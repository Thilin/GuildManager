---@class ProfessionService
--- Serviço central para gerenciamento, escaneamento local e pedidos das 6 profissões de fabricação.
---@field private _professionRepository ProfessionRepository
---@field private _craftOrderRepository CraftOrderRepository
---@field private _memberService MemberService
---@field private _guildRosterService GuildRosterService|nil
---@field private _syncService SyncService|nil
---@field private _listeners table<function>
local function cleanPlayerName(name)
    if not name or name == "" then return "" end
    local clean = name:match("^[^-]+") or name
    return clean:match("^%s*(.-)%s*$") or clean
end

ProfessionService = {}
ProfessionService.__index = ProfessionService

---@param professionRepository ProfessionRepository
---@param craftOrderRepository CraftOrderRepository
---@param memberService MemberService
---@param guildRosterService GuildRosterService|nil
---@param syncService SyncService|nil
---@return ProfessionService
function ProfessionService:new(professionRepository, craftOrderRepository, memberService, guildRosterService, syncService)
    local instance = setmetatable({}, self)

    instance._professionRepository = professionRepository
    instance._craftOrderRepository = craftOrderRepository
    instance._memberService = memberService
    instance._guildRosterService = guildRosterService
    instance._syncService = syncService
    instance._listeners = {}
    instance._eventFrame = nil

    return instance
end

--- Define ou atualiza a referência do SyncService
---@param syncService SyncService
function ProfessionService:setSyncService(syncService)
    self._syncService = syncService
end

--- Registra um listener para atualizações de profissões e pedidos
---@param listener function
function ProfessionService:addListener(listener)
    if type(listener) == "function" then
        table.insert(self._listeners, listener)
    end
end

--- Notifica todos os ouvintes registrados
function ProfessionService:notifyChanged()
    for _, l in ipairs(self._listeners) do
        pcall(l)
    end
end

--- Inicializa os eventos e ganchos da Blizzard para escaneamento automático
function ProfessionService:initHooks()
    if self._eventFrame then return end

    local frame = CreateFrame("Frame")
    self._eventFrame = frame

    local function safeRegister(evt)
        pcall(function() frame:RegisterEvent(evt) end)
    end

    safeRegister("PLAYER_ENTERING_WORLD")
    safeRegister("SKILL_LINES_CHANGED")
    safeRegister("TRADE_SKILL_SHOW")
    safeRegister("TRADE_SKILL_LIST_UPDATE")
    safeRegister("TRADE_SKILL_DATA_SOURCE_CHANGED")
    safeRegister("TRADE_SKILL_CLOSE")
    safeRegister("CRAFT_SHOW")
    safeRegister("CRAFT_UPDATE")
    safeRegister("CRAFT_CLOSE")
    safeRegister("ADDON_LOADED")

    frame:SetScript("OnEvent", function(_, event, arg1, ...)
        if event == "PLAYER_ENTERING_WORLD" or event == "SKILL_LINES_CHANGED" then
            self:scanAll()
        elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
            self:scanTradeSkillFrame()
        elseif event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then
            self:scanCraftFrame()
        elseif event == "ADDON_LOADED" then
            if (arg1 == "Blizzard_TradeSkillUI" or arg1 == "TradeSkillUI") and TradeSkillFrame and TradeSkillFrame.HookScript then
                pcall(function()
                    TradeSkillFrame:HookScript("OnShow", function() self:scanTradeSkillFrame() end)
                end)
            elseif (arg1 == "Blizzard_CraftUI" or arg1 == "CraftUI") and CraftFrame and CraftFrame.HookScript then
                pcall(function()
                    CraftFrame:HookScript("OnShow", function() self:scanCraftFrame() end)
                end)
            end
        end
    end)

    -- Hook adicional no TradeSkillFrame e CraftFrame se já existirem no momento da inicialização
    if TradeSkillFrame and TradeSkillFrame.HookScript then
        pcall(function()
            TradeSkillFrame:HookScript("OnShow", function() self:scanTradeSkillFrame() end)
        end)
    end
    if CraftFrame and CraftFrame.HookScript then
        pcall(function()
            CraftFrame:HookScript("OnShow", function() self:scanCraftFrame() end)
        end)
    end

    -- Escaneamento inicial imediato
    if C_Timer and C_Timer.After then
        C_Timer.After(1.5, function()
            self:scanAll()
        end)
    end
end

--- Normaliza o nome do jogador
---@param name string|nil
---@return string
local function cleanPlayerName(name)
    if not name or name == "" then return "" end
    local clean = name:match("^[^-]+") or name
    return clean:match("^%s*(.-)%s*$") or clean
end

