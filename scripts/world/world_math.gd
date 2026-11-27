class_name WorldMath
extends RefCounted

enum Facing { UP, RIGHT, DOWN, LEFT }

const TARGET_OFFSETS := {
    Facing.UP: Vector2i(-1, -1),
    Facing.RIGHT: Vector2i(1, -1),
    Facing.DOWN: Vector2i(1, 1),
    Facing.LEFT: Vector2i(-1, 1),
}
## Fraction of TARGET_OFFSETS the target probe reaches ahead of the feet.
const TARGET_REACH := 0.5

static func grid_delta_to_world(delta: Vector2) -> Vector2:
    return Vector2(
        (delta.x - delta.y) * (WorldContract.TILE_SIZE.x / 2.0),
        (delta.x + delta.y) * (WorldContract.TILE_SIZE.y / 2.0),
    )

static func grid_to_world(point: Vector2) -> Vector2:
    return WorldContract.PROJECTION_ORIGIN + grid_delta_to_world(point)

static func world_to_grid(point: Vector2) -> Vector2:
    var offset := point - WorldContract.PROJECTION_ORIGIN
    return Vector2(
        offset.x / WorldContract.TILE_SIZE.x + offset.y / WorldContract.TILE_SIZE.y,
        offset.y / WorldContract.TILE_SIZE.y - offset.x / WorldContract.TILE_SIZE.x,
    )

static func grid_cell_at_world(point: Vector2) -> Vector2i:
    var logical := world_to_grid(point)
    return Vector2i(floori(logical.x + 1e-9), floori(logical.y + 1e-9))

static func cell_diamond(cell: Vector2i) -> PackedVector2Array:
    var logical := Vector2(cell.x, cell.y)
    return PackedVector2Array([
        grid_to_world(logical),
        grid_to_world(logical + Vector2.RIGHT),
        grid_to_world(logical + Vector2.ONE),
        grid_to_world(logical + Vector2.DOWN),
    ])

static func facing_for_input(input: Vector2, previous: Facing) -> Facing:
    if input.length_squared() == 0.0:
        return previous
    if abs(input.x) >= abs(input.y):
        return Facing.RIGHT if input.x > 0.0 else Facing.LEFT
    return Facing.DOWN if input.y > 0.0 else Facing.UP

## The target is the cell under a probe half a cell ahead of the feet along
## the facing (32 px sideways, 16 px up/down), so it is always the tile
## directly in front of the player, never more than one tile ahead, and a
## 90-degree turn moves it to an edge-adjacent tile. A probe exactly on a cell
## edge resolves toward the facing, so a player standing on a cell centre
## (spawn, fixtures) targets the facing's corner neighbour; only those exact
## centre lines let a turn move corner to corner.
static func target_cell(position: Vector2, facing: Facing, map_size: Vector2i) -> Variant:
    var offset: Vector2i = TARGET_OFFSETS[facing]
    var probe := position + Vector2(offset) * TARGET_REACH
    var target := Vector2i(
        floori(probe.x) if offset.x > 0 else ceili(probe.x) - 1,
        floori(probe.y) if offset.y > 0 else ceili(probe.y) - 1,
    )
    if (
        target.x < 0
        or target.x >= map_size.x
        or target.y < 0
        or target.y >= map_size.y
    ):
        return null
    return target

static func footprint_to_polygon(footprint: Rect2) -> PackedVector2Array:
    var top_left := footprint.position
    var bottom_right := footprint.position + footprint.size
    return PackedVector2Array([
        grid_to_world(top_left),
        grid_to_world(Vector2(bottom_right.x, top_left.y)),
        grid_to_world(bottom_right),
        grid_to_world(Vector2(top_left.x, bottom_right.y)),
    ])

## HPA-743: nearest point on a collision footprint's projected boundary to a
## world ground position, evaluated edge by edge with the exact segment
## closest point.
static func closest_contact(world_ground_position: Vector2, collision_rect: Rect2) -> Vector2:
    var polygon := footprint_to_polygon(collision_rect)
    var best := world_ground_position
    var best_distance := INF
    for index in polygon.size():
        var candidate := Geometry2D.get_closest_point_to_segment(
            world_ground_position, polygon[index], polygon[(index + 1) % polygon.size()]
        )
        var distance := world_ground_position.distance_to(candidate)
        if distance < best_distance:
            best_distance = distance
            best = candidate
    return best

static func footprint_ground_anchor(footprint: Rect2) -> Vector2:
    return Vector2(
        grid_to_world(footprint.position + footprint.size * 0.5).x,
        grid_to_world(footprint.position + footprint.size).y,
    )

## True when grid_pos is on the viewer's side of a footprint's two southern
## front edges (past y = end.y or x = end.x and south of the matching corner's
## screen Y), so the player sorts in front of multi-cell props along all front faces.
static func is_in_front_of_footprint(grid_pos: Vector2, footprint: Rect2) -> bool:
    var front_sw := (
        grid_pos.y >= footprint.end.y
        and grid_pos.x + grid_pos.y >= footprint.position.x + footprint.end.y
    )
    var front_se := (
        grid_pos.x >= footprint.end.x
        and grid_pos.x + grid_pos.y >= footprint.end.x + footprint.position.y
    )
    return front_sw or front_se

static func map_camera_bounds(map_size: Vector2i) -> Rect2:
    var size := Vector2(map_size)
    var west := grid_to_world(Vector2(0.0, size.y))
    var east := grid_to_world(Vector2(size.x, 0.0))
    var top := grid_to_world(Vector2.ZERO).y
    var bottom := grid_to_world(size).y
    return Rect2(
        west.x,
        top - WorldContract.CAMERA_TOP_PADDING,
        east.x - west.x,
        bottom - top + WorldContract.CAMERA_TOP_PADDING,
    )

## HPA-743: camera-corner overdraw cells for a map's backdrop painter — every
## tile whose 64x32 diamond intersects the camera bounds but lies outside the
## playable map rect, keeping the one-cell coverage margin.
static func backdrop_cells(camera_bounds: Rect2, map_size: Vector2i) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    var half := WorldContract.TILE_SIZE * 0.5
    var min_cell := Vector2(INF, INF)
    var max_cell := Vector2(-INF, -INF)
    for offset in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
        var corner := world_to_grid(camera_bounds.position + offset * camera_bounds.size)
        min_cell.x = minf(min_cell.x, corner.x)
        min_cell.y = minf(min_cell.y, corner.y)
        max_cell.x = maxf(max_cell.x, corner.x)
        max_cell.y = maxf(max_cell.y, corner.y)
    var map_rect := Rect2i(Vector2i.ZERO, map_size)
    for x in range(floori(min_cell.x) - 1, ceili(max_cell.x) + 1):
        for y in range(floori(min_cell.y) - 1, ceili(max_cell.y) + 1):
            var cell := Vector2i(x, y)
            var tile := Rect2(
                grid_to_world(Vector2(cell) + Vector2(0.5, 0.5)) - half,
                WorldContract.TILE_SIZE,
            )
            if tile.intersects(camera_bounds) and not map_rect.has_point(cell):
                cells.append(cell)
    return cells

static func centered_player_footprint_polygon(center: Vector2) -> PackedVector2Array:
    var half_extent := Vector2(
        WorldContract.PLAYER_HALF_EXTENT,
        WorldContract.PLAYER_HALF_EXTENT,
    )
    return footprint_to_polygon(Rect2(center - half_extent, half_extent * 2.0))
