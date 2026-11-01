-- op77_loadscreen client: the in-game zone cover (web/index.html).
--
-- Raised by:
--   * the server:  TriggerClientEvent("op77_loadscreen:cover", playerId, opts)
--                  TriggerClientEvent("op77_loadscreen:release", playerId, { id = id })
--                  (or exports.op77_loadscreen:cover / :release on the server)
--   * a client resource: exports.op77_loadscreen:cover(opts) -> id, :release(id)
--   * the game itself: every native loading screen (long teleports, respawns far
--     away) is covered automatically when the client can report it
--     (Open77.screen.loadingState, screen.read).
-- opts = { id?, title?, subtitle?, zone?, target = {x,y,z}?, targetRadius?,
--          timeoutMs?, minVisibleMs?, expectedMs? } -- see client/cover.lua.
local Cover = LoadscreenCover
local cover = Cover.new()
local page, ready = nil, false
local pending = nil          -- the last "show" sent before the page answered
local hudClaimed = false
local TAG = "[op77_loadscreen] "

local function now() return Open77.time.monotonic() * 1000 end

local function send(name, payload)
    if not (page and ready) then return false end
    local ok, err = pcall(function() page:send(name, payload or {}) end)
    if not ok then print(TAG .. "send " .. name .. " failed: " .. tostring(err)) end
    return ok
end

local function setHud(hidden)
    if hidden == hudClaimed then return end
    hudClaimed = hidden
    if Open77.hud and Open77.hud.setVisible then pcall(Open77.hud.setVisible, "all", not hidden) end
end

local function apply(actions)
    for _, a in ipairs(actions) do
        local kind = a[1]
        if kind == "show" then
            setHud(true)
            pending = a[2]
            send("cover:show", a[2])
        elseif kind == "progress" then
            send("cover:progress", { value = a[2] })
        elseif kind == "complete" then
            send("cover:complete", {})
        elseif kind == "hide" then
            pending = nil
            send("cover:hide", {})
            setHud(false)
        end
    end
end

-- The game's own loading screens (pristine load, teleports, respawns).
local nativeAvailable = Open77.screen and type(Open77.screen.loadingState) == "function"

local function body()
    local ok, s = pcall(Open77.character.state)
    if not ok or type(s) ~= "table" then return {} end
    return { position = s.position, alive = s.alive, grounded = s.grounded }
end

local function step()
    -- Read the native state every tick as well as on its events: the client does
    -- not deliver `open77:loadingScreen:*` to server resources while the session
    -- is still being swapped in, so the end of the join load never arrived and the
    -- cover stayed up until nativeTimeoutMs (90 s) on the arrival, at 100 %.
    if nativeAvailable then
        local ok, state = pcall(Open77.screen.loadingState)
        if ok and type(state) == "table" then cover:native(state, now()) end
    end
    apply(cover:update(now(), cover:hasTargets() and body() or {}))
end

-- --------------------------------------------------------------- requests
local function openCover(opts)
    local id = cover:request(opts, now())
    step()
    return id
end
local function closeCover(id)
    local n = cover:release(id, now())
    step()
    return n
end

RegisterNetEvent("op77_loadscreen:cover", function(opts) openCover(opts) end)
RegisterNetEvent("op77_loadscreen:release", function(p)
    closeCover(type(p) == "table" and p.id ~= nil and tostring(p.id) or nil)
end)

exports("cover", function(opts) return openCover(opts) end)
exports("release", function(id) return closeCover(id ~= nil and tostring(id) or nil) end)
exports("isActive", function() return cover:active() end)

-- --------------------------------------------------------------- native loading screens
if nativeAvailable then
    AddEventHandler("open77:loadingScreen:changed", function(state)
        cover:native(state, now())
        step()
    end)
else
    print(TAG .. "this client cannot report the game's loading screen: zone covers only (update the Open77 client)")
end

-- --------------------------------------------------------------- the page
AddEventHandler("onClientResourceStart", function(name)
    if name ~= GetCurrentResourceName() then return end
    local created, why = Open77.webui.create({
        entry = "web/index.html", layer = "modal", zIndex = 950,
        -- Kept visible with a transparent body between loads: Chromium is already
        -- running when a load begins, and a surface created hidden may never paint.
        visible = true, transparent = true, fps = 30,
    })
    if not created then print(TAG .. "page unavailable: " .. tostring(why)); return end
    page = created
    pcall(function() page:setFocus(false, false) end)
    page:on("ui:ready", function()
        ready = true
        if pending then send("cover:show", pending) end
    end)
    if nativeAvailable then
        local state = Open77.screen.loadingState()
        if state then cover:native(state, now()) end
    end
    CreateThread(function()
        while true do
            step()
            Wait(cover:active() and 100 or 250)
        end
    end)
end)
