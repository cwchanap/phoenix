class_name TownMap
extends GameMap

const SPAWN := Vector2(TownContract.TRUCK_ARRIVAL) + Vector2(0.5, 0.5)
const CAMERA_BOUNDS := TownContract.CAMERA_BOUNDS
const MAP_SIZE := TownContract.MAP_SIZE

func _ready() -> void:
    var backdrop := $Backdrop as TileMapLayer
    var map_rect := Rect2i(Vector2i.ZERO, MAP_SIZE)
    for cell in TownContract.backdrop_cells():
        if map_rect.has_point(cell):
            continue
        var tile := (
            TownContract.BACKDROP_ROAD_TILE
            if TownContract.is_backdrop_road(cell)
            else TownContract.BACKDROP_GRASS_TILE
        )
        backdrop.set_cell(cell, 0, tile)

    var static_collision := $StaticCollision as StaticBody2D
    _fill_collision(static_collision, "StationCollision", TownContract.STATION_FOOTPRINT)
    _fill_collision(static_collision, "SeedShopCollision", TownContract.SHOP_FOOTPRINT)
    _fill_collision(static_collision, "CafeCollision", TownContract.CAFE_FOOTPRINT)
    _fill_collision(static_collision, "MarketCollision", TownContract.MARKET_FOOTPRINT)
    _fill_collision(static_collision, "TruckCollision", TownContract.TRUCK_FOOTPRINT)
    for id in range(TownContract.VILLAGER_COLLISION_NAMES.size()):
        _fill_collision(
            static_collision,
            TownContract.VILLAGER_COLLISION_NAMES[id],
            TownContract.VILLAGER_FOOTPRINTS[id],
        )
    _fill_perimeters(static_collision, MAP_SIZE)

func spawn_position(_arrived_by_truck: bool = false) -> Vector2:
    return SPAWN

func camera_bounds() -> Rect2:
    return CAMERA_BOUNDS

func map_size() -> Vector2i:
    return MAP_SIZE
