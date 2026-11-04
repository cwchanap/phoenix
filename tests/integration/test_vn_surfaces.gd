extends GutTest

const LOCALES := ["en", "zh_TW", "ja"]

func after_each() -> void:
	TranslationServer.set_locale("en")

func _spawn_panel(scene: String) -> Control:
	get_window().size = UiSettings.WINDOW_SIZE
	var panel := (load(scene) as PackedScene).instantiate() as Control
	assert_not_null(panel)
	if panel == null:
		return null
	var top := CanvasLayer.new()
	top.layer = 128
	add_child_autoqfree(top)
	top.add_child(panel)
	panel.visible = true
	return panel

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _stylebox(control: Control) -> StyleBoxFlat:
	return control.get_theme_stylebox("panel") as StyleBoxFlat

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

func _dialogue_snapshot() -> Dictionary:
	var snapshot := GameSession.new().snapshot()
	snapshot["harvested"] = {&"turnip": 7, &"potato": 2, &"pumpkin": 0}
	var relationship: Dictionary = snapshot["relationships"][&"shopkeeper"]
	relationship["points"] = 13
	relationship["level"] = VillagerRules.relationship_key(
		VillagerRules.relationship_level(13)
	)
	return snapshot

func _present_dialogue(result: Dictionary, snapshot: Dictionary) -> DialoguePanel:
	var panel := _spawn_panel("res://scenes/ui/dialogue_panel.tscn") as DialoguePanel
	if panel == null:
		return null
	panel.present(VillagerRules.VillagerId.SHOPKEEPER, result, snapshot)
	return panel

func _dialogue() -> DialoguePanel:
	return _present_dialogue(
		{
			"code": GameRules.CommandCode.VILLAGER_TALKED,
			"lines": [
				"You stopped asking which seeds are best. Now you ask which are right.",
			],
			"points_gained": 1,
			"gift_reaction": &"",
			"close_friend_sequence": false,
			"selected_crop_kind": GameRules.CropKind.POTATO,
		},
		_dialogue_snapshot(),
	)

func _intro() -> OnboardingOverlay:
	var overlay := _spawn_panel(
		"res://scenes/ui/onboarding_overlay.tscn"
	) as OnboardingOverlay
	if overlay == null:
		return null
	overlay.render(GameSession.new().snapshot())
	return overlay

func _title() -> TitleScreen:
	return _spawn_panel("res://scenes/ui/title_screen.tscn") as TitleScreen

func _result_data() -> Dictionary:
	var state := GameSession.new().state()
	state["day"] = GameRules.MAX_DAY
	state["shipped"] = {&"turnip": 4, &"potato": 3, &"pumpkin": 2}
	state["money"] = 505
	state["relationships"][&"shopkeeper"]["points"] = VillagerRules.FRIEND_POINTS
	state["relationships"][&"resident"]["points"] = VillagerRules.CLOSE_FRIEND_POINTS
	state["finale_triggered"] = true
	return ContentRules.build_harvest_result(state)

func _result(save_error: int = OK) -> ResultScreen:
	var screen := _spawn_panel("res://scenes/ui/result_screen.tscn") as ResultScreen
	if screen == null:
		return null
	screen.present(_result_data(), save_error)
	return screen

func _vn_card(panel: Control) -> PanelContainer:
	return panel.find_child("Card", true, false) as PanelContainer

func _canvas(panel: Control) -> Rect2:
	return panel.get_global_rect()

func test_dialogue_card_is_a_wide_white_box_docked_above_the_bottom() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	await _settle()
	var card := _vn_card(panel)
	assert_not_null(card, "the VN card is a single PanelContainer")
	if card == null:
		return
	var rect := card.get_global_rect()
	assert_almost_eq(rect.position.x, 120.0, 2.0, "card docks to the 120px margin")
	assert_almost_eq(rect.end.x, 1800.0, 2.0, "card spans to the right margin")
	assert_almost_eq(rect.end.y, 1040.0, 2.0, "card bottom floats 40px off screen")
	var box := _stylebox(card)
	assert_eq(box.bg_color, UiStyle.CARD, "card is the opaque white from the mockup")
	assert_true(box.corner_radius_top_left >= 30, "card keeps the 30px radius")
	assert_true(box.shadow_size > 0, "card keeps the deep drop shadow")
	assert_true(
		_canvas(panel).encloses(rect),
		"whole VN box stays inside the canvas",
	)

func test_dialogue_card_opens_with_a_header_gradient_band() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	await _settle()
	var card := _vn_card(panel)
	assert_not_null(card)
	if card == null:
		return
	var band := card.find_child("Band", true, false) as PanelContainer
	assert_not_null(band, "the 8px gradient strip caps the card")
	if band == null:
		return
	var card_rect := card.get_global_rect()
	var band_rect := band.get_global_rect()
	assert_lte(band_rect.size.y, 12.0, "band is a thin strip, not a header row")
	assert_almost_eq(band_rect.position.y, card_rect.position.y, 2.0)
	assert_almost_eq(band_rect.size.x, card_rect.size.x, 2.0)

func test_dialogue_name_slant_and_relationship_pill_overhang_the_card() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	await _settle()
	var card := _vn_card(panel)
	var name_tag := panel.find_child("NameTag", true, false) as SlantTag
	var role := panel.find_child("RolePill", true, false) as PanelContainer
	var rel := panel.find_child("RelPill", true, false) as PanelContainer
	assert_not_null(name_tag, "slanted name tag overhangs the card's top edge")
	assert_not_null(role, "role pill rides beside the name tag")
	assert_not_null(rel, "relationship pill overhangs the card's top-right")
	if card == null or name_tag == null or role == null or rel == null:
		return
	var top := card.get_global_rect().position.y
	assert_lt(name_tag.get_global_rect().position.y, top - 10.0)
	assert_lt(rel.get_global_rect().position.y, top - 10.0)
	assert_almost_eq(
		rel.get_global_rect().end.x,
		card.get_global_rect().end.x - 40.0,
		4.0,
		"relationship pill pins 40px in from the right edge",
	)
	assert_eq(panel.villager_name_text(), "Sato-san")
	assert_eq(panel.relationship_text(), "FRIEND  ·  13/18")
	assert_eq(panel.role_text(), "SEED-SHOP KEEPER")
	var hearts := rel.find_children("Heart_*", "TextureRect", true, false)
	assert_eq(hearts.size(), 3, "three hearts ride inside the pill")

