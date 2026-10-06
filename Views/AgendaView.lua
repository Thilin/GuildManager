---@class AgendaView
---@field private _frame table|nil
AgendaView = {}
AgendaView.__index = AgendaView

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

local CLASS_NAME_TO_TOKEN = {
    ["GUERREIRO"] = "WARRIOR",
    ["GUERREIRA"] = "WARRIOR",
    ["WARRIOR"] = "WARRIOR",
    ["PALADINO"] = "PALADIN",
    ["PALADINA"] = "PALADIN",
    ["PALADIN"] = "PALADIN",
    ["CAÇADOR"] = "HUNTER",
    ["CAÇADORA"] = "HUNTER",
    ["HUNTER"] = "HUNTER",
    ["LADINO"] = "ROGUE",
    ["LADINA"] = "ROGUE",
    ["ROGUE"] = "ROGUE",
    ["SACERDOTE"] = "PRIEST",
    ["SACERDOTISA"] = "PRIEST",
    ["PRIEST"] = "PRIEST",
    ["XAMÃ"] = "SHAMAN",
    ["SHAMAN"] = "SHAMAN",
    ["MAGO"] = "MAGE",
    ["MAGA"] = "MAGE",
    ["MAGE"] = "MAGE",
    ["BRUXO"] = "WARLOCK",
    ["BRUXA"] = "WARLOCK",
    ["WARLOCK"] = "WARLOCK",
    ["DRUIDA"] = "DRUID",
    ["DRUID"] = "DRUID",
    ["CAVALEIRO DA MORTE"] = "DEATHKNIGHT",
    ["CAVALEIRA DA MORTE"] = "DEATHKNIGHT",
    ["DEATHKNIGHT"] = "DEATHKNIGHT",
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

local TYPE_BADGES = {
    RAID        = { label = "[Raide]",        color = "|cffff4444" },
    DUNGEON     = { label = "[Masmorra]",     color = "|cff3399ff" },
    PVP         = { label = "[JxJ / PvP]",    color = "|cffff9900" },
    REUNIAO     = { label = "[Reunião]",      color = "|cff00ff88" },
    ANIVERSARIO = { label = "[Aniversário 🎂]", color = "|cffffd200" },
    OUTRO       = { label = "[Outro]",        color = "|cffa0a0a0" },
}

--- Helper para obter o nome colorido pela classe
local function getColoredName(name, classToken)
    if not name or name == "" then return "" end
    local clean = name:match("^[^-]+") or name
    clean = clean:match("^%s*(.-)%s*$") or clean

    local tok = nil
    if classToken and classToken ~= "" then
        local raw = classToken:match("^%s*(.-)%s*$") or classToken
        tok = CLASS_NAME_TO_TOKEN[raw:upper()] or raw:upper()
    end

    if tok then
        if RAID_CLASS_COLORS and RAID_CLASS_COLORS[tok] then
            local c = RAID_CLASS_COLORS[tok]
            return string.format("|cff%02x%02x%02x%s|r", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255), clean)
        elseif CLASS_COLORS and CLASS_COLORS[tok] then
            return CLASS_COLORS[tok].hex .. clean .. "|r"
        end
    end
    return string.format("|cffffffff%s|r", clean)
end

--- Helper para estilizar caixas EditBox
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

--- Construtor da View de Agenda.
---@return AgendaView
function AgendaView:new()
    local instance = setmetatable({}, self)

    instance._frame = nil
    instance._events = {}
    instance._upcomingBirthdays = {}
    instance._currentFilterType = "TODOS"
    instance._currentSearchText = ""
    instance._activeEventCardPool = {}
    instance._activeBirthdayCardPool = {}

    -- Callbacks
    instance._onRefreshCallback = nil
    instance._onCreateEventCallback = nil
    instance._onUpdateEventCallback = nil
    instance._onDeleteEventCallback = nil
    instance._onAddInviteeCallback = nil
    instance._onRemoveInviteeCallback = nil
    instance._onInviteMemberInGameCallback = nil
    instance._onInviteAllOnlineCallback = nil
    instance._onCreateBirthdayEventCallback = nil

    -- Modais
    instance._eventModal = nil
    instance._inviteeModal = nil

    instance:createUI()

    return instance
end

function AgendaView:setOnRefreshCallback(cb) self._onRefreshCallback = cb end
function AgendaView:setOnCreateEventCallback(cb) self._onCreateEventCallback = cb end
function AgendaView:setOnUpdateEventCallback(cb) self._onUpdateEventCallback = cb end
function AgendaView:setOnDeleteEventCallback(cb) self._onDeleteEventCallback = cb end
function AgendaView:setOnAddInviteeCallback(cb) self._onAddInviteeCallback = cb end
function AgendaView:setOnRemoveInviteeCallback(cb) self._onRemoveInviteeCallback = cb end
function AgendaView:setOnInviteMemberInGameCallback(cb) self._onInviteMemberInGameCallback = cb end
function AgendaView:setOnInviteAllOnlineCallback(cb) self._onInviteAllOnlineCallback = cb end
function AgendaView:setOnCreateBirthdayEventCallback(cb) self._onCreateBirthdayEventCallback = cb end

function AgendaView:getFrame()
    return self._frame
end

function AgendaView:isShown()
    return self._frame and self._frame:IsShown()
end

function AgendaView:show()
    if self._frame then
        self._frame:Show()
    end
end

function AgendaView:hide()
    if self._frame then
        self._frame:Hide()
    end
end

--- Cria e estiliza a interface principal da Agenda.
function AgendaView:createUI()
    if self._frame then return end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "GuildManagerAgendaFrame", UIParent, template)
    self._frame = frame

    frame:SetSize(860, 540)
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
        table.insert(UISpecialFrames, "GuildManagerAgendaFrame")
    end

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
        if self._eventModal and self._eventModal:IsShown() then self._eventModal:Hide() end
        if self._inviteeModal and self._inviteeModal:IsShown() then self._inviteeModal:Hide() end
    end)

    -- Camada sólida de fundo
    local solidBg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    solidBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    solidBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    solidBg:SetColorTexture(0.04, 0.03, 0.02, 1.0)

    -- Textura pergaminho clássica GuildManager
    local bgTex = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    bgTex:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    bgTex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    bgTex:SetTexture("Interface\\AddOns\\GuildManager\\Textures\\background.tga")
    bgTex:SetAlpha(0.45)

    -- Moldura temática Blizzard
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

    -- Título da Janela
    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", factionIcon, "RIGHT", 10, 0)
    titleText:SetText("|cffffd200AGENDA DA GUILDA|r")

    -- Subtítulo informativo
    local subtitleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitleText:SetPoint("LEFT", titleText, "RIGHT", 12, 0)
    subtitleText:SetText("|cffaaaaaa(Eventos, Aniversários e Convites da Guilda)|r")

    -- Cria abas laterais (Side Tabs)
    self:createSideTabs()

    -- Cria Painel Esquerdo (Eventos) e Painel Direito (Aniversários)
    self:createLeftPanel()
    self:createRightPanel()

    -- Cria Modais
    self:createEventModal()
    self:createInviteeModal()
end

