extends Control


@onready var tabs: TabContainer = $ContentWrapper/MainLayout/TabContainer
@onready var content_area: MarginContainer = $ContentWrapper/MainLayout/ContentArea


func _ready() -> void:
	# Connect the signal and show first tab
	tabs.tab_changed.connect(_on_tab_changed)
	_update_view(0)


func _on_tab_changed(tab_index: int) -> void:
	_update_view(tab_index)


func _update_view(index: int) -> void:
	# toggle visibility based on selected tab index
	for i in range(content_area.get_child_count()):
		content_area.get_child(i).visible = (i == index)
