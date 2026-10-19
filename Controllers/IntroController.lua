local addonName, addonTable = ...
local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })

---@class IntroController
---@field private _introView IntroView
---@field private _memberService MemberService|nil
---@field private _guildRosterService GuildRosterService|nil
---@field private _settingsService SettingsService|nil
---@field private _syncService SyncService|nil
---@field private _eventFrame table|nil
IntroController = {}
IntroController.__index = IntroController

--- Obtém o timestamp sincronizado do servidor
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

--- Construtor do controlador de introdução e checagem de guilda.
---@param introView IntroView
---@param memberService MemberService|nil
---@param guildRosterService GuildRosterService|nil
---@param settingsService SettingsService|nil
---@param syncService SyncService|nil
---@return IntroController
function IntroController:new(introView, memberService, guildRosterService, settingsService, syncService)
    local instance = setmetatable({}, self)

    instance._introView = introView
    instance._memberService = memberService
    instance._guildRosterService = guildRosterService
    instance._settingsService = settingsService
    instance._syncService = syncService
    instance._hasCheckedOnLogin = false

    instance:setupCallbacks()

    return instance
end

--- Configura as ações e eventos emitidos pela View.
function IntroController:setupCallbacks()
    local view = self._introView
    if not view then return end

    view:setOnCompleteCallback(function()
        self:onTutorialFinished()
    end)

    view:setOnSkipCallback(function()
        self:onTutorialSkipped()
    end)

    view:setOnBirthdaySubmittedCallback(function(bdayStr, isValid)
        self:onBirthdaySubmitted(bdayStr, isValid)
    end)

    view:setOnOpenAuditCallback(function()
        if _G.GM and _G.GM.auditController then
            _G.GM.auditController:show()
        end
    end)

    view:setOnOpenLogsCallback(function()
        if _G.GM and _G.GM.logController then
            _G.GM.logController:show()
        end
    end)

    view:setOnOpenAgendaCallback(function()
        if _G.GM and _G.GM.agendaController then
            _G.GM.agendaController:show()
        end
    end)

    view:setOnOpenGroupsCallback(function()
        if _G.GM and _G.GM.groupController then
            _G.GM.groupController:show()
        end
    end)

    view:setOnOpenProfessionsCallback(function()
        if _G.GM and _G.GM.professionController then
            _G.GM.professionController:show()
        end
    end)

    view:setOnOpenWorldMapCallback(function()
        if ToggleWorldMap then
            ToggleWorldMap()
        end
    end)

    view:setOnOpenSettingsCallback(function()
        if _G.GM and _G.GM.settingsController then
            _G.GM.settingsController:show()
        end
    end)
end

--- Disparado ao salvar ou submeter uma data de aniversário no tutorial.
---@param bdayStr string
---@param isValid boolean
function IntroController:onBirthdaySubmitted(bdayStr, isValid)
    if not isValid or not bdayStr or bdayStr == "" then return end

    -- 1. Salva no banco raiz SavedVariables
    if _G.GM_DB then
        _G.GM_DB.playerBirthday = bdayStr
        if _G.GM_DB.settings then
            _G.GM_DB.settings.playerBirthday = bdayStr
        end
    end

    -- 2. Salva na entidade Member do jogador
    local playerName = UnitName("player")
    if playerName and self._memberService then
        local member = self._memberService:getMember(playerName)
        if member then
            member:setBirthday(bdayStr)
            member:setCustomDataTimestamp(getCurrentTimestamp())
            self._memberService:saveMember(member)
        end
    end

    local curL = (_G.GM and _G.GM.L) or _G.L or L
    local msg = string.format(curL["INTRO_STEP5_BDAY_SAVED"] or "Aniversário configurado: %s", bdayStr)
    print("|cff00ff00[GuildManager]|r " .. msg)
end

--- Disparado ao concluir todos os passos do tutorial.
function IntroController:onTutorialFinished()
    if _G.GM_DB then
        _G.GM_DB.introCompleted = true
        _G.GM_DB.tutorialCompleted = true
    end

    local curL = (_G.GM and _G.GM.L) or _G.L or L
    local msg = curL["INTRO_TUTORIAL_COMPLETED_MSG"] or "Introdução concluída com sucesso! Digite /gm para começar."
    print("|cff00ff00[GuildManager]|r " .. msg)
end

--- Disparado ao pular o tutorial.
function IntroController:onTutorialSkipped()
    if _G.GM_DB then
        _G.GM_DB.introCompleted = true
        _G.GM_DB.tutorialCompleted = true
    end

    local curL = (_G.GM and _G.GM.L) or _G.L or L
    local hint = curL["INTRO_REOPEN_HINT"] or "Você pode rever este tutorial a qualquer momento digitando |cffffff00/gmtutorial|r ou na tela de Configurações."
    print("|cff00ff00[GuildManager]|r " .. hint)
end

