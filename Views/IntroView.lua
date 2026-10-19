local addonName, addonTable = ...
local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })

---@class IntroView
---@field private _introFrame table|nil
---@field private _noGuildFrame table|nil
---@field private _currentStep number
---@field private _maxSteps number
---@field private _stepContainers table
---@field private _stepButtons table
---@field private _birthdayEB table|nil
---@field private _birthdayStatusTxt table|nil
---@field private _onCompleteCallback function|nil
---@field private _onSkipCallback function|nil
---@field private _onBirthdaySubmittedCallback function|nil
---@field private _onOpenAuditCallback function|nil
---@field private _onOpenLogsCallback function|nil
---@field private _onOpenAgendaCallback function|nil
---@field private _onOpenGroupsCallback function|nil
---@field private _onOpenProfessionsCallback function|nil
---@field private _onOpenWorldMapCallback function|nil
---@field private _onOpenSettingsCallback function|nil
IntroView = {}
IntroView.__index = IntroView

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

local PALETTE = {
    FRAME_BG = { 0.055, 0.035, 0.015, 1.0 },
    FRAME_BORDER = { 1.0, 0.68, 0.22, 1.0 },
    INSET_BG = { 0.035, 0.022, 0.010, 0.85 },
    INSET_BORDER = { 0.71, 0.49, 0.16, 0.95 },
    SEPARATOR = { 0.58, 0.37, 0.11, 0.90 },
    SUB_BOX_BG = { 0.022, 0.014, 0.006, 0.80 },
    SUB_BOX_BORDER = { 0.62, 0.41, 0.13, 0.90 },
    FOCUS_BG = { 0.065, 0.045, 0.020, 0.95 },
    FOCUS_BORDER = { 0.85, 0.58, 0.20, 1.0 },
    HIGHLIGHT_TINT = { 0.71, 0.49, 0.16, 0.14 },
    ACTIVE_TAB_BG = { 0.22, 0.14, 0.05, 0.95 },
    ACTIVE_TAB_BORDER = { 0.95, 0.70, 0.25, 1.0 },
    INACTIVE_TAB_BG = { 0.045, 0.030, 0.012, 0.80 },
    INACTIVE_TAB_BORDER = { 0.50, 0.33, 0.12, 0.85 },
}

--- Construtor da View de Introdução.
---@return IntroView
function IntroView:new()
    local instance = setmetatable({}, self)

    instance._introFrame = nil
    instance._noGuildFrame = nil
    instance._currentStep = 1
    instance._maxSteps = 8
    instance._stepContainers = {}
    instance._stepButtons = {}
    instance._birthdayEB = nil
    instance._birthdayStatusTxt = nil

    instance._onCompleteCallback = nil
    instance._onSkipCallback = nil
    instance._onBirthdaySubmittedCallback = nil

    instance._onOpenAuditCallback = nil
    instance._onOpenLogsCallback = nil
    instance._onOpenAgendaCallback = nil
    instance._onOpenGroupsCallback = nil
    instance._onOpenProfessionsCallback = nil
    instance._onOpenWorldMapCallback = nil
    instance._onOpenSettingsCallback = nil

    return instance
end

function IntroView:setOnCompleteCallback(cb) self._onCompleteCallback = cb end
function IntroView:setOnSkipCallback(cb) self._onSkipCallback = cb end
function IntroView:setOnBirthdaySubmittedCallback(cb) self._onBirthdaySubmittedCallback = cb end
function IntroView:setOnOpenAuditCallback(cb) self._onOpenAuditCallback = cb end
function IntroView:setOnOpenLogsCallback(cb) self._onOpenLogsCallback = cb end
function IntroView:setOnOpenAgendaCallback(cb) self._onOpenAgendaCallback = cb end
function IntroView:setOnOpenGroupsCallback(cb) self._onOpenGroupsCallback = cb end
function IntroView:setOnOpenProfessionsCallback(cb) self._onOpenProfessionsCallback = cb end
function IntroView:setOnOpenWorldMapCallback(cb) self._onOpenWorldMapCallback = cb end
function IntroView:setOnOpenSettingsCallback(cb) self._onOpenSettingsCallback = cb end

-- =========================================================================
-- JANELA: AVISO DE SEM GUILDA (NO GUILD DIALOG)
-- =========================================================================

--- Cria a janela modal informando que o jogador não está em guilda.
function IntroView:createNoGuildUI()
    if self._noGuildFrame then return end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "GuildManagerNoGuildFrame", UIParent, template)
    self._noGuildFrame = frame

    frame:SetSize(540, 270)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    frame:Hide()

    if frame.SetBackdrop then
        frame:SetBackdrop(DIALOG_BACKDROP)
        frame:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], PALETTE.FRAME_BG[4])
        frame:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], PALETTE.FRAME_BORDER[4])
    end

    -- Ícone de Alerta
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 40)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -20)
    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Título
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, -2)
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    title:SetText(curL["NO_GUILD_TITLE"] or "|cffffd200GUILD MANAGER FOREVER|r")
    self._noGuildTitle = title

    -- Subtítulo / Header
    local sub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText("|cffff9926" .. (curL["NO_GUILD_HEADER"] or "NENHUMA GUILDA DETECTADA") .. "|r")
    self._noGuildHeader = sub

    -- Divisória
    local sep = frame:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -12)
    sep:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    sep:SetHeight(1)
    sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- Caixa de Mensagem
    local msgBox = CreateFrame("Frame", nil, frame, template)
    msgBox:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -10)
    msgBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 52)
    if msgBox.SetBackdrop then
        msgBox:SetBackdrop(CONTAINER_BACKDROP)
        msgBox:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        msgBox:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end

    local descText = msgBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    descText:SetPoint("TOPLEFT", msgBox, "TOPLEFT", 14, -12)
    descText:SetPoint("BOTTOMRIGHT", msgBox, "BOTTOMRIGHT", -14, 12)
    descText:SetJustifyH("LEFT")
    descText:SetJustifyV("TOP")
    descText:SetSpacing(3)
    self._noGuildDesc = descText

    -- Botão "Entendido"
    local closeBtn = CreateFrame("Button", "GM_NoGuildCloseBtn", frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(130, 26)
    closeBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 16)
    closeBtn:SetText(curL["NO_GUILD_CLOSE"] or "Entendido")
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)
    self._noGuildCloseBtn = closeBtn

    self:updateNoGuildTexts()
end

