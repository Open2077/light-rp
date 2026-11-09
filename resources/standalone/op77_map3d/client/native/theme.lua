-- The colours of the native map, as one RCSS layer (ui:stylesheet "theme") built
-- from the theme config: a setTheme / setConfig reaches every rule live.
Map3DTheme = {}
local T = Map3DTheme

--- "#RRGGBB", "#RRGGBBAA", "rgba(r,g,b,a)", "rgb(r,g,b)" -> r, g, b, a (0..255)
function T.parse(c, fallback)
    if type(c) ~= "string" then return T.parse(fallback or "#ffcc00") end
    local h = c:match("^#(%x+)$")
    if h then
        if #h == 3 then h = h:gsub("(%x)", "%1%1") end
        local r, g, b = tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)
        local a = #h >= 8 and tonumber(h:sub(7, 8), 16) or 255
        if r and g and b then return r, g, b, a end
    end
    local r, g, b, a = c:match("rgba?%(%s*([%d.]+)%s*,%s*([%d.]+)%s*,%s*([%d.]+)%s*,?%s*([%d.]*)%s*%)")
    if r then
        local alpha = tonumber(a) or 1
        return math.floor(tonumber(r) + 0.5), math.floor(tonumber(g) + 0.5), math.floor(tonumber(b) + 0.5), math.floor(alpha * 255 + 0.5)
    end
    return T.parse(fallback or "#ffcc00")
end

--- RmlUi colour "#rrggbbaa", with an optional alpha multiplier
function T.hex(c, alpha, fallback)
    local r, g, b, a = T.parse(c, fallback)
    if alpha then a = math.floor(math.max(0, math.min(1, alpha)) * 255 + 0.5) end
    return ("#%02x%02x%02x%02x"):format(r, g, b, a)
end

function T.mix(a, b, k)
    local r1, g1, b1 = T.parse(a)
    local r2, g2, b2 = T.parse(b)
    return ("#%02x%02x%02x"):format(math.floor(r1 + (r2 - r1) * k + 0.5), math.floor(g1 + (g2 - g1) * k + 0.5), math.floor(b1 + (b2 - b1) * k + 0.5))
end

