---@class LocationService
--- Serviço de comunicação peer-to-peer em tempo real para sincronização de
--- coordenadas geográficas, orientação e zona entre membros da guilda com o GuildManager.
--- Transmite via Grupo (PARTY/RAID), Guilda (GUILD) e canais globais ("GMShare" e "AJShare").
--- Totalmente nativo, autônomo, seguro e compatível com a arquitetura Zero Taint.
LocationService = {}
LocationService.__index = LocationService

local PRIMARY_PREFIX = "GM_POS"
local FALLBACK_PREFIX = "AJ_POS"
local MSG_PREFIX = "AJ_POS"
local COMM_CHANNEL_NAME = "AJShare"

local MOVE_THROTTLE = 1.25    -- Intervalo quando o jogador está em movimento (1.25s)
local IDLE_HEARTBEAT = 4.0     -- Intervalo de heartbeat quando o jogador está parado (4.0s)
local PEER_TIMEOUT = 30.0      -- Tempo sem sinal para considerar o jogador offline (30s)

-- Registra os prefixos de mensagem imediatamente no carregamento do arquivo
local RegisterPrefix = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or _G.RegisterAddonMessagePrefix
if RegisterPrefix then
    pcall(RegisterPrefix, PRIMARY_PREFIX)
    pcall(RegisterPrefix, FALLBACK_PREFIX)
end

--- Construtor do LocationService.
---@param memberService MemberService|nil
---@return LocationService
function LocationService:new(memberService)
    local instance = setmetatable({}, self)
    instance._memberService = memberService
    instance._peers = {}
    instance._listeners = {}
    instance._channelNumber = nil
    instance._channelNumbers = {}
    instance._silencedChannels = {}
    instance._lastJoinAttempt = 0
    instance._myPlayerName = nil
    instance._myFullName = nil
    instance._lastSendTime = 0
    instance._lastSentX = -1
    instance._lastSentY = -1
    instance._lastSentFacing = -1
    instance._lastSentMapID = -1
    instance._eventFrame = nil

    return instance
end

--- Registra um callback para ser notificado de eventos de pares (PEER_UPDATE, PEER_EXPIRED, PEER_LIST_CHANGED)
---@param callback function
function LocationService:registerListener(callback)
    if type(callback) == "function" then
        table.insert(self._listeners, callback)
    end
end

--- Alias de compatibilidade
---@param callback function
function LocationService:registerOnUsersChangedCallback(callback)
    self:registerListener(callback)
end

--- Notifica todos os listeners registrados
---@param event string
---@param peerName string|nil
---@param peerData table|nil
function LocationService:notifyListeners(event, peerName, peerData)
    for _, cb in ipairs(self._listeners) do
        pcall(cb, event, peerName, peerData)
    end
end

--- Retorna a tabela completa de pares remotos conectados
---@return table<string, table>
function LocationService:getPeers()
    return self._peers
end

--- Retorna a quantidade de outros membros conectados via Addon
---@return number
function LocationService:getPeerCount()
    local count = 0
    for name in pairs(self._peers) do
        if not self:isSelf(name) then
            count = count + 1
        end
    end
    return count
end

--- Retorna os membros que estão atualmente em um determinado mapa
---@param mapID number
---@return table
function LocationService:getPeersForMap(mapID)
    if not mapID or mapID <= 0 then return {} end
    local list = {}
    for _, p in pairs(self._peers) do
        if p and p.mapID == mapID then
            table.insert(list, p)
        end
    end
    return list
end

--- Retorna lista amigável de usuários do AddOn para a UI
---@return table[]
function LocationService:getGuildAddonUsers()
    local users = {}
    local now = GetTime and GetTime() or 0

    -- Adiciona o jogador local
    local myName = self._myPlayerName or (UnitName and UnitName("player")) or "Você"
    local _, myClass = UnitClass and UnitClass("player") or nil
    local myLevel = UnitLevel and UnitLevel("player") or 1
    local myZone = GetRealZoneText and GetRealZoneText() or ""

    table.insert(users, {
        name = myName,
        class = myClass or "WARRIOR",
        level = myLevel,
        zone = myZone,
        isSelf = true,
        lastSeen = now,
    })

    -- Adiciona os outros membros conectados
    for _, p in pairs(self._peers) do
        table.insert(users, {
            name = p.name,
            class = p.classFile or "WARRIOR",
            level = p.level or 1,
            zone = p.zoneName or "Azeroth",
            guild = p.guild or "",
            isSelf = false,
            lastSeen = p.lastSeen or now,
            facing = p.facing or 0,
            x = p.x or 0,
            y = p.y or 0,
            mapID = p.mapID,
        })
    end

    return users
