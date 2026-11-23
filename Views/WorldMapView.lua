---@class WorldMapView
---@field private _frame table|nil
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

--- Verifica se o mapa é o Mapa Mundi (Azeroth, Cósmico ou Mapa Global)
local function IsWorldOrCosmicMap(mapID)
    if not mapID then return false end
    if mapID == 947 or mapID == 946 then return true end
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        if ok and info and info.mapType ~= nil then
            if info.mapType == 0 or info.mapType == 1 then
                return true
            end
            if Enum and Enum.UIMapType then
                if info.mapType == Enum.UIMapType.Cosmic or info.mapType == Enum.UIMapType.World then
                    return true
                end
            end
        end
    end
    return false
end

--- Verifica se o mapa é um continente
local function IsContinentMap(mapID)
    if not mapID then return false end
    if mapID == 1414 or mapID == 1415 or mapID == 1945 or mapID == 113 or mapID == 424 or mapID == 572 then
        return true
    end
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        if ok and info and info.mapType ~= nil then
            if info.mapType == 2 then return true end
            if Enum and Enum.UIMapType and info.mapType == Enum.UIMapType.Continent then
                return true
            end
        end
    end
    return false
end

--- Identifica se o mapa é um continente, mundo ou mapa global
local function IsContinentOrWorld(mapID)
    return IsWorldOrCosmicMap(mapID) or IsContinentMap(mapID)
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
    if not (C_Map and C_Map.GetWorldPosFromMapPos) or not sourceMapID or not sourceX or not sourceY then
        return nil, nil
    end
    local v = MakeVector2D(sourceX, sourceY)
    local ok, r1, r2 = pcall(C_Map.GetWorldPosFromMapPos, sourceMapID, v)
    if ok and r1 and r2 then
        if type(r1) == "number" and (type(r2) == "table" or type(r2) == "userdata") then
            return r1, r2
        elseif (type(r1) == "table" or type(r1) == "userdata") and type(r2) == "number" then
            return r2, r1
        end
    end
    if ok and (type(r1) == "table" or type(r1) == "userdata") then
        local cID = 0
        if C_Map.GetMapInfo then
            local info = C_Map.GetMapInfo(sourceMapID)
            if info and info.parentMapID then cID = info.parentMapID end
        end
        return cID, r1
    end

    -- Fallback: se falhar na subzona, tenta calcular via mapa pai
    if C_Map and C_Map.GetMapInfo then
        local okInfo, info = pcall(C_Map.GetMapInfo, sourceMapID)
        if okInfo and info and info.parentMapID and info.parentMapID > 0 and info.parentMapID ~= sourceMapID then
            if C_Map.GetMapRectOnMap then
                local okR, minX, maxX, minY, maxY = pcall(C_Map.GetMapRectOnMap, sourceMapID, info.parentMapID)
                if okR and minX and maxX and minY and maxY and (maxX > minX) and (maxY > minY) then
                    local parentX = minX + sourceX * (maxX - minX)
                    local parentY = minY + sourceY * (maxY - minY)
                    local vParent = MakeVector2D(parentX, parentY)
                    local okP, pr1, pr2 = pcall(C_Map.GetWorldPosFromMapPos, info.parentMapID, vParent)
                    if okP and pr1 and pr2 then
                        if type(pr1) == "number" and (type(pr2) == "table" or type(pr2) == "userdata") then
                            return pr1, pr2
                        elseif (type(pr1) == "table" or type(pr1) == "userdata") and type(pr2) == "number" then
                            return pr2, pr1
                        end
                    end
                end
            end
        end
    end

    return nil, nil
end

--- Extrai as coordenadas (x, y) normalizadas no mapa alvo de forma universal e robusta
local function SafeGetMapPos(continentID, worldPos, targetMapID)
    if not (C_Map and C_Map.GetMapPosFromWorldPos) or not worldPos or not targetMapID then
        return nil, nil
    end
    local ok, r1, r2 = pcall(C_Map.GetMapPosFromWorldPos, continentID, worldPos, targetMapID)
    if not ok then return nil, nil end

    -- Caso 1: r1 é targetMapID (número) e r2 é Vector2D (tabela ou userdata) [padrão nativo do WoW]
    if type(r2) == "table" or type(r2) == "userdata" then
        if r2.GetXY then
            local okXY, x, y = pcall(r2.GetXY, r2)
            if okXY and type(x) == "number" and type(y) == "number" then
                return x, y
            end
        end
        if type(r2.x) == "number" and type(r2.y) == "number" then
            return r2.x, r2.y
        end
    end

    -- Caso 2: r1 é Vector2D (tabela ou userdata)
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

    -- Caso 3: r1 e r2 são diretamente números x, y
    if type(r1) == "number" and type(r2) == "number" then
        return r1, r2
    end

    return nil, nil
end

