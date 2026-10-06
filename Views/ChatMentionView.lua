---@class ChatMentionView
ChatMentionView = {}
ChatMentionView.__index = ChatMentionView

local DIALOG_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 24,
    edgeSize = 24,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
}

local SUB_CONTAINER_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local FLASH_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 20,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
}

local PALETTE = {
    FRAME_BG = { 0.055, 0.035, 0.015, 0.96 },
    FRAME_BORDER = { 1.0, 0.68, 0.22, 1.0 },
    SUB_BOX_BG = { 0.02, 0.02, 0.02, 0.85 },
    SUB_BOX_BORDER = { 0.45, 0.32, 0.12, 0.8 },
    FOCUS_BG = { 0.08, 0.05, 0.02, 0.95 },
    FOCUS_BORDER = { 1.0, 0.82, 0.0, 1.0 },
    HIGHLIGHT_TINT = { 1.0, 0.82, 0.0 },
    FLASH_BORDER = { 1.0, 0.78, 0.1, 1.0 },
    FLASH_BG = { 1.0, 0.70, 0.05, 0.14 },
}

--- Construtor da View de Menção no Chat da Guilda.
---@return ChatMentionView
function ChatMentionView:new()
    local instance = setmetatable({}, self)

    instance._pickerFrame = nil
    instance._searchEB = nil
    instance._scrollBar = nil
    instance._rows = {}
    instance._numVisibleRows = 8
    instance._rowHeight = 22

    instance._fullMemberList = {}
    instance._filteredList = {}
    instance._scrollOffset = 0
    instance._selectedIndex = 1

    instance._targetEditBox = nil
    instance._onSelectCallback = nil
    instance._onCloseCallback = nil

    instance._flashOverlay = nil
    instance._lastSoundPlayTime = 0

    instance:createPickerUI()
    instance:createFlashOverlay()

    return instance
end

