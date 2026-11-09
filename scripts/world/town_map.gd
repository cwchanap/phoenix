class_name TownMap
extends Node2D

@onready var entities: Node2D = $Entities

func _ready() -> void:
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

    var perimeter_names := ["PerimeterTop", "PerimeterRight", "PerimeterBottom", "PerimeterLeft"]
    var perimeter_rects := WorldContract.perimeter_footprints(TownContract.MAP_SIZE)
    for index in perimeter_rects.size():
        _fill_collision(static_collision, perimeter_names[index], perimeter_rects[index])

func _fill_collision(
    static_collision: StaticBody2D,
    node_name: String,
    footprint: Rect2,
) -> void:
    var collision := static_collision.get_node(node_name) as CollisionPolygon2D
    collision.polygon = WorldMath.footprint_to_polygon(footprint)
