#!/usr/bin/env python3
"""Table colliders: the helper's CR2W structures, the cooked packs, and the client.

  python3 tools/test-table-colliders.py                 offline (stdlib + lupa)
  python3 tools/test-table-colliders.py --build WORK    also checks WORK/verified, the
      WolvenKit round trip a pack build leaves (e.g. ~/.cache/<you>/build-slots)

Offline validation only: whether the collider stops a player is the in-game check
of tools/COLLISION.md.
"""
import argparse
import copy
import importlib.util
import json
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / 'resources/assets/models'
CLIENT = ROOT / 'resources/gamemodes/op77_lightrp/client/core/board_games.lua'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


col = load('collision_props', ROOT / 'tools/collision_props.py')
archive_checks = load('archive_checks', ROOT / 'tools/test-board-game-props.py')


def raises(fn, *args):
    try:
        fn(*args)
    except (AssertionError, ValueError):
        return True
    return False


def helper():
    box = col.Box.between((-.49, -.40, 0), (.49, .40, 2.52))
    assert box.size == (.98, .8, 2.52) and box.center == (0., 0., 1.26)
    half, position = col.baked(box)
    assert half == [.3185, .26, .819] and position == [0, 0, .819], 'the 0.65 client scale is baked in'
    assert col.baked(box, 1)[0] == [.49, .4, 1.26]
    assert raises(col.Box, (0, 1, 1)) and raises(col.Box, (1, 1)) and raises(col.Box, (1, 1, float('nan')))
    assert raises(col.collider_box, box, col.SCALE, 'not_a.physmat') and raises(col.collider_component, [], 1)
    # The entity: one static World Static collider, identical in the editor list
    # and the compiled buffer the game spawns from, and nothing else (no mesh).
    template = {'Header': {}, 'Data': {'RootChunk': {'$type': 'entEntityTemplate', 'components': ['old'],
                'compiledData': {'Data': {'Chunks': ['old'], 'CruidDict': {}}}}}}
    boxes = [box, col.Box((.92, .14, .07), (0, -.43, 1.035))]
    entity = col.collider_entity_json(template, boxes, 3)
    assert template['Data']['RootChunk']['components'] == ['old'], 'the template is not modified'
    assert col.check_collider_entity(entity, boxes) == 2
    root = entity['Data']['RootChunk']
    component = root['components'][0]
    assert component['id'] == str(col.COLLIDER_ID_BASE + 3) == root['compiledData']['Data']['CruidDict']['1']
    assert component['filterData']['Data']['preset']['$value'] == 'World Static'
    ids = re.findall(r'"HandleId": "(\d+)"', json.dumps(entity))
    assert len(ids) == len(set(ids)), 'handle ids must be unique in the file'
    wrong = copy.deepcopy(entity)
    wrong['Data']['RootChunk']['compiledData']['Data']['Chunks'][1]['colliders'][0]['Data']['halfExtents']['X'] = .49
    assert raises(col.check_collider_entity, wrong, boxes), 'an unscaled box is refused'
    wrong = copy.deepcopy(entity)
    wrong['Data']['RootChunk']['components'][0]['simulationType'] = 'Dynamic'
    assert raises(col.check_collider_entity, wrong, boxes), 'a simulated collider is refused'
    assert raises(col.check_collider_entity, entity, boxes[:1])
    # The alternative route: the same boxes as mesh physics (game mesh layout).
    mesh = {'Data': {'RootChunk': {'$type': 'CMesh', 'parameters': [col.mesh_physics_param(boxes)]}}}
    assert col.check_mesh_physics(mesh, boxes) == 2
    print('collision_props: boxes, baked scale, entity and mesh-physics structures: OK')


