-- op77_turf zone spacing and the /turf.zone resurvey (owner, 2026-11-03: "in Gang Sweep the
-- zones are a bit too close, in Kabuki all three"). Against the fake host (tests/bot_host.lua):
--   every enabled site's zone centres stand at least the spacing floor apart (60 m, a site
--   may state its own, never under 45 m), each zone inside the bounds and clear of the
--   side spawns, zone ids unique; the check itself flags a crowded site and a zone that
--   sticks out of the bounds;
--   /turf.zone is staff only; it lists the zones and their spacing; `set` moves a zone to
--   the caller's feet, keeps it in the KVP, prints the config line and warns when the new
--   centre crowds another zone; refused for the console, outside the bounds and while a
--   sweep runs at the site; `reset` puts the config back and forgets the KVP; a resurvey
--   kept in the KVP is applied at start and shown as such.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test zones_test.lua
local T = dofile("tests/bot_host.lua")
local CFG, R = T.CFG, T.R
local fire, advance = T.fire, T.advance

local function siteOf(id)
    for _, s in ipairs(CFG.sites) do if s.id == id then return s end end
end

local function reply(src, args)
    T.lastReply = nil
    T.command("turf.zone", src, args)
    assert(T.lastReply, "turf.zone answered nothing")
    return T.lastReply.ok, T.lastReply.text
end

