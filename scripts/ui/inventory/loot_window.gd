extends Control

@onready var grid: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var loot_all_button: Button = $MarginContainer/VBoxContainer/LootAllButton
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

var current_chest_items: Array[ItemData] = []
var current_target_unit: UnitData = null
var _current_chest_node: Node = null

func _ready() -> void:
	UiManager.register_loot_window(self)
	loot_all_button.pressed.connect(_on_loot_all_pressed)
	close_button.pressed.connect(hide)
	hide()

## Fills the window with items and shows it at a specific screen position
func open(items: Array[ItemData], target_unit: UnitData, screen_pos: Vector2, chest_node: Node = null) -> void:
	current_chest_items = items
	_current_chest_node = chest_node
	current_target_unit = target_unit
	# Clear old slots
	for child in grid.get_children():
		child.free()
	# Create new slots for chest items
	for item in items:
		if not item: continue
		var slot = preload("res://scenes/ui/ItemSlot.tscn").instantiate()
		grid.add_child(slot)
		slot.owner = self
		slot.set_item(item)
	show()
	await get_tree().process_frame
	reset_size()
	self.global_position = screen_pos

func remove_single_item(item: ItemData, slot_node: Node) -> void:
	current_chest_items.erase(item)
	slot_node.queue_free()
	if current_chest_items.size() == 0:
		hide()
		if is_instance_valid(_current_chest_node) and _current_chest_node.has_method("remove_chest"):
			_current_chest_node.remove_chest()

func _on_loot_all_pressed() -> void:
	for item in current_chest_items:
		current_target_unit.add_item_to_inventory(item)
	current_chest_items.clear()
	hide()
	if is_instance_valid(_current_chest_node) and _current_chest_node.has_method("remove_chest"):
		_current_chest_node.remove_chest()
