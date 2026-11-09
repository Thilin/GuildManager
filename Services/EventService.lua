---@class EventService
---@field private _eventRepository EventRepository
---@field private _memberService MemberService|nil
---@field private _guildRosterService GuildRosterService|nil
EventService = {}
EventService.__index = EventService

local joinDateCache = {}
local bdayParseCache = {}
local timestampDateCache = {}
local todayInfoCache = {
    year = 2026,
    month = 10,
    day = 19,
    midnight = 0,
    expiresAt = 0,
}

local function getTodayInfo()
    local now = (GetTime and GetTime()) or 0
    if now > 0 and now < todayInfoCache.expiresAt then
        return todayInfoCache.year, todayInfoCache.month, todayInfoCache.day, todayInfoCache.midnight
    end

    local curDate = (date and date("*t")) or (os and os.date and os.date("*t")) or { year = 2026, month = 10, day = 19 }
    local y = curDate.year or 2026
    local m = curDate.month or 10
    local d = curDate.day or 19
    local midnight = 0
    if time then
        midnight = time({ year = y, month = m, day = d, hour = 0, min = 0, sec = 0 }) or 0
    end

    todayInfoCache.year = y
    todayInfoCache.month = m
    todayInfoCache.day = d
    todayInfoCache.midnight = midnight
    todayInfoCache.expiresAt = now + 5.0
    return y, m, d, midnight
end

local function parseJoinDateCached(joinDateStr)
    if not joinDateStr or joinDateStr == "" then return nil end
    local cached = joinDateCache[joinDateStr]
    if cached ~= nil then
        return cached or nil
    end

    local jy, jm, jd = joinDateStr:match("^(%d%d%d%d)[/%-%.](%d%d?)[/%-%.](%d%d?)$")
    if not (jy and jm and jd) then
        jd, jm, jy = joinDateStr:match("^(%d%d?)[/%-%.](%d%d?)[/%-%.](%d%d%d%d)$")
    end

    if jy and jm and jd then
        local ny, nm, nd = tonumber(jy), tonumber(jm), tonumber(jd)
        if ny and nm and nd then
            local midnight = 0
            if time then
                midnight = time({ year = ny, month = nm, day = nd, hour = 0, min = 0, sec = 0 }) or 0
            end
            local entry = { y = ny, m = nm, d = nd, midnight = midnight }
            joinDateCache[joinDateStr] = entry
            return entry
        end
    end

    joinDateCache[joinDateStr] = false
    return nil
end

local function parseBirthdayCached(bdayStr)
    if not bdayStr or bdayStr == "" then return nil end
    local cached = bdayParseCache[bdayStr]
    if cached ~= nil then
        return cached or nil
    end

    local cleanStr = bdayStr:match("^%s*(.-)%s*$")
    local pMonth, pDay = nil, nil

    local y, mo, d = cleanStr:match("^(%d%d%d%d)[/%-%.](%d%d?)[/%-%.](%d%d?)$")
    if mo and d then
        pMonth, pDay = mo, d
    else
        d, mo, y = cleanStr:match("^(%d%d?)[/%-%.](%d%d?)[/%-%.](%d%d%d%d)$")
        if mo and d then
            pMonth, pDay = mo, d
        else
            pMonth, pDay = cleanStr:match("^(%d%d?)[/%-%.](%d%d?)$")
        end
    end

    if pMonth and pDay then
        local bm = tonumber(pMonth)
        local bd = tonumber(pDay)
        if bm and bd then
            if bm > 12 and bd <= 12 then
                bm, bd = bd, bm
            end
            if bm >= 1 and bm <= 12 and bd >= 1 and bd <= 31 then
                local entry = {
                    month = bm,
                    day = bd,
                    formatted = string.format("%02d/%02d", bm, bd),
                }
                bdayParseCache[bdayStr] = entry
                return entry
            end
        end
    end

    bdayParseCache[bdayStr] = false
    return nil
end

local function getTimestampDateCached(ts)
    if not ts or ts <= 0 then return nil end
    local cached = timestampDateCache[ts]
    if cached then
        return cached.year, cached.month, cached.day
    end
    local pD = (date and date("*t", ts)) or (os and os.date and os.date("*t", ts))
    if pD then
        timestampDateCache[ts] = { year = pD.year, month = pD.month, day = pD.day }
        return pD.year, pD.month, pD.day
    end
    return nil
end

--- Construtor do serviço de gerenciamento da agenda e eventos da guilda.
---@param eventRepository EventRepository
---@param memberService MemberService|nil
---@param guildRosterService GuildRosterService|nil
---@return EventService
function EventService:new(eventRepository, memberService, guildRosterService)
    local instance = setmetatable({}, self)

    instance._eventRepository = eventRepository
    instance._memberService = memberService
    instance._guildRosterService = guildRosterService
    instance._cachedGuildRanks = nil
    instance._cachedGuildRanksAt = 0
    instance._monthBirthdaysCache = {}
    instance._monthPromotionsCache = {}
    instance._upcomingBirthdaysCache = {}
    instance._upcomingPromotionsCache = {}
    instance._cacheStateKey = nil
    instance._cacheExpiresAt = 0

    return instance
end

--- Invalida os caches de aniversários e promoções da agenda.
function EventService:invalidateCache()
    self._monthBirthdaysCache = {}
    self._monthPromotionsCache = {}
    self._upcomingBirthdaysCache = {}
    self._upcomingPromotionsCache = {}
    self._cacheStateKey = nil
    self._cacheExpiresAt = 0
