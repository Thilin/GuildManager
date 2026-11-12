local addonName, addonTable = ...
local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })

---@class GroupView
---@field private _frame table|nil
GroupView = {}
GroupView.__index = GroupView

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
    ROLE_TANK = { 0.29, 0.56, 0.88 },
    ROLE_HEALER = { 0.18, 0.80, 0.44 },
    ROLE_DPS = { 0.91, 0.30, 0.24 },
}

local GROUP_TYPE_INFO = {
    DUNGEON = { label = "Masmorras", color = "|cff4a90e2", icon = "Interface\\Icons\\INV_Shield_04" },
    RAID    = { label = "Raides",    color = "|cffff8000", icon = "Interface\\Icons\\INV_Helmet_06" },
    MISC    = { label = "Diversos",  color = "|cff00ff88", icon = "Interface\\Icons\\INV_Misc_GroupLooking" },
    FARM    = { label = "Farm",      color = "|cffffff55", icon = "Interface\\Icons\\INV_Misc_Bag_08" },
    QUESTS  = { label = "Missões",   color = "|cff33ccff", icon = "Interface\\Icons\\INV_Misc_Book_07" },
    PVP     = { label = "PvP",       color = "|cffff4444", icon = "Interface\\Icons\\INV_BannerPVP_02" },
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

local CLASS_NAME_TO_TOKEN = {
    ["GUERREIRO"] = "WARRIOR",
    ["WARRIOR"] = "WARRIOR",
    ["MAGO"] = "MAGE",
    ["MAGE"] = "MAGE",
    ["LADINO"] = "ROGUE",
    ["ROGUE"] = "ROGUE",
    ["DRUIDA"] = "DRUID",
    ["DRUID"] = "DRUID",
    ["CAÇADOR"] = "HUNTER",
    ["CACADOR"] = "HUNTER",
    ["HUNTER"] = "HUNTER",
    ["XAMÃ"] = "SHAMAN",
    ["XAMA"] = "SHAMAN",
    ["SHAMAN"] = "SHAMAN",
    ["SACERDOTE"] = "PRIEST",
    ["PRIEST"] = "PRIEST",
    ["BRUXO"] = "WARLOCK",
    ["WARLOCK"] = "WARLOCK",
    ["PALADINO"] = "PALADIN",
    ["PALADIN"] = "PALADIN",
    ["CAVALEIRO DA MORTE"] = "DEATHKNIGHT",
    ["CAVALEIRO DE MORTE"] = "DEATHKNIGHT",
    ["DEATHKNIGHT"] = "DEATHKNIGHT",
    ["DK"] = "DEATHKNIGHT",
}

local function getColoredMemberName(name, classToken)
    if not name or name == "" then return "" end
    local clean = name:match("^[^-]+") or name
    clean = clean:match("^%s*(.-)%s*$") or clean

    local tok = nil
    if classToken and classToken ~= "" then
        local raw = classToken:match("^%s*(.-)%s*$") or classToken
        tok = CLASS_NAME_TO_TOKEN[raw:upper()] or raw:upper()
    end

    if tok and RAID_CLASS_COLORS and RAID_CLASS_COLORS[tok] then
        local c = RAID_CLASS_COLORS[tok]
        if c and c.r and c.g and c.b then
            local r = math.min(255, math.max(0, math.floor(c.r * 255)))
            local g = math.min(255, math.max(0, math.floor(c.g * 255)))
            local b = math.min(255, math.max(0, math.floor(c.b * 255)))
            return string.format("|cff%02x%02x%02x%s|r", r, g, b, clean)
        end
    end
    return string.format("|cffffffff%s|r", clean)
end

local function getRoleFormatted(role)
    if role == GroupRole.TANK or role == "TANK" then
        return "|cff4a90e2[Tank]|r"
    elseif role == GroupRole.HEALER or role == "HEALER" then
        return "|cff2ecc71[Cura]|r"
    elseif role == GroupRole.DPS or role == "DPS" then
        return "|cffe74c3c[Dano]|r"
    end
    return "|cff888888[-]|r"
end

local function styleBox(eb)
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
    end)
    eb:SetScript("OnEditFocusLost", function(box)
        if box.SetBackdropBorderColor then
            box:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
        end
    end)
end

--- Construtor da View de Grupos e LFG.
---@return GroupView
function GroupView:new()
    local instance = setmetatable({}, self)

    instance._frame = nil
    instance._groups = {}
    instance._lfgCards = {}
    instance._guildMembers = {}
    instance._currentDetailGroupId = nil
    instance._selectedLFGType = "ALL"
    instance._lfgSearchText = ""

    -- Callbacks
    instance._onRefreshCallback = nil
    instance._onCreateGroupCallback = nil
    instance._onDeleteGroupCallback = nil
    instance._onAddMemberCallback = nil
    instance._onRemoveMemberCallback = nil
    instance._onSetLeaderCallback = nil
    instance._onSetRoleCallback = nil
    instance._onInviteGroupCallback = nil
    instance._onUpdateGroupDetailsCallback = nil
    instance._onCreateLFGCardCallback = nil
    instance._onDeleteLFGCardCallback = nil

    -- Modais
    instance._createGroupModal = nil
    instance._createLFGModal = nil
    instance._detailModal = nil
    instance._addMemberModal = nil

    instance:createUI()

    return instance
end

function GroupView:setOnRefreshCallback(cb) self._onRefreshCallback = cb end
function GroupView:setOnCreateGroupCallback(cb) self._onCreateGroupCallback = cb end
function GroupView:setOnDeleteGroupCallback(cb) self._onDeleteGroupCallback = cb end
function GroupView:setOnAddMemberCallback(cb) self._onAddMemberCallback = cb end
function GroupView:setOnRemoveMemberCallback(cb) self._onRemoveMemberCallback = cb end
function GroupView:setOnSetLeaderCallback(cb) self._onSetLeaderCallback = cb end
function GroupView:setOnSetRoleCallback(cb) self._onSetRoleCallback = cb end
function GroupView:setOnInviteGroupCallback(cb) self._onInviteGroupCallback = cb end
function GroupView:setOnUpdateGroupDetailsCallback(cb) self._onUpdateGroupDetailsCallback = cb end
function GroupView:setOnCreateLFGCardCallback(cb) self._onCreateLFGCardCallback = cb end
function GroupView:setOnDeleteLFGCardCallback(cb) self._onDeleteLFGCardCallback = cb end

function GroupView:getFrame() return self._frame end
function GroupView:isShown() return self._frame and self._frame:IsShown() end

function GroupView:show()
    if self._frame then
        if _G.GM and _G.GM.restoreWindowPosition then
            _G.GM.restoreWindowPosition(self._frame)
        end
        self._frame:Show()
        self:renderLFGDashboard()
        self:renderCreatedGroups()
    end
end

function GroupView:hide()
    if self._frame then
        self._frame:Hide()
        if self._createGroupModal then self._createGroupModal:Hide() end
        if self._createLFGModal then self._createLFGModal:Hide() end
        if self._detailModal then self._detailModal:Hide() end
        if self._addMemberModal then self._addMemberModal:Hide() end
    end
end

function GroupView:toggle()
    if self:isShown() then
        self:hide()
    else
        self:show()
    end
end

function GroupView:setGuildMembers(members)
    self._guildMembers = members or {}
end

function GroupView:setGroups(groups)
    self._groups = groups or {}
    if self._frame and self._frame:IsShown() then
        self:renderCreatedGroups()
    end
end

function GroupView:setLFGCards(cards)
    self._lfgCards = cards or {}
    if self._frame and self._frame:IsShown() then
        self:renderLFGDashboard()
    end
end

--- Busca um membro na lista de membros da guilda por nome (valida nome e sobrenome).
function GroupView:findGuildMember(name)
    if not name or name == "" then return nil end
    local clean = (name:match("^[^-]+") or name):match("^%s*(.-)%s*$")
    local cleanLower = clean:lower()

    for _, m in ipairs(self._guildMembers or {}) do
        local mName = m:getName() or ""
        local mClean = (mName:match("^[^-]+") or mName):match("^%s*(.-)%s*$") or mName
        if mClean:lower() == cleanLower then
            return m
        end
    end

    if not clean:find("%s") and _G.GM and _G.GM.memberService and _G.GM.memberService.resolveFullName then
        local full = _G.GM.memberService:resolveFullName(clean)
        if full and full ~= "" and full:find("%s") then
            local fullLower = full:lower()
            for _, m in ipairs(self._guildMembers or {}) do
                local mName = m:getName() or ""
                local mClean = (mName:match("^[^-]+") or mName):match("^%s*(.-)%s*$") or mName
                if mClean:lower() == fullLower then
                    return m
                end
            end
        end
    end
    return nil
end

