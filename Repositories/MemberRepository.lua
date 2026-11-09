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
    instance._guidCache = {}
    instance._lowerCache = {}
    instance._firstNameCache = {}
    instance._allListCache = nil

    return instance
end

--- Limpa o cache de instâncias em memória.
function MemberRepository:clearCache()
    self._cache = {}
    self._guidCache = {}
    self._lowerCache = {}
    self._firstNameCache = {}
    self._allListCache = nil
end

--- Registra uma instância Member nos índices secundários em memória para busca O(1).
---@param member Member
function MemberRepository:_indexMember(member)
    if not member or type(member.getName) ~= "function" then return end
    local mName = member:getName()
    if not mName or mName == "" then return end

    if not self._cache[mName] and self._allListCache then
        table.insert(self._allListCache, member)
    end
    self._cache[mName] = member

    local guid = member.getGuid and member:getGuid()
    if guid and guid ~= "" then
        self._guidCache[guid] = member
    end

    local mClean = mName:match("^[^-]+") or mName
    mClean = mClean:match("^%s*(.-)%s*$") or mClean
    local mLower = mClean:lower()
    if mLower ~= "" then
        self._lowerCache[mLower] = member
        if mClean:find("%s") then
            local first = (mClean:match("^(%S+)") or mClean):lower()
            local existing = self._firstNameCache[first]
            if existing == nil or existing == member then
                self._firstNameCache[first] = member
            else
                -- Mais de um membro com o mesmo primeiro nome: marca como ambíguo
                self._firstNameCache[first] = false
            end
        end
    end
end

--- Atualiza em-loco a tabela persistida no GM_DB sem alocar uma nova tabela a cada save.
---@param target table
---@param member Member
local function serializeIntoTable(target, member)
    target.name = member._name
    target.race = member:getRace()
    target.raceID = member._raceID
    target.rankName = member._rankName
    target.rankIndex = member._rankIndex
    target.level = member._level
    target.classDisplayName = member._classDisplayName
    target.zone = member._zone
    target.publicNote = member._publicNote
    target.officerNote = member._officerNote
    target.isOnline = member._isOnline
    target.lastOnline = member._lastOnline
    target.status = member._status
    target.class = member._class
    target.achievementPoints = member._achievementPoints
    target.achievementRank = member._achievementRank
    target.guid = member._guid
    target.customNote = member._customNote
    target.alts = member._alts
    target.birthday = member._birthday
    target.dateJoin = member._dateJoin
    target.dateLeft = member._dateLeft
    target.lastRank = member._lastRank
    target.timesLeft = member._timesLeft
    target.isMain = member._isMain
    target.isInGuild = member._isInGuild
    target.recruiter = member._recruiter
    target.role = member:getRole()
    target.rolePendingLeaderConfirm = (member._rolePendingLeaderConfirm == true)
    target.customDataTimestamp = member._customDataTimestamp or 0
    target.professions = member._professions or {}
    target.professionsTimestamp = member._professionsTimestamp or 0
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
                if self._lowerCache then self._lowerCache[first:lower()] = nil end
                self._allListCache = nil
            end
        end
    end

    local existingRaw = self._db.members[memberName]
    if type(existingRaw) == "table" then
        serializeIntoTable(existingRaw, member)
    else
        self._db.members[memberName] = member:serialize()
    end

    self:_indexMember(member)
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
        self:_indexMember(member)
        return member
    end

    -- Hidrata todos os índices secundários em uma única passagem se ainda não estiverem prontos
    if not self._allListCache then
        self:findAll()
    end

    local clean = name:match("^[^-]+") or name
    clean = clean:match("^%s*(.-)%s*$") or clean
    local cleanLower = clean:lower()

    local byLower = self._lowerCache[cleanLower]
    if byLower then
        return byLower
    end

    local byFirst = self._firstNameCache[cleanLower]
    if byFirst then
        return byFirst
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

    local byGuid = self._guidCache[guid]
    if byGuid then
        return byGuid
    end

    if not self._allListCache then
        self:findAll()
    end

    return self._guidCache[guid]
end

--- Retorna todas as entidades Member armazenadas no banco reaproveitando instâncias em cache.
---@return Member[] @Array de instâncias de Member
function MemberRepository:findAll()
    if self._allListCache then
        return self._allListCache
    end

    local result = {}
    if type(self._db.members) ~= "table" then
        return result
    end

    for name, rawData in pairs(self._db.members) do
        local member = self._cache[name]
        if not member then
            member = Member:new(rawData)
        end
        self:_indexMember(member)
        table.insert(result, member)
    end

    self._allListCache = result
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

    local oldMember = self._cache and self._cache[name]
    self._db.members[name] = nil
    if self._cache then
        self._cache[name] = nil
    end
    if self._lowerCache then
        self._lowerCache[name:lower()] = nil
    end
    if oldMember then
        local guid = oldMember.getGuid and oldMember:getGuid()
        if guid and self._guidCache and self._guidCache[guid] == oldMember then
            self._guidCache[guid] = nil
        end
        local first = name:match("^(%S+)")
        if first and self._firstNameCache and self._firstNameCache[first:lower()] == oldMember then
            self._firstNameCache[first:lower()] = nil
        end
    end
    self._allListCache = nil
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
