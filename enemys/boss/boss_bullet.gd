extends "res://area_2d.gd"
## Boss projectile. Reuses the safe projectile base (it ignores its shooter and
## every enemy, frees on the player / walls / lifetime) and additionally joins
## "boss_bullets" so the boss can wipe its own projectiles on death or phase
## change. Never damages the boss, and never spawns inside it (the boss offsets
## the spawn point by its radius).

func _ready() -> void:
	super()
	add_to_group("boss_bullets")