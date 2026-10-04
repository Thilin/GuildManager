---@class WorldMapController
---@field private _memberService MemberService
---@field private _guildRosterService GuildRosterService
---@field private _worldMapView WorldMapView
---@field private _receivedLocations table
---@field private _lastMapID number|nil
---@field private _lastScanTime number
---@field private _lastBroadcastTime number
---@field private _updateTicker table|nil
WorldMapController = {}
WorldMapController.__index = WorldMapController

local ADDON_PREFIX = "GuildManager"

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
    instance._receivedLocations = {}
    instance._lastMapID = nil
    instance._lastScanTime = 0
    instance._lastBroadcastTime = 0
    instance._updateTicker = nil

    return instance
end

--- Normaliza strings para comparação (remove acentos e espaços extras).
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

--- Gera um hash pseudo-aleatório estável a partir de um nome.
---@param str string|nil
---@return number
local function hashName(str)
    if not str or str == "" then return 123 end
    local h = 5381
    for i = 1, #str do
        h = ((h * 33) + string.byte(str, i)) % 2147483647
    end
    return h
end

--- Banco de dados de pontos de interesse e coordenadas por região do WoW Classic.
local ZONE_HUBS = {
    -- =========================================================================
    -- REINOS DO LESTE (EASTERN KINGDOMS)
    -- =========================================================================
    ["cerro oeste"] = {
        name = "Cerro Oeste",
        hubs = {
            { name = "Morro da Sentinela", x = 0.534, y = 0.536 },
            { name = "Fazenda dos Saldean", x = 0.562, y = 0.315 },
            { name = "Fazenda dos Jansen", x = 0.595, y = 0.193 },
            { name = "Fazenda dos Furlbrow", x = 0.440, y = 0.245 },
            { name = "Riacho da Lua", x = 0.425, y = 0.672 },
            { name = "Pedreira da Costa Dourada", x = 0.320, y = 0.420 },
            { name = "Farol de Cerro Oeste", x = 0.302, y = 0.855 },
            { name = "Colinas das Adagas", x = 0.445, y = 0.780 },
            { name = "Torre de Mortwake", x = 0.602, y = 0.684 },
        }
    },
    ["westfall"] = {
        name = "Westfall",
        hubs = {
            { name = "Sentinel Hill", x = 0.534, y = 0.536 },
            { name = "Saldean's Farm", x = 0.562, y = 0.315 },
            { name = "Jansen's Farm", x = 0.595, y = 0.193 },
            { name = "Furlbrow's Farm", x = 0.440, y = 0.245 },
            { name = "Moonbrook", x = 0.425, y = 0.672 },
            { name = "Gold Coast Quarry", x = 0.320, y = 0.420 },
            { name = "Westfall Lighthouse", x = 0.302, y = 0.855 },
            { name = "Dagger Hills", x = 0.445, y = 0.780 },
            { name = "Mortwake's Tower", x = 0.602, y = 0.684 },
        }
    },
    ["floresta de elwynn"] = {
        name = "Floresta de Elwynn",
        hubs = {
            { name = "Vila D'Ouro", x = 0.425, y = 0.655 },
            { name = "Vale Norte", x = 0.480, y = 0.420 },
            { name = "Acampamento Madeireiro Leste", x = 0.820, y = 0.620 },
            { name = "Torre de Azora", x = 0.645, y = 0.695 },
            { name = "Plantação Brackwell", x = 0.700, y = 0.780 },
            { name = "Vinhedos Maclure", x = 0.430, y = 0.890 },
            { name = "Fazenda Stonefield", x = 0.345, y = 0.840 },
        }
    },
    ["elwynn forest"] = {
        name = "Elwynn Forest",
        hubs = {
            { name = "Goldshire", x = 0.425, y = 0.655 },
            { name = "Northshire", x = 0.480, y = 0.420 },
            { name = "Eastvale Logging Camp", x = 0.820, y = 0.620 },
            { name = "Tower of Azora", x = 0.645, y = 0.695 },
            { name = "Brackwell Pumpkin Patch", x = 0.700, y = 0.780 },
            { name = "Maclure Vineyards", x = 0.430, y = 0.890 },
            { name = "Stonefield Farm", x = 0.345, y = 0.840 },
        }
    },
    ["floresta do crepusculo"] = {
        name = "Floresta do Crepúsculo",
        hubs = {
            { name = "Vila Sombria", x = 0.735, y = 0.445 },
            { name = "Colina dos Corvos", x = 0.185, y = 0.570 },
            { name = "Pomar Apodrecido", x = 0.650, y = 0.280 },
            { name = "Jardins Tranquilos", x = 0.780, y = 0.360 },
            { name = "Monte Ocre Vul'Gol", x = 0.330, y = 0.740 },
        }
    },
    ["duskwood"] = {
        name = "Duskwood",
        hubs = {
            { name = "Darkshire", x = 0.735, y = 0.445 },
            { name = "Raven Hill", x = 0.185, y = 0.570 },
            { name = "The Rotting Orchard", x = 0.650, y = 0.280 },
            { name = "Tranquil Gardens Cemetery", x = 0.780, y = 0.360 },
            { name = "Vul'Gol Ogre Mound", x = 0.330, y = 0.740 },
        }
    },
    ["montanhas cristarrubra"] = {
        name = "Montanhas Cristarrubra",
        hubs = {
            { name = "Vila do Lago", x = 0.270, y = 0.450 },
            { name = "Torre de Ilgalar", x = 0.790, y = 0.480 },
            { name = "Cavernas Rethban", x = 0.340, y = 0.180 },
            { name = "Pedra Vigia", x = 0.680, y = 0.540 },
        }
    },
    ["redridge mountains"] = {
        name = "Redridge Mountains",
        hubs = {
            { name = "Lakeshire", x = 0.270, y = 0.450 },
            { name = "Tower of Ilgalar", x = 0.790, y = 0.480 },
            { name = "Rethban Caverns", x = 0.340, y = 0.180 },
            { name = "Stonewatch Keep", x = 0.680, y = 0.540 },
        }
    },
    ["loch modan"] = {
        name = "Loch Modan",
        hubs = {
            { name = "Thelsamar", x = 0.350, y = 0.480 },
            { name = "Vale Rachapedra", x = 0.330, y = 0.820 },
            { name = "Bastião Mo'grosh", x = 0.680, y = 0.220 },
            { name = "Mina do Rio Prateado", x = 0.350, y = 0.180 },
        }
    },
    ["dun morogh"] = {
        name = "Dun Morogh",
        hubs = {
            { name = "Kharanos", x = 0.465, y = 0.535 },
            { name = "Vale de Cristálgida", x = 0.290, y = 0.740 },
            { name = "Pedreira Gol'Bolar", x = 0.690, y = 0.560 },
            { name = "Depósito Grilloférreo", x = 0.620, y = 0.490 },
        }
    },
    ["pantanal"] = {
        name = "Pantanal",
        hubs = {
            { name = "Porto de Menethil", x = 0.105, y = 0.595 },
            { name = "Bosque do Guardião Verde", x = 0.500, y = 0.400 },
            { name = "Escavações de Whelgar", x = 0.330, y = 0.470 },
        }
    },
    ["wetlands"] = {
        name = "Wetlands",
        hubs = {
            { name = "Menethil Harbor", x = 0.105, y = 0.595 },
            { name = "Greenwarden's Grove", x = 0.500, y = 0.400 },
            { name = "Whelgar's Excavation Site", x = 0.330, y = 0.470 },
        }
    },
    ["planalto de arathi"] = {
        name = "Planalto de Arathi",
        hubs = {
            { name = "Refúgio", x = 0.460, y = 0.460 },
            { name = "Ruína do Martelo", x = 0.730, y = 0.340 },
            { name = "Fazenda Go'Shek", x = 0.600, y = 0.530 },
        }
    },
    ["arathi highlands"] = {
        name = "Arathi Highlands",
        hubs = {
            { name = "Refuge Pointe", x = 0.460, y = 0.460 },
            { name = "Hammerfall", x = 0.730, y = 0.340 },
            { name = "Go'Shek Farm", x = 0.600, y = 0.530 },
        }
    },
    ["contrafortes de eira dos montes"] = {
        name = "Contrafortes de Eira dos Montes",
        hubs = {
            { name = "Costasul", x = 0.500, y = 0.550 },
            { name = "Moinho de Tarren", x = 0.610, y = 0.190 },
            { name = "Minas Durnholde", x = 0.750, y = 0.400 },
        }
    },
    ["hillsbrad foothills"] = {
        name = "Hillsbrad Foothills",
        hubs = {
            { name = "Southshore", x = 0.500, y = 0.550 },
            { name = "Tarren Mill", x = 0.610, y = 0.190 },
            { name = "Durnholde Keep", x = 0.750, y = 0.400 },
        }
    },
    ["clareiras de tirisfal"] = {
        name = "Clareiras de Tirisfal",
        hubs = {
            { name = "Brill", x = 0.600, y = 0.520 },
            { name = "Plangente", x = 0.320, y = 0.650 },
            { name = "Fazenda Solliden", x = 0.360, y = 0.500 },
        }
    },
    ["tirisfal glades"] = {
        name = "Tirisfal Glades",
        hubs = {
            { name = "Brill", x = 0.600, y = 0.520 },
            { name = "Deathknell", x = 0.320, y = 0.650 },
            { name = "Solliden Farmstead", x = 0.360, y = 0.500 },
        }
    },
    ["floresta de pinho de prata"] = {
        name = "Floresta de Pinho de Prata",
        hubs = {
            { name = "O Sepulcro", x = 0.450, y = 0.420 },
            { name = "Vila de Pirobrasa", x = 0.460, y = 0.710 },
        }
    },
    ["silverpine forest"] = {
        name = "Silverpine Forest",
        hubs = {
            { name = "The Sepulcher", x = 0.450, y = 0.420 },
            { name = "Pyrewood Village", x = 0.460, y = 0.710 },
        }
    },
    ["selva do espinhaco"] = {
        name = "Selva do Espinhaço",
        hubs = {
            { name = "Angra do Butim", x = 0.270, y = 0.770 },
            { name = "Acampamento Grom'gol", x = 0.320, y = 0.280 },
            { name = "Expedição de Nesingwary", x = 0.350, y = 0.105 },
            { name = "Ruínas de Zul'Gurub", x = 0.720, y = 0.330 },
        }
    },
    ["stranglethorn vale"] = {
        name = "Stranglethorn Vale",
        hubs = {
            { name = "Booty Bay", x = 0.270, y = 0.770 },
            { name = "Grom'gol Base Camp", x = 0.320, y = 0.280 },
            { name = "Nesingwary's Expedition", x = 0.350, y = 0.105 },
            { name = "Zul'Gurub Ruins", x = 0.720, y = 0.330 },
        }
    },

    -- =========================================================================
    -- KALIMDOR
    -- =========================================================================
    ["os sertoes"] = {
        name = "Os Sertões",
        hubs = {
            { name = "A Encruzilhada", x = 0.520, y = 0.300 },
            { name = "Acampamento Taurajo", x = 0.450, y = 0.590 },
            { name = "Catraca", x = 0.625, y = 0.380 },
            { name = "Cavernas dos Lamentos", x = 0.420, y = 0.360 },
        }
    },
    ["sertoes"] = {
        name = "Os Sertões",
        hubs = {
            { name = "A Encruzilhada", x = 0.520, y = 0.300 },
            { name = "Acampamento Taurajo", x = 0.450, y = 0.590 },
            { name = "Catraca", x = 0.625, y = 0.380 },
            { name = "Cavernas dos Lamentos", x = 0.420, y = 0.360 },
        }
    },
    ["the barrens"] = {
        name = "The Barrens",
        hubs = {
            { name = "The Crossroads", x = 0.520, y = 0.300 },
            { name = "Camp Taurajo", x = 0.450, y = 0.590 },
            { name = "Ratchet", x = 0.625, y = 0.380 },
            { name = "Wailing Caverns", x = 0.420, y = 0.360 },
        }
    },
    ["durotar"] = {
        name = "Durotar",
        hubs = {
            { name = "Monte da Navalha", x = 0.525, y = 0.430 },
            { name = "Vale das Provações", x = 0.440, y = 0.680 },
            { name = "Aldeia Sen'jin", x = 0.560, y = 0.740 },
        }
    },
    ["mulgore"] = {
        name = "Mulgore",
        hubs = {
            { name = "Aldeia Casco Sangrento", x = 0.470, y = 0.600 },
            { name = "Acampamento Narache", x = 0.480, y = 0.800 },
        }
    },
    ["costa negra"] = {
        name = "Costa Negra",
        hubs = {
            { name = "Auberdine", x = 0.375, y = 0.435 },
            { name = "Bashal'Aran", x = 0.440, y = 0.360 },
            { name = "Ameth'Aran", x = 0.430, y = 0.580 },
            { name = "Bosque dos Anciãos", x = 0.435, y = 0.765 },
        }
    },
    ["darkshore"] = {
        name = "Darkshore",
        hubs = {
            { name = "Auberdine", x = 0.375, y = 0.435 },
            { name = "Bashal'Aran", x = 0.440, y = 0.360 },
            { name = "Ameth'Aran", x = 0.430, y = 0.580 },
            { name = "Grove of the Ancients", x = 0.435, y = 0.765 },
        }
    },
    ["teldrassil"] = {
        name = "Teldrassil",
        hubs = {
            { name = "Dolanaar", x = 0.560, y = 0.600 },
            { name = "Clareira das Sombras", x = 0.580, y = 0.400 },
            { name = "Aldeia Brisa Estelar", x = 0.660, y = 0.560 },
        }
    },
    ["vale gris"] = {
        name = "Vale Gris",
        hubs = {
            { name = "Astranaar", x = 0.360, y = 0.500 },
            { name = "Posto da Madeira Lascada", x = 0.730, y = 0.620 },
            { name = "Refúgio Vento Prateado", x = 0.490, y = 0.670 },
            { name = "Posto de Maestra", x = 0.260, y = 0.380 },
        }
    },
    ["ashenvale"] = {
        name = "Ashenvale",
        hubs = {
            { name = "Astranaar", x = 0.360, y = 0.500 },
            { name = "Splintertree Post", x = 0.730, y = 0.620 },
            { name = "Silverwind Refuge", x = 0.490, y = 0.670 },
            { name = "Maestra's Post", x = 0.260, y = 0.380 },
        }
    },
    ["tanaris"] = {
        name = "Tanaris",
        hubs = {
            { name = "Geringóntzia", x = 0.510, y = 0.270 },
            { name = "Porto Bondebico", x = 0.670, y = 0.230 },
            { name = "Zul'Farrak", x = 0.380, y = 0.200 },
        }
    },
    ["feralas"] = {
        name = "Feralas",
        hubs = {
            { name = "Bastião das Plumas", x = 0.300, y = 0.430 },
            { name = "Acampamento Mojache", x = 0.750, y = 0.430 },
        }
    },
    ["mil agulhas"] = {
        name = "Mil Agulhas",
        hubs = {
            { name = "Posto do Vento Livre", x = 0.450, y = 0.510 },
            { name = "Deserto Salino", x = 0.780, y = 0.750 },
        }
    },
    ["thousand needles"] = {
        name = "Thousand Needles",
        hubs = {
            { name = "Freewind Post", x = 0.450, y = 0.510 },
            { name = "Shimmering Flats", x = 0.780, y = 0.750 },
        }
    },

    -- =========================================================================
    -- CAPITAIS (CITIES)
    -- =========================================================================
    ["ventobravo"] = {
        name = "Ventobravo",
        hubs = {
            { name = "Distrito Comercial", x = 0.540, y = 0.620 },
            { name = "Bairro da Catedral", x = 0.420, y = 0.480 },
            { name = "Bairro dos Magos", x = 0.380, y = 0.750 },
            { name = "Castelo de Ventobravo", x = 0.760, y = 0.320 },
        }
    },
    ["stormwind city"] = {
        name = "Stormwind City",
        hubs = {
            { name = "Trade District", x = 0.540, y = 0.620 },
            { name = "Cathedral Square", x = 0.420, y = 0.480 },
            { name = "Mage Quarter", x = 0.380, y = 0.750 },
            { name = "Stormwind Keep", x = 0.760, y = 0.320 },
        }
    },
    ["altaforja"] = {
        name = "Altaforja",
        hubs = {
            { name = "Os Comuns", x = 0.350, y = 0.620 },
            { name = "A Grande Forja", x = 0.500, y = 0.480 },
            { name = "Bairro Militar", x = 0.700, y = 0.720 },
        }
    },
    ["ironforge"] = {
        name = "Ironforge",
        hubs = {
            { name = "The Commons", x = 0.350, y = 0.620 },
            { name = "The Great Forge", x = 0.500, y = 0.480 },
            { name = "Military Ward", x = 0.700, y = 0.720 },
        }
    },
    ["darnassus"] = {
        name = "Darnassus",
        hubs = {
            { name = "Terraço dos Guerreiros", x = 0.600, y = 0.400 },
            { name = "Templo da Lua", x = 0.400, y = 0.750 },
            { name = "Jardins dos Artesãos", x = 0.620, y = 0.650 },
        }
    },
    ["orgrimmar"] = {
        name = "Orgrimmar",
        hubs = {
            { name = "Vale da Força", x = 0.460, y = 0.680 },
            { name = "Vale da Honra", x = 0.700, y = 0.380 },
            { name = "Vale dos Espíritos", x = 0.380, y = 0.480 },
        }
    },
    ["penhasco do trovao"] = {
        name = "Penhasco do Trovão",
        hubs = {
            { name = "Platô Superior", x = 0.470, y = 0.550 },
            { name = "Platô dos Caçadores", x = 0.600, y = 0.650 },
            { name = "Platô dos Anciãos", x = 0.450, y = 0.400 },
        }
    },
    ["thunder bluff"] = {
        name = "Thunder Bluff",
        hubs = {
            { name = "Central Rise", x = 0.470, y = 0.550 },
            { name = "Hunter Rise", x = 0.600, y = 0.650 },
            { name = "Elder Rise", x = 0.450, y = 0.400 },
        }
    },
    ["cidade baixa"] = {
        name = "Cidade Baixa",
        hubs = {
            { name = "Pátio Central", x = 0.500, y = 0.500 },
            { name = "Bairro dos Guerreiros", x = 0.650, y = 0.400 },
            { name = "Bairro dos Magos", x = 0.650, y = 0.600 },
            { name = "Bairro Real", x = 0.580, y = 0.900 },
        }
    },
    ["undercity"] = {
        name = "Undercity",
        hubs = {
            { name = "Central Courtyard", x = 0.500, y = 0.500 },
            { name = "War Quarter", x = 0.650, y = 0.400 },
            { name = "Mage Quarter", x = 0.650, y = 0.600 },
            { name = "The Royal Quarter", x = 0.580, y = 0.900 },
        }
    },
}