local TEMPLATE = [[
body { color: {text}; }
.kbd { border-color: {line}; color: {accent}; }
.kbd.dim { color: {dim}; }
.dim { color: {dim}; }
.accent { color: {accent}; }
path.ic-line { stroke: {accent}; }
path.ic-fill { fill: {accent}; }

#mini-glass { background-color: {glass}; }
#mini-frame { border-width: 1dp; border-color: {line}; box-shadow: #00000099 0 0 0 1dp, #0000008c 0 12dp 32dp 0; }
.shape-chamfer #mini-frame { border-width: 0; decorator: fx(chamfer 14 1 0.0 0 {line}); box-shadow: none; }
.corner { border-color: {accent}; }
.shape-chamfer .corner-a, .shape-circle .corner { display: none; }
.north-mark { fill: {accent}; }
#mini-district { color: {text}; font-effect: shadow(0 1dp #000000); }
#mini-wp { color: {accent}; }
.nav { background-color: #08090cdb; border-left-color: {accent}; }
.nav path.ic { stroke: {accent}; }
.nav-text span { color: {dim}; }

.blip .pin { background-color: #050506e0; decorator: fx(chamfer 7 1.5 0.0 0 {accent}); }
.blip .label { background-color: #050506d9; border-left-color: {accent}; color: {text}; }
.blip .count { background-color: {accent}; color: #050506; box-shadow: #050506 0 0 0 2dp; }
.blip .ring { border-color: {accent}; }
.blip .arrow { fill: {accent}; stroke: #000000c0; stroke-width: 1dp; }
.blip.is-self .arrow { filter: glow(5dp {accent} 0.9); }
.is-perf .blip.is-self .arrow { filter: none; }


#full-backdrop { background-color: {backdrop}; }
#scan { background-color: {accent}; decorator: linear-gradient(90deg, #00000000 0%, {accent} 18%, #ffffff 50%, {accent} 82%, #00000000 100%); box-shadow: {accentSoft} 0 0 18dp 4dp; }
.glass-panel { background-color: {panel}; border-color: {line}; }
.tag { background-color: {accent}; color: #050506; }
#title { color: {text}; }
#subtitle { color: {accent}; }
#readout { color: {dim}; }
#ro-d { color: {accent}; }
#close { background-color: {panel}; border-width: 1dp; border-color: {line}; backdrop-filter: blur(14dp); }
#close:hover { border-color: {accent}; }
#routebar { border-left-color: {accent}; }
#routebar path.ic { stroke: {accent}; }
.rb-div { background-color: {line}; }
#rb-eta { color: {accent}; }
.danger-btn { border-color: {danger}; color: {danger}; }
.danger-btn:hover { background-color: {danger}; color: #050506; }
#search-field { border-left-color: {accent}; }
#search.is-active #search-field { border-color: {accent}; }
#search-input { color: {text}; }
#results { background-color: {panelSolid}; box-shadow: #00000099 0 12dp 32dp 0; }
.res-sub, .res-empty { color: {dim}; }
.res-dist { color: {accent}; }
.res.is-sel, .res:hover { background-color: {accentFaint}; border-left-color: {accent}; }
#legend { decorator: fx(chamfer 12 1 0.0 0 {line}); border-width: 0; }
#legend h3 { color: {dim}; }
.sw { border-color: {line}; color: {dim}; }
.sw.is-on { background-color: {accent}; border-color: {accent}; color: #050506; }
.cat-count { color: {dim}; }
.cat:hover, .tog:hover { background-color: {accentFaint}; }
.tog-state { border-color: {line}; color: {dim}; }
.tog.is-on .tog-state { background-color: {accent}; border-color: {accent}; color: #050506; }
.tog.is-off .tog-label { color: {dim}; }
.lvl-name { color: {text}; }
.lvl-min { color: {dim}; }
.tool { background-color: {panel}; border-color: {line}; color: {text}; backdrop-filter: blur(12dp); }
.tool:hover { border-color: {accent}; color: {accent}; }
#t-north-n { color: {accent}; }
#help { color: {dim}; }
#card { decorator: fx(chamfer 14 1 0.0 0 {line}); border-width: 0; }
.card-cat { color: {accent}; }
#card-desc { color: {dim}; }
.dt { color: {dim}; }
.solid-btn { background-color: {accent}; color: #050506; }
.solid-btn .kbd { color: #050506; border-color: #05050666; margin-left: 8dp; margin-right: 0; }
.solid-btn.is-clear .kbd { display: none; }
.solid-btn.is-clear { background-color: transparent; border-color: {danger}; color: {danger}; }
#perf { border-left-width: 2dp; border-left-color: {accent}; }
.perf-dot { background-color: {accent}; }
.perf-big { color: {accent}; }
.spark path { stroke: {accent}; }
.toast { background-color: {panel}; border-color: {accent}; color: {text}; backdrop-filter: blur(12dp); }
.toast.danger { border-color: {danger}; color: {danger}; }
.ld-title { color: {text}; }
.ld-stage { color: {accent}; }
.ld-bar { background-color: #ffffff14; }
.ld-fill { background-color: {accent}; }
.district span { color: #f2f3f58c; font-effect: outline(1dp #000000b0); }
.q-card { border-color: {line}; background-color: #ffffff05; }
.q-card.is-on { border-color: {accent}; background-color: {accentFaint}; box-shadow: {accentSoft} 0 0 0 1dp inset; }
.q-art { border-color: #ffffff0f; }
.q-art path { stroke: {dim}; }
.q-card.is-on .q-art path { stroke: {accent}; }
.q-tag, .q-sub { color: {accent}; }
.q-foot { color: {dim}; }
.jam-sweep { decorator: linear-gradient(180deg, #00000000 0%, {accentSoft} 50%, #00000000 100%); }
.jam-label { border-color: {accent}; color: {accent}; background-color: #050506cc; }
.jam-label path.ic { stroke: {accent}; }
]]

--- The RCSS layer for a theme table (the config's theme keys).
function T.rcss(theme)
    theme = theme or {}
    local accent = theme.accent or "#ffcc00"
    local tokens = {
        accent = T.hex(accent),
        accentSoft = T.hex(theme.accentSoft or accent, theme.accentSoft and nil or 0.22),
        accentFaint = T.hex(accent, 0.08),
        text = T.hex(theme.text or "#f2f3f5"),
        dim = T.hex(theme.textDim or "#8a8f9c"),
        danger = T.hex(theme.danger or "#ff2e3c"),
        panel = T.hex(theme.panel or "rgba(6,6,8,.82)"),
        panelSolid = T.hex(theme.panel or "#0b0c10", 0.96),
        line = T.hex(accent, 0.28),
        -- the glass behind the minimap and the map: the theme background, translucent over the blurred game
        glass = T.hex(theme.background or "#17191f", 0.42),
        backdrop = T.hex(theme.background or "#17191f", 0.38),
    }
    return (TEMPLATE:gsub("{(%a+)}", function(k) return tokens[k] or ("{" .. k .. "}") end))
end
