class_name FarmMap
extends Node2D
## The authored farm map: ground/water/path/decoration TileMapLayers,
## non-Y-sorted FarmSoil decals, transient FarmActionEffects, the
## HomesteadAmbience, every farm StaticCollision body, and the one Y-sorted
## Entities/FarmView. Player-placement values come from WorldContract;
## WorldShell owns the session and reparents the single Player into
## `entities` per load.

@onready var entities: FarmView = $Entities as FarmView
@onready var effects: FarmActionEffects = $FarmActionEffects as FarmActionEffects
@onready var ambience: HomesteadAmbience = $HomesteadAmbience as HomesteadAmbience

var spawn := WorldContract.PLAYER_SPAWN
var camera_bounds := WorldContract.CAMERA_BOUNDS

func _ready() -> void:
    var static_collision := $StaticCollision as StaticBody2D
    _fill_collision(static_collision, "HouseCollision", WorldContract.HOUSE_FOOTPRINT)
    _fill_collision(static_collision, "ShopStallCollision", WorldContract.SHOP_STALL_FOOTPRINT)
    _fill_collision(static_collision, "ForestCollision", WorldContract.FOREST_FOOTPRINT)
    _fill_collision(static_collision, "RiverWestCollision", WorldContract.RIVER_WEST_FOOTPRINT)
    _fill_collision(static_collision, "RiverSouthCollision", WorldContract.RIVER_SOUTH_FOOTPRINT)
    _fill_collision(static_collision, "WorkbenchCollision", WorldContract.WORKBENCH_FOOTPRINT)
    _fill_collision(static_collision, "ShippingCollision", WorldContract.SHIPPING_FOOTPRINT)
    _fill_collision(static_collision, "HarvestMarketCollision", WorldContract.MARKET_FOOTPRINT)

    var perimeter_names := ["PerimeterTop", "PerimeterRight", "PerimeterBottom", "PerimeterLeft"]
    var perimeter_rects := WorldContract.perimeter_footprints()
    for index in perimeter_rects.size():
        _fill_collision(static_collision, perimeter_names[index], perimeter_rects[index])

## WorldShell calls this after the persistent Player is reparented under
## `entities`; _ready() must not bind a Player that has not joined the map.
func bind_player(player: PlayerController) -> void:
    effects.setup(player, entities)

func _fill_collision(
    static_collision: StaticBody2D,
    node_name: String,
    footprint: Rect2,
) -> void:
    var collision := static_collision.get_node(node_name) as CollisionPolygon2D
    collision.polygon = WorldMath.footprint_to_polygon(footprint)
