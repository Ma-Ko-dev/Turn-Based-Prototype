extends NinePatchRect

@onready var container = $MarginContainer/VBoxContainer
var _active_creator: Node = null
var _open_time: float = 0.0

func _ready() -> void:
	hide()
	UiManager.register_context_menu(self)


func open(actions: Array, pos: Vector2, creator: Node) -> void:
	_open_time = Time.get_ticks_msec()
	if _active_creator and is_instance_valid(_active_creator):
		if _active_creator.visibility_changed.is_connected(hide):
			_active_creator.visibility_changed.disconnect(hide)
	_active_creator = creator
	if _active_creator:
		_active_creator.visibility_changed.connect(hide, CONNECT_ONE_SHOT)
		
	#Clear previous actions
	for child in container.get_children():
		child.free()
	container.size = Vector2.ZERO
	self.size = Vector2.ZERO
	# Create a button for each action
	for action_data in actions:
		var btn = Button.new()
		btn.text = action_data["label"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func(): _on_action_pressed(action_data["callback"]))
		container.add_child(btn)
	container.reset_size()
	await get_tree().process_frame
	size = container.get_combined_minimum_size() + Vector2(20, 10)
	global_position = pos
	show()


func _on_action_pressed(callback: Callable) -> void:
	callback.call()
	hide()


 #Detect clicks outside of this menu to close it
func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseButton and event.pressed:
		if Time.get_ticks_msec() - _open_time < 50:
			return
		if not get_global_rect().has_point(get_global_mouse_position()):
			hide()