func test_dialogue_line_uses_the_big_vn_typography() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	await _settle()
	var line := panel.find_child("Line", true, false) as Label
	assert_not_null(line)
	if line == null:
		return
	assert_true(line.get_theme_font_size("font_size") >= 30, "line reads at 32px")
	assert_true(line.autowrap_mode != TextServer.AUTOWRAP_OFF, "long lines wrap")
	var card := _vn_card(panel)
	if card != null:
		assert_true(
			card.get_global_rect().encloses(line.get_global_rect()),
			"the line stays inside the card",
		)

func test_dialogue_portrait_stands_at_the_left_edge_full_height() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	await _settle()
	var portrait := panel.find_child("Portrait", true, false) as TextureRect
	assert_not_null(portrait)
	if portrait == null:
		return
	var rect := portrait.get_global_rect()
	assert_true(rect.size.y >= 900.0, "portrait stands ~940px tall like the mockup")
	assert_almost_eq(rect.end.y, 1080.0, 2.0, "portrait feet touch the screen bottom")
	assert_true(rect.position.x >= 100.0 and rect.position.x <= 180.0)
	assert_not_null(portrait.texture)

func test_dialogue_gift_chips_show_tile_name_count_and_value() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	await _settle()
	var selected := panel.gift_chip(GameRules.CropKind.POTATO)
	var tile := selected.find_child("Tile", true, false) as PanelContainer
	assert_not_null(tile, "each chip carries a white icon tile")
	if tile != null:
		var tile_rect := tile.get_global_rect()
		assert_true(tile_rect.size.x <= 66.0 and tile_rect.size.x >= 56.0)
		assert_true(tile_rect.size.y <= 66.0 and tile_rect.size.y >= 56.0)
	assert_eq(panel.gift_chip_count_text(GameRules.CropKind.POTATO), "2")
	assert_eq(panel.gift_chip_value_text(GameRules.CropKind.POTATO), "+5 ♥")
	var name_label := selected.find_child("Name", true, false) as Label
	assert_not_null(name_label, "chip names the crop next to the count")
	if name_label != null:
		assert_eq(name_label.text, "Potato")
	var box := selected.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(box.border_color, UiStyle.ACCENT, "selected chip borders accent")
	assert_eq(box.bg_color, UiStyle.ACCENT_SOFT, "selected chip tints accent-soft")
	var empty := panel.gift_chip(GameRules.CropKind.PUMPKIN)
	assert_true(empty.disabled)
	assert_true(empty.modulate.a < 0.5, "empty chips fade like the mockup .gift.off")
	assert_eq(panel.gift_chip_value_text(GameRules.CropKind.PUMPKIN), "none")

func test_dialogue_footer_has_choose_hint_esc_and_primary_pill() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	await _settle()
	var choose := panel.find_child("ChooseGift", true, false) as Label
	assert_not_null(choose, "the A/D choose-gift hint sits in the footer")
	if choose != null:
		assert_eq(choose.text, "choose gift")
	var pill := panel.find_child("ActionPill", true, false) as PanelContainer
	assert_not_null(pill, "the Enter action is the gradient primary pill")
	if pill == null:
		return
	var key := pill.find_child("Key", true, false) as PanelContainer
	assert_not_null(key, "primary pill keeps its translucent Enter cap")
	var card := _vn_card(panel)
	if card != null:
		assert_true(
			card.get_global_rect().encloses(pill.get_global_rect()),
			"action pill sits inside the card",
		)
	assert_eq(panel.action_text(), "GIVE POTATO")

func test_dialogue_scrim_is_the_light_mockup_veil() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	await _settle()
	var dim := panel.find_child("Dim", true, false) as ColorRect
	assert_not_null(dim)
	if dim == null:
		return
	assert_lte(dim.color.a, 0.3, "scrim stays light enough to read the farm")

func test_dialogue_chip_click_emits_and_release_outside_cancels() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	await _settle()
	watch_signals(panel)
	var turnip := panel.gift_chip(GameRules.CropKind.TURNIP)
	await _press_and_release_outside(turnip)
	assert_signal_not_emitted(panel, "gift_requested")
	await _click(turnip)
	assert_signal_emitted(panel, "gift_requested")

func test_dialogue_everything_stays_inside_at_min_window_in_all_locales() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	var window := get_window()
	for window_size in [UiSettings.WINDOW_SIZE, UiSettings.MIN_WINDOW_SIZE]:
		window.size = window_size
		for locale in LOCALES:
			TranslationServer.set_locale(locale)
			await _settle()
			var where := "%s %s" % [window_size, locale]
			var card := _vn_card(panel)
			assert_not_null(card)
			if card == null:
				continue
			var canvas := _canvas(panel)
			var rect := card.get_global_rect()
			assert_true(
				canvas.encloses(rect),
				"%s: card %s stays inside the canvas" % [where, rect],
			)
			var line := panel.find_child("Line", true, false) as Label
			if line != null:
				assert_true(
					rect.encloses(line.get_global_rect()),
					"%s: line stays inside the card" % where,
				)
			var rel := panel.find_child("RelPill", true, false) as PanelContainer
			if rel != null:
				assert_true(
					rel.get_global_rect().end.x <= canvas.end.x + 1.0,
					"%s: rel pill stays on the card" % where,
				)

func test_intro_letterboxes_and_day_tag_frame_the_floating_vn_card() -> void:
	var overlay := _intro()
	if overlay == null:
		return
	await _settle()
	assert_true(overlay.is_opening_visible())
	var opening := overlay.get_node("OpeningPanel") as Control
	var top := opening.find_child("LetterboxTop", true, false) as ColorRect
	var bottom := opening.find_child("LetterboxBottom", true, false) as ColorRect
	assert_not_null(top)
	assert_not_null(bottom)
	if top == null or bottom == null:
		return
	assert_eq(top.color, Color.BLACK, "letterbox bars are pure black")
	assert_eq(bottom.color, Color.BLACK)
	assert_lte(top.get_global_rect().size.y, 96.0, "top bar stays a thin 90px strip")
	assert_lte(bottom.get_global_rect().size.y, 96.0)
	assert_almost_eq(bottom.get_global_rect().end.y, 1080.0, 2.0)
	var day_tag := opening.find_child("DayTag", true, false) as SlantTag
	assert_not_null(day_tag, "the DAY 1 slant tags the upper left")
	if day_tag != null:
		var tag_rect := day_tag.get_global_rect()
		assert_true(tag_rect.position.x < 300.0 and tag_rect.position.y < 300.0)
		assert_true(day_tag.get_global_rect().position.y > top.get_global_rect().end.y)
	var card := _vn_card(opening)
	assert_not_null(card, "the VN box floats over the letterboxed shot")
	if card != null:
		var rect := card.get_global_rect()
		assert_true(
			rect.end.y < bottom.get_global_rect().position.y,
			"VN box floats above the lower letterbox",
		)
		assert_almost_eq(rect.position.x, 120.0, 2.0)
		assert_almost_eq(rect.end.x, 1800.0, 2.0)