end

--- Garante a conexão ao canal global reservado do AddOn sem poluir janelas de chat nativas
function LocationService:ensureGlobalChannels()
    if self._channelNumber and self._channelNumber > 0 then
        return
    end

    local now = GetTime and GetTime() or 0
    if (now - self._lastJoinAttempt) < 8.0 then return end
    self._lastJoinAttempt = now

    local chName = COMM_CHANNEL_NAME
    local id = nil

    if GetChannelName then
        local ok, chID = pcall(GetChannelName, chName)
        if ok and chID and type(chID) == "number" and chID > 0 then
            id = chID
        end
    end

    if not id and JoinChannelByName then
        pcall(JoinChannelByName, chName)
        if GetChannelName then
            local ok, newID = pcall(GetChannelName, chName)
            if ok and newID and type(newID) == "number" and newID > 0 then
                id = newID
            end
        end
    end

    if id and id > 0 then
        self._channelNumber = id
        self._channelNumbers[chName:lower()] = id

        -- Silencia no chat nativo da Blizzard uma única vez (sem resetar as abas ou animações de fade)
        if not self._silencedChannels[chName:lower()] then
            self._silencedChannels[chName:lower()] = true
            if ChatFrame_RemoveChannel and DEFAULT_CHAT_FRAME then
                pcall(ChatFrame_RemoveChannel, DEFAULT_CHAT_FRAME, chName)
            end
        end
    end
end

--- Obtém as coordenadas geográficas normalizadas (0.0 a 1.0) e orientação do jogador local
---@return number|nil mapID, number|nil x, number|nil y, number facing
function LocationService:getLocalPosition()
    local mapID = nil
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
        if ok and id and id > 0 then mapID = id end
    end
    if not mapID and GetCurrentMapAreaID then
        local ok, id = pcall(GetCurrentMapAreaID)
        if ok and id and id > 0 then mapID = id end
    end
    if not mapID or mapID <= 0 then return nil, nil, nil, 0 end

    local x, y = nil, nil
    if C_Map and C_Map.GetPlayerMapPosition then
        local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
        if ok and pos then
            if pos.GetXY then
                local okXY, px, py = pcall(pos.GetXY, pos)
                if okXY and px and py then x, y = px, py end
            elseif pos.x and pos.y then
                x, y = pos.x, pos.y
            end
        end
    end
    if not x or not y then
        if GetPlayerMapPosition then
            local ok, px, py = pcall(GetPlayerMapPosition, "player")
            if ok and px and py then x, y = px, py end
        end
    end

    if not x or not y or (x == 0 and y == 0) then
        return nil, nil, nil, 0
    end

    local facing = 0
    if GetPlayerFacing then
        local ok, f = pcall(GetPlayerFacing)
        if ok and f then facing = f end
    end

    return mapID, x, y, facing
end

