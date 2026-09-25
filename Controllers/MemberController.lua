---@class MemberController
---@field private _memberService MemberService
---@field private _guildRosterService GuildRosterService
---@field private _memberView MemberView
---@field private _eventFrame table
MemberController = {}
MemberController.__index = MemberController

--- Construtor do Controller de membros no padrão MVC.
---@param memberService MemberService @Serviço de membros
---@param guildRosterService GuildRosterService @Serviço de comunicação com o roster da Blizzard
---@param memberView MemberView @Camada de visualização da ficha do membro
---@return MemberController
function MemberController:new(memberService, guildRosterService, memberView)
    local instance = setmetatable({}, self)

    instance._memberService = memberService
    instance._guildRosterService = guildRosterService
    instance._memberView = memberView
    instance._eventFrame = nil
    instance._debounceTimer = nil
    instance._tooltipHooked = false
    instance._communitiesHooked = false
    instance._guildFrameHooked = false
    instance._pendingInvites = {}
    instance._recentRecruits = {}
    instance._lastPlayerInvite = nil
    instance._guildInviteHooked = false
    instance._cGuildInviteHooked = false

    return instance
end

--- Registra ganchos (hooks) e ouvintes de eventos da Blizzard para capturar e persistir
--- as informações dos membros e controlar a abertura e trava da tela de membro.
function MemberController:initHooks()
    -- Vincula o callback de salvamento da View ao Serviço de persistência
    if self._memberView and self._memberView.setOnSaveCallback then
        self._memberView:setOnSaveCallback(function(member, updatedFields)
            if not member or not updatedFields then
                return
            end

            if updatedFields.customNote ~= nil then
                member:setCustomNote(updatedFields.customNote)
            end
            if updatedFields.birthday ~= nil then
                member:setBirthday(updatedFields.birthday)
            end
            if updatedFields.dateJoin ~= nil then
                member:setDateJoin(updatedFields.dateJoin)
            end
            if updatedFields.isMain ~= nil then
                member:setMain(updatedFields.isMain)
            end
            if updatedFields.recruiter ~= nil then
                member:setRecruiter(updatedFields.recruiter)
            end

            self._memberService:saveMember(member)
        end)
    end

    -- Fornece a lista de membros e callback de busca para a seleção de recrutador na View
    if self._memberView and self._memberView.setGuildMembersProvider then
        self._memberView:setGuildMembersProvider(function()
            local all = self._memberService:getAllMembers()
            if #all == 0 and IsInGuild and IsInGuild() then
                self._guildRosterService:scanRoster()
                all = self._memberService:getAllMembers()
            end
            local guildMembers = {}
            for _, m in ipairs(all) do
                if m:isInGuild() then
                    table.insert(guildMembers, m)
                end
            end
            table.sort(guildMembers, function(a, b)
                return (a:getName() or ""):lower() < (b:getName() or ""):lower()
            end)
            return guildMembers
        end)
    end

    if self._memberView and self._memberView.setMemberLookupCallback then
        self._memberView:setMemberLookupCallback(function(name)
            return self._memberService:getMember(name)
        end)
    end

    -- Criação do Frame de eventos
    if not self._eventFrame then
        local frame = CreateFrame("Frame")
        self._eventFrame = frame

        frame:RegisterEvent("ADDON_LOADED")
        frame:RegisterEvent("PLAYER_LOGIN")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("GUILD_ROSTER_UPDATE")
        frame:RegisterEvent("PLAYER_GUILD_UPDATE")
        frame:RegisterEvent("CHAT_MSG_SYSTEM")
        frame:RegisterEvent("CHAT_MSG_ADDON")
        frame:RegisterEvent("GUILD_EVENT_LOG_UPDATE")

        frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
            if event == "ADDON_LOADED" then
                local loadedAddon = arg1
                if loadedAddon == "Blizzard_Communities" or loadedAddon == "Blizzard_GuildUI" then
                    self:registerAllHooks()
                end
            elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_GUILD_UPDATE" then
                if C_ChatInfo and C_ChatInfo.RegisterAddonPrefix then
                    pcall(C_ChatInfo.RegisterAddonPrefix, "GuildManager")
                elseif RegisterAddonMessagePrefix then
                    pcall(RegisterAddonMessagePrefix, "GuildManager")
                end
                self:hookInviteAPIs()
                if IsInGuild and IsInGuild() then
                    self._guildRosterService:requestRosterUpdate()
                    if GetNumGuildMembers and GetNumGuildMembers() > 0 then
                        self._guildRosterService:scanRoster()
                    end
                end
                self:registerAllHooks()
            elseif event == "GUILD_ROSTER_UPDATE" then
                if not self._debounceTimer then
                    if C_Timer and C_Timer.After then
                        self._debounceTimer = C_Timer.After(0.3, function()
                            self._debounceTimer = nil
                            if IsInGuild and IsInGuild() then
                                self._guildRosterService:scanRoster()
                            end
                        end)
                    else
                        if IsInGuild and IsInGuild() then
                            self._guildRosterService:scanRoster()
                        end
                    end
                end
            elseif event == "CHAT_MSG_SYSTEM" then
                self:handleSystemChatMessage(arg1)
            elseif event == "CHAT_MSG_ADDON" then
                self:handleAddonChatMessage(arg1, arg2, arg3, arg4)
            elseif event == "GUILD_EVENT_LOG_UPDATE" then
                self:checkGuildEventLog()
            end
        end)
    end

    -- Registra todos os ganchos nos painéis disponíveis
    self:registerAllHooks()

    -- Comando de chat /gm
    SLASH_GUILDMANAGER1 = "/gm"
    SLASH_GUILDMANAGER2 = "/guildmanager"
    SlashCmdList["GUILDMANAGER"] = function()
        if IsInGuild and IsInGuild() then
            local count = self._guildRosterService:scanRoster()
            print(string.format("|cff00ff00[GuildManager]|r Roster sincronizado! %d membro(s) no banco.", count))

            -- Tenta abrir a interface de guilda apropriada
            if CommunitiesFrame and ToggleCommunitiesFrame then
                ToggleCommunitiesFrame()
            elseif ToggleFriendsFrame then
                ToggleFriendsFrame(3)
            end
        else
            print("|cffff0000[GuildManager]|r Você não está em uma guilda.")
        end
    end
