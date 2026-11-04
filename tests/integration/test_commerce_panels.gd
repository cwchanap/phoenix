extends GutTest

const LOCALES := ["en", "zh_TW", "ja"]
const SHOP_SCENE := "res://scenes/ui/shop_panel.tscn"
const SHIPPING_SCENE := "res://scenes/ui/shipping_panel.tscn"

func after_each() -> void:
	TranslationServer.set_locale("en")

func _spawn_panel(scene: String) -> Control:
	return _spawn_panel_at(scene, UiSettings.WINDOW_SIZE)

func _spawn_panel_at(scene: String, window_size: Vector2i) -> Control:
	get_window().size = window_size
	var panel := (load(scene) as PackedScene).instantiate() as Control
	assert_not_null(panel)
	if panel == null:
		return null
	var top := CanvasLayer.new()
	top.layer = 128
	add_child_autoqfree(top)
	top.add_child(panel)
	return panel

func _window_point(logical: Vector2) -> Vector2:
	return get_window().get_final_transform() * logical

func _counts(partial: Dictionary) -> Dictionary:
	var result := {&"turnip": 0, &"potato": 0, &"pumpkin": 0}
	for key in partial:
		result[key] = partial[key]
	return result

func _shop_snapshot(money: int, seeds: Dictionary = {}, upgraded := false) -> Dictionary:
	var session := GameSession.new()
	var state := session.state()
	state["money"] = money
	state["seeds"] = _counts(seeds)
	state["watering_can_upgraded"] = upgraded
	assert_true(session.restore_state(state))
	return session.snapshot()

func _shipping_snapshot(
	harvested: Dictionary, day := 1, pending: Dictionary = {}
) -> Dictionary:
	var session := GameSession.new()
	var state := session.state()
	state["day"] = day
	state["weather_history"] = []
	for _index in day:
		state["weather_history"].append(&"sunny")
	state["harvested"] = _counts(harvested)
	state["pending_shipment"] = _counts(pending)
	assert_true(session.restore_state(state))
	return session.snapshot()

