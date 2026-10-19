---@class MemberService
---@field private _repository MemberRepository
---@field private _logService LogService|nil
MemberService = {}
MemberService.__index = MemberService

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

--- Construtor do serviço de membros.
---@param repository MemberRepository @Instância do repositório de membros
---@param logService LogService|nil @Instância opcional do serviço de logs
---@param repository MemberRepository @Instância do repositório de membros
---@param logService LogService|nil @Instância opcional do serviço de logs
---@param syncService SyncService|nil @Instância opcional do serviço de sincronização P2P
---@return MemberService
function MemberService:new(repository, logService, syncService)
    local instance = setmetatable({}, self)
    instance._repository = repository
    instance._logService = logService
    instance._syncService = syncService
    instance._pendingRecruiters = {}
    instance._recentlyJoinedMembers = {}
    instance._missingRosterScans = {}
    return instance
end

--- Define ou atualiza o serviço de sincronização P2P.
---@param syncService SyncService
function MemberService:setSyncService(syncService)
    self._syncService = syncService
end

--- Obtém o serviço de sincronização.
---@return SyncService|nil
function MemberService:getSyncService()
    return self._syncService
end

--- Notifica que os dados customizados de um membro foram alterados e transmite na hora.
---@param member Member
function MemberService:notifyCustomDataChanged(member)
    if member and self._syncService and self._syncService.broadcastMemberCustomData then
        self._syncService:broadcastMemberCustomData(member)
    end
end

--- Notifica que as profissões de um membro foram alteradas e transmite na hora.
---@param member Member
---@param profKey string|nil
function MemberService:notifyProfessionsChanged(member, profKey)
    if member and self._syncService and self._syncService.broadcastMemberProfessions then
        self._syncService:broadcastMemberProfessions(member, profKey)
    end
end

--- Define ou atualiza o serviço de logs.
---@param logService LogService
function MemberService:setLogService(logService)
    self._logService = logService
end

--- Obtém o serviço de logs.
---@return LogService|nil
function MemberService:getLogService()
    return self._logService
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

--- Registra que um membro acabou de ingressar na guilda (para período de carência contra falsos positivos).
---@param memberName string
function MemberService:recordRecentJoin(memberName)
    if not memberName or memberName == "" then return end
    self._recentlyJoinedMembers = self._recentlyJoinedMembers or {}
    local lower = memberName:lower()
    local now = (GetTime and GetTime()) or (time and time()) or (os and os.time and os.time()) or 0
    self._recentlyJoinedMembers[lower] = now
end

--- Verifica se o membro acabou de entrar na guilda (dentro da janela de carência de propagação do roster).
---@param memberName string
---@return boolean
function MemberService:isRecentlyJoined(memberName)
    if not memberName or memberName == "" then return false end
    local lower = memberName:lower()
    local now = (GetTime and GetTime()) or (time and time()) or (os and os.time and os.time()) or 0

    if self._recentlyJoinedMembers and self._recentlyJoinedMembers[lower] then
        local joinTime = self._recentlyJoinedMembers[lower]
        if (now - joinTime) < 180 then -- 3 minutos de carência
            return true
        end
    end

    local member = self:getMember(memberName)
    if member and member:isInGuild() then
        local today = (date and date("%Y-%m-%d")) or (os and os.date and os.date("%Y-%m-%d")) or ""
        if member:getDateJoin() == today and (member:getTimesLeft() or 0) == 0 then
            if not self:findQuitInGuildEventLog(memberName) and not self:findKickInGuildEventLog(memberName) then
                return true
            end
        end
    end

    return false
end

--- Registra que um membro acabou de sair ou ser expulso da guilda (para período de carência contra falsos retornos).
---@param memberName string
function MemberService:recordRecentLeave(memberName)
    if not memberName or memberName == "" then return end
    self._recentlyLeftMembers = self._recentlyLeftMembers or {}
    local lower = memberName:lower()
    local now = (GetTime and GetTime()) or (time and time()) or (os and os.time and os.time()) or 0
    self._recentlyLeftMembers[lower] = now
end

--- Verifica se o membro acabou de sair ou ser expulso da guilda (dentro da janela de carência de 60 segundos).
---@param memberName string
---@return boolean
function MemberService:isRecentlyLeft(memberName)
    if not memberName or memberName == "" or not self._recentlyLeftMembers then return false end
    local lower = memberName:lower()
    local leaveTime = self._recentlyLeftMembers[lower]
    if not leaveTime then return false end

    local now = (GetTime and GetTime()) or (time and time()) or (os and os.time and os.time()) or 0
    if (now - leaveTime) < 60 then
        return true
    end

    self._recentlyLeftMembers[lower] = nil
    return false
end

--- Limpa o registro de saída recente de um membro (por exemplo, quando ele de fato ingressa novamente).
---@param memberName string
function MemberService:clearRecentLeave(memberName)
    if not memberName or not self._recentlyLeftMembers then return end
    self._recentlyLeftMembers[memberName:lower()] = nil
end

