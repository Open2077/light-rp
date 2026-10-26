"""Run the real garage/customization Lua against deterministic native/SQL boundaries."""
from pathlib import Path
import os
from lupa.lua54 import LuaRuntime
root = Path(__file__).resolve().parents[1] / 'resources/gamemodes/op77_lightrp'
os.chdir(root)
LuaRuntime(unpack_returned_tuples=True).execute((root / 'tests/garages_test.lua').read_text())

LuaRuntime(unpack_returned_tuples=True).execute((root / 'tests/vehicle_customization_client_test.lua').read_text())

LuaRuntime(unpack_returned_tuples=True).execute((root / 'tests/customization_payment_test.lua').read_text())
