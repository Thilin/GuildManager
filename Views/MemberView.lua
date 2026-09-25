local RACE_TRANSLATION_PT = {
    ["human"] = "Humano",
    ["humano"] = "Humano",
    ["dwarf"] = "Anão",
    ["anão"] = "Anão",
    ["anao"] = "Anão",
    ["nightelf"] = "Elfo Noturno",
    ["night elf"] = "Elfo Noturno",
    ["elfo noturno"] = "Elfo Noturno",
    ["gnome"] = "Gnomo",
    ["gnomo"] = "Gnomo",
    ["draenei"] = "Draenei",
    ["orc"] = "Orc",
    ["undead"] = "Morto-vivo",
    ["scourge"] = "Morto-vivo",
    ["morto-vivo"] = "Morto-vivo",
    ["morto vivo"] = "Morto-vivo",
    ["renegado"] = "Morto-vivo",
    ["tauren"] = "Tauren",
    ["troll"] = "Troll",
    ["bloodelf"] = "Elfo Sangrento",
    ["blood elf"] = "Elfo Sangrento",
    ["elfo sangrento"] = "Elfo Sangrento",
}

local function getRaceInPortuguese(race)
    if not race or race == "" then return "" end
    local clean = race:match("^%s*(.-)%s*$"):lower()
    return RACE_TRANSLATION_PT[clean] or race
end

local REPUTATION_NAMES = {
    [1] = "|cffcc2222Odiado|r",
    [2] = "|cffff0000Hostil|r",
    [3] = "|cffee6622Desfavorável|r",
    [4] = "|cffffff00Neutro|r",
    [5] = "|cff00ff00Amigável|r",
    [6] = "|cff00ff88Honrado|r",
    [7] = "|cff00ffffReverenciado|r",
    [8] = "|cff9966ffExaltado|r",
}

local function getReputationText(standing)
    local n = tonumber(standing)
    if n and REPUTATION_NAMES[n] then
        return REPUTATION_NAMES[n]
    end
    if n and _G["FACTION_STANDING_LABEL" .. n] then
        return _G["FACTION_STANDING_LABEL" .. n]
    end
    return "|cff888888Neutro|r"
end

---@class MemberView
MemberView = {}
MemberView.__index = MemberView

--- Construtor da View de Membro no padrão MVC.
---@return MemberView
function MemberView:new()
    local instance = setmetatable({}, self)

    instance._frame = nil
    instance._isLocked = false
    instance._currentMember = nil
    instance._onSaveCallback = nil
    instance._isMain = true
    instance._factionIcon = nil
    instance._raceText = nil
    instance._memberNameText = nil
    instance._mainTagBtn = nil
    instance._mainTagText = nil
    instance._levelVal = nil
    instance._classVal = nil
    instance._rankVal = nil
    instance._repVal = nil
    instance._recruiterBtn = nil
    instance._recruiterBtnText = nil
    instance._recruiterPickerFrame = nil
    instance._pickerRows = {}
    instance._pickerFilteredList = {}
    instance._pickerOffset = 0
    instance._guildMembersProvider = nil
    instance._memberLookupCallback = nil

    instance._altsBtn = nil
    instance._altsVal = nil
    instance._altManagerFrame = nil
    instance._altFamilyRows = {}
    instance._altFamilyList = {}
    instance._altFamilyOffset = 0
    instance._altFamilyScrollBar = nil
    instance._availableAltRows = {}
    instance._availableAltsFilteredList = {}
    instance._availableAltsOffset = 0

    instance:createUI()

    return instance
end

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

