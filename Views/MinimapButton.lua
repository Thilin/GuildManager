---@class MinimapButton
---@field private _button table
MinimapButton = {}
MinimapButton.__index = MinimapButton

local DEFAULT_ANGLE = 215

--- Construtor do botão orbitante do Minimapa do GuildManager.
---@return MinimapButton
function MinimapButton:new()
    local instance = setmetatable({}, self)
    instance._button = nil
    instance:createUI()
    return instance
end

--- Cria e estiliza o balão do minimapa com fundo vermelho e texto GM em dourado.
function MinimapButton:createUI()
    if self._button or not Minimap then
        return
    end

    local button = CreateFrame("Button", "GuildManagerMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:EnableMouse(true)
    button:SetMovable(true)

    -- Fundo circular vermelho intenso (balão)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(21, 21)
    bg:SetPoint("CENTER", button, "CENTER", 0, 0)
    bg:SetVertexColor(0.85, 0.08, 0.08, 1.0) -- Vermelho vibrante
    button.bg = bg

    -- Texto "GM" em dourado clássico
    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    label:SetPoint("CENTER", button, "CENTER", 0, 1)
    label:SetText("|cffffd200GM|r")
    label:SetTextColor(1.0, 0.82, 0.0, 1.0)
    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(1, -1)
    button.label = label

    -- Borda metálica circular clássica da Blizzard
    local border = button:CreateTexture(nil, "OVERLAY", nil, 1)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    button.border = border

    -- Highlight suave ao passar o mouse
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetPoint("CENTER", button, "CENTER", 0, 0)
    highlight:SetSize(32, 32)
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
            label:SetPoint("CENTER", button, "CENTER", 1, 0)
        end
    end)

    button:SetScript("OnMouseUp", function()
        label:SetPoint("CENTER", button, "CENTER", 0, 1)
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

    -- Ao clicar no balão, abre a tela de logs (ou auditoria com botão direito)
    button:SetScript("OnClick", function(_, btn)
        if wasDragged then
            wasDragged = false
            return
        end

        if btn == "LeftButton" then
            if _G.GM and _G.GM.logController and _G.GM.logController.toggle then
                _G.GM.logController:toggle()
            end
        elseif btn == "RightButton" then
            if _G.GM and _G.GM.auditController and _G.GM.auditController.toggle then
                _G.GM.auditController:toggle()
            end
        end
    end)

    -- Tooltip explicativo ao passar o mouse
    button:SetScript("OnEnter", function(f)
        GameTooltip:SetOwner(f, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cffffd200Guild Manager|r")
        GameTooltip:AddLine("|cff00ff00Clique com o Botão Esquerdo:|r Abrir Registro de Logs")
        GameTooltip:AddLine("|cffffd200Clique com o Botão Direito:|r Abrir Auditoria de Membros")
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffaaaaaaArraste com o botão esquerdo para orbitar a borda do minimapa|r", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self._button = button

    -- Posiciona no ângulo salvo ou padrão
    local savedAngle = (_G.GM_DB and _G.GM_DB.settings and _G.GM_DB.settings.minimapPos) or DEFAULT_ANGLE
    self:updatePosition(savedAngle)
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

-- Exportação/Alias de compatibilidade
minimapButton = MinimapButton
