class_name HomesteadAmbience
extends Node2D
## Presentation-only river ripples and rain for the homestead ambience slice.
##
## Direct World child layered above FarmSoil/FarmActionEffects (z_index 6)
## and below TargetHighlight/Entities. Owns no gameplay state: three looping
## ripple strips driven by bound Tweens plus deterministic rain drawn as one
## canvas item via _draw()/draw_multiline, freed with the scene.

const RAIN_STREAK_COUNT := 72  # Implementation default; tunable after native review.
const RAIN_VELOCITY := Vector2(-80.0, 320.0)
const RAIN_STREAK_VECTOR := Vector2(-4.0, 16.0)
const RAIN_COLOR := Color(0.85, 0.9, 1.0, 0.35)
const RAIN_SPREAD := Vector2(0.618034, 0.754878)
# Clamp the per-frame advance so a hitch cannot cross a full wrap span.
const RAIN_DELTA_CLAMP := 0.1

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

var _rain_offsets: Array[Vector2] = []
var _rain_falling := false

func _ready() -> void:
    var span := _rain_span()
    for index in RAIN_STREAK_COUNT:
        _rain_offsets.append(Vector2(
            fposmod(float(index) * RAIN_SPREAD.x, 1.0) * span.x,
            fposmod(float(index) * RAIN_SPREAD.y, 1.0) * span.y,
        ))
    for index in _ripple_cells.size():
        _add_ripple(index)
    set_process(false)

func render(snapshot: Dictionary) -> void:
    _rain_falling = GameRules.is_rainy(snapshot["weather"])
    set_process(_rain_falling)
    queue_redraw()

func is_rain_falling() -> bool:
    return _rain_falling

func _process(delta: float) -> void:
    var span := _rain_span()
    var step := RAIN_VELOCITY * minf(delta, RAIN_DELTA_CLAMP)
    for index in _rain_offsets.size():
        var offset := _rain_offsets[index] + step
        # Exact carry (not modulo) keeps the advance continuous through the
        # wrap, so streaks slide in and out instead of popping at the edges.
        if offset.x < 0.0:
            offset.x += span.x
        if offset.y >= span.y:
            offset.y -= span.y
        _rain_offsets[index] = offset
    queue_redraw()

func _draw() -> void:
    if not _rain_falling:
        return
    # Draw-time read: rendering happens after the smoothed Camera2D has
    # applied this frame's scroll, so rain never lags the camera regardless
    # of scene-tree order.
    var camera := get_viewport().get_camera_2d()
    if camera == null:
        return
    var view_size := get_viewport_rect().size
    # The wrap domain is the view padded by the streak extent on the entry
    # sides (right for x, top for y), so carried-in streaks start offscreen.
    var enter_pad := Vector2(abs(RAIN_STREAK_VECTOR.x), abs(RAIN_STREAK_VECTOR.y))
    var view_top_left := camera.get_screen_center_position() - view_size * 0.5
    var origin := Vector2(view_top_left.x, view_top_left.y - enter_pad.y)
    var points := PackedVector2Array()
    points.resize(_rain_offsets.size() * 2)
    for index in _rain_offsets.size():
        var head := origin + _rain_offsets[index]
        points[index * 2] = head
        points[index * 2 + 1] = head + RAIN_STREAK_VECTOR
    draw_multiline(points, RAIN_COLOR, 1.0)

func _rain_span() -> Vector2:
    var enter_pad := Vector2(abs(RAIN_STREAK_VECTOR.x), abs(RAIN_STREAK_VECTOR.y))
    return get_viewport_rect().size + enter_pad

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