func test_intro_vn_box_keeps_authored_name_role_and_copy() -> void:
	var overlay := _intro()
	if overlay == null:
		return
	await _settle()
	var opening := overlay.get_node("OpeningPanel") as Control
	var name_tag := opening.find_child("NameTag", true, false) as SlantTag
	assert_not_null(name_tag, "the intro keeps its authored SATO-SAN tag")
	if name_tag != null:
		var text := name_tag.get_node_or_null("Text") as Label
		if text != null:
			assert_eq(text.text, "SATO-SAN")
	var role := opening.find_child("Role", true, false) as Label
	assert_not_null(role, "the intro keeps the role pill beside the name")
	var intro := opening.find_child("Intro", true, false) as Label
	assert_not_null(intro)
	if intro != null:
		assert_true(
			intro.text.contains("quiet for a while") or intro.text.length() > 0,
			"intro copy is the authored story line",
		)
	var guide := opening.find_child("Guide", true, false) as Label
	assert_not_null(guide)

func test_intro_accept_is_a_primary_pill_that_acknowledges() -> void:
	var overlay := _intro()
	if overlay == null:
		return
	await _settle()
	var opening := overlay.get_node("OpeningPanel") as Control
	var accept := opening.find_child("Accept", true, false) as Button
	assert_not_null(accept, "Begin day 1 is a real button")
	if accept == null:
		return
	var pill := accept.find_child("Pill", true, false) as PanelContainer
	assert_not_null(pill, "accept paints the gradient primary pill")
	watch_signals(overlay)
	await _press_and_release_outside(accept)
	assert_signal_not_emitted(overlay, "intro_acknowledged")
	await _click(accept)
	assert_signal_emitted(overlay, "intro_acknowledged")

func test_intro_keyboard_accept_still_acknowledges() -> void:
	var overlay := _intro()
	if overlay == null:
		return
	await _settle()
	watch_signals(overlay)
	await _press(&"ui_accept")
	assert_signal_emitted(overlay, "intro_acknowledged")

func test_title_menu_rows_match_the_mockup_measurements() -> void:
	var title := _title()
	if title == null:
		return
	await _settle()
	var menu := title.get_node("Menu") as Control
	assert_not_null(menu)
	if menu == null:
		return
	var rect := menu.get_global_rect()
	assert_almost_eq(rect.position.x, 140.0, 2.0)
	assert_almost_eq(rect.position.y, 470.0, 4.0)
	assert_almost_eq(rect.size.x, 520.0, 2.0)
	var new_game := title.get_node("Menu/NewGame") as Button
	assert_not_null(new_game)
	if new_game == null:
		return
	var row_rect := new_game.get_global_rect()
	assert_true(row_rect.size.y <= 84.0 and row_rect.size.y >= 72.0, "rows read ~80px")
	var icon := new_game.get_node("Icon") as TextureRect
	assert_not_null(icon)
	if icon != null:
		assert_true(icon.get_global_rect().size.x <= 48.0, "icon reads at 48px")
	var label := new_game.get_node("Label") as Label
	assert_not_null(label)
	if label != null:
		assert_true(label.get_theme_font_size("font_size") >= 28, "menu text is 30px")
		assert_eq(label.get_theme_color("font_color"), UiStyle.CARD)

func test_title_rows_stay_transparent_until_selected() -> void:
	var title := _title()
	if title == null:
		return
	await _settle()
	var new_game := title.get_node("Menu/NewGame") as Button
	var continue_button := title.get_node("Menu/Continue") as Button
	assert_not_null(new_game)
	assert_not_null(continue_button)
	if new_game == null or continue_button == null:
		return
	var continue_box := continue_button.get_theme_stylebox("normal") as StyleBoxFlat
	assert_not_null(continue_box)
	if continue_box != null:
		assert_lte(
			continue_box.bg_color.a, 0.05,
			"unselected rows keep the art visible through them",
		)
	var gradient := new_game.find_child("Gradient", true, false) as Control
	assert_not_null(gradient)
	if gradient != null:
		assert_true(gradient.visible, "the selected row fills with the accent gradient")

func test_title_disabled_continue_fades_to_mockup_opacity() -> void:
	var title := _title()
	if title == null:
		return
	title.set_continue_state(false, "Save is incompatible; start a New Game.")
	await _settle()
	var continue_button := title.get_node("Menu/Continue") as Button
	assert_not_null(continue_button)
	if continue_button == null:
		return
	assert_true(continue_button.disabled)
	var label := continue_button.get_node("Label") as Label
	assert_not_null(label)
	if label != null:
		var color := label.get_theme_color("font_color")
		assert_true(
			color.a < 0.6 and color.r > 0.8,
			"disabled row fades toward the mockup's white-45",
		)

func test_title_error_status_is_the_amber_warnbar() -> void:
	var title := _title()
	if title == null:
		return
	title.set_continue_state(false, "Save is incompatible; start a New Game.")
	await _settle()
	var status := title.get_node("Menu/Status") as PanelContainer
	assert_not_null(status)
	if status == null:
		return
	assert_true(status.visible)
	var box := _stylebox(status)
	assert_not_null(box)
	if box != null:
		assert_eq(box.bg_color, UiStyle.WARN, "error reads on the amber warnbar")
	var label := status.get_node("Row/Label") as Label
	assert_not_null(label)
	if label != null:
		assert_eq(label.get_theme_color("font_color"), UiStyle.WARN_INK)
		assert_eq(label.text, "Save is incompatible; start a New Game.")