--- Paleta de cores oficial baseada na interface Blizzard / WoW Forever:
--- Tom médio predominante (bronze/dourado escuro): #784916 a #8C5919
--- Realces mais claros (brilho): #B57C2A
--- Sombras (metal escuro): #3A2109
local PALETTE = {
    -- Janelas principais (GuildManagerMemberFrame, RecruiterPickerFrame, AltManagerFrame)
    FRAME_BG = { 0.055, 0.035, 0.015, 1.0 },
    FRAME_BORDER = { 1.0, 0.68, 0.22, 1.0 },

    -- Painéis internos / Insets (Containers com contorno bronze calibrado aos realces #B57C2A)
    INSET_BG = { 0.035, 0.022, 0.010, 0.70 },
    INSET_BORDER = { 0.71, 0.49, 0.16, 0.95 },

    -- Linhas divisórias (Separators / Tracejados calibrados no tom médio #8C5919 / #784916)
    SEPARATOR = { 0.58, 0.37, 0.11, 0.90 },

    -- Caixas de edição e sub-containers (EditBoxes, NoteBoxes, Recruiter, Alts no tom #784916)
    SUB_BOX_BG = { 0.022, 0.014, 0.006, 0.75 },
    SUB_BOX_BORDER = { 0.62, 0.41, 0.13, 0.90 },

    -- Estados de foco e hover (Realce metálico dourado #B57C2A)
    FOCUS_BG = { 0.065, 0.045, 0.020, 0.95 },
    FOCUS_BORDER = { 0.85, 0.58, 0.20, 1.0 },
    HIGHLIGHT_TINT = { 0.71, 0.49, 0.16, 0.12 },

    -- Tags Main / Alt
    MAIN_TAG_BG = { 0.16, 0.10, 0.03, 0.95 },
    MAIN_TAG_BORDER = { 0.85, 0.58, 0.20, 1.0 },
    ALT_TAG_BG = { 0.055, 0.035, 0.015, 0.95 },
    ALT_TAG_BORDER = { 0.62, 0.41, 0.13, 0.90 },
}

--- Cria e estiliza os componentes visuais da janela de membro no padrão clássico Blizzard.
function MemberView:createUI()
    if self._frame then
        return
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "GuildManagerMemberFrame", UIParent, template)
    self._frame = frame

    frame:SetSize(370, 528)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    frame:Hide()

    -- Salvamento automático ao fechar a janela
    frame:SetScript("OnHide", function()
        self:saveCurrentMember()
        if self._recruiterPickerFrame then
            self._recruiterPickerFrame:Hide()
        end
        if self._altManagerFrame then
            self._altManagerFrame:Hide()
        end
    end)

    -- Camada sólida de base (evita qualquer vazamento do mundo 3D ou janelas de fundo)
    local solidBg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    solidBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    solidBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    solidBg:SetColorTexture(0.04, 0.03, 0.02, 1.0)

    -- Textura de fundo customizada em pergaminho (Textures\background.tga convertida a partir de background.jpg)
    local bgTex = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    bgTex:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    bgTex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    bgTex:SetTexture("Interface\\AddOns\\GuildManager\\Textures\\background.tga")
    bgTex:SetHorizTile(false)
    bgTex:SetVertTile(false)
    bgTex:SetAlpha(0.50) -- Opacidade ajustada para 50%
    self._bgTex = bgTex

    -- Fundo e bordas no padrão clássico Blizzard / WoW Forever (cantos ornamentados e moldura bronze/dourada)
    if frame.SetBackdrop then
        frame:SetBackdrop(DIALOG_BACKDROP)
        frame:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], 0.20)
        frame:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], PALETTE.FRAME_BORDER[4])
    end

    -- Botão Fechar ("X" clássico vermelho com moldura dourada)
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetSize(28, 28)
    closeBtn:SetScript("OnClick", function()
        self:setLocked(false)
        self:saveCurrentMember()
        self._frame:Hide()
    end)

    -- Identificação do Personagem (Centralizado no topo da janela)
    local memberNameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    memberNameText:SetPoint("TOP", frame, "TOP", 0, -18)
    memberNameText:SetJustifyH("CENTER")
    self._memberNameText = memberNameText

    -- Ícone da Facção (Alinhado ao lado esquerdo do nome do membro)
    local factionIcon = frame:CreateTexture(nil, "ARTWORK")
    factionIcon:SetSize(24, 24)
    factionIcon:SetPoint("RIGHT", memberNameText, "LEFT", -8, 0)
    self._factionIcon = factionIcon

    -- Raça do Jogador (Exibida diretamente abaixo do nome do membro)
    local raceText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    raceText:SetPoint("TOP", memberNameText, "BOTTOM", 0, -3)
    raceText:SetJustifyH("CENTER")
    self._raceText = raceText

    -- Tag interativa de Main/Alt ('M' para Main, 'A' para Alt - Alinhada ao lado direito do nome)
    local mainTagBtn = CreateFrame("Button", nil, frame, template)
    mainTagBtn:SetSize(24, 18)
    mainTagBtn:SetPoint("LEFT", memberNameText, "RIGHT", 8, 0)
    if mainTagBtn.SetBackdrop then
        mainTagBtn:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        mainTagBtn:SetBackdropColor(PALETTE.MAIN_TAG_BG[1], PALETTE.MAIN_TAG_BG[2], PALETTE.MAIN_TAG_BG[3], PALETTE.MAIN_TAG_BG[4])
        mainTagBtn:SetBackdropBorderColor(PALETTE.MAIN_TAG_BORDER[1], PALETTE.MAIN_TAG_BORDER[2], PALETTE.MAIN_TAG_BORDER[3], PALETTE.MAIN_TAG_BORDER[4])
    end

    local mainTagText = mainTagBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainTagText:SetPoint("CENTER", mainTagBtn, "CENTER", 0, 0)
    self._mainTagBtn = mainTagBtn
    self._mainTagText = mainTagText
    self._isMain = true

    mainTagBtn:SetScript("OnClick", function()
        self:toggleMainTag()
    end)
    mainTagBtn:SetScript("OnEnter", function(btn)
        if GameTooltip then
            GameTooltip:SetOwner(btn, "ANCHOR_TOP")
            if self._isMain then
                GameTooltip:SetText("Personagem Principal [M]\n|cffaaaaaaClique para mudar para Alt [A]|r")
            else
                GameTooltip:SetText("Personagem Secundário [A]\n|cffaaaaaaClique para mudar para Main [M]|r")
            end
            GameTooltip:Show()
        end
    end)
    mainTagBtn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    -- Helper de estilização de EditBox no padrão container com borda arredondada clássica
    local function styleEditBox(eb, tooltip)
        eb:SetFontObject("GameFontHighlightSmall")
        eb:SetAutoFocus(false)
        eb:SetTextInsets(6, 6, 2, 2)
        if eb.SetBackdrop then
            eb:SetBackdrop(SUB_CONTAINER_BACKDROP)
            eb:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
            eb:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
        end
        eb:SetScript("OnEditFocusGained", function(selfBox)
            if selfBox.SetBackdropBorderColor then
                selfBox:SetBackdropBorderColor(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], PALETTE.FOCUS_BORDER[4])
            end
            if selfBox.SetBackdropColor then
                selfBox:SetBackdropColor(PALETTE.FOCUS_BG[1], PALETTE.FOCUS_BG[2], PALETTE.FOCUS_BG[3], PALETTE.FOCUS_BG[4])
            end
        end)
        eb:SetScript("OnEditFocusLost", function(selfBox)
            if selfBox.SetBackdropBorderColor then
                selfBox:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
            end
            if selfBox.SetBackdropColor then
                selfBox:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
            end
            self:saveCurrentMember()
        end)
        eb:SetScript("OnEscapePressed", function(selfBox)
            selfBox:ClearFocus()
        end)
        eb:SetScript("OnEnterPressed", function(selfBox)
            if not (selfBox.IsMultiLine and selfBox:IsMultiLine()) then
                selfBox:ClearFocus()
            end
        end)
        if tooltip then
            eb:SetScript("OnEnter", function(selfBox)
                if GameTooltip then
                    GameTooltip:SetOwner(selfBox, "ANCHOR_TOP")
                    GameTooltip:SetText(tooltip)
                    GameTooltip:Show()
                end
            end)
            eb:SetScript("OnLeave", function()
                if GameTooltip then GameTooltip:Hide() end
            end)
        end
    end

    -- =========================================================================
    -- PAINEL INSET 1: DETALHES DO PERSONAGEM (Nativas Blizzard)
    -- =========================================================================
    local inset1 = CreateFrame("Frame", nil, frame, template)
    inset1:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -64)
    inset1:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    inset1:SetHeight(232)
    if inset1.SetBackdrop then
        inset1:SetBackdrop(CONTAINER_BACKDROP)
        inset1:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        inset1:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end

    local secTitle1 = inset1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    secTitle1:SetPoint("TOPLEFT", inset1, "TOPLEFT", 10, -8)
    secTitle1:SetText("|cffffd200DETALHES DO PERSONAGEM|r")

    local sep1 = inset1:CreateTexture(nil, "ARTWORK")
    sep1:SetPoint("TOPLEFT", inset1, "TOPLEFT", 8, -24)
    sep1:SetPoint("RIGHT", inset1, "RIGHT", -8, 0)
    sep1:SetHeight(1)
    sep1:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- Coluna Esquerda do Inset 1:
    -- Nível
    local levelLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    levelLabel:SetPoint("TOPLEFT", sep1, "BOTTOMLEFT", 2, -6)
    levelLabel:SetText("|cffffd200Nível:|r")
    local levelVal = inset1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    levelVal:SetPoint("LEFT", levelLabel, "RIGHT", 6, 0)
    self._levelVal = levelVal

    -- Classe
    local classLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    classLabel:SetPoint("TOPLEFT", levelLabel, "BOTTOMLEFT", 0, -4)
    classLabel:SetText("|cffffd200Classe:|r")
    local classVal = inset1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    classVal:SetPoint("LEFT", classLabel, "RIGHT", 6, 0)
    self._classVal = classVal

    -- Cargo
    local rankLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rankLabel:SetPoint("TOPLEFT", classLabel, "BOTTOMLEFT", 0, -4)
    rankLabel:SetText("|cffffd200Cargo:|r")
    local rankVal = inset1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rankVal:SetPoint("LEFT", rankLabel, "RIGHT", 6, 0)
    self._rankVal = rankVal

    -- Entrada (Data de entrada do personagem - editável ao clicar)
    local dateJoinLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dateJoinLabel:SetPoint("TOPLEFT", rankLabel, "BOTTOMLEFT", 0, -4)
    dateJoinLabel:SetText("|cffffd200Entrada:|r")
    local dateJoinEB = CreateFrame("EditBox", nil, inset1, template)
    dateJoinEB:SetPoint("LEFT", dateJoinLabel, "RIGHT", 6, 0)
    dateJoinEB:SetSize(86, 18)
    styleEditBox(dateJoinEB, "Data de Entrada na Guilda (AAAA-MM-DD)\n|cffaaaaaaClique para editar|r")
    self._dateJoinEB = dateJoinEB

    -- Coluna Direita do Inset 1:
    -- Reputação
    local repLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    repLabel:SetPoint("TOPLEFT", sep1, "BOTTOMLEFT", 170, -6)
    repLabel:SetText("|cffffd200Reputação:|r")
    local repVal = inset1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    repVal:SetPoint("LEFT", repLabel, "RIGHT", 6, 0)
    self._repVal = repVal

    -- Status
    local statusLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusLabel:SetPoint("TOPLEFT", repLabel, "BOTTOMLEFT", 0, -4)
    statusLabel:SetText("|cffffd200Status:|r")
    local statusVal = inset1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusVal:SetPoint("LEFT", statusLabel, "RIGHT", 6, 0)
    self._statusVal = statusVal

    -- Zona
    local zoneLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    zoneLabel:SetPoint("TOPLEFT", statusLabel, "BOTTOMLEFT", 0, -4)
    zoneLabel:SetText("|cffffd200Zona:|r")
    local zoneVal = inset1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneVal:SetPoint("LEFT", zoneLabel, "RIGHT", 6, 0)
    self._zoneVal = zoneVal

    -- Abaixo das colunas:
    -- Nota Pública (Container no estilo Note do padrão clássico Blizzard)
    local publicNoteLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    publicNoteLabel:SetPoint("TOPLEFT", dateJoinLabel, "BOTTOMLEFT", 0, -14)
    publicNoteLabel:SetText("|cffffd200Nota Pública:|r")

    local publicNoteBox = CreateFrame("Frame", nil, inset1, template)
    publicNoteBox:SetPoint("TOPLEFT", publicNoteLabel, "BOTTOMLEFT", 0, -3)
    publicNoteBox:SetPoint("RIGHT", inset1, "RIGHT", -10, 0)
    publicNoteBox:SetHeight(38)
    if publicNoteBox.SetBackdrop then
        publicNoteBox:SetBackdrop(SUB_CONTAINER_BACKDROP)
        publicNoteBox:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        publicNoteBox:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local publicNoteVal = publicNoteBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    publicNoteVal:SetPoint("TOPLEFT", publicNoteBox, "TOPLEFT", 6, -4)
    publicNoteVal:SetPoint("BOTTOMRIGHT", publicNoteBox, "BOTTOMRIGHT", -6, 4)
    publicNoteVal:SetJustifyH("LEFT")
    if publicNoteVal.SetJustifyV then publicNoteVal:SetJustifyV("TOP") end
    if publicNoteVal.SetWordWrap then publicNoteVal:SetWordWrap(true) end
    self._publicNoteVal = publicNoteVal

    -- Nota de Oficial (Container no estilo Officer's Note do padrão clássico Blizzard)
    local officerNoteLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    officerNoteLabel:SetPoint("TOPLEFT", publicNoteBox, "BOTTOMLEFT", 0, -8)
    officerNoteLabel:SetText("|cffffd200Nota de Oficial:|r")

    local officerNoteBox = CreateFrame("Frame", nil, inset1, template)
    officerNoteBox:SetPoint("TOPLEFT", officerNoteLabel, "BOTTOMLEFT", 0, -3)
    officerNoteBox:SetPoint("RIGHT", inset1, "RIGHT", -10, 0)
    officerNoteBox:SetHeight(38)
    if officerNoteBox.SetBackdrop then
        officerNoteBox:SetBackdrop(SUB_CONTAINER_BACKDROP)
        officerNoteBox:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        officerNoteBox:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local officerNoteVal = officerNoteBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    officerNoteVal:SetPoint("TOPLEFT", officerNoteBox, "TOPLEFT", 6, -4)
    officerNoteVal:SetPoint("BOTTOMRIGHT", officerNoteBox, "BOTTOMRIGHT", -6, 4)
    officerNoteVal:SetJustifyH("LEFT")
    if officerNoteVal.SetJustifyV then officerNoteVal:SetJustifyV("TOP") end
    if officerNoteVal.SetWordWrap then officerNoteVal:SetWordWrap(true) end
    self._officerNoteVal = officerNoteVal

    -- =========================================================================
    -- PAINEL INSET 2: INFORMAÇÕES ADICIONAIS
    -- =========================================================================
    local inset2 = CreateFrame("Frame", nil, frame, template)
    inset2:SetPoint("TOPLEFT", inset1, "BOTTOMLEFT", 0, -8)
    inset2:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    inset2:SetHeight(190)
    if inset2.SetBackdrop then
        inset2:SetBackdrop(CONTAINER_BACKDROP)
        inset2:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        inset2:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end

    local secTitle2 = inset2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    secTitle2:SetPoint("TOPLEFT", inset2, "TOPLEFT", 10, -8)
    secTitle2:SetText("|cffffd200INFORMAÇÕES ADICIONAIS|r")

    local sep2 = inset2:CreateTexture(nil, "ARTWORK")
    sep2:SetPoint("TOPLEFT", inset2, "TOPLEFT", 8, -24)
    sep2:SetPoint("RIGHT", inset2, "RIGHT", -8, 0)
    sep2:SetHeight(1)
    sep2:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- Coluna Esquerda do Inset 2:
    -- 1. Data de Aniversário (birthDay)
    local birthdayLabel = inset2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    birthdayLabel:SetPoint("TOPLEFT", sep2, "BOTTOMLEFT", 2, -6)
    birthdayLabel:SetText("|cffffd200Aniversário (MM/DD):|r")

    local birthdayEB = CreateFrame("EditBox", nil, inset2, template)
    birthdayEB:SetPoint("TOPLEFT", birthdayLabel, "BOTTOMLEFT", 0, -2)
    birthdayEB:SetSize(70, 20)
    birthdayEB:SetMaxLetters(5)
    styleEditBox(birthdayEB, "Data de Aniversário (MM/DD)\n|cffaaaaaaClique para editar|r")
    self._birthdayEB = birthdayEB

    -- 2. Nota Interna Customizada (customNote) - Altura Ampliada até próximo ao Recrutador (deixando espaçamento)
    local customNoteLabel = inset2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    customNoteLabel:SetPoint("TOPLEFT", birthdayEB, "BOTTOMLEFT", 0, -6)
    customNoteLabel:SetText("|cffffd200Nota Interna Customizada:|r")

    -- Container da Nota Interna com Backdrop clássico (evita o colapso nativo do EditBox multiline no motor do WoW)
    local customNoteBox = CreateFrame("Frame", nil, inset2, template)
    customNoteBox:SetPoint("TOPLEFT", customNoteLabel, "BOTTOMLEFT", 0, -2)
    customNoteBox:SetPoint("BOTTOMLEFT", inset2, "BOTTOMLEFT", 10, 36)
    customNoteBox:SetWidth(155)
    if customNoteBox.SetBackdrop then
        customNoteBox:SetBackdrop(SUB_CONTAINER_BACKDROP)
        customNoteBox:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        customNoteBox:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local customNoteEB = CreateFrame("EditBox", nil, customNoteBox)
    customNoteEB:SetPoint("TOPLEFT", customNoteBox, "TOPLEFT", 6, -4)
    customNoteEB:SetPoint("BOTTOMRIGHT", customNoteBox, "BOTTOMRIGHT", -6, 4)
    customNoteEB:SetMultiLine(true)
    customNoteEB:SetAutoFocus(false)
    customNoteEB:SetFontObject("GameFontHighlightSmall")
    customNoteEB:SetMaxLetters(250)
    customNoteEB:SetTextInsets(0, 0, 0, 0)

    -- Permite clicar em qualquer lugar da caixa para focar a edição
    customNoteBox:EnableMouse(true)
    customNoteBox:SetScript("OnMouseDown", function()
        customNoteEB:SetFocus()
    end)

    local isCustomNoteFocused = false
    local function updateCustomNoteBoxStyle(hovered)
        if not customNoteBox.SetBackdropBorderColor then return end
        if isCustomNoteFocused or hovered then
            customNoteBox:SetBackdropBorderColor(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], PALETTE.FOCUS_BORDER[4])
            customNoteBox:SetBackdropColor(PALETTE.FOCUS_BG[1], PALETTE.FOCUS_BG[2], PALETTE.FOCUS_BG[3], PALETTE.FOCUS_BG[4])
        else
            customNoteBox:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
            customNoteBox:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        end
    end

    local function showCustomNoteTip(owner)
        if GameTooltip then
            GameTooltip:SetOwner(owner, "ANCHOR_TOP")
            GameTooltip:SetText("Nota Interna Customizada\n|cffaaaaaaClique para editar|r")
            GameTooltip:Show()
        end
    end
    local function hideCustomNoteTip()
        if GameTooltip then GameTooltip:Hide() end
    end

    customNoteEB:SetScript("OnEditFocusGained", function()
        isCustomNoteFocused = true
        updateCustomNoteBoxStyle(false)
    end)
    customNoteEB:SetScript("OnEditFocusLost", function()
        isCustomNoteFocused = false
        updateCustomNoteBoxStyle(false)
        self:saveCurrentMember()
    end)
    customNoteEB:SetScript("OnEscapePressed", function(selfBox)
        selfBox:ClearFocus()
    end)
    customNoteEB:SetScript("OnEnter", function(eb)
        updateCustomNoteBoxStyle(true)
        showCustomNoteTip(eb)
    end)
    customNoteEB:SetScript("OnLeave", function()
        updateCustomNoteBoxStyle(false)
        hideCustomNoteTip()
    end)
    customNoteBox:SetScript("OnEnter", function(box)
        updateCustomNoteBoxStyle(true)
        showCustomNoteTip(box)
    end)
    customNoteBox:SetScript("OnLeave", function()
        updateCustomNoteBoxStyle(false)
        hideCustomNoteTip()
    end)

    self._customNoteEB = customNoteEB
    self._customNoteBox = customNoteBox

    -- Coluna Direita do Inset 2:
    -- Alts Vinculados (alts) - Altura Expandida acompanhando a Nota Interna até próximo ao Recrutador
    local altsLabelBtn = CreateFrame("Button", nil, inset2)
    altsLabelBtn:SetPoint("TOPLEFT", sep2, "BOTTOMLEFT", 170, -6)
    altsLabelBtn:SetSize(160, 14)

    local altsLabel = altsLabelBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    altsLabel:SetPoint("LEFT", altsLabelBtn, "LEFT", 0, 0)
    altsLabel:SetText("|cffffd200Alts Vinculados:|r")

    local altsManageHint = altsLabelBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    altsManageHint:SetPoint("LEFT", altsLabel, "RIGHT", 4, 0)
    altsManageHint:SetText("|cffffd200[Gerenciar]|r")

    altsLabelBtn:SetScript("OnClick", function()
        self:toggleAltManager()
    end)
    altsLabelBtn:SetScript("OnEnter", function(btn)
        if GameTooltip then
            GameTooltip:SetOwner(btn, "ANCHOR_TOPLEFT")
            GameTooltip:SetText("Alts Vinculados\n|cffaaaaaaClique para gerenciar, vincular alts ou definir o Main|r")
            GameTooltip:Show()
        end
    end)
    altsLabelBtn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    local altsBtn = CreateFrame("Button", nil, inset2, template)
    altsBtn:SetPoint("TOPLEFT", altsLabelBtn, "BOTTOMLEFT", 0, -2)
    altsBtn:SetPoint("RIGHT", inset2, "RIGHT", -10, 0)
    altsBtn:SetPoint("BOTTOM", customNoteBox, "BOTTOM", 0, 0)
    if altsBtn.SetBackdrop then
        altsBtn:SetBackdrop(SUB_CONTAINER_BACKDROP)
        altsBtn:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        altsBtn:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local altsVal = altsBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    altsVal:SetPoint("TOPLEFT", altsBtn, "TOPLEFT", 6, -4)
    altsVal:SetPoint("BOTTOMRIGHT", altsBtn, "BOTTOMRIGHT", -6, 4)
    altsVal:SetJustifyH("LEFT")
    if altsVal.SetJustifyV then altsVal:SetJustifyV("TOP") end
    if altsVal.SetWordWrap then altsVal:SetWordWrap(true) end
    self._altsVal = altsVal
    self._altsBtn = altsBtn

    local altsHl = altsBtn:CreateTexture(nil, "HIGHLIGHT")
    altsHl:SetAllPoints(altsBtn)
    altsHl:SetColorTexture(PALETTE.HIGHLIGHT_TINT[1], PALETTE.HIGHLIGHT_TINT[2], PALETTE.HIGHLIGHT_TINT[3], PALETTE.HIGHLIGHT_TINT[4])
    altsBtn:SetHighlightTexture(altsHl)

    altsBtn:SetScript("OnClick", function()
        self:toggleAltManager()
    end)
    altsBtn:SetScript("OnEnter", function(btn)
        if altsBtn.SetBackdropBorderColor then
            altsBtn:SetBackdropBorderColor(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], PALETTE.FOCUS_BORDER[4])
            altsBtn:SetBackdropColor(PALETTE.FOCUS_BG[1], PALETTE.FOCUS_BG[2], PALETTE.FOCUS_BG[3], PALETTE.FOCUS_BG[4])
        end
        if GameTooltip then
            GameTooltip:SetOwner(btn, "ANCHOR_TOPLEFT")
            GameTooltip:SetText("Alts Vinculados\n|cffaaaaaaClique para abrir a janela de gerenciamento de alts|r")
            GameTooltip:Show()
        end
    end)
    altsBtn:SetScript("OnLeave", function(btn)
        if altsBtn.SetBackdropBorderColor then
            altsBtn:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
            altsBtn:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        end
        if GameTooltip then GameTooltip:Hide() end
    end)

    -- Parte Inferior do Inset 2: Recrutador (Posicionado quase na borda inferior do container)
    local recruiterBtn = CreateFrame("Button", nil, inset2, template)
    recruiterBtn:SetPoint("BOTTOMLEFT", inset2, "BOTTOMLEFT", 76, 8)
    recruiterBtn:SetPoint("RIGHT", inset2, "RIGHT", -10, 0)
    recruiterBtn:SetHeight(20)
    if recruiterBtn.SetBackdrop then
        recruiterBtn:SetBackdrop(SUB_CONTAINER_BACKDROP)
        recruiterBtn:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        recruiterBtn:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
    end

    local recruiterLabel = inset2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    recruiterLabel:SetPoint("RIGHT", recruiterBtn, "LEFT", -6, 0)
    recruiterLabel:SetText("|cffffd200Recrutador:|r")

    local recruiterBtnText = recruiterBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    recruiterBtnText:SetPoint("LEFT", recruiterBtn, "LEFT", 6, 0)
    recruiterBtnText:SetPoint("RIGHT", recruiterBtn, "RIGHT", -18, 0)
    recruiterBtnText:SetJustifyH("LEFT")
    self._recruiterBtnText = recruiterBtnText

    local recruiterArrow = recruiterBtn:CreateTexture(nil, "OVERLAY")
    recruiterArrow:SetSize(12, 12)
    recruiterArrow:SetPoint("RIGHT", recruiterBtn, "RIGHT", -4, 0)
    recruiterArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    recruiterBtn:SetScript("OnEnter", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], PALETTE.FOCUS_BORDER[4])
            btn:SetBackdropColor(PALETTE.FOCUS_BG[1], PALETTE.FOCUS_BG[2], PALETTE.FOCUS_BG[3], PALETTE.FOCUS_BG[4])
        end
        if recruiterArrow and recruiterArrow.SetTexture then
            recruiterArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
        end
        if GameTooltip then
            GameTooltip:SetOwner(btn, "ANCHOR_TOP")
            local rec = self._currentMember and self._currentMember:getRecruiter() or ""
            if rec ~= "" then
                GameTooltip:SetText(string.format("Recrutador: |cffffffff%s|r\n|cffaaaaaaClique para selecionar outro membro da guilda|r", rec))
            else
                GameTooltip:SetText("Recrutador: |cff888888(Não informado)|r\n|cffaaaaaaClique para selecionar um membro da guilda|r")
            end
            GameTooltip:Show()
        end
    end)
    recruiterBtn:SetScript("OnLeave", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], PALETTE.SUB_BOX_BORDER[4])
            btn:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], PALETTE.SUB_BOX_BG[4])
        end
        if recruiterArrow and recruiterArrow.SetTexture then
            recruiterArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        end
        if GameTooltip then GameTooltip:Hide() end
    end)
    recruiterBtn:SetScript("OnClick", function()
        self:toggleRecruiterPicker()
    end)
    self._recruiterBtn = recruiterBtn
    self._recruiterVal = recruiterBtn
