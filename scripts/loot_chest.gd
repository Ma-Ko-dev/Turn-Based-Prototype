extends StaticBody2D

@export var loot: Array[ItemData] = []
var is_empty: bool = false

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		open_context_menu()

func open_context_menu() -> void:
	if is_empty: return
	var actions = [
		{
			"label": "Open Chest",
			"callback": func(): _show_loot_window()
		}
	]
	UiManager.context_menu.open(actions, get_global_mouse_position(), self)

func _show_loot_window() -> void:
	var player = get_tree().get_first_node_in_group("players")
	if not player: return
	var screen_pos = get_viewport().get_mouse_position()
	UiManager.loot_window.open(loot, player.data, screen_pos)
