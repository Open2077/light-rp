-- Safe-zone tile on NativeUI: the drop-in replacement of client/core/safezone_tile.lua and of
-- its page (web/safezone/). Load one or the other, never both (same global, same behaviour).
--
-- A small green holographic tile on the voice plate's top-left corner (the bottom-right
-- cluster with op77_speedometer and open-voice). Entering a zone, a label unfolds out of it
-- ("SAFE ZONE" and what the zone enforces) and folds back after a moment; leaving, an amber
-- "LEAVING SAFE ZONE" unfolds and the tile goes. The zone comes from
-- client/core/safezones.lua (the server's presence); the hint lists the rules of
-- shared/safezones.lua that the zone applies, nothing else.
--
-- What the page's app.js did with timers and CSS animations is one thread here per
-- sequence (enter / leave), which sets classes and texts on ui/native/safezone_tile.rml.
local N = LightRpNative
local Ui = LightRpUi
local Tile = { page = nil, ready = false, sent = nil, shownOnce = false }
LightRpSafezoneTile = Tile

-- What each blocked rule means for the player (keys of LightRpSafezoneGeometry.RULES).
local RULE_TEXT = {
    blockShoot = "No shooting", blockRun = "Walk only", blockJump = "No jumping", blockMelee = "No melee",
    blockGrenades = "No grenades", blockConsumables = "No healing items", blockReload = "No reload",
    blockWeaponWheel = "No weapon wheel",
}
local MAX_PARTS = 3

-- "No PvP · No shooting · Walk only +2": PvP is always refused inside a zone (the server's
-- damage arbiter); the rest is what this zone blocks, defaults included.
function Tile.hint(zone)
    local parts = { "No PvP" }
    local more = 0
    local rules = LightRpSafezoneGeometry and LightRpSafezoneGeometry.RULES or {}
    for _, rule in ipairs(rules) do
        local blocked = type(zone) == "table" and zone[rule.key]
        if blocked == nil then blocked = rule.default end
        if blocked == true and RULE_TEXT[rule.key] then
            if #parts < MAX_PARTS then parts[#parts + 1] = RULE_TEXT[rule.key] else more = more + 1 end
        end
    end
    return table.concat(parts, " · ") .. (more > 0 and (" +" .. more) or "")
end

-- Inside a zone right now, as the controls see it (safezones.lua syncControls): a zone in
-- the presence, a character in the world, alive.
function Tile.current()
    if not (LightRpSafezones and LightRpSafezones.presenceZone) then return nil end
    local zone = LightRpSafezones.presenceZone()
    if type(zone) ~= "table" or not Ui.characterReady or Ui.creationActive then return nil end
    local ok, body = pcall(Open77.character.state)
    if not ok or type(body) ~= "table" or not body.alive or not body.attached then return nil end
    return zone
end

-- ---- the document's sequences (web/safezone/app.js) ------------------------------------
local HOLD_MS, LEAVE_HOLD_MS, FOLD_MS, GO_MS = 2600, 1500, 300, 320
-- the page's glyphs were "█▓▒░<>/\#%&*+=-_": the block glyphs are not in Chakra Petch
local GLYPHS = "<>/\\#%&*+=-_"
local doc
local inside, live = false, false
local token = 0

local function codepoints(s)
    local out = {}
    for ch in tostring(s):gmatch("[\0-\127\194-\253][\128-\191]*") do out[#out + 1] = ch end
    return out
end

-- cubic-bezier(x1, y1, x2, y2) at x
local function bezier(x1, y1, x2, y2, x)
    local t = x
    for _ = 1, 6 do
        local u = 1 - t
        local fx = 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t - x
        local dx = 3 * u * u * x1 + 6 * u * t * (x2 - x1) + 3 * t * t * (1 - x2)
        if math.abs(dx) < 1e-5 then break end
        t = math.max(0, math.min(1, t - fx / dx))
    end
    local u = 1 - t
    return 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t
end

-- "SAFE ZONE" resolving out of glyphs, left to right
local function decoded(text, k)
    local fixed = math.floor(#text * math.min(1, k))
    local out = { text:sub(1, fixed) }
    for i = fixed + 1, #text do
        local ch = text:sub(i, i)
        if ch == " " then out[#out + 1] = " " else
            local g = math.random(#GLYPHS)
            out[#out + 1] = GLYPHS:sub(g, g)
        end
    end
    return table.concat(out)
end
Tile.decoded = decoded

-- zt-pop 420ms steps(7, end): scale, opacity, brightness held at each seventh
local POP = {
    [0] = { 0.2, 0, 3 }, { 0.588, 0.408, 2.35 }, { 0.975, 0.816, 1.7 }, { 1.132, 1, 1.05 },
    { 1.099, 1, 0.64 }, { 1.066, 1, 1.57 }, { 1.033, 1, 1.46 },
}
local function tileStyle(sx, sy, opacity, brightness)
    doc:style("#zone-tile", { transform = ("scale(%.3f, %.3f)"):format(sx, sy), opacity = ("%.3f"):format(opacity),
        filter = ("brightness(%.2f)"):format(brightness) })
end
local function tileRest() -- back to the sheet: is-shown decides
    doc:style("#zone-tile", "transform", nil)
    doc:style("#zone-tile", "opacity", nil)
    doc:style("#zone-tile", "filter", nil)
end

local function setText(cache, sel, value)
    if cache[sel] == value then return end
    cache[sel] = value
    doc:text(sel, value)
end

local function classes(set)
    doc:batch(function() for name, on in pairs(set) do doc:class("#zone", name, on) end end)
end

local function enter(p, instant)
    token = token + 1
    local mine = token
    inside, live = true, true
    doc:batch(function()
        doc:class("#zone", "is-leaving", false)
        doc:class("#zone", "is-open", false)
        doc:class("#zone", "is-label", false)
        doc:class("#zone", "is-live", true)
        doc:class("#zone", "is-shown", true)
        tileRest()
    end)
    if instant then return end
    local hint = codepoints(p.hint or "")
    tileStyle(POP[0][1], POP[0][1], POP[0][2], POP[0][3])
    local t0 = N.now()
    CreateThread(function()
        local cache, pop, opened, typed = {}, 0, false, -1
        while token == mine do
            local t = N.now() - t0
            -- the tile pops
            local k = t >= 420 and 7 or math.floor(t / 60)
            if k ~= pop then
                pop = k
                if k >= 7 then tileRest() else tileStyle(POP[k][1], POP[k][1], POP[k][2], POP[k][3]) end
            end
            if t >= 220 + HOLD_MS then
                doc:class("#zone", "is-open", false) -- it folds back into the tile
                Wait(FOLD_MS)
                if token == mine then doc:class("#zone", "is-label", false) end
                break
            end
            if t >= 220 then
                if not opened then
                    opened = true
                    doc:batch(function()
                        doc:text("#zone-hint", "")
                        doc:class("#zone-hint", "hide", #hint == 0)
                        doc:class("#zone", "is-label", true)
                        doc:class("#zone", "is-open", true)
                    end)
                end
                local u = t - 220
                setText(cache, "#zone-title", u >= 420 and "SAFE ZONE" or decoded("SAFE ZONE", u / 420))
                local count = u < 260 and 0 or math.min(#hint, math.floor((u - 260) / 22) + 1)
                if count ~= typed then typed = count; doc:text("#zone-hint", table.concat(hint, "", 1, count)) end
                if u >= 420 and count >= #hint then Wait(50) else Wait(0) end
            else
                Wait(0)
            end
        end
    end)
end

local function leave(instant)
    token = token + 1
    local mine = token
    if not inside and not live then return end
    inside = false
    if instant then
        live = false
        doc:batch(function()
            for _, name in ipairs({ "is-live", "is-shown", "is-open", "is-label", "is-leaving" }) do doc:class("#zone", name, false) end
            tileRest()
        end)
        return
    end
    local hint = codepoints("Protection off")
    doc:batch(function()
        tileRest()
        doc:text("#zone-hint", "")
        doc:class("#zone-hint", "hide", false)
        doc:class("#zone", "is-leaving", true)
        doc:class("#zone", "is-label", true)
        doc:class("#zone", "is-open", true)
    end)
    CreateThread(function()
        local t0 = N.now()
        local cache, typed, folded = {}, -1, false
        while token == mine do
            local t = N.now() - t0
            if t >= LEAVE_HOLD_MS + FOLD_MS + GO_MS then
                live = false
                classes({ ["is-live"] = false, ["is-shown"] = false, ["is-leaving"] = false, ["is-open"] = false, ["is-label"] = false })
                tileRest()
                break
            end
            if t >= LEAVE_HOLD_MS + FOLD_MS then
                if folded ~= "gone" then folded = "gone"; doc:class("#zone", "is-label", false) end
                -- zt-out 300ms cubic-bezier(.6, 0, .9, .4): flattened to a line, then gone
                local k = math.min(1, (t - LEAVE_HOLD_MS - FOLD_MS) / 300)
                if k < 0.4 then
                    local e = bezier(0.6, 0, 0.9, 0.4, k / 0.4)
                    tileStyle(1 + 0.1 * e, 1 - 0.92 * e, 1, 1 + 1.5 * e)
                else
                    local e = bezier(0.6, 0, 0.9, 0.4, (k - 0.4) / 0.6)
                    tileStyle(1.1 * (1 - e), 0.08 - 0.04 * e, 1 - e, 2.5 - 1.5 * e)
                end
                Wait(0)
            elseif t >= LEAVE_HOLD_MS then
                if not folded then folded = true; doc:class("#zone", "is-open", false) end
                Wait(0)
            else
                setText(cache, "#zone-title", t >= 360 and "LEAVING SAFE ZONE" or decoded("LEAVING SAFE ZONE", t / 360))
                local count = t < 200 and 0 or math.min(#hint, math.floor((t - 200) / 22) + 1)
                if count ~= typed then typed = count; doc:text("#zone-hint", table.concat(hint, "", 1, count)) end
                if t >= 360 and count >= #hint then Wait(50) else Wait(0) end
            end
        end
    end)
end

-- { inside, label?, hint?, instant? }: the page's "zone:state"
local function state(p)
    if type(p) ~= "table" or not doc then return end
    if p.inside then
        if not inside or p.instant then enter(p, p.instant == true) end
    else
        leave(p.instant == true)
    end
end

function Tile.sync(instant)
    if not (Tile.page and Tile.ready) then return end
    local zone = Tile.current()
    local s = zone and { inside = true, label = tostring(zone.label or ""), hint = Tile.hint(zone) } or { inside = false }
    local key = s.inside and (s.label .. "|" .. s.hint) or "out"
    if key == Tile.sent then return end
    Tile.sent = key
    s.instant = instant == true
    if s.inside then Tile.shownOnce = true end
    Tile.last = s -- what the document was last told ({ inside, label, hint, instant })
    state(s)
end

-- The place: the voice plate's top-left corner (dp of a 1080-high screen, from the
-- bottom-right corner); ui/native/safezone_tile.rcss holds the same numbers.
Tile.PLACE = { right = 386, bottom = 101, labelMax = 157 }

N.onStart(function()
    doc = N.create({ document = "ui/native/safezone_tile.rml", zIndex = 13 })
    if not doc then Ui.log("safe-zone tile unavailable: %s", "NativeUI") return end
    Tile.page = doc
    local function ready()
        token = token + 1 -- a sequence of the previous document is over
        inside, live = false, false
        Tile.ready = true
        Tile.sent = nil
        doc:class("#root", "is-covered", N.shell.hidden == true)
        -- a document reload replays the state without the animation; the first one teaches it
        Tile.sync(Tile.shownOnce)
    end
    doc:onEvent("reloaded", ready)
    ready()
end)

-- NativeUI draws above every page: under a menu, a dialog or anything holding the cursor
-- the tile steps aside with the rest of the HUD (the voice plate does the same).
N.onShell(function(shell)
    if doc then doc:class("#root", "is-covered", shell.hidden == true) end
end)

AddEventHandler("onClientResourceStart", function(name)
    if name ~= GetCurrentResourceName() then return end
    CreateThread(function()
        while true do
            Tile.sync(false)
            Wait(250)
        end
    end)
end)
