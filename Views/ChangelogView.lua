local addonName, addonTable = ...
local L = (_G.GM and _G.GM.L) or _G.L or setmetatable({}, { __index = function(_, k) return k end })

---@class ChangelogView
---@field private _frame table|nil
---@field private _db table|nil
---@field private _version string
ChangelogView = {}
ChangelogView.__index = ChangelogView

local DIALOG_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local CONTAINER_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local SUB_CONTAINER_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

--- Dados do Changelog por versão do addon.
local CHANGELOG_DATA = {
    ["1.2"] = {
        title = "Guild Manager Forever v1.2",
        date = "12/11/2026",
        sections = {
            {
                category = "GRUPOS & PROCURANDO GRUPO (LFG)",
                color = "|cffffd200",
                items = {
                    "Mural de Procurando Grupo (LFG) em grade com 2 cards por linha.",
                    "Cada membro da guilda pode criar até 5 cards de LFG simultâneos.",
                    "Cards expiram automaticamente após 72 horas com contagem regressiva.",
                    "Criação de grupos liberada para todos os membros da guilda (sem limites).",
                    "Sincronização em 2 tempos (Criador -> Líder da Guilda -> Outros membros).",
                }
            },
            {
                category = "INTERFACE & EXPERIÊNCIA",
                color = "|cff33ccff",
                items = {
                    "Telas padronizadas na dimensão de alta resolução da Auditoria (1180x614).",
                    "Navegação rápida por abas laterais temáticas entre todas as ferramentas.",
                    "Botão de contato do desenvolvedor via Discord (thillin_) no topo das telas.",
                    "Janela de resumo de novidades (Changelog) automática a cada atualização.",
                }
            },
            {
                category = "MEMBROS & ESTABILIDADE",
                color = "|cff2ecc71",
                items = {
                    "Lista completa de Alts vinculados no popup do membro e na auditoria.",
                    "Sincronização automática de dados para membros que conectam depois.",
                    "Filtro de mensagens no chat suprimindo avisos de limite de envio da Blizzard.",
                    "Fixação do histórico de mensagens no chat (desativando o sumiço automático em 2-3s).",
                }
            }
        }
    },
    ["1.0"] = {
        title = "Guild Manager Forever v1.0",
        date = "11/11/2026",
        sections = {
            {
                category = "LANÇAMENTO",
                color = "|cffffd200",
                items = {
                    "Versão inicial do Guild Manager Forever para Classic Beta.",
                }
            }
        }
    }
}

--- Obtém a versão atual do addon a partir do .toc ou fallback.
---@return string
local function getAddonVersion()
    local ver = nil
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        ver = C_AddOns.GetAddOnMetadata(addonName or "GuildManagerForever", "Version")
    elseif GetAddOnMetadata then
        ver = GetAddOnMetadata(addonName or "GuildManagerForever", "Version")
    end
    if not ver or ver == "" or ver:find("@") then
        ver = "1.2"
    end
    return ver:match("^%s*(.-)%s*$") or "1.2"
end

--- Construtor da View do Changelog.
---@return ChangelogView
function ChangelogView:new()
    local instance = setmetatable({}, self)
    instance._frame = nil
    instance._db = nil
    instance._version = getAddonVersion()
    instance:createUI()
    return instance
end

function ChangelogView:getFrame()
    return self._frame
end

function ChangelogView:isShown()
    return self._frame and self._frame:IsShown()
end

