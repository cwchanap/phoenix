extends GutTest

const TITLE_ART := preload("res://assets/ui/backgrounds/title.png")
const LOCALES := ["en", "zh_TW", "ja"]

func after_each() -> void:
	TranslationServer.set_locale("en")

class UnhandledSpy:
	extends Node
	var presses: Array[StringName] = []

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventAction and event.pressed:
			presses.append(event.action)

func _spawn_panel(scene: String) -> Control:
	get_window().size = UiSettings.WINDOW_SIZE
	var panel := (load(scene) as PackedScene).instantiate() as Control
	assert_not_null(panel)
	if panel == null:
		return null
	add_child_autoqfree(panel)
	panel.visible = true
	return panel

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _frame(panel: Control) -> PhoneFrame:
	if panel is PhoneFrame:
		return panel as PhoneFrame
	return panel.find_child("PhoneFrame", true, false) as PhoneFrame

func _screen(panel: Control) -> Control:
	var frame := _frame(panel)
	assert_not_null(frame)
	if frame == null:
		return null
	return frame.get_node("Screen") as Control

func _screen_rect(panel: Control) -> Rect2:
	var screen := _screen(panel)
	assert_not_null(screen)
	if screen == null:
		return Rect2()
	return screen.get_global_rect()

func _scroll_clip(control: Control) -> ScrollContainer:
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			return ancestor as ScrollContainer
		ancestor = ancestor.get_parent()
	return null

func _containment_report(panel: Control) -> Dictionary:
	var report := {"offenders": [] as Array[String], "checked": 0}
	var screen := _screen(panel)
	if screen == null:
		return report
	var screen_rect := screen.get_global_rect()
	for control in panel.find_children("*", "Control", true, false) as Array[Control]:
		if control == screen or control.is_ancestor_of(screen):
			continue
		if not control.is_visible_in_tree():
			continue
		var rect := control.get_global_rect()
		if screen.is_ancestor_of(control):
			var clip := _scroll_clip(control)
			if clip != null and screen_rect.encloses(clip.get_global_rect()):
				continue
			if not rect.has_area():
				continue
			report["checked"] += 1
			if not screen_rect.encloses(rect):
				(report["offenders"] as Array[String]).append(
					"%s(%s) %s outside %s" % [
						control.name, control.get_class(), rect, screen_rect,
					]
				)
		elif (control is Button or control is Label) and rect.has_area():
			report["checked"] += 1
			(report["offenders"] as Array[String]).append(
				"%s(%s) detached at %s" % [control.name, control.get_class(), rect]
			)
	return report

func _assert_controls_inside(panel: Control, context: String) -> void:
	var report := _containment_report(panel)
	assert_gt(
		report["checked"] as int, 0, "%s found no visible controls to check" % context
	)
	assert_eq(
		report["offenders"] as Array[String],
		[] as Array[String],
		"%s has controls painting outside the phone screen" % context,
	)

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

func _press_at_release_outside(global_pos: Vector2) -> void:
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

func _morning_summary() -> Dictionary:
	return {
		"completed_day": 3,
		"next_day": 4,
		"crops_advanced": 2,
		"crops_withered": 0,
		"next_weather": GameRules.weather_key(GameRules.Weather.RAINY),
		"stamina_restored": GameRules.MAX_STAMINA,
		"shipments": [{"crop": &"turnip", "quantity": 2, "amount": 70}],
		"shipping_income": 70,
		"money_after_shipping": 220,
	}

func _sleep_panel(day: int = 4) -> SleepPanel:
	var sleep := _spawn_panel("res://scenes/ui/sleep_panel.tscn") as SleepPanel
	if sleep == null:
		return null
	sleep.present({"day": day})
	return sleep

func _morning_panel(summary: Dictionary = {}) -> MorningSummaryPanel:
	var panel := _spawn_panel(
		"res://scenes/ui/morning_summary_panel.tscn"
	) as MorningSummaryPanel
	if panel == null:
		return null
	panel.present(_morning_summary() if summary.is_empty() else summary)
	return panel

func _pause_panel() -> PausePanel:
	var pause := _spawn_panel("res://scenes/ui/pause_panel.tscn") as PausePanel
	if pause == null:
		return null
	pause.set_status_time("09:20")
	pause.set_day_weather(3, GameRules.weather_key(GameRules.Weather.SUNNY))
	return pause

func _stylebox(control: Control) -> StyleBoxFlat:
	return control.get_theme_stylebox("panel") as StyleBoxFlat

func _bottom_box(panel: Control) -> StyleBoxFlat:
	var bottom := _frame(panel).find_child("BottomBar", true, false) as PanelContainer
	assert_not_null(bottom)
	if bottom == null:
		return null
	return _stylebox(bottom)

func _home_bar_box(panel: Control) -> StyleBoxFlat:
	var bar := _frame(panel).find_child("Bar", true, false) as Panel
	assert_not_null(bar)
	if bar == null:
		return null
	return _stylebox(bar)

func _status_time_label(panel: Control) -> Label:
	return _frame(panel).find_child("Time", true, false) as Label

func test_phone_frame_backplate_covers_status_row_and_home_indicator() -> void:
	var frame := PhoneFrame.new()
	add_child_autoqfree(frame)
	assert_true(frame.has_method("set_screen_backplate"), "backplate mount API")
	if not frame.has_method("set_screen_backplate"):
		return
	frame.call("set_screen_backplate", TITLE_ART)
	await _settle()
	var backplate := frame.get_node_or_null("Backplate") as TextureRect
	assert_not_null(backplate, "backplate texture rect mounts on the frame")
	if backplate == null:
		return
	assert_true(backplate.visible)
	assert_eq(backplate.texture, TITLE_ART)
	var screen := frame.get_node("Screen") as Control
	var screen_rect := screen.get_global_rect()
	assert_almost_eq(backplate.get_global_rect().position.x, screen_rect.position.x, 0.5)
	assert_almost_eq(backplate.get_global_rect().position.y, screen_rect.position.y, 0.5)
	assert_almost_eq(backplate.get_global_rect().end.x, screen_rect.end.x, 0.5)
	assert_almost_eq(backplate.get_global_rect().end.y, screen_rect.end.y, 0.5)
	var status := frame.find_child("StatusBar", true, false) as Control
	var home := frame.find_child("HomeIndicator", true, false) as Control
	assert_true(
		backplate.get_global_rect().encloses(status.get_global_rect())
		and backplate.get_global_rect().encloses(home.get_global_rect()),
		"wallpaper runs behind the status row and home indicator",
	)
	var screen_box := _stylebox(screen)
	assert_true(screen_box.bg_color.a < 0.05, "screen clears so wallpaper shows")
	var time := _status_time_label(frame)
	assert_eq(
		time.get_theme_color("font_color"),
		UiStyle.CARD,
		"status ink turns light over wallpaper",
	)

