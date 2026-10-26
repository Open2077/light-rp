-- Deterministic, bounded station clusters. Complete-link avoids a chain of
-- roadside pumps accidentally merging two different forecourts.
LightRpFuelModel = {}
function LightRpFuelModel.distance(a, b)
    return math.sqrt((a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2)
end
function LightRpFuelModel.clusters(pumps, radius, height)
    local sorted, groups = {}, {}
    for _, p in ipairs(pumps) do sorted[#sorted+1] = p end
    table.sort(sorted, function(a,b) return a.id < b.id end)
    for _, p in ipairs(sorted) do
        local selected
        for _, g in ipairs(groups) do
            local fits = true
            for _, q in ipairs(g.pumps) do
                if LightRpFuelModel.distance(p.position,q.position) > radius
                    or math.abs(p.position.z-q.position.z) > height then fits = false; break end
            end
            if fits then selected = g; break end
        end
        if not selected then selected = { id=p.id, pumps={}, position={x=0,y=0,z=0} }; groups[#groups+1] = selected end
        selected.pumps[#selected.pumps+1] = p
    end
    for _, g in ipairs(groups) do
        for _, p in ipairs(g.pumps) do
            for _, axis in ipairs({'x','y','z'}) do g.position[axis] = g.position[axis] + p.position[axis]/#g.pumps end
        end
    end
    return groups
end
