-- Marker only: the loader itself is a launcher-installed package (see open77.lua).
AddEventHandler("onResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print("[audioxl] audioxl 0.9.1 declared as a required mod (dist/AudioXL-0.9.1.zip)")
end)
