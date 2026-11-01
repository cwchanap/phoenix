extends GutTest

const TEST_PATH := "user://phoenix-ui-settings-test.cfg"

func _clean() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func before_each() -> void:
    _clean()

func after_each() -> void:
    _clean()

func test_defaults_are_safe_and_exact() -> void:
    var settings := UiSettings.load(TEST_PATH)

    assert_eq(settings.music, 4)
    assert_eq(settings.sound, 7)
    assert_false(settings.fullscreen)
    assert_true(settings.tutorial_cards)

func test_setters_persist_clamped_values_and_reload() -> void:
    var settings := UiSettings.load(TEST_PATH)

    assert_eq(settings.set_music(-3), OK)
    assert_eq(settings.set_sound(14), OK)
    assert_eq(settings.set_fullscreen(true), OK)
    assert_eq(settings.set_tutorial_cards(false), OK)

    var reloaded := UiSettings.load(TEST_PATH)
    assert_eq(reloaded.music, 0)
    assert_eq(reloaded.sound, 10)
    assert_true(reloaded.fullscreen)
    assert_false(reloaded.tutorial_cards)

func test_loaded_invalid_values_use_safe_defaults() -> void:
    var config := ConfigFile.new()
    config.set_value("ui", "music", -3)
    config.set_value("ui", "sound", 14)
    config.set_value("ui", "fullscreen", "yes")
    config.set_value("ui", "tutorial_cards", "yes")
    assert_eq(config.save(TEST_PATH), OK)

    var invalid := UiSettings.load(TEST_PATH)
    assert_eq(invalid.music, 0)
    assert_eq(invalid.sound, 10)
    assert_false(invalid.fullscreen)
    assert_true(invalid.tutorial_cards)

func test_volume_mapping_mutes_zero_and_is_monotonic() -> void:
    var settings := UiSettings.load(TEST_PATH)

    assert_eq(settings.db_for_level(0), -80.0)
    for level in range(1, 10):
        assert_lt(settings.db_for_level(level), settings.db_for_level(level + 1))

func test_windowed_mode_uses_the_1080p_base_viewport_size() -> void:
    var settings := UiSettings.load(TEST_PATH)
    var window := Window.new()

    settings.apply_window(window)

    assert_eq(window.mode, Window.MODE_WINDOWED)
    assert_eq(window.size, UiSettings.WINDOW_SIZE)
    assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), UiSettings.WINDOW_SIZE.x)
    assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), UiSettings.WINDOW_SIZE.y)
    window.free()

func test_fullscreen_mode_leaves_the_window_size_alone() -> void:
    var settings := UiSettings.load(TEST_PATH)
    var window := Window.new()

    assert_eq(settings.set_fullscreen(true), OK)
    settings.apply_window(window)

    assert_eq(window.mode, Window.MODE_FULLSCREEN)
    window.free()

func test_apply_window_leaves_a_placed_window_alone_on_unrelated_changes() -> void:
    var settings := UiSettings.load(TEST_PATH)
    var window := Window.new()
    settings.apply_window(window)
    var placed := Vector2i(1280, 720)
    window.size = placed

    assert_eq(settings.set_music(2), OK)
    settings.apply_window(window)
    assert_eq(window.size, placed, "a volume change keeps the player's window")

    assert_eq(settings.set_fullscreen(true), OK)
    settings.apply_window(window)
    assert_eq(window.mode, Window.MODE_FULLSCREEN)
    assert_eq(settings.set_fullscreen(false), OK)
    settings.apply_window(window)
    assert_eq(window.mode, Window.MODE_WINDOWED)
    assert_eq(window.size, UiSettings.WINDOW_SIZE, "leaving fullscreen refits the window")
    window.free()

func test_windowed_size_shrinks_to_fit_a_smaller_screen() -> void:
    assert_eq(UiSettings.windowed_size(Vector2i(2560, 1400)), UiSettings.WINDOW_SIZE)
    assert_eq(UiSettings.windowed_size(Vector2i(1920, 1080)), UiSettings.WINDOW_SIZE)
    assert_eq(UiSettings.windowed_size(Vector2i(1440, 860)), Vector2i(1296, 729))
    # A screen below the minimum window still gets a window that fits on it.
    assert_eq(UiSettings.windowed_size(Vector2i(800, 600)), Vector2i(720, 405))
    assert_eq(UiSettings.windowed_size(Vector2i.ZERO), UiSettings.WINDOW_SIZE)

func test_min_window_size_never_exceeds_the_fitted_window() -> void:
    assert_eq(UiSettings.min_window_size(Vector2i(2560, 1400)), UiSettings.MIN_WINDOW_SIZE)
    assert_eq(UiSettings.min_window_size(Vector2i(800, 600)), Vector2i(720, 405))
    assert_eq(UiSettings.min_window_size(Vector2i.ZERO), UiSettings.MIN_WINDOW_SIZE)