end

--- Tenta registrar os ganchos em todas as interfaces de guilda conhecidas do WoW
--- (CommunitiesFrame, GuildFrame, FriendsFrame e GameTooltip).
function MemberController:registerAllHooks()
    self:hookGameTooltip()
    self:hookCommunitiesUI()
    self:hookClassicGuildFrame()
    self:hookInviteAPIs()
end

--- Registra hooks universais no GameTooltip.
--- Quando o jogador passa o mouse sobre qualquer membro da guilda (seja na interface moderna ou clássica),
--- o GameTooltip é exibido e dispara a abertura da nossa tela de membro.
function MemberController:hookGameTooltip()
    if self._tooltipHooked or not GameTooltip then
        return
    end
    self._tooltipHooked = true

    GameTooltip:HookScript("OnShow", function(tooltip)
        if self._memberView:isLocked() then
            return
        end

        local owner = tooltip:GetOwner()
        if not owner or not self:isGuildRelatedFrame(owner) then
            return
        end

        -- 1. Verifica se o botão possui memberInfo (CommunitiesFrame)
        local memberInfo = owner.memberInfo or (owner.GetMemberInfo and owner:GetMemberInfo())
        if memberInfo and memberInfo.name then
            self:handleMemberHoverByName(memberInfo.name)
            return
        end

        -- 2. Verifica se o botão possui guildIndex (GuildFrame clássico)
        local guildIndex = self:getButtonRosterIndex(owner)
        if guildIndex and guildIndex > 0 then
            self:handleMemberHover(guildIndex)
            return
        end

        -- 3. Lê o nome diretamente do texto do Tooltip
        local line1 = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
        if line1 and line1 ~= "" then
            local clean = line1:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^[^-]+")
            if clean and clean ~= "" and not clean:find("\n") then
                self:handleMemberHoverByName(clean)
            end
        end
    end)

    GameTooltip:HookScript("OnHide", function()
        if not self._memberView:isLocked() then
            self._memberView:hide()
        end
    end)
end

--- Verifica se um determinado frame pertence à interface de guilda ou comunidades.
---@param frame table
---@return boolean
function MemberController:isGuildRelatedFrame(frame)
    local current = frame
    for _ = 1, 6 do
        if not current then break end
        local name = current:GetName() or ""
        if name:find("Guild") or name:find("Communities") or name:find("FriendsFrame") then
            return true
        end
        current = current:GetParent()
    end
    return false
end

--- Registra hooks para a interface moderna de Guildas/Comunidades (CommunitiesFrame).
function MemberController:hookCommunitiesUI()
    if not CommunitiesFrame then
        return
    end

    if not self._communitiesHooked then
        self._communitiesHooked = true

        CommunitiesFrame:HookScript("OnShow", function()
            self:registerAllHooks()
            if IsInGuild and IsInGuild() then
                self._guildRosterService:scanRoster()
            end
        end)

        CommunitiesFrame:HookScript("OnHide", function()
            if not self._memberView:isLocked() then
                self._memberView:hide()
            end
        end)

        -- Ao abrir os detalhes do membro ao clicar
        if CommunitiesFrame.OpenGuildMemberDetailFrame then
            hooksecurefunc(CommunitiesFrame, "OpenGuildMemberDetailFrame", function(_, _, memberInfo)
                if memberInfo and memberInfo.name then
                    self:handleMemberClickByName(memberInfo.name)
                end
            end)
        end
    end

    -- Hook na configuração das linhas da lista de membros do CommunitiesFrame
    if CommunitiesMemberListEntry_SetUp then
        hooksecurefunc("CommunitiesMemberListEntry_SetUp", function(button, memberInfo)
            if button and not button._gmHooked then
                button._gmHooked = true

                button:HookScript("OnEnter", function(b)
                    local info = b.memberInfo or (b.GetMemberInfo and b:GetMemberInfo())
                    if info and info.name then
                        self:handleMemberHoverByName(info.name)
                    end
                end)

                button:HookScript("OnLeave", function()
                    self:handleMemberLeave()
                end)

                button:HookScript("OnClick", function(b)
                    local info = b.memberInfo or (b.GetMemberInfo and b:GetMemberInfo())
                    if info and info.name then
                        self:handleMemberClickByName(info.name)
                    end
                end)
            end
        end)
    end
