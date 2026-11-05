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

local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })

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
    { id = "name",        title = "PERSONAGEM",       x = 0,    width = 195, align = "LEFT",   editable = false },
    { id = "level",       title = "NV",               x = 195,  width = 32,  align = "CENTER", editable = false },
    { id = "role",        title = "FUNÇÃO",           x = 227,  width = 68,  align = "CENTER", editable = true,  label = "Função / Role" },
    { id = "rank",        title = "CARGO",            x = 295,  width = 90,  align = "LEFT",   editable = false },
    { id = "online",      title = "ONLINE",           x = 385,  width = 90,  align = "LEFT",   editable = false },
    { id = "publicNote",  title = "NOTA PÚBLICA",      x = 475,  width = 120, align = "LEFT",   editable = false },
    { id = "officerNote", title = "NOTA DE OFICIAL",   x = 595,  width = 120, align = "LEFT",   editable = false },
    { id = "dateJoin",    title = "ENTRADA",          x = 715,  width = 85,  align = "LEFT",   editable = true,  label = "Data de Entrada" },
    { id = "recruiter",   title = "RECRUTADOR",       x = 800,  width = 100, align = "LEFT",   editable = true,  label = "Recrutador" },
    { id = "birthday",    title = "ANIVERSÁRIO",      x = 900,  width = 80,  align = "LEFT",   editable = true,  label = "Aniversário" },
    { id = "customNote",  title = "NOTA INTERNA",     x = 980,  width = 190, align = "LEFT",   editable = true,  label = "Nota Interna" },
}

local TOTAL_TABLE_WIDTH = 1170

local STATS_PANEL_WIDTH = 224

local ALL_CLASSES_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

local CLASS_NAMES_MAP = {
    ptBR = {
        WARRIOR = "Guerreiro", PALADIN = "Paladino", HUNTER = "Caçador",
        ROGUE = "Ladino", PRIEST = "Sacerdote", SHAMAN = "Xamã",
        MAGE = "Mago", WARLOCK = "Bruxo", DRUID = "Druida",
    },
    enUS = {
        WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter",
        ROGUE = "Rogue", PRIEST = "Priest", SHAMAN = "Shaman",
        MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
    }
}