--- Cria as abas de navegação lateral (Auditoria, Logs, Grupos, Agenda, Configurações).
function AgendaView:createSideTabs()
    local frame = self._frame
    if not frame then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    -- Aba 1: Auditoria
    local tabAudit = CreateFrame("Button", "GM_AgendaSideTab_Audit", frame, template)
    tabAudit:SetSize(36, 36)
    tabAudit:SetPoint("TOPLEFT", frame, "TOPRIGHT", -2, -44)
    if tabAudit.SetBackdrop then
        tabAudit:SetBackdrop(SIDE_TAB_BACKDROP)
        tabAudit:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
        tabAudit:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
    end
    local auditIcon = tabAudit:CreateTexture(nil, "ARTWORK")
    auditIcon:SetPoint("TOPLEFT", tabAudit, "TOPLEFT", 4, -4)
    auditIcon:SetPoint("BOTTOMRIGHT", tabAudit, "BOTTOMRIGHT", -4, 4)
    auditIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    auditIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    auditIcon:SetVertexColor(0.65, 0.65, 0.65)
    tabAudit.icon = auditIcon

    tabAudit:SetScript("OnEnter", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.95, 0.70, 0.25, 1.0)
            btn:SetBackdropColor(0.08, 0.05, 0.02, 0.95)
        end
        auditIcon:SetVertexColor(1.0, 1.0, 1.0)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd200Auditoria da Guilda|r")
        GameTooltip:AddLine("Clique para alternar para a tela de Auditoria de Membros.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    tabAudit:SetScript("OnLeave", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
            btn:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
        end
        auditIcon:SetVertexColor(0.65, 0.65, 0.65)
        GameTooltip:Hide()
    end)
    tabAudit:SetScript("OnClick", function()
        if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841) end
        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
        self:hide()
        local auditCtrl = (_G.GM and _G.GM.auditController) or _G.auditController
        if auditCtrl then
            auditCtrl:show()
            local aFrame = (_G.GM and _G.GM.auditView and _G.GM.auditView.getFrame and _G.GM.auditView:getFrame())
            if aFrame and point then
                aFrame:ClearAllPoints()
                if relativeTo then aFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs) else aFrame:SetPoint(point, xOfs, yOfs) end
            end
        end
    end)

    -- Aba 2: Logs
    local tabLogs = CreateFrame("Button", "GM_AgendaSideTab_Logs", frame, template)
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

    tabLogs:SetScript("OnEnter", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.95, 0.70, 0.25, 1.0)
            btn:SetBackdropColor(0.08, 0.05, 0.02, 0.95)
        end
        logsIcon:SetVertexColor(1.0, 1.0, 1.0)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd200Registro de Atividades|r")
        GameTooltip:AddLine("Clique para alternar para a tela de Logs da guilda.", 1, 1, 1, true)
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
        if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841) end
        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
        self:hide()
        local logCtrl = (_G.GM and _G.GM.logController) or _G.logController
        if logCtrl then
            logCtrl:show()
            local lFrame = (_G.GM and _G.GM.logView and _G.GM.logView.getFrame and _G.GM.logView:getFrame())
            if lFrame and point then
                lFrame:ClearAllPoints()
                if relativeTo then lFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs) else lFrame:SetPoint(point, xOfs, yOfs) end
            end
        end
    end)

    -- Aba 3: Grupos
    local tabGroups = CreateFrame("Button", "GM_AgendaSideTab_Groups", frame, template)
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

    tabGroups:SetScript("OnEnter", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.95, 0.70, 0.25, 1.0)
            btn:SetBackdropColor(0.08, 0.05, 0.02, 0.95)
        end
        groupsIcon:SetVertexColor(1.0, 1.0, 1.0)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd200Gerenciamento de Grupos|r")
        GameTooltip:AddLine("Clique para alternar para a tela de Grupos.", 1, 1, 1, true)
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
        if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841) end
        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
        self:hide()
        local groupCtrl = (_G.GM and _G.GM.groupController) or _G.groupController
        if groupCtrl then
            groupCtrl:show()
            local gFrame = (_G.GM and _G.GM.groupView and _G.GM.groupView.getFrame and _G.GM.groupView:getFrame())
            if gFrame and point then
                gFrame:ClearAllPoints()
                if relativeTo then gFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs) else gFrame:SetPoint(point, xOfs, yOfs) end
            end
        end
    end)

    -- Aba 4: Agenda (Ativa nesta tela - Ícone Calendário com Brilho Dourado)
    local tabAgenda = CreateFrame("Button", "GM_AgendaSideTab_Agenda", frame, template)
    tabAgenda:SetSize(36, 36)
    tabAgenda:SetPoint("TOPLEFT", tabGroups, "BOTTOMLEFT", 0, -8)
    if tabAgenda.SetBackdrop then
        tabAgenda:SetBackdrop(SIDE_TAB_BACKDROP)
        tabAgenda:SetBackdropColor(0.18, 0.12, 0.04, 0.95)
        tabAgenda:SetBackdropBorderColor(1.0, 0.82, 0.20, 1.0)
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
    agendaIcon:SetVertexColor(1.0, 1.0, 1.0)

    local agendaGlow = tabAgenda:CreateTexture(nil, "OVERLAY")
    agendaGlow:SetPoint("TOPLEFT", tabAgenda, "TOPLEFT", -2, 2)
    agendaGlow:SetPoint("BOTTOMRIGHT", tabAgenda, "BOTTOMRIGHT", 2, -2)
    agendaGlow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    agendaGlow:SetBlendMode("ADD")
    agendaGlow:SetVertexColor(1.0, 0.85, 0.20, 0.80)

    tabAgenda:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd200Agenda da Guilda|r")
        GameTooltip:AddLine("|cff888888(Aba atual)|r", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Eventos, aniversários e convites de membros.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    tabAgenda:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Aba 5: Configurações
    local tabSettings = CreateFrame("Button", "GM_AgendaSideTab_Settings", frame, template)
    tabSettings:SetSize(36, 36)
    tabSettings:SetPoint("TOPLEFT", tabAgenda, "BOTTOMLEFT", 0, -8)
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

    tabSettings:SetScript("OnEnter", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.95, 0.70, 0.25, 1.0)
            btn:SetBackdropColor(0.08, 0.05, 0.02, 0.95)
        end
        settingsIcon:SetVertexColor(1.0, 1.0, 1.0)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd200Configurações do Addon|r")
        GameTooltip:AddLine("Clique para alternar para a tela de Opções e Personalização.", 1, 1, 1, true)
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
        if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841) end
        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
        self:hide()
        local settingsCtrl = (_G.GM and _G.GM.settingsController) or _G.settingsController
        if settingsCtrl then
            settingsCtrl:show()
            local sFrame = (_G.GM and _G.GM.settingsView and _G.GM.settingsView.getFrame and _G.GM.settingsView:getFrame())
            if sFrame and point then
                sFrame:ClearAllPoints()
                if relativeTo then sFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs) else sFrame:SetPoint(point, xOfs, yOfs) end
            end
        end
    end)
end

