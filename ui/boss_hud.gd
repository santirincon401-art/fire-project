extends CanvasLayer
## Boss name + health bar at the top of the arena, plus the intro/warning line.
## process_mode is ALWAYS so the bar keeps drawing while the game is paused.

@onready var name_label: Label = get_node_or_null("Root/TopBar/Name")
@onready var bar: ProgressBar = get_node_or_null("Root/TopBar/Health")
@onready var intro: Label = get_node_or_null("Root/Intro")

var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("boss_hud")
	if intro != null:
		intro.modulate.a = 0.0


func configurar(nombre: String, maxima: int) -> void:
	if name_label != null:
		name_label.text = nombre
	if bar != null:
		bar.max_value = maxi(maxima, 1)
		bar.value = maxima


func set_vida(valor: int, maxima: int) -> void:
	if bar == null:
		return
	bar.max_value = maxi(maxima, 1)
	bar.value = valor


func mostrar_intro(texto: String) -> void:
	_mostrar(texto, 2.4)


## Alias so `call_group("boss_hud", "show_message", ...)` works for phase lines.
func show_message(texto: String) -> void:
	_mostrar(texto, 1.8)


func _mostrar(texto: String, espera: float) -> void:
	if intro == null:
		return
	intro.text = texto
	intro.modulate.a = 1.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(espera)
	_tween.tween_property(intro, "modulate:a", 0.0, 0.7)