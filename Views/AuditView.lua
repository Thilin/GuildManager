---@class AuditView
---@field private _frame table
---@field private _members Member[]
---@field private _flatRows table[]
---@field private _filteredRows table[]
---@field private _offset number
---@field private _hOffset number
---@field private _maxHOffset number
---@field private _rows table[]
---@field private _filterText string
---@field private _activeFilter string
---@field private _collapsedMains table<string, boolean>
---@field private _onRefreshCallback function|nil
---@field private _onSaveCallback function|nil
AuditView = {}
AuditView.__index = AuditView

local DIALOG_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local CONTAINER_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local SUB_CONTAINER_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

--- Paleta de cores padrão Blizzard / WoW Forever (tons bronze, dourado e pergaminho)
local PALETTE = {
    FRAME_BG = { 0.055, 0.035, 0.015, 1.0 },
    FRAME_BORDER = { 1.0, 0.68, 0.22, 1.0 },
    INSET_BG = { 0.035, 0.022, 0.010, 0.85 },
    INSET_BORDER = { 0.71, 0.49, 0.16, 0.95 },
    SEPARATOR = { 0.58, 0.37, 0.11, 0.90 },
    SUB_BOX_BG = { 0.022, 0.014, 0.006, 0.75 },
    SUB_BOX_BORDER = { 0.62, 0.41, 0.13, 0.90 },
    FOCUS_BG = { 0.065, 0.045, 0.020, 0.95 },
    FOCUS_BORDER = { 0.85, 0.58, 0.20, 1.0 },
    HIGHLIGHT_TINT = { 0.71, 0.49, 0.16, 0.20 },
    HEADER_ROW_BG = { 0.12, 0.08, 0.03, 0.95 },
    ROW_MAIN_BG = { 0.080, 0.052, 0.022, 0.65 },
    ROW_ALT_BG = { 0.022, 0.016, 0.008, 0.50 },
    ROW_EVEN_BG = { 0.045, 0.030, 0.014, 0.45 },
    ROW_ODD_BG = { 0.065, 0.045, 0.020, 0.45 },
    ACTIVE_TAB_BG = { 0.20, 0.13, 0.05, 0.95 },
    ACTIVE_TAB_BORDER = { 0.95, 0.70, 0.25, 1.0 },
    INACTIVE_TAB_BG = { 0.045, 0.030, 0.012, 0.80 },
    INACTIVE_TAB_BORDER = { 0.50, 0.33, 0.12, 0.85 },
    CELL_HOVER_BG = { 0.90, 0.70, 0.20, 0.20 },
}

--- Definição otimizada das colunas com espaçamentos proporcionais e a coluna ONLINE entre Cargo e Nota Pública
local COLUMNS = {
    { id = "name",        title = "PERSONAGEM",       x = 0,    width = 200, align = "LEFT",   editable = false },
    { id = "level",       title = "NV",               x = 200,  width = 34,  align = "CENTER", editable = false },
    { id = "rank",        title = "CARGO",            x = 234,  width = 95,  align = "LEFT",   editable = false },
    { id = "online",      title = "ONLINE",           x = 329,  width = 95,  align = "LEFT",   editable = false },
    { id = "publicNote",  title = "NOTA PÚBLICA",      x = 424,  width = 125, align = "LEFT",   editable = false },
    { id = "officerNote", title = "NOTA DE OFICIAL",   x = 549,  width = 125, align = "LEFT",   editable = false },
    { id = "dateJoin",    title = "ENTRADA",          x = 674,  width = 85,  align = "LEFT",   editable = true,  label = "Data de Entrada" },
    { id = "recruiter",   title = "RECRUTADOR",       x = 759,  width = 105, align = "LEFT",   editable = true,  label = "Recrutador" },
    { id = "birthday",    title = "ANIVERSÁRIO",      x = 864,  width = 80,  align = "LEFT",   editable = true,  label = "Aniversário" },
    { id = "customNote",  title = "NOTA INTERNA",     x = 944,  width = 200, align = "LEFT",   editable = true,  label = "Nota Interna" },
}

local TOTAL_TABLE_WIDTH = 1144

--- Retorna a data de hoje no formato AAAA-MM-DD.
---@return string
local function getTodayString()
    if date then
        return date("%Y-%m-%d")
    elseif os and os.date then
        return os.date("%Y-%m-%d")
    end
    return ""
end

--- Retorna o nome do jogador conectado no momento.
---@return string
local function getPlayerName()
    return UnitName and UnitName("player") or ""
end

--- Construtor da View de Auditoria da Guilda.
---@return AuditView
function AuditView:new()
    local instance = setmetatable({}, self)

    instance._frame = nil
    instance._members = {}
    instance._flatRows = {}
    instance._filteredRows = {}
    instance._offset = 0
    instance._hOffset = 0
    instance._maxHOffset = 0
    instance._rows = {}
    instance._filterText = ""
    instance._activeFilter = "ALL"
    instance._collapsedMains = {}
    instance._numVisibleRows = 15
    instance._rowHeight = 24
    instance._onRefreshCallback = nil
    instance._onSaveCallback = nil
    instance._editModal = nil
    instance._editingMember = nil

    instance:createUI()

    return instance
end

--- Define o callback disparado ao solicitar atualização ou abertura da tela.
---@param callback function
function AuditView:setOnRefreshCallback(callback)
    self._onRefreshCallback = callback
end

--- Define o callback disparado ao salvar alterações de um membro via modal.
---@param callback function
function AuditView:setOnSaveCallback(callback)
    self._onSaveCallback = callback
end