end

--- Verifica se o cache derivado de membros e configurações continua válido.
function EventService:ensureCacheValid()
    local now = (GetTime and GetTime()) or 0
    local repoRev = (_G.GM and _G.GM.memberRepository and _G.GM.memberRepository.getRevision and _G.GM.memberRepository:getRevision()) or 0
    local settingsService = _G.GM and _G.GM.settingsService
    local promoEnabled = (settingsService and settingsService:get("enableJoinDatePromotions") == true) and "1" or "0"
    local lookahead = (settingsService and settingsService:get("birthdayLookaheadDays")) or 30
    local curLoc = (_G.GM and _G.GM.GetLocale and _G.GM.GetLocale()) or "enUS"
    local stateKey = string.format("%d:%s:%s:%s", repoRev, promoEnabled, tostring(lookahead), curLoc)

    if self._cacheStateKey ~= stateKey or (now > 0 and now >= self._cacheExpiresAt) then
        self._monthBirthdaysCache = {}
        self._monthPromotionsCache = {}
        self._upcomingBirthdaysCache = {}
        self._upcomingPromotionsCache = {}
        self._cacheStateKey = stateKey
        self._cacheExpiresAt = (now > 0) and (now + 10.0) or 0
    end
end

--- Retorna a lista de membros ativos na guilda, priorizando o cache pré-filtrado do GuildRosterService.
---@return Member[]
function EventService:getActiveMembers()
    if self._guildRosterService and self._guildRosterService.getActiveMemberList then
        local active = self._guildRosterService:getActiveMemberList()
        if active and #active > 0 then
            return active
        end
    end
    if self._memberService and self._memberService.getAllMembers then
        return self._memberService:getAllMembers() or {}
    end
    return {}
end

--- Normaliza e formata uma data (aceita "DD/MM/AAAA", "YYYY-MM-DD", "DD/MM" ou "MM/dd").
---@param dateStr string
---@return string|nil formattedDate, number|nil month, number|nil day, number|nil year
function EventService:parseEventDate(dateStr)
    if not dateStr or type(dateStr) ~= "string" then return nil end
    local clean = dateStr:match("^%s*(.-)%s*$")
    if clean == "" then return nil end

    local curYear, curMonth, curDay = getTodayInfo()

    -- Formato YYYY-MM-DD
    local y, m, d = clean:match("^(%d%d%d%d)[/%-%.](%d%d?)[/%-%.](%d%d?)$")
    if y and m and d then
        return string.format("%04d-%02d-%02d", tonumber(y), tonumber(m), tonumber(d)), tonumber(m), tonumber(d), tonumber(y)
    end

    -- Formato DD/MM/AAAA
    d, m, y = clean:match("^(%d%d?)[/%-%.](%d%d?)[/%-%.](%d%d%d%d)$")
    if d and m and y then
        return string.format("%04d-%02d-%02d", tonumber(y), tonumber(m), tonumber(d)), tonumber(m), tonumber(d), tonumber(y)
    end

    -- Formato MM/DD ou DD/MM (assume ano corrente ou próximo)
    m, d = clean:match("^(%d%d?)[/%-%.](%d%d?)$")
    if m and d then
        local month = tonumber(m)
        local day = tonumber(d)
        if month > 12 and day <= 12 then
            month, day = day, month
        end
        local targetYear = curYear
        if month < (curMonth or 1) or (month == curMonth and day < (curDay or 1)) then
            targetYear = curYear + 1
        end
        return string.format("%04d-%02d-%02d", targetYear, month, day), month, day, targetYear
    end

    return nil
end

--- Cria e persiste um novo evento na agenda da guilda.
---@param title string
---@param eventType EventType
---@param dateStr string
---@param timeStr string|nil
---@param description string|nil
---@param creator string|nil
---@return Event|nil event, string|nil errorMessage
function EventService:createEvent(title, eventType, dateStr, timeStr, description, creator)
    local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
    if not title or title:match("^%s*$") then
        return nil, curL["EVENT_ERR_TITLE_REQ"]
    end

    local cleanTitle = title:match("^%s*(.-)%s*$")
    local formattedDate = self:parseEventDate(dateStr)
    if not formattedDate then
        return nil, curL["EVENT_ERR_INVALID_DATE"]
    end

    local cleanTime = (timeStr and timeStr:match("^%s*(.-)%s*$")) or "20:00"
    if cleanTime == "" then cleanTime = "20:00" end

    local cleanDesc = (description and description:match("^%s*(.-)%s*$")) or ""
    local cleanCreator = (creator and creator:match("^%s*(.-)%s*$")) or ((UnitName and UnitName("player")) or "")

    local event = Event:new({
        title = cleanTitle,
        type = eventType or EventType.OUTRO,
        date = formattedDate,
        time = cleanTime,
        description = cleanDesc,
        creator = cleanCreator,
        createdAt = (time and time()) or 0,
        invitees = {},
    })

    local ok = self._eventRepository:save(event)
    if ok then
        return event, nil
    end
    return nil, curL["EVENT_ERR_NOT_FOUND"]
end

