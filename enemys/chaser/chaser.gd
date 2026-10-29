extends "res://enemys/common/enemy_base.gd"
## Melee brawler. Walks straight at the player and swings when it gets close.
## It winds up for a moment first, so the hit can be read and walked out of.

@export var tiempo_aviso: float = 0.32

enum Estado { ACERCARSE, PREPARAR, RECUPERAR }

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
				# Only connects if the player is still in reach after the wind-up.
				if distancia <= distancia_ataque + 16.0:
					_damage_player()
				_estado = Estado.RECUPERAR
				_t = tiempo_entre_ataques
		Estado.RECUPERAR:
			velocity = Vector2.ZERO
			_t -= delta
			if _t <= 0.0:
				_estado = Estado.ACERCARSE


func _telegraph() -> void:
	var target: Node = sprite if sprite else placeholder
	if target == null or not (target is CanvasItem):
		return
	var tw := create_tween()
	(target as CanvasItem).modulate = Color(1.8, 0.7, 0.5)
	tw.tween_property(target, "modulate", Color.WHITE, tiempo_aviso)