def packs():
    """Every collider a pack manifest declares is cooked into its archive, and the
    client creates exactly the colliders that exist."""
    declared = {}
    for manifest_path in sorted(MODELS.glob('*/asset-manifest.json')):
        manifest = json.loads(manifest_path.read_text())
        colliders = manifest.get('colliders', [])
        if not colliders:
            continue
        names = {m['name'] for m in manifest['models']}
        files = {f['depot'] for f in manifest['files']}
        zips = list((manifest_path.parent / 'dist').glob('*.zip'))
        assert len(zips) == 1, zips
        with zipfile.ZipFile(zips[0]) as z:
            entries = archive_checks.archive_entries(z.read(z.namelist()[0]))
        for row in colliders:
            assert row['for'] in names and row['name'] == col.collider_name(row['for']), row
            assert row['entity'] == manifest['namespace'] + '\\' + row['name'] + '.ent' and row['entity'] in files
            assert archive_checks.fnv(row['entity']) in entries, f"{row['entity']} is not in {zips[0].name}"
            assert row['scaleBaked'] == col.SCALE and row['boxes'], row
            for b in row['boxes']:
                col.Box(b['size'], b['center'])
            declared[row['for']] = (manifest_path.parent.name, row)
    listed = set(re.findall(r'(\w+)=true', re.search(r'local TABLE_COLLIDERS=\{([^}]*)\}', CLIENT.read_text()).group(1)))
    assert listed == set(declared), f'client TABLE_COLLIDERS {sorted(listed)} != cooked colliders {sorted(declared)}'
    assert 'slot_cabinet' in declared, 'the slot machine is the proven pack'
    print('packs: ' + ', '.join(f'{pack}/{row["name"]} ({len(row["boxes"])} box)' for pack, row in declared.values())
          + ' cooked, indexed and wired in the client: OK')
    return declared


def cooked(work, declared):
    verified = Path(work) / 'verified'
    for pack, row in declared.values():
        found = list(verified.rglob(row['name'] + '.ent.json'))
        assert len(found) == 1, (row['name'], found)
        boxes = [col.Box(b['size'], b['center']) for b in row['boxes']]
        col.check_collider_entity(found[0], boxes, row['scaleBaked'])
        print(f'round trip {found[0]}: OK')


