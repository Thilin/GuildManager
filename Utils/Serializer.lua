---@class Serializer
--- Utilitário para serialização e desserialização de dados (formato JSON seguro e compacto)
--- Compatível com Lua 5.1 / LuaJIT / World of Warcraft
local Serializer = {}

-- Caracteres de escape para JSON
local escapeMap = {
    ['"']  = '\\"',
    ['\\'] = '\\\\',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
}

local unescapeMap = {
    ['"']  = '"',
    ['\\'] = '\\',
    ['/']  = '/',
    ['b']  = '\b',
    ['f']  = '\f',
    ['n']  = '\n',
    ['r']  = '\r',
    ['t']  = '\t',
}

--- Codifica uma string escapando caracteres especiais para formato JSON
---@param str string
---@return string
local function escapeString(str)
    return '"' .. str:gsub('["\\%c]', function(c)
        return escapeMap[c] or string.format("\\u%04x", c:byte())
    end) .. '"'
end

--- Verifica se uma tabela é tratada como array sequencial (índices numéricos de 1 a N)
---@param tbl table
---@return boolean
local function isArray(tbl)
    local count = 0
    for k, _ in pairs(tbl) do
        count = count + 1
        if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
            return false
        end
    end
    for i = 1, count do
        if tbl[i] == nil then
            return false
        end
    end
    return true
end

--- Serializa um valor Lua qualquer para uma string formatada em JSON
---@param val any
---@return string
function Serializer.serialize(val)
    local vType = type(val)
    if vType == "nil" then
        return "null"
    elseif vType == "boolean" then
        return val and "true" or "false"
    elseif vType == "number" then
        if val ~= val then return "null" end -- NaN
        if val == math.huge or val == -math.huge then return "null" end
        return tostring(val)
    elseif vType == "string" then
        return escapeString(val)
    elseif vType == "table" then
        if isArray(val) then
            local items = {}
            for i = 1, #val do
                table.insert(items, Serializer.serialize(val[i]))
            end
            return "[" .. table.concat(items, ",") .. "]"
        else
            local fields = {}
            -- Ordena chaves alfabeticamente para determinismo
            local keys = {}
            for k in pairs(val) do
                table.insert(keys, tostring(k))
            end
            table.sort(keys)

            for _, k in ipairs(keys) do
                local v = val[k]
                if v ~= nil then
                    table.insert(fields, escapeString(k) .. ":" .. Serializer.serialize(v))
                end
            end
            return "{" .. table.concat(fields, ",") .. "}"
        end
    else
        return "null"
    end
end