end

--- Salva as alterações feitas nos campos customizados da View de forma automática.
function MemberView:saveCurrentMember()
    if not self._currentMember then
        return
    end

    local updatedFields = {
        isMain = (self._isMain == true),
        birthday = self._birthdayEB and self._birthdayEB:GetText() or "",
        dateJoin = self._dateJoinEB and self._dateJoinEB:GetText() or "",
        customNote = self._customNoteEB and self._customNoteEB:GetText() or "",
        recruiter = self._currentMember and self._currentMember:getRecruiter() or "",
    }

    if self._onSaveCallback then
        self._onSaveCallback(self._currentMember, updatedFields)
    end
end

--- Atualiza visualmente a tag de Main/Alt com cores e bordas distintas.
---@param isMain boolean
function MemberView:updateMainTagVisual(isMain)
    self._isMain = (isMain == true)
    if not self._mainTagBtn or not self._mainTagText then
        return
    end

    if self._isMain then
        self._mainTagText:SetText("|cffffd200M|r")
        if self._mainTagBtn.SetBackdropColor then
            self._mainTagBtn:SetBackdropColor(PALETTE.MAIN_TAG_BG[1], PALETTE.MAIN_TAG_BG[2], PALETTE.MAIN_TAG_BG[3], PALETTE.MAIN_TAG_BG[4])
            self._mainTagBtn:SetBackdropBorderColor(PALETTE.MAIN_TAG_BORDER[1], PALETTE.MAIN_TAG_BORDER[2], PALETTE.MAIN_TAG_BORDER[3], PALETTE.MAIN_TAG_BORDER[4])
        end
    else
        self._mainTagText:SetText("|cffffffffA|r")
        if self._mainTagBtn.SetBackdropColor then
            self._mainTagBtn:SetBackdropColor(PALETTE.ALT_TAG_BG[1], PALETTE.ALT_TAG_BG[2], PALETTE.ALT_TAG_BG[3], PALETTE.ALT_TAG_BG[4])
            self._mainTagBtn:SetBackdropBorderColor(PALETTE.ALT_TAG_BORDER[1], PALETTE.ALT_TAG_BORDER[2], PALETTE.ALT_TAG_BORDER[3], PALETTE.ALT_TAG_BORDER[4])
        end
    end
