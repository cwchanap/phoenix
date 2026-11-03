extends GutTest

const LOCALES := ["en", "zh_TW", "ja"]
const SETTINGS_TEST_PATH := "user://phoenix-phone-panels-settings.cfg"

func after_each() -> void:
	TranslationServer.set_locale("en")
	if FileAccess.file_exists(SETTINGS_TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_TEST_PATH))

func _spawn_panel(scene: String) -> Control:
	var panel := (load(scene) as PackedScene).instantiate() as Control
	assert_not_null(panel)
	if panel == null:
		return null
	add_child_autoqfree(panel)
	return panel

func _snapshot() -> Dictionary:
	var session := GameSession.new()
	var state := session.state()
	state["seeds"] = {&"turnip": 3, &"potato": 0, &"pumpkin": 0}
	state["harvested"] = {&"turnip": 7, &"potato": 2, &"pumpkin": 0}
	state["pending_shipment"] = {&"turnip": 1, &"potato": 2, &"pumpkin": 1}
	assert_true(session.restore_state(state))
	return session.snapshot()

func _crop(kind: StringName, growth: int) -> Dictionary:
	return {
		"kind": kind,
		"growth": growth,
		"dry_nights": 0,
		"watered_today": false,
	}

func _calendar_snapshot() -> Dictionary:
	var session := GameSession.new()
	var state := session.state()
	state["day"] = 3
	state["weather"] = &"sunny"
	state["weather_history"] = [&"sunny", &"rainy", &"sunny"]
	var farm: Array = state["farm"]
	farm[0]["tilled"] = true
	farm[0]["crop"] = _crop(&"turnip", 0)
	farm[1]["tilled"] = true
	farm[1]["crop"] = _crop(&"potato", 2)
	farm[2]["tilled"] = true
	farm[2]["crop"] = _crop(&"pumpkin", 1)
	state["farm"] = farm
	assert_true(session.restore_state(state))
	return session.snapshot()

func _busy_calendar_snapshot() -> Dictionary:
	var session := GameSession.new()
	var state := session.state()
	state["day"] = 1
	state["weather"] = &"sunny"
	state["weather_history"] = [&"sunny"]
	var farm: Array = state["farm"]
	var crops: Array[Dictionary] = [
		_crop(&"turnip", 3),
		_crop(&"turnip", 2),
		_crop(&"turnip", 1),
		_crop(&"turnip", 0),
		_crop(&"potato", 1),
		_crop(&"potato", 0),
		_crop(&"pumpkin", 1),
		_crop(&"pumpkin", 0),
	]
	for index in crops.size():
		farm[index]["tilled"] = true
		farm[index]["crop"] = crops[index]
	state["farm"] = farm
	assert_true(session.restore_state(state))
	return session.snapshot()

func _three_kind_snapshot() -> Dictionary:
	var session := GameSession.new()
	var state := session.state()
	state["day"] = 10
	state["weather"] = &"sunny"
	state["weather_history"] = []
	for _day in 10:
		state["weather_history"].append(&"sunny")
	var farm: Array = state["farm"]
	farm[0]["tilled"] = true
	farm[0]["crop"] = _crop(&"turnip", 0)
	farm[1]["tilled"] = true
	farm[1]["crop"] = _crop(&"potato", 2)
	farm[2]["tilled"] = true
	farm[2]["crop"] = _crop(&"pumpkin", 4)
	state["farm"] = farm
	assert_true(session.restore_state(state))
	return session.snapshot()

func _max_rows_snapshot() -> Dictionary:
	var session := GameSession.new()
	var state := session.state()
	state["day"] = 10
	state["weather"] = &"sunny"
	state["weather_history"] = []
	for _day in 10:
		state["weather_history"].append(&"sunny")
	var growths: Array[Array] = [
		[&"turnip", 2], [&"turnip", 1], [&"turnip", 0],
		[&"potato", 4], [&"potato", 3], [&"potato", 2], [&"potato", 1],
		[&"pumpkin", 6], [&"pumpkin", 5], [&"pumpkin", 4],
	]
	var farm: Array = state["farm"]
	for index in growths.size():
		farm[index]["tilled"] = true
		farm[index]["crop"] = _crop(growths[index][0], growths[index][1])
	state["farm"] = farm
	assert_true(session.restore_state(state))
	return session.snapshot()

func _season_end_snapshot() -> Dictionary:
	var session := GameSession.new()
	var state := session.state()
	state["day"] = GameRules.MAX_DAY
	state["weather"] = &"sunny"
	state["weather_history"] = []
	for _day in GameRules.MAX_DAY:
		state["weather_history"].append(&"sunny")
	var farm: Array = state["farm"]
	farm[0]["tilled"] = true
	farm[0]["crop"] = _crop(&"turnip", GameRules.growth_nights(GameRules.CropKind.TURNIP))
	farm[1]["tilled"] = true
	farm[1]["crop"] = _crop(&"pumpkin", 0)
	state["farm"] = farm
	assert_true(session.restore_state(state))
	return session.snapshot()

func _short_history_snapshot(history_size: int) -> Dictionary:
	var history: Array = []
	for index in history_size:
		history.append(&"sunny")
	return {"day": 3, "weather": &"sunny", "weather_history": history, "farm": []}

func _screen_descendants(panel: Control) -> Array:
	var screen := _frame(panel).get_node("Screen") as Control
	return screen.find_children("*", "Control", true, false)

func _assert_descendants_inside_screen(panel: Control, context: String) -> void:
	var screen := _frame(panel).get_node("Screen") as Control
	var screen_rect := screen.get_global_rect()
	for node in _screen_descendants(panel):
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		if control.get_global_rect().has_area() == false:
			continue
		assert_true(
			screen_rect.encloses(control.get_global_rect()),
			"%s escapes the phone screen at %s" % [control.get_path(), context],
		)

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _frame(panel: Control) -> Control:
	return panel.get_node("Center/PhoneFrame") as Control

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

func test_phone_frame_matches_reference_shell_geometry() -> void:
	var bag := _spawn_panel("res://scenes/ui/bag_panel.tscn") as BagPanel
	if bag == null:
		return
	bag.open_panel(_snapshot())
	await _settle()
	var frame := _frame(bag)
	assert_not_null(frame)
	if frame == null:
		return
	assert_eq(PhoneFrame.PHONE_SIZE, Vector2(560, 920))
	assert_almost_eq(frame.size.x, 560.0, 1.0, "phone stays 560 wide")
	assert_almost_eq(frame.size.y, 920.0, 1.0, "phone stays 920 tall")
	var screen := frame.get_node("Screen") as Control
	var island := frame.find_child("Island", true, false) as Control
	assert_not_null(island, "notch island must exist")
	assert_not_null(screen)
	if island == null or screen == null:
		return
	var island_rect := island.get_global_rect()
	assert_almost_eq(island_rect.size.x, 130.0, 2.0, "notch island width")
	assert_almost_eq(island_rect.size.y, 36.0, 2.0, "notch island height")
	assert_almost_eq(
		island_rect.get_center().x,
		screen.get_global_rect().get_center().x,
		2.0,
		"notch centres on the screen",
	)
	assert_almost_eq(
		island_rect.position.y - screen.get_global_rect().position.y,
		14.0,
		2.0,
		"notch sits 14px under the screen top",
	)
	var bars := frame.find_child("Bars", true, false) as Control
	var battery := frame.find_child("Battery", true, false) as Control
	assert_not_null(bars, "signal bars cluster")
	assert_not_null(battery, "battery indicator")
	if bars != null:
		assert_eq(bars.get_child_count(), 4, "four signal bars")
	var home := frame.find_child("HomeIndicator", true, false) as Control
	assert_not_null(home, "home indicator strip")
	if home != null:
		assert_almost_eq(home.size.y, 26.0, 2.0, "home strip height")
		var bar := home.find_child("Bar", true, false) as Control
		assert_not_null(bar)
		if bar != null:
			assert_almost_eq(bar.size.x, 160.0, 2.0, "home bar width")
			assert_almost_eq(bar.size.y, 6.0, 1.0, "home bar height")

