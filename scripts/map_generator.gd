@tool
extends Node2D

@export_group("Map Dimensions")
@export var map_width: int = 50
@export var map_height: int = 50
@export_group("Seed Settings")
@export var manual_seed: int = 0
var current_seed: int = 0
@export_group("Object Density")
@export_range(0.0, 1.0) var base_density: float = 0.05 # Base chance for a new cluster
@export_range(0.0, 1.0) var cluster_strength: float = 0.6 # Bonus chance if neighbor is a tree
@export_group("POI Settings")
@export var poi_count: int = 3
@export var poi_padding: int = 2
var _poi_zones: Array[Rect2i] = []
@export_group("Vegetation - Deciduous (Laub)")
@export var deciduous_double: Array[Vector2i] = [Vector2i(3,1)]
@export var deciduous_single: Array[Vector2i] = [Vector2i(2,1), Vector2i(4,1), Vector2i(5,1), Vector2i(4,2)]
@export_group("Vegetation - Pine (Nadel)")
@export var pine_double: Array[Vector2i] = [Vector2i(3,2)]
@export var pine_single: Array[Vector2i] = [Vector2i(0,1), Vector2i(1,1)]
@export_group("Vegetation - Details")
@export var tiles_shrubs: Array[Vector2i] = [Vector2i(0,2)]     # Small bushes/transition
@export var tiles_rocks: Array[Vector2i] = [Vector2i(5,2), Vector2i(6,2), Vector2i(18,6), Vector2i(19,6), Vector2i(20,6)] # Blockers like stumps/rocks
@export var tiles_grass_patches: Array[Vector2i] = [Vector2i(5,0), Vector2i(6,0), Vector2i(7,0)] # For bundled grass
@export_group("Tile Settings")
@export var tile_ground: Vector2i = Vector2i(0,0)
@export var tiles_path: Array[Vector2i] = [Vector2i(1,0), Vector2i(2,0), Vector2i(3,0), Vector2i(4,0)]
@export var tiles_obstacles: Array[Vector2i] = [
	Vector2i(5,0), Vector2i(6,0), Vector2i(7,0),
	Vector2i(0,1), Vector2i(1,1), Vector2i(2,1), Vector2i(3,1), Vector2i(4,1), Vector2i(5,1),
	Vector2i(0,2), Vector2i(1,2), Vector2i(2,2), Vector2i(3,2), Vector2i(4,2), Vector2i(5,2), Vector2i(6,2), 
]
@export var tiles_trees: Array[Vector2i] = [Vector2i(0,1), Vector2i(1,1), Vector2i(2,1), Vector2i(3,1), Vector2i(4,1), Vector2i(5,1), Vector2i(3,2), Vector2i(4,2)]
#@export var tiles_rocks: Array[Vector2i] = [Vector2i(5,2), Vector2i(6,2)] #, Vector2i(18,6), Vector2i(19,6), Vector2i(20,6)
@export var tiles_greenery: Array[Vector2i] = [Vector2i(5,0), Vector2i(6,0), Vector2i(7,0), Vector2i(0,2), Vector2i(21,2)] # Vector2i(13,6), Vector2i(14,6), Vector2i(15,6)
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
var _river_shore_cells: Dictionary = {}

@export_tool_button("Generate Map") var map_gen_button = func(): generate_full_map()


@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var decoration_layer: TileMapLayer = $DecorationLayer
@onready var obstacle_layer: TileMapLayer = $ObstacleLayer
@onready var rng = RandomNumberGenerator


func _ready() -> void:
	generate_full_map()

func _get_rng() -> RandomNumberGenerator:
	var new_rng = RandomNumberGenerator.new()
	# 1. Priority: Manual Editor Seed
	if manual_seed != 0:
		new_rng.seed = manual_seed
		print("MapGen: Using MANUAL seed: ", manual_seed)
	# 2. Priority: Use the seed from the global GameRNG singleton
	elif GameRNG.get("map_rng") != null:
		new_rng.seed = GameRNG.map_rng.seed
		print("MapGen: Using GameRNG seed: ", new_rng.seed)
	# 3. Fallback: Full Random (should rarely happen with the GameRoot setup)
	else:
		new_rng.randomize()
		print("MapGen: Using FALLBACK random seed: ", new_rng.seed)
	current_seed = new_rng.seed
	return new_rng

