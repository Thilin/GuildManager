---@alias EventType
---| "RAID"
---| "DUNGEON"
---| "PVP"
---| "REUNIAO"
---| "ANIVERSARIO"
---| "OUTRO"

--- Enum dos tipos de eventos suportados pela agenda
local RAW_EVENT_TYPES = {
    RAID = "RAID",
    DUNGEON = "DUNGEON",
    PVP = "PVP",
    REUNIAO = "REUNIAO",
    ANIVERSARIO = "ANIVERSARIO",
    OUTRO = "OUTRO",
}

local enumMetaEventTypes = {
    __index = RAW_EVENT_TYPES,
    __newindex = function(_, k)
        error(string.format("EventType é imutável. Tentativa de atribuir a '%s'.", tostring(k)), 2)
    end,
}

EventType = setmetatable({}, enumMetaEventTypes)

--- Rótulos formatados dos tipos de eventos
EVENT_TYPE_LABELS = {
    RAID = "|cffff4444[Raide]|r",
    DUNGEON = "|cff3399ff[Masmorra]|r",
    PVP = "|cffff9900[JxJ / PvP]|r",
    REUNIAO = "|cff00ff88[Reunião]|r",
    ANIVERSARIO = "|cffffd200[Aniversário 🎂]|r",
    OUTRO = "|cffa0a0a0[Outro]|r",
}

--- Cores dos tipos de eventos
EVENT_TYPE_COLORS = {
    RAID = { 1.0, 0.27, 0.27 },
    DUNGEON = { 0.20, 0.60, 1.0 },
    PVP = { 1.0, 0.60, 0.0 },
    REUNIAO = { 0.0, 1.0, 0.53 },
    ANIVERSARIO = { 1.0, 0.82, 0.0 },
    OUTRO = { 0.65, 0.65, 0.65 },
}

---@class EventInviteeData
---@field name string @Nome do personagem convidado
---@field status string @Status do convite: "PENDENTE", "CONFIRMADO", "RECUSADO"
---@field class string|nil @Token da classe do personagem
---@field level number|nil @Nível do personagem
---@field invitedAt number|nil @Timestamp do convite

---@class Event
---@field private _id string @Identificador único do evento
---@field private _title string @Título ou nome do evento
---@field private _type EventType @Tipo do evento (RAID, DUNGEON, PVP, REUNIAO, ANIVERSARIO, OUTRO)
---@field private _date string @Data formatada (ex: "15/10/2026" ou "2026-10-15")
---@field private _time string @Horário formatado (ex: "20:00")
---@field private _description string @Descrição e notas detalhadas do evento
---@field private _creator string @Nome do personagem que criou o evento
---@field private _createdAt number @Timestamp de criação
---@field private _invitees EventInviteeData[] @Lista de membros convidados
Event = {}
Event.__index = Event

--- Construtor da entidade Event.
---@param data table|nil @Tabela com os atributos iniciais do evento
---@return Event
function Event:new(data)
    local instance = setmetatable({}, self)
    data = data or {}

    local curTime = (time and time()) or 0
    instance._id = data.id or (string.format("evt_%d_%d", curTime, math.random(1000, 9999)))
    instance._title = data.title or "Novo Evento"
    instance._type = data.type or EventType.OUTRO
    instance._date = data.date or ""
    instance._time = data.time or "20:00"
    instance._description = data.description or ""
    instance._creator = data.creator or ((UnitName and UnitName("player")) or "")
    instance._createdAt = data.createdAt or curTime
    instance._invitees = {}

    if type(data.invitees) == "table" then
        for _, inv in ipairs(data.invitees) do
            if type(inv) == "table" and inv.name and inv.name ~= "" then
                table.insert(instance._invitees, {
                    name = inv.name,
                    status = inv.status or "PENDENTE",
                    class = inv.class or "",
                    level = tonumber(inv.level) or 1,
                    invitedAt = inv.invitedAt or curTime,
                })
            elseif type(inv) == "string" and inv ~= "" then
                table.insert(instance._invitees, {
                    name = inv,
                    status = "PENDENTE",
                    class = "",
                    level = 1,
                    invitedAt = curTime,
                })
            end
        end
    end

    return instance
end

--- Obtém o ID do evento.
---@return string
function Event:getId()
    return self._id
end