--- Atualiza as informações de um evento existente.
---@param id string
---@param title string
---@param eventType EventType
---@param dateStr string
---@param timeStr string|nil
---@param description string|nil
---@return Event|nil event, string|nil errorMessage
function EventService:updateEvent(id, title, eventType, dateStr, timeStr, description)
    local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
    if not id or id == "" then
        return nil, curL["EVENT_ERR_NOT_FOUND"]
    end

    local event = self._eventRepository:findById(id)
    if not event then
        return nil, curL["EVENT_ERR_NOT_FOUND"]
    end

    if not title or title:match("^%s*$") then
        return nil, curL["EVENT_ERR_TITLE_REQ"]
    end

    local cleanTitle = title:match("^%s*(.-)%s*$")
    local formattedDate = self:parseEventDate(dateStr)
    if not formattedDate then
        return nil, curL["EVENT_ERR_INVALID_DATE"]
    end

    local cleanTime = (timeStr and timeStr:match("^%s*(.-)%s*$")) or "20:00"
    if cleanTime == "" then cleanTime = "20:00" end
    local cleanDesc = (description and description:match("^%s*(.-)%s*$")) or ""

    event:setTitle(cleanTitle)
    event:setType(eventType)
    event:setDate(formattedDate)
    event:setTime(cleanTime)
    event:setDescription(cleanDesc)

    local ok = self._eventRepository:save(event)
    if ok then
        return event, nil
    end
    return nil, "Falha ao salvar alterações do evento."
end

--- Deleta um evento pelo ID.
---@param id string
---@return boolean
function EventService:deleteEvent(id)
    if not id or id == "" then return false end
    return self._eventRepository:delete(id)
end

--- Busca um evento pelo ID.
---@param id string
---@return Event|nil
function EventService:getEvent(id)
    if not id or id == "" then return nil end
    return self._eventRepository:findById(id)
end

--- Retorna todos os eventos da agenda ordenados cronologicamente por data e horário.
---@param filterType string|nil @Filtro opcional por tipo (ex: "RAID", "ANIVERSARIO", "TODOS")
---@param searchText string|nil @Filtro opcional por texto de busca no título ou descrição
---@return Event[]
function EventService:getAllEvents(filterType, searchText)
    local all = self._eventRepository:findAll() or {}
    local filtered = {}

    local filterLower = filterType and filterType ~= "TODOS" and filterType ~= "" and filterType:upper() or nil
    local searchLower = searchText and searchText:match("^%s*(.-)%s*$"):lower() or ""

    for _, ev in ipairs(all) do
        local matchesType = true
        if filterLower then
            matchesType = (ev:getType() == filterLower)
        end

        local matchesSearch = true
        if searchLower ~= "" then
            local t = (ev:getTitle() or ""):lower()
            local d = (ev:getDescription() or ""):lower()
            local c = (ev:getCreator() or ""):lower()
            if not t:find(searchLower, 1, true) and not d:find(searchLower, 1, true) and not c:find(searchLower, 1, true) then
                matchesSearch = false
            end
        end

        if matchesType and matchesSearch then
            table.insert(filtered, ev)
        end
    end

    -- Ordena cronologicamente por data e horário
    table.sort(filtered, function(a, b)
        local keyA = (a:getDate() or "") .. " " .. (a:getTime() or "")
        local keyB = (b:getDate() or "") .. " " .. (b:getTime() or "")
        if keyA == keyB then
            return (a:getCreatedAt() or 0) > (b:getCreatedAt() or 0)
        end
        return keyA < keyB
    end)

    return filtered
end

--- Adiciona um membro à lista de convidados do evento.
---@param eventId string
---@param memberName string
---@return boolean success, string|nil errorMessage
function EventService:addInvitee(eventId, memberName)
    local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
    local event = self._eventRepository:findById(eventId)
    if not event then
        return false, curL["EVENT_ERR_NOT_FOUND"]
    end

    local cleanName = memberName and (memberName:match("^[^-]+") or memberName):match("^%s*(.-)%s*$")
    if not cleanName or cleanName == "" then
        return false, curL["EVENT_ERR_NAME_INVALID"]
    end

    if event:hasInvitee(cleanName) then
        return false, curL["EVENT_ERR_ALREADY_INVITED"]
    end

    -- Busca detalhes do membro para enriquecer o card
    local classToken = ""
    local level = 1
    if self._memberService then
        local m = self._memberService:getMember(cleanName) or self._memberService:getMember(memberName)
        if m then
            classToken = m:getClass() or ""
            level = m:getLevel() or 1
        end
    end

    if classToken == "" and self._guildRosterService and self._guildRosterService.getRosterData then
        local rData = self._guildRosterService:getRosterData()
        if rData and (rData[cleanName] or rData[memberName]) then
            local data = rData[cleanName] or rData[memberName]
            classToken = data.classFileName or data.class or ""
            level = data.level or 1
        end
    end

    event:addInvitee(cleanName, classToken, level, "PENDENTE")
    local ok = self._eventRepository:save(event)
    return ok, ok and nil or "Erro ao salvar convidado."
end

--- Remove um convidado do evento.
---@param eventId string
---@param memberName string
---@return boolean
function EventService:removeInvitee(eventId, memberName)
    local event = self._eventRepository:findById(eventId)
    if not event then return false end

    local cleanName = memberName and (memberName:match("^[^-]+") or memberName):match("^%s*(.-)%s*$")
    if not cleanName then return false end

    local removed = event:removeInvitee(cleanName)
    if removed then
        self._eventRepository:save(event)
        return true
    end
    return false
