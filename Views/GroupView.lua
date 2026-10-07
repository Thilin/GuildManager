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
    ACTIVE_TAB_BG = { 0.20, 0.13, 0.05, 0.95 },
    ACTIVE_TAB_BORDER = { 0.95, 0.70, 0.25, 1.0 },
    INACTIVE_TAB_BG = { 0.045, 0.030, 0.012, 0.80 },
    INACTIVE_TAB_BORDER = { 0.50, 0.33, 0.12, 0.85 },
    ROLE_TANK = { 0.29, 0.56, 0.88 },
    ROLE_HEALER = { 0.18, 0.80, 0.44 },
    ROLE_DPS = { 0.91, 0.30, 0.24 },
}

--- Construtor da View de Grupos.
---@return GroupView
function GroupView:new()
    local instance = setmetatable({}, self)

    instance._frame = nil
    instance._columns = {}
    instance._groups = {}
    instance._guildMembers = {}
    instance._currentDetailGroupId = nil

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

    -- Modais
    instance._createModal = nil
    instance._addMemberModal = nil
    instance._leaderPickerModal = nil
    instance._detailModal = nil

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

--- Formata o nome do membro com a cor da sua classe.
local function getColoredMemberName(name, classToken)
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

--- Retorna o texto formatado da função do membro.
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

--- Busca um membro na lista de membros da guilda por nome (tolerante a realms e maiúsculas).
function GroupView:findGuildMember(name)
    if not name or name == "" then return nil end
    local clean = (name:match("^[^-]+") or name):match("^%s*(.-)%s*$")
    local cleanLower = clean:lower()
    local firstClean = (clean:match("^(%S+)") or clean):lower()

    for _, m in ipairs(self._guildMembers or {}) do
        local mName = m:getName() or ""
        local mClean = (mName:match("^[^-]+") or mName):match("^%s*(.-)%s*$") or mName
        local mFirst = (mClean:match("^(%S+)") or mClean):lower()
        if mClean:lower() == cleanLower or mFirst == firstClean then
            return m
        end
    end
    return nil
end

--- Resolve o token da classe de um membro (ex: "WARRIOR", "PALADIN", etc.).
--- Realiza fallback em múltiplas fontes: valor pré-existente, self._guildMembers,
--- MemberService, Roster da Blizzard e GetPlayerInfoByGUID.
---@param name string
---@param fallbackClass string|nil
---@return string @Token da classe em maiúsculas (ex: "WARRIOR") ou "" se não encontrado
function GroupView:resolveMemberClass(name, fallbackClass)
    if fallbackClass and fallbackClass ~= "" then
        local raw = fallbackClass:match("^%s*(.-)%s*$") or fallbackClass
        local tok = CLASS_NAME_TO_TOKEN[raw:upper()] or raw:upper()
        if CLASS_ICON_COORDS[tok] then
            return tok
        end
    end

    if not name or name == "" then
        return ""
    end

    local clean = name:match("^[^-]+") or name
    clean = clean:match("^%s*(.-)%s*$") or clean
    local cleanLower = clean:lower()
    local firstCleanLower = (clean:match("^(%S+)") or clean):lower()

    -- 1. Busca na lista em cache de membros da guilda (self._guildMembers)
    for _, m in ipairs(self._guildMembers or {}) do
        local mName = m:getName() or ""
        local mClean = (mName:match("^[^-]+") or mName):match("^%s*(.-)%s*$") or mName
        local mFirst = (mClean:match("^(%S+)") or mClean):lower()
        if mClean:lower() == cleanLower or mFirst == firstCleanLower then
            local c = m:getClass()
            if c and c ~= "" then
                local tok = CLASS_NAME_TO_TOKEN[c:upper()] or c:upper()
                if CLASS_ICON_COORDS[tok] then return tok end
            end
            local cDisp = m:getClassDisplayName()
            if cDisp and cDisp ~= "" then
                local tok = CLASS_NAME_TO_TOKEN[cDisp:upper()]
                if tok and CLASS_ICON_COORDS[tok] then return tok end
            end
        end
    end

    -- 2. Busca no MemberService do Addon
    if _G.GM and _G.GM.memberService then
        local m = nil
        if _G.GM.memberService.getMember then
            m = _G.GM.memberService:getMember(clean) or _G.GM.memberService:getMember(name)
        end
        if not m and _G.GM.memberService.getAllMembers then
            for _, cand in ipairs(_G.GM.memberService:getAllMembers() or {}) do
                local cName = cand:getName() or ""
                local cClean = (cName:match("^[^-]+") or cName):match("^%s*(.-)%s*$") or cName
                if cClean:lower() == cleanLower or (cClean:match("^(%S+)") or ""):lower() == firstCleanLower then
                    m = cand
                    break
                end
            end
        end
        if m then
            local c = m:getClass()
            if c and c ~= "" then
                local tok = CLASS_NAME_TO_TOKEN[c:upper()] or c:upper()
                if CLASS_ICON_COORDS[tok] then return tok end
            end
            local cDisp = m:getClassDisplayName()
            if cDisp and cDisp ~= "" then
                local tok = CLASS_NAME_TO_TOKEN[cDisp:upper()]
                if tok and CLASS_ICON_COORDS[tok] then return tok end
            end
        end
    end

    -- 3. Busca no GuildRosterService do Addon
    if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.getRosterData then
        local roster = _G.GM.guildRosterService:getRosterData()
        if roster then
            local rData = roster[clean] or roster[cleanLower] or roster[name] or roster[name:lower()]
            if rData then
                local c = rData.classFileName or rData.class
                if c and c ~= "" then
                    local tok = CLASS_NAME_TO_TOKEN[c:upper()] or c:upper()
                    if CLASS_ICON_COORDS[tok] then return tok end
                end
            end
        end
    end

    -- 4. Busca nativa na Blizzard Guild API
    if GetNumGuildMembers and GetGuildRosterInfo then
        local num = GetNumGuildMembers() or 0
        for i = 1, num do
            local gName, _, _, _, gClassDisp, _, _, _, _, _, gClass = GetGuildRosterInfo(i)
            if gName then
                local gClean = (gName:match("^[^-]+") or gName):match("^%s*(.-)%s*$") or gName
                local gFirst = (gClean:match("^(%S+)") or gClean):lower()
                if gClean:lower() == cleanLower or gFirst == firstCleanLower then
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

--- Helper para estilizar caixas EditBox no padrão do Addon.
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

--- Cria a interface principal da janela de grupos (3 Colunas).
function GroupView:createUI()
    if self._frame then return end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "GuildManagerGroupFrame", UIParent, template)
    self._frame = frame

    frame:SetSize(840, 510)
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
        table.insert(UISpecialFrames, "GuildManagerGroupFrame")
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
        if self._createModal and self._createModal:IsShown() then self._createModal:Hide() end
        if self._addMemberModal and self._addMemberModal:IsShown() then self._addMemberModal:Hide() end
        if self._leaderPickerModal and self._leaderPickerModal:IsShown() then self._leaderPickerModal:Hide() end
        if self._detailModal and self._detailModal:IsShown() then self._detailModal:Hide() end
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

    -- Moldura e borda temática Blizzard
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
    titleText:SetText("|cffffd200GERENCIAMENTO DE GRUPOS DA GUILDA|r")

    -- Subtítulo informativo
    local subtitleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitleText:SetPoint("LEFT", titleText, "RIGHT", 12, 0)
    subtitleText:SetText("|cffaaaaaa(Masmorras, Raides e Atividades Diversas)|r")

    -- Divisória abaixo do cabeçalho
    local headerSep = frame:CreateTexture(nil, "ARTWORK")
    headerSep:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -44)
    headerSep:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    headerSep:SetHeight(1)
    headerSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- Criação das abas laterais, 3 colunas e modais
    self:createSideTabs()
    self:createThreeColumns()
    self:createModals()
end

