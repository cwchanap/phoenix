class_name FarmMap
extends GameMap

const SPAWN := WorldContract.PLAYER_SPAWN
const TRUCK_SPAWN := Vector2(WorldContract.TRUCK_ARRIVAL) + Vector2(0.5, 0.5)
const MAP_SIZE := WorldContract.MAP_SIZE
# The canonical target of the player_occluder group: the three named colliders
# keep their historical nodes; every other contract blocker gets a generated
# collision polygon.
const NAMED_COLLISION_PROPS: Array[String] = ["House", "Shipping", "Truck"]

@onready var entities: FarmView = $Entities as FarmView
@onready var effects: FarmActionEffects = $FarmActionEffects as FarmActionEffects

func _ready() -> void:
    var static_collision := $StaticCollision as StaticBody2D
    _fill_collision(static_collision, "HouseCollision", WorldContract.HOUSE_FOOTPRINT)
    _fill_collision(static_collision, "ShippingCollision", WorldContract.SHIPPING_FOOTPRINT)
    _fill_collision(static_collision, "TruckCollision", WorldContract.TRUCK_FOOTPRINT)
    _fill_perimeters(static_collision, MAP_SIZE)

    _add_collisions(static_collision, _terrain_collision_rects(), "TerrainCollision")
    var prop_rects: Array[Rect2] = []
    for entry in WorldContract.blocking_props():
        if NAMED_COLLISION_PROPS.has(entry["node"]):
            continue
        prop_rects.append(entry["footprint"])
    _add_collisions(static_collision, prop_rects, "PropCollision")
    _add_collisions(static_collision, WorldContract.fence_footprints(), "FenceCollision")

## Blocking terrain comes from the final last-writer-wins material grid as
## horizontal runs, so the reopened road and pier cells never gain a collider.
static func _terrain_collision_rects() -> Array[Rect2]:
    var rects: Array[Rect2] = []
    for y in MAP_SIZE.y:
        var start := -1
        for x in MAP_SIZE.x + 1:
            var blocking := x < MAP_SIZE.x and WorldContract.blocks_movement(Vector2i(x, y))
            if blocking and start < 0:
                start = x
            elif not blocking and start >= 0:
                rects.append(Rect2(start, y, x - start, 1))
                start = -1
    return rects

func bind_player(player: PlayerController) -> void:
    effects.setup(player, entities)

func spawn_position(arrived_by_truck: bool = false) -> Vector2:
    return TRUCK_SPAWN if arrived_by_truck else SPAWN

func camera_bounds() -> Rect2:
    return WorldMath.map_camera_bounds(MAP_SIZE)

func map_size() -> Vector2i:
    return MAP_SIZE
