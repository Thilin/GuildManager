---@class GroupService
---@field private _groupRepository GroupRepository
---@field private _memberService MemberService|nil
---@field private _guildRosterService GuildRosterService|nil
---@field private _lfgRepository LFGRepository|nil
---@field private _syncService SyncService|nil
GroupService = {}
GroupService.__index = GroupService

--- Construtor do serviço de grupos.
---@param groupRepository GroupRepository
---@param memberService MemberService|nil
---@param guildRosterService GuildRosterService|nil
---@param lfgRepository LFGRepository|nil
---@param syncService SyncService|nil
---@return GroupService
function GroupService:new(groupRepository, memberService, guildRosterService, lfgRepository, syncService)
    local instance = setmetatable({}, self)

    instance._groupRepository = groupRepository
    instance._memberService = memberService
    instance._guildRosterService = guildRosterService
    instance._lfgRepository = lfgRepository
    instance._syncService = syncService

    return instance
end

function GroupService:setLFGRepository(lfgRepository)
    self._lfgRepository = lfgRepository
end

function GroupService:setSyncService(syncService)
    self._syncService = syncService
end

--- Resolve o nome completo (nome e sobrenome) do personagem informado ou do jogador atual.
---@param explicitName string|nil
---@return string
function GroupService:resolveCreatorName(explicitName)
    if explicitName and explicitName ~= "" then
        local clean = (explicitName:match("^[^-]+") or explicitName):match("^%s*(.-)%s*$")
        if clean:find("%s") then
            return clean
        end
        if self._memberService and self._memberService.resolveFullName then
            local resolved = self._memberService:resolveFullName(clean)
            if resolved and resolved ~= "" and resolved:find("%s") then
                return resolved
            end
        end
        return clean
    end

    if self._memberService and self._memberService.resolvePlayerFullName then
        local pFull = self._memberService:resolvePlayerFullName()
        if pFull and pFull ~= "" then
            return pFull
        end
    end

    local myName = UnitName and UnitName("player")
    if myName and myName ~= "" then
        if self._memberService and self._memberService.resolveFullName then
            local resolved = self._memberService:resolveFullName(myName)
            if resolved and resolved ~= "" then
                return resolved
            end
        end
        return myName
    end

    return ""
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
---@param groupType GroupType @Tipo (DUNGEON, RAID, MISC, FARM, QUESTS, PVP)
---@param leaderName string @Nome do líder (obrigatório)
---@param leaderRole GroupRole|nil @Função do líder (obrigatório para Masmorra e Raide)
---@param timeStr string|nil @Horário previsto
---@param descStr string|nil @Descrição do grupo
---@param creatorName string|nil @Nome do criador (resolvido automaticamente com nome e sobrenome)
---@return Group|nil, string|nil @grupoCriado, mensagemErro
function GroupService:createGroup(name, groupType, leaderName, leaderRole, timeStr, descStr, creatorName)
    local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
    if not name or name:match("^%s*$") then
        return nil, curL["GROUP_SVC_ERR_EMPTY_NAME"] or "O nome do grupo não pode ser vazio."
    end

    if not leaderName or leaderName:match("^%s*$") then
        return nil, curL["GROUP_SVC_ERR_NO_LEADER"] or "Cada grupo precisa obrigatoriamente ter um líder da guilda."
    end

    groupType = groupType or GroupType.DUNGEON
    if groupType == GroupType.DUNGEON or groupType == GroupType.RAID then
        if not leaderRole or leaderRole == GroupRole.NONE or (leaderRole ~= GroupRole.TANK and leaderRole ~= GroupRole.HEALER and leaderRole ~= GroupRole.DPS) then
            leaderRole = GroupRole.DPS
        end
    else
        leaderRole = leaderRole or GroupRole.NONE
    end

    local cleanName = name:match("^%s*(.-)%s*$")
    local cleanLeader = leaderName:match("^%s*(.-)%s*$")
    local fullCreator = self:resolveCreatorName(creatorName)
    local classToken, level = self:getMemberDetails(cleanLeader)

    local group = Group:new({
        name = cleanName,
        type = groupType,
        leader = cleanLeader,
        creator = fullCreator,
        time = timeStr or "",
        description = descStr or "",
        note = timeStr or "",
        createdAt = time(),
        updatedAt = time(),
    })

    group:addMember(cleanLeader, leaderRole, classToken, level)

    local saved = self._groupRepository:save(group)
    if not saved then
        return nil, curL["GROUP_SVC_ERR_SAVE"] or "Falha ao persistir o grupo no banco de dados."
    end

    -- Dispara sincronização (primeiro Criador -> Líder da guilda -> Outros membros)
    if self._syncService and self._syncService.syncGroup then
        self._syncService:syncGroup(group, "CREATE")
    end

    return group, nil
