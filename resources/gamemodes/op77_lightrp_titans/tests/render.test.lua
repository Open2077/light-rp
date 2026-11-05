-- op77_lightrp_titans: the HUD render module's DOM state (render.state, render.toggleHints) against a fake WebUI page.
--
-- Loads the REAL render.lua with a fake Open77 (time, log, display size, WebUI) and proves what the HUD page is told besides
-- the canvas: the state a game asks for before the page is up goes out as soon as the page announced itself and again after
-- it reloads, a new state or a clear is sent at once, the control hints' switch rides on every state, a refused send is
-- retried at the end of the next frame, a send that raises is said once, and destroy() forgets everything. The canvas
-- frames (hud:frame) are the same module's other job and are only checked not to be disturbed. The mission's fields of the state
-- (the class's name, the abilities its class allows, the hold) are the HUD module's; here they are only shown to travel whole.
--
-- Run from this resource's directory with any Lua 5.4 (from elsewhere, pass the resource's directory with its trailing slash):
--   lua tests/render.test.lua
local root = ... or "./"
local passed = 0
local report = print
print = function() end

local function test(name, fn)
    local ok, err = pcall(fn)
    assert(ok, name .. ": " .. tostring(err))
    passed = passed + 1
    report("PASS " .. name)
end

package.path = root .. "?.lua;" .. package.path

local now, logs, pages, created = 100.0, {}, {}, 0
local createFails = false

