---@class AuditController
---@field private _memberService MemberService
---@field private _guildRosterService GuildRosterService
---@field private _auditView AuditView
AuditController = {}
AuditController.__index = AuditController

--- Obtém o timestamp sincronizado do servidor (ou relógio local como fallback)
---@return number
local function getCurrentTimestamp()
    if GetServerTime then
        local st = GetServerTime()
        if st and st > 0 then return st end
    end
    if time then
        local t = time()
        if t and t > 0 then return t end
    end
    if os and os.time then
        return os.time()
    end
    return 0
end

--- Construtor do Controller de auditoria de membros da guilda.
---@param memberService MemberService @Serviço de gerenciamento de membros
---@param guildRosterService GuildRosterService @Serviço de comunicação com o roster da Blizzard
---@param auditView AuditView @Camada de visualização da tela de auditoria
---@param logService LogService|nil @Serviço de logs (opcional)
---@return AuditController
function AuditController:new(memberService, guildRosterService, auditView, logService)
    local instance = setmetatable({}, self)

    instance._memberService = memberService
    instance._guildRosterService = guildRosterService
    instance._auditView = auditView
    instance._logService = logService

    return instance
end

--- Inicializa os comandos de chat e ouvintes de eventos para a tela de auditoria.
function AuditController:initHooks()
    -- Vincula o callback de atualização da View ao serviço
    if self._auditView and self._auditView.setOnRefreshCallback then
        self._auditView:setOnRefreshCallback(function()
            self:refreshAudit()
        end)
    end

    -- Vincula o callback de salvar alterações de membros vindas da modal de edição
    if self._auditView and self._auditView.setOnSaveCallback then
        self._auditView:setOnSaveCallback(function(member, fields)
            if not member or not self._memberService then
                return
            end

            local canOfficer = false
            if self._guildRosterService and self._guildRosterService.isPlayerOfficerOrLeader then
                canOfficer = self._guildRosterService:isPlayerOfficerOrLeader()
            elseif IsGuildLeader and IsGuildLeader() then
                canOfficer = true
            elseif CanEditOfficerNote and CanEditOfficerNote() then
                canOfficer = true
            end

            local hasChanged = false
            if canOfficer and fields.dateJoin ~= nil and member:getDateJoin() ~= fields.dateJoin then
                member:setDateJoin(fields.dateJoin)
                hasChanged = true
            end
            if fields.birthday ~= nil and member:getBirthday() ~= fields.birthday then
                member:setBirthday(fields.birthday)
                hasChanged = true
            end
            if fields.customNote ~= nil then
                member:setCustomNote(fields.customNote)
            end
            if canOfficer and fields.recruiter ~= nil and member:getRecruiter() ~= fields.recruiter then
                local oldRecruiter = member:getRecruiter() or ""
                member:setRecruiter(fields.recruiter)
                hasChanged = true
                if oldRecruiter ~= fields.recruiter and self._logService and self._logService.updateRecruiterForMember then
                    self._logService:updateRecruiterForMember(member:getName(), fields.recruiter)
                end
            end

            if hasChanged then
                member:setCustomDataTimestamp(getCurrentTimestamp())
            end

            self._memberService:saveMember(member)
            self:refreshAudit()
        end)
    end

    -- Ouvinte de eventos de atualização do roster para manter a tela sincronizada quando visível
    if not self._eventFrame then
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
        eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
        eventFrame:SetScript("OnEvent", function(_, event)
            if self._auditView and self._auditView.isShown and self._auditView:isShown() then
                self:refreshAudit()
            end
        end)
        self._eventFrame = eventFrame
    end

    -- Comando de chat /gmaudit e /guildmanageraudit
    SLASH_GUILDMANAGERAUDIT1 = "/gmaudit"
    SLASH_GUILDMANAGERAUDIT2 = "/guildmanageraudit"
    SlashCmdList["GUILDMANAGERAUDIT"] = function()
        self:toggle()
    end
end

