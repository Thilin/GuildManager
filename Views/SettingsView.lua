---@class SettingsView
---@field private _frame table|nil
SettingsView = {}
SettingsView.__index = SettingsView

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
    HIGHLIGHT_TINT = { 0.71, 0.49, 0.16, 0.20 },
    ACTIVE_TAB_BG = { 0.20, 0.13, 0.05, 0.95 },
    ACTIVE_TAB_BORDER = { 0.95, 0.70, 0.25, 1.0 },
    INACTIVE_TAB_BG = { 0.045, 0.030, 0.012, 0.80 },
    INACTIVE_TAB_BORDER = { 0.50, 0.33, 0.12, 0.85 },
}

local SOUND_OPTIONS = {
    { id = "whisper", key = "SOUND_WHISPER", soundId = 3081 },
    { id = "raid",    key = "SOUND_RAID",    soundId = 8959 },
    { id = "ready",   key = "SOUND_READY",   soundId = 8960 },
    { id = "coin",    key = "SOUND_COIN",    soundId = 120 },
}

local LOOKAHEAD_OPTIONS = {
    { days = 7 },
    { days = 14 },
    { days = 30 },
    { days = 60 },
}

--- Construtor da View de Configurações.
---@return SettingsView
function SettingsView:new()
    local instance = setmetatable({}, self)

    instance._frame = nil
    instance._widgets = {}
    instance._onSaveCallback = nil
    instance._onResetCallback = nil
    instance._onPurgeLogsCallback = nil
    instance._onForceScanCallback = nil
    instance._onForceSyncCallback = nil

    instance:createUI()

    return instance
end

function SettingsView:setOnSaveCallback(cb) self._onSaveCallback = cb end
function SettingsView:setOnResetCallback(cb) self._onResetCallback = cb end
function SettingsView:setOnPurgeLogsCallback(cb) self._onPurgeLogsCallback = cb end
function SettingsView:setOnForceScanCallback(cb) self._onForceScanCallback = cb end
function SettingsView:setOnForceSyncCallback(cb) self._onForceSyncCallback = cb end

--- Helper para estilizar caixas EditBox.
local function styleBox(eb)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetAutoFocus(false)
    eb:SetTextInsets(6, 6, 2, 2)
    if eb.SetBackdrop then
        eb:SetBackdrop(SUB_CONTAINER_BACKDROP)
        eb:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.90)
        eb:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.90)
    end
    eb:SetScript("OnEditFocusGained", function(box)
        if box.SetBackdropBorderColor then
            box:SetBackdropBorderColor(1.0, 0.85, 0.20, 1.0)
            box:SetBackdropColor(0.08, 0.05, 0.02, 0.95)
        end
    end)
    eb:SetScript("OnEditFocusLost", function(box)
        if box.SetBackdropBorderColor then
            box:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.90)
            box:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.90)
        end
    end)
    eb:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
end

--- Helper para criar checkboxes no padrão Blizzard reativos à localização.
local function createCheckbox(parent, labelText, tooltipTitle, tooltipDesc)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    local txt = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    txt:SetText(labelText)
    cb.label = txt
    cb.tooltipTitle = tooltipTitle
    cb.tooltipDesc = tooltipDesc

    cb:SetScript("OnEnter", function(f)
        if f.tooltipTitle then
            GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|cffffd200" .. f.tooltipTitle .. "|r")
            if f.tooltipDesc then
                GameTooltip:AddLine(f.tooltipDesc, 1, 1, 1, true)
            end
            GameTooltip:Show()
        end
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)

    cb:SetScript("OnClick", function()
        if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) end
    end)

    function cb:updateTexts(newLabel, newTitle, newDesc)
        if newLabel and self.label then self.label:SetText(newLabel) end
        if newTitle ~= nil then self.tooltipTitle = newTitle end
        if newDesc ~= nil then self.tooltipDesc = newDesc end
    end

    return cb
end

--- Cria a interface gráfica principal da tela de configurações.
function SettingsView:createUI()
    if self._frame then return end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "GM_SettingsFrame", UIParent, template)
    frame:SetSize(946, 594)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    frame:Hide()

    if UISpecialFrames then
        table.insert(UISpecialFrames, "GM_SettingsFrame")
    end

    if frame.SetBackdrop then
        frame:SetBackdrop(DIALOG_BACKDROP)
        frame:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], 0.98)
        frame:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], 1.0)
    end

    -- Botão Fechar (Topo Direito)
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetSize(28, 28)
    closeBtn:SetScript("OnClick", function() self:hide() end)

    -- Cabeçalho
    local gearIcon = frame:CreateTexture(nil, "ARTWORK")
    gearIcon:SetSize(26, 26)
    gearIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
    gearIcon:SetTexture("Interface\\Icons\\Trade_Engineering")
    gearIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", gearIcon, "RIGHT", 8, 0)
    title:SetText(L["SETTINGS_TITLE"])
    self._title = title

    local subTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subTitle:SetPoint("LEFT", title, "RIGHT", 12, 0)
    subTitle:SetText(L["SETTINGS_SUBTITLE"])
    self._subTitle = subTitle

    local sep = frame:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -44)
    sep:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    sep:SetHeight(1)
    sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    self._frame = frame

    self:createSideTabs()
    self:createTopSummaryBox()
    self:createSettingsColumns()
    self:createFooter()
end