--- Cria e estiliza os componentes visuais da janela de auditoria no padrão WoW Forever.
function AuditView:createUI()
    if self._frame then
        return
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "GuildManagerAuditFrame", UIParent, template)
    self._frame = frame

    frame:SetSize(960, 540)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:Hide()

    -- Fecha janela com tecla ESC
    if UISpecialFrames then
        table.insert(UISpecialFrames, "GuildManagerAuditFrame")
    end

    -- Efeitos sonoros ao abrir e fechar
    frame:SetScript("OnShow", function()
        if PlaySound then
            if SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN then
                PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
            else
                pcall(PlaySound, 839)
            end
        end
        self:updateScrollDimensions()
        if self._onRefreshCallback then
            self._onRefreshCallback()
        end
    end)

    frame:SetScript("OnHide", function()
        if PlaySound then
            if SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE then
                PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
            else
                pcall(PlaySound, 840)
            end
        end
        if self._editModal and self._editModal:IsShown() then
            self._editModal:Hide()
        end
    end)

    -- Camada sólida de fundo
    local solidBg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    solidBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    solidBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    solidBg:SetColorTexture(0.04, 0.03, 0.02, 1.0)

    -- Textura de pergaminho clássica GuildManager
    local bgTex = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    bgTex:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    bgTex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    bgTex:SetTexture("Interface\\AddOns\\GuildManager\\Textures\\background.tga")
    bgTex:SetAlpha(0.45)

    -- Moldura e borda temática Blizzard / WoW Forever
    if frame.SetBackdrop then
        frame:SetBackdrop(DIALOG_BACKDROP)
        frame:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], 0.20)
        frame:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], PALETTE.FRAME_BORDER[4])
    end

    -- Botão Fechar ("X" clássico)
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetSize(28, 28)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    -- Ícone da Facção
    local factionIcon = frame:CreateTexture(nil, "ARTWORK")
    factionIcon:SetSize(26, 26)
    factionIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if faction == "Horde" then
        factionIcon:SetTexture("Interface\\AddOns\\GuildManager\\Textures\\Horde-Logo.tga")
    else
        factionIcon:SetTexture("Interface\\AddOns\\GuildManager\\Textures\\Alliance-Logo.tga")
    end
    self._factionIcon = factionIcon

    -- Título da Janela
    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", factionIcon, "RIGHT", 10, 0)
    titleText:SetText("|cffffd200AUDITORIA DE MEMBROS DA GUILDA|r")
    self._titleText = titleText

    -- Subtítulo informativo
    local subtitleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitleText:SetPoint("LEFT", titleText, "RIGHT", 12, 0)
    subtitleText:SetText("|cffaaaaaa(Dados Blizzard + Gestão de Entrada, Recrutador, Aniversário e Notas)|r")

    -- Divisória abaixo do cabeçalho
    local headerSep = frame:CreateTexture(nil, "ARTWORK")
    headerSep:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -44)
    headerSep:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    headerSep:SetHeight(1)
    headerSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- =========================================================================
    -- BARRA DE BUSCA E FILTROS RÁPIDOS
    -- =========================================================================
    local searchEB = CreateFrame("EditBox", nil, frame, template)
    searchEB:SetPoint("TOPLEFT", headerSep, "BOTTOMLEFT", 0, -8)
    searchEB:SetSize(200, 22)
    searchEB:SetFontObject("GameFontHighlightSmall")
    searchEB:SetAutoFocus(false)
    searchEB:SetTextInsets(6, 6, 1, 1)
    if searchEB.SetBackdrop then
        searchEB:SetBackdrop(SUB_CONTAINER_BACKDROP)
        searchEB:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        searchEB:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end
    searchEB:SetScript("OnEditFocusGained", function(box)
        if box.SetBackdropBorderColor then
            box:SetBackdropBorderColor(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], 1.0)
        end
        if box.SetBackdropColor then
            box:SetBackdropColor(PALETTE.FOCUS_BG[1], PALETTE.FOCUS_BG[2], PALETTE.FOCUS_BG[3], 0.95)
        end
    end)
    searchEB:SetScript("OnEditFocusLost", function(box)
        if box.SetBackdropBorderColor then
            box:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.90)
        end
        if box.SetBackdropColor then
            box:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.75)
        end
    end)

    local searchHint = searchEB:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchHint:SetPoint("LEFT", searchEB, "LEFT", 8, 0)
    searchHint:SetText("|cff888888Buscar personagem, nota, cargo...|r")
    searchEB.hint = searchHint

    searchEB:SetScript("OnTextChanged", function(box)
        local txt = box:GetText()
        if txt and txt ~= "" then
            searchHint:Hide()
        else
            searchHint:Show()
        end
        self._filterText = txt or ""
        self:applyFilters()
    end)
    searchEB:SetScript("OnEscapePressed", function(box)
        box:SetText("")
        box:ClearFocus()
    end)
    self._searchEB = searchEB

    -- Botões de filtro rápido
    local filterTabs = {
        { id = "ALL", label = "Todos" },
        { id = "ONLINE", label = "Online" },
        { id = "MAINS", label = "Apenas Mains" },
        { id = "WITH_ALTS", label = "Com Alts" },
        { id = "NO_RECRUITER", label = "Sem Recrutador" },
        { id = "NO_OFFICER_NOTE", label = "Sem Nota Oficial" },
        { id = "NO_CUSTOM_NOTE", label = "Sem Nota Interna" },
    }

    self._filterButtons = {}
    local prevTab = searchEB
    for _, tabData in ipairs(filterTabs) do
        local tabBtn = CreateFrame("Button", nil, frame, template)
        tabBtn:SetHeight(22)
        tabBtn:SetPoint("LEFT", prevTab, "RIGHT", 5, 0)
        tabBtn.tabId = tabData.id

        local btnText = tabBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btnText:SetPoint("CENTER", tabBtn, "CENTER", 0, 0)
        btnText:SetText(tabData.label)
        tabBtn.text = btnText

        local textWidth = btnText:GetStringWidth() or 40
        tabBtn:SetWidth(textWidth + 12)

        tabBtn:SetScript("OnClick", function()
            self._activeFilter = tabData.id
            self:updateFilterButtonsVisual()
            self:applyFilters()
        end)

        self._filterButtons[tabData.id] = tabBtn
        prevTab = tabBtn
    end

    -- =========================================================================
    -- TABELA PRINCIPAL DE AUDITORIA (INSET)
    -- =========================================================================
    local tableInset = CreateFrame("Frame", "GM_AuditTableInset", frame, template)
    tableInset:SetPoint("TOPLEFT", searchEB, "BOTTOMLEFT", 0, -8)
    tableInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 40)
    if tableInset.SetBackdrop then
        tableInset:SetBackdrop(CONTAINER_BACKDROP)
        tableInset:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        tableInset:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end
    self._tableInset = tableInset

    -- Rolagem com a roda do mouse sobre a área de tabela
    tableInset:EnableMouseWheel(true)
    tableInset:SetScript("OnMouseWheel", function(_, delta)
        self:onTableMouseWheel(delta)
    end)

    -- ScrollFrame do Cabeçalho (rolagem horizontal vinculada)
    local headerScrollFrame = CreateFrame("ScrollFrame", "GM_AuditHeaderScrollFrame", tableInset)
    headerScrollFrame:SetPoint("TOPLEFT", tableInset, "TOPLEFT", 4, -4)
    headerScrollFrame:SetPoint("TOPRIGHT", tableInset, "TOPRIGHT", -22, -4)
    headerScrollFrame:SetHeight(24)
    headerScrollFrame:EnableMouse(true)
    headerScrollFrame:SetScript("OnMouseWheel", function(_, delta)
        self:onTableMouseWheel(delta)
    end)

    local headerContent = CreateFrame("Frame", nil, headerScrollFrame, template)
    headerContent:SetSize(TOTAL_TABLE_WIDTH, 24)
    if headerContent.SetBackdrop then
        headerContent:SetBackdrop(SUB_CONTAINER_BACKDROP)
        headerContent:SetBackdropColor(PALETTE.HEADER_ROW_BG[1], PALETTE.HEADER_ROW_BG[2], PALETTE.HEADER_ROW_BG[3], PALETTE.HEADER_ROW_BG[4])
        headerContent:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end
    headerScrollFrame:SetScrollChild(headerContent)
    self._headerScrollFrame = headerScrollFrame
    self._headerContent = headerContent

    -- Construção das colunas do cabeçalho
    for _, col in ipairs(COLUMNS) do
        local colHeader = headerContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        colHeader:SetPoint("LEFT", headerContent, "LEFT", col.x + 4, 0)
        colHeader:SetWidth(col.width - 6)
        colHeader:SetJustifyH(col.align or "LEFT")

        if col.editable then
            colHeader:SetText(string.format("|cffffd200%s|r |cff00ff99*|r", col.title))
        else
            colHeader:SetText(string.format("|cffffd200%s|r", col.title))
        end
    end

    -- ScrollFrame das Linhas (rolagem horizontal vinculada)
    local rowsScrollFrame = CreateFrame("ScrollFrame", "GM_AuditRowsScrollFrame", tableInset)
    rowsScrollFrame:SetPoint("TOPLEFT", headerScrollFrame, "BOTTOMLEFT", 0, -2)
    rowsScrollFrame:SetPoint("BOTTOMRIGHT", tableInset, "BOTTOMRIGHT", -22, 22)
    rowsScrollFrame:EnableMouse(true)
    rowsScrollFrame:SetScript("OnMouseWheel", function(_, delta)
        self:onTableMouseWheel(delta)
    end)

    local rowsContent = CreateFrame("Frame", nil, rowsScrollFrame)
    rowsContent:SetSize(TOTAL_TABLE_WIDTH, self._numVisibleRows * self._rowHeight)
    rowsScrollFrame:SetScrollChild(rowsContent)
    self._rowsScrollFrame = rowsScrollFrame
    self._rowsContent = rowsContent

    -- Scrollbar vertical lateral
    local scrollBar = CreateFrame("Slider", "GM_AuditScrollBar", tableInset, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPRIGHT", tableInset, "TOPRIGHT", -4, -28)
    scrollBar:SetPoint("BOTTOMRIGHT", tableInset, "BOTTOMRIGHT", -4, 24)
    scrollBar:SetWidth(16)
    scrollBar:SetScript("OnValueChanged", function(_, val)
        self._offset = math.floor(val)
        self:renderRows()
    end)
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValueStep(1)

    local upBtn = _G["GM_AuditScrollBarScrollUpButton"] or (scrollBar and scrollBar.ScrollUpButton)
    if upBtn then
        upBtn:SetScript("OnClick", function()
            self:scroll(1)
        end)
    end
    local downBtn = _G["GM_AuditScrollBarScrollDownButton"] or (scrollBar and scrollBar.ScrollDownButton)
    if downBtn then
        downBtn:SetScript("OnClick", function()
            self:scroll(-1)
        end)
    end
    self._scrollBar = scrollBar

    -- =========================================================================
    -- BARRA DE ROLAGEM HORIZONTAL INFERIOR
    -- =========================================================================
    local hScrollContainer = CreateFrame("Frame", "GM_AuditHScrollContainer", tableInset, template)
    hScrollContainer:SetPoint("BOTTOMLEFT", tableInset, "BOTTOMLEFT", 4, 4)
    hScrollContainer:SetPoint("BOTTOMRIGHT", tableInset, "BOTTOMRIGHT", -24, 4)
    hScrollContainer:SetHeight(16)
    hScrollContainer:EnableMouseWheel(true)
    hScrollContainer:SetScript("OnMouseWheel", function(_, delta)
        self:scrollH(-delta * 80)
    end)
    self._hScrollContainer = hScrollContainer

    -- Botão rolar horizontalmente para a esquerda (<)
    local hLeftBtn = CreateFrame("Button", nil, hScrollContainer, template)
    hLeftBtn:SetSize(16, 16)
    hLeftBtn:SetPoint("LEFT", hScrollContainer, "LEFT", 0, 0)
    if hLeftBtn.SetBackdrop then
        hLeftBtn:SetBackdrop(SUB_CONTAINER_BACKDROP)
        hLeftBtn:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.9)
        hLeftBtn:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.9)
    end
    local hLeftTxt = hLeftBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hLeftTxt:SetPoint("CENTER", hLeftBtn, "CENTER", 0, 0)
    hLeftTxt:SetText("|cffffd200◄|r")
    hLeftBtn:SetScript("OnClick", function()
        self:scrollH(-100)
    end)

    -- Botão rolar horizontalmente para a direita (>)
    local hRightBtn = CreateFrame("Button", nil, hScrollContainer, template)
    hRightBtn:SetSize(16, 16)
    hRightBtn:SetPoint("RIGHT", hScrollContainer, "RIGHT", 0, 0)
    if hRightBtn.SetBackdrop then
        hRightBtn:SetBackdrop(SUB_CONTAINER_BACKDROP)
        hRightBtn:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.9)
        hRightBtn:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.9)
    end
    local hRightTxt = hRightBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hRightTxt:SetPoint("CENTER", hRightBtn, "CENTER", 0, 0)
    hRightTxt:SetText("|cffffd200►|r")
    hRightBtn:SetScript("OnClick", function()
        self:scrollH(100)
    end)

    -- Slider horizontal
    local hSlider = CreateFrame("Slider", "GM_AuditHSlider", hScrollContainer, template)
    hSlider:SetPoint("LEFT", hLeftBtn, "RIGHT", 4, 0)
    hSlider:SetPoint("RIGHT", hRightBtn, "LEFT", -4, 0)
    hSlider:SetHeight(12)
    hSlider:SetOrientation("HORIZONTAL")
    if hSlider.SetBackdrop then
        hSlider:SetBackdrop(SUB_CONTAINER_BACKDROP)
        hSlider:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.9)
        hSlider:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.9)
    end

    local hThumb = hSlider:CreateTexture(nil, "OVERLAY")
    hThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    hThumb:SetSize(36, 14)
    hSlider:SetThumbTexture(hThumb)
    hSlider:SetMinMaxValues(0, 100)
    hSlider:SetValue(0)
    hSlider:SetScript("OnValueChanged", function(_, val)
        self:setHorizontalOffset(val, true)
    end)
    self._hSlider = hSlider

    -- Mensagem de aviso caso lista vazia
    local emptyNotice = tableInset:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyNotice:SetPoint("CENTER", tableInset, "CENTER", 0, -10)
    emptyNotice:SetText("Nenhum membro encontrado nos critérios selecionados.")
    emptyNotice:Hide()
    self._emptyNotice = emptyNotice

    -- =========================================================================
    -- LINHAS REUTILIZÁVEIS DA TABELA
    -- =========================================================================
    self._rows = {}
    local numRows = self._numVisibleRows
    local rowHeight = self._rowHeight

    for i = 1, numRows do
        local row = CreateFrame("Button", nil, rowsContent, template)
        row:SetSize(TOTAL_TABLE_WIDTH, rowHeight)
        row:SetPoint("TOPLEFT", rowsContent, "TOPLEFT", 0, -((i - 1) * rowHeight))

        -- Fundo dinâmico da linha
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        local bgColor = (i % 2 == 0) and PALETTE.ROW_EVEN_BG or PALETTE.ROW_ODD_BG
        bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
        row.bg = bg

        -- Highlight suave ao passar o mouse na linha inteira
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(row)
        hl:SetColorTexture(PALETTE.HIGHLIGHT_TINT[1], PALETTE.HIGHLIGHT_TINT[2], PALETTE.HIGHLIGHT_TINT[3], PALETTE.HIGHLIGHT_TINT[4])
        row:SetHighlightTexture(hl)

        -- Barra de destaque dourada na borda esquerda para Mains
        local mainAccent = row:CreateTexture(nil, "OVERLAY")
        mainAccent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        mainAccent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 3, 0)
        mainAccent:SetColorTexture(1.0, 0.82, 0.0, 0.90)
        mainAccent:Hide()
        row.mainAccent = mainAccent

        -- Botão de Expandir/Recolher Alts no Main
        local toggleBtn = CreateFrame("Button", nil, row)
        toggleBtn:SetSize(14, 14)
        toggleBtn:SetPoint("LEFT", row, "LEFT", 4, 0)
        local toggleText = toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        toggleText:SetPoint("CENTER", toggleBtn, "CENTER", 0, 0)
        toggleText:SetText("|cffffd200-|r")
        toggleBtn.text = toggleText
        toggleBtn:Hide()
        row.toggleBtn = toggleBtn

        -- Coluna 1: Personagem (Árvore Main / Alt + Nome colorido por classe + Contador de Alts)
        local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameTxt:SetPoint("LEFT", row, "LEFT", 22, 0)
        nameTxt:SetWidth(176)
        nameTxt:SetJustifyH("LEFT")
        nameTxt:SetWordWrap(false)
        row.nameTxt = nameTxt

        -- Coluna 2: Nível (Centralizado)
        local levelTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        levelTxt:SetPoint("LEFT", row, "LEFT", 200, 0)
        levelTxt:SetWidth(34)
        levelTxt:SetJustifyH("CENTER")
        row.levelTxt = levelTxt

        -- Coluna 3: Cargo (Rank da Guilda)
        local rankTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rankTxt:SetPoint("LEFT", row, "LEFT", 234, 0)
        rankTxt:SetWidth(92)
        rankTxt:SetJustifyH("LEFT")
        rankTxt:SetWordWrap(false)
        row.rankTxt = rankTxt

        -- Coluna 4: ONLINE (Status de Conexão ou Tempo desde Última Vez Online)
        local onlineTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        onlineTxt:SetPoint("LEFT", row, "LEFT", 329, 0)
        onlineTxt:SetWidth(92)
        onlineTxt:SetJustifyH("LEFT")
        onlineTxt:SetWordWrap(false)
        row.onlineTxt = onlineTxt

        -- Coluna 5: Nota Pública (Blizzard - Somente Leitura)
        local publicNoteTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        publicNoteTxt:SetPoint("LEFT", row, "LEFT", 424, 0)
        publicNoteTxt:SetWidth(121)
        publicNoteTxt:SetJustifyH("LEFT")
        publicNoteTxt:SetWordWrap(false)
        row.publicNoteTxt = publicNoteTxt

        -- Coluna 6: Nota de Oficial (Blizzard - Somente Leitura)
        local officerNoteTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        officerNoteTxt:SetPoint("LEFT", row, "LEFT", 549, 0)
        officerNoteTxt:SetWidth(121)
        officerNoteTxt:SetJustifyH("LEFT")
        officerNoteTxt:SetWordWrap(false)
        row.officerNoteTxt = officerNoteTxt

        -- =====================================================================
        -- CÉLULAS EDITÁVEIS (ENTRADA, RECRUTADOR, ANIVERSÁRIO, NOTA INTERNA)
        -- =====================================================================
        local function setupEditableCell(colId, xPos, width, label)
            local cellBtn = CreateFrame("Button", nil, row)
            cellBtn:SetPoint("TOPLEFT", row, "TOPLEFT", xPos, 0)
            cellBtn:SetSize(width, rowHeight)

            local cellHl = cellBtn:CreateTexture(nil, "HIGHLIGHT")
            cellHl:SetAllPoints(cellBtn)
            cellHl:SetColorTexture(PALETTE.CELL_HOVER_BG[1], PALETTE.CELL_HOVER_BG[2], PALETTE.CELL_HOVER_BG[3], PALETTE.CELL_HOVER_BG[4])
            cellBtn:SetHighlightTexture(cellHl)

            local cellTxt = cellBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cellTxt:SetPoint("LEFT", cellBtn, "LEFT", 4, 0)
            cellTxt:SetPoint("RIGHT", cellBtn, "RIGHT", -4, 0)
            cellTxt:SetJustifyH("LEFT")
            cellTxt:SetWordWrap(false)
            cellBtn.txt = cellTxt

            cellBtn:EnableMouseWheel(true)
            cellBtn:SetScript("OnMouseWheel", function(_, delta)
                self:onTableMouseWheel(delta)
            end)

            cellBtn:SetScript("OnEnter", function(btn)
                if row.rowData and row.rowData.member then
                    GameTooltip:SetOwner(btn, "ANCHOR_TOP")
                    GameTooltip:AddLine(string.format("|cffffd200%s|r", label), 1, 1, 1)
                    local currentVal = cellTxt:GetText() or ""
                    GameTooltip:AddLine(string.format("Valor atual: |cffffffff%s|r", currentVal), 0.85, 0.85, 0.85, true)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cff00ff00Clique para abrir a janela de edição|r", 0.2, 1.0, 0.2)
                    GameTooltip:Show()
                end
            end)

            cellBtn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            cellBtn:SetScript("OnClick", function()
                if row.rowData and row.rowData.member then
                    self:openEditModal(row.rowData.member, colId)
                end
            end)

            return cellBtn
        end

        -- Coluna 7: Data de Entrada (Editável)
        local dateJoinCell = setupEditableCell("dateJoin", 674, 85, "Data de Entrada")
        row.dateJoinBtn = dateJoinCell
        row.dateJoinTxt = dateJoinCell.txt

        -- Coluna 8: Recrutador (Editável)
        local recruiterCell = setupEditableCell("recruiter", 759, 105, "Recrutador")
        row.recruiterBtn = recruiterCell
        row.recruiterTxt = recruiterCell.txt

        -- Coluna 9: Aniversário (Editável)
        local birthdayCell = setupEditableCell("birthday", 864, 80, "Aniversário")
        row.birthdayBtn = birthdayCell
        row.birthdayTxt = birthdayCell.txt

        -- Coluna 10: Nota Interna (Editável)
        local customNoteCell = setupEditableCell("customNote", 944, 200, "Nota Interna")
        row.customNoteBtn = customNoteCell
        row.customNoteTxt = customNoteCell.txt

        -- Scroll do mouse na linha
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta)
            self:onTableMouseWheel(delta)
        end)

        -- Clique na parte Blizzard / personagem abre a ficha do membro
        row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnClick", function(r)
            if r.rowData and r.rowData.member then
                local mName = r.rowData.member:getName()
                if _G.GM and _G.GM.memberView and _G.GM.memberView.showMember then
                    _G.GM.memberView:showMember(mName)
                end
            end
        end)

        -- Alternância de colapso de alts
        toggleBtn:SetScript("OnClick", function(btn)
            local r = btn:GetParent()
            if r.rowData and r.rowData.isMain and r.rowData.hasAlts then
                local mainName = r.rowData.member:getName()
                self._collapsedMains[mainName] = not self._collapsedMains[mainName]
                self:rebuildFlatRows()
                self:applyFilters()
            end
        end)

        -- Tooltip detalhado na passagem do mouse pelas áreas de leitura
        row:SetScript("OnEnter", function(r)
            if r.rowData and r.rowData.member then
                local m = r.rowData.member
                GameTooltip:SetOwner(r, "ANCHOR_RIGHT")

                local coloredName = self:formatColoredName(m:getName(), m:getGuid(), m:getClass())
                local rank = m:getRankName() ~= "" and m:getRankName() or "Membro"
                local lvl = m:getLevel() or 1
                local race = m:getRace() ~= "" and m:getRace() or "Desconhecido"
                local classDisp = m:getClassDisplayName() ~= "" and m:getClassDisplayName() or m:getClass()

                local tag = r.rowData.isAlt and ("|cff00e5ff[ALT de " .. (r.rowData.mainName or "") .. "]|r") or "|cffffd200[MAIN]|r"
                GameTooltip:AddLine(string.format("%s %s (Nível %d %s %s)", tag, coloredName, lvl, race, classDisp), 1, 1, 1)
                GameTooltip:AddLine(string.format("Cargo: |cffffd200%s|r", rank), 0.9, 0.8, 0.5)

                -- Status de Conexão no Tooltip
                local isOnline = m:isOnline()
                local statusStr = ""
                if isOnline then
                    local s = m:getStatus() or 0
                    if s == 1 then
                        statusStr = "|cffffaa00Online (AFK)|r"
                    elseif s == 2 then
                        statusStr = "|cffff4444Online (DND)|r"
                    else
                        statusStr = "|cff00ff00Online|r"
                    end
                else
                    local lo = m:getLastOnline()
                    if lo and lo ~= "" then
                        statusStr = string.format("|cff888888Offline (Visto por último: %s)|r", lo)
                    else
                        statusStr = "|cff888888Offline|r"
                    end
                end
                GameTooltip:AddLine("Status: " .. statusStr, 0.9, 0.9, 0.9)

                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cffffd200Informações Nativas da Blizzard (Somente Leitura):|r")
                GameTooltip:AddLine(string.format("Nota Pública: |cffffffff%s|r", m:getPublicNote() ~= "" and m:getPublicNote() or "(Nenhuma)"), 0.8, 0.8, 0.8, true)
                GameTooltip:AddLine(string.format("Nota de Oficial: |cffffffff%s|r", m:getOfficerNote() ~= "" and m:getOfficerNote() or "(Nenhuma)"), 0.8, 0.8, 0.8, true)

                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cffffd200Informações de Gestão (Clique nos campos para editar):|r")
                GameTooltip:AddLine(string.format("Data de Entrada: |cffffffff%s|r", m:getDateJoin() ~= "" and m:getDateJoin() or "(Não informada)"), 0.8, 0.8, 0.8)

                local rec = m:getRecruiter()
                local coloredRec = (rec and rec ~= "" and rec ~= "Desconhecido") and self:formatColoredName(rec) or "|cff888888Desconhecido|r"
                GameTooltip:AddLine("Recrutador: " .. coloredRec, 0.8, 0.8, 0.8)

                local bday = m:getBirthday()
                GameTooltip:AddLine(string.format("Aniversário: |cffffffff%s|r", bday ~= "" and bday or "(Não informado)"), 0.8, 0.8, 0.8)

                local cNote = m:getCustomNote()
                GameTooltip:AddLine(string.format("Nota Interna: |cffffffff%s|r", cNote ~= "" and cNote or "(Nenhuma)"), 0.8, 0.8, 0.8, true)

                if r.rowData.altList and #r.rowData.altList > 0 then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(string.format("|cffffd200Alts Vinculados (%d):|r", #r.rowData.altList))
                    for _, altName in ipairs(r.rowData.altList) do
                        GameTooltip:AddLine("  • " .. self:formatColoredName(altName), 0.8, 0.8, 0.8)
                    end
                end

                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cff00ff00Clique no personagem para abrir a ficha completa|r", 0.2, 1.0, 0.2)
                GameTooltip:AddLine("|cffffd200Dica: Segure SHIFT + Roda do Mouse para rolar horizontalmente|r", 0.9, 0.8, 0.3)
                GameTooltip:Show()
            end
        end)

        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        self._rows[i] = row
    end

    -- =========================================================================
    -- RODAPÉ
    -- =========================================================================
    local footerText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footerText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 14)
    footerText:SetText("|cffaaaaaaTotal de membros na guilda: 0|r")
    self._footerText = footerText

    -- Botão Atualizar
    local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(90, 22)
    refreshBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 10)
    refreshBtn:SetText("Atualizar")
    refreshBtn:SetScript("OnClick", function()
        if self._onRefreshCallback then
            self._onRefreshCallback()
        else
            self:applyFilters()
        end
    end)
    self._refreshBtn = refreshBtn

    self:updateFilterButtonsVisual()
    self:createEditModal()
