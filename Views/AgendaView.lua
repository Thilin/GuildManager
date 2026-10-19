local addonName, addonTable = ...
local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })

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

local TYPE_THEMES = {
    RAID = {
        label     = "[Raide]",
        shortTag  = "Raide",
        colorCode = "|cffff4040",
        border    = { 0.85, 0.22, 0.22, 0.95 },
        bg        = { 0.16, 0.03, 0.03, 0.88 },
    },
    DUNGEON = {
        label     = "[Masmorra]",
        shortTag  = "Masm",
        colorCode = "|cff38a8ff",
        border    = { 0.20, 0.60, 0.95, 0.95 },
        bg        = { 0.02, 0.08, 0.16, 0.88 },
    },
    PVP = {
        label     = "[JxJ / PvP]",
        shortTag  = "PvP",
        colorCode = "|cffff8800",
        border    = { 0.95, 0.52, 0.10, 0.95 },
        bg        = { 0.16, 0.07, 0.02, 0.88 },
    },
    REUNIAO = {
        label     = "[Reunião]",
        shortTag  = "Reunião",
        colorCode = "|cff00e872",
        border    = { 0.15, 0.82, 0.45, 0.95 },
        bg        = { 0.02, 0.14, 0.06, 0.88 },
    },
    ANIVERSARIO = {
        label     = "[Aniversário]",
        shortTag  = "Aniv",
        colorCode = "|cffffd200",
        border    = { 0.95, 0.80, 0.15, 0.95 },
        bg        = { 0.16, 0.12, 0.02, 0.88 },
    },
    PROMO = {
        label     = "[Promoção]",
        shortTag  = "Promo",
        colorCode = "|cff00e5ff",
        border    = { 0.15, 0.78, 0.92, 0.95 },
        bg        = { 0.02, 0.11, 0.16, 0.88 },
    },
    OUTRO = {
        label     = "[Outro]",
        shortTag  = "Outro",
        colorCode = "|cffa888db",
        border    = { 0.65, 0.50, 0.85, 0.90 },
        bg        = { 0.08, 0.05, 0.12, 0.88 },
    },
}

-- Compatibilidade retroativa com TYPE_BADGES
local TYPE_BADGES = setmetatable({}, {
    __index = function(_, k)
        local t = TYPE_THEMES[k] or TYPE_THEMES.OUTRO
        return { label = t.label, color = t.colorCode }
    end
})

local MONTH_NAMES_PT = {
    "JANEIRO", "FEVEREIRO", "MARÇO", "ABRIL", "MAIO", "JUNHO",
    "JULHO", "AGOSTO", "SETEMBRO", "OUTUBRO", "NOVEMBRO", "DEZEMBRO"
}
local MONTH_NAMES_EN = {
    "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
    "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
}
local WEEKDAYS_PT = { "DOM", "SEG", "TER", "QUA", "QUI", "SEX", "SÁB" }
local WEEKDAYS_EN = { "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" }

local function getDaysInMonth(year, month)
    local daysPerMonth = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if month == 2 then
        if (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0) then
            return 29
        else
            return 28
        end
    end
    return daysPerMonth[month] or 30
end

local function getFirstWeekdayOfMonth(year, month)
    if time and date then
        local t = time({ year = year, month = month, day = 1, hour = 12, min = 0, sec = 0 })
        local d = date("*t", t)
        return (d and d.wday) or 1
    end
    local t = { 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 }
    local y = year
    if month < 3 then y = y - 1 end
    local w = (y + math.floor(y/4) - math.floor(y/100) + math.floor(y/400) + t[month] + 1) % 7
    return w + 1
end

local function normalizeDate(dateStr)
    if not dateStr or type(dateStr) ~= "string" then return nil end
    local clean = dateStr:match("^%s*(.-)%s*$")
    if clean == "" then return nil end

    local y, m, d = clean:match("^(%d%d%d%d)[/%-%.](%d%d?)[/%-%.](%d%d?)$")
    if y and m and d then
        return string.format("%04d-%02d-%02d", tonumber(y), tonumber(m), tonumber(d)), tonumber(m), tonumber(d), tonumber(y)
    end

    d, m, y = clean:match("^(%d%d?)[/%-%.](%d%d?)[/%-%.](%d%d%d%d)$")
    if d and m and y then
        return string.format("%04d-%02d-%02d", tonumber(y), tonumber(m), tonumber(d)), tonumber(m), tonumber(d), tonumber(y)
    end

    return nil
end

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
    instance._upcomingPromotions = {}
    instance._currentFilterType = "TODOS"
    instance._currentSearchText = ""
    instance._activeEventCardPool = {}
    instance._activeBirthdayCardPool = {}
    instance._selectedDayCardPool = {}
    instance._selectedDayBirthdayPool = {}
    instance._selectedDayPromoPool = {}
    instance._upcomingFeedCardPool = {}
    instance._eventService = nil

    local curDate = (date and date("*t")) or (os and os.date and os.date("*t")) or { year = 2026, month = 10, day = 19 }
    instance._calendarYear = curDate.year or 2026
    instance._calendarMonth = curDate.month or 10
    instance._selectedDate = {
        year = curDate.year or 2026,
        month = curDate.month or 10,
        day = curDate.day or 19,
    }
    instance._calendarDayCells = {}

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
    instance._onPromoteMemberCallback = nil

    -- Modais
    instance._eventModal = nil
    instance._inviteeModal = nil
    instance._guildMembers = {}

    instance:createUI()

    return instance
end

function AgendaView:setEventService(service)
    self._eventService = service
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
function AgendaView:setOnPromoteMemberCallback(cb) self._onPromoteMemberCallback = cb end

function AgendaView:setUpcomingPromotions(promotions)
    self._upcomingPromotions = promotions or {}
    self:renderEvents()
end

function AgendaView:setGuildMembers(members)
    self._guildMembers = members or {}
end

function AgendaView:getGuildMembers()
    if self._guildMembers and #self._guildMembers > 0 then
        return self._guildMembers
    end
    if _G.GuildManager and _G.GuildManager.memberService then
        local all = _G.GuildManager.memberService:getAllMembers() or {}
        local active = {}
        for _, m in ipairs(all) do
            if m:isInGuild() then
                table.insert(active, m)
            end
        end
        if #active > 0 then
            self._guildMembers = active
            return self._guildMembers
        end
    end
    return self._guildMembers or {}
end

function AgendaView:getFrame()
    return self._frame
end

function AgendaView:isShown()
    return self._frame and self._frame:IsShown()
end

--- Atualiza dinamicamente todos os textos da interface de agenda.
function AgendaView:updateLocale()
    local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
    if not self._frame then return end

    if self._titleText then self._titleText:SetText(L["AGENDA_TITLE"]) end
    if self._subtitleText then self._subtitleText:SetText(L["AGENDA_SUBTITLE"]) end
    if self._eventsHeaderTitle then self._eventsHeaderTitle:SetText(L["AGENDA_CALENDAR_HEADER"] or L["AGENDA_EVENTS_HEADER"]) end
    if self._birthdaysHeaderTitle then self._birthdaysHeaderTitle:SetText(L["AGENDA_UPCOMING_HEADER"] or L["AGENDA_BIRTHDAYS_HEADER"]) end
    if self._emptyBirthdaysText then self._emptyBirthdaysText:SetText(L["AGENDA_NO_UPCOMING"] or L["AGENDA_EMPTY_BIRTHDAYS"]) end
    if self._todayBtn then self._todayBtn:SetText(L["AGENDA_TODAY_BTN"] or "Hoje") end
    if self._newEventOnDayBtn then self._newEventOnDayBtn:SetText(L["AGENDA_NEW_EVENT_DAY_BTN"] or "+ Novo Evento nesta data") end

    self:updateEventModalLocale()
    self:updateInviteeModalLocale()

    self:renderEvents()
    self:renderBirthdays()
end

--- Atualiza textos da modal de criação/edição de evento.
function AgendaView:updateEventModalLocale()
    local modal = self._eventModal
    if not modal then return end
    local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })

    if modal.mTitle then
        modal.mTitle:SetText(modal.editingEventId and L["EVENT_EDIT_TITLE"] or L["EVENT_CREATE_TITLE"])
    end
    if modal.titleLabel then modal.titleLabel:SetText(L["EVENT_TITLE_LABEL"]) end
    if modal.typeLabel then modal.typeLabel:SetText(L["EVENT_TYPE_LABEL"]) end
    if modal.dateLabel then modal.dateLabel:SetText(L["EVENT_DATE_LABEL"]) end
    if modal.timeLabel then modal.timeLabel:SetText(L["EVENT_TIME_LABEL"]) end
    if modal.descLabel then modal.descLabel:SetText(L["EVENT_DESC_LABEL"]) end
    if modal.saveBtn then modal.saveBtn:SetText(L["EVENT_SAVE_BTN"]) end
    if modal.cancelBtn then modal.cancelBtn:SetText(L["CANCEL"]) end

    if modal.typeButtons and modal.typeDefs then
        for _, tDef in ipairs(modal.typeDefs) do
            local btn = modal.typeButtons[tDef.id]
            if btn and btn.bText then
                btn.bText:SetText(L[tDef.labelKey] or tDef.labelKey)
            end
        end
    end
end

--- Atualiza textos da modal de gerenciamento de convidados.
function AgendaView:updateInviteeModalLocale()
    local modal = self._inviteeModal
    if not modal then return end
    local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })

    if modal.mTitle then modal.mTitle:SetText(L["EVENT_INVITEES_TITLE"]) end
    if modal.mSubtitle and not modal.currentEvent then
        modal.mSubtitle:SetText(L["EVENT_INVITEES_SUB"])
    end
    if modal.inviteAllBtn then modal.inviteAllBtn:SetText(L["EVENT_INVITE_ONLINE_BTN"] or L["EVENT_INVITE_GROUP_BTN"]) end
    if modal.addLabel then modal.addLabel:SetText(L["EVENT_ADD_INVITEE_LABEL"]) end
    if modal.addSearchHint then modal.addSearchHint:SetText(L["EVENT_ADD_INVITEE_SEARCH"]) end
    if modal.addBtn then modal.addBtn:SetText(L["EVENT_ADD_INVITEE_BTN"]) end
    if modal.emptyInvText then modal.emptyInvText:SetText(L["EVENT_INVITEES_EMPTY"]) end
    if modal.bottomCloseBtn then modal.bottomCloseBtn:SetText(L["CLOSE"]) end
end

function AgendaView:show()
    if self._frame then
        self:updateLocale()
        self:updatePermissions()
        self._frame:Show()
    end
end

function AgendaView:hide()
    if self._frame then
        self._frame:Hide()
    end
end

--- Atualiza a permissão visual do botão de criação de eventos conforme o cargo do jogador.
function AgendaView:updatePermissions()
    local canOfficer = false
    if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
        canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
    elseif IsGuildLeader and IsGuildLeader() then
        canOfficer = true
    elseif CanEditOfficerNote and CanEditOfficerNote() then
        canOfficer = true
    end

    if self._newEventOnDayBtn then
        if self._newEventOnDayBtn.SetMotionScriptsWhileDisabled then
            self._newEventOnDayBtn:SetMotionScriptsWhileDisabled(true)
        end
        if canOfficer then
            self._newEventOnDayBtn:Enable()
            self._newEventOnDayBtn:SetAlpha(1.0)
        else
            self._newEventOnDayBtn:Disable()
            self._newEventOnDayBtn:SetAlpha(0.50)
        end
    end
end

--- Cria e estiliza a interface principal da Agenda.
function AgendaView:createUI()
    if self._frame then return end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "GuildManagerAgendaFrame", UIParent, template)
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
    titleText:SetText(L["AGENDA_TITLE"])
    self._titleText = titleText

    -- Subtítulo informativo
    local subtitleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitleText:SetPoint("LEFT", titleText, "RIGHT", 12, 0)
    subtitleText:SetText(L["AGENDA_SUBTITLE"])
    self._subtitleText = subtitleText

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
        local curL = (_G.GM and _G.GM.L) or _G.L or L
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
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd200" .. curL["TAB_AGENDA_TOOLTIP"] .. "|r")
        GameTooltip:AddLine("|cff888888" .. curL["TAB_CURRENT"] .. "|r", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(curL["TAB_AGENDA_TOOLTIP_DESC"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    tabAgenda:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Aba 5: Pedidos de Profissão & Artesãos
    local tabProf = CreateFrame("Button", "GM_AgendaSideTab_Professions", frame, template)
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
        if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841) end
        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
        self:hide()
        local profCtrl = (_G.GM and _G.GM.professionController) or _G.professionController
        if profCtrl then
            profCtrl:show()
            local pFrame = (_G.GM and _G.GM.professionView and _G.GM.professionView.getFrame and _G.GM.professionView:getFrame()) or (profCtrl._professionView and profCtrl._professionView:getFrame())
            if pFrame and point then
                pFrame:ClearAllPoints()
                if relativeTo then pFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs) else pFrame:SetPoint(point, xOfs, yOfs) end
            end
        end
    end)

    -- Aba 6: Configurações
    local tabSettings = CreateFrame("Button", "GM_AgendaSideTab_Settings", frame, template)
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

    self._tabAudit = tabAudit
    self._tabLogs = tabLogs
    self._tabGroups = tabGroups
    self._tabAgenda = tabAgenda
    self._tabProf = tabProf
    self._tabSettings = tabSettings