func test_phone_frame_flat_backplate_tints_whole_screen_for_alarm_surface() -> void:
	var frame := PhoneFrame.new()
	add_child_autoqfree(frame)
	assert_true(frame.has_method("set_screen_backplate"), "flat fill API")
	if not frame.has_method("set_screen_backplate"):
		return
	var alarm_ink := Color("141a2b")
	frame.call("set_screen_backplate", null, alarm_ink, UiStyle.CARD, Color("5a6584"))
	await _settle()
	var screen := frame.get_node("Screen") as Control
	assert_eq(_stylebox(screen).bg_color, alarm_ink, "flat fill tints the whole screen")
	var backplate := frame.get_node_or_null("Backplate") as TextureRect
	if backplate != null:
		assert_false(backplate.visible, "flat fill needs no texture")
	var bottom := frame.find_child("BottomBar", true, false) as PanelContainer
	var bottom_box := _stylebox(bottom)
	assert_true(bottom_box.bg_color.a < 0.05, "home strip stays on the dark surface")
	var home_bar := frame.find_child("Bar", true, false) as Panel
	assert_eq(_stylebox(home_bar).bg_color, Color("5a6584"), "slate home bar")
	var time := _status_time_label(frame)
	assert_eq(time.get_theme_color("font_color"), UiStyle.CARD)

func test_phone_frame_clear_backplate_restores_light_chrome() -> void:
	var frame := PhoneFrame.new()
	add_child_autoqfree(frame)
	assert_true(
		frame.has_method("set_screen_backplate")
		and frame.has_method("clear_screen_backplate"),
		"backplate lifecycle API",
	)
	if not frame.has_method("clear_screen_backplate"):
		return
	frame.call("set_screen_backplate", null, Color("141a2b"))
	frame.call("clear_screen_backplate")
	await _settle()
	var screen := frame.get_node("Screen") as Control
	assert_eq(_stylebox(screen).bg_color, UiStyle.SOFT, "screen returns to light surface")
	var bottom := frame.find_child("BottomBar", true, false) as PanelContainer
	var bottom_box := _stylebox(bottom)
	assert_eq(bottom_box.bg_color, UiStyle.CARD, "bottom bar restores the card fill")
	assert_eq(bottom_box.get_border_width(SIDE_TOP), 1, "hairline returns")
	var home_bar := frame.find_child("Bar", true, false) as Panel
	assert_eq(_stylebox(home_bar).bg_color, UiStyle.LINE, "home bar restores light")
	var time := _status_time_label(frame)
	assert_eq(time.get_theme_color("font_color"), UiStyle.INK)

func test_phone_frame_status_time_can_hide_on_lock_surfaces() -> void:
	var frame := PhoneFrame.new()
	add_child_autoqfree(frame)
	frame.set_status_time("06:00")
	assert_true(frame.has_method("set_status_time_visible"), "lock clock toggle")
	if not frame.has_method("set_status_time_visible"):
		return
	frame.call("set_status_time_visible", false)
	await _settle()
	var time := _status_time_label(frame)
	assert_false(time.visible, "lock surfaces hide the redundant status clock")
	assert_eq(frame.status_time_text(), "06:00", "time still tracked for tests")
	frame.call("set_status_time_visible", true)
	assert_true(time.visible)

func test_pause_wallpaper_runs_behind_status_row_and_home_indicator() -> void:
	var pause := _pause_panel()
	if pause == null:
		return
	await _settle()
	var frame := _frame(pause)
	var backplate := frame.get_node_or_null("Backplate") as TextureRect
	assert_not_null(backplate, "pause mounts a wallpaper backplate")
	if backplate == null:
		return
	assert_true(backplate.visible)
	assert_not_null(backplate.texture)
	var status := frame.find_child("StatusBar", true, false) as Control
	var home := frame.find_child("HomeIndicator", true, false) as Control
	assert_true(
		backplate.get_global_rect().encloses(status.get_global_rect()),
		"wallpaper runs behind the status row",
	)
	assert_true(
		backplate.get_global_rect().encloses(home.get_global_rect()),
		"wallpaper runs behind the home indicator",
	)
	var clipped: Array[String] = []
	for control in pause.find_children("*", "Control", true, false) as Array[Control]:
		if control.clip_children == CanvasItem.CLIP_CHILDREN_DISABLED:
			continue
		for child in control.find_children("*", "Control", true, false) as Array[Control]:
			if child.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED:
				clipped.append("%s>%s" % [control.name, child.name])
	assert_eq(clipped, [], "no nested clip masks on the home screen")

func test_pause_lock_block_shows_big_clock_day_weather_and_paused() -> void:
	var pause := _pause_panel()
	if pause == null:
		return
	await _settle()
	var clock := pause.find_child("LockTime", true, false) as Label
	assert_not_null(clock, "big lock clock on the home screen")
	if clock == null:
		return
	assert_eq(clock.text, "09:20")
	assert_true(clock.get_theme_font_size("font_size") >= 70, "lock clock reads at glance")
	assert_eq(clock.get_theme_color("font_color"), UiStyle.CARD)
	assert_eq(pause.day_weather_text(), "Day 3 · Sunny")
	var paused_tail := pause.find_child("PausedTail", true, false) as Label
	assert_not_null(paused_tail, "paused marker trails the day line")
	if paused_tail != null:
		assert_true(paused_tail.text.contains("Paused"))
	var status := _status_time_label(pause)
	assert_eq(status.text, "09:20", "status row keeps the real clock")

