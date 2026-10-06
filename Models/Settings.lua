---@class Settings
--- Entidade de domínio para configurações e personalizações do GuildManager.
Settings = {}
Settings.__index = Settings

local DEFAULTS = {
    guildTagline = "",           -- Mensagem ou lema customizado da guilda
    defaultTab = "audit",        -- Aba inicial padrão: "audit", "logs", "groups", "settings"
    timeFormat24 = true,         -- true = 24 Horas (ex: 20:30), false = 12 Horas AM/PM
    enableChatMentions = true,   -- Autocomplete e realce de menções com @ no chat
    enableMentionSound = true,   -- Tocar alerta sonoro ao ser mencionado
    enableMentionFlash = true,   -- Piscar a aba de chat ao receber menção
    mentionSoundChoice = "whisper", -- "whisper", "raid", "ready", "coin"
    showMinimapButton = true,    -- Exibir ícone do GuildManager no minimapa
    minimapPos = 215,            -- Ângulo de posição no minimapa
    autoScanRoster = true,       -- Varredura automática do roster ao conectar e em eventos
    showOfflineMembers = true,   -- Exibir membros desconectados na auditoria
    notifyNewRecruit = true,     -- Notificar no chat local ao identificar novo membro
    logLevelUp = true,           -- Registrar logs de aumento de nível
    logPromoteDemote = true,     -- Registrar logs de promoção e rebaixamento
    logNotes = true,             -- Registrar logs de alteração de notas públicas e de oficial
    logJoinLeave = true,         -- Registrar logs de entrada, saída e expulsão
    logRetentionDays = 60,       -- Dias de retenção de histórico (0 = ilimitado, 30, 60, 90, 180)
    confirmGroupDelete = true,   -- Solicitar confirmação ao excluir grupos
}

--- Construtor da entidade Settings.
---@param data table|nil
---@return Settings
function Settings:new(data)
    local instance = setmetatable({}, self)
    data = data or {}

    for k, defaultVal in pairs(DEFAULTS) do
        if data[k] ~= nil then
            instance["_" .. k] = data[k]
        else
            instance["_" .. k] = defaultVal
        end
    end

    return instance
end

function Settings:getDefaults()
    local copy = {}
    for k, v in pairs(DEFAULTS) do copy[k] = v end
    return copy
end

-- Getters
function Settings:getGuildTagline() return self._guildTagline or "" end
function Settings:getDefaultTab() return self._defaultTab or "audit" end
function Settings:isTimeFormat24() return self._timeFormat24 == true end
function Settings:isChatMentionsEnabled() return self._enableChatMentions ~= false end
function Settings:isMentionSoundEnabled() return self._enableMentionSound ~= false end
function Settings:isMentionFlashEnabled() return self._enableMentionFlash ~= false end
function Settings:getMentionSoundChoice() return self._mentionSoundChoice or "whisper" end
function Settings:isShowMinimapButton() return self._showMinimapButton ~= false end
function Settings:getMinimapPos() return tonumber(self._minimapPos) or 215 end
function Settings:isAutoScanRoster() return self._autoScanRoster ~= false end
function Settings:isShowOfflineMembers() return self._showOfflineMembers ~= false end
function Settings:isNotifyNewRecruit() return self._notifyNewRecruit ~= false end
function Settings:isLogLevelUp() return self._logLevelUp ~= false end
function Settings:isLogPromoteDemote() return self._logPromoteDemote ~= false end
function Settings:isLogNotes() return self._logNotes ~= false end
function Settings:isLogJoinLeave() return self._logJoinLeave ~= false end
function Settings:getLogRetentionDays() return tonumber(self._logRetentionDays) or 60 end
function Settings:isConfirmGroupDelete() return self._confirmGroupDelete ~= false end

-- Setters
function Settings:setGuildTagline(val) self._guildTagline = tostring(val or "") end
function Settings:setDefaultTab(val) self._defaultTab = tostring(val or "audit") end
function Settings:setTimeFormat24(val) self._timeFormat24 = (val == true) end
function Settings:setChatMentionsEnabled(val) self._enableChatMentions = (val == true) end
function Settings:setMentionSoundEnabled(val) self._enableMentionSound = (val == true) end
function Settings:setMentionFlashEnabled(val) self._enableMentionFlash = (val == true) end
function Settings:setMentionSoundChoice(val) self._mentionSoundChoice = tostring(val or "whisper") end
function Settings:setShowMinimapButton(val) self._showMinimapButton = (val == true) end
function Settings:setMinimapPos(val) self._minimapPos = tonumber(val) or 215 end
function Settings:setAutoScanRoster(val) self._autoScanRoster = (val == true) end
function Settings:setShowOfflineMembers(val) self._showOfflineMembers = (val == true) end
function Settings:setNotifyNewRecruit(val) self._notifyNewRecruit = (val == true) end
function Settings:setLogLevelUp(val) self._logLevelUp = (val == true) end
function Settings:setLogPromoteDemote(val) self._logPromoteDemote = (val == true) end
function Settings:setLogNotes(val) self._logNotes = (val == true) end
function Settings:setLogJoinLeave(val) self._logJoinLeave = (val == true) end
function Settings:setLogRetentionDays(val) self._logRetentionDays = tonumber(val) or 60 end
function Settings:setConfirmGroupDelete(val) self._confirmGroupDelete = (val == true) end

--- Serializa as configurações para uma tabela limpa.
---@return table
function Settings:serialize()
    local result = {}
    for k in pairs(DEFAULTS) do
        result[k] = self["_" .. k]
    end
    return result
end

_G.Settings = Settings
