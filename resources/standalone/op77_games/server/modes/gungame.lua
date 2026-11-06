-- Gun Game: a weapon ladder, everyone alone. A kill climbs one step and hands the next weapon at
-- once; a kill on the last step (the knife) wins. Each step hands its weapon alone (no knife beside
-- it since 2026-11-06), so there is no knife kill below the top step. A death nobody earned (a fall,
-- the play area) costs a step.
-- At the clock the highest step wins, reached first; nobody off the first step is nobody.
--
-- Weapons are held strictly. A hit counts with the step's weapon, verified, and the
-- arbiter remembers it: a kill the platform reports without such a hit by that killer, on that
-- step, scores nothing and costs the victim nothing. Explosions and anything else never hurt, a
-- body seen drawing something else is armed again, and no weapon changes hands without a server
-- that saw the assign verified (GamesCombat.arm). Each step is an explicit kit of Light RP's
-- temporary-kit contract, handed again at each change of step.
local Config = GamesConfig
local E = GamesEngine

local KNIFE = "Items.Preset_Knife_Default"
local SLOT = { step = 1, knife = 2 }

local GG = {
    seconds = 600,
    respawnMs = 2000,
    protectMs = 2000,     -- a respawned body neither takes nor deals damage this long
    meleeWindowMs = 1500, -- a knife hit this recent makes the kill a knife kill
    guardMs = 2000,       -- at most one re-arm this often (a wrong weapon in hand)
    dashCheckMs = 1000,
    -- Live setting DASH_gungame: everyone dashes. The values are the source's.
    dash = { id = "games.gungame.dash", version = 1, profile = "dash", config = {
        inputKey = "ctrl", allowGround = true, allowAir = true, presentation = "native",
        staminaCost = 15, cooldownMs = 900, maxCharges = 2, chargeRegenMs = 3000,
    } },
    -- Reserves: the source's class defaults. Every record is in the 2.31 weapon catalogue.
    ladder = {
        { name = "Lexington", class = "Pistol", record = "Items.Preset_Lexington_Default", reserve = 45 },
        { name = "Nova", class = "Revolver", record = "Items.Preset_Nova_Default", reserve = 24 },
        { name = "Saratoga", class = "SMG", record = "Items.Preset_Saratoga_Default", reserve = 120 },
        { name = "Pulsar", class = "SMG", record = "Items.Preset_Pulsar_Default", reserve = 120 },
        { name = "Copperhead", class = "Assault rifle", record = "Items.Preset_Copperhead_Default", reserve = 120 },
        { name = "Ajax", class = "Assault rifle", record = "Items.Preset_Ajax_Default", reserve = 120 },
        { name = "Carnage", class = "Shotgun", record = "Items.Preset_Carnage_Default", reserve = 24 },
        { name = "Tactician", class = "Shotgun", record = "Items.Preset_Tactician_Default", reserve = 24 },
        { name = "Defender", class = "LMG", record = "Items.Preset_Defender_Default", reserve = 160 },
        { name = "Achilles", class = "Precision rifle", record = "Items.Preset_Achilles_Default", reserve = 40 },
        { name = "Nekomata", class = "Sniper rifle", record = "Items.Preset_Nekomata_Default", reserve = 20 },
        { name = "Burya", class = "Revolver", record = "Items.Preset_Burya_Default", reserve = 24 },
        { name = "Unity", class = "Pistol", record = "Items.Preset_Unity_Default", reserve = 45 },
        { name = "Knife", class = "Melee", record = KNIFE, melee = true },
    },
}

GamesGungame = { rules = GG, knife = KNIFE }
local G = GamesGungame
local LADDER = GG.ladder
local TOP = #LADDER

-- One kit per step: the step's weapon alone (the top step is the knife alone). The knife is no
-- longer handed beside each weapon (owner, 2026-11-06): a knife in an idle slot made every weapon
-- snapshot fail on the clients (weapon HUD frozen, FPS drop, kits re-sent at every kill). So a knife
-- kill below the top step no longer exists. p.plan == SETS[step] is what "armed for this step" means.
local SETS = {}
for step, entry in ipairs(LADDER) do
    SETS[step] = entry.melee and { primary = KNIFE, label = entry.name, names = { entry.name } } or {
        primary = entry.record, reserve = { entry.reserve }, label = entry.name, names = { entry.name },
    }
end
G.sets = SETS

-- The clock ran out: the highest step, reached first. A true tie is a draw, and a room still on
-- the first step has no winner. `list`: players with .gg.
function G.clockWinner(list)
    local top, second
    for _, p in ipairs(list) do
        local x = p.gg
        if top == nil or x.step > top.gg.step or (x.step == top.gg.step and x.stepAt < top.gg.stepAt) then
            top, second = p, top
        elseif second == nil or x.step > second.gg.step or (x.step == second.gg.step and x.stepAt < second.gg.stepAt) then
            second = p
        end
    end
    if top == nil or top.gg.step <= 1 then return nil end
    if second and second.gg.step == top.gg.step and second.gg.stepAt == top.gg.stepAt then return nil end
    return top
