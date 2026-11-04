-- Staff money grants (owner decision 2026-11-04, docs/economy-balance.md §16): a reason is
-- required and becomes the ledger note, one grant is capped at staffGrants.maxGrant unless
-- the grantor holds staffGrants.unlimitedPermission, and the server console is not capped.
-- The real inventory + economy modules, /lightrp.givemoney and the staff desk's Credit
-- (admin.lua), over a transactional SQL model. Never touches live data.
local noop = function() end
local function clone(v) if type(v) ~= "table" then return v end local t = {}; for k, x in pairs(v) do t[k] = clone(x) end return t end
dofile("shared/config.lua"); dofile("shared/items.lua"); dofile("shared/events.lua")
local encoded, serial = {}, 0
json = { encode = function(v) serial = serial + 1; local k = tostring(serial); encoded[k] = clone(v); return k end,
    decode = function(k) if k == "{}" then return {} end assert(encoded[k], "invalid JSON"); return clone(encoded[k]) end }
local state = { wallets = {}, inventories = {}, migrations = {}, ledger = {}, audit = {} }
local chars = {
    [1] = { identifier = "staff-1", key = "default", status = "active" },  -- staff, no unlimited permission
    [2] = { identifier = "player-2", key = "default", status = "active" }, -- the citizen
    [3] = { identifier = "owner-3", key = "default", status = "active" },  -- holds lightrp.money.unlimited
}
local perms = { [3] = { ["lightrp.money.unlimited"] = true } }
local db = { ready = true, schema = noop, query = function() return {} end }
function db.read(sql, p)
    if sql:find("lightrp_staff_audit", 1, true) then return true, {} end
    if sql:find("lightrp_inventories", 1, true) then return true, state.inventories[p[1]] and { clone(state.inventories[p[1]]) } or {} end
    if sql:find("lightrp_cash_migrations", 1, true) then return true, state.migrations[p[1]] and { clone(state.migrations[p[1]]) } or {} end
    if sql:find("lightrp_wallets", 1, true) then
        for _, w in pairs(state.wallets) do if w.identifier == p[1] and w.character_key == p[2] then return true, { clone(w) } end end
        return true, {}
    end
    error("unmodelled read: " .. sql)
end
function db.single(sql, p)
    if sql:find("SELECT 1", 1, true) then return state.wallets[p[1]] and { x = 1 } end
    local ok, rows = db.read(sql, p); return ok and rows[1]
