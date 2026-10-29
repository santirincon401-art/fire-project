extends "res://enemys/common/enemy_base.gd"
## Bullet-hell boss: "The Guardian of the Gate".
##
## Reuses EnemyBase for health, hit-flash, death and the "enemigos" group, so the
## player's existing attacks and abilities damage it unchanged. Its bullets
## (boss_bullet.gd) ignore the boss and all enemies, and are cleared on death.
##
## Patterns:
##  - Radial burst      : an evenly spaced ring of bullets.
##  - Aimed volley      : a telegraphed fan toward the player.
##  - Spiral            : a rotating stream the player must weave through.
##  - Phase-2 "storm"   : a radial ring followed by a fast spiral (desperate).
##
## Every number below is exported and configurable.

signal derrotado

@export_category("Jefe")
@export var nombre_jefe: String = "The Guardian of the Gate"
@export var bala_escena: PackedScene
## Bullets spawn this far from the centre, so they never start inside the boss.
@export var radio_aparicion: float = 74.0
@export var tiempo_intro: float = 2.6

@export_category("Disparos")
@export var danio_bala: int = 8
@export var velocidad_bala: float = 190.0
@export var tiempo_vida_bala: float = 7.0

@export_category("Patrones (Fase 1)")
@export var balas_radial: int = 16
@export var balas_abanico: int = 5
@export var repeticiones_abanico: int = 3
@export var duracion_espiral: float = 3.0
@export var intervalo_espiral: float = 0.06
@export var brazos_espiral: int = 2
@export var giro_espiral_deg: float = 10.0

@export_category("Fases")
@export var umbral_fase2: float = 0.6
@export var umbral_final: float = 0.22
@export var velocidad_fase2: float = 1.35
@export var pausa_entre_patrones: float = 1.05
## Hard cap on bullets alive at once from this boss, for performance safety.
@export var max_balas_activas: int = 260

enum Estado { INTRO, REPOSO, RADIAL, ABANICO, ESPIRAL, STORM, MUERTO }

var _estado: Estado = Estado.INTRO
var _t: float = 0.0
var _fase: int = 1
var _patron_idx: int = 0
var _angulo_base: float = 0.0
var _angulo_espiral: float = 0.0
var _espiral_acum: float = 0.0
var _fan_restantes: int = 0
var _vel_escala: float = 1.0
var _balas_patron: int = 0


func _ready() -> void:
	super()
	_estado = Estado.INTRO
	_t = tiempo_intro
	_fase = 1
	_configurar_hud()


func _configurar_hud() -> void:
	var hud := get_tree().get_first_node_in_group("boss_hud")
	if hud == null:
		return
	if hud.has_method("configurar"):
		hud.call("configurar", nombre_jefe, vida_maxima)
	if hud.has_method("mostrar_intro"):
		hud.call("mostrar_intro", "The Guardian of the Gate awakens...")


func _enemy_process(delta: float) -> void:
	if _estado == Estado.INTRO:
		velocity = Vector2.ZERO
		_play(anim_idle)
		_t -= delta
		if _t <= 0.0:
			_ir_a_reposo()
		return

	if _estado == Estado.MUERTO:
		velocity = Vector2.ZERO
		return

	# Slow stalking movement: the boss keeps its distance but repositions.
	if is_instance_valid(jugador):
		velocity = _direction_to_player() * (velocidad * _vel_escala)

	match _estado:
		Estado.REPOSO:
			_play(anim_idle)
			_t -= delta
			if _t <= 0.0:
				_elegir_patron()
		Estado.RADIAL:
			_play(anim_cast)
			_t -= delta
			if _t <= 0.0:
				_disparar_radial()
				_ir_a_reposo()
		Estado.ABANICO:
			_play(anim_cast)
			_t -= delta
			if _t <= 0.0:
				_disparar_abanico()
				_fan_restantes -= 1
				if _fan_restantes <= 0:
					_ir_a_reposo()
				else:
					_t = 0.3
		Estado.ESPIRAL:
			_play(anim_cast)
			_t += delta
			_espiral_acum += delta
			if _espiral_acum >= intervalo_espiral:
				_espiral_acum = 0.0
				_disparar_espiral_paso()
			if _t >= duracion_espiral:
				_ir_a_reposo()
		Estado.STORM:
			_play(anim_cast)
			_t += delta
			_espiral_acum += delta
			if _espiral_acum >= intervalo_espiral * 0.7:
				_espiral_acum = 0.0
				_disparar_espiral_paso()
			if _t >= duracion_espiral * 1.4:
				_ir_a_reposo()


# ==================================================
# SELECCIÓN Y ARRANQUE DE PATRONES
# ==================================================