end

--- Cria a janela modal de edição de informações de gestão do membro.
function AuditView:createEditModal()
    if self._editModal then
        return
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local modal = CreateFrame("Frame", "GuildManagerAuditEditModal", UIParent, template)
    modal:SetSize(460, 390)
    modal:SetFrameStrata("DIALOG")
    modal:SetToplevel(true)
    modal:SetClampedToScreen(true)
    modal:EnableMouse(true)
    modal:SetMovable(true)
    modal:RegisterForDrag("LeftButton")
    modal:SetScript("OnDragStart", function(f) f:StartMoving() end)
    modal:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    modal:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    modal:Hide()

    -- Fecha janela com tecla ESC
    if UISpecialFrames then
        table.insert(UISpecialFrames, "GuildManagerAuditEditModal")
    end

    -- Moldura da modal
    if modal.SetBackdrop then
        modal:SetBackdrop(DIALOG_BACKDROP)
        modal:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], 0.98)
        modal:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], 1.0)
    end

    -- Botão Fechar ("X")
    local closeBtn = CreateFrame("Button", nil, modal, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -4, -4)
    closeBtn:SetSize(28, 28)
    closeBtn:SetScript("OnClick", function()
        modal:Hide()
    end)

    -- Título da Modal
    local modalTitle = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    modalTitle:SetPoint("TOPLEFT", modal, "TOPLEFT", 18, -16)
    modalTitle:SetText("|cffffd200EDITAR INFORMAÇÕES DO MEMBRO|r")

    -- Cabeçalho do Membro (Nome colorido, nível, raça, classe, status Main/Alt)
    local memberHeader = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    memberHeader:SetPoint("TOPLEFT", modalTitle, "BOTTOMLEFT", 0, -8)
    memberHeader:SetText("")
    modal.memberHeader = memberHeader

    local memberSubHeader = modal:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    memberSubHeader:SetPoint("TOPLEFT", memberHeader, "BOTTOMLEFT", 0, -3)
    memberSubHeader:SetText("")
    modal.memberSubHeader = memberSubHeader

    -- Divisória abaixo do cabeçalho
    local modalSep = modal:CreateTexture(nil, "ARTWORK")
    modalSep:SetPoint("TOPLEFT", modal, "TOPLEFT", 16, -74)
    modalSep:SetPoint("RIGHT", modal, "RIGHT", -16, 0)
    modalSep:SetHeight(1)
    modalSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- Helper para estilizar EditBoxes da Modal
    local function styleModalBox(eb)
        eb:SetFontObject("GameFontHighlightSmall")
        eb:SetAutoFocus(false)
        eb:SetTextInsets(6, 6, 2, 2)
        if eb.SetBackdrop then
            eb:SetBackdrop(SUB_CONTAINER_BACKDROP)
            eb:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
            eb:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
        end
        eb:SetScript("OnEditFocusGained", function(box)
            if box.SetBackdropBorderColor then
                box:SetBackdropBorderColor(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], 1.0)
            end
            if box.SetBackdropColor then
                box:SetBackdropColor(PALETTE.FOCUS_BG[1], PALETTE.FOCUS_BG[2], PALETTE.FOCUS_BG[3], 0.95)
            end
        end)
        eb:SetScript("OnEditFocusLost", function(box)
            if box.SetBackdropBorderColor then
                box:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.90)
            end
            if box.SetBackdropColor then
                box:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.75)
            end
        end)
    end

    -- 1. CAMPO: DATA DE ENTRADA
    local dateJoinLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dateJoinLabel:SetPoint("TOPLEFT", modalSep, "BOTTOMLEFT", 4, -12)
    dateJoinLabel:SetText("|cffffd200Data de Entrada:|r |cffaaaaaa(AAAA-MM-DD)|r")

    local dateJoinEB = CreateFrame("EditBox", nil, modal, template)
    dateJoinEB:SetPoint("TOPLEFT", dateJoinLabel, "BOTTOMLEFT", 0, -4)
    dateJoinEB:SetSize(280, 24)
    styleModalBox(dateJoinEB)
    modal.dateJoinEB = dateJoinEB

    local dateJoinTodayBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    dateJoinTodayBtn:SetPoint("LEFT", dateJoinEB, "RIGHT", 6, 0)
    dateJoinTodayBtn:SetSize(64, 22)
    dateJoinTodayBtn:SetText("Hoje")
    dateJoinTodayBtn:SetScript("OnClick", function()
        dateJoinEB:SetText(getTodayString())
    end)

    -- 2. CAMPO: RECRUTADOR
    local recruiterLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    recruiterLabel:SetPoint("TOPLEFT", dateJoinEB, "BOTTOMLEFT", 0, -10)
    recruiterLabel:SetText("|cffffd200Recrutador:|r")

    local recruiterEB = CreateFrame("EditBox", nil, modal, template)
    recruiterEB:SetPoint("TOPLEFT", recruiterLabel, "BOTTOMLEFT", 0, -4)
    recruiterEB:SetSize(280, 24)
    styleModalBox(recruiterEB)
    modal.recruiterEB = recruiterEB

    local recruiterSelfBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    recruiterSelfBtn:SetPoint("LEFT", recruiterEB, "RIGHT", 6, 0)
    recruiterSelfBtn:SetSize(64, 22)
    recruiterSelfBtn:SetText("Eu")
    recruiterSelfBtn:SetScript("OnClick", function()
        recruiterEB:SetText(getPlayerName())
    end)

    -- 3. CAMPO: ANIVERSÁRIO
    local birthdayLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    birthdayLabel:SetPoint("TOPLEFT", recruiterEB, "BOTTOMLEFT", 0, -10)
    birthdayLabel:SetText("|cffffd200Aniversário:|r |cffaaaaaa(DD/MM)|r")

    local birthdayEB = CreateFrame("EditBox", nil, modal, template)
    birthdayEB:SetPoint("TOPLEFT", birthdayLabel, "BOTTOMLEFT", 0, -4)
    birthdayEB:SetSize(160, 24)
    styleModalBox(birthdayEB)
    modal.birthdayEB = birthdayEB

    local birthdayHint = modal:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    birthdayHint:SetPoint("LEFT", birthdayEB, "RIGHT", 8, 0)
    birthdayHint:SetText("|cff888888Exemplo: 15/07|r")

    -- 4. CAMPO: NOTA INTERNA
    local customNoteLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    customNoteLabel:SetPoint("TOPLEFT", birthdayEB, "BOTTOMLEFT", 0, -10)
    customNoteLabel:SetText("|cffffd200Nota Interna:|r |cffaaaaaa(Visível apenas na gestão do AddOn)|r")

    local noteContainer = CreateFrame("Frame", nil, modal, template)
    noteContainer:SetPoint("TOPLEFT", customNoteLabel, "BOTTOMLEFT", 0, -4)
    noteContainer:SetSize(420, 60)
    if noteContainer.SetBackdrop then
        noteContainer:SetBackdrop(SUB_CONTAINER_BACKDROP)
        noteContainer:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        noteContainer:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local customNoteEB = CreateFrame("EditBox", nil, noteContainer)
    customNoteEB:SetPoint("TOPLEFT", noteContainer, "TOPLEFT", 6, -4)
    customNoteEB:SetPoint("BOTTOMRIGHT", noteContainer, "BOTTOMRIGHT", -6, 4)
    customNoteEB:SetFontObject("GameFontHighlightSmall")
    customNoteEB:SetMultiLine(true)
    customNoteEB:SetAutoFocus(false)
    modal.customNoteEB = customNoteEB

    -- Navegação fluida por TAB entre campos
    dateJoinEB:SetScript("OnTabPressed", function() recruiterEB:SetFocus() end)
    recruiterEB:SetScript("OnTabPressed", function() birthdayEB:SetFocus() end)
    birthdayEB:SetScript("OnTabPressed", function() customNoteEB:SetFocus() end)
    customNoteEB:SetScript("OnTabPressed", function() dateJoinEB:SetFocus() end)

    dateJoinEB:SetScript("OnEscapePressed", function() modal:Hide() end)
    recruiterEB:SetScript("OnEscapePressed", function() modal:Hide() end)
    birthdayEB:SetScript("OnEscapePressed", function() modal:Hide() end)
    customNoteEB:SetScript("OnEscapePressed", function() modal:Hide() end)

    -- Divisória acima dos botões de ação
    local footerSep = modal:CreateTexture(nil, "ARTWORK")
    footerSep:SetPoint("TOPLEFT", noteContainer, "BOTTOMLEFT", 0, -12)
    footerSep:SetPoint("RIGHT", modal, "RIGHT", -16, 0)
    footerSep:SetHeight(1)
    footerSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- Botão Salvar Alterações
    local saveBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    saveBtn:SetSize(140, 24)
    saveBtn:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -16, 14)
    saveBtn:SetText("Salvar Alterações")
    saveBtn:SetScript("OnClick", function()
        self:saveModalChanges()
    end)
    modal.saveBtn = saveBtn

    -- Botão Cancelar
    local cancelBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    cancelBtn:SetSize(90, 24)
    cancelBtn:SetPoint("RIGHT", saveBtn, "LEFT", -8, 0)
    cancelBtn:SetText("Cancelar")
    cancelBtn:SetScript("OnClick", function()
        modal:Hide()
    end)

    self._editModal = modal
