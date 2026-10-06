---@class EventRepository
---@field private _db table @Referência à tabela raiz do banco de dados persistente (GM_DB)
EventRepository = {}
EventRepository.__index = EventRepository

--- Construtor do repositório de eventos da agenda.
---@param db table @Tabela raiz do banco de dados persistente (GM_DB)
---@return EventRepository
function EventRepository:new(db)
    local instance = setmetatable({}, self)

    instance._db = db or {}
    if type(instance._db.events) ~= "table" then
        instance._db.events = {}
    end

    return instance
end

--- Persiste ou atualiza uma entidade Event no banco de dados.
---@param event Event @Instância da entidade a ser gravada
---@return boolean @true se a gravação for bem-sucedida
function EventRepository:save(event)
    if not event or type(event.getId) ~= "function" or type(event.serialize) ~= "function" then
        return false
    end

    local id = event:getId()
    if not id or id == "" then
        return false
    end

    if type(self._db.events) ~= "table" then
        self._db.events = {}
    end

    self._db.events[id] = event:serialize()
    return true
end

--- Deleta um evento do banco de dados pelo ID.
---@param id string @Identificador do evento
---@return boolean @true se o evento foi removido
function EventRepository:delete(id)
    if not id or id == "" or type(self._db.events) ~= "table" then
        return false
    end

    if self._db.events[id] then
        self._db.events[id] = nil
        return true
    end
    return false
end

--- Busca um evento no banco de dados pelo ID.
---@param id string
---@return Event|nil
function EventRepository:findById(id)
    if not id or id == "" or type(self._db.events) ~= "table" then
        return nil
    end

    local data = self._db.events[id]
    if type(data) == "table" and Event and Event.new then
        return Event:new(data)
    end
    return nil
end

--- Retorna todos os eventos persistidos.
---@return Event[]
function EventRepository:findAll()
    local list = {}
    if type(self._db.events) ~= "table" then
        return list
    end

    for _, data in pairs(self._db.events) do
        if type(data) == "table" and Event and Event.new then
            table.insert(list, Event:new(data))
        end
    end

    return list
end

--- Retorna a quantidade total de eventos salvos.
---@return number
function EventRepository:count()
    local c = 0
    if type(self._db.events) == "table" then
        for _ in pairs(self._db.events) do
            c = c + 1
        end
    end
    return c
end

_G.EventRepository = EventRepository