-- Parâmetros oficiais de projeção para o Mapa Mundi de Azeroth (mapID 947)
-- Baseado no UIMapAssignment da Blizzard e HereBeDragons-2.0
local AZEROTH_WORLD_MAP_DATA = {
    -- Eastern Kingdoms (Reinos do Leste) - instance 0
    [0] = { width = 44688.53, height = 29795.11, left = 32601.04, top = 9894.93 },
    -- Kalimdor - instance 1
    [1] = { width = 44878.66, height = 29916.10, left = 8723.96, top = 14824.53 },
    -- Northrend (Nortúndria) - instance 571
    [571] = { width = 47662.70, height = 31772.19, left = 25198.53, top = 11072.07 },
    -- Pandaria - instance 870
    [870] = { width = 53103.22, height = 35408.03, left = 28648.80, top = 30726.23 },
}

-- Compatibilidade dinâmica com versões de cliente
local buildNum = tonumber((select(4, GetBuildInfo()))) or 11506
if buildNum >= 30000 and buildNum < 50000 then
    -- Wrath / Cata
    AZEROTH_WORLD_MAP_DATA[0] = { width = 48033.24, height = 32020.80, left = 36867.97, top = 14848.84 }
    AZEROTH_WORLD_MAP_DATA[1] = { width = 47908.72, height = 31935.28, left = 8552.61, top = 18467.83 }
elseif buildNum >= 100000 then
    -- Retail
    AZEROTH_WORLD_MAP_DATA[0] = { width = 76153.14, height = 50748.62, left = 65008.24, top = 23827.51 }
    AZEROTH_WORLD_MAP_DATA[1] = { width = 77621.12, height = 51854.98, left = 12444.40, top = 28030.61 }
end

--- Extrai coordenadas mundiais absolutas (northSouth, westEast) em jardas de forma segura
local function ExtractWorldCoordinates(worldPos)
    if not worldPos then return nil, nil end
    local northSouth, westEast = nil, nil
    if worldPos.GetXY then
        local ok, r1, r2 = pcall(worldPos.GetXY, worldPos)
        if ok and type(r1) == "number" and type(r2) == "number" then
            northSouth, westEast = r1, r2
        end
    end
    if not northSouth and type(worldPos.x) == "number" and type(worldPos.y) == "number" then
        northSouth, westEast = worldPos.x, worldPos.y
    end
    return northSouth, westEast
end

--- Mapeia continentID / uiMapID para instanceID de coordenadas mundiais
local function GetInstanceIDForContinent(continentID, sourceMapID)
    if continentID == 0 or continentID == 1 or continentID == 571 or continentID == 870 or continentID == 530 then
        return continentID
    end
    if continentID == 1415 then return 0 end
    if continentID == 1414 then return 1 end
    if continentID == 113 then return 571 end
    if continentID == 1945 then return 530 end

    if sourceMapID and C_Map and C_Map.GetMapInfo then
        local cur = sourceMapID
        for _ = 1, 6 do
            local info = C_Map.GetMapInfo(cur)
            if not info or not info.parentMapID or info.parentMapID == 0 then break end
            if info.parentMapID == 1415 then return 0 end
            if info.parentMapID == 1414 then return 1 end
            if info.parentMapID == 113 then return 571 end
            if info.parentMapID == 1945 then return 530 end
            cur = info.parentMapID
        end
    end
    return continentID or 0
end