def client():
    source = (ROOT / 'tools/test-board-games-client.py').read_text()
    namespace = {'__file__': str(ROOT / 'tools/test-board-games-client.py')}
    exec(source.split("for name in ['shared/board_game_models.lua'")[0], namespace)
    lua = namespace['lua']
    assets = json.loads((MODELS / 'open77_casino_slots/asset-manifest.json').read_text())
    lua.globals().availableModels = lua.table_from({m['name']: True for m in assets['models'] + assets['colliders']})
    lua.execute(r'''
LightRpBoardGames={};LightRpItems={}
colliderCreates,failCollider={},false
function Open77.props.create(options)
 nativeCreatesInResume=(nativeCreatesInResume or 0)+1
 assert(options.model:sub(-4)=='.ent' and options.kind=='prop')
 local name=options.model:match('([^\\]+)%.ent$')
 local collider=name:match('_collider$')~=nil
 if collider then
  colliderCreates[#colliderCreates+1]=options
  assert(options.collision==true and options.physics=='static' and options.scale==1 and options.visible==true)
  if failCollider then return nil,'invalid_model' end
 else
  assert(options.collision==false and options.physics=='none' and options.scale==.65,'visual props stay non-solid: '..name)
 end
 assert(availableModels[name] or name:match('^chess_'),'native asset missing from the cooked package: '..tostring(name))
 nextNativeId=nextNativeId+1;local id=tostring(nextNativeId)
 nativeProps[id]={id=id,name=name,model=options.model,position={x=options.position.x,y=options.position.y,z=options.position.z},
  yaw=options.yaw,rendered=not collider,failed=false,backend='raw_entity'}
 createdProps=createdProps+1;return id
end
function findProp(name) for id,p in pairs(nativeProps) do if p.name==name then return p,id end end end
function countName(name) local n=0;for _,p in pairs(nativeProps) do if p.name==name then n=n+1 end end;return n end
''')
    for name in ['shared/board_game_models.lua', 'shared/board_games_rules.lua', 'shared/tabletop_extra_rules.lua',
                 'shared/casino_slots.lua', 'client/core/tabletop_extra.lua', 'client/core/casino_slots.lua',
                 'client/core/board_games.lua']:
        lua.execute((ROOT / 'resources/gamemodes/op77_lightrp' / name).read_text(), name=name)
    lua.execute(r'''
local S,C=LightRpCasinoSlots,LightRpBoardGamesClient
C.bind(page);C.start();step();step()
-- The placement ghost is the visual entity only: never solid.
events['lightrp:boardGames:place']({kind='slots'});step();step()
assert(C.isActive() and findProp('slot_cabinet') and #colliderCreates==0,'the placement ghost has no collider')
edge('BACKSPACE');assert(not C.isActive() and next(nativeProps)==nil)
-- A placed machine: base + one collider at the base transform, at scale 1.
local now=1700000000000
local machine={id=201,kind='slots',owned=true,position={x=1,y=2,z=3},rotation=90,
 players={},ready=true,mode='duel',revision=1,serverNow=now,game=S.new('duel')}
events['lightrp:boardGames:state']({boards={machine}})
waitUntil(function() return findProp('slot_cabinet') and findProp('slot_cabinet_collider') and countName('slot_coin')==4 end,'machine with collider')
assert(#colliderCreates==1 and countName('slot_cabinet_collider')==1)
local o=colliderCreates[1]
assert(o.model=='open77\\assets\\op77_lightrp\\casino_slots\\slot_cabinet_collider.ent')
assert(o.position.x==1 and o.position.y==2 and o.position.z==3 and o.yaw==90)
-- A collider never renders (no mesh): that must not fail the table.
for i=1,400 do step() end
assert(findProp('slot_cabinet') and countName('slot_cabinet_collider')==1 and #colliderCreates==1,'an unrendered collider is not a failure')
for _,d in ipairs(diagnostics) do assert(d.event~='render','no render failure: '..tostring(d.reason)) end
-- ALT-click on the collider picks the machine up like a click on the cabinet.
local _,baseId=findProp('slot_cabinet');local _,colliderId=findProp('slot_cabinet_collider')
invokingResource='open77_contextmenu';Open77.character.state().position={x=1,y=2,z=3.5}
assert(exportCallbacks.boardGamesCanPickup({target={kind='prop',propId=baseId,networked=false}})==true)
assert(exportCallbacks.boardGamesCanPickup({target={kind='prop',propId=colliderId,networked=false}})==true)
machine.owned=false;events['lightrp:boardGames:state']({boards={machine}});step()
assert(exportCallbacks.boardGamesCanPickup({target={kind='prop',propId=colliderId,networked=false}})==false,'only the owner')
machine.owned=true;invokingResource=nil
-- A moved table moves its collider.
machine.position={x=4,y=2,z=3};machine.rotation=180;machine.revision=2
events['lightrp:boardGames:state']({boards={machine}})
waitUntil(function() local p=findProp('slot_cabinet_collider');return p.position.x==4 and p.yaw==180 end,'collider follows the table')
-- Removal takes the collider with the table.
events['lightrp:boardGames:state']({boards={}});for i=1,10 do step() end
assert(not findProp('slot_cabinet') and not findProp('slot_cabinet_collider'))
-- A missing collider asset (an older pack) leaves the table walk-through, nothing else.
failCollider=true;colliderCreates={}
machine.id=202;machine.revision=3;events['lightrp:boardGames:state']({boards={machine}})
waitUntil(function() return findProp('slot_cabinet') and countName('slot_coin')==4 end,'machine without collider')
for i=1,20 do step() end
assert(#colliderCreates==1 and not findProp('slot_cabinet_collider') and findProp('slot_cabinet'),'one attempt, table kept')
failCollider=false
events['lightrp:boardGames:state']({boards={}});for i=1,10 do step() end
-- Every table kind now ships a collider: a chess board creates exactly its own.
local chess={id=301,kind='chess',owned=true,position={x=0,y=0,z=0},rotation=0,players={},ready=true,revision=1,
 game=LightRPBoardRules.new('chess')}
colliderCreates={}
events['lightrp:boardGames:state']({boards={chess}})
waitUntil(function() return findProp('chess_board') end,'chess board')
for i=1,40 do step() end
assert(#colliderCreates==1 and colliderCreates[1].model:find('chess_board_collider.ent',1,true),'the chess board gets its own collider')
handlers.onClientResourceStop('test');for i=1,20 do step() end
assert(next(nativeProps)==nil)
print('client: ghost and pieces non-solid, placed table collider (static, collision, scale 1) follows, picks up, cleans up, tolerates a missing asset: OK; peak '..peakInstructions..' (budget '..BOARD_BUDGET..')')
''')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', help='a pack build work folder to check the WolvenKit round trip of')
    args = parser.parse_args()
    helper()
    declared = packs()
    if args.build:
        cooked(args.build, declared)
    client()


if __name__ == '__main__':
    main()
