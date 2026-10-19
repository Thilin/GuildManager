---@class MinimapButton
---@field private _button table
---@field private _lastPeerCount number
---@field private _knownPeers table<string, boolean>
---@field private _isInitialized boolean
---@field private _listenerRegistered boolean
MinimapButton = {}
MinimapButton.__index = MinimapButton

local DEFAULT_ANGLE = 215

--- Obtém a cor hexadecimal da classe
---@param classToken string|nil
---@return string
local function getClassColor(classToken)
    if not classToken or classToken == "" then return "|cffffffff" end
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if c then
        local r = math.floor((c.r or 1) * 255)
        local g = math.floor((c.g or 1) * 255)
        local b = math.floor((c.b or 1) * 255)
        return string.format("|cff%02x%02x%02x", r, g, b)
    end
    return "|cffffffff"
end

--- Construtor do botão orbitante do Minimapa do GuildManager.
---@return MinimapButton
function MinimapButton:new()
    local instance = setmetatable({}, self)
    instance._button = nil
    instance._lastPeerCount = 0
    instance._knownPeers = {}
    instance._isInitialized = false
    instance._listenerRegistered = false
    instance._pinManager = MinimapPinManager:new(instance)
    instance:createUI()
    if _G.GM then
        _G.GM.minimapPinManager = instance._pinManager
    end
    return instance
end

