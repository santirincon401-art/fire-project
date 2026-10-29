extends Node2D

@export_category("Ability")
@export var sword_count: int = 4
@export var attack_range: float = 280.0
@export var damage: int = 2
@export var fly_speed: float = 420.0
@export var max_distance: float = 320.0
@export var orbit_radius: float = 42.0
@export var orbit_speed: float = 2.4
@export var sword_scene: PackedScene
@export var input_action: StringName = &"SpectralSwords"

@export_category("Energy and Cooldowns")
@export var energy_cost_per_summon: float = 15.0
@export var deactivate_cooldown: float = 1.2
@export var attack_interval: float = 0.75

var _player: Node2D
var _energy_controller: Node
var _active: bool = false
var _cooldown_left: float = 0.0
var _attack_timer: float = 0.0
var _orbit_angle: float = 0.0
var _swords: Array[Node2D] = []


func _ready() -> void:
	_player = get_parent() as Node2D

	if sword_scene == null:
		if ResourceLoader.exists("res://abilities/spectral_sword.tscn"):
			sword_scene = load(
				"res://abilities/spectral_sword.tscn"
			) as PackedScene


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	if not is_instance_valid(_player):
		_player = get_parent() as Node2D

	if not is_instance_valid(_player):
		return

	if not InputMap.has_action(input_action):
		return

	if Input.is_action_just_pressed(input_action):
		if _active:
			_deactivate()
		else:
			_activate()

	if not _active:
		return

	if not _is_unlocked():
		_deactivate()
		return

	_update_orbit(delta)

	_attack_timer = maxf(_attack_timer - delta, 0.0)

	if _attack_timer <= 0.0:
		var target := _find_nearest_enemy()

		if is_instance_valid(target):
			_launch_sword(target)
			_attack_timer = attack_interval


# ==================================================
# DESBLOQUEO DE LA HABILIDAD
# ==================================================

func _is_unlocked() -> bool:
	var abilities = get_node_or_null("/root/PlayerAbilities")

	if abilities == null:
		return false

	return bool(abilities.get("spectral_swords_unlocked"))


# ==================================================
# CONEXIÓN CON LA ENERGÍA DEL JUGADOR
# ==================================================

func _find_energy_controller(node: Node) -> Node:
	if node.has_method("usar_energia"):
		return node

	for child in node.get_children():
		var found := _find_energy_controller(child)

		if found != null:
			return found

	return null


func _pay_energy(cost: float) -> bool:
	if not is_instance_valid(_energy_controller):
		if is_instance_valid(_player):
			_energy_controller = _find_energy_controller(_player)

	if not is_instance_valid(_energy_controller):
		push_warning(
			"No se encontró el controlador con la función usar_energia()."
		)
		return false

	return bool(_energy_controller.call("usar_energia", cost))


# ==================================================
# ACTIVAR Y DESACTIVAR
# ==================================================

func _activate() -> void:
	if _active or _cooldown_left > 0.0:
		return

	if not _is_unlocked() or sword_scene == null:
		return

	if not is_instance_valid(_player):
		return

	# Cobrar energía antes de invocar las espadas.
	if not _pay_energy(energy_cost_per_summon):
		return

	_active = true
	_attack_timer = 0.0
	_orbit_angle = 0.0

	_create_swords()


func _deactivate() -> void:
	if not _active:
		return

	_active = false
	_cooldown_left = deactivate_cooldown

	for sword in _swords:
		if is_instance_valid(sword):
			sword.queue_free()

	_swords.clear()


# ==================================================
# CREACIÓN DE ESPADAS
# ==================================================

func _create_swords() -> void:
	for i in range(maxi(sword_count, 1)):
		_spawn_orbiting_sword()


func _spawn_orbiting_sword() -> void:
	if sword_scene == null or not is_instance_valid(_player):
		return

	var host: Node = get_tree().current_scene

	if host == null:
		host = get_parent()

	if host == null:
		return

	var instance := sword_scene.instantiate()
	host.add_child(instance)

	if not (instance is Node2D):
		instance.queue_free()
		return

	var sword := instance as Node2D
	sword.global_position = _player.global_position

	if sword.has_method("set_orbit_mode"):
		sword.call("set_orbit_mode", true)

	_swords.append(sword)


# ==================================================
# ÓRBITA Y REPOSICIÓN DE ESPADAS
# ==================================================

func _update_orbit(delta: float) -> void:
	_orbit_angle = fposmod(
		_orbit_angle + orbit_speed * delta,
		TAU
	)

	var valid_swords: Array[Node2D] = []

	for sword in _swords:
		if is_instance_valid(sword):
			valid_swords.append(sword)

	_swords = valid_swords

	# Reponer las espadas que hayan salido a atacar.
	while _swords.size() < maxi(sword_count, 1):
		var previous_count := _swords.size()
		_spawn_orbiting_sword()

		if _swords.size() == previous_count:
			break

	if _swords.is_empty():
		return

	for i in range(_swords.size()):
		var angle := (
			_orbit_angle
			+ TAU * float(i) / float(_swords.size())
		)

		var position := (
			_player.global_position
			+ Vector2(cos(angle), sin(angle)) * orbit_radius
		)

		var sword := _swords[i]

		if sword.has_method("orbit_at"):
			sword.call("orbit_at", position, angle + PI / 2.0)
		else:
			sword.global_position = position
			sword.rotation = angle + PI / 2.0


# ==================================================
# BUSCAR ENEMIGOS
# ==================================================

func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = attack_range

	for node in get_tree().get_nodes_in_group("enemigos"):
		if not is_instance_valid(node):
			continue

		if not (node is Node2D):
			continue

		var enemy := node as Node2D

		if not enemy.has_method("recibir_danio"):
			continue

		var distance := _player.global_position.distance_to(
			enemy.global_position
		)

		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = enemy

	return nearest


# ==================================================
# LANZAR ESPADAS
# ==================================================

func _launch_sword(target: Node2D) -> void:
	if not is_instance_valid(target):
		return

	var chosen: Node2D = null
	var best_distance: float = INF

	for sword in _swords:
		if not is_instance_valid(sword):
			continue

		var distance := sword.global_position.distance_squared_to(
			target.global_position
		)

		if distance < best_distance:
			best_distance = distance
			chosen = sword

	if chosen == null:
		return

	_swords.erase(chosen)

	if chosen.has_method("launch_at"):
		chosen.call(
			"launch_at",
			target,
			fly_speed,
			max_distance,
			damage
		)
	else:
		chosen.queue_free()
