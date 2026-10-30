-- op77_weaponhud: the pure parts (no host calls), shared by the client, the server and the
-- tests: config merge and sanitizing, the surface crop, snapshot rows -> what is held,
-- names and classes, and what changed between two samples (shots, reloads, switches).
WeaponHud = {}
local W = WeaponHud

W.WIDTH = 420
W.HEIGHT = 210
W.PAD = 48

local function clamp(v, lo, hi, default)
    v = tonumber(v)
    if v == nil or v ~= v then return default end
    return math.max(lo, math.min(hi, v))
end
local function color(v, default)
    if type(v) == "string" and v:match("^#%x%x%x%x%x%x$") then return v:upper() end
    return default
end

function W.copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = W.copy(v) end
    return out
end
function W.merge(base, patch)
    local out = W.copy(base) or {}
    if type(patch) ~= "table" then return out end
    for k, v in pairs(patch) do
        if type(v) == "table" and type(out[k]) == "table" and v[1] == nil and next(v) ~= nil then out[k] = W.merge(out[k], v)
        else out[k] = W.copy(v) end
    end
    return out
end

function W.pageConfig(c)
    local l, t = c.layout or {}, c.theme or {}
    local zeros = c.leadingZeros
    if zeros ~= "lit" and zeros ~= "off" then zeros = "dim" end
    return {
        leadingZeros = zeros,
        lowAmmo = clamp(c.lowAmmo, 0, 1, 0.25),
        lowAmmoMax = clamp(c.lowAmmoMax, 0, 999, 10),
        maxCells = math.floor(clamp(c.maxCells, 4, 60, 36)),
        layout = {
            left = clamp(l.left, 0, 4000, 36),
            bottom = clamp(l.bottom, 0, 2000, 142),
            offsetX = clamp(l.offsetX, -4000, 4000, 0),
            offsetY = clamp(l.offsetY, -2000, 2000, 0),
            scale = clamp(l.scale, 0.4, 1.6, 0.6),
            tilt = l.tilt ~= false,
            tiltX = clamp(l.tiltX, -30, 30, 8),
            tiltY = clamp(l.tiltY, -40, 40, 16),
            maxInset = clamp(l.maxInset, 0, 600, 60),
        },
        theme = {
            accent = color(t.accent, "#FFCC00"),
            core = color(t.core, "#FFF7DA"),
            warn = color(t.warn, "#FF3B3B"),
            cool = color(t.cool, "#7FD8FF"),
            glow = clamp(t.glow, 0, 2, 1),
            opacity = clamp(t.opacity, 0.3, 1, 1),
            scanlines = t.scanlines ~= false,
            flicker = t.flicker ~= false,
        },
    }
end

-- The crop, anchored to the bottom-LEFT corner (x from the left edge, y negative from the
-- bottom), tall enough for the display lifted by up to `maxInset`.
function W.bounds(page)
    local l = page.layout
    local left = math.max(0, l.left + l.offsetX)
    local bottom = math.max(0, l.bottom - l.offsetY)
    local w = math.ceil(W.WIDTH * l.scale)
    local h = math.ceil(W.HEIGHT * l.scale)
    local pad = W.PAD
    local top = bottom + l.maxInset + h + pad
    return {
        x = 0,
        y = -math.floor(top),
        width = math.floor(left + w + pad),
        height = math.floor(math.min(h + 2 * pad + l.maxInset, top)),
    }
end

-- ── snapshot rows ──
-- open77:weapons:state arguments (client/src/scripting/ClientResourceHost.cpp): requestId,
-- slot, record, tweakDbId, active, drawn, locked, ammoRecord, ammoTweakDbId, total, reserve,
-- magazine, capacity, reloading. Counts are -1 while unknown.
local function count(v)
    local n = tonumber(v)
    if n and n == n and n >= 0 and n <= 1000000 and n % 1 == 0 then return math.floor(n) end
end
function W.row(slot, record, tweakDbId, active, drawn, locked, ammoRecord, ammoTweakDbId, total, reserve, magazine, capacity, reloading)
    local id = tostring(tweakDbId or "")
    local empty = id == "" or id == "0x0000000000000000"
    local cap = count(capacity)
    local mag = count(magazine)
    if cap == 0 or (mag and cap and mag > cap) then cap, mag = nil, nil end
    return {
        slot = math.floor(tonumber(slot) or 0), record = tostring(record or ""), tweakDbId = id, empty = empty,
        active = active == "true" or active == true, drawn = drawn == "true" or drawn == true,
        ammo = tostring(ammoTweakDbId or ""), reserve = count(reserve), magazine = mag, capacity = cap,
        reloading = reloading == "true" or reloading == true,
    }
end

-- What is held: the drawn, active weapon of the right hand (slots 1-3) and of the left (4-6).
function W.held(rows)
    local right, left
    for _, r in pairs(rows or {}) do
        if not r.empty and r.drawn and r.active then
            if r.slot >= 1 and r.slot <= 3 and (not right or r.slot < right.slot) then right = r end
            if r.slot >= 4 and r.slot <= 6 and (not left or r.slot < left.slot) then left = r end
        end
    end
    return right, left
end

