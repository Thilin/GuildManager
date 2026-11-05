---@class LocationService
--- ServiÃ§o de comunicaÃ§Ã£o peer-to-peer em tempo real para sincronizaÃ§Ã£o de
--- coordenadas geogrÃ¡ficas, orientaÃ§Ã£o e zona entre membros da guilda com o GuildManager.
--- Transmite via Grupo (PARTY/RAID), Guilda (GUILD) e canais globais ("GMShare" e "AJShare").
--- Totalmente nativo, autÃ´nomo, seguro e compatÃ­vel com a arquitetura Zero Taint.
LocationService = {}
LocationService.__index = LocationService

--- Verifica com seguranÃ§a se um valor Ã© um "Secret Value" (WoW 11.0+ / 12.0+ / Classic Beta)
---@param val any
---@return boolean
local function isSecretValue(val)
    if not val then
        return false
    end
    local isSecret = _G.issecretvalue or issecretvalue
    if isSecret and isSecret(val) then
        return true
    end
    local ok = pcall(function() return val == "" end)
    if not ok then
        return true
    end
    return false
end

local PRIMARY_PREFIX = "GM_POS"
local FALLBACK_PREFIX = "AJ_POS"
local SYNC_PREFIX = "GM_SYNC"
local COMM_CHANNEL_NAME = "AJShare"

local MOVE_THROTTLE = 1.5     -- Intervalo quando o jogador estÃ¡ em movimento (1.5s)
local IDLE_HEARTBEAT = 5.0    -- Intervalo de heartbeat quando o jogador estÃ¡ parado (5.0s)
local PEER_TIMEOUT = 45.0     -- Tempo sem sinal para considerar o jogador offline (45s)

--- Registra com seguranÃ§a todos os prefixos de mensagem utilizados pelo AddOn
function LocationService:registerPrefixes()
    local Register = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or _G.RegisterAddonMessagePrefix
    if Register then
        pcall(Register, PRIMARY_PREFIX)
        pcall(Register, FALLBACK_PREFIX)
        pcall(Register, SYNC_PREFIX)
        pcall(Register, "GuildManager")
    end
end

-- Registra os prefixos de mensagem imediatamente no carregamento do arquivo
LocationService:registerPrefixes()

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
    instance._lastReqTime = 0
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

--- ObtÃ©m os dados de um peer pelo nome (busca flexÃ­vel com/sem sobrenome, case-insensitive)
---@param name string
---@return table|nil
function LocationService:getPeer(name)
    if not name or name == "" then return nil end
    local exact = self._peers[name]
    if exact then return exact end

    local clean = name:match("^[^-]+") or name
    clean = clean:match("^%s*(.-)%s*$") or clean
    if self._peers[clean] then return self._peers[clean] end

    local lower = clean:lower()
    for pName, p in pairs(self._peers) do
        if pName:lower() == lower or (p.name and p.name:lower() == lower) or (p.fullName and p.fullName:lower() == lower) then
            return p
        end
    end

    -- Se o nome tiver sobrenome ("Killuah Zaviror"), tenta pelo primeiro nome ("Killuah") se nÃ£o houver ambiguidade
    local first = clean:match("^(%S+)")
    if first and first ~= clean then
        local firstLower = first:lower()
        for pName, p in pairs(self._peers) do
            local pFirst = pName:match("^(%S+)")
            if (pFirst and pFirst:lower() == firstLower) or pName:lower() == firstLower then
                return p
            end
        end
    end

    return nil
end

