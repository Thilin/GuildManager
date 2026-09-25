---@class Member
--- [Campos Nativos da Blizzard]
---@field _name string @Nome do personagem (sem realm ou com realm)
---@field _raceID string|number @Identificador ou nome da raça
---@field _rankName string @Nome do cargo/rank do membro na guilda (ex: "Oficial", "Membro")
---@field _rankIndex number @Índice do rank (0 = Guild Master, números maiores = ranks inferiores)
---@field _level number @Nível atual do personagem (1-60/70/80...)
---@field _classDisplayName string @Nome localizado da classe (ex: "Guerreiro", "Mago")
---@field _zone string @Zona atual onde o jogador está conectado (ex: "Ventobravo")
---@field _publicNote string @Nota pública da guilda (visível para todos os membros)
---@field _officerNote string @Nota de oficial (visível apenas para oficiais/GM)
---@field _isOnline boolean @Indica se o jogador está online no momento
---@field _status number @Status do jogador (0: Online, 1: AFK/Ausente, 2: DND/Não Perturbe)
---@field _class string @Token em inglês da classe (ex: "WARRIOR", "MAGE" - usado para cores de classe)
---@field _repStanding number @Nível de reputação com a guilda (0: Odiado até 8: Exaltado)
---@field _guid string @Identificador único global do personagem no WoW (GUID)
---
--- [Campos Customizados do Addon]
---@field _customNote string @Nota interna personalizada criada pela gestão da guilda
---@field _alts string[] @Lista de nomes dos personagens secundários (alts) associados
---@field _birthday string @Data de aniversário do jogador (formato MM/DD)
---@field _dateJoin string @Data em que o jogador entrou na guilda (formato AAAA-MM-DD)
---@field _dateLeft string @Última data em que o jogador saiu da guilda
---@field _lastRank string @Último cargo do jogador
---@field _timesLeft number @Quantidade de vezes que o jogador saiu e retornou à guilda
---@field _isMain boolean @Define se este personagem é o principal (Main) ou um Alt
---@field _isInGuild boolean @Indica se o jogador ainda pertence à guilda ou já saiu
---@field _recruiter string @Nome do membro que recrutou/convidou este jogador
Member = {}
Member.__index = Member

--- Construtor da entidade Member.
--- Recebe uma tabela com os atributos e instancia o objeto de domínio
---@param data table @Tabela com os valores iniciais do membro
---@return Member
function Member:new(data)
    local instance = setmetatable({}, self)
    data = data or {}

        -- Atributos nativos da API da Blizzard:
    instance._name = data.name or ""
    instance._race = data.race or data.raceName or (type(data.raceID) == "string" and data.raceID or "")
    instance._raceID = data.raceID or instance._race
    instance._rankName = data.rankName or ""
    instance._rankIndex = data.rankIndex or 0
    instance._level = data.level or 1
    instance._classDisplayName = data.classDisplayName or ""
    instance._zone = data.zone or ""
    instance._publicNote = data.publicNote or ""
    instance._officerNote = data.officerNote or ""
    instance._isOnline = data.isOnline or false
    instance._status = data.status or 0
    instance._class = data.class or ""
    instance._achievementPoints = tonumber(data.achievementPoints) or 0
    instance._achievementRank = tonumber(data.achievementRank) or 0
    instance._repStanding = data.repStanding or 0
    instance._guid = data.guid or ""

        -- Atributos customizados e gerenciais do Addon:
    instance._customNote = data.customNote or ""
    instance._alts = data.alts or {}
    instance._birthday = data.birthday or ""
    instance._dateJoin = data.dateJoin or ""
    instance._dateLeft = data.dateLeft or ""
    instance._lastRank = data.lastRank or ""
    instance._timesLeft = data.timesLeft or 0
    if data.isMain ~= nil then
        instance._isMain = (data.isMain == true)
    else
        instance._isMain = true
    end
    if data.isInGuild ~= nil then
        instance._isInGuild = (data.isInGuild == true)
    else
        instance._isInGuild = true
    end
    instance._recruiter = data.recruiter or ""

    return instance
