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
local COMM_CHANNEL_NAME = "AJShare"
local RETRANSMIT_INTERVAL = 2.5       -- Intervalo entre retransmissões de pacotes pendentes (2.5s)
local SEND_QUEUE_INTERVAL = 0.12      -- Intervalo compassado de envio de pacotes (evita throttle do chat)
local PEER_LIVENESS_WINDOW = 35.0     -- Tempo em segundos sem sinal para considerar peer offline (35s)
local MAX_RETRANSMIT_ATTEMPTS = 60    -- Limite máximo de tentativas por atualização (evita loop infinito)
local MAX_QUEUE_SIZE = 250            -- Capacidade máxima da fila compassada para proteção contra vazamento de memória

-- Registra o prefixo de mensagem imediatamente no carregamento do arquivo
local RegisterPrefix = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or _G.RegisterAddonMessagePrefix
if RegisterPrefix then
    pcall(RegisterPrefix, SYNC_PREFIX)
end

--- Construtor do SyncService.
---@param memberService MemberService
---@param locationService LocationService|nil
---@param settingsService SettingsService|nil
---@return SyncService
function SyncService:new(memberService, locationService, settingsService)
    local instance = setmetatable({}, self)
    instance._memberService = memberService
    instance._locationService = locationService
    instance._settingsService = settingsService

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

    instance._myPlayerName = nil
    instance._myFullName = nil
    instance._channelNumber = nil
    instance._eventFrame = nil
    instance._lastRetransmitTick = 0
    instance._syncChatFrame = nil

    return instance
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