--- Cria o painel esquerdo dedicado aos eventos da guilda com filtros e busca.
function AgendaView:createLeftPanel()
    local frame = self._frame
    if not frame then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    local leftPanel = CreateFrame("Frame", "GM_AgendaLeftPanel", frame, template)
    leftPanel:SetSize(556, 476)
    leftPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -48)
    if leftPanel.SetBackdrop then
        leftPanel:SetBackdrop(CONTAINER_BACKDROP)
        leftPanel:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        leftPanel:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end
    self._leftPanel = leftPanel

    -- Header do painel esquerdo
    local headerBar = CreateFrame("Frame", nil, leftPanel, template)
    headerBar:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 3, -3)
    headerBar:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -3, -3)
    headerBar:SetHeight(38)
    if headerBar.SetBackdrop then
        headerBar:SetBackdrop(SUB_CONTAINER_BACKDROP)
        headerBar:SetBackdropColor(0.12, 0.08, 0.03, 0.95)
        headerBar:SetBackdropBorderColor(0.60, 0.42, 0.15, 0.90)
    end

    local hIcon = headerBar:CreateTexture(nil, "ARTWORK")
    hIcon:SetSize(22, 22)
    hIcon:SetPoint("LEFT", headerBar, "LEFT", 8, 0)
    local okH = hIcon:SetTexture("Interface\\Calendar\\UI-Calendar-Button")
    if okH ~= false and hIcon:GetTexture() then
        hIcon:SetTexCoord(0.0078, 0.375, 0.0156, 0.75)
    else
        hIcon:SetTexture("Interface\\AddOns\\GuildManager\\Textures\\calendar.tga")
        hIcon:SetTexCoord(0, 1, 0, 1)
    end

    local hTitle = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hTitle:SetPoint("LEFT", hIcon, "RIGHT", 6, 0)
    hTitle:SetText("|cffffd200EVENTOS DA GUILDA|r")

    local hCount = headerBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hCount:SetPoint("LEFT", hTitle, "RIGHT", 8, 0)
    hCount:SetText("|cffaaaaaa(0 eventos)|r")
    self._eventsCountText = hCount

    local newEventBtn = CreateFrame("Button", nil, headerBar, "UIPanelButtonTemplate")
    newEventBtn:SetSize(126, 22)
    newEventBtn:SetPoint("RIGHT", headerBar, "RIGHT", -6, 0)
    newEventBtn:SetText("+ Novo Evento")
    newEventBtn:SetScript("OnClick", function()
        self:openEventModal(nil)
    end)

    -- Barra de ferramentas com Filtros por tipo e Caixa de Busca
    local toolbar = CreateFrame("Frame", nil, leftPanel, template)
    toolbar:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -4)
    toolbar:SetPoint("TOPRIGHT", headerBar, "BOTTOMRIGHT", 0, -4)
    toolbar:SetHeight(32)

    -- Botões de filtro rápido
    local filterButtons = {}
    local filterDefs = {
        { id = "TODOS",       label = "Todos" },
        { id = "RAID",        label = "Raides" },
        { id = "DUNGEON",     label = "Masmorras" },
        { id = "PVP",         label = "PvP" },
        { id = "REUNIAO",     label = "Reunião" },
        { id = "ANIVERSARIO", label = "Aniv. 🎂" },
    }

    local startX = 4
    for _, fDef in ipairs(filterDefs) do
        local btn = CreateFrame("Button", nil, toolbar, template)
        btn:SetSize(fDef.id == "ANIVERSARIO" and 64 or 56, 22)
        btn:SetPoint("LEFT", toolbar, "LEFT", startX, 0)
        startX = startX + (fDef.id == "ANIVERSARIO" and 68 or 60)

        if btn.SetBackdrop then
            btn:SetBackdrop(SUB_CONTAINER_BACKDROP)
            btn:SetBackdropColor(PALETTE.INACTIVE_TAB_BG[1], PALETTE.INACTIVE_TAB_BG[2], PALETTE.INACTIVE_TAB_BG[3], 0.8)
            btn:SetBackdropBorderColor(PALETTE.INACTIVE_TAB_BORDER[1], PALETTE.INACTIVE_TAB_BORDER[2], PALETTE.INACTIVE_TAB_BORDER[3], 0.8)
        end

        local bText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bText:SetPoint("CENTER", btn, "CENTER", 0, 0)
        bText:SetText(fDef.label)
        btn.bText = bText

        btn:SetScript("OnClick", function()
            self._currentFilterType = fDef.id
            self:updateFilterButtonsUI(filterButtons)
            self:renderEvents()
        end)

        filterButtons[fDef.id] = btn
    end
    self._filterButtons = filterButtons
    self:updateFilterButtonsUI(filterButtons)

    -- Caixa de Busca
    local searchEB = CreateFrame("EditBox", nil, toolbar, template)
    searchEB:SetPoint("RIGHT", toolbar, "RIGHT", -6, 0)
    searchEB:SetSize(130, 22)
    styleBox(searchEB)

    local searchPlaceholder = searchEB:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchPlaceholder:SetPoint("LEFT", searchEB, "LEFT", 8, 0)
    searchPlaceholder:SetText("Buscar...")

    searchEB:SetScript("OnTextChanged", function(box)
        local txt = box:GetText() or ""
        if txt == "" then
            searchPlaceholder:Show()
        else
            searchPlaceholder:Hide()
        end
        self._currentSearchText = txt
        self:renderEvents()
    end)
    searchEB:SetScript("OnEscapePressed", function(box)
        box:SetText("")
        box:ClearFocus()
    end)

    -- ScrollFrame dos Eventos
    local scrollFrame = CreateFrame("ScrollFrame", "GM_AgendaEventsScroll", leftPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 2, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -24, 6)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(524)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    self._eventsScrollChild = scrollChild

    leftPanel:EnableMouseWheel(true)
    leftPanel:SetScript("OnMouseWheel", function(_, delta)
        local cur = scrollFrame:GetVerticalScroll()
        scrollFrame:SetVerticalScroll(math.max(0, cur - (delta * 30)))
    end)

    local emptyEventsText = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyEventsText:SetPoint("CENTER", leftPanel, "CENTER", 0, -20)
    emptyEventsText:SetWidth(400)
    emptyEventsText:SetJustifyH("CENTER")
    emptyEventsText:SetText("Nenhum evento agendado.\nClique em |cffffff00+ Novo Evento|r acima para criar um evento.")
    emptyEventsText:Hide()
    self._emptyEventsText = emptyEventsText
end

--- Atualiza a estética visual dos botões de filtro
function AgendaView:updateFilterButtonsUI(buttons)
    for id, btn in pairs(buttons or {}) do
        local isActive = (self._currentFilterType == id)
        if btn.SetBackdrop then
            if isActive then
                btn:SetBackdropColor(PALETTE.ACTIVE_TAB_BG[1], PALETTE.ACTIVE_TAB_BG[2], PALETTE.ACTIVE_TAB_BG[3], 0.95)
                btn:SetBackdropBorderColor(PALETTE.ACTIVE_TAB_BORDER[1], PALETTE.ACTIVE_TAB_BORDER[2], PALETTE.ACTIVE_TAB_BORDER[3], 1.0)
                if btn.bText then btn.bText:SetTextColor(1.0, 0.85, 0.0) end
            else
                btn:SetBackdropColor(PALETTE.INACTIVE_TAB_BG[1], PALETTE.INACTIVE_TAB_BG[2], PALETTE.INACTIVE_TAB_BG[3], 0.80)
                btn:SetBackdropBorderColor(PALETTE.INACTIVE_TAB_BORDER[1], PALETTE.INACTIVE_TAB_BORDER[2], PALETTE.INACTIVE_TAB_BORDER[3], 0.80)
                if btn.bText then btn.bText:SetTextColor(0.75, 0.75, 0.75) end
            end
        end
    end
end

