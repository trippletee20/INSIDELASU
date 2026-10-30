extends RefCounted
## One mutable Theme resource, shared by every game UI root and world label.
const RESOURCE: Theme = preload("res://ui/campus_theme.tres")
const SPACE: int = 8
const RADIUS: int = 18
static var dark: bool = false
static var colors: Dictionary = {}

static func surface(color: Color, radius: int = RADIUS, padding: int = 12) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(radius)
    style.set_content_margin_all(padding)
    return style

static func make(font: Font, use_dark: bool = false) -> Theme:
    dark = use_dark
    colors = {"surface": Color("192b2a" if dark else "f9fbf5"),
        "field": Color("243b38" if dark else "eaf1eb"),
        "hover": Color("30564b" if dark else "dceee2"),
        "text": Color("edf7ef" if dark else "17332e"),
        "muted": Color("b1c8bd" if dark else "50695c"),
        "accent": Color("80dfb2" if dark else "176b4b"),
        "border": Color("5e8070" if dark else "729484"),
        "danger": Color("ffaaaa" if dark else "a62626")}
    var theme := RESOURCE
    theme.set_block_signals(true)
    theme.default_font = font
    theme.default_font_size = 14
    for type in ["Label", "RichTextLabel", "Button", "OptionButton", "CheckButton", "LineEdit", "TextEdit", "PopupMenu"]:
        for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_selected_color", "default_color"]:
            theme.set_color(key, type, colors.text)
        theme.set_color("font_disabled_color", type, colors.muted)
        theme.set_color("font_placeholder_color", type, colors.muted)
        theme.set_color("caret_color", type, colors.text)
        theme.set_color("selection_color", type, colors.hover)
    var panel := surface(colors.surface, RADIUS, 16)
    panel.border_color = colors.border
    panel.set_border_width_all(1)
    theme.set_stylebox("panel", "PanelContainer", panel)
    theme.set_stylebox("panel", "PopupMenu", panel)
    for type in ["OwnMessage", "PeerMessage"]:
        theme.set_type_variation(type, "PanelContainer")
        theme.set_stylebox("panel", type, surface(colors.hover if type == "OwnMessage" else colors.field, 12, 12))
    theme.set_stylebox("slider", "HSlider", surface(colors.field, 4, 4))
    theme.set_stylebox("grabber_area", "HSlider", surface(colors.accent, 4, 4))
    theme.set_stylebox("grabber_area_highlight", "HSlider", surface(colors.accent, 4, 4))
    for type in ["Button", "OptionButton", "CheckButton"]:
        for state in ["normal", "hover", "pressed", "disabled"]:
            theme.set_stylebox(state, type, surface(colors.field if state in ["normal", "disabled"] else colors.hover))
        var focus := surface(Color.TRANSPARENT)
        focus.border_color = colors.accent
        focus.set_border_width_all(2)
        theme.set_stylebox("focus", type, focus)
        for key in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
            theme.set_color(key, type, colors.accent)
    for type in ["LineEdit", "TextEdit"]:
        theme.set_stylebox("normal", type, surface(colors.field, 12))
        var focus := surface(colors.field, 12)
        focus.border_color = colors.accent
        focus.set_border_width_all(2)
        theme.set_stylebox("focus", type, focus)
    for type in ["VBoxContainer", "HBoxContainer"]:
        theme.set_constant("separation", type, SPACE)
    theme.set_constant("h_separation", "GridContainer", SPACE)
    theme.set_constant("v_separation", "GridContainer", SPACE)
    theme.set_stylebox("background", "ProgressBar", surface(colors.field, 6, 0))
    theme.set_stylebox("fill", "ProgressBar", surface(colors.accent, 6, 0))
    for pair in [["EnergyMeter", "4ca47a"], ["StaminaMeter", "699cc4"], ["StressMeter", "ce9d65"]]:
        theme.set_type_variation(pair[0], "ProgressBar")
        theme.set_stylebox("fill", pair[0], surface(Color(pair[1]), 6, 0))
    for pair in [["CompactPanel", 4], ["DockPanel", 6]]:
        theme.set_type_variation(pair[0], "PanelContainer")
        theme.set_stylebox("panel", pair[0], surface(colors.surface, RADIUS, pair[1]))
    for type in ["DockButton", "PhoneTile"]:
        theme.set_type_variation(type, "Button")
        theme.set_font_size("font_size", type, 12)
        theme.set_constant("icon_max_width", type, 20 if type == "DockButton" else 28)
        theme.set_stylebox("normal", type, surface(colors.field if type == "PhoneTile" else Color.TRANSPARENT, RADIUS, 4))
    for type in ["WorldLabel", "Toast"]:
        theme.set_type_variation(type, "Label")
        var card := surface(colors.surface, 10, 8)
        card.border_color = colors.accent
        card.set_border_width_all(1)
        theme.set_stylebox("normal", type, card)
        theme.set_font_size("font_size", type, 16 if type == "WorldLabel" else 14)
        theme.set_color("font_color", type, colors.text)
    theme.set_type_variation("ErrorLabel", "Label")
    theme.set_color("font_color", "ErrorLabel", colors.danger)
    theme.set_block_signals(false)
    theme.emit_changed()
    return theme

static func bind(node: Node) -> void:
    if node is Control and not node.get_parent() is Control:
        node.theme = RESOURCE
    for child in node.get_children(): bind(child)
