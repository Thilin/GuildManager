---@class SyncService
---@field private _eventRepository EventRepository
---@field private _groupRepository GroupRepository
---@field private _memberRepository MemberRepository
---@field private _memberService MemberService|nil
---@field private _loginGetTime number
---@field private _loginTimestamp number
---@field private _outboundQueue table[]
---@field private _isSending boolean
---@field private _incomingStreams table<string, table>
---@field private _callbacks table<string, function>
SyncService = {}
SyncService.__index = SyncService

local PACKET_PREFIX = "GM_SYNC"
local CHUNK_SIZE = 175 -- Tamanho seguro do bloco em caracteres (abaixo do limite de 255 bytes do WoW)
local SEND_INTERVAL = 0.04 -- Intervalo entre disparos (25 mensagens/segundo, seguro contra flood limiter)

--- Construtor do serviço de sincronização automática entre membros da guilda.
---@param eventRepository EventRepository
---@param groupRepository GroupRepository
---@param memberRepository MemberRepository
---@param memberService MemberService|nil
---@return SyncService
function SyncService:new(eventRepository, groupRepository, memberRepository, memberService)
    local instance = setmetatable({}, self)

    instance._eventRepository = eventRepository
    instance._groupRepository = groupRepository
    instance._memberRepository = memberRepository
    instance._memberService = memberService

    instance._loginGetTime = (GetTime and GetTime()) or 0
    instance._loginTimestamp = (time and time()) or 0

    instance._outboundQueue = {}
    instance._isSending = false
    instance._incomingStreams = {}
    instance._callbacks = {}
    instance._streamCounter = 0

    return instance
end

--- Obtém o tempo de sessão contínuo do jogador atual (uptime em segundos).
---@return number
function SyncService:getUptime()
    local now = (GetTime and GetTime()) or 0
    return math.max(0, math.floor(now - self._loginGetTime))
end

--- Obtém o timestamp unix do login do jogador.
---@return number
function SyncService:getLoginTimestamp()
    return self._loginTimestamp
end

--- Registra uma função de callback para eventos do protocolo de sincronização.
---@param eventName string @Nome do evento ("HELLO", "UPTIME", "PULL", "DATA", "DIFF", "ACK")
---@param callback function
function SyncService:registerCallback(eventName, callback)
    if type(eventName) == "string" and type(callback) == "function" then
        self._callbacks[eventName] = callback
    end
end

--- Dispara um callback registrado internamente com captura de erros.
---@param eventName string
---@param ... any
local function triggerCallback(self, eventName, ...)
    local cb = self._callbacks[eventName]
    if type(cb) == "function" then
        local ok, err = pcall(cb, ...)
        if not ok and err then
            if eventName ~= "ERROR" then
                triggerCallback(self, "ERROR", nil, "Erro na execução do evento " .. tostring(eventName) .. ": " .. tostring(err))
            end
        end
    end
end

--- Normaliza o nome do personagem (removendo reino se presente).
---@param name string|nil
---@return string
function SyncService:sanitizeName(name)
    if not name or name == "" then return "" end
    return (name:match("^[^-]+") or name):lower()
end

--- Obtém o nome limpo do jogador local.
---@return string
function SyncService:getMyName()
    local myName = (UnitName and UnitName("player")) or ""
    return (myName:match("^[^-]+") or myName):lower()
end

--- Verifica se um membro possui dados customizados gerenciados pelo AddOn
--- que não são providos nativamente pela API de Roster da Blizzard.
---@param member Member
---@return boolean
function SyncService:hasCustomMemberData(member)
    if not member then return false end

    local note = member:getCustomNote()
    if note and note ~= "" then return true end

    local alts = member:getAlts()
    if type(alts) == "table" and #alts > 0 then return true end

    local bday = member:getBirthday()
    if bday and bday ~= "" then return true end

    local rec = member:getRecruiter()
    if rec and rec ~= "" then return true end

    local dJoin = member:getDateJoin()
    if dJoin and dJoin ~= "" then return true end

    local dLeft = member:getDateLeft()
    if dLeft and dLeft ~= "" then return true end

    local lRank = member:getLastRank()
    if lRank and lRank ~= "" then return true end

    if (member:getTimesLeft() or 0) > 0 then return true end
    if member:isMain() == false then return true end
    if member:isInGuild() == false then return true end

    return false
