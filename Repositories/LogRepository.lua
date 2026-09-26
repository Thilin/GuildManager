---@class LogRepository
---@field private _db table @Referência à tabela raiz do banco de dados persistente (GM_DB)
LogRepository = {}
LogRepository.__index = LogRepository

--- Construtor do repositório de logs.
---@param db table @Tabela raiz do banco de dados persistente (GM_DB)
---@return LogRepository
function LogRepository:new(db)
    local instance = setmetatable({}, self)

    instance._db = db or {}
    if type(instance._db.logs) ~= "table" then
        instance._db.logs = {}
    end

    return instance
end

--- Salva ou atualiza uma entidade Log no banco de dados.
---@param log Log @Instância da entidade Log a ser persistida
---@return boolean @Retorna true se salvo com sucesso
function LogRepository:save(log)
    if not log or type(log.serialize) ~= "function" then
        return false
    end

    if type(self._db.logs) ~= "table" then
        self._db.logs = {}
    end

    local logId = log:getId()
    if logId and self._db.logs[logId] then
        -- Atualiza log existente
        local serialized = log:serialize()
        serialized.id = logId
        self._db.logs[logId] = serialized
        return true
    end

    -- Cria um novo registro
    local serialized = log:serialize()
    table.insert(self._db.logs, serialized)
    local newId = #self._db.logs
    serialized.id = newId
    log:setId(newId)

    return true
end

--- Retorna todas as entidades Log salvas no banco de dados.
---@return Log[]
function LogRepository:findAll()
    local result = {}
    if type(self._db.logs) ~= "table" then
        return result
    end

    for idx, rawData in ipairs(self._db.logs) do
        rawData.id = rawData.id or idx
        table.insert(result, Log:new(rawData))
    end

    return result
end

--- Busca todos os logs associados a um determinado personagem.
---@param name string @Nome do personagem
---@return Log[]
function LogRepository:findByName(name)
    local result = {}
    if not name or name == "" or type(self._db.logs) ~= "table" then
        return result
    end

    local lowerName = name:lower()
    for idx, rawData in ipairs(self._db.logs) do
        if rawData.name and rawData.name:lower() == lowerName then
            rawData.id = rawData.id or idx
            table.insert(result, Log:new(rawData))
        end
    end

    return result
end

--- Busca o registro de evento JOINED de um determinado personagem (por nome ou GUID).
---@param name string @Nome do personagem
---@param guid string|nil @GUID do personagem (opcional)
---@return Log|nil, number|nil @Retorna a entidade Log (se encontrada) e o índice no banco
function LogRepository:findJoinedLog(name, guid)
    if type(self._db.logs) ~= "table" then
        return nil, nil
    end

    local lowerName = (name and name ~= "") and name:lower() or nil
    for idx, rawData in ipairs(self._db.logs) do
        if rawData.event == LogEvent.JOINED then
            local matchName = lowerName and rawData.name and rawData.name:lower() == lowerName
            local matchGuid = guid and guid ~= "" and rawData.guid and rawData.guid == guid
            if matchName or matchGuid then
                rawData.id = rawData.id or idx
                return Log:new(rawData), idx
            end
        end
    end

    return nil, nil
end

--- Busca um log recente de saída (LEFT) para evitar registros duplicados.
---@param name string
---@param withinSeconds number|nil
---@return Log|nil
function LogRepository:findRecentLeaveLog(name, withinSeconds)
    if not name or name == "" or type(self._db.logs) ~= "table" then
        return nil
    end

    local lowerName = name:lower()
    local now = (GetServerTime and GetServerTime()) or (time and time()) or (os and os.time and os.time()) or 0
    local threshold = withinSeconds or 600

    for i = #self._db.logs, 1, -1 do
        local rawData = self._db.logs[i]
        if rawData and (rawData.event == "LEAVED" or rawData.event == "LEFT") then
            if rawData.name and rawData.name:lower() == lowerName then
                local logTime = rawData.timestamp or 0
                if now == 0 or logTime == 0 or (now - logTime) <= threshold then
                    rawData.id = rawData.id or i
                    return Log:new(rawData)
                end
            end
        end
    end

    return nil
end