function IntroView:updateNoGuildTexts()
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    if self._noGuildTitle then self._noGuildTitle:SetText(curL["NO_GUILD_TITLE"] or "|cffffd200GUILD MANAGER FOREVER|r") end
    if self._noGuildHeader then self._noGuildHeader:SetText("|cffff9926" .. (curL["NO_GUILD_HEADER"] or "NENHUMA GUILDA DETECTADA") .. "|r") end
    if self._noGuildCloseBtn then self._noGuildCloseBtn:SetText(curL["NO_GUILD_CLOSE"] or "Entendido") end

    if self._noGuildDesc then
        local msg1 = curL["NO_GUILD_MSG1"] or "Você atualmente não pertence a nenhuma guilda no World of Warcraft."
        local msg2 = curL["NO_GUILD_MSG2"] or "O Guild Manager Forever é uma ferramenta avançada desenvolvida exclusivamente para auditoria de membros, histórico de atividades, notas de gestão e sincronização em tempo real entre colegas de guilda."
        local msg3 = curL["NO_GUILD_MSG3"] or "Entre em uma guilda para desbloquear todas as funcionalidades. Assim que você entrar em uma guilda, o addon detectará automaticamente e iniciará a apresentação de boas-vindas!"

        local full = string.format("|cffffffff%s|r\n\n|cffcccccc%s|r\n\n|cffffd200%s|r", msg1, msg2, msg3)
        self._noGuildDesc:SetText(full)
    end
end

function IntroView:showNoGuildDialog()
    self:createNoGuildUI()
    self:updateNoGuildTexts()
    if self._noGuildFrame then
        self._noGuildFrame:Show()
    end
end

function IntroView:hideNoGuildDialog()
    if self._noGuildFrame then
        self._noGuildFrame:Hide()
    end
end

-- =========================================================================
-- JANELA: TUTORIAL / ONBOARDING COMPLETO (INTRO FRAME)
-- =========================================================================

--- Cria a interface do assistente de introdução do addon com 8 passos.
function IntroView:createIntroUI()
    if self._introFrame then return end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "GuildManagerIntroFrame", UIParent, template)
    self._introFrame = frame

    frame:SetSize(750, 530)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    frame:Hide()

    if UISpecialFrames then
        table.insert(UISpecialFrames, "GuildManagerIntroFrame")
    end

    if frame.SetBackdrop then
        frame:SetBackdrop(DIALOG_BACKDROP)
        frame:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], PALETTE.FRAME_BG[4])
        frame:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], PALETTE.FRAME_BORDER[4])
    end

    frame:SetScript("OnShow", function()
        if PlaySound then
            pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN or 839)
        end
    end)
    frame:SetScript("OnHide", function()
        if PlaySound then
            pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE or 840)
        end
    end)

    -- Topo: Ícone do Addon
    local appIcon = frame:CreateTexture(nil, "ARTWORK")
    appIcon:SetSize(36, 36)
    appIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -18)
    appIcon:SetTexture("Interface\\Icons\\Achievement_GuildPerk_MassResurrection")
    appIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Título
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", appIcon, "TOPRIGHT", 12, 0)
    title:SetText(curL["INTRO_TITLE"] or "|cffffd200GUILD MANAGER FOREVER|r")
    self._introTitle = title

    -- Subtítulo
    local sub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    sub:SetText(curL["INTRO_SUBTITLE"] or "Guia Rápido de Introdução & Recursos")
    self._introSub = sub

    -- Botão "Pular Tutorial (Skip)" no topo
    local topSkipBtn = CreateFrame("Button", "GM_IntroTopSkipBtn", frame, "UIPanelButtonTemplate")
    topSkipBtn:SetSize(130, 22)
    topSkipBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -22)
    topSkipBtn:SetText(curL["INTRO_SKIP"] or "Pular Tutorial")
    topSkipBtn:SetScript("OnClick", function()
        self:skipTutorial()
    end)
    self._topSkipBtn = topSkipBtn

    -- Divisória do Cabeçalho
    local headerSep = frame:CreateTexture(nil, "ARTWORK")
    headerSep:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -62)
    headerSep:SetPoint("RIGHT", frame, "RIGHT", -18, 0)
    headerSep:SetHeight(1)
    headerSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- Barra de Passos (8 abas superiores de navegação rápida)
    local stepTabs = {
        { id = 1, key = "INTRO_STEP1_TAB", fallback = "1. Auditoria" },
        { id = 2, key = "INTRO_STEP2_TAB", fallback = "2. Atividades" },
        { id = 3, key = "INTRO_STEP3_TAB", fallback = "3. Agenda" },
        { id = 4, key = "INTRO_STEP4_TAB", fallback = "4. Grupos" },
        { id = 5, key = "INTRO_STEP5_TAB", fallback = "5. Profissões" },
        { id = 6, key = "INTRO_STEP6_TAB", fallback = "6. Menções (@)" },
        { id = 7, key = "INTRO_STEP7_TAB", fallback = "7. Mapa" },
        { id = 8, key = "INTRO_STEP8_TAB", fallback = "8. Config & Aniv" },
    }
    self._stepTabsDefs = stepTabs
    self._stepButtons = {}

    local tabWidth = (750 - 36 - ((#stepTabs - 1) * 4)) / #stepTabs
    for i, tabData in ipairs(stepTabs) do
        local tabBtn = CreateFrame("Button", nil, frame, template)
        tabBtn:SetSize(tabWidth, 24)
        if i == 1 then
            tabBtn:SetPoint("TOPLEFT", headerSep, "BOTTOMLEFT", 0, -8)
        else
            tabBtn:SetPoint("LEFT", self._stepButtons[i - 1], "RIGHT", 4, 0)
        end

        local btnTxt = tabBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btnTxt:SetPoint("CENTER", tabBtn, "CENTER", 0, 0)
        btnTxt:SetText(curL[tabData.key] or tabData.fallback)
        tabBtn.text = btnTxt

        tabBtn:SetScript("OnClick", function()
            self:goToStep(i)
        end)

        self._stepButtons[i] = tabBtn
    end

    -- Container Central do Conteúdo do Passo
    local contentFrame = CreateFrame("Frame", "GM_IntroContentFrame", frame, template)
    contentFrame:SetPoint("TOPLEFT", self._stepButtons[1], "BOTTOMLEFT", 0, -8)
    contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 54)
    if contentFrame.SetBackdrop then
        contentFrame:SetBackdrop(CONTAINER_BACKDROP)
        contentFrame:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        contentFrame:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end
    self._contentFrame = contentFrame

    -- Criação dos 8 containers de etapas
    self:createStep1UI(contentFrame)
    self:createStep2UI(contentFrame)
    self:createStep3UI(contentFrame)
    self:createStep4UI(contentFrame)
    self:createStep5UI(contentFrame)
    self:createStep6UI(contentFrame)
    self:createStep7UI(contentFrame)
    self:createStep8UI(contentFrame)

    -- =========================================================================
    -- RODAPÉ DE NAVEGAÇÃO
    -- =========================================================================
    local footerSep = frame:CreateTexture(nil, "ARTWORK")
    footerSep:SetPoint("TOPLEFT", contentFrame, "BOTTOMLEFT", 0, -6)
    footerSep:SetPoint("RIGHT", frame, "RIGHT", -18, 0)
    footerSep:SetHeight(1)
    footerSep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- Botão Pular Tutorial (Rodapé)
    local skipBtn = CreateFrame("Button", "GM_IntroBottomSkipBtn", frame, "UIPanelButtonTemplate")
    skipBtn:SetSize(120, 24)
    skipBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 14)
    skipBtn:SetText(curL["INTRO_SKIP"] or "Pular Tutorial")
    skipBtn:SetScript("OnClick", function()
        self:skipTutorial()
    end)
    self._skipBtn = skipBtn

    -- Botão < Anterior
    local prevBtn = CreateFrame("Button", "GM_IntroPrevBtn", frame, "UIPanelButtonTemplate")
    prevBtn:SetSize(100, 24)
    prevBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -160, 14)
    prevBtn:SetText(curL["INTRO_PREV"] or "< Anterior")
    prevBtn:SetScript("OnClick", function()
        self:prevStep()
    end)
    self._prevBtn = prevBtn

    -- Indicador Passo X de 8
    local stepCounter = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stepCounter:SetPoint("RIGHT", prevBtn, "LEFT", -20, 0)
    stepCounter:SetText(string.format(curL["INTRO_STEP_COUNTER"] or "Passo %d de %d", 1, self._maxSteps))
    self._stepCounter = stepCounter

    -- Botão Próximo > / Concluir Tutorial
    local nextBtn = CreateFrame("Button", "GM_IntroNextBtn", frame, "UIPanelButtonTemplate")
    nextBtn:SetSize(130, 24)
    nextBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 14)
    nextBtn:SetText(curL["INTRO_NEXT"] or "Próximo >")
    nextBtn:SetScript("OnClick", function()
        if self._currentStep >= self._maxSteps then
            self:finishTutorial()
        else
            self:nextStep()
        end
    end)
    self._nextBtn = nextBtn

    self:goToStep(1)