function GroupView:resolveMemberClass(name, fallbackClass)
    if fallbackClass and fallbackClass ~= "" then
        local raw = fallbackClass:match("^%s*(.-)%s*$") or fallbackClass
        local tok = CLASS_NAME_TO_TOKEN[raw:upper()] or raw:upper()
        if CLASS_ICON_COORDS[tok] then return tok end
    end

    if not name or name == "" then return "" end

    local clean = name:match("^[^-]+") or name
    clean = clean:match("^%s*(.-)%s*$") or clean
    if not clean:find("%s") and _G.GM and _G.GM.memberService and _G.GM.memberService.resolveFullName then
        local full = _G.GM.memberService:resolveFullName(clean)
        if full and full ~= "" and full:find("%s") then
            clean = full
        end
    end
    local cleanLower = clean:lower()

    for _, m in ipairs(self._guildMembers or {}) do
        if type(m) == "table" then
            local mName = (m.getName and m:getName()) or m.name or ""
            local mClean = (mName:match("^[^-]+") or mName):match("^%s*(.-)%s*$") or mName
            if mClean:lower() == cleanLower then
                local c = (m.getClass and m:getClass()) or m.class
                if c and c ~= "" then
                    local tok = CLASS_NAME_TO_TOKEN[c:upper()] or c:upper()
                    if CLASS_ICON_COORDS[tok] then return tok end
                end
                local cDisp = (m.getClassDisplayName and m:getClassDisplayName()) or m.classDisplayName
                if cDisp and cDisp ~= "" then
                    local tok = CLASS_NAME_TO_TOKEN[cDisp:upper()]
                    if tok and CLASS_ICON_COORDS[tok] then return tok end
                end
            end
        end
    end

    if GetNumGuildMembers and GetGuildRosterInfo then
        local num = GetNumGuildMembers() or 0
        for i = 1, num do
            local gName, _, _, _, gClassDisp, _, _, _, _, _, gClass = GetGuildRosterInfo(i)
            if gName then
                local gClean = (gName:match("^[^-]+") or gName):match("^%s*(.-)%s*$") or gName
                if gClean:lower() == cleanLower then
                    if gClass and gClass ~= "" then
                        local tok = CLASS_NAME_TO_TOKEN[gClass:upper()] or gClass:upper()
                        if CLASS_ICON_COORDS[tok] then return tok end
                    end
                    if gClassDisp and gClassDisp ~= "" then
                        local tok = CLASS_NAME_TO_TOKEN[gClassDisp:upper()]
                        if tok and CLASS_ICON_COORDS[tok] then return tok end
                    end
                    break
                end
            end
        end
    end

    return ""
end

--- Obtém o nome completo do jogador logado.
function GroupView:getPlayerFullName()
    if _G.GM and _G.GM.groupController and _G.GM.groupController.resolvePlayerFullName then
        local res = _G.GM.groupController:resolvePlayerFullName()
        if res and res ~= "" then return res end
    end
    if _G.GM and _G.GM.memberService and _G.GM.memberService.resolvePlayerFullName then
        local res = _G.GM.memberService:resolvePlayerFullName()
        if res and res ~= "" then return res end
    end
    local p = UnitName and UnitName("player")
    if p and _G.GM and _G.GM.memberService and _G.GM.memberService.resolveFullName then
        local res = _G.GM.memberService:resolveFullName(p)
        if res and res ~= "" then return res end
    end
    return p or ""
end

-- =========================================================================
-- CRIAÇÃO DA INTERFACE PRINCIPAL (1180 x 614)
-- =========================================================================

function GroupView:createUI()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "GM_GroupViewFrame", UIParent, template)
    self._frame = frame

    frame:SetSize(1180, 614)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if _G.GM and _G.GM.hookWindowDrag then
        _G.GM.hookWindowDrag(frame)
    end
    if _G.GM and _G.GM.restoreWindowPosition then
        _G.GM.restoreWindowPosition(frame)
    end
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    frame:SetScript("OnShow", function()
        if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN or 839) end
        self:renderLFGDashboard()
        self:renderCreatedGroups()
    end)
    frame:SetScript("OnHide", function()
        if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE or 840) end
        if self._createGroupModal and self._createGroupModal:IsShown() then self._createGroupModal:Hide() end
        if self._createLFGModal and self._createLFGModal:IsShown() then self._createLFGModal:Hide() end
        if self._detailModal and self._detailModal:IsShown() then self._detailModal:Hide() end
        if self._addMemberModal and self._addMemberModal:IsShown() then self._addMemberModal:Hide() end
    end)

    -- Fundo e borda temática
    local solidBg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    solidBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    solidBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    solidBg:SetColorTexture(0.04, 0.03, 0.02, 1.0)

    local bgTex = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    bgTex:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    bgTex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    bgTex:SetTexture("Interface\\AddOns\\GuildManager\\Textures\\background.tga")
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

    -- Botão Discord Contato / Bugs / Feedback (Canto Superior Direito)
    local discordBtn = CreateFrame("Button", nil, frame, template)
    discordBtn:SetSize(125, 20)
    discordBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    if discordBtn.SetBackdrop then
        discordBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, tileSize = 0, edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        discordBtn:SetBackdropColor(0.08, 0.08, 0.14, 0.90)
        discordBtn:SetBackdropBorderColor(0.35, 0.40, 0.95, 0.75)
    end
    local discText = discordBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    discText:SetPoint("CENTER", discordBtn, "CENTER", 0, 0)
    discText:SetText("|cff5865f2Discord:|r |cffffffffthillin_|r")

    discordBtn:SetScript("OnEnter", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.55, 0.65, 1.0, 1.0)
            btn:SetBackdropColor(0.12, 0.12, 0.22, 0.95)
        end
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        GameTooltip:AddLine("|cff5865f2Discord:|r |cffffffffthillin_|r")
        GameTooltip:AddLine("Contato direto para dúvidas, sugestões, bugs e feedback.", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine("|cffffd200Clique para copiar no chat.|r", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    discordBtn:SetScript("OnLeave", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.35, 0.40, 0.95, 0.75)
            btn:SetBackdropColor(0.08, 0.08, 0.14, 0.90)
        end
        GameTooltip:Hide()
    end)
    discordBtn:SetScript("OnClick", function()
        if ChatFrame_OpenChat then
            ChatFrame_OpenChat("thillin_")
        end
        print("|cff5865f2[GuildManager]|r Discord para contato, bugs e feedback: |cffffffffthillin_|r (Copiado para o chat!)")
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

    -- Título da Janela
    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", factionIcon, "RIGHT", 10, 0)
    titleText:SetText("GERENCIAMENTO DE GRUPOS & PROCURANDO GRUPO (LFG)")
    self._titleText = titleText

    local subtitleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitleText:SetPoint("LEFT", titleText, "RIGHT", 12, 0)
    subtitleText:SetText("|cffaaaaaaMural de grupos e jogadores da guilda|r")

    -- Divisória do Cabeçalho
    local headerSep = frame:CreateTexture(nil, "ARTWORK")
    headerSep:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -44)
    headerSep:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    headerSep:SetHeight(1)
    headerSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- Abas Laterais à Direita
    self:createSideTabs()

    -- 1. Painel Esquerdo/Central: Dashboard de Procurando Grupo (width 770, height 554)
    self:createLFGDashboardPanel()

    -- 2. Coluna Lateral Direita: Grupos Criados (width 370, height 554)
    self:createCreatedGroupsPanel()

    -- Modais
    self:createModals()
end

-- =========================================================================
-- ABAS LATERAIS
-- =========================================================================

function GroupView:createSideTabs()
    local frame = self._frame
    if not frame then return end
    if _G.GM and _G.GM.createNavigationSideTabs then
        self._sideTabs = _G.GM.createNavigationSideTabs(frame, 'groups', self)
    end
end

-- =========================================================================
-- PAINEL 1: DASHBOARD DE PROCURANDO GRUPO (LFG) - LADO ESQUERDO / CENTRO
-- =========================================================================

function GroupView:createLFGDashboardPanel()
    local frame = self._frame
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    local panel = CreateFrame("Frame", "GM_LFGPanel", frame, template)
    panel:SetSize(770, 554)
    panel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -50)
    self._lfgPanel = panel

    if panel.SetBackdrop then
        panel:SetBackdrop(CONTAINER_BACKDROP)
        panel:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        panel:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end

    -- Header da Dashboard LFG
    local headerBar = CreateFrame("Frame", nil, panel, template)
    headerBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    headerBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
    headerBar:SetHeight(38)
    if headerBar.SetBackdrop then
        headerBar:SetBackdrop(SUB_CONTAINER_BACKDROP)
        headerBar:SetBackdropColor(0.12, 0.08, 0.03, 0.95)
        headerBar:SetBackdropBorderColor(0.60, 0.42, 0.15, 0.90)
    end

    local hIcon = headerBar:CreateTexture(nil, "ARTWORK")
    hIcon:SetSize(24, 24)
    hIcon:SetPoint("LEFT", headerBar, "LEFT", 8, 0)
    hIcon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    hIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local hTitle = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hTitle:SetPoint("TOPLEFT", hIcon, "TOPRIGHT", 8, 2)
    hTitle:SetText("|cffffd200DASHBOARD - PROCURANDO GRUPO (LFG)|r")

    local hSub = headerBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hSub:SetPoint("BOTTOMLEFT", hIcon, "BOTTOMRIGHT", 8, -2)
    hSub:SetText("|cffaaaaaaMembros procurando parceiros para atividades|r")

    -- Botão "+ Procurar Grupo"
    local createLfgBtn = CreateFrame("Button", nil, headerBar, "UIPanelButtonTemplate")
    createLfgBtn:SetSize(130, 24)
    createLfgBtn:SetPoint("RIGHT", headerBar, "RIGHT", -6, 0)
    createLfgBtn:SetText("+ Procurar Grupo")
    createLfgBtn:SetScript("OnClick", function()
        if self._createLFGModal then
            self:openCreateLFGModal()
        end
    end)

    -- Barra de Filtros e Busca (Logo abaixo do header)
    local filterBar = CreateFrame("Frame", nil, panel, template)
    filterBar:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -4)
    filterBar:SetPoint("TOPRIGHT", headerBar, "BOTTOMRIGHT", 0, -4)
    filterBar:SetHeight(32)

    local filterTypes = {
        { id = "ALL",     label = "Todos" },
        { id = "DUNGEON", label = "Masmorras" },
        { id = "RAID",    label = "Raides" },
        { id = "MISC",    label = "Diversos" },
        { id = "FARM",    label = "Farm" },
        { id = "QUESTS",  label = "Missões" },
        { id = "PVP",     label = "PvP" },
    }

    self._filterButtons = {}
    local prevBtn = nil

    for _, f in ipairs(filterTypes) do
        local fBtn = CreateFrame("Button", nil, filterBar, template)
        fBtn:SetSize(72, 22)
        if not prevBtn then
            fBtn:SetPoint("LEFT", filterBar, "LEFT", 4, 0)
        else
            fBtn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
        end
        prevBtn = fBtn

        if fBtn.SetBackdrop then
            fBtn:SetBackdrop(SUB_CONTAINER_BACKDROP)
        end

        local fText = fBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fText:SetPoint("CENTER", fBtn, "CENTER", 0, 0)
        fText:SetText(f.label)
        fBtn.label = fText
        fBtn.typeId = f.id

        fBtn:SetScript("OnClick", function()
            self._selectedLFGType = f.id
            self:updateFilterButtons()
            self:renderLFGDashboard()
        end)

        table.insert(self._filterButtons, fBtn)
    end

    -- Caixa de Busca na direita da barra de filtros
    local searchBox = CreateFrame("EditBox", "GM_LFGSearchBox", filterBar, template)
    searchBox:SetSize(160, 22)
    searchBox:SetPoint("RIGHT", filterBar, "RIGHT", -4, 0)
    styleBox(searchBox)

    local placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
    placeholder:SetText("Buscar card...")
    searchBox.placeholder = placeholder

    searchBox:SetScript("OnTextChanged", function(box)
        local txt = box:GetText() or ""
        if txt == "" then
            placeholder:Show()
        else
            placeholder:Hide()
        end
        self._lfgSearchText = txt:lower():match("^%s*(.-)%s*$") or ""
        self:renderLFGDashboard()
    end)
    searchBox:SetScript("OnEscapePressed", function(box)
        box:SetText("")
        box:ClearFocus()
    end)

    -- ScrollFrame de Cards de Procurando Grupo
    local scrollFrame = CreateFrame("ScrollFrame", "GM_LFGScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 6)
    self._lfgScrollFrame = scrollFrame

    local contentFrame = CreateFrame("Frame", "GM_LFGContentFrame", scrollFrame)
    contentFrame:SetSize(736, 10)
    scrollFrame:SetScrollChild(contentFrame)
    self._lfgContentFrame = contentFrame

    -- Mensagem de Lista Vazia
    local emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyText:SetPoint("CENTER", panel, "CENTER", 0, -20)
    emptyText:SetJustifyH("CENTER")
    emptyText:SetText("|cff888888Nenhum jogador procurando grupo no momento.\nClique em '+ Procurar Grupo' acima para cadastrar seu card!|r")
    self._lfgEmptyText = emptyText

    self:updateFilterButtons()
end

function GroupView:updateFilterButtons()
    for _, btn in ipairs(self._filterButtons or {}) do
        local isActive = (btn.typeId == self._selectedLFGType)
        if btn.SetBackdropColor and btn.SetBackdropBorderColor then
            if isActive then
                btn:SetBackdropColor(0.25, 0.18, 0.05, 0.95)
                btn:SetBackdropBorderColor(1.0, 0.82, 0.20, 1.0)
                btn.label:SetTextColor(1.0, 0.82, 0.20)
            else
                btn:SetBackdropColor(0.04, 0.025, 0.01, 0.75)
                btn:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.80)
                btn.label:SetTextColor(0.80, 0.80, 0.80)
            end
        end
    end
