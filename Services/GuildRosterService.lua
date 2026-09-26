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
    local processedCount = 0

    for i = 1, numMembers do
        local member = self:getAndProcessMember(i)
        if member then
            local cleanName = member:getName()
            activeRosterNames[cleanName] = true
            activeRosterNames[cleanName:lower()] = true
            processedCount = processedCount + 1
        end
    end

    -- Reconcilia membros que saíram da guilda desde a última varredura
    if processedCount > 0 then
        self._memberService:reconcileGuildMembers(activeRosterNames)
        if _G.GM_DB then
            _G.GM_DB.rosterInitialized = true
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
        isOnline = (isOnline == true),
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