--- Cria as abas laterais (Auditoria, Logs, Grupos, Agenda, Configurações).
function SettingsView:createSideTabs()
    local frame = self._frame
    if not frame then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    -- Aba 1: Auditoria
    local tabAudit = CreateFrame("Button", "GM_SettingsSideTab_Audit", frame, template)
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

    tabAudit:SetScript("OnEnter", function(btn)
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.95, 0.70, 0.25, 1.0)
            btn:SetBackdropColor(0.08, 0.05, 0.02, 0.95)
        end
        auditIcon:SetVertexColor(1.0, 1.0, 1.0)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd200" .. curL["TAB_AUDIT_TOOLTIP"] .. "|r")
        GameTooltip:AddLine(curL["TAB_AUDIT_TOOLTIP_DESC"], 1, 1, 1, true)
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
            local aFrame = (_G.GM and _G.GM.auditView and _G.GM.auditView.getFrame and _G.GM.auditView:getFrame()) or (auditCtrl._auditView and auditCtrl._auditView:getFrame())
            if aFrame and point then
                aFrame:ClearAllPoints()
                if relativeTo then aFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs) else aFrame:SetPoint(point, xOfs, yOfs) end
            end
        end
    end)

    -- Aba 2: Logs
    local tabLogs = CreateFrame("Button", "GM_SettingsSideTab_Logs", frame, template)
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

    tabLogs:SetScript("OnEnter", function(btn)
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.95, 0.70, 0.25, 1.0)
            btn:SetBackdropColor(0.08, 0.05, 0.02, 0.95)
        end
        logsIcon:SetVertexColor(1.0, 1.0, 1.0)
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
        if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841) end
        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
        self:hide()
        local logCtrl = (_G.GM and _G.GM.logController) or _G.logController
        if logCtrl then
            logCtrl:show()
            local lFrame = (_G.GM and _G.GM.logView and _G.GM.logView.getFrame and _G.GM.logView:getFrame()) or (logCtrl._logView and logCtrl._logView:getFrame())
            if lFrame and point then
                lFrame:ClearAllPoints()
                if relativeTo then lFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs) else lFrame:SetPoint(point, xOfs, yOfs) end
            end
        end
    end)

    -- Aba 3: Grupos
    local tabGroups = CreateFrame("Button", "GM_SettingsSideTab_Groups", frame, template)
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

    tabGroups:SetScript("OnEnter", function(btn)
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.95, 0.70, 0.25, 1.0)
            btn:SetBackdropColor(0.08, 0.05, 0.02, 0.95)
        end
        groupsIcon:SetVertexColor(1.0, 1.0, 1.0)
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
        if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841) end
        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
        self:hide()
        local groupCtrl = (_G.GM and _G.GM.groupController) or _G.groupController
        if groupCtrl then
            groupCtrl:show()
            local gFrame = (_G.GM and _G.GM.groupView and _G.GM.groupView.getFrame and _G.GM.groupView:getFrame()) or (groupCtrl._groupView and groupCtrl._groupView:getFrame())
            if gFrame and point then
                gFrame:ClearAllPoints()
                if relativeTo then gFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs) else gFrame:SetPoint(point, xOfs, yOfs) end
            end
        end
    end)

    -- Aba 4: Agenda
    local tabAgenda = CreateFrame("Button", "GM_SettingsSideTab_Agenda", frame, template)
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
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.95, 0.70, 0.25, 1.0)
            btn:SetBackdropColor(0.08, 0.05, 0.02, 0.95)
        end
        agendaIcon:SetVertexColor(1.0, 1.0, 1.0)
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

    -- Aba 5: Configurações (Ativa!)
    local tabSettings = CreateFrame("Button", "GM_SettingsSideTab_Settings", frame, template)
    tabSettings:SetSize(36, 36)
    tabSettings:SetPoint("TOPLEFT", tabAgenda, "BOTTOMLEFT", 0, -8)
    if tabSettings.SetBackdrop then
        tabSettings:SetBackdrop(SIDE_TAB_BACKDROP)
        tabSettings:SetBackdropColor(PALETTE.ACTIVE_TAB_BG[1], PALETTE.ACTIVE_TAB_BG[2], PALETTE.ACTIVE_TAB_BG[3], 0.95)
        tabSettings:SetBackdropBorderColor(PALETTE.ACTIVE_TAB_BORDER[1], PALETTE.ACTIVE_TAB_BORDER[2], PALETTE.ACTIVE_TAB_BORDER[3], 1.0)
    end
    local sIcon = tabSettings:CreateTexture(nil, "ARTWORK")
    sIcon:SetPoint("TOPLEFT", tabSettings, "TOPLEFT", 4, -4)
    sIcon:SetPoint("BOTTOMRIGHT", tabSettings, "BOTTOMRIGHT", -4, 4)
    sIcon:SetTexture("Interface\\Icons\\Trade_Engineering")
    sIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    sIcon:SetVertexColor(1.0, 1.0, 1.0)

    local sGlow = tabSettings:CreateTexture(nil, "OVERLAY")
    sGlow:SetPoint("TOPLEFT", tabSettings, "TOPLEFT", -2, 2)
    sGlow:SetPoint("BOTTOMRIGHT", tabSettings, "BOTTOMRIGHT", 2, -2)
    sGlow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    sGlow:SetBlendMode("ADD")
    sGlow:SetVertexColor(1.0, 0.85, 0.20, 0.80)

    tabSettings:SetScript("OnEnter", function(btn)
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd200" .. curL["TAB_SETTINGS_TOOLTIP"] .. "|r")
        GameTooltip:AddLine("|cff888888" .. curL["CURRENT_TAB"] .. "|r", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(curL["TAB_SETTINGS_TOOLTIP_DESC"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    tabSettings:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

--- Cria o cabeçalho de resumo e customização da guilda no topo da tela.
function SettingsView:createTopSummaryBox()
    local frame = self._frame
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    local topBox = CreateFrame("Frame", nil, frame, template)
    topBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -50)
    topBox:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    topBox:SetHeight(46)
    if topBox.SetBackdrop then
        topBox:SetBackdrop(CONTAINER_BACKDROP)
        topBox:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], 0.90)
        topBox:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], 0.90)
    end

    -- Brasão / Ícone da Guilda
    local crest = topBox:CreateTexture(nil, "ARTWORK")
    crest:SetSize(28, 28)
    crest:SetPoint("LEFT", topBox, "LEFT", 10, 0)
    crest:SetTexture("Interface\\Icons\\INV_BannerPVP_02")
    crest:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local gNameText = topBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gNameText:SetPoint("TOPLEFT", crest, "TOPRIGHT", 8, 2)
    gNameText:SetText("|cffffd200<Guilda>|r")
    self._widgets.gNameText = gNameText

    local gStatsText = topBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    gStatsText:SetPoint("BOTTOMLEFT", crest, "BOTTOMRIGHT", 8, -2)
    gStatsText:SetText("|cffaaaaaaMembros: 0  •  Grupos: 0  •  Logs: 0|r")
    self._widgets.gStatsText = gStatsText

    -- Campo de Lema / Subtítulo customizado da guilda
    local tagLabel = topBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tagLabel:SetPoint("RIGHT", topBox, "RIGHT", -335, 0)
    tagLabel:SetText(L["SETTINGS_TAGLINE_LABEL"])
    self._widgets.tagLabel = tagLabel

    local tagEB = CreateFrame("EditBox", nil, topBox, template)
    tagEB:SetPoint("LEFT", tagLabel, "RIGHT", 8, 0)
    tagEB:SetSize(315, 22)
    styleBox(tagEB)
    self._widgets.guildTagline = tagEB

    self._topBox = topBox
end

--- Seleciona e troca o idioma da interface em tempo real
---@param lang string @"enUS" ou "ptBR"
function SettingsView:selectLanguage(lang)
    if lang ~= "enUS" and lang ~= "ptBR" then lang = "enUS" end
    self._widgets.selectedLanguage = lang
    self:updateLanguageButtonsVisual(self._widgets.langButtons, lang)

    if _G.GM and _G.GM.SetLocale then
        _G.GM.SetLocale(lang)
    end

    self:updateLocale()

    local curL = (_G.GM and _G.GM.L) or _G.L or L
    local msg = (lang == "ptBR") and curL["SETTINGS_LANG_CHANGED_PT"] or curL["SETTINGS_LANG_CHANGED_EN"]
    self:showStatus(msg, false)
end

--- Atualiza visual dos botões de seleção de idioma
function SettingsView:updateLanguageButtonsVisual(buttons, activeLang)
    if not buttons then return end
    for lang, btn in pairs(buttons) do
        local isActive = (lang == activeLang)
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

