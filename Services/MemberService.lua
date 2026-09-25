---@class MemberService
---@field private _repository MemberRepository
MemberService = {}
MemberService.__index = MemberService

--- Construtor do serviço de membros.
---@param repository MemberRepository @Instância do repositório de membros
---@return MemberService
function MemberService:new(repository)
    local instance = setmetatable({}, self)
    instance._repository = repository
    instance._pendingRecruiters = {}
    return instance
end

--- Registra um recrutador pendente na memória do serviço.
---@param memberName string @Nome do membro
---@param recruiterName string @Nome de quem o recrutou
function MemberService:setPendingRecruiter(memberName, recruiterName)
    if not memberName or memberName == "" or not recruiterName or recruiterName == "" then return end
    self._pendingRecruiters = self._pendingRecruiters or {}
    self._pendingRecruiters[memberName:lower()] = recruiterName
end

--- Obtém o recrutador pendente registrado para o jogador.
---@param memberName string @Nome do membro
---@return string|nil
function MemberService:getPendingRecruiter(memberName)
    if not memberName or not self._pendingRecruiters then return nil end
    return self._pendingRecruiters[memberName:lower()]
end

--- Define e persiste o recrutador de um membro.
---@param memberName string @Nome do membro
---@param recruiterName string @Nome de quem o recrutou
---@return Member|nil
function MemberService:setMemberRecruiter(memberName, recruiterName)
    if not memberName or memberName == "" then return nil end
    local member = self._repository:findByName(memberName)
    if member then
        member:setRecruiter(recruiterName)
        self._repository:save(member)
        return member
    end
    return nil
end

--- Resolve o nome completo (nome e sobrenome) de um recrutador buscando no repositório.
---@param recruiterName string
---@return string
function MemberService:resolveRecruiterFullName(recruiterName)
    if not recruiterName or recruiterName == "" then return "" end
    if recruiterName:find("%s") then
        local exact = self._repository:findByName(recruiterName)
        if exact then return exact:getName() end
    end
    local recLower = recruiterName:lower()
    local all = self._repository:findAll()
    for _, m in ipairs(all) do
        local mName = m:getName() or ""
        local first = mName:match("^(%S+)") or mName
        if first:lower() == recLower or mName:lower() == recLower then
            return mName
        end
    end
    return recruiterName
end

--- Processa os dados de um membro obtidos do roster da Blizzard.
--- Se o membro já existir no banco, atualiza os dados nativos preservando informações customizadas.
--- Se for um novo membro, instancia a entidade Member, define a data de entrada e persiste.
---@param rosterData table @Dados brutos normalizados da API Blizzard
---@return Member|nil @Retorna a entidade Member processada e salva
function MemberService:processRosterMember(rosterData)
    if not rosterData or not rosterData.name or rosterData.name == "" then
        return nil
    end

    local member = self._repository:findByName(rosterData.name)
    local pendingRecruiter = self:getPendingRecruiter(rosterData.name)

    if member then
        -- Membro já existente: atualiza dados dinâmicos da API
        member:updateFromRoster(rosterData)

        -- Se o membro ainda não tiver recrutador registrado, associa o recrutador pendente ou vindo dos dados
        if member:getRecruiter() == "" then
            if pendingRecruiter and pendingRecruiter ~= "" then
                member:setRecruiter(self:resolveRecruiterFullName(pendingRecruiter))
            elseif rosterData.recruiter and rosterData.recruiter ~= "" then
                member:setRecruiter(self:resolveRecruiterFullName(rosterData.recruiter))
            end
        else
            -- Se o recrutador atual possui apenas o primeiro nome (sem sobrenome), tenta atualizar para o nome completo
            local curRec = member:getRecruiter()
            if not curRec:find("%s") then
                local full = self:resolveRecruiterFullName(curRec)
                if full ~= curRec then
                    member:setRecruiter(full)
                end
            end
        end
    else
        -- Novo membro detectado: define data de entrada atual caso não definida
        if not rosterData.dateJoin or rosterData.dateJoin == "" then
            rosterData.dateJoin = date("%Y-%m-%d")
        end
        local rec = rosterData.recruiter or ""
        if pendingRecruiter and pendingRecruiter ~= "" then
            rec = pendingRecruiter
        end
        if rec ~= "" then
            rec = self:resolveRecruiterFullName(rec)
        end
        rosterData.recruiter = rec
        rosterData.isInGuild = true
        member = Member:new(rosterData)
    end

    self._repository:save(member)
    return member
