extends Node
## Real HTTP accounts/messages. Empty deployment config deliberately stays offline.
var supabase
var game: Node
var url: String = ""
var token: String = "" # Session only: never placed in the game save or URL.
var username: String = ""
var busy: bool = false
var status: String = ""
var poll_time: float = 0
var peers: Array = []
var avatars: Dictionary = {}
var selected: String = ""
var history: VBoxContainer
var history_signature: String = ""
var history_time: float = 0
const RELATIONS: Array = ["Friends", "Dating", "BFFs", "Gs", "Reading partners", "Project teammates", "Roommates", "Mentor buddies"]

func _ready() -> void:
    var config: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/social_config.json"))
    if config is Dictionary:
        url = str(config.get("server_url", "")).trim_suffix("/")
    if config is Dictionary and str(config.get("provider", "")) == "supabase":
        var configured_url: String = str(config.get("supabase_url", "")).trim_suffix("/")
        var key: String = str(config.get("publishable_key", ""))
        var rule := RegEx.new()
        rule.compile("^https://[a-z0-9]{20}[.]supabase[.]co$")
        if rule.search(configured_url) != null and key.begins_with("sb_publishable_"):
            supabase = preload("res://scripts/supabase_social.gd").new()
            supabase.url = configured_url
            supabase.publishable_key = key
            url = configured_url
    if not url.begins_with("https://") and not url.begins_with("http://127.0.0.1:"):
        url = ""

func request(path: String, data: Variant = null) -> Dictionary:
    if supabase != null:
        return await supabase.request(self, path, data)
    if busy or url.is_empty():
        return {"error": "Social server is not connected" if url.is_empty() else "Please wait for the current request"}
    busy = true
    var http := HTTPRequest.new()
    http.timeout = 12
    add_child(http)
    var headers := PackedStringArray(["Content-Type: application/json"])
    if not token.is_empty():
        headers.append("Authorization: Bearer " + token)
    var error: Error = http.request(url + path, headers, HTTPClient.METHOD_GET if data == null else HTTPClient.METHOD_POST, "" if data == null else JSON.stringify(data))
    if error != OK:
        busy = false
        http.queue_free()
        return {"error": "Could not reach social server"}
    var result: Array = await http.request_completed
    http.queue_free()
    busy = false
    if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
        return {"error": "Connection lost. Your local game is still available."}
    var value: Variant = JSON.parse_string(result[3].get_string_from_utf8())
    if not value is Dictionary:
        return {"error": "Social service returned an invalid response"}
    if int(result[1]) == 401:
        token = ""
        clear_peers()
    return value

