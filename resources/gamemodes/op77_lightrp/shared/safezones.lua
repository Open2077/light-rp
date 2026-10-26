-- Safezone wire validation. This file contains no private data or world reads.
local G = { MAX_ZONES = 64, MAX_POINTS = 32, AUTHOR_RADIUS = 500 }
LightRpSafezoneGeometry = G
function G.finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
function G.integer(n,low,high) return G.finite(n) and n%1==0 and n>=low and n<=high end
function G.point(p)
    if type(p)~="table" then return nil end
    for _,k in ipairs({"x","y","z"}) do if not G.finite(p[k]) or math.abs(p[k])>100000 then return nil end end
    return {x=p.x,y=p.y,z=p.z}
end
function G.clone(t)
    if type(t)~="table" then return t end
    local out={};for k,v in pairs(t) do out[k]=G.clone(v) end;return out
end
function G.text(s,max)
    if type(s)~="string" then return nil end
    s=s:gsub("^%s+",""):gsub("%s+$","")
    local n=utf8.len(s)
    if not n or n==0 or n>max or s:find("%c") then return nil end
    return s
end
function G.distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function cross(a,b,c) return (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x) end
local function onEdge(a,b,p)
    return math.abs(cross(a,b,p))<1e-7 and p.x>=math.min(a.x,b.x)-1e-7 and p.x<=math.max(a.x,b.x)+1e-7 and p.y>=math.min(a.y,b.y)-1e-7 and p.y<=math.max(a.y,b.y)+1e-7
end
local function intersects(a,b,c,d)
    local ac,ad,ca,cb=cross(a,b,c),cross(a,b,d),cross(c,d,a),cross(c,d,b)
    return (ac*ad<0 and ca*cb<0) or onEdge(a,b,c) or onEdge(a,b,d) or onEdge(c,d,a) or onEdge(c,d,b)
end
function G.validate(raw)
    if type(raw)~="table" then return nil,"Invalid zone." end
    local label=G.text(raw.label,80)
    if not label then return nil,"Choose a name of 1–80 characters." end
    if not G.integer(raw.bucket,0,2147483647) then return nil,"Invalid routing bucket." end
    if type(raw.enabled)~="boolean" then return nil,"Invalid activation state." end
    for _,name in ipairs({"blockRun","blockShoot","fullHeight"}) do
        if raw[name]~=nil and type(raw[name])~="boolean" then return nil,"Invalid zone rule: "..name end
    end
    local fullHeight=raw.fullHeight==true
    if not G.finite(raw.minZ) or not G.finite(raw.maxZ) or math.abs(raw.minZ)>100000 or math.abs(raw.maxZ)>100000
        or (not fullHeight and (raw.maxZ-raw.minZ<0.1 or raw.maxZ-raw.minZ>200)) then return nil,"Height must be between 0.1 and 200 metres." end
    local center=G.point(raw.center)
    if not center then return nil,"Invalid zone centre." end
    local z={label=label,bucket=raw.bucket,enabled=raw.enabled,shape=raw.shape,center=center,minZ=raw.minZ,maxZ=raw.maxZ}
    z.blockRun,z.blockShoot,z.fullHeight=raw.blockRun==true,raw.blockShoot~=false,fullHeight
    if raw.id~=nil and raw.id~="" then
        if type(raw.id)~="string" or #raw.id>64 or not raw.id:match("^[%w_-]+$") then return nil,"Invalid zone ID." end
        z.id=raw.id
    end
    if raw.shape=="circle" then
        if not G.finite(raw.radius) or raw.radius<0.5 or raw.radius>250 then return nil,"Radius must be between 0.5 and 250 metres." end
        z.radius=raw.radius
    elseif raw.shape=="box" then
        for _,k in ipairs({"length","width"}) do if not G.finite(raw[k]) or raw[k]<0.5 or raw[k]>500 then return nil,"Box dimensions must be between 0.5 and 500 metres." end end
        if not G.finite(raw.heading) then return nil,"Invalid box heading." end
        z.length,z.width,z.heading=raw.length,raw.width,raw.heading%360
    elseif raw.shape=="poly" then
        if type(raw.points)~="table" or #raw.points<3 or #raw.points>G.MAX_POINTS then return nil,"A polygon needs 3–32 vertices." end
        local count=0;for key in pairs(raw.points) do if not G.integer(key,1,#raw.points) then return nil,"Invalid polygon vertex array." end;count=count+1 end
        if count~=#raw.points then return nil,"Invalid polygon vertex array." end
        z.points={}
        for i,p in ipairs(raw.points) do
            local point=G.point(p);if not point then return nil,"Invalid polygon vertex." end
            for _,q in ipairs(z.points) do if (point.x-q.x)^2+(point.y-q.y)^2<0.01 then return nil,"Polygon vertices must be distinct." end end
            z.points[i]=point
        end
        local area,minX,maxX,minY,maxY=0,math.huge,-math.huge,math.huge,-math.huge
        local n=#z.points
        for i,a in ipairs(z.points) do
            local b=z.points[i%n+1]
            area=area+a.x*b.y-b.x*a.y
            minX,maxX,minY,maxY=math.min(minX,a.x),math.max(maxX,a.x),math.min(minY,a.y),math.max(maxY,a.y)
            for j=i+1,n do if j~=i+1 and not (i==1 and j==n) and intersects(a,b,z.points[j],z.points[j%n+1]) then return nil,"Polygon edges must not cross or touch." end end
        end
        if math.abs(area)<0.5 then return nil,"Polygon area is too small." end
        if maxX-minX>500 or maxY-minY>500 then return nil,"Polygon spans more than 500 metres." end
        z.center={x=(minX+maxX)/2,y=(minY+maxY)/2,z=(z.minZ+z.maxZ)/2}
    else return nil,"Choose circle, box or polygon." end
    return z
end
function G.definition(z)
    local center={x=z.center.x,y=z.center.y,z=z.fullHeight and 0 or (z.minZ+z.maxZ)/2}
    -- Full-height circles/boxes are queried at the player's altitude using
    -- options.origin, preserving exact planar maths without a faceted circle.
    if z.shape=="circle" then return {shape="cylinder",position=center,radius=z.radius,maxHeight=z.fullHeight and 2000 or (z.maxZ-z.minZ)/2} end
    if z.shape=="box" then return {shape="box",position=center,size={x=z.length,y=z.width,z=z.fullHeight and 4000 or z.maxZ-z.minZ},rotation=z.heading} end
    if z.fullHeight then return {shape="poly",points=z.points} end
    return {shape="poly",points=z.points,minZ=z.minZ,maxZ=z.maxZ}
end
function G.origin(z,position)
    if z.fullHeight and z.shape~="poly" then return {x=z.center.x,y=z.center.y,z=position.z} end
end
-- Authorship bounds include the whole volume, not only its displayed centre.
function G.withinAnchor(z,anchor)
    local points=z.points or {z.center}
    for _,p in ipairs(points) do
        local dx,dy=p.x-anchor.x,p.y-anchor.y
        local extra=z.shape=="circle" and z.radius or z.shape=="box" and math.sqrt(z.length^2+z.width^2)/2 or 0
        if math.sqrt(dx*dx+dy*dy)+extra>G.AUTHOR_RADIUS
            or (not z.fullHeight and (math.abs(z.minZ-anchor.z)>G.AUTHOR_RADIUS or math.abs(z.maxZ-anchor.z)>G.AUTHOR_RADIUS)) then return false end
    end
    return true
end
