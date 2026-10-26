-- Register future categories here; each needs a server validator and UI editor.
LightRpVehicleCustomization = {
    categories = { { id = "paint", label = "Body paint", description = "Primary and secondary colors", icon = "palette" } },
    sessionMs = 300000, previewIntervalMs = 200,
    workshops = {
        { id = "auto_studio_1", name = "Auto Studio // Bay 01", bucket = 0, interactRadius = 3, storeRadius = 6,
          position = { x = -1034.573364, y = -1702.693726, z = 11.015274 } },
        { id = "auto_studio_2", name = "Auto Studio // Bay 02", bucket = 0, interactRadius = 3, storeRadius = 6,
          position = { x = -1025.970703, y = -1709.572754, z = 11.015274 } },
    },
    camera = { radius = 6.5, height = 2.1, targetHeight = 0.7, fov = 55, degreesPerSecond = 10, blendMs = 400 },
}
