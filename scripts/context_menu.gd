extends NinePatchRect

@onready var container = $MarginContainer/VBoxContainer
var _active_creator: Node = null

func _ready() -> void:
	hide()
	UiManager.register_context_menu(self)
	#mouse_exited.connect(hide)
	


func open(actions: Array, pos: Vector2, creator: Node) -> void:
	if _active_creator and is_instance_valid(_active_creator):
		if _active_creator.visibility_changed.is_connected(hide):
			_active_creator.visibility_changed.disconnect(hide)
	_active_creator = creator
	if _active_creator:
		_active_creator.visibility_changed.connect(hide, CONNECT_ONE_SHOT)
		
	#Clear previous actions
	while container.get_child_count() > 0:
		var child = container.get_child(0)	
		container.remove_child(child)
		child.free()
	# Create a button for each action
	for action_data in actions:
		var btn = Button.new()
		btn.text = action_data["label"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func(): _on_action_pressed(action_data["callback"]))
		container.add_child(btn)
	#await get_tree().process_frame
	container.reset_size()
	size = container.get_combined_minimum_size() + Vector2(20, 10)
	global_position = pos
	show()


func _on_action_pressed(callback: Callable) -> void:
	callback.call()
	hide()


# Detect clicks outside of this menu to close it
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not get_global_rect().has_point(get_global_mouse_position()):
			hide()
