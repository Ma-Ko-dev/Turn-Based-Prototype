extends StaticBody2D

@export var loot: Array[ItemData] = []
var is_empty: bool = false
var _current_interactor: Node = null


func _ready() -> void:
	await get_tree().process_frame
	var map_manager = get_tree().get_first_node_in_group("map_manager")
	if map_manager and map_manager.ground_layer:
		var coords = map_manager.get_grid_coords(global_position)
		var local_center = map_manager.ground_layer.map_to_local(coords)
		if get_parent() == map_manager.ground_layer:
			position = local_center
		else:
			global_position = map_manager.ground_layer.to_global(local_center)
		if map_manager.has_method("set_cell_occupied"):
			map_manager.set_cell_occupied(coords, true)
		else:
			map_manager.astar_grid.set_point_solid(coords, true)
			map_manager.astar_grid.update()

func open_context_menu(unit: Unit) -> void:
	if is_empty: return
	_current_interactor = unit
	var actions = [
		{
			"label": "Open Chest",
			"callback": func(): _show_loot_window()
		}
	]
	var mouse_pos = get_viewport().get_mouse_position()
	UiManager.context_menu.open(actions, mouse_pos, self)

func _show_loot_window() -> void:
	if not is_instance_valid(_current_interactor):
		return
	var screen_pos = get_viewport().get_mouse_position()
	if _current_interactor.get("data") is UnitData:
		UiManager.loot_window.open(loot, _current_interactor.data, screen_pos, self)
	else:
		print("Error: The interactor has no UnitData in 'data'!")

func remove_chest() -> void:
	var map_manager = get_tree().get_first_node_in_group("map_manager")
	if map_manager:
		var coords = map_manager.get_grid_coords(global_position)
		if map_manager.has_method("set_cell_occupied"):
			map_manager.set_cell_occupied(coords, false)
		else:
			map_manager.astar_grid.set_point_solid(coords, false)
			map_manager.astar_grid.update()
	queue_free()
	
	
	
	
	
	
	
	
	
	
