-- Offline test of the call state machine (server/calls.lua) with every
-- platform call mocked. Run from the resource folder with a Lua 5.4 interpreter:
--     lua54 tests/calls_test.lua
local failures, checks = 0, 0
local function check(cond, label)
    checks = checks + 1
    if not cond then failures = failures + 1; print("FAIL " .. label) end
end

-- ---------------------------------------------------------------------------
-- Platform mocks

local timers, now = {}, 1000000
function SetTimeout(ms, fn) timers[#timers + 1] = { at = now + ms, fn = fn } end
local function advance(ms)
    now = now + ms
    local due = {}
    for i = #timers, 1, -1 do if timers[i].at <= now then due[#due + 1] = table.remove(timers, i) end end
    for _, t in ipairs(due) do t.fn() end
end
function CreateThread() end
function Wait() end
function GetGameTimer() return now end
function GetPlayerRoutingBucket() return 0 end
function AddEventHandler() end
function GetCurrentResourceName() return "op77_neuralink" end

local sounds, soundSeq = {}, 0
function Play3DSound(file) soundSeq = soundSeq + 1; sounds[soundSeq] = file; return soundSeq end
function StopSound(id) sounds[id] = nil return true end
function DestroySound(id) sounds[id] = nil return true end
function SetSoundPosition() return true end
local function liveSounds() local n = 0 for _ in pairs(sounds) do n = n + 1 end return n end

local voice = { channels = {}, members = {}, seq = 0 }
Open77 = {
    time = { unix = function() return now / 1000 end },
    players = { position = function() return { x = 0, y = 0, z = 0, bucket = 0 } end },
    voice = {
        createChannel = function(opts) voice.seq = voice.seq + 1; voice.channels[voice.seq] = opts; voice.members[voice.seq] = {} return { id = voice.seq } end,
        removeChannel = function(id) voice.channels[id] = nil return true end,
        addPlayer = function(id, pid, perm) voice.members[id][pid] = perm return true end,
        removePlayer = function(id, pid) if voice.members[id] then voice.members[id][pid] = nil end return true end,
        setChannelPlayerPermissions = function(id, pid, perm) voice.members[id][pid] = perm return true end,
    },
}

NeuralConfig = { numberPattern = "^%d%d%d%-%d%d%d%d$",
    limits = { callParticipants = 6 },
    calls = { ringSeconds = 30, holocallEyes = true, effect = {}, ring = { maxDistance = 9, minDistance = 1 } },
    ringtones = { aurora = { file = "audio/ring_aurora.wav", duration = 2.4 } } }

-- ---------------------------------------------------------------------------
-- Neural.* collaborators

local pushes, logs, toasts, eyes = {}, {}, {}, {}
Neural = {
    log = function() end,
    nowMs = function() return now end,
    push = function(pid, name, payload) pushes[#pushes + 1] = { pid = pid, name = name, payload = payload } end,
    allow = function() return true end,
    notifyMissedCall = function(pid) toasts[#toasts + 1] = { pid = pid, kind = "missed" } end,
    refreshEyes = function(pid) eyes[pid] = Neural.calls.isConnected(pid) end,
}
local lines, sessions = {}, {}
local function addLine(id, number, pid)
    lines[id] = { id = id, number = number, name = "Name" .. id, settings = { ringtone = "aurora", volume = 0.8 } }
    if pid then sessions[pid] = { playerId = pid, line = lines[id], contacts = {} } end
end
Neural.lines = {
    session = function(pid) return pid and sessions[pid] end,
    playerOfLine = function(id) for pid, s in pairs(sessions) do if s.line.id == id then return pid end end end,
    isInstalled = function(pid) return sessions[pid] ~= nil and sessions[pid].noImplant ~= true end,
    nameFor = function(_, number) return number end,
    validNumber = function(n) return type(n) == "string" and n:match(NeuralConfig.numberPattern) ~= nil end,
    lineByNumber = function(number) for _, l in pairs(lines) do if l.number == number then return l end end return false end,
    linesByIds = function(ids) local out = {} for _, id in ipairs(ids) do out[id] = lines[id] end return out end,
    logCall = function(lineId, peer, direction, status, duration, label)
        logs[#logs + 1] = { line = lineId, peer = peer, direction = direction, status = status, duration = duration, label = label }
    end,
}
local groupMembers = {}
Neural.messages = { groupLines = function(_, threadId) return groupMembers, { id = threadId, title = "Crew" }, nil end }

dofile("server/calls.lua")
local Calls = Neural.calls

local function reset()
    pushes, logs, toasts = {}, {}, {}
end
local function lastPush(pid, name)
    for i = #pushes, 1, -1 do if pushes[i].pid == pid and pushes[i].name == name then return pushes[i].payload, true end end
    return nil, false
end
local function logOf(lineId)
    for i = #logs, 1, -1 do if logs[i].line == lineId then return logs[i] end end
end

addLine(1, "200-0001", 101)
addLine(2, "200-0002", 102)
addLine(3, "200-0003", 103)
addLine(4, "200-0004", 104)
addLine(5, "200-0005", nil)   -- offline

-- 1. direct call: ring, accept, talk, hang up -------------------------------
reset()
check(Calls.dial(101, { number = "200-0002" }) ~= nil, "dial ok")
check((lastPush(101, "nl:call") or {}).phase == "outgoing", "caller sees outgoing")
check((lastPush(102, "nl:call") or {}).phase == "incoming", "callee sees incoming")
check(liveSounds() == 1, "callee rings")
check(Calls.dial(103, { number = "200-0002" }) == nil, "third party cannot reach a busy line")
check(logOf(3) and logOf(3).status == "busy", "busy logged for the third party")
reset()
check(Calls.accept(102) ~= nil, "accept ok")
check(liveSounds() == 0, "ring stops on accept")
check((lastPush(101, "nl:call") or {}).phase == "active", "caller active")
check((lastPush(102, "nl:call") or {}).phase == "active", "callee active")
check(voice.members[1] and voice.members[1][101] and voice.members[1][102], "both in the voice channel")
check(eyes[101] == true and eyes[102] == true, "holocall eyes on")
advance(42000)
reset()
check(Calls.hangup(101) ~= nil, "hangup ok")
check(voice.channels[1] == nil, "voice channel removed")
check(eyes[101] == false and eyes[102] == false, "holocall eyes off")
local _, gotNil = lastPush(102, "nl:call")
check(gotNil, "callee told the call ended")
check((lastPush(102, "nl:callEnded") or {}).reason == "hangup", "callee end reason hangup")
check(logOf(1).status == "answered" and logOf(1).direction == "out" and logOf(1).duration >= 41, "caller history answered ~42 s")
check(logOf(2).status == "answered" and logOf(2).direction == "in", "callee history answered")
local ends = 0
for _, p in ipairs(pushes) do if p.pid == 101 and p.name == "nl:callEnded" then ends = ends + 1 end end
check(ends == 1, "exactly one end card for the caller")

-- 2. declined ---------------------------------------------------------------
reset()
Calls.dial(101, { number = "200-0002" })
check(Calls.decline(102) ~= nil, "decline ok")
check((lastPush(101, "nl:callEnded") or {}).reason == "declined", "caller sees declined")
check(logOf(1).status == "declined" and logOf(2).status == "declined", "both logged declined")
check(liveSounds() == 0, "no ring left after decline")

-- 3. no answer: ring timeout --------------------------------------------------
reset()
Calls.dial(101, { number = "200-0002" })
advance(31000)
check((lastPush(102, "nl:callEnded") or {}).reason == "missed", "callee end reason missed")
check((lastPush(101, "nl:callEnded") or {}).reason == "no_answer", "caller sees no answer")
check(logOf(2).status == "missed" and logOf(1).status == "unavailable", "missed / unavailable logged")
check(#toasts == 1 and toasts[1].pid == 102, "missed-call toast for the callee")
check(liveSounds() == 0, "ring stopped after timeout")

-- 4. caller cancels before an answer ----------------------------------------
reset()
Calls.dial(101, { number = "200-0002" })
Calls.hangup(101)
check((lastPush(101, "nl:callEnded") or {}).reason == "hangup", "caller end reason hangup")
check((lastPush(102, "nl:callEnded") or {}).reason == "missed", "callee end reason missed")
check(logOf(2).status == "missed", "callee logged missed")
check(#toasts == 1, "missed toast when the caller cancels")
advance(31000)
check(#toasts == 1, "no late timeout after the call ended")

-- 5. unreachable --------------------------------------------------------------
reset()
local ok, why = Calls.dial(101, { number = "200-0005" })
check(ok == nil and why == "unavailable", "offline line is unavailable")
ok, why = Calls.dial(101, { number = "999-9999" })
check(ok == nil and why == "unknown_number", "unknown number")
ok, why = Calls.dial(101, { number = "200-0001" })
check(ok == nil and why == "self", "cannot call yourself")

-- 6. group call: one answers, one declines, one times out, then hang up ------
reset()
groupMembers = { 1, 2, 3, 4 }
check(Calls.dialGroup(101, { threadId = 7 }) ~= nil, "group dial ok")
check((lastPush(102, "nl:call") or {}).group ~= nil, "group info on the incoming call")
check(liveSounds() == 3, "three members ring")
Calls.accept(102)
check((lastPush(101, "nl:call") or {}).phase == "active", "group call active after first answer")
Calls.decline(103)
check((lastPush(102, "nl:call") or {}) ~= nil, "call goes on after a decline")
advance(31000)
check(logOf(4) and logOf(4).status == "missed" and logOf(4).label == "Crew", "timed-out member logged missed with the group label")
local state = lastPush(101, "nl:call")
check(state and state.phase == "active", "still active with two connected")
reset()
Calls.hangup(102)
check((lastPush(101, "nl:callEnded") or {}).reason == "hangup", "last remaining member ends")
check(logOf(1).status == "answered" and logOf(1).label == "Crew" and logOf(1).peer == "", "group caller history")

-- 7. adding a participant mid-call -------------------------------------------
reset()
Calls.dial(101, { number = "200-0002" })
Calls.accept(102)
check(Calls.add(101, { number = "200-0003" }) ~= nil, "add participant")
check((lastPush(103, "nl:call") or {}).phase == "incoming", "added participant rings")
Calls.accept(103)
local three = lastPush(103, "nl:call")
local connected = 0
for _, p in ipairs(three and three.participants or {}) do if p.state == "connected" then connected = connected + 1 end end
check(connected == 3, "three connected")
-- 8. mute and drop -----------------------------------------------------------
Calls.mute(102, { muted = true })
local channel = voice.seq
check(voice.members[channel][102].canSpeak == false, "mute revokes speak in the channel")
Calls.mute(102, { muted = false })
check(voice.members[channel][102].canSpeak == true, "unmute restores speak")
reset()
Calls.onDetach(103)
check((lastPush(101, "nl:call") or {}).phase == "active", "call survives one participant dropping")
Calls.hangup(101)
check(voice.channels[channel] == nil, "channel removed at the end")

-- no implant: the line exists, the player is online, but cannot be rung -------
for _, s in pairs(sessions) do if s.line.id == 4 then s.noImplant = true end end
reset()
local result, why = Calls.dial(101, { number = "200-0004" })
check(result == nil and why == "unavailable", "a line without an implant is unavailable")
check(liveSounds() == 0, "nothing rings without an implant")
for _, s in pairs(sessions) do if s.line.id == 4 then s.noImplant = nil end end

print(string.format("%d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)