end

--- Renderiza a lista de cards de LFG no mural.
function GroupView:renderLFGDashboard()
    if not self._lfgContentFrame then return end

    -- Limpa cards anteriores
    if self._lfgCardFrames then
        for _, f in ipairs(self._lfgCardFrames) do
            f:Hide()
        end
    end
    self._lfgCardFrames = {}

    local myFullName = self:getPlayerFullName()
    local myNameNorm = (myFullName:match("^[^-]+") or myFullName):match("^%s*(.-)%s*$"):lower()

    local cards = self._lfgCards or {}
    local filtered = {}

    for _, card in ipairs(cards) do
        local isExp = (card.isExpired and card:isExpired()) or false
        if not isExp then
            local matchesType = (self._selectedLFGType == "ALL") or (card:getType() == self._selectedLFGType)
            local matchesSearch = true
            if self._lfgSearchText and self._lfgSearchText ~= "" then
                local textMatch = false
                local cCreator = (card:getCreator() or ""):lower()
                local cDesc = (card:getDescription() or ""):lower()
                local cTime = (card:getTime() or ""):lower()
                local typeDef = GROUP_TYPE_INFO[card:getType()]
                local typeLabel = typeDef and typeDef.label:lower() or ""
                if cCreator:find(self._lfgSearchText, 1, true) or
                   cDesc:find(self._lfgSearchText, 1, true) or
                   cTime:find(self._lfgSearchText, 1, true) or
                   typeLabel:find(self._lfgSearchText, 1, true) then
                    textMatch = true
                end
                matchesSearch = textMatch
            end

            if matchesType and matchesSearch then
                table.insert(filtered, card)
            end
        end
    end

    if #filtered == 0 then
        self._lfgEmptyText:Show()
        self._lfgContentFrame:SetHeight(10)
        return
    else
        self._lfgEmptyText:Hide()
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local cardWidth = 360
    local cardHeight = 92
    local cardGapX = 10
    local cardGapY = 8
    local colCount = 2

    for i, card in ipairs(filtered) do
        local okCard = pcall(function()
            local col = (i - 1) % colCount
            local row = math.floor((i - 1) / colCount)
            local xOffset = col * (cardWidth + cardGapX)
            local yOffset = row * (cardHeight + cardGapY)

            local cardId = (card.getId and card:getId()) or tostring(card.id or "")
            local rawType = (card.getType and card:getType()) or card.type or "DUNGEON"
            local cType = tostring(rawType):upper()
            local typeDef = GROUP_TYPE_INFO[cType] or GROUP_TYPE_INFO[rawType] or GROUP_TYPE_INFO.MISC
            local creator = (card.getCreator and card:getCreator()) or card.creator or "Desconhecido"
            local cTime = (card.getTime and card:getTime()) or card.time or "A combinar"
            local cDesc = (card.getDescription and card:getDescription()) or card.description or ""
            local cLevel = (card.getCreatorLevel and card:getCreatorLevel()) or card.creatorLevel or 1
            local cClassRaw = (card.getCreatorClass and card:getCreatorClass()) or card.creatorClass or ""
            local cClass = self:resolveMemberClass(creator, cClassRaw)
            local isMyCard = (card.isCreator and card:isCreator(myFullName)) or (creator:lower() == myNameNorm)

            local cardFrame = CreateFrame("Frame", nil, self._lfgContentFrame, template)
            cardFrame:SetSize(cardWidth, cardHeight)
            cardFrame:SetPoint("TOPLEFT", self._lfgContentFrame, "TOPLEFT", xOffset, -yOffset)
            cardFrame:SetFrameLevel(self._lfgContentFrame:GetFrameLevel() + 2)

            if cardFrame.SetBackdrop then
                cardFrame:SetBackdrop(SUB_CONTAINER_BACKDROP)
                if isMyCard then
                    cardFrame:SetBackdropColor(0.12, 0.08, 0.02, 0.95)
                    cardFrame:SetBackdropBorderColor(1.0, 0.75, 0.20, 0.95)
                else
                    cardFrame:SetBackdropColor(0.04, 0.025, 0.01, 0.85)
                    cardFrame:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
                end
            end

            -- Ícone da Classe
            local classIcon = cardFrame:CreateTexture(nil, "ARTWORK")
            classIcon:SetSize(32, 32)
            classIcon:SetPoint("TOPLEFT", cardFrame, "TOPLEFT", 8, -8)
            classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            local coords = CLASS_ICON_COORDS[cClass] or { 0, 0.25, 0, 0.25 }
            classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])

            -- Nome do Criador (validando nome e sobrenome) + Nível
            local creatorNameText = cardFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            creatorNameText:SetPoint("TOPLEFT", classIcon, "TOPRIGHT", 6, 0)
            creatorNameText:SetPoint("RIGHT", cardFrame, "RIGHT", -78, 0)
            creatorNameText:SetJustifyH("LEFT")
            local coloredName = getColoredMemberName(creator, cClass)
            local myTag = isMyCard and " |cffffd200[Meu]|r" or ""
            creatorNameText:SetText(coloredName .. string.format(" |cffaaaaaa(Nv %d)|r", cLevel) .. myTag)

            -- Tipo de Grupo Procurado (Badge) & Expiração em 72h
            local remStr = (card.getRemainingTimeString and card:getRemainingTimeString()) or "72h"
            local typeBadge = cardFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            typeBadge:SetPoint("TOPLEFT", creatorNameText, "BOTTOMLEFT", 0, -2)
            typeBadge:SetText((typeDef.color or "|cffffffff") .. "[" .. (typeDef.label or "Geral") .. "]|r  |cff888888⏳|r |cffffd200" .. remStr .. "|r")

            -- Horário previsto
            local timeText = cardFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            timeText:SetPoint("TOPLEFT", typeBadge, "BOTTOMLEFT", 0, -2)
            timeText:SetPoint("RIGHT", cardFrame, "RIGHT", -78, 0)
            timeText:SetJustifyH("LEFT")
            timeText:SetText("|cffffff00⏰|r " .. (cTime ~= "" and cTime or "A combinar"))

            -- Descrição do Card (ocupa a parte inferior do card)
            local descText = cardFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            descText:SetPoint("TOPLEFT", cardFrame, "TOPLEFT", 8, -50)
            descText:SetPoint("BOTTOMRIGHT", cardFrame, "BOTTOMRIGHT", -8, 6)
            descText:SetJustifyH("LEFT")
            descText:SetJustifyV("TOP")
            descText:SetWordWrap(true)
            if cDesc and cDesc ~= "" then
                descText:SetText("|cffcccccc💬 " .. cDesc .. "|r")
            else
                descText:SetText("|cff666666💬 Sem descrição adicional.|r")
            end

            -- Ações à Direita
            if isMyCard or (IsGuildLeader and IsGuildLeader()) then
                local delBtn = CreateFrame("Button", nil, cardFrame, "UIPanelButtonTemplate")
                delBtn:SetSize(68, 22)
                delBtn:SetPoint("TOPRIGHT", cardFrame, "TOPRIGHT", -8, -8)
                delBtn:SetText("Excluir")
                delBtn:SetScript("OnClick", function()
                    if self._onDeleteLFGCardCallback then
                        self._onDeleteLFGCardCallback(cardId)
                    end
                end)
            else
                local whisperBtn = CreateFrame("Button", nil, cardFrame, "UIPanelButtonTemplate")
                whisperBtn:SetSize(66, 18)
                whisperBtn:SetPoint("TOPRIGHT", cardFrame, "TOPRIGHT", -8, -6)
                whisperBtn:SetText("Sussurrar")
                whisperBtn:SetScript("OnClick", function()
                    local cleanTarget = creator:match("^[^-]+") or creator
                    cleanTarget = cleanTarget:match("^(%S+)") or cleanTarget
                    if ChatFrame_OpenChat then
                        ChatFrame_OpenChat("/w " .. cleanTarget .. " ")
                    end
                end)

                local inviteBtn = CreateFrame("Button", nil, cardFrame, "UIPanelButtonTemplate")
                inviteBtn:SetSize(66, 18)
                inviteBtn:SetPoint("TOPRIGHT", cardFrame, "TOPRIGHT", -8, -26)
                inviteBtn:SetText("Convidar")
                inviteBtn:SetScript("OnClick", function()
                    local cleanTarget = creator:match("^[^-]+") or creator
                    cleanTarget = cleanTarget:match("^(%S+)") or cleanTarget
                    if C_PartyInfo and C_PartyInfo.InviteUnit then
                        pcall(C_PartyInfo.InviteUnit, cleanTarget)
                    elseif InviteUnit then
                        pcall(InviteUnit, cleanTarget)
                    end
                end)
            end

            cardFrame:Show()
            table.insert(self._lfgCardFrames, cardFrame)
        end)
    end

    local totalRows = math.ceil(#filtered / colCount)
    local totalHeight = totalRows * (cardHeight + cardGapY)
    self._lfgContentFrame:SetHeight(math.max(totalHeight, 10))
    self._lfgContentFrame:SetWidth(736)
end

-- =========================================================================
-- PAINEL 2: COLUNA LATERAL DE GRUPOS CRIADOS - LADO DIREITO (370 x 554)
-- =========================================================================

function GroupView:createCreatedGroupsPanel()
    local frame = self._frame
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    local panel = CreateFrame("Frame", "GM_GroupsPanel", frame, template)
    panel:SetSize(370, 554)
    panel:SetPoint("TOPLEFT", frame, "TOPLEFT", 794, -50)
    self._groupsPanel = panel

    if panel.SetBackdrop then
        panel:SetBackdrop(CONTAINER_BACKDROP)
        panel:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        panel:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end

    -- Header da Coluna de Grupos
    local headerBar = CreateFrame("Frame", nil, panel, template)
    headerBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    headerBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
    headerBar:SetHeight(38)
    if headerBar.SetBackdrop then
        headerBar:SetBackdrop(SUB_CONTAINER_BACKDROP)
        headerBar:SetBackdropColor(0.12, 0.08, 0.03, 0.95)
        headerBar:SetBackdropBorderColor(0.60, 0.42, 0.15, 0.90)
    end

    local gIcon = headerBar:CreateTexture(nil, "ARTWORK")
    gIcon:SetSize(24, 24)
    gIcon:SetPoint("LEFT", headerBar, "LEFT", 8, 0)
    gIcon:SetTexture("Interface\\Icons\\INV_Shield_04")
    gIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local gTitle = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gTitle:SetPoint("TOPLEFT", gIcon, "TOPRIGHT", 8, 2)
    gTitle:SetText("|cffffd200GRUPOS CRIADOS|r")

    local gCountText = headerBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gCountText:SetPoint("BOTTOMLEFT", gIcon, "BOTTOMRIGHT", 8, -2)
    gCountText:SetText("|cffaaaaaa(0 grupos ativos)|r")
    self._groupsCountText = gCountText

    -- Botão "+ Criar Grupo" (TODOS os membros podem criar grupos)
    local createGroupBtn = CreateFrame("Button", nil, headerBar, "UIPanelButtonTemplate")
    createGroupBtn:SetSize(100, 24)
    createGroupBtn:SetPoint("RIGHT", headerBar, "RIGHT", -6, 0)
    createGroupBtn:SetText("+ Criar Grupo")
    createGroupBtn:SetScript("OnClick", function()
        self:openCreateGroupModal()
    end)

    -- ScrollFrame de Grupos
    local scrollFrame = CreateFrame("ScrollFrame", "GM_CreatedGroupsScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 4, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 6)
    self._createdGroupsScrollFrame = scrollFrame

    local contentFrame = CreateFrame("Frame", "GM_CreatedGroupsContentFrame", scrollFrame)
    contentFrame:SetSize(336, 10)
    scrollFrame:SetScrollChild(contentFrame)
    self._createdGroupsContentFrame = contentFrame

    -- Mensagem de Lista Vazia
    local emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyText:SetPoint("CENTER", panel, "CENTER", 0, -20)
    emptyText:SetJustifyH("CENTER")
    emptyText:SetText("|cff888888Nenhum grupo criado ainda.\nClique em '+ Criar Grupo' acima para iniciar um!|r")
    self._groupsEmptyText = emptyText
end

--- Renderiza a coluna de grupos criados.
function GroupView:renderCreatedGroups()
    if not self._createdGroupsContentFrame then return end

    if self._groupCardFrames then
        for _, f in ipairs(self._groupCardFrames) do
            f:Hide()
        end
    end
    self._groupCardFrames = {}

    local groups = self._groups or {}
    if self._groupsCountText then
        self._groupsCountText:SetText(string.format("|cffaaaaaa(%d grupo%s ativo%s)|r", #groups, #groups == 1 and "" or "s", #groups == 1 and "" or "s"))
    end

    if #groups == 0 then
        self._groupsEmptyText:Show()
        self._createdGroupsContentFrame:SetHeight(10)
        return
    else
        self._groupsEmptyText:Hide()
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local yOffset = 0
    local cardHeight = 88

    for _, group in ipairs(groups) do
        local okCard = pcall(function()
            local groupId = (group.getId and group:getId()) or tostring(group.id or "")
            local rawType = (group.getType and group:getType()) or group.type or "DUNGEON"
            local gType = tostring(rawType):upper()
            local typeDef = GROUP_TYPE_INFO[gType] or GROUP_TYPE_INFO[rawType] or GROUP_TYPE_INFO.MISC or { label = "Geral", color = "|cffffffff" }
            local gName = (group.getName and group:getName()) or group.name or "Grupo"
            local leader = (group.getLeader and group:getLeader()) or group.leader or "Sem líder"
            local creator = (group.getCreator and group:getCreator()) or group.creator or leader
            if not creator or creator == "" then creator = leader end
            local gTime = (group.getTime and group:getTime()) or (group.getNote and group:getNote()) or group.time or group.note or ""
            local members = (group.getMembers and group:getMembers()) or group.members or {}
            local desc = (group.getDescription and group:getDescription()) or group.description or ""

            local lClass = self:resolveMemberClass(leader)
            local cClass = self:resolveMemberClass(creator)

            local cardFrame = CreateFrame("Button", nil, self._createdGroupsContentFrame, template)
            cardFrame:SetSize(332, cardHeight)
            cardFrame:SetPoint("TOPLEFT", self._createdGroupsContentFrame, "TOPLEFT", 0, -yOffset)
            cardFrame:SetFrameLevel(self._createdGroupsContentFrame:GetFrameLevel() + 2)

            if cardFrame.SetBackdrop then
                cardFrame:SetBackdrop(SUB_CONTAINER_BACKDROP)
                cardFrame:SetBackdropColor(0.04, 0.025, 0.01, 0.85)
                cardFrame:SetBackdropBorderColor(0.55, 0.38, 0.15, 0.85)
            end

            cardFrame:SetScript("OnEnter", function(btn)
                if btn.SetBackdropBorderColor then
                    btn:SetBackdropBorderColor(1.0, 0.82, 0.20, 1.0)
                    btn:SetBackdropColor(0.08, 0.05, 0.02, 0.95)
                end
            end)
            cardFrame:SetScript("OnLeave", function(btn)
                if btn.SetBackdropBorderColor then
                    btn:SetBackdropBorderColor(0.55, 0.38, 0.15, 0.85)
                    btn:SetBackdropColor(0.04, 0.025, 0.01, 0.85)
                end
            end)
            cardFrame:SetScript("OnClick", function()
                self:openDetailModal(group)
            end)

            -- Nome do Grupo
            local titleText = cardFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            titleText:SetPoint("TOPLEFT", cardFrame, "TOPLEFT", 10, -8)
            titleText:SetPoint("RIGHT", cardFrame, "RIGHT", -90, 0)
            titleText:SetJustifyH("LEFT")
            titleText:SetText("|cffffd200" .. gName .. "|r")

            -- Badge do Tipo
            local badgeText = cardFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            badgeText:SetPoint("TOPRIGHT", cardFrame, "TOPRIGHT", -10, -8)
            badgeText:SetText((typeDef.color or "|cffffffff") .. "[" .. (typeDef.label or "Grupo") .. "]|r")

            -- Horário e Membros
            local infoText = cardFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            infoText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -4)
            infoText:SetText(string.format("⏰ |cffffff00%s|r  •  👥 |cffffffff%d membro%s|r",
                (gTime ~= "" and gTime or "A combinar"), #members, #members == 1 and "" or "s"))

            -- Líder e Criador
            local leaderText = cardFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            leaderText:SetPoint("TOPLEFT", infoText, "BOTTOMLEFT", 0, -3)
            leaderText:SetText("👑 " .. getColoredMemberName(leader, lClass) .. "  |cff888888(Líder)|r")

            local creatorText = cardFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            creatorText:SetPoint("TOPLEFT", leaderText, "BOTTOMLEFT", 0, -3)
            creatorText:SetPoint("RIGHT", cardFrame, "RIGHT", -10, 0)
            creatorText:SetJustifyH("LEFT")
            creatorText:SetText("✍ |cffaaaaaaCriador:|r " .. getColoredMemberName(creator, cClass))

            cardFrame:Show()
            table.insert(self._groupCardFrames, cardFrame)
            yOffset = yOffset + cardHeight + 4
        end)
    end

    self._createdGroupsContentFrame:SetHeight(math.max(yOffset, 10))
    self._createdGroupsContentFrame:Show()
    if self._createdGroupsScrollFrame then
        self._createdGroupsScrollFrame:Show()
    end
end

-- =========================================================================
-- MODAL 1: CRIAR NOVO GRUPO (Todos os membros da guilda podem criar)
-- =========================================================================

function GroupView:openCreateGroupModal()
    if not self._createGroupModal then return end
    local myFullName = self:getPlayerFullName()

    self._createGroupNameBox:SetText("")
    self._createGroupTimeBox:SetText("")
    self._createGroupLeaderBox:SetText(myFullName ~= "" and myFullName or (UnitName and UnitName("player")) or "")
    self._createGroupCreatorText:SetText("|cffffd200" .. (myFullName ~= "" and myFullName or (UnitName and UnitName("player")) or "") .. "|r")
    self._createGroupDescBox:SetText("")
    self._createGroupSelectedType = "DUNGEON"
    self:updateCreateGroupTypeButtons()

    self._createGroupModal:Show()
    self._createGroupNameBox:SetFocus()
end

function GroupView:createCreateGroupModal()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local modal = CreateFrame("Frame", "GM_CreateGroupModal", self._frame, template)
    modal:SetSize(480, 480)
    modal:SetPoint("CENTER", self._frame, "CENTER", 0, 0)
    modal:SetFrameStrata("DIALOG")
    modal:EnableMouse(true)
    modal:Hide()
    self._createGroupModal = modal

    if modal.SetBackdrop then
        modal:SetBackdrop(DIALOG_BACKDROP)
        modal:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], 0.98)
        modal:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], 1.0)
    end

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", modal, "TOPLEFT", 20, -18)
    title:SetText("Criar Novo Grupo")

    local subtitle = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("|cffaaaaaaTodos os membros da guilda podem criar grupos|r")

    local closeBtn = CreateFrame("Button", nil, modal, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -4, -4)
    closeBtn:SetSize(28, 28)
    closeBtn:SetScript("OnClick", function() modal:Hide() end)

    -- 1. Nome do Grupo
    local nameLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", modal, "TOPLEFT", 24, -68)
    nameLabel:SetText("Nome do Grupo:")

    local nameBox = CreateFrame("EditBox", nil, modal, template)
    nameBox:SetSize(432, 26)
    nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
    styleBox(nameBox)
    self._createGroupNameBox = nameBox

    -- 2. Tipo do Grupo (Masmorras, Raides, Diversos, Farm, Missões, PvP)
    local typeLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeLabel:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -10)
    typeLabel:SetText("Tipo do Grupo:")

    local types = {
        { id = "DUNGEON", label = "Masmorras" },
        { id = "RAID",    label = "Raides" },
        { id = "MISC",    label = "Diversos" },
        { id = "FARM",    label = "Farm" },
        { id = "QUESTS",  label = "Missões" },
        { id = "PVP",     label = "PvP" },
    }

    self._createGroupTypeButtons = {}
    self._createGroupSelectedType = "DUNGEON"
    local prevBtn = nil

    for _, t in ipairs(types) do
        local btn = CreateFrame("Button", nil, modal, template)
        btn:SetSize(68, 22)
        if not prevBtn then
            btn:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", 0, -4)
        else
            btn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
        end
        prevBtn = btn

        if btn.SetBackdrop then btn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
        local bText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bText:SetPoint("CENTER", btn, "CENTER", 0, 0)
        bText:SetText(t.label)
        btn.label = bText
        btn.typeId = t.id

        btn:SetScript("OnClick", function()
            self._createGroupSelectedType = t.id
            self:updateCreateGroupTypeButtons()
        end)
        table.insert(self._createGroupTypeButtons, btn)
    end

    -- 3. Horário
    local timeLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeLabel:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", 0, -36)
    timeLabel:SetText("Horário Previsto:")

    local timeBox = CreateFrame("EditBox", nil, modal, template)
    timeBox:SetSize(432, 26)
    timeBox:SetPoint("TOPLEFT", timeLabel, "BOTTOMLEFT", 0, -4)
    styleBox(timeBox)
    self._createGroupTimeBox = timeBox

    -- 4. Líder do Grupo
    local leaderLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leaderLabel:SetPoint("TOPLEFT", timeBox, "BOTTOMLEFT", 0, -10)
    leaderLabel:SetText("Líder do Grupo:")

    local leaderBox = CreateFrame("EditBox", nil, modal, template)
    leaderBox:SetSize(432, 26)
    leaderBox:SetPoint("TOPLEFT", leaderLabel, "BOTTOMLEFT", 0, -4)
    styleBox(leaderBox)
    self._createGroupLeaderBox = leaderBox

    -- 5. Criador do Grupo (pego automaticamente sempre validando nome e sobrenome, NÃO EDITÁVEL)
    local creatorLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    creatorLabel:SetPoint("TOPLEFT", leaderBox, "BOTTOMLEFT", 0, -10)
    creatorLabel:SetText("Criador do Grupo (Fixo):")

    local creatorBg = CreateFrame("Frame", nil, modal, template)
    creatorBg:SetSize(432, 24)
    creatorBg:SetPoint("TOPLEFT", creatorLabel, "BOTTOMLEFT", 0, -4)
    if creatorBg.SetBackdrop then
        creatorBg:SetBackdrop(SUB_CONTAINER_BACKDROP)
        creatorBg:SetBackdropColor(0.02, 0.015, 0.005, 0.70)
        creatorBg:SetBackdropBorderColor(0.40, 0.28, 0.10, 0.80)
    end
    local creatorText = creatorBg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    creatorText:SetPoint("LEFT", creatorBg, "LEFT", 8, 0)
    self._createGroupCreatorText = creatorText

    -- 6. Descrição do Grupo
    local descLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descLabel:SetPoint("TOPLEFT", creatorBg, "BOTTOMLEFT", 0, -10)
    descLabel:SetText("Descrição do Grupo:")

    local descBoxBg = CreateFrame("Frame", nil, modal, template)
    descBoxBg:SetSize(432, 60)
    descBoxBg:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -4)
    if descBoxBg.SetBackdrop then
        descBoxBg:SetBackdrop(SUB_CONTAINER_BACKDROP)
        descBoxBg:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        descBoxBg:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local descBox = CreateFrame("EditBox", nil, descBoxBg)
    descBox:SetPoint("TOPLEFT", descBoxBg, "TOPLEFT", 6, -4)
    descBox:SetPoint("BOTTOMRIGHT", descBoxBg, "BOTTOMRIGHT", -6, 4)
    descBox:SetMultiLine(true)
    descBox:SetAutoFocus(false)
    descBox:SetFontObject("GameFontHighlightSmall")
    self._createGroupDescBox = descBox

    -- Botões Criar e Cancelar
    local cancelBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    cancelBtn:SetSize(90, 24)
    cancelBtn:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -24, 16)
    cancelBtn:SetText("Cancelar")
    cancelBtn:SetScript("OnClick", function() modal:Hide() end)

    local confirmBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    confirmBtn:SetSize(110, 24)
    confirmBtn:SetPoint("RIGHT", cancelBtn, "LEFT", -10, 0)
    confirmBtn:SetText("Criar Grupo")
    confirmBtn:SetScript("OnClick", function()
        local name = nameBox:GetText() or ""
        local gType = self._createGroupSelectedType or "DUNGEON"
        local timeStr = timeBox:GetText() or ""
        local leader = leaderBox:GetText() or ""
        local descStr = descBox:GetText() or ""

        if name:match("^%s*$") then
            print("|cffff4444[GuildManager]|r Por favor, informe um nome para o grupo.")
            return
        end
        if leader:match("^%s*$") then
            print("|cffff4444[GuildManager]|r Por favor, informe o líder do grupo.")
            return
        end

        local defaultRole = (gType == "DUNGEON" or gType == "RAID") and GroupRole.DPS or GroupRole.NONE

        if self._onCreateGroupCallback then
            local ok, err = self._onCreateGroupCallback(name, gType, leader, defaultRole, timeStr, descStr)
            if ok then
                modal:Hide()
                nameBox:SetText("")
                timeBox:SetText("")
                descBox:SetText("")
            else
                print("|cffff4444[GuildManager]|r " .. tostring(err or "Falha ao criar grupo."))
            end
        else
            modal:Hide()
        end
    end)
