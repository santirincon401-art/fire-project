extends Control

# Referencias directas a los botones según tu árbol de nodos
@onready var btn_candle: Button = $Panel/Candle/Botoncandle
@onready var btn_angryle: Button = $Panel/Angryle/Button2
@onready var btn_speedle: Button = $Panel/Speedle/Button3


func _ready() -> void:
	# Conectamos cada botón a su respectiva función de selección
	if btn_candle != null:
		btn_candle.pressed.connect(func(): _elegir_personaje(0))
	if btn_angryle != null:
		btn_angryle.pressed.connect(func(): _elegir_personaje(1))

	if btn_speedle != null:
		btn_speedle.pressed.connect(func(): _elegir_personaje(2))

	# Dar foco inicial al primer botón
	if btn_candle != null:
		btn_candle.grab_focus()
		





func _elegir_personaje(id: int) -> void:
	# Guarda la elección en el Autoload Global
	GlobalVariables.personaje_elegido = id
	print("¡Personaje seleccionado con ID: ", id, "!")
	Sonidos.play("seleccion")
	# Cambia a la escena de tu nivel (Ajusta la ruta si tu nivel se llama diferente)
	get_tree().change_scene_to_file("res://scenes/main.tscn")
