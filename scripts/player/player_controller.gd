class_name PlayerController
extends CharacterBody2D

var facing: WorldMath.Facing = WorldMath.Facing.DOWN
var _input_enabled := true

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
    _update_target()

## WorldShell calls this once per map load with the active map's placement
## values; target_highlight must already be bound so the target updates
## immediately instead of waiting for the first physics tick.
func enter_map(spawn: Vector2, camera_bounds: Rect2) -> void:
    global_position = WorldMath.grid_to_world(spawn)
    camera.zoom = Vector2.ONE * WorldContract.CAMERA_ZOOM
    camera.limit_left = int(camera_bounds.position.x)
    camera.limit_top = int(camera_bounds.position.y)
    camera.limit_right = int(camera_bounds.position.x + camera_bounds.size.x)
    camera.limit_bottom = int(camera_bounds.position.y + camera_bounds.size.y)
    _update_target()

func set_input_enabled(enabled: bool) -> void:
    _input_enabled = enabled
    if not enabled:
        velocity = Vector2.ZERO

func current_target_cell() -> Variant:
    return WorldMath.target_cell(WorldMath.world_to_grid(global_position), facing)

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

func _physics_process(_delta: float) -> void:
    if not _input_enabled:
        velocity = Vector2.ZERO
        _update_target()
        return
    var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    facing = WorldMath.facing_for_input(input_vector, facing)
    velocity = input_vector * WorldContract.MOVE_SPEED
    move_and_slide()
    _update_visuals()
    _update_target()

func _update_visuals() -> void:
    player_sprite.frame = int(facing)

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
