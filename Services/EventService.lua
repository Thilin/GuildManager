---@class EventService
---@field private _eventRepository EventRepository
---@field private _memberService MemberService|nil
---@field private _guildRosterService GuildRosterService|nil
EventService = {}
EventService.__index = EventService

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

    return instance
end

--- Normaliza e formata uma data (aceita "DD/MM/AAAA", "YYYY-MM-DD", "DD/MM" ou "MM/dd").
---@param dateStr string
---@return string|nil formattedDate, number|nil month, number|nil day, number|nil year
function EventService:parseEventDate(dateStr)
    if not dateStr or type(dateStr) ~= "string" then return nil end
    local clean = dateStr:match("^%s*(.-)%s*$")
    if clean == "" then return nil end

    local curDate = (date and date("*t")) or (os and os.date and os.date("*t")) or { year = 2026, month = 10, day = 6 }
    local curYear = curDate.year or 2026

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
        if month < (curDate.month or 1) or (month == curDate.month and day < (curDate.day or 1)) then
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
    if not title or title:match("^%s*$") then
        return nil, "O título do evento é obrigatório."
    end

    local cleanTitle = title:match("^%s*(.-)%s*$")
    local formattedDate = self:parseEventDate(dateStr)
    if not formattedDate then
        return nil, "Data inválida. Use o formato DD/MM/AAAA ou MM/dd (ex: 15/10/2026)."
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
    return nil, "Falha ao salvar evento no banco de dados."
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
    if not id or id == "" then
        return nil, "ID do evento inválido."
    end

    local event = self._eventRepository:findById(id)
    if not event then
        return nil, "Evento não encontrado."
    end

    if not title or title:match("^%s*$") then
        return nil, "O título do evento é obrigatório."
    end

    local cleanTitle = title:match("^%s*(.-)%s*$")
    local formattedDate = self:parseEventDate(dateStr)
    if not formattedDate then
        return nil, "Data inválida. Use o formato DD/MM/AAAA ou MM/dd."
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
    local event = self._eventRepository:findById(eventId)
    if not event then
        return false, "Evento não encontrado."
    end

    local cleanName = memberName and (memberName:match("^[^-]+") or memberName):match("^%s*(.-)%s*$")
    if not cleanName or cleanName == "" then
        return false, "Nome do membro inválido."
    end

    if event:hasInvitee(cleanName) then
        return false, string.format("%s já está convidado para este evento.", cleanName)
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
function EventService:getUpcomingBirthdays()
    local result = {}
    if not self._memberService or not self._memberService.getAllMembers then
        return result
    end

    local allMembers = self._memberService:getAllMembers() or {}
    local curDate = (date and date("*t")) or (os and os.date and os.date("*t")) or { year = 2026, month = 10, day = 6 }
    local curYear = curDate.year or 2026
    local curMonth = curDate.month or 10
    local curDay = curDate.day or 6

    local todayMidnight = 0
    if time then
        todayMidnight = time({ year = curYear, month = curMonth, day = curDay, hour = 0, min = 0, sec = 0 })
    end

    for _, m in ipairs(allMembers) do
        local inGuild = true
        if m and type(m.isInGuild) == "function" then
            inGuild = m:isInGuild()
        end

        if inGuild then
            local bdayStr = m:getBirthday()
            if bdayStr and bdayStr ~= "" then
            local cleanStr = bdayStr:match("^%s*(.-)%s*$")
            local pMonth, pDay = cleanStr:match("^(%d%d?)[/%-%.](%d%d?)$")
            if pMonth and pDay then
                local month = tonumber(pMonth)
                local day = tonumber(pDay)

                -- Auto-ajuste de segurança caso digite DD/MM
                if month > 12 and day <= 12 then
                    month, day = day, month
                end

                if month >= 1 and month <= 12 and day >= 1 and day <= 31 then
                    -- Determina o próximo ano em que esse aniversário ocorre
                    local targetYear = curYear
                    if month < curMonth or (month == curMonth and day < curDay) then
                        targetYear = curYear + 1
                    end

                    local daysUntil = 0
                    if time then
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

                    local daysText = ""
                    if daysUntil == 0 then
                        daysText = "|cff00ff00Hoje! 🎂🎉|r"
                    elseif daysUntil == 1 then
                        daysText = "|cffffff00Amanhã!|r"
                    elseif daysUntil <= 7 then
                        daysText = string.format("|cffffff00Em %d dias|r", daysUntil)
                    elseif daysUntil <= 30 then
                        daysText = string.format("|cffaaaaaaEm %d dias|r", daysUntil)
                    else
                        daysText = string.format("|cff777777Em %d dias|r", daysUntil)
                    end

                    local rawName = m:getName() or "Membro"
                    local cleanName = rawName:match("^[^-]+") or rawName

                    table.insert(result, {
                        member = m,
                        name = rawName,
                        cleanName = cleanName,
                        class = m:getClass() or "",
                        level = m:getLevel() or 1,
                        rank = m:getRankName() or "",
                        birthday = string.format("%02d/%02d", month, day),
                        targetYear = targetYear,
                        daysUntil = daysUntil,
                        daysText = daysText,
                    })
                end
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

    return result
end

--- Cria automaticamente um evento de aniversário na agenda a partir de um membro.
--- Convida o aniversariante, o líder e os oficiais da guilda.
---@param member Member
---@return Event|nil event, string|nil errorMessage
function EventService:createBirthdayEventForMember(member)
    if not member or type(member.getName) ~= "function" then
        return nil, "Membro inválido."
    end

    if type(member.isInGuild) == "function" and not member:isInGuild() then
        return nil, "Este jogador não pertence mais à guilda."
    end

    local bday = member:getBirthday()
    if not bday or bday == "" then
        return nil, "Este membro não possui data de aniversário cadastrada."
    end

    local cleanName = (member:getName():match("^[^-]+") or member:getName()):match("^%s*(.-)%s*$")
    local formattedDate, m, d, y = self:parseEventDate(bday)
    if not formattedDate then
        return nil, "Formato de aniversário inválido no cadastro do membro."
    end

    local title = string.format("Aniversário de %s 🎂", cleanName)
    local desc = string.format("Festa de comemoração do aniversário de %s! Venha celebrar com a guilda.", cleanName)

    local event, err = self:createEvent(title, EventType.ANIVERSARIO, formattedDate, "20:00", desc)
    if not event then
        return nil, err
    end

    -- Adiciona o aniversariante aos convidados
    self:addInvitee(event:getId(), cleanName)

    -- Adiciona líder e oficiais se disponíveis e que ainda estão na guilda
    if self._memberService and self._memberService.getAllMembers then
        for _, otherMember in ipairs(self._memberService:getAllMembers()) do
            local otherInGuild = true
            if type(otherMember.isInGuild) == "function" then
                otherInGuild = otherMember:isInGuild()
            end
            if otherInGuild then
                local rankIndex = otherMember:getRankIndex()
                local rankName = (otherMember:getRankName() or ""):lower()
                local otherClean = otherMember:getName():match("^[^-]+") or otherMember:getName()
                if rankIndex == 0 or rankIndex == 1 or rankName:find("oficial") or rankName:find("officer") or rankName:find("lider") then
                    self:addInvitee(event:getId(), otherClean)
                end
            end
        end
    end

    return event, nil
end

_G.EventService = EventService
