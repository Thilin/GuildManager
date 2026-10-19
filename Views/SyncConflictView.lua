local addonName, addonTable = ...
local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })

---@class SyncConflictView
--- Janela modal exclusiva para o Líder da Guilda decidir quando uma informação
--- recebida via sincronização tenta alterar ou substituir um dado já existente no seu banco.
SyncConflictView = {}
SyncConflictView.__index = SyncConflictView

local DIALOG_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local SUB_CONTAINER_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local PALETTE = {
    FRAME_BG = { 0.055, 0.035, 0.015, 0.98 },
    FRAME_BORDER = { 1.0, 0.68, 0.22, 1.0 },
    INSET_BG = { 0.025, 0.016, 0.007, 0.90 },
    INSET_BORDER = { 0.70, 0.48, 0.16, 0.90 },
    OLD_VAL = { 1.0, 0.82, 0.20 },
    NEW_VAL = { 0.25, 1.0, 0.25 },
}

--- Construtor da View de Conflito de Sincronização.
---@return SyncConflictView
function SyncConflictView:new()
    local instance = setmetatable({}, self)
    instance._frame = nil
    instance._queue = {}
    instance._currentConflict = nil
    instance._onActionCallback = nil
    return instance
end

--- Define o callback de resolução de conflito: callback(conflict, action)
---@param cb function(conflict: table, action: string)
function SyncConflictView:setOnActionCallback(cb)
    self._onActionCallback = cb
end

--- Cria a interface da janela caso ainda não exista.
function SyncConflictView:createUI()
    if self._frame then return end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "GuildManagerSyncConflictDialog", UIParent, template)
    self._frame = frame

    frame:SetSize(520, 320)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)

    if frame.SetBackdrop then
        frame:SetBackdrop(DIALOG_BACKDROP)
        frame:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], PALETTE.FRAME_BG[4])
        frame:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], PALETTE.FRAME_BORDER[4])
    end

    -- Botão Fechar [X]
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        -- Ao fechar sem clicar, concatena de acordo com a regra de proteção
        self:resolveCurrent("CONCAT")
    end)

    -- Ícone de Alerta / Gestão
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -18)
    icon:SetTexture("Interface\\Icons\\INV_Scroll_03")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Título
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -1)
    title:SetText(curL["SYNC_CONFLICT_TITLE"] or "Conflito de Sincronização - Decisão do Líder")
    self._title = title

    -- Subtítulo
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetPoint("RIGHT", frame, "RIGHT", -36, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText(curL["SYNC_CONFLICT_SUBTITLE"] or "Um membro enviou dados que conflitam com as informações existentes no seu banco de dados.")
    self._subtitle = subtitle

    -- Inset Central Comparativo
    local inset = CreateFrame("Frame", nil, frame, template)
    inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -70)
    inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 68)
    if inset.SetBackdrop then
        inset:SetBackdrop(SUB_CONTAINER_BACKDROP)
        inset:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        inset:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end

    -- Informações do Membro e Remetente
    local memberLabel = inset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    memberLabel:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -10)
    memberLabel:SetText(curL["SYNC_CONFLICT_MEMBER"] or "Membro:")
    self._memberLabel = memberLabel

    local memberValue = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    memberValue:SetPoint("LEFT", memberLabel, "RIGHT", 6, 0)
    self._memberValue = memberValue

    local senderLabel = inset:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    senderLabel:SetPoint("LEFT", memberValue, "RIGHT", 16, 0)
    senderLabel:SetText(curL["SYNC_CONFLICT_SENDER"] or "Recebido de:")
    self._senderLabel = senderLabel

    local senderValue = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    senderValue:SetPoint("LEFT", senderLabel, "RIGHT", 6, 0)
    self._senderValue = senderValue

    local fieldLabel = inset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fieldLabel:SetPoint("TOPLEFT", memberLabel, "BOTTOMLEFT", 0, -8)
    fieldLabel:SetText(curL["SYNC_CONFLICT_FIELD"] or "Dado em Conflito:")
    self._fieldLabel = fieldLabel

    local fieldValue = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fieldValue:SetPoint("LEFT", fieldLabel, "RIGHT", 6, 0)
    self._fieldValue = fieldValue

    -- Caixa "Antes" (Existente no banco do Líder)
    local beforeBox = CreateFrame("Frame", nil, inset, template)
    beforeBox:SetPoint("TOPLEFT", fieldLabel, "BOTTOMLEFT", 0, -10)
    beforeBox:SetPoint("RIGHT", inset, "RIGHT", -12, 0)
    beforeBox:SetHeight(32)
    if beforeBox.SetBackdrop then
        beforeBox:SetBackdrop(SUB_CONTAINER_BACKDROP)
        beforeBox:SetBackdropColor(0.04, 0.03, 0.015, 0.85)
        beforeBox:SetBackdropBorderColor(0.60, 0.45, 0.15, 0.70)
    end

    local beforeLabel = beforeBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    beforeLabel:SetPoint("LEFT", beforeBox, "LEFT", 10, 0)
    beforeLabel:SetText(curL["SYNC_CONFLICT_BEFORE"] or "Atual no seu Banco (Antes):")
    self._beforeLabel = beforeLabel

    local beforeText = beforeBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    beforeText:SetPoint("LEFT", beforeLabel, "RIGHT", 8, 0)
    beforeText:SetTextColor(PALETTE.OLD_VAL[1], PALETTE.OLD_VAL[2], PALETTE.OLD_VAL[3])
    self._beforeText = beforeText

    -- Caixa "Depois" (Recebido do colega)
    local afterBox = CreateFrame("Frame", nil, inset, template)
    afterBox:SetPoint("TOPLEFT", beforeBox, "BOTTOMLEFT", 0, -6)
    afterBox:SetPoint("RIGHT", inset, "RIGHT", -12, 0)
    afterBox:SetHeight(32)
    if afterBox.SetBackdrop then
        afterBox:SetBackdrop(SUB_CONTAINER_BACKDROP)
        afterBox:SetBackdropColor(0.02, 0.05, 0.02, 0.85)
        afterBox:SetBackdropBorderColor(0.20, 0.65, 0.20, 0.70)
    end

    local afterLabel = afterBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    afterLabel:SetPoint("LEFT", afterBox, "LEFT", 10, 0)
    afterLabel:SetText(curL["SYNC_CONFLICT_AFTER"] or "Recebido do Colega (Depois):")
    self._afterLabel = afterLabel

    local afterText = afterBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    afterText:SetPoint("LEFT", afterLabel, "RIGHT", 8, 0)
    afterText:SetTextColor(PALETTE.NEW_VAL[1], PALETTE.NEW_VAL[2], PALETTE.NEW_VAL[3])
    self._afterText = afterText

    -- Pergunta de ação
    local question = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    question:SetPoint("TOPLEFT", inset, "BOTTOMLEFT", 0, -8)
    question:SetText(curL["SYNC_CONFLICT_QUESTION"] or "Deseja substituir as informações existentes no seu banco de dados?")
    self._question = question

    -- Contador de fila (ex: "Conflito 1 de 3")
    local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    countText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 14)
    self._countText = countText

    -- Três Botões de Ação
    local btnReplace = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnReplace:SetSize(110, 24)
    btnReplace:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 12)
    btnReplace:SetText(curL["SYNC_CONFLICT_BTN_REPLACE"] or "Substituir")
    btnReplace:SetScript("OnClick", function()
        self:resolveCurrent("REPLACE")
    end)
    self._btnReplace = btnReplace

    local btnConcat = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnConcat:SetSize(110, 24)
    btnConcat:SetPoint("LEFT", btnReplace, "RIGHT", 8, 0)
    btnConcat:SetText(curL["SYNC_CONFLICT_BTN_CONCAT"] or "Concatenar")
    btnConcat:SetScript("OnClick", function()
        self:resolveCurrent("CONCAT")
    end)
    self._btnConcat = btnConcat

    local btnKeep = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnKeep:SetSize(120, 24)
    btnKeep:SetPoint("LEFT", btnConcat, "RIGHT", 8, 0)
    btnKeep:SetText(curL["SYNC_CONFLICT_BTN_KEEP"] or "Manter Atual")
    btnKeep:SetScript("OnClick", function()
        self:resolveCurrent("KEEP")
    end)
    self._btnKeep = btnKeep

    frame:Hide()