--- Traduz coordenadas entre zonas, continentes, subzonas e Mapa Mundi oficial da Blizzard
---@param sourceMapID number
---@param sourceX number
---@param sourceY number
---@param viewMapID number
---@return number|nil renderX, number|nil renderY
local function TranslateCoordsToViewMap(sourceMapID, sourceX, sourceY, viewMapID)
    if not sourceMapID or not viewMapID or not sourceX or not sourceY then return nil, nil end

    -- Nível 1: Mesma zona exata
    if sourceMapID == viewMapID then
        return sourceX, sourceY
    end

    -- Nível 2: Bounding box direto do mapa via C_Map.GetMapRectOnMap (nativo da Blizzard)
    if C_Map and C_Map.GetMapRectOnMap then
        local okR, minX, maxX, minY, maxY = pcall(C_Map.GetMapRectOnMap, sourceMapID, viewMapID)
        if okR and minX and maxX and minY and maxY and (maxX > minX) and (maxY > minY) then
            local rx = minX + sourceX * (maxX - minX)
            local ry = minY + sourceY * (maxY - minY)
            if rx >= 0 and rx <= 1 and ry >= 0 and ry <= 1 then
                return rx, ry
            end
        end
    end

    -- Nível 3: Projeção direta para MAPA MUNDI (Azeroth 947 ou Cósmico 946)
    if IsWorldOrCosmicMap(viewMapID) then
        local continentID, worldPos = SafeGetWorldPos(sourceMapID, sourceX, sourceY)
        if continentID and worldPos then
            -- 3A. Tenta conversão nativa da API se suportada pelo cliente para o mapa alvo
            local mx, my = SafeGetMapPos(continentID, worldPos, viewMapID)
            if mx and my and mx >= 0 and mx <= 1 and my >= 0 and my <= 1 then
                return mx, my
            end

            -- 3B. Projeção matemática precisa do Mapa Mundi de Azeroth (mapID 947) via coordenadas mundiais
            local instID = GetInstanceIDForContinent(continentID, sourceMapID)
            local projData = AZEROTH_WORLD_MAP_DATA[instID]
            if projData and projData.width > 0 and projData.height > 0 then
                local northSouth, westEast = ExtractWorldCoordinates(worldPos)
                if northSouth and westEast then
                    local azX = (projData.left - westEast) / projData.width
                    local azY = (projData.top - northSouth) / projData.height

                    if viewMapID == 947 or viewMapID ~= 946 then
                        if azX >= 0 and azX <= 1 and azY >= 0 and azY <= 1 then
                            return azX, azY
                        end
                    elseif viewMapID == 946 then
                        -- Projeção do Mapa Mundi de Azeroth para o Mapa Cósmico (946)
                        if C_Map and C_Map.GetMapRectOnMap then
                            local okC, cMinX, cMaxX, cMinY, cMaxY = pcall(C_Map.GetMapRectOnMap, 947, 946)
                            if okC and cMinX and cMaxX and cMinY and cMaxY and (cMaxX > cMinX) and (cMaxY > cMinY) then
                                local cx = cMinX + azX * (cMaxX - cMinX)
                                local cy = cMinY + azY * (cMaxY - cMinY)
                                if cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1 then
                                    return cx, cy
                                end
                            end
                        end
                        if azX >= 0 and azX <= 1 and azY >= 0 and azY <= 1 then
                            return azX, azY
                        end
                    end
                end
            end

            -- 3C. Caso seja Terralém (Outland 530) visualizada no mapa cósmico (946)
            if instID == 530 and (viewMapID == 946 or viewMapID == 947) then
                if C_Map and C_Map.GetMapRectOnMap then
                    local okO, oMinX, oMaxX, oMinY, oMaxY = pcall(C_Map.GetMapRectOnMap, 1945, viewMapID)
                    if okO and oMinX and oMaxX and oMinY and oMaxY then
                        local ox, oy = SafeGetMapPos(530, worldPos, 1945)
                        if ox and oy then
                            local rx = oMinX + ox * (oMaxX - oMinX)
                            local ry = oMinY + oy * (oMaxY - oMinY)
                            if rx >= 0 and rx <= 1 and ry >= 0 and ry <= 1 then
                                return rx, ry
                            end
                        end
                    end
                end
            end
        end
    end

    -- Nível 4: Visualização em Continente (ex: Kalimdor 1414, Reinos do Leste 1415, Nortúndria 113)
    if IsContinentMap(viewMapID) then
        local continentID, worldPos = SafeGetWorldPos(sourceMapID, sourceX, sourceY)
        if continentID and worldPos then
            local mx, my = SafeGetMapPos(continentID, worldPos, viewMapID)
            if mx and my and mx >= 0 and mx <= 1 and my >= 0 and my <= 1 then
                return mx, my
            end
        end
    end

    -- Nível 5: Micro-zona ou caverna cujo mapa pai é a zona visualizada
    if IsChildOfViewZone(viewMapID, sourceMapID) then
        local continentID, worldPos = SafeGetWorldPos(sourceMapID, sourceX, sourceY)
        if continentID and worldPos then
            local mx, my = SafeGetMapPos(continentID, worldPos, viewMapID)
            if mx and my and mx >= 0 and mx <= 1 and my >= 0 and my <= 1 then
                return mx, my
            end
        end
    end

    -- Nível 6: Resolução recursiva subindo pela árvore de pais (subzona -> zona -> mapa visualizado)
    if C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(sourceMapID)
        if info and info.parentMapID and info.parentMapID > 0 and info.parentMapID ~= sourceMapID then
            local okR, minX, maxX, minY, maxY = pcall(C_Map.GetMapRectOnMap, sourceMapID, info.parentMapID)
            if okR and minX and maxX and minY and maxY and (maxX > minX) and (maxY > minY) then
                local px = minX + sourceX * (maxX - minX)
                local py = minY + sourceY * (maxY - minY)
                return TranslateCoordsToViewMap(info.parentMapID, px, py, viewMapID)
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
---@param pinsEnabled boolean|nil
---@return WorldMapView
function WorldMapView:new(pinsEnabled)
    local instance = setmetatable({}, self)
    instance._pinsEnabled = (pinsEnabled ~= false)
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
    instance._updateFrame = nil

    return instance
end

--- Escala fixa (40%) para todos os marcadores de membros da guilda no Mapa do Jogo.
local FIXED_PIN_SCALE = 0.40

