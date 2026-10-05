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

--- Dicionário de regiões, cidades e instâncias por continente do World of Warcraft (PT e EN).
local CONTINENT_ZONES = {
    eastern_kingdoms = {
        -- Floresta de Elwynn
        "floresta de elwynn", "elwynn forest", "elwynn", "vale norte", "northshire", "vila d'ouro", "goldshire", "azora", "brackwell",
        -- Cerro Oeste
        "cerro oeste", "westfall", "morro da sentinela", "sentinel hill", "riacho da lua", "moonbrook", "costa dourada", "gold coast",
        -- Montanhas Cristarrubra
        "montanhas cristarrubra", "cristarrubra", "redridge mountains", "redridge", "vila do lago", "lakeshire", "pedra vigia", "stonewatch",
        -- Floresta do Crepúsculo
        "floresta do crepusculo", "crepusculo", "duskwood", "vila sombria", "darkshire", "colina dos corvos", "raven hill",
        -- Loch Modan
        "loch modan", "thelsamar",
        -- Dun Morogh
        "dun morogh", "kharanos", "vale de cristalgida", "coldridge valley", "grilloferreo",
        -- Pantanal
        "pantanal", "wetlands", "porto de menethil", "menethil harbor", "menethil", "whelgar",
        -- Planalto de Arathi
        "planalto de arathi", "arathi highlands", "arathi", "refugio", "refuge pointe", "ruina do martelo", "hammerfall",
        -- Contrafortes de Eira dos Montes
        "contrafortes de eira dos montes", "eira dos montes", "hillsbrad foothills", "hillsbrad", "costasul", "southshore", "moinho de tarren", "tarren mill", "durnholde",
        -- Montanhas de Alterac
        "montanhas de alterac", "alterac mountains", "alterac",
        -- Terras Agrestes
        "terras agrestes", "badlands", "kargath",
        -- Pântano das Mágoas
        "pantano das magoas", "swamp of sorrows", "pedregal", "stonard",
        -- Barreira do Inferno
        "barreira do inferno", "blasted lands", "nethergarde", "forte esmagamento",
        -- Garganta de Fogo
        "garganta de fogo", "searing gorge", "vigilia do torio", "thorium point",
        -- Estepes Ardentes
        "estepes ardentes", "burning steppes", "vigilia da morgan", "morgan's vigil", "flame crest",
        -- Terras Pestilentas Ocidentais
        "terras pestilentas ocidentais", "western plaguelands", "plaguelands", "andorhal",
        -- Terras Pestilentas Orientais
        "terras pestilentas orientais", "eastern plaguelands", "capela esperanca da luz", "light's hope chapel", "tyr's hand",
        -- Clareiras de Tirisfal
        "clareiras de tirisfal", "tirisfal glades", "tirisfal", "brill", "plangente", "deathknell",
        -- Floresta de Pinho de Prata
        "floresta de pinho de prata", "pinho de prata", "silverpine forest", "silverpine", "o sepulcro", "the sepulcher", "pirobrasa", "pyrewood",
        -- Selva do Espinhaço / Vale do Espinhaço
        "selva do espinhaco", "vale do espinhaco", "espinhaco", "stranglethorn vale", "stranglethorn", "angra do butim", "booty bay", "grom'gol", "gromgol", "cabo do espinhaco", "the cape of stranglethorn", "selva de espinhaco setentrional", "northern stranglethorn",
        -- Passagem de Ventomorto
        "passagem de ventomorto", "deadwind pass",
        -- TBC / expansões nos Reinos do Leste
        "floresta de petramargem", "eversong woods", "terra fantasma", "ghostlands", "tranquillien", "ilha de quel'danas", "isle of quel'danas", "terras altas do crepusculo", "twilight highlands",
        -- Capitais
        "cidade de ventobravo", "ventobravo", "stormwind city", "stormwind",
        "altaforja", "ironforge",
        "cidade baixa", "undercity",
        "luaprata", "cidade de luaprata", "silvermoon city", "silvermoon",
        -- Masmorras e Raides
        "minas mortas", "deadmines",
        "masmorras de ventobravo", "the stockade", "carcere de ventobravo", "stockade",
        "gnomeregan",
        "monasterio escarlate", "scarlet monastery",
        "bastilha da presa negra", "shadowfang keep",
        "uldaman",
        "templo de atal'hakkar", "sunken temple", "templo submerso",
        "abobadas negras", "blackrock depths", "cavernas da rocha negra", "brd",
        "pico da rocha negra", "blackrock spire", "brs", "lbrs", "ubrs",
        "nucleo derretido", "molten core",
        "covil asa negra", "blackwing lair", "bwl",
        "stratholme", "strat",
        "scolomantia", "scholomance", "scholo",
        "zul'gurub", "zg",
        "karazhan",
        "naxxramas", "naxx",
        -- Campos de Batalha
        "vale de alterac", "alterac valley", "av",
        "bacia arathi", "arathi basin", "ab",
    },
    kalimdor = {
        -- Durotar
        "durotar", "monte navalha", "razor hill", "vale dos desafios", "valley of trials", "sen'jin",
        -- Os Sertões
        "os sertoes", "sertoes", "sertao", "the barrens", "barrens", "encruzilhada", "the crossroads", "crossroads", "catraca", "ratchet", "taurajo", "sertoes setentrionais", "northern barrens", "sertoes meridionais", "southern barrens",
        -- Mulgore
        "mulgore", "aldeia casco sangrento", "bloodhoof village", "mesa vermelha", "red cloud mesa",
        -- Teldrassil
        "teldrassil", "dolanaar", "varzea das sombras", "shadowglen",
        -- Costa Negra
        "costa negra", "darkshore", "auberdine",
        -- Vale Gris
        "vale gris", "ashenvale", "astranaar", "splintertree",
        -- Cordilheira das Pedras Altas
        "cordilheira das pedras altas", "pedras altas", "stonetalon mountains", "stonetalon", "sol-pedra", "sun rock",
        -- Desolação
        "desolacao", "desolace", "nijel",
        -- Pântano Vulpino
        "pantano vulpino", "dustwallow marsh", "dustwallow", "theramore", "brackenwall",
        -- Feralas
        "feralas", "plumaluna", "feathermoon", "mojache",
        -- Mil Agulhas
        "mil agulhas", "thousand needles", "pista de corrida cintilante", "shimmering flats", "vento livre", "freewind post",
        -- Tanaris
        "tanaris", "geringotz", "gadgetzan", "porto de bondebico", "steamwheedle port",
        -- Cratera de Un'Goro
        "cratera de un'goro", "un'goro crater", "un'goro", "ungoro",
        -- Silithus
        "silithus", "forte cenariano", "cenarion hold",
        -- Hibérnia
        "hibernia", "winterspring", "visteterna", "everlook",
        -- Clareira da Lua
        "clareira da lua", "moonglade", "nighthaven",
        -- Mata Malevolente
        "mata malevolente", "felwood",
        -- Azshara
        "azshara", "valormok",
        -- Ilhas Draenei
        "ilha nevoa lazuli", "azuremyst isle", "azuremyst", "ilha nevoa sangrenta", "bloodmyst isle", "bloodmyst",
        -- Capitais
        "orgrimmar",
        "penhasco do trovao", "thunder bluff",
        "darnassus",
        "exodar", "o exodar",
        -- Masmorras e Raides
        "cavernas do braseiro", "ragefire chasm", "rfc",
        "cavernas dos lamentos", "wailing caverns", "wc",
        "profundezas negras", "blackfathom deeps", "bfd",
        "coroa dos espinhos", "razorfen kraul", "rfk",
        "labirinto dos espinhos", "razorfen downs", "rfd",
        "zul'farrak", "zf",
        "maraudon", "mara",
        "glug-glug", "dire maul", "dm",
        "ruinas de ahn'qiraj", "ruins of ahn'qiraj", "aq20",
        "templo de ahn'qiraj", "templo de ahnqiraj", "temple of ahn'qiraj", "aq40",
        "covil de onyxia", "onyxia's lair", "onyxia",
        -- Campos de Batalha
        "ravina brado guerreiro", "warsong gulch", "wsg",
    },
    outland = {
        "terralem", "outland",
        "peninsula fogo do inferno", "hellfire peninsula", "hellfire",
        "pantano zingaro", "zangarmarsh",
        "mata terokkar", "terokkar forest", "terokkar",
        "nagrand",
        "montanhas da lamina afiada", "blade's edge mountains", "blade's edge",
        "vale da lua negra", "shadowmoon valley", "shadowmoon",
        "eternevoa", "netherstorm",
        "shattrath", "cidade de shattrath", "shattrath city",
    },
    northrend = {
        "nortundria", "northrend",
        "fiorde uivante", "howling fjord",
        "tundra boreana", "borean tundra",
        "ermo das serpentes", "dragonblight",
        "colinas pardas", "grizzly hills",
        "zul'drak", "zuldrak",
        "bacia sholazar", "sholazar basin", "sholazar",
        "picos tempestuosos", "the storm peaks", "storm peaks",
        "coroa de gelo", "icecrown",
        "floresta do canto cristalino", "crystalsong forest",
        "conquista do inverno", "wintergrasp",
        "dalaran",
    }
}

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