--- Cria as duas colunas estruturadas de configurações.
function SettingsView:createSettingsColumns()
    local frame = self._frame
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    local colWidth = 451
    local colHeight = 440

    -- =========================================================================
    -- COLUNA ESQUERDA: Interface, Idioma, Chat & Minimapa
    -- =========================================================================
    local leftCol = CreateFrame("Frame", nil, frame, template)
    leftCol:SetPoint("TOPLEFT", self._topBox, "BOTTOMLEFT", 0, -6)
    leftCol:SetSize(colWidth, colHeight)
    if leftCol.SetBackdrop then
        leftCol:SetBackdrop(CONTAINER_BACKDROP)
        leftCol:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], 0.90)
        leftCol:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], 0.90)
    end

    local lScroll = CreateFrame("ScrollFrame", "GM_SettingsScrollLeft", leftCol, "UIPanelScrollFrameTemplate")
    lScroll:SetPoint("TOPLEFT", leftCol, "TOPLEFT", 6, -6)
    lScroll:SetPoint("BOTTOMRIGHT", leftCol, "BOTTOMRIGHT", -22, 6)

    local lChild = CreateFrame("Frame", nil, lScroll)
    lChild:SetWidth(colWidth - 30)
    lChild:SetHeight(520)
    lScroll:SetScrollChild(lChild)

    -- --- SEÇÃO 1: APRESENTAÇÃO, IDIOMA & INTERFACE ---
    local s1Header = lChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s1Header:SetPoint("TOPLEFT", lChild, "TOPLEFT", 4, -4)
    s1Header:SetText(L["SETTINGS_S1_HEADER"])
    self._widgets.s1Header = s1Header

    local s1Sep = lChild:CreateTexture(nil, "ARTWORK")
    s1Sep:SetPoint("TOPLEFT", s1Header, "BOTTOMLEFT", 0, -3)
    s1Sep:SetPoint("RIGHT", lChild, "RIGHT", -4, 0)
    s1Sep:SetHeight(1)
    s1Sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    -- Seletor de Idioma
    local langLabel = lChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    langLabel:SetPoint("TOPLEFT", s1Sep, "BOTTOMLEFT", 2, -6)
    langLabel:SetText(L["SETTINGS_LANG_LABEL"])
    self._widgets.langLabel = langLabel

    local langEnBtn = CreateFrame("Button", nil, lChild, template)
    langEnBtn:SetSize(115, 22)
    langEnBtn:SetPoint("TOPLEFT", langLabel, "BOTTOMLEFT", 0, -4)
    if langEnBtn.SetBackdrop then langEnBtn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
    local enTxt = langEnBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    enTxt:SetPoint("CENTER", langEnBtn, "CENTER", 0, 0)
    enTxt:SetText("English (US)")
    langEnBtn.txt = enTxt
    langEnBtn:SetScript("OnClick", function()
        self:selectLanguage("enUS")
    end)

    local langPtBtn = CreateFrame("Button", nil, lChild, template)
    langPtBtn:SetSize(115, 22)
    langPtBtn:SetPoint("LEFT", langEnBtn, "RIGHT", 10, 0)
    if langPtBtn.SetBackdrop then langPtBtn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
    local ptTxt = langPtBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ptTxt:SetPoint("CENTER", langPtBtn, "CENTER", 0, 0)
    ptTxt:SetText("Português (BR)")
    langPtBtn.txt = ptTxt
    langPtBtn:SetScript("OnClick", function()
        self:selectLanguage("ptBR")
    end)

    self._widgets.langButtons = {
        enUS = langEnBtn,
        ptBR = langPtBtn,
    }

    local tabDefLabel = lChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tabDefLabel:SetPoint("TOPLEFT", langEnBtn, "BOTTOMLEFT", 0, -8)
    tabDefLabel:SetText(L["SETTINGS_DEFAULT_TAB_LABEL"])
    self._widgets.tabDefLabel = tabDefLabel

    local tabDefs = {
        { id = "audit",    key = "TAB_AUDIT" },
        { id = "logs",     key = "TAB_LOGS" },
        { id = "groups",   key = "TAB_GROUPS" },
        { id = "agenda",   key = "TAB_AGENDA" },
        { id = "settings", key = "TAB_SETTINGS" },
    }
    local tabButtons = {}
    for i, tDef in ipairs(tabDefs) do
        local btn = CreateFrame("Button", nil, lChild, template)
        btn:SetSize(62, 20)
        btn:SetPoint("TOPLEFT", tabDefLabel, "BOTTOMLEFT", (i - 1) * 65, -4)
        if btn.SetBackdrop then btn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("CENTER", btn, "CENTER", 0, 0)
        txt:SetText(L[tDef.key] or tDef.id)
        btn.txt = txt
        btn.key = tDef.key
        btn:SetScript("OnClick", function()
            self._widgets.selectedDefaultTab = tDef.id
            self:updateTabSelectionButtons(tabButtons, tDef.id)
        end)
        tabButtons[tDef.id] = btn
    end
    self._widgets.tabButtons = tabButtons

    local cbTime24 = createCheckbox(lChild, L["SETTINGS_TIME_24H"], L["SETTINGS_TIME_24H_TIP_TITLE"], L["SETTINGS_TIME_24H_TIP_DESC"])
    cbTime24:SetPoint("TOPLEFT", tabDefLabel, "BOTTOMLEFT", 0, -32)
    self._widgets.timeFormat24 = cbTime24

    -- --- SEÇÃO 2: CHAT & MENÇÕES (@) ---
    local s2Header = lChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s2Header:SetPoint("TOPLEFT", cbTime24, "BOTTOMLEFT", 2, -12)
    s2Header:SetText(L["SETTINGS_S2_HEADER"])
    self._widgets.s2Header = s2Header

    local s2Sep = lChild:CreateTexture(nil, "ARTWORK")
    s2Sep:SetPoint("TOPLEFT", s2Header, "BOTTOMLEFT", 0, -3)
    s2Sep:SetPoint("RIGHT", lChild, "RIGHT", -4, 0)
    s2Sep:SetHeight(1)
    s2Sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    local cbChatMentions = createCheckbox(lChild, L["SETTINGS_CHAT_MENTIONS"], L["SETTINGS_CHAT_MENTIONS_TIP_TITLE"], L["SETTINGS_CHAT_MENTIONS_TIP_DESC"])
    cbChatMentions:SetPoint("TOPLEFT", s2Sep, "BOTTOMLEFT", 0, -4)
    self._widgets.enableChatMentions = cbChatMentions

    local cbMentionSound = createCheckbox(lChild, L["SETTINGS_MENTION_SOUND"], L["SETTINGS_MENTION_SOUND_TIP_TITLE"], L["SETTINGS_MENTION_SOUND_TIP_DESC"])
    cbMentionSound:SetPoint("TOPLEFT", cbChatMentions, "BOTTOMLEFT", 0, -2)
    self._widgets.enableMentionSound = cbMentionSound

    local cbMentionFlash = createCheckbox(lChild, L["SETTINGS_MENTION_FLASH"], L["SETTINGS_MENTION_FLASH_TIP_TITLE"], L["SETTINGS_MENTION_FLASH_TIP_DESC"])
    cbMentionFlash:SetPoint("TOPLEFT", cbMentionSound, "BOTTOMLEFT", 0, -2)
    self._widgets.enableMentionFlash = cbMentionFlash

    local soundLabel = lChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    soundLabel:SetPoint("TOPLEFT", cbMentionFlash, "BOTTOMLEFT", 4, -6)
    soundLabel:SetText(L["SETTINGS_SOUND_CHOICE_LABEL"])
    self._widgets.soundLabel = soundLabel

    local soundButtons = {}
    for i, sDef in ipairs(SOUND_OPTIONS) do
        local btn = CreateFrame("Button", nil, lChild, template)
        btn:SetSize(66, 18)
        btn:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", (i - 1) * 70, -3)
        if btn.SetBackdrop then btn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("CENTER", btn, "CENTER", 0, 0)
        txt:SetText(L[sDef.key] or sDef.id)
        btn.txt = txt
        btn.key = sDef.key
        btn:SetScript("OnClick", function()
            self._widgets.selectedMentionSound = sDef.id
            self:updateSoundButtons(soundButtons, sDef.id)
            if PlaySound then pcall(PlaySound, sDef.soundId, "Master") end
        end)
        soundButtons[sDef.id] = btn
    end
    self._widgets.soundButtons = soundButtons

    local testSoundBtn = CreateFrame("Button", nil, lChild, "UIPanelButtonTemplate")
    testSoundBtn:SetSize(64, 18)
    testSoundBtn:SetPoint("LEFT", soundButtons["coin"], "RIGHT", 6, 0)
    testSoundBtn:SetText(L["TEST"])
    testSoundBtn:SetScript("OnClick", function()
        local cur = self._widgets.selectedMentionSound or "whisper"
        for _, s in ipairs(SOUND_OPTIONS) do
            if s.id == cur then
                if PlaySound then pcall(PlaySound, s.soundId, "Master") end
                break
            end
        end
    end)
    self._widgets.testSoundBtn = testSoundBtn

    -- --- SEÇÃO 3: BOTÃO DO MINIMAPA ---
    local s3Header = lChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s3Header:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", 0, -30)
    s3Header:SetText(L["SETTINGS_S3_HEADER"])
    self._widgets.s3Header = s3Header

    local s3Sep = lChild:CreateTexture(nil, "ARTWORK")
    s3Sep:SetPoint("TOPLEFT", s3Header, "BOTTOMLEFT", 0, -3)
    s3Sep:SetPoint("RIGHT", lChild, "RIGHT", -4, 0)
    s3Sep:SetHeight(1)
    s3Sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    local cbMinimap = createCheckbox(lChild, L["SETTINGS_MINIMAP_BTN"], L["SETTINGS_MINIMAP_BTN_TIP_TITLE"], L["SETTINGS_MINIMAP_BTN_TIP_DESC"])
    cbMinimap:SetPoint("TOPLEFT", s3Sep, "BOTTOMLEFT", 0, -4)
    self._widgets.showMinimapButton = cbMinimap

    local sliderLabel = lChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sliderLabel:SetPoint("TOPLEFT", cbMinimap, "BOTTOMLEFT", 4, -6)
    sliderLabel:SetText(string.format(L["SETTINGS_MINIMAP_POS_LABEL"], 215))
    self._widgets.sliderLabel = sliderLabel

    local posSlider = CreateFrame("Slider", "GM_MinimapPosSlider", lChild, "OptionsSliderTemplate")
    posSlider:SetPoint("TOPLEFT", sliderLabel, "BOTTOMLEFT", 4, -4)
    posSlider:SetWidth(240)
    posSlider:SetHeight(16)
    posSlider:SetMinMaxValues(0, 360)
    posSlider:SetValueStep(1)
    posSlider:SetObeyStepOnDrag(true)
    _G[posSlider:GetName() .. "Low"]:SetText("0°")
    _G[posSlider:GetName() .. "High"]:SetText("360°")
    _G[posSlider:GetName() .. "Text"]:SetText("")

    posSlider:SetScript("OnValueChanged", function(_, val)
        val = math.floor(val)
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        sliderLabel:SetText(string.format(curL["SETTINGS_MINIMAP_POS_LABEL"] or "Minimap: %d°", val))
        if _G.GM and _G.GM.minimapButton and _G.GM.minimapButton.updatePosition then
            _G.GM.minimapButton:updatePosition(val)
        end
    end)
    self._widgets.minimapSlider = posSlider

    local resetPosBtn = CreateFrame("Button", nil, lChild, "UIPanelButtonTemplate")
    resetPosBtn:SetSize(90, 20)
    resetPosBtn:SetPoint("LEFT", posSlider, "RIGHT", 12, 0)
    resetPosBtn:SetText(L["SETTINGS_MINIMAP_DEFAULT_BTN"])
    resetPosBtn:SetScript("OnClick", function()
        posSlider:SetValue(215)
    end)
    self._widgets.resetPosBtn = resetPosBtn

    -- --- SEÇÃO 4: MAPA MUNDIAL & RASTREAMENTO ---
    local s4Header = lChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s4Header:SetPoint("TOPLEFT", sliderLabel, "BOTTOMLEFT", -4, -34)
    s4Header:SetText(L["SETTINGS_S4_HEADER"])
    self._widgets.s4Header = s4Header

    local s4Sep = lChild:CreateTexture(nil, "ARTWORK")
    s4Sep:SetPoint("TOPLEFT", s4Header, "BOTTOMLEFT", 0, -3)
    s4Sep:SetPoint("RIGHT", lChild, "RIGHT", -4, 0)
    s4Sep:SetHeight(1)
    s4Sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    local cbWorldMapBtn = createCheckbox(lChild, L["SETTINGS_MAP_BTN"], L["SETTINGS_MAP_BTN_TIP_TITLE"], L["SETTINGS_MAP_BTN_TIP_DESC"])
    cbWorldMapBtn:SetPoint("TOPLEFT", s4Sep, "BOTTOMLEFT", 0, -4)
    self._widgets.showWorldMapButton = cbWorldMapBtn

    local cbAutoScanMap = createCheckbox(lChild, L["SETTINGS_MAP_AUTOSCAN"], L["SETTINGS_MAP_AUTOSCAN_TIP_TITLE"], L["SETTINGS_MAP_AUTOSCAN_TIP_DESC"])
    cbAutoScanMap:SetPoint("TOPLEFT", cbWorldMapBtn, "BOTTOMLEFT", 0, -2)
    self._widgets.autoScanWorldMap = cbAutoScanMap

    local cbShowMapPins = createCheckbox(lChild, L["SETTINGS_MAP_PINS"], L["SETTINGS_MAP_PINS_TIP_TITLE"], L["SETTINGS_MAP_PINS_TIP_DESC"])
    cbShowMapPins:SetPoint("TOPLEFT", cbAutoScanMap, "BOTTOMLEFT", 0, -2)
    self._widgets.showMapPins = cbShowMapPins

    local cbHighlightSelf = createCheckbox(lChild, L["SETTINGS_MAP_HIGHLIGHT"], L["SETTINGS_MAP_HIGHLIGHT_TIP_TITLE"], L["SETTINGS_MAP_HIGHLIGHT_TIP_DESC"])
    cbHighlightSelf:SetPoint("TOPLEFT", cbShowMapPins, "BOTTOMLEFT", 0, -2)
    self._widgets.highlightSelfOnMap = cbHighlightSelf

    -- =========================================================================
    -- COLUNA DIREITA: Agenda, Grupos, Roster, Logs & Manutenção
    -- =========================================================================
    local rightCol = CreateFrame("Frame", nil, frame, template)
    rightCol:SetPoint("TOPLEFT", leftCol, "TOPRIGHT", 12, 0)
    rightCol:SetSize(colWidth, colHeight)
    if rightCol.SetBackdrop then
        rightCol:SetBackdrop(CONTAINER_BACKDROP)
        rightCol:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], 0.90)
        rightCol:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], 0.90)
    end

    local rScroll = CreateFrame("ScrollFrame", "GM_SettingsScrollRight", rightCol, "UIPanelScrollFrameTemplate")
    rScroll:SetPoint("TOPLEFT", rightCol, "TOPLEFT", 6, -6)
    rScroll:SetPoint("BOTTOMRIGHT", rightCol, "BOTTOMRIGHT", -22, 6)

    local rChild = CreateFrame("Frame", nil, rScroll)
    rChild:SetWidth(colWidth - 30)
    rChild:SetHeight(760)
    rScroll:SetScrollChild(rChild)

    -- --- SEÇÃO 5: AGENDA & EVENTOS DA GUILDA ---
    local s5Header = rChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s5Header:SetPoint("TOPLEFT", rChild, "TOPLEFT", 4, -4)
    s5Header:SetText(L["SETTINGS_S5_HEADER"])
    self._widgets.s5Header = s5Header

    local s5Sep = rChild:CreateTexture(nil, "ARTWORK")
    s5Sep:SetPoint("TOPLEFT", s5Header, "BOTTOMLEFT", 0, -3)
    s5Sep:SetPoint("RIGHT", rChild, "RIGHT", -4, 0)
    s5Sep:SetHeight(1)
    s5Sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    local cbBdayLogin = createCheckbox(rChild, L["SETTINGS_NOTIFY_BDAY_LOGIN"], L["SETTINGS_NOTIFY_BDAY_TIP_TITLE"], L["SETTINGS_NOTIFY_BDAY_TIP_DESC"])
    cbBdayLogin:SetPoint("TOPLEFT", s5Sep, "BOTTOMLEFT", 0, -4)
    self._widgets.notifyBirthdaysOnLogin = cbBdayLogin

    local cbEventLogin = createCheckbox(rChild, L["SETTINGS_NOTIFY_EVENT_LOGIN"], L["SETTINGS_NOTIFY_EVENT_TIP_TITLE"], L["SETTINGS_NOTIFY_EVENT_TIP_DESC"])
    cbEventLogin:SetPoint("TOPLEFT", cbBdayLogin, "BOTTOMLEFT", 0, -2)
    self._widgets.notifyUpcomingEvents = cbEventLogin

    local cbConfirmEvent = createCheckbox(rChild, L["SETTINGS_CONFIRM_EVENT_DELETE"], L["SETTINGS_CONFIRM_EVENT_TIP_TITLE"], L["SETTINGS_CONFIRM_EVENT_TIP_DESC"])
    cbConfirmEvent:SetPoint("TOPLEFT", cbEventLogin, "BOTTOMLEFT", 0, -2)
    self._widgets.confirmEventDelete = cbConfirmEvent

    local bdayLookaheadLabel = rChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bdayLookaheadLabel:SetPoint("TOPLEFT", cbConfirmEvent, "BOTTOMLEFT", 4, -6)
    bdayLookaheadLabel:SetText(L["SETTINGS_BDAY_LOOKAHEAD_LABEL"])
    self._widgets.bdayLookaheadLabel = bdayLookaheadLabel

    local lookaheadButtons = {}
    for i, lDef in ipairs(LOOKAHEAD_OPTIONS) do
        local btn = CreateFrame("Button", nil, rChild, template)
        btn:SetSize(78, 20)
        btn:SetPoint("TOPLEFT", bdayLookaheadLabel, "BOTTOMLEFT", (i - 1) * 82, -3)
        if btn.SetBackdrop then btn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("CENTER", btn, "CENTER", 0, 0)
        txt:SetText(string.format(L["SETTINGS_DAYS_FMT"], lDef.days))
        btn.txt = txt
        btn.days = lDef.days
        btn:SetScript("OnClick", function()
            self._widgets.selectedBirthdayLookaheadDays = lDef.days
            self:updateLookaheadButtons(lookaheadButtons, lDef.days)
        end)
        lookaheadButtons[lDef.days] = btn
    end
    self._widgets.lookaheadButtons = lookaheadButtons

    local defTimeLabel = rChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    defTimeLabel:SetPoint("TOPLEFT", bdayLookaheadLabel, "BOTTOMLEFT", 0, -32)
    defTimeLabel:SetText(L["SETTINGS_DEFAULT_EVENT_TIME"])
    self._widgets.defTimeLabel = defTimeLabel

    local defTimeEB = CreateFrame("EditBox", "GM_DefaultEventTimeEditBox", rChild)
    defTimeEB:SetSize(70, 20)
    defTimeEB:SetPoint("LEFT", defTimeLabel, "RIGHT", 8, 0)
    defTimeEB:SetMaxLetters(5)
    styleBox(defTimeEB)
    self._widgets.defaultEventTime = defTimeEB

    -- --- SEÇÃO 6: GERENCIAMENTO DE GRUPOS ---
    local s6Header = rChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s6Header:SetPoint("TOPLEFT", defTimeLabel, "BOTTOMLEFT", 0, -14)
    s6Header:SetText(L["SETTINGS_S6_HEADER"])
    self._widgets.s6Header = s6Header

    local s6Sep = rChild:CreateTexture(nil, "ARTWORK")
    s6Sep:SetPoint("TOPLEFT", s6Header, "BOTTOMLEFT", 0, -3)
    s6Sep:SetPoint("RIGHT", rChild, "RIGHT", -4, 0)
    s6Sep:SetHeight(1)
    s6Sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    local cbConfirmGroup = createCheckbox(rChild, L["SETTINGS_CONFIRM_GROUP_DELETE"], L["SETTINGS_CONFIRM_GROUP_TIP_TITLE"], L["SETTINGS_CONFIRM_GROUP_TIP_DESC"])
    cbConfirmGroup:SetPoint("TOPLEFT", s6Sep, "BOTTOMLEFT", 0, -4)
    self._widgets.confirmGroupDelete = cbConfirmGroup

    local cbAutoRole = createCheckbox(rChild, L["SETTINGS_AUTO_ROLE"], L["SETTINGS_AUTO_ROLE_TIP_TITLE"], L["SETTINGS_AUTO_ROLE_TIP_DESC"])
    cbAutoRole:SetPoint("TOPLEFT", cbConfirmGroup, "BOTTOMLEFT", 0, -2)
    self._widgets.autoAssignGroupRole = cbAutoRole

    -- --- SEÇÃO 7: AUDITORIA & ROSTER DE MEMBROS ---
    local s7Header = rChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s7Header:SetPoint("TOPLEFT", cbAutoRole, "BOTTOMLEFT", 2, -12)
    s7Header:SetText(L["SETTINGS_S7_HEADER"])
    self._widgets.s7Header = s7Header

    local s7Sep = rChild:CreateTexture(nil, "ARTWORK")
    s7Sep:SetPoint("TOPLEFT", s7Header, "BOTTOMLEFT", 0, -3)
    s7Sep:SetPoint("RIGHT", rChild, "RIGHT", -4, 0)
    s7Sep:SetHeight(1)
    s7Sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    local cbAutoScan = createCheckbox(rChild, L["SETTINGS_AUTO_SCAN"], L["SETTINGS_AUTO_SCAN_TIP_TITLE"], L["SETTINGS_AUTO_SCAN_TIP_DESC"])
    cbAutoScan:SetPoint("TOPLEFT", s7Sep, "BOTTOMLEFT", 0, -4)
    self._widgets.autoScanRoster = cbAutoScan

    local cbOffline = createCheckbox(rChild, L["SETTINGS_SHOW_OFFLINE"], L["SETTINGS_SHOW_OFFLINE_TIP_TITLE"], L["SETTINGS_SHOW_OFFLINE_TIP_DESC"])
    cbOffline:SetPoint("TOPLEFT", cbAutoScan, "BOTTOMLEFT", 0, -2)
    self._widgets.showOfflineMembers = cbOffline

    local cbNotifyRecruit = createCheckbox(rChild, L["SETTINGS_NOTIFY_RECRUIT"], L["SETTINGS_NOTIFY_RECRUIT_TIP_TITLE"], L["SETTINGS_NOTIFY_RECRUIT_TIP_DESC"])
    cbNotifyRecruit:SetPoint("TOPLEFT", cbOffline, "BOTTOMLEFT", 0, -2)
    self._widgets.notifyNewRecruit = cbNotifyRecruit

    -- --- SEÇÃO 8: REGISTRO DE EVENTOS (LOGS) ---
    local s8Header = rChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s8Header:SetPoint("TOPLEFT", cbNotifyRecruit, "BOTTOMLEFT", 2, -12)
    s8Header:SetText(L["SETTINGS_S8_HEADER"])
    self._widgets.s8Header = s8Header

    local s8Sep = rChild:CreateTexture(nil, "ARTWORK")
    s8Sep:SetPoint("TOPLEFT", s8Header, "BOTTOMLEFT", 0, -3)
    s8Sep:SetPoint("RIGHT", rChild, "RIGHT", -4, 0)
    s8Sep:SetHeight(1)
    s8Sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    local cbLvl = createCheckbox(rChild, L["SETTINGS_LOG_LEVEL"], L["SETTINGS_LOG_LEVEL_TIP_TITLE"], L["SETTINGS_LOG_LEVEL_TIP_DESC"])
    cbLvl:SetPoint("TOPLEFT", s8Sep, "BOTTOMLEFT", 0, -4)
    self._widgets.logLevelUp = cbLvl

    local cbPromote = createCheckbox(rChild, L["SETTINGS_LOG_PROMOTE"], L["SETTINGS_LOG_PROMOTE_TIP_TITLE"], L["SETTINGS_LOG_PROMOTE_TIP_DESC"])
    cbPromote:SetPoint("TOPLEFT", cbLvl, "BOTTOMLEFT", 0, -2)
    self._widgets.logPromoteDemote = cbPromote

    local cbNotes = createCheckbox(rChild, L["SETTINGS_LOG_NOTES"], L["SETTINGS_LOG_NOTES_TIP_TITLE"], L["SETTINGS_LOG_NOTES_TIP_DESC"])
    cbNotes:SetPoint("TOPLEFT", cbPromote, "BOTTOMLEFT", 0, -2)
    self._widgets.logNotes = cbNotes

    local cbJoinLeave = createCheckbox(rChild, L["SETTINGS_LOG_JOIN_LEAVE"], L["SETTINGS_LOG_JOIN_LEAVE_TIP_TITLE"], L["SETTINGS_LOG_JOIN_LEAVE_TIP_DESC"])
    cbJoinLeave:SetPoint("TOPLEFT", cbNotes, "BOTTOMLEFT", 0, -2)
    self._widgets.logJoinLeave = cbJoinLeave

    local cbRejoin = createCheckbox(rChild, L["SETTINGS_LOG_REJOIN"], L["SETTINGS_LOG_REJOIN_TIP_TITLE"], L["SETTINGS_LOG_REJOIN_TIP_DESC"])
    cbRejoin:SetPoint("TOPLEFT", cbJoinLeave, "BOTTOMLEFT", 0, -2)
    self._widgets.logRejoin = cbRejoin

    local retLabel = rChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    retLabel:SetPoint("TOPLEFT", cbRejoin, "BOTTOMLEFT", 4, -6)
    retLabel:SetText(L["SETTINGS_RETENTION_LABEL"])
    self._widgets.retLabel = retLabel

    local retentionDefs = {
        { days = 30 },
        { days = 60 },
        { days = 90 },
        { days = 0, isUnlimited = true },
    }
    local retentionButtons = {}
    for i, rDef in ipairs(retentionDefs) do
        local btn = CreateFrame("Button", nil, rChild, template)
        btn:SetSize(82, 20)
        btn:SetPoint("TOPLEFT", retLabel, "BOTTOMLEFT", (i - 1) * 88, -3)
        if btn.SetBackdrop then btn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("CENTER", btn, "CENTER", 0, 0)
        if rDef.isUnlimited then
            txt:SetText(L["SETTINGS_RETENTION_UNLIMITED"])
        else
            txt:SetText(string.format(L["SETTINGS_DAYS_FMT"], rDef.days))
        end
        btn.txt = txt
        btn.days = rDef.days
        btn:SetScript("OnClick", function()
            self._widgets.selectedRetentionDays = rDef.days
            self:updateRetentionButtons(retentionButtons, rDef.days)
        end)
        retentionButtons[rDef.days] = btn
    end
    self._widgets.retentionButtons = retentionButtons

    -- --- SEÇÃO 9: SEGURANÇA & MANUTENÇÃO ---
    local s9Header = rChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s9Header:SetPoint("TOPLEFT", retLabel, "BOTTOMLEFT", 0, -32)
    s9Header:SetText(L["SETTINGS_S9_HEADER"])
    self._widgets.s9Header = s9Header

    local s9Sep = rChild:CreateTexture(nil, "ARTWORK")
    s9Sep:SetPoint("TOPLEFT", s9Header, "BOTTOMLEFT", 0, -3)
    s9Sep:SetPoint("RIGHT", rChild, "RIGHT", -4, 0)
    s9Sep:SetHeight(1)
    s9Sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    local cbSyncChatLog = createCheckbox(rChild, L["SETTINGS_SYNC_CHAT_LOG"], L["SETTINGS_SYNC_CHAT_LOG_TIP_TITLE"], L["SETTINGS_SYNC_CHAT_LOG_TIP_DESC"])
    cbSyncChatLog:SetPoint("TOPLEFT", s9Sep, "BOTTOMLEFT", 0, -4)
    self._widgets.enableSyncChatLog = cbSyncChatLog

    -- Botões de Ação do Banco
    local purgeBtn = CreateFrame("Button", nil, rChild, "UIPanelButtonTemplate")
    purgeBtn:SetSize(170, 22)
    purgeBtn:SetPoint("TOPLEFT", cbSyncChatLog, "BOTTOMLEFT", 4, -8)
    purgeBtn:SetText(L["SETTINGS_PURGE_BTN"])
    purgeBtn:SetScript("OnClick", function()
        if self._onPurgeLogsCallback then
            self._onPurgeLogsCallback()
        end
    end)
    self._widgets.purgeBtn = purgeBtn

    local forceScanBtn = CreateFrame("Button", nil, rChild, "UIPanelButtonTemplate")
    forceScanBtn:SetSize(170, 22)
    forceScanBtn:SetPoint("LEFT", purgeBtn, "RIGHT", 10, 0)
    forceScanBtn:SetText(L["SETTINGS_FORCE_SCAN_BTN"])
    forceScanBtn:SetScript("OnClick", function()
        if self._onForceScanCallback then
            self._onForceScanCallback()
        end
    end)
    self._widgets.forceScanBtn = forceScanBtn

    local resetAllBtn = CreateFrame("Button", nil, rChild, "UIPanelButtonTemplate")
    resetAllBtn:SetSize(170, 22)
    resetAllBtn:SetPoint("TOPLEFT", purgeBtn, "BOTTOMLEFT", 0, -6)
    resetAllBtn:SetText(L["SETTINGS_RESET_DEFAULTS_BTN"])
    resetAllBtn:SetScript("OnClick", function()
        if self._onResetCallback then
            self._onResetCallback()
        end
    end)
    self._widgets.resetAllBtn = resetAllBtn

    local forceSyncBtn = CreateFrame("Button", nil, rChild, "UIPanelButtonTemplate")
    forceSyncBtn:SetSize(170, 22)
    forceSyncBtn:SetPoint("LEFT", resetAllBtn, "RIGHT", 10, 0)
    forceSyncBtn:SetText(L["SETTINGS_FORCE_SYNC_BTN"])
    forceSyncBtn:SetScript("OnClick", function()
        if self._onForceSyncCallback then
            self._onForceSyncCallback()
        end
    end)
    self._widgets.forceSyncBtn = forceSyncBtn
