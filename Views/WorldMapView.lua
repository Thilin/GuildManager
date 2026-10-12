---@class WorldMapView
---@field private _frame table|nil
---@field private _mapButton table|nil
---@field private _realtimeBadge table|nil
---@field private _updateFrame table|nil
---@field private _panel table|nil
---@field private _pins table
---@field private _memberRows table
---@field private _membersData table
---@field private _onScanCallback function|nil
---@field private _onMemberClickCallback function|nil
WorldMapView = {}
WorldMapView.__index = WorldMapView

local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })

local PALETTE = {
    FRAME_BG = { 0.05, 0.04, 0.02, 0.95 },
    FRAME_BORDER = { 0.60, 0.45, 0.20, 1.0 },
    SUB_BOX_BG = { 0.08, 0.06, 0.03, 0.90 },
    SUB_BOX_BORDER = { 0.45, 0.32, 0.12, 0.85 },
    FOCUS_BORDER = { 0.90, 0.70, 0.20, 1.0 },
    FOCUS_BG = { 0.12, 0.09, 0.04, 0.95 },
    INSET_BG = { 0.04, 0.03, 0.015, 0.90 },
    INSET_BORDER = { 0.45, 0.32, 0.12, 0.80 },
    SEPARATOR = { 0.45, 0.32, 0.12, 0.60 },
    HIGHLIGHT_TINT = { 0.90, 0.75, 0.30, 0.20 },
}

local CONTAINER_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local SUB_CONTAINER_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local MAP_BUTTON_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local CLASS_COLORS = {
    WARRIOR     = { r = 0.78, g = 0.61, b = 0.43, hex = "|cffc79c6e" },
    MAGE        = { r = 0.41, g = 0.80, b = 0.94, hex = "|cff69ccf0" },
    ROGUE       = { r = 1.00, g = 0.96, b = 0.41, hex = "|cfffff569" },
    DRUID       = { r = 1.00, g = 0.49, b = 0.04, hex = "|cffff7d0a" },
    HUNTER      = { r = 0.67, g = 0.83, b = 0.45, hex = "|cffabd473" },
    SHAMAN      = { r = 0.00, g = 0.44, b = 0.87, hex = "|cff0070de" },
    PRIEST      = { r = 1.00, g = 1.00, b = 1.00, hex = "|cffffffff" },
    WARLOCK     = { r = 0.58, g = 0.51, b = 0.79, hex = "|cff9482c9" },
    PALADIN     = { r = 0.96, g = 0.55, b = 0.73, hex = "|cfff58cba" },
    DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23, hex = "|cffc41e3a" },
}

local CLASS_ICON_COORDS = {
    WARRIOR     = { 0, 0.25, 0, 0.25 },
    MAGE        = { 0.25, 0.49609375, 0, 0.25 },
    ROGUE       = { 0.49609375, 0.7421875, 0, 0.25 },
    DRUID       = { 0.7421875, 0.98828125, 0, 0.25 },
    HUNTER      = { 0, 0.25, 0.25, 0.5 },
    SHAMAN      = { 0.25, 0.49609375, 0.25, 0.5 },
    PRIEST      = { 0.49609375, 0.7421875, 0.25, 0.5 },
    WARLOCK     = { 0.7421875, 0.98828125, 0.25, 0.5 },
    PALADIN     = { 0, 0.25, 0.5, 0.75 },
    DEATHKNIGHT = { 0.25, 0.49609375, 0.5, 0.75 },
}

--- Cria vetor bidimensional compatível com todas as versões da API C_Map
local function MakeVector2D(x, y)
    if CreateVector2D then
        return CreateVector2D(x, y)
    elseif Vector2D_Create then
        return Vector2D_Create(x, y)
    end
    local v = { x = x, y = y }
    function v:GetXY() return self.x, self.y end
    return v
end

--- Obtém o ID do mapa atual exibido no WorldMapFrame oficial da Blizzard
local function GetCurrentWorldMapID()
    if WorldMapFrame and WorldMapFrame.GetMapID then
        local ok, id = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
        if ok and id and id > 0 then return id end
    end
    if WorldMapFrame and WorldMapFrame.mapID and WorldMapFrame.mapID > 0 then
        return WorldMapFrame.mapID
    end
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
        if ok and id and id > 0 then return id end
    end
    if GetCurrentMapAreaID then
        local ok, id = pcall(GetCurrentMapAreaID)
        if ok and id and id > 0 then return id end
    end
    return nil
end

--- Identifica se o mapa é um continente, mundo ou mapa global
local function IsContinentOrWorld(mapID)
    if not mapID then return false end
    if mapID == 947 or mapID == 946 or mapID == 1414 or mapID == 1415 or mapID == 1945 or mapID == 113 then
        return true
    end
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        if ok and info and info.mapType ~= nil then
            if info.mapType == 0 or info.mapType == 1 or info.mapType == 2 then
                return true
            end
            if Enum and Enum.UIMapType then
                if info.mapType == Enum.UIMapType.Continent or info.mapType == Enum.UIMapType.World or info.mapType == Enum.UIMapType.Cosmic then
                    return true
                end
            end
        end
    end
    return false
end

--- Verifica se o mapa de origem é uma subzona/micro-mapa dentro da zona visualizada
local function IsChildOfViewZone(parentMapID, childMapID)
    if not parentMapID or not childMapID or parentMapID == childMapID then return false end
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, childMapID)
        if ok and info and info.parentMapID == parentMapID then
            return true
        end
    end
    return false
end

--- Extrai a posição mundial a partir da posição no mapa de forma segura
local function SafeGetWorldPos(sourceMapID, sourceX, sourceY)
    if not (C_Map and C_Map.GetWorldPosFromMapPos) then return nil, nil end
    local v = MakeVector2D(sourceX, sourceY)
    local ok, r1, r2 = pcall(C_Map.GetWorldPosFromMapPos, sourceMapID, v)
    if not ok or not r1 then return nil, nil end

    if type(r1) == "number" and (type(r2) == "table" or type(r2) == "userdata") then
        return r1, r2
    elseif (type(r1) == "table" or type(r1) == "userdata") and type(r2) == "number" then
        return r2, r1
    elseif (type(r1) == "table" or type(r1) == "userdata") then
        local cID = 0
        if C_Map.GetMapInfo then
            local info = C_Map.GetMapInfo(sourceMapID)
            if info and info.parentMapID then cID = info.parentMapID end
        end
        return cID, r1
    end
    return nil, nil
