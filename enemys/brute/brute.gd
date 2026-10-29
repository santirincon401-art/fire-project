extends "res://enemys/common/enemy_base.gd"
## Slow, heavy hitter. Lumbers toward the player and performs a long-telegraphed
## ground slam that damages in a radius around itself. High health and high
## damage, but slow enough that the telegraph leaves plenty of room to escape.

@export var tiempo_aviso: float = 0.65
@export var radio_golpe: float = 78.0
@export var duracion_recuperacion: float = 0.5

enum Estado { ACERCARSE, PREPARAR, RECUPERAR, ESPERAR }

var _estado: Estado = Estado.ACERCARSE
var _t: float = 0.0


func _enemy_process(delta: float) -> void:
	var direccion := _direction_to_player()
	var distancia := _distance_to_player()
	_face(direccion.x)

	match _estado:
		Estado.ACERCARSE:
			if distancia <= distancia_ataque:
				_estado = Estado.PREPARAR
				_t = tiempo_aviso
				_play(anim_attack)
				_telegraph()
				velocity = Vector2.ZERO
			else:
				velocity = direccion * velocidad
				_play(anim_walk)
		Estado.PREPARAR:
			velocity = Vector2.ZERO
			_t -= delta
			if _t <= 0.0:
				_golpear()
				_estado = Estado.RECUPERAR
				_t = duracion_recuperacion
		Estado.RECUPERAR:
			velocity = Vector2.ZERO
			_t -= delta
			if _t <= 0.0:
				_estado = Estado.ESPERAR
				_t = tiempo_entre_ataques
		Estado.ESPERAR:
			velocity = direccion * (velocidad * 0.5)
			_t -= delta
			if _t <= 0.0:
				_estado = Estado.ACERCARSE


## The slam only connects if the player is inside the (larger) slam radius, so
## stepping back during the wind-up is a real counter-play.
func _golpear() -> void:
	if _distance_to_player() <= radio_golpe:
		_damage_player()
	_slam_effect()


func _slam_effect() -> void:
	var target: Node = placeholder if placeholder else sprite
	if target == null or not (target is CanvasItem):
		return
	var item := target as CanvasItem
	var base_scale: Vector2 = item.scale
	var tw := create_tween()
	item.modulate = Color(1.6, 0.4, 0.4)
	tw.tween_property(item, "scale", base_scale * 1.35, 0.08)
	tw.tween_property(item, "scale", base_scale, 0.22)
	tw.parallel().tween_property(item, "modulate", Color.WHITE, 0.3)


func _telegraph() -> void:
	var target: Node = placeholder if placeholder else sprite
	if target == null or not (target is CanvasItem):
		return
	var item := target as CanvasItem
	var tw := create_tween()
	item.modulate = Color(2.0, 0.9, 0.3)
	tw.tween_property(item, "modulate", Color.WHITE, tiempo_aviso)