--- Cria o painel direito dedicado aos próximos aniversariantes da guilda.
function AgendaView:createRightPanel()
    local frame = self._frame
    if not frame then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    local rightPanel = CreateFrame("Frame", "GM_AgendaRightPanel", frame, template)
    rightPanel:SetSize(264, 476)
    rightPanel:SetPoint("TOPLEFT", self._leftPanel, "TOPRIGHT", 8, 0)
    if rightPanel.SetBackdrop then
        rightPanel:SetBackdrop(CONTAINER_BACKDROP)
        rightPanel:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        rightPanel:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end
    self._rightPanel = rightPanel

    -- Header do painel de aniversários
    local headerBar = CreateFrame("Frame", nil, rightPanel, template)
    headerBar:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 3, -3)
    headerBar:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -3, -3)
    headerBar:SetHeight(38)
    if headerBar.SetBackdrop then
        headerBar:SetBackdrop(SUB_CONTAINER_BACKDROP)
        headerBar:SetBackdropColor(0.12, 0.08, 0.03, 0.95)
        headerBar:SetBackdropBorderColor(0.60, 0.42, 0.15, 0.90)
    end

    local hIcon = headerBar:CreateTexture(nil, "ARTWORK")
    hIcon:SetSize(22, 22)
    hIcon:SetPoint("LEFT", headerBar, "LEFT", 8, 0)
    hIcon:SetTexture("Interface\\Icons\\INV_Holiday_Tow_SpicedCider")
    hIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local hTitle = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hTitle:SetPoint("TOPLEFT", hIcon, "TOPRIGHT", 6, 0)
    hTitle:SetText("|cffffd200🎂 ANIVERSARIANTES|r")

    local hSub = headerBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hSub:SetPoint("BOTTOMLEFT", hIcon, "BOTTOMRIGHT", 6, 0)
    hSub:SetText("|cffaaaaaaPróximos da guilda|r")

    -- ScrollFrame dos Aniversários
    local scrollFrame = CreateFrame("ScrollFrame", "GM_AgendaBirthdaysScroll", rightPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 2, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -24, 6)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(232)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    self._birthdaysScrollChild = scrollChild

    rightPanel:EnableMouseWheel(true)
    rightPanel:SetScript("OnMouseWheel", function(_, delta)
        local cur = scrollFrame:GetVerticalScroll()
        scrollFrame:SetVerticalScroll(math.max(0, cur - (delta * 24)))
    end)

    local emptyBirthdaysText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyBirthdaysText:SetPoint("CENTER", rightPanel, "CENTER", 0, -20)
    emptyBirthdaysText:SetWidth(220)
    emptyBirthdaysText:SetJustifyH("CENTER")
    emptyBirthdaysText:SetText("Nenhum aniversário cadastrado.\nAdicione a data na tela de membros ou notas da guilda.")
    emptyBirthdaysText:Hide()
    self._emptyBirthdaysText = emptyBirthdaysText
end

--- Atualiza a lista de eventos na View.
---@param events Event[]
function AgendaView:setEvents(events)
    self._events = events or {}
    self:renderEvents()
end

--- Atualiza a lista de próximos aniversariantes na View.
---@param birthdays table[]
function AgendaView:setUpcomingBirthdays(birthdays)
    local filtered = {}
    for _, item in ipairs(birthdays or {}) do
        local m = item.member
        local inGuild = true
        if m and type(m.isInGuild) == "function" then
            inGuild = m:isInGuild()
        end
        if inGuild then
            table.insert(filtered, item)
        end
    end
    self._upcomingBirthdays = filtered
    self:renderBirthdays()
end

--- Renderiza a lista de cards de eventos no painel esquerdo.
function AgendaView:renderEvents()
    if not self._eventsScrollChild then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    -- Oculta cards antigos no pool
    for _, card in ipairs(self._activeEventCardPool) do
        card:Hide()
    end

    local filterLower = self._currentFilterType ~= "TODOS" and self._currentFilterType or nil
    local searchLower = self._currentSearchText and self._currentSearchText:match("^%s*(.-)%s*$"):lower() or ""

    local visibleEvents = {}
    for _, ev in ipairs(self._events or {}) do
        local matchType = true
        if filterLower then
            matchType = (ev:getType() == filterLower)
        end

        local matchSearch = true
        if searchLower ~= "" then
            local t = (ev:getTitle() or ""):lower()
            local d = (ev:getDescription() or ""):lower()
            local c = (ev:getCreator() or ""):lower()
            if not t:find(searchLower, 1, true) and not d:find(searchLower, 1, true) and not c:find(searchLower, 1, true) then
                matchSearch = false
            end
        end

        if matchType and matchSearch then
            table.insert(visibleEvents, ev)
        end
    end

    if self._eventsCountText then
        self._eventsCountText:SetText(string.format("|cffaaaaaa(%d eventos)|r", #visibleEvents))
    end

    if #visibleEvents == 0 then
        if self._emptyEventsText then self._emptyEventsText:Show() end
        self._eventsScrollChild:SetHeight(1)
        return
    end

    if self._emptyEventsText then self._emptyEventsText:Hide() end

    local cardHeight = 98
    local gap = 6
    local totalY = 4

    for idx, ev in ipairs(visibleEvents) do
        local card = self._activeEventCardPool[idx]
        if not card then
            card = CreateFrame("Frame", nil, self._eventsScrollChild, template)
            card:SetSize(520, cardHeight)
            if card.SetBackdrop then
                card:SetBackdrop(SUB_CONTAINER_BACKDROP)
                card:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.85)
                card:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.90)
            end

            -- Badge do Tipo
            local typeBadge = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            typeBadge:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
            card.typeBadge = typeBadge

            -- Título do Evento
            local titleText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
            titleText:SetPoint("LEFT", typeBadge, "RIGHT", 6, 0)
            titleText:SetPoint("RIGHT", card, "RIGHT", -10, 0)
            titleText:SetJustifyH("LEFT")
            card.titleText = titleText

            -- Data e Horário
            local dateTimeText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            dateTimeText:SetPoint("TOPLEFT", typeBadge, "BOTTOMLEFT", 0, -5)
            card.dateTimeText = dateTimeText

            -- Criador e Convidados
            local infoText = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            infoText:SetPoint("LEFT", dateTimeText, "RIGHT", 12, 0)
            card.infoText = infoText

            -- Descrição
            local descText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            descText:SetPoint("TOPLEFT", dateTimeText, "BOTTOMLEFT", 0, -4)
            descText:SetPoint("RIGHT", card, "RIGHT", -210, 0)
            descText:SetJustifyH("LEFT")
            card.descText = descText

            -- Botões de Ação no Card
            local inviteBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
            inviteBtn:SetSize(90, 22)
            inviteBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -140, 8)
            inviteBtn:SetText("Convidados")
            card.inviteBtn = inviteBtn

            local editBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
            editBtn:SetSize(60, 22)
            editBtn:SetPoint("LEFT", inviteBtn, "RIGHT", 6, 0)
            editBtn:SetText("Editar")
            card.editBtn = editBtn

            local deleteBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
            deleteBtn:SetSize(60, 22)
            deleteBtn:SetPoint("LEFT", editBtn, "RIGHT", 6, 0)
            deleteBtn:SetText("Excluir")
            card.deleteBtn = deleteBtn

            self._activeEventCardPool[idx] = card
        end

        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", self._eventsScrollChild, "TOPLEFT", 2, -totalY)

        local tDef = TYPE_BADGES[ev:getType()] or TYPE_BADGES.OUTRO
        card.typeBadge:SetText(tDef.color .. tDef.label .. "|r")
        card.titleText:SetText("|cffffffff" .. (ev:getTitle() or "Sem título") .. "|r")

        local dtStr = string.format("|cffffd200📅 %s|r  |cffffffffàs %s|r", ev:getDate() or "-", ev:getTime() or "20:00")
        card.dateTimeText:SetText(dtStr)

        local creatorName = ev:getCreator()
        if creatorName == "" then creatorName = "Guilda" end
        local invCount = ev:getInviteeCount()
        card.infoText:SetText(string.format("|cff888888• Criado por: |cffffff00%s|r  |cff888888• 👥 |cff00ff88%d convidado(s)|r", creatorName, invCount))

        local desc = ev:getDescription() or ""
        if desc == "" then desc = "|cff666666(Sem descrição adicional)|r" end
        card.descText:SetText(desc)

        local currentEventId = ev:getId()

        card.inviteBtn:SetScript("OnClick", function()
            self:openInviteeModal(ev)
        end)

        card.editBtn:SetScript("OnClick", function()
            self:openEventModal(ev)
        end)

        card.deleteBtn:SetScript("OnClick", function()
            if self._onDeleteEventCallback then
                self._onDeleteEventCallback(currentEventId)
            end
        end)

        card:Show()
        totalY = totalY + cardHeight + gap
    end

    self._eventsScrollChild:SetHeight(math.max(totalY, 1))
