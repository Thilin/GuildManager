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

-- Filtro de mensagens de sistema para eliminar permanentemente alertas visuais de limite de envio e whispers
local function filterSystemChatMessages(self, event, msg, ...)
    if type(msg) == "string" and msg ~= "" then
        -- 1. Filtra avisos de limite de mensagens (throttling da Blizzard)
        if _G.ERR_CHAT_THROTTLED and msg == _G.ERR_CHAT_THROTTLED then
            return true
        end
        if msg:find("número de mensagens que podem ser enviadas")
            or msg:find("The number of messages that can be sent is limited") then
            return true
        end

        -- 2. Filtra avisos de jogador não encontrado decorrentes de whispers automáticos
        if _G.ERR_CHAT_PLAYER_NOT_FOUND_S then
            local pattern = _G.ERR_CHAT_PLAYER_NOT_FOUND_S:gsub("%%s", ".-")
            if msg:find(pattern) then
                return true
            end
        end
        if msg:find("Nenhum jogador de nome '.-' está jogando no momento")
            or msg:find("No player named '.-' is currently playing") then
            return true
        end
    end
    return false, msg, ...
end

if ChatFrame_AddMessageEventFilter then
    pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_SYSTEM", filterSystemChatMessages)
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
        local syncConflictView = SyncConflictView:new()
        local syncService = SyncService:new(memberService, locationService, settingsService, guildRosterService)
        syncService:setSyncConflictView(syncConflictView)
        memberService:setSyncService(syncService)

        local worldMapView = WorldMapView:new()
        local worldMapController = WorldMapController:new(memberService, guildRosterService, worldMapView, locationService)

        local chatMentionView = ChatMentionView:new()
        local chatMentionController = ChatMentionController:new(memberService, guildRosterService, chatMentionView)

        local craftOrderRepository = CraftOrderRepository:new(dbTable)
        local professionRepository = ProfessionRepository:new(memberService, craftOrderRepository)
        local professionService = ProfessionService:new(professionRepository, craftOrderRepository, memberService, guildRosterService, syncService)
        local professionView = ProfessionView:new()
        local professionController = ProfessionController:new(professionService, guildRosterService, memberService, professionView)

        local introView = IntroView:new()
        local introController = IntroController:new(introView, memberService, guildRosterService, settingsService, syncService)

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
        GM.craftOrderRepository = craftOrderRepository
        GM.professionRepository = professionRepository
        GM.professionService = professionService
        GM.professionView = professionView
        GM.professionController = professionController
        GM.introView = introView
        GM.introController = introController
        GM.syncConflictView = syncConflictView

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
        professionService:initHooks()
        professionController:initHooks()
        introController:initHooks()

        -- Sanitiza o banco de dados contra duplicatas espúrias geradas por loops de eventos da Blizzard
        if logService and logService.cleanDuplicateAndSpuriousLogs then
            logService:cleanDuplicateAndSpuriousLogs(memberService)
        end

        -- Harmoniza a consistência bidirecional de famílias de alts no banco de dados
        if memberService and memberService.healAltFamilyConsistency then
            memberService:healAltFamilyConsistency()
        end

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
                if professionView and professionView.updateLocale then professionView:updateLocale() end
                if introView and introView.updateLocale then introView:updateLocale() end
                if chatMentionView and chatMentionView.updateLocale then chatMentionView:updateLocale() end
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
        if professionView and professionView.updateLocale then professionView:updateLocale() end
        if introView and introView.updateLocale then introView:updateLocale() end
        if chatMentionView and chatMentionView.updateLocale then chatMentionView:updateLocale() end

        SLASH_GUILDMANAGER_LOC1 = "/gmloc"
        SlashCmdList["GUILDMANAGER_LOC"] = function(msg)
            local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
            local arg = (msg or ""):lower():match("^%s*(.-)%s*$")
            if arg == "test" or arg == "peer" then
                if locationService then
                    locationService:toggleTestPeer()
                end
            elseif arg == "login" then
                if minimapButton and minimapButton.flashPeerLogin then
                    minimapButton:flashPeerLogin()
                    print(curL["GMLOC_TEST_LOGIN"] or "|cff00ffff[GuildManager]|r Visual test: LOGIN pulse (blue) on minimap button.")
                end
            elseif arg == "logout" then
                if minimapButton and minimapButton.flashPeerLogout then
                    minimapButton:flashPeerLogout()
                    print(curL["GMLOC_TEST_LOGOUT"] or "|cffff2020[GuildManager]|r Visual test: LOGOUT pulse (red) on minimap button.")
                end
            else
                local count = locationService and locationService:getPeerCount() or 0
                print(string.format(curL["GMLOC_INFO_FMT"] or "|cff00ff00[GuildManager]|r Real-time tracking active. Connected members: |cffffff00%d|r. Type |cffffff00/gmloc test|r to toggle simulated member, or |cffffff00/gmloc login|r / |cffffff00/gmloc logout|r to test pulses.", count))
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
                local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
                print(curL["GMSYNC_HELP_HEADER"] or "|cff00ff00[GuildManager]|r Sync Commands:")
                print(curL["GMSYNC_HELP_SYNC"] or "  |cffffff00/gmsync|r or |cffffff00/gm sync|r : Forces manual sync of all custom data.")
                print(curL["GMSYNC_HELP_STATUS"] or "  |cffffff00/gmsync status|r : Displays queue status and online members with Addon.")
                print(curL["GMSYNC_HELP_TEST"] or "  |cffffff00/gmsync test|r : Simulates a test ACK confirmation.")
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
        local welcomeMsg = curL["WELCOME_LOADED"] or "AddOn loaded successfully! Type |cffffff00/gm|r, |cffffff00/gmcraft|r, |cffffff00/gmsync|r, |cffffff00/gmloc|r, |cffffff00/gmlogs|r, |cffffff00/gmaudit|r, |cffffff00/gmgrupos|r, |cffffff00/gmagenda|r or |cffffff00/gmconfig|r to open."
        print("|cff00ff00[GuildManager]|r " .. welcomeMsg)

        -- Desregistra o evento ADDON_LOADED pois o ciclo de inicialização já foi concluído
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

