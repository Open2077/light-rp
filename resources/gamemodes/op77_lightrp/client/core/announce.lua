-- Staff voice announcements, client side (server/modules/announce.lua): the server says
-- who is on air for us; this feeds the page's halo (ui/src/features/announce) with that
-- speaker's live voice level. The speaker's own halo follows their microphone while
-- they transmit. No audio here: the voice itself is the platform's channel.
local Ui = LightRpUi
local NET = "op77_lightrp:announce"
local PAGE = "lightrp:ui:announce"
local POLL_MS = 50

local casts = {}        -- speaker id -> { name, mode, radius, self, audience }
local polling = false
local last = {}         -- speaker id -> { level, talking } last sent

local function any() return next(casts) ~= nil end

local function levelOf(speaker, cast, talkers)
    if cast.self then
        local ok, status = pcall(Open77.voice.status)
        if not ok or type(status) ~= "table" then return false, 0 end
        local level = tonumber(status.inputLevel or status.microphoneActivity) or 0
        return status.transmitting == true, level
    end
    for _, t in ipairs(talkers or {}) do
        if tonumber(t.playerId) == speaker then return t.talking == true, tonumber(t.level) or 0 end
    end
    return false, 0
end

local function poll()
    if polling then return end
    polling = true
    CreateThread(function()
        while any() do
            local okTalkers, talkers = pcall(Open77.voice.talkers)
            if not okTalkers or type(talkers) ~= "table" then talkers = {} end
            for speaker, cast in pairs(casts) do
                local talking, level = levelOf(speaker, cast, talkers)
                level = math.max(0, math.min(1, level))
                if not talking then level = 0 end
                local prev = last[speaker]
                if prev == nil or prev.talking ~= talking or math.abs(prev.level - level) >= 0.02 then
                    last[speaker] = { level = level, talking = talking }
                    Ui.send(PAGE, { kind = "level", speaker = speaker, level = math.floor(level * 1000 + 0.5) / 1000, talking = talking })
                end
            end
            Wait(POLL_MS)
        end
        polling = false
    end)
end

RegisterNetEvent(NET, function(payload)
    if type(payload) ~= "table" then return end
    local speaker = tonumber(payload.speaker)
    if not speaker then return end
    if payload.active then
        casts[speaker] = { name = tostring(payload.name or ""), mode = payload.mode == "radius" and "radius" or "server",
            radius = tonumber(payload.radius), self = payload.self == true, audience = tonumber(payload.audience) or 0 }
        local c = casts[speaker]
        Ui.send(PAGE, { kind = "cast", speaker = speaker, name = c.name, mode = c.mode, radius = c.radius, self = c.self, audience = c.audience })
        poll()
    else
        casts[speaker], last[speaker] = nil, nil
        Ui.send(PAGE, { kind = "end", speaker = speaker })
    end
end)
