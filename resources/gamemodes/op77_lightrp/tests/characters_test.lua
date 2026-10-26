-- Civil-state validation and activation contract, no game or database connection.
dofile("shared/config.lua")
local noop = function() end
local actions, providers, handlers = {}, {}, {}
local activated, appearance = 0, nil
LightRP = {
    db = { ready = false, schema = noop, run = noop, query = function() return {} end,
        single = function(sql) if sql:find("open77_characters", 1, true) then return appearance end end },
    module = function(name, value) LightRP[name] = value; return value end,
    stateProvider = function(name, fn) providers[name] = fn end,
    action = function(name, fn) actions[name] = fn end,
    eachModule = function(event) if event == "onCharacterActivated" then activated = activated + 1 end end,
    state = noop, command = noop, notice = noop, nowMs = function() return 1000 end,
}
CreateThread = noop
AddEventHandler = function(name, fn) handlers[name] = fn end
GetPlayerName = function() return "Account" end
GetPlayerIdentifier = function() return "test-id" end
GetPlayers = function() return {} end
dofile("server/modules/characters.lua")
local C = LightRP.characters
local ok, reason = C.setIdentity(1, { firstName = "A1", lastName = "Morgan" })
assert(not ok and reason == "invalid_name")
for _, birth in ipairs({ "2053-02-29", "2052-04-31", "2052-13-01", "2060-01-01", "1986-01-01" }) do
    ok, reason = C.setIdentity(1, { firstName = "Alex", lastName = "Morgan", birthDate = birth })
    assert(not ok and reason == "invalid_birth_date", birth)
end
assert(C.setIdentity(1, { firstName = "Élodie", lastName = "O'Neil", birthDate = "2052-02-29", origin = "badlands", story = string.rep("é", 600) }))
local state = providers.character(1)
assert(state.maxAge == 90 and state.nameMinLength == 2 and state.nameMaxLength == 24 and state.nameAllowAccents)
assert(state.story == string.rep("é", 600), "UTF-8 story is not truncated by bytes")
assert(state.status == "draft" and state.step == "confirm", "local session skips required persistence")
assert(C.setIdentity(1, { firstName = "Alex", lastName = "Morgan", story = string.rep("é", 650) }))
assert(utf8.len(C.get(1).story) == 600)
ok, reason = C.setIdentity(1, { firstName = "Alex", lastName = "Morgan", story = string.char(255) })
assert(not ok and reason == "invalid_story")
LightRP.db.ready = true
ok, reason = C.finish(1)
assert(not ok and reason == "appearance_missing" and activated == 0)
appearance = { status = "active", body_family = "male", revision = 2 }
assert(C.finish(1))
assert(C.get(1).status == "active" and activated == 1)
assert(C.finish(1) and activated == 1, "activation/starter items cannot be duplicated")
local c=C.get(1)
c.birthDate,c.origin,c.story="2052-02-29","badlands","Existing character history"
LightRP.broadcastState=noop
LightRP.db.run=function()return false end
assert(not C.adminRename(1,"Jamie","Rivers") and c.firstName=="Alex","failed staff rename leaves local identity intact")
LightRP.db.run=function()return true end
assert(C.adminRename(1,"Jamie","Rivers") and c.firstName=="Jamie" and c.lastName=="Rivers")
assert(c.birthDate=="2052-02-29" and c.origin=="badlands" and c.story=="Existing character history","staff rename preserves civil state and backstory")
assert(c.status=="active" and activated==1,"staff rename never repeats character activation")
Open77={players={position=function()return {x=1000,y=2000,z=50,bucket=1000001}end}}
LightRP.housing={savedPosition=function()return {x=10,y=20,z=30}end,isBusy=function()return true end}
C.samplePosition(1)
assert(c.lastKnown.x==10 and c.lastKnown.z==30,"private interior coordinates are never saved as a public-world spawn")
local switched,why=C.select(1,"other")
assert(not switched and why=="busy","leave housing before switching characters")
local created,message=C.startNew(1)
assert(not created and message=="busy","creating another character cannot strand an instance or race a housing payment")
print("PASS: character identity, dates, limits, UTF-8, appearance gate, idempotent activation and durable staff rename preserving identity context")
