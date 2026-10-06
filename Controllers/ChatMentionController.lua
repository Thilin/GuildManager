---@class ChatMentionController
---@field private _memberService MemberService
---@field private _guildRosterService GuildRosterService
---@field private _view ChatMentionView
ChatMentionController = {}
ChatMentionController.__index = ChatMentionController

--- Construtor do Controller de Menções no Chat da Guilda.
---@param memberService MemberService
---@param guildRosterService GuildRosterService
---@param chatMentionView ChatMentionView
---@return ChatMentionController
function ChatMentionController:new(memberService, guildRosterService, chatMentionView)
    local instance = setmetatable({}, self)
    instance._memberService = memberService
    instance._guildRosterService = guildRosterService
    instance._view = chatMentionView

    instance._activeEditBox = nil
    instance._mentionPreText = ""
    instance._isInsertingMention = false
    instance._hookedEditBoxes = {}
    instance._completedMentions = {}
    instance._justCompletedMember = nil

    return instance
end

local function safeHookScript(frame, scriptName, handler)
    if not frame then return end
    local success = pcall(frame.HookScript, frame, scriptName, handler)
    if not success then
        local oldScript = frame:GetScript(scriptName)
        frame:SetScript(scriptName, function(...)
            if oldScript then
                pcall(oldScript, ...)
            end
            handler(...)
        end)
    end
end

local function getClassColorCode(classFileName)
    if classFileName and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFileName] then
        local c = RAID_CLASS_COLORS[classFileName]
        if c.colorStr then
            return "|c" .. c.colorStr
        end
        local r = math.floor((c.r or 1) * 255)
        local g = math.floor((c.g or 1) * 255)
        local b = math.floor((c.b or 1) * 255)
        return string.format("|cff%02x%02x%02x", r, g, b)
    end
    return "|cffffd200"
end

local function getGuildChatColorCode()
    if ChatTypeInfo and ChatTypeInfo["GUILD"] then
        local c = ChatTypeInfo["GUILD"]
        if c.colorStr then
            return "|c" .. c.colorStr
        end
        local r = math.floor((c.r or 0.25) * 255)
        local g = math.floor((c.g or 1.0) * 255)
        local b = math.floor((c.b or 0.25) * 255)
        return string.format("|cff%02x%02x%02x", r, g, b)
    end
    return "|cff40ff40"
end

--- Vincula os scripts necessários a uma EditBox de chat específica.
---@param eb table
function ChatMentionController:hookEditBox(eb)
    if not eb or not eb.HookScript or self._hookedEditBoxes[eb] then
        return
    end
    self._hookedEditBoxes[eb] = true

    safeHookScript(eb, "OnTextChanged", function(box, userInput)
        self:onChatTextChanged(box, userInput)
    end)

    safeHookScript(eb, "OnKeyDown", function(box, key)
        if self._view and self._view:isPickerShown() then
            if key == "DOWN" then
                self._view:navigate(1)
            elseif key == "UP" then
                self._view:navigate(-1)
            elseif key == "TAB" then
                self._view:confirmSelection()
            elseif key == "ESCAPE" then
                self._view:hidePicker()
            end
        end
    end)

    safeHookScript(eb, "OnEditFocusLost", function(box)
        self:onChatFocusLost(box)
    end)

    safeHookScript(eb, "OnHide", function(box)
        self._completedMentions = {}
        self._justCompletedMember = nil
        if self._view then
            self._view:hidePicker(true)
        end
    end)

    safeHookScript(eb, "OnEscapePressed", function(box)
        if self._view and self._view:isPickerShown() then
            self._view:hidePicker(true)
        end
    end)
end