end

--- Extrai as coordenadas (x, y) normalizadas no mapa alvo de forma universal
local function SafeGetMapPos(continentID, worldPos, targetMapID)
    if not (C_Map and C_Map.GetMapPosFromWorldPos) then return nil, nil end
    local ok, r1, r2 = pcall(C_Map.GetMapPosFromWorldPos, continentID, worldPos, targetMapID)
    if not ok or not r1 then return nil, nil end

    if type(r1) == "number" and type(r2) == "number" then
        return r1, r2
    end
    if type(r1) == "table" or type(r1) == "userdata" then
        if r1.GetXY then
            local okXY, x, y = pcall(r1.GetXY, r1)
            if okXY and type(x) == "number" and type(y) == "number" then
                return x, y
            end
        end
        if type(r1.x) == "number" and type(r1.y) == "number" then
            return r1.x, r1.y
        end
    end
    return nil, nil
end

--- Traduz coordenadas entre zonas, continentes e subzonas no mapa oficial da Blizzard
---@param sourceMapID number
---@param sourceX number
---@param sourceY number
---@param viewMapID number
---@return number|nil renderX, number|nil renderY
local function TranslateCoordsToViewMap(sourceMapID, sourceX, sourceY, viewMapID)
    if not sourceMapID or not viewMapID or not sourceX or not sourceY then return nil, nil end

    -- Caso 1: Mesma zona exata
    if sourceMapID == viewMapID then
        return sourceX, sourceY
    end

    -- Caso 2: O mapa visualizado é um CONTINENTE ou MUNDO (ex: Kalimdor, Reinos do Leste)
    if IsContinentOrWorld(viewMapID) then
        local continentID, worldPos = SafeGetWorldPos(sourceMapID, sourceX, sourceY)
        if not continentID or not worldPos then return nil, nil end

        local mx, my = SafeGetMapPos(continentID, worldPos, viewMapID)
        if mx and my and mx >= 0 and mx <= 1 and my >= 0 and my <= 1 then
            return mx, my
        end
        return nil, nil
    end

    -- Caso 3: O jogador remoto está em uma micro-zona/caverna cujo mapa-mãe é a zona visualizada
    if IsChildOfViewZone(viewMapID, sourceMapID) then
        local continentID, worldPos = SafeGetWorldPos(sourceMapID, sourceX, sourceY)
        if continentID and worldPos then
            local mx, my = SafeGetMapPos(continentID, worldPos, viewMapID)
            if mx and my and mx >= 0 and mx <= 1 and my >= 0 and my <= 1 then
                return mx, my
            end
        end
    end

    return nil, nil
end

--- Aplica a textura do ícone oficial circular da classe no pino
local function ApplyClassIcon(texture, classFile)
    classFile = classFile or "WARRIOR"
    local coords = CLASS_ICON_COORDS[classFile]

    local ok = pcall(function()
        texture:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        if coords then
            texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        end
    end)

    if not ok or not texture:GetTexture() then
        texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        if coords then
            local l, r, t, b = coords[1], coords[2], coords[3], coords[4]
            local dx = (r - l) * 0.05
            local dy = (b - t) * 0.05
            texture:SetTexCoord(l + dx, r - dx, t + dy, b - dy)
        end
    end
end

--- Construtor da View do Mapa Mundi.
---@return WorldMapView
function WorldMapView:new()
    local instance = setmetatable({}, self)
    instance._pins = {}
    instance._memberRows = {}
    instance._membersData = {}
    instance._scrollOffset = 0
    instance._maxVisibleRows = 10
    instance._rowHeight = 42
    instance._currentZoneName = ""
    instance._isPanelOpen = true
    instance._isContinentView = false
    instance._isWorldView = false
    instance._realtimeBadge = nil
    instance._updateFrame = nil

    return instance
end

--- Retorna o canvas oficial do WorldMapFrame da Blizzard e suas dimensões garantidas
---@return table|nil canvas, number cw, number ch
function WorldMapView:getMapCanvas()
    if not WorldMapFrame then return nil, 1002, 668 end

    local canvas = nil
    if WorldMapFrame.GetCanvas then
        local ok, c = pcall(WorldMapFrame.GetCanvas, WorldMapFrame)
        if ok and c then canvas = c end
    end

    if not canvas and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child then
        canvas = WorldMapFrame.ScrollContainer.Child
    end

    if not canvas and WorldMapFrame.ScrollContainer then
        canvas = WorldMapFrame.ScrollContainer
    end

    if not canvas and WorldMapButton then canvas = WorldMapButton end
    if not canvas and WorldMapDetailFrame then canvas = WorldMapDetailFrame end
    if not canvas then canvas = WorldMapFrame end

    local cw = canvas:GetWidth() or 0
    local ch = canvas:GetHeight() or 0

    if cw <= 10 or ch <= 10 then
        if WorldMapFrame.ScrollContainer then
            cw = WorldMapFrame.ScrollContainer:GetWidth() or 0
            ch = WorldMapFrame.ScrollContainer:GetHeight() or 0
        end
    end

    if cw <= 10 or ch <= 10 then
        cw = WorldMapFrame:GetWidth() or 1002
        ch = WorldMapFrame:GetHeight() or 668
    end

    return canvas, cw, ch
end

--- Ajusta a ancoragem do botão da guilda no canto superior direito do WorldMapFrame.
function WorldMapView:reanchorMapButton()
    local mapButton = self._mapButton
    if not mapButton or not WorldMapFrame then return end

    mapButton:ClearAllPoints()
    local anchorFrame = nil
    if WorldMapFrame.MaximizeMinimizeFrame and WorldMapFrame.MaximizeMinimizeFrame:IsShown() then
        anchorFrame = WorldMapFrame.MaximizeMinimizeFrame
    elseif WorldMapFrame.BorderFrame and WorldMapFrame.BorderFrame.MaximizeMinimizeFrame and WorldMapFrame.BorderFrame.MaximizeMinimizeFrame:IsShown() then
        anchorFrame = WorldMapFrame.BorderFrame.MaximizeMinimizeFrame
    elseif WorldMapFrameSizeDownButton and WorldMapFrameSizeDownButton:IsShown() then
        anchorFrame = WorldMapFrameSizeDownButton
    elseif WorldMapFrameSizeUpButton and WorldMapFrameSizeUpButton:IsShown() then
        anchorFrame = WorldMapFrameSizeUpButton
    elseif WorldMapFrameCloseButton and WorldMapFrameCloseButton:IsShown() then
        anchorFrame = WorldMapFrameCloseButton
    elseif WorldMapFrame.BorderFrame and WorldMapFrame.BorderFrame.CloseButton and WorldMapFrame.BorderFrame.CloseButton:IsShown() then
        anchorFrame = WorldMapFrame.BorderFrame.CloseButton
    elseif WorldMapFrameCloseButton then
        anchorFrame = WorldMapFrameCloseButton
    elseif WorldMapFrame.CloseButton then
        anchorFrame = WorldMapFrame.CloseButton
    end

    if anchorFrame then
        local isCloseBtn = (anchorFrame == WorldMapFrameCloseButton)
            or (WorldMapFrame.BorderFrame and anchorFrame == WorldMapFrame.BorderFrame.CloseButton)
            or (anchorFrame == WorldMapFrame.CloseButton)
        local xOffset = isCloseBtn and -32 or -6
        mapButton:SetPoint("RIGHT", anchorFrame, "LEFT", xOffset, 0)
    else
        mapButton:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -65, -4)
    end
