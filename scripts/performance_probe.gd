extends Node
# Opt-in telemetry; never writes saves or changes gameplay.
var elapsed: float = 0.0
var scenario_time: float = 0.0
var stage: String = "building"
var last_tick: int = 0
var benchmarking: bool = false
var started: bool = false
var origin: Vector3
var origin_rotation: Vector3
var frames: int = 0
var longest_ms: float = 0.0

func _ready() -> void:
    set_process(OS.has_feature("web") and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('profile')")))

    if OS.has_feature("web"):
        benchmarking = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('benchmark') === '1'"))

func _process(_delta: float) -> void:
    var now: int = Time.get_ticks_usec()
    if last_tick == 0:
        last_tick = now
        return
    var delta: float = (now - last_tick) / 1000000.0
    last_tick = now
    if benchmarking: _scenario(delta)
    elapsed += delta
    frames += 1
    longest_ms = maxf(longest_ms, delta * 1000.0)
    if elapsed < 1.0: return
    var sample: Dictionary = {
        "stage": stage,
        "fps": frames / elapsed,
        "max_frame_ms": longest_ms,
        "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
        "video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
        "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC) if OS.is_debug_build() else null,
        "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
    }
    JavaScriptBridge.eval("window.lasuPerfSamples=window.lasuPerfSamples||[];window.lasuPerfSamples.push(Object.assign({at:performance.now()}," + JSON.stringify(sample) + "));if(window.lasuPerfSamples.length>600)window.lasuPerfSamples.shift();")
    frames = 0
    elapsed = 0.0
    longest_ms = 0.0

func _scenario(delta: float) -> void:
    var game: Node = get_parent()
    if not game.architecture_queue.is_empty(): return
    if not started:
        # This is only used in an isolated benchmark browser context.
        if not game.profile_data.is_empty():
            benchmarking = false
            JavaScriptBridge.eval("window.lasuBenchmarkError='Use an empty browser context; existing save will not be modified';")
            return
        game.profile_name_input.text = "Performance benchmark"
        game._create_student_profile()
        game.update_setting("quality", "medium")
        origin = game.player.global_position
        origin_rotation = game.player.rotation
        started = true
        elapsed = 0.0
        frames = 0
    scenario_time += delta
    if scenario_time < 10.0:
        stage = "campus_idle"
    elif scenario_time < 25.0:
        stage = "campus_walk"
        game.player.touch_movement = Vector2(0, -1)
        game.player.look(Vector2(16.0 * delta, 0))
    elif scenario_time < 35.0:
        if stage != "phone":
            game.player.touch_movement = Vector2.ZERO
            game.campus_phone.open()
        stage = "phone"
    elif scenario_time < 50.0:
        if stage != "interior":
            game.campus_phone.close()
            var names: Array = game.interior_catalog.keys()
            names.sort()
            game._enter_interior(str(names[0]))
            game.task_panel.visible = false
        stage = "interior"
    elif benchmarking:
        game._leave_interior()
        game.player.global_position = origin
        game.player.rotation = origin_rotation
        benchmarking = false
        JavaScriptBridge.eval("window.lasuBenchmarkDone=true")
