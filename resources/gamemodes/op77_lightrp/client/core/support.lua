-- One existing LightRP WebUI owns the private support desk and the staff desk.
local E=LightRpEvents
LightRpSupport={}
local native={noclip="admin.self.noclip",god="admin.self.god",advanced="adminfull"}
RegisterNetEvent(E.net.support,function(value)
    if type(value)~="table" then return end
    if value.kind=="open" then
        LightRpUi.setMenuOpen(false)
        if LightRpAnimations then LightRpAnimations.close() end
        LightRpUi.send(E.page.dialog,{kind="support",scope=value.scope,body=value.body})
    else LightRpUi.send(E.page.support,value) end
end)
function LightRpSupport.bind(page)
    page:on(E.page.support,function(p)
        if type(p)~="table" then return end
        if p.operation=="input" then
            if p.mode=="menu" or p.mode=="form" or p.mode=="closed" then LightRpUi.setSupportInput(p.mode) end
            return
        end
        if p.operation=="open" then TriggerServerEvent("open77:command:execute",p.scope=="staff" and "admin" or "report");return end
        if p.operation=="native" then
            local command=native[p.action]
            if command then
                LightRpUi.setSupportInput("closed")
                LightRpUi.send(E.page.dialogClose,{kind="support"})
                TriggerServerEvent("open77:command:execute",command)
            end
            return
        end
        -- Staff events made here or a spot saved here: the district the engine sees, as the
        -- place name the city is told (the server keeps it a label, never a check).
        if p.operation=="eventsAction" and (p.where=="here" or p.action=="spotSave" or (p.action=="night" and p.where=="here")) then
            p.district=LightRpSupport.district()
        end
        TriggerServerEvent(E.net.support,p)
    end)
end
-- "Districts.LittleChina" / "LittleChina" -> "Little China"; "" when the engine has none.
function LightRpSupport.district()
    if not (Open77.world and type(Open77.world.district)=="function") then return "" end
    local ok,d=pcall(Open77.world.district)
    if not ok or type(d)~="table" then return "" end
    local name=tostring(d.subDistrict~=nil and d.subDistrict~="" and d.subDistrict or d.district or "")
    name=name:gsub("^[%w_]+%.",""):gsub("_"," "):gsub("(%l)(%u)","%1 %2")
    return name:sub(1,48)
end