end

--- Envia um convite de grupo in-game no World of Warcraft para um membro da lista.
---@param memberName string
---@return boolean success, string message
function EventService:inviteMemberInGame(memberName)
    if not memberName or memberName == "" then
        return false, "Nome inválido."
    end

    local clean = memberName:match("^[^-]+") or memberName
    clean = clean:match("^%s*(.-)%s*$")

    local invited = false
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        local ok = pcall(C_PartyInfo.InviteUnit, clean)
        if ok then invited = true end
    elseif InviteUnit then
        local ok = pcall(InviteUnit, clean)
        if ok then invited = true end
    end

    if invited then
        local msg = string.format("|cff00ff00[GuildManager]|r Convite de grupo enviado para |cffffff00%s|r!", clean)
        print(msg)
        return true, msg
    else
        local msg = string.format("|cffff4444[GuildManager]|r Não foi possível convidar |cffffff00%s|r para o grupo.", clean)
        print(msg)
        return false, msg
    end
end

--- Convida todos os membros online da lista de convidados para o grupo/raide no jogo.
---@param eventId string
---@return number invitedCount, number totalOnline
function EventService:inviteAllOnlineMembers(eventId)
    local event = self._eventRepository:findById(eventId)
    if not event then return 0, 0 end

    local invitees = event:getInvitees() or {}
    local myName = ((UnitName and UnitName("player")) or ""):lower()
    local onlineSet = {}

    -- Coleta quem está online no roster da guilda
    if self._guildRosterService and self._guildRosterService.getRosterData then
        local rData = self._guildRosterService:getRosterData() or {}
        for rName, info in pairs(rData) do
            if info and info.online then
                local cName = (rName:match("^[^-]+") or rName):lower()
                onlineSet[cName] = true
            end
        end
    end

    local invitedCount = 0
    local totalOnline = 0

    for _, inv in ipairs(invitees) do
        local nameLower = (inv.name:match("^[^-]+") or inv.name):lower()
        if nameLower ~= myName then
            -- Se não temos dados de online, tenta convidar assim mesmo
            local isOnline = (next(onlineSet) == nil) or onlineSet[nameLower] == true
            if isOnline then
                totalOnline = totalOnline + 1
                local ok = false
                if C_PartyInfo and C_PartyInfo.InviteUnit then
                    ok = pcall(C_PartyInfo.InviteUnit, inv.name)
                elseif InviteUnit then
                    ok = pcall(InviteUnit, inv.name)
                end
                if ok then
                    invitedCount = invitedCount + 1
                end
            end
        end
    end

    print(string.format(
        "|cff00ff00[GuildManager]|r Convites de grupo disparados para |cffffff00%d|r membro(s) online do evento |cffffd200%s|r!",
        invitedCount, event:getTitle()
    ))

    return invitedCount, totalOnline
end

--- Calcula e retorna a lista dos próximos aniversariantes da guilda,
--- ordenados pelos que fazem aniversário mais cedo a partir de hoje.
---@return table[] @Lista com { member, name, cleanName, class, level, rank, birthday, daysUntil, daysText }
function EventService:getUpcomingBirthdays(maxDays)
    local result = {}
    if not self._memberService or not self._memberService.getAllMembers then
        return result
    end

    local lookahead = maxDays
    if not lookahead and _G.GM and _G.GM.settingsService then
        lookahead = _G.GM.settingsService:get("birthdayLookaheadDays")
    end
    lookahead = tonumber(lookahead) or 30

    self:ensureCacheValid()
    local cacheKey = tostring(lookahead)
    if self._upcomingBirthdaysCache[cacheKey] then
        return self._upcomingBirthdaysCache[cacheKey]
    end

    local allMembers = self:getActiveMembers()
    local curYear, curMonth, curDay, todayMidnight = getTodayInfo()

    for _, m in ipairs(allMembers) do
        local inGuild = true
        if m and type(m.isInGuild) == "function" then
            inGuild = m:isInGuild()
        end

        if inGuild then
            local bdayStr = m:getBirthday()
            local parsed = parseBirthdayCached(bdayStr)
            if parsed then
                local month = parsed.month
                local day = parsed.day

                -- Determina o próximo ano em que esse aniversário ocorre
                local targetYear = curYear
                if month < curMonth or (month == curMonth and day < curDay) then
                    targetYear = curYear + 1
                end

                local daysUntil = 0
                if time and todayMidnight > 0 then
                    local targetMidnight = time({ year = targetYear, month = month, day = day, hour = 0, min = 0, sec = 0 })
                    daysUntil = math.floor((targetMidnight - todayMidnight) / 86400)
                    if daysUntil < 0 then daysUntil = 0 end
                else
                    -- Cálculo simplificado caso time() falhe
                    if targetYear == curYear then
                        daysUntil = (month - curMonth) * 30 + (day - curDay)
                    else
                        daysUntil = (12 - curMonth + month) * 30 + (day - curDay)
                    end
                end

                if not lookahead or lookahead <= 0 or daysUntil <= lookahead then
                    local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
                    local daysText = ""
                    if daysUntil == 0 then
                        daysText = "|cff00ff00" .. (curL["EVENT_DAYS_TODAY"] or "Today!") .. "|r"
                    elseif daysUntil == 1 then
                        daysText = "|cffffff00" .. (curL["EVENT_DAYS_TOMORROW"] or "Tomorrow!") .. "|r"
                    elseif daysUntil <= 7 then
                        daysText = "|cffffff00" .. string.format(curL["EVENT_DAYS_IN_X"] or "In %d days", daysUntil) .. "|r"
                    elseif daysUntil <= 30 then
                        daysText = "|cffaaaaaa" .. string.format(curL["EVENT_DAYS_IN_X"] or "In %d days", daysUntil) .. "|r"
                    else
                        daysText = "|cff777777" .. string.format(curL["EVENT_DAYS_IN_X"] or "In %d days", daysUntil) .. "|r"
                    end

                    local rawName = m:getName() or (curL["MEMBER_DEFAULT_RANK"] or "Member")
                    local cleanName = (m.getCleanName and m:getCleanName()) or rawName:match("^[^-]+") or rawName

                    table.insert(result, {
                        member = m,
                        name = rawName,
                        cleanName = cleanName,
                        class = m:getClass() or "",
                        level = m:getLevel() or 1,
                        rank = m:getRankName() or "",
                        birthday = parsed.formatted,
                        targetYear = targetYear,
                        daysUntil = daysUntil,
                        daysText = daysText,
                    })
                end
            end
        end
    end

    -- Ordena pelos aniversários mais próximos
    table.sort(result, function(a, b)
        if a.daysUntil == b.daysUntil then
            return (a.cleanName or "") < (b.cleanName or "")
        end
        return a.daysUntil < b.daysUntil
    end)

    self._upcomingBirthdaysCache[cacheKey] = result
    return result
