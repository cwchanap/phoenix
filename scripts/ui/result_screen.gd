class_name ResultScreen
extends Control

signal new_game_requested
signal return_to_title_requested

const BACKGROUND := preload("res://assets/ui/backgrounds/result.png")
const WREATH_ICON := preload("res://assets/ui/icons/harvest-wreath.png")
const STAT_ICONS: Array[Texture2D] = [
    preload("res://assets/ui/crops/turnip.png"),
    preload("res://assets/ui/icons/coin-stack.png"),
    preload("res://assets/ui/icons/money-bag.png"),
]
const STAT_CAPTIONS: Array[String] = ["CROPS SHIPPED", "SHIPPED VALUE", "FINAL MONEY"]
const PORTRAIT_NAMES: Array[String] = ["sato", "gen", "hana"]
const HEART_FILLED_ICON := preload("res://assets/ui/icons/heart-filled.png")
const HEART_OUTLINE_ICON := preload("res://assets/ui/icons/heart-outline.png")

var _featured_villager := ""
var _title: Label
var _stats: Array[Label] = []
var _save_status: Label
var _card_names: Array[Label] = []
var _card_levels: Array[Label] = []
var _card_quotes: Array[Label] = []
var _card_panels: Array[PanelContainer] = []
var _hearts: Array = []

func _ready() -> void:
    _build()
    visible = false

func _unhandled_input(event: InputEvent) -> void:
    if not visible or not event.is_pressed() or event.is_echo():
        return
    if event.is_action_pressed(&"ui_accept"):
        new_game_requested.emit()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed(&"ui_cancel"):
        return_to_title_requested.emit()
        get_viewport().set_input_as_handled()

func present(result: Dictionary, save_error: int = OK) -> void:
    _featured_villager = String(result["villager"])
    _title.text = String(result["title"])
    _stats[0].text = "%d" % int(result["shipped_count"])
    _stats[1].text = "%dG" % int(result["shipped_value"])
    _stats[2].text = "%dG" % int(result["final_money"])
    var villagers: Dictionary = result["villagers"]
    for id in range(VillagerRules.VillagerId.size()):
        var villager: Dictionary = villagers[VillagerRules.villager_key(id)]
        var level_key := StringName(villager["level"])
        var level := VillagerRules.RELATIONSHIP_KEYS.find(level_key)
        _card_names[id].text = String(villager["name"])
        _card_levels[id].text = _level_display_name(level_key)
        _card_quotes[id].text = tr("“%s”") % tr(String(villager["line"]))
        var heart_count := _heart_count(level)
        for heart_index in 3:
            (_hearts[id][heart_index] as TextureRect).texture = (
                HEART_FILLED_ICON if heart_index < heart_count else HEART_OUTLINE_ICON
            )
        var featured := String(villager["name"]) == _featured_villager
        var box := UiStyle.card(UiStyle.HUD_CARD, 20, [0, 0, 0, 0])
        box.border_color = UiStyle.ACCENT if featured else UiStyle.LINE
        box.set_border_width_all(3 if featured else 1)
        _card_panels[id].add_theme_stylebox_override("panel", box)
        _card_names[id].add_theme_color_override(
            "font_color", UiStyle.ACCENT_DEEP if featured else UiStyle.INK
        )
    _save_status.text = "" if save_error == OK else "Final result was not saved."
    visible = true

func featured_villager_name() -> String:
    return _featured_villager

func result_state() -> Dictionary:
    var names := {}
    var levels := {}
    var quotes := {}
    var hearts := {}
    var featured := {}
    for id in range(VillagerRules.VillagerId.size()):
        var key := VillagerRules.villager_key(id)
        names[key] = _card_names[id].text
        levels[key] = _card_levels[id].text
        quotes[key] = _card_quotes[id].text
        var filled: Array = []
        for heart in _hearts[id]:
            filled.append((heart as TextureRect).texture == HEART_FILLED_ICON)
        hearts[key] = filled
        var box := _card_panels[id].get_theme_stylebox("panel") as StyleBoxFlat
        featured[key] = box != null and box.border_color == UiStyle.ACCENT
    var stat_values: Array[String] = []
    for label in _stats:
        stat_values.append(label.text)
    return {
        "title": _title.text,
        "save_status": _save_status.text,
        "stats": stat_values,
        "names": names,
        "levels": levels,
        "quotes": quotes,
        "hearts": hearts,
        "featured": featured,
    }

func _level_display_name(level_key: Variant) -> String:
    for level in range(VillagerRules.RelationshipLevel.size()):
        if VillagerRules.relationship_key(level) == level_key:
            return VillagerRules.relationship_display_name(level)
    return String(level_key)