func _press(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	get_viewport().push_input(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	get_viewport().push_input(release)
	await get_tree().process_frame

func _click_at(global_pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = global_pos
	get_viewport().push_input(press)
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = global_pos
	get_viewport().push_input(release)
	await get_tree().process_frame

func _click(control: Control) -> void:
	await _click_at(control.get_global_rect().get_center())

func _press_and_release_outside(control: Control) -> void:
	var center := control.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = center
	get_viewport().push_input(press)
	await get_tree().process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(40, 40)
	get_viewport().push_input(motion)
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(40, 40)
	get_viewport().push_input(release)
	await get_tree().process_frame

func _press_at_release_outside_at(global_pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = global_pos
	get_viewport().push_input(press)
	await get_tree().process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(40, 40)
	get_viewport().push_input(motion)
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(40, 40)
	get_viewport().push_input(release)
	await get_tree().process_frame

func _press_outside_release_at(global_pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(40, 40)
	get_viewport().push_input(press)
	await get_tree().process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = global_pos
	get_viewport().push_input(motion)
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = global_pos
	get_viewport().push_input(release)
	await get_tree().process_frame

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _card(panel: Control) -> Control:
	return panel.find_child("Card", true, false) as Control

func _row(panel: Control, index: int) -> Control:
	return panel.find_child("Row_%d" % index, true, false) as Control

func _row_part(row: Control, node_name: String) -> Control:
	return row.find_child(node_name, true, false) as Control

func _meta(row: Control) -> Control:
	return _row_part(row, "Meta")

func _meta_caption(row: Control) -> Label:
	var meta := _meta(row)
	if meta == null:
		return _row_part(row, "Caption") as Label
	return meta.get_node_or_null("Caption") as Label

func _meta_value(row: Control) -> Label:
	var meta := _meta(row)
	if meta == null:
		return null
	return meta.get_node_or_null("Value") as Label

func _font_size(control: Control) -> int:
	return control.get_theme_font_size("font_size")

func _font_color(label: Label) -> Color:
	return label.get_theme_color("font_color")

func test_shop_action_pill_names_quantity_and_total() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	if shop == null:
		return
	shop.open_panel(_shop_snapshot(150, {&"turnip": 3}))
	await _settle()
	assert_eq(
		shop.selected_action_text(),
		"Buy 1 · 20G",
		"pill names the exact purchase: quantity and total",
	)
	await _press("move_right")
	assert_eq(shop.selected_action_text(), "Buy 2 · 40G")
	await _press("panel_max")
	assert_eq(shop.selected_quantity(), 7)
	assert_eq(shop.selected_action_text(), "Buy 7 · 140G")
	await _press("move_left")
	await _press("move_left")
	assert_eq(shop.selected_action_text(), "Buy 5 · 100G")

func test_shop_action_pill_at_zero_and_unaffordable() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	if shop == null:
		return
	shop.open_panel(_shop_snapshot(15, {}))
	await _settle()
	assert_eq(shop.selected_quantity(), 0)
	assert_eq(shop.selected_action_text(), "Buy 0 · 0G")
	assert_true(
		(shop.stepper_button(0, &"minus") as Button).disabled,
		"cannot step below zero",
	)
	assert_true(
		(shop.stepper_button(0, &"plus") as Button).disabled,
		"cannot afford one turnip at 15G",
	)
	assert_true((shop.stepper_button(0, &"max") as Button).disabled)

func test_shipping_action_pill_names_quantity_and_total() -> void:
	var shipping := _spawn_panel(SHIPPING_SCENE) as ShippingPanel
	if shipping == null:
		return
	shipping.open_panel(
		_shipping_snapshot({&"turnip": 7, &"potato": 0, &"pumpkin": 0})
	)
	await _settle()
	assert_eq(shipping.selected_action_text(), "Ship 1 · 35G")
	await _press("move_right")
	assert_eq(shipping.selected_action_text(), "Ship 2 · 70G")
	await _press("panel_max")
	assert_eq(shipping.selected_quantity(), 7)
	assert_eq(shipping.selected_action_text(), "Ship 7 · 245G")
	await _press("move_down")
	assert_eq(shipping.selected_quantity(), 0)
	assert_eq(shipping.selected_action_text(), "Ship 0 · 0G")
	await _press("move_down")
	assert_eq(shipping.selected_kind(), GameRules.CropKind.PUMPKIN)
	assert_eq(shipping.selected_action_text(), "Ship 0 · 0G")

func _assert_gradient_header_band(panel: Control) -> void:
	var card := _card(panel)
	assert_not_null(card, "card exists")
	if card == null:
		return
	var band := card.find_child("HeaderBand", true, false) as Control
	assert_not_null(band, "a full-width HeaderBand carries the header")
	if band == null:
		return
	var card_rect := card.get_global_rect()
	var band_rect := band.get_global_rect()
	assert_almost_eq(
		band_rect.size.x, card_rect.size.x, 4.0,
		"header band spans the full card width",
	)
	assert_almost_eq(
		band_rect.position.y, card_rect.position.y, 4.0,
		"header band sits flush against the card top",
	)
	assert_gt(band_rect.size.y, 90.0, "header band is a large band, not a row")
	var gradient := band.find_child("Gradient", true, false) as TextureRect
	assert_not_null(gradient, "the band renders a gradient texture")
	if gradient == null:
		return
	assert_not_null(
		gradient.texture, "the gradient TextureRect carries a baked texture"
	)
	if gradient.texture == null:
		return
	assert_true(
		gradient.texture is ImageTexture,
		"gradient is a baked rounded ImageTexture, not a clip mask",
	)
	var image := (gradient.texture as ImageTexture).get_image()
	assert_not_null(image)
	if image == null:
		return
	assert_almost_eq(
		image.get_pixel(0, 0).a, 0.0, 0.05,
		"top-left corner stays transparent (rounded)",
	)
	assert_almost_eq(
		image.get_pixel(image.get_width() - 1, 0).a, 0.0, 0.05,
		"top-right corner stays transparent (rounded)",
	)
	assert_gt(
		image.get_pixel(image.get_width() / 2, 0).a, 0.9,
		"top middle of the band is opaque gradient",
	)
	assert_gt(
		image.get_pixel(0, image.get_height() - 1).a, 0.9,
		"bottom edge is square, not rounded",
	)

func _assert_header_text_on_gradient(band: Control, title_name: String) -> void:
	var title := band.find_child(title_name, true, false) as Label
	assert_not_null(title)
	if title == null:
		return
	assert_eq(_font_color(title), UiStyle.CARD, "title reads white on gradient")
	assert_gte(_font_size(title), 30, "title is a large 30px+ header")
	var chip := band.find_child("IconChip", true, false) as Control
	assert_not_null(chip, "translucent icon chip sits in the band")
	if chip != null:
		assert_gte(chip.get_global_rect().size.x, 60.0, "icon chip ~64px")

func test_shop_header_is_a_large_gradient_band() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	if shop == null:
		return
	shop.open_panel(_shop_snapshot(150, {&"turnip": 3}))
	await _settle()
	_assert_gradient_header_band(shop)
	var band := _card(shop).find_child("HeaderBand", true, false) as Control
	assert_not_null(band)
	if band == null:
		return
	_assert_header_text_on_gradient(band, "Title")
	var title := band.find_child("Title", true, false) as Label
	assert_not_null(title)
	if title == null:
		return
	assert_eq(title.text, "SEED SHOP", "localized shop title stays truthful")
	var sub := band.find_child("Sub", true, false) as Label
	assert_not_null(sub, "a subtitle line rides under the title")
	if sub != null:
		assert_eq(sub.text, "Seeds and tools", "subtitle describes real stock")
	assert_eq(shop.money_text(), "150", "money_text keeps its numeric contract")
	var money := band.find_child("Money", true, false) as Control
	assert_not_null(money, "the money chip rides in the header")
	if money != null:
		var value := money.find_child("Value", true, false) as Label
		assert_not_null(value)
		if value != null:
			assert_eq(value.text, "150G", "money pill reads like the reference")

func test_shipping_header_is_a_large_gradient_band() -> void:
	var shipping := _spawn_panel(SHIPPING_SCENE) as ShippingPanel
	if shipping == null:
		return
	shipping.open_panel(
		_shipping_snapshot(
			{&"turnip": 7}, 1, {&"turnip": 4, &"potato": 0, &"pumpkin": 0}
		)
	)
	await _settle()
	_assert_gradient_header_band(shipping)
	var band := _card(shipping).find_child("HeaderBand", true, false) as Control
	assert_not_null(band)
	if band == null:
		return
	_assert_header_text_on_gradient(band, "Title")
	var title := band.find_child("Title", true, false) as Label
	assert_not_null(title)
	if title == null:
		return
	assert_eq(title.text, "SHIPPING BIN")
	var sub := band.find_child("Sub", true, false) as Label
	assert_not_null(sub)
	if sub != null:
		assert_eq(
			sub.text, "Pays out tomorrow morning",
			"subtitle states the normal-day payout rule",
		)
	var pending := band.find_child("Value", true, false) as Label
	assert_not_null(pending, "the in-bin pill lives in the header")
	if pending != null:
		assert_eq(pending.text, "140G", "4 turnips in the bin pend 140G")

func test_shipping_subtitle_is_truthful_on_day_fourteen() -> void:
	var shipping := _spawn_panel(SHIPPING_SCENE) as ShippingPanel
	if shipping == null:
		return
	shipping.open_panel(
		_shipping_snapshot({&"turnip": 2}, GameRules.MAX_DAY)
	)
	await _settle()
	var band := _card(shipping).find_child("HeaderBand", true, false) as Control
	assert_not_null(band)
	if band == null:
		return
	var sub := band.find_child("Sub", true, false) as Label
	assert_not_null(sub)
	if sub != null:
		assert_eq(
			sub.text, "Paid at season end",
			"day 14 settles at the finale, not next morning",
		)
	assert_true(shipping.day14_warning_visible(), "day 14 warning stays")

func test_commerce_cards_match_reference_width_and_rows() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	var shipping := _spawn_panel(SHIPPING_SCENE) as ShippingPanel
	if shop == null or shipping == null:
		return
	shop.open_panel(_shop_snapshot(150, {&"turnip": 3}))
	shipping.open_panel(
		_shipping_snapshot({&"turnip": 7, &"potato": 0, &"pumpkin": 0})
	)
	await _settle()
	for panel in [shop, shipping]:
		var card := _card(panel)
		assert_gte(
			card.size.x, 1040.0,
			"%s card is the reference 1040px wide" % panel.name,
		)
	for index in range(3):
		for panel in [shop, shipping]:
			var row := _row(panel, index)
			assert_not_null(row, "row %d exists" % index)
			if row == null:
				continue
			var tile := _row_part(row, "Tile")
			assert_not_null(tile)
			if tile != null:
				assert_gte(
					tile.get_global_rect().size.x, 76.0,
					"icon tile is the reference 76px",
				)
			var name_label := _row_part(row, "Name") as Label
			assert_not_null(name_label)
			if name_label != null:
				assert_gte(
					_font_size(name_label), 26,
					"row name is the reference 26px",
				)
			var meta_value := _meta_value(row)
			assert_not_null(meta_value)
			if meta_value != null:
				assert_gte(
					_font_size(meta_value), 28,
					"right column value is the reference 30px class",
				)

func test_selected_row_uses_reference_border_and_stepper_box() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	if shop == null:
		return
	shop.open_panel(_shop_snapshot(150, {&"turnip": 3}))
	await _settle()
	var row := _row(shop, 0)
	var box := row.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(box)
	if box != null:
		assert_eq(box.bg_color, UiStyle.ACCENT_SOFT)
		assert_eq(box.border_color, UiStyle.ACCENT)
		assert_gte(
			box.get_border_width(SIDE_TOP), 3,
			"selected row carries the reference 3px accent border",
		)
	var quantity := _row_part(row, "Quantity") as PanelContainer
	assert_not_null(quantity)
	if quantity == null:
		return
	assert_gte(
		quantity.get_global_rect().size.x, 90.0,
		"quantity box is the reference 90px min width",
	)
	var qbox := quantity.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(qbox)
	if qbox != null:
		assert_eq(qbox.bg_color, UiStyle.CARD, "q box is white like the mockup")
		assert_eq(
			qbox.border_color, UiStyle.ACCENT,
			"selected q box is accent-bordered",
		)
		assert_gte(qbox.get_border_width(SIDE_LEFT), 2)
	var qtext := quantity.get_node_or_null("Value") as Label
	assert_not_null(qtext)
	if qtext != null:
		assert_eq(_font_color(qtext), UiStyle.ACCENT_DEEP)
		assert_gte(_font_size(qtext), 24, "q box text is the reference 28px class")

func test_shop_rows_list_price_nights_and_held() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	if shop == null:
		return
	shop.open_panel(
		_shop_snapshot(150, {&"turnip": 3, &"potato": 0, &"pumpkin": 0})
	)
	await _settle()
	assert_eq(
		shop.display_price_for_row(0),
		"20",
		"display_price_for_row keeps its numeric contract",
	)
	assert_eq(shop.display_price_for_row(1), "30")
	assert_eq(shop.display_price_for_row(2), "70")
	for entry in [
		[0, "20G each · 3 nights · 3 held"],
		[1, "30G each · 5 nights · 0 held"],
		[2, "70G each · 7 nights · 0 held"],
	]:
		var sub := _row_part(_row(shop, entry[0]), "Sub") as Label
		assert_not_null(sub)
		if sub != null:
			assert_eq(
				sub.text, entry[1],
				"sub line names price, nights and held like the reference",
			)
	var selected := _row(shop, 0)
	var selected_caption := _meta_caption(selected)
	var selected_value := _meta_value(selected)
	assert_not_null(selected_caption)
	assert_not_null(selected_value)
	if selected_caption != null and selected_value != null:
		assert_eq(selected_caption.text, "TOTAL")
		assert_eq(
			selected_value.text, "20G",
			"selected row total carries the G unit",
		)
	var idle := _row(shop, 1)
	var idle_caption := _meta_caption(idle)
	var idle_value := _meta_value(idle)
	assert_not_null(idle_caption)
	assert_not_null(idle_value)
	if idle_caption != null and idle_value != null:
		assert_eq(
			idle_caption.text, "EACH",
			"unselected rows show the unit price",
		)
		assert_eq(idle_value.text, "30G")

func test_shop_upgrade_row_matches_reference() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	if shop == null:
		return
	shop.open_panel(_shop_snapshot(150))
	await _settle()
	for _i in range(3):
		await _press("move_down")
	assert_eq(shop.selected_row(), 3)
	assert_eq(
		shop.selected_action_text(), "Buy 1 · 200G",
		"upgrade pill names the one-time purchase",
	)
	var row := _row(shop, 3)
	var sub := _row_part(row, "Sub") as Label
	if sub == null:
		sub = _row_part(row, "Note") as Label
	assert_not_null(sub)
	if sub != null:
		assert_eq(
			sub.text,
			"Watering costs 1 stamina instead of 2. One-time.",
		)
	var need := _row_part(row, "NeedChip") as Control
	assert_not_null(need, "an unaffordable upgrade names its price")
	if need != null:
		assert_true(need.is_visible_in_tree())
		var text := need.find_child("Text", true, false) as Label
		assert_not_null(text)
		if text != null:
			assert_eq(text.text, "Need 200G")
	var meta_value := _meta_value(row)
	assert_not_null(meta_value)
	if meta_value != null:
		assert_eq(meta_value.text, "200G", "upgrade row shows its price")
	assert_eq(
		shop.display_price_for_row(3),
		"200",
		"display_price_for_row keeps its numeric contract on the upgrade row",
	)

func test_shop_upgrade_row_affordable_and_owned_states() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	if shop == null:
		return
	shop.open_panel(_shop_snapshot(255))
	await _settle()
	var row := _row(shop, 3)
	var need := _row_part(row, "NeedChip") as Control
	assert_not_null(need, "NeedChip exists in the upgrade row")
	if need != null:
		assert_false(
			need.is_visible_in_tree(),
			"a funded upgrade hides the Need chip",
		)
	var owned_shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	if owned_shop == null:
		return
	owned_shop.open_panel(_shop_snapshot(55, {}, true))
	await _settle()
	for _i in range(3):
		await _press("move_down")
	assert_eq(owned_shop.selected_action_text(), "OWNED")

func test_unaffordable_and_empty_rows_dim_like_the_reference() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	var shipping := _spawn_panel(SHIPPING_SCENE) as ShippingPanel
	if shop == null or shipping == null:
		return
	shop.open_panel(_shop_snapshot(15))
	shipping.open_panel(
		_shipping_snapshot({&"turnip": 7, &"potato": 0, &"pumpkin": 0})
	)
	await _settle()
	var seed_row := _row(shop, 0)
	assert_lt(
		seed_row.modulate.a, 1.0,
		"a seed row the wallet cannot afford dims like .item.off",
	)
	var empty_row := _row(shipping, 1)
	assert_lt(
		empty_row.modulate.a, 1.0,
		"an empty shipping row dims like .item.off",
	)

func test_off_rows_fade_pale_like_the_reference_not_dark_tint() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	var shipping := _spawn_panel(SHIPPING_SCENE) as ShippingPanel
	if shop == null or shipping == null:
		return
	shop.open_panel(_shop_snapshot(15))
	shipping.open_panel(
		_shipping_snapshot({&"turnip": 7, &"potato": 0, &"pumpkin": 0})
	)
	await _settle()
	for entry in [
		[_row(shop, 0), "unaffordable seed row"],
		[_row(shop, 3), "unaffordable upgrade row"],
		[_row(shipping, 1), "empty potato row"],
		[_row(shipping, 2), "empty pumpkin row"],
	]:
		var row: Control = entry[0]
		var tag: String = entry[1]
		assert_not_null(row, tag)
		if row == null:
			continue
		assert_almost_eq(
			row.modulate.a, 0.45, 0.06,
			"%s fades to the reference .item.off translucency" % tag,
		)
		for channel in [row.modulate.r, row.modulate.g, row.modulate.b]:
			assert_gte(
				channel, 0.9,
				"%s stays a pale multiply, not a dark tint" % tag,
			)
	var need := _row_part(_row(shop, 3), "NeedChip") as Control
	assert_not_null(need, "the off upgrade row still names its price")
	if need != null:
		assert_true(need.is_visible_in_tree())

func _footer_hint_labels(footer: Control) -> Array[Label]:
	var result: Array[Label] = []
	for node in footer.find_children("*", "Label", true, false):
		result.append(node as Label)
	return result

func _assert_footer_matches_reference(panel: Control, max_hint: String) -> void:
	var card := _card(panel)
	var bar := card.find_child("FooterBar", true, false) as Control
	assert_not_null(bar, "a FooterBar anchors the card bottom")
	if bar == null:
		return
	var bar_box := bar.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(bar_box)
	if bar_box != null:
		assert_gte(
			bar_box.get_border_width(SIDE_TOP), 1,
			"the footer carries the reference top hairline",
		)
	var footer := bar.find_child("Footer", true, false) as Control
	assert_not_null(footer)
	if footer == null:
		return
	var captions: Array[String] = []
	for hint in _footer_hint_labels(footer):
		captions.append(hint.text)
	assert_true(
		captions.has(max_hint),
		"footer names the M %s shortcut" % max_hint,
	)
	assert_true(captions.has("leave"))
	var keys: Array[String] = []
	for node in footer.find_children("*", "Label", true, false):
		var label := node as Label
		if label.name == "Key":
			keys.append(label.text)
	assert_true(keys.has("M"), "an M keycap sits in the footer")
	var smallest_hint := 999
	for hint in _footer_hint_labels(footer):
		if hint.name == "Key":
			continue
		smallest_hint = mini(smallest_hint, _font_size(hint))
	assert_gte(smallest_hint, 16, "footer hints are a readable 16px+")
	var action := footer.find_child("Action", true, false) as Control
	assert_not_null(action, "the gradient action pill exists")
	if action == null:
		return
	var enter: Node = null
	for node in action.find_children("*", "Label", true, false):
		if (node as Label).text == "Enter":
			enter = node
	assert_not_null(
		enter, "the Enter keycap rides inside the gradient pill",
	)
	var text := action.find_child("Text", true, false) as Label
	assert_not_null(text)
	if text != null:
		assert_gte(_font_size(text), 20, "action text is a readable 20px+")

func test_shop_footer_matches_reference() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	if shop == null:
		return
	shop.open_panel(_shop_snapshot(150))
	await _settle()
	_assert_footer_matches_reference(shop, "max")

func test_shipping_footer_matches_reference() -> void:
	var shipping := _spawn_panel(SHIPPING_SCENE) as ShippingPanel
	if shipping == null:
		return
	shipping.open_panel(_shipping_snapshot({&"turnip": 7}))
	await _settle()
	_assert_footer_matches_reference(shipping, "all")

func _assert_descendants_inside_card(panel: Control, context: String) -> void:
	var card := _card(panel)
	var card_rect := card.get_global_rect()
	var checked := 0
	for node in card.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		if not control.get_global_rect().has_area():
			continue
		checked += 1
		assert_true(
			card_rect.grow(2.0).encloses(control.get_global_rect()),
			"%s escapes the card at %s" % [control.get_path(), context],
		)
	assert_gt(checked, 0, "rect containment checked real descendants")

func test_commerce_cards_stay_contained_in_all_locales() -> void:
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
		var shipping := _spawn_panel(SHIPPING_SCENE) as ShippingPanel
		if shop == null or shipping == null:
			return
		shop.open_panel(_shop_snapshot(150, {&"turnip": 3}))
		shipping.open_panel(
			_shipping_snapshot(
				{&"turnip": 7, &"potato": 2, &"pumpkin": 1}, GameRules.MAX_DAY
			)
		)
		await _settle()
		_assert_descendants_inside_card(shop, "%s shop" % locale)
		_assert_descendants_inside_card(shipping, "%s shipping" % locale)

func test_action_pills_translate_in_all_locales() -> void:
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
		var shipping := _spawn_panel(SHIPPING_SCENE) as ShippingPanel
		if shop == null or shipping == null:
			return
		shop.open_panel(_shop_snapshot(150))
		shipping.open_panel(_shipping_snapshot({&"turnip": 7}))
		await _settle()
		var buy_text := shop.selected_action_text()
		var ship_text := shipping.selected_action_text()
		match locale:
			"en":
				assert_eq(buy_text, "Buy 1 · 20G")
				assert_eq(ship_text, "Ship 1 · 35G")
			"zh_TW":
				assert_eq(buy_text, "購買 1 · 20G")
				assert_eq(ship_text, "出貨 1 · 35G")
			"ja":
				assert_eq(buy_text, "買う 1 · 20G")
				assert_eq(ship_text, "出荷 1 · 35G")
		var band := _card(shop).find_child("HeaderBand", true, false) as Control
		if band == null:
			continue
		var sub := band.find_child("Sub", true, false) as Label
		if sub != null and locale != "en":
			assert_ne(
				sub.text, "Seeds and tools",
				"%s subtitle is localized, not English fallback" % locale,
			)

func _action_button(panel: Control) -> Button:
	var action := _card(panel).find_child("Action", true, false) as Button
	assert_not_null(action, "the painted action pill is a native Button")
	return action

func test_shop_action_pill_is_a_native_button_over_the_painted_pill() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	if shop == null:
		return
	shop.open_panel(_shop_snapshot(150, {&"turnip": 3}))
	await _settle()
	var action := _action_button(shop)
	if action == null:
		return
	var pill := action.find_child("Pill", true, false) as Control
	assert_not_null(pill, "the gradient pill paints inside the button")
	var text := action.find_child("Text", true, false) as Label
	assert_not_null(text, "the quantity/total label still renders")
	var enter := action.find_child("Enter", true, false) as Control
	assert_not_null(enter, "the Enter keycap still renders")
	if pill == null or text == null:
		return
	assert_almost_eq(
		action.get_global_rect().size.x,
		pill.get_global_rect().size.x,
		1.0,
		"the hitbox spans the whole painted pill",
	)
	assert_almost_eq(
		action.get_global_rect().size.y,
		pill.get_global_rect().size.y,
		1.0,
		"the hitbox is as tall as the painted pill",
	)

func test_shop_action_button_click_buys_the_shown_quantity() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	if shop == null:
		return
	shop.open_panel(_shop_snapshot(150, {&"turnip": 3}))
	await _settle()
	var action := _action_button(shop)
	if action == null:
		return
	watch_signals(shop)
	await _click(action)
	assert_signal_emitted_with_parameters(
		shop,
		"buy_requested",
		[GameRules.CropKind.TURNIP, 1],
	)
	assert_signal_emit_count(shop, "buy_requested", 1)
	await _press("move_right")
	await _press("move_right")
	await _click(action)
	assert_signal_emitted_with_parameters(
		shop,
		"buy_requested",
		[GameRules.CropKind.TURNIP, 3],
	)
	assert_signal_emit_count(shop, "buy_requested", 2)

func test_shipping_action_button_click_deposits_the_shown_quantity() -> void:
	var shipping := _spawn_panel(SHIPPING_SCENE) as ShippingPanel
	if shipping == null:
		return
	shipping.open_panel(
		_shipping_snapshot({&"turnip": 7, &"potato": 2, &"pumpkin": 0})
	)
	await _settle()
	var action := _action_button(shipping)
	if action == null:
		return
	watch_signals(shipping)
	await _press("panel_max")
	await _click(action)
	assert_signal_emitted_with_parameters(
		shipping,
		"deposit_requested",
		[GameRules.CropKind.TURNIP, 7],
	)
	assert_signal_emit_count(shipping, "deposit_requested", 1)
	await _press("move_down")
	await _press("panel_max")
	await _click(action)
	assert_signal_emitted_with_parameters(
		shipping,
		"deposit_requested",
		[GameRules.CropKind.POTATO, 2],
	)

func test_shop_action_button_release_outside_cancels() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	if shop == null:
		return
	shop.open_panel(_shop_snapshot(150, {&"turnip": 3}))
	await _settle()
	var action := _action_button(shop)
	if action == null:
		return
	watch_signals(shop)
	await _press_and_release_outside(action)
	assert_signal_not_emitted(shop, "buy_requested")
	await _click(action)
	assert_signal_emitted(shop, "buy_requested")

func test_shipping_action_button_release_outside_cancels() -> void:
	var shipping := _spawn_panel(SHIPPING_SCENE) as ShippingPanel
	if shipping == null:
		return
	shipping.open_panel(_shipping_snapshot({&"turnip": 7}))
	await _settle()
	var action := _action_button(shipping)
	if action == null:
		return
	watch_signals(shipping)
	await _press_and_release_outside(action)
	assert_signal_not_emitted(shipping, "deposit_requested")
	await _click(action)
	assert_signal_emitted(shipping, "deposit_requested")

func test_shop_action_button_click_outside_does_not_buy() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	if shop == null:
		return
	shop.open_panel(_shop_snapshot(150, {&"turnip": 3}))
	await _settle()
	var action := _action_button(shop)
	if action == null:
		return
	watch_signals(shop)
	var rect := action.get_global_rect()
	await _click_at(rect.position + Vector2(-6.0, rect.size.y * 0.5))
	assert_signal_not_emitted(shop, "buy_requested")
	await _click_at(rect.position + Vector2(6.0, rect.size.y * 0.5))
	assert_signal_emitted(shop, "buy_requested")
	await _click_at(
		Vector2(rect.end.x - 6.0, rect.position.y + 4.0)
	)
	assert_signal_emit_count(shop, "buy_requested", 2)

func test_shop_action_button_zero_quantity_click_emits_zero() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	if shop == null:
		return
	shop.open_panel(_shop_snapshot(15))
	await _settle()
	assert_eq(shop.selected_quantity(), 0)
	var action := _action_button(shop)
	if action == null:
		return
	watch_signals(shop)
	await _click(action)
	assert_signal_emitted_with_parameters(
		shop,
		"buy_requested",
		[GameRules.CropKind.TURNIP, 0],
	)

func test_shop_action_button_upgrade_click_emits_upgrade() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	if shop == null:
		return
	shop.open_panel(_shop_snapshot(255))
	await _settle()
	for _i in range(3):
		await _press("move_down")
	assert_eq(shop.selected_row(), 3)
	var action := _action_button(shop)
	if action == null:
		return
	watch_signals(shop)
	await _click(action)
	assert_signal_emitted(shop, "upgrade_requested")
	assert_signal_emit_count(shop, "upgrade_requested", 1)
	assert_signal_not_emitted(shop, "buy_requested")

func test_shop_action_button_owned_upgrade_click_emits_nothing() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	if shop == null:
		return
	shop.open_panel(_shop_snapshot(55, {}, true))
	await _settle()
	for _i in range(3):
		await _press("move_down")
	assert_eq(shop.selected_action_text(), "OWNED")
	var action := _action_button(shop)
	if action == null:
		return
	watch_signals(shop)
	await _click(action)
	assert_signal_not_emitted(shop, "upgrade_requested")
	assert_signal_not_emitted(shop, "buy_requested")

func test_action_buttons_do_nothing_while_the_panel_is_hidden() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	var shipping := _spawn_panel(SHIPPING_SCENE) as ShippingPanel
	if shop == null or shipping == null:
		return
	shop.open_panel(_shop_snapshot(150))
	shipping.open_panel(_shipping_snapshot({&"turnip": 7}))
	await _settle()
	var shop_action := _action_button(shop)
	var shipping_action := _action_button(shipping)
	if shop_action == null or shipping_action == null:
		return
	var shop_center := shop_action.get_global_rect().get_center()
	var ship_center := shipping_action.get_global_rect().get_center()
	watch_signals(shop)
	watch_signals(shipping)
	shop.visible = false
	shipping.visible = false
	await _settle()
	await _click_at(shop_center)
	assert_signal_not_emitted(shop, "buy_requested")
	await _click_at(ship_center)
	assert_signal_not_emitted(shipping, "deposit_requested")
	await _press("ui_accept")
	assert_signal_not_emitted(shop, "buy_requested")
	assert_signal_not_emitted(shipping, "deposit_requested")

func test_shop_enter_activates_the_focused_button_exactly_once() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	if shop == null:
		return
	shop.open_panel(_shop_snapshot(150, {&"turnip": 3}))
	await _settle()
	var action := _action_button(shop)
	if action == null:
		return
	watch_signals(shop)
	await _click(action)
	assert_signal_emit_count(shop, "buy_requested", 1)
	assert_eq(
		get_viewport().gui_get_focus_owner(),
		action,
		"the click gives the native button focus",
	)
	await _press("ui_accept")
	assert_signal_emit_count(
		shop,
		"buy_requested",
		2,
		"Enter on the focused button dispatches once, not through both paths",
	)
	action.release_focus()
	await _settle()
	await _press("ui_accept")
	assert_signal_emit_count(
		shop,
		"buy_requested",
		3,
		"unfocused Enter still dispatches once through the panel path",
	)

func test_shipping_enter_activates_the_focused_button_exactly_once() -> void:
	var shipping := _spawn_panel(SHIPPING_SCENE) as ShippingPanel
	if shipping == null:
		return
	shipping.open_panel(_shipping_snapshot({&"turnip": 7}))
	await _settle()
	var action := _action_button(shipping)
	if action == null:
		return
	watch_signals(shipping)
	await _click(action)
	assert_signal_emit_count(shipping, "deposit_requested", 1)
	assert_eq(get_viewport().gui_get_focus_owner(), action)
	await _press("ui_accept")
	assert_signal_emit_count(
		shipping,
		"deposit_requested",
		2,
		"Enter on the focused button dispatches once, not through both paths",
	)

func test_shop_disabled_steppers_ignore_clicks() -> void:
	var shop := _spawn_panel(SHOP_SCENE) as ShopPanel
	if shop == null:
		return
	shop.open_panel(_shop_snapshot(15))
	await _settle()
	var minus := shop.stepper_button(0, &"minus")
	var plus := shop.stepper_button(0, &"plus")
	var max_button := shop.stepper_button(0, &"max")
	assert_true(minus.disabled)
	assert_true(plus.disabled)
	assert_true(max_button.disabled)
	await _click(minus)
	await _click(plus)
	await _click(max_button)
	assert_eq(
		shop.selected_quantity(),
		0,
		"disabled steppers keep their native no-op semantics",
	)

func test_action_button_click_works_in_all_locales() -> void:
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		for size in [UiSettings.WINDOW_SIZE, UiSettings.MIN_WINDOW_SIZE]:
			var context := "%s %s" % [size, locale]
			var shop := _spawn_panel_at(SHOP_SCENE, size) as ShopPanel
			if shop == null:
				return
			shop.open_panel(_shop_snapshot(150, {&"turnip": 3}))
			await _settle()
			assert_eq(
				get_window().size, size,
				"%s: the test runs on the requested native window" % context,
			)
			var shop_action := _action_button(shop)
			if shop_action == null:
				return
			watch_signals(shop)
			await _click_at(
				_window_point(shop_action.get_global_rect().get_center())
			)
			assert_signal_emitted(shop, "buy_requested", "%s shop click" % context)
			shop.visible = false
			var shipping := _spawn_panel_at(SHIPPING_SCENE, size) as ShippingPanel
			if shipping == null:
				return
			shipping.open_panel(_shipping_snapshot({&"turnip": 7}))
			await _settle()
			var shipping_action := _action_button(shipping)
			if shipping_action == null:
				return
			watch_signals(shipping)
			await _click_at(
				_window_point(shipping_action.get_global_rect().get_center())
			)
			assert_signal_emitted(
				shipping, "deposit_requested", "%s shipping click" % context
			)
			shipping.visible = false
			await _settle()
	get_window().size = UiSettings.WINDOW_SIZE

func test_action_button_edges_cancel_and_enter_at_both_sizes() -> void:
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		for size in [UiSettings.WINDOW_SIZE, UiSettings.MIN_WINDOW_SIZE]:
			var context := "%s %s" % [size, locale]
			var shop := _spawn_panel_at(SHOP_SCENE, size) as ShopPanel
			if shop == null:
				return
			shop.open_panel(_shop_snapshot(150, {&"turnip": 3}))
			await _settle()
			assert_eq(
				get_window().size, size,
				"%s: the test runs on the requested native window" % context,
			)
			var expected := 0.5 if size == UiSettings.MIN_WINDOW_SIZE else 1.0
			assert_almost_eq(
				get_window().get_final_transform().x.x, expected, 0.01,
				"%s: the canvas transform scales to the native window" % context,
			)
			var action := _action_button(shop)
			if action == null:
				return
			var rect := action.get_global_rect()
			var mid := rect.size.y * 0.5
			watch_signals(shop)
			await _click_at(
				_window_point(rect.position + Vector2(4, mid))
			)
			assert_signal_emitted_with_parameters(
				shop, "buy_requested", [GameRules.CropKind.TURNIP, 1]
			)
			await _click_at(
				_window_point(rect.end - Vector2(4, mid))
			)
			assert_signal_emit_count(
				shop, "buy_requested", 2,
				"%s: both painted edges dispatch the request" % context,
			)
			await _press_at_release_outside_at(
				_window_point(rect.get_center())
			)
			assert_signal_emit_count(
				shop, "buy_requested", 2,
				"%s: release outside cancels" % context,
			)
			await _press_outside_release_at(
				_window_point(rect.get_center())
			)
			assert_signal_emit_count(
				shop, "buy_requested", 2,
				"%s: a press starting outside never arms the button" % context,
			)
			assert_eq(
				get_viewport().gui_get_focus_owner(), action,
				"%s: the edge clicks focused the native button" % context,
			)
			await _press("ui_accept")
			assert_signal_emit_count(
				shop, "buy_requested", 3,
				"%s: focused Enter dispatches exactly once" % context,
			)
			action.release_focus()
			await _settle()
			await _press("ui_accept")
			assert_signal_emit_count(
				shop, "buy_requested", 4,
				"%s: unfocused Enter dispatches once via the panel" % context,
			)
			shop.visible = false
			await _settle()
	get_window().size = UiSettings.WINDOW_SIZE

func test_shipping_action_button_edges_and_cancel_at_both_sizes() -> void:
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		for size in [UiSettings.WINDOW_SIZE, UiSettings.MIN_WINDOW_SIZE]:
			var context := "%s %s" % [size, locale]
			var shipping := _spawn_panel_at(SHIPPING_SCENE, size) as ShippingPanel
			if shipping == null:
				return
			shipping.open_panel(_shipping_snapshot({&"turnip": 7}))
			await _settle()
			assert_eq(
				get_window().size, size,
				"%s: the test runs on the requested native window" % context,
			)
			var action := _action_button(shipping)
			if action == null:
				return
			var rect := action.get_global_rect()
			var mid := rect.size.y * 0.5
			watch_signals(shipping)
			await _click_at(
				_window_point(rect.position + Vector2(4, mid))
			)
			assert_signal_emitted_with_parameters(
				shipping, "deposit_requested", [GameRules.CropKind.TURNIP, 1]
			)
			await _click_at(
				_window_point(rect.end - Vector2(4, mid))
			)
			assert_signal_emit_count(
				shipping, "deposit_requested", 2,
				"%s: both painted edges dispatch the request" % context,
			)
			await _press_at_release_outside_at(
				_window_point(rect.get_center())
			)
			assert_signal_emit_count(
				shipping, "deposit_requested", 2,
				"%s: release outside cancels" % context,
			)
			await _press_outside_release_at(
				_window_point(rect.get_center())
			)
			assert_signal_emit_count(
				shipping, "deposit_requested", 2,
				"%s: a press starting outside never arms the button" % context,
			)
			assert_eq(
				get_viewport().gui_get_focus_owner(), action,
				"%s: the edge clicks focused the native button" % context,
			)
			await _press("ui_accept")
			assert_signal_emit_count(
				shipping, "deposit_requested", 3,
				"%s: focused Enter dispatches exactly once" % context,
			)
			action.release_focus()
			await _settle()
			await _press("ui_accept")
			assert_signal_emit_count(
				shipping, "deposit_requested", 4,
				"%s: unfocused Enter dispatches once via the panel" % context,
			)
			shipping.visible = false
			await _settle()
	get_window().size = UiSettings.WINDOW_SIZE