end

local function setStep(p, step)
    local state = p.gg
    local to = math.max(1, math.min(TOP, step))
    if to == state.step then return false end
    state.step, state.stepAt = to, E.now()
    return true
end

local function armStep(match, p, t)
    p.gg.armedAt = t
    GamesCombat.arm(match, p, SETS[p.gg.step], true) -- mid-fight: no time for a body to land
end

local function announce(p)
    local entry = LADDER[p.gg.step]
    E.banner(p.id, entry.name:upper(), ("Step %d of %d"):format(p.gg.step, TOP), "accent", 1500)
end

-- ---------------------------------------------------------------- dash --

local dashDefined = false

local function dashCall(name, ...)
    if type(Open77.dash) ~= "table" or type(Open77.dash[name]) ~= "function" then return nil, "unavailable" end
    local ok, result, why = pcall(Open77.dash[name], ...)
    if not ok then return nil, tostring(result) end
    return result, why
end

local function defineDash()
    if dashDefined then return true end
    local result, why = dashCall("define", GG.dash)
    dashDefined = result ~= nil and result ~= false
    if not dashDefined then E.log("gun game dash unavailable: " .. tostring(why)) end
    return dashDefined
end

-- A player with another resource's dash (Light RP's implant) keeps it, there is nothing of
-- ours to take back. A grant needs a living body, and the platform may end one: asked again.
local function giveDash(p)
    if not defineDash() then return end
    local state = dashCall("current", p.id)
    if state ~= nil and state.ownedByCaller == false then return end
    local projection = type(state) == "table" and type(state.projection) == "table" and state.projection.status or nil
    if state ~= nil and projection ~= "removed" then
        p.gg.dash = true
        return
    end
    local result, why = dashCall("grant", p.id, GG.dash.id)
    if result then p.gg.dash = true
    elseif why == "definition_unavailable" then dashDefined = false end
end

local function takeDash(id, tries)
    local result, why = dashCall("revoke", id)
    if result or tries <= 0 or Open77.players.name(id) == nil then
        if not result then E.log(("%d: dash not taken back: %s"):format(id, tostring(why))) end
        return
    end
    SetTimeout(1000, function() takeDash(id, tries - 1) end)
end

-- ---------------------------------------------------------------- the mode --

local function rank(a, b)
    if (a.won == true) ~= (b.won == true) then return a.won == true end
    if a.gg.step ~= b.gg.step then return a.gg.step > b.gg.step end
    if a.gg.stepAt ~= b.gg.stepAt then return a.gg.stepAt < b.gg.stepAt end
    return a.id < b.id
end

local function leaderOf(match)
    local list = E.members(match)
    table.sort(list, rank)
    return list[1]
end

