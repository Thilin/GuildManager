---@class SyncService
--- Serviço de sincronização peer-to-peer em tempo real para os dados customizados de cada membro da guilda
--- (Entrada, Aniversário, Alts Vinculados e Recrutador).
--- Transmite via canal de guilda (GUILD) e canais do Addon usando o protocolo de confirmação (ACK).
--- O emissor retransmite os dados até que todos os pares online com o Addon confirmem o recebimento.
--- Sincroniza automaticamente quando um membro da guilda que usa o Addon é identificado ao logar,
--- e permite forçar a sincronização manualmente a qualquer momento.
SyncService = {}
SyncService.__index = SyncService

local SYNC_PREFIX = "GM_SYNC"
local COMM_CHANNEL_NAME = "AJShare"
local RETRANSMIT_INTERVAL = 2.5       -- Intervalo entre retransmissões de pacotes pendentes (2.5s)
local SEND_QUEUE_INTERVAL = 0.12      -- Intervalo compassado de envio de pacotes (evita throttle do chat)
local PEER_LIVENESS_WINDOW = 35.0     -- Tempo em segundos sem sinal para considerar peer offline (35s)
local MAX_RETRANSMIT_ATTEMPTS = 60    -- Limite máximo de tentativas por atualização (evita loop infinito)

-- Registra o prefixo de mensagem imediatamente no carregamento do arquivo
local RegisterPrefix = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or _G.RegisterAddonMessagePrefix
if RegisterPrefix then
    pcall(RegisterPrefix, SYNC_PREFIX)
end

--- Construtor do SyncService.
---@param memberService MemberService
---@param locationService LocationService|nil
---@return SyncService
function SyncService:new(memberService, locationService)
    local instance = setmetatable({}, self)
    instance._memberService = memberService
    instance._locationService = locationService

    -- Tabela de pares conhecidos com o Addon ativo: [peerNameLower] = { name = peerName, lastSeen = GetTime(), isActive = true }
    instance._peers = {}

    -- Registro do último anúncio de login detectado para evitar spam: [peerNameLower] = timestamp
    instance._lastLoginDetected = {}

    -- Fila de envio pendente de confirmações (retransmissão): [updateId] = updateData
    instance._pendingOutbox = {}

    -- Fila sequencial compassada de pacotes para envio: { { payload = ..., target = ..., channelNumber = ... }, ... }
    instance._sendQueue = {}

    -- Histórico de IDs de atualizações já processadas localmente para evitar loops: [updateId] = timestamp
    instance._processedUpdateIds = {}

    -- Assinaturas recentes das informações de cada membro para evitar envios redundantes: [memberNameLower] = signature
    instance._lastMemberSignatures = {}

    instance._myPlayerName = nil
    instance._myFullName = nil
    instance._channelNumber = nil
    instance._eventFrame = nil
    instance._lastRetransmitTick = 0

    return instance
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

--- Disparado quando é identificado que um membro da guilda que usa o Addon acabou de logar / conectar.
--- Notifica o usuário no chat e inicia imediatamente a sincronização dos dados customizados com ele.
---@param peerName string
function SyncService:onPeerLoggedIn(peerName)
    if not peerName or peerName == "" or self:isSelf(peerName) then return end
    local cName = cleanName(peerName)

    print(string.format("|cff00ff00[GuildManager]|r Membro com o AddOn detectado online: |cffffff00%s|r. Sincronizando dados customizados...", cName))

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
---@param payload string
---@param targetChannel string|nil @"GUILD" ou "CHANNEL"
---@param channelNumber number|nil
function SyncService:enqueuePacket(payload, targetChannel, channelNumber)
    if not payload or payload == "" then return end
    table.insert(self._sendQueue, {
        payload = payload,
        target = targetChannel or "GUILD",
        channelNumber = channelNumber,
    })
end

--- Processa a fila compassada de envio a uma taxa segura (~0.12s por pacote = ~8 pacotes/s),
--- garantindo que mensagens de Addon nunca sejam descartadas pelo limite da Blizzard.
function SyncService:processSendQueue()
    if #self._sendQueue == 0 then return end

    local item = table.remove(self._sendQueue, 1)
    if not item or not item.payload then return end

    local Send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or _G.SendAddonMessage
    if not Send then return end

    if item.target == "GUILD" then
        if IsInGuild and IsInGuild() then
            pcall(Send, SYNC_PREFIX, item.payload, "GUILD")
        end
    elseif item.target == "CHANNEL" and item.channelNumber and item.channelNumber > 0 then
        pcall(Send, SYNC_PREFIX, item.payload, "CHANNEL", item.channelNumber)
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

    local nowClock = (time and time()) or (os and os.time and os.time()) or 0
    local randomSuffix = math.random(1000, 9999)
    local updateId = string.format("%s_%d_%d", memberName, nowClock, randomSuffix)

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
        timestamp = nowClock,
        acknowledgedPeers = {},
        sendCount = 0,
        lastSent = 0,
        createdAt = GetTime and GetTime() or 0,
    }

    self._pendingOutbox[updateId] = updateData

    -- Envia NA HORA para todos os outros usuários do Addon via fila de transmissão
    self:sendUpdatePacket(updateData)

    return true