--- Cria e estiliza o balão do minimapa com fundo vermelho e texto GM em dourado.
--- A borda e o fundo piscam em azul (login) ou vermelho (logout).
--- A contagem e detalhes de membros são exibidos exclusivamente no mouseover.
function MinimapButton:createUI()
    if self._button or not Minimap then
        return
    end

    local button = CreateFrame("Button", "GuildManagerMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:EnableMouse(true)
    button:SetMovable(true)

    -- Borda metálica circular clássica da Blizzard (53x53 ancorada em TOPLEFT)
    local border = button:CreateTexture(nil, "OVERLAY", nil, 1)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetVertexColor(1.0, 1.0, 1.0, 1.0)
    button.border = border

    -- 1. Backdrop preto opaco (bloqueia o mapa do minimapa sob o recorte)
    local bgBackdrop = button:CreateTexture(nil, "BACKGROUND", nil, -1)
    bgBackdrop:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bgBackdrop:SetSize(20, 20)
    bgBackdrop:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
    button.bgBackdrop = bgBackdrop

    -- 2. Camada sólida central que adota a cor viva com 100% de saturação (WHITE8X8)
    local bgSolid = button:CreateTexture(nil, "BACKGROUND", nil, 0)
    bgSolid:SetTexture("Interface\\Buttons\\WHITE8X8")
    bgSolid:SetSize(14, 14)
    bgSolid:SetPoint("CENTER", bgBackdrop, "CENTER", 0, 0)
    bgSolid:SetVertexColor(0.12, 0.02, 0.02, 1.0)
    button.bgSolid = bgSolid

    -- 3. Camada circular de preenchimento (ZoomButton-Highlight em modo BLEND, adota qualquer cor)
    local bg = button:CreateTexture(nil, "BACKGROUND", nil, 1)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    bg:SetBlendMode("BLEND")
    bg:SetSize(21, 21)
    bg:SetPoint("CENTER", bgBackdrop, "CENTER", 0, 0)
    bg:SetVertexColor(0.12, 0.02, 0.02, 1.0) -- Fundo escuro clássico que destaca o dourado
    button.bg = bg

    -- Texto "GM" em dourado clássico (100% concêntrico no centro exato do fundo)
    local label = button:CreateFontString(nil, "OVERLAY", nil, 2)
    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    label:SetPoint("CENTER", bg, "CENTER", 0, 0)
    label:SetText("|cffffd200GM|r")
    label:SetTextColor(1.0, 0.82, 0.0, 1.0)
    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(1, -1)
    button.label = label

    -- Aura circular de pulso na borda do botão (100% concêntrico ao redor do círculo)
    local pulseGlow = button:CreateTexture(nil, "OVERLAY", nil, 3)
    pulseGlow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    pulseGlow:SetPoint("CENTER", bg, "CENTER", 0, 0)
    pulseGlow:SetSize(34, 34)
    pulseGlow:SetBlendMode("ADD")
    pulseGlow:SetAlpha(0)
    pulseGlow:Hide()
    button.pulseGlow = pulseGlow

    -- Frame dedicado para controlar animações de pulso sem interferir no arrasto
    local animFrame = CreateFrame("Frame", nil, button)
    button.animFrame = animFrame

    -- Highlight suave ao passar o mouse (100% concêntrico sobre o botão)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetPoint("CENTER", bg, "CENTER", 0, 0)
    highlight:SetSize(30, 30)
    highlight:SetBlendMode("ADD")
    button:SetHighlightTexture(highlight)

    -- Controle de arrastar (orbitar a borda do minimapa) e clique
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local isDragging = false
    local wasDragged = false

    button:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" then
            wasDragged = false
            label:SetPoint("CENTER", bg, "CENTER", 1, -1)
        end
    end)

    button:SetScript("OnMouseUp", function()
        label:SetPoint("CENTER", bg, "CENTER", 0, 0)
    end)

    button:SetScript("OnDragStart", function(f)
        isDragging = true
        wasDragged = true
        GameTooltip:Hide()
        f:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx = cx / scale
            cy = cy / scale

            local dx = cx - mx
            local dy = cy - my
            local angleRad = math.atan2(dy, dx)
            local angleDeg = math.deg(angleRad)
            if angleDeg < 0 then
                angleDeg = angleDeg + 360
            end

            if _G.GM_DB and _G.GM_DB.settings then
                _G.GM_DB.settings.minimapPos = angleDeg
            end

            self:updatePosition(angleDeg)
        end)
    end)

    button:SetScript("OnDragStop", function(f)
        if isDragging then
            isDragging = false
            f:SetScript("OnUpdate", nil)
        end
    end)

    -- Ao clicar no balão, abre a aba padrão (ou configurações com botão direito)
    button:SetScript("OnClick", function(_, btn)
        if wasDragged then
            wasDragged = false
            return
        end

        if btn == "LeftButton" then
            local defTab = (_G.GM_DB and _G.GM_DB.settings and _G.GM_DB.settings.defaultTab) or "audit"
            if defTab == "logs" and _G.GM and _G.GM.logController then
                _G.GM.logController:toggle()
            elseif defTab == "groups" and _G.GM and _G.GM.groupController then
                _G.GM.groupController:toggle()
            elseif defTab == "agenda" and _G.GM and _G.GM.agendaController then
                _G.GM.agendaController:toggle()
            elseif defTab == "professions" and _G.GM and _G.GM.professionController then
                _G.GM.professionController:toggle()
            elseif defTab == "settings" and _G.GM and _G.GM.settingsController then
                _G.GM.settingsController:toggle()
            elseif _G.GM and _G.GM.auditController then
                _G.GM.auditController:toggle()
            elseif _G.GM and _G.GM.logController then
                _G.GM.logController:toggle()
            end
        elseif btn == "RightButton" then
            if _G.GM and _G.GM.settingsController then
                _G.GM.settingsController:toggle()
            end
        end
    end)

    -- Tooltip explicativo ao passar o mouse (informações completas dos membros em mouseover)
    button:SetScript("OnEnter", function(f)
        local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })
        GameTooltip:SetOwner(f, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        local title = (L and L["MINIMAP_TOOLTIP_TITLE"]) or "Guild Manager"
        GameTooltip:AddLine("|cffffd200" .. title .. "|r")
        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_LCLICK"] or "Clique-Esq: Abrir Guild Manager")
        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_RCLICK"] or "Clique-Dir: Configurações")
        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_CMDS"] or "Comandos: /gm, /gmloc, /gmsync")
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_DRAG"] or "Arrastar: Mover ícone pelo minimapa", 0.8, 0.8, 0.8, true)

        -- Seção informativa dos membros conectados com o Addon (exibida exclusivamente no mouseover)
        local locService = _G.GM and _G.GM.locationService
        local peers = locService and locService:getPeers() or {}
        local peerCount = locService and locService.getPeerCount and tonumber(locService:getPeerCount()) or 0

        GameTooltip:AddLine(" ")
        if peerCount > 0 then
            GameTooltip:AddLine(string.format(L["MAP_BADGE_TOOLTIP_TITLE"] or "|TInterface\\Icons\\INV_Misc_GroupNeedMore:14:14:0:0|t |cff20ff20Membros com o Addon (%d)|r", peerCount), 1, 1, 1)
            for name, p in pairs(peers) do
                if not (locService and locService.isSelf and locService:isSelf(p.name)) then
                    local cls = (p.classFile or p.class or "WARRIOR"):upper()
                    local cHex = getClassColor(cls)
                    local zoneStr = p.zoneName or "Azeroth"
                    local coordsStr = (p.x and p.y and p.x > 0) and string.format(" (%.1f, %.1f)", p.x * 100, p.y * 100) or ""
                    GameTooltip:AddDoubleLine(
                        string.format("  • %s%s|r (Nv %d)", cHex, p.name or name, p.level or 1),
                        string.format("|cffffd200%s|r%s", zoneStr, coordsStr),
                        1, 1, 1, 0.85, 0.85, 0.85
                    )
                end
            end
        else
            GameTooltip:AddLine(string.format("|TInterface\\Icons\\INV_Misc_GroupNeedMore:14:14:0:0|t |cffaaaaaa" .. (L["MAP_BADGE_NO_MEMBERS"] or "Nenhum outro membro com o Addon conectado.") .. "|r"), 0.7, 0.7, 0.7)
            GameTooltip:AddLine(L["MAP_BADGE_TIP_SIMULATE"] or "|cff55ff55Dica: Use /gmloc test para simular um membro!|r", 0.3, 0.8, 0.3)
        end

        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self._button = button

    -- Posiciona no ângulo salvo ou padrão
    local savedAngle = (_G.GM_DB and _G.GM_DB.settings and _G.GM_DB.settings.minimapPos) or DEFAULT_ANGLE
    self:updatePosition(savedAngle)

    if _G.GM_DB and _G.GM_DB.settings and _G.GM_DB.settings.showMinimapButton == false then
        button:Hide()
    end

    self:updatePeerCount()
end

--- Faz o fundo e a borda do botão do minimapa piscarem em azul (login) ou vermelho (logout) e voltarem suavemente ao normal
---@param mode string @"LOGIN" (azul) ou "LOGOUT" (vermelho)
function MinimapButton:pulseButton(mode)
    if not self._button or not self._button.bg or not self._button.border then return end

    local button = self._button
    local bg = button.bg
    local bgSolid = button.bgSolid
    local border = button.border
    local glow = button.pulseGlow
    local animFrame = button.animFrame or button

    -- Cores base originais do botão (estado neutro / ocioso)
    local R_norm, G_norm, B_norm = 0.12, 0.02, 0.02 -- Fundo escuro elegante
    local RB_norm, GB_norm, BB_norm = 1.0, 1.0, 1.0 -- Borda dourada metálica normal

    -- Cores de destaque da animação
    local R_tgt, G_tgt, B_tgt       -- Cor do fundo (bg e bgSolid)
    local RB_tgt, GB_tgt, BB_tgt     -- Cor da borda (border)
    local G_r, G_g, G_b             -- Cor da aura (pulseGlow)

    if mode == "LOGOUT" then
        -- DESLOGAR: Vermelho intenso
        R_tgt, G_tgt, B_tgt = 0.95, 0.04, 0.04       -- Fundo vermelho vivo
        RB_tgt, GB_tgt, BB_tgt = 1.00, 0.18, 0.18    -- Borda vermelha brilhante
        G_r, G_g, G_b = 1.00, 0.10, 0.10             -- Aura vermelha
    else
        -- LOGAR: Azul vibrante
        R_tgt, G_tgt, B_tgt = 0.05, 0.45, 0.95       -- Fundo azul profundo
        RB_tgt, GB_tgt, BB_tgt = 0.25, 0.80, 1.00    -- Borda azul/ciano elétrico
        G_r, G_g, G_b = 0.15, 0.65, 1.00             -- Aura azulada
    end

    if glow then
        glow:SetVertexColor(G_r, G_g, G_b, 1.0)
        glow:Show()
    end

    local flashDuration = 1.8   -- Duração do piscar rápido (pulsos visíveis)
    local fadeDuration = 1.8    -- Duração da transição suave de volta ao normal
    local animTotalDuration = flashDuration + fadeDuration
    local elapsedTotal = 0
    local flashFreq = 3.5       -- Frequência de pulsação

    animFrame:SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + elapsed

        if elapsedTotal < flashDuration then
            -- Fase 1: Pisca intensamente a borda e o fundo na cor do evento (azul ou vermelho)
            local pulse = 0.25 + 0.75 * math.abs(math.sin(elapsedTotal * flashFreq * math.pi))

            local r = R_norm + (R_tgt - R_norm) * pulse
            local g = G_norm + (G_tgt - G_norm) * pulse
            local b = B_norm + (B_tgt - B_norm) * pulse
            bg:SetVertexColor(r, g, b, 1.0)
            if bgSolid then bgSolid:SetVertexColor(r, g, b, 1.0) end

            local br = RB_norm + (RB_tgt - RB_norm) * pulse
            local bg_val = GB_norm + (GB_tgt - GB_norm) * pulse
            local bb = BB_norm + (BB_tgt - BB_norm) * pulse
            border:SetVertexColor(br, bg_val, bb, 1.0)

            if glow then
                glow:SetAlpha(pulse)
            end
        elseif elapsedTotal < animTotalDuration then
            -- Fase 2: Vai se apagando suavemente (transição de volta ao fundo escuro e borda dourada)
            local remain = 1.0 - ((elapsedTotal - flashDuration) / fadeDuration)
            remain = math.max(0, remain)

            local r = R_norm + (R_tgt - R_norm) * remain
            local g = G_norm + (G_tgt - G_norm) * remain
            local b = B_norm + (B_tgt - B_norm) * remain
            bg:SetVertexColor(r, g, b, 1.0)
            if bgSolid then bgSolid:SetVertexColor(r, g, b, 1.0) end

            local br = RB_norm + (RB_tgt - RB_norm) * remain
            local bg_val = GB_norm + (GB_tgt - GB_norm) * remain
            local bb = BB_norm + (BB_tgt - BB_norm) * remain
            border:SetVertexColor(br, bg_val, bb, 1.0)

            if glow then
                glow:SetAlpha(remain * 0.8)
            end
        else
            -- Fase 3: Conclui e reseta 100% aos valores neutros
            animFrame:SetScript("OnUpdate", nil)
            bg:SetVertexColor(R_norm, G_norm, B_norm, 1.0)
            if bgSolid then bgSolid:SetVertexColor(R_norm, G_norm, B_norm, 1.0) end
            border:SetVertexColor(RB_norm, GB_norm, BB_norm, 1.0)
            if glow then
                glow:SetAlpha(0)
                glow:Hide()
            end
        end
    end)
