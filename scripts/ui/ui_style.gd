class_name UiStyle
extends RefCounted

# City Pop design system (HPA-681). Tokens copy the approved 1080p mockup's
# style kit; HPA-682 builds the phone apps and world cards from the same set.
const ACCENT := Color("ff3d7f")
const ACCENT_DEEP := Color("d81f62")
const ACCENT_SOFT := Color("ffe3ee")
const ACCENT_2 := Color("17c3ff")
const INK := Color("23142b")
const INK_MUTED := Color("8b6f86")
const LINE := Color("f4dbe4")
const SOFT := Color("fff3f1")
const CARD := Color("ffffff")
const HUD_CARD := Color(1.0, 1.0, 1.0, 0.95)
const SUN := Color("ffbf1a")
const SUN_INK := Color("2a1a00")
const LEAF := Color("12b673")
const LEAF_LIGHT := Color("5be37f")
const WARN := Color("fff1cf")
const WARN_INK := Color("7a4d00")
const BAD := Color("ff4b4b")
const SHADOW := Color(10.0 / 255.0, 10.0 / 255.0, 30.0 / 255.0, 0.25)
# Widget hues: each HUD piece owns one so the HUD reads as many colours,
# not white cards with pink dots.
const NIGHT := Color("2a1b47")
const VIOLET := Color("8c5cff")
const BLUE := Color("2f7bff")
const ORANGE := Color("ff8a2a")
const MINT := Color("e6fbef")
const MINT_TRACK := Color("c3eed6")
const LEAF_DEEP := Color("0a7f50")
const BAD_SOFT := Color("ffe9e9")
const BAD_TRACK := Color("ffcfcf")
# "Selected" or "do it": one gradient pill per screen.
const ACCENT_GRADIENT: Array[Color] = [ACCENT, Color("ff8a2a")]
const HEADER_GRADIENT: Array[Color] = [ACCENT, Color("ff7a3a"), Color("ffb02e")]
const STAMINA_GRADIENT: Array[Color] = [LEAF_LIGHT, LEAF]
const FIELDWORK_GRADIENT: Array[Color] = [ACCENT_2, VIOLET]
const PILL_RADIUS := 999

# Legacy dark palette, still used by the 640x360 modal panels until HPA-682
# rebuilds them. Delete with those panels.

# One UI face: M PLUS 1 covers Latin, kana, and common kanji. Its import
# settings exclude `zh`, as do Noto Sans JP's, so Traditional Chinese text
# falls through to Noto Sans TC; Noto Sans JP backs up rare Japanese kanji.
const M_PLUS_1: Font = preload("res://assets/ui/fonts/m-plus-1-variable.ttf")
const NOTO_SANS_JP: Font = preload("res://assets/ui/fonts/noto-sans-jp-variable.ttf")
const NOTO_SANS_TC: Font = preload("res://assets/ui/fonts/noto-sans-tc-variable.ttf")

## `mono` is kept for the legacy panels' call sites; M PLUS 1 digits are
## already tabular, so it no longer changes the face.
static func font(weight: int = 400) -> FontVariation:
	var variation := _weighted(M_PLUS_1, weight)
	variation.fallbacks = [_weighted(NOTO_SANS_JP, weight), _weighted(NOTO_SANS_TC, weight)]
	return variation

static func _weighted(base: Font, weight: int) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {
		TextServerManager.get_primary_interface().name_to_tag("wght"): float(weight),
	}
	return variation

static func text(control: Control, size: int = 10, color: Color = INK, weight: int = 400) -> void:
	control.add_theme_font_override("font", font(weight))
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", color)
	control.add_theme_color_override("font_hover_color", color)
	control.add_theme_color_override("font_pressed_color", color)
	control.add_theme_color_override("font_focus_color", color)

## A styled Label; `text` is auto-translated like any Control text.
static func label(text_value: String = "", size: int = 22, color: Color = INK, weight: int = 800) -> Label:
	var result := Label.new()
	result.text = text_value
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text(result, size, color, weight)
	return result