end

--- Cria ou obtém um pino persistente diretamente no canvas para o jogador remoto
---@param name string
---@param canvas table
---@return table
function WorldMapView:getOrCreateNamedPin(name, canvas)
    if not self._pins then self._pins = {} end
    local pin = self._pins[name]
    if pin then
        if pin:GetParent() ~= canvas then
            pin:SetParent(canvas)
        end
        return pin
    end

    pin = CreateFrame("Button", "GM_RealtimePin_" .. name, canvas)
    pin:SetSize(26, 26)
    pin:SetFrameStrata("HIGH")
    pin:SetFrameLevel(2500)
    pin:EnableMouse(true)

    -- Glow/Halo pulsante com a cor da classe
    local glow = pin:CreateTexture(nil, "BACKGROUND", nil, -1)
    glow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    glow:SetSize(34, 34)
    glow:SetPoint("CENTER", pin, "CENTER", 0, 0)
    glow:SetBlendMode("ADD")
    pin.glow = glow

    -- Seta direcional GPS atrás do ícone (aponta o rumo exato da bússola)
    local arrow = pin:CreateTexture(nil, "BORDER", nil, 1)
    arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    arrow:SetSize(30, 30)
    arrow:SetPoint("CENTER", pin, "CENTER", 0, 0)
    pin.arrow = arrow

    -- Ícone oficial circular da classe no centro
    local classIcon = pin:CreateTexture(nil, "ARTWORK", nil, 2)
    classIcon:SetSize(22, 22)
    classIcon:SetPoint("CENTER", pin, "CENTER", 0, 0)
    pin.classIcon = classIcon

    -- Anel / Borda circular metálica ao redor do ícone
    local border = pin:CreateTexture(nil, "OVERLAY", nil, 3)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(46, 46)
    border:SetPoint("CENTER", pin, "CENTER", 10, -10)
    pin.border = border

    -- Nome do jogador com sombra forte acima do pino
    local label = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOM", pin, "TOP", 0, 5)
    label:SetJustifyH("CENTER")
    label:SetShadowOffset(1, -1)
    label:SetShadowColor(0, 0, 0, 1)
    pin.label = label

    pin:SetScript("OnEnter", function(p)
        if not p.peerData then return end
        local d = p.peerData
        local cls = (d.classFile or d.class or "WARRIOR"):upper()
        local c = CLASS_COLORS[cls] or { r = 0.2, g = 0.8, b = 1.0, hex = "|cffffffff" }

        GameTooltip:SetOwner(p, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(string.format("%s%s|r", c.hex, d.name), 1, 1, 1)

        if d.guild and d.guild ~= "" then
            GameTooltip:AddLine(string.format("|cff20ff20<%s>|r", d.guild), 0.2, 1, 0.2)
        end

        local curL = (_G.GM and _G.GM.L) or _G.L or L
        GameTooltip:AddDoubleLine(curL["MAP_PIN_LEVEL_CLASS"] or "Level & Class:", string.format("|cffffffff%d %s %s|r", d.level or 1, d.race or "", cls), 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(curL["MAP_PIN_REGION"] or "Region:", string.format("|cffffd200%s|r (%.1f, %.1f)", d.zoneName or "Azeroth", (d.x or 0) * 100, (d.y or 0) * 100), 1, 0.82, 0, 1, 1, 1)

        local now = GetTime and GetTime() or 0
        local diff = math.max(0, math.floor(now - (d.lastSeen or now)))
        local seenStr = (diff < 3) and (curL["MAP_PIN_LIVE"] or "|cff20ff20Live|r") or string.format(curL["MAP_PIN_SEEN_AGO"] or "%d s ago", diff)
        GameTooltip:AddDoubleLine(curL["MAP_PIN_SIGNAL"] or "AddOn Signal:", seenStr, 0.7, 0.7, 0.7, 1, 1, 1)

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(curL["MAP_PIN_LCLICK_WHISPER"] or "|cffaaaaaaLeft-Click to whisper|r", 0.6, 0.6, 0.6)
        GameTooltip:AddLine(curL["MAP_PIN_SYNC_TITLE"] or "|cff00ff00GuildManager • Real-Time Sync|r", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)

    pin:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    pin:SetScript("OnClick", function(p, btn)
        if (btn == "LeftButton" or not btn) and p.peerData and p.peerData.name then
            if ChatFrame_OpenChat then
                ChatFrame_OpenChat("/w " .. p.peerData.name .. " ")
            end
        end
    end)

    self._pins[name] = pin
    return pin
end

--- Garante e atualiza o badge de membros online no topo do WorldMapFrame oficial
function WorldMapView:ensureRealtimeBadge()
    if self._realtimeBadge or not WorldMapFrame then return end

    local badgeBtn = CreateFrame("Button", "GM_WorldMapPeerBadge", WorldMapFrame, "UIPanelButtonTemplate")
    badgeBtn:SetSize(140, 22)
    badgeBtn:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -180, -2)
    badgeBtn:SetFrameStrata("HIGH")
    badgeBtn:SetFrameLevel(3000)
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    badgeBtn:SetText(curL["MAP_BADGE_MEMBERS_ZERO"] or "|TInterface\\Icons\\INV_Misc_GroupNeedMore:14:14:0:0|t |cffffd200Members (0)|r")

    badgeBtn:SetScript("OnClick", function()
        local locService = _G.GM and _G.GM.locationService
        local peers = locService and locService:getPeers() or {}
        local peerList = {}
        for _, p in pairs(peers) do
            table.insert(peerList, p)
        end

        if #peerList == 1 and peerList[1].mapID and WorldMapFrame and WorldMapFrame.SetMapID then
            local targetMapID = peerList[1].mapID
            local currentMapID = GetCurrentWorldMapID()
            if targetMapID ~= currentMapID then
                WorldMapFrame:SetMapID(targetMapID)
                return
            end
        end

        self:togglePanel()
    end)

    badgeBtn:SetScript("OnEnter", function(btn)
        local cL = (_G.GM and _G.GM.L) or _G.L or L
        local locService = _G.GM and _G.GM.locationService
        local peers = locService and locService:getPeers() or {}
        local viewMapID = GetCurrentWorldMapID()

        GameTooltip:SetOwner(btn, "ANCHOR_BOTTOMLEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(cL["MAP_BADGE_TOOLTIP_TITLE"] or "|TInterface\\Icons\\INV_Misc_GroupNeedMore:16:16:0:0|t |cffffd200Members with GuildManager|r", 1, 1, 1)
        GameTooltip:AddLine(cL["MAP_BADGE_TOOLTIP_DESC"] or "|cff888888Positions synced in real time:|r", 0.7, 0.7, 0.7)

        local hasAny = false
        for name, p in pairs(peers) do
            if not (locService and locService.isSelf and locService:isSelf(p.name)) then
                hasAny = true
                local cls = (p.classFile or p.class or "WARRIOR"):upper()
                local c = CLASS_COLORS[cls] or { hex = "|cffffffff" }
                local isHere = (p.mapID == viewMapID)
                local statusStr = isHere and (cL["MAP_BADGE_IN_THIS_ZONE"] or "|cff20ff20In This Zone|r") or string.format("|cffffd200%s|r", p.zoneName or "Azeroth")

                GameTooltip:AddDoubleLine(
                    string.format("%s%s|r (Nv %d %s)", c.hex, p.name, p.level or 1, p.race or ""),
                    string.format("%s (%.1f, %.1f)", statusStr, (p.x or 0) * 100, (p.y or 0) * 100),
                    1, 1, 1, 1, 1, 1
                )
            end
        end

        if not hasAny then
            GameTooltip:AddLine(cL["MAP_BADGE_NO_MEMBERS"] or "|cffaaaaaaNo other member online right now.|r", 0.7, 0.7, 0.7)
            GameTooltip:AddLine(cL["MAP_BADGE_TIP_SIMULATE"] or "|cff55ff55Tip: Use /gmloc test to simulate a member on map!|r", 0.3, 0.9, 0.3)
        else
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(cL["MAP_BADGE_CLICK_HINT"] or "|cff00ff00Click to open member zone or side panel|r", 0.2, 0.8, 0.2)
        end

        GameTooltip:Show()
    end)

    badgeBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self._realtimeBadge = badgeBtn
end

--- Atualiza o texto do badge superior com a contagem ao vivo
function WorldMapView:updateRealtimeBadge()
    self:ensureRealtimeBadge()
    if not self._realtimeBadge then return end

    local cL = (_G.GM and _G.GM.L) or _G.L or L
    local locService = _G.GM and _G.GM.locationService
    local count = (locService and locService.getPeerCount and tonumber(locService:getPeerCount())) or 0
    if count and count > 0 then
        self._realtimeBadge:SetText(string.format(cL["MAP_BADGE_MEMBERS"] or "|TInterface\\Icons\\INV_Misc_GroupNeedMore:14:14:0:0|t |cff20ff20Members (%d)|r", count))
    else
        self._realtimeBadge:SetText(cL["MAP_BADGE_MEMBERS_ZERO"] or "|TInterface\\Icons\\INV_Misc_GroupNeedMore:14:14:0:0|t |cffffd200Members (0)|r")
    end
end

--- Atualiza a renderização contínua de todos os pinos de jogadores remotos no mapa oficial da Blizzard
function WorldMapView:updateRealtimePins()
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end

    local locService = _G.GM and _G.GM.locationService
    if not locService then return end

    local canvas, cw, ch = self:getMapCanvas()
    if not canvas or cw <= 10 or ch <= 10 then return end

    local viewMapID = GetCurrentWorldMapID()
    if not viewMapID then return end

    local peers = locService:getPeers() or {}

    for name, peer in pairs(peers) do
        if not (locService and locService.isSelf and locService:isSelf(peer.name)) then
            local rx, ry = TranslateCoordsToViewMap(peer.mapID, peer.x, peer.y, viewMapID)
            local pin = self:getOrCreateNamedPin(name, canvas)
            pin.peerData = peer

            if rx and ry then
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", canvas, "TOPLEFT", rx * cw, -ry * ch)

                local cls = (peer.classFile or peer.class or "WARRIOR"):upper()
                local c = CLASS_COLORS[cls] or { r = 0.2, g = 0.8, b = 1.0, hex = "|cffffffff" }

                pin.arrow:SetVertexColor(c.r or 1, c.g or 1, c.b or 1, 0.95)
                pin.glow:SetVertexColor(c.r or 1, c.g or 1, c.b or 1, 0.75)

                ApplyClassIcon(pin.classIcon, cls)

                if pin.arrow.SetRotation then
                    pcall(pin.arrow.SetRotation, pin.arrow, peer.facing or 0)
                end

                pin.label:SetText(string.format("%s%s|r", c.hex or "|cffffffff", peer.name))
                pin:Show()
            else
                pin:Hide()
            end
        end
    end

    -- Esconde pinos de jogadores que não estão mais conectados
    if self._pins then
        for name, pin in pairs(self._pins) do
            if not peers[name] then
                pin:Hide()
            end
        end
    end

    self:updateRealtimeBadge()
end

--- Cria frame filho de atualização contínua a 20 FPS (0.05s) para renderização ultra-suave
function WorldMapView:initUpdateFrame()
    if self._updateFrame or not WorldMapFrame then return end

    local updateFrame = CreateFrame("Frame", "GM_WorldMapUpdateFrame", WorldMapFrame)
    updateFrame:SetAllPoints(WorldMapFrame)
    updateFrame:Show()

    updateFrame:SetScript("OnShow", function()
        self:updateRealtimePins()
    end)

    local ticker = 0
    updateFrame:SetScript("OnUpdate", function(_, elapsed)
        ticker = ticker + elapsed
        if ticker >= 0.05 then
            ticker = 0
            self:updateRealtimePins()
        end
    end)

    self._updateFrame = updateFrame
end

--- Inicializa os componentes visuais vinculados à tela nativa de mapa (WorldMapFrame).
function WorldMapView:initWorldMapUI()
    if not WorldMapFrame then return end

    self:initUpdateFrame()
    self:ensureRealtimeBadge()

    if self._mapButton then
        return
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    -- =========================================================================
    -- BOTÃO DE INFORMAÇÃO DA GUILDA NA BARRA SUPERIOR DIREITA DO MAPA
    -- =========================================================================
    local mapButton = CreateFrame("Button", "GM_WorldMapButton", WorldMapFrame, template)
    mapButton:SetSize(145, 22)
    mapButton:SetFrameStrata("HIGH")
    mapButton:SetFrameLevel((WorldMapFrame:GetFrameLevel() or 10) + 20)
    self._mapButton = mapButton
    self:reanchorMapButton()

    if mapButton.SetBackdrop then
        mapButton:SetBackdrop(MAP_BUTTON_BACKDROP)
        mapButton:SetBackdropColor(0.18, 0.12, 0.04, 0.95)
        mapButton:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
    end

    -- Brilho / Aura Dourada ao redor do botão
    local btnGlow = mapButton:CreateTexture(nil, "BACKGROUND", nil, -1)
    btnGlow:SetPoint("TOPLEFT", mapButton, "TOPLEFT", -3, 3)
    btnGlow:SetPoint("BOTTOMRIGHT", mapButton, "BOTTOMRIGHT", 3, -3)
    btnGlow:SetTexture("Interface\\ChatFrame\\ChatFrameTab-NewMessage")
    btnGlow:SetVertexColor(1.0, 0.82, 0.0, 0.55)
    btnGlow:SetBlendMode("ADD")
    mapButton.glow = btnGlow

    -- Ícone oficial do Tabardo da Guilda
    local icon = mapButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", mapButton, "LEFT", 5, 0)
    icon:SetTexture("Interface\\Icons\\INV_Shirt_GuildTabard_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    mapButton.icon = icon

    local btnText = mapButton:CreateFontString(nil, "OVERLAY")
    btnText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    btnText:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    btnText:SetPoint("RIGHT", mapButton, "RIGHT", -4, 0)
    btnText:SetJustifyH("LEFT")
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    btnText:SetText(string.format(curL["MAP_BTN_IN_REGION"] or "|cffffd200Guild:|r %s%d %s|r", "|cff00ff00", 0, curL["MAP_BTN_ZONE_SCOPE"] or "in Region"))
    mapButton.text = btnText

    local btnHighlight = mapButton:CreateTexture(nil, "HIGHLIGHT")
    btnHighlight:SetAllPoints(mapButton)
    btnHighlight:SetColorTexture(1.0, 0.85, 0.30, 0.30)
    mapButton:SetHighlightTexture(btnHighlight)

    mapButton:SetScript("OnEnter", function(btn)
        local cL = (_G.GM and _G.GM.L) or _G.L or L
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(1.0, 0.95, 0.40, 1.0)
            btn:SetBackdropColor(0.24, 0.16, 0.05, 1.0)
        end
        if btn.glow then
            btn.glow:SetVertexColor(1.0, 0.95, 0.40, 0.90)
        end
        GameTooltip:SetOwner(btn, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:AddLine(cL["MAP_PANEL_TOOLTIP_HEADER"] or "|cffffd200GuildManager - Members in Region|r")
        GameTooltip:AddLine(cL["MAP_PANEL_TOOLTIP_DESC"] or "Shows guild members currently present in this map region.", 1, 1, 1, true)

        local locService = _G.GM and _G.GM.locationService
        local addonUsers = locService and locService:getGuildAddonUsers() or {}
        if #addonUsers > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(string.format(cL["MAP_PANEL_TOOLTIP_ACTIVE"] or "|cff00ff00Members with Active AddOn (%d):|r", #addonUsers), 1, 1, 1)
            for _, u in ipairs(addonUsers) do
                local clsHex = (CLASS_COLORS and CLASS_COLORS[u.class] and CLASS_COLORS[u.class].hex) or "|cffffffff"
                local selfTag = u.isSelf and (cL["MAP_PANEL_TOOLTIP_YOU"] or " |cff00ff00(You)|r") or ""
                local zoneStr = (u.zone and u.zone ~= "") and (" - |cff00e5ff" .. u.zone .. "|r") or ""
                GameTooltip:AddLine(string.format("  • %s%s|r%s (Lvl %d)%s", clsHex, u.name, selfTag, u.level or 1, zoneStr), 1, 1, 1)
            end
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(cL["MAP_PANEL_TOOLTIP_CLICK"] or "|cff00ff00Click to toggle side panel and view full list.|r", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    mapButton:SetScript("OnLeave", function(btn)
        self:updateButtonState()
        GameTooltip:Hide()
    end)

    mapButton:SetScript("OnClick", function()
        self:togglePanel()
    end)

    self._mapButton = mapButton

    -- =========================================================================
    -- PAINEL LATERAL ACOPLADO AO WORLD MAP NATIVO
    -- =========================================================================
    local panel = CreateFrame("Frame", "GM_WorldMapPanel", WorldMapFrame, template)
    panel:SetWidth(270)
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel((WorldMapFrame:GetFrameLevel() or 10) + 10)
    panel:Hide()

    if panel.SetBackdrop then
        panel:SetBackdrop(CONTAINER_BACKDROP)
        panel:SetBackdropColor(PALETTE.FRAME_BG[1], PALETTE.FRAME_BG[2], PALETTE.FRAME_BG[3], 0.96)
        panel:SetBackdropBorderColor(PALETTE.FRAME_BORDER[1], PALETTE.FRAME_BORDER[2], PALETTE.FRAME_BORDER[3], 1.0)
    end

    self._panel = panel

    -- Título do Painel
    local headerTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
    headerTitle:SetText(curL["MAP_PANEL_HEADER"] or "|cffffd200Members in Region|r")
    panel.headerTitle = headerTitle

    -- Botão Fechar Painel (X)
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        self:hidePanel()
    end)

    -- Nome da Região / Zona Atual
    local zoneTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneTitle:SetPoint("TOPLEFT", headerTitle, "BOTTOMLEFT", 0, -4)
    zoneTitle:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
    zoneTitle:SetJustifyH("LEFT")
    zoneTitle:SetText(curL["MAP_CURRENT_REGION"] or "|cff00e5ffCurrent Region|r")
    panel.zoneTitle = zoneTitle

    -- Contador de membros encontrados
    local countText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    countText:SetPoint("TOPLEFT", zoneTitle, "BOTTOMLEFT", 0, -2)
    countText:SetText(string.format(curL["MAP_FOUND_COUNT"] or "|cffaaaaaaMembers found: %d|r", 0))
    panel.countText = countText

    -- Linha divisória ornamental
    local sep = panel:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", countText, "BOTTOMLEFT", 0, -6)
    sep:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    sep:SetColorTexture(PALETTE.SEPARATOR[1], PALETTE.SEPARATOR[2], PALETTE.SEPARATOR[3], PALETTE.SEPARATOR[4])

    -- Botão de Escanear / Atualizar Região
    local scanBtn = CreateFrame("Button", nil, panel, template)
    scanBtn:SetSize(110, 20)
    scanBtn:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -6)
    if scanBtn.SetBackdrop then
        scanBtn:SetBackdrop(SUB_CONTAINER_BACKDROP)
        scanBtn:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.90)
        scanBtn:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.85)
    end
    local scanBtnTxt = scanBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scanBtnTxt:SetPoint("CENTER", scanBtn, "CENTER", 0, 0)
    scanBtnTxt:SetText(curL["MAP_SCAN_BTN"] or "Scan Map")
    panel.scanBtnTxt = scanBtnTxt
    scanBtn:SetScript("OnEnter", function(b)
        if b.SetBackdropBorderColor then
            b:SetBackdropBorderColor(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], 1.0)
        end
    end)
    scanBtn:SetScript("OnLeave", function(b)
        if b.SetBackdropBorderColor then
            b:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.85)
        end
    end)
    scanBtn:SetScript("OnClick", function()
        if self._onScanCallback then
            self._onScanCallback()
        end
    end)

    -- Container da Lista de Membros
    local listContainer = CreateFrame("Frame", nil, panel, template)
    listContainer:SetPoint("TOPLEFT", scanBtn, "BOTTOMLEFT", 0, -6)
    listContainer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 36)
    if listContainer.SetBackdrop then
        listContainer:SetBackdrop(SUB_CONTAINER_BACKDROP)
        listContainer:SetBackdropColor(PALETTE.INSET_BG[1], PALETTE.INSET_BG[2], PALETTE.INSET_BG[3], 0.90)
        listContainer:SetBackdropBorderColor(PALETTE.INSET_BORDER[1], PALETTE.INSET_BORDER[2], PALETTE.INSET_BORDER[3], 0.80)
    end
    panel.listContainer = listContainer

    listContainer.SetVerticalScroll = function() end

    -- ScrollBar para a lista
    local scrollBar = CreateFrame("Slider", "GM_WorldMapPanelScrollBar", listContainer, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPRIGHT", listContainer, "TOPRIGHT", -2, -18)
    scrollBar:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -2, 18)
    scrollBar:SetWidth(16)
    scrollBar:SetScript("OnValueChanged", function(_, val)
        self._scrollOffset = math.floor(val)
        self:refreshVisibleRows()
    end)
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValueStep(1)
    scrollBar:SetValue(0)
    scrollBar:Hide()
    self._scrollBar = scrollBar

    listContainer:EnableMouseWheel(true)
    listContainer:SetScript("OnMouseWheel", function(_, delta)
        local cur = self._scrollOffset or 0
        local maxVal = math.max(0, #self._membersData - self._maxVisibleRows)
        if delta < 0 and cur < maxVal then
            scrollBar:SetValue(cur + 1)
        elseif delta > 0 and cur > 0 then
            scrollBar:SetValue(cur - 1)
        end
    end)

    -- Mensagem caso não haja nenhum membro na região
    local emptyMsg = listContainer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyMsg:SetPoint("CENTER", listContainer, "CENTER", 0, 0)
    emptyMsg:SetText(curL["MAP_EMPTY_MSG"] or "No guild members\nfound in this region.")
    emptyMsg:Hide()
    panel.emptyMsg = emptyMsg

    -- Rodapé explicativo
    local footer = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footer:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 8)
    footer:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    footer:SetJustifyH("LEFT")
    footer:SetText(curL["MAP_FOOTER_HINT"] or "|cff888888Click member to whisper.|r")
    panel.footer = footer

    -- Criação dos rows visíveis
    for i = 1, self._maxVisibleRows do
        local row = CreateFrame("Button", nil, listContainer, template)
        row:SetHeight(self._rowHeight)
        row:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 4, -4 - (i - 1) * self._rowHeight)
        row:SetPoint("RIGHT", listContainer, "RIGHT", -20, 0)

        if row.SetBackdrop then
            row:SetBackdrop(SUB_CONTAINER_BACKDROP)
            row:SetBackdropColor(PALETTE.SUB_BOX_BG[1], PALETTE.SUB_BOX_BG[2], PALETTE.SUB_BOX_BG[3], 0.70)
            row:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.50)
        end

        local classIcon = row:CreateTexture(nil, "ARTWORK")
        classIcon:SetSize(26, 26)
        classIcon:SetPoint("LEFT", row, "LEFT", 6, 0)
        classIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        row.classIcon = classIcon

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 38, -6)
        nameText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        nameText:SetHeight(14)
        nameText:SetJustifyH("LEFT")
        nameText:SetJustifyV("MIDDLE")
        nameText:SetWordWrap(false)
        row.nameText = nameText

        local subText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        subText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -3)
        subText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        subText:SetHeight(12)
        subText:SetJustifyH("LEFT")
        subText:SetJustifyV("MIDDLE")
        subText:SetWordWrap(false)
        row.subText = subText

        local rowHl = row:CreateTexture(nil, "HIGHLIGHT")
        rowHl:SetAllPoints(row)
        rowHl:SetColorTexture(PALETTE.HIGHLIGHT_TINT[1], PALETTE.HIGHLIGHT_TINT[2], PALETTE.HIGHLIGHT_TINT[3], 0.25)
        row:SetHighlightTexture(rowHl)

        row:SetScript("OnEnter", function(r)
            if r.SetBackdropBorderColor then
                r:SetBackdropBorderColor(PALETTE.FOCUS_BORDER[1], PALETTE.FOCUS_BORDER[2], PALETTE.FOCUS_BORDER[3], 1.0)
            end
            if r.memberData then
                local curL = (_G.GM and _G.GM.L) or _G.L or L
                local data = r.memberData
                GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
                local cHex = (data.class and CLASS_COLORS[data.class] and CLASS_COLORS[data.class].hex) or "|cffffffff"
                GameTooltip:AddLine(cHex .. (data.name or curL["MEMBER"] or "Member") .. "|r")
                GameTooltip:AddLine(string.format(curL["MAP_ROW_LEVEL_CLASS"] or "Level %d %s", data.level or 1, data.classDisplayName or data.class or ""), 1, 1, 1)
                if data.rankName and data.rankName ~= "" then
                    GameTooltip:AddLine(string.format(curL["MAP_ROW_RANK"] or "Rank: |cffffff00%s|r", data.rankName), 0.9, 0.8, 0.5)
                end
                if data.zone and data.zone ~= "" then
                    GameTooltip:AddLine(string.format(curL["MAP_ROW_ZONE"] or "Region: |cffffffff%s|r", data.zone), 0.8, 0.8, 0.8)
                end
                if data.publicNote and data.publicNote ~= "" then
                    GameTooltip:AddLine(string.format(curL["MAP_ROW_PUB_NOTE"] or "Public Note: %s", data.publicNote), 0.7, 0.7, 0.7, true)
                end
                if data.officerNote and data.officerNote ~= "" then
                    GameTooltip:AddLine(string.format(curL["MAP_ROW_OFF_NOTE"] or "Officer Note: %s", data.officerNote), 0.7, 0.7, 0.7, true)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(curL["MAP_ROW_WHISPER_HINT"] or "|cff00ff00Click to whisper player.|r", 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end
        end)

        row:SetScript("OnLeave", function(r)
            if r.SetBackdropBorderColor then
                r:SetBackdropBorderColor(PALETTE.SUB_BOX_BORDER[1], PALETTE.SUB_BOX_BORDER[2], PALETTE.SUB_BOX_BORDER[3], 0.50)
            end
            GameTooltip:Hide()
        end)

        row:SetScript("OnClick", function(r)
            if r.memberData and r.memberData.name then
                if self._onMemberClickCallback then
                    self._onMemberClickCallback(r.memberData)
                else
                    ChatFrame_OpenChat("/w " .. r.memberData.name .. " ")
                end
            end
        end)

        row:Hide()
        self._memberRows[i] = row
    end
end

--- Atualiza o posicionamento do painel garantindo que fique dentro dos limites da tela.
function WorldMapView:adjustPanelPosition()
    local panel = self._panel
    if not panel or not WorldMapFrame then return end

    panel:ClearAllPoints()
    local mapRight = WorldMapFrame:GetRight() or 0
    local screenWidth = GetScreenWidth() or 1920

    if (mapRight + 275) <= screenWidth then
        panel:SetPoint("TOPLEFT", WorldMapFrame, "TOPRIGHT", 2, 0)
        panel:SetPoint("BOTTOMLEFT", WorldMapFrame, "BOTTOMRIGHT", 2, 0)
    else
        panel:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -4, -30)
        panel:SetPoint("BOTTOMRIGHT", WorldMapFrame, "BOTTOMRIGHT", -4, 30)
    end
