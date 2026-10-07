---@class SyncController
---@field private _syncService SyncService
---@field private _agendaController AgendaController|nil
---@field private _groupController GroupController|nil
---@field private _auditController AuditController|nil
---@field private _memberView MemberView|nil
---@field private _memberService MemberService|nil
---@field private _syncNotificationView SyncNotificationView|nil
---@field private _isConductingElection boolean
---@field private _electionCandidates table<string, number>
---@field private _loginSyncCompleted boolean
---@field private _isSyncing boolean
---@field private _activeSyncPeer string|nil
---@field private _syncStartTime number
---@field private _eventFrame table
---@field private _verboseDiagnostics boolean
SyncController = {}
SyncController.__index = SyncController

local SYNC_TIMEOUT = 12 -- Timeout em segundos para destravar a sincronização caso haja desconexão

--- Construtor do Controller de sincronização automática entre membros da guilda.
---@param syncService SyncService
---@param agendaController AgendaController|nil
---@param groupController GroupController|nil
---@param auditController AuditController|nil
---@param memberView MemberView|nil
---@param memberService MemberService|nil
---@param syncNotificationView SyncNotificationView|nil
---@return SyncController
function SyncController:new(syncService, agendaController, groupController, auditController, memberView, memberService, syncNotificationView)
    local instance = setmetatable({}, self)

    instance._syncService = syncService
    instance._agendaController = agendaController
    instance._groupController = groupController
    instance._auditController = auditController
    instance._memberView = memberView
    instance._memberService = memberService
    instance._syncNotificationView = syncNotificationView

    instance._isConductingElection = false
    instance._electionCandidates = {}
    instance._loginSyncCompleted = false
    instance._isSyncing = false
    instance._activeSyncPeer = nil
    instance._syncStartTime = 0
    instance._verboseDiagnostics = false

    return instance
end

--- Registra o prefixo de comunicação do AddOn utilizando as APIs corretas do WoW.
---@return boolean
function SyncController:registerPrefix()
    local ok = false
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        local success, res = pcall(C_ChatInfo.RegisterAddonMessagePrefix, "GuildManager")
        ok = success and (res == true or res == 0 or res == 1 or res == nil)
    elseif C_ChatInfo and C_ChatInfo.RegisterAddonPrefix then
        local success, res = pcall(C_ChatInfo.RegisterAddonPrefix, "GuildManager")
        ok = success
    elseif RegisterAddonMessagePrefix then
        local success, res = pcall(RegisterAddonMessagePrefix, "GuildManager")
        ok = success
    end
    return ok
end

--- Verifica se o prefixo 'GuildManager' está registrado com sucesso no cliente.
---@return boolean
function SyncController:isPrefixRegistered()
    if C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered then
        local ok, reg = pcall(C_ChatInfo.IsAddonMessagePrefixRegistered, "GuildManager")
        if ok and type(reg) == "boolean" then
            return reg
        end
    end
    return true
end

--- Verifica se o cliente já está em processo de sincronização com alguém (respeitando timeout de segurança).
---@return boolean
function SyncController:isSyncing()
    if not self._isSyncing then
        return false
    end

    local now = (GetTime and GetTime()) or 0
    if (now - (self._syncStartTime or 0)) > SYNC_TIMEOUT then
        self:releaseSyncLock()
        return false
    end

    return true
end

--- Trava o processo de sincronização exclusivamente para um peer específico.
--- Garante que o AddOn não sincronize com mais de uma pessoa ao mesmo tempo.
---@param peerName string
---@return boolean @true se a trava foi adquirida com sucesso
function SyncController:acquireSyncLock(peerName)
    local cleanPeer = self._syncService:sanitizeName(peerName)
    local now = (GetTime and GetTime()) or 0

    if self:isSyncing() then
        -- Se já estiver sincronizando com o mesmo peer, renova o timestamp
        if self._activeSyncPeer == cleanPeer then
            self._syncStartTime = now
            return true
        end
        -- Ocupado com outro membro! Bloqueia sincronização paralela
        return false
    end

    self._isSyncing = true
    self._activeSyncPeer = cleanPeer
    self._syncStartTime = now
    return true