end

--- Cria automaticamente um evento de aniversário na agenda a partir de um membro.
--- Convida o aniversariante, o líder e os oficiais da guilda.
---@param member Member
---@return Event|nil event, string|nil errorMessage
function EventService:createBirthdayEventForMember(member)
    local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
    if not member or type(member.getName) ~= "function" then
        return nil, curL["EVENT_ERR_INVALID_MEMBER"]
    end

    if type(member.isInGuild) == "function" and not member:isInGuild() then
        return nil, curL["EVENT_ERR_INVALID_MEMBER"]
    end

    local bday = member:getBirthday()
    if not bday or bday == "" then
        return nil, curL["EVENT_ERR_NO_BDAY"]
    end

    local cleanName = (member:getName():match("^[^-]+") or member:getName()):match("^%s*(.-)%s*$")
    local formattedDate, m, d, y = self:parseEventDate(bday)
    if not formattedDate then
        return nil, curL["EVENT_ERR_BDAY_FMT"]
    end

    local title = string.format(curL["EVENT_BDAY_AUTO_TITLE"] or "%s's Birthday", cleanName)
    local desc = string.format(curL["EVENT_BDAY_AUTO_DESC"] or "Birthday celebration for %s!", cleanName)

    local event, err = self:createEvent(title, EventType.ANIVERSARIO, formattedDate, "20:00", desc)
    if not event then
        return nil, err
    end

    -- Adiciona o aniversariante aos convidados
    self:addInvitee(event:getId(), cleanName)

    -- Adiciona líder e oficiais se disponíveis e que ainda estão na guilda
    for _, otherMember in ipairs(self:getActiveMembers()) do
        local otherInGuild = true
        if type(otherMember.isInGuild) == "function" then
            otherInGuild = otherMember:isInGuild()
        end
        if otherInGuild then
            local rankIndex = otherMember:getRankIndex()
            local rankName = (otherMember:getRankName() or ""):lower()
            local otherClean = (otherMember.getCleanName and otherMember:getCleanName()) or otherMember:getName():match("^[^-]+") or otherMember:getName()
            if rankIndex == 0 or rankIndex == 1 or rankName:find("oficial") or rankName:find("officer") or rankName:find("lider") then
                self:addInvitee(event:getId(), otherClean)
            end
        end
    end

    return event, nil
end

--- Obtém a lista de cargos da guilda ordenada hierarquicamente (0 = Líder, 1 = Oficial, ...).
---@return table[] @Lista de tabelas { index = number, name = string, rankOrder = number }
function EventService:getGuildRanks()
    local now = (GetTime and GetTime()) or 0
    if self._cachedGuildRanks and #self._cachedGuildRanks > 0 and now > 0 and (now - (self._cachedGuildRanksAt or 0)) < 10.0 then
        return self._cachedGuildRanks
    end

    local ranks = {}
    local numRanks = (GuildControlGetNumRanks and GuildControlGetNumRanks()) or 0
    if numRanks > 0 then
        for i = 1, numRanks do
            local rName = (GuildControlGetRankName and GuildControlGetRankName(i)) or ("Rank " .. i)
            table.insert(ranks, {
                index = i - 1,
                name = rName,
                rankOrder = i,
            })
        end
    end

    if #ranks == 0 and self._memberService and self._memberService.getAllMembers then
        local seen = {}
        for _, m in ipairs(self:getActiveMembers()) do
            local idx = m:getRankIndex()
            local name = m:getRankName()
            if idx and not seen[idx] then
                seen[idx] = true
                table.insert(ranks, {
                    index = idx,
                    name = name or ("Rank " .. (idx + 1)),
                    rankOrder = idx + 1,
                })
            end
        end
        table.sort(ranks, function(a, b) return (a.index or 0) < (b.index or 0) end)
    end

    if #ranks > 0 then
        self._cachedGuildRanks = ranks
        self._cachedGuildRanksAt = now
    end

    return ranks
