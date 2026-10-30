extends CanvasLayer
const APP_THEME = preload("res://scripts/ui_theme.gd")
## Phone apps operate on real game state. Network apps never invent online players.
signal opened_changed(open: bool)
var game: Node
var panel: PanelContainer
var body: VBoxContainer
var heading: Label
var scroll: ScrollContainer
var maximized: bool = false
var app: String = "Home"
var state: Dictionary = {"notes": [], "planner": [], "quiz_day": "", "quiz_score": 0}
var query: String = ""
var app_grid: GridContainer
var online: Node
const ICONS: Array = ["places", "messages", "contacts", "notes", "planner", "courses", "jobs", "wallet", "room", "ride", "health", "skills", "quiz", "societies", "guide", "courses"]
const APPS: Array = [
    ["Places & tasks", "Explore"], ["Messages", "Social"], ["Contacts", "Connect"],
    ["Notes", "Academics"], ["Study planner", "Academics"], ["Courses", "Academics"],
    ["Campus jobs", "Earn"], ["Wallet", "Money"], ["My room", "Living"],
    ["Ride", "Transport"], ["Wellbeing", "Recharge"], ["Skill lab", "Progress"],
    ["Campus quiz", "Play"], ["Societies", "Community"], ["Guide", "Help"], ["Profile", "Me"]
]

func _ready() -> void:
    layer = 22
    panel = PanelContainer.new()
    panel.name = "CampusPhone"
    add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", APP_THEME.SPACE)
    panel.add_child(column)
    var bar := HBoxContainer.new()
    column.add_child(bar)
    heading = Label.new()
    heading.text = "LASU Connect"
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.clip_text = true
    heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    heading.add_theme_font_size_override("font_size", 20)
    bar.add_child(heading)
    button("Size", func(): maximized = not maximized; _layout(), bar)
    button("Home", func(): show_app("Home"), bar)
    button("Close", close, bar)
    scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)
    body = VBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", APP_THEME.SPACE)
    scroll.add_child(body)
    panel.visible = false
    get_viewport().size_changed.connect(_layout)
    _layout()

func _layout() -> void:
    var size: Vector2 = get_viewport().get_visible_rect().size
    panel.size = Vector2(size.x - 16 if maximized else minf(470, size.x - 16), minf(790, size.y - 16))
    panel.position = (size - panel.size) * 0.5
    if is_instance_valid(app_grid): app_grid.columns = 2 if panel.size.x < 350 else 3

func button(text: String, action: Callable, parent: Node = null) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size.y = 48
    b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    if parent is HBoxContainer:
        b.autowrap_mode = TextServer.AUTOWRAP_OFF
        b.custom_minimum_size.x = 48
        b.add_theme_font_size_override("font_size", 12)
    b.pressed.connect(action, CONNECT_DEFERRED)
    (body if parent == null else parent).add_child(b)
    return b

func label(text: String) -> Label:
    var value := Label.new()
    value.text = text
    value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    value.add_theme_font_size_override("font_size", 15)
    body.add_child(value)
    return value

func input(placeholder: String, limit: int = 100) -> LineEdit:
    var field := LineEdit.new()
    field.placeholder_text = placeholder
    field.max_length = limit
    field.custom_minimum_size.y = 48
    body.add_child(field)
    return field

func open(target: String = "Home") -> void:
    if game.profile_data.is_empty() or game.profile_layer != null or game.task_panel.visible or game.shuttle_menu.visible or game.student_ui.modal.visible:
        return
    panel.visible = true
    opened_changed.emit(true)
    show_app(target)
    preload("res://scripts/ui_motion.gd").reveal(panel)

func close() -> void:
    panel.visible = false
    opened_changed.emit(false)
    game._save_game()

func clear() -> void:
    for child in body.get_children():
        body.remove_child(child)
        child.queue_free()
    scroll.scroll_vertical = 0

func persist() -> void:
    game._save_game()