local PROFESSIONS_DEF = {
    { key = "ALCHEMY",        name = "Alquimia",        nameEn = "Alchemy",        icon = "Interface\\Icons\\Trade_Alchemy" },
    { key = "TAILORING",      name = "Alfaiataria",     nameEn = "Tailoring",      icon = "Interface\\Icons\\Trade_Tailoring" },
    { key = "LEATHERWORKING", name = "Couraria",        nameEn = "Leatherworking", icon = "Interface\\Icons\\Trade_Leatherworking" },
    { key = "ENCHANTING",     name = "Encantamento",    nameEn = "Enchanting",     icon = "Interface\\Icons\\Trade_Engraving" },
    { key = "BLACKSMITHING",  name = "Ferraria",        nameEn = "Blacksmithing",  icon = "Interface\\Icons\\Trade_BlackSmithing" },
    { key = "ENGINEERING",    name = "Engenharia",      nameEn = "Engineering",    icon = "Interface\\Icons\\Trade_Engineering" },
    { key = "MINING",         name = "Mineração",       nameEn = "Mining",         icon = "Interface\\Icons\\Trade_Mining" },
    { key = "HERBALISM",      name = "Herborismo",      nameEn = "Herbalism",      icon = "Interface\\Icons\\Trade_Herbalism" },
    { key = "SKINNING",       name = "Esfolamento",     nameEn = "Skinning",       icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
    { key = "COOKING",        name = "Culinária",       nameEn = "Cooking",        icon = "Interface\\Icons\\INV_Misc_Food_15" },
    { key = "FIRST_AID",      name = "Primeiros Socorros", nameEn = "First Aid",   icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
    { key = "FISHING",        name = "Pescaria",        nameEn = "Fishing",        icon = "Interface\\Icons\\Trade_Fishing" },
}

local function normalizeRace(raceStr, isEn)
    if not raceStr or raceStr == "" then return isEn and "Unknown" or "Desconhecido" end
    local clean = raceStr:match("^%s*(.-)%s*$") or raceStr
    local lower = clean:lower()
    if lower:find("^an") or lower:find("^dwarf") then
        return isEn and "Dwarf" or "Anão"
    elseif lower:find("elf") or lower:find("night") then
        return isEn and "Night Elf" or "Elfo Noturno"
    elseif lower:find("^hum") then
        return isEn and "Human" or "Humano"
    elseif lower:find("^gnom") then
        return isEn and "Gnome" or "Gnomo"
    elseif lower:find("^orc") then
        return isEn and "Orc" or "Orc"
    elseif lower:find("^troll") then
        return isEn and "Troll" or "Troll"
    elseif lower:find("^taur") then
        return isEn and "Tauren" or "Tauren"
    elseif lower:find("^mort") or lower:find("undead") or lower:find("renegad") then
        return isEn and "Undead" or "Morto-vivo"
    elseif lower:find("celonat") then
        return "Celonato da Alta Ordem"
    else
        return clean
    end
end

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

--- Normaliza texto removendo caracteres especiais e acentuações para ordenação e busca natural.
---@param txt string|nil
---@return string
local function normalizeForSort(txt)
    if not txt or type(txt) ~= "string" then return "" end
    local s = txt:lower()
    s = s:gsub("đ", "d"):gsub("ð", "d")
    s = s:gsub("ø", "o"):gsub("œ", "oe"):gsub("æ", "ae")
    s = s:gsub("á", "a"):gsub("à", "a"):gsub("ã", "a"):gsub("â", "a"):gsub("ä", "a"):gsub("å", "a")
    s = s:gsub("é", "e"):gsub("è", "e"):gsub("ê", "e"):gsub("ë", "e")
    s = s:gsub("í", "i"):gsub("ì", "i"):gsub("î", "i"):gsub("ï", "i")
    s = s:gsub("ó", "o"):gsub("ò", "o"):gsub("õ", "o"):gsub("ô", "o"):gsub("ö", "o")
    s = s:gsub("ú", "u"):gsub("ù", "u"):gsub("û", "u"):gsub("ü", "u")
    s = s:gsub("ç", "c"):gsub("ñ", "n"):gsub("ß", "ss")
    return s
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
    instance._currentPage = 1
    instance._pageSize = 40
    instance._hOffset = 0
    instance._maxHOffset = 0
    instance._rows = {}
    instance._filterText = ""
    instance._activeFilter = "ALL"
    instance._collapsedMains = {}
    instance._numVisibleRows = 18
    instance._rowHeight = 24
    instance._onRefreshCallback = nil
    instance._onSaveCallback = nil
    instance._editModal = nil
    instance._editingMember = nil
    instance._paginationFrame = nil
    instance._pageText = nil
    instance._firstPageBtn = nil
    instance._prevPageBtn = nil
    instance._nextPageBtn = nil
    instance._lastPageBtn = nil
    instance._statsRowPool = {}
    instance._statsHeaderPool = {}

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

--- Verifica se o jogador conectado possui cargo de Oficial ou Líder da guilda.
---@return boolean
function AuditView:isPlayerOfficerOrLeader()
    if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
        return _G.GM.guildRosterService:isPlayerOfficerOrLeader()
    end
    if IsGuildLeader and IsGuildLeader() then
        return true
    end
    if CanEditOfficerNote and CanEditOfficerNote() then
        return true
    end
    if C_GuildInfo and C_GuildInfo.CanEditOfficerNote and C_GuildInfo.CanEditOfficerNote() then
        return true
    end
    return false
end

--- Cria e estiliza os componentes visuais da janela de auditoria no padrão WoW Forever.
function AuditView:createUI()
    if self._frame then
        return
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "GuildManagerAuditFrame", UIParent, template)
    self._frame = frame

    frame:SetSize(1180, 614)
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
        self:renderGuildStats()
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
    titleText:SetText(L["AUDIT_TITLE"])
    self._titleText = titleText

    -- Subtítulo informativo
    local subtitleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitleText:SetPoint("LEFT", titleText, "RIGHT", 12, 0)
    subtitleText:SetText(L["AUDIT_SUBTITLE"])
    self._subtitleText = subtitleText

    -- Divisória abaixo do cabeçalho
    local headerSep = frame:CreateTexture(nil, "ARTWORK")
    headerSep:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -44)
    headerSep:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    headerSep:SetHeight(1)
    headerSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- =========================================================================
    -- PAINEL LATERAL ESQUERDO: ESTATÍSTICAS DA GUILDA
    -- =========================================================================
    local statsInset = CreateFrame("Frame", "GM_AuditStatsInset", frame, template)
    statsInset:SetPoint("TOPLEFT", headerSep, "BOTTOMLEFT", 0, -8)
    statsInset:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 40)
    statsInset:SetWidth(STATS_PANEL_WIDTH)
    if statsInset.SetBackdrop then
        statsInset:SetBackdrop(CONTAINER_BACKDROP)
        statsInset:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        statsInset:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end
    self._statsInset = statsInset

    -- Cabeçalho do Painel de Estatísticas
    local statsHeaderBg = statsInset:CreateTexture(nil, "ARTWORK")
    statsHeaderBg:SetPoint("TOPLEFT", statsInset, "TOPLEFT", 4, -4)
    statsHeaderBg:SetPoint("TOPRIGHT", statsInset, "TOPRIGHT", -4, -4)
    statsHeaderBg:SetHeight(24)
    statsHeaderBg:SetColorTexture(PALETTE.HEADER_ROW_BG[1], PALETTE.HEADER_ROW_BG[2], PALETTE.HEADER_ROW_BG[3], 0.90)

    local statsTitle = statsInset:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsTitle:SetPoint("LEFT", statsHeaderBg, "LEFT", 8, 0)
    statsTitle:SetText("|cffffd200" .. (L["STATS_TITLE"] or "ESTATÍSTICAS DA GUILDA") .. "|r")
    self._statsTitle = statsTitle

    local statsMemberCount = statsInset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statsMemberCount:SetPoint("RIGHT", statsHeaderBg, "RIGHT", -8, 0)
    statsMemberCount:SetText("|cffaaaaaa0|r")
    self._statsMemberCount = statsMemberCount

    local statsHeaderSep = statsInset:CreateTexture(nil, "ARTWORK")
    statsHeaderSep:SetPoint("TOPLEFT", statsHeaderBg, "BOTTOMLEFT", 0, -1)
    statsHeaderSep:SetPoint("RIGHT", statsHeaderBg, "RIGHT", 0, -1)
    statsHeaderSep:SetHeight(1)
    statsHeaderSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.70)

    -- ScrollFrame do Painel de Estatísticas
    local statsScrollFrame = CreateFrame("ScrollFrame", "GM_AuditStatsScrollFrame", statsInset)
    statsScrollFrame:SetPoint("TOPLEFT", statsHeaderSep, "BOTTOMLEFT", 0, -2)
    statsScrollFrame:SetPoint("BOTTOMRIGHT", statsInset, "BOTTOMRIGHT", -18, 4)
    statsScrollFrame:EnableMouse(true)
    self._statsScrollFrame = statsScrollFrame

    local statsContent = CreateFrame("Frame", "GM_AuditStatsContent", statsScrollFrame)
    statsContent:SetWidth(STATS_PANEL_WIDTH - 24)
    statsContent:SetHeight(500)
    statsScrollFrame:SetScrollChild(statsContent)
    self._statsContent = statsContent

    local statsScrollBar = CreateFrame("Slider", "GM_AuditStatsScrollBar", statsInset, "UIPanelScrollBarTemplate")
    statsScrollBar:SetPoint("TOPRIGHT", statsInset, "TOPRIGHT", -3, -34)
    statsScrollBar:SetPoint("BOTTOMRIGHT", statsInset, "BOTTOMRIGHT", -3, 20)
    statsScrollBar:SetWidth(14)
    statsScrollBar:SetMinMaxValues(0, 100)
    statsScrollBar:SetValue(0)
    statsScrollBar:SetValueStep(20)
    statsScrollBar:SetScript("OnValueChanged", function(_, val)
        statsScrollFrame:SetVerticalScroll(val)
    end)
    self._statsScrollBar = statsScrollBar

    local function onStatsMouseWheel(delta)
        if not statsScrollBar or not statsScrollBar:IsShown() then return end
        local minV, maxV = statsScrollBar:GetMinMaxValues()
        if maxV <= 0 then return end
        local cur = statsScrollBar:GetValue() or 0
        local step = 30
        local nextV = math.max(minV, math.min(maxV, cur - (delta * step)))
        statsScrollBar:SetValue(nextV)
    end

    statsInset:EnableMouseWheel(true)
    statsInset:SetScript("OnMouseWheel", function(_, delta) onStatsMouseWheel(delta) end)
    statsScrollFrame:SetScript("OnMouseWheel", function(_, delta) onStatsMouseWheel(delta) end)

    -- =========================================================================
    -- BARRA DE BUSCA E FILTROS RÁPIDOS
    -- =========================================================================
    local searchEB = CreateFrame("EditBox", nil, frame, template)
    searchEB:SetPoint("TOPLEFT", headerSep, "BOTTOMLEFT", STATS_PANEL_WIDTH + 10, -8)
    searchEB:SetSize(175, 22)
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
    searchHint:SetText("|cff888888" .. L["AUDIT_SEARCH_HINT"] .. "|r")
    searchEB.hint = searchHint

    searchEB:SetScript("OnTextChanged", function(box)
        local txt = box:GetText()
        if txt and txt ~= "" then
            searchHint:Hide()
        else
            searchHint:Show()
        end
        self._filterText = txt or ""
        self._currentPage = 1
        self._offset = 0
        self:applyFilters()
    end)
    searchEB:SetScript("OnEscapePressed", function(box)
        box:SetText("")
        box:ClearFocus()
    end)
    self._searchEB = searchEB

    -- Botões de filtro rápido
    local filterTabs = {
        { id = "ALL", key = "FILTER_ALL", label = "Todos" },
        { id = "ONLINE", key = "FILTER_ONLINE", label = "Online" },
        { id = "MAINS", key = "FILTER_MAINS", label = "Apenas Mains" },
        { id = "WITH_ALTS", key = "FILTER_WITH_ALTS", label = "Com Alts" },
        { id = "NO_RECRUITER", key = "FILTER_NO_RECRUITER", label = "Sem Recrutador" },
        { id = "NO_OFFICER_NOTE", key = "FILTER_NO_OFFICER_NOTE", label = "Sem Nota Oficial" },
        { id = "NO_CUSTOM_NOTE", key = "FILTER_NO_CUSTOM_NOTE", label = "Sem Nota Interna" },
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
        btnText:SetText(L[tabData.key] or tabData.label)
        tabBtn.text = btnText

        local textWidth = btnText:GetStringWidth() or 40
        tabBtn:SetWidth(textWidth + 12)

        tabBtn:SetScript("OnClick", function()
            if tabData.id == "NO_OFFICER_NOTE" and not self:isPlayerOfficerOrLeader() then
                print("|cffff8800[GuildManager]|r O filtro de Nota de Oficial é exclusivo para Oficiais e o Líder da Guilda.")
                return
            end
            self._activeFilter = tabData.id
            self._currentPage = 1
            self._offset = 0
            self:updateFilterButtonsVisual()
            self:applyFilters()
        end)

        tabBtn:SetScript("OnEnter", function(btn)
            if tabData.id == "NO_OFFICER_NOTE" and not self:isPlayerOfficerOrLeader() then
                if GameTooltip then
                    GameTooltip:SetOwner(btn, "ANCHOR_TOP")
                    GameTooltip:AddLine(L[tabData.key] or tabData.label, 1, 0.82, 0)
                    GameTooltip:AddLine("|cffff4444SOMENTE OFICIAIS|r", 0.8, 0.8, 0.8, true)
                    GameTooltip:Show()
                end
            end
        end)

        tabBtn:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
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

    -- Botão de Sincronização P2P manual no topo direito da tabela
    local syncBtn = CreateFrame("Button", "GM_AuditSyncBtn", frame, template)
    syncBtn:SetSize(120, 22)
    syncBtn:SetPoint("BOTTOMRIGHT", tableInset, "TOPRIGHT", 0, 4)
    if syncBtn.SetBackdrop then
        syncBtn:SetBackdrop(SUB_CONTAINER_BACKDROP)
        syncBtn:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.90)
        syncBtn:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.90)
    end
    local syncText = syncBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    syncText:SetPoint("CENTER", syncBtn, "CENTER", 0, 0)
    syncText:SetText("|cffffd200" .. (L["SYNC_P2P_BTN"] or "Sincronizar P2P") .. "|r")
    syncBtn.text = syncText

    syncBtn:SetScript("OnEnter", function(btn)
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], 1.0)
            btn:SetBackdropColor(PALETTE.FOCUS_BG[1], PALETTE.FOCUS_BG[2], PALETTE.FOCUS_BG[3], 0.95)
        end
        if GameTooltip then
            GameTooltip:SetOwner(btn, "ANCHOR_TOPRIGHT")
            GameTooltip:AddLine("|cffffd200" .. (curL["SYNC_P2P_TOOLTIP"] or "Forçar Sincronização P2P") .. "|r")
            GameTooltip:AddLine(curL["SYNC_P2P_TOOLTIP_DESC"] or "Transmite na hora todos os dados customizados (Entrada, Aniversário, Alts, Recrutador e Profissões/Receitas) para todos os outros membros da guilda que usam o Addon.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    syncBtn:SetScript("OnLeave", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.90)
            btn:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.90)
        end
        if GameTooltip then GameTooltip:Hide() end
    end)
    syncBtn:SetScript("OnClick", function()
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        if _G.GM and _G.GM.syncService and _G.GM.syncService.forceSyncAll then
            _G.GM.syncService:forceSyncAll()
            if syncBtn.text then
                syncBtn.text:SetText("|cff00ff00" .. (curL["SYNCING"] or "Sincronizando...") .. "|r")
                if C_Timer and C_Timer.After then
                    C_Timer.After(2.0, function()
                        if syncBtn and syncBtn.text then
                            local freshL = (_G.GM and _G.GM.L) or _G.L or L
                            syncBtn.text:SetText("|cffffd200" .. (freshL["SYNC_P2P_BTN"] or "Sincronizar P2P") .. "|r")
                        end
                    end)
                end
            end
        end
    end)
    self._syncBtn = syncBtn

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
    self._colHeaderStrings = {}
    for _, col in ipairs(COLUMNS) do
        local colHeader = headerContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        colHeader:SetPoint("LEFT", headerContent, "LEFT", col.x + 4, 0)
        colHeader:SetWidth(col.width - 6)
        colHeader:SetJustifyH(col.align or "LEFT")

        local colKey = "COL_" .. col.id:upper()
        local colTitle = L[colKey]
        if not colTitle or colTitle == colKey then
            local isEn = (_G.GM and _G.GM.GetLocale and _G.GM.GetLocale() == "enUS") or (GetLocale and GetLocale() ~= "ptBR")
            if col.id == "role" then
                colTitle = isEn and "ROLE" or "FUNÇÃO"
            else
                colTitle = col.title
            end
        end
        if col.editable then
            colHeader:SetText(string.format("|cffffd200%s|r |cff00ff99*|r", colTitle))
        else
            colHeader:SetText(string.format("|cffffd200%s|r", colTitle))
        end
        self._colHeaderStrings[col.id] = colHeader
    end

    -- ScrollFrame das Linhas (rolagem horizontal vinculada)
    local rowsScrollFrame = CreateFrame("ScrollFrame", "GM_AuditRowsScrollFrame", tableInset)
    rowsScrollFrame:SetPoint("TOPLEFT", headerScrollFrame, "BOTTOMLEFT", 0, -2)
    rowsScrollFrame:SetPoint("BOTTOMRIGHT", tableInset, "BOTTOMRIGHT", -22, 24)
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
        levelTxt:SetPoint("LEFT", row, "LEFT", 195, 0)
        levelTxt:SetWidth(32)
        levelTxt:SetJustifyH("CENTER")
        row.levelTxt = levelTxt

        -- Coluna 3: Cargo (Rank da Guilda)
        local rankTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rankTxt:SetPoint("LEFT", row, "LEFT", 295, 0)
        rankTxt:SetWidth(88)
        rankTxt:SetJustifyH("LEFT")
        rankTxt:SetWordWrap(false)
        row.rankTxt = rankTxt

        -- Coluna 4: ONLINE (Status de Conexão ou Tempo desde Última Vez Online)
        local onlineTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        onlineTxt:SetPoint("LEFT", row, "LEFT", 385, 0)
        onlineTxt:SetWidth(88)
        onlineTxt:SetJustifyH("LEFT")
        onlineTxt:SetWordWrap(false)
        row.onlineTxt = onlineTxt

        -- Coluna 5: Nota Pública (Blizzard - Somente Leitura)
        local publicNoteTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        publicNoteTxt:SetPoint("LEFT", row, "LEFT", 475, 0)
        publicNoteTxt:SetWidth(116)
        publicNoteTxt:SetJustifyH("LEFT")
        publicNoteTxt:SetWordWrap(false)
        row.publicNoteTxt = publicNoteTxt

        -- Coluna 6: Nota de Oficial (Blizzard - Somente Leitura)
        local officerNoteTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        officerNoteTxt:SetPoint("LEFT", row, "LEFT", 595, 0)
        officerNoteTxt:SetWidth(116)
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
                    if colId == "role" then
                        GameTooltip:AddLine("|cff00ff00Clique com botão esquerdo para alternar (TANK -> HEALER -> DPS)|r", 0.2, 1.0, 0.2)
                        GameTooltip:AddLine("|cffaaaaaaClique com botão direito para abrir a janela de edição|r", 0.7, 0.7, 0.7)
                    elseif (colId == "dateJoin" or colId == "recruiter") then
                        local canOfficer = false
                        if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
                            canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
                        elseif IsGuildLeader and IsGuildLeader() then
                            canOfficer = true
                        elseif CanEditOfficerNote and CanEditOfficerNote() then
                            canOfficer = true
                        end
                        if not canOfficer then
                            GameTooltip:AddLine("|cffff4444(Apenas Oficiais ou o Líder da Guilda podem editar)|r", 1, 0.3, 0.3)
                        else
                            GameTooltip:AddLine("|cff00ff00Clique para abrir a janela de edição|r", 0.2, 1.0, 0.2)
                        end
                    else
                        GameTooltip:AddLine("|cff00ff00Clique para abrir a janela de edição|r", 0.2, 1.0, 0.2)
                    end
                    GameTooltip:Show()
                end
            end)

            cellBtn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            cellBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            cellBtn:SetScript("OnClick", function(_, button)
                if row.rowData and row.rowData.member then
                    if colId == "role" and button == "LeftButton" then
                        local m = row.rowData.member
                        local cur = (m.getRole and m:getRole() or ""):upper()
                        local nextR = "TANK"
                        if cur == "TANK" then
                            nextR = "HEALER"
                        elseif cur == "HEALER" then
                            nextR = "DPS"
                        elseif cur == "DPS" then
                            nextR = "TANK"
                        end
                        m:setRole(nextR)
                        m:setCustomDataTimestamp(getCurrentTimestamp())
                        if self._onSaveCallback then
                            self._onSaveCallback(m, { role = nextR })
                        else
                            if _G.GM and _G.GM.memberService then
                                _G.GM.memberService:saveMember(m)
                            end
                        end
                        self:refreshRows()
                        return
                    end
                    self:openEditModal(row.rowData.member, colId)
                end
            end)

            return cellBtn
        end

        -- Coluna 2.5: Função / Role (Editável)
        local roleCell = setupEditableCell("role", 227, 68, "Função / Role")
        row.roleBtn = roleCell
        row.roleTxt = roleCell.txt

        -- Coluna 7: Data de Entrada (Editável)
        local dateJoinCell = setupEditableCell("dateJoin", 715, 85, "Data de Entrada")
        row.dateJoinBtn = dateJoinCell
        row.dateJoinTxt = dateJoinCell.txt

        -- Coluna 8: Recrutador (Editável)
        local recruiterCell = setupEditableCell("recruiter", 800, 100, "Recrutador")
        row.recruiterBtn = recruiterCell
        row.recruiterTxt = recruiterCell.txt

        -- Coluna 9: Aniversário (Editável)
        local birthdayCell = setupEditableCell("birthday", 900, 80, "Aniversário")
        row.birthdayBtn = birthdayCell
        row.birthdayTxt = birthdayCell.txt

        -- Coluna 10: Nota Interna (Editável)
        local customNoteCell = setupEditableCell("customNote", 980, 190, "Nota Interna")
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
                if _G.GM and _G.GM.memberView and _G.GM.memberView.showMember then
                    _G.GM.memberView:showMember(r.rowData.member, true)
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
                if self:isPlayerOfficerOrLeader() then
                    GameTooltip:AddLine(string.format("Nota de Oficial: |cffffffff%s|r", m:getOfficerNote() ~= "" and m:getOfficerNote() or "(Nenhuma)"), 0.8, 0.8, 0.8, true)
                else
                    GameTooltip:AddLine("Nota de Oficial: |cffff4444SOMENTE OFICIAIS|r", 0.8, 0.8, 0.8, true)
                end

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
    footerText:SetPoint("BOTTOMLEFT", tableInset, "BOTTOMLEFT", 0, -26)
    footerText:SetText("|cffaaaaaaTotal de membros na guilda: 0|r")
    self._footerText = footerText

    -- Controles de Paginação (40 membros por página, centralizados no rodapé)
    local paginationFrame = CreateFrame("Frame", "GM_AuditPaginationFrame", frame)
    paginationFrame:SetPoint("BOTTOM", tableInset, "BOTTOM", 0, -30)
    paginationFrame:SetSize(360, 24)
    paginationFrame:EnableMouseWheel(true)
    paginationFrame:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then
            self:prevPage()
        else
            self:nextPage()
        end
    end)
    self._paginationFrame = paginationFrame

    local pageText = paginationFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pageText:SetPoint("CENTER", paginationFrame, "CENTER", 0, 0)
    pageText:SetText("|cffffd200Página 1 de 1|r")
    self._pageText = pageText

    local prevPageBtn = CreateFrame("Button", "GM_AuditPrevPageBtn", paginationFrame, "UIPanelButtonTemplate")
    prevPageBtn:SetSize(24, 22)
    prevPageBtn:SetText("<")
    prevPageBtn:SetPoint("RIGHT", pageText, "LEFT", -8, 0)
    prevPageBtn:SetScript("OnClick", function()
        self:prevPage()
    end)
    prevPageBtn:SetScript("OnEnter", function(btn)
        if GameTooltip then
            GameTooltip:SetOwner(btn, "ANCHOR_TOP")
            GameTooltip:AddLine("Página Anterior", 1, 0.82, 0)
            GameTooltip:AddLine("Clique ou use a roda do mouse para navegar", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    prevPageBtn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    self._prevPageBtn = prevPageBtn

    local firstPageBtn = CreateFrame("Button", "GM_AuditFirstPageBtn", paginationFrame, "UIPanelButtonTemplate")
    firstPageBtn:SetSize(28, 22)
    firstPageBtn:SetText("<<")
    firstPageBtn:SetPoint("RIGHT", prevPageBtn, "LEFT", -4, 0)
    firstPageBtn:SetScript("OnClick", function()
        self:firstPage()
    end)
    firstPageBtn:SetScript("OnEnter", function(btn)
        if GameTooltip then
            GameTooltip:SetOwner(btn, "ANCHOR_TOP")
            GameTooltip:AddLine("Primeira Página", 1, 0.82, 0)
            GameTooltip:Show()
        end
    end)
    firstPageBtn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    self._firstPageBtn = firstPageBtn

    local nextPageBtn = CreateFrame("Button", "GM_AuditNextPageBtn", paginationFrame, "UIPanelButtonTemplate")
    nextPageBtn:SetSize(24, 22)
    nextPageBtn:SetText(">")
    nextPageBtn:SetPoint("LEFT", pageText, "RIGHT", 8, 0)
    nextPageBtn:SetScript("OnClick", function()
        self:nextPage()
    end)
    nextPageBtn:SetScript("OnEnter", function(btn)
        if GameTooltip then
            GameTooltip:SetOwner(btn, "ANCHOR_TOP")
            GameTooltip:AddLine("Próxima Página", 1, 0.82, 0)
            GameTooltip:AddLine("Clique ou use a roda do mouse para navegar", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    nextPageBtn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    self._nextPageBtn = nextPageBtn

    local lastPageBtn = CreateFrame("Button", "GM_AuditLastPageBtn", paginationFrame, "UIPanelButtonTemplate")
    lastPageBtn:SetSize(28, 22)
    lastPageBtn:SetText(">>")
    lastPageBtn:SetPoint("LEFT", nextPageBtn, "RIGHT", 4, 0)
    lastPageBtn:SetScript("OnClick", function()
        self:lastPage()
    end)
    lastPageBtn:SetScript("OnEnter", function(btn)
        if GameTooltip then
            GameTooltip:SetOwner(btn, "ANCHOR_TOP")
            GameTooltip:AddLine("Última Página", 1, 0.82, 0)
            GameTooltip:Show()
        end
    end)
    lastPageBtn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    self._lastPageBtn = lastPageBtn

    -- Botão Atualizar
    local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(90, 22)
    refreshBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 10)
    refreshBtn:SetText(L["REFRESH"])
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
    self:createSideTabs()
end

--- Cria as abas de navegação lateral (estilo Profissões Blizzard) na borda direita da janela.
function AuditView:createSideTabs()
    local frame = self._frame
    if not frame then return end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    local SIDE_TAB_BACKDROP = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    }

    -- ---------------------------------------------------------
    -- Aba 1: Auditoria (Ativa nesta tela - Ícone Livro Aberto)
    -- ---------------------------------------------------------
    local tabAudit = CreateFrame("Button", "GM_AuditSideTab_Audit", frame, template)
    tabAudit:SetSize(36, 36)
    tabAudit:SetPoint("TOPLEFT", frame, "TOPRIGHT", -2, -44)
    if tabAudit.SetBackdrop then
        tabAudit:SetBackdrop(SIDE_TAB_BACKDROP)
        tabAudit:SetBackdropColor(0.18, 0.12, 0.04, 0.95)
        tabAudit:SetBackdropBorderColor(1.0, 0.82, 0.20, 1.0)
    end

    local auditIcon = tabAudit:CreateTexture(nil, "ARTWORK")
    auditIcon:SetPoint("TOPLEFT", tabAudit, "TOPLEFT", 4, -4)
    auditIcon:SetPoint("BOTTOMRIGHT", tabAudit, "BOTTOMRIGHT", -4, 4)
    auditIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    auditIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    auditIcon:SetVertexColor(1.0, 1.0, 1.0)
    tabAudit.icon = auditIcon

    -- Brilho dourado de aba ativa
    local auditGlow = tabAudit:CreateTexture(nil, "OVERLAY")
    auditGlow:SetPoint("TOPLEFT", tabAudit, "TOPLEFT", -2, 2)
    auditGlow:SetPoint("BOTTOMRIGHT", tabAudit, "BOTTOMRIGHT", 2, -2)
    auditGlow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    auditGlow:SetBlendMode("ADD")
    auditGlow:SetVertexColor(1.0, 0.85, 0.20, 0.80)
    tabAudit.glow = auditGlow

    tabAudit:SetScript("OnEnter", function(btn)
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd200" .. curL["TAB_AUDIT_TOOLTIP"] .. "|r")
        GameTooltip:AddLine("|cff888888" .. curL["TAB_CURRENT"] .. "|r", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(curL["TAB_AUDIT_TOOLTIP_DESC"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    tabAudit:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- ---------------------------------------------------------
    -- Aba 2: Logs (Inativa nesta tela - Folhas de Papel / Jornal)
    -- ---------------------------------------------------------
    local tabLogs = CreateFrame("Button", "GM_AuditSideTab_Logs", frame, template)
    tabLogs:SetSize(36, 36)
    tabLogs:SetPoint("TOPLEFT", tabAudit, "BOTTOMLEFT", 0, -8)
    if tabLogs.SetBackdrop then
        tabLogs:SetBackdrop(SIDE_TAB_BACKDROP)
        tabLogs:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
        tabLogs:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
    end

    local logsIcon = tabLogs:CreateTexture(nil, "ARTWORK")
    logsIcon:SetPoint("TOPLEFT", tabLogs, "TOPLEFT", 4, -4)
    logsIcon:SetPoint("BOTTOMRIGHT", tabLogs, "BOTTOMRIGHT", -4, 4)
    logsIcon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    logsIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    logsIcon:SetVertexColor(0.65, 0.65, 0.65)
    tabLogs.icon = logsIcon

    local logsHl = tabLogs:CreateTexture(nil, "HIGHLIGHT")
    logsHl:SetAllPoints(tabLogs)
    logsHl:SetColorTexture(PALETTE.HIGHLIGHT_TINT[1], PALETTE.HIGHLIGHT_TINT[2], PALETTE.HIGHLIGHT_TINT[3], 0.30)
    tabLogs:SetHighlightTexture(logsHl)

    tabLogs:SetScript("OnEnter", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.95, 0.70, 0.25, 1.0)
            btn:SetBackdropColor(0.08, 0.05, 0.02, 0.95)
        end
        logsIcon:SetVertexColor(1.0, 1.0, 1.0)
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd200" .. curL["TAB_LOGS_TOOLTIP"] .. "|r")
        GameTooltip:AddLine(curL["TAB_LOGS_TOOLTIP_DESC"], 1, 1, 1, true)
        GameTooltip:Show()
    end)

    tabLogs:SetScript("OnLeave", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
            btn:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
        end
        logsIcon:SetVertexColor(0.65, 0.65, 0.65)
        GameTooltip:Hide()
    end)

    tabLogs:SetScript("OnClick", function()
        if PlaySound then
            if SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then
                PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            else
                pcall(PlaySound, 841)
            end
        end

        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
        self:hide()

        local logCtrl = (_G.GM and _G.GM.logController) or _G.logController
        if logCtrl then
            logCtrl:show()
            local logFrame = (_G.GM and _G.GM.logView and _G.GM.logView.getFrame and _G.GM.logView:getFrame()) or (logCtrl._logView and logCtrl._logView:getFrame())
            if logFrame and point then
                logFrame:ClearAllPoints()
                if relativeTo then
                    logFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
                else
                    logFrame:SetPoint(point, xOfs, yOfs)
                end
            end
        end
    end)

    -- ---------------------------------------------------------
    -- Aba 3: Grupos (Inativa nesta tela - Ícone Grupos)
    -- ---------------------------------------------------------
    local tabGroups = CreateFrame("Button", "GM_AuditSideTab_Groups", frame, template)
    tabGroups:SetSize(36, 36)
    tabGroups:SetPoint("TOPLEFT", tabLogs, "BOTTOMLEFT", 0, -8)
    if tabGroups.SetBackdrop then
        tabGroups:SetBackdrop(SIDE_TAB_BACKDROP)
        tabGroups:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
        tabGroups:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
    end

    local groupsIcon = tabGroups:CreateTexture(nil, "ARTWORK")
    groupsIcon:SetPoint("TOPLEFT", tabGroups, "TOPLEFT", 4, -4)
    groupsIcon:SetPoint("BOTTOMRIGHT", tabGroups, "BOTTOMRIGHT", -4, 4)
    groupsIcon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    groupsIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    groupsIcon:SetVertexColor(0.65, 0.65, 0.65)
    tabGroups.icon = groupsIcon

    local groupsHl = tabGroups:CreateTexture(nil, "HIGHLIGHT")
    groupsHl:SetAllPoints(tabGroups)
    groupsHl:SetColorTexture(PALETTE.HIGHLIGHT_TINT[1], PALETTE.HIGHLIGHT_TINT[2], PALETTE.HIGHLIGHT_TINT[3], 0.30)
    tabGroups:SetHighlightTexture(groupsHl)

    tabGroups:SetScript("OnEnter", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.95, 0.70, 0.25, 1.0)
            btn:SetBackdropColor(0.08, 0.05, 0.02, 0.95)
        end
        groupsIcon:SetVertexColor(1.0, 1.0, 1.0)
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd200" .. curL["TAB_GROUPS_TOOLTIP"] .. "|r")
        GameTooltip:AddLine(curL["TAB_GROUPS_TOOLTIP_DESC"], 1, 1, 1, true)
        GameTooltip:Show()
    end)

    tabGroups:SetScript("OnLeave", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
            btn:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
        end
        groupsIcon:SetVertexColor(0.65, 0.65, 0.65)
        GameTooltip:Hide()
    end)

    tabGroups:SetScript("OnClick", function()
        if PlaySound then
            if SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then
                PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            else
                pcall(PlaySound, 841)
            end
        end

        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
        self:hide()

        local groupCtrl = (_G.GM and _G.GM.groupController) or _G.groupController
        if groupCtrl then
            groupCtrl:show()
            local groupFrame = (_G.GM and _G.GM.groupView and _G.GM.groupView.getFrame and _G.GM.groupView:getFrame()) or (groupCtrl._groupView and groupCtrl._groupView:getFrame())
            if groupFrame and point then
                groupFrame:ClearAllPoints()
                if relativeTo then
                    groupFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
                else
                    groupFrame:SetPoint(point, xOfs, yOfs)
                end
            end
        end
    end)

    -- ---------------------------------------------------------
    -- Aba 4: Agenda (Inativa nesta tela - Ícone Calendário)
    -- ---------------------------------------------------------
    local tabAgenda = CreateFrame("Button", "GM_AuditSideTab_Agenda", frame, template)
    tabAgenda:SetSize(36, 36)
    tabAgenda:SetPoint("TOPLEFT", tabGroups, "BOTTOMLEFT", 0, -8)
    if tabAgenda.SetBackdrop then
        tabAgenda:SetBackdrop(SIDE_TAB_BACKDROP)
        tabAgenda:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
        tabAgenda:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
    end

    local agendaIcon = tabAgenda:CreateTexture(nil, "ARTWORK")
    agendaIcon:SetPoint("TOPLEFT", tabAgenda, "TOPLEFT", 4, -4)
    agendaIcon:SetPoint("BOTTOMRIGHT", tabAgenda, "BOTTOMRIGHT", -4, 4)
    local okAgenda = agendaIcon:SetTexture("Interface\\Calendar\\UI-Calendar-Button")
    if okAgenda ~= false and agendaIcon:GetTexture() then
        agendaIcon:SetTexCoord(0.0078, 0.375, 0.0156, 0.75)
    else
        agendaIcon:SetTexture("Interface\\AddOns\\GuildManager\\Textures\\calendar.tga")
        agendaIcon:SetTexCoord(0, 1, 0, 1)
    end
    agendaIcon:SetVertexColor(0.65, 0.65, 0.65)
    tabAgenda.icon = agendaIcon

    local agendaHl = tabAgenda:CreateTexture(nil, "HIGHLIGHT")
    agendaHl:SetAllPoints(tabAgenda)
    agendaHl:SetColorTexture(PALETTE.HIGHLIGHT_TINT[1], PALETTE.HIGHLIGHT_TINT[2], PALETTE.HIGHLIGHT_TINT[3], 0.30)
    tabAgenda:SetHighlightTexture(agendaHl)

    tabAgenda:SetScript("OnEnter", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.95, 0.70, 0.25, 1.0)
            btn:SetBackdropColor(0.08, 0.05, 0.02, 0.95)
        end
        agendaIcon:SetVertexColor(1.0, 1.0, 1.0)
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd200" .. curL["TAB_AGENDA_TOOLTIP"] .. "|r")
        GameTooltip:AddLine(curL["TAB_AGENDA_TOOLTIP_DESC"], 1, 1, 1, true)
        GameTooltip:Show()
    end)

    tabAgenda:SetScript("OnLeave", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
            btn:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
        end
        agendaIcon:SetVertexColor(0.65, 0.65, 0.65)
        GameTooltip:Hide()
    end)

    tabAgenda:SetScript("OnClick", function()
        if PlaySound then
            pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841)
        end

        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
        self:hide()

        local agendaCtrl = (_G.GM and _G.GM.agendaController) or _G.agendaController
        if agendaCtrl then
            agendaCtrl:show()
            local agendaFrame = (_G.GM and _G.GM.agendaView and _G.GM.agendaView.getFrame and _G.GM.agendaView:getFrame()) or (agendaCtrl._agendaView and agendaCtrl._agendaView:getFrame())
            if agendaFrame and point then
                agendaFrame:ClearAllPoints()
                if relativeTo then
                    agendaFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
                else
                    agendaFrame:SetPoint(point, xOfs, yOfs)
                end
            end
        end
    end)

    -- ---------------------------------------------------------
    -- Aba 5: Pedidos de Profissão & Artesãos
    -- ---------------------------------------------------------
    local tabProf = CreateFrame("Button", "GM_AuditSideTab_Professions", frame, template)
    tabProf:SetSize(36, 36)
    tabProf:SetPoint("TOPLEFT", tabAgenda, "BOTTOMLEFT", 0, -8)
    if tabProf.SetBackdrop then
        tabProf:SetBackdrop(SIDE_TAB_BACKDROP)
        tabProf:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
        tabProf:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
    end

    local profIcon = tabProf:CreateTexture(nil, "ARTWORK")
    profIcon:SetPoint("TOPLEFT", tabProf, "TOPLEFT", 4, -4)
    profIcon:SetPoint("BOTTOMRIGHT", tabProf, "BOTTOMRIGHT", -4, 4)
    profIcon:SetTexture("Interface\\Icons\\Trade_BlackSmithing")
    profIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    profIcon:SetVertexColor(0.65, 0.65, 0.65)
    tabProf.icon = profIcon

    local profHl = tabProf:CreateTexture(nil, "HIGHLIGHT")
    profHl:SetAllPoints(tabProf)
    profHl:SetColorTexture(PALETTE.HIGHLIGHT_TINT[1], PALETTE.HIGHLIGHT_TINT[2], PALETTE.HIGHLIGHT_TINT[3], 0.30)
    tabProf:SetHighlightTexture(profHl)

    tabProf:SetScript("OnEnter", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.95, 0.70, 0.25, 1.0)
            btn:SetBackdropColor(0.08, 0.05, 0.02, 0.95)
        end
        profIcon:SetVertexColor(1.0, 1.0, 1.0)
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd200" .. (curL["TAB_PROFESSIONS_TOOLTIP"] or "Pedidos de Profissão") .. "|r")
        GameTooltip:AddLine(curL["TAB_PROFESSIONS_TOOLTIP_DESC"] or "Consulte receitas, veja quem faz na guilda e faça pedidos de fabricação.", 1, 1, 1, true)
        GameTooltip:Show()
    end)

    tabProf:SetScript("OnLeave", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
            btn:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
        end
        profIcon:SetVertexColor(0.65, 0.65, 0.65)
        GameTooltip:Hide()
    end)

    tabProf:SetScript("OnClick", function()
        if PlaySound then
            pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841)
        end

        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
        self:hide()

        local profCtrl = (_G.GM and _G.GM.professionController) or _G.professionController
        if profCtrl then
            profCtrl:show()
            local pFrame = (_G.GM and _G.GM.professionView and _G.GM.professionView.getFrame and _G.GM.professionView:getFrame()) or (profCtrl._professionView and profCtrl._professionView:getFrame())
            if pFrame and point then
                pFrame:ClearAllPoints()
                if relativeTo then
                    pFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
                else
                    pFrame:SetPoint(point, xOfs, yOfs)
                end
            end
        end
    end)

    -- ---------------------------------------------------------
    -- Aba 6: Configurações do Addon
    -- ---------------------------------------------------------
    local tabSettings = CreateFrame("Button", "GM_AuditSideTab_Settings", frame, template)
    tabSettings:SetSize(36, 36)
    tabSettings:SetPoint("TOPLEFT", tabProf, "BOTTOMLEFT", 0, -8)
    if tabSettings.SetBackdrop then
        tabSettings:SetBackdrop(SIDE_TAB_BACKDROP)
        tabSettings:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
        tabSettings:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
    end

    local settingsIcon = tabSettings:CreateTexture(nil, "ARTWORK")
    settingsIcon:SetPoint("TOPLEFT", tabSettings, "TOPLEFT", 4, -4)
    settingsIcon:SetPoint("BOTTOMRIGHT", tabSettings, "BOTTOMRIGHT", -4, 4)
    settingsIcon:SetTexture("Interface\\Icons\\Trade_Engineering")
    settingsIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    settingsIcon:SetVertexColor(0.65, 0.65, 0.65)
    tabSettings.icon = settingsIcon

    local settingsHl = tabSettings:CreateTexture(nil, "HIGHLIGHT")
    settingsHl:SetAllPoints(tabSettings)
    settingsHl:SetColorTexture(PALETTE.HIGHLIGHT_TINT[1], PALETTE.HIGHLIGHT_TINT[2], PALETTE.HIGHLIGHT_TINT[3], 0.30)
    tabSettings:SetHighlightTexture(settingsHl)

    tabSettings:SetScript("OnEnter", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.95, 0.70, 0.25, 1.0)
            btn:SetBackdropColor(0.08, 0.05, 0.02, 0.95)
        end
        settingsIcon:SetVertexColor(1.0, 1.0, 1.0)
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd200" .. curL["TAB_SETTINGS_TOOLTIP"] .. "|r")
        GameTooltip:AddLine(curL["TAB_SETTINGS_TOOLTIP_DESC"], 1, 1, 1, true)
        GameTooltip:Show()
    end)

    tabSettings:SetScript("OnLeave", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
            btn:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
        end
        settingsIcon:SetVertexColor(0.65, 0.65, 0.65)
        GameTooltip:Hide()
    end)

    tabSettings:SetScript("OnClick", function()
        if PlaySound then
            if SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then
                PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            else
                pcall(PlaySound, 841)
            end
        end

        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
        self:hide()

        local settingsCtrl = (_G.GM and _G.GM.settingsController) or _G.settingsController
        if settingsCtrl then
            settingsCtrl:show()
            local sFrame = (_G.GM and _G.GM.settingsView and _G.GM.settingsView.getFrame and _G.GM.settingsView:getFrame()) or (settingsCtrl._settingsView and settingsCtrl._settingsView:getFrame())
            if sFrame and point then
                sFrame:ClearAllPoints()
                if relativeTo then
                    sFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
                else
                    sFrame:SetPoint(point, xOfs, yOfs)
                end
            end
        end
    end)

    self._tabAudit = tabAudit
    self._tabLogs = tabLogs
    self._tabGroups = tabGroups
    self._tabSettings = tabSettings
