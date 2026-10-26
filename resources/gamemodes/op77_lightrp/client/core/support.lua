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
        TriggerServerEvent(E.net.support,p)
    end)
end