end

--- Enfileira o pacote de dados formatado para transmissão segura através dos canais suportados.
--- Formato do payload: DATA~updateId~memberName~dateJoin~birthday~recruiter~altsCsv~isMain~timestamp
---@param updateData table
function SyncService:sendUpdatePacket(updateData)
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

    -- 1. Canal de Guilda
    self:enqueuePacket(payload, "GUILD")

    -- 2. Canal global reservado do AddOn (AJShare) caso ativo
    local chNum = self._channelNumber or (self._locationService and self._locationService._channelNumber)
    if chNum and chNum > 0 then
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
    end

    local chNum = self._channelNumber or (self._locationService and self._locationService._channelNumber)
    if chNum and chNum > 0 then
        pcall(Send, SYNC_PREFIX, payload, "CHANNEL", chNum)
    end
end

--- Verifica se todos os outros usuários atualmente online com o Addon já confirmaram o recebimento do update.
---@param updateData table
---@return boolean
function SyncService:isUpdateFullyAcknowledged(updateData)
    if not updateData then return true end

    local activePeers = self:getActivePeers()

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
    if not prefix or not message or type(message) ~= "string" then return end

    local pUpper = prefix:upper()
    if pUpper ~= SYNC_PREFIX then
        -- Se recebeu sinal de presença do LocationService, aproveita para registrar liveness do peer
        if pUpper == "GM_POS" or pUpper == "AJ_POS" then
            self:touchPeer(sender)
        end
        return
    end

    if not sender or sender == "" then return end

    -- Ignora rigorosamente as mensagens enviadas pelo próprio jogador
    if self:isSelf(sender) then
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
        if not member then
            member = Member:new({ name = mClean, isInGuild = true })
        end

        -- Aplica os 4 dados customizados requisitados:
        -- 1. Data de Entrada
        if dateJoin ~= "" then
            member:setDateJoin(dateJoin)
        end

        -- 2. Aniversário
        if birthday ~= "" then
            member:setBirthday(birthday)
        end

        -- 3. Recrutador
        if recruiter ~= "" then
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

        -- Atualiza a assinatura local para não retransmitir de volta o que acabou de receber
        local isMainBool = (isMainStr == "1")
        self._lastMemberSignatures[mClean:lower()] = makeDataSignature(dateJoin, birthday, recruiter, altsCsv, isMainBool)

        -- Persiste no banco de dados local via repositório
        if self._memberService and self._memberService._repository then
            self._memberService._repository:save(member)

            -- Mantém a reciprocidade da família de alts se houver lista
            if #altsList > 0 and self._memberService.syncAltFamily then
                local familyNames = { mClean }
                for _, aName in ipairs(altsList) do
                    table.insert(familyNames, aName)
                end
                local mainName = isMainBool and mClean or altsList[1]
                self._memberService:syncAltFamily(familyNames, mainName)
            end
        end

        -- Atualiza telas da interface em tempo real se estiverem visíveis
        self:refreshActiveViews(mClean)

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
        print(string.format("|cff00ff00[GuildManager]|r Sincronização manual iniciada! |cffffff00%d|r membro(s) com dados customizados para |cffffff00%d|r colega(s) online: |cff00ffff%s|r.", count, #activePeers, table.concat(peerNames, ", ")))
    else
        print(string.format("|cff00ff00[GuildManager]|r Sincronização manual iniciada para |cffffff00%d|r membro(s). Nenhum outro membro com o AddOn online no momento (os dados serão sincronizados automaticamente assim que um membro logar).", count))
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

    print(string.format("|cff00ff00[GuildManager]|r Peer de teste '%s' confirmou recebimento de %d pacote(s) pendente(s).", testPeer, count))
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
    local activePeers = self:getActivePeers()
    local hasActivePeers = (#activePeers > 0)
    local now = GetTime and GetTime() or 0

    local toRemove = {}

    for updateId, update in pairs(self._pendingOutbox) do
        -- Verifica se todos os pares ativos já confirmaram
        if hasActivePeers and self:isUpdateFullyAcknowledged(update) then
            table.insert(toRemove, updateId)
        elseif hasActivePeers then
            -- Retransmite se passou tempo suficiente desde o último envio
            if (now - (update.lastSent or 0)) >= RETRANSMIT_INTERVAL then
                if (update.sendCount or 0) < MAX_RETRANSMIT_ATTEMPTS then
                    self:sendUpdatePacket(update)
                else
                    -- Proteção após limite máximo de tentativas
                    table.insert(toRemove, updateId)
                end
            end
        end
    end

    for _, id in ipairs(toRemove) do
        self._pendingOutbox[id] = nil
    end
end