--- Atualiza o status de saída da guilda na entidade Member e desvincula da lista de alts.
---@param member Member
---@param dateStr string|nil
---@param timestamp number|nil
function MemberService:_markMemberLeftGuild(member, dateStr, timestamp)
    if not member or not member:isInGuild() then return end
    local memberName = member:getName()
    local dateToSet = dateStr or ((date and date("%Y-%m-%d")) or (os and os.date and os.date("%Y-%m-%d")) or "")
    if timestamp and timestamp > 0 then
        if date then
            dateToSet = date("%Y-%m-%d", timestamp)
        elseif os and os.date then
            dateToSet = os.date("%Y-%m-%d", timestamp)
        end
    end

    member:setInGuild(false)
    if member:getRankName() and member:getRankName() ~= "" then
        member:setLastRank(member:getRankName())
    end
    member:setDateLeft(dateToSet)
    member:setTimesLeft((member:getTimesLeft() or 0) + 1)
    self._repository:save(member)

    self:recordRecentLeave(memberName)
    self:unlinkMemberOnGuildLeave(memberName)
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
        member:setCustomDataTimestamp(getCurrentTimestamp())
        self._repository:save(member)
        if self._logService then
            self._logService:updateRecruiterForMember(memberName, recruiterName)
        end
        return member
    end
    return nil
end

--- Resolve o nome completo (nome e sobrenome) de um personagem a partir do nome simples ou completo.
--- Valida obrigatoriamente nome e sobrenome para definir com precisão quem é o personagem.
---@param name string
---@return string
function MemberService:resolveFullName(name)
    if not name or name == "" then return "" end
    local clean = name:match("^[^-]+") or name
    clean = clean:match("^%s*(.-)%s*$") or clean
    if clean == "" then return "" end

    -- 1. Se já possui nome e sobrenome (espaço)
    if clean:find("%s") then
        local exact = self._repository:findByName(clean)
        if exact and exact:getName() and exact:getName() ~= "" then
            return exact:getName()
        end
        local cleanLower = clean:lower()
        for _, m in ipairs(self._repository:findAll()) do
            local mName = m:getName() or ""
            local mClean = (mName:match("^[^-]+") or mName):match("^%s*(.-)%s*$") or mName
            if mClean:lower() == cleanLower then
                return mName
            end
        end
        return clean
    end

    -- 2. Se possui apenas o primeiro nome, busca correspondência única no repositório de membros
    local cleanLower = clean:lower()
    local matchName = nil
    local matchCount = 0
    for _, m in ipairs(self._repository:findAll()) do
        local mName = m:getName() or ""
        if mName:find("%s") then
            local first = mName:match("^(%S+)") or mName
            if first:lower() == cleanLower then
                matchName = mName
                matchCount = matchCount + 1
            end
        end
    end
    if matchCount == 1 and matchName then
        return matchName
    end

    -- 3. Busca no Roster nativo da Blizzard
    if GetNumGuildMembers and GetGuildRosterInfo then
        local num = GetNumGuildMembers() or 0
        local rMatchName = nil
        local rMatchCount = 0
        for i = 1, num do
            local gName = GetGuildRosterInfo(i)
            if gName then
                local gClean = gName:match("^[^-]+") or gName
                gClean = gClean:match("^%s*(.-)%s*$") or gClean
                if gClean:find("%s") then
                    local first = gClean:match("^(%S+)") or gClean
                    if first:lower() == cleanLower then
                        rMatchName = gClean
                        rMatchCount = rMatchCount + 1
                    end
                end
            end
        end
        if rMatchCount >= 1 and rMatchName then
            return rMatchName
        end
    end

    return clean
end

--- Resolve o nome completo (nome e sobrenome) do jogador local utilizando GUID prioritariamente.
---@return string
function MemberService:resolvePlayerFullName()
    local myGUID = UnitGUID and UnitGUID("player")
    local myName = UnitName and UnitName("player") or ""
    local myNameLower = myName:lower()

    if myGUID and myGUID ~= "" then
        local m = self:getMemberByGuid(myGUID)
        if m and m:getName() and m:getName() ~= "" and m:getName():find("%s") then
            return m:getName()
        end
        for _, member in ipairs(self:getAllMembers()) do
            if member:getGuid() == myGUID and member:getName() and member:getName():find("%s") then
                return member:getName()
            end
        end
        if GetNumGuildMembers and GetGuildRosterInfo then
            local num = GetNumGuildMembers() or 0
            for i = 1, num do
                local gName, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
                if gName then
                    local clean = gName:match("^[^-]+") or gName
                    clean = clean:match("^%s*(.-)%s*$") or clean
                    if clean ~= "" and clean:find("%s") then
                        if guid and guid == myGUID then
                            return clean
                        end
                        local first = clean:match("^(%S+)") or clean
                        if myNameLower ~= "" and first:lower() == myNameLower then
                            return clean
                        end
                    end
                end
            end
        end
    end

    return self:resolveFullName(myName)
end