func show_app(target: String) -> void:
    app = target
    if online != null: online.selected = ""
    clear()
    heading.text = "LASU Connect" if target == "Home" else target
    match target:
        "Home": home()
        "Settings": settings()
        "Places & tasks": places()
        "Campus jobs": places(true)
        "Notes": notes()
        "Study planner": planner()
        "Courses": courses()
        "Profile":
            close()
            game.student_ui.toggle("profile")
        "Wallet":
            close()
            game.student_ui.toggle("wallet")
        "My room": room()
        "Ride": ride()
        "Wellbeing": wellbeing()
        "Skill lab": skill_lab()
        "Campus quiz": quiz()
        "Societies": societies()
        "Messages", "Contacts": social(target)
        "Guide":
            close()
            game.student_ui.toggle("help")

func home() -> void:
    label("%s  ·  %s\n%s · %s" % [Time.get_time_string_from_system().substr(0, 5), Time.get_date_string_from_system(), str(game.profile_data.get("student_name", "Student")), str(game.profile_data.get("department", "Campus life"))])
    label("Your campus, in your pocket")
    var grid := GridContainer.new()
    app_grid = grid
    grid.columns = 2 if panel.size.x < 350 else 3
    grid.add_theme_constant_override("h_separation", APP_THEME.SPACE)
    grid.add_theme_constant_override("v_separation", APP_THEME.SPACE)
    body.add_child(grid)
    for item in APPS:
        var target: String = item[0]
        var tile := button(target + "\n" + str(item[1]), func(): show_app(target), grid)
        tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tile.custom_minimum_size = Vector2(0, 112)
        tile.theme_type_variation = "PhoneTile"
        tile.expand_icon = true
        tile.icon = load("res://assets/phone/" + str(ICONS[APPS.find(item)]) + ".svg")
        tile.add_theme_constant_override("icon_max_width", 28)
        tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
        tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
        tile.add_theme_font_size_override("font_size", 12)
    button("Settings", settings)
    label("Progress is saved on this device. Social accounts connect separately when the campus server is available.")

func places(jobs_only: bool = false) -> void:
    label("Explore campus locations. Enter a completed building from nearby, then choose a room or activity. Jobs pay fictional game money.")
    var search := input("Search a building or activity")
    search.text = query
    search.text_submitted.connect(func(value): query = value; show_app(app))
    button("Search", func(): query = search.text; show_app(app))
    var names: Array = game.task_catalog.keys()
    names.sort()
    if game.player.nearby_feature != null:
        var nearby: String = str(game.player.nearby_feature.get_meta("campus_name", ""))
        if names.has(nearby):
            names.erase(nearby)
            names.push_front(nearby)
    for value in names:
        var site: String = str(value)
        var tasks: Array = game.task_catalog[site]
        if jobs_only:
            tasks = tasks.filter(func(entry): return int(entry.get("reward", 0)) > 0 or str(entry.get("kind", "")) == "job")
            if tasks.is_empty():
                continue
        var text: String = site.to_lower() + JSON.stringify(tasks).to_lower()
        if not query.is_empty() and not text.contains(query.to_lower()):
            continue
        button(site + " · " + str(tasks.size()) + (" jobs" if jobs_only else " activities"), func(): place_detail(site))

func place_detail(site: String) -> void:
    clear()
    heading.text = "Campus location"
    label(site)
    var floors: Array = game.interior_catalog.get(site, [])
    label("Open-air location" if floors.is_empty() else "Enterable building · " + str(floors.size()) + " floors")
    for task in game.task_catalog.get(site, []):
        label("• " + str(task.get("title", "Activity")))
    if game.active_interior_site == site or game.is_near_site(site):
        button("Open location actions", func(): close(); game._open_task_panel(site))
    else:
        label("Walk to this location to interact. Use the campus map to find its label.")
        button("View campus map", func(): close(); game.overview_on = true; game.overview_camera.current = true)
    button("Back to places", func(): show_app("Places & tasks"))

