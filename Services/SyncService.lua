---@class SyncService
--- Serviço de sincronização peer-to-peer em tempo real para os dados customizados de cada membro da guilda
--- (Entrada, Aniversário, Alts Vinculados e Recrutador).
--- Transmite via canal de guilda (GUILD) e canais do Addon usando o protocolo de confirmação (ACK).
--- O emissor retransmite os dados até que todos os pares online com o Addon confirmem o recebimento.
--- Sincroniza automaticamente quando um membro da guilda que usa o Addon é identificado ao logar,
--- e permite forçar a sincronização manualmente a qualquer momento.
SyncService = {}
SyncService.__index = SyncService

--- Verifica com segurança se um valor é um "Secret Value" (WoW 11.0+ / 12.0+ / Classic Beta)
---@param val any
---@return boolean
local function isSecretValue(val)
    if not val then
        return false
    end
    local isSecret = _G.issecretvalue or issecretvalue
    if isSecret and isSecret(val) then
        return true
    end
    local ok = pcall(function() return val == "" end)
    if not ok then
        return true
    end
    return false
end

--- Obtém o timestamp sincronizado do servidor (ou relógio local como fallback)
---@return number
local function getCurrentTimestamp()
    if GetServerTime then
        local st = GetServerTime()
        if st and st > 0 then return st end
    end
    if time then
        local t = time()
        if t and t > 0 then return t end
    end
    if os and os.time then
        return os.time()
    end
    return 0
end

--- Normaliza o nome do remetente removendo o sufixo de reino e espaços.
---@param name string|nil
---@return string
local function cleanName(name)
    if not name or name == "" then return "" end
    local clean = name:match("^[^-]+") or name
    return clean:match("^%s*(.-)%s*$") or clean
end

--- Helper de localização seguro para mensagens do SyncService.
---@param key string
---@param ... any
---@return string
local function L(key, ...)
    local str = nil
    if _G.GM and _G.GM.L and type(_G.GM.L) == "table" then
        str = _G.GM.L[key]
    elseif _G.L and type(_G.L) == "table" then
        str = _G.L[key]
    end
    if not str and Locales and Locales.get then
        str = Locales.get(key)
    end
    if not str then
        str = key
    end
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, str, ...)
        if ok then return formatted end
    end
    return str
end

local SYNC_PREFIX = "GM_SYNC"
local RETRANSMIT_INTERVAL = 4.0       -- Intervalo entre retransmissões de pacotes pendentes (4.0s)
local SEND_QUEUE_INTERVAL = 0.8       -- Intervalo compassado de envio de pacotes (1.25 pkt/s, tráfego super suave e zero throttle)
local PEER_LIVENESS_WINDOW = 35.0     -- Tempo em segundos sem sinal para considerar peer offline (35s)
local MAX_RETRANSMIT_ATTEMPTS = 60    -- Limite máximo de tentativas por atualização (evita loop infinito)
local MAX_QUEUE_SIZE = 250            -- Capacidade máxima da fila compassada para proteção contra vazamento de memória

--- Envia mensagem de addon com suporte a ChatThrottleLib para proteção total contra limite de mensagens
local function safeSendAddonMessage(prefix, text, channel, target, prio)
    if not prefix or not text or not channel then return end
    prio = prio or "NORMAL"
    if _G.ChatThrottleLib and _G.ChatThrottleLib.SendAddonMessage then
        pcall(_G.ChatThrottleLib.SendAddonMessage, _G.ChatThrottleLib, prio, prefix, text, channel, target)
        return
    end
    local Send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or _G.SendAddonMessage
    if Send then
        if target then
            pcall(Send, prefix, text, channel, target)
        else
            pcall(Send, prefix, text, channel)
        end
    end
end

-- Registra o prefixo de mensagem imediatamente no carregamento do arquivo
local RegisterPrefix = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or _G.RegisterAddonMessagePrefix
if RegisterPrefix then
    pcall(RegisterPrefix, SYNC_PREFIX)
end

--- Construtor do SyncService.
---@param memberService MemberService
---@param locationService LocationService|nil
---@param settingsService SettingsService|nil
---@param guildRosterService GuildRosterService|nil
---@return SyncService
function SyncService:new(memberService, locationService, settingsService, guildRosterService)
    local instance = setmetatable({}, self)
    instance._memberService = memberService
    instance._locationService = locationService
    instance._settingsService = settingsService
    instance._guildRosterService = guildRosterService
    instance._syncConflictView = nil
    instance._refreshDebounceTimer = nil

    -- Tabela de pares conhecidos com o Addon ativo: [peerNameLower] = { name = peerName, lastSeen = GetTime(), isActive = true }
    instance._peers = {}

    -- Registro do último anúncio de login detectado para evitar spam: [peerNameLower] = timestamp
    instance._lastLoginDetected = {}

    -- Fila de envio pendente de confirmações (retransmissão): [updateId] = updateData
    instance._pendingOutbox = {}

    -- Fila sequencial compassada de pacotes para envio (desenfileiramento O(1) com ponteiros de índice)
    instance._sendQueue = {}
    instance._queueHead = 1
    instance._queueTail = 0

    -- Histórico de IDs de atualizações já processadas localmente para evitar loops: [updateId] = timestamp
    instance._processedUpdateIds = {}

    -- Assinaturas recentes das informações de cada membro para evitar envios redundantes: [memberNameLower] = signature
    instance._lastMemberSignatures = {}

    -- Assinaturas recentes das profissões de cada membro: [memberNameLower_profKey] = signature
    instance._lastProfSignatures = {}

    -- Registro de conflitos de Role já decididos pelo Líder para evitar reabrir pacotes em trânsito: [key] = timestamp
    instance._resolvedLeaderRoleConflicts = {}

    instance._myPlayerName = nil
    instance._myFullName = nil
    instance._channelNumber = nil
    instance._eventFrame = nil
    instance._lastRetransmitTick = 0
    instance._syncChatFrame = nil

    return instance
end

--- Vincula a view de conflito de sincronização para decisões do Líder da Guilda.
---@param view SyncConflictView
function SyncService:setSyncConflictView(view)
    self._syncConflictView = view
    if view and view.setOnActionCallback then
        view:setOnActionCallback(function(conflict, action)
            self:onLeaderResolveConflict(conflict, action)
        end)
    end
end

--- Trata a decisão do Líder da Guilda sobre um conflito de sincronização.
---@param conflict table
---@param action string @"REPLACE", "CONCAT", "KEEP"
function SyncService:onLeaderResolveConflict(conflict, action)
    if not conflict or not conflict.member then return end
    local member = conflict.member
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    local fName = conflict.fieldName or conflict.fieldKey or "Dado"
    local mName = conflict.memberName or member:getName()

    if conflict.fieldKey == "role" then
        local roleVal = tostring(conflict.rawNewValue or conflict.newValue or ""):upper()
        local conflictKey = cleanName(mName):lower() .. "~" .. roleVal
        self._resolvedLeaderRoleConflicts = self._resolvedLeaderRoleConflicts or {}
        self._resolvedLeaderRoleConflicts[conflictKey] = math.max(conflict.timestamp or 0, getCurrentTimestamp())

        if action == "CONCAT" then
            action = "KEEP"
        end
    end

    local nowTs = math.max(getCurrentTimestamp(), (member:getCustomDataTimestamp() or 0) + 1, (conflict.timestamp or 0) + 1)

    if action == "REPLACE" then
        if conflict.fieldKey == "birthday" then
            member:setBirthday(conflict.newValue or "")
        elseif conflict.fieldKey == "recruiter" then
            member:setRecruiter(conflict.newValue or "")
        elseif conflict.fieldKey == "role" then
            member:setRole(conflict.rawNewValue or conflict.newValue or "")
            if member.setRolePendingLeaderConfirm then
                member:setRolePendingLeaderConfirm(false)
            end
        end
        if member.setCustomDataTimestamp then
            member:setCustomDataTimestamp(nowTs)
        end
        if self._memberService then
            self._memberService:saveMember(member, true)
        end
        self:broadcastMemberCustomData(member, true)
        self:refreshActiveViews(mName)
        print(string.format(curL["SYNC_CONFLICT_CHAT_REPLACED"] or "|cff00ff00[GuildManager]|r %s de %s foi substituído no banco do líder.", fName, mName))
    elseif action == "CONCAT" then
        local combined = tostring(conflict.oldValue or "")
        local newVal = tostring(conflict.newValue or "")
        if combined ~= "" and newVal ~= "" then
            combined = combined .. " | " .. newVal
        elseif newVal ~= "" then
            combined = newVal
        end
        if conflict.fieldKey == "birthday" then
            member:setBirthday(combined)
        elseif conflict.fieldKey == "recruiter" then
            member:setRecruiter(combined)
        end
        if member.setCustomDataTimestamp then
            member:setCustomDataTimestamp(nowTs)
        end
        if self._memberService then
            self._memberService:saveMember(member, true)
        end
        self:broadcastMemberCustomData(member, true)
        self:refreshActiveViews(mName)
        print(string.format(curL["SYNC_CONFLICT_CHAT_CONCAT"] or "|cff00ff00[GuildManager]|r %s de %s foi concatenado no banco do líder.", fName, mName))
    elseif action == "KEEP" then
        if conflict.fieldKey == "role" and member.setRolePendingLeaderConfirm then
            member:setRolePendingLeaderConfirm(false)
        end
        if member.setCustomDataTimestamp then
            member:setCustomDataTimestamp(nowTs)
        end
        if self._memberService then
            self._memberService:saveMember(member, true)
        end
        self:broadcastMemberCustomData(member, true)
        self:refreshActiveViews(mName)
        print(string.format(curL["SYNC_CONFLICT_CHAT_KEPT"] or "|cffff9900[GuildManager]|r %s de %s mantido inalterado no banco do líder.", fName, mName))
    end
end

--- Verifica se o remetente é comprovadamente o Líder da Guilda (Guild Master, rankIndex 0).
---@param sender string|nil
---@return boolean
function SyncService:isSenderGuildLeader(sender)
    if not sender or sender == "" then return false end
    local sClean = cleanName(sender):lower()

    if self:isSelf(sender) then
        return (IsGuildLeader and IsGuildLeader() == true) or false
    end

    if self._guildRosterService and self._guildRosterService.getGuildLeaderName then
        local leaderName = self._guildRosterService:getGuildLeaderName()
        if leaderName and cleanName(leaderName):lower() == sClean then
            return true
        end
    end

    local numMembers = GetNumGuildMembers and GetNumGuildMembers() or 0
    for i = 1, numMembers do
        local name, rankName, rankIndex = GetGuildRosterInfo(i)
        if name and rankIndex == 0 then
            local clean = cleanName(name):lower()
            if clean == sClean then
                return true
            end
        end
    end

    if self._memberService and self._memberService.getAllMembers then
        local members = self._memberService:getAllMembers()
        for _, m in ipairs(members) do
            if m:getRankIndex() == 0 and cleanName(m:getName()):lower() == sClean then
                return true
            end
        end
    end

    return false
end

--- Verifica se a exibição de logs de sincronização no chat está ativada nas configurações.
---@return boolean
function SyncService:isChatLogEnabled()
    if self._settingsService and self._settingsService.getSettings then
        local settings = self._settingsService:getSettings()
        if settings and settings.isSyncChatLogEnabled then
            return settings:isSyncChatLogEnabled()
        end
    end
    if _G.GM and _G.GM.settingsService and _G.GM.settingsService.getSettings then
        local settings = _G.GM.settingsService:getSettings()
        if settings and settings.isSyncChatLogEnabled then
            return settings:isSyncChatLogEnabled()
        end
    end
    return false
end



--- Verifica com precisão se o nome informado pertence ao próprio jogador local.
---@param sender string|nil
---@return boolean
function SyncService:isSelf(sender)
    if not sender or sender == "" then return true end
    if UnitIsUnit and UnitIsUnit(sender, "player") then return true end

    local myName = self._myPlayerName
    if not myName and UnitName then
        myName = UnitName("player")
        self._myPlayerName = myName
    end
    if not myName or myName == "" then return false end

    local sClean = cleanName(sender):lower()
    local mClean = cleanName(myName):lower()
    if sClean == mClean then return true end

    return false
end