--- Obtém a entidade Member do jogador local
---@return Member|nil
function ProfessionService:getLocalPlayerMember()
    local myGUID = UnitGUID and UnitGUID("player")
    local myFullName = nil

    if self._memberService and self._memberService.resolvePlayerFullName then
        myFullName = self._memberService:resolvePlayerFullName()
    end
    if not myFullName or myFullName == "" or not myFullName:find("%s") then
        if _G.GM and _G.GM.memberController and _G.GM.memberController.resolvePlayerFullName then
            local cFull = _G.GM.memberController:resolvePlayerFullName()
            if cFull and cFull ~= "" and cFull:find("%s") then
                myFullName = cFull
            end
        end
    end
    if not myFullName or myFullName == "" or not myFullName:find("%s") then
        local myBase = cleanPlayerName(UnitName and UnitName("player"))
        if myBase ~= "" and self._memberService and self._memberService.resolveFullName then
            local res = self._memberService:resolveFullName(myBase)
            if res and res ~= "" and res:find("%s") then
                myFullName = res
            end
        end
    end

    local member = nil
    if self._memberService then
        if myGUID and myGUID ~= "" and self._memberService.getMemberByGuid then
            member = self._memberService:getMemberByGuid(myGUID)
        end
        if not member and myFullName and myFullName ~= "" then
            member = self._memberService:getMember(myFullName)
        end
        if not member then
            local myBaseName = cleanPlayerName(UnitName and UnitName("player"))
            if myBaseName ~= "" then
                member = self._memberService:getMember(myBaseName)
            end
        end
    end

    -- Se o membro existe mas seu nome ainda não possui o sobrenome, atualiza para o nome completo!
    if member and myFullName and myFullName ~= "" and myFullName:find("%s") then
        if not member:getName() or not member:getName():find("%s") or member:getName() ~= myFullName then
            member:setName(myFullName)
            if self._memberService then
                self._memberService:saveMember(member, true)
            end
        end
    end

    if not member and self._memberService then
        local myClass = UnitClass and select(2, UnitClass("player"))
        local myLevel = UnitLevel and UnitLevel("player")
        local myRace = UnitRace and UnitRace("player")
        local chosenName = (myFullName and myFullName ~= "") and myFullName or cleanPlayerName(UnitName and UnitName("player"))
        member = Member:new({
            name = chosenName,
            guid = myGUID or "",
            class = myClass or "",
            level = myLevel or 1,
            race = myRace or "",
            isInGuild = true,
            isMain = true,
        })
        self._memberService:saveMember(member, true)
    end

    return member
end

--- Extrai o ID numérico a partir de um link de item ou feitiço
---@param link string|nil
---@return number|nil
local function extractIdFromLink(link)
    if not link or type(link) ~= "string" then return nil end
    local itemId = link:match("item:(%d+)")
    if itemId then return tonumber(itemId) end
    local spellId = link:match("spell:(%d+)")
    if spellId then return tonumber(spellId) end
    local enchantId = link:match("enchant:(%d+)")
    if enchantId then return tonumber(enchantId) end
    return nil
end

--- Escaneia utilizando a API moderna GetProfessions() / GetProfessionInfo() se disponível
---@param member Member
---@return number @Quantidade de profissões detectadas por esta fonte
function ProfessionService:scanFromProfessionsAPI(member)
    local count = 0
    if not member then return 0 end
    if GetProfessions and GetProfessionInfo then
        local profs = { GetProfessions() }
        for i = 1, 2 do
            local idx = profs[i]
            if idx then
                local name, icon, skillLevel, maxSkillLevel = GetProfessionInfo(idx)
                if name and name ~= "" then
                    local pKey = ProfessionData.getProfessionKey(name)
                    if pKey then
                        local existing = member:getProfession(pKey) or {}
                        member:setProfession(pKey, tonumber(skillLevel) or existing.rank or 1, tonumber(maxSkillLevel) or existing.maxRank or 300, existing.recipes or {})
                        count = count + 1
                    end
                end
            end
        end
    end
    if count > 0 and self._memberService then
        self._memberService:saveMember(member, true)
    end
    return count
end

--- Escaneia o Grimório do jogador (Spellbook) em busca de feitiços de profissão primária
--- No WoW Classic, todo personagem que aprende uma profissão ganha o feitiço correspondente no Grimório.
---@param member Member
---@return number @Quantidade de profissões detectadas
function ProfessionService:scanFromSpellBook(member)
    local count = 0
    if not member then return 0 end

    local function checkSpell(spellName, spellSubName)
        if not spellName or spellName == "" then return false end
        local pKey = ProfessionData.getProfessionKey(spellName)
        if pKey then
            local existing = member:getProfession(pKey) or {}
            local curRank = existing.rank or 0
            if curRank == 0 then
                local sub = (spellSubName or ""):lower()
                local estMax = 75
                if sub:find("perito") or sub:find("journeyman") then estMax = 150
                elseif sub:find("especialista") or sub:find("expert") then estMax = 225
                elseif sub:find("artes") or sub:find("artisan") then estMax = 300
                end
                member:setProfession(pKey, 1, estMax, existing.recipes or {})
                count = count + 1
            end
            return true
        end
        return false
    end

    if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
        local numTabs = GetNumSpellTabs()
        for t = 1, numTabs do
            local _, _, offset, numSpells = GetSpellTabInfo(t)
            if offset and numSpells then
                for s = offset + 1, offset + numSpells do
                    local spellName, spellSubName = GetSpellBookItemName(s, BOOKTYPE_SPELL or "spell")
                    checkSpell(spellName, spellSubName)
                end
            end
        end
    elseif GetSpellBookItemName then
        for s = 1, 150 do
            local spellName, spellSubName = GetSpellBookItemName(s, BOOKTYPE_SPELL or "spell")
            if not spellName then break end
            checkSpell(spellName, spellSubName)
        end
    end

    if count > 0 and self._memberService then
        self._memberService:saveMember(member, true)
    end

    return count
end

