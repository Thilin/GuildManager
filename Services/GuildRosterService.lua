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

    local activeMemberList = {}
    local activeRosterNames = {}
    local activeRosterGuids = {}
    local processedCount = 0

    for i = 1, numMembers do
        local member, rawCleanName, rawGuid = self:getAndProcessMember(i)
        if member then
            table.insert(activeMemberList, member)
            local cleanName = member:getName() or rawCleanName or ""
            local guid = member:getGuid() or rawGuid or ""

            if cleanName ~= "" then
                activeRosterNames[cleanName] = true
                activeRosterNames[cleanName:lower()] = true

                local baseName = cleanName:match("^[^-]+") or cleanName
                baseName = baseName:match("^%s*(.-)%s*$") or baseName
                if baseName ~= "" then
                    activeRosterNames[baseName] = true
                    activeRosterNames[baseName:lower()] = true
                end
            end

            if rawCleanName and rawCleanName ~= "" then
                activeRosterNames[rawCleanName] = true
                activeRosterNames[rawCleanName:lower()] = true
                local rawBase = rawCleanName:match("^[^-]+") or rawCleanName
                rawBase = rawBase:match("^%s*(.-)%s*$") or rawBase
                if rawBase ~= "" then
                    activeRosterNames[rawBase] = true
                    activeRosterNames[rawBase:lower()] = true
                end
            end

            if guid and guid ~= "" then
                activeRosterGuids[guid] = true
            end
            processedCount = processedCount + 1
        end
    end

    -- Reconcilia membros que saíram da guilda desde a última varredura
    if processedCount > 0 then
        self._activeMemberList = activeMemberList
        self._activeRosterNames = activeRosterNames
        self._activeRosterGuids = activeRosterGuids
        self._memberService:reconcileGuildMembers(activeRosterNames, activeRosterGuids)
        if _G.GM_DB then
            _G.GM_DB.rosterInitialized = true
        end
        local now = GetTime and GetTime() or 0
        if (now - (self._lastLogCleanTime or 0)) >= 300 then
            self._lastLogCleanTime = now
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
          _, guid = GetGuildRosterInfo(index)

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

    -- Resolve nome completo (com sobrenome) se disponível via GUID ou MemberService
    if guid and guid ~= "" and self._memberService and self._memberService.getMemberByGuid then
        local gm = self._memberService:getMemberByGuid(guid)
        if gm and gm:getName() and gm:getName():find("%s") then
            cleanName = gm:getName()
        end
    end
    if not cleanName:find("%s") and guid and UnitGUID and guid == UnitGUID("player") and self._memberService and self._memberService.resolvePlayerFullName then
        local myFull = self._memberService:resolvePlayerFullName()
        if myFull and myFull ~= "" and myFull:find("%s") then
            cleanName = myFull
        end
    end
    if not cleanName:find("%s") and self._memberService and self._memberService.resolveFullName then
        local resolved = self._memberService:resolveFullName(cleanName)
        if resolved and resolved ~= "" and resolved:find("%s") then
            cleanName = resolved
        end
    end

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
        guid = guid or "",
        isInGuild = true,
    }

    return self._memberService:processRosterMember(rosterData), cleanName, guid
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

--- Retorna a tabela hash dos GUIDs de membros ativos encontrados no último scan.
---@return table<string, boolean>|nil
function GuildRosterService:getActiveRosterGuids()
    return self._activeRosterGuids
end

--- Retorna a lista de entidades Member processadas diretamente do roster ativo da Blizzard.
---@return Member[]
function GuildRosterService:getActiveMemberList()
    return self._activeMemberList or {}
end

--- Verifica se o jogador local possui cargo de Oficial ou Líder da Guilda.
--- Considera:
--- 1. Líder da guilda nativo da Blizzard (IsGuildLeader).
--- 2. Permissão nativa da Blizzard para editar notas de oficial (CanEditOfficerNote).
--- 3. Cargo no roster nativo ou MemberService com rankIndex <= 1 ou nome contendo oficial/lider/mestre.
---@return boolean
function GuildRosterService:isPlayerOfficerOrLeader()
    if IsInGuild and not IsInGuild() then
        return false
    end

    -- 1. Líder da guilda nativo (Guild Master)
    if IsGuildLeader and IsGuildLeader() then
        return true
    end

    -- 2. Permissão nativa para notas de oficiais (benchmark de cargos de oficial no WoW)
    if CanEditOfficerNote and CanEditOfficerNote() then
        return true
    end
    if C_GuildInfo and C_GuildInfo.CanEditOfficerNote and C_GuildInfo.CanEditOfficerNote() then
        return true
    end

    -- 3. Verificação no banco de membros / roster local pelo nome do jogador
    local myName = UnitName and UnitName("player")
    if myName and myName ~= "" then
        local myClean = myName:match("^[^-]+") or myName
        myClean = myClean:match("^%s*(.-)%s*$") or myClean
        local myLower = myClean:lower()

        if self._memberService and self._memberService.getMember then
            local me = self._memberService:getMember(myClean)
            if me then
                local rIdx = me:getRankIndex()
                if rIdx and rIdx <= 1 then
                    return true
                end
                local rName = (me:getRankName() or ""):lower()
                if rName:find("oficial") or rName:find("officer") or rName:find("lider") or rName:find("líder") or rName:find("mestre") then
                    return true
                end
            end
        end

        local numMembers = GetNumGuildMembers and GetNumGuildMembers() or 0
        for i = 1, numMembers do
            local name, rankName, rankIndex = GetGuildRosterInfo(i)
            if name then
                local cName = name:match("^[^-]+") or name
                cName = cName:match("^%s*(.-)%s*$") or cName
                if cName:lower() == myLower then
                    if rankIndex and rankIndex <= 1 then
                        return true
                    end
                    local rLower = (rankName or ""):lower()
                    if rLower:find("oficial") or rLower:find("officer") or rLower:find("lider") or rLower:find("líder") or rLower:find("mestre") then
                        return true
                    end
                    break
                end
            end
        end
    end

    return false
end