end
local function apply(s, sql, p)
    if sql:find("INSERT INTO lightrp_inventories", 1, true) then s.inventories[p[1]] = { items = p[6], slots = p[4], max_weight = p[5] }
    elseif sql:find("INSERT INTO lightrp_cash_migrations", 1, true) then
        s.migrations[p[1]] = { account_number = p[1], inventory_id = p[2], legacy_cash = p[3], inventory_before = p[4], slots_before = p[5] }
    elseif sql:find("INSERT INTO lightrp_wallets", 1, true) then s.wallets[p[1]] = { account_number = p[1], identifier = p[2], character_key = p[3], owner_name = p[4], cash = p[5], bank = p[6] }
    elseif sql:find("SET cash = 0", 1, true) then s.wallets[p[1]].cash = 0
    elseif sql:find("SET bank = ?", 1, true) then s.wallets[p[2]].bank = p[1]
    elseif sql:find("INSERT INTO lightrp_transactions", 1, true) then
        -- the ledger columns: note VARCHAR(160), counterparty VARCHAR(96), utf8mb4 (strict mode)
        assert(#(p[7] or "") <= 160 and utf8.len(p[7] or ""), "ledger note too long or broken UTF-8")
        s.ledger[#s.ledger + 1] = clone(p)
    elseif sql:find("lightrp_staff_audit", 1, true) then s.audit[#s.audit + 1] = clone(p)
    elseif sql:find("SET owner_name", 1, true) then s.wallets[p[2]].owner_name = p[1]
    else error("unmodelled write: " .. sql) end
end
function db.run(sql, p) apply(state, sql, p); return true, 1 end
function db.transaction(writes)
    local draft = clone(state)
    for _, q in ipairs(writes) do apply(draft, q.query, q.values) end
    state = draft; return true
end
local commands = {}
LightRP = { db = db, module = function(n, t) LightRP[n] = t; return t end, log = noop, state = noop, stateProvider = noop,
    eachModule = noop, notice = noop, result = noop, action = noop, interaction = noop, removeInteraction = noop, dialog = noop,
    nowMs = function() return 1000 end, chat = { system = noop },
    command = function(name, _, fn) commands[name] = fn end,
    joinArgs = function(args, from)
        local count = args.n or #args
        from = from or 1
        if count < from then return "" end
        return (table.concat(args, " ", from, count)):gsub("^%s+", ""):gsub("%s+$", "")
    end,
    staff = { allowed = function(id, permission) return perms[id] ~= nil and perms[id][permission] == true end },
    characters = { get = function(id) return chars[id] end, displayName = function(id) return "Citizen " .. tostring(id) end } }
local positions = { [1] = { x = 0, y = 0, z = 0, bucket = 0 }, [2] = { x = 1, y = 0, z = 0, bucket = 0 }, [3] = { x = 2, y = 0, z = 0, bucket = 0 } }
Open77 = { players = { position = function(id) return positions[id] end, positions = function() return positions end }, vehicles = {} }
GetPlayers = function() return { 1, 2, 3 } end; GetPlayerName = function(id) return chars[tonumber(id)] and ("Account " .. id) or nil end
TriggerClientEvent = noop; AddEventHandler = noop; CreateThread = noop; Wait = function() coroutine.yield("wait") end
dofile("server/modules/inventory.lua"); dofile("server/modules/economy.lua"); dofile("server/config/economy.lua")
local I, M = LightRP.inventory, LightRP.money
for id = 1, 3 do I.onCharacterLoaded(id, chars[id]); M.onCharacterLoaded(id, chars[id]) end
assert(M.get(2), "the citizen has a wallet")
local rule = M.staffGrantRule()
assert(rule.maxGrant == 10000 and rule.minReason == 4 and rule.permission == "lightrp.money.unlimited")

local give = commands["lightrp.givemoney"]
local function line() return state.ledger[#state.ledger] end -- account, wallet, kind, amount, balance, counterparty, note
local bank, cash, lines = M.get(2).bank, M.get(2).cash, #state.ledger

-- No reason, or a reason under minReason: refused with the usage, nothing moves.
local ok, text = give(1, { "2", "bank", "500" })
assert(ok == false and text:find("A reason is required (at least 4 characters)", 1, true), tostring(text))
assert(text:find("usage: /lightrp.givemoney <id|me> <cash|bank> <amount> <reason>", 1, true), text)
ok, text = give(1, { "2", "bank", "500", "  ok  " })
assert(ok == false and text:find("reason is required", 1, true), tostring(text))
assert(M.get(2).bank == bank and #state.ledger == lines, "a refused grant moves nothing")

-- The reason is the ledger line's note.
assert(give(1, { "2", "bank", "500", "event", "prize:", "race", "winner" }))
assert(M.get(2).bank == bank + 500 and line()[3] == "staff" and line()[4] == 500 and line()[7] == "event prize: race winner", line()[7])
assert(give(1, { "2", "cash", "10000", "refund", "after", "the", "crash" }), "the cap itself is allowed")
assert(M.get(2).cash == cash + 10000 and line()[2] == "cash" and line()[7] == "refund after the crash")

-- One grant above the cap is refused for staff without the permission.
lines = #state.ledger
ok, text = give(1, { "2", "bank", "10001", "big", "refund" })
assert(ok == false and text:find("capped at €$ 10,000", 1, true) and text:find("lightrp.money.unlimited", 1, true), tostring(text))
assert(#state.ledger == lines and M.get(2).bank == bank + 500)
ok, text = give(1, { "2", "bank", "abc", "a", "reason" })
assert(ok == false and text:find("Invalid amount", 1, true), tostring(text))

-- The unlimited permission and the server console lift the cap.
assert(give(3, { "2", "bank", "50000", "owner", "grant" }))
assert(give(0, { "2", "bank", "50000", "console", "grant" }))
assert(M.get(2).bank == bank + 100500 and line()[7] == "console grant")

-- A long reason is cut at the note's 160 bytes, never inside a UTF-8 character.
assert(give(1, { "2", "bank", "1", string.rep("\u{E9}", 100) }))
assert(#line()[7] == 160 and line()[7] == string.rep("\u{E9}", 80))
assert(give(1, { "2", "bank", "1", "x" .. string.rep("\u{E9}", 100) }))
assert(#line()[7] == 159 and utf8.len(line()[7]))

-- maxGrant = 0 turns the cap off; the reason stays required.
LightRpEconomy.staffGrants.maxGrant = 0
assert(give(1, { "2", "bank", "20000", "no", "cap", "now" }))
assert(not give(1, { "2", "bank", "20000" }))
LightRpEconomy.staffGrants.maxGrant = 10000

-- The staff desk's Credit (admin.lua) follows the same rule; its reason (4-500
-- characters, the audit) is cut to the note's 160 bytes instead of losing the line.
LightRpSupportConfig = { permissions = {} }
LightRP.support = {
    allowed = function() return true end,
    identity = function(id) return chars[tonumber(id)] end,
    text = function(v, max, min)
        if type(v) ~= "string" then return nil end
        v = v:gsub("^%s+", ""):gsub("%s+$", "")
        if #v < min or #v > max then return nil end
        return v
    end,
    open = noop,
}
exports = noop; GetInvokingResource = function() return "open77_admin" end
dofile("server/modules/admin.lua")
local A, n = LightRP.admin, 0
local function credit(actor, amount, reason, wallet)
    n = n + 1
    return A.action(actor, { target = 2, account = chars[2].identifier, character = chars[2].key, action = "credit", wallet = wallet or "bank",
        amount = amount, reason = reason, confirmed = true, mutation = "credit-test-" .. n })
end
bank, lines = M.get(2).bank, #state.ledger
local r = credit(1, 10001, "Compensation after the crash")
assert(r and r.accepted == false and r.message:find("capped at €$ 10,000", 1, true), r and r.message)
assert(M.get(2).bank == bank and #state.ledger == lines)
r = credit(3, 25000, "Compensation after the crash")
assert(r.accepted and M.get(2).bank == bank + 25000 and line()[7] == "Compensation after the crash" and line()[6] == "Account 3")
r = credit(1, 10000, string.rep("long reason ", 40)) -- 480 characters: valid for the audit
assert(r.accepted and #line()[7] == 160 and line()[4] == 10000, "the line is kept, its note cut")
r = A.action(1, { target = 2, account = chars[2].identifier, character = chars[2].key, action = "debit", wallet = "bank",
    amount = 20000, reason = "Seized for a duplication exploit", confirmed = true, mutation = "debit-test-1" })
assert(r.accepted and line()[4] == -20000, "a debit is not capped")

print("PASS: staff grants (reason required and stored as the ledger note, 10,000 cap per grant, lightrp.money.unlimited and the console uncapped, UTF-8-safe 160-byte notes, staff desk Credit)")
