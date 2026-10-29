class_name SpiralBullet
extends Area2D
## Independent projectile. Damages the player, then frees itself on hit,
## on solid collision, or when it leaves walkable dungeon tiles.

@export var speed: float = 180.0
@export var danio: int = 10
@export var max_lifetime: float = 8.0

var direction: Vector2 = Vector2.RIGHT
var _age: float = 0.0
var _room_grace: float = 0.08
var _tile_layers: Array[TileMapLayer] = []


func setup(dir: Vector2, bullet_speed: float, bullet_damage: int) -> void:
	direction = dir.normalized()
	speed = bullet_speed
	danio = bullet_damage
	rotation = direction.angle()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_cache_tile_layers()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_age += delta

	if _age >= max_lifetime:
		queue_free()
		return

	if _age >= _room_grace and _left_the_room():
		queue_free()


func _cache_tile_layers() -> void:
	_tile_layers.clear()
	var root: Node = get_tree().current_scene
	if root == null:
		return
	_collect_tile_layers(root)


func _collect_tile_layers(node: Node) -> void:
	if node is TileMapLayer:
		_tile_layers.append(node as TileMapLayer)
	for child in node.get_children():
		_collect_tile_layers(child)


func _left_the_room() -> bool:
	if _tile_layers.is_empty():
		return false

	var on_floor := false
	for layer in _tile_layers:
		if not is_instance_valid(layer) or layer.tile_set == null:
			continue
		var cell: Vector2i = layer.local_to_map(layer.to_local(global_position))
		if layer.get_cell_source_id(cell) != -1:
			on_floor = true
			break
	return not on_floor


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemigos"):
		return

	if body.is_in_group("jugador"):
		_hit_player(body)
		queue_free()
		return

	if body is CharacterBody2D or body is StaticBody2D or body is AnimatableBody2D:
		queue_free()


func _hit_player(jugador: Node) -> void:
	var ctrl: Node = jugador
	if not ctrl.has_method("recibir_danio"):
		ctrl = jugador.get_node_or_null("controlador")
	if ctrl == null or not ctrl.has_method("recibir_danio"):
		return
	if "invulnerable" in ctrl and bool(ctrl.invulnerable):
		return
	ctrl.recibir_danio(danio)
	if ctrl.has_method("activar_invulnerabilidad"):
		ctrl.activar_invulnerabilidad()

	var sprite := jugador.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if sprite:
		var tween := jugador.create_tween()
		sprite.modulate = Color.CRIMSON
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)
