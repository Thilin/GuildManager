---@alias LogEventType
---| "JOINED"
---| "LEFT"
---| "KICK"
---| "LEVELED"
---| "PROMOTION"
---| "DEMOTION"
---| "OFFICERNOTE"
---| "PUBLICNOTE"
---| "NAMECHANGE"
---| "INACTIVERETURN"
---| "REJOINED"

--- Enum de Eventos de Log suportados pelo GuildManager
local RAW_EVENTS = {
    JOINED = "JOINED",
    LEFT = "LEFT",
    KICK = "KICK",
    LEVELED = "LEVELED",
    PROMOTION = "PROMOTION",
    DEMOTION = "DEMOTION",
    OFFICERNOTE = "OFFICERNOTE",
    PUBLICNOTE = "PUBLICNOTE",
    NAMECHANGE = "NAMECHANGE",
    INACTIVERETURN = "INACTIVERETURN",
    REJOINED = "REJOINED",
}

-- Tabela para validação rápida O(1) de eventos válidos
local VALID_EVENTS = {}
for _, val in pairs(RAW_EVENTS) do
    VALID_EVENTS[val] = true
end

--- Metatable para garantir comportamento estrito de ENUM (somente leitura / imutável)
local enumMeta = {
    __index = RAW_EVENTS,
    __newindex = function(_, key)
        error(string.format("LogEvent é imutável. Tentativa inválida de atribuir ao campo '%s'.", tostring(key)), 2)
    end,
    __pairs = function()
        return pairs(RAW_EVENTS)
    end,
}

---@class LogEventsEnum
---@field JOINED "JOINED" @Membro entrou na guilda
---@field LEFT "LEFT" @Membro saiu da guilda
---@field KICK "KICK" @Membro foi expulso da guilda
---@field LEVELED "LEVELED" @Membro subiu de nível
---@field PROMOTION "PROMOTION" @Membro foi promovido para um cargo maior
---@field DEMOTION "DEMOTION" @Membro foi rebaixado para um cargo menor
---@field OFFICERNOTE "OFFICERNOTE" @Nota de oficial foi alterada
---@field PUBLICNOTE "PUBLICNOTE" @Nota pública foi alterada
---@field NAMECHANGE "NAMECHANGE" @Membro alterou o nome do personagem
---@field INACTIVERETURN "INACTIVERETURN" @Membro inativo retornou à atividade
---@field REJOINED "REJOINED" @Ex-membro retornou à guilda
LogEvent = setmetatable({}, enumMeta)

---@class Log
---@field _id number|nil @Identificador único do log
---@field _name string @Nome do personagem
---@field _class string @Token da classe do personagem (ex: WARRIOR)
---@field _guid string @GUID único do personagem no WoW
---@field _message string @Mensagem explicativa ou detalhe da alteração
---@field _event LogEventType @Tipo de evento associado (ENUM LogEvent)
---@field _recruiter string @Nome do recrutador (caso aplicável)
---@field _recruiterClass string @Token da classe do recrutador (caso aplicável)
---@field _kicker string @Nome de quem expulsou o membro (caso KICK)
---@field _kickerClass string @Token da classe de quem expulsou o membro (caso KICK)
---@field _promoter string @Nome de quem promoveu o membro (caso PROMOTION)
---@field _promoterClass string @Token da classe de quem promoveu o membro (caso PROMOTION)
---@field _demoter string @Nome de quem rebaixou o membro (caso DEMOTION)
---@field _demoterClass string @Token da classe de quem rebaixou o membro (caso DEMOTION)
---@field _oldRank string @Cargo anterior antes da alteração
---@field _newRank string @Novo cargo alcançado
---@field _oldRankIndex number|nil @Índice do cargo anterior
---@field _newRankIndex number|nil @Índice do novo cargo
---@field _dateLeft string @Data em que o membro saiu da guilda antes de retornar
---@field _lastRank string @Último cargo do membro antes de sair da guilda
---@field _timesLeft number @Quantidade de vezes que o membro saiu da guilda
---@field _timestamp number @Timestamp Unix de quando o evento ocorreu
---@field _date string @Data legível formatada (AAAA-MM-DD HH:MM:SS)
Log = {}
Log.__index = Log