func test_pause_app_tiles_badge_keycaps_on_tinted_icon_tiles() -> void:
	var pause := _pause_panel()
	if pause == null:
		return
	await _settle()
	var expected := {
		"BagTile": "I", "AlmanacTile": "B",
		"CalendarTile": "C", "SettingsTile": "O",
	}
	for tile_name in expected:
		var tile := pause.find_child(tile_name, true, false) as Control
		assert_not_null(tile, tile_name)
		if tile == null:
			continue
		var icon := tile.find_child("Icon", true, false) as Panel
		assert_not_null(icon, "%s keeps a tinted icon tile" % tile_name)
		if icon == null:
			continue
		assert_true(icon.size.x >= 84.0, "%s icon tile is phone sized" % tile_name)
		var badge := tile.find_child("KeyBadge", true, false) as Control
		assert_not_null(badge, "%s badges its keycap on the tile corner" % tile_name)
		if badge == null:
			continue
		var key := badge.find_child("Key", true, false) as Label
		assert_not_null(key)
		if key != null:
			assert_eq(key.text, expected[tile_name])
		var badge_rect := badge.get_global_rect()
		var icon_rect := icon.get_global_rect()
		assert_true(
			badge_rect.intersects(icon_rect),
			"%s badge overlaps the tile corner" % tile_name,
		)
		assert_true(
			badge_rect.end.x > icon_rect.end.x or badge_rect.position.y < icon_rect.position.y,
			"%s badge bleeds off the corner like the reference" % tile_name,
		)
		var name_label := tile.find_child("Name", true, false) as Label
		assert_not_null(name_label, "%s keeps a name under the tile" % tile_name)

func test_pause_controls_glass_lists_real_hold_and_interact_hints() -> void:
	var pause := _pause_panel()
	if pause == null:
		return
	await _settle()
	var controls := pause.find_child("Controls", true, false) as PanelContainer
	assert_not_null(controls)
	if controls == null:
		return
	var box := _stylebox(controls)
	assert_true(box.bg_color.a > 0.8, "controls widget is a readable glass card")
	var copies: Array[String] = []
	for item in controls.find_children("*", "Label", true, false):
		copies.append((item as Label).text)
	assert_true(copies.has("Till, plant, water or harvest. Hold to keep going."))
	assert_true(copies.has("Talk, shop, bin, bed"))
	assert_true(copies.has("Switch seed"))
	assert_true(copies.has("Walk; you face the tile you'll work"))

func test_pause_resume_pill_sits_inside_the_phone_and_emits() -> void:
	var pause := _pause_panel()
	if pause == null:
		return
	await _settle()
	var resume := pause.find_child("Resume", true, false) as Button
	assert_not_null(resume, "resume is a real button inside the phone")
	if resume == null:
		return
	var screen_rect := _screen_rect(pause)
	assert_true(
		screen_rect.encloses(resume.get_global_rect()),
		"resume pill sits inside the phone screen",
	)
	assert_true(
		resume.get_global_rect().get_center().y > screen_rect.get_center().y,
		"resume anchors the bottom of the home screen",
	)
	var caption := resume.find_child("Text", true, false) as Label
	assert_not_null(caption)
	if caption != null:
		assert_eq(caption.text, "Back to the farm")
	watch_signals(pause)
	await _click(resume)
	assert_signal_emitted(pause, "resume_requested")

func test_pause_release_outside_the_resume_pill_cancels_the_click() -> void:
	var pause := _pause_panel()
	if pause == null:
		return
	await _settle()
	var resume := pause.find_child("Resume", true, false) as Button
	assert_not_null(resume)
	if resume == null:
		return
	watch_signals(pause)
	await _press_and_release_outside(resume)
	assert_signal_not_emitted(pause, "resume_requested")

func test_pause_everything_stays_inside_the_screen() -> void:
	var pause := _pause_panel()
	if pause == null:
		return
	await _settle()
	_assert_controls_inside(pause, "pause home")

func test_sleep_alarm_surface_fills_the_whole_screen_in_dark_ink() -> void:
	var sleep := _sleep_panel(4)
	if sleep == null:
		return
	await _settle()
	var screen := _screen(sleep)
	if screen == null:
		return
	var box := _stylebox(screen)
	assert_true(box.bg_color.a > 0.9, "alarm surface is opaque")
	assert_true(
		box.bg_color.v < 0.25 and box.bg_color.s > 0.3,
		"alarm surface is the dark ink from the reference",
	)
	var bottom_box := _bottom_box(sleep)
	assert_true(bottom_box.bg_color.a < 0.05, "home strip rides on the dark surface")
	var time := _status_time_label(sleep)
	assert_eq(
		time.get_theme_color("font_color"),
		UiStyle.CARD,
		"status clock stays readable on dark",
	)
	var app_title := _frame(sleep).find_child("AppTitle", true, false) as Label
	assert_not_null(app_title, "sleep keeps the shared app header")
	if app_title != null:
		assert_eq(app_title.text, "Alarm")

func test_sleep_alarm_card_shows_toggle_and_the_wake_day() -> void:
	var sleep := _sleep_panel(4)
	if sleep == null:
		return
	await _settle()
	var card := sleep.find_child("AlarmCard", true, false) as Control
	assert_not_null(card)
	if card == null:
		return
	var card_box := _stylebox(card)
	assert_true(
		card_box.bg_color.v < 0.3 and card_box.bg_color.a > 0.9,
		"alarm card is a slightly lifted dark slab",
	)
	var alarm := card.find_child("AlarmTime", true, false) as Label
	assert_not_null(alarm)
	if alarm != null:
		assert_eq(alarm.text, GameRules.format_time(GameRules.DAY_START_MINUTES))
		assert_true(alarm.get_theme_font_size("font_size") >= 64, "alarm target reads huge")
		assert_eq(alarm.get_theme_color("font_color"), UiStyle.CARD)
	var wake := card.find_child("WakeDay", true, false) as Label
	assert_not_null(wake, "the wake day line sits under the alarm time")
	if wake != null:
		assert_true(wake.text.contains("wake up"), "wake day reads like the alarm app")
	var toggle := card.find_child("AlarmSwitch", true, false) as Control
	assert_not_null(toggle, "the always-on alarm switch from the reference")
	if toggle != null:
		var knob := toggle.find_child("Knob", true, false) as Control
		assert_not_null(knob)
		if knob != null:
			assert_true(
				knob.get_global_rect().get_center().x
					> toggle.get_global_rect().get_center().x,
				"alarm switch reads ON",
			)

func test_sleep_confirm_and_ghost_row_sit_inside_the_phone() -> void:
	var sleep := _sleep_panel(4)
	if sleep == null:
		return
	await _settle()
	var screen_rect := _screen_rect(sleep)
	var confirm := sleep.find_child("Confirm", true, false) as Button
	assert_not_null(confirm, "sleep keeps a primary confirm button")
	if confirm == null:
		return
	assert_true(
		screen_rect.encloses(confirm.get_global_rect()),
		"confirm pill sits inside the phone screen",
	)
	assert_true(
		confirm.get_global_rect().get_center().y > screen_rect.get_center().y,
		"confirm anchors the bottom of the alarm screen",
	)
	var ghost := sleep.find_child("CancelRow", true, false) as Control
	assert_not_null(ghost, "esc ghost hint under the confirm pill")
	if ghost != null:
		assert_true(
			screen_rect.encloses(ghost.get_global_rect()),
			"ghost hint stays inside the phone",
		)
		var texts: Array[String] = []
		for item in ghost.find_children("*", "Label", true, false):
			texts.append((item as Label).text)
		assert_true(texts.has("Esc"))
		assert_true(texts.has("not yet"))
	watch_signals(sleep)
	await _click(confirm)
	assert_signal_emitted(sleep, "sleep_requested")