--- Registra ou atualiza um peer descoberto (via SyncService, eventos ou mensagem)
---@param peerName string
---@param extraData table|nil
function LocationService:touchPeer(peerName, extraData)
    if not peerName or peerName == "" or self:isSelf(peerName) then return end
    local clean = peerName:match("^[^-]+") or peerName
    clean = clean:match("^%s*(.-)%s*$") or clean

    local now = GetTime and GetTime() or 0
    local existing = self:getPeer(clean)

    if existing then
        existing.lastSeen = now
        if extraData then
            for k, v in pairs(extraData) do
                if v ~= nil then existing[k] = v end
            end
        end
    else
        local resolvedName = clean
        if self._memberService and self._memberService.resolveFullName then
            local r = self._memberService:resolveFullName(clean)
            if r and r ~= "" then resolvedName = r end
        end

        local peerData = {
            name = resolvedName,
            fullName = resolvedName,
            senderUnit = clean,
            mapID = (extraData and extraData.mapID) or 0,
            zoneName = (extraData and extraData.zoneName) or "Azeroth",
            x = (extraData and extraData.x) or 0,
            y = (extraData and extraData.y) or 0,
            facing = (extraData and extraData.facing) or 0,
            classFile = (extraData and extraData.classFile) or "WARRIOR",
            level = (extraData and extraData.level) or 1,
            race = (extraData and extraData.race) or "Desconhecido",
            guild = (extraData and extraData.guild) or "",
            channel = "P2P",
            lastSeen = now,
            lastSeenClock = time and time() or 0,
        }
        self._peers[clean] = peerData
        self._peers[resolvedName] = peerData
        self:notifyListeners("PEER_UPDATE", resolvedName, peerData)
        self:notifyListeners("PEER_LIST_CHANGED")
    end
end

--- Retorna a quantidade de outros membros conectados via Addon
---@return number
function LocationService:getPeerCount()
    local count = 0
    local seen = {}
    for name, p in pairs(self._peers) do
        local pClean = (p.name or name):match("^[^-]+") or (p.name or name)
        pClean = pClean:match("^%s*(.-)%s*$") or pClean
        local lower = pClean:lower()
        if not seen[lower] and not self:isSelf(name) and not p.isTest then
            seen[lower] = true
            count = count + 1
        end
    end
    return count
end

--- Retorna os membros que estÃ£o atualmente em um determinado mapa
---@param mapID number
---@return table
function LocationService:getPeersForMap(mapID)
    if not mapID or mapID <= 0 then return {} end
    local list = {}
    local seen = {}
    for _, p in pairs(self._peers) do
        if p and p.mapID == mapID and p.x and p.y and (p.x > 0 or p.y > 0) then
            local lower = (p.fullName or p.name or ""):lower()
            if not seen[lower] then
                seen[lower] = true
                table.insert(list, p)
            end
        end
    end
    return list
end