--- Alterna dinamicamente os repositórios para a guilda ativa do personagem atual.
--- Garante que dados de uma guilda jamais apareçam em outro personagem de guilda diferente.
function GM.switchActiveGuild(guildName, realmName, force)
    local gName = guildName
    if not gName and GetGuildInfo then
        local ok, info = pcall(GetGuildInfo, "player")
        if ok and info and info ~= "" then
            gName = info
        end
    end

    if IsInGuild and not IsInGuild() then
        gName = nil
    end

    if GM.database and GM.database.switchGuild then
        local currentKey = GM.database:getCurrentGuildKey()
        local newKey = GM.database:getGuildKey(gName, realmName)

        -- Se a guilda não mudou e já está devidamente vinculada, não há necessidade de resetar caches
        if not force and currentKey and newKey and currentKey == newKey and GM.database:getActiveDatabase() then
            return GM.database:getActiveDatabase(), currentKey
        end

        local guildDb, key = GM.database:switchGuild(gName, realmName)

        local targetDb = guildDb
        if not targetDb then
            targetDb = { members = {}, logs = {}, groups = {}, events = {}, craftOrders = {}, professions = {} }
        end

        if GM.memberRepository and GM.memberRepository.setDatabase then
            GM.memberRepository:setDatabase(targetDb)
            if GM.memberRepository.resetOnlineStatus then
                GM.memberRepository:resetOnlineStatus()
            end
        end
        if GM.logRepository and GM.logRepository.setDatabase then
            GM.logRepository:setDatabase(targetDb)
        end
        if GM.groupRepository and GM.groupRepository.setDatabase then
            GM.groupRepository:setDatabase(targetDb)
        end
        if GM.eventRepository and GM.eventRepository.setDatabase then
            GM.eventRepository:setDatabase(targetDb)
        end
        if GM.eventService and GM.eventService.invalidateCache then
            GM.eventService:invalidateCache()
        end
        if GM.craftOrderRepository and GM.craftOrderRepository.setDatabase then
            GM.craftOrderRepository:setDatabase(targetDb)
        end

        if GM.guildRosterService and GM.guildRosterService.clearActiveRoster then
            GM.guildRosterService:clearActiveRoster()
        end
        if GM.memberService and GM.memberService.clearRosterCache then
            GM.memberService:clearRosterCache()
        end
        if GM.locationService and GM.locationService.clearPeers then
            GM.locationService:clearPeers()
        end
        if GM.worldMapView and GM.worldMapView.clearPins then
            GM.worldMapView:clearPins()
        end

        return targetDb, key
    end
end

local guildWatchFrame = CreateFrame("Frame")
guildWatchFrame:RegisterEvent("PLAYER_LOGIN")
guildWatchFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
guildWatchFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
guildWatchFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
guildWatchFrame:SetScript("OnEvent", function(_, event)
    if GM.switchActiveGuild then
        GM.switchActiveGuild()
    end
end)