end

--- Alterna o status entre Main e Alt ao clicar na tag e persiste a alteração imediatamente.
function MemberView:toggleMainTag()
    if not self._currentMember then
        return
    end

    local newState = not self._isMain
    local memberService = _G.GM and _G.GM.memberService
    local alts = self._currentMember:getAlts() or {}

    if #alts > 0 and memberService then
        local family = memberService:getAltFamily(self._currentMember)
        local familyNames = {}
        for _, m in ipairs(family) do
            table.insert(familyNames, m:getName())
        end

        local newMainName = ""
        if newState == true then
            -- Este membro virou Main -> todos os outros viram Alt automaticamente
            newMainName = self._currentMember:getName()
        else
            -- Este membro virou Alt -> elege o primeiro alt disponível da lista como novo Main
            for _, m in ipairs(family) do
                if (m:getName() or ""):lower() ~= (self._currentMember:getName() or ""):lower() then
                    newMainName = m:getName()
                    break
                end
            end
            if newMainName == "" then
                newMainName = self._currentMember:getName()
                newState = true
            end
        end

        memberService:syncAltFamily(familyNames, newMainName)
        local refreshed = memberService:getMember(self._currentMember:getName())
        if refreshed then
            self._currentMember = refreshed
        end
        self:updateMainTagVisual(self._currentMember:isMain())
        self:updateAltsVisual()
        if self._altManagerFrame and self._altManagerFrame:IsShown() then
            self:refreshAltManager()
        end
    else
        self:updateMainTagVisual(newState)
        self._currentMember:setMain(newState)
        if self._onSaveCallback then
            self._onSaveCallback(self._currentMember, { isMain = newState })
        end
    end
end

--- Registra o callback que será chamado quando as alterações forem salvas.
---@param callback fun(member: Member, updatedData: table)
function MemberView:setOnSaveCallback(callback)
    self._onSaveCallback = callback
end

--- Preenche a interface com os dados de uma entidade Member e a exibe.
--- Ao trocar de membro, salva as alterações do membro anterior automaticamente.
---@param member Member @Instância do membro a ser exibido
---@param isLocked boolean @Se true, trava a janela naquele membro
function MemberView:showMember(member, isLocked)
    if not member then
        return
    end

    -- Se já estiver exibindo um membro diferente, salva as alterações do membro anterior automaticamente
    if self._currentMember and self._currentMember ~= member then
        self:saveCurrentMember()
    end

    self._currentMember = member
    if isLocked ~= nil then
        self:setLocked(isLocked)
    end

    local function getFactionTexture(m)
        local faction = nil
        if m then
            local r = (m.getRace and m:getRace() or ""):lower()
            if r:find("orc") or r:find("troll") or r:find("tauren") or r:find("undead") or r:find("renegad") or r:find("morto") or r:find("sangrent") or r:find("blood") or r:find("goblin") then
                faction = "Horde"
            elseif r:find("human") or r:find("dwarf") or r:find("anão") or r:find("anao") or r:find("elf") or r:find("gnom") or r:find("draenei") or r:find("worgen") then
                faction = "Alliance"
            end
        end

        if not faction and UnitFactionGroup then
            faction = UnitFactionGroup("player")
        end

        if faction == "Horde" then
            return "Interface\\AddOns\\GuildManager\\Textures\\Horde-Logo.tga"
        else
            return "Interface\\AddOns\\GuildManager\\Textures\\Alliance-Logo.tga"
        end
    end

    -- Ícone da Facção (Leão da Aliança / Símbolo da Horda exibido à esquerda do nome)
    if self._factionIcon then
        self._factionIcon:SetTexture(getFactionTexture(member))
        if self._factionIcon.SetTexCoord then
            self._factionIcon:SetTexCoord(0, 1, 0, 1)
        end
        self._factionIcon:Show()
    end

    -- Raça do Jogador exibida em português diretamente abaixo do ícone da facção
    local race = (member.getRace and member:getRace()) or ""
    if race == "" and member:getGuid() and GetPlayerInfoByGUID then
        local _, _, locRace = GetPlayerInfoByGUID(member:getGuid())
        if locRace and locRace ~= "" then
            race = locRace
            if member.setRace then
                member:setRace(race)
            end
        end
    end

    local racePt = getRaceInPortuguese(race)
    if self._raceText then
        local raceDisplay = racePt ~= "" and racePt or race
        if raceDisplay ~= "" then
            self._raceText:SetText(string.format("|cffffffff%s|r", raceDisplay))
            self._raceText:Show()
        else
            self._raceText:SetText("")
            self._raceText:Hide()
        end
    end

    -- Cabeçalho com o nome do personagem na cor da sua respectiva classe
    local rawName = member:getName() or ""
    local classColor = RAID_CLASS_COLORS and member.getClass and RAID_CLASS_COLORS[member:getClass()]
    if classColor then
        local r = math.floor((classColor.r or 1) * 255)
        local g = math.floor((classColor.g or 1) * 255)
        local b = math.floor((classColor.b or 1) * 255)
        self._memberNameText:SetText(string.format("|cff%02x%02x%02x%s|r", r, g, b, rawName))
    else
        self._memberNameText:SetText(self:formatColoredMemberName(rawName))
    end

    -- Reposiciona e atualiza a tag M/A dinamicamente ao lado do nome do membro
    local textWidth = (self._memberNameText.GetStringWidth and self._memberNameText:GetStringWidth()) or 0
    self._mainTagBtn:ClearAllPoints()
    if textWidth and textWidth > 0 then
        self._mainTagBtn:SetPoint("LEFT", self._memberNameText, "LEFT", textWidth + 8, 0)
    else
        self._mainTagBtn:SetPoint("LEFT", self._memberNameText, "RIGHT", 6, 0)
    end
    self:updateMainTagVisual(member:isMain())

    -- Seção DETALHES DO PERSONAGEM
    local level = member:getLevel() or 1
    self._levelVal:SetText(tostring(level))

    local classDisplay = member:getClassDisplayName() or member:getClass() or ""
    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[member:getClass()]
    if classColor then
        local r = math.floor(classColor.r * 255)
        local g = math.floor(classColor.g * 255)
        local b = math.floor(classColor.b * 255)
        self._classVal:SetText(string.format("|cff%02x%02x%02x%s|r", r, g, b, classDisplay))
    else
        self._classVal:SetText(classDisplay ~= "" and classDisplay or "Desconhecida")
    end

    local rankName = member:getRankName() or ""
    self._rankVal:SetText(rankName ~= "" and rankName or "Membro")

    local repStanding = member:getRepStanding() or 0
    self._repVal:SetText(getReputationText(repStanding))

    if member:isOnline() then
        self._statusVal:SetText("|cff40ff40Online|r")
    else
        self._statusVal:SetText("|cffffffffOffline|r")
    end

    local zone = member:getZone()
    self._zoneVal:SetText(zone ~= "" and zone or "Desconhecida")

    local publicNote = member:getPublicNote()
    self._publicNoteVal:SetText(publicNote ~= "" and publicNote or "|cff888888(Nenhuma)|r")

    local officerNote = member:getOfficerNote()
    self._officerNoteVal:SetText(officerNote ~= "" and officerNote or "|cff888888(Nenhuma)|r")

    self:updateAltsVisual()
    self:updateRecruiterButtonVisual()
    if self._recruiterPickerFrame then
        self._recruiterPickerFrame:Hide()
    end
    if self._altManagerFrame and self._altManagerFrame:IsShown() then
        self:refreshAltManager()
    end

    -- Seção Customizada do Addon
    self._birthdayEB:SetText(member:getBirthday() or "")
    self._dateJoinEB:SetText(member:getDateJoin() or "")
    self._customNoteEB:SetText(member:getCustomNote() or "")

    -- Oculta o painel de detalhes nativo do WoW Classic para não vazar textos ou botões sob a janela do GuildManager
    if GuildMemberDetailFrame and GuildMemberDetailFrame.Hide then
        GuildMemberDetailFrame:Hide()
    end

    self:anchorToGuildFrame()
    self._frame:Show()
end

--- Posiciona a janela de forma elegante ao lado do painel de guilda (suporta CommunitiesFrame e GuildFrame).
function MemberView:anchorToGuildFrame()
    local target = nil
    if CommunitiesFrame and CommunitiesFrame.IsVisible and CommunitiesFrame:IsVisible() then
        target = CommunitiesFrame
    elseif GuildFrame and GuildFrame.IsVisible and GuildFrame:IsVisible() then
        target = GuildFrame
    elseif FriendsFrame and FriendsFrame.IsVisible and FriendsFrame:IsVisible() then
        target = FriendsFrame
    end

    if target then
        self._frame:ClearAllPoints()
        self._frame:SetPoint("TOPLEFT", target, "TOPRIGHT", 6, -12)
    elseif not (self._frame.GetPoint and self._frame:GetPoint()) then
        self._frame:ClearAllPoints()
        self._frame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    end
end

--- Define o estado de fixação/trava da janela (controlado sob os panos).
---@param locked boolean
function MemberView:setLocked(locked)
    self._isLocked = (locked == true)
end

--- Verifica se a janela está travada em um membro selecionado.
---@return boolean
function MemberView:isLocked()
    return self._isLocked
end

--- Oculta a janela se não estiver travada (dispara salvamento automático via OnHide).
--- Oculta a janela se não estiver travada (dispara salvamento automático via OnHide).
function MemberView:hide()
    if self._recruiterPickerFrame then
        self._recruiterPickerFrame:Hide()
    end
    if self._altManagerFrame then
        self._altManagerFrame:Hide()
    end
    if self._frame and not self._isLocked then
        self._frame:Hide()
    end
end

--- Força o fechamento da janela independente de estar travada.
function MemberView:forceHide()
    self:setLocked(false)
    if self._recruiterPickerFrame then
        self._recruiterPickerFrame:Hide()
    end
    if self._altManagerFrame then
        self._altManagerFrame:Hide()
    end
    if self._frame then
        self._frame:Hide()
    end
end

--- Registra a função que fornece a lista atual de membros ativos da guilda.
---@param provider fun(): Member[]
function MemberView:setGuildMembersProvider(provider)
    self._guildMembersProvider = provider
end

--- Registra o callback para busca de entidade Member por nome.
---@param callback fun(name: string): Member|nil
function MemberView:setMemberLookupCallback(callback)
    self._memberLookupCallback = callback
end

