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
    instance._bootDisableWorldMapPins = (settingsService:get("disableWorldMapMemberPins") == true)

    instance:setupCallbacks()

    return instance
end

--- Exibe o diálogo de confirmação para recarregar a UI ao alterar a desativação dos pins no Mapa do Jogo.
---@param curL table
function SettingsController:promptReloadForMapPins(curL)
    local view = self._settingsView
    local pendingMsg = curL["SETTINGS_MAP_PINS_RELOAD_PENDING"] or "Configuração salva! Use /reload ou relogue para aplicar completamente a alteração dos pins no Mapa do Jogo."

    if StaticPopupDialogs and StaticPopup_Show then
        StaticPopupDialogs["GM_CONFIRM_RELOAD_MAP_PINS"] = {
            text = curL["SETTINGS_RELOAD_MAP_PINS_PROMPT"] or "Ativar ou desativar os pins dos membros no Mapa do Jogo requer recarregar a interface (/reload) ou relogar para ligar/desligar completamente o sistema de pins e ganchos do mapa.\n\nDeseja recarregar a interface agora?",
            button1 = curL["RELOAD_UI"] or _G.RELOADUI or "Recarregar UI",
            button2 = curL["SETTINGS_RELOAD_LATER"] or "Depois",
            OnAccept = function()
                if ReloadUI then ReloadUI() end
            end,
            OnCancel = function()
                print("|cffffaa00[GuildManager]|r " .. pendingMsg)
                if view and view.showStatus then
                    view:showStatus(pendingMsg, false)
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("GM_CONFIRM_RELOAD_MAP_PINS")
    else
        print("|cffffaa00[GuildManager]|r " .. pendingMsg)
        if view and view.showStatus then
            view:showStatus(pendingMsg, false)
        end
    end
end

--- Configura os callbacks entre a View e os Serviços.
function SettingsController:setupCallbacks()
    local view = self._settingsView
    local service = self._settingsService

    view:setOnSaveCallback(function(formData, skipReloadPrompt)
        local oldSyncChatLog = service:get("enableSyncChatLog") == true
        local newSyncChatLog = formData and (formData.enableSyncChatLog == true)

        local bootDisableMapPins = (_G.GM and _G.GM.worldMapView and _G.GM.worldMapView.isPinsEnabled)
            and (not _G.GM.worldMapView:isPinsEnabled())
            or (self._bootDisableWorldMapPins == true)
        local newDisableMapPins = formData and (formData.disableWorldMapMemberPins == true)
        local mapPinsReloadNeeded = (newDisableMapPins ~= bootDisableMapPins)

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

        -- Aplica configurações de marcadores do minimapa imediatamente
        if self._minimapButton and self._minimapButton.updatePinSettings then
            self._minimapButton:updatePinSettings(formData.showMinimapPins, formData.clampMinimapPins)
        end

        -- Aplica visibilidade do painel lateral no mapa mundial imediatamente
        if _G.GM and _G.GM.worldMapView then
            if not formData.showWorldMapButton and _G.GM.worldMapView.hidePanel then
                _G.GM.worldMapView:hidePanel()
            end
        end

        -- Pausa/oculta ou restaura os pins no Mapa do Jogo enquanto aguarda /reload
        if _G.GM and _G.GM.worldMapView and _G.GM.worldMapView.setPinsHiddenUntilReload then
            _G.GM.worldMapView:setPinsHiddenUntilReload(newDisableMapPins)
        end

        -- Aplica fixação permanente do chat se configurado
        if _G.GM and _G.GM.chatMentionController and _G.GM.chatMentionController.disableChatFading then
            _G.GM.chatMentionController:disableChatFading(formData.disableChatFading ~= false)
        end

        -- Notifica no chat do jogador
        local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
        local savedMsg = curL["SETTINGS_STATUS_SAVED"] or "Settings saved and applied successfully!"
        print("|cff00ff00[GuildManager]|r " .. savedMsg)
        view:showStatus(savedMsg, false)

        if not skipReloadPrompt and (oldSyncChatLog ~= newSyncChatLog) and StaticPopupDialogs and StaticPopup_Show then
            StaticPopupDialogs["GM_CONFIRM_RELOAD_SYNC_CHAT"] = {
                text = curL["SETTINGS_RELOAD_SYNC_PROMPT"] or "Alterar a exibição de mensagens de sincronização no chat requer o recarregamento da interface (/reload).\n\nDeseja recarregar a interface agora?",
                button1 = curL["RELOAD_UI"] or _G.RELOADUI or "Recarregar UI",
                button2 = curL["CANCEL"] or _G.CANCEL or "Cancelar",
                OnAccept = function()
                    if ReloadUI then ReloadUI() end
                end,
                OnCancel = function()
                    service:set("enableSyncChatLog", oldSyncChatLog)
                    view:renderSettings(service:getSettings(), service:getGuildStats())
                    if mapPinsReloadNeeded then
                        self:promptReloadForMapPins(curL)
                    end
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("GM_CONFIRM_RELOAD_SYNC_CHAT")
        elseif not skipReloadPrompt and mapPinsReloadNeeded then
            self:promptReloadForMapPins(curL)
        end
    end)

    view:setOnResetCallback(function()
        local wasSyncChatLog = service:get("enableSyncChatLog") == true
        local bootDisableMapPins = (_G.GM and _G.GM.worldMapView and _G.GM.worldMapView.isPinsEnabled)
            and (not _G.GM.worldMapView:isPinsEnabled())
            or (self._bootDisableWorldMapPins == true)

        service:resetToDefaults()
        local settings = service:getSettings()
        local stats = service:getGuildStats()
        view:renderSettings(settings, stats)

        if self._minimapButton and self._minimapButton._button then
            self._minimapButton._button:Show()
            self._minimapButton:updatePosition(215)
        end
        if self._minimapButton and self._minimapButton.updatePinSettings then
            self._minimapButton:updatePinSettings(true, false)
        end

        if _G.GM and _G.GM.worldMapView then
            if _G.GM.worldMapView.setPinsHiddenUntilReload then
                _G.GM.worldMapView:setPinsHiddenUntilReload(false)
            end
        end

        if _G.GM and _G.GM.chatMentionController and _G.GM.chatMentionController.disableChatFading then
            _G.GM.chatMentionController:disableChatFading(true)
        end

        local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
        local resetMsg = curL["SETTINGS_STATUS_RESTORED"] or "Settings restored to defaults!"
        print("|cffffff00[GuildManager]|r " .. resetMsg)
        view:showStatus(resetMsg, false)

        if wasSyncChatLog and StaticPopupDialogs and StaticPopup_Show then
            StaticPopupDialogs["GM_CONFIRM_RELOAD_SYNC_CHAT"] = {
                text = curL["SETTINGS_RELOAD_SYNC_PROMPT"] or "Alterar a exibição de mensagens de sincronização no chat requer o recarregamento da interface (/reload).\n\nDeseja recarregar a interface agora?",
                button1 = curL["RELOAD_UI"] or _G.RELOADUI or "Recarregar UI",
                button2 = curL["CANCEL"] or _G.CANCEL or "Cancelar",
                OnAccept = function()
                    if ReloadUI then ReloadUI() end
                end,
                OnCancel = function()
                    service:set("enableSyncChatLog", true)
                    view:renderSettings(service:getSettings(), stats)
                    if bootDisableMapPins then
                        self:promptReloadForMapPins(curL)
                    end
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("GM_CONFIRM_RELOAD_SYNC_CHAT")
        elseif bootDisableMapPins then
            self:promptReloadForMapPins(curL)
        end
    end)

    view:setOnPurgeLogsCallback(function()
        local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
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

        local msg = string.format(curL["SETTINGS_PURGE_SUCCESS_FMT"] or "Limpeza concluída! %d registro(s) antigo(s) removido(s).", purgedCount)
        print("|cff00ff00[GuildManager]|r " .. msg)
        view:showStatus(msg, false)
    end)

    view:setOnForceScanCallback(function()
        local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
        if self._guildRosterService then
            if self._guildRosterService.requestRosterUpdate then
                self._guildRosterService:requestRosterUpdate()
            end
            if self._guildRosterService.scanRoster then
                local count = self._guildRosterService:scanRoster()
                local stats = service:getGuildStats()
                view:renderSettings(service:getSettings(), stats)
                local msg = string.format(curL["SETTINGS_FORCE_SCAN_SUCCESS_FMT"] or "Varredura concluída! %d membros atualizados.", count)
                print("|cff00ff00[GuildManager]|r " .. msg)
                view:showStatus(msg, false)
                return
            end
        end
        view:showStatus(curL["SETTINGS_FORCE_SCAN_REQUESTED"] or "Varredura solicitada ao servidor da Blizzard.", false)
    end)

    view:setOnForceSyncCallback(function()
        local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
        if _G.GM and _G.GM.syncService and _G.GM.syncService.forceSyncAll then
            local count = _G.GM.syncService:forceSyncAll()
            local status = _G.GM.syncService:getStatus()
            local msg = string.format(curL["SETTINGS_FORCE_SYNC_MSG_FMT"] or "Sincronização P2P iniciada! %d membro(s) para %d colega(s) online.", count, status.activePeerCount)
            view:showStatus(msg, false)
        else
            view:showStatus(curL["SETTINGS_FORCE_SYNC_UNAVAILABLE"] or "Serviço de sincronização não disponível.", true)
        end
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
