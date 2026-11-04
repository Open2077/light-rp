-- JSON text for a state key too large for one page message (ui.lua sends it in parts
-- the page reassembles).
--
-- The pure-Lua encoder alone did not fit the client's script budget (2 ms per resume,
-- ClientResourceHost frameBudget): on prod 2026-11-04, with the new editor contracts
-- riding in `activities`, it failed with "script execution budget exceeded"
-- (mission_editor.lua:137) and the panel stayed on "Waiting for the activities board"
-- for the players whose frame was busy. So every subtree the host's native encoder
-- accepts (up to its 1024-value event limit) is encoded in C++; Lua only walks the
-- spine above those subtrees, a few dozen tables for the activities board.
LightRpStateJson = {}
local J = LightRpStateJson

local ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
local function encodeString(s)
    return '"' .. s:gsub('[%c"\\]', function(c) return ESCAPES[c] or string.format("\\u%04x", c:byte()) end) .. '"'
end

local function native()
    local codec = (type(Open77) == "table" and type(Open77.json) == "table" and Open77.json)
        or (type(json) == "table" and json) or nil
    return type(codec) == "table" and type(codec.encode) == "function" and codec.encode or nil
end

-- Lists are tables with keys 1..n only; an empty table is {} (the page normalizes
-- lists); NaN and infinities become null; functions and userdata become null.
local function encode(value, depth, out, nativeEncode)
    local t = type(value)
    if t == "nil" then out[#out + 1] = "null"
    elseif t == "boolean" then out[#out + 1] = value and "true" or "false"
    elseif t == "number" then
        if value ~= value or value == math.huge or value == -math.huge then out[#out + 1] = "null"
        elseif math.type(value) == "integer" then out[#out + 1] = tostring(value)
        else out[#out + 1] = string.format("%.14g", value) end
    elseif t == "string" then out[#out + 1] = encodeString(value)
    elseif t == "table" then
        if nativeEncode and next(value) ~= nil then
            local ok, text = pcall(nativeEncode, value)
            if ok and type(text) == "string" then out[#out + 1] = text; return out end
        end
        if depth > 32 then error("too deep") end
        local n, count = #value, 0
        for _ in pairs(value) do count = count + 1 end
        if n > 0 and n == count then
            out[#out + 1] = "["
            for i = 1, n do
                if i > 1 then out[#out + 1] = "," end
                encode(value[i], depth + 1, out, nativeEncode)
            end
            out[#out + 1] = "]"
        else
            out[#out + 1] = "{"
            local first = true
            for k, v in pairs(value) do
                if type(k) == "string" or type(k) == "number" then
                    if not first then out[#out + 1] = "," end
                    first = false
                    out[#out + 1] = encodeString(tostring(k))
                    out[#out + 1] = ":"
                    encode(v, depth + 1, out, nativeEncode)
                end
            end
            out[#out + 1] = "}"
        end
    else out[#out + 1] = "null" end
    return out
end

-- `useNative` false = plain Lua only (tests compare the two).
function J.encode(value, useNative)
    return table.concat(encode(value, 0, {}, useNative ~= false and native() or nil))
end

return J
