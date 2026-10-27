-- The roleplay bubbles LightRP sends to op77_actionbubble: /me (on the character),
-- /do (a state bubble at the spot), lock/unlock (on the vehicle), and nothing
-- breaks when the resource is not running.
local shown, commands, chatLines = {}, {}, {}
local running = true
_G.exports = setmetatable({}, { __index = function(_, name)
    if name ~= "op77_actionbubble" or not running then error("no such resource") end
    return { show = function(_, def) shown[#shown + 1] = def; return "s:" .. #shown end }
end })
_G.TriggerClientEvent = function(name, target, msg) chatLines[#chatLines + 1] = { target = target, msg = msg } end
_G.AddEventHandler = function() end
_G.CancelEvent = function() end
_G.RegisterCommand = function(name, fn) commands[name] = fn end
_G.Open77 = { players = { position = function() return { x = 10, y = 20, z = 30, bucket = 0 } end, positions = function() return {} end } }
_G.LightRpConfig = { chat = { icRange = 20, whisperRange = 4, shoutRange = 45, meRange = 20, requireCharacterForIc = true,
    colors = { ic = "#fff", me = "#c9a", ["do"] = "#9ac", ["try"] = "#aaa", whisper = "#ccc", shout = "#f80", system = "#ff0", ooc = "#888" } } }
_G.LightRP = {
    characters = { displayName = function(id) return "Alex Morgan" end, isRegistered = function() return true end },
    reply = function() end, log = function() end,
}
local modules = {}
function LightRP.module(name, def) def.name = name; modules[#modules + 1] = def; LightRP[name] = LightRP[name] or def; return def end
function LightRP.command(name, _, handler) commands[name] = function(source, args) return handler(source, args, "/" .. name) end end
function LightRP.joinArgs(args, from) return table.concat(args, " ", from or 1) end

dofile("server/modules/chat.lua")
dofile("server/modules/bubbles.lua")

-- /me: the chat line, and a bubble on the character (no name: in character), replicated around
commands.me(3, { "ouvre", "le", "coffre" })
local b = shown[#shown]
assert(b and b.text == "ouvre le coffre" and b.player == 3 and b.author == nil and b.kind == "action", "/me bubble")
assert(b.network and b.network.range == 20)
assert(chatLines[#chatLines].msg.text == "ouvre le coffre", "the chat line still goes")
-- /do: a state bubble at the spot (a point, not following the body)
commands["do"](3, { "La", "portière", "est", "verrouillée." })
b = shown[#shown]
assert(b.kind == "state" and b.position and b.position.z == 31.2 and b.player == nil, "/do bubble at the spot")
-- the L key: on the vehicle, signed by who did it
LightRP.bubbles.onVehicleLockChanged(77, true, 3)
b = shown[#shown]
assert(b.vehicle == 77 and b.text == "Locks the vehicle" and b.icon == "lock")
LightRP.bubbles.onVehicleLockChanged(77, false, 3)
assert(shown[#shown].text == "Unlocks the vehicle" and shown[#shown].icon == "unlock")
-- a lock changed by the server (no player): no bubble
local n = #shown
LightRP.bubbles.onVehicleLockChanged(77, true, nil)
assert(#shown == n)
-- the resource is not running: /me still sends its chat line, no error
running = false
local lines = #chatLines
commands.me(3, { "sourit" })
assert(#chatLines == lines + 1 and #shown == n, "no bubble resource: chat only")
print("PASS: /me bubble on the character, /do state bubble at the spot, lock/unlock on the vehicle, nothing without the resource")