end

--- Registra hooks para a interface clássica de guilda (GuildFrame / FriendsFrame).
function MemberController:hookClassicGuildFrame()
    if GuildFrame and not self._guildFrameHooked then
        self._guildFrameHooked = true

        GuildFrame:HookScript("OnShow", function()
            self:hookGuildRosterButtons()
            if IsInGuild and IsInGuild() then
                self._guildRosterService:scanRoster()
            end
        end)

        GuildFrame:HookScript("OnHide", function()
            if not self._memberView:isLocked() then
                self._memberView:hide()
            end
        end)
    end

    if FriendsFrame and not self._friendsFrameHooked then
        self._friendsFrameHooked = true

        FriendsFrame:HookScript("OnShow", function()
            self:hookGuildRosterButtons()
        end)

        FriendsFrame:HookScript("OnHide", function()
            if not self._memberView:isLocked() then
                self._memberView:hide()
            end
        end)
    end

    if GuildFrame_Update then
        hooksecurefunc("GuildFrame_Update", function()
            self:hookGuildRosterButtons()
        end)
    end

    if SetGuildRosterSelection then
        hooksecurefunc("SetGuildRosterSelection", function(index)
            if index and index > 0 then
                self:handleMemberClick(index)
            end
        end)
    end

    -- Detalhes ao clicar no membro clássico
    if GuildMemberDetailFrame and not self._detailFrameHooked then
        self._detailFrameHooked = true
        GuildMemberDetailFrame:HookScript("OnShow", function(frame)
            local index = GetGuildRosterSelection and GetGuildRosterSelection()
            if index and index > 0 then
                self:handleMemberClick(index)
            end
            if frame and frame.Hide then
                frame:Hide()
            end
        end)
    end

    self:hookGuildRosterButtons()
end

--- Hooka os botões visíveis de membros do painel clássico da Blizzard.
function MemberController:hookGuildRosterButtons()
    for i = 1, 25 do
        local btn = _G["GuildFrameButton" .. i]
        if btn and not btn._gmHooked then
            btn._gmHooked = true

            btn:HookScript("OnEnter", function(b)
                local index = self:getButtonRosterIndex(b)
                if index and index > 0 then
                    self:handleMemberHover(index)
                end
            end)

            btn:HookScript("OnLeave", function()
                self:handleMemberLeave()
            end)

            btn:HookScript("OnClick", function(b)
                local index = self:getButtonRosterIndex(b)
                if index and index > 0 then
                    self:handleMemberClick(index)
                end
            end)
        end

        local statusBtn = _G["GuildFrameGuildStatusButton" .. i]
        if statusBtn and not statusBtn._gmHooked then
            statusBtn._gmHooked = true

            statusBtn:HookScript("OnEnter", function(b)
                local index = self:getButtonRosterIndex(b)
                if index and index > 0 then
                    self:handleMemberHover(index)
                end
            end)

            statusBtn:HookScript("OnLeave", function()
                self:handleMemberLeave()
            end)

            statusBtn:HookScript("OnClick", function(b)
                local index = self:getButtonRosterIndex(b)
                if index and index > 0 then
                    self:handleMemberClick(index)
                end
            end)
        end
    end
end

--- Obtém o índice do membro a partir do botão da lista da guilda.
---@param button table
---@return number|nil
function MemberController:getButtonRosterIndex(button)
    if not button then return nil end

    if button.guildIndex and button.guildIndex > 0 then
        return button.guildIndex
    end

    local offset = 0
    if FauxScrollFrame_GetOffset and GuildListScrollFrame then
        offset = FauxScrollFrame_GetOffset(GuildListScrollFrame) or 0
    end

    local id = button:GetID() or 0
    local index = offset + id

    return index > 0 and index or nil
end

--- Trata a ação de passar o cursor sobre um membro pelo índice.
---@param index number
function MemberController:handleMemberHover(index)
    if not self._memberView or self._memberView:isLocked() then
        return
    end

    local member = self:resolveMemberByIndex(index)
    if member then
        self._memberView:showMember(member, false)
    end
end

--- Trata a ação de passar o cursor sobre um membro pelo nome.
---@param name string
function MemberController:handleMemberHoverByName(name)
    if not name or name == "" or not self._memberView or self._memberView:isLocked() then
        return
    end

    local member = self:resolveMemberByName(name)
    if member then
        self._memberView:showMember(member, false)
    end
