extends Node
## Session-wide unlock flags. Survives room/scene changes for the current run.
## Not an inventory: it only stores whether Candle has learned an ability.

var spectral_swords_unlocked: bool = false
## Set true the first time the Spectral Sword encounter enemy is spawned, so it
## can never be spawned twice in one run (survives scene reloads / transitions).
var spectral_guardian_spawned: bool = false
