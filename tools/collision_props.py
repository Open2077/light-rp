#!/usr/bin/env python3
"""Box colliders for the cooked LightRP table props (WolvenKit 9.1 CR2W JSON).

A table base is rendered from `<base>.ent` (one entMeshComponent). This module
writes a second, mesh-less entity `<base>_collider.ent` holding one
entColliderComponent made of static boxes. The client creates it as its own prop
(collision=true, physics="static", scale 1) once a table is placed, so:

- the visual entity, the placement ghost and every piece stay non-solid;
- the collider never depends on how the client hides or scales a visual prop
  (Open77 does not rescale authored collision, so the 0.65 visual scale is baked
  into the box sizes here and the collider prop is created at scale 1).

Every structure below is copied from files WolvenKit 9.1 serialized itself:
the entColliderComponent of the inspected Oni vehicle entity (lab donor) and the
"World Static" physicsFilterData of the game's Arasaka lobby wall mesh found in
resources/assets/maps/casino. See tools/COLLISION.md for the recipe.

Usage from a pack build script (boxes in table-local metres, before scale):

    import collision_props as col
    BOXES = [col.Box(size=(.98, .80, 2.52), center=(0, 0, 1.26))]
    (schemas / (name + '_collider.ent.json')).write_text(
        json.dumps(col.collider_entity_json(template, BOXES, index)))
    ...after `convert serialize` of the cooked archive:
    col.check_collider_entity(verified / ... / (name + '_collider.ent.json'), BOXES)
"""
import copy
import json
import math
from collections import namedtuple
from pathlib import Path

# Client visual scale of every table pack (client/core/board_games.lua SCALE).
SCALE = .65
# Suffix of the collider entity beside its base: chess_board -> chess_board_collider.
SUFFIX = '_collider'
# Game physics preset for immovable world geometry, with the masks the game
# cooks for it (int_arasaka_tower_lobby_a_wall_a_l600.mesh, WolvenKit 9.1).
PRESET = 'World Static'
QUERY_MASKS = ('0', '143769604')
SIMULATION_MASKS = ('376836', '5070')
# Physics materials seen in cooked game meshes (footsteps/impacts sound).
MATERIALS = {'concrete.physmat', 'metal.physmat', 'stone.physmat', 'tiles.physmat', 'ceramic.physmat',
             'furniture_leather.physmat', 'furniture_upholstery.physmat'}
COLLIDER_ID_BASE = 8300000000000000000


class Box(namedtuple('Box', 'size center')):
    """An axis-aligned box in table-local metres BEFORE the client scale.

    size = (width X, depth Y, height Z), center = (x, y, z) of its middle, in the
    same frame as the base mesh (Z up, origin = the prop's position).
    """
    def __new__(cls, size, center=(0., 0., 0.)):
        size = tuple(float(v) for v in size)
        center = tuple(float(v) for v in center)
        if len(size) != 3 or len(center) != 3:
            raise ValueError('a box needs three sizes and a three-axis center')
        if not all(math.isfinite(v) and v > 0 for v in size) or not all(math.isfinite(v) for v in center):
            raise ValueError(f'invalid collider box {size} at {center}')
        return super().__new__(cls, size, center)

    @classmethod
    def between(cls, lo, hi):
        """The box spanning two opposite corners (e.g. a part's min/max bounds)."""
        return cls([h - l for l, h in zip(lo, hi)], [(l + h) / 2 for l, h in zip(lo, hi)])


def collider_name(name):
    return name + SUFFIX


def _cn(value):
    return {'$type': 'CName', '$storage': 'string', '$value': value}


def _vector3(values):
    return {'$type': 'Vector3', 'X': values[0], 'Y': values[1], 'Z': values[2]}


def _transform(position=(0., 0., 0.)):
    return {'$type': 'Transform',
            'orientation': {'$type': 'Quaternion', 'i': 0, 'j': 0, 'k': 0, 'r': 1},
            'position': {'$type': 'Vector4', 'W': 0, 'X': position[0], 'Y': position[1], 'Z': position[2]}}


def baked(box, scale=SCALE):
    """(halfExtents, position) in metres as cooked: scale is baked in."""
    return ([round(v * scale / 2, 6) for v in box.size], [round(v * scale, 6) for v in box.center])


def filter_data():
    return {'$type': 'physicsFilterData', 'customFilterData': None, 'preset': _cn(PRESET),
            'queryFilter': {'$type': 'physicsQueryFilter', 'mask1': QUERY_MASKS[0], 'mask2': QUERY_MASKS[1]},
            'simulationFilter': {'$type': 'physicsSimulationFilter', 'mask1': SIMULATION_MASKS[0], 'mask2': SIMULATION_MASKS[1]}}