## Rounded card or pill. Padding is [left, top, right, bottom].
static func card(
	fill: Color = HUD_CARD,
	radius: int = 22,
	padding: Array = [0, 0, 0, 0],
	shadow: bool = true,
) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.set_corner_radius_all(radius)
	result.corner_detail = 8
	result.anti_aliasing = true
	result.content_margin_left = padding[0]
	result.content_margin_top = padding[1]
	result.content_margin_right = padding[2]
	result.content_margin_bottom = padding[3]
	if shadow:
		result.shadow_color = SHADOW
		result.shadow_size = 14
		result.shadow_offset = Vector2(0, 8)
	return result

## Adds a solid border to a card() stylebox and returns it.
static func outlined(box: StyleBoxFlat, color: Color, width: int = 3) -> StyleBoxFlat:
	box.border_color = color
	box.set_border_width_all(width)
	return box

## A left-to-right gradient strip with evenly spaced stops.
static func gradient_texture(colors: Array[Color]) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(colors)
	var offsets := PackedFloat32Array()
	for index in colors.size():
		offsets.append(float(index) / float(maxi(colors.size() - 1, 1)))
	gradient.offsets = offsets
	var result := GradientTexture2D.new()
	result.gradient = gradient
	result.width = 256
	result.height = 1
	return result

## A TextureRect that stretches a gradient over its whole rect.
static func gradient_rect(colors: Array[Color], min_size: Vector2 = Vector2.ZERO) -> TextureRect:
	var result := TextureRect.new()
	result.texture = gradient_texture(colors)
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_SCALE
	result.custom_minimum_size = min_size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func rounded_gradient_texture(
	colors: Array[Color],
	size: Vector2i,
	radius_top: int,
	radius_bottom: int = -1,
	vertical: bool = false,
) -> ImageTexture:
	if radius_bottom < 0:
		radius_bottom = radius_top
	var stops := Gradient.new()
	var offsets := PackedFloat32Array()
	for index in colors.size():
		offsets.append(float(index) / float(colors.size() - 1))
	stops.offsets = offsets
	stops.colors = PackedColorArray(colors)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var span := maxf(1.0, float((size.y if vertical else size.x) - 1))
	var steps := size.y if vertical else size.x
	for step in steps:
		var color := stops.sample(float(step) / span)
		if vertical:
			image.fill_rect(Rect2i(0, step, size.x, 1), color)
		else:
			image.fill_rect(Rect2i(step, 0, 1, size.y), color)
	apply_rounded_mask(image, radius_top, radius_bottom)
	return ImageTexture.create_from_image(image)

static func apply_rounded_mask(
	image: Image, radius_top: int, radius_bottom: int = -1
) -> void:
	if radius_bottom < 0:
		radius_bottom = radius_top
	var size := image.get_size()
	for y in image.get_height():
		if y >= radius_top and y < size.y - radius_bottom:
			continue
		for x in image.get_width():
			var alpha := _rounded_coverage(x, y, size, radius_top, radius_bottom)
			if alpha < 1.0:
				var pixel := image.get_pixel(x, y)
				pixel.a *= alpha
				image.set_pixel(x, y, pixel)

static func _rounded_coverage(
	x: int, y: int, size: Vector2i, radius_top: int, radius_bottom: int
) -> float:
	var center := Vector2.ZERO
	var radius := 0.0
	if y < radius_top:
		radius = radius_top
		center.y = radius_top
		if x < radius_top:
			center.x = radius_top
		elif x >= size.x - radius_top:
			center.x = size.x - radius_top
		else:
			return 1.0
	elif y >= size.y - radius_bottom:
		radius = radius_bottom
		center.y = size.y - radius_bottom
		if x < radius_bottom:
			center.x = radius_bottom
		elif x >= size.x - radius_bottom:
			center.x = size.x - radius_bottom
		else:
			return 1.0
	else:
		return 1.0
	var distance := Vector2(x + 0.5 - center.x, y + 0.5 - center.y).length()
	return clampf(radius - distance + 0.5, 0.0, 1.0)