-- Disponibiliza o Enum também como atributo estático da classe
Log.Event = LogEvent
Log.Events = LogEvent

--- Verifica se um evento informado é válido de acordo com o Enum LogEvent.
---@param event string|LogEventType
---@return boolean
function Log.isValidEvent(event)
    return type(event) == "string" and VALID_EVENTS[event] == true
end

--- Construtor da entidade Log.
--- Recebe uma tabela com os atributos e instancia o objeto de domínio.
---@param data table|nil @Tabela contendo os dados iniciais do log
---@return Log
function Log:new(data)
    local instance = setmetatable({}, self)
    data = data or {}

    -- Atributos obrigatórios do modelo:
    instance._id = tonumber(data.id)
    instance._name = data.name or data.characterName or ""
    instance._class = data.class or data.classToken or ""
    instance._guid = data.guid or ""
    instance._message = data.message or data.msg or ""
    instance._recruiter = data.recruiter or ""
    instance._recruiterClass = data.recruiterClass or ""
    instance._kicker = data.kicker or ""
    instance._kickerClass = data.kickerClass or ""
    instance._promoter = data.promoter or ""
    instance._promoterClass = data.promoterClass or ""
    instance._demoter = data.demoter or ""
    instance._demoterClass = data.demoterClass or ""
    instance._oldRank = data.oldRank or ""
    instance._newRank = data.newRank or ""
    instance._oldRankIndex = tonumber(data.oldRankIndex)
    instance._newRankIndex = tonumber(data.newRankIndex)
    instance._dateLeft = data.dateLeft or ""
    instance._lastRank = data.lastRank or data.oldRank or ""
    instance._timesLeft = tonumber(data.timesLeft) or 0
    instance._level = tonumber(data.level or data.newLevel)

    local event = data.event
    if event == "LEAVED" then
        event = LogEvent.LEFT
    end
    if Log.isValidEvent(event) then
        instance._event = event
    else
        instance._event = event or ""
    end

    if instance._event == LogEvent.LEVELED or instance._event == "LEVELED" then
        instance._message = instance._message:gsub("^%s*[Mm]embro%s+", "")
    end


    -- Metadados de data e hora para ordenação e histórico:
    local currentUnix = (GetServerTime and GetServerTime()) or (time and time()) or (os and os.time and os.time()) or 0
    instance._timestamp = tonumber(data.timestamp) or currentUnix

    if data.date and data.date ~= "" then
        instance._date = tostring(data.date)
    else
        local formattedDate = ""
        if date then
            formattedDate = date("%Y-%m-%d %H:%M:%S", instance._timestamp > 0 and instance._timestamp or nil)
        elseif os and os.date then
            formattedDate = os.date("%Y-%m-%d %H:%M:%S", instance._timestamp > 0 and instance._timestamp or nil)
        end
        instance._date = formattedDate
    end

    return instance
end

--- Obtém o nome do personagem associado ao log.
---@return string
function Log:getName()
    return self._name
end

--- Define o nome do personagem com validação.
---@param name string
function Log:setName(name)
    if type(name) == "string" then
        self._name = name
    end
end

--- Alias para getName().
---@return string
function Log:getCharacterName()
    return self:getName()
end

--- Alias para setName().
---@param characterName string
function Log:setCharacterName(characterName)
    self:setName(characterName)
end

--- Obtém o GUID do personagem.
---@return string
function Log:getGuid()
    return self._guid
end

--- Define o GUID do personagem.
---@param guid string
function Log:setGuid(guid)
    if type(guid) == "string" then
        self._guid = guid
    end
end

--- Obtém a mensagem do log.
---@return string
function Log:getMessage()
    return self._message
end