--- Inicializa os ganchos (hooks) na interface de chat da Blizzard.
function ChatMentionController:initHooks()
    self._hookedEditBoxes = self._hookedEditBoxes or {}

    -- 1. Hook direto em todas as caixas de chat disponíveis (ChatFrame1EditBox a ChatFrame10EditBox)
    local maxWindows = NUM_CHAT_WINDOWS or 10
    for i = 1, maxWindows do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb then
            self:hookEditBox(eb)
        end
    end

    -- 2. Hook dinâmico ao ativar chat para garantir captura caso novos frames sejam instanciados
    if type(_G.ChatEdit_ActivateChat) == "function" then
        hooksecurefunc("ChatEdit_ActivateChat", function(editBox)
            if editBox then
                self:hookEditBox(editBox)
            end
        end)
    end

    -- 3. Hooks globais da Blizzard com proteção estrita de tipo (apenas se existirem no cliente)
    if type(_G.ChatEdit_OnTextChanged) == "function" then
        hooksecurefunc("ChatEdit_OnTextChanged", function(editBox, userInput)
            self:onChatTextChanged(editBox, userInput)
        end)
    end

    if type(_G.ChatEdit_OnTabPressed) == "function" then
        hooksecurefunc("ChatEdit_OnTabPressed", function(editBox)
            if self._view and self._view:isPickerShown() then
                self._view:confirmSelection()
            end
        end)
    end

    if type(_G.ChatEdit_OnEditFocusLost) == "function" then
        hooksecurefunc("ChatEdit_OnEditFocusLost", function(editBox)
            self:onChatFocusLost(editBox)
        end)
    end

    -- 4. Registra filtro de mensagem EXCLUSIVAMENTE para o chat da guilda (CHAT_MSG_GUILD)
    if ChatFrame_AddMessageEventFilter then
        ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", function(chatFrame, event, msg, author, ...)
            return self:onGuildChatMessage(chatFrame, event, msg, author, ...)
        end)
    end
end

--- Verifica se o EditBox fornecido está atualmente configurado para o chat da guilda (/g, /guild).
---@param editBox table
---@return boolean
function ChatMentionController:isGuildChat(editBox)
    if not editBox then
        return false
    end

    -- Verifica atributo chatType da Blizzard
    local chatType = editBox:GetAttribute("chatType")
    if chatType == "GUILD" then
        return true
    end

    -- Verifica se o jogador acabou de digitar /g ou /guild antes do espaço
    local text = editBox:GetText() or ""
    if text:match("^/[gG]%s+") or text:match("^/[gG][uU][iI][lL][dD]%s+") then
        return true
    end

    return false
end

--- Disparado sempre que o texto do EditBox do chat é modificado.
---@param editBox table
---@param userInput boolean
function ChatMentionController:onChatTextChanged(editBox, userInput)
    -- Se o evento foi programático (ex: SetText do addon) ou durante inserção, não processa
    if self._isInsertingMention or (userInput == false) then
        return
    end

    -- Requisito estrito: funciona APENAS para o chat da guilda
    if not self:isGuildChat(editBox) then
        if self._view and self._view:isPickerShown() then
            self._view:hidePicker(true)
        end
        return
    end

    local text = editBox:GetText() or ""
    if text == "" then
        self._completedMentions = {}
        self._justCompletedMember = nil
        if self._view and self._view:isPickerShown() then
            self._view:hidePicker(true)
        end
        return
    end

    local cursorPos = editBox:GetCursorPosition() or #text
    local textBeforeCursor = text:sub(1, cursorPos)

    -- Localiza a última ocorrência de '@' antes do cursor
    local lastAtIndex = textBeforeCursor:match(".*()@")
    if lastAtIndex then
        local pre = textBeforeCursor:sub(1, lastAtIndex - 1)
        local mentionQuery = textBeforeCursor:sub(lastAtIndex + 1)

        -- Garante que o '@' esteja no início ou após espaço/pontuação
        local isValidAt = (pre == "") or pre:match("[%s%(%[%{]$")

        -- Se a menção logo antes do cursor já foi selecionada/completada, não deve abrir
        local trimmedQuery = mentionQuery:match("^%s*(.-)%s*$") or ""
        local trimmedLower = trimmedQuery:lower()
        if self._completedMentions and self._completedMentions[trimmedLower] then
            if self._view and self._view:isPickerShown() then
                self._view:hidePicker(true)
            end
            return
        end

        if self._justCompletedMember then
            local compLower = self._justCompletedMember:lower()
            if trimmedLower == compLower or trimmedLower:find("^" .. compLower:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")) then
                if self._view and self._view:isPickerShown() then
                    self._view:hidePicker(true)
                end
                return
            end
        end

        -- Se a query de menção termina com espaço ou quebra de linha, a menção já foi finalizada
        local hasTrailingSpace = mentionQuery:match("%s$")
        local spaceCount = 0
        for _ in mentionQuery:gmatch("%s") do
            spaceCount = spaceCount + 1
        end

        local isAlreadyFinished = (spaceCount >= 2) or (hasTrailingSpace and not (self._view and self._view:isPickerShown()))

        local isValidQuery = not isAlreadyFinished and #mentionQuery <= 35 and not mentionQuery:find("[%c\r\n]")

        if isValidAt and isValidQuery then
            if _G.GM_DB and _G.GM_DB.settings and _G.GM_DB.settings.enableChatMentions == false then
                if self._view and self._view:isPickerShown() then self._view:hidePicker() end
                return
            end

            self._activeEditBox = editBox
            self._mentionPreText = pre

            local members = self:getGuildMemberList()

            if not self._view:isPickerShown() then
                self._view:showPicker(editBox, members, mentionQuery, function(selectedName, targetEB)
                    self:onMemberSelected(selectedName, targetEB)
                end, function()
                    self._activeEditBox = nil
                end)
            else
                self._view:filterList(mentionQuery)
            end
            return
        end
    end

    -- Se apagou o '@' ou não é uma query válida de menção, fecha o popup imediatamente
    if self._view and self._view:isPickerShown() then
        self._view:hidePicker(true)
    end
end

--- Trata a perda de foco do EditBox do chat com proteção para o popup.
---@param editBox table
function ChatMentionController:onChatFocusLost(editBox)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            if self._view and self._view:isPickerShown() then
                -- Se o foco foi para o campo de busca do popup, mantém aberto
                if self._view._searchEB and self._view._searchEB:HasFocus() then
                    return
                end
                if not editBox:HasFocus() then
                    self._view:hidePicker(true)
                end
            end
        end)
    end