--- Cria a janela popup de autocompletar menções (@).
function ChatMentionView:createPickerUI()
    if self._pickerFrame then
        return
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local picker = CreateFrame("Frame", "GM_ChatMentionPickerFrame", UIParent, template)
    self._pickerFrame = picker

    picker:SetSize(280, 260)
    picker:SetFrameStrata("DIALOG")
    picker:SetToplevel(true)
    picker:SetClampedToScreen(true)
    picker:EnableMouse(true)
    picker:Hide()

    if picker.SetBackdrop then
        picker:SetBackdrop(DIALOG_BACKDROP)
        picker:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], PALETTE.FRAME_BG[4])
        picker:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], PALETTE.FRAME_BORDER[4])
    end

    if UISpecialFrames then
        table.insert(UISpecialFrames, "GM_ChatMentionPickerFrame")
    end

    -- Título da Janela
    local title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", picker, "TOPLEFT", 14, -12)
    title:SetText("|cffffd200Mencionar Membro (@)|r")

    -- Botão Fechar ("X")
    local closeBtn = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -4, -4)
    closeBtn:SetSize(24, 24)
    closeBtn:SetScript("OnClick", function()
        self:hidePicker()
    end)

    -- Campo de Busca / Digitação do Nome
    local searchEB = CreateFrame("EditBox", "GM_ChatMentionSearchEB", picker, template)
    self._searchEB = searchEB
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
    searchHint:SetText("|cffaaaaaaDigite o nome do membro...|r")
    searchEB.hint = searchHint

    searchEB:SetScript("OnTextChanged", function(box)
        local txt = box:GetText()
        if txt and txt ~= "" then
            searchHint:Hide()
        else
            searchHint:Show()
        end
        self:filterList(txt)
    end)

    searchEB:SetScript("OnEnterPressed", function()
        self:confirmSelection()
    end)

    searchEB:SetScript("OnTabPressed", function()
        self:confirmSelection()
    end)

    searchEB:SetScript("OnEscapePressed", function()
        self:hidePicker()
    end)

    searchEB:SetScript("OnArrowPressed", function(box, key)
        if key == "DOWN" then
            self:navigate(1)
        elseif key == "UP" then
            self:navigate(-1)
        end
    end)

    searchEB:SetScript("OnKeyDown", function(box, key)
        if key == "DOWN" then
            self:navigate(1)
        elseif key == "UP" then
            self:navigate(-1)
        elseif key == "ENTER" or key == "TAB" then
            self:confirmSelection()
        elseif key == "ESCAPE" then
            self:hidePicker()
        elseif key == "BACKSPACE" then
            local currentText = box:GetText() or ""
            if currentText == "" then
                self:hidePicker()
            end
        end
    end)

    -- Rolagem com a roda do mouse
    picker:EnableMouseWheel(true)
    picker:SetScript("OnMouseWheel", function(_, delta)
        self:scroll(delta)
    end)

    -- Scrollbar lateral
    local scrollBar = CreateFrame("Slider", "GM_ChatMentionScrollBar", picker, "UIPanelScrollBarTemplate")
    self._scrollBar = scrollBar
    scrollBar:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -6, -58)
    scrollBar:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -6, 12)
    scrollBar:SetWidth(16)
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValueStep(1)
    scrollBar:SetScript("OnValueChanged", function(_, val)
        self._scrollOffset = math.floor(val)
        self:renderRows()
    end)

    local upBtn = _G["GM_ChatMentionScrollBarScrollUpButton"] or (scrollBar and scrollBar.ScrollUpButton)
    if upBtn then
        upBtn:SetScript("OnClick", function()
            self:scroll(1)
        end)
    end
    local downBtn = _G["GM_ChatMentionScrollBarScrollDownButton"] or (scrollBar and scrollBar.ScrollDownButton)
    if downBtn then
        downBtn:SetScript("OnClick", function()
            self:scroll(-1)
        end)
    end

    -- Mensagem de "Nenhum membro encontrado"
    local emptyLabel = picker:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyLabel:SetPoint("CENTER", picker, "CENTER", 0, -30)
    emptyLabel:SetText("|cff888888Nenhum membro encontrado|r")
    emptyLabel:Hide()
    self._emptyLabel = emptyLabel

    -- Linhas recicladas de membros
    self._rows = {}
    for i = 1, self._numVisibleRows do
        local btn = CreateFrame("Button", nil, picker)
        btn:SetHeight(self._rowHeight)
        btn:SetPoint("TOPLEFT", searchEB, "BOTTOMLEFT", 0, -4 - (i - 1) * self._rowHeight)
        btn:SetPoint("RIGHT", scrollBar, "LEFT", -4, 0)

        -- Fundo de seleção ativa (via teclado)
        local selBg = btn:CreateTexture(nil, "BACKGROUND")
        selBg:SetAllPoints(btn)
        selBg:SetColorTexture(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], 0.22)
        selBg:Hide()
        btn.selectedBg = selBg

        -- Highlight de hover
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(btn)
        hl:SetColorTexture(PALETTE.HIGHLIGHT_TINT[1], PALETTE.HIGHLIGHT_TINT[2], PALETTE.HIGHLIGHT_TINT[3], 0.12)
        btn:SetHighlightTexture(hl)

        -- Ícone de status (online = verde, offline = cinza)
        local statusDot = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statusDot:SetPoint("LEFT", btn, "LEFT", 4, 0)
        statusDot:SetText("|cff00ff00●|r")
        btn.statusDot = statusDot

        -- Nome do membro (colorido por classe)
        local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", statusDot, "RIGHT", 4, 0)
        nameText:SetPoint("RIGHT", btn, "RIGHT", -60, 0)
        nameText:SetJustifyH("LEFT")
        btn.nameText = nameText

        -- Info adicional (Lv / Rank)
        local infoText = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        infoText:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
        infoText:SetJustifyH("RIGHT")
        btn.infoText = infoText

        btn:EnableMouseWheel(true)
        btn:SetScript("OnMouseWheel", function(_, delta)
            self:scroll(delta)
        end)

        btn:SetScript("OnEnter", function()
            local index = (self._scrollOffset or 0) + i
            self._selectedIndex = index
            self:updateSelectionVisuals()
        end)

        btn:SetScript("OnClick", function(b)
            if b.itemData and b.itemData.name then
                self:selectMember(b.itemData.name)
            end
        end)

        self._rows[i] = btn
    end
end