end

--- Deleta um grupo existente.
--- Apenas o criador do grupo (ou líder da guilda) pode excluir o grupo.
---@param groupId string
---@param requesterName string|nil
---@return boolean, string|nil
function GroupService:deleteGroup(groupId, requesterName)
    if not groupId or groupId == "" then return false, "ID inválido." end
    local group = self._groupRepository:findById(groupId)
    if not group then return false, "Grupo não encontrado." end

    if requesterName and not group:canEdit(requesterName) then
        return false, "Apenas o criador do grupo pode excluí-lo."
    end

    local ok = self._groupRepository:delete(groupId)
    if ok and self._syncService and self._syncService.syncGroupDelete then
        self._syncService:syncGroupDelete(groupId)
    end
    return ok, nil
end

--- Atualiza informações do grupo (nome, tipo, líder, horário e descrição).
--- Apenas o criador do grupo (ou líder da guilda) pode editá-lo.
---@param groupId string
---@param name string|nil
---@param groupType GroupType|nil
---@param leaderName string|nil
---@param timeStr string|nil
---@param descStr string|nil
---@param requesterName string|nil
---@return boolean, string|nil
function GroupService:updateGroupDetails(groupId, name, groupType, leaderName, timeStr, descStr, requesterName)
    local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
    local group = self._groupRepository:findById(groupId)
    if not group then return false, curL["GROUP_SVC_ERR_NOT_FOUND"] or "Grupo não encontrado." end

    if requesterName and not group:canEdit(requesterName) then
        return false, "Apenas o criador do grupo tem permissão para editá-lo."
    end

    if name and not name:match("^%s*$") then
        group:setName(name:match("^%s*(.-)%s*$"))
    end

    if groupType and RAW_GROUP_TYPES and RAW_GROUP_TYPES[groupType] then
        group:setType(groupType)
    end

    if timeStr ~= nil then
        group:setTime(timeStr:match("^%s*(.-)%s*$") or "")
    end

    if descStr ~= nil then
        group:setDescription(descStr:match("^%s*(.-)%s*$") or "")
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

    group:setUpdatedAt(time())

    local ok = self._groupRepository:save(group)
    if ok and self._syncService and self._syncService.syncGroup then
        self._syncService:syncGroup(group, "UPDATE")
    end

    return ok, ok and nil or (curL["GROUP_SVC_ERR_SAVE"] or "Erro ao salvar alterações do grupo.")
end

--- Adiciona um membro ao grupo.
--- Apenas o criador do grupo pode adicionar membros.
--- Se o membro adicionado tiver um card no Procurando Grupo, o card é automaticamente excluído.
---@param groupId string
---@param memberName string
---@param role GroupRole|nil
---@param requesterName string|nil
---@return boolean, string|nil
function GroupService:addMemberToGroup(groupId, memberName, role, requesterName)
    local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
    if not groupId or not memberName or memberName:match("^%s*$") then
        return false, curL["GROUP_SVC_ERR_INVALID"] or "Dados inválidos."
    end

    local group = self._groupRepository:findById(groupId)
    if not group then
        return false, curL["GROUP_SVC_ERR_NOT_FOUND"] or "Grupo não encontrado."
    end

    if requesterName and not group:canEdit(requesterName) then
        return false, "Apenas o criador do grupo tem permissão para adicionar membros."
    end

    local cleanName = memberName:match("^%s*(.-)%s*$")
    if group:hasMember(cleanName) then
        return false, curL["GROUP_SVC_ERR_ALREADY_IN"] or "Este membro já faz parte do grupo."
    end

    local gType = group:getType()
    if gType == GroupType.DUNGEON or gType == GroupType.RAID then
        if not role or role == GroupRole.NONE or (role ~= GroupRole.TANK and role ~= GroupRole.HEALER and role ~= GroupRole.DPS) then
            role = GroupRole.DPS
        end
    else
        role = role or GroupRole.NONE
    end

    local classToken, level = self:getMemberDetails(cleanName)
    group:addMember(cleanName, role, classToken, level)
    group:setUpdatedAt(time())

    local ok = self._groupRepository:save(group)
    if ok then
        if self._syncService and self._syncService.syncGroup then
            self._syncService:syncGroup(group, "UPDATE")
        end
        return true, nil
    end

    return false, curL["GROUP_SVC_ERR_SAVE"] or "Erro ao salvar alterações no grupo."
