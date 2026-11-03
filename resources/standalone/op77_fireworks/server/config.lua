-- op77_fireworks -- configuration. Server only: nothing here is downloaded.
--
-- Everything an operator would change lives here: where a show can be fired,
-- what it fires, how it is paced, and what the announcements say.

FireworksConfig = {
    -- ONE restricted command: the platform checks `command.fireworks` against
    -- the caller's ACL before the handler runs, so this resource has no rights
    -- logic of its own. The dedicated console (source 0) is always allowed.
    command = "fireworks",

    -- NAMED PLACES. A show fired at a place uses the place's routing bucket,
    -- never a guessed one: a show fired into a bucket nobody occupies is
    -- invisible while every call still reports success. Keep bucket 0 for
    -- places in the shared city.
    --
    -- `crossing` is the lobby, The Crossing: the Westbrook esplanade where every
    -- newcomer arrives (`spawn.afterTutorial` in op77_lightrp/shared/config.lua).
    -- `standoff` + `heading` move the centre of the show that many metres in
    -- that direction (yaw 0 = +Y, counter-clockwise), so the sky in front of a
    -- crowd can be used instead of the sky straight above it. 0 = over the point.
    places = {
        crossing = {
            label = "The Crossing",
            x = -756.581, y = 777.257, z = 22.454,
            bucket = 0,
            heading = 52.6, standoff = 0.0,
        },
    },
    -- The console has no body, so a show it fires without naming a place goes here.
    defaultPlace = "crossing",
    defaultShow = "burst",
    -- How announcements name a show fired at a staff member's position ("here").
    hereLabel = "Night City",

    -- THE SHELLS. Cyberpunk cooks four firework effects for the q112 parade;
    -- only the first has a curated alias. `Open77.effects.play` takes a cooked
    -- depot path exactly like an alias. A shell is drawn at random, minus the one
    -- just used (rp_fireworks measured that a strict rotation reads as a loop).
    shells = {
        "race.firework.burst",
        "base\\fx\\quest\\q112\\q112_firework_02.effect",
        "base\\fx\\quest\\q112\\q112_firework_03.effect",
        "base\\fx\\quest\\q112\\q112_firework_04.effect",
    },
    -- Named effects a cue can use by key.
    effects = {
        confetti = "base\\fx\\quest\\q112\\e_debris_confetti_q112.effect",
        petals   = "base\\fx\\quest\\q112\\q112_holo_petals.effect",
    },

    -- WHERE IT LANDS, relative to the show's centre (measured in game by
    -- rp_fireworks: lower reads as a bonfire, higher as distant sparks).
    radius = 40.0,
    minHeight = 25.0,
    maxHeight = 45.0,
    -- Two shells closer than this read as one smeared burst: a point is redrawn
    -- (a few tries) until it clears the previous one.
    minSeparation = 26.0,
    -- Broadcast radius in metres, 1..500. A shell 30 m up is seen from afar.
    range = 500.0,
    -- The launch boom, on the first shell of a cue that asks for it (`sound = true`).
    sound = "sq024_race_start_fireworks",

    -- HOW A SHELL IS FIRED.
    --   "registry": Open77.effects.create with `ttlMs = budget.shellLifeMs`. The
    --       server retires the entry, and the client stops the handle and frees its
    --       quota slot. A shell carrying the boom still goes as a one-shot: that is
    --       the only way to attach a sound to it (3 per burst, 10 per finale).
    --   "oneshot": Open77.effects.play for every shell, as rp_fireworks does.
    -- Why "registry" is the default: a world one-shot reaches the client with no
    -- duration, and in the current client source (base client/src/api/Effects.cpp,
    -- Expiry(0) = no expiry) such a handle keeps its slot in the 192-slot quota
    -- that every server effect shares until the player leaves the world. The fix
    -- the memory note describes (ONE_SHOT_SECONDS in open77_effects) is not in
    -- this distribution's copy. Check in game with the debug bridge's
    -- `effects.list` after a show: if spent one-shots are gone, "oneshot" is safe.
    shellMode = "registry",
    -- A registry shell streams to players within this many metres (10..2000).
    streamingRadius = 400.0,

    -- THE CLIENT EFFECT BUDGET. Every server-driven effect lands in one client
    -- quota (192 slots shared by every resource, see the memory note
    -- op77-client-effect-quota-and-projector-budget), and a shell holds its slot
    -- while it lives. Two rules, applied to every show before it runs:
    --   slice  : at most `sliceSize` shells in one server tick, the rest pushed
    --            `sliceGapMs` later (a large tick overruns the client's frame budget);
    --   maxLive: at most `maxLive` shells alive at once, a shell counting for
    --            `shellLifeMs` (also the registry ttl); extras are thinned, never delayed.
    -- The presets below are written to stay inside it (tests/fireworks_test.lua
    -- proves none is thinned), so the budget is a safety net, not the design.
    budget = {
        sliceSize = 8,
        sliceGapMs = 60,
        maxLive = 60,
        shellLifeMs = 10000,
    },

    -- THE SHOWS. A show is a list of cues; a cue is one beat:
    --   at        ms from the start of the show
    --   effect    a key of `effects` above, an alias, a depot path -- or nil for a shell
    --   count     copies, `spreadMs` apart
    --   radius / minHeight / maxHeight   placement, defaulting to the block above
    --   sound     true = the boom above on the first copy, a string = that event
    shows = {
        -- Short and loud (about 10 s): a race finish, a match won, midnight.
        burst = {
            { at = 0,    count = 5, spreadMs = 320, sound = true },
            { at = 2200, count = 6, spreadMs = 280 },
            { at = 4600, count = 8, spreadMs = 240, sound = true },
            { at = 7400, effect = "confetti", count = 4, radius = 10.0, minHeight = 9.0, maxHeight = 15.0, spreadMs = 160 },
            { at = 8000, count = 14, spreadMs = 120, sound = true },
        },

        -- The finale (about 45 s): a steady pulse that opens up, then the climax.
        finale = {
            { at = 0,     effect = "confetti", count = 4, radius = 10.0, minHeight = 9.0, maxHeight = 15.0, spreadMs = 160 },
            { at = 600,   count = 4, spreadMs = 320, sound = true },
            { at = 2400,  count = 4, spreadMs = 300 },
            { at = 4400,  count = 5, spreadMs = 280, sound = true },
            { at = 6800,  effect = "petals", count = 3, radius = 9.0, minHeight = 10.0, maxHeight = 15.0, spreadMs = 220 },
            { at = 7600,  count = 5, spreadMs = 260 },
            { at = 10000, count = 5, spreadMs = 260, sound = true },
            { at = 12600, count = 5, spreadMs = 240 },
            { at = 15200, count = 6, spreadMs = 240, sound = true },
            { at = 18000, effect = "confetti", count = 4, radius = 11.0, minHeight = 9.0, maxHeight = 15.0, spreadMs = 160 },
            { at = 18600, count = 6, spreadMs = 220 },
            { at = 21400, count = 6, spreadMs = 220, sound = true },
            { at = 24200, count = 6, spreadMs = 200 },
            { at = 27000, count = 7, spreadMs = 200, sound = true },
            { at = 30000, count = 7, spreadMs = 180 },
            { at = 33000, effect = "petals", count = 4, radius = 10.0, minHeight = 10.0, maxHeight = 16.0, spreadMs = 200 },
            { at = 33600, count = 8, spreadMs = 170, radius = 46.0, sound = true },
            { at = 36800, count = 8, spreadMs = 160, radius = 50.0, sound = true },
            { at = 40000, effect = "confetti", count = 5, radius = 12.0, minHeight = 9.0, maxHeight = 15.0, spreadMs = 150 },
            { at = 40600, count = 12, spreadMs = 130, radius = 52.0, sound = true },
            { at = 43200, count = 12, spreadMs = 120, radius = 55.0, sound = true },
        },

        -- Indoor-safe (about 8 s): nothing explodes, it stays at head height.
        -- A podium, a wedding, a promotion.
        celebration = {
            { at = 0,    effect = "confetti", count = 3, radius = 5.0, minHeight = 6.0, maxHeight = 9.0,  spreadMs = 200 },
            { at = 1400, effect = "petals",   count = 2, radius = 4.0, minHeight = 7.0, maxHeight = 10.0, spreadMs = 250 },
            { at = 3000, effect = "confetti", count = 4, radius = 6.0, minHeight = 6.0, maxHeight = 10.0, spreadMs = 180 },
            { at = 4800, effect = "petals",   count = 4, radius = 5.0, minHeight = 7.0, maxHeight = 12.0, spreadMs = 200 },
            { at = 6600, effect = "confetti", count = 5, radius = 7.0, minHeight = 6.0, maxHeight = 11.0, spreadMs = 150 },
        },
    },

    -- SCHEDULING. `/fireworks in <delay>` takes minutes (`10`, `2.5`) or an
    -- explicit unit (`90s`, `5m`).
    schedule = {
        minSeconds = 10,
        maxSeconds = 3 * 60 * 60,
        -- Countdown marks, in seconds before the launch. A mark is skipped when
        -- the delay is shorter, or when it would land within `minGapSeconds`
        -- of the first announcement (two banners back to back read as a bug).
        marks = { 1800, 900, 600, 300, 120, 60, 30, 10, 5, 4, 3, 2, 1 },
        minGapSeconds = 5,
        -- Marks at or above this also go to chat; the final seconds only tick
        -- the on-screen banner, so the chat is not flooded.
        chatFromSeconds = 30,
    },

    -- ANNOUNCEMENTS go to every connected player, whatever their bucket:
    --   chat  : an announcement row in open77_chat (Open77.chat.broadcast);
    --   toast : a banner from the platform's open77_notifications
    --           (Open77.notifications.broadcast) -- the countdown updates one
    --           banner in place instead of stacking new ones;
    --   lightrpEvent : when set (e.g. "op77_lightrp:announce"), also raised as a
    --           host-wide server event with { title, body, kind, durationMs }, for
    --           a gamemode that shows its own notice. Nil until op77_lightrp
    --           handles such an event (it has no announce export or event today).
    announce = {
        title = "ANNOUNCEMENT",
        author = "LIGHT RP",
        chat = true,
        toast = true,
        position = "top_center",
        icon = "77",
        durationMs = 12000,
        lightrpEvent = nil,
    },

    -- Texts of a scheduled show. Placeholders: {place}, {time}, {show}.
    texts = {
        scheduled = { title = "FIREWORKS", text = "Fireworks over {place} in {time}." },
        countdown = { title = "FIREWORKS", text = "Fireworks over {place} in {time}." },
        launch    = { title = "FIREWORKS", text = "Look up! Fireworks over {place}." },
        cancelled = { title = "FIREWORKS", text = "The fireworks over {place} are cancelled." },
    },

    -- THE OPENING-NIGHT MACRO (`/fireworks opening [delay] [place]`):
    -- announcement, countdown, then the finale, then a closing line.
    opening = {
        show = "finale",
        place = "crossing",
        delaySeconds = 5 * 60,
        texts = {
            scheduled = { title = "OPENING NIGHT", text = "Light RP is open! Fireworks over {place}, the Westbrook esplanade, in {time}." },
            countdown = { title = "OPENING NIGHT", text = "Fireworks over {place} in {time}. Meet at the Westbrook esplanade." },
            launch    = { title = "OPENING NIGHT", text = "Look up! Welcome to Light RP." },
            cancelled = { title = "OPENING NIGHT", text = "The opening fireworks are postponed." },
            after     = { title = "OPENING NIGHT", text = "Thanks for being here. Contracts and activities start at {place}. Have a good night in Night City." },
        },
    },
}
