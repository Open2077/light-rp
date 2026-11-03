-- Money. Cash is the zero-weight inventory item `cash`; wallet.cash is only a
-- compatibility projection. Each active character also owns a bank
-- account numbered XXX-XXX (letters and digits, no O/I/0/1 so it can be read
-- out loud). Balances/items are server-owned and written through on every change;
-- every movement lands in lightrp_transactions. Other modules (jobs, shops,
-- rent) go through LightRP.money.* and never touch the tables.
--
--   LightRP.money.get(playerId)                    -> wallet | nil (draft characters have none)
--   LightRP.money.format(amount)                   -> "€$ 1,250"
--   LightRP.money.addCash / removeCash(playerId, amount, kind, note, counterparty)
--   LightRP.money.addBank / removeBank(playerId, amount, kind, note, counterparty)
--   LightRP.money.deposit / withdraw(playerId, amount)
--   LightRP.money.transfer(playerId, accountNumber, amount, note)
--   LightRP.money.pay(playerId, targetId, amount)  -> cash, hand to hand, within economy.payRange
--   LightRP.money.creditAccount(accountNumber, amount, kind, note, counterparty) -> offline-capable
--   LightRP.money.findAccount(accountNumber)       -> { number, ownerName } | nil
--   hook onMoneyChanged(playerId, wallet, delta, balance, kind)
local Config = LightRpConfig.economy
local Db = LightRP.db
local Money = LightRP.module("money", {})
local Inv = LightRP.inventory

