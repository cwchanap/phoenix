class_name WorldContract
extends RefCounted

const MAP_SIZE := Vector2i(48, 40)
const TILE_SIZE := Vector2(64.0, 32.0)
const PROJECTION_ORIGIN := Vector2(768.0, 0.0)
const PLAYER_SPAWN := Vector2(23.5, 11.5)
const PLAYER_HALF_EXTENT := 0.18
const MOVE_SPEED := 96.0
const HOUSE_FOOTPRINT := Rect2(22.0, 7.0, 3.0, 3.0)
const BED_CELL := Vector2i(23, 10)
const SHIPPING_CELL := Vector2i(22, 19)
const SHIPPING_FOOTPRINT := Rect2(22.0, 19.0, 1.0, 1.0)
const TRUCK_CELL := Vector2i(33, 12)
const TRUCK_ARRIVAL := Vector2i(32, 13)
const TRUCK_FOOTPRINT := Rect2(33.0, 12.0, 1.0, 1.0)
# One world (art) pixel draws as CAMERA_ZOOM screen pixels on the 1920x1080
# canvas, so the camera still frames a 640x360 world view. A higher-res art
# set changes only this value.
const CAMERA_ZOOM := 3.0
const CAMERA_TOP_PADDING := 96.0

# HPA-863 v2 terrain: the one ordered, last-writer-wins material table the
# ground stamper and the collision derivation both read.
const TERRAIN_RECTS := [
    {"material": "grass", "rect": Rect2i(0, 0, 48, 40)},
    {"material": "forest", "rect": Rect2i(0, 0, 48, 3)},
    {"material": "forest", "rect": Rect2i(0, 3, 17, 1)},
    {"material": "forest", "rect": Rect2i(31, 3, 11, 2)},
    {"material": "forest", "rect": Rect2i(0, 0, 1, 40)},
    {"material": "water", "rect": Rect2i(1, 0, 2, 37)},
    {"material": "water", "rect": Rect2i(1, 35, 31, 2)},
    {"material": "water", "rect": Rect2i(30, 37, 2, 3)},
    {"material": "reeds", "rect": Rect2i(1, 37, 29, 3)},
    {"material": "bamboo", "rect": Rect2i(3, 4, 3, 3)},
    {"material": "bamboo", "rect": Rect2i(9, 4, 3, 3)},
    {"material": "water", "rect": Rect2i(4, 31, 4, 3)},
    {"material": "road", "rect": Rect2i(42, 0, 2, 40)},
    {"material": "paddy", "rect": Rect2i(44, 0, 4, 40)},
    {"material": "yard", "rect": Rect2i(18, 6, 13, 9)},
    {"material": "lot", "rect": Rect2i(3, 8, 15, 9)},
    {"material": "path", "rect": Rect2i(23, 14, 2, 19)},
    {"material": "path", "rect": Rect2i(3, 12, 15, 1)},
    {"material": "path", "rect": Rect2i(17, 10, 1, 2)},
    {"material": "path", "rect": Rect2i(7, 6, 1, 6)},
    {"material": "path", "rect": Rect2i(22, 20, 1, 2)},
    {"material": "gravel", "rect": Rect2i(25, 15, 17, 2)},
    {"material": "gravel", "rect": Rect2i(31, 11, 5, 5)},
    {"material": "field", "rect": Rect2i(15, 19, 6, 5)},
    {"material": "fallow", "rect": Rect2i(8, 19, 6, 5)},
    {"material": "fallow", "rect": Rect2i(8, 25, 6, 5)},
    {"material": "fallow", "rect": Rect2i(15, 25, 6, 5)},
    {"material": "pier", "rect": Rect2i(23, 33, 2, 3)},
]
const TERRAIN_BLOCKING_MATERIALS: Array[String] = ["bamboo", "forest", "paddy", "reeds", "water"]

const FARM_PATCH := Rect2i(15, 19, 6, 5)

const PERIMETER_BAND_WIDTH := 1.0

# HPA-743: the E resolver's physical near-contact reach, in projected world
# pixels, measured from the player's ground centre to the closest contact
# point on a region's collision footprint (inclusive).
const INTERACT_REACH_PIXELS := 14.0

