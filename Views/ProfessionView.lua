local addonName, addonTable = ...
local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })

---@class ProfessionView
---@field private _frame table|nil
ProfessionView = {}
ProfessionView.__index = ProfessionView

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

local SIDE_TAB_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

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
    ACTIVE_TAB_BG = { 0.20, 0.13, 0.05, 0.95 },
    ACTIVE_TAB_BORDER = { 0.95, 0.70, 0.25, 1.0 },
    INACTIVE_TAB_BG = { 0.045, 0.030, 0.012, 0.80 },
    INACTIVE_TAB_BORDER = { 0.50, 0.33, 0.12, 0.85 },
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

local REAGENT_NAMES_PT = {
    ["Light Leather"] = "Couro Leve",
    ["Medium Leather"] = "Couro Médio",
    ["Heavy Leather"] = "Couro Pesado",
    ["Thick Leather"] = "Couro Grosso",
    ["Rugged Leather"] = "Couro Rústico",
    ["Light Hide"] = "Pele Leve",
    ["Medium Hide"] = "Pele Média",
    ["Heavy Hide"] = "Pele Pesada",
    ["Thick Hide"] = "Pele Grossa",
    ["Rugged Hide"] = "Pele Rústica",
    ["Cured Light Hide"] = "Pele Leve Curada",
    ["Cured Medium Hide"] = "Pele Média Curada",
    ["Cured Heavy Hide"] = "Pele Pesada Curada",
    ["Cured Thick Hide"] = "Pele Grossa Curada",
    ["Cured Rugged Hide"] = "Pele Rústica Curada",
    ["Coarse Thread"] = "Linha Grossa",
    ["Fine Thread"] = "Linha Fina",
    ["Silken Thread"] = "Linha de Seda",
    ["Heavy Silken Thread"] = "Linha de Seda Pesada",
    ["Rune Thread"] = "Linha Rúnica",
    ["Linen Cloth"] = "Tecido de Linho",
    ["Wool Cloth"] = "Tecido de Lã",
    ["Silk Cloth"] = "Tecido de Seda",
    ["Mageweave Cloth"] = "Terramagia",
    ["Runecloth"] = "Etertrama",
    ["Felcloth"] = "Tecido Vil",
    ["Mooncloth"] = "Tecido Lunar",
    ["Bolt of Linen Cloth"] = "Rolo de Tecido de Linho",
    ["Bolt of Woolen Cloth"] = "Rolo de Tecido de Lã",
    ["Bolt of Silk Cloth"] = "Rolo de Tecido de Seda",
    ["Bolt of Mageweave"] = "Rolo de Terramagia",
    ["Bolt of Runecloth"] = "Rolo de Etertrama",
    ["Peacebloom"] = "Botão-de-paz",
    ["Silverleaf"] = "Folha-de-prata",
    ["Earthroot"] = "Raiz-telúrica",
    ["Mageroyal"] = "Magirreal",
    ["Briarthorn"] = "Espinhel",
    ["Bruiseweed"] = "Erva-dos-hematomas",
    ["Wild Steelbloom"] = "Flordaço Selvagem",
    ["Kingsblood"] = "Sangue-real",
    ["Grave Moss"] = "Musgo-de-túmulo",
    ["Fadeleaf"] = "Folha-etérea",
    ["Goldthorn"] = "Espinha-dourada",
    ["Khadgar's Whisker"] = "Bigode-de-hadgar",
    ["Wintersbite"] = "Mordida-do-inverno",
    ["Firebloom"] = "Flor-de-fogo",
    ["Purple Lotus"] = "Lótus Roxo",
    ["Arthas' Tears"] = "Lágrimas de Arthas",
    ["Sungrass"] = "Capim-do-sol",
    ["Blindweed"] = "Erva-cega",
    ["Ghost Mushroom"] = "Cogumelo Fantasma",
    ["Gromsblood"] = "Gromsanguina",
    ["Golden Sansam"] = "Sansam Dourado",
    ["Dreamfoil"] = "Sonífolia",
    ["Mountain Silversage"] = "Sálvia-prateada-da-montanha",
    ["Plaguebloom"] = "Flordapeste",
    ["Icecap"] = "Calota-de-gelo",
    ["Black Lotus"] = "Lótus Negro",
    ["Empty Vial"] = "Frasco Vazio",
    ["Leaded Vial"] = "Frasco de Chumbo",
    ["Crystal Vial"] = "Frasco de Cristal",
    ["Copper Bar"] = "Barra de Cobre",
    ["Bronze Bar"] = "Barra de Bronze",
    ["Iron Bar"] = "Barra de Ferro",
    ["Steel Bar"] = "Barra de Aço",
    ["Mithril Bar"] = "Barra de Mithril",
    ["Thorium Bar"] = "Barra de Tório",
    ["Dark Iron Bar"] = "Barra de Ferro Negro",
    ["Arcanite Bar"] = "Barra de Arcanita",
    ["Rough Stone"] = "Pedra Bruta",
    ["Coarse Stone"] = "Pedra Pesada",
    ["Heavy Stone"] = "Pedra Maciça",
    ["Solid Stone"] = "Pedra Sólida",
    ["Dense Stone"] = "Pedra Densa",
    ["Unstable Trigger"] = "Gatilho Instável",
    ["Solid Blasting Powder"] = "Pólvora Sólida",
    ["Heavy Blasting Powder"] = "Pólvora Pesada",
    ["Coarse Blasting Powder"] = "Pólvora Grossa",
    ["Rough Blasting Powder"] = "Pólvora Bruta",
    ["Strange Dust"] = "Pó Estranho",
    ["Soul Dust"] = "Pó da Alma",
    ["Vision Dust"] = "Pó da Visão",
    ["Dream Dust"] = "Pó dos Sonhos",
    ["Illusion Dust"] = "Pó da Ilusão",
    ["Lesser Magic Essence"] = "Essência Mágica Inferior",
    ["Greater Magic Essence"] = "Essência Mágica Superior",
    ["Lesser Astral Essence"] = "Essência Astral Inferior",
    ["Greater Astral Essence"] = "Essência Astral Superior",
    ["Lesser Mystic Essence"] = "Essência Mística Inferior",
    ["Greater Mystic Essence"] = "Essência Mística Superior",
    ["Lesser Nether Essence"] = "Essência Etérea Inferior",
    ["Greater Nether Essence"] = "Essência Etérea Superior",
    ["Lesser Eternal Essence"] = "Essência Eterna Inferior",
    ["Greater Eternal Essence"] = "Essência Eterna Superior",
    ["Small Glimmering Shard"] = "Estilhaço Tremeluzente Pequeno",
    ["Large Glimmering Shard"] = "Estilhaço Tremeluzente Grande",
    ["Small Glowing Shard"] = "Estilhaço Reluzente Pequeno",
    ["Large Glowing Shard"] = "Estilhaço Reluzente Grande",
    ["Small Radiant Shard"] = "Estilhaço Radiante Pequeno",
    ["Large Radiant Shard"] = "Estilhaço Radiante Grande",
    ["Small Brilliant Shard"] = "Estilhaço Brilhante Pequeno",
    ["Large Brilliant Shard"] = "Estilhaço Brilhante Grande",
    ["Nexus Crystal"] = "Cristal do Nexus",
    ["Righteous Orb"] = "Orbe da Virtude",
}

--- Normaliza o nome do jogador removendo o reino e espaços
---@param name string|nil
---@return string
local function cleanPlayerName(name)
    if not name or name == "" then return "" end
    local clean = name:match("^[^-]+") or name
    return clean:match("^%s*(.-)%s*$") or clean
end

--- Retorna o nome do reagente localizado em português se disponível
---@param name string|nil
---@return string
function ProfessionView:getReagentLocalizedName(name)
    if not name or name == "" then return "" end
    return REAGENT_NAMES_PT[name] or name
end

--- Construtor da View de Profissões e Pedidos
---@return ProfessionView
function ProfessionView:new()
    local instance = setmetatable({}, self)

    instance._frame = nil
    instance._currentSubTab = "BROWSER" -- "BROWSER", "ORDERS", "MY_PROFS"
    instance._selectedProfKey = "ALCHEMY"
    instance._selectedRecipe = nil
    instance._recipeSearchText = ""
    instance._onlyGuildCrafters = false
    instance._orderFilter = "ALL" -- "ALL", "MINE", "FOR_ME"

    instance._profButtons = {}
    instance._recipeRows = {}
    instance._recipeOffset = 0
    instance._filteredRecipes = {}
    instance._crafterRows = {}

    instance._orderRows = {}
    instance._orderOffset = 0
    instance._filteredOrders = {}
    instance._modalSuggestRows = {}
    instance._modalSuggestFrame = nil

    instance._onCreateOrderCallback = nil
    instance._onAcceptOrderCallback = nil
    instance._onCompleteOrderCallback = nil
    instance._onCancelOrderCallback = nil
    instance._onScanProfessionsCallback = nil

    instance:createUI()

    return instance
end

--- Retorna a referência do frame principal
---@return table|nil
function ProfessionView:getFrame()
    return self._frame
end

--- Verifica se a janela está visível
---@return boolean
function ProfessionView:isShown()
    return self._frame and self._frame:IsShown()
end

--- Exibe a janela
function ProfessionView:show()
    if not self._frame then self:createUI() end
    self._frame:Show()
    self:updateLocale()
    self:refresh()
end

--- Oculta a janela
function ProfessionView:hide()
    if self._frame then
        self._frame:Hide()
    end
end

--- Alterna a visibilidade da janela
function ProfessionView:toggle()
    if self:isShown() then
        self:hide()
    else
        self:show()
    end
end

-- Callbacks
function ProfessionView:setOnCreateOrderCallback(cb) self._onCreateOrderCallback = cb end
function ProfessionView:setOnAcceptOrderCallback(cb) self._onAcceptOrderCallback = cb end
function ProfessionView:setOnCompleteOrderCallback(cb) self._onCompleteOrderCallback = cb end
function ProfessionView:setOnCancelOrderCallback(cb) self._onCancelOrderCallback = cb end
function ProfessionView:setOnScanProfessionsCallback(cb) self._onScanProfessionsCallback = cb end

--- Atualiza textos e traduções em tempo real
function ProfessionView:updateLocale()
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    if self._titleText then self._titleText:SetText(curL["PROF_VIEW_TITLE"] or "PEDIDOS DE PROFISSÃO & ARTESÃOS DA GUILDA") end
    if self._subtitleText then self._subtitleText:SetText(curL["PROF_VIEW_SUBTITLE"] or "Consulte todas as receitas do jogo, veja quem fabrica na guilda e faça seus pedidos") end

    if self._subTabBtns then
        if self._subTabBtns["BROWSER"] and self._subTabBtns["BROWSER"].text then
            self._subTabBtns["BROWSER"].text:SetText(curL["PROF_SUBTAB_BROWSER"] or "Profissões & Receitas")
        end
        if self._subTabBtns["ORDERS"] and self._subTabBtns["ORDERS"].text then
            self._subTabBtns["ORDERS"].text:SetText(curL["PROF_SUBTAB_ORDERS"] or "Mural de Pedidos")
        end
        if self._subTabBtns["MY_PROFS"] and self._subTabBtns["MY_PROFS"].text then
            self._subTabBtns["MY_PROFS"].text:SetText(curL["PROF_SUBTAB_MY_PROFS"] or "Minhas Profissões")
        end
    end

    if self._searchBox and self._searchBox:GetText() == "" and self._searchPlaceholder then
        self._searchPlaceholder:SetText(curL["PROF_SEARCH_PLACEHOLDER"] or "Buscar receita ou item...")
    end

    if self._cbOnlyGuildText then
        self._cbOnlyGuildText:SetText(curL["PROF_FILTER_KNOWN_GUILD"] or "Apenas com Artesão na Guilda")
    end

    if self._newOrderBtn and self._newOrderBtn.text then
        self._newOrderBtn.text:SetText(curL["ORDER_NEW_BTN"] or "+ Novo Pedido de Profissão")
    end

    if self._scanBtn and self._scanBtn.text then
        self._scanBtn.text:SetText(curL["MY_PROF_SCAN_BTN"] or "Escanear Minhas Profissões Agora")
    end
end

--- Cria todos os componentes visuais da janela no padrão WoW Forever
function ProfessionView:createUI()
    if self._frame then return end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "GuildManagerProfessionFrame", UIParent, template)
    self._frame = frame

    frame:SetSize(946, 594)
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

    if UISpecialFrames then
        table.insert(UISpecialFrames, "GuildManagerProfessionFrame")
    end

    frame:SetScript("OnShow", function()
        if PlaySound then
            pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN or 839)
        end
        self:refresh()
    end)

    frame:SetScript("OnHide", function()
        if PlaySound then
            pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE or 840)
        end
        if self._orderModal and self._orderModal:IsShown() then
            self._orderModal:Hide()
        end
    end)

    -- Fundo sólido escuro
    local solidBg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    solidBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    solidBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    solidBg:SetColorTexture(0.04, 0.03, 0.02, 1.0)

    -- Pergaminho clássico
    local bgTex = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    bgTex:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    bgTex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    local okTex = bgTex:SetTexture("Interface\\AddOns\\GuildManagerForever\\Textures\\background.tga")
    if okTex == false or not bgTex:GetTexture() then
        bgTex:SetTexture("Interface\\AddOns\\GuildManager\\Textures\\background.tga")
    end
    bgTex:SetAlpha(0.45)

    if frame.SetBackdrop then
        frame:SetBackdrop(DIALOG_BACKDROP)
        frame:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], 0.20)
        frame:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], PALETTE.FRAME_BORDER[4])
    end

    -- Botão Fechar ("X")
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetSize(28, 28)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

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

    -- Título
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", factionIcon, "RIGHT", 10, 0)
    titleText:SetText(curL["PROF_VIEW_TITLE"] or "PEDIDOS DE PROFISSÃO & ARTESÃOS DA GUILDA")
    self._titleText = titleText

    -- Subtítulo
    local subtitleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitleText:SetPoint("LEFT", titleText, "RIGHT", 12, 0)
    subtitleText:SetText(curL["PROF_VIEW_SUBTITLE"] or "Consulte todas as receitas do jogo, veja quem fabrica na guilda e faça seus pedidos")
    self._subtitleText = subtitleText

    -- Linha divisória superior
    local headerSep = frame:CreateTexture(nil, "ARTWORK")
    headerSep:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -45)
    headerSep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -45)
    headerSep:SetHeight(1)
    headerSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- Navegador de Sub-abas no topo
    self:createSubTabs()

    -- Container 1: Navegador de Profissões & Receitas
    self:createBrowserContainer()

    -- Container 2: Mural de Pedidos de Fabricação
    self:createOrdersContainer()

    -- Container 3: Minhas Profissões
    self:createMyProfessionsContainer()

    -- Modal de Criação de Pedido
    self:createOrderModal()

    -- Abas Laterais (Audit, Logs, Groups, Agenda, Professions [Ativa], Settings)
    self:createSideTabs()

    -- Listener para atualização assíncrona de itens da Blizzard
    local evtFrame = CreateFrame("Frame", nil, frame)
    pcall(function() evtFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED") end)
    evtFrame:SetScript("OnEvent", function(_, event)
        if event == "GET_ITEM_INFO_RECEIVED" then
            if ProfessionData and ProfessionData.clearItemCache then
                ProfessionData.clearItemCache()
            end
            if frame:IsShown() and self._currentSubTab == "BROWSER" then
                self:renderRecipeRows()
                if self._selectedRecipe then
                    self:updateRecipeDetails(self._selectedRecipe)
                end
            end
        end
    end)

    self:switchSubTab("BROWSER")
end

--- Cria as sub-abas de alternância (Profissões & Receitas / Mural de Pedidos / Minhas Profissões)
function ProfessionView:createSubTabs()
    local frame = self._frame
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local curL = (_G.GM and _G.GM.L) or _G.L or L

    local subTabDefs = {
        { id = "BROWSER",  key = "PROF_SUBTAB_BROWSER",  defaultText = "Profissões & Receitas", width = 160 },
        { id = "ORDERS",   key = "PROF_SUBTAB_ORDERS",   defaultText = "Mural de Pedidos",       width = 140 },
        { id = "MY_PROFS", key = "PROF_SUBTAB_MY_PROFS", defaultText = "Minhas Profissões",    width = 140 },
    }

    self._subTabBtns = {}
    local prevBtn = nil

    for _, def in ipairs(subTabDefs) do
        local btn = CreateFrame("Button", nil, frame, template)
        btn:SetSize(def.width, 24)
        if not prevBtn then
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -50)
        else
            btn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
        end

        if btn.SetBackdrop then
            btn:SetBackdrop(SUB_CONTAINER_BACKDROP)
        end

        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("CENTER", btn, "CENTER", 0, 0)
        txt:SetText(curL[def.key] or def.defaultText)
        btn.text = txt
        btn.id = def.id

        btn:SetScript("OnClick", function()
            self:switchSubTab(def.id)
        end)

        self._subTabBtns[def.id] = btn
        prevBtn = btn
    end
end

