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
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


# Main function to put an item into the slot
func set_item(item_data: ItemData) -> void:
	stored_item = item_data
	update_slot_visuals()


# Logic to show/hide labels and textures
func update_slot_visuals() -> void:
	if not is_inside_tree(): return
	
	if stored_item:
		if icon == null:
			print("CRITICAL: Icon node is null in slot ", name)
			return
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
	var unit = inventory_content.active_unit_data
	
	# Get indices for backpack logic
	var target_index = get_index()
	var origin_index = origin_slot.get_index()
	
	# This is a Backpack Slot (target_slot_type is NONE)
	if target_slot_type == ItemData.EquipmentSlot.NONE:
		var items = unit.inventory_items
		# Came from Equipment
		if origin_slot.target_slot_type != ItemData.EquipmentSlot.NONE:
			if target_index < items.size():
				var old_backpack_item = items[target_index]
				items[target_index] = dragged_item
				_update_unit_equipment(unit, origin_slot.target_slot_type, old_backpack_item)
			else:
				items.append(dragged_item)
				_update_unit_equipment(unit, origin_slot.target_slot_type, null)
			#unit.inventory_items.append(dragged_item)
			# Clear the specific equipment slot
			#_update_unit_equipment(unit, origin_slot.target_slot_type, null)
		else:
			# Moving within Backpack
			#var items = unit.inventory_items
			if target_index < items.size() and origin_index < items.size():
				# Actual swap in the array
				var temp = items[target_index]
				items[target_index] = items[origin_index]
				items[origin_index] = temp
	# This is an Equipment Slot (Head, Body, etc.)
	else:
		# Update equipment in UnitData
		var old_item = _get_unit_equipment(unit, target_slot_type)
		_update_unit_equipment(unit, target_slot_type, dragged_item)
		
		if origin_slot.target_slot_type == ItemData.EquipmentSlot.NONE:
			unit.inventory_items.remove_at(origin_index)
			# If there was already something equipped, put it in the backpack
			if old_item:
				unit.inventory_items.insert(origin_index, old_item)
		else:
			# Swapping between two equipment slots
			_update_unit_equipment(unit, origin_slot.target_slot_type, old_item)
	get_tree().get_first_node_in_group("character_sheet").display_unit(unit)


# Helper to set UnitData fields dynamically
func _update_unit_equipment(unit: UnitData, type: ItemData.EquipmentSlot, item: ItemData) -> void:
	if type == ItemData.EquipmentSlot.SHOULDER: unit.shoulder_item = item
	elif type == ItemData.EquipmentSlot.HEAD: unit.head_item = item
	elif type == ItemData.EquipmentSlot.NECK: unit.neck_item = item
	elif type == ItemData.EquipmentSlot.CLOAK: unit.cloak_item = item
	elif type == ItemData.EquipmentSlot.BODY: unit.body_armor = item
	elif type == ItemData.EquipmentSlot.GLOVES: unit.gloves_item = item
	elif type == ItemData.EquipmentSlot.BELT: unit.belt_item = item
	elif type == ItemData.EquipmentSlot.BOOT: unit.boot_item = item
	elif type == ItemData.EquipmentSlot.RING: unit.ring1_item = item
	elif type == ItemData.EquipmentSlot.QUICK: unit.quick1_item = item
	elif type == ItemData.EquipmentSlot.MAIN_HAND: unit.main_hand = item
	elif type == ItemData.EquipmentSlot.OFF_HAND: unit.off_hand = item
	elif type == ItemData.EquipmentSlot.BOTH_HANDS: unit.both_hand = item


# Helper to get UnitData fields dynamically
func _get_unit_equipment(unit: UnitData, type: ItemData.EquipmentSlot) -> ItemData:
	if type == ItemData.EquipmentSlot.SHOULDER: return unit.shoulder_item
	elif type == ItemData.EquipmentSlot.HEAD: return unit.head_item
	elif type == ItemData.EquipmentSlot.NECK: return unit.neck_item
	elif type == ItemData.EquipmentSlot.CLOAK: return unit.cloak_item
	elif type == ItemData.EquipmentSlot.BODY: return unit.body_armor
	elif type == ItemData.EquipmentSlot.GLOVES: return unit.gloves_item
	elif type == ItemData.EquipmentSlot.BELT: return unit.belt_item
	elif type == ItemData.EquipmentSlot.BOOT: return unit.boot_item
	elif type == ItemData.EquipmentSlot.RING: return unit.ring1_item
	elif type == ItemData.EquipmentSlot.QUICK: return unit.quick1_item
	elif type == ItemData.EquipmentSlot.MAIN_HAND: return  unit.main_hand
	elif type == ItemData.EquipmentSlot.OFF_HAND: return unit.off_hand
	elif type == ItemData.EquipmentSlot.BOTH_HANDS: return unit.both_hand

	return null


func _on_mouse_entered() -> void:
	if stored_item:
		GameEvents.item_hovered.emit(stored_item)

func _on_mouse_exited() -> void:
	GameEvents.item_hovered.emit(null)
