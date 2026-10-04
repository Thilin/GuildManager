---@class WorldMapView
---@field private _frame table|nil
---@field private _mapButton table|nil
---@field private _panel table|nil
---@field private _pins table
---@field private _memberRows table
---@field private _membersData table
---@field private _onScanCallback function|nil
---@field private _onMemberClickCallback function|nil
WorldMapView = {}
WorldMapView.__index = WorldMapView

local PALETTE = {
    FRAME_BG = { 0.05, 0.04, 0.02, 0.95 },
    FRAME_BORDER = { 0.60, 0.45, 0.20, 1.0 },
    SUB_BOX_BG = { 0.08, 0.06, 0.03, 0.90 },
    SUB_BOX_BORDER = { 0.45, 0.32, 0.12, 0.85 },
    FOCUS_BORDER = { 0.90, 0.70, 0.20, 1.0 },
    FOCUS_BG = { 0.12, 0.09, 0.04, 0.95 },
    INSET_BG = { 0.04, 0.03, 0.015, 0.90 },
    INSET_BORDER = { 0.45, 0.32, 0.12, 0.80 },
    SEPARATOR = { 0.45, 0.32, 0.12, 0.60 },
    HIGHLIGHT_TINT = { 0.90, 0.75, 0.30, 0.20 },
}

local CONTAINER_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local SUB_CONTAINER_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local MAP_BUTTON_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local CLASS_COLORS = {
    WARRIOR     = { r = 0.78, g = 0.61, b = 0.43, hex = "|cffc79c6e" },
    MAGE        = { r = 0.41, g = 0.80, b = 0.94, hex = "|cff69ccf0" },
    ROGUE       = { r = 1.00, g = 0.96, b = 0.41, hex = "|cfffff569" },
    DRUID       = { r = 1.00, g = 0.49, b = 0.04, hex = "|cffff7d0a" },
    HUNTER      = { r = 0.67, g = 0.83, b = 0.45, hex = "|cffabd473" },
    SHAMAN      = { r = 0.00, g = 0.44, b = 0.87, hex = "|cff0070de" },
    PRIEST      = { r = 1.00, g = 1.00, b = 1.00, hex = "|cffffffff" },
    WARLOCK     = { r = 0.58, g = 0.51, b = 0.79, hex = "|cff9482c9" },
    PALADIN     = { r = 0.96, g = 0.55, b = 0.73, hex = "|cfff58cba" },
    DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23, hex = "|cffc41e3a" },
}

local CLASS_ICON_COORDS = {
    WARRIOR     = { 0, 0.25, 0, 0.25 },
    MAGE        = { 0.25, 0.49609375, 0, 0.25 },
    ROGUE       = { 0.49609375, 0.7421875, 0, 0.25 },
    DRUID       = { 0.7421875, 0.98828125, 0, 0.25 },
    HUNTER      = { 0, 0.25, 0.25, 0.5 },
    SHAMAN      = { 0.25, 0.49609375, 0.25, 0.5 },
    PRIEST      = { 0.49609375, 0.7421875, 0.25, 0.5 },
    WARLOCK     = { 0.7421875, 0.98828125, 0.25, 0.5 },
    PALADIN     = { 0, 0.25, 0.5, 0.75 },
    DEATHKNIGHT = { 0.25, 0.49609375, 0.5, 0.75 },
}

--- Construtor da View do Mapa Mundi.
---@return WorldMapView
function WorldMapView:new()
    local instance = setmetatable({}, self)
    instance._pins = {}
    instance._memberRows = {}
    instance._membersData = {}
    instance._scrollOffset = 0
    instance._maxVisibleRows = 10
    instance._rowHeight = 42
    instance._currentZoneName = ""
    instance._isPanelOpen = true

    return instance
end