--- Cria os elementos visuais da janela de Changelog.
function ChangelogView:createUI()
    if self._frame then return end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "GuildManagerChangelogFrame", UIParent, template)
    frame:SetSize(520, 500)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    frame:Hide()
    self._frame = frame

    if tinsert and UISpecialFrames then
        tinsert(UISpecialFrames, "GuildManagerChangelogFrame")
    end

    -- Fundo sólido e moldura temática
    local solidBg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    solidBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    solidBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    solidBg:SetColorTexture(0.04, 0.03, 0.02, 1.0)

    if frame.SetBackdrop then
        frame:SetBackdrop(DIALOG_BACKDROP)
        frame:SetBackdropColor(0.05, 0.035, 0.015, 0.98)
        frame:SetBackdropBorderColor(1.0, 0.68, 0.22, 1.0)
    end

    -- Botão Fechar ("X")
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetSize(28, 28)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Botão Discord Contato / Bugs / Feedback
    local discordBtn = CreateFrame("Button", nil, frame, template)
    discordBtn:SetSize(125, 20)
    discordBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    if discordBtn.SetBackdrop then
        discordBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, tileSize = 0, edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        discordBtn:SetBackdropColor(0.08, 0.08, 0.14, 0.90)
        discordBtn:SetBackdropBorderColor(0.35, 0.40, 0.95, 0.75)
    end
    local discText = discordBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    discText:SetPoint("CENTER", discordBtn, "CENTER", 0, 0)
    discText:SetText("|cff5865f2Discord:|r |cffffffffthillin_|r")

    discordBtn:SetScript("OnEnter", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.55, 0.65, 1.0, 1.0)
            btn:SetBackdropColor(0.12, 0.12, 0.22, 0.95)
        end
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        GameTooltip:AddLine("|cff5865f2Discord:|r |cffffffffthillin_|r")
        GameTooltip:AddLine("Contato direto para dúvidas, sugestões, bugs e feedback.", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine("|cffffd200Clique para copiar no chat.|r", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    discordBtn:SetScript("OnLeave", function(btn)
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.35, 0.40, 0.95, 0.75)
            btn:SetBackdropColor(0.08, 0.08, 0.14, 0.90)
        end
        GameTooltip:Hide()
    end)
    discordBtn:SetScript("OnClick", function()
        if ChatFrame_OpenChat then
            ChatFrame_OpenChat("thillin_")
        end
        print("|cff5865f2[GuildManager]|r Discord para contato, bugs e feedback: |cffffffffthillin_|r (Copiado para o chat!)")
    end)

    -- Ícone do Cabeçalho
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_07")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Título da Janela
    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    titleText:SetText("FIX & UPDATES")
    self._titleText = titleText

    -- Divisória do Cabeçalho
    local headerSep = frame:CreateTexture(nil, "ARTWORK")
    headerSep:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -46)
    headerSep:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    headerSep:SetHeight(1)
    headerSep:SetColorTexture(0.58, 0.37, 0.11, 0.90)

    -- Inset do Conteúdo do Changelog
    local contentInset = CreateFrame("Frame", nil, frame, template)
    contentInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -52)
    contentInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 60)
    if contentInset.SetBackdrop then
        contentInset:SetBackdrop(CONTAINER_BACKDROP)
        contentInset:SetBackdropColor(0.035, 0.022, 0.010, 0.90)
        contentInset:SetBackdropBorderColor(0.60, 0.42, 0.15, 0.85)
    end

    -- ScrollFrame do Changelog
    local scrollFrame = CreateFrame("ScrollFrame", "GuildManagerChangelogScrollFrame", contentInset, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", contentInset, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", contentInset, "BOTTOMRIGHT", -26, 8)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(sf, delta)
        local cur = sf:GetVerticalScroll()
        local maxScroll = math.max(0, (self._scrollChild:GetHeight() or 0) - sf:GetHeight())
        sf:SetVerticalScroll(math.max(0, math.min(maxScroll, cur - (delta * 24))))
    end)
    self._scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(450, 10)
    scrollFrame:SetScrollChild(scrollChild)
    self._scrollChild = scrollChild

    -- Rodapé
    local footerSep = frame:CreateTexture(nil, "ARTWORK")
    footerSep:SetPoint("TOPLEFT", contentInset, "BOTTOMLEFT", 0, -8)
    footerSep:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    footerSep:SetHeight(1)
    footerSep:SetColorTexture(0.58, 0.37, 0.11, 0.90)

    local helpText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    helpText:SetPoint("TOPLEFT", footerSep, "BOTTOMLEFT", 4, -8)
    helpText:SetText("|cff888888Esta janela abre uma única vez por atualização.\nComando: |cffffd200/gm changelog|r|r")

    -- Botão "Entendi! / Fechar"
    local okBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    okBtn:SetSize(120, 26)
    okBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 14)
    okBtn:SetText("Entendi!")
    okBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    self:populateChangelog(self._version)
end