--- Retorna lista amigÃ¡vel de usuÃ¡rios do AddOn para a UI
---@return table[]
function LocationService:getGuildAddonUsers()
    local users = {}
    local now = GetTime and GetTime() or 0
    local seen = {}

    -- Adiciona o jogador local com nome completo (nome e sobrenome)
    local myFullName = self:getLocalPlayerFullName()
    local myName = (myFullName and myFullName ~= "") and myFullName or (self._myPlayerName or (UnitName and UnitName("player")) or "VocÃª")
    local _, myClass = UnitClass and UnitClass("player") or nil
    local myLevel = UnitLevel and UnitLevel("player") or 1
    local myZone = GetRealZoneText and GetRealZoneText() or ""

    local myClean = myName:match("^[^-]+") or myName
    myClean = myClean:match("^%s*(.-)%s*$") or myClean
    seen[myClean:lower()] = true

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
        local pName = p.fullName or p.name
        local cleanP = (pName or ""):match("^[^-]+") or pName
        cleanP = cleanP:match("^%s*(.-)%s*$") or cleanP
        local lower = cleanP:lower()

        if cleanP ~= "" and not seen[lower] and not self:isSelf(cleanP, pName) then
            seen[lower] = true
            table.insert(users, {
                name = p.fullName or p.name,
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
    end

    return users
end

--- Garante a conexÃ£o ao canal global reservado do AddOn sem poluir janelas de chat nativas
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

        -- Silencia no chat nativo da Blizzard uma Ãºnica vez (sem resetar as abas ou animaÃ§Ãµes de fade)
        if not self._silencedChannels[chName:lower()] then
            self._silencedChannels[chName:lower()] = true
            if ChatFrame_RemoveChannel and DEFAULT_CHAT_FRAME then
                pcall(ChatFrame_RemoveChannel, DEFAULT_CHAT_FRAME, chName)
            end
        end
    end
end

--- ObtÃ©m as coordenadas geogrÃ¡ficas normalizadas (0.0 a 1.0) e orientaÃ§Ã£o do jogador local
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
    mapID = mapID or 0

    local x, y = nil, nil
    if mapID > 0 then
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
    end

    local facing = 0
    if GetPlayerFacing then
        local ok, f = pcall(GetPlayerFacing)
        if ok and f then facing = f end
    end

    return mapID, x or 0, y or 0, facing
end

--- ObtÃ©m o nome completo (nome e sobrenome) do jogador local
---@return string
function LocationService:getLocalPlayerFullName()
    if self._myFullName and self._myFullName ~= "" and self._myFullName:find("%s") then
        local clean = self._myFullName:match("^[^-]+") or self._myFullName
        return clean:match("^%s*(.-)%s*$") or clean
    end

    local myGUID = UnitGUID and UnitGUID("player")
    if myGUID and myGUID ~= "" and self._memberService then
        if self._memberService.getMemberByGuid then
            local m = self._memberService:getMemberByGuid(myGUID)
            if m and m:getName() and m:getName() ~= "" and m:getName():find("%s") then
                self._myFullName = m:getName()
                return self._myFullName
            end
        end
        if self._memberService.resolvePlayerFullName then
            local res = self._memberService:resolvePlayerFullName()
            if res and res ~= "" and res:find("%s") then
                self._myFullName = res
                return self._myFullName
            end
        end
    end

    if _G.GM and _G.GM.memberController and _G.GM.memberController.resolvePlayerFullName then
        local res = _G.GM.memberController:resolvePlayerFullName()
        if res and res ~= "" and res:find("%s") then
            self._myFullName = res
            return self._myFullName
        end
    end

    local myName = self._myPlayerName or (UnitName and UnitName("player")) or ""
    return myName
end

--- Solicita que todos os outros membros conectados reportem imediatamente suas posiÃ§Ãµes
function LocationService:requestPositions()
    local now = GetTime and GetTime() or 0
    if (now - (self._lastReqTime or 0)) < 2.0 then return end
    self._lastReqTime = now

    local myName = self:getLocalPlayerFullName()
    local payload = string.format("POS_REQ:%s", myName)
    local Send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or _G.SendAddonMessage
    if not Send then return end

    if IsInGuild and IsInGuild() then
        pcall(Send, PRIMARY_PREFIX, payload, "GUILD")
        pcall(Send, FALLBACK_PREFIX, payload, "GUILD")
    end
    if self._channelNumber and self._channelNumber > 0 then
        pcall(Send, PRIMARY_PREFIX, payload, "CHANNEL", self._channelNumber)
    end
    if IsInRaid and IsInRaid() then
        pcall(Send, PRIMARY_PREFIX, payload, "RAID")
    elseif IsInGroup and IsInGroup() then
        pcall(Send, PRIMARY_PREFIX, payload, "PARTY")
    end
end

--- Transmite as coordenadas do jogador em tempo real para todos os canais disponÃ­veis
---@param force boolean|nil
function LocationService:sendPosition(force)
    local now = GetTime and GetTime() or 0
    if not force and (now - self._lastSendTime) < 0.5 then return end

    local mapID, x, y, facing = self:getLocalPosition()
    mapID = mapID or 0
    x = x or 0
    y = y or 0
    facing = facing or 0

    -- DetecÃ§Ã£o de movimento significativo se coordenadas estiverem disponÃ­veis
    local isMoving = false
    if x > 0 and y > 0 and self._lastSentX and self._lastSentY then
        local dx = math.abs(x - self._lastSentX)
        local dy = math.abs(y - self._lastSentY)
        local df = math.abs(facing - self._lastSentFacing)
        local mapChanged = (mapID ~= self._lastSentMapID)
        isMoving = (dx > 0.0008 or dy > 0.0008 or df > 0.15 or mapChanged)
    end
    local interval = isMoving and MOVE_THROTTLE or IDLE_HEARTBEAT

    if not force and (now - self._lastSendTime) < interval then
        return
    end

    self._lastSendTime = now
    self._lastSentX = x
    self._lastSentY = y
    self._lastSentFacing = facing
    self._lastSentMapID = mapID

    -- Atributos do jogador com cache local para evitar chamadas de API repetidas
    if not self._cachedClass and UnitClass then
        local ok, _, cFile = pcall(UnitClass, "player")
        if ok and cFile and type(cFile) == "string" then self._cachedClass = cFile end
    end
    local myClass = self._cachedClass or "WARRIOR"

    if not self._cachedRace and UnitRace then
        local ok, r = pcall(UnitRace, "player")
        if ok and r and type(r) == "string" then self._cachedRace = r:gsub(":", "") end
    end
    local myRace = self._cachedRace or "Desconhecido"

    if not self._cachedGuild and GetGuildInfo then
        local ok, g = pcall(GetGuildInfo, "player")
        if ok and g and type(g) == "string" then self._cachedGuild = g:gsub(":", "") end
    end
    local myGuild = self._cachedGuild or ""

    local myLevel = self._cachedLevel or 1
    if (not self._cachedLevel or force) and UnitLevel then
        local ok, lvl = pcall(UnitLevel, "player")
        if ok and lvl then
            myLevel = tonumber(lvl) or 1
            self._cachedLevel = myLevel
        end
    end

    -- Payload oficial compacto: POS:mapID:x:y:facing:class:level:race:guild:fullName
    local myFullName = self:getLocalPlayerFullName()
    local payload = string.format("POS:%d:%.4f:%.4f:%.2f:%s:%d:%s:%s:%s",
        mapID, x, y, facing, myClass, myLevel, myRace, myGuild, myFullName
    )

    local Send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or _G.SendAddonMessage
    if not Send then return end

    local function sendPacket(pfx)
        if IsInRaid and IsInRaid() then
            pcall(Send, pfx, payload, "RAID")
        elseif IsInGroup and IsInGroup() then
            pcall(Send, pfx, payload, "PARTY")
        end
        if IsInGuild and IsInGuild() then
            pcall(Send, pfx, payload, "GUILD")
        end
        if self._channelNumber and self._channelNumber > 0 then
            pcall(Send, pfx, payload, "CHANNEL", self._channelNumber)
        end
    end

    sendPacket(PRIMARY_PREFIX)
    sendPacket(FALLBACK_PREFIX)
end

--- Verifica com precisÃ£o se o remetente Ã© o prÃ³prio jogador local (evita ghosting)
--- Valida obrigatoriamente nome e sobrenome para evitar falsos positivos entre membros com mesmo primeiro nome.
---@param sender string
---@param rawFullName string|nil
---@return boolean
function LocationService:isSelf(sender, rawFullName)
    if not sender or sender == "" then return true end
    if UnitIsUnit and UnitIsUnit(sender, "player") then return true end

    local myName = self._myPlayerName
    if not myName and UnitName then
        myName = UnitName("player")
        self._myPlayerName = myName
    end
    local myFullName = self:getLocalPlayerFullName()

    local senderClean = sender:match("^([^-]+)") or sender
    senderClean = senderClean:match("^%s*(.-)%s*$") or senderClean

    local sLower = senderClean:lower()
    local mLower = (myName or ""):lower()
    local mfLower = (myFullName or ""):lower()

    -- 1. Se rawFullName (do payload da mensagem) foi fornecido, valida prioritariamente nome e sobrenome
    if rawFullName and rawFullName ~= "" then
        local rClean = rawFullName:match("^([^-]+)"):lower():match("^%s*(.-)%s*$")
        if rClean ~= "" and mfLower ~= "" then
            if rClean:find("%s") and mfLower:find("%s") then
                return rClean == mfLower
            elseif rClean == mfLower then
                return true
            end
        end
    end

    -- 2. Se ambos tÃªm nome e sobrenome, valida obrigatoriamente nome e sobrenome
    if mfLower ~= "" and mfLower:find("%s") and sLower:find("%s") then
        return sLower == mfLower
    end

    -- 3. Se o remetente tem nome e sobrenome e compara com o nome completo local
    if mfLower ~= "" and sLower == mfLower then
        return true
    end

    -- 4. Se o remetente nÃ£o tem sobrenome e confere com o primeiro nome do jogador local
    -- Importante: sÃ³ considera igual se o jogador local tambÃ©m nÃ£o tiver sobrenome
    if mLower ~= "" and not sLower:find("%s") and not mfLower:find("%s") and sLower == mLower then
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
    if not prefix or not message or isSecretValue(prefix) or isSecretValue(message) or (sender and isSecretValue(sender)) then
        return
    end
    if type(message) ~= "string" then return end

    local pUpper = prefix:upper()
    if pUpper ~= PRIMARY_PREFIX and pUpper ~= FALLBACK_PREFIX and pUpper ~= "GUILDMANAGER" and pUpper ~= SYNC_PREFIX then
        return
    end

    if not sender or sender == "" then return end

    local senderClean = sender:match("^([^-]+)") or sender
    senderClean = senderClean:match("^%s*(.-)%s*$") or senderClean

    -- Se for sinal vindo do GM_SYNC, registra a presenÃ§a deste usuÃ¡rio imediatamente
    if pUpper == SYNC_PREFIX then
        if not self:isSelf(sender, senderClean) then
            self:touchPeer(senderClean)
        end
        return
    end

    local tag, raw1, raw2, raw3, raw4, raw5, raw6, raw7, raw8, raw9 = strsplit(":", message)

    -- RequisiÃ§Ã£o de posiÃ§Ãµes em tempo real
    if tag == "POS_REQ" then
        if not self:isSelf(sender, raw1) then
            self:touchPeer(senderClean)
            self:sendPosition(true)
        end
        return
    end

    -- Ignora rigorosamente o prÃ³prio jogador validando nome e sobrenome
    if tag == "POS" then
        local rawMapID, rawX, rawY, rawFacing, classFile, rawLevel, race, guild, rawFullName = raw1, raw2, raw3, raw4, raw5, raw6, raw7, raw8, raw9

        if self:isSelf(sender, rawFullName) then
            return
        end

        local mapID = tonumber(rawMapID) or 0
        local x = tonumber(rawX) or 0
        local y = tonumber(rawY) or 0
        local facing = tonumber(rawFacing) or 0
        local level = tonumber(rawLevel) or 1
        classFile = classFile or "WARRIOR"
        race = race or "Desconhecido"
        guild = guild or ""

        local now = GetTime and GetTime() or 0
        local clock = time and time() or 0

        -- ValidaÃ§Ã£o rigorosa de Nome e Sobrenome para definir quem Ã© o personagem
        local resolvedFullName = nil
        if rawFullName and not isSecretValue(rawFullName) and rawFullName ~= "" then
            local cleanRaw = rawFullName:match("^[^-]+") or rawFullName
            cleanRaw = cleanRaw:match("^%s*(.-)%s*$") or cleanRaw
            if cleanRaw:find("%s") then
                resolvedFullName = cleanRaw
            end
        end

        if not resolvedFullName and self._memberService and self._memberService.resolveFullName then
            local resolved = self._memberService:resolveFullName(senderClean)
            if resolved and resolved ~= "" and resolved:find("%s") then
                resolvedFullName = resolved
            end
        end

        local finalName = resolvedFullName or senderClean

        -- Nome amigÃ¡vel da zona
        local zoneName = "Azeroth"
        if mapID and mapID > 0 and C_Map and C_Map.GetMapInfo then
            local ok, info = pcall(C_Map.GetMapInfo, mapID)
            if ok and info and info.name then zoneName = info.name end
        end

        local peerData = {
            name = finalName,
            fullName = finalName,
            senderUnit = senderClean,
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
        self._peers[finalName] = peerData
        self:notifyListeners("PEER_UPDATE", finalName, peerData)
        self:notifyListeners("PEER_LIST_CHANGED")

    -- Parsing do payload formato legado LOC:version:name:x:y:mapID:worldX:worldY:instanceID:class:level:zone
    elseif tag == "LOC" then
        local _, _, _, rawX, rawY, rawMapID, _, _, _, classToken, rawLevel, rawZone = strsplit(":", message)
        local mapID = tonumber(rawMapID) or 0
        local x = tonumber(rawX) or 0
        local y = tonumber(rawY) or 0
        local now = GetTime and GetTime() or 0
        local finalName = senderClean
        if self._memberService and self._memberService.resolveFullName then
            local resolved = self._memberService:resolveFullName(senderClean)
            if resolved and resolved ~= "" and resolved:find("%s") then
                finalName = resolved
            end
        end
        local peerData = {
            name = finalName,
            fullName = finalName,
            senderUnit = senderClean,
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
        self._peers[finalName] = peerData
        self:notifyListeners("PEER_UPDATE", finalName, peerData)
        self:notifyListeners("PEER_LIST_CHANGED")
    end
end

--- Alterna um jogador de teste simulado para validaÃ§Ã£o imediata no mapa oficial
---@return boolean
function LocationService:toggleTestPeer()
    local testName = "AventureiroTeste"
    if self._peers[testName] then
        self._peers[testName] = nil
        self:notifyListeners("PEER_EXPIRED", testName)
        self:notifyListeners("PEER_LIST_CHANGED")
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffd200[GuildManager]|r Membro de teste desativado.")
        end
        return false
    end

    local mapID = GetCurrentMapAreaID and GetCurrentMapAreaID()
    if not mapID or mapID <= 0 then
        if C_Map and C_Map.GetBestMapForUnit then
            mapID = C_Map.GetBestMapForUnit("player")
        end
    end
    if not mapID or mapID <= 0 then
        if WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame.GetMapID then
            local ok, id = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
            if ok and id and id > 0 and id ~= 947 and id ~= 946 and id ~= 1414 and id ~= 1415 then
                mapID = id
            end
        end
    end
    mapID = mapID or 1429

    local px, py = select(2, self:getLocalPosition()), select(3, self:getLocalPosition())
    if not px or not py or (px == 0 and py == 0) then
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
            "|cffffd200[GuildManager]|r Membro de teste '|cff00ff00%s|r' ativado em (%.1f, %.1f)! Abra o Mapa da Blizzard (M) para vÃª-lo em tempo real.",
            testName, px * 100, py * 100
        ))
    end
    return true
end

--- Remove pares que nÃ£o enviaram sinal recente
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

--- Inicializa os ganchos de eventos e timers do LocationService
function LocationService:initHooks()
    if self._eventFrame then return end

    self:registerPrefixes()

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_GUILD_UPDATE")
    frame:RegisterEvent("CHANNEL_UI_UPDATE")

    local function setupSession()
        self:registerPrefixes()
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
            C_Timer.After(1.0, function()
                self:registerPrefixes()
                self:sendPosition(true)
                self:requestPositions()
            end)
            C_Timer.After(3.5, function()
                self:sendPosition(true)
                self:requestPositions()
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
            self:registerPrefixes()
            self:ensureGlobalChannels()
            self:sendPosition(true)
            self:requestPositions()
        end
    end)

    -- Inicializa imediatamente sem depender de PLAYER_LOGIN (vital para /reload)
    if (IsLoggedIn and IsLoggedIn()) or (UnitName and UnitName("player")) then
        setupSession()
    end

    -- Loop de verificaÃ§Ã£o suave (0.75s) e expiraÃ§Ã£o periÃ³dica
    local ticker = 0
    local purgeTicker = 0
    local channelTicker = 0

    frame:SetScript("OnUpdate", function(_, elapsed)
        ticker = ticker + elapsed
        purgeTicker = purgeTicker + elapsed
        channelTicker = channelTicker + elapsed

        if ticker >= 0.75 then
            ticker = 0
            self:sendPosition(false)
        end

        -- Garante conexÃ£o ao canal global reservado somente se ainda nÃ£o conectado (a cada 15s)
        if channelTicker >= 15.0 then
            channelTicker = 0
            if not self._channelNumber or self._channelNumber <= 0 then
                self:ensureGlobalChannels()
            end
        end

        -- AnimaÃ§Ã£o em tempo real para peer de teste se ativo
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

--- Limpa todos os peers conhecidos e invalida o cache da guilda (usado na troca de guilda ou personagem)
function LocationService:clearPeers()
    self._peers = {}
    self._cachedGuild = nil
    self:notifyListeners("PEER_LIST_CHANGED")
end