-- Clothes as items. The fitting room (open77_wardrobe_ui) offers, after a save,
-- to take the look away: as separate pieces (one `clothing` item per garment
-- the visit added) or as one `outfit` item (the whole look). open77_appearance
-- checks every piece against what the character really wears and hands them
-- here (server event open77:presentation:takeAway); this module puts them in the
-- bag in one write. A garment is either in the bag or worn, never both: using
-- a piece puts it on (its item leaves the bag, the piece it replaces comes
-- back); using an outfit lays it under the clothes (see "The outfit layer");
-- the inventory's Worn column takes a piece off into the bag. Dressing goes
-- through open77_appearance's persisted commit (export applyLook), like a save
-- in the fitting room.
local Clothing = LightRP.module("clothing", {})

local SLOTS = { "Head", "Face", "InnerChest", "OuterChest", "Legs", "Feet", "Outfit" }
local SLOT_NAMES = { Head = "headwear", Face = "eyewear", InnerChest = "top", OuterChest = "jacket", Legs = "bottoms", Feet = "footwear", Outfit = "full-body outfit" }
local ICON_ROOT = "open77://open77_wardrobe_ui/web/"
-- The icon a whole outfit shows: its most visible piece.
local COVER = { "OuterChest", "Outfit", "InnerChest", "Legs", "Head", "Feet", "Face" }

local pending = {} -- playerId -> { label, at } while a dressing commit runs
-- Our own changes the appearance resource has yet to announce as committed. The
-- `committed` event of a change can arrive after its `lookApplied` answer (the
-- two are separate events), so `pending` alone cannot tell ours from a look
-- saved elsewhere: each successful applyLook announces exactly one commit.
local ownCommits = {} -- playerId -> { n, at }
local function expectCommit(playerId, delta)
    local entry = ownCommits[playerId]
    if entry and LightRP.nowMs() - entry.at > 15000 then entry = nil end
    local n = math.max(0, (entry and entry.n or 0) + delta)
    ownCommits[playerId] = n > 0 and { n = n, at = LightRP.nowMs() } or nil
end
local function family(value) return value == "male" and "male" or "female" end
local function imageOf(icon) return type(icon) == "string" and (ICON_ROOT .. icon) or nil end
local function notice(playerId, kind, body)
    pcall(LightRP.notice, playerId, { kind = kind, title = "Clothes", body = body, durationMs = 5000 })
end
local function appearance() return exports.open77_appearance end

-- ---------------------------------------------------------------------------
-- Take-away: the checked look becomes items.

local function itemsFor(look)
    local items, fam = {}, family(look.family)
    if look.mode == "outfit" then
        local pieces, labels, cover = {}, {}, nil
        for _, piece in ipairs(look.pieces) do pieces[piece.slot], labels[piece.slot] = piece.record, piece.label end
        for _, slot in ipairs(COVER) do
            for _, piece in ipairs(look.pieces) do if piece.slot == slot and piece.icon and not cover then cover = piece.icon end end
        end
        items[1] = { name = "outfit", count = 1, metadata = { label = look.name, pieces = pieces, labels = labels, family = fam, image = imageOf(cover) } }
    else
        for _, piece in ipairs(look.pieces) do
            items[#items + 1] = { name = "clothing", count = 1, metadata = { label = piece.label, record = piece.record,
                slot = piece.slot, family = fam, image = imageOf(piece.icon) } }
        end
    end
    return items
end