--- Obtém a camada onde os pinos de mapa devem ser desenhados (canvas do WorldMapFrame).
--- Suporta WoW Classic Era 1.15 (MapCanvasFrame) e versões clássicas/legadas.
---@return table|nil
function WorldMapView:getMapCanvas()
    if WorldMapFrame then
        if WorldMapFrame.GetCanvas then
            local canvas = WorldMapFrame:GetCanvas()
            if canvas then return canvas end
        end
        if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child then
            return WorldMapFrame.ScrollContainer.Child
        end
    end
    if WorldMapButton then return WorldMapButton end
    if WorldMapDetailFrame then return WorldMapDetailFrame end
    return WorldMapFrame
end

--- Ajusta a ancoragem do botão da guilda no canto superior direito do WorldMapFrame.
function WorldMapView:reanchorMapButton()
    local mapButton = self._mapButton
    if not mapButton or not WorldMapFrame then return end

    mapButton:ClearAllPoints()
    local anchorFrame = nil
    if WorldMapFrame.MaximizeMinimizeFrame and WorldMapFrame.MaximizeMinimizeFrame:IsShown() then
        anchorFrame = WorldMapFrame.MaximizeMinimizeFrame
    elseif WorldMapFrame.BorderFrame and WorldMapFrame.BorderFrame.MaximizeMinimizeFrame and WorldMapFrame.BorderFrame.MaximizeMinimizeFrame:IsShown() then
        anchorFrame = WorldMapFrame.BorderFrame.MaximizeMinimizeFrame
    elseif WorldMapFrameSizeDownButton and WorldMapFrameSizeDownButton:IsShown() then
        anchorFrame = WorldMapFrameSizeDownButton
    elseif WorldMapFrameSizeUpButton and WorldMapFrameSizeUpButton:IsShown() then
        anchorFrame = WorldMapFrameSizeUpButton
    elseif WorldMapFrameCloseButton and WorldMapFrameCloseButton:IsShown() then
        anchorFrame = WorldMapFrameCloseButton
    elseif WorldMapFrame.BorderFrame and WorldMapFrame.BorderFrame.CloseButton and WorldMapFrame.BorderFrame.CloseButton:IsShown() then
        anchorFrame = WorldMapFrame.BorderFrame.CloseButton
    elseif WorldMapFrameCloseButton then
        anchorFrame = WorldMapFrameCloseButton
    elseif WorldMapFrame.CloseButton then
        anchorFrame = WorldMapFrame.CloseButton
    end

    if anchorFrame then
        local isCloseBtn = (anchorFrame == WorldMapFrameCloseButton)
            or (WorldMapFrame.BorderFrame and anchorFrame == WorldMapFrame.BorderFrame.CloseButton)
            or (anchorFrame == WorldMapFrame.CloseButton)
        local xOffset = isCloseBtn and -32 or -6
        mapButton:SetPoint("RIGHT", anchorFrame, "LEFT", xOffset, 0)
    else
        mapButton:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -65, -4)
    end
end