static func state_pip(size: Vector2, radius: int = 4) -> Control:
	var pip := Control.new()
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.custom_minimum_size = size
	var off := Panel.new()
	off.name = "Off"
	off.mouse_filter = Control.MOUSE_FILTER_IGNORE
	off.set_anchors_preset(Control.PRESET_FULL_RECT)
	off.add_theme_stylebox_override(
		"panel", card(LINE, radius, [0, 0, 0, 0], false)
	)
	pip.add_child(off)
	var on := TextureRect.new()
	on.name = "On"
	on.mouse_filter = Control.MOUSE_FILTER_IGNORE
	on.texture = rounded_gradient_texture(
		ACCENT_GRADIENT, Vector2i(int(size.x), int(size.y)), radius
	)
	on.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	on.stretch_mode = TextureRect.STRETCH_SCALE
	on.set_anchors_preset(Control.PRESET_FULL_RECT)
	pip.add_child(on)
	return pip

## A rounded container filled with a gradient: the rounded box masks a
## gradient child, so gradients keep their corners without image assets.
## Add content as further children; they stack over the gradient.
static func gradient_surface(colors: Array[Color], radius: int = PILL_RADIUS, padding: Array = [0, 0, 0, 0]) -> PanelContainer:
	var result := PanelContainer.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_stylebox_override("panel", card(CARD, radius, padding, false))
	result.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var fill := gradient_rect(colors)
	fill.name = "Gradient"
	result.add_child(fill)
	# After the container fits its children inside the padding, stretch the
	# fill back over the whole rect so it reaches the rounded edge.
	result.sort_children.connect(func() -> void:
		fill.position = Vector2.ZERO
		fill.size = result.size
	)
	return result

## A keycap: white with a heavier bottom edge, the accent gradient, or a
## solid `tint` with a darker bottom edge.
static func keycap(key_text: String, small: bool = false, accent: bool = false, tint := Color.TRANSPARENT) -> PanelContainer:
	var height := 30 if small else 38
	var side := 7 if small else 10
	var radius := 8 if small else 10
	var result: PanelContainer
	if accent:
		result = gradient_surface(ACCENT_GRADIENT, radius, [side, 0, side, 0])
	else:
		var tinted := tint.a > 0.0
		result = PanelContainer.new()
		var box := card(tint if tinted else CARD, radius, [side, 0, side, 0], false)
		box.border_color = tint.darkened(0.25) if tinted else LINE
		box.set_border_width_all(0 if tinted else 2)
		box.border_width_bottom = 4
		result.add_theme_stylebox_override("panel", box)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.custom_minimum_size = Vector2(height, height)
	var light := accent or tint.a > 0.0
	var caption := label(key_text, 14 if small else 17, CARD if light else INK, 800)
	caption.name = "Key"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.add_child(caption)
	return result

## An icon TextureRect at integer scale with nearest filtering.
static func icon(texture: Texture2D, size: int = 32) -> TextureRect:
	var result := TextureRect.new()
	result.texture = texture
	result.custom_minimum_size = Vector2(size, size)
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func hbox(separation: int) -> HBoxContainer:
	var result := HBoxContainer.new()
	result.add_theme_constant_override("separation", separation)
	result.alignment = BoxContainer.ALIGNMENT_BEGIN
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func vbox(separation: int) -> VBoxContainer:
	var result := VBoxContainer.new()
	result.add_theme_constant_override("separation", separation)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func action_button(text_value: String) -> Button:
	var result := Button.new()
	result.text = text_value
	result.custom_minimum_size = Vector2(220, 54)
	result.focus_mode = Control.FOCUS_NONE
	text(result, 20, CARD, 900)
	var normal := card(ACCENT, 16, [0, 0, 0, 0])
	normal.border_color = ACCENT_DEEP
	normal.border_width_bottom = 4
	var hover := card(ACCENT.lightened(0.08), 16, [0, 0, 0, 0])
	hover.border_color = ACCENT_DEEP
	hover.border_width_bottom = 4
	result.add_theme_stylebox_override("normal", normal)
	result.add_theme_stylebox_override("hover", hover)
	result.add_theme_stylebox_override("pressed", card(ACCENT_DEEP, 16, [0, 0, 0, 0]))
	result.add_theme_stylebox_override("focus", normal)
	result.add_theme_stylebox_override("disabled", card(INK_MUTED, 16, [0, 0, 0, 0]))
	return result