-- A page as the host gives it: handlers the test fires by hand, and every send recorded; `accept` decides what send answers.
local function newPage()
    local page = { handlers = {}, sent = {}, accept = true, raises = false, destroyed = false }
    function page:on(event, handler) self.handlers[event] = handler end
    function page:send(event, payload)
        if self.raises then error("the page is gone", 0) end
        self.sent[#self.sent + 1] = { event = event, payload = payload }
        return self.accept
    end
    function page:destroy() self.destroyed = true end
    return page
end

Open77 = {
    time = { monotonic = function() return now end },
    log = {
        warn = function(text) logs[#logs + 1] = { "warn", text } end,
        error = function(text) logs[#logs + 1] = { "error", text } end,
    },
    screen = { surface = function() return { ready = true, width = 1920, height = 1080 } end },
    webui = {
        create = function()
            if createFails then return nil, "denied" end
            created = created + 1
            local page = newPage()
            pages[#pages + 1] = page
            return page
        end,
    },
}

local function load()
    package.loaded["render"], package.loaded["ui.hud_font"] = nil, nil
    for i = #logs, 1, -1 do logs[i] = nil end
    for i = #pages, 1, -1 do pages[i] = nil end
    now, created, createFails = now + 100.0, 0, false
    return dofile(root .. "render.lua")
end

local function states(page)
    local list = {}
    for _, entry in ipairs(page.sent) do if entry.event == "hud:state" then list[#list + 1] = entry.payload end end
    return list
end

local function frames(page)
    local count = 0
    for _, entry in ipairs(page.sent) do if entry.event == "hud:frame" then count = count + 1 end end
    return count
end

-- The module with its page created and announced (the document said "ui:ready").
local function ready()
    local render = load()
    render.beginFrame()
    local page = pages[1]
    assert(page, "the page was not created")
    page.handlers["ui:ready"]({ font = true })
    return render, page
end

test("a state asked for before the page is up is kept and sent when the page announces itself, with the hints on", function()
    local render = load()
    local state = { on = true, weapon = { name = "XO-16" } }
    render.state(state)                                        -- no page yet: nothing to send to
    render.beginFrame()
    local page = pages[1]
    assert(page and #page.sent == 0, "the page is not ready: nothing is sent")
    render.endFrame()
    assert(#page.sent == 0)
    page.handlers["ui:ready"]({ font = true })
    render.beginFrame()
    render.endFrame()
    local sent = states(page)
    assert(#sent == 1, "one state, once the page is ready")
    assert(sent[1].on == true and sent[1].weapon.name == "XO-16" and sent[1].hints == true)
    assert(state.hints == nil, "the module's own table is never changed")
    render.endFrame()
    assert(#states(page) == 1, "nothing is sent twice")
end)

test("a new state and a clear are sent at once; a clear is { on = false } and carries nothing else", function()
    local render, page = ready()
    render.state({ on = true, hull = { hull = 1 } })
    assert(#states(page) == 1 and states(page)[1].hull.hull == 1)
    render.state({ on = true, hull = { hull = 2 } })
    assert(#states(page) == 2 and states(page)[2].hull.hull == 2)
    render.state(nil)
    local cleared = states(page)[3]
    assert(#states(page) == 3 and cleared.on == false and cleared.hull == nil and cleared.hints == nil)
    assert(not pcall(render.state, 5), "a state is a table or nil")
end)

test("the control hints' switch rides on every state and a toggle resends the state that is up", function()
    local render, page = ready()
    render.toggleHints()
    assert(#states(page) == 0, "nothing is up: nothing to resend")
    render.toggleHints()
    render.state({ on = true })
    assert(states(page)[1].hints == true)
    assert(render.toggleHints() == false)
    assert(#states(page) == 2 and states(page)[2].hints == false and states(page)[2].on == true)
    render.state({ on = true, core = { share = 0.5 } })
    assert(states(page)[3].hints == false, "the switch stays off for the next state")
    assert(render.toggleHints() == true)
    assert(states(page)[4].hints == true and states(page)[4].core.share == 0.5)
end)

test("a mission's class name, allowed abilities and hold travel with the state as they are, and change it when they change", function()
    local render, page = ready()
    local allowed = { missiles = true, vortex = true, smoke = false, dash = false, jets = true, sentry = false, flight = false,
        designator = false, core = true }
    local state = { on = true, className = "Vanguard", allowed = allowed, held = true }
    render.state(state)
    local sent = states(page)
    assert(#sent == 1 and sent[1].className == "Vanguard" and sent[1].held == true and sent[1].hints == true)
    for name, value in pairs(allowed) do assert(sent[1].allowed[name] == value, name) end
    assert(state.hints == nil and state.allowed == allowed, "the module's own table is never changed")
    -- the next state of the same Titan, released and with another class: each is a new state for the page
    render.state({ on = true, className = "Ronin", allowed = { dash = true, smoke = true, core = true }, held = false })
    sent = states(page)
    assert(#sent == 2 and sent[2].className == "Ronin" and sent[2].held == false and sent[2].allowed.dash == true)
    assert(sent[2].allowed.missiles == nil, "a state is sent as it is: the page decides what an absent ability means")
    -- no class at all: the fields are simply absent
    render.state({ on = true })
    sent = states(page)
    assert(#sent == 3 and sent[3].className == nil and sent[3].allowed == nil and sent[3].held == nil)
    -- a page that reloads is given the mission's fields again
    render.state({ on = true, className = "Legion", held = true })
    page.handlers["ui:ready"]({ font = true })
    render.endFrame()
    sent = states(page)
    assert(#sent == 5 and sent[5].className == "Legion" and sent[5].held == true)
end)

test("a page that reloads is given the state again; a cleared page needs nothing", function()
    local render, page = ready()
    render.state({ on = true, weapon = { name = "XO-16" } })
    assert(#states(page) == 1)
    page.handlers["ui:ready"]({ font = true })                 -- the document loaded again
    render.endFrame()
    assert(#states(page) == 2 and states(page)[2].weapon.name == "XO-16")
    render.state(nil)
    page.handlers["ui:ready"]({ font = true })
    render.endFrame()
    assert(#states(page) == 3, "a blank page is the cleared page: no third state")
end)

test("a refused send is retried at the end of the next frame; a send that raises is said once and retried too", function()
    local render, page = ready()
    page.accept = false
    render.state({ on = true })
    assert(#states(page) == 1 and #logs == 0)
    render.endFrame()
    assert(#states(page) == 2, "retried")
    page.accept = true
    render.endFrame()
    assert(#states(page) == 3)
    render.endFrame()
    assert(#states(page) == 3, "taken: not sent again")
    page.raises = true
    render.state({ on = true, hull = {} })
    render.endFrame()
    render.state({ on = true, hull = { hull = 3 } })
    local warned = 0
    for _, entry in ipairs(logs) do if entry[2]:find("state could not be sent", 1, true) then warned = warned + 1 end end
    assert(warned == 1, "said once, however often it recurs")
    page.raises = false
    render.endFrame()
    assert(states(page)[#states(page)].hull.hull == 3, "the newest state is the one that goes out")
end)

test("the canvas frames are not disturbed by the state, and neither is sent when it has not changed", function()
    local render, page = ready()
    render.state({ on = true })
    render.beginFrame()
    render.line(0, 0, 10, 10, 0xffffffff, 2)
    render.endFrame()
    render.beginFrame()
    render.line(0, 0, 10, 10, 0xffffffff, 2)
    render.endFrame()
    assert(frames(page) == 1, "an identical frame is not sent twice")
    assert(#states(page) == 1)
end)

test("destroy forgets the state and the page; nothing is revived", function()
    local render, page = ready()
    render.state({ on = true })
    render.destroy()
    assert(page.destroyed)
    render.state({ on = true })
    render.beginFrame()
    render.endFrame()
    assert(#pages == 1 and #states(page) == 1, "no new page, nothing sent to the old one")
end)

report(passed .. " render tests passed")
