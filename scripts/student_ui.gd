extends CanvasLayer
## Player-facing HUD and expandable profile/wallet. World simulation stays separate.
signal modal_changed(open: bool)
signal dashboard_changed(open: bool)
signal navigation_requested(action: String)
signal reward_requested
signal settings_requested
signal phone_requested
signal places_requested
signal ad_preview_requested
const APP_THEME = preload("res://scripts/ui_theme.gd")
var clock_pill: PanelContainer
var wallet_pill: PanelContainer
var dock: PanelContainer
var map_button: Button
var vitals_chip: Label
var location_chip: Button
var hud_expanded: bool = false
var hud_toggle: Button
var phone_button: Button
var places_button: Button
var toast: Label
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
    parent.add_child(panel)
    return panel

func _label(text: String, parent: Node, size: int = 16) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    parent.add_child(label)
    return label

func _button(text: String, parent: Node, action: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size.y = 44
    button.pressed.connect(action)
    parent.add_child(button)
    return button

func _meter(text: String, parent: Node) -> ProgressBar:
    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(box)
    _label(text, box, 12)
    var bar := ProgressBar.new()
    bar.custom_minimum_size = Vector2(80, 16)
    bar.show_percentage = false
    bar.theme_type_variation = text + "Meter"
    box.add_child(bar)
    return bar

func _ready() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    clock_pill = _panel(root)
    clock = _label("--:--", clock_pill, 16)
    clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    clock_pill.theme_type_variation = "CompactPanel"
    wallet_pill = _panel(root)
    wallet_pill.theme_type_variation = "CompactPanel"
    var wallet_row := HBoxContainer.new()
    wallet_pill.add_child(wallet_row)
    balance = _label("", wallet_row, 15)
    balance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    balance.clip_text = true
    balance.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    _button("+", wallet_row, func(): toggle("wallet"))
    student_name = _label("INSIDE LASU", root, 16)
    student_name.visible = false
    hud_toggle = _button("v", root, func(): set_expanded(not hud_expanded))
    hud_toggle.tooltip_text = "Expand or minimise campus dashboard"
    vitals_chip = _label("Energy 92%", root, 13)
    location_chip = _button("Main Gate  /  Open", root, func(): set_expanded(true))
    location_chip.clip_text = true
    dock = _panel(root)
    var nav := HBoxContainer.new()
    nav.add_theme_constant_override("separation", APP_THEME.SPACE)
    nav.alignment = BoxContainer.ALIGNMENT_CENTER
    dock.add_child(nav)
    var home := _button("Explore", nav, func(): places_requested.emit())
    home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _nav_style(home, "places")
    map_button = _button("Map", nav, func(): navigation_requested.emit("map"))
    map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _nav_style(map_button, "map")
    phone_button = _button("Phone", nav, func(): phone_requested.emit())
    phone_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _nav_style(phone_button, "phone")
    status_panel = _panel(root)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", APP_THEME.SPACE)
    status_panel.add_child(column)
    var head := HBoxContainer.new()
    column.add_child(head)
    location = _label("Main Gate", head, 20)
    location.custom_minimum_size.x = 0
    location.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    location.clip_text = true
    location.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    _button("Settings", head, func(): settings_requested.emit())
    _button("Close", head, func(): set_expanded(false))
    objective = _label("Create your student profile to begin.", column, 14)
    objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    places_button = _button("Explore here", column, func():
        set_expanded(false)
        places_requested.emit())
    meters_row = HBoxContainer.new()
    meters_row.add_theme_constant_override("separation", APP_THEME.SPACE)
    column.add_child(meters_row)
    energy = _meter("Energy", meters_row)
    stamina = _meter("Stamina", meters_row)
    stress = _meter("Stress", meters_row)
    footer_panel = _panel(column)
    prompt = _label("", footer_panel, 12)
    prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    prompt.max_lines_visible = 2
    toast = _label("", root, 12)
    toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    toast.max_lines_visible = 2
    toast.theme_type_variation = "Toast"
    toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
    modal = _panel(root)
    modal.name = "StudentModal"
    modal.focus_mode = Control.FOCUS_ALL
    modal.visible = false
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", APP_THEME.SPACE)
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

func set_expanded(value: bool) -> void:
    if hud_expanded == value: return
    hud_expanded = value
    _layout()
    dashboard_changed.emit(value)

func _layout() -> void:
    var view: Vector2 = get_viewport().get_visible_rect().size
    var short: bool = view.y < 500
    modal.size = Vector2(minf(680, view.x - 24), minf(570, view.y - 24))
    modal.position = (view - modal.size) * 0.5
    clock_pill.position = Vector2(12, 12)
    clock_pill.size = Vector2(104, 48)
    var wallet_width: float = clampf(view.x * 0.36, 115, 154)
    wallet_pill.position = Vector2(view.x - wallet_width - 12, 12)
    wallet_pill.size = Vector2(wallet_width, 48)
    # No full-width top panels: the centre of the view remains open.
    hud_toggle.position = Vector2((view.x - 44) * 0.5, 14)
    hud_toggle.size = Vector2(44, 44)
    hud_toggle.text = ""
    hud_toggle.icon = load("res://assets/phone/chevron-up.svg" if hud_expanded else "res://assets/phone/chevron-down.svg")
    vitals_chip.position = Vector2(20, 72)
    dock.position = Vector2(maxf(12, (view.x - 440) * 0.5), view.y - 72)
    dock.size = Vector2(minf(440, view.x - 24), 60)
    dock.theme_type_variation = "DockPanel"
    location_chip.position = Vector2(maxf(12, (view.x - 440) * 0.5), view.y - 122)
    location_chip.size = Vector2(minf(440, view.x - 24), 42)
    location_chip.visible = not hud_expanded and not short
    status_panel.visible = hud_expanded
    var height: float = 160 if short else minf(282, view.y - 100)
    status_panel.position = Vector2(maxf(12, (view.x - 480) * 0.5), view.y - 82 - height)
    status_panel.size = Vector2(minf(480, view.x - 24), height)
    objective.custom_minimum_size.x = maxf(100, minf(430, view.x - 72))
    objective.visible = not short
    meters_row.visible = not short
    footer_panel.visible = false
    wallet_summary.add_theme_font_size_override("font_size", 14)
    toast.position = Vector2(20, 100)
    toast.size.x = minf(350, view.x - 40)
    status_panel.set_deferred("size", Vector2(minf(480, view.x - 24), height))

func update_context() -> void:
    location_chip.text = location.text + "  /  Open"
    vitals_chip.text = "Energy %d%%" % int(energy.value)

func toggle(kind: String) -> void:
    if current == kind:
        close()
        return
    current = kind
    modal.visible = true
    preload("res://scripts/ui_motion.gd").reveal(modal)
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
    balance.text = ("₦%.1fm" % (float(amount) / 1000000.0)) if amount >= 1000000 else formatter.call(amount)
    balance.tooltip_text = formatter.call(amount)
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


func _nav_style(button: Button, icon_name: String) -> void:
    button.icon = load("res://assets/phone/" + icon_name + ".svg")
    button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
    button.add_theme_constant_override("icon_max_width", 18)
    button.add_theme_font_size_override("font_size", 12)
    button.theme_type_variation = "DockButton"
    button.expand_icon = true