static func stepper_button(text_value: String) -> Button:
	var result := Button.new()
	result.text = text_value
	result.custom_minimum_size = Vector2(42, 42)
	result.focus_mode = Control.FOCUS_NONE
	text(result, 22, INK, 800)
	result.add_theme_stylebox_override(
		"normal",
		outlined(card(CARD, 10, [0, 0, 0, 0], false), LINE, 1),
	)
	result.add_theme_stylebox_override(
		"hover",
		outlined(card(ACCENT_SOFT, 10, [0, 0, 0, 0], false), ACCENT, 1),
	)
	result.add_theme_stylebox_override(
		"pressed",
		outlined(card(ACCENT_SOFT, 10, [0, 0, 0, 0], false), ACCENT, 2),
	)
	result.add_theme_stylebox_override(
		"focus",
		outlined(card(CARD, 10, [0, 0, 0, 0], false), ACCENT, 2),
	)
	result.add_theme_stylebox_override(
		"disabled",
		outlined(card(SOFT, 10, [0, 0, 0, 0], false), LINE, 1),
	)
	result.add_theme_color_override("font_disabled_color", INK_MUTED)
	return result

static func max_button(caption_text: String) -> Button:
	var result := Button.new()
	result.name = "Max"
	result.custom_minimum_size = Vector2(88, 42)
	result.focus_mode = Control.FOCUS_NONE
	result.add_theme_stylebox_override(
		"normal",
		outlined(card(CARD, 10, [0, 0, 0, 0], false), LINE, 1),
	)
	result.add_theme_stylebox_override(
		"hover",
		outlined(card(ACCENT_SOFT, 10, [0, 0, 0, 0], false), ACCENT, 1),
	)
	result.add_theme_stylebox_override(
		"pressed",
		outlined(card(ACCENT_SOFT, 10, [0, 0, 0, 0], false), ACCENT, 2),
	)
	result.add_theme_stylebox_override(
		"focus",
		outlined(card(CARD, 10, [0, 0, 0, 0], false), ACCENT, 2),
	)
	result.add_theme_stylebox_override(
		"disabled",
		outlined(card(SOFT, 10, [0, 0, 0, 0], false), LINE, 1),
	)
	var row := hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	result.add_child(row)
	var cap := keycap("M", true)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	var caption := label(caption_text, 14, INK_MUTED, 800)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	return result

static func gradient_band(
	colors: Array[Color], radius: int, padding: Array = [0, 0, 0, 0]
) -> PanelContainer:
	var band := PanelContainer.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := card(Color(1.0, 1.0, 1.0, 0.0), 0, padding, false)
	band.add_theme_stylebox_override("panel", box)
	var fill := TextureRect.new()
	fill.name = "Gradient"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	band.add_child(fill)
	band.sort_children.connect(func() -> void:
		fill.position = Vector2.ZERO
		fill.size = band.size
		var pixels := Vector2i(
			maxi(2, int(band.size.x)), maxi(2, int(band.size.y))
		)
		if fill.texture == null or fill.texture.get_size() != Vector2(pixels):
			fill.texture = rounded_gradient_texture(colors, pixels, radius, 0)
	)
	return band

