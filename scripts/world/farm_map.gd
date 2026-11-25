class_name FarmMap
extends GameMap

const SPAWN := WorldContract.PLAYER_SPAWN
const TRUCK_SPAWN := Vector2(WorldContract.TRUCK_ARRIVAL) + Vector2(0.5, 0.5)
const MAP_SIZE := WorldContract.MAP_SIZE
# The three props with authored named CollisionPolygon2D nodes; skipped when
# generating generic PropCollision polygons from WorldContract.blocking_props().
const NAMED_COLLISION_PROPS: Array[String] = ["House", "Shipping", "Truck"]

static var _cached_terrain_rects: Array[Rect2] = []

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
## horizontal runs, resolved in a single pass over TERRAIN_RECTS and cached.
static func _terrain_collision_rects() -> Array[Rect2]:
    if not _cached_terrain_rects.is_empty():
        return _cached_terrain_rects
    var map_rect := Rect2i(Vector2i.ZERO, MAP_SIZE)
    var blocked_grid := PackedByteArray()
    blocked_grid.resize(MAP_SIZE.x * MAP_SIZE.y)
    for entry in WorldContract.TERRAIN_RECTS:
        var blocked := 1 if WorldContract.TERRAIN_BLOCKING_MATERIALS.has(entry["material"]) else 0
        var rect: Rect2i = entry["rect"].intersection(map_rect)
        for y in range(rect.position.y, rect.end.y):
            var row_offset := y * MAP_SIZE.x
            for x in range(rect.position.x, rect.end.x):
                blocked_grid[row_offset + x] = blocked
    var rects: Array[Rect2] = []
    for y in MAP_SIZE.y:
        var row_offset := y * MAP_SIZE.x
        var start := -1
        for x in MAP_SIZE.x + 1:
            var blocking := x < MAP_SIZE.x and blocked_grid[row_offset + x] != 0
            if blocking and start < 0:
                start = x
            elif not blocking and start >= 0:
                rects.append(Rect2(start, y, x - start, 1))
                start = -1
    _cached_terrain_rects = rects
    return _cached_terrain_rects

func bind_player(player: PlayerController) -> void:
    effects.setup(player, entities)

func spawn_position(arrived_by_truck: bool = false) -> Vector2:
    return TRUCK_SPAWN if arrived_by_truck else SPAWN

func camera_bounds() -> Rect2:
    return WorldMath.map_camera_bounds(MAP_SIZE)

func map_size() -> Vector2i:
    return MAP_SIZE
