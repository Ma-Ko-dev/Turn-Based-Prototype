extends MarginContainer

@onready var backpack_grid: GridContainer = $HBoxContainer/RightSide/BackpackScroll/BackpackGrid
var slot_scene = preload("res://scenes/ui/ItemSlot.tscn")
var inventory_items: Array[ItemData] = []


func _ready() -> void:
	_fill_test_items()
	refresh_backpack_ui()


# This function clears and rebuilds the grid based on inventory_items
func refresh_backpack_ui() -> void:
	for child in backpack_grid.get_children():
		child.queue_free()
	# Create slots for all items currently in the list
	for item in inventory_items:
		_add_slot_to_grid(item)
	# ALWAYS add one extra empty slot to allow dropping new items into the backpack
	_add_slot_to_grid(null)


# Helper to instantiate and setup a slot
func _add_slot_to_grid(item_data: ItemData) -> void:
	var new_slot = slot_scene.instantiate()
	backpack_grid.add_child(new_slot)
	if item_data == null:
		new_slot.name = "Empty"
	new_slot.set_item(item_data)


# --- DEBUG ---
func _fill_test_items():
	var item1 = load("res://ressources/ui/items/armor/leather_armor.tres")
	var item2 = load("res://ressources/ui/items/weapons/longsword.tres")
	
	if item1: inventory_items.append(item1)
	if item2: inventory_items.append(item2)