end

--- Cria a janela modal de edição de informações de gestão do membro.
function AuditView:createEditModal()
    if self._editModal then
        return
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local modal = CreateFrame("Frame", "GuildManagerAuditEditModal", UIParent, template)
    modal:SetSize(460, 426)
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
    modalTitle:SetText(L["EDIT_MODAL_TITLE"])
    modal.titleText = modalTitle

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
    dateJoinLabel:SetText("|cffffd200" .. L["EDIT_JOIN_DATE_LABEL"] .. "|r")
    modal.dateJoinLabel = dateJoinLabel

    local dateJoinEB = CreateFrame("EditBox", nil, modal, template)
    dateJoinEB:SetPoint("TOPLEFT", dateJoinLabel, "BOTTOMLEFT", 0, -4)
    dateJoinEB:SetSize(280, 24)
    styleModalBox(dateJoinEB)
    modal.dateJoinEB = dateJoinEB

    local function showDateJoinModalTooltip(target)
        if not GameTooltip then return end
        GameTooltip:SetOwner(target, "ANCHOR_TOP")
        GameTooltip:AddLine("|cffffd200Data de Entrada|r", 1, 1, 1)
        local curVal = dateJoinEB:GetText() or ""
        GameTooltip:AddLine(string.format("Valor atual: |cffffffff%s|r", curVal ~= "" and curVal or "(Não informado)"), 0.85, 0.85, 0.85)
        GameTooltip:AddLine(" ")

        local canOfficer = false
        if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
            canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
        elseif IsGuildLeader and IsGuildLeader() then
            canOfficer = true
        elseif CanEditOfficerNote and CanEditOfficerNote() then
            canOfficer = true
        end

        if not canOfficer then
            GameTooltip:AddLine("|cffff4444Apenas Oficiais ou o Líder da Guilda podem alterar este campo.|r", 1, 0.3, 0.3, true)
        else
            GameTooltip:AddLine("|cff00ff00Clique para editar.|r\n|cffaaaaaa(Permissão de Oficial/Líder ativa)|r", 0.2, 1.0, 0.2)
        end
        GameTooltip:Show()
    end

    dateJoinEB:SetScript("OnEnter", function(eb) showDateJoinModalTooltip(eb) end)
    dateJoinEB:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    dateJoinEB:HookScript("OnEditFocusGained", function(eb)
        local canOfficer = false
        if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
            canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
        elseif IsGuildLeader and IsGuildLeader() then
            canOfficer = true
        elseif CanEditOfficerNote and CanEditOfficerNote() then
            canOfficer = true
        end
        if not canOfficer then
            eb:ClearFocus()
            print("|cffff4444[GuildManager]|r Apenas Oficiais ou o Líder da Guilda podem alterar a Data de Entrada.")
        end
    end)

    local dateJoinTodayBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    dateJoinTodayBtn:SetPoint("LEFT", dateJoinEB, "RIGHT", 6, 0)
    dateJoinTodayBtn:SetSize(64, 22)
    dateJoinTodayBtn:SetText("Hoje")
    dateJoinTodayBtn:SetScript("OnEnter", function(btn)
        if not GameTooltip then return end
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        GameTooltip:AddLine("|cffffd200Definir Data de Hoje|r", 1, 1, 1)
        local canOfficer = false
        if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
            canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
        elseif IsGuildLeader and IsGuildLeader() then
            canOfficer = true
        elseif CanEditOfficerNote and CanEditOfficerNote() then
            canOfficer = true
        end
        if not canOfficer then
            GameTooltip:AddLine("|cffff4444Apenas Oficiais ou o Líder da Guilda podem alterar a Data de Entrada.|r", 1, 0.3, 0.3, true)
        else
            GameTooltip:AddLine("|cff00ff00Clique para preencher com a data de hoje.|r", 0.2, 1.0, 0.2)
        end
        GameTooltip:Show()
    end)
    dateJoinTodayBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    dateJoinTodayBtn:SetScript("OnClick", function()
        local canOfficer = false
        if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
            canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
        elseif IsGuildLeader and IsGuildLeader() then
            canOfficer = true
        elseif CanEditOfficerNote and CanEditOfficerNote() then
            canOfficer = true
        end
        if not canOfficer then
            print("|cffff4444[GuildManager]|r Apenas Oficiais ou o Líder da Guilda podem alterar a Data de Entrada.")
            return
        end
        dateJoinEB:SetText(getTodayString())
    end)
    modal.dateJoinTodayBtn = dateJoinTodayBtn

    -- 2. CAMPO: RECRUTADOR
    local recruiterLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    recruiterLabel:SetPoint("TOPLEFT", dateJoinEB, "BOTTOMLEFT", 0, -10)
    recruiterLabel:SetText("|cffffd200" .. L["EDIT_RECRUITER_LABEL"] .. "|r")
    modal.recruiterLabel = recruiterLabel

    local recruiterEB = CreateFrame("EditBox", nil, modal, template)
    recruiterEB:SetPoint("TOPLEFT", recruiterLabel, "BOTTOMLEFT", 0, -4)
    recruiterEB:SetSize(280, 24)
    styleModalBox(recruiterEB)
    modal.recruiterEB = recruiterEB

    local function showRecruiterModalTooltip(target)
        if not GameTooltip then return end
        GameTooltip:SetOwner(target, "ANCHOR_TOP")
        GameTooltip:AddLine("|cffffd200Recrutador|r", 1, 1, 1)
        local curVal = recruiterEB:GetText() or ""
        GameTooltip:AddLine(string.format("Valor atual: |cffffffff%s|r", curVal ~= "" and curVal or "(Não informado)"), 0.85, 0.85, 0.85)
        GameTooltip:AddLine(" ")

        local canOfficer = false
        if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
            canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
        elseif IsGuildLeader and IsGuildLeader() then
            canOfficer = true
        elseif CanEditOfficerNote and CanEditOfficerNote() then
            canOfficer = true
        end

        if not canOfficer then
            GameTooltip:AddLine("|cffff4444Apenas Oficiais ou o Líder da Guilda podem alterar este campo.|r", 1, 0.3, 0.3, true)
        else
            GameTooltip:AddLine("|cff00ff00Clique para digitar o nome do recrutador.|r\n|cffaaaaaa(Permissão de Oficial/Líder ativa)|r", 0.2, 1.0, 0.2)
        end
        GameTooltip:Show()
    end

    recruiterEB:SetScript("OnEnter", function(eb) showRecruiterModalTooltip(eb) end)
    recruiterEB:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    recruiterEB:HookScript("OnEditFocusGained", function(eb)
        local canOfficer = false
        if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
            canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
        elseif IsGuildLeader and IsGuildLeader() then
            canOfficer = true
        elseif CanEditOfficerNote and CanEditOfficerNote() then
            canOfficer = true
        end
        if not canOfficer then
            eb:ClearFocus()
            print("|cffff4444[GuildManager]|r Apenas Oficiais ou o Líder da Guilda podem alterar o recrutador.")
        end
    end)

    local recruiterSelfBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    recruiterSelfBtn:SetPoint("LEFT", recruiterEB, "RIGHT", 6, 0)
    recruiterSelfBtn:SetSize(64, 22)
    recruiterSelfBtn:SetText("Eu")
    recruiterSelfBtn:SetScript("OnEnter", function(btn)
        if not GameTooltip then return end
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        GameTooltip:AddLine("|cffffd200Definir Meu Nome|r", 1, 1, 1)
        local canOfficer = false
        if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
            canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
        elseif IsGuildLeader and IsGuildLeader() then
            canOfficer = true
        elseif CanEditOfficerNote and CanEditOfficerNote() then
            canOfficer = true
        end
        if not canOfficer then
            GameTooltip:AddLine("|cffff4444Apenas Oficiais ou o Líder da Guilda podem alterar o recrutador.|r", 1, 0.3, 0.3, true)
        else
            GameTooltip:AddLine("|cff00ff00Clique para preencher com o seu nome.|r", 0.2, 1.0, 0.2)
        end
        GameTooltip:Show()
    end)
    recruiterSelfBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    recruiterSelfBtn:SetScript("OnClick", function()
        local canOfficer = false
        if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
            canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
        elseif IsGuildLeader and IsGuildLeader() then
            canOfficer = true
        elseif CanEditOfficerNote and CanEditOfficerNote() then
            canOfficer = true
        end
        if not canOfficer then
            print("|cffff4444[GuildManager]|r Apenas Oficiais ou o Líder da Guilda podem alterar o recrutador.")
            return
        end
        recruiterEB:SetText(getPlayerName())
    end)
    modal.recruiterSelfBtn = recruiterSelfBtn

    -- 3. CAMPO: ANIVERSÁRIO
    local birthdayLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    birthdayLabel:SetPoint("TOPLEFT", recruiterEB, "BOTTOMLEFT", 0, -10)
    birthdayLabel:SetText("|cffffd200" .. L["EDIT_BIRTHDAY_LABEL"] .. "|r")
    modal.birthdayLabel = birthdayLabel

    local birthdayEB = CreateFrame("EditBox", nil, modal, template)
    birthdayEB:SetPoint("TOPLEFT", birthdayLabel, "BOTTOMLEFT", 0, -4)
    birthdayEB:SetSize(160, 24)
    styleModalBox(birthdayEB)
    modal.birthdayEB = birthdayEB

    local birthdayHint = modal:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    birthdayHint:SetPoint("LEFT", birthdayEB, "RIGHT", 8, 0)
    birthdayHint:SetText("|cff888888Exemplo: 15/07|r")

    -- CAMPO: FUNÇÃO / ROLE
    local roleModalLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    roleModalLabel:SetPoint("TOPLEFT", birthdayEB, "BOTTOMLEFT", 0, -10)
    roleModalLabel:SetText("|cffffd200" .. (L["EDIT_ROLE_LABEL"] or "Função / Role:") .. "|r")
    modal.roleLabel = roleModalLabel

    local roleBtnDefs = {
        { id = "TANK",   text = "TANK",   color = { 0.29, 0.56, 0.88 } },
        { id = "HEALER", text = "HEALER", color = { 0.18, 0.80, 0.44 } },
        { id = "DPS",    text = "DPS",    color = { 0.91, 0.30, 0.24 } },
    }
    modal.roleButtons = {}
    for i, rDef in ipairs(roleBtnDefs) do
        local rBtn = CreateFrame("Button", nil, modal, BackdropTemplateMixin and "BackdropTemplate" or nil)
        rBtn:SetPoint("TOPLEFT", roleModalLabel, "BOTTOMLEFT", (i - 1) * 88, -4)
        rBtn:SetSize(82, 22)
        if rBtn.SetBackdrop then
            rBtn:SetBackdrop(SUB_CONTAINER_BACKDROP)
            rBtn:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.9)
            rBtn:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.8)
        end

        local t = rBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t:SetPoint("CENTER", rBtn, "CENTER", 0, 0)
        t:SetText(rDef.text)
        rBtn.text = t
        rBtn.rDef = rDef

        rBtn:SetScript("OnClick", function()
            modal.selectedRole = rDef.id
            self:updateModalRoleButtons(modal.selectedRole)
        end)
        modal.roleButtons[rDef.id] = rBtn
    end

    -- 4. CAMPO: NOTA INTERNA
    local customNoteLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    customNoteLabel:SetPoint("TOPLEFT", modal.roleButtons["TANK"], "BOTTOMLEFT", 0, -10)
    customNoteLabel:SetText("|cffffd200" .. L["EDIT_CUSTOM_NOTE_LABEL"] .. "|r")
    modal.customNoteLabel = customNoteLabel

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
    saveBtn:SetText(L["SAVE"])
    saveBtn:SetScript("OnClick", function()
        self:saveModalChanges()
    end)
    modal.saveBtn = saveBtn

    -- Botão Cancelar
    local cancelBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    cancelBtn:SetSize(90, 24)
    cancelBtn:SetPoint("RIGHT", saveBtn, "LEFT", -8, 0)
    cancelBtn:SetText(L["CANCEL"])
    cancelBtn:SetScript("OnClick", function()
        modal:Hide()
    end)
    modal.cancelBtn = cancelBtn

    self._editModal = modal