end

--- Renderiza a lista de aniversariantes no painel direito.
function AgendaView:renderBirthdays()
    if not self._birthdaysScrollChild then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    for _, card in ipairs(self._activeBirthdayCardPool) do
        card:Hide()
    end

    local list = self._upcomingBirthdays or {}
    if #list == 0 then
        if self._emptyBirthdaysText then self._emptyBirthdaysText:Show() end
        self._birthdaysScrollChild:SetHeight(1)
        return
    end

    if self._emptyBirthdaysText then self._emptyBirthdaysText:Hide() end

    local cardHeight = 64
    local gap = 4
    local totalY = 4

    for idx, item in ipairs(list) do
        local card = self._activeBirthdayCardPool[idx]
        if not card then
            card = CreateFrame("Frame", nil, self._birthdaysScrollChild, template)
            card:SetSize(228, cardHeight)
            if card.SetBackdrop then
                card:SetBackdrop(SUB_CONTAINER_BACKDROP)
                card:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.85)
                card:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.90)
            end

            -- Ícone da Classe
            local cIcon = card:CreateTexture(nil, "ARTWORK")
            cIcon:SetSize(20, 20)
            cIcon:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -6)
            cIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
            card.cIcon = cIcon

            -- Nome e Nível
            local nameText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameText:SetPoint("LEFT", cIcon, "RIGHT", 5, 0)
            nameText:SetPoint("RIGHT", card, "RIGHT", -6, 0)
            nameText:SetJustifyH("LEFT")
            card.nameText = nameText

            -- Linha 2: Data + Cargo
            local detailText = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            detailText:SetPoint("TOPLEFT", cIcon, "BOTTOMLEFT", 0, -4)
            detailText:SetPoint("RIGHT", card, "RIGHT", -78, 0)
            detailText:SetJustifyH("LEFT")
            card.detailText = detailText

            -- Linha 3: Contagem regressiva (Hoje!, Amanhã, Em X dias)
            local countdownText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            countdownText:SetPoint("TOPLEFT", detailText, "BOTTOMLEFT", 0, -2)
            card.countdownText = countdownText

            -- Botão rápido: "+ Agendar"
            local scheduleBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
            scheduleBtn:SetSize(72, 20)
            scheduleBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -6, 6)
            scheduleBtn:SetText("+ Agendar")
            card.scheduleBtn = scheduleBtn

            self._activeBirthdayCardPool[idx] = card
        end

        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", self._birthdaysScrollChild, "TOPLEFT", 2, -totalY)

        local tok = item.class and (CLASS_NAME_TO_TOKEN[item.class:upper()] or item.class:upper()) or ""
        local coords = tok ~= "" and CLASS_ICON_COORDS[tok]
        if coords then
            card.cIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            card.cIcon:Show()
            card.nameText:SetPoint("LEFT", card.cIcon, "RIGHT", 5, 0)
        else
            card.cIcon:Hide()
            card.nameText:SetPoint("LEFT", card, "TOPLEFT", 8, -14)
        end

        card.nameText:SetText(getColoredName(item.cleanName or item.name, item.class) .. " |cff888888(Nv " .. (item.level or 1) .. ")|r")

        local rk = item.rank or ""
        if rk ~= "" then rk = " • " .. rk end
        card.detailText:SetText(string.format("|cffffd200Data: %s|r%s", item.birthday or "--/--", rk))
        card.countdownText:SetText(item.daysText or "")

        card.scheduleBtn:SetScript("OnClick", function()
            if self._onCreateBirthdayEventCallback and item.member then
                self._onCreateBirthdayEventCallback(item.member)
            else
                -- Fallback: abre modal de criação pré-preenchida
                local curYear = (date and date("*t") and date("*t").year) or 2026
                local m, d = (item.birthday or ""):match("^(%d%d?)/(%d%d?)$")
                local targetDate = string.format("%02d/%02d/%04d", tonumber(d) or 1, tonumber(m) or 1, item.targetYear or curYear)
                self:openEventModal(nil, {
                    title = "Aniversário de " .. (item.cleanName or item.name) .. " 🎂",
                    type = "ANIVERSARIO",
                    date = targetDate,
                    time = "20:00",
                    description = "Comemoração de aniversário de " .. (item.cleanName or item.name) .. "!",
                })
            end
        end)

        card:Show()
        totalY = totalY + cardHeight + gap
    end

    self._birthdaysScrollChild:SetHeight(math.max(totalY, 1))
end