--- Cria o frame overlay para piscar/destacar a janela do chat quando o membro for mencionado.
function ChatMentionView:createFlashOverlay()
    if self._flashOverlay then
        return
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local overlay = CreateFrame("Frame", "GM_ChatMentionFlashOverlay", UIParent, template)
    self._flashOverlay = overlay

    overlay:SetFrameStrata("HIGH")
    overlay:SetAllPoints(DEFAULT_CHAT_FRAME or ChatFrame1)
    overlay:EnableMouse(false)
    overlay:Hide()

    if overlay.SetBackdrop then
        overlay:SetBackdrop(FLASH_BACKDROP)
        overlay:SetBackdropColor(PALETTE.FLASH_BG[1], PALETTE.FLASH_BG[2], PALETTE.FLASH_BG[3], PALETTE.FLASH_BG[4])
        overlay:SetBackdropBorderColor(PALETTE.FLASH_BORDER[1], PALETTE.FLASH_BORDER[2], PALETTE.FLASH_BORDER[3], 1.0)
    end

    -- Faixa de alerta no topo do chat frame
    local badge = CreateFrame("Frame", nil, overlay, template)
    badge:SetSize(250, 20)
    badge:SetPoint("TOP", overlay, "TOP", 0, 10)
    if badge.SetBackdrop then
        badge:SetBackdrop(SUB_CONTAINER_BACKDROP)
        badge:SetBackdropColor(0.08, 0.04, 0.01, 0.95)
        badge:SetBackdropBorderColor(PALETTE.FLASH_BORDER[1], PALETTE.FLASH_BORDER[2], PALETTE.FLASH_BORDER[3], 1.0)
    end
    local badgeText = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badgeText:SetPoint("CENTER", badge, "CENTER", 0, 0)
    badgeText:SetText("|cffffd200VOCÊ FOI MENCIONADO NO CHAT DA GUILDA|r")
    badgeText:SetTextColor(1.0, 0.85, 0.2, 1.0)
    overlay.badge = badge
end

