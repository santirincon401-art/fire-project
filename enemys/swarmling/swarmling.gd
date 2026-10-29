extends "res://enemys/common/enemy_base.gd"
## Fast, fragile pest. Rushes the player and scratches on a short cycle with no
## wind-up. Very low health and light damage so several can be fought at once,
## which pressures the player without being unfair.

var _t: float = 0.0


func _enemy_process(delta: float) -> void:
	var direccion := _direction_to_player()
	var distancia := _distance_to_player()
	_face(direccion.x)

	# Pests never stop chasing.
	velocity = direccion * velocidad
	_play(anim_walk)

	if distancia <= distancia_ataque:
		_t -= delta
		if _t <= 0.0:
			_damage_player()
			_t = tiempo_entre_ataques
	else:
		_t = 0.0