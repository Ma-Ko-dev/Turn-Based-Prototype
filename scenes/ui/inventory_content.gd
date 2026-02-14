extends MarginContainer

@onready var backpack_grid: GridContainer = $HBoxContainer/RightSide/BackpackScroll/BackpackGrid
@onready var equipment_area: VBoxContainer = $HBoxContainer/EquipmentArea

var slot_scene = preload("res://scenes/ui/ItemSlot.tscn")
var active_unit_data: UnitData

func _ready() -> void:
	#_fill_test_items()
	#refresh_backpack_ui()
	pass


# This function clears and rebuilds the grid based on inventory_items
func refresh_backpack_ui(unit: UnitData) -> void:
	if not unit: return
	active_unit_data = unit
	# Update all fixed equipment slots automatically
	_update_fixed_slots(unit)
	for child in backpack_grid.get_children():
		child.queue_free()
	# Create slots for all items currently in the list
	for item in unit.inventory_items:
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


# Helper to find and update all equipment slots in the UI tree
func _update_fixed_slots(unit: UnitData) -> void:
	# Get all nodes recursively that are part of the equipment
	for slot in equipment_area.find_children("*", "PanelContainer", true):
		if slot.has_method("set_item") and slot.target_slot_type != ItemData.EquipmentSlot.NONE:
			var item = unit.get_item_by_slot_type(slot.target_slot_type)
			slot.set_item(item)
