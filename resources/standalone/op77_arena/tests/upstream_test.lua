-- The engine's own tests from base (resources/gamemodes/freeroam/pvp/tests, copied
-- verbatim into tests/upstream), run in the order base's FreeroamPvpGeometryTests runs
-- them -- with shared/lightrp.lua in place of Freeroam's shared/freeroam.lua, so the
-- arena geometry and the client wall are checked as op77_arena configures them.
-- Run: pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test upstream_test.lua
local say = print
for _, file in ipairs({ "shared/config.lua", "shared/kabuki.lua", "shared/lightrp.lua", "shared/wire.lua",
    "tests/upstream/wire_test.lua", "tests/upstream/geometry_test.lua", "client/bounds.lua",
    "tests/upstream/clamp_test.lua" }) do
    local ok, err = pcall(dofile, file)
    assert(ok, file .. ": " .. tostring(err))
end
say("PASS: op77_arena upstream engine tests (wire, geometry, client clamp)")
