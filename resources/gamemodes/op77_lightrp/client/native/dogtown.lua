-- Dogtown on screen, on NativeUI (was ui/src/features/dogtown/DogtownHud.tsx): the red
-- banner when the player walks in (or connects inside) and the persistent tile top-left
-- while inside or combat-tagged. The server decides everything (state key `dogtown`,
-- server/modules/dogtown.lua); the funds (pocket + bank) come from the state key `money`.
local N = LightRpNative

local D = {}
LightRpNativeDogtown = D

local BANNER_MS, BANNER_FADE_AT = 6500, 6000
-- lucide shield-check (not in client/native/icons.lua)
local SHIELD_CHECK = "M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1zM9 12l2 2l4-4"

local doc
local receivedAt = 0     -- the tag and the escort count down from the push that carried them
local bannerAt           -- once per entry
local wasInside = false

-- ---- pure helpers (the page's model.ts, bridge/money.ts) --------------------------------
local function num(v, d) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge and v or (d or 0) end

local function normalize(raw)
    if type(raw) ~= "table" then return nil end
    local r = type(raw.rules) == "table" and raw.rules or {}
    local s = type(raw.stake) == "table" and raw.stake or {}
    return {
        enabled = raw.enabled == true, label = type(raw.label) == "string" and raw.label or "Dogtown",
        inside = raw.inside == true, tagged = raw.tagged == true, tagEndsInMs = num(raw.tagEndsInMs),
        protected = raw.protected == true, protectedInMs = num(raw.protectedInMs),
        stake = { missing = num(s.missing), short = s.short == true, evictInMs = num(s.evictInMs) },
        streak = num(raw.streak), bounty = raw.bounty == true,
        rules = { share = num(r.share), min = num(r.min), max = num(r.max), bonus = num(r.bonus), stake = num(r.stake), graceSeconds = num(r.graceSeconds),
            stakeBank = r.stakeBank ~= false },
    }
end
--- "€$ 1,250": whole eddies, thousands grouped.
local function formatMoney(amount, currency)
    local n = num(amount)
    n = n < 0 and math.ceil(n) or math.floor(n)
    local digits = ("%d"):format(math.abs(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (n < 0 and "-" or "") .. (type(currency) == "string" and currency or "€$") .. " " .. digits
end
--- What a death costs this pocket: the share, at least the minimum, at most the cap, never more than carried.
local function cashAtRisk(cash, rules)
    if cash <= 0 then return 0 end
    local amount = math.floor(cash * rules.share)
    if rules.min > 0 then amount = math.max(amount, rules.min) end
    if rules.max > 0 then amount = math.min(amount, rules.max) end
    return math.max(0, math.min(amount, cash))
end
local function stakeMissing(cash, rules) return math.max(0, rules.stake - math.max(0, cash)) end
local function percent(share) return ("%d%%"):format(math.floor(share * 100 + 0.5)) end
--- 120 -> "2:00".
local function clock(seconds)
    local s = math.max(0, math.ceil(seconds))
    return ("%d:%02d"):format(s // 60, s % 60)
end
D.normalize, D.formatMoney, D.cashAtRisk, D.stakeMissing, D.percent, D.clock = normalize, formatMoney, cashAtRisk, stakeMissing, percent, clock

local function model()
    return {
        show = false, on = false,
        icSkull = N.icon("skull"), icShield = SHIELD_CHECK, icTimer = N.icon("timer"), icCrosshair = N.icon("crosshair"), icFlame = N.icon("flame"),
        bannerOn = false, bannerOut = false, short = false, labelUpper = "", lawA = "", lawB = "", lawSafe = false,
        cashText = "", stakeText = "", ruleText = "",
        tagged = false, outside = false, safe = false, bounty = false, tileIcon = N.icon("skull"), tileA = "", tileB = "", tileTitle = "",
        safeClock = "", escortSeconds = 0, tagSeconds = 0, streakOn = false, streak = 0, riskText = "",
    }
end

--- Draws the current state; returns true while a countdown (or the banner) is running.
local function render()
    if not doc then return false end
    local now = N.now()
    local d = normalize(N.state.dogtown)
    local inside = d ~= nil and d.enabled and d.inside
    -- the banner, once per entry
    if inside and not wasInside then bannerAt = now end
    if not inside then bannerAt = nil end
    wasInside = inside and true or false
    if bannerAt and now - bannerAt >= BANNER_MS then bannerAt = nil end

    local shell = N.shell
    local shellOn = shell.ready and not shell.hidden and not shell.quiet
    if not d or not d.enabled then N.patch(doc, "dt", { on = false, show = false, bannerOn = false }); return false end
    local elapsed = now - receivedAt
    local tagLeft = d.tagged and math.max(0, d.tagEndsInMs - elapsed) or 0
    local tagged = tagLeft > 0
    if not inside and not tagged then N.patch(doc, "dt", { on = false, show = false, bannerOn = false }); return false end

    local money = type(N.state.money) == "table" and N.state.money or {}
    -- pocket + bank (rules.stakeBank): what the stake and the loss count
    local bank = type(money.bank) == "table" and num(money.bank.balance) or 0
    local cash = num(money.cash) + (d.rules.stakeBank and math.max(0, bank) or 0)
    local function fmt(n) return formatMoney(n, money.currency) end
    local risk = cashAtRisk(cash, d.rules)
    -- The server's verdict (short) with the live pocket for the amount.
    local short = inside and d.stake.short
    local missing = stakeMissing(cash, d.rules)
    if missing == 0 then missing = d.stake.missing end
    local escortLeft = short and math.max(0, d.stake.evictInMs - elapsed) or 0
    -- Entry protection: out of the PvP grant until it runs out (the server ends it).
    local safeLeft = d.protected and math.max(0, d.protectedInMs - elapsed) or 0
    local safe = safeLeft > 0 and not short
    local upper = d.label:upper()

    local values = {
        on = true, show = shellOn, short = short, labelUpper = upper, safe = safe, tagged = tagged, outside = not inside, bounty = d.bounty,
        bannerOn = bannerAt ~= nil and inside, bannerOut = bannerAt ~= nil and now - bannerAt >= BANNER_FADE_AT,
        cashText = fmt(cash), safeClock = clock(safeLeft / 1000),
        escortSeconds = math.ceil(escortLeft / 1000), tagSeconds = math.ceil(tagLeft / 1000),
        streakOn = not d.bounty and d.streak > 0, streak = math.floor(d.streak),
        riskText = risk > 0 and (fmt(risk) .. " at risk") or "Nothing to take",
        tileIcon = short and N.icon("wallet") or safe and SHIELD_CHECK or N.icon("skull"),
        tileTitle = short and (fmt(missing) .. " missing") or inside and d.label or "Combat tag",
    }
    if short then
        values.lawA, values.lawB, values.lawSafe = "NO STAKE", "YOU CAN'T FIGHT HERE", false
        values.tileA, values.tileB = "NO STAKE", "NO PVP FOR YOU"
    elseif safe then
        values.lawA, values.lawB, values.lawSafe = "ENTRY PROTECTION", clock(safeLeft / 1000) .. " TO GET CLEAR", true
        values.tileA, values.tileB = "PVP ZONE", "YOU ARE PROTECTED"
    else
        values.lawA, values.lawB, values.lawSafe = "NO LAW", "ANYONE CAN KILL YOU", false
        if inside then values.tileA, values.tileB = "PVP ZONE", "NO LAW"
        else values.tileA, values.tileB = "LEFT " .. upper, "STILL ATTACKABLE" end
    end
    local held = d.rules.stakeBank and "cash + bank" or "cash"
    values.stakeText = ("The stake is %s (%s): %s missing. Leave within %d s or you are escorted out."):format(
        fmt(d.rules.stake), held, fmt(missing), math.floor(d.rules.graceSeconds))
    values.ruleText = ("A killer takes %s (%s, %s to %s) plus a %s bonus.%s"):format(
        fmt(risk), percent(d.rules.share), fmt(d.rules.min), fmt(d.rules.max), percent(d.rules.bonus),
        d.rules.stakeBank and " Cash first, then your bank." or " Your bank is safe.")
    N.patch(doc, "dt", values)
    return d.tagged or d.stake.short or d.protected or bannerAt ~= nil
end

N.onStart(function()
    doc = N.create({ document = "ui/native/dogtown.rml", zIndex = 20, models = { dt = model() } })
    if not doc then return end
    CreateThread(function()
        while true do
            local ok, counting = pcall(render)
            if not ok then N.log("dogtown render failed: " .. tostring(counting)) end
            Wait(ok and counting and 250 or 1000)
        end
    end)
end)
N.onShell(function() render() end)
N.onState("dogtown", function() receivedAt = N.now(); render() end)
N.onState("money", function() render() end)
