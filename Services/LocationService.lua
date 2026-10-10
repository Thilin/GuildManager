---@class LocationService
--- Serviço responsável pela transmissão e recepção em tempo real das coordenadas
--- dos jogadores que usam o GuildManager, permitindo o rastreamento no mapa oficial.
---@field private _memberService MemberService|nil
---@field private _remoteLocations table<string, table>
---@field private _onLocationUpdated function|nil
---@field private _eventFrame table|nil
---@field private _lastBroadcastTime number
---@field private _lastBroadcastX number|nil
---@field private _lastBroadcastY number|nil
---@field private _lastBroadcastMapID number|nil
---@field private _ticker table|nil
LocationService = {}
LocationService.__index = LocationService

local PREFIX = "GuildManager"
local PROTOCOL_VERSION = "1"
local LOCATION_TIMEOUT = 45 -- Segundos antes de considerar uma coordenada obsoleta/expirada
local MIN_BROADCAST_INTERVAL = 1.0 -- Intervalo mínimo entre transmissões por movimento (1s)
local HEARTBEAT_INTERVAL = 4.0 -- Intervalo de atualização de presença quando parado (4s)
local MOVEMENT_THRESHOLD = 0.001 -- Variação mínima de coordenadas (aproximadamente 1-2 metros)

--- Normaliza o nome do personagem removendo reino, cores e espaços.
---@param rawName string|nil
---@return string
local function sanitizeName(rawName)
    if not rawName or rawName == "" then return "" end
    local name = rawName:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
    name = name:match("^[^-]+") or name
    name = name:match("^%s*(.-)%s*$") or name
    return name
end

--- Obtém o timestamp atual de alta precisão.
---@return number
local function getTimestamp()
    if GetTime then return GetTime() end
    if time then return time() end
    return 0
end

--- Construtor do LocationService.
---@param memberService MemberService|nil
---@return LocationService
function LocationService:new(memberService)
    local instance = setmetatable({}, self)
    instance._memberService = memberService
    instance._remoteLocations = {}
    instance._onLocationUpdated = nil
    instance._eventFrame = nil
    instance._lastBroadcastTime = 0
    instance._lastBroadcastX = nil
    instance._lastBroadcastY = nil
    instance._lastBroadcastMapID = nil
    instance._ticker = nil

    return instance
end

--- Cria ou encapsula um vetor 2D compatível com as APIs C_Map da Blizzard.
---@param x number
---@param y number
---@return table
function LocationService:makeVector2D(x, y)
    local numX = tonumber(x) or 0
    local numY = tonumber(y) or 0
    if CreateVector2D then
        return CreateVector2D(numX, numY)
    end
    local vec = { x = numX, y = numY }
    function vec:GetXY()
        return self.x, self.y
    end
    return vec
end