--- =========================================================================
--- MODAL: CRIAR / EDITAR EVENTO
--- =========================================================================
function AgendaView:createEventModal()
    if self._eventModal then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    local modal = CreateFrame("Frame", "GM_AgendaEventModal", UIParent, template)
    modal:SetSize(450, 460)
    modal:SetFrameStrata("FULLSCREEN_DIALOG")
    modal:SetToplevel(true)
    modal:SetClampedToScreen(true)
    modal:EnableMouse(true)
    modal:SetMovable(true)
    modal:RegisterForDrag("LeftButton")
    modal:SetScript("OnDragStart", function(f) f:StartMoving() end)
    modal:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    modal:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    modal:Hide()

    if UISpecialFrames then
        table.insert(UISpecialFrames, "GM_AgendaEventModal")
    end

    if modal.SetBackdrop then
        modal:SetBackdrop(DIALOG_BACKDROP)
        modal:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], 0.98)
        modal:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], 1.0)
    end

    local closeBtn = CreateFrame("Button", nil, modal, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -4, -4)
    closeBtn:SetSize(28, 28)
    closeBtn:SetScript("OnClick", function() modal:Hide() end)

    local mTitle = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mTitle:SetPoint("TOPLEFT", modal, "TOPLEFT", 18, -16)
    mTitle:SetText("|cffffd200CRIAR NOVO EVENTO|r")
    modal.mTitle = mTitle

    local mSep = modal:CreateTexture(nil, "ARTWORK")
    mSep:SetPoint("TOPLEFT", modal, "TOPLEFT", 16, -44)
    mSep:SetPoint("RIGHT", modal, "RIGHT", -16, 0)
    mSep:SetHeight(1)
    mSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- Campo: Título
    local titleLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("TOPLEFT", mSep, "BOTTOMLEFT", 4, -10)
    titleLabel:SetText("|cffffd200Título do Evento:|r |cffff0000*|r")

    local titleEB = CreateFrame("EditBox", nil, modal, template)
    titleEB:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 0, -4)
    titleEB:SetSize(400, 24)
    styleBox(titleEB)
    modal.titleEB = titleEB

    -- Campo: Tipo de Evento
    local typeLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    typeLabel:SetPoint("TOPLEFT", titleEB, "BOTTOMLEFT", 0, -10)
    typeLabel:SetText("|cffffd200Tipo de Evento:|r")

    local typeButtons = {}
    local typeDefs = {
        { id = "RAID",        label = "Raide" },
        { id = "DUNGEON",     label = "Masmorra" },
        { id = "PVP",         label = "JxJ/PvP" },
        { id = "REUNIAO",     label = "Reunião" },
        { id = "ANIVERSARIO", label = "Aniversário" },
        { id = "OUTRO",       label = "Outro" },
    }
    modal.selectedType = "RAID"

    local tStartX = 4
    local tRow1 = CreateFrame("Frame", nil, modal)
    tRow1:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", 0, -4)
    tRow1:SetSize(400, 26)

    for i, tDef in ipairs(typeDefs) do
        local btn = CreateFrame("Button", nil, tRow1, template)
        btn:SetSize(62, 22)
        btn:SetPoint("LEFT", tRow1, "LEFT", (i - 1) * 67, 0)
        if btn.SetBackdrop then
            btn:SetBackdrop(SUB_CONTAINER_BACKDROP)
            btn:SetBackdropColor(PALETTE.INACTIVE_TAB_BG[1], PALETTE.INACTIVE_TAB_BG[2], PALETTE.INACTIVE_TAB_BG[3], 0.8)
            btn:SetBackdropBorderColor(PALETTE.INACTIVE_TAB_BORDER[1], PALETTE.INACTIVE_TAB_BORDER[2], PALETTE.INACTIVE_TAB_BORDER[3], 0.8)
        end
        local bText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bText:SetPoint("CENTER", btn, "CENTER", 0, 0)
        bText:SetText(tDef.label)
        btn.bText = bText

        btn:SetScript("OnClick", function()
            modal.selectedType = tDef.id
            for tid, obtn in pairs(typeButtons) do
                local active = (tid == tDef.id)
                if obtn.SetBackdrop then
                    if active then
                        obtn:SetBackdropColor(PALETTE.ACTIVE_TAB_BG[1], PALETTE.ACTIVE_TAB_BG[2], PALETTE.ACTIVE_TAB_BG[3], 0.95)
                        obtn:SetBackdropBorderColor(PALETTE.ACTIVE_TAB_BORDER[1], PALETTE.ACTIVE_TAB_BORDER[2], PALETTE.ACTIVE_TAB_BORDER[3], 1.0)
                        if obtn.bText then obtn.bText:SetTextColor(1.0, 0.85, 0.0) end
                    else
                        obtn:SetBackdropColor(PALETTE.INACTIVE_TAB_BG[1], PALETTE.INACTIVE_TAB_BG[2], PALETTE.INACTIVE_TAB_BG[3], 0.8)
                        obtn:SetBackdropBorderColor(PALETTE.INACTIVE_TAB_BORDER[1], PALETTE.INACTIVE_TAB_BORDER[2], PALETTE.INACTIVE_TAB_BORDER[3], 0.8)
                        if obtn.bText then obtn.bText:SetTextColor(0.75, 0.75, 0.75) end
                    end
                end
            end
        end)
        typeButtons[tDef.id] = btn
    end
    modal.typeButtons = typeButtons

    -- Linha: Data e Horário (duas colunas perfeitamente alinhadas aos 400px de largura)
    local dateLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dateLabel:SetPoint("TOPLEFT", tRow1, "BOTTOMLEFT", 0, -10)
    dateLabel:SetText("|cffffd200Data:|r |cffff0000*|r |cffaaaaaa(DD/MM/AAAA ou MM/dd)|r")

    local dateEB = CreateFrame("EditBox", nil, modal, template)
    dateEB:SetPoint("TOPLEFT", dateLabel, "BOTTOMLEFT", 0, -4)
    dateEB:SetSize(250, 24)
    styleBox(dateEB)
    modal.dateEB = dateEB

    local timeLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timeLabel:SetPoint("TOPLEFT", dateLabel, "TOPLEFT", 265, 0)
    timeLabel:SetText("|cffffd200Horário:|r |cffaaaaaa(HH:MM)|r")

    local timeEB = CreateFrame("EditBox", nil, modal, template)
    timeEB:SetPoint("TOPLEFT", timeLabel, "BOTTOMLEFT", 0, -4)
    timeEB:SetSize(135, 24)
    timeEB:SetMaxLetters(5)
    styleBox(timeEB)
    modal.timeEB = timeEB

    -- Campo: Descrição (Container com Backdrop clássico evita o colapso nativo de EditBox multiline no motor do WoW)
    local descLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", dateEB, "BOTTOMLEFT", 0, -10)
    descLabel:SetText("|cffffd200Descrição e Detalhes do Evento:|r")

    local descContainer = CreateFrame("Frame", nil, modal, template)
    descContainer:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -4)
    descContainer:SetSize(400, 140)
    if descContainer.SetBackdrop then
        descContainer:SetBackdrop(SUB_CONTAINER_BACKDROP)
        descContainer:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        descContainer:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local descEB = CreateFrame("EditBox", nil, descContainer)
    descEB:SetPoint("TOPLEFT", descContainer, "TOPLEFT", 8, -6)
    descEB:SetPoint("BOTTOMRIGHT", descContainer, "BOTTOMRIGHT", -8, 6)
    descEB:SetMultiLine(true)
    descEB:SetAutoFocus(false)
    descEB:SetFontObject("GameFontHighlightSmall")
    descEB:SetMaxLetters(500)
    descEB:SetTextInsets(0, 0, 0, 0)
    modal.descEB = descEB

    descContainer:EnableMouse(true)
    descContainer:SetScript("OnMouseDown", function()
        descEB:SetFocus()
    end)

    descEB:SetScript("OnEditFocusGained", function()
        if descContainer.SetBackdropBorderColor then
            descContainer:SetBackdropBorderColor(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], 1.0)
            descContainer:SetBackdropColor(PALETTE.FOCUS_BG[1], PALETTE.FOCUS_BG[2], PALETTE.FOCUS_BG[3], 0.95)
        end
    end)
    descEB:SetScript("OnEditFocusLost", function()
        if descContainer.SetBackdropBorderColor then
            descContainer:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.90)
            descContainer:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        end
    end)

    -- Atalhos de Teclado (TAB para avançar campo e ESC para fechar)
    titleEB:SetScript("OnTabPressed", function() dateEB:SetFocus() end)
    titleEB:SetScript("OnEnterPressed", function() dateEB:SetFocus() end)
    titleEB:SetScript("OnEscapePressed", function() modal:Hide() end)

    dateEB:SetScript("OnTabPressed", function() timeEB:SetFocus() end)
    dateEB:SetScript("OnEnterPressed", function() timeEB:SetFocus() end)
    dateEB:SetScript("OnEscapePressed", function() modal:Hide() end)

    timeEB:SetScript("OnTabPressed", function() descEB:SetFocus() end)
    timeEB:SetScript("OnEnterPressed", function() descEB:SetFocus() end)
    timeEB:SetScript("OnEscapePressed", function() modal:Hide() end)

    descEB:SetScript("OnTabPressed", function() titleEB:SetFocus() end)
    descEB:SetScript("OnEscapePressed", function() descEB:ClearFocus() end)

    -- Mensagem de Erro / Feedback
    local errText = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    errText:SetPoint("TOPLEFT", descContainer, "BOTTOMLEFT", 4, -6)
    errText:SetPoint("RIGHT", modal, "RIGHT", -20, 0)
    errText:SetJustifyH("LEFT")
    errText:SetTextColor(1.0, 0.3, 0.3)
    errText:SetText("")
    modal.errText = errText

    -- Botões Salvar e Cancelar
    local saveBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    saveBtn:SetSize(140, 26)
    saveBtn:SetPoint("BOTTOMLEFT", modal, "BOTTOMLEFT", 20, 16)
    saveBtn:SetText("Salvar Evento")
    modal.saveBtn = saveBtn

    saveBtn:SetScript("OnClick", function()
        local tVal = titleEB:GetText() or ""
        local dVal = dateEB:GetText() or ""
        local hVal = timeEB:GetText() or "20:00"
        local descVal = descEB:GetText() or ""

        if tVal:match("^%s*$") then
            errText:SetText("O título do evento é obrigatório.")
            return
        end

        if dVal:match("^%s*$") then
            errText:SetText("A data do evento é obrigatória.")
            return
        end

        local ok = false
        local err = nil
        if modal.editingEventId then
            if self._onUpdateEventCallback then
                ok, err = self._onUpdateEventCallback(modal.editingEventId, tVal, modal.selectedType, dVal, hVal, descVal)
            end
        else
            if self._onCreateEventCallback then
                ok, err = self._onCreateEventCallback(tVal, modal.selectedType, dVal, hVal, descVal)
            end
        end

        if ok then
            modal:Hide()
        else
            errText:SetText(err or "Erro ao salvar evento.")
        end
    end)

    local cancelBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    cancelBtn:SetSize(100, 26)
    cancelBtn:SetPoint("LEFT", saveBtn, "RIGHT", 10, 0)
    cancelBtn:SetText("Cancelar")
    cancelBtn:SetScript("OnClick", function() modal:Hide() end)

    self._eventModal = modal