--- Informa se o sistema de pins de membros no Mapa do Jogo está ativo nesta sessão.
---@return boolean
function WorldMapView:isPinsEnabled()
    return self._pinsEnabled == true
end

--- Oculta/pausa ou restaura temporariamente os pins do Mapa do Jogo enquanto aguarda /reload.
---@param hidden boolean
function WorldMapView:setPinsHiddenUntilReload(hidden)
    if not self._pinsEnabled then return end
    if hidden then
        self:clearPins()
        if self._updateFrame then self._updateFrame:Hide() end
    else
        if self._updateFrame then self._updateFrame:Show() end
        if WorldMapFrame and WorldMapFrame:IsShown() then
            self:updateRealtimePins()
        end
    end
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

--- Retorna a escala fixa (40%) para os marcadores de membros da guilda no mapa.
---@return number scale
function WorldMapView:getPinScale()
    return FIXED_PIN_SCALE
end

--- Aplica a escala gráfica fixa (40%) em um pino redimensionando seus elementos em torno do centro
--- sem alterar o SetScale do frame pai, preservando 100% da precisão das coordenadas no mapa.
---@param pin table
---@param scale number|nil
function WorldMapView:applyPinScale(pin, scale)
    if not pin then return end
    local s = FIXED_PIN_SCALE
    pin._gmPinScale = s

    local pinSize = math.max(8, math.floor(26 * s + 0.5))
    pin:SetSize(pinSize, pinSize)

    if pin.glow then
        local gSize = math.max(10, math.floor(34 * s + 0.5))
        pin.glow:SetSize(gSize, gSize)
    end

    if pin.arrow then
        local aSize = math.max(10, math.floor(30 * s + 0.5))
        pin.arrow:SetSize(aSize, aSize)
    end

    if pin.classIcon then
        local cSize = math.max(8, math.floor(22 * s + 0.5))
        pin.classIcon:SetSize(cSize, cSize)
    end

    if pin.border then
        local bSize = math.max(16, math.floor(46 * s + 0.5))
        pin.border:SetSize(bSize, bSize)
        pin.border:SetPoint("CENTER", pin, "CENTER", 10 * s, -10 * s)
    end

    if pin.label then
        pin.label:SetPoint("BOTTOM", pin, "TOP", 0, math.max(2, math.floor(5 * s + 0.5)))
        if pin.label.GetFont and pin.label.SetFont then
            local fontPath, _, fontFlags = pin.label:GetFont()
            if fontPath then
                local fontSize = math.max(7, math.floor(10 * s + 0.5))
                pcall(pin.label.SetFont, pin.label, fontPath, fontSize, fontFlags)
            end
        end
    end
end

