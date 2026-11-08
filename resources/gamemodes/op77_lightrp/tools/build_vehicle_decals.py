"""Generate server/config/vehicle_decals.lua from the Open77 decal packs.

The original sticker sets and the liveries are built in the Open77 repository
(scripts/vehicle-kit/stickers/build-original-stickers.ps1 and
scripts/vehicle-kit/liveries/build-liveries.ps1); each built resource carries the
catalogue its server script registers: the stickers resource `catalogue.json`
(registerStickers rows: `model`, and `models` when the set fits trims of the same body),
the liveries resource `profiles.json` (registerPaintProfiles rows per record).

The Auto Studio never reads this table to offer anything: it lists stickers and liveries
from the natives (listStickers, listPaintProfiles), so a pack the server has not loaded
offers nothing. The table says which catalogue keys the packs cover, so a covered model
whose pack is stopped reads "not installed" instead of "no sticker fits", and it lists the
vanilla player bodies the packs cover that the catalogue does not sell (the lead's list
when adding catalogue keys). It writes Lua only: no pack is copied here (see
resources/assets/models/lightrp_vehicle_kit/README.md).

    python tools/build_vehicle_decals.py \
        --stickers <built>/lightrp_vehicle_original_stickers/catalogue.json \
        --liveries <built>/lightrp_vk_liveries/profiles.json
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'server' / 'config' / 'vehicle_decals.lua'
CONFIG = ROOT / 'shared' / 'config.lua'
STICKERS_SCHEMA = 'open77.vehicle-stickers.catalogue/1'
LIVERIES_SCHEMA = 'open77.vehicle-liveries.profiles/1'
LIVERY_PREFIX = 'Vehicle.o77_livery_'
KEY = re.compile(r'^[a-z0-9_]{1,64}$')
RECORD = re.compile(r'^Vehicle\.[A-Za-z0-9_]{1,120}$')
STICKER_ID = re.compile(r'^[a-z0-9][a-z0-9_.-]{0,63}$')
# Quest variants (Vehicle.q000_hym_player_car, ...) are out of the customization extension by
# the owner's decision: a pack listing one was built from a stale scope table.
QUEST = re.compile(r'^Vehicle\.q\d+_')


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()[:12]


def catalogue(path: Path) -> list[tuple[str, str]]:
    """(key, record) of LightRpConfig.vehicles.catalog, in file order."""
    text = path.read_text(encoding='utf-8')
    out = []
    for m in re.finditer(r'\{\s*key\s*=\s*"(\w+)"[^{}]*?record\s*=\s*"(Vehicle\.\w+)"[^{}]*\}', text):
        out.append((m.group(1), m.group(2)))
    if not out:
        raise SystemExit(f'{path}: no LightRpConfig.vehicles.catalog entry found')
    return out


def lua_str(value: str) -> str:
    if not re.fullmatch(r'[\x20-\x7e]*', value) or '"' in value or '\\' in value:
        raise SystemExit(f'not a plain ASCII string: {value!r}')
    return f'"{value}"'


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--stickers', type=Path, required=True, help='built lightrp_vehicle_original_stickers/catalogue.json')
    parser.add_argument('--liveries', type=Path, required=True, help='built lightrp_vk_liveries/profiles.json')
    parser.add_argument('--stickers-resource', default='lightrp_vehicle_original_stickers')
    parser.add_argument('--liveries-resource', default='lightrp_vk_liveries')
    parser.add_argument('--config', type=Path, default=CONFIG)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    args = parser.parse_args()

    st = json.loads(args.stickers.read_text(encoding='utf-8'))
    lv = json.loads(args.liveries.read_text(encoding='utf-8'))
    if st.get('schema') != STICKERS_SCHEMA:
        raise SystemExit(f'{args.stickers}: schema {st.get("schema")!r}, expected {STICKERS_SCHEMA}')
    if lv.get('schema') != LIVERIES_SCHEMA:
        raise SystemExit(f'{args.liveries}: schema {lv.get("schema")!r}, expected {LIVERIES_SCHEMA}')

    stickers: dict[str, list[str]] = {}
    for s in st['stickers']:
        if not STICKER_ID.fullmatch(s['id']):
            raise SystemExit(f'sticker id {s["id"]!r}')
        records = s.get('models') or [s['model']]
        if records[0] != s['model']:
            raise SystemExit(f'{s["id"]}: models must start with model')
        for r in records:
            if not RECORD.fullmatch(r):
                raise SystemExit(f'{s["id"]}: record {r!r}')
            if QUEST.match(r):
                raise SystemExit(f'{s["id"]}: quest variant {r} (out of scope, rebuild the pack)')
            stickers.setdefault(r, []).append(s['id'])
    liveries: dict[str, int] = {}
    for r, rows in lv['records'].items():
        if not RECORD.fullmatch(r):
            raise SystemExit(f'livery record {r!r}')
        ours = [row for row in rows if str(row.get('id', '')).startswith(LIVERY_PREFIX)]
        if ours and QUEST.match(r):
            raise SystemExit(f'liveries: quest variant {r} (out of scope, rebuild the pack)')
        if ours:
            liveries[r] = len(ours)

    cat = catalogue(args.config)
    by_record = {}
    for key, record in cat:
        if not KEY.fullmatch(key):
            raise SystemExit(f'catalogue key {key!r}')
        by_record.setdefault(record, key)

    lines = [
        '-- GENERATED by tools/build_vehicle_decals.py -- do not edit: re-run the generator.',
        f'-- Stickers: {args.stickers.name} sha256 {sha(args.stickers)} ({args.stickers_resource}, revision {st.get("revision")}).',
        f'-- Liveries: {args.liveries.name} sha256 {sha(args.liveries)} ({args.liveries_resource}, revision {lv.get("revision")}).',
        '-- What the decal packs carry per catalogue key. The studio offers stickers and liveries',
        '-- from the natives (listStickers, listPaintProfiles), never from this table: it only tells a',
        '-- covered model whose pack is stopped ("not installed") from a model no sticker fits.',
        'LightRpVehicleDecals = {',
        f'    packs = {{ stickers = {lua_str(args.stickers_resource)}, liveries = {lua_str(args.liveries_resource)} }},',
        f'    revisions = {{ stickers = {lua_str(str(st.get("revision")))}, liveries = {lua_str(str(lv.get("revision")))} }},',
        '    -- catalogue key -> the original sticker sets that fit its record, and its pack liveries',
        '    models = {',
    ]
    for key, record in cat:
        ids = stickers.get(record, [])
        listed = '{ ' + ', '.join(lua_str(i) for i in ids) + ' }' if ids else '{}'
        lines.append(f'        {key} = {{ stickers = {listed}, liveries = {liveries.get(record, 0)} }},')
    lines += [
        '    },',
        '    -- Vanilla player bodies the packs cover that the catalogue does not sell (no key, so',
        '    -- nobody owns one here yet): record -> sticker sets, pack liveries.',
        '    uncatalogued = {',
    ]
    others = sorted(r for r in set(stickers) | set(liveries) if r not in by_record)
    for r in others:
        lines.append(f'        [{lua_str(r)}] = {{ stickers = {len(stickers.get(r, []))}, liveries = {liveries.get(r, 0)} }},')
    lines += ['    },', '}', '']
    args.output.write_text('\n'.join(lines), encoding='utf-8', newline='\n')
    covered = sum(1 for _k, r in cat if stickers.get(r) or liveries.get(r))
    print(f'wrote {args.output}: {len(cat)} catalogue keys ({covered} covered), {len(others)} uncatalogued records')


if __name__ == '__main__':
    main()