func test_app_header_band_shows_gradient_jp_subtitle_and_light_status() -> void:
	var bag := _spawn_panel("res://scenes/ui/bag_panel.tscn") as BagPanel
	if bag == null:
		return
	bag.open_panel(_snapshot())
	bag.set_status_time("09:20")
	await _settle()
	var frame := _frame(bag)
	var band := frame.find_child("HeaderBand", true, false) as Control
	assert_not_null(band, "integrated app header band")
	if band == null:
		return
	assert_true(band.size.y >= 150.0, "band covers status row and app bar")
	var gradient := band.find_child("Gradient", true, false) as TextureRect
	assert_not_null(gradient, "band carries the header gradient")
	if gradient != null:
		assert_true(gradient.visible)
		assert_true(
			gradient.get_global_rect().size.x >= band.get_global_rect().size.x - 1.0,
			"gradient fills the band",
		)
	var jp := frame.find_child("JpSubtitle", true, false) as Label
	assert_not_null(jp, "Japanese app subtitle")
	if jp != null:
		assert_eq(jp.text, "かばん")
	var title := frame.find_child("AppTitle", true, false) as Label
	assert_not_null(title, "app title")
	if title != null:
		assert_eq(title.text, "Bag")
		assert_true(title.get_theme_font_size("font_size") >= 34, "app title font")
	var time := frame.find_child("Time", true, false) as Label
	assert_not_null(time)
	if time != null:
		assert_eq(time.text, "09:20")
		assert_eq(
			time.get_theme_color("font_color"),
			UiStyle.CARD,
			"status ink turns light on the gradient band",
		)

func test_bag_groups_grid_slots_and_counts_chip() -> void:
	var bag := _spawn_panel("res://scenes/ui/bag_panel.tscn") as BagPanel
	if bag == null:
		return
	bag.open_panel(_snapshot())
	await _settle()
	var frame := _frame(bag)
	var chip := frame.find_child("TotalsChip", true, false) as Label
	assert_not_null(chip, "header counts chip")
	if chip != null:
		assert_eq(chip.text, "3 seeds · 9 crops")
	var screen := frame.get_node("Screen") as Control
	for shelf in 2:
		var grid := bag.get_node(
			"Center/PhoneFrame/Screen/Column/Content/Layout/Column/Shelf_%d/Rows/Grid" % shelf
		) as GridContainer
		assert_not_null(grid, "shelf %d grid" % shelf)
		if grid == null:
			continue
		assert_eq(grid.columns, 4, "grid4 layout")
		assert_true(grid.get_child_count() >= 3)
		var slot := grid.get_child(0) as Control
		assert_true(slot.size.x >= 88.0, "slots are thumb-sized")
		assert_almost_eq(slot.size.x, slot.size.y, 3.0, "slots stay square")
		assert_true(screen.get_global_rect().encloses(slot.get_global_rect()))
		var icon := slot.find_child("Icon", true, false) as TextureRect
		assert_not_null(icon)
		if icon != null:
			assert_true(icon.size.x >= 56.0, "slot icon is readable")
		var count := slot.find_child("Count", true, false) as Label
		assert_not_null(count)
	assert_eq(bag.selected_shelf(), 0)
	assert_eq(bag.selected_kind(), GameRules.CropKind.TURNIP)

func test_bag_slot_icons_and_counts_stay_inside_their_slot() -> void:
	var bag := _spawn_panel("res://scenes/ui/bag_panel.tscn") as BagPanel
	if bag == null:
		return
	bag.open_panel(_snapshot())
	await _settle()
	var expected := [
		[3, 0, 0],
		[7, 2, 0],
		[1, 2, 1],
	]
	for shelf in 3:
		var grid := bag.get_node(
			"Center/PhoneFrame/Screen/Column/Content/Layout/Column/Shelf_%d/Rows/Grid" % shelf
		) as GridContainer
		assert_not_null(grid, "shelf %d grid" % shelf)
		if grid == null:
			continue
		for kind in 3:
			var slot := grid.get_child(kind) as Control
			var amount: int = expected[shelf][kind]
			if shelf == 2:
				assert_eq(
					slot.visible, amount > 0,
					"bin slot %d visibility tracks stock" % kind,
				)
			if not slot.visible:
				continue
			var slot_rect := slot.get_global_rect()
			var icon := slot.find_child("Icon", false, false) as TextureRect
			assert_not_null(icon, "slot icon")
			if icon != null:
				assert_true(
					slot_rect.encloses(icon.get_global_rect()),
					"icon spills out of its slot",
				)
				assert_almost_eq(
					icon.get_global_rect().get_center().x,
					slot_rect.get_center().x,
					1.0,
					"icon centres horizontally in its slot",
				)
				assert_almost_eq(
					icon.get_global_rect().get_center().y,
					slot_rect.get_center().y,
					1.0,
					"icon centres vertically in its slot",
				)
				assert_not_null(icon.texture)
			var count := slot.find_child("Count", false, false) as Label
			assert_not_null(count, "slot count")
			if count != null:
				assert_eq(
					count.visible, amount > 0,
					"count shows only for stocked slots",
				)
				if amount > 0:
					assert_eq(count.text, "%d" % amount)
					assert_true(
						slot_rect.encloses(count.get_global_rect()),
						"count label stays inside its slot",
					)

func test_bag_bin_payout_row_uses_reference_copy() -> void:
	var bag := _spawn_panel("res://scenes/ui/bag_panel.tscn") as BagPanel
	if bag == null:
		return
	bag.open_panel(_snapshot())
	await _press("move_down")
	await _press("move_down")
	await _settle()
	var bin_row := bag.find_child("BinPayout", true, false) as Control
	assert_not_null(bin_row, "bin payout row")
	assert_true(bag.bin_payout_visible())
	assert_eq(bag.bin_payout_value_text(), "+325G")
	assert_eq(bag.bin_payout_note_text(), "Pays out tomorrow morning")
	var count := bag.find_child("BinCount", true, false) as Label
	assert_not_null(count, "pending count line")
	if count != null:
		assert_eq(count.text, "4 crops in the bin")
	assert_true(bag.bin_slot_visible(GameRules.CropKind.TURNIP))
	assert_true(bag.bin_slot_visible(GameRules.CropKind.POTATO))
	assert_true(bag.bin_slot_visible(GameRules.CropKind.PUMPKIN))

func test_bag_detail_preserves_rules_content() -> void:
	var bag := _spawn_panel("res://scenes/ui/bag_panel.tscn") as BagPanel
	if bag == null:
		return
	bag.open_panel(_snapshot())
	await _settle()
	assert_eq(bag.detail_title_text(), "Turnip seeds")
	assert_eq(bag.detail_economy_text(), "20G buy · 35G sell")
	assert_eq(bag.detail_favourite_text(), "Hana's favourite")
	assert_eq(
		bag.detail_description_text(),
		"Cheapest and fastest; the latest safe planting.",
	)
	assert_lte(bag.detail_description_line_count(), 2)
	await _press("move_right")
	assert_eq(bag.selected_kind(), GameRules.CropKind.POTATO)
	assert_eq(bag.detail_title_text(), "Potato seeds")

func test_bag_hints_live_in_the_phone_footer() -> void:
	var bag := _spawn_panel("res://scenes/ui/bag_panel.tscn") as BagPanel
	if bag == null:
		return
	bag.open_panel(_snapshot())
	await _settle()
	var frame := _frame(bag)
	var footer := frame.find_child("Footer", true, false) as Control
	assert_not_null(footer, "frame footer bar")
	if footer == null:
		return
	assert_true(footer.visible, "footer shows once hints mount")
	var screen := frame.get_node("Screen") as Control
	assert_true(
		screen.get_global_rect().encloses(footer.get_global_rect()),
		"footer stays inside the phone screen",
	)
	var home := frame.find_child("HomeIndicator", true, false) as Control
	assert_not_null(home)
	if home != null:
		assert_almost_eq(
			footer.get_global_rect().end.y,
			home.get_global_rect().position.y,
			2.0,
			"footer sits directly above the home indicator",
		)
	var hints := footer.find_children("*", "Label", true, false)
	var texts: Array[String] = []
	for hint in hints:
		texts.append((hint as Label).text)
	assert_true(texts.has("move"), "footer keeps the move hint")
	assert_true(texts.has("close"), "footer keeps the close hint")

