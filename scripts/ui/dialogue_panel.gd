class_name DialoguePanel
extends Control

signal gift_requested(villager_id: int, crop_kind: int)
signal close_requested

# Portrait art per VillagerId slot.
const PORTRAIT_NAMES: Array[String] = ["sato", "gen", "hana"]

const HEART_FILLED_ICON := preload("res://assets/ui/icons/heart-filled.png")
const HEART_OUTLINE_ICON := preload("res://assets/ui/icons/heart-outline.png")
const DIMMED := Color(0.5, 0.54, 0.62, 1.0)

var _villager_id := -1
var _lines: Array[String] = []
var _line_index := 0
var _points_gained := 0
var _gift_reaction: StringName = &""
var _close_friend_sequence := false
var _snapshot: Dictionary = {}
var _selected_gift_kind := -1
var _gift_buttons: Array[Button] = []
var _gift_icons: Array[TextureRect] = []
var _gift_keycaps: Array[PanelContainer] = []
var _gift_keys: Array[Label] = []
var _gift_badges: Array[PanelContainer] = []
var _gift_counts: Array[Label] = []
var _gift_values: Array[Label] = []
var _portrait: TextureRect
var _name: Label
var _role: Label
var _relationship: Label
var _hearts: Array[TextureRect] = []
var _progress_fill: Control
var _line: Label
var _feedback: Label
var _feedback_badge: PanelContainer
var _feedback_value: Label
var _gift_status: Label
var _gift_hint: Label
var _esc_text: Label
var _action_text: Label
var _continue: Button
var _close: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_continue.pressed.connect(_on_continue_pressed)
	_close.pressed.connect(func() -> void: close_requested.emit())
	for kind in _gift_buttons.size():
		_gift_buttons[kind].pressed.connect(_on_gift_button_pressed.bind(kind))
		_gift_buttons[kind].focus_entered.connect(_on_gift_focus_entered.bind(kind))
	visible = false

func present(villager_id: int, result: Dictionary, snapshot: Dictionary) -> void:
	_villager_id = villager_id
	_snapshot = snapshot.duplicate(true)

	var incoming_lines: Array = result.get("lines", [])
	if not incoming_lines.is_empty() or _lines.is_empty():
		_lines.clear()
		for line in incoming_lines:
			_lines.append(String(line))
		_line_index = 0
	_points_gained = int(result.get("points_gained", 0))
	_gift_reaction = StringName(result.get("gift_reaction", &""))
	_close_friend_sequence = bool(result.get("close_friend_sequence", false))
	_selected_gift_kind = int(result.get("selected_crop_kind", -1))
	_select_first_available_gift()
	visible = true
	_render()
	_focus_primary()

func current_line_text() -> String:
	return _line.text

func villager_name_text() -> String:
	return _name.text

func role_text() -> String:
	return _role.text

func relationship_text() -> String:
	return _relationship.text

func feedback_text() -> String:
	return _feedback.text

func action_text() -> String:
	return _action_text.text

func portrait_texture() -> Texture2D:
	return _portrait.texture

func gift_chip(kind: int) -> Button:
	return _gift_buttons[kind]

func gift_chip_count_text(kind: int) -> String:
	return _gift_counts[kind].text

func gift_chip_value_text(kind: int) -> String:
	return _gift_values[kind].text

func continue_control() -> Button:
	return _continue

func close_control() -> Button:
	return _close

func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(UiStyle.INK, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.anchor_top = 1.0
	_portrait.anchor_bottom = 1.0
	_portrait.offset_left = 96.0
	_portrait.offset_top = -620.0
	_portrait.offset_right = 536.0
	_portrait.offset_bottom = -30.0
	_portrait.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_portrait)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 560.0
	panel.offset_top = -420.0
	panel.offset_right = -64.0
	panel.offset_bottom = -40.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.HUD_CARD, 24, [24, 18, 24, 16])
	)
	add_child(panel)
	var column := UiStyle.vbox(12)
	column.name = "Column"
	panel.add_child(column)
	column.add_child(_header())
	_line = UiStyle.label("", 24, UiStyle.INK, 500)
	_line.name = "Line"
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(0, 104)
	column.add_child(_line)
	column.add_child(_feedback_row())
	column.add_child(_gift_area())
	column.add_child(_footer())

	_continue = _ghost_button("Continue")
	_continue.name = "Continue"
	add_child(_continue)
	_close = _ghost_button("Close")
	_close.name = "Close"
	add_child(_close)

