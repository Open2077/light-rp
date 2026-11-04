-- client/core/state_json.lua: the text of an oversized state key. Native-first: every
-- subtree the host's encoder accepts (up to its value limit) goes through it, Lua only
-- walks the spine above; the result is the same JSON the plain Lua encoder writes.
-- No game.
local function check(cond, msg) if not cond then error(msg, 2) end end

-- A stand-in for the host's json.encode: plain Lua, refusing a value of more than LIMIT
-- nodes (a key and a value count one each, like ResourceHost ReadValue), counting calls.
local LIMIT, calls, refused = 60, 0, 0
local function nodes(v, n)
    n = n + 1
    if n > LIMIT then return n end
    if type(v) == "table" then
        for k, item in pairs(v) do
            n = nodes(k, n); if n > LIMIT then return n end
            n = nodes(item, n); if n > LIMIT then return n end
        end
    end
    return n
end
dofile("client/core/state_json.lua")
local J = LightRpStateJson
local plain = function(v) return J.encode(v, false) end
Open77 = { json = { encode = function(v)
    calls = calls + 1
    if nodes(v, 0) > LIMIT then refused = refused + 1; return nil, "value_not_json_serializable" end
    return plain(v)
end } }

-- the activities board's shape: a long list of entries, each small, plus contracts
local function board(entries, contracts)
    local list = {}
    for i = 1, entries do
        list[i] = { id = "act" .. i, label = "Activity \"" .. i .. "\"\n", players = i, joinable = i % 2 == 0,
            modes = { { key = "solo" }, { key = "duo" } }, top = { { name = "A", score = 1.5 } }, detail = false }
    end
    local c = {}
    for i = 1, contracts do c[i] = { id = "c" .. i, title = "Contract " .. i, distance = i * 10 } end
    return { enabled = true, hub = { name = "The Crossing" }, list = list, contracts = c, current = false,
        reputation = { today = 3, cap = 6 }, nearby = {} }
end

local value = board(40, 30)
local text = J.encode(value)
check(text == plain(value), "the same JSON as the plain Lua encoder")
check(calls > 0 and refused > 0, "the native encoder was tried and refused the big tables")
local accepted = calls - refused
check(accepted >= 40, "each activity entry went through the native encoder (" .. accepted .. ")")
check(text:find([["label":"Activity \"1\"\n"]], 1, true), "strings escaped")

-- a value the native encoder takes whole: one call, nothing walked in Lua
calls, refused = 0, 0
local small = { a = 1, b = { 1, 2, 3 } }
check(J.encode(small) == plain(small) and calls == 1 and refused == 0, "a small value is one native call")

-- no host encoder: plain Lua, same text
Open77 = nil
calls = 0
check(J.encode(value) == plain(value) and calls == 0, "without a host encoder it is plain Lua")

-- a host encoder that throws: caught, plain Lua for that subtree
Open77 = { json = { encode = function() error("boom") end } }
check(J.encode(value) == plain(value), "a throwing host encoder falls back to Lua")

-- the edge cases the page relies on
Open77 = nil
check(J.encode({}) == "{}", "an empty table is {}")
check(J.encode({ 1, 2 }) == "[1,2]", "a list")
check(J.encode({ x = 0 / 0 }) == '{"x":null}', "NaN is null")
check(J.encode({ n = 1.25 }) == '{"n":1.25}', "a float")

io.write("state_json_test: ok\n")