end

function GroupView:updateCreateGroupTypeButtons()
    for _, btn in ipairs(self._createGroupTypeButtons or {}) do
        local isActive = (btn.typeId == self._createGroupSelectedType)
        if btn.SetBackdropColor and btn.SetBackdropBorderColor then
            if isActive then
                btn:SetBackdropColor(0.25, 0.18, 0.05, 0.95)
                btn:SetBackdropBorderColor(1.0, 0.82, 0.20, 1.0)
                btn.label:SetTextColor(1.0, 0.82, 0.20)
            else
                btn:SetBackdropColor(0.04, 0.025, 0.01, 0.75)
                btn:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.80)
                btn.label:SetTextColor(0.80, 0.80, 0.80)
            end
        end
    end
end

-- =========================================================================
-- MODAL 2: CRIAR CARD DE PROCURANDO GRUPO (LFG)
-- =========================================================================

function GroupView:openCreateLFGModal()
    if not self._createLFGModal then return end
    local myFullName = self:getPlayerFullName()

    local myCardsCount = 0
    for _, card in ipairs(self._lfgCards or {}) do
        if not (card.isExpired and card:isExpired()) and (card.isCreator and card:isCreator(myFullName)) then
            myCardsCount = myCardsCount + 1
        end
    end

    if myCardsCount >= 5 then
        print(string.format("|cffff4444[GuildManager]|r Você já possui o limite de 5 cards de Procurando Grupo ativos (%d/5). Exclua um card existente para poder criar outro.", myCardsCount))
        return
    end

    if self._createLFGSubtitle then
        self._createLFGSubtitle:SetText(string.format("|cffaaaaaaCada membro pode criar até 5 cards (Você possui %d/5 ativos)|r", myCardsCount))
    end

    self._createLFGTimeBox:SetText("")
    self._createLFGCreatorText:SetText("|cffffd200" .. (myFullName ~= "" and myFullName or (UnitName and UnitName("player")) or "") .. "|r")
    self._createLFGDescBox:SetText("")
    self._createLFGSelectedType = "DUNGEON"
    self:updateCreateLFGTypeButtons()

    self._createLFGModal:Show()
    self._createLFGTimeBox:SetFocus()
