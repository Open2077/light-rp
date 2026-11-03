#!/usr/bin/env python3
"""Validate cooked board-game props, archive indexing and startup registration.

The default checks need only Python's standard library. Pass --build to also inspect
WolvenKit round-trip JSON and actual cooked CR2W files; this is offline validation,
not a claim that a client has mounted or rendered the models.
"""
import argparse
import base64
import hashlib
import importlib.util
import json
import math
from pathlib import Path, PurePosixPath
import re
import struct
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = ROOT / 'resources/assets/models/open77_board_games'
EXPECTED = {'chess_board', 'checkers_board', 'connect4_board'}
EXPECTED.update(f'chess_{side}_{kind}' for side in ('white', 'black') for kind in ('pawn', 'rook', 'knight', 'bishop', 'queen', 'king'))
EXPECTED.update(f'checkers_{side}_{kind}' for side in ('white', 'black') for kind in ('man', 'king'))
EXPECTED.update(f'connect4_{side}_disc' for side in ('white', 'black'))
COLLIDERS = {'chess_board_collider': 'chess_board', 'checkers_board_collider': 'checkers_board',
             'connect4_board_collider': 'connect4_board'}
WHITE_TEXTURE = 'engine\\textures\\editor\\white.xbm'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def art():
    return load('board_game_art', ROOT / 'tools/board-game-art.py')


def fnv(path):
    result = 14695981039346656037
    for byte in path.lower().replace('/', '\\').encode('utf-8'):
        result = ((result ^ byte) * 1099511628211) & 0xffffffffffffffff
    return result


def archive_entries(data):
    assert data[:4] == b'RDAR', 'package contains no REDengine archive'
    version, index_offset, index_size = struct.unpack_from('<IQQ', data, 4)
    assert version == 12 and 40 <= index_offset < len(data)
    assert index_offset + index_size <= len(data)
    files, segments, dependencies = struct.unpack_from('<III', data, index_offset + 16)
    assert index_size == 28 + files * 56 + segments * 16 + dependencies * 8
    entries = {}
    segment_offset = index_offset + 28 + files * 56
    for i in range(files):
        entry = index_offset + 28 + i * 56
        path_hash = struct.unpack_from('<Q', data, entry)[0]
        first, last, first_dep, last_dep = struct.unpack_from('<IIII', data, entry + 20)
        assert 0 <= first < last <= segments
        assert 0 <= first_dep <= last_dep <= dependencies
        assert path_hash not in entries, 'duplicate archive hash'
        chunks = []
        for j in range(first, last):
            offset, packed_size, raw_size = struct.unpack_from('<QII', data, segment_offset + j * 16)
            assert 40 <= offset < index_offset and packed_size > 0 and raw_size > 0
            assert offset + packed_size <= index_offset
            chunks.append((offset, packed_size, raw_size))
        entries[path_hash] = chunks
    return entries


def depot_paths(value):
    if isinstance(value, dict):
        if value.get('$type') == 'ResourcePath' and isinstance(value.get('$value'), str):
            yield value['$value']
        for item in value.values():
            yield from depot_paths(item)
    elif isinstance(value, list):
        for item in value:
            yield from depot_paths(item)


