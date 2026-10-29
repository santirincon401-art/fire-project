class_name EnemyBase
extends CharacterBody2D
## Shared behaviour for the melee, swarm and brute enemies: health, damage,
## hit-flash, death handling, player targeting, contact/melee damage and the
## sprite <-> placeholder swap.
##
## It joins the existing "enemigos" group and exposes `recibir_danio()`, so the
## player's hitboxes (controlador.gd) and area items (fire_bomb.gd) work with it
## unchanged - no duplicated damage plumbing.
##
## Subclasses override `_enemy_process(delta)` and drive `velocity`; the base
## runs move_and_slide() and handles death. Every sprite animation is optional:
## when a named animation is missing the placeholder shapes are shown instead, so
## a scene works before its art exists and adding a SpriteFrames later just works.

@export_category("Estadísticas Base")
@export var vida_maxima: int = 6
## Damage dealt to the player by a contact/melee attack.
@export var danio: int = 10
@export var velocidad: float = 90.0
@export var distancia_ataque: float = 44.0
@export var tiempo_entre_ataques: float = 1.0

@export_category("Animaciones (opcionales)")
@export var anim_idle: StringName = &"idle"
@export var anim_walk: StringName = &"walk"
@export var anim_attack: StringName = &"attack"
@export var anim_hurt: StringName = &"hurt"
@export var anim_cast: StringName = &"cast"
@export var anim_death: StringName = &"death"

## How long the hurt animation holds before movement animations resume.
@export var duracion_hurt: float = 0.18

## Seconds the death pose stays on screen before the node frees itself.
@export var duracion_muerte: float = 0.8

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var placeholder: Node2D = get_node_or_null("Placeholder")

var vida: int = 0
var jugador: Node2D
var muerto: bool = false
## Time left on the hurt pose; blocks walk/idle from overriding it.
var _hurt_time: float = 0.0


func _ready() -> void:
	add_to_group("enemigos")
	vida = vida_maxima
	jugador = get_tree().get_first_node_in_group("jugador")
	_play(anim_idle)


func _physics_process(delta: float) -> void:
	if muerto:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _hurt_time > 0.0:
		_hurt_time = maxf(_hurt_time - delta, 0.0)

	if not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("jugador")
		if not is_instance_valid(jugador):
			velocity = Vector2.ZERO
			move_and_slide()
			_play(anim_idle)
			return

	_enemy_process(delta)
	move_and_slide()


## Override in subclasses. Drive `velocity` and call _play() / _damage_player().
func _enemy_process(_delta: float) -> void:
	velocity = Vector2.ZERO


func _distance_to_player() -> float:
	if not is_instance_valid(jugador):
		return INF
	return global_position.distance_to(jugador.global_position)


func _direction_to_player() -> Vector2:
	if not is_instance_valid(jugador):
		return Vector2.ZERO
	return global_position.direction_to(jugador.global_position)


## Flips the sprite/placeholder to face the given horizontal direction.
func _face(dir_x: float) -> void:
	if dir_x == 0.0:
		return
	if sprite:
		sprite.flip_h = dir_x < 0.0
	if placeholder:
		placeholder.scale.x = -1.0 if dir_x < 0.0 else 1.0


func recibir_danio(cantidad: int) -> void:
	if muerto:
		return
	vida = clampi(vida - cantidad, 0, vida_maxima)
	_flash()
	if vida <= 0:
		_morir()
		return
	# Stagger briefly with the hurt clip, if the enemy has one.
	if _has_anim(anim_hurt):
		_hurt_time = duracion_hurt
		_play(anim_hurt)


func _flash() -> void:
	if sprite:
		var tw := create_tween()
		sprite.modulate = Color.CRIMSON
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	if placeholder:
		var pw := create_tween()
		placeholder.modulate = Color.CRIMSON
		pw.tween_property(placeholder, "modulate", Color.WHITE, 0.25)


func _morir() -> void:
	if muerto:
		return
	muerto = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0

	if _has_anim(anim_death):
		_play(anim_death)
		var timer := get_tree().create_timer(duracion_muerte)
		timer.timeout.connect(_finish_death)
	else:
		_fade_and_free()


func _finish_death() -> void:
	if is_instance_valid(self):
		queue_free()


func _fade_and_free() -> void:
	var target: Node = sprite if sprite else placeholder
	if target == null:
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(target, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


## Applies melee/contact damage to the player through the existing controlador
## damage API, respecting the player's i-frames, and flashes the player sprite.
func _damage_player() -> void:
	var controlador: Node = _player_controller()
	if controlador == null:
		return

	controlador.call("recibir_danio", danio)
	if controlador.has_method("activar_invulnerabilidad"):
		controlador.call("activar_invulnerabilidad")

	if is_instance_valid(jugador):
		var p_sprite := jugador.get_node_or_null("AnimatedSprite2D") as CanvasItem
		if p_sprite:
			var tw := jugador.create_tween()
			p_sprite.modulate = Color.CRIMSON
			tw.tween_property(p_sprite, "modulate", Color.WHITE, 0.4)


func _player_controller() -> Node:
	if not is_instance_valid(jugador):
		return null
	var controlador: Node = jugador
	if not controlador.has_method("recibir_danio"):
		controlador = jugador.get_node_or_null("controlador")
	if controlador == null or not controlador.has_method("recibir_danio"):
		return null
	if "invulnerable" in controlador and bool(controlador.invulnerable):
		return null
	return controlador


func _play(anim: StringName) -> void:
	# While staggered, only hurt/death may take over the sprite.
	if _hurt_time > 0.0 and anim != anim_hurt and anim != anim_death:
		return
	if sprite and _has_anim(anim):
		sprite.visible = true
		if placeholder:
			placeholder.visible = false
		if sprite.animation != anim or not sprite.is_playing():
			sprite.play(anim)
		return
	if sprite:
		sprite.visible = false
	if placeholder:
		placeholder.visible = true


func _has_anim(anim: StringName) -> bool:
	if sprite == null or sprite.sprite_frames == null:
		return false
	if not sprite.sprite_frames.has_animation(anim):
		return false
	return sprite.sprite_frames.get_frame_count(anim) > 0