extends Node
## Headless behaviour test for the enemy/UI work. Run with:
##   godot --headless --path . res://tests/test_runner.tscn
## Exits with the number of failed checks (0 = all passed).

var _fallos: int = 0
var _main: Node


func _ready() -> void:
	# Keep running even when the game pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var player: Node2D = get_tree().get_first_node_in_group("jugador")
	_ok(player != null, "player is in group 'jugador'")
	if player == null:
		_finalizar()
		return
	var ctrl: Node = player.get_node_or_null("controlador")
	_ok(ctrl != null, "player has a 'controlador' node")
	_hacer_jugador_inmune()

	_ok(_enemigos().size() == 0, "level starts with no placed enemies")
	# A wrong rune must not spawn anything or advance progression.
	_activar_runa(1)
	await get_tree().process_frame
	_ok(_enemigos().size() == 0, "a wrong rune does not spawn enemies")

	var mage: Node2D = await _activar_progresion()
	_ok(mage != null, "mage spawned through the puzzle progression")

	await _probar_mago(mage, player)
	await _probar_mago_muerte(mage, player)
	await _probar_perseguidor(player)
	await _probar_enemigos_variados()
	await _probar_pausa()
	await _probar_muerte(ctrl)

	_finalizar()


## Drives the puzzle stage by stage so the spawners fire, then returns the mage.
func _activar_progresion() -> Node2D:
	# Stage 1 - runes in the correct order [2, 3, 1].
	_activar_runa(2)
	_activar_runa(3)
	_activar_runa(1)
	await get_tree().process_frame
	await get_tree().physics_frame

	# Stage 2 - ground the energy on all three plates (this also opens the gate).
	for p in get_tree().get_nodes_in_group("pressure_plates"):
		p.call("activate")
	await get_tree().process_frame
	await get_tree().physics_frame

	_ok(_cuenta_script("chaser.gd") >= 1, "stage 1 spawned a chaser")
	_ok(_cuenta_script("brute.gd") >= 1, "stage 2 spawned a brute")
	_ok(_cuenta_script("spectral_guardian.gd") == 1, "exactly one Spectral Guardian spawned")
	_ok(_cuenta_script("mago.gd") >= 1, "stage 3 spawned the mage")
	_ok(_cuenta_script("spiral_shooter.gd") >= 1, "stage 3 spawned the spiral shooter")

	# The Spectral Guardian must never spawn a second copy.
	var guardian_spawner := _main.get_node_or_null("Spawner_Guardian")
	if guardian_spawner != null:
		guardian_spawner.call("activar")
		await get_tree().physics_frame
	_ok(_cuenta_script("spectral_guardian.gd") == 1, "guardian cannot spawn twice")

	return _buscar_script("mago.gd")


func _probar_mago(mage: Node2D, player: Node2D) -> void:
	if mage == null:
		return
	# The mage should be idling (not stuck on its scene-default death frame).
	var mage_sprite := mage.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if mage_sprite != null:
		_ok(mage_sprite.animation == "Idle", "mage plays its Idle animation (got '%s')" % mage_sprite.animation)

	# Put the player inside the mage's attack range and wait for a shot.
	player.global_position = mage.global_position + Vector2(180, 0)

	var espera := 220
	var bala: Node = null
	while espera > 0 and bala == null:
		await get_tree().physics_frame
		espera -= 1
		bala = _buscar_bala()

	_ok(bala != null, "mage fired a projectile when the player was in range")
	if bala == null:
		return

	var dist: float = (bala as Node2D).global_position.distance_to(mage.global_position)
	_ok(dist > 20.0, "projectile spawned clear of the mage (dist %.1f px)" % dist)

	# Let it fly and confirm it does not vanish on the shooter and keeps moving.
	await get_tree().physics_frame
	var antes: Vector2 = (bala as Node2D).global_position if is_instance_valid(bala) else Vector2.ZERO
	for i in 10:
		await get_tree().physics_frame
	var sigue_viva: bool = is_instance_valid(bala)
	_ok(sigue_viva, "projectile survives past the shooter")
	if sigue_viva:
		var recorrido: float = (bala as Node2D).global_position.distance_to(antes)
		_ok(recorrido > 5.0, "projectile keeps travelling (%.1f px in 10 frames)" % recorrido)


func _probar_mago_muerte(mage: Node2D, player: Node2D) -> void:
	if mage == null:
		return
	mage.call("recibir_danio", 99999)
	await get_tree().process_frame
	_ok(bool(mage.get("muerto")), "mage is flagged dead after lethal damage")
	# With a dead mage in range, no new bullet may appear.
	player.global_position = mage.global_position + Vector2(150, 0)
	for i in 5:
		await get_tree().physics_frame
		for c in get_tree().current_scene.get_children():
			if c.get_script() != null and c.get_script().resource_path == "res://area_2d.gd":
				(c as Node).queue_free()
	for i in 90:
		await get_tree().physics_frame
	_ok(_buscar_bala() == null, "dead mage never fires again")