--- Alterna a sub-aba ativa na interface
---@param subTabId string @"BROWSER", "ORDERS", "MY_PROFS"
function ProfessionView:switchSubTab(subTabId)
    self._currentSubTab = subTabId

    for id, btn in pairs(self._subTabBtns or {}) do
        local isActive = (id == subTabId)
        if btn.SetBackdropColor and btn.SetBackdropBorderColor then
            if isActive then
                btn:SetBackdropColor(PALETTE.ACTIVE_TAB_BG[1], PALETTE.ACTIVE_TAB_BG[2], PALETTE.ACTIVE_TAB_BG[3], PALETTE.ACTIVE_TAB_BG[4])
                btn:SetBackdropBorderColor(PALETTE.ACTIVE_TAB_BORDER[1], PALETTE.ACTIVE_TAB_BORDER[2], PALETTE.ACTIVE_TAB_BORDER[3], PALETTE.ACTIVE_TAB_BORDER[4])
                btn.text:SetTextColor(1.0, 0.85, 0.20, 1.0)
            else
                btn:SetBackdropColor(PALETTE.INACTIVE_TAB_BG[1], PALETTE.INACTIVE_TAB_BG[2], PALETTE.INACTIVE_TAB_BG[3], PALETTE.INACTIVE_TAB_BG[4])
                btn:SetBackdropBorderColor(PALETTE.INACTIVE_TAB_BORDER[1], PALETTE.INACTIVE_TAB_BORDER[2], PALETTE.INACTIVE_TAB_BORDER[3], PALETTE.INACTIVE_TAB_BORDER[4])
                btn.text:SetTextColor(0.70, 0.70, 0.70, 1.0)
            end
        end
    end

    if self._browserContainer then
        if subTabId == "BROWSER" then self._browserContainer:Show() else self._browserContainer:Hide() end
    end
    if self._ordersContainer then
        if subTabId == "ORDERS" then self._ordersContainer:Show() else self._ordersContainer:Hide() end
    end
    if self._myProfsContainer then
        if subTabId == "MY_PROFS" then self._myProfsContainer:Show() else self._myProfsContainer:Hide() end
    end

    self:refresh()
end

-- =========================================================================
-- SUB-ABA 1: NAVEGADOR DE PROFISSÕES & RECEITAS
-- =========================================================================

function ProfessionView:createBrowserContainer()
    local frame = self._frame
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local curL = (_G.GM and _G.GM.L) or _G.L or L

    local container = CreateFrame("Frame", "GM_ProfBrowserContainer", frame)
    container:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -78)
    container:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 14)
    self._browserContainer = container

    -- -------------------------------------------------------------
    -- Coluna Esquerda: As 6 Profissões Primárias de Fabricação
    -- -------------------------------------------------------------
    local profListInset = CreateFrame("Frame", nil, container, template)
    profListInset:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    profListInset:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
    profListInset:SetWidth(185)
    if profListInset.SetBackdrop then
        profListInset:SetBackdrop(CONTAINER_BACKDROP)
        profListInset:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        profListInset:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end

    local profHeader = profListInset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    profHeader:SetPoint("TOPLEFT", profListInset, "TOPLEFT", 8, -8)
    profHeader:SetText("|cffffd200Profissões de Fabricação|r")

    local pSep = profListInset:CreateTexture(nil, "ARTWORK")
    pSep:SetPoint("TOPLEFT", profHeader, "BOTTOMLEFT", 0, -4)
    pSep:SetPoint("RIGHT", profListInset, "RIGHT", -8, 0)
    pSep:SetHeight(1)
    pSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    self._profButtons = {}
    local prevProfBtn = nil

    for _, profKey in ipairs(ProfessionData.ORDER) do
        local def = ProfessionData.PROFESSIONS[profKey]
        local btn = CreateFrame("Button", nil, profListInset, template)
        btn:SetSize(170, 48)
        if not prevProfBtn then
            btn:SetPoint("TOPLEFT", pSep, "BOTTOMLEFT", 0, -6)
        else
            btn:SetPoint("TOPLEFT", prevProfBtn, "BOTTOMLEFT", 0, -6)
        end

        if btn.SetBackdrop then
            btn:SetBackdrop(SUB_CONTAINER_BACKDROP)
        end

        -- Ícone
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(36, 36)
        icon:SetPoint("LEFT", btn, "LEFT", 6, 0)
        icon:SetTexture(def.icon)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.icon = icon

        -- Nome da profissão
        local nameTxt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameTxt:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -2)
        nameTxt:SetText(def.name)
        btn.nameTxt = nameTxt

        -- Badge de membros com a profissão
        local countTxt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        countTxt:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 2)
        countTxt:SetText("|cffaaaaaa0 artesãos|r")
        btn.countTxt = countTxt
        btn.profKey = profKey

        btn:SetScript("OnClick", function()
            self:selectProfession(profKey)
        end)

        self._profButtons[profKey] = btn
        prevProfBtn = btn
    end

    -- -------------------------------------------------------------
    -- Painel Central / Meio: Barra Superior + Lista de Receitas
    -- -------------------------------------------------------------
    local centerInset = CreateFrame("Frame", nil, container, template)
    centerInset:SetPoint("TOPLEFT", profListInset, "TOPRIGHT", 6, 0)
    centerInset:SetPoint("BOTTOMLEFT", profListInset, "BOTTOMRIGHT", 6, 0)
    centerInset:SetWidth(400)
    if centerInset.SetBackdrop then
        centerInset:SetBackdrop(CONTAINER_BACKDROP)
        centerInset:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        centerInset:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end

    -- Cabeçalho da profissão selecionada
    local profActiveIcon = centerInset:CreateTexture(nil, "ARTWORK")
    profActiveIcon:SetSize(28, 28)
    profActiveIcon:SetPoint("TOPLEFT", centerInset, "TOPLEFT", 8, -8)
    self._profActiveIcon = profActiveIcon

    local profActiveTitle = centerInset:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    profActiveTitle:SetPoint("LEFT", profActiveIcon, "RIGHT", 8, 0)
    profActiveTitle:SetText("Alquimia")
    self._profActiveTitle = profActiveTitle

    -- Lista resumida de membros que possuem a profissão
    local guildCraftersSummary = centerInset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    guildCraftersSummary:SetPoint("TOPLEFT", profActiveIcon, "BOTTOMLEFT", 0, -6)
    guildCraftersSummary:SetPoint("RIGHT", centerInset, "RIGHT", -8, 0)
    guildCraftersSummary:SetJustifyH("LEFT")
    guildCraftersSummary:SetText("|cffffd200Membros com esta profissão:|r Carregando...")
    self._guildCraftersSummary = guildCraftersSummary

    -- Caixa de Busca
    local searchBox = CreateFrame("EditBox", "GM_ProfRecipeSearchBox", centerInset, template)
    searchBox:SetPoint("TOPLEFT", guildCraftersSummary, "BOTTOMLEFT", 0, -8)
    searchBox:SetPoint("RIGHT", centerInset, "RIGHT", -8, 0)
    searchBox:SetHeight(22)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("GameFontHighlightSmall")
    searchBox:SetTextInsets(6, 6, 0, 0)
    if searchBox.SetBackdrop then
        searchBox:SetBackdrop(SUB_CONTAINER_BACKDROP)
        searchBox:SetBackdropColor(0, 0, 0, 0.8)
        searchBox:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.8)
    end
    local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
    searchPlaceholder:SetText(curL["PROF_SEARCH_PLACEHOLDER"] or "Buscar receita ou item...")
    self._searchPlaceholder = searchPlaceholder

    searchBox:SetScript("OnTextChanged", function(eb)
        local text = eb:GetText()
        if text and text ~= "" then
            searchPlaceholder:Hide()
        else
            searchPlaceholder:Show()
        end
        self._recipeSearchText = text
        self._recipeOffset = 0
        self:refreshRecipeList()
    end)
    searchBox:SetScript("OnEscapePressed", function(eb) eb:ClearFocus() end)
    self._searchBox = searchBox

    -- Checkbox "Apenas com Artesão na Guilda"
    local cbOnlyGuild = CreateFrame("CheckButton", "GM_ProfOnlyGuildCheckbox", centerInset, "UICheckButtonTemplate")
    cbOnlyGuild:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -4)
    cbOnlyGuild:SetSize(22, 22)
    cbOnlyGuild:SetChecked(false)
    local cbText = cbOnlyGuild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cbText:SetPoint("LEFT", cbOnlyGuild, "RIGHT", 4, 0)
    cbText:SetText(curL["PROF_FILTER_KNOWN_GUILD"] or "Apenas com Artesão na Guilda")
    self._cbOnlyGuildText = cbText
    cbOnlyGuild:SetScript("OnClick", function(cb)
        self._onlyGuildCrafters = cb:GetChecked()
        self._recipeOffset = 0
        self:refreshRecipeList()
    end)
    self._cbOnlyGuild = cbOnlyGuild

    -- Separador da lista de receitas
    local rSep = centerInset:CreateTexture(nil, "ARTWORK")
    rSep:SetPoint("TOPLEFT", cbOnlyGuild, "BOTTOMLEFT", 0, -4)
    rSep:SetPoint("RIGHT", centerInset, "RIGHT", -8, 0)
    rSep:SetHeight(1)
    rSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.5)

    -- ScrollFrame da lista de receitas
    local recipeScroll = CreateFrame("ScrollFrame", "GM_ProfRecipeScrollFrame", centerInset)
    recipeScroll:SetPoint("TOPLEFT", rSep, "BOTTOMLEFT", 0, -4)
    recipeScroll:SetPoint("BOTTOMRIGHT", centerInset, "BOTTOMRIGHT", -22, 8)
    recipeScroll:EnableMouseWheel(true)
    recipeScroll:SetScript("OnMouseWheel", function(_, delta)
        self:scrollRecipes(-delta * 2)
    end)
    self._recipeScroll = recipeScroll

    -- ScrollBar vertical
    local recipeScrollBar = CreateFrame("Slider", "GM_ProfRecipeScrollBar", centerInset, "UIPanelScrollBarTemplate")
    recipeScrollBar:SetPoint("TOPRIGHT", centerInset, "TOPRIGHT", -4, -120)
    recipeScrollBar:SetPoint("BOTTOMRIGHT", centerInset, "BOTTOMRIGHT", -4, 26)
    recipeScrollBar:SetWidth(16)
    recipeScrollBar:SetMinMaxValues(0, 1)
    recipeScrollBar:SetValueStep(1)
    recipeScrollBar:SetScript("OnValueChanged", function(_, val)
        self._recipeOffset = math.floor(val)
        self:renderRecipeRows()
    end)
    self._recipeScrollBar = recipeScrollBar

    -- Linhas de receitas visíveis (10 linhas)
    self._recipeRows = {}
    local NUM_RECIPE_ROWS = 10
    local ROW_HEIGHT = 34
    for i = 1, NUM_RECIPE_ROWS do
        local row = CreateFrame("Button", nil, centerInset, template)
        row:SetSize(370, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", recipeScroll, "TOPLEFT", 0, -(i - 1) * (ROW_HEIGHT + 2))
        if row.SetBackdrop then
            row:SetBackdrop(SUB_CONTAINER_BACKDROP)
            row:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.8)
            row:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.6)
        end

        local rIcon = row:CreateTexture(nil, "ARTWORK")
        rIcon:SetSize(28, 28)
        rIcon:SetPoint("LEFT", row, "LEFT", 4, 0)
        rIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.icon = rIcon

        local rBorder = row:CreateTexture(nil, "OVERLAY")
        rBorder:SetPoint("TOPLEFT", rIcon, "TOPLEFT", -1, 1)
        rBorder:SetPoint("BOTTOMRIGHT", rIcon, "BOTTOMRIGHT", 1, -1)
        rBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
        row.iconBorder = rBorder

        local rName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rName:SetPoint("TOPLEFT", rIcon, "TOPRIGHT", 6, -2)
        rName:SetPoint("RIGHT", row, "RIGHT", -80, 0)
        rName:SetJustifyH("LEFT")
        row.nameTxt = rName

        local rSkill = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        rSkill:SetPoint("BOTTOMLEFT", rIcon, "BOTTOMRIGHT", 6, 2)
        row.skillTxt = rSkill

        local rCrafters = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rCrafters:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        rCrafters:SetJustifyH("RIGHT")
        row.craftersTxt = rCrafters

        local rHl = row:CreateTexture(nil, "HIGHLIGHT")
        rHl:SetAllPoints(row)
        rHl:SetColorTexture(PALETTE.HIGHLIGHT_TINT[1], PALETTE.HIGHLIGHT_TINT[2], PALETTE.HIGHLIGHT_TINT[3], 0.25)

        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta)
            self:scrollRecipes(-delta * 2)
        end)

        row:SetScript("OnClick", function()
            if row.recipeData then
                self:selectRecipe(row.recipeData)
            end
        end)

        row:SetScript("OnEnter", function()
            if row.recipeData then
                self:showRecipeTooltip(row, row.recipeData)
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        self._recipeRows[i] = row
    end

    -- -------------------------------------------------------------
    -- Painel Direito: Detalhes da Receita & Quem Faz na Guilda
    -- -------------------------------------------------------------
    local rightInset = CreateFrame("Frame", nil, container, template)
    rightInset:SetPoint("TOPLEFT", centerInset, "TOPRIGHT", 6, 0)
    rightInset:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    if rightInset.SetBackdrop then
        rightInset:SetBackdrop(CONTAINER_BACKDROP)
        rightInset:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        rightInset:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end
    self._rightInset = rightInset

    -- Container de Detalhes e Tooltip do Item no estilo oficial do WoW
    local itemStatsContainer = CreateFrame("Frame", nil, rightInset, template)
    itemStatsContainer:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 10, -10)
    itemStatsContainer:SetPoint("TOPRIGHT", rightInset, "TOPRIGHT", -10, -10)
    itemStatsContainer:SetHeight(70)
    if itemStatsContainer.SetBackdrop then
        itemStatsContainer:SetBackdrop(SUB_CONTAINER_BACKDROP)
        itemStatsContainer:SetBackdropColor(0.04, 0.04, 0.04, 0.95)
        itemStatsContainer:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.90)
    end
    self._itemStatsContainer = itemStatsContainer

    -- Ícone da receita dentro do container com borda de qualidade e suporte a clique/tooltip
    local detailIconBtn = CreateFrame("Button", nil, itemStatsContainer)
    detailIconBtn:SetSize(38, 38)
    detailIconBtn:SetPoint("TOPLEFT", itemStatsContainer, "TOPLEFT", 8, -8)
    self._detailIconBtn = detailIconBtn

    local detailIcon = detailIconBtn:CreateTexture(nil, "ARTWORK")
    detailIcon:SetAllPoints(detailIconBtn)
    detailIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self._detailIcon = detailIcon

    local detailIconBorder = detailIconBtn:CreateTexture(nil, "OVERLAY")
    detailIconBorder:SetPoint("TOPLEFT", detailIconBtn, "TOPLEFT", -1, 1)
    detailIconBorder:SetPoint("BOTTOMRIGHT", detailIconBtn, "BOTTOMRIGHT", 1, -1)
    detailIconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    self._detailIconBorder = detailIconBorder

    detailIconBtn:SetScript("OnEnter", function()
        if self._selectedRecipe then
            self:showRecipeTooltip(detailIconBtn, self._selectedRecipe)
        end
    end)
    detailIconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    detailIconBtn:SetScript("OnClick", function()
        if self._selectedRecipe and self._selectedRecipe.itemId and HandleModifiedItemClick and _G.GetItemInfo then
            local _, link = _G.GetItemInfo(self._selectedRecipe.itemId)
            if link then HandleModifiedItemClick(link) end
        end
    end)

    -- Nome do item dentro do container ao lado do ícone
    local detailTitle = itemStatsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    detailTitle:SetPoint("LEFT", detailIconBtn, "RIGHT", 8, 0)
    detailTitle:SetPoint("RIGHT", itemStatsContainer, "RIGHT", -8, 0)
    detailTitle:SetJustifyH("LEFT")
    detailTitle:SetWordWrap(true)
    detailTitle:SetText("Selecione uma receita")
    self._detailTitle = detailTitle

    local detailSubtitle = itemStatsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailSubtitle:Hide()
    self._detailSubtitle = detailSubtitle

    local detailSkill = itemStatsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailSkill:Hide()
    self._detailSkill = detailSkill

    -- Separador sutil entre o cabeçalho e os atributos dentro do container
    local headerSep = itemStatsContainer:CreateTexture(nil, "ARTWORK")
    headerSep:SetHeight(1)
    headerSep:SetPoint("TOPLEFT", itemStatsContainer, "TOPLEFT", 8, -50)
    headerSep:SetPoint("RIGHT", itemStatsContainer, "RIGHT", -8, 0)
    headerSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.35)
    headerSep:Hide()
    self._headerSep = headerSep

    self._tooltipLines = {}
    local MAX_TOOLTIP_LINES = 12
    for i = 1, MAX_TOOLTIP_LINES do
        local lineFrame = CreateFrame("Frame", nil, itemStatsContainer)
        lineFrame:SetHeight(13)
        if i == 1 then
            lineFrame:SetPoint("TOPLEFT", itemStatsContainer, "TOPLEFT", 8, -56)
            lineFrame:SetPoint("TOPRIGHT", itemStatsContainer, "TOPRIGHT", -8, -56)
        else
            lineFrame:SetPoint("TOPLEFT", self._tooltipLines[i - 1], "BOTTOMLEFT", 0, -2)
            lineFrame:SetPoint("TOPRIGHT", self._tooltipLines[i - 1], "BOTTOMRIGHT", 0, -2)
        end

        local leftTxt = lineFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        leftTxt:SetPoint("TOPLEFT", lineFrame, "TOPLEFT", 0, 0)
        leftTxt:SetPoint("RIGHT", lineFrame, "RIGHT", 0, 0)
        leftTxt:SetJustifyH("LEFT")
        leftTxt:SetWordWrap(true)
        lineFrame.leftTxt = leftTxt

        local rightTxt = lineFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rightTxt:SetPoint("TOPRIGHT", lineFrame, "TOPRIGHT", 0, 0)
        rightTxt:SetJustifyH("RIGHT")
        lineFrame.rightTxt = rightTxt

        lineFrame:Hide()
        self._tooltipLines[i] = lineFrame
    end
    self._statLine1 = self._tooltipLines[1] and self._tooltipLines[1].leftTxt

    -- Materiais necessários
    local reagentsHeader = rightInset:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reagentsHeader:SetPoint("TOPLEFT", itemStatsContainer, "BOTTOMLEFT", 0, -6)
    reagentsHeader:SetText(curL["PROF_REAGENTS_HEADER"] or "|cffffd200Materiais Necessários:|r")

    local reagentsText = rightInset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    reagentsText:SetPoint("TOPLEFT", reagentsHeader, "BOTTOMLEFT", 0, -3)
    reagentsText:SetPoint("RIGHT", rightInset, "RIGHT", -10, 0)
    reagentsText:SetJustifyH("LEFT")
    reagentsText:SetWordWrap(true)
    reagentsText:SetText("|cffaaaaaaNenhum material listado.|r")
    self._reagentsText = reagentsText

    local dSep = rightInset:CreateTexture(nil, "ARTWORK")
    dSep:SetPoint("TOPLEFT", reagentsText, "BOTTOMLEFT", 0, -6)
    dSep:SetPoint("RIGHT", rightInset, "RIGHT", -10, 0)
    dSep:SetHeight(1)
    dSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    -- Cabeçalho "Quem faz esta receita na guilda"
    local craftersHeader = rightInset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    craftersHeader:SetPoint("TOPLEFT", dSep, "BOTTOMLEFT", 0, -6)
    craftersHeader:SetText(curL["PROF_WHO_CRAFTS"] or "|cffffd200Quem faz esta receita na guilda:|r")

    -- ScrollFrame de Artesãos que conhecem a receita
    local craftersScroll = CreateFrame("ScrollFrame", "GM_ProfCraftersScroll", rightInset)
    craftersScroll:SetPoint("TOPLEFT", craftersHeader, "BOTTOMLEFT", 0, -4)
    craftersScroll:SetPoint("BOTTOMRIGHT", rightInset, "BOTTOMRIGHT", -10, 36)
    self._craftersScroll = craftersScroll

    local noCraftersNotice = rightInset:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    noCraftersNotice:SetPoint("CENTER", craftersScroll, "CENTER", 0, 0)
    noCraftersNotice:SetWidth(280)
    noCraftersNotice:SetText(curL["PROF_NO_ONE_CRAFTS"] or "Nenhum membro da guilda conhece esta receita ainda.")
    self._noCraftersNotice = noCraftersNotice

    -- Linhas de artesãos (5 linhas visíveis)
    self._crafterRows = {}
    local NUM_CRAFTER_ROWS = 5
    local CRAFTER_ROW_H = 30
    for i = 1, NUM_CRAFTER_ROWS do
        local row = CreateFrame("Frame", nil, rightInset, template)
        row:SetHeight(CRAFTER_ROW_H)
        row:SetPoint("TOPLEFT", craftersScroll, "TOPLEFT", 0, -(i - 1) * (CRAFTER_ROW_H + 2))
        row:SetPoint("RIGHT", craftersScroll, "RIGHT", 0, 0)
        if row.SetBackdrop then
            row:SetBackdrop(SUB_CONTAINER_BACKDROP)
            row:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.85)
            row:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.70)
        end

        local cStatus = row:CreateTexture(nil, "ARTWORK")
        cStatus:SetSize(8, 8)
        cStatus:SetPoint("LEFT", row, "LEFT", 6, 0)
        cStatus:SetColorTexture(0, 1, 0, 1) -- Verde para online
        row.statusDot = cStatus

        -- Botão Fazer Pedido
        local oBtn = CreateFrame("Button", nil, row, template)
        oBtn:SetSize(72, 20)
        oBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        if oBtn.SetBackdrop then oBtn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
        local oTxt = oBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        oTxt:SetPoint("CENTER", oBtn, "CENTER", 0, 0)
        oTxt:SetText(curL["PROF_BTN_CREATE_ORDER"] or "Pedir")
        oBtn.text = oTxt
        oBtn:SetScript("OnClick", function()
            if row.member and self._selectedRecipe then
                local crafterName = self:getMemberDisplayName(row.member)
                self:openOrderModal(self._selectedRecipe, crafterName)
            end
        end)
        row.orderBtn = oBtn

        -- Botão Sussurrar
        local wBtn = CreateFrame("Button", nil, row, template)
        wBtn:SetSize(58, 20)
        wBtn:SetPoint("RIGHT", oBtn, "LEFT", -4, 0)
        if wBtn.SetBackdrop then wBtn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
        local wTxt = wBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        wTxt:SetPoint("CENTER", wBtn, "CENTER", 0, 0)
        wTxt:SetText(curL["PROF_BTN_WHISPER"] or "Sussurrar")
        wBtn.text = wTxt
        wBtn:SetScript("OnClick", function()
            if row.member then
                local crafterName = self:getMemberDisplayName(row.member)
                self:whisperCrafter(crafterName)
            end
        end)
        row.whisperBtn = wBtn

        -- Nome do artesão (linha superior ancorada ao topo)
        local cName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cName:SetPoint("TOPLEFT", row, "TOPLEFT", 20, -3)
        cName:SetPoint("RIGHT", wBtn, "LEFT", -4, 0)
        cName:SetJustifyH("LEFT")
        cName:SetWordWrap(false)
        cName:SetText("Nome")
        row.nameTxt = cName

        -- Nível de perícia do artesão (linha inferior ancorada ao rodapé)
        local cRank = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        cRank:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 20, 3)
        cRank:SetPoint("RIGHT", wBtn, "LEFT", -4, 0)
        cRank:SetJustifyH("LEFT")
        cRank:SetWordWrap(false)
        cRank:SetText("(300/300)")
        row.rankTxt = cRank

        row:Hide()
        self._crafterRows[i] = row
    end

    -- Botão inferior: "Fazer Pedido Geral para a Guilda"
    local publicOrderBtn = CreateFrame("Button", nil, rightInset, template)
    publicOrderBtn:SetSize(280, 24)
    publicOrderBtn:SetPoint("BOTTOM", rightInset, "BOTTOM", 0, 6)
    if publicOrderBtn.SetBackdrop then
        publicOrderBtn:SetBackdrop(SUB_CONTAINER_BACKDROP)
        publicOrderBtn:SetBackdropColor(PALETTE.FOCUS_BG[1], PALETTE.FOCUS_BG[2], PALETTE.FOCUS_BG[3], 0.9)
        publicOrderBtn:SetBackdropBorderColor(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], 1.0)
    end
    local pubTxt = publicOrderBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pubTxt:SetPoint("CENTER", publicOrderBtn, "CENTER", 0, 0)
    pubTxt:SetText("|cffffd200+ Fazer Pedido de Fabricação|r")
    publicOrderBtn.text = pubTxt
    publicOrderBtn:SetScript("OnClick", function()
        if self._selectedRecipe then
            self:openOrderModal(self._selectedRecipe, "")
        end
    end)
    self._publicOrderBtn = publicOrderBtn