end

--- Cria o painel esquerdo dedicado aos eventos da guilda com filtros e busca.
function AgendaView:createLeftPanel()
    local frame = self._frame
    if not frame then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    local leftPanel = CreateFrame("Frame", "GM_AgendaLeftPanel", frame, template)
    leftPanel:SetSize(612, 530)
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
    hTitle:SetText(L["AGENDA_EVENTS_HEADER"])
    self._eventsHeaderTitle = hTitle

    local hCount = headerBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hCount:SetPoint("LEFT", hTitle, "RIGHT", 8, 0)
    hCount:SetText("|cffaaaaaa(0 eventos)|r")
    self._eventsCountText = hCount

    self._newEventBtn = nil

    -- Barra de ferramentas com Filtros por tipo e Caixa de Busca
    local toolbar = CreateFrame("Frame", nil, leftPanel, template)
    toolbar:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -4)
    toolbar:SetPoint("TOPRIGHT", headerBar, "BOTTOMRIGHT", 0, -4)
    toolbar:SetHeight(32)

    -- Botões de filtro rápido
    local filterButtons = {}
    local filterDefs = {
        { id = "TODOS",       label = "Todos",     width = 48 },
        { id = "RAID",        label = "Raides",    width = 52 },
        { id = "DUNGEON",     label = "Masmorras", width = 64 },
        { id = "PVP",         label = "PvP",       width = 40 },
        { id = "REUNIAO",     label = "Reunião",   width = 54 },
        { id = "ANIVERSARIO", label = "Aniv.",      width = 48 },
        { id = "PROMO",       label = "Promo",     width = 50 },
    }

    local startX = 4
    for _, fDef in ipairs(filterDefs) do
        local btn = CreateFrame("Button", nil, toolbar, template)
        local btnWidth = fDef.width or 56
        btn:SetSize(btnWidth, 22)
        btn:SetPoint("LEFT", toolbar, "LEFT", startX, 0)
        startX = startX + btnWidth + 4

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

    -- =========================================================================
    -- CARD DO CALENDÁRIO MENSAL
    -- =========================================================================
    local calendarCard = CreateFrame("Frame", "GM_AgendaCalendarCard", leftPanel, template)
    calendarCard:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 2, -4)
    calendarCard:SetPoint("TOPRIGHT", toolbar, "BOTTOMRIGHT", -2, -4)
    calendarCard:SetHeight(246)
    if calendarCard.SetBackdrop then
        calendarCard:SetBackdrop(SUB_CONTAINER_BACKDROP)
        calendarCard:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.85)
        calendarCard:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.90)
    end
    self._calendarCard = calendarCard

    -- Barra de Navegação do Mês ( < Mês Ano > [Hoje] )
    local navBar = CreateFrame("Frame", nil, calendarCard, template)
    navBar:SetPoint("TOPLEFT", calendarCard, "TOPLEFT", 4, -4)
    navBar:SetPoint("TOPRIGHT", calendarCard, "TOPRIGHT", -4, -4)
    navBar:SetHeight(26)

    local prevMonthBtn = CreateFrame("Button", nil, navBar, "UIPanelButtonTemplate")
    prevMonthBtn:SetSize(28, 22)
    prevMonthBtn:SetPoint("LEFT", navBar, "LEFT", 4, 0)
    prevMonthBtn:SetText("<")
    prevMonthBtn:SetScript("OnClick", function()
        self:changeMonth(-1)
    end)
    self._prevMonthBtn = prevMonthBtn

    local nextMonthBtn = CreateFrame("Button", nil, navBar, "UIPanelButtonTemplate")
    nextMonthBtn:SetSize(28, 22)
    nextMonthBtn:SetPoint("LEFT", prevMonthBtn, "RIGHT", 4, 0)
    nextMonthBtn:SetText(">")
    nextMonthBtn:SetScript("OnClick", function()
        self:changeMonth(1)
    end)
    self._nextMonthBtn = nextMonthBtn

    local todayBtn = CreateFrame("Button", nil, navBar, "UIPanelButtonTemplate")
    todayBtn:SetSize(62, 22)
    todayBtn:SetPoint("RIGHT", navBar, "RIGHT", -4, 0)
    todayBtn:SetText(L["AGENDA_TODAY_BTN"] or "Hoje")
    todayBtn:SetScript("OnClick", function()
        local curDate = (date and date("*t")) or (os and os.date and os.date("*t")) or { year = 2026, month = 10, day = 19 }
        self._calendarYear = curDate.year or 2026
        self._calendarMonth = curDate.month or 10
        self._selectedDate = {
            year = curDate.year or 2026,
            month = curDate.month or 10,
            day = curDate.day or 19,
        }
        self:renderCalendar()
        self:renderSelectedDayEvents()
    end)
    self._todayBtn = todayBtn

    local monthTitle = navBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    monthTitle:SetPoint("CENTER", navBar, "CENTER", 0, 0)
    monthTitle:SetText("OUTUBRO 2026")
    self._calendarMonthTitle = monthTitle

    -- Cabeçalhos dos Dias da Semana (DOM - SÁB)
    local weekdayBar = CreateFrame("Frame", nil, calendarCard)
    weekdayBar:SetPoint("TOPLEFT", navBar, "BOTTOMLEFT", 4, -2)
    weekdayBar:SetPoint("TOPRIGHT", navBar, "BOTTOMRIGHT", -4, -2)
    weekdayBar:SetHeight(18)

    local colWidth = 84
    local colGap = 2
    local weekdayLabels = {}
    local isPT = true
    if _G.GM and _G.GM.settingsService and _G.GM.settingsService:get("language") == "enUS" then
        isPT = false
    end
    local wNames = isPT and WEEKDAYS_PT or WEEKDAYS_EN

    for col = 1, 7 do
        local wLabel = weekdayBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        wLabel:SetSize(colWidth, 18)
        wLabel:SetPoint("TOPLEFT", weekdayBar, "TOPLEFT", (col - 1) * (colWidth + colGap), 0)
        wLabel:SetJustifyH("CENTER")
        wLabel:SetText(wNames[col] or "")
        weekdayLabels[col] = wLabel
    end
    self._weekdayLabels = weekdayLabels

    -- Grid 6x7 = 42 células de dias
    local dayCells = {}
    local gridTopOffset = 48
    local rowHeight = 30
    local rowGap = 2

    for i = 1, 42 do
        local row = math.floor((i - 1) / 7)
        local col = (i - 1) % 7
        local cell = CreateFrame("Button", "GM_AgendaDayCell_" .. i, calendarCard, template)
        cell:SetSize(colWidth, rowHeight)
        cell:SetPoint("TOPLEFT", calendarCard, "TOPLEFT", 8 + col * (colWidth + colGap), -(gridTopOffset + row * (rowHeight + rowGap)))

        if cell.SetBackdrop then
            cell:SetBackdrop(SIDE_TAB_BACKDROP)
            cell:SetBackdropColor(PALETTE.INACTIVE_TAB_BG[1], PALETTE.INACTIVE_TAB_BG[2], PALETTE.INACTIVE_TAB_BG[3], 0.70)
            cell:SetBackdropBorderColor(PALETTE.INACTIVE_TAB_BORDER[1], PALETTE.INACTIVE_TAB_BORDER[2], PALETTE.INACTIVE_TAB_BORDER[3], 0.60)
        end

        local dayNum = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dayNum:SetPoint("TOPLEFT", cell, "TOPLEFT", 4, -3)
        cell.dayNum = dayNum

        local badge = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        badge:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -4, 3)
        badge:SetJustifyH("RIGHT")
        cell.badge = badge

        cell:SetScript("OnClick", function(btn)
            if btn.cellYear and btn.cellMonth and btn.cellDay then
                self:selectDate(btn.cellYear, btn.cellMonth, btn.cellDay)
            end
        end)

        cell:SetScript("OnDoubleClick", function(btn)
            if btn.cellYear and btn.cellMonth and btn.cellDay then
                self:selectDate(btn.cellYear, btn.cellMonth, btn.cellDay)
                local canOfficer = false
                if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
                    canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
                elseif IsGuildLeader and IsGuildLeader() then
                    canOfficer = true
                elseif CanEditOfficerNote and CanEditOfficerNote() then
                    canOfficer = true
                end
                if canOfficer then
                    local targetDate = string.format("%02d/%02d/%04d", btn.cellDay, btn.cellMonth, btn.cellYear)
                    self:openEventModal(nil, { date = targetDate })
                end
            end
        end)

        cell:SetScript("OnEnter", function(btn)
            local numEvents = (btn.cellEvents and #btn.cellEvents) or 0
            local numBdays = (btn.cellBirthdays and #btn.cellBirthdays) or 0
            local numPromos = (btn.cellPromotions and #btn.cellPromotions) or 0
            local total = numEvents + numBdays + numPromos

            if not GameTooltip then return end
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            local dtFmt = string.format("%02d/%02d/%04d", btn.cellDay or 1, btn.cellMonth or 1, btn.cellYear or 2026)

            if total == 0 then
                if btn.cellDay then
                    GameTooltip:AddLine("|cffffd200Data: " .. dtFmt .. "|r", 1, 1, 1)
                    GameTooltip:AddLine("|cff888888Clique para selecionar esta data.\nDuplo-clique para criar evento.|r", 0.7, 0.7, 0.7)
                    GameTooltip:Show()
                end
                return
            end

            GameTooltip:AddLine(string.format("|cffffd200Data: %s (%d itens)|r", dtFmt, total), 1, 1, 1)

            if numEvents > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cffffd200• Eventos da Guilda:|r", 1, 0.85, 0.0)
                for _, ev in ipairs(btn.cellEvents) do
                    local tDef = TYPE_THEMES[ev:getType()] or TYPE_THEMES.OUTRO
                    GameTooltip:AddLine(string.format("  %s %s |cffaaaaaa(às %s)|r", tDef.colorCode .. tDef.label .. "|r", ev:getTitle() or "", ev:getTime() or "20:00"), 1, 1, 1)
                end
            end

            if numBdays > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(TYPE_THEMES.ANIVERSARIO.colorCode .. "• Aniversários:|r", 1, 0.85, 0.0)
                for _, b in ipairs(btn.cellBirthdays) do
                    local rk = b.rank and b.rank ~= "" and (" • " .. b.rank) or ""
                    GameTooltip:AddLine(string.format("  %s %s |cff888888(Nv %d%s)|r", TYPE_THEMES.ANIVERSARIO.colorCode .. "•|r", getColoredName(b.cleanName or b.name, b.class), b.level or 1, rk), 1, 1, 1)
                end
            end

            if numPromos > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(TYPE_THEMES.PROMO.colorCode .. "• Promoções de Cargo:|r", 1, 0.85, 0.0)
                for _, p in ipairs(btn.cellPromotions) do
                    local st = p.isEligibleNow and "|cff00ff00[Elegível]|r" or string.format("|cffffff00[Meta: %d dias]|r", p.requiredDays or 0)
                    GameTooltip:AddLine(string.format("  %s %s ➔ |cffffd200%s|r %s", TYPE_THEMES.PROMO.colorCode .. "•|r", getColoredName(p.cleanName or p.name, p.class), p.targetRank or "", st), 1, 1, 1)
                end
            end

            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cff00ff00Clique para ver detalhes nesta data.\nDuplo-clique para criar novo evento.|r", 0.2, 1.0, 0.2)
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)

        dayCells[i] = cell
    end
    self._calendarDayCells = dayCells

    -- =========================================================================
    -- SEÇÃO INFERIOR: EVENTOS DO DIA SELECIONADO
    -- =========================================================================
    local selectedSection = CreateFrame("Frame", "GM_AgendaSelectedDaySection", leftPanel, template)
    selectedSection:SetPoint("TOPLEFT", calendarCard, "BOTTOMLEFT", 0, -6)
    selectedSection:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -2, 6)
    if selectedSection.SetBackdrop then
        selectedSection:SetBackdrop(SUB_CONTAINER_BACKDROP)
        selectedSection:SetBackdropColor(0.04, 0.025, 0.012, 0.85)
        selectedSection:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.90)
    end
    self._selectedSection = selectedSection

    -- Subheader do Dia Selecionado
    local subHeader = CreateFrame("Frame", nil, selectedSection, template)
    subHeader:SetPoint("TOPLEFT", selectedSection, "TOPLEFT", 4, -4)
    subHeader:SetPoint("TOPRIGHT", selectedSection, "TOPRIGHT", -4, -4)
    subHeader:SetHeight(28)
    if subHeader.SetBackdrop then
        subHeader:SetBackdrop(SUB_CONTAINER_BACKDROP)
        subHeader:SetBackdropColor(0.10, 0.07, 0.03, 0.95)
        subHeader:SetBackdropBorderColor(0.55, 0.38, 0.14, 0.90)
    end

    local selTitle = subHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selTitle:SetPoint("LEFT", subHeader, "LEFT", 8, 0)
    selTitle:SetText("Eventos em 19/10/2026")
    self._selectedDayTitleText = selTitle

    local newEventOnDayBtn = CreateFrame("Button", nil, subHeader, "UIPanelButtonTemplate")
    newEventOnDayBtn:SetSize(185, 22)
    newEventOnDayBtn:SetPoint("RIGHT", subHeader, "RIGHT", -4, 0)
    newEventOnDayBtn:SetText(L["AGENDA_NEW_EVENT_DAY_BTN"] or "+ Novo Evento nesta data")
    if newEventOnDayBtn.SetMotionScriptsWhileDisabled then
        newEventOnDayBtn:SetMotionScriptsWhileDisabled(true)
    end
    newEventOnDayBtn:SetScript("OnEnter", function(btn)
        local canOfficer = false
        if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
            canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
        elseif IsGuildLeader and IsGuildLeader() then
            canOfficer = true
        elseif CanEditOfficerNote and CanEditOfficerNote() then
            canOfficer = true
        end

        if GameTooltip then
            local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
            GameTooltip:SetOwner(btn, "ANCHOR_TOP")
            GameTooltip:AddLine(curL["AGENDA_NEW_EVENT_DAY_BTN"] or "+ Novo Evento nesta data", 1, 1, 1)
            if not canOfficer then
                GameTooltip:AddLine(curL["EVENT_ERR_OFFICER_ONLY"] or "|cffff4444Apenas Oficiais ou o Líder da Guilda podem criar eventos da agenda.|r", 1, 0.3, 0.3, true)
            end
            GameTooltip:Show()
        end
    end)
    newEventOnDayBtn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    newEventOnDayBtn:SetScript("OnClick", function()
        local canOfficer = false
        if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
            canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
        elseif IsGuildLeader and IsGuildLeader() then
            canOfficer = true
        elseif CanEditOfficerNote and CanEditOfficerNote() then
            canOfficer = true
        end

        if not canOfficer then
            print("|cffff4444[GuildManager]|r Apenas Oficiais ou o Líder da Guilda podem criar eventos da agenda.")
            return
        end

        local sel = self._selectedDate or { year = self._calendarYear or 2026, month = self._calendarMonth or 10, day = 1 }
        local targetDate = string.format("%02d/%02d/%04d", sel.day, sel.month, sel.year)
        self:openEventModal(nil, { date = targetDate })
    end)
    self._newEventOnDayBtn = newEventOnDayBtn

    -- ScrollFrame dos Eventos do Dia Selecionado
    local scrollFrame = CreateFrame("ScrollFrame", "GM_AgendaSelectedEventsScroll", selectedSection, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", subHeader, "BOTTOMLEFT", 2, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", selectedSection, "BOTTOMRIGHT", -22, 4)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(572)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    self._eventsScrollChild = scrollChild

    selectedSection:EnableMouseWheel(true)
    selectedSection:SetScript("OnMouseWheel", function(_, delta)
        local cur = scrollFrame:GetVerticalScroll()
        scrollFrame:SetVerticalScroll(math.max(0, cur - (delta * 30)))
    end)

    local emptyEventsText = selectedSection:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyEventsText:SetPoint("CENTER", selectedSection, "CENTER", 0, -10)
    emptyEventsText:SetWidth(460)
    emptyEventsText:SetJustifyH("CENTER")
    emptyEventsText:SetText(L["AGENDA_EMPTY_EVENTS"])
    emptyEventsText:Hide()
    self._emptyEventsText = emptyEventsText
end

--- Atualiza a estética visual dos botões de filtro
function AgendaView:updateFilterButtonsUI(buttons)
    for id, btn in pairs(buttons or {}) do
        local isActive = (self._currentFilterType == id)
        local theme = TYPE_THEMES[id] or {
            border = PALETTE.ACTIVE_TAB_BORDER,
            bg = PALETTE.ACTIVE_TAB_BG,
            colorCode = "|cffffd200",
        }
        if btn.SetBackdrop then
            if isActive then
                btn:SetBackdropColor(theme.bg[1], theme.bg[2], theme.bg[3], 0.95)
                btn:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1.0)
                if btn.bText then btn.bText:SetTextColor(theme.border[1], theme.border[2], theme.border[3]) end
            else
                btn:SetBackdropColor(PALETTE.INACTIVE_TAB_BG[1], PALETTE.INACTIVE_TAB_BG[2], PALETTE.INACTIVE_TAB_BG[3], 0.80)
                btn:SetBackdropBorderColor(PALETTE.INACTIVE_TAB_BORDER[1], PALETTE.INACTIVE_TAB_BORDER[2], PALETTE.INACTIVE_TAB_BORDER[3], 0.80)
                if btn.bText then btn.bText:SetTextColor(0.75, 0.75, 0.75) end
            end
        end
    end
