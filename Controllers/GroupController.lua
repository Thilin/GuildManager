---@class GroupController
---@field private _groupService GroupService
---@field private _memberService MemberService
---@field private _guildRosterService GuildRosterService
---@field private _groupView GroupView
GroupController = {}
GroupController.__index = GroupController

--- Construtor do Controller de gerenciamento de grupos e Procurando Grupo.
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

--- Obtém o nome completo do jogador atual (nome e sobrenome).
---@return string
function GroupController:resolvePlayerFullName()
    if self._memberService and self._memberService.resolvePlayerFullName then
        local resolved = self._memberService:resolvePlayerFullName()
        if resolved and resolved ~= "" then
            return resolved
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

--- Inicializa os ganchos da View e comandos de barra (/gmgrupos).
function GroupController:initHooks()
    if not self._groupView then return end

    -- Callback de atualização da View
    if self._groupView.setOnRefreshCallback then
        self._groupView:setOnRefreshCallback(function()
            self:refreshGroups()
        end)
    end

    -- Callback de criação de grupo (TODOS os membros da guilda podem criar grupos)
    if self._groupView.setOnCreateGroupCallback then
        self._groupView:setOnCreateGroupCallback(function(name, groupType, leaderName, leaderRole, timeStr, descStr)
            local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
            if not self._groupService then
                return false, curL["GROUP_CTRL_ERR_UNAVAILABLE"] or "Serviço de grupos indisponível."
            end

            local myFullName = self:resolvePlayerFullName()
            local group, err = self._groupService:createGroup(name, groupType, leaderName, leaderRole, timeStr, descStr, myFullName)
            if group then
                pcall(function() self:refreshGroups() end)
                return true, nil
            end
            return false, err
        end)
    end

    -- Callback de exclusão de grupo (Apenas o criador ou líder da guilda pode excluir)
    if self._groupView.setOnDeleteGroupCallback then
        self._groupView:setOnDeleteGroupCallback(function(groupId)
            if not self._groupService then return false end
            local myFullName = self:resolvePlayerFullName()
            local ok, err = self._groupService:deleteGroup(groupId, myFullName)
            if ok then
                pcall(function() self:refreshGroups() end)
                return true
            else
                print("|cffff4444[GuildManager]|r " .. (err or "Apenas o criador do grupo pode excluí-lo."))
                return false, err
            end
        end)
    end

    -- Callback de adição de membro (Apenas o criador pode adicionar membros)
    if self._groupView.setOnAddMemberCallback then
        self._groupView:setOnAddMemberCallback(function(groupId, memberName, role)
            local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
            if not self._groupService then
                return false, curL["GROUP_CTRL_ERR_UNAVAILABLE"] or "Serviço de grupos indisponível."
            end

            local myFullName = self:resolvePlayerFullName()
            local ok, err = self._groupService:addMemberToGroup(groupId, memberName, role, myFullName)
            if ok then
                pcall(function() self:refreshGroups() end)
                return true, nil
            end
            return false, err
        end)
    end

    -- Callback de remoção de membro
    if self._groupView.setOnRemoveMemberCallback then
        self._groupView:setOnRemoveMemberCallback(function(groupId, memberName)
            if not self._groupService then return false end
            local myFullName = self:resolvePlayerFullName()
            local ok, err = self._groupService:removeMemberFromGroup(groupId, memberName, myFullName)
            if ok then
                pcall(function() self:refreshGroups() end)
                return true
            else
                print("|cffff4444[GuildManager]|r " .. (err or "Sem permissão para remover este membro."))
                return false, err
            end
        end)
    end

    -- Callback de alteração de líder
    if self._groupView.setOnSetLeaderCallback then
        self._groupView:setOnSetLeaderCallback(function(groupId, newLeaderName)
            if not self._groupService then return false end
            local myFullName = self:resolvePlayerFullName()
            local ok, err = self._groupService:setGroupLeader(groupId, newLeaderName, myFullName)
            if ok then
                pcall(function() self:refreshGroups() end)
                return true
            else
                print("|cffff4444[GuildManager]|r " .. (err or "Sem permissão para alterar o líder."))
                return false, err
            end
        end)
    end

    -- Callback de alteração de função
    if self._groupView.setOnSetRoleCallback then
        self._groupView:setOnSetRoleCallback(function(groupId, memberName, role)
            if not self._groupService then return false end
            local myFullName = self:resolvePlayerFullName()
            local ok, err = self._groupService:setMemberRole(groupId, memberName, role, myFullName)
            if ok then
                pcall(function() self:refreshGroups() end)
                return true
            end
            return false, err
        end)
    end

    -- Callback de atualização de detalhes do grupo (nome, tipo, líder, horário, descrição)
    if self._groupView.setOnUpdateGroupDetailsCallback then
        self._groupView:setOnUpdateGroupDetailsCallback(function(groupId, name, groupType, leaderName, timeStr, descStr)
            local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
            if not self._groupService then
                return false, curL["GROUP_CTRL_ERR_UNAVAILABLE"] or "Serviço de grupos indisponível."
            end

            local myFullName = self:resolvePlayerFullName()
            local ok, err = self._groupService:updateGroupDetails(groupId, name, groupType, leaderName, timeStr, descStr, myFullName)
            if ok then
                pcall(function() self:refreshGroups() end)
                return true, nil
            end
            return false, err
        end)
    end

    -- Callback de criação de card de Procurando Grupo (LFG)
    if self._groupView.setOnCreateLFGCardCallback then
        self._groupView:setOnCreateLFGCardCallback(function(groupType, timeStr, descStr)
            if not self._groupService then return false, "Serviço de grupos indisponível." end
            local myFullName = self:resolvePlayerFullName()
            local card, err = self._groupService:createLFGCard(groupType, timeStr, descStr, myFullName)
            if card then
                pcall(function() self:refreshGroups() end)
                return true, nil
            end
            return false, err
        end)
    end

    -- Callback de exclusão de card de Procurando Grupo (LFG)
    if self._groupView.setOnDeleteLFGCardCallback then
        self._groupView:setOnDeleteLFGCardCallback(function(cardId)
            if not self._groupService then return false end
            local myFullName = self:resolvePlayerFullName()
            local ok, err = self._groupService:deleteLFGCard(cardId, myFullName)
            if ok then
                pcall(function() self:refreshGroups() end)
                return true
            else
                print("|cffff4444[GuildManager]|r " .. (err or "Falha ao excluir card."))
                return false, err
            end
        end)
    end

    -- Callback de convite para party/raid no WoW
    if self._groupView.setOnInviteGroupCallback then
        self._groupView:setOnInviteGroupCallback(function(groupId)
            local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
            if not self._groupService then return end
            local count = self._groupService:inviteGroupToParty(groupId)
            if count and count > 0 then
                print(string.format("|cff00ff00[GuildManager]|r " .. (curL["GROUP_CTRL_INVITING_MSG"] or "Enviando convites para %d membro(s) do grupo."), count))
            else
                print("|cffff8800[GuildManager]|r " .. (curL["GROUP_CTRL_NO_INVITE_MSG"] or "Nenhum membro para convidar no momento."))
            end
        end)
    end

    -- Comandos de chat /gmgrupos, /gmgroups, /gmgrupo, /gmlfg
    SLASH_GUILDMANAGERGROUPS1 = "/gmgrupos"
    SLASH_GUILDMANAGERGROUPS2 = "/gmgroups"
    SLASH_GUILDMANAGERGROUPS3 = "/gmgrupo"
    SLASH_GUILDMANAGERGROUPS4 = "/gmlfg"
    SlashCmdList["GUILDMANAGERGROUPS"] = function()
        self:toggle()
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
    eventFrame:SetScript("OnEvent", function()
        if self._groupView and self._groupView:isShown() then
            self:refreshGroups()
        end
    end)
    self._eventFrame = eventFrame