end

--- Trata a ação de clicar em um membro pelo índice (trava a janela).
---@param index number
function MemberController:handleMemberClick(index)
    if not self._memberView then
        return
    end

    local member = self:resolveMemberByIndex(index)
    if member then
        self._memberView:showMember(member, true)
    end
end

--- Trata a ação de clicar em um membro pelo nome (trava a janela).
---@param name string
function MemberController:handleMemberClickByName(name)
    if not self._memberView or not name or name == "" then
        return
    end

    local member = self:resolveMemberByName(name)
    if member then
        self._memberView:showMember(member, true)
    end
end

--- Trata a saída do cursor de um membro na lista da guilda.
function MemberController:handleMemberLeave()
    if not self._memberView or self._memberView:isLocked() then
        return
    end

    self._memberView:hide()
end

--- Localiza ou processa sob demanda a entidade Member correspondente ao índice.
---@param index number
---@return Member|nil
function MemberController:resolveMemberByIndex(index)
    if not index or index <= 0 or not GetGuildRosterInfo then
        return nil
    end

    local name = GetGuildRosterInfo(index)
    if not name or name == "" then
        return nil
    end

    local cleanName = name
    if Ambiguate then
        local amb = Ambiguate(name, "none")
        if amb and amb ~= "" then
            cleanName = amb
        end
    end

    local member = self._memberService:getMember(cleanName)
    if not member then
        member = self._guildRosterService:getAndProcessMember(index)
    end

    return member
end

--- Localiza ou processa sob demanda a entidade Member correspondente ao nome.
---@param targetName string
---@return Member|nil
function MemberController:resolveMemberByName(targetName)
    if not targetName or targetName == "" then
        return nil
    end

    local cleanName = targetName
    if Ambiguate then
        local amb = Ambiguate(targetName, "none")
        if amb and amb ~= "" then
            cleanName = amb
        end
    end
    cleanName = cleanName:match("^[^-]+") or cleanName

    -- 1. Tenta buscar no banco de dados existente
    local member = self._memberService:getMember(cleanName) or self._memberService:getMember(targetName)
    if member then
        return member
    end

    -- 2. Tenta encontrar pelo índice na API clássica
    if GetNumGuildMembers and GetGuildRosterInfo then
        local num = GetNumGuildMembers() or 0
        local targetLower = cleanName:lower()
        for i = 1, num do
            local name = GetGuildRosterInfo(i)
            if name then
                local c = name
                if Ambiguate then
                    local a = Ambiguate(name, "none")
                    if a and a ~= "" then c = a end
                end
                c = c:match("^[^-]+") or c
                if c:lower() == targetLower or name:lower() == targetLower then
                    return self._guildRosterService:getAndProcessMember(i)
                end
            end
        end
    end

    -- 3. Tenta encontrar na API moderna C_Club (se disponível)
    if C_Club and C_Club.GetGuildClubId then
        local clubId = C_Club.GetGuildClubId()
        if clubId and C_Club.GetClubMembers then
            local memberIds = C_Club.GetClubMembers(clubId) or {}
            local targetLower = cleanName:lower()
            for _, memberId in ipairs(memberIds) do
                local info = C_Club.GetMemberInfo(clubId, memberId)
                if info and info.name then
                    local base = info.name:match("^[^-]+") or info.name
                    if base:lower() == targetLower or info.name:lower() == targetLower then
                        local rosterData = {
                            name = base,
                            rankName = info.guildRank or "",
                            rankIndex = info.guildRankOrder or 0,
                            level = info.level or 1,
                            classDisplayName = "",
                            zone = info.zone or "",
                            publicNote = info.memberNote or "",
                            officerNote = info.officerNote or "",
                            isOnline = (info.presence == 1),
                            status = 0,
                            class = "",
                            achievementPoints = 0,
                            achievementRank = 0,
                            repStanding = 0,
                            guid = info.guid or "",
                            isInGuild = true,
                        }
                        return self._memberService:processRosterMember(rosterData)
                    end
                end
            end
        end
    end

    return nil
end

--- Registra hooks nas funções oficiais de convite da Blizzard (GuildInvite e C_GuildInfo.Invite).
function MemberController:hookInviteAPIs()
    if GuildInvite and not self._guildInviteHooked then
        self._guildInviteHooked = true
        hooksecurefunc("GuildInvite", function(name)
            if name and name ~= "" then
                local myName = UnitName and UnitName("player") or ""
                self:recordPendingInvite(name, myName)
            end
        end)
    end

    if C_GuildInfo and C_GuildInfo.Invite and not self._cGuildInviteHooked then
        self._cGuildInviteHooked = true
        hooksecurefunc(C_GuildInfo, "Invite", function(name)
            if name and name ~= "" then
                local myName = UnitName and UnitName("player") or ""
                self:recordPendingInvite(name, myName)
            end
        end)
    end
end