end

--- Libera a trava exclusiva de sincronização.
function SyncController:releaseSyncLock()
    self._isSyncing = false
    self._activeSyncPeer = nil
    self._syncStartTime = 0
end

--- Inicia watchdog de segurança para cancelar a trava se o outro jogador parar de responder.
---@param peerName string
function SyncController:startSyncWatchdog(peerName)
    local targetName = self._syncService:sanitizeName(peerName)
    if C_Timer and C_Timer.After then
        C_Timer.After(SYNC_TIMEOUT, function()
            if self:isSyncing() and self._activeSyncPeer == targetName then
                self:handleSyncError("Tempo limite esgotado sem resposta do jogador", targetName)
            end
        end)
    end
end

--- Registra os manipuladores de eventos e inicializa a escuta de mensagens do AddOn.
function SyncController:initHooks()
    self:registerPrefix()

    -- Cria o quadro de eventos do controlador
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_GUILD_UPDATE")
    frame:RegisterEvent("CHAT_MSG_ADDON")

    frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            self:registerPrefix()
            if not self._loginSyncCompleted then
                if C_Timer and C_Timer.After then
                    C_Timer.After(2.5, function()
                        self:tryLoginSync(1)
                    end)
                else
                    self:tryLoginSync(1)
                end
            end
        elseif event == "PLAYER_GUILD_UPDATE" then
            self:registerPrefix()
            if not self._loginSyncCompleted and IsInGuild and IsInGuild() then
                self:tryLoginSync(1)
            end
        elseif event == "CHAT_MSG_ADDON" then
            local prefix = arg1
            local msg = arg2
            local channel = arg3
            local sender = arg4

            if prefix == "GuildManager" and type(msg) == "string" and msg:find("^GM_SYNC:") then
                if self._syncService then
                    self._syncService:handleIncomingPacket(msg, sender)
                end
            end
        end
    end)

    self._eventFrame = frame

    -- Configura os callbacks do protocolo de comunicação no SyncService
    self:setupSyncCallbacks()

    -- Registra comandos de barra
    self:registerSlashCommands()
end

--- Tenta disparar a sincronização inicial de login com retentativas caso a guilda ainda esteja carregando.
---@param attempt number|nil
function SyncController:tryLoginSync(attempt)
    attempt = attempt or 1
    if self._loginSyncCompleted then return end

    self:registerPrefix()

    if IsInGuild and IsInGuild() then
        self._loginSyncCompleted = true
        self:startElection(false)
    else
        -- No WoW Classic a guilda frequentemente leva alguns segundos para carregar do servidor
        if attempt < 5 and C_Timer and C_Timer.After then
            local nextDelay = (attempt == 1 and 3.0) or (attempt == 2 and 5.0) or 8.0
            C_Timer.After(nextDelay, function()
                self:tryLoginSync(attempt + 1)
            end)
        end
    end
end

--- Registra o comando de chat /gmsync.
function SyncController:registerSlashCommands()
    SLASH_GMSYNC1 = "/gmsync"
    SlashCmdList["GMSYNC"] = function(msg)
        local arg = (msg or ""):lower():match("^%s*(.-)%s*$")
        if arg == "test" or arg == "teste" then
            if self._syncNotificationView then
                local testSender = (UnitName and UnitName("player")) or "Membro"
                self._syncNotificationView:showProgress(testSender)
                if C_Timer and C_Timer.After then
                    C_Timer.After(1.5, function()
                        self._syncNotificationView:showSuccess(testSender, { totalAdded = 2, totalUpdated = 3 })
                    end)
                else
                    self._syncNotificationView:showSuccess(testSender, { totalAdded = 2, totalUpdated = 3 })
                end
                print("|cff00ff00[GuildManager]|r Exibindo caixinha de teste de sincronização com progresso e fade de 3 segundos.")
            end
            return
        elseif arg == "error" or arg == "erro" or arg == "err" then
            local testSender = (UnitName and UnitName("player")) or "Membro"
            self:handleSyncError("Tempo limite esgotado sem resposta do jogador", testSender)
            return
        elseif arg == "status" then
            self:printStatus()
            return
        end
        self:startElection(true)
    end