--- Resolve o nome completo (nome e sobrenome) de um recrutador buscando no repositório.
---@param recruiterName string
---@return string
function MemberService:resolveRecruiterFullName(recruiterName)
    return self:resolveFullName(recruiterName)
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

    -- Busca membro existente por GUID prioritariamente para evitar desvios de homônimos
    local member = nil
    if rosterData.guid and rosterData.guid ~= "" and self._repository and self._repository.findByGuid then
        member = self._repository:findByGuid(rosterData.guid)
    end
    if not member then
        member = self._repository:findByName(rosterData.name)
    end
    if not member and not rosterData.name:find("%s") then
        local full = self:resolveFullName(rosterData.name)
        if full and full ~= "" and full:find("%s") then
            member = self._repository:findByName(full)
            if member then
                rosterData.name = member:getName()
            end
        end
    end
    if member and member:getName() and member:getName():find("%s") then
        rosterData.name = member:getName()
    end
    local pendingRecruiter = self:getPendingRecruiter(rosterData.name)

    if member then
        if self:isRecentlyLeft(member:getName()) then
            -- O membro acabou de ser expulso ou sair da guilda (delay de propagação do cache da Blizzard).
            -- NÃO processa dados de nível, cargo, reativação ou log de retorno!
            return member
        end

        local oldLevel = member:getLevel()
        local newLevel = tonumber(rosterData.level)

        -- Detecta se o membro subiu de nível e registra o evento LEVELED
        if oldLevel and oldLevel > 0 and newLevel and newLevel > oldLevel then
            if rosterData.class and rosterData.class ~= "" and member:getClass() == "" then
                member:setClass(rosterData.class)
            end
            if self._logService then
                if (newLevel - oldLevel) <= 5 then
                    for lvl = oldLevel + 1, newLevel do
                        self._logService:logMemberLeveled(member, lvl, oldLevel)
                    end
                else
                    self._logService:logMemberLeveled(member, newLevel, oldLevel)
                end
            end
        end

        -- Detecta se o membro foi promovido para um cargo maior
        -- No WoW, 0 = Guild Master, e índices menores representam cargos de maior autoridade (ex: 1 = Oficial, 3 = Membro)
        -- Portanto, newRankIndex < oldRankIndex indica promoção para um cargo maior!
        local oldRankIndex = member:getRankIndex()
        local newRankIndex = tonumber(rosterData.rankIndex)
        local oldRankName = member:getRankName()
        local newRankName = rosterData.rankName

        if oldRankIndex and newRankIndex and newRankIndex < oldRankIndex and (oldRankName ~= "" and oldRankName ~= newRankName) then
            if self._logService then
                local promoInfo = self:findPromotionInGuildEventLog(member:getName(), newRankName)
                local promoter = promoInfo and promoInfo.promoter or ""
                local promoTime = promoInfo and promoInfo.time or nil
                self._logService:logMemberPromotion(member, promoter, oldRankName, newRankName, oldRankIndex, newRankIndex, promoTime)
            end
        end

        -- Detecta se o membro foi rebaixado para um cargo menor
        -- No WoW, 0 = Guild Master, e índices maiores representam cargos de menor autoridade (ex: 1 = Oficial, 3 = Membro)
        -- Portanto, newRankIndex > oldRankIndex indica rebaixamento para um cargo menor!
        if oldRankIndex and newRankIndex and newRankIndex > oldRankIndex and (oldRankName ~= "" and oldRankName ~= newRankName) then
            if self._logService then
                local demoInfo = self:findDemotionInGuildEventLog(member:getName(), newRankName)
                local demoter = demoInfo and demoInfo.demoter or ""
                local demoTime = demoInfo and demoInfo.time or nil
                self._logService:logMemberDemotion(member, demoter, oldRankName, newRankName, oldRankIndex, newRankIndex, demoTime)
            end
        end

        -- Membro já existente: verifica se estava fora da guilda e retornou
        local wasInGuild = member:isInGuild()
        local previousDateLeft = member:getDateLeft() or ""
        local previousLastRank = member:getLastRank() or ""
        if previousLastRank == "" then
            previousLastRank = member:getRankName() or ""
        end
        local timesLeft = member:getTimesLeft() or 0
        local isReturning = (not wasInGuild)

        if isReturning and timesLeft == 0 then
            timesLeft = 1
            member:setTimesLeft(1)
        end

        -- Detecta alterações na Nota Pública e Nota de Oficial (Blizzard)
        local isRosterInit = (_G.GM_DB and _G.GM_DB.rosterInitialized) or (self._repository and self._repository._db and self._repository._db.rosterInitialized)
        if isRosterInit and self._logService then
            local oldPublicNote = member:getPublicNote() or ""
            local newPublicNote = rosterData.publicNote or ""
            if oldPublicNote ~= newPublicNote then
                self._logService:logPublicNoteChange(member, oldPublicNote, newPublicNote)
            end

            local oldOfficerNote = member:getOfficerNote() or ""
            local newOfficerNote = rosterData.officerNote or ""
            if oldOfficerNote ~= newOfficerNote then
                self._logService:logOfficerNoteChange(member, oldOfficerNote, newOfficerNote)
            end
        end

        -- Atualiza dados dinâmicos da API
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

        -- Se o membro retornou para a guilda, registra o log de REJOINED
        if isReturning and self._logService then
            local recruiter = member:getRecruiter()
            if recruiter == "" and pendingRecruiter and pendingRecruiter ~= "" then
                recruiter = self:resolveRecruiterFullName(pendingRecruiter)
            end
            if previousDateLeft == "" and self._logService.getRecentLeaveOrKickDate then
                previousDateLeft = self._logService:getRecentLeaveOrKickDate(member:getName())
            end
            if previousLastRank == "" and self._logService.getRecentRankBeforeLeave then
                previousLastRank = self._logService:getRecentRankBeforeLeave(member:getName())
            end
            self._logService:logMemberRejoin(member:getName(), recruiter, previousDateLeft, previousLastRank, timesLeft, member:getGuid() or rosterData.guid)
        end
    else
        -- Novo membro detectado: define data de entrada atual caso não definida
        if not rosterData.dateJoin or rosterData.dateJoin == "" then
            rosterData.dateJoin = (date and date("%Y-%m-%d")) or (os and os.date and os.date("%Y-%m-%d")) or ""
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
        self:recordRecentJoin(rosterData.name)

        local isExistingDb = (_G.GM_DB and _G.GM_DB.rosterInitialized) or (self._repository and self._repository._db and self._repository._db.rosterInitialized)
        local isRecruit = (isExistingDb or self._repository:count() > 0)
        if isRecruit then
            -- Quando um membro é recrutado, os dados de nota de oficial e pública já começam com o valor vazio!
            rosterData.publicNote = ""
            rosterData.officerNote = ""
        end

        member = Member:new(rosterData)

        -- Se o banco já possuía membros sincronizados anteriormente, significa que este novo membro
        -- entrou/foi recrutado para a guilda enquanto o jogador esteve offline.
        if self._logService and isRecruit then
            self._logService:logRecruitment(member:getName(), member:getRecruiter(), member:getGuid())
        end
    end

    self._repository:save(member)
    return member
