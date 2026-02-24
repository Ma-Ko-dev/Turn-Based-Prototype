extends Node2D

@export var map_width: int = 50
@export var map_height: int = 50

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var decoration_layer: TileMapLayer = $DecorationLayer
@onready var obstacle_layer: TileMapLayer = $ObstacleLayer


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		generate_full_map()


func generate_full_map() -> void:
	ground_layer.clear()
	decoration_layer.clear()
	obstacle_layer.clear()
	
	for x in range(map_width):
		for y in range(map_height):
			# tile coords 8,5
			ground_layer.set_cell(Vector2i(x, y), 0, Vector2i(8, 5))
	_generate_organic_paths()
	_populate_objects()
	var map_manager = get_tree().get_first_node_in_group("map_manager")
	if map_manager and map_manager.has_method("update_astar_grid"):
		map_manager.update_astar_grid()


func _generate_organic_paths() -> void:
	var path_tiles = [Vector2i(1,0), Vector2i(2,0), Vector2i(3,0), Vector2i(4,0)]
	var curr = Vector2i(map_width / 2, map_width / 2)
	for i in range(400):
		decoration_layer.set_cell(curr, 0, path_tiles.pick_random())
		curr += [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT].pick_random()
		curr.x = clamp(curr.x, 0, map_width - 1)
		curr.y = clamp(curr.y, 0, map_height - 1)


func _populate_objects() -> void:
	for x in range(map_width):
		for y in range(map_height):
			var coords = Vector2i(x, y)
			if decoration_layer.get_cell_source_id(coords) != -1: continue # keep paths clear
			var roll = randf()
			if roll < 0.1:
				obstacle_layer.set_cell(coords, 0, [Vector2i(5,0), Vector2i(6,0), Vector2i(7,0), Vector2i(0,1), Vector2i(1,1), Vector2i(2,1)].pick_random())
