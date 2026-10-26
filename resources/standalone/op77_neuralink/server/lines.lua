-- Phone lines: one per character (LightRP) or per account (no LightRP), a
-- unique "NNN-NNNN" number, the online session index, contacts, settings and
-- the call history.
local Store, C = Neural.store, NeuralConfig
local Lines = {}
Neural.lines = Lines

local sessions = {}   -- playerId -> session { playerId, line, contacts = { [number] = contact } }
local byLine = {}     -- lineId -> playerId (online lines only)
local byNumber = {}   -- number -> playerId (online lines only)

function Lines.session(playerId) return sessions[playerId] end
function Lines.playerOfLine(lineId) return byLine[lineId] end
function Lines.playerOfNumber(number) return byNumber[number] end
function Lines.sessions() return sessions end

-- Push one page event to a player (the client relays it to the page as is).
function Neural.push(playerId, name, payload)
    if playerId then TriggerClientEvent("op77_neuralink:push", playerId, name, payload) end
end

-- ---------------------------------------------------------------------------
-- Identity: the active LightRP character when the framework runs, the account otherwise.

local function lightRpIdentity(playerId)
    local ok, result = pcall(function() return exports.op77_lightrp:characterIdentity(playerId) end)
    if not ok then return nil, false end          -- framework absent (or failing): not authoritative
    return result, true                            -- framework present; nil = no active character yet
end

function Lines.identity(playerId)
    local identity, framework = lightRpIdentity(playerId)
    if framework then return identity end
    local identifier = GetPlayerIdentifier(playerId)
    if not identifier then return nil end
    return { identifier = identifier, characterKey = "default", name = GetPlayerName(playerId) }
end

-- ---------------------------------------------------------------------------
-- Numbers

function Lines.validNumber(number)
    return type(number) == "string" and number:match(C.numberPattern) ~= nil
end

local function randomNumber()
    return string.format("%d%02d-%04d", math.random(2, 9), math.random(0, 99), math.random(0, 9999))
end

local function decodeSettings(text)
    local settings = {}
    for k, v in pairs(C.defaults.settings) do settings[k] = v end
    if type(text) == "string" and #text > 0 then
        local ok, stored = pcall(json.decode, text)
        if ok and type(stored) == "table" then
            for k in pairs(C.defaults.settings) do
                if stored[k] ~= nil then settings[k] = stored[k] end
            end
        end
    end
    return settings
end

local function loadOrCreateLine(identity)
    local row, err = Store.single("SELECT id, number, name, settings, installed_at FROM nl_lines WHERE identifier = ? AND character_key = ?",
        { identity.identifier, identity.characterKey })
    if row == nil then return nil, err end
    if row then
        if identity.name and identity.name ~= row.name then
            Store.update("UPDATE nl_lines SET name = ? WHERE id = ?", { identity.name, row.id })
            row.name = identity.name
        end
        return { id = row.id, number = row.number, name = row.name or row.number, settings = decodeSettings(row.settings),
            installedAt = tonumber(row.installed_at) }
    end
    for _ = 1, 12 do
        local number = randomNumber()
        local id, insertErr = Store.insert(
            "INSERT INTO nl_lines (number, identifier, character_key, name, settings, created_at) VALUES (?, ?, ?, ?, ?, ?)",
            { number, identity.identifier, identity.characterKey, identity.name, json.encode(C.defaults.settings), Neural.nowMs() })
        if id then
            Neural.log("line %s assigned to %s/%s", number, identity.identifier, identity.characterKey)
            return { id = id, number = number, name = identity.name or number, settings = decodeSettings(nil) }
        end
        if insertErr ~= "conflict" then return nil, insertErr end
        -- a number (or this owner, from a racing request) already exists: retry / re-read
        local again = Store.single("SELECT id, number, name, settings, installed_at FROM nl_lines WHERE identifier = ? AND character_key = ?",
            { identity.identifier, identity.characterKey })
        if again then
            return { id = again.id, number = again.number, name = again.name or again.number, settings = decodeSettings(again.settings),
                installedAt = tonumber(again.installed_at) }
        end
    end
    return nil, "no_number"
end

