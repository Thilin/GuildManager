---@class SyncNotificationView
---@field private _frame table|nil
---@field private _titleText table|nil
---@field private _senderText table|nil
---@field private _detailsText table|nil
---@field private _iconTexture table|nil
---@field private _elapsed number
---@field private _isHovered boolean
SyncNotificationView = {}
SyncNotificationView.__index = SyncNotificationView

local FADE_DURATION = 3.0 -- Efeito de fade com duração de 3 segundos
local TOAST_WIDTH = 330
local TOAST_HEIGHT = 68

local TOAST_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

--- Construtor da View de notificação de sincronização (caixinha toast).
---@return SyncNotificationView
function SyncNotificationView:new()
    local instance = setmetatable({}, self)
    instance._frame = nil
    instance._elapsed = 0
    instance._isHovered = false
    return instance
end

--- Cria e inicializa os elementos visuais da caixinha de sincronização se ainda não existirem.
function SyncNotificationView:createUI()
    if self._frame then return end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Button", "GM_SyncNotificationToast", UIParent, template)

    frame:SetSize(TOAST_WIDTH, TOAST_HEIGHT)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -115)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)

    if frame.SetBackdrop then
        frame:SetBackdrop(TOAST_BACKDROP)
        frame:SetBackdropColor(0.04, 0.025, 0.012, 0.95)
        frame:SetBackdropBorderColor(0.12, 0.85, 0.35, 1.0)
    end

    -- Ícone (Status / Check)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("LEFT", frame, "LEFT", 12, 0)
    icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")

    -- Título da notificação
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 4)
    title:SetText("|cff00ff00Sincronização Realizada|r")

    -- Texto de com quem está sincronizando
    local senderText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    senderText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    senderText:SetText("Sincronizando com a guilda")

    -- Detalhes da sincronização
    local detailsText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    detailsText:SetPoint("TOPLEFT", senderText, "BOTTOMLEFT", 0, -3)
    detailsText:SetText("Banco de dados atualizado com sucesso!")

    -- Botão Fechar ("X")
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        self:hide()
    end)

    -- Ao passar o mouse, pausa o fade e mantém opacidade máxima para leitura
    frame:SetScript("OnEnter", function()
        self._isHovered = true
        frame:SetAlpha(1.0)
    end)

    frame:SetScript("OnLeave", function()
        self._isHovered = false
        -- Reinicia a contagem do fade de 3 segundos ao retirar o cursor
        self._elapsed = 0
    end)

    -- Ao clicar na caixinha, abre a janela principal do GuildManager
    frame:SetScript("OnClick", function()
        if SlashCmdList["GUILDMANAGER"] then
            SlashCmdList["GUILDMANAGER"]("")
        end
    end)

    frame:Hide()

    self._frame = frame
    self._titleText = title
    self._senderText = senderText
    self._detailsText = detailsText
    self._iconTexture = icon
end

--- Exibe a caixinha indicando início de sincronização em andamento com um jogador.
--- Permanece visível enquanto a sincronização ocorre.
---@param peerName string @Nome do jogador com quem o AddOn está sincronizando
function SyncNotificationView:showProgress(peerName)
    self:createUI()
    if not self._frame then return end

    local cleanPeer = peerName or "Membro"
    cleanPeer = cleanPeer:match("^[^-]+") or cleanPeer

    -- Remove qualquer OnUpdate de fade anterior
    self._frame:SetScript("OnUpdate", nil)

    -- Estilo para estado em andamento (Dourado / Em progresso)
    if self._frame.SetBackdropBorderColor then
        self._frame:SetBackdropBorderColor(1.0, 0.82, 0.15, 1.0)
    end
    self._iconTexture:SetTexture("Interface\\Buttons\\UI-RefreshButton")
    self._titleText:SetText("|cffffff00Sincronizando...|r")
    self._senderText:SetText(string.format("Sincronizando com: |cffffff00%s|r", cleanPeer))
    self._detailsText:SetText("Transferindo informações do AddOn...")

    self._isHovered = false
    self._elapsed = 0
    self._frame:SetAlpha(1.0)
    self._frame:Show()
end

