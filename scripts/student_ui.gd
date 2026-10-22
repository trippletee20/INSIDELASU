extends CanvasLayer
## Player-facing HUD and expandable profile/wallet. World simulation stays separate.
signal modal_changed(open: bool)
signal reward_requested
signal ad_preview_requested
var student_name: Label
var balance: Label
var location: Label
var objective: Label
var prompt: Label
var clock: Label
var energy: ProgressBar
var stamina: ProgressBar
var stress: ProgressBar
var modal: PanelContainer
var modal_title: Label
var profile_text: RichTextLabel
var wallet_text: RichTextLabel
var wallet_summary: Label
var reward: Button
var search: LineEdit
var wallet_box: VBoxContainer
var records: Array = []
var current: String = ""
var money_formatter: Callable
var top_buttons: Array[Button] = []
var top_row: HBoxContainer
var status_panel: PanelContainer
var footer_panel: PanelContainer
var meters_row: HBoxContainer
var close_button: Button
var ad_preview: Button

func _panel(parent: Node) -> PanelContainer:
    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color("102835")
    style.border_color = Color("3c7777")
    style.set_border_width_all(1)
    style.set_corner_radius_all(12)
    style.set_content_margin_all(14)
    panel.add_theme_stylebox_override("panel", style)
    parent.add_child(panel)
    return panel

func _label(text: String, parent: Node, size: int = 16) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", Color("edf4eb"))
    parent.add_child(label)
    return label

func _button(text: String, parent: Node, action: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size.y = 44
    button.pressed.connect(action)
    parent.add_child(button)
    return button

func _meter(text: String, parent: Node, tint: Color) -> ProgressBar:
    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(box)
    _label(text, box, 12)
    var bar := ProgressBar.new()
    bar.custom_minimum_size = Vector2(80, 16)
    bar.show_percentage = false
    var fill := StyleBoxFlat.new()
    fill.bg_color = tint
    fill.set_corner_radius_all(6)
    bar.add_theme_stylebox_override("fill", fill)
    box.add_child(bar)
    return bar

func _ready() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    margin.offset_left = 16
    margin.offset_right = -16
    margin.offset_top = 12
    root.add_child(margin)
    var top: PanelContainer = _panel(margin)
    var row := HBoxContainer.new()
    top_row = row
    row.add_theme_constant_override("separation", 16)
    top.add_child(row)
    student_name = _label("INSIDE LASU", row, 18)
    student_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    student_name.clip_text = true
    student_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    balance = _label("", row, 18)
    clock = _label("", row)
    for item in [["Profile · P", "profile"], ["Wallet · B", "wallet"], ["Help · H", "help"]]:
        var key: String = item[1]
        top_buttons.append(_button(item[0], row, func(): toggle(key)))
    var status := _panel(root)
    status_panel = status
    status.position = Vector2(16, 88)
    status.custom_minimum_size.x = 360
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    status.add_child(column)
    location = _label("Main Gate", column, 14)
    objective = _label("Create your student profile to begin.", column, 14)
    objective.custom_minimum_size.x = 320
    objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var meters := HBoxContainer.new()
    meters_row = meters
    meters.add_theme_constant_override("separation", 12)
    column.add_child(meters)
    energy = _meter("Energy", meters, Color("5db688"))
    stamina = _meter("Stamina", meters, Color("5596cf"))
    stress = _meter("Stress", meters, Color("e39a62"))
    var footer := _panel(root)
    footer_panel = footer
    footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    footer.offset_left = 16
    footer.offset_right = -16
    footer.offset_top = -86
    footer.offset_bottom = -12
    prompt = _label("WASD move · Mouse look · E interact · M map · Shift run · Space jump", footer, 14)
    prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    modal = _panel(root)
    modal.name = "StudentModal"
    modal.focus_mode = Control.FOCUS_ALL
    modal.visible = false
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 12)
    modal.add_child(content)
    var heading := HBoxContainer.new()
    content.add_child(heading)
    modal_title = _label("Student", heading, 24)
    modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    modal_title.clip_text = true
    modal_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    close_button = _button("Close", heading, close)
    profile_text = RichTextLabel.new()
    profile_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
    profile_text.add_theme_font_size_override("normal_font_size", 17)
    content.add_child(profile_text)
    ad_preview = _button("Preview an ad", content, func(): ad_preview_requested.emit())
    ad_preview.visible = false
    wallet_box = VBoxContainer.new()
    wallet_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(wallet_box)
    wallet_summary = _label("", wallet_box, 16)
    reward = _button("Claim daily support", wallet_box, func(): reward_requested.emit())
    search = LineEdit.new()
    search.placeholder_text = "Search transactions by source or description"
    search.custom_minimum_size.y = 38
    search.text_changed.connect(func(_query): _render_transactions())
    wallet_box.add_child(search)
    wallet_text = RichTextLabel.new()
    wallet_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
    wallet_text.add_theme_font_size_override("normal_font_size", 16)
    wallet_box.add_child(wallet_text)
    get_viewport().size_changed.connect(_layout)
    _layout()

