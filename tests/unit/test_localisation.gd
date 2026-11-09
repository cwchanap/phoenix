extends GutTest

const CSV_PATH := "res://assets/i18n/strings.csv"
const SETTINGS_PATH := "user://phoenix-localisation-test.cfg"
const TRANSLATED_LOCALES: Array[String] = ["zh_TW", "ja"]

func after_each() -> void:
    TranslationServer.set_locale("en")
    if FileAccess.file_exists(SETTINGS_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))

func _rows() -> Array[PackedStringArray]:
    var file := FileAccess.open(CSV_PATH, FileAccess.READ)
    assert_not_null(file, "strings.csv must exist")
    var rows: Array[PackedStringArray] = []
    while not file.eof_reached():
        var row := file.get_csv_line()
        if row.size() == 1 and row[0] == "":
            continue
        rows.append(row)
    return rows

func _placeholders(text: String) -> Array[String]:
    var regex := RegEx.create_from_string("%[sd]")
    var result: Array[String] = []
    for found in regex.search_all(text):
        result.append(found.get_string())
    return result

func test_every_key_has_both_translations_with_matching_placeholders() -> void:
    var rows := _rows()
    assert_eq(Array(rows[0]), ["keys", "zh_TW", "ja"])
    var keys := {}
    for index in range(1, rows.size()):
        var row := rows[index]
        assert_eq(row.size(), 3, "row %d must have key, zh_TW, ja" % index)
        var key := row[0]
        assert_false(keys.has(key), "duplicate key: %s" % key)
        keys[key] = true
        for column in [1, 2]:
            assert_ne(row[column].strip_edges(), "", "%s is missing a translation" % key)
            assert_eq(
                _placeholders(row[column]),
                _placeholders(key),
                "%s placeholders must match in column %d" % [key, column],
            )

func _rules_strings() -> Array[String]:
    var result: Array[String] = []
    for name in GameRules.CROP_DISPLAY_NAMES:
        result.append(name)
    for list in [
        VillagerRules.DISPLAY_NAMES,
        VillagerRules.ROLE_LABELS,
        VillagerRules.RELATIONSHIP_DISPLAY_NAMES,
        VillagerRules.RAINY_DIALOGUE,
        VillagerRules.SHIPPED_DIALOGUE,
        VillagerRules.MARKET_DIALOGUE,
        VillagerRules.NORMAL_GIFT_LINES,
        VillagerRules.FAVOURITE_GIFT_LINES,
    ]:
        for line in list:
            result.append(String(line))
    for per_villager in VillagerRules.NORMAL_DIALOGUE:
        for per_level in per_villager:
            for line in per_level:
                result.append(String(line))
    for nested in [VillagerRules.CLOSE_FRIEND_DIALOGUE, VillagerRules.FINALE_LINES]:
        for per_villager in nested:
            for line in per_villager:
                result.append(String(line))
    for tutorial in ContentRules.TUTORIALS:
        result.append(String(tutorial["title"]))
        result.append(String(tutorial["body"]))
    for tier_title in ["New Beginning", "Promising Farmer", "Heart of the Harvest"]:
        result.append(tier_title)
    return result

func test_every_rules_string_is_translated() -> void:
    for locale in TRANSLATED_LOCALES:
        TranslationServer.set_locale(locale)
        for text in _rules_strings():
            assert_ne(tr(text), text, "%s has no %s translation" % [text, locale])

func test_translations_load_for_each_locale() -> void:
    TranslationServer.set_locale("zh_TW")
    assert_eq(tr("Turnip"), "蕪菁")
    TranslationServer.set_locale("ja")
    assert_eq(tr("Turnip"), "カブ")
    TranslationServer.set_locale("en")
    assert_eq(tr("Turnip"), "Turnip")

func test_truck_prompt_strings_translate_in_both_locales() -> void:
    for locale in TRANSLATED_LOCALES:
        TranslationServer.set_locale(locale)
        for text in ["Drive to town", "Drive home", "Seed Shop", "Talk, shop, bin, bed, truck"]:
            assert_ne(tr(text), text, "%s has no %s translation" % [text, locale])
    TranslationServer.set_locale("zh_TW")
    assert_eq(tr("Drive to town"), "開車去鎮上")
    assert_eq(tr("Drive home"), "開車回家")
    assert_eq(tr("Seed Shop"), "種子行")
    assert_eq(tr("Talk, shop, bin, bed, truck"), "對話、商店、出貨箱、床、貨車")
    TranslationServer.set_locale("ja")
    assert_eq(tr("Drive to town"), "町までドライブ")
    assert_eq(tr("Drive home"), "家までドライブ")
    assert_eq(tr("Seed Shop"), "種屋")
    assert_eq(tr("Talk, shop, bin, bed, truck"), "話す・店・出荷箱・ベッド・トラック")

func test_default_language_follows_os_locale() -> void:
    assert_eq(UiSettings.default_language("ja_JP"), "ja")
    assert_eq(UiSettings.default_language("zh_TW"), "zh_TW")
    assert_eq(UiSettings.default_language("zh_HK"), "zh_TW")
    assert_eq(UiSettings.default_language("zh_Hant_MO"), "zh_TW")
    assert_eq(UiSettings.default_language("zh_CN"), "en")
    assert_eq(UiSettings.default_language("zh_Hans_HK"), "en")
    assert_eq(UiSettings.default_language("zh_Hans_TW"), "en")
    assert_eq(UiSettings.default_language("en_US"), "en")
    assert_eq(UiSettings.default_language("fr"), "en")

func test_language_persists_and_rejects_unknown_values() -> void:
    var settings := UiSettings.load(SETTINGS_PATH)
    assert_eq(settings.set_language("ja"), OK)
    assert_eq(settings.set_language("de"), ERR_INVALID_PARAMETER)
    assert_eq(UiSettings.load(SETTINGS_PATH).language, "ja")
    settings.apply_language()
    assert_eq(TranslationServer.get_locale(), "ja")
