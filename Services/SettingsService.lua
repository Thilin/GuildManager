---@class SettingsService
---@field private _db table
---@field private _settings Settings
---@field private _logRepository LogRepository|nil
---@field private _memberService MemberService|nil
---@field private _guildRosterService GuildRosterService|nil
---@field private _listeners function[]
SettingsService = {}
SettingsService.__index = SettingsService

--- Construtor do serviço de configurações.
---@param db table @Tabela raiz GM_DB
---@param logRepository LogRepository|nil
---@param memberService MemberService|nil
---@param guildRosterService GuildRosterService|nil
---@return SettingsService
function SettingsService:new(db, logRepository, memberService, guildRosterService)
    local instance = setmetatable({}, self)

    instance._db = db or {}
    if type(instance._db.settings) ~= "table" then
        instance._db.settings = {}
    end

    instance._logRepository = logRepository
    instance._memberService = memberService
    instance._guildRosterService = guildRosterService
    instance._listeners = {}

    -- Carrega entidade Settings mesclando com os dados persistidos
    instance._settings = Settings:new(instance._db.settings)
    -- Garante sincronismo inicial dos dados
    instance:save()

    return instance
end

--- Retorna a entidade de configurações em memória.
---@return Settings
function SettingsService:getSettings()
    return self._settings
end

--- Obtém o valor de uma configuração pelo identificador.
---@param key string
---@param defaultVal any|nil
---@return any
function SettingsService:get(key, defaultVal)
    local getter = self._settings["get" .. key:sub(1, 1):upper() .. key:sub(2)]
    if type(getter) == "function" then
        return getter(self._settings)
    end
    local isGetter = self._settings["is" .. key:sub(1, 1):upper() .. key:sub(2)]
    if type(isGetter) == "function" then
        return isGetter(self._settings)
    end
    if self._settings["_" .. key] ~= nil then
        return self._settings["_" .. key]
    end
    return defaultVal
end

--- Define o valor de uma configuração e persiste.
---@param key string
---@param val any
function SettingsService:set(key, val)
    local setter = self._settings["set" .. key:sub(1, 1):upper() .. key:sub(2)]
    if type(setter) == "function" then
        setter(self._settings, val)
    else
        self._settings["_" .. key] = val
    end
    self:save()
    self:notifyListeners(key, val)
end

--- Salva a entidade de configurações na tabela GM_DB.settings.
function SettingsService:save()
    if self._db and self._settings then
        self._db.settings = self._settings:serialize()
    end
end

--- Restaura todas as configurações para os valores de fábrica.
function SettingsService:resetToDefaults()
    local defaults = self._settings:getDefaults()
    self._settings = Settings:new(defaults)
    self:save()
    self:notifyListeners("*", nil)
end

--- Registra um listener que é acionado quando uma configuração muda.
---@param callback function(key: string, val: any)
function SettingsService:registerListener(callback)
    if type(callback) == "function" then
        table.insert(self._listeners, callback)
    end
end

--- Notifica todos os listeners registrados.
---@param key string
---@param val any
function SettingsService:notifyListeners(key, val)
    for _, cb in ipairs(self._listeners) do
        pcall(cb, key, val, self._settings)
    end
end

--- Executa limpeza de logs antigos com base na retenção configurada.
---@return number @Quantidade de registros removidos
function SettingsService:purgeOldLogs()
    if not self._logRepository or not self._logRepository.purgeOlderThan then
        return 0
    end

    local days = self._settings:getLogRetentionDays()
    if days <= 0 then
        -- 0 = Ilimitado (não apaga nada)
        return 0
    end

    local cutoff = time() - (days * 86400)
    return self._logRepository:purgeOlderThan(cutoff)
end

--- Retorna estatísticas gerais da guilda e do Addon para exibição informativa.
---@return table @{ guildName, totalMembers, totalGroups, totalLogs, version }
function SettingsService:getGuildStats()
    local gName = "Guilda"
    if GetGuildInfo then
        local name = GetGuildInfo("player")
        if name and name ~= "" then gName = name end
    end

    local totalMembers = 0
    if self._memberService and self._memberService.getAllMembers then
        local mList = self._memberService:getAllMembers()
        totalMembers = mList and #mList or 0
    elseif self._db and type(self._db.members) == "table" then
        for _ in pairs(self._db.members) do totalMembers = totalMembers + 1 end
    end

    local totalGroups = 0
    if self._db and type(self._db.groups) == "table" then
        for _ in pairs(self._db.groups) do totalGroups = totalGroups + 1 end
    end

    local totalLogs = 0
    if self._logRepository and self._logRepository.count then
        totalLogs = self._logRepository:count()
    elseif self._db and type(self._db.logs) == "table" then
        totalLogs = #self._db.logs
    end

    return {
        guildName = gName,
        totalMembers = totalMembers,
        totalGroups = totalGroups,
        totalLogs = totalLogs,
        version = (self._db and self._db.version) or "1.0",
    }
end

_G.SettingsService = SettingsService
