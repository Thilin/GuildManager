---@class GroupRepository
---@field private _db table @Referência à tabela raiz do banco de dados persistente (GM_DB)
GroupRepository = {}
GroupRepository.__index = GroupRepository

--- Construtor do repositório de grupos.
---@param db table @Tabela raiz do banco de dados persistente (GM_DB)
---@return GroupRepository
function GroupRepository:new(db)
    local instance = setmetatable({}, self)

    instance._db = db or {}
    if type(instance._db.groups) ~= "table" then
        instance._db.groups = {}
    end

    return instance
end

--- Persiste ou atualiza uma entidade Group no banco de dados.
---@param group Group @Instância da entidade a ser gravada
---@return boolean @true se a gravação for bem-sucedida
function GroupRepository:save(group)
    if not group or type(group.getId) ~= "function" or type(group.serialize) ~= "function" then
        return false
    end

    local id = group:getId()
    if not id or id == "" then
        return false
    end

    if type(self._db.groups) ~= "table" then
        self._db.groups = {}
    end

    self._db.groups[id] = group:serialize()
    return true
end

--- Deleta um grupo do banco de dados pelo ID.
---@param id string @Identificador do grupo
---@return boolean @true se o grupo foi removido
function GroupRepository:delete(id)
    if not id or id == "" or type(self._db.groups) ~= "table" then
        return false
    end

    if self._db.groups[id] then
        self._db.groups[id] = nil
        return true
    end
    return false
end

--- Busca um grupo no banco de dados pelo ID.
---@param id string
---@return Group|nil
function GroupRepository:findById(id)
    if not id or id == "" or type(self._db.groups) ~= "table" then
        return nil
    end

    local raw = self._db.groups[id]
    if raw then
        return Group:new(raw)
    end
    return nil
end

--- Retorna todos os grupos cadastrados.
---@return Group[]
function GroupRepository:findAll()
    local result = {}
    if type(self._db.groups) ~= "table" then
        return result
    end

    for _, raw in pairs(self._db.groups) do
        table.insert(result, Group:new(raw))
    end

    -- Ordena por data de criação decrescente
    table.sort(result, function(a, b)
        return (a:getCreatedAt() or 0) > (b:getCreatedAt() or 0)
    end)

    return result
end

--- Retorna grupos filtrados por tipo (DUNGEON, RAID, MISC).
---@param groupType GroupType
---@return Group[]
function GroupRepository:findByType(groupType)
    local result = {}
    if type(self._db.groups) ~= "table" then
        return result
    end

    for _, raw in pairs(self._db.groups) do
        if raw.type == groupType then
            table.insert(result, Group:new(raw))
        end
    end

    table.sort(result, function(a, b)
        return (a:getCreatedAt() or 0) > (b:getCreatedAt() or 0)
    end)

    return result
end

--- Retorna a quantidade total de grupos cadastrados.
---@return number
function GroupRepository:count()
    local count = 0
    if type(self._db.groups) == "table" then
        for _ in pairs(self._db.groups) do
            count = count + 1
        end
    end
    return count
end

--- Limpa todos os grupos do banco de dados.
function GroupRepository:wipe()
    if self._db then
        self._db.groups = {}
    end
end

-- Exportação/Alias de compatibilidade
_G.GroupRepository = GroupRepository
