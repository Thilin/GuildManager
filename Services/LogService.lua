---@class LogService
---@field private _repository LogRepository
LogService = {}
LogService.__index = LogService

--- Construtor do serviço de logs de eventos da guilda.
---@param repository LogRepository @Instância do repositório de logs
---@return LogService
function LogService:new(repository)
    local instance = setmetatable({}, self)
    instance._repository = repository
    return instance
end

--- Formata a mensagem padrão obrigatória para o evento JOINED.
--- Padrão: "Player X foi RECRUTADO por Player Y" com cores temáticas.
---@param recruitName string @Nome do personagem recrutado
---@param recruiterName string|nil @Nome do recrutador
---@param recruitClass string|nil @Classe do recrutado (opcional)
---@param recClass string|nil @Classe do recrutador (opcional)
---@return string
function LogService:formatJoinedMessage(recruitName, recruiterName, recruitClass, recClass)
    local recruiter = (recruiterName and recruiterName ~= "") and recruiterName or "Desconhecido"
    local coloredRecruit = self:formatColoredMemberName(recruitName, recruitClass)
    local coloredRecruiter
    if recruiter ~= "Desconhecido" then
        coloredRecruiter = self:formatColoredMemberName(recruiter, recClass)
    else
        coloredRecruiter = "|cff888888Desconhecido|r"
    end
    return string.format("%s |cffa8f0a8foi|r |cff40ff40RECRUTADO|r |cffa8f0a8por|r %s", coloredRecruit, coloredRecruiter)
end

--- Registra o evento de recrutamento (JOINED) de um novo membro.
--- Se o log de JOINED já existir para o membro e um novo recrutador for informado,
--- atualiza o registro existente sem duplicar.
---@param recruitName string @Nome do membro que entrou na guilda
---@param recruiterName string|nil @Nome de quem o recrutou
---@param guid string|nil @GUID do personagem
---@param timestamp number|nil @Timestamp Unix do evento (opcional)
---@param dateStr string|nil @Data legível formatada (opcional)
---@return Log|nil, boolean @Retorna a entidade Log e um booleano indicando se foi criada (true) ou atualizada (false)
function LogService:logRecruitment(recruitName, recruiterName, guid, timestamp, dateStr)
    if not recruitName or recruitName == "" then
        return nil, false
    end

    -- Resolve tokens de classe caso disponíveis
    local memberClass = ""
    local recClass = ""
    if _G.GM and _G.GM.memberService then
        local m = _G.GM.memberService:getMember(recruitName)
        if m then memberClass = m:getClass() or "" end
        if recruiterName and recruiterName ~= "" then
            local r = _G.GM.memberService:getMember(recruiterName)
            if r then recClass = r:getClass() or "" end
        end
    end
    if memberClass == "" and guid and guid ~= "" and GetPlayerInfoByGUID then
        local _, classToken = GetPlayerInfoByGUID(guid)
        if classToken then memberClass = classToken end
    end

    local existingLog = self._repository:findJoinedLog(recruitName, guid)
    if existingLog then
        -- Se já existia um log mas o recrutador era desconhecido ou mudou para um recrutador válido
        local curRecruiter = existingLog:getRecruiter()
        if recruiterName and recruiterName ~= "" and (curRecruiter == "" or curRecruiter == "Desconhecido" or curRecruiter ~= recruiterName) then
            existingLog:setRecruiter(recruiterName)
            existingLog:setMessage(self:formatJoinedMessage(recruitName, recruiterName, memberClass, recClass))
            if guid and guid ~= "" and existingLog:getGuid() == "" then
                existingLog:setGuid(guid)
            end
            if recClass ~= "" then
                existingLog:setRecruiterClass(recClass)
            end
            if memberClass ~= "" and existingLog:getClass() == "" then
                existingLog:setClass(memberClass)
            end
            self._repository:save(existingLog)
        end
        return existingLog, false
    end

    -- Cria um novo registro de log de JOINED
    local message = self:formatJoinedMessage(recruitName, recruiterName, memberClass, recClass)
    local newLog = Log:new({
        name = recruitName,
        class = memberClass,
        guid = guid or "",
        message = message,
        event = LogEvent.JOINED,
        recruiter = recruiterName or "",
        recruiterClass = recClass,
        timestamp = timestamp,
        date = dateStr,
    })

    self._repository:save(newLog)
    return newLog, true