end

--- Seleciona uma das 6 profissões para exibir na interface
---@param profKey string
function ProfessionView:selectProfession(profKey)
    local isDifferent = (self._selectedProfKey ~= profKey)
    self._selectedProfKey = profKey
    if isDifferent then
        self._recipeOffset = 0
        self._selectedRecipe = nil
    end

    for pKey, btn in pairs(self._profButtons or {}) do
        local isSelected = (pKey == profKey)
        if btn.SetBackdropColor and btn.SetBackdropBorderColor then
            if isSelected then
                btn:SetBackdropColor(PALETTE.ACTIVE_TAB_BG[1], PALETTE.ACTIVE_TAB_BG[2], PALETTE.ACTIVE_TAB_BG[3], 0.95)
                btn:SetBackdropBorderColor(PALETTE.ACTIVE_TAB_BORDER[1], PALETTE.ACTIVE_TAB_BORDER[2], PALETTE.ACTIVE_TAB_BORDER[3], 1.0)
                btn.nameTxt:SetTextColor(1.0, 0.85, 0.20, 1.0)
            else
                btn:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.80)
                btn:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.70)
                btn.nameTxt:SetTextColor(0.9, 0.9, 0.9, 1.0)
            end
        end
    end

    local def = ProfessionData.PROFESSIONS[profKey]
    if def then
        if self._profActiveIcon then self._profActiveIcon:SetTexture(def.icon) end
        if self._profActiveTitle then self._profActiveTitle:SetText(def.name) end
    end

    self:refreshRecipeList()
end

