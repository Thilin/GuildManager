---@class LogView
---@field private _frame table
---@field private _logs Log[]
---@field private _filteredLogs Log[]
---@field private _offset number
---@field private _rows table[]
---@field private _filterText string
---@field private _activeEventFilter string
LogView = {}
LogView.__index = LogView

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

--- Paleta de cores oficial WoW Forever (tons bronze/dourado e metais escuros)
local PALETTE = {
    FRAME_BG = { 0.055, 0.035, 0.015, 1.0 },
    FRAME_BORDER = { 1.0, 0.68, 0.22, 1.0 },
    INSET_BG = { 0.035, 0.022, 0.010, 0.75 },
    INSET_BORDER = { 0.71, 0.49, 0.16, 0.95 },
    SEPARATOR = { 0.58, 0.37, 0.11, 0.90 },
    SUB_BOX_BG = { 0.022, 0.014, 0.006, 0.75 },
    SUB_BOX_BORDER = { 0.62, 0.41, 0.13, 0.90 },
    FOCUS_BG = { 0.065, 0.045, 0.020, 0.95 },
    FOCUS_BORDER = { 0.85, 0.58, 0.20, 1.0 },
    HIGHLIGHT_TINT = { 0.71, 0.49, 0.16, 0.14 },
    HEADER_ROW_BG = { 0.10, 0.065, 0.025, 0.85 },
    ROW_EVEN_BG = { 0.035, 0.022, 0.010, 0.40 },
    ROW_ODD_BG = { 0.060, 0.040, 0.018, 0.40 },
    ACTIVE_TAB_BG = { 0.18, 0.11, 0.04, 0.95 },
    ACTIVE_TAB_BORDER = { 0.95, 0.70, 0.25, 1.0 },
    INACTIVE_TAB_BG = { 0.045, 0.030, 0.012, 0.80 },
    INACTIVE_TAB_BORDER = { 0.50, 0.33, 0.12, 0.85 },
}

local EVENT_COLORS = {
    JOINED = { r = 0.25, g = 1.00, b = 0.25, hex = "|cff40ff40" },
    LEFT = { r = 1.00, g = 0.60, b = 0.15, hex = "|cffff9926" },
    KICK = { r = 1.00, g = 0.25, b = 0.25, hex = "|cffff4040" },
    LEVELED = { r = 1.00, g = 0.85, b = 0.10, hex = "|cffffd91a" },
    OFFICERNOTE = { r = 0.25, g = 0.75, b = 1.00, hex = "|cff40bfff" },
    PUBLICNOTE = { r = 0.45, g = 0.90, b = 1.00, hex = "|cff73e6ff" },
    NAMECHANGE = { r = 0.85, g = 0.55, b = 1.00, hex = "|cffd98cff" },
    INACTIVERETURN = { r = 0.15, g = 1.00, b = 0.75, hex = "|cff26ffbf" },
}

--- Construtor da View de Logs.
---@return LogView
function LogView:new()
    local instance = setmetatable({}, self)

    instance._frame = nil
    instance._logs = {}
    instance._filteredLogs = {}
    instance._offset = 0
    instance._rows = {}
    instance._filterText = ""
    instance._activeEventFilter = "ALL"
    instance._numVisibleRows = 14
    instance._rowHeight = 22
    instance._onRefreshCallback = nil

    instance:createUI()

    return instance
end

--- Define o callback disparado ao solicitar atualização ou abertura da tela.
---@param callback function
function LogView:setOnRefreshCallback(callback)
    self._onRefreshCallback = callback
end