end

--- Atualiza o recrutador de um registro JOINED já gravado (ou cria caso não exista).
---@param recruitName string
---@param recruiterName string
---@return boolean
function LogService:updateRecruiterForMember(recruitName, recruiterName)
    if not recruitName or recruitName == "" or not recruiterName or recruiterName == "" then
        return false
    end

    local existingLog = self._repository:findJoinedLog(recruitName)
    if existingLog then
        existingLog:setRecruiter(recruiterName)
        existingLog:setMessage(self:formatJoinedMessage(recruitName, recruiterName, existingLog:getClass(), existingLog:getRecruiterClass()))
        return self._repository:save(existingLog)
    else
        local _, created = self:logRecruitment(recruitName, recruiterName)
        return created
    end
end

--- Verifica se já existe um registro de entrada (JOINED) para um membro.
---@param recruitName string
---@param guid string|nil
---@return boolean
function LogService:hasJoinedLog(recruitName, guid)
    local log = self._repository:findJoinedLog(recruitName, guid)
    return log ~= nil
end

--- Retorna todos os logs registrados no sistema.
---@return Log[]
function LogService:getAllLogs()
    return self._repository:findAll()
end

--- Retorna os logs de um personagem específico.
---@param memberName string
---@return Log[]
function LogService:getLogsForMember(memberName)
    return self._repository:findByName(memberName)
end

--- Formata a mensagem padrão obrigatória para o evento LEFT.
--- Padrão: "Player X SAIU da guilda" com cores temáticas.
---@param memberName string
---@param memberClass string|nil
---@return string
function LogService:formatLeftMessage(memberName, memberClass)
    local coloredName = self:formatColoredMemberName(memberName, memberClass)
    return string.format("%s |cffff9926SAIU|r |cffffcca0da guilda|r", coloredName)
end

--- Registra o evento de saída (LEFT) de um membro da guilda.
--- Evita duplicidade se a saída já tiver sido registrada recentemente.
---@param memberName string @Nome do membro que saiu
---@param guid string|nil @GUID do personagem
---@param timestamp number|nil @Timestamp Unix do evento
---@param dateStr string|nil @Data legível formatada
---@param memberClass string|nil @Token da classe do personagem (opcional)
---@return Log|nil, boolean @Retorna a entidade Log e se foi criada
function LogService:logGuildLeave(memberName, guid, timestamp, dateStr, memberClass)
    if not memberName or memberName == "" then
        return nil, false
    end

    -- Se o membro foi removido (KICK), é um erro de lógica registrar que ele saiu (LEFT)
    if self:hasKickLog(memberName) then
        return nil, false
    end

    -- Se o membro acabou de entrar na guilda (período de carência) e não há timestamp oficial de saída,
    -- rejeita a criação do log de LEFT para evitar falsos positivos decorrentes do delay da Blizzard
    local mService = self._memberService or (_G.GM and _G.GM.memberService)
    if mService and mService.isRecentlyJoined and mService:isRecentlyJoined(memberName) then
        if not timestamp or timestamp <= 0 then
            return nil, false
        end
    end

    -- Evita duplicidade se já houver log registrado para este evento
    if self._repository and self._repository.hasLeaveLog and timestamp and timestamp > 0 then
        if self._repository:hasLeaveLog(memberName, timestamp) then
            return nil, false
        end
    end
    if self._repository and self._repository.findRecentLeaveLog then
        local existingLog = self._repository:findRecentLeaveLog(memberName, 600)
        if existingLog then
            return existingLog, false
        end
    end

    memberClass = memberClass or ""
    if memberClass == "" and _G.GM and _G.GM.memberService then
        local m = _G.GM.memberService:getMember(memberName)
        if m then
            memberClass = m:getClass() or ""
            if not guid or guid == "" then
                guid = m:getGuid() or ""
            end
        end
    end
    if memberClass == "" and guid and guid ~= "" and GetPlayerInfoByGUID then
        local _, classToken = GetPlayerInfoByGUID(guid)
        if classToken then memberClass = classToken end
    end

    local message = self:formatLeftMessage(memberName, memberClass)
    local newLog = Log:new({
        name = memberName,
        class = memberClass,
        guid = guid or "",
        message = message,
        event = LogEvent.LEFT or "LEFT",
        timestamp = timestamp,
        date = dateStr,
    })

    self._repository:save(newLog)
    return newLog, true
