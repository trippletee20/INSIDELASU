extends SceneTree
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void:
    if OS.get_environment("INSIDE_LASU_TEST") != "1":
        quit(2)
        return
    call_deferred("_run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)
        print("FAIL: ", message)
func touch(index: int, at: Vector2, pressed: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.position = at
    event.pressed = pressed
    Input.parse_input_event(event)
func drag(index: int, at: Vector2, relative: Vector2) -> void:
    var event := InputEventScreenDrag.new()
    event.index = index
    event.position = at
    event.relative = relative
    Input.parse_input_event(event)
func _run() -> void:
    preload("res://scripts/mobile_controls.gd")._touch_available = 1
    root.size = Vector2i(873, 393)
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    game.profile_name_input.text = "Touch regression student"
    game._create_student_profile()
    await process_frame
    var controls = game.mobile_controls
    controls.available = true
    game._sync_mobile_controls()
    check(controls.enabled, "touch controls activate after profile creation")
    var origin: Vector3 = game.player.position
    var center: Vector2 = controls.center
    touch(0, center, true)
    drag(0, center - Vector2(0, 54), Vector2(0, -54))
    var rotation: float = game.player.rotation.y
    touch(1, Vector2(470, 240), true)
    drag(1, Vector2(550, 250), Vector2(80, 10))
    for _frame in range(12): await physics_frame
    check(absf(game.player.rotation.y - rotation) > 0.1, "second finger turns camera within 200ms while joystick is held")
    for i in range(45):
        await physics_frame
    check(game.player.position.distance_to(origin) > 2.0, "screen drag drives actual player movement without keyboard")
    var jump_count: Array = [0]
    controls.action_requested.connect(func(action):
        if action == "jump":
            jump_count[0] += 1)
    var jump_at: Vector2 = controls.buttons.jump.get_global_rect().get_center()
    touch(2, jump_at, true)
    await process_frame
    touch(2, jump_at, false)
    await process_frame
    check(jump_count[0] == 1 and controls.movement.length() > 0.5, "third finger activates jump exactly once while moving and looking")
    touch(1, Vector2(550, 250), false)
    check(controls.movement.length() > 0.5, "releasing look finger preserves movement finger")
    game.student_ui.toggle("wallet")
    game._sync_mobile_controls()
    check(not controls.enabled and controls.movement == Vector2.ZERO and game.player.touch_movement == Vector2.ZERO, "opening menu cancels held touch and clears movement")
    game.student_ui.close()
    game._sync_mobile_controls()
    check(controls.move_finger == -1 and controls.look_finger == -1, "menu close does not resurrect held fingers")
    touch(0, center, false)
    game._mobile_action("map")
    game._sync_mobile_controls()
    check(game.overview_on and game.player.touch_movement == Vector2.ZERO, "touch map switches overview without moving character")
    game._mobile_action("map")
    check(not game.overview_on and game.player.camera.current, "touch map returns to walking camera")
    game._open_task_panel("Faculty of Education")
    check(game.task_panel.visible, "building interaction opens activity menu")
    game._close_task_panel()
    var definitions: Dictionary = game.building_experiences
    var themes: Dictionary = {}
    var new_tasks: int = 0
    var maximum_nodes: int = 0
    for site in game.interior_catalog:
        var design: Dictionary = definitions.get(site, {})
        check(not design.is_empty() and design.tasks.size() == 3, "building has three new activities: " + site)
        themes[design.theme] = true
        var spawn: Vector3 = game.interior_builder.show_floor(site, str(game.interior_catalog[site][0]), 0)
        var floor: Node3D = game.interior_builder.current_floor
        check(floor.get_meta("interior_theme") == design.theme and spawn.z > 8 and spawn.z < 12, "matching interior theme and entrance: " + site)
        maximum_nodes = maxi(maximum_nodes, floor.get_child_count())
        for entry in design.tasks:
            new_tasks += 1
            check(game._task_floor_for_site(site, entry) < game.interior_catalog[site].size() and entry.challenge.size() >= 2, "activity floor exists and has multiple decisions: " + site)
        await process_frame
    check(themes.size() == 24 and new_tasks == 168, "all 56 enterable sites covered by 24 themes and 168 activities")
    check(maximum_nodes < 600, "active interior stays within bounded procedural object budget")
    game.interior_builder.clear_interior()
    game._enter_interior("Faculty of Education")
    var entry: Dictionary = definitions["Faculty of Education"].tasks[2]
    game._go_to_interior_floor(int(entry.floor))
    game._open_task_panel("Faculty of Education")
    var wallet: int = game.wallet_balance
    var journal_size: int = game.transactions.size()
    game._run_location_task("Faculty of Education", entry)
    var answer: int = int(entry.challenge[0].answer)
    game._answer_challenge((answer + 1) % 3)
    check(game.challenge_step == 0 and game.wallet_balance == wallet, "incorrect challenge answer cannot award money")
    game._answer_challenge(answer)
    check(game.challenge_step == 1 and game.wallet_balance == wallet, "partial challenge cannot award money")
    game._answer_challenge(int(entry.challenge[1].answer))
    check(game.wallet_balance == wallet + int(entry.reward) and game.transactions.size() == journal_size + 1, "completed challenge pays exactly one journalled reward")
    game._run_location_task("Faculty of Education", entry)
    check(game.wallet_balance == wallet + int(entry.reward), "daily challenge cannot pay twice")
    game._leave_interior()
    check(game.active_interior_site.is_empty(), "building exit returns to outdoor world")
    var bus: Node3D = game.transit_system._services[0].node
    var inside: Camera3D = game.transit_system.onboard_camera(bus)
    check(inside.position.x > -3 and inside.position.x < 3 and inside.position.y < 2.8, "passenger camera is physically inside the cabin")
    inside.current = true
    rotation = inside.rotation.y
    game.transit_system.look_passenger(bus, Vector2(90, 20))
    check(absf(inside.rotation.y - rotation) > 0.1, "passenger swipe turns interior camera")
    game.transit_system.toggle_passenger_view(bus)
    check(bus.get_node("OnboardCamera").current, "ride view switches to exterior")
    game.transit_system.toggle_passenger_view(bus)
    check(inside.current, "ride view returns to cabin")
    check(game.billboard_slots.size() == 100, "all 100 billboard slots remain registered")
    game._open_advertising("AD-001")
    check(game.student_ui.current == "advertise" and game.student_ui.profile_text.text.contains("Paystack") and game.student_ui.profile_text.text.contains("Flutterwave"), "billboard opens explicit future-booking preview with both providers")
    game.student_ui.close()
    for dimensions in [Vector2i(393, 873), Vector2i(873, 393), Vector2i(360, 640), Vector2i(640, 360), Vector2i(320, 568)]:
        root.size = dimensions
        await process_frame
        await process_frame
        game.student_ui.toggle("wallet")
        await process_frame
        game.student_ui._layout()
        var bounds: Rect2 = game.student_ui.modal.get_global_rect()
        check(bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= dimensions.x + 1 and bounds.end.y <= dimensions.y + 1, "touch wallet fits " + str(dimensions))
        game.student_ui.close()
        game._open_task_panel("Faculty of Education")
        await process_frame
        await process_frame
        game._layout_action_menus()
        bounds = game.task_panel.get_global_rect()
        if bounds.position.y < 0:
            print("TASK BOUNDS ", dimensions, " ", bounds)
        check(bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= dimensions.x + 1 and bounds.end.y <= dimensions.y + 1, "touch activity menu fits " + str(dimensions))
        game._close_task_panel()
        game.shuttle_menu.visible = true
        game.shuttle_menu_title.text = "LASU SHUTTLE\nChoose your destination and travel style."
        await process_frame
        await process_frame
        game._layout_action_menus()
        bounds = game.shuttle_menu.get_global_rect()
        if bounds.position.y < 0:
            print("SHUTTLE BOUNDS ", dimensions, " ", bounds)
        check(bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= dimensions.x + 1 and bounds.end.y <= dimensions.y + 1, "touch shuttle menu fits " + str(dimensions))
        game.shuttle_menu.visible = false
    print("MOBILE GAMEPLAY: %d checks, %d failures; max interior children %d" % [checks, failures.size(), maximum_nodes])
    game.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)