end

--- Reconcilia os membros do banco com os membros atualmente presentes no roster.
--- Identifica membros que saíram da guilda e atualiza seus status.
---@param activeRosterNames table<string, boolean> @Tabela hash com nomes dos membros ativos na guilda
---@param activeRosterGuids table<string, boolean>|nil @Tabela hash opcional com GUIDs dos membros ativos
function MemberService:reconcileGuildMembers(activeRosterNames, activeRosterGuids)
    if type(activeRosterNames) ~= "table" then
        return
    end

    local allMembers = self._repository:findAll()
    local today = (date and date("%Y-%m-%d")) or (os and os.date and os.date("%Y-%m-%d")) or ""

    for _, member in ipairs(allMembers) do
        local memberName = member:getName()
        local nameLower = (memberName or ""):lower()
        local guid = member:getGuid() or ""

        -- Verifica se o membro está presente no roster ativo (por nome exato, base sem reino ou GUID)
        local inRoster = activeRosterNames[memberName] or activeRosterNames[nameLower]
        if not inRoster then
            local baseName = memberName:match("^[^-]+") or memberName
            baseName = baseName:match("^%s*(.-)%s*$") or baseName
            inRoster = activeRosterNames[baseName] or activeRosterNames[baseName:lower()]
        end
        if not inRoster and guid ~= "" and activeRosterGuids then
            inRoster = activeRosterGuids[guid]
        end

        if inRoster then
            -- Membro está presente e ativo: reseta qualquer contador de ausência pendente
            if self._missingRosterScans and self._missingRosterScans[nameLower] then
                self._missingRosterScans[nameLower] = nil
            end
        elseif member:isInGuild() then
            -- Se o membro nem sequer possui cargo na guilda (Cargo: -) e não está no roster,
            -- é um convite expirado ou registro que não pertence à guilda: desativa imediatamente!
            local curRank = member:getRankName() or ""
            if curRank == "" or curRank == "-" then
                member:setInGuild(false)
                self._repository:save(member)
            -- 1. Se o membro acabou de entrar na guilda (período de carência de propagação do roster),
            -- NUNCA marca como LEFT!
            elseif self:isRecentlyJoined(memberName) then
                -- Membro recém-chegado em trânsito de cache no servidor, preserva o status
            else
                -- 2. Membro ausente: verifica confirmação no registro oficial de eventos da Blizzard
                local kickInfo = self:findKickInGuildEventLog(memberName)
                local alreadyKicked = self._logService and self._logService.hasKickLog and self._logService:hasKickLog(memberName)
                local quitInfo = self:findQuitInGuildEventLog(memberName)

                if kickInfo or alreadyKicked then
                    -- O membro foi REMOVIDO (KICK) - É um erro de lógica adicionar LEFT; registra apenas KICK!
                    self:_markMemberLeftGuild(member, today, kickInfo and kickInfo.time)
                    if self._logService then
                        local kicker = kickInfo and kickInfo.kicker or ""
                        local kickTime = kickInfo and kickInfo.time or nil
                        self._logService:logGuildKick(memberName, kicker, member:getGuid(), kickTime, nil, member:getClass())
                    end
                    if self._missingRosterScans then self._missingRosterScans[nameLower] = nil end
                elseif quitInfo then
                    -- O membro saiu voluntariamente (QUIT/LEFT) confirmado pelo registro oficial da Blizzard
                    self:_markMemberLeftGuild(member, today, quitInfo and quitInfo.time)
                    if self._logService then
                        local quitTime = quitInfo and quitInfo.time or nil
                        self._logService:logGuildLeave(memberName, member:getGuid(), quitTime, nil, member:getClass())
                    end
                    if self._missingRosterScans then self._missingRosterScans[nameLower] = nil end
                else
                    -- Nem KICK nem QUIT encontrados no registro oficial.
                    -- Para evitar falsos positivos causados por lag ou scans intermediários, exige confirmação em múltiplos scans
                    self._missingRosterScans = self._missingRosterScans or {}
                    self._missingRosterScans[nameLower] = (self._missingRosterScans[nameLower] or 0) + 1

                    -- Marca como saída se ausente por pelo menos 3 scans consecutivos
                    if self._missingRosterScans[nameLower] >= 3 then
                        self:_markMemberLeftGuild(member, today)
                        if self._logService then
                            self._logService:logGuildLeave(memberName, member:getGuid(), nil, nil, member:getClass())
                        end
                        self._missingRosterScans[nameLower] = nil
                    else
                        -- Dispara consulta do log de eventos caso ainda não esteja disponível
                        if not self:hasGuildEventLogEntries() then
                            if _G.GM and _G.GM.memberController and _G.GM.memberController.requestGuildEventLog then
                                _G.GM.memberController:requestGuildEventLog()
                            elseif QueryGuildEventLog then
                                pcall(QueryGuildEventLog)
                            end
                        end
                    end
                end
            end
        end
    end