end

--- Formata a mensagem padrão obrigatória para o evento KICK.
--- Padrão: "Player X foi REMOVIDO da guilda por Player Y" com cores temáticas.
---@param kickedName string @Nome do personagem expulso
---@param kickerName string|nil @Nome de quem o expulsou
---@param kickedClass string|nil @Classe do expulso
---@param kickerClass string|nil @Classe do autor
---@return string
function LogService:formatKickMessage(kickedName, kickerName, kickedClass, kickerClass)
    local kicker = (kickerName and kickerName ~= "") and kickerName or "Desconhecido"
    local coloredKicked = self:formatColoredMemberName(kickedName, kickedClass)
    local coloredKicker
    if kicker ~= "Desconhecido" then
        coloredKicker = self:formatColoredMemberName(kicker, kickerClass)
    else
        coloredKicker = "|cff888888Desconhecido|r"
    end
    return string.format("%s |cffffa6a6foi|r |cffff4040REMOVIDO|r |cffffa6a6da guilda por|r %s", coloredKicked, coloredKicker)
end

--- Verifica se existe algum log de saída (LEFT) para o personagem.
---@param name string
---@param timestamp number|nil
---@return boolean
function LogService:hasLeaveLog(name, timestamp)
    if self._repository and self._repository.hasLeaveLog then
        return self._repository:hasLeaveLog(name, timestamp)
    end
    return false
end

--- Verifica se existe algum log de expulsão (KICK) para o personagem.
---@param name string
---@param timestamp number|nil
---@return boolean
function LogService:hasKickLog(name, timestamp)
    if self._repository and self._repository.hasKickLog then
        return self._repository:hasKickLog(name, timestamp)
    end
    return false
end

--- Registra o evento de expulsão/remoção (KICK) de um membro da guilda.
--- Evita duplicidade se o KICK já tiver sido registrado recentemente.
--- Caso haja um log recente de saída voluntária (LEFT), converte-o para KICK com o autor correto.
---@param kickedName string @Nome do membro removido
---@param kickerName string|nil @Nome do membro que o removeu
---@param guid string|nil @GUID do personagem expulso
---@param timestamp number|nil @Timestamp Unix do evento
---@param dateStr string|nil @Data legível formatada
---@param kickedClass string|nil @Classe do membro expulso
---@param kickerClass string|nil @Classe de quem expulsou
---@return Log|nil, boolean @Retorna a entidade Log e se foi criada (true) ou atualizada (false)
function LogService:logGuildKick(kickedName, kickerName, guid, timestamp, dateStr, kickedClass, kickerClass)
    if not kickedName or kickedName == "" then
        return nil, false
    end

    local kicker = kickerName or ""

    -- 1. Verifica se já existe um KICK para este personagem no mesmo período
    if self._repository and self._repository.hasKickLog and timestamp and timestamp > 0 then
        if self._repository:hasKickLog(kickedName, timestamp) then
            return nil, false
        end
    end
    if self._repository and self._repository.findRecentKickLog then
        local existingKick = self._repository:findRecentKickLog(kickedName, 600)
        if existingKick then
            -- Se já existe mas o autor era desconhecido e agora temos o autor, atualiza
            if (existingKick:getKicker() == "" or existingKick:getKicker() == "Desconhecido") and kicker ~= "" then
                existingKick:setKicker(kicker)
                if kickerClass and kickerClass ~= "" then
                    existingKick:setKickerClass(kickerClass)
                end
                existingKick:setMessage(self:formatKickMessage(kickedName, kicker, existingKick:getClass(), kickerClass))
                self._repository:save(existingKick)
            end
            return existingKick, false
        end
    end

    -- 2. Se houver um log de LEFT gerado para este membro, converte-o para KICK
    if self._repository and self._repository.findRecentLeaveLog then
        local existingLeave = self._repository:findRecentLeaveLog(kickedName, 86400)
        if existingLeave then
            existingLeave:setEvent(LogEvent.KICK)
            existingLeave:setKicker(kicker)
            if kickerClass and kickerClass ~= "" then
                existingLeave:setKickerClass(kickerClass)
            end
            existingLeave:setMessage(self:formatKickMessage(kickedName, kicker, existingLeave:getClass(), kickerClass))
            if timestamp and timestamp > 0 then
                existingLeave:setTimestamp(timestamp)
            end
            if dateStr and dateStr ~= "" then
                existingLeave:setDate(dateStr)
            end
            self._repository:save(existingLeave)
            return existingLeave, false
        end
    end

    -- 3. Resolve classes se não informadas
    kickedClass = kickedClass or ""
    kickerClass = kickerClass or ""
    if _G.GM and _G.GM.memberService then
        local m = _G.GM.memberService:getMember(kickedName)
        if m then
            if kickedClass == "" then kickedClass = m:getClass() or "" end
            if not guid or guid == "" then guid = m:getGuid() or "" end
        end
        if kicker ~= "" and kickerClass == "" then
            local k = _G.GM.memberService:getMember(kicker)
            if k then kickerClass = k:getClass() or "" end
        end
    end
    if kickedClass == "" and guid and guid ~= "" and GetPlayerInfoByGUID then
        local _, classToken = GetPlayerInfoByGUID(guid)
        if classToken then kickedClass = classToken end
    end

    local message = self:formatKickMessage(kickedName, kicker, kickedClass, kickerClass)
    local newLog = Log:new({
        name = kickedName,
        class = kickedClass,
        guid = guid or "",
        message = message,
        event = LogEvent.KICK,
        kicker = kicker,
        kickerClass = kickerClass,
        recruiter = kicker,
        recruiterClass = kickerClass,
        timestamp = timestamp,
        date = dateStr,
    })

    self._repository:save(newLog)
    return newLog, true