func generate_full_map() -> void:
	rng = _get_rng() # Always refresh the RNG instance/seed first
	_poi_zones.clear()
	_clear_layers()
	_fill_ground()
	if rng.randf() < 0.5:
		_generate_river()
		is_river_generated = true
	else:
		# just to be sure
		is_river_generated = false
	_generate_organic_paths()
	if is_river_generated and not _has_bridge():
		_force_bridge_connection()
	_place_all_unique_pois()
	#_populate_objects()
	#_populate_objects_v2()
	_populate_objects_v3()
	_sync_systems()

func _pick_seeded(list: Array):
	if list.is_empty(): return null
	return list[rng.randi() % list.size()]

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
	var h_start = Vector2i(0, rng.randi_range(5, map_height - 5))
	var h_end = Vector2i(map_width - 1, rng.randi_range(5, map_height - 5))
	_create_path_connection(h_start, h_end)
	if not is_river_generated:
		if rng.randf() < 0.5: # have a chance to generate a second road when river is not present
			var v_start = Vector2i(rng.randi_range(5, map_width - 5), 0)
			var v_end = Vector2i(rng.randi_range(5, map_width - 5), map_height - 1)
			_create_path_connection(v_start, v_end)

func _generate_river() -> void:
	_river_shore_cells.clear()
	# Choose river style
	if rng.randf() < 0.5:
		_current_river_straight = tile_river_straight_big
		_current_river_curve = tile_river_curve_big
	else:
		_current_river_straight = tile_river_straight_small
		_current_river_curve = tile_river_curve_small
	# Random start on the left edge
	var curr = Vector2i(0, rng.randi_range(10, map_height - 10))
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
			if turn_cooldown == 0 and segment_counter >= 3 and rng.randf() < 0.15:
				var possible_turns = []
				if curr.y > 10: possible_turns.append(Vector2i.UP)
				if curr.y < map_height - 10: possible_turns.append(Vector2i.DOWN)
				if possible_turns.size() > 0:
					next_dir = _pick_seeded(possible_turns)
		else:
			if segment_counter >= 4 and rng.randf() < 0.3:
				next_dir = Vector2i.RIGHT
				turn_cooldown = 10
		if curr.y < 4 and next_dir == Vector2i.UP:
			next_dir = Vector2i.RIGHT
			turn_cooldown = 10
		elif curr.y > map_height - 4 and next_dir == Vector2i.DOWN: 
			next_dir = Vector2i.RIGHT
			turn_cooldown = 10
		_place_river_tile_smart(curr, dir, next_dir)
		_mark_river_shore(curr)
		if next_dir != dir:
			segment_counter = 0
		else:
			segment_counter += 1
		curr += next_dir
		dir = next_dir
		if curr.x >= map_width: break

# Marks cells around a river tile as shore
func _mark_river_shore(pos: Vector2i) -> void:
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var shore_pos = pos + Vector2i(dx, dy)
			var dist = abs(dx) + abs(dy)
			if dist <= 3:
				if not _river_shore_cells.has(shore_pos) or _river_shore_cells[shore_pos] > dist:
					_river_shore_cells[shore_pos] = dist

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
			if rng.randf() < 0.5 and curr.x != end.x:
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
		decoration_layer.set_cell(pos, 0, _pick_seeded(tiles_path))

