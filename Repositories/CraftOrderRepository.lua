---@class CraftOrderRepository
--- Repositório para persistência e recuperação de pedidos de fabricação (CraftOrder) no SavedVariables (GM_DB).
---@field private _db table @Referência à tabela raiz GM_DB
---@field private _cache table<string, CraftOrder>
CraftOrderRepository = {}
CraftOrderRepository.__index = CraftOrderRepository

---@param db table @Tabela raiz GM_DB
---@return CraftOrderRepository
function CraftOrderRepository:new(db)
    local instance = setmetatable({}, self)
    instance._db = db or {}
    if type(instance._db.craftOrders) ~= "table" then
        instance._db.craftOrders = {}
    end
    instance._cache = {}
    return instance
end

--- Atualiza a referência de banco de dados do repositório (ex: na troca de guilda).
---@param db table
function CraftOrderRepository:setDatabase(db)
    self._db = db or {}
    if type(self._db.craftOrders) ~= "table" then
        self._db.craftOrders = {}
    end
    self._cache = {}
end

--- Salva ou atualiza um pedido no banco de dados
---@param order CraftOrder
---@return boolean
function CraftOrderRepository:save(order)
    if not order or type(order.getId) ~= "function" or type(order.serialize) ~= "function" then
        return false
    end
    local id = order:getId()
    if not id or id == "" then return false end

    if type(self._db.craftOrders) ~= "table" then
        self._db.craftOrders = {}
    end

    self._db.craftOrders[id] = order:serialize()
    self._cache[id] = order
    return true
end

--- Busca um pedido pelo identificador
---@param id string
---@return CraftOrder|nil
function CraftOrderRepository:findById(id)
    if not id or id == "" or type(self._db.craftOrders) ~= "table" then return nil end
    if self._cache[id] then return self._cache[id] end

    local raw = self._db.craftOrders[id]
    if raw then
        local order = CraftOrder:new(raw)
        self._cache[id] = order
        return order
    end
    return nil
end

--- Retorna todos os pedidos de fabricação cadastrados
--- Ordenados decrescente pela data de criação/atualização
---@return CraftOrder[]
function CraftOrderRepository:findAll()
    local result = {}
    if type(self._db.craftOrders) ~= "table" then
        return result
    end

    for id, raw in pairs(self._db.craftOrders) do
        if raw.status == "CANCELLED" or (type(raw) == "table" and raw._status == "CANCELLED") then
            -- Remove pedidos cancelados do banco persistente
            self._db.craftOrders[id] = nil
            self._cache[id] = nil
        else
            local order = self._cache[id]
            if not order then
                order = CraftOrder:new(raw)
                self._cache[id] = order
            end
            table.insert(result, order)
        end
    end

    table.sort(result, function(a, b)
        return (a:getUpdatedAt() or 0) > (b:getUpdatedAt() or 0)
    end)

    return result
end

--- Remove um pedido do banco
---@param id string
---@return boolean
function CraftOrderRepository:delete(id)
    if not id or type(self._db.craftOrders) ~= "table" or not self._db.craftOrders[id] then
        return false
    end
    self._db.craftOrders[id] = nil
    self._cache[id] = nil
    return true
end

--- Retorna a quantidade total de pedidos
---@return number
function CraftOrderRepository:count()
    if type(self._db.craftOrders) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(self._db.craftOrders) do
        count = count + 1
    end
    return count
end