end

--- Executado quando um membro é selecionado na lista de autocompletar.
---@param memberName string
---@param targetEB table|nil
function ChatMentionController:onMemberSelected(memberName, targetEB)
    self._completedMentions = self._completedMentions or {}
    self._completedMentions[memberName:lower()] = true
    local first = memberName:match("^(%S+)")
    if first then
        self._completedMentions[first:lower()] = true
    end
    self._justCompletedMember = memberName
    self._isInsertingMention = true

    -- Fecha imediatamente a janela de menção
    if self._view then
        self._view:hidePicker(true)
    end

    local editBox = targetEB or self._activeEditBox or (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()) or ChatFrame1EditBox
    if not editBox then
        self._isInsertingMention = false
        return
    end

    local text = editBox:GetText() or ""
    local cursorPos = editBox:GetCursorPosition() or #text
    local textAfterCursor = text:sub(cursorPos + 1)
    local preText = self._mentionPreText or ""

    local inserted = "@" .. memberName .. " "
    local newText = preText .. inserted .. textAfterCursor

    editBox:SetText(newText)
    local newCursor = #preText + #inserted
    editBox:SetCursorPosition(newCursor)
    editBox:SetFocus()

    -- Mantém a flag ativa por um breve momento para evitar que o OnTextChanged gerado pelo SetText reabra a janela
    if C_Timer and C_Timer.After then
        C_Timer.After(0.3, function()
            self._isInsertingMention = false
            if self._view and self._view:isPickerShown() then
                self._view:hidePicker(true)
            end
        end)
    else
        self._isInsertingMention = false
    end
end

