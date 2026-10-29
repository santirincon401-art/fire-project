class_name EnemySpawner
extends Node2D
## Spawns one wave of enemies when the seal puzzle reaches a stage.
##
## - Inactive until the matching puzzle stage completes (linked through the
##   "enemy_spawners" group, never a timer).
## - One-shot per instance, so a repeated signal can never duplicate the wave.
## - Optionally guarded once per session through the PlayerAbilities autoload
##   (used for the unique Spectral Sword encounter) so re-entering the area or
##   reloading the scene cannot spawn it twice.
## - Never spawns off the floor tiles, nor right on top of the player.

@export_category("Disparo")
## Stage that activates this spawner: 1 = runes, 2 = plates, 3 = gate/portal.
@export var etapa: int = 1
@export var enemigos: Array[PackedScene] = []
@export var radio_dispersion: float = 70.0
@export var retardo: float = 0.0
@export var distancia_minima_jugador: float = 120.0
@export var mensaje: String = "The dungeon stirs... enemies awaken!"

@export_category("Único")
## When true the spawner may run only once per session (persistent guard).
@export var una_vez_por_sesion: bool = false
@export var bandera_persistente: String = ""

var _activado: bool = false

@onready var _ring: Polygon2D = get_node_or_null("Ring")


func _ready() -> void:
	add_to_group("enemy_spawners")
	if _ring != null:
		_ring.visible = false


## Called by the SealPuzzle (through the group) with the stage that finished.
func activar_etapa(etapa_completada: int) -> void:
	if etapa_completada != etapa:
		return
	activar()


## Direct activation (used by tests / manual triggers).
func activar() -> void:
	if _activado:
		return
	if una_vez_por_sesion and _bandera_activa():
		return
	_activado = true
	if una_vez_por_sesion:
		_marcar_bandera()

	if retardo > 0.0:
		var t := get_tree().create_timer(retardo)
		t.timeout.connect(_spawn_wave)
	else:
		_spawn_wave()


func _spawn_wave() -> void:
	if enemigos.is_empty():
		return
	var host := _host()
	if host == null:
		return

	var posiciones := _calcular_posiciones(enemigos.size())
	for i in enemigos.size():
		var escena: PackedScene = enemigos[i]
		if escena == null:
			continue
		var enemigo := escena.instantiate()
		host.add_child(enemigo)
		if enemigo is Node2D:
			(enemigo as Node2D).global_position = posiciones[i]

	_feedback()


func _host() -> Node:
	var raiz := get_tree().current_scene
	if raiz != null:
		return raiz
	return get_parent()


# ==================================================
# COLOCACIÓN SEGURA
# ==================================================

func _calcular_posiciones(cantidad: int) -> Array:
	var resultado: Array = []
	var total := maxi(cantidad, 1)
	var centro := global_position

	var jugador := get_tree().get_first_node_in_group("jugador")
	var jugador_pos := Vector2.INF
	if jugador is Node2D:
		jugador_pos = (jugador as Node2D).global_position

	for i in total:
		var angulo_base := TAU * float(i) / float(total)
		var elegido := centro + Vector2.from_angle(angulo_base) * radio_dispersion
		var mejor := -1.0
		for intento in 8:
			var ang := angulo_base + float(intento) * 0.7
			var cand := centro + Vector2.from_angle(ang) * radio_dispersion
			if not _es_piso(cand):
				continue
			if jugador_pos != Vector2.INF and cand.distance_to(jugador_pos) < distancia_minima_jugador:
				continue
			var dist := cand.distance_to(jugador_pos) if jugador_pos != Vector2.INF else 0.0
			if dist >= mejor:
				mejor = dist
				elegido = cand
		resultado.append(elegido)
	return resultado


func _es_piso(punto: Vector2) -> bool:
	var raiz := get_tree().current_scene
	if raiz == null:
		return true
	var capas: Array = []
	_recoger_capas(raiz, capas)
	if capas.is_empty():
		return true
	var piso: Array = []
	for c in capas:
		if _es_capa_piso(c):
			piso.append(c)
	if piso.is_empty():
		piso = capas
	for capa in piso:
		if capa.tile_set == null:
			continue
		var celda: Vector2i = capa.local_to_map(capa.to_local(punto))
		if capa.get_cell_source_id(celda) != -1:
			return true
	return false


func _recoger_capas(nodo: Node, salida: Array) -> void:
	for c in nodo.get_children():
		if c is TileMapLayer:
			salida.append(c)
		_recoger_capas(c, salida)


func _es_capa_piso(capa: Node) -> bool:
	var ts: TileSet = capa.tile_set
	if ts == null:
		return false
	for i in ts.get_source_count():
		var src := ts.get_source(ts.get_source_id(i))
		if src is TileSetAtlasSource and src.texture != null:
			if String(src.texture.resource_path).contains("piso"):
				return true
	return false


# ==================================================
# FEEDBACK
# ==================================================

func _feedback() -> void:
	if mensaje != "":
		get_tree().call_group("hud", "show_message", mensaje)
	if _ring == null:
		return
	_ring.visible = true
	_ring.scale = Vector2(0.3, 0.3)
	_ring.modulate.a = 0.9
	var tw := create_tween()
	tw.tween_property(_ring, "scale", Vector2.ONE, 0.4)
	tw.parallel().tween_property(_ring, "modulate:a", 0.0, 0.55)
	tw.tween_callback(_ocultar_ring)


func _ocultar_ring() -> void:
	if _ring != null:
		_ring.visible = false


# ==================================================
# GUARDA PERSISTENTE (una vez por sesión)
# ==================================================

func _bandera_activa() -> bool:
	if bandera_persistente == "":
		return false
	var ab := get_node_or_null("/root/PlayerAbilities")
	return ab != null and bool(ab.get(bandera_persistente))


func _marcar_bandera() -> void:
	if bandera_persistente == "":
		return
	var ab := get_node_or_null("/root/PlayerAbilities")
	if ab != null:
		ab.set(bandera_persistente, true)