--- Define a mensagem do log.
---@param message string
function Log:setMessage(message)
    local msg = tostring(message or "")
    if self._event == LogEvent.LEVELED or self._event == "LEVELED" then
        msg = msg:gsub("^%s*[Mm]embro%s+", "")
    end
    self._message = msg
end

--- Obtém o tipo de evento (ENUM).
---@return LogEventType
function Log:getEvent()
    return self._event
end

--- Define o evento do log, validando contra o Enum LogEvent.
---@param event LogEventType|string
---@return boolean @Retorna true se o evento foi alterado com sucesso, false caso seja inválido
function Log:setEvent(event)
    if Log.isValidEvent(event) then
        self._event = event
        return true
    end
    return false
end

--- Obtém o timestamp Unix do log.
---@return number
function Log:getTimestamp()
    return self._timestamp
end

--- Define o timestamp Unix do log.
---@param timestamp number
function Log:setTimestamp(timestamp)
    local n = tonumber(timestamp)
    if n then
        self._timestamp = n
    end
end

--- Obtém a data e hora formatada do log.
---@return string
function Log:getDate()
    return self._date
end

--- Define a data e hora formatada do log.
---@param dateStr string
function Log:setDate(dateStr)
    self._date = tostring(dateStr or "")
end

--- Obtém o ID do log.
---@return number|nil
function Log:getId()
    return self._id
end

--- Define o ID do log.
---@param id number
function Log:setId(id)
    self._id = tonumber(id)
end

--- Obtém o recrutador associado ao log.
---@return string
function Log:getRecruiter()
    return self._recruiter or ""
end

--- Define o recrutador do log.
---@param recruiter string
function Log:setRecruiter(recruiter)
    self._recruiter = tostring(recruiter or "")
end

--- Obtém a classe do personagem.
---@return string
function Log:getClass()
    return self._class or ""
end

--- Define a classe do personagem.
---@param class string
function Log:setClass(class)
    self._class = tostring(class or "")
end

--- Obtém a classe do recrutador.
---@return string
function Log:getRecruiterClass()
    return self._recruiterClass or ""
end

--- Define a classe do recrutador.
---@param class string
function Log:setRecruiterClass(class)
    self._recruiterClass = tostring(class or "")
end

--- Obtém o nome de quem expulsou/removeu o membro (KICK).
---@return string
function Log:getKicker()
    return self._kicker or ""
end

--- Define quem expulsou/removeu o membro (KICK).
---@param kicker string
function Log:setKicker(kicker)
    self._kicker = tostring(kicker or "")
end

--- Obtém a classe de quem expulsou/removeu o membro (KICK).
---@return string
function Log:getKickerClass()
    return self._kickerClass or ""
end

--- Define a classe de quem expulsou/removeu o membro (KICK).
---@param class string
function Log:setKickerClass(class)
    self._kickerClass = tostring(class or "")
end

--- Obtém o nível associado ao log (evento LEVELED).
---@return number|nil
function Log:getLevel()
    return self._level
end

--- Define o nível associado ao log (evento LEVELED).
---@param level number
function Log:setLevel(level)
    self._level = tonumber(level)
end

--- Obtém o nome de quem promoveu o membro (PROMOTION).
---@return string
function Log:getPromoter()
    return self._promoter or ""
end

--- Define quem promoveu o membro (PROMOTION).
---@param promoter string
function Log:setPromoter(promoter)
    self._promoter = tostring(promoter or "")
end

--- Obtém a classe de quem promoveu o membro (PROMOTION).
---@return string
function Log:getPromoterClass()
    return self._promoterClass or ""
end

--- Define a classe de quem promoveu o membro (PROMOTION).
---@param class string
function Log:setPromoterClass(class)
    self._promoterClass = tostring(class or "")
end

--- Obtém o cargo anterior do membro promovido.
---@return string
function Log:getOldRank()
    return self._oldRank or ""
end

--- Define o cargo anterior do membro promovido.
---@param oldRank string
function Log:setOldRank(oldRank)
    self._oldRank = tostring(oldRank or "")
end

