#!/usr/bin/env python3
"""Validate cooked board-game props, archive indexing and startup registration.

The default checks need only Python's standard library. Pass --build to also inspect
WolvenKit round-trip JSON and actual cooked CR2W files; this is offline validation,
not a claim that a client has mounted or rendered the models.
"""
import argparse
import base64
import hashlib
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


def check_build(build, models):
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
            for material in materials:
                values={key:value for entry in material['values'] for key,value in entry.items() if key!='$type'}
                assert values['MetalnessScale']==0 and values['RoughnessScale']>=.6, f'{name}: wood must use a matte nonmetallic material'
                assert values['BaseColor']['DepotPath']['$value'].endswith(('.xbm',))
                assert '\\textures\\wood_' in values['BaseColor']['DepotPath']['$value'], f'{name}: missing authored wood texture'
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
            assert len(set(uv_values))>1, f'{name}: wood texture UVs collapsed to a point'
            box = root['boundingBox']
            for axis in ('X', 'Y', 'Z'):
                low, high = box['Min'][axis], box['Max'][axis]
                assert math.isfinite(low) and math.isfinite(high) and low < high, (name, axis)


def check_textures(build, textures):
    for texture in textures:
        path=texture['depot'].replace(chr(92),'/')
        cooked=build/'archive'/path
        assert cooked.read_bytes()[:4]==b'CR2W'
        matches=list((build/'verified').rglob(texture['name']+'.xbm.json'))
        assert len(matches)==1
        root=json.loads(matches[0].read_text(encoding='utf-8-sig'))['Data']['RootChunk']
        assert root['$type']=='CBitmapTexture'
        assert (root['width'],root['height'])==(texture['width'],texture['height'])==(256,256)
        setup=root['setup']
        assert setup['compression']=='TCM_None' and setup['rawFormat']=='TRF_TrueColor' and setup['isGamma']==1
        blob=root['renderTextureResource']['renderResourceBlobPC']['Data'];header=blob['header']
        data=base64.b64decode(blob['textureData']['Bytes'])
        assert len(data)==texture['bytes']==header['textureInfo']['textureDataSize']
        assert len(header['mipMapInfo'])==texture['mips']==header['textureInfo']['mipCount']==9
        assert all(alpha==255 for alpha in data[3::4]), texture['name']
        offset=0;size=256
        for mip in header['mipMapInfo']:
            assert mip['placement']['offset']==offset
            assert mip['placement']['size']==mip['layout']['slicePitch']==size*size*4
            assert mip['layout']['rowPitch']==size*4
            offset+=size*size*4;size=max(1,size//2)
        assert offset==len(data)
        source=RESOURCE/'sources'/(texture['name']+'.png')
        png=source.read_bytes();assert hashlib.sha256(png).hexdigest()==texture['sourceSha256']
        assert png[:8]==b'\x89PNG\r\n\x1a\n'
        # Generated source PNGs use the None filter; compare top mip bytes to
        # source pixels without an image-library dependency.
        compressed=[];cursor=8
        while cursor<len(png):
            length=struct.unpack_from('>I',png,cursor)[0];kind=png[cursor+4:cursor+8];chunk=png[cursor+8:cursor+8+length]
            if kind==b'IDAT': compressed.append(chunk)
            cursor+=length+12
        scan=zlib.decompress(b''.join(compressed));pitch=256*4+1
        assert len(scan)==pitch*256 and all(scan[y*pitch]==0 for y in range(256))
        top=b''.join(scan[y*pitch+1:(y+1)*pitch] for y in range(256))
        assert data[:len(top)]==top
        assert len(set(top[0::4]))>1, f"{texture['name']}: source wood grain is flat"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, help='WolvenKit build directory with archive/ and verified/')
    args = parser.parse_args()
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
    assert {texture['name'] for texture in textures}=={'wood_ivory','wood_ebony','wood_natural','wood_grain'}
    all_paths=paths+[texture['depot'] for texture in textures]
    assert len(all_paths)==len(set(all_paths))==46
    assert {fnv(path) for path in all_paths} == set(entries), 'archive contents differ from model and texture set'
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
    if args.build:
        for item in manifest['files']:
            cooked = (args.build/'archive'/item['depot'].replace('\\', '/')).read_bytes()
            assert len(cooked) == item['bytes'] and hashlib.sha256(cooked).hexdigest() == item['sha256'], item['depot']
        check_build(args.build, models)
        check_textures(args.build,textures)
    print(f'Board-game props: {len(models)} meshes/templates + {len(textures)} wood textures, RDAR index, preload and resource dependencies verified; archive SHA256 {hashlib.sha256(data).hexdigest()}')


if __name__ == '__main__':
    main()
