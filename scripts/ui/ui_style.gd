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
const PRIMARY := Color("141a24")
const HEADER := Color("1d2634")
const INSET := Color("0e131b")
const BORDER := Color("2a3547")
const BORDER_LIGHT := Color("6b7a94")
const FRAME_BORDER := Color("38465e")
const KEYCAP_FILL := Color("3a2f0f")
const WARNING_FILL := Color("241f0e")
const GOLD := Color("ffe673")
const CREAM := Color("fff5db")
const MUTED := Color("8a94a6")
const TEXT := Color("c6d0e0")
const GREEN := Color("7fbf5f")
const RED := Color("d4574e")

# One UI face: M PLUS 1 covers Latin, kana, and common kanji. Its import
# settings exclude `zh`, as do Noto Sans JP's, so Traditional Chinese text
# falls through to Noto Sans TC; Noto Sans JP backs up rare Japanese kanji.
const M_PLUS_1: Font = preload("res://assets/ui/fonts/m-plus-1-variable.ttf")
const NOTO_SANS_JP: Font = preload("res://assets/ui/fonts/noto-sans-jp-variable.ttf")
const NOTO_SANS_TC: Font = preload("res://assets/ui/fonts/noto-sans-tc-variable.ttf")

## `mono` is kept for the legacy panels' call sites; M PLUS 1 digits are
## already tabular, so it no longer changes the face.
static func font(weight: int = 400, _mono: bool = false) -> FontVariation:
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

static func text(control: Control, size: int = 10, color: Color = TEXT, weight: int = 400, mono: bool = false) -> void:
	control.add_theme_font_override("font", font(weight, mono))
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

static func panel(fill: Color = PRIMARY, border: Color = BORDER, width: int = 1) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(width)
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

static func button(control: Button, size: int = 10, selected: bool = false) -> void:
	text(control, size, GOLD if selected else TEXT, 700, false)
	control.add_theme_stylebox_override("normal", panel(INSET, GOLD if selected else BORDER, 1))
	control.add_theme_stylebox_override("hover", panel(HEADER, BORDER_LIGHT, 1))
	control.add_theme_stylebox_override("pressed", panel(HEADER, GOLD, 1))
	control.add_theme_stylebox_override("focus", panel(INSET, GOLD, 1))
	control.add_theme_stylebox_override("disabled", panel(INSET, BORDER, 1))
	control.add_theme_color_override("font_disabled_color", MUTED)
	control.focus_mode = Control.FOCUS_NONE

## HPA-680 stopgap: the title, result, intro, and modal panels are still
## authored for the old 640x360 canvas. Pin them to that size and draw them 3x
## so they fill the 1920x1080 base viewport until HPA-682 rebuilds them
## natively; delete these helpers and their call sites then.
const LEGACY_LAYOUT_SIZE := Vector2(640, 360)

static func fit_legacy_layout(root: Control) -> void:
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.position = Vector2.ZERO
	root.size = LEGACY_LAYOUT_SIZE
	fit_legacy_control(root)

## Scales one control authored in 640x360 coordinates (its offsets included)
## onto the 1920x1080 canvas.
static func fit_legacy_control(control: Control) -> void:
	var factor := float(UiSettings.WINDOW_SIZE.x) / LEGACY_LAYOUT_SIZE.x
	control.position *= factor
	control.scale = Vector2.ONE * factor
	# Rasterize glyphs at the scaled size so the 3x text stays sharp.
	control.oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED

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