--- Formata o nome do membro com a cor da sua classe para exibição rica.
---@param name string
---@return string
function MemberView:formatColoredMemberName(name)
    if not name or name == "" then
        return "|cff666666(Não informado)|r"
    end

    local clean = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[%.,!]+$", "")
    clean = clean:match("^[^-]+") or clean
    clean = clean:match("^%s*(.-)%s*$") or clean
    if clean == "" then
        return "|cff666666(Não informado)|r"
    end

    -- 1. Tenta buscar no serviço/repositório de membros (busca exata)
    local member = nil
    if self._memberLookupCallback then
        member = self._memberLookupCallback(clean)
    end
    if not member and _G.GM and _G.GM.memberService then
        member = _G.GM.memberService:getMember(clean)
    end

    -- 2. Se não encontrou, busca no repositório de membros pelo primeiro nome (suporte ao WoW Forever onde o nome do recrutador foi gravado só com primeiro nome)
    if not member and _G.GM and _G.GM.memberService then
        local all = _G.GM.memberService:getAllMembers()
        local cleanLower = clean:lower()
        for _, m in ipairs(all) do
            local mName = m:getName() or ""
            local first = mName:match("^(%S+)") or mName
            if first:lower() == cleanLower or mName:lower() == cleanLower then
                member = m
                -- Se o recrutador salvo no membro atual era apenas o primeiro nome, atualiza automaticamente para o nome completo com sobrenome
                if self._currentMember and self._currentMember:getRecruiter():lower() == cleanLower and mName ~= self._currentMember:getRecruiter() then
                    self._currentMember:setRecruiter(mName)
                    self:saveCurrentMember()
                end
                break
            end
        end
    end

    if member and member.getColoredName then
        return member:getColoredName()
    end

    -- 3. Tenta buscar no Roster da Blizzard se disponível (exato e por primeiro nome)
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
                    if self._currentMember and self._currentMember:getRecruiter():lower() == cleanLower and gClean ~= self._currentMember:getRecruiter() then
                        self._currentMember:setRecruiter(gClean)
                        self:saveCurrentMember()
                    end
                    if gClass and RAID_CLASS_COLORS and RAID_CLASS_COLORS[gClass] then
                        local color = RAID_CLASS_COLORS[gClass]
                        local r = math.floor((color.r or 1) * 255)
                        local g = math.floor((color.g or 1) * 255)
                        local b = math.floor((color.b or 1) * 255)
                        return string.format("|cff%02x%02x%02x%s|r", r, g, b, gClean)
                    end
                    return gClean
                end
            end
        end
    end

    return clean
end

--- Atualiza o texto do botão de recrutador aplicando a cor da classe do membro que recrutou.
function MemberView:updateRecruiterButtonVisual()
    if not self._recruiterBtnText then
        return
    end

    local rec = self._currentMember and self._currentMember:getRecruiter() or ""
    local colored = self:formatColoredMemberName(rec)
    self._recruiterBtnText:SetText(colored)
end

--- Cria a janela suspensa (picker) para listagem e seleção do recrutador da guilda.
function MemberView:createRecruiterPickerUI()
    if self._recruiterPickerFrame then
        return
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local picker = CreateFrame("Frame", "GuildManagerRecruiterPickerFrame", self._frame, template)
    self._recruiterPickerFrame = picker
    picker.SetVerticalScroll = function() end

    picker:SetSize(250, 270)
    picker:SetFrameStrata("DIALOG")
    picker:SetToplevel(true)
    picker:SetClampedToScreen(true)
    picker:EnableMouse(true)
    picker:Hide()

    if picker.SetBackdrop then
        picker:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 24,
            edgeSize = 24,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        picker:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], PALETTE.FRAME_BG[4])
        picker:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], PALETTE.FRAME_BORDER[4])
    end

    -- Permite fechar a janela ao pressionar Escape
    if UISpecialFrames then
        table.insert(UISpecialFrames, "GuildManagerRecruiterPickerFrame")
    end

    -- Título
    local title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", picker, "TOPLEFT", 14, -12)
    title:SetText("|cffffd200SELECIONAR RECRUTADOR|r")

    -- Botão Fechar ("X")
    local closeBtn = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -4, -4)
    closeBtn:SetSize(24, 24)
    closeBtn:SetScript("OnClick", function()
        picker:Hide()
    end)

    -- Campo de Busca (Filtro por nome em tempo real)
    local searchEB = CreateFrame("EditBox", nil, picker, template)
    searchEB:SetPoint("TOPLEFT", picker, "TOPLEFT", 12, -32)
    searchEB:SetPoint("RIGHT", picker, "RIGHT", -12, 0)
    searchEB:SetHeight(22)
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
    searchHint:SetText("|cffaaaaaaBuscar membro...|r")
    searchEB.hint = searchHint

    searchEB:SetScript("OnTextChanged", function(box)
        local txt = box:GetText()
        if txt and txt ~= "" then
            searchHint:Hide()
        else
            searchHint:Show()
        end
        self:refreshRecruiterPickerList(txt)
    end)
    searchEB:SetScript("OnEscapePressed", function(box)
        box:ClearFocus()
        picker:Hide()
    end)

    self._pickerSearchEB = searchEB

    -- Rolagem com a roda do mouse
    picker:EnableMouseWheel(true)
    picker:SetScript("OnMouseWheel", function(_, delta)
        self:scrollRecruiterPicker(delta)
    end)

    -- Scrollbar lateral
    local scrollBar = CreateFrame("Slider", "GM_RecruiterPickerScrollBar", picker, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -6, -56)
    scrollBar:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -6, 10)
    scrollBar:SetWidth(16)
    scrollBar:SetScript("OnValueChanged", function(_, val)
        self._pickerOffset = math.floor(val)
        self:renderRecruiterPickerRows()
    end)
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValueStep(1)

    local upBtn = _G["GM_RecruiterPickerScrollBarScrollUpButton"] or (scrollBar and scrollBar.ScrollUpButton)
    if upBtn then
        upBtn:SetScript("OnClick", function()
            self:scrollRecruiterPicker(1)
        end)
    end
    local downBtn = _G["GM_RecruiterPickerScrollBarScrollDownButton"] or (scrollBar and scrollBar.ScrollDownButton)
    if downBtn then
        downBtn:SetScript("OnClick", function()
            self:scrollRecruiterPicker(-1)
        end)
    end
    self._pickerScrollBar = scrollBar

    -- Linhas visíveis (tabela de botões reciclados)
    self._pickerRows = {}
    local numRows = 8
    local rowHeight = 22

    for i = 1, numRows do
        local btn = CreateFrame("Button", nil, picker)
        btn:SetHeight(rowHeight)
        btn:SetPoint("TOPLEFT", searchEB, "BOTTOMLEFT", 0, -4 - (i - 1) * rowHeight)
        btn:SetPoint("RIGHT", scrollBar, "LEFT", -4, 0)

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(btn)
        hl:SetColorTexture(PALETTE.HIGHLIGHT_TINT[1], PALETTE.HIGHLIGHT_TINT[2], PALETTE.HIGHLIGHT_TINT[3], 0.12)
        btn:SetHighlightTexture(hl)

        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("LEFT", btn, "LEFT", 6, 0)
        txt:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
        txt:SetJustifyH("LEFT")
        btn.text = txt

        btn:EnableMouseWheel(true)
        btn:SetScript("OnMouseWheel", function(_, delta)
            self:scrollRecruiterPicker(delta)
        end)

        btn:SetScript("OnClick", function(b)
            if b.itemData then
                if b.itemData.isClear then
                    self:selectRecruiter("")
                else
                    self:selectRecruiter(b.itemData.name)
                end
            end
        end)

        self._pickerRows[i] = btn
    end
end

--- Abre ou fecha a janela de seleção de recrutador.
function MemberView:toggleRecruiterPicker()
    self:createRecruiterPickerUI()
    if not self._recruiterPickerFrame then
        return
    end

    if self._recruiterPickerFrame:IsShown() then
        self._recruiterPickerFrame:Hide()
    else
        self._recruiterPickerFrame:ClearAllPoints()
        self._recruiterPickerFrame:SetPoint("BOTTOMLEFT", self._recruiterBtn, "TOPLEFT", 0, 4)
        if self._pickerSearchEB then
            self._pickerSearchEB:SetText("")
        end
        self._pickerOffset = 0
        self:refreshRecruiterPickerList("")
        self._recruiterPickerFrame:Show()
    end
end