end

--- Formata o nome de um membro com o código hexadecimal da cor da sua classe.
---@param name string
---@param classToken string|nil
---@return string
function LogService:formatColoredMemberName(name, classToken)
    if not name or name == "" then return "" end
    local clean = name:match("^[^-]+") or name
    clean = clean:match("^%s*(.-)%s*$") or clean

    local token = classToken or ""
    if token == "" and _G.GM and _G.GM.memberService then
        local m = _G.GM.memberService:getMember(clean)
        if m then token = m:getClass() or "" end
    end

    if token ~= "" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token] then
        local color = RAID_CLASS_COLORS[token]
        if color.colorStr then
            return "|c" .. color.colorStr .. clean .. "|r"
        end
        local r = math.floor((color.r or 1) * 255)
        local g = math.floor((color.g or 1) * 255)
        local b = math.floor((color.b or 1) * 255)
        return string.format("|cff%02x%02x%02x%s|r", r, g, b, clean)
    end

    return clean
end

--- Formata a mensagem padrão obrigatória para o evento LEVELED.
--- Padrão: "X SUBIU para o nível Y" com X colorido pela cor da sua classe e cores temáticas.
---@param memberName string|Member @Nome do membro ou objeto Member
---@param newLevel number @Nível alcançado
---@param memberClass string|nil @Token da classe
---@return string
function LogService:formatLeveledMessage(memberName, newLevel, memberClass)
    local name = memberName
    local classToken = memberClass or ""
    if type(memberName) == "table" and memberName.getName then
        name = memberName:getName()
        classToken = memberName:getClass() or classToken
    end

    local coloredName = self:formatColoredMemberName(name, classToken)
    return string.format("%s |cffffd91aSUBIU|r |cffffe899para o nível|r |cffffffff%d|r", coloredName, tonumber(newLevel) or 1)
end