--- Escaneia as perícias do jogador local via GetSkillLineInfo (Classic / Forever)
--- Detecta quais das 6 profissões primárias o jogador possui e seus níveis atuais
---@param member Member|nil
---@return number @Quantidade de profissões primárias detectadas
function ProfessionService:scanPlayerSkills(member)
    member = member or self:getLocalPlayerMember()
    if not member then return 0 end

    -- Expande todos os cabeçalhos para garantir que as perícias filhas estejam visíveis na listagem
    if ExpandSkillHeader then
        pcall(ExpandSkillHeader, 0)
    end

    local detectedCount = 0

    if GetNumSkillLines and GetSkillLineInfo then
        local numSkills = GetNumSkillLines()
        for i = 1, numSkills do
            local skillName, isHeader, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank = GetSkillLineInfo(i)
            -- No WoW Classic C API, isHeader pode retornar 0 (número) que é truthy em Lua!
            -- Por isso comparamos explicitamente com 1 ou true.
            local isH = (isHeader == 1 or isHeader == true or isHeader == "1")
            if not isH and skillName and skillName ~= "" then
                local profKey = ProfessionData.getProfessionKey(skillName)
                if profKey then
                    local existing = member:getProfession(profKey) or {}
                    local currentRecipes = existing.recipes or {}
                    member:setProfession(profKey, tonumber(skillRank) or existing.rank or 1, tonumber(skillMaxRank) or existing.maxRank or 300, currentRecipes)
                    detectedCount = detectedCount + 1
                end
            end
        end
    end

    if detectedCount > 0 and self._memberService then
        self._memberService:saveMember(member, true)
    end

    return detectedCount
end

--- Escaneia receitas conhecidas pelo jogador com base no grimório e evolução de perícia
---@param member Member|nil
---@return number @Quantidade de receitas registradas
function ProfessionService:scanPlayerKnownRecipes(member)
    member = member or self:getLocalPlayerMember()
    if not member then return 0 end

    local count = 0
    local localName = UnitName and UnitName("player")
    local isLocal = false
    if localName and member.getName then
        local c1 = (member:getName():match("^[^-]+") or member:getName()):lower():gsub("%s+", "")
        local c2 = (localName:match("^[^-]+") or localName):lower():gsub("%s+", "")
        if c1 == c2 then isLocal = true end
    end

    for _, profKey in ipairs(ProfessionData.ORDER) do
        local prof = member:getProfession(profKey)
        if prof and (prof.rank or 0) > 0 then
            local knownRecipes = prof.recipes or {}
            local catRecipes = ProfessionData.getRecipesForProfession(profKey)
            for _, r in ipairs(catRecipes) do
                local learns = false
                -- 1. Verifica se o feitiço é conhecido no grimório do jogador local
                if isLocal and r.id and type(r.id) == "number" then
                    if (IsSpellKnown and IsSpellKnown(r.id)) or (IsPlayerSpell and IsPlayerSpell(r.id)) then
                        learns = true
                    end
                end

                -- 2. Regra canônica de evolução de perícia (receitas de treinador até o rank atual)
                local reqSkill = r.skill or 1
                local isSpecial = (r.source == "drop" or r.source == "reputation" or r.source == "raid")
                if not isSpecial and (prof.rank or 0) >= reqSkill then
                    learns = true
                end

                if learns then
                    knownRecipes[r.id] = true
                    if type(r.id) == "number" then
                        knownRecipes[tostring(r.id)] = true
                    end
                    if r.itemId then
                        knownRecipes[r.itemId] = true
                        knownRecipes[tostring(r.itemId)] = true
                    end
                    count = count + 1
                end
            end

            -- Sanitiza chaves de texto legadas em knownRecipes
            for k in pairs(knownRecipes) do
                if type(k) == "string" and not tonumber(k) then
                    local matched = ProfessionData.getRecipeById(k, profKey)
                    if matched and matched.id then
                        knownRecipes[matched.id] = true
                        knownRecipes[tostring(matched.id)] = true
                    end
                    knownRecipes[k] = nil
                end
            end

            member:setProfession(profKey, prof.rank, prof.maxRank, knownRecipes)
        end
    end

    if count > 0 and self._memberService then
        self._memberService:saveMember(member, true)
    end
    return count
end

