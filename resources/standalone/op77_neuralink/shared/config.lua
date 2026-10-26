-- Shared by server and client: never put credentials here.
NeuralConfig = {
    -- Key that opens / closes the interface (rebindable in Pause > Settings > Key bindings).
    toggleKey = "F2",

    -- Phone numbers: "NNN-NNNN", first digit 2..9.
    numberPattern = "^%d%d%d%-%d%d%d%d$",

    limits = {
        contacts = 200,          -- per line
        nameLength = 48,
        bodyLength = 500,        -- characters of one message
        groupTitle = 40,
        groupMembers = 16,       -- including the owner
        threadsListed = 60,      -- threads sent in a snapshot
        messagesPage = 40,       -- messages per thread page
        recents = 60,            -- call history entries kept per line
        callParticipants = 6,
    },

    rate = {
        requestsPerSecond = 12,  -- token bucket refill per player
        burst = 30,
        messagesPerTenSeconds = 12,
        dialsPerMinute = 10,
        screamsPerMinute = 6,    -- Screamsheet posts, replies and quotes
        socialPerTenSeconds = 20, -- Street Cred, echoes and follows
    },

    -- The implant. A character starts without a Neural-Link: F2 shows that none is
    -- detected and offers the installation (an animated Kiroshi sequence). Without
    -- the implant the line exists but cannot be called and its requests are refused.
    implant = {
        required = true,         -- false: every line counts as installed
        selfInstall = true,      -- false: only a resource (a ripperdoc) installs it, see exports
        model = "Kiroshi NL-77 Synapse",
    },

    -- Screamsheet, the players' social feed (server/social.lua).
    social = {
        screamLength = 280,      -- characters
        nameLength = 32,
        bioLength = 160,
        tagsPerScream = 5,
        mentionsPerScream = 5,
        page = 20,               -- screams per feed page
        repliesShown = 60,
        hotHours = 24,           -- window of Hot and Net Heat
        hotShown = 30,
        pingsPage = 30,
    },

    calls = {
        ringSeconds = 30,        -- unanswered after this: missed
        holocallEyes = true,     -- native blue eye glow while connected
        -- Neural voice: clean, close and slightly "inside the head".
        effect = {
            gain = 1.0, highPassHz = 160.0, lowPassHz = 7000.0, distortion = 0.02,
            radioNoise = 0.004, spatialBlend = 0.0,
            reverbWet = 0.08, reverbRoomSize = 0.25, reverbDecay = 0.6,
            reverbDamping = 0.6, reverbPreDelayMs = 8.0,
        },
        -- The ringtone is a networked 3D sound at the callee: the callee and
        -- anybody within maxDistance hear the implant chime.
        ring = { maxDistance = 9.0, minDistance = 1.0 },
    },

    -- Ringtone files (audio/<file>) and their exact duration in seconds (looped server-side).
    -- Cyberpunk 2077's own phone rings (mono, full length: the game's gap between
    -- two rings is in the file). Ids stay stable: they are stored in players' settings.
    ringtones = {
        aurora = { file = "audio/ring_aurora.wav", duration = 16.9 },   -- V's holocall ring
        link   = { file = "audio/ring_link.wav",   duration = 6.468 },  -- Kerry's phone
        pulse  = { file = "audio/ring_pulse.wav",  duration = 21.318 }, -- old landline
    },

    -- Interface sounds (Cyberpunk 2077 UI samples), played by the client with Play2DSound when the
    -- page asks (`nl:sound { name = "ui:<name>" }`); gain multiplies the player's volume.
    uiSounds = {
        tick       = { file = "audio/ui_tick.wav",       gain = 0.35 },
        select     = { file = "audio/ui_select.wav",     gain = 0.7 },
        back       = { file = "audio/ui_back.wav",       gain = 0.7 },
        open       = { file = "audio/ui_open.wav",       gain = 0.8 },
        close      = { file = "audio/ui_close.wav",      gain = 0.8 },
        send       = { file = "audio/ui_send.wav",       gain = 0.7 },
        chime      = { file = "audio/ui_message.wav",    gain = 0.85 },
        receive    = { file = "audio/ui_panel.wav",      gain = 0.7 },
        connect    = { file = "audio/ui_connect.wav",    gain = 0.8 },
        disconnect = { file = "audio/ui_disconnect.wav", gain = 0.8 },
        error      = { file = "audio/ui_warning.wav",    gain = 0.7 },
        toast      = { file = "audio/ui_system.wav",     gain = 0.75 },
        -- the Night City style's glitched boot; it borrows an installation slot
        -- (no interface while installing) to stay under the 16 handles
        glitch     = { file = "audio/ui_glitch.wav",     gain = 0.6, slot = "implant:a" },
        -- The implant installation sequence (Cyberpunk 2077 UI samples, the q110
        -- "personal link" for the end). They share two slots, "a" and "b":
        -- a sound cuts the previous one of its own slot.
        implant_denied    = { file = "audio/implant_denied.wav",    gain = 0.8, slot = "implant:a" },
        implant_glitch    = { file = "audio/implant_glitch.wav",    gain = 0.7, slot = "implant:a" },
        implant_boot      = { file = "audio/implant_boot.wav",      gain = 0.8, slot = "implant:a" },
        implant_flash     = { file = "audio/implant_flash.wav",     gain = 0.7, slot = "implant:a" },
        implant_calibrate = { file = "audio/implant_calibrate.wav", gain = 0.75, slot = "implant:a" },
        implant_granted   = { file = "audio/implant_granted.wav",   gain = 0.8, slot = "implant:a" },
        implant_insert    = { file = "audio/implant_insert.wav",    gain = 0.85, slot = "implant:b" },
        implant_scan      = { file = "audio/implant_scan.wav",      gain = 0.7, slot = "implant:b" },
        implant_online    = { file = "audio/implant_online.wav",    gain = 0.85, slot = "implant:b" },
    },

    defaults = {
        settings = { ringtone = "aurora", volume = 0.8, dnd = false, accent = "sao", intensity = 0.8, theme = "light", style = "cyberpunk" },
    },
}
