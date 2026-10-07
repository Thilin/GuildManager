---@class AgendaController
---@field private _eventService EventService
---@field private _memberService MemberService
---@field private _guildRosterService GuildRosterService
---@field private _agendaView AgendaView
AgendaController = {}
AgendaController.__index = AgendaController

--- Construtor do Controller de gerenciamento da agenda da guilda.
---@param eventService EventService @Serviço de gerenciamento de eventos e agenda
---@param memberService MemberService @Serviço de membros da guilda
---@param guildRosterService GuildRosterService @Serviço de integração com o Roster da Blizzard
---@param agendaView AgendaView @Camada de visualização da agenda
---@return AgendaController
function AgendaController:new(eventService, memberService, guildRosterService, agendaView)
    local instance = setmetatable({}, self)

    instance._eventService = eventService
    instance._memberService = memberService
    instance._guildRosterService = guildRosterService
    instance._agendaView = agendaView

    return instance
end

--- Inicializa os ganchos da View e comandos de barra (/gmagenda, /gmeventos).
function AgendaController:initHooks()
    if not self._agendaView then return end

    -- Callback de atualização da View
    if self._agendaView.setOnRefreshCallback then
        self._agendaView:setOnRefreshCallback(function()
            self:refreshAgenda()
        end)
    end

    -- Callback de criação de evento
    if self._agendaView.setOnCreateEventCallback then
        self._agendaView:setOnCreateEventCallback(function(title, eventType, dateStr, timeStr, desc)
            if not self._eventService then return false, "Serviço de agenda indisponível." end
            local event, err = self._eventService:createEvent(title, eventType, dateStr, timeStr, desc)
            if event then
                self:refreshAgenda()
                return true, nil
            end
            return false, err
        end)
    end

    -- Callback de atualização de evento
    if self._agendaView.setOnUpdateEventCallback then
        self._agendaView:setOnUpdateEventCallback(function(id, title, eventType, dateStr, timeStr, desc)
            if not self._eventService then return false, "Serviço de agenda indisponível." end
            local event, err = self._eventService:updateEvent(id, title, eventType, dateStr, timeStr, desc)
            if event then
                self:refreshAgenda()
                return true, nil
            end
            return false, err
        end)
    end

    -- Callback de exclusão de evento
    if self._agendaView.setOnDeleteEventCallback then
        self._agendaView:setOnDeleteEventCallback(function(id)
            if not self._eventService then return false end
            local ok = self._eventService:deleteEvent(id)
            if ok then
                self:refreshAgenda()
            end
            return ok
        end)
    end

    -- Callback de adicionar convidado ao evento
    if self._agendaView.setOnAddInviteeCallback then
        self._agendaView:setOnAddInviteeCallback(function(eventId, memberName)
            if not self._eventService then return false, "Serviço de agenda indisponível." end
            local ok, err = self._eventService:addInvitee(eventId, memberName)
            if ok then
                self:refreshAgenda()
                return true, nil
            end
            return false, err
        end)
    end

    -- Callback de remover convidado do evento
    if self._agendaView.setOnRemoveInviteeCallback then
        self._agendaView:setOnRemoveInviteeCallback(function(eventId, memberName)
            if not self._eventService then return false end
            local ok = self._eventService:removeInvitee(eventId, memberName)
            if ok then
                self:refreshAgenda()
            end
            return ok
        end)
    end

    -- Callback de convite individual in-game (grupo WoW)
    if self._agendaView.setOnInviteMemberInGameCallback then
        self._agendaView:setOnInviteMemberInGameCallback(function(memberName)
            if not self._eventService then return false, "Serviço de agenda indisponível." end
            return self._eventService:inviteMemberInGame(memberName)
        end)
    end

    -- Callback de convite coletivo de membros online in-game
    if self._agendaView.setOnInviteAllOnlineCallback then
        self._agendaView:setOnInviteAllOnlineCallback(function(eventId)
            if not self._eventService then return 0, 0 end
            return self._eventService:inviteAllOnlineMembers(eventId)
        end)
    end

    -- Callback de agendar aniversário a partir do card de aniversariantes
    if self._agendaView.setOnCreateBirthdayEventCallback then
        self._agendaView:setOnCreateBirthdayEventCallback(function(member)
            if not self._eventService then return end
            local event, err = self._eventService:createBirthdayEventForMember(member)
            if event then
                print(string.format("|cff00ff00[GuildManager]|r Evento de comemoração criado com sucesso para |cffffd200%s|r!", member:getName()))
                self:refreshAgenda()
            else
                print(string.format("|cffff4444[GuildManager]|r %s", err or "Falha ao criar evento de aniversário."))
            end
        end)
    end

    -- Monitora entrada no mundo para notificar sobre aniversários e eventos do dia
    local loginFrame = CreateFrame("Frame")
    loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    loginFrame:SetScript("OnEvent", function(frame)
        frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        if C_Timer and C_Timer.After then
            C_Timer.After(4.0, function()
                if not IsInGuild or not IsInGuild() then return end
                self:checkLoginNotifications()
            end)
        end
    end)

    -- Comandos de chat /gmagenda, /gmeventos, /gmevento, /gmaniversarios
    SLASH_GUILDMANAGERAGENDA1 = "/gmagenda"
    SLASH_GUILDMANAGERAGENDA2 = "/gmeventos"
    SLASH_GUILDMANAGERAGENDA3 = "/gmevento"
    SLASH_GUILDMANAGERAGENDA4 = "/gmaniversarios"
    SlashCmdList["GUILDMANAGERAGENDA"] = function()
        self:toggle()
    end