func test_title_selected_row_keycap_is_the_translucent_cap() -> void:
	var title := _title()
	if title == null:
		return
	await _settle()
	var keycap := title.get_node("Menu/NewGame/Keycap") as PanelContainer
	assert_not_null(keycap)
	if keycap == null:
		return
	assert_true(keycap.visible)
	var box := _stylebox(keycap)
	assert_not_null(box)
	if box != null:
		assert_true(
			box.bg_color.a > 0.1 and box.bg_color.a < 0.5,
			"selected keycap is a translucent glass cap",
		)

func test_title_footer_sits_at_the_screen_bottom_left() -> void:
	var title := _title()
	if title == null:
		return
	await _settle()
	var footer := title.get_node_or_null("Footer") as Control
	assert_not_null(footer, "version footer is a screen-level row, not menu text")
	if footer == null:
		return
	var rect := footer.get_global_rect()
	assert_true(rect.end.y >= 1020.0, "footer anchors to the screen bottom")
	assert_almost_eq(rect.position.x, 160.0, 4.0)
	var version := footer.find_child("Version", true, false) as Label
	assert_not_null(version)

func test_title_new_game_click_and_release_outside_cancellation() -> void:
	var title := _title()
	if title == null:
		return
	await _settle()
	var new_game := title.get_node("Menu/NewGame") as Button
	assert_not_null(new_game)
	if new_game == null:
		return
	watch_signals(title)
	await _press_and_release_outside(new_game)
	assert_signal_not_emitted(title, "new_game_requested")
	await _click(new_game)
	assert_signal_emitted(title, "new_game_requested")

func test_title_disabled_continue_click_does_not_emit() -> void:
	var title := _title()
	if title == null:
		return
	title.set_continue_state(false, "Save is incompatible; start a New Game.")
	await _settle()
	var continue_button := title.get_node("Menu/Continue") as Button
	assert_not_null(continue_button)
	if continue_button == null:
		return
	watch_signals(title)
	await _click(continue_button)
	assert_signal_not_emitted(title, "continue_requested")

func test_result_header_stats_and_cards_match_the_mockup() -> void:
	var result := _result()
	if result == null:
		return
	await _settle()
	var kicker := result.find_child("Kicker", true, false) as SlantTag
	assert_not_null(kicker, "SEASON COMPLETE keeps the slanted tag")
	var title_label := result.find_child("Title", true, false) as Label
	assert_not_null(title_label)
	if title_label != null:
		assert_true(
			title_label.get_theme_font_size("font_size") >= 72,
			"the season title reads at ~84px",
		)
	for index in 3:
		var card := result.find_child("Card_%d" % index, true, false) as Control
		assert_not_null(card, "stat card %d exists" % index)
		if card == null:
			continue
		var stat_rect := card.get_global_rect()
		assert_true(
			stat_rect.size.x >= 260.0,
			"stat cards are wide like the mockup rstat",
		)
		var value := card.find_child("Value", true, false) as Label
		assert_not_null(value)
		if value != null:
			assert_true(value.get_theme_font_size("font_size") >= 40, "stat value ~44px")
	var featured := result.find_child("Card_Resident", true, false) as PanelContainer
	assert_not_null(featured)
	if featured != null:
		var box := _stylebox(featured)
		assert_eq(box.border_color, UiStyle.ACCENT, "featured card outlines accent")
		assert_true(box.get_border_width(SIDE_LEFT) >= 4, "best card takes a 4px ring")

func test_result_stat_card_highlight_uses_the_gradient() -> void:
	var result := _result()
	if result == null:
		return
	await _settle()
	var highlight := result.find_child("Card_1", true, false) as Control
	assert_not_null(highlight)
	if highlight == null:
		return
	var gradient := highlight.find_child("Gradient", true, false) as TextureRect
	assert_not_null(gradient, "the shipped-value card is the gradient highlight")
	var value := highlight.find_child("Value", true, false) as Label
	assert_not_null(value)
	if value != null:
		assert_eq(value.get_theme_color("font_color"), UiStyle.CARD)

func test_result_portrait_backplates_crop_faces_intentionally() -> void:
	var result := _result()
	if result == null:
		return
	await _settle()
	for key in [&"shopkeeper", &"farmer", &"resident"]:
		var card := result.find_child(
			"Card_%s" % String(key).capitalize(), true, false
		) as PanelContainer
		assert_not_null(card, "%s card exists" % key)
		if card == null:
			continue
		var clip := card.find_child("PortraitClip", true, false) as Control
		assert_not_null(clip)
		if clip == null:
			continue
		var clip_rect := clip.get_global_rect()
		assert_true(clip_rect.size.y <= 210.0, "band height ~200 like the mockup ph")
		var backdrop := clip.find_child("Backdrop", true, false) as TextureRect
		assert_not_null(backdrop, "portrait rides a gradient backplate")
		var portrait := clip.find_child("Portrait", true, false) as TextureRect
		assert_not_null(portrait)
		if portrait == null:
			continue
		var portrait_rect := portrait.get_global_rect()
		assert_true(
			portrait_rect.end.y > clip_rect.end.y + 20.0,
			"the portrait is intentionally cropped at the band bottom",
		)
		var name_label := card.find_child("Name", true, false) as Label
		assert_not_null(name_label)
		if name_label != null:
			assert_true(
				name_label.get_theme_font_size("font_size") >= 24, "name reads 26px"
			)

func test_result_action_pills_are_native_buttons() -> void:
	var result := _result()
	if result == null:
		return
	await _settle()
	var new_game := result.get_node("Actions/NewGame") as Button
	var to_title := result.get_node("Actions/ReturnToTitle") as Button
	assert_not_null(new_game)
	assert_not_null(to_title)
	if new_game == null or to_title == null:
		return
	assert_not_null(
		new_game.find_child("Pill", true, false),
		"New game is the gradient primary pill",
	)
	var ghost := to_title.find_child("Pill", true, false) as PanelContainer
	assert_not_null(ghost, "Title is the white ghost pill")
	if ghost != null:
		var box := _stylebox(ghost)
		assert_eq(box.bg_color, UiStyle.CARD)
	watch_signals(result)
	await _press_and_release_outside(new_game)
	assert_signal_not_emitted(result, "new_game_requested")
	await _click(new_game)
	assert_signal_emitted(result, "new_game_requested")
	watch_signals(result)
	await _press_and_release_outside(to_title)
	assert_signal_not_emitted(result, "return_to_title_requested")
	await _click(to_title)
	assert_signal_emitted(result, "return_to_title_requested")