func test_sleep_day14_warning_stays_inside_the_phone() -> void:
	var sleep := _sleep_panel(GameRules.MAX_DAY)
	if sleep == null:
		return
	await _settle()
	assert_true(sleep.day14_warning_visible())
	assert_true(
		sleep.day14_warning_text().contains("this ends the season"),
		"day 14 copy is preserved",
	)
	var warning := sleep.find_child("Warning", true, false) as Control
	assert_not_null(warning)
	if warning != null:
		assert_true(
			_screen_rect(sleep).encloses(warning.get_global_rect()),
			"warning banner stays inside the phone",
		)
	_assert_controls_inside(sleep, "sleep day 14")

func test_sleep_screen_keeps_everything_inside_on_a_normal_day() -> void:
	var sleep := _sleep_panel(4)
	if sleep == null:
		return
	await _settle()
	_assert_controls_inside(sleep, "sleep alarm")

func test_morning_wallpaper_runs_behind_status_row_and_home() -> void:
	var summary := _morning_panel()
	if summary == null:
		return
	await _settle()
	var frame := _frame(summary)
	var backplate := frame.get_node_or_null("Backplate") as TextureRect
	assert_not_null(backplate, "morning mounts a wallpaper backplate")
	if backplate == null:
		return
	assert_true(backplate.visible)
	assert_not_null(backplate.texture)
	var status := frame.find_child("StatusBar", true, false) as Control
	var home := frame.find_child("HomeIndicator", true, false) as Control
	assert_true(
		backplate.get_global_rect().encloses(status.get_global_rect())
		and backplate.get_global_rect().encloses(home.get_global_rect()),
		"wallpaper runs behind status row and home indicator",
	)

func test_morning_lock_header_hides_the_status_clock() -> void:
	var summary := _morning_panel()
	if summary == null:
		return
	summary.set_status_time("06:00")
	await _settle()
	var status := _status_time_label(summary)
	assert_false(
		status.visible,
		"lock screen hides the redundant status clock",
	)
	assert_eq(summary.status_time_text(), "06:00", "time still tracked")
	var clock := summary.find_child("LockTime", true, false) as Label
	assert_not_null(clock, "big lock clock")
	if clock != null:
		assert_eq(clock.text, GameRules.format_time(GameRules.DAY_START_MINUTES))
		assert_true(clock.get_theme_font_size("font_size") >= 90, "lock clock is huge")
	var day_line := summary.find_child("DayLine", true, false) as Label
	assert_not_null(day_line)
	if day_line != null:
		assert_eq(day_line.text, "Day 3 → Day 4")
	var weather := summary.find_child("WeatherTail", true, false) as Label
	assert_not_null(weather, "weather trails the lock day line")
	if weather != null:
		assert_true(weather.text.contains("Rainy"))

func test_morning_notification_cards_carry_real_facts() -> void:
	var summary := _morning_panel()
	if summary == null:
		return
	await _settle()
	var weather_card := summary.find_child("WeatherCard", true, false) as Control
	assert_not_null(weather_card, "weather notification card")
	var farm_card := summary.find_child("FarmCard", true, false) as Control
	assert_not_null(farm_card, "farm notification card")
	var bank_card := summary.find_child("BankCard", true, false) as Control
	assert_not_null(bank_card, "bank notification card")
	if weather_card == null or farm_card == null or bank_card == null:
		return
	for card in [weather_card, farm_card, bank_card]:
		var header := card.find_child("Header", true, false) as Label
		var stamp := card.find_child("Stamp", true, false) as Label
		var headline := card.find_child("Headline", true, false) as Label
		var sub := card.find_child("Sub", true, false) as Label
		assert_not_null(header)
		assert_not_null(stamp)
		assert_not_null(headline)
		assert_not_null(sub)
		var tile := card.find_child("Tile", true, false) as Control
		assert_not_null(tile, "%s keeps an app tile" % card.name)
		assert_true(
			_screen_rect(summary).encloses(card.get_global_rect()),
			"%s inside the phone" % card.name,
		)
	assert_eq(
		(weather_card.find_child("Headline", true, false) as Label).text,
		"Rain all day",
	)
	assert_eq(
		(weather_card.find_child("Sub", true, false) as Label).text,
		"No watering needed today.",
	)
	assert_eq(
		(farm_card.find_child("Headline", true, false) as Label).text,
		"2 crops grew overnight",
	)
	assert_eq(
		(farm_card.find_child("Sub", true, false) as Label).text,
		"Stamina is back to 20.",
	)
	assert_eq(
		(bank_card.find_child("Headline", true, false) as Label).text,
		"Shipping payout +70G",
	)
	assert_eq(
		(bank_card.find_child("Header", true, false) as Label).text, "BANK"
	)
	assert_eq(
		(farm_card.find_child("Header", true, false) as Label).text, "FARM"
	)
	assert_eq(
		(weather_card.find_child("Header", true, false) as Label).text, "WEATHER"
	)

func test_morning_bank_card_renders_empty_and_three_shipments() -> void:
	var empty := _morning_summary()
	empty["shipments"] = []
	empty["shipping_income"] = 0
	var summary := _morning_panel(empty)
	if summary == null:
		return
	await _settle()
	var bank_card := summary.find_child("BankCard", true, false) as Control
	assert_not_null(bank_card)
	if bank_card == null:
		return
	var headline := bank_card.find_child("Headline", true, false) as Label
	assert_eq(headline.text, "No shipping payout")
	var empty_label := summary.find_child("EmptyShipment", true, false) as Label
	assert_not_null(empty_label)
	if empty_label != null:
		assert_true(empty_label.visible)
		assert_eq(empty_label.text, "No crops shipped.")

	var full := _morning_summary()
	full["shipments"] = [
		{"crop": &"turnip", "quantity": 2, "amount": 70},
		{"crop": &"potato", "quantity": 1, "amount": 80},
		{"crop": &"pumpkin", "quantity": 3, "amount": 300},
	]
	full["shipping_income"] = 450
	var packed := _morning_panel(full)
	if packed == null:
		return
	await _settle()
	var compact := packed.find_child("CompactShipmentRows", true, false) as Control
	assert_not_null(compact)
	if compact == null:
		return
	assert_true(compact.visible)
	var state := packed.summary_state()
	assert_eq(state["shipment_mode"], "compact")
	assert_eq(state["shipments"].size(), 3)
	_assert_controls_inside(packed, "morning three shipments")