--- Obtém a posição geográfica atual do jogador local (mapa normalizado e coordenadas globais).
---@return number|nil bestMapID, number|nil x, number|nil y, number worldX, number worldY, number instanceID, string zoneName
function LocationService:getLocalPosition()
    local bestMapID = nil
    if C_Map and C_Map.GetBestMapForUnit then
        bestMapID = C_Map.GetBestMapForUnit("player")
    end
    if not bestMapID and WorldMapFrame and WorldMapFrame.GetMapID then
        bestMapID = WorldMapFrame:GetMapID()
    end
    if not bestMapID and GetCurrentMapAreaID then
        bestMapID = GetCurrentMapAreaID()
    end

    local x, y = nil, nil
    if bestMapID and C_Map and C_Map.GetPlayerMapPosition then
        local pos = C_Map.GetPlayerMapPosition(bestMapID, "player")
        if pos then
            x, y = pos:GetXY()
        end
    end

    local worldX, worldY, instanceID = 0, 0, 0
    if UnitPosition then
        local wy, wx, wz, inst = UnitPosition("player")
        if wx and wy then
            worldX = wx
            worldY = wy
            instanceID = inst or 0
        end
    end

    -- Se não conseguiu x, y direto do mapa mas tem worldPos, tenta converter via C_Map
    if (not x or not y) and bestMapID and (worldX ~= 0 or worldY ~= 0) and C_Map and C_Map.GetMapPosFromWorldPos then
        local wVec = self:makeVector2D(worldX, worldY)
        local mPos = C_Map.GetMapPosFromWorldPos(bestMapID, wVec)
        if mPos then
            x, y = mPos:GetXY()
        end
    end

    -- Se worldPos estava zerado mas tem x, y, tenta obter worldPos via C_Map
    if (worldX == 0 and worldY == 0) and bestMapID and x and y and C_Map and C_Map.GetWorldPosFromMapPos then
        local mVec = self:makeVector2D(x, y)
        local contID, wPos = C_Map.GetWorldPosFromMapPos(bestMapID, mVec)
        if wPos then
            worldX, worldY = wPos:GetXY()
            instanceID = contID or instanceID
        end
    end

    local zoneName = GetRealZoneText and GetRealZoneText() or (GetZoneText and GetZoneText() or "")
    if (not zoneName or zoneName == "") and bestMapID and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(bestMapID)
        if info and info.name then
            zoneName = info.name
        end
    end

    return bestMapID, x, y, worldX, worldY, instanceID, zoneName
end

--- Envia uma mensagem via canal de Addon oficial da Blizzard para a Guilda e Grupo.
---@param payload string
---@return boolean
function LocationService:sendAddonMessage(payload)
    if not payload or payload == "" then return false end
    local sent = false

    -- Transmissão via canal de guilda
    if IsInGuild and IsInGuild() then
        if C_ChatInfo and C_ChatInfo.SendAddonMessage then
            pcall(C_ChatInfo.SendAddonMessage, PREFIX, payload, "GUILD")
        elseif SendAddonMessage then
            pcall(SendAddonMessage, PREFIX, payload, "GUILD")
        end
        sent = true
    end

    -- Transmissão adicional via grupo (Raid ou Party)
    if IsInRaid and IsInRaid() then
        if C_ChatInfo and C_ChatInfo.SendAddonMessage then
            pcall(C_ChatInfo.SendAddonMessage, PREFIX, payload, "RAID")
        elseif SendAddonMessage then
            pcall(SendAddonMessage, PREFIX, payload, "RAID")
        end
        sent = true
    elseif IsInGroup and IsInGroup() then
        if C_ChatInfo and C_ChatInfo.SendAddonMessage then
            pcall(C_ChatInfo.SendAddonMessage, PREFIX, payload, "PARTY")
        elseif SendAddonMessage then
            pcall(SendAddonMessage, PREFIX, payload, "PARTY")
        end
        sent = true
    end

    return sent
end

--- Transmite as coordenadas do jogador local em tempo real para os demais jogadores.
---@param force boolean|nil @Se true, ignora o intervalo mínimo e força envio imediato
---@return boolean
function LocationService:broadcastLocation(force)
    local now = getTimestamp()
    if not force and (now - self._lastBroadcastTime) < MIN_BROADCAST_INTERVAL then
        return false
    end

    local bestMapID, x, y, worldX, worldY, instanceID, zoneName = self:getLocalPosition()
    if not x or not y or not bestMapID then
        return false
    end

    local myName = UnitName and UnitName("player") or ""
    myName = sanitizeName(myName)
    if myName == "" then return false end

    local _, classToken = UnitClass("player")
    classToken = classToken or "WARRIOR"
    local level = UnitLevel and UnitLevel("player") or 1

    -- Formato compacto do payload:
    -- LOC:<versão>:<nome>:<x>:<y>:<mapID>:<worldX>:<worldY>:<instanceID>:<classe>:<nível>:<zona>
    local cleanZone = (zoneName or ""):gsub(":", " ")
    local payload = string.format("LOC:%s:%s:%.4f:%.4f:%d:%.1f:%.1f:%d:%s:%d:%s",
        PROTOCOL_VERSION,
        myName,
        x,
        y,
        bestMapID,
        worldX or 0,
        worldY or 0,
        instanceID or 0,
        classToken,
        level,
        cleanZone
    )

    local success = self:sendAddonMessage(payload)
    if success then
        self._lastBroadcastTime = now
        self._lastBroadcastX = x
        self._lastBroadcastY = y
        self._lastBroadcastMapID = bestMapID
    end

    return success