end

--- Exporta todos os Eventos cadastrados no banco de dados.
---@return table[]
function SyncService:exportEvents()
    local result = {}
    if not self._eventRepository then return result end

    local all = self._eventRepository:findAll()
    for _, evt in ipairs(all) do
        if evt and type(evt.serialize) == "function" then
            table.insert(result, evt:serialize())
        end
    end
    return result
end

--- Exporta todos os Grupos cadastrados no banco de dados.
---@return table[]
function SyncService:exportGroups()
    local result = {}
    if not self._groupRepository then return result end

    local all = self._groupRepository:findAll()
    for _, grp in ipairs(all) do
        if grp and type(grp.serialize) == "function" then
            table.insert(result, grp:serialize())
        end
    end
    return result
end

--- Exporta todos os Membros que possuem dados customizados ou histórico do AddOn.
---@return table[]
function SyncService:exportMembers()
    local result = {}
    if not self._memberRepository then return result end

    local all = self._memberRepository:findAll()
    for _, mem in ipairs(all) do
        if mem and self:hasCustomMemberData(mem) and type(mem.serialize) == "function" then
            table.insert(result, mem:serialize())
        end
    end
    return result
end

--- Exporta o pacote completo com todas as entidades Models (Event, Group, Member).
---@return table
function SyncService:exportAllData()
    return {
        events = self:exportEvents(),
        groups = self:exportGroups(),
        members = self:exportMembers(),
    }
end

--- Mescla uma lista de Eventos remotos no repositório local.
--- Regra: Adiciona eventos faltantes e complementa informações sem sobreescrever destrutivamente.
---@param remoteEvents table[]
---@return number, number @addedCount, updatedCount
function SyncService:mergeEvents(remoteEvents)
    if not self._eventRepository or type(remoteEvents) ~= "table" then
        return 0, 0
    end

    local addedCount, updatedCount = 0, 0

    for _, remEvt in ipairs(remoteEvents) do
        if remEvt and remEvt.id and remEvt.id ~= "" then
            local localEvt = self._eventRepository:findById(remEvt.id)
            if not localEvt then
                -- Evento novo: Adiciona diretamente
                local newEvt = Event:new(remEvt)
                self._eventRepository:save(newEvt)
                addedCount = addedCount + 1
            else
                -- Evento existente: Concatena e complementa dados
                local changed = false

                -- Título
                local lTitle = localEvt:getTitle() or ""
                local rTitle = remEvt.title or ""
                if (lTitle == "" or lTitle == "Novo Evento") and (rTitle ~= "" and rTitle ~= "Novo Evento") then
                    localEvt:setTitle(rTitle)
                    changed = true
                end

                -- Descrição
                local lDesc = localEvt:getDescription() or ""
                local rDesc = remEvt.description or ""
                if lDesc == "" and rDesc ~= "" then
                    localEvt:setDescription(rDesc)
                    changed = true
                end

                -- Data e Horário
                local lDate = localEvt:getDate() or ""
                local rDate = remEvt.date or ""
                if lDate == "" and rDate ~= "" then
                    localEvt:setDate(rDate)
                    changed = true
                end

                local lTime = localEvt:getTime() or ""
                local rTime = remEvt.time or ""
                if lTime == "" and rTime ~= "" then
                    localEvt:setTime(rTime)
                    changed = true
                end

                -- Tipo
                if (not localEvt:getType() or localEvt:getType() == "OUTRO") and remEvt.type and remEvt.type ~= "OUTRO" then
                    localEvt:setType(remEvt.type)
                    changed = true
                end

                -- Convidados: Concatena novos convidados e atualiza status confirmados
                if type(remEvt.invitees) == "table" then
                    for _, remInv in ipairs(remEvt.invitees) do
                        if remInv and remInv.name and remInv.name ~= "" then
                            local has, idx = localEvt:hasInvitee(remInv.name)
                            if not has then
                                localEvt:addInvitee(remInv.name, remInv.class, remInv.level, remInv.status)
                                changed = true
                            else
                                local curInvitees = localEvt:getInvitees()
                                if curInvitees and curInvitees[idx] then
                                    local curStatus = curInvitees[idx].status
                                    if (curStatus == "PENDENTE" or not curStatus) and remInv.status and remInv.status ~= "PENDENTE" then
                                        localEvt:setInviteeStatus(remInv.name, remInv.status)
                                        changed = true
                                    end
                                end
                            end
                        end
                    end
                end

                if changed then
                    self._eventRepository:save(localEvt)
                    updatedCount = updatedCount + 1
                end
            end
        end
    end

    return addedCount, updatedCount
