@tool
extends Node2D

#region --- Exports & Variables ---
@export_group("Map Dimensions")
@export var map_width: int = 50
@export var map_height: int = 50

@export_group("Seed Settings")
@export var manual_seed: int = 0
var current_seed: int = 0

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
@export var tiles_road_straight: Vector2i = Vector2i(8,1)
@export var tiles_road_curve: Vector2i = Vector2i(9,1)
@export var tiles_road_t_junction: Vector2i = Vector2i(10,1)
@export var tiles_road_x_junction: Vector2i = Vector2i(11,1)
@export var tiles_path_placeholder: Array[Vector2i] = [Vector2i(23,2)]
var _path_endpoints: Array[Vector2i] = []

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
#endregion
#region --- Core Logic ---
func _ready() -> void:
	generate_full_map()

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
	_populate_objects()
	_setup_player_spawn()
	_sync_systems()

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

func _sync_systems() -> void:
	var map_manager = get_tree().get_first_node_in_group("map_manager")
	if map_manager and map_manager.has_method("update_astar_grid"):
		map_manager.update_astar_grid()
	var player = get_tree().get_first_node_in_group("players")
	if player and player.has_method("update_camera_limits"):
		player.update_camera_limits()
#endregion
#region --- River Generation ---
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

# Marks cells around a river tile as shore
func _mark_river_shore(pos: Vector2i) -> void:
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var shore_pos = pos + Vector2i(dx, dy)
			var dist = abs(dx) + abs(dy)
			if dist <= 3:
				if not _river_shore_cells.has(shore_pos) or _river_shore_cells[shore_pos] > dist:
					_river_shore_cells[shore_pos] = dist

func _is_river_at(pos: Vector2i) -> bool:
	var tile = obstacle_layer.get_cell_atlas_coords(pos)
	return tile == tile_river_straight_big or tile == tile_river_curve_big or \
		   tile == tile_river_straight_small or tile == tile_river_curve_small
#endregion
#region --- Path & Bridge Logic ---
func _generate_organic_paths() -> void:
	_path_endpoints.clear()
	# 1. Main Road (West to East)
	var h_start = Vector2i(0, rng.randi_range(15, map_height - 15))
	var h_end = Vector2i(map_width - 1, rng.randi_range(15, map_height - 15))
	_path_endpoints.append(h_start)
	_path_endpoints.append(h_end)
	_create_path_connection(h_start, h_end, true)
	# 2. Exactly one organic side road from a straight segment
	if not is_river_generated and rng.randf() < 0.8:
		_generate_road_from_main_to_edge()
	_refine_all_paths()

func _create_path_connection(start: Vector2i, end: Vector2i, is_main_road: bool) -> void:
	var curr = start
	var steps = 0
	var max_steps = map_width * map_height
	_place_path_or_bridge(curr, true)
	while curr != end and steps < max_steps:
		steps += 1
		var next_step = curr
		# Check for main road nearby to start straightening up
		var road_nearby = false
		if not is_main_road:
			# Look ahead in Y direction to see if the main road is close
			var check_dir = Vector2i(0, 1 if end.y > curr.y else -1)
			for dist in range(1, 5): # Check up to 4 tiles ahead
				if _is_path_or_bridge(curr + (check_dir * dist)):
					road_nearby = true
					break
		#  Movement logic
		if not is_main_road and road_nearby:
			# Force straight vertical approach when close
			next_step.y += (1 if end.y > curr.y else -1)
		else:
			#  Increased sway for more organic look (0.4 instead of 0.2)
			var sway = 0.5 if is_main_road else 0.4 
			if rng.randf() < sway and curr.x != end.x:
				next_step.x += (1 if end.x > curr.x else -1)
			elif curr.y != end.y:
				next_step.y += (1 if end.y > curr.y else -1)
			else:
				next_step.x += (1 if end.x > curr.x else -1)
		#  Collision: Stop when hitting existing road
		if not is_main_road and _is_path_or_bridge(next_step):
			_place_path_or_bridge(next_step, false)
			break 
		#  River logic
		if _is_river_at(next_step):
			_place_path_or_bridge(next_step, (next_step.x != curr.x))
			next_step += (next_step - curr)
		if not is_main_road and _is_too_close_to_existing_path(next_step, start):
			pass
		curr = next_step
		_place_path_or_bridge(curr, (curr.x != start.x))

