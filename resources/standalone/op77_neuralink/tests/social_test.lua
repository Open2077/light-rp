-- Offline test of Screamsheet's text rules (server/social.lua): handles,
-- #tags, @mentions and districts. Run from the resource folder:
--     lua54 tests/social_test.lua
local failures, checks = 0, 0
local function check(cond, label)
    checks = checks + 1
    if not cond then failures = failures + 1; print("FAIL " .. label) end
end
local function same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

Neural = { store = {}, lines = {} }
dofile("shared/config.lua")
dofile("server/social.lua")
local Social = Neural.social

-- handles
check(Social.validHandle("judy_a"), "plain handle")
check(Social.validHandle("abc"), "3 characters")
check(not Social.validHandle("ab"), "too short")
check(not Social.validHandle("a234567890123456x"), "17 characters")
check(not Social.validHandle("Judy"), "uppercase")
check(not Social.validHandle("judy-a"), "dash")
check(not Social.validHandle(nil), "nil")
check(Social.handleBase("Jack Rob") == "jack_rob", "base from a name")
check(Social.handleBase("  Alex   Morgan  ") == "alex_morgan", "spaces collapse")
check(Social.handleBase("Rogue Amendiares") == "rogue_a", "long name: first name and initial")
check(Social.handleBase("Jackie Welles") == "jackie_w", "13 characters: first name and initial")
check(Social.handleBase("Judy Alvarez") == "judy_alvarez", "12 characters kept whole")
check(Social.handleBase("Abcdefghijklmnopq") == "abcdefghijkl", "one long word cut at 12")
check(Social.handleBase("Jo") == "citizen", "too short falls back")
check(Social.handleBase("Été") == "citizen", "no ASCII left falls back")
check(Social.handleBase("V__") == "citizen", "underscores trimmed then too short")
check(Social.validHandle(Social.handleBase("Panam Palmer") .. "_999"), "base plus suffix stays valid")
check(Social.validHandle(Social.handleBase("Abcdefghijklmnopq") .. "_999"), "12 plus suffix stays valid")

-- tags
check(same(Social.parseTags("Night at the #Afterlife with #maxtac #afterlife"), { "afterlife", "maxtac" }), "tags lowered and unique")
check(same(Social.parseTags("#a #ok #trauma_team"), { "ok", "trauma_team" }), "one-letter tag ignored")
check(same(Social.parseTags("#1 #2 #3 #4 #5 #6 #77 #88 #99 #10 #11 #12"), { "77", "88", "99", "10", "11" }), "five tags at most")
check(#Social.parseTags("no tags here") == 0, "none")
check(#Social.parseTags("#" .. string.rep("x", 33)) == 0, "33-character tag ignored")

-- mentions
check(same(Social.parseMentions("@Judy_A @panam and @judy_a again"), { "judy_a", "panam" }), "mentions lowered and unique")
check(same(Social.parseMentions("mail me at v@x and @ab"), {}), "short handles ignored")

-- districts
check(Social.cleanDistrict("Kabuki") == "Kabuki", "district kept")
check(Social.cleanDistrict("  Japantown ") == "Japantown", "district trimmed")
check(Social.cleanDistrict("<b>Watson</b>") == "bWatson/b", "angle brackets stripped")
check(Social.cleanDistrict("") == nil, "empty is nil")
check(Social.cleanDistrict(string.rep("x", 41)) == nil, "too long is nil")
check(Social.cleanDistrict(12) == nil, "not a string")
check(Social.cleanDistrict("LocKey#10963") == nil, "unresolved LocKey refused")

print(string.format("%d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)