static func commerce_footer(max_hint: String = "max") -> HBoxContainer:
	var footer := hbox(20)
	footer.name = "Footer"
	var caps := hbox(4)
	caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for key in ["W", "S"]:
		caps.add_child(keycap(key, true))
	footer.add_child(caps)
	var choose := label("choose crop", 17, INK_MUTED, 800)
	choose.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(choose)
	var adjust_caps := hbox(4)
	adjust_caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for key in ["A", "D"]:
		adjust_caps.add_child(keycap(key, true))
	footer.add_child(adjust_caps)
	var quantity_hint := label("quantity", 17, INK_MUTED, 800)
	quantity_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(quantity_hint)
	var max_cap := keycap("M", true)
	max_cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(max_cap)
	var max_label := label(max_hint, 17, INK_MUTED, 800)
	max_label.name = "MaxHint"
	max_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(max_label)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var escape := keycap("Esc", true)
	escape.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(escape)
	var leave := label("leave", 17, INK_MUTED, 800)
	leave.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(leave)
	var pill := gradient_surface(ACCENT_GRADIENT, PILL_RADIUS, [8, 7, 24, 7])
	pill.name = "Pill"
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pill_row := hbox(12)
	pill_row.name = "Row"
	pill_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.add_child(pill_row)
	var enter := keycap("Enter", true)
	enter.name = "Enter"
	enter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill_row.add_child(enter)
	var action := label("", 20, CARD, 900)
	action.name = "Text"
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill_row.add_child(action)
	var action_button := hit_button(pill)
	action_button.name = "Action"
	action_button.focus_mode = Control.FOCUS_CLICK
	action_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(action_button)
	return footer

static func wallpaper_texture(
	source: Texture2D,
	size: Vector2i,
	corner_radius: int,
	dim_top := Color(0.0, 0.0, 0.0, 0.0),
	dim_bottom := Color(0.0, 0.0, 0.0, 0.0),
) -> Texture2D:
	if source == null or size.x < 2 or size.y < 2:
		return null
	var source_size := source.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return null
	var cover := maxf(size.x / source_size.x, size.y / source_size.y)
	var scaled := Vector2i(
		maxi(1, int(ceil(source_size.x * cover))),
		maxi(1, int(ceil(source_size.y * cover)))
	)
	var image := source.get_image()
	image.resize(scaled.x, scaled.y, Image.INTERPOLATE_NEAREST)
	image.convert(Image.FORMAT_RGBA8)
	var composed := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	composed.blit_rect(
		image,
		Rect2i((scaled - size) / 2, size),
		Vector2i.ZERO,
	)
	var span := float(maxi(size.y - 1, 1))
	if dim_top != dim_bottom:
		var veil := Image.create(size.x, 1, false, Image.FORMAT_RGBA8)
		for y in size.y:
			veil.fill(dim_top.lerp(dim_bottom, float(y) / span))
			composed.blend_rect(veil, Rect2i(0, 0, size.x, 1), Vector2i(0, y))
	elif dim_top.a > 0.0:
		var veil := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		veil.fill(dim_top)
		composed.blend_rect(veil, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	apply_rounded_mask(composed, corner_radius)
	return ImageTexture.create_from_image(composed)

static func translucent_keycap(key_text: String) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.name = "Key"
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.custom_minimum_size = Vector2(38, 38)
	var cap_box := card(Color(1.0, 1.0, 1.0, 0.22), 10, [10, 0, 10, 0], false)
	cap_box.border_color = Color(1.0, 1.0, 1.0, 0.45)
	cap_box.set_border_width_all(1)
	cap.add_theme_stylebox_override("panel", cap_box)
	var cap_label := label(key_text, 15, CARD, 800)
	cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_child(cap_label)
	return cap

static func primary_action_pill(key_text: String, caption: String) -> PanelContainer:
	var pill := gradient_surface(ACCENT_GRADIENT, PILL_RADIUS, [8, 7, 24, 7])
	pill.name = "Pill"
	var row := hbox(12)
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(row)
	row.add_child(translucent_keycap(key_text))
	var text := label(caption, 22, CARD, 900)
	text.name = "Text"
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	return pill

static func hit_button(child: Control, floor_size: Vector2 = Vector2.ZERO) -> Button:
	return _pill_button(child, floor_size)

static func _pill_button(pill: Control, floor_size: Vector2 = Vector2(200, 52)) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	pill.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(pill)
	var button_ref: WeakRef = weakref(button)
	var pill_ref: WeakRef = weakref(pill)
	var sync_hitbox := func() -> void:
		var b := button_ref.get_ref() as Button
		var p := pill_ref.get_ref() as Control
		if b == null or p == null:
			return
		b.custom_minimum_size = floor_size.max(p.get_combined_minimum_size())
	pill.minimum_size_changed.connect(sync_hitbox)
	sync_hitbox.call()
	sync_hitbox.call_deferred()
	button.button_down.connect(
		func() -> void: pill.self_modulate = Color(0.88, 0.88, 0.88)
	)
	button.button_up.connect(func() -> void: pill.self_modulate = Color.WHITE)
	return button

static func primary_action(key_text: String, caption: String) -> Button:
	return _pill_button(primary_action_pill(key_text, caption))

static func ghost_action_pill(key_text: String, caption: String) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.name = "Pill"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override(
		"panel", card(CARD, PILL_RADIUS, [8, 7, 22, 7])
	)
	var row := hbox(12)
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(row)
	var cap := keycap(key_text, true)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	var text := label(caption, 20, INK, 900)
	text.name = "Text"
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	return pill

static func ghost_action(key_text: String, caption: String) -> Button:
	return _pill_button(ghost_action_pill(key_text, caption), Vector2(160, 52))

static func vn_card() -> Control:
	var box := MarginContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_panel := PanelContainer.new()
	card_panel.name = "Card"
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var card_box := card(CARD, 30, [0, 0, 0, 0])
	card_box.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	card_box.shadow_size = 30
	card_box.shadow_offset = Vector2(0, 24)
	card_panel.add_theme_stylebox_override("panel", card_box)
	box.add_child(card_panel)
	var column := vbox(0)
	column.name = "Column"
	card_panel.add_child(column)
	var band := gradient_band(HEADER_GRADIENT, 30)
	band.name = "Band"
	band.custom_minimum_size = Vector2(0, 8)
	column.add_child(band)
	var body := MarginContainer.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["left", 48], ["top", 38], ["right", 48], ["bottom", 22]]:
		body.add_theme_constant_override("margin_" + side[0], side[1])
	column.add_child(body)
	var content := vbox(16)
	content.name = "Content"
	body.add_child(content)
	var overlay := Control.new()
	overlay.name = "Overlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(overlay)
	return box