--- Transmite as coordenadas do jogador em tempo real para todos os canais disponíveis
---@param force boolean|nil
function LocationService:sendPosition(force)
    local now = GetTime and GetTime() or 0
    if not force and (now - self._lastSendTime) < 0.5 then return end

    local mapID, x, y, facing = self:getLocalPosition()
    if not mapID or not x or not y then return end

    -- Detecção de movimento significativo
    local dx = math.abs(x - self._lastSentX)
    local dy = math.abs(y - self._lastSentY)
    local df = math.abs(facing - self._lastSentFacing)
    local mapChanged = (mapID ~= self._lastSentMapID)

    local isMoving = (dx > 0.0008 or dy > 0.0008 or df > 0.15 or mapChanged)
    local interval = isMoving and MOVE_THROTTLE or IDLE_HEARTBEAT

    if not force and (now - self._lastSendTime) < interval then
        return
    end

    self._lastSendTime = now
    self._lastSentX = x
    self._lastSentY = y
    self._lastSentFacing = facing
    self._lastSentMapID = mapID

    -- Atributos do jogador
    local myClass = "WARRIOR"
    if UnitClass then
        local ok, _, cFile = pcall(UnitClass, "player")
        if ok and cFile and type(cFile) == "string" then myClass = cFile end
    end

    local myLevel = 1
    if UnitLevel then
        local ok, lvl = pcall(UnitLevel, "player")
        if ok and lvl then myLevel = tonumber(lvl) or 1 end
    end

    local myRace = "Desconhecido"
    if UnitRace then
        local ok, r = pcall(UnitRace, "player")
        if ok and r and type(r) == "string" then myRace = r end
    end

    local myGuild = ""
    if GetGuildInfo then
        local ok, g = pcall(GetGuildInfo, "player")
        if ok and g and type(g) == "string" then myGuild = g end
    end

    -- Payload oficial compacto: POS:mapID:x:y:facing:class:level:race:guild
    local payload = string.format("POS:%d:%.4f:%.4f:%.2f:%s:%d:%s:%s",
        mapID, x, y, facing, myClass, myLevel, myRace:gsub(":", ""), myGuild:gsub(":", "")
    )

    local Send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or _G.SendAddonMessage
    if not Send then return end

    -- 1. Transmite para Raide ou Grupo (se agrupado)
    if IsInRaid and IsInRaid() then
        pcall(Send, MSG_PREFIX, payload, "RAID")
    elseif IsInGroup and IsInGroup() then
        pcall(Send, MSG_PREFIX, payload, "PARTY")
    end

    -- 2. Transmite para a Guilda (1 prefixo limpo, sem pacotes duplicados que poluem o chat)
    if IsInGuild and IsInGuild() then
        pcall(Send, MSG_PREFIX, payload, "GUILD")
    end

    -- 3. Transmite para o canal global do AddOn ("AJShare")
    if not self._channelNumber and self.ensureGlobalChannels then
        self:ensureGlobalChannels()
    end
    if self._channelNumber and self._channelNumber > 0 then
        pcall(Send, MSG_PREFIX, payload, "CHANNEL", self._channelNumber)
    end
end

--- Verifica com precisão se o remetente é o próprio jogador local (evita ghosting)
---@param sender string
---@return boolean
function LocationService:isSelf(sender)
    if not sender or sender == "" then return true end
    if UnitIsUnit and UnitIsUnit(sender, "player") then return true end

    local myName = self._myPlayerName
    if not myName and UnitName then
        myName = UnitName("player")
        self._myPlayerName = myName
    end
    if not myName or myName == "" then return false end

    local senderClean = sender:match("^([^-]+)") or sender
    local sLower = senderClean:lower():gsub("%s+", "")
    local mLower = myName:lower():gsub("%s+", "")
    if sLower == mLower then return true end

    local sFirst = senderClean:match("^(%S+)") or senderClean
    local mFirst = myName:match("^(%S+)") or myName
    if sFirst ~= "" and mFirst ~= "" and sFirst:lower() == mFirst:lower() then
        return true
    end

    return false
end

