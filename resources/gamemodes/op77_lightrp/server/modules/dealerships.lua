local lightrpEvery = LightRP.every or function(ms, fn) while true do Wait(tonumber(ms) or 1000); fn() end end -- framework.lua (tests: the plain loop, in the calling thread)
local expireFlags, expireFlag = LightRP.expireFlags or function() end, LightRP.expireFlag or function() end -- framework.lua
local C, Db, E = LightRpDealerships, LightRP.db, LightRpEvents
local Dealer = LightRP.module("dealership", {})
local locations, sessions, opening = {}, {}, {}
local send, view
local function identity(id)
    local c = LightRP.characters.get(id)
    return c and c.status == "active" and c.identifier and (c.identifier .. "#" .. c.key)
end
local function guard(id, place)
    if not C.enabled or not place then return false, "This dealership is closed." end
    if not Db.ready then return false, "Vehicle sales are unavailable while the database is offline." end
    if not identity(id) or not LightRP.money.get(id) then return false, "Finish loading your character first." end
    if (LightRP.characters.switching or {})[id] then return false, "Your character is changing. Please wait." end
    local life = Open77.players.getLifeState(id)
    if not life or life.phase ~= "alive" then return false, "You cannot buy a vehicle right now." end
    if not LightRP.nearInteraction(id, { position = place.position, radius = C.range, bucket = place.bucket }, 0.75) then
        return false, "Walk up to the dealership marker."
    end
    if Open77.vehicles.getPlayerSeat(id) then return false, "Step out before visiting the showroom." end
    return true
end
view = function(id, session)
    local wallet = LightRP.money.get(id)
    return { kind = "dealership", session = session.id, nextRequest = session.nextRequest,
        dealer = { id = session.place.id, name = session.place.name, subtitle = session.place.subtitle },
        garage = LightRP.garage.location(session.place.garage), stock = session.stock,
        delivery = session.place.delivery and { name = session.place.delivery.name } or nil,
        money = { currency = LightRpConfig.economy.currency, cash = wallet and wallet.cash or 0, bank = wallet and wallet.bank or 0 } }
end
send = function(id, session, response)
    if sessions[id] ~= session or identity(id) ~= session.owner then return end
    response = response or {}
    response.session, response.state = session.id, view(id, session)
    TriggerClientEvent(E.net.dealership, id, response)