def collider_box(box, scale=SCALE, material='metal.physmat'):
    """physicsColliderBox data (the payload of a handle)."""
    if material not in MATERIALS:
        raise ValueError(f'unknown physics material {material}')
    half, position = baked(box, scale)
    return {'$type': 'physicsColliderBox', 'filterData': None,
            'halfExtents': _vector3(half), 'isImported': 0, 'isObstacle': 0, 'isQueryShapeOnly': 0,
            'localToBody': _transform(position), 'material': _cn(material), 'materialApperanceOverrides': [],
            'tag': _cn('None'), 'volumeModifier': 1}


def collider_component(boxes, ident, scale=SCALE, material='metal.physmat', handles=100):
    """entColliderComponent: static, World Static, no simulation (mass is unused)."""
    if not boxes:
        raise ValueError('a collider needs at least one box')
    colliders = [{'HandleId': str(handles + i), 'Data': collider_box(b, scale, material)} for i, b in enumerate(boxes)]
    return {'$type': 'entColliderComponent', 'colliders': colliders, 'comOffset': _transform(),
            'dynamicTrafficSetting': {'$type': 'TrafficGenDynamicTrafficSetting', 'impact': 'Ignored'},
            'filterData': {'HandleId': str(handles + len(boxes)), 'Data': filter_data()},
            'id': str(ident), 'inertia': _vector3((1, 1, 1)), 'isEnabled': 1, 'isReplicable': 0,
            'localTransform': {'$type': 'WorldTransform',
                               'Orientation': {'$type': 'Quaternion', 'i': 0, 'j': 0, 'k': 0, 'r': 1},
                               'Position': {'$type': 'WorldPosition', **{a: {'$type': 'FixedPoint', 'Bits': 0} for a in 'xyz'}}},
            'mass': 1, 'massOverride': -1, 'name': _cn('table_collider'), 'parentTransform': None,
            'simulationType': 'Static', 'startInactive': 0, 'useCCD': 0, 'volume': 0}


def collider_entity_json(template, boxes, index, scale=SCALE, material='metal.physmat'):
    """A mesh-less entity template holding only the collider.

    `template` is the serialized host entity the pack scripts already load
    (ball_01.ent.json); `index` makes the component id unique in the pack.
    The component is written in full in both the editor list and the compiled
    buffer (distinct handle ids); WolvenKit folds them into references.
    """
    obj = copy.deepcopy(template)
    r = obj['Data']['RootChunk']
    ident = COLLIDER_ID_BASE + index
    entity = {'$type': 'entEntity'}
    r['entity'] = {'HandleId': '1', 'Data': copy.deepcopy(entity)}
    r['components'] = [collider_component(boxes, ident, scale, material, handles=100)]
    r['compiledData']['Data']['Chunks'] = [copy.deepcopy(entity), collider_component(boxes, ident, scale, material, handles=200)]
    r['compiledData']['Data']['CruidDict'] = {'0': '0', '1': str(ident)}
    r['appearances'] = []
    r['defaultAppearance'] = _cn('default')
    r['resolvedDependencies'] = []
    r['includes'] = []
    r['inplaceResources'] = []
    return obj


def mesh_physics_param(boxes, scale=SCALE, material='metal.physmat', handles=900):
    """Alternative route, NOT used by the packs: collision inside the .mesh.

    The game's own static meshes carry their collision as a meshMeshParamPhysics
    entry of CMesh.parameters (this mirrors int_arasaka_tower_lobby_a_wall_a_l600);
    an entPhysicalMeshComponent, or a host that builds one from a raw .mesh,
    reads it. Append the result to `RootChunk['parameters']` of the mesh JSON.
    """
    shapes = []
    for i, b in enumerate(boxes):
        shape = collider_box(b, scale, material)
        shape['filterData'] = {'HandleId': str(handles + 10 + 2 * i), 'Data': filter_data()}
        shapes.append({'HandleId': str(handles + 11 + 2 * i), 'Data': shape})
    body = {'$type': 'physicsSystemBody', 'collisionShapes': shapes, 'isQueryBodyOnly': 0,
            'localToModel': _transform(), 'mappedBoneName': _cn('None'), 'mappedBoneToBody': _transform(),
            'name': _cn('Actor (ID: 3, Mass: 1.000, bone: None )'),
            'params': {'$type': 'physicsSystemBodyParams', 'angularDamping': 0, 'comOffset': _transform(),
                       'inertia': _vector3((1, 1, 1)), 'linearDamping': 0, 'mass': 1, 'maxAngularVelocity': -1,
                       'maxContactImpulse': -1, 'maxDepenetrationVelocity': -1, 'simulationType': 'Static',
                       'solverIterationsCountPosition': 4, 'solverIterationsCountVelocity': 1}}
    resource = {'$type': 'physicsSystemResource', 'bodies': [{'HandleId': str(handles + 2), 'Data': body}],
                'cookingPlatform': 'PLATFORM_None', 'joints': []}
    return {'HandleId': str(handles), 'Data': {'$type': 'meshMeshParamPhysics',
                                               'physicsData': {'HandleId': str(handles + 1), 'Data': resource}}}


