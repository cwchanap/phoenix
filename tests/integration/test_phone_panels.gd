extends GutTest

const LOCALES := ["en", "zh_TW", "ja"]

func after_each() -> void:
	TranslationServer.set_locale("en")

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
		for scene in ["res://scenes/ui/bag_panel.tscn", "res://scenes/ui/almanac_panel.tscn"]:
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
