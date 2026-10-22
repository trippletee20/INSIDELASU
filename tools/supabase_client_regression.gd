extends SceneTree
var checks: int = 0
var failures: int = 0
func check(ok: bool, title: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: ", title)
func _initialize() -> void:
    if OS.get_environment("INSIDE_LASU_TEST") != "1": quit(2); return
    call_deferred("run")
func run() -> void:
    var client = preload("res://scripts/campus_social.gd").new()
    root.add_child(client)
    check(client.supabase != null, "public config selects Supabase adapter")
    client.supabase.url = OS.get_environment("INSIDE_LASU_SUPABASE_TEST_URL")
    client.supabase.publishable_key = "sb_publishable_test"
    var reply: Dictionary = await client.request("/register", {"username": "student", "email": "student@example.test", "password": "new-test-password"})
    check(str(reply.get("error", "")).contains("confirm"), "signup without session explains email confirmation")
    check(client.token.is_empty(), "unconfirmed email never creates active session")
    reply = await client.request("/login", {"username": "", "email": "student@example.test", "password": "new-test-password"})
    check(reply.get("username", "") == "student" and reply.has("token"), "email sign-in resolves public username")
    check(not client.supabase.refresh_token.is_empty(), "refresh token kept in runtime memory")
    client.supabase.expires_at = 0
    reply = await client.request("/users?q=study")
    check(reply.get("users", []).size() == 1 and client.token == "refreshed-token", "expired session refreshes before RPC request")
    reply = await client.request("/messages", {"to": "study_partner", "body": "Hello from Godot"})
    check(reply.get("ok", false), "message maps to authenticated send RPC")
    reply = await client.request("/messages?to=study_partner")
    check(reply.get("messages", []).size() == 1, "conversation query maps to private read RPC")
    reply = await client.request("/relationship", {"to": "study_partner", "kind": "BFFs"})
    check(reply.get("ok", false), "relationship invitation uses RPC")
    reply = await client.request("/presence", {"location": "private:hostel:42"})
    check(reply.get("peers", []).is_empty(), "private presence response handled")
    reply = await client.request("/logout", {})
    check(client.token.is_empty() and client.supabase.refresh_token.is_empty(), "sign out clears both in-memory tokens")
    client.supabase.ready = false
    client.supabase.url += "/missing"
    reply = await client.request("/register", {"username": "student", "email": "student@example.test", "password": "new-test-password"})
    check(str(reply.get("error", "")).contains("being set up") and not client.supabase.ready, "absent migration blocks authentication and gives setup message")
    client.queue_free()
    await process_frame
    print("SUPABASE CLIENT: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