end

--- Abre a modal de edição para um determinado membro e foca no campo especificado.
---@param member Member
---@param fieldToFocus string|nil @"dateJoin"|"recruiter"|"birthday"|"customNote"
function AuditView:openEditModal(member, fieldToFocus)
    if not member then return end
    self:createEditModal()
    local modal = self._editModal
    self._editingMember = member

    local coloredName = self:formatColoredName(member:getName(), member:getGuid(), member:getClass())
    local isMain = member:isMain()
    local mainTag = isMain and "|cffffd200[MAIN]|r" or "|cff00e5ff[ALT]|r"
    modal.memberHeader:SetText(string.format("%s %s", mainTag, coloredName))

    local lvl = member:getLevel() or 1
    local race = member:getRace() ~= "" and member:getRace() or "Desconhecido"
    local classDisp = member:getClassDisplayName() ~= "" and member:getClassDisplayName() or member:getClass()
    local rank = member:getRankName() ~= "" and member:getRankName() or "Membro"
    modal.memberSubHeader:SetText(string.format("Nível %d %s %s • Cargo: |cffffd200%s|r", lvl, race, classDisp, rank))

    modal.dateJoinEB:SetText(member:getDateJoin() or "")
    modal.recruiterEB:SetText(member:getRecruiter() or "")
    modal.birthdayEB:SetText(member:getBirthday() or "")
    modal.customNoteEB:SetText(member:getCustomNote() or "")

    modal:Show()

    -- Foca automaticamente no campo que foi clicado
    if fieldToFocus == "dateJoin" then
        modal.dateJoinEB:SetFocus()
        modal.dateJoinEB:HighlightText()
    elseif fieldToFocus == "recruiter" then
        modal.recruiterEB:SetFocus()
        modal.recruiterEB:HighlightText()
    elseif fieldToFocus == "birthday" then
        modal.birthdayEB:SetFocus()
        modal.birthdayEB:HighlightText()
    elseif fieldToFocus == "customNote" then
        modal.customNoteEB:SetFocus()
        modal.customNoteEB:HighlightText()
    end