end

--- Abre a modal de edição para um determinado membro e foca no campo especificado.
---@param member Member
---@param fieldToFocus string|nil @"dateJoin"|"recruiter"|"birthday"|"customNote"
--- Atualiza o estado visual dos botões de Role na modal de edição.
---@param activeRole string|nil
function AuditView:updateModalRoleButtons(activeRole)
    local modal = self._editModal
    if not modal or not modal.roleButtons then return end
    for rId, btn in pairs(modal.roleButtons) do
        local isActive = (rId == activeRole)
        if isActive then
            local color = btn.rDef.color
            if btn.SetBackdropBorderColor then
                btn:SetBackdropBorderColor(color[1], color[2], color[3], 1.0)
                btn:SetBackdropColor(color[1] * 0.25, color[2] * 0.25, color[3] * 0.25, 0.95)
            end
            btn.text:SetTextColor(color[1], color[2], color[3])
        else
            if btn.SetBackdropBorderColor then
                btn:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.8)
                btn:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.9)
            end
            btn.text:SetTextColor(0.7, 0.7, 0.7)
        end
    end
end

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
    modal.selectedRole = (member.getRole and member:getRole() or ""):upper()
    self:updateModalRoleButtons(modal.selectedRole)

    local canOfficer = false
    if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
        canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
    elseif IsGuildLeader and IsGuildLeader() then
        canOfficer = true
    elseif CanEditOfficerNote and CanEditOfficerNote() then
        canOfficer = true
    end

    if modal.dateJoinEB then
        modal.dateJoinEB:EnableMouse(true)
        if canOfficer then
            modal.dateJoinEB:SetTextColor(1, 1, 1)
        else
            modal.dateJoinEB:ClearFocus()
            modal.dateJoinEB:SetTextColor(0.55, 0.55, 0.55)
        end
    end

    if modal.dateJoinTodayBtn then
        modal.dateJoinTodayBtn:EnableMouse(true)
        if canOfficer then
            modal.dateJoinTodayBtn:SetAlpha(1.0)
        else
            modal.dateJoinTodayBtn:SetAlpha(0.55)
        end
    end

    if modal.recruiterEB then
        modal.recruiterEB:EnableMouse(true)
        if canOfficer then
            modal.recruiterEB:SetTextColor(1, 1, 1)
        else
            modal.recruiterEB:ClearFocus()
            modal.recruiterEB:SetTextColor(0.55, 0.55, 0.55)
        end
    end

    if modal.recruiterSelfBtn then
        modal.recruiterSelfBtn:EnableMouse(true)
        if canOfficer then
            modal.recruiterSelfBtn:SetAlpha(1.0)
        else
            modal.recruiterSelfBtn:SetAlpha(0.55)
        end
    end

    modal:Show()

    -- Foca automaticamente no campo que foi clicado (se o usuário não puder editar dateJoin/recruiter, foca no aniversário)
    if (fieldToFocus == "dateJoin" or fieldToFocus == "recruiter") and not canOfficer then
        fieldToFocus = "birthday"
    end

    if fieldToFocus == "dateJoin" and canOfficer then
        modal.dateJoinEB:SetFocus()
        modal.dateJoinEB:HighlightText()
    elseif fieldToFocus == "recruiter" and canOfficer then
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

    local canOfficer = false
    if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
        canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
    elseif IsGuildLeader and IsGuildLeader() then
        canOfficer = true
    elseif CanEditOfficerNote and CanEditOfficerNote() then
        canOfficer = true
    end

    local origDateJoin = member:getDateJoin() or ""
    local origRecruiter = member:getRecruiter() or ""

    local newDateJoin = origDateJoin
    if canOfficer then
        newDateJoin = (modal.dateJoinEB:GetText() or ""):match("^%s*(.-)%s*$") or ""
    end

    local newRecruiter = origRecruiter
    if canOfficer then
        newRecruiter = (modal.recruiterEB:GetText() or ""):match("^%s*(.-)%s*$") or ""
    end

    local newBirthday = (modal.birthdayEB:GetText() or ""):match("^%s*(.-)%s*$") or ""
    local newCustomNote = (modal.customNoteEB:GetText() or ""):match("^%s*(.-)%s*$") or ""

    local fields = {
        dateJoin = newDateJoin,
        recruiter = newRecruiter,
        birthday = newBirthday,
        customNote = newCustomNote,
        role = modal.selectedRole or "",
    }

    if self._onSaveCallback then
        self._onSaveCallback(member, fields)
    else
        if canOfficer then
            member:setDateJoin(newDateJoin)
            local oldRec = member:getRecruiter() or ""
            member:setRecruiter(newRecruiter)

            if oldRec ~= newRecruiter and _G.GM and _G.GM.logService and _G.GM.logService.updateRecruiterForMember then
                _G.GM.logService:updateRecruiterForMember(member:getName(), newRecruiter)
            end
        end

        member:setBirthday(newBirthday)
        member:setCustomNote(newCustomNote)
        if modal.selectedRole and modal.selectedRole ~= "" then member:setRole(modal.selectedRole) end

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
    local insetWidth = self._tableInset and self._tableInset:GetWidth() or 812
    if insetWidth <= 0 then insetWidth = 812 end
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
    local isOfficer = self:isPlayerOfficerOrLeader()
    for tabId, btn in pairs(self._filterButtons) do
        local isActive = (tabId == self._activeFilter)
        local isRestricted = (tabId == "NO_OFFICER_NOTE" and not isOfficer)
        local bg = isActive and PALETTE.ACTIVE_TAB_BG or PALETTE.INACTIVE_TAB_BG
        local border = isActive and PALETTE.ACTIVE_TAB_BORDER or PALETTE.INACTIVE_TAB_BORDER

        if btn.SetBackdrop then
            btn:SetBackdrop(SUB_CONTAINER_BACKDROP)
            btn:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
            btn:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
        end

        if btn.text then
            if isRestricted then
                btn:SetAlpha(0.4)
                btn.text:SetTextColor(0.55, 0.55, 0.55)
            else
                btn:SetAlpha(1.0)
                if isActive then
                    btn.text:SetTextColor(1.0, 0.85, 0.20)
                else
                    btn.text:SetTextColor(0.80, 0.80, 0.80)
                end
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
--- Ex-membros (isInGuild == false) ou sem cargo válido são rigorosamente ignorados.
---@param members Member[]
function AuditView:setMembers(members)
    local activeOnly = {}
    for _, m in ipairs(members or {}) do
        local rName = m and m:getRankName() or ""
        if m and m:isInGuild() and rName ~= "" and rName ~= "-" then
            table.insert(activeOnly, m)
        end
    end
    self._members = activeOnly
    self:rebuildFlatRows()
    self:applyFilters()
    self:renderGuildStats()
