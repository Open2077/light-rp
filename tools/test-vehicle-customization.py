"""Run the real garage/customization Lua against deterministic native/SQL boundaries."""
from pathlib import Path
import os
from lupa.lua54 import LuaRuntime
root = Path(__file__).resolve().parents[1] / 'resources/gamemodes/op77_lightrp'
os.chdir(root)
LuaRuntime(unpack_returned_tuples=True).execute((root / 'tests/garages_test.lua').read_text())

LuaRuntime(unpack_returned_tuples=True).execute((root / 'tests/vehicle_customization_client_test.lua').read_text())

LuaRuntime(unpack_returned_tuples=True).execute((root / 'tests/customization_payment_test.lua').read_text())

LuaRuntime(unpack_returned_tuples=True).execute((root / 'tests/vehicle_customization_categories_test.lua').read_text())

LuaRuntime(unpack_returned_tuples=True).execute((root / 'tests/vehicle_customization_kit_test.lua').read_text())

LuaRuntime(unpack_returned_tuples=True).execute((root / 'tests/vehicle_persistence_audit_test.lua').read_text())

# Wave 2: the full flow needs the garage's category registry (else it checks the greying and
# prints SKIP); run once per place getProperties may keep the wave 2 keys.
wave2 = (root / 'tests/vehicle_customization_wave2_test.lua').read_text()
os.environ['LIGHTRP_WAVE2_KEYS'] = 'top'
if LuaRuntime(unpack_returned_tuples=True).execute(wave2):
    os.environ['LIGHTRP_WAVE2_KEYS'] = 'visual'
    LuaRuntime(unpack_returned_tuples=True).execute(wave2)