end

--- Solicita a todos os outros jogadores online com o addon que enviem suas coordenadas agora.
function LocationService:requestLocations()
    self:sendAddonMessage("LOC_REQ")
end

--- Processa mensagens de AddOn recebidas pelo canal.
---@param prefix string
---@param msg string
---@param channel string
---@param sender string
function LocationService:handleIncomingMessage(prefix, msg, channel, sender)
    if prefix ~= PREFIX or type(msg) ~= "string" or msg == "" then
        return
    end

    local cleanSender = sanitizeName(sender)
    local myName = sanitizeName(UnitName and UnitName("player") or "")

    -- O emissor não deve rastrear a própria posição enviada (apenas receptores rastreiam)
    if cleanSender == "" or cleanSender:lower() == myName:lower() then
        return
    end

    -- 1. Resposta a uma solicitação de coordenadas por outro jogador
    if msg == "LOC_REQ" then
        -- Envia as próprias coordenadas com uma pequena variação de tempo (jitter) para evitar gargalo
        local delay = 0.05 + (math.random() * 0.15)
        if C_Timer and C_Timer.After then
            C_Timer.After(delay, function()
                self:broadcastLocation(true)
            end)
        else
            self:broadcastLocation(true)
        end
        return
    end

    -- 2. Recepção de coordenadas transmitidas em tempo real
    if msg:find("^LOC:") then
        local parts = { strsplit(":", msg) }
        -- partes: 1=LOC, 2=ver, 3=name, 4=x, 5=y, 6=mapID, 7=wX, 8=wY, 9=inst, 10=class, 11=level, 12=zone
        local ver = parts[2]
        local senderCharName = sanitizeName(parts[3] or cleanSender)
        local posX = tonumber(parts[4])
        local posY = tonumber(parts[5])
        local mapID = tonumber(parts[6])
        local worldX = tonumber(parts[7]) or 0
        local worldY = tonumber(parts[8]) or 0
        local instanceID = tonumber(parts[9]) or 0
        local classToken = parts[10] or "WARRIOR"
        local level = tonumber(parts[11]) or 1
        local zone = parts[12] or ""

        -- Garante novamente que o emissor não armazene a si próprio
        if senderCharName:lower() == myName:lower() then
            return
        end

        if posX and posY and mapID then
            local locData = {
                name = senderCharName,
                x = posX,
                y = posY,
                mapID = mapID,
                worldX = worldX,
                worldY = worldY,
                instanceID = instanceID,
                class = classToken:upper(),
                level = level,
                zone = zone,
                lastSeen = getTimestamp(),
            }

            self._remoteLocations[senderCharName:lower()] = locData

            if self._onLocationUpdated then
                self._onLocationUpdated(locData)
            end
        end
    end
end

--- Remove localizações remotas obsoletas que não foram atualizadas há mais de LOCATION_TIMEOUT segundos.
---@param timeoutSeconds number|nil
function LocationService:cleanStaleLocations(timeoutSeconds)
    local limit = timeoutSeconds or LOCATION_TIMEOUT
    local now = getTimestamp()

    for key, data in pairs(self._remoteLocations) do
        if not data.lastSeen or (now - data.lastSeen) > limit then
            self._remoteLocations[key] = nil
        end
    end
end

