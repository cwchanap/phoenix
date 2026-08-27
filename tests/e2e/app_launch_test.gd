# godot-e2e smoke: launch the app, start a new game from the title screen,
# and confirm the live World appears.
extends GdUnitE2ETestSuite

func test_new_game_reaches_world() -> void:
	var options := E2ELaunchOptions.new()
	options.scene_path = "res://scenes/app/app.tscn"
	var game := await launch_game(options)
	if game == null or is_failure():
		return

	assert_bool(await game.wait_for_node("/root/AppRoot/TitleScreen", 10.0)).is_true()
	if is_failure():
		return

	assert_bool(await game.click_node("/root/AppRoot/TitleScreen/Panel/NewGame")).is_true()
	if is_failure():
		return

	assert_bool(await game.wait_for_node("/root/AppRoot/World", 10.0)).is_true()