end

--- Verifica se há registros de eventos da guilda disponíveis na API da Blizzard.
---@return boolean
function MemberService:hasGuildEventLogEntries()
    if C_GuildInfo and C_GuildInfo.GetGuildEventLog then
        local success, entries = pcall(C_GuildInfo.GetGuildEventLog)
        if success and type(entries) == "table" and #entries > 0 then
            return true
        end
    end

    local getNum = GetNumGuildEvents or GetNumGuildEventLogEntries
    if getNum then
        local success, count = pcall(getNum)
        if success and type(count) == "number" and count > 0 then
            return true
        end
    end

    return false
end

--- Procura se há registro de expulsão (remove/kick) para o membro no log de eventos da guilda da Blizzard.
---@param memberName string
---@return table|nil @{ kicker = string, time = number|nil }
function MemberService:findKickInGuildEventLog(memberName)
    if not memberName or memberName == "" then return nil end
    local lowerName = memberName:lower()

    if C_GuildInfo and C_GuildInfo.GetGuildEventLog then
        local success, logEntries = pcall(C_GuildInfo.GetGuildEventLog)
        if success and type(logEntries) == "table" then
            for _, entry in ipairs(logEntries) do
                if entry and (entry.type == "remove" or entry.type == 4 or entry.type == "kick") then
                    local kicked = entry.player2 or entry.name or ""
                    local cleanKicked = tostring(kicked):match("^[^-]+") or kicked
                    cleanKicked = cleanKicked:match("^%s*(.-)%s*$")
                    if cleanKicked:lower() == lowerName then
                        local kicker = entry.player1 or entry.sourceName or ""
                        local cleanKicker = tostring(kicker):match("^[^-]+") or kicker
                        cleanKicker = cleanKicker:match("^%s*(.-)%s*$")
                        return { kicker = cleanKicker, time = entry.time }
                    end
                end
            end
        end
    end

    local getNum = GetNumGuildEvents or GetNumGuildEventLogEntries
    local getInfo = GetGuildEventInfo or GetGuildEventLogEntry
    if getNum and getInfo then
        local success, count = pcall(getNum)
        if success and type(count) == "number" and count > 0 then
            local limit = math.min(count, 100)
            for i = 1, limit do
                local s, eventType, p1, p2, _, years, months, days, hours = pcall(getInfo, i)
                if s and eventType then
                    local evtLower = tostring(eventType):lower()
                    if evtLower == "remove" or evtLower == "kick" or evtLower:find("remove") or evtLower:find("kick") then
                        local kicked = p2 or ""
                        local cleanKicked = tostring(kicked):match("^[^-]+") or kicked
                        cleanKicked = cleanKicked:match("^%s*(.-)%s*$")
                        if cleanKicked:lower() == lowerName then
                            local kicker = p1 or ""
                            local cleanKicker = tostring(kicker):match("^[^-]+") or kicker
                            cleanKicker = cleanKicker:match("^%s*(.-)%s*$")
                            local eventTimestamp = nil
                            if days or hours or months or years then
                                local now = (GetServerTime and GetServerTime()) or (time and time()) or (os and os.time and os.time()) or 0
                                local secAgo = ((years or 0) * 365 + (months or 0) * 30 + (days or 0)) * 86400 + (hours or 0) * 3600
                                if now > secAgo then eventTimestamp = now - secAgo end
                            end
                            return { kicker = cleanKicker, time = eventTimestamp }
                        end
                    end
                end
            end
        end
    end

    return nil
