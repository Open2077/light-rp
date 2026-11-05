-- One existing LightRP WebUI owns the private support desk and the staff desk.
local E=LightRpEvents
LightRpSupport={}
local native={noclip="admin.self.noclip",god="admin.self.god",advanced="adminfull"}
-- The admin menu (/admin) runs server commands as the operator: the host checks command.<name>
-- against the ACL for each one, so the page never grants anything. Only these families, a few
-- tokens, no control characters.
local FAMILIES={"admin.","adminfull","weather.","lightrp.","worldboss.","fixers.","missions.","turf.","tcg.rooms"}
local function family(name)
    for _,prefix in ipairs(FAMILIES) do if name==prefix or name:sub(1,#prefix)==prefix then return true end end
    return false
end
local function runCommand(tokens)
    if type(tokens)~="table" or #tokens<1 or #tokens>16 then return false end
    local clean={}
    for i=1,#tokens do
        local token=tostring(tokens[i] or ""):gsub("[%c]"," ")
        if #token>200 then token=token:sub(1,200) end
        if token~="" then clean[#clean+1]=token end
    end
    if #clean<1 or not family(clean[1]) then return false end
    return TriggerServerEvent("open77:command:execute",table.unpack(clean))~=false
end
-- Every command's answer (LightRP.reply, open77_admin output) goes to the page: the menu shows it.
RegisterNetEvent("open77:command:result",function(raw,ok,text)
    LightRpUi.send(E.page.support,{kind="commandResult",raw=tostring(raw or ""):sub(1,200),ok=ok==true,text=tostring(text or ""):sub(1,400)})
end)
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
        if p.operation=="command" then
            -- a tool that takes the screen (noclip, spectate, map travel, an editor): the menu closes first
            if p.close==true then
                LightRpUi.setSupportInput("closed")
                LightRpUi.send(E.page.dialogClose,{kind="support"})
            end
            runCommand(p.tokens)
            return
        end
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