--- Escaneia a janela de TradeSkill clássica (Alquimia, Alfaiataria, Couraria, Ferraria, Engenharia)
---@param member Member|nil
---@return number @Quantidade de receitas registradas
function ProfessionService:scanTradeSkillFrame(member)
    member = member or self:getLocalPlayerMember()
    if not member then return 0 end

    local profName = nil
    local currentLevel = nil
    local maxLevel = nil

    -- 1. Tenta C_TradeSkillUI.GetTradeSkillLine() (Modern Classic / Dragonflight namespace)
    if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLine then
        local lineId, dispName, curL, maxL = C_TradeSkillUI.GetTradeSkillLine()
        if dispName and dispName ~= "" and dispName ~= "UNKNOWN" then
            profName = dispName
            currentLevel = tonumber(curL)
            maxLevel = tonumber(maxL)
        end
    end

    -- 2. Tenta global GetTradeSkillLine() clássico
    if not profName and GetTradeSkillLine then
        local a, b, c = GetTradeSkillLine()
        if type(a) == "string" and a ~= "" and a ~= "UNKNOWN" then
            profName = a
            currentLevel = tonumber(b)
            maxLevel = tonumber(c)
        elseif type(b) == "string" and b ~= "" and b ~= "UNKNOWN" then
            profName = b
            currentLevel = tonumber(c)
            maxLevel = tonumber(select(4, GetTradeSkillLine()))
        end
    end

    -- 3. Fallback: Lê o título da janela (TradeSkillFrameTitleText / TitleText) se estiver aberta
    if not profName then
        local title = (TradeSkillFrameTitleText and TradeSkillFrameTitleText.GetText and TradeSkillFrameTitleText:GetText())
            or (TradeSkillFrame and TradeSkillFrame.TitleText and TradeSkillFrame.TitleText.GetText and TradeSkillFrame.TitleText:GetText())
            or (ProfessionsFrame and ProfessionsFrame.TitleText and ProfessionsFrame.TitleText.GetText and ProfessionsFrame.TitleText:GetText())
        if title and title ~= "" then
            profName = title
        end
    end

    -- 4. Fallback para rank/nível: Lê o texto da barra de perícia (ex: "Leatherworking 101/150")
    local rankText = (TradeSkillRankFrameSkillRank and TradeSkillRankFrameSkillRank.GetText and TradeSkillRankFrameSkillRank:GetText())
        or (TradeSkillRankFrame and TradeSkillRankFrame.GetText and TradeSkillRankFrame:GetText())
    if rankText and rankText ~= "" then
        local r, m = rankText:match("(%d+)%s*/%s*(%d+)")
        if r and m then
            if not currentLevel or currentLevel == 0 then currentLevel = tonumber(r) end
            if not maxLevel or maxLevel == 0 then maxLevel = tonumber(m) end
        end
        if not profName or profName == "" then
            local pName = rankText:match("^(.-)%s*%d+%s*/")
            if pName and pName ~= "" then
                profName = pName
            end
        end
    end

    if not profName or profName == "" then
        return 0
    end

    local profKey = ProfessionData.getProfessionKey(profName)
    if not profKey then
        return 0
    end

    -- REGISTRA IMEDIATAMENTE A PROFISSÃO NO MEMBRO
    local existingProf = member:getProfession(profKey) or {}
    local knownRecipes = existingProf.recipes or {}
    member:setProfession(profKey, currentLevel or existingProf.rank or 1, maxLevel or existingProf.maxRank or 150, knownRecipes)

    local learnedCount = 0

    -- 1. Varredura via C_TradeSkillUI (Modern Classic Era / 1.15)
    if C_TradeSkillUI then
        local recipeIDs = nil
        if C_TradeSkillUI.GetAllRecipeIDs then
            local ok, list = pcall(C_TradeSkillUI.GetAllRecipeIDs)
            if ok and type(list) == "table" and #list > 0 then
                recipeIDs = list
            end
        end
        if (not recipeIDs or #recipeIDs == 0) and C_TradeSkillUI.GetFilteredRecipeIDs then
            local ok, list = pcall(C_TradeSkillUI.GetFilteredRecipeIDs)
            if ok and type(list) == "table" and #list > 0 then
                recipeIDs = list
            end
        end

        if recipeIDs and #recipeIDs > 0 then
            for _, rId in ipairs(recipeIDs) do
                local info = nil
                if C_TradeSkillUI.GetRecipeInfo then
                    local ok, rInfo = pcall(C_TradeSkillUI.GetRecipeInfo, rId)
                    if ok and rInfo then info = rInfo end
                end

                local isLearned = true
                if info and info.learned ~= nil then
                    isLearned = (info.learned == true)
                end

                if isLearned then
                    local rName = (info and info.name) or (GetSpellInfo and GetSpellInfo(rId)) or ("Receita " .. tostring(rId))
                    local iconTex = (info and info.icon) or (GetSpellTexture and GetSpellTexture(rId))
                    if not iconTex and C_TradeSkillUI.GetRecipeIcon then
                        local okI, ico = pcall(C_TradeSkillUI.GetRecipeIcon, rId)
                        if okI and ico then iconTex = ico end
                    end
                    local minSkill = (info and (info.skillLevel or info.requiredSkillRank or info.minSkillLineRank)) or currentLevel or 1
                    local categoryName = "Diversos"
                    if info and info.categoryID and C_TradeSkillUI.GetCategoryInfo then
                        local okCat, catInfo = pcall(C_TradeSkillUI.GetCategoryInfo, info.categoryID)
                        if okCat and catInfo and catInfo.name then
                            categoryName = catInfo.name
                        end
                    end

                    -- Busca se já existe no catálogo padrão
                    local foundRecipe = ProfessionData.getRecipeById(rId, profKey)
                    if not foundRecipe then
                        for _, r in ipairs(ProfessionData.getRecipesForProfession(profKey)) do
                            if r.name:lower() == rName:lower() or (r.namePT and r.namePT:lower() == rName:lower()) then
                                foundRecipe = r
                                break
                            end
                        end
                    end

                    local finalId = (foundRecipe and foundRecipe.id) or rId

                    ProfessionData.registerDynamicRecipe(profKey, {
                        id = finalId,
                        name = rName,
                        namePT = rName,
                        prof = profKey,
                        skill = minSkill,
                        category = categoryName,
                        categoryPT = categoryName,
                        quality = (info and info.quality) or 1,
                        icon = iconTex or ProfessionData.PROFESSIONS[profKey].icon,
                        reagents = {},
                    })

                    if not knownRecipes[finalId] then
                        knownRecipes[finalId] = true
                        if type(finalId) == "number" then
                            knownRecipes[tostring(finalId)] = true
                        end
                        if foundRecipe and foundRecipe.id then
                            knownRecipes[foundRecipe.id] = true
                            knownRecipes[tostring(foundRecipe.id)] = true
                        end
                        if foundRecipe and foundRecipe.itemId then
                            knownRecipes[foundRecipe.itemId] = true
                            knownRecipes[tostring(foundRecipe.itemId)] = true
                        end
                        learnedCount = learnedCount + 1
                    end
                end
            end
        end
    end

    -- 2. Varredura via GetNumTradeSkills (Classic Legacy / Vanilla 1.12)
    if GetNumTradeSkills and GetTradeSkillInfo then
        local num = GetNumTradeSkills() or 0
        if num > 0 then
            for i = 1, num do
                local rName, skillType = GetTradeSkillInfo(i)
                if skillType ~= "header" and rName and rName ~= "" then
                    local itemLink = GetTradeSkillItemLink and GetTradeSkillItemLink(i)
                    local recipeLink = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)
                    local extractedId = extractIdFromLink(recipeLink) or extractIdFromLink(itemLink) or rName

                    local iconTex = GetTradeSkillIcon and GetTradeSkillIcon(i)
                    local foundRecipe = nil
                    if type(extractedId) == "number" then
                        foundRecipe = ProfessionData.getRecipeById(extractedId, profKey)
                    end
                    if not foundRecipe then
                        for _, r in ipairs(ProfessionData.getRecipesForProfession(profKey)) do
                            if r.name:lower() == rName:lower() or (r.namePT and r.namePT:lower() == rName:lower()) then
                                foundRecipe = r
                                break
                            end
                        end
                    end

                    local finalId = (foundRecipe and foundRecipe.id) or extractedId
                    if type(finalId) == "number" then
                        ProfessionData.registerDynamicRecipe(profKey, {
                            id = finalId,
                            name = rName,
                            namePT = rName,
                            prof = profKey,
                            skill = currentLevel or 1,
                            category = "Geral",
                            categoryPT = "Geral",
                            quality = 1,
                            icon = iconTex or ProfessionData.PROFESSIONS[profKey].icon,
                            reagents = {},
                        })
                    end

                    if not knownRecipes[finalId] then
                        knownRecipes[finalId] = true
                        if type(finalId) == "number" then
                            knownRecipes[tostring(finalId)] = true
                        end
                        if foundRecipe and foundRecipe.id then
                            knownRecipes[foundRecipe.id] = true
                            knownRecipes[tostring(foundRecipe.id)] = true
                        end
                        if foundRecipe and foundRecipe.itemId then
                            knownRecipes[foundRecipe.itemId] = true
                            knownRecipes[tostring(foundRecipe.itemId)] = true
                        end
                        learnedCount = learnedCount + 1
                    end
                end
            end
        end
    end

    -- 3. Fallback: Leitura direta dos botões visíveis na interface do TradeSkillFrame
    for i = 1, 50 do
        local btn = _G["TradeSkillSkill" .. i]
        if btn and btn.IsShown and btn:IsShown() then
            local bText = (btn.GetText and btn:GetText())
                or (btn.Text and btn.Text.GetText and btn.Text:GetText())
                or (_G["TradeSkillSkill" .. i .. "Text"] and _G["TradeSkillSkill" .. i .. "Text"].GetText and _G["TradeSkillSkill" .. i .. "Text"]:GetText())
            if bText and bText ~= "" then
                local cleanName = bText:match("^[+-]?%s*(.-)%s*%[?%d*%]?$") or bText
                cleanName = cleanName:match("^%s*(.-)%s*$")
                -- Ignora cabeçalhos comuns de categorias
                local isCategory = cleanName == "Camping" or cleanName == "Reagents" or cleanName == "Cloaks"
                    or cleanName == "Leather Chestguards" or cleanName == "Leather Bracers" or cleanName == "Leather Gauntlets"
                    or cleanName == "Leather Belts" or cleanName == "Leather Legguards" or cleanName == "Leather Boots"
                    or cleanName == "Armor Kits" or cleanName == "Quivers" or cleanName == "Ammo Pouches"
                if cleanName ~= "" and not isCategory then
                    local foundRecipe = nil
                    for _, r in ipairs(ProfessionData.getRecipesForProfession(profKey)) do
                        if r.name:lower() == cleanName:lower() or (r.namePT and r.namePT:lower() == cleanName:lower()) then
                            foundRecipe = r
                            break
                        end
                    end

                    local finalId = (foundRecipe and foundRecipe.id) or cleanName
                    ProfessionData.registerDynamicRecipe(profKey, {
                        id = finalId,
                        name = cleanName,
                        namePT = cleanName,
                        prof = profKey,
                        skill = currentLevel or 1,
                        category = "Geral",
                        categoryPT = "Geral",
                        quality = 1,
                        icon = ProfessionData.PROFESSIONS[profKey].icon,
                        reagents = {},
                    })

                    if not knownRecipes[finalId] then
                        knownRecipes[finalId] = true
                        knownRecipes[cleanName] = true
                        learnedCount = learnedCount + 1
                    end
                end
            end
        end
    end

    -- 4. Verificação cruzada com o catálogo de receitas de nível compatível via IsSpellKnown
    if IsSpellKnown or IsPlayerSpell then
        for _, r in ipairs(ProfessionData.getRecipesForProfession(profKey)) do
            if r.id and type(r.id) == "number" and (r.skill or 0) <= (currentLevel or 300) then
                local known = (IsSpellKnown and IsSpellKnown(r.id)) or (IsPlayerSpell and IsPlayerSpell(r.id))
                if not known and C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
                    local ok, rInfo = pcall(C_TradeSkillUI.GetRecipeInfo, r.id)
                    if ok and rInfo and rInfo.learned == true then
                        known = true
                    end
                end
                if known and not knownRecipes[r.id] then
                    knownRecipes[r.id] = true
                    knownRecipes[tostring(r.id)] = true
                    learnedCount = learnedCount + 1
                end
            end
        end
    end

    -- Sanitiza chaves de texto legadas em knownRecipes
    for k in pairs(knownRecipes) do
        if type(k) == "string" and not tonumber(k) then
            local matched = ProfessionData.getRecipeById(k, profKey)
            if matched and matched.id then
                knownRecipes[matched.id] = true
                knownRecipes[tostring(matched.id)] = true
            end
            knownRecipes[k] = nil
        end
    end

    -- Atualiza e salva com todas as receitas conhecidas
    member:setProfession(profKey, currentLevel or existingProf.rank or 1, maxLevel or existingProf.maxRank or 150, knownRecipes)
    if self._memberService then
        self._memberService:saveMember(member, true)
    end

    self:notifyChanged()

    local sync = self._syncService or (_G.GM and _G.GM.syncService)
    if sync then
        if sync.broadcastMemberProfessions then
            sync:broadcastMemberProfessions(member, profKey)
        elseif sync.broadcastPlayerProfessions then
            sync:broadcastPlayerProfessions(member, profKey)
        end
    end

    return learnedCount
