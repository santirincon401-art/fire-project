class_name SealPuzzle
extends Node
## Multi-stage "Ancient Sealing Mechanism" controller.
##
## Stage 1 - activate the three rune pedestals in the order carved on the
##           inscription. A wrong rune resets stage 1 (recoverable).
## Stage 2 - the three energy plates power up; stand on all three to ground the
##           energy.
## Stage 3 - the sealed gate grinds open and the boss portal awakens.
##
## All state is scene-local, so it resets cleanly when the room reloads.

signal resuelto
## Emitted with the stage number that just completed (1 = runes, 2 = plates,
## 3 = gate/portal). Enemy spawners listen to this via the "enemy_spawners" group.
signal etapa_completada(etapa: int)

@export var orden_correcta: Array[int] = [2, 3, 1]

var _progreso: int = 0
var _runas: Array = []
var _placas: Array = []
var _resuelto: bool = false


func _ready() -> void:
	add_to_group("seal_puzzle")

	_runas = get_tree().get_nodes_in_group("rune_devices")
	_runas.sort_custom(_ordenar_runas)
	for r in _runas:
		if r.has_signal("rune_activated") and not r.is_connected("rune_activated", _on_runa):
			r.connect("rune_activated", _on_runa)

	_placas = get_tree().get_nodes_in_group("pressure_plates")
	for p in _placas:
		if p.has_method("habilitar"):
			p.call("habilitar", false)
		if p.has_signal("activated") and not p.is_connected("activated", _on_placa):
			p.connect("activated", _on_placa)

	var inscripcion := get_tree().get_first_node_in_group("rune_inscription")
	if inscripcion != null and inscripcion.has_method("mostrar_orden"):
		inscripcion.call("mostrar_orden", _pista_glyphs())

	_avisar("The seal is dormant. Read the stone and wake the runes in order.")


func _ordenar_runas(a: Node, b: Node) -> bool:
	return int(a.rune_id) < int(b.rune_id)


func _runa_por_id(id: int) -> Node:
	for r in _runas:
		if int(r.rune_id) == id:
			return r
	return null


## The inscription draws glyph *shapes* (triangle/square/circle), so translate the
## required rune ids into the glyph shape each pedestal actually carries. Without
## this the clue would show the wrong (and ambiguous) symbols.
func _pista_glyphs() -> Array:
	var pista: Array = []
	for id in orden_correcta:
		var r := _runa_por_id(id)
		if r != null:
			pista.append(int(r.glyph_shape))
	return pista


func _on_runa(rune_id: int) -> void:
	if _resuelto:
		return
	if _progreso < orden_correcta.size() and rune_id == orden_correcta[_progreso]:
		_progreso += 1
		if _progreso >= orden_correcta.size():
			_completar_runas()
		else:
			_avisar("Rune accepted (%d/%d)..." % [_progreso, orden_correcta.size()])
	else:
		_avisar("The seal rejects that rune! The binding resets.")
		resetear()


func _completar_runas() -> void:
	for p in _placas:
		if p.has_method("habilitar"):
			p.call("habilitar", true)
	_avisar("The runes align! Ground the energy on the three plates.")
	_notificar_etapa(1)


func _on_placa() -> void:
	if _resuelto:
		return
	var activas := 0
	for p in _placas:
		if "is_active" in p and bool(p.is_active):
			activas += 1
	if activas < _placas.size():
		_avisar("Energy grounded (%d/%d)..." % [activas, _placas.size()])
		return
	_notificar_etapa(2)
	_abrir_puerta()


func _abrir_puerta() -> void:
	if _resuelto:
		return
	_resuelto = true

	var puerta := get_tree().get_first_node_in_group("puzzle_doors")
	if puerta != null and puerta.has_method("open"):
		puerta.call("open")

	var portal := get_tree().get_first_node_in_group("boss_portal")
	if portal != null and portal.has_method("activar"):
		portal.call("activar")

	get_tree().call_group(
		"hud",
		"show_message",
		"The Ancient Gate is unlocked! The Guardian of the Gate awaits beyond."
	)
	_notificar_etapa(3)
	resuelto.emit()


## Clears stage 1 (and any half-done stage 2) so a wrong attempt is recoverable.
func resetear() -> void:
	if _resuelto:
		return
	_progreso = 0
	for r in _runas:
		if r.has_method("reset"):
			r.call("reset")
	for p in _placas:
		if p.has_method("reset"):
			p.call("reset")
		if p.has_method("habilitar"):
			p.call("habilitar", false)


func _avisar(texto: String) -> void:
	get_tree().call_group("hud", "show_message", texto)


## Announces a finished stage to the enemy spawners (and anyone else listening).
func _notificar_etapa(etapa: int) -> void:
	etapa_completada.emit(etapa)
	get_tree().call_group("enemy_spawners", "activar_etapa", etapa)