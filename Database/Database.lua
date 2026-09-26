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

    if type(_G.GM_DB.members) ~= "table" then
        _G.GM_DB.members = {}
    end

    if type(_G.GM_DB.settings) ~= "table" then
        _G.GM_DB.settings = {}
    end

    if type(_G.GM_DB.logs) ~= "table" then
        _G.GM_DB.logs = {}
    end

    if not _G.GM_DB.version then
        _G.GM_DB.version = self._version
    end

    return _G.GM_DB
end

---@return void
function Database:wipe()
    if _G.GM_DB then
        table.wipe(_G.GM_DB)
        self:init()
    end
end