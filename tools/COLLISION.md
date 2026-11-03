# Player collision for the cooked table props

Players walked through every placed table: every table prop is created by the
client with `collision=false`, and the cooked meshes carry no collision shapes.
Per the devkit (guide `props`, "Model and collision limits" / "Current
limitations"), collision comes from shapes authored in the asset. `collision=true`
does nothing without them, and `scale` does not rescale them.

## The route: a collider entity beside the base

Each table base `<base>.ent` (visual, one `entMeshComponent`) gets a second cooked
entity `<base>_collider.ent` with no mesh and one `entColliderComponent` made of
static boxes. The client creates it as a separate prop when a table is placed:

```lua
Open77.props.create{ model = "<depot>\\<base>_collider.ent", kind = "prop",
  position = board.position, yaw = board.rotation, scale = 1,
  physics = "static", collision = true, visible = true }
```

Why a separate entity instead of a collider inside the visual `.ent`:

- The placement ghost and every piece are visual props created with
  `collision=false`. We don't know whether `collision=false` turns off a collider
  authored inside a raw `.ent`. Keeping the collider in its own entity means those
  props can never be solid, so the ghost cannot shove the player.
- The 0.65 visual scale is baked into the boxes, and the collider prop is created
  at scale 1. The sizes stay right even if a later build starts scaling prop
  colliders (base branch `fix/prop-collision-scale`).
- Visual remodelling never touches the collider, and the collider never touches
  the visual pipeline.

Client (`client/core/board_games.lua`): `TABLE_COLLIDERS` lists the base names
whose pack ships a collider. A listed base gets one collider per placed table:

- It is created after the base. Each attempt is followed by a yield, so there is
  one native create per resume.
- It moves with the base and is removed with it.
- It is never render-validated: it has no mesh. If the asset is missing or fails,
  the table is walk-through, as before.
- ALT-click on the collider acts as a click on its base, so "Pick up board" still
  works.

`PROP_ESTIMATE` counts it.

## Inputs

`collision_props.Box(size, center)` is an axis-aligned box in **table-local metres
before the 0.65 scale**. These are the same numbers as the geometry in the build
script: Z up, origin = the prop position, +Y = the table's back.

- `size` = (X width, Y depth, Z height).
- `center` = the middle of the box.
- `Box.between(lo, hi)` builds one from two corners.

Keep it simple: one box per footprint, or a few. Leave out levers, overhangs and
anything a player must reach. Keep where the player stands to play outside the
boxes. The character capsule is about 0.3 m in radius, so a small overhang never
matters.

Proven pack: `slot_cabinet` = `Box.between((-.49,-.40,0),(.49,.40,2.52))`, which
cooks to 0.637 x 0.52 x 1.638 m in game.

## Adding a pack (recipe for the build scripts)

```python
spec=importlib.util.spec_from_file_location('collision_props',ROOT/'tools/collision_props.py')
col=importlib.util.module_from_spec(spec);spec.loader.exec_module(col)
COLLIDERS={'blackjack_table':[col.Box.between((x0,y0,0),(x1,y1,h))]}
# after the per-model loop (template = the serialized ball_01.ent host the script already loads):
for i,(name,boxes) in enumerate(COLLIDERS.items()):
  (schemas/(col.collider_name(name)+'.ent.json')).write_text(json.dumps(col.collider_entity_json(template,boxes,i)))
  colliders.append({'name':col.collider_name(name),'for':name,'entity':DEPOT+'\\'+col.collider_name(name)+'.ent',
                    'scaleBaked':col.SCALE,'boxes':[{'size':list(b.size),'center':list(b.center)} for b in boxes]})
# manifest: 'colliders':colliders ; verify step: +len(COLLIDERS) archive entries, then
col.check_collider_entity(next(verified.rglob(row['name']+'.ent.json')),COLLIDERS[row['for']])
```

Then:

1. Add the base name to `TABLE_COLLIDERS` in `client/core/board_games.lua`.
2. Add +1 to its `PROP_ESTIMATE`.
3. Update that pack's client test mock. A model ending in `_collider.ent` must
   have `collision==true`, `physics=='static'` and `scale==1`, and its manifest
   `colliders` count as available models.

`tools/test-table-colliders.py` refuses the build if:

- a manifest collider is missing from its archive index;
- a listed base has no cooked collider;
- a cooked collider is not listed in `TABLE_COLLIDERS`.

## CR2W structures (WolvenKit 9.1, copied from files it serialized)

- `entEntityTemplate`:
  - `components` and `compiledData.Chunks` (the buffer the game spawns from)
    both hold `[entEntity, entColliderComponent]`, written in full with distinct
    `HandleId`s. WolvenKit folds the duplicates into `HandleRefId`s on serialize.
  - `CruidDict = {'0':'0','1':'<component id>'}`.
  - Component ids are `8300000000000000000 + index`. Mesh components use
    `8200000000000000000 + index`.
- `entColliderComponent`. Its field set comes from the lab donor
  `v_methodd_oni_basic_01.ent`:
  - `simulationType: "Static"`, `parentTransform: null`, identity `localTransform`.
  - `mass 1`, `massOverride -1`, `useCCD 0`. These are unused for a static body.
  - `filterData` → `physicsFilterData`:
    - `preset "World Static"`
    - `queryFilter.mask2 143769604`
    - `simulationFilter.mask1 376836` / `mask2 5070`

    These are the game's own values, from
    `int_arasaka_tower_lobby_a_wall_a_l600.mesh` in `resources/assets/maps/casino`.
    The `worldCollisionNode`s of our maps use the same preset (CName hash
    11199900243055890879 = FNV1a64 of "World Static").
  - `colliders`: one handle per box → `physicsColliderBox`:
    - `halfExtents` = size x 0.65 / 2.
    - `localToBody.position` = center x 0.65, identity orientation.
    - `material "metal.physmat"`. Any name in `collision_props.MATERIALS`, all seen
      in cooked game meshes.
    - `isQueryShapeOnly 0`, `isObstacle 0`, `filterData null`.

The alternative is `collision_props.mesh_physics_param(boxes)`. It appends a
`meshMeshParamPhysics` (`physicsSystemResource` → one `physicsSystemBody`,
`simulationType Static` → `physicsColliderBox` shapes with the World Static
filter) to `CMesh.parameters`. This is how the game's static meshes carry
collision (Arasaka wall, `box_1_1_1_snappoints.mesh`), and probably what the
devkit's 116 solid catalogue hosts read through a physical mesh component.

It round-trips and survives `wolvenkit import <glb> --keep` (checked on
`slot_coin`). It only matters for an `entPhysicalMeshComponent` or a raw `.mesh`
prop host, so the packs do not use it. Keep it for the fallback below.

## Verifying

1. Build the pack: `python3 tools/build-casino-slots-props.py --lab <lab> --work <work>`.
   Its verify step:
   - counts the collider entity in the archive index;
   - checks the round-tripped JSON with `check_collider_entity`, which compares
     box sizes against the baked scale, Static, the preset, the masks and the CRUID.
2. Run `python3 tools/test-table-colliders.py --build <work>`. It checks:
   - the helper structures;
   - the manifests, archive indexes and client list;
   - the round trip;
   - client behaviour (the placement ghost is non-solid, the collider follows,
     ALT pickup, cleanup, a missing asset is tolerated).
3. In game (owner), on a fresh launcher join so the new archive is mounted:
   1. Place a slot machine and walk into it from the front, the sides and the back.
      You must stop at the cabinet. Its lever side (+X) is intentionally open.
   2. Sit (E), play, and leave (Backspace). The camera and E prompt are unchanged.
   3. While placing (ghost), walk through the preview. It must not block or push.
   4. ALT-click the machine → "Pick up board" still works. Afterwards, walk where
      it stood: nothing solid remains.
   5. Server log, if a collider failed: look for
      `collider_create_failed ... slot_cabinet_collider.ent`.

If step 1 walks through, isolate the cause with the bundled prop commands, at the
staff console, standing 2 m away:

- `prop.create open77\assets\op77_lightrp\casino_slots\slot_cabinet_collider.ent <x> <y> <z>`
  (server-owned, `collision=true`, `physics=static`).
  - Solid: the client path is wrong.
  - Not solid: the collider-only entity route does not work on this build. Fall
    back to (a) the mesh-physics route with an `entPhysicalMeshComponent` base, or
    (b) a hidden collidable catalogue alias (`visible=false`). Neither is proven:
    it is unknown whether a hidden prop keeps its collider, and catalogue
    colliders cannot be resized.
