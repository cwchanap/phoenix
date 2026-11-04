class_name DialoguePanel
extends Control

signal gift_requested(villager_id: int, crop_kind: int)
signal close_requested

# Portrait art per VillagerId slot.
const PORTRAIT_NAMES: Array[String] = ["sato", "gen", "hana"]

const HEART_FILLED_ICON := preload("res://assets/ui/icons/heart-filled.png")
const HEART_OUTLINE_ICON := preload("res://assets/ui/icons/heart-outline.png")
const DIMMED := Color(1.0, 1.0, 1.0, 0.45)

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
var _gift_counts: Array[Label] = []
var _gift_values: Array[Label] = []
var _portrait: TextureRect
var _name: Label
var _role: Label
var _relationship: Label
var _hearts: Array[TextureRect] = []
var _line: Label
var _feedback: Label
var _feedback_badge: PanelContainer
var _feedback_value: Label
var _gift_status: Label
var _gift_hint: Label
var _esc_text: Label
var _action_text: Label
var _action: Button
var _continue: Button
var _close: Button
var _anchor_intent: StringName = &""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_continue.pressed.connect(_on_continue_pressed)
	_close.pressed.connect(func() -> void: close_requested.emit())
	_continue.focus_entered.connect(_on_continue_focus_entered)
	_close.focus_entered.connect(_on_close_focus_entered)
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
	_anchor_intent = &""
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
	dim.color = Color(0.047, 0.071, 0.125, 0.25)
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
	_portrait.offset_left = 140.0
	_portrait.offset_top = -940.0
	_portrait.offset_right = 812.0
	_portrait.offset_bottom = 0.0
	_portrait.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_portrait)

	var dock := UiStyle.vn_dock(40.0)
	add_child(dock)
	var content := dock.find_child("Content", true, false) as VBoxContainer
	var overlay := dock.find_child("Overlay", true, false) as Control

	_line = UiStyle.label("", 32, UiStyle.INK, 700)
	_line.name = "Line"
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(0, 100)
	content.add_child(_line)
	_feedback = UiStyle.label("", 18, UiStyle.LEAF_DEEP, 700)
	_feedback.name = "Feedback"
	_feedback.visible = false
	content.add_child(_feedback)
	content.add_child(_gift_area())
	content.add_child(_footer_block())

	var name_row := UiStyle.hbox(14)
	name_row.name = "NameRow"
	overlay.add_child(name_row)
	UiStyle.pin(name_row, CORNER_TOP_LEFT, Vector2(40, -28))
	var name_tag := SlantTag.new("", UiStyle.ACCENT_GRADIENT, UiStyle.CARD, 30)
	name_tag.name = "NameTag"
	var tag_pad := StyleBoxEmpty.new()
	tag_pad.content_margin_left = 26
	tag_pad.content_margin_right = 26
	tag_pad.content_margin_top = 6
	tag_pad.content_margin_bottom = 6
	name_tag.add_theme_stylebox_override("panel", tag_pad)
	name_row.add_child(name_tag)
	_name = name_tag.get_node("Text") as Label
	var role_pill := PanelContainer.new()
	role_pill.name = "RolePill"
	role_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	role_pill.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.CARD, UiStyle.PILL_RADIUS, [16, 6, 16, 6])
	)
	role_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(role_pill)
	_role = UiStyle.label("", 16, UiStyle.INK_MUTED, 800)
	_role.name = "Role"
	role_pill.add_child(_role)

	var rel_pill := PanelContainer.new()
	rel_pill.name = "RelPill"
	rel_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rel_pill.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.CARD, UiStyle.PILL_RADIUS, [18, 8, 18, 8])
	)
	overlay.add_child(rel_pill)
	UiStyle.pin(rel_pill, CORNER_TOP_RIGHT, Vector2(40, -24))
	var rel_row := UiStyle.hbox(12)
	rel_row.name = "Row"
	rel_pill.add_child(rel_row)
	var hearts := UiStyle.hbox(4)
	hearts.name = "Hearts"
	hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rel_row.add_child(hearts)
	for index in 3:
		var heart := UiStyle.icon(null, 24)
		heart.name = "Heart_%d" % index
		hearts.add_child(heart)
		_hearts.append(heart)
	_relationship = UiStyle.label("", 16, UiStyle.INK, 800)
	_relationship.name = "Relationship"
	_relationship.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rel_row.add_child(_relationship)
	_feedback_badge = PanelContainer.new()
	_feedback_badge.name = "FeedbackBadge"
	_feedback_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_badge.add_theme_stylebox_override(
		"panel",
		UiStyle.card(
			Color(UiStyle.LEAF, 0.15), UiStyle.PILL_RADIUS, [12, 4, 12, 4], false
		),
	)
	_feedback_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_feedback_badge.visible = false
	rel_row.add_child(_feedback_badge)
	_feedback_value = UiStyle.label("+1", 15, UiStyle.LEAF, 800)
	_feedback_value.name = "Value"
	_feedback_badge.add_child(_feedback_value)

	_continue = _ghost_button("Continue")
	_continue.name = "Continue"
	add_child(_continue)
	_close = _ghost_button("Close")
	_close.name = "Close"
	add_child(_close)