end

--- Procura se há registro de saída voluntária (quit/leave) para o membro no log de eventos da guilda da Blizzard.
---@param memberName string
---@return table|nil @{ time = number|nil }
function MemberService:findQuitInGuildEventLog(memberName)
    if not memberName or memberName == "" then return nil end
    local lowerName = memberName:lower()

    if C_GuildInfo and C_GuildInfo.GetGuildEventLog then
        local success, logEntries = pcall(C_GuildInfo.GetGuildEventLog)
        if success and type(logEntries) == "table" then
            for _, entry in ipairs(logEntries) do
                if entry and (entry.type == "quit" or entry.type == 5 or entry.type == "leave") then
                    local quitter = entry.player1 or entry.name or ""
                    local cleanQuitter = tostring(quitter):match("^[^-]+") or quitter
                    cleanQuitter = cleanQuitter:match("^%s*(.-)%s*$")
                    if cleanQuitter:lower() == lowerName then
                        return { time = entry.time }
                    end
                end
            end
        end
    end

    local getNum = GetNumGuildEvents or GetNumGuildEventLogEntries
    local getInfo = GetGuildEventInfo or GetGuildEventLogEntry
    if getNum and getInfo then
        local success, count = pcall(getNum)
        if success and type(count) == "number" and count > 0 then
            local limit = math.min(count, 100)
            for i = 1, limit do
                local s, eventType, p1, p2, _, years, months, days, hours = pcall(getInfo, i)
                if s and eventType then
                    local evtLower = tostring(eventType):lower()
                    if evtLower == "quit" or evtLower == "leave" or evtLower:find("quit") or evtLower:find("leave") or evtLower:find("saiu") then
                        local quitter = p1 or ""
                        local cleanQuitter = tostring(quitter):match("^[^-]+") or quitter
                        cleanQuitter = cleanQuitter:match("^%s*(.-)%s*$")
                        if cleanQuitter:lower() == lowerName then
                            local eventTimestamp = nil
                            if days or hours or months or years then
                                local now = (GetServerTime and GetServerTime()) or (time and time()) or (os and os.time and os.time()) or 0
                                local secAgo = ((years or 0) * 365 + (months or 0) * 30 + (days or 0)) * 86400 + (hours or 0) * 3600
                                if now > secAgo then eventTimestamp = now - secAgo end
                            end
                            return { time = eventTimestamp }
                        end
                    end
                end
            end
        end
    end

    return nil
end

--- Procura se há registro de promoção (promote) para o membro no log de eventos da guilda da Blizzard.
---@param memberName string
---@param targetRank string|nil
---@return table|nil @{ promoter = string, time = number|nil, newRank = string }
function MemberService:findPromotionInGuildEventLog(memberName, targetRank)
    if not memberName or memberName == "" then return nil end
    local lowerName = memberName:lower()
    local lowerTarget = (targetRank and targetRank ~= "") and targetRank:lower() or nil

    if C_GuildInfo and C_GuildInfo.GetGuildEventLog then
        local success, logEntries = pcall(C_GuildInfo.GetGuildEventLog)
        if success and type(logEntries) == "table" then
            for _, entry in ipairs(logEntries) do
                if entry and (entry.type == "promote" or entry.type == 3 or entry.type == "promoted") then
                    local promoted = entry.player2 or entry.name or ""
                    local cleanPromoted = tostring(promoted):match("^[^-]+") or promoted
                    cleanPromoted = cleanPromoted:match("^%s*(.-)%s*$")
                    if cleanPromoted:lower() == lowerName then
                        local rank = entry.rank or entry.rankName or ""
                        if not lowerTarget or rank:lower() == lowerTarget or rank == "" then
                            local promoter = entry.player1 or entry.sourceName or ""
                            local cleanPromoter = tostring(promoter):match("^[^-]+") or promoter
                            cleanPromoter = cleanPromoter:match("^%s*(.-)%s*$")
                            return { promoter = cleanPromoter, time = entry.time, newRank = rank }
                        end
                    end
                end
            end
        end
    end

    local getNum = GetNumGuildEvents or GetNumGuildEventLogEntries
    local getInfo = GetGuildEventInfo or GetGuildEventLogEntry
    if getNum and getInfo then
        local success, count = pcall(getNum)
        if success and type(count) == "number" and count > 0 then
            local limit = math.min(count, 100)
            for i = 1, limit do
                local s, eventType, p1, p2, rank, years, months, days, hours = pcall(getInfo, i)
                if s and eventType then
                    local evtLower = tostring(eventType):lower()
                    if evtLower == "promote" or evtLower == "promoted" or evtLower:find("promote") or evtLower:find("promov") then
                        local promoted = p2 or ""
                        local cleanPromoted = tostring(promoted):match("^[^-]+") or promoted
                        cleanPromoted = cleanPromoted:match("^%s*(.-)%s*$")
                        if cleanPromoted:lower() == lowerName then
                            local rankStr = tostring(rank or "")
                            if not lowerTarget or rankStr:lower() == lowerTarget or rankStr == "" then
                                local promoter = p1 or ""
                                local cleanPromoter = tostring(promoter):match("^[^-]+") or promoter
                                cleanPromoter = cleanPromoter:match("^%s*(.-)%s*$")
                                local eventTimestamp = nil
                                if days or hours or months or years then
                                    local now = (GetServerTime and GetServerTime()) or (time and time()) or (os and os.time and os.time()) or 0
                                    local secAgo = ((years or 0) * 365 + (months or 0) * 30 + (days or 0)) * 86400 + (hours or 0) * 3600
                                    if now > secAgo then eventTimestamp = now - secAgo end
                                end
                                return { promoter = cleanPromoter, time = eventTimestamp, newRank = rankStr }
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

