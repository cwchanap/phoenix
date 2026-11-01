class_name UiSettings
extends RefCounted

const DEFAULT_PATH := "user://phoenix-settings.cfg"
const DEFAULT_MUSIC := 4
const DEFAULT_SOUND := 7
const DEFAULT_WINDOW_SCALE := 2
const DEFAULT_TUTORIAL_CARDS := true
const FULLSCREEN := 0
const VALID_WINDOW_SCALES := [1, 2, 3, 4, FULLSCREEN]
# Locale codes registered with TranslationServer. English is the source text
# (CSV keys), so it needs no translation file.
const LANGUAGES: Array[String] = ["en", "zh_TW", "ja"]

const _SECTION := "ui"

var music: int = DEFAULT_MUSIC
var sound: int = DEFAULT_SOUND
var window_scale: int = DEFAULT_WINDOW_SCALE
var tutorial_cards: bool = DEFAULT_TUTORIAL_CARDS
var language: String = default_language(OS.get_locale())
var _path: String

func _init(path: String = DEFAULT_PATH) -> void:
    _path = path

static func load(path: String = DEFAULT_PATH) -> UiSettings:
    var settings := UiSettings.new(path)
    var config := ConfigFile.new()
    if config.load(path) != OK:
        return settings

    settings.music = _read_level(config.get_value(_SECTION, "music", DEFAULT_MUSIC), DEFAULT_MUSIC)
    settings.sound = _read_level(config.get_value(_SECTION, "sound", DEFAULT_SOUND), DEFAULT_SOUND)
    settings.window_scale = _read_window_scale(
        config.get_value(_SECTION, "window_scale", DEFAULT_WINDOW_SCALE)
    )
    var tutorial_value: Variant = config.get_value(
        _SECTION,
        "tutorial_cards",
        DEFAULT_TUTORIAL_CARDS,
    )
    if tutorial_value is bool:
        settings.tutorial_cards = tutorial_value
    var language_value: Variant = config.get_value(_SECTION, "language", settings.language)
    if language_value is String and LANGUAGES.has(language_value):
        settings.language = language_value
    return settings

## Maps an OS locale such as `ja_JP`, `zh_Hant_HK` or `zh_TW` to a supported
## language; Simplified Chinese and everything else fall back to English.
static func default_language(os_locale: String) -> String:
    var parts := os_locale.replace("-", "_").split("_")
    match parts[0].to_lower():
        "ja":
            return "ja"
        "zh":
            for part in parts.slice(1):
                if ["hant", "tw", "hk", "mo"].has(part.to_lower()):
                    return "zh_TW"
    return "en"

func set_music(level: int) -> Error:
    music = clampi(level, 0, 10)
    return _save()

func set_sound(level: int) -> Error:
    sound = clampi(level, 0, 10)
    return _save()

func set_window_scale(scale: int) -> Error:
    if not VALID_WINDOW_SCALES.has(scale):
        return ERR_INVALID_PARAMETER
    window_scale = scale
    return _save()

func set_tutorial_cards(enabled: bool) -> Error:
    tutorial_cards = enabled
    return _save()

func set_language(value: String) -> Error:
    if not LANGUAGES.has(value):
        return ERR_INVALID_PARAMETER
    language = value
    return _save()

func apply_language() -> void:
    TranslationServer.set_locale(language)

func db_for_level(level: int) -> float:
    var clamped := clampi(level, 0, 10)
    if clamped == 0:
        return -80.0
    return -40.0 + float(clamped) * 4.0

func apply_window(window: Window) -> void:
    if window == null:
        return
    if window_scale == FULLSCREEN:
        window.mode = Window.MODE_FULLSCREEN
        return
    window.mode = Window.MODE_WINDOWED
    window.size = Vector2i(640 * window_scale, 360 * window_scale)

static func _read_level(value: Variant, fallback: int) -> int:
    if value is int:
        return clampi(value, 0, 10)
    if value is float and is_finite(value):
        return clampi(int(value), 0, 10)
    return fallback

static func _read_window_scale(value: Variant) -> int:
    if value is int and VALID_WINDOW_SCALES.has(value):
        return value
    if value is float and is_finite(value) and value == floor(value) and VALID_WINDOW_SCALES.has(int(value)):
        return int(value)
    return DEFAULT_WINDOW_SCALE

func _save() -> Error:
    var config := ConfigFile.new()
    config.set_value(_SECTION, "music", music)
    config.set_value(_SECTION, "sound", sound)
    config.set_value(_SECTION, "window_scale", window_scale)
    config.set_value(_SECTION, "tutorial_cards", tutorial_cards)
    config.set_value(_SECTION, "language", language)
    return config.save(_path)