--- Cria as abas laterais (Auditoria, Logs, Grupos).
function GroupView:createSideTabs()
    local frame = self._frame
    if not frame then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    -- Aba 1: Auditoria
    local tabAudit = CreateFrame("Button", "GM_GroupSideTab_Audit", frame, template)
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
            local auditFrame = (_G.GM and _G.GM.auditView and _G.GM.auditView.getFrame and _G.GM.auditView:getFrame())
            if auditFrame and point then
                auditFrame:ClearAllPoints()
                if relativeTo then auditFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs) else auditFrame:SetPoint(point, xOfs, yOfs) end
            end
        end
    end)

    -- Aba 2: Logs
    local tabLogs = CreateFrame("Button", "GM_GroupSideTab_Logs", frame, template)
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
            local logFrame = (_G.GM and _G.GM.logView and _G.GM.logView.getFrame and _G.GM.logView:getFrame())
            if logFrame and point then
                logFrame:ClearAllPoints()
                if relativeTo then logFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs) else logFrame:SetPoint(point, xOfs, yOfs) end
            end
        end
    end)

    -- Aba 3: Grupos (Ativa)
    local tabGroups = CreateFrame("Button", "GM_GroupSideTab_Groups", frame, template)
    tabGroups:SetSize(36, 36)
    tabGroups:SetPoint("TOPLEFT", tabLogs, "BOTTOMLEFT", 0, -8)
    if tabGroups.SetBackdrop then
        tabGroups:SetBackdrop(SIDE_TAB_BACKDROP)
        tabGroups:SetBackdropColor(0.18, 0.12, 0.04, 0.95)
        tabGroups:SetBackdropBorderColor(1.0, 0.82, 0.20, 1.0)
    end
    local groupsIcon = tabGroups:CreateTexture(nil, "ARTWORK")
    groupsIcon:SetPoint("TOPLEFT", tabGroups, "TOPLEFT", 4, -4)
    groupsIcon:SetPoint("BOTTOMRIGHT", tabGroups, "BOTTOMRIGHT", -4, 4)
    groupsIcon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    groupsIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    groupsIcon:SetVertexColor(1.0, 1.0, 1.0)

    local groupsGlow = tabGroups:CreateTexture(nil, "OVERLAY")
    groupsGlow:SetPoint("TOPLEFT", tabGroups, "TOPLEFT", -2, 2)
    groupsGlow:SetPoint("BOTTOMRIGHT", tabGroups, "BOTTOMRIGHT", 2, -2)
    groupsGlow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    groupsGlow:SetBlendMode("ADD")
    groupsGlow:SetVertexColor(1.0, 0.85, 0.20, 0.80)

    tabGroups:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd200Gerenciamento de Grupos|r")
        GameTooltip:AddLine("|cff888888(Aba atual)|r", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Organização de grupos para Masmorras, Raides e Atividades Diversas.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    tabGroups:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Aba 4: Agenda
    local tabAgenda = CreateFrame("Button", "GM_GroupSideTab_Agenda", frame, template)
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

    tabAgenda:SetScript("OnEnter", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.95, 0.70, 0.25, 1.0)
            btn:SetBackdropColor(0.08, 0.05, 0.02, 0.95)
        end
        agendaIcon:SetVertexColor(1.0, 1.0, 1.0)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd200Agenda da Guilda|r")
        GameTooltip:AddLine("Clique para alternar para a tela de Agenda e Eventos da guilda.", 1, 1, 1, true)
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
        if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841) end
        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
        self:hide()
        local agendaCtrl = (_G.GM and _G.GM.agendaController) or _G.agendaController
        if agendaCtrl then
            agendaCtrl:show()
            local aFrame = (_G.GM and _G.GM.agendaView and _G.GM.agendaView.getFrame and _G.GM.agendaView:getFrame())
            if aFrame and point then
                aFrame:ClearAllPoints()
                if relativeTo then aFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs) else aFrame:SetPoint(point, xOfs, yOfs) end
            end
        end
    end)

    -- Aba 5: Configurações do Addon
    local tabSettings = CreateFrame("Button", "GM_GroupSideTab_Settings", frame, template)
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
            local sFrame = (_G.GM and _G.GM.settingsView and _G.GM.settingsView.getFrame and _G.GM.settingsView:getFrame()) or (settingsCtrl._settingsView and settingsCtrl._settingsView:getFrame())
            if sFrame and point then
                sFrame:ClearAllPoints()
                if relativeTo then sFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs) else sFrame:SetPoint(point, xOfs, yOfs) end
            end
        end
    end)

    self._tabAudit = tabAudit
    self._tabLogs = tabLogs
    self._tabGroups = tabGroups
    self._tabSettings = tabSettings
end

--- Cria as 3 colunas: Masmorras, Raides e Diversos.
function GroupView:createThreeColumns()
    local frame = self._frame
    if not frame then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    local columnDefs = {
        {
            type = GroupType.DUNGEON,
            title = "MASMORRAS",
            subtitle = "5 Jogadores",
            titleColor = "|cff4a90e2",
            icon = "Interface\\Icons\\INV_Shield_04",
            x = 16,
        },
        {
            type = GroupType.RAID,
            title = "RAIDES",
            subtitle = "10 / 25 / 40 Jogadores",
            titleColor = "|cffff8000",
            icon = "Interface\\Icons\\INV_Helmet_06",
            x = 288,
        },
        {
            type = GroupType.MISC,
            title = "DIVERSOS",
            subtitle = "PvP / Farm / Eventos",
            titleColor = "|cff00ff88",
            icon = "Interface\\Icons\\INV_Misc_GroupLooking",
            x = 560,
        },
    }

    self._columns = {}

    for _, def in ipairs(columnDefs) do
        local col = CreateFrame("Frame", "GM_GroupCol_" .. def.type, frame, template)
        col:SetSize(262, 450)
        col:SetPoint("TOPLEFT", frame, "TOPLEFT", def.x, -50)

        if col.SetBackdrop then
            col:SetBackdrop(CONTAINER_BACKDROP)
            col:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
            col:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
        end

        -- Header da Coluna
        local headerBar = CreateFrame("Frame", nil, col, template)
        headerBar:SetPoint("TOPLEFT", col, "TOPLEFT", 3, -3)
        headerBar:SetPoint("TOPRIGHT", col, "TOPRIGHT", -3, -3)
        headerBar:SetHeight(38)
        if headerBar.SetBackdrop then
            headerBar:SetBackdrop(SUB_CONTAINER_BACKDROP)
            headerBar:SetBackdropColor(0.12, 0.08, 0.03, 0.95)
            headerBar:SetBackdropBorderColor(0.60, 0.42, 0.15, 0.90)
        end

        local colIcon = headerBar:CreateTexture(nil, "ARTWORK")
        colIcon:SetSize(24, 24)
        colIcon:SetPoint("LEFT", headerBar, "LEFT", 6, 0)
        colIcon:SetTexture(def.icon)
        colIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local colTitle = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        colTitle:SetPoint("TOPLEFT", colIcon, "TOPRIGHT", 6, 0)
        colTitle:SetText(def.titleColor .. def.title .. "|r")

        local colSub = headerBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        colSub:SetPoint("BOTTOMLEFT", colIcon, "BOTTOMRIGHT", 6, 0)
        colSub:SetText("|cffaaaaaa" .. def.subtitle .. "|r")

        -- Botão "+ Criar" no header da coluna
        local createBtn = CreateFrame("Button", nil, headerBar, "UIPanelButtonTemplate")
        createBtn:SetSize(62, 22)
        createBtn:SetPoint("RIGHT", headerBar, "RIGHT", -6, 0)
        createBtn:SetText("+ Criar")
        createBtn:SetScript("OnClick", function()
            self:openCreateModal(def.type)
        end)

        -- ScrollFrame para os cards de grupos
        local scrollFrame = CreateFrame("ScrollFrame", "GM_GroupScroll_" .. def.type, col, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", col, "TOPLEFT", 4, -44)
        scrollFrame:SetPoint("BOTTOMRIGHT", col, "BOTTOMRIGHT", -22, 6)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(234)
        scrollChild:SetHeight(1)
        scrollFrame:SetScrollChild(scrollChild)

        col:EnableMouseWheel(true)
        col:SetScript("OnMouseWheel", function(_, delta)
            local current = scrollFrame:GetVerticalScroll()
            scrollFrame:SetVerticalScroll(math.max(0, current - (delta * 30)))
        end)

        local emptyText = col:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        emptyText:SetPoint("CENTER", col, "CENTER", 0, -10)
        emptyText:SetWidth(200)
        emptyText:SetJustifyH("CENTER")
        emptyText:SetText("Nenhum grupo criado.\nClique em |cffffff00+ Criar|r acima.")
        emptyText:Hide()

        self._columns[def.type] = {
            frame = col,
            scrollFrame = scrollFrame,
            scrollChild = scrollChild,
            emptyText = emptyText,
            def = def,
            cardPool = {},
        }
    end
end

--- Renderiza os grupos nas 3 colunas exibindo APENAS: Nome, Nota/Horário e Líder.
--- Ao clicar no grupo, abre a janela dedicada de gerenciamento de membros.
function GroupView:renderGroups()
    if not self._frame then return end

    local grouped = {
        [GroupType.DUNGEON] = {},
        [GroupType.RAID] = {},
        [GroupType.MISC] = {},
    }

    for _, g in ipairs(self._groups or {}) do
        local gType = g:getType()
        if grouped[gType] then
            table.insert(grouped[gType], g)
        else
            table.insert(grouped[GroupType.MISC], g)
        end
    end

    for gType, colData in pairs(self._columns) do
        local list = grouped[gType] or {}
        local child = colData.scrollChild

        for _, card in ipairs(colData.cardPool) do
            card:Hide()
        end

        if #list == 0 then
            colData.emptyText:Show()
            child:SetHeight(1)
        else
            colData.emptyText:Hide()
            local yOffset = 0

            for i, group in ipairs(list) do
                local card = self:getOrCreateCard(colData, i)
                self:setupCard(card, group)
                card:ClearAllPoints()
                card:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -yOffset)
                card:Show()

                yOffset = yOffset + card:GetHeight() + 8
            end

            child:SetHeight(math.max(1, yOffset))
        end
    end
end