--- Retorna todas as posições ativas recebidas de outros jogadores.
---@return table<string, table>
function LocationService:getAllLocations()
    self:cleanStaleLocations()
    return self._remoteLocations
end

--- Retorna a posição de um jogador específico.
---@param name string
---@return table|nil
function LocationService:getLocation(name)
    local clean = sanitizeName(name)
    if clean == "" then return nil end
    local loc = self._remoteLocations[clean:lower()]
    if loc and (getTimestamp() - (loc.lastSeen or 0)) <= LOCATION_TIMEOUT then
        return loc
    end
    return nil
end

--- Limpa todas as coordenadas em memória.
function LocationService:clear()
    self._remoteLocations = {}
end

--- Define o callback invocado sempre que uma nova coordenada for recebida.
---@param callback function
function LocationService:setOnLocationUpdatedCallback(callback)
    self._onLocationUpdated = callback
end

--- Loop periódico para detectar movimento e transmitir coordenadas em tempo real.
function LocationService:onPeriodicCheck()
    local bestMapID, x, y = self:getLocalPosition()
    if not x or not y or not bestMapID then return end

    local now = getTimestamp()
    local moved = false

    if self._lastBroadcastX and self._lastBroadcastY and self._lastBroadcastMapID == bestMapID then
        local dx = math.abs(x - self._lastBroadcastX)
        local dy = math.abs(y - self._lastBroadcastY)
        if dx >= MOVEMENT_THRESHOLD or dy >= MOVEMENT_THRESHOLD then
            moved = true
        end
    else
        moved = true
    end

    if moved then
        if (now - self._lastBroadcastTime) >= MIN_BROADCAST_INTERVAL then
            self:broadcastLocation(true)
        end
    else
        if (now - self._lastBroadcastTime) >= HEARTBEAT_INTERVAL then
            self:broadcastLocation(true)
        end
    end
end

--- Inicializa os ganchos e eventos do serviço de localização.
function LocationService:initHooks()
    if self._eventFrame then return end

    -- Registro do prefixo do Addon
    if C_ChatInfo and C_ChatInfo.RegisterAddonPrefix then
        pcall(C_ChatInfo.RegisterAddonPrefix, PREFIX)
    elseif RegisterAddonMessagePrefix then
        pcall(RegisterAddonMessagePrefix, PREFIX)
    end

    local frame = CreateFrame("Frame")
    self._eventFrame = frame

    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("ZONE_CHANGED")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterEvent("ZONE_CHANGED_INDOORS")

    frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
        if event == "PLAYER_ENTERING_WORLD" then
            if C_ChatInfo and C_ChatInfo.RegisterAddonPrefix then
                pcall(C_ChatInfo.RegisterAddonPrefix, PREFIX)
            elseif RegisterAddonMessagePrefix then
                pcall(RegisterAddonMessagePrefix, PREFIX)
            end
            -- Ao entrar no mundo, transmite e solicita posições
            if C_Timer and C_Timer.After then
                C_Timer.After(2.0, function()
                    self:broadcastLocation(true)
                    self:requestLocations()
                end)
            end
        elseif event == "CHAT_MSG_ADDON" then
            self:handleIncomingMessage(arg1, arg2, arg3, arg4)
        elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED_INDOORS" then
            self:broadcastLocation(true)
        end
    end)

    -- Inicia ticker periódico de verificação a cada 1 segundo
    if C_Timer and C_Timer.NewTicker then
        self._ticker = C_Timer.NewTicker(1.0, function()
            self:onPeriodicCheck()
        end)
    else
        local accum = 0
        frame:SetScript("OnUpdate", function(_, elapsed)
            accum = accum + (elapsed or 0)
            if accum >= 1.0 then
                accum = 0
                self:onPeriodicCheck()
            end
        end)
    end
end

_G.LocationService = LocationService
if _G.GM then
    _G.GM.LocationService = LocationService
end
