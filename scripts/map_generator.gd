@tool
extends Node2D

@export_group("Map Dimensions")
@export var map_width: int = 50
@export var map_height: int = 50
@export_group("Object Density")
@export_range(0.0, 1.0) var base_density: float = 0.05 # Base chance for a new cluster
@export_range(0.0, 1.0) var cluster_strength: float = 0.6 # Bonus chance if neighbor is a tree
@export_group("POI Settings")
@export var poi_count: int = 3
@export var poi_padding: int = 2
var _poi_zones: Array[Rect2i] = []
@export_group("Tile Settings")
@export var tile_ground: Vector2i = Vector2i(0,0)
@export var tiles_path: Array[Vector2i] = [Vector2i(1,0), Vector2i(2,0), Vector2i(3,0), Vector2i(4,0)]
@export var tiles_obstacles: Array[Vector2i] = [
	Vector2i(5,0), Vector2i(6,0), Vector2i(7,0),
	Vector2i(0,1), Vector2i(1,1), Vector2i(2,1), Vector2i(3,1), Vector2i(4,1), Vector2i(5,1),
	Vector2i(0,2), Vector2i(1,2), Vector2i(2,2), Vector2i(3,2), Vector2i(4,2), Vector2i(5,2), Vector2i(6,2), 
]
@export_group("River Settings")
@export var tile_river_straight_big: Vector2i = Vector2i(8,4)
@export var tile_river_curve_big: Vector2i = Vector2i(9,4)
@export var tile_river_straight_small: Vector2i = Vector2i(12,5)
@export var tile_river_curve_small: Vector2i = Vector2i(13,5)
@export var tile_bridge_h: Vector2i = Vector2i(6,5)
@export var tile_bridge_v: Vector2i = Vector2i(7,5)
var _current_river_straight: Vector2i
var _current_river_curve: Vector2i
var is_river_generated = false
@export_tool_button("Generate Map") var map_gen_button = func(): generate_full_map()


@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var decoration_layer: TileMapLayer = $DecorationLayer
@onready var obstacle_layer: TileMapLayer = $ObstacleLayer


func _ready() -> void:
	generate_full_map()

func generate_full_map() -> void:
	_poi_zones.clear()
	_clear_layers()
	_fill_ground()
	if randf() < 0.5:
		_generate_river()
		is_river_generated = true
	else:
		# just to be sure
		is_river_generated = false
	_generate_organic_paths()
	if is_river_generated and not _has_bridge():
		_force_bridge_connection()
	_place_all_unique_pois()
	_populate_objects()
	_sync_systems()

func _clear_layers() -> void:
	ground_layer.clear()
	decoration_layer.clear()
	obstacle_layer.clear()

func _fill_ground() -> void:
	for x in range(map_width):
		for y in range(map_height):
			# make sure to use the alternative 1 of the tile_ground
			ground_layer.set_cell(Vector2i(x, y), 0, tile_ground)

func _sync_systems() -> void:
	var map_manager = get_tree().get_first_node_in_group("map_manager")
	if map_manager and map_manager.has_method("update_astar_grid"):
		map_manager.update_astar_grid()
	var player = get_tree().get_first_node_in_group("players")
	if player and player.has_method("update_camera_limits"):
		player.update_camera_limits()

func _generate_organic_paths() -> void:
	var h_start = Vector2i(0, randi_range(5, map_height - 5))
	var h_end = Vector2i(map_width - 1, randi_range(5, map_height - 5))
	_create_path_connection(h_start, h_end)
	if not is_river_generated:
		if randf() < 0.5: # have a chance to generate a second road when river is not present
			var v_start = Vector2i(randi_range(5, map_width - 5), 0)
			var v_end = Vector2i(randi_range(5, map_width - 5), map_height - 1)
			_create_path_connection(v_start, v_end)

func _generate_river() -> void:
	# Choose river style
	if randf() < 0.5:
		_current_river_straight = tile_river_straight_big
		_current_river_curve = tile_river_curve_big
	else:
		_current_river_straight = tile_river_straight_small
		_current_river_curve = tile_river_curve_small
	# Random start on the left edge
	var curr = Vector2i(0, randi_range(10, map_height - 10))
	var dir = Vector2i.RIGHT
	var steps = 0
	var segment_counter = 0
	var turn_cooldown = 0
	while curr.x < map_width and steps < 1000:
		steps += 1
		var next_dir = dir
		if turn_cooldown > 0:
			turn_cooldown -= 1
		if dir == Vector2i.RIGHT:
			if turn_cooldown == 0 and segment_counter >= 3 and randf() < 0.15:
				var possible_turns = []
				if curr.y > 10: possible_turns.append(Vector2i.UP)
				if curr.y < map_height - 10: possible_turns.append(Vector2i.DOWN)
				if possible_turns.size() > 0:
					next_dir = possible_turns.pick_random()
		else:
			if segment_counter >= 4 and randf() < 0.3:
				next_dir = Vector2i.RIGHT
				turn_cooldown = 10
		if curr.y < 4 and next_dir == Vector2i.UP:
			next_dir = Vector2i.RIGHT
			turn_cooldown = 10
		elif curr.y > map_height - 4 and next_dir == Vector2i.DOWN: 
			next_dir = Vector2i.RIGHT
			turn_cooldown = 10
		_place_river_tile_smart(curr, dir, next_dir)
		if next_dir != dir:
			segment_counter = 0
		else:
			segment_counter += 1
		curr += next_dir
		dir = next_dir
		if curr.x >= map_width: break