--- Cria ou obtém um pino persistente diretamente no canvas para o jogador remoto
---@param name string
---@param canvas table
---@return table|nil
function WorldMapView:getOrCreateNamedPin(name, canvas)
    if not self._pinsEnabled then return nil end
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
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")

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

    self:applyPinScale(pin, self:getPinScale())

    pin:SetScript("OnEnter", function(p)
        if not p.peerData then return end
        local d = p.peerData
        local cls = (d.classFile or d.class or "WARRIOR"):upper()
        local c = CLASS_COLORS[cls] or { r = 0.2, g = 0.8, b = 1.0, hex = "|cffffffff" }

        GameTooltip:SetOwner(p, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        local displayName = d.displayName or d.fullName or d.name
        local selfTag = d.isSelf and (curL["MAP_YOU_TAG"] or " |cff00ff00(You)|r") or ""
        GameTooltip:AddLine(string.format("%s%s|r%s", c.hex, displayName, selfTag), 1, 1, 1)

        if d.guild and d.guild ~= "" then
            GameTooltip:AddLine(string.format("|cff20ff20<%s>|r", d.guild), 0.2, 1, 0.2)
        end
        GameTooltip:AddDoubleLine(curL["MAP_PIN_LEVEL_CLASS"] or "Level & Class:", string.format("|cffffffff%d %s %s|r", d.level or 1, d.race or "", cls), 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(curL["MAP_PIN_REGION"] or "Region:", string.format("|cffffd200%s|r (%.1f, %.1f)", d.zoneName or "Azeroth", (d.x or 0) * 100, (d.y or 0) * 100), 1, 0.82, 0, 1, 1, 1)

        local now = GetTime and GetTime() or 0
        local diff = math.max(0, math.floor(now - (d.lastSeen or now)))
        local seenStr = (diff < 3) and (curL["MAP_PIN_LIVE"] or "|cff20ff20Live|r") or string.format(curL["MAP_PIN_SEEN_AGO"] or "%d s ago", diff)
        GameTooltip:AddDoubleLine(curL["MAP_PIN_SIGNAL"] or "AddOn Signal:", seenStr, 0.7, 0.7, 0.7, 1, 1, 1)

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(curL["MAP_PIN_LCLICK_WHISPER"] or "|cffaaaaaaLeft-Click to whisper|r", 0.6, 0.6, 0.6)
        if d.mapID and not d.isSelf then
            GameTooltip:AddLine(curL["MAP_PIN_RCLICK_ZOOM"] or "|cff00e5ffRight-Click to view member's zone|r", 0.4, 0.8, 1.0)
        end
        GameTooltip:AddLine(curL["MAP_PIN_SYNC_TITLE"] or "|cff00ff00GuildManager • Real-Time Sync|r", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)

    pin:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    pin:SetScript("OnClick", function(p, btn)
        if not p.peerData then return end
        if btn == "RightButton" and p.peerData.mapID and WorldMapFrame and WorldMapFrame.SetMapID then
            local currentMapID = GetCurrentWorldMapID()
            if p.peerData.mapID ~= currentMapID then
                WorldMapFrame:SetMapID(p.peerData.mapID)
                return
            end
        end
        if (btn == "LeftButton" or not btn) and p.peerData.name then
            if ChatFrame_OpenChat then
                ChatFrame_OpenChat("/w " .. p.peerData.name .. " ")
            end
        end
    end)

    self._pins[name] = pin
    return pin
end

--- Atualiza a renderização contínua de todos os pinos de jogadores remotos no mapa oficial da Blizzard
function WorldMapView:updateRealtimePins()
    if not self._pinsEnabled then return end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end

    if IsInGuild and not IsInGuild() then
        self:clearPins()
        return
    end

    local locService = _G.GM and _G.GM.locationService
    if not locService then return end

    local canvas, cw, ch = self:getMapCanvas()
    if not canvas or cw <= 10 or ch <= 10 then return end

    local viewMapID = GetCurrentWorldMapID()
    if not viewMapID then return end

    -- Respeita a opção de marcadores nas configurações
    local showPins = true
    local disablePins = false
    if _G.GM and _G.GM.settingsService then
        if _G.GM.settingsService:get("showMapPins") == false then
            showPins = false
        end
        if _G.GM.settingsService:get("disableWorldMapMemberPins") == true then
            disablePins = true
        end
    end

    if not showPins or disablePins then
        self:clearPins()
        return
    end

    local currentScale = FIXED_PIN_SCALE

    local peers = locService:getPeers() or {}
    local renderedPins = {}

    -- 1. Renderiza os pinos de membros remotos que usam o AddOn
    for name, peer in pairs(peers) do
        local peerFullName = peer.fullName or peer.name or name
        if not peerFullName:find("%s") and _G.GM and _G.GM.memberService and _G.GM.memberService.resolveFullName then
            local resolved = _G.GM.memberService:resolveFullName(peerFullName)
            if resolved and resolved ~= "" and resolved:find("%s") then
                peerFullName = resolved
            end
        end

        if not (locService and locService.isSelf and locService:isSelf(name, peerFullName)) then
            if peer.x and peer.y and (peer.x > 0 or peer.y > 0) then
                local rx, ry = TranslateCoordsToViewMap(peer.mapID, peer.x, peer.y, viewMapID)
            local pin = self:getOrCreateNamedPin(name, canvas)
            peer.displayName = peerFullName
            pin.peerData = peer
            if pin._gmPinScale ~= currentScale then
                self:applyPinScale(pin, currentScale)
            end

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

                pin.label:SetText(string.format("%s%s|r", c.hex or "|cffffffff", peerFullName))
                pin:Show()
                renderedPins[name] = true
            else
                pin:Hide()
            end
            end
        end
    end

    -- 2. Renderiza o próprio jogador no Mapa Mundi (caso Blizzard não desenhe a seta nativa)
    local highlightSelf = true
    if _G.GM and _G.GM.settingsService and _G.GM.settingsService:get("highlightSelfOnMap") == false then
        highlightSelf = false
    end

    local selfPinName = "__GM_SELF_PLAYER__"
    if highlightSelf and IsWorldOrCosmicMap(viewMapID) then
        local myMapID, myX, myY, myFacing = locService:getLocalPosition()
        if myMapID and myX and myY then
            local rx, ry = TranslateCoordsToViewMap(myMapID, myX, myY, viewMapID)
            if rx and ry then
                local selfPin = self:getOrCreateNamedPin(selfPinName, canvas)
                if selfPin._gmPinScale ~= currentScale then
                    self:applyPinScale(selfPin, currentScale)
                end
                local _, myClass = UnitClass("player")
                local cls = (myClass or "WARRIOR"):upper()

                -- Resolve o nome completo (nome e sobrenome) do jogador local
                local myFullName = nil
                if _G.GM and _G.GM.memberService and _G.GM.memberService.resolvePlayerFullName then
                    myFullName = _G.GM.memberService:resolvePlayerFullName()
                elseif _G.GM and _G.GM.memberController and _G.GM.memberController.resolvePlayerFullName then
                    myFullName = _G.GM.memberController:resolvePlayerFullName()
                end
                if not myFullName or myFullName == "" then
                    myFullName = UnitName("player") or "Você"
                end
                local myGuild = (GetGuildInfo and GetGuildInfo("player")) or ""

                selfPin.peerData = {
                    name = myFullName,
                    displayName = myFullName,
                    isSelf = true,
                    mapID = myMapID,
                    x = myX,
                    y = myY,
                    facing = myFacing or 0,
                    classFile = cls,
                    level = UnitLevel("player") or 1,
                    race = select(1, UnitRace("player")) or "",
                    guild = myGuild,
                    zoneName = GetRealZoneText() or GetZoneText() or "Azeroth",
                    lastSeen = GetTime and GetTime() or 0,
                }

                selfPin:ClearAllPoints()
                selfPin:SetPoint("CENTER", canvas, "TOPLEFT", rx * cw, -ry * ch)

                selfPin.arrow:SetVertexColor(1.0, 0.85, 0.20, 1.0)
                selfPin.glow:SetVertexColor(1.0, 0.85, 0.20, 0.95)

                ApplyClassIcon(selfPin.classIcon, cls)
                if selfPin.arrow.SetRotation then
                    pcall(selfPin.arrow.SetRotation, selfPin.arrow, myFacing or 0)
                end

                selfPin.label:SetText(string.format("|cffffd200%s (Você)|r", myFullName))
                selfPin:Show()
                renderedPins[selfPinName] = true
            else
                local p = self._pins and self._pins[selfPinName]
                if p then p:Hide() end
            end
        else
            local p = self._pins and self._pins[selfPinName]
            if p then p:Hide() end
        end
    else
        local p = self._pins and self._pins[selfPinName]
        if p then p:Hide() end
    end

    -- Esconde pinos que não foram renderizados nesta passada
    if self._pins then
        for name, pin in pairs(self._pins) do
            if not renderedPins[name] then
                pin:Hide()
            end
        end
    end
end

--- Cria frame filho de atualização contínua a 10 FPS (0.10s) para renderização suave com baixo uso de CPU
function WorldMapView:initUpdateFrame()
    if not self._pinsEnabled or self._updateFrame or not WorldMapFrame then return end

    local updateFrame = CreateFrame("Frame", "GM_WorldMapUpdateFrame", WorldMapFrame)
    updateFrame:SetAllPoints(WorldMapFrame)
    updateFrame:Show()

    updateFrame:SetScript("OnShow", function()
        self:updateRealtimePins()
    end)

    local ticker = 0
    updateFrame:SetScript("OnUpdate", function(_, elapsed)
        if not WorldMapFrame:IsShown() then return end
        ticker = ticker + elapsed
        if ticker >= 0.10 then
            ticker = 0
            self:updateRealtimePins()
        end
    end)

    self._updateFrame = updateFrame
end

--- Inicializa os componentes visuais vinculados à tela nativa de mapa (WorldMapFrame).
function WorldMapView:initWorldMapUI()
    if not WorldMapFrame then return end

    if self._pinsEnabled then
        self:initUpdateFrame()
    end

    if self._panel then
        return
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local curL = (_G.GM and _G.GM.L) or _G.L or L

    if not self._headerHooksInstalled then
        self._headerHooksInstalled = true
        if WorldMapFrame.HookScript then
            WorldMapFrame:HookScript("OnShow", function()
                if self._panel then
                    self:adjustPanelPosition()
                end
            end)
        end
    end

    -- =========================================================================
    -- PAINEL LATERAL MÓVEL DO WORLD MAP NATIVO
    -- =========================================================================
    local panel = CreateFrame("Frame", "GM_WorldMapPanel", WorldMapFrame, template)
    panel:SetSize(270, 556)
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel((WorldMapFrame:GetFrameLevel() or 10) + 10)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(f)
        if not f:GetHeight() or f:GetHeight() < 200 then
            f:SetHeight(556)
        end
        f:StartMoving()
    end)
    panel:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
    end)
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
    panel.sep = sep

    -- Container da Lista de Membros
    local listContainer = CreateFrame("Frame", nil, panel, template)
    listContainer:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -6)
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

    -- Container e Mensagem Exclusiva caso o jogador NÃO esteja em guilda
    local noGuildFrame = CreateFrame("Frame", nil, panel)
    noGuildFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -40)
    noGuildFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 20)
    noGuildFrame:Hide()
    panel.noGuildFrame = noGuildFrame

    local noGuildIcon = noGuildFrame:CreateTexture(nil, "ARTWORK")
    noGuildIcon:SetSize(48, 48)
    noGuildIcon:SetPoint("CENTER", noGuildFrame, "CENTER", 0, 35)
    noGuildIcon:SetTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
    noGuildIcon:SetDesaturated(true)
    noGuildFrame.icon = noGuildIcon

    local noGuildText = noGuildFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    noGuildText:SetPoint("TOP", noGuildIcon, "BOTTOM", 0, -16)
    noGuildText:SetPoint("LEFT", noGuildFrame, "LEFT", 10, 0)
    noGuildText:SetPoint("RIGHT", noGuildFrame, "RIGHT", -10, 0)
    noGuildText:SetJustifyH("CENTER")
    noGuildText:SetTextColor(1.0, 0.2, 0.2, 1.0)
    noGuildText:SetText(curL["NO_GUILD_MAP_MSG"] or "VOCÊ NÃO ESTÁ EM UMA GUILDA")
    noGuildFrame.text = noGuildText

    local noGuildSub = noGuildFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noGuildSub:SetPoint("TOP", noGuildText, "BOTTOM", 0, -10)
    noGuildSub:SetPoint("LEFT", noGuildFrame, "LEFT", 12, 0)
    noGuildSub:SetPoint("RIGHT", noGuildFrame, "RIGHT", -12, 0)
    noGuildSub:SetJustifyH("CENTER")
    noGuildSub:SetSpacing(3)
    noGuildSub:SetTextColor(0.8, 0.8, 0.8, 0.85)
    noGuildSub:SetText(curL["NO_GUILD_MAP_SUB"] or "Entre em uma guilda para visualizar membros no mapa.")
    noGuildFrame.sub = noGuildSub

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
                if data.isAddonUser then
                    local coordStr = (data.x and data.y and (data.x > 0 or data.y > 0)) and string.format(" (%.1f, %.1f)", data.x * 100, data.y * 100) or ""
                    GameTooltip:AddLine("|cff00ff00" .. (curL["MAP_GPS_SYNC_NOTE"] or "Synced via GPS AddOn") .. coordStr .. "|r", 0.2, 1.0, 0.2)
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

    if IsInGuild and not IsInGuild() then
        self:renderNoGuild()
    end