func _generate_road_from_main_to_edge() -> void:
	var valid_starts = []
	# Slightly tighter horizontal constraints for start search
	for x in range(15, map_width - 15):
		for y in range(5, map_height - 5):
			var pos = Vector2i(x, y)
			if _is_path_or_bridge(pos):
				#  Must be a horizontal straight segment
				if _is_path_or_bridge(pos + Vector2i.LEFT) and _is_path_or_bridge(pos + Vector2i.RIGHT):
					if not _is_path_or_bridge(pos + Vector2i.UP) and not _is_path_or_bridge(pos + Vector2i.DOWN):
						valid_starts.append(pos)
	if valid_starts.is_empty(): return
	var v_start = _pick_seeded(valid_starts)
	var go_up = rng.randf() < 0.5
	var v_end = Vector2i(rng.randi_range(5, map_width - 5), 0 if go_up else map_height - 1)
	# Ensure it's not too vertical, keep it diagonal
	if abs(v_end.x - v_start.x) < 10:
		v_end.x = clamp(v_start.x + (15 if rng.randf() < 0.5 else -15), 5, map_width - 5)
	_path_endpoints.append(v_end)
	#  --- MANUALLY START THE ROAD STRAIGHT ---
	var curr = v_start
	var step_dir = Vector2i.UP if go_up else Vector2i.DOWN
	for i in range(3): # Force 3 tiles strictly away from main road
		curr += step_dir
		if curr.y > 0 and curr.y < map_height - 1:
			_place_path_or_bridge(curr, false)
	# Now continue with the organic connection from the new position
	_create_path_connection(curr, v_end, true)

func _is_too_close_to_existing_path(pos: Vector2i, current_path_start: Vector2i) -> bool:
	# Check neighbors to avoid parallel paths
	# We ignore the immediate area of the starting point
	if pos.distance_to(current_path_start) < 4: return false
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var check = pos + Vector2i(dx, dy)
			if _is_path_or_bridge(check):
				return true
	return false

func _place_path_or_bridge(pos: Vector2i, moving_horizontal: bool) -> void:
	if _is_river_at(pos):
		# Select bridge orientation based on movement direction
		var bridge = tile_bridge_h
		var alternative = 0
		if not moving_horizontal:
			bridge = tile_bridge_v
			alternative = TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
		decoration_layer.set_cell(pos, 0, bridge, alternative)
	else:
		# Place a placeholder tile that will be replaced by _refine_all_paths laterh))
		decoration_layer.set_cell(pos, 0, Vector2i(23,2))

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

func _refine_all_paths() -> void:
	# Record all path coordinates before changing tiles to avoid neighbor detection errors
	var all_path_coords: Array[Vector2i] = []
	var used_cells = decoration_layer.get_used_cells()
	for pos in used_cells:
		if _is_path_or_bridge(pos):
			all_path_coords.append(pos)
	# Transform each path tile into the correct graphical representation
	for pos in all_path_coords:
		# Skip bridges - they are already correctly placed by bridge logic
		var atlas = decoration_layer.get_cell_atlas_coords(pos)
		if atlas == tile_bridge_h or atlas == tile_bridge_v:
			continue
		var neighbors = _get_path_neighbors(pos, all_path_coords)
		_place_smart_path_tile(pos, neighbors)

func _place_smart_path_tile(pos: Vector2i, n: Dictionary) -> void:
	# Use bitmasking to identify neighbor configuration (N=1, S=2, W=4, E=8)
	var mask = 0
	if n.up:	mask += 1
	if n.down:	mask += 2
	if n.left:	mask += 4
	if n.right:	mask += 8
	var atlas = tiles_road_straight
	var alt = 0
	# Constants for Godot Tile Transforms
	var flip_h = TileSetAtlasSource.TRANSFORM_FLIP_H
	var flip_v = TileSetAtlasSource.TRANSFORM_FLIP_V
	var transpose = TileSetAtlasSource.TRANSFORM_TRANSPOSE
	match mask:
		# --- Straight Tiles (8,1) ---
		1, 2, 3: atlas = tiles_road_straight; alt = 0 # North/South
		4, 8, 12: atlas = tiles_road_straight; alt = transpose # West/East
		# --- Curve Tiles (9,1) ---
		10: atlas = tiles_road_curve; alt = 0 # South + East
		6: atlas = tiles_road_curve; alt = flip_h # South + West
		9: atlas = tiles_road_curve; alt = flip_v # North + East
		5: atlas = tiles_road_curve; alt = flip_h | flip_v # North + West
		# --- T-Junctions (10,1) - Base is N+S+E (Links offen) ---
		11: atlas = tiles_road_t_junction; alt = 0 # North + South + East
		7: atlas = tiles_road_t_junction; alt = flip_h # North + South + West
		14: atlas = tiles_road_t_junction; alt = transpose # South + West + East (T von OBEN)
		13: atlas = tiles_road_t_junction; alt = transpose | flip_v # North + West + East (T von UNTEN)
		# --- X-Junction (11,1) ---
		15: atlas = tiles_road_x_junction; alt = 0
		_: atlas = tiles_road_straight; alt = 0
	decoration_layer.set_cell(pos, 0, atlas, alt)