--- Parser de JSON para tabelas nativas de Lua
---@param jsonStr string
---@return any, string|nil
function Serializer.deserialize(jsonStr)
    if type(jsonStr) ~= "string" or jsonStr == "" then
        return nil, "Entrada vazia ou inválida"
    end

    local pos = 1
    local len = #jsonStr

    local function skipWhitespace()
        while pos <= len do
            local c = jsonStr:byte(pos)
            if c == 32 or c == 9 or c == 10 or c == 13 then
                pos = pos + 1
            else
                break
            end
        end
    end

    local parseValue -- forward declaration

    local function parseString()
        if jsonStr:byte(pos) ~= 34 then -- '"'
            return nil, "Esperado '\"' na posição " .. pos
        end
        pos = pos + 1
        local startPos = pos
        local chunks = {}

        while pos <= len do
            local c = jsonStr:sub(pos, pos)
            if c == '"' then
                table.insert(chunks, jsonStr:sub(startPos, pos - 1))
                pos = pos + 1
                return table.concat(chunks)
            elseif c == '\\' then
                table.insert(chunks, jsonStr:sub(startPos, pos - 1))
                pos = pos + 1
                if pos > len then return nil, "Escape inacabado no final da string" end
                local esc = jsonStr:sub(pos, pos)
                if esc == 'u' then
                    local hex = jsonStr:sub(pos + 1, pos + 4)
                    if #hex < 4 or not hex:match("^%x%x%x%x$") then
                        return nil, "Sequência Unicode inválida"
                    end
                    local code = tonumber(hex, 16)
                    if code and code <= 255 then
                        table.insert(chunks, string.char(code))
                    else
                        table.insert(chunks, "?")
                    end
                    pos = pos + 5
                else
                    table.insert(chunks, unescapeMap[esc] or esc)
                    pos = pos + 1
                end
                startPos = pos
            else
                pos = pos + 1
            end
        end
        return nil, "String não terminada"
    end

    local function parseNumber()
        local startPos = pos
        if jsonStr:sub(pos, pos) == '-' then
            pos = pos + 1
        end
        while pos <= len and jsonStr:byte(pos) >= 48 and jsonStr:byte(pos) <= 57 do
            pos = pos + 1
        end
        if pos <= len and jsonStr:sub(pos, pos) == '.' then
            pos = pos + 1
            while pos <= len and jsonStr:byte(pos) >= 48 and jsonStr:byte(pos) <= 57 do
                pos = pos + 1
            end
        end
        if pos <= len and (jsonStr:sub(pos, pos) == 'e' or jsonStr:sub(pos, pos) == 'E') then
            pos = pos + 1
            if pos <= len and (jsonStr:sub(pos, pos) == '+' or jsonStr:sub(pos, pos) == '-') then
                pos = pos + 1
            end
            while pos <= len and jsonStr:byte(pos) >= 48 and jsonStr:byte(pos) <= 57 do
                pos = pos + 1
            end
        end
        local numStr = jsonStr:sub(startPos, pos - 1)
        local num = tonumber(numStr)
        if num == nil then
            return nil, "Número inválido: " .. numStr
        end
        return num
    end

    local function parseArray()
        pos = pos + 1 -- pula '['
        local arr = {}
        skipWhitespace()
        if pos <= len and jsonStr:sub(pos, pos) == ']' then
            pos = pos + 1
            return arr
        end

        while pos <= len do
            skipWhitespace()
            local val, err = parseValue()
            if err then return nil, err end
            table.insert(arr, val)

            skipWhitespace()
            local c = jsonStr:sub(pos, pos)
            if c == ']' then
                pos = pos + 1
                return arr
            elseif c == ',' then
                pos = pos + 1
            else
                return nil, "Esperado ',' ou ']' na posição " .. pos
            end
        end
        return nil, "Array não terminado"
    end

    local function parseObject()
        pos = pos + 1 -- pula '{'
        local obj = {}
        skipWhitespace()
        if pos <= len and jsonStr:sub(pos, pos) == '}' then
            pos = pos + 1
            return obj
        end

        while pos <= len do
            skipWhitespace()
            if jsonStr:sub(pos, pos) ~= '"' then
                return nil, "Esperado chave em string na posição " .. pos
            end
            local key, err = parseString()
            if err then return nil, err end

            skipWhitespace()
            if jsonStr:sub(pos, pos) ~= ':' then
                return nil, "Esperado ':' após chave na posição " .. pos
            end
            pos = pos + 1 -- pula ':'

            skipWhitespace()
            local val, errVal = parseValue()
            if errVal then return nil, errVal end
            obj[key] = val

            skipWhitespace()
            local c = jsonStr:sub(pos, pos)
            if c == '}' then
                pos = pos + 1
                return obj
            elseif c == ',' then
                pos = pos + 1
            else
                return nil, "Esperado ',' ou '}' na posição " .. pos
            end
        end
        return nil, "Objeto não terminado"
    end

    parseValue = function()
        skipWhitespace()
        if pos > len then
            return nil, "Fim inesperado de entrada"
        end

        local c = jsonStr:sub(pos, pos)
        if c == '"' then
            return parseString()
        elseif c == '{' then
            return parseObject()
        elseif c == '[' then
            return parseArray()
        elseif c == '-' or (jsonStr:byte(pos) >= 48 and jsonStr:byte(pos) <= 57) then
            return parseNumber()
        elseif jsonStr:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        elseif jsonStr:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        elseif jsonStr:sub(pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        else
            return nil, "Caractere inesperado '" .. c .. "' na posição " .. pos
        end
    end

    local result, err = parseValue()
    if err then
        return nil, err
    end
    return result
end

_G.Serializer = Serializer
return Serializer
