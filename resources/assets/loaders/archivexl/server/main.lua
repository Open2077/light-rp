-- Marker only: the loader itself is a launcher-installed package (see open77.lua).
AddEventHandler("onResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print("[archivexl] archivexl 1.28.0-open77.2 (Open77 build for Cyberpunk 2.5) declared as a required mod (dist/ArchiveXL-1.28.0-open77.2.zip)")
end)