end

--- Reconstrói a estrutura hierárquica plana de linhas (Mains seguidos de seus respectivos Alts).
--- Garante que cada membro pertença a exatamente um grupo e elimina qualquer duplicação.
function AuditView:rebuildFlatRows()
    -- 1. Indexa membros ativos únicos da guilda
    local memberByName = {}
    local uniqueMembers = {}
    for _, m in ipairs(self._members or {}) do
        local nLower = (m:getName() or ""):lower()
        if nLower ~= "" and not memberByName[nLower] then
            memberByName[nLower] = m
            table.insert(uniqueMembers, m)
        end
    end

    -- 2. Constrói grafo de conexões de alts (bidirecional e simétrico)
    local adj = {}
    for _, m in ipairs(uniqueMembers) do
        local mLower = (m:getName() or ""):lower()
        adj[mLower] = adj[mLower] or {}

        -- Conexões diretas da entidade Member
        for _, altName in ipairs(m:getAlts() or {}) do
            local aLower = (altName or ""):lower()
            if aLower ~= "" and aLower ~= mLower and memberByName[aLower] then
                adj[mLower][aLower] = true
                adj[aLower] = adj[aLower] or {}
                adj[aLower][mLower] = true
            end
        end

        -- Conexões de família registradas no serviço
        if _G.GM and _G.GM.memberService and _G.GM.memberService.getAltFamily then
            local fam = _G.GM.memberService:getAltFamily(m)
            if fam then
                for _, famM in ipairs(fam) do
                    local fLower = (famM:getName() or ""):lower()
                    if fLower ~= "" and fLower ~= mLower and memberByName[fLower] then
                        adj[mLower][fLower] = true
                        adj[fLower] = adj[fLower] or {}
                        adj[fLower][mLower] = true
                    end
                end
            end
        end
    end

    -- 3. Identifica famílias completas via busca em largura (BFS) sem sobreposições
    local visited = {}
    local mainGroups = {}

    for _, m in ipairs(uniqueMembers) do
        local mLower = (m:getName() or ""):lower()
        if not visited[mLower] then
            local component = {}
            local queue = { mLower }
            visited[mLower] = true

            while #queue > 0 do
                local curr = table.remove(queue, 1)
                local mem = memberByName[curr]
                if mem then
                    table.insert(component, mem)
                end

                if adj[curr] then
                    for neighbor, _ in pairs(adj[curr]) do
                        if not visited[neighbor] then
                            visited[neighbor] = true
                            table.insert(queue, neighbor)
                        end
                    end
                end
            end

            -- Determina quem é o Main da família e separa os Alts
            local mainMember = nil
            local altMembers = {}

            for _, mem in ipairs(component) do
                if mem:isMain() then
                    if not mainMember then
                        mainMember = mem
                    else
                        -- Se mais de um estiver com flag isMain, desempata pelo cargo de maior prestígio ou nível
                        local curRank = mem:getRankIndex() or 99
                        local mainRank = mainMember:getRankIndex() or 99
                        if curRank < mainRank or (curRank == mainRank and (mem:getLevel() or 0) > (mainMember:getLevel() or 0)) then
                            table.insert(altMembers, mainMember)
                            mainMember = mem
                        else
                            table.insert(altMembers, mem)
                        end
                    end
                else
                    table.insert(altMembers, mem)
                end
            end

            -- Se nenhum estiver explicitamente marcado como isMain, elege o de maior nível / rank
            if not mainMember then
                table.sort(altMembers, function(a, b)
                    local lvlA = a:getLevel() or 0
                    local lvlB = b:getLevel() or 0
                    if lvlA ~= lvlB then return lvlA > lvlB end
                    local rA = a:getRankIndex() or 99
                    local rB = b:getRankIndex() or 99
                    if rA ~= rB then return rA < rB end
                    return normalizeForSort(a:getName()) < normalizeForSort(b:getName())
                end)
                mainMember = table.remove(altMembers, 1)
            end

            -- Ordena os alts do grupo por nível decrescente e nome
            table.sort(altMembers, function(a, b)
                local lvlA = a:getLevel() or 0
                local lvlB = b:getLevel() or 0
                if lvlA ~= lvlB then return lvlA > lvlB end
                return normalizeForSort(a:getName()) < normalizeForSort(b:getName())
            end)

            table.insert(mainGroups, {
                main = mainMember,
                alts = altMembers,
            })
        end
    end

    -- Ordena os grupos principais por Rank na guilda (Guild Master -> Oficiais -> Membros) e depois por Nome normalizado
    table.sort(mainGroups, function(a, b)
        local rankA = a.main:getRankIndex() or 99
        local rankB = b.main:getRankIndex() or 99
        if rankA ~= rankB then
            return rankA < rankB
        end
        return normalizeForSort(a.main:getName()) < normalizeForSort(b.main:getName())
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
    local isOfficer = self:isPlayerOfficerOrLeader()

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
            if not isOfficer then
                matchFilter = false
            else
                local on = m:getOfficerNote() or ""
                matchFilter = (on == "")
            end
        elseif filter == "NO_CUSTOM_NOTE" then
            local cn = m:getCustomNote() or ""
            matchFilter = (cn == "")
        end

        if matchFilter and _G.GM_DB and _G.GM_DB.settings and _G.GM_DB.settings.showOfflineMembers == false then
            if not m:isOnline() then
                matchFilter = false
            end
        end

        if matchFilter and search ~= "" then
            local normSearch = normalizeForSort(search)
            local name = (m:getName() or ""):lower()
            local normName = normalizeForSort(name)
            local rank = (m:getRankName() or ""):lower()
            local onlineStatus = m:isOnline() and "online" or (m:getLastOnline() or "offline"):lower()
            local pubNote = (m:getPublicNote() or ""):lower()
            local offNote = isOfficer and (m:getOfficerNote() or ""):lower() or ""
            local custNote = (m:getCustomNote() or ""):lower()
            local rec = (m:getRecruiter() or ""):lower()
            local normRec = normalizeForSort(rec)
            local dateJoin = (m:getDateJoin() or ""):lower()
            local bday = (m:getBirthday() or ""):lower()

            if not (name:find(search, 1, true) or normName:find(normSearch, 1, true) or
                    rank:find(search, 1, true) or
                    onlineStatus:find(search, 1, true) or
                    pubNote:find(search, 1, true) or offNote:find(search, 1, true) or
                    custNote:find(search, 1, true) or rec:find(search, 1, true) or normRec:find(normSearch, 1, true) or
                    dateJoin:find(search, 1, true) or bday:find(search, 1, true)) then
                matchFilter = false
            end
        end

        if matchFilter then
            table.insert(self._filteredRows, rowData)
        end
    end

    local currentPage, totalPages, startIndex, endIndex, pageCount, total = self:getPageInfo()
    local maxOffset = math.max(0, pageCount - self._numVisibleRows)

    if self._offset > maxOffset then
        self._offset = maxOffset
    end
    if self._offset < 0 then
        self._offset = 0
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
            "|cffaaaaaaTotal na guilda: %d membros (%d Mains, %d Alts)|r",
            #self._members, self._totalMainsCount or 0, self._totalAltsCount or 0
        ))
    end

    self:updateScrollDimensions()
    self:renderRows()