--- Resolve o nome completo (primeiro nome e sobrenome) do jogador local (suporte ao WoW Forever).
---@return string
function MemberController:resolvePlayerFullName()
    local myName = UnitName and UnitName("player") or ""
    if myName == "" then return "" end

    -- 1. Tenta resolver via MemberService se já estiver no banco
    if self._memberService and self._memberService.resolveRecruiterFullName then
        local resolved = self._memberService:resolveRecruiterFullName(myName)
        if resolved and resolved ~= "" and resolved ~= myName then
            return resolved
        end
    end

    -- 2. Tenta buscar diretamente no Roster da guilda
    if GetNumGuildMembers and GetGuildRosterInfo then
        local num = GetNumGuildMembers() or 0
        local myLower = myName:lower()
        for i = 1, num do
            local gName = GetGuildRosterInfo(i)
            if gName then
                local clean = gName:match("^[^-]+") or gName
                clean = clean:match("^%s*(.-)%s*$") or clean
                local first = clean:match("^(%S+)") or clean
                if first:lower() == myLower or clean:lower() == myLower then
                    return clean
                end
            end
        end
    end

    return myName
end

local function getNow()
    if GetTime then return GetTime() end
    if time then return time() end
    if os and os.time then return os.time() end
    return 0
end

--- Registra um convite emitido em memória e o transmite aos demais membros da guilda.
---@param targetName string @Nome do jogador convidado
---@param recruiterName string @Nome de quem emitiu o convite
function MemberController:recordPendingInvite(targetName, recruiterName)
    local cleanTarget = self:sanitizeCharacterName(targetName)
    if not cleanTarget or cleanTarget == "" then
        return
    end

    local recruiter = self:sanitizeCharacterName(recruiterName)
    if not recruiter or recruiter == "" then
        recruiter = self:resolvePlayerFullName()
    elseif self._memberService and self._memberService.resolveRecruiterFullName then
        recruiter = self._memberService:resolveRecruiterFullName(recruiter)
    end

    local currentTime = getNow()
    self._pendingInvites[cleanTarget:lower()] = {
        target = cleanTarget,
        recruiter = recruiter,
        time = currentTime,
    }

    local myName = UnitName and UnitName("player") or ""
    if recruiter == self:sanitizeCharacterName(myName) then
        self._lastPlayerInvite = {
            target = cleanTarget,
            recruiter = recruiter,
            time = currentTime,
        }
        self:broadcastInvite(cleanTarget, recruiter)
    end
end

--- Transmite a informação do convite via canal de AddOn da guilda para sincronização entre membros.
---@param targetName string
---@param recruiterName string
function MemberController:broadcastInvite(targetName, recruiterName)
    if not IsInGuild or not IsInGuild() then
        return
    end
    local payload = string.format("INVITE:%s:%s", targetName, recruiterName)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        pcall(C_ChatInfo.SendAddonMessage, "GuildManager", payload, "GUILD")
    elseif SendAddonMessage then
        pcall(SendAddonMessage, "GuildManager", payload, "GUILD")
    end
end

--- Processa mensagens do sistema procurando por novos membros recrutados (ERR_GUILD_JOIN_S)
--- e convites emitidos (ERR_GUILD_INVITE_S).
---@param message string
function MemberController:handleSystemChatMessage(message)
    if not message or type(message) ~= "string" or message == "" then
        return
    end

    -- 1. Verifica se um novo membro ingressou na guilda
    local joinedMemberName = self:matchGuildJoin(message)
    if joinedMemberName then
        self:handleGuildJoin(joinedMemberName)
        return
    end

    -- 2. Verifica se um membro saiu ou foi expulso da guilda
    local leftMemberName = self:matchGuildLeave(message)
    if leftMemberName then
        self:handleGuildLeave(leftMemberName)
        return
    end

    -- 3. Verifica se o jogador local convidou alguém (confirmação do sistema)
    local invitedTarget = self:matchGuildInvite(message)
    if invitedTarget then
        local myName = UnitName and UnitName("player") or ""
        self:recordPendingInvite(invitedTarget, myName)
    end
end

--- Converte uma string formatada oficial da Blizzard (ex: ERR_GUILD_JOIN_S) em um padrão regex do Lua.
---@param templateStr string|nil
---@return string|nil
function MemberController:buildPatternFromTemplate(templateStr)
    if not templateStr or type(templateStr) ~= "string" or templateStr == "" then
        return nil
    end

    local s = templateStr
    -- Substitui marcadores posicionais (%1$s) e normais (%s) por token temporário seguro
    s = s:gsub("%%1%$s", "___GM_TARGET___")
    s = s:gsub("%%s", "___GM_TARGET___")

    -- Escapa caracteres mágicos do Lua: ^ $ ( ) % . [ ] * + - ?
    s = s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")

    -- Substitui o token temporário pelo grupo de captura
    s = s:gsub("___GM_TARGET___", "(.+)")

    return s
end

