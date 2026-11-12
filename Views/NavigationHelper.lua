local addonName, addonTable = ...
_G.GM = _G.GM or addonTable or {}

local SIDE_TAB_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

--- Guarda a última posição da janela para unificar todas as telas.
_G.GM.lastWindowPos = nil

--- Salva a posição atual de uma janela do GuildManager.
---@param frame table
function _G.GM.saveWindowPosition(frame)
    if not frame then return end
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
    if point then
        _G.GM.lastWindowPos = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            x = xOfs,
            y = yOfs
        }
    end
end

--- Restaura a posição salva em uma janela do GuildManager.
---@param frame table
function _G.GM.restoreWindowPosition(frame)
    if not frame or not _G.GM.lastWindowPos then return end
    local pos = _G.GM.lastWindowPos
    frame:ClearAllPoints()
    if pos.relativeTo then
        frame:SetPoint(pos.point, pos.relativeTo, pos.relativePoint, pos.x, pos.y)
    else
        frame:SetPoint(pos.point, pos.x, pos.y)
    end
end

--- Vincula o arrasto da janela com salvamento unificado de posição.
---@param frame table
function _G.GM.hookWindowDrag(frame)
    if not frame then return end
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        _G.GM.saveWindowPosition(f)
    end)
end

--- Normaliza formatos comuns de data (YYYY-MM-DD, DD/MM/YYYY, DD-MM-YYYY, etc.) para o padrão ISO YYYY-MM-DD.
---@param val string|nil
---@return string
function _G.GM.normalizeJoinDate(val)
    if not val or val == "" then return "" end
    val = val:match("^%s*(.-)%s*$")
    -- Formato: YYYY-MM-DD ou YYYY/MM/DD
    local y, m, d = val:match("^(%d%d%d%d)[%-%/%.](%d%d?)[%-%/%.](%d%d?)$")
    if y and m and d then
        return string.format("%04d-%02d-%02d", tonumber(y), tonumber(m), tonumber(d))
    end
    -- Formato: DD/MM/YYYY ou DD-MM-YYYY
    d, m, y = val:match("^(%d%d?)[%-%/%.](%d%d?)[%-%/%.](%d%d%d%d)$")
    if d and m and y then
        return string.format("%04d-%02d-%02d", tonumber(y), tonumber(m), tonumber(d))
    end
    -- Formato: DD/MM/YY (ano de 2 dígitos)
    d, m, y = val:match("^(%d%d?)[%-%/%.](%d%d?)[%-%/%.](%d%d)$")
    if d and m and y then
        local numY = tonumber(y)
        local fullY = (numY < 50) and (2000 + numY) or (1900 + numY)
        return string.format("%04d-%02d-%02d", fullY, tonumber(m), tonumber(d))
    end
    return val
end

local NAV_TABS = {
    {
        id = "audit",
        name = "Audit",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        texCoord = { 0.08, 0.92, 0.08, 0.92 },
        tooltipKey = "TAB_AUDIT_TOOLTIP",
        tooltipDescKey = "TAB_AUDIT_TOOLTIP_DESC",
        fallbackTitle = "Auditoria da Guilda",
        fallbackDesc = "Painel de controle e lista de membros da guilda.",
        getController = function() return (_G.GM and _G.GM.auditController) or _G.auditController end,
        getViewFrame = function()
            local v = (_G.GM and _G.GM.auditView) or _G.auditView
            return (v and v.getFrame and v:getFrame()) or (v and v._frame)
        end,
    },
    {
        id = "logs",
        name = "Logs",
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        texCoord = { 0.08, 0.92, 0.08, 0.92 },
        tooltipKey = "TAB_LOGS_TOOLTIP",
        tooltipDescKey = "TAB_LOGS_TOOLTIP_DESC",
        fallbackTitle = "Histórico de Logs",
        fallbackDesc = "Visualiza alterações cadastrais, entradas, saídas e promoções.",
        getController = function() return (_G.GM and _G.GM.logController) or _G.logController end,
        getViewFrame = function()
            local v = (_G.GM and _G.GM.logView) or _G.logView
            return (v and v.getFrame and v:getFrame()) or (v and v._frame)
        end,
    },
    {
        id = "groups",
        name = "Groups",
        icon = "Interface\\Icons\\INV_Misc_GroupLooking",
        texCoord = { 0.08, 0.92, 0.08, 0.92 },
        tooltipKey = "TAB_GROUPS_TOOLTIP",
        tooltipDescKey = "TAB_GROUPS_TOOLTIP_DESC",
        fallbackTitle = "Grupos & LFG",
        fallbackDesc = "Mural de Procurando Grupo (LFG) e gerenciamento de grupos da guilda.",
        getController = function() return (_G.GM and _G.GM.groupController) or _G.groupController end,
        getViewFrame = function()
            local v = (_G.GM and _G.GM.groupView) or _G.groupView
            return (v and v.getFrame and v:getFrame()) or (v and v._frame)
        end,
    },
    {
        id = "agenda",
        name = "Agenda",
        icon = "Interface\\Calendar\\UI-Calendar-Button",
        texCoord = { 0.0078, 0.375, 0.0156, 0.75 },
        fallbackIcon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
        tooltipKey = "TAB_AGENDA_TOOLTIP",
        tooltipDescKey = "TAB_AGENDA_TOOLTIP_DESC",
        fallbackTitle = "Agenda da Guilda",
        fallbackDesc = "Eventos agendados, raides e aniversários dos membros.",
        getController = function() return (_G.GM and _G.GM.agendaController) or _G.agendaController end,
        getViewFrame = function()
            local v = (_G.GM and _G.GM.agendaView) or _G.agendaView
            return (v and v.getFrame and v:getFrame()) or (v and v._frame)
        end,
    },
    {
        id = "professions",
        name = "Professions",
        icon = "Interface\\Icons\\Trade_BlackSmithing",
        texCoord = { 0.08, 0.92, 0.08, 0.92 },
        tooltipKey = "TAB_PROFESSIONS_TOOLTIP",
        tooltipDescKey = "TAB_PROFESSIONS_TOOLTIP_DESC",
        fallbackTitle = "Pedidos de Profissão",
        fallbackDesc = "Consulte receitas, veja quem faz na guilda e faça pedidos de fabricação.",
        getController = function() return (_G.GM and _G.GM.professionController) or _G.professionController end,
        getViewFrame = function()
            local v = (_G.GM and _G.GM.professionView) or _G.professionView
            return (v and v.getFrame and v:getFrame()) or (v and v._frame)
        end,
    },
    {
        id = "settings",
        name = "Settings",
        icon = "Interface\\Icons\\Trade_Engineering",
        texCoord = { 0.08, 0.92, 0.08, 0.92 },
        tooltipKey = "TAB_SETTINGS_TOOLTIP",
        tooltipDescKey = "TAB_SETTINGS_TOOLTIP_DESC",
        fallbackTitle = "Configurações do Addon",
        fallbackDesc = "Preferências gerais, alertas, sons, formato de data e minimapa.",
        getController = function() return (_G.GM and _G.GM.settingsController) or _G.settingsController end,
        getViewFrame = function()
            local v = (_G.GM and _G.GM.settingsView) or _G.settingsView
            return (v and v.getFrame and v:getFrame()) or (v and v._frame)
        end,
    },
}

