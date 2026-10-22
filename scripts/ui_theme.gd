extends RefCounted
## Shared app controls: warm surfaces, quiet borders and consistent focus states.
static func surface(color: Color, radius: int = 22, padding: int = 12) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(radius)
    style.set_content_margin_all(padding)
    style.shadow_color = Color(0.06, 0.13, 0.12, 0.14)
    style.shadow_size = 8
    style.shadow_offset = Vector2(0, 3)
    return style

static func make(font: Font) -> Theme:
    var theme := Theme.new()
    theme.default_font = font
    theme.default_font_size = 14
    for type in ["Label", "RichTextLabel", "Button", "OptionButton", "LineEdit", "TextEdit"]:
        theme.set_color("font_color", type, Color("17332e"))
    for type in ["Button", "OptionButton"]:
        theme.set_stylebox("normal", type, surface(Color("f8faf6"), 22))
        theme.set_stylebox("hover", type, surface(Color("e4f4e9"), 22))
        theme.set_stylebox("pressed", type, surface(Color("d1eadc"), 22))
        var focus := surface(Color.TRANSPARENT, 22)
        focus.border_color = Color("1c855c")
        focus.set_border_width_all(2)
        theme.set_stylebox("focus", type, focus)
        theme.set_color("font_hover_color", type, Color("126443"))
        theme.set_color("font_pressed_color", type, Color("126443"))
        theme.set_color("font_focus_color", type, Color("17332e"))
    for type in ["LineEdit", "TextEdit"]:
        theme.set_stylebox("normal", type, surface(Color("edf3ed"), 14))
        theme.set_stylebox("focus", type, surface(Color("e1f0e5"), 14))
        theme.set_color("font_placeholder_color", type, Color("667b70"))
        theme.set_color("caret_color", type, Color("17332e"))
        theme.set_color("font_selected_color", type, Color("17332e"))
    return theme