--- Processa uma mensagem de coordenadas recebida de outro jogador
---@param prefix string
---@param message string
---@param channel string
---@param sender string
function LocationService:onAddonMessage(prefix, message, channel, sender)
    if not prefix or not message or type(message) ~= "string" then return end

    -- Aceita mensagens do prefixo primário do GuildManager (GM_POS) e fallback (AJ_POS)
    local pUpper = prefix:upper()
    if pUpper ~= PRIMARY_PREFIX and pUpper ~= FALLBACK_PREFIX and pUpper ~= "GUILDMANAGER" then
        return
    end

    if not sender or sender == "" then return end

    -- Ignora rigorosamente o próprio jogador
    if self:isSelf(sender) then
        return
    end

    local senderClean = sender:match("^([^-]+)") or sender

    -- Parsing do payload formato POS:mapID:x:y:facing:class:level:race:guild
    local tag, rawMapID, rawX, rawY, rawFacing, classFile, rawLevel, race, guild = strsplit(":", message)

    if tag == "POS" then
        local mapID = tonumber(rawMapID)
        local x = tonumber(rawX)
        local y = tonumber(rawY)
        local facing = tonumber(rawFacing) or 0
        local level = tonumber(rawLevel) or 1
        classFile = classFile or "WARRIOR"
        race = race or "Desconhecido"
        guild = guild or ""

        if not mapID or not x or not y then return end

        local now = GetTime and GetTime() or 0
        local clock = time and time() or 0

        -- Nome amigável da zona
        local zoneName = "Azeroth"
        if C_Map and C_Map.GetMapInfo then
            local ok, info = pcall(C_Map.GetMapInfo, mapID)
            if ok and info and info.name then zoneName = info.name end
        end

        local peerData = {
            name = senderClean,
            fullName = sender,
            mapID = mapID,
            zoneName = zoneName,
            x = x,
            y = y,
            facing = facing,
            classFile = classFile,
            level = level,
            race = race,
            guild = guild,
            channel = channel,
            lastSeen = now,
            lastSeenClock = clock,
        }

        self._peers[senderClean] = peerData
        self:notifyListeners("PEER_UPDATE", senderClean, peerData)

    -- Parsing do payload formato legado LOC:version:name:x:y:mapID:worldX:worldY:instanceID:class:level:zone
    elseif tag == "LOC" then
        local _, _, _, rawX, rawY, rawMapID, _, _, _, classToken, rawLevel, rawZone = strsplit(":", message)
        local mapID = tonumber(rawMapID)
        local x = tonumber(rawX)
        local y = tonumber(rawY)
        if mapID and x and y then
            local now = GetTime and GetTime() or 0
            local peerData = {
                name = senderClean,
                fullName = sender,
                mapID = mapID,
                zoneName = rawZone or "Azeroth",
                x = x,
                y = y,
                facing = 0,
                classFile = classToken or "WARRIOR",
                level = tonumber(rawLevel) or 1,
                race = "Desconhecido",
                guild = "",
                channel = channel,
                lastSeen = now,
                lastSeenClock = time and time() or 0,
            }
            self._peers[senderClean] = peerData
            self:notifyListeners("PEER_UPDATE", senderClean, peerData)
        end
    end
end

--- Alterna um jogador de teste simulado para validação imediata no mapa oficial
---@return boolean
function LocationService:toggleTestPeer()
    local testName = "AventureiroTeste"
    if self._peers[testName] then
        self._peers[testName] = nil
        self:notifyListeners("PEER_EXPIRED", testName)
        self:notifyListeners("PEER_LIST_CHANGED")
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffd200[GuildManager]|r Membro de teste removido.")
        end
        return false
    end

    local mapID = nil
    if WorldMapFrame and WorldMapFrame:IsShown() then
        if WorldMapFrame.GetMapID then
            local ok, id = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
            if ok and id and id > 0 then mapID = id end
        end
        if not mapID and WorldMapFrame.mapID and WorldMapFrame.mapID > 0 then
            mapID = WorldMapFrame.mapID
        end
    end
    if not mapID then
        mapID = select(1, self:getLocalPosition())
    end
    mapID = mapID or 1429

    local px, py = select(2, self:getLocalPosition()), select(3, self:getLocalPosition())
    if not px or not py then
        px, py = 0.50, 0.50
    else
        px = px + 0.012
        py = py + 0.012
    end

    local peerData = {
        name = testName,
        fullName = testName .. "-Forever",
        mapID = mapID,
        zoneName = (C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID) and C_Map.GetMapInfo(mapID).name) or "Azeroth",
        x = px,
        y = py,
        baseX = px,
        baseY = py,
        facing = 1.57,
        classFile = "MAGE",
        level = 60,
        race = "Humano",
        guild = "GuildManager",
        channel = "GMShare",
        lastSeen = GetTime and GetTime() or 0,
        lastSeenClock = time and time() or 0,
        isTest = true,
    }

    self._peers[testName] = peerData
    self:notifyListeners("PEER_UPDATE", testName, peerData)
    self:notifyListeners("PEER_LIST_CHANGED")
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cffffd200[GuildManager]|r Membro de teste '|cff00ff00%s|r' ativado em (%.1f, %.1f)! Abra o Mapa da Blizzard (M) para vê-lo em tempo real.",
            testName, px * 100, py * 100
        ))
    end
    return true
end

