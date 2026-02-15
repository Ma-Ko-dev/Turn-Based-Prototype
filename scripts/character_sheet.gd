extends Control


@onready var tabs: TabContainer = $ContentWrapper/MainLayout/TabContainer
@onready var content_area: MarginContainer = $ContentWrapper/MainLayout/ContentArea
@onready var close_button: TextureButton = $ContentWrapper/MainLayout/Header/CloseButton
@onready var character_content = $ContentWrapper/MainLayout/ContentArea/CharacterContent
@onready var inventory_content = $ContentWrapper/MainLayout/ContentArea/InventoryContent
var last_hp: int = 0

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


# Main function to fill the UI with data
func display_unit(data: UnitData, current_hp: int = -1) -> void:
	if current_hp >= 0:
		last_hp = current_hp
	if character_content:
		character_content.update_ui(data, last_hp)
	if inventory_content:
		inventory_content.refresh_backpack_ui(data)
	# Note: Future tabs will be added here