end

-- =========================================================================
-- PASSO 1: AUDITORIA DA GUILDA
-- =========================================================================
function IntroView:createStep1UI(parent)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints(parent)
    self._stepContainers[1] = p

    local icon = p:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -16)
    icon:SetTexture("Interface\\Icons\\Achievement_GuildPerk_MassResurrection")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    title:SetText(curL["INTRO_STEP1_TITLE"] or "Auditoria da Guilda & Gestão de Membros")
    p.title = title

    local desc = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -12)
    desc:SetPoint("RIGHT", p, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetSpacing(4)
    p.desc = desc

    -- Card Ilustrativo de Demonstração
    local card = CreateFrame("Frame", nil, p, template)
    card:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    card:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 48)
    if card.SetBackdrop then
        card:SetBackdrop(SUB_CONTAINER_BACKDROP)
        card:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        card:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local cardHeader = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cardHeader:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -10)
    cardHeader:SetText("|cffffd200Exemplo ao Vivo da Tela de Auditoria:|r")

    local mockRows = {
        { name = "|cffc79c6eThorgrimm|r", rank = "Líder da Guilda", lvl = "60", pubNote = "Tanque Principal", offNote = "|cffff4040[SOMENTE OFICIAIS]|r", status = "|cff40ff40Online|r" },
        { name = "|cff69ccf0Sylphira|r", rank = "Oficial", lvl = "60", pubNote = "Maga Gelo / Alquimia", offNote = "|cffff4040[SOMENTE OFICIAIS]|r", status = "|cff40ff40Online|r" },
        { name = "|cfffff569Shadowalker|r", rank = "Membro", lvl = "54", pubNote = "Dungeon leveling", offNote = "|cffff4040[SOMENTE OFICIAIS]|r", status = "|cff888888Offline|r" },
    }

    local lastRow = nil
    for i, data in ipairs(mockRows) do
        local row = CreateFrame("Frame", nil, card, template)
        row:SetHeight(24)
        if i == 1 then
            row:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -32)
            row:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        else
            row:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, -4)
            row:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        end
        if row.SetBackdrop then
            row:SetBackdrop(SUB_CONTAINER_BACKDROP)
            row:SetBackdropColor(0.04, 0.03, 0.015, 0.60)
            row:SetBackdropBorderColor(0.40, 0.28, 0.10, 0.50)
        end

        local tName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tName:SetPoint("LEFT", row, "LEFT", 8, 0)
        tName:SetText(data.name)

        local tLvl = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        tLvl:SetPoint("LEFT", row, "LEFT", 110, 0)
        tLvl:SetText("Nível " .. data.lvl)

        local tRank = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tRank:SetPoint("LEFT", row, "LEFT", 175, 0)
        tRank:SetText("|cffffd200" .. data.rank .. "|r")

        local tNote = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tNote:SetPoint("LEFT", row, "LEFT", 300, 0)
        tNote:SetText("|cffaaaaaaNota:|r " .. data.pubNote)

        local tOff = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tOff:SetPoint("LEFT", row, "LEFT", 470, 0)
        tOff:SetText(data.offNote)

        local tSt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tSt:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        tSt:SetText(data.status)

        lastRow = row
    end

    local openBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    openBtn:SetSize(220, 24)
    openBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 16, 14)
    openBtn:SetText(curL["INTRO_STEP1_OPEN_BTN"] or "Abrir Tela de Auditoria (/gmaudit)")
    openBtn:SetScript("OnClick", function()
        if self._onOpenAuditCallback then
            self._onOpenAuditCallback()
        elseif _G.GM and _G.GM.auditController then
            _G.GM.auditController:show()
        end
    end)
    p.openBtn = openBtn
end

-- =========================================================================
-- PASSO 2: REGISTRO DE ATIVIDADES (LOGS)
-- =========================================================================
function IntroView:createStep2UI(parent)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints(parent)
    self._stepContainers[2] = p

    local icon = p:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -16)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    title:SetText(curL["INTRO_STEP2_TITLE"] or "Registro de Atividades da Guilda")
    p.title = title

    local desc = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -12)
    desc:SetPoint("RIGHT", p, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetSpacing(4)
    p.desc = desc

    -- Card Ilustrativo de Logs
    local card = CreateFrame("Frame", nil, p, template)
    card:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    card:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 48)
    if card.SetBackdrop then
        card:SetBackdrop(SUB_CONTAINER_BACKDROP)
        card:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        card:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local cardHeader = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cardHeader:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -10)
    cardHeader:SetText("|cffffd200Exemplo de Histórico & Badges de Eventos:|r")

    local mockLogs = {
        { date = "Hoje 14:20", text = "|cffc79c6eThorgrimm|r |cff40ff40RECRUTOU|r |cfffff569Shadowalker|r para a guilda." },
        { date = "Hoje 13:05", text = "|cff69ccf0Sylphira|r |cffffd91aSUBIU|r para o nível |cffffffff60|r!" },
        { date = "Ontem 19:40", text = "|cffc79c6eThorgrimm|r |cff00e5ffPROMOVEU|r |cff69ccf0Sylphira|r para o cargo |cffffd200Oficial|r." },
    }

    local lastRow = nil
    for i, log in ipairs(mockLogs) do
        local row = CreateFrame("Frame", nil, card, template)
        row:SetHeight(24)
        if i == 1 then
            row:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -32)
            row:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        else
            row:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, -4)
            row:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        end
        if row.SetBackdrop then
            row:SetBackdrop(SUB_CONTAINER_BACKDROP)
            row:SetBackdropColor(0.04, 0.03, 0.015, 0.60)
            row:SetBackdropBorderColor(0.40, 0.28, 0.10, 0.50)
        end

        local tDate = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        tDate:SetPoint("LEFT", row, "LEFT", 8, 0)
        tDate:SetText(log.date)

        local tMsg = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tMsg:SetPoint("LEFT", row, "LEFT", 120, 0)
        tMsg:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        tMsg:SetJustifyH("LEFT")
        tMsg:SetText(log.text)

        lastRow = row
    end

    local openBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    openBtn:SetSize(240, 24)
    openBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 16, 14)
    openBtn:SetText(curL["INTRO_STEP2_OPEN_BTN"] or "Abrir Registro de Atividades (/gmlogs)")
    openBtn:SetScript("OnClick", function()
        if self._onOpenLogsCallback then
            self._onOpenLogsCallback()
        elseif _G.GM and _G.GM.logController then
            _G.GM.logController:show()
        end
    end)
    p.openBtn = openBtn