func _ghost_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = Vector2(584, 986)
	button.size = Vector2(120, 36)
	button.focus_mode = Control.FOCUS_ALL
	button.modulate = Color(1, 1, 1, 0)
	return button

func _header() -> HBoxContainer:
	var header := UiStyle.hbox(14)
	header.name = "Header"
	var identity := UiStyle.vbox(6)
	identity.name = "Identity"
	header.add_child(identity)
	var name_tag := SlantTag.new("", UiStyle.ACCENT_GRADIENT, UiStyle.CARD, 22)
	name_tag.name = "NameTag"
	name_tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	identity.add_child(name_tag)
	_name = name_tag.get_node("Text") as Label
	_role = UiStyle.label("", 15, UiStyle.INK_MUTED, 800)
	_role.name = "Role"
	identity.add_child(_role)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var rel := UiStyle.vbox(6)
	rel.name = "Relationship"
	header.add_child(rel)
	var rel_row := UiStyle.hbox(8)
	rel_row.alignment = BoxContainer.ALIGNMENT_END
	rel.add_child(rel_row)
	var hearts := UiStyle.hbox(4)
	hearts.name = "Hearts"
	hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rel_row.add_child(hearts)
	for index in 3:
		var heart := UiStyle.icon(null, 22)
		heart.name = "Heart_%d" % index
		hearts.add_child(heart)
		_hearts.append(heart)
	_relationship = UiStyle.label("", 16, UiStyle.ACCENT_DEEP, 800)
	_relationship.name = "Label"
	_relationship.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rel_row.add_child(_relationship)
	var progress := Panel.new()
	progress.name = "Progress"
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.custom_minimum_size = Vector2(180, 8)
	progress.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.LINE, UiStyle.PILL_RADIUS, [0, 0, 0, 0], false)
	)
	rel.add_child(progress)
	var fill := Panel.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.ACCENT, UiStyle.PILL_RADIUS, [0, 0, 0, 0], false)
	)
	fill.anchor_right = 0.0
	fill.anchor_bottom = 1.0
	progress.add_child(fill)
	_progress_fill = fill
	return header

func _feedback_row() -> HBoxContainer:
	var row := UiStyle.hbox(10)
	row.name = "FeedbackRow"
	_feedback_badge = PanelContainer.new()
	_feedback_badge.name = "FeedbackBadge"
	_feedback_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_badge.add_theme_stylebox_override(
		"panel",
		UiStyle.outlined(
			UiStyle.card(UiStyle.MINT, UiStyle.PILL_RADIUS, [10, 4, 12, 4], false),
			UiStyle.LEAF,
			1,
		),
	)
	_feedback_badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(_feedback_badge)
	var badge_row := UiStyle.hbox(6)
	_feedback_badge.add_child(badge_row)
	badge_row.add_child(UiStyle.icon(HEART_FILLED_ICON, 16))
	_feedback_value = UiStyle.label("+1", 16, UiStyle.LEAF_DEEP, 900)
	_feedback_value.name = "Value"
	badge_row.add_child(_feedback_value)
	_feedback = UiStyle.label("", 18, UiStyle.LEAF_DEEP, 700)
	_feedback.name = "Text"
	_feedback.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_feedback)
	return row

func _gift_area() -> VBoxContainer:
	var area := UiStyle.vbox(6)
	area.name = "GiftArea"
	_gift_status = UiStyle.label("", 14, UiStyle.INK_MUTED, 800)
	_gift_status.name = "GiftStatus"
	area.add_child(_gift_status)
	var row := UiStyle.hbox(12)
	row.name = "GiftRow"
	area.add_child(row)
	var chips := UiStyle.hbox(10)
	chips.name = "GiftButtons"
	row.add_child(chips)
	for kind in range(GameRules.CropKind.size()):
		var chip := _gift_chip_button(kind)
		chips.add_child(chip)
		_gift_buttons.append(chip)
	_gift_hint = UiStyle.label("", 15, UiStyle.WARN_INK, 700)
	_gift_hint.name = "GiftHint"
	_gift_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gift_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gift_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_gift_hint)
	return area