--- Inicializa os componentes visuais vinculados à tela nativa de mapa (WorldMapFrame).
function WorldMapView:initWorldMapUI()
    if self._mapButton or not WorldMapFrame then
        return
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    -- =========================================================================
    -- BOTÃO DE INFORMAÇÃO DA GUILDA NA BARRA SUPERIOR DIREITA DO MAPA
    -- =========================================================================
    local mapButton = CreateFrame("Button", "GM_WorldMapButton", WorldMapFrame, template)
    mapButton:SetSize(145, 22)
    mapButton:SetFrameStrata("HIGH")
    mapButton:SetFrameLevel((WorldMapFrame:GetFrameLevel() or 10) + 20)
    self._mapButton = mapButton
    self:reanchorMapButton()

    if mapButton.SetBackdrop then
        mapButton:SetBackdrop(MAP_BUTTON_BACKDROP)
        mapButton:SetBackdropColor(0.18, 0.12, 0.04, 0.95)
        mapButton:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
    end

    -- Brilho / Aura Dourada ao redor do botão
    local btnGlow = mapButton:CreateTexture(nil, "BACKGROUND", nil, -1)
    btnGlow:SetPoint("TOPLEFT", mapButton, "TOPLEFT", -3, 3)
    btnGlow:SetPoint("BOTTOMRIGHT", mapButton, "BOTTOMRIGHT", 3, -3)
    btnGlow:SetTexture("Interface\\ChatFrame\\ChatFrameTab-NewMessage")
    btnGlow:SetVertexColor(1.0, 0.82, 0.0, 0.55)
    btnGlow:SetBlendMode("ADD")
    mapButton.glow = btnGlow

    -- Ícone oficial do Tabardo da Guilda
    local icon = mapButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", mapButton, "LEFT", 5, 0)
    icon:SetTexture("Interface\\Icons\\INV_Shirt_GuildTabard_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    mapButton.icon = icon

    local btnText = mapButton:CreateFontString(nil, "OVERLAY")
    btnText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    btnText:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    btnText:SetPoint("RIGHT", mapButton, "RIGHT", -4, 0)
    btnText:SetJustifyH("LEFT")
    btnText:SetText("|cffffd200Guilda:|r |cff00ff000 na Região|r")
    mapButton.text = btnText

    local btnHighlight = mapButton:CreateTexture(nil, "HIGHLIGHT")
    btnHighlight:SetAllPoints(mapButton)
    btnHighlight:SetColorTexture(1.0, 0.85, 0.30, 0.30)
    mapButton:SetHighlightTexture(btnHighlight)

    mapButton:SetScript("OnEnter", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(1.0, 0.95, 0.40, 1.0)
            btn:SetBackdropColor(0.24, 0.16, 0.05, 1.0)
        end
        if btn.glow then
            btn.glow:SetVertexColor(1.0, 0.95, 0.40, 0.90)
        end
        GameTooltip:SetOwner(btn, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:AddLine("|cffffd200GuildManager - Membros na Região|r")
        GameTooltip:AddLine("Exibe os membros da guilda presentes nesta região do mapa com suas coordenadas e pinos em tempo real.", 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ff00Clique para abrir/fechar o painel lateral e ver a lista completa.|r", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    mapButton:SetScript("OnLeave", function(btn)
        self:updateButtonState()
        GameTooltip:Hide()
    end)

    mapButton:SetScript("OnClick", function()
        self:togglePanel()
    end)

    self._mapButton = mapButton

    -- =========================================================================
    -- PAINEL LATERAL ACOPLADO AO WORLD MAP NATIVO
    -- =========================================================================
    local panel = CreateFrame("Frame", "GM_WorldMapPanel", WorldMapFrame, template)
    panel:SetWidth(270)
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel((WorldMapFrame:GetFrameLevel() or 10) + 10)
    panel:Hide()

    if panel.SetBackdrop then
        panel:SetBackdrop(CONTAINER_BACKDROP)
        panel:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], 0.96)
        panel:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], 1.0)
    end

    self._panel = panel

    -- Título do Painel
    local headerTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
    headerTitle:SetText("|cffffd200Membros na Região|r")
    panel.headerTitle = headerTitle

    -- Botão Fechar Painel (X)
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        self:hidePanel()
    end)

    -- Nome da Região / Zona Atual
    local zoneTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneTitle:SetPoint("TOPLEFT", headerTitle, "BOTTOMLEFT", 0, -4)
    zoneTitle:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
    zoneTitle:SetJustifyH("LEFT")
    zoneTitle:SetText("|cff00e5ffRegião Atual|r")
    panel.zoneTitle = zoneTitle

    -- Contador de membros encontrados
    local countText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    countText:SetPoint("TOPLEFT", zoneTitle, "BOTTOMLEFT", 0, -2)
    countText:SetText("|cffaaaaaaMembros encontrados: 0|r")
    panel.countText = countText

    -- Linha divisória ornamental
    local sep = panel:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", countText, "BOTTOMLEFT", 0, -6)
    sep:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- Botão de Escanear / Atualizar Região
    local scanBtn = CreateFrame("Button", nil, panel, template)
    scanBtn:SetSize(110, 20)
    scanBtn:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -6)
    if scanBtn.SetBackdrop then
        scanBtn:SetBackdrop(SUB_CONTAINER_BACKDROP)
        scanBtn:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.90)
        scanBtn:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.85)
    end
    local scanBtnTxt = scanBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scanBtnTxt:SetPoint("CENTER", scanBtn, "CENTER", 0, 0)
    scanBtnTxt:SetText("Escanear Mapa")
    scanBtn:SetScript("OnEnter", function(b)
        if b.SetBackdropBorderColor then
            b:SetBackdropBorderColor(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], 1.0)
        end
    end)
    scanBtn:SetScript("OnLeave", function(b)
        if b.SetBackdropBorderColor then
            b:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.85)
        end
    end)
    scanBtn:SetScript("OnClick", function()
        if self._onScanCallback then
            self._onScanCallback()
        end
    end)

    -- Container da Lista de Membros
    local listContainer = CreateFrame("Frame", nil, panel, template)
    listContainer:SetPoint("TOPLEFT", scanBtn, "BOTTOMLEFT", 0, -6)
    listContainer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 36)
    if listContainer.SetBackdrop then
        listContainer:SetBackdrop(SUB_CONTAINER_BACKDROP)
        listContainer:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], 0.90)
        listContainer:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], 0.80)
    end
    panel.listContainer = listContainer

    -- ScrollBar para a lista
    local scrollBar = CreateFrame("Slider", "GM_WorldMapPanelScrollBar", listContainer, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPRIGHT", listContainer, "TOPRIGHT", -2, -18)
    scrollBar:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -2, 18)
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValue(0)
    scrollBar:SetValueStep(1)
    scrollBar:SetWidth(16)
    scrollBar:Hide()
    scrollBar:SetScript("OnValueChanged", function(_, val)
        self._scrollOffset = math.floor(val)
        self:refreshVisibleRows()
    end)
    self._scrollBar = scrollBar

    listContainer:EnableMouseWheel(true)
    listContainer:SetScript("OnMouseWheel", function(_, delta)
        local cur = self._scrollOffset or 0
        local maxVal = math.max(0, #self._membersData - self._maxVisibleRows)
        if delta < 0 and cur < maxVal then
            scrollBar:SetValue(cur + 1)
        elseif delta > 0 and cur > 0 then
            scrollBar:SetValue(cur - 1)
        end
    end)

    -- Mensagem caso não haja nenhum membro na região
    local emptyMsg = listContainer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyMsg:SetPoint("CENTER", listContainer, "CENTER", 0, 0)
    emptyMsg:SetText("Nenhum membro da guilda\nencontrado nesta região.")
    emptyMsg:Hide()
    panel.emptyMsg = emptyMsg

    -- Rodapé explicativo
    local footer = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footer:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 8)
    footer:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    footer:SetJustifyH("LEFT")
    footer:SetText("|cff888888Pinos no mapa mostram posições exatas.|r\n|cff888888Clique no membro para sussurrar.|r")

    -- Criação dos rows visíveis
    for i = 1, self._maxVisibleRows do
        local row = CreateFrame("Button", nil, listContainer, template)
        row:SetHeight(self._rowHeight)
        row:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 4, -4 - (i - 1) * self._rowHeight)
        row:SetPoint("RIGHT", listContainer, "RIGHT", -20, 0)

        if row.SetBackdrop then
            row:SetBackdrop(SUB_CONTAINER_BACKDROP)
            row:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.70)
            row:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.50)
        end

        local classIcon = row:CreateTexture(nil, "ARTWORK")
        classIcon:SetSize(26, 26)
        classIcon:SetPoint("LEFT", row, "LEFT", 6, 0)
        classIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        row.classIcon = classIcon

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 38, -6)
        nameText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        nameText:SetHeight(14)
        nameText:SetJustifyH("LEFT")
        nameText:SetJustifyV("MIDDLE")
        nameText:SetWordWrap(false)
        row.nameText = nameText

        local subText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        subText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -3)
        subText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        subText:SetHeight(12)
        subText:SetJustifyH("LEFT")
        subText:SetJustifyV("MIDDLE")
        subText:SetWordWrap(false)
        row.subText = subText

        local rowHl = row:CreateTexture(nil, "HIGHLIGHT")
        rowHl:SetAllPoints(row)
        rowHl:SetColorTexture(PALETTE.HIGHLIGHT_TINT[1], PALETTE.HIGHLIGHT_TINT[2], PALETTE.HIGHLIGHT_TINT[3], 0.25)
        row:SetHighlightTexture(rowHl)

        row:SetScript("OnEnter", function(r)
            if r.SetBackdropBorderColor then
                r:SetBackdropBorderColor(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], 1.0)
            end
            if r.memberData then
                local data = r.memberData
                GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
                local cHex = (data.class and CLASS_COLORS[data.class] and CLASS_COLORS[data.class].hex) or "|cffffffff"
                GameTooltip:AddLine(cHex .. (data.name or "Membro") .. "|r")
                GameTooltip:AddLine(string.format("Nível %d %s", data.level or 1, data.classDisplayName or data.class or ""), 1, 1, 1)
                if data.rankName and data.rankName ~= "" then
                    GameTooltip:AddLine(string.format("Cargo: |cffffff00%s|r", data.rankName), 0.9, 0.8, 0.5)
                end
                if data.coordX and data.coordY and (data.coordX > 0 or data.coordY > 0) then
                    local locType = data.isSelf and "Você" or (data.isExact and "Exatas" or (data.hubLocation or "Região"))
                    local cColor = data.isExact and "|cff40ff40" or "|cffffd200"
                    GameTooltip:AddLine(string.format("Coordenadas: %s%.1f, %.1f (%s)|r", cColor, data.coordX * 100, data.coordY * 100, locType), 0.9, 0.9, 0.9)
                else
                    GameTooltip:AddLine(string.format("Região: |cffffffff%s|r", data.zone or "Desconhecida"), 0.8, 0.8, 0.8)
                end
                if data.publicNote and data.publicNote ~= "" then
                    GameTooltip:AddLine("Nota Pública: |cffffffff" .. data.publicNote .. "|r", 0.7, 0.7, 0.7, true)
                end
                if data.officerNote and data.officerNote ~= "" then
                    GameTooltip:AddLine("Nota de Oficial: |cff80d0ff" .. data.officerNote .. "|r", 0.7, 0.7, 0.7, true)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cff00ff00Clique para sussurrar com o jogador.|r", 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end
        end)

        row:SetScript("OnLeave", function(r)
            if r.SetBackdropBorderColor then
                r:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.50)
            end
            GameTooltip:Hide()
        end)

        row:SetScript("OnClick", function(r)
            if r.memberData and r.memberData.name then
                if self._onMemberClickCallback then
                    self._onMemberClickCallback(r.memberData)
                else
                    ChatFrame_OpenChat("/w " .. r.memberData.name .. " ")
                end
            end
        end)

        row:Hide()
        self._memberRows[i] = row
    end
