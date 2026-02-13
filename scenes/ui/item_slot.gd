extends PanelContainer

# References
@onready var icon: TextureRect = $MarginContainer/Icon
@onready var amount_label: Label = $MarginContainer/AmountLabel
@onready var slot_name_label: Label = $MarginContainer/SlotnameLabel

# This will hold the actual item data later
var stored_item: ItemData = null


func _ready() -> void:
	# Auto-rename label based on node name ("HeadSlot" -> "HEAD")
	var display_name = name.replace("Slot", "").to_upper()
	slot_name_label.text = display_name
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