end

--- Escaneia a janela de Craft clássica (Encantamento no Classic Vanilla)
---@param member Member|nil
---@return number @Quantidade de receitas de encantamento registradas
function ProfessionService:scanCraftFrame(member)
    member = member or self:getLocalPlayerMember()
    if not member then return 0 end

    if not GetCraftDisplaySkillLine or not GetNumCrafts or not GetCraftInfo then
        return 0
    end

    local craftSkillName, craftRank, craftMaxRank = GetCraftDisplaySkillLine()
    if not craftSkillName or craftSkillName == "" then return 0 end

    local profKey = ProfessionData.getProfessionKey(craftSkillName)
    if not profKey or profKey ~= "ENCHANTING" then
        return 0
    end

    local existingProf = member:getProfession("ENCHANTING") or {}
    local knownRecipes = existingProf.recipes or {}
    member:setProfession("ENCHANTING", tonumber(craftRank) or existingProf.rank or 1, tonumber(craftMaxRank) or existingProf.maxRank or 300, knownRecipes)

    local learnedCount = 0
    local numCrafts = GetNumCrafts() or 0

    for i = 1, numCrafts do
        local craftName, craftSubSpellName, craftType = GetCraftInfo(i)
        if craftType ~= "header" and craftName and craftName ~= "" then
            local craftLink = GetCraftItemLink and GetCraftItemLink(i)
            local extractedId = extractIdFromLink(craftLink)

            local foundRecipe = nil
            if extractedId then
                foundRecipe = ProfessionData.getRecipeById(extractedId, "ENCHANTING")
            end
            if not foundRecipe then
                for _, r in ipairs(ProfessionData.getRecipesForProfession("ENCHANTING")) do
                    if r.name:lower() == craftName:lower() or (r.namePT and r.namePT:lower() == craftName:lower()) then
                        foundRecipe = r
                        break
                    end
                end
            end

            local finalRecipeId = (foundRecipe and foundRecipe.id) or extractedId or craftName

            if not foundRecipe then
                local iconTex = GetCraftIcon and GetCraftIcon(i)
                ProfessionData.registerDynamicRecipe("ENCHANTING", {
                    id = finalRecipeId,
                    name = craftName,
                    namePT = craftName,
                    prof = "ENCHANTING",
                    skill = craftRank or 1,
                    category = "Enchant",
                    categoryPT = "Encantamentos",
                    quality = 2,
                    icon = iconTex or "Interface\\Icons\\Trade_Engraving",
                    reagents = {},
                })
            end

            knownRecipes[finalRecipeId] = true
            if type(finalRecipeId) == "number" then
                knownRecipes[tostring(finalRecipeId)] = true
            end
            if foundRecipe and foundRecipe.id then
                knownRecipes[foundRecipe.id] = true
                knownRecipes[tostring(foundRecipe.id)] = true
            end
            if foundRecipe and foundRecipe.itemId then
                knownRecipes[foundRecipe.itemId] = true
                knownRecipes[tostring(foundRecipe.itemId)] = true
            end
            learnedCount = learnedCount + 1
        end
    end

    -- Sanitiza chaves de texto legadas em knownRecipes
    for k in pairs(knownRecipes) do
        if type(k) == "string" and not tonumber(k) then
            local matched = ProfessionData.getRecipeById(k, "ENCHANTING")
            if matched and matched.id then
                knownRecipes[matched.id] = true
                knownRecipes[tostring(matched.id)] = true
            end
            knownRecipes[k] = nil
        end
    end

    member:setProfession("ENCHANTING", tonumber(craftRank) or existingProf.rank or 1, tonumber(craftMaxRank) or existingProf.maxRank or 300, knownRecipes)
    if self._memberService then
        self._memberService:saveMember(member, true)
    end

    self:notifyChanged()

    local sync = self._syncService or (_G.GM and _G.GM.syncService)
    if sync then
        if sync.broadcastMemberProfessions then
            sync:broadcastMemberProfessions(member, "ENCHANTING")
        elseif sync.broadcastPlayerProfessions then
            sync:broadcastPlayerProfessions(member, "ENCHANTING")
        end
    end

    return learnedCount
