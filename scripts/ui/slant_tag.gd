class_name SlantTag
extends PanelContainer
## The mockup's slanted label tag: a parallelogram leaning 12 degrees with
## upright text, filled flat or with a left-to-right gradient.

const LEAN := 0.2126 # tan(12 degrees)

var _colors: Array[Color] = []

func _init(text_value: String = "", fill: Array[Color] = [UiStyle.ACCENT_2], ink: Color = UiStyle.CARD, font_size: int = 15) -> void:
	_colors = fill
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxEmpty.new()
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	add_theme_stylebox_override("panel", box)
	var caption := UiStyle.label(text_value, font_size, ink, 900)
	caption.name = "Text"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(caption)

func _draw() -> void:
	var lean := size.y * LEAN
	var points := PackedVector2Array([
		Vector2(lean, 0.0),
		Vector2(size.x, 0.0),
		Vector2(size.x - lean, size.y),
		Vector2(0.0, size.y),
	])
	if _colors.size() == 1:
		draw_colored_polygon(points, _colors[0])
		return
	var first := _colors[0]
	var last := _colors[_colors.size() - 1]
	draw_polygon(points, PackedColorArray([first, last, last, first]))
