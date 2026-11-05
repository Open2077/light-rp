"""Generate server/config/vehicle_kit.lua from the vehicle-kit fit tables.

The rims and body parts are designed and fitted in the Open77 repository
(scripts/vehicle-kit): the rim fit table (E1, specs/lightrp-rims-fit.json) and the
body-kit fit table (E2, specs/lightrp-bodykit-fit.json). This script turns them into
the Open77.vehicles.registerParts catalogue Light RP declares at start, plus the
studio's own data (part order, body groups, finish labels). It writes Lua only:
no model, archive or pack is copied here (the packs are resources of their own,
see resources/assets/models/lightrp_vehicle_kit/README.md).

    python tools/build_vehicle_kit.py --rims <...>/specs/lightrp-rims-fit.json \
        --body <...>/specs/lightrp-bodykit-fit.json [--body-spec <...>/specs/lightrp-bodykit.json]

Rim fits use the per-wheel `wheels` list of contract section 5 (a back axle that
differs, the Merrimac's middle axle, the Apollo's stock wheel slots). An entry lists
only what differs from its fit, so the catalogue stays small.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'server' / 'config' / 'vehicle_kit.lua'
CAR_WHEELS = ['wheel_front_left', 'wheel_front_right', 'wheel_back_left', 'wheel_back_right']
BIKE_WHEELS = ['wheel_front', 'wheel_back']
FINISHES = {
    'chrome': 'Chrome', 'black': 'Black', 'white': 'White', 'bronze': 'Bronze', 'gunmetal': 'Gunmetal',
    'carbon': 'Carbon', 'alu': 'Aluminium', 'steel': 'Steel',
}
# Body groups: one part per group on a car. The id is the spec's `kind`.
GROUPS = [
    ('spoiler', 'Wing'),
    ('lip', 'Front lip'),
    ('skirt', 'Side skirts'),
    ('roofrack', 'Roof'),
    ('bullbar', 'Push bar'),
]
DEFAULT_BODY_KINDS = {
    'wing_street': 'spoiler', 'wing_gt': 'spoiler', 'wing_duck': 'spoiler', 'wing_rally': 'spoiler',
    'lip_splitter': 'lip', 'skirt_side': 'skirt', 'roof_rack': 'roofrack', 'bull_bar': 'bullbar',
}


def number(value: float) -> str:
    text = f'{float(value):.4f}'.rstrip('0').rstrip('.')
    return '0' if text in ('-0', '') else text


def vector(values) -> list[float]:
    return [round(float(v), 4) for v in values]


def lua(value, indent: int = 0) -> str:
    pad = '    ' * indent
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (int, float)):
        return number(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list):
        if all(isinstance(v, (int, float, str)) for v in value):
            return '{ ' + ', '.join(lua(v) for v in value) + ' }' if value else '{}'
        inner = ',\n'.join(pad + '    ' + lua(v, indent + 1) for v in value)
        return '{\n' + inner + ',\n' + pad + '}'
    if isinstance(value, dict):
        if not value:
            return '{}'
        items = []
        for key, item in value.items():
            name = key if key.isidentifier() else '[' + json.dumps(key) + ']'
            items.append(f'{pad}    {name} = {lua(item, indent + 1)}')
        flat = '{ ' + ', '.join(item.strip() for item in items) + ' }'
        if len(flat) + len(pad) <= 110 and '\n' not in flat:
            return flat
        return '{\n' + ',\n'.join(items) + ',\n' + pad + '}'
    raise TypeError(type(value))


def differs(a, b) -> bool:
    return vector(a) != vector(b)


def rim_fit(record: str, fit: dict) -> dict:
    """One record's rim fit in the registerParts shape, with its `wheels` list when needed."""
    offset, scale = vector(fit.get('offset', [0, 0, 0])), vector(fit.get('scale', [1, 1, 1]))
    out = {'offset': offset, 'scale': scale}
    hide = list(fit.get('hide', []))
    slots, extra, names = fit.get('slots') or {}, fit.get('extraSlots') or {}, fit.get('slotNames') or {}
    if slots or extra or names:
        bike = bool(names) or 'bike' in record
        wheels = []
        for slot in (BIKE_WHEELS if bike else CAR_WHEELS):
            entry = {'slot': names.get(slot, slot)}
            own = slots.get(slot, {})
            if 'offset' in own and differs(own['offset'], offset):
                entry['offset'] = vector(own['offset'])
            if 'scale' in own and differs(own['scale'], scale):
                entry['scale'] = vector(own['scale'])
            wheels.append(entry)
        for slot, own in extra.items():
            entry = {'slot': slot}
            if 'offset' in own and differs(own['offset'], offset):
                entry['offset'] = vector(own['offset'])
            if 'scale' in own and differs(own['scale'], scale):
                entry['scale'] = vector(own['scale'])
            wheels.append(entry)
            hide += [name for name in own.get('hide', []) if name not in hide]
        out['wheels'] = wheels
    out['hide'] = hide
    return out


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()[:12]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--rims', type=Path, required=True, help='scripts/vehicle-kit/specs/lightrp-rims-fit.json')
    parser.add_argument('--body', type=Path, required=True, help='scripts/vehicle-kit/specs/lightrp-bodykit-fit.json')
    parser.add_argument('--body-spec', type=Path, help='scripts/vehicle-kit/specs/lightrp-bodykit.json (part kinds)')
    parser.add_argument('--output', type=Path, default=OUTPUT)
    args = parser.parse_args()

    rims_src = json.loads(args.rims.read_text(encoding='utf-8'))
    body_src = json.loads(args.body.read_text(encoding='utf-8'))
    kinds = dict(DEFAULT_BODY_KINDS)
    if args.body_spec:
        for part in json.loads(args.body_spec.read_text(encoding='utf-8'))['parts']:
            kinds[part['id']] = part['kind']

    rim_fits = {record: rim_fit(record, fit) for record, fit in rims_src['fit'].items()}
    rim_parts = {}
    for rim, part in rims_src['parts'].items():
        rim_parts[rim] = {'kind': 'rim', 'label': part['label'], 'variants': part['variants']}

    body_parts, groups = {}, {group: [] for group, _ in GROUPS}
    for part_id, part in body_src['parts'].items():
        group = kinds.get(part_id)
        if group not in groups:
            raise SystemExit(f'body part {part_id}: unknown group {group!r}')
        fits = {}
        for record, fit in part['fit'].items():
            # keep offset/rotation/scale/hide; drop estimate (and excluded/evidence above)
            entry = {key: (vector(fit[key]) if key != 'hide' else list(fit[key]))
                     for key in ('offset', 'rotation', 'scale', 'hide') if key in fit}
            fits[record] = entry
        body_parts[part_id] = {'kind': part['kind'], 'slot': part['slot'], 'label': part['label'],
                               'variants': part['variants'], 'fit': fits}
        groups[group].append(part_id)

    finishes = sorted({v for p in list(rim_parts.values()) + list(body_parts.values()) for v in p['variants']})
    unknown = [f for f in finishes if f not in FINISHES]
    if unknown:
        raise SystemExit(f'finish without a label: {unknown}')

    rim_fit_lua = lua(rim_fits, 0)
    lines = [
        '-- GENERATED by tools/build_vehicle_kit.py -- do not edit: re-run the generator.',
        f'-- Rims: {args.rims.name} sha256 {sha(args.rims)} ({rims_src.get("schema")}, game {rims_src.get("gameVersion")}).',
        f'-- Body: {args.body.name} sha256 {sha(args.body)} ({body_src.get("schema")}).',
        '-- Every offset is an OFFLINE ESTIMATE from mesh data until seen in game (docs/vehicle-customization.md).',
        '-- Server only: the registerParts catalogue (parts.*.fit) and the studio data (order, groups,',
        '-- finishes). The models come from the packs `rims.pack` / `body.pack` (asset:<pack>/<model>).',
        f'local rimFit = {rim_fit_lua}',
        'LightRpVehicleKit = {',
        '    generator = 1,',
        '    finishes = ' + lua({f: FINISHES[f] for f in finishes}, 1) + ',',
        '    finishOrder = ' + lua([f for f in FINISHES if f in finishes], 1) + ',',
        '    rims = {',
        f'        pack = {lua(rims_src.get("resource", "lightrp_vk_rims"))},',
        '        order = ' + lua(list(rim_parts), 2) + ',',
        '        excluded = ' + lua(rims_src.get('excluded', {}), 2) + ',',
        '        parts = {',
    ]
    for rim, part in rim_parts.items():
        lines.append(f'            {rim} = {{ kind = "rim", label = {lua(part["label"])}, variants = {lua(part["variants"], 3)}, fit = rimFit }},')
    lines += [
        '        },',
        '    },',
        '    body = {',
        f'        pack = {lua(body_src.get("resource", "lightrp_vk_body"))},',
        '        groups = {',
    ]
    for group, label in GROUPS:
        lines.append(f'            {{ id = {lua(group)}, label = {lua(label)}, parts = {lua(groups[group])} }},')
    lines += ['        },', '        parts = {']
    for part_id, part in body_parts.items():
        lines.append(f'            {part_id} = {lua(part, 3)},')
    lines += ['        },', '    },', '}', '']
    args.output.write_text('\n'.join(lines), encoding='utf-8', newline='\n')
    fits = sum(len(p['fit']) for p in body_parts.values())
    print(f'{args.output}: {len(rim_parts)} rims x {len(rim_fits)} records, {len(body_parts)} body parts, {fits} body fits')


if __name__ == '__main__':
    main()