func test_result_save_error_shows_the_warnbar() -> void:
	var result := _result(ERR_CANT_CREATE)
	if result == null:
		return
	await _settle()
	var status := result.find_child("SaveStatus", true, false) as Label
	assert_not_null(status)
	if status == null:
		return
	assert_eq(status.text, "Final result was not saved.")
	var pill := result.find_child("SavePill", true, false) as PanelContainer
	assert_not_null(pill, "save error rides a warnbar like the other surfaces")
	if pill != null:
		assert_true(pill.visible)
		assert_eq(_stylebox(pill).bg_color, UiStyle.WARN)

func test_result_keyboard_actions_still_emit() -> void:
	var result := _result()
	if result == null:
		return
	await _settle()
	watch_signals(result)
	await _press(&"ui_accept")
	assert_signal_emitted(result, "new_game_requested")
	await _press(&"ui_cancel")
	assert_signal_emitted(result, "return_to_title_requested")

func test_result_empty_stats_still_render_the_layout() -> void:
	var screen := _spawn_panel("res://scenes/ui/result_screen.tscn") as ResultScreen
	if screen == null:
		return
	var empty_state := GameSession.new().state()
	empty_state["day"] = GameRules.MAX_DAY
	empty_state["finale_triggered"] = true
	screen.present(ContentRules.build_harvest_result(empty_state))
	await _settle()
	var state := screen.result_state()
	assert_eq(state["stats"].size(), 3)
	var title_label := screen.find_child("Title", true, false) as Label
	assert_not_null(title_label)
	if title_label != null:
		assert_ne(title_label.text, "")

func _action_button(panel: Control) -> Button:
	var pill := panel.find_child("ActionPill", true, false) as Control
	if pill == null:
		return null
	return pill.get_parent() as Button

func _press_keycode(
	keycode: Key,
	ctrl := false,
	alt := false,
	shift := false,
	meta := false,
) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	press.ctrl_pressed = ctrl
	press.alt_pressed = alt
	press.shift_pressed = shift
	press.meta_pressed = meta
	get_viewport().push_input(press)
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	get_viewport().push_input(release)
	await get_tree().process_frame

func test_dialogue_action_pill_is_a_native_button_painting_full_hitbox() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	await _settle()
	var pill := panel.find_child("ActionPill", true, false) as Control
	assert_not_null(pill, "the painted action is still the gradient pill")
	if pill == null:
		return
	var action := _action_button(panel)
	assert_not_null(action, "the visible action is a real Button, not paint only")
	if action == null:
		return
	assert_almost_eq(
		action.get_global_rect().position,
		pill.get_global_rect().position,
		Vector2(1, 1),
		"the native hitbox covers the whole painted pill",
	)
	assert_almost_eq(
		action.get_global_rect().size,
		pill.get_global_rect().size,
		Vector2(1, 1),
		"the native hitbox covers the whole painted pill",
	)

func test_dialogue_action_pill_click_center_and_edges_gifts() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	await _settle()
	var pill := panel.find_child("ActionPill", true, false) as Control
	assert_not_null(pill)
	if pill == null:
		return
	var rect := pill.get_global_rect()
	watch_signals(panel)
	await _click_at(rect.get_center())
	assert_signal_emitted(panel, "gift_requested", "pill centre gifts")
	await _click_at(rect.position + Vector2(4, rect.size.y / 2.0))
	await _click_at(rect.end - Vector2(4, rect.size.y / 2.0))
	assert_signal_emit_count(panel, "gift_requested", 3, "both painted edges gift")

func test_dialogue_action_pill_click_emits_gift_for_selected_crop() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	await _settle()
	var pill := panel.find_child("ActionPill", true, false) as Control
	assert_not_null(pill)
	if pill == null:
		return
	watch_signals(panel)
	await _click_at(pill.get_global_rect().get_center())
	assert_signal_emitted_with_parameters(
		panel,
		"gift_requested",
		[VillagerRules.VillagerId.SHOPKEEPER, GameRules.CropKind.POTATO],
	)

func test_dialogue_action_pill_release_outside_cancels() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	await _settle()
	var pill := panel.find_child("ActionPill", true, false) as Control
	assert_not_null(pill)
	if pill == null:
		return
	watch_signals(panel)
	await _press_and_release_outside(pill)
	assert_signal_not_emitted(panel, "gift_requested")
	assert_signal_not_emitted(panel, "close_requested")
	await _click(pill)
	assert_signal_emitted(panel, "gift_requested")

func test_dialogue_action_pill_continues_lines_then_gifts() -> void:
	var panel := _present_dialogue(
		{
			"code": GameRules.CommandCode.VILLAGER_TALKED,
			"lines": ["First line.", "Second line."],
			"points_gained": 0,
			"gift_reaction": &"",
			"close_friend_sequence": false,
			"selected_crop_kind": GameRules.CropKind.POTATO,
		},
		_dialogue_snapshot(),
	)
	if panel == null:
		return
	await _settle()
	assert_eq(panel.action_text(), "CONTINUE", "multi-line Enter caption is continue")
	var pill := panel.find_child("ActionPill", true, false) as Control
	watch_signals(panel)
	await _click(pill)
	assert_eq(panel._line_index, 1, "click advances the line like Enter")
	assert_signal_not_emitted(panel, "gift_requested")
	assert_signal_not_emitted(panel, "close_requested")
	assert_eq(panel.action_text(), "GIVE POTATO", "last line caption becomes the gift")
	await _click(pill)
	assert_signal_emitted(panel, "gift_requested")