end

--- Cria o painel direito dedicado aos próximos eventos da guilda (Eventos, Aniversários e Promoções).
function AgendaView:createRightPanel()
    local frame = self._frame
    if not frame then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })

    local rightPanel = CreateFrame("Frame", "GM_AgendaRightPanel", frame, template)
    rightPanel:SetSize(294, 530)
    rightPanel:SetPoint("TOPLEFT", self._leftPanel, "TOPRIGHT", 8, 0)
    if rightPanel.SetBackdrop then
        rightPanel:SetBackdrop(CONTAINER_BACKDROP)
        rightPanel:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        rightPanel:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end
    self._rightPanel = rightPanel

    -- Header do painel de Próximos Eventos
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
    local okH = hIcon:SetTexture("Interface\\Calendar\\UI-Calendar-Button")
    if okH ~= false and hIcon:GetTexture() then
        hIcon:SetTexCoord(0.0078, 0.375, 0.0156, 0.75)
    else
        hIcon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
        hIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    local hTitle = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hTitle:SetPoint("LEFT", hIcon, "RIGHT", 8, 0)
    hTitle:SetText(L["AGENDA_UPCOMING_HEADER"] or "PRÓXIMOS EVENTOS")
    self._birthdaysHeaderTitle = hTitle
    self._birthdaysHeaderSub = nil

    -- ScrollFrame do feed unificado de Próximos Eventos
    local scrollFrame = CreateFrame("ScrollFrame", "GM_AgendaBirthdaysScroll", rightPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 2, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -24, 6)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(262)
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
    emptyBirthdaysText:SetWidth(250)
    emptyBirthdaysText:SetJustifyH("CENTER")
    emptyBirthdaysText:SetText(L["AGENDA_NO_UPCOMING"] or "Nenhum evento, aniversário ou promoção próxima.")
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
    self:renderUpcomingFeed()
end

--- Alterna o mês exibido no calendário.
---@param delta number
function AgendaView:changeMonth(delta)
    local m = self._calendarMonth + delta
    local y = self._calendarYear
    if m < 1 then
        m = 12
        y = y - 1
    elseif m > 12 then
        m = 1
        y = y + 1
    end
    self._calendarMonth = m
    self._calendarYear = y
    self:renderCalendar()
    self:renderSelectedDayEvents()
end

--- Seleciona uma data no calendário.
---@param year number
---@param month number
---@param day number
function AgendaView:selectDate(year, month, day)
    self._selectedDate = { year = year, month = month, day = day }
    self:renderCalendar()
    self:renderSelectedDayEvents()
end

--- Obtém aniversariantes para o mês e ano fornecidos.
function AgendaView:getMonthBirthdays(year, month)
    if self._eventService and self._eventService.getBirthdaysForMonth then
        return self._eventService:getBirthdaysForMonth(year, month) or {}
    end
    local results = {}
    local members = self:getGuildMembers()
    for _, m in ipairs(members or {}) do
        local bdayStr = m:getBirthday()
        if bdayStr and bdayStr ~= "" then
            local cleanStr = bdayStr:match("^%s*(.-)%s*$")
            local pMonth, pDay = nil, nil
            local y, mo, d = cleanStr:match("^(%d%d%d%d)[/%-%.](%d%d?)[/%-%.](%d%d?)$")
            if mo and d then pMonth, pDay = mo, d else
                d, mo, y = cleanStr:match("^(%d%d?)[/%-%.](%d%d?)[/%-%.](%d%d%d%d)$")
                if mo and d then pMonth, pDay = mo, d else
                    pMonth, pDay = cleanStr:match("^(%d%d?)[/%-%.](%d%d?)$")
                end
            end
            if pMonth and pDay then
                local bm, bd = tonumber(pMonth), tonumber(pDay)
                if bm and bd then
                    if bm > 12 and bd <= 12 then bm, bd = bd, bm end
                    if bm == month and bd >= 1 and bd <= 31 then
                        local rawName = m:getName() or "Membro"
                        local cleanName = rawName:match("^[^-]+") or rawName
                        table.insert(results, {
                            member = m,
                            name = rawName,
                            cleanName = cleanName,
                            class = m:getClass() or "",
                            level = m:getLevel() or 1,
                            rank = m:getRankName() or "",
                            day = bd,
                            month = bm,
                            year = year,
                            birthday = string.format("%02d/%02d", bm, bd),
                            dateStr = string.format("%02d/%02d/%04d", bd, bm, year),
                            dateKey = string.format("%04d-%02d-%02d", year, bm, bd),
                        })
                    end
                end
            end
        end
    end
    return results
end

--- Obtém promoções para o mês e ano fornecidos.
function AgendaView:getMonthPromotions(year, month)
    if self._eventService and self._eventService.getPromotionsForMonth then
        return self._eventService:getPromotionsForMonth(year, month) or {}
    end
    return {}
end