end

--- Salva as alterações da modal chamando o callback do controller ou persistindo diretamente.
function AuditView:saveModalChanges()
    local member = self._editingMember
    local modal = self._editModal
    if not member or not modal then return end

    local newDateJoin = (modal.dateJoinEB:GetText() or ""):match("^%s*(.-)%s*$") or ""
    local newRecruiter = (modal.recruiterEB:GetText() or ""):match("^%s*(.-)%s*$") or ""
    local newBirthday = (modal.birthdayEB:GetText() or ""):match("^%s*(.-)%s*$") or ""
    local newCustomNote = (modal.customNoteEB:GetText() or ""):match("^%s*(.-)%s*$") or ""

    local fields = {
        dateJoin = newDateJoin,
        recruiter = newRecruiter,
        birthday = newBirthday,
        customNote = newCustomNote,
    }

    if self._onSaveCallback then
        self._onSaveCallback(member, fields)
    else
        member:setDateJoin(newDateJoin)
        local oldRec = member:getRecruiter() or ""
        member:setRecruiter(newRecruiter)
        member:setBirthday(newBirthday)
        member:setCustomNote(newCustomNote)

        if oldRec ~= newRecruiter and _G.GM and _G.GM.logService and _G.GM.logService.updateRecruiterForMember then
            _G.GM.logService:updateRecruiterForMember(member:getName(), newRecruiter)
        end

        if _G.GM and _G.GM.memberService and _G.GM.memberService.saveMember then
            _G.GM.memberService:saveMember(member)
        end

        self:rebuildFlatRows()
        self:applyFilters()
    end

    print(string.format("|cff00ff00[GuildManager]|r Informações de |cffffff00%s|r atualizadas com sucesso.", member:getName()))
    modal:Hide()
