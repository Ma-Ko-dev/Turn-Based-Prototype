extends Control


@onready var tabs: TabContainer = $ContentWrapper/MainLayout/TabContainer
@onready var content_area: MarginContainer = $ContentWrapper/MainLayout/ContentArea
@onready var close_button: TextureButton = $ContentWrapper/MainLayout/Header/CloseButton
@onready var character_content = $ContentWrapper/MainLayout/ContentArea/CharacterContent
@onready var inventory_content = $ContentWrapper/MainLayout/ContentArea/InventoryContent
var last_hp: int = 0
var _active_data: UnitData = null

func _ready() -> void:
	# Hide on gamestart
	self.hide()
	# Connect the signal and show first tab
	tabs.tab_changed.connect(_on_tab_changed)
	_update_view(0)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

func _on_tab_changed(tab_index: int) -> void:
	_update_view(tab_index)


# toggle visibility based on selected tab index
func _update_view(index: int) -> void:
	for i in range(content_area.get_child_count()):
		content_area.get_child(i).visible = (i == index)


func _on_close_pressed() -> void:
	self.hide()


func display_unit(data: UnitData, current_hp: int = -1) -> void:
	# Manage signal connections to avoid double-firing or leaks
	if _active_data and _active_data.data_updated.is_connected(_on_unit_data_updated):
		_active_data.data_updated.disconnect(_on_unit_data_updated)
	_active_data = data
	_active_data.data_updated.connect(_on_unit_data_updated)

	if current_hp >= 0:
		last_hp = current_hp
	
	# : This is your existing logic
	if character_content:
		character_content.update_ui(data, last_hp)
	if inventory_content:
		inventory_content.refresh_backpack_ui(data)

# New helper function for the signal
func _on_unit_data_updated() -> void:
	if _active_data:
		display_unit(_active_data)
