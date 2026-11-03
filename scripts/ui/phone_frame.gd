class_name PhoneFrame
extends PanelContainer
## The shared City Pop phone chrome (HPA-682): a dark rounded bezel around
## a light screen carrying a status-bar time, one content mount, and a home
## indicator. Code-built like HudChrome; it owns no app navigation, modal
## state, session data, or input — panels own their content.

const PHONE_SIZE := Vector2(560, 920)
const BEZEL := Color("10131a")
const BEZEL_LINE := Color("2b303c")
const SCREEN_RADIUS := 56
const STATUS_HEIGHT := 58
const HOME_HEIGHT := 26
const BOTTOM_MIN_HEIGHT := 112
const NOTCH_SIZE := Vector2(130, 36)
const NOTCH_TOP := 14.0
const BAR_HEIGHTS: Array[float] = [6.0, 9.0, 12.0, 16.0]

var _status_time: Label
var _status_bars: Array[Panel] = []
var _battery_outline: StyleBoxFlat
var _battery_fill: StyleBoxFlat
var _band_gradient: TextureRect
var _app_bar: MarginContainer
var _title: Label
var _title_key := ""
var _jp: Label
var _accessory: HBoxContainer
var _content: VBoxContainer
var _footer: PanelContainer
var _footer_row: HBoxContainer

func _init() -> void:
	name = "PhoneFrame"
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = PHONE_SIZE
	var bezel := UiStyle.card(BEZEL, 68, [14, 14, 14, 14])
	bezel.border_color = BEZEL_LINE
	bezel.set_border_width_all(3)
	add_theme_stylebox_override("panel", bezel)

	var screen := PanelContainer.new()
	screen.name = "Screen"
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.SOFT, SCREEN_RADIUS, [0, 0, 0, 0], false)
	)
	add_child(screen)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	screen.add_child(column)

	var band := PanelContainer.new()
	band.name = "HeaderBand"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band_box := UiStyle.card(Color(1.0, 1.0, 1.0, 0.0), 0, [0, 0, 0, 0], false)
	band_box.corner_radius_top_left = SCREEN_RADIUS
	band_box.corner_radius_top_right = SCREEN_RADIUS
	band.add_theme_stylebox_override("panel", band_box)
	column.add_child(band)
	_band_gradient = UiStyle.gradient_rect(UiStyle.HEADER_GRADIENT)
	_band_gradient.name = "Gradient"
	_band_gradient.visible = false
	band.add_child(_band_gradient)
	var band_column := VBoxContainer.new()
	band_column.name = "Column"
	band_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band_column.add_theme_constant_override("separation", 0)
	band.add_child(band_column)
	band_column.add_child(_status_row())
	band_column.add_child(_app_header_row())

	_content = UiStyle.vbox(0)
	_content.name = "Content"
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_content)

	var bottom := PanelContainer.new()
	bottom.name = "BottomBar"
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.custom_minimum_size = Vector2(0, BOTTOM_MIN_HEIGHT)
	var bottom_box := UiStyle.card(UiStyle.CARD, 0, [0, 0, 0, 0], false)
	bottom_box.border_color = UiStyle.LINE
	bottom_box.border_width_top = 1
	bottom_box.corner_radius_bottom_left = SCREEN_RADIUS
	bottom_box.corner_radius_bottom_right = SCREEN_RADIUS
	bottom.add_theme_stylebox_override("panel", bottom_box)
	column.add_child(bottom)
	var bottom_rows := UiStyle.vbox(0)
	bottom_rows.name = "Rows"
	bottom.add_child(bottom_rows)
	var bottom_spacer := Control.new()
	bottom_spacer.name = "Spacer"
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_rows.add_child(bottom_spacer)

	_footer = PanelContainer.new()
	_footer.name = "Footer"
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.add_theme_stylebox_override(
		"panel", UiStyle.card(Color(1.0, 1.0, 1.0, 0.0), 0, [26, 12, 26, 10], false)
	)
	_footer.visible = false
	bottom_rows.add_child(_footer)
	_footer_row = UiStyle.hbox(14)
	_footer_row.name = "Row"
	_footer.add_child(_footer_row)
	_footer_row.child_entered_tree.connect(func(_node: Node) -> void: _queue_footer_sync())
	_footer_row.child_exiting_tree.connect(func(_node: Node) -> void: _queue_footer_sync())

	var home := PanelContainer.new()
	home.name = "HomeIndicator"
	home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.custom_minimum_size = Vector2(0, HOME_HEIGHT)
	home.add_theme_stylebox_override(
		"panel", UiStyle.card(Color(1.0, 1.0, 1.0, 0.0), 0, [0, 0, 0, 0], false)
	)
	bottom_rows.add_child(home)
	var home_center := CenterContainer.new()
	home_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.add_child(home_center)
	var bar := Panel.new()
	bar.name = "Bar"
	bar.custom_minimum_size = Vector2(160, 6)
	bar.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.LINE, 3, [0, 0, 0, 0], false)
	)
	home_center.add_child(bar)

	var notch := Control.new()
	notch.name = "NotchLayer"
	notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(notch)
	var island := Panel.new()
	island.name = "Island"
	island.mouse_filter = Control.MOUSE_FILTER_IGNORE
	island.custom_minimum_size = NOTCH_SIZE
	island.anchor_left = 0.5
	island.anchor_right = 0.5
	island.offset_left = -NOTCH_SIZE.x / 2.0
	island.offset_right = NOTCH_SIZE.x / 2.0
	island.offset_top = NOTCH_TOP
	island.offset_bottom = NOTCH_TOP + NOTCH_SIZE.y
	island.grow_horizontal = Control.GROW_DIRECTION_BOTH
	island.add_theme_stylebox_override(
		"panel", UiStyle.card(Color.BLACK, 18, [0, 0, 0, 0], false)
	)
	notch.add_child(island)

