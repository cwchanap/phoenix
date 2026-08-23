class_name WorldContract
extends RefCounted

const MAP_SIZE := Vector2i(12, 12)
const TILE_SIZE := Vector2(64.0, 32.0)
const PROJECTION_ORIGIN := Vector2(384.0, 0.0)
const PLAYER_SPAWN := Vector2(2.5, 9.5)
const PLAYER_HALF_EXTENT := 0.18
const MOVE_SPEED := 96.0
const TREE_FOOTPRINT := Rect2(7.2, 4.2, 0.6, 0.6)
const TREE_ANCHOR := Vector2(480.0, 192.0)
const BUILDING_FOOTPRINT := Rect2(7.0, 7.0, 2.0, 2.0)
const BUILDING_ANCHOR := Vector2(384.0, 288.0)
const SHOP_CELL := Vector2i(6, 7)
const BED_CELL := Vector2i(6, 8)
const SHIPPING_CELL := Vector2i(6, 10)
const SHIPPING_FOOTPRINT := Rect2(6.2, 10.2, 0.6, 0.6)
const VILLAGER_CELLS: Array[Vector2i] = [
    Vector2i(6, 5),
    Vector2i(3, 5),
    Vector2i(9, 5),
]
const VILLAGER_FOOTPRINTS: Array[Rect2] = [
    Rect2(6.2, 5.2, 0.6, 0.6),
    Rect2(3.2, 5.2, 0.6, 0.6),
    Rect2(9.2, 5.2, 0.6, 0.6),
]
const VILLAGER_COLLISION_NAMES: Array[String] = [
    "VillagerShopkeeperCollision",
    "VillagerFarmerCollision",
    "VillagerResidentCollision",
]
const CAMERA_TOP_PADDING := 96.0
const CAMERA_BOUNDS := Rect2(0.0, -96.0, 768.0, 480.0)

const FARM_PATCH := Rect2i(2, 7, 3, 3)
const PATH_ROW := Rect2i(3, 6, 7, 1)

static func farm_cells() -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for y in range(FARM_PATCH.position.y, FARM_PATCH.end.y):
        for x in range(FARM_PATCH.position.x, FARM_PATCH.end.x):
            cells.append(Vector2i(x, y))
    return cells

static func path_cells() -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for y in range(PATH_ROW.position.y, PATH_ROW.end.y):
        for x in range(PATH_ROW.position.x, PATH_ROW.end.x):
            cells.append(Vector2i(x, y))
    return cells

static func villager_cell(id: VillagerRules.VillagerId) -> Vector2i:
    return VILLAGER_CELLS[id]

static func villager_footprint(id: VillagerRules.VillagerId) -> Rect2:
    return VILLAGER_FOOTPRINTS[id]

static func villager_at(cell: Variant) -> int:
    if not (cell is Vector2i):
        return -1
    return VILLAGER_CELLS.find(cell)