end

--- Cria o rodapé com ações de salvar e fechar.
function SettingsView:createFooter()
    local frame = self._frame

    local fSep = frame:CreateTexture(nil, "ARTWORK")
    fSep:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 44)
    fSep:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    fSep:SetHeight(1)
    fSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", fSep, "BOTTOMLEFT", 4, -18)
    hint:SetText("|cff666666" .. L["SETTINGS_FOOTER_HINT"] .. "|r")
    self._widgets.footerHint = hint

    local statusMsg = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusMsg:SetPoint("CENTER", frame, "BOTTOM", -50, 22)
    statusMsg:SetText("")
    self._widgets.statusMsg = statusMsg

    local saveBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveBtn:SetSize(150, 24)
    saveBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -120, 10)
    saveBtn:SetText(L["SAVE_SETTINGS"])
    saveBtn:SetScript("OnClick", function()
        if self._onSaveCallback then
            self._onSaveCallback(self:gatherFormData())
        end
    end)
    self._widgets.saveBtn = saveBtn

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(90, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 10)
    closeBtn:SetText(L["CLOSE"])
    closeBtn:SetScript("OnClick", function() self:hide() end)
    self._widgets.closeBtn = closeBtn
end

--- Atualiza a visualização dos botões da aba padrão.
function SettingsView:updateTabSelectionButtons(buttons, activeId)
    for id, btn in pairs(buttons) do
        local isActive = (id == activeId)
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

