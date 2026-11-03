-- Prestige titles (server/modules/titles.lua), the host stubbed: earning from
-- reputation tiers, clears, raid reports, world bosses, paid activity counters,
-- contracts and Dogtown's real stats; per character; one shown (chat, crew,
-- Hall of Fame); live board titles held only at rank 1; hidden sources; the
-- weekly King of Dogtown (exclusions, ISO week suffix, expiry, restart); staff
-- grant / revoke; the database round trip; the page state's size.
local clock = 0
_G.CreateThread = function(fn) local co = coroutine.create(fn); local ok, err = coroutine.resume(co); if not ok then error(err) end end
_G.Wait = function() coroutine.yield() end
local unixNow = 2966 * 604800 - 259200 + 3600 -- Monday 2026-11-02 01:00 UTC (Dogtown week 2966)
local online, names = {}, {}
_G.GetPlayers = function() local t = {} for id in pairs(online) do t[#t + 1] = tostring(id) end table.sort(t) return t end
_G.GetPlayerName = function(id) return online[id] and names[id] or nil end
_G.Open77 = { time = { unix = function() return unixNow end } }

local chars, tiers, clears, crews, refreshed = {}, {}, {}, {}, {}
local modules, actions, commands, providers = {}, {}, {}, {}
local notices, results, states = {}, {}, {}
local hofBoards, hofAt, excluded = {}, 1, {}
local dogStats, dogWeek = {}, 2966
local db = { titles = {}, choice = {}, progress = {}, dogtown = {} }
local function keyOfId(id) local c = chars[id]; return c and (c.identifier .. "#" .. c.key) end
_G.LightRP = {
    nowMs = function() return clock end, log = function() end,
    module = function(name, def)
        def.name = name
        for i = #modules, 1, -1 do if modules[i].name == name then table.remove(modules, i) end end
        modules[#modules + 1] = def; LightRP[name] = def; return def
    end,
    eachModule = function(hook, ...) for _, m in ipairs(modules) do if type(m[hook]) == "function" then m[hook](...) end end end,
    action = function(name, fn) actions[name] = fn end,
    command = function(name, _, fn) commands[name] = fn end,
    stateProvider = function(key, fn) providers[key] = fn end,
    state = function(id, keys) states[#states + 1] = { id = id, keys = keys } end,
    notice = function(id, n) notices[#notices + 1] = { id = id, title = n.title, body = n.body } end,
    result = function(id, ok, text, action) results[#results + 1] = { id = id, ok = ok, text = text, action = action } end,
    characters = { get = function(id) return chars[id] end },
    parties = { of = function(id) return crews[id] end, refresh = function(p) refreshed[#refreshed + 1] = p end },
    missions = {
        tier = function(id) return tiers[keyOfId(id)] or 1 end,
        cleared = function(id, point, difficulty) return (clears[keyOfId(id)] or {})[point .. ":" .. difficulty] or 0 end,
        point = function(id) return (id == "chimera_raid" or id == "sector04_blackout") and { id = id } or nil end,
    },
    activities = { registry = { ["arena.duel"] = {}, ["race.grid"] = {}, ["chase.wanted"] = {}, ["chase.pve"] = {} } },
    worldBosses = { catalogue = function() return { { id = "boss" } } end },
    hallOfFame = {
        cache = function() return { at = hofAt, boards = hofBoards } end,
        excludedBy = function(key) return excluded[key] end,
    },
    db = {
        ready = false, schema = function() end, single = function() end,
        run = function(sql, p)
            -- like the runtime: as many values as placeholders (a nil ends the list)
            local _, marks = sql:gsub("%?", "")
            assert(marks == #(p or {}), string.format("parameter_count_mismatch: %d placeholders, %d values: %s", marks, #(p or {}), sql:sub(1, 60)))
            if sql:find("INSERT INTO lightrp_titles ", 1, true) then
                local suffix, expires = p[4], p[5]
                if suffix == "" and sql:find("NULLIF(?, '')", 1, true) then suffix = nil end
                if expires == 0 and sql:find("NULLIF(?, 0)", 1, true) then expires = nil end
                db.titles[p[1] .. "#" .. p[2] .. "|" .. p[3]] = { identifier = p[1], character_key = p[2], title_id = p[3],
                    suffix = suffix, expires_at = expires }
            elseif sql:find("DELETE FROM lightrp_titles ", 1, true) then db.titles[p[1] .. "#" .. p[2] .. "|" .. p[3]] = nil
            elseif sql:find("INSERT INTO lightrp_title_choice", 1, true) then db.choice[p[1] .. "#" .. p[2]] = { identifier = p[1], character_key = p[2], title_id = p[3] }
            elseif sql:find("DELETE FROM lightrp_title_choice", 1, true) then db.choice[p[1] .. "#" .. p[2]] = nil
            elseif sql:find("INSERT INTO lightrp_title_progress", 1, true) then
                local k = p[1] .. "#" .. p[2] .. "|" .. p[3]
                db.progress[k] = { counter = p[3], value = (db.progress[k] and db.progress[k].value or 0) + p[4] }
            end
            return true
        end,
        read = function(sql, p)
            local out = {}
            if sql:find("LEFT JOIN", 1, true) then
                for key, c in pairs(db.choice) do
                    local t = db.titles[key .. "|" .. c.title_id]
                    out[#out + 1] = { identifier = c.identifier, character_key = c.character_key, title_id = c.title_id, owned_id = t and t.title_id, suffix = t and t.suffix, expires_at = t and t.expires_at }
                end
            elseif sql:find("FROM lightrp_titles WHERE", 1, true) then
                for k, t in pairs(db.titles) do if k:find(p[1] .. "#" .. p[2] .. "|", 1, true) == 1 then out[#out + 1] = t end end
            elseif sql:find("FROM lightrp_title_progress", 1, true) then
                for k, row in pairs(db.progress) do if k:find(p[1] .. "#" .. p[2] .. "|", 1, true) == 1 then out[#out + 1] = row end end
            elseif sql:find("FROM lightrp_title_choice WHERE", 1, true) then
                local c = db.choice[p[1] .. "#" .. p[2]]
                if c then out[1] = c end
            elseif sql:find("FROM lightrp_dogtown_stats", 1, true) then
                for _, row in ipairs(db.dogtown[p[1]] or {}) do out[#out + 1] = row end
            end
            return true, out
        end,
    },
}
LightRP.dogtown = {
    statsFor = function(id) return dogStats[id] end,
    weekIndex = function() return dogWeek end,
}

dofile("server/config/titles.lua")
dofile("server/modules/titles.lua")
local T = LightRP.titles

local function join(id, account, key, name)
    chars[id] = { status = "active", identifier = account, key = key }
    names[id], online[id] = name, true
    LightRP.eachModule("onCharacterLoaded", id)
end
local function view(id) return providers.titles(id) end
local function entry(id, titleId) for _, e in ipairs(view(id).list or {}) do if e.id == titleId then return e end end end
local function earned(id, titleId) local e = entry(id, titleId); return e ~= nil and e.earned == true end
local function unlocked(id, pattern)
    for i = #notices, 1, -1 do
        local n = notices[i]
        if n.id == id and n.title == "TITLE UNLOCKED" and (not pattern or n.body:find(pattern, 1, true)) then return true end
    end
    return false
end
local function select(id, titleId) actions["titles.select"](id, { id = titleId }); return results[#results] end
local function values(v)
    if type(v) ~= "table" then return 1 end
    local n = 0
    for _, x in pairs(v) do n = n + values(x) end
    return n
end

-- ── ISO weeks (the King of Dogtown's suffix) ──
assert(T.isoWeek(2966) == "W45", "2026-11-02 is in ISO week 45")
assert(T.isoWeek(2922) == "W01", "2025-12-29 opens ISO 2026-W01")
assert(T.isoWeek(2870) == "W01", "2024-12-30 opens ISO 2025-W01")
assert(T.isoWeek(2661) == "W53", "2020-12-28 is ISO 2020-W53")

-- ── reputation tiers and clears: a quiet sync on load, a notice after ──
tiers["acc1#c1"] = 2
join(1, "acc1", "c1", "Kaito")
assert(earned(1, "merc") and not unlocked(1), "tier II on load, quietly")
assert(not earned(1, "operator"))
tiers["acc1#c1"] = 3
T.sync(1)
assert(earned(1, "operator") and unlocked(1, "Operator (Rare)"), "a new tier is told")
clears["acc1#c1"] = { ["chimera_raid:standard"] = 1 }
T.sync(1)
assert(earned(1, "chimera_standard") and not earned(1, "chimera_hard"))

-- ── choosing and showing ──
local r = select(1, "legend")
assert(not r.ok and r.text == "You have not earned this title.")
assert(not select(1, "nope").ok)
local before = #refreshed
crews[1] = { id = "crew1", members = { 1 } }
r = select(1, "operator")
assert(r.ok and r.text == "Title shown: Operator.", r.text)
assert(#refreshed > before, "the crew frame refreshes")
local shown = T.shown(1)
assert(shown and shown.id == "operator" and shown.label == "Operator" and shown.rarity == "rare")
assert(T.chatName(1, "Kaito") == "Kaito · Operator", "the RP chat name")
assert(T.forKey("acc1#c1") == "Operator", "Hall of Fame rows")
assert(view(1).shown == "operator" and view(1).chosen == "operator")
r = select(1, "none")
assert(r.ok and T.shown(1) == nil and T.chatName(1, "Kaito") == "Kaito" and T.forKey("acc1#c1") == nil, "no title")
select(1, "operator")

-- ── per character: another character of the same account starts from zero ──
chars[1] = { status = "active", identifier = "acc1", key = "c2" }
LightRP.eachModule("onCharacterLoaded", 1)
assert(T.shown(1) == nil and not earned(1, "operator") and not earned(1, "merc"), "titles are per character")
assert(T.forKey("acc1#c1") == "Operator", "the other character keeps its title")
chars[1] = { status = "active", identifier = "acc1", key = "c1" }
LightRP.eachModule("onCharacterLoaded", 1)
assert(earned(1, "operator"), "back on the first character")

-- ── raid feats from the Chimera's report ──
join(2, "acc2", "c1", "Rosa")
local chimera = { id = "chimera_raid" }
T.onMissionFinished({ members = { 1, 2 }, test = true, report = { enraged = false, downs = 0 } }, chimera, { id = "critical" }, true)
T.onMissionFinished({ members = { 1, 2 }, report = { enraged = false, downs = 0 } }, chimera, { id = "critical" }, false)
T.onMissionFinished({ members = { 1, 2 }, report = { enraged = false, downs = 0 } }, chimera, { id = "standard" }, true)
assert(not earned(1, "overclock_denied") and not earned(1, "two_man_army") and not earned(1, "flawless"), "test, failure and Standard give nothing")
T.onMissionFinished({ members = { 1, 2, 3 }, report = { enraged = true, downs = 2 } }, chimera, { id = "hard" }, true)
assert(not earned(1, "overclock_denied") and not earned(1, "two_man_army"))
T.onMissionFinished({ members = { 1, 2 }, report = { enraged = false, downs = 1, operators = 3 } }, chimera, { id = "critical" }, true)
assert(earned(1, "overclock_denied") and not earned(1, "two_man_army"), "three started the fight, one left: not a two-man army")
T.onMissionFinished({ members = { 1, 2 }, report = { enraged = false, downs = 1, operators = 2 } }, chimera, { id = "critical" }, true)
assert(earned(1, "overclock_denied") and earned(2, "overclock_denied") and earned(1, "two_man_army") and not earned(1, "flawless"))
T.onMissionFinished({ members = { 2 }, report = { enraged = true, downs = 0 } }, chimera, { id = "critical" }, true)
assert(earned(2, "flawless") and not earned(1, "flawless"), "Critical without a down")

-- ── world bosses ──
T.onWorldEventEnded({ lastHit = 1, contrib = { [1] = { eligible = true, score = 10 }, [2] = { eligible = true, score = 30 } } }, false)
assert(not earned(1, "boss_killer"))
T.onWorldEventEnded({ lastHit = 1, contrib = { [1] = { eligible = true, score = 10 }, [2] = { eligible = true, score = 30 }, [9] = { eligible = false, score = 99 } } }, true)
assert(earned(1, "boss_killer") and earned(2, "lions_share") and not earned(1, "lions_share"))

-- ── paid ranked activity results, counted per character ──
local function result(id, activity, stats, extra)
    extra = extra or {}
    local entry = { activity = activity, ranked = extra.ranked }
    T.onActivityResult(id, entry, { won = extra.won, placement = extra.placement }, { stats = stats, unranked = extra.unranked },
        extra.verdict or { amount = 100, detail = { players = extra.players or 2 } })
end
for _ = 1, 9 do result(1, "arena.duel", { roundsWon = 2, roundsLost = 0 }, { won = true }) end
result(1, "arena.duel", { roundsWon = 2, roundsLost = 0 }, { won = true, verdict = { kind = "repeat" } })
result(1, "arena.duel", { roundsWon = 2, roundsLost = 0 }, { won = true, unranked = true })
result(1, "arena.duel", { roundsWon = 2, roundsLost = 0 }, { won = true, ranked = false })
result(1, "arena.duel", { roundsWon = 0, roundsLost = 2 }, { won = false })
assert(not earned(1, "duelist") and entry(1, "duelist").value == 9 and entry(1, "duelist").count == 10, "9 / 10")
result(1, "arena.duel", { roundsWon = 2, roundsLost = 1 }, { won = true })
assert(earned(1, "duelist") and entry(1, "duelist").value == 10)
for _ = 1, 4 do result(1, "arena.duel", { roundsWon = 2, roundsLost = 1 }, { won = true }) end
assert(earned(1, "sudden_death"), "5 deciding rounds")
for _ = 1, 10 do result(1, "race.grid", { finished = true }, { placement = 1, players = 2 }) end
assert(not earned(1, "street_racer"), "at least 3 real drivers")
for _ = 1, 10 do result(1, "race.grid", { finished = true }, { placement = 1, players = 3 }) end
assert(earned(1, "street_racer"))
result(1, "chase.wanted", { extractions = 6, arrests = 4 })
result(1, "chase.wanted", { extractions = 4, arrests = 5 })
assert(earned(1, "getaway_driver") and not earned(1, "long_arm") and entry(1, "long_arm").value == 9)
-- NCPD Escape against the game's own NCPD (op77_chase pve.lua resultFor)
local function escape(how, stars, more)
    local s = { outcome = (how == "clock" or how == "extraction") and "escaped" or "busted", how = how, seconds = 120,
        police = "ncpd", difficulty = "standard", stars = stars, runners = 1 }
    for k, v in pairs(more or {}) do s[k] = v end
    return s
end
for _ = 1, 9 do result(1, "chase.pve", escape("extraction", 4)) end
result(1, "chase.pve", escape("clock", 3))
result(1, "chase.pve", escape("extraction", 3)) -- every run starts at 3
result(1, "chase.pve", escape("arrest", 4, { difficulty = "hard" }))
result(1, "chase.pve", escape("extraction", 4, { policeBlocked = true }))
result(1, "chase.pve", escape("extraction", 4, { police = "bots" }))
result(1, "chase.pve", { outcome = "escaped", how = "shake", stars = 3 })
result(1, "chase.pve", escape("extraction", 3), { verdict = { kind = "too_short" } })
result(1, "chase.pve", escape("extraction", 3), { ranked = false })
assert(not earned(1, "ghost") and entry(1, "ghost").value == 9, "only paid extractions at 4+ stars against the real NCPD")
result(1, "chase.pve", escape("extraction", 5, { difficulty = "critical" }))
assert(earned(1, "ghost"))

-- ── contracts award through LightRP.titles.award; grant-only titles refuse it ──
assert(T.award(1, "streak_7") == true and earned(1, "streak_7"))
assert(T.award(1, "streak_7") == false, "earned once")
assert(T.award(1, "dogtown_king") == false, "the crown is never awarded by a hook")

-- ── a source that is gone hides its titles, unless already earned ──
LightRP.activities.registry["arena.duel"] = nil
LightRP.activities.registry["race.grid"] = nil
assert(entry(1, "duelist") ~= nil, "earned stays listed")
assert(entry(2, "duelist") == nil and entry(2, "street_racer") == nil, "no duels on this server: hidden")
LightRP.activities.registry["arena.duel"], LightRP.activities.registry["race.grid"] = {}, {}

-- ── live Hall of Fame titles: rank 1 only, while it lasts ──
assert(entry(1, "top_gun") == nil, "a board the Hall of Fame does not have is hidden")
hofBoards["pvp.kills"] = { rows = { { key = "acc2#c1", rank = 1 }, { key = "acc1#c1", rank = 2 } } }
local tg = entry(1, "top_gun")
assert(tg and tg.live and not tg.earned and tg.rarity == "live")
assert(not select(1, "top_gun").ok, "rank 2 cannot show it")
hofBoards["pvp.kills"].rows = { { key = "acc1#c1", rank = 1 }, { key = "acc2#c1", rank = 2 } }
assert(earned(1, "top_gun") and select(1, "top_gun").ok and T.shown(1).label == "Top Gun")
hofBoards["pvp.kills"].rows = { { key = "acc2#c1", rank = 1 }, { key = "acc1#c1", rank = 2 } }
assert(T.shown(1) == nil and T.forKey("acc1#c1") == nil and view(1).chosen == "top_gun", "lost rank 1: hidden, still chosen")
hofBoards["pvp.kills"].rows = { { key = "acc1#c1", rank = 1 }, { key = "acc2#c1", rank = 1 } }
assert(T.shown(1).label == "Top Gun" and earned(2, "top_gun"), "a shared first place")
select(1, "operator")

-- ── Dogtown: the zone's own stats ──
dogStats[1] = { key = "acc1#c1", total = { kills = 49, deaths = 3, looted = 0, bestStreak = 4 } }
T.sync(1)
assert(not earned(1, "most_wanted") and not earned(1, "barghest_problem"))
assert(entry(1, "barghest_problem").value == 49 and entry(1, "barghest_problem").count == 50 and entry(1, "most_wanted").value == 4)
dogStats[1].total.kills, dogStats[1].total.bestStreak = 50, 5
T.onDogtownKill(1, 2, { streak = 5, bountyStreak = 0 })
assert(earned(1, "most_wanted") and earned(1, "barghest_problem"), "a credited kill syncs at once")
assert(not earned(1, "bounty_hunter") and entry(1, "bounty_hunter").value == 0)
dogStats[2] = { key = "acc2#OTHER", total = { kills = 500, bestStreak = 50 } }
T.sync(2)
assert(not earned(2, "barghest_problem"), "stats of another character do not count")
T.onDogtownKill(1, 2, { streak = 1, bountyStreak = 5 }); T.onDogtownKill(1, 2, { streak = 2, bountyStreak = 7 })
assert(entry(1, "bounty_hunter").value == 2)
T.onDogtownKill(1, 2, { streak = 3, bountyStreak = 5 })
assert(earned(1, "bounty_hunter"), "three bounties ended")
LightRP.dogtown = nil
assert(entry(2, "most_wanted") == nil and entry(1, "most_wanted") ~= nil, "Dogtown stopped: hidden unless earned")
LightRP.dogtown = { statsFor = function(id) return dogStats[id] end, weekIndex = function() return dogWeek end }

-- ── the weekly King of Dogtown ──
assert(T.crownDogtown() == nil, "needs the database")
LightRP.db.ready = true
excluded["staff1#c1"] = "staff"
db.dogtown[2965] = {
    { identifier = "staff1", character_key = "c1", kills = 40 },
    { identifier = "acc2", character_key = "c1", kills = 31 },
    { identifier = "acc1", character_key = "c1", kills = 12 },
}
assert(T.crownDogtown() == "acc2#c1", "last week's top killer, staff left out")
local king = entry(2, "dogtown_king")
assert(king.earned and king.label == "King of Dogtown · W44" and unlocked(2, "King of Dogtown · W44"))
assert(king.expiresInMs == ((2966 + 1) * 604800 - 259200 - unixNow) * 1000, "until the end of this week")
assert(db.titles["acc2#c1|dogtown_king"].suffix == "W44")
assert(T.crownDogtown() == nil, "once per week")
assert(select(2, "dogtown_king").ok and T.chatName(2, "Rosa") == "Rosa · King of Dogtown · W44")
-- a restart crowns the same holder again, quietly
local count = #notices
dofile("server/modules/titles.lua"); T = LightRP.titles
LightRP.eachModule("onDatabaseReady")
assert(T.crownDogtown() == "acc2#c1" and #notices == count, "no second notice after a restart")
assert(T.shown(2).label == "King of Dogtown · W44", "the choice survives the restart")
-- next week: a new king, the old crown expires
unixNow = unixNow + 7 * 86400; dogWeek = 2967
db.dogtown[2966] = { { identifier = "acc1", character_key = "c1", kills = 22 } }
assert(T.crownDogtown() == "acc1#c1" and earned(1, "dogtown_king") and entry(1, "dogtown_king").label == "King of Dogtown · W45")
assert(not earned(2, "dogtown_king") and T.shown(2) == nil and T.chatName(2, "Rosa") == "Rosa", "last week's crown is gone")
-- a week without a credited kill crowns nobody
unixNow = unixNow + 7 * 86400; dogWeek = 2968
assert(T.crownDogtown() == nil)
LightRP.db.ready = false

-- ── staff ──
local ok, text = commands["lightrp.titles"](0, { "grant", "1", "legend" })
assert(ok and text == "Granted legend." and earned(1, "legend"))
ok = commands["lightrp.titles"](0, { "grant", "1", "top_gun" })
assert(not ok, "a live title cannot be granted")
ok = commands["lightrp.titles"](0, { "grant", "1", "dogtown_king", "W01", "1" })
assert(ok and entry(1, "dogtown_king").label == "King of Dogtown · W01" and entry(1, "dogtown_king").expiresInMs == 86400000)
select(1, "legend")
ok = commands["lightrp.titles"](0, { "revoke", "1", "legend" })
assert(ok and not earned(1, "legend") and T.shown(1) == nil, "revoked, and no longer shown")
assert(not commands["lightrp.titles"](0, { "grant", "1", "nope" }))

-- ── the database: earned titles, counters and the choice come back ──
LightRP.db.ready = true
join(3, "acc3", "c1", "Vi")
for _ = 1, 9 do result(3, "chase.pve", escape("extraction", 4)) end
T.award(3, "lucky_seven"); select(3, "lucky_seven")
T.onDisconnected(3); online[3] = nil
assert(T.forKey("acc3#c1") == "Lucky Seven", "offline: the Hall of Fame still reads the title")
dofile("server/modules/titles.lua"); T = LightRP.titles
LightRP.eachModule("onDatabaseReady")
assert(T.forKey("acc3#c1") == "Lucky Seven", "loaded at database ready")
do -- no suffix, no expiry: stored as NULL, not "" / 0 (0 would read back as already expired)
    local row = db.titles["acc3#c1|lucky_seven"]
    assert(row and row.suffix == nil and row.expires_at == nil, "a plain title is stored with NULL suffix and expiry")
end
join(3, "acc3", "c1", "Vi")
assert(earned(3, "lucky_seven") and entry(3, "ghost").value == 9 and T.shown(3).label == "Lucky Seven")
result(3, "chase.pve", escape("extraction", 4, { difficulty = "hard" }))
assert(earned(3, "ghost"), "the counter resumed")
-- a stored choice of a title no longer owned is ignored
db.choice["acc4#c1"] = { identifier = "acc4", character_key = "c1", title_id = "legend" }
dofile("server/modules/titles.lua"); T = LightRP.titles
LightRP.eachModule("onDatabaseReady")
assert(T.forKey("acc4#c1") == nil)
LightRP.db.ready = false

-- ── off ──
LightRpTitles.enabled = false
assert(T.shown(1) == nil and view(1).enabled == false and T.chatName(1, "Kaito") == "Kaito")
LightRpTitles.enabled = true

-- ── the page state stays small ──
assert(values(view(1)) < 900, "titles state: " .. values(view(1)))
assert(#view(1).list <= #LightRpTitles.catalogue)

print("titles_test: ok")
