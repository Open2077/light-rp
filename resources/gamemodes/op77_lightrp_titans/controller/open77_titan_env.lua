-- The explicit global environment of the Titan controller and of its bridge modules.
--
-- The resource sandbox has no setmetatable, so the environment is a PLAIN table built once, here: every name a Titan
-- chunk reads as a global is a field of it, and a name that is not a field is nil - exactly what an unbound global is.
-- Open77's scripts/titans/titan_port.py proved, for every chunk it generated, that each global the chunk reads is listed in
-- open77_titan_names.lua (generated from its scripts/titans/titan_env.py) or is defined below; a hand edit of a chunk keeps to the
-- same rule: a name it reads must be added to one of the two. A chunk starts with `local _ENV = require("controller.open77_titan_env")`.
--
-- What is bound, and to what:
--   lua        the sandbox's own functions and libraries, by reference. `math` and `string` are copies of the real ones
--              with the two differences from the interpreter the controller was written for made good: `math.atan2`
--              exists, and `string.format`'s integer conversions (%d %i %u %o %x %X %c) truncate a fractional number
--              instead of raising "number has no integer representation".
--   types      Open77.rtti.type(<name>): struct constructors, enum members and static functions of every RTTI type the
--              controller names. A type this game does not have is nil (the controller already tests for that).
--   game       Game.<name>: the static of the GameInstance class or the global function of that name, the current game
--              instance inserted as first argument (Open77.rtti does that); the decorated names (`TSQ_NPC;`) are the
--              global functions of the exact overload.
--   functions  bare global functions (GetLocalizedTextByKey).
--   the rest   small Lua definitions below for what the interpreter the controller was written for provided itself:
--              CName, TweakDBID, TweakDB, NewObject, Enum, EnumInt, EnumName, IsDefined, Variant, FromVariant,
--              ResRefOf, RaRef, GetColorU32 and the plain-table constructors of the vector structs.

local names = require("controller.open77_titan_names")

local rtti = Open77.rtti
local floor, ceil, mtype, huge = math.floor, math.ceil, math.type, math.huge
local sformat, unpack = string.format, table.unpack

local env = {}

-- ------------------------------------------------------------------ the sandbox's functions -----------------------
for _, name in ipairs(names.lua) do env[name] = _G[name] end

local function copy(source)
  local out = {}
  for key, value in pairs(source) do out[key] = value end
  return out
end

local math_copy = copy(math)
math_copy.atan2 = function(y, x) return math.atan(y, x) end
env.math = math_copy

-- A float the integer conversions would refuse becomes the integer the other interpreter produced: truncated toward
-- zero, saturated at the 64-bit range, NaN as 0.
local function whole(v)
  if v ~= v then return 0 end
  if v >= 9.2233720368547758e18 then return math.maxinteger end
  if v <= -9.2233720368547758e18 then return math.mininteger end
  if v >= 0 then return floor(v) end
  return ceil(v)
end

local plans = {}
local function plan(fmt)
  local p = plans[fmt]
  if p ~= nil then return p end
  local list, n, any, from = {}, 0, false, 1
  while true do
    local first, last, spec = fmt:find("%%[%-%+ #0]*%d*%.?%d*([%a%%])", from)
    if not first then break end
    if spec ~= "%" then
      n = n + 1
      if spec:find("[diouxXc]") then
        list[n] = true
        any = true
      end
    end
    from = last + 1
  end
  p = any and list or false
  plans[fmt] = p
  return p
end

local function format(fmt, ...)
  local p = plan(fmt)
  if not p then return sformat(fmt, ...) end
  local n = select("#", ...)
  local args = { ... }
  for i = 1, n do
    local v = args[i]
    if p[i] and mtype(v) == "float" then args[i] = whole(v) end
  end
  return sformat(fmt, unpack(args, 1, n))
end

local string_copy = copy(string)
string_copy.format = format
env.string = string_copy

-- ------------------------------------------------------------------ RTTI names -------------------------------------
for _, name in ipairs(names.types) do
  local accessor = rtti.type(name)
  env[name] = accessor
end

-- The vector structs are plain tables by value (Open77.rtti decodes and encodes them), so their constructors are plain
-- Lua: one table, no native call. The other statics of a struct (EulerAngles.ToQuat) stay the RTTI function.
env.Vector4 = { new = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end }
env.Vector3 = { new = function(x, y, z) return { x = x, y = y, z = z } end }
env.Vector2 = { new = function(x, y) return { x = x, y = y } end }
env.Quaternion = { new = function(i, j, k, r) return { i = i, j = j, k = k, r = r } end }
do
  local euler = rtti.type("EulerAngles")
  env.EulerAngles = {
    new = function(roll, pitch, yaw) return { roll = roll, pitch = pitch, yaw = yaw } end,
    ToQuat = euler and euler.ToQuat,
  }
end

