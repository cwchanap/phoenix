class_name HomesteadAmbience
extends Node2D
## Presentation-only river ripples for the homestead ambience slice.
##
## Direct FarmMap child layered above FarmSoil/FarmActionEffects (z_index 6)
## and below TargetHighlight/Entities. Owns no gameplay state: three looping
## ripple strips driven by bound Tweens, freed with the scene. World-level
## rain moved to RainLayer (scripts/world/rain_layer.gd).

const RIPPLE_TEXTURE: Texture2D = preload("res://assets/sprites/polish/river-ripple.png")
# Ripple anchors sit on the river center-lines owned by WorldContract.
var _ripple_cells: Array[Vector2] = [
    Vector2(WorldContract.RIVER_WEST_FOOTPRINT.get_center().x, 6.5),
    Vector2(WorldContract.RIVER_WEST_FOOTPRINT.get_center().x, 13.0),
    Vector2(6.5, WorldContract.RIVER_SOUTH_FOOTPRINT.get_center().y),
]
# ~2 fps across the three-frame strip.
const RIPPLE_FRAME_SECONDS := 0.5
const RIPPLE_START_STAGGER := 0.17

func _ready() -> void:
    for index in _ripple_cells.size():
        _add_ripple(index)

func _add_ripple(index: int) -> void:
    var ripple := Sprite2D.new()
    ripple.name = "RiverRipple%d" % index
    ripple.texture = RIPPLE_TEXTURE
    ripple.hframes = 3
    ripple.scale = Vector2(1, 1)
    ripple.offset = Vector2.ZERO
    ripple.position = WorldMath.grid_to_world(_ripple_cells[index])
    add_child(ripple)
    var starter := create_tween()
    starter.tween_interval(index * RIPPLE_START_STAGGER)
    starter.tween_callback(_start_ripple_loop.bind(ripple))

func _start_ripple_loop(ripple: Sprite2D) -> void:
    var tween := create_tween().set_loops()
    for frame in [1, 2, 0]:
        tween.tween_callback(_show_frame.bind(ripple, frame)).set_delay(RIPPLE_FRAME_SECONDS)

func _show_frame(ripple: Sprite2D, frame: int) -> void:
    ripple.frame = frame