end

--- Mescla uma lista de Grupos remotos no repositório local.
--- Regra: Adiciona grupos faltantes e complementa membros e notas sem sobreescrever destrutivamente.
---@param remoteGroups table[]
---@return number, number @addedCount, updatedCount
function SyncService:mergeGroups(remoteGroups)
    if not self._groupRepository or type(remoteGroups) ~= "table" then
        return 0, 0
    end

    local addedCount, updatedCount = 0, 0

    for _, remGrp in ipairs(remoteGroups) do
        if remGrp and remGrp.id and remGrp.id ~= "" then
            local localGrp = self._groupRepository:findById(remGrp.id)
            if not localGrp then
                -- Grupo novo: Adiciona diretamente
                local newGrp = Group:new(remGrp)
                self._groupRepository:save(newGrp)
                addedCount = addedCount + 1
            else
                -- Grupo existente: Concatena membros e complementa atributos
                local changed = false

                -- Líder
                local lLeader = localGrp:getLeader() or ""
                local rLeader = remGrp.leader or ""
                if lLeader == "" and rLeader ~= "" then
                    localGrp:setLeader(rLeader)
                    changed = true
                end

                -- Nota
                local lNote = localGrp:getNote() or ""
                local rNote = remGrp.note or ""
                if lNote == "" and rNote ~= "" then
                    localGrp:setNote(rNote)
                    changed = true
                end

                -- Membros: Adiciona novos membros e complementa funções
                if type(remGrp.members) == "table" then
                    for _, remMem in ipairs(remGrp.members) do
                        if remMem and remMem.name and remMem.name ~= "" then
                            local existing = localGrp:getMember(remMem.name)
                            if not existing then
                                localGrp:addMember(remMem.name, remMem.role, remMem.class, remMem.level)
                                changed = true
                            else
                                if (existing.role == "NONE" or not existing.role) and remMem.role and remMem.role ~= "NONE" then
                                    localGrp:setMemberRole(remMem.name, remMem.role)
                                    changed = true
                                end
                            end
                        end
                    end
                end

                if changed then
                    self._groupRepository:save(localGrp)
                    updatedCount = updatedCount + 1
                end
            end
        end
    end

    return addedCount, updatedCount
end