--- Cria ou reaproveita um card compacto de grupo na coluna.
function GroupView:getOrCreateCard(colData, index)
    if colData.cardPool[index] then
        return colData.cardPool[index]
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local card = CreateFrame("Button", nil, colData.scrollChild, template)
    card:SetWidth(232)
    card:SetHeight(74) -- Altura fixa e compacta para exibir Nome, Nota e Líder

    if card.SetBackdrop then
        card:SetBackdrop(SUB_CONTAINER_BACKDROP)
        card:SetBackdropColor(0.045, 0.030, 0.015, 0.90)
        card:SetBackdropBorderColor(0.60, 0.40, 0.14, 0.90)
    end

    -- Highlight ao passar o mouse sobre o card
    local hl = card:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(card)
    hl:SetColorTexture(1.0, 0.82, 0.20, 0.15)
    card:SetHighlightTexture(hl)

    -- Linha 1: Nome do Grupo
    local title = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)
    title:SetPoint("RIGHT", card, "RIGHT", -55, 0)
    title:SetJustifyH("LEFT")
    card.title = title

    -- Contador de membros no canto superior direito
    local countText = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    countText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -8)
    card.countText = countText

    -- Linha 2: Nota / Horário
    local noteText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noteText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    noteText:SetPoint("RIGHT", card, "RIGHT", -8, 0)
    noteText:SetJustifyH("LEFT")
    card.noteText = noteText

    -- Linha 3: Líder do Grupo
    local crown = card:CreateTexture(nil, "ARTWORK")
    crown:SetSize(14, 14)
    crown:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 8, 8)
    crown:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    card.crown = crown

    local leaderText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leaderText:SetPoint("LEFT", crown, "RIGHT", 4, 0)
    leaderText:SetPoint("RIGHT", card, "RIGHT", -8, 0)
    leaderText:SetJustifyH("LEFT")
    card.leaderText = leaderText

    table.insert(colData.cardPool, card)
    return card
end