--- Retorna a lista de outros jogadores atualmente conectados com o Addon ativo.
--- Combina os pares detectados pelo LocationService com as mensagens do SyncService.
---@return table[]
function SyncService:getActivePeers()
    local peers = {}
    local seen = {}
    local now = GetTime and GetTime() or 0

    -- 1. Pares monitorados pelo LocationService (atualizados a cada heartbeat/movimento)
    if self._locationService and self._locationService.getPeers then
        local locPeers = self._locationService:getPeers() or {}
        for name, p in pairs(locPeers) do
            if not self:isSelf(name) and not p.isTest then
                local lastSeen = p.lastSeen or 0
                if (now - lastSeen) <= PEER_LIVENESS_WINDOW then
                    local cName = cleanName(name)
                    local cLower = cName:lower()
                    if cName ~= "" and not seen[cLower] then
                        seen[cLower] = true
                        table.insert(peers, { name = cName, fullName = name, lastSeen = lastSeen })
                    end
                end
            end
        end
    end

    -- 2. Pares descobertos diretamente pelo SyncService
    for lowerName, p in pairs(self._peers) do
        if not seen[lowerName] and not self:isSelf(p.name) and not p.isTest then
            local lastSeen = p.lastSeen or 0
            if (now - lastSeen) <= PEER_LIVENESS_WINDOW then
                seen[lowerName] = true
                table.insert(peers, { name = p.name, fullName = p.name, lastSeen = lastSeen })
            end
        end
    end

    return peers
end

--- Retorna a quantidade de pares online ativos com o Addon.
---@return number
function SyncService:getPeerCount()
    local active = self:getActivePeers()
    return #active
end

--- Registra a atividade recente de um peer. Se for um membro recém-conectado com o Addon,
--- dispara a rotina de detecção de login e sincronização automática.
---@param peerName string
function SyncService:touchPeer(peerName)
    if not peerName or peerName == "" or self:isSelf(peerName) then return end
    local cName = cleanName(peerName)
    local lower = cName:lower()
    local now = GetTime and GetTime() or 0
    local existing = self._peers[lower]

    local isNewlyOnline = false
    if not existing or not existing.isActive or (now - (existing.lastSeen or 0)) > PEER_LIVENESS_WINDOW then
        isNewlyOnline = true
    end

    if existing then
        existing.name = cName
        existing.lastSeen = now
        existing.isActive = true
    else
        self._peers[lower] = {
            name = cName,
            lastSeen = now,
            isActive = true,
        }
    end

    -- Notifica o LocationService imediatamente para registrar que este membro Ã© usuÃ¡rio ativo do AddOn!
    if self._locationService and self._locationService.touchPeer then
        self._locationService:touchPeer(cName)
    end

    if isNewlyOnline then
        local lastNotice = self._lastLoginDetected[lower] or 0
        if (now - lastNotice) > PEER_LIVENESS_WINDOW then
            self._lastLoginDetected[lower] = now
            self:onPeerLoggedIn(cName)
        end
    end
end

--- Retorna o chat frame padrão se a flag de exibição de sincronização no chat estiver ativa.
---@return table|nil
function SyncService:getSyncChatFrame()
    if not self:isChatLogEnabled() then
        return nil
    end
    return DEFAULT_CHAT_FRAME or _G.ChatFrame1
end

--- Imprime a mensagem de sincronização diretamente no chat principal caso a flag esteja ativada nas configurações.
--- Se a flag estiver desativada (padrão), nenhuma mensagem de sincronização é emitida no chat.
---@param msg string
function SyncService:printSyncNotification(msg)
    if not self:isChatLogEnabled() then
        return
    end
    if not msg or msg == "" then return end

    local targetFrame = self:getSyncChatFrame()
    local timeStr = date and date("%H:%M:%S")
    local timePrefix = timeStr and string.format("|cff888888[%s]|r ", timeStr) or ""
    local fullMsg = timePrefix .. msg

    if targetFrame and targetFrame.AddMessage then
        targetFrame:AddMessage(fullMsg)
    elseif print then
        print(fullMsg)
    end
end

--- Disparado quando é identificado que um membro da guilda que usa o Addon acabou de logar / conectar.
--- Notifica o usuário na aba de sync e inicia imediatamente a sincronização dos dados customizados com ele.
---@param peerName string
function SyncService:onPeerLoggedIn(peerName)
    if not peerName or peerName == "" or self:isSelf(peerName) then return end
    local cName = cleanName(peerName)

    self:printSyncNotification(L("SYNC_LOG_PEER_ONLINE", cName))

    -- Dispara a sincronização de todos os membros que possuem dados customizados com o novo colega
    self:syncWithPeer(cName)
end

--- Sincroniza todos os dados customizados com um peer específico que acabou de logar.
--- Enfileira todos os membros cadastrados que possuem dados customizados (Entrada, Aniversário, Recrutador, Alts)
--- e garante que o novo peer esteja na lista de confirmações pendentes (ACK).
---@param peerName string
---@return number @Quantidade de membros com dados customizados enfileirados
function SyncService:syncWithPeer(peerName)
    if not self._memberService or not peerName or peerName == "" then return 0 end
    local cName = cleanName(peerName)
    local peerLower = cName:lower()

    local members = self._memberService:getAllMembers()
    local count = 0
    local isLeader = (IsGuildLeader and IsGuildLeader() == true) or false

    for _, m in ipairs(members) do
        local dateJoin = m:getDateJoin() or ""
        local bday = m:getBirthday() or ""
        local rec = m:getRecruiter() or ""
        local alts = m:getAlts() or {}
        local role = (m.getRole and m:getRole()) or ""
        local roleShouldSync = isLeader or (m.isRolePendingLeaderConfirm and m:isRolePendingLeaderConfirm())
        if dateJoin ~= "" or bday ~= "" or rec ~= "" or #alts > 0 or (role ~= "" and roleShouldSync) then
            local mName = cleanName(m:getName())
            local memberLower = mName:lower()

            -- Encontra ou cria a entrada na outbox
            local existingUpdate = nil
            for _, u in pairs(self._pendingOutbox) do
                if u.memberName:lower() == memberLower then
                    existingUpdate = u
                    break
                end
            end

            if existingUpdate then
                -- Remove a confirmação anterior deste peer para garantir retransmissão até confirmação do novo login
                existingUpdate.acknowledgedPeers[peerLower] = nil
                self:sendUpdatePacket(existingUpdate)
                count = count + 1
            else
                -- Cria novo update e transmite
                local ok = self:broadcastMemberCustomData(m, true)
                if ok then count = count + 1 end
            end
        end
    end

    -- Sincroniza profissões e receitas de todos os membros cadastrados com o colega
    for _, m in ipairs(members) do
        local profs = m.getProfessions and m:getProfessions()
        if type(profs) == "table" then
            local mName = cleanName(m:getName())
            local mLower = mName:lower()
            for profKey, pData in pairs(profs) do
                if (pData.rank or 0) > 0 or (pData.recipes and next(pData.recipes) ~= nil) then
                    local existingUpdate = nil
                    for _, u in pairs(self._pendingOutbox) do
                        if u.type == "PROFESSION" and u.memberName:lower() == mLower and u.profKey == profKey then
                            existingUpdate = u
                            break
                        end
                    end

                    if existingUpdate then
                        existingUpdate.acknowledgedPeers[peerLower] = nil
                        self:sendUpdatePacket(existingUpdate)
                        count = count + 1
                    else
                        local ok = self:broadcastMemberProfessions(m, profKey, true)
                        if ok then count = count + 1 end
                    end
                end
            end
        end
    end
    if _G.GM and _G.GM.craftOrderRepository and _G.GM.craftOrderRepository.findAll then
        pcall(function()
            local orders = _G.GM.craftOrderRepository:findAll()
            for _, ord in ipairs(orders) do
                if ord:getStatus() ~= "CANCELLED" then
                    self:broadcastCraftOrder(ord, "UPDATE", false)
                end
            end
        end)
    end

    -- Sincroniza Grupos e Cards de LFG com o peer conectado
    if isLeader then
        pcall(function()
            self:broadcastAllGroups()
            self:broadcastAllLFGCards()
        end)
    elseif self:isSenderGuildLeader(peerName) then
        pcall(function()
            local myName = self._myPlayerName or (UnitName and UnitName("player")) or ""
            if _G.GM and _G.GM.groupRepository and _G.GM.groupRepository.findAll then
                for _, g in ipairs(_G.GM.groupRepository:findAll()) do
                    if g:isCreator(myName) then
                        self:syncGroup(g, "UPDATE")
                    end
                end
            end
            if _G.GM and _G.GM.lfgRepository and _G.GM.lfgRepository.findAll then
                for _, c in ipairs(_G.GM.lfgRepository:findAll()) do
                    if c:isCreator(myName) then
                        self:syncLFGCard(c, "UPDATE")
                    end
                end
            end
        end)
    end

    return count
end

--- Gera uma assinatura dos dados customizados do membro para detectar alterações reais.
---@param dateJoin string|nil
---@param birthday string|nil
---@param recruiter string|nil
---@param altsCsv string|nil
---@param isMain boolean|nil
---@return string
local function makeDataSignature(dateJoin, birthday, recruiter, altsCsv, isMain, role)
    return string.format("%s~%s~%s~%s~%s~%s",
        dateJoin or "",
        birthday or "",
        recruiter or "",
        altsCsv or "",
        isMain and "1" or "0",
        role or ""
    )
end

--- Adiciona um pacote à fila compassada de envio para evitar throttling do chat da Blizzard.
--- Limita o tamanho máximo a MAX_QUEUE_SIZE para prevenir crescimento descontrolado de memória.
---@param payload string
---@param targetChannel string|nil @"GUILD", "CHANNEL", "RAID", "PARTY", "WHISPER"
---@param channelNumber number|nil
---@param targetPlayer string|nil
function SyncService:enqueuePacket(payload, targetChannel, channelNumber, targetPlayer)
    if not payload or payload == "" then return end

    local currentSize = (self._queueTail or 0) - (self._queueHead or 1) + 1
    if currentSize >= MAX_QUEUE_SIZE then
        -- Fila no limite: descarta o pacote mais antigo avançando a cabeça para evitar leak de memória
        if self._sendQueue and self._queueHead then
            self._sendQueue[self._queueHead] = nil
        end
        self._queueHead = (self._queueHead or 1) + 1
    end

    self._queueTail = (self._queueTail or 0) + 1
    self._sendQueue[self._queueTail] = {
        payload = payload,
        target = targetChannel or "GUILD",
        channelNumber = channelNumber,
        targetPlayer = targetPlayer,
    }
end

--- Processa a fila compassada de envio a uma taxa segura (~0.12s por pacote = ~8 pacotes/s),
--- garantindo que mensagens de Addon nunca sejam descartadas pelo limite da Blizzard.
--- Utiliza desenfileiramento O(1) via ponteiros sem operações de deslocamento de array.
function SyncService:processSendQueue()
    local head = self._queueHead or 1
    local tail = self._queueTail or 0

    if head > tail then
        if head ~= 1 or tail ~= 0 then
            self._queueHead = 1
            self._queueTail = 0
        end
        return
    end

    local item = self._sendQueue[head]
    self._sendQueue[head] = nil
    self._queueHead = head + 1

    if self._queueHead > tail then
        self._queueHead = 1
        self._queueTail = 0
    end

    if not item or not item.payload then return end

    if item.target == "GUILD" then
        if IsInGuild and IsInGuild() then
            safeSendAddonMessage(SYNC_PREFIX, item.payload, "GUILD", nil, "BULK")
        end
    elseif item.target == "RAID" and IsInRaid and IsInRaid() then
        safeSendAddonMessage(SYNC_PREFIX, item.payload, "RAID", nil, "BULK")
    elseif item.target == "PARTY" and IsInGroup and IsInGroup() then
        safeSendAddonMessage(SYNC_PREFIX, item.payload, "PARTY", nil, "BULK")
    end
end

