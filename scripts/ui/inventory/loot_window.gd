extends Control

@onready var grid: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var loot_all_button: Button = $MarginContainer/VBoxContainer/LootAllButton
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

var current_chest_items: Array[ItemData] = []
var current_target_unit: UnitData = null

func _ready() -> void:
	UiManager.register_loot_window(self)
	loot_all_button.pressed.connect(_on_loot_all_pressed)
	close_button.pressed.connect(hide)
	hide()

## Fills the window with items and shows it at a specific screen position
func open(items: Array[ItemData], target_unit: UnitData, screen_pos: Vector2) -> void:
	current_chest_items = items
	current_target_unit = target_unit
	# Clear old slots
	for child in grid.get_children():
		child.free()
	# Create new slots for chest items
	for item in items:
		if not item: continue
		var slot = preload("res://scenes/ui/ItemSlot.tscn").instantiate()
		slot.set_item(item)
		grid.add_child(slot)
	show()
	await get_tree().process_frame
	reset_size()
	self.global_position = screen_pos

func _on_loot_all_pressed() -> void:
	for item in current_chest_items:
		current_target_unit.add_item_to_inventory(item)
	current_chest_items.clear()
	hide()