func _ghost_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = Vector2(1540, 950)
	button.size = Vector2(200, 56)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.modulate = Color(1, 1, 1, 0)
	return button

func _gift_area() -> HBoxContainer:
	var row := UiStyle.hbox(12)
	row.name = "GiftRow"
	_gift_status = UiStyle.label("", 14, UiStyle.INK_MUTED, 900)
	_gift_status.name = "GiftStatus"
	_gift_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_gift_status)
	var chips := UiStyle.hbox(12)
	chips.name = "GiftButtons"
	chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	return row

func _gift_chip_button(kind: int) -> Button:
	var button := Button.new()
	button.name = "Gift_%d" % kind
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := UiStyle.hbox(10)
	row.name = "Row"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_top = 6
	row.offset_right = -16
	row.offset_bottom = -6
	button.add_child(row)
	var tile := PanelContainer.new()
	tile.name = "Tile"
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.custom_minimum_size = Vector2(60, 60)
	tile.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.CARD, 14, [6, 6, 6, 6], false)
	)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tile)
	var icon := UiStyle.icon(null, 48)
	icon.name = "Icon"
	tile.add_child(icon)
	var stack := UiStyle.vbox(2)
	stack.name = "TextStack"
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stack)
	var name_line := UiStyle.hbox(2)
	name_line.name = "NameRow"
	stack.add_child(name_line)
	var crop_name := UiStyle.label(GameRules.crop_display_name(kind), 18, UiStyle.INK, 800)
	crop_name.name = "Name"
	name_line.add_child(crop_name)
	var times := UiStyle.label("×", 15, UiStyle.INK_MUTED, 800)
	times.name = "Times"
	times.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_line.add_child(times)
	var count := UiStyle.label("0", 18, UiStyle.INK, 800)
	count.name = "Count"
	name_line.add_child(count)
	var value := UiStyle.label("", 14, UiStyle.INK_MUTED, 800)
	value.name = "Value"
	stack.add_child(value)
	var sync_size := func() -> void:
		if not is_instance_valid(button) or not is_instance_valid(row):
			return
		button.custom_minimum_size = (
			row.get_combined_minimum_size() + Vector2(22, 12)
		)
	row.minimum_size_changed.connect(sync_size)
	sync_size.call()
	sync_size.call_deferred()
	_gift_icons.append(icon)
	_gift_counts.append(count)
	_gift_values.append(value)
	return button

func _footer_block() -> VBoxContainer:
	var block := UiStyle.vbox(14)
	block.name = "FooterBlock"
	var separator := Panel.new()
	separator.name = "Separator"
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	separator.custom_minimum_size = Vector2(0, 2)
	separator.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.LINE, 0, [0, 0, 0, 0], false)
	)
	block.add_child(separator)
	var footer := UiStyle.hbox(18)
	footer.name = "Footer"
	block.add_child(footer)
	var gift_keys := UiStyle.hbox(4)
	gift_keys.name = "GiftKeys"
	gift_keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(gift_keys)
	gift_keys.add_child(UiStyle.keycap("A", true))
	gift_keys.add_child(UiStyle.keycap("D", true))
	var choose := UiStyle.label("choose gift", 17, UiStyle.INK_MUTED, 800)
	choose.name = "ChooseGift"
	choose.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(choose)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var leave_row := UiStyle.hbox(8)
	leave_row.name = "LeaveRow"
	leave_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(leave_row)
	leave_row.add_child(UiStyle.keycap("Esc", true))
	_esc_text = UiStyle.label("leave", 17, UiStyle.INK_MUTED, 800)
	_esc_text.name = "EscText"
	_esc_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	leave_row.add_child(_esc_text)
	_action = UiStyle.primary_action("Enter", "")
	_action.name = "Action"
	var pill := _action.find_child("Pill", true, false) as PanelContainer
	pill.name = "ActionPill"
	_action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_action.pressed.connect(_on_action_pressed)
	footer.add_child(_action)
	_action_text = pill.get_node("Row/Text") as Label
	return block

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