func test_phone_bottom_bar_is_a_rounded_surface_tall_enough_for_its_corners() -> void:
	var bag := _spawn_panel("res://scenes/ui/bag_panel.tscn") as BagPanel
	if bag == null:
		return
	bag.open_panel(_snapshot())
	await _settle()
	var frame := _frame(bag)
	var screen := frame.get_node("Screen") as Control
	var bottom := frame.find_child("BottomBar", true, false) as PanelContainer
	assert_not_null(bottom, "one bottom surface owns the rounded corners")
	if bottom == null or screen == null:
		return
	assert_true(
		bottom.size.y >= 112.0,
		"bottom bar spans enough height for the 56px screen corners",
	)
	assert_true(
		screen.get_global_rect().encloses(bottom.get_global_rect()),
		"bottom bar stays inside the screen",
	)
	var box := bottom.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(box)
	if box == null:
		return
	assert_eq(
		box.corner_radius_bottom_left,
		PhoneFrame.SCREEN_RADIUS,
		"bottom-left matches screen corner",
	)
	assert_eq(
		box.corner_radius_bottom_right,
		PhoneFrame.SCREEN_RADIUS,
		"bottom-right matches screen corner",
	)
	var footer := frame.find_child("Footer", true, false) as PanelContainer
	var home := frame.find_child("HomeIndicator", true, false) as PanelContainer
	assert_not_null(footer)
	assert_not_null(home)
	if footer != null:
		var footer_box := footer.get_theme_stylebox("panel") as StyleBoxFlat
		assert_true(
			footer_box == null or footer_box.bg_color.a < 0.05,
			"footer paints no background of its own",
		)
	if home != null:
		var home_box := home.get_theme_stylebox("panel") as StyleBoxFlat
		assert_true(
			home_box == null or home_box.bg_color.a < 0.05,
			"home indicator paints no background of its own",
		)

func test_almanac_art_is_composited_inside_the_rounded_artbox() -> void:
	var almanac := _spawn_panel("res://scenes/ui/almanac_panel.tscn") as AlmanacPanel
	if almanac == null:
		return
	almanac.open_panel(_snapshot())
	await _settle()
	var art := almanac.find_child("Art", true, false) as TextureRect
	assert_not_null(art)
	if art == null:
		return
	var texture := art.texture as ImageTexture
	assert_not_null(texture, "art surface is a composited image, not the raw PNG")
	if texture == null:
		return
	var image := texture.get_image()
	assert_not_null(image)
	if image == null:
		return
	assert_eq(
		image.get_size(), Vector2i(488, 300),
		"composite covers the whole artbox (sky plus art)",
	)
	for corner in [
		Vector2i(0, 0), Vector2i(487, 0), Vector2i(0, 299), Vector2i(487, 299)
	]:
		assert_almost_eq(
			image.get_pixelv(corner).a,
			0.0,
			0.01,
			"composite corner %s stays transparent" % corner,
		)
	assert_true(
		image.get_pixel(244, 150).a > 0.5,
		"composite centre is opaque",
	)

func test_growth_pips_and_page_dots_render_rounded_gradient_pills() -> void:
	var almanac := _spawn_panel("res://scenes/ui/almanac_panel.tscn") as AlmanacPanel
	if almanac == null:
		return
	almanac.open_panel(_snapshot())
	await _settle()
	var pips := almanac.find_child("GrowthPips", true, false) as Control
	assert_not_null(pips)
	if pips != null:
		var on := pips.get_child(0).get_node("On") as TextureRect
		assert_not_null(on)
		if on != null:
			var pip_texture := on.texture as ImageTexture
			assert_not_null(
				pip_texture, "growth pip on-state is a baked rounded pill"
			)
			if pip_texture != null:
				var pip_image := pip_texture.get_image()
				assert_almost_eq(
					pip_image.get_pixel(0, 0).a, 0.0, 0.05,
					"pip corner stays transparent",
				)
				assert_true(
					pip_image.get_pixel(
						int(pip_image.get_width() / 2.0),
						int(pip_image.get_height() / 2.0),
					).a > 0.9,
					"pip centre stays opaque",
				)
	var dots := almanac.find_child("PageDots", true, false) as Control
	assert_not_null(dots)
	if dots != null:
		var dot_on := dots.get_child(0).get_node("On") as TextureRect
		assert_not_null(dot_on)
		if dot_on != null:
			var dot_texture := dot_on.texture as ImageTexture
			assert_not_null(
				dot_texture, "page marker on-state is a baked rounded pill"
			)
			if dot_texture != null:
				var dot_image := dot_texture.get_image()
				assert_almost_eq(
					dot_image.get_pixel(0, 0).a, 0.0, 0.05,
					"page marker corner stays transparent",
				)

func test_almanac_composes_each_crop_art_once_for_the_panel_lifetime() -> void:
	var almanac := _spawn_panel("res://scenes/ui/almanac_panel.tscn") as AlmanacPanel
	if almanac == null:
		return
	almanac.open_panel(_snapshot())
	await _settle()
	var art := almanac.find_child("Art", true, false) as TextureRect
	assert_not_null(art)
	if art == null:
		return
	var turnip := art.texture
	almanac.present(_snapshot())
	assert_same(
		art.texture, turnip, "re-presenting the same page reuses the texture"
	)
	await _press("move_right")
	await _settle()
	var potato := art.texture
	assert_true(potato != null and potato != turnip, "page turn swaps texture")
	await _press("move_right")
	await _settle()
	var pumpkin := art.texture
	assert_true(pumpkin != turnip and pumpkin != potato)
	await _press("move_left")
	await _settle()
	assert_same(art.texture, potato, "revisiting a page reuses its cached texture")
	await _press("move_left")
	await _settle()
	assert_same(art.texture, turnip, "first page keeps its cached texture")

func test_almanac_renders_reference_surface() -> void:
	var almanac := _spawn_panel("res://scenes/ui/almanac_panel.tscn") as AlmanacPanel
	if almanac == null:
		return
	almanac.open_panel(_snapshot())
	await _settle()
	var frame := _frame(almanac)
	var jp := frame.find_child("JpSubtitle", true, false) as Label
	assert_not_null(jp)
	if jp != null:
		assert_eq(jp.text, "作物図鑑")
	var chip := frame.find_child("PageChip", true, false) as Label
	assert_not_null(chip, "page indicator chip")
	if chip != null:
		assert_eq(chip.text, "1 of 3")
	var artbox := almanac.find_child("ArtBox", true, false) as Control
	assert_not_null(artbox, "full-size crop art region")
	if artbox == null:
		return
	assert_true(artbox.size.x >= 460.0, "artbox spans the app content")
	assert_true(artbox.size.y >= 290.0, "artbox is full-size, not a thumbnail")
	var art := artbox.find_child("Art", true, false) as TextureRect
	assert_not_null(art)
	if art != null:
		assert_not_null(art.texture)
	var name_label := almanac.find_child("Name", true, false) as Label
	assert_not_null(name_label)
	if name_label != null:
		assert_true(name_label.get_theme_font_size("font_size") >= 30)
	assert_eq(almanac.crop_name_text(), "Turnip")
	assert_eq(almanac.crop_seed_text(), "20G")
	assert_eq(almanac.crop_sell_text(), "35G")
	assert_eq(almanac.crop_margin_text(), "+15")
	var pips := almanac.find_child("GrowthPips", true, false) as Control
	assert_not_null(pips)
	if pips != null:
		assert_eq(pips.get_child_count(), 7)
	var dots := almanac.find_child("PageDots", true, false) as Control
	assert_not_null(dots)
	if dots != null:
		assert_eq(dots.get_child_count(), 3)
		var active := dots.get_child(0) as Control
		assert_true(active.size.x >= 24.0, "active page marker is a pill, not a dot")
		var idle := dots.get_child(1) as Control
		assert_true(idle.size.x <= 12.0, "idle page marker is a dot")

func test_almanac_still_pages_with_move_keys() -> void:
	var almanac := _spawn_panel("res://scenes/ui/almanac_panel.tscn") as AlmanacPanel
	if almanac == null:
		return
	almanac.open_panel(_snapshot())
	await _settle()
	await _press("move_right")
	assert_eq(almanac.selected_kind(), GameRules.CropKind.POTATO)
	assert_eq(almanac.crop_name_text(), "Potato")
	assert_eq(almanac.crop_seed_text(), "30G")
	assert_eq(almanac.crop_sell_text(), "75G")
	assert_eq(almanac.crop_margin_text(), "+45")
	var chip := _frame(almanac).find_child("PageChip", true, false) as Label
	assert_not_null(chip)
	if chip != null:
		assert_eq(chip.text, "2 of 3")

