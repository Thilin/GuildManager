---@class ProfessionController
--- Controlador do módulo de profissões, catálogo de receitas e pedidos de fabricação no padrão MVC.
---@field private _professionService ProfessionService
---@field private _guildRosterService GuildRosterService
---@field private _memberService MemberService
---@field private _professionView ProfessionView
ProfessionController = {}
ProfessionController.__index = ProfessionController

---@param professionService ProfessionService
---@param guildRosterService GuildRosterService
---@param memberService MemberService
---@param professionView ProfessionView
---@return ProfessionController
function ProfessionController:new(professionService, guildRosterService, memberService, professionView)
    local instance = setmetatable({}, self)

    instance._professionService = professionService
    instance._guildRosterService = guildRosterService
    instance._memberService = memberService
    instance._professionView = professionView

    return instance
end

--- Inicializa os ganchos, comandos slash e listeners de atualização
function ProfessionController:initHooks()
    local view = self._professionView
    local service = self._professionService

    if not view or not service then return end

    -- Escuta alterações disparadas pelo serviço para atualizar a tela
    service:addListener(function()
        if view and view.isShown and view:isShown() then
            view:refresh()
        end
    end)

    -- Configura comandos de barra (Slash Commands)
    SLASH_GMPROF1 = "/gmcraft"
    SLASH_GMPROF2 = "/gmpedidos"
    SLASH_GMPROF3 = "/gmprof"
    SlashCmdList["GMPROF"] = function(msg)
        local arg = (msg or ""):lower():match("^%s*(.-)%s*$")
        if arg == "scan" then
            if service and service.scanPlayerSkills then
                local count = service:scanPlayerSkills()
                service:scanTradeSkillFrame()
                service:scanCraftFrame()
                print(string.format("|cff00ff00[GuildManager]|r Escaneamento concluído! %d profissões detectadas.", count))
            end
        else
            self:toggle()
        end
    end
end

--- Exibe a janela de profissões
function ProfessionController:show()
    if self._professionView then
        self._professionView:show()
    end
end

--- Oculta a janela de profissões
function ProfessionController:hide()
    if self._professionView then
        self._professionView:hide()
    end
end

--- Alterna a janela de profissões
function ProfessionController:toggle()
    if self._professionView then
        self._professionView:toggle()
    end
end

--- Atualiza a visualização caso esteja aberta
function ProfessionController:refreshView()
    if self._professionView and self._professionView.isShown and self._professionView:isShown() then
        self._professionView:refresh()
    end
end