func _heart_count(level: int) -> int:
    if level == VillagerRules.RelationshipLevel.CLOSE_FRIEND:
        return 3
    if level == VillagerRules.RelationshipLevel.FRIEND:
        return 2
    return 0

func _build() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    var background := TextureRect.new()
    background.name = "Background"
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.set_anchors_preset(Control.PRESET_FULL_RECT)
    background.texture = BACKGROUND
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    add_child(background)

    var dim := ColorRect.new()
    dim.name = "Dim"
    dim.color = Color(UiStyle.INK, 0.52)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(dim)

    var center := CenterContainer.new()
    center.name = "Center"
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var column := UiStyle.vbox(26)
    column.name = "Column"
    center.add_child(column)

    column.add_child(_header())
    column.add_child(_stats_row())
    column.add_child(_villager_cards())

    var actions := UiStyle.hbox(18)
    actions.name = "Actions"
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.anchor_left = 0.5
    actions.anchor_right = 0.5
    actions.anchor_top = 1.0
    actions.anchor_bottom = 1.0
    actions.offset_left = -330.0
    actions.offset_right = 330.0
    actions.offset_top = -92.0
    actions.offset_bottom = -24.0
    actions.grow_horizontal = Control.GROW_DIRECTION_BOTH
    actions.grow_vertical = Control.GROW_DIRECTION_BEGIN
    add_child(actions)
    var new_game := _action_button("NewGame", "NEW GAME", "Enter", true)
    new_game.pressed.connect(func() -> void: new_game_requested.emit())
    actions.add_child(new_game)
    var to_title := _action_button("ReturnToTitle", "TITLE", "Esc", false)
    to_title.pressed.connect(func() -> void: return_to_title_requested.emit())
    actions.add_child(to_title)

    _save_status = UiStyle.label("", 16, UiStyle.BAD, 700)
    _save_status.name = "SaveStatus"
    _save_status.anchor_left = 0.5
    _save_status.anchor_right = 0.5
    _save_status.anchor_top = 1.0
    _save_status.anchor_bottom = 1.0
    _save_status.offset_top = -124.0
    _save_status.offset_bottom = -98.0
    _save_status.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _save_status.grow_vertical = Control.GROW_DIRECTION_BEGIN
    _save_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(_save_status)

func _header() -> VBoxContainer:
    var header := UiStyle.vbox(10)
    header.name = "Header"
    var wreath := UiStyle.icon(WREATH_ICON, 72)
    wreath.name = "Wreath"
    wreath.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    header.add_child(wreath)
    var kicker := SlantTag.new("SEASON COMPLETE", UiStyle.FIELDWORK_GRADIENT, UiStyle.CARD, 17)
    kicker.name = "Kicker"
    kicker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    header.add_child(kicker)
    _title = UiStyle.label("", 52, UiStyle.CARD, 900)
    _title.name = "Title"
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_child(_title)
    return header

func _stats_row() -> HBoxContainer:
    var row := UiStyle.hbox(18)
    row.name = "Stats"
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    for index in STAT_CAPTIONS.size():
        var card := PanelContainer.new()
        card.name = "Card_%d" % index
        card.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.custom_minimum_size = Vector2(330, 0)
        var accent := index == 1
        var box := UiStyle.card(
            UiStyle.ACCENT_SOFT if accent else UiStyle.HUD_CARD, 18, [20, 12, 20, 14]
        )
        box.border_color = UiStyle.ACCENT if accent else UiStyle.LINE
        box.set_border_width_all(2 if accent else 1)
        card.add_theme_stylebox_override("panel", box)
        var inner := UiStyle.hbox(14)
        card.add_child(inner)
        var icon := UiStyle.icon(STAT_ICONS[index], 52)
        icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        inner.add_child(icon)
        var pair := UiStyle.vbox(2)
        pair.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        inner.add_child(pair)
        var value := UiStyle.label("", 32, UiStyle.ACCENT_DEEP if accent else UiStyle.INK, 900)
        value.name = "Value"
        _stats.append(value)
        pair.add_child(value)
        var caption := UiStyle.label(STAT_CAPTIONS[index], 13, UiStyle.INK_MUTED, 800)
        caption.name = "Caption"
        pair.add_child(caption)
        row.add_child(card)
    return row

func _villager_cards() -> HBoxContainer:
    var row := UiStyle.hbox(20)
    row.name = "Cards"
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    for id in range(VillagerRules.VillagerId.size()):
        row.add_child(_villager_card(id))
    return row