def _handles(node, table):
    if isinstance(node, dict):
        if 'HandleId' in node and 'Data' in node:
            table[node['HandleId']] = node['Data']
        for value in node.values():
            _handles(value, table)
    elif isinstance(node, list):
        for value in node:
            _handles(value, table)
    return table


def _resolve(value, table):
    if isinstance(value, dict) and 'HandleRefId' in value:
        return table[value['HandleRefId']]
    if isinstance(value, dict) and 'Data' in value and 'HandleId' in value:
        return value['Data']
    return value


def _close(a, b, tolerance=1e-4):
    return abs(float(a) - float(b)) <= tolerance


def check_collider_entity(source, boxes, scale=SCALE):
    """Assert a round-tripped (`convert serialize`) collider entity matches `boxes`.

    `source` is a path to the .ent.json WolvenKit wrote back, or its parsed JSON.
    Checks both the compiled buffer the game spawns from and the editor list.
    Returns the number of boxes checked.
    """
    obj = json.loads(Path(source).read_text()) if not isinstance(source, dict) else source
    r = obj['Data']['RootChunk']
    assert r['$type'] == 'entEntityTemplate', r['$type']
    table = _handles(obj, {})
    chunks = r['compiledData']['Data']['Chunks']
    for label, components in (('compiled', [c for c in chunks if c.get('$type') != 'entEntity']),
                              ('components', r['components'])):
        assert len(components) == 1, (label, [c.get('$type') for c in components])
        component = components[0]
        assert component['$type'] == 'entColliderComponent', (label, component['$type'])
        assert component['simulationType'] == 'Static' and component['isEnabled'] == 1, label
        assert component['parentTransform'] is None, (label, 'a table collider is not bound to a slot')
        data = _resolve(component['filterData'], table)
        assert data['preset']['$value'] == PRESET, (label, data['preset'])
        assert (data['queryFilter']['mask1'], data['queryFilter']['mask2']) == QUERY_MASKS, label
        assert (data['simulationFilter']['mask1'], data['simulationFilter']['mask2']) == SIMULATION_MASKS, label
        shapes = [_resolve(c, table) for c in component['colliders']]
        assert len(shapes) == len(boxes), (label, len(shapes), len(boxes))
        for shape, box in zip(shapes, boxes):
            assert shape['$type'] == 'physicsColliderBox', shape['$type']
            half, position = baked(box, scale)
            got = shape['halfExtents']
            assert all(_close(got[a], h) for a, h in zip('XYZ', half)), (label, got, half)
            got = shape['localToBody']['position']
            assert all(_close(got[a], p) for a, p in zip('XYZ', position)), (label, got, position)
            assert shape['material']['$value'] in MATERIALS and not shape['isQueryShapeOnly']
    ident = r['compiledData']['Data']['CruidDict']['1']
    assert ident == r['components'][0]['id'], 'the component id must be in the compiled CRUID table'
    return len(boxes)


def check_mesh_physics(source, boxes, scale=SCALE):
    """Assert a round-tripped mesh carries `mesh_physics_param(boxes)`."""
    obj = json.loads(Path(source).read_text()) if not isinstance(source, dict) else source
    table = _handles(obj, {})
    params = [_resolve(p, table) for p in obj['Data']['RootChunk']['parameters']]
    physics = [p for p in params if p['$type'] == 'meshMeshParamPhysics']
    assert len(physics) == 1, [p['$type'] for p in params]
    resource = _resolve(physics[0]['physicsData'], table)
    bodies = [_resolve(b, table) for b in resource['bodies']]
    assert len(bodies) == 1 and bodies[0]['params']['simulationType'] == 'Static'
    shapes = [_resolve(s, table) for s in bodies[0]['collisionShapes']]
    assert len(shapes) == len(boxes)
    for shape, box in zip(shapes, boxes):
        half, position = baked(box, scale)
        assert all(_close(shape['halfExtents'][a], h) for a, h in zip('XYZ', half))
        assert all(_close(shape['localToBody']['position'][a], p) for a, p in zip('XYZ', position))
        assert _resolve(shape['filterData'], table)['preset']['$value'] == PRESET
    return len(boxes)


def footprint_report(name, boxes, scale=SCALE):
    """One line per box, in game metres, for build logs."""
    lines = []
    for box in boxes:
        half, position = baked(box, scale)
        lines.append(f'{collider_name(name)}: box {[round(2 * h, 3) for h in half]} m at {position} m (scale {scale} baked)')
    return lines