func notes() -> void:
    label("Private notebook · saved on this browser. Take lecture notes or record your discoveries.")
    var title := input("Note title", 80)
    var content := TextEdit.new()
    content.placeholder_text = "Write your note…"
    content.custom_minimum_size.y = 150
    content.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    body.add_child(content)
    button("Save note", func():
        if title.text.strip_edges().is_empty() or content.text.strip_edges().is_empty():
            return
        if state.notes.size() >= 100:
            label("Notebook full. Delete an old note first.")
            return
        state.notes.push_front({"title": title.text.strip_edges(), "text": content.text.left(4000), "date": Time.get_date_string_from_system(), "site": game.active_interior_site})
        persist()
        show_app("Notes"))
    for i in range(state.notes.size()):
        var entry: Dictionary = state.notes[i]
        label(str(entry.title) + " · " + str(entry.date) + "\n" + str(entry.text))
        var index: int = i
        button("Delete note", func(): state.notes.remove_at(index); persist(); show_app("Notes"))

func planner() -> void:
    label("Create a study checklist. Tick completed sessions; reminders stay here on this device.")
    var text := input("Course / study goal", 140)
    button("Add study goal", func():
        if not text.text.strip_edges().is_empty() and state.planner.size() < 60:
            state.planner.append({"text": text.text.strip_edges(), "done": false})
            persist()
            show_app("Study planner"))
    for i in range(state.planner.size()):
        var index: int = i
        var item: Dictionary = state.planner[i]
        button(("✓ " if item.done else "○ ") + str(item.text), func(): state.planner[index].done = not state.planner[index].done; persist(); show_app("Study planner"))
        button("Remove goal", func(): state.planner.remove_at(index); persist(); show_app("Study planner"))

func courses() -> void:
    label(str(game.profile_data.get("department", "General Studies")) + " · Level " + str(game.profile_data.get("level", "100")))
    label("Practice sessions in this game are fictional, not LASU's official course registration or timetable.")
    button("Find lecture and study tasks", func(): query = "study"; show_app("Places & tasks"))
    button("Open my study planner", func(): show_app("Study planner"))
    button("Take lecture notes", func(): show_app("Notes"))

func room() -> void:
    var site: String = str(game.profile_data.get("hostel_name", ""))
    label(site + " · Room " + str(game.profile_data.get("room_number", "?")))
    label("Your own room has rest, decoration and visitor settings. Visit your assigned hostel to unlock it.")
    if game.active_interior_site == site:
        button("Enter my room", func(): close(); game._enter_private_room())
    else:
        button("Find my hostel", func(): place_detail(site))

func ride() -> void:
    label("Campus shuttle · ₦150 per trip in game money. Walk to a shuttle stand or a stopped bus and tap Interact.")
    if game.ride_bus != null:
        button("Switch cabin / outside view", func(): game.transit_system.toggle_passenger_view(game.ride_bus))
    button("Open campus map", func(): close(); game.overview_on = true; game.overview_camera.current = true)

func wellbeing() -> void:
    label("Energy %d / 100\nStamina %d / 100\nStress %d / 100" % [game.energy, game.stamina, game.stress])
    label("Rest in your room, eat at a food location or visit the campus clinic. These are game activities.")
    button("Find food and clinic activities", func(): query = "health"; show_app("Places & tasks"))
    button("My hostel room", func(): show_app("My room"))

func skill_lab() -> void:
    label("Build skills through campus activities. Each activity explains its requirements and rewards.")
    for key in game.skills:
        label(str(key).capitalize() + " · " + str(game.skills[key]) + " / 10")
    button("Find practice activities", func(): query = ""; show_app("Places & tasks"))

func quiz() -> void:
    var today: String = Time.get_date_string_from_system()
    if state.quiz_day == today:
        label("Today's quiz complete · " + str(state.quiz_score) + "/3. Come back tomorrow.")
        return
    quiz_question(0, 0)

func quiz_question(index: int, score: int) -> void:
    clear()
    var questions: Array = [["What makes a stronger reading partnership?", ["Agree on a regular study time", "Share another student's password", "Skip every revision session"], 0], ["How should you handle an unknown payment link?", ["Enter your banking PIN", "Verify the source first", "Forward it to everyone"], 1], ["Which note-taking habit helps recall?", ["Copy without understanding", "Never revisit your notes", "Summarise and test yourself"], 2]]
    if index >= questions.size():
        state.quiz_day = Time.get_date_string_from_system()
        state.quiz_score = score
        persist()
        show_app("Campus quiz")
        return
    label("Question %d / 3\n%s" % [index + 1, questions[index][0]])
    for i in range(3):
        var answer: int = i
        button(questions[index][1][i], func(): quiz_question(index + 1, score + (1 if answer == questions[index][2] else 0)))

