extends CanvasLayer
## Player HUD. The Health and Energy bars are driven directly by controlador.gd;
## this script only owns the transient message banner (item pickups, item uses,
## not-enough-Energy warnings, ...). It joins the "hud" group so any system can
## call get_tree().call_group("hud", "show_message", "text").

@onready var label: Label = get_node_or_null("Mensaje")

var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	if label != null:
		label.modulate.a = 0.0


func show_message(text: String) -> void:
	if label == null:
		return
	label.text = text
	label.modulate.a = 1.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(2.2)
	_tween.tween_property(label, "modulate:a", 0.0, 0.6)