--- Rola a lista de receitas
---@param delta number
function ProfessionView:scrollRecipes(delta)
    local maxOffset = math.max(0, #self._filteredRecipes - 10)
    local newOffset = math.max(0, math.min(maxOffset, (self._recipeOffset or 0) + delta))
    if newOffset ~= self._recipeOffset then
        self._recipeOffset = newOffset
        if self._recipeScrollBar then
            self._recipeScrollBar:SetValue(newOffset)
        end
        self:renderRecipeRows()
    end
end

--- Atualiza a lista filtrada de receitas da profissão selecionada
function ProfessionView:refreshRecipeList()
    local profKey = self._selectedProfKey or "ALCHEMY"
    local pService = _G.GM and _G.GM.professionService
    if not pService then return end

    -- Membros da guilda com a profissão
    local membersWithProf = pService:getGuildMembersWithProfession(profKey)
    if self._guildCraftersSummary then
        if #membersWithProf == 0 then
            self._guildCraftersSummary:SetText("|cffaaaaaaNenhum membro da guilda com esta profissão registrado.|r")
        else
            local names = {}
            for _, info in ipairs(membersWithProf) do
                local m = info.member
                local cTok = m:getClass()
                local cColor = CLASS_COLORS[cTok] and CLASS_COLORS[cTok].hex or "|cffffffff"
                local dispName = self:getMemberDisplayName(m)
                table.insert(names, string.format("%s%s|r (%d/%d)", cColor, dispName, info.rank or 0, info.maxRank or 300))
            end
            self._guildCraftersSummary:SetText(string.format("|cffffd200Membros com %s (%d):|r %s", ProfessionData.PROFESSIONS[profKey].name, #membersWithProf, table.concat(names, ", ")))
        end
    end

    -- Atualiza os contadores nos botões laterais de profissão
    for pK, btn in pairs(self._profButtons or {}) do
        local mList = pService:getGuildMembersWithProfession(pK)
        if btn.countTxt then
            btn.countTxt:SetText(string.format("|cffaaaaaa%d artesão(s)|r", #mList))
        end
    end

    -- Lista de receitas filtradas
    self._filteredRecipes = pService:getRecipes(profKey, self._recipeSearchText, nil, self._onlyGuildCrafters)

    local maxOffset = math.max(0, #self._filteredRecipes - 10)
    self._recipeOffset = math.max(0, math.min(self._recipeOffset or 0, maxOffset))
    if self._recipeScrollBar then
        self._recipeScrollBar:SetMinMaxValues(0, maxOffset)
        self._recipeScrollBar:SetValue(self._recipeOffset)
    end

    self:renderRecipeRows()

    -- Mantém a receita atualmente selecionada se ainda existir na lista filtrada
    local stillExists = false
    if self._selectedRecipe then
        for _, item in ipairs(self._filteredRecipes) do
            if item.recipe and item.recipe.id == self._selectedRecipe.id then
                stillExists = true
                self._selectedRecipe = item.recipe
                break
            end
        end
    end

    if not stillExists then
        if #self._filteredRecipes > 0 then
            self:selectRecipe(self._filteredRecipes[1].recipe)
        else
            self._selectedRecipe = nil
        end
    elseif self._selectedRecipe then
        self:updateRecipeDetails(self._selectedRecipe)
    end
end

--- Renderiza as linhas visíveis da lista de receitas
function ProfessionView:renderRecipeRows()
    local startIdx = self._recipeOffset or 0
    for i = 1, 10 do
        local row = self._recipeRows[i]
        local data = self._filteredRecipes[startIdx + i]
        if data and data.recipe then
            local r = data.recipe
            row.recipeData = r

            local itemData = ProfessionData.getItemData(r)
            local iconTex = (itemData and itemData.icon) or r.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
            row.icon:SetTexture(iconTex)

            if row.iconBorder then
                local rQ, gQ, bQ = (itemData and itemData.r or 1), (itemData and itemData.g or 1), (itemData and itemData.b or 1)
                row.iconBorder:SetVertexColor(rQ, gQ, bQ, 1.0)
            end

            local qColor = (itemData and itemData.qualityColor) or ProfessionData.getQualityColor(r.quality or 1)
            local displayName = (itemData and itemData.name) or ProfessionData.getRecipeDisplayName(r)
            row.nameTxt:SetText(string.format("%s%s|r", qColor, displayName))
            row.skillTxt:SetText(string.format("Perícia: %d", r.skill or 1))

            if (data.crafterCount or 0) > 0 then
                row.craftersTxt:SetText(string.format("|cff00ff00%d artesão(s)|r", data.crafterCount))
            else
                row.craftersTxt:SetText("|cff888888Sem artesão|r")
            end

            local isSelected = (self._selectedRecipe and self._selectedRecipe.id == r.id)
            if row.SetBackdropBorderColor then
                if isSelected then
                    row:SetBackdropBorderColor(1.0, 0.85, 0.20, 1.0)
                    row:SetBackdropColor(PALETTE.ACTIVE_TAB_BG[1], PALETTE.ACTIVE_TAB_BG[2], PALETTE.ACTIVE_TAB_BG[3], 0.95)
                else
                    row:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.6)
                    row:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.8)
                end
            end

            row:Show()
        else
            row.recipeData = nil
            row:Hide()
        end
    end
end

--- Seleciona uma receita e atualiza o painel de artesãos da direita
---@param recipe table
function ProfessionView:selectRecipe(recipe)
    self._selectedRecipe = recipe
    self:renderRecipeRows()
    self:updateRecipeDetails(recipe)
end

--- Atualiza o painel de detalhes e lista de artesãos para a receita selecionada
---@param recipe table
function ProfessionView:updateRecipeDetails(recipe)
    if not recipe then
        if self._detailTitle then self._detailTitle:SetText("Selecione uma receita") end
        if self._detailIcon then self._detailIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
        if self._detailIconBorder then self._detailIconBorder:SetVertexColor(0.5, 0.5, 0.5, 0.5) end
        if self._detailSubtitle then self._detailSubtitle:SetText(""); self._detailSubtitle:Hide() end
        if self._detailSkill then self._detailSkill:SetText(""); self._detailSkill:Hide() end
        if self._headerSep then self._headerSep:Hide() end
        for _, lf in ipairs(self._tooltipLines or {}) do lf:Hide() end
        if self._itemStatsContainer then
            self._itemStatsContainer:Show()
            self._itemStatsContainer:SetHeight(54)
        end
        if self._reagentsText then self._reagentsText:SetText("") end
        if self._noCraftersNotice then self._noCraftersNotice:Show() end
        for _, row in ipairs(self._crafterRows or {}) do row:Hide() end
        return
    end

    if self._itemStatsContainer then
        self._itemStatsContainer:Show()
    end

    local itemData = ProfessionData.getItemData(recipe)
    local displayName = (itemData and itemData.name) or ProfessionData.getRecipeDisplayName(recipe)

    if self._detailIcon then
        self._detailIcon:SetTexture((itemData and itemData.icon) or recipe.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    end
    if self._detailIconBorder then
        local rQ, gQ, bQ = (itemData and itemData.r or 1), (itemData and itemData.g or 1), (itemData and itemData.b or 1)
        self._detailIconBorder:SetVertexColor(rQ, gQ, bQ, 1.0)
    end
    if self._detailTitle then
        local qColor = (itemData and itemData.qualityColor) or ProfessionData.getQualityColor(recipe.quality or 1)
        self._detailTitle:SetText(string.format("%s%s|r", qColor, displayName))
    end
    if self._detailSubtitle then
        self._detailSubtitle:SetText("")
        self._detailSubtitle:Hide()
    end
    if self._detailSkill then
        self._detailSkill:SetText("")
        self._detailSkill:Hide()
    end

    -- Calcula as dimensões do cabeçalho dentro do itemStatsContainer
    local iconH = 38
    local titleHeight = 16
    if self._detailTitle and self._detailTitle.GetStringHeight then
        local gh = self._detailTitle:GetStringHeight()
        if type(gh) == "number" and gh > 0 then
            titleHeight = gh
        end
    end
    local titleRaw = (self._detailTitle and self._detailTitle:GetText()) or ""
    local cleanTitle = titleRaw:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if titleHeight <= 16 and string.len(cleanTitle) > 28 then
        titleHeight = 32
    end

    local headerH = math.max(iconH, titleHeight)
    local sepY = -(8 + headerH + 5)
    local startLinesY = sepY - 6

    -- Monta as linhas exatamente no formato de Tooltip Oficial do WoW (conforme o segundo print)
    local linesData = {}
    local scanned = false

    -- 1. Tenta primeiro escanear o item nativo da API do WoW caso já esteja em cache
    if recipe.itemId and _G.GetItemInfo and _G.GetItemInfo(recipe.itemId) then
        local scanTip = _G.GM_ProfScanTooltip
        if not scanTip and CreateFrame then
            pcall(function()
                scanTip = CreateFrame("GameTooltip", "GM_ProfScanTooltip", UIParent, "GameTooltipTemplate")
                if scanTip and scanTip.SetOwner then
                    scanTip:SetOwner(WorldFrame or UIParent, "ANCHOR_NONE")
                end
                _G.GM_ProfScanTooltip = scanTip
            end)
        end
        if scanTip and scanTip.ClearLines and scanTip.SetHyperlink and scanTip.NumLines then
            scanTip:ClearLines()
            pcall(function() scanTip:SetHyperlink("item:" .. recipe.itemId) end)
            local nLines = scanTip:NumLines()
            if nLines and nLines > 0 then
                -- Note: j = 1 é sempre o nome do item (já destacado no cabeçalho ao lado do ícone).
                -- Começamos em j = 2 para não duplicar o nome do item.
                for j = 2, math.min(12, nLines) do
                    local lObj = _G["GM_ProfScanTooltipTextLeft" .. j]
                    local rObj = _G["GM_ProfScanTooltipTextRight" .. j]
                    local lText = lObj and lObj.GetText and lObj:GetText()
                    local rText = rObj and rObj.GetText and rObj:GetText()
                    if lText and lText ~= "" then
                        local isItemLevel = lText:find("Item Nv") or lText:find("Nível do Item") or lText:find("Item Level")
                        if not isItemLevel then
                            local lr, lg, lb = 1, 1, 1
                            if lObj and lObj.GetTextColor then lr, lg, lb = lObj:GetTextColor() end
                            local rr, rg, rb = 1, 1, 1
                            if rObj and rObj.GetTextColor then rr, rg, rb = rObj:GetTextColor() end

                            table.insert(linesData, {
                                left = lText,
                                right = rText,
                                colorLeft = { lr, lg, lb },
                                colorRight = { rr, rg, rb },
                                font = "GameFontHighlightSmall",
                            })
                        end
                    end
                end
                if #linesData > 0 then
                    scanned = true
                end
            end
        end
    end

    -- 2. Fallback oficial estruturado a partir do banco de dados consolidado
    if not scanned then
        local quality = (itemData and itemData.quality) or recipe.quality or 1

        -- Tipo de Vinculação (Liga-se quando equipado / ao coletar)
        local slotRaw = itemData and itemData.slot
        local isGear = slotRaw and not slotRaw:find("Poção") and not slotRaw:find("Elixir")
            and not slotRaw:find("Frasco") and not slotRaw:find("Reagente")
            and not slotRaw:find("Consumível") and not slotRaw:find("Encantamento")
        if isGear then
            local bindStr = "Liga-se quando equipado"
            if quality == 4 or (itemData and itemData.source == "raid") then
                bindStr = "Liga-se ao coletar"
            end
            table.insert(linesData, {
                left = bindStr,
                colorLeft = { 1, 1, 1 },
                font = "GameFontHighlightSmall",
            })
        end

        -- Slot (esquerda) e Tipo de Armadura (direita)
        if slotRaw then
            local sLeft = slotRaw
            local sRight = nil
            local p1, p2 = slotRaw:match("^(.-)%s*%((.-)%)$")
            if p1 and p2 then
                sLeft = p1
                sRight = p2
            end
            table.insert(linesData, {
                left = sLeft,
                right = sRight,
                colorLeft = { 1, 1, 1 },
                colorRight = { 1, 1, 1 },
                font = "GameFontHighlightSmall",
            })
        end

        -- Armadura
        if itemData and itemData.armor and itemData.armor > 0 then
            table.insert(linesData, {
                left = string.format("%d de Armadura", itemData.armor),
                colorLeft = { 1, 1, 1 },
                font = "GameFontHighlightSmall",
            })
        end

        -- Atributos (cada atributo em sua própria linha)
        if itemData and itemData.attrs and itemData.attrs ~= "" then
            for stat in string.gmatch(itemData.attrs, "[^,]+") do
                local clean = stat:match("^%s*(.-)%s*$")
                if clean and clean ~= "" then
                    local num, attr = clean:match("^%+(%d+)%s+(.*)$")
                    local statFormatted = clean
                    if num and attr and not attr:find("^de ") then
                        statFormatted = string.format("+%s de %s", num, attr)
                    end
                    table.insert(linesData, {
                        left = statFormatted,
                        colorLeft = { 1, 1, 1 },
                        font = "GameFontHighlightSmall",
                    })
                end
            end
        end

        -- Efeitos de Equipar / Uso em verde
        if itemData and itemData.effects and itemData.effects ~= "" then
            table.insert(linesData, {
                left = itemData.effects,
                colorLeft = { 0, 1, 0 },
                font = "GameFontGreenSmall",
                wrap = true,
            })
        end

        -- Requer Nível
        if itemData and itemData.reqLevel and itemData.reqLevel > 0 then
            table.insert(linesData, {
                left = string.format("Requer Nível %d", itemData.reqLevel),
                colorLeft = { 1, 1, 1 },
                font = "GameFontHighlightSmall",
            })
        end

        -- Descrição / Utilidade
        if itemData and itemData.desc and itemData.desc ~= "" then
            table.insert(linesData, {
                left = itemData.desc,
                colorLeft = { 0.8, 0.8, 0.8 },
                font = "GameFontHighlightSmall",
                wrap = true,
            })
        end

        -- Texto de Ambientação (Flavor)
        if itemData and itemData.flavor and itemData.flavor ~= "" then
            table.insert(linesData, {
                left = string.format("\"%s\"", itemData.flavor),
                colorLeft = { 1, 0.82, 0 },
                font = "GameFontNormalSmall",
                wrap = true,
            })
        end
    end

    if self._headerSep then
        self._headerSep:ClearAllPoints()
        self._headerSep:SetPoint("TOPLEFT", self._itemStatsContainer, "TOPLEFT", 8, sepY)
        self._headerSep:SetPoint("RIGHT", self._itemStatsContainer, "RIGHT", -8, 0)
        if #linesData > 0 then
            self._headerSep:Show()
        else
            self._headerSep:Hide()
        end
    end

    -- Renderiza as linhas dinamicamente no itemStatsContainer
    local totalBoxH = (#linesData > 0) and math.abs(startLinesY) or (8 + headerH + 8)
    local prevLFrame = nil

    if self._tooltipLines then
        for idx = 1, 12 do
            local lFrame = self._tooltipLines[idx]
            local data = linesData[idx]
            if data and lFrame then
                lFrame.leftTxt:SetFontObject(data.font or "GameFontHighlightSmall")
                lFrame.leftTxt:SetText(data.left or "")
                local cL = data.colorLeft or { 1, 1, 1 }
                lFrame.leftTxt:SetTextColor(cL[1], cL[2], cL[3], 1.0)
                lFrame.leftTxt:ClearAllPoints()
                lFrame.leftTxt:SetPoint("TOPLEFT", lFrame, "TOPLEFT", 0, 0)
                lFrame.leftTxt:SetJustifyH("LEFT")
                lFrame.leftTxt:SetWordWrap(true)

                if data.right and data.right ~= "" then
                    lFrame.rightTxt:ClearAllPoints()
                    lFrame.rightTxt:SetPoint("TOPRIGHT", lFrame, "TOPRIGHT", 0, 0)
                    lFrame.rightTxt:SetFontObject(data.font or "GameFontHighlightSmall")
                    lFrame.rightTxt:SetText(data.right)
                    local cR = data.colorRight or { 1, 1, 1 }
                    lFrame.rightTxt:SetTextColor(cR[1], cR[2], cR[3], 1.0)
                    lFrame.rightTxt:Show()
                    lFrame.leftTxt:SetPoint("RIGHT", lFrame.rightTxt, "LEFT", -6, 0)
                else
                    lFrame.rightTxt:SetText("")
                    lFrame.rightTxt:Hide()
                    lFrame.leftTxt:SetPoint("RIGHT", lFrame, "RIGHT", 0, 0)
                end

                -- Cálculo de altura dinâmico para respeitar estritamente os limites da linha
                local lH = 13
                if lFrame.leftTxt.GetStringHeight then
                    local gh = lFrame.leftTxt:GetStringHeight()
                    if type(gh) == "number" and gh > 0 then
                        lH = math.max(13, math.ceil(gh))
                    end
                end
                if lH <= 13 then
                    local rawTxt = (data.left or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                    local maxChars = (data.right and data.right ~= "") and 24 or 38
                    if string.len(rawTxt) > maxChars then
                        local numLines = math.ceil(string.len(rawTxt) / maxChars)
                        lH = math.max(lH, numLines * 13)
                    end
                end
                lFrame:SetHeight(lH)

                lFrame:ClearAllPoints()
                if not prevLFrame then
                    lFrame:SetPoint("TOPLEFT", self._itemStatsContainer, "TOPLEFT", 8, startLinesY)
                    lFrame:SetPoint("TOPRIGHT", self._itemStatsContainer, "TOPRIGHT", -8, startLinesY)
                else
                    lFrame:SetPoint("TOPLEFT", prevLFrame, "BOTTOMLEFT", 0, -3)
                    lFrame:SetPoint("TOPRIGHT", prevLFrame, "BOTTOMRIGHT", 0, -3)
                end

                totalBoxH = totalBoxH + lH + 3
                lFrame:Show()
                prevLFrame = lFrame
            elseif lFrame then
                lFrame:Hide()
            end
        end
    end

    if #linesData > 0 then
        totalBoxH = totalBoxH + 6
    end

    if self._itemStatsContainer then
        totalBoxH = math.min(168, totalBoxH)
        self._itemStatsContainer:Show()
        self._itemStatsContainer:SetHeight(totalBoxH)
    end

    -- Materiais / Reagentes
    if self._reagentsText then
        if recipe.reagents and #recipe.reagents > 0 then
            local rParts = {}
            for _, rg in ipairs(recipe.reagents) do
                local rName = self:getReagentLocalizedName(rg.name) or rg.name
                table.insert(rParts, string.format("• |cffffffff%s|r x%d", rName, rg.count or 1))
            end
            self._reagentsText:SetText(table.concat(rParts, "   "))
        else
            self._reagentsText:SetText("|cffaaaaaaMateriais sob consulta no jogo.|r")
        end
    end

    -- Consulta quem da guilda conhece a receita
    local pService = _G.GM and _G.GM.professionService
    local crafters = pService and pService:getCraftersForRecipe(recipe.prof or self._selectedProfKey, recipe) or {}

    if #crafters == 0 then
        if self._noCraftersNotice then self._noCraftersNotice:Show() end
    else
        if self._noCraftersNotice then self._noCraftersNotice:Hide() end
    end

    -- Limita artesãos visíveis para garantir que jamais ultrapassem o limite inferior e colidam com o botão
    local maxVisibleCrafters = 4
    if totalBoxH > 140 then
        maxVisibleCrafters = 3
    end
    if totalBoxH > 160 then
        maxVisibleCrafters = 2
    end

    local numRows = #(self._crafterRows or {})
    for i = 1, numRows do
        local row = self._crafterRows[i]
        local cData = crafters[i]
        if cData and cData.member and i <= maxVisibleCrafters then
            local m = cData.member
            row.member = m

            local cTok = m:getClass()
            local cColor = CLASS_COLORS[cTok] and CLASS_COLORS[cTok].hex or "|cffffffff"
            local dispName = self:getMemberDisplayName(m)
            row.nameTxt:SetText(string.format("%s%s|r", cColor, dispName))
            row.rankTxt:SetText(string.format("Perícia: %d/%d", cData.rank or 0, cData.maxRank or 300))

            if cData.isOnline then
                row.statusDot:SetColorTexture(0.2, 1.0, 0.2, 1.0) -- Verde (Online)
            else
                row.statusDot:SetColorTexture(0.5, 0.5, 0.5, 1.0) -- Cinza (Offline)
            end

            row:Show()
        else
            row.member = nil
            row:Hide()
        end
    end
end

--- Exibe um tooltip rico e formatado para a receita ou item selecionado
---@param anchorFrame table
---@param recipe table
function ProfessionView:showRecipeTooltip(anchorFrame, recipe)
    if not recipe or not anchorFrame then return end
    GameTooltip:SetOwner(anchorFrame, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    local itemData = ProfessionData.getItemData(recipe)

    -- Tenta exibir o link nativo do item se já conhecido no cliente WoW
    local showedLink = false
    if recipe.itemId and _G.GetItemInfo then
        local _, itemLink = _G.GetItemInfo(recipe.itemId)
        if itemLink and GameTooltip.SetHyperlink then
            pcall(function() GameTooltip:SetHyperlink(itemLink) end)
            showedLink = (GameTooltip:NumLines() > 0)
        end
    end

    if not showedLink then
        local displayName = (itemData and itemData.name) or ProfessionData.getRecipeDisplayName(recipe)
        local rQ, gQ, bQ = (itemData and itemData.r or 1), (itemData and itemData.g or 1), (itemData and itemData.b or 1)
        GameTooltip:AddLine(displayName, rQ, gQ, bQ, true)

        local lineParts = {}
        if itemData and itemData.qualityName then table.insert(lineParts, itemData.qualityName) end
        if itemData and itemData.slot then table.insert(lineParts, itemData.slot) end
        if #lineParts > 0 then
            GameTooltip:AddLine(table.concat(lineParts, " - "), 0.8, 0.8, 0.8)
        end

        if itemData and itemData.armor and itemData.armor > 0 then
            GameTooltip:AddLine(string.format("%d Armadura", itemData.armor), 1, 1, 1)
        end

        if itemData and itemData.attrs and itemData.attrs ~= "" then
            GameTooltip:AddLine(itemData.attrs, 1, 1, 1, true)
        end

        if itemData and itemData.effects and itemData.effects ~= "" then
            GameTooltip:AddLine(itemData.effects, 0, 1, 0, true)
        end

        if itemData and itemData.reqLevel and itemData.reqLevel > 1 then
            GameTooltip:AddLine(string.format("Requer Nível %d", itemData.reqLevel), 1, 1, 1)
        end

        if itemData and itemData.desc and itemData.desc ~= "" then
            GameTooltip:AddLine(itemData.desc, 0.7, 0.7, 0.7, true)
        end

        if itemData and itemData.flavor and itemData.flavor ~= "" then
            GameTooltip:AddLine(string.format("\"%s\"", itemData.flavor), 1, 0.82, 0, true)
        end
    end

    -- Informações da Guilda no rodapé do tooltip
    GameTooltip:AddLine(" ")
    local pService = _G.GM and _G.GM.professionService
    local crafters = pService and pService:getCraftersForRecipe(recipe.prof or self._selectedProfKey, recipe) or {}
    if #crafters > 0 then
        GameTooltip:AddLine(string.format("|cffffd200Quem faz na guilda (%d):|r", #crafters))
        for _, c in ipairs(crafters) do
            local m = c.member
            local cTok = m:getClass()
            local cColor = CLASS_COLORS[cTok] and CLASS_COLORS[cTok].hex or "|cffffffff"
            local st = c.isOnline and "|cff00ff00[Online]|r" or "|cff888888[Offline]|r"
            local dispName = self:getMemberDisplayName(m)
            GameTooltip:AddLine(string.format("  %s %s%s|r (%d/%d)", st, cColor, dispName, c.rank or 0, c.maxRank or 300))
        end
    else
        GameTooltip:AddLine("|cff888888Nenhum membro da guilda conhece esta receita ainda.|r")
    end

    GameTooltip:Show()
end

--- Inicia um sussurro de chat para o artesão
---@param crafterName string
function ProfessionView:whisperCrafter(crafterName)
    if not crafterName or crafterName == "" then return end
    local rName = self._selectedRecipe and ProfessionData.getRecipeDisplayName(self._selectedRecipe) or "um item"
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    local msg = string.format(curL["WHISPER_ORDER_TEMPLATE"] or "Olá! Gostaria de encomendar %s com você. Você pode fabricar?", rName)

    -- No WoW, o comando /w só aceita o primeiro nome (base) do personagem
    local whisperTarget = crafterName:match("^[^-]+") or crafterName
    whisperTarget = (whisperTarget:match("^(%S+)") or whisperTarget):match("^%s*(.-)%s*$")

    if ChatFrame_OpenChat then
        ChatFrame_OpenChat(string.format("/w %s %s", whisperTarget, msg))
    end
end

-- =========================================================================
-- SUB-ABA 2: MURAL DE PEDIDOS DE FABRICAÇÃO
-- =========================================================================

function ProfessionView:createOrdersContainer()
    local frame = self._frame
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local curL = (_G.GM and _G.GM.L) or _G.L or L

    local container = CreateFrame("Frame", "GM_ProfOrdersContainer", frame)
    container:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -78)
    container:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 14)
    container:Hide()
    self._ordersContainer = container

    -- Barra Superior de Controle do Mural
    local topBar = CreateFrame("Frame", nil, container, template)
    topBar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    topBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    topBar:SetHeight(32)
    if topBar.SetBackdrop then
        topBar:SetBackdrop(SUB_CONTAINER_BACKDROP)
        topBar:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], 0.9)
        topBar:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], 0.9)
    end

    -- Filtros de Pedidos ("Todos os Pedidos", "Meus Pedidos", "Pedidos para Mim")
    local filterBtns = {
        { id = "ALL",    label = curL["ORDER_FILTER_ALL"] or "Todos os Pedidos", width = 130 },
        { id = "MINE",   label = curL["ORDER_FILTER_MINE"] or "Meus Pedidos", width = 120 },
        { id = "FOR_ME", label = curL["ORDER_FILTER_FOR_ME"] or "Pedidos para Mim", width = 130 },
    }
    self._orderFilterBtns = {}
    local prevFBtn = nil
    for _, fDef in ipairs(filterBtns) do
        local fBtn = CreateFrame("Button", nil, topBar, template)
        fBtn:SetSize(fDef.width or 120, 24)
        if not prevFBtn then
            fBtn:SetPoint("LEFT", topBar, "LEFT", 8, 0)
        else
            fBtn:SetPoint("LEFT", prevFBtn, "RIGHT", 6, 0)
        end
        if fBtn.SetBackdrop then
            fBtn:SetBackdrop(SUB_CONTAINER_BACKDROP)
            fBtn:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.80)
            fBtn:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.60)
        end
        local fTxt = fBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fTxt:SetPoint("CENTER", fBtn, "CENTER", 0, 0)
        fTxt:SetText(fDef.label)
        fBtn.text = fTxt
        fBtn.id = fDef.id
        fBtn:SetScript("OnClick", function()
            self._orderFilter = fDef.id
            self:refreshOrders()
        end)
        self._orderFilterBtns[fDef.id] = fBtn
        prevFBtn = fBtn
    end

    -- Inset da Tabela de Pedidos
    local tableInset = CreateFrame("Frame", nil, container, template)
    tableInset:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 0, -6)
    tableInset:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    if tableInset.SetBackdrop then
        tableInset:SetBackdrop(CONTAINER_BACKDROP)
        tableInset:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        tableInset:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end

    -- Cabeçalhos das Colunas da Tabela
    local cols = {
        { title = "Receita / Item",    x = 10,  width = 220 },
        { title = "Solicitante",       x = 235, width = 110 },
        { title = "Artesão",           x = 350, width = 110 },
        { title = "Qtd",               x = 465, width = 45 },
        { title = "Gorjeta / Comissão",x = 515, width = 100 },
        { title = "Status",            x = 620, width = 90 },
        { title = "Observações",       x = 715, width = 110 },
        { title = "Ações",             x = 830, width = 80 },
    }
    for _, c in ipairs(cols) do
        local hTxt = tableInset:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hTxt:SetPoint("TOPLEFT", tableInset, "TOPLEFT", c.x, -8)
        hTxt:SetText(c.title)
    end

    local hSep = tableInset:CreateTexture(nil, "ARTWORK")
    hSep:SetPoint("TOPLEFT", tableInset, "TOPLEFT", 6, -26)
    hSep:SetPoint("RIGHT", tableInset, "RIGHT", -6, 0)
    hSep:SetHeight(1)
    hSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    -- Linhas de Pedidos (12 linhas visíveis)
    self._orderRows = {}
    local NUM_ORDER_ROWS = 12
    local ORDER_ROW_H = 34
    for i = 1, NUM_ORDER_ROWS do
        local row = CreateFrame("Frame", nil, tableInset, template)
        row:SetSize(900, ORDER_ROW_H)
        row:SetPoint("TOPLEFT", tableInset, "TOPLEFT", 6, -30 - (i - 1) * (ORDER_ROW_H + 2))
        if row.SetBackdrop then
            row:SetBackdrop(SUB_CONTAINER_BACKDROP)
            row:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.8)
            row:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.5)
        end

        local oIcon = row:CreateTexture(nil, "ARTWORK")
        oIcon:SetSize(24, 24)
        oIcon:SetPoint("LEFT", row, "LEFT", 4, 0)
        oIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.icon = oIcon

        local rName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rName:SetPoint("LEFT", oIcon, "RIGHT", 6, 0)
        rName:SetWidth(185)
        rName:SetJustifyH("LEFT")
        row.recipeName = rName

        local reqTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        reqTxt:SetPoint("LEFT", row, "LEFT", 230, 0)
        reqTxt:SetWidth(105)
        reqTxt:SetJustifyH("LEFT")
        row.requesterTxt = reqTxt

        local crfTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        crfTxt:SetPoint("LEFT", row, "LEFT", 345, 0)
        crfTxt:SetWidth(105)
        crfTxt:SetJustifyH("LEFT")
        row.crafterTxt = crfTxt

        local qtyTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        qtyTxt:SetPoint("LEFT", row, "LEFT", 460, 0)
        qtyTxt:SetWidth(40)
        qtyTxt:SetJustifyH("CENTER")
        row.qtyTxt = qtyTxt

        local tipTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tipTxt:SetPoint("LEFT", row, "LEFT", 510, 0)
        tipTxt:SetWidth(95)
        tipTxt:SetJustifyH("LEFT")
        row.tipTxt = tipTxt

        local statusTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusTxt:SetPoint("LEFT", row, "LEFT", 615, 0)
        statusTxt:SetWidth(85)
        statusTxt:SetJustifyH("LEFT")
        row.statusTxt = statusTxt

        local notesTxt = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        notesTxt:SetPoint("LEFT", row, "LEFT", 710, 0)
        notesTxt:SetWidth(105)
        notesTxt:SetJustifyH("LEFT")
        row.notesTxt = notesTxt

        -- Botões de Ação na coluna Ações: Cancelar (X) e Aceitar / Concluir (Check)
        local cancelBtn = CreateFrame("Button", nil, row, template)
        cancelBtn:SetSize(24, 22)
        cancelBtn:SetPoint("CENTER", row, "RIGHT", -36, 0)
        if cancelBtn.SetBackdrop then cancelBtn:SetBackdrop(SUB_CONTAINER_BACKDROP) end

        local cIcon = cancelBtn:CreateTexture(nil, "ARTWORK")
        cIcon:SetSize(14, 14)
        cIcon:SetPoint("CENTER", cancelBtn, "CENTER", 0, 0)
        cIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
        cancelBtn.icon = cIcon

        local cTxt = cancelBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cTxt:SetPoint("CENTER", cancelBtn, "CENTER", 0, 0)
        cTxt:SetText("")
        cancelBtn.text = cTxt
        cancelBtn.actionType = "CANCEL"
        row.cancelBtn = cancelBtn

        local acceptBtn = CreateFrame("Button", nil, row, template)
        acceptBtn:SetSize(24, 22)
        acceptBtn:SetPoint("CENTER", row, "RIGHT", -36, 0)
        if acceptBtn.SetBackdrop then acceptBtn:SetBackdrop(SUB_CONTAINER_BACKDROP) end

        local aIcon = acceptBtn:CreateTexture(nil, "ARTWORK")
        aIcon:SetSize(14, 14)
        aIcon:SetPoint("CENTER", acceptBtn, "CENTER", 0, 0)
        aIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        acceptBtn.icon = aIcon

        local aIcon2 = acceptBtn:CreateTexture(nil, "ARTWORK")
        aIcon2:SetSize(12, 12)
        aIcon2:SetPoint("CENTER", acceptBtn, "CENTER", 4, 0)
        aIcon2:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        aIcon2:Hide()
        acceptBtn.icon2 = aIcon2

        local aTxt = acceptBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        aTxt:SetPoint("CENTER", acceptBtn, "CENTER", 0, 0)
        aTxt:SetText("")
        acceptBtn.text = aTxt
        acceptBtn.actionType = "ACCEPT"
        row.acceptBtn = acceptBtn

        -- Compatibilidade retroativa
        row.actBtn = cancelBtn

        row:Hide()
        self._orderRows[i] = row
    end