--- Atualiza botões de efeito sonoro.
function SettingsView:updateSoundButtons(buttons, activeId)
    for id, btn in pairs(buttons) do
        local isActive = (id == activeId)
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

--- Atualiza botões de retenção.
function SettingsView:updateRetentionButtons(buttons, activeDays)
    for days, btn in pairs(buttons) do
        local isActive = (days == activeDays)
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

--- Atualiza botões de antecedência de aniversariantes.
function SettingsView:updateLookaheadButtons(buttons, activeDays)
    for days, btn in pairs(buttons) do
        local isActive = (days == activeDays)
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

--- Atualiza dinamicamente todos os textos da interface após mudança de idioma.
function SettingsView:updateLocale()
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    if not self._frame then return end

    if self._title then self._title:SetText(curL["SETTINGS_TITLE"]) end
    if self._subTitle then self._subTitle:SetText(curL["SETTINGS_SUBTITLE"]) end
    if self._widgets.tagLabel then self._widgets.tagLabel:SetText(curL["SETTINGS_TAGLINE_LABEL"]) end
    if self._widgets.langLabel then self._widgets.langLabel:SetText(curL["SETTINGS_LANG_LABEL"]) end

    -- Seção 1
    if self._widgets.s1Header then self._widgets.s1Header:SetText(curL["SETTINGS_S1_HEADER"]) end
    if self._widgets.tabDefLabel then self._widgets.tabDefLabel:SetText(curL["SETTINGS_DEFAULT_TAB_LABEL"]) end
    if self._widgets.tabButtons then
        local tabKeys = { audit = "TAB_AUDIT", logs = "TAB_LOGS", groups = "TAB_GROUPS", agenda = "TAB_AGENDA", settings = "TAB_SETTINGS" }
        for id, btn in pairs(self._widgets.tabButtons) do
            if tabKeys[id] and btn.txt then btn.txt:SetText(curL[tabKeys[id]] or id) end
        end
    end
    if self._widgets.timeFormat24 then
        self._widgets.timeFormat24:updateTexts(curL["SETTINGS_TIME_24H"], curL["SETTINGS_TIME_24H_TIP_TITLE"], curL["SETTINGS_TIME_24H_TIP_DESC"])
    end

    -- Seção 2
    if self._widgets.s2Header then self._widgets.s2Header:SetText(curL["SETTINGS_S2_HEADER"]) end
    if self._widgets.enableChatMentions then
        self._widgets.enableChatMentions:updateTexts(curL["SETTINGS_CHAT_MENTIONS"], curL["SETTINGS_CHAT_MENTIONS_TIP_TITLE"], curL["SETTINGS_CHAT_MENTIONS_TIP_DESC"])
    end
    if self._widgets.enableMentionSound then
        self._widgets.enableMentionSound:updateTexts(curL["SETTINGS_MENTION_SOUND"], curL["SETTINGS_MENTION_SOUND_TIP_TITLE"], curL["SETTINGS_MENTION_SOUND_TIP_DESC"])
    end
    if self._widgets.enableMentionFlash then
        self._widgets.enableMentionFlash:updateTexts(curL["SETTINGS_MENTION_FLASH"], curL["SETTINGS_MENTION_FLASH_TIP_TITLE"], curL["SETTINGS_MENTION_FLASH_TIP_DESC"])
    end
    if self._widgets.soundLabel then self._widgets.soundLabel:SetText(curL["SETTINGS_SOUND_CHOICE_LABEL"]) end
    if self._widgets.soundButtons then
        local sndKeys = { whisper = "SOUND_WHISPER", raid = "SOUND_RAID", ready = "SOUND_READY", coin = "SOUND_COIN" }
        for id, btn in pairs(self._widgets.soundButtons) do
            if sndKeys[id] and btn.txt then btn.txt:SetText(curL[sndKeys[id]] or id) end
        end
    end
    if self._widgets.testSoundBtn then self._widgets.testSoundBtn:SetText(curL["TEST"]) end

    -- Seção 3
    if self._widgets.s3Header then self._widgets.s3Header:SetText(curL["SETTINGS_S3_HEADER"]) end
    if self._widgets.showMinimapButton then
        self._widgets.showMinimapButton:updateTexts(curL["SETTINGS_MINIMAP_BTN"], curL["SETTINGS_MINIMAP_BTN_TIP_TITLE"], curL["SETTINGS_MINIMAP_BTN_TIP_DESC"])
    end
    if self._widgets.sliderLabel and self._widgets.minimapSlider then
        local val = math.floor(self._widgets.minimapSlider:GetValue())
        self._widgets.sliderLabel:SetText(string.format(curL["SETTINGS_MINIMAP_POS_LABEL"] or "Minimap: %d°", val))
    end
    if self._widgets.resetPosBtn then self._widgets.resetPosBtn:SetText(curL["SETTINGS_MINIMAP_DEFAULT_BTN"]) end

    -- Seção 4
    if self._widgets.s4Header then self._widgets.s4Header:SetText(curL["SETTINGS_S4_HEADER"]) end
    if self._widgets.showWorldMapButton then
        self._widgets.showWorldMapButton:updateTexts(curL["SETTINGS_MAP_BTN"], curL["SETTINGS_MAP_BTN_TIP_TITLE"], curL["SETTINGS_MAP_BTN_TIP_DESC"])
    end
    if self._widgets.autoScanWorldMap then
        self._widgets.autoScanWorldMap:updateTexts(curL["SETTINGS_MAP_AUTOSCAN"], curL["SETTINGS_MAP_AUTOSCAN_TIP_TITLE"], curL["SETTINGS_MAP_AUTOSCAN_TIP_DESC"])
    end
    if self._widgets.showMapPins then
        self._widgets.showMapPins:updateTexts(curL["SETTINGS_MAP_PINS"], curL["SETTINGS_MAP_PINS_TIP_TITLE"], curL["SETTINGS_MAP_PINS_TIP_DESC"])
    end
    if self._widgets.highlightSelfOnMap then
        self._widgets.highlightSelfOnMap:updateTexts(curL["SETTINGS_MAP_HIGHLIGHT"], curL["SETTINGS_MAP_HIGHLIGHT_TIP_TITLE"], curL["SETTINGS_MAP_HIGHLIGHT_TIP_DESC"])
    end

    -- Seção 5
    if self._widgets.s5Header then self._widgets.s5Header:SetText(curL["SETTINGS_S5_HEADER"]) end
    if self._widgets.notifyBirthdaysOnLogin then
        self._widgets.notifyBirthdaysOnLogin:updateTexts(curL["SETTINGS_NOTIFY_BDAY_LOGIN"], curL["SETTINGS_NOTIFY_BDAY_TIP_TITLE"], curL["SETTINGS_NOTIFY_BDAY_TIP_DESC"])
    end
    if self._widgets.notifyUpcomingEvents then
        self._widgets.notifyUpcomingEvents:updateTexts(curL["SETTINGS_NOTIFY_EVENT_LOGIN"], curL["SETTINGS_NOTIFY_EVENT_TIP_TITLE"], curL["SETTINGS_NOTIFY_EVENT_TIP_DESC"])
    end
    if self._widgets.confirmEventDelete then
        self._widgets.confirmEventDelete:updateTexts(curL["SETTINGS_CONFIRM_EVENT_DELETE"], curL["SETTINGS_CONFIRM_EVENT_TIP_TITLE"], curL["SETTINGS_CONFIRM_EVENT_TIP_DESC"])
    end
    if self._widgets.bdayLookaheadLabel then self._widgets.bdayLookaheadLabel:SetText(curL["SETTINGS_BDAY_LOOKAHEAD_LABEL"]) end
    if self._widgets.lookaheadButtons then
        for days, btn in pairs(self._widgets.lookaheadButtons) do
            if btn.txt then btn.txt:SetText(string.format(curL["SETTINGS_DAYS_FMT"] or "%d Days", days)) end
        end
    end
    if self._widgets.defTimeLabel then self._widgets.defTimeLabel:SetText(curL["SETTINGS_DEFAULT_EVENT_TIME"]) end

    -- Seção 6
    if self._widgets.s6Header then self._widgets.s6Header:SetText(curL["SETTINGS_S6_HEADER"]) end
    if self._widgets.confirmGroupDelete then
        self._widgets.confirmGroupDelete:updateTexts(curL["SETTINGS_CONFIRM_GROUP_DELETE"], curL["SETTINGS_CONFIRM_GROUP_TIP_TITLE"], curL["SETTINGS_CONFIRM_GROUP_TIP_DESC"])
    end
    if self._widgets.autoAssignGroupRole then
        self._widgets.autoAssignGroupRole:updateTexts(curL["SETTINGS_AUTO_ROLE"], curL["SETTINGS_AUTO_ROLE_TIP_TITLE"], curL["SETTINGS_AUTO_ROLE_TIP_DESC"])
    end

    -- Seção 7
    if self._widgets.s7Header then self._widgets.s7Header:SetText(curL["SETTINGS_S7_HEADER"]) end
    if self._widgets.autoScanRoster then
        self._widgets.autoScanRoster:updateTexts(curL["SETTINGS_AUTO_SCAN"], curL["SETTINGS_AUTO_SCAN_TIP_TITLE"], curL["SETTINGS_AUTO_SCAN_TIP_DESC"])
    end
    if self._widgets.showOfflineMembers then
        self._widgets.showOfflineMembers:updateTexts(curL["SETTINGS_SHOW_OFFLINE"], curL["SETTINGS_SHOW_OFFLINE_TIP_TITLE"], curL["SETTINGS_SHOW_OFFLINE_TIP_DESC"])
    end
    if self._widgets.notifyNewRecruit then
        self._widgets.notifyNewRecruit:updateTexts(curL["SETTINGS_NOTIFY_RECRUIT"], curL["SETTINGS_NOTIFY_RECRUIT_TIP_TITLE"], curL["SETTINGS_NOTIFY_RECRUIT_TIP_DESC"])
    end

    -- Seção 8
    if self._widgets.s8Header then self._widgets.s8Header:SetText(curL["SETTINGS_S8_HEADER"]) end
    if self._widgets.logLevelUp then
        self._widgets.logLevelUp:updateTexts(curL["SETTINGS_LOG_LEVEL"], curL["SETTINGS_LOG_LEVEL_TIP_TITLE"], curL["SETTINGS_LOG_LEVEL_TIP_DESC"])
    end
    if self._widgets.logPromoteDemote then
        self._widgets.logPromoteDemote:updateTexts(curL["SETTINGS_LOG_PROMOTE"], curL["SETTINGS_LOG_PROMOTE_TIP_TITLE"], curL["SETTINGS_LOG_PROMOTE_TIP_DESC"])
    end
    if self._widgets.logNotes then
        self._widgets.logNotes:updateTexts(curL["SETTINGS_LOG_NOTES"], curL["SETTINGS_LOG_NOTES_TIP_TITLE"], curL["SETTINGS_LOG_NOTES_TIP_DESC"])
    end
    if self._widgets.logJoinLeave then
        self._widgets.logJoinLeave:updateTexts(curL["SETTINGS_LOG_JOIN_LEAVE"], curL["SETTINGS_LOG_JOIN_LEAVE_TIP_TITLE"], curL["SETTINGS_LOG_JOIN_LEAVE_TIP_DESC"])
    end
    if self._widgets.logRejoin then
        self._widgets.logRejoin:updateTexts(curL["SETTINGS_LOG_REJOIN"], curL["SETTINGS_LOG_REJOIN_TIP_TITLE"], curL["SETTINGS_LOG_REJOIN_TIP_DESC"])
    end
    if self._widgets.retLabel then self._widgets.retLabel:SetText(curL["SETTINGS_RETENTION_LABEL"]) end
    if self._widgets.retentionButtons then
        for days, btn in pairs(self._widgets.retentionButtons) do
            if btn.txt then
                if days == 0 then
                    btn.txt:SetText(curL["SETTINGS_RETENTION_UNLIMITED"] or "Unlimited")
                else
                    btn.txt:SetText(string.format(curL["SETTINGS_DAYS_FMT"] or "%d Days", days))
                end
            end
        end
    end

    -- Seção 9
    if self._widgets.s9Header then self._widgets.s9Header:SetText(curL["SETTINGS_S9_HEADER"]) end
    if self._widgets.enableSyncChatLog then
        self._widgets.enableSyncChatLog:updateTexts(curL["SETTINGS_SYNC_CHAT_LOG"], curL["SETTINGS_SYNC_CHAT_LOG_TIP_TITLE"], curL["SETTINGS_SYNC_CHAT_LOG_TIP_DESC"])
    end
    if self._widgets.purgeBtn then self._widgets.purgeBtn:SetText(curL["SETTINGS_PURGE_BTN"]) end
    if self._widgets.forceScanBtn then self._widgets.forceScanBtn:SetText(curL["SETTINGS_FORCE_SCAN_BTN"]) end
    if self._widgets.resetAllBtn then self._widgets.resetAllBtn:SetText(curL["SETTINGS_RESET_DEFAULTS_BTN"]) end
    if self._widgets.forceSyncBtn then self._widgets.forceSyncBtn:SetText(curL["SETTINGS_FORCE_SYNC_BTN"]) end

    -- Rodapé
    if self._widgets.footerHint then self._widgets.footerHint:SetText("|cff666666" .. (curL["SETTINGS_FOOTER_HINT"] or "GuildManager") .. "|r") end
    if self._widgets.saveBtn then self._widgets.saveBtn:SetText(curL["SAVE_SETTINGS"] or "Save Settings") end
    if self._widgets.closeBtn then self._widgets.closeBtn:SetText(curL["CLOSE"] or "Close") end

    if self._lastStats and self._widgets.gStatsText then
        self._widgets.gStatsText:SetText(string.format(
            curL["SETTINGS_STATS_FORMAT"] or "|cffaaaaaaMembers: |cffffff00%d|r  •  Groups: |cffffff00%d|r  •  Logs: |cffffff00%d|r  •  v%s|r",
            self._lastStats.totalMembers or 0, self._lastStats.totalGroups or 0, self._lastStats.totalLogs or 0, self._lastStats.version or "1.0"
        ))
    end

    local curLang = self._widgets.selectedLanguage or (_G.GM and _G.GM.GetLocale and _G.GM.GetLocale()) or "enUS"
    self:updateLanguageButtonsVisual(self._widgets.langButtons, curLang)