# HPA-863 blocking props: every approved solid sprite root wears the exact
# full-cell (or approved multi-cell) footprint that its collision carries, so
# the scene, the collider set and the tests all read one table.
static func blocking_props() -> Array:
    return [
        {"node": "House", "footprint": HOUSE_FOOTPRINT},
        {"node": "Persimmon", "footprint": Rect2(19.0, 7.0, 1.0, 1.0)},
        {"node": "LaundryPole", "footprint": Rect2(20.0, 8.0, 1.0, 1.0)},
        {"node": "Well", "footprint": Rect2(20.0, 11.0, 1.0, 1.0)},
        {"node": "ToolShed", "footprint": Rect2(27.0, 7.0, 2.0, 2.0)},
        {"node": "Woodpile", "footprint": Rect2(29.0, 7.0, 1.0, 1.0)},
        {"node": "Workbench", "footprint": Rect2(27.0, 10.0, 1.0, 1.0)},
        {"node": "Crates", "footprint": Rect2(29.0, 10.0, 1.0, 1.0)},
        {"node": "StoneLanternA", "footprint": Rect2(22.0, 13.0, 1.0, 1.0)},
        {"node": "StoneLanternB", "footprint": Rect2(25.0, 13.0, 1.0, 1.0)},
        {"node": "Shipping", "footprint": SHIPPING_FOOTPRINT},
        {"node": "Scarecrow", "footprint": Rect2(11.0, 22.0, 1.0, 1.0)},
        {"node": "RainBarrel", "footprint": Rect2(22.0, 23.0, 1.0, 1.0)},
        {"node": "Compost", "footprint": Rect2(5.0, 21.0, 1.0, 1.0)},
        {"node": "Storehouse", "footprint": Rect2(12.0, 8.0, 5.0, 4.0)},
        {"node": "BuildBoard", "footprint": Rect2(17.0, 13.0, 1.0, 1.0)},
        {"node": "Shrine", "footprint": Rect2(6.0, 4.0, 2.0, 2.0)},
        {"node": "BenchPond", "footprint": Rect2(8.0, 32.0, 1.0, 1.0)},
        {"node": "RockRiverside1", "footprint": Rect2(12.0, 33.0, 1.0, 1.0)},
        {"node": "BenchPier", "footprint": Rect2(25.0, 33.0, 1.0, 1.0)},
        {"node": "RockRiverside2", "footprint": Rect2(28.0, 33.0, 1.0, 1.0)},
        {"node": "Truck", "footprint": TRUCK_FOOTPRINT},
        {"node": "Mailbox", "footprint": Rect2(41.0, 14.0, 1.0, 1.0)},
        {"node": "VillageSign", "footprint": Rect2(40.0, 17.0, 1.0, 1.0)},
        {"node": "VendingMachine", "footprint": Rect2(41.0, 18.0, 1.0, 1.0)},
        {"node": "Jizo", "footprint": Rect2(41.0, 12.0, 1.0, 1.0)},
        {"node": "UtilityPole1", "footprint": Rect2(41.0, 6.0, 1.0, 1.0)},
        {"node": "UtilityPole2", "footprint": Rect2(41.0, 24.0, 1.0, 1.0)},
        {"node": "UtilityPole3", "footprint": Rect2(41.0, 30.0, 1.0, 1.0)},
        {"node": "UtilityPole4", "footprint": Rect2(41.0, 36.0, 1.0, 1.0)},
        {"node": "Greenhouse", "footprint": Rect2(27.0, 19.0, 5.0, 4.0)},
        {"node": "FruitTree1", "footprint": Rect2(34.0, 21.0, 1.0, 1.0)},
        {"node": "FruitTree2", "footprint": Rect2(37.0, 21.0, 1.0, 1.0)},
        {"node": "FruitTree3", "footprint": Rect2(40.0, 21.0, 1.0, 1.0)},
        {"node": "FruitTree4", "footprint": Rect2(34.0, 24.0, 1.0, 1.0)},
        {"node": "FruitTree5", "footprint": Rect2(37.0, 24.0, 1.0, 1.0)},
        {"node": "FruitTree6", "footprint": Rect2(40.0, 24.0, 1.0, 1.0)},
        {"node": "FruitTree7", "footprint": Rect2(34.0, 27.0, 1.0, 1.0)},
        {"node": "FruitTree8", "footprint": Rect2(37.0, 27.0, 1.0, 1.0)},
        {"node": "FruitTree9", "footprint": Rect2(40.0, 27.0, 1.0, 1.0)},
        {"node": "Camphor", "footprint": Rect2(36.0, 7.0, 2.0, 2.0)},
        {"node": "RockMeadow1", "footprint": Rect2(33.0, 6.0, 1.0, 1.0)},
        {"node": "Bush1", "footprint": Rect2(39.0, 10.0, 1.0, 1.0)},
        {"node": "Bush2", "footprint": Rect2(19.0, 16.0, 1.0, 1.0)},
        {"node": "RockMeadow2", "footprint": Rect2(17.0, 17.0, 1.0, 1.0)},
        {"node": "Bush3", "footprint": Rect2(26.0, 18.0, 1.0, 1.0)},
        {"node": "RockMeadow3", "footprint": Rect2(3.0, 17.0, 1.0, 1.0)},
    ]