--- Normaliza e sanitiza o nome de um personagem, removendo códigos de cores, sufixos de reino e pontuação.
---@param rawName string
---@return string
function MemberController:sanitizeCharacterName(rawName)
    if not rawName or type(rawName) ~= "string" then
        return ""
    end

    local name = rawName:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
    name = name:gsub("[%.,!]+$", "") -- remove pontuação residual no final
    name = name:match("^%s*(.-)%s*$") or name -- trim

    if Ambiguate then
        local amb = Ambiguate(name, "none")
        if amb and amb ~= "" then
            name = amb
        end
    end

    name = name:match("^[^-]+") or name -- remove nome do reino se presente
    return name
end

--- Extrai o nome do novo membro usando prioritariamente a variável global ERR_GUILD_JOIN_S da Blizzard.
---@param message string
---@return string|nil
function MemberController:matchGuildJoin(message)
    if not message or type(message) ~= "string" or message == "" then
        return nil
    end

    local clean = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
    clean = clean:match("^%s*(.-)%s*$")

    -- 1. Melhor prática oficial: variável global ERR_GUILD_JOIN_S da Blizzard
    local blizzardPattern = self:buildPatternFromTemplate(_G.ERR_GUILD_JOIN_S)
    if blizzardPattern then
        local name = clean:match("^" .. blizzardPattern .. "$")
            or clean:match(blizzardPattern)
            or clean:match("^" .. blizzardPattern:gsub("%%%.$", "") .. "$")
            or clean:match(blizzardPattern:gsub("%%%.$", ""))
        if name and name ~= "" then
            return self:sanitizeCharacterName(name)
        end
    end

    -- 2. Fallbacks em PT-BR e EN-US caso a global da Blizzard não esteja carregada
    local fallbacks = {
        "^(.+) entrou para a guilda",
        "^(.+) entrou na guilda",
        "^(.+) ingressou na guilda",
        "^(.+) juntou%-se à guilda",
        "^(.+) has joined the guild",
    }
    for _, fb in ipairs(fallbacks) do
        local name = clean:match(fb)
        if name and name ~= "" then
            return self:sanitizeCharacterName(name)
        end
    end

    return nil
end

--- Extrai o nome do jogador convidado a partir da variável global ERR_GUILD_INVITE_S da Blizzard.
---@param message string
---@return string|nil
function MemberController:matchGuildInvite(message)
    if not message or type(message) ~= "string" or message == "" then
        return nil
    end

    local clean = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
    clean = clean:match("^%s*(.-)%s*$")

    -- 1. Variável global ERR_GUILD_INVITE_S da Blizzard
    local blizzardPattern = self:buildPatternFromTemplate(_G.ERR_GUILD_INVITE_S)
    if blizzardPattern then
        local target = clean:match("^" .. blizzardPattern .. "$")
            or clean:match(blizzardPattern)
            or clean:match("^" .. blizzardPattern:gsub("%%%.$", "") .. "$")
            or clean:match(blizzardPattern:gsub("%%%.$", ""))
        if target and target ~= "" then
            return self:sanitizeCharacterName(target)
        end
    end

    -- 2. Fallbacks em PT-BR e EN-US
    local inviteFallbacks = {
        "Você convidou (.+) para a guilda",
        "Você convidou (.+) para entrar na guilda",
        "You have invited (.+) to join the guild",
    }
    for _, fb in ipairs(inviteFallbacks) do
        local target = clean:match(fb)
        if target and target ~= "" then
            return self:sanitizeCharacterName(target)
        end
    end

    return nil
end

--- Extrai o nome do membro que saiu ou foi expulso da guilda a partir das mensagens do sistema da Blizzard.
---@param message string
---@return string|nil
function MemberController:matchGuildLeave(message)
    if not message or type(message) ~= "string" or message == "" then
        return nil
    end

    local clean = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
    clean = clean:match("^%s*(.-)%s*$")

    -- 1. Variável global ERR_GUILD_LEAVE_S ("%s has left the guild." / "%s saiu da guilda.")
    local leavePattern = self:buildPatternFromTemplate(_G.ERR_GUILD_LEAVE_S)
    if leavePattern then
        local name = clean:match("^" .. leavePattern .. "$")
            or clean:match(leavePattern)
            or clean:match("^" .. leavePattern:gsub("%%%.$", "") .. "$")
            or clean:match(leavePattern:gsub("%%%.$", ""))
        if name and name ~= "" then
            return self:sanitizeCharacterName(name)
        end
    end

    -- 2. Variável global ERR_GUILD_REMOVE_SS ("%s has kicked %s from the guild." / "%s removeu %s da guilda.")
    if _G.ERR_GUILD_REMOVE_SS then
        local removeTpl = _G.ERR_GUILD_REMOVE_SS
        local s = removeTpl:gsub("%%1%$s", "___GM_KICKER___"):gsub("%%2%$s", "___GM_TARGET___")
        if not s:find("___GM_TARGET___") then
            s = removeTpl:gsub("%%s", "___GM_KICKER___", 1):gsub("%%s", "___GM_TARGET___", 1)
        end
        s = s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        s = s:gsub("___GM_KICKER___", ".-"):gsub("___GM_TARGET___", "(.+)")
        local kicked = clean:match("^" .. s .. "$") or clean:match(s)
        if kicked and kicked ~= "" then
            return self:sanitizeCharacterName(kicked)
        end
    end

    -- 3. Fallbacks diretos em Português e Inglês
    local leaveFallbacks = {
        "^(.+) saiu da guilda",
        "^(.+) deixou a guilda",
        "^(.+) has left the guild",
        "^.- removeu (.+) da guilda",
        "^.- expulsou (.+) da guilda",
        "^.- has kicked (.+) from the guild",
    }
    for _, fb in ipairs(leaveFallbacks) do
        local name = clean:match(fb)
        if name and name ~= "" then
            return self:sanitizeCharacterName(name)
        end
    end

    return nil