def check_build(build, models, table, manifest_namespace):
    for model in models:
        name = model['name']
        for extension, root_type in (('mesh', 'CMesh'), ('ent', 'entEntityTemplate')):
            path = model['mesh' if extension == 'mesh' else 'entity'].replace('\\', '/')
            cooked = build / 'archive' / path
            assert cooked.read_bytes()[:4] == b'CR2W', str(cooked)
            matches = list((build / 'verified').rglob(f'{name}.{extension}.json'))
            assert len(matches) == 1, (name, extension, matches)
            root = json.loads(matches[0].read_text(encoding='utf-8-sig'))['Data']['RootChunk']
            assert root['$type'] == root_type, (name, extension)
            if extension == 'ent':
                assert model['mesh'] in list(depot_paths(root)), f'{name}: template does not reference its mesh'
                continue
            assert root.get('objectType') == 'ROT_Static', f'{name}: mesh must use the static prop render category'
            assert not root.get('boneNames'), f'{name}: static game prop unexpectedly carries a vehicle rig'
            materials = root['localMaterialBuffer']['materials']
            assert len(materials) == len(model['materials']), f'{name}: material count differs from the manifest'
            for key, material in zip(model['materials'], materials):
                values={key:value for entry in material['values'] for key,value in entry.items() if key!='$type'}
                texture, _, rough, metal = table[key]
                assert material['baseMaterial']['DepotPath']['$value'] == 'engine\\materials\\metal_base.remt'
                assert math.isclose(values['RoughnessScale'], rough, abs_tol=1e-4) and math.isclose(values['MetalnessScale'], metal, abs_tol=1e-4), f'{name}: {key} surface values differ'
                path = values['BaseColor']['DepotPath']['$value']
                assert path == (manifest_namespace + '\\textures\\' + texture + '.xbm' if texture else WHITE_TEXTURE), f'{name}: {key} texture {path}'
            local_entries = [entry for entry in root['materialEntries'] if entry.get('isLocalInstance')]
            assert local_entries and all(0 <= entry['index'] < len(materials) for entry in local_entries), f'{name}: invalid local material index'
            names = {entry['name']['$value'] for entry in root['materialEntries']}
            for appearance in root['appearances']:
                assert all(item['$value'] in names for item in appearance['Data']['chunkMaterials']), f'{name}: appearance references absent material'
            blob = root['renderResourceBlob']['Data']
            chunks = blob['header']['renderChunkInfos']
            triangles = sum(chunk['numIndices'] for chunk in chunks) // 3
            assert triangles == model['triangles'] and triangles > 0, name
            pixels = base64.b64decode(blob['renderBuffer']['Bytes'])
            uv_values=[]
            for chunk in chunks:
                assert chunk['numIndices'] % 3 == 0 and chunk['numVertices'] > 0
                vertices = chunk['chunkVertices']
                layout = vertices['vertexLayout']
                uv = next(item for item in layout['elements']['Elements'] if item['usage']=='PS_TexCoord' and item['usageIndex']==0)
                assert uv['type']=='PT_Float16_2'
                stream=uv['streamIndex'];start=vertices['byteOffsets']['Elements'][stream];stride=layout['slotStrides']['Elements'][stream]
                for i in range(chunk['numVertices']):
                    pair=struct.unpack_from('<ee',pixels,start+i*stride)
                    assert all(math.isfinite(component) for component in pair)
                    uv_values.append(pair)
                colors = [item for item in layout['elements']['Elements'] if item['usage'] == 'PS_Color']
                assert colors, f'{name}: missing vertex color stream'
                for color in colors:
                    stream = color['streamIndex']
                    start = vertices['byteOffsets']['Elements'][stream]
                    stride = layout['slotStrides']['Elements'][stream]
                    assert all(pixels[start+i*stride:start+i*stride+4] == b'\xff'*4 for i in range(chunk['numVertices'])), f'{name}: black/transparent cooked vertex colors'
            assert len(set(uv_values))>1, f'{name}: texture UVs collapsed to a point'
            box = root['boundingBox']
            for axis in ('X', 'Y', 'Z'):
                low, high = box['Min'][axis], box['Max'][axis]
                assert math.isfinite(low) and math.isfinite(high) and low < high, (name, axis)


