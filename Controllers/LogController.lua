---@class LogController
---@field private _logService LogService
---@field private _logView LogView
LogController = {}
LogController.__index = LogController

--- Construtor do Controller de logs de guilda.
---@param logService LogService @Serviço de gerenciamento de logs
---@param logView LogView @Camada de visualização de logs
---@return LogController
function LogController:new(logService, logView)
    local instance = setmetatable({}, self)

    instance._logService = logService
    instance._logView = logView

    return instance
end

--- Inicializa os comandos de chat e ouvintes de eventos para a tela de logs.
function LogController:initHooks()
    -- Vincula o callback de atualização da View ao serviço
    if self._logView and self._logView.setOnRefreshCallback then
        self._logView:setOnRefreshCallback(function()
            self:refreshLogs()
        end)
    end

    -- Comando de chat /gmlogs e /guildmanagerlogs
    SLASH_GUILDMANAGERLOGS1 = "/gmlogs"
    SLASH_GUILDMANAGERLOGS2 = "/guildmanagerlogs"
    SlashCmdList["GUILDMANAGERLOGS"] = function()
        self:toggle()
    end
end

--- Atualiza os dados exibidos na View buscando os registros do serviço.
function LogController:refreshLogs()
    if not self._logService or not self._logView then
        return
    end

    if _G.GM and _G.GM.guildRosterService and IsInGuild and IsInGuild() then
        _G.GM.guildRosterService:scanRoster()
    end

    if self._logService.cleanInvalidInviteJoinedLogs then
        self._logService:cleanInvalidInviteJoinedLogs()
    end

    local allLogs = self._logService:getAllLogs() or {}
    self._logView:setLogs(allLogs)
end

--- Abre a tela de logs e carrega os registros.
function LogController:show()
    if _G.GM and _G.GM.memberController and _G.GM.memberController.requestGuildEventLog then
        _G.GM.memberController:requestGuildEventLog(true)
    elseif QueryGuildEventLog then
        pcall(QueryGuildEventLog)
    end
    self:refreshLogs()
    if self._logView then
        self._logView:show()
    end
end

--- Fecha a tela de logs.
function LogController:hide()
    if self._logView then
        self._logView:hide()
    end
end

--- Alterna a visibilidade da tela de logs.
function LogController:toggle()
    if not self._logView then
        return
    end

    if self._logView:isShown() then
        self._logView:hide()
    else
        self:show()
    end
end

-- Exportação/Alias de compatibilidade
logController = LogController
