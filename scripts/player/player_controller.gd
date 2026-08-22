class_name PlayerController
extends CharacterBody2D

var facing: WorldMath.Facing = WorldMath.Facing.DOWN

@onready var player_sprite: Sprite2D = $Sprite2D
@onready var player_collision: CollisionPolygon2D = $CollisionPolygon2D
@onready var camera: Camera2D = $Camera2D
var target_highlight: Line2D

func _ready() -> void:
    global_position = WorldMath.grid_to_world(WorldContract.PLAYER_SPAWN)
    var player_polygon := WorldMath.centered_player_footprint_polygon(Vector2.ZERO)
    var projection_origin := WorldMath.grid_to_world(Vector2.ZERO)
    for index in player_polygon.size():
        player_polygon[index] -= projection_origin
    player_collision.polygon = player_polygon

    var bounds := WorldContract.CAMERA_BOUNDS
    camera.limit_left = int(bounds.position.x)
    camera.limit_top = int(bounds.position.y)
    camera.limit_right = int(bounds.position.x + bounds.size.x)
    camera.limit_bottom = int(bounds.position.y + bounds.size.y)

    target_highlight = get_node_or_null("../../TargetHighlight") as Line2D
    _update_visuals()
    _update_target()

func _physics_process(_delta: float) -> void:
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

    var logical_position := WorldMath.world_to_grid(global_position)
    var target_cell: Variant = WorldMath.target_cell(logical_position, facing)
    if target_cell == null:
        target_highlight.points = PackedVector2Array()
        target_highlight.visible = false
        return

    target_highlight.points = WorldMath.cell_diamond(target_cell)
    target_highlight.visible = true