--- Verifica se o jogador está em guilda e se deve exibir a introdução ou o aviso de sem guilda.
function IntroController:checkGuildAndIntroStatus()
    local inGuild = false
    if IsInGuild then
        inGuild = (IsInGuild() == true)
    end

    if not inGuild then
        -- O jogador não está em guilda: fecha o tutorial e exibe a tela de aviso de sem guilda
        if self._introView then
            self._introView:hide()
            self._introView:showNoGuildDialog()
        end
        return
    end

    -- O jogador está em guilda: fecha o aviso de sem guilda caso estivesse aberto
    if self._introView then
        self._introView:hideNoGuildDialog()
    end

    -- Aplica aniversário persistido ao Member caso ainda não tenha sido gravado nele
    if _G.GM_DB and _G.GM_DB.playerBirthday and _G.GM_DB.playerBirthday ~= "" then
        local playerName = UnitName("player")
        if playerName and self._memberService then
            local member = self._memberService:getMember(playerName)
            if member and (member:getBirthday() or "") == "" then
                member:setBirthday(_G.GM_DB.playerBirthday)
                member:setCustomDataTimestamp(getCurrentTimestamp())
                self._memberService:saveMember(member)
            end
        end
    end

    -- Verifica se o jogador já viu/completou o tutorial alguma vez
    local alreadySeen = false
    if _G.GM_DB then
        if _G.GM_DB.introCompleted == true or _G.GM_DB.tutorialCompleted == true or _G.GM_DB.hasSeenIntro == true then
            alreadySeen = true
        end
    end

    -- Se nunca viu o tutorial, exibe a apresentação guiada!
    if not alreadySeen and self._introView then
        self._introView:show()
    end
end

--- Exibe a apresentação/tutorial guiado a qualquer momento, mesmo que já concluído.
---@param isReset boolean|nil @Se verdadeiro, reinicia também o status de conclusão no banco
function IntroController:showTutorial(isReset)
    if isReset and _G.GM_DB then
        _G.GM_DB.introCompleted = false
        _G.GM_DB.tutorialCompleted = false
        _G.GM_DB.hasSeenIntro = false
    end

    if self._introView then
        self._introView:show()
        if self._introView.goToStep then
            self._introView:goToStep(1)
        end
    end

    local curL = (_G.GM and _G.GM.L) or _G.L or L
    local msg = curL["INTRO_REOPENED_MSG"] or "Apresentação da guilda reaberta! Você pode rever a qualquer momento com /gmtutorial."
    print("|cff00ff00[GuildManager]|r " .. msg)
end

--- Registra comandos de barra (slash commands) e ouvintes de login e eventos de guilda.
function IntroController:initHooks()
    SLASH_GUILDMANAGER_INTRO1 = "/gmtutorial"
    SLASH_GUILDMANAGER_INTRO2 = "/gmintro"
    SLASH_GUILDMANAGER_INTRO3 = "/gmtutorialreset"
    SlashCmdList["GUILDMANAGER_INTRO"] = function(msg)
        local arg = (msg or ""):lower():match("^%s*(.-)%s*$")
        local isReset = (arg == "reset" or arg == "reiniciar" or arg == "limpar")
        self:showTutorial(isReset)
    end

    if not self._eventFrame then
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
        eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")

        eventFrame:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_ENTERING_WORLD" then
                -- Aguarda brevemente para que o cliente do WoW receba a confirmação de guilda do servidor
                if C_Timer and C_Timer.After then
                    C_Timer.After(2.5, function()
                        self:checkGuildAndIntroStatus()
                    end)
                else
                    self:checkGuildAndIntroStatus()
                end
            elseif event == "PLAYER_GUILD_UPDATE" then
                -- Disparado quando o jogador entra ou sai de uma guilda
                if C_Timer and C_Timer.After then
                    C_Timer.After(1.0, function()
                        self:checkGuildAndIntroStatus()
                    end)
                else
                    self:checkGuildAndIntroStatus()
                end
            elseif event == "GUILD_ROSTER_UPDATE" then
                -- Sincroniza aniversário do jogador se foi persistido antes do primeiro scan do roster
                if _G.GM_DB and _G.GM_DB.playerBirthday and _G.GM_DB.playerBirthday ~= "" then
                    local playerName = UnitName("player")
                    if playerName and self._memberService then
                        local member = self._memberService:getMember(playerName)
                        if member and (member:getBirthday() or "") == "" then
                            member:setBirthday(_G.GM_DB.playerBirthday)
                            member:setCustomDataTimestamp(getCurrentTimestamp())
                            self._memberService:saveMember(member)
                        end
                    end
                end
            end
        end)

        self._eventFrame = eventFrame
    end
end

--- Exibe a introdução manualmente.
function IntroController:show()
    self:showTutorial(false)
end

--- Oculta a introdução.
function IntroController:hide()
    if self._introView then
        self._introView:hide()
    end
end

_G.IntroController = IntroController
