extends CanvasLayer
## Full-screen death overlay for the whole run.
##
## It listens to the player controller's `murio` signal, then:
##  - freezes the gameplay world (get_tree().paused = true), so enemies and
##    projectiles stop attacking while the overlay is up,
##  - shows "YOU DIED" with Retry / Quit Game,
##  - guards against being raised more than once.
## process_mode is ALWAYS so its buttons keep working while the tree is paused.

@onready var _root: Control = get_node_or_null("Root")
@onready var _retry: Button = get_node_or_null("Root/Center/Menu/Retry")
@onready var _quit: Button = get_node_or_null("Root/Center/Menu/Quit")

var _showing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("death_screen")
	if _root != null:
		_root.visible = false
	if _retry != null:
		_retry.pressed.connect(_on_retry)
	if _quit != null:
		_quit.pressed.connect(_on_quit)
	call_deferred("_connect_player")


## Connects to the player's death signal. Deferred so the rest of the scene
## (including the player) has finished entering the tree.
func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group("jugador")
	if player == null:
		return
	var controlador: Node = player.get_node_or_null("controlador")
	if controlador == null:
		return
	var callable := Callable(self, "_on_player_died")
	if controlador.has_signal("murio") and not controlador.is_connected("murio", callable):
		controlador.connect("murio", callable)


func is_showing() -> bool:
	return _showing


func show_death() -> void:
	if _showing:
		return
	_showing = true
	if _root != null:
		_root.visible = true
	get_tree().paused = true
	if _retry != null:
		_retry.grab_focus()


func _on_player_died() -> void:
	show_death()


func _on_retry() -> void:
	_showing = false
	# Unpause before reloading so the freshly loaded level starts running.
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit() -> void:
	get_tree().quit()