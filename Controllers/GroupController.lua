---@class GroupController
---@field private _groupService GroupService
---@field private _memberService MemberService
---@field private _guildRosterService GuildRosterService
---@field private _groupView GroupView
GroupController = {}
GroupController.__index = GroupController

--- Construtor do Controller de gerenciamento de grupos.
---@param groupService GroupService @Serviço de gerenciamento de grupos
---@param memberService MemberService @Serviço de gerenciamento de membros
---@param guildRosterService GuildRosterService @Serviço de comunicação com o roster da Blizzard
---@param groupView GroupView @Camada de visualização da tela de grupos
---@return GroupController
function GroupController:new(groupService, memberService, guildRosterService, groupView)
    local instance = setmetatable({}, self)

    instance._groupService = groupService
    instance._memberService = memberService
    instance._guildRosterService = guildRosterService
    instance._groupView = groupView

    return instance
end

--- Inicializa os ganchos da View e comandos de barra (/gmgrupos).
function GroupController:initHooks()
    if not self._groupView then return end

    -- Callback de atualização da View
    if self._groupView.setOnRefreshCallback then
        self._groupView:setOnRefreshCallback(function()
            self:refreshGroups()
        end)
    end

    -- Callback de criação de grupo
    if self._groupView.setOnCreateGroupCallback then
        self._groupView:setOnCreateGroupCallback(function(name, groupType, leaderName, leaderRole, note)
            if not self._groupService then return false, "Serviço de grupos indisponível." end
            local group, err = self._groupService:createGroup(name, groupType, leaderName, leaderRole, note)
            if group then
                self:refreshGroups()
                return true, nil
            end
            return false, err
        end)
    end

    -- Callback de exclusão de grupo
    if self._groupView.setOnDeleteGroupCallback then
        self._groupView:setOnDeleteGroupCallback(function(groupId)
            if not self._groupService then return end
            self._groupService:deleteGroup(groupId)
            self:refreshGroups()
        end)
    end

    -- Callback de adição de membro
    if self._groupView.setOnAddMemberCallback then
        self._groupView:setOnAddMemberCallback(function(groupId, memberName, role)
            if not self._groupService then return false, "Serviço de grupos indisponível." end
            local ok, err = self._groupService:addMemberToGroup(groupId, memberName, role)
            if ok then
                self:refreshGroups()
                return true, nil
            end
            return false, err
        end)
    end

    -- Callback de remoção de membro
    if self._groupView.setOnRemoveMemberCallback then
        self._groupView:setOnRemoveMemberCallback(function(groupId, memberName)
            if not self._groupService then return end
            self._groupService:removeMemberFromGroup(groupId, memberName)
            self:refreshGroups()
        end)
    end

    -- Callback de alteração de líder
    if self._groupView.setOnSetLeaderCallback then
        self._groupView:setOnSetLeaderCallback(function(groupId, newLeaderName)
            if not self._groupService then return end
            self._groupService:setGroupLeader(groupId, newLeaderName)
            self:refreshGroups()
        end)
    end

    -- Callback de alteração de função
    if self._groupView.setOnSetRoleCallback then
        self._groupView:setOnSetRoleCallback(function(groupId, memberName, role)
            if not self._groupService then return end
            self._groupService:setMemberRole(groupId, memberName, role)
            self:refreshGroups()
        end)
    end

    -- Callback de atualização de detalhes do grupo (nome, nota, líder)
    if self._groupView.setOnUpdateGroupDetailsCallback then
        self._groupView:setOnUpdateGroupDetailsCallback(function(groupId, name, note, leaderName)
            if not self._groupService then return false, "Serviço de grupos indisponível." end
            local ok, err = self._groupService:updateGroupDetails(groupId, name, note, leaderName)
            if ok then
                self:refreshGroups()
                return true, nil
            end
            return false, err
        end)
    end

    -- Callback de convite para party/raid no WoW
    if self._groupView.setOnInviteGroupCallback then
        self._groupView:setOnInviteGroupCallback(function(groupId)
            if not self._groupService then return end
            local count = self._groupService:inviteGroupToParty(groupId)
            if count and count > 0 then
                print(string.format("|cff00ff00[GuildManager]|r Enviando convite para %d membro(s) do grupo.", count))
            else
                print("|cffff8800[GuildManager]|r Nenhum membro para convidar no momento (você pode ser o único membro do grupo).")
            end
        end)
    end

    -- Comandos de chat /gmgrupos, /gmgroups, /gmgrupo
    SLASH_GUILDMANAGERGROUPS1 = "/gmgrupos"
    SLASH_GUILDMANAGERGROUPS2 = "/gmgroups"
    SLASH_GUILDMANAGERGROUPS3 = "/gmgrupo"
    SlashCmdList["GUILDMANAGERGROUPS"] = function()
        self:toggle()
    end
end

--- Atualiza a lista de membros e grupos carregados na View.
function GroupController:refreshGroups()
    if not self._groupView then return end

    if IsInGuild and IsInGuild() then
        if self._guildRosterService and self._guildRosterService.scanRoster then
            self._guildRosterService:scanRoster()
        end
    end

    -- Atualiza lista de membros disponíveis
    local activeMembers = {}
    if self._memberService and self._memberService.getAllMembers then
        local all = self._memberService:getAllMembers() or {}
        for _, m in ipairs(all) do
            if m:isInGuild() then
                table.insert(activeMembers, m)
            end
        end
    end
    self._groupView:setGuildMembers(activeMembers)

    -- Atualiza lista de grupos cadastrados
    local allGroups = {}
    if self._groupService and self._groupService.getAllGroups then
        allGroups = self._groupService:getAllGroups() or {}
    end
    self._groupView:setGroups(allGroups)

    -- Atualiza modal de detalhes se estiver aberta
    if self._groupView.refreshOpenDetailModal then
        self._groupView:refreshOpenDetailModal()
    end
end

--- Abre a janela de gerenciamento de grupos.
function GroupController:show()
    if not IsInGuild or not IsInGuild() then
        print("|cffff0000[GuildManager]|r Você não está em uma guilda.")
        return
    end

    self:refreshGroups()
    if self._groupView then
        self._groupView:show()
    end
end

--- Oculta a janela de gerenciamento de grupos.
function GroupController:hide()
    if self._groupView then
        self._groupView:hide()
    end
end

--- Alterna a visibilidade da janela.
function GroupController:toggle()
    if not self._groupView then return end

    if self._groupView:isShown() then
        self:hide()
    else
        self:show()
    end
end

-- Exportação/Alias de compatibilidade
_G.GroupController = GroupController
