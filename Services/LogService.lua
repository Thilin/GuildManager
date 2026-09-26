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
--- Padrão: "Player X foi RECRUTADO por Player Y"
---@param recruitName string @Nome do personagem recrutado
---@param recruiterName string|nil @Nome do recrutador
---@return string
function LogService:formatJoinedMessage(recruitName, recruiterName)
    local recruiter = (recruiterName and recruiterName ~= "") and recruiterName or "Desconhecido"
    return string.format("%s foi RECRUTADO por %s", recruitName, recruiter)
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
            existingLog:setMessage(self:formatJoinedMessage(recruitName, recruiterName))
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
    local message = self:formatJoinedMessage(recruitName, recruiterName)
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
        existingLog:setMessage(self:formatJoinedMessage(recruitName, recruiterName))
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
