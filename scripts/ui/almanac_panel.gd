class_name AlmanacPanel
extends Control

signal close_requested

const ART_TEXTURES: Array[String] = [
    "res://assets/ui/crops/turnip-art.png",
    "res://assets/ui/crops/potato-art.png",
    "res://assets/ui/crops/pumpkin-art.png",
]
const GROWTH_COLORS: Array[Color] = [UiStyle.GOLD, Color("6b8bc4"), UiStyle.RED]

var _snapshot: Dictionary = {}
var _selected_kind := GameRules.CropKind.TURNIP
var _cards: Array[Panel] = []

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    for kind in range(GameRules.CropKind.size()):
        _cards.append(get_node("Frame/Body/Card_%d" % kind) as Panel)
    _style_tree(self)
    _update_cards()

func open_panel(snapshot: Dictionary) -> void:
    _selected_kind = GameRules.CropKind.TURNIP
    present(snapshot)
    visible = true

func present(snapshot: Dictionary) -> void:
    _snapshot = snapshot.duplicate(true)
    _update_cards()

func selected_kind() -> int:
    return _selected_kind

func _input(event: InputEvent) -> void:
    if not visible or not event.is_pressed() or event.is_echo():
        return
    if event.is_action_pressed("move_left"):
        _selected_kind = posmod(_selected_kind - 1, GameRules.CropKind.size())
    elif event.is_action_pressed("move_right"):
        _selected_kind = posmod(_selected_kind + 1, GameRules.CropKind.size())
    else:
        return
    _update_cards()
    get_viewport().set_input_as_handled()

func _update_cards() -> void:
    if not has_node("Frame"):
        return
    for kind in range(GameRules.CropKind.size()):
        var card := _cards[kind]
        var selected := kind == _selected_kind
        card.add_theme_stylebox_override(
            "panel",
            UiStyle.panel(UiStyle.INSET, UiStyle.GOLD if selected else UiStyle.BORDER, 2 if selected else 1),
        )
        var art := card.get_node("Art") as TextureRect
        art.texture = load(ART_TEXTURES[kind]) as Texture2D
        var favourite := VillagerRules.favourite_villager_for_crop(kind)
        (card.get_node("Name") as Label).text = GameRules.crop_display_name(kind)
        var favourite_badge := card.get_node("FavouriteBadge") as Panel
        favourite_badge.add_theme_stylebox_override(
            "panel", UiStyle.panel(UiStyle.INSET, UiStyle.GOLD if selected else UiStyle.BORDER, 1)
        )
        var favourite_badge_label := favourite_badge.get_node("Value") as Label
        favourite_badge_label.text = "♥ %s" % VillagerRules.display_name(favourite).to_upper()
        UiStyle.text(favourite_badge_label, 7, UiStyle.GOLD if selected else UiStyle.MUTED, 800, true)
        var growth := GameRules.growth_nights(kind)
        (card.get_node("GrowthValue") as Label).text = "%d watered nights" % growth
        for pip_index in 7:
            var pip := card.get_node("Growth/Pip_%d" % pip_index) as ColorRect
            pip.color = GROWTH_COLORS[kind] if pip_index < growth else UiStyle.BORDER
        (card.get_node("SeedValue") as Label).text = "%dG" % GameRules.seed_price(kind)
        (card.get_node("SellValue") as Label).text = "%dG" % GameRules.sale_value(kind)
        (card.get_node("MarginValue") as Label).text = "+%d" % (
            GameRules.sale_value(kind) - GameRules.seed_price(kind)
        )
        UiStyle.text(card.get_node("Name") as Label, 14, UiStyle.GOLD if selected else UiStyle.CREAM, 800)
        UiStyle.text(card.get_node("GrowthCaption") as Label, 8, UiStyle.MUTED, 700, true)
        UiStyle.text(card.get_node("GrowthValue") as Label, 9, UiStyle.TEXT, 700)
        UiStyle.text(card.get_node("SeedCaption") as Label, 8, UiStyle.MUTED, 700, true)
        UiStyle.text(card.get_node("SeedValue") as Label, 11, UiStyle.TEXT, 800, true)
        UiStyle.text(card.get_node("SellCaption") as Label, 8, UiStyle.MUTED, 700, true)
        UiStyle.text(card.get_node("SellValue") as Label, 11, UiStyle.GREEN, 800, true)
        UiStyle.text(card.get_node("MarginCaption") as Label, 8, UiStyle.MUTED, 700, true)
        UiStyle.text(card.get_node("MarginValue") as Label, 11, UiStyle.GREEN, 800, true)

func _style_tree(node: Node) -> void:
    for child in node.get_children():
        if child is Label:
            UiStyle.text(child as Label)
        elif child is Button:
            UiStyle.button(child as Button)
        _style_tree(child)
    (get_node("Frame") as Panel).add_theme_stylebox_override(
        "panel", UiStyle.panel(UiStyle.PRIMARY, UiStyle.FRAME_BORDER, 2)
    )
    var header_style := UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER, 0)
    header_style.border_width_bottom = 2
    (get_node("Frame/Header") as Panel).add_theme_stylebox_override("panel", header_style)
    var footer_style := UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER, 0)
    footer_style.border_width_top = 2
    (get_node("Frame/Footer") as Panel).add_theme_stylebox_override("panel", footer_style)
    UiStyle.text(get_node("Frame/Header/Title") as Label, 13, UiStyle.CREAM, 800)
    UiStyle.text(get_node("Frame/Header/Subtitle") as Label, 9, UiStyle.MUTED, 700)
    UiStyle.text(get_node("Frame/Footer/Help") as Label, 9, UiStyle.MUTED, 600)
    UiStyle.button(get_node("Frame/Footer/Close") as Button, 9)
    for card in _cards:
        for cell_name in [&"SeedCell", &"SellCell", &"MarginCell"]:
            (card.get_node(String(cell_name)) as Panel).add_theme_stylebox_override(
                "panel", UiStyle.panel(UiStyle.INSET, UiStyle.BORDER, 1)
            )