--- Procura se há registro de rebaixamento (demote) para o membro no log de eventos da guilda da Blizzard.
---@param memberName string
---@param targetRank string|nil
---@return table|nil @{ demoter = string, time = number|nil, newRank = string }
function MemberService:findDemotionInGuildEventLog(memberName, targetRank)
    if not memberName or memberName == "" then return nil end
    local lowerName = memberName:lower()
    local lowerTarget = (targetRank and targetRank ~= "") and targetRank:lower() or nil

    if C_GuildInfo and C_GuildInfo.GetGuildEventLog then
        local success, logEntries = pcall(C_GuildInfo.GetGuildEventLog)
        if success and type(logEntries) == "table" then
            for _, entry in ipairs(logEntries) do
                if entry and (entry.type == "demote" or entry.type == "demoted") then
                    local demoted = entry.player2 or entry.name or ""
                    local cleanDemoted = tostring(demoted):match("^[^-]+") or demoted
                    cleanDemoted = cleanDemoted:match("^%s*(.-)%s*$")
                    if cleanDemoted:lower() == lowerName then
                        local rank = entry.rank or entry.rankName or ""
                        if not lowerTarget or rank:lower() == lowerTarget or rank == "" then
                            local demoter = entry.player1 or entry.sourceName or ""
                            local cleanDemoter = tostring(demoter):match("^[^-]+") or demoter
                            cleanDemoter = cleanDemoter:match("^%s*(.-)%s*$")
                            return { demoter = cleanDemoter, time = entry.time, newRank = rank }
                        end
                    end
                end
            end
        end
    end

    local getNum = GetNumGuildEvents or GetNumGuildEventLogEntries
    local getInfo = GetGuildEventInfo or GetGuildEventLogEntry
    if getNum and getInfo then
        local success, count = pcall(getNum)
        if success and type(count) == "number" and count > 0 then
            local limit = math.min(count, 100)
            for i = 1, limit do
                local s, eventType, p1, p2, rank, years, months, days, hours = pcall(getInfo, i)
                if s and eventType then
                    local evtLower = tostring(eventType):lower()
                    if evtLower == "demote" or evtLower == "demoted" or evtLower:find("demote") or evtLower:find("rebaix") then
                        local demoted = p2 or ""
                        local cleanDemoted = tostring(demoted):match("^[^-]+") or demoted
                        cleanDemoted = cleanDemoted:match("^%s*(.-)%s*$")
                        if cleanDemoted:lower() == lowerName then
                            local rankStr = tostring(rank or "")
                            if not lowerTarget or rankStr:lower() == lowerTarget or rankStr == "" then
                                local demoter = p1 or ""
                                local cleanDemoter = tostring(demoter):match("^[^-]+") or demoter
                                cleanDemoter = cleanDemoter:match("^%s*(.-)%s*$")
                                local eventTimestamp = nil
                                if days or hours or months or years then
                                    local now = (GetServerTime and GetServerTime()) or (time and time()) or (os and os.time and os.time()) or 0
                                    local secAgo = ((years or 0) * 365 + (months or 0) * 30 + (days or 0)) * 86400 + (hours or 0) * 3600
                                    if now > secAgo then eventTimestamp = now - secAgo end
                                end
                                return { demoter = cleanDemoter, time = eventTimestamp, newRank = rankStr }
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
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

--- Alias para compatibilidade com findAll de repositório
---@return Member[]
function MemberService:findAll()
    return self:getAllMembers()
end