end

--- Remove um membro do grupo.
--- O criador pode remover qualquer membro. Um membro pode se remover do grupo.
---@param groupId string
---@param memberName string
---@param requesterName string|nil
---@return boolean, string|nil
function GroupService:removeMemberFromGroup(groupId, memberName, requesterName)
    local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
    if not groupId or not memberName then return false, curL["GROUP_SVC_ERR_INVALID"] or "Dados inválidos." end

    local group = self._groupRepository:findById(groupId)
    if not group then return false, curL["GROUP_SVC_ERR_NOT_FOUND"] or "Grupo não encontrado." end

    if requesterName then
        local reqClean = (requesterName:match("^[^-]+") or requesterName):match("^%s*(.-)%s*$"):lower()
        local memClean = (memberName:match("^[^-]+") or memberName):match("^%s*(.-)%s*$"):lower()
        if reqClean ~= memClean and not group:canEdit(requesterName) then
            return false, "Apenas o criador do grupo pode remover outros membros."
        end
    end

    local removed, wasLeader = group:removeMember(memberName)
    if not removed then
        return false, curL["GROUP_SVC_ERR_MEMBER_NOT_IN"] or "Membro não encontrado no grupo."
    end

    group:setUpdatedAt(time())
    self._groupRepository:save(group)

    if self._syncService and self._syncService.syncGroup then
        self._syncService:syncGroup(group, "UPDATE")
    end

    return true, nil
end

--- Promove um membro a líder do grupo.
---@param groupId string
---@param newLeaderName string
---@param requesterName string|nil
---@return boolean, string|nil
function GroupService:setGroupLeader(groupId, newLeaderName, requesterName)
    local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
    if not groupId or not newLeaderName then return false, curL["GROUP_SVC_ERR_INVALID"] or "Dados inválidos." end

    local group = self._groupRepository:findById(groupId)
    if not group then return false, curL["GROUP_SVC_ERR_NOT_FOUND"] or "Grupo não encontrado." end

    if requesterName and not group:canEdit(requesterName) then
        return false, "Apenas o criador do grupo pode alterar o líder."
    end

    if not group:hasMember(newLeaderName) then
        return false, curL["GROUP_SVC_ERR_LEADER_MUST_IN"] or "O líder deve ser um membro pertencente ao grupo."
    end

    group:setLeader(newLeaderName)
    group:setUpdatedAt(time())
    self._groupRepository:save(group)

    if self._syncService and self._syncService.syncGroup then
        self._syncService:syncGroup(group, "UPDATE")
    end

    return true, nil
end

--- Altera a função de um membro no grupo.
---@param groupId string
---@param memberName string
---@param role GroupRole
---@param requesterName string|nil
---@return boolean, string|nil
function GroupService:setMemberRole(groupId, memberName, role, requesterName)
    local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
    if not groupId or not memberName or not role then return false, curL["GROUP_SVC_ERR_INVALID"] or "Dados inválidos." end

    local group = self._groupRepository:findById(groupId)
    if not group then return false, curL["GROUP_SVC_ERR_NOT_FOUND"] or "Grupo não encontrado." end

    if requesterName then
        local reqClean = (requesterName:match("^[^-]+") or requesterName):match("^%s*(.-)%s*$"):lower()
        local memClean = (memberName:match("^[^-]+") or memberName):match("^%s*(.-)%s*$"):lower()
        if reqClean ~= memClean and not group:canEdit(requesterName) then
            return false, "Sem permissão para alterar função deste membro."
        end
    end

    local ok = group:setMemberRole(memberName, role)
    if ok then
        group:setUpdatedAt(time())
        self._groupRepository:save(group)
        if self._syncService and self._syncService.syncGroup then
            self._syncService:syncGroup(group, "UPDATE")
        end
        return true, nil
    end
    return false, curL["GROUP_SVC_ERR_INVALID_ROLE"] or "Função inválida."
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