func _force_bridge_connection() -> void:
	# Find all vertical river tiles (straight) in the middle area
	var candidates: Array[Vector2i] = []
	for x in range(10, map_width - 2):
		for y in range(10, map_height - 2):
			var pos = Vector2i(x,y)
			# Better to place a bridge on a straight vertical river
			if obstacle_layer.get_cell_atlas_coords(pos) == tile_river_straight_big or obstacle_layer.get_cell_atlas_coords(pos) == tile_river_straight_small:
				candidates.append(pos)
	if candidates.is_empty(): return
	var bridge_pos = _pick_seeded(candidates)
	# Get the rotation/flip flags of the river tile
	var river_alt = obstacle_layer.get_cell_alternative_tile(bridge_pos)
	# If TRANSFORM_TRANSPOSE is set, the river flows horizontal.
	# If not, it flows vertical.
	var river_is_horizontal = (river_alt & TileSetAtlasSource.TRANSFORM_TRANSPOSE) != 0
	if river_is_horizontal:
		# River flows Left-Right -> Bridge must be Vertical
		var alt = TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
		decoration_layer.set_cell(bridge_pos, 0, tile_bridge_v, alt)
		decoration_layer.set_cell(bridge_pos + Vector2i.UP, 0, _pick_seeded(tiles_path))
		decoration_layer.set_cell(bridge_pos + Vector2i.DOWN, 0, _pick_seeded(tiles_path))
	else:
		# River flows Up-Down -> Bridge must be Horizontal
		decoration_layer.set_cell(bridge_pos, 0, tile_bridge_h, 0)
		decoration_layer.set_cell(bridge_pos + Vector2i.LEFT, 0, _pick_seeded(tiles_path))
		decoration_layer.set_cell(bridge_pos + Vector2i.RIGHT, 0, _pick_seeded(tiles_path))

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

func _populate_objects_v2() -> void:
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.08 # Higher = smaller, more frequent clusters
	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y)
			# TODO:Put this in a func later
			var is_in_poi_zone = false
			for zone in _poi_zones:
				if zone.has_point(pos):
					is_in_poi_zone = true
					break
			# Skip paths, POIs and River
			if decoration_layer.get_cell_source_id(pos) != -1: continue
			if obstacle_layer.get_cell_source_id(pos) != -1: continue
			if is_in_poi_zone: continue
			var val = noise.get_noise_2dv(Vector2(x,y)) # Returns -1.0 to 1.0
			if val > 0.45:
				# forest zone
				if randf() < 0.8:
					obstacle_layer.set_cell(pos, 0, tiles_trees.pick_random())
				else:
					obstacle_layer.set_cell(pos, 0, tiles_greenery.pick_random())
			elif val > 0.25:
				# Transition Zone / Meadows
				var chance = randf()
				if chance < 0.4:
					decoration_layer.set_cell(pos, 0, tiles_trees.pick_random())
				elif chance < 0.7:
					obstacle_layer.set_cell(pos, 0, tiles_rocks.pick_random())
				else:
					decoration_layer.set_cell(pos, 0, tiles_greenery.pick_random())
			else:
				if randf() < 0.15:
					decoration_layer.set_cell(pos, 0, tiles_greenery.pick_random())
				elif randf() < 0.02:
					decoration_layer.set_cell(pos, 0, tiles_rocks.pick_random())