end

--- Obtém o nome do membro.
---@return string
function Member:getName()
    return self._name
end

--- Define o nome do membro com validação.
---@param name string
function Member:setName(name)
    if type(name) == "string" and name ~= "" then
        self._name = name
    end
end

--- Obtém o nível atual do membro.
---@return number
function Member:getLevel()
    return self._level
end

--- Define o nível do membro com validação de limites (1 a 80).
---@param level number
function Member:setLevel(level)
    local n = tonumber(level)
    if n and n >= 1 and n <= 80 then
        self._level = n
    end
end

--- Obtém o token da classe em inglês (ex: "WARRIOR").
---@return string
function Member:getClass()
    return self._class
end

--- Define o token da classe.
---@param class string
function Member:setClass(class)
    if type(class) == "string" then
        self._class = class
    end
end

--- Obtém o nome localizado da classe (ex: "Guerreiro").
---@return string
function Member:getClassDisplayName()
    return self._classDisplayName
end

--- Define o nome localizado da classe.
---@param displayName string
function Member:setClassDisplayName(displayName)
    if type(displayName) == "string" then
        self._classDisplayName = displayName
    end
end

--- Obtém o cargo/rank na guilda.
---@return string
function Member:getRankName()
    return self._rankName
end

--- Define o cargo na guilda.
---@param rankName string
function Member:setRankName(rankName)
    if type(rankName) == "string" then
        self._rankName = rankName
    end
end

--- Obtém o índice numérico do rank.
---@return number
function Member:getRankIndex()
    return self._rankIndex
end

--- Define o índice numérico do rank.
---@param rankIndex number
function Member:setRankIndex(rankIndex)
    local n = tonumber(rankIndex)
    if n then
        self._rankIndex = n
    end
end

--- Obtém a zona onde o jogador se encontra.
---@return string
function Member:getZone()
    return self._zone
end

--- Define a zona atual do jogador.
---@param zone string
function Member:setZone(zone)
    if type(zone) == "string" then
        self._zone = zone
    end
end

--- Verifica se o jogador está conectado no momento.
---@return boolean
function Member:isOnline()
    return self._isOnline
end

--- Define se o jogador está conectado.
---@param isOnline boolean
function Member:setOnline(isOnline)
    self._isOnline = (isOnline == true)
end

--- Obtém a nota pública da guilda.
---@return string
function Member:getPublicNote()
    return self._publicNote
end

--- Define a nota pública da guilda.
---@param note string
function Member:setPublicNote(note)
    self._publicNote = tostring(note or "")
end

--- Obtém a nota de oficial da guilda.
---@return string
function Member:getOfficerNote()
    return self._officerNote
end

--- Define a nota de oficial da guilda.
---@param note string
function Member:setOfficerNote(note)
    self._officerNote = tostring(note or "")
end

--- Obtém a nota gerencial customizada do GuildManager.
---@return string
function Member:getCustomNote()
    return self._customNote
end

--- Define a nota gerencial customizada do GuildManager.
---@param note string
function Member:setCustomNote(note)
    self._customNote = tostring(note or "")
end

--- Obtém a lista de nomes dos alts vinculados.
---@return string[]
function Member:getAlts()
    return self._alts
end

--- Define a lista de alts vinculados.
---@param alts string[]
function Member:setAlts(alts)
    self._alts = {}
    if type(alts) == "table" then
        local seen = {}
        local myNameLower = (self._name or ""):lower()
        for _, name in ipairs(alts) do
            if type(name) == "string" and name ~= "" then
                local lower = name:lower()
                if lower ~= myNameLower and not seen[lower] then
                    seen[lower] = true
                    table.insert(self._alts, name)
                end
            end
        end
    end
end

