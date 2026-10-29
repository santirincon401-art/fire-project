extends Node
## Live (non-headless) test: actually toggles fullscreen and checks the runtime
## stretch configuration. Run WITHOUT --headless:
##   godot --path . res://tests/fullscreen_live.tscn

var _fallos: int = 0


func _ready() -> void:
	await get_tree().process_frame

	var win := get_window()
	_ok(
		win.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS,
		"runtime stretch mode is canvas_items"
	)
	_ok(
		win.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP,
		"runtime stretch aspect is KEEP (letterbox, no distortion)"
	)

	var menu: Node = load("res://ui/pause_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame

	menu.call("_on_fullscreen_toggled", true)
	await _esperar(8)
	var modo_fs := DisplayServer.window_get_mode()
	print("mode after enable: ", modo_fs, " size=", DisplayServer.window_get_size())
	_ok(
		modo_fs == DisplayServer.WINDOW_MODE_FULLSCREEN
		or modo_fs == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
		"fullscreen engaged without restarting"
	)

	menu.call("_on_fullscreen_toggled", false)
	await _esperar(8)
	var modo_w := DisplayServer.window_get_mode()
	print("mode after disable: ", modo_w, " size=", DisplayServer.window_get_size())
	_ok(modo_w == DisplayServer.WINDOW_MODE_WINDOWED, "returned to windowed without restarting")
	_ok(not bool(menu.call("_es_pantalla_completa")), "fullscreen checkbox state is in sync")

	# Maximized mode: the stretch aspect must stay KEEP so nothing distorts.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	await _esperar(8)
	print("mode maximized: ", DisplayServer.window_get_mode(), " size=", DisplayServer.window_get_size())
	_ok(
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED,
		"window maximizes"
	)
	_ok(
		get_window().content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP,
		"stretch aspect stays KEEP when maximized"
	)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await _esperar(4)

	_final()


func _esperar(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		_fallos += 1
		print("FAIL: ", msg)


func _final() -> void:
	print("RESULT: %d failed check(s)" % _fallos)
	get_tree().quit(_fallos)