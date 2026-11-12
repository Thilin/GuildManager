---@class LFGRepository
---@field private _db table @Referência à tabela do banco de dados persistente (GM_DB)
LFGRepository = {}
LFGRepository.__index = LFGRepository

--- Construtor do repositório de cards de procura de grupo (LFG).
---@param db table
---@return LFGRepository
function LFGRepository:new(db)
    local instance = setmetatable({}, self)

    instance._db = db or {}
    if type(instance._db.lfgCards) ~= "table" then
        instance._db.lfgCards = {}
    end

    return instance
end

--- Atualiza a referência de banco de dados do repositório (ex: na troca de guilda).
---@param db table
function LFGRepository:setDatabase(db)
    self._db = db or {}
    if type(self._db.lfgCards) ~= "table" then
        self._db.lfgCards = {}
    end
end

--- Persiste ou atualiza uma entidade LFGCard no banco de dados.
---@param card LFGCard
---@return boolean
function LFGRepository:save(card)
    if not card or type(card.getId) ~= "function" or type(card.serialize) ~= "function" then
        return false
    end

    local id = card:getId()
    if not id or id == "" then
        return false
    end

    if type(self._db.lfgCards) ~= "table" then
        self._db.lfgCards = {}
    end

    self._db.lfgCards[id] = card:serialize()
    return true
end

--- Deleta um card do banco de dados pelo ID.
---@param id string
---@return boolean
function LFGRepository:delete(id)
    if not id or id == "" or type(self._db.lfgCards) ~= "table" then
        return false
    end

    if self._db.lfgCards[id] then
        self._db.lfgCards[id] = nil
        return true
    end
    return false
end

--- Duração de validade de um card de LFG: 72 horas (em segundos)
local LFG_CARD_LIFETIME = 72 * 3600

--- Remove cards que já ultrapassaram o tempo limite de 72 horas.
---@param currentTime number|nil
---@return number @Quantidade de cards expirados removidos
function LFGRepository:cleanExpired(currentTime)
    if type(self._db.lfgCards) ~= "table" then return 0 end
    local now = currentTime or (time and time()) or 0
    local removedCount = 0

    for id, raw in pairs(self._db.lfgCards) do
        local createdAt = tonumber(raw.createdAt) or 0
        if (now - createdAt) >= LFG_CARD_LIFETIME then
            self._db.lfgCards[id] = nil
            removedCount = removedCount + 1
        end
    end

    return removedCount
end

--- Busca um card pelo ID.
---@param id string
---@return LFGCard|nil
function LFGRepository:findById(id)
    if not id or id == "" or type(self._db.lfgCards) ~= "table" then
        return nil
    end

    local raw = self._db.lfgCards[id]
    if raw then
        local card = LFGCard:new(raw)
        if card:isExpired() then
            self._db.lfgCards[id] = nil
            return nil
        end
        return card
    end
    return nil
end

--- Retorna todos os cards de procura de grupo cadastrados (expira automaticamente após 72h).
---@return LFGCard[]
function LFGRepository:findAll()
    local result = {}
    if type(self._db.lfgCards) ~= "table" then
        return result
    end

    self:cleanExpired()

    for _, raw in pairs(self._db.lfgCards) do
        local card = LFGCard:new(raw)
        if not card:isExpired() then
            table.insert(result, card)
        end
    end

    table.sort(result, function(a, b)
        return (a:getCreatedAt() or 0) > (b:getCreatedAt() or 0)
    end)

    return result
end

--- Retorna cards filtrados por tipo de grupo.
---@param groupType string|nil
---@return LFGCard[]
function LFGRepository:findByType(groupType)
    local all = self:findAll()
    if not groupType or groupType == "ALL" or groupType == "" then
        return all
    end

    local filtered = {}
    for _, card in ipairs(all) do
        if card:getType() == groupType then
            table.insert(filtered, card)
        end
    end
    return filtered
end

--- Retorna todos os cards ativos criados pelo personagem informado (até 5).
---@param creatorName string
---@return LFGCard[]
function LFGRepository:findAllByCreator(creatorName)
    local result = {}
    if not creatorName or creatorName == "" or type(self._db.lfgCards) ~= "table" then
        return result
    end

    self:cleanExpired()

    for _, raw in pairs(self._db.lfgCards) do
        local card = LFGCard:new(raw)
        if not card:isExpired() and card:isCreator(creatorName) then
            table.insert(result, card)
        end
    end

    table.sort(result, function(a, b)
        return (a:getCreatedAt() or 0) > (b:getCreatedAt() or 0)
    end)

    return result
end

--- Retorna a quantidade de cards ativos de determinado criador.
---@param creatorName string
---@return number
function LFGRepository:countByCreator(creatorName)
    local list = self:findAllByCreator(creatorName)
    return #list
end

--- Busca um card criado por determinado personagem.
---@param creatorName string
---@return LFGCard|nil
function LFGRepository:findByCreator(creatorName)
    if not creatorName or creatorName == "" or type(self._db.lfgCards) ~= "table" then
        return nil
    end

    self:cleanExpired()

    for _, raw in pairs(self._db.lfgCards) do
        local card = LFGCard:new(raw)
        if not card:isExpired() and card:isCreator(creatorName) then
            return card
        end
    end
    return nil
end

--- Deleta card criado pelo personagem informado.
---@param creatorName string
---@return boolean
function LFGRepository:deleteByCreator(creatorName)
    local card = self:findByCreator(creatorName)
    if card then
        return self:delete(card:getId())
    end
    return false
end

_G.LFGRepository = LFGRepository