end

--- Renderiza as linhas visíveis na tabela com paginação (40 membros por página).
function AuditView:renderRows()
    local isOfficer = self:isPlayerOfficerOrLeader()
    local currentPage, totalPages, startIndex, endIndex, pageCount, total = self:getPageInfo()

    if total == 0 or pageCount == 0 then
        if self._emptyNotice then
            self._emptyNotice:Show()
        end
        for _, row in ipairs(self._rows) do
            row:Hide()
        end
        self:updatePaginationControls()
        return
    else
        if self._emptyNotice then
            self._emptyNotice:Hide()
        end
    end

    for i = 1, self._numVisibleRows do
        local dataIndex = startIndex - 1 + self._offset + i
        local row = self._rows[i]
        local rowData = (dataIndex <= endIndex) and self._filteredRows[dataIndex] or nil

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
                local branch = "|cff888888»|r"
                row.nameTxt:SetPoint("LEFT", row, "LEFT", 26, 0)
                row.nameTxt:SetText(string.format("%s |cff00e5ff[ALT]|r %s", branch, coloredName))
            end

            -- Coluna 2: Nível (Centralizado e nítido)
            local lvl = m:getLevel() or 1
            row.levelTxt:SetText(string.format("|cffffffff%d|r", lvl))

            -- Coluna Função / Role
            local roleVal = (m.getRole and m:getRole() or ""):upper()
            if roleVal == "TANK" then
                row.roleTxt:SetText("|cff4a90e2TANK|r")
            elseif roleVal == "HEALER" then
                row.roleTxt:SetText("|cff2ecc71HEALER|r")
            elseif roleVal == "DPS" then
                row.roleTxt:SetText("|cffe74c3cDPS|r")
            else
                row.roleTxt:SetText("|cff777777-|r")
            end

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

            -- Coluna 6: Nota de Oficial (Blizzard - Exclusiva para Oficiais e Líder)
            if isOfficer then
                local oNote = m:getOfficerNote()
                if oNote and oNote ~= "" then
                    row.officerNoteTxt:SetText("|cff80d0ff" .. oNote .. "|r")
                else
                    row.officerNoteTxt:SetText("|cff555555-|r")
                end
            else
                row.officerNoteTxt:SetText("|cffff4444SOMENTE OFICIAIS|r")
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

    self:updatePaginationControls()
end

