extends SceneTree
var checks: int = 0
var failures: int = 0
func check(value: bool, title: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("FAIL: ", title)
func _initialize() -> void:
    if OS.get_environment("INSIDE_LASU_TEST") != "1":
        quit(2)
        return
    call_deferred("run")
func run() -> void:
    preload("res://scripts/mobile_controls.gd")._touch_available = 1
    root.size = Vector2i(393, 873)
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    if game.profile_data.is_empty():
        game.profile_name_input.text = "Campus ecosystem tester"
        game._create_student_profile()
    await process_frame
    var phone = game.campus_phone
    check(not game.student_ui.hud_expanded and not game.student_ui.footer_panel.visible, "default HUD leaves the world clear")
    phone.open()
    game._sync_mobile_controls()
    var grid: GridContainer = phone.body.get_child(2) as GridContainer
    check(grid != null and grid.get_child_count() == 16, "all sixteen phone apps render")
    check(phone.panel.visible and not game.player.is_physics_processing() and not game.mobile_controls.enabled, "phone cancels movement and touch ownership")
    for item in phone.APPS:
        phone.show_app(item[0])
        await process_frame
        if not phone.panel.visible:
            game.student_ui.close()
            phone.open()
    phone.show_app("Notes")
    var fields: Array = []
    for child in phone.body.get_children():
        if child is LineEdit or child is TextEdit: fields.append(child)
    fields[0].text = "BIO lecture"
    fields[1].text = "Cell structure and functions. [b]literal[/b]"
    for child in phone.body.get_children():
        if child is Button and child.text == "Save note": child.pressed.emit(); break
    await process_frame
    check(phone.state.notes.size() == 1 and phone.state.notes[0].text.contains("Cell structure"), "notebook creates a real saved lecture note")
    phone.show_app("Study planner")
    for child in phone.body.get_children():
        if child is LineEdit: child.text = "Revise BIO for 30 minutes"
    for child in phone.body.get_children():
        if child is Button and child.text == "Add study goal": child.pressed.emit(); break
    await process_frame
    check(phone.state.planner.size() == 1, "planner adds study goals")
    phone.quiz_question(3, 2)
    check(phone.state.quiz_score == 2 and phone.state.quiz_day == Time.get_date_string_from_system(), "quiz result persists and locks daily replay")
    phone.close()
    var saved: Dictionary = preload("res://scripts/save_store.gd").load_profile()
    check(saved.get("campus_phone", {}).get("notes", []).size() == 1, "existing versioned save stores phone content")
    check(game.player.is_physics_processing(), "closing phone restores walking")
    check(game.campus_social.url.is_empty() and game.campus_social.peers.is_empty(), "unconfigured social service never invents online players")
    var count: int = 0
    for site in game.interior_catalog:
        # Test completed buildings only; radio access remains programme restricted.
        if site == "LASU Radio": continue
        game._leave_interior()
        game._open_task_panel(site)
        check(game.task_panel.visible, "location actions reachable for " + site)
        game._enter_interior(site)
        check(game.active_interior_site == site, "enter " + site)
        var rooms: Array = game.CAMPUS_ROOMS.for_site(site, game.building_experiences)
        for i in range(rooms.size()):
            game._enter_campus_room(i)
            await process_frame
            var floor_node: Node3D = game.interior_builder.current_floor
            check(str(floor_node.get_meta("room_title", "")) == str(rooms[i][0]), "independent named room for " + site)
            check(str(floor_node.get_meta("interior_theme", "")) == str(rooms[i][1]), "correct room kit for " + site)
            check(get_nodes_in_group("campus_actions").size() == 3, "old room actions removed on room switch")
            var staff: Node3D = null
            var notebook: Node3D = null
            for action in get_nodes_in_group("campus_actions"):
                if action.get_meta("action") == "staff": staff = action
                if action.get_meta("action") == "notes": notebook = action
            check(staff != null and not str(staff.get_meta("dialogue", "")).is_empty(), "role NPC has a usable service dialogue")
            game.player.global_position = staff.global_position + Vector3(0, 0.4, 1.4)
            check(game.try_campus_interaction(game.player) and game.task_panel.visible, "actual proximity NPC interaction opens services")
            game._close_task_panel()
            if notebook != null:
                game.player.global_position = notebook.global_position + Vector3(0, 0.4, 1.5)
                check(game.try_campus_interaction(game.player) and phone.panel.visible, "lecture notebook object opens notes")
                phone.close()
            count += 1
        game._go_to_interior_floor(0)
        check(game.active_campus_room == -1, "room returns to its floor lobby")
    game._leave_interior()
    for dimensions in [Vector2i(320, 568), Vector2i(393, 873), Vector2i(873, 393)]:
        root.size = dimensions
        await process_frame
        phone.open()
        await process_frame
        await process_frame
        await process_frame
        var rect: Rect2 = phone.panel.get_global_rect()
        check(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= dimensions.x and rect.end.y <= dimensions.y, "phone fits " + str(dimensions))
        phone.close()
    print("ECOSYSTEM: %d checks, %d failures; %d independent rooms exercised" % [checks, failures, count])
    game.queue_free()
    await process_frame
    quit(0 if failures == 0 else 1)