--- Normaliza o nome do remetente removendo o sufixo de reino e espaços.
---@param name string|nil
---@return string
local function cleanName(name)
    if not name or name == "" then return "" end
    local clean = name:match("^[^-]+") or name
    return clean:match("^%s*(.-)%s*$") or clean
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

    self._peers[lower] = {
        name = cName,
        lastSeen = now,
        isActive = true,
    }

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

    for _, m in ipairs(members) do
        local dateJoin = m:getDateJoin() or ""
        local bday = m:getBirthday() or ""
        local rec = m:getRecruiter() or ""
        local alts = m:getAlts() or {}
        if dateJoin ~= "" or bday ~= "" or rec ~= "" or #alts > 0 then
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

    -- Sincroniza profissões do próprio jogador e pedidos de profissão ativos com o colega
    if self.broadcastPlayerProfessions then
        pcall(function() self:broadcastPlayerProfessions() end)
    end
    if _G.GM and _G.GM.craftOrderRepository and _G.GM.craftOrderRepository.findAll then
        pcall(function()
            local orders = _G.GM.craftOrderRepository:findAll()
            for _, ord in ipairs(orders) do
                if ord:getStatus() ~= "CANCELLED" then
                    self:broadcastCraftOrder(ord, "UPDATE")
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
local function makeDataSignature(dateJoin, birthday, recruiter, altsCsv, isMain)
    return string.format("%s~%s~%s~%s~%s",
        dateJoin or "",
        birthday or "",
        recruiter or "",
        altsCsv or "",
        isMain and "1" or "0"
    )
end

--- Adiciona um pacote à fila compassada de envio para evitar throttling do chat da Blizzard.
--- Limita o tamanho máximo a MAX_QUEUE_SIZE para prevenir crescimento descontrolado de memória.
---@param payload string
---@param targetChannel string|nil @"GUILD", "CHANNEL", "RAID", "PARTY"
---@param channelNumber number|nil
function SyncService:enqueuePacket(payload, targetChannel, channelNumber)
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

    local Send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or _G.SendAddonMessage
    if not Send then return end

    if item.target == "GUILD" then
        if IsInGuild and IsInGuild() then
            pcall(Send, SYNC_PREFIX, item.payload, "GUILD")
        end
    elseif item.target == "CHANNEL" and item.channelNumber and item.channelNumber > 0 then
        pcall(Send, SYNC_PREFIX, item.payload, "CHANNEL", item.channelNumber)
    elseif item.target == "RAID" and IsInRaid and IsInRaid() then
        pcall(Send, SYNC_PREFIX, item.payload, "RAID")
    elseif item.target == "PARTY" and IsInGroup and IsInGroup() then
        pcall(Send, SYNC_PREFIX, item.payload, "PARTY")
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

    local dateJoin = member:getDateJoin() or ""
    local birthday = member:getBirthday() or ""
    local recruiter = member:getRecruiter() or ""
    local alts = member:getAlts() or {}
    local altsCsv = table.concat(alts, ",")
    local isMain = member:isMain()

    local signature = makeDataSignature(dateJoin, birthday, recruiter, altsCsv, isMain)
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

    local payload = string.format("DATA~%s~%s~%s~%s~%s~%s~%s~%d",
        updateData.updateId,
        updateData.memberName,
        updateData.dateJoin or "",
        updateData.birthday or "",
        updateData.recruiter or "",
        updateData.altsCsv or "",
        updateData.isMain and "1" or "0",
        updateData.timestamp or 0
    )

    local Send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or _G.SendAddonMessage
    local chNum = self._channelNumber or (self._locationService and self._locationService._channelNumber)

    if immediate and Send then
        -- Envio imediato direto
        if IsInGuild and IsInGuild() then
            pcall(Send, SYNC_PREFIX, payload, "GUILD")
        elseif IsInRaid and IsInRaid() then
            pcall(Send, SYNC_PREFIX, payload, "RAID")
        elseif IsInGroup and IsInGroup() then
            pcall(Send, SYNC_PREFIX, payload, "PARTY")
        elseif chNum and chNum > 0 then
            pcall(Send, SYNC_PREFIX, payload, "CHANNEL", chNum)
        end
    end

    -- Enfileira de forma otimizada na fila compassada sem disparar mensagens redundantes em múltiplos canais
    if IsInGuild and IsInGuild() then
        self:enqueuePacket(payload, "GUILD")
    elseif IsInRaid and IsInRaid() then
        self:enqueuePacket(payload, "RAID")
    elseif IsInGroup and IsInGroup() then
        self:enqueuePacket(payload, "PARTY")
    elseif chNum and chNum > 0 then
        self:enqueuePacket(payload, "CHANNEL", chNum)
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

    local Send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or _G.SendAddonMessage
    if not Send then return end

    if IsInGuild and IsInGuild() then
        pcall(Send, SYNC_PREFIX, payload, "GUILD")
    elseif IsInRaid and IsInRaid() then
        pcall(Send, SYNC_PREFIX, payload, "RAID")
    elseif IsInGroup and IsInGroup() then
        pcall(Send, SYNC_PREFIX, payload, "PARTY")
    end

    local chNum = self._channelNumber or (self._locationService and self._locationService._channelNumber)
    if chNum and chNum > 0 then
        pcall(Send, SYNC_PREFIX, payload, "CHANNEL", chNum)
    end
end

--- Verifica se todos os outros usuários atualmente online com o Addon já confirmaram o recebimento do update.
---@param updateData table
---@param activePeers table[]|nil
---@return boolean
function SyncService:isUpdateFullyAcknowledged(updateData, activePeers)
    if not updateData then return true end

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

    local tag, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8 = strsplit("~", message)

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

        if not updateId or updateId == "" or not memberName or memberName == "" then
            return
        end

        local mClean = cleanName(memberName)
        local member = self._memberService and self._memberService:getMember(mClean)
        local localTimestamp = (member and member.getCustomDataTimestamp and member:getCustomDataTimestamp()) or 0

        -- Last-Write-Wins: Se o membro já possui dados localmente e a versão local é MAIS RECENTE que o pacote recebido,
        -- rejeita o pacote antigo para proteger as informações novas contra sobrescrita indevida!
        if member and localTimestamp > 0 and timestamp > 0 and localTimestamp > timestamp then
            -- Confirma o recebimento para o peer parar de retransmitir o pacote antigo
            self:sendAckPacket(updateId, mClean)
            -- Transmite imediatamente a nossa versão mais recente para atualizar o peer desatualizado
            self:broadcastMemberCustomData(member, true)
            return
        end

        if not member then
            member = Member:new({ name = mClean, isInGuild = true })
        end

        -- Aplica os 4 dados customizados requisitados:
        -- 1. Data de Entrada
        if dateJoin and dateJoin ~= "" then
            member:setDateJoin(dateJoin)
        end

        -- 2. Aniversário
        if birthday and birthday ~= "" then
            member:setBirthday(birthday)
        end

        -- 3. Recrutador
        if recruiter and recruiter ~= "" then
            member:setRecruiter(recruiter)
        end

        -- 4. Alts Vinculados e Main/Alt
        local altsList = {}
        if altsCsv and altsCsv ~= "" then
            for altName in string.gmatch(altsCsv, "([^,]+)") do
                local cAlt = cleanName(altName)
                if cAlt ~= "" and cAlt:lower() ~= mClean:lower() then
                    table.insert(altsList, cAlt)
                end
            end
        end

        member:setAlts(altsList)
        member:setMain(isMainStr == "1")

        local appliedTimestamp = (timestamp > 0) and timestamp or getCurrentTimestamp()
        if member.setCustomDataTimestamp then
            member:setCustomDataTimestamp(appliedTimestamp)
        end

        -- Atualiza a assinatura local para não retransmitir de volta o que acabou de receber
        local isMainBool = (isMainStr == "1")
        self._lastMemberSignatures[mClean:lower()] = makeDataSignature(dateJoin, birthday, recruiter, altsCsv, isMainBool)

        -- Persiste no banco de dados local com normalização e sem retransmissão circular
        if self._memberService then
            self._memberService:saveMember(member, true)

            -- Mantém a reciprocidade da família de alts se houver lista (skipSync = true evita flood)
            if #altsList > 0 and self._memberService.syncAltFamily then
                local familyNames = { mClean }
                for _, aName in ipairs(altsList) do
                    table.insert(familyNames, aName)
                end
                local mainName = isMainBool and mClean or altsList[1]
                self._memberService:syncAltFamily(familyNames, mainName, true)
            end
        end

        -- Atualiza telas da interface em tempo real se estiverem visíveis
        self:refreshActiveViews(mClean)

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
        local pName = arg1
        local profKey = arg2
        local rank = tonumber(arg3) or 0
        local maxRank = tonumber(arg4) or 300
        if not pName or pName == "" or not profKey then return end

        local mClean = cleanName(pName)
        local member = self._memberService and self._memberService:getMember(mClean)
        if not member then
            member = Member:new({ name = mClean, isInGuild = true })
        end
        local currentRecipes = {}
        local existingProf = member:getProfession(profKey)
        if existingProf and existingProf.recipes then
            currentRecipes = existingProf.recipes
        end
        member:setProfession(profKey, rank, maxRank, currentRecipes)
        if self._memberService then
            self._memberService:saveMember(member, true)
        end
        if _G.GM and _G.GM.professionService and _G.GM.professionService.notifyChanged then
            _G.GM.professionService:notifyChanged()
        end
        self:refreshActiveViews(mClean)

    -- =========================================================================
    -- RECEBIMENTO DE RECEITAS DE PROFISSÃO (PROF_REC)
    -- =========================================================================
    elseif tag == "PROF_REC" then
        local pName = arg1
        local profKey = arg2
        local chunkIdx = tonumber(arg3) or 1
        local totalChunks = tonumber(arg4) or 1
        local idsCsv = arg5 or ""
        if not pName or pName == "" or not profKey or idsCsv == "" then return end

        local mClean = cleanName(pName)
        local member = self._memberService and self._memberService:getMember(mClean)
        if not member then
            member = Member:new({ name = mClean, isInGuild = true })
        end

        for rId in string.gmatch(idsCsv, "([^,]+)") do
            member:addRecipe(profKey, rId)
        end

        if self._memberService then
            self._memberService:saveMember(member, true)
        end
        if _G.GM and _G.GM.professionService and _G.GM.professionService.notifyChanged then
            _G.GM.professionService:notifyChanged()
        end
        self:refreshActiveViews(mClean)

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
                    order:setCrafter(crafter)
                    order:setItemCount(itemCount)
                    order:setTipCopper(tipCopper)
                    order:setStatus(status)
                    order:setAcceptedBy(acceptedBy)
                end
                orderRepo:save(order)
            end
        end

        if _G.GM and _G.GM.professionService and _G.GM.professionService.notifyChanged then
            _G.GM.professionService:notifyChanged()
        end
        self:refreshActiveViews(requester)
    end
end

--- Atualiza as janelas abertas para refletir os novos dados em tempo real.
---@param memberName string
function SyncService:refreshActiveViews(memberName)
    -- Atualiza tela de auditoria se aberta
    if _G.GM and _G.GM.auditController and _G.GM.auditController.refreshAudit then
        local aView = _G.GM.auditView
        if aView and aView.isShown and aView:isShown() then
            _G.GM.auditController:refreshAudit()
        end
    end

    -- Atualiza card do membro se aberto
    if _G.GM and _G.GM.memberView and _G.GM.memberView.isShown and _G.GM.memberView:isShown() then
        local cur = _G.GM.memberView._currentMember
        if cur and cur:getName() and cur:getName():lower() == memberName:lower() then
            local refreshed = self._memberService and self._memberService:getMember(memberName)
            if refreshed then
                _G.GM.memberView:showMember(refreshed)
            end
        end
    end

    -- Atualiza lista de aniversariantes da agenda se aberta
    if _G.GM and _G.GM.agendaView and _G.GM.agendaView.isShown and _G.GM.agendaView:isShown() then
        if _G.GM.agendaController and _G.GM.agendaController.refreshAgenda then
            _G.GM.agendaController:refreshAgenda()
        end
    end

    -- Atualiza tela de profissões e pedidos se aberta
    if _G.GM and _G.GM.professionController and _G.GM.professionController.refreshView then
        local pView = _G.GM.professionView
        if pView and pView.isShown and pView:isShown() then
            _G.GM.professionController:refreshView()
        end
    end
end

--- Transmite as informações de profissões e receitas do jogador local para os colegas da guilda.
--- Divide as receitas em blocos seguros (~15 IDs por pacote) para respeitar o limite de 255 bytes da Blizzard.
---@param member Member|nil
---@param specificProfKey string|nil
function SyncService:broadcastPlayerProfessions(member, specificProfKey)
    local myName = self._myPlayerName or (UnitName and UnitName("player"))
    member = member or (self._memberService and self._memberService:getMember(myName))
    if not member or not member.getProfessions then return end

    local memberName = cleanName(member:getName())
    if memberName == "" then return end

    local profs = member:getProfessions()
    for profKey, profData in pairs(profs) do
        if not specificProfKey or specificProfKey == profKey then
            local rank = profData.rank or 0
            local maxRank = profData.maxRank or 300
            local now = getCurrentTimestamp()

            -- 1. Pacote de Resumo da Profissão: PROF_SUM~playerName~profKey~rank~maxRank~timestamp
            local sumPayload = string.format("PROF_SUM~%s~%s~%d~%d~%d", memberName, profKey, rank, maxRank, now)
            self:enqueuePacket(sumPayload, "GUILD")

            -- 2. Pacotes de Receitas Conhecidas: PROF_REC~playerName~profKey~chunk~total~csvIds
            local recipeIds = {}
            if type(profData.recipes) == "table" then
                for rId, v in pairs(profData.recipes) do
                    if v == true then
                        table.insert(recipeIds, tostring(rId))
                    end
                end
            end

            if #recipeIds > 0 then
                local CHUNK_SIZE = 15
                local totalChunks = math.ceil(#recipeIds / CHUNK_SIZE)
                for c = 1, totalChunks do
                    local startIdx = (c - 1) * CHUNK_SIZE + 1
                    local endIdx = math.min(c * CHUNK_SIZE, #recipeIds)
                    local chunkIds = {}
                    for i = startIdx, endIdx do
                        table.insert(chunkIds, recipeIds[i])
                    end
                    local recPayload = string.format("PROF_REC~%s~%s~%d~%d~%s", memberName, profKey, c, totalChunks, table.concat(chunkIds, ","))
                    self:enqueuePacket(recPayload, "GUILD")
                end
            end
        end
    end
end

--- Transmite a criação ou alteração de um pedido de fabricação para a guilda.
--- Formato: ORDER~action~id~requester~crafter~profKey~recipeId~recipeName~itemCount~tipCopper~status~acceptedBy~updatedAt
---@param order CraftOrder
---@param action string @"CREATE", "UPDATE", "DELETE"
function SyncService:broadcastCraftOrder(order, action)
    if not order or not order.getId then return end
    action = action or "UPDATE"
    local payload = string.format("ORDER~%s~%s~%s~%s~%s~%s~%s~%d~%d~%s~%s~%d",
        action,
        order:getId(),
        cleanName(order:getRequester()),
        cleanName(order:getCrafter()),
        order:getProfessionKey() or "ALCHEMY",
        tostring(order:getRecipeId() or 0),
        order:getRecipeName() or "",
        order:getItemCount() or 1,
        order:getTipCopper() or 0,
        order:getStatus() or "PENDING",
        cleanName(order:getAcceptedBy()),
        order:getUpdatedAt() or 0
    )
    self:enqueuePacket(payload, "GUILD")
end

--- Força manualmente a sincronização de todos os dados customizados de todos os membros da guilda.
--- Enfileira todos os pacotes, reinicia as confirmações esperadas dos pares online e transmite na hora.
--- Também envia um SYNC_REQ solicitando aos outros colegas que transmitam suas informações.
---@return number @Quantidade de membros com dados customizados enfileirados
function SyncService:forceSyncAll()
    if not self._memberService then return 0 end

    local members = self._memberService:getAllMembers()
    local count = 0

    for _, m in ipairs(members) do
        local dateJoin = m:getDateJoin() or ""
        local bday = m:getBirthday() or ""
        local rec = m:getRecruiter() or ""
        local alts = m:getAlts() or {}
        if dateJoin ~= "" or bday ~= "" or rec ~= "" or #alts > 0 then
            -- Limpa assinatura em cache para permitir reenvio forçado
            local mLower = cleanName(m:getName()):lower()
            self._lastMemberSignatures[mLower] = nil

            if self:broadcastMemberCustomData(m, true) then
                count = count + 1
            end
        end
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
            for _, m in ipairs(all) do
                local d = m:getDateJoin() or ""
                local b = m:getBirthday() or ""
                local r = m:getRecruiter() or ""
                local a = m:getAlts() or {}
                local ts = m:getCustomDataTimestamp()
                if (d ~= "" or b ~= "" or r ~= "" or #a > 0) and (not ts or ts == 0) then
                    m:setCustomDataTimestamp(nowTs)
                    self._memberService:saveMember(m, true)
                end
            end
        end

        -- Ao logar / entrar no mundo, aguarda 2.5s para os canais de chat estarem conectados
        -- e então anuncia a presença e solicita sincronização
        if C_Timer and C_Timer.After then
            C_Timer.After(2.5, function()
                local myName = self._myPlayerName or (UnitName and UnitName("player")) or "Desconhecido"
                -- 1. Anuncia aos outros membros que este jogador com o Addon logou
                self:enqueuePacket(string.format("LOGIN~%s", myName), "GUILD")
                -- 2. Solicita os dados aos outros membros
                self:enqueuePacket(string.format("SYNC_REQ~%s", myName), "GUILD")
            end)
        end
    end

    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            setupSession()
        elseif event == "CHAT_MSG_ADDON" then
            local prefix, msg, ch, sender = ...
            self:onAddonMessage(prefix, msg, ch, sender)
        elseif event == "PLAYER_GUILD_UPDATE" or event == "GROUP_ROSTER_UPDATE" then
            -- Tenta reenviar atualizações pendentes
            self:processRetransmission()
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
    frame:SetScript("OnUpdate", function(_, elapsed)
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
