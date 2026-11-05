-- The 3D duel table: playmats, the table slots of NEON DECK (the Kabuki TCG shop), and where every game zone sits
-- on a playmat. Shared: the server places the props and seats the players, the client draws prompts and the camera.
-- The meshes come from the NEON DECK world resource (neon_deck, NCWE project E:/Open77/Maps/TCGShop); the table props
-- (card back, deck stack, dice) were added to it for op77_tcg (tools/tcg_table_blender.py there).
TcgTable = {}

-- Playmats: the shop's six printed mats (610 x 355 mm, the official zone layout). `image` is the binder preview.
TcgTable.playmats = {
    { id = "netrunner", label = "Netrunner", mesh = "ncwe\\custom\\nd_p3_mat_netrunner_6f498c\\nd_p3_mat_netrunner_6f498c.mesh", image = "img/mats/netrunner.webp" },
    { id = "arasaka", label = "Arasaka", mesh = "ncwe\\custom\\nd_p3_mat_arasaka_fa6361\\nd_p3_mat_arasaka_fa6361.mesh", image = "img/mats/arasaka.webp" },
    { id = "militech", label = "Militech", mesh = "ncwe\\custom\\nd_p3_mat_militech_c42fd8\\nd_p3_mat_militech_c42fd8.mesh", image = "img/mats/militech.webp" },
    { id = "aldecaldo", label = "Aldecaldos", mesh = "ncwe\\custom\\nd_p3_mat_aldecaldo_83df96\\nd_p3_mat_aldecaldo_83df96.mesh", image = "img/mats/aldecaldo.webp" },
    { id = "card0", label = "Night City", mesh = "ncwe\\custom\\nd_p3_mat_card0_f320b9\\nd_p3_mat_card0_f320b9.mesh", image = "img/mats/card0.webp" },
    { id = "card1", label = "Afterlife", mesh = "ncwe\\custom\\nd_p3_mat_card1_557625\\nd_p3_mat_card1_557625.mesh", image = "img/mats/card1.webp" },
}
TcgTable.defaultPlaymat = "netrunner"
TcgTable.playmatById = {}
for _, m in ipairs(TcgTable.playmats) do TcgTable.playmatById[m.id] = m end

TcgTable.mesh = {
    cardback = "ncwe\\custom\\nd_tcg_cardback_170c81\\nd_tcg_cardback_170c81.mesh",   -- one face-down card, 63 x 88 x 0.4 mm
    deck = "ncwe\\custom\\nd_tcg_deck_59af9f\\nd_tcg_deck_59af9f.mesh",               -- face-down stack, 15 mm tall
    deckHeight = 0.015, cardThickness = 0.00032,
}
-- One dice set per seat colour.
TcgTable.dice = {
    netrunner = { d4 = "ncwe\\custom\\nd_tcg_d4_netrunner_303e4a\\nd_tcg_d4_netrunner_303e4a.mesh",
        d6 = "ncwe\\custom\\nd_tcg_d6_netrunner_2ec405\\nd_tcg_d6_netrunner_2ec405.mesh",
        d8 = "ncwe\\custom\\nd_tcg_d8_netrunner_d10b3a\\nd_tcg_d8_netrunner_d10b3a.mesh",
        d10 = "ncwe\\custom\\nd_tcg_d10_netrunner_7cd867\\nd_tcg_d10_netrunner_7cd867.mesh",
        d12 = "ncwe\\custom\\nd_tcg_d12_netrunner_252060\\nd_tcg_d12_netrunner_252060.mesh",
        d20 = "ncwe\\custom\\nd_tcg_d20_netrunner_c51356\\nd_tcg_d20_netrunner_c51356.mesh" },
    arasaka = { d4 = "ncwe\\custom\\nd_tcg_d4_arasaka_9dca3e\\nd_tcg_d4_arasaka_9dca3e.mesh",
        d6 = "ncwe\\custom\\nd_tcg_d6_arasaka_276753\\nd_tcg_d6_arasaka_276753.mesh",
        d8 = "ncwe\\custom\\nd_tcg_d8_arasaka_e8cd5c\\nd_tcg_d8_arasaka_e8cd5c.mesh",
        d10 = "ncwe\\custom\\nd_tcg_d10_arasaka_aca4f1\\nd_tcg_d10_arasaka_aca4f1.mesh",
        d12 = "ncwe\\custom\\nd_tcg_d12_arasaka_e67fe7\\nd_tcg_d12_arasaka_e67fe7.mesh",
        d20 = "ncwe\\custom\\nd_tcg_d20_arasaka_31359f\\nd_tcg_d20_arasaka_31359f.mesh" },
}
TcgTable.dieKinds = { "d4", "d6", "d8", "d10", "d12", "d20" }