end

--- Retorna a lista de eventos da guilda agendados para hoje ou datas futuras.
---@param lookaheadDays number|nil
---@return table[]
function EventService:getUpcomingEvents(lookaheadDays)
    local all = self:getAllEvents() or {}
    local results = {}

    local curYear, curMonth, curDay, todayMidnight = getTodayInfo()

    local lookahead = lookaheadDays
    if not lookahead and _G.GM and _G.GM.settingsService then
        lookahead = _G.GM.settingsService:get("birthdayLookaheadDays") or 30
    end

    for _, ev in ipairs(all) do
        local dStr = ev:getDate()
        local formattedDate, m, d, y = self:parseEventDate(dStr)
        if formattedDate and m and d and y then
            local daysUntil = 0
            if time and todayMidnight > 0 then
                local evMidnight = time({ year = y, month = m, day = d, hour = 0, min = 0, sec = 0 })
                daysUntil = math.floor((evMidnight - todayMidnight) / 86400)
            else
                if y == curYear then
                    daysUntil = (m - curMonth) * 30 + (d - curDay)
                else
                    daysUntil = (y - curYear) * 365 + (m - curMonth) * 30 + (d - curDay)
                end
            end

            if daysUntil >= 0 then
                if not lookahead or lookahead <= 0 or daysUntil <= lookahead then
                    local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
                    local daysText = ""
                    if daysUntil == 0 then
                        daysText = "|cff00ff00" .. (curL["EVENT_DAYS_TODAY"] or "Today!") .. "|r"
                    elseif daysUntil == 1 then
                        daysText = "|cffffff00" .. (curL["EVENT_DAYS_TOMORROW"] or "Tomorrow!") .. "|r"
                    elseif daysUntil <= 7 then
                        daysText = "|cffffff00" .. string.format(curL["EVENT_DAYS_IN_X"] or "In %d days", daysUntil) .. "|r"
                    else
                        daysText = "|cffaaaaaa" .. string.format(curL["EVENT_DAYS_IN_X"] or "In %d days", daysUntil) .. "|r"
                    end

                    table.insert(results, {
                        itemType = "EVENT",
                        event = ev,
                        id = ev:getId(),
                        title = ev:getTitle(),
                        type = ev:getType(),
                        date = ev:getDate(),
                        time = ev:getTime(),
                        creator = ev:getCreator(),
                        inviteeCount = ev:getInviteeCount(),
                        daysUntil = daysUntil,
                        daysText = daysText,
                    })
                end
            end
        end
    end

    table.sort(results, function(a, b)
        if a.daysUntil == b.daysUntil then
            return (a.time or "") < (b.time or "")
        end
        return a.daysUntil < b.daysUntil
    end)

    return results
end