end

--- Enfileira um novo conflito para apreciação do Líder da Guilda.
---@param conflict table @{ memberName, sender, fieldKey, fieldName, oldValue, newValue, timestamp, member }
function SyncConflictView:enqueueConflict(conflict)
    if not conflict then return end
    table.insert(self._queue, conflict)

    if not self._currentConflict then
        self:showNextConflict()
    else
        self:updateCountText()
    end
end

--- Atualiza o texto do contador de conflitos na fila.
function SyncConflictView:updateCountText()
    if not self._countText then return end
    local total = #self._queue + (self._currentConflict and 1 or 0)
    if total > 1 then
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        self._countText:SetText(string.format(curL["SYNC_CONFLICT_QUEUE_COUNT"] or "Conflito 1 de %d", total))
        self._countText:Show()
    else
        self._countText:Hide()
    end
end

--- Exibe o próximo conflito da fila.
function SyncConflictView:showNextConflict()
    if #self._queue == 0 then
        self._currentConflict = nil
        self:hide()
        return
    end

    self:createUI()

    local conflict = table.remove(self._queue, 1)
    self._currentConflict = conflict

    local curL = (_G.GM and _G.GM.L) or _G.L or L
    if self._memberValue then self._memberValue:SetText("|cffffff00" .. (conflict.memberName or "Desconhecido") .. "|r") end
    if self._senderValue then self._senderValue:SetText(conflict.sender or "Membro") end
    if self._fieldValue then self._fieldValue:SetText("|cffff9926" .. (conflict.fieldName or conflict.fieldKey or "") .. "|r") end
    if self._beforeText then self._beforeText:SetText(tostring(conflict.oldValue or "")) end
    if self._afterText then self._afterText:SetText(tostring(conflict.newValue or "")) end

    self:updateCountText()

    if self._frame then
        self._frame:Show()
    end
end

--- Resolve o conflito atual e avança para o próximo.
---@param action string @"REPLACE", "CONCAT", "KEEP"
function SyncConflictView:resolveCurrent(action)
    local current = self._currentConflict
    if current and self._onActionCallback then
        pcall(self._onActionCallback, current, action)
    end

    self:showNextConflict()
end

--- Oculta o diálogo.
function SyncConflictView:hide()
    if self._frame then
        self._frame:Hide()
    end
end

--- Verifica se o diálogo está aberto na tela.
---@return boolean
function SyncConflictView:isShown()
    return self._frame and self._frame:IsShown() or false
end

_G.SyncConflictView = SyncConflictView
