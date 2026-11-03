-- Crews, client side (server/modules/parties.lua decides everything):
--   ALT + click a player (open77_contextmenu): Invite to crew, Kick from crew,
--   Make crew leader; ALT + click yourself: Leave crew.
--   The invite keys (Y accept, N decline, rebindable in Pause > Settings > Key
--   bindings) answer the newest invite while the HUD prompt shows it.
-- The page draws the crew frame and the invite prompt from the "party" state;
-- client/core/ui.lua hands every "party" patch to Crew.sync first, which adds the
-- effective key names. The menu predicates below are only UX: a stale or forged
-- request is refused by the server.
local E, Ui = LightRpEvents, LightRpUi
local KEYS = LightRpConfig.keys
local resource = GetCurrentResourceName()

local Crew = { state = nil }
LightRpCrew = Crew

local function keyName(key) return key and (Open77.input and Open77.input.keyFor and Open77.input.keyFor(key.id)) or (key and key.key) or nil end
local function keyNames() return { accept = keyName(KEYS.crewAccept), decline = keyName(KEYS.crewDecline) } end

-- client/core/ui.lua: every "party" patch passes here before the page gets it.
function Crew.sync(party)
    if type(party) == "table" then
        party.keys = keyNames()
        Crew.state = party
    elseif party == false or party == nil then
        Crew.state = nil
    end
end
AddEventHandler("open77:keybinds:changed", function()
    if Crew.state then
        Crew.state.keys = keyNames()
        Ui.send(E.page.state, { party = Crew.state })
    end
end)

local function send(payload)
    local ok, reason = TriggerServerEvent(E.net.action, payload)
    if not ok then Ui.send(E.page.result, { ok = false, text = "Crew request failed: " .. tostring(reason), action = payload.type }) end
    return ok == true
end

-- A Light RP window holds the keyboard: the crew keys and the menu stay quiet.
local function busy()
    if not Ui.characterReady or Ui.actionFocus or Ui.menuOpen or Ui.promptActive then return true end
    for _, open in pairs(Ui.dialogs or {}) do if open then return true end end
    return false
end

-- ---------------------------------------------------------------------------
-- ALT + click

local function member(id)
    local s = Crew.state
    for _, m in ipairs(s and s.members or {}) do if m.id == id then return m end end
end
local function leads()
    local s = Crew.state
    return s ~= nil and s.id ~= nil and s.leader == s.you
end
local function invited(id)
    local s = Crew.state
    for _, p in ipairs(s and s.pending or {}) do if p.id == id then return true end end
    return false
end

local function targetOf(context)
    if GetInvokingResource() ~= "open77_contextmenu" or type(context) ~= "table" then return end
    local t = context.target
    if type(t) ~= "table" or t.kind ~= "player" or type(t.playerId) ~= "number" or t.playerId < 1 then return end
    if busy() then return end
    return t.playerId, context.kind == "self" or t.isLocalPlayer == true
end

local AVAILABLE = {
    invite = function(id, self)
        if self or member(id) or invited(id) then return false end
        local s = Crew.state
        if not s then return true end
        if s.id and s.leader ~= s.you then return false end
        return not s.members or #s.members < (s.maxSize or 8)
    end,
    kick = function(id, self) return not self and leads() and member(id) ~= nil end,
    lead = function(id, self) return not self and leads() and member(id) ~= nil end,
    leave = function(_, self) return self and Crew.state ~= nil and Crew.state.id ~= nil end,
}
local REQUEST = { invite = "party.invite", kick = "party.kick", lead = "party.promote", leave = "party.leave" }

local function choice(context)
    local id, self = targetOf(context)
    if not id then return end
    local data = type(context.action) == "table" and context.action.data
    local what = type(data) == "table" and data.crew
    local test = AVAILABLE[what]
    if test and test(id, self) then return what, id end
end
exports("crewContextAvailable", function(context) return choice(context) ~= nil end)
exports("crewContextSelect", function(context)
    local what, id = choice(context)
    if not what then return false end
    if what == "leave" then return send({ type = REQUEST.leave }) end
    return send({ type = REQUEST[what], target = id })
end)

local function register()
    local definitions = {
        { id = "crew.invite", label = "Invite to crew", icon = "person", types = { "player" }, group = "Crew", order = 1, distance = 15,
            canInteract = "crewContextAvailable", onSelect = "crewContextSelect", data = { crew = "invite" } },
        { id = "crew.lead", label = "Make crew leader", icon = "person", types = { "player" }, group = "Crew", order = 2, distance = 15,
            canInteract = "crewContextAvailable", onSelect = "crewContextSelect", data = { crew = "lead" } },
        { id = "crew.kick", label = "Kick from crew", icon = "lock", types = { "player" }, group = "Crew", order = 3, distance = 15, danger = true,
            canInteract = "crewContextAvailable", onSelect = "crewContextSelect", data = { crew = "kick" } },
        { id = "crew.leave", label = "Leave crew", icon = "person", types = { "player" }, group = "Crew", order = 4, distance = 15,
            allowSelf = true, selfOnly = true, canInteract = "crewContextAvailable", onSelect = "crewContextSelect", data = { crew = "leave" } },
    }
    local pending, reason = Open77.exports.call("open77_contextmenu", "registerMany", definitions)
    local tokens
    if pending then tokens, reason = pending:await() end
    if not tokens then Ui.log("crew context registration failed: %s", tostring(reason)); return end
    Ui.log("crew context ready: %d actions", #definitions)
end
AddEventHandler("onClientResourceStart", function(name)
    if name == resource or name == "open77_contextmenu" then register() end
end)

-- ---------------------------------------------------------------------------
-- The invite keys

local function newestInvite()
    local s = Crew.state
    return s and s.invites and s.invites[1] or nil
end
local function answer(accept)
    local invite = newestInvite()
    if not invite or busy() then return end
    -- the raid's ready check owns its key while it runs
    local raid = LightRpRaidClient and LightRpRaidClient.state
    if accept and raid and raid.phase == "ready" and keyName(KEYS.crewAccept) == keyName(KEYS.raidReady) then return end
    send({ type = accept and "party.accept" or "party.decline", party = invite.party })
end
for _, entry in ipairs({ { KEYS.crewAccept, true }, { KEYS.crewDecline, false } }) do
    local key, accept = entry[1], entry[2]
    if key then
        local ok, effective = RegisterKeyMapping(key.id, key.name, key.key, function() answer(accept) end)
        if not ok then Ui.log("crew key %s refused: %s", key.id, tostring(effective)) end
    end
end
