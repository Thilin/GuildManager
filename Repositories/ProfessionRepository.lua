---@class ProfessionRepository
--- Repositório para consulta e indexação de artesãos e profissões dos membros da guilda.
---@field private _memberRepository MemberRepository
ProfessionRepository = {}
ProfessionRepository.__index = ProfessionRepository

---@param memberServiceOrRepo MemberService|MemberRepository
---@param craftOrderRepository CraftOrderRepository|nil
---@return ProfessionRepository
function ProfessionRepository:new(memberServiceOrRepo, craftOrderRepository)
    local instance = setmetatable({}, self)
    instance._memberSource = memberServiceOrRepo
    instance._memberRepository = memberServiceOrRepo
    instance._craftOrderRepository = craftOrderRepository
    return instance
end

--- Obtém a lista de membros de forma segura (MemberService:getAllMembers() ou MemberRepository:findAll())
---@private
---@return Member[]
function ProfessionRepository:_getMemberList()
    local src = self._memberSource or self._memberRepository or (_G.GM and (_G.GM.memberService or _G.GM.memberRepository))
    if not src then return {} end
    local list = {}
    if type(src.getAllMembers) == "function" then
        list = src:getAllMembers() or {}
    elseif type(src.findAll) == "function" then
        list = src:findAll() or {}
    end

    -- Deduplica membros pelo GUID ou primeiro nome, priorizando a versão que tem Nome e Sobrenome (espaço)
    local byKey = {}
    local deduped = {}

    for _, m in ipairs(list) do
        if m and m.getName then
            local name = m:getName() or ""
            local guid = m.getGuid and m:getGuid() or ""
            local hasSpace = (name:find("%s") ~= nil)
            local first = (name:match("^(%S+)") or name):lower()

            local key = (guid ~= "") and ("G_" .. guid) or ("N_" .. first)
            if not byKey[key] then
                byKey[key] = m
                table.insert(deduped, m)
            else
                local existing = byKey[key]
                local exName = existing:getName() or ""
                if not exName:find("%s") and hasSpace then
                    for idx, item in ipairs(deduped) do
                        if item == existing then
                            deduped[idx] = m
                            break
                        end
                    end
                    byKey[key] = m
                end
            end
        end
    end

    return deduped
end

--- Resolve o nome completo (nome e sobrenome) do membro caso ainda não possua espaço
---@private
---@param member Member
---@return string
function ProfessionRepository:_resolveMemberName(member)
    if not member or not member.getName then return "" end
    local name = member:getName() or ""
    if name:find("%s") then return name end

    local myGUID = UnitGUID and UnitGUID("player")
    local myName = UnitName and UnitName("player")
    local isLocalPlayer = false
    if (myGUID and member.getGuid and member:getGuid() == myGUID) or (myName and name:lower() == myName:lower()) then
        isLocalPlayer = true
    end

    if isLocalPlayer then
        if self._memberSource and self._memberSource.resolvePlayerFullName then
            local full = self._memberSource:resolvePlayerFullName()
            if full and full ~= "" and full:find("%s") then
                member:setName(full)
                return full
            end
        end
        if _G.GM and _G.GM.memberController and _G.GM.memberController.resolvePlayerFullName then
            local full = _G.GM.memberController:resolvePlayerFullName()
            if full and full ~= "" and full:find("%s") then
                member:setName(full)
                return full
            end
        end
        if _G.GM and _G.GM.memberService and _G.GM.memberService.resolvePlayerFullName then
            local full = _G.GM.memberService:resolvePlayerFullName()
            if full and full ~= "" and full:find("%s") then
                member:setName(full)
                return full
            end
        end
    end

    if self._memberSource and self._memberSource.resolveFullName then
        local full = self._memberSource:resolveFullName(name)
        if full and full ~= "" and full:find("%s") then
            member:setName(full)
            return full
        end
    end
    if _G.GM and _G.GM.memberService and _G.GM.memberService.resolveFullName then
        local full = _G.GM.memberService:resolveFullName(name)
        if full and full ~= "" and full:find("%s") then
            member:setName(full)
            return full
        end
    end

    if GetNumGuildMembers and GetGuildRosterInfo then
        local num = GetNumGuildMembers() or 0
        local nLower = name:lower()
        for i = 1, num do
            local gName, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
            if gName then
                local gClean = (gName:match("^[^-]+") or gName):match("^%s*(.-)%s*$") or gClean
                if gClean:find("%s") then
                    if isLocalPlayer and myGUID and guid and guid == myGUID then
                        member:setName(gClean)
                        return gClean
                    end
                    local first = gClean:match("^(%S+)") or gClean
                    if first:lower() == nLower then
                        member:setName(gClean)
                        return gClean
                    end
                end
            end
        end
    end

    return name
