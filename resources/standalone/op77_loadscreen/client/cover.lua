-- op77_loadscreen: when the zone cover is up, decided without touching the game.
-- client/main.lua feeds it the requests (server events, exports), the native
-- loading-screen state and the local body, and draws what update() returns.
--
-- The cover is up while any of these holds:
--   * a cover request is open. It closes on `release`, on its timeout, or, when it
--     carries a `target`, once the body stands within `targetRadius` of it, alive
--     and grounded, for `targetStableMs`, with no native loading screen active;
--   * the game's own loading screen is active (Open77.screen.loadingState), for
--     longer than `nativeDelayMs` (a cycle that ends at once is never covered).
-- It then stays for `settleMs` more (the bar lands on 100 %), and never goes
-- before `minVisibleMs` so that it reads as a loading screen, not a flash.
LoadscreenCover = {}
local M = LoadscreenCover

M.defaults = {
    minVisibleMs = 2200,        -- a scripted cover (a zone change)
    nativeMinVisibleMs = 1200,  -- a cover raised by the game's loading screen alone
    settleMs = 650,             -- the full bar before the cover leaves
    nativeDelayMs = 200,
    timeoutMs = 30000,          -- a request nobody releases
    maxTimeoutMs = 120000,
    nativeTimeoutMs = 90000,    -- a native cycle that never reports its end
    targetRadius = 4.0,
    targetStableMs = 800,
    expectedMs = 7000,          -- the page's estimate curve until real progress arrives
}

local function text(v, max)
    if type(v) ~= "string" then return nil end
    v = v:gsub("[%c]", " ")
    if v == "" then return nil end
    if #v > max then v = v:sub(1, max) end
    return v
end
local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local function clamp(v, lo, hi, default)
    if not finite(v) then return default end
    return math.max(lo, math.min(hi, v))
end

-- What a caller may ask for. Anything else is dropped.
function M.normalize(opts)
    if type(opts) ~= "table" then opts = {} end
    local d = M.defaults
    local out = {
        id = text(type(opts.id) == "number" and tostring(opts.id) or opts.id, 64),
        title = text(opts.title, 64),
        subtitle = text(opts.subtitle, 64),
        zone = text(opts.zone, 40),
        timeoutMs = clamp(opts.timeoutMs, 1000, d.maxTimeoutMs, d.timeoutMs),
        minVisibleMs = clamp(opts.minVisibleMs, 0, 15000, d.minVisibleMs),
        expectedMs = clamp(opts.expectedMs, 1500, 60000, d.expectedMs),
    }
    local t = opts.target
    if type(t) == "table" and finite(t.x) and finite(t.y) and finite(t.z) then
        out.target = { x = t.x, y = t.y, z = t.z }
        out.targetRadius = clamp(opts.targetRadius, 0.5, 50, d.targetRadius)
    end
    return out
end

-- The client sandbox has no setmetatable: methods and defaults are copied in.
function M.new(overrides)
    local self = {}
    for k, v in pairs(M) do
        if type(v) == "function" then self[k] = v end
    end
    self.cfg = {}
    for k, v in pairs(M.defaults) do self.cfg[k] = v end
    for k, v in pairs(overrides or {}) do self.cfg[k] = v end
    self.requests = {}       -- ordered list of open requests
    self.seq = 0
    self.nativeState = { active = false }
    self.visible = false
    self.shownAt = 0
    self.quietSince = nil    -- when nothing wanted the cover any more
    self.minVisible = 0
    self.completed = false
    self.lastProgress = nil
    self.shownFor = nil      -- the request whose texts are on screen
    return self
end

function M:request(opts, now)
    local r = M.normalize(opts)
    if not r.id then self.seq = self.seq + 1; r.id = "cover:" .. self.seq end
    -- the same id again refreshes that request instead of stacking a second one
    for i, open in ipairs(self.requests) do
        if open.id == r.id then table.remove(self.requests, i) break end
    end
    r.at = now
    self.requests[#self.requests + 1] = r
    return r.id
end

-- nil releases every open request (the server lost track, a resource stopped).
function M:release(id, _now)
    local released = 0
    for i = #self.requests, 1, -1 do
        if id == nil or self.requests[i].id == id then
            table.remove(self.requests, i)
            released = released + 1
        end
    end
    return released
end

function M:native(state, now)
    if type(state) ~= "table" then return end
    local prev = self.nativeState
    if prev.revision and state.revision and state.revision < prev.revision then return end
    local active = state.active == true
    self.nativeState = {
        active = active,
        revision = state.revision,
        since = active and (prev.active and prev.since or now) or nil,
        progress = (state.progressKnown and finite(state.progress)) and math.max(0, math.min(1, state.progress)) or nil,
    }
end

local function dist2(a, b) local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z; return dx * dx + dy * dy + dz * dz end

-- env = { position = {x,y,z}?, alive = bool?, grounded = bool? } (the local body)
-- Returns a list of actions: { "show", payload } | { "progress", 0..1 } | { "complete" } | { "hide" }
function M:update(now, env)
    local cfg, actions = self.cfg, {}
    env = env or {}
    local native = self.nativeState
    local nativeActive = native.active and native.since ~= nil and (now - native.since) < cfg.nativeTimeoutMs
    -- 1. close what is done
    for i = #self.requests, 1, -1 do
        local r = self.requests[i]
        local done = now - r.at >= r.timeoutMs
        if not done and r.target then
            local p = env.position
            local standing = p and env.alive ~= false and env.grounded ~= false and not nativeActive
                and dist2(p, r.target) <= r.targetRadius * r.targetRadius
            if standing then
                r.nearSince = r.nearSince or now
                done = now - r.nearSince >= cfg.targetStableMs
            else
                r.nearSince = nil
            end
        end
        if done then table.remove(self.requests, i) end
    end
    local top = self.requests[#self.requests]
    local wantNative = nativeActive and (now - native.since) >= cfg.nativeDelayMs
    local want = top ~= nil or wantNative
    -- 2. raise or refresh
    if want then
        self.quietSince, self.completed = nil, false
        local payload
        if not self.visible then
            self.visible, self.shownAt, self.minVisible = true, now, 0
            self.lastProgress, self.shownFor = nil, nil
            payload = top or {}
        elseif top and self.shownFor ~= top then
            payload = top
        end
        if top then self.minVisible = math.max(self.minVisible, top.minVisibleMs)
        else self.minVisible = math.max(self.minVisible, cfg.nativeMinVisibleMs) end
        if payload then
            self.shownFor = top
            actions[#actions + 1] = { "show", {
                title = payload.title, subtitle = payload.subtitle, zone = payload.zone,
                expectedMs = payload.expectedMs or cfg.expectedMs,
            } }
        end
        if nativeActive and native.progress and native.progress ~= self.lastProgress then
            self.lastProgress = native.progress
            actions[#actions + 1] = { "progress", native.progress }
        end
        return actions
    end
    -- 3. lower, once it has been seen long enough and the full bar has shown
    if self.visible then
        self.quietSince = self.quietSince or now
        if not self.completed then
            self.completed = true
            actions[#actions + 1] = { "complete" }
        end
        if now - self.quietSince >= cfg.settleMs and now - self.shownAt >= self.minVisible then
            self.visible, self.shownFor, self.quietSince = false, nil, nil
            actions[#actions + 1] = { "hide" }
        end
    end
    return actions
end

function M:active() return self.visible or #self.requests > 0 end
function M:hasTargets()
    for _, r in ipairs(self.requests) do if r.target then return true end end
    return false
end
