-- Economy rules (server only: nothing here is downloaded). The prices themselves
-- live with their features (job_work, delivery, job_runs, missions, shops,
-- garages, fuel in shared/config.lua); this file holds the rules that cut across
-- them. Rationale and the before/after table: docs/economy-balance.md.
LightRpEconomy = {
    -- Missions and fixer gigs (server/modules/mission_pay.lua).
    missions = {
        -- A difficulty's `payout` is what EACH operator earns at the difficulty's
        -- minimum crew. Past it, the pot grows as crew^crewExponent and is split:
        -- share = payout * (crew / min) ^ (crewExponent - 1). 1 = everyone keeps
        -- the full payout (the old rule), 0 = a fixed pot split evenly.
        crewExponent = 0.7,
        -- After a full payout, the same mission point pays in full again to that
        -- character only after this long (board missions and gigs alike).
        cooldownMinutes = 60,
        -- Full payouts per UTC day. capScope "account" counts every character of
        -- the account together, "character" each character on its own.
        dailyFullPayouts = 6,
        capScope = "account",
        -- What a completion pays while on cooldown or past the daily cap, as a
        -- fraction of the share (reputation is never reduced).
        repeatShare = 0.25,
        -- Ceiling of the per-head payout, in eddies per minute of the difficulty's
        -- time limit: guards against authored missions saved with old payouts.
        maxSharePerMinute = 250,
    },

    -- Free work (job_work.lua) and work orders (job_runs.lua): each grade of the
    -- matching job adds this fraction to a sale or a run's pay (grade 2 = +20 %).
    jobs = {
        gradeBonus = 0.10,
    },

    -- Paychecks (jobs.lua, every LightRpConfig.jobs.paycheckMinutes) go to players
    -- who did something real in the last `windowMinutes` (work_activity.lua): a job
    -- task, a stabilized patient, a bank transfer of at least `servedMinimum` from
    -- another player, or getting `moveMetres` around the city (server position
    -- samples every `sampleSeconds`; a jump past `teleportMetres` is not a walk).
    -- Idle players get nothing and are told once why. false pays everyone (old rule).
    paychecks = {
        requireActivity = true,
        windowMinutes = 30,
        moveMetres = 75,
        teleportMetres = 2000,
        sampleSeconds = 20,
        servedMinimum = 50,
    },

    -- Activity results (activity_pay.lua; the core drops staff bot mode and
    -- `test` results before). PvP ranked pays
    --   perMinute x rate x minutes played (to maxSeconds) x min(1, real players /
    --   players) x (participation + resultBonus x result)
    -- with result 1 for a win / first place down to 0 for the last place (placement
    -- modes), 0.5 for a draw, 0 for a loss; a trial (record) scores a personal best
    -- or a course record. An average player near the job rate (~3,400 €$ an hour of
    -- matches), a good one about a fifth more. PvE pays perMinute[difficulty] x
    -- minutes (a loss lossShare of it): below jobs, far below missions.
    -- Nothing for: `result.unranked`, a PvP match with bots, real players all in one
    -- crew, a quit / forfeit (the one left standing keeps the participation share),
    -- under minSeconds, none of the mode's `progress` stats reached (AFK), modes not
    -- listed. Real players = accounts the server saw in the same activity and bucket
    -- (sampled every sampleSeconds). repeatPerHour[n]: paid results an hour between
    -- the same n accounts (a set bigger than the list is not limited). dailyCap per
    -- account (all characters) and UTC day, per kind.
    activities = {
        enabled = true,
        sampleSeconds = 10,
        pvp = {
            ledger = "activity_pvp",
            perMinute = 70,
            participation = 0.75,
            resultBonus = 0.5,
            dailyCap = 12000,
            repeatPerHour = { 4, 3, 4, 5 },
            modes = {
                ["arena.ffa"]    = { players = 4, minSeconds = 120, maxSeconds = 900, placement = true, progress = { kills = 1, assists = 1 } },
                ["arena.blade"]  = { players = 4, minSeconds = 120, maxSeconds = 900, placement = true, progress = { kills = 1, assists = 1 } },
                ["arena.duel"]   = { players = 2, minSeconds = 60, maxSeconds = 600, progress = { kills = 1, roundsWon = 1 } },
                ["arena.teams"]  = { players = 4, minSeconds = 120, maxSeconds = 900, progress = { kills = 1, assists = 1 } },
                ["race.trial"]   = { players = 1, rate = 0.5, minSeconds = 60, maxSeconds = 300, record = true, progress = { finished = true } },
                ["race.grid"]    = { players = 4, minSeconds = 60, maxSeconds = 600, placement = true, progress = { finished = true, checkpoints = 2 } },
                ["race.foot"]    = { players = 4, minSeconds = 60, maxSeconds = 600, placement = true, progress = { finished = true, checkpoints = 2 } },
                ["chase.1v1"]    = { players = 2, minSeconds = 90, maxSeconds = 600, progress = { roundsWon = 1, busts = 1, escapes = 1 } },
                ["chase.wanted"] = { players = 4, minSeconds = 120, maxSeconds = 900, placement = true, progress = { points = 1 } },
                ["turf.war"]     = { players = 6, minSeconds = 180, maxSeconds = 1200, progress = { captures = 1, kills = 1, holdSeconds = 30 } },
            },
        },
        pve = {
            ledger = "activity_pve",
            perMinute = { standard = 40, hard = 50, critical = 60 },
            lossShare = 0.5,
            dailyCap = 6000,
            -- `difficulty`: the activity's own, unless its result names one.
            modes = {
                ["arena.pve"] = { difficulty = "standard", minSeconds = 120, maxSeconds = 900, progress = { kills = 1, assists = 1 } },
                ["race.pve"]  = { difficulty = "standard", minSeconds = 60, maxSeconds = 600, progress = { finished = true, checkpoints = 2 } },
                ["chase.pve"] = { difficulty = "hard", minSeconds = 60, maxSeconds = 600, wonCounts = true, progress = { shakes = 1 } },
                ["turf.pve"]  = { difficulty = "hard", minSeconds = 120, maxSeconds = 600, progress = { captures = 1, kills = 1 } },
            },
        },
    },

    -- Waking up at the hospital after "Give up and go to hospital" (medical.lua).
    -- Never on a revive, never inside a mission or an activity, never during the
    -- first day guide nor the character's first `graceMinutes` of play. Taken from
    -- the bank, then from cash, and only what is there: never below zero.
    hospital = {
        bill = 300,
        graceMinutes = 120,
        counterparty = "Night City Medical",
    },

    -- A public fitting room in the city (wardrobe.lua): charged once per visit
    -- that ends with a saved look. Homes, the creation wizard, the first day and
    -- the character's first `graceMinutes` are free. Waived when the player
    -- cannot pay. 0 disables it.
    fitting = {
        fee = 50,
        graceMinutes = 120,
        counterparty = "Fitting room",
    },
}