--- Atualiza a lista filtrada de membros e redesenha os botões visíveis.
---@param filterText string|nil
function MemberView:refreshRecruiterPickerList(filterText)
    local query = filterText and filterText:lower():match("^%s*(.-)%s*$") or ""

    -- 1. Coleta os membros da guilda através do provedor
    local members = {}
    if self._guildMembersProvider then
        members = self._guildMembersProvider()
    elseif _G.GM and _G.GM.memberService then
        local all = _G.GM.memberService:getAllMembers()
        for _, m in ipairs(all) do
            if m:isInGuild() then
                table.insert(members, m)
            end
        end
        table.sort(members, function(a, b)
            return (a:getName() or ""):lower() < (b:getName() or ""):lower()
        end)
    end

    local currentName = self._currentMember and self._currentMember:getName() or ""
    local currentRecruiter = self._currentMember and self._currentMember:getRecruiter() or ""

    local items = {}

    -- Opção de limpar/remover recrutador se já houver um configurado
    if currentRecruiter ~= "" and (query == "" or ("remover"):find(query, 1, true) or ("nenhum"):find(query, 1, true)) then
        table.insert(items, {
            isClear = true,
            displayName = "|cffff5555[Remover Recrutador]|r",
        })
    end

    for _, m in ipairs(members) do
        local mName = m:getName()
        -- Não inclui o próprio membro (um membro não pode recrutar a si mesmo)
        if mName and mName ~= "" and mName:lower() ~= currentName:lower() then
            if query == "" or mName:lower():find(query, 1, true) then
                local coloredName = m:getColoredName()
                local rank = m:getRankName()
                local rankStr = (rank and rank ~= "") and string.format(" |cff777777(%s)|r", rank) or ""
                table.insert(items, {
                    isClear = false,
                    name = mName,
                    displayName = coloredName .. rankStr,
                })
            end
        end
    end

    self._pickerFilteredList = items

    -- Ajusta o limite da barra de rolagem
    local numRows = #(self._pickerRows or {})
    local maxOffset = math.max(0, #items - numRows)
    if (self._pickerOffset or 0) > maxOffset then
        self._pickerOffset = maxOffset
    end

    if self._pickerScrollBar then
        self._pickerScrollBar:SetMinMaxValues(0, maxOffset)
        self._pickerScrollBar:SetValue(self._pickerOffset or 0)
        if maxOffset == 0 then
            self._pickerScrollBar:Hide()
        else
            self._pickerScrollBar:Show()
        end
    end

    self:renderRecruiterPickerRows()
end

--- Renderiza as linhas visíveis do seletor de recrutadores com base no offset atual.
function MemberView:renderRecruiterPickerRows()
    if not self._pickerRows or not self._pickerFilteredList then
        return
    end

    local offset = self._pickerOffset or 0
    local items = self._pickerFilteredList

    for i, btn in ipairs(self._pickerRows) do
        local index = offset + i
        local item = items[index]
        if item then
            btn.itemData = item
            btn.text:SetText(item.displayName or "")
            btn:Show()
        else
            btn.itemData = nil
            btn.text:SetText("")
            btn:Hide()
        end
    end
end

--- Realiza a rolagem da lista de membros do seletor.
---@param delta number
function MemberView:scrollRecruiterPicker(delta)
    local items = self._pickerFilteredList or {}
    local numRows = #(self._pickerRows or {})
    local maxOffset = math.max(0, #items - numRows)
    if maxOffset <= 0 then
        return
    end

    local newOffset = (self._pickerOffset or 0) - delta
    if newOffset < 0 then newOffset = 0 end
    if newOffset > maxOffset then newOffset = maxOffset end

    self._pickerOffset = newOffset
    if self._pickerScrollBar then
        self._pickerScrollBar:SetValue(newOffset)
    end
    self:renderRecruiterPickerRows()
end

--- Seleciona e define o recrutador único do membro.
---@param selectedName string
function MemberView:selectRecruiter(selectedName)
    if not self._currentMember then
        return
    end

    local newRecruiter = selectedName or ""
    self._currentMember:setRecruiter(newRecruiter)

    self:updateRecruiterButtonVisual()
    self:saveCurrentMember()

    if self._recruiterPickerFrame then
        self._recruiterPickerFrame:Hide()
    end

    if newRecruiter ~= "" then
        print(string.format("|cff00ff00[GuildManager]|r Recrutador de |cffffff00%s|r alterado para %s.",
            self._currentMember:getName(),
            self:formatColoredMemberName(newRecruiter)
        ))
    else
        print(string.format("|cff00ff00[GuildManager]|r Recrutador de |cffffff00%s|r removido.",
            self._currentMember:getName()
        ))
    end
end

--- Atualiza a exibição da lista de alts vinculados na janela principal do membro.
function MemberView:updateAltsVisual()
    if not self._altsVal then
        return
    end

    if not self._currentMember then
        self._altsVal:SetText("|cff666666(Nenhum)|r")
        return
    end

    local alts = self._currentMember:getAlts() or {}
    if #alts == 0 then
        self._altsVal:SetText("|cff666666(Nenhum)|r")
        return
    end

    local formattedAlts = {}
    for _, altName in ipairs(alts) do
        local colored = self:formatColoredMemberName(altName)
        table.insert(formattedAlts, colored)
    end

    self._altsVal:SetText(table.concat(formattedAlts, ", "))
end

--- Cria a janela de gerenciamento de alts vinculados (AltManagerFrame).
function MemberView:createAltManagerUI()
    if self._altManagerFrame then
        return
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local manager = CreateFrame("Frame", "GuildManagerAltManagerFrame", self._frame, template)
    self._altManagerFrame = manager
    manager.SetVerticalScroll = function() end

    manager:SetSize(350, 480)
    manager:SetFrameStrata("DIALOG")
    manager:SetToplevel(true)
    manager:SetClampedToScreen(true)
    manager:EnableMouse(true)
    manager:Hide()

    if manager.SetBackdrop then
        manager:SetBackdrop(DIALOG_BACKDROP)
        manager:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], PALETTE.FRAME_BG[4])
        manager:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], PALETTE.FRAME_BORDER[4])
    end

    -- Permite fechar a janela ao pressionar Escape
    if UISpecialFrames then
        table.insert(UISpecialFrames, "GuildManagerAltManagerFrame")
    end

    -- Título da Janela (Centralizado, Dourado)
    local title = manager:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", manager, "TOP", 0, -12)
    title:SetText("|cffffd200Gerenciar Alts Vinculados|r")

    -- Subtítulo com o nome do membro inspecionado
    local subtitle = manager:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", manager, "TOPLEFT", 18, -28)
    subtitle:SetText("Família de alts")
    self._altManagerSubtitle = subtitle

    -- Botão Fechar ("X" clássico vermelho com moldura)
    local closeBtn = CreateFrame("Button", nil, manager, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", manager, "TOPRIGHT", -4, -4)
    closeBtn:SetSize(26, 26)
    closeBtn:SetScript("OnClick", function()
        manager:Hide()
    end)

    -- =========================================================================
    -- INSET 1: PERSONAGENS VINCULADOS (Membros da mesma família)
    -- =========================================================================
    local inset1 = CreateFrame("Frame", nil, manager, template)
    inset1:SetPoint("TOPLEFT", manager, "TOPLEFT", 12, -46)
    inset1:SetPoint("RIGHT", manager, "RIGHT", -12, 0)
    inset1:SetHeight(188)
    if inset1.SetBackdrop then
        inset1:SetBackdrop(CONTAINER_BACKDROP)
        inset1:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        inset1:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end

    local sec1Title = inset1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sec1Title:SetPoint("TOPLEFT", inset1, "TOPLEFT", 10, -8)
    sec1Title:SetText("|cffffd200PERSONAGENS VINCULADOS|r")

    local sep1 = inset1:CreateTexture(nil, "ARTWORK")
    sep1:SetPoint("TOPLEFT", inset1, "TOPLEFT", 8, -24)
    sep1:SetPoint("RIGHT", inset1, "RIGHT", -8, 0)
    sep1:SetHeight(1)
    sep1:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    local sec1Hint = inset1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sec1Hint:SetPoint("TOPLEFT", sep1, "BOTTOMLEFT", 2, -4)
    sec1Hint:SetText("|cffffd200Apenas 1 Main por família (clique em [A] para tornar Main):|r")

    -- Mensagem informativa caso não haja alts vinculados ainda
    local emptyNotice = inset1:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyNotice:SetPoint("TOPLEFT", sec1Hint, "BOTTOMLEFT", 6, -18)
    emptyNotice:SetPoint("RIGHT", inset1, "RIGHT", -12, 0)
    emptyNotice:SetJustifyH("LEFT")
    emptyNotice:SetText("|cffaaaaaaNenhum outro alt vinculado.\nUse a lista abaixo para selecionar e vincular membros.|r")
    emptyNotice:Hide()
    self._familyEmptyNotice = emptyNotice

    -- Scrollbar lateral da lista de personagens vinculados (Família de Alts)
    local familyScrollBar = CreateFrame("Slider", "GM_AltFamilyScrollBar", inset1, "UIPanelScrollBarTemplate")
    familyScrollBar:SetPoint("TOPRIGHT", inset1, "TOPRIGHT", -4, -46)
    familyScrollBar:SetPoint("BOTTOMRIGHT", inset1, "BOTTOMRIGHT", -4, 8)
    familyScrollBar:SetWidth(16)
    familyScrollBar:SetScript("OnValueChanged", function(_, val)
        self._altFamilyOffset = math.floor(val)
        self:renderLinkedFamilyRows()
    end)
    familyScrollBar:SetMinMaxValues(0, 1)
    familyScrollBar:SetValueStep(1)
    familyScrollBar:Hide()

    local familyUpBtn = _G["GM_AltFamilyScrollBarScrollUpButton"] or (familyScrollBar and familyScrollBar.ScrollUpButton)
    if familyUpBtn then
        familyUpBtn:SetScript("OnClick", function()
            self:scrollAltFamily(1)
        end)
    end
    local familyDownBtn = _G["GM_AltFamilyScrollBarScrollDownButton"] or (familyScrollBar and familyScrollBar.ScrollDownButton)
    if familyDownBtn then
        familyDownBtn:SetScript("OnClick", function()
            self:scrollAltFamily(-1)
        end)
    end
    self._altFamilyScrollBar = familyScrollBar

    -- Suporte à roda do mouse no container da família de alts
    inset1:EnableMouseWheel(true)
    inset1:SetScript("OnMouseWheel", function(_, delta)
        self:scrollAltFamily(delta)
    end)

    -- Linhas da Família de Personagens Vinculados (5 visíveis com paginação por scroll)
    self._altFamilyRows = {}
    local numFamilyRows = 5
    local familyRowHeight = 22

    for i = 1, numFamilyRows do
        local row = CreateFrame("Frame", nil, inset1)
        row:SetHeight(familyRowHeight)
        row:SetPoint("TOPLEFT", sec1Hint, "BOTTOMLEFT", 0, -4 - (i - 1) * (familyRowHeight + 2))
        row:SetPoint("RIGHT", familyScrollBar, "LEFT", -4, 0)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta)
            self:scrollAltFamily(delta)
        end)

        -- Highlight suave ao passar o mouse
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(row)
        hl:SetColorTexture(PALETTE.HIGHLIGHT_TINT[1], PALETTE.HIGHLIGHT_TINT[2], PALETTE.HIGHLIGHT_TINT[3], 0.08)

        -- Botão Main/Alt Tag [M] / [A]
        local mainBtn = CreateFrame("Button", nil, row, template)
        mainBtn:SetSize(22, 18)
        mainBtn:SetPoint("LEFT", row, "LEFT", 2, 0)
        if mainBtn.SetBackdrop then
            mainBtn:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            mainBtn:SetBackdropColor(PALETTE.ALT_TAG_BG[1], PALETTE.ALT_TAG_BG[2], PALETTE.ALT_TAG_BG[3], PALETTE.ALT_TAG_BG[4])
            mainBtn:SetBackdropBorderColor(PALETTE.ALT_TAG_BORDER[1], PALETTE.ALT_TAG_BORDER[2], PALETTE.ALT_TAG_BORDER[3], PALETTE.ALT_TAG_BORDER[4])
        end

        local mainText = mainBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        mainText:SetPoint("CENTER", mainBtn, "CENTER", 0, 0)
        mainBtn.text = mainText

        mainBtn:SetScript("OnClick", function()
            if row.memberName then
                if row.isMain then
                    print(string.format("|cffffff00[GuildManager]|r %s já é o Main. Para mudar o Main, clique no botão [A] de outro personagem da lista.",
                        row.memberName
                    ))
                else
                    self:setFamilyMain(row.memberName)
                end
            end
        end)

        mainBtn:SetScript("OnEnter", function(btn)
            if GameTooltip and row.memberName then
                GameTooltip:SetOwner(btn, "ANCHOR_TOPLEFT")
                if row.isMain then
                    GameTooltip:SetText(string.format("|cffffd200Personagem Principal [M]|r\n|cffffffff%s|r\n|cffaaaaaa(Apenas um Main é permitido por família)|r", row.memberName))
                else
                    GameTooltip:SetText(string.format("|cffffffffPersonagem Secundário [A]|r\n|cffffffff%s|r\n|cff00ff00Clique para definir como o ÚNICO Main desta família|r\n|cffaaaaaa(Todos os outros se tornarão automaticamente alts)|r", row.memberName))
                end
                GameTooltip:Show()
            end
        end)
        mainBtn:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)

        row.mainBtn = mainBtn

        -- Botão Desvincular [X]
        local unlinkBtn = CreateFrame("Button", nil, row, template)
        unlinkBtn:SetSize(18, 18)
        unlinkBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        if unlinkBtn.SetBackdrop then
            unlinkBtn:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            unlinkBtn:SetBackdropColor(0.18, 0.06, 0.05, 0.90)
            unlinkBtn:SetBackdropBorderColor(0.65, 0.25, 0.20, 0.90)
        end

        local unlinkText = unlinkBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        unlinkText:SetPoint("CENTER", unlinkBtn, "CENTER", 0, 0)
        unlinkText:SetText("|cffff4444X|r")

        unlinkBtn:SetScript("OnClick", function()
            if row.memberName then
                self:unlinkAltFromCurrentFamily(row.memberName)
            end
        end)
        unlinkBtn:SetScript("OnEnter", function(btn)
            if unlinkBtn.SetBackdropBorderColor then
                unlinkBtn:SetBackdropBorderColor(1.0, 0.25, 0.25, 1.0)
            end
            if GameTooltip and row.memberName then
                GameTooltip:SetOwner(btn, "ANCHOR_TOPRIGHT")
                GameTooltip:SetText(string.format("Desvincular Alt\n|cffaaaaaaRemove |cffffff00%s|r da lista de alts vinculados|r", row.memberName))
                GameTooltip:Show()
            end
        end)
        unlinkBtn:SetScript("OnLeave", function(btn)
            if unlinkBtn.SetBackdropBorderColor then
                unlinkBtn:SetBackdropBorderColor(0.55, 0.22, 0.18, 0.85)
            end
            if GameTooltip then GameTooltip:Hide() end
        end)

        row.unlinkBtn = unlinkBtn

        -- Nome do membro e rank/nível
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", mainBtn, "RIGHT", 6, 0)
        nameText:SetPoint("RIGHT", unlinkBtn, "LEFT", -4, 0)
        nameText:SetJustifyH("LEFT")
        row.nameText = nameText

        row:Hide()
        self._altFamilyRows[i] = row
    end

    -- =========================================================================
    -- INSET 2: VINCULAR NOVO ALT
    -- =========================================================================
    local inset2 = CreateFrame("Frame", nil, manager, template)
    inset2:SetPoint("TOPLEFT", inset1, "BOTTOMLEFT", 0, -8)
    inset2:SetPoint("RIGHT", manager, "RIGHT", -12, 0)
    inset2:SetHeight(218)
    if inset2.SetBackdrop then
        inset2:SetBackdrop(CONTAINER_BACKDROP)
        inset2:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], PALETTE.INSET_BG[4])
        inset2:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], PALETTE.INSET_BORDER[4])
    end

    local sec2Title = inset2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sec2Title:SetPoint("TOPLEFT", inset2, "TOPLEFT", 10, -8)
    sec2Title:SetText("|cffffd200VINCULAR NOVO ALT|r")

    local sep2 = inset2:CreateTexture(nil, "ARTWORK")
    sep2:SetPoint("TOPLEFT", inset2, "TOPLEFT", 8, -24)
    sep2:SetPoint("RIGHT", inset2, "RIGHT", -8, 0)
    sep2:SetHeight(1)
    sep2:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- Campo de Busca de Membros
    local searchEB = CreateFrame("EditBox", nil, inset2, template)
    searchEB:SetPoint("TOPLEFT", sep2, "BOTTOMLEFT", 2, -4)
    searchEB:SetPoint("RIGHT", inset2, "RIGHT", -8, 0)
    searchEB:SetHeight(22)
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
    searchHint:SetText("|cffaaaaaaBuscar membro da guilda...|r")
    searchEB.hint = searchHint

    searchEB:SetScript("OnTextChanged", function(box)
        local txt = box:GetText()
        if txt and txt ~= "" then
            searchHint:Hide()
        else
            searchHint:Show()
        end
        self:refreshAvailableAltsList(txt)
    end)
    searchEB:SetScript("OnEscapePressed", function(box)
        box:ClearFocus()
        manager:Hide()
    end)
    self._availableAltsSearchEB = searchEB

    -- Rolagem com a roda do mouse na janela
    manager:EnableMouseWheel(true)
    manager:SetScript("OnMouseWheel", function(_, delta)
        self:scrollAvailableAlts(delta)
    end)

    -- Scrollbar lateral da lista de disponíveis
    local scrollBar = CreateFrame("Slider", "GM_AvailableAltsScrollBar", inset2, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPRIGHT", inset2, "TOPRIGHT", -4, -58)
    scrollBar:SetPoint("BOTTOMRIGHT", inset2, "BOTTOMRIGHT", -4, 8)
    scrollBar:SetWidth(16)
    scrollBar:SetScript("OnValueChanged", function(_, val)
        self._availableAltsOffset = math.floor(val)
        self:renderAvailableAltRows()
    end)
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValueStep(1)

    local upBtn = _G["GM_AvailableAltsScrollBarScrollUpButton"] or (scrollBar and scrollBar.ScrollUpButton)
    if upBtn then
        upBtn:SetScript("OnClick", function()
            self:scrollAvailableAlts(1)
        end)
    end
    local downBtn = _G["GM_AvailableAltsScrollBarScrollDownButton"] or (scrollBar and scrollBar.ScrollDownButton)
    if downBtn then
        downBtn:SetScript("OnClick", function()
            self:scrollAvailableAlts(-1)
        end)
    end
    self._availableAltsScrollBar = scrollBar

    -- Linhas da Lista de Membros Disponíveis para Vincular (6 visíveis)
    self._availableAltRows = {}
    local numAvailableRows = 6
    local availableRowHeight = 22

    for i = 1, numAvailableRows do
        local row = CreateFrame("Frame", nil, inset2)
        row:SetHeight(availableRowHeight)
        row:SetPoint("TOPLEFT", searchEB, "BOTTOMLEFT", 0, -4 - (i - 1) * (availableRowHeight + 2))
        row:SetPoint("RIGHT", scrollBar, "LEFT", -4, 0)

        -- Highlight suave ao passar o mouse
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(row)
        hl:SetColorTexture(PALETTE.HIGHLIGHT_TINT[1], PALETTE.HIGHLIGHT_TINT[2], PALETTE.HIGHLIGHT_TINT[3], 0.08)

        -- Botão Vincular [+ Vincular]
        local linkBtn = CreateFrame("Button", nil, row, template)
        linkBtn:SetSize(72, 18)
        linkBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        if linkBtn.SetBackdrop then
            linkBtn:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            linkBtn:SetBackdropColor(0.08, 0.14, 0.06, 0.90)
            linkBtn:SetBackdropBorderColor(0.35, 0.65, 0.25, 0.85)
        end

        local linkBtnText = linkBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        linkBtnText:SetPoint("CENTER", linkBtn, "CENTER", 0, 0)
        linkBtnText:SetText("|cff60e060+ Vincular|r")

        linkBtn:SetScript("OnClick", function(btn)
            if btn.memberName then
                self:linkAltToCurrentFamily(btn.memberName)
            end
        end)
        linkBtn:SetScript("OnEnter", function(btn)
            if linkBtn.SetBackdropBorderColor then
                linkBtn:SetBackdropBorderColor(0.45, 0.85, 0.35, 1.0)
            end
            if GameTooltip and btn.memberName then
                GameTooltip:SetOwner(btn, "ANCHOR_TOPRIGHT")
                GameTooltip:SetText(string.format("Vincular Alt\n|cffaaaaaaAdiciona |cffffff00%s|r como alt à família atual|r", btn.memberName))
                GameTooltip:Show()
            end
        end)
        linkBtn:SetScript("OnLeave", function(btn)
            if linkBtn.SetBackdropBorderColor then
                linkBtn:SetBackdropBorderColor(0.35, 0.55, 0.25, 0.85)
            end
            if GameTooltip then GameTooltip:Hide() end
        end)

        row.linkBtn = linkBtn

        -- Nome do membro disponível e detalhes
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", row, "LEFT", 4, 0)
        nameText:SetPoint("RIGHT", linkBtn, "LEFT", -4, 0)
        nameText:SetJustifyH("LEFT")
        row.nameText = nameText

        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta)
            self:scrollAvailableAlts(delta)
        end)

        row:Hide()
        self._availableAltRows[i] = row
    end
