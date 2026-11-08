-- Client: registers every cooked model of this pack as asset:<resource>/<model>.
-- Decision D4: a model that cannot register is skipped with a log line, and the others
-- still register. Never raise here: an error fails the resource activation, and that
-- disconnects the player. prop_archive_missing_restart_required means the game mounted
-- an older archive than this package (preload_mod archives mount at game start).
local function log(text) print('[vehicle-kit] ' .. text) end

local ok, package = pcall(json.decode, LoadResourceFile(GetCurrentResourceName(), 'package.json') or '')
if not ok or type(package) ~= 'table' or package.schema ~= 'open77.prop-package/1' or type(package.models) ~= 'table' then
    log('package.json is missing or invalid: no model registered')
    return
end
local revision = tostring(package.revision or '?'):sub(1, 12)

local ids = {}
for id in pairs(package.models) do ids[#ids + 1] = id end
table.sort(ids)   -- a stable log order

local registered, skipped = 0, 0
for _, id in ipairs(ids) do
    local def = package.models[id]
    -- registerModel accepts exactly mesh / visualEntity / physicalEntity.
    local called, alias, reason = pcall(Open77.props.registerModel, id, { mesh = def.mesh, visualEntity = def.visualEntity })
    if called and alias then
        registered = registered + 1
    else
        skipped = skipped + 1
        log(('skipped model %s: %s'):format(id, tostring(called and reason or alias)))
    end
end
log(('registered %d of %d models, skipped %d, revision %s'):format(registered, #ids, skipped, revision))