end

--- Verifica e envia notificações no chat local ao conectar sobre aniversariantes e eventos de hoje.
function AgendaController:checkLoginNotifications()
    if not _G.GM or not _G.GM.settingsService then return end
    local settingsService = _G.GM.settingsService

    -- 1. Aniversariantes de hoje
    if settingsService:get("notifyBirthdaysOnLogin") ~= false and self._eventService and self._eventService.getUpcomingBirthdays then
        local bdays = self._eventService:getUpcomingBirthdays(1) or {}
        local todayList = {}
        for _, b in ipairs(bdays) do
            if b.daysUntil == 0 then
                table.insert(todayList, "|cffffd200" .. (b.cleanName or b.name) .. "|r")
            end
        end
        if #todayList > 0 then
            print(string.format("|cff00ff00[GuildManager]|r 🎂 |cffffd200Aniversário Hoje:|r %s está fazendo aniversário! Dê os parabéns!", table.concat(todayList, ", ")))
        end
    end

    -- 2. Eventos agendados para hoje
    if settingsService:get("notifyUpcomingEvents") ~= false and self._eventService and self._eventService.getAllEvents then
        local allEvents = self._eventService:getAllEvents() or {}
        local curDate = (date and date("*t")) or (os and os.date and os.date("*t")) or { year = 2026, month = 10, day = 6 }
        local todayStr = string.format("%02d/%02d/%04d", curDate.day or 1, curDate.month or 1, curDate.year or 2026)
        local todayEvents = {}
        for _, ev in ipairs(allEvents) do
            if ev:getDate() == todayStr then
                local timeDisplay = ev:getTime() and ev:getTime() ~= "" and (" às " .. ev:getTime()) or ""
                table.insert(todayEvents, string.format("|cffffd200%s|r (%s%s)", ev:getTitle(), ev:getType() or "Evento", timeDisplay))
            end
        end
        if #todayEvents > 0 then
            print(string.format("|cff00ff00[GuildManager]|r 📅 |cffffd200Eventos da Guilda Hoje:|r %s", table.concat(todayEvents, ", ")))
        end
    end
end

--- Atualiza os eventos e a lista de aniversariantes carregados na View.
function AgendaController:refreshAgenda()
    if not self._agendaView then return end

    if IsInGuild and IsInGuild() then
        if self._guildRosterService and self._guildRosterService.scanRoster then
            self._guildRosterService:scanRoster()
        end
    end

    -- 1. Carrega todos os eventos ordenados
    local events = {}
    if self._eventService and self._eventService.getAllEvents then
        events = self._eventService:getAllEvents() or {}
    end
    self._agendaView:setEvents(events)

    -- 2. Carrega lista de próximos aniversariantes ordenada
    local birthdays = {}
    if self._eventService and self._eventService.getUpcomingBirthdays then
        birthdays = self._eventService:getUpcomingBirthdays() or {}
    end
    self._agendaView:setUpcomingBirthdays(birthdays)

    -- 3. Carrega lista de membros ativos da guilda para buscas e convites
    local guildMembers = {}
    if self._memberService and self._memberService.getAllMembers then
        local all = self._memberService:getAllMembers() or {}
        for _, m in ipairs(all) do
            if m:isInGuild() then
                table.insert(guildMembers, m)
            end
        end
    end
    if self._agendaView.setGuildMembers then
        self._agendaView:setGuildMembers(guildMembers)
    end
end

--- Abre a janela da agenda da guilda.
function AgendaController:show()
    if not IsInGuild or not IsInGuild() then
        print("|cffff0000[GuildManager]|r Você não está em uma guilda.")
        return
    end

    self:refreshAgenda()
    if self._agendaView then
        self._agendaView:show()
    end
end

--- Oculta a janela da agenda da guilda.
function AgendaController:hide()
    if self._agendaView then
        self._agendaView:hide()
    end
end

--- Alterna a visibilidade da janela da agenda.
function AgendaController:toggle()
    if not self._agendaView then return end

    if self._agendaView:isShown() then
        self:hide()
    else
        self:show()
    end
end

_G.AgendaController = AgendaController