end

--- Obtém o nome completo (nome e sobrenome) do jogador local
---@return string
function ProfessionView:getLocalPlayerFullName()
    if _G.GM and _G.GM.memberController and _G.GM.memberController.resolvePlayerFullName then
        local full = _G.GM.memberController:resolvePlayerFullName()
        if full and full ~= "" and full:find("%s") then return full end
    end
    if _G.GM and _G.GM.memberService and _G.GM.memberService.resolvePlayerFullName then
        local full = _G.GM.memberService:resolvePlayerFullName()
        if full and full ~= "" and full:find("%s") then return full end
    end
    local myName = UnitName and UnitName("player") or ""
    if _G.GM and _G.GM.memberService and _G.GM.memberService.resolveFullName and myName ~= "" then
        local full = _G.GM.memberService:resolveFullName(myName)
        if full and full ~= "" and full:find("%s") then return full end
    end
    if GetNumGuildMembers and GetGuildRosterInfo then
        local num = GetNumGuildMembers() or 0
        local myBaseLower = myName:lower()
        for i = 1, num do
            local gName = GetGuildRosterInfo(i)
            if gName then
                local gClean = (gName:match("^[^-]+") or gName):match("^%s*(.-)%s*$") or gClean
                if gClean:find("%s") then
                    local first = gClean:match("^(%S+)") or gClean
                    if myBaseLower ~= "" and first:lower() == myBaseLower then
                        return gClean
                    end
                end
            end
        end
    end
    return myName
end

--- Obtém o nome formatado de exibição do membro (obrigatoriamente Nome e Sobrenome se disponível)
---@param member Member|string|nil
---@return string
function ProfessionView:getMemberDisplayName(member)
    if not member then return "" end
    local name = ""
    local mObj = nil

    if type(member) == "string" then
        name = cleanPlayerName(member)
        if _G.GM and _G.GM.memberService and _G.GM.memberService.getMember then
            mObj = _G.GM.memberService:getMember(name)
        end
        if not mObj and _G.GM and _G.GM.memberRepository and _G.GM.memberRepository.findByName then
            mObj = _G.GM.memberRepository:findByName(name)
        end
    elseif type(member) == "table" then
        mObj = member
        if member.getName then
            name = cleanPlayerName(member:getName())
        end
    end

    if name:find("%s") then
        return name
    end

    -- 1. Verifica se corresponde ao jogador local
    local myName = cleanPlayerName(UnitName and UnitName("player")):lower()
    local myGUID = UnitGUID and UnitGUID("player")
    local isMe = (name ~= "" and myName ~= "" and name:lower() == myName)
    if not isMe and myGUID and mObj and mObj.getGuid and mObj:getGuid() == myGUID then
        isMe = true
    end

    if isMe then
        local myFull = self:getLocalPlayerFullName()
        if myFull and myFull ~= "" and myFull:find("%s") then
            if mObj and mObj.setName then mObj:setName(myFull) end
            return myFull
        end
    end

    -- 2. Tenta resolver via MemberService:resolveFullName
    if _G.GM and _G.GM.memberService and _G.GM.memberService.resolveFullName and name ~= "" then
        local resolved = _G.GM.memberService:resolveFullName(name)
        if resolved and resolved ~= "" and resolved:find("%s") then
            if mObj and mObj.setName then mObj:setName(resolved) end
            return resolved
        end
    end

    -- 3. Tenta buscar no repositório de membros por primeiro nome
    local allMembers = nil
    if _G.GM and _G.GM.memberService and _G.GM.memberService.getAllMembers then
        allMembers = _G.GM.memberService:getAllMembers()
    elseif _G.GM and _G.GM.memberRepository and _G.GM.memberRepository.findAll then
        allMembers = _G.GM.memberRepository:findAll()
    end
    if allMembers and name ~= "" then
        local nLower = name:lower()
        for _, m in ipairs(allMembers) do
            local mName = m:getName() or ""
            if mName:find("%s") then
                local first = mName:match("^(%S+)") or mName
                if first:lower() == nLower then
                    if mObj and mObj.setName then mObj:setName(mName) end
                    return mName
                end
            end
        end
    end

    -- 4. Tenta buscar no Roster nativo da Blizzard
    if GetNumGuildMembers and GetGuildRosterInfo and name ~= "" then
        local num = GetNumGuildMembers() or 0
        local nLower = name:lower()
        for i = 1, num do
            local gName, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
            if gName then
                local gClean = (gName:match("^[^-]+") or gName):match("^%s*(.-)%s*$") or gClean
                if gClean:find("%s") then
                    if mObj and mObj.getGuid and guid and guid ~= "" and guid == mObj:getGuid() then
                        if mObj.setName then mObj:setName(gClean) end
                        return gClean
                    end
                    local first = gClean:match("^(%S+)") or gClean
                    if first:lower() == nLower then
                        if mObj and mObj.setName then mObj:setName(gClean) end
                        return gClean
                    end
                end
            end
        end
    end

    return name
end

--- Retorna o nome base e o nome completo do jogador local
---@return string, string
function ProfessionView:getLocalPlayerNames()
    local myName = cleanPlayerName(UnitName and UnitName("player")):lower()
    local myFullName = cleanPlayerName(self:getLocalPlayerFullName()):lower()
    return myName, myFullName
end

--- Verifica se um nome (simples, sobrenome ou completo) corresponde ao jogador local ou seus alts
---@param targetName string|nil
---@param myName string|nil
---@param myFullName string|nil
---@return boolean
function ProfessionView:matchesPlayer(targetName, myName, myFullName)
    if not targetName or targetName == "" then return false end
    if not myName or myName == "" then
        myName = cleanPlayerName(UnitName and UnitName("player")):lower()
    end
    if not myFullName or myFullName == "" then
        myFullName = cleanPlayerName(self:getLocalPlayerFullName()):lower()
    end

    local cleanTarget = cleanPlayerName(targetName):lower()
    if cleanTarget == "" then return false end

    -- 1. Correspondência exata direta
    if cleanTarget == myName or cleanTarget == myFullName then
        return true
    end

    -- 2. Primeiro nome
    local myFirst = myFullName:match("^(%S+)") or myName
    local targetFirst = cleanTarget:match("^(%S+)") or cleanTarget
    if targetFirst == myName or targetFirst == myFirst then
        if not cleanTarget:find("%s") or not myFullName:find("%s") then
            return true
        end
    end

    -- 3. Sobrenome
    local mySurname = myFullName:match("%s+(.+)$")
    local targetSurname = cleanTarget:match("%s+(.+)$")
    if mySurname and targetSurname and mySurname == targetSurname and myFirst == targetFirst then
        return true
    end
    if mySurname and not cleanTarget:find("%s") and cleanTarget == mySurname then
        return true
    end

    -- 4. Alts da família no MemberService
    if _G.GM and _G.GM.memberService and _G.GM.memberService.getMember and _G.GM.memberService.getAltFamily then
        local myMember = _G.GM.memberService:getMember(myFullName) or _G.GM.memberService:getMember(myName)
        if myMember then
            local family = _G.GM.memberService:getAltFamily(myMember)
            for _, fMember in ipairs(family or {}) do
                local fName = fMember:getName()
                if fName and fName ~= "" then
                    local fClean = cleanPlayerName(fName):lower()
                    if cleanTarget == fClean then
                        return true
                    end
                    local fFirst = fClean:match("^(%S+)") or fClean
                    if cleanTarget == fFirst then
                        return true
                    end
                end
            end
        end
    end

    return false
end

--- Retorna o nome formatado com a cor da classe do membro
---@param name string|nil
---@return string
function ProfessionView:getPlayerColoredName(name)
    if not name or name == "" then return "" end
    local clean = cleanPlayerName(name)
    local dispName = self:getMemberDisplayName(clean)
    local m = nil
    if _G.GM and _G.GM.memberService then
        if _G.GM.memberService.getMember then
            m = _G.GM.memberService:getMember(dispName) or _G.GM.memberService:getMember(clean)
        end
        if not m and _G.GM.memberService.resolveFullName then
            local resolved = _G.GM.memberService:resolveFullName(dispName)
            if resolved and resolved ~= "" and _G.GM.memberService.getMember then
                m = _G.GM.memberService:getMember(resolved)
                if m then dispName = resolved end
            end
        end
    end
    if not m and _G.GM and _G.GM.memberRepository and _G.GM.memberRepository.findByName then
        m = _G.GM.memberRepository:findByName(dispName) or _G.GM.memberRepository:findByName(clean)
    end

    if m and m.getClass then
        local cTok = m:getClass()
        local cColor = CLASS_COLORS[cTok] and CLASS_COLORS[cTok].hex or "|cffffffff"
        return string.format("%s%s|r", cColor, dispName ~= "" and dispName or (m:getName() or clean))
    end

    return string.format("|cffffffff%s|r", dispName ~= "" and dispName or clean)
end