func _populate_objects_v3() -> void:
	var forest_rng = RandomNumberGenerator.new()
	forest_rng.seed = rng.seed + 100 # Offset
	var noise = FastNoiseLite.new()
	noise.seed = forest_rng.randi()
	# Slightly higher frequency for smaller maps to get more "features"
	noise.frequency = 0.07 
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	var is_pine_map = forest_rng.randf() < 0.5
	var core_trees = pine_double if is_pine_map else deciduous_double
	var edge_trees = pine_single if is_pine_map else deciduous_single
	
	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y)
			if _is_occupied_or_path(pos): continue
			# River Gras Logic
			if _river_shore_cells.has(pos): 
				var dist = _river_shore_cells[pos]
				var chance = 0.0
				if dist <= 1: chance = 0.8
				elif dist <= 2: chance = 0.4
				else: chance = 0.1
				if forest_rng.randf() < chance:
					var shrub_chance = 0.1 if dist <= 1 else 0.25
					if forest_rng.randf() < shrub_chance:
						_place_veg(decoration_layer, pos, tiles_shrubs, false)
					else:
						_place_veg(decoration_layer, pos, tiles_grass_patches, true)
					continue
			# Forest generation
			var val = noise.get_noise_2dv(Vector2(x,y))
			# Raised thresholds to create more open space on small maps
			if val > 0.45: # Was 0.35 -> Fewer core trees
				_place_veg(obstacle_layer, pos, core_trees, false)
			elif val > 0.25: # Was 0.15 -> Narrower forest edge
				_place_veg(obstacle_layer, pos, edge_trees, false)
			elif val > 0.05:
				if forest_rng.randf() < 0.3:
					_place_veg(decoration_layer, pos, tiles_shrubs, false)
				else:
					_place_veg(decoration_layer, pos, tiles_grass_patches, true)
			elif val < -0.4:
				if forest_rng.randf() < 0.9:
					_place_veg(decoration_layer, pos, tiles_grass_patches, true)
				else:
					if forest_rng.randf() < 0.1:
						_place_veg(decoration_layer, pos, tiles_shrubs, false)
			else: # THE REST (Open Meadow)
				# Only very few stray grass blades to keep it clean
				if forest_rng.randf() < 0.005:
					_place_veg(obstacle_layer, pos, tiles_rocks, false)
					#obstacle_layer.set_cell(pos, 0, _pick_seeded(tiles_rocks), alt)

# Helper to keep the loop clean
func _is_occupied_or_path(pos: Vector2i) -> bool:
	if decoration_layer.get_cell_source_id(pos) != -1: return true
	if obstacle_layer.get_cell_source_id(pos) != -1: return true
	for zone in _poi_zones:
		if zone.has_point(pos): return true
	return false

# Returns a random flip/transpose combination for tiles
func _get_random_flip(allow_vertical: bool = true) -> int:
	var flip_h = rng.randi() % 2 == 0
	var flip_v = (rng.randi() % 2 == 0) if allow_vertical else false
	var transpose = (rng.randi() % 2 == 0) if allow_vertical else false
	var alt = 0
	if flip_h: alt |= TileSetAtlasSource.TRANSFORM_FLIP_H
	if flip_v: alt |= TileSetAtlasSource.TRANSFORM_FLIP_V
	if transpose: alt |= TileSetAtlasSource.TRANSFORM_TRANSPOSE
	return alt

# Centralized helper for placing vegetation with random flips
func _place_veg(layer: TileMapLayer, pos: Vector2i, list: Array[Vector2i], allow_v_flip: bool = true) -> void:
	var coords = _pick_seeded(list)
	var alt = _get_random_flip(allow_v_flip)
	layer.set_cell(pos, 0, coords, alt)

func _place_all_unique_pois() -> void:
	var tileset = obstacle_layer.tile_set
	var count = tileset.get_patterns_count()
	if count == 0:
		push_warning("MapGenerator: No patterns found in TileSet!")
		return
	# Create a dedicated RNG for POI shuffling and placement
	# This prevents POI logic from "stealing" numbers from the global RNG
	var poi_rng = RandomNumberGenerator.new()
	poi_rng.seed = rng.seed + 500 # seperate offset
	# Create and shuffle indices to ensure each POI is unique
	var indices = []
	for i in range(count):
		indices.append(i)
	#indices.shuffle()
	_shuffle_array_seeded(indices, poi_rng)
	var to_place = clampi(poi_count, 0, count)
	for i in range(to_place):
		_attempt_pattern_placement(indices[i], poi_rng)

func _shuffle_array_seeded(arr: Array, custom_rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() -1, 0, -1):
		var j = custom_rng.randi() % (i + 1)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp

func _attempt_pattern_placement(pattern_idx: int, poi_rng: RandomNumberGenerator) -> void:
	var pattern = obstacle_layer.tile_set.get_pattern(pattern_idx)
	var p_size = pattern.get_size()
	for attempt in range(100):
		var x = poi_rng.randi_range(poi_padding + 1, map_width - p_size.x - poi_padding - 1)
		var y = poi_rng.randi_range(poi_padding + 1, map_height - p_size.y - poi_padding - 1)
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
			