## The 12 approved straight fence runs: seven bamboo yard runs and five
## wooden field runs. Gates are simply the cells the runs leave out.
static func fence_runs() -> Array:
    return [
        {"material": "bamboo", "start": Vector2i(18, 6), "length": 13, "step": Vector2i(1, 0)},
        {"material": "bamboo", "start": Vector2i(18, 7), "length": 3, "step": Vector2i(0, 1)},
        {"material": "bamboo", "start": Vector2i(18, 11), "length": 4, "step": Vector2i(0, 1)},
        {"material": "bamboo", "start": Vector2i(30, 7), "length": 4, "step": Vector2i(0, 1)},
        {"material": "bamboo", "start": Vector2i(30, 13), "length": 2, "step": Vector2i(0, 1)},
        {"material": "bamboo", "start": Vector2i(19, 14), "length": 4, "step": Vector2i(1, 0)},
        {"material": "bamboo", "start": Vector2i(25, 14), "length": 5, "step": Vector2i(1, 0)},
        {"material": "wood", "start": Vector2i(7, 18), "length": 15, "step": Vector2i(1, 0)},
        {"material": "wood", "start": Vector2i(7, 19), "length": 12, "step": Vector2i(0, 1)},
        {"material": "wood", "start": Vector2i(21, 19), "length": 1, "step": Vector2i(0, 1)},
        {"material": "wood", "start": Vector2i(21, 22), "length": 9, "step": Vector2i(0, 1)},
        {"material": "wood", "start": Vector2i(8, 30), "length": 13, "step": Vector2i(1, 0)},
    ]

static func fence_cells() -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for run in fence_runs():
        for index in int(run["length"]):
            cells.append(run["start"] + run["step"] * index)
    return cells

static func fence_footprints() -> Array[Rect2]:
    var footprints: Array[Rect2] = []
    for cell in fence_cells():
        footprints.append(Rect2(cell, Vector2.ONE))
    return footprints

## The three visible river-ripple spots: contract water cells, centred by
## HomesteadAmbience.
const RIVER_RIPPLE_CELLS: Array[Vector2i] = [
    Vector2i(1, 6),
    Vector2i(1, 13),
    Vector2i(5, 32),
]

## The bed's reachable contact is the narrow southern slice of the house
## footprint: the 3x3 house ends exactly where the door cell begins, so the old
## footprint/cell intersection is an empty Rect2 at the origin.
static func bed_contact_footprint() -> Rect2:
    return Rect2(BED_CELL.x, HOUSE_FOOTPRINT.end.y - 0.25, 1.0, 0.25)

## Canonical E-interact regions in contract order: each maps an interactable
## cell to its already-defined collision footprint.
static func interact_regions() -> Array:
    return [
        {"cell": BED_CELL, "footprint": bed_contact_footprint()},
        {"cell": SHIPPING_CELL, "footprint": SHIPPING_FOOTPRINT},
        {"cell": TRUCK_CELL, "footprint": TRUCK_FOOTPRINT},
    ]

static func perimeter_footprints(map_size: Vector2i) -> Array[Rect2]:
    var size := Vector2(map_size)
    return [
        Rect2(0.0, -PERIMETER_BAND_WIDTH, size.x, PERIMETER_BAND_WIDTH),
        Rect2(size.x, 0.0, PERIMETER_BAND_WIDTH, size.y),
        Rect2(0.0, size.y, size.x, PERIMETER_BAND_WIDTH),
        Rect2(-PERIMETER_BAND_WIDTH, 0.0, PERIMETER_BAND_WIDTH, size.y),
    ]

static func farm_cells() -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for y in range(FARM_PATCH.position.y, FARM_PATCH.end.y):
        for x in range(FARM_PATCH.position.x, FARM_PATCH.end.x):
            cells.append(Vector2i(x, y))
    return cells

## HPA-863: last-writer-wins terrain material; outside coordinates clamp to the
## nearest map-edge cell so overdraw never invents a shore or a grass rim.
static func material_at(cell: Vector2i) -> String:
    var clamped := Vector2i(
        clampi(cell.x, 0, MAP_SIZE.x - 1),
        clampi(cell.y, 0, MAP_SIZE.y - 1),
    )
    var material := "grass"
    for entry in TERRAIN_RECTS:
        if entry["rect"].has_point(clamped):
            material = entry["material"]
    return material

## Terrain blocking comes from the resolved grid, never a union of the source
## rectangles: the later road and pier strokes reopen the forest and water.
static func blocks_movement(cell: Vector2i) -> bool:
    return TERRAIN_BLOCKING_MATERIALS.has(material_at(cell))