--- Define o ID do evento.
---@param id string
function Event:setId(id)
    if type(id) == "string" and id ~= "" then
        self._id = id
    end
end

--- Obtém o título do evento.
---@return string
function Event:getTitle()
    return self._title
end

--- Define o título do evento.
---@param title string
function Event:setTitle(title)
    if type(title) == "string" then
        self._title = title
    end
end

--- Obtém o tipo do evento.
---@return EventType
function Event:getType()
    return self._type
end

--- Define o tipo do evento.
---@param eventType EventType
function Event:setType(eventType)
    if eventType and RAW_EVENT_TYPES[eventType] then
        self._type = eventType
    end
end

--- Obtém a data do evento.
---@return string
function Event:getDate()
    return self._date
end

--- Define a data do evento.
---@param dateStr string
function Event:setDate(dateStr)
    if type(dateStr) == "string" then
        self._date = dateStr
    end
end

--- Obtém o horário do evento.
---@return string
function Event:getTime()
    return self._time
end

--- Define o horário do evento.
---@param timeStr string
function Event:setTime(timeStr)
    if type(timeStr) == "string" then
        self._time = timeStr
    end
end

--- Obtém a descrição do evento.
---@return string
function Event:getDescription()
    return self._description
end

--- Define a descrição do evento.
---@param desc string
function Event:setDescription(desc)
    if type(desc) == "string" then
        self._description = desc
    end
end

--- Obtém o nome do criador do evento.
---@return string
function Event:getCreator()
    return self._creator
end

--- Define o nome do criador do evento.
---@param creator string
function Event:setCreator(creator)
    if type(creator) == "string" then
        self._creator = creator
    end
end

--- Obtém o timestamp de criação.
---@return number
function Event:getCreatedAt()
    return self._createdAt
end

--- Obtém a lista de convidados do evento.
---@return EventInviteeData[]
function Event:getInvitees()
    return self._invitees
end

--- Quantidade de convidados.
---@return number
function Event:getInviteeCount()
    return #self._invitees
end

--- Verifica se um membro já está convidado.
---@param memberName string
---@return boolean, number|nil @isInvited, index
function Event:hasInvitee(memberName)
    if not memberName or memberName == "" then return false, nil end
    local clean = (memberName:match("^[^-]+") or memberName):lower()
    for idx, inv in ipairs(self._invitees) do
        local invClean = (inv.name:match("^[^-]+") or inv.name):lower()
        if invClean == clean then
            return true, idx
        end
    end
    return false, nil
end

--- Adiciona um membro à lista de convidados.
---@param name string
---@param class string|nil
---@param level number|nil
---@param status string|nil
---@return boolean @true se adicionado, false se já existia
function Event:addInvitee(name, class, level, status)
    if not name or name == "" then return false end
    if self:hasInvitee(name) then return false end

    local curTime = (time and time()) or 0
    table.insert(self._invitees, {
        name = name,
        status = status or "PENDENTE",
        class = class or "",
        level = tonumber(level) or 1,
        invitedAt = curTime,
    })
    return true
end

--- Remove um convidado da lista pelo nome.
---@param name string
---@return boolean @true se removido com sucesso
function Event:removeInvitee(name)
    local has, idx = self:hasInvitee(name)
    if has and idx then
        table.remove(self._invitees, idx)
        return true
    end
    return false
end

--- Atualiza o status de resposta do convidado (ex: "CONFIRMADO", "RECUSADO").
---@param name string
---@param status string
---@return boolean
function Event:setInviteeStatus(name, status)
    local has, idx = self:hasInvitee(name)
    if has and idx then
        self._invitees[idx].status = status or "PENDENTE"
        return true
    end
    return false
end

--- Serializa a entidade Event para persistência em GM_DB.
---@return table
function Event:serialize()
    local serializedInvitees = {}
    for _, inv in ipairs(self._invitees) do
        table.insert(serializedInvitees, {
            name = inv.name,
            status = inv.status,
            class = inv.class,
            level = inv.level,
            invitedAt = inv.invitedAt,
        })
    end

    return {
        id = self._id,
        title = self._title,
        type = self._type,
        date = self._date,
        time = self._time,
        description = self._description,
        creator = self._creator,
        createdAt = self._createdAt,
        invitees = serializedInvitees,
    }
end

_G.Event = Event
_G.EventType = EventType