--- Retorna os candidatos a artesão ordenados por relevância e perícia
---@param query string
---@param recipe table|nil
---@return table[] @Lista de { member = Member, rank = number, maxRank = number, isOnline = boolean, knowsRecipe = boolean, profKey = string }
function ProfessionView:getCrafterCandidates(query, recipe)
    local results = {}
    local seen = {}

    local qClean = (query:match("^[^-]+") or query or ""):match("^%s*(.-)%s*$") or ""
    local qLower = qClean:lower()

    local pService = _G.GM and _G.GM.professionService
    local mService = _G.GM and _G.GM.memberService
    local mRepo = _G.GM and _G.GM.memberRepository

    local profKey = recipe and (recipe.prof or self._selectedProfKey) or self._selectedProfKey

    -- 1. Candidatos prioritários: Membros que conhecem a receita
    if recipe and pService and pService.getCraftersForRecipe then
        local rCrafters = pService:getCraftersForRecipe(profKey, recipe) or {}
        for _, item in ipairs(rCrafters) do
            if item.member then
                local mName = item.member:getName()
                if mName and not seen[mName] then
                    seen[mName] = true
                    table.insert(results, {
                        member = item.member,
                        rank = item.rank or 0,
                        maxRank = item.maxRank or 300,
                        isOnline = item.isOnline == true,
                        knowsRecipe = true,
                        profKey = profKey,
                    })
                end
            end
        end
    end

    -- 2. Membros da guilda com a profissão relevante
    local allMembers = {}
    if mService and mService.getAllMembers then
        allMembers = mService:getAllMembers()
    elseif mRepo and mRepo.findAll then
        allMembers = mRepo:findAll()
    end

    for _, m in ipairs(allMembers) do
        local mName = m:getName()
        if mName and not seen[mName] then
            local prof = profKey and m.getProfession and m:getProfession(profKey)
            if prof then
                seen[mName] = true
                table.insert(results, {
                    member = m,
                    rank = prof.rank or 0,
                    maxRank = prof.maxRank or 300,
                    isOnline = m.isOnline and m:isOnline() == true,
                    knowsRecipe = false,
                    profKey = profKey,
                })
            end
        end
    end

    -- 3. Demais membros da guilda
    for _, m in ipairs(allMembers) do
        local mName = m:getName()
        if mName and not seen[mName] then
            seen[mName] = true
            table.insert(results, {
                member = m,
                rank = 0,
                maxRank = 300,
                isOnline = m.isOnline and m:isOnline() == true,
                knowsRecipe = false,
                profKey = profKey,
            })
        end
    end

    -- Se query for vazia, retorna os artesãos ordenados
    if qLower == "" then
        table.sort(results, function(a, b)
            if a.knowsRecipe ~= b.knowsRecipe then
                return a.knowsRecipe == true
            end
            if a.isOnline ~= b.isOnline then
                return a.isOnline == true
            end
            if a.rank ~= b.rank then
                return a.rank > b.rank
            end
            return (a.member:getName() or "") < (b.member:getName() or "")
        end)
        return results
    end

    -- Pontuação de correspondência por Nome e Sobrenome
    local scored = {}
    for _, cand in ipairs(results) do
        local m = cand.member
        local fullName = self:getMemberDisplayName(m)
        local cleanFull = (fullName:match("^[^-]+") or fullName):match("^%s*(.-)%s*$") or fullName
        local fLower = cleanFull:lower()

        local firstWord = cleanFull:match("^(%S+)") or cleanFull
        local firstLower = firstWord:lower()

        local surname = cleanFull:match("%s+(.+)$") or ""
        local surLower = surname:lower()

        local score = 0

        if fLower == qLower then
            score = 1000
        elseif firstLower == qLower then
            score = 800
        elseif surLower ~= "" and surLower == qLower then
            score = 750
        elseif fLower:sub(1, #qLower) == qLower then
            score = 600
        elseif firstLower:sub(1, #qLower) == qLower then
            score = 500
        elseif surLower ~= "" and surLower:sub(1, #qLower) == qLower then
            score = 450
        elseif fLower:find(qLower, 1, true) then
            score = 300
        elseif surLower ~= "" and surLower:find(qLower, 1, true) then
            score = 250
        end

        if score > 0 then
            if cand.knowsRecipe then
                score = score + 200
            end
            if cand.rank and cand.rank > 0 then
                score = score + 50 + math.min(cand.rank, 300) * 0.1
            end
            if cand.isOnline then
                score = score + 20
            end

            table.insert(scored, { candidate = cand, score = score })
        end
    end

    table.sort(scored, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        local aName = self:getMemberDisplayName(a.candidate.member)
        local bName = self:getMemberDisplayName(b.candidate.member)
        return aName < bName
    end)

    local sorted = {}
    for _, sc in ipairs(scored) do
        table.insert(sorted, sc.candidate)
    end

    return sorted
end

--- Resolve o texto informado para o nome canônico (nome e sobrenome) do artesão
---@param query string|nil
---@param recipe table|nil
---@return string
function ProfessionView:resolveCrafterName(query, recipe)
    if not query or query == "" then return "" end
    local qClean = (query:match("^[^-]+") or query):match("^%s*(.-)%s*$") or ""
    if qClean == "" then return "" end

    local candidates = self:getCrafterCandidates(qClean, recipe or self._modalTargetRecipe)
    if candidates and #candidates > 0 then
        local best = candidates[1]
        local m = best.member
        if m then
            return self:getMemberDisplayName(m)
        end
    end

    if _G.GM and _G.GM.memberService and _G.GM.memberService.resolveFullName then
        local resolved = _G.GM.memberService:resolveFullName(qClean)
        if resolved and resolved ~= "" then
            return resolved
        end
    end

    return self:getMemberDisplayName(qClean)
end

--- Atualiza a legenda de validação do artesão no modal
---@param text string|nil
---@param recipe table|nil
function ProfessionView:updateCrafterFeedback(text, recipe)
    if not self._modalCrafterFeedback then return end
    local clean = (text:match("^[^-]+") or text or ""):match("^%s*(.-)%s*$") or ""
    if clean == "" then
        self._modalCrafterFeedback:SetText("|cffaaaaaa(Aberto para qualquer artesão da guilda)|r")
        return
    end

    local candidates = self:getCrafterCandidates(clean, recipe or self._modalTargetRecipe)
    if candidates and #candidates > 0 then
        local best = candidates[1]
        local m = best.member
        local cTok = m and m.getClass and m:getClass() or ""
        local cColor = CLASS_COLORS[cTok] and CLASS_COLORS[cTok].hex or "|cffffd200"
        local nameStr = self:getMemberDisplayName(m or clean)
        local profStr = ""
        if best.knowsRecipe then
            profStr = string.format(" |cff00ff00✓ Conhece a receita (%d/%d)|r", best.rank or 0, best.maxRank or 300)
        elseif best.rank and best.rank > 0 then
            profStr = string.format(" |cffffff00(%d/%d)|r", best.rank, best.maxRank or 300)
        end
        self._modalCrafterFeedback:SetText(string.format("Direcionado a: %s%s|r%s", cColor, nameStr, profStr))
    else
        self._modalCrafterFeedback:SetText("|cffff4444✗ Nenhum artesão ou membro encontrado|r")
    end
end

--- Atualiza as sugestões suspensas do autocompletar de artesãos
---@param text string|nil
function ProfessionView:updateCrafterSuggestions(text)
    if not self._modalSuggestFrame then return end
    local clean = (text:match("^[^-]+") or text or ""):match("^%s*(.-)%s*$") or ""
    if clean == "" then
        self._modalSuggestFrame:Hide()
        return
    end

    local candidates = self:getCrafterCandidates(clean, self._modalTargetRecipe)
    if not candidates or #candidates == 0 then
        self._modalSuggestFrame:Hide()
        return
    end

    local count = math.min(#candidates, 4)
    for i = 1, 4 do
        local row = self._modalSuggestRows[i]
        if i <= count then
            local cand = candidates[i]
            local m = cand.member
            row.candidate = cand

            local cTok = m and m.getClass and m:getClass() or ""
            local cColor = CLASS_COLORS[cTok] and CLASS_COLORS[cTok].hex or "|cffffffff"
            local mName = self:getMemberDisplayName(m)

            row.nameTxt:SetText(string.format("%s%s|r", cColor, mName))

            if cand.knowsRecipe then
                row.infoTxt:SetText(string.format("|cff00ff00Conhece (%d/%d)|r", cand.rank or 0, cand.maxRank or 300))
            elseif cand.rank and cand.rank > 0 then
                row.infoTxt:SetText(string.format("|cffffff00Perícia %d/%d|r", cand.rank, cand.maxRank or 300))
            else
                row.infoTxt:SetText("|cff888888Membro|r")
            end

            if cand.isOnline then
                row.dot:SetColorTexture(0.2, 1.0, 0.2, 1.0)
            else
                row.dot:SetColorTexture(0.5, 0.5, 0.5, 1.0)
            end

            row:Show()
        else
            row.candidate = nil
            row:Hide()
        end
    end

    self._modalSuggestFrame:SetHeight(14 + count * 24)
    self._modalSuggestFrame:Show()
end

--- Atualiza a exibição da lista de pedidos
function ProfessionView:refreshOrders()
    local pService = _G.GM and _G.GM.professionService
    if not pService then return end

    local myName, myFullName = self:getLocalPlayerNames()
    local all = pService:getAllOrders()
    local filtered = {}

    for _, ord in ipairs(all) do
        local status = ord:getStatus()
        -- Pedidos cancelados são removidos da lista
        if status ~= CraftOrder.STATUS.CANCELLED then
            local isRequester = self:matchesPlayer(ord:getRequester(), myName, myFullName)
            local isDirectedToMe = self:matchesPlayer(ord:getCrafter(), myName, myFullName)
            local isAcceptedByMe = self:matchesPlayer(ord:getAcceptedBy(), myName, myFullName)

            local matches = false
            if self._orderFilter == "ALL" then
                matches = (status == CraftOrder.STATUS.PENDING)
            elseif self._orderFilter == "MINE" then
                matches = isRequester
            elseif self._orderFilter == "FOR_ME" then
                if isDirectedToMe or isAcceptedByMe then
                    matches = true
                elseif ord:isOpenToGuild() and not isRequester and status == CraftOrder.STATUS.PENDING then
                    matches = true
                end
            end

            if matches then
                table.insert(filtered, ord)
            end
        end
    end

    -- Ordena os pedidos mais recentes primeiro
    table.sort(filtered, function(a, b)
        return (a:getUpdatedAt() or 0) > (b:getUpdatedAt() or 0)
    end)

    self._filteredOrders = filtered

    -- Atualiza botões de filtro com destaque ativo
    for fId, btn in pairs(self._orderFilterBtns or {}) do
        local isActive = (fId == self._orderFilter)
        if btn.SetBackdropColor and btn.SetBackdropBorderColor then
            if isActive then
                btn:SetBackdropColor(PALETTE.ACTIVE_TAB_BG[1], PALETTE.ACTIVE_TAB_BG[2], PALETTE.ACTIVE_TAB_BG[3], 0.95)
                btn:SetBackdropBorderColor(PALETTE.ACTIVE_TAB_BORDER[1], PALETTE.ACTIVE_TAB_BORDER[2], PALETTE.ACTIVE_TAB_BORDER[3], 1.0)
                if btn.text then btn.text:SetTextColor(1.0, 0.85, 0.20, 1.0) end
            else
                btn:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.80)
                btn:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.60)
                if btn.text then btn.text:SetTextColor(0.85, 0.85, 0.85, 1.0) end
            end
        end
    end

    self:renderOrderRows()
end

--- Renderiza as linhas visíveis do mural de pedidos
function ProfessionView:renderOrderRows()
    local myName, myFullName = self:getLocalPlayerNames()

    for i = 1, 12 do
        local row = self._orderRows[i]
        local order = self._filteredOrders[i]
        if order then
            row.orderData = order

            row.icon:SetTexture(order:getRecipeIcon())
            row.recipeName:SetText(order:getRecipeName())
            row.requesterTxt:SetText(self:getPlayerColoredName(order:getRequester()))

            if order:isOpenToGuild() then
                local who = order:getAcceptedBy()
                if who and who ~= "" then
                    row.crafterTxt:SetText(self:getPlayerColoredName(who))
                else
                    row.crafterTxt:SetText("|cffffd200Qualquer Artesão|r")
                end
            else
                row.crafterTxt:SetText(self:getPlayerColoredName(order:getCrafter()))
            end

            row.qtyTxt:SetText(string.format("x%d", order:getItemCount()))
            row.tipTxt:SetText(order:getFormattedTip())

            local status = order:getStatus()
            if status == CraftOrder.STATUS.PENDING then
                row.statusTxt:SetText("|cffffcc00Pendente|r")
            elseif status == CraftOrder.STATUS.IN_PROGRESS then
                row.statusTxt:SetText("|cff00ccffPreparando|r")
            elseif status == CraftOrder.STATUS.COMPLETED then
                row.statusTxt:SetText("|cff00ff00Concluído|r")
            elseif status == CraftOrder.STATUS.CANCELLED then
                row.statusTxt:SetText("|cff888888Cancelado|r")
            end

            row.notesTxt:SetText(order:getNotes() ~= "" and order:getNotes() or "-")

            -- Configura botões de ação (X para cancelar, Check para aceitar / concluir)
            local isRequester = self:matchesPlayer(order:getRequester(), myName, myFullName)
            local isDirectedToMe = self:matchesPlayer(order:getCrafter(), myName, myFullName)
            local isAcceptedByMe = self:matchesPlayer(order:getAcceptedBy(), myName, myFullName)

            local canCancel = false
            local canAccept = false
            local isCompleteAction = false
            local isRefuseAction = false

            if status == CraftOrder.STATUS.PENDING then
                -- Pode aceitar se o pedido for aberto para a guilda ou direcionado ao jogador
                if order:isOpenToGuild() or isDirectedToMe then
                    canAccept = true
                end

                -- Solicitante pode cancelar
                if isRequester then
                    canCancel = true
                    isRefuseAction = false
                elseif isDirectedToMe then
                    -- Artesão direcionado pode recusar
                    canCancel = true
                    isRefuseAction = true
                end
            elseif status == CraftOrder.STATUS.IN_PROGRESS then
                if isAcceptedByMe or isDirectedToMe then
                    canAccept = true
                    isCompleteAction = true
                end
                if isRequester then
                    canCancel = true
                    isRefuseAction = false
                end
            end

            -- Posicionamento dos botões (lado a lado se ambos existirem, ou centralizado na coluna Ações)
            if canCancel and canAccept then
                row.cancelBtn:ClearAllPoints()
                row.cancelBtn:SetPoint("RIGHT", row, "RIGHT", -10, 0)
                row.acceptBtn:ClearAllPoints()
                row.acceptBtn:SetPoint("RIGHT", row.cancelBtn, "LEFT", -6, 0)
            else
                row.cancelBtn:ClearAllPoints()
                row.cancelBtn:SetPoint("CENTER", row, "RIGHT", -36, 0)
                row.acceptBtn:ClearAllPoints()
                row.acceptBtn:SetPoint("CENTER", row, "RIGHT", -36, 0)
            end

            if canCancel then
                row.cancelBtn.isRefuseAction = isRefuseAction
                if row.cancelBtn.icon then
                    row.cancelBtn.icon:Show()
                    row.cancelBtn.text:SetText("")
                else
                    row.cancelBtn.text:SetText("|cffff4444X|r")
                end
                row.cancelBtn:SetScript("OnEnter", function(btn)
                    if btn.SetBackdropBorderColor then
                        btn:SetBackdropBorderColor(1.0, 0.3, 0.3, 1.0)
                    end
                    if GameTooltip then
                        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                        if btn.isRefuseAction then
                            GameTooltip:SetText("|cffff4444Recusar Pedido|r")
                            GameTooltip:AddLine("Clique para recusar este pedido e liberá-lo para a guilda.", 1, 1, 1, true)
                        else
                            GameTooltip:SetText("|cffff4444Cancelar Pedido|r")
                            GameTooltip:AddLine("Clique para cancelar e remover este pedido do mural.", 1, 1, 1, true)
                        end
                        GameTooltip:Show()
                    end
                end)
                row.cancelBtn:SetScript("OnLeave", function(btn)
                    if btn.SetBackdropBorderColor then
                        btn:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.70)
                    end
                    if GameTooltip then GameTooltip:Hide() end
                end)
                row.cancelBtn:SetScript("OnClick", function(btn)
                    if GameTooltip then GameTooltip:Hide() end
                    if _G.GM and _G.GM.professionService then
                        if btn.isRefuseAction and _G.GM.professionService.declineOrder then
                            _G.GM.professionService:declineOrder(order:getId())
                        else
                            _G.GM.professionService:cancelOrder(order:getId())
                        end
                        self:refreshOrders()
                    end
                end)
                row.cancelBtn:Show()
                row.actBtn = row.cancelBtn
            else
                row.cancelBtn:Hide()
            end

            if canAccept then
                row.acceptBtn.isCompleteAction = isCompleteAction
                if row.acceptBtn.text then
                    row.acceptBtn.text:SetText("")
                end

                if isCompleteAction then
                    -- Botão Concluir Pedido: 2 checks azuis
                    if row.acceptBtn.icon then
                        row.acceptBtn.icon:ClearAllPoints()
                        row.acceptBtn.icon:SetPoint("CENTER", row.acceptBtn, "CENTER", -4, 0)
                        row.acceptBtn.icon:SetSize(12, 12)
                        row.acceptBtn.icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
                        if row.acceptBtn.icon.SetVertexColor then
                            row.acceptBtn.icon:SetVertexColor(0.0, 0.75, 1.0, 1.0)
                        end
                        row.acceptBtn.icon:Show()
                    end
                    if row.acceptBtn.icon2 then
                        row.acceptBtn.icon2:ClearAllPoints()
                        row.acceptBtn.icon2:SetPoint("CENTER", row.acceptBtn, "CENTER", 4, 0)
                        row.acceptBtn.icon2:SetSize(12, 12)
                        row.acceptBtn.icon2:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
                        if row.acceptBtn.icon2.SetVertexColor then
                            row.acceptBtn.icon2:SetVertexColor(0.0, 0.75, 1.0, 1.0)
                        end
                        row.acceptBtn.icon2:Show()
                    end
                else
                    -- Botão Aceitar Pedido: 1 check verde padrão
                    if row.acceptBtn.icon then
                        row.acceptBtn.icon:ClearAllPoints()
                        row.acceptBtn.icon:SetPoint("CENTER", row.acceptBtn, "CENTER", 0, 0)
                        row.acceptBtn.icon:SetSize(14, 14)
                        row.acceptBtn.icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
                        if row.acceptBtn.icon.SetVertexColor then
                            row.acceptBtn.icon:SetVertexColor(1.0, 1.0, 1.0, 1.0)
                        end
                        row.acceptBtn.icon:Show()
                    end
                    if row.acceptBtn.icon2 then
                        row.acceptBtn.icon2:Hide()
                    end
                end

                row.acceptBtn:SetScript("OnEnter", function(btn)
                    if btn.SetBackdropBorderColor then
                        if btn.isCompleteAction then
                            btn:SetBackdropBorderColor(0.0, 0.75, 1.0, 1.0)
                        else
                            btn:SetBackdropBorderColor(0.2, 1.0, 0.2, 1.0)
                        end
                    end
                    if GameTooltip then
                        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                        if btn.isCompleteAction then
                            GameTooltip:SetText("|cff00ccffConcluir Pedido|r")
                            GameTooltip:AddLine("Clique para marcar este pedido como fabricado e entregue.", 1, 1, 1, true)
                        else
                            GameTooltip:SetText("|cff00ff00Aceitar Pedido|r")
                            GameTooltip:AddLine("Clique para aceitar fabricar este pedido para o solicitante.", 1, 1, 1, true)
                        end
                        GameTooltip:Show()
                    end
                end)
                row.acceptBtn:SetScript("OnLeave", function(btn)
                    if btn.SetBackdropBorderColor then
                        btn:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.70)
                    end
                    if GameTooltip then GameTooltip:Hide() end
                end)
                row.acceptBtn:SetScript("OnClick", function()
                    if GameTooltip then GameTooltip:Hide() end
                    if _G.GM and _G.GM.professionService then
                        if isCompleteAction then
                            _G.GM.professionService:completeOrder(order:getId())
                        else
                            _G.GM.professionService:acceptOrder(order:getId(), self:getLocalPlayerFullName())
                        end
                        self:refreshOrders()
                    end
                end)
                row.acceptBtn:Show()
                if not canCancel then
                    row.actBtn = row.acceptBtn
                end
            else
                row.acceptBtn:Hide()
                if row.acceptBtn.icon2 then row.acceptBtn.icon2:Hide() end
            end

            if not canCancel and not canAccept then
                row.actBtn = row.cancelBtn
                row.actBtn:Hide()
            end

            row:Show()
        else
            row.orderData = nil
            if row.cancelBtn then row.cancelBtn:Hide() end
            if row.acceptBtn then row.acceptBtn:Hide() end
            row:Hide()
        end
    end