func _layout() -> void:
    var viewport: Vector2 = get_viewport().get_visible_rect().size
    modal.size = Vector2(minf(720, viewport.x - 32), minf(570, viewport.y - 32))
    modal.position = (viewport - modal.size) * 0.5
    var touch: bool = preload("res://scripts/mobile_controls.gd").touch_device()
    var compact: bool = viewport.x < 700
    wallet_summary.add_theme_font_size_override("font_size", 14 if compact else 16)
    student_name.visible = not compact and not touch
    clock.visible = not compact and not touch
    status_panel.custom_minimum_size.x = minf(360, viewport.x - 32)
    status_panel.size = Vector2(minf(360, viewport.x - 32), 0)
    objective.custom_minimum_size.x = minf(320, viewport.x - 70)
    objective.size.x = minf(320, viewport.x - 70)
    objective.visible = not (touch and viewport.y < 500)
    meters_row.visible = not (touch and viewport.y < 500)
    if touch:
        top_row.add_theme_constant_override("separation", 6)
        balance.visible = viewport.x >= 350
        balance.custom_minimum_size = Vector2(90, 44)
        balance.clip_text = true
        balance.add_theme_font_size_override("font_size", 14)
        for i in range(top_buttons.size()):
            top_buttons[i].custom_minimum_size.x = 44 if i == 2 else 56
            top_buttons[i].visible = i != 2 or viewport.x >= 390 or viewport.x < 350
        footer_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
        footer_panel.offset_left = 16
        footer_panel.offset_right = -16
        footer_panel.offset_top = 130 if viewport.y < 500 else 230
        footer_panel.offset_bottom = footer_panel.offset_top + 62
        prompt.add_theme_font_size_override("font_size", 12)
        prompt.max_lines_visible = 3
        prompt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    for button in top_buttons:
        button.add_theme_font_size_override("font_size", 12 if compact else 14)
        button.text = button.text.get_slice(" · ", 0) if viewport.x < 1000 else ["Profile · P", "Wallet · B", "Help · H"][top_buttons.find(button)]

func toggle(kind: String) -> void:
    if current == kind:
        close()
        return
    current = kind
    modal.visible = true
    modal_title.text = {"profile": "Student profile", "wallet": "Wallet & activity", "help": "How to play", "advertise": "Billboard advertising"}[kind]
    ad_preview.visible = kind == "advertise"
    wallet_box.visible = kind == "wallet"
    profile_text.visible = kind != "wallet"
    if kind == "help":
        profile_text.text = "WELCOME TO INSIDE LASU\n\nYour first goal: visit your assigned hostel and check in. Press E near a building to see its activities.\n\nWASD — Walk\nMouse — Look around\nShift — Run\nSpace — Jump\nE — Interact, board or leave an arrived shuttle\nF — Sit or stand\nM — Campus map\nP — Student profile\nB — Wallet and receipts\nH — Help\nEsc — Close a menu / release mouse\n\nVisit a shuttle stand and press E to call a shuttle. Every trip costs ₦150.\n\nYour first hostel session is prepaid. Your assigned room has rest, furniture and privacy options. Hostel curfew starts at 23:00; permitted faculty night access stays available.\n\nProgress saves on this browser and device. Clearing site data deletes local saves. On phones: use the left thumbstick to move, swipe on the right to look, and tap Interact near buildings and shuttles. Run is a toggle. Map opens the campus overview. Onboard, use Inside / outside to switch views. On desktop, press V to switch ride views and hold the right mouse button to look around inside."
    modal_changed.emit(true)
    reward.grab_focus() if kind == "wallet" else modal.grab_focus()

func close() -> void:
    modal.visible = false
    current = ""
    modal_changed.emit(false)

func update_student(profile: Dictionary, skills: Dictionary, amount: int, journal: Array, last_reward: int, claimed: bool, formatter: Callable) -> void:
    money_formatter = formatter
    student_name.text = str(profile.get("student_name", "INSIDE LASU"))
    balance.text = formatter.call(amount)
    records = journal
    if current not in ["help", "advertise"]:
        var lines: Array[String] = []
        for pair in [["Student", "student_name"], ["Department", "department"], ["Faculty", "faculty"], ["Level", "level"], ["CGPA", "cgpa"], ["Background", "background"], ["Hostel", "hostel_name"], ["Room", "room_number"]]:
            lines.append(pair[0] + ": " + str(profile.get(pair[1], "—")))
        lines.append("\nFirst-session rent: prepaid")
        lines.append("\nSKILLS")
        for key in skills:
            lines.append(str(key).capitalize() + ": " + str(skills[key]) + " / 10")
        profile_text.text = "\n".join(lines)
    var earned: int = 0
    var spent: int = 0
    var today: String = Time.get_date_string_from_system()
    for record in journal:
        if record is Dictionary and str(record.get("date", "")) == today:
            var value: int = int(record.get("amount", 0))
            earned += maxi(0, value)
            spent += maxi(0, -value)
    wallet_summary.text = "Balance: %s\nEarned today: %s\nSpent today: %s\nLast daily support: %s" % [formatter.call(amount), formatter.call(earned), formatter.call(spent), formatter.call(last_reward)]
    reward.disabled = claimed
    reward.text = "Daily support claimed today" if claimed else "Claim daily support · ₦500–₦1,500"
    _render_transactions()

func _render_transactions() -> void:
    if not money_formatter.is_valid():
        return
    var lines: Array[String] = []
    for i in range(records.size() - 1, -1, -1):
        var record: Variant = records[i]
        if not record is Dictionary:
            continue
        var description: String = str(record.get("source", "")) + " · " + str(record.get("description", ""))
        if not search.text.is_empty() and not description.to_lower().contains(search.text.to_lower()):
            continue
        var amount: int = int(record.get("amount", 0))
        lines.append(str(record.get("time", "")) + "  " + ("+" if amount >= 0 else "−") + str(money_formatter.call(absi(amount))) + "\n" + description + "\n")
    wallet_text.text = "\n".join(lines) if not lines.is_empty() else "No matching receipts yet. New earnings and purchases appear here.\nOlder saves keep their balance and totals; historical receipts were not recorded before this update."
