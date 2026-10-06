---@class GroupService
---@field private _groupRepository GroupRepository
---@field private _memberService MemberService|nil
---@field private _guildRosterService GuildRosterService|nil
GroupService = {}
GroupService.__index = GroupService

--- Construtor do serviço de grupos.
---@param groupRepository GroupRepository
---@param memberService MemberService|nil
---@param guildRosterService GuildRosterService|nil
---@return GroupService
function GroupService:new(groupRepository, memberService, guildRosterService)
    local instance = setmetatable({}, self)

    instance._groupRepository = groupRepository
    instance._memberService = memberService
    instance._guildRosterService = guildRosterService

    return instance
end

--- Busca informações de um membro (classe, nível) a partir do MemberService ou do Roster.
---@param memberName string
---@return string, number @classToken, level
function GroupService:getMemberDetails(memberName)
    local classToken = ""
    local level = 1
    if not memberName or memberName == "" then return classToken, level end

    local cleanName = memberName:match("^[^-]+") or memberName
    cleanName = cleanName:match("^%s*(.-)%s*$") or cleanName
    local cleanLower = cleanName:lower()

    if self._memberService then
        local member = nil
        if self._memberService.getMember then
            member = self._memberService:getMember(memberName) or self._memberService:getMember(cleanName)
        end
        if not member and self._memberService.getAllMembers then
            for _, m in ipairs(self._memberService:getAllMembers() or {}) do
                local mName = (m:getName() or ""):match("^[^-]+") or (m:getName() or "")
                if mName:lower() == cleanLower then
                    member = m
                    break
                end
            end
        end
        if member then
            classToken = member:getClass() or ""
            level = member:getLevel() or 1
        end
    end

    if (not classToken or classToken == "") and self._guildRosterService and self._guildRosterService.getRosterData then
        local roster = self._guildRosterService:getRosterData()
        if roster then
            local rData = roster[memberName] or roster[cleanName] or roster[cleanLower]
            if rData then
                classToken = rData.classFileName or rData.class or ""
                level = tonumber(rData.level) or level
            end
        end
    end

    if (not classToken or classToken == "") and GetNumGuildMembers and GetGuildRosterInfo then
        local num = GetNumGuildMembers() or 0
        for i = 1, num do
            local gName, _, _, gLevel, _, _, _, _, _, _, gClass = GetGuildRosterInfo(i)
            if gName then
                local gClean = (gName:match("^[^-]+") or gName):match("^%s*(.-)%s*$")
                if gClean:lower() == cleanLower then
                    classToken = gClass or ""
                    level = tonumber(gLevel) or level
                    break
                end
            end
        end
    end

    return classToken, level
end

--- Cria um novo grupo.
---@param name string @Nome do grupo
---@param groupType GroupType @Tipo (DUNGEON, RAID, MISC)
---@param leaderName string @Nome do líder (obrigatório)
---@param leaderRole GroupRole|nil @Função do líder (obrigatório para Masmorra e Raide)
---@param note string|nil @Nota / Horário opcional
---@return Group|nil, string|nil @grupoCriado, mensagemErro
function GroupService:createGroup(name, groupType, leaderName, leaderRole, note)
    if not name or name:match("^%s*$") then
        return nil, "O nome do grupo não pode ser vazio."
    end

    if not leaderName or leaderName:match("^%s*$") then
        return nil, "Cada grupo precisa obrigatoriamente ter um líder da guilda."
    end

    groupType = groupType or GroupType.DUNGEON
    if groupType == GroupType.DUNGEON or groupType == GroupType.RAID then
        if not leaderRole or leaderRole == GroupRole.NONE or (leaderRole ~= GroupRole.TANK and leaderRole ~= GroupRole.HEALER and leaderRole ~= GroupRole.DPS) then
            return nil, "Para grupos de masmorra e raide, a função do líder deve ser definida (Tank, Curador ou Dano)."
        end
    else
        leaderRole = leaderRole or GroupRole.NONE
    end

    local cleanName = name:match("^%s*(.-)%s*$")
    local cleanLeader = leaderName:match("^%s*(.-)%s*$")
    local classToken, level = self:getMemberDetails(cleanLeader)

    local group = Group:new({
        name = cleanName,
        type = groupType,
        leader = cleanLeader,
        note = note or "",
        createdAt = time(),
    })

    group:addMember(cleanLeader, leaderRole, classToken, level)

    local saved = self._groupRepository:save(group)
    if not saved then
        return nil, "Falha ao persistir o grupo no banco de dados."
    end

    return group, nil
end

--- Deleta um grupo existente.
---@param groupId string
---@return boolean
function GroupService:deleteGroup(groupId)
    if not groupId or groupId == "" then return false end
    return self._groupRepository:delete(groupId)
end

--- Adiciona um membro ao grupo.
---@param groupId string
---@param memberName string
---@param role GroupRole|nil
---@return boolean, string|nil
function GroupService:addMemberToGroup(groupId, memberName, role)
    if not groupId or not memberName or memberName:match("^%s*$") then
        return false, "Dados inválidos."
    end

    local group = self._groupRepository:findById(groupId)
    if not group then
        return false, "Grupo não encontrado."
    end

    local cleanName = memberName:match("^%s*(.-)%s*$")
    if group:hasMember(cleanName) then
        return false, "Este membro já faz parte do grupo."
    end

    local gType = group:getType()
    if gType == GroupType.DUNGEON or gType == GroupType.RAID then
        if not role or role == GroupRole.NONE or (role ~= GroupRole.TANK and role ~= GroupRole.HEALER and role ~= GroupRole.DPS) then
            return false, "Defina a função do membro no grupo (Tank, Curador ou Dano)."
        end
    else
        role = role or GroupRole.NONE
    end

    local classToken, level = self:getMemberDetails(cleanName)
    group:addMember(cleanName, role, classToken, level)

    local ok = self._groupRepository:save(group)
    return ok, ok and nil or "Erro ao salvar alterações no grupo."
