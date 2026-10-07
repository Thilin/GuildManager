---@class SettingsView
---@field private _frame table|nil
SettingsView = {}
SettingsView.__index = SettingsView

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
    { id = "whisper", label = "Sussurro", soundId = 3081 },
    { id = "raid",    label = "Alerta Raide", soundId = 8959 },
    { id = "ready",   label = "Ready Check", soundId = 8960 },
    { id = "coin",    label = "Moeda", soundId = 120 },
}

local LOOKAHEAD_OPTIONS = {
    { days = 7,  label = "7 Dias" },
    { days = 14, label = "14 Dias" },
    { days = 30, label = "30 Dias" },
    { days = 60, label = "60 Dias" },
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

    instance:createUI()

    return instance
end

function SettingsView:setOnSaveCallback(cb) self._onSaveCallback = cb end
function SettingsView:setOnResetCallback(cb) self._onResetCallback = cb end
function SettingsView:setOnPurgeLogsCallback(cb) self._onPurgeLogsCallback = cb end
function SettingsView:setOnForceScanCallback(cb) self._onForceScanCallback = cb end

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

--- Helper para criar checkboxes no padrão Blizzard.
local function createCheckbox(parent, labelText, tooltipTitle, tooltipDesc)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    local txt = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    txt:SetText(labelText)
    cb.label = txt

    if tooltipTitle then
        cb:SetScript("OnEnter", function(f)
            GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|cffffd200" .. tooltipTitle .. "|r")
            if tooltipDesc then
                GameTooltip:AddLine(tooltipDesc, 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    cb:SetScript("OnClick", function(f)
        if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) end
    end)

    return cb
end

--- Cria a interface gráfica principal da tela de configurações.
function SettingsView:createUI()
    if self._frame then return end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "GM_SettingsFrame", UIParent, template)
    frame:SetSize(840, 510)
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
    title:SetText("|cffffd200CONFIGURAÇÕES DO GUILDMANAGER|r")

    local subTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subTitle:SetPoint("LEFT", title, "RIGHT", 12, 0)
    subTitle:SetText("|cffaaaaaaPersonalize opções visuais, alertas, histórico e dados da guilda|r")

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

--- Cria as abas laterais (Auditoria, Logs, Grupos, Configurações).
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
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd200Configurações do Addon|r")
        GameTooltip:AddLine("|cff888888(Aba atual)|r", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Personalização de comportamento, alertas, minimapa e dados da guilda.", 1, 1, 1, true)
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
    tagLabel:SetText("|cffffd200Lema / Mensagem:|r")

    local tagEB = CreateFrame("EditBox", nil, topBox, template)
    tagEB:SetPoint("LEFT", tagLabel, "RIGHT", 8, 0)
    tagEB:SetSize(315, 22)
    styleBox(tagEB)
    self._widgets.guildTagline = tagEB

    self._topBox = topBox
end

--- Cria as duas colunas estruturadas de configurações.
function SettingsView:createSettingsColumns()
    local frame = self._frame
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    local colWidth = 398
    local colHeight = 352

    -- =========================================================================
    -- COLUNA ESQUERDA: Interface, Chat & Minimapa
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
    lChild:SetHeight(480)
    lScroll:SetScrollChild(lChild)

    -- --- SEÇÃO 1: APRESENTAÇÃO & INTERFACE ---
    local s1Header = lChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s1Header:SetPoint("TOPLEFT", lChild, "TOPLEFT", 4, -4)
    s1Header:SetText("|cffffd2001. APRESENTAÇÃO & INTERFACE|r")

    local s1Sep = lChild:CreateTexture(nil, "ARTWORK")
    s1Sep:SetPoint("TOPLEFT", s1Header, "BOTTOMLEFT", 0, -3)
    s1Sep:SetPoint("RIGHT", lChild, "RIGHT", -4, 0)
    s1Sep:SetHeight(1)
    s1Sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    local tabDefLabel = lChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tabDefLabel:SetPoint("TOPLEFT", s1Sep, "BOTTOMLEFT", 2, -6)
    tabDefLabel:SetText("Aba inicial padrão ao abrir o Addon:")

    local tabDefs = {
        { id = "audit",    label = "Auditoria" },
        { id = "logs",     label = "Logs" },
        { id = "groups",   label = "Grupos" },
        { id = "agenda",   label = "Agenda" },
        { id = "settings", label = "Opções" },
    }
    local tabButtons = {}
    for i, tDef in ipairs(tabDefs) do
        local btn = CreateFrame("Button", nil, lChild, template)
        btn:SetSize(62, 20)
        btn:SetPoint("TOPLEFT", tabDefLabel, "BOTTOMLEFT", (i - 1) * 65, -4)
        if btn.SetBackdrop then btn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("CENTER", btn, "CENTER", 0, 0)
        txt:SetText(tDef.label)
        btn.txt = txt
        btn:SetScript("OnClick", function()
            self._widgets.selectedDefaultTab = tDef.id
            self:updateTabSelectionButtons(tabButtons, tDef.id)
        end)
        tabButtons[tDef.id] = btn
    end
    self._widgets.tabButtons = tabButtons

    local cbTime24 = createCheckbox(lChild, "Formato 24 horas no relógio dos registros (ex: 21:45)", "Formato de Horário", "Exibe horários no formato 24 horas ou no formato AM/PM.")
    cbTime24:SetPoint("TOPLEFT", tabDefLabel, "BOTTOMLEFT", 0, -32)
    self._widgets.timeFormat24 = cbTime24

    -- --- SEÇÃO 2: CHAT & MENÇÕES (@) ---
    local s2Header = lChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s2Header:SetPoint("TOPLEFT", cbTime24, "BOTTOMLEFT", 2, -12)
    s2Header:SetText("|cffffd2002. CHAT DA GUILDA & MENÇÕES (@)|r")

    local s2Sep = lChild:CreateTexture(nil, "ARTWORK")
    s2Sep:SetPoint("TOPLEFT", s2Header, "BOTTOMLEFT", 0, -3)
    s2Sep:SetPoint("RIGHT", lChild, "RIGHT", -4, 0)
    s2Sep:SetHeight(1)
    s2Sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    local cbChatMentions = createCheckbox(lChild, "Ativar menções no chat da guilda (@Nome com autocomplete)", "Menções no Chat", "Permite digitar @ no chat da guilda para abrir a lista de membros e destacar nomes em dourado.")
    cbChatMentions:SetPoint("TOPLEFT", s2Sep, "BOTTOMLEFT", 0, -4)
    self._widgets.enableChatMentions = cbChatMentions

    local cbMentionSound = createCheckbox(lChild, "Tocar aviso sonoro quando eu for mencionado no chat", "Alerta Sonoro", "Executa um efeito de som imediato quando outro membro marcar seu nome no chat da guilda.")
    cbMentionSound:SetPoint("TOPLEFT", cbChatMentions, "BOTTOMLEFT", 0, -2)
    self._widgets.enableMentionSound = cbMentionSound

    local cbMentionFlash = createCheckbox(lChild, "Piscar a janela/aba de chat ao receber menção", "Alerta Visual", "Aplica uma animação visual pulsante na janela de chat onde você foi mencionado.")
    cbMentionFlash:SetPoint("TOPLEFT", cbMentionSound, "BOTTOMLEFT", 0, -2)
    self._widgets.enableMentionFlash = cbMentionFlash

    local soundLabel = lChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    soundLabel:SetPoint("TOPLEFT", cbMentionFlash, "BOTTOMLEFT", 4, -6)
    soundLabel:SetText("Efeito sonoro da menção:")

    local soundButtons = {}
    for i, sDef in ipairs(SOUND_OPTIONS) do
        local btn = CreateFrame("Button", nil, lChild, template)
        btn:SetSize(66, 18)
        btn:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", (i - 1) * 70, -3)
        if btn.SetBackdrop then btn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("CENTER", btn, "CENTER", 0, 0)
        txt:SetText(sDef.label)
        btn.txt = txt
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
    testSoundBtn:SetText("Testar")
    testSoundBtn:SetScript("OnClick", function()
        local cur = self._widgets.selectedMentionSound or "whisper"
        for _, s in ipairs(SOUND_OPTIONS) do
            if s.id == cur then
                if PlaySound then pcall(PlaySound, s.soundId, "Master") end
                break
            end
        end
    end)

    -- --- SEÇÃO 3: BOTÃO DO MINIMAPA ---
    local s3Header = lChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s3Header:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", 0, -30)
    s3Header:SetText("|cffffd2003. BOTÃO DO MINIMAPA|r")

    local s3Sep = lChild:CreateTexture(nil, "ARTWORK")
    s3Sep:SetPoint("TOPLEFT", s3Header, "BOTTOMLEFT", 0, -3)
    s3Sep:SetPoint("RIGHT", lChild, "RIGHT", -4, 0)
    s3Sep:SetHeight(1)
    s3Sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    local cbMinimap = createCheckbox(lChild, "Exibir botão do GuildManager ao redor do minimapa", "Botão do Minimapa", "Mostra o ícone flutuante do GuildManager na borda do Minimapa.")
    cbMinimap:SetPoint("TOPLEFT", s3Sep, "BOTTOMLEFT", 0, -4)
    self._widgets.showMinimapButton = cbMinimap

    local sliderLabel = lChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sliderLabel:SetPoint("TOPLEFT", cbMinimap, "BOTTOMLEFT", 4, -6)
    sliderLabel:SetText("Posição Orbital do Minimapa: 215°")
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
        sliderLabel:SetText(string.format("Posição Orbital do Minimapa: %d°", val))
        if _G.GM and _G.GM.minimapButton and _G.GM.minimapButton.updatePosition then
            _G.GM.minimapButton:updatePosition(val)
        end
    end)
    self._widgets.minimapSlider = posSlider

    local resetPosBtn = CreateFrame("Button", nil, lChild, "UIPanelButtonTemplate")
    resetPosBtn:SetSize(90, 20)
    resetPosBtn:SetPoint("LEFT", posSlider, "RIGHT", 12, 0)
    resetPosBtn:SetText("Padrão (215°)")
    resetPosBtn:SetScript("OnClick", function()
        posSlider:SetValue(215)
    end)

    -- --- SEÇÃO 4: MAPA MUNDIAL & RASTREAMENTO ---
    local s4Header = lChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s4Header:SetPoint("TOPLEFT", sliderLabel, "BOTTOMLEFT", -4, -34)
    s4Header:SetText("|cffffd2004. MAPA MUNDIAL & RASTREAMENTO|r")

    local s4Sep = lChild:CreateTexture(nil, "ARTWORK")
    s4Sep:SetPoint("TOPLEFT", s4Header, "BOTTOMLEFT", 0, -3)
    s4Sep:SetPoint("RIGHT", lChild, "RIGHT", -4, 0)
    s4Sep:SetHeight(1)
    s4Sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    local cbWorldMapBtn = createCheckbox(lChild, "Exibir botão do GuildManager no cabeçalho do Mapa", "Botão no Mapa", "Mostra o botão de resumo da guilda na barra superior direita do mapa mundial.")
    cbWorldMapBtn:SetPoint("TOPLEFT", s4Sep, "BOTTOMLEFT", 0, -4)
    self._widgets.showWorldMapButton = cbWorldMapBtn

    local cbAutoScanMap = createCheckbox(lChild, "Escanear membros da guilda ao abrir o mapa mundial", "Varredura Automática", "Atualiza a lista de membros e suas posições sempre que você abre o mapa.")
    cbAutoScanMap:SetPoint("TOPLEFT", cbWorldMapBtn, "BOTTOMLEFT", 0, -2)
    self._widgets.autoScanWorldMap = cbAutoScanMap

    local cbShowMapPins = createCheckbox(lChild, "Exibir marcadores e painel de membros na zona", "Marcadores no Mapa", "Exibe marcadores e o painel expansível de membros da guilda no mapa.")
    cbShowMapPins:SetPoint("TOPLEFT", cbAutoScanMap, "BOTTOMLEFT", 0, -2)
    self._widgets.showMapPins = cbShowMapPins

    local cbHighlightSelf = createCheckbox(lChild, "Destacar o próprio jogador na listagem da região", "Destacar a Si Mesmo", "Exibe seu personagem no topo da lista com identificação e destaque dourado.")
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
    s5Header:SetText("|cffffd2005. AGENDA & EVENTOS DA GUILDA|r")

    local s5Sep = rChild:CreateTexture(nil, "ARTWORK")
    s5Sep:SetPoint("TOPLEFT", s5Header, "BOTTOMLEFT", 0, -3)
    s5Sep:SetPoint("RIGHT", rChild, "RIGHT", -4, 0)
    s5Sep:SetHeight(1)
    s5Sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    local cbBdayLogin = createCheckbox(rChild, "Avisar no chat sobre aniversariantes do dia ao conectar", "Aniversariantes de Hoje", "Exibe lembrete no chat local caso haja colegas de guilda fazendo aniversário no dia atual.")
    cbBdayLogin:SetPoint("TOPLEFT", s5Sep, "BOTTOMLEFT", 0, -4)
    self._widgets.notifyBirthdaysOnLogin = cbBdayLogin

    local cbEventLogin = createCheckbox(rChild, "Avisar no chat sobre eventos da guilda agendados para hoje", "Eventos de Hoje", "Notifica no chat local sobre eventos de raide, masmorra ou comemorações hoje.")
    cbEventLogin:SetPoint("TOPLEFT", cbBdayLogin, "BOTTOMLEFT", 0, -2)
    self._widgets.notifyUpcomingEvents = cbEventLogin

    local cbConfirmEvent = createCheckbox(rChild, "Solicitar confirmação ao excluir eventos da agenda", "Segurança da Agenda", "Exige confirmação antes de remover qualquer evento registrado.")
    cbConfirmEvent:SetPoint("TOPLEFT", cbEventLogin, "BOTTOMLEFT", 0, -2)
    self._widgets.confirmEventDelete = cbConfirmEvent

    local bdayLookaheadLabel = rChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bdayLookaheadLabel:SetPoint("TOPLEFT", cbConfirmEvent, "BOTTOMLEFT", 4, -6)
    bdayLookaheadLabel:SetText("Antecedência de aniversários na lista:")

    local lookaheadButtons = {}
    for i, lDef in ipairs(LOOKAHEAD_OPTIONS) do
        local btn = CreateFrame("Button", nil, rChild, template)
        btn:SetSize(78, 20)
        btn:SetPoint("TOPLEFT", bdayLookaheadLabel, "BOTTOMLEFT", (i - 1) * 82, -3)
        if btn.SetBackdrop then btn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("CENTER", btn, "CENTER", 0, 0)
        txt:SetText(lDef.label)
        btn.txt = txt
        btn:SetScript("OnClick", function()
            self._widgets.selectedBirthdayLookaheadDays = lDef.days
            self:updateLookaheadButtons(lookaheadButtons, lDef.days)
        end)
        lookaheadButtons[lDef.days] = btn
    end
    self._widgets.lookaheadButtons = lookaheadButtons

    local defTimeLabel = rChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    defTimeLabel:SetPoint("TOPLEFT", bdayLookaheadLabel, "BOTTOMLEFT", 0, -32)
    defTimeLabel:SetText("Horário padrão sugerido ao criar eventos:")

    local defTimeEB = CreateFrame("EditBox", "GM_DefaultEventTimeEditBox", rChild)
    defTimeEB:SetSize(70, 20)
    defTimeEB:SetPoint("LEFT", defTimeLabel, "RIGHT", 8, 0)
    defTimeEB:SetMaxLetters(5)
    styleBox(defTimeEB)
    self._widgets.defaultEventTime = defTimeEB

    -- --- SEÇÃO 6: GERENCIAMENTO DE GRUPOS ---
    local s6Header = rChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s6Header:SetPoint("TOPLEFT", defTimeLabel, "BOTTOMLEFT", 0, -14)
    s6Header:SetText("|cffffd2006. GERENCIAMENTO DE GRUPOS|r")

    local s6Sep = rChild:CreateTexture(nil, "ARTWORK")
    s6Sep:SetPoint("TOPLEFT", s6Header, "BOTTOMLEFT", 0, -3)
    s6Sep:SetPoint("RIGHT", rChild, "RIGHT", -4, 0)
    s6Sep:SetHeight(1)
    s6Sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    local cbConfirmGroup = createCheckbox(rChild, "Solicitar confirmação ao excluir grupos de masmorra/raide", "Segurança de Grupos", "Exige confirmação antes de remover um grupo criado.")
    cbConfirmGroup:SetPoint("TOPLEFT", s6Sep, "BOTTOMLEFT", 0, -4)
    self._widgets.confirmGroupDelete = cbConfirmGroup

    local cbAutoRole = createCheckbox(rChild, "Sugerir função automaticamente pela classe ao adicionar", "Função Automática", "Define Tanque, Cura ou Dano automaticamente com base na classe do personagem.")
    cbAutoRole:SetPoint("TOPLEFT", cbConfirmGroup, "BOTTOMLEFT", 0, -2)
    self._widgets.autoAssignGroupRole = cbAutoRole

    -- --- SEÇÃO 7: AUDITORIA & ROSTER DE MEMBROS ---
    local s7Header = rChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s7Header:SetPoint("TOPLEFT", cbAutoRole, "BOTTOMLEFT", 2, -12)
    s7Header:SetText("|cffffd2007. AUDITORIA & ROSTER DE MEMBROS|r")

    local s7Sep = rChild:CreateTexture(nil, "ARTWORK")
    s7Sep:SetPoint("TOPLEFT", s7Header, "BOTTOMLEFT", 0, -3)
    s7Sep:SetPoint("RIGHT", rChild, "RIGHT", -4, 0)
    s7Sep:SetHeight(1)
    s7Sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    local cbAutoScan = createCheckbox(rChild, "Varredura automática ao conectar e em eventos da guilda", "Auto Varredura", "Sincroniza membros e cargos da guilda automaticamente em segundo plano.")
    cbAutoScan:SetPoint("TOPLEFT", s7Sep, "BOTTOMLEFT", 0, -4)
    self._widgets.autoScanRoster = cbAutoScan

    local cbOffline = createCheckbox(rChild, "Exibir membros desconectados na auditoria por padrão", "Membros Offline", "Mantém os membros offline visíveis na lista de auditoria.")
    cbOffline:SetPoint("TOPLEFT", cbAutoScan, "BOTTOMLEFT", 0, -2)
    self._widgets.showOfflineMembers = cbOffline

    local cbNotifyRecruit = createCheckbox(rChild, "Avisar no chat local quando um novo jogador for recrutado", "Aviso de Recrutamento", "Envia mensagem informativa amigável no chat quando novos membros entram.")
    cbNotifyRecruit:SetPoint("TOPLEFT", cbOffline, "BOTTOMLEFT", 0, -2)
    self._widgets.notifyNewRecruit = cbNotifyRecruit

    local cbNotifyLevel = createCheckbox(rChild, "Avisar no chat local quando um membro subir de nível", "Aviso de Nível", "Envia mensagem no chat local quando um colega de guilda ganha nível.")
    cbNotifyLevel:SetPoint("TOPLEFT", cbNotifyRecruit, "BOTTOMLEFT", 0, -2)
    self._widgets.notifyMemberLevelUp = cbNotifyLevel

    -- --- SEÇÃO 8: REGISTRO DE EVENTOS (LOGS) ---
    local s8Header = rChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s8Header:SetPoint("TOPLEFT", cbNotifyLevel, "BOTTOMLEFT", 2, -12)
    s8Header:SetText("|cffffd2008. REGISTRO DE EVENTOS (LOGS)|r")

    local s8Sep = rChild:CreateTexture(nil, "ARTWORK")
    s8Sep:SetPoint("TOPLEFT", s8Header, "BOTTOMLEFT", 0, -3)
    s8Sep:SetPoint("RIGHT", rChild, "RIGHT", -4, 0)
    s8Sep:SetHeight(1)
    s8Sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    local cbLvl = createCheckbox(rChild, "Registrar quando membros subirem de nível", "Log de Nível", "Grava registro histórico quando qualquer membro da guilda ganha um nível.")
    cbLvl:SetPoint("TOPLEFT", s8Sep, "BOTTOMLEFT", 0, -4)
    self._widgets.logLevelUp = cbLvl

    local cbPromote = createCheckbox(rChild, "Registrar promoções e rebaixamentos de cargo", "Log de Cargos", "Grava quando alguém tem cargo alterado, identificando quem alterou.")
    cbPromote:SetPoint("TOPLEFT", cbLvl, "BOTTOMLEFT", 0, -2)
    self._widgets.logPromoteDemote = cbPromote

    local cbNotes = createCheckbox(rChild, "Registrar alterações em notas públicas e de oficial", "Log de Notas", "Grava modificações de notas personalizadas da guilda.")
    cbNotes:SetPoint("TOPLEFT", cbPromote, "BOTTOMLEFT", 0, -2)
    self._widgets.logNotes = cbNotes

    local cbJoinLeave = createCheckbox(rChild, "Registrar entradas, saídas e expulsões da guilda", "Log de Admissão/Saída", "Grava entradas, saídas voluntárias e expulsões de jogadores.")
    cbJoinLeave:SetPoint("TOPLEFT", cbNotes, "BOTTOMLEFT", 0, -2)
    self._widgets.logJoinLeave = cbJoinLeave

    local cbRejoin = createCheckbox(rChild, "Registrar retorno à guilda (jogadores que já saíram)", "Log de Reingresso", "Grava quando um membro que já fez parte da guilda retorna, mantendo histórico prévio.")
    cbRejoin:SetPoint("TOPLEFT", cbJoinLeave, "BOTTOMLEFT", 0, -2)
    self._widgets.logRejoin = cbRejoin

    local retLabel = rChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    retLabel:SetPoint("TOPLEFT", cbRejoin, "BOTTOMLEFT", 4, -6)
    retLabel:SetText("Retenção máxima de histórico de logs:")

    local retentionDefs = {
        { days = 30,  label = "30 Dias" },
        { days = 60,  label = "60 Dias" },
        { days = 90,  label = "90 Dias" },
        { days = 0,   label = "Ilimitado" },
    }
    local retentionButtons = {}
    for i, rDef in ipairs(retentionDefs) do
        local btn = CreateFrame("Button", nil, rChild, template)
        btn:SetSize(82, 20)
        btn:SetPoint("TOPLEFT", retLabel, "BOTTOMLEFT", (i - 1) * 88, -3)
        if btn.SetBackdrop then btn:SetBackdrop(SUB_CONTAINER_BACKDROP) end
        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("CENTER", btn, "CENTER", 0, 0)
        txt:SetText(rDef.label)
        btn.txt = txt
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
    s9Header:SetText("|cffffd2009. SEGURANÇA & MANUTENÇÃO|r")

    local s9Sep = rChild:CreateTexture(nil, "ARTWORK")
    s9Sep:SetPoint("TOPLEFT", s9Header, "BOTTOMLEFT", 0, -3)
    s9Sep:SetPoint("RIGHT", rChild, "RIGHT", -4, 0)
    s9Sep:SetHeight(1)
    s9Sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], 0.6)

    -- Botões de Ação do Banco
    local purgeBtn = CreateFrame("Button", nil, rChild, "UIPanelButtonTemplate")
    purgeBtn:SetSize(170, 22)
    purgeBtn:SetPoint("TOPLEFT", s9Sep, "BOTTOMLEFT", 4, -8)
    purgeBtn:SetText("Limpar Logs Antigos")
    purgeBtn:SetScript("OnClick", function()
        if self._onPurgeLogsCallback then
            self._onPurgeLogsCallback()
        end
    end)

    local forceScanBtn = CreateFrame("Button", nil, rChild, "UIPanelButtonTemplate")
    forceScanBtn:SetSize(170, 22)
    forceScanBtn:SetPoint("LEFT", purgeBtn, "RIGHT", 10, 0)
    forceScanBtn:SetText("Forçar Varredura Agora")
    forceScanBtn:SetScript("OnClick", function()
        if self._onForceScanCallback then
            self._onForceScanCallback()
        end
    end)

    local resetAllBtn = CreateFrame("Button", nil, rChild, "UIPanelButtonTemplate")
    resetAllBtn:SetSize(170, 22)
    resetAllBtn:SetPoint("TOPLEFT", purgeBtn, "BOTTOMLEFT", 0, -6)
    resetAllBtn:SetText("Restaurar Padrões")
    resetAllBtn:SetScript("OnClick", function()
        if self._onResetCallback then
            self._onResetCallback()
        end
    end)
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
    hint:SetText("|cff666666GuildManager v0.1 • Configurações & Personalização|r")

    local statusMsg = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusMsg:SetPoint("CENTER", frame, "BOTTOM", -50, 22)
    statusMsg:SetText("")
    self._widgets.statusMsg = statusMsg

    local saveBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveBtn:SetSize(150, 24)
    saveBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -120, 10)
    saveBtn:SetText("Salvar Informações")
    saveBtn:SetScript("OnClick", function()
        if self._onSaveCallback then
            self._onSaveCallback(self:gatherFormData())
        end
    end)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(90, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 10)
    closeBtn:SetText("Fechar")
    closeBtn:SetScript("OnClick", function() self:hide() end)
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