--- Renderiza o grid de 42 células do calendário mensal.
function AgendaView:renderCalendar()
    if not self._calendarDayCells or #self._calendarDayCells == 0 then return end

    local curDate = (date and date("*t")) or (os and os.date and os.date("*t")) or { year = 2026, month = 10, day = 19 }
    local year = self._calendarYear or curDate.year or 2026
    local month = self._calendarMonth or curDate.month or 10

    local isPT = true
    if _G.GM and _G.GM.settingsService and _G.GM.settingsService:get("language") == "enUS" then
        isPT = false
    end

    local mNames = isPT and MONTH_NAMES_PT or MONTH_NAMES_EN
    local mName = mNames[month] or ("MÊS " .. month)
    if self._calendarMonthTitle then
        self._calendarMonthTitle:SetText(string.format("%s %d", mName, year))
    end

    local wNames = isPT and WEEKDAYS_PT or WEEKDAYS_EN
    if self._weekdayLabels then
        for col = 1, 7 do
            if self._weekdayLabels[col] then
                self._weekdayLabels[col]:SetText(wNames[col] or "")
            end
        end
    end

    local filterLower = self._currentFilterType or "TODOS"
    local searchLower = self._currentSearchText and self._currentSearchText:match("^%s*(.-)%s*$"):lower() or ""

    -- 1. Indexa eventos
    local eventsByDate = {}
    local totalMatchingEvents = 0
    if filterLower ~= "ANIVERSARIO" and filterLower ~= "PROMO" then
        for _, ev in ipairs(self._events or {}) do
            local matchType = (filterLower == "TODOS" or ev:getType() == filterLower)
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
                totalMatchingEvents = totalMatchingEvents + 1
                local norm = normalizeDate(ev:getDate())
                if norm then
                    eventsByDate[norm] = eventsByDate[norm] or {}
                    table.insert(eventsByDate[norm], ev)
                end
            end
        end
    end

    -- 2. Indexa aniversários do mês
    local birthdaysByDate = {}
    local totalMatchingBdays = 0
    if filterLower == "TODOS" or filterLower == "ANIVERSARIO" then
        local bdays = self:getMonthBirthdays(year, month)
        for _, b in ipairs(bdays) do
            local matchSearch = true
            if searchLower ~= "" then
                local n = (b.name or ""):lower()
                local cn = (b.cleanName or ""):lower()
                if not n:find(searchLower, 1, true) and not cn:find(searchLower, 1, true) then
                    matchSearch = false
                end
            end
            if matchSearch then
                totalMatchingBdays = totalMatchingBdays + 1
                birthdaysByDate[b.dateKey] = birthdaysByDate[b.dateKey] or {}
                table.insert(birthdaysByDate[b.dateKey], b)
            end
        end
    end

    -- 3. Indexa promoções do mês
    local promotionsByDate = {}
    local totalMatchingPromos = 0
    if filterLower == "TODOS" or filterLower == "PROMO" then
        local promos = self:getMonthPromotions(year, month)
        for _, p in ipairs(promos) do
            local matchSearch = true
            if searchLower ~= "" then
                local n = (p.name or ""):lower()
                local cn = (p.cleanName or ""):lower()
                local tr = (p.targetRank or ""):lower()
                if not n:find(searchLower, 1, true) and not cn:find(searchLower, 1, true) and not tr:find(searchLower, 1, true) then
                    matchSearch = false
                end
            end
            if matchSearch then
                totalMatchingPromos = totalMatchingPromos + 1
                promotionsByDate[p.dateKey] = promotionsByDate[p.dateKey] or {}
                table.insert(promotionsByDate[p.dateKey], p)
            end
        end
    end

    local totalMatching = totalMatchingEvents + totalMatchingBdays + totalMatchingPromos
    if self._eventsCountText then
        self._eventsCountText:SetText(string.format("|cffaaaaaa(%d itens)|r", totalMatching))
    end

    local firstWday = getFirstWeekdayOfMonth(year, month)
    local daysInCurMonth = getDaysInMonth(year, month)
    local prevM = (month == 1) and 12 or (month - 1)
    local prevY = (month == 1) and (year - 1) or year
    local daysInPrevMonth = getDaysInMonth(prevY, prevM)
    local nextM = (month == 12) and 1 or (month + 1)
    local nextY = (month == 12) and (year + 1) or year

    for i = 1, 42 do
        local cell = self._calendarDayCells[i]
        if cell then
            local cDay, cMonth, cYear, isCurrentMonth
            if i < firstWday then
                cDay = daysInPrevMonth - (firstWday - 1 - i)
                cMonth = prevM
                cYear = prevY
                isCurrentMonth = false
            elseif i < firstWday + daysInCurMonth then
                cDay = i - firstWday + 1
                cMonth = month
                cYear = year
                isCurrentMonth = true
            else
                cDay = i - (firstWday + daysInCurMonth) + 1
                cMonth = nextM
                cYear = nextY
                isCurrentMonth = false
            end

            cell.cellYear = cYear
            cell.cellMonth = cMonth
            cell.cellDay = cDay
            cell.isCurrentMonth = isCurrentMonth

            local dateKey = string.format("%04d-%02d-%02d", cYear, cMonth, cDay)
            local dayEvents = eventsByDate[dateKey] or {}
            local dayBdays = birthdaysByDate[dateKey] or {}
            local dayPromos = promotionsByDate[dateKey] or {}

            cell.cellEvents = dayEvents
            cell.cellBirthdays = dayBdays
            cell.cellPromotions = dayPromos

            cell.dayNum:SetText(tostring(cDay))

            local isToday = (cYear == (curDate.year or 2026) and cMonth == (curDate.month or 10) and cDay == (curDate.day or 19))
            local isSelected = (self._selectedDate and cYear == self._selectedDate.year and cMonth == self._selectedDate.month and cDay == self._selectedDate.day)

            if not isCurrentMonth then
                cell.dayNum:SetTextColor(0.40, 0.35, 0.28)
            elseif isToday then
                cell.dayNum:SetTextColor(1.0, 0.85, 0.1)
            else
                cell.dayNum:SetTextColor(0.95, 0.95, 0.95)
            end

            local totalCellItems = #dayEvents + #dayBdays + #dayPromos

            if cell.SetBackdropColor and cell.SetBackdropBorderColor then
                if isSelected then
                    cell:SetBackdropColor(0.28, 0.18, 0.06, 0.95)
                    cell:SetBackdropBorderColor(1.0, 0.82, 0.20, 1.0)
                elseif isToday then
                    cell:SetBackdropColor(0.18, 0.12, 0.05, 0.85)
                    cell:SetBackdropBorderColor(0.95, 0.65, 0.15, 0.90)
                elseif not isCurrentMonth then
                    cell:SetBackdropColor(0.02, 0.015, 0.008, 0.40)
                    cell:SetBackdropBorderColor(0.28, 0.18, 0.06, 0.35)
                elseif totalCellItems > 0 then
                    -- Cor sutil baseada no item principal do dia
                    local primaryTheme = nil
                    if #dayEvents > 0 then
                        primaryTheme = TYPE_THEMES[dayEvents[1]:getType()] or TYPE_THEMES.OUTRO
                    elseif #dayBdays > 0 then
                        primaryTheme = TYPE_THEMES.ANIVERSARIO
                    elseif #dayPromos > 0 then
                        primaryTheme = TYPE_THEMES.PROMO
                    end
                    if primaryTheme then
                        cell:SetBackdropColor(primaryTheme.bg[1], primaryTheme.bg[2], primaryTheme.bg[3], 0.70)
                        cell:SetBackdropBorderColor(primaryTheme.border[1], primaryTheme.border[2], primaryTheme.border[3], 0.75)
                    else
                        cell:SetBackdropColor(PALETTE.INACTIVE_TAB_BG[1], PALETTE.INACTIVE_TAB_BG[2], PALETTE.INACTIVE_TAB_BG[3], 0.70)
                        cell:SetBackdropBorderColor(PALETTE.INACTIVE_TAB_BORDER[1], PALETTE.INACTIVE_TAB_BORDER[2], PALETTE.INACTIVE_TAB_BORDER[3], 0.60)
                    end
                else
                    cell:SetBackdropColor(PALETTE.INACTIVE_TAB_BG[1], PALETTE.INACTIVE_TAB_BG[2], PALETTE.INACTIVE_TAB_BG[3], 0.70)
                    cell:SetBackdropBorderColor(PALETTE.INACTIVE_TAB_BORDER[1], PALETTE.INACTIVE_TAB_BORDER[2], PALETTE.INACTIVE_TAB_BORDER[3], 0.60)
                end
            end

            if totalCellItems > 0 then
                if #dayEvents > 0 and #dayBdays == 0 and #dayPromos == 0 then
                    if #dayEvents == 1 then
                        local ev = dayEvents[1]
                        local tDef = TYPE_THEMES[ev:getType()] or TYPE_THEMES.OUTRO
                        cell.badge:SetText(tDef.colorCode .. "• " .. (ev:getTime() or "20:00") .. "|r")
                    else
                        local firstType = dayEvents[1]:getType()
                        local same = true
                        for _, ev in ipairs(dayEvents) do
                            if ev:getType() ~= firstType then same = false; break end
                        end
                        if same then
                            local tDef = TYPE_THEMES[firstType] or TYPE_THEMES.OUTRO
                            cell.badge:SetText(string.format("%s• %d %s|r", tDef.colorCode, #dayEvents, tDef.shortTag))
                        else
                            local countsByType = {}
                            local order = {}
                            for _, ev in ipairs(dayEvents) do
                                local t = ev:getType() or "OUTRO"
                                if not countsByType[t] then
                                    countsByType[t] = 0
                                    table.insert(order, t)
                                end
                                countsByType[t] = countsByType[t] + 1
                            end
                            local evParts = {}
                            for _, t in ipairs(order) do
                                local tDef = TYPE_THEMES[t] or TYPE_THEMES.OUTRO
                                table.insert(evParts, string.format("%s•%d|r", tDef.colorCode, countsByType[t]))
                            end
                            cell.badge:SetText(table.concat(evParts, " "))
                        end
                    end
                elseif #dayBdays > 0 and #dayEvents == 0 and #dayPromos == 0 then
                    local bTheme = TYPE_THEMES.ANIVERSARIO
                    if #dayBdays == 1 then
                        local b = dayBdays[1]
                        local sName = b.cleanName:sub(1, 6)
                        cell.badge:SetText(string.format("%s• %s|r", bTheme.colorCode, sName))
                    else
                        cell.badge:SetText(string.format("%s• %d aniv|r", bTheme.colorCode, #dayBdays))
                    end
                elseif #dayPromos > 0 and #dayEvents == 0 and #dayBdays == 0 then
                    local pTheme = TYPE_THEMES.PROMO
                    if #dayPromos == 1 then
                        local p = dayPromos[1]
                        local sName = p.cleanName:sub(1, 6)
                        cell.badge:SetText(string.format("%s• %s|r", pTheme.colorCode, sName))
                    else
                        cell.badge:SetText(string.format("%s• %d promo|r", pTheme.colorCode, #dayPromos))
                    end
                else
                    local parts = {}
                    if #dayEvents > 0 then
                        local countsByType = {}
                        local order = {}
                        for _, ev in ipairs(dayEvents) do
                            local t = ev:getType() or "OUTRO"
                            if not countsByType[t] then
                                countsByType[t] = 0
                                table.insert(order, t)
                            end
                            countsByType[t] = countsByType[t] + 1
                        end
                        for _, t in ipairs(order) do
                            local tDef = TYPE_THEMES[t] or TYPE_THEMES.OUTRO
                            table.insert(parts, string.format("%s•%d|r", tDef.colorCode, countsByType[t]))
                        end
                    end
                    if #dayBdays > 0 then
                        table.insert(parts, string.format("%s•%d|r", TYPE_THEMES.ANIVERSARIO.colorCode, #dayBdays))
                    end
                    if #dayPromos > 0 then
                        table.insert(parts, string.format("%s•%d|r", TYPE_THEMES.PROMO.colorCode, #dayPromos))
                    end
                    cell.badge:SetText(table.concat(parts, " "))
                end
                cell.badge:Show()
            else
                cell.badge:Hide()
            end
        end
    end
end

--- Renderiza a lista de cards de eventos para a data selecionada no calendário.
function AgendaView:renderSelectedDayEvents()
    if not self._eventsScrollChild then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })

    for _, card in ipairs(self._selectedDayCardPool) do card:Hide() end
    for _, card in ipairs(self._selectedDayBirthdayPool) do card:Hide() end
    for _, card in ipairs(self._selectedDayPromoPool) do card:Hide() end

    local sel = self._selectedDate or { year = self._calendarYear or 2026, month = self._calendarMonth or 10, day = 1 }
    local selDateStr = string.format("%02d/%02d/%04d", sel.day, sel.month, sel.year)
    local selKey = string.format("%04d-%02d-%02d", sel.year, sel.month, sel.day)

    local filterLower = self._currentFilterType or "TODOS"
    local searchLower = self._currentSearchText and self._currentSearchText:match("^%s*(.-)%s*$"):lower() or ""

    -- 1. Eventos do dia
    local dayEvents = {}
    if filterLower ~= "ANIVERSARIO" and filterLower ~= "PROMO" then
        for _, ev in ipairs(self._events or {}) do
            local norm = normalizeDate(ev:getDate())
            if norm == selKey then
                local matchType = (filterLower == "TODOS" or ev:getType() == filterLower)
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
                    table.insert(dayEvents, ev)
                end
            end
        end
        table.sort(dayEvents, function(a, b) return (a:getTime() or "") < (b:getTime() or "") end)
    end

    -- 2. Aniversários do dia
    local dayBirthdays = {}
    if filterLower == "TODOS" or filterLower == "ANIVERSARIO" then
        local bdays = self:getMonthBirthdays(sel.year, sel.month)
        for _, b in ipairs(bdays) do
            if b.day == sel.day then
                local matchSearch = true
                if searchLower ~= "" then
                    local n = (b.name or ""):lower()
                    local cn = (b.cleanName or ""):lower()
                    if not n:find(searchLower, 1, true) and not cn:find(searchLower, 1, true) then
                        matchSearch = false
                    end
                end
                if matchSearch then
                    table.insert(dayBirthdays, b)
                end
            end
        end
    end

    -- 3. Promoções do dia
    local dayPromotions = {}
    if filterLower == "TODOS" or filterLower == "PROMO" then
        local promos = self:getMonthPromotions(sel.year, sel.month)
        for _, p in ipairs(promos) do
            if p.day == sel.day then
                local matchSearch = true
                if searchLower ~= "" then
                    local n = (p.name or ""):lower()
                    local cn = (p.cleanName or ""):lower()
                    local tr = (p.targetRank or ""):lower()
                    if not n:find(searchLower, 1, true) and not cn:find(searchLower, 1, true) and not tr:find(searchLower, 1, true) then
                        matchSearch = false
                    end
                end
                if matchSearch then
                    table.insert(dayPromotions, p)
                end
            end
        end
    end

    local totalItems = #dayEvents + #dayBirthdays + #dayPromotions

    if self._selectedDayTitleText then
        local baseTitle = string.format(L["AGENDA_SELECTED_DAY_HEADER"] or "Eventos em %s", selDateStr)
        local countStr = string.format("(%d atividade(s))", totalItems)
        self._selectedDayTitleText:SetText(string.format("%s |cffaaaaaa%s|r", baseTitle, countStr))
    end

    if totalItems == 0 then
        if self._emptyEventsText then
            self._emptyEventsText:SetText(L["AGENDA_NO_EVENTS_DAY"] or "Nenhum evento agendado para este dia.\nClique em + Novo Evento nesta data para criar.")
            self._emptyEventsText:Show()
        end
        self._eventsScrollChild:SetHeight(1)
        return
    end

    if self._emptyEventsText then self._emptyEventsText:Hide() end

    local gap = 4
    local totalY = 2

    local canOfficer = false
    if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
        canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
    elseif IsGuildLeader and IsGuildLeader() then
        canOfficer = true
    elseif CanEditOfficerNote and CanEditOfficerNote() then
        canOfficer = true
    end

    -- 1. Cards de Eventos
    local eventCardHeight = 76
    for idx, ev in ipairs(dayEvents) do
        local card = self._selectedDayCardPool[idx]
        if not card then
            card = CreateFrame("Frame", nil, self._eventsScrollChild, template)
            card:SetSize(566, eventCardHeight)
            if card.SetBackdrop then
                card:SetBackdrop(SUB_CONTAINER_BACKDROP)
                card:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.85)
                card:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.90)
            end

            local typeBadge = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            typeBadge:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -6)
            card.typeBadge = typeBadge

            local titleText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
            titleText:SetPoint("LEFT", typeBadge, "RIGHT", 6, 0)
            titleText:SetPoint("RIGHT", card, "RIGHT", -190, 0)
            titleText:SetJustifyH("LEFT")
            card.titleText = titleText

            local dateTimeText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            dateTimeText:SetPoint("TOPLEFT", typeBadge, "BOTTOMLEFT", 0, -4)
            card.dateTimeText = dateTimeText

            local infoText = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            infoText:SetPoint("LEFT", dateTimeText, "RIGHT", 10, 0)
            card.infoText = infoText

            local descText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            descText:SetPoint("TOPLEFT", dateTimeText, "BOTTOMLEFT", 0, -3)
            descText:SetPoint("RIGHT", card, "RIGHT", -180, 0)
            descText:SetJustifyH("LEFT")
            card.descText = descText

            local inviteBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
            inviteBtn:SetSize(80, 20)
            inviteBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -116, 6)
            inviteBtn:SetText("Convidados")
            card.inviteBtn = inviteBtn

            local editBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
            editBtn:SetSize(52, 20)
            editBtn:SetPoint("LEFT", inviteBtn, "RIGHT", 4, 0)
            editBtn:SetText("Editar")
            card.editBtn = editBtn

            local deleteBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
            deleteBtn:SetSize(52, 20)
            deleteBtn:SetPoint("LEFT", editBtn, "RIGHT", 4, 0)
            deleteBtn:SetText("Excluir")
            card.deleteBtn = deleteBtn

            self._selectedDayCardPool[idx] = card
        end

        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", self._eventsScrollChild, "TOPLEFT", 2, -totalY)

        local evTheme = TYPE_THEMES[ev:getType()] or TYPE_THEMES.OUTRO
        if card.SetBackdropColor and card.SetBackdropBorderColor then
            card:SetBackdropColor(evTheme.bg[1], evTheme.bg[2], evTheme.bg[3], evTheme.bg[4])
            card:SetBackdropBorderColor(evTheme.border[1], evTheme.border[2], evTheme.border[3], evTheme.border[4])
        end

        card.typeBadge:SetText(evTheme.colorCode .. evTheme.label .. "|r")
        card.titleText:SetText("|cffffffff" .. (ev:getTitle() or "Sem título") .. "|r")

        local dtStr = string.format("|cffffd200Data: %s|r  |cffffffffàs %s|r", ev:getDate() or "-", ev:getTime() or "20:00")
        card.dateTimeText:SetText(dtStr)

        local creatorName = ev:getCreator()
        if creatorName == "" then creatorName = "Guilda" end
        local invCount = ev:getInviteeCount()
        card.infoText:SetText(string.format("|cff888888• Criado por: |cffffff00%s|r  • |cff00ff88%d convidado(s)|r", creatorName, invCount))

        local desc = ev:getDescription() or ""
        if desc == "" then desc = "|cff666666(Sem descrição adicional)|r" end
        card.descText:SetText(desc)

        local currentEventId = ev:getId()
        if canOfficer then
            card.editBtn:SetAlpha(1.0)
            card.deleteBtn:SetAlpha(1.0)
        else
            card.editBtn:SetAlpha(0.55)
            card.deleteBtn:SetAlpha(0.55)
        end

        card.inviteBtn:SetScript("OnClick", function()
            self:openInviteeModal(ev)
        end)

        card.editBtn:SetScript("OnClick", function()
            if not canOfficer then
                print("|cffff4444[GuildManager]|r Apenas Oficiais ou o Líder da Guilda podem editar eventos da agenda.")
                return
            end
            self:openEventModal(ev)
        end)

        card.deleteBtn:SetScript("OnClick", function()
            if not canOfficer then
                print("|cffff4444[GuildManager]|r Apenas Oficiais ou o Líder da Guilda podem excluir eventos da agenda.")
                return
            end
            local confirm = true
            if _G.GM and _G.GM.settingsService and _G.GM.settingsService:get("confirmEventDelete") == false then
                confirm = false
            end
            if confirm and StaticPopupDialogs then
                StaticPopupDialogs["GM_CONFIRM_DELETE_EVENT"] = {
                    text = "Deseja realmente excluir este evento da guilda?",
                    button1 = "Sim",
                    button2 = "Não",
                    OnAccept = function()
                        if self._onDeleteEventCallback then
                            self._onDeleteEventCallback(currentEventId)
                        end
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                }
                StaticPopup_Show("GM_CONFIRM_DELETE_EVENT")
            else
                if self._onDeleteEventCallback then
                    self._onDeleteEventCallback(currentEventId)
                end
            end
        end)

        card:Show()
        totalY = totalY + eventCardHeight + gap
    end

    -- 2. Cards de Aniversários
    local bdayCardHeight = 62
    for bIdx, b in ipairs(dayBirthdays) do
        local card = self._selectedDayBirthdayPool[bIdx]
        if not card then
            card = CreateFrame("Frame", nil, self._eventsScrollChild, template)
            card:SetSize(566, bdayCardHeight)
            if card.SetBackdrop then
                card:SetBackdrop(SUB_CONTAINER_BACKDROP)
                card:SetBackdropColor(0.12, 0.08, 0.02, 0.90)
                card:SetBackdropBorderColor(0.85, 0.65, 0.15, 0.90)
            end

            local cIcon = card:CreateTexture(nil, "ARTWORK")
            cIcon:SetSize(22, 22)
            cIcon:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)
            card.cIcon = cIcon

            local titleText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
            titleText:SetPoint("LEFT", cIcon, "RIGHT", 6, 0)
            titleText:SetPoint("RIGHT", card, "RIGHT", -120, 0)
            titleText:SetJustifyH("LEFT")
            card.titleText = titleText

            local detailText = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            detailText:SetPoint("TOPLEFT", cIcon, "BOTTOMLEFT", 0, -4)
            detailText:SetPoint("RIGHT", card, "RIGHT", -120, 0)
            detailText:SetJustifyH("LEFT")
            card.detailText = detailText

            local scheduleBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
            scheduleBtn:SetSize(90, 22)
            scheduleBtn:SetPoint("RIGHT", card, "RIGHT", -8, 0)
            scheduleBtn:SetText("+ Agendar")
            card.scheduleBtn = scheduleBtn

            self._selectedDayBirthdayPool[bIdx] = card
        end

        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", self._eventsScrollChild, "TOPLEFT", 2, -totalY)

        local bTheme = TYPE_THEMES.ANIVERSARIO
        if card.SetBackdropColor and card.SetBackdropBorderColor then
            card:SetBackdropColor(bTheme.bg[1], bTheme.bg[2], bTheme.bg[3], bTheme.bg[4])
            card:SetBackdropBorderColor(bTheme.border[1], bTheme.border[2], bTheme.border[3], bTheme.border[4])
        end

        local tok = b.class and (CLASS_NAME_TO_TOKEN[b.class:upper()] or b.class:upper()) or ""
        local coords = tok ~= "" and CLASS_ICON_COORDS[tok]
        card.cIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        if coords then
            card.cIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            card.cIcon:Show()
            card.titleText:SetPoint("LEFT", card.cIcon, "RIGHT", 6, 0)
        else
            card.cIcon:Hide()
            card.titleText:SetPoint("LEFT", card, "TOPLEFT", 8, -8)
        end

        local rk = b.rank and b.rank ~= "" and (" • " .. b.rank) or ""
        card.titleText:SetText(bTheme.colorCode .. "[Aniversário]|r " .. getColoredName(b.cleanName or b.name, b.class) .. " |cff888888(Nv " .. (b.level or 1) .. rk .. ")|r")
        card.detailText:SetText(string.format("|cffffd200Data:|r %s • Comemoração de Aniversário na guilda", b.birthday or "--/--"))

        card.scheduleBtn:EnableMouse(true)
        if canOfficer then
            card.scheduleBtn:SetAlpha(1.0)
        else
            card.scheduleBtn:SetAlpha(0.55)
        end

        card.scheduleBtn:SetScript("OnClick", function()
            if not canOfficer then
                print("|cffff4444[GuildManager]|r Apenas Oficiais ou o Líder da Guilda podem agendar eventos.")
                return
            end
            if self._onCreateBirthdayEventCallback and b.member then
                self._onCreateBirthdayEventCallback(b.member)
            else
                self:openEventModal(nil, {
                    title = "Aniversário de " .. (b.cleanName or b.name),
                    type = "ANIVERSARIO",
                    date = selDateStr,
                    time = "20:00",
                    description = "Comemoração de aniversário de " .. (b.cleanName or b.name) .. "!",
                })
            end
        end)

        card:Show()
        totalY = totalY + bdayCardHeight + gap
    end

    -- 3. Cards de Promoções
    local promoCardHeight = 62
    for pIdx, p in ipairs(dayPromotions) do
        local card = self._selectedDayPromoPool[pIdx]
        if not card then
            card = CreateFrame("Frame", nil, self._eventsScrollChild, template)
            card:SetSize(566, promoCardHeight)
            if card.SetBackdrop then
                card:SetBackdrop(SUB_CONTAINER_BACKDROP)
                card:SetBackdropColor(0.03, 0.08, 0.12, 0.90)
                card:SetBackdropBorderColor(0.20, 0.70, 0.90, 0.90)
            end

            local cIcon = card:CreateTexture(nil, "ARTWORK")
            cIcon:SetSize(22, 22)
            cIcon:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)
            cIcon:SetTexture("Interface\\Icons\\INV_Shield_06")
            cIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            card.cIcon = cIcon

            local titleText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
            titleText:SetPoint("LEFT", cIcon, "RIGHT", 6, 0)
            titleText:SetPoint("RIGHT", card, "RIGHT", -120, 0)
            titleText:SetJustifyH("LEFT")
            card.titleText = titleText

            local detailText = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            detailText:SetPoint("TOPLEFT", cIcon, "BOTTOMLEFT", 0, -4)
            detailText:SetPoint("RIGHT", card, "RIGHT", -120, 0)
            detailText:SetJustifyH("LEFT")
            card.detailText = detailText

            local promoteBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
            promoteBtn:SetSize(90, 22)
            promoteBtn:SetPoint("RIGHT", card, "RIGHT", -8, 0)
            promoteBtn:SetText(L["AGENDA_PROMOTE_BTN"] or "Promover")
            card.promoteBtn = promoteBtn

            self._selectedDayPromoPool[pIdx] = card
        end

        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", self._eventsScrollChild, "TOPLEFT", 2, -totalY)

        local pTheme = TYPE_THEMES.PROMO
        if card.SetBackdropColor and card.SetBackdropBorderColor then
            card:SetBackdropColor(pTheme.bg[1], pTheme.bg[2], pTheme.bg[3], pTheme.bg[4])
            card:SetBackdropBorderColor(pTheme.border[1], pTheme.border[2], pTheme.border[3], pTheme.border[4])
        end

        card.titleText:SetText(pTheme.colorCode .. "[Promoção]|r " .. getColoredName(p.cleanName or p.name, p.class) .. " |cff888888(Nv " .. (p.level or 1) .. ")|r")

        local statusStr = p.isEligibleNow and "|cff00ff00[Elegível Hoje]|r" or string.format("|cffffff00[Meta: %d dias]|r", p.requiredDays or 0)
        card.detailText:SetText(string.format("Promover para: " .. pTheme.colorCode .. "%s|r • Tempo na guilda: %d dias %s", p.targetRank or "", p.daysInGuild or 0, statusStr))

        card.promoteBtn:EnableMouse(true)
        if canOfficer and p.isEligibleNow then
            card.promoteBtn:SetAlpha(1.0)
        else
            card.promoteBtn:SetAlpha(0.50)
        end

        card.promoteBtn:SetScript("OnEnter", function(btn)
            if not GameTooltip then return end
            GameTooltip:SetOwner(btn, "ANCHOR_TOP")
            GameTooltip:AddLine(string.format("|cffffd200Promoção para %s|r", p.targetRank or ""), 1, 1, 1)
            if not canOfficer then
                GameTooltip:AddLine("|cffff4444Apenas Oficiais ou o Líder da Guilda podem promover membros.|r", 1, 0.3, 0.3, true)
            elseif p.isEligibleNow then
                GameTooltip:AddLine("|cff00ff00Clique para promover este membro agora!|r", 0.2, 1.0, 0.2)
            else
                GameTooltip:AddLine(string.format("|cffaaaaaaMembro atinge os %d dias requeridos nesta data.|r", p.requiredDays or 0), 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end)
        card.promoteBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        card.promoteBtn:SetScript("OnClick", function()
            if not canOfficer then
                print("|cffff4444[GuildManager]|r Apenas Oficiais ou o Líder da Guilda podem promover membros.")
                return
            end
            if not p.isEligibleNow then
                print(string.format("|cffffaa00[GuildManager]|r %s atinge a meta no dia previsto (%d dias na guilda).", p.cleanName or p.name, p.requiredDays or 0))
                return
            end
            if self._onPromoteMemberCallback then
                self._onPromoteMemberCallback(p.name or p.cleanName, p.targetRank)
            end
        end)

        card:Show()
        totalY = totalY + promoCardHeight + gap
    end

    self._eventsScrollChild:SetHeight(math.max(totalY, 1))
end

--- Renderiza o feed unificado de Próximos Eventos (Eventos, Aniversários e Promoções) no painel direito.
function AgendaView:renderUpcomingFeed()
    if not self._birthdaysScrollChild then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })

    for _, card in ipairs(self._upcomingFeedCardPool) do
        card:Hide()
    end

    local combined = {}

    -- 1. Próximos eventos da guilda
    local curDate = (date and date("*t")) or (os and os.date and os.date("*t")) or { year = 2026, month = 10, day = 19 }
    local todayMidnight = 0
    if time then
        todayMidnight = time({ year = curDate.year or 2026, month = curDate.month or 10, day = curDate.day or 19, hour = 0, min = 0, sec = 0 })
    end

    for _, ev in ipairs(self._events or {}) do
        local norm, m, d, y = normalizeDate(ev:getDate())
        if norm and y and m and d then
            local daysUntil = 9999
            if time and todayMidnight > 0 then
                local evMidnight = time({ year = y, month = m, day = d, hour = 0, min = 0, sec = 0 })
                daysUntil = math.floor((evMidnight - todayMidnight) / 86400)
            else
                daysUntil = (y - (curDate.year or 2026)) * 365 + (m - (curDate.month or 10)) * 30 + (d - (curDate.day or 19))
            end

            if daysUntil >= 0 and daysUntil <= 60 then
                local dText = ""
                if daysUntil == 0 then
                    dText = "|cff00ff00Hoje!|r"
                elseif daysUntil == 1 then
                    dText = "|cffffff00Amanhã!|r"
                elseif daysUntil <= 7 then
                    dText = string.format("|cffffff00Em %d dias|r", daysUntil)
                else
                    dText = string.format("|cffaaaaaaEm %d dias|r", daysUntil)
                end

                table.insert(combined, {
                    itemType = "EVENT",
                    event = ev,
                    title = ev:getTitle() or "Evento",
                    type = ev:getType() or "OUTRO",
                    date = ev:getDate() or "",
                    time = ev:getTime() or "20:00",
                    year = y,
                    month = m,
                    day = d,
                    daysUntil = daysUntil,
                    daysText = dText,
                })
            end
        end
    end

    -- 2. Próximos aniversários
    for _, b in ipairs(self._upcomingBirthdays or {}) do
        table.insert(combined, {
            itemType = "BIRTHDAY",
            member = b.member,
            name = b.name or (b.member and b.member:getName()) or "",
            cleanName = b.cleanName or (b.name and b.name:match("^[^-]+")) or "Membro",
            class = b.class or (b.member and b.member:getClass()) or "",
            level = b.level or (b.member and b.member:getLevel()) or 1,
            birthday = b.birthday or "--/--",
            rank = b.rank or "",
            targetYear = b.targetYear,
            daysUntil = b.daysUntil or 999,
            daysText = b.daysText or "",
        })
    end

    -- 3. Próximas promoções
    for _, p in ipairs(self._upcomingPromotions or {}) do
        table.insert(combined, {
            itemType = "PROMOTION",
            member = p.member,
            name = p.name or (p.member and p.member:getName()) or "",
            cleanName = p.cleanName or (p.name and p.name:match("^[^-]+")) or "Membro",
            class = p.class or (p.member and p.member:getClass()) or "",
            level = p.level or (p.member and p.member:getLevel()) or 1,
            currentRank = p.currentRank or "",
            targetRank = p.targetRank or "",
            daysInGuild = p.daysInGuild or 0,
            requiredDays = p.requiredDays or 0,
            daysUntil = p.daysUntil or 0,
            isEligibleNow = p.isEligibleNow == true,
            daysText = p.daysText or "",
        })
    end

    table.sort(combined, function(a, b)
        if a.daysUntil == b.daysUntil then
            if a.itemType ~= b.itemType then
                local pMap = { PROMOTION = 1, EVENT = 2, BIRTHDAY = 3 }
                return (pMap[a.itemType] or 9) < (pMap[b.itemType] or 9)
            end
            return (a.title or a.cleanName or "") < (b.title or b.cleanName or "")
        end
        return a.daysUntil < b.daysUntil
    end)

    if #combined == 0 then
        if self._emptyBirthdaysText then self._emptyBirthdaysText:Show() end
        self._birthdaysScrollChild:SetHeight(1)
        return
    end

    if self._emptyBirthdaysText then self._emptyBirthdaysText:Hide() end

    local cardHeight = 66
    local gap = 4
    local totalY = 2

    local canOfficer = false
    if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
        canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
    elseif IsGuildLeader and IsGuildLeader() then
        canOfficer = true
    elseif CanEditOfficerNote and CanEditOfficerNote() then
        canOfficer = true
    end

    for idx, item in ipairs(combined) do
        local card = self._upcomingFeedCardPool[idx]
        if not card then
            card = CreateFrame("Frame", nil, self._birthdaysScrollChild, template)
            card:SetSize(258, cardHeight)
            if card.SetBackdrop then
                card:SetBackdrop(SUB_CONTAINER_BACKDROP)
                card:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.85)
                card:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.90)
            end

            local cIcon = card:CreateTexture(nil, "ARTWORK")
            cIcon:SetSize(20, 20)
            cIcon:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -6)
            card.cIcon = cIcon

            local nameText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameText:SetPoint("LEFT", cIcon, "RIGHT", 5, 0)
            nameText:SetPoint("RIGHT", card, "RIGHT", -6, 0)
            nameText:SetJustifyH("LEFT")
            card.nameText = nameText

            local detailText = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            detailText:SetPoint("TOPLEFT", cIcon, "BOTTOMLEFT", 0, -4)
            detailText:SetPoint("RIGHT", card, "RIGHT", -78, 0)
            detailText:SetJustifyH("LEFT")
            card.detailText = detailText

            local countdownText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            countdownText:SetPoint("TOPLEFT", detailText, "BOTTOMLEFT", 0, -2)
            card.countdownText = countdownText

            local actionBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
            actionBtn:SetSize(72, 20)
            actionBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -6, 6)
            card.actionBtn = actionBtn

            self._upcomingFeedCardPool[idx] = card
        end

        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", self._birthdaysScrollChild, "TOPLEFT", 2, -totalY)

        local itemTheme = TYPE_THEMES.OUTRO
        if item.itemType == "EVENT" then
            itemTheme = TYPE_THEMES[item.type] or TYPE_THEMES.OUTRO
        elseif item.itemType == "BIRTHDAY" then
            itemTheme = TYPE_THEMES.ANIVERSARIO
        elseif item.itemType == "PROMOTION" then
            itemTheme = TYPE_THEMES.PROMO
        end

        if card.SetBackdropColor and card.SetBackdropBorderColor then
            card:SetBackdropColor(itemTheme.bg[1], itemTheme.bg[2], itemTheme.bg[3], itemTheme.bg[4])
            card:SetBackdropBorderColor(itemTheme.border[1], itemTheme.border[2], itemTheme.border[3], itemTheme.border[4])
        end

        card.actionBtn:EnableMouse(true)

        if item.itemType == "EVENT" then
            local okIcon = card.cIcon:SetTexture("Interface\\Calendar\\UI-Calendar-Button")
            if okIcon ~= false and card.cIcon:GetTexture() then
                card.cIcon:SetTexCoord(0.0078, 0.375, 0.0156, 0.75)
            else
                card.cIcon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
                card.cIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            card.cIcon:Show()
            card.nameText:SetPoint("LEFT", card.cIcon, "RIGHT", 5, 0)

            card.nameText:SetText(itemTheme.colorCode .. itemTheme.label .. "|r |cffffffff" .. (item.title or "") .. "|r")
            card.detailText:SetText(string.format("|cffffd200Data: %s|r às %s", item.date or "--/--", item.time or "20:00"))
            card.countdownText:SetText(item.daysText or "")

            card.actionBtn:SetText(L["AGENDA_VIEW_BTN"] or "Ver")
            card.actionBtn:SetWidth(56)
            card.actionBtn:SetAlpha(1.0)
            card.actionBtn:SetScript("OnEnter", function(btn)
                if not GameTooltip then return end
                GameTooltip:SetOwner(btn, "ANCHOR_TOP")
                GameTooltip:AddLine("|cffffd200Ver no Calendário|r", 1, 1, 1)
                GameTooltip:AddLine("|cff00ff00Clique para selecionar esta data no calendário e ver os detalhes.|r", 0.2, 1.0, 0.2)
                GameTooltip:Show()
            end)
            card.actionBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            card.actionBtn:SetScript("OnClick", function()
                self._calendarYear = item.year
                self._calendarMonth = item.month
                self._selectedDate = { year = item.year, month = item.month, day = item.day }
                self:renderCalendar()
                self:renderSelectedDayEvents()
            end)

        elseif item.itemType == "BIRTHDAY" then
            local tok = item.class and (CLASS_NAME_TO_TOKEN[item.class:upper()] or item.class:upper()) or ""
            local coords = tok ~= "" and CLASS_ICON_COORDS[tok]
            card.cIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
            if coords then
                card.cIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                card.cIcon:Show()
                card.nameText:SetPoint("LEFT", card.cIcon, "RIGHT", 5, 0)
            else
                card.cIcon:Hide()
                card.nameText:SetPoint("LEFT", card, "TOPLEFT", 8, -6)
            end

            card.nameText:SetText(getColoredName(item.cleanName or item.name, item.class) .. " |cff888888(Nv " .. (item.level or 1) .. ")|r")
            local rk = item.rank or ""
            if rk ~= "" then rk = " • " .. rk end
            card.detailText:SetText(string.format("%sAniv: %s|r%s", itemTheme.colorCode, item.birthday or "--/--", rk))
            card.countdownText:SetText(item.daysText or "")

            card.actionBtn:SetText("+ Agendar")
            card.actionBtn:SetWidth(72)
            if canOfficer then
                card.actionBtn:SetAlpha(1.0)
            else
                card.actionBtn:SetAlpha(0.55)
            end
            card.actionBtn:SetScript("OnEnter", function(btn)
                if not GameTooltip then return end
                GameTooltip:SetOwner(btn, "ANCHOR_TOP")
                GameTooltip:AddLine("|cffffd200Agendar Comemoração|r", 1, 1, 1)
                if not canOfficer then
                    GameTooltip:AddLine("|cffff4444Apenas Oficiais ou o Líder da Guilda podem agendar comemorações.|r", 1, 0.3, 0.3, true)
                else
                    GameTooltip:AddLine("|cff00ff00Clique para criar um evento na agenda para este aniversário.|r", 0.2, 1.0, 0.2)
                end
                GameTooltip:Show()
            end)
            card.actionBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            card.actionBtn:SetScript("OnClick", function()
                if not canOfficer then
                    print("|cffff4444[GuildManager]|r Apenas Oficiais ou o Líder da Guilda podem criar eventos da agenda.")
                    return
                end
                if self._onCreateBirthdayEventCallback and item.member then
                    self._onCreateBirthdayEventCallback(item.member)
                else
                    local curYear = (date and date("*t") and date("*t").year) or 2026
                    local m, d = (item.birthday or ""):match("^(%d%d?)/(%d%d?)$")
                    local targetDate = string.format("%02d/%02d/%04d", tonumber(d) or 1, tonumber(m) or 1, item.targetYear or curYear)
                    self:openEventModal(nil, {
                        title = "Aniversário de " .. (item.cleanName or item.name),
                        type = "ANIVERSARIO",
                        date = targetDate,
                        time = "20:00",
                        description = "Comemoração de aniversário de " .. (item.cleanName or item.name) .. "!",
                    })
                end
            end)

        elseif item.itemType == "PROMOTION" then
            card.cIcon:SetTexture("Interface\\Icons\\INV_Shield_06")
            card.cIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            card.cIcon:Show()
            card.nameText:SetPoint("LEFT", card.cIcon, "RIGHT", 5, 0)

            card.nameText:SetText(getColoredName(item.cleanName or item.name, item.class) .. " |cff888888(Nv " .. (item.level or 1) .. ")|r")
            card.detailText:SetText(string.format("Cargo: %s%s|r (%dd / %dd)", itemTheme.colorCode, item.targetRank or "", item.daysInGuild or 0, item.requiredDays or 0))
            card.countdownText:SetText(item.isEligibleNow and "|cff00ff00Elegível Hoje!|r" or (item.daysText or ""))

            card.actionBtn:SetText(L["AGENDA_PROMOTE_BTN"] or "Promover")
            card.actionBtn:SetWidth(68)
            if canOfficer and item.isEligibleNow then
                card.actionBtn:SetAlpha(1.0)
            else
                card.actionBtn:SetAlpha(0.50)
            end
            card.actionBtn:SetScript("OnEnter", function(btn)
                if not GameTooltip then return end
                GameTooltip:SetOwner(btn, "ANCHOR_TOP")
                GameTooltip:AddLine(string.format("|cffffd200Promoção para %s|r", item.targetRank or ""), 1, 1, 1)
                GameTooltip:AddLine(string.format("Tempo na guilda: |cffffff00%d dias|r (Meta: %d dias)", item.daysInGuild or 0, item.requiredDays or 0), 1, 1, 1)
                if not canOfficer then
                    GameTooltip:AddLine("|cffff4444Apenas Oficiais ou o Líder da Guilda podem promover membros.|r", 1, 0.3, 0.3, true)
                elseif item.isEligibleNow then
                    GameTooltip:AddLine("|cff00ff00Clique para promover este membro no jogo!|r", 0.2, 1.0, 0.2)
                else
                    GameTooltip:AddLine(string.format("|cffaaaaaaMembro ainda não atingiu o tempo mínimo (%d dias restantes).|r", item.daysUntil or 0), 0.7, 0.7, 0.7)
                end
                GameTooltip:Show()
            end)
            card.actionBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            card.actionBtn:SetScript("OnClick", function()
                if not canOfficer then
                    print("|cffff4444[GuildManager]|r Apenas Oficiais ou o Líder da Guilda podem promover membros.")
                    return
                end
                if not item.isEligibleNow then
                    print(string.format("|cffffaa00[GuildManager]|r %s ainda não atingiu os %d dias necessários para esta promoção (%d dias restantes).", item.cleanName or item.name, item.requiredDays or 0, item.daysUntil or 0))
                    return
                end
                if self._onPromoteMemberCallback then
                    self._onPromoteMemberCallback(item.name or item.cleanName, item.targetRank)
                end
            end)
        end

        card:Show()
        totalY = totalY + cardHeight + gap
    end

    self._birthdaysScrollChild:SetHeight(math.max(totalY, 1))