--- Registra o evento de evolução de nível (LEVELED) de um membro da guilda.
--- Salva a mensagem: "X SUBIU para o nível Y" com o nome na cor da classe.
--- Evita duplicidade se já houver registro deste nível para o membro.
---@param member Member|string @Instância do membro ou nome
---@param newLevel number @Novo nível alcançado
---@param oldLevel number|nil @Nível anterior (opcional)
---@param timestamp number|nil @Timestamp Unix do evento (opcional)
---@param dateStr string|nil @Data legível formatada (opcional)
---@return Log|nil, boolean @Retorna a entidade Log e se foi criada (true) ou já existia (false)
function LogService:logMemberLeveled(member, newLevel, oldLevel, timestamp, dateStr)
    if not member or not newLevel then
        return nil, false
    end

    local memberName = ""
    local memberClass = ""
    local guid = ""
    if type(member) == "table" and member.getName then
        memberName = member:getName()
        memberClass = member:getClass() or ""
        guid = member:getGuid() or ""
    else
        memberName = tostring(member)
    end

    if memberName == "" then
        return nil, false
    end

    local targetLevel = tonumber(newLevel) or 1

    -- Evita duplicidade se o log deste nível já foi registrado
    if self._repository and self._repository.findLeveledLog then
        local existing = self._repository:findLeveledLog(memberName, targetLevel)
        if existing then
            return existing, false
        end
    end

    if memberClass == "" and _G.GM and _G.GM.memberService then
        local m = _G.GM.memberService:getMember(memberName)
        if m then
            memberClass = m:getClass() or ""
            if guid == "" then guid = m:getGuid() or "" end
        end
    end
    if memberClass == "" and guid ~= "" and GetPlayerInfoByGUID then
        local _, classToken = GetPlayerInfoByGUID(guid)
        if classToken then memberClass = classToken end
    end

    local message = self:formatLeveledMessage(memberName, targetLevel, memberClass)

    local newLog = Log:new({
        name = memberName,
        class = memberClass,
        guid = guid,
        level = targetLevel,
        message = message,
        event = LogEvent.LEVELED,
        timestamp = timestamp,
        date = dateStr,
    })

    self._repository:save(newLog)
    return newLog, true
end

--- Formata a mensagem padrão obrigatória para o evento PROMOTION.
--- Padrão: "Player X foi PROMOVIDO a CargoNovo por Player Y (anterior: CargoAntigo)" com cores temáticas.
---@param promotedName string @Nome do personagem promovido
---@param promoterName string|nil @Nome de quem o promoveu
---@param oldRank string|nil @Cargo anterior
---@param newRank string @Novo cargo alcançado
---@param promotedClass string|nil @Classe do promovido
---@param promoterClass string|nil @Classe do autor da promoção
---@return string
function LogService:formatPromotionMessage(promotedName, promoterName, oldRank, newRank, promotedClass, promoterClass)
    local promoter = (promoterName and promoterName ~= "") and promoterName or "Desconhecido"
    local coloredPromoted = self:formatColoredMemberName(promotedName, promotedClass)
    local coloredPromoter
    if promoter ~= "Desconhecido" then
        coloredPromoter = self:formatColoredMemberName(promoter, promoterClass)
    else
        coloredPromoter = "|cff888888Desconhecido|r"
    end
    local rankStr = (newRank and newRank ~= "") and newRank or "Novo Cargo"
    local rankChangeStr = ""
    if oldRank and oldRank ~= "" and oldRank ~= newRank then
        rankChangeStr = string.format(" |cff888888(anterior: |cffffffff%s|r)|r", oldRank)
    end
    return string.format("%s |cffa8f0a8foi|r |cff00e5ffPROMOVIDO|r |cffa8f0a8a|r |cffffff00%s|r |cffa8f0a8por|r %s%s", coloredPromoted, rankStr, coloredPromoter, rankChangeStr)
end

--- Verifica se existe algum log de promoção (PROMOTION) para o personagem.
---@param name string
---@param newRank string|nil
---@param timestamp number|nil
---@return boolean
function LogService:hasPromotionLog(name, newRank, timestamp)
    if self._repository and self._repository.hasPromotionLog then
        return self._repository:hasPromotionLog(name, newRank, timestamp)
    end
    return false
end

