---@alias GroupType
---| "DUNGEON"
---| "RAID"
---| "MISC"
---| "FARM"
---| "QUESTS"
---| "PVP"

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
    FARM = "FARM",
    QUESTS = "QUESTS",
    PVP = "PVP",
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
---@field private _type GroupType @Tipo: DUNGEON, RAID, MISC, FARM, QUESTS, PVP
---@field private _leader string @Nome do membro líder do grupo
---@field private _creator string @Nome do criador do grupo (nome e sobrenome)
---@field private _time string @Horário previsto do grupo
---@field private _description string @Descrição detalhada do grupo
---@field private _note string @Anotação legada / compatibilidade
---@field private _createdAt number @Timestamp de criação
---@field private _updatedAt number @Timestamp da última alteração
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
    instance._creator = data.creator or instance._leader or ""
    instance._time = data.time or data.note or ""
    instance._description = data.description or ""
    instance._note = data.note or instance._time or ""
    instance._createdAt = tonumber(data.createdAt) or time()
    instance._updatedAt = tonumber(data.updatedAt) or instance._createdAt or time()
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

function Group:getId() return self._id end
function Group:setId(id) if type(id) == "string" and id ~= "" then self._id = id end end

function Group:getName() return self._name end
function Group:setName(name) if type(name) == "string" and name ~= "" then self._name = name end end

function Group:getType() return self._type end
function Group:setType(gType)
    if RAW_GROUP_TYPES[gType] then
        self._type = gType
    end
end

function Group:getLeader() return self._leader end
function Group:setLeader(leaderName)
    if type(leaderName) == "string" then
        self._leader = leaderName
    end
end

function Group:getCreator()
    if self._creator and self._creator ~= "" then
        return self._creator
    end
    return self._leader or ""
end

function Group:setCreator(creatorName)
    if type(creatorName) == "string" then
        self._creator = creatorName
        self._updatedAt = time()
    end
end

function Group:getTime()
    if self._time and self._time ~= "" then
        return self._time
    end
    return self._note or ""
end

function Group:setTime(timeStr)
    self._time = timeStr or ""
    self._note = self._time
    self._updatedAt = time()
end

function Group:getDescription() return self._description or "" end
function Group:setDescription(desc)
    self._description = desc or ""
    self._updatedAt = time()
end

function Group:getNote() return self:getTime() end
function Group:setNote(note)
    self._note = note or ""
    self._time = note or ""
    self._updatedAt = time()
end

function Group:getCreatedAt() return self._createdAt end
function Group:getUpdatedAt() return self._updatedAt or self._createdAt or time() end
function Group:setUpdatedAt(ts) self._updatedAt = tonumber(ts) or time() end

function Group:getMembers() return self._members end

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

function Group:setMemberRole(name, role)
    local member = self:getMember(name)
    if not member then return false end

    if RAW_GROUP_ROLES[role] then
        member.role = role
        return true
    end
    return false
end

function Group:updateMemberClass(name, class)
    local member = self:getMember(name)
    if not member or not class or class == "" then return false end
    member.class = class
    return true
end

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

function Group:isCreator(playerName)
    if not playerName or playerName == "" then
        return false
    end
    local creator = self:getCreator()
    if not creator or creator == "" then
        return false
    end

    local function normalize(n)
        local c = (n:match("^[^-]+") or n):match("^%s*(.-)%s*$")
        return c:lower()
    end

    local pNorm = normalize(playerName)
    local cNorm = normalize(creator)

    if pNorm == cNorm then return true end

    local pFirst = pNorm:match("^(%S+)") or pNorm
    local cFirst = cNorm:match("^(%S+)") or cNorm
    if pFirst == cFirst then return true end

    if _G.GM and _G.GM.memberService and _G.GM.memberService.resolveFullName then
        local pResolved = normalize(_G.GM.memberService:resolveFullName(playerName) or "")
        local cResolved = normalize(_G.GM.memberService:resolveFullName(creator) or "")
        if pResolved ~= "" and (pResolved == cNorm or pResolved == cResolved) then return true end
        if cResolved ~= "" and (cResolved == pNorm or cResolved == pResolved) then return true end
    end

    return false
end

function Group:canEdit(playerName, isGuildLeader)
    if isGuildLeader == true or (IsGuildLeader and IsGuildLeader() == true) then
        return true
    end
    return self:isCreator(playerName)
end

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
        creator = self:getCreator(),
        time = self:getTime(),
        description = self:getDescription(),
        note = self._note,
        createdAt = self._createdAt,
        updatedAt = self:getUpdatedAt(),
        members = serializedMembers,
    }
end

_G.Group = Group