static func vn_dock(bottom_margin: float, side_margin: float = 120.0) -> VBoxContainer:
	var dock := VBoxContainer.new()
	dock.name = "Dock"
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.alignment = BoxContainer.ALIGNMENT_END
	dock.add_theme_constant_override("separation", 0)
	dock.set_anchors_preset(Control.PRESET_FULL_RECT)
	var edge := MarginContainer.new()
	edge.name = "Edge"
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.add_theme_constant_override("margin_left", int(side_margin))
	edge.add_theme_constant_override("margin_top", 0)
	edge.add_theme_constant_override("margin_right", int(side_margin))
	edge.add_theme_constant_override("margin_bottom", int(bottom_margin))
	dock.add_child(edge)
	edge.add_child(vn_card())
	return dock

## HPA-680 stopgap: the title, result, intro, and modal panels are still
## authored for the old 640x360 canvas. Pin them to that size and draw them 3x
## so they fill the 1920x1080 base viewport until HPA-682 rebuilds them
## natively; delete these helpers and their call sites then.
## Scales one control authored in 640x360 coordinates (its offsets included)
## onto the 1920x1080 canvas.
# Rasterize glyphs at the scaled size so the 3x text stays sharp.

## Pins a control to a screen corner with a margin; it grows inward as its
## content changes size. `corner` uses Godot's Corner enum.
static func pin(control: Control, corner: Corner, margin: Vector2) -> void:
	var right := corner == CORNER_TOP_RIGHT or corner == CORNER_BOTTOM_RIGHT
	var bottom := corner == CORNER_BOTTOM_LEFT or corner == CORNER_BOTTOM_RIGHT
	control.anchor_left = 1.0 if right else 0.0
	control.anchor_right = control.anchor_left
	control.anchor_top = 1.0 if bottom else 0.0
	control.anchor_bottom = control.anchor_top
	control.offset_left = -margin.x if right else margin.x
	control.offset_right = control.offset_left
	control.offset_top = -margin.y if bottom else margin.y
	control.offset_bottom = control.offset_top
	control.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
	control.grow_vertical = Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END