func _villager_card(id: int) -> PanelContainer:
    var card := PanelContainer.new()
    card.name = "Card_%s" % String(VillagerRules.villager_key(id)).capitalize()
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var box := UiStyle.card(UiStyle.HUD_CARD, 20, [0, 0, 0, 0])
    box.border_color = UiStyle.LINE
    box.set_border_width_all(1)
    card.add_theme_stylebox_override("panel", box)
    _card_panels.append(card)

    var column := UiStyle.vbox(0)
    card.add_child(column)
    var clip := Control.new()
    clip.name = "PortraitClip"
    clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    clip.clip_contents = true
    clip.custom_minimum_size = Vector2(470, 220)
    column.add_child(clip)
    var portrait := TextureRect.new()
    portrait.name = "Portrait"
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    portrait.position = Vector2.ZERO
    portrait.size = Vector2(470, 658)
    portrait.texture = load("res://assets/ui/portraits/%s.png" % PORTRAIT_NAMES[id]) as Texture2D
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_SCALE
    clip.add_child(portrait)

    var body := MarginContainer.new()
    body.name = "Body"
    body.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for side in [["left", 20], ["top", 12], ["right", 20], ["bottom", 16]]:
        body.add_theme_constant_override("margin_" + side[0], side[1])
    column.add_child(body)
    var stack := UiStyle.vbox(6)
    body.add_child(stack)
    var name_row := UiStyle.hbox(10)
    name_row.name = "NameRow"
    stack.add_child(name_row)
    var card_name := UiStyle.label("", 24, UiStyle.INK, 900)
    card_name.name = "Name"
    card_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _card_names.append(card_name)
    name_row.add_child(card_name)
    var hearts := UiStyle.hbox(4)
    hearts.name = "Hearts"
    hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    name_row.add_child(hearts)
    var card_hearts: Array = []
    for heart_index in 3:
        var heart := UiStyle.icon(HEART_OUTLINE_ICON, 24)
        heart.name = "Heart_%d" % heart_index
        hearts.add_child(heart)
        card_hearts.append(heart)
    _hearts.append(card_hearts)
    var level := UiStyle.label("", 14, UiStyle.INK_MUTED, 800)
    level.name = "Level"
    _card_levels.append(level)
    stack.add_child(level)
    var quote := UiStyle.label("", 16, UiStyle.INK, 500)
    quote.name = "Quote"
    quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    quote.custom_minimum_size = Vector2(0, 76)
    _card_quotes.append(quote)
    stack.add_child(quote)
    return card

func _action_button(button_name: String, text_value: String, key: String, accent: bool) -> Button:
    var button := Button.new()
    button.name = button_name
    button.custom_minimum_size = Vector2(300 if accent else 220, 64)
    button.focus_mode = Control.FOCUS_NONE
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    if accent:
        var normal := UiStyle.card(UiStyle.ACCENT, 18)
        normal.border_color = UiStyle.ACCENT_DEEP
        normal.border_width_bottom = 4
        var hover := UiStyle.card(UiStyle.ACCENT.lightened(0.08), 18)
        hover.border_color = UiStyle.ACCENT_DEEP
        hover.border_width_bottom = 4
        button.add_theme_stylebox_override("normal", normal)
        button.add_theme_stylebox_override("hover", hover)
        button.add_theme_stylebox_override("pressed", UiStyle.card(UiStyle.ACCENT_DEEP, 18))
        button.add_theme_stylebox_override("focus", normal)
    else:
        var normal := UiStyle.card(UiStyle.HUD_CARD, 18)
        normal.border_color = UiStyle.LINE
        normal.set_border_width_all(2)
        button.add_theme_stylebox_override("normal", normal)
        button.add_theme_stylebox_override("hover", UiStyle.card(UiStyle.CARD, 18))
        button.add_theme_stylebox_override("pressed", UiStyle.card(UiStyle.LINE, 18))
        button.add_theme_stylebox_override("focus", normal)
    var keycap := UiStyle.keycap(key, true)
    keycap.name = "Keycap"
    button.add_child(keycap)
    keycap.reset_size()
    keycap.position = Vector2(14, (64 - keycap.size.y) / 2.0)
    var label := UiStyle.label(text_value, 20, UiStyle.CARD if accent else UiStyle.INK, 900)
    label.name = "Label"
    label.position = Vector2(14 + keycap.size.x + 12, 0)
    label.size = Vector2(button.custom_minimum_size.x - keycap.size.x - 40, 64)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    button.add_child(label)
    return button
