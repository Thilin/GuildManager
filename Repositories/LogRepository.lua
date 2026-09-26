---@class LogRepository
---@field private _db table @Referência à tabela raiz do banco de dados persistente (GM_DB)
LogRepository = {}
LogRepository.__index = LogRepository

--- Construtor do repositório de logs.
---@param db table @Tabela raiz do banco de dados persistente (GM_DB)
---@return LogRepository
function LogRepository:new(db)
    local instance = setmetatable({}, self)

    instance._db = db or {}
    if type(instance._db.logs) ~= "table" then
        instance._db.logs = {}
    end

    return instance
end

--- Salva ou atualiza uma entidade Log no banco de dados.
---@param log Log @Instância da entidade Log a ser persistida
---@return boolean @Retorna true se salvo com sucesso
function LogRepository:save(log)
    if not log or type(log.serialize) ~= "function" then
        return false
    end

    if type(self._db.logs) ~= "table" then
        self._db.logs = {}
    end

    local logId = log:getId()
    if logId and self._db.logs[logId] then
        -- Atualiza log existente
        local serialized = log:serialize()
        serialized.id = logId
        self._db.logs[logId] = serialized
        return true
    end

    -- Cria um novo registro
    local serialized = log:serialize()
    table.insert(self._db.logs, serialized)
    local newId = #self._db.logs
    serialized.id = newId
    log:setId(newId)

    return true
end

--- Retorna todas as entidades Log salvas no banco de dados.
---@return Log[]
function LogRepository:findAll()
    local result = {}
    if type(self._db.logs) ~= "table" then
        return result
    end

    for idx, rawData in ipairs(self._db.logs) do
        rawData.id = rawData.id or idx
        table.insert(result, Log:new(rawData))
    end

    return result
end

--- Busca todos os logs associados a um determinado personagem.
---@param name string @Nome do personagem
---@return Log[]
function LogRepository:findByName(name)
    local result = {}
    if not name or name == "" or type(self._db.logs) ~= "table" then
        return result
    end

    local lowerName = name:lower()
    for idx, rawData in ipairs(self._db.logs) do
        if rawData.name and rawData.name:lower() == lowerName then
            rawData.id = rawData.id or idx
            table.insert(result, Log:new(rawData))
        end
    end

    return result
end

--- Busca o registro de evento JOINED de um determinado personagem (por nome ou GUID).
---@param name string @Nome do personagem
---@param guid string|nil @GUID do personagem (opcional)
---@return Log|nil, number|nil @Retorna a entidade Log (se encontrada) e o índice no banco
function LogRepository:findJoinedLog(name, guid)
    if type(self._db.logs) ~= "table" then
        return nil, nil
    end

    local lowerName = (name and name ~= "") and name:lower() or nil
    for idx, rawData in ipairs(self._db.logs) do
        if rawData.event == LogEvent.JOINED then
            local matchName = lowerName and rawData.name and rawData.name:lower() == lowerName
            local matchGuid = guid and guid ~= "" and rawData.guid and rawData.guid == guid
            if matchName or matchGuid then
                rawData.id = rawData.id or idx
                return Log:new(rawData), idx
            end
        end
    end

    return nil, nil
end

--- Retorna a quantidade total de logs registrados.
---@return number
function LogRepository:count()
    if type(self._db.logs) ~= "table" then
        return 0
    end
    return #self._db.logs
end

--- Retorna a referência direta à tabela bruta de logs no GM_DB.
---@return table
function LogRepository:getAllRaw()
    if type(self._db.logs) ~= "table" then
        self._db.logs = {}
    end
    return self._db.logs
end

--- Limpa todos os logs do repositório.
function LogRepository:wipe()
    if self._db and type(self._db.logs) == "table" then
        table.wipe(self._db.logs)
    end
end