local def = E.mode({
    id = "games.gungame", key = "gungame", label = "Gun Game", kind = "pvp",
    description = "Everyone alone on a ladder of 14 weapons. A kill climbs, a kill with the knife on the last step wins.",
    minPlayers = 2, maxPlayers = 16,
    schema = {
        points = { { key = "centre", label = "Play area centre", color = "#ffcc00" } },
        lists = { { key = "spawns", label = "Spawn", color = "#3ddc84", min = 2, max = 32 } },
        numbers = { { key = "radius", label = "Play area radius", min = 10, max = 400, default = 70, unit = "m" } },
        area = { centre = "centre", radius = "radius", holds = { "spawns" } },
    },
    pvp = true,
    seconds = GG.seconds, respawnMs = GG.respawnMs, protectMs = GG.protectMs,
    kit = function(_, p) return SETS[p.gg.step] end,

    setup = function(match)
        match.gg = { next = 0 }
        for _, p in pairs(match.players) do p.gg = { step = 1, stepAt = 0, humiliations = 0 } end
    end,

    -- The start: one spawn after the other, spread (a map may have two for sixteen players).
    -- Later: the engine's choice, away from everybody.
    spawnFor = function(match)
        if match.phase == "running" then return nil end
        local gg, spawns = match.gg, match.map.spawns
        gg.next = gg.next + 1
        return spawns[(gg.next - 1) % #spawns + 1], 2.0
    end,

    start = function(match)
        for _, p in ipairs(E.members(match)) do giveDash(p) end
    end,

    tick = function(match, t)
        local dash = t >= (match.gg.dashAt or 0)
        if dash then match.gg.dashAt = t + GG.dashCheckMs end
        for _, p in ipairs(E.members(match)) do
            if p.alive and t >= p.holdUntil then
                -- A step changed while the body was down: it stands up with the old gun.
                if p.plan ~= SETS[p.gg.step] then armStep(match, p, t) end
                if dash then giveDash(p) end
            end
        end
    end,

    damage = function(_, event, attacker, victim)
        local kind = tostring(event.attackKind or "")
        if kind == "explosion" then return false end
        local state = attacker.gg
        if attacker.plan ~= SETS[state.step] then return false end -- the old gun, on its way out
        local melee = LADDER[state.step].melee
        if melee and kind == "ranged" then return false end -- the source: only the top step is melee only
        local knife = GamesCombat.slotOf(attacker, event.weaponTdbId) == (melee and SLOT.step or SLOT.knife)
        victim.gg.hit = { by = attacker.id, at = E.now(), step = state.step, knife = knife and kind == "melee" }
        return nil
    end,

    killed = function(match, victim, killer)
        local hit, state = victim.gg.hit, killer and killer.gg
        local t = E.now()
        victim.gg.hit = nil
        if killer == nil then
            if setStep(victim, victim.gg.step - 1) then
                E.feed(match, ("%s set themselves back: %s"):format(victim.name, LADDER[victim.gg.step].name), "danger")
                announce(victim)
            end
            return
        end
        if hit == nil or hit.by ~= killer.id or hit.step ~= state.step or t - hit.at > Config.match.lastHitMs then
            killer.kills = killer.kills - 1 -- no hit we let through: nobody earned this
            E.log(("%s: kill of %d by %d scored nothing"):format(match.id, victim.id, killer.id))
            return
        end
        if state.step >= TOP then
            match.gg.winner = killer
            E.finish(match, "ladder")
            return
        end
        if hit.knife and t - hit.at <= GG.meleeWindowMs then
            state.humiliations = state.humiliations + 1
            E.feed(match, ("%s humiliated %s"):format(killer.name, victim.name), "danger")
            if setStep(victim, victim.gg.step - 1) then announce(victim) end
            return
        end
        setStep(killer, state.step + 1)
        if state.step == TOP then E.feed(match, ("%s is on the final weapon!"):format(killer.name), "danger")
        else E.feed(match, ("%s reached the %s"):format(killer.name, LADDER[state.step].name), "info") end
        announce(killer)
        if killer.alive then armStep(match, killer, t) end -- else on the way back up (tick)
    end,

    left = function(_, p)
        if p.gg and p.gg.dash then
            p.gg.dash = nil
            takeDash(p.id, 3)
        end
    end,

    hud = function(match, p, view)
        local state = p.gg
        local entry, following = LADDER[state.step], LADDER[state.step + 1]
        view.objective = entry.melee and "Final weapon: a knife kill wins" or ("Kill with the %s"):format(entry.name)
        view.progress = { { id = "ladder", label = "Ladder", value = state.step / TOP, tone = entry.melee and "danger" or "accent" } }
        local leader = leaderOf(match)
        view.stats = {
            { label = "Weapon", value = entry.name },
            { label = "Step", value = ("%d/%d"):format(state.step, TOP) },
            { label = "Next", value = following and following.name or "Win" },
            { label = "Leader", value = leader and ("%s %d"):format(leader.name, leader.gg.step) or "-" },
        }
    end,

    results = function(match, reason)
        local winner = match.gg.winner
        if reason == "forfeit" then winner = E.members(match)[1]
        elseif reason == "time" then winner = G.clockWinner(E.members(match)) end
        local ranking = {}
        for _, p in pairs(match.roster) do
            p.won = p == winner
            p.score = p.gg.step
            p.row = { outcome = p.won and "won" or LADDER[p.gg.step].name }
            ranking[#ranking + 1] = p
        end
        table.sort(ranking, rank)
        return {
            ranking = ranking,
            lines = {
                { label = "Winner", value = winner and winner.name or "Nobody" },
                { label = "Ladder", value = ("%d weapons"):format(TOP) },
            },
            columns = { "placement", "score", "kills", "deaths" },
        }
    end,
})

-- Holding something else than the step's weapon or the knife: armed again, at most once every
-- guardMs and never right after an arm. Only the arbiter decides a kill, this keeps hands honest.
AddEventHandler("onPlayerWeaponChanged", function(raw, _, record, drawn)
    local id = E.playerId(raw)
    local match = id and E.matchOf(id)
    if match == nil or match.def ~= def or match.phase ~= "running" then return end
    local p = match.players[id]
    if p == nil or not p.alive then return end
    -- the kit's own clear / assign / draw while it is delivered: not a wrong weapon
    if GamesCombat.delivering(p) then return end
    if drawn == false or drawn == "false" or drawn == "0" then return end
    if type(record) ~= "string" or not record:find("^Items%.") then return end
    if record == LADDER[p.gg.step].record or record == KNIFE then return end
    local t = E.now()
    local state = p.gg
    if (state.guardAt and t - state.guardAt < GG.guardMs) or (state.armedAt and t - state.armedAt < GG.guardMs) then return end
    state.guardAt = t
    armStep(match, p, t)
end)