end

-- =========================================================================
-- SUB-ABA 3: MINHAS PROFISSÕES & STATUS LOCAL
-- =========================================================================

function ProfessionView:createMyProfessionsContainer()
    local frame = self._frame
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local curL = (_G.GM and _G.GM.L) or _G.L or L

    local container = CreateFrame("Frame", "GM_ProfMyProfsContainer", frame)
    container:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -78)
    container:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 14)
    container:Hide()
    self._myProfsContainer = container

    local card = CreateFrame("Frame", nil, container, template)
    card:SetPoint("TOPLEFT", container, "TOPLEFT", 40, -30)
    card:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -40, 40)
    if card.SetBackdrop then
        card:SetBackdrop(CONTAINER_BACKDROP)
        card:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        card:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end

    local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", card, "TOPLEFT", 20, -20)
    title:SetText(curL["MY_PROF_TITLE"] or "Minhas Profissões & Receitas Aprendidas")

    local hint = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    hint:SetPoint("RIGHT", card, "RIGHT", -20, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(curL["MY_PROF_SCAN_HINT"] or "Abra a sua janela de profissão no jogo (Alquimia, Ferraria, etc.) para registrar automaticamente todas as suas receitas!")

    local scanBtn = CreateFrame("Button", nil, card, template)
    scanBtn:SetSize(240, 32)
    scanBtn:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -16)
    if scanBtn.SetBackdrop then
        scanBtn:SetBackdrop(SUB_CONTAINER_BACKDROP)
        scanBtn:SetBackdropColor(PALETTE.FOCUS_BG[1], PALETTE.FOCUS_BG[2], PALETTE.FOCUS_BG[3], 0.95)
        scanBtn:SetBackdropBorderColor(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], 1.0)
    end
    local scanTxt = scanBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scanTxt:SetPoint("CENTER", scanBtn, "CENTER", 0, 0)
    scanTxt:SetText(curL["MY_PROF_SCAN_BTN"] or "Escanear Minhas Profissões Agora")
    scanBtn.text = scanTxt
    scanBtn:SetScript("OnClick", function()
        if _G.GM and _G.GM.professionService then
            local count = _G.GM.professionService:scanAll()
            print(string.format("|cff00ff00[GuildManager]|r Escaneamento concluído! %d profissão(ões) detectada(s).", count))
            self:refresh()
        end
    end)
    self._scanBtn = scanBtn

    -- Área informativa das profissões detectadas
    local statusCard = CreateFrame("Frame", nil, card, template)
    statusCard:SetPoint("TOPLEFT", scanBtn, "BOTTOMLEFT", 0, -20)
    statusCard:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -20, 20)
    if statusCard.SetBackdrop then
        statusCard:SetBackdrop(SUB_CONTAINER_BACKDROP)
        statusCard:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.8)
        statusCard:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.6)
    end

    local statusTitle = statusCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusTitle:SetPoint("TOPLEFT", statusCard, "TOPLEFT", 16, -16)
    statusTitle:SetText(curL["MY_PROF_DETECTED"] or "Profissões Primárias Detectadas:")

    local statusDetails = statusCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    statusDetails:SetPoint("TOPLEFT", statusTitle, "BOTTOMLEFT", 0, -12)
    statusDetails:SetPoint("RIGHT", statusCard, "RIGHT", -16, 0)
    statusDetails:SetJustifyH("LEFT")
    statusDetails:SetText("Carregando informações locais...")
    self._myProfsStatusDetails = statusDetails
end

--- Atualiza a exibição de Minhas Profissões
function ProfessionView:refreshMyProfessions()
    local pService = _G.GM and _G.GM.professionService
    if not pService or not self._myProfsStatusDetails then return end

    local member = pService:getLocalPlayerMember()
    if not member then
        self._myProfsStatusDetails:SetText("|cffaaaaaaPersonagem local não encontrado no banco de dados.|r")
        return
    end

    local profs = member:getProfessions()
    local parts = {}

    for _, profKey in ipairs(ProfessionData.ORDER) do
        local pData = profs[profKey]
        if pData and (pData.rank or 0) > 0 then
            local def = ProfessionData.PROFESSIONS[profKey]
            local recipeCount = 0
            if type(pData.recipes) == "table" then
                local counted = {}
                for rKey, val in pairs(pData.recipes) do
                    if val == true then
                        local canonId = rKey
                        local num = tonumber(rKey)
                        if num then canonId = num end
                        local rDef = ProfessionData.getRecipeById(rKey, profKey)
                        if rDef and rDef.id then canonId = rDef.id end
                        if not counted[canonId] then
                            counted[canonId] = true
                            recipeCount = recipeCount + 1
                        end
                    end
                end
            end
            table.insert(parts, string.format("• |T%s:20:20:0:0|t |cffffd200%s:|r Perícia |cffffff00%d / %d|r — |cff00ff00%d receita(s) aprendida(s)|r",
                def.icon, def.name, pData.rank or 0, pData.maxRank or 300, recipeCount))
        end
    end

    -- Se nenhuma profissão estiver salva em memória ainda, executa scanAll uma vez automaticamente
    if #parts == 0 and not self._didInitialMyProfScan then
        self._didInitialMyProfScan = true
        local detected = pService:scanAll()
        if detected > 0 then
            profs = member:getProfessions()
            for _, profKey in ipairs(ProfessionData.ORDER) do
                local pData = profs[profKey]
                if pData and (pData.rank or 0) > 0 then
                    local def = ProfessionData.PROFESSIONS[profKey]
                    local recipeCount = 0
                    if type(pData.recipes) == "table" then
                        local counted = {}
                        for rKey, val in pairs(pData.recipes) do
                            if val == true then
                                local canonId = rKey
                                local num = tonumber(rKey)
                                if num then canonId = num end
                                local rDef = ProfessionData.getRecipeById(rKey, profKey)
                                if rDef and rDef.id then canonId = rDef.id end
                                if not counted[canonId] then
                                    counted[canonId] = true
                                    recipeCount = recipeCount + 1
                                end
                            end
                        end
                    end
                    table.insert(parts, string.format("• |T%s:20:20:0:0|t |cffffd200%s:|r Perícia |cffffff00%d / %d|r — |cff00ff00%d receita(s) aprendida(s)|r",
                        def.icon, def.name, pData.rank or 0, pData.maxRank or 300, recipeCount))
                end
            end
        end
    end

    if #parts == 0 then
        self._myProfsStatusDetails:SetText("|cffaaaaaaNenhuma profissão primária de fabricação foi detectada ainda.\nAbra as perícias do seu personagem (atalho K) ou a janela de profissão para registrar automaticamente!|r")
    else
        self._myProfsStatusDetails:SetText(table.concat(parts, "\n\n"))
    end
end

-- =========================================================================
-- MODAL DE NOVO PEDIDO DE PROFISSÃO
-- =========================================================================

function ProfessionView:createOrderModal()
    local frame = self._frame
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local curL = (_G.GM and _G.GM.L) or _G.L or L

    local modal = CreateFrame("Frame", "GM_ProfOrderModal", frame, template)
    modal:SetSize(460, 420)
    modal:SetPoint("CENTER", frame, "CENTER", 0, 0)
    modal:SetFrameStrata("FULLSCREEN_DIALOG")
    modal:EnableMouse(true)
    if modal.SetBackdrop then
        modal:SetBackdrop(DIALOG_BACKDROP)
        modal:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], 0.98)
        modal:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], 1.0)
    end
    modal:SetScript("OnMouseDown", function()
        if self._modalSuggestFrame then self._modalSuggestFrame:Hide() end
    end)
    modal:Hide()
    self._orderModal = modal

    local mTitle = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mTitle:SetPoint("TOPLEFT", modal, "TOPLEFT", 16, -16)
    mTitle:SetText(curL["ORDER_MODAL_TITLE"] or "Novo Pedido de Profissão")

    local mClose = CreateFrame("Button", nil, modal, "UIPanelCloseButton")
    mClose:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -4, -4)
    mClose:SetScript("OnClick", function()
        if self._modalSuggestFrame then self._modalSuggestFrame:Hide() end
        modal:Hide()
    end)

    -- Item / Receita selecionada
    local rLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rLabel:SetPoint("TOPLEFT", mTitle, "BOTTOMLEFT", 0, -14)
    rLabel:SetText("|cffffd200Receita / Item Solicitado:|r")

    local rPreview = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rPreview:SetPoint("TOPLEFT", rLabel, "BOTTOMLEFT", 0, -4)
    rPreview:SetText("Nome do Item")
    self._modalRecipePreview = rPreview

    -- Artesão direcionado
    local cLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cLabel:SetPoint("TOPLEFT", rPreview, "BOTTOMLEFT", 0, -12)
    cLabel:SetText("|cffffd200Artesão Direcionado (deixe em branco para aberto à guilda):|r")

    local cBox = CreateFrame("EditBox", nil, modal, template)
    cBox:SetPoint("TOPLEFT", cLabel, "BOTTOMLEFT", 0, -4)
    cBox:SetSize(420, 24)
    cBox:SetFontObject("GameFontHighlightSmall")
    cBox:SetTextInsets(6, 6, 0, 0)
    if cBox.SetBackdrop then
        cBox:SetBackdrop(SUB_CONTAINER_BACKDROP)
        cBox:SetBackdropColor(0, 0, 0, 0.8)
    end
    cBox:SetAutoFocus(false)
    self._modalCrafterBox = cBox

    -- Legenda de validação / feedback do artesão direcionado
    local cFeedback = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cFeedback:SetPoint("TOPLEFT", cBox, "BOTTOMLEFT", 2, -3)
    cFeedback:SetWidth(416)
    cFeedback:SetJustifyH("LEFT")
    cFeedback:SetText("|cffaaaaaa(Aberto para qualquer artesão da guilda)|r")
    self._modalCrafterFeedback = cFeedback

    -- Quantidade
    local qLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qLabel:SetPoint("TOPLEFT", cFeedback, "BOTTOMLEFT", -2, -10)
    qLabel:SetText("|cffffd200Quantidade:|r")

    local qBox = CreateFrame("EditBox", nil, modal, template)
    qBox:SetPoint("TOPLEFT", qLabel, "BOTTOMLEFT", 0, -4)
    qBox:SetSize(80, 24)
    qBox:SetFontObject("GameFontHighlightSmall")
    qBox:SetTextInsets(6, 6, 0, 0)
    qBox:SetNumeric(true)
    qBox:SetText("1")
    if qBox.SetBackdrop then
        qBox:SetBackdrop(SUB_CONTAINER_BACKDROP)
        qBox:SetBackdropColor(0, 0, 0, 0.8)
    end
    qBox:SetAutoFocus(false)
    self._modalQtyBox = qBox

    -- Comissão / Gorjeta em Ouro
    local tipLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tipLabel:SetPoint("LEFT", qLabel, "RIGHT", 80, 0)
    tipLabel:SetText("|cffffd200Gorjeta / Comissão (Ouro):|r")

    local tipBox = CreateFrame("EditBox", nil, modal, template)
    tipBox:SetPoint("TOPLEFT", tipLabel, "BOTTOMLEFT", 0, -4)
    tipBox:SetSize(120, 24)
    tipBox:SetFontObject("GameFontHighlightSmall")
    tipBox:SetTextInsets(6, 6, 0, 0)
    tipBox:SetNumeric(true)
    tipBox:SetText("0")
    if tipBox.SetBackdrop then
        tipBox:SetBackdrop(SUB_CONTAINER_BACKDROP)
        tipBox:SetBackdropColor(0, 0, 0, 0.8)
    end
    tipBox:SetAutoFocus(false)
    self._modalTipBox = tipBox

    -- Observações
    local nLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nLabel:SetPoint("TOPLEFT", qBox, "BOTTOMLEFT", 0, -12)
    nLabel:SetText("|cffffd200Observações (ex: levo todos os materiais):|r")

    local nBox = CreateFrame("EditBox", nil, modal, template)
    nBox:SetPoint("TOPLEFT", nLabel, "BOTTOMLEFT", 0, -4)
    nBox:SetSize(420, 26)
    nBox:SetFontObject("GameFontHighlightSmall")
    nBox:SetTextInsets(6, 6, 0, 0)
    if nBox.SetBackdrop then
        nBox:SetBackdrop(SUB_CONTAINER_BACKDROP)
        nBox:SetBackdropColor(0, 0, 0, 0.8)
    end
    nBox:SetAutoFocus(false)
    self._modalNotesBox = nBox

    -- Botão Confirmar
    local confirmBtn = CreateFrame("Button", nil, modal, template)
    confirmBtn:SetSize(160, 28)
    confirmBtn:SetPoint("BOTTOMLEFT", modal, "BOTTOMLEFT", 50, 16)
    if confirmBtn.SetBackdrop then
        confirmBtn:SetBackdrop(SUB_CONTAINER_BACKDROP)
        confirmBtn:SetBackdropColor(PALETTE.FOCUS_BG[1], PALETTE.FOCUS_BG[2], PALETTE.FOCUS_BG[3], 0.95)
        confirmBtn:SetBackdropBorderColor(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], 1.0)
    end
    local cTxt = confirmBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cTxt:SetPoint("CENTER", confirmBtn, "CENTER", 0, 0)
    cTxt:SetText(curL["ORDER_MODAL_CONFIRM"] or "Confirmar Pedido")
    confirmBtn:SetScript("OnClick", function()
        self:submitOrder()
    end)

    -- Botão Cancelar
    local cancelBtn = CreateFrame("Button", nil, modal, template)
    cancelBtn:SetSize(120, 28)
    cancelBtn:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -50, 16)
    if cancelBtn.SetBackdrop then cancelBtn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
    local canTxt = cancelBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    canTxt:SetPoint("CENTER", cancelBtn, "CENTER", 0, 0)
    canTxt:SetText(curL["CANCEL"] or "Cancelar")
    cancelBtn:SetScript("OnClick", function()
        if self._modalSuggestFrame then self._modalSuggestFrame:Hide() end
        modal:Hide()
    end)

    -- Frame flutuante de sugestões de autocompletar artesãos
    local suggestFrame = CreateFrame("Frame", "GM_ProfOrderSuggestFrame", modal, template)
    suggestFrame:SetSize(420, 110)
    suggestFrame:SetPoint("TOPLEFT", cBox, "BOTTOMLEFT", 0, -2)
    suggestFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    local baseLevel = (modal.GetFrameLevel and tonumber(modal:GetFrameLevel())) or 1
    if suggestFrame.SetFrameLevel then
        suggestFrame:SetFrameLevel(baseLevel + 20)
    end
    suggestFrame:EnableMouse(true)
    if suggestFrame.SetBackdrop then
        suggestFrame:SetBackdrop(DIALOG_BACKDROP)
        suggestFrame:SetBackdropColor(0.04, 0.025, 0.01, 0.98)
        suggestFrame:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], 1.0)
    end
    suggestFrame:Hide()
    self._modalSuggestFrame = suggestFrame

    self._modalSuggestRows = {}
    local NUM_SUGGEST_ROWS = 4
    local SUGGEST_ROW_H = 24
    for i = 1, NUM_SUGGEST_ROWS do
        local sRow = CreateFrame("Button", nil, suggestFrame, template)
        sRow:SetSize(406, SUGGEST_ROW_H)
        sRow:SetPoint("TOPLEFT", suggestFrame, "TOPLEFT", 7, -7 - (i - 1) * SUGGEST_ROW_H)
        if sRow.SetBackdrop then
            sRow:SetBackdrop(SUB_CONTAINER_BACKDROP)
            sRow:SetBackdropColor(0.02, 0.015, 0.005, 0.8)
            sRow:SetBackdropBorderColor(0.4, 0.3, 0.1, 0.6)
        end

        local sDot = sRow:CreateTexture(nil, "ARTWORK")
        sDot:SetSize(8, 8)
        sDot:SetPoint("LEFT", sRow, "LEFT", 6, 0)
        sDot:SetColorTexture(0, 1, 0, 1)
        sRow.dot = sDot

        local sName = sRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sName:SetPoint("LEFT", sDot, "RIGHT", 6, 0)
        sName:SetJustifyH("LEFT")
        sRow.nameTxt = sName

        local sInfo = sRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        sInfo:SetPoint("RIGHT", sRow, "RIGHT", -6, 0)
        sInfo:SetJustifyH("RIGHT")
        sRow.infoTxt = sInfo

        sRow:SetScript("OnEnter", function(btn)
            if btn.SetBackdropColor then
                btn:SetBackdropColor(PALETTE.FOCUS_BG[1], PALETTE.FOCUS_BG[2], PALETTE.FOCUS_BG[3], 0.95)
                btn:SetBackdropBorderColor(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], 1.0)
            end
        end)
        sRow:SetScript("OnLeave", function(btn)
            if btn.SetBackdropColor then
                btn:SetBackdropColor(0.02, 0.015, 0.005, 0.8)
                btn:SetBackdropBorderColor(0.4, 0.3, 0.1, 0.6)
            end
        end)

        sRow:SetScript("OnClick", function(btn)
            if btn.candidate and btn.candidate.member then
                local fullName = self:getMemberDisplayName(btn.candidate.member)
                if self._modalCrafterBox then
                    self._modalCrafterBox:SetText(fullName)
                end
                if self._modalSuggestFrame then
                    self._modalSuggestFrame:Hide()
                end
                self:updateCrafterFeedback(fullName, self._modalTargetRecipe)
            end
        end)

        sRow:Hide()
        self._modalSuggestRows[i] = sRow
    end

    -- Eventos de digitação e navegação do EditBox do Artesão
    cBox:SetScript("OnTextChanged", function(box, userInput)
        if userInput then
            local text = box:GetText() or ""
            self:updateCrafterSuggestions(text)
            self:updateCrafterFeedback(text, self._modalTargetRecipe)
        end
    end)
    cBox:SetScript("OnEnterPressed", function(box)
        local text = box:GetText() or ""
        local resolved = self:resolveCrafterName(text, self._modalTargetRecipe)
        if resolved ~= "" then
            box:SetText(resolved)
            self:updateCrafterFeedback(resolved, self._modalTargetRecipe)
        end
        if self._modalSuggestFrame then self._modalSuggestFrame:Hide() end
        box:ClearFocus()
    end)
    cBox:SetScript("OnTabPressed", function(box)
        local text = box:GetText() or ""
        local candidates = self:getCrafterCandidates(text, self._modalTargetRecipe)
        if candidates and #candidates > 0 and candidates[1].member then
            local fullName = self:getMemberDisplayName(candidates[1].member)
            box:SetText(fullName)
            self:updateCrafterFeedback(fullName, self._modalTargetRecipe)
        end
        if self._modalSuggestFrame then self._modalSuggestFrame:Hide() end
        box:ClearFocus()
    end)
    cBox:SetScript("OnEscapePressed", function(box)
        if self._modalSuggestFrame and self._modalSuggestFrame:IsShown() then
            self._modalSuggestFrame:Hide()
        else
            box:ClearFocus()
        end
    end)
    cBox:SetScript("OnEditFocusLost", function(box)
        if C_Timer and C_Timer.After then
            C_Timer.After(0.25, function()
                if self._modalSuggestFrame then self._modalSuggestFrame:Hide() end
            end)
        else
            if self._modalSuggestFrame then self._modalSuggestFrame:Hide() end
        end
    end)