end

--- Abre ou fecha a janela de gerenciamento de alts vinculados.
function MemberView:toggleAltManager()
    self:createAltManagerUI()
    if not self._altManagerFrame then
        return
    end

    if self._altManagerFrame:IsShown() then
        self._altManagerFrame:Hide()
    else
        self._altManagerFrame:ClearAllPoints()
        self._altManagerFrame:SetPoint("TOPLEFT", self._frame, "TOPRIGHT", 6, 0)

        if self._availableAltsSearchEB then
            self._availableAltsSearchEB:SetText("")
        end
        self._altFamilyOffset = 0
        self._availableAltsOffset = 0
        self:refreshAltManager()
        self._altManagerFrame:Show()
    end
end

--- Atualiza todos os dados e listas da janela de gerenciamento de alts.
function MemberView:refreshAltManager()
    if not self._altManagerFrame or not self._currentMember then
        return
    end

    if self._altManagerSubtitle then
        local coloredName = self:formatColoredMemberName(self._currentMember:getName())
        self._altManagerSubtitle:SetText("Família de: " .. coloredName)
    end

    self:renderLinkedFamilyRows()
    local searchTxt = self._availableAltsSearchEB and self._availableAltsSearchEB:GetText() or ""
    self:refreshAvailableAltsList(searchTxt)
end