func _gift_chip_button(kind: int) -> Button:
	var button := Button.new()
	button.name = "Gift_%d" % kind
	button.custom_minimum_size = Vector2(96, 96)
	button.focus_mode = Control.FOCUS_ALL
	var keycap := PanelContainer.new()
	keycap.name = "Keycap"
	keycap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keycap.position = Vector2(5, 5)
	keycap.size = Vector2(26, 26)
	keycap.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.SOFT, 9, [0, 0, 0, 0], false)
	)
	button.add_child(keycap)
	var key := UiStyle.label("%d" % (kind + 1), 13, UiStyle.INK, 900)
	key.name = "Key"
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keycap.add_child(key)
	var icon := UiStyle.icon(null, 48)
	icon.name = "Icon"
	icon.position = Vector2(24, 18)
	icon.size = Vector2(48, 48)
	button.add_child(icon)
	var badge := PanelContainer.new()
	badge.name = "CountBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(64, 5)
	badge.size = Vector2(27, 20)
	badge.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.INK_MUTED, UiStyle.PILL_RADIUS, [0, 0, 0, 0], false)
	)
	button.add_child(badge)
	var count := UiStyle.label("0", 13, UiStyle.CARD, 800)
	count.name = "Count"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(count)
	var value := UiStyle.label("", 13, UiStyle.INK_MUTED, 800)
	value.name = "Value"
	value.position = Vector2(4, 74)
	value.size = Vector2(88, 18)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_child(value)
	_gift_icons.append(icon)
	_gift_keycaps.append(keycap)
	_gift_keys.append(key)
	_gift_badges.append(badge)
	_gift_counts.append(count)
	_gift_values.append(value)
	return button

func _footer() -> HBoxContainer:
	var footer := UiStyle.hbox(8)
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_END
	var escape := UiStyle.keycap("Esc", true)
	escape.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(escape)
	_esc_text = UiStyle.label("leave", 15, UiStyle.INK_MUTED, 700)
	_esc_text.name = "EscText"
	_esc_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_esc_text)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size = Vector2(24, 0)
	footer.add_child(gap)
	var enter := UiStyle.keycap("Enter", true)
	enter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(enter)
	_action_text = UiStyle.label("", 16, UiStyle.ACCENT_DEEP, 800)
	_action_text.name = "ActionText"
	_action_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_action_text)
	return footer

func _render() -> void:
	_portrait.texture = load(
		"res://assets/ui/portraits/%s.png" % PORTRAIT_NAMES[_villager_id]
	) as Texture2D
	_name.text = VillagerRules.display_name(_villager_id)
	_role.text = tr(VillagerRules.role_label(_villager_id)).to_upper()

	var relationship := _relationship_snapshot()
	_relationship.text = "%s  ·  %d/%d" % [
		tr(_relationship_display(relationship.get("level", &"stranger"))).to_upper(),
		int(relationship.get("points", 0)),
		VillagerRules.CLOSE_FRIEND_POINTS,
	]
	_line.text = (
		tr("“%s”") % tr(_lines[_line_index])
		if _line_index < _lines.size()
		else ""
	)

	var feedback_lines: Array[String] = []
	if _points_gained > 0:
		feedback_lines.append(
			tr("+%d relationship point" if _points_gained == 1 else "+%d relationship points")
			% _points_gained
		)
	if _gift_reaction == &"favourite":
		feedback_lines.append(tr("Favourite gift!"))
	elif _gift_reaction == &"normal":
		feedback_lines.append(tr("Gift accepted."))
	var points_only := _points_gained > 0 and feedback_lines.size() == 1
	_feedback.text = "\n".join(feedback_lines)
	_feedback.visible = not feedback_lines.is_empty() and not points_only
	_feedback_badge.visible = points_only
	if points_only:
		_feedback_value.text = "+%d" % _points_gained

	var more_lines := _line_index < _lines.size() - 1
	_continue.visible = more_lines
	var locked := _close_friend_sequence and more_lines
	_close.visible = not locked
	_esc_text.text = "continue" if locked else "leave"
	_render_relationship(relationship)
	_render_gift_buttons(locked)

