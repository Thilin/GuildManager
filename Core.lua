local addonName, addonTable = ...

_G.GM = _G.GM or addonTable or {}

--- Verifica com segurança se um valor é um "Secret Value" (WoW 11.0+ / 12.0+ / Classic Beta)
---@param val any
---@return boolean
function GM.isSecretValue(val)
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

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")

initFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == addonName then
        local databaseManager = Database:new()
        local dbTable = databaseManager:init()

        local logRepository = LogRepository:new(dbTable)
        local logService = LogService:new(logRepository)

        local memberRepository = MemberRepository:new(dbTable)
        local memberService = MemberService:new(memberRepository, logService)
        local guildRosterService = GuildRosterService:new(memberService)
        local memberView = MemberView:new()
        local memberController = MemberController:new(memberService, guildRosterService, memberView, logService)

        local logView = LogView:new()
        local logController = LogController:new(logService, logView)

        local auditView = AuditView:new()
        local auditController = AuditController:new(memberService, guildRosterService, auditView, logService)

        local groupRepository = GroupRepository:new(dbTable)
        local groupService = GroupService:new(groupRepository, memberService, guildRosterService)
        local groupView = GroupView:new()
        local groupController = GroupController:new(groupService, memberService, guildRosterService, groupView)

        local eventRepository = EventRepository:new(dbTable)
        local eventService = EventService:new(eventRepository, memberService, guildRosterService)
        local agendaView = AgendaView:new()
        local agendaController = AgendaController:new(eventService, memberService, guildRosterService, agendaView)

        local minimapButton = MinimapButton:new()

        local settingsService = SettingsService:new(dbTable, logRepository, memberService, guildRosterService)
        local settingsView = SettingsView:new()
        local settingsController = SettingsController:new(settingsService, settingsView, memberService, guildRosterService, logService, minimapButton)

        local locationService = LocationService:new(memberService)
        local syncService = SyncService:new(memberService, locationService, settingsService)
        memberService:setSyncService(syncService)

        local worldMapView = WorldMapView:new()
        local worldMapController = WorldMapController:new(memberService, guildRosterService, worldMapView, locationService)

        local chatMentionView = ChatMentionView:new()
        local chatMentionController = ChatMentionController:new(memberService, guildRosterService, chatMentionView)

        GM.database = databaseManager
        GM.logRepository = logRepository
        GM.logService = logService
        GM.logView = logView
        GM.logController = logController
        GM.memberRepository = memberRepository
        GM.memberService = memberService
        GM.syncService = syncService
        GM.guildRosterService = guildRosterService
        GM.memberView = memberView
        GM.memberController = memberController
        GM.auditView = auditView
        GM.auditController = auditController
        GM.groupRepository = groupRepository
        GM.groupService = groupService
        GM.groupView = groupView
        GM.groupController = groupController
        GM.eventRepository = eventRepository
        GM.eventService = eventService
        GM.agendaView = agendaView
        GM.agendaController = agendaController
        GM.settingsService = settingsService
        GM.settingsView = settingsView
        GM.settingsController = settingsController
        GM.minimapButton = minimapButton
        GM.locationService = locationService
        GM.worldMapView = worldMapView
        GM.worldMapController = worldMapController
        GM.chatMentionView = chatMentionView
        GM.chatMentionController = chatMentionController

        locationService:initHooks()
        syncService:initHooks()
        memberController:initHooks()
        logController:initHooks()
        auditController:initHooks()
        groupController:initHooks()
        agendaController:initHooks()
        settingsController:initHooks()
        worldMapController:initHooks()
        chatMentionController:initHooks()

        if minimapButton and minimapButton.initLocationListener then
            minimapButton:initLocationListener(locationService)
        end

        -- Registra o listener para atualização de idioma em tempo real ("na hora")
        if GM.RegisterLocaleListener then
            GM.RegisterLocaleListener(function(newLang)
                if settingsView and settingsView.updateLocale then settingsView:updateLocale() end
                if auditView and auditView.updateLocale then auditView:updateLocale() end
                if logView and logView.updateLocale then logView:updateLocale() end
                if groupView and groupView.updateLocale then groupView:updateLocale() end
                if agendaView and agendaView.updateLocale then agendaView:updateLocale() end
                if memberView and memberView.updateLocale then memberView:updateLocale() end
                if worldMapView and worldMapView.updateLocale then worldMapView:updateLocale() end
                if minimapButton and minimapButton.updateLocale then minimapButton:updateLocale() end
            end)
        end

        -- Aplica o idioma persistido (padrão enUS)
        local initialLang = settingsService:get("language", "enUS")
        if GM.SetLocale then
            GM.SetLocale(initialLang, true)
        end
        if settingsView and settingsView.updateLocale then settingsView:updateLocale() end
        if auditView and auditView.updateLocale then auditView:updateLocale() end
        if logView and logView.updateLocale then logView:updateLocale() end
        if groupView and groupView.updateLocale then groupView:updateLocale() end
        if agendaView and agendaView.updateLocale then agendaView:updateLocale() end
        if memberView and memberView.updateLocale then memberView:updateLocale() end
        if worldMapView and worldMapView.updateLocale then worldMapView:updateLocale() end
        if minimapButton and minimapButton.updateLocale then minimapButton:updateLocale() end

        SLASH_GUILDMANAGER_LOC1 = "/gmloc"
        SlashCmdList["GUILDMANAGER_LOC"] = function(msg)
            local arg = (msg or ""):lower():match("^%s*(.-)%s*$")
            if arg == "test" or arg == "peer" then
                if locationService then
                    locationService:toggleTestPeer()
                end
            elseif arg == "login" then
                if minimapButton and minimapButton.flashPeerLogin then
                    minimapButton:flashPeerLogin()
                    print("|cff00ffff[GuildManager]|r Teste visual: Pulso de LOGIN (azul) no botão do minimapa.")
                end
            elseif arg == "logout" then
                if minimapButton and minimapButton.flashPeerLogout then
                    minimapButton:flashPeerLogout()
                    print("|cffff2020[GuildManager]|r Teste visual: Pulso de LOGOUT (vermelho) no botão do minimapa.")
                end
            else
                local count = locationService and locationService:getPeerCount() or 0
                print(string.format("|cff00ff00[GuildManager]|r Posições em tempo real ativas. Membros conectados: |cffffff00%d|r. Digite |cffffff00/gmloc test|r para alternar um membro simulado, ou |cffffff00/gmloc login|r / |cffffff00/gmloc logout|r para testar as animações.", count))
            end
        end

        SLASH_GUILDMANAGER_SYNC1 = "/gmsync"
        SlashCmdList["GUILDMANAGER_SYNC"] = function(msg)
            local arg = (msg or ""):lower():match("^%s*(.-)%s*$")
            if arg == "test" or arg == "ack" then
                if syncService then
                    syncService:simulateTestPeerAck()
                end
            elseif arg == "status" then
                local status = syncService and syncService:getStatus() or { pendingCount = 0, queueCount = 0, activePeerCount = 0, activePeers = {} }
                local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
                local summary = string.format(curL["SYNC_LOG_STATUS_SUMMARY"] or "|cff00ff00[GuildManager]|r Sincronização P2P: |cffffff00%d|r membro(s) com Addon online, |cffffff00%d|r na fila de envio, |cffffff00%d|r aguardando confirmação (ACK).", status.activePeerCount, status.queueCount, status.pendingCount)
                print(summary)
                if syncService and syncService.printSyncNotification then
                    syncService:printSyncNotification(summary)
                end
                if #status.activePeers > 0 then
                    local names = {}
                    for _, p in ipairs(status.activePeers) do
                        table.insert(names, p.name)
                    end
                    local peersMsg = string.format(curL["SYNC_LOG_ONLINE_PEERS"] or "|cffaaaaaaMembros com Addon online:|r %s", table.concat(names, ", "))
                    print(peersMsg)
                    if syncService and syncService.printSyncNotification then
                        syncService:printSyncNotification(peersMsg)
                    end
                end
                if status.pendingCount > 0 then
                    local retransMsg = curL["SYNC_LOG_RETRANSMIT_NOTICE"] or "|cffaaaaaa(Retransmitindo pacotes em segundo plano até que todos confirmem o recebimento)|r"
                    print(retransMsg)
                    if syncService and syncService.printSyncNotification then
                        syncService:printSyncNotification(retransMsg)
                    end
                end
            elseif arg == "help" or arg == "ajuda" then
                print("|cff00ff00[GuildManager]|r Comandos de Sincronização:")
                print("  |cffffff00/gmsync|r ou |cffffff00/gm sync|r : Força a sincronização manual de todos os dados customizados.")
                print("  |cffffff00/gmsync status|r : Exibe o status da fila e membros online com o Addon.")
                print("  |cffffff00/gmsync test|r : Simula confirmação de recebimento (ACK) de teste.")
            else
                if syncService then
                    syncService:forceSyncAll()
                end
            end
        end

        if logRepository.cleanDuplicateKickAndLeaveLogs then
            logRepository:cleanDuplicateKickAndLeaveLogs(memberService)
        end

        local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
        local welcomeMsg = curL["WELCOME_LOADED"] or "AddOn loaded successfully! Type |cffffff00/gm|r, |cffffff00/gmsync|r, |cffffff00/gmloc|r, |cffffff00/gmlogs|r, |cffffff00/gmaudit|r, |cffffff00/gmgrupos|r, |cffffff00/gmagenda|r or |cffffff00/gmconfig|r to open."
        print("|cff00ff00[GuildManager]|r " .. welcomeMsg)

        -- Desregistra o evento ADDON_LOADED pois o ciclo de inicialização já foi concluído
        self:UnregisterEvent("ADDON_LOADED")
    end
end)