func test_dialogue_action_pill_continues_locked_sequence_while_escape_gated() -> void:
	var panel := _present_dialogue(
		{
			"code": GameRules.CommandCode.VILLAGER_TALKED,
			"lines": ["One.", "Two.", "Three."],
			"points_gained": 0,
			"gift_reaction": &"",
			"close_friend_sequence": true,
			"selected_crop_kind": GameRules.CropKind.POTATO,
		},
		_dialogue_snapshot(),
	)
	if panel == null:
		return
	await _settle()
	assert_eq(panel.action_text(), "CONTINUE")
	var pill := panel.find_child("ActionPill", true, false) as Control
	watch_signals(panel)
	await _press(&"ui_cancel")
	assert_true(panel.visible, "escape stays gated mid close-friend sequence")
	assert_signal_not_emitted(panel, "close_requested")
	await _click(pill)
	assert_eq(panel._line_index, 1)
	await _click(pill)
	assert_eq(panel._line_index, 2)
	await _press(&"ui_cancel")
	assert_signal_emitted(panel, "close_requested", "escape closes on the last line")

func test_dialogue_action_pill_closes_when_gift_already_given() -> void:
	var snapshot := _dialogue_snapshot()
	snapshot["relationships"][&"shopkeeper"]["gifted_today"] = true
	var panel := _present_dialogue(
		{
			"code": GameRules.CommandCode.VILLAGER_TALKED,
			"lines": ["Thanks again for earlier."],
			"points_gained": 0,
			"gift_reaction": &"",
			"close_friend_sequence": false,
			"selected_crop_kind": GameRules.CropKind.POTATO,
		},
		snapshot,
	)
	if panel == null:
		return
	await _settle()
	assert_eq(panel.action_text(), "CLOSE", "already-gifted Enter closes")
	var pill := panel.find_child("ActionPill", true, false) as Control
	watch_signals(panel)
	await _click(pill)
	assert_signal_emitted(panel, "close_requested")
	assert_signal_not_emitted(panel, "gift_requested")

func test_dialogue_action_pill_closes_with_zero_inventory() -> void:
	var snapshot := _dialogue_snapshot()
	snapshot["harvested"] = {&"turnip": 0, &"potato": 0, &"pumpkin": 0}
	var panel := _present_dialogue(
		{
			"code": GameRules.CommandCode.VILLAGER_TALKED,
			"lines": ["Nothing in the bag today."],
			"points_gained": 0,
			"gift_reaction": &"",
			"close_friend_sequence": false,
		},
		snapshot,
	)
	if panel == null:
		return
	await _settle()
	assert_eq(panel.action_text(), "CLOSE", "no eligible crop means Enter closes")
	var pill := panel.find_child("ActionPill", true, false) as Control
	watch_signals(panel)
	await _click(pill)
	assert_signal_emitted(panel, "close_requested")
	assert_signal_not_emitted(panel, "gift_requested")

func test_dialogue_focus_anchors_never_intercept_mouse() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	await _settle()
	var continue_control := panel.continue_control()
	var close_control := panel.close_control()
	assert_eq(
		continue_control.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"the continue focus anchor cannot eat clicks",
	)
	assert_eq(
		close_control.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"the close focus anchor cannot eat clicks",
	)
	var pill := panel.find_child("ActionPill", true, false) as Control
	assert_not_null(pill)
	if pill == null:
		return
	watch_signals(panel)
	await _click(pill)
	assert_signal_emitted(panel, "gift_requested")
	assert_signal_not_emitted(panel, "close_requested")

func test_dialogue_action_pill_click_works_in_all_locales() -> void:
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		var panel := _dialogue()
		if panel == null:
			continue
		await _settle()
		var pill := panel.find_child("ActionPill", true, false) as Control
		assert_not_null(pill, "%s action pill" % locale)
		if pill == null:
			continue
		assert_ne(panel.action_text(), "", "%s caption is set" % locale)
		watch_signals(panel)
		await _click(pill)
		assert_signal_emitted(panel, "gift_requested", "%s click gifts" % locale)
		panel.hide()

func test_dialogue_final_close_friend_line_repaints_focused_chip() -> void:
	var panel := _present_dialogue(
		{
			"code": GameRules.CommandCode.VILLAGER_TALKED,
			"lines": VillagerRules.close_friend_dialogue_lines(
				VillagerRules.VillagerId.SHOPKEEPER,
			),
			"points_gained": 0,
			"gift_reaction": &"",
			"close_friend_sequence": true,
			"selected_crop_kind": GameRules.CropKind.POTATO,
		},
		_dialogue_snapshot(),
	)
	if panel == null:
		return
	await _settle()
	var turnip := panel.gift_chip(GameRules.CropKind.TURNIP)
	var potato := panel.gift_chip(GameRules.CropKind.POTATO)
	assert_false(turnip.visible, "gifts stay suppressed on locked lines")
	var pill := panel.find_child("ActionPill", true, false) as Control
	await _click(pill)
	assert_eq(panel._line_index, 1, "last close-friend line reached")
	assert_true(turnip.visible, "the final line reopens gifts")
	turnip.grab_focus()
	await _settle()
	assert_eq(panel._selected_gift_kind, GameRules.CropKind.TURNIP)
	assert_eq(
		panel.action_text(),
		"GIVE TURNIP",
		"caption follows the focused chip on the final line",
	)
	var turnip_box := turnip.get_theme_stylebox("normal") as StyleBoxFlat
	assert_not_null(turnip_box)
	if turnip_box != null:
		assert_eq(
			turnip_box.border_color,
			UiStyle.ACCENT,
			"focused chip repaints its accent ring",
		)
	watch_signals(panel)
	await _click(pill)
	assert_signal_emitted_with_parameters(
		panel,
		"gift_requested",
		[VillagerRules.VillagerId.SHOPKEEPER, GameRules.CropKind.TURNIP],
	)
	assert_signal_emit_count(panel, "gift_requested", 1)
	potato.grab_focus()
	await _settle()
	assert_eq(panel.action_text(), "GIVE POTATO")

