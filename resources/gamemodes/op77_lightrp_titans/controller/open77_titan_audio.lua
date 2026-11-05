-- BT's sounds as other players hear them.
--
-- Owner side: `world_row` turns a row the controller plays for its own ears into the row a bystander hears
-- (no spoken lines, first-person rows replaced by their third-person twins, listener-relative side rows reduced
-- to their base row).
--
-- Observer side: `Audio.new(ctx)` replays an event on a remote Titan the way the controller itself plays BT for
-- a listener standing at a distance: rows meant to be positioned go through an AudioXL emitter attached to the
-- remote entity, plain rows are played with a distance-dependent gain (near / middle / far takes where the
-- family has them), native events are posted on the remote entity. Nothing here is played "in the head" of the
-- listener at full level regardless of distance.

local _ENV = require("controller.open77_titan_env")

local M = {}

local catalog_names

-- Splits a row into (family, tier, index): bt7274_step_mid_3 -> bt7274_step, mid, 3; bt7274_xo16_tail -> itself, close.
local function family_of(name)
  local fam, tier, idx = name:match("^(.-)_(mid)_(%d+)$")
  if not fam then fam, tier, idx = name:match("^(.-)_(far)_(%d+)$") end
  if not fam then fam, tier = name:match("^(.-)_(mid)$") end
  if not fam then fam, tier = name:match("^(.-)_(far)$") end
  if fam then return fam, tier, tonumber(idx) end
  local base, n = name:match("^(.-)_(%d+)$")
  if base then return base, "close", tonumber(n) end
  return name, "close", nil
end

-- The family a row belongs to (its name without tier and index): rows of one family are one sound to a listener.
function M.family(name)
  return (family_of(name))
end

