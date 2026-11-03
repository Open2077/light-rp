-- Iconic implants: rare drops, never sold, never resold, never traded (C.iconics in
-- server/config/cyberware.lua). The sources call one hook each, so their own files stay as
-- they are but for one line:
--   onWorldBossFinished({ id, title, boss, success, results = { [playerId] = { eligible, pay, share } } })
--                       server/modules/world_bosses.lua, after the payout
--   onRaidFinished({ instance, point, difficulty, success, test, members = { ids } })
--                       server/modules/mission_chimera.lua, at the end of a run
-- Each eligible participant (online, character loaded) is rolled on his own, server side:
-- `chance`, or the pity counter (lightrp_cyberware_pity, per character and source) reaching
-- `pity`. A character who owns every item of a source is not rolled and keeps his counter. The
-- drop goes to the implant storage (LightRP.cyberware.store), the winner is told, the city is
-- told, the log keeps every roll.
local C = LightRpCyberwareConfig
local I = type(C.iconics) == "table" and C.iconics or { enabled = false, sources = {}, items = {} }
local Db = LightRP.db
local Iconics = LightRP.module("cyberware_iconics", {})

Db.schema([[
    CREATE TABLE IF NOT EXISTS lightrp_cyberware_pity (
        identifier    VARCHAR(64) NOT NULL,
        character_key VARCHAR(32) NOT NULL,
        source        VARCHAR(32) NOT NULL,
        misses        INT         NOT NULL DEFAULT 0,
        updated_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (identifier, character_key, source)
    )
]])

local function log(fmt, ...) LightRP.log("cyberware: " .. fmt, ...) end

local misses = {} -- "identifier:key:source" -> misses since the last drop (cache of the table)

local function slot(identifier, key, source) return tostring(identifier) .. ":" .. tostring(key) .. ":" .. source end

function Iconics.misses(identifier, key, source)
    local k = slot(identifier, key, source)
    if misses[k] == nil then
        local row = Db.ready and Db.single("SELECT misses FROM lightrp_cyberware_pity WHERE identifier = ? AND character_key = ? AND source = ?",
            { identifier, key, source }) or nil
        misses[k] = row and tonumber(row.misses) or 0
    end
    return misses[k]
end

local function setMisses(identifier, key, source, n)
    misses[slot(identifier, key, source)] = n
    if Db.ready then
        Db.run("INSERT INTO lightrp_cyberware_pity (identifier, character_key, source, misses) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE misses = VALUES(misses)",
            { identifier, key, source, n })
    end
end

--- One roll for one participant. -> item (granted, in storage), "roll" | "pity"; or nil, why
--- ("disabled", "not_loaded", "owns_all", "miss" + the misses so far, a storage refusal).
function Iconics.roll(playerId, sourceId)
    local source = type(I.sources) == "table" and I.sources[sourceId] or nil
    local Cy = LightRP.cyberware
    if I.enabled == false or type(source) ~= "table" or not Cy then return nil, "disabled" end
    local identifier, key = Cy.owner(playerId)
    if not identifier then return nil, "not_loaded" end
    local missing = {}
    for _, id in ipairs(source.items or {}) do
        if Cy.item(id) and not Cy.owns(playerId, id) then missing[#missing + 1] = id end
    end
    if #missing == 0 then return nil, "owns_all" end
    local before = Iconics.misses(identifier, key, sourceId)
    local pity = math.floor(tonumber(source.pity) or 0)
    local guaranteed = pity > 0 and before + 1 >= pity
    if not guaranteed and math.random() >= (tonumber(source.chance) or 0) then
        setMisses(identifier, key, sourceId, before + 1)
        return nil, "miss", before + 1
    end
    local itemId = missing[#missing > 1 and math.random(#missing) or 1]
    local ok, why = Cy.store(playerId, itemId, "iconic:" .. sourceId)
    if not ok then return nil, why end -- the counter stays: the next one is still owed
    setMisses(identifier, key, sourceId, 0)
    return Cy.item(itemId), guaranteed and "pity" or "roll"
end

local function award(playerId, sourceId)
    local source = I.sources[sourceId]
    local item, how, count = Iconics.roll(playerId, sourceId)
    local identifier, key = LightRP.cyberware and LightRP.cyberware.owner(playerId)
    if not item then
        log("iconic roll for %d (%s/%s) from %s: %s%s", playerId, tostring(identifier), tostring(key), sourceId, tostring(how),
            count and (" (" .. count .. " without a drop)") or "")
        return nil
    end
    local Ch = LightRP.characters
    local name = Ch and type(Ch.displayName) == "function" and Ch.displayName(playerId) or ("Player " .. tostring(playerId))
    local fee = LightRP.money and LightRP.money.format(C.fittingFee or 0) or tostring(C.fittingFee or 0)
    LightRP.notice(playerId, { kind = "success", title = "ICONIC IMPLANT", source = "CYBERWARE", durationMs = 12000,
        body = string.format("%s is yours. It waits in your implant storage: any ripperdoc fits it for %s (%d capacity points).",
            item.name, fee, LightRP.cyberware.cost(item)) })
    LightRP.broadcastNotice({ kind = "info", title = "ICONIC IMPLANT", source = "NIGHT CITY", durationMs = 9000,
        body = string.format("%s pulled an iconic implant out of the %s: %s.", name, source.label or sourceId, item.name) })
    log("iconic %s dropped for %d (%s/%s) from %s (%s)", item.id, playerId, tostring(identifier), tostring(key), sourceId, how)
    return item
end

-- The rolls run on their own thread (storage writes wait on the database) a moment after the
-- result screens.
local function rollAll(sourceId, ids)
    if I.enabled == false or type(I.sources) ~= "table" or not I.sources[sourceId] or #ids == 0 then return end
    CreateThread(function()
        Wait(tonumber(I.delayMs) or 2500)
        for _, id in ipairs(ids) do
            local ok, err = pcall(award, id, sourceId)
            if not ok then log("iconic roll for %d from %s failed: %s", id, sourceId, tostring(err)) end
        end
    end)
end

function Iconics.onWorldBossFinished(ev)
    if type(ev) ~= "table" or ev.success ~= true or type(ev.results) ~= "table" then return end
    local ids = {}
    for id, r in pairs(ev.results) do
        id = tonumber(id)
        if id and type(r) == "table" and r.eligible == true then ids[#ids + 1] = id end
    end
    table.sort(ids)
    rollAll("worldBoss", ids)
end

function Iconics.onRaidFinished(ev)
    if type(ev) ~= "table" or ev.success ~= true or ev.test == true or type(ev.members) ~= "table" then return end
    for sourceId, source in pairs(I.sources or {}) do
        if source.difficulty and source.difficulty == ev.difficulty and (source.point == nil or source.point == ev.point) then
            local ids = {}
            for _, id in ipairs(ev.members) do if tonumber(id) then ids[#ids + 1] = tonumber(id) end end
            rollAll(sourceId, ids)
        end
    end
end