--- Mescla uma lista de Membros remotos no repositório local.
--- Regra: Adiciona novos membros e complementa notas, alts, aniversário, recrutador etc.
---@param remoteMembers table[]
---@return number, number @addedCount, updatedCount
function SyncService:mergeMembers(remoteMembers)
    if not self._memberRepository or type(remoteMembers) ~= "table" then
        return 0, 0
    end

    local addedCount, updatedCount = 0, 0

    for _, remMem in ipairs(remoteMembers) do
        local memberName = remMem and remMem.name
        if memberName and memberName ~= "" then
            local localMem = self._memberRepository:findByName(memberName)
            if not localMem then
                -- Membro novo: Adiciona ao repositório
                local newMem = Member:new(remMem)
                self._memberRepository:save(newMem)
                addedCount = addedCount + 1
            else
                -- Membro existente: Concatena e complementa dados customizados
                local changed = false

                -- Nota Customizada
                local lNote = localMem:getCustomNote() or ""
                local rNote = remMem.customNote or ""
                if lNote == "" and rNote ~= "" then
                    localMem:setCustomNote(rNote)
                    changed = true
                elseif lNote ~= "" and rNote ~= "" and lNote ~= rNote then
                    if rNote:find(lNote, 1, true) then
                        localMem:setCustomNote(rNote)
                        changed = true
                    elseif not lNote:find(rNote, 1, true) then
                        localMem:setCustomNote(lNote .. " | " .. rNote)
                        changed = true
                    end
                end

                -- Alts vinculados
                if type(remMem.alts) == "table" then
                    for _, alt in ipairs(remMem.alts) do
                        if alt and alt ~= "" and alt:lower() ~= memberName:lower() then
                            local added = localMem:addAlt(alt)
                            if added then
                                changed = true
                            end
                        end
                    end
                end

                -- Aniversário
                local lBday = localMem:getBirthday() or ""
                local rBday = remMem.birthday or ""
                if lBday == "" and rBday ~= "" then
                    localMem:setBirthday(rBday)
                    changed = true
                end

                -- Recrutador
                local lRec = localMem:getRecruiter() or ""
                local rRec = remMem.recruiter or ""
                if lRec == "" and rRec ~= "" then
                    localMem:setRecruiter(rRec)
                    changed = true
                end

                -- Data de Entrada (mantém a data mais antiga)
                local lJoin = localMem:getDateJoin() or ""
                local rJoin = remMem.dateJoin or ""
                if lJoin == "" and rJoin ~= "" then
                    localMem:setDateJoin(rJoin)
                    changed = true
                end

                -- Data de Saída
                local lLeft = localMem:getDateLeft() or ""
                local rLeft = remMem.dateLeft or ""
                if lLeft == "" and rLeft ~= "" then
                    localMem:setDateLeft(rLeft)
                    changed = true
                end

                -- Último Cargo
                local lRank = localMem:getLastRank() or ""
                local rRank = remMem.lastRank or ""
                if lRank == "" and rRank ~= "" then
                    localMem:setLastRank(rRank)
                    changed = true
                end

                -- Quantidade de saídas (mantém o maior contador registrado)
                local lTimes = localMem:getTimesLeft() or 0
                local rTimes = tonumber(remMem.timesLeft) or 0
                if rTimes > lTimes then
                    localMem:setTimesLeft(rTimes)
                    changed = true
                end

                -- Status de guilda
                if remMem.isInGuild == false and localMem:isInGuild() == true then
                    if (lLeft ~= "" or rLeft ~= "") and (rTimes > 0 or lTimes > 0) then
                        localMem:setInGuild(false)
                        changed = true
                    end
                end

                if changed then
                    self._memberRepository:save(localMem)
                    updatedCount = updatedCount + 1

                    -- Sincroniza família de alts se serviço de membros estiver disponível
                    if self._memberService and self._memberService.syncAltFamily then
                        pcall(self._memberService.syncAltFamily, self._memberService, localMem:getAlts(), localMem:getName())
                    end
                end
            end
        end
    end

    return addedCount, updatedCount
end

--- Mescla todas as entidades recebidas (Events, Groups, Members).
---@param remoteData table
---@return table @Resumo com contagens de inserções e atualizações
function SyncService:mergeAllData(remoteData)
    if type(remoteData) ~= "table" then
        return { eventsAdded = 0, eventsUpdated = 0, groupsAdded = 0, groupsUpdated = 0, membersAdded = 0, membersUpdated = 0 }
    end

    local evAdd, evUp = self:mergeEvents(remoteData.events)
    local grAdd, grUp = self:mergeGroups(remoteData.groups)
    local memAdd, memUp = self:mergeMembers(remoteData.members)

    return {
        eventsAdded = evAdd,
        eventsUpdated = evUp,
        groupsAdded = grAdd,
        groupsUpdated = grUp,
        membersAdded = memAdd,
        membersUpdated = memUp,
        totalAdded = evAdd + grAdd + memAdd,
        totalUpdated = evUp + grUp + memUp,
    }
end