func _place_river_tile_smart(pos: Vector2i, from_dir: Vector2i, to_dir: Vector2i) -> void:
	var atlas: Vector2i
	var alternative = 0
	var flip_h = TileSetAtlasSource.TRANSFORM_FLIP_H
	var flip_v = TileSetAtlasSource.TRANSFORM_FLIP_V
	var transpose = TileSetAtlasSource.TRANSFORM_TRANSPOSE
	if from_dir == to_dir:
		atlas = _current_river_straight
		if from_dir.x != 0:
			alternative = transpose | flip_h
	else:
		atlas = _current_river_curve
		# from_dir is the movement that BROUGHT us here
		# to_dir is the movement we take LEAVING here
		# To fit the tile, we need the OPPOSITE of from_dir (where the water enters)
		var entry = -from_dir 
		var exit = to_dir
		# Now we check which two sides of the tile are connected
		if (entry == Vector2i.DOWN and exit == Vector2i.RIGHT) or (entry == Vector2i.RIGHT and exit == Vector2i.DOWN):
			alternative = 0 # Your base Right-Curve
		elif (entry == Vector2i.DOWN and exit == Vector2i.LEFT) or (entry == Vector2i.LEFT and exit == Vector2i.DOWN):
			alternative = flip_h
		elif (entry == Vector2i.UP and exit == Vector2i.RIGHT) or (entry == Vector2i.RIGHT and exit == Vector2i.UP):
			alternative = flip_v
		elif (entry == Vector2i.UP and exit == Vector2i.LEFT) or (entry == Vector2i.LEFT and exit == Vector2i.UP):
			alternative = flip_h | flip_v
	# FML this took way too long T_T
	obstacle_layer.set_cell(pos, 0, atlas, alternative)

func _create_path_connection(start: Vector2i, end: Vector2i) -> void:
	if tiles_path.is_empty():
		push_error("MapGenerator: tiles_path is empty! Check Inspector.")
		return
	var curr = start
	var steps = 0
	var max_steps = map_width * map_height 
	var last_was_horizontal = true
	_place_path_or_bridge(curr, last_was_horizontal)
	while curr != end and steps < max_steps:
		steps += 1
		var is_horizontal = last_was_horizontal
		if _is_river_at(curr):
			if last_was_horizontal:
				curr.x += (1 if end.x > curr.x else -1)
			else:
				curr.y += (1 if end.y > curr.y else -1)
		else:
			if randf() < 0.5 and curr.x != end.x:
				var next_x = curr.x + (1 if end.x > curr.x else -1)
				curr.x = next_x
				is_horizontal = true
			elif curr.y != end.y:
				var next_y = curr.y + (1 if end.y > curr.y else -1)
				curr.y = next_y
				is_horizontal = false
			else:
				curr.x += (1 if end.x > curr.x else -1)
				is_horizontal = true
		last_was_horizontal = is_horizontal
		_place_path_or_bridge(curr, is_horizontal)

func _is_river_at(pos: Vector2i) -> bool:
	var tile = obstacle_layer.get_cell_atlas_coords(pos)
	return tile == tile_river_straight_big or tile == tile_river_curve_big or \
		   tile == tile_river_straight_small or tile == tile_river_curve_small

func _place_path_or_bridge(pos: Vector2i, moving_horizontal: bool) -> void:
	# Check if the ground layer has any river tile at this pos
	# Check the source_id to see if it's part of the tileset (assuming ID 0)
	if _is_river_at(pos):
		var bridge = tile_bridge_h
		var alternative = 0
		if not moving_horizontal:
			bridge = tile_bridge_v
			alternative = TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
		decoration_layer.set_cell(pos, 0, bridge, alternative)
	else:
		decoration_layer.set_cell(pos, 0, tiles_path.pick_random())

