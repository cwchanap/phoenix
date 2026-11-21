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
    for line in ContentRules.DIARY_LINES:
        result.append(String(line))
    for tier in ContentRules.RESULT_TIERS:
        result.append(String(ContentRules.RESULT_TIERS[tier]["title"]))
        result.append(String(ContentRules.RESULT_TIERS[tier]["epilogue"]))
    for scene in ContentRules.PROLOGUE_SCENES:
        result.append(String(scene["tag"]))
        for line in scene["lines"]:
            result.append(String(line["text"]))
    result.append(ContentRules.INNER_VOICE_LABEL)
    for opening_text in [
        ContentRules.OPENING_SPEAKER,
        ContentRules.OPENING_ROLE,
    ]:
        result.append(opening_text)
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
        for text in ["Drive to town", "Drive home", "Seed Shop", "Go to bed", "Talk, shop, bin, bed, truck"]:
            assert_ne(tr(text), text, "%s has no %s translation" % [text, locale])
    TranslationServer.set_locale("zh_TW")
    assert_eq(tr("Drive to town"), "開車去鎮上")
    assert_eq(tr("Drive home"), "開車回家")
    assert_eq(tr("Seed Shop"), "種子行")
    assert_eq(tr("Go to bed"), "去睡覺")
    assert_eq(tr("Talk, shop, bin, bed, truck"), "對話、商店、出貨箱、床、貨車")
    TranslationServer.set_locale("ja")
    assert_eq(tr("Drive to town"), "町までドライブ")
    assert_eq(tr("Drive home"), "家までドライブ")
    assert_eq(tr("Seed Shop"), "種屋")
    assert_eq(tr("Go to bed"), "寝る")
    assert_eq(tr("Talk, shop, bin, bed, truck"), "話す・店・出荷箱・ベッド・トラック")

func test_market_confirmation_card_strings_translate_for_each_locale() -> void:
    var panel := MarketConfirmPanel.new()
    add_child_autoqfree(panel)
    var card_strings := {
        "Center/Card/Column/HeaderBand/Row/Titles/Title": "End the season?",
        "Center/Card/Column/Body/Content/Finality": "The market settles your shipments and friendships and shows your result. You can't keep playing after this.",
        "Center/Card/Column/Body/Content/Warning/Row/Text": "Crops in your bag are not sold. Ship them first.",
        "Center/Card/Column/Body/Content/Actions/Confirm/Pill/Row/Text": "Open the market",
        "Center/Card/Column/Body/Content/Actions/Cancel/Pill/Row/Text": "Not yet",
    }
    var expected_headers := {
        "en": "HARVEST MARKET · DAY 14",
        "zh_TW": "豐收市集 · 第 14 天",
        "ja": "収穫市 · 14日目",
    }
    var expected_translations := {
        "zh_TW": [
            "要結束這一季嗎？",
            "市集會結算你的出貨與友誼並顯示成果。之後你就不能再繼續遊玩。",
            "背包裡的作物不會出售。請先出貨。",
            "開啟市集",
            "還不要",
        ],
        "ja": [
            "シーズンを終えますか？",
            "収穫市は出荷と友好関係を精算して結果を表示します。これ以降はプレイを続けられません。",
            "かばんの中の作物は売れません。先に出荷してください。",
            "マーケットを開く",
            "まだ",
        ],
    }
    var day_label := panel.get_node(
        "Center/Card/Column/HeaderBand/Row/Titles/Day"
    ) as Label
    for locale in ["en"] + TRANSLATED_LOCALES:
        TranslationServer.set_locale(locale)
        panel.present({"day": GameRules.MAX_DAY})
        assert_eq(day_label.text, expected_headers[locale], "%s header" % locale)
    for label_path in card_strings:
        var source: String = card_strings[label_path]
        var label := panel.get_node(label_path) as Label
        assert_eq(label.text, source)
        var index: int = card_strings.keys().find(label_path)
        for locale in TRANSLATED_LOCALES:
            TranslationServer.set_locale(locale)
            assert_eq(
                tr(source),
                expected_translations[locale][index],
                "%s: %s" % [locale, source],
            )

func test_travel_overlay_card_strings_translate_for_each_locale() -> void:
    var overlay := TravelOverlay.new()
    add_child_autoqfree(overlay)
    overlay.play(
        GameRules.MapId.TOWN,
        12 * 60 + 5,
        12 * 60 + 35,
        func() -> void: pass,
    )
    var card_strings := {
        "Center/Column/Title": "Driving to town",
        "Center/Column/TimePill/Row/Departure": "12:05",
        "Center/Column/TimePill/Row/Arrival": "12:35",
        "Center/Column/Duration": "+30 min",
    }
    for label_path in card_strings:
        var label := overlay.get_node(label_path) as Label
        assert_eq(label.text, card_strings[label_path])
    var expected_translations := {
        "Driving to town": {"zh_TW": "開車進鎮中", "ja": "町までドライブ中"},
        "Driving home": {"zh_TW": "開車回家中", "ja": "家までドライブ中"},
        "+%d min": {"zh_TW": "+%d 分鐘", "ja": "+%d分"},
    }
    for source in expected_translations:
        for locale in TRANSLATED_LOCALES:
            TranslationServer.set_locale(locale)
            assert_eq(
                tr(source),
                expected_translations[source][locale],
                "%s: %s" % [locale, source],
            )
    TranslationServer.set_locale("en")
    overlay.play(
        GameRules.MapId.FARM,
        100,
        130,
        func() -> void: pass,
    )
    assert_eq(
        (overlay.get_node("Center/Column/Title") as Label).text,
        "Driving home",
    )

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