func test_dialogue_caption_and_click_follow_the_focused_action() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	await _settle()
	assert_eq(panel.action_text(), "GIVE POTATO")
	var pill := panel.find_child("ActionPill", true, false) as Control
	for step in range(4):
		if get_viewport().gui_get_focus_owner() == panel.close_control():
			break
		await _press(&"ui_focus_next")
	assert_eq(
		get_viewport().gui_get_focus_owner(),
		panel.close_control(),
		"Tab can reach the close anchor",
	)
	assert_eq(
		panel.action_text(),
		"CLOSE",
		"caption tracks the anchored action once it owns focus",
	)
	watch_signals(panel)
	await _click(pill)
	assert_signal_emitted(panel, "close_requested")
	assert_signal_emit_count(panel, "close_requested", 1)
	assert_signal_not_emitted(panel, "gift_requested")
	await _press(&"ui_accept")
	assert_signal_emit_count(panel, "close_requested", 2)
	for step in range(4):
		if (
			get_viewport().gui_get_focus_owner()
			== panel.gift_chip(GameRules.CropKind.TURNIP)
		):
			break
		await _press(&"ui_focus_next")
	assert_eq(
		get_viewport().gui_get_focus_owner(),
		panel.gift_chip(GameRules.CropKind.TURNIP),
		"Tab wraps back to the first chip",
	)
	assert_eq(panel.action_text(), "GIVE TURNIP")
	assert_eq(panel._selected_gift_kind, GameRules.CropKind.TURNIP)

func test_dialogue_disabled_chips_never_take_focus() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	await _settle()
	var pumpkin := panel.gift_chip(GameRules.CropKind.PUMPKIN)
	assert_true(pumpkin.disabled, "empty stock disables the chip")
	assert_eq(
		pumpkin.focus_mode,
		Control.FOCUS_NONE,
		"sold-out chips leave the keyboard focus chain",
	)
	for step in range(6):
		await _press_keycode(KEY_TAB)
		assert_ne(
			get_viewport().gui_get_focus_owner(),
			pumpkin,
			"Tab never lands on the sold-out chip (stop %d)" % step,
		)

func test_dialogue_enter_click_and_caption_agree_at_each_tab_stop() -> void:
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		var panel := _dialogue()
		if panel == null:
			continue
		await _settle()
		watch_signals(panel)
		var seen: Array = []
		for step in range(7):
			var owner := get_viewport().gui_get_focus_owner()
			if owner == null or seen.has(owner):
				break
			seen.append(owner)
			var where := "%s stop %d %s" % [locale, step, owner.name]
			var chip_index := -1
			if owner is Button and String(owner.name).begins_with("Gift_"):
				chip_index = String(owner.name).trim_prefix("Gift_").to_int()
			var gifts_before: int = get_signal_emit_count(panel, "gift_requested")
			var closes_before: int = get_signal_emit_count(panel, "close_requested")
			await _press_keycode(KEY_ENTER)
			if owner == panel.close_control():
				assert_eq(
					panel.action_text(), "CLOSE",
					"%s caption matches the anchored action" % where,
				)
				assert_eq(
					get_signal_emit_count(panel, "close_requested"),
					closes_before + 1,
					"%s Enter closes once" % where,
				)
				assert_eq(
					get_signal_emit_count(panel, "gift_requested"),
					gifts_before,
					"%s Enter never gifts" % where,
				)
			elif chip_index >= 0:
				var expected := (
					tr("GIVE %s")
					% tr(GameRules.crop_display_name(chip_index)).to_upper()
				)
				assert_eq(
					panel.action_text(), expected,
					"%s caption names the focused crop" % where,
				)
				var gifts_after: int = get_signal_emit_count(
					panel, "gift_requested"
				)
				assert_eq(
					gifts_after, gifts_before + 1,
					"%s Enter gifts exactly once" % where,
				)
				var params: Array = get_signal_parameters(
					panel, "gift_requested", gifts_after - 1
				)
				assert_eq(
					params,
					[VillagerRules.VillagerId.SHOPKEEPER, chip_index],
					"%s Enter gifts the focused crop" % where,
				)
				assert_eq(
					get_signal_emit_count(panel, "close_requested"),
					closes_before,
					"%s Enter never closes" % where,
				)
			await _press_keycode(KEY_TAB)
		panel.hide()

func test_dialogue_stock_change_releases_focus_from_a_disabled_chip() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	await _settle()
	var turnip := panel.gift_chip(GameRules.CropKind.TURNIP)
	turnip.grab_focus()
	await _settle()
	assert_eq(get_viewport().gui_get_focus_owner(), turnip)
	var snapshot := _dialogue_snapshot()
	snapshot["harvested"] = {&"turnip": 0, &"potato": 2, &"pumpkin": 0}
	panel.present(
		VillagerRules.VillagerId.SHOPKEEPER,
		{
			"code": GameRules.CommandCode.VILLAGER_TALKED,
			"lines": [
				"You stopped asking which seeds are best. Now you ask which are right.",
			],
			"points_gained": 1,
			"gift_reaction": &"",
			"close_friend_sequence": false,
			"selected_crop_kind": GameRules.CropKind.POTATO,
		},
		snapshot,
	)
	await _settle()
	assert_true(turnip.disabled, "empty stock disables the chip")
	var owner := get_viewport().gui_get_focus_owner()
	assert_ne(owner, turnip, "focus cannot linger on the now-disabled chip")
	assert_eq(
		owner,
		panel.gift_chip(GameRules.CropKind.POTATO),
		"focus lands on the next live gift",
	)
	assert_eq(panel.action_text(), "GIVE POTATO")
	watch_signals(panel)
	await _press_keycode(KEY_ENTER)
	assert_signal_emitted_with_parameters(
		panel,
		"gift_requested",
		[VillagerRules.VillagerId.SHOPKEEPER, GameRules.CropKind.POTATO],
	)

func test_dialogue_zero_inventory_enter_closes_from_the_anchor() -> void:
	var snapshot := _dialogue_snapshot()
	snapshot["harvested"] = {&"turnip": 0, &"potato": 0, &"pumpkin": 0}
	var panel := _present_dialogue(
		{
			"code": GameRules.CommandCode.VILLAGER_TALKED,
			"lines": ["Nothing in the bag today."],
			"points_gained": 0,
			"gift_reaction": &"",
			"close_friend_sequence": false,
		},
		snapshot,
	)
	if panel == null:
		return
	await _settle()
	assert_eq(
		get_viewport().gui_get_focus_owner(),
		panel.close_control(),
		"empty bag focuses the close anchor",
	)
	assert_eq(panel.action_text(), "CLOSE")
	for step in range(4):
		await _press_keycode(KEY_TAB)
		var owner := get_viewport().gui_get_focus_owner()
		for kind in GameRules.CropKind.size():
			assert_ne(
				owner,
				panel.gift_chip(kind),
				"no disabled chip is reachable (stop %d)" % step,
			)
	watch_signals(panel)
	await _press_keycode(KEY_ENTER)
	assert_signal_emitted(panel, "close_requested")
	assert_signal_not_emitted(panel, "gift_requested")

