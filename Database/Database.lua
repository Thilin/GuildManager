---@class Database
---@field _version string @Versao corrente do esquema do Banco de dados para controle de migrações
Database = {}
Database.__index = Database

local DEFAULT_DB_VERSION = "1.0"

---@param version string|nil @Versão opcional para o esquema do banco de dados
---@return Database @Retorna uma nova instancia da classe Database
function Database:new(version)

    local instance = setmetatable({}, self)

    instance._version = version or DEFAULT_DB_VERSION

    return instance
end

---@return string @Versão do esquema do banco
function Database:getVersion()
    return self._version
end

---@return table @Retorna a referencia direta à tabela raiz GM_DB
function Database:init()

    if type(_G.GM_DB) ~= "table" then
        _G.GM_DB = {}
    end

    if type(_G.GM_DB.guilds) ~= "table" then
        _G.GM_DB.guilds = {}
    end

    if type(_G.GM_DB.settings) ~= "table" then
        _G.GM_DB.settings = {}
    end

    -- Compatibilidade com esquema raiz legado
    if type(_G.GM_DB.members) ~= "table" then
        _G.GM_DB.members = {}
    end

    if type(_G.GM_DB.logs) ~= "table" then
        _G.GM_DB.logs = {}
    end

    if type(_G.GM_DB.groups) ~= "table" then
        _G.GM_DB.groups = {}
    end

    if type(_G.GM_DB.events) ~= "table" then
        _G.GM_DB.events = {}
    end

    if type(_G.GM_DB.craftOrders) ~= "table" then
        _G.GM_DB.craftOrders = {}
    end

    if type(_G.GM_DB.professions) ~= "table" then
        _G.GM_DB.professions = {}
    end

    if not _G.GM_DB.version then
        _G.GM_DB.version = self._version
    end

    -- Tenta inicializar com a guilda atual do jogador se já estiver disponível
    local guildKey = self:getGuildKey()
    if guildKey then
        return self:switchGuild(nil)
    end

    -- Se a guilda ainda não é conhecida no ADDON_LOADED, inicializa com banco isolado
    -- para impedir vazamento de membros legados globais antes da confirmação da guilda
    self._activeDb = {
        members = {},
        logs = {},
        groups = {},
        events = {},
        craftOrders = {},
        professions = {},
        rosterInitialized = false,
    }
    return self._activeDb
end

--- Retorna a chave única da guilda no formato "Realm - NomeDaGuilda"
---@param guildName string|nil
---@param realmName string|nil
---@return string|nil
function Database:getGuildKey(guildName, realmName)
    local gName = guildName
    if not gName or gName == "" then
        if GetGuildInfo then
            local ok, info = pcall(GetGuildInfo, "player")
            if ok and info and info ~= "" then
                gName = info
            end
        end
    end

    if not gName or gName == "" then
        return nil
    end

    local rName = realmName or (GetRealmName and GetRealmName()) or ""
    if rName ~= "" then
        return rName .. " - " .. gName
    end
    return gName
end

--- Retorna a tabela isolada de dados persistentes da guilda especificada
---@param guildKey string
---@return table|nil
function Database:getGuildData(guildKey)
    if not guildKey or guildKey == "" then return nil end
    if type(_G.GM_DB.guilds) ~= "table" then
        _G.GM_DB.guilds = {}
    end

    if type(_G.GM_DB.guilds[guildKey]) ~= "table" then
        _G.GM_DB.guilds[guildKey] = {
            members = {},
            logs = {},
            groups = {},
            events = {},
            craftOrders = {},
            professions = {},
            rosterInitialized = false,
        }
    else
        local g = _G.GM_DB.guilds[guildKey]
        if type(g.members) ~= "table" then g.members = {} end
        if type(g.logs) ~= "table" then g.logs = {} end
        if type(g.groups) ~= "table" then g.groups = {} end
        if type(g.events) ~= "table" then g.events = {} end
        if type(g.craftOrders) ~= "table" then g.craftOrders = {} end
        if type(g.professions) ~= "table" then g.professions = {} end
    end

    return _G.GM_DB.guilds[guildKey]
end

--- Alterna a guilda ativa, retornando o banco de dados correspondente
---@param guildName string|nil
---@param realmName string|nil
---@return table|nil @Tabela da guilda ou nil se sem guilda
---@return string|nil @Chave da guilda
function Database:switchGuild(guildName, realmName)
    local key = self:getGuildKey(guildName, realmName)
    self._currentGuildKey = key
    if key then
        local guildDb = self:getGuildData(key)
        self._activeDb = guildDb
        return guildDb, key
    else
        self._activeDb = nil
        return nil, nil
    end
end

--- Retorna o banco ativo (ou a raiz se nenhuma guilda estiver vinculada ainda)
---@return table
function Database:getActiveDatabase()
    return self._activeDb or {
        members = {},
        logs = {},
        groups = {},
        events = {},
        craftOrders = {},
        professions = {},
        rosterInitialized = false,
    }
end

--- Retorna a chave da guilda atualmente ativa
---@return string|nil
function Database:getCurrentGuildKey()
    return self._currentGuildKey
end

--- Migra dados customizados (notas internas, aniversários, recrutadores, alts) do banco legado para o banco particionado da guilda
--- Apenas membros confirmados no roster da guilda ativa são migrados.
---@param guildDb table
---@param activeMemberNames table<string, boolean>
function Database:migrateLegacyCustomData(guildDb, activeMemberNames)
    if not guildDb or type(guildDb.members) ~= "table" then return end
    if not _G.GM_DB or type(_G.GM_DB.members) ~= "table" then return end
    if not activeMemberNames then return end

    for name, rawMember in pairs(_G.GM_DB.members) do
        local lower = name:lower():match("^%s*(.-)%s*$")
        if lower and activeMemberNames[lower] then
            local target = guildDb.members[name]
            if target then
                if (not target.birthday or target.birthday == "") and rawMember.birthday and rawMember.birthday ~= "" then
                    target.birthday = rawMember.birthday
                end
                if (not target.customNote or target.customNote == "") and rawMember.customNote and rawMember.customNote ~= "" then
                    target.customNote = rawMember.customNote
                end
                if (not target.recruiter or target.recruiter == "") and rawMember.recruiter and rawMember.recruiter ~= "" then
                    target.recruiter = rawMember.recruiter
                end
                if (not target.alts or #target.alts == 0) and rawMember.alts and #rawMember.alts > 0 then
                    target.alts = rawMember.alts
                end
            end
        end
    end
end

---@return void
function Database:wipe()
    if _G.GM_DB then
        table.wipe(_G.GM_DB)
        self:init()
    end
end