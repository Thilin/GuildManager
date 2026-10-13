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
    instance:createUI()
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
