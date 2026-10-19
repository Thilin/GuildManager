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
    instance._cache = {}

    return instance
end

--- Limpa o cache de instâncias em memória.
function MemberRepository:clearCache()
    self._cache = {}
end

--- Atualiza a referência de banco de dados do repositório (ex: na troca de guilda ou personagem).
---@param db table
function MemberRepository:setDatabase(db)
    self._db = db or {}
    if type(self._db.members) ~= "table" then
        self._db.members = {}
    end
    self:clearCache()
end

--- Reseta o status de isOnline em memória de todos os membros do banco ativo.
--- Garante que dados de sessões passadas salvos em disco não sejam interpretados falsamente como online.
function MemberRepository:resetOnlineStatus()
    self:clearCache()
    if type(self._db.members) == "table" then
        for _, raw in pairs(self._db.members) do
            if raw and raw.isOnline then
                raw.isOnline = false
            end
        end
    end
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

    -- Se o nome foi atualizado (ex: adicionado sobrenome), limpa chave legada sem sobrenome com mesmo GUID
    local guid = member.getGuid and member:getGuid()
    if guid and guid ~= "" and memberName:find("%s") then
        local first = memberName:match("^(%S+)")
        if first and self._db.members[first] then
            local oldRaw = self._db.members[first]
            if oldRaw and (oldRaw.guid == guid or oldRaw.name == first) then
                self._db.members[first] = nil
                if self._cache then self._cache[first] = nil end
            end
        end
    end

    self._db.members[memberName] = member:serialize()
    self._cache[memberName] = member
    return true
end

--- Busca um membro no banco de dados pelo nome.
---@param name string @Nome do membro a buscar
---@return Member|nil @Retorna a entidade Member reconstituída ou nil se não encontrado
function MemberRepository:findByName(name)
    if not name or name == "" or type(self._db.members) ~= "table" then
        return nil
    end

    local cached = self._cache[name]
    if cached then
        return cached
    end

    local rawData = self._db.members[name]
    if rawData then
        local member = Member:new(rawData)
        self._cache[name] = member
        return member
    end

    -- Fallback case-insensitive se a chave exata não foi encontrada
    local clean = name:match("^[^-]+") or name
    clean = clean:match("^%s*(.-)%s*$") or clean
    local cleanLower = clean:lower()
    for mName, raw in pairs(self._db.members) do
        local mClean = mName:match("^[^-]+") or mName
        mClean = mClean:match("^%s*(.-)%s*$") or mClean
        if mClean:lower() == cleanLower then
            local member = self._cache[mName] or Member:new(raw)
            self._cache[mName] = member
            return member
        end
        -- Permite encontrar "Nome Sobrenome" mesmo se pesquisado apenas pelo primeiro nome
        if mClean:find("%s") then
            local first = mClean:match("^(%S+)") or mClean
            if first:lower() == cleanLower then
                local member = self._cache[mName] or Member:new(raw)
                self._cache[mName] = member
                return member
            end
        end
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

    for name, cached in pairs(self._cache) do
        if cached.getGuid and cached:getGuid() == guid then
            return cached
        end
    end

    for name, rawData in pairs(self._db.members) do
        if rawData.guid == guid then
            local member = self._cache[name] or Member:new(rawData)
            self._cache[name] = member
            return member
        end
    end

    return nil
end

--- Retorna todas as entidades Member armazenadas no banco reaproveitando instâncias em cache.
---@return Member[] @Array de instâncias de Member
function MemberRepository:findAll()
    local result = {}
    if type(self._db.members) ~= "table" then
        return result
    end

    for name, rawData in pairs(self._db.members) do
        local member = self._cache[name]
        if not member then
            member = Member:new(rawData)
            self._cache[name] = member
        end
        table.insert(result, member)
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
    if self._cache then
        self._cache[name] = nil
    end
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