end

--- Manipula a detecção da entrada de um novo membro na guilda, associando o recrutador correspondente.
---@param newMemberName string
function MemberController:handleGuildJoin(newMemberName)
    local cleanName = self:sanitizeCharacterName(newMemberName)
    if not cleanName or cleanName == "" then
        return
    end

    local lowerName = cleanName:lower()
    local recruiter = ""

    -- 1. Verifica se há convite pendente registrado
    if self._pendingInvites and self._pendingInvites[lowerName] then
        recruiter = self._pendingInvites[lowerName].recruiter or ""
        self._pendingInvites[lowerName] = nil
    elseif self._lastPlayerInvite and GetTime and (GetTime() - (self._lastPlayerInvite.time or 0) < 300) then
        if self._lastPlayerInvite.target:lower() == lowerName or self._lastPlayerInvite.target == "" then
            recruiter = self._lastPlayerInvite.recruiter or (UnitName and UnitName("player")) or ""
        end
    end

    -- 2. Se ainda não encontrado, verifica histórico recente
    if recruiter == "" and self._recentRecruits and self._recentRecruits[lowerName] then
        recruiter = self._recentRecruits[lowerName]
    end

    -- Registra no histórico recente e no serviço
    if recruiter ~= "" then
        self._recentRecruits[lowerName] = recruiter
        if self._memberService and self._memberService.setPendingRecruiter then
            self._memberService:setPendingRecruiter(cleanName, recruiter)
        end
    end

    -- 3. Atualiza ou cria a entidade no banco de dados imediatamente
    local today = (date and date("%Y-%m-%d")) or (os and os.date and os.date("%Y-%m-%d")) or ""
    local member = self._memberService:getMember(cleanName)

    if member then
        if recruiter ~= "" then
            member:setRecruiter(recruiter)
        end
        if not member:isInGuild() then
            member:setInGuild(true)
            member:setDateJoin(today)
        end
        self._memberService:saveMember(member)
    else
        local newMember = Member:new({
            name = cleanName,
            dateJoin = today,
            isInGuild = true,
            recruiter = recruiter,
            isMain = true,
        })
        self._memberService:saveMember(newMember)
    end

    -- 4. Notificação no chat com destaque visual
    if recruiter ~= "" then
        print(string.format("|cff00ff00[GuildManager]|r Novo membro recrutado: |cffffff00%s|r (Recrutador: |cff00bfff%s|r)", cleanName, recruiter))
    else
        print(string.format("|cff00ff00[GuildManager]|r Novo membro entrou na guilda: |cffffff00%s|r", cleanName))
    end

    -- Se a janela estiver aberta exibindo este membro, atualiza o botão do recrutador em tempo real
    if self._memberView and self._memberView._currentMember then
        local viewingName = self._memberView._currentMember:getName() or ""
        if viewingName:lower() == cleanName:lower() then
            if recruiter ~= "" then
                self._memberView._currentMember:setRecruiter(recruiter)
            end
            if self._memberView.updateRecruiterButtonVisual then
                self._memberView:updateRecruiterButtonVisual()
            end
        end
    end

    -- 5. Dispara sincronização do roster com a Blizzard
    if C_Timer and C_Timer.After then
        C_Timer.After(1.0, function()
            if IsInGuild and IsInGuild() then
                self._guildRosterService:requestRosterUpdate()
            end
        end)
    else
        self._guildRosterService:requestRosterUpdate()
    end

    -- 6. Consulta o log oficial de eventos da guilda caso o recrutador ainda não tenha sido definido
    if recruiter == "" and QueryGuildEventLog then
        pcall(QueryGuildEventLog)
    end
end