func _render_relationship(relationship: Dictionary) -> void:
	var points := int(relationship.get("points", 0))
	var filled := mini(points / 6, 3)
	for index in 3:
		_hearts[index].texture = (
			HEART_FILLED_ICON if index < filled else HEART_OUTLINE_ICON
		)
	_progress_fill.anchor_right = clampf(
		float(points) / float(VillagerRules.CLOSE_FRIEND_POINTS), 0.0, 1.0
	)

func _render_gift_buttons(suppressed: bool) -> void:
	if suppressed:
		_gift_status.text = ""
		_gift_hint.visible = false
		_action_text.text = "CONTINUE"
		for button in _gift_buttons:
			button.visible = false
		return

	var relationship := _relationship_snapshot()
	if bool(relationship.get("gifted_today", false)):
		_gift_status.text = "GIFT GIVEN TODAY"
		_gift_hint.visible = false
		_action_text.text = "CLOSE"
		for button in _gift_buttons:
			button.visible = false
		return

	var harvested: Dictionary = _snapshot.get("harvested", {})
	_gift_status.text = "GIVE A GIFT  ·  ONE PER DAY"
	_gift_hint.visible = false
	_action_text.text = "GIVE"
	for kind in _gift_buttons.size():
		var button := _gift_buttons[kind]
		var quantity := int(harvested.get(GameRules.crop_key(kind), 0))
		var favourite := VillagerRules.is_favourite_crop(_villager_id, kind)
		var is_selected := kind == _selected_gift_kind
		button.visible = true
		button.disabled = quantity < 1
		button.focus_mode = Control.FOCUS_ALL
		button.modulate = Color.WHITE if quantity > 0 else DIMMED
		var card_style := UiStyle.card(
			UiStyle.ACCENT_SOFT if is_selected else UiStyle.CARD, 14, [0, 0, 0, 0], false
		)
		card_style.border_color = UiStyle.ACCENT if is_selected else UiStyle.LINE
		card_style.set_border_width_all(2 if is_selected else 1)
		for state in ["normal", "focus", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, card_style)
		var keycap := _gift_keycaps[kind]
		keycap.visible = quantity > 0
		var keycap_style := UiStyle.card(
			UiStyle.ACCENT_SOFT if is_selected else UiStyle.SOFT, 9, [0, 0, 0, 0], false
		)
		keycap_style.border_color = UiStyle.ACCENT if is_selected else UiStyle.LINE
		keycap_style.set_border_width_all(1)
		keycap.add_theme_stylebox_override("panel", keycap_style)
		_gift_keys[kind].add_theme_color_override(
			"font_color", UiStyle.ACCENT_DEEP if is_selected else UiStyle.INK
		)
		var count_badge := _gift_badges[kind]
		count_badge.visible = quantity > 0
		count_badge.add_theme_stylebox_override(
			"panel",
			UiStyle.card(
				UiStyle.ACCENT if is_selected else UiStyle.INK_MUTED,
				UiStyle.PILL_RADIUS,
				[0, 0, 0, 0],
				false,
			),
		)
		_gift_icons[kind].texture = load(
			"res://assets/ui/crops/%s.png" % GameRules.crop_key(kind)
		) as Texture2D
		_gift_counts[kind].text = "%d" % quantity
		_gift_counts[kind].visible = quantity > 0
		_gift_values[kind].text = (
			"+%d ♥" % VillagerRules.gift_points(_villager_id, kind)
			if quantity > 0 and favourite
			else "+%d" % VillagerRules.gift_points(_villager_id, kind)
			if quantity > 0
			else "none"
		)
		_gift_values[kind].add_theme_color_override(
			"font_color",
			UiStyle.ACCENT_DEEP if quantity > 0 and favourite else UiStyle.INK_MUTED,
		)
	if _selected_gift_kind >= 0 and _selected_gift_kind < _gift_buttons.size():
		var selected := _gift_buttons[_selected_gift_kind]
		var selected_quantity := int(harvested.get(
			GameRules.crop_key(_selected_gift_kind),
			0,
		))
		if selected.visible and not selected.disabled:
			var selected_name := tr(GameRules.crop_display_name(_selected_gift_kind))
			_action_text.text = tr("GIVE %s") % selected_name.to_upper()
			if VillagerRules.is_favourite_crop(_villager_id, _selected_gift_kind):
				_gift_hint.text = tr("%s is %s's favourite — worth %d instead of %d.") % [
					selected_name,
					tr(VillagerRules.display_name(_villager_id)),
					VillagerRules.gift_points(_villager_id, _selected_gift_kind),
					VillagerRules.GIFT_POINTS,
				]
				_gift_hint.visible = selected_quantity > 0