end

--- Posiciona o painel na posição padrão inicial ao lado do Mapa Mundial.
function WorldMapView:adjustPanelPosition()
    local panel = self._panel
    if not panel or not WorldMapFrame then return end

    local defaultHeight = 556
    if WorldMapFrame.GetHeight then
        local mapH = WorldMapFrame:GetHeight() or 0
        if mapH >= 420 and mapH <= 760 then
            defaultHeight = mapH
        end
    end

    panel:ClearAllPoints()
    panel:SetSize(270, defaultHeight)
    local mapRight = WorldMapFrame:GetRight() or 0
    local screenWidth = GetScreenWidth() or 1920

    if (mapRight + 275) <= screenWidth then
        panel:SetPoint("TOPLEFT", WorldMapFrame, "TOPRIGHT", 2, 0)
    else
        panel:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -4, -30)
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

--- Exibe o painel de membros da guilda na região.
function WorldMapView:showPanel()
    self:initWorldMapUI()
    if not self._panel then return end

    self:adjustPanelPosition()
    self._panel:Show()
    self._isPanelOpen = true

    if IsInGuild and not IsInGuild() then
        self:renderNoGuild()
        return
    end

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
end

--- Retorna se o painel está aberto.
---@return boolean
function WorldMapView:isPanelShown()
    return self._isPanelOpen == true and self._panel and self._panel:IsShown()