--- Cria e padroniza as 6 abas laterais de navegação para qualquer tela principal do GuildManager.
---@param parentFrame table
---@param activeTabId string @"audit"|"logs"|"groups"|"agenda"|"professions"|"settings"
---@param viewInstance table|nil
---@return table @Lista de botões criados
function _G.GM.createNavigationSideTabs(parentFrame, activeTabId, viewInstance)
    if not parentFrame then return {} end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local createdTabs = {}
    local previousTab = nil

    local curL = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })

    for i, tabDef in ipairs(NAV_TABS) do
        local isActive = (tabDef.id == activeTabId)
        local btn = CreateFrame("Button", nil, parentFrame, template)
        btn:SetSize(36, 36)

        if not previousTab then
            btn:SetPoint("TOPLEFT", parentFrame, "TOPRIGHT", -2, -44)
        else
            btn:SetPoint("TOPLEFT", previousTab, "BOTTOMLEFT", 0, -8)
        end
        previousTab = btn

        if btn.SetBackdrop then
            btn:SetBackdrop(SIDE_TAB_BACKDROP)
            if isActive then
                btn:SetBackdropColor(0.18, 0.12, 0.04, 0.95)
                btn:SetBackdropBorderColor(1.0, 0.82, 0.20, 1.0)
            else
                btn:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
                btn:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
            end
        end

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 4, -4)
        icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -4, 4)

        local ok = icon:SetTexture(tabDef.icon)
        if ok ~= false and icon:GetTexture() and tabDef.texCoord then
            icon:SetTexCoord(tabDef.texCoord[1], tabDef.texCoord[2], tabDef.texCoord[3], tabDef.texCoord[4])
        elseif tabDef.fallbackIcon then
            icon:SetTexture(tabDef.fallbackIcon)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end

        if isActive then
            icon:SetVertexColor(1.0, 1.0, 1.0)
            -- Brilho dourado de aba ativa
            local glow = btn:CreateTexture(nil, "OVERLAY")
            glow:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 2)
            glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)
            glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
            glow:SetBlendMode("ADD")
            glow:SetVertexColor(1.0, 0.85, 0.20, 0.80)
            btn.glow = glow
        else
            icon:SetVertexColor(0.65, 0.65, 0.65)
            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints(btn)
            hl:SetColorTexture(1.0, 0.82, 0.0, 0.30)
            btn:SetHighlightTexture(hl)
        end
        btn.icon = icon

        btn:SetScript("OnEnter", function(b)
            if not isActive and b.SetBackdropBorderColor then
                b:SetBackdropBorderColor(0.95, 0.70, 0.25, 1.0)
                b:SetBackdropColor(0.08, 0.05, 0.02, 0.95)
                icon:SetVertexColor(1.0, 1.0, 1.0)
            end
            local title = curL[tabDef.tooltipKey] or tabDef.fallbackTitle
            local desc = curL[tabDef.tooltipDescKey] or tabDef.fallbackDesc
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|cffffd200" .. title .. "|r")
            if isActive then
                GameTooltip:AddLine("|cff888888" .. (curL["TAB_CURRENT"] or "Aba atual") .. "|r", 0.7, 0.7, 0.7)
            end
            GameTooltip:AddLine(desc, 1, 1, 1, true)
            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function(b)
            if not isActive and b.SetBackdropBorderColor then
                b:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.85)
                b:SetBackdropColor(0.035, 0.025, 0.012, 0.85)
                icon:SetVertexColor(0.65, 0.65, 0.65)
            end
            GameTooltip:Hide()
        end)

        if not isActive then
            btn:SetScript("OnClick", function()
                if PlaySound then
                    pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841)
                end
                _G.GM.saveWindowPosition(parentFrame)
                if viewInstance and viewInstance.hide then
                    viewInstance:hide()
                else
                    parentFrame:Hide()
                end
                local ctrl = tabDef.getController()
                if ctrl and ctrl.show then
                    ctrl:show()
                    local targetFrame = tabDef.getViewFrame()
                    if targetFrame then
                        _G.GM.restoreWindowPosition(targetFrame)
                    end
                end
            end)
        end

        table.insert(createdTabs, btn)
    end

    return createdTabs
end