end

--- Atualiza a lista de membros, grupos e cards de LFG carregados na View.
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
    if self._groupView.setGuildMembers then
        self._groupView:setGuildMembers(activeMembers)
    end

    -- Atualiza lista de grupos cadastrados
    local allGroups = {}
    if self._groupService and self._groupService.getAllGroups then
        allGroups = self._groupService:getAllGroups() or {}
    end
    if self._groupView.setGroups then
        self._groupView:setGroups(allGroups)
    end

    -- Atualiza lista de cards de Procurando Grupo (LFG)
    local allLFGCards = {}
    if self._groupService and self._groupService.getAllLFGCards then
        allLFGCards = self._groupService:getAllLFGCards() or {}
    end
    if self._groupView.setLFGCards then
        self._groupView:setLFGCards(allLFGCards)
    end

    -- Atualiza modal de detalhes se estiver aberta
    if self._groupView.refreshOpenDetailModal then
        self._groupView:refreshOpenDetailModal()
    end
end

--- Abre a janela de gerenciamento de grupos e Procurando Grupo.
function GroupController:show()
    if not IsInGuild or not IsInGuild() then
        if _G.GM and _G.GM.introView and _G.GM.introView.showNoGuildDialog then
            _G.GM.introView:showNoGuildDialog()
        else
            local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
            print("|cffff0000[GuildManager]|r " .. (curL["NOT_IN_GUILD"] or "Você não está em uma guilda."))
        end
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

_G.GroupController = GroupController
