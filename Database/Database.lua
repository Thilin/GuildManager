---@class Database
---@field _version string @Versao corrente do esquema do Banco de dados para controle de migrações
Database = {}
Database.__index = Database

local DEFAULT_DB_VERSION = "1.2"

---@param version string|nil @Versão opcional para o esquema do banco de dados
---@return Database @Retorna uma nova instancia da classe Database
function Database:new(version)

    local instance = setmetatable({}, self)

    instance._version = version or DEFAULT_DB_VERSION

    return instance
end

---@return string @Versão do esquema do banco
function Database:getVersion()
    return self._version
end

---@return table @Retorna a referencia direta à tabela raiz GM_DB
function Database:init()

    if type(_G.GM_DB) ~= "table" then
        _G.GM_DB = {}
    end

    if type(_G.GM_DB.guilds) ~= "table" then
        _G.GM_DB.guilds = {}
    end

    if type(_G.GM_DB.settings) ~= "table" then
        _G.GM_DB.settings = {}
    end

    -- Compatibilidade com esquema raiz legado
    if type(_G.GM_DB.members) ~= "table" then
        _G.GM_DB.members = {}
    end

    if type(_G.GM_DB.logs) ~= "table" then
        _G.GM_DB.logs = {}
    end

    if type(_G.GM_DB.groups) ~= "table" then
        _G.GM_DB.groups = {}
    end

    if type(_G.GM_DB.lfgCards) ~= "table" then
        _G.GM_DB.lfgCards = {}
    end

    if type(_G.GM_DB.events) ~= "table" then
        _G.GM_DB.events = {}
    end

    if type(_G.GM_DB.craftOrders) ~= "table" then
        _G.GM_DB.craftOrders = {}
    end

    if type(_G.GM_DB.professions) ~= "table" then
        _G.GM_DB.professions = {}
    end

    _G.GM_DB.version = self._version

    -- Tenta inicializar com a guilda atual do jogador se já estiver disponível
    local guildKey = self:getGuildKey()
    if guildKey then
        return self:switchGuild(nil)
    end

    -- Se a guilda ainda não é conhecida no ADDON_LOADED, inicializa com banco isolado
    -- para impedir vazamento de membros legados globais antes da confirmação da guilda
    self._activeDb = {
        members = {},
        logs = {},
        groups = {},
        lfgCards = {},
        events = {},
        craftOrders = {},
        professions = {},
        rosterInitialized = false,
    }
    return self._activeDb
end

--- Normaliza e valida uma data no formato AAAA-MM-DD (retorna "" se inválida).
---@param d string|nil
---@return string
local function normalizeIsoDate(d)
    if type(d) ~= "string" then return "" end
    local y, m, day = d:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
    if y and m and day then
        return y .. "-" .. m .. "-" .. day
    end
    return ""
end

--- Retorna o maior timestamp presente nos logs de uma tabela de guilda (para identificar qual partição é mais recente).
---@param db table|nil
---@return number
local function getMaxActivityTimestamp(db)
    if type(db) ~= "table" then return 0 end
    local maxTs = 0
    if type(db.logs) == "table" then
        for _, lg in ipairs(db.logs) do
            local ts = tonumber(lg and lg.timestamp) or 0
            if ts > maxTs then maxTs = ts end
        end
    end
    if type(db.members) == "table" then
        for _, m in pairs(db.members) do
            local ts = tonumber(m and m.customDataTimestamp) or 0
            if ts > maxTs then maxTs = ts end
        end
    end
    return maxTs
end

