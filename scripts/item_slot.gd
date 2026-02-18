extends PanelContainer

# References
@onready var icon: TextureRect = $MarginContainer/Icon
@onready var amount_label: Label = $MarginContainer/AmountLabel
@onready var slot_name_label: Label = $MarginContainer/SlotnameLabel

@export var target_slot_type: ItemData.EquipmentSlot = ItemData.EquipmentSlot.NONE
# This will hold the actual item data later
var stored_item: ItemData = null


func _ready() -> void:
	# Auto-rename label based on node name ("HeadSlot" -> "HEAD")
	var display_name = name.replace("Slot", "")
	if display_name.contains("@"):
		slot_name_label.text = "EMPTY"
	else:
		slot_name_label.text = display_name.to_upper()
	update_slot_visuals()
	mouse_entered.connect(func(): if stored_item: GameEvents.item_hovered.emit(stored_item))
	mouse_exited.connect(func(): GameEvents.item_hovered.emit(null))


# Main function to put an item into the slot
func set_item(item_data: ItemData) -> void:
	stored_item = item_data
	update_slot_visuals()


# Logic to show/hide labels and textures
func update_slot_visuals() -> void:
	if not is_inside_tree(): return
	icon.visible = stored_item != null
	slot_name_label.visible = stored_item == null
	amount_label.visible = stored_item and stored_item.amount > 1
	if stored_item:
		icon.texture = stored_item.texture
		if amount_label.visible: amount_label.text = str(stored_item.amount)
	else:
		icon.texture = null

# --- DRAG & DROP ---

func _get_drag_data(_at_position: Vector2):
	if not stored_item: return null
	# Create a preview of the item under the mouse
	var preview = TextureRect.new()
	preview.texture = icon.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(48, 48)
	var c = Control.new()
	c.add_child(preview)
	preview.position = -preview.custom_minimum_size / 2
	set_drag_preview(c)
	# Center the preview under the mouse
	return {"item": stored_item, "origin_slot": self}

func _can_drop_data(_at_position: Vector2, data) -> bool:
	if not (data is Dictionary and data.has("item")): return false
	var dragged_item = data["item"]
	# Can always drop in backpack, but equipment must match slot_type
	if target_slot_type == ItemData.EquipmentSlot.NONE: return true
	return dragged_item.slot_type == target_slot_type

func _drop_data(_at_position: Vector2, data) -> void:
	var inventory_content = get_tree().get_first_node_in_group("inventory_manager")
	var unit = inventory_content.active_unit_data
	var origin_slot = data["origin_slot"]
	# We just need to know if we are a backpack-slot or an equipment-slot.
	unit.handle_drag_drop(origin_slot.target_slot_type, origin_slot.get_index(), target_slot_type, get_index())

# --- ACTIONS ---
func _gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if stored_item: _open_context_menu()

func _open_context_menu() -> void:
	var inventory_manager = get_tree().get_first_node_in_group("inventory_manager")
	var unit = inventory_manager.active_unit_data
	var actions = stored_item.get_actions(unit, target_slot_type != ItemData.EquipmentSlot.NONE, self)
	UiManager.context_menu.open(actions, get_global_mouse_position(), self)

func _drop_item_logic(unit: UnitData) -> void:
	if target_slot_type == ItemData.EquipmentSlot.NONE:
		unit.drop_item(get_index())
	else:
		unit.drop_equipped_item(target_slot_type)

func _equip_via_menu(unit: UnitData) -> void:
	if stored_item: unit.equip_item_from_backpack(stored_item, get_index())

func _unequip_via_menu(unit: UnitData) -> void:
	unit.unequip_slot(target_slot_type)