--- Retorna os detalhes de paginação atuais (página atual, total de páginas, índices inicial e final).
---@return number currentPage
---@return number totalPages
---@return number startIndex
---@return number endIndex
---@return number pageCount
---@return number totalRows
function AuditView:getPageInfo()
    local totalRows = #self._filteredRows
    local pageSize = self._pageSize or 40
    local totalPages = math.max(1, math.ceil(totalRows / pageSize))
    local currentPage = math.max(1, math.min(self._currentPage or 1, totalPages))
    self._currentPage = currentPage

    local startIndex = 0
    local endIndex = 0
    local pageCount = 0

    if totalRows > 0 then
        startIndex = (currentPage - 1) * pageSize + 1
        endIndex = math.min(startIndex + pageSize - 1, totalRows)
        pageCount = math.max(0, endIndex - startIndex + 1)
    end

    return currentPage, totalPages, startIndex, endIndex, pageCount, totalRows
end

--- Atualiza o texto e o estado dos botões de navegação por página.
function AuditView:updatePaginationControls()
    if not self._paginationFrame then return end

    local currentPage, totalPages, startIndex, endIndex, pageCount, totalRows = self:getPageInfo()
    local isEn = (_G.GM and _G.GM.GetLocale and _G.GM.GetLocale() == "enUS")

    if self._pageText then
        if totalRows == 0 then
            self._pageText:SetText(isEn and "|cffffd200Page 1 of 1|r |cff888888(0)|r" or "|cffffd200Página 1 de 1|r |cff888888(0)|r")
        else
            if isEn then
                self._pageText:SetText(string.format("|cffffd200Page %d of %d|r  |cff888888(%d-%d of %d)|r", currentPage, totalPages, startIndex, endIndex, totalRows))
            else
                self._pageText:SetText(string.format("|cffffd200Página %d de %d|r  |cff888888(%d-%d de %d)|r", currentPage, totalPages, startIndex, endIndex, totalRows))
            end
        end
        local w = self._pageText:GetStringWidth() or 120
        self._pageText:SetWidth(w + 10)
    end

    local canPrev = (currentPage > 1)
    local canNext = (currentPage < totalPages)

    if self._firstPageBtn then
        if canPrev then self._firstPageBtn:Enable() else self._firstPageBtn:Disable() end
    end
    if self._prevPageBtn then
        if canPrev then self._prevPageBtn:Enable() else self._prevPageBtn:Disable() end
    end
    if self._nextPageBtn then
        if canNext then self._nextPageBtn:Enable() else self._nextPageBtn:Disable() end
    end
    if self._lastPageBtn then
        if canNext then self._lastPageBtn:Enable() else self._lastPageBtn:Disable() end
    end
end

--- Define a página atual da tabela de auditoria e atualiza a exibição.
---@param page number
function AuditView:setPage(page)
    local _, totalPages = self:getPageInfo()
    local targetPage = math.max(1, math.min(page, totalPages))
    if targetPage ~= self._currentPage or self._offset ~= 0 then
        self._currentPage = targetPage
        self._offset = 0
        if self._scrollBar then
            self._scrollBar:SetValue(0)
        end
        self:applyFilters()
    end
end

--- Avança para a próxima página.
function AuditView:nextPage()
    self:setPage((self._currentPage or 1) + 1)
end

--- Retorna para a página anterior.
function AuditView:prevPage()
    self:setPage((self._currentPage or 1) - 1)
end

--- Vai para a primeira página.
function AuditView:firstPage()
    self:setPage(1)
end

--- Vai para a última página.
function AuditView:lastPage()
    local _, totalPages = self:getPageInfo()
    self:setPage(totalPages)
end

--- Controla o scroll vertical da tabela via roda do mouse ou botões de seta dentro da página atual.
---@param delta number
function AuditView:scroll(delta)
    local currentPage, totalPages, startIndex, endIndex, pageCount = self:getPageInfo()
    local maxOffset = math.max(0, pageCount - self._numVisibleRows)
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
        self:updateLocale()
        self:updateFilterButtonsVisual()
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

--- Atualiza dinamicamente os textos da interface após mudança de idioma.
function AuditView:updateLocale()
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    if not self._frame then return end

    if self._titleText then
        self._titleText:SetText(curL["AUDIT_TITLE"] or "|cffffd200AUDITORIA DE MEMBROS DA GUILDA|r")
    end
    if self._subtitleText then
        self._subtitleText:SetText(curL["AUDIT_SUBTITLE"] or "|cffaaaaaa(Dados Blizzard + Gestão de Entrada, Recrutador, Aniversário e Notas)|r")
    end
    if self._searchEB and self._searchEB.hint then
        self._searchEB.hint:SetText("|cff888888" .. (curL["AUDIT_SEARCH_HINT"] or "Buscar...") .. "|r")
    end
    if self._syncBtn and self._syncBtn.text then
        self._syncBtn.text:SetText("|cffffd200" .. (curL["SYNC_P2P_BTN"] or "Sincronizar P2P") .. "|r")
    end
    if self._refreshBtn then
        self._refreshBtn:SetText(curL["REFRESH"] or "Atualizar")
    end
    if self._emptyNotice then
        self._emptyNotice:SetText(curL["AUDIT_EMPTY_NOTICE"] or "Nenhum membro encontrado nos critérios selecionados.")
    end

    -- Atualiza colunas do cabeçalho
    if self._colHeaderStrings then
        for _, col in ipairs(COLUMNS) do
            local fs = self._colHeaderStrings[col.id]
            if fs then
                local colKey = "COL_" .. col.id:upper()
                local title = curL[colKey]
                if not title or title == colKey then
                    local isEn = (_G.GM and _G.GM.GetLocale and _G.GM.GetLocale() == "enUS") or (GetLocale and GetLocale() ~= "ptBR")
                    if col.id == "role" then
                        title = isEn and "ROLE" or "FUNÇÃO"
                    else
                        title = col.title
                    end
                end
                if col.editable then
                    fs:SetText(string.format("|cffffd200%s|r |cff00ff99*|r", title))
                else
                    fs:SetText(string.format("|cffffd200%s|r", title))
                end
            end
        end
    end

    -- Atualiza botões de filtro rápido
    local filterKeys = {
        ALL = "FILTER_ALL",
        ONLINE = "FILTER_ONLINE",
        MAINS = "FILTER_MAINS",
        WITH_ALTS = "FILTER_WITH_ALTS",
        NO_RECRUITER = "FILTER_NO_RECRUITER",
        NO_OFFICER_NOTE = "FILTER_NO_OFFICER_NOTE",
        NO_CUSTOM_NOTE = "FILTER_NO_CUSTOM_NOTE",
    }
    if self._filterButtons then
        for tabId, btn in pairs(self._filterButtons) do
            local key = filterKeys[tabId]
            if key and btn.text then
                btn.text:SetText(curL[key] or tabId)
                local textWidth = btn.text:GetStringWidth() or 40
                btn:SetWidth(textWidth + 12)
            end
        end
    end

    -- Atualiza modal de edição se existir
    if self._editModal then
        if self._editModal.titleText then self._editModal.titleText:SetText(curL["EDIT_MODAL_TITLE"] or "Editar Informações do Membro") end
        if self._editModal.dateJoinLabel then self._editModal.dateJoinLabel:SetText("|cffffd200" .. (curL["EDIT_JOIN_DATE_LABEL"] or "Data de Entrada:") .. "|r") end
        if self._editModal.recruiterLabel then self._editModal.recruiterLabel:SetText("|cffffd200" .. (curL["EDIT_RECRUITER_LABEL"] or "Recrutador:") .. "|r") end
        if self._editModal.birthdayLabel then self._editModal.birthdayLabel:SetText("|cffffd200" .. (curL["EDIT_BIRTHDAY_LABEL"] or "Aniversário:") .. "|r") end
        if self._editModal.roleLabel then self._editModal.roleLabel:SetText("|cffffd200" .. (curL["EDIT_ROLE_LABEL"] or "Função:") .. "|r") end
        if self._editModal.customNoteLabel then self._editModal.customNoteLabel:SetText("|cffffd200" .. (curL["EDIT_CUSTOM_NOTE_LABEL"] or "Nota Interna:") .. "|r") end
        if self._editModal.saveBtn then self._editModal.saveBtn:SetText(curL["SAVE"] or "Salvar") end
        if self._editModal.cancelBtn then self._editModal.cancelBtn:SetText(curL["CANCEL"] or "Cancelar") end
    end

    -- Atualiza rodapé
    if self._footerText and self._members then
        self._footerText:SetText(string.format(
            "|cffaaaaaaTotal na guilda: %d membros (%d Mains, %d Alts)|r",
            #self._members, self._totalMainsCount or 0, self._totalAltsCount or 0
        ))
    end

    -- Re-renderiza linhas visíveis
    if self.renderRows then
        self:renderRows()
    end
    if self.renderGuildStats then
        self:renderGuildStats()
    end
end

--- Retorna o frame principal da janela de auditoria.
---@return table
function AuditView:getFrame()
    return self._frame
end

--- Verifica se a janela de auditoria está aberta.
---@return boolean
function AuditView:isShown()
    return self._frame and self._frame:IsShown() or false
end

-- Exportação/Alias de compatibilidade
auditView = AuditView


--- Obtém ou cria um cabeçalho de seção no painel de estatísticas.
---@param index number
---@return table
function AuditView:getStatsHeader(index)
    self._statsHeaderPool = self._statsHeaderPool or {}
    local h = self._statsHeaderPool[index]
    if not h then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        h = CreateFrame("Frame", nil, self._statsContent, template)
        h:SetSize(STATS_PANEL_WIDTH - 24, 20)

        local bg = h:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(h)
        bg:SetColorTexture(PALETTE.HEADER_ROW_BG[1], PALETTE.HEADER_ROW_BG[2], PALETTE.HEADER_ROW_BG[3], 0.75)
        h.bg = bg

        local bar = h:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("LEFT", h, "LEFT", 0, 0)
        bar:SetSize(3, 16)
        bar:SetColorTexture(0.95, 0.70, 0.25, 1.0)
        h.bar = bar

        local txt = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetPoint("LEFT", bar, "RIGHT", 6, 0)
        txt:SetJustifyH("LEFT")
        h.txt = txt

        self._statsHeaderPool[index] = h
    end
    h:Show()
    return h
end