func _elegir_patron() -> void:
	var ratio := float(vida) / float(maxi(vida_maxima, 1))
	if _fase >= 2 and ratio <= umbral_final:
		_iniciar_storm()
		return
	var opciones: Array = [Estado.RADIAL, Estado.ABANICO, Estado.ESPIRAL]
	if _fase >= 2:
		opciones = [Estado.RADIAL, Estado.ESPIRAL, Estado.ABANICO, Estado.ESPIRAL]
	_patron_idx = (_patron_idx + 1) % opciones.size()
	_iniciar(opciones[_patron_idx])


func _iniciar(estado: Estado) -> void:
	_estado = estado
	_balas_patron = 0
	match estado:
		Estado.RADIAL:
			_t = 0.5
		Estado.ABANICO:
			_t = 0.45
			_fan_restantes = maxi(repeticiones_abanico, 1)
		Estado.ESPIRAL:
			_t = 0.0
			_espiral_acum = 0.0
		_:
			_t = 0.4


func _iniciar_storm() -> void:
	_estado = Estado.STORM
	_t = 0.0
	_espiral_acum = 0.0
	_balas_patron = 0
	_disparar_radial()
	get_tree().call_group("boss_hud", "show_message", "The Guardian unleashes its final storm!")


func _ir_a_reposo() -> void:
	_estado = Estado.REPOSO
	_t = pausa_entre_patrones / maxf(_vel_escala, 0.1)


# ==================================================
# PATRONES
# ==================================================

func _disparar_radial() -> void:
	var n := balas_radial
	if _fase >= 2:
		n = int(float(balas_radial) * 1.35)
	n = maxi(n, 1)
	for i in n:
		_spawn_bala(TAU * float(i) / float(n) + _angulo_base)
	_angulo_base += 0.35


func _disparar_abanico() -> void:
	var base := Vector2.RIGHT.angle()
	if is_instance_valid(jugador):
		base = global_position.direction_to(jugador.global_position).angle()
	var n := maxi(balas_abanico, 1)
	var spread := deg_to_rad(24.0)
	for i in n:
		var off := (float(i) - (float(n) - 1.0) * 0.5) * spread
		_spawn_bala(base + off)


func _disparar_espiral_paso() -> void:
	var arms := maxi(brazos_espiral, 1)
	for i in arms:
		_spawn_bala(_angulo_espiral + TAU * float(i) / float(arms))
	_angulo_espiral += deg_to_rad(giro_espiral_deg)


func _spawn_bala(angulo: float) -> void:
	if bala_escena == null:
		return
	if get_tree().get_nodes_in_group("boss_bullets").size() >= max_balas_activas:
		return
	if _balas_patron >= max_balas_activas:
		return

	var b: Node = bala_escena.instantiate()
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		b.queue_free()
		return
	host.add_child(b)

	var dir := Vector2.from_angle(angulo)
	if b is Node2D:
		(b as Node2D).global_position = global_position + dir * radio_aparicion
	if b.has_method("configurar"):
		b.call("configurar", dir, self)
	b.set("velocidad", velocidad_bala)
	b.set("danio", danio_bala)
	b.set("tiempo_vida", tiempo_vida_bala)
	_balas_patron += 1


# ==================================================
# DAÑO, FASES Y MUERTE
# ==================================================

func recibir_danio(cantidad: int) -> void:
	if muerto:
		return
	super(cantidad)
	_actualizar_fase()
	var hud := get_tree().get_first_node_in_group("boss_hud")
	if hud != null and hud.has_method("set_vida"):
		hud.call("set_vida", vida, vida_maxima)


func _actualizar_fase() -> void:
	if muerto:
		return
	var ratio := float(vida) / float(maxi(vida_maxima, 1))
	if _fase < 2 and ratio <= umbral_fase2:
		_fase = 2
		_vel_escala = velocidad_fase2
		if sprite != null:
			sprite.self_modulate = Color(1.5, 0.7, 1.4, 1)
		get_tree().call_group("boss_hud", "show_message", "The Guardian grows furious!")
	if _fase < 3 and ratio <= umbral_final:
		_fase = 3
		if sprite != null:
			sprite.self_modulate = Color(1.9, 0.5, 0.5, 1)


func _morir() -> void:
	if muerto:
		return
	muerto = true
	_estado = Estado.MUERTO
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_limpiar_balas()

	if _has_anim(anim_death):
		_play(anim_death)

	derrotado.emit()
	get_tree().call_group("boss_hud", "show_message", "The Guardian is defeated!")

	var t := get_tree().create_timer(1.6)
	t.timeout.connect(_mostrar_victoria)
	var t2 := get_tree().create_timer(2.6)
	t2.timeout.connect(_terminar)


func _limpiar_balas() -> void:
	for b in get_tree().get_nodes_in_group("boss_bullets"):
		if is_instance_valid(b):
			b.queue_free()


func _mostrar_victoria() -> void:
	get_tree().call_group("victory_screen", "show_victory")


func _terminar() -> void:
	if is_instance_valid(self):
		queue_free()