end

--- Abre ou fecha o painel de membros na região.
function WorldMapView:togglePanel()
    if self._isPanelOpen then
        self:hidePanel()
    else
        self:showPanel()
    end
end

--- Atualiza o estado visual do botão inferior (ativo / inativo).
function WorldMapView:updateButtonState()
    if self._mapButton then
        if self._isPanelOpen then
            if self._mapButton.SetBackdropColor then
                self._mapButton:SetBackdropColor(0.25, 0.17, 0.05, 1.0)
                self._mapButton:SetBackdropBorderColor(1.0, 0.95, 0.35, 1.0)
            end
            if self._mapButton.glow then
                self._mapButton.glow:SetVertexColor(1.0, 0.95, 0.35, 0.85)
            end
        else
            if self._mapButton.SetBackdropColor then
                self._mapButton:SetBackdropColor(0.18, 0.12, 0.04, 0.95)
                self._mapButton:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
            end
            if self._mapButton.glow then
                self._mapButton.glow:SetVertexColor(1.0, 0.82, 0.0, 0.55)
            end
        end
    end
end

--- Exibe o painel de membros da guilda na região.
function WorldMapView:showPanel()
    self:initWorldMapUI()
    if not self._panel then return end

    self:adjustPanelPosition()
    self._panel:Show()
    self._isPanelOpen = true
    self:updateButtonState()

    if self._onScanCallback then
        self._onScanCallback()
    else
        self:refreshVisibleRows()
    end