end

-- =========================================================================
-- PASSO 3: AGENDA & CALENDÁRIO DA GUILDA
-- =========================================================================
function IntroView:createStep3UI(parent)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints(parent)
    self._stepContainers[3] = p

    local icon = p:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -16)
    local ok = icon:SetTexture("Interface\\Calendar\\UI-Calendar-Button")
    if ok == false or not icon:GetTexture() then
        icon:SetTexture("Interface\\Icons\\Spell_Holy_BoringSpell")
    else
        icon:SetTexCoord(0.0078, 0.375, 0.0156, 0.75)
    end

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    title:SetText(curL["INTRO_STEP3_TITLE"] or "Agenda & Calendário da Guilda")
    p.title = title

    local desc = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -12)
    desc:SetPoint("RIGHT", p, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetSpacing(4)
    p.desc = desc

    -- Card Ilustrativo da Agenda
    local card = CreateFrame("Frame", nil, p, template)
    card:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    card:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 48)
    if card.SetBackdrop then
        card:SetBackdrop(SUB_CONTAINER_BACKDROP)
        card:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        card:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local cardHeader = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cardHeader:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -10)
    cardHeader:SetText("|cffffd200Exemplo de Eventos no Calendário Mensal:|r")

    local mockEvents = {
        { tag = "|cffff6060[RAIDE]|r", title = "Núcleo Ígneo (Molten Core) - 20:00", leader = "Org: Thorgrimm" },
        { tag = "|cff40c0ff[MASMORRA]|r", title = "Pico da Rocha Negra Superior (UBRS) - 17:30", leader = "Org: Sylphira" },
        { tag = "|cffff80df[ANIVERSÁRIO]|r", title = "Aniversário de Sylphira - Parabéns!", leader = "Comemoração" },
    }

    local lastRow = nil
    for i, evt in ipairs(mockEvents) do
        local row = CreateFrame("Frame", nil, card, template)
        row:SetHeight(24)
        if i == 1 then
            row:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -32)
            row:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        else
            row:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, -4)
            row:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        end
        if row.SetBackdrop then
            row:SetBackdrop(SUB_CONTAINER_BACKDROP)
            row:SetBackdropColor(0.04, 0.03, 0.015, 0.60)
            row:SetBackdropBorderColor(0.40, 0.28, 0.10, 0.50)
        end

        local tTag = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tTag:SetPoint("LEFT", row, "LEFT", 8, 0)
        tTag:SetText(evt.tag)

        local tTitle = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tTitle:SetPoint("LEFT", tTag, "RIGHT", 8, 0)
        tTitle:SetText(evt.title)

        local tLdr = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        tLdr:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        tLdr:SetText(evt.leader)

        lastRow = row
    end

    local openBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    openBtn:SetSize(220, 24)
    openBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 16, 14)
    openBtn:SetText(curL["INTRO_STEP3_OPEN_BTN"] or "Abrir Agenda da Guilda (/gmagenda)")
    openBtn:SetScript("OnClick", function()
        if self._onOpenAgendaCallback then
            self._onOpenAgendaCallback()
        elseif _G.GM and _G.GM.agendaController then
            _G.GM.agendaController:show()
        end
    end)
    p.openBtn = openBtn
end

-- =========================================================================
-- PASSO 4: GERENCIAMENTO DE GRUPOS
-- =========================================================================
function IntroView:createStep4UI(parent)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints(parent)
    self._stepContainers[4] = p

    local icon = p:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -16)
    icon:SetTexture("Interface\\Icons\\Achievement_GuildPerk_HaveGroupWillTravel")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    title:SetText(curL["INTRO_STEP4_TITLE"] or "Gerenciamento de Grupos & Raides")
    p.title = title

    local desc = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -12)
    desc:SetPoint("RIGHT", p, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetSpacing(4)
    p.desc = desc

    -- Card Ilustrativo de Formação de Grupos
    local card = CreateFrame("Frame", nil, p, template)
    card:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    card:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 48)
    if card.SetBackdrop then
        card:SetBackdrop(SUB_CONTAINER_BACKDROP)
        card:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        card:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local cardHeader = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cardHeader:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -10)
    cardHeader:SetText("|cffffd200Equipe Escalada para Masmorra & Convite com 1 Clique:|r")

    local mockRoles = {
        { role = "|cff4aa0e0[TANQUE]|r", name = "|cffc79c6eThorgrimm|r", class = "Guerreiro (Nv 60)" },
        { role = "|cff40ff40[CURADOR]|r", name = "|cffffffffAluneth|r", class = "Sacerdote (Nv 60)" },
        { role = "|cffff4040[DANO 1]|r", name = "|cff69ccf0Sylphira|r", class = "Maga (Nv 60)" },
        { role = "|cffff4040[DANO 2]|r", name = "|cfffff569Shadowalker|r", class = "Ladino (Nv 58)" },
    }

    local lastRow = nil
    for i, rData in ipairs(mockRoles) do
        local row = CreateFrame("Frame", nil, card, template)
        row:SetHeight(22)
        if i == 1 then
            row:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -30)
            row:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        else
            row:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, -3)
            row:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        end
        if row.SetBackdrop then
            row:SetBackdrop(SUB_CONTAINER_BACKDROP)
            row:SetBackdropColor(0.04, 0.03, 0.015, 0.60)
            row:SetBackdropBorderColor(0.40, 0.28, 0.10, 0.50)
        end

        local tRole = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tRole:SetPoint("LEFT", row, "LEFT", 8, 0)
        tRole:SetText(rData.role)

        local tName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tName:SetPoint("LEFT", tRole, "RIGHT", 10, 0)
        tName:SetText(rData.name)

        local tCls = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        tCls:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        tCls:SetText(rData.class)

        lastRow = row
    end

    local openBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    openBtn:SetSize(240, 24)
    openBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 16, 14)
    openBtn:SetText(curL["INTRO_STEP4_OPEN_BTN"] or "Abrir Gerenciamento de Grupos (/gmgrupos)")
    openBtn:SetScript("OnClick", function()
        if self._onOpenGroupsCallback then
            self._onOpenGroupsCallback()
        elseif _G.GM and _G.GM.groupController then
            _G.GM.groupController:show()
        end
    end)
    p.openBtn = openBtn
