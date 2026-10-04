local addonName, addonTable = ...

_G.GM = _G.GM or addonTable or {}

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

        local minimapButton = MinimapButton:new()

        local worldMapView = WorldMapView:new()
        local worldMapController = WorldMapController:new(memberService, guildRosterService, worldMapView)

        GM.database = databaseManager
        GM.logRepository = logRepository
        GM.logService = logService
        GM.logView = logView
        GM.logController = logController
        GM.memberRepository = memberRepository
        GM.memberService = memberService
        GM.guildRosterService = guildRosterService
        GM.memberView = memberView
        GM.memberController = memberController
        GM.auditView = auditView
        GM.auditController = auditController
        GM.minimapButton = minimapButton
        GM.worldMapView = worldMapView
        GM.worldMapController = worldMapController

        memberController:initHooks()
        logController:initHooks()
        auditController:initHooks()
        worldMapController:initHooks()

        if logRepository.cleanDuplicateKickAndLeaveLogs then
            logRepository:cleanDuplicateKickAndLeaveLogs(memberService)
        end

        print("|cff00ff00[GuildManager]|r AddOn carregado com sucesso! Digite |cffffff00/gm|r, |cffffff00/gmlogs|r ou |cffffff00/gmaudit|r para abrir.")

        -- Desregistra o evento ADDON_LOADED pois o ciclo de inicialização já foi concluído
        self:UnregisterEvent("ADDON_LOADED")
    end
end)