func _select_first_available_gift() -> void:
	var harvested: Dictionary = _snapshot.get("harvested", {})
	if _selected_gift_kind >= 0 and int(harvested.get(GameRules.crop_key(_selected_gift_kind), 0)) > 0:
		return
	for kind in range(GameRules.CropKind.size()):
		if int(harvested.get(GameRules.crop_key(kind), 0)) > 0:
			_selected_gift_kind = kind
			return
	_selected_gift_kind = 0

func _relationship_snapshot() -> Dictionary:
	var relationships: Dictionary = _snapshot.get("relationships", {})
	var relationship: Variant = relationships.get(VillagerRules.villager_key(_villager_id), {})
	return relationship if relationship is Dictionary else {}

func _relationship_display(level_key: Variant) -> String:
	for level in range(VillagerRules.RelationshipLevel.size()):
		if VillagerRules.relationship_key(level) == level_key:
			return VillagerRules.relationship_display_name(level)
	return String(level_key)

func _on_gift_button_pressed(crop_kind: int) -> void:
	if _gift_buttons[crop_kind].disabled:
		return
	_selected_gift_kind = crop_kind
	_render_gift_buttons(false)
	gift_requested.emit(_villager_id, crop_kind)

func _on_gift_focus_entered(crop_kind: int) -> void:
	_selected_gift_kind = crop_kind
	if visible and not _close_friend_sequence:
		_render_gift_buttons(false)

func _on_continue_pressed() -> void:
	if _line_index >= _lines.size() - 1:
		return
	_line_index += 1
	_render()
	_focus_primary()

func _focus_primary() -> void:
	if _line_index < _lines.size() - 1:
		_continue.grab_focus()
		return
	if _selected_gift_kind >= 0 and _selected_gift_kind < _gift_buttons.size():
		var selected_button := _gift_buttons[_selected_gift_kind]
		if selected_button.visible and not selected_button.disabled:
			selected_button.grab_focus()
			return
	for button in _gift_buttons:
		if button.visible and not button.disabled:
			button.grab_focus()
			return
	_close.grab_focus()

func close_panel() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()
	visible = false

func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		var delta := -1 if event.is_action_pressed("move_left") else 1
		_select_gift(delta)
		get_viewport().set_input_as_handled()
		return
	var key_event := event as InputEventKey
	if key_event == null:
		return
	var code := key_event.physical_keycode
	if code == KEY_NONE:
		code = key_event.keycode
	var kind := int(code) - int(KEY_1)
	if kind < 0 or kind >= _gift_buttons.size():
		return
	if (
		key_event.ctrl_pressed
		or key_event.alt_pressed
		or key_event.shift_pressed
		or key_event.meta_pressed
	):
		return
	var chip := _gift_buttons[kind]
	if not chip.visible or chip.disabled:
		return
	_on_gift_button_pressed(kind)
	get_viewport().set_input_as_handled()

func _select_gift(delta: int) -> void:
	var next := _selected_gift_kind
	for _step in GameRules.CropKind.size():
		next = posmod(next + delta, GameRules.CropKind.size())
		if _gift_buttons[next].visible and not _gift_buttons[next].disabled:
			_selected_gift_kind = next
			_gift_buttons[next].grab_focus()
			_render_gift_buttons(false)
			return

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _close_friend_sequence and _line_index < _lines.size() - 1:
		return
	close_requested.emit()
