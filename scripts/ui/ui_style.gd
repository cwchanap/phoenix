class_name UiStyle
extends RefCounted

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

const OPEN_SANS: Font = preload("res://assets/ui/fonts/open-sans-variable.ttf")
const JETBRAINS_MONO: Font = preload("res://assets/ui/fonts/jetbrains-mono-variable.ttf")
# CJK fallbacks. Their import settings mark Noto Sans JP as not supporting `zh`
# and Noto Sans TC as not supporting `ja`, so the text server picks the face
# that matches the current locale for shared Han code points.
const NOTO_SANS_JP: Font = preload("res://assets/ui/fonts/noto-sans-jp-variable.ttf")
const NOTO_SANS_TC: Font = preload("res://assets/ui/fonts/noto-sans-tc-variable.ttf")

static func font(weight: int = 400, mono: bool = false) -> FontVariation:
	var variation := _weighted(JETBRAINS_MONO if mono else OPEN_SANS, weight)
	variation.fallbacks = [_weighted(NOTO_SANS_JP, weight), _weighted(NOTO_SANS_TC, weight)]
	return variation

static func _weighted(base: Font, weight: int) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {
		TextServerManager.get_primary_interface().name_to_tag("wght"): float(weight),
	}
	return variation

static func panel(fill: Color = PRIMARY, border: Color = BORDER, width: int = 1) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(width)
	return result

static func text(control: Control, size: int = 10, color: Color = TEXT, weight: int = 400, mono: bool = false) -> void:
	control.add_theme_font_override("font", font(weight, mono))
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", color)
	control.add_theme_color_override("font_hover_color", color)
	control.add_theme_color_override("font_pressed_color", color)
	control.add_theme_color_override("font_focus_color", color)

static func button(control: Button, size: int = 10, selected: bool = false) -> void:
	text(control, size, GOLD if selected else TEXT, 700, false)
	control.add_theme_stylebox_override("normal", panel(INSET, GOLD if selected else BORDER, 1))
	control.add_theme_stylebox_override("hover", panel(HEADER, BORDER_LIGHT, 1))
	control.add_theme_stylebox_override("pressed", panel(HEADER, GOLD, 1))
	control.add_theme_stylebox_override("focus", panel(INSET, GOLD, 1))
	control.add_theme_stylebox_override("disabled", panel(INSET, BORDER, 1))
	control.add_theme_color_override("font_disabled_color", MUTED)
	control.focus_mode = Control.FOCUS_NONE

## HPA-680 stopgap: the title, result, and HUD roots are still authored for
## the old 640x360 canvas. Pin them to that size and draw them 3x so they fill
## the 1920x1080 base viewport until HPA-681/682 rebuild them natively; delete
## this helper and its three call sites then.
const LEGACY_LAYOUT_SIZE := Vector2(640, 360)

static func fit_legacy_layout(root: Control) -> void:
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.position = Vector2.ZERO
	root.size = LEGACY_LAYOUT_SIZE
	root.scale = Vector2.ONE * (float(UiSettings.WINDOW_SIZE.x) / LEGACY_LAYOUT_SIZE.x)
	# Rasterize glyphs at the scaled size so the 3x text stays sharp.
	root.oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
