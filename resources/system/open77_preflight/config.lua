-- Light RP: the launcher's server check in the Light RP design (light-rp repo,
-- resources/system/open77_preflight: this file, ui/custom/ and the art script
-- tools/build-preflight-art.py). The rest of the resource is open77-base's open77_preflight,
-- copied unchanged; re-copy it on a runtime update and keep this file and ui/custom/.
--
-- open77_preflight settings. Edit, then `ensure open77_preflight` at the console: no
-- server restart is needed. Everything here is optional; what you leave out keeps the
-- value shown. Out of the box the resource only welcomes players and presents the
-- door list's refusals (bans, whitelist): every extra step below is off.
--
-- All text is shown to players as written. Links must start with https://.

PreflightConfig = {
    -- Links offered on the screens. Leave one empty to hide it.
    links = {
        discord = "https://discord.gg/open77",
        appeal = "",    -- where a banned player may appeal; empty: the Discord link is used
        website = "https://open2077.net/",
    },

    -- The anonymous screen the launcher shows on this server's page, before Join.
    -- The server name, description, player count and whitelist state come from the
    -- server itself (server.jsonc and the door list).
    welcome = {
        enabled = true,
        title = "",         -- empty: the server's name
        text = "",          -- empty: the server's description
        showPlayers = true, -- "12 / 64 players"
        showRules = false,  -- the rules are asked on Join (rules.enabled), not listed here
    },

    -- Short lines shown on the welcome screen and above the rules. Change them live
    -- with the console command `preflight.announce <text>` (and `preflight.announce clear`).
    announcements = {
        "The launcher now checks your access before the game starts: no more loading for nothing.",
        "Dogtown: the entry stake draws on your bank when your pocket is short.",
        "Missions pay in full once a day per difficulty.",
    },

    -- Rules a player must accept once before their first join. Bump `version` when
    -- you change them: everybody is asked again.
    rules = {
        enabled = true,
        version = "1",
        title = "House rules",
        items = {
            "Stay in character: plain chat is in character, /ooc steps out of it.",
            "No random kills and no car ramming: every fight needs a roleplay reason (no RDM / VDM).",
            "Respect the other players and the staff: no harassment, no hate speech.",
            "No cheats, no exploits, no metagaming: what you learn out of character stays out of character.",
            "A problem in game? /report reaches the staff.",
        },
        -- false: the "I accept" button alone is enough, no checkbox to tick.
        checkbox = true,
    },

    -- Require a Discord account linked to the OPEN//77 account. The Discord id is
    -- verified by the master server (session.player.discord); nothing is asked of the
    -- player here. Needs a launcher that sends a connect ticket: an older one is told
    -- to update.
    -- Off on Light RP (2026-11-16): the server is open to everyone.
    discord = {
        required = false,
        message = "This server needs a Discord account linked to your OPEN//77 account. " ..
            "Link it in the launcher (Settings > Account), then join again.",
    },

    -- What a player the whitelist refuses sees (the whitelist itself is switched on in
    -- Warden, or with `whitelist.on` at the console).
    whitelist = {
        -- true: an application form. The request appears in Warden (Access > Requests),
        -- at the console (`whitelist.requests`) and through this resource's exports;
        -- approving it lets a player who is still waiting straight in.
        -- false: a page with their player id and your links.
        applications = true,
        prompt = "Tell the staff who you are and how you found the server.",
        minLength = 10,     -- characters the application needs
        -- A player whose application was denied may send a new one.
        reapply = true,
        -- Invite codes that whitelist at once, without staff. Case-insensitive.
        -- Anyone who knows a code gets in: treat them like passwords and rotate them.
        -- Five wrong codes lock the field for that account for ten minutes.
        inviteCodes = {
            -- "NC-2077",
        },
    },

    -- Maintenance: everybody is refused with `message`, except the identities listed
    -- in `allow` (and whitelisted players when `allowWhitelisted`). Switch it live
    -- with `preflight.maintenance on [message]` / `off`; the console wins over this
    -- file until `preflight.maintenance default`.
    maintenance = {
        enabled = false,
        message = "The server is under maintenance. Please come back later.",
        allowWhitelisted = false,
        allow = {
            -- "00000000-0000-0000-0000-000000000000",
        },
    },

    -- The server is full. Preflight never refuses for capacity by itself (the game's
    -- handshake does); this only tells the player before the game starts.
    --   "wait":   a waiting screen; the player is let through when a slot frees, or
    --             when they press "Try anyway".
    --   "refuse": a refusal page.
    --   "off":    say nothing.
    full = {
        mode = "wait",
        message = "The server is full. You will be let in as soon as a slot frees.",
    },

    -- Ban pages. The reason and the expiry are what the staff typed in Warden.
    bans = {
        showReason = true,
        showStaff = false,  -- true: "Banned by warden:alice"
    },

    -- The line the launcher may show on its way to the game. {name} and {server} are
    -- replaced, and so is any {key} that ui.provider gives a text or a number for.
    -- op77_lightrp words it per player ("Welcome back to Night City, <character>."); this
    -- line is used when it cannot answer.
    allowedMessage = "Welcome to Night City, {name}.",

    -- A short screen for players who passed every step, right before the game starts:
    -- the allowed line in big, and a button to go at once. 0 seconds: wait for the button.
    greeting = {
        enabled = true,
        seconds = 5,
    },

    -- Your own look. Every screen is an .rml document of this resource; name your own file
    -- for any of them (keep the {{ bindings }} and the event names of the shipped one in
    -- ui/). Images go in ui/custom/ (png, jpeg, webp: the manifest already serves them)
    -- and are shown with <img src="asset:ui/custom/logo.png"/>. A document that cannot be
    -- sent falls back to the shipped one.
    ui = {
        documents = {
            welcome = "ui/custom/lightrp-welcome.rml",
            rules = "ui/custom/lightrp-rules.rml",
            apply = "ui/custom/lightrp-apply.rml",
            refused = "ui/custom/lightrp-refused.rml",
            full = "ui/custom/lightrp-full.rml",
            greeting = "ui/custom/lightrp-greeting.rml",
        },
        -- Values every screen's data gets: your tagline, the image paths, colours...
        data = {
            tagline = "Light roleplay on Cyberpunk 2077.",
        },
        -- A server resource that completes each screen's data for the player who sees
        -- it (their characters, their last visit...). It exports `providerExport`:
        --   exports("preflightScreen", function(screen, context) return { key = value } end)
        -- It may take its time (a database query) up to providerTimeoutMs; past that,
        -- or on any error, the screen is shown without its values. See README.md.
        provider = "op77_lightrp", -- server/modules/preflight.lua: characters, last visit, residents
        providerExport = "preflightScreen",
        providerTimeoutMs = 1500,
    },

    -- How long a kick through this resource's `kick` export is shown to the player
    -- when they try to join again.
    kickSeconds = 120,

    -- Which other resources may call the exports that list or change the door list
    -- (ban, unban, whitelistAdd, approve, kick, requests, ...). Empty: none. "*": every
    -- resource on this server. The read-only yes/no exports (isBanned, isWhitelisted,
    -- whitelistEnabled, maintenance) are open to all.
    api = {
        trusted = {
            "open77_admin",
        },
    },
}