AddEventHandler("open77:presentation:takeAway", function(playerId, look)
    playerId = tonumber(playerId)
    local inv = playerId and LightRP.inventory.playerId(playerId)
    local function answer(ok, text) pcall(function() appearance():takeAwayResult(playerId, ok, text) end) end
    if not inv or type(look) ~= "table" or type(look.pieces) ~= "table" or #look.pieces == 0 then
        answer(false, "Your bag is not available right now."); return
    end
    local items = itemsFor(look)
    local ok, reason = LightRP.inventory.addItems(inv, items)
    if not ok then
        answer(false, reason == "too_heavy" and "Your bag is too heavy for these clothes. Make room and try again."
            or reason == "no_room" and "Your bag is full. Make room and try again." or "These clothes could not be added to your bag.")
        return
    end
    LightRP.log("clothing: %s took %d item(s) (%s)", LightRP.characters.displayName(playerId), #items, look.mode)
    answer(true, look.mode == "outfit" and string.format("“%s” is in your bag. Use it to change into it.", look.name)
        or string.format("%d piece%s in your bag. Use one to put it on.", #items, #items == 1 and "" or "s"))
end)

-- ---------------------------------------------------------------------------
-- Dressing from the bag.

local function wearing(playerId)
    local ok, shown = pcall(function() return appearance():visibleOutfit(playerId) end)
    if not ok or type(shown) ~= "table" then
        LightRP.log("clothing: no visible outfit for %s (%s)", tostring(playerId), ok and type(shown) or tostring(shown))
        return nil
    end
    local look, active = {}, shown.wardrobe and shown.wardrobe.active
    local over = active ~= nil and active ~= false and shown.wardrobe.outfits and shown.wardrobe.outfits[tostring(active)] or nil
    for _, slot in ipairs(SLOTS) do
        local value
        if over and over[slot] ~= nil then value = over[slot] else value = shown.equipment and shown.equipment[slot] end
        look[slot] = value or false
    end
    return look
end

-- ---------------------------------------------------------------------------
-- A garment moves between the bag and the body, never both: putting a piece on
-- uses up its item and hands back what it replaces; taking one off puts it in
-- the bag. The bag's room is checked before the change; a refused change gives
-- the used item back. Names and art follow the fitting room: the record's title
-- and its icon, open77_wardrobe_ui/web/icons/<m|f>/<first 16 hex of SHA-256(record)>.webp.

local K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}
local M32 = 0xffffffff
local function rotr(x, n) return ((x >> n) | (x << (32 - n))) & M32 end
local hashes = {}
local function sha256(text)
    if hashes[text] then return hashes[text] end
    local bytes = { string.byte(text, 1, -1) }
    local bits = #bytes * 8
    bytes[#bytes + 1] = 0x80
    while #bytes % 64 ~= 56 do bytes[#bytes + 1] = 0 end
    for i = 7, 0, -1 do bytes[#bytes + 1] = (bits >> (i * 8)) & 0xff end
    local h = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }
    for chunk = 1, #bytes, 64 do
        local w = {}
        for i = 0, 15 do
            local b = chunk + i * 4
            w[i] = (bytes[b] << 24) | (bytes[b + 1] << 16) | (bytes[b + 2] << 8) | bytes[b + 3]
        end
        for i = 16, 63 do
            local s0 = rotr(w[i - 15], 7) ~ rotr(w[i - 15], 18) ~ (w[i - 15] >> 3)
            local s1 = rotr(w[i - 2], 17) ~ rotr(w[i - 2], 19) ~ (w[i - 2] >> 10)
            w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & M32
        end
        local a, b, c, d, e, f, g, hh = h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8]
        for i = 0, 63 do
            local t1 = (hh + (rotr(e, 6) ~ rotr(e, 11) ~ rotr(e, 25)) + ((e & f) ~ ((~e) & M32 & g)) + K[i + 1] + w[i]) & M32
            local t2 = ((rotr(a, 2) ~ rotr(a, 13) ~ rotr(a, 22)) + ((a & b) ~ (a & c) ~ (b & c))) & M32
            hh, g, f, e, d, c, b, a = g, f, e, (d + t1) & M32, c, b, a, (t1 + t2) & M32
        end
        h[1], h[2], h[3], h[4] = (h[1] + a) & M32, (h[2] + b) & M32, (h[3] + c) & M32, (h[4] + d) & M32
        h[5], h[6], h[7], h[8] = (h[5] + e) & M32, (h[6] + f) & M32, (h[7] + g) & M32, (h[8] + hh) & M32
    end
    local hex = string.format("%08x%08x%08x%08x%08x%08x%08x%08x", table.unpack(h))
    hashes[text] = hex
    return hex
end
Clothing.sha256 = sha256

local function titleOf(record)
    return (record:gsub("^Items%.", ""):gsub("(%l)(%u)", "%1 %2"):gsub("_", " "):gsub("%f[%a][Bb]asic%f[%A]", "Classic"))
end
-- A worn garment as a bag item.
local function garmentItem(playerId, slot, record)
    local c = LightRP.characters.get(playerId)
    local fam = family(c and c.bodyFamily)
    return { name = "clothing", count = 1, metadata = { label = titleOf(record), record = record, slot = slot, family = fam,
        image = imageOf("icons/" .. (fam == "male" and "m" or "f") .. "/" .. sha256(record):sub(1, 16) .. ".webp") } }
end
Clothing.garmentItem = garmentItem

local function slotOf(inv, item)
    for slot, other in pairs(inv.items) do if other == item then return slot end end
end

-- ---------------------------------------------------------------------------
-- The outfit layer. A worn outfit item lies under the clothes as one layer:
-- its pieces show in every slot, a piece put on over it replaces only its own
-- slot (an override), taking that piece off shows the outfit's again, and an
-- outfit piece can be hidden (override false) and shown again. Taking the
-- outfit off returns the whole item to the bag; the pieces worn over it stay.
-- The layer is saved per character (an outfit item worn is never lost to a
-- restart). A change made elsewhere (the fitting room) ends the layer: what
-- the character wears then is plain clothes, the outfit item is not returned.

local layers = {} -- playerId -> { item = outfit metadata, overrides = { slot = record | false } }
local Db = LightRP.db
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_outfit_layers (
    identifier VARCHAR(128) NOT NULL, character_key VARCHAR(64) NOT NULL, layer TEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier, character_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local function owner(playerId)
    local c = LightRP.characters.get(playerId)
    if c and c.status == "active" and c.identifier then return c.identifier, c.key end
end
local function saveLayer(playerId)
    local identifier, key = owner(playerId)
    if not identifier or not Db.ready then return end
    local layer = layers[playerId]
    if layer then
        Db.run("INSERT INTO lightrp_outfit_layers (identifier, character_key, layer) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE layer = VALUES(layer)",
            { identifier, key, json.encode(layer) })
    else
        Db.run("DELETE FROM lightrp_outfit_layers WHERE identifier = ? AND character_key = ?", { identifier, key })
    end
end
local function loadLayer(playerId)
    layers[playerId] = nil
    local identifier, key = owner(playerId)
    if not identifier then return end
    local row = Db.single("SELECT layer FROM lightrp_outfit_layers WHERE identifier = ? AND character_key = ?", { identifier, key })
    local ok, layer = pcall(function() return row and json.decode(row.layer) end)
    if ok and type(layer) == "table" and type(layer.item) == "table" and type(layer.item.pieces) == "table" then
        layer.overrides = type(layer.overrides) == "table" and layer.overrides or {}
        layers[playerId] = layer
    end
end
function Clothing.onCharacterActivated(playerId) loadLayer(playerId) end
function Clothing.onCharacterLoaded(playerId) loadLayer(playerId) end
function Clothing.onDatabaseReady() for _, id in ipairs(GetPlayers()) do loadLayer(tonumber(id)) end end

local function copyLayer(layer)
    if not layer then return nil end
    local overrides = {}
    for slot, value in pairs(layer.overrides) do overrides[slot] = value end
    return { item = layer.item, overrides = overrides }
end
-- What a layer shows: the override where there is one, else the outfit's piece.
local function layerLook(layer)
    local equipment = {}
    for _, slot in ipairs(SLOTS) do
        local over = layer.overrides[slot]
        if over ~= nil then equipment[slot] = over
        else equipment[slot] = type(layer.item.pieces[slot]) == "string" and layer.item.pieces[slot] or false end
    end
    -- a piece over the outfit shows only once the outfit's full-body suit stops covering it
    local covered = false
    for _, slot in ipairs(SLOTS) do if slot ~= "Outfit" and type(layer.overrides[slot]) == "string" then covered = true end end
    if covered and layer.overrides.Outfit == nil then equipment.Outfit = false end
    return equipment
end
local function outfitItem(layer) return { name = "outfit", count = 1, metadata = layer.item } end

-- Start a change. `swap.returned` come back to the bag once it shows, `swap.back`
-- (the item used up) returns if it is refused, `swap.layer` (a layer, or false
-- for none) becomes the character's once it shows. "keep" when nothing is used up.
local function dress(playerId, equipment, label, swap)
    if pending[playerId] and LightRP.nowMs() - pending[playerId].at < 10000 then
        notice(playerId, "warning", "Still changing. One moment."); return false
    end
    swap = swap or {}
    -- Recorded before asking: the change can be applied (and answered) inside the call.
    local job = { label = label, at = LightRP.nowMs(), returned = swap.returned or {}, back = swap.back, layer = swap.layer }
    pending[playerId] = job
    local ok, queued, reason = pcall(function() return appearance():applyLook(playerId, equipment, "lightrp") end)
    if not ok or not queued then
        if pending[playerId] == job then pending[playerId] = nil end
        notice(playerId, "error", reason == "temporary_outfit_active" and "You cannot change clothes right now."
            or "Your clothes could not be changed right now.")
        return false
    end
    expectCommit(playerId, 1)
    if swap.back then return true, "Changing clothes…" end
    return "keep", "Changing clothes…"
end

-- Room in the bag for what comes back, the used item (if any) leaving its slot.
local function roomFor(playerId, item, returned)
    local invId = LightRP.inventory.playerId(playerId)
    local inv = invId and LightRP.inventory.get(invId)
    if not inv then return false end
    if #returned == 0 then return true end
    local ok, why = LightRP.inventory.canSwap(invId, item and slotOf(inv, item), returned)
    if not ok then
        notice(playerId, "warning", why == "too_heavy" and "Your bag is too heavy for the clothes you take off. Make room first."
            or "Your bag is full: make room for the clothes you take off.")
    end
    return ok
end

LightRP.inventory.onUse("clothing", function(playerId, item)
    local m = type(item.metadata) == "table" and item.metadata or {}
    if type(m.record) ~= "string" or type(m.slot) ~= "string" or not SLOT_NAMES[m.slot] then return false end
    local now = wearing(playerId)
    if not now then notice(playerId, "error", "Your clothes are still loading."); return false end
    local back = { name = "clothing", count = 1, metadata = m }
    local layer = layers[playerId]
    if layer then
        -- Over the outfit: only this slot changes; a piece already over it comes back.
        local returned, next = {}, copyLayer(layer)
        local prev = layer.overrides[m.slot]
        if type(prev) == "string" then returned[1] = garmentItem(playerId, m.slot, prev) end
        next.overrides[m.slot] = m.record
        if not roomFor(playerId, item, returned) then return false end
        return dress(playerId, layerLook(next), "Put on " .. (m.label or SLOT_NAMES[m.slot]), { returned = returned, back = back, layer = next })
    end
    local equipment, returned = {}, {}
    for _, slot in ipairs(SLOTS) do equipment[slot] = now[slot] end
    equipment[m.slot] = m.record
    if type(now[m.slot]) == "string" then returned[#returned + 1] = garmentItem(playerId, m.slot, now[m.slot]) end
    -- A piece shows only once a full-body outfit stops covering it: the suit comes off too.
    if m.slot ~= "Outfit" and type(now.Outfit) == "string" then
        equipment.Outfit = false
        returned[#returned + 1] = garmentItem(playerId, "Outfit", now.Outfit)
    end
    if not roomFor(playerId, item, returned) then return false end
    return dress(playerId, equipment, "Put on " .. (m.label or SLOT_NAMES[m.slot]), { returned = returned, back = back })
end)

LightRP.inventory.onUse("outfit", function(playerId, item)
    local m = type(item.metadata) == "table" and item.metadata or {}
    if type(m.pieces) ~= "table" then return false end
    local any = false
    for _, slot in ipairs(SLOTS) do if type(m.pieces[slot]) == "string" then any = true end end
    if not any then return false end
    local now = wearing(playerId)
    if not now then notice(playerId, "error", "Your clothes are still loading."); return false end
    -- Changing into an outfit: the clothes worn (and an outfit worn before) go to the bag.
    local returned, layer = {}, layers[playerId]
    if layer then
        returned[1] = outfitItem(layer)
        for _, slot in ipairs(SLOTS) do
            if type(layer.overrides[slot]) == "string" then returned[#returned + 1] = garmentItem(playerId, slot, layer.overrides[slot]) end
        end
    else
        for _, slot in ipairs(SLOTS) do
            if type(now[slot]) == "string" then returned[#returned + 1] = garmentItem(playerId, slot, now[slot]) end
        end
    end
    local next = { item = m, overrides = {} }
    if not roomFor(playerId, item, returned) then return false end
    return dress(playerId, layerLook(next), "Changed into “" .. tostring(m.label or "your outfit") .. "”",
        { returned = returned, back = { name = "outfit", count = 1, metadata = m }, layer = next })
end)

AddEventHandler("open77:presentation:lookApplied", function(playerId, token, ok, reason)
    playerId = tonumber(playerId)
    local job = playerId and pending[playerId]
    if token ~= "lightrp" or not job then return end
    if not ok then
        expectCommit(playerId, -1) -- refused: no commit will be announced
        LightRP.log("clothing: change refused for %s: %s (%s)", LightRP.characters.displayName(playerId), job.label, tostring(reason))
    end
    pending[playerId] = nil
    local invId = LightRP.inventory.playerId(playerId)
    if ok then
        if job.layer ~= nil then
            layers[playerId] = job.layer or nil; saveLayer(playerId)
            LightRP.log("clothing: %s: %s (outfit layer %s)", LightRP.characters.displayName(playerId), job.label,
                job.layer and string.format("%q", tostring(job.layer.item.label)) or "off")
        end
        if #job.returned > 0 then
            local added, why = false, "no_inventory"
            if invId then added, why = LightRP.inventory.addItems(invId, job.returned) end
            if not added then LightRP.log("clothing: %d garment(s) could not return to the bag of %s (%s)", #job.returned, tostring(playerId), tostring(why)) end
        end
        notice(playerId, "success", job.label .. ".")
    else
        if job.back and invId then LightRP.inventory.addItems(invId, { job.back }) end
        notice(playerId, "error", reason == "invalid_equipment" and "These clothes do not fit your body."
            or "Your clothes could not be changed. Nothing was lost.")
    end
end)

function Clothing.onDisconnected(playerId) pending[playerId], layers[playerId], ownCommits[playerId] = nil, nil, nil end

-- ---------------------------------------------------------------------------
-- What the character wears, for the inventory's Worn column: per slot the
-- record that shows (or false) and where it comes from (`piece`, `outfit` for
-- the outfit's own, `over` for a piece over the outfit, `hidden` for an outfit
-- piece hidden), the outfit worn (label, art), and the body family for the art.

local function wornState(playerId)
    local look = wearing(playerId)
    local c = LightRP.characters.get(playerId)
    if not look then return { ready = false, slots = {} } end
    local layer, sources, hidden = layers[playerId], {}, {}
    for _, slot in ipairs(SLOTS) do
        if not layer then sources[slot] = look[slot] and "piece" or nil
        else
            local over = layer.overrides[slot]
            if type(over) == "string" then sources[slot] = "over"
            elseif over == false and type(layer.item.pieces[slot]) == "string" then sources[slot], hidden[slot] = "hidden", layer.item.pieces[slot]
            elseif look[slot] then sources[slot] = "outfit" end
        end
    end
    return { ready = true, family = c and c.bodyFamily == "male" and "m" or "f", slots = look, sources = sources, hidden = hidden,
        outfit = layer and { label = layer.item.label or "Outfit", image = layer.item.image } or nil, changing = pending[playerId] ~= nil }
end
LightRP.stateProvider("worn", wornState)
local function pushWorn(playerId) LightRP.state(playerId, { "worn" }) end
Clothing.pushWorn = pushWorn

AddEventHandler("open77:presentation:committed", function(playerId)
    playerId = tonumber(playerId)
    if not playerId then return end
    -- Not ours (the fitting room saved a look): the layer ends, what shows is plain clothes.
    local ours = ownCommits[playerId] ~= nil
    if ours then expectCommit(playerId, -1) end
    if not ours and not pending[playerId] and layers[playerId] then
        layers[playerId] = nil; saveLayer(playerId)
        LightRP.log("clothing: outfit layer of %s ended by a look saved elsewhere", LightRP.characters.displayName(playerId))
        notice(playerId, "info", "Your outfit is now worn as separate pieces.")
    end
    pushWorn(playerId)
end)
AddEventHandler("open77:presentation:lookApplied", function(playerId) playerId = tonumber(playerId); if playerId then pushWorn(playerId) end end)

LightRP.action("clothing.refresh", function(playerId) pushWorn(playerId) end)

-- Take off (Worn column): a piece goes to the bag; over an outfit the outfit's
-- piece shows again; an outfit's own piece is hidden; the Outfit slot of a
-- worn outfit returns the whole outfit item (the pieces over it stay on).
LightRP.action("clothing.takeOff", function(playerId, payload)
    local slot = type(payload) == "table" and payload.slot
    local function refuse(text) LightRP.result(playerId, false, text, "inventory.takeOff") end
    if type(slot) ~= "string" or not SLOT_NAMES[slot] then return refuse("Nothing to take off there.") end
    local look = wearing(playerId)
    if not look then return refuse("Your clothes are still loading.") end
    if pending[playerId] and LightRP.nowMs() - pending[playerId].at < 10000 then return refuse("Still changing. One moment.") end
    local layer = layers[playerId]
    local equipment, returned, next, label = nil, {}, nil, nil
    if layer and slot == "Outfit" and payload.whole ~= false then
        returned[1] = outfitItem(layer)
        equipment = {}
        for _, s in ipairs(SLOTS) do equipment[s] = type(layer.overrides[s]) == "string" and layer.overrides[s] or false end
        next, label = false, "Took off “" .. tostring(layer.item.label or "your outfit") .. "”"
    elseif layer and type(layer.overrides[slot]) == "string" then
        returned[1] = garmentItem(playerId, slot, layer.overrides[slot])
        next = copyLayer(layer); next.overrides[slot] = nil
        equipment, label = layerLook(next), "Took off " .. returned[1].metadata.label
    elseif layer and layer.overrides[slot] == nil and type(layer.item.pieces[slot]) == "string" then
        next = copyLayer(layer); next.overrides[slot] = false
        equipment, label = layerLook(next), "Hid the " .. SLOT_NAMES[slot] .. " of your outfit"
    else
        local record = look[slot]
        if type(record) ~= "string" then return refuse("You wear nothing there.") end
        returned[1] = garmentItem(playerId, slot, record)
        equipment = {}
        for _, s in ipairs(SLOTS) do equipment[s] = look[s] end
        equipment[slot] = false
        label = "Took off " .. returned[1].metadata.label
    end
    if not roomFor(playerId, nil, returned) then return refuse("Your bag is full. Make room to take this off.") end
    local queued = dress(playerId, equipment, label, { returned = returned, layer = next })
    pushWorn(playerId)
    LightRP.result(playerId, queued ~= false, queued and "Changing clothes…" or "Your clothes could not be changed right now.", "inventory.takeOff")
end)

-- Everything worn becomes one outfit (no outfit worn yet): nothing changes on
-- the body and no item is made; the pieces now belong to the outfit, which
-- goes to the bag whole when the Outfit slot is taken off.
LightRP.action("clothing.makeOutfit", function(playerId, payload)
    local function answer(ok, text) LightRP.result(playerId, ok, text, "inventory.makeOutfit") end
    if layers[playerId] then return answer(false, "You already wear an outfit. Take it off first.") end
    if pending[playerId] and LightRP.nowMs() - pending[playerId].at < 10000 then return answer(false, "Still changing. One moment.") end
    local look = wearing(playerId)
    if not look then return answer(false, "Your clothes are still loading.") end
    local c = LightRP.characters.get(playerId)
    local fam = family(c and c.bodyFamily)
    local pieces, labels, count, cover = {}, {}, 0, nil
    for _, slot in ipairs(SLOTS) do
        if type(look[slot]) == "string" then pieces[slot], labels[slot], count = look[slot], titleOf(look[slot]), count + 1 end
    end
    if count == 0 then return answer(false, "You wear nothing to make an outfit of.") end
    for _, slot in ipairs(COVER) do if not cover and pieces[slot] then cover = pieces[slot] end end
    local name = type(payload) == "table" and type(payload.name) == "string" and payload.name:gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 40) or ""
    if name == "" then name = "My outfit" end
    layers[playerId] = { overrides = {}, item = { label = name, pieces = pieces, labels = labels, family = fam,
        image = imageOf("icons/" .. (fam == "male" and "m" or "f") .. "/" .. sha256(cover):sub(1, 16) .. ".webp") } }
    saveLayer(playerId)
    pushWorn(playerId)
    LightRP.log("clothing: %s made the outfit %q of %d piece(s)", LightRP.characters.displayName(playerId), name, count)
    answer(true, string.format("“%s” is your outfit now: take it off from the Outfit slot to fold it into your bag.", name))
end)

-- Show again an outfit piece that was hidden.
LightRP.action("clothing.show", function(playerId, payload)
    local slot = type(payload) == "table" and payload.slot
    local layer = layers[playerId]
    if type(slot) ~= "string" or not layer or layer.overrides[slot] ~= false then
        return LightRP.result(playerId, false, "Nothing hidden there.", "inventory.show")
    end
    local next = copyLayer(layer); next.overrides[slot] = nil
    local queued = dress(playerId, layerLook(next), "Showed the " .. SLOT_NAMES[slot] .. " of your outfit", { layer = next })
    LightRP.result(playerId, queued ~= false, queued and "Changing clothes…" or "Your clothes could not be changed right now.", "inventory.show")
end)