end

--- Retorna todos os membros da guilda que possuem uma determinada profissão primária
--- Ordenados decrescente pelo nível de perícia (rank) e depois pelo nome
---@param profKey string @"ALCHEMY", "TAILORING", "LEATHERWORKING", "ENCHANTING", "BLACKSMITHING", "ENGINEERING"
---@return table[] @Lista de { member = Member, rank = number, maxRank = number, recipeCount = number }
function ProfessionRepository:getMembersWithProfession(profKey)
    local result = {}
    if not profKey then return result end

    local localName = UnitName and UnitName("player")
    local members = self:_getMemberList()
    for _, member in ipairs(members) do
        local inG = (member.isInGuild == nil or member:isInGuild() == true)
        if not inG and localName and member.getName and (member:getName() == localName or member:getName():match("^(%S+)") == localName) then
            inG = true
        end

        if member and inG and member.hasProfession and member:hasProfession(profKey) then
            self:_resolveMemberName(member)
            local prof = member:getProfession(profKey)
            local recipeCount = 0
            if prof and type(prof.recipes) == "table" then
                local counted = {}
                for rKey, val in pairs(prof.recipes) do
                    if val == true then
                        local canonId = rKey
                        local num = tonumber(rKey)
                        if num then canonId = num end
                        local rDef = ProfessionData.getRecipeById(rKey, profKey)
                        if rDef and rDef.id then canonId = rDef.id end
                        if not counted[canonId] then
                            counted[canonId] = true
                            recipeCount = recipeCount + 1
                        end
                    end
                end
            end
            table.insert(result, {
                member = member,
                rank = prof and prof.rank or 0,
                maxRank = prof and prof.maxRank or 300,
                recipeCount = recipeCount,
            })
        end
    end

    table.sort(result, function(a, b)
        if a.rank ~= b.rank then
            return a.rank > b.rank
        end
        return (a.member:getName() or "") < (b.member:getName() or "")
    end)

    return result
end

--- Retorna todos os membros da guilda que conhecem uma receita específica
--- Ordenados: membros online primeiro, depois maior rank de perícia, depois nome alfabético
---@param profKey string
---@param recipeId number|string|table
---@return table[] @Lista de { member = Member, rank = number, maxRank = number, isOnline = boolean }
function ProfessionRepository:getCraftersForRecipe(profKey, recipeId)
    local result = {}
    if not profKey or not recipeId then return result end

    local recipeDef = nil
    if type(recipeId) == "table" then
        recipeDef = recipeId
        recipeId = recipeDef.id
    elseif ProfessionData and ProfessionData.getRecipeById then
        recipeDef = ProfessionData.getRecipeById(recipeId, profKey)
    end

    local localName = UnitName and UnitName("player")
    local members = self:_getMemberList()
    for _, member in ipairs(members) do
        local inG = (member.isInGuild == nil or member:isInGuild() == true)
        if not inG and localName and member.getName and (member:getName() == localName or member:getName():match("^(%S+)") == localName) then
            inG = true
        end

        if member and inG and member.knowsRecipe and member:knowsRecipe(profKey, recipeDef or recipeId) then
            self:_resolveMemberName(member)
            local prof = member:getProfession(profKey)
            table.insert(result, {
                member = member,
                rank = prof and prof.rank or 0,
                maxRank = prof and prof.maxRank or 300,
                isOnline = member:isOnline() == true,
            })
        end
    end

    table.sort(result, function(a, b)
        if a.isOnline ~= b.isOnline then
            return a.isOnline == true -- Online primeiro
        end
        if a.rank ~= b.rank then
            return a.rank > b.rank
        end
        return (a.member:getName() or "") < (b.member:getName() or "")
    end)

    return result
