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
    instance._availableAltRows = {}
    instance._availableAltsFilteredList = {}
    instance._availableAltsOffset = 0

    instance:createUI()

    return instance
end

--- Cria e estiliza os componentes visuais da janela de membro com design moderno e elegante.
function MemberView:createUI()
    if self._frame then
        return
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "GuildManagerMemberFrame", UIParent, template)
    self._frame = frame

    frame:SetSize(360, 465)
    frame:SetFrameStrata("HIGH")
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

    -- Fundo e bordas no padrão oficial WoW Forever (Dark warm leather & burnished bronze/gold trim)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 14,
            edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(0.07, 0.05, 0.04, 0.96)
        frame:SetBackdropBorderColor(0.65, 0.48, 0.22, 1.0)
    end

    -- Botão Fechar ("X" clássico vermelho com moldura dourada)
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    closeBtn:SetSize(24, 24)
    closeBtn:SetScript("OnClick", function()
        self:setLocked(false)
        self:saveCurrentMember()
        self._frame:Hide()
    end)

    -- Título Centralizado da Janela (Padrão WoW Forever)
    local frameTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frameTitle:SetPoint("TOP", frame, "TOP", 0, -8)
    frameTitle:SetText("|cffffd200Ficha do Membro|r")

    -- Retrato / Brasão Circular no Canto Superior Esquerdo
    local portraitFrame = CreateFrame("Frame", nil, frame)
    portraitFrame:SetSize(48, 48)
    portraitFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", -8, 8)
    if portraitFrame.SetFrameLevel and frame.GetFrameLevel then
        portraitFrame:SetFrameLevel(frame:GetFrameLevel() + 2)
    end

    local portraitBg = portraitFrame:CreateTexture(nil, "BACKGROUND")
    portraitBg:SetSize(38, 38)
    portraitBg:SetPoint("CENTER", portraitFrame, "CENTER", 0, 0)
    if portraitBg.SetColorTexture then
        portraitBg:SetColorTexture(0.04, 0.03, 0.02, 1.0)
    end

    local factionIcon = portraitFrame:CreateTexture(nil, "ARTWORK")
    factionIcon:SetSize(36, 36)
    factionIcon:SetPoint("CENTER", portraitFrame, "CENTER", 0, 0)
    if factionIcon.SetTexCoord then
        factionIcon:SetTexCoord(4/32, 29/32, 2/32, 30/32)
    end
    self._factionIcon = factionIcon

    local portraitRing = portraitFrame:CreateTexture(nil, "OVERLAY")
    portraitRing:SetSize(50, 50)
    portraitRing:SetPoint("CENTER", portraitFrame, "CENTER", 0, 0)
    portraitRing:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Identificação do Personagem (ao lado do brasão circular)
    local memberNameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    memberNameText:SetPoint("TOPLEFT", frame, "TOPLEFT", 46, -24)
    memberNameText:SetJustifyH("LEFT")
    self._memberNameText = memberNameText

    -- Tag interativa de Main/Alt ('M' para Main, 'A' para Alt)
    local mainTagBtn = CreateFrame("Button", nil, frame, template)
    mainTagBtn:SetSize(22, 18)
    mainTagBtn:SetPoint("LEFT", memberNameText, "RIGHT", 6, 0)
    if mainTagBtn.SetBackdrop then
        mainTagBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 6, edgeSize = 6,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
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

    -- Subtítulo com Nível, Raça e Classe
    local raceText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    raceText:SetPoint("TOPLEFT", memberNameText, "BOTTOMLEFT", 0, -2)
    raceText:SetJustifyH("LEFT")
    self._raceText = raceText

    -- Helper de estilização de EditBox no padrão escuro rebaixado do WoW Forever
    local function styleEditBox(eb, tooltip)
        eb:SetFontObject("GameFontHighlightSmall")
        eb:SetAutoFocus(false)
        eb:SetTextInsets(4, 4, 1, 1)
        if eb.SetBackdrop then
            eb:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 6, edgeSize = 6,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            eb:SetBackdropColor(0.025, 0.018, 0.012, 0.90)
            eb:SetBackdropBorderColor(0.38, 0.28, 0.16, 0.85)
        end
        eb:SetScript("OnEditFocusGained", function(selfBox)
            if selfBox.SetBackdropBorderColor then
                selfBox:SetBackdropBorderColor(0.85, 0.70, 0.25, 1.0)
            end
            if selfBox.SetBackdropColor then
                selfBox:SetBackdropColor(0.06, 0.04, 0.03, 0.95)
            end
        end)
        eb:SetScript("OnEditFocusLost", function(selfBox)
            if selfBox.SetBackdropBorderColor then
                selfBox:SetBackdropBorderColor(0.38, 0.28, 0.16, 0.85)
            end
            if selfBox.SetBackdropColor then
                selfBox:SetBackdropColor(0.025, 0.018, 0.012, 0.90)
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
    inset1:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -66)
    inset1:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    inset1:SetHeight(224)
    if inset1.SetBackdrop then
        inset1:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        inset1:SetBackdropColor(0.035, 0.025, 0.018, 0.80)
        inset1:SetBackdropBorderColor(0.38, 0.28, 0.16, 0.85)
    end

    local secTitle1 = inset1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    secTitle1:SetPoint("TOPLEFT", inset1, "TOPLEFT", 10, -8)
    secTitle1:SetText("|cffffd200DETALHES DO PERSONAGEM|r")

    local sep1 = inset1:CreateTexture(nil, "ARTWORK")
    sep1:SetPoint("TOPLEFT", inset1, "TOPLEFT", 8, -24)
    sep1:SetPoint("RIGHT", inset1, "RIGHT", -8, 0)
    sep1:SetHeight(1)
    sep1:SetColorTexture(0.45, 0.35, 0.20, 0.65)

    -- Coluna Esquerda do Inset 1:
    -- Nível
    local levelLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    levelLabel:SetPoint("TOPLEFT", sep1, "BOTTOMLEFT", 2, -6)
    levelLabel:SetText("|cffc79c6eNível:|r")
    local levelVal = inset1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    levelVal:SetPoint("LEFT", levelLabel, "RIGHT", 6, 0)
    self._levelVal = levelVal

    -- Classe
    local classLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    classLabel:SetPoint("TOPLEFT", levelLabel, "BOTTOMLEFT", 0, -4)
    classLabel:SetText("|cffc79c6eClasse:|r")
    local classVal = inset1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    classVal:SetPoint("LEFT", classLabel, "RIGHT", 6, 0)
    self._classVal = classVal

    -- Cargo
    local rankLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    rankLabel:SetPoint("TOPLEFT", classLabel, "BOTTOMLEFT", 0, -4)
    rankLabel:SetText("|cffc79c6eCargo:|r")
    local rankVal = inset1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rankVal:SetPoint("LEFT", rankLabel, "RIGHT", 6, 0)
    self._rankVal = rankVal

    -- Entrada (Data de entrada do personagem - editável ao clicar)
    local dateJoinLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dateJoinLabel:SetPoint("TOPLEFT", rankLabel, "BOTTOMLEFT", 0, -4)
    dateJoinLabel:SetText("|cffc79c6eEntrada:|r")
    local dateJoinEB = CreateFrame("EditBox", nil, inset1, template)
    dateJoinEB:SetPoint("LEFT", dateJoinLabel, "RIGHT", 6, 0)
    dateJoinEB:SetSize(86, 18)
    styleEditBox(dateJoinEB, "Data de Entrada na Guilda (AAAA-MM-DD)\n|cffaaaaaaClique para editar|r")
    self._dateJoinEB = dateJoinEB

    -- Coluna Direita do Inset 1:
    -- Reputação
    local repLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    repLabel:SetPoint("TOPLEFT", sep1, "BOTTOMLEFT", 170, -6)
    repLabel:SetText("|cffc79c6eReputação:|r")
    local repVal = inset1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    repVal:SetPoint("LEFT", repLabel, "RIGHT", 6, 0)
    self._repVal = repVal

    -- Status
    local statusLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusLabel:SetPoint("TOPLEFT", repLabel, "BOTTOMLEFT", 0, -4)
    statusLabel:SetText("|cffc79c6eStatus:|r")
    local statusVal = inset1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusVal:SetPoint("LEFT", statusLabel, "RIGHT", 6, 0)
    self._statusVal = statusVal

    -- Zona
    local zoneLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    zoneLabel:SetPoint("TOPLEFT", statusLabel, "BOTTOMLEFT", 0, -4)
    zoneLabel:SetText("|cffc79c6eZona:|r")
    local zoneVal = inset1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneVal:SetPoint("LEFT", zoneLabel, "RIGHT", 6, 0)
    self._zoneVal = zoneVal

    -- Abaixo das colunas (Largura total do Inset 1):
    -- Recrutador
    local recruiterLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    recruiterLabel:SetPoint("TOPLEFT", dateJoinLabel, "BOTTOMLEFT", 0, -6)
    recruiterLabel:SetText("|cffc79c6eRecrutador:|r")

    local recruiterBtn = CreateFrame("Button", nil, inset1, template)
    recruiterBtn:SetPoint("LEFT", recruiterLabel, "RIGHT", 6, 0)
    recruiterBtn:SetPoint("RIGHT", inset1, "RIGHT", -10, 0)
    recruiterBtn:SetHeight(20)
    if recruiterBtn.SetBackdrop then
        recruiterBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 6, edgeSize = 6,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        recruiterBtn:SetBackdropColor(0.12, 0.08, 0.05, 0.90)
        recruiterBtn:SetBackdropBorderColor(0.50, 0.38, 0.20, 0.90)
    end

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
            btn:SetBackdropBorderColor(0.90, 0.75, 0.30, 1.0)
            btn:SetBackdropColor(0.18, 0.13, 0.07, 0.95)
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
            btn:SetBackdropBorderColor(0.50, 0.38, 0.20, 0.90)
            btn:SetBackdropColor(0.12, 0.08, 0.05, 0.90)
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

    -- Nota Pública
    local publicNoteLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    publicNoteLabel:SetPoint("TOPLEFT", recruiterLabel, "BOTTOMLEFT", 0, -6)
    publicNoteLabel:SetText("|cffc79c6eNota Pública:|r")
    local publicNoteVal = inset1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    publicNoteVal:SetPoint("TOPLEFT", publicNoteLabel, "BOTTOMLEFT", 0, -2)
    publicNoteVal:SetPoint("RIGHT", inset1, "RIGHT", -10, 0)
    publicNoteVal:SetJustifyH("LEFT")
    if publicNoteVal.SetWordWrap then publicNoteVal:SetWordWrap(true) end
    self._publicNoteVal = publicNoteVal

    -- Nota de Oficial
    local officerNoteLabel = inset1:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    officerNoteLabel:SetPoint("TOPLEFT", publicNoteVal, "BOTTOMLEFT", 0, -4)
    officerNoteLabel:SetText("|cffc79c6eNota de Oficial:|r")
    local officerNoteVal = inset1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    officerNoteVal:SetPoint("TOPLEFT", officerNoteLabel, "BOTTOMLEFT", 0, -2)
    officerNoteVal:SetPoint("RIGHT", inset1, "RIGHT", -10, 0)
    officerNoteVal:SetJustifyH("LEFT")
    if officerNoteVal.SetWordWrap then officerNoteVal:SetWordWrap(true) end
    self._officerNoteVal = officerNoteVal

    -- =========================================================================
    -- PAINEL INSET 2: GESTÃO CUSTOMIZADA (Editável)
    -- =========================================================================
    local inset2 = CreateFrame("Frame", nil, frame, template)
    inset2:SetPoint("TOPLEFT", inset1, "BOTTOMLEFT", 0, -8)
    inset2:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    inset2:SetHeight(155)
    if inset2.SetBackdrop then
        inset2:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        inset2:SetBackdropColor(0.035, 0.025, 0.018, 0.80)
        inset2:SetBackdropBorderColor(0.38, 0.28, 0.16, 0.85)
    end

    local secTitle2 = inset2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    secTitle2:SetPoint("TOPLEFT", inset2, "TOPLEFT", 10, -8)
    secTitle2:SetText("|cffffd200GESTÃO CUSTOMIZADA (EDITÁVEL)|r")

    local sep2 = inset2:CreateTexture(nil, "ARTWORK")
    sep2:SetPoint("TOPLEFT", inset2, "TOPLEFT", 8, -24)
    sep2:SetPoint("RIGHT", inset2, "RIGHT", -8, 0)
    sep2:SetHeight(1)
    sep2:SetColorTexture(0.45, 0.35, 0.20, 0.65)

    -- Coluna Esquerda do Inset 2:
    -- 1. Data de Aniversário (birthDay)
    local birthdayLabel = inset2:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    birthdayLabel:SetPoint("TOPLEFT", sep2, "BOTTOMLEFT", 2, -6)
    birthdayLabel:SetText("|cffc79c6eAniversário (MM/DD):|r")

    local birthdayEB = CreateFrame("EditBox", nil, inset2, template)
    birthdayEB:SetPoint("TOPLEFT", birthdayLabel, "BOTTOMLEFT", 0, -2)
    birthdayEB:SetSize(60, 20)
    birthdayEB:SetMaxLetters(5)
    styleEditBox(birthdayEB, "Data de Aniversário (MM/DD)\n|cffaaaaaaClique para editar|r")
    self._birthdayEB = birthdayEB

    -- 2. Nota Interna Customizada (customNote)
    local customNoteLabel = inset2:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    customNoteLabel:SetPoint("TOPLEFT", birthdayEB, "BOTTOMLEFT", 0, -6)
    customNoteLabel:SetText("|cffc79c6eNota Interna Customizada:|r")

    local customNoteEB = CreateFrame("EditBox", nil, inset2, template)
    customNoteEB:SetPoint("TOPLEFT", customNoteLabel, "BOTTOMLEFT", 0, -2)
    customNoteEB:SetSize(155, 52)
    customNoteEB:SetMultiLine(true)
    customNoteEB:SetMaxLetters(250)
    styleEditBox(customNoteEB, "Nota Interna Customizada\n|cffaaaaaaClique para editar|r")
    self._customNoteEB = customNoteEB

    -- Coluna Direita do Inset 2:
    -- Alts Vinculados (alts)
    local altsLabelBtn = CreateFrame("Button", nil, inset2)
    altsLabelBtn:SetPoint("TOPLEFT", sep2, "BOTTOMLEFT", 170, -6)
    altsLabelBtn:SetSize(160, 14)

    local altsLabel = altsLabelBtn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    altsLabel:SetPoint("LEFT", altsLabelBtn, "LEFT", 0, 0)
    altsLabel:SetText("|cffc79c6eAlts Vinculados:|r")

    local altsManageHint = altsLabelBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    altsManageHint:SetPoint("LEFT", altsLabel, "RIGHT", 4, 0)
    altsManageHint:SetText("|cffe6be6a[Gerenciar]|r")

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
    altsBtn:SetSize(158, 80)
    if altsBtn.SetBackdrop then
        altsBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 6, edgeSize = 6,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        altsBtn:SetBackdropColor(0.025, 0.018, 0.012, 0.90)
        altsBtn:SetBackdropBorderColor(0.38, 0.28, 0.16, 0.85)
    end

    local altsVal = altsBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    altsVal:SetPoint("TOPLEFT", altsBtn, "TOPLEFT", 4, -4)
    altsVal:SetPoint("BOTTOMRIGHT", altsBtn, "BOTTOMRIGHT", -4, 4)
    altsVal:SetJustifyH("LEFT")
    if altsVal.SetJustifyV then
        altsVal:SetJustifyV("TOP")
    end
    if altsVal.SetWordWrap then
        altsVal:SetWordWrap(true)
    end
    self._altsVal = altsVal
    self._altsBtn = altsBtn

    local altsHl = altsBtn:CreateTexture(nil, "HIGHLIGHT")
    altsHl:SetAllPoints(altsBtn)
    altsHl:SetColorTexture(0.85, 0.70, 0.25, 0.08)
    altsBtn:SetHighlightTexture(altsHl)

    altsBtn:SetScript("OnClick", function()
        self:toggleAltManager()
    end)
    altsBtn:SetScript("OnEnter", function(btn)
        if altsBtn.SetBackdropBorderColor then
            altsBtn:SetBackdropBorderColor(0.85, 0.70, 0.25, 1.0)
        end
        if GameTooltip then
            GameTooltip:SetOwner(btn, "ANCHOR_TOPLEFT")
            GameTooltip:SetText("Alts Vinculados\n|cffaaaaaaClique para abrir a janela de gerenciamento de alts|r")
            GameTooltip:Show()
        end
    end)
    altsBtn:SetScript("OnLeave", function(btn)
        if altsBtn.SetBackdropBorderColor then
            altsBtn:SetBackdropBorderColor(0.38, 0.28, 0.16, 0.85)
        end
        if GameTooltip then GameTooltip:Hide() end
    end)
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
            self._mainTagBtn:SetBackdropColor(0.22, 0.16, 0.05, 0.95)
            self._mainTagBtn:SetBackdropBorderColor(0.85, 0.68, 0.20, 0.95)
        end
    else
        self._mainTagText:SetText("|cffccb594A|r")
        if self._mainTagBtn.SetBackdropColor then
            self._mainTagBtn:SetBackdropColor(0.10, 0.09, 0.08, 0.95)
            self._mainTagBtn:SetBackdropBorderColor(0.45, 0.38, 0.26, 0.90)
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
        if UnitFactionGroup then
            faction = UnitFactionGroup("player")
        end

        if not faction and m then
            local r = (m.getRace and m:getRace() or ""):lower()
            if r:find("orc") or r:find("troll") or r:find("tauren") or r:find("undead") or r:find("renegad") or r:find("morto") or r:find("sangrent") then
                faction = "Horde"
            elseif r:find("human") or r:find("dwarf") or r:find("anão") or r:find("elf") or r:find("gnom") or r:find("draenei") then
                faction = "Alliance"
            end
        end

        if faction == "Horde" then
            return "Interface\\PVPFrame\\PVP-Currency-Horde"
        else
            return "Interface\\PVPFrame\\PVP-Currency-Alliance"
        end
    end

    -- Ícone da Facção (Leão da Aliança / Símbolo da Horda)
    if self._factionIcon then
        self._factionIcon:SetTexture(getFactionTexture(member))
        if self._factionIcon.SetTexCoord then
            self._factionIcon:SetTexCoord(4/32, 29/32, 2/32, 30/32)
        end
    end

    -- Raça do Jogador em português abaixo do ícone da facção
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
        local level = member:getLevel() or 1
        local classDisplay = member:getClassDisplayName() or member:getClass() or ""
        local subParts = { string.format("Nv. %d", level) }
        if racePt ~= "" then
            table.insert(subParts, racePt)
        end
        if classDisplay ~= "" then
            table.insert(subParts, classDisplay)
        end
        self._raceText:SetText(string.format("|cffccb594%s|r", table.concat(subParts, " • ")))
        self._raceText:Show()
    end

    -- Cabeçalho
    local coloredName = member:getColoredName()
    self._memberNameText:SetText(coloredName)

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
        self._statusVal:SetText("|cff888888Offline|r")
    end

    local zone = member:getZone()
    self._zoneVal:SetText(zone ~= "" and zone or "Desconhecida")

    local publicNote = member:getPublicNote()
    self._publicNoteVal:SetText(publicNote ~= "" and publicNote or "|cff887766(Nenhuma)|r")

    local officerNote = member:getOfficerNote()
    self._officerNoteVal:SetText(officerNote ~= "" and officerNote or "|cff887766(Nenhuma)|r")

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

    picker:SetSize(240, 260)
    picker:SetFrameStrata("DIALOG")
    picker:SetToplevel(true)
    picker:SetClampedToScreen(true)
    picker:EnableMouse(true)
    picker:Hide()

    if picker.SetBackdrop then
        picker:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 12,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        picker:SetBackdropColor(0.07, 0.05, 0.04, 0.98)
        picker:SetBackdropBorderColor(0.65, 0.48, 0.22, 1.0)
    end

    -- Permite fechar a janela ao pressionar Escape
    if UISpecialFrames then
        table.insert(UISpecialFrames, "GuildManagerRecruiterPickerFrame")
    end

    -- Título
    local title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", picker, "TOPLEFT", 12, -10)
    title:SetText("|cffffd200SELECIONAR RECRUTADOR|r")

    -- Botão Fechar ("X")
    local closeBtn = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -2, -2)
    closeBtn:SetSize(22, 22)
    closeBtn:SetScript("OnClick", function()
        picker:Hide()
    end)

    -- Campo de Busca (Filtro por nome em tempo real)
    local searchEB = CreateFrame("EditBox", nil, picker, template)
    searchEB:SetPoint("TOPLEFT", picker, "TOPLEFT", 10, -28)
    searchEB:SetPoint("RIGHT", picker, "RIGHT", -10, 0)
    searchEB:SetHeight(20)
    searchEB:SetFontObject("GameFontHighlightSmall")
    searchEB:SetAutoFocus(false)
    searchEB:SetTextInsets(6, 6, 1, 1)
    if searchEB.SetBackdrop then
        searchEB:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 6, edgeSize = 6,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        searchEB:SetBackdropColor(0.025, 0.018, 0.012, 0.90)
        searchEB:SetBackdropBorderColor(0.38, 0.28, 0.16, 0.85)
    end
    searchEB:SetScript("OnEditFocusGained", function(box)
        if box.SetBackdropBorderColor then
            box:SetBackdropBorderColor(0.85, 0.70, 0.25, 1.0)
        end
    end)
    searchEB:SetScript("OnEditFocusLost", function(box)
        if box.SetBackdropBorderColor then
            box:SetBackdropBorderColor(0.38, 0.28, 0.16, 0.85)
        end
    end)

    local searchHint = searchEB:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchHint:SetPoint("LEFT", searchEB, "LEFT", 8, 0)
    searchHint:SetText("Buscar membro...")
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
        hl:SetColorTexture(0.85, 0.70, 0.25, 0.12)
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
        self._recruiterPickerFrame:SetPoint("TOPLEFT", self._recruiterBtn, "BOTTOMLEFT", 0, -4)
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

    manager:SetSize(340, 465)
    manager:SetFrameStrata("DIALOG")
    manager:SetToplevel(true)
    manager:SetClampedToScreen(true)
    manager:EnableMouse(true)
    manager:Hide()

    if manager.SetBackdrop then
        manager:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 12,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        manager:SetBackdropColor(0.07, 0.05, 0.04, 0.98)
        manager:SetBackdropBorderColor(0.65, 0.48, 0.22, 1.0)
    end

    -- Permite fechar a janela ao pressionar Escape
    if UISpecialFrames then
        table.insert(UISpecialFrames, "GuildManagerAltManagerFrame")
    end

    -- Título da Janela (Centralizado, Dourado)
    local title = manager:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", manager, "TOP", 0, -8)
    title:SetText("|cffffd200Gerenciar Alts Vinculados|r")

    -- Subtítulo com o nome do membro inspecionado
    local subtitle = manager:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", manager, "TOPLEFT", 14, -24)
    subtitle:SetText("Família de alts")
    self._altManagerSubtitle = subtitle

    -- Botão Fechar ("X" clássico vermelho com moldura)
    local closeBtn = CreateFrame("Button", nil, manager, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", manager, "TOPRIGHT", -2, -2)
    closeBtn:SetSize(22, 22)
    closeBtn:SetScript("OnClick", function()
        manager:Hide()
    end)

    -- =========================================================================
    -- INSET 1: PERSONAGENS VINCULADOS (Membros da mesma família)
    -- =========================================================================
    local inset1 = CreateFrame("Frame", nil, manager, template)
    inset1:SetPoint("TOPLEFT", manager, "TOPLEFT", 10, -42)
    inset1:SetPoint("RIGHT", manager, "RIGHT", -10, 0)
    inset1:SetHeight(188)
    if inset1.SetBackdrop then
        inset1:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        inset1:SetBackdropColor(0.035, 0.025, 0.018, 0.80)
        inset1:SetBackdropBorderColor(0.38, 0.28, 0.16, 0.85)
    end

    local sec1Title = inset1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sec1Title:SetPoint("TOPLEFT", inset1, "TOPLEFT", 10, -8)
    sec1Title:SetText("|cffffd200PERSONAGENS VINCULADOS|r")

    local sep1 = inset1:CreateTexture(nil, "ARTWORK")
    sep1:SetPoint("TOPLEFT", inset1, "TOPLEFT", 8, -24)
    sep1:SetPoint("RIGHT", inset1, "RIGHT", -8, 0)
    sep1:SetHeight(1)
    sep1:SetColorTexture(0.45, 0.35, 0.20, 0.65)

    local sec1Hint = inset1:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sec1Hint:SetPoint("TOPLEFT", sep1, "BOTTOMLEFT", 2, -4)
    sec1Hint:SetText("|cffc79c6eApenas 1 Main por família (clique em [A] para tornar Main):|r")

    -- Mensagem informativa caso não haja alts vinculados ainda
    local emptyNotice = inset1:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyNotice:SetPoint("TOPLEFT", sec1Hint, "BOTTOMLEFT", 6, -18)
    emptyNotice:SetPoint("RIGHT", inset1, "RIGHT", -12, 0)
    emptyNotice:SetJustifyH("LEFT")
    emptyNotice:SetText("|cff887766Nenhum outro alt vinculado.\nUse a lista abaixo para selecionar e vincular membros.|r")
    emptyNotice:Hide()
    self._familyEmptyNotice = emptyNotice

    -- Linhas da Família de Personagens Vinculados (até 5 visíveis)
    self._altFamilyRows = {}
    local numFamilyRows = 5
    local familyRowHeight = 22

    for i = 1, numFamilyRows do
        local row = CreateFrame("Frame", nil, inset1)
        row:SetHeight(familyRowHeight)
        row:SetPoint("TOPLEFT", sec1Hint, "BOTTOMLEFT", 0, -4 - (i - 1) * (familyRowHeight + 2))
        row:SetPoint("RIGHT", inset1, "RIGHT", -8, 0)

        -- Botão Main/Alt Tag [M] / [A]
        local mainBtn = CreateFrame("Button", nil, row, template)
        mainBtn:SetSize(22, 18)
        mainBtn:SetPoint("LEFT", row, "LEFT", 2, 0)
        if mainBtn.SetBackdrop then
            mainBtn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 6, edgeSize = 6,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
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
                    GameTooltip:SetText(string.format("|cffccb594Personagem Secundário [A]|r\n|cffffffff%s|r\n|cff00ff00Clique para definir como o ÚNICO Main desta família|r\n|cffaaaaaa(Todos os outros se tornarão automaticamente alts)|r", row.memberName))
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
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 4, edgeSize = 4,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            unlinkBtn:SetBackdropColor(0.18, 0.06, 0.05, 0.90)
            unlinkBtn:SetBackdropBorderColor(0.55, 0.22, 0.18, 0.85)
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
    inset2:SetPoint("RIGHT", manager, "RIGHT", -10, 0)
    inset2:SetHeight(218)
    if inset2.SetBackdrop then
        inset2:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        inset2:SetBackdropColor(0.035, 0.025, 0.018, 0.80)
        inset2:SetBackdropBorderColor(0.38, 0.28, 0.16, 0.85)
    end

    local sec2Title = inset2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sec2Title:SetPoint("TOPLEFT", inset2, "TOPLEFT", 10, -8)
    sec2Title:SetText("|cffffd200VINCULAR NOVO ALT|r")

    local sep2 = inset2:CreateTexture(nil, "ARTWORK")
    sep2:SetPoint("TOPLEFT", inset2, "TOPLEFT", 8, -24)
    sep2:SetPoint("RIGHT", inset2, "RIGHT", -8, 0)
    sep2:SetHeight(1)
    sep2:SetColorTexture(0.45, 0.35, 0.20, 0.65)

    -- Campo de Busca de Membros
    local searchEB = CreateFrame("EditBox", nil, inset2, template)
    searchEB:SetPoint("TOPLEFT", sep2, "BOTTOMLEFT", 2, -4)
    searchEB:SetPoint("RIGHT", inset2, "RIGHT", -8, 0)
    searchEB:SetHeight(20)
    searchEB:SetFontObject("GameFontHighlightSmall")
    searchEB:SetAutoFocus(false)
    searchEB:SetTextInsets(6, 6, 1, 1)
    if searchEB.SetBackdrop then
        searchEB:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 6, edgeSize = 6,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        searchEB:SetBackdropColor(0.025, 0.018, 0.012, 0.90)
        searchEB:SetBackdropBorderColor(0.38, 0.28, 0.16, 0.85)
    end
    searchEB:SetScript("OnEditFocusGained", function(box)
        if box.SetBackdropBorderColor then
            box:SetBackdropBorderColor(0.85, 0.70, 0.25, 1.0)
        end
    end)
    searchEB:SetScript("OnEditFocusLost", function(box)
        if box.SetBackdropBorderColor then
            box:SetBackdropBorderColor(0.38, 0.28, 0.16, 0.85)
        end
    end)

    local searchHint = searchEB:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchHint:SetPoint("LEFT", searchEB, "LEFT", 8, 0)
    searchHint:SetText("Buscar membro da guilda...")
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
        hl:SetColorTexture(0.85, 0.70, 0.25, 0.08)

        -- Botão Vincular [+ Vincular]
        local linkBtn = CreateFrame("Button", nil, row, template)
        linkBtn:SetSize(72, 18)
        linkBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        if linkBtn.SetBackdrop then
            linkBtn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 4, edgeSize = 4,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            linkBtn:SetBackdropColor(0.10, 0.14, 0.08, 0.90)
            linkBtn:SetBackdropBorderColor(0.35, 0.55, 0.25, 0.85)
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

    local currentNameLower = (self._currentMember:getName() or ""):lower()

    for i, row in ipairs(self._altFamilyRows) do
        local m = family[i]
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
                    row.mainBtn:SetBackdropColor(0.22, 0.16, 0.05, 0.95)
                    row.mainBtn:SetBackdropBorderColor(0.85, 0.68, 0.20, 0.95)
                end
            else
                row.mainBtn.text:SetText("|cffccb594A|r")
                if row.mainBtn.SetBackdropColor then
                    row.mainBtn:SetBackdropColor(0.10, 0.09, 0.08, 0.95)
                    row.mainBtn:SetBackdropBorderColor(0.45, 0.38, 0.26, 0.90)
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