end

--- Oculta o painel de membros da guilda.
function WorldMapView:hidePanel()
    if self._panel then
        self._panel:Hide()
    end
    self._isPanelOpen = false
    self:updateButtonState()
end

--- Retorna se o painel está aberto.
---@return boolean
function WorldMapView:isPanelShown()
    return self._isPanelOpen == true and self._panel and self._panel:IsShown()
end

--- Atualiza o texto do botão na barra do mapa com a quantidade de membros na região/continente.
---@param count number
---@param isContinent boolean|nil
---@param isWorld boolean|nil
function WorldMapView:updateButton(count, isContinent, isWorld)
    if not self._mapButton then
        self:initWorldMapUI()
    end
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    local num = tonumber(count) or 0
    local color = num > 0 and "|cff00ff00" or "|cffaaaaaa"
    local scopeText = isWorld and (curL["MAP_BTN_WORLD_SCOPE"] or "in World") or (isContinent and (curL["MAP_BTN_CONT_SCOPE"] or "in Continent") or (curL["MAP_BTN_ZONE_SCOPE"] or "in Region"))
    if self._mapButton and self._mapButton.text then
        self._mapButton.text:SetText(string.format(curL["MAP_BTN_IN_REGION"] or "|cffffd200Guild:|r %s%d %s|r", color, num, scopeText))
    end
    self:reanchorMapButton()
    self:updateButtonState()