-- Immutable recovery record + idempotency key. The legacy wallet.cash column
-- is zeroed atomically with delivery, and is never a live balance again.
Db.schema([[
    CREATE TABLE IF NOT EXISTS lightrp_cash_migrations (
        account_number CHAR(7) NOT NULL PRIMARY KEY,
        inventory_id VARCHAR(96) NOT NULL,
        legacy_cash BIGINT NOT NULL,
        inventory_before MEDIUMTEXT NOT NULL,
        slots_before INT NOT NULL,
        migrated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
]])

Db.schema([[
    CREATE TABLE IF NOT EXISTS lightrp_wallets (
        account_number CHAR(7)      NOT NULL PRIMARY KEY,
        identifier     VARCHAR(64)  NOT NULL,
        character_key  VARCHAR(64)  NOT NULL DEFAULT 'default',
        owner_name     VARCHAR(96)  NOT NULL DEFAULT '',
        cash           BIGINT       NOT NULL DEFAULT 0,
        bank           BIGINT       NOT NULL DEFAULT 0,
        created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uq_wallet_owner (identifier, character_key)
    )
]])
Db.schema([[
    CREATE TABLE IF NOT EXISTS lightrp_transactions (
        id             BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
        account_number CHAR(7)      NOT NULL,
        wallet         VARCHAR(8)   NOT NULL,
        kind           VARCHAR(24)  NOT NULL,
        amount         BIGINT       NOT NULL,
        balance_after  BIGINT       NOT NULL,
        counterparty   VARCHAR(96)  NULL,
        note           VARCHAR(160) NULL,
        created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        KEY ix_tx_account (account_number, id)
    )
]])

local wallets = {}   -- playerId -> { number, identifier, key, ownerName, cash, bank, history, busy }
local settling = {} -- identifier#character -> an in-flight atomic shop checkout
local byNumber = {}  -- account number -> playerId (online wallets only)
Money.byPlayer = wallets

-- ---------------------------------------------------------------------------
-- Helpers

local ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

local function block()
    local out = {}
    for i = 1, 3 do
        local n = math.random(#ALPHABET)
        out[i] = ALPHABET:sub(n, n)
    end
    return table.concat(out)
end

local function numberTaken(number)
    if byNumber[number] ~= nil then return true end
    if not Db.ready then return false end
    return Db.single("SELECT 1 AS x FROM lightrp_wallets WHERE account_number = ?", { number }) ~= nil
end

local function generateNumber()
    for _ = 1, 64 do
        local number = block() .. "-" .. block()
        if not numberTaken(number) then return number end
    end
    return nil
end

-- "k7f2qd", "K7F-2QD" -> "K7F-2QD"; nil when it is not an account number.
function Money.normalizeNumber(value)
    local raw = tostring(value or ""):upper():gsub("[%s%-]", "")
    if #raw ~= 6 then return nil end
    for i = 1, 6 do
        if not ALPHABET:find(raw:sub(i, i), 1, true) then return nil end
    end
    return raw:sub(1, 3) .. "-" .. raw:sub(4, 6)
end

-- Whole eddies only, 1 .. maxTransaction.
function Money.validAmount(value)
    local n = tonumber(value)
    if n == nil or n ~= n then return nil end
    n = math.tointeger(n)
    if n == nil or n <= 0 or n > (Config.maxTransaction or 1000000000) then return nil end
    return n
end

function Money.format(amount)
    amount = math.tointeger(tonumber(amount) or 0) or 0
    local sign = amount < 0 and "-" or ""
    local digits = tostring(math.abs(amount))
    local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return sign .. (Config.currency or "€$") .. " " .. grouped
end

local function stamp()
    local ok, value = pcall(function() return os.date("%Y-%m-%d %H:%M:%S") end)
    return ok and value or nil
end

local function persist(w)
    if not Db.ready then return false, "database_unavailable" end
    return Db.run("UPDATE lightrp_wallets SET bank = ? WHERE account_number = ?", { w.bank, w.number })
end

-- One ledger line. `history` is the in-memory tail of an online wallet (nil for
-- an offline account: the row is written, nobody is watching).
local function record(number, history, wallet, kind, amount, balanceAfter, counterparty, note)
    local entry = { wallet = wallet, kind = kind, amount = amount, balanceAfter = balanceAfter,
        counterparty = counterparty, note = note, at = stamp() }
    if history then
        table.insert(history, 1, entry)
        while #history > (Config.historyLength or 10) do table.remove(history) end
    end
    if Db.ready then
        Db.run([[INSERT INTO lightrp_transactions (account_number, wallet, kind, amount, balance_after, counterparty, note)
                 VALUES (?, ?, ?, ?, ?, NULLIF(?, ''), NULLIF(?, ''))]],
            { number, wallet, kind, amount, balanceAfter, counterparty or "", note or "" })
    end
    return entry
end

local function loadHistory(number)
    local rows = Db.query(string.format([[SELECT wallet, kind, amount, balance_after, counterparty, note, created_at
        FROM lightrp_transactions WHERE account_number = ? ORDER BY id DESC LIMIT %d]], Config.historyLength or 10), { number })
    local history = {}
    for _, row in ipairs(rows) do
        history[#history + 1] = { wallet = row.wallet, kind = row.kind, amount = tonumber(row.amount) or 0,
            balanceAfter = tonumber(row.balance_after) or 0, counterparty = row.counterparty, note = row.note,
            at = row.created_at and tostring(row.created_at) or nil }
    end
    return history
end

local function changed(playerId, w, wallet, delta, kind)
    LightRP.state(playerId, "money")
    LightRP.eachModule("onMoneyChanged", playerId, wallet, delta, w[wallet], kind)
end

local function ledger(w, wallet, kind, delta, balance, counterparty, note)
    local entry = { wallet = wallet, kind = kind, amount = delta, balanceAfter = balance,
        counterparty = counterparty, note = note, at = stamp() }
    local write = { query = [[INSERT INTO lightrp_transactions (account_number, wallet, kind, amount, balance_after, counterparty, note)
        VALUES (?, ?, ?, ?, ?, NULLIF(?, ''), NULLIF(?, ''))]],
        values = { w.number, wallet, kind, delta, balance, counterparty or "", note or "" } }
    return write, function()
        table.insert(w.history, 1, entry)
        while #w.history > (Config.historyLength or 10) do table.remove(w.history) end
    end
end

-- Inventory transfers keep the HUD/ledger in step, without mirroring cash to SQL.
function Money.inventoryReceipt(inv, after)
    if inv.kind ~= "player" or after == Inv.cashOf(inv) then return end
    local id, w = inv.playerId, wallets[inv.playerId]
    if not w or inv.cashReady ~= true or inv.id ~= "player:" .. w.identifier .. "#" .. w.key then return nil, nil, "no_wallet" end
    if w.busy then return nil, nil, "busy" end
    local delta = after - Inv.cashOf(inv)
    local write, receipt = ledger(w, "cash", "inventory", delta, after, nil, "Physical cash moved")
    return write, function()
        w.cash = after
        receipt()
        if wallets[id] == w then pcall(changed, id, w, "cash", delta, "inventory") end
    end
end

local function migrateCash(playerId, w)
    local inv = Inv and Inv.player(playerId)
    if not inv then return false, "no_inventory" end
    if inv.busy then return false, "busy" end
    inv.busy = true
    local called, ok, reason = pcall(function()
        local read, rows = Db.read("SELECT account_number FROM lightrp_cash_migrations WHERE account_number = ?", { w.number })
        if not read then return false, "database_error" end
        if rows[1] then
            if w.cash ~= 0 then return false, "legacy_cash_not_zero" end
            w.cash = Inv.cashOf(inv)
            return true
        end
        local amount = math.tointeger(w.cash)
        if not amount or amount < 0 or amount > 9007199254740991 then return false, "invalid_legacy_cash" end
        local draft = Inv.draft(inv)
        local fits, why = Inv.adjustCash(draft, amount)
        if not fits and why == "no_room" then
            -- Never discard another item or an old balance during migration.
            draft.slots = draft.slots + math.ceil(amount / LightRpItems.cash.stack)
            fits, why = Inv.adjustCash(draft, amount)
        end
        if not fits then return false, why end
        local before = Inv.writeDraft(inv, inv).values[6]
        local saved, failure = Db.transaction({
            { query = [[INSERT INTO lightrp_cash_migrations (account_number, inventory_id, legacy_cash, inventory_before, slots_before)
                VALUES (?, ?, ?, ?, ?)]], values = { w.number, inv.id, amount, before, inv.slots } },
            Inv.writeDraft(inv, draft),
            { query = "UPDATE lightrp_wallets SET cash = 0 WHERE account_number = ?", values = { w.number } },
        })
        if not saved then return false, failure end
        Inv.applyDraft(inv, draft)
        w.cash = Inv.cashOf(inv)
        LightRP.log("cash migrated for account %s: %d eddies (recovery snapshot saved)", w.number, amount)
        return true
    end)
    Inv.releaseBusy(inv)
    return called and ok == true, called and reason or "database_error"
end

-- ---------------------------------------------------------------------------
-- Load / unload, following the character

local function unload(playerId)
    local w = wallets[playerId]
    if w then byNumber[w.number] = nil end
    wallets[playerId] = nil
end

local function open(playerId, c)
    local w = { identifier = c.identifier, key = c.key, ownerName = LightRP.characters.displayName(playerId), history = {} }
    local number = generateNumber()
    if number == nil then return nil, "account_number_exhausted" end
    w.number, w.cash, w.bank = number, Config.startingCash or 0, Config.startingBank or 0
    if Db.ready and c.identifier then
        local ok = Db.run([[INSERT INTO lightrp_wallets (account_number, identifier, character_key, owner_name, cash, bank)
                            VALUES (?, ?, ?, ?, ?, ?)]], { w.number, c.identifier, c.key, w.ownerName, w.cash, w.bank })
        if not ok then return nil, "database_error" end
    end
    if w.bank > 0 then record(w.number, w.history, "bank", "opening", w.bank, w.bank, "Night City Bank", "Account opened") end
    if w.cash > 0 then record(w.number, w.history, "cash", "opening", w.cash, w.cash, nil, "Starting cash") end
    return w
end

local function load(playerId, c)
    unload(playerId)
    if c == nil or c.status ~= "active" then return nil end
    if not Db.ready or not Inv or not Inv.player(playerId) then return nil end
    local owner = tostring(c.identifier) .. "#" .. c.key
    while settling[owner] do Wait(10) end
    local w, reason
    if Db.ready and c.identifier then
        local read, rows = Db.read("SELECT account_number, owner_name, cash, bank FROM lightrp_wallets WHERE identifier = ? AND character_key = ?", { c.identifier, c.key })
        if not read then return nil end
        local row = rows[1]
        if row then
            w = { identifier = c.identifier, key = c.key, ownerName = LightRP.characters.displayName(playerId),
                number = row.account_number, cash = tonumber(row.cash) or 0, bank = tonumber(row.bank) or 0 }
            if row.owner_name ~= w.ownerName then
                Db.run("UPDATE lightrp_wallets SET owner_name = ? WHERE account_number = ?", { w.ownerName, w.number })
            end
            w.history = loadHistory(w.number)
        end
    end
    if w == nil then
        w, reason = open(playerId, c)
        if w == nil then
            LightRP.log("wallet for %d could not be opened: %s", playerId, tostring(reason))
            return nil
        end
        LightRP.log("wallet %s opened for %s", w.number, w.ownerName)
    end
    local migrated, failure = migrateCash(playerId, w)
    if not migrated then
        LightRP.log("cash migration for %d blocked: %s; stored balances preserved", playerId, tostring(failure))
        LightRP.notice(playerId, { kind = "error", title = "Wallet unavailable", body = "Your money is safe, but could not be loaded. Please reconnect or contact staff." })
        return nil
    end
    wallets[playerId] = w
    Inv.player(playerId).cashReady = true
    byNumber[w.number] = playerId
    return w
end

function Money.get(playerId)
    local w = wallets[playerId]
    local inv = Inv and Inv.player(playerId)
    if w and inv and inv.cashReady and inv.id == "player:" .. w.identifier .. "#" .. w.key then
        w.cash = Inv.cashOf(inv)
        return w
    end
end

function Money.onCharacterLoaded(playerId, c)
    load(playerId, c)
    LightRP.state(playerId, "money")
end

function Money.onCharacterActivated(playerId, c)
    local w = load(playerId, c)
    LightRP.state(playerId, "money")
    if w then
        LightRP.notice(playerId, { kind = "money", title = "Night City Bank", durationMs = 12000,
            body = string.format("Account %s opened. %s in the bank, %s in your pocket.", w.number, Money.format(w.bank), Money.format(w.cash)) })
    end
end

function Money.onDisconnected(playerId) unload(playerId) end

function Money.onDatabaseReady()
    for _, id in ipairs(GetPlayers()) do
        local c = LightRP.characters.get(id)
        if c and c.status == "active" then
            load(id, c)
            LightRP.state(id, "money")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Movements. Every function returns ok, reason.

local function guard(playerId, amount)
    local w = Money.get(playerId)
    if w == nil then return nil, "no_wallet" end
    if w.busy then return nil, "busy" end
    local n = Money.validAmount(amount)
    if n == nil then return nil, "invalid_amount" end
    return w, n
end

-- delta may be negative; the wallet never goes below zero.
local function change(playerId, wallet, delta, kind, note, counterparty)
    if wallet == "cash" then return Money.exchange(playerId, wallet, delta, nil, nil, kind, note, counterparty) end
    local w, n = guard(playerId, math.abs(delta))
    if w == nil then return false, n end
    if delta < 0 then n = -n end
    local before = w[wallet]
    if before + n < 0 then return false, "insufficient_funds" end
    w.busy = true
    w[wallet] = before + n
    local ok = persist(w)
    if not ok then w[wallet] = before; w.busy = false; return false, "database_error" end
    record(w.number, w.history, wallet, kind, n, w[wallet], counterparty, note)
    w.busy = false
    changed(playerId, w, wallet, n, kind)
    return true
end

function Money.addCash(playerId, amount, kind, note, counterparty) return change(playerId, "cash", math.abs(tonumber(amount) or 0), kind or "credit", note, counterparty) end
function Money.removeCash(playerId, amount, kind, note, counterparty) return change(playerId, "cash", -math.abs(tonumber(amount) or 0), kind or "debit", note, counterparty) end
function Money.addBank(playerId, amount, kind, note, counterparty) return change(playerId, "bank", math.abs(tonumber(amount) or 0), kind or "credit", note, counterparty) end
function Money.removeBank(playerId, amount, kind, note, counterparty) return change(playerId, "bank", -math.abs(tonumber(amount) or 0), kind or "debit", note, counterparty) end

-- Internal commerce primitive. Inventory callers pass their SAME draft as the
-- final argument. Other callers supply a prepared SQL write (or list) and a
-- non-yielding cache commit. Cash creates/locks a pocket draft when needed.
-- Neither cache changes until the SQL commit succeeds.
function Money.exchange(playerId, wallet, delta, inventoryWrite, commitItems, kind, note, counterparty, inventoryDraft)
    if wallet ~= "cash" and wallet ~= "bank" then return false, "invalid_payment" end
    local w, n = guard(playerId, math.abs(delta))
    if not w then return false, n end
    if not Db.ready then return false, "database_unavailable" end
    if delta < 0 then n = -n end
    local after = w[wallet] + n
    if after < 0 then return false, "insufficient_funds" end
    if after > 9007199254740991 then return false, "invalid_amount" end
    local cash
    if wallet == "cash" then
        if inventoryDraft then
            -- Shops already own this lock; change the SAME staged inventory,
            -- never overwrite their delivery with a separately copied cash bag.
            local inv = Inv.player(playerId)
            if not inv or not inv.busy then return false, "busy" end
            if inventoryDraft.cashDelta ~= n then
                local ok, failure = Inv.adjustCash(inventoryDraft, n)
                if not ok then return false, failure end
            end
            if Inv.cashOf(inventoryDraft) ~= after then return false, "invalid_amount" end
            inventoryWrite = Inv.writeDraft(inv, inventoryDraft)
            if inventoryDraft.extraWrites and #inventoryDraft.extraWrites > 0 then
                -- a bought firearm's serial rows travel with the delivery (Inv.trade)
                inventoryWrite = { inventoryWrite }
                for _, query in ipairs(inventoryDraft.extraWrites) do inventoryWrite[#inventoryWrite + 1] = query end
            end
        else
            local failure
            cash, failure = Inv.prepareCash(playerId, n)
            if not cash then return false, failure end
        end
    end
    w.busy = true
    local owner = tostring(w.identifier) .. "#" .. w.key
    settling[owner] = true
    settling[w.number] = true
    local writes = {}
    if wallet == "bank" then
        writes[#writes + 1] = { query = "UPDATE lightrp_wallets SET bank = ? WHERE account_number = ?", values = { after, w.number } }
    end
    if inventoryWrite then
        if inventoryWrite.query then writes[#writes + 1] = inventoryWrite
        else for _, write in ipairs(inventoryWrite) do writes[#writes + 1] = write end end
    end
    if cash then writes[#writes + 1] = cash.write end
    local receiptWrite, receipt = ledger(w, wallet, kind, n, after, counterparty, note)
    writes[#writes + 1] = receiptWrite
    local called, ok, reason = pcall(Db.transaction, writes)
    if not called or ok ~= true then
        w.busy = false
        settling[owner] = nil
        settling[w.number] = nil
        if cash then Inv.releaseBusy(cash.inventory) end
        return false, called and reason or "database_error"
    end
    w[wallet] = after
    if cash then Inv.applyDraft(cash.inventory, cash.draft) end
    if commitItems then commitItems() end
    receipt()
    w.busy = false
    settling[owner] = nil
    settling[w.number] = nil
    if cash then Inv.releaseBusy(cash.inventory); Inv.publishCommitted(cash.inventory) end
    if wallets[playerId] == w then
        local published, failure = pcall(changed, playerId, w, wallet, n, kind)
        if not published then LightRP.log("committed checkout: wallet notification failed: %s", tostring(failure)) end
    end
    return true
end

-- Cash <-> bank inside one wallet, atomically for the cache.
local function move(playerId, from, to, amount, kindOut, kindIn)
    local w, n = guard(playerId, amount)
    if w == nil then return false, n end
    if w[from] < n then return false, "insufficient_funds" end
    local cashDelta = from == "cash" and -n or n
    local bankAfter = w.bank - cashDelta
    if bankAfter > 9007199254740991 then return false, "invalid_amount" end
    local bankReceipt, commitReceipt = ledger(w, "bank", kindOut, -cashDelta, bankAfter, "Night City Bank", nil)
    return Money.exchange(playerId, "cash", cashDelta, {
        { query = "UPDATE lightrp_wallets SET bank = ? WHERE account_number = ?", values = { bankAfter, w.number } },
        bankReceipt,
    }, function() w.bank = bankAfter; commitReceipt() end, kindIn, nil, "Night City Bank")
end

function Money.deposit(playerId, amount) return move(playerId, "cash", "bank", amount, "deposit", "deposit") end
function Money.withdraw(playerId, amount) return move(playerId, "bank", "cash", amount, "withdraw", "withdraw") end

function Money.findAccount(number)
    number = Money.normalizeNumber(number)
    if number == nil then return nil end
    local online = byNumber[number]
    if online and wallets[online] then return { number = number, ownerName = wallets[online].ownerName, playerId = online } end
    if not Db.ready then return nil end
    local row = Db.single("SELECT owner_name FROM lightrp_wallets WHERE account_number = ?", { number })
    if row == nil then return nil end
    return { number = number, ownerName = row.owner_name }
end

-- Credit any account, online or not (salaries, refunds, staff). Returns ok, reason.
function Money.creditAccount(number, amount, kind, note, counterparty)
    local target = Money.findAccount(number)
    if target == nil then return false, "unknown_account" end
    if settling[target.number] then return false, "busy" end
    local n = Money.validAmount(amount)
    if n == nil then return false, "invalid_amount" end
    if target.playerId then
        return change(target.playerId, "bank", n, kind or "credit", note, counterparty)
    end
    local ok = Db.run("UPDATE lightrp_wallets SET bank = bank + ? WHERE account_number = ?", { n, target.number })
    if not ok then return false, "database_error" end
    local row = Db.single("SELECT bank FROM lightrp_wallets WHERE account_number = ?", { target.number })
    record(target.number, nil, "bank", kind or "credit", n, row and tonumber(row.bank) or 0, counterparty, note)
    return true
end

-- Bank to bank, to any account number. The fee (config) is taken on top.
function Money.transfer(playerId, number, amount, note)
    local w, n = guard(playerId, amount)
    if w == nil then return false, n end
    local target = Money.findAccount(number)
    if target == nil then return false, "unknown_account" end
    if target.number == w.number then return false, "same_account" end
    local fee = math.max(0, math.tointeger(tonumber(Config.transferFee) or 0) or 0)
    if w.bank < n + fee then return false, "insufficient_funds" end
    note = note and tostring(note):sub(1, 160) or nil
    w.busy = true
    w.bank = w.bank - n - fee
    local ok = persist(w)
    if not ok then w.bank = w.bank + n + fee; w.busy = false; return false, "database_error" end
    record(w.number, w.history, "bank", "transfer_out", -n, w.bank + fee, target.ownerName .. " · " .. target.number, note)
    if fee > 0 then record(w.number, w.history, "bank", "fee", -fee, w.bank, "Night City Bank", "Transfer fee") end
    w.busy = false
    local from = w.ownerName .. " · " .. w.number
    local credited, reason = Money.creditAccount(target.number, n, "transfer_in", note, from)
    if not credited then
        -- Give the money back rather than leave it in limbo.
        w.bank = w.bank + n + fee
        persist(w)
        record(w.number, w.history, "bank", "refund", n + fee, w.bank, "Night City Bank", "Transfer failed: " .. tostring(reason))
        changed(playerId, w, "bank", 0, "refund")
        return false, reason
    end
    changed(playerId, w, "bank", -(n + fee), "transfer_out")
    if target.playerId then LightRP.eachModule("onMoneySent", playerId, target.playerId, n, "transfer") end
    if target.playerId then
        LightRP.notice(target.playerId, { kind = "money", title = "Transfer received", durationMs = 10000,
            body = string.format("%s from %s%s", Money.format(n), from, note and (" — " .. note) or "") })
    end
    return true, target
end

local function distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Cash, hand to hand: both online, both with a wallet, close enough, same bucket.
function Money.pay(playerId, targetId, amount)
    local w, n = guard(playerId, amount)
    if w == nil then return false, n end
    targetId = tonumber(targetId)
    if targetId == nil or targetId == playerId or GetPlayerName(targetId) == nil then return false, "unknown_target" end
    local tw = wallets[targetId]
    if tw == nil then return false, "target_no_wallet" end
    if tw.busy then return false, "busy" end
    if w.cash < n then return false, "insufficient_funds" end
    local here, there = Open77.players.position(playerId), Open77.players.position(targetId)
    if here == nil or there == nil or (here.bucket or 0) ~= (there.bucket or 0) or distance(here, there) > (Config.payRange or 6) then
        return false, "too_far"
    end
    local ok, failure = Inv.transferCash(playerId, targetId, n)
    if not ok then return false, failure end
    LightRP.notice(targetId, { kind = "money", title = "Cash received", body = string.format("%s from %s", Money.format(n), w.ownerName), durationMs = 8000 })
    LightRP.eachModule("onMoneySent", playerId, targetId, n, "cash")
    return true, tw
end

function Money.history(playerId)
    local w = wallets[playerId]
    return w and w.history or {}
end

-- ---------------------------------------------------------------------------
-- State, actions, commands

LightRP.stateProvider("money", function(playerId)
    local w = Money.get(playerId)
    if w == nil then return { currency = Config.currency, cash = 0, history = {} } end
    return { currency = Config.currency, cash = w.cash, bank = { number = w.number, balance = w.bank }, history = w.history }
end)

local REASONS = {
    no_wallet = "You have no wallet yet: finish your character first.",
    target_no_wallet = "That player has no wallet yet.",
    no_inventory = "Your inventory could not be loaded. Reconnect or contact staff; no money was moved.",
    no_room = "Make room in your inventory for the cash. Nothing was charged.",
    database_unavailable = "The database is unavailable. No money was moved.",
    busy = "Another operation is still running, try again.",
    invalid_amount = "Invalid amount: whole eddies, greater than zero.",
    insufficient_funds = "Insufficient funds.",
    unknown_account = "No account with that number.",
    same_account = "That is your own account.",
    unknown_target = "Unknown player.",
    too_far = "Too far away: cash changes hands within " .. tostring(Config.payRange or 6) .. " m.",
    database_error = "The bank did not answer, nothing was moved.",
}
local function explain(reason) return REASONS[reason] or ("Denied: " .. tostring(reason)) end
Money.explain = explain

LightRP.action("money.deposit", function(playerId, payload)
    local ok, reason = Money.deposit(playerId, payload.amount)
    LightRP.result(playerId, ok, ok and (Money.format(payload.amount) .. " deposited.") or explain(reason), "money.deposit")
end)

LightRP.action("money.withdraw", function(playerId, payload)
    local ok, reason = Money.withdraw(playerId, payload.amount)
    LightRP.result(playerId, ok, ok and (Money.format(payload.amount) .. " withdrawn.") or explain(reason), "money.withdraw")
end)

LightRP.action("money.transfer", function(playerId, payload)
    local ok, result = Money.transfer(playerId, payload.to, payload.amount, payload.note)
    LightRP.result(playerId, ok, ok and string.format("%s sent to %s (%s).", Money.format(payload.amount), result.ownerName, result.number) or explain(result), "money.transfer")
end)

LightRP.action("money.pay", function(playerId, payload)
    local ok, result = Money.pay(playerId, payload.target, payload.amount)
    LightRP.result(playerId, ok, ok and string.format("%s handed to %s.", Money.format(payload.amount), result.ownerName) or explain(result), "money.pay")
end)

local function summary(w)
    return string.format("Cash %s · Bank %s · Account %s", Money.format(w.cash), Money.format(w.bank), w.number)
end

LightRP.command("money", {}, function(source)
    local w = wallets[source]
    if w == nil then return false, explain("no_wallet") end
    return true, summary(w)
end)

LightRP.command("bank", {}, function(source)
    local w = wallets[source]
    if w == nil then return false, explain("no_wallet") end
    for i = math.min(5, #w.history), 1, -1 do
        local e = w.history[i]
        LightRP.chat.system(source, string.format("%s %s %s%s", e.at or "", e.kind, (e.amount >= 0 and "+" or "") .. Money.format(e.amount),
            e.counterparty and (" · " .. e.counterparty) or ""))
    end
    return true, summary(w)
end)

LightRP.command("pay", { usage = "/pay <id> <amount>" }, function(source, args)
    if args[1] == nil or args[2] == nil then return false end
    local ok, result = Money.pay(source, args[1], args[2])
    if not ok then return false, explain(result) end
    return true, string.format("%s handed to %s.", Money.format(args[2]), result.ownerName)
end)

LightRP.command("transfer", { usage = "/transfer <account XXX-XXX> <amount> [note]" }, function(source, args)
    if args[1] == nil or args[2] == nil then return false end
    local note = LightRP.joinArgs(args, 3)
    local ok, result = Money.transfer(source, args[1], args[2], note ~= "" and note or nil)
    if not ok then return false, explain(result) end
    return true, string.format("%s sent to %s (%s).", Money.format(args[2]), result.ownerName, result.number)
end)

-- Staff -------------------------------------------------------------------

local function parseTarget(source, value)
    if value == nil or value == "" or value == "me" then return source end
    local id = tonumber(value)
    if id == nil or GetPlayerName(id) == nil then return nil end
    return id
end

local function walletArg(value)
    value = string.lower(tostring(value or ""))
    if value == "cash" or value == "bank" then return value end
    return nil
end

LightRP.command("lightrp.givemoney", { restricted = true, usage = "/lightrp.givemoney <id|me> <cash|bank> <amount> [note]" }, function(source, args)
    local target, wallet = parseTarget(source, args[1]), walletArg(args[2])
    if target == nil or wallet == nil or args[3] == nil then return false end
    local note = LightRP.joinArgs(args, 4)
    local fn = wallet == "cash" and Money.addCash or Money.addBank
    local ok, reason = fn(target, args[3], "staff", note ~= "" and note or "Staff grant", "Staff")
    if not ok then return false, explain(reason) end
    LightRP.notice(target, { kind = "money", title = "Staff", body = string.format("%s added to your %s.", Money.format(args[3]), wallet), durationMs = 8000 })
    return true, string.format("%s given to %s (%s).", Money.format(args[3]), LightRP.characters.displayName(target), wallet)
end)

LightRP.command("lightrp.takemoney", { restricted = true, usage = "/lightrp.takemoney <id|me> <cash|bank> <amount> [note]" }, function(source, args)
    local target, wallet = parseTarget(source, args[1]), walletArg(args[2])
    if target == nil or wallet == nil or args[3] == nil then return false end
    local note = LightRP.joinArgs(args, 4)
    local fn = wallet == "cash" and Money.removeCash or Money.removeBank
    local ok, reason = fn(target, args[3], "staff", note ~= "" and note or "Staff seizure", "Staff")
    if not ok then return false, explain(reason) end
    return true, string.format("%s taken from %s (%s).", Money.format(args[3]), LightRP.characters.displayName(target), wallet)
end)

LightRP.command("lightrp.account", { restricted = true, usage = "/lightrp.account <id|me|XXX-XXX>" }, function(source, args)
    local number = Money.normalizeNumber(args[1])
    local w
    if number then
        local online = byNumber[number]
        w = online and wallets[online]
        if w == nil and Db.ready then
            local row = Db.single("SELECT account_number, identifier, character_key, owner_name, cash, bank FROM lightrp_wallets WHERE account_number = ?", { number })
            if row then
                local cash = tonumber(row.cash) or 0
                local read, rows = Db.read("SELECT items FROM lightrp_inventories WHERE id = ?", { "player:" .. row.identifier .. "#" .. row.character_key })
                if not read then return false, explain("database_unavailable") end
                if rows[1] then
                    local ok, items = pcall(json.decode, rows[1].items)
                    if not ok or type(items) ~= "table" then return false, "Stored inventory could not be read." end
                    cash = cash + Inv.cashOf({ items = items })
                end
                w = { number = row.account_number, ownerName = row.owner_name, cash = cash, bank = tonumber(row.bank) or 0 }
            end
        end
    else
        local target = parseTarget(source, args[1])
        w = target and wallets[target]
    end
    if w == nil then return false, explain("unknown_account") end
    return true, w.ownerName .. " — " .. summary(w)
end)

LightRP.log("economy ready: %s starting cash, %s in the bank, pay range %.0f m",
    Money.format(Config.startingCash or 0), Money.format(Config.startingBank or 0), Config.payRange or 6)