end

-- =========================================================================
-- PASSO 5: PEDIDOS DE PROFISSÃO & ARTESÃOS
-- =========================================================================
function IntroView:createStep5UI(parent)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints(parent)
    self._stepContainers[5] = p

    local icon = p:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -16)
    icon:SetTexture("Interface\\Icons\\Trade_BlackSmithing")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    title:SetText(curL["INTRO_STEP5_TITLE"] or "Pedidos de Profissão & Artesãos da Guilda")
    p.title = title

    local desc = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -12)
    desc:SetPoint("RIGHT", p, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetSpacing(4)
    p.desc = desc

    -- Card Ilustrativo de Pedido de Profissão
    local card = CreateFrame("Frame", nil, p, template)
    card:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    card:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 48)
    if card.SetBackdrop then
        card:SetBackdrop(SUB_CONTAINER_BACKDROP)
        card:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        card:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local cardHeader = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cardHeader:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -10)
    cardHeader:SetText("|cffffd200Exemplo de Pedido de Fabricação no Quadro da Guilda:|r")

    local mockOrders = {
        { item = "|cffa335ee[Frasco de Poder Titânico]|r", crafter = "Artesão: Sylphira", tip = "Comissão: |cffffd70015 Ouro|r", status = "|cff40ff40Pendente|r" },
        { item = "|cff0070dd[Armadura de Placas de Ferro Negro]|r", crafter = "Artesão: Thorgrimm", tip = "Comissão: |cffffd70025 Ouro|r", status = "|cffffff00Em Fabricação|r" },
        { item = "|cffa335ee[Manto de Feitiçaria]|r", crafter = "Qualquer Artesão", tip = "Comissão: |cffffd70010 Ouro|r", status = "|cff40ff40Aberto à Guilda|r" },
    }

    local lastRow = nil
    for i, oData in ipairs(mockOrders) do
        local row = CreateFrame("Frame", nil, card, template)
        row:SetHeight(24)
        if i == 1 then
            row:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -32)
            row:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        else
            row:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, -4)
            row:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        end
        if row.SetBackdrop then
            row:SetBackdrop(SUB_CONTAINER_BACKDROP)
            row:SetBackdropColor(0.04, 0.03, 0.015, 0.60)
            row:SetBackdropBorderColor(0.40, 0.28, 0.10, 0.50)
        end

        local tItem = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tItem:SetPoint("LEFT", row, "LEFT", 8, 0)
        tItem:SetText(oData.item)

        local tCrafter = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tCrafter:SetPoint("LEFT", row, "LEFT", 220, 0)
        tCrafter:SetText(oData.crafter)

        local tTip = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tTip:SetPoint("LEFT", row, "LEFT", 380, 0)
        tTip:SetText(oData.tip)

        local tStatus = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tStatus:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        tStatus:SetText(oData.status)

        lastRow = row
    end

    local openBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    openBtn:SetSize(230, 24)
    openBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 16, 14)
    openBtn:SetText(curL["INTRO_STEP5_OPEN_BTN"] or "Abrir Pedidos de Profissão (/gmcraft)")
    openBtn:SetScript("OnClick", function()
        if self._onOpenProfessionsCallback then
            self._onOpenProfessionsCallback()
        elseif _G.GM and _G.GM.professionController then
            _G.GM.professionController:show()
        end
    end)
    p.openBtn = openBtn
end

-- =========================================================================
-- PASSO 6: MENÇÕES NO CHAT COM @ E ALERTA SONORO
-- =========================================================================
function IntroView:createStep6UI(parent)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints(parent)
    self._stepContainers[6] = p

    local icon = p:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -16)
    icon:SetTexture("Interface\\Icons\\Spell_Holy_Silence")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    title:SetText(curL["INTRO_STEP6_TITLE"] or "Menções no Chat com @ e Alerta Sonoro")
    p.title = title

    local desc = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -12)
    desc:SetPoint("RIGHT", p, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetSpacing(4)
    p.desc = desc

    -- Card Ilustrativo de Chat
    local card = CreateFrame("Frame", nil, p, template)
    card:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    card:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 48)
    if card.SetBackdrop then
        card:SetBackdrop(SUB_CONTAINER_BACKDROP)
        card:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        card:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local chatHeader = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chatHeader:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -12)
    chatHeader:SetText("|cffffd200Demonstração de Menção em Mensagem de Chat:|r")

    local myName = UnitName("player") or "Você"
    local chatBox = CreateFrame("Frame", nil, card, template)
    chatBox:SetPoint("TOPLEFT", chatHeader, "BOTTOMLEFT", 0, -8)
    chatBox:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    chatBox:SetHeight(48)
    if chatBox.SetBackdrop then
        chatBox:SetBackdrop(SUB_CONTAINER_BACKDROP)
        chatBox:SetBackdropColor(0, 0, 0, 0.70)
        chatBox:SetBackdropBorderColor(0.45, 0.35, 0.15, 0.70)
    end

    local chatMsg = chatBox:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
    chatMsg:SetPoint("LEFT", chatBox, "LEFT", 12, 0)
    chatMsg:SetPoint("RIGHT", chatBox, "RIGHT", -12, 0)
    chatMsg:SetJustifyH("LEFT")
    chatMsg:SetText(string.format("|cff3ce73c[Guilda]|r |cffc79c6e[Thorgrimm]|r: Ei |cff00ffff@%s|r, vamos fechar o grupo da masmorra agora!", myName))
    p.chatMsg = chatMsg

    -- Botão de Teste Sonoro
    local soundBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
    soundBtn:SetSize(220, 26)
    soundBtn:SetPoint("TOPLEFT", chatBox, "BOTTOMLEFT", 0, -14)
    soundBtn:SetText(curL["INTRO_STEP6_TEST_SOUND"] or "Ouvir Som da Notificação")
    soundBtn:SetScript("OnClick", function()
        if _G.GM and _G.GM.chatMentionView and _G.GM.chatMentionView.playMentionSound then
            _G.GM.chatMentionView:playMentionSound()
        elseif PlaySound then
            pcall(PlaySound, 3081, "Master")
        end
    end)
    p.soundBtn = soundBtn

    local soundHint = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    soundHint:SetPoint("LEFT", soundBtn, "RIGHT", 12, 0)
    soundHint:SetText("|cffaaaaaa(Clique para testar o som que tocará quando você for marcado)|r")
end

