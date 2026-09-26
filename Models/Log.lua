---@alias LogEventType
---| "JOINED"
---| "LEFT"
---| "KICK"
---| "LEVELED"
---| "OFFICERNOTE"
---| "PUBLICNOTE"
---| "NAMECHANGE"
---| "INACTIVERETURN"

--- Enum de Eventos de Log suportados pelo GuildManager
local RAW_EVENTS = {
    JOINED = "JOINED",
    LEFT = "LEFT",
    KICK = "KICK",
    LEVELED = "LEVELED",
    OFFICERNOTE = "OFFICERNOTE",
    PUBLICNOTE = "PUBLICNOTE",
    NAMECHANGE = "NAMECHANGE",
    INACTIVERETURN = "INACTIVERETURN",
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
---@field OFFICERNOTE "OFFICERNOTE" @Nota de oficial foi alterada
---@field PUBLICNOTE "PUBLICNOTE" @Nota pública foi alterada
---@field NAMECHANGE "NAMECHANGE" @Membro alterou o nome do personagem
---@field INACTIVERETURN "INACTIVERETURN" @Membro inativo retornou à atividade
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

    local event = data.event
    if event == "LEAVED" then
        event = LogEvent.LEFT
    end
    if Log.isValidEvent(event) then
        instance._event = event
    else
        instance._event = event or ""
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
    self._message = tostring(message or "")
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

--- Serializa a entidade Log em uma tabela Lua pura para persistência no banco de dados.
---@return table
function Log:serialize()
    return {
        id = self._id,
        name = self._name,
        class = self._class,
        guid = self._guid,
        message = self._message,
        event = self._event,
        recruiter = self._recruiter,
        recruiterClass = self._recruiterClass,
        kicker = self._kicker,
        kickerClass = self._kickerClass,
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
