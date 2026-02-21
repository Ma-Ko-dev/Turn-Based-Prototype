extends Node

var context_menu = null
var loot_window = null


func register_context_menu(menu_node: Control) -> void:
	context_menu = menu_node

func register_loot_window(window_node: Control) -> void:
	loot_window = window_node