end

--- Executa um escaneamento completo de todas as fontes disponíveis
--- (GetProfessions, GetSkillLineInfo, Spellbook, TradeSkillFrame e CraftFrame)
---@return number @Total de profissões primárias registradas para o jogador
function ProfessionService:scanAll()
    local member = self:getLocalPlayerMember()
    if not member then return 0 end

    -- 1. Scan por GetProfessions() moderna
    self:scanFromProfessionsAPI(member)

    -- 2. Scan por GetSkillLineInfo() clássica (Perícias - K)
    self:scanPlayerSkills(member)

    -- 3. Scan pelo Grimório / Spellbook
    self:scanFromSpellBook(member)

    -- 4. Scan de receitas conhecidas / treinador do jogador local
    self:scanPlayerKnownRecipes(member)

    -- 5. Scan pela janela de TradeSkill ativa
    self:scanTradeSkillFrame(member)

    -- 6. Scan pela janela de Craft (Encantamento) ativa
    self:scanCraftFrame(member)

    -- Salva o membro no banco
    if self._memberService then
        self._memberService:saveMember(member, true)
    end
    self:notifyChanged()

    if sync then
        if sync.broadcastMemberProfessions then
            sync:broadcastMemberProfessions(member)
        elseif sync.broadcastPlayerProfessions then
            sync:broadcastPlayerProfessions(member)
        end
    end

    local count = 0
    for _, pKey in ipairs(ProfessionData.ORDER) do
        local p = member:getProfession(pKey)
        if p and (p.rank or 0) > 0 then
            count = count + 1
        end
    end

    return count