-- Where each zone sits on a mat, as a fraction of the printed artwork from its top-left corner (the far edge, the
-- Rival's side, is the top). From the shop's mat generator (mats_binders_blender.py build_game) and the print.
TcgTable.matSize = { w = 0.61, d = 0.355, thick = 0.0029 }
TcgTable.zones = {
    fixer = { d20 = { 0.0725, 0.235 }, d12 = { 0.0725, 0.355 }, d10 = { 0.0725, 0.475 }, d8 = { 0.0725, 0.595 },
              d6 = { 0.0725, 0.715 }, d4 = { 0.0725, 0.835 } },
    legends = { { 0.196, 0.805 }, { 0.313, 0.805 }, { 0.430, 0.805 } },
    field = { x0 = 0.16, x1 = 0.85, y = 0.37 },
    eddies = { x0 = 0.55, x1 = 0.84, y = 0.81 },
    deck = { 0.9325, 0.53 },
    trash = { 0.9325, 0.82 },
    friendlyGigs = { x0 = 0.56, x1 = 0.85, y = 0.055 },
    rivalGigs = { x0 = 0.16, x1 = 0.45, y = 0.055 },
}

-- NEON DECK's duel tables, in the shop's frame (tools/frame.py of E:/Open77/Maps/TCGShop): origin (-824.6, 930.0),
-- yaw 9; u runs along the tables, v across them. Each table has two 1v1 slots, the players face to face; a seat is
-- its chair (v, anchor = the floor under it), the mat's centre (v), where the player stands up (v, away from the
-- table) and the dice colour. Each shop mat mesh carries its sleeve box 0.555 m to the player's right: the slots keep
-- both boxes on the table top.
TcgTable.frame = { ox = -824.6, oy = 930.0, yaw = 9.0 }
TcgTable.tables = {
    -- Upper floor, Table 1 (in front of the stairs): u 2.8-6.4, v 5.8-6.7; the room was deepened to v 3.95.
    etage = { floor = 16.68, top = 17.43, seats = {
        { side = "south", chairV = 5.32, matV = 6.03, turn = 0, standV = 4.75, dice = "netrunner" },
        { side = "north", chairV = 7.18, matV = 6.47, turn = 180, standV = 7.75, dice = "arasaka" },
    } },
    -- Ground floor, the duel table in the middle of the shop: u 5.9-9.1, v 4.5-5.4.
    rdc = { floor = 12.14, top = 12.89, seats = {
        { side = "south", chairV = 4.02, matV = 4.73, turn = 0, standV = 3.45, dice = "netrunner" },
        { side = "north", chairV = 5.88, matV = 5.17, turn = 180, standV = 6.45, dice = "arasaka" },
    } },
}
-- The private rooms under the shop (shared/rooms.lua), level -1, floor 4.0: one duel table per room (u = room centre
-- +- 1.6, v 4.05-4.95), the same layout in all three.
for _, style in ipairs({ "shop", "cozy", "jp" }) do
    TcgTable.tables["room_" .. style] = { floor = 4.0, top = 4.75, seats = {
        { side = "south", chairV = 3.57, matV = 4.28, turn = 0, standV = 3.0, dice = "netrunner" },
        { side = "north", chairV = 5.43, matV = 4.72, turn = 180, standV = 6.0, dice = "arasaka" },
    } }
