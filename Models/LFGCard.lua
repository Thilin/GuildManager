---@class LFGCard
---@field private _id string @Identificador único do card
---@field private _type GroupType @Tipo de grupo procurado (DUNGEON, RAID, MISC, FARM, QUESTS, PVP)
---@field private _time string @Horário previsto / disponibilidade
---@field private _description string @Descrição do card
---@field private _creator string @Nome completo do personagem criador (fixo e não editável)
---@field private _creatorClass string @Token da classe do criador
---@field private _creatorLevel number @Nível do criador
---@field private _createdAt number @Timestamp de criação
LFGCard = {}
LFGCard.__index = LFGCard

--- Duração padrão de validade de um card de LFG: 72 horas (em segundos)
local LFG_CARD_LIFETIME = 72 * 3600 -- 259200 segundos

--- Construtor da entidade LFGCard.
---@param data table|nil
---@return LFGCard
function LFGCard:new(data)
    local instance = setmetatable({}, self)
    data = data or {}

    instance._id = data.id or (string.format("lfg_%d_%d", time(), math.random(1000, 9999)))
    instance._type = data.type or (GroupType and GroupType.DUNGEON) or "DUNGEON"
    instance._time = data.time or ""
    instance._description = data.description or ""
    instance._creator = data.creator or ""
    instance._creatorClass = data.creatorClass or ""
    instance._creatorLevel = tonumber(data.creatorLevel) or 1
    instance._createdAt = tonumber(data.createdAt) or time()

    return instance
end

function LFGCard:getId()
    return self._id
end

function LFGCard:setId(id)
    if type(id) == "string" and id ~= "" then
        self._id = id
    end
end

function LFGCard:getType()
    return self._type
end

function LFGCard:setType(t)
    if t and t ~= "" then
        self._type = t
    end
end

function LFGCard:getTime()
    return self._time
end

function LFGCard:setTime(t)
    self._time = t or ""
end

function LFGCard:getDescription()
    return self._description
end

function LFGCard:setDescription(d)
    self._description = d or ""
end

function LFGCard:getCreator()
    return self._creator
end

function LFGCard:setCreator(c)
    self._creator = c or ""
end

function LFGCard:getCreatorClass()
    return self._creatorClass
end

function LFGCard:setCreatorClass(c)
    self._creatorClass = c or ""
end

function LFGCard:getCreatorLevel()
    return self._creatorLevel
end

function LFGCard:setCreatorLevel(lvl)
    self._creatorLevel = tonumber(lvl) or 1
end

function LFGCard:getCreatedAt()
    return self._createdAt
end

function LFGCard:setCreatedAt(ts)
    self._createdAt = tonumber(ts) or time()
end

--- Verifica se o card expirou após 72 horas da criação.
---@param currentTime number|nil
---@return boolean
function LFGCard:isExpired(currentTime)
    local now = currentTime or (time and time()) or 0
    local created = self._createdAt or 0
    return (now - created) >= LFG_CARD_LIFETIME
end

--- Retorna os segundos restantes antes de expirar (mínimo 0).
---@param currentTime number|nil
---@return number
function LFGCard:getRemainingTime(currentTime)
    local now = currentTime or (time and time()) or 0
    local created = self._createdAt or 0
    local elapsed = now - created
    local remaining = LFG_CARD_LIFETIME - elapsed
    return math.max(0, remaining)
end

--- Retorna uma string amigável com o tempo restante de validade do card (ex: "2d 14h", "5h 30m", "45m").
---@param currentTime number|nil
---@return string
function LFGCard:getRemainingTimeString(currentTime)
    local rem = self:getRemainingTime(currentTime)
    if rem <= 0 then
        return "Expirado"
    end
    local hours = math.floor(rem / 3600)
    local minutes = math.floor((rem % 3600) / 60)
    if hours >= 24 then
        local days = math.floor(hours / 24)
        local h = hours % 24
        if h > 0 then
            return string.format("%dd %dh", days, h)
        else
            return string.format("%dd", days)
        end
    elseif hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    else
        return string.format("%dm", math.max(1, minutes))
    end
end

--- Verifica se o jogador informado é o criador deste card.
---@param playerName string|nil
---@return boolean
function LFGCard:isCreator(playerName)
    if not playerName or playerName == "" or not self._creator or self._creator == "" then
        return false
    end

    local function norm(n)
        local c = (n:match("^[^-]+") or n):match("^%s*(.-)%s*$")
        return c:lower()
    end

    local pNorm = norm(playerName)
    local cNorm = norm(self._creator)

    if pNorm == cNorm then return true end

    local pFirst = pNorm:match("^(%S+)") or pNorm
    local cFirst = cNorm:match("^(%S+)") or cNorm
    if pFirst == cFirst then return true end

    if _G.GM and _G.GM.memberService and _G.GM.memberService.resolveFullName then
        local pRes = norm(_G.GM.memberService:resolveFullName(playerName) or "")
        local cRes = norm(_G.GM.memberService:resolveFullName(self._creator) or "")
        if pRes ~= "" and (pRes == cNorm or pRes == cRes) then return true end
        if cRes ~= "" and (cRes == pNorm or cRes == pRes) then return true end
    end

    return false
end

--- Serializa a entidade para armazenamento em tabela.
---@return table
function LFGCard:serialize()
    return {
        id = self._id,
        type = self._type,
        time = self._time,
        description = self._description,
        creator = self._creator,
        creatorClass = self._creatorClass,
        creatorLevel = self._creatorLevel,
        createdAt = self._createdAt,
    }
end

_G.LFGCard = LFGCard

