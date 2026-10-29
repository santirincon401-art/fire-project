extends CanvasLayer
## Escape pause menu.
##
## Opening it pauses the gameplay world (enemies, projectiles, timers) with
## get_tree().paused = true, while this CanvasLayer keeps processing
## (process_mode = ALWAYS) so its own UI stays interactive. Pressing Escape again
## resumes. Opening Settings shows the volume / fullscreen / resolution options.
##
## It refuses to open while the death screen is up, so Escape can never pause
## over a game-over and can never quit the game by itself.

@onready var _root: Control = get_node_or_null("Root")
@onready var _main_menu: Control = get_node_or_null("Root/MainMenu")
@onready var _settings_menu: Control = get_node_or_null("Root/SettingsMenu")
@onready var _resume: Button = get_node_or_null("Root/MainMenu/Menu/Resume")
@onready var _settings_button: Button = get_node_or_null("Root/MainMenu/Menu/SettingsButton")
@onready var _quit: Button = get_node_or_null("Root/MainMenu/Menu/Quit")
@onready var _volume: HSlider = get_node_or_null("Root/SettingsMenu/Menu/VolRow/VolumeSlider")
@onready var _fullscreen: CheckButton = get_node_or_null("Root/SettingsMenu/Menu/Fullscreen")
@onready var _resolution: OptionButton = get_node_or_null("Root/SettingsMenu/Menu/ResRow/Resolution")
@onready var _back: Button = get_node_or_null("Root/SettingsMenu/Menu/Back")

const RESOLUCIONES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

var _abierto: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	if _root != null:
		_root.visible = false
	if _resume != null:
		_resume.pressed.connect(_resume_game)
	if _settings_button != null:
		_settings_button.pressed.connect(_show_settings)
	if _quit != null:
		_quit.pressed.connect(_on_quit)
	if _back != null:
		_back.pressed.connect(_show_main)
	if _volume != null:
		_volume.value_changed.connect(_on_volume_changed)
	if _fullscreen != null:
		_fullscreen.toggled.connect(_on_fullscreen_toggled)
	if _resolution != null:
		_resolution.item_selected.connect(_on_resolution_selected)
	_inicializar_ajustes()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _death_showing():
		return
	if _settings_menu != null and _settings_menu.visible:
		_show_main()
	else:
		_toggle()
	get_viewport().set_input_as_handled()


func _toggle() -> void:
	if _abierto:
		_resume_game()
	else:
		_pause_game()


func _pause_game() -> void:
	_abierto = true
	if _root != null:
		_root.visible = true
	_show_main()
	get_tree().paused = true
	if _resume != null:
		_resume.grab_focus()


func _resume_game() -> void:
	_abierto = false
	if _root != null:
		_root.visible = false
	get_tree().paused = false


func _show_main() -> void:
	if _main_menu != null:
		_main_menu.visible = true
	if _settings_menu != null:
		_settings_menu.visible = false


func _show_settings() -> void:
	if _main_menu != null:
		_main_menu.visible = false
	if _settings_menu != null:
		_settings_menu.visible = true
	if _back != null:
		_back.grab_focus()


func _on_quit() -> void:
	get_tree().quit()


func _death_showing() -> bool:
	for nodo in get_tree().get_nodes_in_group("death_screen"):
		if nodo.has_method("is_showing") and bool(nodo.call("is_showing")):
			return true
	return false


# ==================================================
# AJUSTES
# ==================================================

func _inicializar_ajustes() -> void:
	if _volume != null:
		_volume.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(0)))
	if _fullscreen != null:
		_fullscreen.set_pressed_no_signal(_es_pantalla_completa())
	if _resolution != null:
		_resolution.clear()
		for i in RESOLUCIONES.size():
			var tamano: Vector2i = RESOLUCIONES[i]
			_resolution.add_item("%d x %d" % [tamano.x, tamano.y])
		var actual := DisplayServer.window_get_size()
		for i in RESOLUCIONES.size():
			if RESOLUCIONES[i] == actual:
				_resolution.select(i)
				break


func _on_volume_changed(valor: float) -> void:
	# Evita el -inf dB de un volumen 0.
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(valor, 0.0001)))


func _on_fullscreen_toggled(activado: bool) -> void:
	# Toggle live, no restart. The stretch aspect is "keep", so both windowed and
	# fullscreen letterbox instead of stretching the game.
	if activado:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_aplicar_resolucion(_resolucion_seleccionada())
	_sincronizar_fullscreen()


func _on_resolution_selected(indice: int) -> void:
	if indice < 0 or indice >= RESOLUCIONES.size():
		return
	if not _es_pantalla_completa():
		# Resolution only makes sense in windowed mode; drop out of fullscreen.
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN \
				or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			_sincronizar_fullscreen()
	_aplicar_resolucion(RESOLUCIONES[indice])
	_resolution.select(indice)


func _es_pantalla_completa() -> bool:
	var modo := DisplayServer.window_get_mode()
	return (
		modo == DisplayServer.WINDOW_MODE_FULLSCREEN
		or modo == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)


func _sincronizar_fullscreen() -> void:
	if _fullscreen != null:
		_fullscreen.set_pressed_no_signal(_es_pantalla_completa())


func _resolucion_seleccionada() -> Vector2i:
	if _resolution != null:
		var idx := _resolution.selected
		if idx >= 0 and idx < RESOLUCIONES.size():
			return RESOLUCIONES[idx]
	return Vector2i(1152, 648)


func _aplicar_resolucion(tamano: Vector2i) -> void:
	DisplayServer.window_set_size(tamano)
	var pantalla := DisplayServer.window_get_current_screen()
	var centro := (
		DisplayServer.screen_get_position(pantalla)
		+ (DisplayServer.screen_get_size(pantalla) - tamano) / 2
	)
	DisplayServer.window_set_position(centro)