end

function GroupView:createCreateLFGModal()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local modal = CreateFrame("Frame", "GM_CreateLFGModal", self._frame, template)
    modal:SetSize(480, 390)
    modal:SetPoint("CENTER", self._frame, "CENTER", 0, 0)
    modal:SetFrameStrata("DIALOG")
    modal:EnableMouse(true)
    modal:Hide()
    self._createLFGModal = modal

    if modal.SetBackdrop then
        modal:SetBackdrop(DIALOG_BACKDROP)
        modal:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], 0.98)
        modal:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], 1.0)
    end

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", modal, "TOPLEFT", 20, -18)
    title:SetText("Procurar Grupo (LFG)")

    local subtitle = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("|cffaaaaaaCada membro pode criar até 5 cards de Procurando Grupo|r")
    self._createLFGSubtitle = subtitle

    local closeBtn = CreateFrame("Button", nil, modal, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -4, -4)
    closeBtn:SetSize(28, 28)
    closeBtn:SetScript("OnClick", function() modal:Hide() end)

    -- 1. Tipo do Grupo que Procura
    local typeLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeLabel:SetPoint("TOPLEFT", modal, "TOPLEFT", 24, -68)
    typeLabel:SetText("Tipo de Grupo que Procura:")

    local types = {
        { id = "DUNGEON", label = "Masmorras" },
        { id = "RAID",    label = "Raides" },
        { id = "MISC",    label = "Diversos" },
        { id = "FARM",    label = "Farm" },
        { id = "QUESTS",  label = "Missões" },
        { id = "PVP",     label = "PvP" },
    }

    self._createLFGTypeButtons = {}
    self._createLFGSelectedType = "DUNGEON"
    local prevBtn = nil

    for _, t in ipairs(types) do
        local btn = CreateFrame("Button", nil, modal, template)
        btn:SetSize(68, 22)
        if not prevBtn then
            btn:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", 0, -4)
        else
            btn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
        end
        prevBtn = btn

        if btn.SetBackdrop then btn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
        local bText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bText:SetPoint("CENTER", btn, "CENTER", 0, 0)
        bText:SetText(t.label)
        btn.label = bText
        btn.typeId = t.id

        btn:SetScript("OnClick", function()
            self._createLFGSelectedType = t.id
            self:updateCreateLFGTypeButtons()
        end)
        table.insert(self._createLFGTypeButtons, btn)
    end

    -- 2. Horário / Disponibilidade
    local timeLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeLabel:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", 0, -36)
    timeLabel:SetText("Horário / Disponibilidade:")

    local timeBox = CreateFrame("EditBox", nil, modal, template)
    timeBox:SetSize(432, 26)
    timeBox:SetPoint("TOPLEFT", timeLabel, "BOTTOMLEFT", 0, -4)
    styleBox(timeBox)
    self._createLFGTimeBox = timeBox

    -- 3. Criador do Card (Fixo e Não Editável)
    local creatorLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    creatorLabel:SetPoint("TOPLEFT", timeBox, "BOTTOMLEFT", 0, -10)
    creatorLabel:SetText("Nome do Personagem Criador (Fixo):")

    local creatorBg = CreateFrame("Frame", nil, modal, template)
    creatorBg:SetSize(432, 24)
    creatorBg:SetPoint("TOPLEFT", creatorLabel, "BOTTOMLEFT", 0, -4)
    if creatorBg.SetBackdrop then
        creatorBg:SetBackdrop(SUB_CONTAINER_BACKDROP)
        creatorBg:SetBackdropColor(0.02, 0.015, 0.005, 0.70)
        creatorBg:SetBackdropBorderColor(0.40, 0.28, 0.10, 0.80)
    end
    local creatorText = creatorBg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    creatorText:SetPoint("LEFT", creatorBg, "LEFT", 8, 0)
    self._createLFGCreatorText = creatorText

    -- 4. Descrição
    local descLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descLabel:SetPoint("TOPLEFT", creatorBg, "BOTTOMLEFT", 0, -10)
    descLabel:SetText("Descrição / Atividade Desejada:")

    local descBoxBg = CreateFrame("Frame", nil, modal, template)
    descBoxBg:SetSize(432, 70)
    descBoxBg:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -4)
    if descBoxBg.SetBackdrop then
        descBoxBg:SetBackdrop(SUB_CONTAINER_BACKDROP)
        descBoxBg:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        descBoxBg:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local descBox = CreateFrame("EditBox", nil, descBoxBg)
    descBox:SetPoint("TOPLEFT", descBoxBg, "TOPLEFT", 6, -4)
    descBox:SetPoint("BOTTOMRIGHT", descBoxBg, "BOTTOMRIGHT", -6, 4)
    descBox:SetMultiLine(true)
    descBox:SetAutoFocus(false)
    descBox:SetFontObject("GameFontHighlightSmall")
    self._createLFGDescBox = descBox

    -- Botões
    local cancelBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    cancelBtn:SetSize(90, 24)
    cancelBtn:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -24, 16)
    cancelBtn:SetText("Cancelar")
    cancelBtn:SetScript("OnClick", function() modal:Hide() end)

    local confirmBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    confirmBtn:SetSize(120, 24)
    confirmBtn:SetPoint("RIGHT", cancelBtn, "LEFT", -10, 0)
    confirmBtn:SetText("Publicar Card")
    confirmBtn:SetScript("OnClick", function()
        local gType = self._createLFGSelectedType or "DUNGEON"
        local timeStr = timeBox:GetText() or ""
        local descStr = descBox:GetText() or ""

        if self._onCreateLFGCardCallback then
            local ok, err = self._onCreateLFGCardCallback(gType, timeStr, descStr)
            if ok then
                modal:Hide()
                timeBox:SetText("")
                descBox:SetText("")
            else
                print("|cffff4444[GuildManager]|r " .. (err or "Falha ao publicar card."))
            end
        else
            modal:Hide()
        end
    end)
