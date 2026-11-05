-- Message sizes for the Titan bridge. The messages themselves never leave the Lua state as text any more (the
-- bridge hands tables to the resource, which hands tables to the network); what is left of the JSON module is what the
-- capture needs to keep a frame inside the budgets the resource and the server enforce:
--   count   the nodes of a value the way Open77's JSON encoder counts them
--   encode  Open77's own encoder (native; nil and a reason when the value is over its limits)
--   decode  Open77's own parser (native; nil and a reason for text that is not JSON)

local _ENV = require("controller.open77_titan_env")
local type, pairs = type, pairs

local M = {}

-- Counts nodes the way the client's JSON encoder does: every number, string, boolean and table is one, and so is
-- every key of every table. (This is the stricter, sending, side.) A leaf is counted where it is met (a key and a
-- value: two) instead of by a call of its own: the capture counts a few hundred nodes of every frame it sends.
function M.count(value)
  if type(value) ~= "table" then return 1 end
  local n = 1
  for _, v in pairs(value) do
    if type(v) == "table" then n = n + 1 + M.count(v) else n = n + 2 end
  end
  return n
end

function M.encode(value)
  return Open77.json.encode(value)
end

function M.decode(text)
  return Open77.json.decode(text)
end

return M