local function main()
    local host = T.host

    -- ============================================================ the config holds the rule
    assert(tonumber(CFG.zoneSpacing) and CFG.zoneSpacing >= 60, "the default floor is 60 m")
    local enabled = 0
    for _, site in ipairs(CFG.sites) do
        local floor = R.spacingFloor(site, CFG.zoneSpacing)
        local ok, problems, closest = R.checkZones(site, floor)
        local ids = {}
        for _, z in ipairs(site.zones) do
            assert(not ids[z.id], site.id .. ": zone id " .. z.id .. " twice")
            ids[z.id] = true
        end
        if site.enabled ~= false then
            enabled = enabled + 1
            assert(#site.zones == 3, site.id .. ": three zones")
            assert(floor >= 45, site.id .. ": a floor under 45 m is no spacing at all")
            assert(ok, site.id .. ": " .. table.concat(problems, "; "))
            assert(closest and closest.metres >= floor, site.id .. ": closest pair under the floor")
            for _, side in ipairs(site.spawns) do
                for _, p in ipairs(side.points) do
                    assert(R.inBounds(site.bounds, p), site.id .. ": spawn " .. side.label .. " outside the bounds")
                    for _, z in ipairs(site.zones) do
                        assert(R.flatDistance(p, z) >= 15, ("%s: zone %s sits on spawn %s (%.1f m)"):format(site.id, z.id,
                            side.label, R.flatDistance(p, z)))
                    end
                end
            end
        end
    end
    assert(enabled >= 2, "both voted sites checked")
    local kabuki, badlands = siteOf("kabuki"), siteOf("badlands")
    assert(R.spacingFloor(kabuki, CFG.zoneSpacing) == 60, "Kabuki is held to the full 60 m")
    local _, _, closest = R.checkZones(kabuki, 60)
    assert(closest.metres >= 65, ("Kabuki: closest pair %s-%s %.1f m"):format(closest.a, closest.b, closest.metres))

    -- The check sees a crowded site and a zone outside the bounds (the old Kabuki line).
    local crowded = { id = "x", bounds = { center = { x = 0, y = 0, z = 0 }, radius = 50 }, zones = {
        { id = "A", x = 0, y = 0, z = 0, radius = 6 },
        { id = "B", x = 0, y = 33.9, z = 0, radius = 6 },
        { id = "C", x = 0, y = -48, z = 0, radius = 6 },
    } }
    local ok, problems = R.checkZones(crowded, 60)
    assert(not ok and #problems == 3, "two pairs under the floor and one zone out: " .. table.concat(problems, "; "))
    assert(T.endsWith(problems, "zones A and B are 33.9 m apart") and T.endsWith(problems, "zone C is not inside the bounds"))
    assert(R.spacingFloor({}, nil) == 0 and R.spacingFloor({ zoneSpacing = 45 }, 60) == 45 and R.spacingFloor({}, 60) == 60)

    -- ============================================================ a kept resurvey is applied at start
    T.kvpStore["turf.zone.badlands.B"] = "3000.000,-2400.000,124.000"
    T.kvpStore["turf.zone.badlands.C"] = "not a centre"
    host.threads[1]() -- the registration thread
    local bB, bC = badlands.zones[2], badlands.zones[3]
    assert(bB.x == 3000 and bB.y == -2400 and bB.z == 124, "the kept centre is used")
    assert(bC.x == 2987.544 and bC.y == -2446.255, "a broken KVP value is ignored")
    assert(T.logged("zone badlands B: resurveyed centre %(kvp%)"))
    assert(not T.logged("zone badlands C: resurveyed"))

    -- ============================================================ staff only, listing
    assert(host.commands["turf.zone"] and host.commands["turf.zone"].restricted == true, "staff (ACL command.turf.zone)")
    local listed, text = reply(0, {})
    assert(listed and text:find("kabuki: A%-B 77%.1 m, A%-C 65%.6 m, B%-C 66%.4 m %(floor 60 m%)"), text)
    assert(text:find("badlands: ") and text:find("%(floor 45 m%)") and text:find("afterlife %(staff only%)"), text)
    assert(text:find('{ id = "A", label = "The Stalls", x = %-1228%.750, y = 1983%.250, z = 7%.970, radius = 6%.0 },', 1), text)
    assert(text:find('{ id = "B", label = "Upper Deck", x = 3000%.000, y = %-2400%.000, z = 124%.000, radius = 6%.0 },  %-%- resurveyed %(kvp%)'), text)
    local one, kText = reply(0, { "kabuki" })
    assert(one and kText:find("^kabuki:") and not kText:find("badlands"), kText)

    -- ============================================================ reset
    local reset, rText = reply(0, { "reset", "badlands", "all" })
    assert(reset and rText:find("badlands A,B,C back to the config"), rText)
    assert(bB.x == 3007.488 and bB.y == -2401.259 and bB.z == 124.374, "B is back on its config centre")
    assert(T.kvpStore["turf.zone.badlands.B"] == nil and T.kvpStore["turf.zone.badlands.C"] == nil, "the KVP forgets them")
    assert(not select(2, reply(0, { "badlands" })):find("resurveyed"))
    assert(not reply(0, { "reset", "badlands", "Q" }), "an unknown zone resets nothing")

    -- ============================================================ set
    T.addPlayer(1, "valentinos")
    local kA, kB, kC = kabuki.zones[1], kabuki.zones[2], kabuki.zones[3]
    assert(not reply(0, { "set", "kabuki", "C" }), "the console has no feet")
    assert(select(2, reply(0, { "set", "kabuki", "C" })) == "In game only.")
    assert(not reply(1, { "set", "nowhere", "C" }) and not reply(1, { "set", "kabuki", "Q" }) and not reply(1, { "fly" }))
    T.at(1, 0, 0, 0, 0)
    local out, oText = reply(1, { "set", "kabuki", "C" })
    assert(not out and oText:find("outside Kabuki Market"), oText)
    assert(kC.x == -1220.135, "nothing moved")

    -- A good resurvey: C a few metres east of its config centre, the spacing holds.
    T.at(1, kC.x + 4, kC.y + 1, 7.9, 0)
    local set, sText = reply(1, { "set", "kabuki", "c" })
    assert(set and kC.x == -1216.135 and kC.y == 2049.270 and kC.z == 7.9, "C moved to the caller's feet")
    assert(T.kvpStore["turf.zone.kabuki.C"] == "-1216.135,2049.270,7.900", tostring(T.kvpStore["turf.zone.kabuki.C"]))
    assert(sText:find('^{ id = "C", label = "Lantern Row", x = %-1216%.135, y = 2049%.270, z = 7%.900, radius = 6%.0 },'), sText)
    assert(sText:find("paste into the kabuki site of shared/config.lua %(kept until /turf.zone reset%)") and not sText:find("WARNING"), sText)

    -- A crowding one: B set 10 m from A is kept but warned.
    T.at(1, kA.x + 10, kA.y, kA.z, 0)
    local warned, wText = reply(1, { "set", "kabuki", "B" })
    assert(warned and kB.x == kA.x + 10, "staff decide: the resurvey stands")
    assert(wText:find("WARNING: zones A and B are 10%.0 m apart %(under 60 m%)"), wText)
    assert(T.logged("zone kabuki B resurveyed by 1"))
    reply(0, { "reset", "kabuki", "B" })
    assert(kB.x == -1160.499 and kB.y == 2019.064 and T.kvpStore["turf.zone.kabuki.B"] == nil)
    assert(T.kvpStore["turf.zone.kabuki.C"] ~= nil, "resetting B leaves C's resurvey")
    reply(0, { "reset", "kabuki", "C" })
    assert(kC.x == -1220.135 and kC.y == 2048.270 and kC.z == 7.817, "C back on its config centre")
    assert(next(T.kvpStore) == nil, "the KVP is empty again")
    assert(R.checkZones(kabuki, 60))

    -- ============================================================ refused while a sweep runs there
    fire("op77_lightrp:activity:join", nil, 1, "turf.pve", { site = "kabuki" })
    advance(1250)
    local war = Turf.sweeps[1]
    assert(war and war.kind == "pve" and war.site.id == "kabuki")
    T.at(1, kA.x + 2, kA.y, kA.z, war.bucket)
    local busy, bText = reply(1, { "set", "kabuki", "A" })
    assert(not busy and bText:find("^Sweep %d+ is on at Kabuki Market"), bText)
    assert(kA.x == -1228.750 and T.kvpStore["turf.zone.kabuki.A"] == nil, "a running sweep's zones never move")
    assert(not reply(1, { "reset", "kabuki", "all" }), "nor reset")
    local other = reply(0, { "reset", "badlands", "all" })
    assert(other, "another site stays free")
end

T.run("zones_test", main, "spacing floor per site (Kabuki 60 m, closest 65.6 m; Badlands 45 m), zones in bounds and off "
    .. "the spawns, the check flags a crowded site; /turf.zone staff list, set (KVP, config line, crowding warning), "
    .. "refused for the console / outside the bounds / during a sweep, reset, kept resurvey applied at start")