--- Extrai a parte de reino e nome da guilda de uma chave de GM_DB.guilds se ela corresponder ao nome de guilda fornecido.
---@param key string
---@param targetGuildName string
---@return boolean matched, string realmPart
local function matchGuildKey(key, targetGuildName)
    if type(key) ~= "string" or type(targetGuildName) ~= "string" or targetGuildName == "" then
        return false, ""
    end
    local kLower = key:lower()
    local gLower = targetGuildName:lower()
    if kLower == gLower then
        return true, ""
    end
    local suffix = " - " .. gLower
    if #kLower > #suffix and kLower:sub(-#suffix) == suffix then
        local realmPart = key:sub(1, #key - #suffix)
        return true, realmPart
    end
    return false, ""
end

--- Retorna a lista de chaves existentes em GM_DB.guilds que representam a mesma guilda (incluindo splits sem nome do reino).
---@param gName string
---@param rName string
---@return table[] @Lista de { key = string, realm = string }
function Database:_findMatchingGuildKeys(gName, rName)
    local matches = {}
    if not _G.GM_DB or type(_G.GM_DB.guilds) ~= "table" or not gName or gName == "" then
        return matches
    end

    local rLower = (rName or ""):lower()
    for existingKey, existingVal in pairs(_G.GM_DB.guilds) do
        if type(existingVal) == "table" then
            local matched, realmPart = matchGuildKey(existingKey, gName)
            if matched then
                -- Se o reino atual é conhecido, só combina chaves do mesmo reino ou chaves sem reino (criadas quando GetRealmName() falhou).
                -- Se o reino atual está vazio, combina todas as partições desta guilda para evitar criar novo banco vazio.
                if rLower == "" or realmPart == "" or realmPart:lower() == rLower then
                    table.insert(matches, { key = existingKey, realm = realmPart })
                end
            end
        end
    end

    return matches
end

--- Escolhe a chave canônica entre uma lista de chaves correspondentes da mesma guilda.
---@param matches table[]
---@param gName string
---@param rName string
---@return string
function Database:_pickCanonicalKey(matches, gName, rName)
    local preferredKey = (rName ~= "") and (rName .. " - " .. gName) or gName
    if not matches or #matches == 0 then
        return preferredKey
    end

    local prefLower = preferredKey:lower()
    -- 1. Se o reino atual é conhecido e já existe a chave exata "Reino - Guilda", usa ela
    if rName ~= "" then
        for _, item in ipairs(matches) do
            if item.key:lower() == prefLower then
                return item.key
            end
        end
    end

    -- 2. Prefere chave que possua prefixo de reino (mais estável e preserva o padrão original)
    local bestWithRealm = nil
    local bestCount = -1
    for _, item in ipairs(matches) do
        if item.realm ~= "" then
            local db = _G.GM_DB.guilds[item.key]
            local count = 0
            if db and type(db.members) == "table" then
                for _ in pairs(db.members) do count = count + 1 end
            end
            if not bestWithRealm or count > bestCount then
                bestWithRealm = item.key
                bestCount = count
            end
        end
    end
    if bestWithRealm then
        return bestWithRealm
    end

    return matches[1].key
end

--- Mescla de forma segura e sem perda de dados uma partição dividida (sourceDb) na partição canônica (targetDb).
--- Preserva as datas de entrada reais mais antigas, une vínculos de alts, recupera notas internas,
--- grupos, eventos, profissões e logs históricos sem perder membros ou atualizações recentes.
---@param targetDb table
---@param sourceDb table
---@return table @{ recoveredDates = number, recoveredAlts = number, recoveredNotes = number, mergedMembers = number, mergedLogs = number }
function Database:_mergeGuildTables(targetDb, sourceDb)
    local stats = { recoveredDates = 0, recoveredAlts = 0, recoveredNotes = 0, mergedMembers = 0, mergedLogs = 0 }
    if type(targetDb) ~= "table" or type(sourceDb) ~= "table" or targetDb == sourceDb then
        return stats
    end

    if type(targetDb.members) ~= "table" then targetDb.members = {} end
    if type(targetDb.logs) ~= "table" then targetDb.logs = {} end
    if type(targetDb.groups) ~= "table" then targetDb.groups = {} end
    if type(targetDb.lfgCards) ~= "table" then targetDb.lfgCards = {} end
    if type(targetDb.events) ~= "table" then targetDb.events = {} end
    if type(targetDb.craftOrders) ~= "table" then targetDb.craftOrders = {} end
    if type(targetDb.professions) ~= "table" then targetDb.professions = {} end

    local targetMaxTs = getMaxActivityTimestamp(targetDb)
    local sourceMaxTs = getMaxActivityTimestamp(sourceDb)
    local sourceIsNewer = (sourceMaxTs > targetMaxTs)
    local olderDb = sourceIsNewer and targetDb or sourceDb
    local newerDb = sourceIsNewer and sourceDb or targetDb

    local nowTs = (GetServerTime and GetServerTime()) or (time and time()) or (os and os.time and os.time()) or 0

    -- Snapshot dos membros antigos (para filtrar falsos JOINED gerados na criação da partição vazia)
    local olderMemberSnap = {}
    if type(olderDb.members) == "table" then
        for mName, mData in pairs(olderDb.members) do
            if type(mData) == "table" then
                olderMemberSnap[mName:lower()] = {
                    isInGuild = (mData.isInGuild ~= false),
                    dateJoin = normalizeIsoDate(mData.dateJoin),
                }
            end
        end
    end

    -- 1. Merge de Membros (une todos os membros das duas partições)
    local allMemberNames = {}
    local seenMemberKeys = {}
    for mName in pairs(olderDb.members or {}) do
        local keyLower = mName:lower()
        if not seenMemberKeys[keyLower] then
            seenMemberKeys[keyLower] = mName
            table.insert(allMemberNames, mName)
        end
    end
    for mName in pairs(newerDb.members or {}) do
        local keyLower = mName:lower()
        if not seenMemberKeys[keyLower] then
            seenMemberKeys[keyLower] = mName
            table.insert(allMemberNames, mName)
        end
    end

    local mergedMembers = {}
    for _, canonicalName in ipairs(allMemberNames) do
        local mOld = olderDb.members and olderDb.members[canonicalName]
        local mNew = newerDb.members and newerDb.members[canonicalName]

        -- Busca fallback case-insensitive caso capitalização difira entre partições
        if not mOld and olderDb.members then
            local cLower = canonicalName:lower()
            for k, v in pairs(olderDb.members) do
                if k:lower() == cLower then mOld = v break end
            end
        end
        if not mNew and newerDb.members then
            local cLower = canonicalName:lower()
            for k, v in pairs(newerDb.members) do
                if k:lower() == cLower then mNew = v break end
            end
        end

        if mOld and mNew then
            -- Base: dados ao vivo da partição mais recente
            local merged = {}
            for k, v in pairs(mOld) do merged[k] = v end
            for k, v in pairs(mNew) do merged[k] = v end

            -- Campos auxiliares: fallback se vazio no novo
            if (not merged.guid or merged.guid == "") and mOld.guid and mOld.guid ~= "" then merged.guid = mOld.guid end
            if (not merged.race or merged.race == "") and mOld.race and mOld.race ~= "" then merged.race = mOld.race end
            if (not merged.class or merged.class == "") and mOld.class and mOld.class ~= "" then merged.class = mOld.class end
            if (not merged.dateLeft or merged.dateLeft == "") and mOld.dateLeft and mOld.dateLeft ~= "" then merged.dateLeft = mOld.dateLeft end
            if (not merged.lastRank or merged.lastRank == "") and mOld.lastRank and mOld.lastRank ~= "" then merged.lastRank = mOld.lastRank end
            merged.timesLeft = math.max(tonumber(mOld.timesLeft) or 0, tonumber(mNew.timesLeft) or 0)

            -- Preserva campos customizados não-vazios
            if (not merged.birthday or merged.birthday == "") and mOld.birthday and mOld.birthday ~= "" then
                merged.birthday = mOld.birthday
            end
            if (not merged.recruiter or merged.recruiter == "") and mOld.recruiter and mOld.recruiter ~= "" then
                merged.recruiter = mOld.recruiter
            end
            if (not merged.role or merged.role == "") and mOld.role and mOld.role ~= "" then
                merged.role = mOld.role
            end
            if (not merged.customNote or merged.customNote == "") and mOld.customNote and mOld.customNote ~= "" then
                merged.customNote = mOld.customNote
                stats.recoveredNotes = stats.recoveredNotes + 1
            end

            -- Data de entrada (dateJoin): preserva sempre a data real mais antiga
            local dOld = normalizeIsoDate(mOld.dateJoin)
            local dNew = normalizeIsoDate(mNew.dateJoin)
            local recoveredCustom = false

            if dOld ~= "" and (dNew == "" or dOld < dNew) then
                merged.dateJoin = dOld
                stats.recoveredDates = stats.recoveredDates + 1
                recoveredCustom = true
            elseif dNew ~= "" then
                merged.dateJoin = dNew
            elseif dOld ~= "" then
                merged.dateJoin = dOld
            end

            -- Vínculos de Alts: faz a união dos alts de ambas as partições (deduplicado)
            local oldAlts = (type(mOld.alts) == "table") and mOld.alts or {}
            local newAlts = (type(mNew.alts) == "table") and mNew.alts or {}
            local altSet = {}
            local combinedAlts = {}
            local selfLower = canonicalName:lower()

            for _, aName in ipairs(oldAlts) do
                if type(aName) == "string" and aName ~= "" then
                    local aLower = aName:lower()
                    if aLower ~= selfLower and not altSet[aLower] then
                        altSet[aLower] = true
                        table.insert(combinedAlts, aName)
                    end
                end
            end
            for _, aName in ipairs(newAlts) do
                if type(aName) == "string" and aName ~= "" then
                    local aLower = aName:lower()
                    if aLower ~= selfLower and not altSet[aLower] then
                        altSet[aLower] = true
                        table.insert(combinedAlts, aName)
                    end
                end
            end

            merged.alts = combinedAlts
            if #oldAlts > 0 and #combinedAlts > #newAlts then
                stats.recoveredAlts = stats.recoveredAlts + 1
                recoveredCustom = true
            end

            -- Preserva isMain original quando a partição antiga já tinha a família de alts definida
            if #oldAlts > 0 and #newAlts == 0 then
                merged.isMain = (mOld.isMain == true)
            end

            -- Merge de profissões (preserva todas as profissões conhecidas de ambas as partições)
            local mergedProfs = {}
            if type(mOld.professions) == "table" then
                for pKey, pVal in pairs(mOld.professions) do
                    mergedProfs[pKey] = pVal
                end
            end
            if type(mNew.professions) == "table" then
                for pKey, pVal in pairs(mNew.professions) do
                    mergedProfs[pKey] = pVal
                end
            end
            merged.professions = mergedProfs
            merged.professionsTimestamp = math.max(tonumber(mOld.professionsTimestamp) or 0, tonumber(mNew.professionsTimestamp) or 0)

            -- Atualiza customDataTimestamp se recuperamos data de entrada ou alts, para propagar via SyncService
            local maxCustomTs = math.max(tonumber(mOld.customDataTimestamp) or 0, tonumber(mNew.customDataTimestamp) or 0)
            if recoveredCustom then
                merged.customDataTimestamp = math.max(nowTs, maxCustomTs) + 1
            else
                merged.customDataTimestamp = maxCustomTs
            end

            mergedMembers[canonicalName] = merged
        else
            local single = mNew or mOld
            mergedMembers[canonicalName] = single
        end
        stats.mergedMembers = stats.mergedMembers + 1
    end
    targetDb.members = mergedMembers

    -- 2. Merge de coleções indexadas por ID (groups, lfgCards, events, craftOrders, professions)
    local function mergeKeyedCollection(fieldName)
        local result = {}
        if type(olderDb[fieldName]) == "table" then
            for id, item in pairs(olderDb[fieldName]) do
                result[id] = item
            end
        end
        if type(newerDb[fieldName]) == "table" then
            for id, item in pairs(newerDb[fieldName]) do
                local existing = result[id]
                if not existing then
                    result[id] = item
                elseif type(item) == "table" and type(existing) == "table" then
                    local newUpd = tonumber(item.updatedAt or item.createdAt) or 0
                    local oldUpd = tonumber(existing.updatedAt or existing.createdAt) or 0
                    if newUpd >= oldUpd then
                        result[id] = item
                    end
                else
                    result[id] = item
                end
            end
        end
        targetDb[fieldName] = result
    end

    mergeKeyedCollection("groups")
    mergeKeyedCollection("lfgCards")
    mergeKeyedCollection("events")
    mergeKeyedCollection("craftOrders")
    mergeKeyedCollection("professions")

    -- 3. Merge de logs históricos + novos, removendo duplicatas e falsos JOINED gerados pelo split
    local mergedLogs = {}
    local seenLogs = {}

    local function addLogEntry(lg, isFromNewer)
        if type(lg) ~= "table" then return end
        local ts = tonumber(lg.timestamp) or 0
        local ev = tostring(lg.event or "")
        local nm = tostring(lg.name or "")
        local msg = tostring(lg.message or "")

        -- Ignora falsos logs de JOINED gerados na partição nova para membros que já existiam antes do split
        if isFromNewer and ev == "JOINED" and nm ~= "" then
            local snap = olderMemberSnap[nm:lower()]
            local logDate = normalizeIsoDate(lg.date)
            if snap and snap.isInGuild and snap.dateJoin ~= "" and logDate ~= "" and snap.dateJoin < logDate then
                return
            end
        end

        local sig = string.format("%d|%s|%s|%s", ts, ev, nm:lower(), msg)
        if not seenLogs[sig] then
            seenLogs[sig] = true
            table.insert(mergedLogs, lg)
        end
    end

    for _, lg in ipairs(olderDb.logs or {}) do
        addLogEntry(lg, false)
    end
    for _, lg in ipairs(newerDb.logs or {}) do
        addLogEntry(lg, true)
    end

    table.sort(mergedLogs, function(a, b)
        local tsA = tonumber(a and a.timestamp) or 0
        local tsB = tonumber(b and b.timestamp) or 0
        if tsA ~= tsB then return tsA < tsB end
        return (tonumber(a and a.id) or 0) < (tonumber(b and b.id) or 0)
    end)

    for idx, lg in ipairs(mergedLogs) do
        lg.id = idx
    end
    targetDb.logs = mergedLogs
    stats.mergedLogs = #mergedLogs

    -- 4. Preserva configurações mais recentes e flags de inicialização
    if type(newerDb.settings) == "table" then
        targetDb.settings = newerDb.settings
    elseif type(olderDb.settings) == "table" and type(targetDb.settings) ~= "table" then
        targetDb.settings = olderDb.settings
    end
    targetDb.rosterInitialized = (olderDb.rosterInitialized == true) or (newerDb.rosterInitialized == true) or (stats.mergedMembers > 0)

    return stats
end

--- Consolida eventuais chaves divididas da mesma guilda (ex: "Reino - Guilda" e "Guilda" sem reino)
--- retornando sempre a chave canônica unificada.
---@param gName string
---@param rName string
---@return string
function Database:consolidateSplitGuildKeys(gName, rName)
    local matches = self:_findMatchingGuildKeys(gName, rName)
    local canonicalKey = self:_pickCanonicalKey(matches, gName, rName)

    if #matches > 1 and _G.GM_DB and type(_G.GM_DB.guilds) == "table" then
        local targetDb = self:getGuildData(canonicalKey)
        local totalDates, totalAlts, totalNotes = 0, 0, 0

        for _, item in ipairs(matches) do
            if item.key ~= canonicalKey and type(_G.GM_DB.guilds[item.key]) == "table" then
                local st = self:_mergeGuildTables(targetDb, _G.GM_DB.guilds[item.key])
                totalDates = totalDates + (st.recoveredDates or 0)
                totalAlts = totalAlts + (st.recoveredAlts or 0)
                totalNotes = totalNotes + (st.recoveredNotes or 0)
                _G.GM_DB.guilds[item.key] = nil
            end
        end

        if (totalDates > 0 or totalAlts > 0 or totalNotes > 0) and print then
            print(string.format(
                "|cff00ff00[GuildManager]|r Banco da guilda unificado automaticamente! Recuperados: |cffffff00%d|r datas de entrada, |cffffff00%d|r vínculos de alts e |cffffff00%d|r notas internas.",
                totalDates, totalAlts, totalNotes
            ))
        end
    end

    return canonicalKey
end

--- Retorna a chave única da guilda no formato "Realm - NomeDaGuilda", resolvendo automaticamente
--- chaves existentes caso GetRealmName() retorne vazio ou oscile.
---@param guildName string|nil
---@param realmName string|nil
---@return string|nil
function Database:getGuildKey(guildName, realmName)
    local gName = guildName
    if not gName or gName == "" then
        if GetGuildInfo then
            local ok, info = pcall(GetGuildInfo, "player")
            if ok and info and info ~= "" then
                gName = info
            end
        end
    end

    if not gName or gName == "" then
        return nil
    end

    local rName = realmName or (GetRealmName and GetRealmName()) or ""
    if type(rName) == "string" then
        rName = rName:match("^%s*(.-)%s*$") or ""
    else
        rName = ""
    end

    local matches = self:_findMatchingGuildKeys(gName, rName)
    if #matches > 0 then
        return self:_pickCanonicalKey(matches, gName, rName)
    end

    if rName ~= "" then
        return rName .. " - " .. gName
    end
    return gName
end

--- Retorna a tabela isolada de dados persistentes da guilda especificada
---@param guildKey string
---@return table|nil
function Database:getGuildData(guildKey)
    if not guildKey or guildKey == "" then return nil end
    if type(_G.GM_DB.guilds) ~= "table" then
        _G.GM_DB.guilds = {}
    end

    if type(_G.GM_DB.guilds[guildKey]) ~= "table" then
        _G.GM_DB.guilds[guildKey] = {
            members = {},
            logs = {},
            groups = {},
            lfgCards = {},
            events = {},
            craftOrders = {},
            professions = {},
            rosterInitialized = false,
        }
    else
        local g = _G.GM_DB.guilds[guildKey]
        if type(g.members) ~= "table" then g.members = {} end
        if type(g.logs) ~= "table" then g.logs = {} end
        if type(g.groups) ~= "table" then g.groups = {} end
        if type(g.lfgCards) ~= "table" then g.lfgCards = {} end
        if type(g.events) ~= "table" then g.events = {} end
        if type(g.craftOrders) ~= "table" then g.craftOrders = {} end
        if type(g.professions) ~= "table" then g.professions = {} end
    end

    return _G.GM_DB.guilds[guildKey]
end

--- Alterna a guilda ativa, retornando o banco de dados correspondente
---@param guildName string|nil
---@param realmName string|nil
---@return table|nil @Tabela da guilda ou nil se sem guilda
---@return string|nil @Chave da guilda
function Database:switchGuild(guildName, realmName)
    local gName = guildName
    if not gName or gName == "" then
        if GetGuildInfo then
            local ok, info = pcall(GetGuildInfo, "player")
            if ok and info and info ~= "" then
                gName = info
            end
        end
    end

    if not gName or gName == "" then
        self._currentGuildKey = nil
        self._activeDb = nil
        return nil, nil
    end

    local rName = realmName or (GetRealmName and GetRealmName()) or ""
    if type(rName) == "string" then
        rName = rName:match("^%s*(.-)%s*$") or ""
    else
        rName = ""
    end

    local key = self:consolidateSplitGuildKeys(gName, rName)
    self._currentGuildKey = key
    if key then
        local guildDb = self:getGuildData(key)
        self._activeDb = guildDb
        return guildDb, key
    else
        self._activeDb = nil
        return nil, nil
    end
end

--- Retorna o banco ativo (ou a raiz se nenhuma guilda estiver vinculada ainda)
---@return table
function Database:getActiveDatabase()
    return self._activeDb or {
        members = {},
        logs = {},
        groups = {},
        lfgCards = {},
        events = {},
        craftOrders = {},
        professions = {},
        rosterInitialized = false,
    }
end

--- Retorna a chave da guilda atualmente ativa
---@return string|nil
function Database:getCurrentGuildKey()
    return self._currentGuildKey
end

--- Migra dados customizados (notas internas, aniversários, recrutadores, alts) do banco legado para o banco particionado da guilda
--- Apenas membros confirmados no roster da guilda ativa são migrados.
---@param guildDb table
---@param activeMemberNames table<string, boolean>
function Database:migrateLegacyCustomData(guildDb, activeMemberNames)
    if not guildDb or type(guildDb.members) ~= "table" then return end
    if not _G.GM_DB or type(_G.GM_DB.members) ~= "table" then return end
    if not activeMemberNames then return end

    for name, rawMember in pairs(_G.GM_DB.members) do
        local lower = name:lower():match("^%s*(.-)%s*$")
        if lower and activeMemberNames[lower] then
            local target = guildDb.members[name]
            if target then
                if (not target.birthday or target.birthday == "") and rawMember.birthday and rawMember.birthday ~= "" then
                    target.birthday = rawMember.birthday
                end
                if (not target.customNote or target.customNote == "") and rawMember.customNote and rawMember.customNote ~= "" then
                    target.customNote = rawMember.customNote
                end
                if (not target.recruiter or target.recruiter == "") and rawMember.recruiter and rawMember.recruiter ~= "" then
                    target.recruiter = rawMember.recruiter
                end
                if (not target.alts or #target.alts == 0) and rawMember.alts and #rawMember.alts > 0 then
                    target.alts = rawMember.alts
                end
            end
        end
    end
end

---@return void
function Database:wipe()
    if _G.GM_DB then
        table.wipe(_G.GM_DB)
        self:init()
    end
end