--- Preenche a interface com os valores atuais de Settings e estatísticas.
---@param settings GMSettings
---@param stats table
function SettingsView:renderSettings(settings, stats)
    if not self._frame or not settings then return end

    -- Estatísticas da Guilda
    if stats then
        self._widgets.gNameText:SetText(string.format("|cffffd200<%s>|r", stats.guildName or "Guilda"))
        self._widgets.gStatsText:SetText(string.format(
            "|cffaaaaaaMembros: |cffffff00%d|r  •  Grupos: |cffffff00%d|r  •  Logs: |cffffff00%d|r  •  v%s|r",
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
    self._widgets.sliderLabel:SetText(string.format("Posição Orbital do Minimapa: %d°", mPos))

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
    self._widgets.notifyMemberLevelUp:SetChecked(settings:isNotifyMemberLevelUp())

    -- Logs
    self._widgets.logLevelUp:SetChecked(settings:isLogLevelUp())
    self._widgets.logPromoteDemote:SetChecked(settings:isLogPromoteDemote())
    self._widgets.logNotes:SetChecked(settings:isLogNotes())
    self._widgets.logJoinLeave:SetChecked(settings:isLogJoinLeave())
    self._widgets.logRejoin:SetChecked(settings:isLogRejoin())
    self._widgets.selectedRetentionDays = settings:getLogRetentionDays()
    self:updateRetentionButtons(self._widgets.retentionButtons, self._widgets.selectedRetentionDays)

    self._widgets.statusMsg:SetText("")
end

--- Coleta os valores dos controles da tela em uma tabela.
---@return table
function SettingsView:gatherFormData()
    local w = self._widgets
    return {
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
        notifyMemberLevelUp = w.notifyMemberLevelUp:GetChecked() == true,
        logLevelUp = w.logLevelUp:GetChecked() == true,
        logPromoteDemote = w.logPromoteDemote:GetChecked() == true,
        logNotes = w.logNotes:GetChecked() == true,
        logJoinLeave = w.logJoinLeave:GetChecked() == true,
        logRejoin = w.logRejoin:GetChecked() == true,
        logRetentionDays = tonumber(w.selectedRetentionDays) or 60,
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