end

-- =========================================================================
-- CONSULTAS E BUSCAS DE ARTESÃOS E RECEITAS
-- =========================================================================

--- Retorna os membros da guilda que possuem a profissão informada
---@param profKey string
---@return table[]
function ProfessionService:getGuildMembersWithProfession(profKey)
    return self._professionRepository:getMembersWithProfession(profKey)
end

--- Retorna os membros da guilda que sabem fabricar a receita especificada
---@param profKey string
---@param recipeId number|string
---@return table[]
function ProfessionService:getCraftersForRecipe(profKey, recipeId)
    return self._professionRepository:getCraftersForRecipe(profKey, recipeId)
end

--- Retorna a lista de receitas filtrada para exibição na UI
---@param profKey string
---@param filterText string|nil @Termo de busca (nome do item ou receita)
---@param filterCategory string|nil @Categoria (ex: "Potions", "Armor") ou "ALL"
---@param onlyGuildCrafters boolean|nil @Se verdadeiro, exibe apenas receitas conhecidas por membros da guilda
---@return table[]
function ProfessionService:getRecipes(profKey, filterText, filterCategory, onlyGuildCrafters)
    local all = self._professionRepository:getAllRecipes(profKey)
    local result = {}

    local cleanSearch = filterText and filterText:lower():match("^%s*(.-)%s*$") or ""

    for _, recipe in ipairs(all) do
        local matchesSearch = true
        if cleanSearch ~= "" then
            local nameEn = (recipe.name or ""):lower()
            local namePt = (recipe.namePT or ""):lower()
            if not nameEn:find(cleanSearch, 1, true) and not namePt:find(cleanSearch, 1, true) then
                matchesSearch = false
            end
        end

        local matchesCat = true
        if filterCategory and filterCategory ~= "" and filterCategory ~= "ALL" and filterCategory ~= "TODAS" then
            local cat = (recipe.category or ""):upper()
            local catPt = (recipe.categoryPT or ""):upper()
            local targetCat = filterCategory:upper()
            if cat ~= targetCat and catPt ~= targetCat then
                matchesCat = false
            end
        end

        local matchesCrafters = true
        local crafterCount = self._professionRepository:countCraftersForRecipe(profKey, recipe.id)
        if onlyGuildCrafters and crafterCount <= 0 then
            matchesCrafters = false
        end

        if matchesSearch and matchesCat and matchesCrafters then
            table.insert(result, {
                recipe = recipe,
                crafterCount = crafterCount,
            })
        end
    end

    return result
end

-- =========================================================================
-- GERENCIAMENTO DE PEDIDOS DE PROFISSÃO (CRAFTING ORDERS)
-- =========================================================================

