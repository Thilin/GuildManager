---@class WorldMapController
---@field private _memberService MemberService
---@field private _guildRosterService GuildRosterService
---@field private _worldMapView WorldMapView
---@field private _lastMapID number|nil
---@field private _updateTicker table|nil
---@field private _eventFrame table|nil
WorldMapController = {}
WorldMapController.__index = WorldMapController

--- Construtor do Controller do Mapa Mundi.
---@param memberService MemberService @Serviço de gerenciamento de membros
---@param guildRosterService GuildRosterService @Serviço de comunicação com o roster da Blizzard
---@param worldMapView WorldMapView @Camada de visualização no mapa nativo
---@return WorldMapController
function WorldMapController:new(memberService, guildRosterService, worldMapView)
    local instance = setmetatable({}, self)
    instance._memberService = memberService
    instance._guildRosterService = guildRosterService
    instance._worldMapView = worldMapView
    instance._lastMapID = nil
    instance._updateTicker = nil
    instance._eventFrame = nil

    return instance
end

--- Normaliza strings para comparação (remove acentos, espaços extras e caixa alta).
---@param str string|nil
---@return string
local function cleanString(str)
    if not str or str == "" then return "" end
    local s = str:lower():match("^%s*(.-)%s*$") or ""
    s = s:gsub("á", "a"):gsub("à", "a"):gsub("â", "a"):gsub("ã", "a"):gsub("ä", "a")
    s = s:gsub("é", "e"):gsub("è", "e"):gsub("ê", "e"):gsub("ë", "e")
    s = s:gsub("í", "i"):gsub("ì", "i"):gsub("î", "i"):gsub("ï", "i")
    s = s:gsub("ó", "o"):gsub("ò", "o"):gsub("ô", "o"):gsub("õ", "o"):gsub("ö", "o")
    s = s:gsub("ú", "u"):gsub("ù", "u"):gsub("û", "u"):gsub("ü", "u")
    s = s:gsub("ç", "c")
    return s
end

--- Obtém o ID do mapa atual exibido no WorldMapFrame nativo.
---@return number|nil
function WorldMapController:getCurrentMapID()
    if WorldMapFrame and WorldMapFrame.GetMapID then
        local id = WorldMapFrame:GetMapID()
        if id and id > 0 then return id end
    end
    if C_Map and C_Map.GetBestMapForUnit then
        local id = C_Map.GetBestMapForUnit("player")
        if id and id > 0 then return id end
    end
    if GetCurrentMapAreaID then
        local id = GetCurrentMapAreaID()
        if id and id > 0 then return id end
    end
    return nil
end

--- Obtém o nome legível da região do mapa visualizado.
---@param mapID number|nil
---@return string
function WorldMapController:getCurrentMapName(mapID)
    if not mapID then
        mapID = self:getCurrentMapID()
    end
    if mapID and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(mapID)
        if info and info.name and info.name ~= "" then
            return info.name
        end
    end
    if GetRealZoneText then
        local z = GetRealZoneText()
        if z and z ~= "" then return z end
    end
    if GetZoneText then
        local z = GetZoneText()
        if z and z ~= "" then return z end
    end
    return "Região Atual"
end

--- Inicializa os ganchos com a interface do WorldMapFrame da Blizzard e eventos.
function WorldMapController:initHooks()
    if not WorldMapFrame then
        return
    end

    -- Vincula callbacks da View
    self._worldMapView:setOnScanCallback(function()
        if self._guildRosterService and self._guildRosterService.requestRosterUpdate then
            self._guildRosterService:requestRosterUpdate()
        end
        self:scanCurrentZone()
    end)

    self._worldMapView:setOnMemberClickCallback(function(memberData)
        if memberData and memberData.name then
            ChatFrame_OpenChat("/w " .. memberData.name .. " ")
        end
    end)

    -- Hook do WorldMapFrame OnShow: inicializa UI, exibe o painel e varre os membros da região
    WorldMapFrame:HookScript("OnShow", function()
        self._worldMapView:initWorldMapUI()
        self._worldMapView:showPanel()
        self:scanCurrentZone()
        self:startPeriodicUpdate()

        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, function()
                if WorldMapFrame and WorldMapFrame:IsShown() then
                    self:scanCurrentZone()
                end
            end)
        end
    end)

    -- Hook do WorldMapFrame OnHide: interrompe atualizações periódicas e garante limpeza de pinos
    WorldMapFrame:HookScript("OnHide", function()
        self:stopPeriodicUpdate()
        self._worldMapView:clearPins()
    end)

    -- Frame de eventos para monitorar atualizações de mapa e roster da guilda
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    pcall(function() eventFrame:RegisterEvent("WORLD_MAP_UPDATE") end)

    eventFrame:SetScript("OnEvent", function(_, event)
        if WorldMapFrame and WorldMapFrame:IsShown() then
            self:scanCurrentZone()
        end
    end)

    self._eventFrame = eventFrame

    -- Inicializa a UI caso o mapa já esteja visível
    if WorldMapFrame:IsShown() then
        self._worldMapView:initWorldMapUI()
        self._worldMapView:showPanel()
        self:scanCurrentZone()
    end
end

--- Inicia o timer de atualização enquanto o WorldMapFrame estiver aberto.
function WorldMapController:startPeriodicUpdate()
    if self._updateTicker then return end

    if C_Timer and C_Timer.NewTicker then
        self._updateTicker = C_Timer.NewTicker(3.0, function()
            if WorldMapFrame and WorldMapFrame:IsShown() then
                self:scanCurrentZone()
            else
                self:stopPeriodicUpdate()
            end
        end)
    end
end

--- Interrompe o timer de atualização.
function WorldMapController:stopPeriodicUpdate()
    if self._updateTicker then
        self._updateTicker:Cancel()
        self._updateTicker = nil
    end