-- Test harness: an offline line owned by nobody real ("test:<number>").
function Lines.ensureTestLine(number, name)
    if not Lines.validNumber(number) then return nil, "invalid_number" end
    local line, err = Lines.lineByNumber(number)
    if line == nil then return nil, err end
    if line then return line end
    local id, insertErr = Store.insert(
        "INSERT INTO nl_lines (number, identifier, character_key, name, settings, created_at) VALUES (?, ?, 'default', ?, ?, ?)",
        { number, "test:" .. number, name, json.encode(C.defaults.settings), Neural.nowMs() })
    if not id then return nil, insertErr end
    return { id = id, number = number, name = name }
end

function Lines.lineByNumber(number)
    local online = byNumber[number]
    if online and sessions[online] then return sessions[online].line end
    local row, err = Store.single("SELECT id, number, name FROM nl_lines WHERE number = ?", { number })
    if row == nil then return nil, err end
    if not row then return false end
    return { id = row.id, number = row.number, name = row.name or row.number }
end

function Lines.linesByIds(ids)
    local out = {}
    local missing = {}
    for _, id in ipairs(ids) do
        local pid = byLine[id]
        if pid and sessions[pid] then out[id] = sessions[pid].line else missing[#missing + 1] = id end
    end
    for i = 1, #missing, 60 do
        local chunk = { table.unpack(missing, i, math.min(#missing, i + 59)) }
        local rows = Store.query("SELECT id, number, name FROM nl_lines WHERE id IN (" .. Store.placeholders(#chunk) .. ")", chunk)
        for _, row in ipairs(rows or {}) do out[row.id] = { id = row.id, number = row.number, name = row.name or row.number } end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Contacts and names as one viewer sees them

local function loadContacts(lineId)
    local rows = Store.query("SELECT id, name, number, favorite FROM nl_contacts WHERE line_id = ? ORDER BY name", { lineId })
    local contacts = {}
    for _, row in ipairs(rows or {}) do
        contacts[row.number] = { id = row.id, name = row.name, number = row.number, favorite = row.favorite == 1 or row.favorite == true }
    end
    return contacts
end

-- The name a viewer sees for a number: their contact name, else the number itself.
function Lines.nameFor(viewerPlayerId, number)
    local s = viewerPlayerId and sessions[viewerPlayerId]
    if s and s.line.number == number then return s.line.name end
    local contact = s and s.contacts[number]
    return contact and contact.name or number
end

function Lines.contactList(playerId)
    local s = sessions[playerId]
    if not s then return {} end
    local list = {}
    for number, c in pairs(s.contacts) do
        list[#list + 1] = { id = c.id, name = c.name, number = number, favorite = c.favorite, online = byNumber[number] ~= nil }
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end

function Lines.saveContact(playerId, args)
    local s = sessions[playerId]
    if not s then return nil, "no_line" end
    local name = type(args.name) == "string" and args.name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if #name < 1 or #name > C.limits.nameLength then return nil, "invalid_name" end
    if not Lines.validNumber(args.number) then return nil, "invalid_number" end
    if args.number == s.line.number then return nil, "self" end
    local favorite = args.favorite == true and 1 or 0
    local existing = s.contacts[args.number]
    if args.id then
        local id = tonumber(args.id)
        local current
        for _, c in pairs(s.contacts) do if c.id == id then current = c end end
        if not current then return nil, "unknown_contact" end
        if existing and existing.id ~= id then return nil, "duplicate_contact" end
        local ok, err = Store.update("UPDATE nl_contacts SET name = ?, number = ?, favorite = ? WHERE id = ? AND line_id = ?",
            { name, args.number, favorite, id, s.line.id })
        if not ok then return nil, err end
        s.contacts[current.number] = nil
        s.contacts[args.number] = { id = id, name = name, number = args.number, favorite = favorite == 1 }
    else
        if existing then return nil, "duplicate_contact" end
        local count = 0
        for _ in pairs(s.contacts) do count = count + 1 end
        if count >= C.limits.contacts then return nil, "contacts_full" end
        local id, err = Store.insert("INSERT INTO nl_contacts (line_id, name, number, favorite) VALUES (?, ?, ?, ?)",
            { s.line.id, name, args.number, favorite })
        if not id then return nil, err == "conflict" and "duplicate_contact" or err end
        s.contacts[args.number] = { id = id, name = name, number = args.number, favorite = favorite == 1 }
    end
    local c = s.contacts[args.number]
    return { id = c.id, name = c.name, number = c.number, favorite = c.favorite, online = byNumber[c.number] ~= nil }
end

function Lines.deleteContact(playerId, args)
    local s = sessions[playerId]
    if not s then return nil, "no_line" end
    local id = tonumber(args.id)
    for number, c in pairs(s.contacts) do
        if c.id == id then
            local ok, err = Store.update("DELETE FROM nl_contacts WHERE id = ? AND line_id = ?", { id, s.line.id })
            if not ok then return nil, err end
            s.contacts[number] = nil
            return {}
        end
    end
    return nil, "unknown_contact"
end

-- ---------------------------------------------------------------------------
-- Settings

function Lines.saveSettings(playerId, patch)
    local s = sessions[playerId]
    if not s then return nil, "no_line" end
    if type(patch) ~= "table" then return nil, "invalid_settings" end
    local settings = {}
    for k, v in pairs(s.line.settings) do settings[k] = v end
    if patch.ringtone ~= nil then
        if patch.ringtone ~= "silent" and not C.ringtones[patch.ringtone] then return nil, "invalid_settings" end
        settings.ringtone = patch.ringtone
    end
    if patch.volume ~= nil then
        if type(patch.volume) ~= "number" or patch.volume ~= patch.volume then return nil, "invalid_settings" end
        settings.volume = math.max(0, math.min(1, patch.volume))
    end
    if patch.dnd ~= nil then settings.dnd = patch.dnd == true end
    if patch.accent ~= nil then
        if patch.accent ~= "sao" and patch.accent ~= "cyan" and patch.accent ~= "magenta" then return nil, "invalid_settings" end
        settings.accent = patch.accent
    end
    if patch.intensity ~= nil then
        if type(patch.intensity) ~= "number" or patch.intensity ~= patch.intensity then return nil, "invalid_settings" end
        settings.intensity = math.max(0.3, math.min(1, patch.intensity))
    end
    if patch.theme ~= nil then
        if patch.theme ~= "light" and patch.theme ~= "dark" then return nil, "invalid_settings" end
        settings.theme = patch.theme
    end
    if patch.style ~= nil then
        if patch.style ~= "cyberpunk" and patch.style ~= "sao" then return nil, "invalid_settings" end
        settings.style = patch.style
    end
    local ok, err = Store.update("UPDATE nl_lines SET settings = ? WHERE id = ?", { json.encode(settings), s.line.id })
    if not ok then return nil, err end
    s.line.settings = settings
    return settings
end

-- ---------------------------------------------------------------------------
-- Call history

-- peerNumber "" + label = a group call (no single number to call back).
function Lines.logCall(lineId, peerNumber, direction, status, duration, label)
    Store.insert("INSERT INTO nl_calls (line_id, peer_number, label, direction, status, at, duration) VALUES (?, ?, NULLIF(?, ''), ?, ?, ?, ?)",
        { lineId, peerNumber or "", label or "", direction, status, Neural.nowMs(), math.floor(duration or 0) })
    local pid = byLine[lineId]
    if pid then Neural.push(pid, "nl:patch", { recents = Lines.recents(pid) }) end
end

function Lines.recents(playerId)
    local s = sessions[playerId]
    if not s then return {} end
    local rows = Store.query("SELECT id, peer_number, label, direction, status, at, duration FROM nl_calls WHERE line_id = ? ORDER BY id DESC LIMIT ?",
        { s.line.id, C.limits.recents }) or {}
    local list = {}
    for _, row in ipairs(rows) do
        local name = row.label or Lines.nameFor(playerId, row.peer_number)
        list[#list + 1] = { id = row.id, number = row.peer_number, name = name,
            direction = row.direction, status = row.status, at = row.at, duration = row.duration }
    end
    return list
end

function Lines.clearRecents(playerId)
    local s = sessions[playerId]
    if not s then return nil, "no_line" end
    local ok, err = Store.update("DELETE FROM nl_calls WHERE line_id = ?", { s.line.id })
    if not ok then return nil, err end
    return {}
end

-- ---------------------------------------------------------------------------
-- The implant

function Lines.isInstalled(playerId)
    if not C.implant.required then return true end
    local s = sessions[playerId]
    return s ~= nil and s.line.installedAt ~= nil
end

function Lines.implantOf(playerId)
    local s = sessions[playerId]
    return {
        installed = Lines.isInstalled(playerId),
        installedAt = s and s.line.installedAt or nil,
        model = C.implant.model,
        selfInstall = C.implant.selfInstall == true,
    }
end

-- Installs (true) or removes (false) the implant of a connected player's line.
function Lines.setInstalled(playerId, installed)
    local s = sessions[playerId]
    if not s then return nil, "no_line" end
    local at = installed and Neural.nowMs() or nil
    local ok, err
    if at then ok, err = Store.update("UPDATE nl_lines SET installed_at = ? WHERE id = ?", { at, s.line.id })
    else ok, err = Store.update("UPDATE nl_lines SET installed_at = NULL WHERE id = ?", { s.line.id }) end
    if ok == nil then return nil, err end
    s.line.installedAt = at
    Neural.log("implant %s for line %s", installed and "installed" or "removed", s.line.number)
    if not installed then Neural.calls.onDetach(playerId, "implant") end
    -- host-wide, for a gamemode (LightRP's first day waits for it)
    TriggerEvent("op77_neuralink:implantChanged", playerId, installed == true)
    -- everything the interface shows changes with it: send the whole state
    Neural.push(playerId, "nl:state", Lines.snapshot(playerId))
    return { implant = Lines.implantOf(playerId) }
end

-- ---------------------------------------------------------------------------
-- Sessions

local attaching = {}

function Lines.snapshot(playerId)
    local s = sessions[playerId]
    if not s then
        return { ready = false, line = nil, settings = C.defaults.settings, contacts = {}, threads = {}, recents = {}, apps = {}, call = nil, social = nil,
            implant = Lines.implantOf(playerId) }
    end
    return {
        ready = true,
        line = { number = s.line.number, name = s.line.name },
        settings = s.line.settings,
        contacts = Lines.contactList(playerId),
        threads = Neural.messages.summaries(playerId),
        recents = Lines.recents(playerId),
        apps = {},
        call = Neural.calls.stateFor(playerId),
        social = Neural.social.summary(playerId),
        implant = Lines.implantOf(playerId),
    }
end

-- Tells every online line that has this number in its contacts that it went on/offline.
local function announcePresence(number)
    for pid, s in pairs(sessions) do
        if s.contacts[number] then Neural.push(pid, "nl:patch", { contacts = Lines.contactList(pid) }) end
    end
end

function Lines.detach(playerId, reason)
    local s = sessions[playerId]
    if not s then return end
    Neural.calls.onDetach(playerId, reason)
    sessions[playerId] = nil
    if byLine[s.line.id] == playerId then byLine[s.line.id] = nil end
    if byNumber[s.line.number] == playerId then byNumber[s.line.number] = nil end
    announcePresence(s.line.number)
end

function Lines.attach(playerId, identity)
    if attaching[playerId] then return end
    identity = identity or Lines.identity(playerId)
    if not identity then
        Neural.push(playerId, "nl:state", Lines.snapshot(playerId))
        return
    end
    local current = sessions[playerId]
    if current and current.identifier == identity.identifier and current.characterKey == identity.characterKey then
        Neural.push(playerId, "nl:state", Lines.snapshot(playerId))
        return
    end
    if current then Lines.detach(playerId, "switch") end
    if not Store.ready then
        Store.onReady(function() Lines.attach(playerId) end)
        return
    end
    attaching[playerId] = true
    local line, err = loadOrCreateLine(identity)
    attaching[playerId] = nil
    if not line then
        Neural.log("no line for player %d: %s", playerId, tostring(err))
        return
    end
    -- The same line cannot be open twice (one character, two clients): the newest wins.
    local previous = byLine[line.id]
    if previous and previous ~= playerId then Lines.detach(previous, "replaced") end
    sessions[playerId] = { playerId = playerId, line = line, identifier = identity.identifier,
        characterKey = identity.characterKey, contacts = loadContacts(line.id) }
    byLine[line.id] = playerId
    byNumber[line.number] = playerId
    Neural.push(playerId, "nl:state", Lines.snapshot(playerId))
    announcePresence(line.number)
end