end

--- Atualiza as dimensões de rolagem horizontal com base no tamanho atual da tabela.
function AuditView:updateScrollDimensions()
    local insetWidth = self._tableInset and self._tableInset:GetWidth() or 932
    if insetWidth <= 0 then insetWidth = 932 end
    local visibleWidth = math.max(100, insetWidth - 24)
    self._visibleWidth = visibleWidth
    self._maxHOffset = math.max(0, TOTAL_TABLE_WIDTH - visibleWidth)

    if self._headerScrollFrame then
        self._headerScrollFrame:SetWidth(visibleWidth)
    end
    if self._rowsScrollFrame then
        self._rowsScrollFrame:SetWidth(visibleWidth)
    end

    if self._hSlider then
        self._hSlider:SetMinMaxValues(0, self._maxHOffset)
        if self._hOffset > self._maxHOffset then
            self:setHorizontalOffset(self._maxHOffset)
        end
    end

    if self._hScrollContainer then
        if self._maxHOffset <= 0 then
            self._hScrollContainer:Hide()
        else
            self._hScrollContainer:Show()
        end
    end
end

--- Define a posição do scroll horizontal da tabela (de 0 até maxHOffset).
---@param offset number
---@param skipSlider boolean|nil
function AuditView:setHorizontalOffset(offset, skipSlider)
    local maxH = self._maxHOffset or 0
    if offset < 0 then offset = 0 end
    if offset > maxH then offset = maxH end
    self._hOffset = offset

    if self._headerScrollFrame then
        self._headerScrollFrame:SetHorizontalScroll(offset)
    end
    if self._rowsScrollFrame then
        self._rowsScrollFrame:SetHorizontalScroll(offset)
    end

    if not skipSlider and self._hSlider then
        self._hSlider:SetValue(offset)
    end
end

--- Rola a tabela horizontalmente por um delta em pixels.
---@param delta number
function AuditView:scrollH(delta)
    local cur = self._hOffset or 0
    self:setHorizontalOffset(cur + delta)
end

--- Manipula a rolagem da roda do mouse (Shift = horizontal, normal = vertical).
---@param delta number
function AuditView:onTableMouseWheel(delta)
    if IsShiftKeyDown and IsShiftKeyDown() then
        self:scrollH(-delta * 80)
    else
        self:scroll(delta)
    end
end

--- Atualiza a aparência visual dos botões de filtro.
function AuditView:updateFilterButtonsVisual()
    for tabId, btn in pairs(self._filterButtons) do
        local isActive = (tabId == self._activeFilter)
        local bg = isActive and PALETTE.ACTIVE_TAB_BG or PALETTE.INACTIVE_TAB_BG
        local border = isActive and PALETTE.ACTIVE_TAB_BORDER or PALETTE.INACTIVE_TAB_BORDER

        if btn.SetBackdrop then
            btn:SetBackdrop(SUB_CONTAINER_BACKDROP)
            btn:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
            btn:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
        end

        if btn.text then
            if isActive then
                btn.text:SetTextColor(1.0, 0.85, 0.20)
            else
                btn.text:SetTextColor(0.80, 0.80, 0.80)
            end
        end
    end