--- Computa a diferença de dados que o cliente local possui e que o cliente remoto não possuía.
--- Usado para sincronização bidirecional completa sem perda de dados.
---@param remoteData table
---@return table @Tabela contendo apenas as entidades únicas que o cliente remoto não enviou
function SyncService:computeDiff(remoteData)
    local diff = {
        events = {},
        groups = {},
        members = {},
    }

    if type(remoteData) ~= "table" then
        return self:exportAllData()
    end

    -- Mapeia IDs de eventos remotos
    local remoteEvtIds = {}
    if type(remoteData.events) == "table" then
        for _, e in ipairs(remoteData.events) do
            if e and e.id then remoteEvtIds[e.id] = e end
        end
    end

    -- Mapeia IDs de grupos remotos
    local remoteGrpIds = {}
    if type(remoteData.groups) == "table" then
        for _, g in ipairs(remoteData.groups) do
            if g and g.id then remoteGrpIds[g.id] = g end
        end
    end

    -- Mapeia nomes de membros remotos
    local remoteMemNames = {}
    if type(remoteData.members) == "table" then
        for _, m in ipairs(remoteData.members) do
            if m and m.name then remoteMemNames[m.name:lower()] = m end
        end
    end

    -- Encontra eventos locais inexistentes ou com convidados a mais no remoto
    local localEvents = self:exportEvents()
    for _, lEvt in ipairs(localEvents) do
        local rEvt = remoteEvtIds[lEvt.id]
        if not rEvt then
            table.insert(diff.events, lEvt)
        else
            -- Verifica se o local tem mais convidados
            local lInvCount = (lEvt.invitees and #lEvt.invitees) or 0
            local rInvCount = (rEvt.invitees and #rEvt.invitees) or 0
            if lInvCount > rInvCount then
                table.insert(diff.events, lEvt)
            end
        end
    end

    -- Encontra grupos locais inexistentes ou com membros a mais no remoto
    local localGroups = self:exportGroups()
    for _, lGrp in ipairs(localGroups) do
        local rGrp = remoteGrpIds[lGrp.id]
        if not rGrp then
            table.insert(diff.groups, lGrp)
        else
            local lMemCount = (lGrp.members and #lGrp.members) or 0
            local rMemCount = (rGrp.members and #rGrp.members) or 0
            if lMemCount > rMemCount then
                table.insert(diff.groups, lGrp)
            end
        end
    end

    -- Encontra membros locais com dados customizados que o remoto não possui
    local localMembers = self:exportMembers()
    for _, lMem in ipairs(localMembers) do
        local lower = lMem.name:lower()
        local rMem = remoteMemNames[lower]
        if not rMem then
            table.insert(diff.members, lMem)
        else
            -- Se o local possui mais alts ou notas não presentes no remoto
            local lAltsCount = (lMem.alts and #lMem.alts) or 0
            local rAltsCount = (rMem.alts and #rMem.alts) or 0
            local lNote = lMem.customNote or ""
            local rNote = rMem.customNote or ""
            if lAltsCount > rAltsCount or (lNote ~= "" and rNote == "") then
                table.insert(diff.members, lMem)
            end
        end
    end

    return diff
end

--- Envia um pacote de chat para a guilda usando as APIs protegidas do WoW.
---@param packet string
---@param target string|nil
---@return boolean
local function dispatchPacket(packet, target)
    if not IsInGuild or not IsInGuild() then return false end

    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        local success = pcall(C_ChatInfo.SendAddonMessage, "GuildManager", packet, "GUILD")
        return success
    elseif SendAddonMessage then
        local success = pcall(SendAddonMessage, "GuildManager", packet, "GUILD")
        return success
    end

    return false
end

--- Processa a fila de saída de pacotes sequencialmente com taxa controlada (throttle).
function SyncService:processOutboundQueue()
    if #self._outboundQueue == 0 then
        self._isSending = false
        return
    end

    self._isSending = true
    local item = table.remove(self._outboundQueue, 1)

    if item and item.packet then
        dispatchPacket(item.packet, item.target)
    end

    if #self._outboundQueue > 0 then
        if C_Timer and C_Timer.After then
            C_Timer.After(SEND_INTERVAL, function()
                self:processOutboundQueue()
            end)
        else
            self:processOutboundQueue()
        end
    else
        self._isSending = false
    end
end

--- Enfileira um pacote para envio sequencial com taxa controlada.
---@param packet string
---@param target string|nil
function SyncService:queuePacket(packet, target)
    table.insert(self._outboundQueue, { packet = packet, target = target })
    if not self._isSending then
        self:processOutboundQueue()
    end
end

--- Cria e enfileira uma mensagem lógica dividida em blocos (chunking).
---@param action string @Tipo da ação ("HELLO", "UPTIME", "PULL", "DATA", "DIFF", "ACK")
---@param payload table|string|number
---@param target string|nil @Nome do destinatário pretendido ("*" para todos)
function SyncService:sendLogicalMessage(action, payload, target)
    self._streamCounter = self._streamCounter + 1
    local streamId = string.format("s%d%d", (time and time()) or 0, self._streamCounter)
    local targetName = target or "*"

    local serializedPayload = ""
    if type(payload) == "table" then
        serializedPayload = Serializer.serialize(payload)
    else
        serializedPayload = tostring(payload or "")
    end

    local payloadLen = #serializedPayload
    local totalParts = math.ceil(payloadLen / CHUNK_SIZE)
    if totalParts == 0 then totalParts = 1 end

    for part = 1, totalParts do
        local startIdx = (part - 1) * CHUNK_SIZE + 1
        local endIdx = math.min(part * CHUNK_SIZE, payloadLen)
        local chunk = serializedPayload:sub(startIdx, endIdx)

        -- Formato: GM_SYNC:<action>:<streamId>:<part>:<totalParts>:<target>:<chunk>
        local packet = string.format("%s:%s:%s:%d:%d:%s:%s",
            PACKET_PREFIX,
            action,
            streamId,
            part,
            totalParts,
            targetName,
            chunk)

        self:queuePacket(packet, target)
    end
end

--- Trata um pacote de mensagem de AddOn recebido.
---@param rawMessage string
---@param sender string
function SyncService:handleIncomingPacket(rawMessage, sender)
    if type(rawMessage) ~= "string" or not rawMessage:find("^" .. PACKET_PREFIX .. ":") then
        return
    end

    -- Ignora mensagens enviadas pelo próprio personagem
    local myName = self:getMyName()
    local senderClean = self:sanitizeName(sender)
    if myName ~= "" and senderClean == myName then
        return
    end

    -- Extração do cabeçalho do pacote
    local pfx, action, streamId, partStr, totalPartsStr, target, chunk =
        rawMessage:match("^(GM_SYNC):([^:]+):([^:]+):(%d+):(%d+):([^:]+):(.*)$")

    if not pfx or not action or not streamId or not partStr or not totalPartsStr then
        return
    end

    local part = tonumber(partStr)
    local totalParts = tonumber(totalPartsStr)
    if not part or not totalParts then return end

    -- Se o pacote tem destinatário específico e não é para o jogador local nem broadcast "*", descarta
    if target ~= "*" and self:sanitizeName(target) ~= myName then
        return
    end

    -- Limpeza de fluxos pendentes que excederam o tempo limite (pacotes perdidos)
    local now = (GetTime and GetTime()) or 0
    for sId, sData in pairs(self._incomingStreams) do
        if (now - (sData.startTime or 0)) > 8 then
            self._incomingStreams[sId] = nil
            triggerCallback(self, "ERROR", sData.sender, "Pacotes perdidos ou transmissão incompleta")
        end
    end

    -- Inicializa estrutura de reanimação de pacotes fragmentados (streams)
    if not self._incomingStreams[streamId] then
        self._incomingStreams[streamId] = {
            action = action,
            totalParts = totalParts,
            receivedCount = 0,
            parts = {},
            sender = senderClean,
            startTime = now,
        }
    end

    local stream = self._incomingStreams[streamId]
    if not stream.parts[part] then
        stream.parts[part] = chunk
        stream.receivedCount = stream.receivedCount + 1
    end

    -- Quando todos os blocos foram recebidos, monta o payload completo e aciona o evento
    if stream.receivedCount == stream.totalParts then
        local assembled = table.concat(stream.parts, "")
        self._incomingStreams[streamId] = nil

        local deserializedData = assembled
        if assembled:sub(1, 1) == "{" or assembled:sub(1, 1) == "[" then
            local obj, err = Serializer.deserialize(assembled)
            if err or obj == nil then
                triggerCallback(self, "ERROR", stream.sender, "Dados corrompidos na desserialização: " .. tostring(err))
                return
            end
            deserializedData = obj
        end

        triggerCallback(self, action, stream.sender, deserializedData)
    end
end

_G.SyncService = SyncService
return SyncService