--- Configura o card com APENAS o Nome, a Nota/Horário e o Líder.
--- O clique abre a tela de gerenciamento de membros.
function GroupView:setupCard(card, group)
    local leaderName = group:getLeader() or ""
    local note = group:getNote() or ""
    local members = group:getMembers() or {}

    -- 1. Nome do Grupo
    card.title:SetText("|cffffd200" .. (group:getName() or "Grupo") .. "|r")

    -- Quantidade de membros (discreta)
    card.countText:SetText(string.format("|cff888888(%d memb)|r", #members))

    -- 2. Nota / Horário
    if note ~= "" then
        card.noteText:SetText("|cffaaaaaa" .. note .. "|r")
    else
        card.noteText:SetText("|cff555555(Sem nota/horário)|r")
    end

    -- 3. Líder do Grupo
    local leaderMember = self:findGuildMember(leaderName)
    local leaderClass = self:resolveMemberClass(leaderName, leaderMember and leaderMember:getClass())
    if leaderName ~= "" then
        card.leaderText:SetText("|cffffd200Líder:|r " .. getColoredMemberName(leaderName, leaderClass))
    else
        card.leaderText:SetText("|cffff4444Sem líder definido|r")
    end

    -- Ação de Clique: Abre a tela completa de gerenciamento do grupo!
    card:SetScript("OnClick", function()
        self:openGroupDetailModal(group)
    end)

    -- Tooltip indicando clique para gerenciar
    card:SetScript("OnEnter", function(f)
        if f.SetBackdropBorderColor then
            f:SetBackdropBorderColor(1.0, 0.85, 0.20, 1.0)
            f:SetBackdropColor(0.08, 0.05, 0.02, 0.95)
        end
        GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd200" .. group:getName() .. "|r")
        GameTooltip:AddLine("|cffaaaaaaLíder:|r " .. (leaderName ~= "" and leaderName or "Nenhum"))
        if note ~= "" then
            GameTooltip:AddLine("|cffaaaaaaNota/Horário:|r " .. note)
        end
        GameTooltip:AddLine(string.format("|cffaaaaaaTotal de Membros:|r %d", #members))
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ff00Clique para abrir e gerenciar este grupo|r", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)

    card:SetScript("OnLeave", function(f)
        if f.SetBackdropBorderColor then
            f:SetBackdropBorderColor(0.60, 0.40, 0.14, 0.90)
            f:SetBackdropColor(0.045, 0.030, 0.015, 0.90)
        end
        GameTooltip:Hide()
    end)
end

--- Cria todas as modais da View: Detalhes do Grupo, Novo Grupo, Adicionar Membro, Picker de Líder.
function GroupView:createModals()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    -- =========================================================================
    -- 1. MODAL DE GERENCIAMENTO / DETALHES DO GRUPO (Outra tela ao clicar)
    -- =========================================================================
    local detailModal = CreateFrame("Frame", "GM_GroupDetailModal", UIParent, template)
    detailModal:SetSize(620, 520)
    detailModal:SetFrameStrata("FULLSCREEN_DIALOG")
    detailModal:SetToplevel(true)
    detailModal:SetClampedToScreen(true)
    detailModal:EnableMouse(true)
    detailModal:SetMovable(true)
    detailModal:RegisterForDrag("LeftButton")
    detailModal:SetScript("OnDragStart", function(f) f:StartMoving() end)
    detailModal:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    detailModal:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    detailModal:Hide()

    if UISpecialFrames then
        table.insert(UISpecialFrames, "GM_GroupDetailModal")
    end

    if detailModal.SetBackdrop then
        detailModal:SetBackdrop(DIALOG_BACKDROP)
        detailModal:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], 0.98)
        detailModal:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], 1.0)
    end

    local dCloseBtn = CreateFrame("Button", nil, detailModal, "UIPanelCloseButton")
    dCloseBtn:SetPoint("TOPRIGHT", detailModal, "TOPRIGHT", -4, -4)
    dCloseBtn:SetSize(28, 28)
    dCloseBtn:SetScript("OnClick", function() detailModal:Hide() end)

    -- Cabeçalho da Modal
    local dIcon = detailModal:CreateTexture(nil, "ARTWORK")
    dIcon:SetSize(26, 26)
    dIcon:SetPoint("TOPLEFT", detailModal, "TOPLEFT", 16, -14)
    detailModal.icon = dIcon

    local dTitle = detailModal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dTitle:SetPoint("LEFT", dIcon, "RIGHT", 8, 0)
    dTitle:SetText("|cffffd200GERENCIAR GRUPO|r")
    detailModal.title = dTitle

    local dSub = detailModal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dSub:SetPoint("LEFT", dTitle, "RIGHT", 12, 0)
    dSub:SetText("")
    detailModal.subtitle = dSub

    local dSep = detailModal:CreateTexture(nil, "ARTWORK")
    dSep:SetPoint("TOPLEFT", detailModal, "TOPLEFT", 16, -46)
    dSep:SetPoint("RIGHT", detailModal, "RIGHT", -16, 0)
    dSep:SetHeight(1)
    dSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- --- SEÇÃO DE EDIÇÃO BÁSICA DO GRUPO ---
    -- Campo: Nome do Grupo
    local nameLbl = detailModal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLbl:SetPoint("TOPLEFT", dSep, "BOTTOMLEFT", 4, -10)
    nameLbl:SetText("|cffffd200Nome do Grupo:|r")

    local nameEB = CreateFrame("EditBox", nil, detailModal, template)
    nameEB:SetPoint("TOPLEFT", nameLbl, "BOTTOMLEFT", 0, -3)
    nameEB:SetSize(280, 22)
    styleBox(nameEB)
    detailModal.nameEB = nameEB

    -- Campo: Nota / Horário
    local noteLbl = detailModal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    noteLbl:SetPoint("LEFT", nameLbl, "LEFT", 295, 0)
    noteLbl:SetText("|cffffd200Nota / Horário:|r")

    local noteEB = CreateFrame("EditBox", nil, detailModal, template)
    noteEB:SetPoint("TOPLEFT", noteLbl, "BOTTOMLEFT", 0, -3)
    noteEB:SetSize(280, 22)
    styleBox(noteEB)
    detailModal.noteEB = noteEB

    -- Campo: Líder do Grupo
    local leaderLbl = detailModal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leaderLbl:SetPoint("TOPLEFT", nameEB, "BOTTOMLEFT", 0, -8)
    leaderLbl:SetText("|cffffd200Líder Atual do Grupo:|r")

    local leaderBox = CreateFrame("Frame", nil, detailModal, template)
    leaderBox:SetPoint("TOPLEFT", leaderLbl, "BOTTOMLEFT", 0, -3)
    leaderBox:SetSize(280, 24)
    if leaderBox.SetBackdrop then
        leaderBox:SetBackdrop(SUB_CONTAINER_BACKDROP)
        leaderBox:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.90)
        leaderBox:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.90)
    end

    local lCrown = leaderBox:CreateTexture(nil, "ARTWORK")
    lCrown:SetSize(14, 14)
    lCrown:SetPoint("LEFT", leaderBox, "LEFT", 6, 0)
    lCrown:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    detailModal.lCrown = lCrown

    local lClassIcon = leaderBox:CreateTexture(nil, "ARTWORK")
    lClassIcon:SetSize(16, 16)
    lClassIcon:SetPoint("LEFT", lCrown, "RIGHT", 4, 0)
    lClassIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    lClassIcon:Hide()
    detailModal.leaderClassIcon = lClassIcon

    local leaderVal = leaderBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    leaderVal:SetPoint("LEFT", lCrown, "RIGHT", 6, 0)
    leaderVal:SetPoint("RIGHT", leaderBox, "RIGHT", -6, 0)
    leaderVal:SetJustifyH("LEFT")
    detailModal.leaderVal = leaderVal
    detailModal.selectedLeaderName = ""

    local changeLeaderBtn = CreateFrame("Button", nil, detailModal, "UIPanelButtonTemplate")
    changeLeaderBtn:SetSize(110, 22)
    changeLeaderBtn:SetPoint("LEFT", leaderBox, "RIGHT", 8, 0)
    changeLeaderBtn:SetText("Trocar Líder...")
    changeLeaderBtn:SetScript("OnClick", function()
        self:openLeaderPicker(function(chosenMember)
            detailModal.selectedLeaderName = chosenMember:getName()
            local chClass = self:resolveMemberClass(chosenMember:getName(), chosenMember:getClass())
            leaderVal:SetText(getColoredMemberName(chosenMember:getName(), chClass))
            if detailModal.leaderClassIcon then
                local coords = chClass ~= "" and CLASS_ICON_COORDS[chClass]
                if coords then
                    detailModal.leaderClassIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
                    detailModal.leaderClassIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                    detailModal.leaderClassIcon:Show()
                    leaderVal:SetPoint("LEFT", detailModal.leaderClassIcon, "RIGHT", 4, 0)
                else
                    detailModal.leaderClassIcon:Hide()
                    leaderVal:SetPoint("LEFT", lCrown, "RIGHT", 6, 0)
                end
            end
        end)
    end)

    -- Botão "Salvar Dados"
    local saveInfoBtn = CreateFrame("Button", nil, detailModal, "UIPanelButtonTemplate")
    saveInfoBtn:SetSize(162, 22)
    saveInfoBtn:SetPoint("RIGHT", detailModal, "RIGHT", -20, 0)
    saveInfoBtn:SetPoint("CENTER", changeLeaderBtn, "CENTER", 140, 0)
    saveInfoBtn:SetText("Salvar Informações")
    saveInfoBtn:SetScript("OnClick", function()
        if not detailModal.currentGroup then return end
        local nVal = nameEB:GetText()
        local ntVal = noteEB:GetText()
        local lVal = detailModal.selectedLeaderName
        if self._onUpdateGroupDetailsCallback then
            self._onUpdateGroupDetailsCallback(detailModal.currentGroup:getId(), nVal, ntVal, lVal)
        end
    end)

    -- Divisória abaixo dos dados do grupo
    local dSep2 = detailModal:CreateTexture(nil, "ARTWORK")
    dSep2:SetPoint("TOPLEFT", leaderBox, "BOTTOMLEFT", 0, -10)
    dSep2:SetPoint("RIGHT", detailModal, "RIGHT", -16, 0)
    dSep2:SetHeight(1)
    dSep2:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- --- SEÇÃO DE MEMBROS DO GRUPO ---
    local membersHeader = detailModal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    membersHeader:SetPoint("TOPLEFT", dSep2, "BOTTOMLEFT", 4, -8)
    membersHeader:SetText("|cffffd200MEMBROS DO GRUPO|r")

    local membersSummary = detailModal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    membersSummary:SetPoint("LEFT", membersHeader, "RIGHT", 12, 0)
    detailModal.membersSummary = membersSummary

    local addMemberBtn = CreateFrame("Button", nil, detailModal, "UIPanelButtonTemplate")
    addMemberBtn:SetSize(140, 22)
    addMemberBtn:SetPoint("RIGHT", detailModal, "RIGHT", -18, 0)
    addMemberBtn:SetPoint("CENTER", membersHeader, "CENTER", 180, 0)
    addMemberBtn:SetText("+ Adicionar Membro")
    addMemberBtn:SetScript("OnClick", function()
        if detailModal.currentGroup then
            self:openAddMemberModal(detailModal.currentGroup)
        end
    end)

    -- Container e ScrollFrame da lista de membros
    local memberTable = CreateFrame("Frame", nil, detailModal, template)
    memberTable:SetPoint("TOPLEFT", membersHeader, "BOTTOMLEFT", 0, -6)
    memberTable:SetPoint("BOTTOMRIGHT", detailModal, "BOTTOMRIGHT", -16, 50)
    if memberTable.SetBackdrop then
        memberTable:SetBackdrop(CONTAINER_BACKDROP)
        memberTable:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], 0.90)
        memberTable:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], 0.90)
    end

    local memberScroll = CreateFrame("ScrollFrame", "GM_DetailMemberScroll", memberTable, "UIPanelScrollFrameTemplate")
    memberScroll:SetPoint("TOPLEFT", memberTable, "TOPLEFT", 4, -4)
    memberScroll:SetPoint("BOTTOMRIGHT", memberTable, "BOTTOMRIGHT", -22, 4)

    local memberChild = CreateFrame("Frame", nil, memberScroll)
    memberChild:SetWidth(555)
    memberChild:SetHeight(1)
    memberScroll:SetScrollChild(memberChild)
    detailModal.memberChild = memberChild
    detailModal.memberRows = {}

    -- Suporte a rolagem do mouse na tabela de membros
    memberTable:EnableMouseWheel(true)
    memberTable:SetScript("OnMouseWheel", function(_, delta)
        local cur = memberScroll:GetVerticalScroll()
        memberScroll:SetVerticalScroll(math.max(0, cur - (delta * 24)))
    end)

    -- --- SEÇÃO INFERIOR: AÇÕES DO GRUPO ---
    local inviteAllBtn = CreateFrame("Button", nil, detailModal, "UIPanelButtonTemplate")
    inviteAllBtn:SetSize(140, 24)
    inviteAllBtn:SetPoint("BOTTOMLEFT", detailModal, "BOTTOMLEFT", 16, 14)
    inviteAllBtn:SetText("Convidar Grupo")
    inviteAllBtn:SetScript("OnClick", function()
        if detailModal.currentGroup and self._onInviteGroupCallback then
            self._onInviteGroupCallback(detailModal.currentGroup:getId())
        end
    end)

    local delGroupBtn = CreateFrame("Button", nil, detailModal, "UIPanelButtonTemplate")
    delGroupBtn:SetSize(120, 24)
    delGroupBtn:SetPoint("LEFT", inviteAllBtn, "RIGHT", 10, 0)
    delGroupBtn:SetText("Excluir Grupo")
    delGroupBtn:SetScript("OnClick", function()
        if detailModal.currentGroup and self._onDeleteGroupCallback then
            local gId = detailModal.currentGroup:getId()
            local gName = detailModal.currentGroup:getName() or "este grupo"
            local confirm = true
            if _G.GM and _G.GM.settingsService and _G.GM.settingsService:get("confirmGroupDelete") == false then
                confirm = false
            end
            if confirm and StaticPopupDialogs then
                StaticPopupDialogs["GM_CONFIRM_DELETE_GROUP"] = {
                    text = string.format("Deseja realmente excluir o grupo '%s'?", gName),
                    button1 = "Sim",
                    button2 = "Não",
                    OnAccept = function()
                        self._onDeleteGroupCallback(gId)
                        detailModal:Hide()
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                }
                StaticPopup_Show("GM_CONFIRM_DELETE_GROUP")
            else
                self._onDeleteGroupCallback(gId)
                detailModal:Hide()
            end
        end
    end)

    local closeDetailBtn = CreateFrame("Button", nil, detailModal, "UIPanelButtonTemplate")
    closeDetailBtn:SetSize(100, 24)
    closeDetailBtn:SetPoint("BOTTOMRIGHT", detailModal, "BOTTOMRIGHT", -16, 14)
    closeDetailBtn:SetText("Fechar")
    closeDetailBtn:SetScript("OnClick", function() detailModal:Hide() end)

    self._detailModal = detailModal

    -- =========================================================================
    -- 2. MODAL DE NOVO GRUPO
    -- =========================================================================
    local createModal = CreateFrame("Frame", "GM_CreateGroupModal", UIParent, template)
    createModal:SetSize(430, 440)
    createModal:SetFrameStrata("FULLSCREEN_DIALOG")
    createModal:SetToplevel(true)
    createModal:SetClampedToScreen(true)
    createModal:EnableMouse(true)
    createModal:SetMovable(true)
    createModal:RegisterForDrag("LeftButton")
    createModal:SetScript("OnDragStart", function(f) f:StartMoving() end)
    createModal:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    createModal:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    createModal:Hide()

    if UISpecialFrames then
        table.insert(UISpecialFrames, "GM_CreateGroupModal")
    end

    if createModal.SetBackdrop then
        createModal:SetBackdrop(DIALOG_BACKDROP)
        createModal:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], 0.98)
        createModal:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], 1.0)
    end

    local cCloseBtn = CreateFrame("Button", nil, createModal, "UIPanelCloseButton")
    cCloseBtn:SetPoint("TOPRIGHT", createModal, "TOPRIGHT", -4, -4)
    cCloseBtn:SetSize(28, 28)
    cCloseBtn:SetScript("OnClick", function() createModal:Hide() end)

    local cTitle = createModal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cTitle:SetPoint("TOPLEFT", createModal, "TOPLEFT", 18, -16)
    cTitle:SetText("|cffffd200CRIAR NOVO GRUPO|r")

    local cSep = createModal:CreateTexture(nil, "ARTWORK")
    cSep:SetPoint("TOPLEFT", createModal, "TOPLEFT", 16, -44)
    cSep:SetPoint("RIGHT", createModal, "RIGHT", -16, 0)
    cSep:SetHeight(1)
    cSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- Nome
    local cNameLabel = createModal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cNameLabel:SetPoint("TOPLEFT", cSep, "BOTTOMLEFT", 4, -12)
    cNameLabel:SetText("|cffffd200Nome do Grupo:|r |cffff0000*|r")

    local cNameEB = CreateFrame("EditBox", nil, createModal, template)
    cNameEB:SetPoint("TOPLEFT", cNameLabel, "BOTTOMLEFT", 0, -4)
    cNameEB:SetSize(380, 24)
    styleBox(cNameEB)
    createModal.nameEB = cNameEB

    -- Tipo
    local cTypeLabel = createModal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cTypeLabel:SetPoint("TOPLEFT", cNameEB, "BOTTOMLEFT", 0, -12)
    cTypeLabel:SetText("|cffffd200Tipo de Grupo:|r")

    local typeButtons = {}
    local typeDefs = {
        { id = GroupType.DUNGEON, label = "Masmorras" },
        { id = GroupType.RAID, label = "Raides" },
        { id = GroupType.MISC, label = "Diversos" },
    }
    createModal.selectedType = GroupType.DUNGEON

    for i, tDef in ipairs(typeDefs) do
        local btn = CreateFrame("Button", nil, createModal, template)
        btn:SetSize(120, 24)
        btn:SetPoint("TOPLEFT", cTypeLabel, "BOTTOMLEFT", (i - 1) * 130, -4)
        if btn.SetBackdrop then btn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("CENTER", btn, "CENTER", 0, 0)
        txt:SetText(tDef.label)
        btn.txt = txt

        btn:SetScript("OnClick", function()
            createModal.selectedType = tDef.id
            self:updateCreateModalTypeButtons(typeButtons, tDef.id)
            self:updateCreateModalRoleVisibility()
        end)
        typeButtons[tDef.id] = btn
    end
    createModal.typeButtons = typeButtons

    -- Nota / Horário
    local cNoteLabel = createModal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cNoteLabel:SetPoint("TOPLEFT", cTypeLabel, "BOTTOMLEFT", 0, -38)
    cNoteLabel:SetText("|cffffd200Nota / Horário (Opcional):|r")

    local cNoteEB = CreateFrame("EditBox", nil, createModal, template)
    cNoteEB:SetPoint("TOPLEFT", cNoteLabel, "BOTTOMLEFT", 0, -4)
    cNoteEB:SetSize(380, 24)
    styleBox(cNoteEB)
    createModal.noteEB = cNoteEB

    -- Líder Obrigatório
    local cLeaderLabel = createModal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cLeaderLabel:SetPoint("TOPLEFT", cNoteEB, "BOTTOMLEFT", 0, -12)
    cLeaderLabel:SetText("|cffffd200Líder do Grupo (Membro da Guilda):|r |cffff0000*|r")

    local cLeaderBox = CreateFrame("Button", nil, createModal, template)
    cLeaderBox:SetPoint("TOPLEFT", cLeaderLabel, "BOTTOMLEFT", 0, -4)
    cLeaderBox:SetSize(270, 24)
    if cLeaderBox.SetBackdrop then
        cLeaderBox:SetBackdrop(SUB_CONTAINER_BACKDROP)
        cLeaderBox:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.90)
        cLeaderBox:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 1.0)
    end
    local cCrown = cLeaderBox:CreateTexture(nil, "ARTWORK")
    cCrown:SetSize(14, 14)
    cCrown:SetPoint("LEFT", cLeaderBox, "LEFT", 6, 0)
    cCrown:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")

    local cLeaderText = cLeaderBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cLeaderText:SetPoint("LEFT", cCrown, "RIGHT", 6, 0)
    cLeaderText:SetText("|cffaaaaaaClique para selecionar líder...|r")
    createModal.leaderText = cLeaderText
    createModal.selectedLeader = nil

    local cLeaderPickBtn = CreateFrame("Button", nil, createModal, "UIPanelButtonTemplate")
    cLeaderPickBtn:SetSize(104, 24)
    cLeaderPickBtn:SetPoint("LEFT", cLeaderBox, "RIGHT", 6, 0)
    cLeaderPickBtn:SetText("Selecionar...")
    cLeaderPickBtn:SetScript("OnClick", function()
        self:openLeaderPicker(function(chosenMember)
            createModal.selectedLeader = chosenMember
            local chClass = self:resolveMemberClass(chosenMember:getName(), chosenMember:getClass())
            cLeaderText:SetText(getColoredMemberName(chosenMember:getName(), chClass))
            if chClass ~= "" and (createModal.selectedType ~= GroupType.MISC) then
                self:autoSelectRoleForClass(createModal.roleButtons, chClass, function(r)
                    createModal.selectedLeaderRole = r
                end)
            end
        end)
    end)
    cLeaderBox:SetScript("OnClick", function() cLeaderPickBtn:Click() end)

    -- Função do Líder
    local cRoleContainer = CreateFrame("Frame", nil, createModal)
    cRoleContainer:SetPoint("TOPLEFT", cLeaderBox, "BOTTOMLEFT", 0, -10)
    cRoleContainer:SetSize(380, 50)
    createModal.roleContainer = cRoleContainer

    local cRoleLabel = cRoleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cRoleLabel:SetPoint("TOPLEFT", cRoleContainer, "TOPLEFT", 0, 0)
    cRoleLabel:SetText("|cffffd200Função do Líder no Grupo:|r |cffff0000*|r")

    local cRoleButtons = {}
    local roleDefs = {
        { id = GroupRole.TANK, label = "🛡️ Tank", color = { 0.29, 0.56, 0.88 } },
        { id = GroupRole.HEALER, label = "✨ Curador", color = { 0.18, 0.80, 0.44 } },
        { id = GroupRole.DPS, label = "⚔️ Dano", color = { 0.91, 0.30, 0.24 } },
    }
    createModal.selectedLeaderRole = GroupRole.DPS

    for i, rDef in ipairs(roleDefs) do
        local rBtn = CreateFrame("Button", nil, cRoleContainer, template)
        rBtn:SetSize(120, 24)
        rBtn:SetPoint("TOPLEFT", cRoleLabel, "BOTTOMLEFT", (i - 1) * 130, -4)
        if rBtn.SetBackdrop then rBtn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
        local rTxt = rBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rTxt:SetPoint("CENTER", rBtn, "CENTER", 0, 0)
        rTxt:SetText(rDef.label)
        rBtn.txt = rTxt
        rBtn.def = rDef

        rBtn:SetScript("OnClick", function()
            createModal.selectedLeaderRole = rDef.id
            self:updateRoleButtons(cRoleButtons, rDef.id)
        end)
        cRoleButtons[rDef.id] = rBtn
    end
    createModal.roleButtons = cRoleButtons

    local cErrorText = createModal:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    cErrorText:SetPoint("BOTTOMLEFT", createModal, "BOTTOMLEFT", 18, 48)
    cErrorText:SetPoint("BOTTOMRIGHT", createModal, "BOTTOMRIGHT", -18, 48)
    cErrorText:SetJustifyH("CENTER")
    cErrorText:SetText("")
    createModal.errorText = cErrorText

    local cSaveBtn = CreateFrame("Button", nil, createModal, "UIPanelButtonTemplate")
    cSaveBtn:SetSize(130, 24)
    cSaveBtn:SetPoint("BOTTOMRIGHT", createModal, "BOTTOMRIGHT", -16, 16)
    cSaveBtn:SetText("Criar Grupo")
    cSaveBtn:SetScript("OnClick", function()
        local nameVal = cNameEB:GetText()
        if not nameVal or nameVal:match("^%s*$") then
            cErrorText:SetText("Por favor, informe o nome do grupo.")
            return
        end
        if not createModal.selectedLeader then
            cErrorText:SetText("Selecione um membro da guilda para ser o líder.")
            return
        end
        local lRole = createModal.selectedLeaderRole
        if createModal.selectedType ~= GroupType.MISC then
            if not lRole or lRole == GroupRole.NONE then
                cErrorText:SetText("Defina a função do líder (Tank, Curador ou Dano).")
                return
            end
        else
            lRole = GroupRole.NONE
        end

        if self._onCreateGroupCallback then
            local ok, err = self._onCreateGroupCallback(
                nameVal,
                createModal.selectedType,
                createModal.selectedLeader:getName(),
                lRole,
                cNoteEB:GetText()
            )
            if ok then
                createModal:Hide()
            else
                cErrorText:SetText(err or "Falha ao criar grupo.")
            end
        end
    end)

    local cCancelBtn = CreateFrame("Button", nil, createModal, "UIPanelButtonTemplate")
    cCancelBtn:SetSize(100, 24)
    cCancelBtn:SetPoint("RIGHT", cSaveBtn, "LEFT", -8, 0)
    cCancelBtn:SetText("Cancelar")
    cCancelBtn:SetScript("OnClick", function() createModal:Hide() end)

    self._createModal = createModal

    -- =========================================================================
    -- 3. MODAL DE ADICIONAR MEMBRO
    -- =========================================================================
    local addModal = CreateFrame("Frame", "GM_AddMemberModal", UIParent, template)
    addModal:SetSize(400, 440)
    addModal:SetFrameStrata("FULLSCREEN_DIALOG")
    addModal:SetToplevel(true)
    addModal:SetClampedToScreen(true)
    addModal:EnableMouse(true)
    addModal:SetMovable(true)
    addModal:RegisterForDrag("LeftButton")
    addModal:SetScript("OnDragStart", function(f) f:StartMoving() end)
    addModal:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    addModal:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    addModal:Hide()

    if UISpecialFrames then
        table.insert(UISpecialFrames, "GM_AddMemberModal")
    end

    if addModal.SetBackdrop then
        addModal:SetBackdrop(DIALOG_BACKDROP)
        addModal:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], 0.98)
        addModal:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], 1.0)
    end

    local aCloseBtn = CreateFrame("Button", nil, addModal, "UIPanelCloseButton")
    aCloseBtn:SetPoint("TOPRIGHT", addModal, "TOPRIGHT", -4, -4)
    aCloseBtn:SetSize(28, 28)
    aCloseBtn:SetScript("OnClick", function() addModal:Hide() end)

    local aTitle = addModal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    aTitle:SetPoint("TOPLEFT", addModal, "TOPLEFT", 18, -16)
    aTitle:SetText("|cffffd200ADICIONAR MEMBRO AO GRUPO|r")

    local aSubtitle = addModal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    aSubtitle:SetPoint("TOPLEFT", aTitle, "BOTTOMLEFT", 0, -4)
    aSubtitle:SetText("")
    addModal.subtitle = aSubtitle

    local aSep = addModal:CreateTexture(nil, "ARTWORK")
    aSep:SetPoint("TOPLEFT", addModal, "TOPLEFT", 16, -60)
    aSep:SetPoint("RIGHT", addModal, "RIGHT", -16, 0)
    aSep:SetHeight(1)
    aSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    local aSearchEB = CreateFrame("EditBox", nil, addModal, template)
    aSearchEB:SetPoint("TOPLEFT", aSep, "BOTTOMLEFT", 0, -8)
    aSearchEB:SetSize(364, 22)
    styleBox(aSearchEB)

    local aSearchHint = aSearchEB:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    aSearchHint:SetPoint("LEFT", aSearchEB, "LEFT", 8, 0)
    aSearchHint:SetText("|cffaaaaaaBuscar membro na guilda...|r")

    aSearchEB:SetScript("OnTextChanged", function(box)
        local txt = box:GetText()
        if txt and txt ~= "" then aSearchHint:Hide() else aSearchHint:Show() end
        self:filterAddMemberList(txt)
    end)
    addModal.searchEB = aSearchEB

    local aListFrame = CreateFrame("Frame", nil, addModal, template)
    aListFrame:SetPoint("TOPLEFT", aSearchEB, "BOTTOMLEFT", 0, -6)
    aListFrame:SetSize(364, 180)
    if aListFrame.SetBackdrop then
        aListFrame:SetBackdrop(SUB_CONTAINER_BACKDROP)
        aListFrame:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.90)
        aListFrame:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.90)
    end

    local aScroll = CreateFrame("ScrollFrame", "GM_AddMemberScroll", aListFrame, "UIPanelScrollFrameTemplate")
    aScroll:SetPoint("TOPLEFT", aListFrame, "TOPLEFT", 2, -2)
    aScroll:SetPoint("BOTTOMRIGHT", aListFrame, "BOTTOMRIGHT", -20, 2)

    local aChild = CreateFrame("Frame", nil, aScroll)
    aChild:SetWidth(340)
    aChild:SetHeight(1)
    aScroll:SetScrollChild(aChild)
    addModal.memberChild = aChild
    addModal.memberRows = {}

    -- Seleção de Função
    local aRoleContainer = CreateFrame("Frame", nil, addModal)
    aRoleContainer:SetPoint("TOPLEFT", aListFrame, "BOTTOMLEFT", 0, -10)
    aRoleContainer:SetSize(364, 50)
    addModal.roleContainer = aRoleContainer

    local aRoleLabel = aRoleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    aRoleLabel:SetPoint("TOPLEFT", aRoleContainer, "TOPLEFT", 0, 0)
    aRoleLabel:SetText("|cffffd200Função do Membro no Grupo:|r |cffff0000*|r")

    local aRoleButtons = {}
    addModal.selectedRole = GroupRole.DPS

    for i, rDef in ipairs(roleDefs) do
        local rBtn = CreateFrame("Button", nil, aRoleContainer, template)
        rBtn:SetSize(115, 24)
        rBtn:SetPoint("TOPLEFT", aRoleLabel, "BOTTOMLEFT", (i - 1) * 124, -4)
        if rBtn.SetBackdrop then rBtn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
        local rTxt = rBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rTxt:SetPoint("CENTER", rBtn, "CENTER", 0, 0)
        rTxt:SetText(rDef.label)
        rBtn.txt = rTxt
        rBtn.def = rDef

        rBtn:SetScript("OnClick", function()
            addModal.selectedRole = rDef.id
            self:updateRoleButtons(aRoleButtons, rDef.id)
        end)
        aRoleButtons[rDef.id] = rBtn
    end
    addModal.roleButtons = aRoleButtons

    local aErrorText = addModal:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    aErrorText:SetPoint("BOTTOMLEFT", addModal, "BOTTOMLEFT", 18, 48)
    aErrorText:SetPoint("BOTTOMRIGHT", addModal, "BOTTOMRIGHT", -18, 48)
    aErrorText:SetJustifyH("CENTER")
    aErrorText:SetText("")
    addModal.errorText = aErrorText

    local aAddBtn = CreateFrame("Button", nil, addModal, "UIPanelButtonTemplate")
    aAddBtn:SetSize(140, 24)
    aAddBtn:SetPoint("BOTTOMRIGHT", addModal, "BOTTOMRIGHT", -16, 16)
    aAddBtn:SetText("Adicionar Membro")
    aAddBtn:SetScript("OnClick", function()
        if not addModal.selectedMember then
            aErrorText:SetText("Selecione um membro na lista acima.")
            return
        end
        local role = addModal.selectedRole
        if addModal.targetGroup and addModal.targetGroup:getType() ~= GroupType.MISC then
            if not role or role == GroupRole.NONE then
                aErrorText:SetText("Defina a função do membro (Tank, Curador ou Dano).")
                return
            end
        else
            role = GroupRole.NONE
        end

        if self._onAddMemberCallback and addModal.targetGroup then
            local ok, err = self._onAddMemberCallback(addModal.targetGroup:getId(), addModal.selectedMember:getName(), role)
            if ok then
                addModal:Hide()
            else
                aErrorText:SetText(err or "Falha ao adicionar membro.")
            end
        end
    end)

    local aCancelBtn = CreateFrame("Button", nil, addModal, "UIPanelButtonTemplate")
    aCancelBtn:SetSize(100, 24)
    aCancelBtn:SetPoint("RIGHT", aAddBtn, "LEFT", -8, 0)
    aCancelBtn:SetText("Cancelar")
    aCancelBtn:SetScript("OnClick", function() addModal:Hide() end)

    self._addMemberModal = addModal

    -- =========================================================================
    -- 4. SUB-PICKER DE LÍDER
    -- =========================================================================
    local leaderPicker = CreateFrame("Frame", "GM_LeaderPickerModal", UIParent, template)
    leaderPicker:SetSize(340, 360)
    leaderPicker:SetFrameStrata("TOOLTIP")
    leaderPicker:SetToplevel(true)
    leaderPicker:SetClampedToScreen(true)
    leaderPicker:EnableMouse(true)
    leaderPicker:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    leaderPicker:Hide()

    if leaderPicker.SetBackdrop then
        leaderPicker:SetBackdrop(DIALOG_BACKDROP)
        leaderPicker:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], 0.98)
        leaderPicker:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], 1.0)
    end

    local lpClose = CreateFrame("Button", nil, leaderPicker, "UIPanelCloseButton")
    lpClose:SetPoint("TOPRIGHT", leaderPicker, "TOPRIGHT", -4, -4)
    lpClose:SetSize(24, 24)
    lpClose:SetScript("OnClick", function() leaderPicker:Hide() end)

    local lpTitle = leaderPicker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lpTitle:SetPoint("TOPLEFT", leaderPicker, "TOPLEFT", 14, -14)
    lpTitle:SetText("|cffffd200ESCOLHER LÍDER DA GUILDA|r")

    local lpSearch = CreateFrame("EditBox", nil, leaderPicker, template)
    lpSearch:SetPoint("TOPLEFT", lpTitle, "BOTTOMLEFT", 0, -8)
    lpSearch:SetSize(310, 22)
    styleBox(lpSearch)
    leaderPicker.searchEB = lpSearch

    local lpSearchHint = lpSearch:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    lpSearchHint:SetPoint("LEFT", lpSearch, "LEFT", 8, 0)
    lpSearchHint:SetText("|cffaaaaaaBuscar membro...|r")

    lpSearch:SetScript("OnTextChanged", function(box)
        local txt = box:GetText()
        if txt and txt ~= "" then lpSearchHint:Hide() else lpSearchHint:Show() end
        self:filterLeaderPickerList(txt)
    end)

    local lpScroll = CreateFrame("ScrollFrame", "GM_LeaderPickerScroll", leaderPicker, "UIPanelScrollFrameTemplate")
    lpScroll:SetPoint("TOPLEFT", lpSearch, "BOTTOMLEFT", 0, -6)
    lpScroll:SetPoint("BOTTOMRIGHT", leaderPicker, "BOTTOMRIGHT", -22, 10)

    local lpChild = CreateFrame("Frame", nil, lpScroll)
    lpChild:SetWidth(290)
    lpChild:SetHeight(1)
    lpScroll:SetScrollChild(lpChild)
    leaderPicker.child = lpChild
    leaderPicker.rows = {}

    self._leaderPickerModal = leaderPicker