--- Manipula a saída de um membro da guilda.
--- Atualiza a entidade no banco de dados e desvincula imediatamente da lista de alts.
---@param memberName string
function MemberController:handleGuildLeave(memberName)
    local cleanName = self:sanitizeCharacterName(memberName)
    if not cleanName or cleanName == "" then
        return
    end

    local today = (date and date("%Y-%m-%d")) or (os and os.date and os.date("%Y-%m-%d")) or ""
    local member = self._memberService:getMember(cleanName)

    if member then
        member:setInGuild(false)
        member:setLastRank(member:getRankName())
        member:setDateLeft(today)
        member:setTimesLeft((member:getTimesLeft() or 0) + 1)
        self._memberService:saveMember(member)
    end

    -- Desvincula imediatamente da lista de alts
    local unlinked = self._memberService:unlinkMemberOnGuildLeave(cleanName)
    if unlinked then
        print(string.format("|cffff8800[GuildManager]|r %s saiu da guilda e foi desvinculado da lista de alts.", cleanName))
    else
        print(string.format("|cffff8800[GuildManager]|r %s saiu da guilda.", cleanName))
    end

    -- Se a janela estiver aberta exibindo o membro que saiu ou seus alts, atualiza o visual
    if self._memberView and self._memberView._frame and self._memberView._frame:IsShown() and self._memberView._currentMember then
        local currentName = self._memberView._currentMember:getName()
        local refreshed = self._memberService:getMember(currentName)
        if refreshed then
            self._memberView._currentMember = refreshed
        end
        if self._memberView.updateAltsVisual then
            self._memberView:updateAltsVisual()
        end
        if self._memberView.updateMainTagVisual then
            self._memberView:updateMainTagVisual(self._memberView._currentMember:isMain())
        end
        if self._memberView._altManagerFrame and self._memberView._altManagerFrame:IsShown() and self._memberView.refreshAltManager then
            self._memberView:refreshAltManager()
        end
    end

    -- Solicita atualização do roster
    if C_Timer and C_Timer.After then
        C_Timer.After(1.0, function()
            if IsInGuild and IsInGuild() then
                self._guildRosterService:requestRosterUpdate()
            end
        end)
    else
        self._guildRosterService:requestRosterUpdate()
    end
end

--- Trata mensagens recebidas de outros clientes do GuildManager via CHAT_MSG_ADDON.
---@param prefix string
---@param msg string
---@param channel string
---@param sender string
function MemberController:handleAddonChatMessage(prefix, msg, channel, sender)
    if prefix ~= "GuildManager" or type(msg) ~= "string" then
        return
    end

    if msg:find("^INVITE:") then
        local _, target, recruiter = strsplit(":", msg)
        if target and target ~= "" and recruiter and recruiter ~= "" then
            local cleanTarget = self:sanitizeCharacterName(target)
            local cleanRecruiter = self:sanitizeCharacterName(recruiter)
            local currentTime = getNow()
            self._pendingInvites[cleanTarget:lower()] = {
                target = cleanTarget,
                recruiter = cleanRecruiter,
                time = currentTime,
            }
        end
    end
end

--- Verifica o registro de eventos de guilda da Blizzard para associar recrutadores caso ainda ausentes.
function MemberController:checkGuildEventLog()
    if C_GuildInfo and C_GuildInfo.GetGuildEventLog then
        local success, logEntries = pcall(C_GuildInfo.GetGuildEventLog)
        if success and type(logEntries) == "table" then
            for _, entry in ipairs(logEntries) do
                if entry and (entry.type == "invite" or entry.type == 1) then
                    local recruit = entry.player2 or entry.name
                    local recruiter = entry.player1 or entry.sourceName
                    if recruit and recruiter and recruit ~= "" and recruiter ~= "" then
                        self:applyRecruiterIfEmpty(recruit, recruiter)
                    end
                end
            end
            return
        end
    end

    local getNum = GetNumGuildEvents or GetNumGuildEventLogEntries
    local getInfo = GetGuildEventInfo or GetGuildEventLogEntry
    if getNum and getInfo then
        local success, count = pcall(getNum)
        if success and type(count) == "number" and count > 0 then
            local limit = math.min(count, 15)
            for i = 1, limit do
                local s, eventType, p1, p2 = pcall(getInfo, i)
                if s and eventType and (eventType == "invite" or tostring(eventType):lower():find("invite")) then
                    local recruiter = p1
                    local recruit = p2
                    if recruit and recruiter and recruit ~= "" and recruiter ~= "" then
                        self:applyRecruiterIfEmpty(recruit, recruiter)
                    end
                end
            end
        end
    end
end

--- Atribui o recrutador ao membro caso o campo ainda esteja vazio.
---@param recruitName string
---@param recruiterName string
function MemberController:applyRecruiterIfEmpty(recruitName, recruiterName)
    local cleanRecruit = self:sanitizeCharacterName(recruitName)
    local cleanRecruiter = self:sanitizeCharacterName(recruiterName)
    if cleanRecruit == "" or cleanRecruiter == "" then
        return
    end

    local member = self._memberService:getMember(cleanRecruit)
    if member and member:getRecruiter() == "" then
        member:setRecruiter(cleanRecruiter)
        self._memberService:saveMember(member)
        print(string.format("|cff00ff00[GuildManager]|r Recrutador de |cffffff00%s|r atualizado pelo log: |cff00bfff%s|r", cleanRecruit, cleanRecruiter))
    end
end

-- Exportação/Alias para compatibilidade de nomenclatura em Core.lua
memberController = MemberController