--- Transmite os dados customizados de um membro da guilda para todos os outros usuários do Addon.
--- Se os dados foram alterados, transmite na hora e mantém na fila até que todos confirmem (ACK).
---@param member Member
---@param force boolean|nil
---@return boolean @Retorna true se o envio foi enfileirado
function SyncService:broadcastMemberCustomData(member, force)
    if not member or type(member.getName) ~= "function" then
        return false
    end

    local memberName = cleanName(member:getName())
    if memberName == "" then
        return false
    end

    local isLeader = (IsGuildLeader and IsGuildLeader() == true) or false

    local dateJoin = ""
    local altsCsv = ""
    local isMain = false
    local role = ""

    -- Regra 1: Data de entrada e Lista de Alts só sincronizam a partir do Líder da guilda!
    -- A Função (Role) é compartilhada para todos a partir do addon do Líder da Guilda,
    -- e qualquer atualização feita pelos membros é enviada ao Líder para confirmação.
    if isLeader then
        dateJoin = member:getDateJoin() or ""
        local alts = member:getAlts() or {}
        altsCsv = table.concat(alts, ",")
        isMain = member:isMain()
        role = (member.getRole and member:getRole()) or ""
    elseif member.isRolePendingLeaderConfirm and member:isRolePendingLeaderConfirm() then
        role = (member.getRole and member:getRole()) or ""
    end

    -- Regra 2: Aniversário e Recrutador continuam sendo syncados entre todos os membros
    local birthday = member:getBirthday() or ""
    local recruiter = member:getRecruiter() or ""

    -- Regra 3: Nota interna NUNCA recebe sync (nunca é transmitida)
    -- Se não é o líder e não possui aniversário, recrutador nem função pendente, descarta o envio
    if not isLeader and birthday == "" and recruiter == "" and role == "" then
        return false
    end

    local signature = makeDataSignature(dateJoin, birthday, recruiter, altsCsv, isMain, role)
    local memberLower = memberName:lower()

    -- Evita transmissões redundantes se nada mudou
    if not force and self._lastMemberSignatures[memberLower] == signature then
        return false
    end
    self._lastMemberSignatures[memberLower] = signature

    local memberTimestamp = (member.getCustomDataTimestamp and member:getCustomDataTimestamp()) or 0
    if memberTimestamp == 0 then
        memberTimestamp = getCurrentTimestamp()
        if member.setCustomDataTimestamp then
            member:setCustomDataTimestamp(memberTimestamp)
        end
        if self._memberService then
            self._memberService:saveMember(member, true)
        end
    end

    local randomSuffix = math.random(1000, 9999)
    local updateId = string.format("%s_%d_%d", memberName, memberTimestamp, randomSuffix)

    -- Cancela envios anteriores do mesmo membro que ainda estavam pendentes na fila
    for id, u in pairs(self._pendingOutbox) do
        if u.memberName:lower() == memberLower then
            self._pendingOutbox[id] = nil
        end
    end

    local updateData = {
        updateId = updateId,
        memberName = memberName,
        dateJoin = dateJoin,
        birthday = birthday,
        recruiter = recruiter,
        altsCsv = altsCsv,
        isMain = isMain,
        role = role,
        timestamp = memberTimestamp,
        acknowledgedPeers = {},
        sendCount = 0,
        lastSent = 0,
        createdAt = GetTime and GetTime() or 0,
    }

    self._pendingOutbox[updateId] = updateData

    -- Envia NA HORA para todos os outros usuários do Addon
    self:sendUpdatePacket(updateData, true)

    if not force then
        local myName = self._myPlayerName or (UnitName and UnitName("player")) or "Você"
        local fieldsList = {}
        if birthday and birthday ~= "" then
            table.insert(fieldsList, L("SYNC_LOG_FIELD_BIRTHDAY", birthday))
        end
        if dateJoin and dateJoin ~= "" then
            table.insert(fieldsList, L("SYNC_LOG_FIELD_JOIN_DATE", dateJoin))
        end
        if recruiter and recruiter ~= "" then
            table.insert(fieldsList, L("SYNC_LOG_FIELD_RECRUITER", recruiter))
        end
        if role and role ~= "" then
            table.insert(fieldsList, L("SYNC_LOG_FIELD_ROLE", role))
        end
        if altsCsv and altsCsv ~= "" then
            table.insert(fieldsList, L("SYNC_LOG_FIELD_ALTS"))
        end

        local infoY = L("SYNC_LOG_DATA_OF", memberName)
        if #fieldsList > 0 then
            infoY = L("SYNC_LOG_FIELD_OF", table.concat(fieldsList, ", "), memberName)
        end

        self:printSyncNotification(L("SYNC_LOG_DATA_SYNCED", myName, infoY))
    end

    return true
end

--- Enfileira o pacote de dados formatado para transmissão segura através dos canais suportados.
--- Se immediate for true, envia imediatamente através da API nativa da Blizzard.
--- Formato do payload: DATA~updateId~memberName~dateJoin~birthday~recruiter~altsCsv~isMain~timestamp
---@param updateData table
---@param immediate boolean|nil
function SyncService:sendUpdatePacket(updateData, immediate)
    if not updateData then return end

    -- Suporte a retransmissão de atualizações de pedidos de fabricação
    if updateData.type == "ORDER" then
        local payload = updateData.payload

        if immediate then
            if IsInGuild and IsInGuild() then
                safeSendAddonMessage(SYNC_PREFIX, payload, "GUILD", nil, "NORMAL")
            elseif IsInRaid and IsInRaid() then
                safeSendAddonMessage(SYNC_PREFIX, payload, "RAID", nil, "NORMAL")
            elseif IsInGroup and IsInGroup() then
                safeSendAddonMessage(SYNC_PREFIX, payload, "PARTY", nil, "NORMAL")
            end
        elseif payload then
            if IsInGuild and IsInGuild() then
                self:enqueuePacket(payload, "GUILD")
            elseif IsInRaid and IsInRaid() then
                self:enqueuePacket(payload, "RAID")
            elseif IsInGroup and IsInGroup() then
                self:enqueuePacket(payload, "PARTY")
            else
                self:enqueuePacket(payload, "GUILD")
            end
        end

        updateData.sendCount = (updateData.sendCount or 0) + 1
        updateData.lastSent = GetTime and GetTime() or 0
        return
    end

    -- Suporte a retransmissão de atualizações de profissões e receitas
    if updateData.type == "PROFESSION" then
        local packets = updateData.packets or {}

        for idx, payload in ipairs(packets) do
            if immediate and idx == 1 then
                if IsInGuild and IsInGuild() then
                    safeSendAddonMessage(SYNC_PREFIX, payload, "GUILD", nil, "NORMAL")
                elseif IsInRaid and IsInRaid() then
                    safeSendAddonMessage(SYNC_PREFIX, payload, "RAID", nil, "NORMAL")
                elseif IsInGroup and IsInGroup() then
                    safeSendAddonMessage(SYNC_PREFIX, payload, "PARTY", nil, "NORMAL")
                end
            else
                if IsInGuild and IsInGuild() then
                    self:enqueuePacket(payload, "GUILD")
                elseif IsInRaid and IsInRaid() then
                    self:enqueuePacket(payload, "RAID")
                elseif IsInGroup and IsInGroup() then
                    self:enqueuePacket(payload, "PARTY")
                else
                    self:enqueuePacket(payload, "GUILD")
                end
            end
        end

        updateData.sendCount = (updateData.sendCount or 0) + 1
        updateData.lastSent = GetTime and GetTime() or 0
        return
    end

    local payload = string.format("DATA~%s~%s~%s~%s~%s~%s~%s~%d~%s",
        updateData.updateId,
        updateData.memberName,
        updateData.dateJoin or "",
        updateData.birthday or "",
        updateData.recruiter or "",
        updateData.altsCsv or "",
        updateData.isMain and "1" or "0",
        updateData.timestamp or 0,
        updateData.role or ""
    )

    if immediate then
        if IsInGuild and IsInGuild() then
            safeSendAddonMessage(SYNC_PREFIX, payload, "GUILD", nil, "NORMAL")
        elseif IsInRaid and IsInRaid() then
            safeSendAddonMessage(SYNC_PREFIX, payload, "RAID", nil, "NORMAL")
        elseif IsInGroup and IsInGroup() then
            safeSendAddonMessage(SYNC_PREFIX, payload, "PARTY", nil, "NORMAL")
        end
    else
        if IsInGuild and IsInGuild() then
            self:enqueuePacket(payload, "GUILD")
        elseif IsInRaid and IsInRaid() then
            self:enqueuePacket(payload, "RAID")
        elseif IsInGroup and IsInGroup() then
            self:enqueuePacket(payload, "PARTY")
        else
            self:enqueuePacket(payload, "GUILD")
        end
    end

    updateData.sendCount = (updateData.sendCount or 0) + 1
    updateData.lastSent = GetTime and GetTime() or 0
end

--- Envia confirmação (ACK) informando ao emissor que os dados foram recebidos com sucesso.
--- Formato do payload: ACK~updateId~senderName~memberName
---@param updateId string
---@param memberName string
function SyncService:sendAckPacket(updateId, memberName)
    if not updateId or updateId == "" then return end

    local myName = self._myPlayerName or (UnitName and UnitName("player")) or "Desconhecido"
    local payload = string.format("ACK~%s~%s~%s", updateId, myName, memberName or "")

    if IsInGuild and IsInGuild() then
        safeSendAddonMessage(SYNC_PREFIX, payload, "GUILD", nil, "NORMAL")
    elseif IsInRaid and IsInRaid() then
        safeSendAddonMessage(SYNC_PREFIX, payload, "RAID", nil, "NORMAL")
    elseif IsInGroup and IsInGroup() then
        safeSendAddonMessage(SYNC_PREFIX, payload, "PARTY", nil, "NORMAL")
    end
end

--- Verifica se todos os outros usuários atualmente online com o Addon já confirmaram o recebimento do update.
---@param updateData table
---@param activePeers table[]|nil
---@return boolean
function SyncService:isUpdateFullyAcknowledged(updateData, activePeers)
    if not updateData then return true end

    -- Para atualizações de pedidos de fabricação, se confirmado ou atingiu 4 tentativas, encerra
    if updateData.type == "ORDER" then
        if updateData.confirmed then return true end
        if (updateData.sendCount or 0) >= (updateData.maxAttempts or 4) then return true end
        return false
    end

    activePeers = activePeers or self:getActivePeers()

    -- Se não há nenhum outro peer ativo no momento, pausamos a retransmissão
    -- até que algum peer apareça online e confirme.
    if #activePeers == 0 then
        return false
    end

    local ackMap = updateData.acknowledgedPeers or {}
    for _, peer in ipairs(activePeers) do
        local peerLower = peer.name:lower()
        if not ackMap[peerLower] then
            return false
        end
    end

    return true
end