--- Busca um log recente de expulsão (KICK) para evitar registros duplicados.
---@param name string
---@param withinSeconds number|nil
---@return Log|nil, number|nil
function LogRepository:findRecentKickLog(name, withinSeconds)
    if not name or name == "" or type(self._db.logs) ~= "table" then
        return nil, nil
    end

    local lowerName = name:lower()
    local now = (GetServerTime and GetServerTime()) or (time and time()) or (os and os.time and os.time()) or 0
    local threshold = withinSeconds or 600

    for i = #self._db.logs, 1, -1 do
        local rawData = self._db.logs[i]
        if rawData and rawData.event == "KICK" then
            if rawData.name and rawData.name:lower() == lowerName then
                local logTime = rawData.timestamp or 0
                if now == 0 or logTime == 0 or (now - logTime) <= threshold then
                    rawData.id = rawData.id or i
                    return Log:new(rawData), i
                end
            end
        end
    end

    return nil, nil
end

--- Verifica se existe algum log de saída (LEFT) registrado para o personagem.
--- Se eventTimestamp for informado, verifica se existe log no mesmo período (diferença <= 2 horas).
---@param name string
---@param eventTimestamp number|nil
---@return boolean
function LogRepository:hasLeaveLog(name, eventTimestamp)
    if not name or name == "" or type(self._db.logs) ~= "table" then
        return false
    end

    local lowerName = name:lower()
    for i = #self._db.logs, 1, -1 do
        local rawData = self._db.logs[i]
        if rawData and (rawData.event == "LEFT" or rawData.event == "LEAVED") then
            if rawData.name and rawData.name:lower() == lowerName then
                if not eventTimestamp or eventTimestamp == 0 then
                    return true
                end
                local logTime = rawData.timestamp or 0
                if logTime == 0 or math.abs(logTime - eventTimestamp) <= 7200 then
                    return true
                end
            end
        end
    end

    return false
end

--- Verifica se existe algum log de expulsão (KICK) registrado para o personagem.
--- Se eventTimestamp for informado, verifica se existe log no mesmo período (diferença <= 2 horas).
---@param name string
---@param eventTimestamp number|nil
---@return boolean
function LogRepository:hasKickLog(name, eventTimestamp)
    if not name or name == "" or type(self._db.logs) ~= "table" then
        return false
    end

    local lowerName = name:lower()
    for i = #self._db.logs, 1, -1 do
        local rawData = self._db.logs[i]
        if rawData and rawData.event == "KICK" then
            if rawData.name and rawData.name:lower() == lowerName then
                if not eventTimestamp or eventTimestamp == 0 then
                    return true
                end
                local logTime = rawData.timestamp or 0
                if logTime == 0 or math.abs(logTime - eventTimestamp) <= 7200 then
                    return true
                end
            end
        end
    end

    return false
end

--- Busca um log existente de evolução de nível (LEVELED) para o personagem e nível especificados.
---@param name string @Nome do personagem
---@param level number @Nível alcançado
---@return Log|nil
function LogRepository:findLeveledLog(name, level)
    if not name or name == "" or type(self._db.logs) ~= "table" then
        return nil
    end

    local lowerName = name:lower()
    local targetLevel = tonumber(level)

    for i = #self._db.logs, 1, -1 do
        local rawData = self._db.logs[i]
        if rawData and rawData.event == "LEVELED" then
            if rawData.name and rawData.name:lower() == lowerName then
                if targetLevel then
                    local logLvl = tonumber(rawData.level)
                    if logLvl == targetLevel then
                        rawData.id = rawData.id or i
                        return Log:new(rawData)
                    end
                    if rawData.message and rawData.message:find("nível " .. targetLevel, 1, true) then
                        rawData.id = rawData.id or i
                        return Log:new(rawData)
                    end
                else
                    rawData.id = rawData.id or i
                    return Log:new(rawData)
                end
            end
        end
    end

    return nil
end

--- Retorna a quantidade total de logs registrados.
---@return number
function LogRepository:count()
    if type(self._db.logs) ~= "table" then
        return 0
    end
    return #self._db.logs
end

--- Retorna a referência direta à tabela bruta de logs no GM_DB.
---@return table
function LogRepository:getAllRaw()
    if type(self._db.logs) ~= "table" then
        self._db.logs = {}
    end
    return self._db.logs
end

--- Limpa todos os logs do repositório.
function LogRepository:wipe()
    if self._db and type(self._db.logs) == "table" then
        if table.wipe then
            table.wipe(self._db.logs)
        elseif wipe then
            wipe(self._db.logs)
        else
            for k in pairs(self._db.logs) do
                self._db.logs[k] = nil
            end
        end
    end
end