end

--- Renderiza a agenda: atualiza calendário, eventos do dia e o feed de próximos eventos.
function AgendaView:renderEvents()
    self:renderCalendar()
    self:renderSelectedDayEvents()
    self:renderUpcomingFeed()
end

--- Renderiza a lista de aniversários e promoções (chama o feed de próximos eventos).
function AgendaView:renderBirthdays()
    self:renderUpcomingFeed()
end

--- =========================================================================
--- MODAL: CRIAR / EDITAR EVENTO
--- =========================================================================
function AgendaView:createEventModal()
    if self._eventModal then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })

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
    mTitle:SetText(L["EVENT_CREATE_TITLE"])
    modal.mTitle = mTitle

    local mSep = modal:CreateTexture(nil, "ARTWORK")
    mSep:SetPoint("TOPLEFT", modal, "TOPLEFT", 16, -44)
    mSep:SetPoint("RIGHT", modal, "RIGHT", -16, 0)
    mSep:SetHeight(1)
    mSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- Campo: Título
    local titleLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("TOPLEFT", mSep, "BOTTOMLEFT", 4, -10)
    titleLabel:SetText(L["EVENT_TITLE_LABEL"])
    modal.titleLabel = titleLabel

    local titleEB = CreateFrame("EditBox", nil, modal, template)
    titleEB:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 0, -4)
    titleEB:SetSize(400, 24)
    styleBox(titleEB)
    modal.titleEB = titleEB

    -- Campo: Tipo de Evento
    local typeLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    typeLabel:SetPoint("TOPLEFT", titleEB, "BOTTOMLEFT", 0, -10)
    typeLabel:SetText(L["EVENT_TYPE_LABEL"])
    modal.typeLabel = typeLabel

    local typeButtons = {}
    local typeDefs = {
        { id = "RAID",        labelKey = "EVENT_TYPE_RAID" },
        { id = "DUNGEON",     labelKey = "EVENT_TYPE_DUNGEON" },
        { id = "PVP",         labelKey = "EVENT_TYPE_PVP" },
        { id = "REUNIAO",     labelKey = "EVENT_TYPE_MEETING" },
        { id = "ANIVERSARIO", labelKey = "EVENT_TYPE_BIRTHDAY" },
        { id = "OUTRO",       labelKey = "EVENT_TYPE_OTHER" },
    }
    modal.typeDefs = typeDefs
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
        bText:SetText(tDef.labelKey)
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
    dateLabel:SetText(L["EVENT_DATE_LABEL"])
    modal.dateLabel = dateLabel

    local dateEB = CreateFrame("EditBox", nil, modal, template)
    dateEB:SetPoint("TOPLEFT", dateLabel, "BOTTOMLEFT", 0, -4)
    dateEB:SetSize(250, 24)
    styleBox(dateEB)
    modal.dateEB = dateEB

    local timeLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timeLabel:SetPoint("TOPLEFT", dateLabel, "TOPLEFT", 265, 0)
    timeLabel:SetText(L["EVENT_TIME_LABEL"])
    modal.timeLabel = timeLabel

    local timeEB = CreateFrame("EditBox", nil, modal, template)
    timeEB:SetPoint("TOPLEFT", timeLabel, "BOTTOMLEFT", 0, -4)
    timeEB:SetSize(135, 24)
    timeEB:SetMaxLetters(5)
    styleBox(timeEB)
    modal.timeEB = timeEB

    -- Campo: Descrição (Container com Backdrop clássico evita o colapso nativo de EditBox multiline no motor do WoW)
    local descLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", dateEB, "BOTTOMLEFT", 0, -10)
    descLabel:SetText(L["EVENT_DESC_LABEL"])
    modal.descLabel = descLabel

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
    saveBtn:SetText(L["EVENT_SAVE_BTN"])
    modal.saveBtn = saveBtn

    saveBtn:SetScript("OnEnter", function(btn)
        local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
        local canOfficer = false
        if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
            canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
        elseif IsGuildLeader and IsGuildLeader() then
            canOfficer = true
        elseif CanEditOfficerNote and CanEditOfficerNote() then
            canOfficer = true
        end

        if GameTooltip then
            GameTooltip:SetOwner(btn, "ANCHOR_TOP")
            GameTooltip:AddLine("|cffffd200" .. curL["EVENT_SAVE_BTN"] .. "|r", 1, 1, 1)
            if not canOfficer then
                GameTooltip:AddLine(curL["EVENT_ERR_OFFICER_ONLY"], 1, 0.3, 0.3, true)
            else
                GameTooltip:AddLine("|cff00ff00Clique para confirmar e salvar o evento.|r\n|cffaaaaaa(Permissão de Oficial/Líder ativa)|r", 0.2, 1.0, 0.2)
            end
            GameTooltip:Show()
        end
    end)
    saveBtn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    saveBtn:SetScript("OnClick", function()
        local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
        local canOfficer = false
        if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
            canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
        elseif IsGuildLeader and IsGuildLeader() then
            canOfficer = true
        elseif CanEditOfficerNote and CanEditOfficerNote() then
            canOfficer = true
        end

        if not canOfficer then
            errText:SetText(curL["EVENT_ERR_OFFICER_ONLY"])
            return
        end
        local tVal = titleEB:GetText() or ""
        local dVal = dateEB:GetText() or ""
        local hVal = timeEB:GetText() or "20:00"
        local descVal = descEB:GetText() or ""

        if tVal:match("^%s*$") then
            errText:SetText(curL["EVENT_ERR_TITLE_REQ"])
            return
        end

        if dVal:match("^%s*$") then
            errText:SetText(curL["EVENT_ERR_DATE_REQ"])
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
            errText:SetText(err or curL["EVENT_ERR_SAVE_FAIL"])
        end
    end)

    local cancelBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    cancelBtn:SetSize(100, 26)
    cancelBtn:SetPoint("LEFT", saveBtn, "RIGHT", 10, 0)
    cancelBtn:SetText(L["CANCEL"])
    cancelBtn:SetScript("OnClick", function() modal:Hide() end)
    modal.cancelBtn = cancelBtn

    self._eventModal = modal
    self:updateEventModalLocale()
