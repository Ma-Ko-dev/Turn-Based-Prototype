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


# Main function to put an item into the slot
func set_item(item_data: ItemData) -> void:
	stored_item = item_data
	update_slot_visuals()


# Logic to show/hide labels and textures
func update_slot_visuals() -> void:
	if stored_item:
		icon.texture = stored_item.texture
		icon.show()
		slot_name_label.hide()
		if stored_item.get("amount") and stored_item.amount > 1:
			amount_label.text = str(stored_item.amount)
			amount_label.show()
		else:
			amount_label.hide()
	else:
		icon.texture = null
		icon.hide()
		slot_name_label.show()
		amount_label.hide()


# Starts the drag process
func _get_drag_data(_at_position: Vector2):
	if stored_item == null:
		return null
	# Create a preview of the item under the mouse
	var preview = TextureRect.new()
	preview.texture = icon.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(48, 48)
	# Center the preview under the mouse
	var preview_container = Control.new()
	preview_container.add_child(preview)
	preview.position = -preview.custom_minimum_size / 2
	set_drag_preview(preview_container)
	
	return {"item": stored_item, "origin_slot": self}


func _can_drop_data(_at_position: Vector2, data) -> bool:
	# Check if 'data' is actually our ItemData resource
	if data is Dictionary and data.has("item"):
		var dragged_item = data["item"]
		if target_slot_type == ItemData.EquipmentSlot.NONE:
			return true
		return dragged_item.slot_type == target_slot_type
	return false


# Handles the actual drop
func _drop_data(_at_position: Vector2, data) -> void:
	var dragged_item = data["item"]
	var origin_slot = data["origin_slot"]
	# Get reference to the inventory controller
	var inventory_content = get_tree().get_first_node_in_group("inventory_manager")
	
	# This is a Backpack Slot (target_slot_type is NONE)
	if target_slot_type == ItemData.EquipmentSlot.NONE:
		if origin_slot.target_slot_type != ItemData.EquipmentSlot.NONE:
			# Came from Equipment -> Add to backpack list
			inventory_content.inventory_items.append(dragged_item)
			origin_slot.set_item(null)
		else:
			# Moved within Backpack -> We just swap in the list later or ignore for now
			pass
		inventory_content.refresh_backpack_ui()
	# This is an Equipment Slot (Head, Body, etc.)
	else:
		if origin_slot.target_slot_type == ItemData.EquipmentSlot.NONE:
			# Came from Backpack -> Remove from list
			inventory_content.inventory_items.erase(dragged_item)
		
		# Standard swap logic for Equipment
		if stored_item != null:
			var temp_item = stored_item
			# If swapping back to backpack, add temp_item to list
			if origin_slot.target_slot_type == ItemData.EquipmentSlot.NONE:
				inventory_content.inventory_items.append(temp_item)
			set_item(dragged_item)
			origin_slot.set_item(temp_item)
		else:
			set_item(dragged_item)
			origin_slot.set_item(null)
		inventory_content.refresh_backpack_ui()