end

--- Retorna a quantidade de artesãos na guilda para uma receita
---@param profKey string
---@param recipeId number|string
---@return number
function ProfessionRepository:countCraftersForRecipe(profKey, recipeId)
    local crafters = self:getCraftersForRecipe(profKey, recipeId)
    return #crafters
end

--- Retorna todas as receitas disponíveis para a profissão (catálogo + receitas aprendidas por membros) com deduplicação estrita
---@param profKey string
---@return table[]
function ProfessionRepository:getAllRecipes(profKey)
    local list = {}
    local seenId = {}
    local seenName = {}

    local function addRecipe(r)
        if not r or not r.id then return false end
        local canonId = r.id
        local numId = tonumber(canonId)
        local n1 = r.name and ProfessionData.normalizeText(r.name) or ""
        local n2 = r.namePT and ProfessionData.normalizeText(r.namePT) or ""

        if seenId[canonId] or (numId and seenId[numId]) or (numId and seenId[tostring(numId)]) then
            return false
        end
        if n1 ~= "" and seenName[n1] then
            return false
        end
        if n2 ~= "" and seenName[n2] then
            return false
        end

        seenId[canonId] = true
        if numId then
            seenId[numId] = true
            seenId[tostring(numId)] = true
        end
        if n1 ~= "" then seenName[n1] = true end
        if n2 ~= "" then seenName[n2] = true end
        table.insert(list, r)
        return true
    end

    -- 1. Receitas do catálogo canônico e dinâmico registrado
    if ProfessionData and ProfessionData.getRecipesForProfession then
        for _, r in ipairs(ProfessionData.getRecipesForProfession(profKey)) do
            addRecipe(r)
        end
    end

    -- 2. Qualquer receita aprendida por membros da guilda que ainda não conste na lista
    local members = self:_getMemberList()
    for _, member in ipairs(members) do
        if member and member.getProfession then
            local prof = member:getProfession(profKey)
            if prof and type(prof.recipes) == "table" then
                for rId, isKnown in pairs(prof.recipes) do
                    if isKnown then
                        local r = ProfessionData.getRecipeById(rId, profKey)
                        if r then
                            addRecipe(r)
                        else
                            local numId = tonumber(rId)
                            if numId then
                                local rName = tostring(numId)
                                local icon = ProfessionData.PROFESSIONS[profKey] and ProfessionData.PROFESSIONS[profKey].icon or "Interface\\Icons\\INV_Misc_QuestionMark"
                                if GetSpellInfo then
                                    local sName, _, sIcon = GetSpellInfo(numId)
                                    if sName then rName = sName end
                                    if sIcon then icon = sIcon end
                                end
                                local dynamicRecipe = {
                                    id = numId,
                                    name = rName,
                                    namePT = rName,
                                    prof = profKey,
                                    skill = prof.rank or 1,
                                    category = "Geral",
                                    categoryPT = "Geral",
                                    quality = 1,
                                    icon = icon,
                                    reagents = {},
                                }
                                ProfessionData.registerDynamicRecipe(profKey, dynamicRecipe)
                                addRecipe(dynamicRecipe)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Ordena por skill requerida crescente e depois por nome
    table.sort(list, function(a, b)
        if (a.skill or 0) ~= (b.skill or 0) then
            return (a.skill or 0) < (b.skill or 0)
        end
        return (a.name or "") < (b.name or "")
    end)

    return list
end

--- Retorna uma receita pelo identificador
---@param recipeId number|string
---@param profKey string|nil
---@return table|nil
function ProfessionRepository:getRecipeById(recipeId, profKey)
    if not ProfessionData or not ProfessionData.getRecipeById then
        return nil
    end
    return ProfessionData.getRecipeById(recipeId, profKey)
end