def decode_png(png):
    """Decode an 8-bit RGBA PNG (any filter) with the standard library."""
    assert png[:8] == b'\x89PNG\r\n\x1a\n'
    cursor, compressed, header = 8, [], None
    while cursor < len(png):
        length = struct.unpack_from('>I', png, cursor)[0]
        kind, chunk = png[cursor + 4:cursor + 8], png[cursor + 8:cursor + 8 + length]
        if kind == b'IHDR':
            header = struct.unpack('>IIBBBBB', chunk)
        elif kind == b'IDAT':
            compressed.append(chunk)
        cursor += length + 12
    width, height, depth, colour, _, _, interlace = header
    assert depth == 8 and colour == 6 and interlace == 0, 'expected 8-bit RGBA PNG'
    scan = zlib.decompress(b''.join(compressed))
    stride = width * 4
    rows, previous = [], bytearray(stride)
    for y in range(height):
        kind = scan[y * (stride + 1)]
        row = bytearray(scan[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            left = row[i - 4] if i >= 4 else 0
            up = previous[i]
            corner = previous[i - 4] if i >= 4 else 0
            if kind == 1:
                row[i] = (row[i] + left) & 255
            elif kind == 2:
                row[i] = (row[i] + up) & 255
            elif kind == 3:
                row[i] = (row[i] + (left + up) // 2) & 255
            elif kind == 4:
                p = left + up - corner
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - corner)
                row[i] = (row[i] + (left if pa <= pb and pa <= pc else up if pb <= pc else corner)) & 255
            else:
                assert kind == 0, kind
        rows.append(bytes(row))
        previous = row
    return width, height, rows


def check_textures(build, textures):
    sizes = art().TEXTURE_SIZES
    assert {texture['name'] for texture in textures} == set(sizes)
    for texture in textures:
        path=texture['depot'].replace(chr(92),'/')
        cooked=build/'archive'/path
        assert cooked.read_bytes()[:4]==b'CR2W'
        matches=list((build/'verified').rglob(texture['name']+'.xbm.json'))
        assert len(matches)==1
        root=json.loads(matches[0].read_text(encoding='utf-8-sig'))['Data']['RootChunk']
        assert root['$type']=='CBitmapTexture'
        width, height = sizes[texture['name']]
        assert (root['width'],root['height'])==(texture['width'],texture['height'])==(width, height)
        setup=root['setup']
        assert setup['compression']=='TCM_None' and setup['rawFormat']=='TRF_TrueColor' and setup['isGamma']==1
        blob=root['renderTextureResource']['renderResourceBlobPC']['Data'];header=blob['header']
        data=base64.b64decode(blob['textureData']['Bytes'])
        assert len(data)==texture['bytes']==header['textureInfo']['textureDataSize']
        assert len(header['mipMapInfo'])==texture['mips']==header['textureInfo']['mipCount']==max(width, height).bit_length()
        assert all(alpha==255 for alpha in data[3::4]), texture['name']
        offset=0;w,h=width,height
        for mip in header['mipMapInfo']:
            assert mip['placement']['offset']==offset
            assert mip['placement']['size']==mip['layout']['slicePitch']==w*h*4
            assert mip['layout']['rowPitch']==w*4
            offset+=w*h*4;w,h=max(1,w//2),max(1,h//2)
        assert offset==len(data)
        check_texture_source(texture, data)


def check_texture_source(texture, data):
    """The shipped top mip is the upright source PNG flipped vertically (FLIP_V)."""
    source=RESOURCE/'sources'/(texture['name']+'.png')
    png=source.read_bytes();assert hashlib.sha256(png).hexdigest()==texture['sourceSha256']
    width, height, rows = decode_png(png)
    assert texture.get('flipV') is True, f"{texture['name']}: textures must be cooked flipped (FLIP_V)"
    top = b''.join(reversed(rows))
    assert data[:len(top)] == top, f"{texture['name']}: cooked top mip is not the flipped source"
    assert len(set(top[0::4]))>1, f"{texture['name']}: flat texture"


def piece_heights(manifest):
    """The client's crosshair picking boxes follow the cooked piece heights."""
    client = (ROOT/'resources/gamemodes/op77_lightrp/client/core/board_games.lua').read_text()
    line = re.search(r'local PIECE_HEIGHTS=\{([^}]*)\}', client)
    assert line, 'client PIECE_HEIGHTS missing'
    heights = {k: float(v) for k, v in re.findall(r'(\w+)=([0-9.]+)', line.group(1))}
    assert heights == manifest['pieceHeights'], (heights, manifest['pieceHeights'])
    tops = {model['name']: model['bounds']['max'][2] for model in manifest['models']}
    for kind, height in heights.items():
        for side in ('white', 'black'):
            assert abs(tops[f'chess_{side}_{kind}'] - height) < .0015, (kind, side, tops[f'chess_{side}_{kind}'])
    king, man = re.search(r'piece\.kind=="king" and ([0-9.]+) or ([0-9.]+)', client).groups()
    for side in ('white', 'black'):
        assert abs(tops[f'checkers_{side}_king'] - float(king)) < .0015 and abs(tops[f'checkers_{side}_man'] - float(man)) < .0015


def verify(build=None):
    """Check the committed package; with `build`, also the cooked files and
    the WolvenKit round trip of that build directory."""
    manifest = json.loads((RESOURCE / 'asset-manifest.json').read_text())
    models = manifest['models']
    assert len(models) == len(EXPECTED) and {item['name'] for item in models} == EXPECTED
    package = RESOURCE / 'dist/open77_board_games.zip'
    with zipfile.ZipFile(package) as z:
        assert z.testzip() is None
        members = z.namelist()
        assert len(members) == len(set(members))
        assert all(not PurePosixPath(name).is_absolute() and '..' not in PurePosixPath(name).parts for name in members)
        assert not any(name.lower().endswith(('.dll', '.exe', '.reds', '.lua')) for name in members), 'asset package unexpectedly includes executable code'
        archives = [name for name in members if name.endswith('.archive')]
        assert archives == ['archive/pc/mod/0_open77_board_games.archive']
        data = z.read(archives[0])
        entries = archive_entries(data)
    assert hashlib.sha256(data).hexdigest() == manifest['archiveSha256']
    assert hashlib.sha256(package.read_bytes()).hexdigest() == manifest['zipSha256']
    paths = [model[key] for model in models for key in ('mesh', 'entity')]
    assert len(paths) == len(set(paths)) == 42
    textures=manifest['textures']
    pack_art = art()
    assert {texture['name'] for texture in textures}==set(pack_art.TEXTURE_SIZES)
    assert all(texture['flipV'] is True for texture in textures)
    colliders = manifest['colliders']
    assert {row['name']: row['for'] for row in colliders} == COLLIDERS
    for row in colliders:
        assert row['entity'] == manifest['namespace'] + chr(92) + row['name'] + '.ent' and row['boxes']
        assert row['scaleBaked'] == .65
    all_paths=paths+[texture['depot'] for texture in textures]+[row['entity'] for row in colliders]
    assert len(all_paths)==len(set(all_paths))==42+len(pack_art.TEXTURE_SIZES)+len(COLLIDERS)
    assert {fnv(path) for path in all_paths} == set(entries), 'archive contents differ from model, texture and collider set'
    table = pack_art.MATERIALS
    for model in models:
        assert all(key in table for key in model['materials']), model['name']
    piece_heights(manifest)
    # The committed geometry is what the art module generates today.
    generated = pack_art.models()
    for model in models:
        faces = generated[model['name']]
        assert len(faces) == model['triangles'], (model['name'], len(faces), model['triangles'])
        lo, hi = pack_art.bounds(faces)
        assert all(abs(a - b) < 1e-9 for a, b in zip(lo + hi, model['bounds']['min'] + model['bounds']['max'])), model['name']
    for model in models:
        assert model['triangles'] > 0
        for key, extension in (('mesh', '.mesh'), ('entity', '.ent')):
            path = model[key]
            assert path.startswith('open77\\assets\\op77_lightrp\\board_games\\') and path.endswith(extension)
            assert path.split('\\')[-1] == model['name'] + extension
    resource_manifest = (RESOURCE / 'open77.lua').read_text()
    assert re.search(r'resource\s+["\']open77_board_games["\']', resource_manifest)
    assert re.search(r'preload_mod\s+["\']dist/open77_board_games.zip["\']', resource_manifest)
    gamemode = (ROOT/'resources/gamemodes/op77_lightrp/open77.lua').read_text()
    single = re.findall(r'dependency\s+["\']([^"\']+)["\']', gamemode)
    blocks = re.findall(r'dependencies\s*\{([^}]+)\}', gamemode, re.S)
    multiple = [name for block in blocks for name in re.findall(r'["\']([^"\']+)["\']', block)]
    assert any(value.split()[0] == 'open77_board_games' for value in single + multiple), 'gamemode must depend on mounted model resource'
    client = (ROOT/'resources/gamemodes/op77_lightrp/client/core/board_games.lua').read_text()
    depot_literal = re.search(r'local\s+DEPOT\s*=\s*("(?:\\.|[^"\\])*")', client)
    assert depot_literal, 'client model depot prefix missing'
    depot = json.loads(depot_literal.group(1))
    assert depot == manifest['namespace'] + chr(92), 'client depot path and archive namespace differ'
    assert all(model['entity'] == depot + model['name'] + '.ent' for model in models)
    assert 'DEPOT..name..".ent"' in client and 'kind="prop"' in client, 'client must instantiate cooked entity hosts (bare names resolve to DEPOT; casino adapters pass full .ent paths)'
    for filename in ('server.jsonc', 'server.local.jsonc'):
        assert 'open77_board_games' in (ROOT/filename).read_text(), f'{filename}: asset resource not selected'
    assert {item['depot'] for item in manifest['files']} == set(all_paths)
    for texture in textures:
        sources = RESOURCE/'sources'/(texture['name']+'.png')
        assert hashlib.sha256(sources.read_bytes()).hexdigest() == texture['sourceSha256'], texture['name']
    if build:
        build = Path(build)
        for item in manifest['files']:
            cooked = (build/'archive'/item['depot'].replace('\\', '/')).read_bytes()
            assert len(cooked) == item['bytes'] and hashlib.sha256(cooked).hexdigest() == item['sha256'], item['depot']
        check_build(build, models, table, manifest['namespace'])
        check_textures(build,textures)
        col = load('collision_props', ROOT/'tools/collision_props.py')
        for row in colliders:
            boxes = [col.Box(b['size'], b['center']) for b in row['boxes']]
            matches = list((build/'verified').rglob(row['name']+'.ent.json'))
            assert len(matches) == 1, row['name']
            assert col.check_collider_entity(matches[0], boxes) == len(boxes)
            assert (build/'archive'/row['entity'].replace(chr(92), '/')).read_bytes()[:4] == b'CR2W'
    print(f'Board-game props: {len(models)} meshes/templates + {len(textures)} textures + {len(colliders)} colliders, '
          f'RDAR index, preload, piece heights and resource dependencies verified'
          f'{" (with WolvenKit round trip)" if build else ""}; archive SHA256 {hashlib.sha256(data).hexdigest()}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, help='WolvenKit build directory with archive/ and verified/')
    args = parser.parse_args()
    verify(args.build)


if __name__ == '__main__':
    main()
