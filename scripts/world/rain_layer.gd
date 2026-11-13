class_name RainLayer
extends Node2D
## Presentation-only world-level rain renderer.
##
## Authored WorldShell child (z_index 6) layered above both maps and below
## TargetHighlight, so it survives every map swap without resetting. Owns no
## gameplay state: deterministic rain drawn as one canvas item via
## _draw()/draw_multiline, freed with the scene.

const RAIN_STREAK_COUNT := 72  # Implementation default; tunable after native review.
const RAIN_VELOCITY := Vector2(-80.0, 320.0)
const RAIN_STREAK_VECTOR := Vector2(-4.0, 16.0)
const RAIN_COLOR := Color(0.85, 0.9, 1.0, 0.35)
const RAIN_SPREAD := Vector2(0.618034, 0.754878)
# Clamp the per-frame advance so a hitch cannot cross a full wrap span.
const RAIN_DELTA_CLAMP := 0.1

var _rain_offsets: Array[Vector2] = []
var _rain_falling := false

func _ready() -> void:
    var span := _rain_span()
    for index in RAIN_STREAK_COUNT:
        _rain_offsets.append(Vector2(
            fposmod(float(index) * RAIN_SPREAD.x, 1.0) * span.x,
            fposmod(float(index) * RAIN_SPREAD.y, 1.0) * span.y,
        ))
    set_process(false)

func render(snapshot: Dictionary) -> void:
    _rain_falling = snapshot["weather"] == GameRules.weather_key(GameRules.Weather.RAINY)
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
    var view_size := _world_view_size()
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
    return _world_view_size() + enter_pad

# The camera's visible world rect, not the 1920x1080 canvas it is zoomed onto.
func _world_view_size() -> Vector2:
    return get_viewport_rect().size / WorldContract.CAMERA_ZOOM