end

--- Atualiza o posicionamento do painel garantindo que fique dentro dos limites da tela.
function WorldMapView:adjustPanelPosition()
    local panel = self._panel
    if not panel or not WorldMapFrame then return end

    panel:ClearAllPoints()
    local mapRight = WorldMapFrame:GetRight() or 0
    local screenWidth = GetScreenWidth() or 1920

    -- Se houver espaço à direita do WorldMapFrame, acopla externamente; caso contrário, acopla por dentro.
    if (mapRight + 275) <= screenWidth then
        panel:SetPoint("TOPLEFT", WorldMapFrame, "TOPRIGHT", 2, 0)
        panel:SetPoint("BOTTOMLEFT", WorldMapFrame, "BOTTOMRIGHT", 2, 0)
    else
        panel:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -4, -30)
        panel:SetPoint("BOTTOMRIGHT", WorldMapFrame, "BOTTOMRIGHT", -4, 30)
    end
end

--- Abre ou fecha o painel de membros na região.
function WorldMapView:togglePanel()
    if self._isPanelOpen then
        self:hidePanel()
    else
        self:showPanel()
    end
end

--- Atualiza o estado visual do botão inferior (ativo / inativo).
function WorldMapView:updateButtonState()
    if self._mapButton then
        if self._isPanelOpen then
            if self._mapButton.SetBackdropColor then
                self._mapButton:SetBackdropColor(0.25, 0.17, 0.05, 1.0)
                self._mapButton:SetBackdropBorderColor(1.0, 0.95, 0.35, 1.0)
            end
            if self._mapButton.glow then
                self._mapButton.glow:SetVertexColor(1.0, 0.95, 0.35, 0.85)
            end
        else
            if self._mapButton.SetBackdropColor then
                self._mapButton:SetBackdropColor(0.18, 0.12, 0.04, 0.95)
                self._mapButton:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
            end
            if self._mapButton.glow then
                self._mapButton.glow:SetVertexColor(1.0, 0.82, 0.0, 0.55)
            end
        end
    end