func _force_bridge_connection() -> void:
	# Find all vertical river tiles (straight) in the middle area
	var candidates: Array[Vector2i] = []
	for x in range(10, map_width - 10):
		for y in range(10, map_height - 10):
			var pos = Vector2i(x,y)
			# Better to place a bridge on a straight vertical river
			if obstacle_layer.get_cell_atlas_coords(pos) == tile_river_straight_big or obstacle_layer.get_cell_atlas_coords(pos) == tile_river_straight_small:
				candidates.append(pos)
	if candidates.is_empty(): return
	var bridge_pos = candidates.pick_random()
	# Get the rotation/flip flags of the river tile
	var river_alt = obstacle_layer.get_cell_alternative_tile(bridge_pos)
	# If TRANSFORM_TRANSPOSE is set, the river flows horizontal.
	# If not, it flows vertical.
	var river_is_horizontal = (river_alt & TileSetAtlasSource.TRANSFORM_TRANSPOSE) != 0
	if river_is_horizontal:
		# River flows Left-Right -> Bridge must be Vertical
		var alt = TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
		decoration_layer.set_cell(bridge_pos, 0, tile_bridge_v, alt)
		decoration_layer.set_cell(bridge_pos + Vector2i.UP, 0, tiles_path.pick_random())
		decoration_layer.set_cell(bridge_pos + Vector2i.DOWN, 0, tiles_path.pick_random())
	else:
		# River flows Up-Down -> Bridge must be Horizontal
		decoration_layer.set_cell(bridge_pos, 0, tile_bridge_h, 0)
		decoration_layer.set_cell(bridge_pos + Vector2i.LEFT, 0, tiles_path.pick_random())
		decoration_layer.set_cell(bridge_pos + Vector2i.RIGHT, 0, tiles_path.pick_random())

func _has_bridge() -> bool:
	# Iterate through decoration layer to find any bridge tile
	for x in range(map_width):
		for y in range(map_height):
			var coords = Vector2i(x,y)
			var atlas = decoration_layer.get_cell_atlas_coords(coords)
			if atlas == tile_bridge_h or atlas == tile_bridge_v:
				return true
	return false

func _populate_objects() -> void:
	for x in range(map_width):
		for y in range(map_height):
			var coords = Vector2i(x, y)
			if decoration_layer.get_cell_source_id(coords) != -1: continue # keep paths clear
			var is_in_poi_zone = false
			for zone in _poi_zones:
				if zone.has_point(coords):
					is_in_poi_zone = true
					break
			if is_in_poi_zone: continue
			# IMPORTANT: Keep POIs clear!
			# If there's already something in the obstacle_layer, dont overwrite it.
			if obstacle_layer.get_cell_source_id(coords) != -1: continue
			var chance = base_density
			# Check if left or top neighbor is already a tree
			var has_neighbor = false
			if obstacle_layer.get_cell_source_id(coords + Vector2i.LEFT) != -1: has_neighbor = true
			if obstacle_layer.get_cell_source_id(coords + Vector2i.UP) != -1: has_neighbor = true
			# If neighbor exists, drastically increase chance
			if has_neighbor:
				chance += cluster_strength
			if randf() < chance:
				obstacle_layer.set_cell(coords, 0, tiles_obstacles.pick_random())
			
func _place_all_unique_pois() -> void:
	var tileset = obstacle_layer.tile_set
	var count = tileset.get_patterns_count()
	if count == 0:
		push_warning("MapGenerator: No patterns found in TileSet!")
	# Create and shuffle indices to ensure each POI is unique
	var indices = []
	for i in range(count):
		indices.append(i)
	indices.shuffle()
	var to_place = clampi(poi_count, 0, count)
	for i in range(to_place):
		_attempt_pattern_placement(indices[i])
	
func _attempt_pattern_placement(pattern_idx: int) -> void:
	var pattern = obstacle_layer.tile_set.get_pattern(pattern_idx)
	var p_size = pattern.get_size()
	for attempt in range(100):
		var x = randi_range(poi_padding + 1, map_width - p_size.x - poi_padding - 1)
		var y = randi_range(poi_padding + 1, map_height - p_size.y - poi_padding - 1)
		var pos = Vector2i(x, y)
		if _is_area_clear_for_poi(pos, p_size, poi_padding):
			_clear_area_for_poi(pos, p_size)
			obstacle_layer.set_pattern(pos, pattern)
			# Register the zone including an extra buffer tile
			var zone = Rect2i(pos.x - 1, pos.y - 1, p_size.x + 2, p_size.y + 2)
			_poi_zones.append(zone)
			return
	
func _is_area_clear_for_poi(pos: Vector2i, size: Vector2i, pad: int) -> bool:
	for x in range(pos.x - pad, pos.x + size.x + pad):
		for y in range(pos.y - pad, pos.y + size.y + pad):
			var check_pos = Vector2i(x,y)
			if check_pos.x < 0 or check_pos.x >= map_width or check_pos.y < 0 or check_pos.y >= map_height:
				return false
			if decoration_layer.get_cell_source_id(check_pos) != -1:
				return false
			for zone in _poi_zones:
				if zone.has_point(check_pos):
					return false
			var atlas_coords = obstacle_layer.get_cell_atlas_coords(check_pos)
			if atlas_coords == tile_river_straight_big or atlas_coords == tile_river_curve_big or \
			atlas_coords == tile_river_straight_small or atlas_coords == tile_river_curve_small:
				return false
	return true
	
func _clear_area_for_poi(pos: Vector2i, size: Vector2i) -> void:
	for x in range(pos.x, pos.x + size.x):
		for y in range(pos.y, pos.y + size.y):
			obstacle_layer.erase_cell(Vector2i(x,y))
			
