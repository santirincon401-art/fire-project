extends CanvasLayer
## Victory overlay shown when the boss is defeated. Guards against firing twice,
## pauses the world, and offers a return to the dungeon or to quit.

@onready var root: Control = get_node_or_null("Root")
@onready var volver: Button = get_node_or_null("Root/Center/Menu/Volver")
@onready var salir: Button = get_node_or_null("Root/Center/Menu/Salir")

var _showing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("victory_screen")
	if root != null:
		root.visible = false
	if volver != null:
		volver.pressed.connect(_on_volver)
	if salir != null:
		salir.pressed.connect(_on_salir)


func is_showing() -> bool:
	return _showing


func show_victory() -> void:
	if _showing:
		return
	_showing = true
	if root != null:
		root.visible = true
	get_tree().paused = true
	if volver != null:
		volver.grab_focus()


func _on_volver() -> void:
	_showing = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_salir() -> void:
	get_tree().quit()