func render(phone: CanvasLayer, target: String) -> void:
    if url.is_empty():
        phone.label("Social server not connected yet. Username search, live messages and player relationships become available after the server is deployed. Your local game, notes and activities work now.")
        phone.label("Relationships: Friends, Dating, BFFs, Gs, Reading partners, Project teammates, Roommates and Mentor buddies. Both players must agree; either can end a relationship.")
        return
    phone.label(status)
    if token.is_empty():
        phone.label("Create a social account to find real players. Use a new password, not your LASU or bank password. Messages are stored by the game server; they are not end-to-end encrypted. Session signs out when you reload.")
        var name_field: LineEdit = phone.input("Username (3–24 characters)", 24)
        var email: LineEdit = null
        if supabase != null:
            phone.label("Use email and password to sign in. Your username is public; your email is private. Confirm your email before the first sign-in. Username is needed only for new accounts.")
            email = phone.input("Email address", 254)
        var password: LineEdit = phone.input("Password (at least 10 characters)", 128)
        password.secret = true
        for route in ["login", "register"]:
            var endpoint: String = route
            phone.button("Sign in" if route == "login" else "Create account", func():
                if busy: return
                var credentials: Dictionary = {"username": name_field.text.strip_edges().to_lower(), "password": password.text}
                if email != null: credentials["email"] = email.text.strip_edges()
                var reply: Dictionary = await request("/" + endpoint, credentials)
                password.text = ""
                if reply.has("token"):
                    token = reply.token
                    username = reply.username
                    status = "Signed in as @" + username
                else:
                    status = str(reply.get("error", "Unable to sign in"))
                if phone.panel.visible: phone.show_app(target))
        return
    phone.label("@" + username + " · real player account")
    var search: LineEdit = phone.input("Search username", 24)
    phone.button("Find player", func():
        var reply: Dictionary = await request("/users?q=" + search.text.strip_edges().to_lower().uri_encode())
        if not phone.panel.visible: return
        phone.clear()
        phone.label(str(reply.get("error", "Search results")))
        for entry in reply.get("users", []):
            var peer: String = entry.username
            phone.button("@" + peer, func(): conversation(phone, peer)))
    phone.button("Inbox & relationships", func(): inbox(phone))
    phone.label("Players nearby (updates while signed in)")
    for peer in peers:
        var name_value: String = str(peer.username)
        phone.button("@" + name_value, func(): conversation(phone, name_value))
    phone.button("Blocked players", func():
        var reply: Dictionary = await request("/blocks")
        if not phone.panel.visible: return
        phone.clear()
        phone.label(str(reply.get("error", "Your blocked players")))
        for entry in reply.get("users", []):
            var peer: String = entry.username
            phone.button("Unblock @" + peer, func():
                var sent: Dictionary = await request("/unblock", {"to": peer})
                status = str(sent.get("error", "Player unblocked"))
                if phone.panel.visible: phone.show_app("Contacts")))
    phone.button("Sign out", func():
        await request("/logout", {})
        token = ""
        clear_peers()
        if phone.panel.visible: phone.show_app(target))
    phone.button("Account settings", func():
        phone.clear()
        phone.label("Delete your social account, messages and relationships permanently? Local game progress stays on this device.")
        phone.button("Confirm permanent account deletion", func():
            var reply: Dictionary = await request("/account/delete", {})
            if reply.get("ok", false):
                token = ""
                clear_peers()
            status = str(reply.get("error", "Social account deleted"))
            if phone.panel.visible: phone.show_app(target)))

func conversation(phone: CanvasLayer, peer: String) -> void:
    selected = peer
    var reply: Dictionary = await request("/messages?to=" + peer.uri_encode())
    if not phone.panel.visible or selected != peer: return
    phone.clear()
    phone.heading.text = "@" + peer
    phone.label(str(reply.get("error", "Messages · tap Refresh for new replies")))
    history = VBoxContainer.new()
    history.add_theme_constant_override("separation", 10)
    history.custom_minimum_size.y = 150
    history_signature = ""
    phone.body.add_child(history)
    update_history(reply.get("messages", []))
    var draft: LineEdit = phone.input("Message…", 1000)
    phone.button("Send", func():
        if busy or draft.text.strip_edges().is_empty(): return
        var sent: Dictionary = await request("/messages", {"to": peer, "body": draft.text})
        if sent.has("error"):
            if phone.panel.visible: phone.label(str(sent.error))
        elif selected == peer and phone.panel.visible:
            conversation(phone, peer))
    phone.button("Refresh", func(): conversation(phone, peer))
    phone.button("Relationship invitation", func():
        selected = ""
        phone.clear()
        phone.label("Invite @" + peer + ". Their acceptance is required. These are in-game social labels.")
        for relationship in RELATIONS:
            var kind: String = relationship
            phone.button(kind, func():
                var sent: Dictionary = await request("/relationship", {"to": peer, "kind": kind})
                if phone.panel.visible: phone.label(str(sent.get("error", "Invitation sent")))))
    phone.button("Block player", func():
        var sent: Dictionary = await request("/block", {"to": peer})
        status = str(sent.get("error", "Player blocked"))
        if phone.panel.visible: phone.show_app("Contacts"))
    phone.button("Report player", func():
        selected = ""
        phone.clear()
        var reason: LineEdit = phone.input("Explain the issue (5–500 characters)", 500)
        phone.button("Submit report", func():
            var sent: Dictionary = await request("/report", {"to": peer, "reason": reason.text})
            if phone.panel.visible: phone.label(str(sent.get("error", "Report submitted for operator review")))))