--- Remove logs do tipo JOINED de personagens que não existem no cadastro de membros (apenas receberam convite e nunca entraram).
---@param memberService table
---@return number @Quantidade de registros removidos
function LogRepository:removeInvalidJoinedLogs(memberService)
    if not memberService or type(self._db.logs) ~= "table" then
        return 0
    end

    local removedCount = 0
    for i = #self._db.logs, 1, -1 do
        local rawData = self._db.logs[i]
        if rawData and (rawData.event == "JOINED" or rawData.event == "join") then
            local name = rawData.name or ""
            local member = memberService:getMember(name)
            -- Se o membro nem existe no banco de membros, ele nunca esteve no roster da guilda
            if not member then
                table.remove(self._db.logs, i)
                removedCount = removedCount + 1
            end
        end
    end

    -- Re-indexa os IDs após a remoção
    if removedCount > 0 then
        for idx, rawData in ipairs(self._db.logs) do
            rawData.id = idx
        end
    end

    return removedCount
end

--- Remove logs do tipo LEFT de personagens que continuam ativos na guilda e cujo log de LEFT
--- foi registrado indevidamente logo após o evento de JOINED (falso positivo por delay de roster).
---@param memberService table
---@param activeRosterNames table|nil
---@return number @Quantidade de registros removidos
function LogRepository:removeInvalidLeftLogs(memberService, activeRosterNames)
    if not memberService or type(self._db.logs) ~= "table" then
        return 0
    end

    local removedCount = 0
    for i = #self._db.logs, 1, -1 do
        local rawData = self._db.logs[i]
        if rawData and (rawData.event == "LEFT" or rawData.event == "LEAVED") then
            local name = rawData.name or ""
            local lowerName = name:lower()
            local member = memberService:getMember(name)
            local isInRoster = (activeRosterNames and (activeRosterNames[name] or activeRosterNames[lowerName])) or (member and member:isInGuild())

            if isInRoster then
                local joinedLog = self:findJoinedLog(name, member and member:getGuid())
                local isFalsePositive = false

                if joinedLog then
                    local leftTime = rawData.timestamp or 0
                    local joinedTime = joinedLog:getTimestamp() or 0
                    local leftDate = rawData.date or ""
                    local joinedDate = joinedLog:getDate() or ""

                    if leftTime > 0 and joinedTime > 0 then
                        if math.abs(leftTime - joinedTime) <= 600 then
                            isFalsePositive = true
                        end
                    elseif leftDate ~= "" and joinedDate ~= "" then
                        local leftDay = leftDate:match("^(%d%d%d%d%-%d%d%-%d%d)") or leftDate
                        local joinedDay = joinedDate:match("^(%d%d%d%d%-%d%d%-%d%d)") or joinedDate
                        if leftDay == joinedDay then
                            isFalsePositive = true
                        end
                    else
                        -- Se ambos não têm timestamp/data detalhada, mas o membro está ativo
                        isFalsePositive = true
                    end
                end

                if isFalsePositive then
                    table.remove(self._db.logs, i)
                    removedCount = removedCount + 1

                    if member then
                        member:setInGuild(true)
                        member:setDateLeft("")
                        if (member:getTimesLeft() or 0) > 0 then
                            member:setTimesLeft(math.max(0, member:getTimesLeft() - 1))
                        end
                        memberService:saveMember(member)
                    end
                end
            end
        end
    end

    if removedCount > 0 then
        for idx, rawData in ipairs(self._db.logs) do
            rawData.id = idx
        end
    end

    return removedCount
end

--- Remove logs de expulsão (KICK) invertidos onde o jogador local foi registrado falsamente como expulso
--- mesmo continuando na guilda, enquanto quem ele removeu foi registrado como kicker.
---@param memberService table
---@return number @Quantidade de registros removidos
function LogRepository:cleanInvertedKickLogs(memberService)
    if not memberService or type(self._db.logs) ~= "table" then
        return 0
    end

    local myName = UnitName and UnitName("player") or ""
    if myName == "" or not IsInGuild or not IsInGuild() then
        return 0
    end
    local myLower = myName:lower()

    local removedCount = 0
    for i = #self._db.logs, 1, -1 do
        local rawData = self._db.logs[i]
        if rawData and rawData.event == "KICK" then
            local name = rawData.name or ""
            if name:lower() == myLower then
                table.remove(self._db.logs, i)
                removedCount = removedCount + 1

                local myMember = memberService:getMember(myName)
                if myMember and not myMember:isInGuild() then
                    myMember:setInGuild(true)
                    myMember:setDateLeft("")
                    if (myMember:getTimesLeft() or 0) > 0 then
                        myMember:setTimesLeft(math.max(0, myMember:getTimesLeft() - 1))
                    end
                    memberService:saveMember(myMember)
                end
            end
        end
    end

    if removedCount > 0 then
        for idx, rawData in ipairs(self._db.logs) do
            rawData.id = idx
        end
    end

    return removedCount
end



