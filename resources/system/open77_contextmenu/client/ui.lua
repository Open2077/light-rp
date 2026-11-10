-- The Light RP ALT context menu on NativeUI (ui/contextmenu.rml): the TargetEye and the
-- ContextMenu column of the Open//77 RP design system.
--
-- client/main.lua keeps every decision (targeting, predicates, dynamic rows, revalidation,
-- input claims) and talks to this module through the page API it used with the WebUI page:
-- page:on(event, fn), page:send(event, payload), show, hide, setFocus, hasFocus, destroy.
-- Events this surface raises: context:ready, context:pick {epoch,x,y},
-- context:select {epoch,token}, context:cancel {epoch} and context:blur (reason), the last
-- when the input lease is taken away or refused.
--
-- Presentation only: folders (submenus) fold rows main.lua already authorised, and
-- navigation never dispatches an action.
ContextMenuUi = {}
local M = ContextMenuUi

M.DEFAULT_ACCENT = "#FFCC00"
M.MENU_WIDTH = 252    -- dp, keep in step with #menu in contextmenu.rcss
M.EYE = 40            -- dp, the eye's box; its gap to the menu is 10
M.ROW_HEIGHT = 32     -- dp, estimates for keeping the column on screen
M.GROUP_HEIGHT = 23
M.HEAD_HEIGHT = 25
M.LEGEND_HEIGHT = 23
M.STATUS_HEIGHT = 29
M.DESC_HEIGHT = 30
M.MAX_LIST = 860      -- dp, #rows max-height

