---@class MemberRepository
---@field private _db table @Referência à tabela raiz do banco de dados persistente (GM_DB)
MemberRepository = {}
MemberRepository.__index = MemberRepository

--- Construtor do repositório de membros.
---@param db table @Tabela raiz do banco de dados persistente (GM_DB)
---@return MemberRepository @Retorna a instância do repositório
function MemberRepository:new(db)
    local instance = setmetatable({}, self)

    instance._db = db or {}
    if type(instance._db.members) ~= "table" then
        instance._db.members = {}
    end

    return instance
end

--- Persiste ou atualiza uma entidade Member no banco de dados.
---@param member Member @Instância da entidade a ser gravada
---@return boolean @Retorna true se a gravação for bem-sucedida
function MemberRepository:save(member)
    if not member or type(member.getName) ~= "function" or type(member.serialize) ~= "function" then
        return false
    end

    local memberName = member:getName()
    if not memberName or memberName == "" then
        return false
    end

    if type(self._db.members) ~= "table" then
        self._db.members = {}
    end

    self._db.members[memberName] = member:serialize()
    return true
end

--- Busca um membro no banco de dados pelo nome.
---@param name string @Nome do membro a buscar
---@return Member|nil @Retorna a entidade Member reconstituída ou nil se não encontrado
function MemberRepository:findByName(name)
    if not name or name == "" or type(self._db.members) ~= "table" then
        return nil
    end

    local rawData = self._db.members[name]
    if rawData then
        return Member:new(rawData)
    end

    return nil
end

--- Busca um membro no banco de dados pelo GUID do personagem.
---@param guid string @Identificador GUID único
---@return Member|nil
function MemberRepository:findByGuid(guid)
    if not guid or guid == "" or type(self._db.members) ~= "table" then
        return nil
    end

    for _, rawData in pairs(self._db.members) do
        if rawData.guid == guid then
            return Member:new(rawData)
        end
    end

    return nil
end

--- Retorna todas as entidades Member armazenadas no banco.
---@return Member[] @Array de instâncias de Member
function MemberRepository:findAll()
    local result = {}
    if type(self._db.members) ~= "table" then
        return result
    end

    for _, rawData in pairs(self._db.members) do
        table.insert(result, Member:new(rawData))
    end

    return result
end

--- Retorna a referência direta da tabela de membros no GM_DB.
---@return table<string, table>
function MemberRepository:getAllRaw()
    if type(self._db.members) ~= "table" then
        self._db.members = {}
    end
    return self._db.members
end

--- Remove um membro do repositório pelo nome.
---@param name string
---@return boolean
function MemberRepository:delete(name)
    if not name or type(self._db.members) ~= "table" or not self._db.members[name] then
        return false
    end

    self._db.members[name] = nil
    return true
end

--- Retorna a contagem total de membros salvos no repositório.
---@return number
function MemberRepository:count()
    if type(self._db.members) ~= "table" then
        return 0
    end

    local total = 0
    for _ in pairs(self._db.members) do
        total = total + 1
    end
    return total
end