func test_phone_apps_keep_localized_titles_and_fixed_jp_subtitles() -> void:
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		var bag := _spawn_panel("res://scenes/ui/bag_panel.tscn") as BagPanel
		assert_not_null(bag)
		if bag == null:
			continue
		bag.open_panel(_snapshot())
		await _settle()
		var frame := _frame(bag)
		var title := frame.find_child("AppTitle", true, false) as Label
		var jp := frame.find_child("JpSubtitle", true, false) as Label
		assert_not_null(title)
		assert_not_null(jp)
		if title != null:
			match locale:
				"en":
					assert_eq(title.text, "Bag")
				"zh_TW":
					assert_eq(title.text, "背包")
				"ja":
					assert_eq(title.text, "かばん")
		if jp != null:
			assert_eq(jp.text, "かばん", "%s keeps the decorative JP subtitle" % locale)
		var almanac := _spawn_panel("res://scenes/ui/almanac_panel.tscn") as AlmanacPanel
		assert_not_null(almanac)
		if almanac == null:
			continue
		almanac.open_panel(_snapshot())
		await _settle()
		var a_frame := _frame(almanac)
		var a_title := a_frame.find_child("AppTitle", true, false) as Label
		var a_jp := a_frame.find_child("JpSubtitle", true, false) as Label
		assert_not_null(a_title)
		assert_not_null(a_jp)
		if a_title != null:
			match locale:
				"en":
					assert_eq(a_title.text, "Almanac")
				"zh_TW":
					assert_eq(a_title.text, "圖鑑")
				"ja":
					assert_eq(a_title.text, "図鑑")
		if a_jp != null:
			assert_eq(a_jp.text, "作物図鑑", "%s keeps the decorative JP subtitle" % locale)

func test_localized_phone_layouts_stay_inside_the_screen() -> void:
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		for scene in [
			"res://scenes/ui/bag_panel.tscn",
			"res://scenes/ui/almanac_panel.tscn",
			"res://scenes/ui/calendar_panel.tscn",
		]:
			var panel := _spawn_panel(scene)
			assert_not_null(panel)
			if panel == null:
				continue
			panel.call("open_panel", _snapshot())
			await _settle()
			var screen := _frame(panel).get_node("Screen") as Control
			assert_not_null(screen)
			if screen == null:
				continue
			var screen_rect := screen.get_global_rect()
			for node in screen.find_children("*", "Control", true, false):
				var control := node as Control
				if not control.is_visible_in_tree():
					continue
				if control.get_global_rect().has_area() == false:
					continue
				assert_true(
					screen_rect.encloses(control.get_global_rect()),
					"%s escapes the phone screen at %s" % [control.get_path(), locale],
				)

func test_footer_stays_hidden_until_a_panel_mounts_hints() -> void:
	var frame := PhoneFrame.new()
	add_child_autoqfree(frame)
	var footer := frame.find_child("Footer", true, false) as Control
	assert_not_null(footer)
	if footer == null:
		return
	assert_false(footer.visible, "empty footer bar stays hidden")
	var mount := frame.call("footer_mount") as HBoxContainer
	assert_not_null(mount)
	if mount == null:
		return
	mount.add_child(UiStyle.keycap("I", true))
	await _settle()
	assert_true(footer.visible, "footer appears once a hint mounts")
	mount.get_child(0).queue_free()
	await _settle()
	await _settle()
	assert_false(footer.visible, "footer hides again when emptied")

func test_content_mount_and_status_time_keep_working_for_other_panels() -> void:
	var frame := PhoneFrame.new()
	add_child_autoqfree(frame)
	assert_not_null(frame.content_mount())
	frame.set_status_time("18:40")
	assert_eq(frame.status_time_text(), "18:40")
	var app_bar := frame.find_child("AppBar", true, false) as Control
	assert_not_null(app_bar)
	if app_bar != null:
		assert_false(app_bar.visible, "app bar stays hidden without an app header")

func test_calendar_integrated_header_and_market_tag() -> void:
	var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
	if calendar == null:
		return
	calendar.open_panel(_calendar_snapshot())
	calendar.set_status_time("09:20")
	await _settle()
	var frame := _frame(calendar)
	var title := frame.find_child("AppTitle", true, false) as Label
	assert_not_null(title, "calendar uses the shared app header")
	if title != null:
		assert_eq(title.text, "Season")
		assert_true(title.get_theme_font_size("font_size") >= 34)
	var jp := frame.find_child("JpSubtitle", true, false) as Label
	assert_not_null(jp, "Japanese app subtitle")
	if jp != null:
		assert_eq(jp.text, "カレンダー")
	var gradient := frame.find_child("Gradient", true, false) as TextureRect
	assert_not_null(gradient, "header band gradient")
	if gradient != null:
		assert_true(gradient.visible)
	var tag := frame.find_child("MarketTag", true, false) as Control
	assert_not_null(tag, "market countdown accessory on the header")
	if tag != null:
		assert_true(tag.visible)
		var tag_text := tag.find_child("Text", true, false) as Label
		assert_not_null(tag_text)
		if tag_text != null:
			assert_eq(tag_text.text, "MARKET IN 11")
	var time := frame.find_child("Time", true, false) as Label
	assert_not_null(time)
	if time != null:
		assert_eq(time.text, "09:20")
		assert_eq(time.get_theme_color("font_color"), UiStyle.CARD)
	calendar.present(_season_end_snapshot())
	var tag_text := tag.find_child("Text", true, false) as Label
	assert_eq(tag_text.text, "MARKET TODAY")

func test_calendar_grid_cells_match_reference_with_legible_markers() -> void:
	var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
	if calendar == null:
		return
	calendar.open_panel(_calendar_snapshot())
	await _settle()
	var grid := calendar.find_child("Days", true, false) as GridContainer
	assert_not_null(grid, "7-column season grid")
	if grid == null:
		return
	assert_eq(grid.columns, 7)
	assert_eq(grid.get_child_count(), GameRules.MAX_DAY)
	var screen := _frame(calendar).get_node("Screen") as Control
	for index in grid.get_child_count():
		var cell := grid.get_child(index) as Control
		assert_true(cell.size.x >= 56.0, "day cell %d stays thumb-readable" % (index + 1))
		assert_true(cell.size.y >= 78.0, "day cell %d matches the reference height" % (index + 1))
		assert_true(
			screen.get_global_rect().encloses(cell.get_global_rect()),
			"day cell %d stays inside the screen" % (index + 1),
		)
		for node in cell.find_children("*", "Label", true, false):
			var label := node as Label
			assert_true(
				label.get_theme_font_size("font_size") >= 11,
				"%s marker text must stay readable at 960x540" % label.get_path(),
			)
			if not label.is_visible_in_tree():
				continue
			if label.get_global_rect().has_area() == false:
				continue
			assert_true(
				cell.get_global_rect().encloses(label.get_global_rect()),
				"%s marker text must sit inside its day cell" % label.get_path(),
			)
		var day_label := cell.find_child("Day", true, false) as Label
		assert_not_null(day_label)
		if day_label != null:
			assert_true(
				day_label.get_theme_font_size("font_size") >= 18,
				"day number is the reference 20px weight",
			)
		var weather := cell.find_child("Weather", true, false) as TextureRect
		assert_not_null(weather)
		if weather != null:
			assert_true(weather.custom_minimum_size.x >= 20.0, "weather icon is legible")

