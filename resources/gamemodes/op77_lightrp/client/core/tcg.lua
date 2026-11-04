-- Cyberpunk TCG (op77_tcg): its page takes the mouse for an opening, a display's shrink-wrap or the binder, and
-- says so with the local event op77_tcg:focus. LightRP's panels must not stay on top of it: the inventory a
-- booster was just used from closes (the page draws over op77_tcg's own surface).
AddEventHandler("op77_tcg:focus", function()
    if LightRpUi and LightRpUi.dialogs and LightRpUi.dialogs.inventory then
        LightRpUi.send(LightRpEvents.page.dialogClose, { kind = "inventory" })
    end
end)
