class_name FarmMap
extends GameMap

const SPAWN := WorldContract.PLAYER_SPAWN
const TRUCK_SPAWN := Vector2(WorldContract.TRUCK_ARRIVAL) + Vector2(0.5, 0.5)
const CAMERA_BOUNDS := WorldContract.CAMERA_BOUNDS
const MAP_SIZE := WorldContract.MAP_SIZE

@onready var entities: FarmView = $Entities as FarmView
@onready var effects: FarmActionEffects = $FarmActionEffects as FarmActionEffects
@onready var ambience: HomesteadAmbience = $HomesteadAmbience as HomesteadAmbience

func _ready() -> void:
    var static_collision := $StaticCollision as StaticBody2D
    _fill_collision(static_collision, "HouseCollision", WorldContract.HOUSE_FOOTPRINT)
    _fill_collision(static_collision, "ForestCollision", WorldContract.FOREST_FOOTPRINT)
    _fill_collision(static_collision, "RiverWestCollision", WorldContract.RIVER_WEST_FOOTPRINT)
    _fill_collision(static_collision, "RiverSouthCollision", WorldContract.RIVER_SOUTH_FOOTPRINT)
    _fill_collision(static_collision, "WorkbenchCollision", WorldContract.WORKBENCH_FOOTPRINT)
    _fill_collision(static_collision, "ShippingCollision", WorldContract.SHIPPING_FOOTPRINT)
    _fill_collision(static_collision, "TruckCollision", WorldContract.TRUCK_FOOTPRINT)
    _fill_perimeters(static_collision, MAP_SIZE)

func bind_player(player: PlayerController) -> void:
    effects.setup(player, entities)

func spawn_position(arrived_by_truck: bool = false) -> Vector2:
    return TRUCK_SPAWN if arrived_by_truck else SPAWN

func camera_bounds() -> Rect2:
    return CAMERA_BOUNDS

func map_size() -> Vector2i:
    return MAP_SIZE
