extends Node
## Headless test for the boss arena: intro, patterns, damage, victory.
## Run: godot --headless --path . res://tests/boss_test.tscn

var _fallos: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var arena: Node = load("res://scenes/boss_arena.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	await get_tree().process_frame

	_hacer_jugador_inmune()

	var boss := _buscar_boss()
	_ok(boss != null, "boss present in arena")
	_ok(get_tree().get_first_node_in_group("boss_hud") != null, "boss HUD present")
	_ok(get_tree().get_first_node_in_group("jugador") != null, "player present in arena")
	_ok(get_tree().get_first_node_in_group("death_screen") != null, "death screen present in arena")
	_ok(get_tree().get_first_node_in_group("pause_menu") != null, "pause menu present in arena")
	_ok(get_tree().get_first_node_in_group("victory_screen") != null, "victory screen present in arena")

	if boss == null:
		_final()
		return

	# Boss must have real sprite frames.
	var spr := boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_ok(spr != null and spr.sprite_frames != null
		and spr.sprite_frames.has_animation("idle")
		and spr.sprite_frames.get_frame_count("idle") > 0, "boss has idle sprite frames")

	# Wait past the intro and let patterns fire.
	for i in 320:
		await get_tree().physics_frame
	var bullets := get_tree().get_nodes_in_group("boss_bullets")
	_ok(bullets.size() > 0, "boss fired bullets (%d active)" % bullets.size())

	# Damage works through the existing API.
	var v0 := int(boss.get("vida"))
	boss.call("recibir_danio", 5)
	_ok(int(boss.get("vida")) < v0, "boss takes damage via recibir_danio()")

	# Phase change at the threshold.
	var umbral := float(boss.get("umbral_fase2"))
	boss.call("recibir_danio", int(float(boss.get("vida_maxima")) * umbral))
	await get_tree().process_frame
	_ok(int(boss.get("_fase")) >= 2, "boss enters phase 2 below the health threshold")

	# Killing the boss clears its bullets and shows victory once.
	boss.call("recibir_danio", 99999)
	await get_tree().process_frame
	_ok(get_tree().get_nodes_in_group("boss_bullets").size() == 0, "bullets cleared on boss death")
	for i in 140:
		await get_tree().physics_frame
	var vic := get_tree().get_first_node_in_group("victory_screen")
	_ok(vic != null and bool(vic.call("is_showing")), "victory screen shows after defeat")
	# Cannot trigger twice.
	if vic != null:
		vic.call("show_victory")
		_ok(bool(vic.call("is_showing")), "victory stays single-shot")

	_final()


func _buscar_boss() -> Node:
	for n in get_tree().get_nodes_in_group("enemigos"):
		if n.has_method("derrotado") or n.has_signal("derrotado"):
			return n
		if n.get_script() != null and String(n.get_script().resource_path).ends_with("boss.gd"):
			return n
	return null


func _hacer_jugador_inmune() -> void:
	var player := get_tree().get_first_node_in_group("jugador")
	if player == null:
		return
	var ctrl: Node = player.get_node_or_null("controlador")
	if ctrl != null:
		ctrl.set("invulnerable", true)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		_fallos += 1
		print("FAIL: ", msg)


func _final() -> void:
	print("RESULT: %d failed check(s)" % _fallos)
	get_tree().paused = false
	get_tree().quit(_fallos)