end

--- Retorna o código hexadecimal da cor da classe da Blizzard.
---@param classToken string
---@return string|nil
local function getClassColorHex(classToken)
    if not classToken or classToken == "" then return nil end
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if not color then return nil end
    if color.colorStr then
        return "|c" .. color.colorStr
    end
    local r = math.floor((color.r or 1) * 255)
    local g = math.floor((color.g or 1) * 255)
    local b = math.floor((color.b or 1) * 255)
    return string.format("|cff%02x%02x%02x", r, g, b)
end

--- Formata o nome de um personagem com a cor oficial de classe.
---@param name string
---@param guid string|nil
---@param fallbackClass string|nil
---@return string
function AuditView:formatColoredName(name, guid, fallbackClass)
    if not name or name == "" then return "" end

    local clean = name:match("^[^-]+") or name
    clean = clean:match("^%s*(.-)%s*$") or clean

    if fallbackClass and fallbackClass ~= "" then
        local hex = getClassColorHex(fallbackClass)
        if hex then return hex .. clean .. "|r" end
    end

    if guid and guid ~= "" and GetPlayerInfoByGUID then
        local _, classToken = GetPlayerInfoByGUID(guid)
        if classToken and classToken ~= "" then
            local hex = getClassColorHex(classToken)
            if hex then return hex .. clean .. "|r" end
        end
    end

    if _G.GM and _G.GM.memberService then
        local member = _G.GM.memberService:getMember(clean)
        if member and member.getClass then
            local hex = getClassColorHex(member:getClass())
            if hex then return hex .. clean .. "|r" end
        end
    end

    return "|cffffffff" .. clean .. "|r"
end

--- Define a lista de membros ativos na guilda e reconstrói a árvore de Mains e Alts.
---@param members Member[]
function AuditView:setMembers(members)
    self._members = members or {}
    self:rebuildFlatRows()
    self:applyFilters()
end