end

--- Alias para pulso de login (azul)
function MinimapButton:flashPeerLogin()
    self:pulseButton("LOGIN")
end

--- Alias para pulso de logout (vermelho)
function MinimapButton:flashPeerLogout()
    self:pulseButton("LOGOUT")
end

--- Alias de compatibilidade
---@param mode string
function MinimapButton:pulseBubble(mode)
    self:pulseButton(mode)
end

--- Disparado quando ocorre um evento de peers no LocationService
---@param event string
---@param peerName string|nil
---@param peerData table|nil
function MinimapButton:onPeerEvent(event, peerName, peerData)
    local locService = _G.GM and _G.GM.locationService
    local currentCount = locService and locService.getPeerCount and tonumber(locService:getPeerCount()) or 0

    if event == "PEER_UPDATE" and peerName and peerName ~= "" then
        local lower = peerName:lower()
        local isSelf = locService and locService.isSelf and locService:isSelf(peerName)
        if not isSelf then
            if not self._knownPeers[lower] then
                self._knownPeers[lower] = true
                if self._isInitialized then
                    self:pulseButton("LOGIN")
                end
            end
        end
    elseif event == "PEER_EXPIRED" and peerName and peerName ~= "" then
        local lower = peerName:lower()
        if self._knownPeers[lower] then
            self._knownPeers[lower] = nil
            if self._isInitialized then
                self:pulseButton("LOGOUT")
            end
        end
    elseif event == "PEER_LIST_CHANGED" then
        if self._isInitialized then
            if currentCount > self._lastPeerCount then
                self:pulseButton("LOGIN")
            elseif currentCount < self._lastPeerCount then
                self:pulseButton("LOGOUT")
            end
        end
    end

    self._lastPeerCount = currentCount

    if self._pinManager then
        self._pinManager:onPeerEvent(event, peerName, peerData)
    end