end

--- Exibe o painel de membros da guilda na região.
function WorldMapView:showPanel()
    self:initWorldMapUI()
    if not self._panel then return end

    self:adjustPanelPosition()
    self._panel:Show()
    self._isPanelOpen = true
    self:updateButtonState()

    if self._onScanCallback then
        self._onScanCallback()
    else
        self:refreshVisibleRows()
        self:plotMemberPins()
    end
end

--- Oculta o painel de membros da guilda.
function WorldMapView:hidePanel()
    if self._panel then
        self._panel:Hide()
    end
    self._isPanelOpen = false
    self:updateButtonState()
end

--- Retorna se o painel está aberto.
---@return boolean
function WorldMapView:isPanelShown()
    return self._isPanelOpen == true and self._panel and self._panel:IsShown()
end

--- Atualiza o texto do botão na barra do mapa com a quantidade de membros na região.
---@param count number
function WorldMapView:updateButton(count)
    if not self._mapButton then
        self:initWorldMapUI()
    end
    local num = tonumber(count) or 0
    local color = num > 0 and "|cff00ff00" or "|cffaaaaaa"
    if self._mapButton and self._mapButton.text then
        self._mapButton.text:SetText(string.format("|cffffd200Guilda:|r %s%d na Região|r", color, num))
    end
    self:reanchorMapButton()
    self:updateButtonState()
