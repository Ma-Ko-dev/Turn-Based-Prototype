extends Node

var map_rng = RandomNumberGenerator.new()
var game_rng = RandomNumberGenerator.new()


func _ready() -> void:
	# Always start with a fresh random state
	setup_new_game()

func setup_new_game(custom_seed: int = -1) -> void:
	# If no seed is given, create a random one
	var final_seed = custom_seed if custom_seed != -1 else randi()
	# Fix the map generation to this seed
	map_rng.seed = final_seed
	# Keep gameplay truly random every time
	game_rng.randomize()
	print("Map Seed: ", final_seed)