--- Exibe a caixinha com sucesso e inicia o efeito de fade que dura exatamente 3 segundos.
---@param peerName string @Nome do membro com quem o AddOn sincronizou
---@param summary table|nil @Resumo das alterações (totalAdded, totalUpdated)
function SyncNotificationView:showSuccess(peerName, summary)
    self:createUI()
    if not self._frame then return end

    local cleanPeer = peerName or "Membro"
    cleanPeer = cleanPeer:match("^[^-]+") or cleanPeer

    -- Estilo de sucesso (Verde esmeralda com checkmark)
    if self._frame.SetBackdropBorderColor then
        self._frame:SetBackdropBorderColor(0.12, 0.85, 0.35, 1.0)
    end
    self._iconTexture:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
    self._titleText:SetText("|cff00ff00Sincronização Concluída|r")
    self._senderText:SetText(string.format("Sincronizado com: |cffffff00%s|r", cleanPeer))

    if type(summary) == "table" and ((summary.totalAdded or 0) > 0 or (summary.totalUpdated or 0) > 0) then
        self._detailsText:SetText(string.format("+%d novos registros | %d complementados",
            summary.totalAdded or 0, summary.totalUpdated or 0))
    else
        self._detailsText:SetText("Banco de dados 100% atualizado!")
    end

    -- Reinicia estado de exibição e animação
    self._elapsed = 0
    self._isHovered = false

    self._frame:SetAlpha(1.0)
    self._frame:Show()

    -- Toca som suave de confirmação no WoW
    if PlaySound then
        local soundId = (SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_OPEN) or 846
        pcall(PlaySound, soundId)
    end

    -- Animação de fade contínuo com duração de 3 segundos
    self._frame:SetScript("OnUpdate", function(f, dt)
        if self._isHovered then
            return
        end

        self._elapsed = self._elapsed + dt

        if self._elapsed >= FADE_DURATION then
            f:SetScript("OnUpdate", nil)
            f:SetAlpha(0)
            f:Hide()
        else
            -- Efeito de fade gradual (1.0 -> 0.0) durante os 3 segundos
            local progress = self._elapsed / FADE_DURATION
            local currentAlpha = math.max(0, 1.0 - progress)
            f:SetAlpha(currentAlpha)
        end
    end)
end

--- Exibe a caixinha indicando erro na sincronização com efeito de fade que dura 3 segundos.
---@param peerName string|nil @Nome do membro com quem ocorreu o erro
---@param errorMessage string @Descrição do erro capturado
function SyncNotificationView:showError(peerName, errorMessage)
    self:createUI()
    if not self._frame then return end

    local cleanPeer = peerName or "Membro da guilda"
    cleanPeer = cleanPeer:match("^[^-]+") or cleanPeer

    -- Estilo de erro (Borda vermelha com ícone de falha/alerta)
    if self._frame.SetBackdropBorderColor then
        self._frame:SetBackdropBorderColor(1.0, 0.25, 0.25, 1.0)
    end
    self._iconTexture:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
    self._titleText:SetText("|cffff4444Erro na Sincronização|r")
    self._senderText:SetText(string.format("Com: |cffffff00%s|r", cleanPeer))
    self._detailsText:SetText(string.format("|cffff8888%s|r", errorMessage or "Falha inesperada."))

    -- Reinicia estado de exibição e animação
    self._elapsed = 0
    self._isHovered = false

    self._frame:SetAlpha(1.0)
    self._frame:Show()

    -- Toca som de erro / atenção no WoW
    if PlaySound then
        local soundId = (SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_ABANDON) or 847
        pcall(PlaySound, soundId)
    end

    -- Animação de fade contínuo com duração de 3 segundos
    self._frame:SetScript("OnUpdate", function(f, dt)
        if self._isHovered then
            return
        end

        self._elapsed = self._elapsed + dt

        if self._elapsed >= FADE_DURATION then
            f:SetScript("OnUpdate", nil)
            f:SetAlpha(0)
            f:Hide()
        else
            -- Efeito de fade gradual (1.0 -> 0.0) durante os 3 segundos
            local progress = self._elapsed / FADE_DURATION
            local currentAlpha = math.max(0, 1.0 - progress)
            f:SetAlpha(currentAlpha)
        end
    end)
end

--- Alias de compatibilidade para exibir a notificação.
---@param peerName string
---@param summary table|nil
function SyncNotificationView:show(peerName, summary)
    self:showSuccess(peerName, summary)
end

--- Oculta imediatamente a notificação.
function SyncNotificationView:hide()
    if self._frame then
        self._frame:SetScript("OnUpdate", nil)
        self._frame:SetAlpha(0)
        self._frame:Hide()
    end
end

_G.SyncNotificationView = SyncNotificationView
return SyncNotificationView