end

--- Renderiza o estado exclusivo de jogador sem guilda: oculta pinos e membros,
--- e exibe no painel exclusivamente a mensagem "VOCÊ NÃO ESTÁ EM UMA GUILDA".
function WorldMapView:renderNoGuild()
    if not self._panel then
        self:initWorldMapUI()
    end

    -- 1. Limpa e remove quaisquer pinos no mapa
    self:clearPins()
    self._membersData = {}

    local panel = self._panel
    if not panel then return end

    -- 3. Oculta todos os componentes normais do painel da guilda
    if panel.headerTitle then panel.headerTitle:Hide() end
    if panel.zoneTitle then panel.zoneTitle:Hide() end
    if panel.countText then panel.countText:Hide() end
    if panel.sep then panel.sep:Hide() end
    if panel.listContainer then panel.listContainer:Hide() end
    if panel.footer then panel.footer:Hide() end
    if panel.emptyMsg then panel.emptyMsg:Hide() end
    if self._scrollBar then self._scrollBar:Hide() end

    for _, row in pairs(self._memberRows or {}) do
        row:Hide()
        row.memberData = nil
    end

    -- 4. Exibe o frame com a mensagem exclusiva centralizada
    if panel.noGuildFrame then
        local curL = (_G.GM and _G.GM.L) or _G.L or L
        if panel.noGuildFrame.text then
            panel.noGuildFrame.text:SetText(curL["NO_GUILD_MAP_MSG"] or "VOCÊ NÃO ESTÁ EM UMA GUILDA")
        end
        if panel.noGuildFrame.sub then
            panel.noGuildFrame.sub:SetText(curL["NO_GUILD_MAP_SUB"] or "Entre em uma guilda para visualizar membros no mapa.")
        end
        panel.noGuildFrame:Show()
    end
