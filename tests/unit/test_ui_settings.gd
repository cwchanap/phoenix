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
    assert_eq(settings.window_scale, 2)
    assert_true(settings.tutorial_cards)

func test_setters_persist_clamped_values_and_reload() -> void:
    var settings := UiSettings.load(TEST_PATH)

    assert_eq(settings.set_music(-3), OK)
    assert_eq(settings.set_sound(14), OK)
    assert_eq(settings.set_window_scale(4), OK)
    assert_eq(settings.set_tutorial_cards(false), OK)

    var reloaded := UiSettings.load(TEST_PATH)
    assert_eq(reloaded.music, 0)
    assert_eq(reloaded.sound, 10)
    assert_eq(reloaded.window_scale, 4)
    assert_false(reloaded.tutorial_cards)

func test_invalid_window_scale_is_rejected_without_mutation() -> void:
    var settings := UiSettings.load(TEST_PATH)

    assert_eq(settings.window_scale, 2)
    assert_eq(settings.set_window_scale(5), ERR_INVALID_PARAMETER)
    assert_eq(settings.window_scale, 2)
    assert_false(FileAccess.file_exists(TEST_PATH))

func test_loaded_invalid_values_use_safe_defaults() -> void:
    var config := ConfigFile.new()
    config.set_value("ui", "music", -3)
    config.set_value("ui", "sound", 14)
    config.set_value("ui", "window_scale", 5)
    config.set_value("ui", "tutorial_cards", "yes")
    assert_eq(config.save(TEST_PATH), OK)

    var invalid := UiSettings.load(TEST_PATH)
    assert_eq(invalid.music, 0)
    assert_eq(invalid.sound, 10)
    assert_eq(invalid.window_scale, 2)
    assert_true(invalid.tutorial_cards)

func test_volume_mapping_mutes_zero_and_is_monotonic() -> void:
    var settings := UiSettings.load(TEST_PATH)

    assert_eq(settings.db_for_level(0), -80.0)
    for level in range(1, 10):
        assert_lt(settings.db_for_level(level), settings.db_for_level(level + 1))

func test_window_scale_changes_os_size_without_changing_logical_viewport() -> void:
    var settings := UiSettings.load(TEST_PATH)
    var window := Window.new()

    settings.set_window_scale(3)
    settings.apply_window(window)

    assert_eq(window.mode, Window.MODE_WINDOWED)
    assert_eq(window.size, Vector2i(1920, 1080))
    assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 640)
    assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 360)
    window.free()
