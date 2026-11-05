-- Marker only: the loader itself is a launcher-installed package (see open77.lua).
AddEventHandler("onResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print("[codeware] codeware 1.21.2 declared as a required mod (dist/Codeware-1.21.2.zip)")
end)