end

--- Exibe informações diagnósticas no chat sobre o estado da sincronização.
function SyncController:printStatus()
    local inGuild = IsInGuild and IsInGuild()
    local prefixReg = self:isPrefixRegistered()
    local myUptime = self._syncService and self._syncService:getUptime() or 0
    local isSyncing = self:isSyncing()
    local activePeer = self._activeSyncPeer or "Nenhum"

    print("|cff00ff00[GuildManager Sync Status]|r")
    print(string.format("  Em guilda: %s", inGuild and "|cff00ff00Sim|r" or "|cffff0000Não|r"))
    print(string.format("  Prefixo 'GuildManager' registrado: %s", prefixReg and "|cff00ff00Sim|r" or "|cffff0000Não|r"))
    print(string.format("  Tempo de sessão (uptime): |cffffff00%ds|r", myUptime))
    print(string.format("  Sincronização em andamento: %s (com %s)", isSyncing and "|cffff9900Sim|r" or "|cff888888Não|r", activePeer))
    print(string.format("  Login sync concluído: %s", self._loginSyncCompleted and "|cff00ff00Sim|r" or "|cffff9900Pendente|r"))
end

--- Inicia o processo de descoberta e sincronização de dados com outros membros da guilda.
---@param verbose boolean|nil @Se true, exibe detalhes diagnósticos no chat
function SyncController:startElection(verbose)
    if not IsInGuild or not IsInGuild() then
        if verbose then
            print("|cffff0000[GuildManager]|r Você não está em uma guilda para sincronizar dados.")
        end
        return
    end

    self:registerPrefix()

    if self:isSyncing() then
        if verbose then
            print(string.format("|cffff9900[GuildManager]|r Sincronização já em andamento com %s. Aguarde.", tostring(self._activeSyncPeer)))
        end
        return
    end

    if self._isConductingElection then
        if verbose then
            print("|cffff9900[GuildManager]|r Já existe uma busca de membros em andamento. Aguarde alguns instantes.")
        end
        return
    end

    self._isConductingElection = true
    self._electionCandidates = {}
    self._verboseDiagnostics = verbose or false

    local myUptime = self._syncService:getUptime()
    if self._verboseDiagnostics then
        print(string.format("|cff00ff00[GuildManager]|r Procurando membros da guilda com o AddOn... (seu tempo online: %ds)", myUptime))
    end

    -- Envia transmissão HELLO para a guilda com seu uptime atual
    self._syncService:sendLogicalMessage("HELLO", myUptime, "*")

    -- Aguarda 2 segundos para coletar respostas de outros jogadores online com o AddOn
    if C_Timer and C_Timer.After then
        C_Timer.After(2.0, function()
            self:resolveElection()
        end)
    else
        self:resolveElection()
    end
end