--- Retorna a lista atualizada de membros da guilda para o autocompletar e cache.
---@return table
function ChatMentionController:getGuildMemberList()
    local list = {}
    local seenNames = {}

    -- 1. Varre o roster ativo da API da Blizzard
    if GetNumGuildMembers and GetGuildRosterInfo then
        local num = GetNumGuildMembers() or 0
        for i = 1, num do
            local name, rankName, _, level, _, _, _, _, isOnline, _, classFileName = GetGuildRosterInfo(i)
            if name then
                local clean = name:match("^[^-]+") or name
                clean = clean:match("^%s*(.-)%s*$") or clean
                local cleanLower = clean:lower()

                if not seenNames[cleanLower] then
                    seenNames[cleanLower] = true

                    local colorCode = getClassColorCode(classFileName)
                    local coloredName = colorCode .. clean .. "|r"

                    table.insert(list, {
                        name = clean,
                        firstName = clean:match("^(%S+)") or clean,
                        coloredName = coloredName,
                        colorCode = colorCode,
                        rank = rankName or "",
                        level = level or 0,
                        isOnline = (isOnline == 1 or isOnline == true),
                        class = classFileName or "",
                    })
                end
            end
        end
    end

    -- 2. Complementa com membros do banco local se não estiverem no roster imediato
    if self._memberService and self._memberService.getAllMembers then
        local all = self._memberService:getAllMembers()
        for _, m in ipairs(all or {}) do
            if m:isInGuild() then
                local mName = m:getName()
                if mName and mName ~= "" then
                    local clean = mName:match("^[^-]+") or mName
                    clean = clean:match("^%s*(.-)%s*$") or clean
                    local cleanLower = clean:lower()

                    if not seenNames[cleanLower] then
                        seenNames[cleanLower] = true
                        local mClass = m:getClass() or ""
                        local colorCode = getClassColorCode(mClass)
                        local coloredName = colorCode .. clean .. "|r"

                        table.insert(list, {
                            name = clean,
                            firstName = clean:match("^(%S+)") or clean,
                            coloredName = coloredName,
                            colorCode = colorCode,
                            rank = m:getRankName() or "",
                            level = m:getLevel() or 0,
                            isOnline = m:isOnline() or false,
                            class = mClass,
                        })
                    end
                end
            end
        end
    end

    return list
end

--- Reconstrói o cache de consulta rápida indexado por nome completo e primeiro nome.
function ChatMentionController:rebuildMemberCache()
    self._memberCache = {}
    self._memberCacheTime = GetTime and GetTime() or 0

    local list = self:getGuildMemberList()
    for _, item in ipairs(list) do
        local fullName = item.name or ""
        local fullNameLower = fullName:lower()
        local firstName = item.firstName or fullName:match("^(%S+)") or fullName
        local firstNameLower = firstName:lower()

        local info = {
            name = fullName,
            firstName = firstName,
            class = item.class,
            colorCode = item.colorCode or getClassColorCode(item.class),
        }

        self._memberCache[fullNameLower] = info
        if not self._memberCache[firstNameLower] then
            self._memberCache[firstNameLower] = info
        end
    end
end

--- Busca as informações de um membro (incluindo cor da classe) por nome completo ou primeiro nome.
--- Se 'name' contiver espaços (ex: multi-palavras), busca ESTRITAMENTE o nome completo correspondente.
---@param name string
---@return table|nil
function ChatMentionController:findMemberInfo(name)
    if not name or name == "" then
        return nil
    end

    local clean = name:match("^[^-]+") or name
    clean = clean:match("^%s*(.-)%s*$") or clean
    local cleanLower = clean:lower()
    local hasSpaces = clean:find("%s") ~= nil

    -- 1. Verifica cache rápido
    local now = GetTime and GetTime() or 0
    if not self._memberCache or not self._memberCacheTime or (now - self._memberCacheTime > 5) then
        self:rebuildMemberCache()
    end

    if self._memberCache then
        if self._memberCache[cleanLower] then
            return self._memberCache[cleanLower]
        end
        -- Fallback por primeiro nome APENAS se a busca NÃO contiver espaços
        if not hasSpaces then
            local firstLower = clean:match("^(%S+)") and clean:match("^(%S+)"):lower() or cleanLower
            if self._memberCache[firstLower] then
                return self._memberCache[firstLower]
            end
        end
    end

    -- 2. Tenta buscar no MemberService
    if self._memberService then
        local m = nil
        if self._memberService.getMember then
            m = self._memberService:getMember(clean)
            if not m and not hasSpaces then
                local firstLower = clean:match("^(%S+)") and clean:match("^(%S+)"):lower() or cleanLower
                if firstLower ~= cleanLower then
                    m = self._memberService:getMember(firstLower)
                end
            end
        end

        if m then
            local classToken = m:getClass()
            return {
                name = m:getName(),
                firstName = m:getName():match("^(%S+)") or m:getName(),
                class = classToken,
                colorCode = getClassColorCode(classToken),
            }
        end
    end

    -- 3. Tenta varrer diretamente a API da Blizzard
    if GetNumGuildMembers and GetGuildRosterInfo then
        local num = GetNumGuildMembers() or 0
        local firstLower = not hasSpaces and (clean:match("^(%S+)") and clean:match("^(%S+)"):lower() or cleanLower) or nil

        for i = 1, num do
            local gName, _, _, _, _, _, _, _, _, _, classFileName = GetGuildRosterInfo(i)
            if gName then
                local gClean = gName:match("^[^-]+") or gName
                gClean = gClean:match("^%s*(.-)%s*$") or gClean
                local gLower = gClean:lower()

                if gLower == cleanLower then
                    return {
                        name = gClean,
                        firstName = gClean:match("^(%S+)") or gClean,
                        class = classFileName,
                        colorCode = getClassColorCode(classFileName),
                    }
                elseif not hasSpaces and firstLower then
                    local gFirst = gClean:match("^(%S+)") and gClean:match("^(%S+)"):lower() or gLower
                    if gFirst == firstLower or gLower == firstLower then
                        return {
                            name = gClean,
                            firstName = gClean:match("^(%S+)") or gClean,
                            class = classFileName,
                            colorCode = getClassColorCode(classFileName),
                        }
                    end
                end
            end
        end
    end

    return nil