-- =========================================================================
-- PASSO 7: MAPA MUNDIAL & MEMBROS POR REGIÃO
-- =========================================================================
function IntroView:createStep7UI(parent)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints(parent)
    self._stepContainers[7] = p

    local icon = p:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -16)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Compass_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    title:SetText(curL["INTRO_STEP7_TITLE"] or "Mapa Mundial & Membros por Região")
    p.title = title

    local desc = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -12)
    desc:SetPoint("RIGHT", p, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetSpacing(4)
    p.desc = desc

    -- Card Ilustrativo de Regiões
    local card = CreateFrame("Frame", nil, p, template)
    card:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    card:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 48)
    if card.SetBackdrop then
        card:SetBackdrop(SUB_CONTAINER_BACKDROP)
        card:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        card:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local mapHeader = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mapHeader:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -12)
    mapHeader:SetText("|cffffd200Visualização no Mapa Mundial (M):|r")

    local mockZones = {
        { zone = "Ventobravo / Stormwind", count = "4 membros online", names = "Thorgrimm, Sylphira, Aluneth, Durgar" },
        { zone = "Selva do Espinhaço", count = "2 membros explorando", names = "Shadowalker, Valerius" },
        { zone = "Cavernas das Lamentações", count = "3 membros em grupo", names = "Brakkar, Kaelen, Moira" },
    }

    local lastRow = nil
    for i, zData in ipairs(mockZones) do
        local row = CreateFrame("Frame", nil, card, template)
        row:SetHeight(24)
        if i == 1 then
            row:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -32)
            row:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        else
            row:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, -4)
            row:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        end
        if row.SetBackdrop then
            row:SetBackdrop(SUB_CONTAINER_BACKDROP)
            row:SetBackdropColor(0.04, 0.03, 0.015, 0.60)
            row:SetBackdropBorderColor(0.40, 0.28, 0.10, 0.50)
        end

        local tPin = row:CreateTexture(nil, "ARTWORK")
        tPin:SetSize(14, 14)
        tPin:SetPoint("LEFT", row, "LEFT", 8, 0)
        tPin:SetTexture("Interface\\WorldMap\\Skull_64Red")

        local tZone = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tZone:SetPoint("LEFT", tPin, "RIGHT", 6, 0)
        tZone:SetText("|cffffffff" .. zData.zone .. "|r  |cffaaaaaa(" .. zData.count .. ")|r")

        local tNames = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        tNames:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        tNames:SetText("|cff888888" .. zData.names .. "|r")

        lastRow = row
    end

    local openBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    openBtn:SetSize(200, 24)
    openBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 16, 14)
    openBtn:SetText(curL["INTRO_STEP7_OPEN_MAP"] or "Abrir Mapa Mundial (M)")
    openBtn:SetScript("OnClick", function()
        if ToggleWorldMap then
            ToggleWorldMap()
        end
    end)
    p.openBtn = openBtn
end

-- =========================================================================
-- PASSO 8: CONFIGURAÇÕES & DATA DE ANIVERSÁRIO
-- =========================================================================
function IntroView:createStep8UI(parent)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints(parent)
    self._stepContainers[8] = p

    local icon = p:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -16)
    icon:SetTexture("Interface\\Icons\\Trade_Engineering")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    title:SetText(curL["INTRO_STEP8_TITLE"] or "Configurações Gerais & Seu Aniversário")
    p.title = title

    local desc = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -12)
    desc:SetPoint("RIGHT", p, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetSpacing(4)
    p.desc = desc

    -- Card Especial para Configuração do Aniversário
    local card = CreateFrame("Frame", nil, p, template)
    card:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    card:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 48)
    if card.SetBackdrop then
        card:SetBackdrop(SUB_CONTAINER_BACKDROP)
        card:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        card:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local bdayIcon = card:CreateTexture(nil, "ARTWORK")
    bdayIcon:SetSize(24, 24)
    bdayIcon:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -12)
    bdayIcon:SetTexture("Interface\\Icons\\INV_Misc_Gift_01")
    bdayIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local bdayTitle = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bdayTitle:SetPoint("LEFT", bdayIcon, "RIGHT", 8, 0)
    bdayTitle:SetText(curL["INTRO_STEP8_BDAY_TITLE"] or "Comemore seu Aniversário com a Guilda!")
    p.bdayTitle = bdayTitle

    local bdayDesc = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bdayDesc:SetPoint("TOPLEFT", bdayIcon, "BOTTOMLEFT", 0, -8)
    bdayDesc:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    bdayDesc:SetJustifyH("LEFT")
    bdayDesc:SetText(curL["INTRO_STEP8_BDAY_DESC"] or "Informe sua data de aniversário para receber os parabéns da guilda e figurar na Agenda:")
    p.bdayDesc = bdayDesc

    -- Campo de Entrada (EditBox) com Estilo WoW Forever
    local bdayEB = CreateFrame("EditBox", "GM_IntroBirthdayEB", card, template)
    bdayEB:SetSize(120, 26)
    bdayEB:SetPoint("TOPLEFT", bdayDesc, "BOTTOMLEFT", 0, -10)
    bdayEB:SetFontObject("GameFontHighlight")
    bdayEB:SetAutoFocus(false)
    bdayEB:SetMaxLetters(5)
    bdayEB:SetTextInsets(8, 8, 1, 1)
    if bdayEB.SetBackdrop then
        bdayEB:SetBackdrop(SUB_CONTAINER_BACKDROP)
        bdayEB:SetBackdropColor(PALETTE.FOCUS_BG[1], PALETTE.FOCUS_BG[2], PALETTE.FOCUS_BG[3], PALETTE.FOCUS_BG[4])
        bdayEB:SetBackdropBorderColor(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], PALETTE.FOCUS_BORDER[4])
    end
    self._birthdayEB = bdayEB

    local bdayHint = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    bdayHint:SetPoint("LEFT", bdayEB, "RIGHT", 12, 0)
    self._birthdayHint = bdayHint

    local statusTxt = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusTxt:SetPoint("TOPLEFT", bdayEB, "BOTTOMLEFT", 0, -8)
    statusTxt:SetText("")
    self._birthdayStatusTxt = statusTxt

    -- Validação e auto-formatação ao digitar
    bdayEB:SetScript("OnTextChanged", function(box)
        local raw = box:GetText() or ""
        -- Auto insere barra se o usuário digitou 2 dígitos numéricos
        if raw:match("^%d%d$") and not raw:find("/") then
            box:SetText(raw .. "/")
            box:SetCursorPosition(3)
            return
        end

        local isValid, normalized = self:validateBirthday(raw)
        if raw == "" then
            statusTxt:SetText(curL["INTRO_STEP8_BDAY_OPTIONAL"] or "(Opcional - você também pode preencher depois na Auditoria)")
        elseif isValid then
            statusTxt:SetText(curL["INTRO_STEP8_BDAY_VALID"] or "|cff40ff40Data válida! Pronta para salvar.|r")
        else
            local isEn = (_G.GM and _G.GM.GetLocale and _G.GM.GetLocale() == "enUS")
            local fmt = isEn and "MM/dd (ex: 07/15)" or "dd/MM (ex: 15/07)"
            statusTxt:SetText(string.format(curL["INTRO_STEP8_BDAY_INVALID"] or "|cffff4040Data inválida. Digite no formato %s|r", fmt))
        end
    end)

    -- Botão Salvar Aniversário Agora
    local saveBdayBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
    saveBdayBtn:SetSize(130, 24)
    saveBdayBtn:SetPoint("TOPLEFT", statusTxt, "BOTTOMLEFT", 0, -10)
    saveBdayBtn:SetText("Salvar Aniversário")
    saveBdayBtn:SetScript("OnClick", function()
        self:saveBirthdayField()
    end)
    self._saveBdayBtn = saveBdayBtn

    local openConfigBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    openConfigBtn:SetSize(220, 24)
    openConfigBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 16, 14)
    openConfigBtn:SetText(curL["INTRO_STEP8_OPEN_CONFIG"] or "Abrir Configurações (/gmconfig)")
    openConfigBtn:SetScript("OnClick", function()
        if self._onOpenSettingsCallback then
            self._onOpenSettingsCallback()
        elseif _G.GM and _G.GM.settingsController then
            _G.GM.settingsController:show()
        end
    end)
    p.openConfigBtn = openConfigBtn