end

--- Abre a janela de detalhes / gerenciamento de membros do grupo.
---@param group Group
function GroupView:openGroupDetailModal(group)
    local m = self._detailModal
    if not m or not group then return end

    self._currentDetailGroupId = group:getId()
    m.currentGroup = group
    m.selectedLeaderName = group:getLeader() or ""

    -- Ícone da categoria
    local gType = group:getType()
    if gType == GroupType.DUNGEON then
        m.icon:SetTexture("Interface\\Icons\\INV_Shield_04")
        m.subtitle:SetText("|cff4a90e2Masmorras (5 Jogadores)|r")
    elseif gType == GroupType.RAID then
        m.icon:SetTexture("Interface\\Icons\\INV_Helmet_06")
        m.subtitle:SetText("|cffff8000Raides (10 / 25 / 40 Jogadores)|r")
    else
        m.icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
        m.subtitle:SetText("|cff00ff88Diversos (PvP / Farm / Eventos)|r")
    end

    -- Preenche campos editáveis
    m.nameEB:SetText(group:getName() or "")
    m.noteEB:SetText(group:getNote() or "")

    -- Líder
    local leaderMember = self:findGuildMember(group:getLeader())
    local lClass = self:resolveMemberClass(group:getLeader(), leaderMember and leaderMember:getClass())
    m.selectedLeaderName = group:getLeader() or ""
    m.leaderVal:SetText(getColoredMemberName(group:getLeader(), lClass))
    if m.leaderClassIcon then
        local lCoords = lClass ~= "" and CLASS_ICON_COORDS[lClass]
        if lCoords then
            m.leaderClassIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
            m.leaderClassIcon:SetTexCoord(lCoords[1], lCoords[2], lCoords[3], lCoords[4])
            m.leaderClassIcon:Show()
            m.leaderVal:SetPoint("LEFT", m.leaderClassIcon, "RIGHT", 4, 0)
        else
            m.leaderClassIcon:Hide()
            m.leaderVal:SetPoint("LEFT", m.lCrown or m.icon, "RIGHT", 6, 0)
        end
    end

    -- Renderiza membros
    self:renderDetailMembers(group)

    m:Show()
    if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN or 839) end