end

--- Renderiza a lista de membros no painel lateral do mapa.
---@param membersData table @Lista de membros presentes na região/continente
---@param zoneName string @Nome da região visualizada no mapa
---@param isContinent boolean|nil @Indica se o mapa atual é um continente
---@param isWorld boolean|nil @Indica se o mapa atual é o mundo global
function WorldMapView:renderMembers(membersData, zoneName, isContinent, isWorld)
    local curL = (_G.GM and _G.GM.L) or _G.L or L
    self._membersData = membersData or {}
    self._currentZoneName = zoneName or (curL["MAP_CURRENT_REGION"] or "Current Region")
    self._isContinentView = isContinent == true
    self._isWorldView = isWorld == true

    if not self._panel then
        self:initWorldMapUI()
    end

    if self._panel then
        self._panel.zoneTitle:SetText("|cff00e5ff" .. self._currentZoneName .. "|r")
        local scopeText = isWorld and (curL["MAP_BTN_WORLD_SCOPE"] or "in World") or (isContinent and (curL["MAP_BTN_CONT_SCOPE"] or "in Continent") or (curL["MAP_BTN_ZONE_SCOPE"] or "in Region"))
        self._panel.countText:SetText(string.format(curL["MAP_FOUND_COUNT_FORMAT"] or "|cffa8f0a8%d member(s) %s|r", #self._membersData, scopeText))
    end

    self:updateButton(#self._membersData, isContinent, isWorld)

    -- Atualiza os pinos em tempo real no mapa
    self:updateRealtimePins()

    -- Atualiza as linhas da lista lateral se o painel estiver aberto
    if self._isPanelOpen then
        self:refreshVisibleRows()
    end
end

--- Atualiza as linhas da tabela de membros no painel lateral.
function WorldMapView:refreshVisibleRows()
    local total = #self._membersData
    local offset = self._scrollOffset or 0

    if self._scrollBar then
        if total > self._maxVisibleRows then
            self._scrollBar:SetMinMaxValues(0, total - self._maxVisibleRows)
            self._scrollBar:Show()
        else
            self._scrollBar:SetMinMaxValues(0, 0)
            self._scrollBar:SetValue(0)
            self._scrollBar:Hide()
            self._scrollOffset = 0
            offset = 0
        end
    end

    if self._panel and self._panel.emptyMsg then
        if total == 0 then
            local emptyScope = self._isWorldView and "no mundo" or (self._isContinentView and "neste continente" or "nesta região")
            self._panel.emptyMsg:SetText(string.format("Nenhum membro da guilda\nencontrado %s.", emptyScope))
            self._panel.emptyMsg:Show()
        else
            self._panel.emptyMsg:Hide()
        end
    end

    for i = 1, self._maxVisibleRows do
        local row = self._memberRows[i]
        local dataIndex = offset + i
        local data = self._membersData[dataIndex]

        if data and row then
            row.memberData = data
            local cHex = (data.class and CLASS_COLORS[data.class] and CLASS_COLORS[data.class].hex) or "|cffffffff"
            local nameStr = cHex .. (data.name or "Membro") .. "|r"

            -- Ícone da classe
            local coords = data.class and CLASS_ICON_COORDS[data.class]
            if coords and row.classIcon then
                row.classIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
                row.classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                row.classIcon:Show()
            else
                row.classIcon:Hide()
            end

            -- Linha 1: Nome do personagem
            row.nameText:SetText(nameStr)

            -- Linha 2: Nível e Cargo (e Zona se estiver em visualização de Continente ou Mundo)
            local rankStr = data.rankName and data.rankName ~= "" and (" • |cffffff00" .. data.rankName .. "|r") or ""
            if (self._isContinentView or self._isWorldView) and data.zone and data.zone ~= "" then
                row.subText:SetText(string.format("Lvl %d%s • |cff00e5ff%s|r", data.level or 1, rankStr, data.zone))
            else
                row.subText:SetText(string.format("Lvl %d%s", data.level or 1, rankStr))
            end
            row:Show()
        elseif row then
            row.memberData = nil
            row:Hide()
        end
    end
end

--- Limpa e desativa todos os pinos de membros no mapa nativo.
function WorldMapView:clearPins()
    if self._pins then
        for _, pin in pairs(self._pins) do
            pin:Hide()
            pin:ClearAllPoints()
            pin.peerData = nil
        end
    end
end

--- Mantém os pinos atualizados ou limpos conforme o estado.
function WorldMapView:plotMemberPins()
    self:updateRealtimePins()
end

--- Define o callback acionado quando o usuário clica em "Escanear Mapa".
---@param callback function
function WorldMapView:setOnScanCallback(callback)
    self._onScanCallback = callback
end

--- Define o callback acionado quando o usuário clica em um membro na lista ou no pino.
---@param callback function
function WorldMapView:setOnMemberClickCallback(callback)
    self._onMemberClickCallback = callback
end

--- Atualiza dinamicamente todos os textos da interface do mapa de acordo com o idioma ativo
function WorldMapView:updateLocale()
    local curL = (_G.GM and _G.GM.L) or _G.L or L

    if self._panel then
        if self._panel.headerTitle then
            self._panel.headerTitle:SetText(curL["MAP_PANEL_HEADER"] or "|cffffd200Members in Region|r")
        end
        if self._panel.scanBtnTxt then
            self._panel.scanBtnTxt:SetText(curL["MAP_SCAN_BTN"] or "Scan Map")
        end
        if self._panel.emptyMsg then
            self._panel.emptyMsg:SetText(curL["MAP_EMPTY_MSG"] or "No guild members\nfound in this region.")
        end
        if self._panel.footer then
            self._panel.footer:SetText(curL["MAP_FOOTER_HINT"] or "|cff888888Click member to whisper.|r")
        end
        if self._currentZoneName and self._panel.zoneTitle then
            self._panel.zoneTitle:SetText("|cff00e5ff" .. self._currentZoneName .. "|r")
        end
        if self._membersData and self._panel.countText then
            local isWorld = self._isWorldView
            local isContinent = self._isContinentView
            local scopeText = isWorld and (curL["MAP_BTN_WORLD_SCOPE"] or "in World") or (isContinent and (curL["MAP_BTN_CONT_SCOPE"] or "in Continent") or (curL["MAP_BTN_ZONE_SCOPE"] or "in Region"))
            self._panel.countText:SetText(string.format(curL["MAP_FOUND_COUNT_FORMAT"] or "|cffa8f0a8%d member(s) %s|r", #self._membersData, scopeText))
        end
    end

    if self._membersData then
        self:updateButton(#self._membersData, self._isContinentView, self._isWorldView)
    elseif self._mapButton then
        self:updateButton(0, false, false)
    end

    self:updateRealtimeBadge()

    if self._isPanelOpen then
        self:refreshVisibleRows()
    end
end

