-- Runs the server half against tests/fakes.lua (working directory: the resource root),
-- in the order the platform test harness of open77_scenes uses:
--   pwsh tests/run-lua.ps1 -Test all.lua
for _, file in ipairs({ "tests/fakes.lua", "shared/scenes.lua", "server/core.lua", "server/main.lua", "tests/scenes_test.lua" }) do
    dofile(file)
end
local r = TestResult
print(("op77_scenes: %d passed, %d failed"):format(r.passed, r.failed))
for _, failure in ipairs(r.failures) do print("  FAIL " .. tostring(failure)) end
if r.failed > 0 then error("op77_scenes tests failed") end