func test_calendar_cell_markers_never_overlap_neighbor_cells() -> void:
	var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
	if calendar == null:
		return
	var snapshots := [
		_calendar_snapshot(),
		_season_end_snapshot(),
		_busy_calendar_snapshot(),
		_three_kind_snapshot(),
	]
	calendar.open_panel(snapshots[0])
	await _settle()
	var checked := 0
	for snapshot in snapshots:
		calendar.present(snapshot)
		await _settle()
		var grid := calendar.find_child("Days", true, false) as GridContainer
		assert_not_null(grid)
		if grid == null:
			continue
		for cell_node in grid.get_children():
			var cell := cell_node as Control
			var cell_rect := cell.get_global_rect()
			for node in cell.find_children("*", "Control", true, false):
				var child := node as Control
				if not child.is_visible_in_tree():
					continue
				if child.get_global_rect().has_area() == false:
					continue
				checked += 1
				assert_true(
					cell_rect.encloses(child.get_global_rect()),
					"%s overlaps its day cell at day %d" % [child.get_path(), int(snapshot["day"])],
				)
	assert_gt(checked, 0, "the overlap walk must inspect rendered descendants")

func test_calendar_coming_up_wraps_three_crop_names_inside_the_frame() -> void:
	var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
	if calendar == null:
		return
	var crop_names := {
		"en": ["Turnip", "Potato", "Pumpkin"],
		"zh_TW": ["蕪菁", "馬鈴薯", "南瓜"],
		"ja": ["カブ", "ジャガイモ", "カボチャ"],
	}
	var earliest := {"en": "earliest harvest", "zh_TW": "最早收成", "ja": "最短収穫"}
	for locale in ["en", "zh_TW", "ja"]:
		TranslationServer.set_locale(locale)
		calendar.open_panel(_three_kind_snapshot())
		await _settle()
		var frame_rect := _frame(calendar).get_global_rect()
		assert_true(
			frame_rect.size.x <= 560.0,
			"%s three-crop coming-up row keeps the phone at 560 wide" % locale,
		)
		assert_true(
			frame_rect.size.y <= 920.0,
			"%s three-crop coming-up row keeps the phone at 920 tall" % locale,
		)
		var coming := calendar.find_child("ComingUp", true, false) as Control
		assert_not_null(coming)
		if coming == null:
			continue
		var text_label: Label = null
		for node in coming.find_children("Text", "Label", true, false):
			var label := node as Label
			if label.text.contains(earliest[locale]):
				text_label = label
		assert_not_null(text_label, "%s renders the three-crop readiness row" % locale)
		if text_label == null:
			continue
		for crop_name in crop_names[locale]:
			assert_true(
				text_label.text.contains(crop_name),
				"%s row keeps %s in the wrapped text" % [locale, crop_name],
			)
		var screen_rect := (
			(_frame(calendar).get_node("Screen") as Control).get_global_rect()
		)
		assert_true(
			screen_rect.encloses(text_label.get_global_rect()),
			"%s three-crop text stays inside the phone screen" % locale,
		)
		if locale == "en":
			assert_true(
				text_label.get_line_count() >= 2,
				"en three-crop text wraps instead of widening the phone",
			)

func test_calendar_coming_up_max_rows_stay_inside_the_frame() -> void:
	var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
	if calendar == null:
		return
	var crop_names := {
		"en": ["Turnip", "Potato", "Pumpkin"],
		"zh_TW": ["蕪菁", "馬鈴薯", "南瓜"],
		"ja": ["カブ", "ジャガイモ", "カボチャ"],
	}
	var earliest := {"en": "earliest harvest", "zh_TW": "最早收成", "ja": "最短収穫"}
	var overflow := {"en": "+1 more", "zh_TW": "還有 1", "ja": "あと 1"}
	for locale in ["en", "zh_TW", "ja"]:
		TranslationServer.set_locale(locale)
		calendar.open_panel(_max_rows_snapshot())
		await _settle()
		var frame_rect := _frame(calendar).get_global_rect()
		assert_true(
			frame_rect.size.x <= 560.0,
			"%s max-row coming-up keeps the phone at 560 wide" % locale,
		)
		assert_true(
			frame_rect.size.y <= 920.0,
			"%s max-row coming-up keeps the phone at 920 tall" % locale,
		)
		var coming := calendar.find_child("ComingUp", true, false) as Control
		assert_not_null(coming)
		if coming == null:
			continue
		assert_eq(
			calendar.coming_up_row_texts().size(),
			6,
			"%s renders three crop days plus overflow, last night and market"
				% locale,
		)
		var readiness_rows := 0
		var checked := 0
		var screen_rect := (
			(_frame(calendar).get_node("Screen") as Control).get_global_rect()
		)
		for node in coming.find_children("*", "Control", true, false):
			var child := node as Control
			if not child.is_visible_in_tree():
				continue
			if child.get_global_rect().has_area() == false:
				continue
			checked += 1
			assert_true(
				screen_rect.encloses(child.get_global_rect()),
				(
					"%s escapes the phone screen in %s"
					% [child.get_path(), locale]
				),
			)
			var label := child as Label
			if (
				label != null
				and label.text.contains(earliest[locale])
				and label.text.contains(" · ")
			):
				readiness_rows += 1
				for crop_name in crop_names[locale]:
					assert_true(
						label.text.contains(crop_name),
						(
							"%s keeps %s in wrapped readiness row %d"
							% [locale, crop_name, readiness_rows]
						),
					)
		assert_gt(checked, 0, "%s coming-up walk inspects real controls" % locale)
		assert_eq(
			readiness_rows,
			3,
			"%s renders all three three-kind readiness rows" % locale,
		)
		var all_text := " ".join(calendar.coming_up_row_texts())
		assert_true(
			all_text.contains(overflow[locale]),
			"%s keeps the +1 overflow row" % locale,
		)

func test_calendar_coming_up_scrolls_with_keys_and_pointer() -> void:
	var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
	if calendar == null:
		return
	calendar.open_panel(_max_rows_snapshot())
	await _settle()
	var scroll := calendar.find_child("ComingScroll", true, false) as ScrollContainer
	assert_not_null(scroll)
	var hint := calendar.find_child("ScrollHint", true, false) as Label
	assert_not_null(hint)
	if scroll == null or hint == null:
		return
	assert_true(scroll.visible, "the bounded rows viewport is real")
	assert_true(hint.visible, "the scroll hint shows only when content overflows")
	assert_false(hint.text.is_empty(), "the scroll hint carries text")
	assert_eq(scroll.scroll_vertical, 0, "a fresh snapshot starts at the top")
	_press("move_down")
	await _settle()
	assert_gt(
		scroll.scroll_vertical,
		0,
		"move_down scrolls the hidden readiness rows into view",
	)
	for _press_index in 12:
		_press("move_down")
	await _settle()
	var bottom := scroll.scroll_vertical
	assert_gt(bottom, 0)
	_press("move_down")
	await _settle()
	assert_eq(
		scroll.scroll_vertical,
		bottom,
		"move_down clamps at the last hidden row",
	)
	_press("move_up")
	await _settle()
	assert_lt(scroll.scroll_vertical, bottom, "move_up scrolls back up")
	var vbar := scroll.get_v_scroll_bar()
	assert_not_null(vbar, "a pointer-draggable scrollbar exists")
	if vbar == null:
		return
	assert_true(vbar.visible, "the scrollbar renders for pointer users")
	assert_gt(
		vbar.max_value - vbar.page,
		0.0,
		"the scrollbar exposes the hidden readiness rows",
	)
	var vbar_before := vbar.value
	vbar.value = minf(vbar.max_value - vbar.page, vbar.value + 40.0)
	await _settle()
	assert_gt(
		vbar.value,
		vbar_before,
		"dragging the scrollbar scrolls for pointer users",
	)
	assert_eq(
		int(vbar.value),
		scroll.scroll_vertical,
		"the scrollbar drives the same scroll position as the keys",
	)
	calendar.open_panel(_calendar_snapshot())
	await _settle()
	assert_eq(scroll.scroll_vertical, 0, "a fresh snapshot resets the scroll")
	assert_false(
		hint.visible,
		"the scroll hint hides when every row fits without scrolling",
	)
	_press("move_down")
	await _settle()
	assert_eq(
		scroll.scroll_vertical,
		0,
		"move_down is a no-op while every row is already visible",
	)