-- ── names ──
local CLASS = { P = "POWER", T = "TECH", S = "SMART", B = "BLADE", U = "BLUNT" }
local TYPES = {
    Handgun = "HANDGUN", Revolver = "REVOLVER", SubmachineGun = "SMG", Rifle = "RIFLE", SniperRifle = "SNIPER",
    PrecisionRifle = "PRECISION", Shotgun = "SHOTGUN", ShotgunDual = "DOUBLE BARREL", LightMachineGun = "LMG",
    Katana = "KATANA", Knife = "KNIFE", Machete = "MACHETE", OneHandedClub = "CLUB", TwoHandedClub = "HEAVY CLUB",
    Hammer = "HAMMER", Axe = "AXE", Chainsword = "CHAINSWORD", LongBlade = "BLADE", Sword = "SWORD", Fists = "FISTS",
    GrenadeLauncher = "LAUNCHER",
}
local function typeLabel(kind)
    if not kind or kind == "" then return nil end
    kind = tostring(kind):gsub("^ItemType%.", ""):gsub("^Wea_", "")
    return TYPES[kind] or kind:gsub("(%l)(%u)", "%1 %2"):upper()
end
local function classOf(text)
    text = tostring(text or "")
    for _, name in ipairs({ "Smart", "Tech", "Power", "Blade", "Blunt" }) do
        if text:find(name) then return name:upper() end
    end
end

-- "Items.Preset_Lexington_Default" -> "LEXINGTON", "Items.MantisBlades" -> "MANTIS BLADES"
function W.recordName(record)
    local name = tostring(record or ""):gsub("^Items%.", ""):gsub("^Preset_", ""):gsub("^Base_", "")
        :gsub("_Default$", ""):gsub("_", " "):gsub("(%l)(%u)", "%1 %2")
    return name:upper()
end

-- Arm cyberware held as a weapon (ArmsCW): no magazine, no reserve. Neither the shipped catalogue
-- nor Open77.data.weapon knows them, so the record / item type decides.
local ARMS = {
    { match = "MantisBlades", name = "MANTIS BLADES", type = "ARM BLADES", class = "BLADE" },
    { match = "NanoWires", name = "MONOWIRE", type = "ARM WIRE", class = "BLADE" },
    { match = "StrongArms", name = "GORILLA ARMS", type = "ARM FISTS", class = "BLUNT" },
}
local function armWeapon(record, itemType)
    local text = tostring(record or "") .. " " .. tostring(itemType or "")
    for _, arm in ipairs(ARMS) do
        if text:find(arm.match, 1, true) then
            local name = arm.name
            if text:find("Electric", 1, true) then name = "ELECTRIC " .. name
            elseif text:find("Thermal", 1, true) then name = "THERMAL " .. name
            elseif text:find("Chemical", 1, true) then name = "CHEMICAL " .. name end
            return { name = name, type = arm.type, class = arm.class }
        end
    end
end

-- record + Open77.data.weapon(record) (may be nil) + the shipped catalogue + labels -> name, type, class
function W.describe(record, info, catalogue, labels, names)
    record = tostring(record or "")
    info = type(info) == "table" and info or {}
    local entry = type(catalogue) == "table" and catalogue[record] or nil
    local name = (type(labels) == "table" and labels[record]) or (type(names) == "table" and names[record])
        or (type(info.displayName) == "string" and info.displayName ~= "" and info.displayName)
        or (record ~= "" and W.recordName(record)) or "WEAPON"
    local class = classOf(info.evolution) or (entry and CLASS[entry:sub(1, 1)])
    if not class and type(info.tags) == "table" then class = classOf(table.concat(info.tags, ",")) end
    local kind = typeLabel(info.itemType) or (entry and typeLabel(entry:sub(2)))
    local arm = armWeapon(record, info.itemType)
    if arm then
        local labelled = (type(labels) == "table" and labels[record]) or (type(names) == "table" and names[record])
        return { name = tostring(labelled or arm.name):upper(), type = arm.type, class = arm.class, melee = true }
    end
    local melee = class == "BLADE" or class == "BLUNT"
    return { name = tostring(name):upper(), type = kind, class = class, melee = melee }
end

-- ── what changed ──
-- prev / cur: { key, magazine, reloading } of the held weapon. shots = rounds gone without
-- a reload in between (no shot event exists: magazine deltas between two snapshots).
function W.diff(prev, cur)
    if not cur then return { switched = prev ~= nil, shots = 0 } end
    if not prev or prev.key ~= cur.key then return { switched = true, shots = 0 } end
    local out = { switched = false, shots = 0 }
    if prev.magazine and cur.magazine then
        if cur.magazine < prev.magazine and not cur.reloading then out.shots = prev.magazine - cur.magazine end
        if cur.magazine > prev.magazine then out.reloaded = true end
    end
    return out
end

function W.low(magazine, capacity, c)
    if not magazine or not capacity or capacity <= 0 or magazine <= 0 then return false end
    return magazine <= math.min(c.lowAmmoMax or 10, math.max(1, math.floor(capacity * (c.lowAmmo or 0.25) + 0.5)))
end

function W.shouldShow(c, s)
    if c.enabled == false or not s.armed then return false end
    if s.busy and c.hideUnderMenus ~= false then return false end
    if s.inVehicle and c.showInVehicles == false then return false end
    if s.suppressed then return false end
    return true
end