end

--- Abre o modal de criação de pedido pré-preenchido
---@param recipe table
---@param targetCrafter string|nil
function ProfessionView:openOrderModal(recipe, targetCrafter)
    if not self._orderModal then return end
    self._modalTargetRecipe = recipe

    local itemData = ProfessionData.getItemData and ProfessionData.getItemData(recipe)
    local dName = (itemData and itemData.name) or (ProfessionData.getRecipeDisplayName and ProfessionData.getRecipeDisplayName(recipe)) or recipe.name or "Item"
    local qColor = (itemData and itemData.qualityColor) or (ProfessionData.getQualityColor and ProfessionData.getQualityColor(recipe.quality or 1)) or "|cffffd200"
    local iconTex = (itemData and itemData.icon) or recipe.icon or "Interface\\Icons\\Trade_Alchemy"

    if self._modalRecipePreview then
        self._modalRecipePreview:SetText(string.format("|T%s:20:20:0:0|t %s%s|r", iconTex, qColor, dName))
    end

    local initialCrafter = ""
    if targetCrafter and targetCrafter ~= "" then
        initialCrafter = self:resolveCrafterName(targetCrafter, recipe)
        if initialCrafter == "" then
            initialCrafter = self:getMemberDisplayName(targetCrafter)
        end
    end

    if self._modalCrafterBox then
        self._modalCrafterBox:SetText(initialCrafter)
    end
    if self._modalSuggestFrame then
        self._modalSuggestFrame:Hide()
    end
    self:updateCrafterFeedback(initialCrafter, recipe)

    if self._modalQtyBox then
        self._modalQtyBox:SetText("1")
    end
    if self._modalTipBox then
        self._modalTipBox:SetText("0")
    end
    if self._modalNotesBox then
        self._modalNotesBox:SetText("Trago os materiais.")
    end

    self._orderModal:Show()
end

--- Confirma e envia o novo pedido
function ProfessionView:submitOrder()
    if not self._modalTargetRecipe then return end

    local recipe = self._modalTargetRecipe
    local inputCrafter = self._modalCrafterBox and self._modalCrafterBox:GetText() or ""
    local crafter = self:resolveCrafterName(inputCrafter, recipe)
    local qty = self._modalQtyBox and tonumber(self._modalQtyBox:GetText()) or 1
    local goldTip = self._modalTipBox and tonumber(self._modalTipBox:GetText()) or 0
    local notes = self._modalNotesBox and self._modalNotesBox:GetText() or ""

    local myFullName = self:getLocalPlayerFullName()

    local orderData = {
        professionKey = recipe.prof or self._selectedProfKey or "ALCHEMY",
        recipeId = recipe.id,
        recipeName = ProfessionData.getRecipeDisplayName(recipe),
        recipeIcon = recipe.icon or "Interface\\Icons\\Trade_Alchemy",
        requester = myFullName,
        crafter = crafter,
        itemCount = math.max(1, qty),
        tipCopper = goldTip * 10000,
        notes = notes,
    }

    if _G.GM and _G.GM.professionService then
        _G.GM.professionService:createOrder(orderData)
    end

    if self._orderModal then
        self._orderModal:Hide()
    end
    if self._modalSuggestFrame then
        self._modalSuggestFrame:Hide()
    end

    self:switchSubTab("ORDERS")
end

-- =========================================================================
-- ABAS LATERAIS COMPATÍVEIS COM AUDIT, LOGS, GRUPOS, AGENDA E SETTINGS
-- =========================================================================

function ProfessionView:createSideTabs()
    local frame = self._frame
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local curL = (_G.GM and _G.GM.L) or _G.L or L

    -- Aba 1: Auditoria
    local tabAudit = CreateFrame("Button", "GM_ProfSideTab_Audit", frame, template)
    tabAudit:SetSize(36, 36)
    tabAudit:SetPoint("TOPLEFT", frame, "TOPRIGHT", -2, -60)
    if tabAudit.SetBackdrop then
        tabAudit:SetBackdrop(SIDE_TAB_BACKDROP)
        tabAudit:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
        tabAudit:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
    end
    local aIcon = tabAudit:CreateTexture(nil, "ARTWORK")
    aIcon:SetPoint("TOPLEFT", tabAudit, "TOPLEFT", 4, -4)
    aIcon:SetPoint("BOTTOMRIGHT", tabAudit, "BOTTOMRIGHT", -4, 4)
    aIcon:SetTexture("Interface\\Icons\\INV_Scroll_03")
    aIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tabAudit:SetScript("OnClick", function()
        local pt, rel, relPt, x, y = frame:GetPoint()
        self:hide()
        if _G.GM and _G.GM.auditController then
            _G.GM.auditController:show()
            local aFrame = _G.GM.auditView and _G.GM.auditView:getFrame()
            if aFrame and pt then aFrame:ClearAllPoints(); aFrame:SetPoint(pt, rel, relPt, x, y) end
        end
    end)

    -- Aba 2: Logs
    local tabLogs = CreateFrame("Button", "GM_ProfSideTab_Logs", frame, template)
    tabLogs:SetSize(36, 36)
    tabLogs:SetPoint("TOPLEFT", tabAudit, "BOTTOMLEFT", 0, -8)
    if tabLogs.SetBackdrop then
        tabLogs:SetBackdrop(SIDE_TAB_BACKDROP)
        tabLogs:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
        tabLogs:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
    end
    local lIcon = tabLogs:CreateTexture(nil, "ARTWORK")
    lIcon:SetPoint("TOPLEFT", tabLogs, "TOPLEFT", 4, -4)
    lIcon:SetPoint("BOTTOMRIGHT", tabLogs, "BOTTOMRIGHT", -4, 4)
    lIcon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    lIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tabLogs:SetScript("OnClick", function()
        local pt, rel, relPt, x, y = frame:GetPoint()
        self:hide()
        if _G.GM and _G.GM.logController then
            _G.GM.logController:show()
            local lFrame = _G.GM.logView and _G.GM.logView:getFrame()
            if lFrame and pt then lFrame:ClearAllPoints(); lFrame:SetPoint(pt, rel, relPt, x, y) end
        end
    end)

    -- Aba 3: Grupos
    local tabGroups = CreateFrame("Button", "GM_ProfSideTab_Groups", frame, template)
    tabGroups:SetSize(36, 36)
    tabGroups:SetPoint("TOPLEFT", tabLogs, "BOTTOMLEFT", 0, -8)
    if tabGroups.SetBackdrop then
        tabGroups:SetBackdrop(SIDE_TAB_BACKDROP)
        tabGroups:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
        tabGroups:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
    end
    local gIcon = tabGroups:CreateTexture(nil, "ARTWORK")
    gIcon:SetPoint("TOPLEFT", tabGroups, "TOPLEFT", 4, -4)
    gIcon:SetPoint("BOTTOMRIGHT", tabGroups, "BOTTOMRIGHT", -4, 4)
    gIcon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    gIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tabGroups:SetScript("OnClick", function()
        local pt, rel, relPt, x, y = frame:GetPoint()
        self:hide()
        if _G.GM and _G.GM.groupController then
            _G.GM.groupController:show()
            local gFrame = _G.GM.groupView and _G.GM.groupView:getFrame()
            if gFrame and pt then gFrame:ClearAllPoints(); gFrame:SetPoint(pt, rel, relPt, x, y) end
        end
    end)

    -- Aba 4: Agenda
    local tabAgenda = CreateFrame("Button", "GM_ProfSideTab_Agenda", frame, template)
    tabAgenda:SetSize(36, 36)
    tabAgenda:SetPoint("TOPLEFT", tabGroups, "BOTTOMLEFT", 0, -8)
    if tabAgenda.SetBackdrop then
        tabAgenda:SetBackdrop(SIDE_TAB_BACKDROP)
        tabAgenda:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
        tabAgenda:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
    end
    local agIcon = tabAgenda:CreateTexture(nil, "ARTWORK")
    agIcon:SetPoint("TOPLEFT", tabAgenda, "TOPLEFT", 4, -4)
    agIcon:SetPoint("BOTTOMRIGHT", tabAgenda, "BOTTOMRIGHT", -4, 4)
    agIcon:SetTexture("Interface\\Calendar\\UI-Calendar-Button")
    agIcon:SetTexCoord(0.0078, 0.375, 0.0156, 0.75)
    tabAgenda:SetScript("OnClick", function()
        local pt, rel, relPt, x, y = frame:GetPoint()
        self:hide()
        if _G.GM and _G.GM.agendaController then
            _G.GM.agendaController:show()
            local agFrame = _G.GM.agendaView and _G.GM.agendaView:getFrame()
            if agFrame and pt then agFrame:ClearAllPoints(); agFrame:SetPoint(pt, rel, relPt, x, y) end
        end
    end)

    -- Aba 5: Profissões & Pedidos (Ativa nesta janela com brilho dourado)
    local tabProf = CreateFrame("Button", "GM_ProfSideTab_Professions", frame, template)
    tabProf:SetSize(36, 36)
    tabProf:SetPoint("TOPLEFT", tabAgenda, "BOTTOMLEFT", 0, -8)
    if tabProf.SetBackdrop then
        tabProf:SetBackdrop(SIDE_TAB_BACKDROP)
        tabProf:SetBackdropColor(0.18, 0.12, 0.04, 0.95)
        tabProf:SetBackdropBorderColor(1.0, 0.82, 0.20, 1.0)
    end
    local pIcon = tabProf:CreateTexture(nil, "ARTWORK")
    pIcon:SetPoint("TOPLEFT", tabProf, "TOPLEFT", 4, -4)
    pIcon:SetPoint("BOTTOMRIGHT", tabProf, "BOTTOMRIGHT", -4, 4)
    pIcon:SetTexture("Interface\\Icons\\Trade_BlackSmithing")
    pIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pIcon:SetVertexColor(1.0, 1.0, 1.0)
    local pGlow = tabProf:CreateTexture(nil, "OVERLAY")
    pGlow:SetPoint("TOPLEFT", tabProf, "TOPLEFT", -2, 2)
    pGlow:SetPoint("BOTTOMRIGHT", tabProf, "BOTTOMRIGHT", 2, -2)
    pGlow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    pGlow:SetBlendMode("ADD")
    pGlow:SetVertexColor(1.0, 0.85, 0.20, 0.80)

    -- Aba 6: Configurações
    local tabSettings = CreateFrame("Button", "GM_ProfSideTab_Settings", frame, template)
    tabSettings:SetSize(36, 36)
    tabSettings:SetPoint("TOPLEFT", tabProf, "BOTTOMLEFT", 0, -8)
    if tabSettings.SetBackdrop then
        tabSettings:SetBackdrop(SIDE_TAB_BACKDROP)
        tabSettings:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
        tabSettings:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
    end
    local sIcon = tabSettings:CreateTexture(nil, "ARTWORK")
    sIcon:SetPoint("TOPLEFT", tabSettings, "TOPLEFT", 4, -4)
    sIcon:SetPoint("BOTTOMRIGHT", tabSettings, "BOTTOMRIGHT", -4, 4)
    sIcon:SetTexture("Interface\\Icons\\Trade_Engineering")
    sIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tabSettings:SetScript("OnClick", function()
        local pt, rel, relPt, x, y = frame:GetPoint()
        self:hide()
        if _G.GM and _G.GM.settingsController then
            _G.GM.settingsController:show()
            local sFrame = _G.GM.settingsView and _G.GM.settingsView:getFrame()
            if sFrame and pt then sFrame:ClearAllPoints(); sFrame:SetPoint(pt, rel, relPt, x, y) end
        end
    end)
end

--- Atualiza a tela de acordo com a sub-aba selecionada
function ProfessionView:refresh()
    if not self:isShown() then return end
    if self._currentSubTab == "BROWSER" then
        self:refreshRecipeList()
    elseif self._currentSubTab == "ORDERS" then
        self:refreshOrders()
    elseif self._currentSubTab == "MY_PROFS" then
        self:refreshMyProfessions()
    end
end
