class_name WorldMath
extends RefCounted

enum Facing { UP, RIGHT, DOWN, LEFT }

const TARGET_OFFSETS := {
    Facing.UP: Vector2i(-1, -1),
    Facing.RIGHT: Vector2i(1, -1),
    Facing.DOWN: Vector2i(1, 1),
    Facing.LEFT: Vector2i(-1, 1),
}

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

static func target_cell(position: Vector2, facing: Facing) -> Variant:
    var offset: Vector2i = TARGET_OFFSETS[facing]
    var target := Vector2i(floori(position.x), floori(position.y)) + offset
    if (
        target.x < 0
        or target.x >= WorldContract.MAP_SIZE.x
        or target.y < 0
        or target.y >= WorldContract.MAP_SIZE.y
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

static func centered_player_footprint_polygon(center: Vector2) -> PackedVector2Array:
    var half_extent := Vector2(
        WorldContract.PLAYER_HALF_EXTENT,
        WorldContract.PLAYER_HALF_EXTENT,
    )
    return footprint_to_polygon(Rect2(center - half_extent, half_extent * 2.0))
