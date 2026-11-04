#!/usr/bin/env python3
"""Cook the Maneki-neko collectible host: one visual entity over the game's own lucky cat.

The collectible (op77_lightrp server/modules/maneki.lua, client/core/maneki.lua) shows
the vanilla waving cat `chinese_sculpture_small_c.mesh` (16 cm, Japantown shops) as a
client-local prop. Local props take a raw `.ent` under open77\\assets\\, and 2.31 cannot
redirect a mesh component at runtime, so this writes one authored host entity that binds
the vanilla mesh. No game mesh or texture is copied: the archive holds the .ent only.

The host is the board games' visual entity (same entMeshComponent, same flags), taken
from resources/assets/models/open77_board_games/dist, with its mesh path, component
name and id replaced. Windows + WolvenKit CLI 8.19 (E:/Apps/WolvenKit.Console).

    python tools/build-maneki-props.py [--wolvenkit PATH] [--work DIR]
"""
import argparse, copy, hashlib, json, shutil, subprocess, tempfile, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = ROOT / 'resources/assets/models/open77_maneki'
HOST_ZIP = ROOT / 'resources/assets/models/open77_board_games/dist/open77_board_games.zip'
HOST_ENT = 'open77/assets/op77_lightrp/board_games/checkers_black_man.ent'
DEPOT = 'open77\\assets\\op77_lightrp\\maneki'
MESH = 'base\\environment\\decoration\\misc\\sculptures\\chinese_sculpture_small\\chinese_sculpture_small_c.mesh'
MODELS = {'maneki_neko': MESH}
ARCHIVE_NAME = '0_open77_maneki.archive'


def cn(value): return {'$type': 'CName', '$storage': 'string', '$value': value}


def retarget(template, mesh, ident):
    obj = copy.deepcopy(template)
    root = obj['Data']['RootChunk']
    chunks = root['compiledData']['Data']['Chunks']
    components = [c for c in root['components'] if c['$type'] == 'entMeshComponent']
    compiled = [c for c in chunks if c['$type'] == 'entMeshComponent']
    assert len(components) == 1 and len(compiled) == 1, 'host must hold exactly one mesh component'
    for c in (components[0], compiled[0]):
        c['mesh']['DepotPath']['$value'] = mesh
        c['meshAppearance'] = cn('default')
        c['name'] = cn('maneki_mesh')
        c['id'] = ident
        c['castShadows'] = 'Always'
        c['castLocalShadows'] = 'Always'
    root['compiledData']['Data']['CruidDict'] = {'0': '0', '1': ident}
    obj['Header'].pop('ArchiveFileName', None)
    return obj


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wolvenkit', type=Path, default=Path('E:/Apps/WolvenKit.Console/WolvenKit.CLI.exe'))
    parser.add_argument('--work', type=Path, default=None)
    args = parser.parse_args()
    work = args.work or Path(tempfile.mkdtemp(prefix='maneki-build-'))
    for stale in ('host', 'host-json', 'json', 'archive', 'packed', 'verified'):
        shutil.rmtree(work / stale, ignore_errors=True)

    def cli(*words):
        result = subprocess.run([str(args.wolvenkit), *map(str, words)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if result.returncode or ': Error' in result.stdout:
            print(result.stdout)
            raise RuntimeError('WolvenKit command failed: ' + ' '.join(map(str, words)))

    # 1. The host entity out of the board games' archive.
    with zipfile.ZipFile(HOST_ZIP) as z:
        raw = z.read('archive/pc/mod/0_open77_board_games.archive')
    (work / 'host').mkdir(parents=True)
    (work / 'host/board_games.archive').write_bytes(raw)
    cli('unbundle', work / 'host/board_games.archive', '-o', work / 'host/files', '-r', r'checkers_black_man\.ent$')
    (work / 'host-json').mkdir()
    cli('convert', 'serialize', work / 'host/files' / HOST_ENT, '-o', work / 'host-json')
    template = json.loads((work / 'host-json/checkers_black_man.ent.json').read_text(encoding='utf-8'))

    # 2. One entity per model, bound to the vanilla mesh.
    (work / 'json').mkdir()
    for index, (name, mesh) in enumerate(sorted(MODELS.items())):
        ident = str(8300000000000000000 + index)
        (work / 'json' / (name + '.ent.json')).write_text(json.dumps(retarget(template, mesh, ident), indent=1), encoding='utf-8')
    target = work / 'archive' / DEPOT.replace('\\', '/')
    target.mkdir(parents=True)
    cli('convert', 'deserialize', work / 'json', '-o', target)
    (work / 'packed').mkdir()
    cli('pack', work / 'archive', '-o', work / 'packed')
    packed = work / 'packed/archive.archive'
    assert packed.read_bytes()[:4] == b'RDAR', 'not an archive'

    # 3. Round trip: what the archive holds really points at the vanilla mesh.
    cli('unbundle', packed, '-o', work / 'verified')
    for name, mesh in MODELS.items():
        ent = work / 'verified' / DEPOT.replace('\\', '/') / (name + '.ent')
        cli('convert', 'serialize', ent, '-o', work / 'verified')
        back = json.loads((work / 'verified' / (name + '.ent.json')).read_text(encoding='utf-8'))
        paths = [c['mesh']['DepotPath']['$value'] for c in back['Data']['RootChunk']['components'] if c['$type'] == 'entMeshComponent']
        assert paths == [mesh], f'{name}: {paths}'

    # 4. The preload ZIP (fixed timestamp: same bytes for the same archive).
    output = RESOURCE / 'dist/open77_maneki.zip'
    output.parent.mkdir(parents=True, exist_ok=True)
    data = packed.read_bytes()
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        info = zipfile.ZipInfo('archive/pc/mod/' + ARCHIVE_NAME, (2026, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        z.writestr(info, data)
    manifest = {
        'version': '1.0.0', 'namespace': DEPOT,
        'models': [{'name': n, 'entity': DEPOT + '\\' + n + '.ent', 'mesh': m, 'vanilla': True,
                    'bounds': {'min': [-0.045, -0.065, -0.001], 'max': [0.047, 0.053, 0.161]}} for n, m in sorted(MODELS.items())],
        'host': 'open77_board_games ' + HOST_ENT,
        'archiveSha256': hashlib.sha256(data).hexdigest(),
        'zipSha256': hashlib.sha256(output.read_bytes()).hexdigest(),
    }
    (RESOURCE / 'asset-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print('COOKED', len(MODELS), 'entity host(s),', output.stat().st_size, 'ZIP bytes, archive sha256', manifest['archiveSha256'][:12])


if __name__ == '__main__':
    main()