--- Obtém dados de coordenadas e pontos de interesse para a região.
---@param zoneName string
---@return table|nil, table|nil
function WorldMapController:getZoneHubData(zoneName)
    local cz = cleanString(zoneName)
    if cz == "" then return nil, nil end

    if ZONE_HUBS[cz] then
        return ZONE_HUBS[cz], nil
    end

    -- Busca parcial por chave de zona
    for k, v in pairs(ZONE_HUBS) do
        if cz:find(k, 1, true) or k:find(cz, 1, true) then
            return v, nil
        end
    end

    -- Busca por subzona / nome de marco conhecido dentro de qualquer zona
    for _, v in pairs(ZONE_HUBS) do
        for _, hub in ipairs(v.hubs) do
            local cleanHub = cleanString(hub.name)
            if cleanHub == cz or cz:find(cleanHub, 1, true) or cleanHub:find(cz, 1, true) then
                return v, hub
            end
        end
    end

    return nil, nil
end

--- Deriva coordenadas determinísticas para membros sem coordenadas exatas de rede.
---@param memberName string
---@param zoneName string
---@return number, number, string
function WorldMapController:deriveZoneCoordinates(memberName, zoneName)
    local zoneData, directHub = self:getZoneHubData(zoneName)
    local hash = hashName(memberName or "Member")

    if directHub then
        local offX = (((hash * 13) % 21) - 10) / 1000
        local offY = (((hash * 17) % 21) - 10) / 1000
        local finalX = math.max(0.06, math.min(0.94, directHub.x + offX))
        local finalY = math.max(0.06, math.min(0.94, directHub.y + offY))
        return finalX, finalY, directHub.name
    end

    if zoneData and zoneData.hubs and #zoneData.hubs > 0 then
        local idx = (hash % #zoneData.hubs) + 1
        local hub = zoneData.hubs[idx]
        local offX = (((hash * 13) % 25) - 12) / 1000
        local offY = (((hash * 17) % 25) - 12) / 1000
        local finalX = math.max(0.06, math.min(0.94, hub.x + offX))
        local finalY = math.max(0.06, math.min(0.94, hub.y + offY))
        return finalX, finalY, hub.name
    end

    -- Ponto de dispersão padrão da região
    local offX = (((hash * 13) % 41) - 20) / 100
    local offY = (((hash * 17) % 41) - 20) / 100
    local finalX = math.max(0.15, math.min(0.85, 0.50 + offX))
    local finalY = math.max(0.15, math.min(0.85, 0.50 + offY))
    return finalX, finalY, zoneName or "Região"
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

--- Obtém o nome legível da região do mapa atual.
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

--- Obtém as coordenadas normalizadas (0.0 a 1.0) de uma unidade para o mapa especificado.
---@param unit string
---@param mapID number|nil
---@return number|nil, number|nil
function WorldMapController:getUnitCoordinates(unit, mapID)
    unit = unit or "player"
    mapID = mapID or self:getCurrentMapID()
    if not mapID then return nil, nil end

    if C_Map and C_Map.GetPlayerMapPosition then
        local pos = C_Map.GetPlayerMapPosition(mapID, unit)
        if pos then
            local x = pos.x or pos.X
            local y = pos.y or pos.Y
            if not x and pos.GetXY then
                x, y = pos:GetXY()
            end
            if x and y and (x > 0 or y > 0) then
                return x, y
            end
        end
    end

    if unit == "player" and GetPlayerMapPosition then
        local x, y = GetPlayerMapPosition("player")
        if x and y and (x > 0 or y > 0) then
            return x, y
        end
    end

    return nil, nil
end

--- Envia mensagem via CHAT_MSG_ADDON para o canal de guilda com proteção de erros.
---@param msg string
function WorldMapController:sendAddonMessage(msg)
    if not IsInGuild or not IsInGuild() then return end
    if not msg or msg == "" then return end

    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        pcall(C_ChatInfo.SendAddonMessage, ADDON_PREFIX, msg, "GUILD")
    elseif SendAddonMessage then
        pcall(SendAddonMessage, ADDON_PREFIX, msg, "GUILD")
    end
end

--- Transmite a localização atual do jogador para os outros membros da guilda.
function WorldMapController:broadcastMyPosition()
    local now = (GetTime and GetTime()) or 0
    if (now - self._lastBroadcastTime) < 3.0 then
        return
    end
    self._lastBroadcastTime = now

    local myMapID = self:getCurrentMapID()
    local myX, myY = self:getUnitCoordinates("player", myMapID)
    local myName = UnitName("player") or ""
    local myZone = GetRealZoneText() or GetZoneText() or ""
    local myLevel = UnitLevel("player") or 1
    local _, myClass = UnitClass("player")
    myClass = myClass or ""

    if myName ~= "" and myX and myY then
        local msg = string.format("MAP_LOC:%s:%s:%.4f:%.4f:%s:%d:%s",
            myName, tostring(myMapID or 0), myX, myY, myZone, myLevel, myClass)
        self:sendAddonMessage(msg)
    end
end

--- Solicita a localização de todos os membros da guilda presentes no mapa atual.
function WorldMapController:requestGuildMapLocations()
    local now = (GetTime and GetTime()) or 0
    if (now - self._lastScanTime) < 4.0 then
        return
    end
    self._lastScanTime = now

    local mapID = self:getCurrentMapID() or 0
    local mapName = self:getCurrentMapName(mapID)
    self:sendAddonMessage(string.format("MAP_REQ:%s:%s", tostring(mapID), mapName))
    self:broadcastMyPosition()
end

--- Inicializa os ganchos com a interface do WorldMapFrame da Blizzard e eventos de chat.
function WorldMapController:initHooks()
    if not WorldMapFrame then
        return
    end

    -- Registra o prefixo de comunicação addon
    if C_ChatInfo and C_ChatInfo.RegisterAddonPrefix then
        pcall(C_ChatInfo.RegisterAddonPrefix, ADDON_PREFIX)
    elseif RegisterAddonMessagePrefix then
        pcall(RegisterAddonMessagePrefix, ADDON_PREFIX)
    end

    -- Vincula callbacks da View
    self._worldMapView:setOnScanCallback(function()
        self:requestGuildMapLocations()
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

    -- Hook do WorldMapFrame OnShow: inicializa UI, exibe o painel, plota os pinos e faz scan da região
    WorldMapFrame:HookScript("OnShow", function()
        self._worldMapView:initWorldMapUI()
        self._worldMapView:showPanel()
        self:scanCurrentZone()
        self:requestGuildMapLocations()
        self:startPeriodicUpdate()

        -- Scan adicional de segurança para quando as dimensões do canvas do mapa terminarem de calcular
        if C_Timer and C_Timer.After then
            C_Timer.After(0.05, function()
                if WorldMapFrame and WorldMapFrame:IsShown() then
                    self:scanCurrentZone()
                end
            end)
        end
    end)

    -- Hook do WorldMapFrame OnHide: interrompe atualizações periódicas e limpa os pinos da tela
    WorldMapFrame:HookScript("OnHide", function()
        self:stopPeriodicUpdate()
        self._worldMapView:clearPins()
    end)

    -- Criação do frame de eventos para mensagens de addon e mudanças de mapa
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    pcall(function() eventFrame:RegisterEvent("WORLD_MAP_UPDATE") end)

    eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
        if event == "CHAT_MSG_ADDON" then
            self:handleIncomingAddonMessage(arg1, arg2, arg3, arg4)
        elseif event == "GUILD_ROSTER_UPDATE" then
            if WorldMapFrame:IsShown() then
                self:scanCurrentZone()
            end
        elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED_INDOORS" then
            if WorldMapFrame:IsShown() then
                self:scanCurrentZone()
            end
        elseif event == "WORLD_MAP_UPDATE" then
            if WorldMapFrame and WorldMapFrame:IsShown() then
                local currentMapID = self:getCurrentMapID()
                if currentMapID ~= self._lastMapID then
                    self._lastMapID = currentMapID
                    self:requestGuildMapLocations()
                end
                self:scanCurrentZone()
            end
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
                local currentMapID = self:getCurrentMapID()
                if currentMapID ~= self._lastMapID then
                    self._lastMapID = currentMapID
                    self:requestGuildMapLocations()
                end
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

--- Processa mensagens de addon recebidas (MAP_REQ e MAP_LOC).
---@param prefix string
---@param msg string
---@param channel string
---@param sender string
function WorldMapController:handleIncomingAddonMessage(prefix, msg, channel, sender)
    if prefix ~= ADDON_PREFIX or type(msg) ~= "string" then
        return
    end

    local myName = UnitName("player") or ""
    local cleanSender = sender:match("^[^-]+") or sender

    -- 1. Responde a solicitações de mapa vindas de outros membros da guilda
    if msg:find("^MAP_REQ:") then
        local _, reqMapID, reqZone = strsplit(":", msg)
        reqMapID = tonumber(reqMapID)

        local myMapID = self:getCurrentMapID()
        local myX, myY = self:getUnitCoordinates("player", myMapID)
        local myZone = GetRealZoneText() or GetZoneText() or ""

        -- Se estiver na mesma região solicitada ou se possui coordenadas
        local isSameMap = reqMapID and myMapID and (reqMapID == myMapID)
        local isSameZone = reqZone and myZone ~= "" and cleanString(reqZone) == cleanString(myZone)

        if (isSameMap or isSameZone or not reqMapID or reqMapID == 0) and myX and myY then
            local myLevel = UnitLevel("player") or 1
            local _, myClass = UnitClass("player")
            myClass = myClass or ""
            local respMsg = string.format("MAP_LOC:%s:%s:%.4f:%.4f:%s:%d:%s",
                myName, tostring(myMapID or 0), myX, myY, myZone, myLevel, myClass)
            self:sendAddonMessage(respMsg)
        end

    -- 2. Processa a localização recebida de um membro da guilda
    elseif msg:find("^MAP_LOC:") then
        local _, pName, pMapID, pX, pY, pZone, pLevel, pClass = strsplit(":", msg)
        pName = pName or cleanSender
        pMapID = tonumber(pMapID)
        pX = tonumber(pX)
        pY = tonumber(pY)
        pLevel = tonumber(pLevel) or 1
        pClass = pClass or ""
        pZone = pZone or ""

        if pName and pName ~= "" and pX and pY then
            self._receivedLocations[pName:lower()] = {
                name = pName,
                mapID = pMapID,
                coordX = pX,
                coordY = pY,
                zone = pZone,
                level = pLevel,
                class = pClass,
                timestamp = (GetTime and GetTime()) or 0,
            }

            if WorldMapFrame and WorldMapFrame:IsShown() then
                self:scanCurrentZone()
            end
        end
    end
end

--- Varre e filtra os membros da guilda presentes no mapa/região atual.
function WorldMapController:scanCurrentZone()
    local currentMapID = self:getCurrentMapID()
    local currentMapName = self:getCurrentMapName(currentMapID)
    self._lastMapID = currentMapID

    local cleanCurrentMap = cleanString(currentMapName)
    local regionMembers = {}
    local addedByName = {}

    -- Identificação robusta do jogador local e suas variantes de nome
    local myGUID = UnitGUID("player")
    local myName = UnitName("player") or ""
    local myFirstName = myName:match("^(%S+)") or myName
    local cleanMyName = cleanString(myName)
    local cleanMyFirst = cleanString(myFirstName)

    -- Função auxiliar para registrar todas as variantes de um nome (completo, minúsculo, sem acentos, primeiro nome)
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

    -- Identifica com precisão se qualquer membro ou unidade corresponde ao jogador local
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

    -- Busca os dados do próprio jogador no Roster da guilda para obter nome completo e cargo oficial
    local allRosterMembers = self._memberService:getAllMembers()
    local myMember = nil
    for _, m in ipairs(allRosterMembers) do
        if isLocalPlayer(m:getName(), m:getGuid()) then
            myMember = m
            break
        end
    end

    -- Registra o jogador local em todas as variações para evitar qualquer duplicação
    registerAddedName(myName)
    registerAddedName(myFirstName)
    if myMember then
        registerAddedName(myMember:getName())
    end

    -- 1. Inclui o jogador local caso esteja no mapa atual
    local myMapID = self:getCurrentMapID()
    local myX, myY = self:getUnitCoordinates("player", currentMapID)
    local myZone = GetRealZoneText() or GetZoneText() or ""

    if myName ~= "" and (cleanCurrentMap == "" or cleanCurrentMap == cleanString(myZone) or (myX and myY)) then
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
            coordX = myX,
            coordY = myY,
            isOnline = true,
            isSelf = true,
            isExact = true,
        }
        table.insert(regionMembers, myData)
        registerAddedName(displayName)
    end

    -- 2. Membros do grupo/raide que estão na guilda (coordenadas em tempo real nativas)
    if IsInGroup and IsInGroup() then
        local numGroup = GetNumGroupMembers and GetNumGroupMembers() or 0
        local isRaid = IsInRaid and IsInRaid()
        local prefix = isRaid and "raid" or "party"

        for i = 1, numGroup do
            local unit = prefix .. i
            if not isRaid and i == numGroup then unit = "player" end
            local unitName = UnitName(unit)
            local unitGUID = UnitGUID(unit)
            if unitName and unitName ~= ""
                and not isLocalPlayer(unitName, unitGUID)
                and not addedByName[unitName:lower()]
                and not addedByName[cleanString(unitName)] then
                local m = self._memberService:getMember(unitName)
                if m and m:isInGuild() and m:isOnline() then
                    local uX, uY = self:getUnitCoordinates(unit, currentMapID)
                    local uLevel = UnitLevel(unit) or m:getLevel()
                    local _, uClass = UnitClass(unit)
                    uClass = uClass or m:getClass()

                    local data = {
                        name = m:getName(),
                        level = uLevel,
                        class = uClass,
                        classDisplayName = m:getClassDisplayName(),
                        rankName = m:getRankName(),
                        publicNote = m:getPublicNote(),
                        officerNote = m:getOfficerNote(),
                        zone = currentMapName,
                        coordX = uX,
                        coordY = uY,
                        isOnline = true,
                        isGroup = true,
                        isExact = true,
                    }
                    table.insert(regionMembers, data)
                    registerAddedName(unitName)
                    registerAddedName(m:getName())
                end
            end
        end
    end

    -- 3. Membros que enviaram coordenadas via Addon Message no mapa atual
    local now = (GetTime and GetTime()) or 0
    for lowerName, locData in pairs(self._receivedLocations) do
        if not isLocalPlayer(locData.name)
            and not addedByName[lowerName]
            and not addedByName[cleanString(locData.name)]
            and (now - (locData.timestamp or 0)) <= 300 then
            -- Valida se está no mesmo mapID ou mesma zona
            local matchMap = currentMapID and locData.mapID and (currentMapID == locData.mapID)
            local matchZone = locData.zone and locData.zone ~= "" and cleanString(locData.zone) == cleanCurrentMap

            if matchMap or matchZone then
                local m = self._memberService:getMember(locData.name)
                local data = {
                    name = locData.name,
                    level = locData.level or (m and m:getLevel()) or 1,
                    class = locData.class or (m and m:getClass()) or "",
                    classDisplayName = m and m:getClassDisplayName() or "",
                    rankName = m and m:getRankName() or "",
                    publicNote = m and m:getPublicNote() or "",
                    officerNote = m and m:getOfficerNote() or "",
                    zone = locData.zone or currentMapName,
                    coordX = locData.coordX,
                    coordY = locData.coordY,
                    isOnline = true,
                    viaAddon = true,
                    isExact = true,
                }
                table.insert(regionMembers, data)
                registerAddedName(locData.name)
                if m then registerAddedName(m:getName()) end
            end
        end
    end

    -- 4. Todos os membros online da guilda cuja zona no Roster coincide com a região do mapa
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
                local cachedLoc = self._receivedLocations[lowerName] or self._receivedLocations[cleanMName]
                local coordX = cachedLoc and cachedLoc.coordX
                local coordY = cachedLoc and cachedLoc.coordY
                local isExact = false
                local hubLocation = nil

                if coordX and coordY and (coordX > 0 or coordY > 0) then
                    isExact = true
                else
                    coordX, coordY, hubLocation = self:deriveZoneCoordinates(mName, m:getZone() or currentMapName)
                end

                local data = {
                    name = m:getName(),
                    level = m:getLevel(),
                    class = m:getClass(),
                    classDisplayName = m:getClassDisplayName(),
                    rankName = m:getRankName(),
                    publicNote = m:getPublicNote(),
                    officerNote = m:getOfficerNote(),
                    zone = m:getZone(),
                    coordX = coordX,
                    coordY = coordY,
                    hubLocation = hubLocation,
                    isOnline = true,
                    isExact = isExact,
                }
                table.insert(regionMembers, data)
                registerAddedName(mName)
            end
        end
    end

    -- Ordenação: Jogador local primeiro, depois quem tem coordenadas exatas, depois alfabético
    table.sort(regionMembers, function(a, b)
        if a.isSelf then return true end
        if b.isSelf then return false end
        if a.isExact and not b.isExact then return true end
        if not a.isExact and b.isExact then return false end
        return (a.name or ""):lower() < (b.name or ""):lower()
    end)

    -- Atualiza a View do Mapa com os dados obtidos
    self._worldMapView:renderMembers(regionMembers, currentMapName)
end