--- Cria um novo pedido de fabricação e sincroniza com a guilda
---@param data table
---@return CraftOrder|nil
function ProfessionService:createOrder(data)
    if not data or not data.recipeName or data.recipeName == "" then return nil end

    local myName = cleanPlayerName(UnitName and UnitName("player"))
    if self._memberService and self._memberService.resolvePlayerFullName then
        local full = self._memberService:resolvePlayerFullName()
        if full and full ~= "" then myName = full end
    end
    data.requester = data.requester or myName

    -- Se o artesão direcionado foi informado, resolve para o nome canônico (nome e sobrenome) se disponível
    if data.crafter and data.crafter ~= "" and self._memberService and self._memberService.resolveFullName then
        local resolved = self._memberService:resolveFullName(data.crafter)
        if resolved and resolved ~= "" then
            data.crafter = resolved
        end
    end

    local order = CraftOrder:new(data)
    local saved = self._craftOrderRepository:save(order)
    if not saved then return nil end

    self:notifyChanged()

    -- Transmite o novo pedido via SyncService
    if self._syncService and self._syncService.broadcastCraftOrder then
        self._syncService:broadcastCraftOrder(order, "CREATE")
    end

    local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
    print(string.format("|cff00ff00[GuildManager]|r %s: |cffffff00%s|r", L["ORDER_CREATED_SUCCESS"] or "Pedido criado com sucesso", order:getRecipeName()))

    return order
end

--- Aceita um pedido de fabricação (assume a ordem como artesão)
---@param orderId string
---@param crafterName string|nil
---@return boolean
function ProfessionService:acceptOrder(orderId, crafterName)
    local order = self._craftOrderRepository:findById(orderId)
    if not order then return false end

    if not crafterName or crafterName == "" then
        if self._memberService and self._memberService.resolvePlayerFullName then
            local full = self._memberService:resolvePlayerFullName()
            if full and full ~= "" then crafterName = full end
        end
        if not crafterName or crafterName == "" then
            crafterName = cleanPlayerName(UnitName and UnitName("player"))
        end
    end
    order:setAcceptedBy(crafterName)
    order:setStatus(CraftOrder.STATUS.IN_PROGRESS)

    self._craftOrderRepository:save(order)
    self:notifyChanged()

    if self._syncService and self._syncService.broadcastCraftOrder then
        self._syncService:broadcastCraftOrder(order, "UPDATE")
    end

    local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
    print(string.format("|cff00ff00[GuildManager]|r %s |cffffff00%s|r!", L["ORDER_ACCEPTED_SUCCESS"] or "Você aceitou o pedido de", order:getRecipeName()))

    return true
end

--- Conclui um pedido de fabricação
---@param orderId string
---@return boolean
function ProfessionService:completeOrder(orderId)
    local order = self._craftOrderRepository:findById(orderId)
    if not order then return false end

    order:setStatus(CraftOrder.STATUS.COMPLETED)
    self._craftOrderRepository:save(order)
    self:notifyChanged()

    if self._syncService and self._syncService.broadcastCraftOrder then
        self._syncService:broadcastCraftOrder(order, "UPDATE")
    end

    local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
    print(string.format("|cff00ff00[GuildManager]|r %s: |cffffff00%s|r!", L["ORDER_COMPLETED_SUCCESS"] or "Pedido concluído", order:getRecipeName()))

    return true
end

--- Cancela um pedido de fabricação e remove da lista de pedidos da guilda
---@param orderId string
---@return boolean
function ProfessionService:cancelOrder(orderId)
    local order = self._craftOrderRepository:findById(orderId)
    if not order then return false end

    -- Transmite cancelamento para a guilda via SyncService antes de deletar localmente
    if self._syncService and self._syncService.broadcastCraftOrder then
        order:setStatus(CraftOrder.STATUS.CANCELLED)
        self._syncService:broadcastCraftOrder(order, "DELETE")
    end

    -- Remove o pedido do repositório/banco persistente
    self._craftOrderRepository:delete(orderId)
    self:notifyChanged()

    local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
    print(string.format("|cffff4444[GuildManager]|r %s: |cffffff00%s|r", L["ORDER_CANCELLED_SUCCESS"] or "Pedido cancelado", order:getRecipeName()))

    return true
end

--- Recusa um pedido de fabricação direcionado e libera para qualquer artesão da guilda
---@param orderId string
---@return boolean
function ProfessionService:declineOrder(orderId)
    local order = self._craftOrderRepository:findById(orderId)
    if not order then return false end

    -- Se o pedido era direcionado a um artesão específico, libera para qualquer artesão da guilda
    if order:getCrafter() ~= "" then
        order:setCrafter("")
        self._craftOrderRepository:save(order)
        if self._syncService and self._syncService.broadcastCraftOrder then
            self._syncService:broadcastCraftOrder(order, "UPDATE")
        end
        self:notifyChanged()
        local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
        print(string.format("|cffff9900[GuildManager]|r %s: |cffffff00%s|r", L["ORDER_DECLINED_SUCCESS"] or "Pedido recusado e liberado para a guilda", order:getRecipeName()))
        return true
    else
        return self:cancelOrder(orderId)
    end
end

--- Retorna todos os pedidos de fabricação
---@return CraftOrder[]
function ProfessionService:getAllOrders()
    return self._craftOrderRepository:findAll()
end

--- Retorna um pedido específico
---@param orderId string
---@return CraftOrder|nil
function ProfessionService:getOrder(orderId)
    return self._craftOrderRepository:findById(orderId)
end
