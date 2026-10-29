extends Node
## Headless test for the multi-stage seal puzzle in main.tscn.
## Run: godot --headless --path . res://tests/puzzle_test.tscn

const RuneGeometry := preload("res://puzzles/rune_geometry.gd")

var _fallos: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().physics_frame
	await get_tree().process_frame

	_hacer_jugador_inmune()

	_ok(get_tree().get_nodes_in_group("rune_devices").size() == 3, "3 rune devices present")
	_ok(get_tree().get_nodes_in_group("pressure_plates").size() == 3, "3 energy plates present")
	_ok(get_tree().get_first_node_in_group("rune_inscription") != null, "inscription present")
	_ok(get_tree().get_first_node_in_group("boss_portal") != null, "boss portal present")
	_ok(get_tree().get_first_node_in_group("puzzle_doors") != null, "sealed gate present")
	var puzzle := get_tree().get_first_node_in_group("seal_puzzle")
	_ok(puzzle != null, "seal puzzle controller present")

	var inscripcion := get_tree().get_first_node_in_group("rune_inscription")
	if inscripcion != null:
		var glyphs: int = 0
		for c in inscripcion.get_children():
			if c is Polygon2D and String(c.name).begins_with("GlyphClue"):
				glyphs += 1
		_ok(glyphs == 3, "inscription drew 3 clue glyphs (%d)" % glyphs)
	# Rune ids [2, 3, 1] map to glyph shapes [1, 2, 0] = square, circle, triangle.
	_ok(_clue_correcta(inscripcion, [1, 2, 0]), "inscription clue matches the solution order")

	# Wrong order -> the sequence must reset and stay unsolved.
	_activar_runa(1)
	await get_tree().process_frame
	_ok(not bool(_runa(1).get("activada")), "wrong rune resets stage 1")

	# Correct order is [2, 3, 1].
	_activar_runa(2)
	_activar_runa(3)
	_activar_runa(1)
	await get_tree().process_frame
	_ok(_placas_habilitadas(), "plates enabled once the runes align")

	# Ground the energy on all three plates.
	for p in get_tree().get_nodes_in_group("pressure_plates"):
		p.call("activate")
	await get_tree().process_frame

	var portal := get_tree().get_first_node_in_group("boss_portal")
	_ok(portal != null and bool(portal.get("activo")), "portal activates when the plates complete")
	var puerta := get_tree().get_first_node_in_group("puzzle_doors")
	_ok(puerta != null and bool(puerta.get("opened")), "sealed gate opens")

	# Enemies now enter through the puzzle-driven spawners.
	await get_tree().physics_frame
	_ok(_cuenta_script("chaser.gd") >= 1, "stage 1 spawned a chaser")
	_ok(_cuenta_script("brute.gd") >= 1, "stage 2 spawned a brute")
	_ok(_cuenta_script("spectral_guardian.gd") == 1, "exactly one Spectral Guardian spawned")
	_ok(_tiene_frames(_buscar_script("chaser.gd"), "walk"), "chaser has walk frames")
	_ok(_tiene_frames(_buscar_script("brute.gd"), "attack"), "brute has attack frames")

	_final()


func _activar_runa(id: int) -> void:
	var r := _runa(id)
	if r != null:
		r.call("activate")


func _runa(id: int) -> Node:
	for r in get_tree().get_nodes_in_group("rune_devices"):
		if int(r.get("rune_id")) == id:
			return r
	return null


func _placas_habilitadas() -> bool:
	for p in get_tree().get_nodes_in_group("pressure_plates"):
		if not bool(p.get("habilitada")):
			return false
	return true


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


func _tiene_frames(enemigo: Node, anim: String) -> bool:
	if enemigo == null:
		return false
	var spr := enemigo.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr == null or spr.sprite_frames == null:
		return false
	if not spr.sprite_frames.has_animation(anim):
		return false
	return spr.sprite_frames.get_frame_count(anim) > 0


func _clue_correcta(inscripcion: Node, esperado: Array) -> bool:
	if inscripcion == null:
		return false
	var polys: Array = []
	for c in inscripcion.get_children():
		if c is Polygon2D and String(c.name).begins_with("GlyphClue"):
			polys.append(c)
	if polys.size() != esperado.size():
		return false
	polys.sort_custom(func(a, b): return String(a.name) < String(b.name))
	for i in polys.size():
		var want: PackedVector2Array = RuneGeometry.points(int(esperado[i]))
		if polys[i].polygon != want:
			return false
	return true


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