--- Exibe a janela de menção ancorada logo acima da EditBox do chat ativa.
---@param targetEditBox table @EditBox do chat que acionou o @
---@param memberList table @Lista completa de membros da guilda
---@param initialQuery string|nil @Texto inicial já digitado após o @
---@param onSelect function @Callback chamado quando um membro for selecionado (recebe memberName)
---@param onClose function|nil @Callback opcional chamado ao fechar a janela
function ChatMentionView:showPicker(targetEditBox, memberList, initialQuery, onSelect, onClose)
    if not self._pickerFrame then
        self:createPickerUI()
    end

    self._targetEditBox = targetEditBox
    self._fullMemberList = memberList or {}
    self._onSelectCallback = onSelect
    self._onCloseCallback = onClose
    self._scrollOffset = 0
    self._selectedIndex = 1

    -- Ancoragem dinâmica sobre a EditBox do Chat
    self._pickerFrame:ClearAllPoints()
    if targetEditBox and targetEditBox.GetLeft then
        self._pickerFrame:SetPoint("BOTTOMLEFT", targetEditBox, "TOPLEFT", 0, 4)
    else
        self._pickerFrame:SetPoint("BOTTOMLEFT", ChatFrame1EditBox or UIParent, "TOPLEFT", 0, 4)
    end

    local query = initialQuery or ""
    if self._searchEB then
        self._searchEB:SetText(query)
    end

    self:filterList(query)
    self._pickerFrame:Show()

    -- Foca automaticamente no campo de digitação do membro
    if self._searchEB then
        self._searchEB:SetFocus()
        if query ~= "" then
            self._searchEB:SetCursorPosition(#query)
        end
    end
end

--- Oculta a janela de menção e opcionalmente retorna o foco à caixa de texto do chat original.
---@param skipFocus boolean|nil
function ChatMentionView:hidePicker(skipFocus)
    if self._pickerFrame then
        self._pickerFrame:Hide()
    end

    if self._searchEB then
        self._searchEB:ClearFocus()
        self._searchEB:SetText("")
    end

    if not skipFocus and self._targetEditBox and self._targetEditBox.SetFocus then
        self._targetEditBox:SetFocus()
    end

    if self._onCloseCallback then
        local cb = self._onCloseCallback
        self._onCloseCallback = nil
        cb()
    end
end

--- Verifica se a janela de menção está visível no momento.
---@return boolean
function ChatMentionView:isPickerShown()
    return self._pickerFrame and self._pickerFrame:IsShown() or false
end

--- Filtra a lista de membros em tempo real com base no que foi digitado.
---@param filterText string|nil
function ChatMentionView:filterList(filterText)
    local query = filterText and filterText:lower():match("^%s*(.-)%s*$") or ""

    local items = {}
    for _, m in ipairs(self._fullMemberList) do
        local name = m.name or ""
        local nameLower = name:lower()

        if query == "" then
            table.insert(items, m)
        else
            local startsWith = nameLower:sub(1, #query) == query
            local findPos = nameLower:find(query, 1, true)
            if startsWith then
                m._sortWeight = 1
                table.insert(items, m)
            elseif findPos then
                m._sortWeight = 2
                table.insert(items, m)
            end
        end
    end

    -- Ordenação inteligente:
    -- 1. Prefixo exato primeiro, depois substring
    -- 2. Membros online primeiro
    -- 3. Alfabético por nome
    table.sort(items, function(a, b)
        local wA = a._sortWeight or 3
        local wB = b._sortWeight or 3
        if wA ~= wB then
            return wA < wB
        end
        if a.isOnline ~= b.isOnline then
            return a.isOnline == true
        end
        return (a.name or ""):lower() < (b.name or ""):lower()
    end)

    self._filteredList = items

    -- Ajusta os limites da scrollbar
    local maxOffset = math.max(0, #items - self._numVisibleRows)
    if self._scrollOffset > maxOffset then
        self._scrollOffset = maxOffset
    end

    if self._scrollBar then
        self._scrollBar:SetMinMaxValues(0, maxOffset)
        self._scrollBar:SetValue(self._scrollOffset)
        if maxOffset == 0 then
            self._scrollBar:Hide()
        else
            self._scrollBar:Show()
        end
    end

    if self._selectedIndex > #items then
        self._selectedIndex = math.max(1, #items)
    end

    self:renderRows()
end

--- Renderiza os botões visíveis de acordo com a página/offset atual.
function ChatMentionView:renderRows()
    if not self._rows or not self._filteredList then
        return
    end

    local items = self._filteredList
    local offset = self._scrollOffset or 0

    if #items == 0 then
        if self._emptyLabel then
            self._emptyLabel:Show()
        end
    else
        if self._emptyLabel then
            self._emptyLabel:Hide()
        end
    end

    for i = 1, self._numVisibleRows do
        local btn = self._rows[i]
        local itemIndex = offset + i
        local item = items[itemIndex]

        if item then
            btn.itemData = item

            -- Status online/offline
            if item.isOnline then
                btn.statusDot:SetText("|cff00ff00●|r")
            else
                btn.statusDot:SetText("|cff666666○|r")
            end

            -- Nome formatado
            btn.nameText:SetText(item.coloredName or item.name or "")

            -- Info adicional (Lv / Rank)
            local levelStr = item.level and item.level > 0 and string.format("|cffffd200Lv %d|r", item.level) or ""
            local rankStr = item.rank and item.rank ~= "" and string.format("|cff777777%s|r", item.rank) or ""
            local fullInfo = levelStr
            if rankStr ~= "" then
                fullInfo = fullInfo ~= "" and (fullInfo .. " " .. rankStr) or rankStr
            end
            btn.infoText:SetText(fullInfo)

            btn:Show()
        else
            btn.itemData = nil
            btn:Hide()
        end
    end

    self:updateSelectionVisuals()
end

--- Atualiza a indicação visual do item selecionado via teclado ou mouse.
function ChatMentionView:updateSelectionVisuals()
    local offset = self._scrollOffset or 0
    for i = 1, self._numVisibleRows do
        local btn = self._rows[i]
        local itemIndex = offset + i
        if btn and btn:IsShown() and btn.selectedBg then
            if itemIndex == self._selectedIndex then
                btn.selectedBg:Show()
            else
                btn.selectedBg:Hide()
            end
        end
    end
end

--- Navega pela lista via setas cima/baixo.
---@param delta number @+1 para descer, -1 para subir
function ChatMentionView:navigate(delta)
    local total = #(self._filteredList or {})
    if total == 0 then
        return
    end

    local newIndex = self._selectedIndex + delta
    if newIndex < 1 then
        newIndex = 1
    elseif newIndex > total then
        newIndex = total
    end

    self._selectedIndex = newIndex

    -- Rola a visualização se o cursor sair da janela visível
    if self._selectedIndex <= self._scrollOffset then
        self._scrollOffset = self._selectedIndex - 1
    elseif self._selectedIndex > (self._scrollOffset + self._numVisibleRows) then
        self._scrollOffset = self._selectedIndex - self._numVisibleRows
    end

    if self._scrollBar then
        self._scrollBar:SetValue(self._scrollOffset)
    end

    self:renderRows()
end

--- Executa a rolagem da lista por mousewheel ou botões da barra.
---@param delta number
function ChatMentionView:scroll(delta)
    local maxOffset = math.max(0, #(self._filteredList or {}) - self._numVisibleRows)
    local current = self._scrollOffset or 0
    local target = current - (delta * 2)

    if target < 0 then
        target = 0
    elseif target > maxOffset then
        target = maxOffset
    end

    self._scrollOffset = target
    if self._scrollBar then
        self._scrollBar:SetValue(target)
    end
    self:renderRows()
end

--- Confirma a seleção do membro ativo no momento.
function ChatMentionView:confirmSelection()
    local items = self._filteredList or {}
    if #items == 0 then
        self:hidePicker()
        return
    end

    local selected = items[self._selectedIndex] or items[1]
    if selected and selected.name then
        self:selectMember(selected.name)
    else
        self:hidePicker()
    end
end

--- Seleciona o membro, fecha o popup imediatamente e executa o callback de injeção no chat.
---@param memberName string
function ChatMentionView:selectMember(memberName)
    local cb = self._onSelectCallback
    local targetEB = self._targetEditBox
    self._onSelectCallback = nil
    self._onCloseCallback = nil

    self:hidePicker(true)

    if cb and memberName and memberName ~= "" then
        cb(memberName, targetEB)
    elseif targetEB and targetEB.SetFocus then
        targetEB:SetFocus()
    end
end

--- Executa a animação de pulso/piscar personalizada no chat do membro mencionado.
---@param chatFrame table|nil @ChatFrame que recebeu a menção
function ChatMentionView:flashChatFrame(chatFrame)
    if not self._flashOverlay then
        self:createFlashOverlay()
    end

    local target = chatFrame or DEFAULT_CHAT_FRAME or ChatFrame1
    if not target then
        return
    end

    local allowFlash = not (_G.GM_DB and _G.GM_DB.settings and _G.GM_DB.settings.enableMentionFlash == false)
    if allowFlash then
        local overlay = self._flashOverlay
        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT", target, "TOPLEFT", -6, 6)
        overlay:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 6, -6)
        overlay:Show()

        -- Pisca a aba do chat também se disponível
        local tab = _G[target:GetName() .. "Tab"]
        if FCF_StartAlertFlash then
            pcall(FCF_StartAlertFlash, target)
        elseif tab and tab.StartFlashing then
            pcall(tab.StartFlashing, tab)
        elseif UIFrameFlash and tab then
            pcall(UIFrameFlash, tab, 0.25, 0.25, 2.5, true, 0.1, 0.1)
        end

        -- Animação de pulso senoidal suave (4 pulsos vibrantes ao longo de 2.4s)
        local totalDuration = 2.4
        local elapsed = 0
        local pulseFreq = 3.5

        overlay:SetScript("OnUpdate", function(f, dt)
            elapsed = elapsed + (dt or 0.016)
            if elapsed >= totalDuration then
                f:Hide()
                f:SetScript("OnUpdate", nil)
            else
                -- Oscila o alpha suavemente entre 0.15 e 0.95
                local wave = 0.5 + 0.5 * math.sin(elapsed * pulseFreq * math.pi * 2 - math.pi / 2)
                local alpha = 0.15 + (0.80 * wave)
                f:SetAlpha(alpha)
            end
        end)
    end

    -- Toca o som de alerta (com proteção de debounce de 0.5s)
    local now = GetTime and GetTime() or 0
    if (now - (self._lastSoundPlayTime or 0)) > 0.5 then
        self._lastSoundPlayTime = now
        self:playMentionSound()
    end
end

--- Toca o som de notificação quando for mencionado.
function ChatMentionView:playMentionSound()
    if not PlaySound then
        return
    end

    if _G.GM_DB and _G.GM_DB.settings and _G.GM_DB.settings.enableMentionSound == false then
        return
    end

    local choice = (_G.GM_DB and _G.GM_DB.settings and _G.GM_DB.settings.mentionSoundChoice) or "whisper"
    local soundId = 3081
    if choice == "raid" then
        soundId = 8959
    elseif choice == "ready" then
        soundId = 8960
    elseif choice == "coin" then
        soundId = 120
    end

    pcall(PlaySound, soundId, "Master")
end
