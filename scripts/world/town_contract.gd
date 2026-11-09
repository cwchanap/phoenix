class_name TownContract
extends RefCounted

const MAP_SIZE := Vector2i(16, 12)
const TRUCK_CELL := Vector2i(2, 9)
const TRUCK_ARRIVAL := Vector2i(3, 8)
const TRUCK_FOOTPRINT := Rect2(2.0, 9.0, 1.0, 1.0)
const STATION_FOOTPRINT := Rect2(1.85, 3.85, 1.3, 1.3)
const SHOP_FOOTPRINT := Rect2(6.85, 2.85, 1.3, 1.3)
const SHOP_CELL := Vector2i(7, 4)
const CAFE_FOOTPRINT := Rect2(10.85, 2.85, 1.3, 1.3)
const MARKET_FOOTPRINT := Rect2(12.85, 5.85, 1.3, 1.3)
const MARKET_CELL := Vector2i(13, 7)
const VILLAGER_CELLS: Array[Vector2i] = [
    Vector2i(9, 4),
    Vector2i(5, 7),
    Vector2i(11, 6),
]
const VILLAGER_FOOTPRINTS: Array[Rect2] = [
    Rect2(9.2, 4.2, 0.6, 0.6),
    Rect2(5.2, 7.2, 0.6, 0.6),
    Rect2(11.2, 6.2, 0.6, 0.6),
]
const VILLAGER_COLLISION_NAMES: Array[String] = [
    "VillagerShopkeeperCollision",
    "VillagerFarmerCollision",
    "VillagerResidentCollision",
]
const CAMERA_BOUNDS := Rect2(384.0, -96.0, 896.0, 544.0)

static func villager_cell(id: VillagerRules.VillagerId) -> Vector2i:
    return VILLAGER_CELLS[id]

static func villager_footprint(id: VillagerRules.VillagerId) -> Rect2:
    return VILLAGER_FOOTPRINTS[id]

static func villager_at(cell: Variant) -> int:
    return VILLAGER_CELLS.find(cell)