end

function GroupView:updateCreateLFGTypeButtons()
    for _, btn in ipairs(self._createLFGTypeButtons or {}) do
        local isActive = (btn.typeId == self._createLFGSelectedType)
        if btn.SetBackdropColor and btn.SetBackdropBorderColor then
            if isActive then
                btn:SetBackdropColor(0.25, 0.18, 0.05, 0.95)
                btn:SetBackdropBorderColor(1.0, 0.82, 0.20, 1.0)
                btn.label:SetTextColor(1.0, 0.82, 0.20)
            else
                btn:SetBackdropColor(0.04, 0.025, 0.01, 0.75)
                btn:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.80)
                btn.label:SetTextColor(0.80, 0.80, 0.80)
            end
        end
    end
end

-- =========================================================================
-- MODAL 3: DETALHES DO GRUPO (Visualização & Edição pelo Criador)
-- =========================================================================

function GroupView:openDetailModal(group)
    if not group then return end
    self._currentDetailGroupId = (group.getId and group:getId()) or group.id or ""

    local myFullName = self:getPlayerFullName()
    local canEdit = (group.canEdit and group:canEdit(myFullName, IsGuildLeader and IsGuildLeader())) or false

    local gName = (group.getName and group:getName()) or group.name or "Detalhes do Grupo"
    local gLeader = (group.getLeader and group:getLeader()) or group.leader or ""
    local gCreator = (group.getCreator and group:getCreator()) or group.creator or gLeader
    local gTime = (group.getTime and group:getTime()) or (group.getNote and group:getNote()) or group.time or group.note or ""
    local gDesc = (group.getDescription and group:getDescription()) or group.description or ""
    local gType = (group.getType and group:getType()) or group.type or "DUNGEON"

    self._detailTitleText:SetText(gName)
    self._detailNameBox:SetText(gName)
    self._detailTimeBox:SetText(gTime)
    self._detailLeaderBox:SetText(gLeader)
    self._detailCreatorText:SetText("|cffffd200" .. gCreator .. "|r")
    self._detailDescBox:SetText(gDesc)

    self._detailSelectedType = tostring(gType):upper()
    self:updateDetailTypeButtons()

    if canEdit then
        self._detailPermNotice:SetText("|cff00ff00Você é o criador deste grupo e pode editá-lo ou gerenciá-lo.|r")
        self._detailNameBox:EnableMouse(true)
        self._detailTimeBox:EnableMouse(true)
        self._detailLeaderBox:EnableMouse(true)
        self._detailDescBox:EnableMouse(true)
        self._detailSaveBtn:Show()
        self._detailAddMemberBtn:Show()
        self._detailDeleteBtn:Show()
    else
        self._detailPermNotice:SetText("|cffaaaaaa(Apenas o criador deste grupo pode editar os detalhes ou membros)|r")
        self._detailNameBox:EnableMouse(false)
        self._detailTimeBox:EnableMouse(false)
        self._detailLeaderBox:EnableMouse(false)
        self._detailDescBox:EnableMouse(false)
        self._detailSaveBtn:Hide()
        self._detailAddMemberBtn:Hide()
        self._detailDeleteBtn:Hide()
    end

    self:renderDetailMembers(group, canEdit)
    self._detailModal:Show()