func test_morning_acknowledge_pill_sits_inside_the_phone_and_emits() -> void:
	var summary := _morning_panel()
	if summary == null:
		return
	await _settle()
	var acknowledge := summary.find_child("Acknowledge", true, false) as Button
	assert_not_null(acknowledge, "acknowledge is a real button inside the phone")
	if acknowledge == null:
		return
	var screen_rect := _screen_rect(summary)
	assert_true(
		screen_rect.encloses(acknowledge.get_global_rect()),
		"start-day pill sits inside the phone screen",
	)
	assert_true(
		acknowledge.get_global_rect().get_center().y > screen_rect.get_center().y,
		"acknowledge anchors the bottom of the lock screen",
	)
	var state := summary.summary_state()
	assert_eq(state["action_text"], "START DAY 4")
	watch_signals(summary)
	await _click(acknowledge)
	assert_signal_emitted(summary, "acknowledged")

func test_morning_save_chip_and_error_stay_inside_the_phone() -> void:
	var summary := _morning_panel()
	if summary == null:
		return
	summary.set_save_status(&"saved")
	await _settle()
	var badge := summary.find_child("SaveBadge", true, false) as Control
	assert_not_null(badge)
	if badge == null:
		return
	assert_true(badge.visible)
	assert_true(
		_screen_rect(summary).encloses(badge.get_global_rect()),
		"save chip sits inside the phone",
	)
	assert_eq(summary.save_status_text(), "Saved.")
	summary.set_save_status(&"error", "Save failed — this morning is not persisted.")
	await _settle()
	var status := summary.find_child("SaveStatus", true, false) as Label
	assert_not_null(status)
	if status == null:
		return
	assert_eq(status.text, "Save failed — this morning is not persisted.")
	assert_eq(status.get_theme_color("font_color"), UiStyle.BAD, "errors read red")
	var card := summary.find_child("SaveStatusCard", true, false) as Control
	assert_not_null(card, "error rides a backed card")
	if card != null:
		assert_true(
			_screen_rect(summary).encloses(card.get_global_rect()),
			"backed error surface stays inside the phone",
		)
	_assert_controls_inside(summary, "morning save error")

func test_morning_long_save_error_wraps_bounded_inside_the_phone() -> void:
	var summary := _morning_panel()
	if summary == null:
		return
	var long_message := (
		"Save failed — this morning is not persisted. "
		+ "The storage card is full after the long festival season and the "
		+ "ledger could not be written; keep playing and try again."
	)
	summary.set_save_status(&"error", long_message)
	await _settle()
	var status := summary.find_child("SaveStatus", true, false) as Label
	assert_not_null(status)
	if status == null:
		return
	var screen_rect := _screen_rect(summary)
	var status_rect := status.get_global_rect()
	var card := summary.find_child("SaveStatusCard", true, false) as Control
	assert_not_null(card, "long error rides a backed card")
	if card != null:
		assert_true(
			screen_rect.encloses(card.get_global_rect()),
			"long error's backed surface stays inside the phone",
		)
		assert_true(
			status_rect.size.x <= card.get_global_rect().size.x,
			"long error wraps inside the backed surface",
		)
	assert_true(
		status.autowrap_mode != TextServer.AUTOWRAP_OFF,
		"long error wraps instead of clipping",
	)
	assert_true(
		status.get_theme_font_size("font_size") >= 15,
		"error stays readable at 960x540",
	)
	assert_eq(summary.save_status_text(), long_message, "full message preserved")
	_assert_controls_inside(summary, "morning long error")

func test_morning_save_error_rides_a_backed_legible_surface() -> void:
	var summary := _morning_panel()
	if summary == null:
		return
	summary.set_save_status(&"error", "Save failed — this morning is not persisted.")
	await _settle()
	var card := summary.find_child("SaveStatusCard", true, false) as PanelContainer
	assert_not_null(card, "error rides a backed surface, not bare wallpaper text")
	var status := summary.find_child("SaveStatus", true, false) as Label
	assert_not_null(status)
	if card == null or status == null:
		return
	var box := _stylebox(card)
	assert_true(box.bg_color.a >= 0.85, "backing is opaque over the busy wallpaper")
	assert_true(
		(box.bg_color.r + box.bg_color.g + box.bg_color.b) / 3.0 > 0.7,
		"backing stays light so the red error ink reads",
	)
	assert_gte(
		status.get_theme_font_size("font_size"),
		20,
		"error text is legible at native scale",
	)
	assert_eq(
		status.get_theme_color("font_color"), UiStyle.BAD, "errors still read red"
	)
	assert_true(
		card.get_global_rect().encloses(status.get_global_rect())
		or card.find_child("SaveStatusScroll", true, false) != null,
		"backing wraps the error text",
	)
	assert_true(
		_screen_rect(summary).encloses(card.get_global_rect()),
		"backed error stays inside the phone",
	)

func test_morning_long_localized_errors_wrap_fully_without_silent_loss() -> void:
	var summary := _morning_panel()
	if summary == null:
		return
	var status := summary.find_child("SaveStatus", true, false) as Label
	assert_not_null(status)
	if status == null:
		return
	await _settle()
	var screen_rect := _screen_rect(summary)
	var messages: Array[String] = [
		(
			"Save failed — this morning is not persisted. The storage card is "
			+ "full after the long festival season and the ledger could not be "
			+ "written; keep playing and try again."
		),
		"存檔失敗——今天早上的進度沒有保存。儲存卡在漫長的祭典季節之後已滿，帳目無法寫入；請繼續遊戲並再試一次，請不要關閉電源。",
		"セーブに失敗しました——今朝の進行は保存されていません。長い祭りの季節のあとでセーブ領域がいっぱいになり、帳簿を書き込めませんでした。そのまま遊んで、もう一度お試しください。",
	]
	for message in messages:
		summary.set_save_status(&"error", message)
		await _settle()
		assert_eq(
			status.max_lines_visible,
			-1,
			"failure detail is never silently capped",
		)
		assert_true(
			status.get_line_count() > 3,
			"long localized errors keep every wrapped line",
		)
		assert_eq(summary.save_status_text(), message, "full message preserved")
		var card := summary.find_child("SaveStatusCard", true, false) as Control
		assert_not_null(card)
		if card != null:
			assert_true(
				screen_rect.encloses(card.get_global_rect()),
				"backed error card stays inside the phone",
			)

