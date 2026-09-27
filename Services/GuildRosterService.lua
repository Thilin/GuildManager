---@class GuildRosterService
---@field private _memberService MemberService
GuildRosterService = {}
GuildRosterService.__index = GuildRosterService

--- Construtor do serviço de comunicação com a API de Guilda da Blizzard.
---@param memberService MemberService @Instância do serviço de membros
---@return GuildRosterService
function GuildRosterService:new(memberService)
    local instance = setmetatable({}, self)
    instance._memberService = memberService
    return instance
end

--- Solicita à Blizzard a atualização do roster da guilda via servidor.
---@return boolean @Retorna true se a requisição foi enviada
function GuildRosterService:requestRosterUpdate()
    if not IsInGuild or not IsInGuild() then
        return false
    end

    -- No WoW Classic 1.15, GuildRoster() é o método principal
    if GuildRoster then
        GuildRoster()
    end

    if C_GuildInfo and C_GuildInfo.GuildRoster then
        pcall(C_GuildInfo.GuildRoster)
    end

    return true
end

--- Varre todos os membros do roster da guilda através da API da Blizzard,
--- transformando os dados recebidos em entidades Member persistidas pelo MemberService.
---@return number @Quantidade de membros processados com sucesso
function GuildRosterService:scanRoster()
    if not IsInGuild or not IsInGuild() then
        return 0
    end

    -- Garante que membros offline também sejam listados pela API
    if SetGuildRosterShowOffline and GetGuildRosterShowOffline and not GetGuildRosterShowOffline() then
        SetGuildRosterShowOffline(true)
    end

    local numMembers = GetNumGuildMembers and GetNumGuildMembers() or 0
    if numMembers == 0 then
        return 0
    end

    local activeRosterNames = {}
    local activeRosterGuids = {}
    local processedCount = 0

    for i = 1, numMembers do
        local member = self:getAndProcessMember(i)
        if member then
            local cleanName = member:getName()
            activeRosterNames[cleanName] = true
            activeRosterNames[cleanName:lower()] = true
            local guid = member:getGuid()
            if guid and guid ~= "" then
                activeRosterGuids[guid] = true
            end
            processedCount = processedCount + 1
        end
    end

    -- Reconcilia membros que saíram da guilda desde a última varredura
    if processedCount > 0 then
        self._activeRosterNames = activeRosterNames
        self._memberService:reconcileGuildMembers(activeRosterNames, activeRosterGuids)
        if _G.GM_DB then
            _G.GM_DB.rosterInitialized = true
        end
        if _G.GM and _G.GM.logService then
            if _G.GM.logService.cleanInvalidInviteJoinedLogs then
                _G.GM.logService:cleanInvalidInviteJoinedLogs(self._memberService)
            end
            if _G.GM.logService.cleanInvalidLeftLogs then
                _G.GM.logService:cleanInvalidLeftLogs(self._memberService, activeRosterNames)
            end
            if _G.GM.logService.cleanInvertedKickLogs then
                _G.GM.logService:cleanInvertedKickLogs(self._memberService)
            end
        end
    end

    return processedCount
end

--- Obtém os dados de um membro específico pelo índice do roster da guilda,
--- processa através do MemberService e retorna a entidade Member pronta e salva.
---@param index number @Índice do membro no GetGuildRosterInfo
---@return Member|nil
function GuildRosterService:getAndProcessMember(index)
    if not index or index <= 0 or not GetGuildRosterInfo then
        return nil
    end

    local name, rankName, rankIndex, level, classDisplayName, zone,
          publicNote, officerNote, isOnline, status, class,
          achievementPoints, achievementRank, isMobile, canSoR,
          repStanding, guid = GetGuildRosterInfo(index)

    if not name or name == "" then
        return nil
    end

    local cleanName = name
    if Ambiguate then
        local amb = Ambiguate(name, "none")
        if amb and amb ~= "" then
            if not (name:find("%s") and not amb:find("%s")) then
                cleanName = amb
            end
        end
    end
    cleanName = cleanName:match("^[^-]+") or cleanName
    cleanName = cleanName:match("^%s*(.-)%s*$") or cleanName

    local race = ""
    if guid and guid ~= "" and GetPlayerInfoByGUID then
        local _, _, locRace = GetPlayerInfoByGUID(guid)
        if locRace and locRace ~= "" then
            race = locRace
        end
    end

    local isOnlineBool = (isOnline == true)
    local lastOnlineText = ""
    if not isOnlineBool then
        local years, months, days, hours = 0, 0, 0, 0
        if GetGuildRosterLastOnline then
            years, months, days, hours = GetGuildRosterLastOnline(index)
        elseif C_GuildInfo and C_GuildInfo.GetGuildRosterLastOnline then
            years, months, days, hours = C_GuildInfo.GetGuildRosterLastOnline(index)
        end
        lastOnlineText = self:formatLastOnline(years, months, days, hours)
    end

    local rosterData = {
        name = cleanName,
        race = race,
        raceID = race,
        rankName = rankName or "",
        rankIndex = rankIndex or 0,
        level = level or 1,
        classDisplayName = classDisplayName or "",
        zone = zone or "",
        publicNote = publicNote or "",
        officerNote = officerNote or "",
        isOnline = isOnlineBool,
        lastOnline = lastOnlineText,
        status = status or 0,
        class = class or "",
        achievementPoints = achievementPoints or 0,
        achievementRank = achievementRank or 0,
        repStanding = repStanding or 0,
        guid = guid or "",
        isInGuild = true,
    }

    return self._memberService:processRosterMember(rosterData)
end

--- Formata o tempo decorrido desde a última vez que o membro esteve online.
---@param years number|nil
---@param months number|nil
---@param days number|nil
---@param hours number|nil
---@return string
function GuildRosterService:formatLastOnline(years, months, days, hours)
    years = tonumber(years) or 0
    months = tonumber(months) or 0
    days = tonumber(days) or 0
    hours = tonumber(hours) or 0

    if years > 0 then
        return string.format(years == 1 and "%d ano atrás" or "%d anos atrás", years)
    elseif months > 0 then
        return string.format(months == 1 and "%d mês atrás" or "%d meses atrás", months)
    elseif days > 0 then
        return string.format(days == 1 and "%d d atrás" or "%d d atrás", days)
    elseif hours > 0 then
        return string.format(hours == 1 and "%d h atrás" or "%d h atrás", hours)
    else
        return "< 1 hora"
    end
end

--- Retorna a tabela hash de nomes de membros ativos encontrados no último scan.
---@return table<string, boolean>|nil
function GuildRosterService:getActiveRosterNames()
    return self._activeRosterNames
end