end
function Dealer.open(id, placeId)
    local place = locations[placeId]
    local valid, reason = guard(id, place)
    if not valid then return false, reason end
    if opening[id] or LightRP.garage.isBusy(id) then return false, "A vehicle operation is still running." end
    local who, token = identity(id), {}; opening[id] = token
    local ok, rows = Db.read("SELECT UUID() AS id")
    if opening[id] ~= token then return false, "This visit was cancelled." end
    opening[id] = nil
    if not ok or not rows[1] then return false, "The dealership could not prepare a secure purchase." end
    valid, reason = guard(id, place)
    if not valid or identity(id) ~= who then return false, reason or "Your character changed." end
    local stock = {}
    for _, offer in ipairs(place.stock) do
        local item = LightRP.vehicles.byKey[offer.key]
        stock[#stock+1] = { key=item.key, label=item.label, category=item.category, price=offer.price, description=offer.description }
    end
    local session = { id=rows[1].id, owner=who, place=place, stock=stock, nextRequest=1, expires=LightRP.nowMs()+C.sessionMs }
    sessions[id] = session
    LightRP.dialog(id,"dealership",view(id,session))
    return true
end
-- After a purchase: where to find the vehicle. A dealership with a delivery bay
-- drives it out there at once; otherwise, or when the bay cannot take it, it
-- waits at the garage. Either way a private blip and GPS route lead the buyer to
-- it (client/core/vehicle_gps.lua). Returns the text for the purchase screen.
local function handOver(id, place, rowId)
    local garage = LightRP.garage.location(place.garage)
    local name = LightRP.garage.label and LightRP.garage.label(rowId) or "Your vehicle"
    local bay, why = place.delivery, nil
    if bay then
        local ran, delivered, text, vehicleId = pcall(LightRP.garage.deliver, id, rowId, bay)
        if ran and delivered then
            TriggerClientEvent(E.net.vehicleGps, id, { position = bay.position, title = name, description = bay.name, vehicle = vehicleId })
            local body = string.format("%s is waiting for you at %s. Follow the GPS, then press L next to it to unlock it.", name, bay.name)
            pcall(LightRP.notice, id, { kind = "success", title = "Your new vehicle", body = body, durationMs = 12000 })
            return body
        end
        why = ran and text or "the delivery failed"
        if not ran then LightRP.log("dealership delivery failed: %s", tostring(delivered)) end
    end
    TriggerClientEvent(E.net.vehicleGps, id, { position = garage.position, title = garage.name,
        description = name .. " is stored here. Press E at the garage.", garage = true })
    local body = why and string.format("%s could not be driven out (%s) and is waiting at %s. Follow the GPS and press E at the garage.", name, why, garage.name)
        or string.format("%s is waiting at %s. Follow the GPS and press E at the garage.", name, garage.name)
    if bay then pcall(LightRP.notice, id, { kind = "success", title = "Your new vehicle", body = body, durationMs = 12000 }) end
    return body
end
function Dealer.buy(id, payload)
    local session = sessions[id]
    if type(payload) ~= "table" or not session or session.id ~= payload.session then return false, "Reopen the dealership." end
    if session.owner ~= identity(id) then sessions[id]=nil;return false,"Your character changed." end
    if session.busy then return false,"The purchase is already being processed." end
    if session.last and payload.request == session.last.request and payload.key == session.last.key and payload.pay == session.last.pay then
        send(id,session,{request=payload.request,ok=session.last.ok,text=session.last.text,vehicleId=session.last.vehicleId});return session.last.ok
    end
    if type(payload.request) ~= "number" or math.tointeger(payload.request) ~= session.nextRequest then
        send(id,session,{request=payload.request,ok=false,text="This request is out of date. Reopen the dealership."});return false
    end
    session.busy = true
    local request=payload.request;session.nextRequest=request+1
    local ran, ok, result = pcall(function()
        local valid, reason = guard(id,session.place)
        if not valid then return false,reason end
        if LightRP.nowMs()>session.expires then return false,"Your quote expired. Reopen the dealership." end
        if payload.pay~="cash" and payload.pay~="bank" then return false,"Choose cash or bank." end
        local offer
        for _,item in ipairs(session.stock) do if item.key==payload.key then offer=item;break end end
        if not offer then return false,"This vehicle is not sold here." end
        -- Session copy is the displayed quote; config is still authoritative.
        local current
        for _,item in ipairs(session.place.stock) do if item.key==payload.key then current=item;break end end
        if not current or current.price~=offer.price then return false,"The offer changed. Reopen the dealership to review the price." end
        return LightRP.garage.purchase(id,offer.key,session.place.garage,"dealer:"..session.id..":"..request,
            {amount=offer.price,method=payload.pay,vendor=session.place.name,silent=session.place.delivery~=nil,validate=function()
                if sessions[id]~=session or identity(id)~=session.owner then return false,"This visit was cancelled before payment." end
                return guard(id,session.place)
            end})
    end)
    session.busy=nil
    if not ran then LightRP.log("dealership purchase failed: %s",tostring(ok));ok,result=false,"Purchase could not be confirmed. Reopen the dealership to check your balance and garage." end
    local vehicleId = ok and result or nil
    local message = result
    if ok then
        local placed, text = pcall(handOver, id, session.place, result)
        message = placed and text or ("Purchase complete. Your vehicle is waiting at " .. LightRP.garage.location(session.place.garage).name .. ".")
    end
    session.last={request=request,key=payload.key,pay=payload.pay,ok=ok,text=message,vehicleId=vehicleId}
    session.expires=LightRP.nowMs()+C.sessionMs
    send(id,session,{request=request,ok=ok,text=message,vehicleId=vehicleId})
    return ok,result
end
LightRP.action("dealership.buy",function(id,payload) Dealer.buy(id,payload) end)
LightRP.action("dealership.close",function(id,payload)
    if sessions[id] and sessions[id].id==payload.session then sessions[id]=nil end
end)
function Dealer.onInteract(id,point)
    local placeId=point:match("^dealership%.(.+)$")
    if placeId then local ok,why=Dealer.open(id,placeId);if not ok then LightRP.result(id,false,why,"dealership.open") end end
end
function Dealer.onDisconnected(id) sessions[id],opening[id]=nil,nil end
function Dealer.onCharacterLoaded(id)
    local session = sessions[id]
    if session then TriggerClientEvent(E.net.dealership,id,{session=session.id,closed=true}) end
    Dealer.onDisconnected(id)
end
function Dealer.onLifeState(id,phase) if phase~="alive" then Dealer.onCharacterLoaded(id) end end
for _,place in ipairs(C.locations) do
    assert(type(place.id)=="string" and not locations[place.id] and LightRP.garage.location(place.garage),"Invalid dealership config")
    local used={}
    for _,item in ipairs(place.stock) do
        local entry=LightRP.vehicles.byKey[item.key]
        assert(entry and not entry.staffOnly and not used[item.key] and LightRP.money.validAmount(item.price),"Invalid dealership offer")
        used[item.key]=true
    end
    place.bucket=place.bucket or 0;locations[place.id]=place
    if C.enabled then LightRP.interaction("dealership."..place.id,{position=place.position,radius=C.range,bucket=place.bucket,
        label=place.name,prompt="Browse vehicles",key="E",marker=LightRpGarages.marker,ring=false,promptHeight=place.clerk and 1.1 or nil,
        blip={icon="car-front",sprite="Zzz01_CarForPurchaseVariant",title="Vehicle Dealership",description=place.name..(place.delivery
            and "\nBuy a personal vehicle. Handed over at the delivery bay, keys included." or "\nBuy a personal vehicle. Delivered to your public garage.")}}) end
end
-- A sales clerk at the desks that ask for one (crowd NPC, AI off; jobs.lua).
CreateThread(function()
    Wait(700)
    for _,place in pairs(locations) do
        if place.clerk and C.enabled and LightRP.jobs and LightRP.jobs.spawnClerk then
            place.npcId=LightRP.jobs.spawnClerk({id=place.id,kind="dealership",position=place.position,heading=place.heading,bucket=place.bucket})
        end
    end
end)
CreateThread(function()
    lightrpEvery(2000, function()
        
        for id,session in pairs(sessions) do
            if not guard(id,session.place) or session.owner~=identity(id) or LightRP.nowMs()>session.expires then
                TriggerClientEvent(E.net.dealership,id,{session=session.id,closed=true});sessions[id]=nil
            else send(id,session) end
        end
    end, "dealerships:166")
end)

-- Stale flags left by tasks the instruction quota killed (framework.lua expireFlags).
expireFlags("dealerships.opening", opening)