end

--- Abre a modal de criação ou edição de evento.
---@param event Event|nil
---@param prefill table|nil
function AgendaView:openEventModal(event, prefill)
    local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
    local canOfficer = false
    if _G.GM and _G.GM.guildRosterService and _G.GM.guildRosterService.isPlayerOfficerOrLeader then
        canOfficer = _G.GM.guildRosterService:isPlayerOfficerOrLeader()
    elseif IsGuildLeader and IsGuildLeader() then
        canOfficer = true
    elseif CanEditOfficerNote and CanEditOfficerNote() then
        canOfficer = true
    end

    if not canOfficer then
        print(string.format("|cffff4444[GuildManager]|r %s", L["EVENT_ERR_OFFICER_ONLY"]))
        return
    end

    if not self._eventModal then return end
    local modal = self._eventModal

    modal.errText:SetText("")

    if event then
        modal.editingEventId = event:getId()
        modal.mTitle:SetText(L["EVENT_EDIT_TITLE"])
        modal.titleEB:SetText(event:getTitle() or "")
        modal.dateEB:SetText(event:getDate() or "")
        modal.timeEB:SetText(event:getTime() or "20:00")
        modal.descEB:SetText(event:getDescription() or "")
        modal.selectedType = event:getType() or "OUTRO"
    else
        modal.editingEventId = nil
        modal.mTitle:SetText(L["EVENT_CREATE_TITLE"])
        local p = prefill or {}
        modal.titleEB:SetText(p.title or "")
        modal.dateEB:SetText(p.date or "")
        local defTime = (_G.GM and _G.GM.settingsService and _G.GM.settingsService:get("defaultEventTime")) or "20:00"
        modal.timeEB:SetText(p.time or defTime)
        modal.descEB:SetText(p.description or "")
        modal.selectedType = p.type or "RAID"
    end

    self:updateEventModalLocale()

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
    modal:SetScript("OnHide", function()
        if modal.suggestFrame then modal.suggestFrame:Hide() end
    end)

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
    modal.mTitle = mTitle

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
    modal.inviteAllBtn = inviteAllBtn

    local totalText = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalText:SetPoint("LEFT", inviteAllBtn, "RIGHT", 12, 0)
    totalText:SetText("|cffaaaaaaTotal: 0 convidados|r")
    modal.totalText = totalText

    -- Linha de Adicionar Convidado com Busca / Autocomplete
    local addLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLabel:SetPoint("TOPLEFT", inviteAllBtn, "BOTTOMLEFT", 0, -12)
    addLabel:SetText(L["EVENT_ADD_INVITEE_LABEL"])
    modal.addLabel = addLabel

    local addEB = CreateFrame("EditBox", nil, modal, template)
    addEB:SetPoint("TOPLEFT", addLabel, "BOTTOMLEFT", 0, -4)
    addEB:SetSize(260, 22)
    styleBox(addEB)
    modal.addEB = addEB

    local addSearchHint = addEB:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    addSearchHint:SetPoint("LEFT", addEB, "LEFT", 8, 0)
    addSearchHint:SetText("|cffaaaaaaBuscar membro na guilda...|r")
    modal.addSearchHint = addSearchHint

    local addBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    addBtn:SetSize(110, 22)
    addBtn:SetPoint("LEFT", addEB, "RIGHT", 8, 0)
    addBtn:SetText("+ Adicionar")
    modal.addBtn = addBtn

    -- Dropdown Flutuante de Sugestões de Membros da Guilda
    local suggestFrame = CreateFrame("Frame", "GM_AgendaInviteeSuggest", modal, template)
    suggestFrame:SetPoint("TOPLEFT", addEB, "BOTTOMLEFT", 0, -2)
    suggestFrame:SetSize(378, 160)
    suggestFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    suggestFrame:SetFrameLevel((modal:GetFrameLevel() or 20) + 50)
    suggestFrame:EnableMouse(true)
    suggestFrame:Hide()
    modal.suggestFrame = suggestFrame

    if suggestFrame.SetBackdrop then
        suggestFrame:SetBackdrop(SUB_CONTAINER_BACKDROP)
        suggestFrame:SetBackdropColor(0.04, 0.03, 0.015, 0.98)
        suggestFrame:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], 1.0)
    end

    local scrollBar = CreateFrame("Slider", "GM_AgendaInviteeSuggestScrollBar", suggestFrame, "UIPanelScrollBarTemplate")
    modal.suggestScrollBar = scrollBar
    scrollBar:SetPoint("TOPRIGHT", suggestFrame, "TOPRIGHT", -4, -18)
    scrollBar:SetPoint("BOTTOMRIGHT", suggestFrame, "BOTTOMRIGHT", -4, 18)
    scrollBar:SetWidth(14)
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValueStep(1)
    scrollBar:Hide()
    scrollBar:SetScript("OnValueChanged", function(_, val)
        modal.suggestOffset = math.floor(val)
        self:renderInviteeSuggestions()
    end)

    local suggestEmpty = suggestFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    suggestEmpty:SetPoint("CENTER", suggestFrame, "CENTER", 0, 0)
    suggestEmpty:SetText("|cff888888Nenhum membro encontrado|r")
    suggestEmpty:Hide()
    modal.suggestEmpty = suggestEmpty

    modal.suggestRows = {}
    local maxSuggestRows = 6
    local suggestRowHeight = 24
    for i = 1, maxSuggestRows do
        local row = CreateFrame("Button", nil, suggestFrame)
        row:SetHeight(suggestRowHeight)
        row:SetPoint("TOPLEFT", suggestFrame, "TOPLEFT", 6, -5 - (i - 1) * suggestRowHeight)
        row:SetPoint("RIGHT", suggestFrame, "RIGHT", -6, 0)

        local selBg = row:CreateTexture(nil, "BACKGROUND")
        selBg:SetAllPoints(row)
        selBg:SetColorTexture(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], 0.25)
        selBg:Hide()
        row.selectedBg = selBg

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(row)
        hl:SetColorTexture(PALETTE.HIGHLIGHT_TINT[1], PALETTE.HIGHLIGHT_TINT[2], PALETTE.HIGHLIGHT_TINT[3], 0.15)
        row:SetHighlightTexture(hl)

        -- Status online/offline
        local statusDot = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statusDot:SetPoint("LEFT", row, "LEFT", 4, 0)
        statusDot:SetText("●")
        row.statusDot = statusDot

        -- Ícone circular de classe
        local classIcon = row:CreateTexture(nil, "ARTWORK")
        classIcon:SetSize(16, 16)
        classIcon:SetPoint("LEFT", statusDot, "RIGHT", 4, 0)
        classIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        row.classIcon = classIcon

        -- Nome do jogador
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", classIcon, "RIGHT", 6, 0)
        row.nameText = nameText

        -- Detalhes (Nível / Cargo)
        local infoText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        infoText:SetPoint("LEFT", nameText, "RIGHT", 6, 0)
        row.infoText = infoText

        -- Dica de ação
        local actionText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        actionText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        actionText:SetText("|cff00ff00+ Convidar|r")
        row.actionText = actionText

        row:SetScript("OnEnter", function()
            modal.suggestSelectedIndex = (modal.suggestOffset or 0) + i
            self:updateSuggestSelectionVisual()
        end)

        row:SetScript("OnClick", function()
            if row.item then
                self:selectAndAddInvitee(row.item.cleanName)
            end
        end)

        modal.suggestRows[i] = row
    end

    local function onSuggestWheel(delta)
        local candidates = modal.suggestCandidates or {}
        if #candidates <= maxSuggestRows then return end
        local maxOffset = #candidates - maxSuggestRows
        local cur = modal.suggestOffset or 0
        if delta > 0 then
            modal.suggestOffset = math.max(0, cur - 1)
        else
            modal.suggestOffset = math.min(maxOffset, cur + 1)
        end
        self:renderInviteeSuggestions()
    end
    suggestFrame:EnableMouseWheel(true)
    suggestFrame:SetScript("OnMouseWheel", function(_, delta) onSuggestWheel(delta) end)

    addEB:SetScript("OnTextChanged", function(box)
        local txt = box:GetText() or ""
        if txt ~= "" then
            addSearchHint:Hide()
        else
            addSearchHint:Show()
        end
        self:filterInviteeCandidates(txt)
    end)

    addEB:SetScript("OnKeyDown", function(box, key)
        local sf = modal.suggestFrame
        if sf and sf:IsShown() and modal.suggestCandidates and #modal.suggestCandidates > 0 then
            local total = #modal.suggestCandidates
            if key == "DOWN" then
                modal.suggestSelectedIndex = math.min((modal.suggestSelectedIndex or 1) + 1, total)
                if modal.suggestSelectedIndex > (modal.suggestOffset or 0) + maxSuggestRows then
                    modal.suggestOffset = modal.suggestSelectedIndex - maxSuggestRows
                end
                self:renderInviteeSuggestions()
                return
            elseif key == "UP" then
                modal.suggestSelectedIndex = math.max((modal.suggestSelectedIndex or 1) - 1, 1)
                if modal.suggestSelectedIndex <= (modal.suggestOffset or 0) then
                    modal.suggestOffset = math.max(0, modal.suggestSelectedIndex - 1)
                end
                self:renderInviteeSuggestions()
                return
            elseif key == "TAB" then
                local selected = modal.suggestCandidates[modal.suggestSelectedIndex or 1]
                if selected then
                    self:selectAndAddInvitee(selected.cleanName)
                    return
                end
            elseif key == "ESCAPE" then
                sf:Hide()
                return
            end
        end
        if key == "ESCAPE" then
            modal:Hide()
        end
    end)

    addEB:SetScript("OnEnterPressed", function()
        local sf = modal.suggestFrame
        if sf and sf:IsShown() and modal.suggestCandidates and #modal.suggestCandidates > 0 then
            local selected = modal.suggestCandidates[modal.suggestSelectedIndex or 1]
            if selected then
                self:selectAndAddInvitee(selected.cleanName)
                return
            end
        end
        addBtn:Click()
    end)

    addBtn:SetScript("OnClick", function()
        local name = addEB:GetText() or ""
        if name:match("^%s*$") then return end
        if modal.suggestFrame then modal.suggestFrame:Hide() end
        if modal.currentEvent and self._onAddInviteeCallback then
            local ok, err = self._onAddInviteeCallback(modal.currentEvent:getId(), name)
            if ok then
                addEB:SetText("")
                addSearchHint:Show()
                self:refreshInviteeModal()
                self:renderEvents()
            else
                print(string.format("|cffff4444[GuildManager]|r %s", err or "Falha ao adicionar."))
            end
        end
    end)

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
    emptyInvText:SetText(L["EVENT_INVITEES_EMPTY"])
    modal.emptyInvText = emptyInvText

    -- Botão Fechar inferior
    local bottomCloseBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate")
    bottomCloseBtn:SetSize(100, 24)
    bottomCloseBtn:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -16, 12)
    bottomCloseBtn:SetText(L["CLOSE"])
    bottomCloseBtn:SetScript("OnClick", function() modal:Hide() end)
    modal.bottomCloseBtn = bottomCloseBtn

    self._inviteeModal = modal
