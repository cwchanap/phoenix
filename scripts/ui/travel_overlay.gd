class_name TravelOverlay
extends Control

signal finished

const TRUCK_SHEET := preload("res://assets/sprites/kei-truck.png")
const CLOCK_ICON := preload("res://assets/ui/icons/clock.png")
const FADE_SECONDS := 0.25
const HOLD_SECONDS := 1.0
const FINISH_STEP_SECONDS := 0.5
const FINISH_MAX_STEPS := 16

var _tween: Tween
var _title: Label
var _departure: Label
var _arrival: Label
var _duration: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false

func is_active() -> bool:
	return visible

func play(before: Dictionary, after: Dictionary, swap: Callable) -> void:
	var to_town := int(after["location"]) == GameRules.MapId.TOWN
	_title.text = tr("Driving to town") if to_town else tr("Driving home")
	_departure.text = GameRules.format_time(int(before["time_minutes"]))
	_arrival.text = GameRules.format_time(int(after["time_minutes"]))
	_duration.text = tr("+%d min") % GameRules.TRAVEL_MINUTES
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	_tween.tween_callback(swap)
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(_on_beat_finished)

func finish() -> void:
	var steps := 0
	while (
		is_active()
		and _tween != null
		and _tween.is_valid()
		and steps < FINISH_MAX_STEPS
	):
		_tween.custom_step(FINISH_STEP_SECONDS)
		steps += 1

func _on_beat_finished() -> void:
	visible = false
	finished.emit()

func _build() -> void:
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0.04, 0.03, 0.08, 0.8)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := UiStyle.vbox(16)
	column.name = "Column"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)
	column.add_child(_road())
	_title = UiStyle.label("Driving to town", 46, UiStyle.CARD, 900)
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_title)
	column.add_child(_time_pill())
	_duration = UiStyle.label("+30 min", 20, Color(1.0, 1.0, 1.0, 0.85), 800)
	_duration.name = "Duration"
	_duration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_duration.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_duration)

func _road() -> Control:
	var road := Control.new()
	road.name = "Road"
	road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	road.custom_minimum_size = Vector2(880, 176)
	var dashes := UiStyle.hbox(30)
	dashes.name = "Dashes"
	dashes.alignment = BoxContainer.ALIGNMENT_CENTER
	dashes.anchor_left = 0.0
	dashes.anchor_right = 1.0
	dashes.anchor_top = 1.0
	dashes.anchor_bottom = 1.0
	dashes.offset_top = -10.0
	dashes.offset_bottom = -10.0
	dashes.grow_vertical = Control.GROW_DIRECTION_BEGIN
	road.add_child(dashes)
	for index in 12:
		var dash := ColorRect.new()
		dash.name = "Dash%d" % index
		dash.color = Color(1.0, 1.0, 1.0, 0.9)
		dash.custom_minimum_size = Vector2(42, 6)
		dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dashes.add_child(dash)
	var atlas := AtlasTexture.new()
	atlas.atlas = TRUCK_SHEET
	atlas.region = Rect2(0, 0, 96, 96)
	var truck := TextureRect.new()
	truck.name = "Truck"
	truck.texture = atlas
	truck.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	truck.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	truck.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	truck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	truck.anchor_left = 0.5
	truck.anchor_right = 0.5
	truck.anchor_top = 0.0
	truck.anchor_bottom = 0.0
	truck.offset_left = -84.0
	truck.offset_right = 84.0
	truck.offset_top = -10.0
	truck.offset_bottom = 158.0
	road.add_child(truck)
	return road

func _time_pill() -> PanelContainer:
	var pill := PanelContainer.new()
	pill.name = "TimePill"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override(
		"panel",
		UiStyle.card(
			Color(0.10, 0.07, 0.16, 0.95),
			UiStyle.PILL_RADIUS,
			[24, 9, 24, 9],
			false,
		),
	)
	var row := UiStyle.hbox(12)
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(row)
	var clock := UiStyle.icon(CLOCK_ICON, 26)
	clock.name = "ClockIcon"
	clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(clock)
	_departure = UiStyle.label("00:00", 26, UiStyle.CARD, 800)
	_departure.name = "Departure"
	_departure.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_departure)
	var arrow := UiStyle.label("→", 24, Color(1.0, 1.0, 1.0, 0.7), 800)
	arrow.name = "Arrow"
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrow)
	_arrival = UiStyle.label("00:00", 26, UiStyle.SUN, 800)
	_arrival.name = "Arrival"
	_arrival.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_arrival)
	return pill