end

--- Renderiza a lista de membros no painel lateral do mapa.
---@param membersData table @Lista de membros presentes na região/continente
---@param zoneName string @Nome da região visualizada no mapa
---@param isContinent boolean|nil @Indica se o mapa atual é um continente
---@param isWorld boolean|nil @Indica se o mapa atual é o mundo global
function WorldMapView:renderMembers(membersData, zoneName, isContinent, isWorld)
    if IsInGuild and not IsInGuild() then
        self:renderNoGuild()
        return
    end

    local curL = (_G.GM and _G.GM.L) or _G.L or L
    self._membersData = membersData or {}
    self._currentZoneName = zoneName or (curL["MAP_CURRENT_REGION"] or "Current Region")
    self._isContinentView = isContinent == true
    self._isWorldView = isWorld == true

    if not self._panel then
        self:initWorldMapUI()
    end

    if self._panel then
        if self._panel.headerTitle then self._panel.headerTitle:Show() end
        if self._panel.zoneTitle then
            self._panel.zoneTitle:SetText("|cff00e5ff" .. self._currentZoneName .. "|r")
            self._panel.zoneTitle:Show()
        end
        local scopeText = isWorld and (curL["MAP_BTN_WORLD_SCOPE"] or "in World") or (isContinent and (curL["MAP_BTN_CONT_SCOPE"] or "in Continent") or (curL["MAP_BTN_ZONE_SCOPE"] or "in Region"))
        if self._panel.countText then
            self._panel.countText:SetText(string.format(curL["MAP_FOUND_COUNT_FORMAT"] or "|cffa8f0a8%d member(s) %s|r", #self._membersData, scopeText))
            self._panel.countText:Show()
        end
        if self._panel.sep then self._panel.sep:Show() end
        if self._panel.listContainer then self._panel.listContainer:Show() end
        if self._panel.footer then self._panel.footer:Show() end
        if self._panel.noGuildFrame then self._panel.noGuildFrame:Hide() end
    end

    -- Atualiza os pinos em tempo real no mapa
    if self._pinsEnabled then
        self:updateRealtimePins()
    end

    -- Atualiza as linhas da lista lateral se o painel estiver aberto
    if self._isPanelOpen then
        self:refreshVisibleRows()
    end
end

--- Atualiza as linhas da tabela de membros no painel lateral.
function WorldMapView:refreshVisibleRows()
    local curL = (_G.GM and _G.GM.L) or _G.L or L
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
            local emptyScope = self._isWorldView and (curL["MAP_EMPTY_WORLD_SCOPE"] or "in the world") or (self._isContinentView and (curL["MAP_EMPTY_CONT_SCOPE"] or "on this continent") or (curL["MAP_EMPTY_ZONE_SCOPE"] or "in this region"))
            self._panel.emptyMsg:SetText(string.format(curL["MAP_EMPTY_ZONE_FMT"] or "No guild members\nfound %s.", emptyScope))
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
            local nameStr = cHex .. (data.name or (curL["MEMBER_DEFAULT_RANK"] or "Member")) .. "|r"

            -- Ícone da classe
            local coords = data.class and CLASS_ICON_COORDS[data.class]
            if coords and row.classIcon then
                row.classIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
                row.classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                row.classIcon:Show()
            else
                row.classIcon:Hide()
            end

            -- Linha 1: Nome do personagem (com indicador de GPS AddOn)
            local addonTag = data.isAddonUser and " |cff00ff00• GPS|r" or ""
            row.nameText:SetText(nameStr .. addonTag)

            -- Linha 2: Nível e Cargo (e Zona se estiver em visualização de Continente ou Mundo)
            local rankStr = data.rankName and data.rankName ~= "" and (" • |cffffff00" .. data.rankName .. "|r") or ""
            local lvlLabel = curL["COL_LEVEL"] or "Lvl"
            if (self._isContinentView or self._isWorldView) and data.zone and data.zone ~= "" then
                row.subText:SetText(string.format("%s %d%s • |cff00e5ff%s|r", lvlLabel, data.level or 1, rankStr, data.zone))
            else
                row.subText:SetText(string.format("%s %d%s", lvlLabel, data.level or 1, rankStr))
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
    if not self._pinsEnabled then return end
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
    if IsInGuild and not IsInGuild() then
        self:renderNoGuild()
        return
    end

    local curL = (_G.GM and _G.GM.L) or _G.L or L

    if self._panel then
        if self._panel.headerTitle then
            self._panel.headerTitle:SetText(curL["MAP_PANEL_HEADER"] or "|cffffd200Members in Region|r")
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

    if self._isPanelOpen then
        self:refreshVisibleRows()
    end
end