end

--- Filtra os membros da guilda com base no texto digitado no campo de adicionar convidado.
---@param text string
function AgendaView:filterInviteeCandidates(text)
    local modal = self._inviteeModal
    if not modal or not modal:IsShown() then return end
    local sf = modal.suggestFrame
    if not sf then return end

    local query = (text or ""):lower():match("^%s*(.-)%s*$")
    if not query or query == "" then
        sf:Hide()
        return
    end

    local all = self:getGuildMembers()
    local currentEvent = modal.currentEvent
    local candidates = {}

    for _, m in ipairs(all) do
        local rawName = m:getName() or ""
        local cleanName = rawName:match("^[^-]+") or rawName
        local cleanLower = cleanName:lower()

        -- Não sugere membros que já foram convidados para este evento
        local alreadyInvited = currentEvent and currentEvent:hasInvitee(cleanName)

        if not alreadyInvited and cleanLower:find(query, 1, true) then
            local isOnline = (type(m.isOnline) == "function" and m:isOnline()) or false
            local startsWith = (cleanLower:find("^" .. query) ~= nil)
            table.insert(candidates, {
                member = m,
                name = rawName,
                cleanName = cleanName,
                class = m:getClass() or "",
                level = m:getLevel() or 1,
                rank = m:getRankName() or "",
                isOnline = isOnline,
                startsWith = startsWith,
            })
        end
    end

    -- Ordena: quem começa com a busca primeiro, online primeiro, alfabético
    table.sort(candidates, function(a, b)
        if a.startsWith ~= b.startsWith then
            return a.startsWith == true
        end
        if a.isOnline ~= b.isOnline then
            return a.isOnline == true
        end
        return a.cleanName < b.cleanName
    end)

    modal.suggestCandidates = candidates
    modal.suggestOffset = 0
    modal.suggestSelectedIndex = 1

    self:renderInviteeSuggestions()