-- WorldPosition and WorldTransform are value structs too. Their native setters take the struct through a script
-- reference that does not reach a Lua table (SetPosition left the caller's transform unchanged, measured 2026-11-03),
-- so the helpers the controller uses work on the tables here. A WorldPosition axis is a FixedPoint: metres * 2^17,
-- truncated toward zero as the engine stores it.
do
  local SCALE = 131072.0
  local function fixed(metres)
    local bits = metres * SCALE
    return { Bits = math.tointeger(bits >= 0 and math.floor(bits) or math.ceil(bits)) }
  end
  local function position(v) return { x = fixed(v.x), y = fixed(v.y), z = fixed(v.z) } end
  env.WorldPosition = {
    new = function() return position({ x = 0.0, y = 0.0, z = 0.0 }) end,
    ToVector4 = function(p) return { x = p.x.Bits / SCALE, y = p.y.Bits / SCALE, z = p.z.Bits / SCALE, w = 1.0 } end,
    SetVector4 = function(p, v)
      local set = position(v)
      p.x, p.y, p.z = set.x, set.y, set.z
    end,
  }
  env.WorldTransform = {
    new = function()
      return { Position = position({ x = 0.0, y = 0.0, z = 0.0 }), Orientation = { i = 0.0, j = 0.0, k = 0.0, r = 1.0 } }
    end,
    SetPosition = function(t, v) t.Position = position(v) end,
    GetWorldPosition = function(t) return t.Position end,
    SetOrientation = function(t, q) t.Orientation = { i = q.i, j = q.j, k = q.k, r = q.r } end,
    GetOrientation = function(t) return t.Orientation end,
  }
end

-- ------------------------------------------------------------------ Game ------------------------------------------
do
  local instance = rtti.type("GameInstance")
  local function global(name)
    local ok, bound = pcall(rtti.global, name)
    if ok then return bound end
  end
  local Game = {}
  for _, name in ipairs(names.game) do
    local bound = instance and instance[name]
    if bound == nil then bound = global(name) end
    Game[name] = bound
  end
  env.Game = Game
  for _, name in ipairs(names.functions) do env[name] = global(name) end
end

-- ------------------------------------------------------------------ small definitions -----------------------------
env.CName = { new = function(text) return text end }

-- A TweakDBID is the integer REDengine computes from the name: GetHashKey is that hash. `TweakDBID.new(base, suffix)`
-- continues the CRC of `base` over `suffix` (what the engine's two-argument constructor does).
local crc_table
local function crc_step(state, text)
  if not crc_table then
    crc_table = {}
    for i = 0, 255 do
      local c = i
      for _ = 1, 8 do
        if c & 1 == 1 then c = 0xEDB88320 ~ (c >> 1) else c = c >> 1 end
      end
      crc_table[i] = c
    end
  end
  for i = 1, #text do
    state = crc_table[(state ~ text:byte(i)) & 0xFF] ~ (state >> 8)
  end
  return state
end

env.TweakDBID = {
  new = function(base, suffix)
    if suffix == nil then
      if type(base) == "number" then return base end
      return GetHashKey(base)
    end
    local crc = ~crc_step(~base & 0xFFFFFFFF, suffix) & 0xFFFFFFFF
    local length = (((base >> 32) & 0xFF) + #suffix) & 0xFF
    return (length << 32) | crc
  end,
}

do
  local tweak = rtti.tweakdb
  env.TweakDB = {
    GetRecord = function(_, id) return tweak.getRecord(id) end,
    GetFlat = function(_, id) return tweak.getFlat(id) end,
    SetFlat = function(_, id, value) return tweak.setFlat(id, value) end,
    Update = function(_, id) return tweak.update(id) end,
  }
end

env.IsDefined = rtti.isDefined

-- `NewObject("handle:Class")` is a new object of a class (a ref); `NewObject("Struct")` a new struct (a table).
env.NewObject = function(name)
  if name:sub(1, 7) == "handle:" then name = name:sub(8) end
  return rtti.type(name).new()
end

env.Enum = {
  new = function(typeName, member)
    if type(member) == "number" then return member end
    return rtti.type(typeName)[member]
  end,
}
env.EnumInt = function(value) return value end
env.EnumName = function(typeName, value) return rtti.enumName(typeName, value) or tostring(value) end

env.Variant = rtti.variant
env.FromVariant = function(value) return value end

-- raRef:<resource kind> properties and parameters are the 64-bit hash of the depot path; ResRef.FromString does the
-- hashing, and effect paths are few, so the answer is kept.
do
  local resref = rtti.type("ResRef")
  local made, hashes = {}, {}
  local function resref_of(path)
    local value = made[path]
    if value == nil then
      local make = resref.FromString or resref.FromName
      value = make(path)
      made[path] = value
    end
    return value
  end
  env.ResRefOf = resref_of
  env.RaRef = function(path)
    local hash = hashes[path]
    if hash == nil then
      hash = resref_of(path).resource
      hashes[path] = hash
    end
    return hash
  end
end

-- ImGui's packed colour: red in the low byte, alpha in the high one, each channel the nearest of 256 steps.
do
  local function channel(x)
    if x <= 0 then return 0 end
    if x >= 1 then return 255 end
    return floor(x * 255 + 0.5)
  end
  env.GetColorU32 = function(r, g, b, a)
    return channel(r) | (channel(g) << 8) | (channel(b) << 16) | (channel(a) << 24)
  end
end

-- The gameplay HUD's drawing surface (resources/gamemodes/op77_lightrp_titans/render.lua). A game without it draws no
-- overlay; the controller's native ink HUD does not depend on it.
do
  local ok, render = pcall(require, "render")
  env.render = ok and type(render) == "table" and render or nil
end

env.Open77 = Open77
env.require = require

return env