end

--- Remove um membro do grupo.
---@param groupId string
---@param memberName string
---@return boolean, string|nil
function GroupService:removeMemberFromGroup(groupId, memberName)
    if not groupId or not memberName then return false, "Dados inválidos." end

    local group = self._groupRepository:findById(groupId)
    if not group then return false, "Grupo não encontrado." end

    local removed, wasLeader = group:removeMember(memberName)
    if not removed then
        return false, "Membro não encontrado no grupo."
    end

    self._groupRepository:save(group)
    return true, nil
end

--- Promove um membro a líder do grupo.
---@param groupId string
---@param newLeaderName string
---@return boolean, string|nil
function GroupService:setGroupLeader(groupId, newLeaderName)
    if not groupId or not newLeaderName then return false, "Dados inválidos." end

    local group = self._groupRepository:findById(groupId)
    if not group then return false, "Grupo não encontrado." end

    if not group:hasMember(newLeaderName) then
        return false, "O líder deve ser um membro pertencente ao grupo."
    end

    group:setLeader(newLeaderName)
    self._groupRepository:save(group)
    return true, nil
end

--- Altera a função de um membro no grupo.
---@param groupId string
---@param memberName string
---@param role GroupRole
---@return boolean, string|nil
function GroupService:setMemberRole(groupId, memberName, role)
    if not groupId or not memberName or not role then return false, "Dados inválidos." end

    local group = self._groupRepository:findById(groupId)
    if not group then return false, "Grupo não encontrado." end

    local ok = group:setMemberRole(memberName, role)
    if ok then
        self._groupRepository:save(group)
        return true, nil
    end
    return false, "Função inválida."
end

--- Atualiza informações básicas do grupo (nome, nota/horário e líder).
---@param groupId string
---@param name string|nil
---@param note string|nil
---@param leaderName string|nil
---@return boolean, string|nil
function GroupService:updateGroupDetails(groupId, name, note, leaderName)
    local group = self._groupRepository:findById(groupId)
    if not group then return false, "Grupo não encontrado." end

    if name and not name:match("^%s*$") then
        group:setName(name:match("^%s*(.-)%s*$"))
    end

    if note ~= nil then
        group:setNote(note:match("^%s*(.-)%s*$") or "")
    end

    if leaderName and not leaderName:match("^%s*$") then
        local cleanLeader = leaderName:match("^%s*(.-)%s*$")
        if not group:hasMember(cleanLeader) then
            local classToken, level = self:getMemberDetails(cleanLeader)
            local defaultRole = (group:getType() ~= GroupType.MISC) and GroupRole.DPS or GroupRole.NONE
            group:addMember(cleanLeader, defaultRole, classToken, level)
        end
        group:setLeader(cleanLeader)
    end

    -- Preenche classe e nível que possam estar vazios em membros existentes
    for _, mData in ipairs(group:getMembers() or {}) do
        if not mData.class or mData.class == "" then
            local cTok, lvl = self:getMemberDetails(mData.name)
            if cTok and cTok ~= "" then
                mData.class = cTok
            end
            if lvl and lvl > 0 and (not mData.level or mData.level <= 1) then
                mData.level = lvl
            end
        end
    end

    local ok = self._groupRepository:save(group)
    return ok, ok and nil or "Erro ao salvar alterações do grupo."
end

--- Busca um grupo pelo ID.
---@param groupId string
---@return Group|nil
function GroupService:getGroupById(groupId)
    if not groupId or groupId == "" then return nil end
    return self._groupRepository:findById(groupId)
end

--- Retorna todos os grupos.
---@return Group[]
function GroupService:getAllGroups()
    return self._groupRepository:findAll()
end

--- Retorna grupos filtrados por tipo.
---@param groupType GroupType
---@return Group[]
function GroupService:getGroupsByType(groupType)
    return self._groupRepository:findByType(groupType)
end

--- Convida todos os membros do grupo para o grupo/raide no World of Warcraft.
---@param groupId string
---@return number @Quantidade de membros convidados
function GroupService:inviteGroupToParty(groupId)
    local group = self._groupRepository:findById(groupId)
    if not group then return 0 end

    local members = group:getMembers() or {}
    local myName = UnitName and UnitName("player") or ""
    local invited = 0

    -- Se o grupo tem mais de 5 membros, converte para raide se possível
    local totalMembers = #members
    if totalMembers > 5 and ConvertToRaid then
        local inGroup = (IsInRaid and IsInRaid()) or (IsInGroup and IsInGroup()) or (GetNumGroupMembers and GetNumGroupMembers() > 0)
        local isLeader = UnitIsGroupLeader and UnitIsGroupLeader("player")
        if inGroup and isLeader and not (IsInRaid and IsInRaid()) then
            pcall(ConvertToRaid)
        end
    end

    for _, m in ipairs(members) do
        local target = m.name
        if target and target ~= "" and target:lower() ~= myName:lower() then
            if C_PartyInfo and C_PartyInfo.InviteUnit then
                pcall(C_PartyInfo.InviteUnit, target)
                invited = invited + 1
            elseif InviteUnit then
                pcall(InviteUnit, target)
                invited = invited + 1
            end
        end
    end

    return invited
end

-- Exportação/Alias de compatibilidade
_G.GroupService = GroupService