--- Obtém o novo cargo do membro promovido.
---@return string
function Log:getNewRank()
    return self._newRank or ""
end

--- Define o novo cargo do membro promovido.
---@param newRank string
function Log:setNewRank(newRank)
    self._newRank = tostring(newRank or "")
end

--- Obtém o índice do cargo anterior.
---@return number|nil
function Log:getOldRankIndex()
    return self._oldRankIndex
end

--- Define o índice do cargo anterior.
---@param idx number
function Log:setOldRankIndex(idx)
    self._oldRankIndex = tonumber(idx)
end

--- Obtém o índice do novo cargo.
---@return number|nil
function Log:getNewRankIndex()
    return self._newRankIndex
end

--- Define o índice do novo cargo.
---@param idx number
function Log:setNewRankIndex(idx)
    self._newRankIndex = tonumber(idx)
end

--- Obtém o nome de quem rebaixou o membro (DEMOTION).
---@return string
function Log:getDemoter()
    return self._demoter or ""
end

--- Define quem rebaixou o membro (DEMOTION).
---@param demoter string
function Log:setDemoter(demoter)
    self._demoter = tostring(demoter or "")
end

--- Obtém a classe de quem rebaixou o membro (DEMOTION).
---@return string
function Log:getDemoterClass()
    return self._demoterClass or ""
end

--- Define a classe de quem rebaixou o membro (DEMOTION).
---@param class string
function Log:setDemoterClass(class)
    self._demoterClass = tostring(class or "")
end

--- Obtém a data em que o membro saiu da guilda antes de retornar (evento REJOINED).
---@return string
function Log:getDateLeft()
    return self._dateLeft or ""
end

--- Define a data em que o membro saiu da guilda antes de retornar (evento REJOINED).
---@param dateLeft string
function Log:setDateLeft(dateLeft)
    self._dateLeft = tostring(dateLeft or "")
end

--- Obtém o último cargo do membro antes de sair da guilda (evento REJOINED).
---@return string
function Log:getLastRank()
    return self._lastRank or self._oldRank or ""
end

--- Define o último cargo do membro antes de sair da guilda (evento REJOINED).
---@param lastRank string
function Log:setLastRank(lastRank)
    self._lastRank = tostring(lastRank or "")
    if not self._oldRank or self._oldRank == "" then
        self._oldRank = self._lastRank
    end
end

--- Obtém a quantidade de vezes que o membro saiu da guilda (evento REJOINED).
---@return number
function Log:getTimesLeft()
    return self._timesLeft or 0
end

--- Define a quantidade de vezes que o membro saiu da guilda (evento REJOINED).
---@param timesLeft number
function Log:setTimesLeft(timesLeft)
    local n = tonumber(timesLeft)
    if n then
        self._timesLeft = n
    end
end

--- Serializa a entidade Log em uma tabela Lua pura para persistência no banco de dados.
---@return table
function Log:serialize()
    return {
        id = self._id,
        name = self._name,
        class = self._class,
        guid = self._guid,
        level = self._level,
        message = self._message,
        event = self._event,
        recruiter = self._recruiter,
        recruiterClass = self._recruiterClass,
        kicker = self._kicker,
        kickerClass = self._kickerClass,
        promoter = self._promoter,
        promoterClass = self._promoterClass,
        demoter = self._demoter,
        demoterClass = self._demoterClass,
        oldRank = self._oldRank,
        newRank = self._newRank,
        oldRankIndex = self._oldRankIndex,
        newRankIndex = self._newRankIndex,
        dateLeft = self._dateLeft,
        lastRank = self._lastRank,
        timesLeft = self._timesLeft,
        timestamp = self._timestamp,
        date = self._date,
    }
end

--- Retorna uma representação legível em string para exibição ou debug.
---@return string
function Log:toString()
    return string.format("[%s] [%s] %s: %s", self._date or "", self._event or "", self._name or "", self._message or "")
end

--- Metamethod __tostring para permitir tostring(log)
Log.__tostring = Log.toString