-- =========================================================================
-- MÉTODOS DE PROCURANDO GRUPO (LFG DASHBOARD)
-- =========================================================================

--- Cria um card de Procurando Grupo (LFG).
--- O nome do criador é fixo e validado automaticamente com nome e sobrenome.
---@param groupType string
---@param timeStr string
---@param descStr string
---@param creatorName string|nil
---@return LFGCard|nil, string|nil
function GroupService:createLFGCard(groupType, timeStr, descStr, creatorName)
    if not self._lfgRepository then
        return nil, "Repositório de Procurando Grupo indisponível."
    end

    local fullCreator = self:resolveCreatorName(creatorName)
    if not fullCreator or fullCreator == "" then
        return nil, "Nome do personagem criador não identificado."
    end

    -- REQUISITO: Cada membro pode criar até 5 cards de LFG ativos
    local currentCount = 0
    if self._lfgRepository and self._lfgRepository.countByCreator then
        currentCount = self._lfgRepository:countByCreator(fullCreator)
    elseif self._lfgRepository and self._lfgRepository.findAllByCreator then
        currentCount = #(self._lfgRepository:findAllByCreator(fullCreator) or {})
    end

    if currentCount >= 5 then
        return nil, "Você já atingiu o limite de 5 cards de Procurando Grupo ativos. Exclua um card existente para poder criar um novo."
    end

    local classToken, level = self:getMemberDetails(fullCreator)

    local card = LFGCard:new({
        type = groupType or "DUNGEON",
        time = timeStr or "",
        description = descStr or "",
        creator = fullCreator,
        creatorClass = classToken,
        creatorLevel = level,
        createdAt = time(),
    })

    local ok = self._lfgRepository:save(card)
    if not ok then
        return nil, "Falha ao salvar card de Procurando Grupo."
    end

    -- Sincronização em 2 tempos (Criador -> Líder da guilda -> Membros da guilda)
    if self._syncService and self._syncService.syncLFGCard then
        self._syncService:syncLFGCard(card, "CREATE")
    end

    return card, nil
end

--- Exclui um card de Procurando Grupo pelo ID.
---@param cardId string
---@param requesterName string|nil
---@return boolean, string|nil
function GroupService:deleteLFGCard(cardId, requesterName)
    if not self._lfgRepository or not cardId or cardId == "" then
        return false, "Card inválido."
    end

    local card = self._lfgRepository:findById(cardId)
    if not card then
        return false, "Card não encontrado."
    end

    if requesterName and not card:isCreator(requesterName) and not (IsGuildLeader and IsGuildLeader()) then
        return false, "Apenas o criador pode excluir este card."
    end

    local ok = self._lfgRepository:delete(cardId)
    if ok and self._syncService and self._syncService.syncLFGCardDelete then
        self._syncService:syncLFGCardDelete(cardId)
    end
    return ok, nil
end

--- Exclui card criado pelo membro informado.
---@param memberName string
---@return boolean
function GroupService:deleteLFGCardByCreator(memberName)
    if not self._lfgRepository or not memberName or memberName == "" then
        return false
    end

    local card = self._lfgRepository:findByCreator(memberName)
    if card then
        return self:deleteLFGCard(card:getId())
    end
    return false
end

--- Limpa cards expirados (> 72 horas).
---@return number @Quantidade de cards expirados removidos
function GroupService:cleanExpiredCards()
    if self._lfgRepository and self._lfgRepository.cleanExpired then
        return self._lfgRepository:cleanExpired()
    end
    return 0
end

--- Retorna todos os cards de Procurando Grupo cadastrados.
---@return LFGCard[]
function GroupService:getAllLFGCards()
    if not self._lfgRepository then return {} end
    if self._lfgRepository.cleanExpired then
        self._lfgRepository:cleanExpired()
    end
    return self._lfgRepository:findAll()
end

--- Retorna cards filtrados por tipo.
---@param groupType string|nil
---@return LFGCard[]
function GroupService:getLFGCardsByType(groupType)
    if not self._lfgRepository then return {} end
    if self._lfgRepository.cleanExpired then
        self._lfgRepository:cleanExpired()
    end
    return self._lfgRepository:findByType(groupType)
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

_G.GroupService = GroupService