end
-- Templates of the private rooms' slots: never used as they are, only through TcgTable.roomSlot(template, bucket)
-- (one copy per room instance, in that instance's bucket).
TcgTable.roomSlots = {
    shop = { { id = "rm_shop_a", table = "room_shop", u = -0.5 - 0.78, room = "shop" }, { id = "rm_shop_b", table = "room_shop", u = -0.5 + 0.78, room = "shop" } },
    cozy = { { id = "rm_cozy_a", table = "room_cozy", u = 7.1 - 0.78, room = "cozy" }, { id = "rm_cozy_b", table = "room_cozy", u = 7.1 + 0.78, room = "cozy" } },
    jp = { { id = "rm_jp_a", table = "room_jp", u = 14.7 - 0.78, room = "jp" }, { id = "rm_jp_b", table = "room_jp", u = 14.7 + 0.78, room = "jp" } },
}
local roomSlotCache = {}
function TcgTable.roomSlot(template, bucket)
    local id = template.id .. "@" .. tostring(bucket)
    local s = roomSlotCache[id]
    if not s then
        local side = template.id:sub(-1) == "a" and "A" or "B"
        s = { id = id, label = "Private room - duel table " .. side, table = template.table, u = template.u, bucket = bucket,
              room = template.room, template = template.id }
        roomSlotCache[id] = s
    end
    return s
end
-- The slots of one private room instance.
function TcgTable.roomSlotsFor(style, bucket)
    local out = {}
    for i, tpl in ipairs(TcgTable.roomSlots[style] or {}) do out[i] = TcgTable.roomSlot(tpl, bucket) end
    return out
end

TcgTable.slots = {
    { id = "nd_a", label = "NEON DECK - Table 1 A (upstairs)", table = "etage", bucket = 0, u = 3.45 },
    { id = "nd_b", label = "NEON DECK - Table 1 B (upstairs)", table = "etage", bucket = 0, u = 5.75 },
    { id = "nd_c", label = "NEON DECK - Duel table A (ground floor)", table = "rdc", bucket = 0, u = 6.75 },
    { id = "nd_d", label = "NEON DECK - Duel table B (ground floor)", table = "rdc", bucket = 0, u = 8.25 },
}

local function frameXY(u, v)
    local f = TcgTable.frame
    local a = math.rad(f.yaw)
    local ux, uy, vx, vy = math.cos(a), math.sin(a), -math.sin(a), math.cos(a)
    return f.ox + u * ux + v * vx, f.oy + u * uy + v * vy
end
TcgTable.frameXY = frameXY

-- The two seats of a slot: chair anchor (floor under the seat), where the player stands up, the mat pose.
function TcgTable.seats(slot)
    local tbl = TcgTable.tables[slot.table or "etage"]
    local out = {}
    for i, s in ipairs(tbl.seats) do
        local yaw = (TcgTable.frame.yaw + s.turn) % 360
        local cx, cy = frameXY(slot.u, s.chairV)
        local sx, sy = frameXY(slot.u, s.standV)
        local mx, my = frameXY(slot.u, s.matV)
        out[i] = {
            index = i, side = s.side, yaw = yaw, dice = s.dice,
            chair = { x = cx, y = cy, z = tbl.floor },
            stand = { x = sx, y = sy, z = tbl.floor },
            mat = { x = mx, y = my, z = tbl.top },
        }
    end
    return out
end

-- The middle of a slot (between its two mats): to find the slot nearest to a player.
function TcgTable.centre(slot)
    local s = TcgTable.seats(slot)
    return { x = (s[1].mat.x + s[2].mat.x) / 2, y = (s[1].mat.y + s[2].mat.y) / 2, z = s[1].mat.z }
end

-- A point of a mat (xn, yn: fraction of the artwork from its top-left) in the world, and the mat's yaw.
-- The mat's local +Y is its far edge (the artwork's top); its yaw is the seat's.
function TcgTable.onMat(seat, xn, yn, lift)
    local w, d = TcgTable.matSize.w, TcgTable.matSize.d
    local lx, ly = -w / 2 + xn * w, d / 2 - yn * d
    local a = math.rad(seat.yaw)
    local rx, ry = math.cos(a), math.sin(a)
    local fx, fy = -math.sin(a), math.cos(a)
    return { x = seat.mat.x + lx * rx + ly * fx, y = seat.mat.y + lx * ry + ly * fy,
             z = seat.mat.z + TcgTable.matSize.thick + (lift or 0) }
end

function TcgTable.slotById(id)
    for _, s in ipairs(TcgTable.slots) do if s.id == id then return s end end
    -- a private room's instance slot: "<template>@<bucket>"
    local base, bucket = tostring(id or ""):match("^([%w_]+)@(%d+)$")
    if base then
        for _, list in pairs(TcgTable.roomSlots) do
            for _, tpl in ipairs(list) do if tpl.id == base then return TcgTable.roomSlot(tpl, tonumber(bucket)) end end
        end
    end
end