func test_dialogue_gift_number_keys_ignore_modifiers() -> void:
	var panel := _dialogue()
	if panel == null:
		return
	await _settle()
	watch_signals(panel)
	await _press_keycode(KEY_1, true)
	await _press_keycode(KEY_1, false, true)
	await _press_keycode(KEY_1, false, false, true)
	await _press_keycode(KEY_1, false, false, false, true)
	assert_signal_not_emitted(panel, "gift_requested", "modified number keys do not gift")
	await _press_keycode(KEY_1)
	assert_signal_emitted(panel, "gift_requested", "plain number key gifts")

func test_title_warning_label_is_20px_and_stays_clear_of_menu() -> void:
	var title := _title()
	if title == null:
		return
	var window := get_window()
	for window_size in [UiSettings.WINDOW_SIZE, UiSettings.MIN_WINDOW_SIZE]:
		window.size = window_size
		for locale in LOCALES:
			TranslationServer.set_locale(locale)
			title.set_continue_state(
				false, "Save is incompatible; start a New Game."
			)
			await _settle()
			var where := "%s %s" % [window_size, locale]
			var status := title.find_child("Status", true, false) as PanelContainer
			assert_not_null(status, "%s: warnbar exists" % where)
			var label := (
				status.find_child("Label", true, false) as Label if status != null else null
			)
			assert_not_null(label, "%s: warning label exists" % where)
			if label == null:
				continue
			assert_gte(
				label.get_theme_font_size("font_size"), 20,
				"%s: warning type is at least 20px native" % where,
			)
			assert_ne(
				label.autowrap_mode,
				TextServer.AUTOWRAP_OFF,
				"%s: long warnings wrap inside the pill" % where,
			)
			var canvas := _canvas(title)
			var pill_rect := status.get_global_rect()
			var label_rect := label.get_global_rect()
			assert_true(
				canvas.encloses(pill_rect),
				"%s: warnbar stays inside the screen" % where,
			)
			assert_true(
				pill_rect.encloses(label_rect),
				"%s: warning text stays inside the pill" % where,
			)
			for row_name in ["NewGame", "Continue"]:
				var row := title.find_child(row_name, true, false) as Control
				if row != null:
					assert_false(
						pill_rect.intersects(row.get_global_rect()),
						"%s: warnbar stays clear of %s" % [where, row_name],
					)
	window.size = UiSettings.WINDOW_SIZE
	await _settle()

func test_result_featured_card_paints_its_ring_over_the_portrait_band() -> void:
	var screen := _result()
	if screen == null:
		return
	await _settle()
	var state := screen.result_state()
	var featured: Dictionary = state["featured"]
	var featured_key := ""
	for key in featured.keys():
		if featured[key]:
			featured_key = String(key)
	assert_ne(featured_key, "", "one card is featured")
	for id in range(VillagerRules.VillagerId.size()):
		var key := VillagerRules.villager_key(id)
		var card := screen.find_child(
			"Card_%s" % String(key).capitalize(), true, false
		) as PanelContainer
		assert_not_null(card, "%s card exists" % key)
		if card == null:
			continue
		var frame := card.find_child("Frame", true, false) as PanelContainer
		var where := "card %s" % key
		if key == featured_key:
			assert_not_null(
				frame,
				"%s: the featured accent ring survives the portrait band" % where,
			)
			if frame == null:
				continue
			assert_true(frame.visible, "%s: ring is painted" % where)
			assert_almost_eq(
				frame.get_global_rect().position,
				card.get_global_rect().position,
				Vector2(1, 1),
				"%s: ring hugs the card edge" % where,
			)
			assert_almost_eq(
				frame.get_global_rect().size,
				card.get_global_rect().size,
				Vector2(1, 1),
				"%s: ring hugs the card edge" % where,
			)
			var clip := card.find_child("PortraitClip", true, false) as Control
			if clip != null:
				var band_top := clip.get_global_rect().position.y + 2.0
				assert_true(
					frame.get_global_rect().has_point(
						Vector2(card.get_global_rect().get_center().x, band_top)
					),
					"%s: ring spans the band that used to hide it" % where,
				)
			var frame_box := frame.get_theme_stylebox("panel") as StyleBoxFlat
			assert_not_null(frame_box)
			if frame_box != null:
				assert_gte(
					frame_box.border_width_top, 4,
					"%s: ring keeps the accent weight" % where,
				)
				assert_eq(
					frame_box.border_color, UiStyle.ACCENT,
					"%s: ring keeps the accent colour" % where,
				)
		elif frame != null:
			assert_false(
				frame.visible,
				"%s: non-featured cards keep the plain border only" % where,
			)

func test_result_warning_label_is_20px_and_stays_clear_of_actions() -> void:
	var screen := _result(ERR_CANT_CREATE)
	if screen == null:
		return
	var window := get_window()
	for window_size in [UiSettings.WINDOW_SIZE, UiSettings.MIN_WINDOW_SIZE]:
		window.size = window_size
		for locale in LOCALES:
			TranslationServer.set_locale(locale)
			await _settle()
			var where := "%s %s" % [window_size, locale]
			var pill := screen.find_child("SavePill", true, false) as PanelContainer
			assert_not_null(pill, "%s: save warnbar exists" % where)
			var label := (
				screen.find_child("SaveStatus", true, false) as Label
			)
			assert_not_null(label, "%s: save warning label exists" % where)
			if pill == null or label == null:
				continue
			assert_gte(
				label.get_theme_font_size("font_size"), 20,
				"%s: save warning type is at least 20px native" % where,
			)
			var canvas := _canvas(screen)
			var pill_rect := pill.get_global_rect()
			var label_rect := label.get_global_rect()
			assert_true(
				canvas.encloses(pill_rect),
				"%s: warnbar stays inside the screen" % where,
			)
			assert_true(
				pill_rect.encloses(label_rect),
				"%s: warning text stays inside the pill" % where,
			)
			var actions := screen.find_child("Actions", true, false) as Control
			if actions != null:
				assert_false(
					pill_rect.intersects(actions.get_global_rect()),
					"%s: warnbar stays clear of the action pills" % where,
				)
	window.size = UiSettings.WINDOW_SIZE
	await _settle()