end

--- Recarrega a tela de detalhes caso ela esteja aberta.
function GroupView:refreshOpenDetailModal()
    if not self._detailModal or not self._detailModal:IsShown() or not self._currentDetailGroupId then
        return
    end

    for _, g in ipairs(self._groups or {}) do
        if g:getId() == self._currentDetailGroupId then
            self:openGroupDetailModal(g)
            break
        end
    end
end

--- Renderiza a lista de membros na janela de detalhes do grupo.
---@param group Group
function GroupView:renderDetailMembers(group)
    local m = self._detailModal
    if not m then return end

    local members = group:getMembers() or {}
    local gType = group:getType()
    local leaderName = group:getLeader() or ""
    local roleCounts = group:getRoleCounts()

    -- Resumo de funções
    if gType == GroupType.DUNGEON or gType == GroupType.RAID then
        m.membersSummary:SetText(string.format(
            "|cff4a90e2T: %d|r  |cff2ecc71C: %d|r  |cffe74c3cD: %d|r  |cffaaaaaa(Total: %d membros)|r",
            roleCounts.tank, roleCounts.healer, roleCounts.dps, #members
        ))
    else
        m.membersSummary:SetText(string.format("|cffaaaaaaTotal: %d membro(s)|r", #members))
    end

    local rowHeight = 26
    for i, member in ipairs(members) do
        local row = m.memberRows[i]
        if not row then
            row = CreateFrame("Frame", nil, m.memberChild)
            row:SetHeight(rowHeight)
            row:SetWidth(550)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(row)
            row.bg = bg

            -- Ícone de Líder
            local crown = row:CreateTexture(nil, "ARTWORK")
            crown:SetSize(16, 16)
            crown:SetPoint("LEFT", row, "LEFT", 4, 0)
            crown:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
            row.crown = crown

            -- Botão / Badge de Função
            local roleBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            roleBtn:SetSize(60, 20)
            roleBtn:SetPoint("LEFT", crown, "RIGHT", 6, 0)
            row.roleBtn = roleBtn

            -- Ícone da Classe
            local classIcon = row:CreateTexture(nil, "ARTWORK")
            classIcon:SetSize(18, 18)
            classIcon:SetPoint("LEFT", roleBtn, "RIGHT", 6, 0)
            classIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
            row.classIcon = classIcon

            -- Nome do Membro
            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameText:SetPoint("LEFT", classIcon, "RIGHT", 6, 0)
            nameText:SetPoint("RIGHT", row, "RIGHT", -125, 0)
            nameText:SetJustifyH("LEFT")
            row.nameText = nameText

            -- Botão "Tornar Líder"
            local makeLeaderBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            makeLeaderBtn:SetSize(90, 20)
            makeLeaderBtn:SetPoint("RIGHT", row, "RIGHT", -30, 0)
            makeLeaderBtn:SetText("Tornar Líder")
            row.makeLeaderBtn = makeLeaderBtn

            -- Botão "Remover" (×)
            local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            removeBtn:SetSize(22, 20)
            removeBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            removeBtn:SetText("×")
            row.removeBtn = removeBtn

            m.memberRows[i] = row
        else
            if not row.classIcon then
                local classIcon = row:CreateTexture(nil, "ARTWORK")
                classIcon:SetSize(18, 18)
                classIcon:SetPoint("LEFT", row.roleBtn, "RIGHT", 6, 0)
                classIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
                row.classIcon = classIcon
            end
            if row.lvlText then
                row.lvlText:Hide()
            end
            row.nameText:ClearAllPoints()
            row.nameText:SetPoint("LEFT", row.classIcon, "RIGHT", 6, 0)
            row.nameText:SetPoint("RIGHT", row, "RIGHT", -125, 0)
        end

        -- Cores alternadas das linhas
        if i % 2 == 0 then
            row.bg:SetColorTexture(0.06, 0.04, 0.02, 0.50)
        else
            row.bg:SetColorTexture(0.03, 0.02, 0.01, 0.35)
        end

        local isLeader = (member.name:lower() == leaderName:lower())
        if isLeader then
            row.crown:Show()
            row.makeLeaderBtn:Hide()
        else
            row.crown:Hide()
            row.makeLeaderBtn:Show()
            row.makeLeaderBtn:SetScript("OnClick", function()
                if self._onSetLeaderCallback then
                    self._onSetLeaderCallback(group:getId(), member.name)
                end
            end)
        end

        -- Função
        if gType ~= GroupType.MISC then
            row.roleBtn:SetText(getRoleFormatted(member.role))
            row.roleBtn:Show()
            row.roleBtn:SetScript("OnClick", function()
                local nextRole = GroupRole.DPS
                if member.role == GroupRole.TANK then
                    nextRole = GroupRole.HEALER
                elseif member.role == GroupRole.HEALER then
                    nextRole = GroupRole.DPS
                elseif member.role == GroupRole.DPS then
                    nextRole = GroupRole.TANK
                end
                if self._onSetRoleCallback then
                    self._onSetRoleCallback(group:getId(), member.name, nextRole)
                end
            end)
        else
            row.roleBtn:SetText("|cff888888Membro|r")
            row.roleBtn:SetScript("OnClick", nil)
        end

        -- Resolução e atualização dinâmica da classe do membro
        local resolvedClass = self:resolveMemberClass(member.name, member.class)
        if (not member.class or member.class == "") and resolvedClass ~= "" then
            member.class = resolvedClass
            if group.updateMemberClass then
                group:updateMemberClass(member.name, resolvedClass)
            end
        end

        -- Ícone da Classe
        local coords = resolvedClass ~= "" and CLASS_ICON_COORDS[resolvedClass]
        if coords and row.classIcon then
            row.classIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
            row.classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            row.classIcon:Show()
        elseif row.classIcon then
            row.classIcon:Hide()
        end

        -- Nome colorido com a cor da classe
        row.nameText:SetText(getColoredMemberName(member.name, resolvedClass))

        -- Nível removido (o usuário solicitou: "remova o nível")
        if row.lvlText then
            row.lvlText:Hide()
        end

        -- Botão Remover
        row.removeBtn:SetScript("OnClick", function()
            if self._onRemoveMemberCallback then
                self._onRemoveMemberCallback(group:getId(), member.name)
            end
        end)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", m.memberChild, "TOPLEFT", 0, -((i - 1) * rowHeight))
        row:Show()
    end

    for j = #members + 1, #m.memberRows do
        m.memberRows[j]:Hide()
    end

    m.memberChild:SetHeight(math.max(1, #members * rowHeight))
end

--- Atualiza a visualização dos botões de tipo na modal de criação.
function GroupView:updateCreateModalTypeButtons(typeButtons, activeType)
    for tId, btn in pairs(typeButtons) do
        local isActive = (tId == activeType)
        if btn.SetBackdropColor and btn.SetBackdropBorderColor then
            if isActive then
                btn:SetBackdropColor(PALETTE.ACTIVE_TAB_BG[1], PALETTE.ACTIVE_TAB_BG[2], PALETTE.ACTIVE_TAB_BG[3], 0.95)
                btn:SetBackdropBorderColor(PALETTE.ACTIVE_TAB_BORDER[1], PALETTE.ACTIVE_TAB_BORDER[2], PALETTE.ACTIVE_TAB_BORDER[3], 1.0)
                btn.txt:SetTextColor(1.0, 0.85, 0.20)
            else
                btn:SetBackdropColor(PALETTE.INACTIVE_TAB_BG[1], PALETTE.INACTIVE_TAB_BG[2], PALETTE.INACTIVE_TAB_BG[3], 0.80)
                btn:SetBackdropBorderColor(PALETTE.INACTIVE_TAB_BORDER[1], PALETTE.INACTIVE_TAB_BORDER[2], PALETTE.INACTIVE_TAB_BORDER[3], 0.85)
                btn.txt:SetTextColor(0.80, 0.80, 0.80)
            end
        end
    end
end

function GroupView:updateCreateModalRoleVisibility()
    local m = self._createModal
    if not m or not m.roleContainer then return end
    if m.selectedType == GroupType.MISC then
        m.roleContainer:Hide()
    else
        m.roleContainer:Show()
    end
end

function GroupView:updateRoleButtons(roleButtons, activeRole)
    for rId, btn in pairs(roleButtons) do
        local isActive = (rId == activeRole)
        if btn.SetBackdropColor and btn.SetBackdropBorderColor then
            if isActive then
                local c = btn.def.color or { 1.0, 0.82, 0.20 }
                btn:SetBackdropColor(c[1] * 0.35, c[2] * 0.35, c[3] * 0.35, 0.95)
                btn:SetBackdropBorderColor(c[1], c[2], c[3], 1.0)
                btn.txt:SetTextColor(c[1], c[2], c[3])
            else
                btn:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.80)
                btn:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.85)
                btn.txt:SetTextColor(0.70, 0.70, 0.70)
            end
        end
    end
end

function GroupView:autoSelectRoleForClass(roleButtons, classToken, setCallback)
    if _G.GM and _G.GM.settingsService and _G.GM.settingsService:get("autoAssignGroupRole") == false then
        return
    end
    local raw = (classToken or ""):upper()
    local upper = CLASS_NAME_TO_TOKEN[raw] or raw
    local chosen = GroupRole.DPS

    if upper == "PRIEST" then
        chosen = GroupRole.HEALER
    elseif upper == "WARRIOR" or upper == "DEATHKNIGHT" then
        chosen = GroupRole.TANK
    elseif upper == "PALADIN" or upper == "DRUID" or upper == "SHAMAN" then
        chosen = GroupRole.HEALER
    else
        chosen = GroupRole.DPS
    end

    if setCallback then setCallback(chosen) end
    self:updateRoleButtons(roleButtons, chosen)
end

function GroupView:openCreateModal(groupType)
    local m = self._createModal
    if not m then return end

    groupType = groupType or GroupType.DUNGEON
    m.selectedType = groupType
    m.selectedLeader = nil
    m.selectedLeaderRole = (groupType ~= GroupType.MISC) and GroupRole.DPS or GroupRole.NONE

    m.nameEB:SetText("")
    m.noteEB:SetText("")
    m.leaderText:SetText("|cffaaaaaaClique para selecionar líder...|r")
    m.errorText:SetText("")

    self:updateCreateModalTypeButtons(m.typeButtons, groupType)
    self:updateRoleButtons(m.roleButtons, m.selectedLeaderRole)
    self:updateCreateModalRoleVisibility()

    m:Show()
    m.nameEB:SetFocus()
end

function GroupView:openAddMemberModal(group)
    local m = self._addMemberModal
    if not m or not group then return end

    m.targetGroup = group
    m.selectedMember = nil
    m.selectedRole = (group:getType() ~= GroupType.MISC) and GroupRole.DPS or GroupRole.NONE
    m.subtitle:SetText(string.format("Grupo: |cffffff00%s|r", group:getName()))
    m.searchEB:SetText("")
    m.errorText:SetText("")

    if group:getType() == GroupType.MISC then
        m.roleContainer:Hide()
    else
        m.roleContainer:Show()
        self:updateRoleButtons(m.roleButtons, m.selectedRole)
    end

    self:filterAddMemberList("")
    m:Show()
    m.searchEB:SetFocus()
end

function GroupView:filterAddMemberList(filterText)
    local m = self._addMemberModal
    if not m or not m.targetGroup then return end

    local group = m.targetGroup
    local search = (filterText or ""):lower():match("^%s*(.-)%s*$")
    local candidates = {}

    for _, member in ipairs(self._guildMembers or {}) do
        local mName = member:getName()
        if not group:hasMember(mName) then
            if search == "" or (mName:lower():find(search, 1, true)) then
                table.insert(candidates, member)
            end
        end
    end

    table.sort(candidates, function(a, b)
        return (a:getName() or "") < (b:getName() or "")
    end)

    local rowHeight = 22
    for i, candidate in ipairs(candidates) do
        local row = m.memberRows[i]
        if not row then
            row = CreateFrame("Button", nil, m.memberChild)
            row:SetHeight(rowHeight)
            row:SetWidth(330)

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints(row)
            hl:SetColorTexture(1.0, 0.82, 0.0, 0.15)
            row:SetHighlightTexture(hl)

            local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            txt:SetPoint("LEFT", row, "LEFT", 6, 0)
            row.txt = txt

            local rnk = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            rnk:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            row.rnk = rnk

            m.memberRows[i] = row
        end

        local cClass = self:resolveMemberClass(candidate:getName(), candidate:getClass())
        local nameStr = getColoredMemberName(candidate:getName(), cClass)
        local lvl = candidate:getLevel() or 1
        row.txt:SetText(string.format("%s (Nv %d)", nameStr, lvl))
        row.rnk:SetText(candidate:getRankName() or "")

        row:SetScript("OnClick", function()
            m.selectedMember = candidate
            m.errorText:SetText("")
            for _, r in ipairs(m.memberRows) do
                if r.selBg then r.selBg:Hide() end
            end
            if not row.selBg then
                local sel = row:CreateTexture(nil, "BACKGROUND")
                sel:SetAllPoints(row)
                sel:SetColorTexture(0.2, 0.6, 1.0, 0.25)
                row.selBg = sel
            end
            row.selBg:Show()

            if group:getType() ~= GroupType.MISC and candidate:getClass() then
                self:autoSelectRoleForClass(m.roleButtons, candidate:getClass(), function(r)
                    m.selectedRole = r
                end)
            end
        end)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", m.memberChild, "TOPLEFT", 0, -((i - 1) * rowHeight))
        row:Show()
    end

    for j = #candidates + 1, #m.memberRows do
        m.memberRows[j]:Hide()
    end

    m.memberChild:SetHeight(math.max(1, #candidates * rowHeight))
end

function GroupView:openLeaderPicker(onChosen)
    local p = self._leaderPickerModal
    if not p then return end

    p.onChosen = onChosen
    p.searchEB:SetText("")
    self:filterLeaderPickerList("")
    p:Show()
    p.searchEB:SetFocus()
end

function GroupView:filterLeaderPickerList(filterText)
    local p = self._leaderPickerModal
    if not p then return end

    local search = (filterText or ""):lower():match("^%s*(.-)%s*$")
    local candidates = {}

    for _, member in ipairs(self._guildMembers or {}) do
        local mName = member:getName()
        if search == "" or (mName:lower():find(search, 1, true)) then
            table.insert(candidates, member)
        end
    end

    table.sort(candidates, function(a, b)
        return (a:getName() or "") < (b:getName() or "")
    end)

    local rowHeight = 22
    for i, candidate in ipairs(candidates) do
        local row = p.rows[i]
        if not row then
            row = CreateFrame("Button", nil, p.child)
            row:SetHeight(rowHeight)
            row:SetWidth(280)

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints(row)
            hl:SetColorTexture(1.0, 0.82, 0.0, 0.15)
            row:SetHighlightTexture(hl)

            local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            txt:SetPoint("LEFT", row, "LEFT", 6, 0)
            row.txt = txt

            p.rows[i] = row
        end

        local cClass = self:resolveMemberClass(candidate:getName(), candidate:getClass())
        local nameStr = getColoredMemberName(candidate:getName(), cClass)
        local lvl = candidate:getLevel() or 1
        row.txt:SetText(string.format("%s (Nv %d)", nameStr, lvl))

        row:SetScript("OnClick", function()
            if p.onChosen then
                p.onChosen(candidate)
            end
            p:Hide()
        end)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", p.child, "TOPLEFT", 0, -((i - 1) * rowHeight))
        row:Show()
    end

    for j = #candidates + 1, #p.rows do
        p.rows[j]:Hide()
    end

    p.child:SetHeight(math.max(1, #candidates * rowHeight))
end

function GroupView:setGroups(groups)
    self._groups = groups or {}
    self:renderGroups()
end

function GroupView:setGuildMembers(members)
    self._guildMembers = members or {}
end

function GroupView:show()
    if not self._frame then self:createUI() end
    self._frame:Show()
end

function GroupView:hide()
    if self._frame then self._frame:Hide() end
end

function GroupView:toggle()
    if self:isShown() then self:hide() else self:show() end
end

function GroupView:getFrame() return self._frame end
function GroupView:isShown() return self._frame and self._frame:IsShown() or false end

_G.GroupView = GroupView
