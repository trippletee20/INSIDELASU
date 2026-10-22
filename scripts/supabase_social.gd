extends RefCounted
## Supabase Auth + tightly scoped RPC. Publishable key is public, never privileged.
var url: String = ""
var publishable_key: String = ""
var refresh_token: String = ""
var expires_at: int = 0
var ready: bool = false
const CALLBACK_URL: String = "https://trippletee20.github.io/INSIDELASU/auth/callback.html"

func wire(client: Node, path: String, payload: Dictionary, authenticated: bool = false) -> Dictionary:
    var http := HTTPRequest.new()
    http.timeout = 15
    client.add_child(http)
    var headers := PackedStringArray(["Content-Type: application/json", "apikey: " + publishable_key])
    if authenticated and not client.token.is_empty():
        headers.append("Authorization: Bearer " + client.token)
    var error: Error = http.request(url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
    if error != OK:
        http.queue_free()
        return {"error": "Could not reach campus accounts. Try again."}
    var result: Array = await http.request_completed
    http.queue_free()
    if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
        return {"error": "Campus accounts are unavailable. Your local game still works."}
    var code: int = int(result[1])
    var raw: String = result[3].get_string_from_utf8()
    if raw.is_empty() and code >= 200 and code < 300:
        return {"ok": true}
    var value: Variant = JSON.parse_string(raw)
    if not value is Dictionary:
        return {"error": "Campus accounts returned an invalid response"}
    if code >= 400:
        return {"error": str(value.get("msg", value.get("error_description", value.get("message", "Request failed. Please try again."))))}
    return value

func keep_session(client: Node, response: Dictionary) -> void:
    client.token = str(response.get("access_token", ""))
    refresh_token = str(response.get("refresh_token", ""))
    expires_at = int(Time.get_unix_time_from_system()) + int(response.get("expires_in", 3600))
    if OS.has_feature("web"):
        var saved: Dictionary = {"access_token": client.token, "refresh_token": refresh_token, "expires_at": expires_at, "username": client.username}
        JavaScriptBridge.eval("sessionStorage.setItem('lasu.social.session', " + JSON.stringify(JSON.stringify(saved)) + ")")

func clear_session(client: Node) -> void:
    client.token = ""
    refresh_token = ""
    expires_at = 0
    client.clear_peers()
    if OS.has_feature("web"):
        JavaScriptBridge.eval("sessionStorage.removeItem('lasu.social.session')")

func request(client: Node, path: String, data: Variant) -> Dictionary:
    if client.busy:
        return {"error": "Please wait for the current request"}
    client.busy = true
    var reply: Dictionary = await perform(client, path, data)
    client.busy = false
    return reply

func perform(client: Node, path: String, data: Variant) -> Dictionary:
    if not ready:
        var health: Dictionary = await wire(client, "/rest/v1/rpc/lasu_health", {})
        if health.get("service", "") != "Inside LASU Supabase social" or int(health.get("version", 0)) != 1:
            return {"error": "Campus accounts are being set up. Your local game, notes and tasks still work."}
        ready = true
    if path in ["/login", "/register"]:
        var email: String = str(data.get("email", "")).strip_edges()
        var password: String = str(data.get("password", ""))
        var name_value: String = str(data.get("username", "")).strip_edges().to_lower()
        if not email.contains("@") or password.length() < 10:
            return {"error": "Enter your email and a password of at least 10 characters"}
        var credentials: Dictionary = {"email": email, "password": password}
        if path == "/register":
            var username_rule := RegEx.new()
            username_rule.compile("^[a-z][a-z0-9_]{2,23}$")
            if username_rule.search(name_value) == null:
                return {"error": "Choose a username: 3–24 letters, numbers or underscores; start with a letter"}
            credentials["data"] = {"username": name_value}
        var auth: Dictionary = await wire(client, "/auth/v1/signup?redirect_to=" + CALLBACK_URL.uri_encode() if path == "/register" else "/auth/v1/token?grant_type=password", credentials)
        if auth.has("error"): return auth
        if not auth.has("access_token"):
            return {"error": "Check your email to confirm your account, then return here and sign in. If nothing arrives, check spam or try again later."}
        keep_session(client, auth)
        if name_value.is_empty():
            name_value = str(auth.get("user", {}).get("user_metadata", {}).get("username", ""))
        var profile: Dictionary = await wire(client, "/rest/v1/rpc/lasu_api", {"route": "/profile", "payload": {"username": name_value}}, true)
        if profile.has("error"):
            await wire(client, "/auth/v1/logout", {}, true)
            clear_session(client)
            return profile
        return {"token": client.token, "username": str(profile.get("username", ""))}
    if client.token.is_empty(): return {"error": "Sign in to your social account"}
    if int(Time.get_unix_time_from_system()) >= expires_at - 60:
        var refreshed: Dictionary = await wire(client, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh_token})
        if not refreshed.has("access_token"):
            clear_session(client)
            return {"error": "Session expired. Sign in again."}
        keep_session(client, refreshed)
    if path == "/logout":
        await wire(client, "/rest/v1/rpc/lasu_api", {"route": "/presence", "payload": {"location": "private:offline"}}, true)
        var signed_out: Dictionary = await wire(client, "/auth/v1/logout", {}, true)
        clear_session(client)
        return signed_out
    var route: String = path.get_slice("?", 0)
    var payload: Dictionary = {} if data == null else data.duplicate(true)
    if path.contains("?"):
        for part in path.get_slice("?", 1).split("&"):
            if part.contains("="):
                payload[part.get_slice("=", 0)] = part.get_slice("=", 1).uri_decode()
    if route == "/messages": route = "/messages/read" if data == null else "/messages/send"
    var response: Dictionary = await wire(client, "/rest/v1/rpc/lasu_api", {"route": route, "payload": payload}, true)
    if path == "/account/delete" and response.get("ok", false):
        clear_session(client)
    return response

func import_browser_session(client: Node) -> void:
    if not OS.has_feature("web"): return
    var raw: Variant = JavaScriptBridge.eval("sessionStorage.getItem('lasu.social.session') || ''")
    if not raw is String or str(raw).is_empty(): return
    var value: Variant = JSON.parse_string(str(raw))
    if not value is Dictionary or not value.get("access_token", "") is String or not value.get("refresh_token", "") is String: return
    if str(value.get("access_token", "")).is_empty() or str(value.get("refresh_token", "")).is_empty(): return
    client.token = str(value.access_token)
    refresh_token = str(value.refresh_token)
    expires_at = int(value.get("expires_at", 0))
    var response: Dictionary = await request(client, "/profile", {})
    if response.has("username"):
        client.username = str(response.username)
        client.status = "Signed in as @" + client.username
    else:
        client.token = ""
        client.status = str(response.get("error", "Reconnect to your campus account"))