func test_morning_full_content_long_error_keeps_acknowledge_reachable() -> void:
	var full := _morning_summary()
	full["crops_withered"] = 2
	full["shipments"] = [
		{"crop": &"turnip", "quantity": 2, "amount": 70},
		{"crop": &"potato", "quantity": 1, "amount": 80},
		{"crop": &"pumpkin", "quantity": 3, "amount": 300},
	]
	full["shipping_income"] = 450
	full["money_after_shipping"] = 600
	var summary := _morning_panel(full)
	if summary == null:
		return
	summary.set_save_status(
		&"error",
		(
			"Save failed — this morning is not persisted. The storage card is "
			+ "full after the long festival season and the ledger could not be "
			+ "written; keep playing and try again."
		),
	)
	await _settle()
	var screen_rect := _screen_rect(summary)
	for node_name in ["SaveBadge", "SaveStatusCard", "SaveStatusScroll", "Acknowledge"]:
		var node := summary.find_child(node_name, true, false) as Control
		assert_not_null(node, node_name)
		if node != null:
			assert_true(
				screen_rect.encloses(node.get_global_rect()),
				"%s stays inside the phone" % node_name,
			)
	var acknowledge := summary.find_child("Acknowledge", true, false) as Button
	if acknowledge != null:
		assert_true(
			acknowledge.get_global_rect().get_center().y > screen_rect.get_center().y,
			"acknowledge stays reachable at the bottom",
		)
		watch_signals(summary)
		await _click(acknowledge)
		assert_signal_emitted(summary, "acknowledged")
	_assert_controls_inside(summary, "morning full content + long error")

func test_morning_long_error_scrolls_with_move_keys_and_shows_hint() -> void:
	var summary := _morning_panel()
	if summary == null:
		return
	summary.set_save_status(
		&"error",
		(
			"Save failed — this morning is not persisted. The storage card is "
			+ "full after the long festival season and the ledger could not be "
			+ "written; keep playing and try again."
		),
	)
	await _settle()
	var scroll := summary.find_child(
		"SaveStatusScroll", true, false
	) as ScrollContainer
	assert_not_null(scroll)
	var hint := summary.find_child("ScrollHint", true, false) as Label
	assert_not_null(hint, "a keyboard scroll hint exists")
	if scroll == null or hint == null:
		return
	assert_true(hint.visible, "hint shows only while the detail overflows")
	assert_false(hint.text.is_empty(), "hint is a real localized caption")
	assert_eq(scroll.scroll_vertical, 0, "a fresh error starts at the top")
	var spy := UnhandledSpy.new()
	add_child_autoqfree(spy)
	_press("move_down")
	await _settle()
	assert_gt(scroll.scroll_vertical, 0, "move_down reveals more detail")
	for _press_index in 6:
		_press("move_down")
	await _settle()
	var bottom := scroll.scroll_vertical
	assert_gt(bottom, 0)
	_press("move_down")
	await _settle()
	assert_eq(
		scroll.scroll_vertical, bottom, "move_down clamps at the last line"
	)
	_press("move_up")
	await _settle()
	assert_lt(scroll.scroll_vertical, bottom, "move_up scrolls back")
	assert_eq(spy.presses, [], "scrolling keys never leak into the world")
	watch_signals(summary)
	_press("ui_accept")
	await _settle()
	assert_signal_emitted(summary, "acknowledged")

func test_morning_short_status_hides_scroll_hint_and_ignores_move_keys() -> void:
	var summary := _morning_panel()
	if summary == null:
		return
	var scroll := summary.find_child(
		"SaveStatusScroll", true, false
	) as ScrollContainer
	assert_not_null(scroll)
	var hint := summary.find_child("ScrollHint", true, false) as Label
	assert_not_null(hint)
	if scroll == null or hint == null:
		return
	summary.set_save_status(&"saved")
	await _settle()
	assert_false(hint.visible, "no scroll affordance when the line fits")
	_press("move_down")
	await _settle()
	assert_eq(scroll.scroll_vertical, 0, "move_down is a no-op without overflow")
	summary.set_save_status(&"error", "Save failed — this morning is not persisted.")
	await _settle()
	assert_false(hint.visible, "the real localized message fits unclipped")
	_press("move_down")
	await _settle()
	assert_eq(scroll.scroll_vertical, 0, "short error still scrolls nowhere")
	summary.set_save_status(&"idle")
	await _settle()
	assert_false(hint.visible, "idle hides every save surface")

func test_morning_day14_summary_stays_inside_the_phone() -> void:
	var finale := _morning_summary()
	finale["completed_day"] = GameRules.MAX_DAY - 1
	finale["next_day"] = GameRules.MAX_DAY
	finale["shipments"] = [
		{"crop": &"turnip", "quantity": 2, "amount": 70},
		{"crop": &"potato", "quantity": 1, "amount": 80},
		{"crop": &"pumpkin", "quantity": 3, "amount": 300},
	]
	var summary := _morning_panel(finale)
	if summary == null:
		return
	summary.set_save_status(&"saved")
	await _settle()
	_assert_controls_inside(summary, "morning day 14")
	var state := summary.summary_state()
	assert_eq(state["action_text"], "START DAY 14")

func _primary_pill(button: Button) -> Control:
	assert_not_null(button)
	if button == null:
		return null
	return button.find_child("Pill", true, false) as Control

func _primary_specs() -> Array[Dictionary]:
	return [
		{"kind": "pause", "button": "Resume", "signal": &"resume_requested"},
		{"kind": "morning", "button": "Acknowledge", "signal": &"acknowledged"},
		{"kind": "sleep", "button": "Confirm", "signal": &"sleep_requested"},
	]

func _primary_panel(kind: String) -> Control:
	match kind:
		"pause":
			return _pause_panel()
		"morning":
			return _morning_panel()
		"sleep":
			return _sleep_panel(4)
	return null