func test_calendar_event_markers_use_legible_icons_not_tiny_text() -> void:
	var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
	if calendar == null:
		return
	calendar.open_panel(_busy_calendar_snapshot())
	await _settle()
	var grid := calendar.find_child("Days", true, false) as GridContainer
	assert_not_null(grid)
	if grid == null:
		return
	var last_night_cell := grid.get_child(GameRules.MAX_DAY - 2) as Control
	var moon := last_night_cell.find_child("Moon", true, false) as TextureRect
	assert_not_null(moon, "last night marks with a real icon, not 5px text")
	if moon != null:
		assert_true(moon.visible)
		assert_true(moon.custom_minimum_size.x >= 18.0, "moon icon legible at 960x540")
	var market_cell := grid.get_child(GameRules.MAX_DAY - 1) as Control
	var market := market_cell.find_child("Market", true, false) as TextureRect
	assert_not_null(market)
	if market != null:
		assert_true(market.visible)
		assert_true(market.custom_minimum_size.x >= 20.0, "market icon legible at 960x540")
	var day_one := grid.get_child(0) as Control
	var readiness := day_one.find_child("ReadinessIcon", true, false) as TextureRect
	assert_not_null(readiness)
	if readiness != null:
		assert_true(readiness.visible)
		assert_true(readiness.custom_minimum_size.x >= 16.0, "readiness icon legible at 960x540")
	var weather := day_one.find_child("Weather", true, false) as TextureRect
	assert_not_null(weather)
	if weather != null:
		assert_true(weather.visible)
		assert_true(weather.custom_minimum_size.x >= 20.0, "weather icon legible at 960x540")
	var day_state := calendar.day_state(GameRules.MAX_DAY - 1)
	assert_true(day_state["last_night"], "the moon keeps the last-night seam")
	assert_eq(
		calendar.day_state(1)["readiness_text"],
		"EARLIEST",
		"the day_state seam derives readiness wording from real icons",
	)

func test_calendar_caption_reports_actual_weather_history_depth() -> void:
	var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
	if calendar == null:
		return
	var caption := calendar.find_child("Caption", true, false) as Label
	assert_not_null(caption)
	if caption == null:
		return
	calendar.open_panel(_short_history_snapshot(1))
	await _settle()
	assert_eq(
		caption.text.left(len("Weather is known through Day 1.")),
		"Weather is known through Day 1.",
		"short history must not claim weather is known through today",
	)
	calendar.present(_short_history_snapshot(0))
	assert_eq(
		caption.text.left(len("Weather is not recorded yet.")),
		"Weather is not recorded yet.",
		"empty history must not claim known weather",
	)
	calendar.present(_calendar_snapshot())
	assert_eq(
		caption.text.left(len("Weather is known through today.")),
		"Weather is known through today.",
		"full history still claims through-today weather",
	)

func test_calendar_coming_up_labels_are_sized_for_960x540() -> void:
	var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
	if calendar == null:
		return
	calendar.open_panel(_calendar_snapshot())
	await _settle()
	var card := calendar.find_child("ComingUp", true, false) as Control
	assert_not_null(card)
	if card == null:
		return
	var title := card.find_child("Title", true, false) as Label
	assert_not_null(title)
	if title != null:
		assert_true(title.get_theme_font_size("font_size") >= 14)
	var rows := card.find_child("Rows", true, false) as Control
	assert_not_null(rows)
	if rows == null:
		return
	for row in rows.get_children():
		var text := (row as Control).find_child("Text", true, false) as Label
		assert_not_null(text)
		if text != null:
			assert_true(
				text.get_theme_font_size("font_size") >= 17,
				"coming-up event text must stay readable at 960x540",
			)
	var caption := calendar.find_child("Caption", true, false) as Label
	assert_not_null(caption)
	if caption != null:
		assert_true(
			caption.get_theme_font_size("font_size") >= 14,
			"the marker legend must stay readable at 960x540",
		)

func test_calendar_cells_render_no_hidden_marker_labels() -> void:
	var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
	if calendar == null:
		return
	calendar.open_panel(_season_end_snapshot())
	await _settle()
	var grid := calendar.find_child("Days", true, false) as GridContainer
	assert_not_null(grid)
	if grid == null:
		return
	for cell_node in grid.get_children():
		var cell := cell_node as Control
		var labels := cell.find_children("*", "Label", true, false)
		assert_eq(
			labels.size(),
			1,
			"%s may only render the day-number label, not fake seam carriers"
			% cell.name,
		)
		if labels.size() == 1:
			assert_eq((labels[0] as Label).name, "Day")

func test_calendar_day_state_tracks_only_rendered_controls() -> void:
	var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
	if calendar == null:
		return
	calendar.open_panel(_season_end_snapshot())
	await _settle()
	var grid := calendar.find_child("Days", true, false) as GridContainer
	assert_not_null(grid)
	if grid == null:
		return
	var cell := grid.get_child(GameRules.MAX_DAY - 1) as Control
	var fill := cell.find_child("TodayFill", true, false) as TextureRect
	assert_not_null(fill)
	if fill == null:
		return
	assert_true(calendar.day_state(GameRules.MAX_DAY)["today"])
	fill.visible = false
	assert_false(
		calendar.day_state(GameRules.MAX_DAY)["today"],
		"today must track the rendered today fill",
	)
	fill.visible = true
	var market := cell.find_child("Market", true, false) as TextureRect
	assert_not_null(market)
	if market == null:
		return
	assert_true(calendar.day_state(GameRules.MAX_DAY)["market"])
	market.visible = false
	assert_false(
		calendar.day_state(GameRules.MAX_DAY)["market"],
		"market must track the rendered icon",
	)
	market.visible = true
	var night_cell := grid.get_child(GameRules.MAX_DAY - 2) as Control
	var moon := night_cell.find_child("Moon", true, false) as TextureRect
	assert_not_null(moon)
	if moon == null:
		return
	assert_true(calendar.day_state(GameRules.MAX_DAY - 1)["last_night"])
	moon.visible = false
	assert_false(
		calendar.day_state(GameRules.MAX_DAY - 1)["last_night"],
		"last night must track the rendered moon",
	)
	moon.visible = true
	var icons_row := cell.find_child("ReadinessIcons", true, false) as Control
	assert_not_null(icons_row)
	if icons_row == null:
		return
	assert_ne(calendar.day_state(GameRules.MAX_DAY)["readiness_text"], "")
	icons_row.visible = false
	assert_eq(
		calendar.day_state(GameRules.MAX_DAY)["readiness_kinds"],
		[],
		"hiding the icons row removes the readiness markers",
	)
	assert_eq(
		calendar.day_state(GameRules.MAX_DAY)["readiness_text"],
		"",
		"hiding the icons row clears the readiness wording",
	)

func test_calendar_legend_is_localized_and_legible_in_all_locales() -> void:
	var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
	if calendar == null:
		return
	var sun_words := {"en": "Sun", "zh_TW": "太陽", "ja": "太陽"}
	var market_words := {"en": "market", "zh_TW": "市集", "ja": "市"}
	for locale in ["en", "zh_TW", "ja"]:
		TranslationServer.set_locale(locale)
		calendar.present(_calendar_snapshot())
		await _settle()
		var grid := calendar.find_child("Days", true, false) as GridContainer
		assert_not_null(grid)
		if grid == null:
			continue
		var weather := (
			(grid.get_child(0) as Control).find_child("Weather", true, false)
			as TextureRect
		)
		assert_not_null(weather)
		if weather != null:
			assert_true(
				weather.visible,
				"%s cell 1 renders a real sun weather icon during this check"
					% locale,
			)
		var legend := calendar.find_child("Legend", true, false) as Label
		assert_not_null(legend, "a compact legend line exists")
		if legend == null:
			continue
		assert_false(
			legend.text.contains(sun_words[locale]),
			(
				"%s legend must not call the rendered weather sun a market marker"
				% locale
			),
		)
		assert_true(
			legend.text.contains(market_words[locale]),
			"%s legend still names the market event unambiguously" % locale,
		)
		if locale != "en":
			assert_false(
				legend.text.contains("Pink")
					or legend.text.contains("Gold")
					or legend.text.contains("Sun")
					or legend.text.contains("Moon")
					or legend.text.contains("Crops")
					or legend.text.contains("market"),
				"%s legend must translate, not render English" % locale,
			)
		assert_true(
			legend.get_theme_font_size("font_size") >= 15,
			"legend readable at 960x540",
		)
	var caption := calendar.find_child("Caption", true, false) as Label
	assert_not_null(caption)
	if caption != null:
		assert_true(
			caption.get_theme_font_size("font_size") >= 16,
			"weather caption readable at 960x540",
		)
	TranslationServer.set_locale("en")