end

function GroupView:refreshOpenDetailModal()
    if not self._detailModal or not self._detailModal:IsShown() or not self._currentDetailGroupId then
        return
    end
    for _, g in ipairs(self._groups or {}) do
        if g:getId() == self._currentDetailGroupId then
            self:openDetailModal(g)
            return
        end
    end
    self._detailModal:Hide()
end

function GroupView:createDetailModal()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local modal = CreateFrame("Frame", "GM_GroupDetailModal", self._frame, template)
    modal:SetSize(620, 560)
    modal:SetPoint("CENTER", self._frame, "CENTER", 0, 0)
    modal:SetFrameStrata("DIALOG")
    modal:EnableMouse(true)
    modal:Hide()
    self._detailModal = modal

    if modal.SetBackdrop then
        modal:SetBackdrop(DIALOG_BACKDROP)
        modal:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], 0.98)
        modal:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], 1.0)
    end

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", modal, "TOPLEFT", 20, -18)
    title:SetText("Detalhes do Grupo")
    self._detailTitleText = title

    local permNotice = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    permNotice:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    self._detailPermNotice = permNotice

    local closeBtn = CreateFrame("Button", nil, modal, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -4, -4)
    closeBtn:SetSize(28, 28)
    closeBtn:SetScript("OnClick", function() modal:Hide() end)

    -- Nome do Grupo
    local nameLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", modal, "TOPLEFT", 24, -64)
    nameLabel:SetText("Nome do Grupo:")

    local nameBox = CreateFrame("EditBox", nil, modal, template)
    nameBox:SetSize(270, 24)
    nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -3)
    styleBox(nameBox)
    self._detailNameBox = nameBox

    -- Horário
    local timeLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeLabel:SetPoint("LEFT", nameLabel, "RIGHT", 200, 0)
    timeLabel:SetText("Horário Previsto:")

    local timeBox = CreateFrame("EditBox", nil, modal, template)
    timeBox:SetSize(270, 24)
    timeBox:SetPoint("TOPLEFT", timeLabel, "BOTTOMLEFT", 0, -3)
    styleBox(timeBox)
    self._detailTimeBox = timeBox

    -- Tipo do Grupo
    local typeLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeLabel:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -8)
    typeLabel:SetText("Tipo do Grupo:")

    local types = {
        { id = "DUNGEON", label = "Masmorras" },
        { id = "RAID",    label = "Raides" },
        { id = "MISC",    label = "Diversos" },
        { id = "FARM",    label = "Farm" },
        { id = "QUESTS",  label = "Missões" },
        { id = "PVP",     label = "PvP" },
    }

    self._detailTypeButtons = {}
    self._detailSelectedType = "DUNGEON"
    local prevBtn = nil

    for _, t in ipairs(types) do
        local btn = CreateFrame("Button", nil, modal, template)
        btn:SetSize(66, 20)
        if not prevBtn then
            btn:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", 0, -3)
        else
            btn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
        end
        prevBtn = btn

        if btn.SetBackdrop then btn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
        local bText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bText:SetPoint("CENTER", btn, "CENTER", 0, 0)
        bText:SetText(t.label)
        btn.label = bText
        btn.typeId = t.id

        btn:SetScript("OnClick", function()
            local group = self:getCurrentDetailGroup()
            local myFullName = self:getPlayerFullName()
            if group and group:canEdit(myFullName, IsGuildLeader and IsGuildLeader()) then
                self._detailSelectedType = t.id
                self:updateDetailTypeButtons()
            end
        end)
        table.insert(self._detailTypeButtons, btn)
    end

    -- Líder do Grupo
    local leaderLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leaderLabel:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", 0, -32)
    leaderLabel:SetText("Líder do Grupo:")

    local leaderBox = CreateFrame("EditBox", nil, modal, template)
    leaderBox:SetSize(270, 24)
    leaderBox:SetPoint("TOPLEFT", leaderLabel, "BOTTOMLEFT", 0, -3)
    styleBox(leaderBox)
    self._detailLeaderBox = leaderBox

    -- Criador do Grupo (Fixo)
    local creatorLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    creatorLabel:SetPoint("LEFT", leaderLabel, "RIGHT", 200, 0)
    creatorLabel:SetText("Criador do Grupo:")

    local creatorBg = CreateFrame("Frame", nil, modal, template)
    creatorBg:SetSize(270, 24)
    creatorBg:SetPoint("TOPLEFT", creatorLabel, "BOTTOMLEFT", 0, -3)
    if creatorBg.SetBackdrop then
        creatorBg:SetBackdrop(SUB_CONTAINER_BACKDROP)
        creatorBg:SetBackdropColor(0.02, 0.015, 0.005, 0.70)
        creatorBg:SetBackdropBorderColor(0.40, 0.28, 0.10, 0.80)
    end
    local creatorText = creatorBg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    creatorText:SetPoint("LEFT", creatorBg, "LEFT", 8, 0)
    self._detailCreatorText = creatorText

    -- Descrição
    local descLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descLabel:SetPoint("TOPLEFT", leaderBox, "BOTTOMLEFT", 0, -8)
    descLabel:SetText("Descrição do Grupo:")

    local descBg = CreateFrame("Frame", nil, modal, template)
    descBg:SetSize(572, 44)
    descBg:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -3)
    if descBg.SetBackdrop then
        descBg:SetBackdrop(SUB_CONTAINER_BACKDROP)
        descBg:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        descBg:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local descBox = CreateFrame("EditBox", nil, descBg)
    descBox:SetPoint("TOPLEFT", descBg, "TOPLEFT", 6, -3)
    descBox:SetPoint("BOTTOMRIGHT", descBg, "BOTTOMRIGHT", -6, 3)
    descBox:SetMultiLine(true)
    descBox:SetAutoFocus(false)
    descBox:SetFontObject("GameFontHighlightSmall")
    self._detailDescBox = descBox

    -- Membros do Grupo Header
    local membersHeader = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    membersHeader:SetPoint("TOPLEFT", descBg, "BOTTOMLEFT", 0, -12)
    membersHeader:SetText("Membros do Grupo:")

    -- Botão "+ Adicionar Membro"
    local addMemberBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    addMemberBtn:SetSize(130, 22)
    addMemberBtn:SetPoint("RIGHT", modal, "RIGHT", -24, 0)
    addMemberBtn:SetPoint("BOTTOM", membersHeader, "BOTTOM", 0, -2)
    addMemberBtn:SetText("+ Adicionar Membro")
    addMemberBtn:SetScript("OnClick", function()
        self:openAddMemberModal()
    end)
    self._detailAddMemberBtn = addMemberBtn

    -- ScrollFrame de Membros do Grupo
    local memScroll = CreateFrame("ScrollFrame", "GM_DetailMemScrollFrame", modal, "UIPanelScrollFrameTemplate")
    memScroll:SetPoint("TOPLEFT", membersHeader, "BOTTOMLEFT", 0, -6)
    memScroll:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -46, 52)
    self._detailMemScroll = memScroll

    local memContent = CreateFrame("Frame", nil, memScroll)
    memContent:SetSize(550, 10)
    memScroll:SetScrollChild(memContent)
    self._detailMemContent = memContent

    -- Botões no Rodapé da Modal
    local inviteWoWBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    inviteWoWBtn:SetSize(140, 24)
    inviteWoWBtn:SetPoint("BOTTOMLEFT", modal, "BOTTOMLEFT", 24, 16)
    inviteWoWBtn:SetText("Convidar no WoW")
    inviteWoWBtn:SetScript("OnClick", function()
        if self._currentDetailGroupId and self._onInviteGroupCallback then
            self._onInviteGroupCallback(self._currentDetailGroupId)
        end
    end)

    local deleteBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    deleteBtn:SetSize(110, 24)
    deleteBtn:SetPoint("LEFT", inviteWoWBtn, "RIGHT", 10, 0)
    deleteBtn:SetText("Excluir Grupo")
    deleteBtn:SetScript("OnClick", function()
        if self._currentDetailGroupId and self._onDeleteGroupCallback then
            local ok = self._onDeleteGroupCallback(self._currentDetailGroupId)
            if ok ~= false then
                modal:Hide()
            end
        end
    end)
    self._detailDeleteBtn = deleteBtn

    local saveBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    saveBtn:SetSize(120, 24)
    saveBtn:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -24, 16)
    saveBtn:SetText("Salvar Grupo")
    saveBtn:SetScript("OnClick", function()
        local gId = self._currentDetailGroupId
        if not gId then return end
        local name = nameBox:GetText() or ""
        local gType = self._detailSelectedType or "DUNGEON"
        local leader = leaderBox:GetText() or ""
        local timeStr = timeBox:GetText() or ""
        local descStr = descBox:GetText() or ""

        if self._onUpdateGroupDetailsCallback then
            local ok, err = self._onUpdateGroupDetailsCallback(gId, name, gType, leader, timeStr, descStr)
            if ok then
                modal:Hide()
            else
                print("|cffff4444[GuildManager]|r " .. (err or "Falha ao salvar."))
            end
        end
    end)
    self._detailSaveBtn = saveBtn