--- Salva um membro diretamente através do repositório e transmite atualizações de dados customizados.
---@param member Member
---@param skipSync boolean|nil @Se verdadeiro, não retransmite via SyncService (útil para dados recebidos da rede)
---@return boolean
function MemberService:saveMember(member, skipSync)
    local ok = self._repository:save(member)
    if ok and not skipSync and self._syncService and self._syncService.broadcastMemberCustomData then
        self._syncService:broadcastMemberCustomData(member)
    end
    return ok
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
---@param skipSync boolean|nil @Se true, não dispara retransmissão de rede nem sobrescreve timestamp
---@return boolean
function MemberService:syncAltFamily(memberNames, mainName, skipSync)
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

    local nowTs = getCurrentTimestamp()
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
        if not skipSync then
            m:setCustomDataTimestamp(nowTs)
        end
        self._repository:save(m)
    end

    -- Notifica o SyncService para transmitir a família atualizada na hora para todos os outros pares
    if not skipSync and self._syncService and self._syncService.broadcastMemberCustomData then
        for _, m in ipairs(members) do
            self._syncService:broadcastMemberCustomData(m)
        end
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
        removedMember:setCustomDataTimestamp(getCurrentTimestamp())
        self._repository:save(removedMember)
        if self._syncService and self._syncService.broadcastMemberCustomData then
            self._syncService:broadcastMemberCustomData(removedMember)
        end
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
--- sincroniza as listas dos membros restantes, restaura o membro removido como Main independente,
--- e remove quaisquer referências residuais em todo o banco de membros.
---@param memberName string
---@return boolean @Retorna true se o membro pertencia a uma lista de alts e foi desvinculado
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

    local leavingLower = memberName:lower()
    local familyMap = {}
    local familyList = {}

    local function addToFamily(m)
        if not m then return end
        local n = (m:getName() or ""):lower()
        if n ~= "" and not familyMap[n] then
            familyMap[n] = m
            table.insert(familyList, m)
            for _, alt in ipairs(m:getAlts() or {}) do
                local am = self._repository:findByName(alt)
                if not am then
                    for _, ex in ipairs(self._repository:findAll()) do
                        if (ex:getName() or ""):lower() == alt:lower() then
                            am = ex
                            break
                        end
                    end
                end
                if am and not familyMap[(am:getName() or ""):lower()] then
                    addToFamily(am)
                end
            end
        end
    end

    if leavingMember then
        addToFamily(leavingMember)
    end

    -- Varre para encontrar membros que possam apontar para o membro que saiu
    local all = self._repository:findAll()
    for _, otherMember in ipairs(all) do
        local oName = otherMember:getName() or ""
        if oName:lower() ~= leavingLower then
            for _, aName in ipairs(otherMember:getAlts() or {}) do
                if (aName or ""):lower() == leavingLower then
                    addToFamily(otherMember)
                    break
                end
            end
        end
    end

    local hadAlts = (#familyList > 1) or (leavingMember and #(leavingMember:getAlts() or {}) > 0)

    -- Se o membro que saiu foi encontrado, isola-o
    if leavingMember then
        leavingMember:setAlts({})
        leavingMember:setMain(true)
        self._repository:save(leavingMember)
    end

    -- Coleta os membros restantes da família
    local remainingNames = {}
    local currentMainName = ""
    for _, m in ipairs(familyList) do
        local mName = m:getName() or ""
        if mName:lower() ~= leavingLower then
            table.insert(remainingNames, mName)
            if m:isMain() then
                currentMainName = mName
            end
        end
    end

    -- Sincroniza e atualiza os membros restantes da família de alts
    if #remainingNames > 0 then
        if currentMainName == "" or currentMainName:lower() == leavingLower then
            currentMainName = remainingNames[1]
        end
        self:syncAltFamily(remainingNames, currentMainName)
    end

    -- Varredura final preventiva: garante que nenhum membro em todo o banco possua o que saiu na lista de alts
    local modifiedOther = false
    for _, otherMember in ipairs(self._repository:findAll()) do
        local oName = (otherMember:getName() or ""):lower()
        if oName ~= leavingLower then
            local modified = false
            local remainingAlts = {}
            for _, aName in ipairs(otherMember:getAlts() or {}) do
                if (aName or ""):lower() == leavingLower then
                    modified = true
                else
                    table.insert(remainingAlts, aName)
                end
            end
            if modified then
                otherMember:setAlts(remainingAlts)
                if #remainingAlts == 0 then
                    otherMember:setMain(true)
                end
                self._repository:save(otherMember)
                modifiedOther = true
            end
        end
    end

    return hadAlts or modifiedOther
end

--- Verifica se o jogador local possui cargo de Oficial ou Líder da Guilda.
---@return boolean
function MemberService:isPlayerOfficerOrLeader()
    if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
        return _G.GM.guildRosterService:isPlayerOfficerOrLeader()
    end
    if IsInGuild and not IsInGuild() then return false end
    if IsGuildLeader and IsGuildLeader() then return true end
    if CanEditOfficerNote and CanEditOfficerNote() then return true end
    if C_GuildInfo and C_GuildInfo.CanEditOfficerNote and C_GuildInfo.CanEditOfficerNote() then return true end
    return false
end

