extends GutTest
## The target tile is the cell under a probe half a cell ahead of the feet:
## always directly in front, never more than one tile ahead, and a turn or a
## step moves it to an edge-adjacent tile. The exact cell-centre lines are the
## deliberate exception: there the probe sits on a cell edge and resolves
## toward the facing, so a centred player keeps the facing's corner neighbour
## (spawn and fixtures) and a walk along a centre line steps straight to the
## next tile ahead.

const CELL := Vector2i(20, 20)
const FACINGS := [
    WorldMath.Facing.UP,
    WorldMath.Facing.RIGHT,
    WorldMath.Facing.DOWN,
    WorldMath.Facing.LEFT,
]

## Sub-cell feet positions on a 20x20 lattice that avoids the exact cell
## centre lines, where the probe would sit on a shared vertex.
func _feet_positions() -> Array[Vector2]:
    var positions: Array[Vector2] = []
    for ix in 20:
        for iy in 20:
            positions.append(Vector2(CELL) + Vector2(0.025 + ix * 0.05, 0.025 + iy * 0.05))
    return positions

func _target(feet: Vector2, facing: WorldMath.Facing) -> Vector2i:
    return WorldMath.target_cell(feet, facing, WorldContract.MAP_SIZE)

## Unit screen direction of a facing.
func _screen_direction(facing: WorldMath.Facing) -> Vector2:
    return WorldMath.grid_delta_to_world(Vector2(WorldMath.TARGET_OFFSETS[facing])).normalized()

func test_target_sits_directly_in_front_and_at_most_one_tile_ahead() -> void:
    for facing in FACINGS:
        var direction := _screen_direction(facing)
        var horizontal := absf(direction.x) > 0.5
        # A diamond is 64x32: one tile ahead is 64 px sideways or 32 px up/down,
        # and its centre can sit at most half a tile to either side.
        var max_ahead := WorldContract.TILE_SIZE.x if horizontal else WorldContract.TILE_SIZE.y
        var max_side := (WorldContract.TILE_SIZE.y if horizontal else WorldContract.TILE_SIZE.x) / 2.0
        for feet in _feet_positions():
            var target := _target(feet, facing)
            var offset := (
                WorldMath.grid_to_world(Vector2(target) + Vector2(0.5, 0.5))
                - WorldMath.grid_to_world(feet)
            )
            var ahead := offset.dot(direction)
            var side := absf(offset.dot(direction.orthogonal()))
            assert_true(
                ahead > 0.0 and ahead <= max_ahead and side <= max_side,
                "facing %d from %s: target %s is %.1f px ahead, %.1f px aside" % [
                    facing, feet, target, ahead, side,
                ],
            )

func test_a_quarter_turn_moves_the_target_to_an_edge_adjacent_tile() -> void:
    for feet in _feet_positions():
        for index in FACINGS.size():
            var from := _target(feet, FACINGS[index])
            var to := _target(feet, FACINGS[(index + 1) % FACINGS.size()])
            var step := (to - from).abs()
            assert_eq(
                step.x + step.y, 1,
                "turning %d->%d from %s moved %s -> %s" % [
                    FACINGS[index], FACINGS[(index + 1) % FACINGS.size()], feet, from, to,
                ],
            )

func test_a_quarter_turn_a_hair_off_a_centre_line_stays_edge_adjacent() -> void:
    # Only the exact centre lines hold the corner-neighbour exception: a hair
    # to either side, every quarter turn is still one edge step.
    var centre := Vector2(CELL) + Vector2(0.5, 0.5)
    var poses: Array[Vector2] = [Vector2(CELL) + Vector2(0.5005, 0.25)]
    for nudge: float in [-0.0005, -0.0001, 0.0001, 0.0005]:
        poses.append(centre + Vector2(nudge, -0.25))
        poses.append(centre + Vector2(-0.25, nudge))
        poses.append(centre + Vector2(nudge, -nudge))
        poses.append(centre + Vector2(nudge, nudge))
    for feet in poses:
        for index in FACINGS.size():
            var from := _target(feet, FACINGS[index])
            var to := _target(feet, FACINGS[(index + 1) % FACINGS.size()])
            var step := (to - from).abs()
            assert_eq(
                step.x + step.y, 1,
                "turning %d->%d from %s moved %s -> %s" % [
                    FACINGS[index], FACINGS[(index + 1) % FACINGS.size()], feet, from, to,
                ],
            )

func test_walking_moves_the_target_one_edge_step_at_a_time() -> void:
    var start := Vector2(CELL) + Vector2(0.3, 0.6)
    for facing in FACINGS:
        var direction := _screen_direction(facing)
        var feet_world := WorldMath.grid_to_world(start)
        var previous := _target(start, facing)
        # Walk two tiles in half-pixel steps.
        for step in 256:
            feet_world += direction * 0.5
            var target := _target(WorldMath.world_to_grid(feet_world), facing)
            var moved := (target - previous).abs()
            assert_true(
                moved.x + moved.y <= 1,
                "walking facing %d jumped %s -> %s" % [facing, previous, target],
            )
            previous = target

func test_walking_a_centre_line_steps_the_target_straight_ahead() -> void:
    # Both probe coordinates cross a cell edge on the same step, so the target
    # jumps to the facing's corner neighbour: the next tile directly ahead,
    # never back and never to a tile beside the path.
    var start := Vector2(CELL) + Vector2(0.5, 0.5)
    for facing in FACINGS:
        var direction := _screen_direction(facing)
        var forward: Vector2i = WorldMath.TARGET_OFFSETS[facing]
        var feet_world := WorldMath.grid_to_world(start)
        var previous := _target(start, facing)
        var visited := [previous]
        for step in 256:
            feet_world += direction * 0.5
            var target := _target(WorldMath.world_to_grid(feet_world), facing)
            var moved := target - previous
            assert_true(
                moved.x in [0, forward.x] and moved.y in [0, forward.y],
                "walking facing %d moved %s -> %s" % [facing, previous, target],
            )
            if target != previous:
                visited.append(target)
            previous = target
        # Two tiles walked: the target passed the own tile and two tiles ahead.
        assert_gte(visited.size(), 3, "facing %d visited %s" % [facing, visited])

func test_a_centred_player_targets_the_facing_corner_neighbour() -> void:
    var centre := Vector2(CELL) + Vector2(0.5, 0.5)
    for facing in FACINGS:
        assert_eq(_target(centre, facing), CELL + WorldMath.TARGET_OFFSETS[facing])