func _status_row() -> MarginContainer:
	var status := MarginContainer.new()
	status.name = "StatusBar"
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.custom_minimum_size = Vector2(0, STATUS_HEIGHT)
	for side in [["left", 40], ["top", 6], ["right", 40], ["bottom", 0]]:
		status.add_theme_constant_override("margin_" + side[0], side[1])
	var row := UiStyle.hbox(0)
	row.name = "Row"
	status.add_child(row)
	_status_time = UiStyle.label("06:00", 19, UiStyle.INK, 900)
	_status_time.name = "Time"
	_status_time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_status_time)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var sig := UiStyle.hbox(8)
	sig.name = "Signals"
	sig.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sig)
	var bars := UiStyle.hbox(3)
	bars.name = "Bars"
	sig.add_child(bars)
	for index in BAR_HEIGHTS.size():
		var bar := Panel.new()
		bar.name = "Bar_%d" % index
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size = Vector2(4, BAR_HEIGHTS[index])
		bar.size_flags_vertical = Control.SIZE_SHRINK_END
		bar.add_theme_stylebox_override(
			"panel", UiStyle.card(UiStyle.INK, 1, [0, 0, 0, 0], false)
		)
		bars.add_child(bar)
		_status_bars.append(bar)
	var battery := Panel.new()
	battery.name = "Battery"
	battery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battery.custom_minimum_size = Vector2(30, 15)
	battery.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_battery_outline = UiStyle.card(Color(1.0, 1.0, 1.0, 0.0), 5, [0, 0, 0, 0], false)
	_battery_outline.border_color = UiStyle.INK
	_battery_outline.set_border_width_all(2)
	battery.add_theme_stylebox_override("panel", _battery_outline)
	sig.add_child(battery)
	var fill := Panel.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_left = 0.06
	fill.anchor_right = 0.64
	fill.anchor_top = 0.16
	fill.anchor_bottom = 0.84
	_battery_fill = UiStyle.card(UiStyle.INK, 2, [0, 0, 0, 0], false)
	fill.add_theme_stylebox_override("panel", _battery_fill)
	battery.add_child(fill)
	return status

func _app_header_row() -> MarginContainer:
	_app_bar = MarginContainer.new()
	_app_bar.name = "AppBar"
	_app_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["left", 28], ["top", 6], ["right", 28], ["bottom", 18]]:
		_app_bar.add_theme_constant_override("margin_" + side[0], side[1])
	_app_bar.visible = false
	var row := UiStyle.hbox(10)
	row.name = "Row"
	_app_bar.add_child(row)
	var titles := UiStyle.vbox(2)
	titles.name = "Titles"
	row.add_child(titles)
	_jp = UiStyle.label("", 15, Color(1.0, 1.0, 1.0, 0.85), 700)
	_jp.name = "JpSubtitle"
	_jp.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	titles.add_child(_jp)
	_title = UiStyle.label("", 36, UiStyle.CARD, 900)
	_title.name = "AppTitle"
	titles.add_child(_title)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_accessory = UiStyle.hbox(8)
	_accessory.name = "Accessory"
	_accessory.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_accessory)
	return _app_bar

func _queue_footer_sync() -> void:
	call_deferred("_sync_footer_visibility")

func _sync_footer_visibility() -> void:
	_footer.visible = _footer_row.get_child_count() > 0

## The mount panels fill with their app content.
func content_mount() -> VBoxContainer:
	return _content

func footer_mount() -> HBoxContainer:
	return _footer_row

func app_header_accessory() -> HBoxContainer:
	return _accessory

func set_app_header(
	title_text: String,
	jp_text: String,
	gradient: Array[Color] = UiStyle.HEADER_GRADIENT,
) -> void:
	_title_key = title_text
	_title.text = tr(title_text)
	_jp.text = jp_text
	_band_gradient.texture = UiStyle.rounded_gradient_texture(
		gradient,
		Vector2i(int(PHONE_SIZE.x) - 28, 160),
		SCREEN_RADIUS,
		0,
	)
	_band_gradient.visible = true
	_app_bar.visible = true
	set_status_tint(UiStyle.CARD)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _title_key != "":
		_title.text = tr(_title_key)

func set_status_time(time_text: String) -> void:
	_status_time.text = time_text

func status_time_text() -> String:
	return _status_time.text

func set_status_tint(color: Color) -> void:
	_status_time.add_theme_color_override("font_color", color)
	for bar in _status_bars:
		(bar.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = color
	_battery_outline.border_color = color
	_battery_fill.bg_color = color