--- Preenche o conteúdo do Changelog para a versão indicada.
---@param version string|nil
function ChangelogView:populateChangelog(version)
    if not self._scrollChild then return end

    local targetVersion = version or self._version or "1.2"
    local data = CHANGELOG_DATA[targetVersion] or CHANGELOG_DATA["1.2"]

    -- Remove widgets antigos do scrollChild
    if self._entryFrames then
        for _, f in ipairs(self._entryFrames) do
            if f and f.Hide then
                f:Hide()
            end
        end
    end
    self._entryFrames = {}

    local yOffset = 4
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    -- Banner de introdução da versão
    local banner = CreateFrame("Frame", nil, self._scrollChild, template)
    banner:SetSize(446, 38)
    banner:SetPoint("TOPLEFT", self._scrollChild, "TOPLEFT", 2, -yOffset)
    if banner.SetBackdrop then
        banner:SetBackdrop(SUB_CONTAINER_BACKDROP)
        banner:SetBackdropColor(0.12, 0.08, 0.03, 0.95)
        banner:SetBackdropBorderColor(0.60, 0.42, 0.15, 0.90)
    end

    local bTitle = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bTitle:SetPoint("TOPLEFT", banner, "TOPLEFT", 10, -8)
    bTitle:SetText(string.format("|cffffd200%s|r", data.title or ("Guild Manager v" .. targetVersion)))

    local bDate = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bDate:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 10, 6)
    bDate:SetText(string.format("|cffaaaaaaData da atualização: %s|r", data.date or "Recente"))

    table.insert(self._entryFrames, banner)
    yOffset = yOffset + 44

    -- Seções do Changelog
    for _, section in ipairs(data.sections or {}) do
        -- Título da Seção
        local sTitle = self._scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sTitle:SetPoint("TOPLEFT", self._scrollChild, "TOPLEFT", 6, -yOffset)
        sTitle:SetText(string.format("%s▶ %s|r", section.color or "|cffffd200", section.category))
        table.insert(self._entryFrames, sTitle)
        yOffset = yOffset + 20

        -- Container dos Itens
        local numItems = #(section.items or {})
        local boxHeight = math.max(30, numItems * 22 + 10)
        local box = CreateFrame("Frame", nil, self._scrollChild, template)
        box:SetSize(446, boxHeight)
        box:SetPoint("TOPLEFT", self._scrollChild, "TOPLEFT", 2, -yOffset)
        if box.SetBackdrop then
            box:SetBackdrop(SUB_CONTAINER_BACKDROP)
            box:SetBackdropColor(0.04, 0.025, 0.01, 0.85)
            box:SetBackdropBorderColor(0.50, 0.35, 0.15, 0.80)
        end

        local itemY = -8
        for _, itemText in ipairs(section.items or {}) do
            local bullet = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            bullet:SetPoint("TOPLEFT", box, "TOPLEFT", 10, itemY)
            bullet:SetPoint("RIGHT", box, "RIGHT", -10, 0)
            bullet:SetJustifyH("LEFT")
            bullet:SetText(string.format("|cffffd200•|r  |cffffffff%s|r", itemText))
            itemY = itemY - 22
        end

        table.insert(self._entryFrames, box)
        yOffset = yOffset + boxHeight + 8
    end

    self._scrollChild:SetHeight(math.max(yOffset + 10, 10))
end

--- Exibe a janela de Changelog.
---@param version string|nil
function ChangelogView:show(version)
    if not self._frame then
        self:createUI()
    end
    self:populateChangelog(version or self._version)
    self._frame:Show()
end

--- Oculta a janela de Changelog.
function ChangelogView:hide()
    if self._frame then
        self._frame:Hide()
    end
end

--- Verifica no login se a versão atual já foi visualizada.
--- Se for uma versão nova (ou primeira instalação), abre a janela UMA ÚNICA VEZ e grava a versão no banco.
---@param dbTable table|nil
function ChangelogView:checkVersionOnLogin(dbTable)
    local db = dbTable or _G.GM_DB
    if type(db) ~= "table" then return end

    local currentVer = getAddonVersion()
    local lastSeen = db.lastChangelogVersion or db.lastSeenVersion

    if lastSeen ~= currentVer then
        -- Versão nova detectada! Abre a janela do Changelog
        self:show(currentVer)
        -- Marca a versão atual como visualizada para não abrir novamente nesta versão
        db.lastChangelogVersion = currentVer
        db.lastSeenVersion = currentVer
    end
end

_G.ChangelogView = ChangelogView