--- Remove pares que não enviaram sinal recente
function LocationService:purgeExpiredPeers()
    local now = GetTime and GetTime() or 0
    local removedAny = false

    for name, p in pairs(self._peers) do
        if not p.isTest and (now - (p.lastSeen or 0)) > PEER_TIMEOUT then
            self._peers[name] = nil
            removedAny = true
            self:notifyListeners("PEER_EXPIRED", name, p)
        end
    end

    if removedAny then
        self:notifyListeners("PEER_LIST_CHANGED")
    end
end

--- Inicializa os ganchos de eventos e loop de transmissão em segundo plano
function LocationService:initHooks()
    if self._eventFrame then return end

    -- Garante o registro de todos os prefixos suportados
    if RegisterPrefix then
        pcall(RegisterPrefix, PRIMARY_PREFIX)
        pcall(RegisterPrefix, FALLBACK_PREFIX)
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_GUILD_UPDATE")
    frame:RegisterEvent("CHANNEL_UI_UPDATE")

    local function setupSession()
        if UnitName then
            self._myPlayerName = UnitName("player")
        end
        if UnitFullName then
            local ok, n, r = pcall(UnitFullName, "player")
            if ok and n then
                self._myFullName = (r and r ~= "") and (n .. "-" .. r) or n
            end
        end
        self:ensureGlobalChannels()
        if C_Timer and C_Timer.After then
            C_Timer.After(1.5, function()
                self:sendPosition(true)
            end)
        end
    end

    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            setupSession()

        elseif event == "CHAT_MSG_ADDON" then
            local prefix, msg, ch, sender = ...
            self:onAddonMessage(prefix, msg, ch, sender)

        elseif event == "CHAT_MSG_CHANNEL_NOTICE" then
            local noticeType, _, _, _, _, _, _, arg8, arg9 = ...
            if noticeType == "YOU_JOINED" then
                local chName = (type(arg9) == "string" and arg9) or (type(arg8) == "string" and arg8) or nil
                local chIndex = (type(arg8) == "number" and arg8) or (type(arg9) == "number" and arg9) or nil
                if chName and chName:lower():find("ajshare", 1, true) then
                    if chIndex and chIndex > 0 then
                        self._channelNumber = chIndex
                        self._channelNumbers["ajshare"] = chIndex
                    end
                    if not self._silencedChannels["ajshare"] then
                        self._silencedChannels["ajshare"] = true
                        if ChatFrame_RemoveChannel and DEFAULT_CHAT_FRAME then
                            pcall(ChatFrame_RemoveChannel, DEFAULT_CHAT_FRAME, chName)
                        end
                    end
                end
            end

        elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" or event == "CHANNEL_UI_UPDATE" then
            self:ensureGlobalChannels()
            self:sendPosition(true)
        end
    end)

    -- Inicializa imediatamente sem depender de PLAYER_LOGIN (vital para /reload)
    if (IsLoggedIn and IsLoggedIn()) or (UnitName and UnitName("player")) then
        setupSession()
    end

    -- Loop de verificação suave (0.25s) e expiração periódica
    local ticker = 0
    local purgeTicker = 0
    local channelTicker = 0

    frame:SetScript("OnUpdate", function(_, elapsed)
        ticker = ticker + elapsed
        purgeTicker = purgeTicker + elapsed
        channelTicker = channelTicker + elapsed

        if ticker >= 0.25 then
            ticker = 0
            self:sendPosition(false)
        end

        -- Garante conexão ao canal global reservado somente se ainda não conectado (a cada 15s)
        if channelTicker >= 15.0 then
            channelTicker = 0
            if not self._channelNumber or self._channelNumber <= 0 then
                self:ensureGlobalChannels()
            end
        end

        -- Animação em tempo real para peer de teste se ativo
        local testPeer = self._peers["AventureiroTeste"]
        if testPeer and testPeer.isTest then
            local now = GetTime and GetTime() or 0
            testPeer.lastSeen = now
            local t = now * 0.9
            testPeer.x = testPeer.baseX + math.sin(t) * 0.005
            testPeer.y = testPeer.baseY + math.cos(t) * 0.005
            testPeer.facing = (t + math.pi / 2) % (2 * math.pi)
            self:notifyListeners("PEER_UPDATE", "AventureiroTeste", testPeer)
        end

        if purgeTicker >= 5.0 then
            purgeTicker = 0
            self:purgeExpiredPeers()
        end
    end)

    self._eventFrame = frame
end