--- Retorna a lista de promoções elegíveis ou futuras com base no tempo de entrada na guilda (join date).
---@param lookaheadDays number|nil
---@return table[]
function EventService:getUpcomingPromotions(lookaheadDays)
    local results = {}
    if not self._memberService or not self._memberService.getAllMembers then
        return results
    end

    local settingsService = _G.GM and _G.GM.settingsService
    if not settingsService then
        return results
    end

    if settingsService:get("enableJoinDatePromotions") ~= true then
        return results
    end

    local rankDays = settingsService:get("rankPromotionDays") or {}
    if type(rankDays) ~= "table" then
        return results
    end

    local lookahead = lookaheadDays
    if not lookahead then
        lookahead = settingsService:get("birthdayLookaheadDays") or 30
    end

    self:ensureCacheValid()
    local cacheKey = tostring(lookahead)
    if self._upcomingPromotionsCache[cacheKey] then
        return self._upcomingPromotionsCache[cacheKey]
    end

    local ranks = self:getGuildRanks()
    if #ranks == 0 then
        return results
    end

    local curYear, curMonth, curDay, todayMidnight = getTodayInfo()

    local members = self:getActiveMembers()
    for _, m in ipairs(members) do
        local inGuild = true
        if type(m.isInGuild) == "function" then
            inGuild = m:isInGuild()
        end

        local joinDateStr = (m.getDateJoin and m:getDateJoin()) or ""
        if inGuild and joinDateStr and joinDateStr ~= "" then
            local jParsed = parseJoinDateCached(joinDateStr)
            if jParsed then
                local daysInGuild = 0
                if time and todayMidnight > 0 and jParsed.midnight > 0 then
                    daysInGuild = math.floor((todayMidnight - jParsed.midnight) / 86400)
                    if daysInGuild < 0 then daysInGuild = 0 end
                else
                    daysInGuild = (curYear - jParsed.y) * 365 + (curMonth - jParsed.m) * 30 + (curDay - jParsed.d)
                    if daysInGuild < 0 then daysInGuild = 0 end
                end

                local curRankIdx = m:getRankIndex() or 99
                local curRankName = m:getRankName() or ""

                -- Promoção significa avançar para um rankIndex menor que o atual (exceto 0 = Guild Master)
                local eligiblePromotion = nil
                local nextUpcomingPromotion = nil
                local minUpcomingDays = 999999

                for _, rDef in ipairs(ranks) do
                    if rDef.index > 0 and rDef.index < curRankIdx then
                        local reqDays = tonumber(rankDays[rDef.name]) or tonumber(rankDays[tostring(rDef.index)]) or tonumber(rankDays[rDef.index])
                        if reqDays and reqDays > 0 then
                            if daysInGuild >= reqDays then
                                if not eligiblePromotion or rDef.index < eligiblePromotion.targetRankIndex then
                                    eligiblePromotion = {
                                        targetRankName = rDef.name,
                                        targetRankIndex = rDef.index,
                                        requiredDays = reqDays,
                                    }
                                end
                            else
                                local daysUntil = reqDays - daysInGuild
                                if daysUntil < minUpcomingDays then
                                    minUpcomingDays = daysUntil
                                    nextUpcomingPromotion = {
                                        targetRankName = rDef.name,
                                        targetRankIndex = rDef.index,
                                        requiredDays = reqDays,
                                        daysUntil = daysUntil,
                                    }
                                end
                            end
                        end
                    end
                end

                local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
                local promoItem = nil
                local rawName = m:getName() or (curL["MEMBER_DEFAULT_RANK"] or "Member")
                local cleanName = (m.getCleanName and m:getCleanName()) or rawName:match("^[^-]+") or rawName

                if eligiblePromotion then
                    promoItem = {
                        itemType = "PROMOTION",
                        member = m,
                        name = rawName,
                        cleanName = cleanName,
                        class = m:getClass() or "",
                        level = m:getLevel() or 1,
                        currentRank = curRankName,
                        currentRankIndex = curRankIdx,
                        targetRank = eligiblePromotion.targetRankName,
                        targetRankIndex = eligiblePromotion.targetRankIndex,
                        daysInGuild = daysInGuild,
                        requiredDays = eligiblePromotion.requiredDays,
                        daysUntil = 0,
                        isEligibleNow = true,
                        daysText = "|cff00ff00" .. (curL["EVENT_PROMO_ELIGIBLE_TODAY"] or "Eligible Today!") .. "|r",
                    }
                elseif nextUpcomingPromotion and (not lookahead or lookahead <= 0 or nextUpcomingPromotion.daysUntil <= lookahead) then
                    local dText = ""
                    if nextUpcomingPromotion.daysUntil == 1 then
                        dText = "|cffffff00" .. (curL["EVENT_DAYS_TOMORROW"] or "Tomorrow!") .. "|r"
                    elseif nextUpcomingPromotion.daysUntil <= 7 then
                        dText = "|cffffff00" .. string.format(curL["EVENT_DAYS_IN_X"] or "In %d days", nextUpcomingPromotion.daysUntil) .. "|r"
                    else
                        dText = "|cffaaaaaa" .. string.format(curL["EVENT_DAYS_IN_X"] or "In %d days", nextUpcomingPromotion.daysUntil) .. "|r"
                    end

                    promoItem = {
                        itemType = "PROMOTION",
                        member = m,
                        name = rawName,
                        cleanName = cleanName,
                        class = m:getClass() or "",
                        level = m:getLevel() or 1,
                        currentRank = curRankName,
                        currentRankIndex = curRankIdx,
                        targetRank = nextUpcomingPromotion.targetRankName,
                        targetRankIndex = nextUpcomingPromotion.targetRankIndex,
                        daysInGuild = daysInGuild,
                        requiredDays = nextUpcomingPromotion.requiredDays,
                        daysUntil = nextUpcomingPromotion.daysUntil,
                        isEligibleNow = false,
                        daysText = dText,
                    }
                end

                if promoItem then
                    table.insert(results, promoItem)
                end
            end
        end
    end

    table.sort(results, function(a, b)
        if a.daysUntil == b.daysUntil then
            return (a.cleanName or "") < (b.cleanName or "")
        end
        return a.daysUntil < b.daysUntil
    end)

    self._upcomingPromotionsCache[cacheKey] = results
    return results
end

--- Retorna a lista de aniversariantes que fazem aniversário no mês e ano especificados.
---@param year number
---@param month number
---@return table[]
function EventService:getBirthdaysForMonth(year, month)
    local results = {}
    if not self._memberService or not self._memberService.getAllMembers then
        return results
    end

    self:ensureCacheValid()
    local cacheKey = string.format("%04d-%02d", year or 0, month or 0)
    if self._monthBirthdaysCache[cacheKey] then
        return self._monthBirthdaysCache[cacheKey]
    end

    local allMembers = self:getActiveMembers()
    for _, m in ipairs(allMembers) do
        local inGuild = true
        if type(m.isInGuild) == "function" then
            inGuild = m:isInGuild()
        end

        if inGuild then
            local bdayStr = m:getBirthday()
            local parsed = parseBirthdayCached(bdayStr)
            if parsed and parsed.month == month then
                local bm = parsed.month
                local bd = parsed.day
                local rawName = m:getName() or "Membro"
                local cleanName = (m.getCleanName and m:getCleanName()) or rawName:match("^[^-]+") or rawName
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
                    birthday = parsed.formatted,
                    dateStr = string.format("%02d/%02d/%04d", bd, bm, year),
                    dateKey = string.format("%04d-%02d-%02d", year, bm, bd),
                })
            end
        end
    end

    table.sort(results, function(a, b)
        if a.day == b.day then
            return (a.cleanName or "") < (b.cleanName or "")
        end
        return a.day < b.day
    end)

    self._monthBirthdaysCache[cacheKey] = results
    return results
