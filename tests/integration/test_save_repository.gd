extends GutTest

const TEST_PATH := "user://phoenix-hpa-598-repository-test.json"

func _clean() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func before_each() -> void:
    _clean()

func after_each() -> void:
    _clean()

func test_missing_then_save_replace_load_and_restore() -> void:
    var repository := SaveRepository.new(TEST_PATH)
    assert_eq(repository.load()["status"], &"missing")

    var first := GameSession.new(func() -> float: return 0.9).state()
    assert_eq(repository.save(first), OK)
    var first_loaded := repository.load()
    assert_eq(first_loaded["status"], &"loaded")
    assert_eq(GameSession.state_error(first_loaded["state"]), "")

    var second_session := GameSession.new(func() -> float: return 0.9)
    assert_eq(second_session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    var second := second_session.state()
    assert_eq(repository.save(second), OK)
    var second_loaded := repository.load()
    var restored := GameSession.new(func() -> float: return 0.9)
    assert_true(restored.restore_state(second_loaded["state"]))
    assert_eq(restored.state(), second)

func test_malformed_file_is_invalid_not_a_crash() -> void:
    var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    assert_not_null(file)
    file.store_string("{broken")
    file.close()
    var result := SaveRepository.new(TEST_PATH).load()
    assert_eq(result["status"], &"invalid")
    assert_ne(String(result["error"]), "")

func test_nonexistent_parent_directory_returns_write_error() -> void:
    var repository := SaveRepository.new("user://missing-hpa-598-dir/save.json")
    assert_ne(repository.save(GameSession.new().state()), OK)