func inbox(phone: CanvasLayer) -> void:
    selected = "@inbox"
    var reply: Dictionary = await request("/inbox")
    if not phone.panel.visible or selected != "@inbox": return
    phone.clear()
    phone.label(str(reply.get("error", "Your conversations and invitations")))
    for thread in reply.get("threads", []):
        var peer: String = thread.username
        phone.button("@" + peer, func(): conversation(phone, peer))
    for relation in reply.get("relationships", []):
        var id: int = int(relation.id)
        var incoming: bool = relation.recipient_name == username
        var peer: String = relation.sender_name if incoming else relation.recipient_name
        phone.label("@" + peer + " · " + str(relation.kind) + " · " + str(relation.status))
        if relation.status == "pending" and incoming:
            for value in ["accepted", "declined"]:
                var response: String = value
                phone.button("Accept" if value == "accepted" else "Decline", func():
                    var sent: Dictionary = await request("/relationship/respond", {"id": id, "status": response})
                    if sent.has("error"): status = str(sent.error)
                    inbox(phone))
        phone.button("End / withdraw", func():
            await request("/relationship/respond", {"id": id, "status": "ended"})
            inbox(phone))

func clear_peers() -> void:
    peers.clear()
    for avatar in avatars.values():
        if is_instance_valid(avatar): avatar.queue_free()
    avatars.clear()

func update_history(messages: Array) -> void:
    if not is_instance_valid(history): return
    var signature: String = JSON.stringify(messages)
    if signature == history_signature: return
    history_signature = signature
    for child in history.get_children():
        history.remove_child(child)
        child.queue_free()
    for message in messages:
        var own: bool = message.sender == username
        var row := HBoxContainer.new()
        history.add_child(row)
        var spacer := Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        spacer.size_flags_stretch_ratio = 0.20
        if own: row.add_child(spacer)
        var bubble := PanelContainer.new()
        bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var style := StyleBoxFlat.new()
        style.bg_color = Color("1c655d") if own else Color("2a3b53")
        style.set_corner_radius_all(12)
        style.set_content_margin_all(10)
        bubble.add_theme_stylebox_override("panel", style)
        row.add_child(bubble)
        var text := RichTextLabel.new()
        text.fit_content = true
        text.scroll_active = false
        text.bbcode_enabled = false
        text.text = ("You" if own else "@" + str(message.sender)) + "\n" + str(message.body) + "\n" + Time.get_datetime_string_from_unix_time(int(message.created)).replace("T", " ")
        text.add_theme_font_size_override("normal_font_size", 14)
        bubble.add_child(text)
        if not own: row.add_child(spacer)

func _process(delta: float) -> void:
    if token.is_empty() or busy or game == null or game.player == null or game.profile_data.is_empty(): return
    history_time += delta
    if history_time >= 4 and not selected.is_empty() and not selected.begins_with("@") and game.campus_phone.panel.visible and is_instance_valid(history):
        history_time = 0
        var peer: String = selected
        var chat: Dictionary = await request("/messages?to=" + peer.uri_encode())
        if selected == peer and chat.has("messages"): update_history(chat.messages)
        return
    poll_time += delta
    if poll_time < 3: return
    poll_time = 0
    var position: Vector3 = game.player.global_position
    var location: String = game.social_location()
    var reply: Dictionary = await request("/presence", {"location": location, "x": position.x, "y": position.y, "z": position.z, "yaw": game.player.rotation.y})
    if reply.has("error"):
        clear_peers()
        return
    # Discard an old response if the player changed room while it was in flight.
    if location != game.social_location():
        clear_peers()
        return
    peers = reply.get("peers", [])
    var found: Array = []
    for entry in peers:
        var key: String = str(entry.username)
        found.append(key)
        if not avatars.has(key):
            var avatar := Node3D.new()
            avatar.name = "OnlineStudent"
            var mesh := MeshInstance3D.new()
            var capsule := CapsuleMesh.new()
            capsule.radius = 0.3
            capsule.height = 1.7
            mesh.mesh = capsule
            mesh.position.y = 0.85
            var mat := StandardMaterial3D.new()
            mat.albedo_color = Color("4cacaa")
            mesh.material_override = mat
            avatar.add_child(mesh)
            var caption := Label3D.new()
            caption.text = "@" + key
            caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
            caption.position.y = 2.1
            caption.font_size = 36
            avatar.add_child(caption)
            game.add_child(avatar)
            avatar.set_meta("username", key)
            avatar.add_to_group("online_students")
            avatars[key] = avatar
        var node: Node3D = avatars[key]
        node.global_position = Vector3(float(entry.x), float(entry.y), float(entry.z))
        node.rotation.y = float(entry.yaw)
    for key in avatars.keys():
        if not found.has(key):
            avatars[key].queue_free()
            avatars.erase(key)