--- Obtém ou cria uma linha de dado no painel de estatísticas.
---@param index number
---@return table
function AuditView:getStatsRow(index)
    self._statsRowPool = self._statsRowPool or {}
    local row = self._statsRowPool[index]
    if not row then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        row = CreateFrame("Button", nil, self._statsContent, template)
        row:SetSize(STATS_PANEL_WIDTH - 24, 18)

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(row)
        hl:SetColorTexture(PALETTE.CELL_HOVER_BG[1], PALETTE.CELL_HOVER_BG[2], PALETTE.CELL_HOVER_BG[3], 0.25)
        row:SetHighlightTexture(hl)

        local dot = row:CreateTexture(nil, "ARTWORK")
        dot:SetPoint("LEFT", row, "LEFT", 4, 0)
        dot:SetSize(6, 6)
        dot:SetColorTexture(0.8, 0.8, 0.8, 1.0)
        row.dot = dot

        local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameTxt:SetPoint("LEFT", dot, "RIGHT", 5, 0)
        nameTxt:SetPoint("RIGHT", row, "RIGHT", -60, 0)
        nameTxt:SetJustifyH("LEFT")
        nameTxt:SetWordWrap(false)
        row.nameTxt = nameTxt

        local countTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        countTxt:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        countTxt:SetJustifyH("RIGHT")
        row.countTxt = countTxt

        row:SetScript("OnEnter", function(btn)
            if btn.tooltipData and GameTooltip then
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                GameTooltip:AddLine(btn.tooltipData.title, 1, 0.82, 0)
                if btn.tooltipData.subtitle then
                    GameTooltip:AddLine(btn.tooltipData.subtitle, 0.7, 0.7, 0.7, true)
                end
                if btn.tooltipData.members and #btn.tooltipData.members > 0 then
                    GameTooltip:AddLine(" ")
                    local header = btn.tooltipData.header or (btn.tooltipData.isEn and "Members:" or "Membros:")
                    GameTooltip:AddLine(string.format("|cffffd200%s (%d)|r", header, #btn.tooltipData.members))
                    local maxShow = 25
                    for i, info in ipairs(btn.tooltipData.members) do
                        if i > maxShow then
                            local rem = #btn.tooltipData.members - maxShow
                            GameTooltip:AddLine(string.format("|cffaaaaaa... e mais %d membros|r", rem), 0.7, 0.7, 0.7)
                            break
                        end
                        local mName = info.name or (info.member and info.member.getName and info.member:getName()) or ""
                        local mGuid = info.guid or (info.member and info.member.getGuid and info.member:getGuid())
                        local mClass = info.class or (info.member and info.member.getClass and info.member:getClass())
                        local colName = self:formatColoredName(mName, mGuid, mClass)
                        if info.detail and info.detail ~= "" then
                            GameTooltip:AddLine(string.format("  • %s |cffaaaaaa(%s)|r", colName, info.detail), 0.85, 0.85, 0.85)
                        else
                            GameTooltip:AddLine(string.format("  • %s", colName), 0.85, 0.85, 0.85)
                        end
                    end
                else
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cff888888" .. (btn.tooltipData.isEn and "No members in this category." or "Nenhum membro nesta categoria.") .. "|r", 0.6, 0.6, 0.6)
                end
                if btn.filterQuery and btn.filterQuery ~= "" then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cff00ff00" .. (btn.tooltipData.isEn and "Click to filter in table" or "Clique para filtrar na tabela") .. "|r", 0.2, 1.0, 0.2)
                end
                GameTooltip:Show()
            end
        end)

        row:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)

        row:SetScript("OnClick", function(btn)
            if btn.filterQuery and btn.filterQuery ~= "" and self._searchEB then
                local cur = self._searchEB:GetText() or ""
                if cur == btn.filterQuery then
                    self._searchEB:SetText("")
                else
                    self._searchEB:SetText(btn.filterQuery)
                end
            end
        end)

        self._statsRowPool[index] = row
    end
    row:Show()
    return row
end

--- Renderiza e atualiza todas as seções de estatísticas da guilda na barra lateral esquerda.
function AuditView:renderGuildStats()
    if not self._statsContent then return end

    local isEn = (_G.GM and _G.GM.GetLocale and _G.GM.GetLocale() == "enUS") or (GetLocale and GetLocale() ~= "ptBR")
    local curL = (_G.GM and _G.GM.L) or _G.L or L

    if self._statsTitle then
        self._statsTitle:SetText("|cffffd200" .. (curL["STATS_TITLE"] or (isEn and "GUILD STATS" or "ESTATÍSTICAS DA GUILDA")) .. "|r")
    end

    local members = self._members or {}
    local total = #members

    if self._statsMemberCount then
        self._statsMemberCount:SetText(string.format("|cffffffff%d|r |cffaaaaaa%s|r", total, isEn and "members" or "membros"))
    end

    -- Esconde linhas e cabeçalhos anteriores
    if self._statsHeaderPool then
        for _, h in pairs(self._statsHeaderPool) do h:Hide() end
    end
    if self._statsRowPool then
        for _, r in pairs(self._statsRowPool) do r:Hide() end
    end

    local headerIdx = 0
    local rowIdx = 0
    local currentY = 2

    local function addHeader(titleText)
        headerIdx = headerIdx + 1
        local h = self:getStatsHeader(headerIdx)
        h:SetPoint("TOPLEFT", self._statsContent, "TOPLEFT", 0, -currentY)
        h.txt:SetText(titleText)
        currentY = currentY + 22
    end

    local function addRow(dotColor, nameText, count, totalCount, tooltipData, filterQuery)
        rowIdx = rowIdx + 1
        local row = self:getStatsRow(rowIdx)
        row:SetPoint("TOPLEFT", self._statsContent, "TOPLEFT", 0, -currentY)
        if dotColor then
            row.dot:SetColorTexture(dotColor[1], dotColor[2], dotColor[3], 1.0)
            row.dot:Show()
            row.nameTxt:SetPoint("LEFT", row.dot, "RIGHT", 5, 0)
        else
            row.dot:Hide()
            row.nameTxt:SetPoint("LEFT", row, "LEFT", 4, 0)
        end
        row.nameTxt:SetText(nameText)
        local pct = totalCount > 0 and math.floor((count / totalCount) * 100 + 0.5) or 0
        if count > 0 then
            row.countTxt:SetText(string.format("|cffffffff%d|r |cff888888(%d%%)|r", count, pct))
        else
            row.countTxt:SetText("|cff6666660|r")
        end
        tooltipData.isEn = isEn
        row.tooltipData = tooltipData
        row.filterQuery = filterQuery
        currentY = currentY + 18
    end

    -- =========================================================================
    -- 1. FUNÇÕES / ROLES
    -- =========================================================================
    addHeader("|cffffd200" .. (curL["STATS_SECTION_ROLES"] or (isEn and "ROLES" or "FUNÇÕES")) .. "|r")
    local rolesDef = {
        { id = "TANK",   name = "TANK",   color = { 0.29, 0.56, 0.88 }, hex = "4a90e2" },
        { id = "HEALER", name = "HEALER", color = { 0.18, 0.80, 0.44 }, hex = "2ecc71" },
        { id = "DPS",    name = "DPS",    color = { 0.91, 0.30, 0.24 }, hex = "e74c3c" },
        { id = "NONE",   name = curL["STATS_UNASSIGNED"] or (isEn and "Unassigned" or "Sem Função"), color = { 0.55, 0.55, 0.55 }, hex = "888888" },
    }
    local roleMap = {
        TANK = { count = 0, members = {} },
        HEALER = { count = 0, members = {} },
        DPS = { count = 0, members = {} },
        NONE = { count = 0, members = {} },
    }
    for _, m in ipairs(members) do
        local r = (m.getRole and m:getRole() or ""):upper()
        if roleMap[r] then
            roleMap[r].count = roleMap[r].count + 1
            table.insert(roleMap[r].members, { name = m:getName(), guid = m:getGuid(), class = m:getClass(), detail = m:getClassDisplayName() })
        else
            roleMap.NONE.count = roleMap.NONE.count + 1
            table.insert(roleMap.NONE.members, { name = m:getName(), guid = m:getGuid(), class = m:getClass(), detail = m:getClassDisplayName() })
        end
    end
    for _, rDef in ipairs(rolesDef) do
        local data = roleMap[rDef.id]
        local tt = {
            title = string.format("Função: |cff%s%s|r", rDef.hex, rDef.name),
            subtitle = string.format("%d de %d membros na guilda", data.count, total),
            members = data.members,
            header = isEn and "Members with this role:" or "Membros com esta função:",
        }
        local fQuery = (rDef.id ~= "NONE") and rDef.name or ""
        addRow(rDef.color, string.format("|cff%s%s|r", rDef.hex, rDef.name), data.count, total, tt, fQuery)
    end
    currentY = currentY + 6

    -- =========================================================================
    -- 2. CLASSES
    -- =========================================================================
    addHeader("|cffffd200" .. (curL["STATS_SECTION_CLASSES"] or (isEn and "CLASSES" or "CLASSES")) .. "|r")
    local classNames = isEn and CLASS_NAMES_MAP.enUS or CLASS_NAMES_MAP.ptBR
    local classMap = {}
    for _, cKey in ipairs(ALL_CLASSES_ORDER) do
        classMap[cKey] = { key = cKey, name = classNames[cKey] or cKey, count = 0, members = {} }
    end
    for _, m in ipairs(members) do
        local cKey = (m.getClass and m:getClass() or ""):upper()
        if classMap[cKey] then
            classMap[cKey].count = classMap[cKey].count + 1
            local lvl = m.getLevel and m:getLevel() or 1
            local rank = m.getRankName and m:getRankName() or ""
            local dStr = (rank ~= "") and string.format("Lvl %d - %s", lvl, rank) or string.format("Lvl %d", lvl)
            table.insert(classMap[cKey].members, { name = m:getName(), guid = m:getGuid(), class = cKey, detail = dStr })
        end
    end
    local classList = {}
    for _, cKey in ipairs(ALL_CLASSES_ORDER) do
        table.insert(classList, classMap[cKey])
    end
    table.sort(classList, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    for _, c in ipairs(classList) do
        local hex = getClassColorHex(c.key) or "|cffffffff"
        local colorRgb = { 0.8, 0.8, 0.8 }
        if RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.key] then
            local rc = RAID_CLASS_COLORS[c.key]
            colorRgb = { rc.r or 0.8, rc.g or 0.8, rc.b or 0.8 }
        end
        local tt = {
            title = string.format("%s%s|r (%d)", hex, c.name, c.count),
            subtitle = string.format("%d de %d membros na guilda", c.count, total),
            members = c.members,
            header = isEn and "Guild members of this class:" or "Membros desta classe na guilda:",
        }
        addRow(colorRgb, string.format("%s%s|r", hex, c.name), c.count, total, tt, c.name)
    end
    currentY = currentY + 6

    -- =========================================================================
    -- 3. RAÇAS
    -- =========================================================================
    addHeader("|cffffd200" .. (curL["STATS_SECTION_RACES"] or (isEn and "RACES" or "RAÇAS")) .. "|r")
    local raceMap = {}
    for _, m in ipairs(members) do
        local rawRace = m.getRace and m:getRace() or ""
        local rName = normalizeRace(rawRace, isEn)
        if not raceMap[rName] then
            raceMap[rName] = { name = rName, count = 0, members = {} }
        end
        raceMap[rName].count = raceMap[rName].count + 1
        local cDisp = m.getClassDisplayName and m:getClassDisplayName() or m:getClass()
        local lvl = m.getLevel and m:getLevel() or 1
        table.insert(raceMap[rName].members, { name = m:getName(), guid = m:getGuid(), class = m:getClass(), detail = string.format("Lvl %d %s", lvl, cDisp) })
    end
    local raceList = {}
    for _, rData in pairs(raceMap) do
        table.insert(raceList, rData)
    end
    table.sort(raceList, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    for _, r in ipairs(raceList) do
        local tt = {
            title = string.format("|cffffffff%s|r (%d)", r.name, r.count),
            subtitle = string.format("%d de %d membros na guilda", r.count, total),
            members = r.members,
            header = isEn and "Guild members of this race:" or "Membros desta raça na guilda:",
        }
        addRow({ 0.85, 0.70, 0.40 }, string.format("|cffffffff%s|r", r.name), r.count, total, tt, r.name)
    end
    currentY = currentY + 6

    -- =========================================================================
    -- 4. PROFISSÕES
    -- =========================================================================
    addHeader("|cffffd200" .. (curL["STATS_SECTION_PROFESSIONS"] or (isEn and "PROFESSIONS" or "PROFISSÕES")) .. "|r")
    local profMap = {}
    for _, pDef in ipairs(PROFESSIONS_DEF) do
        profMap[pDef.key] = { key = pDef.key, name = isEn and pDef.nameEn or pDef.name, icon = pDef.icon, count = 0, members = {} }
    end
    for _, m in ipairs(members) do
        local mProfs = m.getProfessions and m:getProfessions()
        if type(mProfs) == "table" then
            for pKey, pData in pairs(mProfs) do
                local uKey = tostring(pKey):upper()
                if not profMap[uKey] then
                    profMap[uKey] = { key = uKey, name = uKey, icon = nil, count = 0, members = {} }
                end
                local rank = (type(pData) == "table" and pData.rank) or 0
                local maxRank = (type(pData) == "table" and pData.maxRank) or 300
                profMap[uKey].count = profMap[uKey].count + 1
                local det = (rank > 0) and string.format("%d/%d", rank, maxRank) or "Aprendiz"
                table.insert(profMap[uKey].members, { name = m:getName(), guid = m:getGuid(), class = m:getClass(), detail = det })
            end
        end
    end
    local profList = {}
    for _, pData in pairs(profMap) do
        table.insert(profList, pData)
    end
    table.sort(profList, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    for _, p in ipairs(profList) do
        if p.count > 0 or p.key == "ALCHEMY" or p.key == "TAILORING" or p.key == "LEATHERWORKING" or p.key == "ENCHANTING" or p.key == "BLACKSMITHING" or p.key == "ENGINEERING" then
            local tt = {
                title = string.format("|cffffffff%s|r (%d)", p.name, p.count),
                subtitle = string.format("%d artesão(ãos) com esta profissão na guilda", p.count),
                members = p.members,
                header = isEn and "Crafters in guild:" or "Artesãos na guilda:",
            }
            local color = (p.count > 0) and { 0.3, 0.9, 0.4 } or { 0.4, 0.4, 0.4 }
            local nameColor = (p.count > 0) and "|cffffffff" or "|cff888888"
            addRow(color, string.format("%s%s|r", nameColor, p.name), p.count, total, tt, (p.count > 0) and p.name or "")
        end
    end

    currentY = currentY + 14

    -- Ajusta altura do container de rolagem e limites do slider
    local minH = (self._statsScrollFrame and self._statsScrollFrame:GetHeight()) or 450
    self._statsContent:SetHeight(math.max(currentY, minH))
    if self._statsScrollBar then
        local maxScroll = math.max(0, currentY - minH)
        self._statsScrollBar:SetMinMaxValues(0, maxScroll)
        if maxScroll <= 0 then
            self._statsScrollBar:Hide()
        else
            self._statsScrollBar:Show()
        end
    end
end