local function families(sounds)
  if catalog_names == sounds then return M._families end
  local out = {}
  for name in pairs(sounds) do
    if name:find("^bt7274_") then
      local fam, tier, idx = family_of(name)
      local F = out[fam]
      if not F then F = { close = {}, mid = {}, far = {} }; out[fam] = F end
      local list = F[tier]
      list[#list + 1] = { name = name, idx = idx or 0 }
    end
  end
  for _, F in pairs(out) do
    for _, tier in ipairs({ "close", "mid", "far" }) do
      table.sort(F[tier], function(a, b) return a.idx < b.idx end)
    end
  end
  catalog_names, M._families = sounds, out
  return out
end

local function pick(list, idx)
  local n = #list
  if n == 0 then return nil end
  if idx and idx > 0 then return list[(idx - 1) % n + 1].name end
  return list[1].name
end

-- The row a bystander hears for a row the owner's controller plays, or nil and the reason.
function M.world_row(sounds, name)
  if type(name) ~= "string" then return nil, "name" end
  if name:find("^bt7274_vo_") or name:find("^bt7274_say_") then return nil, "voice" end
  local base = name:gsub("_p%d%d$", "")
  if sounds[base] and not base:find("_fp") then return base end
  if base:find("_fp") then
    local tp = base:gsub("_fp", "_tp")
    if sounds[tp] then return tp end
    local plain = base:gsub("_fp", "")
    if sounds[plain] then return plain end
    return nil, "first-person row without a world row"
  end
  return nil, "not in the catalog"
end

local function curve(points, d)
  if type(points) ~= "table" or #points < 2 then return 0.0 end
  if d <= points[1][1] or d >= points[#points][1] then return 0.0 end
  for i = 2, #points do
    local a, b = points[i - 1], points[i]
    if d <= b[1] then return a[2] + (b[2] - a[2]) * (d - a[1]) / (b[1] - a[1]) end
  end
  return 0.0
end
M.curve = curve

local DEFAULTS = {
  closeTo = 24.0,
  midCurve = { { 6.0, 0.0 }, { 18.0, 0.5 }, { 35.0, 0.5 }, { 60.0, 0.0 } },
  farCurve = { { 30.0, 0.0 }, { 55.0, 0.4 }, { 90.0, 0.25 }, { 140.0, 0.0 } },
  full = 12.0, silent = 150.0, placedReach = 60.0,
}
local PLACE_LIFE = 12.0    -- seconds a one-shot emitter at a world point lives before its owner destroys it
local MAX_PLACES = 12      -- one-shot emitters one Titan may hold at once (the oldest is destroyed first)
local MAX_PLAYING = 8      -- remembered plays per row, so a stop reaches exactly what this Titan started

-- Observer-side player. `ctx` supplies env (controller tables), diag, clock and the catalog.
--
-- Every sound of a remote Titan R is played on an emitter that belongs to R alone (open77_titan_<id>, attached to R's
-- entity, or a one-shot emitter at a world point owned by R), and stopped only on that emitter. Nothing here uses
-- the global AudioXL Stop: a row is shared by the local player's own BT and every other Titan, a stop is not.
function M.new(ctx)
  local self = { axl = nil, axlAt = -10.0 }

  local function env() return ctx.env or {} end

  local function steps()
    local FPC = env().FPC
    local K = FPC and FPC.steps
    return {
      closeTo = K and K.closeTo or DEFAULTS.closeTo,
      midCurve = K and K.midCurve or DEFAULTS.midCurve,
      farCurve = K and K.farCurve or DEFAULTS.farCurve,
    }
  end

  function self.class()
    if self.axl and ctx.clock - self.axlAt < 5.0 then return self.axl end
    self.axlAt = ctx.clock
    local sys
    pcall(function() sys = Game.GetScriptableSystemsContainer():Get(CName.new("AudioXL.AudioXLLua")) end)
    self.axl = sys
    if not sys then ctx.diag("audio.noaxl", "AudioXL's class for Lua mods (AudioXL.AudioXLLua) is not in the game: remote Titans play native sounds only") end
    return sys
  end

  -- listener side and distance for a world point
  local function listener(x, y, z)
    local FPF = env().FPF
    if not (FPF and FPF.sideTo) then return nil, 0.0 end
    local ok, side, dist = pcall(FPF.sideTo, x, y, z)
    if ok and side then return side, dist or 0.0 end
    return nil, 0.0
  end

  local function side_row(axl, row, side)
    local FPC = env().FPC
    local rows, suffix = FPC and FPC.side and FPC.side.rows, FPC and FPC.side and FPC.side.suffix
    local R = rows and rows[row]
    if not (R and side and suffix) then return row end
    local i = math.floor(side * R.k + 0.5)
    if i == 0 then return row end
    local candidate = row .. string.format(suffix, i + R.k)
    local ok, has = pcall(function() return axl:Has(candidate) end)
    return (ok and has ~= false) and candidate or row
  end

  local function placed(row)
    local FPC = env().FPC
    return FPC and FPC.placedRows and FPC.placedRows[row] == true
  end

  -- AudioXL calls answer true when they took effect; anything else (an error, nil, false) is a refusal.
  local function took(ok, result) return ok and result == true end

  local function refused(key, text)
    ctx.diag(key, text)
    return false
  end

  -- the emitter on the remote Titan: made once, kept for the Titan's life
  local function attach(R, axl)
    if R.emitterOn then return R.emitter end
    if not R.ent or ctx.clock < (R.emitterTryAt or 0.0) then return nil end
    local ok, result = pcall(function() return axl:AttachEmitter(R.emitter, R.ent) end)
    if took(ok, result) then
      R.emitterOn = true
      return R.emitter
    end
    R.emitterTryAt = ctx.clock + 5.0
    refused("audio.attach", "AudioXL refused an emitter on a remote Titan (" .. tostring(result) .. "): its AudioXL sounds are not heard")
    return nil
  end

  local function destroy(axl, name)
    pcall(function() axl:DestroyEmitter(name) end)
  end

  -- a one-shot emitter at a world point, owned (and later destroyed) by the Titan that asked for it
  local function place(R, axl, pos)
    R.places = R.places or {}
    if #R.places >= MAX_PLACES then destroy(axl, table.remove(R.places, 1).name) end
    R.placeN = (R.placeN or 0) + 1
    local name = "open77_titan_" .. R.id .. "_at_" .. R.placeN
    local ok, result = pcall(function() return axl:CreateEmitter(name, pos.x, pos.y, pos.z) end)
    if not took(ok, result) then
      refused("audio.place", "AudioXL refused an emitter at a world point (" .. tostring(result) .. "): that sound is not heard")
      return nil
    end
    R.places[#R.places + 1] = { name = name, expires = ctx.clock + PLACE_LIFE }
    return name
  end

  local function remember(R, name, em, row)
    R.playing = R.playing or {}
    local list = R.playing[name] or {}
    R.playing[name] = list
    if #list >= MAX_PLAYING then table.remove(list, 1) end
    list[#list + 1] = { em = em, row = row }
  end

  local function play_row(R, axl, row, gain, where, side)
    local em = where and place(R, axl, where) or attach(R, axl)
    if not em then return false end
    -- plain rows are 2D rows: on an emitter they stay 2D, so their level is the distance gain computed by the caller
    local actual = placed(row) and row or side_row(axl, row, side)
    local ok, result = pcall(function() return axl:PlayOn(em, actual, math.max(gain, 0.01)) end)
    if not took(ok, result) then
      return refused("audio.playon", "AudioXL refused to play " .. actual .. " on a remote Titan's emitter (" .. tostring(result) .. ")")
    end
    remember(R, row, em, actual)
    return true
  end

  -- Plays a clean `sound` event on remote Titan R. `where` is the world point (event position or the Titan).
  function self.play(R, ev)
    if ev.backend == "native" then
      if R.ent then pcall(function() GameObject.PlaySoundEvent(R.ent, ev.name) end) end
      return true
    end
    local axl = self.class()
    if not axl then return false end
    local pos = ev.position
    local at = pos or R.pose or { x = 0, y = 0, z = 0 }
    local side, dist = listener(at.x, at.y, at.z + (pos and 0.0 or 4.0))
    local gain = ev.gain or 1.0
    local K = steps()
    local fam, tier, idx = family_of(ev.name)
    local F = families(ctx.catalog.sounds)[fam]
    local plays = {}
    if F and (#F.mid > 0 or #F.far > 0) then
      if dist < K.closeTo then
        local close = (tier == "close") and ev.name or pick(F.close, idx)
        if close then plays[#plays + 1] = { close, gain } end
      end
      local gm, gf = curve(K.midCurve, dist), curve(K.farCurve, dist)
      if gm > 0.02 and #F.mid > 0 then plays[#plays + 1] = { pick(F.mid, idx), gain * gm } end
      if gf > 0.02 and #F.far > 0 then plays[#plays + 1] = { pick(F.far, idx), gain * gf } end
    else
      local g = gain
      if not placed(ev.name) and dist > DEFAULTS.full then
        g = g * math.max(0.0, 1.0 - (dist - DEFAULTS.full) / (DEFAULTS.silent - DEFAULTS.full))
      end
      if g > 0.02 then plays[#plays + 1] = { ev.name, g } end
    end
    local any = false
    for _, p in ipairs(plays) do
      if not (placed(p[1]) and dist > DEFAULTS.placedReach) then
        any = play_row(R, axl, p[1], p[2], pos, side) or any
      end
    end
    return any
  end

  -- Stops what remote Titan R started for this row, on the emitters it started it on, and nothing else.
  function self.stop(R, ev)
    if ev.backend == "native" then return end
    local axl = self.axl
    local list = R.playing and R.playing[ev.name]
    if not (axl and list) then return end
    R.playing[ev.name] = nil
    for _, p in ipairs(list) do
      pcall(function() axl:StopOn(p.em, p.row, 0.25) end)
    end
  end

  -- destroys one-shot emitters whose sounds have had their time
  function self.maintain(R)
    local axl = self.axl
    if not (axl and R.places and #R.places > 0) then return end
    local keep = {}
    for _, p in ipairs(R.places) do
      if ctx.clock >= p.expires then destroy(axl, p.name) else keep[#keep + 1] = p end
    end
    R.places = keep
  end

  function self.release(R)
    local axl = self.axl
    if axl then
      if R.emitterOn then
        pcall(function() axl:StopOn(R.emitter, "", 0.2) end)
        destroy(axl, R.emitter)
      end
      for _, p in ipairs(R.places or {}) do destroy(axl, p.name) end
    end
    R.emitterOn, R.places, R.playing = false, nil, nil
  end

  return self
end

return M
