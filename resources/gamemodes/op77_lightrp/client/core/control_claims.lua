-- Native claims belong to a resource, so features must OR their restrictions
-- before releasing a native action. Leaving a zone must not unlock a pending gun.
LightRpControlClaims = { owners = {}, applied = {} }
function LightRpControlClaims.set(owner, action, blocked)
    local C = LightRpControlClaims
    C.owners[owner] = C.owners[owner] or {}
    C.owners[owner][action] = blocked == true or nil
    local effective = false
    for _, claims in pairs(C.owners) do if claims[action] then effective = true; break end end
    if C.applied[action] == effective then return true end
    local api = Open77.input and Open77.input.setActionBlocked
    if type(api) ~= "function" then return false, "unavailable" end
    local ok, reason = api(action, effective)
    if ok == true then C.applied[action] = effective end
    return ok, reason
end