end

-- =========================================================================
-- CONTROLE DE NAVEGAÇÃO DOS PASSOS
-- =========================================================================

--- Valida a data de aniversário digitada pelo usuário de acordo com o idioma ativo.
---@param text string
---@return boolean isValid
---@return string normalized
function IntroView:validateBirthday(text)
    if not text or text == "" then return false, "" end
    local clean = text:match("^%s*(.-)%s*$")
    local num1, num2 = clean:match("^(%d%d?)[/%-%.](%d%d?)$")
    if not num1 or not num2 then return false, "" end

    local n1 = tonumber(num1)
    local n2 = tonumber(num2)
    if not n1 or not n2 then return false, "" end

    local isEn = (_G.GM and _G.GM.GetLocale and _G.GM.GetLocale() == "enUS")
    local day, month

    if isEn then
        -- MM/dd
        month, day = n1, n2
    else
        -- dd/MM
        day, month = n1, n2
    end

    if month >= 1 and month <= 12 and day >= 1 and day <= 31 then
        local formatted = string.format("%02d/%02d", isEn and month or day, isEn and day or month)
        return true, formatted
    end

    return false, ""
end

--- Salva a data de aniversário preenchida no campo.
function IntroView:saveBirthdayField()
    if not self._birthdayEB then return end
    local raw = self._birthdayEB:GetText() or ""
    local isValid, formatted = self:validateBirthday(raw)
    local curL = (_G.GM and _G.GM.L) or _G.L or L

    if isValid then
        if self._onBirthdaySubmittedCallback then
            self._onBirthdaySubmittedCallback(formatted, true)
        end
        if self._birthdayStatusTxt then
            self._birthdayStatusTxt:SetText(string.format("|cff40ff40" .. (curL["INTRO_STEP8_BDAY_SAVED"] or "Aniversário configurado: %s") .. "|r", formatted))
        end
    elseif raw ~= "" then
        if self._birthdayStatusTxt then
            local isEn = (_G.GM and _G.GM.GetLocale and _G.GM.GetLocale() == "enUS")
            local fmt = isEn and "MM/dd" or "dd/MM"
            self._birthdayStatusTxt:SetText(string.format(curL["INTRO_STEP8_BDAY_INVALID"] or "|cffff4040Data inválida. Digite no formato %s|r", fmt))
        end
    end
end

--- Muda para uma etapa específica do tutorial.
---@param step number
function IntroView:goToStep(step)
    local target = math.max(1, math.min(step or 1, self._maxSteps))
    self._currentStep = target

    for i = 1, self._maxSteps do
        local c = self._stepContainers[i]
        if c then
            if i == target then c:Show() else c:Hide() end
        end

        local btn = self._stepButtons[i]
        if btn then
            local isActive = (i == target)
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
                    btn.text:SetTextColor(0.70, 0.70, 0.70)
                end
            end
        end
    end

    local curL = (_G.GM and _G.GM.L) or _G.L or L
    if self._stepCounter then
        self._stepCounter:SetText(string.format(curL["INTRO_STEP_COUNTER"] or "Passo %d de %d", target, self._maxSteps))
    end

    if self._prevBtn then
        if target > 1 then
            self._prevBtn:Enable()
        else
            self._prevBtn:Disable()
        end
    end

    if self._nextBtn then
        if target >= self._maxSteps then
            self._nextBtn:SetText(curL["INTRO_FINISH"] or "Concluir Tutorial")
        else
            self._nextBtn:SetText(curL["INTRO_NEXT"] or "Próximo >")
        end
    end

    -- Atualiza hints específicos do passo 8 (aniversário)
    if target == 8 and self._birthdayHint then
        local isEn = (_G.GM and _G.GM.GetLocale and _G.GM.GetLocale() == "enUS")
        local hintText = isEn and (curL["INTRO_STEP8_BDAY_FORMAT_HINT"] or "Format: MM/dd (e.g. 07/15)") or (curL["INTRO_STEP8_BDAY_FORMAT_HINT"] or "Formato: dd/MM (Exemplo: 15/07)")
        self._birthdayHint:SetText("|cffaaaaaa" .. hintText .. "|r")

        -- Preenche com o aniversário atual se já existir
        if self._birthdayEB and (self._birthdayEB:GetText() or "") == "" then
            local existing = nil
            if _G.GM and _G.GM.memberService then
                local m = _G.GM.memberService:getMember(UnitName("player") or "")
                if m then existing = m:getBirthday() end
            end
            if not existing and _G.GM_DB then
                existing = _G.GM_DB.playerBirthday or (_G.GM_DB.settings and _G.GM_DB.settings.playerBirthday)
            end
            if existing and existing ~= "" then
                self._birthdayEB:SetText(existing)
            end
        end
    end
end

--- Avança para o próximo passo.
function IntroView:nextStep()
    self:goToStep(self._currentStep + 1)
end

--- Retorna ao passo anterior.
function IntroView:prevStep()
    self:goToStep(self._currentStep - 1)
end

--- Pula o tutorial imediatamente a pedido do jogador.
function IntroView:skipTutorial()
    if self._introFrame then
        self._introFrame:Hide()
    end
    if self._onSkipCallback then
        self._onSkipCallback()
    end
end

--- Conclui o tutorial no passo final.
function IntroView:finishTutorial()
    self:saveBirthdayField()

    if self._introFrame then
        self._introFrame:Hide()
    end
    if self._onCompleteCallback then
        self._onCompleteCallback()
    end
end