func _probar_enemigos_variados() -> void:
	var swarm := _buscar_script("swarmling.gd")
	var brute := _buscar_script("brute.gd")
	_ok(swarm != null and swarm.has_method("recibir_danio"), "swarmling uses recibir_danio()")
	_ok(brute != null and brute.has_method("recibir_danio"), "brute uses recibir_danio()")
	if swarm != null and brute != null:
		var v_swarm: int = int(swarm.get("vida_maxima"))
		var v_brute: int = int(brute.get("vida_maxima"))
		var sp_swarm: float = float(swarm.get("velocidad"))
		var sp_brute: float = float(brute.get("velocidad"))
		_ok(v_brute > v_swarm, "brute is tankier than the swarmling (%d vs %d)" % [v_brute, v_swarm])
		_ok(sp_swarm > sp_brute, "swarmling is faster than the brute (%.0f vs %.0f)" % [sp_swarm, sp_brute])


func _probar_perseguidor(player: Node2D) -> void:
	var chaser: Node2D = _buscar_script("chaser.gd") as Node2D
	_ok(chaser != null, "chaser exists")
	if chaser == null:
		return
	player.global_position = chaser.global_position + Vector2(400, 0)
	await get_tree().physics_frame
	var d0: float = chaser.global_position.distance_to(player.global_position)
	for i in 30:
		await get_tree().physics_frame
	var d1: float = chaser.global_position.distance_to(player.global_position)
	_ok(d1 < d0 - 5.0, "chaser approaches the player (%.1f -> %.1f)" % [d0, d1])


func _probar_pausa() -> void:
	var pm: Node = get_tree().get_first_node_in_group("pause_menu")
	_ok(pm != null, "pause menu is present")
	if pm == null:
		return
	pm.call("_pause_game")
	await get_tree().process_frame
	_ok(get_tree().paused == true, "pause menu pauses the tree")
	pm.call("_resume_game")
	await get_tree().process_frame
	_ok(get_tree().paused == false, "resume unpauses the tree")


func _probar_muerte(ctrl: Node) -> void:
	if ctrl == null:
		return
	ctrl.call("recibir_danio", 100000)
	await get_tree().process_frame
	var ds: Node = get_tree().get_first_node_in_group("death_screen")
	_ok(ds != null and bool(ds.call("is_showing")), "death screen shows when the player dies")
	_ok(get_tree().paused == true, "world is paused while the death screen is up")
	var vida_tras_morir: int = int(ctrl.get("vida_actual"))
	ctrl.call("recibir_danio", 50)
	_ok(int(ctrl.get("vida_actual")) == vida_tras_morir, "dead player takes no further damage")
	var pm: Node = get_tree().get_first_node_in_group("pause_menu")
	if pm != null:
		_ok(bool(pm.call("_death_showing")), "pause menu detects the death screen (won't pause over it)")


func _enemigos() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("enemigos"):
		if n.has_method("recibir_danio"):
			out.append(n)
	return out


func _buscar_script(nombre: String) -> Node:
	for n in _enemigos():
		var s: Script = n.get_script()
		if s != null and String(s.resource_path).ends_with(nombre):
			return n
	return null


func _cuenta_script(nombre: String) -> int:
	var c := 0
	for n in _enemigos():
		var s: Script = n.get_script()
		if s != null and String(s.resource_path).ends_with(nombre):
			c += 1
	return c


func _activar_runa(id: int) -> void:
	for r in get_tree().get_nodes_in_group("rune_devices"):
		if int(r.get("rune_id")) == id:
			r.call("activate")
			return


func _hacer_jugador_inmune() -> void:
	var player := get_tree().get_first_node_in_group("jugador")
	if player == null:
		return
	var ctrl: Node = player.get_node_or_null("controlador")
	if ctrl != null:
		ctrl.set("invulnerable", true)


func _buscar_bala() -> Node:
	var raiz: Node = get_tree().current_scene
	if raiz == null:
		return null
	for c in raiz.get_children():
		var script: Script = c.get_script()
		if script != null and script.resource_path == "res://area_2d.gd":
			return c
	return null


func _ok(cond: bool, mensaje: String) -> void:
	if cond:
		print("PASS: ", mensaje)
	else:
		_fallos += 1
		print("FAIL: ", mensaje)


func _finalizar() -> void:
	print("RESULT: %d failed check(s)" % _fallos)
	get_tree().paused = false
	get_tree().quit(_fallos)