end

--- Verifica se o nome mencionado corresponde ao jogador logado ou a algum de seus alts/main.
---@param targetName string
---@return boolean
function ChatMentionController:isCurrentPlayerOrAlt(targetName)
    if not targetName or targetName == "" then
        return false
    end

    local myName = UnitName("player")
    if not myName or myName == "" then
        return false
    end

    local cleanTarget = targetName:match("^[^-]+"):lower():match("^%s*(.-)%s*$")
    local cleanMyName = myName:match("^[^-]+"):lower():match("^%s*(.-)%s*$")

    local targetFirst = cleanTarget:match("^(%S+)") or cleanTarget
    local myFirst = cleanMyName:match("^(%S+)") or cleanMyName

    -- 1. Comparação direta (nome completo ou primeiro nome)
    if cleanTarget == cleanMyName or targetFirst == myFirst or cleanTarget == myFirst or targetFirst == cleanMyName then
        return true
    end

    -- 2. Tenta resolver nome completo do jogador local
    local myFullName = cleanMyName
    if self._memberService and self._memberService.resolveRecruiterFullName then
        local resolved = self._memberService:resolveRecruiterFullName(myName)
        if resolved and resolved ~= "" then
            myFullName = resolved:match("^[^-]+"):lower():match("^%s*(.-)%s*$")
            if cleanTarget == myFullName or targetFirst == myFullName then
                return true
            end
        end
    end

    -- 3. Verifica na família de alts/main do MemberService
    if self._memberService and self._memberService.getMember and self._memberService.getAltFamily then
        local myMember = self._memberService:getMember(myName) or (myFullName ~= cleanMyName and self._memberService:getMember(myFullName))
        if myMember then
            local family = self._memberService:getAltFamily(myMember)
            for _, fMember in ipairs(family or {}) do
                local fName = fMember:getName()
                if fName and fName ~= "" then
                    local fClean = fName:match("^[^-]+"):lower():match("^%s*(.-)%s*$")
                    local fFirst = fClean:match("^(%S+)") or fClean
                    if cleanTarget == fClean or targetFirst == fClean or cleanTarget == fFirst or targetFirst == fFirst then
                        return true
                    end
                end
            end
        end
    end

    return false
end