end

--- Retorna a lista de datas de promoções da guilda para o mês e ano especificados.
---@param year number
---@param month number
---@return table[]
function EventService:getPromotionsForMonth(year, month)
    local results = {}
    if not self._memberService or not self._memberService.getAllMembers then
        return results
    end

    local settingsService = _G.GM and _G.GM.settingsService
    if not settingsService or settingsService:get("enableJoinDatePromotions") ~= true then
        return results
    end

    self:ensureCacheValid()
    local cacheKey = string.format("%04d-%02d", year or 0, month or 0)
    if self._monthPromotionsCache[cacheKey] then
        return self._monthPromotionsCache[cacheKey]
    end

    local rankDays = settingsService:get("rankPromotionDays") or {}
    local ranks = self:getGuildRanks()
    if #ranks == 0 then return results end

    local curYear, curMonth, curDay, todayMidnight = getTodayInfo()
    local curDateStr = string.format("%02d/%02d/%04d", curDay, curMonth, curYear)
    local curDateKey = string.format("%04d-%02d-%02d", curYear, curMonth, curDay)

    local allMembers = self:getActiveMembers()
    for _, m in ipairs(allMembers) do
        local inGuild = true
        if type(m.isInGuild) == "function" then
            inGuild = m:isInGuild()
        end

        if inGuild then
            local dateJoin = m:getDateJoin()
            local jParsed = parseJoinDateCached(dateJoin)
            if jParsed then
                local joinMidnight = jParsed.midnight
                local daysInGuild = 0
                if time and todayMidnight > 0 and joinMidnight > 0 then
                    daysInGuild = math.floor((todayMidnight - joinMidnight) / 86400)
                    if daysInGuild < 0 then daysInGuild = 0 end
                else
                    daysInGuild = (curYear - jParsed.y) * 365 + (curMonth - jParsed.m) * 30 + (curDay - jParsed.d)
                    if daysInGuild < 0 then daysInGuild = 0 end
                end

                local curRankIdx = m:getRankIndex() or 99
                local curRankName = m:getRankName() or ""
                local rawName = m:getName() or "Membro"
                local cleanName = (m.getCleanName and m:getCleanName()) or rawName:match("^[^-]+") or rawName

                local bestOverdueRank = nil
                local addedExactOnToday = {}

                for _, rDef in ipairs(ranks) do
                    if rDef.index > 0 and rDef.index < curRankIdx then
                        local reqDays = tonumber(rankDays[rDef.name]) or tonumber(rankDays[tostring(rDef.index)]) or tonumber(rankDays[rDef.index])
                        if reqDays and reqDays > 0 then
                            local pYear, pMonth, pDay = nil, nil, nil
                            if joinMidnight > 0 then
                                pYear, pMonth, pDay = getTimestampDateCached(joinMidnight + reqDays * 86400)
                            end

                            if pYear == year and pMonth == month and pDay then
                                local isEligibleNow = (daysInGuild >= reqDays)
                                if year == curYear and month == curMonth and pDay == curDay then
                                    addedExactOnToday[rDef.index] = true
                                end
                                table.insert(results, {
                                    member = m,
                                    name = rawName,
                                    cleanName = cleanName,
                                    class = m:getClass() or "",
                                    level = m:getLevel() or 1,
                                    currentRank = curRankName,
                                    currentRankIndex = curRankIdx,
                                    targetRank = rDef.name,
                                    targetRankIndex = rDef.index,
                                    daysInGuild = daysInGuild,
                                    requiredDays = reqDays,
                                    day = pDay,
                                    month = pMonth,
                                    year = pYear,
                                    dateStr = string.format("%02d/%02d/%04d", pDay, pMonth, pYear),
                                    dateKey = string.format("%04d-%02d-%02d", pYear, pMonth, pDay),
                                    isEligibleNow = isEligibleNow,
                                })
                            elseif year == curYear and month == curMonth and daysInGuild >= reqDays then
                                if not bestOverdueRank or rDef.index < bestOverdueRank.index then
                                    bestOverdueRank = {
                                        index = rDef.index,
                                        name = rDef.name,
                                        reqDays = reqDays,
                                    }
                                end
                            end
                        end
                    end
                end

                if bestOverdueRank and not addedExactOnToday[bestOverdueRank.index] then
                    table.insert(results, {
                        member = m,
                        name = rawName,
                        cleanName = cleanName,
                        class = m:getClass() or "",
                        level = m:getLevel() or 1,
                        currentRank = curRankName,
                        currentRankIndex = curRankIdx,
                        targetRank = bestOverdueRank.name,
                        targetRankIndex = bestOverdueRank.index,
                        daysInGuild = daysInGuild,
                        requiredDays = bestOverdueRank.reqDays,
                        day = curDay,
                        month = curMonth,
                        year = curYear,
                        dateStr = curDateStr,
                        dateKey = curDateKey,
                        isEligibleNow = true,
                        isPendingOverdue = true,
                    })
                end
            end
        end
    end

    table.sort(results, function(a, b)
        if a.day == b.day then
            return (a.cleanName or "") < (b.cleanName or "")
        end
        return a.day < b.day
    end)

    self._monthPromotionsCache[cacheKey] = results
    return results
end

_G.EventService = EventService
