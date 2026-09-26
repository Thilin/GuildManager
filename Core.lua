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

        memberController:initHooks()
        logController:initHooks()

        print("|cff00ff00[GuildManager]|r AddOn carregado com sucesso! Digite |cffffff00/gm|r ou |cffffff00/gmlogs|r para abrir.")

        -- Desregistra o evento ADDON_LOADED pois o ciclo de inicialização já foi concluído
        self:UnregisterEvent("ADDON_LOADED")
    end
end)