--- Obtém o nome legível da região ou continente do mapa visualizado.
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

--- Verifica se a zona do membro pertence à região, continente ou mundo visualizado no mapa.
---@param memberZone string|nil
---@param currentMapName string
---@param currentMapID number|nil
---@return boolean, boolean, boolean @matches, isContinent, isWorld
function WorldMapController:isZoneMatch(memberZone, currentMapName, currentMapID)
    local cleanCurrent = cleanString(currentMapName)
    local cleanMZone = cleanString(memberZone)

    -- 1. Determina o tipo de mapa (Mundo, Continente ou Zona)
    local mapInfo = currentMapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(currentMapID)
    local mapType = mapInfo and mapInfo.mapType

    local isWorld = false
    local isContinent = false
    local continentKey = nil

    -- Detecção de Mundo / Azeroth / Cósmico
    if mapType == 0 or mapType == 1 or currentMapID == 947 or currentMapID == 946
        or cleanCurrent == "azeroth" or cleanCurrent == "mundo" or cleanCurrent == "world" then
        isWorld = true
    -- Detecção de Continente
    elseif mapType == 2
        or currentMapID == 1415 or currentMapID == 1414 or currentMapID == 1945 or currentMapID == 113
        or cleanCurrent:find("reinos do leste", 1, true) or cleanCurrent:find("eastern kingdoms", 1, true)
        or cleanCurrent:find("kalimdor", 1, true)
        or cleanCurrent:find("terralem", 1, true) or cleanCurrent:find("outland", 1, true)
        or cleanCurrent:find("nortundria", 1, true) or cleanCurrent:find("northrend", 1, true) then
        isContinent = true
    end

    if cleanMZone == "" then
        return false, isContinent, isWorld
    end

    -- Se for visão global do Mundo: qualquer membro online na guilda é considerado presente
    if isWorld then
        return true, false, true
    end

    -- Se for visão de Continente: identifica qual continente está sendo visualizado
    if isContinent then
        if currentMapID == 1415 or cleanCurrent:find("reinos do leste", 1, true) or cleanCurrent:find("eastern kingdoms", 1, true) then
            continentKey = "eastern_kingdoms"
        elseif currentMapID == 1414 or cleanCurrent:find("kalimdor", 1, true) then
            continentKey = "kalimdor"
        elseif currentMapID == 1945 or cleanCurrent:find("terralem", 1, true) or cleanCurrent:find("outland", 1, true) then
            continentKey = "outland"
        elseif currentMapID == 113 or cleanCurrent:find("nortundria", 1, true) or cleanCurrent:find("northrend", 1, true) then
            continentKey = "northrend"
        end

        -- A. Validação via dicionário pré-definido
        if continentKey and CONTINENT_ZONES[continentKey] then
            for _, zonePattern in ipairs(CONTINENT_ZONES[continentKey]) do
                if cleanMZone == zonePattern or cleanMZone:find(zonePattern, 1, true) or zonePattern:find(cleanMZone, 1, true) then
                    return true, true, false
                end
            end
        end

        -- B. Validação dinâmica via C_Map.GetMapChildrenInfo
        if currentMapID and C_Map and C_Map.GetMapChildrenInfo then
            local children = C_Map.GetMapChildrenInfo(currentMapID)
            if children and type(children) == "table" then
                for _, child in ipairs(children) do
                    if child.name and child.name ~= "" then
                        local cleanChild = cleanString(child.name)
                        if cleanMZone == cleanChild or cleanMZone:find(cleanChild, 1, true) or cleanChild:find(cleanMZone, 1, true) then
                            return true, true, false
                        end
                    end
                end
            end
        end

        return false, true, false
    end

    -- 3. Visão de Zona específica regular
    if cleanCurrent ~= "" then
        if cleanMZone == cleanCurrent or cleanCurrent:find(cleanMZone, 1, true) or cleanMZone:find(cleanCurrent, 1, true) then
            return true, false, false
        end
    end

    return false, false, false
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
        self._updateTicker = C_Timer.NewTicker(2.5, function()
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

--- Varre e filtra os membros da guilda presentes no mapa/região/continente atual.
function WorldMapController:scanCurrentZone()
    local currentMapID = self:getCurrentMapID()
    local currentMapName = self:getCurrentMapName(currentMapID)
    self._lastMapID = currentMapID

    local cleanCurrentMap = cleanString(currentMapName)
    local regionMembers = {}
    local addedByName = {}

    -- Determina o escopo do mapa visualizado (Continente, Mundo ou Zona)
    local _, isContinent, isWorld = self:isZoneMatch("dummy", currentMapName, currentMapID)

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

    -- 1. Verifica se o jogador local está na região / continente / mundo visualizado no mapa
    local myZone = GetRealZoneText() or GetZoneText() or ""
    local isLocalInZone = self:isZoneMatch(myZone, currentMapName, currentMapID)

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

    -- 2. Membros online da guilda cuja zona no Roster coincide com a região / continente visualizado
    for _, m in ipairs(allRosterMembers) do
        local mName = m:getName()
        local lowerName = mName:lower()
        local cleanMName = cleanString(mName)

        if not isLocalPlayer(mName, m:getGuid())
            and not addedByName[lowerName]
            and not addedByName[cleanMName]
            and m:isInGuild()
            and m:isOnline() then

            local match = self:isZoneMatch(m:getZone(), currentMapName, currentMapID)

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

    -- Atualiza a View do Mapa passando os flags de continente e mundo
    self._worldMapView:renderMembers(regionMembers, currentMapName, isContinent, isWorld)
end