--- Processa mensagens recebidas pelo Addon no canal GM_SYNC.
---@param prefix string
---@param message string
---@param channel string
---@param sender string
function SyncService:onAddonMessage(prefix, message, channel, sender)
    if not prefix or not message or isSecretValue(prefix) or isSecretValue(message) or (sender and isSecretValue(sender)) then
        return
    end
    if type(message) ~= "string" or not sender or sender == "" then return end

    -- Ignora rigorosamente as mensagens enviadas pelo próprio jogador antes de qualquer processamento
    if self:isSelf(sender) then
        return
    end

    local pUpper = prefix:upper()
    if pUpper ~= SYNC_PREFIX then
        -- Se recebeu sinal de presença do LocationService de outro jogador, aproveita para registrar liveness do peer
        if pUpper == "GM_POS" or pUpper == "AJ_POS" then
            self:touchPeer(sender)
        end
        return
    end

    local senderClean = cleanName(sender)
    self:touchPeer(senderClean)

    local parts = { strsplit("~", message) }
    local tag = parts[1]
    local arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11 = parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8], parts[9], parts[10], parts[11], parts[12]

    -- =========================================================================
    -- RECEBIMENTO DE ANÚNCIO DE LOGIN / HELLO
    -- =========================================================================
    if tag == "LOGIN" or tag == "HELLO" then
        -- O peer já foi registrado em touchPeer() e onPeerLoggedIn foi disparado automaticamente
        return

    -- =========================================================================
    -- RECEBIMENTO DE DADOS CUSTOMIZADOS (DATA)
    -- =========================================================================
    elseif tag == "DATA" then
        local updateId = arg1
        local memberName = arg2
        local dateJoin = arg3 or ""
        local birthday = arg4 or ""
        local recruiter = arg5 or ""
        local altsCsv = arg6 or ""
        local isMainStr = arg7 or "1"
        local timestamp = tonumber(arg8) or 0
        local role = arg9 or ""

        if not updateId or updateId == "" or not memberName or memberName == "" then
            return
        end

        local mClean = cleanName(memberName)
        local member = self._memberService and self._memberService:getMember(mClean)
        local localTimestamp = (member and member.getCustomDataTimestamp and member:getCustomDataTimestamp()) or 0

        local isLocalLeader = (IsGuildLeader and IsGuildLeader() == true) or false
        local senderIsLeader = self:isSenderGuildLeader(senderClean)

        -- Verifica se o pacote traz uma atualização de Role para o Líder da Guilda confirmar
        local currentLocalRole = (member and member.getRole and member:getRole()) or ""
        local hasIncomingRoleChangeForLeader = false
        if isLocalLeader and role ~= "" and role ~= currentLocalRole then
            local conflictKey = mClean:lower() .. "~" .. role:upper()
            local lastResolvedTs = self._resolvedLeaderRoleConflicts and self._resolvedLeaderRoleConflicts[conflictKey]
            if not lastResolvedTs or timestamp > lastResolvedTs then
                hasIncomingRoleChangeForLeader = true
            end
        end

        -- Last-Write-Wins: Se o membro já possui dados localmente e a versão local é MAIS RECENTE que o pacote recebido,
        -- rejeita o pacote antigo para proteger as informações novas contra sobrescrita indevida!
        -- Exceções:
        -- 1. Se o remetente for o Líder da Guilda (senderIsLeader), os dados do Líder são a fonte oficial da guilda.
        -- 2. Se o receptor for o Líder da Guilda e houver uma alteração de Role pendente de confirmação.
        if member and localTimestamp > 0 and timestamp > 0 and localTimestamp > timestamp and not senderIsLeader and not hasIncomingRoleChangeForLeader then
            -- Confirma o recebimento para o peer parar de retransmitir o pacote antigo
            self:sendAckPacket(updateId, mClean)
            -- Transmite imediatamente a nossa versão mais recente para atualizar o peer desatualizado
            self:broadcastMemberCustomData(member, true)
            return
        end

        local wasNewMember = (member == nil)
        local prevDateJoin = (member and member:getDateJoin()) or ""
        local prevBday = (member and member:getBirthday()) or ""
        local prevRec = (member and member:getRecruiter()) or ""
        local prevRole = (member and member.getRole and member:getRole()) or ""
        local prevAltsCsv = (member and table.concat(member:getAlts() or {}, ",")) or ""
        local prevIsMain = (member and member:isMain() ~= false) or true

        if not member then
            member = Member:new({ name = mClean, isInGuild = true })
        end

        -- Regra 1: Data de entrada e Lista de Alts só sincronizam a partir do Líder da guilda!
        -- Se o remetente NÃO for o Líder da guilda, ignora dateJoin e lista de alts.
        if not senderIsLeader then
            dateJoin = ""
            altsCsv = ""
            isMainStr = "1"
        end

        local appliedTimestamp = (timestamp > 0) and timestamp or getCurrentTimestamp()

        -- Regra 4: Proteção do Banco de Dados do Líder da Guilda
        -- Em nenhuma hipótese as informações Syncada devem substituir diretamente as informações
        -- registradas no banco de dados do líder da guilda. Se conflitarem, exibe diálogo para decisão.
        -- No caso de Role/Função: toda vez que for atualizada e tiver alguma alteração, o Guild Líder precisa confirmar!
        if isLocalLeader and member then
            -- Verificação de Conflito em Aniversário
            local currentBday = member:getBirthday() or ""
            if currentBday ~= "" and birthday ~= "" and birthday ~= currentBday then
                local inCombat = (InCombatLockdown and InCombatLockdown()) or false
                if not inCombat and self._syncConflictView then
                    local curL = (_G.GM and _G.GM.L) or _G.L or L
                    self._syncConflictView:enqueueConflict({
                        memberName = mClean,
                        sender = senderClean,
                        fieldKey = "birthday",
                        fieldName = curL["SYNC_CONFLICT_FIELD_BDAY"] or "Data de Aniversário",
                        oldValue = currentBday,
                        newValue = birthday,
                        timestamp = appliedTimestamp,
                        member = member,
                    })
                    -- Mantém o valor atual inalterado até a decisão do Líder
                    birthday = currentBday
                else
                    -- Não foi possível perguntar: apenas concatena a informação
                    birthday = currentBday .. " | " .. birthday
                end
            end

            -- Verificação de Conflito em Recrutador
            local currentRec = member:getRecruiter() or ""
            if currentRec ~= "" and recruiter ~= "" and recruiter ~= currentRec then
                local inCombat = (InCombatLockdown and InCombatLockdown()) or false
                if not inCombat and self._syncConflictView then
                    local curL = (_G.GM and _G.GM.L) or _G.L or L
                    self._syncConflictView:enqueueConflict({
                        memberName = mClean,
                        sender = senderClean,
                        fieldKey = "recruiter",
                        fieldName = curL["SYNC_CONFLICT_FIELD_REC"] or "Recrutador",
                        oldValue = currentRec,
                        newValue = recruiter,
                        timestamp = appliedTimestamp,
                        member = member,
                    })
                    -- Mantém o valor atual inalterado até a decisão do Líder
                    recruiter = currentRec
                else
                    -- Não foi possível perguntar: apenas concatena a informação
                    recruiter = currentRec .. " | " .. recruiter
                end
            end

            -- Verificação de Alteração em Função (Role) - Exige confirmação do Líder sempre que houver alteração
            local currentRole = (member.getRole and member:getRole()) or ""
            if role ~= "" and role ~= currentRole then
                local conflictKey = mClean:lower() .. "~" .. role:upper()
                local lastResolvedTs = self._resolvedLeaderRoleConflicts and self._resolvedLeaderRoleConflicts[conflictKey]
                if not lastResolvedTs or appliedTimestamp > lastResolvedTs then
                    if self._syncConflictView then
                        local curL = (_G.GM and _G.GM.L) or _G.L or L
                        local emptyRoleLabel = curL["STATS_UNASSIGNED"] or "Sem Função"
                        self._syncConflictView:enqueueConflict({
                            memberName = mClean,
                            sender = senderClean,
                            fieldKey = "role",
                            fieldName = curL["SYNC_CONFLICT_FIELD_ROLE"] or "Função",
                            oldValue = (currentRole ~= "" and currentRole) or emptyRoleLabel,
                            newValue = role,
                            rawOldValue = currentRole,
                            rawNewValue = role,
                            timestamp = appliedTimestamp,
                            member = member,
                        })
                    end
                end
                -- Mantém a função atual do banco do Líder até a confirmação do Líder
                role = currentRole
            elseif role ~= "" and role == currentRole then
                if member.setRolePendingLeaderConfirm then
                    member:setRolePendingLeaderConfirm(false)
                end
            end
        end

        -- Aplica os dados permitidos:
        -- 1. Data de Entrada (somente se remetente for o Líder)
        if senderIsLeader and dateJoin and dateJoin ~= "" then
            member:setDateJoin(dateJoin)
        end

        -- 2. Função / Role (os outros membros salvam a partir do que existe no addon do Guild Líder)
        if senderIsLeader then
            member:setRole(role or "")
            if member.setRolePendingLeaderConfirm then
                member:setRolePendingLeaderConfirm(false)
            end
        elseif isLocalLeader and role and role ~= "" then
            member:setRole(role)
            if member.setRolePendingLeaderConfirm then
                member:setRolePendingLeaderConfirm(false)
            end
        end

        -- 3. Aniversário
        if birthday and birthday ~= "" then
            member:setBirthday(birthday)
        end

        -- 4. Recrutador
        if recruiter and recruiter ~= "" then
            member:setRecruiter(recruiter)
        end

        -- 5. Alts Vinculados e Main/Alt (somente se remetente for o Líder)
        local altsList = {}
        if senderIsLeader and altsCsv and altsCsv ~= "" then
            for altName in string.gmatch(altsCsv, "([^,]+)") do
                local cAlt = cleanName(altName)
                if cAlt ~= "" and cAlt:lower() ~= mClean:lower() then
                    table.insert(altsList, cAlt)
                end
            end
            member:setAlts(altsList)
            member:setMain(isMainStr == "1")
        end

        if member.setCustomDataTimestamp then
            member:setCustomDataTimestamp(appliedTimestamp)
        end

        -- Atualiza a assinatura local para não retransmitir de volta o que acabou de receber
        local isMainBool = (isMainStr == "1")
        local effectiveRole = (member.getRole and member:getRole()) or ""
        self._lastMemberSignatures[mClean:lower()] = makeDataSignature(dateJoin, birthday, recruiter, altsCsv, isMainBool, effectiveRole)

        local newDateJoin = member:getDateJoin() or ""
        local newBday = member:getBirthday() or ""
        local newRec = member:getRecruiter() or ""
        local newAltsCsv = table.concat(member:getAlts() or {}, ",")
        local newIsMain = (member:isMain() ~= false)
        local dataChanged = wasNewMember
            or (newDateJoin ~= prevDateJoin)
            or (newBday ~= prevBday)
            or (newRec ~= prevRec)
            or (effectiveRole ~= prevRole)
            or (newAltsCsv ~= prevAltsCsv)
            or (newIsMain ~= prevIsMain)
        local agendaDataChanged = wasNewMember or (newDateJoin ~= prevDateJoin) or (newBday ~= prevBday)

        if dataChanged then
            -- Persiste no banco de dados local com normalização e sem retransmissão circular
            if self._memberService then
                self._memberService:saveMember(member, true)

                -- Mantém a reciprocidade da família de alts se houver lista (skipSync = true evita flood)
                if senderIsLeader and #altsList > 0 and self._memberService.syncAltFamily then
                    local familyNames = { mClean }
                    for _, aName in ipairs(altsList) do
                        table.insert(familyNames, aName)
                    end
                    local mainName = isMainBool and mClean or altsList[1]
                    self._memberService:syncAltFamily(familyNames, mainName, true)
                end
            end

            -- Atualiza telas da interface em tempo real se estiverem visíveis
            self:refreshActiveViews(mClean, agendaDataChanged)
        end

        -- Exibe no chat local a notificação requerida quando alguém envia informação pra sincronizar
        local isNewUpdate = not self._processedUpdateIds[updateId]
        self._processedUpdateIds[updateId] = GetTime and GetTime() or 0

        if isNewUpdate then
            local fieldsList = {}
            if birthday and birthday ~= "" then
                table.insert(fieldsList, L("SYNC_LOG_FIELD_BIRTHDAY", birthday))
            end
            if dateJoin and dateJoin ~= "" then
                table.insert(fieldsList, L("SYNC_LOG_FIELD_JOIN_DATE", dateJoin))
            end
            if recruiter and recruiter ~= "" then
                table.insert(fieldsList, L("SYNC_LOG_FIELD_RECRUITER", recruiter))
            end
            if (senderIsLeader or isLocalLeader) and role and role ~= "" then
                table.insert(fieldsList, L("SYNC_LOG_FIELD_ROLE", role))
            end
            if altsCsv and altsCsv ~= "" then
                table.insert(fieldsList, L("SYNC_LOG_FIELD_ALTS"))
            end

            local infoY = L("SYNC_LOG_DATA_OF", mClean)
            if #fieldsList > 0 then
                infoY = L("SYNC_LOG_FIELD_OF", table.concat(fieldsList, ", "), mClean)
            end

            self:printSyncNotification(L("SYNC_LOG_DATA_SYNCED", senderClean, infoY))
        end

        -- SEMPRE responde com ACK ao emissor informando que o receptor recebeu
        self:sendAckPacket(updateId, mClean)

    -- =========================================================================
    -- RECEBIMENTO DE CONFIRMAÇÃO (ACK)
    -- =========================================================================
    elseif tag == "ACK" then
        local updateId = arg1
        local ackSender = arg2 or senderClean
        local memberName = arg3 or ""

        if not updateId or updateId == "" then return end

        local pending = self._pendingOutbox[updateId]
        if pending then
            local peerLower = cleanName(ackSender):lower()
            pending.acknowledgedPeers[peerLower] = true

            -- Verifica se todos os que têm o Addon já receberam todas as atualizações
            if self:isUpdateFullyAcknowledged(pending) then
                self._pendingOutbox[updateId] = nil
            end
        end

    -- =========================================================================
    -- SOLICITAÇÃO DE SINCRONIZAÇÃO GERAL (SYNC_REQ)
    -- =========================================================================
    elseif tag == "SYNC_REQ" then
        -- Quando um novo membro conecta e pede sincronização, envia dados que temos para ele
        self:syncWithPeer(senderClean)

    -- =========================================================================
    -- RECEBIMENTO DE RESUMO DE PROFISSÃO (PROF_SUM)
    -- =========================================================================
    elseif tag == "PROF_SUM" then
        local updateId, pName, profKey, rank, maxRank, timestamp, totalChunks
        if arg1 and arg1:find("^PROF_") then
            updateId = arg1
            pName = arg2
            profKey = arg3
            rank = tonumber(arg4) or 0
            maxRank = tonumber(arg5) or 300
            timestamp = tonumber(arg6) or 0
            totalChunks = tonumber(arg7) or 0
        else
            pName = arg1
            profKey = arg2
            rank = tonumber(arg3) or 0
            maxRank = tonumber(arg4) or 300
            timestamp = tonumber(arg5) or 0
            totalChunks = 0
            updateId = string.format("PROF_%s_%s_%d", pName or "", profKey or "", timestamp)
        end

        if not pName or pName == "" or not profKey then return end

        local mClean = cleanName(pName)
        local member = self._memberService and self._memberService:getMember(mClean)
        local existingProf = member and member.getProfession and member:getProfession(profKey)
        local localProfTimestamp = (existingProf and existingProf.updatedAt) or (member and member.getProfessionsTimestamp and member:getProfessionsTimestamp()) or 0

        -- Last-Write-Wins: Se o membro já possui dados localmente e a versão local é MAIS RECENTE que o pacote recebido,
        -- rejeita o pacote antigo, confirma o recebimento para o peer parar de retransmitir,
        -- e transmite imediatamente a nossa versão mais recente para atualizar o colega!
        if member and localProfTimestamp > 0 and timestamp > 0 and localProfTimestamp > timestamp then
            self:sendAckPacket(updateId, mClean)
            self:broadcastMemberProfessions(member, profKey, true)
            return
        end

        if member and existingProf and localProfTimestamp == timestamp and existingProf.rank == rank and existingProf.maxRank == maxRank and totalChunks == 0 then
            self:sendAckPacket(updateId, mClean)
            return
        end

        if not member then
            member = Member:new({ name = mClean, isInGuild = true })
        end

        local currentRecipes = {}
        if existingProf and existingProf.recipes then
            currentRecipes = existingProf.recipes
        end

        local appliedTs = (timestamp > 0) and timestamp or getCurrentTimestamp()
        member:setProfession(profKey, rank, maxRank, currentRecipes, appliedTs)

        -- Se for uma profissão primária com rank > 0, assegura a regra de no máximo 2 primárias no WoW Classic
        local isPrimary = false
        local uProfKey = tostring(profKey):upper()
        if ProfessionData and ProfessionData.PRIMARY_KEYS then
            for _, pk in ipairs(ProfessionData.PRIMARY_KEYS) do
                if pk == uProfKey then isPrimary = true break end
            end
        end

        if isPrimary and rank > 0 and ProfessionData and ProfessionData.PRIMARY_KEYS then
            local activePrimaries = {}
            for _, pk in ipairs(ProfessionData.PRIMARY_KEYS) do
                local p = member:getProfession(pk)
                if p and (tonumber(p.rank) or 0) > 0 then
                    table.insert(activePrimaries, { key = pk, updatedAt = tonumber(p.updatedAt) or 0 })
                end
            end
            if #activePrimaries > 2 then
                -- Mais de 2 primárias ativas detectadas! Mantém as 2 mais recentes e purga as antigas
                table.sort(activePrimaries, function(a, b) return (a.updatedAt or 0) > (b.updatedAt or 0) end)
                for i = 3, #activePrimaries do
                    member:removeProfession(activePrimaries[i].key)
                end
            end
        end

        if self._memberService then
            self._memberService:saveMember(member, true)
        end
        if _G.GM and _G.GM.professionService and _G.GM.professionService.notifyChanged then
            _G.GM.professionService:notifyChanged()
        end
        self:refreshActiveViews(mClean, false)

        -- Se não há blocos de receitas a esperar (totalChunks == 0), finaliza e confirma com ACK
        if totalChunks == 0 then
            self:sendAckPacket(updateId, mClean)

            local isNew = not self._processedUpdateIds[updateId]
            self._processedUpdateIds[updateId] = GetTime and GetTime() or 0
            if isNew then
                local profDef = ProfessionData and ProfessionData.PROFESSIONS and ProfessionData.PROFESSIONS[profKey]
                local pDisp = profDef and profDef.name or profKey
                local infoStr = string.format("%s (%d/%d) de %s", pDisp, rank, maxRank, mClean)
                self:printSyncNotification(L("SYNC_LOG_DATA_SYNCED", senderClean, infoStr))
            end
        end

    -- =========================================================================
    -- RECEBIMENTO DE RECEITAS DE PROFISSÃO (PROF_REC)
    -- =========================================================================
    elseif tag == "PROF_REC" then
        local updateId, pName, profKey, chunkIdx, totalChunks, idsCsv
        if arg1 and arg1:find("^PROF_") then
            updateId = arg1
            pName = arg2
            profKey = arg3
            chunkIdx = tonumber(arg4) or 1
            totalChunks = tonumber(arg5) or 1
            idsCsv = arg6 or ""
        else
            pName = arg1
            profKey = arg2
            chunkIdx = tonumber(arg3) or 1
            totalChunks = tonumber(arg4) or 1
            idsCsv = arg5 or ""
            updateId = string.format("PROF_%s_%s", pName or "", profKey or "")
        end

        if not pName or pName == "" or not profKey or idsCsv == "" then return end

        local mClean = cleanName(pName)
        local member = self._memberService and self._memberService:getMember(mClean)
        if not member then
            member = Member:new({ name = mClean, isInGuild = true })
        end

        for rId in string.gmatch(idsCsv, "([^,]+)") do
            local num = tonumber(rId)
            member:addRecipe(profKey, num or rId)
        end

        -- Quando o último chunk chega (ou único), salva, atualiza views e envia ACK
        if chunkIdx >= totalChunks then
            if self._memberService then
                self._memberService:saveMember(member, true)
            end
            if _G.GM and _G.GM.professionService and _G.GM.professionService.notifyChanged then
                _G.GM.professionService:notifyChanged()
            end
            self:refreshActiveViews(mClean, false)
            self:sendAckPacket(updateId, mClean)

            local isNew = not self._processedUpdateIds[updateId]
            self._processedUpdateIds[updateId] = GetTime and GetTime() or 0
            if isNew then
                local profDef = ProfessionData and ProfessionData.PROFESSIONS and ProfessionData.PROFESSIONS[profKey]
                local pDisp = profDef and profDef.name or profKey
                local recCount = (member.getCanonicalRecipeIds and #member:getCanonicalRecipeIds(profKey)) or 0
                local pProf = member:getProfession(profKey)
                local pRank = pProf and pProf.rank or 0
                local pMax = pProf and pProf.maxRank or 300
                local infoStr = string.format("%s (%d/%d, %d receitas) de %s", pDisp, pRank, pMax, recCount, mClean)
                self:printSyncNotification(L("SYNC_LOG_DATA_SYNCED", senderClean, infoStr))
            end
        end

    -- =========================================================================
    -- RECEBIMENTO DE PEDIDO DE FABRICAÇÃO (ORDER)
    -- =========================================================================
    elseif tag == "ORDER" then
        local p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13 = strsplit("~", message)
        local action = p2 or "UPDATE"
        local orderId = p3
        local requester = p4 or ""
        local crafter = p5 or ""
        local profKey = p6 or "ALCHEMY"
        local recipeId = p7 or 0
        local recipeName = p8 or ""
        local itemCount = tonumber(p9) or 1
        local tipCopper = tonumber(p10) or 0
        local status = p11 or "PENDING"
        local acceptedBy = p12 or ""
        local updatedAt = tonumber(p13) or 0

        if not orderId or orderId == "" then return end

        local orderRepo = (_G.GM and _G.GM.craftOrderRepository)
        local oldStatus = nil
        if orderRepo then
            if action == "DELETE" or action == "CANCEL" or status == "CANCELLED" then
                orderRepo:delete(orderId)
                if _G.GM and _G.GM.professionService and _G.GM.professionService.notifyChanged then
                    _G.GM.professionService:notifyChanged()
                end
            else
                local order = orderRepo:findById(orderId)
                if not order then
                    order = CraftOrder:new({
                        id = orderId,
                        requester = requester,
                        crafter = crafter,
                        professionKey = profKey,
                        recipeId = recipeId,
                        recipeName = recipeName,
                        itemCount = itemCount,
                        tipCopper = tipCopper,
                        status = status,
                        acceptedBy = acceptedBy,
                        updatedAt = updatedAt,
                    })
                else
                    oldStatus = order:getStatus()
                    order:setCrafter(crafter)
                    order:setItemCount(itemCount)
                    order:setTipCopper(tipCopper)
                    order:setStatus(status)
                    order:setAcceptedBy(acceptedBy)
                end
                orderRepo:save(order)
            end
        end

        -- Envia confirmação (ORDER_ACK) via canal de guilda para o remetente parar a retransmissão
        local myName = self._myPlayerName or (UnitName and UnitName("player")) or "Desconhecido"
        local ackPayload = string.format("ORDER_ACK~%s~%s~%s", orderId, status, myName)
        if IsInGuild and IsInGuild() then
            safeSendAddonMessage(SYNC_PREFIX, ackPayload, "GUILD", nil, "NORMAL")
        elseif IsInRaid and IsInRaid() then
            safeSendAddonMessage(SYNC_PREFIX, ackPayload, "RAID", nil, "NORMAL")
        elseif IsInGroup and IsInGroup() then
            safeSendAddonMessage(SYNC_PREFIX, ackPayload, "PARTY", nil, "NORMAL")
        end

        -- Se a ordem foi concluída (COMPLETED) e o jogador local for o solicitante, notifica no chat e com som
        if status == "COMPLETED" and oldStatus ~= "COMPLETED" then
            local isMyOrder = false
            if _G.GM and _G.GM.professionView and _G.GM.professionView.matchesPlayer then
                isMyOrder = _G.GM.professionView:matchesPlayer(requester)
            else
                local myName = cleanName(self._myPlayerName or (UnitName and UnitName("player"))):lower()
                isMyOrder = (cleanName(requester):lower() == myName or cleanName(requester):lower():find("^" .. myName))
            end

            if isMyOrder then
                local crafterDisplay = acceptedBy ~= "" and acceptedBy or (crafter ~= "" and crafter or senderClean)
                local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
                local fmt = L["ORDER_COMPLETED_NOTICE"] or "Seu pedido de %s foi concluído pelo artesão %s!"
                local msg = string.format("|cff00ff00[GuildManager]|r " .. fmt, recipeName ~= "" and recipeName or "Item", crafterDisplay)
                print(msg)
                if PlaySound then
                    pcall(PlaySound, SOUNDKIT.UI_GUILD_BANK_DEPOSIT_MONEY or 8959)
                end
                if RaidNotice_AddMessage and RaidWarningFrame then
                    pcall(RaidNotice_AddMessage, RaidWarningFrame, msg, { r = 0.0, g = 1.0, b = 0.0 })
                end
            end
        end

        -- Notifica os listeners do serviço
        if _G.GM and _G.GM.professionService and _G.GM.professionService.notifyChanged then
            _G.GM.professionService:notifyChanged()
        end

        -- Atualiza IMEDIATAMENTE a visualização da tela de pedidos se estiver aberta
        if _G.GM and _G.GM.professionView and _G.GM.professionView.isShown and _G.GM.professionView:isShown() then
            if _G.GM.professionView.refreshOrders then
                _G.GM.professionView:refreshOrders()
            end
        end

        self:refreshActiveViews(requester, false)

    -- =========================================================================
    -- CONFIRMAÇÃO DE RECEBIMENTO DE PEDIDO (ORDER_ACK)
    -- =========================================================================
    elseif tag == "ORDER_ACK" then
        local orderId = arg1
        if orderId and orderId ~= "" then
            for uId, uData in pairs(self._pendingOutbox) do
                if uData.type == "ORDER" and uData.orderId == orderId then
                    uData.confirmed = true
                    self._pendingOutbox[uId] = nil
                end
            end
        end

    -- =========================================================================
    -- SOLICITAÇÃO DE ESTADO DOS PEDIDOS (ORDER_REQ)
    -- =========================================================================
    elseif tag == "ORDER_REQ" then
        if _G.GM and _G.GM.craftOrderRepository and _G.GM.craftOrderRepository.findAll then
            local orders = _G.GM.craftOrderRepository:findAll()
            for _, ord in ipairs(orders) do
                if ord:getStatus() ~= "CANCELLED" then
                    self:broadcastCraftOrder(ord, "UPDATE", false)
                end
            end
        end

    -- =========================================================================
    -- PROPOSTA DE GRUPO (GRP_PROP: Criador -> Líder da Guilda)
    -- =========================================================================
    elseif tag == "GRP_PROP" then
        local isLocalLeader = (IsGuildLeader and IsGuildLeader() == true) or false
        if not isLocalLeader then return end

        local action = arg1 or "UPDATE"
        local groupId = arg2
        if not groupId or groupId == "" then return end

        if action == "DELETE" then
            if _G.GM and _G.GM.groupRepository then
                _G.GM.groupRepository:delete(groupId)
            end
            local payload = string.format("GRP_DATA~DELETE~%s", groupId)
            safeSendAddonMessage(SYNC_PREFIX, payload, "GUILD", nil, "NORMAL")
            self:refreshActiveViews()
            return
        end

        local gType = arg3 or "DUNGEON"
        local gTime = arg4 or ""
        local gLeader = arg5 or ""
        local gCreator = arg6 or ""
        local gUpdatedAt = tonumber(arg7) or time()
        local gName = arg8 or "Novo Grupo"
        local gDesc = arg9 or ""
        local membersCsv = arg10 or ""

        local membersList = {}
        if membersCsv ~= "" then
            for item in membersCsv:gmatch("[^;]+") do
                local n, r, c, l = item:match("^(.-)/(.-)/(.-)/(.-)$")
                if n and n ~= "" then
                    table.insert(membersList, {
                        name = n,
                        role = r or "NONE",
                        class = c or "",
                        level = tonumber(l) or 1,
                        addedAt = time(),
                    })
                end
            end
        end

        local group = Group:new({
            id = groupId,
            name = gName,
            type = gType,
            time = gTime,
            leader = gLeader,
            creator = gCreator,
            description = gDesc,
            note = gTime,
            updatedAt = gUpdatedAt,
            members = membersList,
        })

        if _G.GM and _G.GM.groupRepository then
            _G.GM.groupRepository:save(group)
        end

        -- Líder replica para toda a guilda como verdade oficial (GRP_DATA)
        local payload = string.format("GRP_DATA~%s~%s~%s~%s~%s~%s~%d~%s~%s~%s",
            action, groupId, gType, gTime, gLeader, gCreator, gUpdatedAt, gName, gDesc, membersCsv)
        safeSendAddonMessage(SYNC_PREFIX, payload, "GUILD", nil, "NORMAL")
        self:refreshActiveViews()

    -- =========================================================================
    -- DADOS OFICIAIS DE GRUPO (GRP_DATA: Líder da Guilda -> Todos os membros)
    -- =========================================================================
    elseif tag == "GRP_DATA" then
        if not self:isSenderGuildLeader(senderClean) then return end

        local action = arg1 or "UPDATE"
        local groupId = arg2
        if not groupId or groupId == "" then return end

        if action == "DELETE" then
            if _G.GM and _G.GM.groupRepository then
                _G.GM.groupRepository:delete(groupId)
            end
            self:refreshActiveViews()
            return
        end

        local gType = arg3 or "DUNGEON"
        local gTime = arg4 or ""
        local gLeader = arg5 or ""
        local gCreator = arg6 or ""
        local gUpdatedAt = tonumber(arg7) or time()
        local gName = arg8 or "Novo Grupo"
        local gDesc = arg9 or ""
        local membersCsv = arg10 or ""

        local membersList = {}
        if membersCsv ~= "" then
            for item in membersCsv:gmatch("[^;]+") do
                local n, r, c, l = item:match("^(.-)/(.-)/(.-)/(.-)$")
                if n and n ~= "" then
                    table.insert(membersList, {
                        name = n,
                        role = r or "NONE",
                        class = c or "",
                        level = tonumber(l) or 1,
                        addedAt = time(),
                    })
                end
            end
        end

        local group = Group:new({
            id = groupId,
            name = gName,
            type = gType,
            time = gTime,
            leader = gLeader,
            creator = gCreator,
            description = gDesc,
            note = gTime,
            updatedAt = gUpdatedAt,
            members = membersList,
        })

        if _G.GM and _G.GM.groupRepository then
            _G.GM.groupRepository:save(group)
        end

        self:refreshActiveViews()

    -- =========================================================================
    -- PROPOSTA DE CARD LFG (LFG_PROP: Jogador -> Líder da Guilda)
    -- =========================================================================
    elseif tag == "LFG_PROP" then
        local isLocalLeader = (IsGuildLeader and IsGuildLeader() == true) or false
        if not isLocalLeader then return end

        local action = arg1 or "UPDATE"
        local cardId = arg2
        if not cardId or cardId == "" then return end

        if action == "DELETE" then
            if _G.GM and _G.GM.lfgRepository then
                _G.GM.lfgRepository:delete(cardId)
            end
            local payload = string.format("LFG_DATA~DELETE~%s", cardId)
            safeSendAddonMessage(SYNC_PREFIX, payload, "GUILD", nil, "NORMAL")
            self:refreshActiveViews()
            return
        end

        local cType = arg3 or "DUNGEON"
        local cTime = arg4 or ""
        local cCreator = arg5 or senderClean
        local cClass = arg6 or ""
        local cLevel = tonumber(arg7) or 1
        local cCreatedAt = tonumber(arg8) or time()
        local cDesc = arg9 or ""

        local card = LFGCard:new({
            id = cardId,
            type = cType,
            time = cTime,
            creator = cCreator,
            creatorClass = cClass,
            creatorLevel = cLevel,
            createdAt = cCreatedAt,
            description = cDesc,
        })

        if _G.GM and _G.GM.lfgRepository then
            _G.GM.lfgRepository:save(card)
        end

        -- Líder replica para toda a guilda (LFG_DATA)
        local payload = string.format("LFG_DATA~%s~%s~%s~%s~%s~%s~%d~%d~%s",
            action, cardId, cType, cTime, cCreator, cClass, cLevel, cCreatedAt, cDesc)
        safeSendAddonMessage(SYNC_PREFIX, payload, "GUILD", nil, "NORMAL")
        self:refreshActiveViews()

    -- =========================================================================
    -- DADOS OFICIAIS DE CARD LFG (LFG_DATA: Líder da Guilda -> Todos os membros)
    -- =========================================================================
    elseif tag == "LFG_DATA" then
        if not self:isSenderGuildLeader(senderClean) then return end

        local action = arg1 or "UPDATE"
        local cardId = arg2
        if not cardId or cardId == "" then return end

        if action == "DELETE" then
            if _G.GM and _G.GM.lfgRepository then
                _G.GM.lfgRepository:delete(cardId)
            end
            self:refreshActiveViews()
            return
        end

        local cType = arg3 or "DUNGEON"
        local cTime = arg4 or ""
        local cCreator = arg5 or ""
        local cClass = arg6 or ""
        local cLevel = tonumber(arg7) or 1
        local cCreatedAt = tonumber(arg8) or time()
        local cDesc = arg9 or ""

        local card = LFGCard:new({
            id = cardId,
            type = cType,
            time = cTime,
            creator = cCreator,
            creatorClass = cClass,
            creatorLevel = cLevel,
            createdAt = cCreatedAt,
            description = cDesc,
        })

        if _G.GM and _G.GM.lfgRepository then
            _G.GM.lfgRepository:save(card)
        end

        self:refreshActiveViews()
    end
end

--- Executa a atualização das janelas abertas de forma otimizada.
---@param memberName string
---@param refreshAgenda boolean|nil
function SyncService:executeRefreshViews(memberName, refreshAgenda)
    -- Atualiza tela de auditoria se aberta (sem re-escanear GetGuildRosterInfo)
    if _G.GM and _G.GM.auditController and _G.GM.auditController.refreshAudit then
        local aView = _G.GM.auditView
        if aView and aView.isShown and aView:isShown() then
            _G.GM.auditController:refreshAudit(true)
        end
    end

    -- Atualiza card do membro se aberto
    if memberName and memberName ~= "" and _G.GM and _G.GM.memberView and _G.GM.memberView.isShown and _G.GM.memberView:isShown() then
        local cur = _G.GM.memberView._currentMember
        if cur and cur:getName() and cur:getName():lower() == memberName:lower() then
            local refreshed = self._memberService and self._memberService:getMember(memberName)
            if refreshed then
                _G.GM.memberView:showMember(refreshed)
            end
        end
    end

    -- Atualiza lista de aniversariantes/promoções da agenda se aberta e se houve mudança relevante
    if refreshAgenda ~= false and _G.GM and _G.GM.agendaView and _G.GM.agendaView.isShown and _G.GM.agendaView:isShown() then
        if _G.GM.agendaController and _G.GM.agendaController.refreshAgenda then
            _G.GM.agendaController:refreshAgenda(true)
        end
    end

    -- Atualiza tela de profissões e pedidos se aberta
    if _G.GM and _G.GM.professionController and _G.GM.professionController.refreshView then
        local pView = _G.GM.professionView
        if pView and pView.isShown and pView:isShown() then
            _G.GM.professionController:refreshView()
        end
    end

    -- Atualiza tela de grupos e procurando grupo (LFG) se aberta
    if _G.GM and _G.GM.groupController and _G.GM.groupController.refreshGroups then
        local gView = _G.GM.groupView
        if gView and gView.isShown and gView:isShown() then
            _G.GM.groupController:refreshGroups()
        end
    end
end

--- Atualiza as janelas abertas para refletir os novos dados com debounce suave (600ms),
--- eliminando picos de CPU e congelamentos quando múltiplos pacotes chegam em lote.
---@param memberName string
---@param refreshAgenda boolean|nil
function SyncService:refreshActiveViews(memberName, refreshAgenda)
    if memberName and memberName ~= "" then
        self._lastRefreshMemberName = memberName
    end
    if refreshAgenda ~= false then
        self._pendingRefreshAgenda = true
    end
    if self._refreshDebouncePending then
        return
    end

    if C_Timer and C_Timer.After then
        self._refreshDebouncePending = true
        C_Timer.After(0.6, function()
            self._refreshDebouncePending = false
            local targetName = self._lastRefreshMemberName or memberName or ""
            local shouldRefreshAgenda = (self._pendingRefreshAgenda == true)
            self._lastRefreshMemberName = nil
            self._pendingRefreshAgenda = false
            self:executeRefreshViews(targetName, shouldRefreshAgenda)
        end)
    else
        local shouldRefreshAgenda = (self._pendingRefreshAgenda == true)
        self._pendingRefreshAgenda = false
        self:executeRefreshViews(memberName, shouldRefreshAgenda)
    end
end

--- Transmite as informações de profissões e receitas de um membro para os colegas da guilda.
--- Divide as receitas em blocos seguros (~20 IDs por pacote) para respeitar o limite de 255 bytes da Blizzard.
--- Mantém retransmissão contínua com confirmação ACK até que todos os pares recebam.
---@param member Member|nil
---@param specificProfKey string|nil
---@param force boolean|nil
---@return boolean @Retorna true se algum pacote foi transmitido/enfileirado
function SyncService:broadcastMemberProfessions(member, specificProfKey, force)
    local myName = self._myPlayerName or (UnitName and UnitName("player"))
    member = member or (self._memberService and self._memberService:getMember(myName))
    if not member or not member.getProfessions then return false end

    local memberName = cleanName(member:getName())
    if memberName == "" then return false end

    local profs = member:getProfessions()
    if type(profs) ~= "table" then return false end

    local enqueuedAny = false
    local memberLower = memberName:lower()

    -- Garante que o membro possua no máximo 2 profissões primárias ativas (WoW Classic)
    if ProfessionData and ProfessionData.PRIMARY_KEYS then
        local activePrimaries = {}
        for _, pk in ipairs(ProfessionData.PRIMARY_KEYS) do
            local p = member:getProfession(pk)
            if p and (tonumber(p.rank) or 0) > 0 then
                table.insert(activePrimaries, { key = pk, updatedAt = tonumber(p.updatedAt) or 0 })
            end
        end
        if #activePrimaries > 2 then
            table.sort(activePrimaries, function(a, b) return (a.updatedAt or 0) > (b.updatedAt or 0) end)
            for i = 3, #activePrimaries do
                member:removeProfession(activePrimaries[i].key)
            end
            if self._memberService then
                self._memberService:saveMember(member, true)
            end
        end
    end

    for profKey, profData in pairs(profs) do
        if not specificProfKey or specificProfKey == profKey then
            local rank = tonumber(profData.rank) or 0
            local maxRank = profData.maxRank or 300
            local recipeIds = {}
            if member.getCanonicalRecipeIds then
                recipeIds = member:getCanonicalRecipeIds(profKey) or {}
            elseif type(profData.recipes) == "table" then
                local seen = {}
                for rId, v in pairs(profData.recipes) do
                    if v == true then
                        local n = tonumber(rId) or rId
                        if not seen[n] then
                            seen[n] = true
                            table.insert(recipeIds, n)
                        end
                    end
                end
            end

            if rank > 0 then
                local profTimestamp = profData.updatedAt or (member.getProfessionsTimestamp and member:getProfessionsTimestamp()) or 0
                if profTimestamp == 0 then
                    profTimestamp = getCurrentTimestamp()
                    profData.updatedAt = profTimestamp
                    if member.setProfessionsTimestamp then
                        member:setProfessionsTimestamp(profTimestamp)
                    end
                    if self._memberService then
                        self._memberService:saveMember(member, true)
                    end
                end

                -- Assinatura para evitar envios redundantes se nada mudou
                local sigKey = string.format("%s_%s", memberLower, profKey)
                local sig = string.format("%d~%d~%d~%s", rank, maxRank, profTimestamp, table.concat(recipeIds, ","))
                if not force and self._lastProfSignatures and self._lastProfSignatures[sigKey] == sig then
                    -- Nada mudou
                else
                    if self._lastProfSignatures then
                        self._lastProfSignatures[sigKey] = sig
                    end

                    local CHUNK_SIZE = 20
                    local totalChunks = math.ceil(#recipeIds / CHUNK_SIZE)
                    if #recipeIds == 0 then totalChunks = 0 end

                    local randomSuffix = math.random(1000, 9999)
                    local updateId = string.format("PROF_%s_%s_%d_%d", memberName, profKey, profTimestamp, randomSuffix)

                    -- Cancela envios anteriores da mesma profissão deste membro que estavam na outbox
                    for id, u in pairs(self._pendingOutbox) do
                        if u.type == "PROFESSION" and u.memberName:lower() == memberLower and u.profKey == profKey then
                            self._pendingOutbox[id] = nil
                        end
                    end

                    local packetsList = {}

                    -- 1. Pacote de Resumo da Profissão:
                    -- PROF_SUM~updateId~memberName~profKey~rank~maxRank~timestamp~totalChunks
                    local sumPayload = string.format("PROF_SUM~%s~%s~%s~%d~%d~%d~%d",
                        updateId, memberName, profKey, rank, maxRank, profTimestamp, totalChunks)
                    table.insert(packetsList, sumPayload)

                    -- 2. Pacotes de Receitas Conhecidas:
                    -- PROF_REC~updateId~memberName~profKey~chunk~total~csvIds
                    if totalChunks > 0 then
                        for c = 1, totalChunks do
                            local startIdx = (c - 1) * CHUNK_SIZE + 1
                            local endIdx = math.min(c * CHUNK_SIZE, #recipeIds)
                            local chunkIds = {}
                            for i = startIdx, endIdx do
                                table.insert(chunkIds, tostring(recipeIds[i]))
                            end
                            local recPayload = string.format("PROF_REC~%s~%s~%s~%d~%d~%s",
                                updateId, memberName, profKey, c, totalChunks, table.concat(chunkIds, ","))
                            table.insert(packetsList, recPayload)
                        end
                    end

                    local updateData = {
                        updateId = updateId,
                        type = "PROFESSION",
                        memberName = memberName,
                        profKey = profKey,
                        rank = rank,
                        maxRank = maxRank,
                        timestamp = profTimestamp,
                        packets = packetsList,
                        acknowledgedPeers = {},
                        sendCount = 0,
                        lastSent = 0,
                        createdAt = GetTime and GetTime() or 0,
                    }

                    self._pendingOutbox[updateId] = updateData
                    self:sendUpdatePacket(updateData, force)
                    enqueuedAny = true

                    if not force then
                        local myPlayer = self._myPlayerName or (UnitName and UnitName("player")) or "Você"
                        local profDef = ProfessionData and ProfessionData.PROFESSIONS and ProfessionData.PROFESSIONS[profKey]
                        local pDisp = profDef and profDef.name or profKey
                        local infoStr = string.format("%s (%d/%d, %d receitas) de %s", pDisp, rank, maxRank, #recipeIds, memberName)
                        self:printSyncNotification(L("SYNC_LOG_DATA_SYNCED", myPlayer, infoStr))
                    end
                end
            end
        end
    end

    return enqueuedAny
end

--- Alias de compatibilidade
---@param member Member|nil
---@param specificProfKey string|nil
---@param force boolean|nil
---@return boolean
function SyncService:broadcastPlayerProfessions(member, specificProfKey, force)
    return self:broadcastMemberProfessions(member, specificProfKey, force)
end

--- Transmite a criação ou alteração de um pedido de fabricação para a guilda através do canal oficial.
--- Formato: ORDER~action~id~requester~crafter~profKey~recipeId~recipeName~itemCount~tipCopper~status~acceptedBy~updatedAt
---@param order CraftOrder
---@param action string @"CREATE", "UPDATE", "DELETE"
---@param immediate boolean|nil @Se verdadeiro ou omitido, envia imediatamente além de enfileirar. Passe false para sincronização em lote.
function SyncService:broadcastCraftOrder(order, action, immediate)
    if not order or not order.getId then return end
    action = action or "UPDATE"
    local requester = order:getRequester() or ""
    local crafter = order:getCrafter() or ""
    local acceptedBy = order:getAcceptedBy() or ""

    local payload = string.format("ORDER~%s~%s~%s~%s~%s~%s~%s~%d~%d~%s~%s~%d",
        action,
        order:getId(),
        cleanName(requester),
        cleanName(crafter),
        order:getProfessionKey() or "ALCHEMY",
        tostring(order:getRecipeId() or 0),
        order:getRecipeName() or "",
        order:getItemCount() or 1,
        order:getTipCopper() or 0,
        order:getStatus() or "PENDING",
        cleanName(acceptedBy),
        order:getUpdatedAt() or 0
    )

    -- Disparo seguro via safeSendAddonMessage (se imediato) ou enfileirado na fila compassada
    local shouldSendImmediate = (immediate ~= false)
    if shouldSendImmediate then
        if IsInGuild and IsInGuild() then
            safeSendAddonMessage(SYNC_PREFIX, payload, "GUILD", nil, "NORMAL")
        elseif IsInRaid and IsInRaid() then
            safeSendAddonMessage(SYNC_PREFIX, payload, "RAID", nil, "NORMAL")
        elseif IsInGroup and IsInGroup() then
            safeSendAddonMessage(SYNC_PREFIX, payload, "PARTY", nil, "NORMAL")
        end
    else
        if IsInGuild and IsInGuild() then
            self:enqueuePacket(payload, "GUILD")
        elseif IsInRaid and IsInRaid() then
            self:enqueuePacket(payload, "RAID")
        elseif IsInGroup and IsInGroup() then
            self:enqueuePacket(payload, "PARTY")
        else
            self:enqueuePacket(payload, "GUILD")
        end
    end

    -- 3. Adiciona à outbox de retransmissão para confirmação ACK (especialmente em UPDATE / COMPLETED / DELETE)
    local updateId = string.format("ORDER_%s_%s", order:getId(), order:getStatus())
    self._pendingOutbox[updateId] = {
        type = "ORDER",
        updateId = updateId,
        orderId = order:getId(),
        payload = payload,
        target = "GUILD",
        lastSent = GetTime and GetTime() or 0,
        sendCount = 1,
        maxAttempts = 4,
        confirmed = false,
        acknowledgedPeers = {},
    }
end

--- Solicita à guilda o estado atual de todos os pedidos ativos e recentes
function SyncService:requestOrdersSync()
    local myName = self._myPlayerName or (UnitName and UnitName("player")) or "Desconhecido"
    local payload = string.format("ORDER_REQ~%s", myName)
    self:enqueuePacket(payload, "GUILD")
end

local function serializeGroupMembers(members)
    if type(members) ~= "table" then return "" end
    local parts = {}
    for _, m in ipairs(members) do
        local mName = (m.name or ""):gsub("[~/;]", "-")
        local mRole = m.role or "NONE"
        local mClass = m.class or ""
        local mLvl = tostring(m.level or 1)
        table.insert(parts, string.format("%s/%s/%s/%s", mName, mRole, mClass, mLvl))
    end
    return table.concat(parts, ";")
end

--- Sincroniza criação ou alteração de um grupo.
--- Regra: O sync acontece primeiro entre o criador e o líder da guilda,
--- e então do líder da guilda para os outros membros da guilda.
---@param group Group
---@param action string|nil @"CREATE", "UPDATE"
function SyncService:syncGroup(group, action)
    if not group or not group.getId then return end
    action = action or "UPDATE"
    local gId = group:getId()
    local gType = group:getType() or "DUNGEON"
    local gTime = (group:getTime() or ""):gsub("[~]", "-")
    local gLeader = (group:getLeader() or ""):gsub("[~]", "-")
    local gCreator = (group:getCreator() or ""):gsub("[~]", "-")
    local gUpdatedAt = tonumber(group:getUpdatedAt()) or time()
    local gName = (group:getName() or ""):gsub("[~]", "-")
    local gDesc = (group:getDescription() or ""):gsub("[~]", "-")
    local membersCsv = serializeGroupMembers(group:getMembers())

    local isLocalLeader = (IsGuildLeader and IsGuildLeader() == true) or false
    local tag = isLocalLeader and "GRP_DATA" or "GRP_PROP"

    local payload = string.format("%s~%s~%s~%s~%s~%s~%s~%d~%s~%s~%s",
        tag, action, gId, gType, gTime, gLeader, gCreator, gUpdatedAt, gName, gDesc, membersCsv)

    if IsInGuild and IsInGuild() then
        safeSendAddonMessage(SYNC_PREFIX, payload, "GUILD", nil, "NORMAL")
    end
end

--- Sincroniza a exclusão de um grupo.
---@param groupId string
function SyncService:syncGroupDelete(groupId)
    if not groupId or groupId == "" then return end
    local isLocalLeader = (IsGuildLeader and IsGuildLeader() == true) or false
    local tag = isLocalLeader and "GRP_DATA" or "GRP_PROP"
    local payload = string.format("%s~DELETE~%s", tag, groupId)

    if IsInGuild and IsInGuild() then
        safeSendAddonMessage(SYNC_PREFIX, payload, "GUILD", nil, "NORMAL")
    end
end

--- Sincroniza criação ou alteração de um card de Procurando Grupo (LFG).
--- Regra: O sync acontece primeiro entre o criador e o líder da guilda,
--- e então do líder da guilda para os outros membros da guilda.
---@param card LFGCard
---@param action string|nil @"CREATE", "UPDATE"
function SyncService:syncLFGCard(card, action)
    if not card or not card.getId then return end
    action = action or "UPDATE"
    local cId = card:getId()
    local cType = card:getType() or "DUNGEON"
    local cTime = (card:getTime() or ""):gsub("[~]", "-")
    local cCreator = (card:getCreator() or ""):gsub("[~]", "-")
    local cClass = card:getCreatorClass() or ""
    local cLevel = tonumber(card:getCreatorLevel()) or 1
    local cCreated = tonumber(card:getCreatedAt()) or time()
    local cDesc = (card:getDescription() or ""):gsub("[~]", "-")

    local isLocalLeader = (IsGuildLeader and IsGuildLeader() == true) or false
    local tag = isLocalLeader and "LFG_DATA" or "LFG_PROP"

    local payload = string.format("%s~%s~%s~%s~%s~%s~%s~%d~%d~%s",
        tag, action, cId, cType, cTime, cCreator, cClass, cLevel, cCreated, cDesc)

    if IsInGuild and IsInGuild() then
        safeSendAddonMessage(SYNC_PREFIX, payload, "GUILD", nil, "NORMAL")
    end
end

--- Sincroniza a exclusão de um card de Procurando Grupo.
---@param cardId string
function SyncService:syncLFGCardDelete(cardId)
    if not cardId or cardId == "" then return end
    local isLocalLeader = (IsGuildLeader and IsGuildLeader() == true) or false
    local tag = isLocalLeader and "LFG_DATA" or "LFG_PROP"
    local payload = string.format("%s~DELETE~%s", tag, cardId)

    if IsInGuild and IsInGuild() then
        safeSendAddonMessage(SYNC_PREFIX, payload, "GUILD", nil, "NORMAL")
    end
end

--- O Líder da guilda transmite todos os grupos para a guilda.
function SyncService:broadcastAllGroups()
    if not (_G.GM and _G.GM.groupRepository and _G.GM.groupRepository.findAll) then return end
    local groups = _G.GM.groupRepository:findAll()
    for _, g in ipairs(groups) do
        self:syncGroup(g, "UPDATE")
    end
end

--- O Líder da guilda transmite todos os cards de LFG para a guilda.
function SyncService:broadcastAllLFGCards()
    if not (_G.GM and _G.GM.lfgRepository and _G.GM.lfgRepository.findAll) then return end
    local cards = _G.GM.lfgRepository:findAll()
    for _, c in ipairs(cards) do
        self:syncLFGCard(c, "UPDATE")
    end
end

--- Força manualmente a sincronização de todos os dados customizados de todos os membros da guilda.
--- Enfileira todos os pacotes, reinicia as confirmações esperadas dos pares online e transmite na hora.
--- Também envia um SYNC_REQ solicitando aos outros colegas que transmitam suas informações.
---@return number @Quantidade de membros com dados customizados enfileirados
function SyncService:forceSyncAll()
    if not self._memberService then return 0 end

    local members = self._memberService:getAllMembers()
    local count = 0
    local isLeader = (IsGuildLeader and IsGuildLeader() == true) or false

    -- 1. Sincroniza dados customizados (Entrada, Aniversário, Recrutador, Alts, Função)
    for _, m in ipairs(members) do
        local dateJoin = m:getDateJoin() or ""
        local bday = m:getBirthday() or ""
        local rec = m:getRecruiter() or ""
        local alts = m:getAlts() or {}
        local role = (m.getRole and m:getRole()) or ""
        local roleShouldSync = isLeader or (m.isRolePendingLeaderConfirm and m:isRolePendingLeaderConfirm())
        if dateJoin ~= "" or bday ~= "" or rec ~= "" or #alts > 0 or (role ~= "" and roleShouldSync) then
            -- Limpa assinatura em cache para permitir reenvio forçado
            local mLower = cleanName(m:getName()):lower()
            self._lastMemberSignatures[mLower] = nil

            if self:broadcastMemberCustomData(m, true) then
                count = count + 1
            end
        end
    end

    -- 2. Sincroniza profissões e receitas de todos os membros cadastrados
    for _, m in ipairs(members) do
        local profs = m.getProfessions and m:getProfessions()
        if type(profs) == "table" then
            local mLower = cleanName(m:getName()):lower()
            for profKey, pData in pairs(profs) do
                if (pData.rank or 0) > 0 or (pData.recipes and next(pData.recipes) ~= nil) then
                    if self._lastProfSignatures then
                        self._lastProfSignatures[mLower .. "_" .. profKey] = nil
                    end
                    if self:broadcastMemberProfessions(m, profKey, true) then
                        count = count + 1
                    end
                end
            end
        end
    end

    -- 3. Sincroniza pedidos de fabricação ativos
    if _G.GM and _G.GM.craftOrderRepository and _G.GM.craftOrderRepository.findAll then
        pcall(function()
            local orders = _G.GM.craftOrderRepository:findAll()
            for _, ord in ipairs(orders) do
                if ord:getStatus() ~= "CANCELLED" then
                    self:broadcastCraftOrder(ord, "UPDATE", false)
                end
            end
        end)
    end

    -- 4. Se for o Líder da guilda, sincroniza grupos e cards de Procurando Grupo (LFG)
    if isLeader then
        pcall(function()
            self:broadcastAllGroups()
            self:broadcastAllLFGCards()
        end)
    end

    -- Envia uma solicitação para os colegas também transmitirem o que eles possuem
    local myName = self._myPlayerName or (UnitName and UnitName("player")) or "Desconhecido"
    self:enqueuePacket(string.format("SYNC_REQ~%s", myName), "GUILD")

    local activePeers = self:getActivePeers()
    if #activePeers > 0 then
        local peerNames = {}
        for _, p in ipairs(activePeers) do
            table.insert(peerNames, p.name)
        end
        self:printSyncNotification(L("SYNC_LOG_MANUAL_STARTED", count, #activePeers, table.concat(peerNames, ", ")))
    else
        self:printSyncNotification(L("SYNC_LOG_MANUAL_NO_PEERS", count))
    end

    return count
end

--- Alias de compatibilidade para forceSyncAll
---@return number
function SyncService:sendAllCustomDataToPeers()
    return self:forceSyncAll()
end

--- Simula um peer de teste confirmando updates (útil para testes com /gmsync test).
---@return boolean
function SyncService:simulateTestPeerAck()
    local testPeer = "AventureiroTeste"
    self:touchPeer(testPeer)

    local count = 0
    for id, update in pairs(self._pendingOutbox) do
        update.acknowledgedPeers[testPeer:lower()] = true
        count = count + 1
        if self:isUpdateFullyAcknowledged(update) then
            self._pendingOutbox[id] = nil
        end
    end

    self:printSyncNotification(L("SYNC_LOG_TEST_ACK", testPeer, count))
    return true
end

--- Retorna o status atual da fila de sincronização.
---@return table
function SyncService:getStatus()
    local pendingCount = 0
    for _ in pairs(self._pendingOutbox) do
        pendingCount = pendingCount + 1
    end
    local queueCount = #self._sendQueue
    local activePeers = self:getActivePeers()
    return {
        pendingCount = pendingCount,
        queueCount = queueCount,
        activePeerCount = #activePeers,
        activePeers = activePeers,
    }
end

--- Inicializa os ganchos de eventos, a fila compassada e o loop de retransmissão em segundo plano.
function SyncService:initHooks()
    if self._eventFrame then return end

    if RegisterPrefix then
        pcall(RegisterPrefix, SYNC_PREFIX)
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("PLAYER_GUILD_UPDATE")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")

    local function setupSession()
        if self._sessionInitialized then return end
        self._sessionInitialized = true

        if UnitName then
            self._myPlayerName = UnitName("player")
        end
        if UnitFullName then
            local ok, n, r = pcall(UnitFullName, "player")
            if ok and n then
                self._myFullName = (r and r ~= "") and (n .. "-" .. r) or n
            end
        end

        -- Notifica o início de sessão no chat caso a flag esteja ativada
        if self:isChatLogEnabled() and not self._sessionLogged then
            self._sessionLogged = true
            local myName = self._myPlayerName or (UnitName and UnitName("player")) or "Player"
            self:printSyncNotification(L("SYNC_LOG_INIT", myName))
        end

        -- Garante que membros existentes com dados customizados possuam timestamp inicial de segurança
        if self._memberService then
            local all = self._memberService:getAllMembers()
            local nowTs = getCurrentTimestamp()
            local isLeader = (IsGuildLeader and IsGuildLeader() == true) or false
            for _, m in ipairs(all) do
                local d = m:getDateJoin() or ""
                local b = m:getBirthday() or ""
                local r = m:getRecruiter() or ""
                local a = m:getAlts() or {}
                local rl = (m.getRole and m:getRole()) or ""
                local ts = m:getCustomDataTimestamp()
                if isLeader and rl ~= "" and m.isRolePendingLeaderConfirm and m:isRolePendingLeaderConfirm() then
                    m:setRolePendingLeaderConfirm(false)
                    self._memberService:saveMember(m, true)
                end
                if (d ~= "" or b ~= "" or r ~= "" or #a > 0 or rl ~= "") and (not ts or ts == 0) then
                    m:setCustomDataTimestamp(nowTs)
                    self._memberService:saveMember(m, true)
                end
            end
        end

        -- Garante que todos os prefixos estejam registrados na conexão do chat
        local Register = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or _G.RegisterAddonMessagePrefix
        if Register then
            pcall(Register, SYNC_PREFIX)
            pcall(Register, "GM_POS")
            pcall(Register, "GuildManager")
        end

        -- Sincronização automática compassada após estabilização da conexão (12 a 16s pós-login)
        -- O atraso de warmup garante que os canais estejam ativos e o limite de tráfego inicial da Blizzard liberado
        if C_Timer and C_Timer.After then
            local warmup = 12.0 + math.random(1, 4)
            C_Timer.After(warmup, function()
                if not IsInGuild or not IsInGuild() then return end
                local myName = self._myPlayerName or (UnitName and UnitName("player")) or "Desconhecido"

                -- 1. Anuncia aos outros membros que este jogador com o Addon conectou
                self:enqueuePacket(string.format("LOGIN~%s", myName), "GUILD")

                -- 2. Solicita os dados mais recentes aos outros membros
                self:enqueuePacket(string.format("SYNC_REQ~%s", myName), "GUILD")

                -- 3. Solicita pedidos de fabricação ativos da guilda
                pcall(function() self:requestOrdersSync() end)

                -- 4. Transmite profissões e receitas do jogador local com espaçamento suave adicional
                C_Timer.After(4.0, function()
                    if IsInGuild and IsInGuild() then
                        pcall(function() self:broadcastMemberProfessions() end)
                    end
                end)
            end)
        end
    end

    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            setupSession()
        elseif event == "CHAT_MSG_ADDON" then
            local prefix, msg, ch, sender = ...
            self:onAddonMessage(prefix, msg, ch, sender)
        end
    end)

    if (IsLoggedIn and IsLoggedIn()) or (UnitName and UnitName("player")) then
        setupSession()
    end

    -- Conecta-se ao LocationService para detectar imediatamente a presença de pares online
    if self._locationService and self._locationService.registerListener then
        self._locationService:registerListener(function(event, peerName, peerData)
            if event == "PEER_UPDATE" and peerName and not self:isSelf(peerName) then
                self:touchPeer(peerName)
            end
        end)
    end

    -- Loop em segundo plano para envio compassado da fila e retransmissão periódica
    local sendQueueTicker = 0
    local retransmitTicker = 0
    local cleanupTicker = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        -- Regra de Performance: Pausa total de processamento em combate para zero stuttering e FPS máximo!
        if InCombatLockdown and InCombatLockdown() then
            return
        end

        sendQueueTicker = sendQueueTicker + elapsed
        if sendQueueTicker >= SEND_QUEUE_INTERVAL then
            sendQueueTicker = 0
            self:processSendQueue()
        end

        retransmitTicker = retransmitTicker + elapsed
        if retransmitTicker >= RETRANSMIT_INTERVAL then
            retransmitTicker = 0
            self:processRetransmission()
        end

        cleanupTicker = cleanupTicker + elapsed
        if cleanupTicker >= 60.0 then
            cleanupTicker = 0
            -- Limpeza leve de memória para economizar RAM em sessões longas
            local now = GetTime and GetTime() or 0
            for id, t in pairs(self._processedUpdateIds) do
                if (now - t) > 120.0 then
                    self._processedUpdateIds[id] = nil
                end
            end
        end
    end)

    self._eventFrame = frame
end

--- Processa a fila de retransmissão em segundo plano.
--- O emissor sempre continua enviando até que todos os pares recebam.
--- Quando todos tiverem recebido, o item é removido e não é mais transmitido.
function SyncService:processRetransmission()
    -- Se a outbox estiver vazia, retorna imediatamente sem alocar tabelas
    if next(self._pendingOutbox) == nil then
        return
    end

    local activePeers = self:getActivePeers()
    local hasActivePeers = (#activePeers > 0)
    if not hasActivePeers then
        -- Sem pares ativos online: aguarda conexão de algum colega para retransmitir
        return
    end

    local now = GetTime and GetTime() or 0
    local toRemove = nil

    for updateId, update in pairs(self._pendingOutbox) do
        -- Verifica se todos os pares ativos já confirmaram (reutilizando a lista de peers)
        if self:isUpdateFullyAcknowledged(update, activePeers) then
            toRemove = toRemove or {}
            table.insert(toRemove, updateId)
        else
            -- Retransmite se passou tempo suficiente desde o último envio
            if (now - (update.lastSent or 0)) >= RETRANSMIT_INTERVAL then
                if (update.sendCount or 0) < MAX_RETRANSMIT_ATTEMPTS then
                    self:sendUpdatePacket(update)
                else
                    -- Proteção após limite máximo de tentativas
                    toRemove = toRemove or {}
                    table.insert(toRemove, updateId)
                end
            end
        end
    end

    if toRemove then
        for _, id in ipairs(toRemove) do
            self._pendingOutbox[id] = nil
        end
    end
end
