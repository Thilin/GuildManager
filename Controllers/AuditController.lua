---@class AuditController
---@field private _memberService MemberService
---@field private _guildRosterService GuildRosterService
---@field private _auditView AuditView
AuditController = {}
AuditController.__index = AuditController

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

            if fields.dateJoin ~= nil then
                member:setDateJoin(fields.dateJoin)
            end
            if fields.birthday ~= nil then
                member:setBirthday(fields.birthday)
            end
            if fields.customNote ~= nil then
                member:setCustomNote(fields.customNote)
            end
            if fields.recruiter ~= nil then
                local oldRecruiter = member:getRecruiter() or ""
                member:setRecruiter(fields.recruiter)
                if oldRecruiter ~= fields.recruiter and self._logService and self._logService.updateRecruiterForMember then
                    self._logService:updateRecruiterForMember(member:getName(), fields.recruiter)
                end
            end

            self._memberService:saveMember(member)
            self:refreshAudit()
        end)
    end

    -- Comando de chat /gmaudit e /guildmanageraudit
    SLASH_GUILDMANAGERAUDIT1 = "/gmaudit"
    SLASH_GUILDMANAGERAUDIT2 = "/guildmanageraudit"
    SlashCmdList["GUILDMANAGERAUDIT"] = function()
        self:toggle()
    end
end

--- Atualiza os dados exibidos na View buscando apenas os membros ativos pertencentes à guilda.
function AuditController:refreshAudit()
    if not self._memberService or not self._auditView then
        return
    end

    if IsInGuild and IsInGuild() then
        if self._guildRosterService and self._guildRosterService.scanRoster then
            self._guildRosterService:scanRoster()
        end
    end

    local all = self._memberService:getAllMembers() or {}
    local activeGuildMembers = {}
    local activeRosterNames = self._guildRosterService and self._guildRosterService.getActiveRosterNames and self._guildRosterService:getActiveRosterNames()
    local hasRosterFilter = (activeRosterNames and next(activeRosterNames) ~= nil)

    for _, member in ipairs(all) do
        local mName = member:getName()
        local mLower = (mName or ""):lower()

        if hasRosterFilter then
            -- Se temos a lista ativa direta da Blizzard, quem não está no roster NÃO pertence mais à guilda!
            if activeRosterNames[mName] or activeRosterNames[mLower] then
                if not member:isInGuild() then
                    member:setInGuild(true)
                    self._memberService:saveMember(member)
                end
                table.insert(activeGuildMembers, member)
            else
                -- Membro ausente no roster oficial da Blizzard: desativa e desvincula dos alts
                if member:isInGuild() then
                    member:setInGuild(false)
                    self._memberService:unlinkMemberOnGuildLeave(mName)
                    self._memberService:saveMember(member)
                end
            end
        else
            -- Fallback caso scan do roster não esteja disponível no momento
            if member:isInGuild() then
                table.insert(activeGuildMembers, member)
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