--- Registra o evento de promoção (PROMOTION) de um membro para um cargo maior.
--- Armazena quem promoveu, quem foi promovido, o cargo anterior e o cargo novo.
--- Evita duplicidade se a promoção já tiver sido registrada recentemente.
---@param member Member|string @Instância do membro promovido ou nome
---@param promoterName string|nil @Nome de quem promoveu
---@param oldRank string|nil @Cargo anterior
---@param newRank string @Novo cargo alcançado
---@param oldRankIndex number|nil @Índice do cargo anterior
---@param newRankIndex number|nil @Índice do novo cargo
---@param timestamp number|nil @Timestamp Unix do evento (opcional)
---@param dateStr string|nil @Data legível formatada (opcional)
---@param promoterClass string|nil @Token da classe do promotor (opcional)
---@return Log|nil, boolean @Retorna a entidade Log e se foi criada (true) ou atualizada/já existia (false)
function LogService:logMemberPromotion(member, promoterName, oldRank, newRank, oldRankIndex, newRankIndex, timestamp, dateStr, promoterClass)
    if not member or not newRank or newRank == "" then
        return nil, false
    end

    local memberName = ""
    local memberClass = ""
    local guid = ""
    if type(member) == "table" and member.getName then
        memberName = member:getName()
        memberClass = member:getClass() or ""
        guid = member:getGuid() or ""
        if not oldRank or oldRank == "" then
            oldRank = member:getRankName() or ""
        end
        if not oldRankIndex then
            oldRankIndex = member:getRankIndex()
        end
    else
        memberName = tostring(member)
    end

    if memberName == "" then
        return nil, false
    end

    -- 1. Verifica se já existe um log recente de promoção para este personagem e cargo
    if self._repository and self._repository.findRecentPromotionLog then
        local existingLog = self._repository:findRecentPromotionLog(memberName, newRank, 600)
        if existingLog then
            local modified = false
            -- Se o log existente não possuía o promotor e agora temos o promotor, atualiza
            local curPromoter = existingLog:getPromoter()
            if (curPromoter == "" or curPromoter == "Desconhecido") and promoterName and promoterName ~= "" and promoterName ~= "Desconhecido" then
                existingLog:setPromoter(promoterName)
                if promoterClass and promoterClass ~= "" then
                    existingLog:setPromoterClass(promoterClass)
                end
                modified = true
            end
            -- Se o log existente não possuía o cargo anterior e agora temos, atualiza
            local curOldRank = existingLog:getOldRank()
            if (curOldRank == "" or curOldRank == newRank) and oldRank and oldRank ~= "" and oldRank ~= newRank then
                existingLog:setOldRank(oldRank)
                if oldRankIndex then
                    existingLog:setOldRankIndex(oldRankIndex)
                end
                modified = true
            end

            if modified then
                local pName = existingLog:getPromoter()
                local pClass = existingLog:getPromoterClass()
                local oRank = existingLog:getOldRank()
                existingLog:setMessage(self:formatPromotionMessage(memberName, pName, oRank, newRank, existingLog:getClass(), pClass))
                self._repository:save(existingLog)
            end
            return existingLog, false
        end
    end

    -- 2. Resolve classes se não informadas
    if memberClass == "" and _G.GM and _G.GM.memberService then
        local m = _G.GM.memberService:getMember(memberName)
        if m then
            memberClass = m:getClass() or ""
            if guid == "" then guid = m:getGuid() or "" end
            if (not oldRank or oldRank == "") and m:getRankName() ~= "" and m:getRankName() ~= newRank then
                oldRank = m:getRankName()
            end
            if not oldRankIndex then
                oldRankIndex = m:getRankIndex()
            end
        end
    end
    if memberClass == "" and guid ~= "" and GetPlayerInfoByGUID then
        local _, classToken = GetPlayerInfoByGUID(guid)
        if classToken then memberClass = classToken end
    end

    promoterClass = promoterClass or ""
    if promoterName and promoterName ~= "" and promoterName ~= "Desconhecido" and promoterClass == "" and _G.GM and _G.GM.memberService then
        local p = _G.GM.memberService:getMember(promoterName)
        if p then promoterClass = p:getClass() or "" end
    end

    local message = self:formatPromotionMessage(memberName, promoterName, oldRank, newRank, memberClass, promoterClass)

    local newLog = Log:new({
        name = memberName,
        class = memberClass,
        guid = guid,
        message = message,
        event = LogEvent.PROMOTION,
        promoter = promoterName or "",
        promoterClass = promoterClass or "",
        oldRank = oldRank or "",
        newRank = newRank or "",
        oldRankIndex = oldRankIndex,
        newRankIndex = newRankIndex,
        timestamp = timestamp,
        date = dateStr,
    })

    self._repository:save(newLog)
    return newLog, true
end

