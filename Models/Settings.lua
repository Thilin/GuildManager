---@class GMSettings
--- Entidade de domínio para configurações e personalizações do GuildManager.
GMSettings = {}
GMSettings.__index = GMSettings

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

--- Construtor da entidade GMSettings.
---@param data table|nil
---@return GMSettings
function GMSettings:new(data)
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

function GMSettings:getDefaults()
    local copy = {}
    for k, v in pairs(DEFAULTS) do copy[k] = v end
    return copy
end

-- Getters
function GMSettings:getGuildTagline() return self._guildTagline or "" end
function GMSettings:getDefaultTab() return self._defaultTab or "audit" end
function GMSettings:isTimeFormat24() return self._timeFormat24 == true end
function GMSettings:isChatMentionsEnabled() return self._enableChatMentions ~= false end
function GMSettings:isMentionSoundEnabled() return self._enableMentionSound ~= false end
function GMSettings:isMentionFlashEnabled() return self._enableMentionFlash ~= false end
function GMSettings:getMentionSoundChoice() return self._mentionSoundChoice or "whisper" end
function GMSettings:isShowMinimapButton() return self._showMinimapButton ~= false end
function GMSettings:getMinimapPos() return tonumber(self._minimapPos) or 215 end
function GMSettings:isAutoScanRoster() return self._autoScanRoster ~= false end
function GMSettings:isShowOfflineMembers() return self._showOfflineMembers ~= false end
function GMSettings:isNotifyNewRecruit() return self._notifyNewRecruit ~= false end
function GMSettings:isLogLevelUp() return self._logLevelUp ~= false end
function GMSettings:isLogPromoteDemote() return self._logPromoteDemote ~= false end
function GMSettings:isLogNotes() return self._logNotes ~= false end
function GMSettings:isLogJoinLeave() return self._logJoinLeave ~= false end
function GMSettings:getLogRetentionDays() return tonumber(self._logRetentionDays) or 60 end
function GMSettings:isConfirmGroupDelete() return self._confirmGroupDelete ~= false end

-- Setters
function GMSettings:setGuildTagline(val) self._guildTagline = tostring(val or "") end
function GMSettings:setDefaultTab(val) self._defaultTab = tostring(val or "audit") end
function GMSettings:setTimeFormat24(val) self._timeFormat24 = (val == true) end
function GMSettings:setChatMentionsEnabled(val) self._enableChatMentions = (val == true) end
function GMSettings:setMentionSoundEnabled(val) self._enableMentionSound = (val == true) end
function GMSettings:setMentionFlashEnabled(val) self._enableMentionFlash = (val == true) end
function GMSettings:setMentionSoundChoice(val) self._mentionSoundChoice = tostring(val or "whisper") end
function GMSettings:setShowMinimapButton(val) self._showMinimapButton = (val == true) end
function GMSettings:setMinimapPos(val) self._minimapPos = tonumber(val) or 215 end
function GMSettings:setAutoScanRoster(val) self._autoScanRoster = (val == true) end
function GMSettings:setShowOfflineMembers(val) self._showOfflineMembers = (val == true) end
function GMSettings:setNotifyNewRecruit(val) self._notifyNewRecruit = (val == true) end
function GMSettings:setLogLevelUp(val) self._logLevelUp = (val == true) end
function GMSettings:setLogPromoteDemote(val) self._logPromoteDemote = (val == true) end
function GMSettings:setLogNotes(val) self._logNotes = (val == true) end
function GMSettings:setLogJoinLeave(val) self._logJoinLeave = (val == true) end
function GMSettings:setLogRetentionDays(val) self._logRetentionDays = tonumber(val) or 60 end
function GMSettings:setConfirmGroupDelete(val) self._confirmGroupDelete = (val == true) end

--- Serializa as configurações para uma tabela limpa.
---@return table
function GMSettings:serialize()
    local result = {}
    for k in pairs(DEFAULTS) do
        result[k] = self["_" .. k]
    end
    return result
end

_G.GMSettings = GMSettings
if _G.GM then
    _G.GM.Settings = GMSettings
end
