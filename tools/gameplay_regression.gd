extends SceneTree
const Store = preload("res://scripts/save_store.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    if OS.get_environment("INSIDE_LASU_TEST") != "1":
        push_error("Use tools/check_environment.py: gameplay checks require isolated player data")
        quit(1)
        return
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)
        print("FAIL: ", message)

func same(a: Variant, b: Variant) -> bool:
    if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
        return float(a) == float(b)
    if a is Dictionary and b is Dictionary:
        if a.size() != b.size():
            return false
        for key in a:
            if not b.has(key) or not same(a[key], b[key]):
                return false
        return true
    if a is Array and b is Array:
        if a.size() != b.size():
            return false
        for i in range(a.size()):
            if not same(a[i], b[i]):
                return false
        return true
    return a == b

func debug_controls(node: Node) -> void:
    if node is Control and node.get_combined_minimum_size().y > 600:
        print("LARGE CONTROL ", node.get_path(), " min=", node.get_combined_minimum_size(), " size=", node.size)
    for child in node.get_children():
        debug_controls(child)

func _run() -> void:
    var fixture: String = "user://legacy_fixture.json"
    var legacy: Dictionary = {"save_version": 1, "profile": {"student_name": "Legacy student", "hostel_name": "Hostel 1", "room_number": 42},
        "wallet_balance": 54321, "total_earned": 1234, "total_spent": 456, "skills": {"intellect": 4},
        "room_furniture": ["plant"], "room_visitors_allowed": true, "last_room_rest_unix": 12345,
        "extra_custom_field": {"kept": true}}
    var file: FileAccess = FileAccess.open(fixture, FileAccess.WRITE)
    file.store_string(JSON.stringify(legacy))
    file.close()
    var migrated: Dictionary = Store.load_profile(fixture)
    check(migrated.save_version == 2 and migrated.transactions.is_empty(), "legacy migration adds schema and empty receipts")
    for key in legacy:
        if key != "save_version":
            check(same(migrated[key], legacy[key]), "legacy migration preserves " + key)
    check(Store.save_profile(migrated, fixture) == OK, "atomic save succeeds")
    file = FileAccess.open(fixture, FileAccess.WRITE)
    file.store_string("{interrupted")
    file.close()
    check(Store.load_profile(fixture).wallet_balance == 54321, "corrupt primary recovers last valid backup")
    check(Store.save_profile(migrated, fixture) == OK, "recovered save writes safely")
    var future: Dictionary = migrated.duplicate(true)
    future.save_version = 999
    file = FileAccess.open(fixture, FileAccess.WRITE)
    file.store_string(JSON.stringify(future))
    file.close()
    check(Store.save_profile(migrated, fixture) == ERR_UNAVAILABLE, "future-version saves cannot be overwritten")

    var scene: PackedScene = load("res://scenes/main.tscn")
    var game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    check(game.profile_layer != null and game.profile_data.is_empty(), "new player sees profile creation")
    game.profile_name_input.text = "Beta Test Student"
    game.rng.seed = 20261022
    game._create_student_profile()
    await process_frame
    check(game.profile_data.student_name == "Beta Test Student", "profile creation completes")
    check(game.profile_data.first_session_rent_paid and game.profile_data.hostel_rent_amount == 525000, "first hostel session remains prepaid")
    check(game.wallet_balance == game.profile_data.starting_balance, "prepaid rent does not debit starting wallet")
    check(game.skills.size() == 8 and game.profile_layer == null, "skills initialise and player can start")
    var walking_start: Vector3 = game.player.position
    Input.action_press("move_forward")
    for frame in range(60):
        await physics_frame
    Input.action_release("move_forward")
    check(Vector2(game.player.position.x - walking_start.x, game.player.position.z - walking_start.z).length() > 3.0 and absf(game.player.position.y) < 3.0, "player can walk on the ground after profile creation")
    var before: int = game.wallet_balance
    game._claim_daily_reward()
    var award: int = game.wallet_balance - before
    check(award >= 500 and award <= 1500, "daily support is bounded to 500–1500 naira")
    check(game.transactions.size() == 1 and game.transactions[0].source == "Daily support", "daily support has an exact receipt")
    game._claim_daily_reward()
    check(game.wallet_balance == before + award and game.transactions.size() == 1, "daily support cannot be claimed twice")

    before = game.wallet_balance
    for i in range(game.destination_option.item_count):
        game.destination_option.select(i)
        game.chosen_bus = game.transit_system._services[0].node
        game._confirm_quick_travel()
        if game.wallet_balance < before:
            break
    check(game.wallet_balance == before - 150, "quick travel debits exactly the 150 naira fare")
    check(game.transactions[-1].amount == -150 and game.transactions[-1].source == "Shuttle", "shuttle fare records destination receipt")

    var hostel: String = game.profile_data.hostel_name
    game.show_interaction(hostel)
    check(game.profile_data.hostel_checked_in, "assigned hostel check-in completes objective")
    game._enter_interior(hostel)
    check(game.active_interior_site == hostel, "hostel interior opens")
    game._enter_private_room()
    check(game.active_private_room, "assigned private room opens")
    before = game.wallet_balance
    game._buy_room_furniture("plant", 2200)
    check(game.room_furniture.has("plant") and game.wallet_balance == before - 2200, "private-room furniture purchase persists exact cost")
    game._toggle_room_visitors()
    check(game.room_visitors_allowed, "visitor preference toggles")
    game.energy = 30
    game._rest_in_room()
    check(game.energy == 52 and game.last_room_rest_unix > 0, "private-room rest restores stats and starts cooldown")
    game._rest_in_room()
    check(game.energy == 52, "rest cooldown prevents repeat reward")
    game._return_to_hostel_lobby()
    check(not game.active_private_room and game.active_interior_site == hostel, "private room returns to hostel lobby")
    game._leave_interior()
    check(game.active_interior_site.is_empty() and game.player.position.x < 800, "hostel exit returns player outdoors")

    for size_value in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
        root.size = size_value
        root.content_scale_size = size_value
        await process_frame
        await process_frame
        game.student_ui.toggle("wallet")
        game._update_wallet_panel()
        var bounds: Rect2 = game.student_ui.modal.get_global_rect()
        var viewport: Vector2 = root.get_visible_rect().size
        print("LAYOUT ", size_value, " viewport=", viewport, " bounds=", bounds)
        check(bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= viewport.x + 1 and bounds.end.y <= viewport.y + 1,
            "wallet fits viewport " + str(size_value))
        game.student_ui.search.text = "Shuttle"
        game.student_ui._render_transactions()
        check(game.student_ui.wallet_text.text.contains("Shuttle") and not game.student_ui.wallet_text.text.contains("Daily support"), "wallet search filters receipts " + str(size_value))
        game.student_ui.close()
    game.student_ui.toggle("help")
    check(game.student_ui.modal.has_focus() and game.student_ui.profile_text.text.contains("WASD"), "help is keyboard-focusable and explains controls")
    game.student_ui.toggle("profile")
    check(game.student_ui.profile_text.text.contains("Beta Test Student"), "profile button replaces help with current student details")
    game.student_ui.close()
    game._save_game()
    var expected_balance: int = game.wallet_balance
    var expected_profile: Dictionary = game.profile_data.duplicate(true)
    var expected_skills: Dictionary = game.skills.duplicate(true)
    var expected_records: Array = game.transactions.duplicate(true)
    var expected_rest: int = game.last_room_rest_unix
    game.free()
    await process_frame
    game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    check(same(game.profile_data, expected_profile), "same student profile reloads without loss")
    check(game.wallet_balance == expected_balance and same(game.transactions, expected_records), "wallet and receipt history reload exactly")
    check(same(game.skills, expected_skills) and game.room_furniture.has("plant"), "skills and purchased furniture reload")
    check(game.room_visitors_allowed and game.last_room_rest_unix == expected_rest, "privacy and rest cooldown reload")
    check(game.profile_layer == null, "existing player does not see new-profile screen")
    var legacy_game: Dictionary = Store.load_profile()
    legacy_game.save_version = 1
    legacy_game.erase("transactions")
    legacy_game["custom_legacy_field"] = {"retained": true}
    file = FileAccess.open(Store.PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(legacy_game))
    file.close()
    game.free()
    await process_frame
    game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    check(game.wallet_balance == expected_balance and same(game.profile_data, expected_profile), "existing version-one game loads same wallet and profile")
    check(same(game.skills, expected_skills) and game.room_furniture.has("plant") and game.transactions.is_empty(), "legacy gameplay migration retains progress without inventing receipts")
    game._save_game()
    var legacy_resaved: Dictionary = Store.load_profile()
    check(legacy_resaved.save_version == 2 and legacy_resaved.custom_legacy_field.retained, "legacy resave upgrades schema and preserves unknown fields")
    game.free()
    print("GAMEPLAY REGRESSION: %d checks, %d failures" % [checks, failures.size()])
    quit(0 if failures.is_empty() else 1)
