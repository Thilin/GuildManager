---@class SettingsController
---@field private _settingsService SettingsService
---@field private _settingsView SettingsView
---@field private _memberService MemberService|nil
---@field private _guildRosterService GuildRosterService|nil
---@field private _logService LogService|nil
---@field private _minimapButton MinimapButton|nil
SettingsController = {}
SettingsController.__index = SettingsController

--- Construtor do controlador de configurações.
---@param settingsService SettingsService
---@param settingsView SettingsView
---@param memberService MemberService|nil
---@param guildRosterService GuildRosterService|nil
---@param logService LogService|nil
---@param minimapButton MinimapButton|nil
---@return SettingsController
function SettingsController:new(settingsService, settingsView, memberService, guildRosterService, logService, minimapButton)
    local instance = setmetatable({}, self)

    instance._settingsService = settingsService
    instance._settingsView = settingsView
    instance._memberService = memberService
    instance._guildRosterService = guildRosterService
    instance._logService = logService
    instance._minimapButton = minimapButton

    instance:setupCallbacks()

    return instance
end

--- Configura os callbacks entre a View e os Serviços.
function SettingsController:setupCallbacks()
    local view = self._settingsView
    local service = self._settingsService

    view:setOnSaveCallback(function(formData)
        for key, val in pairs(formData) do
            service:set(key, val)
        end

        -- Aplica visibilidade do minimapa imediatamente
        if self._minimapButton and self._minimapButton._button then
            if formData.showMinimapButton then
                self._minimapButton._button:Show()
                self._minimapButton:updatePosition(formData.minimapPos or 215)
            else
                self._minimapButton._button:Hide()
            end
        end

        -- Aplica visibilidade do botão no mapa mundial imediatamente
        if _G.GM and _G.GM.worldMapView and _G.GM.worldMapView._mapButton then
            if formData.showWorldMapButton then
                _G.GM.worldMapView._mapButton:Show()
            else
                _G.GM.worldMapView._mapButton:Hide()
                if _G.GM.worldMapView.hidePanel then _G.GM.worldMapView:hidePanel() end
            end
        end

        -- Notifica no chat do jogador
        print("|cff00ff00[GuildManager]|r Configurações salvas e aplicadas com sucesso!")
        view:showStatus("Configurações salvas com sucesso!", false)
    end)

    view:setOnResetCallback(function()
        service:resetToDefaults()
        local settings = service:getSettings()
        local stats = service:getGuildStats()
        view:renderSettings(settings, stats)

        if self._minimapButton and self._minimapButton._button then
            self._minimapButton._button:Show()
            self._minimapButton:updatePosition(215)
        end

        if _G.GM and _G.GM.worldMapView and _G.GM.worldMapView._mapButton then
            _G.GM.worldMapView._mapButton:Show()
        end

        print("|cffffff00[GuildManager]|r Todas as configurações foram restauradas para o padrão.")
        view:showStatus("Configurações restauradas para o padrão!", false)
    end)

    view:setOnPurgeLogsCallback(function()
        local purgedCount = service:purgeOldLogs()
        local settings = service:getSettings()
        local stats = service:getGuildStats()
        view:renderSettings(settings, stats)

        -- Se a tela de logs estiver aberta, recarrega
        if _G.GM and _G.GM.logView and _G.GM.logView.renderLogs then
            if _G.GM.logService and _G.GM.logService.getAllLogs then
                _G.GM.logView:renderLogs(_G.GM.logService:getAllLogs())
            end
        end

        local msg = string.format("Limpeza concluída! %d registro(s) antigo(s) removido(s).", purgedCount)
        print("|cff00ff00[GuildManager]|r " .. msg)
        view:showStatus(msg, false)
    end)

    view:setOnForceScanCallback(function()
        if self._guildRosterService then
            if self._guildRosterService.requestRosterUpdate then
                self._guildRosterService:requestRosterUpdate()
            end
            if self._guildRosterService.scanRoster then
                local count = self._guildRosterService:scanRoster()
                local stats = service:getGuildStats()
                view:renderSettings(service:getSettings(), stats)
                local msg = string.format("Varredura concluída! %d membros atualizados.", count)
                print("|cff00ff00[GuildManager]|r " .. msg)
                view:showStatus(msg, false)
                return
            end
        end
        view:showStatus("Varredura solicitada ao servidor da Blizzard.", false)
    end)
end

--- Registra comandos de barra (slash commands) para abrir as configurações.
function SettingsController:initHooks()
    SLASH_GUILDMANAGER_CONFIG1 = "/gmconfig"
    SLASH_GUILDMANAGER_CONFIG2 = "/gmsettings"
    SLASH_GUILDMANAGER_CONFIG3 = "/gmopcoes"
    SlashCmdList["GUILDMANAGER_CONFIG"] = function()
        self:toggle()
    end
end

function SettingsController:show()
    local settings = self._settingsService:getSettings()
    local stats = self._settingsService:getGuildStats()
    self._settingsView:renderSettings(settings, stats)
    self._settingsView:show()
end

function SettingsController:hide()
    self._settingsView:hide()
end

function SettingsController:toggle()
    if self._settingsView:isShown() then
        self:hide()
    else
        self:show()
    end
end

_G.SettingsController = SettingsController
