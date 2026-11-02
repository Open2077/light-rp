-- Validation shared by the relay and the clients: a definition from any
-- caller is reduced to known fields with bounded values before it is used or
-- sent anywhere. `ActionBubble.clean(def)` returns the clean definition, or
-- nil and a reason.
ActionBubble = ActionBubble or {}
local C = ActionBubbleConfig

local ICONS = {
    hand = true, key = true, lock = true, unlock = true, box = true, trunk = true, car = true,
    door = true, eye = true, chat = true, alert = true, search = true, wrench = true,
    phone = true, cash = true, heart = true, gear = true, none = true,
}
ActionBubble.ICONS = ICONS
local SIDES = { auto = true, left = true, right = true }
local ANCHORS = { player = true, vehicle = true, entity = true, position = true }

--- Cuts a string to `max` bytes without splitting a UTF-8 sequence, drops
--- control characters and squeezes blanks.
function ActionBubble.text(value, max)
    if type(value) ~= "string" then return nil end
    value = value:gsub("[%c]", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #value > max then
        local cut = max
        -- step back over continuation bytes (10xxxxxx) to a lead byte
        while cut > 0 and (value:byte(cut + 1) or 0) >= 0x80 and (value:byte(cut + 1) or 0) < 0xC0 do cut = cut - 1 end
        value = value:sub(1, cut):gsub("%s+$", "") .. "…"
    end
    if value == "" then return nil end
    return value
end

local function number(value, min, max, default)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge or value == -math.huge then return default end
    return math.max(min, math.min(max, value))
end

local function vector(value, limit)
    if type(value) ~= "table" then return nil end
    local x, y, z = tonumber(value.x or value[1]), tonumber(value.y or value[2]), tonumber(value.z or value[3])
    if not x or not y or not z then return nil end
    for _, v in ipairs({ x, y, z }) do
        if v ~= v or math.abs(v) > limit then return nil end
    end
    return { x = x, y = y, z = z }
end
ActionBubble.vector = vector

local function color(value)
    if type(value) == "string" and value:match("^#%x%x%x%x%x%x$") then return value:upper() end
    return nil
end

--- The anchor: { type = "player", player = id } | { type = "vehicle", vehicle = id }
--- | { type = "entity", entity = id } | { type = "position", position = {x,y,z} },
--- each with an optional world-axis `offset`. Shorthands: `player = id`,
--- `vehicle = id`, `entity = id` or `position = {...}` at the top level.
function ActionBubble.anchor(def)
    local a = type(def.anchor) == "table" and def.anchor or {}
    local kind = a.type
    if a.self == true then kind = "self"
    elseif kind == nil then
        if a.player or def.player then kind = "player"
        elseif a.vehicle or def.vehicle then kind = "vehicle"
        elseif a.entity or def.entity then kind = "entity"
        elseif a.position or def.position then kind = "position"
        else kind = "self" end
    end
    if kind == "self" then return { type = "player", self = true, offset = vector(a.offset or def.offset, 10) or C.offsets.player } end
    if not ANCHORS[kind] then return nil, "invalid_anchor" end
    local out = { type = kind, offset = vector(a.offset or def.offset, 10) or C.offsets[kind] }
    if kind == "position" then
        out.position = vector(a.position or def.position, 100000)
        if not out.position then return nil, "invalid_position" end
    else
        local id = a[kind] or def[kind]
        if kind == "entity" then
            id = tostring(id or "")
            if not id:match("^%d+$") or id == "0" then return nil, "invalid_entity" end
        else
            id = tonumber(id)
            if not id or id < 0 or id ~= math.floor(id) then return nil, "invalid_" .. kind end
        end
        out[kind] = id
    end
    return out
end

--- The clean definition of a bubble.
function ActionBubble.clean(def)
    if type(def) == "string" then def = { text = def } end
    if type(def) ~= "table" then return nil, "invalid_definition" end
    local text = ActionBubble.text(def.text, C.maxText)
    if not text then return nil, "text_required" end
    local anchor, why = ActionBubble.anchor(def)
    if not anchor then return nil, why end
    local kind = C.kinds[def.kind] and def.kind or "action"
    local duration = def.duration == 0 and 0 or number(def.duration, 0.5, C.maxDuration, C.duration)
    return {
        text = text,
        kind = kind,
        author = ActionBubble.text(def.author, C.maxAuthor),
        icon = ICONS[def.icon] and def.icon or nil,
        accent = color(def.accent),
        duration = duration,
        anchor = anchor,
        maxDistance = number(def.maxDistance, C.minDistance, C.maxDistanceCap, C.maxDistance),
        side = SIDES[def.side] and def.side or "auto",
        -- the *asterisks* of a roleplay action; on by default for actions only
        asterisks = def.asterisks == nil and kind == "action" or def.asterisks == true,
    }
end

--- A patch for `update`: only the fields given, cleaned the same way.
function ActionBubble.patch(patch)
    if type(patch) ~= "table" then return nil, "invalid_patch" end
    local out, any = {}, false
    if patch.text ~= nil then out.text = ActionBubble.text(patch.text, C.maxText); if not out.text then return nil, "text_required" end; any = true end
    if patch.kind ~= nil then out.kind = C.kinds[patch.kind] and patch.kind or "action"; any = true end
    if patch.author ~= nil then out.author = ActionBubble.text(patch.author, C.maxAuthor) or false; any = true end
    if patch.icon ~= nil then out.icon = ICONS[patch.icon] and patch.icon or false; any = true end
    if patch.accent ~= nil then out.accent = color(patch.accent) or false; any = true end
    if patch.duration ~= nil then out.duration = patch.duration == 0 and 0 or number(patch.duration, 0.5, C.maxDuration, C.duration); any = true end
    if patch.offset ~= nil then out.offset = vector(patch.offset, 10); if not out.offset then return nil, "invalid_offset" end; any = true end
    if patch.position ~= nil then out.position = vector(patch.position, 100000); if not out.position then return nil, "invalid_position" end; any = true end
    if not any then return nil, "empty_patch" end
    return out
end

--- Network options: `network = true` (players around the anchor), or a table
--- { range = metres, targets = { ids } | "all" }. nil / false: local only.
function ActionBubble.network(value)
    if value == nil or value == false then return nil end
    local opts = type(value) == "table" and value or {}
    local targets = nil
    if opts.targets == "all" then targets = "all"
    elseif type(opts.targets) == "table" then
        targets = {}
        for _, id in ipairs(opts.targets) do
            id = tonumber(id)
            if id and id > 0 and #targets < 256 then targets[#targets + 1] = math.floor(id) end
        end
    end
    return { range = number(opts.range, 1, C.maxRange, C.range), targets = targets }
end