func test_primary_action_pills_paint_exactly_over_their_native_hitboxes() -> void:
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		for spec in _primary_specs():
			var panel := _primary_panel(spec["kind"])
			assert_not_null(panel, "%s %s panel" % [locale, spec["button"]])
			if panel == null:
				continue
			await _settle()
			var button := panel.find_child(
				spec["button"], true, false
			) as Button
			var pill := _primary_pill(button)
			assert_not_null(pill, "%s %s paints a pill" % [locale, spec["button"]])
			if pill == null:
				continue
			var pill_rect := pill.get_global_rect()
			var button_rect := button.get_global_rect()
			assert_almost_eq(
				pill_rect.position.x, button_rect.position.x, 0.5,
				"%s %s painted pill starts where the hitbox starts"
					% [locale, spec["button"]],
			)
			assert_almost_eq(
				pill_rect.end.x, button_rect.end.x, 0.5,
				"%s %s painted pill right edge is clickable"
					% [locale, spec["button"]],
			)
			assert_almost_eq(
				pill_rect.position.y, button_rect.position.y, 0.5,
				"%s %s painted pill top edge is clickable"
					% [locale, spec["button"]],
			)
			assert_almost_eq(
				pill_rect.end.y, button_rect.end.y, 0.5,
				"%s %s painted pill bottom edge is clickable"
					% [locale, spec["button"]],
			)
			assert_almost_eq(
				pill_rect.get_center().x, button_rect.get_center().x, 0.5,
				"%s %s paint and hitbox share a center"
					% [locale, spec["button"]],
			)
			panel.visible = false

func test_primary_action_pill_painted_edges_take_native_presses() -> void:
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		for spec in _primary_specs():
			var panel := _primary_panel(spec["kind"])
			assert_not_null(panel, "%s %s panel" % [locale, spec["button"]])
			if panel == null:
				continue
			await _settle()
			var button := panel.find_child(
				spec["button"], true, false
			) as Button
			var pill := _primary_pill(button)
			assert_not_null(pill, "%s %s paints a pill" % [locale, spec["button"]])
			if pill == null:
				continue
			var pill_rect := pill.get_global_rect()
			var mid := pill_rect.size.y * 0.5
			watch_signals(panel)
			await _click_at(pill_rect.position + Vector2(4, mid))
			await _click_at(pill_rect.end - Vector2(4, mid))
			assert_signal_emit_count(
				panel, spec["signal"], 2,
				(
					"%s %s presses at both painted edges of the pill"
					% [locale, spec["button"]]
				),
			)
			panel.visible = false

func test_primary_action_pill_release_outside_cancels_the_press() -> void:
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		for spec in _primary_specs():
			var panel := _primary_panel(spec["kind"])
			assert_not_null(panel, "%s %s panel" % [locale, spec["button"]])
			if panel == null:
				continue
			await _settle()
			var button := panel.find_child(
				spec["button"], true, false
			) as Button
			var pill := _primary_pill(button)
			if pill == null:
				continue
			var pill_rect := pill.get_global_rect()
			var mid := pill_rect.size.y * 0.5
			watch_signals(panel)
			await _press_at_release_outside(
				pill_rect.end - Vector2(4, mid)
			)
			assert_signal_not_emitted(
				panel, spec["signal"],
				(
					"%s %s release outside cancels the painted right edge press"
					% [locale, spec["button"]]
				),
			)
			panel.visible = false

func test_morning_acknowledge_hitbox_tracks_caption_changes() -> void:
	var summary := _morning_panel()
	if summary == null:
		return
	await _settle()
	var acknowledge := summary.find_child(
		"Acknowledge", true, false
	) as Button
	var pill := _primary_pill(acknowledge)
	assert_not_null(pill)
	if pill == null:
		return
	assert_almost_eq(
		pill.get_global_rect().size.x,
		acknowledge.get_global_rect().size.x,
		0.5,
		"present() lands the caption inside the hitbox",
	)
	var caption := pill.find_child("Text", true, false) as Label
	assert_not_null(caption)
	if caption == null:
		return
	caption.text = (
		"Save failed — this morning is not persisted. The storage card is full"
	)
	await _settle()
	assert_almost_eq(
		pill.get_global_rect().size.x,
		acknowledge.get_global_rect().size.x,
		0.5,
		"a longer caption keeps the hitbox synced to the paint",
	)
	assert_almost_eq(
		pill.get_global_rect().get_center().x,
		acknowledge.get_global_rect().get_center().x,
		0.5,
		"paint and hitbox stay centered after the caption changes",
	)

func test_sleep_wake_day_only_promises_a_morning_that_exists() -> void:
	for day in [1, 13]:
		var sleep := _sleep_panel(day)
		if sleep == null:
			continue
		await _settle()
		var wake := sleep.find_child("WakeDay", true, false) as Label
		assert_not_null(wake)
		if wake == null:
			continue
		assert_true(
			wake.is_visible_in_tree(),
			"day %d alarm still names tomorrow" % day,
		)
		assert_eq(
			wake.text,
			tr("Day %d · wake up") % (day + 1),
			"day %d names day %d as the wake day" % [day, day + 1],
		)
		assert_false(
			sleep.day14_warning_visible(),
			"day %d keeps the terminal warning hidden" % day,
		)
	var finale := _sleep_panel(GameRules.MAX_DAY)
	if finale == null:
		return
	await _settle()
	var alarm := finale.find_child("AlarmTime", true, false) as Label
	assert_not_null(alarm)
	if alarm != null:
		assert_eq(
			alarm.text,
			GameRules.format_time(GameRules.DAY_START_MINUTES),
			"day 14 keeps the 06:00 alarm target",
		)
	assert_true(
		finale.day14_warning_visible(),
		"day 14 keeps the terminal warning",
	)
	var wake := finale.find_child("WakeDay", true, false) as Label
	assert_not_null(wake)
	if wake == null:
		return
	assert_false(
		wake.is_visible_in_tree(),
		"day 14 promises no next morning: sleep goes straight to the finale",
	)

func test_containment_assertion_checks_real_rects_not_ancestry() -> void:
	var summary := _morning_panel()
	if summary == null:
		return
	await _settle()
	var healthy := _containment_report(summary)
	assert_gt(
		int(healthy["checked"]),
		0,
		"the check inspects visible controls, not just ancestry",
	)
	assert_eq(
		healthy["offenders"], [],
		"a healthy lock screen has no out-of-screen controls",
	)
	var screen_rect := _screen_rect(summary)
	var lock := summary.find_child("LockTime", true, false) as Control
	assert_not_null(lock)
	if lock == null:
		return
	lock.global_position = Vector2(
		screen_rect.end.x - 6.0, lock.global_position.y
	)
	var flagged := _containment_report(summary)
	var names := ""
	for offender in flagged["offenders"] as Array[String]:
		names += offender + ";"
	assert_true(
		names.contains("LockTime"),
		"a screen descendant protruding the edge must be flagged",
	)

