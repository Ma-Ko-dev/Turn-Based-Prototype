extends PanelContainer

@onready var header: Label = $MarginContainer/VBoxContainer/HeaderLabel
@onready var stat_grid: GridContainer = $MarginContainer/VBoxContainer/HBoxContainer/LeftColumn/StatGrid
@onready var description: Label = $MarginContainer/VBoxContainer/HBoxContainer/RightColumn/DescLabel
@onready var sep_header: HSeparator = $MarginContainer/VBoxContainer/HSeparator
@onready var sep_content: VSeparator = $MarginContainer/VBoxContainer/HBoxContainer/VSeparator


func _ready() -> void:
	sep_header.hide()
	sep_content.hide()
	GameEvents.item_hovered.connect(display_item)
	display_item(null) # English comment: Set initial empty state


func display_item(item: ItemData) -> void:
	for child in stat_grid.get_children():
		stat_grid.remove_child(child)
		child.queue_free()
		
	if not item:
		_clear_ui()
		return
	
	sep_header.show()
	sep_content.show()
	header.text = item.item_name
	var item_type = _get_type_text(item)
	header.text = header.text + " | " + item_type
	description.text = item.description
	if item is ArmorData:
		_add_stat("AC Bonus:", "+" + str(item.ac_bonus))
		_add_stat("Max Dex:", str(item.max_dex_bonus))
		_add_stat("ACP:", str(item.armor_check_penalty))
	elif item is WeaponData:
		_add_stat("Damage:", item.damage_medium)
		_add_stat("Crit:", "x" + str(item.critical_multiplier))
	_add_stat("Weight:", str(item.weight) + " lbs")


func _clear_ui() -> void:
	header.text = ""
	description.text = ""
	if sep_header: sep_header.hide()
	if sep_content: sep_content.hide()


func _add_stat(label_text: String, value_text: String) -> void:
	var l = Label.new()
	l.add_theme_color_override("font_color", Color("ffffffc8"))
	l.text = label_text
	var v = Label.new()
	v.add_theme_color_override("font_color", Color("ffffffc8"))
	v.text = value_text
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stat_grid.add_child(l)
	stat_grid.add_child(v)


func _get_type_text(item: ItemData) -> String:
	if item is ArmorData: return "Armor"
	if item is WeaponData: return "Weapon"
	return "Item"