--- Atualiza dinamicamente todos os textos da interface para o idioma ativo.
function IntroView:updateLocale()
    self:updateNoGuildTexts()

    local curL = (_G.GM and _G.GM.L) or _G.L or L
    if not self._introFrame then return end

    if self._introTitle then self._introTitle:SetText(curL["INTRO_TITLE"] or "|cffffd200GUILD MANAGER FOREVER|r") end
    if self._introSub then self._introSub:SetText(curL["INTRO_SUBTITLE"] or "Guia Rápido de Introdução & Recursos") end
    if self._topSkipBtn then self._topSkipBtn:SetText(curL["INTRO_SKIP"] or "Pular Tutorial") end
    if self._skipBtn then self._skipBtn:SetText(curL["INTRO_SKIP"] or "Pular Tutorial") end
    if self._prevBtn then self._prevBtn:SetText(curL["INTRO_PREV"] or "< Anterior") end

    -- Abas dos passos
    if self._stepTabsDefs and self._stepButtons then
        for i, tabDef in ipairs(self._stepTabsDefs) do
            local b = self._stepButtons[i]
            if b and b.text then
                b.text:SetText(curL[tabDef.key] or tabDef.fallback)
            end
        end
    end

    -- Passo 1
    local p1 = self._stepContainers[1]
    if p1 then
        if p1.title then p1.title:SetText(curL["INTRO_STEP1_TITLE"] or "Auditoria da Guilda & Gestão de Membros") end
        if p1.desc then
            local d1 = curL["INTRO_STEP1_DESC1"] or ""
            local d2 = curL["INTRO_STEP1_DESC2"] or ""
            local d3 = curL["INTRO_STEP1_DESC3"] or ""
            p1.desc:SetText(d1 .. "\n\n" .. d2 .. "\n\n" .. d3)
        end
        if p1.openBtn then p1.openBtn:SetText(curL["INTRO_STEP1_OPEN_BTN"] or "Abrir Tela de Auditoria (/gmaudit)") end
    end

    -- Passo 2
    local p2 = self._stepContainers[2]
    if p2 then
        if p2.title then p2.title:SetText(curL["INTRO_STEP2_TITLE"] or "Registro de Atividades da Guilda") end
        if p2.desc then
            local d1 = curL["INTRO_STEP2_DESC1"] or ""
            local d2 = curL["INTRO_STEP2_DESC2"] or ""
            local d3 = curL["INTRO_STEP2_DESC3"] or ""
            p2.desc:SetText(d1 .. "\n\n" .. d2 .. "\n\n" .. d3)
        end
        if p2.openBtn then p2.openBtn:SetText(curL["INTRO_STEP2_OPEN_BTN"] or "Abrir Registro de Atividades (/gmlogs)") end
    end

    -- Passo 3
    local p3 = self._stepContainers[3]
    if p3 then
        if p3.title then p3.title:SetText(curL["INTRO_STEP3_TITLE"] or "Agenda & Calendário da Guilda") end
        if p3.desc then
            local d1 = curL["INTRO_STEP3_DESC1"] or ""
            local d2 = curL["INTRO_STEP3_DESC2"] or ""
            local d3 = curL["INTRO_STEP3_DESC3"] or ""
            p3.desc:SetText(d1 .. "\n\n" .. d2 .. "\n\n" .. d3)
        end
        if p3.openBtn then p3.openBtn:SetText(curL["INTRO_STEP3_OPEN_BTN"] or "Abrir Agenda da Guilda (/gmagenda)") end
    end

    -- Passo 4
    local p4 = self._stepContainers[4]
    if p4 then
        if p4.title then p4.title:SetText(curL["INTRO_STEP4_TITLE"] or "Gerenciamento de Grupos & Raides") end
        if p4.desc then
            local d1 = curL["INTRO_STEP4_DESC1"] or ""
            local d2 = curL["INTRO_STEP4_DESC2"] or ""
            local d3 = curL["INTRO_STEP4_DESC3"] or ""
            p4.desc:SetText(d1 .. "\n\n" .. d2 .. "\n\n" .. d3)
        end
        if p4.openBtn then p4.openBtn:SetText(curL["INTRO_STEP4_OPEN_BTN"] or "Abrir Gerenciamento de Grupos (/gmgrupos)") end
    end

    -- Passo 5
    local p5 = self._stepContainers[5]
    if p5 then
        if p5.title then p5.title:SetText(curL["INTRO_STEP5_TITLE"] or "Pedidos de Profissão & Artesãos da Guilda") end
        if p5.desc then
            local d1 = curL["INTRO_STEP5_DESC1"] or ""
            local d2 = curL["INTRO_STEP5_DESC2"] or ""
            local d3 = curL["INTRO_STEP5_DESC3"] or ""
            p5.desc:SetText(d1 .. "\n\n" .. d2 .. "\n\n" .. d3)
        end
        if p5.openBtn then p5.openBtn:SetText(curL["INTRO_STEP5_OPEN_BTN"] or "Abrir Pedidos de Profissão (/gmcraft)") end
    end

    -- Passo 6
    local p6 = self._stepContainers[6]
    if p6 then
        if p6.title then p6.title:SetText(curL["INTRO_STEP6_TITLE"] or "Menções no Chat com @ e Alerta Sonoro") end
        if p6.desc then
            local d1 = curL["INTRO_STEP6_DESC1"] or ""
            local d2 = curL["INTRO_STEP6_DESC2"] or ""
            p6.desc:SetText(d1 .. "\n\n" .. d2)
        end
        if p6.soundBtn then p6.soundBtn:SetText(curL["INTRO_STEP6_TEST_SOUND"] or "Ouvir Som da Notificação") end
        if p6.chatMsg then
            local myName = UnitName("player") or "Você"
            p6.chatMsg:SetText(string.format("|cff3ce73c[Guilda]|r |cffc79c6e[Thorgrimm]|r: Ei |cff00ffff@%s|r, vamos fechar o grupo da masmorra agora!", myName))
        end
    end

    -- Passo 7
    local p7 = self._stepContainers[7]
    if p7 then
        if p7.title then p7.title:SetText(curL["INTRO_STEP7_TITLE"] or "Mapa Mundial & Membros por Região") end
        if p7.desc then
            local d1 = curL["INTRO_STEP7_DESC1"] or ""
            local d2 = curL["INTRO_STEP7_DESC2"] or ""
            p7.desc:SetText(d1 .. "\n\n" .. d2)
        end
        if p7.openBtn then p7.openBtn:SetText(curL["INTRO_STEP7_OPEN_MAP"] or "Abrir Mapa Mundial (M)") end
    end

    -- Passo 8
    local p8 = self._stepContainers[8]
    if p8 then
        if p8.title then p8.title:SetText(curL["INTRO_STEP8_TITLE"] or "Configurações Gerais & Seu Aniversário") end
        if p8.desc then p8.desc:SetText(curL["INTRO_STEP8_DESC1"] or "") end
        if p8.bdayTitle then p8.bdayTitle:SetText(curL["INTRO_STEP8_BDAY_TITLE"] or "Comemore seu Aniversário com a Guilda!") end
        if p8.bdayDesc then p8.bdayDesc:SetText(curL["INTRO_STEP8_BDAY_DESC"] or "Informe sua data de aniversário para receber os parabéns da guilda e figurar na Agenda:") end
        if p8.openConfigBtn then p8.openConfigBtn:SetText(curL["INTRO_STEP8_OPEN_CONFIG"] or "Abrir Configurações (/gmconfig)") end
    end

    self:goToStep(self._currentStep or 1)
end

--- Exibe a janela de introdução.
function IntroView:show()
    self:createIntroUI()
    self:updateLocale()
    self:goToStep(1)
    if self._introFrame then
        self._introFrame:Show()
    end
end

--- Oculta a janela de introdução.
function IntroView:hide()
    if self._introFrame then
        self._introFrame:Hide()
    end
end

--- Retorna se a introdução está visível na tela.
---@return boolean
function IntroView:isShown()
    return self._introFrame and self._introFrame:IsShown() or false
end

_G.IntroView = IntroView