end

--- Renderiza a lista de membros e plota os pinos de localização no mapa.
---@param membersData table @Lista de membros presentes na região
---@param zoneName string @Nome da região visualizada no mapa
function WorldMapView:renderMembers(membersData, zoneName)
    self._membersData = membersData or {}
    self._currentZoneName = zoneName or "Região Atual"

    if not self._panel then
        self:initWorldMapUI()
    end

    if self._panel then
        self._panel.zoneTitle:SetText("|cff00e5ff" .. self._currentZoneName .. "|r")
        self._panel.countText:SetText(string.format("|cffa8f0a8%d membro(s) encontrado(s)|r", #self._membersData))
    end

    self:updateButton(#self._membersData)

    -- Plota os pinos no mapa sempre que os dados forem atualizados
    self:plotMemberPins()

    -- Atualiza as linhas da lista lateral se o painel estiver aberto
    if self._isPanelOpen then
        self:refreshVisibleRows()
    end
end

--- Atualiza as linhas da tabela de membros no painel lateral.
function WorldMapView:refreshVisibleRows()
    local total = #self._membersData
    local offset = self._scrollOffset or 0

    if self._scrollBar then
        if total > self._maxVisibleRows then
            self._scrollBar:SetMinMaxValues(0, total - self._maxVisibleRows)
            self._scrollBar:Show()
        else
            self._scrollBar:SetMinMaxValues(0, 0)
            self._scrollBar:SetValue(0)
            self._scrollBar:Hide()
            self._scrollOffset = 0
            offset = 0
        end
    end

    if self._panel and self._panel.emptyMsg then
        if total == 0 then
            self._panel.emptyMsg:Show()
        else
            self._panel.emptyMsg:Hide()
        end
    end

    for i = 1, self._maxVisibleRows do
        local row = self._memberRows[i]
        local dataIndex = offset + i
        local data = self._membersData[dataIndex]

        if data and row then
            row.memberData = data
            local cHex = (data.class and CLASS_COLORS[data.class] and CLASS_COLORS[data.class].hex) or "|cffffffff"
            local nameStr = cHex .. (data.name or "Membro") .. "|r"

            -- Ícone da classe
            local coords = data.class and CLASS_ICON_COORDS[data.class]
            if coords and row.classIcon then
                row.classIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
                row.classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                row.classIcon:Show()
            else
                row.classIcon:Hide()
            end

            -- Linha 1: Nome do personagem
            row.nameText:SetText(nameStr)

            -- Linha 2: Nível, Cargo e Coordenadas (se disponíveis)
            local rankStr = data.rankName and data.rankName ~= "" and (" |cffffff00" .. data.rankName .. "|r") or ""
            local coordStr = ""
            if data.coordX and data.coordY and (data.coordX > 0 or data.coordY > 0) then
                local cColor = data.isExact and "|cff40ff40" or "|cffffd200"
                coordStr = string.format(" %s(%.1f, %.1f)|r", cColor, data.coordX * 100, data.coordY * 100)
            else
                coordStr = " |cff888888(Na Região)|r"
            end

            row.subText:SetText(string.format("Lvl %d%s%s", data.level or 1, rankStr, coordStr))
            row:Show()
        elseif row then
            row.memberData = nil
            row:Hide()
        end
    end
end

--- Cria ou obtém um pino reutilizável para exibição no mapa.
---@param index number
---@return table
function WorldMapView:getOrCreatePin(index)
    if self._pins[index] then
        return self._pins[index]
    end

    local canvas = self:getMapCanvas()
    local pin = CreateFrame("Button", "GM_MapPin_" .. index, canvas or WorldMapFrame)
    pin:SetSize(24, 24)
    pin:SetFrameStrata("HIGH")
    pin:SetFrameLevel((canvas and canvas.GetFrameLevel and canvas:GetFrameLevel() or 20) + 15)

    -- Fundo circular perfeitamente centrado
    local bg = pin:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(22, 22)
    bg:SetPoint("CENTER", pin, "CENTER", 0, 0)
    bg:SetVertexColor(0.08, 0.08, 0.08, 0.95)
    pin.bg = bg

    -- Ícone circular de classe do membro perfeitamente centrado
    local icon = pin:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", pin, "CENTER", 0, 0)
    icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    pin.icon = icon

    -- Borda dourada circular simétrica concêntrica
    local border = pin:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Border")
    border:SetSize(32, 32)
    border:SetPoint("CENTER", pin, "CENTER", 0, 0)
    pin.border = border

    -- Nome flutuante logo abaixo do pino
    local label = pin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    label:SetPoint("TOP", pin, "BOTTOM", 0, -2)
    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(1, -1)
    pin.label = label

    pin:SetScript("OnEnter", function(p)
        if p.memberData then
            local data = p.memberData
            GameTooltip:SetOwner(p, "ANCHOR_TOP")
            local cHex = (data.class and CLASS_COLORS[data.class] and CLASS_COLORS[data.class].hex) or "|cffffffff"
            GameTooltip:AddLine(cHex .. (data.name or "Membro") .. "|r")
            GameTooltip:AddLine(string.format("Nível %d %s", data.level or 1, data.classDisplayName or data.class or ""), 1, 1, 1)
            if data.rankName and data.rankName ~= "" then
                GameTooltip:AddLine(string.format("Cargo: |cffffff00%s|r", data.rankName), 0.9, 0.8, 0.5)
            end
            if data.coordX and data.coordY and (data.coordX > 0 or data.coordY > 0) then
                local locType = data.isSelf and "Você" or (data.isExact and "Exatas" or (data.hubLocation or "Região"))
                local cColor = data.isExact and "|cff40ff40" or "|cffffd200"
                GameTooltip:AddLine(string.format("Coordenadas: %s%.1f, %.1f (%s)|r", cColor, data.coordX * 100, data.coordY * 100, locType), 0.9, 0.9, 0.9)
            end
            if data.zone and data.zone ~= "" then
                GameTooltip:AddLine(string.format("Região: |cffffffff%s|r", data.zone), 0.8, 0.8, 0.8)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cff00ff00Clique para sussurrar com o jogador.|r", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end
    end)

    pin:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    pin:SetScript("OnClick", function(p)
        if p.memberData and p.memberData.name then
            if self._onMemberClickCallback then
                self._onMemberClickCallback(p.memberData)
            else
                ChatFrame_OpenChat("/w " .. p.memberData.name .. " ")
            end
        end
    end)

    self._pins[index] = pin
    return pin
end

--- Limpa todos os pinos de membros atualmente visíveis no mapa.
function WorldMapView:clearPins()
    for _, pin in ipairs(self._pins) do
        pin:Hide()
        pin.memberData = nil
    end
end

--- Plota os pinos no mapa nas coordenadas exatas de cada membro.
function WorldMapView:plotMemberPins()
    self:clearPins()

    local canvas = self:getMapCanvas()
    if not canvas or not canvas.GetWidth or not canvas.GetHeight then
        return
    end

    local canvasW = canvas:GetWidth()
    local canvasH = canvas:GetHeight()
    if canvasW <= 0 or canvasH <= 0 then
        return
    end

    local pinIndex = 0
    for _, data in ipairs(self._membersData) do
        local x = data.coordX
        local y = data.coordY
        -- Verifica se possui coordenadas válidas (entre 0 e 1)
        if x and y and x > 0 and x < 1 and y > 0 and y < 1 then
            pinIndex = pinIndex + 1
            local pin = self:getOrCreatePin(pinIndex)

            pin.memberData = data
            pin:SetParent(canvas)
            pin:ClearAllPoints()
            -- Posicionamento centrado em pixels relativos ao TOPLEFT do canvas
            pin:SetPoint("CENTER", canvas, "TOPLEFT", x * canvasW, -y * canvasH)

            -- Ícone de classe
            local coords = data.class and CLASS_ICON_COORDS[data.class]
            if coords then
                pin.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            else
                pin.icon:SetTexCoord(0, 1, 0, 1)
            end

            -- Diferenciação visual da borda do pino: Verde para 'Você', Ciano para coordenadas exatas de rede, Dourado para região
            if data.isSelf then
                pin:SetSize(26, 26)
                pin.bg:SetSize(24, 24)
                pin.icon:SetSize(22, 22)
                pin.border:SetSize(34, 34)
                pin.border:SetVertexColor(0.2, 1.0, 0.2, 1.0)
            elseif data.isExact then
                pin:SetSize(24, 24)
                pin.bg:SetSize(22, 22)
                pin.icon:SetSize(20, 20)
                pin.border:SetSize(32, 32)
                pin.border:SetVertexColor(0.3, 0.9, 1.0, 1.0)
            else
                pin:SetSize(24, 24)
                pin.bg:SetSize(22, 22)
                pin.icon:SetSize(20, 20)
                pin.border:SetSize(32, 32)
                pin.border:SetVertexColor(1.0, 0.85, 0.20, 1.0)
            end

            -- Rótulo com o nome colorido por classe
            local cHex = (data.class and CLASS_COLORS[data.class] and CLASS_COLORS[data.class].hex) or "|cffffffff"
            pin.label:SetText(cHex .. (data.name or "") .. "|r")

            pin:Show()
        end
    end
end

--- Define o callback acionado quando o usuário clica em "Escanear Mapa".
---@param callback function
function WorldMapView:setOnScanCallback(callback)
    self._onScanCallback = callback
end

--- Define o callback acionado quando o usuário clica em um membro na lista ou no pino.
---@param callback function
function WorldMapView:setOnMemberClickCallback(callback)
    self._onMemberClickCallback = callback
end