end

--- Renderiza visualmente as linhas de sugestões de membros no dropdown.
function AgendaView:renderInviteeSuggestions()
    local modal = self._inviteeModal
    if not modal then return end
    local sf = modal.suggestFrame
    if not sf then return end

    local candidates = modal.suggestCandidates or {}
    local maxVisible = 6
    local rowHeight = 24

    if #candidates == 0 then
        for _, row in ipairs(modal.suggestRows or {}) do row:Hide() end
        if modal.suggestScrollBar then modal.suggestScrollBar:Hide() end
        if modal.suggestEmpty then
            local q = (modal.addEB and modal.addEB:GetText()) or ""
            modal.suggestEmpty:SetText(string.format("|cff888888Nenhum membro encontrado com \"%s\"|r", q))
            modal.suggestEmpty:Show()
        end
        sf:SetHeight(38)
        sf:Show()
        return
    end

    if modal.suggestEmpty then modal.suggestEmpty:Hide() end

    local total = #candidates
    local offset = modal.suggestOffset or 0
    local visibleCount = math.min(total, maxVisible)

    sf:SetHeight(visibleCount * rowHeight + 10)
    sf:Show()

    local sb = modal.suggestScrollBar
    if total > maxVisible then
        sb:Show()
        sb:SetMinMaxValues(0, total - maxVisible)
        sb:SetValue(offset)
    else
        sb:Hide()
    end

    for i = 1, maxVisible do
        local row = modal.suggestRows[i]
        local cIndex = offset + i
        local item = candidates[cIndex]

        if item and i <= visibleCount then
            row.item = item
            row:SetPoint("TOPLEFT", sf, "TOPLEFT", 6, -5 - (i - 1) * rowHeight)
            if total > maxVisible then
                row:SetPoint("RIGHT", sf, "RIGHT", -22, 0)
            else
                row:SetPoint("RIGHT", sf, "RIGHT", -6, 0)
            end

            -- Status online/offline
            if item.isOnline then
                row.statusDot:SetText("|cff00ff00●|r")
            else
                row.statusDot:SetText("|cff666666○|r")
            end

            -- Ícone de classe
            local tok = item.class and (CLASS_NAME_TO_TOKEN[item.class:upper()] or item.class:upper()) or ""
            local coords = tok ~= "" and CLASS_ICON_COORDS[tok]
            if coords then
                row.classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                row.classIcon:Show()
                row.nameText:SetPoint("LEFT", row.classIcon, "RIGHT", 6, 0)
            else
                row.classIcon:Hide()
                row.nameText:SetPoint("LEFT", row.statusDot, "RIGHT", 6, 0)
            end

            -- Nome colorido
            row.nameText:SetText(getColoredName(item.cleanName, item.class))

            -- Informações (Nível / Cargo)
            local infoStr = string.format("|cffaaaaaaNv. %d|r", item.level or 1)
            if item.rank and item.rank ~= "" then
                infoStr = infoStr .. string.format(" |cff888888• %s|r", item.rank)
            end
            row.infoText:SetText(infoStr)

            -- Destaque de seleção
            if cIndex == (modal.suggestSelectedIndex or 1) then
                row.selectedBg:Show()
            else
                row.selectedBg:Hide()
            end

            row:Show()
        else
            if row then row:Hide() end
        end
    end
end

--- Atualiza o destaque visual da seleção nas linhas de sugestão.
function AgendaView:updateSuggestSelectionVisual()
    local modal = self._inviteeModal
    if not modal or not modal.suggestRows then return end
    local selectedIndex = modal.suggestSelectedIndex or 1
    local offset = modal.suggestOffset or 0
    for i, row in ipairs(modal.suggestRows) do
        local cIndex = offset + i
        if cIndex == selectedIndex then
            row.selectedBg:Show()
        else
            row.selectedBg:Hide()
        end
    end
end

--- Seleciona e adiciona o membro escolhido diretamente ao evento.
---@param memberName string
function AgendaView:selectAndAddInvitee(memberName)
    local modal = self._inviteeModal
    if not modal or not memberName or memberName == "" then return end

    if modal.suggestFrame then
        modal.suggestFrame:Hide()
    end

    if modal.currentEvent and self._onAddInviteeCallback then
        local ok, err = self._onAddInviteeCallback(modal.currentEvent:getId(), memberName)
        if ok then
            modal.addEB:SetText("")
            if modal.addSearchHint then modal.addSearchHint:Show() end
            self:refreshInviteeModal()
            self:renderEvents()
        else
            print(string.format("|cffff4444[GuildManager]|r %s", err or "Falha ao adicionar."))
        end
    end
end

--- Abre a modal de gerenciamento de convidados do evento.
---@param event Event
function AgendaView:openInviteeModal(event)
    if not self._inviteeModal or not event then return end
    self._inviteeModal.currentEvent = event
    if self._inviteeModal.suggestFrame then
        self._inviteeModal.suggestFrame:Hide()
    end
    if self._inviteeModal.addEB then
        self._inviteeModal.addEB:SetText("")
    end
    if self._inviteeModal.addSearchHint then
        self._inviteeModal.addSearchHint:Show()
    end
    self:refreshInviteeModal()
    self._inviteeModal:Show()
    if self._inviteeModal.addEB then
        self._inviteeModal.addEB:SetFocus()
    end
end

--- Atualiza a lista visual de convidados dentro da modal de convidados.
function AgendaView:refreshInviteeModal()
    local modal = self._inviteeModal
    if not modal or not modal.currentEvent then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    local evId = modal.currentEvent:getId()
    for _, item in ipairs(self._events or {}) do
        if item:getId() == evId then
            modal.currentEvent = item
            break
        end
    end

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