--- Adiciona um personagem secundário (alt) à lista deste membro.
--- Evita duplicações e não permite adicionar o próprio membro como alt dele mesmo.
---@param altName string
---@return boolean @Retorna true se adicionado com sucesso
function Member:addAlt(altName)
    if type(altName) ~= "string" or altName == "" or altName == self._name then
        return false
    end

    -- Verifica se já está presente na lista
    for _, name in ipairs(self._alts) do
        if string.lower(name) == string.lower(altName) then
            return false
        end
    end

    -- Insere o alt na lista
    table.insert(self._alts, altName)
    return true
end

--- Remove um personagem secundário da lista deste membro.
---@param altName string
---@return boolean @Retorna true se removido com sucesso
function Member:removeAlt(altName)
    if type(altName) ~= "string" or altName == "" then
        return false
    end

    local lowerAlt = string.lower(altName)
    for i, name in ipairs(self._alts) do
        if string.lower(name) == lowerAlt then
            table.remove(self._alts, i)
            return true
        end
    end

    return false
end

--- Verifica se o personagem é o personagem principal (Main).
---@return boolean
function Member:isMain()
    return self._isMain
end

--- Define se o personagem é o principal (Main).
---@param isMain boolean
function Member:setMain(isMain)
    self._isMain = (isMain == true)
end

--- Verifica se o personagem ainda pertence à guilda.
---@return boolean
function Member:isInGuild()
    return self._isInGuild
end

--- Define o pertencimento do personagem à guilda.
---@param inGuild boolean
function Member:setInGuild(inGuild)
    self._isInGuild = (inGuild == true)
end

--- Obtém o nome formatado com o código hexadecimal de cor da sua classe para o chat do WoW.
---@return string @Ex: "|cffc79c6eGuerreiro|r"
function Member:getColoredName()
    if self._class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[self._class] then
        local color = RAID_CLASS_COLORS[self._class]
        if color.colorStr then
            return "|c" .. color.colorStr .. self._name .. "|r"
        end
        local r = math.floor((color.r or 1) * 255)
        local g = math.floor((color.g or 1) * 255)
        local b = math.floor((color.b or 1) * 255)
        return string.format("|cff%02x%02x%02x%s|r", r, g, b, self._name)
    end
    return self._name
end

--- Serializa a entidade Member em uma tabela Lua pura (pronta para persistência no SavedVariables).
---@return table @Tabela com chave-valor dos dados a serem gravados no GM_DB
function Member:serialize()
    return {
        -- Campos nativos da Blizzard
        name = self._name,
        race = self:getRace(),
        raceID = self._raceID,
        rankName = self._rankName,
        rankIndex = self._rankIndex,
        level = self._level,
        classDisplayName = self._classDisplayName,
        zone = self._zone,
        publicNote = self._publicNote,
        officerNote = self._officerNote,
        isOnline = self._isOnline,
        status = self._status,
        class = self._class,
        achievementPoints = self._achievementPoints,
        achievementRank = self._achievementRank,
        repStanding = self._repStanding,
        guid = self._guid,

        -- Campos customizados do Addon
        customNote = self._customNote,
        alts = self._alts,
        birthday = self._birthday,
        dateJoin = self._dateJoin,
        dateLeft = self._dateLeft,
        lastRank = self._lastRank,
        timesLeft = self._timesLeft,
        isMain = self._isMain,
        isInGuild = self._isInGuild,
        recruiter = self._recruiter,
    }
end

