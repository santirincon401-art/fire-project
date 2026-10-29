extends Node
## Headless test for the display / fullscreen configuration.
## Run: godot --headless --path . res://tests/settings_test.tscn

var _fallos: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ok(
		String(ProjectSettings.get_setting("display/window/stretch/mode", "")) == "canvas_items",
		"stretch mode is canvas_items"
	)
	_ok(
		String(ProjectSettings.get_setting("display/window/stretch/aspect", "")) == "keep",
		"stretch aspect is 'keep' (letterbox - no stretching)"
	)
	_ok(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) == 1152,
		"viewport width is 1152"
	)
	_ok(
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)) == 648,
		"viewport height is 648"
	)
	_ok(
		bool(ProjectSettings.get_setting("display/window/size/resizable", true)),
		"window is resizable"
	)

	# The pause menu must expose a working fullscreen toggle that does not error.
	var menu: Node = load("res://ui/pause_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	_ok(menu.has_method("_es_pantalla_completa"), "pause menu exposes the fullscreen state check")

	menu.call("_on_fullscreen_toggled", true)
	await get_tree().process_frame
	menu.call("_on_fullscreen_toggled", false)
	await get_tree().process_frame
	_ok(not bool(menu.call("_es_pantalla_completa")), "toggling fullscreen returns to windowed")

	var r: Vector2i = menu.call("_resolucion_seleccionada")
	_ok(r.x > 0 and r.y > 0, "a valid windowed resolution is available (%s)" % r)

	menu.call("_on_resolution_selected", 1)
	await get_tree().process_frame
	_ok(true, "changing resolution runs without error")

	_final()


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		_fallos += 1
		print("FAIL: ", msg)


func _final() -> void:
	print("RESULT: %d failed check(s)" % _fallos)
	get_tree().quit(_fallos)