end

--- Abre a modal de criação ou edição de evento.
---@param event Event|nil
---@param prefill table|nil
function AgendaView:openEventModal(event, prefill)
    if not self._eventModal then return end
    local modal = self._eventModal

    modal.errText:SetText("")

    if event then
        modal.editingEventId = event:getId()
        modal.mTitle:SetText("|cffffd200EDITAR EVENTO|r")
        modal.titleEB:SetText(event:getTitle() or "")
        modal.dateEB:SetText(event:getDate() or "")
        modal.timeEB:SetText(event:getTime() or "20:00")
        modal.descEB:SetText(event:getDescription() or "")
        modal.selectedType = event:getType() or "OUTRO"
    else
        modal.editingEventId = nil
        modal.mTitle:SetText("|cffffd200CRIAR NOVO EVENTO|r")
        local p = prefill or {}
        modal.titleEB:SetText(p.title or "")
        modal.dateEB:SetText(p.date or "")
        modal.timeEB:SetText(p.time or "20:00")
        modal.descEB:SetText(p.description or "")
        modal.selectedType = p.type or "RAID"
    end

    -- Atualiza seleção visual dos botões de tipo
    for tid, btn in pairs(modal.typeButtons or {}) do
        local active = (tid == modal.selectedType)
        if btn.SetBackdrop then
            if active then
                btn:SetBackdropColor(PALETTE.ACTIVE_TAB_BG[1], PALETTE.ACTIVE_TAB_BG[2], PALETTE.ACTIVE_TAB_BG[3], 0.95)
                btn:SetBackdropBorderColor(PALETTE.ACTIVE_TAB_BORDER[1], PALETTE.ACTIVE_TAB_BORDER[2], PALETTE.ACTIVE_TAB_BORDER[3], 1.0)
                if btn.bText then btn.bText:SetTextColor(1.0, 0.85, 0.0) end
            else
                btn:SetBackdropColor(PALETTE.INACTIVE_TAB_BG[1], PALETTE.INACTIVE_TAB_BG[2], PALETTE.INACTIVE_TAB_BG[3], 0.8)
                btn:SetBackdropBorderColor(PALETTE.INACTIVE_TAB_BORDER[1], PALETTE.INACTIVE_TAB_BORDER[2], PALETTE.INACTIVE_TAB_BORDER[3], 0.8)
                if btn.bText then btn.bText:SetTextColor(0.75, 0.75, 0.75) end
            end
        end
    end

    modal:Show()
    modal.titleEB:SetFocus()
end

