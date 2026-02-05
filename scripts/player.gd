extends Unit

# --- Tilemap Layer References ---
var movement_label: Label
var preview_layer: TileMapLayer
var selection_layer: TileMapLayer

# --- Misc ---
@onready var camera: Camera2D = $Camera2D


func _ready():
	super._ready()
	if camera:
		camera.enabled = true
		# Zoom setting
		#(1, 1) is default, (0.5, 0,5) is 2x zoom out
		camera.zoom = Vector2(0.6, 0.6)
		# Make camera as active camera
		camera.make_current()
	update_ui()


func _input(event):
	# Ignore input if it's combat and not this unit's turn
	if TurnManager.current_state == TurnManager.State.COMBAT and not is_active_unit:
		return
	
	# Mouse Click Handling
	if event is InputEventMouseButton and event.pressed:
		# Left Click: Selection / Deselection
		if event.button_index == MOUSE_BUTTON_LEFT:
			var clicked_cell = map_manager.get_grid_coords(get_global_mouse_position())
			
			if clicked_cell == grid_pos:
				is_selected = true
			else:
				is_selected = false
			
			update_selection_visual()
			
		# Right Click: Movement Execution
		if event.button_index == MOUSE_BUTTON_RIGHT and is_selected and !is_moving:
			var clicked_cell = map_manager.get_grid_coords(get_global_mouse_position())
			
			# Security checks for valid destination
			if not astar_grid.is_in_boundsv(clicked_cell):
				preview_layer.clear()
				return
			if clicked_cell == grid_pos:
				return
				
			# Calculate path and cost to target
			var result = get_path_and_cost(clicked_cell)
			if not result["path"].is_empty() and result["cost"] <= remaining_movement:
				execute_movement(result["path"], result["cost"])
	
	# Turn End & Mode Switching
	if Input.is_action_just_pressed("ui_accept"): # Default 'Enter'
		if TurnManager.current_state == TurnManager.State.EXPLORATION:
			# Exploration Mode: Refresh movement and finish 'turn'
			start_new_turn()
			TurnManager.end_exploration_turn()
		else:
			# Combat Mode: Clean up visuals and pass turn to next unit
			is_active_unit = false
			is_selected = false
			update_selection_visual()
			preview_layer.clear()
			TurnManager.next_combat_turn()
	
	# Debug/Manual Trigger: Start Combat
	if Input.is_action_just_pressed("ui_focus_next"): # Default 'Tab'
		if TurnManager.current_state == TurnManager.State.EXPLORATION:
			TurnManager.start_combat()


func _process(_delta):
	# Stop drawing path previews if it's not our turn
	if TurnManager.current_state == TurnManager.State.COMBAT and not is_active_unit:
		preview_layer.clear()
		return
		
	# Draw movement preview while selected and hovering
	if is_selected and !is_moving:
		var hovered_cell = map_manager.get_grid_coords(get_global_mouse_position())
		preview_layer.clear()
		
		if not astar_grid.is_in_boundsv(hovered_cell):
			return
			
		if hovered_cell != grid_pos:
			var result = get_path_and_cost(hovered_cell)
			var path = result["path"]
			var total_cost = result["cost"]
			
			if not path.is_empty():
				draw_path_preview(path)
				update_preview(hovered_cell, total_cost)
	else:
		preview_layer.clear()


func setup_player_references(m_manager, m_label, p_layer, s_layer):
	map_manager = m_manager
	movement_label = m_label
	preview_layer = p_layer
	selection_layer = s_layer
	# --- Camera Limits ---
	# Set the camera boundaries based on the map size
	if camera and map_manager:
		var bounds = map_manager.get_map_bounds_pixels()
		camera.limit_left = bounds.position.x
		camera.limit_top = bounds.position.y
		camera.limit_right = bounds.end.x
		camera.limit_bottom = bounds.end.y
	update_ui()


func draw_path_preview(path: Array[Vector2i]):
	# Draw dots for the path (excluding start and target tiles)
	# Vector2i(27,20) is the path ball icon
	for cell in path.slice(1, -1):
		preview_layer.set_cell(cell, 0, Vector2i(27,20))


func update_selection_visual():
	selection_layer.clear()
	if is_selected:
		# Draw selection indicator under unit
		# Vector2i(25,14) is the selection bracket/circle icon
		selection_layer.set_cell(grid_pos, 0, Vector2i(25,14))


func update_preview(target_cell, distance):
	# Color the path based on whether the unit can reach the destination
	if distance <= remaining_movement:
		preview_layer.modulate = Color(0, 1, 0, 0.5) # Green (Affordable)
	else:
		preview_layer.modulate = Color(1, 0, 0, 0.5) # Red (Too far)
	
	# Mark the target tile
	# Vector2i(27,21) is the target crosshair/circle icon
	preview_layer.set_cell(target_cell, 0, Vector2i(27,21))


func update_ui():
	# Sync the UI label with remaining movement points
	if movement_label:
		movement_label.text = "Movement: " + str(remaining_movement)


func start_new_turn():
	super.start_new_turn()
	remaining_movement = movement_range
	is_selected = true # Auto-select unit when its turn starts
	update_selection_visual()
	update_ui()
	print("New Turn! Movement points refreshed: ", remaining_movement)


func on_movement_start_logic():
	# Hide selection circle while moving
	selection_layer.clear()


func on_movement_finished_logic():
	# Update UI and visuals once movement stops
	update_ui()
	preview_layer.clear()
	update_selection_visual()
