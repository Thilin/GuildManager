---@alias GroupType
---| "DUNGEON"
---| "RAID"
---| "MISC"

---@alias GroupRole
---| "TANK"
---| "HEALER"
---| "DPS"
---| "NONE"

--- Enum dos tipos de grupos suportados
local RAW_GROUP_TYPES = {
    DUNGEON = "DUNGEON",
    RAID = "RAID",
    MISC = "MISC",
}

--- Enum das funções nos grupos
local RAW_GROUP_ROLES = {
    TANK = "TANK",
    HEALER = "HEALER",
    DPS = "DPS",
    NONE = "NONE",
}

local enumMetaTypes = {
    __index = RAW_GROUP_TYPES,
    __newindex = function(_, k)
        error(string.format("GroupType é imutável. Tentativa de atribuir a '%s'.", tostring(k)), 2)
    end,
}

local enumMetaRoles = {
    __index = RAW_GROUP_ROLES,
    __newindex = function(_, k)
        error(string.format("GroupRole é imutável. Tentativa de atribuir a '%s'.", tostring(k)), 2)
    end,
}

GroupType = setmetatable({}, enumMetaTypes)
GroupRole = setmetatable({}, enumMetaRoles)

---@class GroupMemberData
---@field name string @Nome do personagem
---@field role GroupRole @Função do membro no grupo (TANK, HEALER, DPS, NONE)
---@field class string|nil @Token da classe do personagem (ex: "WARRIOR")
---@field level number|nil @Nível do personagem
---@field addedAt number|nil @Timestamp de adição

---@class Group
---@field private _id string @Identificador único do grupo
---@field private _name string @Nome/Título descritivo do grupo
---@field private _type GroupType @Tipo: DUNGEON, RAID ou MISC
---@field private _leader string @Nome do membro líder do grupo
---@field private _note string @Anotação ou horário do grupo
---@field private _createdAt number @Timestamp de criação
---@field private _members GroupMemberData[] @Lista de membros do grupo
Group = {}
Group.__index = Group

--- Construtor da entidade Group.
---@param data table|nil @Tabela com os atributos iniciais do grupo
---@return Group
function Group:new(data)
    local instance = setmetatable({}, self)
    data = data or {}

    instance._id = data.id or (string.format("grp_%d_%d", time(), math.random(1000, 9999)))
    instance._name = data.name or "Novo Grupo"
    instance._type = data.type or GroupType.DUNGEON
    instance._leader = data.leader or ""
    instance._note = data.note or ""
    instance._createdAt = data.createdAt or time()
    instance._members = {}

    if type(data.members) == "table" then
        for _, m in ipairs(data.members) do
            if type(m) == "table" and m.name and m.name ~= "" then
                table.insert(instance._members, {
                    name = m.name,
                    role = m.role or GroupRole.NONE,
                    class = m.class or "",
                    level = tonumber(m.level) or 1,
                    addedAt = m.addedAt or time(),
                })
            end
        end
    end

    return instance
end

--- Obtém o ID do grupo.
---@return string
function Group:getId()
    return self._id
end

--- Define o ID do grupo.
---@param id string
function Group:setId(id)
    if type(id) == "string" and id ~= "" then
        self._id = id
    end
end

--- Obtém o nome do grupo.
---@return string
function Group:getName()
    return self._name
end

--- Define o nome do grupo.
---@param name string
function Group:setName(name)
    if type(name) == "string" and name ~= "" then
        self._name = name
    end
end

--- Obtém o tipo do grupo (DUNGEON, RAID, MISC).
---@return GroupType
function Group:getType()
    return self._type
end

--- Define o tipo do grupo.
---@param gType GroupType
function Group:setType(gType)
    if RAW_GROUP_TYPES[gType] then
        self._type = gType
    end
end

--- Obtém o nome do líder do grupo.
---@return string
function Group:getLeader()
    return self._leader
end

--- Define o líder do grupo.
---@param leaderName string
function Group:setLeader(leaderName)
    if type(leaderName) == "string" then
        self._leader = leaderName
    end
end

--- Obtém a nota / horário do grupo.
---@return string
function Group:getNote()
    return self._note
end