end

--- Varre e filtra os membros da guilda presentes no mapa/região atual sem exibir coordenadas.
function WorldMapController:scanCurrentZone()
    local currentMapID = self:getCurrentMapID()
    local currentMapName = self:getCurrentMapName(currentMapID)
    self._lastMapID = currentMapID

    local cleanCurrentMap = cleanString(currentMapName)
    local regionMembers = {}
    local addedByName = {}

    -- Identificação do jogador local
    local myGUID = UnitGUID("player")
    local myName = UnitName("player") or ""
    local myFirstName = myName:match("^(%S+)") or myName
    local cleanMyName = cleanString(myName)
    local cleanMyFirst = cleanString(myFirstName)

    local function registerAddedName(name)
        if not name or name == "" then return end
        local lower = name:lower()
        addedByName[lower] = true
        local clean = cleanString(name)
        if clean ~= "" then addedByName[clean] = true end
        local first = name:match("^(%S+)")
        if first then
            addedByName[first:lower()] = true
            local cleanF = cleanString(first)
            if cleanF ~= "" then addedByName[cleanF] = true end
        end
    end

    local function isLocalPlayer(name, guid)
        if guid and myGUID and guid == myGUID then
            return true
        end
        if not name or name == "" then return false end
        local cName = cleanString(name)
        if cName == cleanMyName or cName == cleanMyFirst then
            return true
        end
        local cFirst = cName:match("^(%S+)")
        if cFirst and (cFirst == cleanMyName or cFirst == cleanMyFirst) then
            return true
        end
        return false
    end

    -- Obter todos os membros do roster da guilda
    local allRosterMembers = self._memberService:getAllMembers()
    local myMember = nil
    for _, m in ipairs(allRosterMembers) do
        if isLocalPlayer(m:getName(), m:getGuid()) then
            myMember = m
            break
        end
    end

    registerAddedName(myName)
    registerAddedName(myFirstName)
    if myMember then
        registerAddedName(myMember:getName())
    end

    -- 1. Verifica se o jogador local está na região visualizada no mapa
    local myZone = GetRealZoneText() or GetZoneText() or ""
    local cleanMyZone = cleanString(myZone)
    local isLocalInZone = false

    if cleanCurrentMap ~= "" and cleanMyZone ~= "" then
        if cleanCurrentMap == cleanMyZone
            or cleanCurrentMap:find(cleanMyZone, 1, true)
            or cleanMyZone:find(cleanCurrentMap, 1, true) then
            isLocalInZone = true
        end
    elseif cleanCurrentMap == "" then
        isLocalInZone = true
    end

    if isLocalInZone and myName ~= "" then
        local _, unitClassToken = UnitClass("player")
        local displayName = (myMember and myMember:getName() and myMember:getName() ~= "") and myMember:getName() or myName
        local myRank = myMember and myMember:getRankName()
        local rankDisplay = (myRank and myRank ~= "") and (myRank .. " (Você)") or "Você"
        local myLevel = (myMember and myMember:getLevel() and myMember:getLevel() > 0) and myMember:getLevel() or (UnitLevel("player") or 1)
        local myClass = (myMember and myMember:getClass() and myMember:getClass() ~= "") and myMember:getClass() or (unitClassToken or "")
        local myClassDisplay = (myMember and myMember:getClassDisplayName() and myMember:getClassDisplayName() ~= "") and myMember:getClassDisplayName() or (UnitClass("player") or "")

        local myData = {
            name = displayName,
            level = myLevel,
            class = myClass,
            classDisplayName = myClassDisplay,
            rankName = rankDisplay,
            publicNote = myMember and myMember:getPublicNote() or "",
            officerNote = myMember and myMember:getOfficerNote() or "",
            zone = myZone,
            isOnline = true,
            isSelf = true,
        }
        table.insert(regionMembers, myData)
        registerAddedName(displayName)
    end

    -- 2. Membros online da guilda cuja zona no Roster coincide com a região visualizada
    for _, m in ipairs(allRosterMembers) do
        local mName = m:getName()
        local lowerName = mName:lower()
        local cleanMName = cleanString(mName)

        if not isLocalPlayer(mName, m:getGuid())
            and not addedByName[lowerName]
            and not addedByName[cleanMName]
            and m:isInGuild()
            and m:isOnline() then

            local mZone = cleanString(m:getZone())
            local match = false

            if mZone ~= "" and cleanCurrentMap ~= "" then
                if mZone == cleanCurrentMap then
                    match = true
                elseif cleanCurrentMap:find(mZone, 1, true) or mZone:find(cleanCurrentMap, 1, true) then
                    match = true
                end
            end

            if match then
                local data = {
                    name = m:getName(),
                    level = m:getLevel(),
                    class = m:getClass(),
                    classDisplayName = m:getClassDisplayName(),
                    rankName = m:getRankName(),
                    publicNote = m:getPublicNote(),
                    officerNote = m:getOfficerNote(),
                    zone = m:getZone(),
                    isOnline = true,
                    isSelf = false,
                }
                table.insert(regionMembers, data)
                registerAddedName(mName)
            end
        end
    end

    -- Ordenação: Jogador local primeiro, depois por nível decrescente, depois por nome alfabético
    table.sort(regionMembers, function(a, b)
        if a.isSelf then return true end
        if b.isSelf then return false end
        if (a.level or 0) ~= (b.level or 0) then
            return (a.level or 0) > (b.level or 0)
        end
        return (a.name or ""):lower() < (b.name or ""):lower()
    end)

    -- Atualiza a View do Mapa apenas com a lista de membros na região
    self._worldMapView:renderMembers(regionMembers, currentMapName)
end