end

function GroupView:updateDetailTypeButtons()
    for _, btn in ipairs(self._detailTypeButtons or {}) do
        local isActive = (btn.typeId == self._detailSelectedType)
        if btn.SetBackdropColor and btn.SetBackdropBorderColor then
            if isActive then
                btn:SetBackdropColor(0.25, 0.18, 0.05, 0.95)
                btn:SetBackdropBorderColor(1.0, 0.82, 0.20, 1.0)
                btn.label:SetTextColor(1.0, 0.82, 0.20)
            else
                btn:SetBackdropColor(0.04, 0.025, 0.01, 0.75)
                btn:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.80)
                btn.label:SetTextColor(0.80, 0.80, 0.80)
            end
        end
    end
end

function GroupView:getCurrentDetailGroup()
    if not self._currentDetailGroupId then return nil end
    for _, g in ipairs(self._groups or {}) do
        if g:getId() == self._currentDetailGroupId then
            return g
        end
    end
    return nil
end

function GroupView:renderDetailMembers(group, canEdit)
    if not self._detailMemContent then return end

    if self._detailMemberFrames then
        for _, f in ipairs(self._detailMemberFrames) do
            f:Hide()
        end
    end
    self._detailMemberFrames = {}

    local members = (group.getMembers and group:getMembers()) or group.members or {}
    local leaderName = (group.getLeader and group:getLeader()) or group.leader or ""
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local yOffset = 0
    local rowHeight = 28
    local myFullName = self:getPlayerFullName()
    local myNorm = (myFullName:match("^[^-]+") or myFullName):match("^%s*(.-)%s*$"):lower()

    for _, m in ipairs(members) do
        local mName = m.name or "Membro"
        local mRole = m.role or "NONE"
        local mClass = self:resolveMemberClass(mName, m.class)
        local isLeader = (leaderName ~= "" and leaderName:lower() == mName:lower())

        local row = CreateFrame("Frame", nil, self._detailMemContent, template)
        row:SetSize(540, rowHeight)
        row:SetPoint("TOPLEFT", self._detailMemContent, "TOPLEFT", 0, -yOffset)

        if row.SetBackdrop then
            row:SetBackdrop(SUB_CONTAINER_BACKDROP)
            row:SetBackdropColor(0.04, 0.025, 0.01, 0.70)
            row:SetBackdropBorderColor(0.40, 0.28, 0.10, 0.65)
        end

        local cIcon = row:CreateTexture(nil, "ARTWORK")
        cIcon:SetSize(20, 20)
        cIcon:SetPoint("LEFT", row, "LEFT", 6, 0)
        cIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        local coords = CLASS_ICON_COORDS[mClass] or { 0, 0.25, 0, 0.25 }
        cIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", cIcon, "RIGHT", 8, 0)
        local colored = getColoredMemberName(mName, mClass)
        if isLeader then
            colored = "👑 " .. colored .. " |cffffd200(Líder)|r"
        end
        nameText:SetText(colored .. string.format(" |cff888888(Nv %d)|r", m.level or 1))

        -- Função (Role)
        local roleText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        roleText:SetPoint("RIGHT", row, "RIGHT", canEdit and -70 or -10, 0)
        roleText:SetText(getRoleFormatted(mRole))

        -- Ações se puder editar
        if canEdit then
            local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            removeBtn:SetSize(22, 20)
            removeBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            removeBtn:SetText("X")
            removeBtn:SetScript("OnClick", function()
                if self._onRemoveMemberCallback then
                    self._onRemoveMemberCallback(group:getId(), mName)
                end
            end)

            if not isLeader then
                local makeLeaderBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                makeLeaderBtn:SetSize(24, 20)
                makeLeaderBtn:SetPoint("RIGHT", removeBtn, "LEFT", -4, 0)
                makeLeaderBtn:SetText("👑")
                makeLeaderBtn:SetScript("OnClick", function()
                    if self._onSetLeaderCallback then
                        self._onSetLeaderCallback(group:getId(), mName)
                    end
                end)
            end
        else
            -- Se não pode editar, mas é o próprio jogador: permite sair do grupo
            local mNorm = (mName:match("^[^-]+") or mName):match("^%s*(.-)%s*$"):lower()
            if mNorm == myNorm then
                local leaveBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                leaveBtn:SetSize(60, 20)
                leaveBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                leaveBtn:SetText("Sair")
                leaveBtn:SetScript("OnClick", function()
                    if self._onRemoveMemberCallback then
                        self._onRemoveMemberCallback(group:getId(), mName)
                    end
                end)
            end
        end

        table.insert(self._detailMemberFrames, row)
        yOffset = yOffset + rowHeight + 2
    end

    self._detailMemContent:SetHeight(math.max(yOffset, 10))
end

-- =========================================================================
-- MODAL 4: ADICIONAR MEMBRO AO GRUPO
-- =========================================================================

function GroupView:openAddMemberModal()
    if not self._addMemberModal then return end
    self._addMemberNameBox:SetText("")
    self._addMemberSelectedRole = GroupRole.DPS
    self:updateAddMemberRoleButtons()
    self._addMemberModal:Show()
    self._addMemberNameBox:SetFocus()
end

function GroupView:createAddMemberModal()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local modal = CreateFrame("Frame", "GM_AddMemberModal", self._frame, template)
    modal:SetSize(380, 240)
    modal:SetPoint("CENTER", self._frame, "CENTER", 0, 0)
    modal:SetFrameStrata("TOOLTIP")
    modal:EnableMouse(true)
    modal:Hide()
    self._addMemberModal = modal

    if modal.SetBackdrop then
        modal:SetBackdrop(DIALOG_BACKDROP)
        modal:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], 0.98)
        modal:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], 1.0)
    end

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", modal, "TOPLEFT", 20, -18)
    title:SetText("Adicionar Membro ao Grupo")

    local closeBtn = CreateFrame("Button", nil, modal, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -4, -4)
    closeBtn:SetSize(28, 28)
    closeBtn:SetScript("OnClick", function() modal:Hide() end)

    local nameLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameLabel:SetPoint("TOPLEFT", modal, "TOPLEFT", 24, -54)
    nameLabel:SetText("Nome do Personagem (Guilda):")

    local nameBox = CreateFrame("EditBox", nil, modal, template)
    nameBox:SetSize(332, 26)
    nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
    styleBox(nameBox)
    self._addMemberNameBox = nameBox

    local roleLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    roleLabel:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -12)
    roleLabel:SetText("Função no Grupo:")

    local roles = {
        { id = GroupRole.TANK,   label = "Tank" },
        { id = GroupRole.HEALER, label = "Curador" },
        { id = GroupRole.DPS,    label = "Dano (DPS)" },
        { id = GroupRole.NONE,   label = "Nenhuma" },
    }

    self._addMemberRoleButtons = {}
    self._addMemberSelectedRole = GroupRole.DPS
    local prevBtn = nil

    for _, r in ipairs(roles) do
        local btn = CreateFrame("Button", nil, modal, template)
        btn:SetSize(78, 22)
        if not prevBtn then
            btn:SetPoint("TOPLEFT", roleLabel, "BOTTOMLEFT", 0, -4)
        else
            btn:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0)
        end
        prevBtn = btn

        if btn.SetBackdrop then btn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
        local bText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bText:SetPoint("CENTER", btn, "CENTER", 0, 0)
        bText:SetText(r.label)
        btn.label = bText
        btn.roleId = r.id

        btn:SetScript("OnClick", function()
            self._addMemberSelectedRole = r.id
            self:updateAddMemberRoleButtons()
        end)
        table.insert(self._addMemberRoleButtons, btn)
    end

    local cancelBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 24)
    cancelBtn:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -20, 16)
    cancelBtn:SetText("Cancelar")
    cancelBtn:SetScript("OnClick", function() modal:Hide() end)

    local confirmBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    confirmBtn:SetSize(100, 24)
    confirmBtn:SetPoint("RIGHT", cancelBtn, "LEFT", -10, 0)
    confirmBtn:SetText("Adicionar")
    confirmBtn:SetScript("OnClick", function()
        local gId = self._currentDetailGroupId
        if not gId then return end
        local memberName = nameBox:GetText() or ""
        if memberName:match("^%s*$") then
            print("|cffff4444[GuildManager]|r Digite o nome do membro.")
            return
        end

        local mObj = self:findGuildMember(memberName)
        local finalName = mObj and mObj:getName() or memberName

        if self._onAddMemberCallback then
            local ok, err = self._onAddMemberCallback(gId, finalName, self._addMemberSelectedRole)
            if ok then
                modal:Hide()
            else
                print("|cffff4444[GuildManager]|r " .. (err or "Falha ao adicionar membro."))
            end
        end
    end)
end

function GroupView:updateAddMemberRoleButtons()
    for _, btn in ipairs(self._addMemberRoleButtons or {}) do
        local isActive = (btn.roleId == self._addMemberSelectedRole)
        if btn.SetBackdropColor and btn.SetBackdropBorderColor then
            if isActive then
                btn:SetBackdropColor(0.25, 0.18, 0.05, 0.95)
                btn:SetBackdropBorderColor(1.0, 0.82, 0.20, 1.0)
                btn.label:SetTextColor(1.0, 0.82, 0.20)
            else
                btn:SetBackdropColor(0.04, 0.025, 0.01, 0.75)
                btn:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.80)
                btn.label:SetTextColor(0.80, 0.80, 0.80)
            end
        end
    end
end

function GroupView:createModals()
    self:createCreateGroupModal()
    self:createCreateLFGModal()
    self:createDetailModal()
    self:createAddMemberModal()
end

_G.GroupView = GroupView