end

--- Preenche a interface com os valores atuais de Settings e estatísticas.
---@param settings GMSettings
---@param stats table
function SettingsView:renderSettings(settings, stats)
    if not self._frame or not settings then return end

    -- Idioma
    local lang = settings.getLanguage and settings:getLanguage() or "enUS"
    self._widgets.selectedLanguage = lang
    self:updateLanguageButtonsVisual(self._widgets.langButtons, lang)

    -- Estatísticas da Guilda
    if stats then
        self._lastStats = stats
        self._widgets.gNameText:SetText(string.format("|cffffd200<%s>|r", stats.guildName or "Guilda"))
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        self._widgets.gStatsText:SetText(string.format(
            curL["SETTINGS_STATS_FORMAT"] or "|cffaaaaaaMembers: |cffffff00%d|r  •  Groups: |cffffff00%d|r  •  Logs: |cffffff00%d|r  •  v%s|r",
            stats.totalMembers or 0, stats.totalGroups or 0, stats.totalLogs or 0, stats.version or "1.0"
        ))
    end

    -- Lema da guilda
    self._widgets.guildTagline:SetText(settings:getGuildTagline() or "")

    -- Aba padrão
    self._widgets.selectedDefaultTab = settings:getDefaultTab() or "audit"
    self:updateTabSelectionButtons(self._widgets.tabButtons, self._widgets.selectedDefaultTab)

    -- Formato 24h
    self._widgets.timeFormat24:SetChecked(settings:isTimeFormat24())

    -- Chat & Menções
    self._widgets.enableChatMentions:SetChecked(settings:isChatMentionsEnabled())
    self._widgets.enableMentionSound:SetChecked(settings:isMentionSoundEnabled())
    self._widgets.enableMentionFlash:SetChecked(settings:isMentionFlashEnabled())
    self._widgets.selectedMentionSound = settings:getMentionSoundChoice() or "whisper"
    self:updateSoundButtons(self._widgets.soundButtons, self._widgets.selectedMentionSound)

    -- Minimapa
    self._widgets.showMinimapButton:SetChecked(settings:isShowMinimapButton())
    local mPos = settings:getMinimapPos() or 215
    self._widgets.minimapSlider:SetValue(mPos)
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    self._widgets.sliderLabel:SetText(string.format(curL["SETTINGS_MINIMAP_POS_LABEL"] or "Minimap: %d°", mPos))

    -- Mapa Mundial & Rastreamento
    self._widgets.showWorldMapButton:SetChecked(settings:isShowWorldMapButton())
    self._widgets.autoScanWorldMap:SetChecked(settings:isAutoScanWorldMap())
    self._widgets.showMapPins:SetChecked(settings:isShowMapPins())
    self._widgets.highlightSelfOnMap:SetChecked(settings:isHighlightSelfOnMap())

    -- Agenda & Eventos
    self._widgets.notifyBirthdaysOnLogin:SetChecked(settings:isNotifyBirthdaysOnLogin())
    self._widgets.notifyUpcomingEvents:SetChecked(settings:isNotifyUpcomingEvents())
    self._widgets.confirmEventDelete:SetChecked(settings:isConfirmEventDelete())
    self._widgets.selectedBirthdayLookaheadDays = settings:getBirthdayLookaheadDays()
    self:updateLookaheadButtons(self._widgets.lookaheadButtons, self._widgets.selectedBirthdayLookaheadDays)
    self._widgets.defaultEventTime:SetText(settings:getDefaultEventTime() or "20:00")

    -- Grupos
    self._widgets.confirmGroupDelete:SetChecked(settings:isConfirmGroupDelete())
    self._widgets.autoAssignGroupRole:SetChecked(settings:isAutoAssignGroupRole())

    -- Auditoria & Roster
    self._widgets.autoScanRoster:SetChecked(settings:isAutoScanRoster())
    self._widgets.showOfflineMembers:SetChecked(settings:isShowOfflineMembers())
    self._widgets.notifyNewRecruit:SetChecked(settings:isNotifyNewRecruit())

    -- Logs
    self._widgets.logLevelUp:SetChecked(settings:isLogLevelUp())
    self._widgets.logPromoteDemote:SetChecked(settings:isLogPromoteDemote())
    self._widgets.logNotes:SetChecked(settings:isLogNotes())
    self._widgets.logJoinLeave:SetChecked(settings:isLogJoinLeave())
    self._widgets.logRejoin:SetChecked(settings:isLogRejoin())
    self._widgets.selectedRetentionDays = settings:getLogRetentionDays()
    self:updateRetentionButtons(self._widgets.retentionButtons, self._widgets.selectedRetentionDays)

    if self._widgets.enableSyncChatLog then
        self._widgets.enableSyncChatLog:SetChecked(settings:isSyncChatLogEnabled())
    end

    self._widgets.statusMsg:SetText("")