--- Formata a mensagem padrão obrigatória para o evento DEMOTION.
--- Padrão: "Player X foi REBAIXADO a CargoNovo por Player Y (anterior: CargoAntigo)" com cores temáticas.
---@param demotedName string @Nome do personagem rebaixado
---@param demoterName string|nil @Nome de quem o rebaixou
---@param oldRank string|nil @Cargo anterior
---@param newRank string @Novo cargo alcançado
---@param demotedClass string|nil @Classe do rebaixado
---@param demoterClass string|nil @Classe do autor do rebaixamento
---@return string
function LogService:formatDemotionMessage(demotedName, demoterName, oldRank, newRank, demotedClass, demoterClass)
    local demoter = (demoterName and demoterName ~= "") and demoterName or "Desconhecido"
    local coloredDemoted = self:formatColoredMemberName(demotedName, demotedClass)
    local coloredDemoter
    if demoter ~= "Desconhecido" then
        coloredDemoter = self:formatColoredMemberName(demoter, demoterClass)
    else
        coloredDemoter = "|cff888888Desconhecido|r"
    end
    local rankStr = (newRank and newRank ~= "") and newRank or "Novo Cargo"
    local rankChangeStr = ""
    if oldRank and oldRank ~= "" and oldRank ~= newRank then
        rankChangeStr = string.format(" |cff888888(anterior: |cffffffff%s|r)|r", oldRank)
    end
    return string.format("%s |cffffa6a6foi|r |cffff7043REBAIXADO|r |cffffa6a6a|r |cffffff00%s|r |cffffa6a6por|r %s%s", coloredDemoted, rankStr, coloredDemoter, rankChangeStr)
end

--- Verifica se existe algum log de rebaixamento (DEMOTION) para o personagem.
---@param name string
---@param newRank string|nil
---@param timestamp number|nil
---@return boolean
function LogService:hasDemotionLog(name, newRank, timestamp)
    if self._repository and self._repository.hasDemotionLog then
        return self._repository:hasDemotionLog(name, newRank, timestamp)
    end
    return false
end

--- Registra o evento de rebaixamento (DEMOTION) de um membro para um cargo menor.
--- Armazena quem rebaixou, quem foi rebaixado, o cargo anterior e o cargo novo.
--- Evita duplicidade se o rebaixamento já tiver sido registrado recentemente.
---@param member Member|string @Instância do membro rebaixado ou nome
---@param demoterName string|nil @Nome de quem rebaixou
---@param oldRank string|nil @Cargo anterior
---@param newRank string @Novo cargo alcançado
---@param oldRankIndex number|nil @Índice do cargo anterior
---@param newRankIndex number|nil @Índice do novo cargo
---@param timestamp number|nil @Timestamp Unix do evento (opcional)
---@param dateStr string|nil @Data legível formatada (opcional)
---@param demoterClass string|nil @Token da classe de quem rebaixou (opcional)
---@return Log|nil, boolean @Retorna a entidade Log e se foi criada (true) ou atualizada/já existia (false)
function LogService:logMemberDemotion(member, demoterName, oldRank, newRank, oldRankIndex, newRankIndex, timestamp, dateStr, demoterClass)
    if not member or not newRank or newRank == "" then
        return nil, false
    end

    local memberName = ""
    local memberClass = ""
    local guid = ""
    if type(member) == "table" and member.getName then
        memberName = member:getName()
        memberClass = member:getClass() or ""
        guid = member:getGuid() or ""
        if not oldRank or oldRank == "" then
            oldRank = member:getRankName() or ""
        end
        if not oldRankIndex then
            oldRankIndex = member:getRankIndex()
        end
    else
        memberName = tostring(member)
    end

    if memberName == "" then
        return nil, false
    end

    -- 1. Verifica se já existe um log recente de rebaixamento para este personagem e cargo
    if self._repository and self._repository.findRecentDemotionLog then
        local existingLog = self._repository:findRecentDemotionLog(memberName, newRank, 600)
        if existingLog then
            local modified = false
            local curDemoter = existingLog:getDemoter()
            if (curDemoter == "" or curDemoter == "Desconhecido") and demoterName and demoterName ~= "" and demoterName ~= "Desconhecido" then
                existingLog:setDemoter(demoterName)
                if demoterClass and demoterClass ~= "" then
                    existingLog:setDemoterClass(demoterClass)
                end
                modified = true
            end
            local curOldRank = existingLog:getOldRank()
            if (curOldRank == "" or curOldRank == newRank) and oldRank and oldRank ~= "" and oldRank ~= newRank then
                existingLog:setOldRank(oldRank)
                if oldRankIndex then
                    existingLog:setOldRankIndex(oldRankIndex)
                end
                modified = true
            end

            if modified then
                local dName = existingLog:getDemoter()
                local dClass = existingLog:getDemoterClass()
                local oRank = existingLog:getOldRank()
                existingLog:setMessage(self:formatDemotionMessage(memberName, dName, oRank, newRank, existingLog:getClass(), dClass))
                self._repository:save(existingLog)
            end
            return existingLog, false
        end
    end

    -- 2. Resolve classes se não informadas
    if memberClass == "" and _G.GM and _G.GM.memberService then
        local m = _G.GM.memberService:getMember(memberName)
        if m then
            memberClass = m:getClass() or ""
            if guid == "" then guid = m:getGuid() or "" end
            if (not oldRank or oldRank == "") and m:getRankName() ~= "" and m:getRankName() ~= newRank then
                oldRank = m:getRankName()
            end
            if not oldRankIndex then
                oldRankIndex = m:getRankIndex()
            end
        end
    end
    if memberClass == "" and guid ~= "" and GetPlayerInfoByGUID then
        local _, classToken = GetPlayerInfoByGUID(guid)
        if classToken then memberClass = classToken end
    end

    demoterClass = demoterClass or ""
    if demoterName and demoterName ~= "" and demoterName ~= "Desconhecido" and demoterClass == "" and _G.GM and _G.GM.memberService then
        local p = _G.GM.memberService:getMember(demoterName)
        if p then demoterClass = p:getClass() or "" end
    end

    local message = self:formatDemotionMessage(memberName, demoterName, oldRank, newRank, memberClass, demoterClass)

    local newLog = Log:new({
        name = memberName,
        class = memberClass,
        guid = guid,
        message = message,
        event = LogEvent.DEMOTION,
        demoter = demoterName or "",
        demoterClass = demoterClass or "",
        promoter = demoterName or "",
        promoterClass = demoterClass or "",
        oldRank = oldRank or "",
        newRank = newRank or "",
        oldRankIndex = oldRankIndex,
        newRankIndex = newRankIndex,
        timestamp = timestamp,
        date = dateStr,
    })

    self._repository:save(newLog)
    return newLog, true
