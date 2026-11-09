-- op77_map3d native modules: SVG icons to NativeUI paths, the theme layer, config merge.
-- pwsh -File tests/run-lua.ps1 -Test native_test.lua
dofile("client/native/defaults.lua")
dofile("client/native/theme.lua")
dofile("client/native/icons.lua")
local D, T, I = Map3DDefaults, Map3DTheme, Map3DIcons

-- colours
local r, g, b, a = T.parse("#FFCC00")
assert(r == 255 and g == 204 and b == 0 and a == 255)
r, g, b, a = T.parse("rgba(34, 216, 226, 0.35)")
assert(r == 34 and g == 216 and b == 226 and a == 89, "rgba alpha " .. tostring(a))
assert(T.hex("#ffcc00", 0.5) == "#ffcc0080")
assert(T.hex("not a colour", nil, "#112233") == "#112233ff", "a bad colour falls back")
assert(T.mix("#000000", "#ffffff", 0.5) == "#808080")

-- the theme layer carries the theme's own colours, no token left
local rcss = T.rcss({ accent = "#22d8e2", danger = "#ff3b4e", panel = "rgba(11, 14, 20, 0.82)" })
assert(rcss:find("#22d8e2ff", 1, true) and rcss:find("#ff3b4eff", 1, true) and rcss:find("#0b0e14d1", 1, true))
assert(not rcss:find("{%a+}"), "every token is replaced")

-- icons: circles and rects become path data; a line icon keeps no fill
local d = I.pathData('<circle cx="12" cy="10" r="2.4"/>')
assert(d:match("^M9%.6 10A2%.4 2%.4 0 1 0 14%.4 10"), d)
local rect = I.pathData('<rect x="3.5" y="7.5" width="17" height="12" rx="1"/>')
assert(rect:find("^M4%.5 7%.5H19%.5A1 1 0 0 1 20%.5 8%.5"), rect)
local pin = I.rml("pin")
assert(pin:find('class="ic ic%-line') and pin:find('view%-box="0 0 24 24"'), pin)
assert(I.rml("no-such-icon") == pin, "an unknown icon is the pin")
-- a resource's own filled SVG with a <g transform>: translate(12 12) scale(2) translate(-12 -12)
local filled, isFilled = I.pathData('<svg viewBox="0 0 24 24" fill="currentColor"><g transform="translate(12 12) scale(2) translate(-12 -12)"><path d="M12 12h1"/></g></svg>')
assert(isFilled and filled == "M12 12 h2 ", filled)
local gun = I.rml([[<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" fill-rule="evenodd"><path d="M3.2 4.2h17.6q.7 0 .3.6z"/></svg>]])
assert(gun:find("ic%-fill") and gun:find("M3%.2 4%.2h17%.6q%.7 0 %.3%.6z"), gun)
assert(I.rml("nui://x/icon.png"):find("<img"), "an image path stays an image")
assert(I.maneuver("left"):find("ic%-man"))

-- config merge: objects merge, arrays replace, nil keeps
local cfg = D.copy(D.config)
D.merge(cfg, { theme = { accent = "#22d8e2" }, minimap = { margin = { 10, 12 } }, categories = { { id = "x", label = "X" } } })
assert(cfg.theme.accent == "#22d8e2" and cfg.theme.danger == "#ff2e3c")
assert(cfg.minimap.margin[1] == 10 and #cfg.minimap.margin == 2)
assert(#cfg.categories == 1 and cfg.categories[1].id == "x")
assert(D.config.theme.accent == "#ffcc00", "the defaults are never touched")

print("PASS: native icons, theme layer, config merge")