-- Lucide glyphs (the design system's icon set) as one path each, 24 x 24: no icon font,
-- no remote asset, no provider markup. The registry only accepts the first seven names.
M.ICONS = {
    interact = "M18 11V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2 M14 10V4a2 2 0 0 0-2-2a2 2 0 0 0-2 2v2 M10 10.5V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2v8 M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15",
    person = "M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2 M8 7a4 4 0 1 0 8 0a4 4 0 1 0-8 0z",
    vehicle = "M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2 M5 17a2 2 0 1 0 4 0a2 2 0 1 0-4 0z M9 17h6 M15 17a2 2 0 1 0 4 0a2 2 0 1 0-4 0z",
    info = "M2 12a10 10 0 1 0 20 0a10 10 0 1 0-20 0z M12 16v-4 M12 8h.01",
    lock = "M5 11h14a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2z M7 11V7a5 5 0 0 1 10 0v4",
    tool = "M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z",
    location = "M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0 M9 10a3 3 0 1 0 6 0a3 3 0 1 0-6 0z",
    eye = "M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0a1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0 M9 12a3 3 0 1 0 6 0a3 3 0 1 0-6 0z",
    ban = "M2 12a10 10 0 1 0 20 0a10 10 0 1 0-20 0z M4.9 4.9l14.2 14.2",
    scan = "M3 7V5a2 2 0 0 1 2-2h2 M17 3h2a2 2 0 0 1 2 2v2 M21 17v2a2 2 0 0 1-2 2h-2 M7 21H5a2 2 0 0 1-2-2v-2",
    forward = "M9 5l7 7-7 7",
    back = "M15 5l-7 7 7 7",
}

-- Header: what was hit and how far. Identifiers stay strings (64-bit safe).
local KIND_LABELS = { player = "PLAYER", vehicle = "VEHICLE", npc = "NPC", prop = "PROP", door = "DOOR", device = "DEVICE",
    item = "ITEM", object = "OBJECT", world = "WORLD", sky = "SKY" }

local function clamp(v, a, b) return v < a and a or (v > b and b or v) end

--- Text safe to place inside RML: markup escaped, and no "{{" a data model would evaluate.
function M.escape(value)
    local text = tostring(value == nil and "" or value)
    text = text:gsub("[%c]", " ")
    text = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
    text = text:gsub("{", "{ "):gsub("}", " }")
    return text
end
-- model strings are text nodes: only the braces need care
local function plain(value) return (tostring(value == nil and "" or value):gsub("[%c]", " "):gsub("{", "{ "):gsub("}", " }")) end

function M.safeColor(value)
    local text = tostring(value or "")
    return text:match("^#%x%x%x%x%x%x$") and text or M.DEFAULT_ACCENT
end

--- The accent as a stylesheet layer over contextmenu.rcss (every rule that uses it):
--- the colour, its quiet tint (.12) and its soft line (.28).
function M.theme(color)
    local c = M.safeColor(color)
    return table.concat({
        "#eye.available .ec { border-color: " .. c .. "; }",
        "#eye.available #eye-glyph { stroke: " .. c .. "; }",
        "#eye.available #hex { fill: " .. c .. "1F; }",
        "#head .np-top, #head .np-body { background-color: " .. c .. "; }",
        "#head .np-cut { fill: " .. c .. "; }",
        "#sheet { border-color: " .. c .. "47; }",
        "#rows .row.focus { background-color: " .. c .. "; }",
        "#rows .row.danger.focus { background-color: #FF2E3C; }",
        "#menu.busy #rows .row.pending { color: " .. c .. "; }",
        "#desc { border-left-color: " .. c .. "; }",
        ".spin { stroke: " .. c .. "; }",
        "#rows scrollbarvertical sliderbar { background-color: " .. c .. "; }",
    }, "\n")
end

--- Sizes for a configured scale (0.75 to 1.5): the eye and the column's width, as the page did.
function M.scaleSheet(scale)
    local k = clamp(tonumber(scale) or 1, 0.75, 1.5)
    if math.abs(k - 1) < 0.001 then return "" end
    local function dp(v) return ("%.1fdp"):format(v * k) end
    return table.concat({
        "#eye { width: " .. dp(M.EYE) .. "; height: " .. dp(M.EYE) .. "; }",
        "#core { left: " .. dp(8) .. "; top: " .. dp(8) .. "; width: " .. dp(24) .. "; height: " .. dp(24) .. "; }",
        "#hex { width: " .. dp(24) .. "; height: " .. dp(24) .. "; }",
        "#eye-glyph { left: " .. ("%.1fdp"):format((24 * k - 15) / 2) .. "; top: " .. ("%.1fdp"):format((24 * k - 15) / 2) .. "; }",
        "#menu { width: " .. dp(M.MENU_WIDTH) .. "; }",
    }, "\n")
end

--- What the header names: { head, tag } ("VEHICLE", "#0042 // 3.2M").
function M.describeTarget(target, distance)
    local t = type(target) == "table" and target or {}
    local kind = tostring(t.kind or "world"):lower()
    local head = t.isLocalPlayer and "YOU" or (KIND_LABELS[kind] or kind:upper())
    local parts = {}
    local function tail(id) return "#" .. tostring(id):sub(-4) end
    if t.playerId ~= nil and not t.isLocalPlayer then
        local id = tostring(t.playerId)
        if math.type(t.playerId) == "float" and t.playerId == math.floor(t.playerId) then id = tostring(math.floor(t.playerId)) end
        parts[#parts + 1] = "ID " .. ("0"):rep(math.max(0, 3 - #id)) .. id
    elseif t.vehicleId ~= nil then parts[#parts + 1] = tail(t.vehicleId)
    elseif t.npcId ~= nil then parts[#parts + 1] = tail(t.npcId)
    elseif t.propId ~= nil then parts[#parts + 1] = tail(t.propId) end
    if kind == "npc" and type(t.record) == "string" then
        head = t.record:gsub("^Character%.", ""):gsub("_", " "):upper():sub(1, 22)
    end
    local d = tonumber(distance)
    if type(distance) == "number" and d == d and math.abs(d) < math.huge then
        parts[#parts + 1] = d < 10 and (("%.1f"):format(d) .. "M") or (tostring(math.floor(d + 0.5)) .. "M")
    end
    return { head = head, tag = table.concat(parts, " // ") }
end

--- The rows on screen for the rows main.lua authorised: at the root, one row per action
--- and one per folder; in a folder, Back and its actions. Returns the entries and the
--- folder shown ({ id, label, icon }) or nil.
function M.entries(rows, submenu)
    rows = type(rows) == "table" and rows or {}
    local folder = nil
    if submenu ~= nil then
        for _, row in ipairs(rows) do
            if type(row) == "table" and type(row.submenu) == "table" and row.submenu.id == submenu then folder = row.submenu break end
        end
    end
    local entries, folders = {}, {}
    if folder then
        entries[1] = { label = "Back", icon = "back", back = true }
        for _, row in ipairs(rows) do
            if type(row) == "table" and type(row.submenu) == "table" and row.submenu.id == folder.id then
                entries[#entries + 1] = { label = row.label, icon = row.icon, token = row.token, description = row.description,
                    danger = row.danger == true, group = row.group }
            end
        end
    else
        for _, row in ipairs(rows) do
            if type(row) == "table" then
                if type(row.submenu) ~= "table" then
                    entries[#entries + 1] = { label = row.label, icon = row.icon, token = row.token, description = row.description,
                        danger = row.danger == true, group = row.group }
                elseif not folders[row.submenu.id] then
                    folders[row.submenu.id] = true
                    entries[#entries + 1] = { label = row.submenu.label, icon = row.submenu.icon, folder = row.submenu.id, group = row.group }
                end
            end
        end
    end
    return entries, folder
end

--- The entries as RML: group headings (optional), then rows r1..rN. Returns the RML and
--- the number of headings.
function M.rowsRml(entries, showGroups)
    local out, group, groups = {}, "", 0
    for i, entry in ipairs(entries) do
        if showGroups and entry.group and entry.group ~= "" and entry.group ~= group then
            group = entry.group
            groups = groups + 1
            out[#out + 1] = '<div class="grp"><span>' .. M.escape(group) .. '</span></div>'
        end
        local classes = "row" .. (entry.danger and " danger" or "") .. (entry.back and " back" or "") .. (entry.folder and " folder" or "")
        local icon = M.ICONS[entry.icon] or M.ICONS.interact
        local arrow = entry.folder and ('<path class="arrow" view-box="0 0 24 24" d="%s"/>'):format(M.ICONS.forward) or ""
        out[#out + 1] = ('<div class="%s" id="r%d"><div class="ic"><path class="gl" view-box="0 0 24 24" d="%s"/>'
            .. '<shape type="circle" class="spin"/></div><span class="lb">%s</span>%s</div>')
            :format(classes, i, icon, M.escape(entry.label), arrow)
    end
    return table.concat(out), groups
end

--- The key legend under the column: "kind" is open, rows, folder or none.
function M.legendRml(kind, key)
    key = M.escape(key)
    local dot = '<span class="lg-dot">·</span>'
    local function arrow(d) return ('<path class="lg-arrow" view-box="0 0 10 10" d="%s"/>'):format(d) end
    if kind == "rows" then
        return ("<span>HOLD [%s]</span>%s%s%s%s<span>ENTER</span>"):format(key, dot,
            arrow("M5 8.5V1.5M2 4.5L5 1.5L8 4.5"), arrow("M5 1.5V8.5M2 5.5L5 8.5L8 5.5"), dot)
    elseif kind == "folder" then
        return ("%s<span>BACK</span>%s<span>ESC CLOSE</span>"):format(arrow("M8.5 5H1.5M4.5 2L1.5 5L4.5 8"), dot)
    elseif kind == "none" then
        return ("<span>HOLD [%s]</span>%s<span>PICK ANOTHER TARGET</span>"):format(key, dot)
    end
    return ("<span>HOLD [%s]</span>"):format(key)
end

--- Where the eye and the column go for an anchor (ax, ay), fractions of a W x H screen,
--- in pixels: the eye centred on it; the column to its right, or to its left when it would
--- leave the screen, never past an edge. `menuHeight` is the column's estimated height (dp).
function M.place(ax, ay, width, height, scale, menuHeight)
    local r = math.max(0.5, height / 1080)
    local half, gap, margin = 20 * scale * r, 10 * scale * r, 8 * r
    local x, y = ax * width, ay * height
    local w, h = M.MENU_WIDTH * scale * r, (menuHeight or 0) * r
    local right = x + half + gap
    local flipped = right + w > width - margin
    local left = flipped and (x - half - gap - w) or right
    local function px(v) return math.floor(v + 0.5) end
    return {
        eyeLeft = px(clamp(x - half, margin, math.max(margin, width - half * 2 - margin))),
        eyeTop = px(clamp(y - half, margin, math.max(margin, height - half * 2 - margin))),
        left = px(clamp(left, margin, math.max(margin, width - w - margin))),
        top = px(clamp(y - half, margin, math.max(margin, height - h - margin))),
        flipped = flipped,
    }
end

--- The column's height (dp), near enough to keep it above the bottom edge.
function M.menuHeight(rowCount, groupCount, hasStatus, hasDesc)
    local list = math.min(M.MAX_LIST, 8 + (rowCount or 0) * M.ROW_HEIGHT + (groupCount or 0) * M.GROUP_HEIGHT)
    return M.HEAD_HEIGHT + list + (hasStatus and M.STATUS_HEIGHT or 0) + (hasDesc and M.DESC_HEIGHT or 0) + M.LEGEND_HEIGHT
end

local function defaults()
    return {
        shown = false, available = false, blocked = false, keyboard = false, busy = false, submenu = false,
        glyph = M.ICONS.eye, title = "TARGET", tag = "",
        status = "", hasStatus = false, statusError = false, statusLoading = false,
        desc = "", hasDesc = false,
    }
end

--- A surface with the page API client/main.lua uses.
function M.create(config)
    if type(Open77) ~= "table" or type(Open77.ui) ~= "table" or type(Open77.ui.create) ~= "function" then
        return nil, "nativeui_unavailable"
    end
    local appearance = type(config) == "table" and type(config.appearance) == "table" and config.appearance or {}
    if type(Open77.ui.loadFont) == "function" then
        local ok, done, why = pcall(Open77.ui.loadFont, "ui/fonts/share-tech-mono-400.ttf", "Share Tech Mono", false)
        if not ok or not done then print("[contextmenu] font not loaded: " .. tostring(ok and why or done)) end
    end
    -- The HUD lab (tools/native-lab) sets Op77UiLab before this script loads: the document
    -- is then drawn on its layer (above the pre-game shell). Absent, nothing changes.
    local lab = type(Op77UiLab) == "table" and Op77UiLab or nil
    local ui, why = Open77.ui.create({
        document = "ui/contextmenu.rml", layer = lab and lab.layer or "hud", zIndex = 60, visible = true,
        models = { cm = defaults() },
    })
    if not ui then return nil, why end

    local page = { handlers = {} }
    -- DOM listeners, kept by name so that the lab can replay an input without the lease
    local listeners = {}
    local function listen(kind, selector, fn)
        if fn == nil then
            fn, selector = selector, ""
            ui:on(kind, fn)
        else
            ui:on(kind, selector, fn)
        end
        listeners[kind .. "|" .. selector] = fn
    end
    local S = {
        opened = false, epoch = 0, busy = false, shown = false, anchor = { x = 0.5, y = 0.5 },
        rows = {}, submenu = nil, entries = {}, groups = 0, focus = nil, head = { head = "TARGET", tag = "" },
        key = "ALT", accent = nil, scale = 1, scaleApplied = nil, showGroups = false, width = nil, height = nil,
        hasStatus = false, hasDesc = false, spinning = false,
    }

    local function emit(name, payload)
        local fn = page.handlers[name]
        if fn then fn(payload) end
    end
    local function screen()
        local ok, state = pcall(ui.state, ui)
        if ok and type(state) == "table" and tonumber(state.width) and tonumber(state.width) > 0 and tonumber(state.height) and tonumber(state.height) > 0 then
            S.width, S.height = tonumber(state.width), tonumber(state.height)
        end
        return S.width or 1920, S.height or 1080
    end
    local function applyAppearance(value)
        value = type(value) == "table" and value or {}
        -- the design system's accent is the default; the config may still recolour
        local accent = M.safeColor(value.accentColor)
        if accent ~= S.accent then
            S.accent = accent
            ui:stylesheet("accent", M.theme(accent))
        end
        local scale = tonumber(value.scale)
        scale = (scale and scale == scale) and clamp(scale, 0.75, 1.5) or 1
        if scale ~= S.scale or S.scaleApplied == nil then
            S.scale, S.scaleApplied = scale, true
            ui:stylesheet("scale", M.scaleSheet(scale))
        end
        S.showGroups = value.showGroups == true
    end

    -- ---- placement -----------------------------------------------------------------------------
    local function place()
        local w, h = screen()
        local p = M.place(S.anchor.x, S.anchor.y, w, h, S.scale, M.menuHeight(#S.entries, S.groups, S.hasStatus, S.hasDesc))
        ui:style("#eye", { left = p.eyeLeft .. "px", top = p.eyeTop .. "px" })
        if S.shown then ui:style("#menu", { left = p.left .. "px", top = p.top .. "px" }) end
    end
    local function message(text, loading, isError)
        text = text and tostring(text) or ""
        S.hasStatus = text ~= ""
        ui:merge("cm", { status = plain(text), hasStatus = S.hasStatus, statusError = isError == true,
            statusLoading = loading == true, blocked = isError == true })
        if loading and not S.spinning then
            S.spinning = true
            ui:keyframes("#status-spin .spin", { channel = "rotate", stops = { { offset = 0, value = 0 }, { offset = 1, value = 360 } },
                duration = 0.65, iterations = -1 })
        elseif not loading and S.spinning then
            S.spinning = false
            ui:stop("#status-spin .spin")
        end
        place()
    end
    local function describe(text)
        text = text and tostring(text) or ""
        local had = S.hasDesc
        S.hasDesc = text ~= ""
        ui:merge("cm", { desc = plain(text), hasDesc = S.hasDesc })
        if had ~= S.hasDesc then place() end
    end
    local function setLegend(kind) ui:rml("#legend", M.legendRml(kind, S.key)) end

    -- ---- focus, rows ---------------------------------------------------------------------------
    -- Mouse hover and keyboard share one highlighted row; its description shows under the list.
    local function setRowFocus(index, keyboard)
        if index ~= S.focus then
            if S.focus then ui:class("#r" .. S.focus, "focus", false) end
            S.focus = index
            if index then
                ui:class("#r" .. index, "focus", true)
                if keyboard then ui:scrollTo("#r" .. index, "nearest", true) end
            end
        end
        ui:set("cm", "keyboard", keyboard == true)
        describe(index and S.entries[index] and S.entries[index].description or "")
    end
    local renderRows
    local function goBack(keyboard)
        if S.busy or not S.submenu then return false end
        local previous = S.submenu
        S.submenu = nil
        renderRows(keyboard, previous)
        return true
    end
    renderRows = function(keyboard, restoreFolder)
        local entries, folder = M.entries(S.rows, S.submenu)
        if not folder then S.submenu = nil end
        local rml, groups = M.rowsRml(entries, S.showGroups)
        S.entries, S.groups, S.focus = entries, groups, nil
        ui:rml("#rows", rml)
        local any = #entries > 0
        ui:merge("cm", { title = plain(folder and folder.label or S.head.head), tag = plain(S.head.tag), submenu = folder ~= nil,
            available = any, glyph = any and M.ICONS.eye or M.ICONS.ban, keyboard = keyboard == true, busy = false })
        describe("")
        message(any and "" or "No actions")
        setLegend(any and (folder and "folder" or "rows") or "none")
        if any then ui:scrollTo("#r1", true) end
        -- Coming back, the folder keeps the highlight. Opening with the keyboard highlights
        -- the first real action, not Back.
        local target = nil
        if restoreFolder then
            for i, entry in ipairs(entries) do if entry.folder == restoreFolder then target = i break end end
        end
        if not target and keyboard and any then
            target = 1
            for i, entry in ipairs(entries) do if entry.token ~= nil then target = i break end end
        end
        if target then setRowFocus(target, keyboard) end
    end
    local function activate(index, keyboard)
        local entry = index and S.entries[index]
        if not S.opened or S.busy or not entry then return end
        if entry.back then goBack(keyboard) return end
        if entry.folder then S.submenu = entry.folder; renderRows(keyboard) return end
        S.busy = true
        -- the rows wait (dimmed): none stays highlighted
        if S.focus then ui:class("#r" .. S.focus, "focus", false); S.focus = nil end
        ui:set("cm", "busy", true)
        emit("context:select", { epoch = S.epoch, token = entry.token })
    end
    local function moveFocus(step, absolute)
        local n = #S.entries
        if n == 0 or S.busy then return end
        local index
        if absolute == "first" then index = 1
        elseif absolute == "last" then index = n
        elseif not S.focus then index = step < 0 and n or 1
        else index = (S.focus - 1 + step) % n + 1 end
        setRowFocus(index, true)
    end
    local function clearRows()
        S.rows, S.submenu, S.entries, S.groups, S.focus = {}, nil, {}, 0, nil
        ui:rml("#rows", "")
    end
    local function stopRowSpinners()
        for i in ipairs(S.entries) do
            ui:class("#r" .. i, "pending", false)
            ui:stop("#r" .. i .. " .spin")
        end
    end

    -- ---- page API ------------------------------------------------------------------------------
    function page.on(_, name, fn) page.handlers[name] = fn end
    function page.show() ui:show(); return true end
    function page.hide() ui:hide(); return true end
    function page.hasFocus() return ui:hasFocus() == true end
    function page.setFocus(_, keyboard, cursor)
        if keyboard or cursor then
            local ok = ui:focus({ keyboard = true, cursor = true })
            return ok ~= false and ok ~= nil
        end
        ui:blur()
        return true
    end
    function page.destroy() pcall(ui.destroy, ui) end

    function page.send(_, name, p)
        p = type(p) == "table" and p or {}
        if name == "context:open" then
            S.opened, S.epoch, S.busy, S.shown = true, tonumber(p.epoch) or 0, false, false
            S.anchor = { x = 0.5, y = 0.5 } -- the lease puts the pointer at the centre of the screen
            S.key = tostring(p.key or "ALT"):upper():sub(1, 12)
            applyAppearance(p.appearance)
            clearRows()
            S.hasDesc = false
            ui:merge("cm", { shown = false, available = false, blocked = false, keyboard = false, busy = false, submenu = false,
                glyph = M.ICONS.eye, desc = "", hasDesc = false })
            message("")
            ui:show()
            place()
            -- A hidden document publishes no state: until it has drawn once, screen() only
            -- knows the 1920 x 1080 reference, and the eye sat off centre at any other size.
            -- Place it again once the real screen size is in.
            local epoch = S.epoch
            if type(CreateThread) == "function" then CreateThread(function()
                for _ = 1, 4 do
                    Wait(0)
                    if not S.opened or S.epoch ~= epoch or S.shown then return end
                    place()
                end
            end) end
        elseif name == "context:close" then
            S.opened, S.busy, S.shown = false, false, false
            clearRows()
            if S.spinning then S.spinning = false; ui:stop("#status-spin .spin") end
            ui:merge("cm", { shown = false, available = false, blocked = false, busy = false })
        elseif name == "context:loading" then
            local epoch = tonumber(p.epoch)
            if not S.opened or not epoch or epoch ~= math.floor(epoch) or epoch < S.epoch then return end
            S.epoch, S.busy = epoch, true
            S.anchor = { x = clamp(tonumber(p.x) or 0.5, 0, 1), y = clamp(tonumber(p.y) or 0.5, 0, 1) }
            local first = not S.shown
            S.shown = true
            clearRows()
            S.hasDesc = false
            ui:merge("cm", { shown = true, available = false, glyph = M.ICONS.scan, title = "SCANNING", tag = "",
                desc = "", hasDesc = false, submenu = false, busy = false, keyboard = false })
            setLegend("open")
            message("Looking…", true)
            -- the page's wipe-in, as a short fade from the eye's side
            if first then ui:animate("#menu", { from = { opacity = 0, x = -8 }, to = { opacity = 1, x = 0 }, duration = 0.12, easing = "ease-out" }) end
        elseif name == "context:empty" then
            if not S.opened or p.epoch ~= S.epoch then return end
            S.busy = false
            ui:merge("cm", { glyph = M.ICONS.ban, title = "NO TARGET", tag = "" })
            message("No target", false, true)
            describe(p.message and tostring(p.message):sub(1, 180) or "")
        elseif name == "context:menu" then
            if not S.opened or p.epoch ~= S.epoch then return end
            S.busy, S.submenu = false, nil
            S.head = M.describeTarget(p.target, p.distance)
            -- A dynamic-rows provider may name what was clicked (e.g. a game table).
            if type(p.title) == "string" and p.title ~= "" then S.head.head = p.title:sub(1, 40):upper() end
            S.rows = type(p.actions) == "table" and p.actions or {}
            renderRows(false)
        elseif name == "context:busy" then
            if not S.opened or p.epoch ~= S.epoch then return end
            S.busy = true
            ui:set("cm", "busy", true)
            for i, entry in ipairs(S.entries) do
                if entry.token ~= nil and tostring(entry.token) == tostring(p.token) then
                    ui:class("#r" .. i, "pending", true)
                    ui:keyframes("#r" .. i .. " .spin", { channel = "rotate",
                        stops = { { offset = 0, value = 0 }, { offset = 1, value = 360 } }, duration = 0.65, iterations = -1 })
                    entry.failed = true
                end
            end
        elseif name == "context:error" then
            if not S.opened or p.epoch ~= S.epoch then return end
            S.busy = false
            stopRowSpinners()
            -- the row that failed keeps an "info" glyph, as the page did
            for i, entry in ipairs(S.entries) do
                if entry.failed then entry.failed = nil; ui:attr("#r" .. i .. " .gl", "d", M.ICONS.info) end
            end
            ui:set("cm", "busy", false)
            message("Action unavailable", false, true)
            describe(p.message and tostring(p.message):sub(1, 180) or "Try again.")
        end
    end

    -- ---- input ---------------------------------------------------------------------------------
    -- The event's own coordinates (the lease's pointer), never the system cursor.
    local function mouse(e)
        local x, y = tonumber(e and e.mouse_x), tonumber(e and e.mouse_y)
        if not x or not y then return nil end
        return x, y
    end
    local function rowIndex(e) return tonumber(tostring(e and e.id or ""):match("^r(%d+)$")) end
    listen("mousemove", "#hit", function(e)
        -- the eye follows the pointer until a pick shows the column
        if not S.opened or S.shown then return end
        local x, y = mouse(e)
        if not x then return end
        local w, h = screen()
        S.anchor = { x = clamp(x / w, 0, 1), y = clamp(y / h, 0, 1) }
        place()
    end)
    listen("click", "#hit", function(e)
        if not S.opened or S.busy then return end
        local x, y = mouse(e)
        if not x then return end
        local w, h = screen()
        local nx, ny = x / w, y / h
        if nx ~= nx or ny ~= ny or nx < 0 or nx > 1 or ny < 0 or ny > 1 then return end
        emit("context:pick", { epoch = S.epoch, x = nx, y = ny })
    end)
    listen("mousedown", function(e)
        -- right click: back out of a folder, else close
        if not S.opened or tonumber(e and e.button) ~= 1 then return end
        if not S.busy and not goBack(false) then emit("context:cancel", { epoch = S.epoch }) end
    end)
    listen("mouseover", ".row", function(e)
        if not S.opened or S.busy then return end
        local index = rowIndex(e)
        if index then setRowFocus(index, false) end
    end)
    listen("click", ".row", function(e) activate(rowIndex(e), false) end)
    listen("keydown", function(e)
        if not S.opened then return end
        local key = tostring(e.key or ""):lower()
        if key == "escape" then emit("context:cancel", { epoch = S.epoch })
        elseif key == "left" or key == "backspace" or key == "back" then goBack(true)
        elseif key == "right" then
            if not S.busy and S.focus and S.entries[S.focus] and S.entries[S.focus].folder then activate(S.focus, true) end
        elseif key == "down" then moveFocus(1)
        elseif key == "up" then moveFocus(-1)
        elseif key == "home" then moveFocus(0, "first")
        elseif key == "end" then moveFocus(0, "last")
        elseif key == "enter" or key == "return" or key == "numpadenter" or key == "space" then activate(S.focus, true) end
    end)

    if lab then
        -- lab only: replay a DOM event (the pre-game shell keeps the keyboard and the mouse)
        function page.labInput(_, kind, selector, e)
            local fn = listeners[kind .. "|" .. (selector or "")]
            if fn then fn(e or {}) end
        end
    end

    -- ---- lifecycle -----------------------------------------------------------------------------
    local function ready()
        S.accent, S.scaleApplied = nil, nil
        applyAppearance(appearance)
        ui:hide()
        emit("context:ready")
    end
    ui:onEvent("loaded", ready)
    ui:onEvent("reloaded", function()
        S.accent, S.scaleApplied = nil, nil
        applyAppearance(appearance)
        if S.opened then emit("context:blur", "reloaded") else ui:hide() end
    end)
    -- The menu closes only on these: the lease taken by someone else, or refused.
    ui:onEvent("focus", function(kind, detail)
        if kind == "blur" and S.opened then emit("context:blur", detail and detail.reason or "blur") end
    end)
    ui:onEvent("error", function(kind, detail)
        local text = tostring(detail and detail.message or "")
        if kind == "focus" then
            if S.opened then emit("context:blur", text ~= "" and text or "focus_unavailable") end
            return
        end
        print("[contextmenu] UI " .. tostring(kind) .. ": " .. text)
    end)
    return page
end