func test_calendar_today_cell_uses_the_gradient_and_past_days_dim() -> void:
	var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
	if calendar == null:
		return
	calendar.open_panel(_calendar_snapshot())
	await _settle()
	var grid := calendar.find_child("Days", true, false) as GridContainer
	assert_not_null(grid)
	if grid == null:
		return
	var today := grid.get_child(2) as PanelContainer
	var today_fill := today.find_child("TodayFill", true, false) as TextureRect
	assert_not_null(today_fill, "today paints the accent gradient, not a flat fill")
	if today_fill != null:
		assert_true(today_fill.visible)
		var fill_texture := today_fill.texture as ImageTexture
		assert_not_null(fill_texture, "gradient texture")
		if fill_texture != null:
			var mid := fill_texture.get_image().get_pixel(
				int(fill_texture.get_width() * 0.1),
				int(fill_texture.get_height() * 0.5),
			)
			var end := fill_texture.get_image().get_pixel(
				int(fill_texture.get_width() * 0.9),
				int(fill_texture.get_height() * 0.5),
			)
			assert_true(mid.r != end.r or mid.g != end.g or mid.b != end.b,
				"today fill is a real gradient")
	var other_fill := (grid.get_child(5) as PanelContainer).find_child(
		"TodayFill", true, false
	) as TextureRect
	assert_not_null(other_fill)
	if other_fill != null:
		assert_false(other_fill.visible, "only today paints the gradient")
	var past := grid.get_child(0) as PanelContainer
	assert_true(past.modulate.a < 0.99, "past days dim like the reference")
	var market := grid.get_child(GameRules.MAX_DAY - 1) as PanelContainer
	var market_box := market.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(market_box)
	if market_box != null:
		assert_eq(market_box.bg_color, UiStyle.SUN, "market day uses the sun fill")

func test_calendar_coming_up_lists_real_readiness_and_events() -> void:
	var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
	if calendar == null:
		return
	calendar.open_panel(_calendar_snapshot())
	await _settle()
	var rows := calendar.coming_up_row_texts()
	assert_eq(rows.size(), 4, "crop days, last night and market rows")
	if rows.size() != 4:
		return
	assert_eq(rows[0], "Turnip · Potato earliest harvest")
	assert_eq(rows[1], "Pumpkin earliest harvest")
	assert_eq(rows[2], "Last night to grow")
	assert_eq(rows[3], "Town harvest market")
	var day_labels := calendar.coming_up_day_texts()
	assert_eq(day_labels, ["Day 6", "Day 9", "Day 13", "Day 14"])

func test_calendar_coming_up_row_icons_and_day_badges_render() -> void:
	var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
	if calendar == null:
		return
	calendar.open_panel(_calendar_snapshot())
	await _settle()
	var card := calendar.find_child("ComingUp", true, false) as Control
	assert_not_null(card)
	if card == null:
		return
	var rows := card.find_child("Rows", true, false) as Control
	assert_not_null(rows)
	if rows == null:
		return
	var first := rows.get_child(0) as Control
	var icons := first.find_children("*", "TextureRect", true, false)
	var shown := 0
	for icon in icons:
		if (icon as TextureRect).visible and (icon as TextureRect).texture != null:
			shown += 1
	assert_eq(shown, 2, "a shared readiness day shows both crop icons")
	var day := first.find_child("Day", true, false) as Label
	assert_not_null(day)
	if day != null:
		assert_true(day.get_theme_font_size("font_size") >= 14)
		assert_true(day.custom_minimum_size.x >= 56.0, "day badge keeps its column")

func test_calendar_coming_up_caps_crop_days_with_an_overflow_row() -> void:
	var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
	if calendar == null:
		return
	calendar.open_panel(_busy_calendar_snapshot())
	await _settle()
	var texts := calendar.coming_up_row_texts()
	assert_eq(texts.size(), 6, "3 crop days + overflow + last night + market")
	if texts.size() != 6:
		return
	assert_eq(texts[3], "+5 more earliest days")
	assert_eq(texts[4], "Last night to grow")
	assert_eq(texts[5], "Town harvest market")
	_assert_descendants_inside_screen(calendar, "busy day-1 calendar")

func test_calendar_coming_up_marks_today_readiness_as_factual() -> void:
	var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
	if calendar == null:
		return
	calendar.open_panel(_busy_calendar_snapshot())
	await _settle()
	var texts := calendar.coming_up_row_texts()
	assert_eq(texts[0], "Turnip ready today", "a mature crop is stated, not forecast")

func test_calendar_footer_mounts_the_close_hint() -> void:
	var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
	if calendar == null:
		return
	calendar.open_panel(_calendar_snapshot())
	await _settle()
	var frame := _frame(calendar)
	var footer := frame.find_child("Footer", true, false) as Control
	assert_not_null(footer)
	if footer == null:
		return
	assert_true(footer.visible)
	var home := frame.find_child("HomeIndicator", true, false) as Control
	assert_not_null(home)
	if home != null:
		assert_almost_eq(
			footer.get_global_rect().end.y,
			home.get_global_rect().position.y,
			2.0,
			"footer sits directly above the home indicator",
		)
	var labels := footer.find_children("*", "Label", true, false)
	var texts: Array[String] = []
	for label in labels:
		texts.append((label as Label).text)
	assert_true(texts.has("close"), "calendar closes with C")
	var keycaps := footer.find_children("*", "PanelContainer", true, false)
	var keys: Array[String] = []
	for keycap in keycaps:
		var caption := (keycap as Control).find_child("Key", true, false) as Label
		if caption != null:
			keys.append(caption.text)
	assert_true(keys.has("C"), "the C keycap rides along")

func test_calendar_day14_and_busy_farm_stay_inside_the_screen_in_all_locales() -> void:
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		for snapshot in [_season_end_snapshot(), _busy_calendar_snapshot()]:
			var calendar := _spawn_panel("res://scenes/ui/calendar_panel.tscn") as CalendarPanel
			assert_not_null(calendar)
			if calendar == null:
				continue
			calendar.open_panel(snapshot)
			await _settle()
			_assert_descendants_inside_screen(
				calendar, "calendar %s day %d" % [locale, int(snapshot["day"])],
			)
			calendar.queue_free()
			await _settle()

func test_settings_integrated_header_and_grouped_rows() -> void:
	var settings := _spawn_panel("res://scenes/ui/settings_panel.tscn") as SettingsPanel
	if settings == null:
		return
	settings.open_panel(UiSettings.new(SETTINGS_TEST_PATH))
	await _settle()
	var frame := _frame(settings)
	var title := frame.find_child("AppTitle", true, false) as Label
	assert_not_null(title, "settings uses the shared app header")
	if title != null:
		assert_eq(title.text, "Settings")
		assert_true(title.get_theme_font_size("font_size") >= 34)
	var jp := frame.find_child("JpSubtitle", true, false) as Label
	assert_not_null(jp, "Japanese app subtitle")
	if jp != null:
		assert_eq(jp.text, "設定")
	var gradient := frame.find_child("Gradient", true, false) as TextureRect
	assert_not_null(gradient)
	if gradient != null:
		assert_true(gradient.visible)
	var sound_group := settings.find_child("SoundGroup", true, false) as Control
	var display_group := settings.find_child("DisplayGroup", true, false) as Control
	assert_not_null(sound_group, "the sound section card")
	assert_not_null(display_group, "the display section card")
	if sound_group == null or display_group == null:
		return
	var rows := sound_group.find_children("*Row", "PanelContainer", true, false)
	var row_names: Array[String] = []
	for row in rows:
		row_names.append((row as Control).name)
	assert_true(row_names.has("MusicRow"), "sound group keeps the music row")
	assert_true(row_names.has("SoundRow"), "sound group keeps the sound row")
	rows = display_group.find_children("*Row", "PanelContainer", true, false)
	row_names = []
	for row in rows:
		row_names.append((row as Control).name)
	for expected in ["WindowRow", "TipsRow", "LanguageRow"]:
		assert_true(row_names.has(expected), "display group keeps %s" % expected)

