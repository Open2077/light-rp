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

-- NEON DECK, upper floor, Table 1 (the one in front of the stairs): two 1v1 slots, the players face to face across
-- the table. The shop's frame (tools/frame.py): origin (-824.6, 930.0), yaw 9, upper floor 16.68, table top 17.43;
-- u runs along the table, v across it (south seat at v 5.32 facing +v, north seat at v 7.18 facing -v).
TcgTable.frame = { ox = -824.6, oy = 930.0, yaw = 9.0, floor = 16.68, top = 17.43 }
-- The table runs u 2.8 - 6.4. Each shop mat mesh carries its sleeve box 0.555 m to the player's right, so the slots
-- keep both boxes (one per seat, on opposite sides) on the table top.
TcgTable.slots = {
    { id = "nd_a", label = "NEON DECK - Table 1 A", bucket = 0, u = 3.45 },
    { id = "nd_b", label = "NEON DECK - Table 1 B", bucket = 0, u = 5.75 },
}
-- Per seat: the chair (v), the mat centre (v) and the way the player faces (+v south seat, -v north seat).
TcgTable.seatLayout = {
    { side = "south", chairV = 5.32, matV = 6.03, turn = 0, standV = 4.85, dice = "netrunner" },
    { side = "north", chairV = 7.18, matV = 6.47, turn = 180, standV = 7.65, dice = "arasaka" },
}

local function frameXY(u, v)
    local f = TcgTable.frame
    local a = math.rad(f.yaw)
    local ux, uy, vx, vy = math.cos(a), math.sin(a), -math.sin(a), math.cos(a)
    return f.ox + u * ux + v * vx, f.oy + u * uy + v * vy
end
TcgTable.frameXY = frameXY

-- The two seats of a slot: chair anchor (floor under the seat), where the player stands to sit, the mat pose.
function TcgTable.seats(slot)
    local out = {}
    for i, s in ipairs(TcgTable.seatLayout) do
        local yaw = (TcgTable.frame.yaw + s.turn) % 360
        local cx, cy = frameXY(slot.u, s.chairV)
        local sx, sy = frameXY(slot.u, s.standV)
        local mx, my = frameXY(slot.u, s.matV)
        out[i] = {
            index = i, side = s.side, yaw = yaw, dice = s.dice,
            chair = { x = cx, y = cy, z = TcgTable.frame.floor },
            stand = { x = sx, y = sy, z = TcgTable.frame.floor },
            mat = { x = mx, y = my, z = TcgTable.frame.top },
        }
    end
    return out
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
end