end

--- Reconcilia os membros do banco com os membros atualmente presentes no roster.
--- Identifica membros que saíram da guilda e atualiza seus status.
---@param activeRosterNames table<string, boolean> @Tabela hash com nomes dos membros ativos na guilda
function MemberService:reconcileGuildMembers(activeRosterNames)
    if type(activeRosterNames) ~= "table" then
        return
    end

    local allMembers = self._repository:findAll()
    local today = (date and date("%Y-%m-%d")) or (os and os.date and os.date("%Y-%m-%d")) or ""

    for _, member in ipairs(allMembers) do
        local memberName = member:getName()
        local nameLower = (memberName or ""):lower()
        if member:isInGuild() and not activeRosterNames[memberName] and not activeRosterNames[nameLower] then
            -- Membro saiu da guilda
            member:setInGuild(false)
            member:setLastRank(member:getRankName())
            member:setDateLeft(today)
            member:setTimesLeft((member:getTimesLeft() or 0) + 1)
            self._repository:save(member)

            -- Desvincula imediatamente da lista de alts ao sair da guilda
            self:unlinkMemberOnGuildLeave(memberName)
        end
    end
end

--- Retorna um membro pelo nome.
---@param name string
---@return Member|nil
function MemberService:getMember(name)
    return self._repository:findByName(name)
end

--- Retorna um membro pelo GUID do personagem.
---@param guid string
---@return Member|nil
function MemberService:getMemberByGuid(guid)
    if not guid or guid == "" then return nil end
    return self._repository:findByGuid(guid)
end

--- Retorna todos os membros persistidos.
---@return Member[]
function MemberService:getAllMembers()
    return self._repository:findAll()
end

--- Salva um membro diretamente através do repositório.
---@param member Member
---@return boolean
function MemberService:saveMember(member)
    return self._repository:save(member)
end

--- Retorna todas as entidades Member pertencentes ao mesmo grupo de alts do membro fornecido (incluindo o próprio membro).
---@param member Member
---@return Member[]
function MemberService:getAltFamily(member)
    if not member then return {} end
    local rootMember = self._repository:findByName(member:getName()) or member
    local familyMap = {}
    local familyList = {}

    local function addMemberToFamily(m)
        if not m then return end
        local nameLower = (m:getName() or ""):lower()
        if nameLower ~= "" and not familyMap[nameLower] then
            familyMap[nameLower] = m
            table.insert(familyList, m)
            for _, altName in ipairs(m:getAlts() or {}) do
                local altMember = self._repository:findByName(altName)
                if not altMember then
                    for _, ex in ipairs(self._repository:findAll()) do
                        if (ex:getName() or ""):lower() == altName:lower() then
                            altMember = ex
                            break
                        end
                    end
                end
                if not altMember then
                    altMember = Member:new({ name = altName, isMain = false })
                end
                if altMember and not familyMap[(altMember:getName() or ""):lower()] then
                    addMemberToFamily(altMember)
                end
            end
        end
    end

    addMemberToFamily(rootMember)
    return familyList
end

