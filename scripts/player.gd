extends Unit

# --- Tilemap Layer References ---
var preview_layer: TileMapLayer
var selection_layer: TileMapLayer
var _last_movement_amount: int = 0

# --- Misc ---
@onready var camera: Camera2D = $Camera2D


# --- Lifecycle ---
func _ready() -> void:
	super._ready()
	movement_changed.connect(_on_movement_changed)
	TurnManager.active_unit_changed.connect(_on_active_unit_changed)
	if camera:
		_setup_camera()
		await get_tree().process_frame
 

func _setup_camera() -> void:
	camera.enabled = true
	# Zoom setting
	# (1, 1) is default, (0.5, 0,5) is 2x zoom out
	camera.zoom = Vector2(0.6, 0.6)
	camera.make_current()


# --- Signal Handlers ---
func _on_active_unit_changed(unit: Unit) -> void:
	if unit == self:
		start_new_turn()


# Helper function for the signal
func _on_movement_changed(new_amount: int) -> void:
	if new_amount >= _last_movement_amount:
		_last_movement_amount = new_amount
		return
	_last_movement_amount = new_amount
	GameEvents.log_requested.emit("Hero moved. " + str(new_amount) + " movement left.")


# --- Input Handling ---
func _input(event: InputEvent) -> void:
	# Do not allow any interaction if the player is dead/hidden
	if not visible: return
	# Ignore input if it's combat and not this unit's turn
	if TurnManager.current_state == TurnManager.State.COMBAT and not is_active_unit:
		return
	if event is InputEventMouseButton and event.pressed:
		var clicked_cell = map_manager.get_grid_coords(get_global_mouse_position())
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_selection(clicked_cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT and is_selected and not is_moving:
			_handle_interaction(clicked_cell)
	if Input.is_action_just_pressed("ui_accept"):
		_handle_turn_end()
	

func _handle_selection(cell: Vector2i) -> void:
	is_selected = (cell == grid_pos)
	update_selection_visual()


func _handle_interaction(cell: Vector2i) -> void:
	var target_unit = map_manager.get_unit_at_cell(cell)
	if target_unit and target_unit != self:
		if is_adjacent_to(target_unit):
			attack_target(target_unit)
		else:
			GameEvents.log_requested.emit("Target is too far away!")
	else:
		_handle_movement(cell)


func _handle_movement(cell: Vector2i) -> void:
	if not astar_grid.is_in_boundsv(cell) or cell == grid_pos:
		preview_layer.clear()
		return
	var result = get_path_and_cost(cell)
	if not result["path"].is_empty() and result ["cost"] <= remaining_movement:
		execute_movement(result["path"], result["cost"])


func _handle_turn_end() -> void:
	if is_moving: return
	if TurnManager.current_state == TurnManager.State.EXPLORATION:
		TurnManager.end_exploration_turn()
	else:
		is_active_unit = false
		is_selected = false
		update_selection_visual()
		preview_layer.clear()
		TurnManager.next_combat_turn()


# ---Process and Visuals
func _process(_delta) -> void:
	# Stop drawing path previews if it's not our turn
	if TurnManager.current_state == TurnManager.State.COMBAT and not is_active_unit:
		preview_layer.clear()
		return
	# Draw movement preview while selected and hovering
	if is_selected and not is_moving:
		_update_path_preview()
	else:
		preview_layer.clear()


func _update_path_preview() -> void:
	var hovered_cell = map_manager.get_grid_coords(get_global_mouse_position())
	preview_layer.clear()
	if not astar_grid.is_in_boundsv(hovered_cell) or hovered_cell == grid_pos:
		return
	var result = get_path_and_cost(hovered_cell)
	if not result["path"].is_empty():
		draw_path_preview(result["path"])
		update_preview(hovered_cell, result["cost"])


# --- Visual Overrides ---
func draw_path_preview(path: Array[Vector2i]) -> void:
	# Draw dots for the path (excluding start and target tiles)
	# Vector2i(27,20) is the path ball icon
	for cell in path.slice(1, -1):
		preview_layer.set_cell(cell, 0, Vector2i(27,20))


func update_selection_visual() -> void:
	selection_layer.clear()
	if is_selected:
		# Draw selection indicator under unit
		# Vector2i(25,14) is the selection bracket/circle icon
		selection_layer.set_cell(grid_pos, 0, Vector2i(25,14))


func update_preview(target_cell: Vector2i, distance: float) -> void:
	# Color the path based on whether the unit can reach the destination
	preview_layer.modulate = Color(0, 1, 0, 0.5) if distance <= remaining_movement else Color(1, 0, 0, 0.5)
	# Mark the target tile
	# Vector2i(27,21) is the target crosshair/circle icon
	preview_layer.set_cell(target_cell, 0, Vector2i(27,21))


# --- Overridden Hooks from Unit.gd ---
func start_new_turn() -> void:
	super.start_new_turn()
	is_selected = true # Auto-select unit when its turn starts
	update_selection_visual()
	#remaining_movement = movement_range
	#GameEvents.log_requested.emit("--- Player Turn: Movement refreshed (%s) ---" % remaining_movement)


func setup_player_references(m_manager, p_layer, s_layer) -> void:
	map_manager = m_manager
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



func _on_movement_start_logic():
	# Hide selection circle while moving
	selection_layer.clear()


func _on_movement_finished_logic():
	# Update UI and visuals once movement stops
	preview_layer.clear()
	update_selection_visual()