end

--- Atualiza a contagem interna de peers para sincronia com o tooltip
function MinimapButton:updatePeerCount()
    local locService = _G.GM and _G.GM.locationService
    local count = 0
    if locService and locService.getPeerCount then
        count = tonumber(locService:getPeerCount()) or 0
    end
    self._lastPeerCount = count
end

--- Conecta listener com o LocationService para monitorar logins e logouts em tempo real.
---@param locService LocationService|nil
function MinimapButton:initLocationListener(locService)
    locService = locService or (_G.GM and _G.GM.locationService)
    if not locService then return end

    -- Registra peers existentes inicialmente sem disparar animação de login imediato
    local initialPeers = locService.getPeers and locService:getPeers() or {}
    for name in pairs(initialPeers) do
        self._knownPeers[name:lower()] = true
    end
    self._lastPeerCount = locService.getPeerCount and locService:getPeerCount() or 0

    -- Permite que novas conexões disparem o piscar azul/vermelho logo após a inicialização (0.5s)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            self._isInitialized = true
        end)
    else
        self._isInitialized = true
    end

    if locService.registerListener and not self._listenerRegistered then
        self._listenerRegistered = true
        locService:registerListener(function(event, peerName, peerData)
            self:onPeerEvent(event, peerName, peerData)
        end)
    end

    if self._pinManager then
        self._pinManager:start(locService)
    end
end

--- Atualiza as opções de exibição dos marcadores no minimapa
---@param showPins boolean|nil
---@param clampPins boolean|nil
function MinimapButton:updatePinSettings(showPins, clampPins)
    if self._pinManager then
        self._pinManager:updateSettings(showPins, clampPins)
    end
end

--- Retorna a instância do gerenciador de pinos do minimapa
---@return MinimapPinManager|nil
function MinimapButton:getPinManager()
    return self._pinManager
end

--- Atualiza a posição angular do botão orbitando a borda do Minimapa.
---@param angleDeg number
function MinimapButton:updatePosition(angleDeg)
    if not self._button or not Minimap then
        return
    end

    angleDeg = angleDeg or DEFAULT_ANGLE
    local rad = math.rad(angleDeg)
    local cosA = math.cos(rad)
    local sinA = math.sin(rad)

    local mapWidth = Minimap:GetWidth() / 2
    local mapHeight = Minimap:GetHeight() / 2
    local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"

    local x, y
    if minimapShape == "SQUARE" then
        x = math.max(-mapWidth - 10, math.min(mapWidth + 10, cosA * (mapWidth + 10)))
        y = math.max(-mapHeight - 10, math.min(mapHeight + 10, sinA * (mapHeight + 10)))
    else
        local radius = mapWidth + 10
        x = cosA * radius
        y = sinA * radius
    end

    self._button:ClearAllPoints()
    self._button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

--- Exibe o botão do minimapa.
function MinimapButton:show()
    if self._button then
        self._button:Show()
    end
end

--- Oculta o botão do minimapa.
function MinimapButton:hide()
    if self._button then
        self._button:Hide()
    end
end

--- Alterna a visibilidade do botão do minimapa.
function MinimapButton:toggle()
    if self._button and self._button:IsShown() then
        self:hide()
    else
        self:show()
    end
end

--- Atualiza a interface do botão do minimapa conforme o idioma ativo
function MinimapButton:updateLocale()
    self:updatePeerCount()
end

-- Exportação/Alias de compatibilidade
minimapButton = MinimapButton

