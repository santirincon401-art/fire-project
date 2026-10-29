extends CanvasLayer
## Menú Principal del juego.
##
## Arranca abierto al iniciar el juego. Al presionar "Jugar", oculta el menú
## y permite que comience la partida.

@onready var _root: Control = get_node_or_null("Root")
@onready var _main_menu: Control = get_node_or_null("Root/MainMenu")
@onready var _settings_menu: Control = get_node_or_null("Root/SettingsMenu")
@onready var _jugar: Button = get_node_or_null("Root/MainMenu/Menu/Jugar")
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("main_menu")
	
	# El menú principal siempre arranca visible al iniciar el juego
	if _root != null:
		_root.visible = true
	_show_main()
	
	if _jugar != null:
		_jugar.pressed.connect(_iniciar_juego)
		_jugar.grab_focus()
	else:
		print("¡Aviso: No se encontró el botón Jugar en la ruta especificada!")
		
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
	# Si estás en los ajustes y presionas Escape, vuelve al menú principal en vez de salir
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if _settings_menu != null and _settings_menu.visible:
			_show_main()
			get_viewport().set_input_as_handled()


func _iniciar_juego() -> void:
	Sonidos.play("seleccion")
	# Oculta el menú principal para comenzar a jugar
	if _root != null:
		_root.visible = false
	get_tree().change_scene_to_file("res://selector_personajes.tscn")
	
	# Opcional: Si quieres cambiar de escena en lugar de solo ocultar el menú,
	# puedes descomentar la línea de abajo y poner la ruta de tu nivel:
	# get_tree().change_scene_to_file("res://escenas/nivel_1.tscn")


func _show_main() -> void:
	if _main_menu != null:
		_main_menu.visible = true
	if _settings_menu != null:
		_settings_menu.visible = false
	if _jugar != null:
		_jugar.grab_focus()


func _show_settings() -> void:
	Sonidos.play("seleccion")
	if _main_menu != null:
		_main_menu.visible = false
	if _settings_menu != null:
		_settings_menu.visible = true
	if _back != null:
		_back.grab_focus()


func _on_quit() -> void:
	Sonidos.play("seleccion")
	get_tree().quit()


# ==================================================
# SECCIÓN DE FUNCIONES DE AJUSTES FALTANTES
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
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(valor, 0.0001)))


func _on_fullscreen_toggled(activado: bool) -> void:
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
	# 1. Fuerza el cambio en la ventana principal del árbol
	var ventana := get_window()
	if ventana != null:
		ventana.mode = Window.MODE_WINDOWED
		ventana.size = tamano
	
	# 2. Respalda con el DisplayServer
	DisplayServer.window_set_size(tamano)
	
	# 3. Centra la ventana en pantalla
	var pantalla := DisplayServer.window_get_current_screen()
	var centro := (
		DisplayServer.screen_get_position(pantalla)
		+ (DisplayServer.screen_get_size(pantalla) - tamano) / 2
	)
	DisplayServer.window_set_position(centro)