--- Sincroniza o grupo de alts vinculados garantindo:
--- 1. Reciprocidade: todos os membros do grupo possuem a lista completa dos demais alts.
--- 2. Unicidade de Main: exatamente um único membro da lista é marcado como Main (isMain = true), e todos os outros como Alts (isMain = false).
---@param memberNames string[] @Lista com todos os nomes dos personagens do grupo
---@param mainName string @Nome do personagem que será o Main único
---@return boolean
function MemberService:syncAltFamily(memberNames, mainName)
    if type(memberNames) ~= "table" or #memberNames == 0 then
        return false
    end

    local members = {}
    local validNames = {}

    for _, name in ipairs(memberNames) do
        local m = self._repository:findByName(name)
        if not m then
            for _, ex in ipairs(self._repository:findAll()) do
                if (ex:getName() or ""):lower() == name:lower() then
                    m = ex
                    break
                end
            end
        end
        if not m then
            m = Member:new({ name = name, isMain = false })
        end
        if m then
            table.insert(members, m)
            table.insert(validNames, m:getName())
        end
    end

    if #members == 0 then
        return false
    end

    -- Se o mainName não foi informado ou não pertence à lista, elege o primeiro da lista
    local mainLower = (mainName or ""):lower()
    local mainFound = false
    for _, m in ipairs(members) do
        if m:getName():lower() == mainLower then
            mainFound = true
            break
        end
    end
    if not mainFound then
        mainLower = members[1]:getName():lower()
    end

    for _, m in ipairs(members) do
        local isThisMain = (m:getName():lower() == mainLower)
        m:setMain(isThisMain)

        -- Lista de alts deste membro = todos os outros da família
        local altList = {}
        for _, otherName in ipairs(validNames) do
            if otherName:lower() ~= m:getName():lower() then
                table.insert(altList, otherName)
            end
        end
        m:setAlts(altList)
        self._repository:save(m)
    end

    return true
end

--- Desvincula um personagem de uma família de alts.
---@param currentMember Member
---@param altToRemoveName string
---@return boolean
function MemberService:unlinkAltFromFamily(currentMember, altToRemoveName)
    if not currentMember or not altToRemoveName or altToRemoveName == "" then
        return false
    end

    local family = self:getAltFamily(currentMember)
    local remainingNames = {}
    local currentMainName = ""

    for _, m in ipairs(family) do
        if m:getName():lower() ~= altToRemoveName:lower() then
            table.insert(remainingNames, m:getName())
            if m:isMain() then
                currentMainName = m:getName()
            end
        end
    end

    -- Limpa os alts do membro removido e torna-o Main independente
    local removedMember = self._repository:findByName(altToRemoveName)
    if not removedMember then
        for _, ex in ipairs(self._repository:findAll()) do
            if (ex:getName() or ""):lower() == altToRemoveName:lower() then
                removedMember = ex
                break
            end
        end
    end
    if removedMember then
        removedMember:setAlts({})
        removedMember:setMain(true)
        self._repository:save(removedMember)
    end

    -- Sincroniza os membros restantes
    if #remainingNames > 0 then
        if currentMainName == "" then
            currentMainName = remainingNames[1]
        end
        self:syncAltFamily(remainingNames, currentMainName)
    end

    return true
end

--- Desvincula um membro de sua família de alts quando ele sai da guilda.
--- Remove o membro da lista de alts de todos os seus parentes,
--- limpa sua própria lista de alts, restaura isMain = true e,
--- caso o membro que saiu fosse o Main da família, elege um dos alts restantes na guilda como novo Main.
---@param memberName string
---@return boolean
function MemberService:unlinkMemberOnGuildLeave(memberName)
    if not memberName or memberName == "" then
        return false
    end

    local leavingMember = self._repository:findByName(memberName)
    if not leavingMember then
        for _, m in ipairs(self._repository:findAll()) do
            if (m:getName() or ""):lower() == memberName:lower() then
                leavingMember = m
                break
            end
        end
    end

    if not leavingMember then
        return false
    end

    local alts = leavingMember:getAlts() or {}
    if #alts == 0 then
        return false
    end

    local family = self:getAltFamily(leavingMember)
    local leavingLower = (leavingMember:getName() or ""):lower()
    local remainingNames = {}
    local currentMainName = ""

    for _, m in ipairs(family) do
        local mName = m:getName()
        if (mName or ""):lower() ~= leavingLower then
            table.insert(remainingNames, mName)
            if m:isMain() then
                currentMainName = mName
            end
        end
    end

    -- Limpa os alts do membro que saiu e torna-o Main independente
    leavingMember:setAlts({})
    leavingMember:setMain(true)
    self._repository:save(leavingMember)

    -- Sincroniza os membros restantes da família
    if #remainingNames > 0 then
        -- Se o membro que saiu era o Main (ou nenhum restante era Main), elege o primeiro restante como novo Main
        if currentMainName == "" or currentMainName:lower() == leavingLower then
            currentMainName = remainingNames[1]
        end
        self:syncAltFamily(remainingNames, currentMainName)
    end

    return true
end

