-- RP policy. Canonical native `dead` is presented as unconscious until rescue
-- or a deliberate hospital transfer; no client-selected timer/effect values.
LightRpMedicalConfig = {
    giveUpDelayMs = 90000,
    downedScriptWeapons = { ["lightrp:needs"] = true }, -- starvation is real injury; placement scripts are not
    treatmentMs = 8000,
    handoffMs = 900,
    reviveHealth = .35,
    reviveGraceMs = 5000,
    range = 2.5,
    movementTolerance = .75,
    patientMovementTolerance = 1.0,
    maxPositionAgeMs = 2000,
    confirmationTimeoutMs = 20000,
    kit = "trauma_kit",
    animation = {profile="examine",clip="kneel__rk_on_ground__01__inspect_ground__01"},
}
LightRpItems.trauma_kit = {
    label="Trauma Stabilization Kit",
    description="Emergency stabilization equipment. Use near an unconscious person, remain still, and complete treatment to revive them.",
    weight=1.5,stack=2,category="medical",icon="briefcase-medical",image="img/items/firstaid.png",
}