--- =========================================================================
--- MODAL: GERENCIADOR DE CONVIDADOS
--- =========================================================================
function AgendaView:createInviteeModal()
    if self._inviteeModal then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    local modal = CreateFrame("Frame", "GM_AgendaInviteeModal", UIParent, template)
    modal:SetSize(520, 500)
    modal:SetFrameStrata("FULLSCREEN_DIALOG")
    modal:SetToplevel(true)
    modal:SetClampedToScreen(true)
    modal:EnableMouse(true)
    modal:SetMovable(true)
    modal:RegisterForDrag("LeftButton")
    modal:SetScript("OnDragStart", function(f) f:StartMoving() end)
    modal:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    modal:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
    modal:Hide()

    if UISpecialFrames then
        table.insert(UISpecialFrames, "GM_AgendaInviteeModal")
    end

    if modal.SetBackdrop then
        modal:SetBackdrop(DIALOG_BACKDROP)
        modal:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], 0.98)
        modal:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], 1.0)
    end

    local closeBtn = CreateFrame("Button", nil, modal, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -4, -4)
    closeBtn:SetSize(28, 28)
    closeBtn:SetScript("OnClick", function() modal:Hide() end)

    local mTitle = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mTitle:SetPoint("TOPLEFT", modal, "TOPLEFT", 18, -16)
    mTitle:SetText("|cffffd200CONVIDADOS DO EVENTO|r")

    local mSubtitle = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mSubtitle:SetPoint("TOPLEFT", mTitle, "BOTTOMLEFT", 0, -4)
    mSubtitle:SetText("|cffaaaaaaGerencie os participantes e envie convites in-game|r")
    modal.mSubtitle = mSubtitle

    local mSep = modal:CreateTexture(nil, "ARTWORK")
    mSep:SetPoint("TOPLEFT", modal, "TOPLEFT", 16, -56)
    mSep:SetPoint("RIGHT", modal, "RIGHT", -16, 0)
    mSep:SetHeight(1)
    mSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- Barra superior com botão "Convidar Online para Grupo"
    local inviteAllBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    inviteAllBtn:SetSize(210, 24)
    inviteAllBtn:SetPoint("TOPLEFT", mSep, "BOTTOMLEFT", 4, -10)
    inviteAllBtn:SetText("Convidar Online para Grupo")
    inviteAllBtn:SetScript("OnClick", function()
        if modal.currentEvent and self._onInviteAllOnlineCallback then
            self._onInviteAllOnlineCallback(modal.currentEvent:getId())
        end
    end)

    local totalText = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalText:SetPoint("LEFT", inviteAllBtn, "RIGHT", 12, 0)
    totalText:SetText("|cffaaaaaaTotal: 0 convidados|r")
    modal.totalText = totalText

    -- Linha de Adicionar Convidado
    local addLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLabel:SetPoint("TOPLEFT", inviteAllBtn, "BOTTOMLEFT", 0, -12)
    addLabel:SetText("|cffffd200Adicionar Convidado:|r")

    local addEB = CreateFrame("EditBox", nil, modal, template)
    addEB:SetPoint("TOPLEFT", addLabel, "BOTTOMLEFT", 0, -4)
    addEB:SetSize(260, 22)
    styleBox(addEB)
    modal.addEB = addEB

    local addBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    addBtn:SetSize(110, 22)
    addBtn:SetPoint("LEFT", addEB, "RIGHT", 8, 0)
    addBtn:SetText("+ Adicionar")
    addBtn:SetScript("OnClick", function()
        local name = addEB:GetText() or ""
        if name:match("^%s*$") then return end
        if modal.currentEvent and self._onAddInviteeCallback then
            local ok, err = self._onAddInviteeCallback(modal.currentEvent:getId(), name)
            if ok then
                addEB:SetText("")
                -- Atualiza a tela de convidados
                self:refreshInviteeModal()
            else
                print(string.format("|cffff4444[GuildManager]|r %s", err or "Falha ao adicionar."))
            end
        end
    end)
    addEB:SetScript("OnEnterPressed", function() addBtn:Click() end)

    -- Container e ScrollFrame da lista de convidados
    local listContainer = CreateFrame("Frame", nil, modal, template)
    listContainer:SetPoint("TOPLEFT", addEB, "BOTTOMLEFT", 0, -10)
    listContainer:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -16, 46)
    if listContainer.SetBackdrop then
        listContainer:SetBackdrop(CONTAINER_BACKDROP)
        listContainer:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], 0.90)
        listContainer:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], 0.90)
    end

    local scrollFrame = CreateFrame("ScrollFrame", "GM_InviteeScrollFrame", listContainer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -22, 4)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(460)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    modal.scrollChild = scrollChild
    modal.inviteeCardPool = {}

    listContainer:EnableMouseWheel(true)
    listContainer:SetScript("OnMouseWheel", function(_, delta)
        local cur = scrollFrame:GetVerticalScroll()
        scrollFrame:SetVerticalScroll(math.max(0, cur - (delta * 24)))
    end)

    local emptyInvText = listContainer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyInvText:SetPoint("CENTER", listContainer, "CENTER", 0, 0)
    emptyInvText:SetText("Nenhum membro convidado para este evento.")
    modal.emptyInvText = emptyInvText

    -- Botão Fechar inferior
    local bottomCloseBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    bottomCloseBtn:SetSize(100, 24)
    bottomCloseBtn:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -16, 12)
    bottomCloseBtn:SetText("Fechar")
    bottomCloseBtn:SetScript("OnClick", function() modal:Hide() end)

    self._inviteeModal = modal
end

--- Abre a modal de gerenciamento de convidados do evento.
---@param event Event
function AgendaView:openInviteeModal(event)
    if not self._inviteeModal or not event then return end
    self._inviteeModal.currentEvent = event
    self:refreshInviteeModal()
    self._inviteeModal:Show()
end

--- Atualiza a lista visual de convidados dentro da modal de convidados.
function AgendaView:refreshInviteeModal()
    local modal = self._inviteeModal
    if not modal or not modal.currentEvent then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    local ev = modal.currentEvent
    modal.mSubtitle:SetText(string.format("|cffffd200%s|r  |cffaaaaaa(%s às %s)|r", ev:getTitle(), ev:getDate(), ev:getTime()))

    for _, c in ipairs(modal.inviteeCardPool) do
        c:Hide()
    end

    local invitees = ev:getInvitees() or {}
    modal.totalText:SetText(string.format("|cffaaaaaaTotal: |cffffd200%d|r convidado(s)|r", #invitees))

    if #invitees == 0 then
        modal.emptyInvText:Show()
        modal.scrollChild:SetHeight(1)
        return
    end

    modal.emptyInvText:Hide()

    local rowHeight = 32
    local gap = 4
    local totalY = 4

    for idx, inv in ipairs(invitees) do
        local row = modal.inviteeCardPool[idx]
        if not row then
            row = CreateFrame("Frame", nil, modal.scrollChild, template)
            row:SetSize(454, rowHeight)
            if row.SetBackdrop then
                row:SetBackdrop(SUB_CONTAINER_BACKDROP)
                row:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.85)
                row:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.90)
            end

            -- Ícone de Classe
            local cIcon = row:CreateTexture(nil, "ARTWORK")
            cIcon:SetSize(18, 18)
            cIcon:SetPoint("LEFT", row, "LEFT", 8, 0)
            cIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
            row.cIcon = cIcon

            -- Nome e Nível
            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameText:SetPoint("LEFT", cIcon, "RIGHT", 6, 0)
            row.nameText = nameText

            -- Status do Convite
            local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            statusText:SetPoint("LEFT", nameText, "RIGHT", 12, 0)
            row.statusText = statusText

            -- Botão Convidar para Grupo WoW
            local invBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            invBtn:SetSize(110, 20)
            invBtn:SetPoint("RIGHT", row, "RIGHT", -34, 0)
            invBtn:SetText("Convidar (Grupo)")
            row.invBtn = invBtn

            -- Botão Remover
            local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            delBtn:SetSize(22, 20)
            delBtn:SetPoint("LEFT", invBtn, "RIGHT", 4, 0)
            delBtn:SetText("X")
            row.delBtn = delBtn

            modal.inviteeCardPool[idx] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", modal.scrollChild, "TOPLEFT", 2, -totalY)

        local tok = inv.class and (CLASS_NAME_TO_TOKEN[inv.class:upper()] or inv.class:upper()) or ""
        local coords = tok ~= "" and CLASS_ICON_COORDS[tok]
        if coords then
            row.cIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            row.cIcon:Show()
            row.nameText:SetPoint("LEFT", row.cIcon, "RIGHT", 6, 0)
        else
            row.cIcon:Hide()
            row.nameText:SetPoint("LEFT", row, "LEFT", 10, 0)
        end

        row.nameText:SetText(getColoredName(inv.name, inv.class) .. " |cff888888(Nv " .. (inv.level or 1) .. ")|r")

        local stColor = "|cffffff00"
        if inv.status == "CONFIRMADO" then stColor = "|cff00ff00"
        elseif inv.status == "RECUSADO" then stColor = "|cffff4444" end
        row.statusText:SetText(stColor .. "[" .. (inv.status or "PENDENTE") .. "]|r")

        local invName = inv.name
        row.invBtn:SetScript("OnClick", function()
            if self._onInviteMemberInGameCallback then
                self._onInviteMemberInGameCallback(invName)
            end
        end)

        row.delBtn:SetScript("OnClick", function()
            if self._onRemoveInviteeCallback and modal.currentEvent then
                self._onRemoveInviteeCallback(modal.currentEvent:getId(), invName)
                self:refreshInviteeModal()
                self:renderEvents()
            end
        end)

        row:Show()
        totalY = totalY + rowHeight + gap
    end

    modal.scrollChild:SetHeight(math.max(totalY, 1))
end

_G.AgendaView = AgendaView