--- Processa e filtra mensagens de CHAT_MSG_GUILD para destacar menções e piscar o chat.
---@param chatFrame table
---@param event string
---@param msg string
---@param author string
---@return boolean, string, string, ...
function ChatMentionController:onGuildChatMessage(chatFrame, event, msg, author, ...)
    if not msg or not msg:find("@", 1, true) then
        return false, msg, author, ...
    end

    local result = ""
    local index = 1
    local len = #msg
    local mentionsFound = false
    local isPlayerMentioned = false

    while index <= len do
        local atPos = msg:find("@", index, true)
        if not atPos then
            result = result .. msg:sub(index)
            break
        end

        -- Verifica se o '@' inicia uma palavra (início da mensagem ou precedido de espaço/pontuação)
        local isWordStart = (atPos == 1) or msg:sub(atPos - 1, atPos - 1):match("[%s%(%[%{<\"'`]")
        if not isWordStart then
            result = result .. msg:sub(index, atPos)
            index = atPos + 1
        else
            result = result .. msg:sub(index, atPos - 1)
            local remaining = msg:sub(atPos + 1)
            local matchedMember = nil
            local matchLength = 0
            local matchedDisplayName = nil

            -- 1. Tenta correspondência com 3 palavras (ex: Nome Sobrenome Terceiro)
            local w1, s1, w2, s2, w3 = remaining:match("^([%w\128-\255_]+)(%s+)([%w\128-\255_]+)(%s+)([%w\128-\255_]+)")
            if w1 and w2 and w3 then
                local three = w1 .. " " .. w2 .. " " .. w3
                local m = self:findMemberInfo(three)
                if m then
                    matchedMember = m
                    matchLength = #w1 + #s1 + #w2 + #s2 + #w3
                    matchedDisplayName = m.name or three
                end
            end

            -- 2. Tenta correspondência com 2 palavras (ex: Thalendris Lunavéu, Aslan Macedo)
            if not matchedMember then
                local w1, s1, w2 = remaining:match("^([%w\128-\255_]+)(%s+)([%w\128-\255_]+)")
                if w1 and w2 then
                    local two = w1 .. " " .. w2
                    local m = self:findMemberInfo(two)
                    if m then
                        matchedMember = m
                        matchLength = #w1 + #s1 + #w2
                        matchedDisplayName = m.name or two
                    end
                end
            end

            -- 3. Tenta correspondência com 1 palavra (primeiro nome ou nome único)
            if not matchedMember then
                local w1 = remaining:match("^([%w\128-\255_]+)")
                if w1 then
                    local m = self:findMemberInfo(w1)
                    if m then
                        matchedMember = m
                        matchLength = #w1
                        matchedDisplayName = m.name or w1
                    end
                end
            end

            if matchedMember then
                mentionsFound = true
                if self:isCurrentPlayerOrAlt(matchedMember.name) or self:isCurrentPlayerOrAlt(matchedMember.firstName) then
                    isPlayerMentioned = true
                end

                -- @ na cor do chat da guilda, nome e sobrenome na cor da classe (sem colchetes)
                local guildColor = getGuildChatColorCode()
                local colorCode = matchedMember.colorCode or "|cffffd200"
                local nameStr = matchedDisplayName or matchedMember.name
                result = result .. guildColor .. "@|r" .. colorCode .. nameStr .. "|r" .. guildColor
                index = atPos + 1 + matchLength
            else
                -- Menção a nome desconhecido (@ na cor da guilda, texto amarelo, sem colchetes)
                local w1 = remaining:match("^([%w\128-\255_]+)")
                if w1 then
                    mentionsFound = true
                    if self:isCurrentPlayerOrAlt(w1) then
                        isPlayerMentioned = true
                    end
                    local guildColor = getGuildChatColorCode()
                    result = result .. guildColor .. "@|r|cffffd200" .. w1 .. "|r" .. guildColor
                    index = atPos + 1 + #w1
                else
                    result = result .. "@"
                    index = atPos + 1
                end
            end
        end
    end

    if not mentionsFound then
        return false, msg, author, ...
    end

    -- Se o jogador logado foi mencionado, ativa o efeito de piscar o chat e o som
    if isPlayerMentioned then
        if self._view and self._view.flashChatFrame then
            self._view:flashChatFrame(chatFrame)
        end
    end

    -- Retorna a mensagem com o @Nome Sobrenome formatado na cor da classe (sem nenhuma tag [MENÇÃO])
    return false, result, author, ...
end