func _get_path_neighbors(pos: Vector2i, all_paths: Array[Vector2i]) -> Dictionary:
	# Check neighbors, but assume a neighbor exists if we are at the map edge
	# This ensures paths look like they continue "outside" the map.
	return {
		"up": all_paths.has(pos + Vector2i.UP) or (pos.y == 0 and _path_endpoints.has(pos)),
		"down": all_paths.has(pos + Vector2i.DOWN) or (pos.y == map_height - 1 and _path_endpoints.has(pos)),
		"left": all_paths.has(pos + Vector2i.LEFT) or (pos.x == 0 and _path_endpoints.has(pos)),
		"right": all_paths.has(pos + Vector2i.RIGHT) or (pos.x == map_width - 1 and _path_endpoints.has(pos))
	}

func _is_path_or_bridge(pos: Vector2i) -> bool:
	var atlas = decoration_layer.get_cell_atlas_coords(pos)
	# Check for placeholders, refined paths, or bridges to define "what is a road"ridge
	var is_placeholder = tiles_path_placeholder.has(atlas)
	var is_refined = atlas.y == 1 and (atlas.x >= 8 and atlas.x <= 11)
	var is_bridge = (atlas == tile_bridge_h or atlas == tile_bridge_v)
	return is_placeholder or is_refined or is_bridge

func _has_bridge() -> bool:
	# Utility to check if at least one bridge exists on the map
	for x in range(map_width):
		for y in range(map_height):
			var coords = Vector2i(x,y)
			var atlas = decoration_layer.get_cell_atlas_coords(coords)
			if atlas == tile_bridge_h or atlas == tile_bridge_v:
				return true
	return false
#endregion
#region --- POI Placement ---
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
#endregion
#region --- Vegetation & Decoration ---
func _populate_objects() -> void:
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

# Centralized helper for placing vegetation with random flips
func _place_veg(layer: TileMapLayer, pos: Vector2i, list: Array[Vector2i], allow_v_flip: bool = true) -> void:
	var coords = _pick_seeded(list)
	var alt = _get_random_flip(allow_v_flip)
	layer.set_cell(pos, 0, coords, alt)
#endregion
#region --- Generic Helpers ---
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

# Helper to keep the loop clean
func _is_occupied_or_path(pos: Vector2i) -> bool:
	if decoration_layer.get_cell_source_id(pos) != -1: return true
	if obstacle_layer.get_cell_source_id(pos) != -1: return true
	for zone in _poi_zones:
		if zone.has_point(pos): return true
	return false

func _shuffle_array_seeded(arr: Array, custom_rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() -1, 0, -1):
		var j = custom_rng.randi() % (i + 1)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp

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
#endregion
#region --- Spawn Logic ---
func _setup_player_spawn() -> void:
	# Look specifically in the 'Markers' node
	var markers_node = get_node_or_null("Markers")
	if not markers_node:
		push_warning("MapGen: 'Markers' node not found!")
		return
	var player_marker: SpawnMarker = null
	for child in markers_node.get_children():
		if child is SpawnMarker and child.is_player_spawn:
			player_marker = child
			break
	if not player_marker:
		push_warning("MapGen: No Player SpawnMarker found inside 'Markers'!")
		return
	# Find all valid path tiles (excluding bridges)
	var path_candidates: Array[Vector2i] = []
	var all_road_types = [
		tiles_road_straight,
		tiles_road_curve,
		tiles_road_t_junction,
		tiles_road_x_junction
	]
	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y)
			var atlas = decoration_layer.get_cell_atlas_coords(pos)
			if atlas in all_road_types or _is_path_or_bridge(pos):
				path_candidates.append(pos)
	if path_candidates.is_empty():
		push_error("MapGen: No paths found for player spawn!")
		return
	# Pick a random path and move the marker
	var spawn_grid_pos = _pick_seeded(path_candidates)
	# Important: map_to_local is relative to the TileMapLayer's position
	# We set the marker's GLOBAL position to avoid parent offset issues
	var world_pos = decoration_layer.to_global(decoration_layer.map_to_local(spawn_grid_pos))
	player_marker.global_position = world_pos
	print("MapGen: Player moved to path at ", spawn_grid_pos)
#endregion
