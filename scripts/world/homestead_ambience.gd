class_name HomesteadAmbience
extends Node2D
## Presentation-only river ripples for the homestead ambience slice.
##
## Direct World child layered above FarmSoil/FarmActionEffects (z_index 6)
## and below TargetHighlight/Entities. Owns no gameplay state: three looping
## ripple strips driven by bound Tweens, freed with the scene.

const RIPPLE_TEXTURE: Texture2D = preload("res://assets/sprites/polish/river-ripple.png")
const RIPPLE_CELLS: Array[Vector2] = [Vector2(1.0, 6.5), Vector2(1.0, 13.0), Vector2(6.5, 19.0)]
const RIPPLE_START_DELAYS: Array[float] = [0.0, 0.17, 0.34]
# ~2 fps across the three-frame strip.
const RIPPLE_FRAME_SECONDS := 0.5

func _ready() -> void:
    for index in RIPPLE_CELLS.size():
        _add_ripple(index)

func _add_ripple(index: int) -> void:
    var ripple := Sprite2D.new()
    ripple.name = "RiverRipple%d" % index
    ripple.texture = RIPPLE_TEXTURE
    ripple.hframes = 3
    ripple.scale = Vector2(2, 2)
    ripple.offset = Vector2.ZERO
    ripple.position = WorldMath.grid_to_world(RIPPLE_CELLS[index])
    add_child(ripple)
    var tween := create_tween().set_loops()
    tween.tween_interval(RIPPLE_START_DELAYS[index])
    for frame in [1, 2, 0]:
        tween.tween_callback(_show_frame.bind(ripple, frame)).set_delay(RIPPLE_FRAME_SECONDS)

func _show_frame(ripple: Sprite2D, frame: int) -> void:
    ripple.frame = frame