--- Cria e estiliza os componentes visuais da janela de logs no padrão WoW Forever.
function LogView:createUI()
    if self._frame then
        return
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "GuildManagerLogFrame", UIParent, template)
    self._frame = frame

    frame:SetSize(720, 480)
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
        table.insert(UISpecialFrames, "GuildManagerLogFrame")
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
    titleText:SetText("|cffffd200REGISTRO DE ATIVIDADES DA GUILDA|r")
    self._titleText = titleText

    -- Subtítulo informativo
    local subtitleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitleText:SetPoint("LEFT", titleText, "RIGHT", 12, 0)
    subtitleText:SetText("|cffaaaaaa(Logs do AddOn)|r")

    -- Divisória abaixo do cabeçalho
    local headerSep = frame:CreateTexture(nil, "ARTWORK")
    headerSep:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -44)
    headerSep:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    headerSep:SetHeight(1)
    headerSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- =========================================================================
    -- BARRA DE FILTROS E BUSCA
    -- =========================================================================
    local searchEB = CreateFrame("EditBox", nil, frame, template)
    searchEB:SetPoint("TOPLEFT", headerSep, "BOTTOMLEFT", 0, -8)
    searchEB:SetSize(230, 22)
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
            box:SetBackdropBorderColor(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], PALETTE.FOCUS_BORDER[4])
        end
        if box.SetBackdropColor then
            box:SetBackdropColor(PALETTE.FOCUS_BG[1], PALETTE.FOCUS_BG[2], PALETTE.FOCUS_BG[3], PALETTE.FOCUS_BG[4])
        end
    end)
    searchEB:SetScript("OnEditFocusLost", function(box)
        if box.SetBackdropBorderColor then
            box:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
        end
        if box.SetBackdropColor then
            box:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        end
    end)

    local searchHint = searchEB:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchHint:SetPoint("LEFT", searchEB, "LEFT", 8, 0)
    searchHint:SetText("|cff888888Buscar personagem, recrutador ou texto...|r")
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

    -- Botões de filtro rápido por tipo de evento
    local filterTabs = {
        { id = "ALL", label = "Todos" },
        { id = "JOINED", label = "Recrutamentos" },
        { id = "LEFT_KICK", label = "Saídas / Kicks" },
        { id = "NOTES", label = "Notas" },
        { id = "OTHER", label = "Outros" },
    }

    self._filterButtons = {}
    local prevTab = searchEB
    for _, tabData in ipairs(filterTabs) do
        local tabBtn = CreateFrame("Button", nil, frame, template)
        tabBtn:SetHeight(22)
        tabBtn:SetPoint("LEFT", prevTab, "RIGHT", 6, 0)
        tabBtn.tabId = tabData.id

        local btnText = tabBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btnText:SetPoint("CENTER", tabBtn, "CENTER", 0, 0)
        btnText:SetText(tabData.label)
        tabBtn.text = btnText

        local textWidth = btnText:GetStringWidth() or 40
        tabBtn:SetWidth(textWidth + 16)

        tabBtn:SetScript("OnClick", function()
            self._activeEventFilter = tabData.id
            self:updateFilterButtonsVisual()
            self:applyFilters()
        end)

        self._filterButtons[tabData.id] = tabBtn
        prevTab = tabBtn
    end

    -- =========================================================================
    -- TABELA PRINCIPAL DE LOGS (INSET)
    -- =========================================================================
    local tableInset = CreateFrame("Frame", nil, frame, template)
    tableInset:SetPoint("TOPLEFT", searchEB, "BOTTOMLEFT", 0, -8)
    tableInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 38)
    if tableInset.SetBackdrop then
        tableInset:SetBackdrop(CONTAINER_BACKDROP)
        tableInset:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        tableInset:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end
    self._tableInset = tableInset

    -- Rolagem com a roda do mouse
    tableInset:EnableMouseWheel(true)
    tableInset:SetScript("OnMouseWheel", function(_, delta)
        self:scroll(delta)
    end)

    -- Barra de cabeçalho da tabela
    local headerRow = CreateFrame("Frame", nil, tableInset, template)
    headerRow:SetPoint("TOPLEFT", tableInset, "TOPLEFT", 4, -4)
    headerRow:SetPoint("TOPRIGHT", tableInset, "TOPRIGHT", -22, -4)
    headerRow:SetHeight(22)
    if headerRow.SetBackdrop then
        headerRow:SetBackdrop(SUB_CONTAINER_BACKDROP)
        headerRow:SetBackdropColor(PALETTE.HEADER_ROW_BG[1], PALETTE.HEADER_ROW_BG[2], PALETTE.HEADER_ROW_BG[3], PALETTE.HEADER_ROW_BG[4])
        headerRow:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local col1 = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    col1:SetPoint("LEFT", headerRow, "LEFT", 8, 0)
    col1:SetText("|cffffd200DATA / HORA|r")

    local col2 = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    col2:SetPoint("LEFT", headerRow, "LEFT", 136, 0)
    col2:SetText("|cffffd200EVENTO|r")

    local col3 = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    col3:SetPoint("LEFT", headerRow, "LEFT", 226, 0)
    col3:SetText("|cffffd200PERSONAGEM|r")

    local col4 = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    col4:SetPoint("LEFT", headerRow, "LEFT", 346, 0)
    col4:SetText("|cffffd200MENSAGEM / HISTÓRICO|r")

    -- Scrollbar lateral
    local scrollBar = CreateFrame("Slider", "GM_LogScrollBar", tableInset, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPRIGHT", tableInset, "TOPRIGHT", -4, -26)
    scrollBar:SetPoint("BOTTOMRIGHT", tableInset, "BOTTOMRIGHT", -4, 22)
    scrollBar:SetWidth(16)
    scrollBar:SetScript("OnValueChanged", function(_, val)
        self._offset = math.floor(val)
        self:renderRows()
    end)
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValueStep(1)

    local upBtn = _G["GM_LogScrollBarScrollUpButton"] or (scrollBar and scrollBar.ScrollUpButton)
    if upBtn then
        upBtn:SetScript("OnClick", function()
            self:scroll(1)
        end)
    end
    local downBtn = _G["GM_LogScrollBarScrollDownButton"] or (scrollBar and scrollBar.ScrollDownButton)
    if downBtn then
        downBtn:SetScript("OnClick", function()
            self:scroll(-1)
        end)
    end
    self._scrollBar = scrollBar

    -- Mensagem de vazio (Nenhum log encontrado)
    local emptyNotice = tableInset:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyNotice:SetPoint("CENTER", tableInset, "CENTER", 0, -10)
    emptyNotice:SetText("Nenhum registro de log encontrado.")
    emptyNotice:Hide()
    self._emptyNotice = emptyNotice

    -- Criação das linhas reutilizáveis
    self._rows = {}
    local numRows = self._numVisibleRows
    local rowHeight = self._rowHeight

    for i = 1, numRows do
        local row = CreateFrame("Button", nil, tableInset, template)
        row:SetHeight(rowHeight)
        row:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -((i - 1) * rowHeight))
        row:SetPoint("RIGHT", headerRow, "RIGHT", 0, 0)

        -- Fundo alternado
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        local bgColor = (i % 2 == 0) and PALETTE.ROW_EVEN_BG or PALETTE.ROW_ODD_BG
        bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
        row.bg = bg

        -- Destaque de hover
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(row)
        hl:SetColorTexture(PALETTE.HIGHLIGHT_TINT[1], PALETTE.HIGHLIGHT_TINT[2], PALETTE.HIGHLIGHT_TINT[3], PALETTE.HIGHLIGHT_TINT[4])
        row:SetHighlightTexture(hl)

        -- Texto: Data
        local dateTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dateTxt:SetPoint("LEFT", row, "LEFT", 8, 0)
        dateTxt:SetWidth(122)
        dateTxt:SetJustifyH("LEFT")
        row.dateTxt = dateTxt

        -- Texto: Evento
        local eventTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        eventTxt:SetPoint("LEFT", row, "LEFT", 136, 0)
        eventTxt:SetWidth(85)
        eventTxt:SetJustifyH("LEFT")
        row.eventTxt = eventTxt

        -- Texto: Personagem
        local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameTxt:SetPoint("LEFT", row, "LEFT", 226, 0)
        nameTxt:SetWidth(115)
        nameTxt:SetJustifyH("LEFT")
        row.nameTxt = nameTxt

        -- Texto: Mensagem
        local msgTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        msgTxt:SetPoint("LEFT", row, "LEFT", 346, 0)
        msgTxt:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        msgTxt:SetJustifyH("LEFT")
        msgTxt:SetWordWrap(false)
        row.msgTxt = msgTxt

        -- Rolagem do mouse na linha
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta)
            self:scroll(delta)
        end)

        -- Tooltip com detalhes completos ao passar o mouse
        row:SetScript("OnEnter", function(r)
            if r.logData then
                GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
                local log = r.logData
                local evt = log:getEvent()
                local colorInfo = EVENT_COLORS[evt] or { hex = "|cffffffff" }

                local coloredName = self:formatColoredName(log:getName(), log:getGuid(), log:getClass())
                GameTooltip:AddLine(string.format("%s[%s]|r %s", colorInfo.hex, evt, coloredName), 1, 1, 1)
                GameTooltip:AddLine("Data: |cffffffff" .. (log:getDate() ~= "" and log:getDate() or "N/A") .. "|r", 0.9, 0.8, 0.5)

                local recruiter = log:getRecruiter()
                if recruiter and recruiter ~= "" then
                    local coloredRecruiter = (recruiter ~= "Desconhecido") and self:formatColoredName(recruiter, nil, log:getRecruiterClass()) or "|cff888888Desconhecido|r"
                    GameTooltip:AddLine("Recrutado por: " .. coloredRecruiter, 0.9, 0.8, 0.5)
                end

                local guid = log:getGuid()
                if guid and guid ~= "" then
                    GameTooltip:AddLine("GUID: |cff888888" .. guid .. "|r", 0.7, 0.7, 0.7)
                end

                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(self:formatColoredMessage(log), 1, 1, 1, true)
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
    footerText:SetText("|cffaaaaaaTotal de registros: 0|r")
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
end

--- Atualiza a aparência dos botões de filtro de eventos.
function LogView:updateFilterButtonsVisual()
    for tabId, btn in pairs(self._filterButtons) do
        local isActive = (tabId == self._activeEventFilter)
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

--- Define a lista completa de logs e reexecuta os filtros.
---@param logs Log[]
function LogView:setLogs(logs)
    self._logs = logs or {}

    -- Ordena em ordem decrescente (mais recente primeiro)
    table.sort(self._logs, function(a, b)
        local tA = a:getTimestamp() or 0
        local tB = b:getTimestamp() or 0
        if tA ~= tB then
            return tA > tB
        end
        return (a:getId() or 0) > (b:getId() or 0)
    end)

    self:applyFilters()
end

--- Aplica os filtros ativos (texto de busca e tipo de evento).
function LogView:applyFilters()
    local search = (self._filterText or ""):lower():match("^%s*(.-)%s*$")
    local eventFilter = self._activeEventFilter or "ALL"

    self._filteredLogs = {}

    for _, log in ipairs(self._logs) do
        local matchEvent = true
        local evt = log:getEvent()

        if eventFilter == "JOINED" then
            matchEvent = (evt == LogEvent.JOINED)
        elseif eventFilter == "LEFT_KICK" then
            matchEvent = (evt == LogEvent.LEFT or evt == LogEvent.KICK)
        elseif eventFilter == "NOTES" then
            matchEvent = (evt == LogEvent.OFFICERNOTE or evt == LogEvent.PUBLICNOTE)
        elseif eventFilter == "OTHER" then
            matchEvent = (evt ~= LogEvent.JOINED and evt ~= LogEvent.LEFT and evt ~= LogEvent.KICK and evt ~= LogEvent.OFFICERNOTE and evt ~= LogEvent.PUBLICNOTE)
        end

        if matchEvent then
            local matchSearch = true
            if search ~= "" then
                local name = (log:getName() or ""):lower()
                local recruiter = (log:getRecruiter() or ""):lower()
                local msg = (log:getMessage() or ""):lower()
                local dateStr = (log:getDate() or ""):lower()
                local evtStr = (evt or ""):lower()

                if not (name:find(search, 1, true) or recruiter:find(search, 1, true) or msg:find(search, 1, true) or dateStr:find(search, 1, true) or evtStr:find(search, 1, true)) then
                    matchSearch = false
                end
            end

            if matchSearch then
                table.insert(self._filteredLogs, log)
            end
        end
    end

    local total = #self._filteredLogs
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
        self._footerText:SetText(string.format("|cffaaaaaaExibindo %d de %d registro(s)|r", total, #self._logs))
    end

    self:renderRows()
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

--- Formata o nome de um personagem com a cor oficial da sua classe.
--- Busca dinamicamente no Log, no MemberService, no GUID ou no Roster da Blizzard.
---@param name string
---@param guid string|nil
---@param fallbackClass string|nil
---@return string
function LogView:formatColoredName(name, guid, fallbackClass)
    if not name or name == "" then
        return ""
    end

    local clean = name:match("^[^-]+") or name
    clean = clean:match("^%s*(.-)%s*$") or clean

    -- 1. Verifica se a classe foi informada diretamente ou já armazenada
    if fallbackClass and fallbackClass ~= "" then
        local hex = getClassColorHex(fallbackClass)
        if hex then
            return hex .. clean .. "|r"
        end
    end

    -- 2. Tenta obter pelo GUID via API da Blizzard
    if guid and guid ~= "" and GetPlayerInfoByGUID then
        local _, classToken = GetPlayerInfoByGUID(guid)
        if classToken and classToken ~= "" then
            local hex = getClassColorHex(classToken)
            if hex then
                return hex .. clean .. "|r"
            end
        end
    end

    -- 3. Tenta obter pelo MemberService do GuildManager
    if _G.GM and _G.GM.memberService then
        local member = _G.GM.memberService:getMember(clean)
        if not member then
            local cleanLower = clean:lower()
            local all = _G.GM.memberService:getAllMembers()
            for _, m in ipairs(all) do
                local mName = m:getName() or ""
                local first = mName:match("^(%S+)") or mName
                if mName:lower() == cleanLower or first:lower() == cleanLower then
                    member = m
                    break
                end
            end
        end
        if member and member.getClass then
            local hex = getClassColorHex(member:getClass())
            if hex then
                return hex .. clean .. "|r"
            end
        end
    end

    -- 4. Tenta obter pelo Roster da guilda da Blizzard
    if GetNumGuildMembers and GetGuildRosterInfo then
        local num = GetNumGuildMembers() or 0
        local cleanLower = clean:lower()
        for i = 1, num do
            local gName, _, _, _, _, _, _, _, _, _, gClass = GetGuildRosterInfo(i)
            if gName then
                local gClean = gName:match("^[^-]+") or gName
                gClean = gClean:match("^%s*(.-)%s*$") or gClean
                local first = gClean:match("^(%S+)") or gClean
                if gClean:lower() == cleanLower or first:lower() == cleanLower then
                    local hex = getClassColorHex(gClass)
                    if hex then
                        return hex .. clean .. "|r"
                    end
                    break
                end
            end
        end
    end

    return "|cffffffff" .. clean .. "|r"
end

--- Formata a mensagem do log aplicando as cores de classe aos nomes dos personagens citados.
---@param log Log
---@return string
function LogView:formatColoredMessage(log)
    if not log then return "" end

    local evt = log:getEvent()
    local name = log:getName() or ""
    local recruiter = log:getRecruiter() or ""

    if evt == LogEvent.JOINED then
        local recruitColored = self:formatColoredName(name, log:getGuid(), log:getClass())
        local recruiterColored
        if recruiter ~= "" and recruiter ~= "Desconhecido" then
            recruiterColored = self:formatColoredName(recruiter, nil, log:getRecruiterClass())
        else
            recruiterColored = "|cff888888Desconhecido|r"
        end
        return string.format("%s foi RECRUTADO por %s", recruitColored, recruiterColored)
    end

    local rawMsg = log:getMessage() or ""
    if name ~= "" and rawMsg:find(name, 1, true) then
        local coloredName = self:formatColoredName(name, log:getGuid(), log:getClass())
        rawMsg = rawMsg:gsub(name, coloredName)
    end
    if recruiter ~= "" and recruiter ~= "Desconhecido" and rawMsg:find(recruiter, 1, true) then
        local coloredRecruiter = self:formatColoredName(recruiter, nil, log:getRecruiterClass())
        rawMsg = rawMsg:gsub(recruiter, coloredRecruiter)
    end

    return rawMsg
end

--- Renderiza as linhas visíveis da tabela de acordo com o offset atual.
function LogView:renderRows()
    local total = #self._filteredLogs

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
        local log = self._filteredLogs[dataIndex]

        if log and row then
            row.logData = log

            -- Data
            local d = log:getDate() or ""
            row.dateTxt:SetText("|cffcccccc" .. d .. "|r")

            -- Evento
            local evt = log:getEvent() or ""
            local colorInfo = EVENT_COLORS[evt] or { hex = "|cffffffff" }
            row.eventTxt:SetText(colorInfo.hex .. evt .. "|r")

            -- Personagem com a cor da respectiva classe
            local name = log:getName() or ""
            row.nameTxt:SetText(self:formatColoredName(name, log:getGuid(), log:getClass()))

            -- Mensagem formatada com as cores de classe dos membros
            row.msgTxt:SetText(self:formatColoredMessage(log))

            row:Show()
        elseif row then
            row.logData = nil
            row:Hide()
        end
    end
end

--- Controla o scroll da tabela via roda do mouse ou botões de seta.
---@param delta number
function LogView:scroll(delta)
    local total = #self._filteredLogs
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

--- Exibe a janela de logs.
function LogView:show()
    self:createUI()
    if self._frame then
        self._frame:Show()
    end
end

--- Oculta a janela de logs.
function LogView:hide()
    if self._frame then
        self._frame:Hide()
    end
end

--- Alterna a visibilidade da janela de logs.
function LogView:toggle()
    self:createUI()
    if self._frame:IsShown() then
        self:hide()
    else
        self:show()
    end
end

--- Verifica se a janela de logs está aberta.
---@return boolean
function LogView:isShown()
    return self._frame and self._frame:IsShown() or false
end