--- Atualiza os dados dinâmicos da API da Blizzard preservando os dados customizados já salvos.
---@param data table @Tabela com novos valores vindos do roster
function Member:updateFromRoster(data)
    if not data then return end

    if data.rankName then self._rankName = data.rankName end
    if data.rankIndex ~= nil then self._rankIndex = tonumber(data.rankIndex) or self._rankIndex end
    if data.level then self:setLevel(data.level) end
    if data.classDisplayName then self._classDisplayName = data.classDisplayName end
    if data.zone then self._zone = data.zone end
    if data.publicNote ~= nil then self._publicNote = tostring(data.publicNote) end
    if data.officerNote ~= nil then self._officerNote = tostring(data.officerNote) end
    if data.isOnline ~= nil then self._isOnline = (data.isOnline == true) end
    if data.status ~= nil then self._status = tonumber(data.status) or self._status end
    if data.class then self._class = data.class end
    if data.achievementPoints ~= nil then self._achievementPoints = tonumber(data.achievementPoints) or self._achievementPoints end
    if data.achievementRank ~= nil then self._achievementRank = tonumber(data.achievementRank) or self._achievementRank end
    if data.repStanding ~= nil then self._repStanding = tonumber(data.repStanding) or self._repStanding end
    if data.guid and data.guid ~= "" then self._guid = data.guid end
    if data.race ~= nil then self._race = tostring(data.race) end
    if data.raceName ~= nil then self._race = tostring(data.raceName) end
    if data.raceID ~= nil then self._raceID = data.raceID end

    -- Se o jogador estava marcado como fora da guilda e reapareceu no roster:
    if not self._isInGuild then
        self._isInGuild = true
        self._dateLeft = ""
    end
end

---@return string
function Member:getGuid()
    return self._guid
end

---@param guid string
function Member:setGuid(guid)
    if type(guid) == "string" then
        self._guid = guid
    end
end

--- Obtém a raça do membro.
---@return string
function Member:getRace()
    if self._race and self._race ~= "" then
        return self._race
    end
    if type(self._raceID) == "string" and self._raceID ~= "" then
        return self._raceID
    end
    return ""
end

--- Define a raça do membro.
---@param race string
function Member:setRace(race)
    self._race = tostring(race or "")
end

---@return string|number
function Member:getRaceID()
    return self._raceID
end

---@param raceID string|number
function Member:setRaceID(raceID)
    self._raceID = raceID
end

---@return number
function Member:getStatus()
    return self._status
end

---@param status number
function Member:setStatus(status)
    local n = tonumber(status)
    if n then
        self._status = n
    end
end

---@return number
function Member:getRepStanding()
    return self._repStanding
end

---@param repStanding number
function Member:setRepStanding(repStanding)
    local n = tonumber(repStanding)
    if n then
        self._repStanding = n
    end
end

---@return number
function Member:getAchievementPoints()
    return self._achievementPoints
end

---@param points number
function Member:setAchievementPoints(points)
    local n = tonumber(points)
    if n then
        self._achievementPoints = n
    end
end

---@return number
function Member:getAchievementRank()
    return self._achievementRank
end

---@param rank number
function Member:setAchievementRank(rank)
    local n = tonumber(rank)
    if n then
        self._achievementRank = n
    end
end

---@return string
function Member:getBirthday()
    return self._birthday
end

---@param birthday string
function Member:setBirthday(birthday)
    self._birthday = tostring(birthday or "")
end

---@return string
function Member:getDateJoin()
    return self._dateJoin
end

---@param dateJoin string
function Member:setDateJoin(dateJoin)
    self._dateJoin = tostring(dateJoin or "")
end

---@return string
function Member:getDateLeft()
    return self._dateLeft
end

---@param dateLeft string
function Member:setDateLeft(dateLeft)
    self._dateLeft = tostring(dateLeft or "")
end

---@return string
function Member:getLastRank()
    return self._lastRank
end

---@param lastRank string
function Member:setLastRank(lastRank)
    self._lastRank = tostring(lastRank or "")
end

---@return number
function Member:getTimesLeft()
    return self._timesLeft
end

---@param times number
function Member:setTimesLeft(times)
    local n = tonumber(times)
    if n then
        self._timesLeft = n
    end
end

---@return string
function Member:getRecruiter()
    return self._recruiter
end

---@param recruiter string
function Member:setRecruiter(recruiter)
    self._recruiter = tostring(recruiter or "")
end



