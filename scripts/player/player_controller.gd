class_name PlayerController
extends CharacterBody2D

const WALK_FPS := 8.0
const WALK_CYCLE := [1, 2, 3, 2]
# Real velocity can dip to zero for a tick or two while the player trades keys
# or grazes a corner. Granting one 8 fps pose of rest grace keeps a direction
# change from flashing idle and restarting the cycle; a genuine stop or a held
# push against a blocker outlasts one pose and still lands on idle.
const WALK_GRACE_SECONDS := 1.0 / WALK_FPS

var facing: WorldMath.Facing = WorldMath.Facing.DOWN
var _input_enabled := true
var _map_size := Vector2i.ZERO
var _walk_seconds := 0.0
var _rest_seconds := WALK_GRACE_SECONDS

@onready var player_sprite: Sprite2D = $Sprite2D
@onready var player_collision: CollisionPolygon2D = $CollisionPolygon2D
@onready var camera: Camera2D = $Camera2D
var target_highlight: Line2D

func _ready() -> void:
    var player_polygon := WorldMath.centered_player_footprint_polygon(Vector2.ZERO)
    var projection_origin := WorldMath.grid_to_world(Vector2.ZERO)
    for index in player_polygon.size():
        player_polygon[index] -= projection_origin
    player_collision.polygon = player_polygon

    _update_visuals()

func enter_map(spawn: Vector2, camera_bounds: Rect2, map_size: Vector2i) -> void:
    _map_size = map_size
    global_position = WorldMath.grid_to_world(spawn)
    velocity = Vector2.ZERO
    facing = WorldMath.Facing.DOWN
    _rest_seconds = WALK_GRACE_SECONDS
    _update_visuals()
    camera.zoom = Vector2.ONE * WorldContract.CAMERA_ZOOM
    camera.limit_left = int(camera_bounds.position.x)
    camera.limit_top = int(camera_bounds.position.y)
    camera.limit_right = int(camera_bounds.position.x + camera_bounds.size.x)
    camera.limit_bottom = int(camera_bounds.position.y + camera_bounds.size.y)
    camera.reset_smoothing()
    _update_target()

func set_input_enabled(enabled: bool) -> void:
    _input_enabled = enabled
    if not enabled:
        velocity = Vector2.ZERO
        _rest_seconds = WALK_GRACE_SECONDS
        _update_visuals()

func current_target_cell() -> Variant:
    return WorldMath.target_cell(WorldMath.world_to_grid(global_position), facing, _map_size)

enum TargetTint { NEUTRAL, VALID, INVALID }

const TARGET_NEUTRAL := Color(1.0, 0.85, 0.2, 0.9)
const TARGET_VALID := Color(0.35, 1.0, 0.45, 0.9)
const TARGET_INVALID := Color(1.0, 0.35, 0.35, 0.9)

func set_target_tint(tint: TargetTint) -> void:
    if target_highlight == null:
        return
    match tint:
        TargetTint.NEUTRAL:
            target_highlight.default_color = TARGET_NEUTRAL
        TargetTint.VALID:
            target_highlight.default_color = TARGET_VALID
        TargetTint.INVALID:
            target_highlight.default_color = TARGET_INVALID

func _physics_process(delta: float) -> void:
    if not _input_enabled:
        velocity = Vector2.ZERO
        _update_target()
        return
    var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    facing = WorldMath.facing_for_input(input_vector, facing)
    velocity = input_vector * WorldContract.MOVE_SPEED
    move_and_slide()
    if get_real_velocity().length() > 1.0:
        _rest_seconds = 0.0
    else:
        _rest_seconds += delta
    _update_visuals(delta, _rest_seconds < WALK_GRACE_SECONDS)
    _update_target()

func _update_visuals(delta: float = 0.0, moving: bool = false) -> void:
    if not moving:
        _walk_seconds = 0.0
        player_sprite.frame = int(facing) * player_sprite.hframes
        return
    var column: int = WALK_CYCLE[int(_walk_seconds * WALK_FPS) % WALK_CYCLE.size()]
    _walk_seconds += delta
    player_sprite.frame = int(facing) * player_sprite.hframes + column

func _update_target() -> void:
    if target_highlight == null:
        return

    var target_cell: Variant = current_target_cell()
    if target_cell == null:
        target_highlight.points = PackedVector2Array()
        target_highlight.visible = false
        return

    target_highlight.points = WorldMath.cell_diamond(target_cell)
    target_highlight.visible = true
