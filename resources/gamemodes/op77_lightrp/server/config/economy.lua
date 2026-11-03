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