end

--- Remove do banco de dados registros de JOINED de personagens que nunca entraram na guilda (foram apenas convidados).
---@param memberService table|nil
---@return number @Quantidade de registros removidos
function LogService:cleanInvalidInviteJoinedLogs(memberService)
    local mService = memberService or (_G.GM and _G.GM.memberService)
    if not mService or not self._repository or not self._repository.removeInvalidJoinedLogs then
        return 0
    end

    local isRosterInit = (_G.GM_DB and _G.GM_DB.rosterInitialized)
    if not isRosterInit and mService._repository and mService._repository:count() == 0 then
        return 0
    end

    local count = self._repository:removeInvalidJoinedLogs(mService)
    if count > 0 then
        print(string.format("|cff00ff00[GuildManager]|r %d log(s) de convites não aceitos foram removidos do registro.", count))
    end
    return count
end

--- Define a referência ao serviço de membros.
---@param memberService table
function LogService:setMemberService(memberService)
    self._memberService = memberService
end

--- Remove do banco de dados registros de LEFT que foram falsamente registrados logo após o JOINED
--- devido a atraso de propagação do roster pela Blizzard, para membros que permanecem na guilda.
---@param memberService table|nil
---@param activeRosterNames table|nil
---@return number @Quantidade de registros removidos
function LogService:cleanInvalidLeftLogs(memberService, activeRosterNames)
    local mService = memberService or self._memberService or (_G.GM and _G.GM.memberService)
    if not mService or not self._repository or not self._repository.removeInvalidLeftLogs then
        return 0
    end

    local count = self._repository:removeInvalidLeftLogs(mService, activeRosterNames)
    if count > 0 then
        print(string.format("|cff00ff00[GuildManager]|r %d log(s) de saída indevidos (falso positivo pós-entrada) foram removidos do registro.", count))
    end
    return count
end

--- Remove do banco de dados registros de KICK invertidos onde o jogador local foi colocado como expulso.
---@param memberService table|nil
---@return number @Quantidade de registros removidos
function LogService:cleanInvertedKickLogs(memberService)
    local mService = memberService or self._memberService or (_G.GM and _G.GM.memberService)
    if not mService or not self._repository or not self._repository.cleanInvertedKickLogs then
        return 0
    end

    local count = self._repository:cleanInvertedKickLogs(mService)
    if count > 0 then
        print(string.format("|cff00ff00[GuildManager]|r %d log(s) de expulsão invertidos foram corrigidos.", count))
    end
    return count
end


