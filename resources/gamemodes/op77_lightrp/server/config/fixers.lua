-- Fixer gigs (server/modules/fixers.lua). The fixers are server-side characters:
-- every so often one of them texts an online player a job taken at random from the
-- gig catalogue (authored missions tagged "Fixer gig" in the mission editor: they
-- have no board in the city, nobody tags in). The player accepts or passes from the
-- message; once accepted, the fixer sends the meeting point and the objective (with
-- a button that pins it on the map). The gig owner can share the job with contacts
-- or any phone number; whoever accepts joins the crew, up to the job's squad size.
-- The crew meets at the point; the gig launches when everyone who accepted is there
-- (or when the owner says go with enough of them), and runs like any mission.
--
-- Texts are RP lines with placeholders: {player} {title} {location} {difficulty}
-- {payout} {objective} {crew} {max} {minutes} {owner} {fixer}.
LightRpFixers = {
    enabled = true,

    dispatch = {
        -- first offers this long after the server start, then a scan every `every`
        firstDelaySeconds = 180,
        everySeconds = 60,
        -- each scan, each eligible player has this chance to get a text
        chance = 0.08,
        -- after an offer (whatever the answer) a player waits this long for the next
        playerCooldownMinutes = 20,
        -- at most this many gigs open or running at once, server-wide
        maxOpen = 6,
        -- only players this long in the city since they joined
        settleSeconds = 120,
    },

    -- How long an offer (and a shared invitation) waits for an answer.
    offerSeconds = 180,
    -- How long the crew has to reach the meeting point once the owner accepted.
    meetMinutes = 20,
    -- The meeting point: everyone within this radius (horizontal) and this height
    -- difference counts as there.
    meetRadius = 20.0,
    meetHeight = 15.0,
    -- Countdown once the whole crew is at the point (or the owner says go).
    launchSeconds = 10,
    -- Shares one gig can send (pending + accepted), and per minute.
    maxShares = 12,
    sharesPerMinute = 6,

    -- The fixer's pay: the difficulty's payout times this.
    payoutMultiplier = 1.0,
    -- Which difficulty a gig is offered at (weights); a difficulty whose minimum
    -- squad is above 1 makes the owner bring a crew (shares).
    difficultyWeights = { standard = 6, hard = 3, critical = 1 },

    -- Map pin of the meeting point (client: Open77 waypoint / blip).
    pin = { sprite = "objective", label = "Gig: {title}" },

    contacts = {
        {
            id = "okoro",
            name = "Mama Okoro",
            number = "555-0147",
            tagline = "Heywood. Pays on time, remembers who doesn't.",
            lines = {
                offer = {
                    "{player}, it's Mama Okoro. Got work with your name on it: {title}, out in {location}. {payout} if it's clean. You in?",
                    "Choom, I need hands. {title}, {location}. {difficulty} job, {payout} on delivery. Yes or no, I don't have all day.",
                },
                accepted = {
                    "Good. Head to {location}, I'm pinning the spot. {objective} Don't keep me waiting.",
                    "That's what I like to hear. Meet point's on your map. {objective}",
                },
                declined = { "Your loss, choom. Next one goes to someone hungrier.", "Fine. I'll remember you said no." },
                expired = { "Took too long. Job's gone to somebody else.", "Silence is a no in my book. Moving on." },
                shared = { "{owner} vouched for you. {title} in {location}, {payout} a head. You in?" },
                success = { "Clean work. {payout} wired. Don't spend it all at once.", "Eddies are on the way. That's how it's done." },
                failed = { "That went sideways. Don't make it a habit.", "Bad day. We'll talk when you're breathing easier." },
                cancelled = { "Job's off. Stand down, choom." },
            },
        },
        {
            id = "ledger",
            name = "Silas \"Ledger\" Varga",
            number = "555-0322",
            tagline = "Corpo leftovers, sold by the pound.",
            lines = {
                offer = {
                    "Mr. or Ms. {player}. A {difficulty} opportunity: {title}, {location}. Compensation {payout}. Reply at your convenience, which is now.",
                    "I have a line item that needs closing. {title}, {location}. {payout}. Interested?",
                },
                accepted = {
                    "Excellent. Coordinates attached. {objective} Discretion is part of the fee.",
                    "Contract noted. The meeting point is pinned. {objective}",
                },
                declined = { "Noted. The opportunity has been reallocated.", "Understood. No hard feelings, only records." },
                expired = { "The offer has lapsed. Punctuality is a skill.", "Window closed. Better luck next quarter." },
                shared = { "{owner} has subcontracted you. {title}, {location}, {payout} per operator. Accept?" },
                success = { "Deliverable received. {payout} transferred.", "Invoice settled. A pleasure." },
                failed = { "The client is displeased. So am I.", "We will call this a learning expense." },
                cancelled = { "The contract has been withdrawn." },
            },
        },
        {
            id = "nix",
            name = "Nix Delacroix",
            number = "555-0619",
            tagline = "Pacifica runner. Fast money, faster exits.",
            lines = {
                offer = {
                    "yo {player}! got a gig, {title} in {location}. {payout}, {difficulty} vibes. u down??",
                    "hey hey. {title}. {location}. {payout}. say yes and i'll send the spot",
                },
                accepted = {
                    "lets gooo. pinned it for u. {objective}",
                    "ok ok. spot's on ur map. {objective} dont flatline",
                },
                declined = { "aw ok. next time", "ur loss lol" },
                expired = { "ghosted me huh. gig's gone", "too slow choom" },
                shared = { "{owner} says ur solid. {title} in {location}, {payout} each. in?" },
                success = { "LEGEND. {payout} sent", "clean af. eddies incoming" },
                failed = { "oof. that hurt to watch", "we don't talk about that one" },
                cancelled = { "gig's dead, sry" },
            },
        },
    },
}
