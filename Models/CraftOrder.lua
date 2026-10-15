---@class CraftOrder
--- Entidade que representa um pedido de fabricação de profissão na guilda.
---@field _id string @Identificador único do pedido
---@field _requester string @Nome do membro que solicitou o pedido
---@field _crafter string @Nome do artesão direcionado ("" se aberto para qualquer um da guilda)
---@field _professionKey string @Chave da profissão ("ALCHEMY", "TAILORING", etc.)
---@field _recipeId number|string @Identificador da receita solicitada
---@field _recipeName string @Nome da receita solicitada
---@field _recipeIcon string @Ícone da receita
---@field _itemCount number @Quantidade de itens solicitada
---@field _tipCopper number @Gorjeta / comissão oferecida em cobre (10000 = 1 ouro)
---@field _notes string @Observações, materiais fornecidos e detalhes do pedido
---@field _status string @"PENDING", "IN_PROGRESS", "COMPLETED", "CANCELLED"
---@field _acceptedBy string @Nome do artesão que assumiu a ordem
---@field _createdAt number @Timestamp de criação
---@field _updatedAt number @Timestamp da última alteração
CraftOrder = {}
CraftOrder.__index = CraftOrder

--- Status possíveis para um pedido de profissão
CraftOrder.STATUS = {
    PENDING     = "PENDING",     -- Pendente (aguardando artesão)
    IN_PROGRESS = "IN_PROGRESS", -- Em Andamento (aceito por um artesão)
    COMPLETED   = "COMPLETED",   -- Concluído (fabricado e entregue)
    CANCELLED   = "CANCELLED",   -- Cancelado pelo solicitante
}

---@param data table|nil
---@return CraftOrder
function CraftOrder:new(data)
    local instance = setmetatable({}, self)
    data = data or {}

    local now = (GetServerTime and GetServerTime()) or (time and time()) or (os and os.time and os.time()) or 0

    instance._id = data.id or string.format("order_%d_%d", now, math.random(1000, 9999))
    instance._requester = data.requester or ""
    instance._crafter = data.crafter or ""
    instance._professionKey = data.professionKey or "ALCHEMY"
    instance._recipeId = data.recipeId or 0
    instance._recipeName = data.recipeName or ""
    instance._recipeIcon = data.recipeIcon or "Interface\\Icons\\Trade_Alchemy"
    instance._itemCount = tonumber(data.itemCount) or 1
    instance._tipCopper = tonumber(data.tipCopper) or 0
    instance._notes = data.notes or ""
    instance._status = data.status or CraftOrder.STATUS.PENDING
    instance._acceptedBy = data.acceptedBy or ""
    instance._createdAt = tonumber(data.createdAt) or now
    instance._updatedAt = tonumber(data.updatedAt) or now

    return instance
end

--- Serializa o pedido para persistência e transmissão P2P
---@return table
function CraftOrder:serialize()
    return {
        id = self._id,
        requester = self._requester,
        crafter = self._crafter,
        professionKey = self._professionKey,
        recipeId = self._recipeId,
        recipeName = self._recipeName,
        recipeIcon = self._recipeIcon,
        itemCount = self._itemCount,
        tipCopper = self._tipCopper,
        notes = self._notes,
        status = self._status,
        acceptedBy = self._acceptedBy,
        createdAt = self._createdAt,
        updatedAt = self._updatedAt,
    }
end

-- Getters
function CraftOrder:getId() return self._id end
function CraftOrder:getRequester() return self._requester end
function CraftOrder:getCrafter() return self._crafter end
function CraftOrder:getProfessionKey() return self._professionKey end
function CraftOrder:getRecipeId() return self._recipeId end
function CraftOrder:getRecipeName() return self._recipeName end
function CraftOrder:getRecipeIcon() return self._recipeIcon end
function CraftOrder:getItemCount() return self._itemCount or 1 end
function CraftOrder:getTipCopper() return self._tipCopper or 0 end
function CraftOrder:getNotes() return self._notes or "" end
function CraftOrder:getStatus() return self._status or CraftOrder.STATUS.PENDING end
function CraftOrder:getAcceptedBy() return self._acceptedBy or "" end
function CraftOrder:getCreatedAt() return self._createdAt or 0 end
function CraftOrder:getUpdatedAt() return self._updatedAt or 0 end

-- Setters
function CraftOrder:setCrafter(crafter) self._crafter = tostring(crafter or ""); self:touch() end
function CraftOrder:setItemCount(count) self._itemCount = math.max(1, tonumber(count) or 1); self:touch() end
function CraftOrder:setTipCopper(copper) self._tipCopper = math.max(0, tonumber(copper) or 0); self:touch() end
function CraftOrder:setNotes(notes) self._notes = tostring(notes or ""); self:touch() end
function CraftOrder:setStatus(status) self._status = status or CraftOrder.STATUS.PENDING; self:touch() end
function CraftOrder:setAcceptedBy(name) self._acceptedBy = tostring(name or ""); self:touch() end
function CraftOrder:touch()
    self._updatedAt = (GetServerTime and GetServerTime()) or (time and time()) or (os and os.time and os.time()) or 0
end

--- Verifica se o pedido é aberto para qualquer artesão da guilda
---@return boolean
function CraftOrder:isOpenToGuild()
    return not self._crafter or self._crafter == "" or self._crafter:upper() == "ANY" or self._crafter:lower() == "qualquer"
end

--- Retorna a gorjeta formatada em ouro, prata e cobre (ex: "5g 20s")
---@return string
function CraftOrder:getFormattedTip()
    local copper = self._tipCopper or 0
    if copper <= 0 then return "|cff888888Sem gorjeta|r" end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100

    local parts = {}
    if gold > 0 then table.insert(parts, string.format("|cffffd700%dg|r", gold)) end
    if silver > 0 then table.insert(parts, string.format("|cffc7c7cf%ds|r", silver)) end
    if cop > 0 or #parts == 0 then table.insert(parts, string.format("|cffeda55f%dc|r", cop)) end
    return table.concat(parts, " ")
end