func societies() -> void:
    label("Your society interests · local checklist. Find fellow members through Contacts when social services are connected.")
    var interests: Array = state.get("societies", [])
    for title in ["Tech & builders", "Debate & public speaking", "Arts & culture", "Sports crew", "Entrepreneurs", "Reading circle", "Volunteer team"]:
        var society: String = title
        button(("✓ " if interests.has(society) else "+ ") + society, func():
            if interests.has(society): interests.erase(society)
            else: interests.append(society)
            state["societies"] = interests
            persist()
            show_app("Societies"))

func social(target: String) -> void:
    online.render(self, target)

func settings() -> void:
    app = "Settings"
    clear()
    heading.text = "Settings"
    label("Changes apply immediately and save with your student on this device.")
    setting_choice("Appearance", "theme", ["system", "light", "dark"], ["System (device)", "Light", "Dark"])
    setting_choice("Graphics quality", "quality", ["auto", "low", "medium", "high"], ["Auto · device capability", "Low · lighter rendering", "Medium · balanced", "High · smoother edges"])
    if game.MOBILE_CONTROLS.touch_device():
        setting_slider("Control size", "control_size", 0.85, 1.2, 0.05)
        setting_choice("Stick position", "stick_position", ["left", "right"], ["Left hand", "Right hand"])
        setting_slider("Look sensitivity", "touch_sensitivity", 0.25, 2.0, 0.05)
    else:
        setting_slider("Resolution scale (3D only)", "resolution_scale", 0.5, 1.0, 0.05)
        setting_slider("Mouse sensitivity", "mouse_sensitivity", 0.25, 2.0, 0.05)
    setting_slider("Master volume", "volume", 0.0, 1.0, 0.05)
    if not game.MOBILE_CONTROLS.touch_device():
        label("KEYBINDINGS · display only")
        for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "interact"]:
            var keys: Array[String] = []
            for event in InputMap.action_get_events(action):
                if event is InputEventKey: keys.append(OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode))
            label(action.replace("_", " ").capitalize() + " — " + " / ".join(keys))
        label("Shift — Run · F — Sit/stand\nM — Map · P — Profile · B — Wallet\nH — Help · T — Phone · F2 — Settings\nV — Ride camera · Right mouse — Cabin look\nEsc — Close menu / release mouse")
    label("Lower quality reduces 3D rendering cost; UI stays sharp. High quality may be slower on phones.")
    button("Reset settings to device defaults", func():
        game.preferences = game.SETTINGS.validated({})
        game.SETTINGS.apply(game)
        game._save_game()
        settings())

func setting_choice(title: String, key: String, values: Array, captions: Array) -> void:
    label(title)
    var choice := OptionButton.new()
    choice.name = "Setting_" + key
    choice.tooltip_text = title
    choice.custom_minimum_size.y = 48
    choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for caption in captions: choice.add_item(caption)
    choice.selected = values.find(game.preferences[key])
    choice.item_selected.connect(func(index): game.update_setting(key, values[index]))
    body.add_child(choice)
    if key == "theme": choice.grab_focus.call_deferred()

func setting_slider(title: String, key: String, low: float, high: float, step_value: float) -> void:
    var caption := label(title + " · %d%%" % roundi(float(game.preferences[key]) * 100))
    var slider := HSlider.new()
    slider.name = "Setting_" + key
    slider.tooltip_text = title
    slider.custom_minimum_size.y = 44
    slider.min_value = low
    slider.max_value = high
    slider.step = step_value
    slider.value = game.preferences[key]
    slider.value_changed.connect(func(value):
        caption.text = title + " · %d%%" % roundi(value * 100)
        game.update_setting(key, value))
    body.add_child(slider)
