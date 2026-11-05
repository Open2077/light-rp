-- Server-owned prices for confirmed Auto Studio jobs, per category. Every price is
-- PROVISIONAL except paint (owner, 2026-11-05): docs/economy-balance.md, "Auto Studio".
LightRpCustomizationPricing = {
    paint = 2500,   -- body paint, both channels included (owner, 2026-11-05)
    lights = 500,   -- headlight/lamp tint, or back to factory lights -- PROVISIONAL
    trim = 2500,    -- one factory trim (appearance variant) -- PROVISIONAL
    livery = 4000,  -- one factory two-tone scheme, or back to plain paint -- PROVISIONAL
    rims = 6000,    -- a set of rims (every wheel, one finish), or back to factory rims -- PROVISIONAL
    body = 3500,    -- per body-kit group changed (wing, lip, skirts, roof, push bar) -- PROVISIONAL
    neon = 5000,    -- neon kit with its colour and brightness, or removing it -- PROVISIONAL
    plate = 2500,   -- a new registration number -- PROVISIONAL
    windows = 0,    -- not sold yet (no native): the category is greyed "Coming soon"
    -- Performance: price of each stage, per catalogue key; an upgrade pays every stage
    -- between the fitted one and the target. Going down (or back to stock) costs
    -- `performanceRemoval` and refunds nothing. Proposal of docs/research STAGES.md
    -- (10 / 15 / 20 % of the dealer price, weighted) -- PROVISIONAL.
    performanceRemoval = 1000,
    performance = {
        maimai = { 1000, 1500, 2000 }, galena = { 1500, 2000, 2500 }, hella = { 2500, 3500, 5000 },
        colby = { 3000, 4000, 5500 }, supron = { 3500, 5000, 7000 }, quartz = { 2500, 4000, 5000 },
        hozuki = { 6000, 9000, 12000 }, columbus = { 7500, 11500, 15000 }, cortes = { 9500, 14500, 19000 },
        merrimac = { 11500, 17500, 23000 }, bandit = { 11000, 16500, 22000 }, thrax = { 15500, 23500, 31000 },
        semimaru = { 25000, 37500, 50000 }, apollo = { 1000, 1500, 2000 }, kusanagi = { 20000, 30000, 40000 },
    },
}
-- Registration plates: words a plate may not contain (server only, never sent to a
-- client). Matched anywhere in the plate as written and in its "leet" reading (0=O 1=I
-- 3=E 4=A 5=S 7=T 8=B 9=G); a word with digits (1488) is matched as written only.
-- `reserved` are the service names nobody may wear.
-- The owner extends both lists.
LightRpCustomizationPlates = {
    banned = {
        "FUCK", "FUK", "SHIT", "CUNT", "DICK", "COCK", "PUSSY", "BITCH", "WHORE", "SLUT", "RAPE",
        "NAZI", "HITLER", "KKK", "SS88", "1488", "HEIL",
        "PUTE", "MERDE", "SALOPE", "CONNARD", "CONNAR", "ENCULE", "NIQUE", "BITE", "CHATTE",
        "NIGGER", "NIGGA", "NEGRO", "FAGGOT", "FAG", "TRANNY", "RETARD",
    },
    reserved = { "NCPD", "POLICE", "MAXTAC", "TRAUMA", "STAFF", "ADMIN", "MILITECH", "ARASAKA" },
}