func _render_gift_buttons(suppressed: bool) -> void:
	if suppressed:
		_gift_status.text = ""
		_gift_hint.visible = false
		for button in _gift_buttons:
			button.visible = false
		_render_action_caption()
		return

	var relationship := _relationship_snapshot()
	if bool(relationship.get("gifted_today", false)):
		_gift_status.text = "GIFT GIVEN TODAY"
		_gift_hint.visible = false
		for button in _gift_buttons:
			button.visible = false
		_render_action_caption()
		return

	var harvested: Dictionary = _snapshot.get("harvested", {})
	_gift_status.text = "GIVE A GIFT  ·  ONE PER DAY"
	_gift_hint.visible = false
	for kind in _gift_buttons.size():
		var button := _gift_buttons[kind]
		var quantity := int(harvested.get(GameRules.crop_key(kind), 0))
		var favourite := VillagerRules.is_favourite_crop(_villager_id, kind)
		var is_selected := kind == _selected_gift_kind
		button.visible = true
		button.disabled = quantity < 1
		button.focus_mode = (
			Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		)
		if button.disabled and get_viewport().gui_get_focus_owner() == button:
			button.release_focus()
		button.modulate = Color.WHITE if quantity > 0 else DIMMED
		var card_style := UiStyle.card(
			UiStyle.ACCENT_SOFT if is_selected else UiStyle.SOFT, 18, [0, 0, 0, 0], false
		)
		card_style.border_color = (
			UiStyle.ACCENT if is_selected else Color(1.0, 1.0, 1.0, 0.0)
		)
		card_style.set_border_width_all(3)
		for state in ["normal", "focus", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, card_style)
		_gift_icons[kind].texture = load(
			"res://assets/ui/crops/%s.png" % GameRules.crop_key(kind)
		) as Texture2D
		_gift_counts[kind].text = "%d" % quantity
		_gift_values[kind].text = (
			"+%d ♥" % VillagerRules.gift_points(_villager_id, kind)
			if quantity > 0 and favourite
			else "+%d" % VillagerRules.gift_points(_villager_id, kind)
			if quantity > 0
			else "none"
		)
		_gift_values[kind].add_theme_color_override(
			"font_color",
			UiStyle.ACCENT_DEEP
			if quantity > 0 and (favourite or is_selected)
			else UiStyle.INK_MUTED,
		)
	if _selected_gift_kind >= 0 and _selected_gift_kind < _gift_buttons.size():
		var selected := _gift_buttons[_selected_gift_kind]
		var selected_quantity := int(harvested.get(
			GameRules.crop_key(_selected_gift_kind),
			0,
		))
		if selected.visible and not selected.disabled:
			var selected_name := tr(GameRules.crop_display_name(_selected_gift_kind))
			if VillagerRules.is_favourite_crop(_villager_id, _selected_gift_kind):
				_gift_hint.text = tr("%s is %s's favourite — worth %d instead of %d.") % [
					selected_name,
					tr(VillagerRules.display_name(_villager_id)),
					VillagerRules.gift_points(_villager_id, _selected_gift_kind),
					VillagerRules.GIFT_POINTS,
				]
				_gift_hint.visible = selected_quantity > 0
	_render_action_caption()

func _primary_gift_kind() -> int:
	if _selected_gift_kind >= 0 and _selected_gift_kind < _gift_buttons.size():
		var selected := _gift_buttons[_selected_gift_kind]
		if selected.visible and not selected.disabled:
			return _selected_gift_kind
	for index in _gift_buttons.size():
		var chip := _gift_buttons[index]
		if chip.visible and not chip.disabled:
			return index
	return -1

func _primary_action_kind() -> StringName:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == _close:
		return &"close"
	if focused == _continue:
		return &"continue"
	if _anchor_intent != &"":
		return _anchor_intent
	if _line_index < _lines.size() - 1:
		return &"continue"
	var relationship := _relationship_snapshot()
	if not bool(relationship.get("gifted_today", false)) and _primary_gift_kind() >= 0:
		return &"gift"
	return &"close"

func _render_action_caption() -> void:
	match _primary_action_kind():
		&"continue":
			_action_text.text = "CONTINUE"
		&"gift":
			var selected_name := tr(GameRules.crop_display_name(_primary_gift_kind()))
			_action_text.text = tr("GIVE %s") % selected_name.to_upper()
		&"close":
			_action_text.text = "CLOSE"

func _on_action_pressed() -> void:
	match _primary_action_kind():
		&"continue":
			_on_continue_pressed()
		&"gift":
			_on_gift_button_pressed(_primary_gift_kind())
		&"close":
			close_requested.emit()

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
	_anchor_intent = &""
	_selected_gift_kind = crop_kind
	_render_gift_buttons(false)
	gift_requested.emit(_villager_id, crop_kind)

func _on_gift_focus_entered(crop_kind: int) -> void:
	_anchor_intent = &""
	_selected_gift_kind = crop_kind
	if visible and not (
		_close_friend_sequence and _line_index < _lines.size() - 1
	):
		_render_gift_buttons(false)

func _on_continue_focus_entered() -> void:
	_anchor_intent = &"continue"
	_render_action_caption()

func _on_close_focus_entered() -> void:
	_anchor_intent = &"close"
	_render_action_caption()

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
	if not visible:
		return
	if event.is_action_pressed("ui_accept") and not event.is_echo():
		var owner := get_viewport().gui_get_focus_owner()
		if owner == null or not is_ancestor_of(owner):
			get_viewport().set_input_as_handled()
			_on_action_pressed()
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _close_friend_sequence and _line_index < _lines.size() - 1:
		return
	close_requested.emit()