--- Avalia as respostas recebidas e decide a direção da sincronização garantindo concatenação sem perda.
function SyncController:resolveElection()
    if not self._isConductingElection then
        return
    end
    self._isConductingElection = false

    local myUptime = self._syncService:getUptime()
    local myName = self._syncService:getMyName()

    local bestCandidate = nil
    local maxUptime = -1

    for candidateName, uptime in pairs(self._electionCandidates) do
        if uptime > maxUptime then
            maxUptime = uptime
            bestCandidate = candidateName
        elseif uptime == maxUptime and bestCandidate then
            -- Desempate alfabético determinístico
            if candidateName:lower() < bestCandidate:lower() then
                bestCandidate = candidateName
            end
        end
    end

    if not bestCandidate then
        -- Nenhum outro membro com o AddOn respondeu
        self:releaseSyncLock()
        if self._verboseDiagnostics then
            print("|cffff9900[GuildManager]|r Nenhum outro membro com o AddOn online no momento. O banco de dados está pronto.")
        end
        return
    end

    -- Determina quem é o coordenador (o online há mais tempo)
    local remoteIsOlder = (maxUptime > myUptime) or (maxUptime == myUptime and bestCandidate:lower() < myName:lower())

    if remoteIsOlder then
        -- O membro remoto está online há mais tempo!
        -- Solicitamos (PULL) que ele nos envie a base dele
        if not self:acquireSyncLock(bestCandidate) then
            return
        end

        if self._syncNotificationView and type(self._syncNotificationView.showProgress) == "function" then
            self._syncNotificationView:showProgress(bestCandidate)
        end
        print(string.format("|cff00ff00[GuildManager]|r Sincronizando com |cffffff00%s|r...", tostring(bestCandidate)))

        self._syncService:sendLogicalMessage("PULL", { target = bestCandidate }, bestCandidate)
        self:startSyncWatchdog(bestCandidate)
    else
        -- O jogador local está online há mais tempo!
        -- O jogador local é o provedor e envia a base diretamente para o recém-chegado
        if not self:acquireSyncLock(bestCandidate) then
            return
        end

        if self._syncNotificationView and type(self._syncNotificationView.showProgress) == "function" then
            self._syncNotificationView:showProgress(bestCandidate)
        end
        print(string.format("|cff00ff00[GuildManager]|r Sincronizando com |cffffff00%s|r...", tostring(bestCandidate)))

        local exportData = self._syncService:exportAllData()
        self._syncService:sendLogicalMessage("DATA", exportData, bestCandidate)
        self:startSyncWatchdog(bestCandidate)
    end
end