end

--- Coleta os valores dos controles da tela em uma tabela.
---@return table
function SettingsView:gatherFormData()
    local w = self._widgets
    return {
        language = w.selectedLanguage or "enUS",
        guildTagline = w.guildTagline:GetText() or "",
        defaultTab = w.selectedDefaultTab or "audit",
        timeFormat24 = w.timeFormat24:GetChecked() == true,
        enableChatMentions = w.enableChatMentions:GetChecked() == true,
        enableMentionSound = w.enableMentionSound:GetChecked() == true,
        enableMentionFlash = w.enableMentionFlash:GetChecked() == true,
        mentionSoundChoice = w.selectedMentionSound or "whisper",
        showMinimapButton = w.showMinimapButton:GetChecked() == true,
        minimapPos = math.floor(w.minimapSlider:GetValue()),
        showWorldMapButton = w.showWorldMapButton:GetChecked() == true,
        autoScanWorldMap = w.autoScanWorldMap:GetChecked() == true,
        showMapPins = w.showMapPins:GetChecked() == true,
        highlightSelfOnMap = w.highlightSelfOnMap:GetChecked() == true,
        notifyBirthdaysOnLogin = w.notifyBirthdaysOnLogin:GetChecked() == true,
        notifyUpcomingEvents = w.notifyUpcomingEvents:GetChecked() == true,
        confirmEventDelete = w.confirmEventDelete:GetChecked() == true,
        birthdayLookaheadDays = tonumber(w.selectedBirthdayLookaheadDays) or 30,
        defaultEventTime = (w.defaultEventTime:GetText() and w.defaultEventTime:GetText() ~= "") and w.defaultEventTime:GetText() or "20:00",
        confirmGroupDelete = w.confirmGroupDelete:GetChecked() == true,
        autoAssignGroupRole = w.autoAssignGroupRole:GetChecked() == true,
        autoScanRoster = w.autoScanRoster:GetChecked() == true,
        showOfflineMembers = w.showOfflineMembers:GetChecked() == true,
        notifyNewRecruit = w.notifyNewRecruit:GetChecked() == true,
        notifyMemberLevelUp = false,
        logLevelUp = w.logLevelUp:GetChecked() == true,
        logPromoteDemote = w.logPromoteDemote:GetChecked() == true,
        logNotes = w.logNotes:GetChecked() == true,
        logJoinLeave = w.logJoinLeave:GetChecked() == true,
        logRejoin = w.logRejoin:GetChecked() == true,
        logRetentionDays = tonumber(w.selectedRetentionDays) or 60,
        enableSyncChatLog = w.enableSyncChatLog and (w.enableSyncChatLog:GetChecked() == true) or false,
    }
end

--- Exibe mensagem de status temporária na interface.
---@param text string
---@param isError boolean|nil
function SettingsView:showStatus(text, isError)
    if not self._widgets.statusMsg then return end
    local color = isError and "|cffff4444" or "|cff00ff00"
    self._widgets.statusMsg:SetText(color .. text .. "|r")
    C_Timer.After(4, function()
        if self._widgets.statusMsg then
            self._widgets.statusMsg:SetText("")
        end
    end)
end

function SettingsView:show()
    if not self._frame then self:createUI() end
    self._frame:Show()
    self:updateLocale()
    if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN or 839) end
end

function SettingsView:hide()
    if self._frame then self._frame:Hide() end
    if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE or 840) end
end

function SettingsView:toggle()
    if self:isShown() then self:hide() else self:show() end
end

function SettingsView:getFrame() return self._frame end
function SettingsView:isShown() return self._frame and self._frame:IsShown() or false end

_G.SettingsView = SettingsView