--- Verifica se uma entidade Member pertence ao roster oficial ativo da Blizzard.
---@param member Member
---@param activeRosterNames table<string, boolean>|nil
---@param activeRosterGuids table<string, boolean>|nil
---@return boolean
local function isMemberInActiveRoster(member, activeRosterNames, activeRosterGuids)
    if not member then return false end

    -- 1. Verificação por GUID (100% único e imutável)
    local guid = member:getGuid()
    if guid and guid ~= "" and activeRosterGuids and activeRosterGuids[guid] then
        return true
    end

    if not activeRosterNames then return false end

    -- 2. Verificação por Nome exato e minúsculo
    local name = member:getName() or ""
    if name ~= "" then
        if activeRosterNames[name] or activeRosterNames[name:lower()] then
            return true
        end

        -- 3. Verificação por Nome base sem reino
        local base = name:match("^[^-]+") or name
        base = base:match("^%s*(.-)%s*$") or base
        if base ~= "" and (activeRosterNames[base] or activeRosterNames[base:lower()]) then
            return true
        end
    end

    return false
end

--- Atualiza os dados exibidos na View buscando apenas os membros ativos pertencentes à guilda.
--- Ex-membros (jogadores que saíram ou foram expulsos) são rigorosamente excluídos da visualização.
function AuditController:refreshAudit()
    if not self._memberService or not self._auditView then
        return
    end

    if IsInGuild and IsInGuild() then
        if self._guildRosterService and self._guildRosterService.scanRoster then
            self._guildRosterService:scanRoster()
        end
    end

    local activeGuildMembers = {}
    local seenMembers = {}

    -- 1. Fonte primária e incontestável: lista de membros ativos processados diretamente da API da Blizzard
    local rosterMembers = self._guildRosterService and self._guildRosterService.getActiveMemberList and self._guildRosterService:getActiveMemberList()

    if rosterMembers and #rosterMembers > 0 then
        for _, member in ipairs(rosterMembers) do
            local rankName = member:getRankName() or ""
            if member:isInGuild() and rankName ~= "" and rankName ~= "-" then
                local guid = member:getGuid() or ""
                local name = (member:getName() or ""):lower()
                local key = (guid ~= "") and guid or name
                if key ~= "" and not seenMembers[key] then
                    seenMembers[key] = true
                    table.insert(activeGuildMembers, member)
                end
            end
        end
    else
        -- 2. Fallback caso a API da Blizzard ainda não tenha retornado dados nesta sessão
        if self._guildRosterService and self._guildRosterService.requestRosterUpdate then
            self._guildRosterService:requestRosterUpdate()
        end

        local all = self._memberService:getAllMembers() or {}
        local activeRosterNames = self._guildRosterService and self._guildRosterService.getActiveRosterNames and self._guildRosterService:getActiveRosterNames()
        local activeRosterGuids = self._guildRosterService and self._guildRosterService.getActiveRosterGuids and self._guildRosterService:getActiveRosterGuids()
        local hasRosterFilter = (activeRosterNames and next(activeRosterNames) ~= nil)

        for _, member in ipairs(all) do
            local rankName = member:getRankName() or ""
            -- Exige obrigatoriamente que o membro tenha status ativo e cargo válido da Blizzard (nunca Cargo: -)
            if member:isInGuild() and rankName ~= "" and rankName ~= "-" then
                if hasRosterFilter then
                    if isMemberInActiveRoster(member, activeRosterNames, activeRosterGuids) then
                        local guid = member:getGuid() or ""
                        local name = (member:getName() or ""):lower()
                        local key = (guid ~= "") and guid or name
                        if key ~= "" and not seenMembers[key] then
                            seenMembers[key] = true
                            table.insert(activeGuildMembers, member)
                        end
                    end
                else
                    local guid = member:getGuid() or ""
                    local name = (member:getName() or ""):lower()
                    local key = (guid ~= "") and guid or name
                    if key ~= "" and not seenMembers[key] then
                        seenMembers[key] = true
                        table.insert(activeGuildMembers, member)
                    end
                end
            end
        end
    end

    self._auditView:setMembers(activeGuildMembers)
end

--- Abre a tela de auditoria e recarrega os dados.
function AuditController:show()
    if not IsInGuild or not IsInGuild() then
        print("|cffff0000[GuildManager]|r Você não está em uma guilda.")
        return
    end

    if self._guildRosterService and self._guildRosterService.requestRosterUpdate then
        self._guildRosterService:requestRosterUpdate()
    end

    self:refreshAudit()
    if self._auditView then
        self._auditView:show()
    end
end

--- Fecha a tela de auditoria.
function AuditController:hide()
    if self._auditView then
        self._auditView:hide()
    end
end

--- Alterna a visibilidade da tela de auditoria.
function AuditController:toggle()
    if not self._auditView then
        return
    end

    if self._auditView:isShown() then
        self:hide()
    else
        self:show()
    end
end

-- Exportação/Alias de compatibilidade
auditController = AuditController