--- Reconstrói a estrutura hierárquica plana de linhas (Mains seguidos de seus respectivos Alts).
function AuditView:rebuildFlatRows()
    local guildMap = {}
    for _, m in ipairs(self._members) do
        guildMap[(m:getName() or ""):lower()] = m
    end

    local familyHandled = {}
    local mainGroups = {}

    for _, m in ipairs(self._members) do
        local mNameLower = (m:getName() or ""):lower()
        if not familyHandled[mNameLower] then
            local family = {}
            if _G.GM and _G.GM.memberService then
                family = _G.GM.memberService:getAltFamily(m)
            else
                family = { m }
            end

            -- Filtra os membros da família que estão atualmente na guilda
            local guildFamily = {}
            for _, famMember in ipairs(family) do
                local famLower = (famMember:getName() or ""):lower()
                local activeMember = guildMap[famLower]
                if activeMember then
                    table.insert(guildFamily, activeMember)
                    familyHandled[famLower] = true
                end
            end

            if #guildFamily > 0 then
                local mainMember = nil
                local altMembers = {}

                for _, famMember in ipairs(guildFamily) do
                    if famMember:isMain() then
                        if not mainMember then
                            mainMember = famMember
                        else
                            table.insert(altMembers, famMember)
                        end
                    else
                        table.insert(altMembers, famMember)
                    end
                end

                -- Se nenhum foi marcado como isMain, elege o de maior nível ou primeiro da lista
                if not mainMember then
                    table.sort(altMembers, function(a, b)
                        return (a:getLevel() or 0) > (b:getLevel() or 0)
                    end)
                    mainMember = table.remove(altMembers, 1)
                end

                -- Ordena os alts do grupo por nível decrescente e nome
                table.sort(altMembers, function(a, b)
                    local lvlA = a:getLevel() or 0
                    local lvlB = b:getLevel() or 0
                    if lvlA ~= lvlB then return lvlA > lvlB end
                    return (a:getName() or "") < (b:getName() or "")
                end)

                table.insert(mainGroups, {
                    main = mainMember,
                    alts = altMembers,
                })
            end
        end
    end

    -- Ordena os grupos principais por Rank na guilda (Guild Master -> Oficiais -> Membros) e depois por Nome
    table.sort(mainGroups, function(a, b)
        local rankA = a.main:getRankIndex() or 99
        local rankB = b.main:getRankIndex() or 99
        if rankA ~= rankB then
            return rankA < rankB
        end
        return (a.main:getName() or ""):lower() < (b.main:getName() or ""):lower()
    end)

    -- Achata os grupos em uma lista sequencial com indicação clara de Main e Subnível (Alts)
    self._flatRows = {}
    local totalMains = 0
    local totalAlts = 0

    for _, group in ipairs(mainGroups) do
        totalMains = totalMains + 1
        local mainName = group.main:getName()
        local isCollapsed = (self._collapsedMains[mainName] == true)
        local altNames = {}
        for _, alt in ipairs(group.alts) do
            table.insert(altNames, alt:getName())
        end

        table.insert(self._flatRows, {
            member = group.main,
            isMain = true,
            isAlt = false,
            mainName = mainName,
            hasAlts = (#group.alts > 0),
            isCollapsed = isCollapsed,
            altCount = #group.alts,
            altList = altNames,
        })

        if not isCollapsed then
            for idx, alt in ipairs(group.alts) do
                totalAlts = totalAlts + 1
                table.insert(self._flatRows, {
                    member = alt,
                    isMain = false,
                    isAlt = true,
                    mainName = mainName,
                    isLastAlt = (idx == #group.alts),
                    altList = altNames,
                })
            end
        else
            totalAlts = totalAlts + #group.alts
        end
    end

    self._totalMainsCount = totalMains
    self._totalAltsCount = totalAlts
end

--- Aplica filtros de texto de busca e abas rápidas à lista de auditoria.
function AuditView:applyFilters()
    local search = (self._filterText or ""):lower():match("^%s*(.-)%s*$")
    local filter = self._activeFilter or "ALL"

    self._filteredRows = {}

    for _, rowData in ipairs(self._flatRows) do
        local m = rowData.member
        local matchFilter = true

        if filter == "MAINS" then
            matchFilter = rowData.isMain
        elseif filter == "WITH_ALTS" then
            matchFilter = (rowData.isMain and rowData.hasAlts) or rowData.isAlt
        elseif filter == "ONLINE" then
            matchFilter = m:isOnline()
        elseif filter == "NO_RECRUITER" then
            local rec = m:getRecruiter() or ""
            matchFilter = (rec == "" or rec == "Desconhecido")
        elseif filter == "NO_OFFICER_NOTE" then
            local on = m:getOfficerNote() or ""
            matchFilter = (on == "")
        elseif filter == "NO_CUSTOM_NOTE" then
            local cn = m:getCustomNote() or ""
            matchFilter = (cn == "")
        end

        if matchFilter and search ~= "" then
            local name = (m:getName() or ""):lower()
            local rank = (m:getRankName() or ""):lower()
            local onlineStatus = m:isOnline() and "online" or (m:getLastOnline() or "offline"):lower()
            local pubNote = (m:getPublicNote() or ""):lower()
            local offNote = (m:getOfficerNote() or ""):lower()
            local custNote = (m:getCustomNote() or ""):lower()
            local rec = (m:getRecruiter() or ""):lower()
            local dateJoin = (m:getDateJoin() or ""):lower()
            local bday = (m:getBirthday() or ""):lower()

            if not (name:find(search, 1, true) or rank:find(search, 1, true) or
                    onlineStatus:find(search, 1, true) or
                    pubNote:find(search, 1, true) or offNote:find(search, 1, true) or
                    custNote:find(search, 1, true) or rec:find(search, 1, true) or
                    dateJoin:find(search, 1, true) or bday:find(search, 1, true)) then
                matchFilter = false
            end
        end

        if matchFilter then
            table.insert(self._filteredRows, rowData)
        end
    end

    local total = #self._filteredRows
    local maxOffset = math.max(0, total - self._numVisibleRows)

    if self._offset > maxOffset then
        self._offset = maxOffset
    end

    if self._scrollBar then
        self._scrollBar:SetMinMaxValues(0, maxOffset)
        self._scrollBar:SetValue(self._offset)
        if maxOffset == 0 then
            self._scrollBar:Hide()
        else
            self._scrollBar:Show()
        end
    end

    if self._footerText then
        self._footerText:SetText(string.format(
            "|cffaaaaaaTotal na guilda: %d membros (%d Mains, %d Alts) • Exibindo: %d linha(s)|r",
            #self._members, self._totalMainsCount or 0, self._totalAltsCount or 0, total
        ))
    end

    self:updateScrollDimensions()
    self:renderRows()
end

--- Renderiza as linhas visíveis na tabela com suporte avançado a subnível, identação e células interativas.
function AuditView:renderRows()
    local total = #self._filteredRows

    if total == 0 then
        if self._emptyNotice then
            self._emptyNotice:Show()
        end
        for _, row in ipairs(self._rows) do
            row:Hide()
        end
        return
    else
        if self._emptyNotice then
            self._emptyNotice:Hide()
        end
    end

    for i = 1, self._numVisibleRows do
        local dataIndex = self._offset + i
        local row = self._rows[i]
        local rowData = self._filteredRows[dataIndex]

        if rowData and row then
            row.rowData = rowData
            local m = rowData.member

            -- Cor de fundo da linha e indicador lateral dourado para Mains
            if rowData.isMain then
                row.bg:SetColorTexture(PALETTE.ROW_MAIN_BG[1], PALETTE.ROW_MAIN_BG[2], PALETTE.ROW_MAIN_BG[3], PALETTE.ROW_MAIN_BG[4])
                row.mainAccent:Show()
            else
                row.bg:SetColorTexture(PALETTE.ROW_ALT_BG[1], PALETTE.ROW_ALT_BG[2], PALETTE.ROW_ALT_BG[3], PALETTE.ROW_ALT_BG[4])
                row.mainAccent:Hide()
            end

            -- Coluna 1: Personagem (Diferenciação clara entre Mains e Alts)
            local coloredName = self:formatColoredName(m:getName(), m:getGuid(), m:getClass())
            if rowData.isMain then
                if rowData.hasAlts then
                    row.toggleBtn:Show()
                    row.toggleBtn.text:SetText(rowData.isCollapsed and "|cffffd200+|r" or "|cffffd200-|r")
                    row.nameTxt:SetPoint("LEFT", row, "LEFT", 22, 0)

                    if rowData.isCollapsed then
                        row.nameTxt:SetText(string.format("|cffffd200[MAIN]|r %s |cffffaa00[+%d alts]|r", coloredName, rowData.altCount))
                    else
                        local altWord = (rowData.altCount == 1) and "alt" or "alts"
                        row.nameTxt:SetText(string.format("|cffffd200[MAIN]|r %s |cffaaaaaa(%d %s)|r", coloredName, rowData.altCount, altWord))
                    end
                else
                    row.toggleBtn:Hide()
                    row.nameTxt:SetPoint("LEFT", row, "LEFT", 12, 0)
                    row.nameTxt:SetText(string.format("|cffffd200[MAIN]|r %s", coloredName))
                end
            else
                row.toggleBtn:Hide()
                local branch = rowData.isLastAlt and "└──" or "├──"
                row.nameTxt:SetPoint("LEFT", row, "LEFT", 24, 0)
                row.nameTxt:SetText(string.format("|cff888888%s|r |cff00e5ff[ALT]|r %s", branch, coloredName))
            end

            -- Coluna 2: Nível (Centralizado e nítido)
            local lvl = m:getLevel() or 1
            row.levelTxt:SetText(string.format("|cffffffff%d|r", lvl))

            -- Coluna 3: Cargo (Rank da guilda)
            local rank = m:getRankName()
            if rank and rank ~= "" then
                if m:getRankIndex() == 0 then
                    row.rankTxt:SetText("|cffffd200" .. rank .. "|r")
                elseif m:getRankIndex() <= 2 then
                    row.rankTxt:SetText("|cff40bfff" .. rank .. "|r")
                else
                    row.rankTxt:SetText("|cffdddddd" .. rank .. "|r")
                end
            else
                row.rankTxt:SetText("|cff555555-|r")
            end

            -- Coluna 4: ONLINE (Status Online ou Tempo desde Última Vez Online)
            if m:isOnline() then
                local status = m:getStatus() or 0
                if status == 1 then
                    row.onlineTxt:SetText("|cffffaa00AFK|r")
                elseif status == 2 then
                    row.onlineTxt:SetText("|cffff4444DND|r")
                else
                    row.onlineTxt:SetText("|cff00ff00Online|r")
                end
            else
                local lastOnline = m:getLastOnline()
                if lastOnline and lastOnline ~= "" then
                    row.onlineTxt:SetText("|cff888888" .. lastOnline .. "|r")
                else
                    row.onlineTxt:SetText("|cff666666Offline|r")
                end
            end

            -- Coluna 5: Nota Pública (Blizzard - Somente Leitura)
            local pNote = m:getPublicNote()
            if pNote and pNote ~= "" then
                row.publicNoteTxt:SetText("|cffffffff" .. pNote .. "|r")
            else
                row.publicNoteTxt:SetText("|cff555555-|r")
            end

            -- Coluna 6: Nota de Oficial (Blizzard - Somente Leitura)
            local oNote = m:getOfficerNote()
            if oNote and oNote ~= "" then
                row.officerNoteTxt:SetText("|cff80d0ff" .. oNote .. "|r")
            else
                row.officerNoteTxt:SetText("|cff555555-|r")
            end

            -- Coluna 7: Data de Entrada (Editável ao clicar)
            local dJoin = m:getDateJoin()
            if dJoin and dJoin ~= "" then
                row.dateJoinTxt:SetText("|cffe0e0e0" .. dJoin .. "|r")
            else
                row.dateJoinTxt:SetText("|cff777777(definir)|r")
            end

            -- Coluna 8: Recrutador (Editável ao clicar)
            local rec = m:getRecruiter()
            if rec and rec ~= "" and rec ~= "Desconhecido" then
                row.recruiterTxt:SetText(self:formatColoredName(rec))
            else
                row.recruiterTxt:SetText("|cff777777(definir)|r")
            end

            -- Coluna 9: Aniversário (Editável ao clicar)
            local bday = m:getBirthday()
            if bday and bday ~= "" then
                row.birthdayTxt:SetText("|cffffd200" .. bday .. "|r")
            else
                row.birthdayTxt:SetText("|cff777777(definir)|r")
            end

            -- Coluna 10: Nota Interna (Editável ao clicar)
            local cNote = m:getCustomNote()
            if cNote and cNote ~= "" then
                row.customNoteTxt:SetText("|cffffea88" .. cNote .. "|r")
            else
                row.customNoteTxt:SetText("|cff777777(adicionar)|r")
            end

            row:Show()
        elseif row then
            row.rowData = nil
            row:Hide()
        end
    end
end

--- Controla o scroll vertical da tabela via roda do mouse ou botões de seta.
---@param delta number
function AuditView:scroll(delta)
    local total = #self._filteredRows
    local maxOffset = math.max(0, total - self._numVisibleRows)
    local newOffset = self._offset - delta

    if newOffset < 0 then
        newOffset = 0
    elseif newOffset > maxOffset then
        newOffset = maxOffset
    end

    if newOffset ~= self._offset then
        self._offset = newOffset
        if self._scrollBar then
            self._scrollBar:SetValue(newOffset)
        end
        self:renderRows()
    end
end

--- Exibe a janela de auditoria.
function AuditView:show()
    self:createUI()
    if self._frame then
        self._frame:Show()
    end
end

--- Oculta a janela de auditoria.
function AuditView:hide()
    if self._frame then
        self._frame:Hide()
    end
end

--- Alterna a visibilidade da janela de auditoria.
function AuditView:toggle()
    self:createUI()
    if self._frame:IsShown() then
        self:hide()
    else
        self:show()
    end
end

--- Verifica se a janela de auditoria está aberta.
---@return boolean
function AuditView:isShown()
    return self._frame and self._frame:IsShown() or false
end

-- Exportação/Alias de compatibilidade
auditView = AuditView