func test_settings_section_headings_clear_the_header_band() -> void:
	var settings := _spawn_panel("res://scenes/ui/settings_panel.tscn") as SettingsPanel
	if settings == null:
		return
	settings.open_panel(UiSettings.new(SETTINGS_TEST_PATH))
	await _settle()
	var frame := _frame(settings)
	var band := frame.find_child("HeaderBand", true, false) as Control
	assert_not_null(band)
	if band == null:
		return
	var band_bottom := band.get_global_rect().end.y
	for section_name in ["SoundSection", "DisplaySection"]:
		var section := settings.find_child(section_name, true, false) as Control
		assert_not_null(section, "%s heading" % section_name)
		if section == null:
			continue
		assert_true(
			section.get_global_rect().position.y >= band_bottom,
			"%s heading must start below the gradient header band, not paint over it"
			% section_name,
		)

func test_settings_sliders_render_numeric_levels_and_fill() -> void:
	var settings := _spawn_panel("res://scenes/ui/settings_panel.tscn") as SettingsPanel
	if settings == null:
		return
	var ui_settings := UiSettings.new(SETTINGS_TEST_PATH)
	ui_settings.music = 4
	ui_settings.sound = 7
	settings.open_panel(ui_settings)
	await _settle()
	for entry in [
		{"name": "Music", "level": 4},
		{"name": "Sound", "level": 7},
	]:
		var slider := settings.find_child(
			"%sSlider" % entry["name"], true, false
		) as Control
		assert_not_null(slider, "%s slider" % entry["name"])
		if slider == null:
			continue
		assert_true(
			slider.custom_minimum_size.x >= 170.0,
			"%s slider matches the reference track width" % entry["name"],
		)
		var track := slider.find_child("Track", true, false) as Control
		assert_not_null(track, "%s slider track" % entry["name"])
		var fill := slider.find_child("Fill", true, false) as Control
		assert_not_null(fill, "%s slider gradient fill" % entry["name"])
		if fill != null:
			assert_almost_eq(
				fill.anchor_right,
				float(entry["level"]) / 10.0,
				0.01,
				"%s fill tracks the stored level" % entry["name"],
			)
		var knob := slider.find_child("Knob", true, false) as Control
		assert_not_null(knob, "%s slider knob" % entry["name"])
		if knob != null:
			assert_almost_eq(
				knob.anchor_left,
				float(entry["level"]) / 10.0,
				0.01,
				"%s knob sits on the level" % entry["name"],
			)
		var level := settings.find_child(
			"%sLevel" % entry["name"], true, false
		) as Label
		assert_not_null(level, "%s numeric level" % entry["name"])
		if level != null:
			assert_eq(level.text, "%d" % entry["level"])
			assert_true(
				level.get_theme_font_size("font_size") >= 16,
				"%s level is readable" % entry["name"],
			)
	await _press("move_right")
	var music_level := settings.find_child("MusicLevel", true, false) as Label
	assert_eq(music_level.text, "5", "A/D adjusts the numeric level")
	var music_slider := settings.find_child("MusicSlider", true, false) as Control
	assert_not_null(music_slider)
	if music_slider != null:
		var fill := music_slider.find_child("Fill", true, false) as Control
		assert_not_null(fill)
		if fill != null:
			assert_almost_eq(fill.anchor_right, 0.5, 0.01)

func test_settings_window_tips_language_controls() -> void:
	var settings := _spawn_panel("res://scenes/ui/settings_panel.tscn") as SettingsPanel
	if settings == null:
		return
	var ui_settings := UiSettings.new(SETTINGS_TEST_PATH)
	ui_settings.tutorial_cards = true
	settings.open_panel(ui_settings)
	await _settle()
	var window_seg := settings.find_child("WindowSeg", true, false) as Control
	assert_not_null(window_seg, "window segmented control")
	if window_seg != null:
		var chips := window_seg.find_children("Option_*", "PanelContainer", true, false)
		assert_eq(chips.size(), 2, "1080p / Full options")
		var captions: Array[String] = []
		for chip in chips:
			var caption := (chip as Control).find_child("Label", true, false) as Label
			captions.append(caption.text)
		assert_eq(captions, ["1080p", "FULL"])
	var tips := settings.find_child("TipsSwitch", true, false) as Control
	assert_not_null(tips, "tips on/off switch")
	if tips != null:
		var knob := tips.find_child("Knob", true, false) as Control
		var on := tips.find_child("On", true, false) as Control
		assert_not_null(knob)
		assert_not_null(on)
		if knob != null and on != null:
			assert_true(on.visible, "tips on shows the gradient track")
			assert_true(knob.position.x > 20.0, "tips on parks the knob right")
	var language := settings.find_child("LanguageSeg", true, false) as Control
	assert_not_null(language, "the required language row keeps its options")
	if language != null:
		var chips := language.find_children("Option_*", "PanelContainer", true, false)
		assert_eq(chips.size(), 3)
		var captions: Array[String] = []
		for chip in chips:
			var caption := (chip as Control).find_child("Label", true, false) as Label
			captions.append(caption.text)
		assert_eq(captions, ["English", "繁體中文", "日本語"])

func test_settings_tips_switch_flips_with_the_setting() -> void:
	var settings := _spawn_panel("res://scenes/ui/settings_panel.tscn") as SettingsPanel
	if settings == null:
		return
	var ui_settings := UiSettings.new(SETTINGS_TEST_PATH)
	ui_settings.tutorial_cards = true
	settings.open_panel(ui_settings)
	await _settle()
	assert_eq(settings.selected_setting_name(), &"music")
	await _press("move_down")
	await _press("move_down")
	await _press("move_down")
	assert_eq(settings.selected_setting_name(), &"tutorial_cards")
	await _press("move_left")
	assert_false(ui_settings.tutorial_cards)
	var tips := settings.find_child("TipsSwitch", true, false) as Control
	assert_not_null(tips)
	var knob := tips.find_child("Knob", true, false) as Control
	var on := tips.find_child("On", true, false) as Control
	assert_not_null(knob)
	assert_not_null(on)
	if knob != null:
		assert_true(knob.position.x < 10.0, "tips off parks the knob left")
	if on != null:
		assert_false(on.visible, "tips off hides the gradient track")

func test_settings_selection_ring_and_footer_hints() -> void:
	var settings := _spawn_panel("res://scenes/ui/settings_panel.tscn") as SettingsPanel
	if settings == null:
		return
	settings.open_panel(UiSettings.new(SETTINGS_TEST_PATH))
	await _settle()
	var music_row := settings.find_child("MusicRow", true, false) as PanelContainer
	assert_not_null(music_row)
	if music_row != null:
		var box := music_row.get_theme_stylebox("panel") as StyleBoxFlat
		assert_not_null(box)
		if box != null:
			assert_eq(box.border_color, UiStyle.ACCENT, "selected row wears the ring")
			assert_true(box.get_border_width_min() >= 2)
	await _press("move_down")
	var sound_row := settings.find_child("SoundRow", true, false) as PanelContainer
	assert_not_null(sound_row)
	if sound_row != null:
		var box := sound_row.get_theme_stylebox("panel") as StyleBoxFlat
		assert_not_null(box)
		if box != null:
			assert_eq(box.border_color, UiStyle.ACCENT)
	var frame := _frame(settings)
	var footer := frame.find_child("Footer", true, false) as Control
	assert_not_null(footer)
	if footer == null:
		return
	assert_true(footer.visible)
	var labels := footer.find_children("*", "Label", true, false)
	var texts: Array[String] = []
	for label in labels:
		texts.append((label as Label).text)
	for hint in ["row", "change", "done"]:
		assert_true(texts.has(hint), "footer keeps the %s hint" % hint)

func test_settings_stays_inside_the_screen_in_all_locales() -> void:
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		var settings := _spawn_panel("res://scenes/ui/settings_panel.tscn") as SettingsPanel
		assert_not_null(settings)
		if settings == null:
			continue
		settings.open_panel(UiSettings.new(SETTINGS_TEST_PATH))
		await _settle()
		_assert_descendants_inside_screen(settings, "settings %s" % locale)
		assert_eq(
			settings.save_path_text(),
			tr("Save file: %s") % SaveRepository.DEFAULT_PATH,
		)
		settings.queue_free()
		await _settle()
