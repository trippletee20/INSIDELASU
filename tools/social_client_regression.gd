extends SceneTree
var checks: int = 0
var failures: int = 0
func check(ok: bool, title: String) -> void:
    checks += 1
    if not ok:
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
    game.profile_name_input.text = "Social client student"
    game._create_student_profile()
    await process_frame
    var client = game.campus_social
    client.set_process(false)
    var second = preload("res://scripts/campus_social.gd").new()
    root.add_child(second)
    client.supabase = null
    second.supabase = null
    client.url = OS.get_environment("INSIDE_LASU_SOCIAL_TEST_URL")
    second.url = client.url
    var reply: Dictionary = await client.request("/register", {"username": "godot_student", "password": "test-only-strong-password"})
    check(reply.has("token"), "Godot HTTP client creates real account")
    if not reply.has("token"):
        print(reply)
        quit(1)
        return
    client.token = reply.token
    client.username = reply.username
    reply = await second.request("/register", {"username": "study_partner", "password": "test-only-another-password"})
    check(reply.has("token"), "second Godot client has distinct account")
    second.token = reply.get("token", "")
    reply = await client.request("/users?q=study")
    check(reply.get("users", []).size() == 1, "search resolves another player's username")
    reply = await client.request("/messages", {"to": "study_partner", "body": "Meet at the reading room?"})
    check(reply.get("ok", false), "Godot client sends message")
    reply = await second.request("/messages?to=godot_student")
    check(reply.get("messages", []).size() == 1 and reply.messages[0].body == "Meet at the reading room?", "other client receives actual message")
    game.campus_phone.open("Messages")
    await client.conversation(game.campus_phone, "study_partner")
    await process_frame
    check(is_instance_valid(client.history) and client.history.get_child_count() == 1, "actual phone renders the conversation as a chat bubble")
    var bubble_text: RichTextLabel = client.history.get_child(0).get_child(1).get_child(0)
    check(not bubble_text.bbcode_enabled and bubble_text.text.contains("Meet at the reading room?"), "message UI shows received content as literal text")
    game.campus_phone.close()
    reply = await client.request("/relationship", {"to": "study_partner", "kind": "Reading partners"})
    check(reply.get("ok", false), "relationship invitation reaches service")
    reply = await second.request("/inbox")
    var invitations: Array = reply.get("relationships", [])
    check(invitations.size() == 1 and invitations[0].status == "pending", "recipient sees pending invitation")
    reply = await second.request("/relationship/respond", {"id": int(invitations[0].id), "status": "accepted"})
    check(reply.get("ok", false), "recipient can accept invitation")
    reply = await client.request("/inbox")
    check(reply.relationships[0].status == "accepted", "acceptance visible to sender")
    await second.request("/presence", {"location": "campus", "x": 10, "y": 0, "z": 20, "yaw": 1})
    reply = await client.request("/presence", {"location": "campus", "x": 12, "y": 0, "z": 20, "yaw": 0})
    check(reply.get("peers", []).size() == 1, "Godot client receives real same-location peer")
    client.selected = ""
    await client._process(3.1)
    check(client.avatars.has("study_partner"), "actual presence controller creates a labelled peer in the scene")
    await second.request("/presence", {"location": "private:hostel:101", "x": 900})
    reply = await client.request("/presence", {"location": "campus"})
    check(reply.get("peers", []).is_empty(), "private-room player disappears from public peers")
    await second.request("/block", {"to": "godot_student"})
    reply = await client.request("/messages", {"to": "study_partner", "body": "Should not send"})
    check(reply.has("error"), "blocked conversation fails visibly in Godot client")
    game.queue_free()
    second.queue_free()
    await process_frame
    print("SOCIAL CLIENT: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