--- Configura as ações para cada mensagem do protocolo de sincronização.
function SyncController:setupSyncCallbacks()
    if not self._syncService then return end

    -- 1. HELLO: Outro jogador acabou de logar ou solicitou sincronização
    self._syncService:registerCallback("HELLO", function(sender, payload)
        -- Se já estivermos ocupados sincronizando ativamente, não participa
        if self:isSyncing() then
            return
        end

        local myUptime = self._syncService:getUptime()
        -- SEMPRE responde informando seu próprio uptime para que o iniciador conheça todos os membros online
        self._syncService:sendLogicalMessage("UPTIME", myUptime, sender)
    end)

    -- 2. UPTIME: Resposta recebida dos jogadores já online informando quanto tempo estão conectados
    self._syncService:registerCallback("UPTIME", function(sender, payload)
        if self._isConductingElection then
            local remoteUptime = tonumber(payload) or 0
            self._electionCandidates[sender] = remoteUptime
            if self._verboseDiagnostics then
                print(string.format("|cff00ff00[GuildManager]|r Membro encontrado: |cffffff00%s|r (online há %ds)", tostring(sender), remoteUptime))
            end
        end
    end)

    -- 3. PULL: Jogador recém-logado solicita que o jogador online há mais tempo envie seu banco de dados
    self._syncService:registerCallback("PULL", function(sender, payload)
        local myName = self._syncService:getMyName()
        local chosenTarget = ""

        if type(payload) == "table" and payload.target then
            chosenTarget = self._syncService:sanitizeName(payload.target)
        elseif type(payload) == "string" then
            chosenTarget = self._syncService:sanitizeName(payload)
        end

        -- Se este cliente for o escolhido (o online há mais tempo)
        if chosenTarget == myName then
            -- Tenta obter a trava exclusiva com este remetente
            if not self:acquireSyncLock(sender) then
                -- Ocupado com outro membro! Avisa o remetente para evitar colisão
                self._syncService:sendLogicalMessage("BUSY", { activePeer = self._activeSyncPeer }, sender)
                return
            end

            -- Mostra na tela e no chat com quem está sincronizando
            if self._syncNotificationView and type(self._syncNotificationView.showProgress) == "function" then
                self._syncNotificationView:showProgress(sender)
            end
            print(string.format("|cff00ff00[GuildManager]|r Sincronizando com |cffffff00%s|r...", tostring(sender)))

            local exportData = self._syncService:exportAllData()
            self._syncService:sendLogicalMessage("DATA", exportData, sender)
            self:startSyncWatchdog(sender)
        end
    end)

    -- 4. BUSY: Notificação de que o membro alvo está ocupado sincronizando com outra pessoa
    self._syncService:registerCallback("BUSY", function(sender, payload)
        self:releaseSyncLock()
        if self._syncNotificationView then
            self._syncNotificationView:hide()
        end
        print(string.format("|cffff9900[GuildManager]|r %s está ocupado sincronizando com outro membro no momento. A sincronização ocorrerá em breve.", tostring(sender)))
    end)

    -- 5. DATA: Dados recebidos do jogador com a base
    self._syncService:registerCallback("DATA", function(sender, payload)
        if type(payload) ~= "table" then return end

        local cleanSender = self._syncService:sanitizeName(sender)
        -- Proteção: rejeita pacotes vindos de terceiros se já estamos sincronizando com alguém diferente
        if self:isSyncing() and self._activeSyncPeer and self._activeSyncPeer ~= cleanSender then
            return
        end

        self:acquireSyncLock(sender)

        -- Mescla os dados recebidos sem sobreescrever (com proteção contra erros)
        local ok, summary = pcall(function()
            return self._syncService:mergeAllData(payload)
        end)

        if not ok or type(summary) ~= "table" then
            self:handleSyncError("Falha ao gravar informações recebidas no banco", sender)
            return
        end

        -- Atualiza as interfaces gráficas abertas
        self:refreshViews()

        -- Exibe a caixinha de notificação de sincronização realizada com fade de 3 segundos
        if self._syncNotificationView and type(self._syncNotificationView.showSuccess) == "function" then
            self._syncNotificationView:showSuccess(sender, summary)
        end

        -- Verifica se o jogador local tem informações adicionais que o remoto não possuía
        -- (para caso onde o jogador local jogou offline ou criou eventos enquanto sozinho)
        local diff = self._syncService:computeDiff(payload)
        local hasDiff = (#diff.events > 0 or #diff.groups > 0 or #diff.members > 0)

        if hasDiff then
            -- Envia as informações complementares de volta para que ambos fiquem 100% sincronizados
            self._syncService:sendLogicalMessage("DIFF", diff, sender)
            self:startSyncWatchdog(sender)
        else
            -- Confirmação final
            self._syncService:sendLogicalMessage("ACK", "OK", sender)
            self:releaseSyncLock()
        end

        local totalNew = (summary.totalAdded or 0)
        local totalUpd = (summary.totalUpdated or 0)
        if totalNew > 0 or totalUpd > 0 then
            print(string.format("|cff00ff00[GuildManager]|r Sincronização concluída com |cffffff00%s|r! (+%d novos registros, %d complementados)",
                tostring(sender), totalNew, totalUpd))
        else
            print(string.format("|cff00ff00[GuildManager]|r Sincronização concluída com |cffffff00%s|r! Banco de dados atualizado.",
                tostring(sender)))
        end
    end)

    -- 6. DIFF: Informações adicionais/complementares enviadas de volta pelo jogador recém-logado
    self._syncService:registerCallback("DIFF", function(sender, payload)
        if type(payload) ~= "table" then return end

        local cleanSender = self._syncService:sanitizeName(sender)
        if self:isSyncing() and self._activeSyncPeer and self._activeSyncPeer ~= cleanSender then
            return
        end

        self:acquireSyncLock(sender)

        local ok, summary = pcall(function()
            return self._syncService:mergeAllData(payload)
        end)

        if not ok or type(summary) ~= "table" then
            self:handleSyncError("Falha ao gravar informações complementares no banco", sender)
            return
        end

        self:refreshViews()

        -- Exibe a caixinha de notificação de sincronização realizada com fade de 3 segundos
        if self._syncNotificationView and type(self._syncNotificationView.showSuccess) == "function" then
            self._syncNotificationView:showSuccess(sender, summary)
        end

        self._syncService:sendLogicalMessage("ACK", "OK", sender)
        self:releaseSyncLock()

        local totalNew = (summary.totalAdded or 0)
        local totalUpd = (summary.totalUpdated or 0)
        if totalNew > 0 or totalUpd > 0 then
            print(string.format("|cff00ff00[GuildManager]|r Informações complementares recebidas de |cffffff00%s|r e adicionadas com sucesso! (+%d novos, %d complementados)",
                tostring(sender), totalNew, totalUpd))
        else
            print(string.format("|cff00ff00[GuildManager]|r Informações sincronizadas com sucesso com |cffffff00%s|r!",
                tostring(sender)))
        end
    end)

    -- 7. ACK: Confirmação de recebimento e encerramento da sessão de sincronização
    self._syncService:registerCallback("ACK", function(sender)
        self:releaseSyncLock()
    end)

    -- 8. ERROR: Tratamento e exibição visual de falhas capturadas
    self._syncService:registerCallback("ERROR", function(peerName, errorMessage)
        self:handleSyncError(errorMessage, peerName)
    end)
end

--- Trata e exibe visualmente qualquer erro ocorrido durante o processo de sincronização.
---@param errorMessage string
---@param peerName string|nil
function SyncController:handleSyncError(errorMessage, peerName)
    local targetPeer = peerName or self._activeSyncPeer or "Guilda"
    targetPeer = (targetPeer:match("^[^-]+") or targetPeer)

    -- Libera a trava imediatamente para não bloquear futuras sincronizações
    self:releaseSyncLock()

    -- Exibe a caixinha de notificação de erro visualmente com efeito de fade de 3 segundos
    if self._syncNotificationView and type(self._syncNotificationView.showError) == "function" then
        self._syncNotificationView:showError(targetPeer, errorMessage)
    end

    -- Alerta no chat em vermelho
    print(string.format("|cffff0000[GuildManager]|r Erro na sincronização com |cffffff00%s|r: %s",
        tostring(targetPeer), tostring(errorMessage or "Falha inesperada")))
end

--- Atualiza as views do AddOn com os novos dados sincronizados.
function SyncController:refreshViews()
    -- Atualiza Agenda
    if self._agendaController and type(self._agendaController.refreshAgenda) == "function" then
        pcall(self._agendaController.refreshAgenda, self._agendaController)
    end

    -- Atualiza Grupos
    if self._groupController and type(self._groupController.refreshGroups) == "function" then
        pcall(self._groupController.refreshGroups, self._groupController)
    end

    -- Atualiza Auditoria
    if self._auditController and type(self._auditController.refreshAudit) == "function" then
        pcall(self._auditController.refreshAudit, self._auditController)
    end

    -- Atualiza Detalhes de Membro se estiver visível
    if self._memberView and self._memberService then
        local frame = self._memberView.getFrame and self._memberView:getFrame()
        if frame and frame:IsShown() and self._memberView._currentMember then
            local memName = self._memberView._currentMember:getName()
            local updated = self._memberService:getMember(memName)
            if updated and self._memberView.showMember then
                pcall(self._memberView.showMember, self._memberView, updated, self._memberView:isLocked())
            end
        end
    end
end

_G.SyncController = SyncController
return SyncController