--- Renderiza a lista de personagens que pertencem à família de alts atual.
function MemberView:renderLinkedFamilyRows()
    if not self._currentMember then
        return
    end

    local memberService = _G.GM and _G.GM.memberService
    local family = {}
    if memberService then
        family = memberService:getAltFamily(self._currentMember)
    else
        table.insert(family, self._currentMember)
    end

    self._altFamilyList = family

    local numRows = #(self._altFamilyRows or {})
    local maxOffset = math.max(0, #family - numRows)
    local offset = self._altFamilyOffset or 0
    if offset > maxOffset then
        offset = maxOffset
        self._altFamilyOffset = offset
    end

    if self._altFamilyScrollBar then
        self._altFamilyScrollBar:SetMinMaxValues(0, maxOffset)
        local curVal = math.floor(self._altFamilyScrollBar:GetValue() or 0)
        if curVal ~= offset then
            self._altFamilyScrollBar:SetValue(offset)
        end
        if maxOffset > 0 then
            self._altFamilyScrollBar:Show()
        else
            self._altFamilyScrollBar:Hide()
        end
    end

    local currentNameLower = (self._currentMember:getName() or ""):lower()

    for i, row in ipairs(self._altFamilyRows) do
        local index = offset + i
        local m = family[index]
        if m then
            local mName = m:getName()
            local isThisMemberCurrent = (mName:lower() == currentNameLower)
            local isThisMain = m:isMain()

            row.memberName = mName
            row.isMain = isThisMain

            -- Atualiza visual da tag M / A
            if isThisMain then
                row.mainBtn.text:SetText("|cffffd200M|r")
                if row.mainBtn.SetBackdropColor then
                    row.mainBtn:SetBackdropColor(PALETTE.MAIN_TAG_BG[1], PALETTE.MAIN_TAG_BG[2], PALETTE.MAIN_TAG_BG[3], PALETTE.MAIN_TAG_BG[4])
                    row.mainBtn:SetBackdropBorderColor(PALETTE.MAIN_TAG_BORDER[1], PALETTE.MAIN_TAG_BORDER[2], PALETTE.MAIN_TAG_BORDER[3], PALETTE.MAIN_TAG_BORDER[4])
                end
            else
                row.mainBtn.text:SetText("|cffffffffA|r")
                if row.mainBtn.SetBackdropColor then
                    row.mainBtn:SetBackdropColor(PALETTE.ALT_TAG_BG[1], PALETTE.ALT_TAG_BG[2], PALETTE.ALT_TAG_BG[3], PALETTE.ALT_TAG_BG[4])
                    row.mainBtn:SetBackdropBorderColor(PALETTE.ALT_TAG_BORDER[1], PALETTE.ALT_TAG_BORDER[2], PALETTE.ALT_TAG_BORDER[3], PALETTE.ALT_TAG_BORDER[4])
                end
            end

            -- Nome colorido por classe + detalhes de nível e cargo
            local coloredName = self:formatColoredMemberName(mName)
            local lvl = m.getLevel and m:getLevel() or 0
            local rank = m.getRankName and m:getRankName() or ""
            local details = ""
            if lvl > 0 and rank ~= "" then
                details = string.format(" |cff888888(Nv %d • %s)|r", lvl, rank)
            elseif lvl > 0 then
                details = string.format(" |cff888888(Nv %d)|r", lvl)
            end
            if isThisMemberCurrent then
                details = details .. " |cffffe680[Atual]|r"
            end
            row.nameText:SetText(coloredName .. details)

            -- Botão desvincular: visível para todos exceto o membro atual da janela
            if isThisMemberCurrent then
                row.unlinkBtn:Hide()
            else
                row.unlinkBtn:Show()
            end

            row:Show()
        else
            row.memberName = nil
            row:Hide()
        end
    end

    if #family <= 1 then
        if self._familyEmptyNotice then
            self._familyEmptyNotice:Show()
        end
    else
        if self._familyEmptyNotice then
            self._familyEmptyNotice:Hide()
        end
    end
end

--- Atualiza a lista filtrada de membros disponíveis para vincular como alts.
---@param filterText string|nil
function MemberView:refreshAvailableAltsList(filterText)
    local query = filterText and filterText:lower():match("^%s*(.-)%s*$") or ""

    -- 1. Cria mapa com todos os membros já pertencentes à família para excluí-los da busca
    local familyNamesMap = {}
    if self._currentMember then
        familyNamesMap[(self._currentMember:getName() or ""):lower()] = true
        for _, alt in ipairs(self._currentMember:getAlts() or {}) do
            familyNamesMap[alt:lower()] = true
        end
    end

    -- 2. Coleta todos os membros da guilda através do provedor
    local guildMembers = {}
    if self._guildMembersProvider then
        guildMembers = self._guildMembersProvider()
    end

    -- Fallback: busca diretamente no Roster da Blizzard caso o provider esteja vazio
    if #guildMembers == 0 and GetNumGuildMembers then
        local num = GetNumGuildMembers() or 0
        for i = 1, num do
            local gName, gRank, _, gLevel, _, _, _, _, _, _, gClass = GetGuildRosterInfo(i)
            if gName then
                local clean = gName:match("^[^-]+") or gName
                clean = clean:match("^%s*(.-)%s*$") or clean
                table.insert(guildMembers, {
                    name = clean,
                    displayName = clean,
                    level = gLevel or 1,
                    rankName = gRank or "",
                    class = gClass,
                })
            end
        end
    end

    local filtered = {}
    local seen = {}

    for _, gm in ipairs(guildMembers) do
        local rawName = type(gm.getName) == "function" and gm:getName() or gm.name
        if rawName and rawName ~= "" then
            local clean = rawName:match("^[^-]+") or rawName
            clean = clean:match("^%s*(.-)%s*$") or clean
            local cleanLower = clean:lower()

            if not familyNamesMap[cleanLower] and not seen[cleanLower] then
                seen[cleanLower] = true

                if query == "" or cleanLower:find(query, 1, true) then
                    local lvl = type(gm.getLevel) == "function" and gm:getLevel() or gm.level or 1
                    local rnk = type(gm.getRankName) == "function" and gm:getRankName() or gm.rankName or ""
                    local cls = type(gm.getClass) == "function" and gm:getClass() or gm.class or ""
                    table.insert(filtered, {
                        name = clean,
                        level = lvl,
                        rankName = rnk,
                        class = cls,
                    })
                end
            end
        end
    end

    table.sort(filtered, function(a, b)
        return (a.name or "") < (b.name or "")
    end)

    self._availableAltsFilteredList = filtered

    local numRows = #(self._availableAltRows or {})
    local maxOffset = math.max(0, #filtered - numRows)
    if (self._availableAltsOffset or 0) > maxOffset then
        self._availableAltsOffset = maxOffset
    end

    if self._availableAltsScrollBar then
        self._availableAltsScrollBar:SetMinMaxValues(0, maxOffset)
        self._availableAltsScrollBar:SetValue(self._availableAltsOffset or 0)
    end

    self:renderAvailableAltRows()
end

--- Renderiza as linhas visíveis da lista de membros disponíveis.
function MemberView:renderAvailableAltRows()
    local offset = self._availableAltsOffset or 0
    local items = self._availableAltsFilteredList or {}

    for i, row in ipairs(self._availableAltRows) do
        local index = offset + i
        local item = items[index]
        if item then
            row.itemData = item
            local coloredName = self:formatColoredMemberName(item.name)
            local details = ""
            if item.level and item.level > 0 and item.rankName and item.rankName ~= "" then
                details = string.format(" |cff888888(Nv %d • %s)|r", item.level, item.rankName)
            elseif item.level and item.level > 0 then
                details = string.format(" |cff888888(Nv %d)|r", item.level)
            end
            row.nameText:SetText(coloredName .. details)
            row.linkBtn.memberName = item.name
            row:Show()
        else
            row.itemData = nil
            row.nameText:SetText("")
            row:Hide()
        end
    end
end

--- Realiza a rolagem da lista de personagens vinculados (família de alts).
---@param delta number
function MemberView:scrollAltFamily(delta)
    local items = self._altFamilyList or {}
    local numRows = #(self._altFamilyRows or {})
    local maxOffset = math.max(0, #items - numRows)
    if maxOffset <= 0 then
        return
    end

    local newOffset = (self._altFamilyOffset or 0) - delta
    if newOffset < 0 then newOffset = 0 end
    if newOffset > maxOffset then newOffset = maxOffset end

    if newOffset ~= self._altFamilyOffset then
        self._altFamilyOffset = newOffset
        if self._altFamilyScrollBar then
            self._altFamilyScrollBar:SetValue(newOffset)
        end
        self:renderLinkedFamilyRows()
    end
end

--- Realiza a rolagem da lista de membros disponíveis para vincular.
---@param delta number
function MemberView:scrollAvailableAlts(delta)
    local items = self._availableAltsFilteredList or {}
    local numRows = #(self._availableAltRows or {})
    local maxOffset = math.max(0, #items - numRows)
    if maxOffset <= 0 then
        return
    end

    local newOffset = (self._availableAltsOffset or 0) - delta
    if newOffset < 0 then newOffset = 0 end
    if newOffset > maxOffset then newOffset = maxOffset end

    self._availableAltsOffset = newOffset
    if self._availableAltsScrollBar then
        self._availableAltsScrollBar:SetValue(newOffset)
    end
    self:renderAvailableAltRows()
end

--- Vincula um novo personagem à família de alts do membro atual.
--- Garante a regra de negócio: mantém o Main atual e adiciona o novo como Alt.
---@param targetName string
function MemberView:linkAltToCurrentFamily(targetName)
    if not self._currentMember or not targetName or targetName == "" then
        return
    end

    local memberService = _G.GM and _G.GM.memberService
    if not memberService then
        print("|cffff0000[GuildManager]|r Erro: MemberService não encontrado.")
        return
    end

    local family = memberService:getAltFamily(self._currentMember)
    local familyNames = {}
    local currentMainName = ""

    for _, m in ipairs(family) do
        table.insert(familyNames, m:getName())
        if m:isMain() then
            currentMainName = m:getName()
        end
    end

    if currentMainName == "" then
        currentMainName = self._currentMember:getName()
    end

    table.insert(familyNames, targetName)

    -- Sincroniza garantindo unicidade do Main: apenas currentMainName é Main, todos os outros são Alts
    memberService:syncAltFamily(familyNames, currentMainName)

    local refreshed = memberService:getMember(self._currentMember:getName())
    if refreshed then
        self._currentMember = refreshed
    end

    self:updateMainTagVisual(self._currentMember:isMain())
    self:updateAltsVisual()
    self:refreshAltManager()

    print(string.format("|cff00ff00[GuildManager]|r %s foi vinculado como alt à família de %s.",
        self:formatColoredMemberName(targetName),
        self:formatColoredMemberName(currentMainName)
    ))
end

--- Define um personagem da família como o Main ÚNICO, transformando automaticamente todos os outros em Alts.
---@param targetName string
function MemberView:setFamilyMain(targetName)
    if not self._currentMember or not targetName or targetName == "" then
        return
    end

    local memberService = _G.GM and _G.GM.memberService
    if not memberService then
        return
    end

    local family = memberService:getAltFamily(self._currentMember)
    local familyNames = {}
    for _, m in ipairs(family) do
        table.insert(familyNames, m:getName())
    end

    -- Sincroniza a família inteira: targetName torna-se o único Main, todos os outros tornam-se Alts
    memberService:syncAltFamily(familyNames, targetName)

    local refreshed = memberService:getMember(self._currentMember:getName())
    if refreshed then
        self._currentMember = refreshed
    end

    self:updateMainTagVisual(self._currentMember:isMain())
    self:updateAltsVisual()
    self:refreshAltManager()

    print(string.format("|cff00ff00[GuildManager]|r %s agora é o MAIN da família de alts. Todos os outros tornaram-se alts.",
        self:formatColoredMemberName(targetName)
    ))
end

--- Desvincula um personagem da família de alts atual.
---@param targetName string
function MemberView:unlinkAltFromCurrentFamily(targetName)
    if not self._currentMember or not targetName or targetName == "" then
        return
    end

    local memberService = _G.GM and _G.GM.memberService
    if not memberService then
        return
    end

    memberService:unlinkAltFromFamily(self._currentMember, targetName)

    local refreshed = memberService:getMember(self._currentMember:getName())
    if refreshed then
        self._currentMember = refreshed
    end

    self:updateMainTagVisual(self._currentMember:isMain())
    self:updateAltsVisual()
    self:refreshAltManager()

    print(string.format("|cff00ff00[GuildManager]|r %s foi desvinculado da família de alts.",
        self:formatColoredMemberName(targetName)
    ))
end

--- Retorna a referência do Frame raiz.
---@return table
function MemberView:getFrame()
    return self._frame
end

-- Função global para compatibilidade com inicializações funcionais
function memberView()
    return MemberView:new()
end