-- ============================================================================
-- MINIMAP PIN MANAGER (Rastreamento P2P de membros no Minimapa em tempo real)
-- ============================================================================
---@class MinimapPinManager
--- Gerencia os pinos circulares de membros da guilda diretamente no Minimapa oficial da Blizzard,
--- permitindo ver a localização exata, orientação, classe e nível de quem usa o AddOn,
--- mesmo que não estejam em grupo.
MinimapPinManager = {}
MinimapPinManager.__index = MinimapPinManager

local MAP_PIN_CLASS_COLORS = {
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

local MAP_PIN_CLASS_COORDS = {
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

local MAP_PIN_SIZES = {
    indoor = {
        [0] = 300,
        [1] = 240,
        [2] = 180,
        [3] = 120,
        [4] = 80,
        [5] = 50,
    },
    outdoor = {
        [0] = 466 + 2/3,
        [1] = 400,
        [2] = 333 + 1/3,
        [3] = 266 + 2/3,
        [4] = 200,
        [5] = 133 + 1/3,
    },
}

local function MapPinMakeVector2D(x, y)
    if CreateVector2D then
        return CreateVector2D(x, y)
    elseif Vector2D_Create then
        return Vector2D_Create(x, y)
    end
    local v = { x = x, y = y }
    function v:GetXY() return self.x, self.y end
    return v
end

local function MapPinSafeGetWorldPos(sourceMapID, sourceX, sourceY)
    if not (C_Map and C_Map.GetWorldPosFromMapPos) or not sourceMapID or not sourceX or not sourceY then
        return nil, nil
    end
    local v = MapPinMakeVector2D(sourceX, sourceY)
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

    -- Fallback: tenta via mapa pai se for subzona
    if C_Map and C_Map.GetMapInfo then
        local okInfo, info = pcall(C_Map.GetMapInfo, sourceMapID)
        if okInfo and info and info.parentMapID and info.parentMapID > 0 and info.parentMapID ~= sourceMapID then
            if C_Map.GetMapRectOnMap then
                local okR, minX, maxX, minY, maxY = pcall(C_Map.GetMapRectOnMap, sourceMapID, info.parentMapID)
                if okR and minX and maxX and minY and maxY and (maxX > minX) and (maxY > minY) then
                    local parentX = minX + sourceX * (maxX - minX)
                    local parentY = minY + sourceY * (maxY - minY)
                    local vParent = MapPinMakeVector2D(parentX, parentY)
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

local function MapPinExtractWorldCoords(worldPos)
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

local function MapPinApplyClassIcon(texture, classFile)
    classFile = (classFile or "WARRIOR"):upper()
    local coords = MAP_PIN_CLASS_COORDS[classFile]

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

--- Construtor do MinimapPinManager
---@param parentButton MinimapButton|nil
---@return MinimapPinManager
function MinimapPinManager:new(parentButton)
    local instance = setmetatable({}, self)
    instance._parent = parentButton
    instance._pins = {}
    instance._locService = nil
    instance._updateFrame = nil
    instance._lastThrottle = 0
    instance._forceUpdate = true
    instance._showPins = true
    instance._clampToEdge = false
    return instance
end

--- Inicia o loop de renderização do minimapa
---@param locService LocationService|nil
function MinimapPinManager:start(locService)
    self._locService = locService or self._locService or (_G.GM and _G.GM.locationService)

    -- Carrega as opções de configurações
    self._showPins = true
    self._clampToEdge = false

    if _G.GM and _G.GM.settingsService then
        if _G.GM.settingsService:get("showMinimapPins") == false then
            self._showPins = false
        end
        if _G.GM.settingsService:get("clampMinimapPins") == true then
            self._clampToEdge = true
        end
    elseif _G.GM_DB and _G.GM_DB.settings then
        if _G.GM_DB.settings.showMinimapPins == false then
            self._showPins = false
        end
        if _G.GM_DB.settings.clampMinimapPins == true then
            self._clampToEdge = true
        end
    end

    if not self._updateFrame then
        local f = CreateFrame("Frame", "GM_MinimapPinUpdateFrame", Minimap)
        f:RegisterEvent("MINIMAP_UPDATE_ZOOM")
        f:RegisterEvent("CVAR_UPDATE")
        f:RegisterEvent("ZONE_CHANGED")
        f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        f:RegisterEvent("ZONE_CHANGED_INDOORS")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")

        f:SetScript("OnEvent", function(_, event, arg1)
            if event == "CVAR_UPDATE" and (arg1 == "rotateMinimap" or arg1 == "ROTATE_MINIMAP") then
                self._forceUpdate = true
                self:updatePins()
            elseif event == "MINIMAP_UPDATE_ZOOM" or event:find("ZONE_CHANGED") or event == "PLAYER_ENTERING_WORLD" then
                self._forceUpdate = true
                self:updatePins()
            end
        end)

        f:SetScript("OnUpdate", function(_, elapsed)
            self._lastThrottle = self._lastThrottle + elapsed
            if self._lastThrottle >= 0.05 or self._forceUpdate then
                self._lastThrottle = 0
                self._forceUpdate = false
                self:updatePins()
            end
        end)

        self._updateFrame = f
    end

    self._forceUpdate = true
    self:updatePins()
end

--- Atualiza as preferências do usuário para os pinos do minimapa
---@param showPins boolean|nil
---@param clampPins boolean|nil
function MinimapPinManager:updateSettings(showPins, clampPins)
    if showPins ~= nil then
        self._showPins = (showPins == true)
    end
    if clampPins ~= nil then
        self._clampToEdge = (clampPins == true)
    end
    self._forceUpdate = true
    if not self._showPins then
        self:clearPins()
    else
        self:updatePins()
    end
end

--- Notificado quando um evento de peer ocorre no LocationService
---@param event string
---@param peerName string|nil
---@param peerData table|nil
function MinimapPinManager:onPeerEvent(event, peerName, peerData)
    if event == "PEER_EXPIRED" and peerName and self._pins[peerName] then
        self._pins[peerName]:Hide()
    end
    self._forceUpdate = true
    if self._showPins then
        self:updatePins()
    end
end

--- Limpa e oculta todos os pinos atualmente criados no Minimapa
function MinimapPinManager:clearPins()
    for _, pin in pairs(self._pins) do
        if pin and pin.Hide then
            pin:Hide()
        end
    end
end

--- Cria ou obtém o pino do Minimapa para um determinado jogador
---@param name string
---@return table
function MinimapPinManager:getOrCreatePin(name)
    local safeName = (name or "unknown"):gsub("%s+", "_"):gsub("[^%w_]", "")
    if safeName == "" then safeName = "Member" end

    local pin = self._pins[name]
    if pin then
        if pin:GetParent() ~= Minimap then
            pin:SetParent(Minimap)
        end
        return pin
    end

    pin = CreateFrame("Button", "GM_MinimapPin_" .. safeName, Minimap)
    pin:SetSize(22, 22)
    pin:SetFrameStrata("HIGH")
    pin:SetFrameLevel((Minimap:GetFrameLevel() or 8) + 10)
    pin:EnableMouse(true)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- 1. Glow pulsante na cor da classe
    local glow = pin:CreateTexture(nil, "BACKGROUND", nil, -1)
    glow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    glow:SetSize(30, 30)
    glow:SetPoint("CENTER", pin, "CENTER", 0, 0)
    glow:SetBlendMode("ADD")
    pin.glow = glow

    -- 2. Seta direcional GPS atrás do ícone (aponta para o rumo da bússola ou direção radial)
    local arrow = pin:CreateTexture(nil, "BORDER", nil, 1)
    arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    arrow:SetSize(26, 26)
    arrow:SetPoint("CENTER", pin, "CENTER", 0, 0)
    pin.arrow = arrow

    -- 3. Ícone circular oficial da classe no centro
    local classIcon = pin:CreateTexture(nil, "ARTWORK", nil, 2)
    classIcon:SetSize(17, 17)
    classIcon:SetPoint("CENTER", pin, "CENTER", 0, 0)
    pin.classIcon = classIcon

    -- 4. Borda metálica clássica de rastreamento do minimapa
    local border = pin:CreateTexture(nil, "OVERLAY", nil, 3)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(40, 40)
    border:SetPoint("CENTER", pin, "CENTER", 7, -7)
    pin.border = border

    pin:SetScript("OnEnter", function(p)
        if not p.peerData then return end
        local d = p.peerData
        local cls = (d.classFile or d.class or "WARRIOR"):upper()
        local c = MAP_PIN_CLASS_COLORS[cls] or { r = 0.78, g = 0.61, b = 0.43, hex = "|cffffffff" }

        GameTooltip:SetOwner(p, "ANCHOR_BOTTOMLEFT")
        GameTooltip:ClearLines()
        local displayName = d.displayName or d.fullName or d.name
        GameTooltip:AddLine(string.format("%s%s|r", c.hex, displayName), 1, 1, 1)

        if d.guild and d.guild ~= "" then
            GameTooltip:AddLine(string.format("|cff20ff20<%s>|r", d.guild), 0.2, 1, 0.2)
        end

        local curL = (_G.GM and _G.GM.L) or _G.L or L
        GameTooltip:AddDoubleLine(curL["MAP_PIN_LEVEL_CLASS"] or "Level & Class:", string.format("|cffffffff%d %s %s|r", d.level or 1, d.race or "", cls), 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(curL["MAP_PIN_REGION"] or "Region:", string.format("|cffffd200%s|r (%.1f, %.1f)", d.zoneName or "Azeroth", (d.x or 0) * 100, (d.y or 0) * 100), 1, 0.82, 0, 1, 1, 1)

        if p.peerDistYards and p.peerDistYards >= 0 then
            local distVal = math.floor(p.peerDistYards + 0.5)
            local distStr = string.format("%d yd", distVal)
            if p.onEdge then
                distStr = string.format("|cffffd200%s|r %s", distStr, curL["MINIMAP_PIN_FAR"] or "|cffaaaaaa(Beyond Radar)|r")
            else
                distStr = string.format("|cff20ff20%s|r", distStr)
            end
            GameTooltip:AddDoubleLine(curL["MINIMAP_PIN_DISTANCE"] or "Distance:", distStr, 1, 0.82, 0, 1, 1, 1)
        end

        local now = GetTime and GetTime() or 0
        local diff = math.max(0, math.floor(now - (d.lastSeen or now)))
        local seenStr = (diff < 3) and (curL["MAP_PIN_LIVE"] or "|cff20ff20Live|r") or string.format(curL["MAP_PIN_SEEN_AGO"] or "%d s ago", diff)
        GameTooltip:AddDoubleLine(curL["MAP_PIN_SIGNAL"] or "AddOn Signal:", seenStr, 0.7, 0.7, 0.7, 1, 1, 1)

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(curL["MAP_PIN_LCLICK_WHISPER"] or "|cffaaaaaaLeft-Click to whisper|r", 0.6, 0.6, 0.6)
        if d.mapID then
            GameTooltip:AddLine(curL["MAP_PIN_RCLICK_ZOOM"] or "|cff00e5ffRight-Click to view member on World Map|r", 0.4, 0.8, 1.0)
        end
        GameTooltip:AddLine(curL["MAP_PIN_SYNC_TITLE"] or "|cff00ff00GuildManager • Real-Time GPS|r", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)

    pin:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    pin:SetScript("OnClick", function(p, btn)
        if not p.peerData then return end
        if btn == "RightButton" and p.peerData.mapID and WorldMapFrame and WorldMapFrame.SetMapID then
            if not WorldMapFrame:IsShown() then
                if ToggleWorldMap then ToggleWorldMap() elseif ShowUIPanel then ShowUIPanel(WorldMapFrame) end
            end
            WorldMapFrame:SetMapID(p.peerData.mapID)
            return
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

--- Atualiza a renderização contínua de todos os membros no Minimapa
function MinimapPinManager:updatePins()
    if not Minimap or not Minimap:IsShown() then return end

    if not self._showPins then
        self:clearPins()
        return
    end

    local locService = self._locService or (_G.GM and _G.GM.locationService)
    if not locService then return end

    local myMapID, myX, myY, myFacing = locService:getLocalPosition()
    if not myMapID or not myX or not myY then
        if C_Map and C_Map.GetBestMapForUnit then
            local bMap = C_Map.GetBestMapForUnit("player")
            if bMap and bMap > 0 then
                myMapID = bMap
                local pos = C_Map.GetPlayerMapPosition(myMapID, "player")
                if pos then
                    if pos.GetXY then myX, myY = pos:GetXY() elseif pos.x and pos.y then myX, myY = pos.x, pos.y end
                end
            end
        end
    end

    if not myMapID or not myX or not myY then
        self:clearPins()
        return
    end

    local pContID, pWorldPos = MapPinSafeGetWorldPos(myMapID, myX, myY)
    local pNS, pWE = MapPinExtractWorldCoords(pWorldPos)
    if (not pNS or not pWE) and UnitPosition then
        local uy, ux, _, uInst = UnitPosition("player")
        if uy and ux then
            pNS, pWE = uy, ux
            pContID = pContID or uInst
        end
    end

    local zoom = Minimap:GetZoom() or 0
    local cvarZoom = tonumber(GetCVar("minimapZoom")) or 0
    local isIndoor = (cvarZoom ~= zoom)
    local mapRadius = nil
    if C_Minimap and C_Minimap.GetViewRadius then
        local ok, r = pcall(C_Minimap.GetViewRadius)
        if ok and r and type(r) == "number" and r > 0 then
            mapRadius = r
        end
    end
    if not mapRadius or mapRadius <= 0 then
        local env = isIndoor and MAP_PIN_SIZES.indoor or MAP_PIN_SIZES.outdoor
        mapRadius = (env[zoom] or env[0] or 350) / 2
    end

    local minimapWidth = (Minimap:GetWidth() or 140) / 2
    local minimapHeight = (Minimap:GetHeight() or 140) / 2
    local rotateMinimap = (GetCVar("rotateMinimap") == "1")
    local playerFacing = GetPlayerFacing and GetPlayerFacing() or myFacing or 0

    local peers = locService:getPeers() or {}
    local renderedPins = {}

    for name, peer in pairs(peers) do
        local peerFullName = peer.fullName or peer.name or name
        if not peerFullName:find("%s") and _G.GM and _G.GM.memberService and _G.GM.memberService.resolveFullName then
            local resolved = _G.GM.memberService:resolveFullName(peerFullName)
            if resolved and resolved ~= "" and resolved:find("%s") then
                peerFullName = resolved
            end
        end

        local isSelf = locService.isSelf and locService:isSelf(name, peerFullName)
        if not isSelf and peer.mapID and peer.x and peer.y then
            peer.displayName = peerFullName

            -- Enriquece com dados do membro se disponíveis
            if _G.GM and _G.GM.memberService and _G.GM.memberService.getMemberByName then
                local m = _G.GM.memberService:getMemberByName(peer.name or name)
                if m then
                    if not peer.race or peer.race == "" then peer.race = m:getRace() end
                    if not peer.guild or peer.guild == "" then peer.guild = m:getGuildName() or (GetGuildInfo and GetGuildInfo("player")) end
                end
            end

            local mContID, mWorldPos = MapPinSafeGetWorldPos(peer.mapID, peer.x, peer.y)
            local mNS, mWE = MapPinExtractWorldCoords(mWorldPos)

            -- Fallback para mesma zona caso GetWorldPosFromMapPos falhe
            if (not mNS or not mWE) and peer.mapID == myMapID and pNS and pWE then
                local _, w0 = MapPinSafeGetWorldPos(myMapID, 0, 0)
                local _, w1 = MapPinSafeGetWorldPos(myMapID, 1, 1)
                local ns0, we0 = MapPinExtractWorldCoords(w0)
                local ns1, we1 = MapPinExtractWorldCoords(w1)
                if ns0 and ns1 and we0 and we1 then
                    mWE = we0 + peer.x * (we1 - we0)
                    mNS = ns0 + peer.y * (ns1 - ns0)
                    mContID = pContID
                end
            end

            -- Verifica se estão no mesmo continente/instância
            local sameContinent = true
            if pContID and mContID and pContID > 0 and mContID > 0 and pContID ~= mContID then
                sameContinent = false
            end

            if sameContinent and pNS and pWE and mNS and mWE then
                -- Distâncias em jardas no mundo real:
                -- No WoW: +X = Norte, +Y = Oeste
                local distEastWest = pWE - mWE    -- Positivo = peer está a Leste (Direita)
                local distNorthSouth = mNS - pNS  -- Positivo = peer está ao Norte (Cima)
                local distYards = math.sqrt(distEastWest * distEastWest + distNorthSouth * distNorthSouth)

                -- Filtro: Se estiver em zona diferente E a mais de 1200 jardas, não polui a borda
                local canRender = true
                if peer.mapID ~= myMapID and distYards > 1200 then
                    canRender = false
                end

                if canRender then
                    local effX, effY = distEastWest, distNorthSouth
                    if rotateMinimap and playerFacing then
                        local s = math.sin(playerFacing)
                        local c = math.cos(playerFacing)
                        effX = distEastWest * c - distNorthSouth * s
                        effY = distEastWest * s + distNorthSouth * c
                    end

                    local diffX = effX / mapRadius
                    local diffY = effY / mapRadius
                    local distFromCenter = math.sqrt(diffX * diffX + diffY * diffY)

                    local maxRadius = 0.90
                    local onEdge = false
                    local screenX, screenY
                    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"

                    local inRange = false
                    if shape == "SQUARE" then
                        inRange = (math.max(math.abs(diffX), math.abs(diffY)) <= maxRadius)
                    else
                        inRange = (distFromCenter <= maxRadius)
                    end

                    if inRange then
                        screenX = diffX * minimapWidth
                        screenY = diffY * minimapHeight
                    else
                        if not self._clampToEdge then
                            canRender = false
                        else
                            onEdge = true
                            if shape == "SQUARE" then
                                local maxCoord = math.max(math.abs(diffX), math.abs(diffY))
                                local scale = maxRadius / (maxCoord > 0 and maxCoord or 1)
                                screenX = (diffX * scale) * minimapWidth
                                screenY = (diffY * scale) * minimapHeight
                            else
                                local scale = maxRadius / (distFromCenter > 0 and distFromCenter or 1)
                                screenX = (diffX * scale) * minimapWidth
                                screenY = (diffY * scale) * minimapHeight
                            end
                        end
                    end

                    if canRender then
                        local pin = self:getOrCreatePin(name)
                        pin.peerData = peer
                        pin.peerDistYards = distYards
                        pin.onEdge = onEdge

                        pin:ClearAllPoints()
                        pin:SetPoint("CENTER", Minimap, "CENTER", screenX, screenY)

                        local cls = (peer.classFile or peer.class or "WARRIOR"):upper()
                        local c = MAP_PIN_CLASS_COLORS[cls] or { r = 0.78, g = 0.61, b = 0.43, hex = "|cffffffff" }

                        MapPinApplyClassIcon(pin.classIcon, cls)
                        pin.glow:SetVertexColor(c.r, c.g, c.b, onEdge and 0.55 or 0.85)
                        pin.arrow:SetVertexColor(c.r, c.g, c.b, 1.0)

                        if pin.arrow and pin.arrow.SetRotation then
                            if onEdge then
                                -- Seta aponta radialmente em direção ao membro
                                local bearing = math.atan2(screenY, screenX) - (math.pi / 2)
                                pcall(pin.arrow.SetRotation, pin.arrow, bearing)
                            else
                                -- Seta aponta na orientação (facing) do membro
                                local peerFacing = peer.facing or 0
                                if rotateMinimap and playerFacing then
                                    peerFacing = peerFacing - playerFacing
                                end
                                pcall(pin.arrow.SetRotation, pin.arrow, peerFacing)
                            end
                        end

                        pin:SetAlpha(onEdge and 0.88 or 1.0)
                        pin:Show()
                        renderedPins[name] = true
                    end
                end
            end
        end
    end

    -- Oculta os pinos que não foram renderizados nesta passada
    for pName, pFrame in pairs(self._pins) do
        if not renderedPins[pName] and pFrame:IsShown() then
            pFrame:Hide()
        end
    end
end

_G.MinimapPinManager = MinimapPinManager
if _G.GM then
    _G.GM.MinimapPinManager = MinimapPinManager
end
