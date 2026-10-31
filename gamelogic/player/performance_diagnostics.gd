extends CanvasLayer
## Скрытая диагностика браузерной сборки. F3 — панель, F6/F7 — сравнение эффектов.
var _label: Label
var _panel: PanelContainer
var _elapsed := 0.0
var _frames := 0
var _shadows_disabled := false
var _shadow_lights: Array[WeakRef] = []

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
	_panel.hide()
	set_process(false)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_F3:
		_panel.visible = not _panel.visible
		_elapsed = 0.0
		_frames = 0
		set_process(_panel.visible)
		if _panel.visible:
			_refresh(0.0, 0.0)
		get_viewport().set_input_as_handled()
	elif _panel.visible and event.physical_keycode == KEY_F6:
		var cutout := get_parent().get_node_or_null("WallCutout")
		if cutout:
			cutout.enabled = not cutout.enabled
		get_viewport().set_input_as_handled()
	elif _panel.visible and event.physical_keycode == KEY_F7:
		_toggle_shadows()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_elapsed += delta
	_frames += 1
	if _elapsed < 0.5:
		return
	_refresh(float(_frames) / _elapsed, _elapsed * 1000.0 / float(_frames))
	_elapsed = 0.0
	_frames = 0

func _refresh(fps: float, frame_ms: float) -> void:
	var cutout := get_parent().get_node_or_null("WallCutout")
	var cutout_enabled: bool = cutout.enabled if cutout else false
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_label.text = "F3: diagnostics\nFPS: %.1f | frame: %.1f ms\nProcess: %.2f ms | physics: %.2f ms\nDraw calls: %d | primitives: %d\nF6 cutout: %s | F7 shadows: %s" % [fps, frame_ms, process_ms, physics_ms, draws, primitives, "ON" if cutout_enabled else "OFF", "OFF" if _shadows_disabled else "ON"]

func _toggle_shadows() -> void:
	if _shadows_disabled:
		_restore_shadows()
		return
	_shadow_lights.clear()
	for light in get_tree().current_scene.find_children("*", "Light3D", true, false):
		if light.shadow_enabled:
			_shadow_lights.append(weakref(light))
			light.shadow_enabled = false
	_shadows_disabled = true

func _restore_shadows() -> void:
	for reference in _shadow_lights:
		var light = reference.get_ref()
		if is_instance_valid(light):
			light.shadow_enabled = true
	_shadow_lights.clear()
	_shadows_disabled = false

func _exit_tree() -> void:
	_restore_shadows()