func test_containment_assertion_exempts_only_clipped_scroll_content() -> void:
	var summary := _morning_panel()
	if summary == null:
		return
	summary.set_save_status(
		&"error",
		(
			"Save failed — this morning is not persisted. The storage card is "
			+ "full after the long festival season and the ledger could not be "
			+ "written; keep playing and try again."
		),
	)
	await _settle()
	var scroll := summary.find_child(
		"SaveStatusScroll", true, false
	) as ScrollContainer
	var status := summary.find_child("SaveStatus", true, false) as Label
	assert_not_null(scroll)
	assert_not_null(status)
	if scroll == null or status == null:
		return
	var screen_rect := _screen_rect(summary)
	assert_true(
		screen_rect.encloses(scroll.get_global_rect()),
		"the scroll viewport itself is inside the screen",
	)
	assert_true(
		status.get_global_rect().size.y > scroll.get_global_rect().size.y,
		"the long label is genuinely clipped by the scroll viewport",
	)
	var report := _containment_report(summary)
	var names := ""
	for offender in report["offenders"] as Array[String]:
		names += offender + ";"
	assert_false(
		names.contains("SaveStatus"),
		"content clipped inside a verified viewport is exempt",
	)
	assert_gt(int(report["checked"]), 0, "the check really ran")

func _window_point(logical: Vector2) -> Vector2:
	return get_window().get_final_transform() * logical

func _sleep_panel_at(window_size: Vector2i, day: int) -> SleepPanel:
	var sleep := _sleep_panel(day)
	if sleep == null:
		return null
	get_window().size = window_size
	return sleep

func test_sleep_confirm_pill_spans_the_phone_interior() -> void:
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		for window_size in [UiSettings.WINDOW_SIZE, UiSettings.MIN_WINDOW_SIZE]:
			for day in [4, GameRules.MAX_DAY]:
				var sleep := _sleep_panel_at(window_size, day)
				assert_not_null(
					sleep,
					"%s %s day %d sleep panel" % [locale, window_size, day],
				)
				if sleep == null:
					continue
				await _settle()
				var screen_rect := _screen_rect(sleep)
				var confirm := sleep.find_child(
					"Confirm", true, false
				) as Button
				var pill := _primary_pill(confirm)
				assert_not_null(
					pill,
					"%s %s day %d paints a confirm pill"
						% [locale, window_size, day],
				)
				if pill == null:
					continue
				var context := "%s %s day %d" % [locale, window_size, day]
				var pill_rect := pill.get_global_rect()
				var button_rect := confirm.get_global_rect()
				assert_almost_eq(
					pill_rect.position.x, button_rect.position.x, 0.5,
					"%s native click rect starts where the paint starts"
						% context,
				)
				assert_almost_eq(
					pill_rect.end.x, button_rect.end.x, 0.5,
					"%s native click rect ends where the paint ends" % context,
				)
				assert_almost_eq(
					pill_rect.size.x, button_rect.size.x, 0.5,
					"%s click rect is exactly as wide as the paint" % context,
				)
				var pill_ratio := pill_rect.size.x / screen_rect.size.x
				assert_almost_eq(
					pill_ratio, 0.9, 0.05,
					(
						"%s confirm pill spans ~90%% of the phone interior "
						+ "(ratio %.3f)"
					) % [context, pill_ratio],
				)
				var button_ratio := button_rect.size.x / screen_rect.size.x
				assert_almost_eq(
					button_ratio, 0.9, 0.05,
					(
						"%s confirm hitbox spans ~90%% of the phone interior "
						+ "(ratio %.3f)"
					) % [context, button_ratio],
				)
				assert_almost_eq(
					pill_rect.get_center().x, screen_rect.get_center().x, 0.5,
					"%s pill is centered on the screen" % context,
				)
				assert_true(
					screen_rect.encloses(pill_rect),
					"%s wide pill stays inside the phone screen" % context,
				)
				sleep.visible = false
		get_window().size = UiSettings.WINDOW_SIZE

func test_sleep_confirm_edges_take_native_presses_at_both_sizes() -> void:
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		for window_size in [UiSettings.WINDOW_SIZE, UiSettings.MIN_WINDOW_SIZE]:
			for day in [4, GameRules.MAX_DAY]:
				var sleep := _sleep_panel_at(window_size, day)
				assert_not_null(
					sleep,
					"%s %s day %d sleep panel" % [locale, window_size, day],
				)
				if sleep == null:
					continue
				await _settle()
				var confirm := sleep.find_child(
					"Confirm", true, false
				) as Button
				var pill := _primary_pill(confirm)
				if pill == null:
					continue
				var pill_rect := pill.get_global_rect()
				var mid := pill_rect.size.y * 0.5
				watch_signals(sleep)
				await _click_at(
					_window_point(pill_rect.position + Vector2(4, mid))
				)
				await _click_at(
					_window_point(pill_rect.end - Vector2(4, mid))
				)
				assert_signal_emit_count(
					sleep,
					&"sleep_requested",
					2,
					(
						"%s %s day %d presses at both painted edges of the "
						+ "wide pill"
					) % [locale, window_size, day],
				)
				sleep.visible = false
		get_window().size = UiSettings.WINDOW_SIZE

func test_sleep_confirm_release_outside_cancels_at_both_sizes() -> void:
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		for window_size in [UiSettings.WINDOW_SIZE, UiSettings.MIN_WINDOW_SIZE]:
			for day in [4, GameRules.MAX_DAY]:
				var sleep := _sleep_panel_at(window_size, day)
				assert_not_null(
					sleep,
					"%s %s day %d sleep panel" % [locale, window_size, day],
				)
				if sleep == null:
					continue
				await _settle()
				var confirm := sleep.find_child(
					"Confirm", true, false
				) as Button
				var pill := _primary_pill(confirm)
				if pill == null:
					continue
				var pill_rect := pill.get_global_rect()
				var mid := pill_rect.size.y * 0.5
				watch_signals(sleep)
				await _press_at_release_outside(
					_window_point(pill_rect.end - Vector2(4, mid))
				)
				assert_signal_not_emitted(
					sleep,
					&"sleep_requested",
					(
						"%s %s day %d release outside cancels the painted "
						+ "right edge press"
					) % [locale, window_size, day],
				)
				sleep.visible = false
		get_window().size = UiSettings.WINDOW_SIZE
