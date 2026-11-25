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

static func blocking_props() -> Array:
    return [
        {"node": "Station", "footprint": STATION_FOOTPRINT},
        {"node": "SeedShop", "footprint": SHOP_FOOTPRINT},
        {"node": "Cafe", "footprint": CAFE_FOOTPRINT},
        {"node": "Market", "footprint": MARKET_FOOTPRINT},
        {"node": "Truck", "footprint": TRUCK_FOOTPRINT},
    ]

## Multi-cell town occluders whose ground-plane sort must yield to the player
## across both southern front edges, keyed by Entities child name.
static func multi_cell_occluders() -> Dictionary:
    var result := {}
    for entry in blocking_props():
        var footprint: Rect2 = entry["footprint"]
        if footprint.size.x > 1.0 or footprint.size.y > 1.0:
            result[entry["node"]] = {
                "footprint": footprint,
                "anchor": WorldMath.footprint_ground_anchor(footprint),
            }
    return result

## HPA-743 canonical E-interact regions in contract order (this order breaks
## distance ties): truck, shop, market, then the three villagers — each maps
## an interactable cell to its already-defined collision footprint.
static func interact_regions() -> Array:
    var regions: Array = [
        {"cell": TRUCK_CELL, "footprint": TRUCK_FOOTPRINT},
        {"cell": SHOP_CELL, "footprint": SHOP_FOOTPRINT},
        {"cell": MARKET_CELL, "footprint": MARKET_FOOTPRINT},
    ]
    for index in VILLAGER_CELLS.size():
        regions.append(
            {"cell": VILLAGER_CELLS[index], "footprint": VILLAGER_FOOTPRINTS[index]}
        )
    return regions

static func villager_cell(id: VillagerRules.VillagerId) -> Vector2i:
    return VILLAGER_CELLS[id]

static func villager_at(cell: Variant) -> int:
    if not (cell is Vector2i):
        return -1
    return VILLAGER_CELLS.find(cell)

static func is_backdrop_road(cell: Vector2i) -> bool:
    return cell.y == 9 or (cell.y == 10 and cell.x <= 4)