--- Define a nota / horário do grupo.
---@param note string
function Group:setNote(note)
    self._note = note or ""
end

--- Obtém o timestamp de criação.
---@return number
function Group:getCreatedAt()
    return self._createdAt
end

--- Obtém a lista de membros do grupo.
---@return GroupMemberData[]
function Group:getMembers()
    return self._members
end

--- Verifica se um membro já está no grupo.
---@param name string
---@return boolean
function Group:hasMember(name)
    if not name or name == "" then return false end
    local lower = name:lower()
    for _, m in ipairs(self._members) do
        if m.name:lower() == lower then
            return true
        end
    end
    return false
end

--- Obtém os dados de um membro do grupo pelo nome.
---@param name string
---@return GroupMemberData|nil
function Group:getMember(name)
    if not name or name == "" then return nil end
    local lower = name:lower()
    for _, m in ipairs(self._members) do
        if m.name:lower() == lower then
            return m
        end
    end
    return nil
end

--- Adiciona ou atualiza um membro no grupo.
---@param name string @Nome do personagem
---@param role GroupRole|nil @Função (TANK, HEALER, DPS, NONE)
---@param class string|nil @Token da classe
---@param level number|nil @Nível
---@return boolean @true se adicionado ou atualizado
function Group:addMember(name, role, class, level)
    if not name or name == "" then return false end

    role = role or GroupRole.NONE
    if not RAW_GROUP_ROLES[role] then
        role = GroupRole.NONE
    end

    local existing = self:getMember(name)
    if existing then
        existing.role = role
        if class and class ~= "" then existing.class = class end
        if level and level > 0 then existing.level = level end
        return true
    end

    table.insert(self._members, {
        name = name,
        role = role,
        class = class or "",
        level = tonumber(level) or 1,
        addedAt = time(),
    })
    return true
end

--- Remove um membro do grupo.
---@param name string
---@return boolean, boolean @removido, eraLider
function Group:removeMember(name)
    if not name or name == "" then return false, false end
    local lower = name:lower()
    local wasLeader = (self._leader:lower() == lower)

    for i, m in ipairs(self._members) do
        if m.name:lower() == lower then
            table.remove(self._members, i)
            if wasLeader then
                if #self._members > 0 then
                    self._leader = self._members[1].name
                else
                    self._leader = ""
                end
            end
            return true, wasLeader
        end
    end
    return false, false
end

--- Atualiza a função de um membro no grupo.
---@param name string
---@param role GroupRole
---@return boolean
function Group:setMemberRole(name, role)
    local member = self:getMember(name)
    if not member then return false end

    if RAW_GROUP_ROLES[role] then
        member.role = role
        return true
    end
    return false
end

--- Atualiza o token de classe de um membro no grupo.
---@param name string
---@param class string
---@return boolean
function Group:updateMemberClass(name, class)
    local member = self:getMember(name)
    if not member or not class or class == "" then return false end
    member.class = class
    return true
end

--- Contabiliza membros e quantidades por função.
---@return table @{ total = number, tank = number, healer = number, dps = number, none = number }
function Group:getRoleCounts()
    local counts = { total = #self._members, tank = 0, healer = 0, dps = 0, none = 0 }
    for _, m in ipairs(self._members) do
        if m.role == GroupRole.TANK then
            counts.tank = counts.tank + 1
        elseif m.role == GroupRole.HEALER then
            counts.healer = counts.healer + 1
        elseif m.role == GroupRole.DPS then
            counts.dps = counts.dps + 1
        else
            counts.none = counts.none + 1
        end
    end
    return counts
end

--- Serializa a entidade Group para armazenamento em tabela (GM_DB).
---@return table
function Group:serialize()
    local serializedMembers = {}
    for _, m in ipairs(self._members) do
        table.insert(serializedMembers, {
            name = m.name,
            role = m.role,
            class = m.class,
            level = m.level,
            addedAt = m.addedAt,
        })
    end

    return {
        id = self._id,
        name = self._name,
        type = self._type,
        leader = self._leader,
        note = self._note,
        createdAt = self._createdAt,
        members = serializedMembers,
    }
end

-- Exportação/Alias de compatibilidade
_G.Group = Group
