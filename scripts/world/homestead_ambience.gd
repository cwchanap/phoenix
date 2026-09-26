class_name HomesteadAmbience
extends Node2D
## Presentation-only river ripples and rain for the homestead ambience slice.
##
## Direct World child layered above FarmSoil/FarmActionEffects (z_index 6)
## and below TargetHighlight/Entities. Owns no gameplay state: three looping
## ripple strips driven by bound Tweens plus deterministic Line2D rain driven
## by render(snapshot)/_process, freed with the scene.

const RAIN_STREAK_COUNT := 72  # Implementation default; tunable after native review.
const RAIN_AREA := Vector2(640.0, 360.0)
const RAIN_VELOCITY := Vector2(-80.0, 320.0)
const RAIN_STREAK_VECTOR := Vector2(-4.0, 16.0)
const RAIN_COLOR := Color(0.85, 0.9, 1.0, 0.35)
const RAIN_SPREAD := Vector2(0.618034, 0.754878)

const RIPPLE_TEXTURE: Texture2D = preload("res://assets/sprites/polish/river-ripple.png")
const RIPPLE_CELLS: Array[Vector2] = [Vector2(1.0, 6.5), Vector2(1.0, 13.0), Vector2(6.5, 19.0)]
const RIPPLE_START_DELAYS: Array[float] = [0.0, 0.17, 0.34]
# ~2 fps across the three-frame strip.
const RIPPLE_FRAME_SECONDS := 0.5

var _camera: Camera2D = null
var _rain_lines: Array[Line2D] = []
var _rain_phase := 0.0
var _rain_falling := false

func _ready() -> void:
    for index in RIPPLE_CELLS.size():
        _add_ripple(index)
    _setup_rain()

func setup(camera: Camera2D) -> void:
    _camera = camera

func render(snapshot: Dictionary) -> void:
    # Keep streaks hidden until setup() supplies a camera; a layout without one
    # would pile every line at the ambience origin.
    _rain_falling = (
        snapshot["weather"] == GameRules.weather_key(GameRules.Weather.RAINY)
        and _camera != null
    )
    for line in _rain_lines:
        line.visible = _rain_falling
    if _rain_falling:
        _layout_rain(_rain_phase)

func _process(delta: float) -> void:
    if not _rain_falling:
        return
    _rain_phase += delta
    _layout_rain(_rain_phase)

func _setup_rain() -> void:
    for index in RAIN_STREAK_COUNT:
        var line := Line2D.new()
        line.name = "RainStreak%d" % index
        line.points = PackedVector2Array([Vector2.ZERO, RAIN_STREAK_VECTOR])
        line.width = 1.0
        line.default_color = RAIN_COLOR
        line.visible = false
        add_child(line)
        _rain_lines.append(line)

func _layout_rain(phase: float) -> void:
    if _camera == null:
        return
    var origin := _camera.get_screen_center_position() - RAIN_AREA * 0.5
    for index in _rain_lines.size():
        var line := _rain_lines[index]
        var offset := Vector2(
            fposmod(float(index) * RAIN_SPREAD.x, 1.0) * RAIN_AREA.x,
            fposmod(float(index) * RAIN_SPREAD.y, 1.0) * RAIN_AREA.y,
        ) + phase * RAIN_VELOCITY
        line.position = origin + Vector2(
            fposmod(offset.x, RAIN_AREA.x),
            fposmod(offset.y, RAIN_AREA.y),
        )

func _add_ripple(index: int) -> void:
    var ripple := Sprite2D.new()
    ripple.name = "RiverRipple%d" % index
    ripple.texture = RIPPLE_TEXTURE
    ripple.hframes = 3
    ripple.scale = Vector2(1, 1)
    ripple.offset = Vector2.ZERO
    ripple.position = WorldMath.grid_to_world(RIPPLE_CELLS[index])
    add_child(ripple)
    var starter := create_tween()
    starter.tween_interval(RIPPLE_START_DELAYS[index])
    starter.tween_callback(_start_ripple_loop.bind(ripple))

func _start_ripple_loop(ripple: Sprite2D) -> void:
    var tween := create_tween().set_loops()
    for frame in [1, 2, 0]:
        tween.tween_callback(_show_frame.bind(ripple, frame)).set_delay(RIPPLE_FRAME_SECONDS)

func _show_frame(ripple: Sprite2D, frame: int) -> void:
    ripple.frame = frame
