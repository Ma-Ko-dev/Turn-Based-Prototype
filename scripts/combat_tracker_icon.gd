extends VBoxContainer

@onready var portrait: TextureRect = $Portrait
@onready var health_bar: ProgressBar = $HealthBar
var _tracked_unit: Unit


func setup(unit: Unit) -> void:
	_tracked_unit = unit
	# Set the unit image from its data
	portrait.texture = unit.data.texture
	# Use instance ID as node name for easy lookup
	name = str(unit.get_instance_id())
	_update_health_ui()
	set_active(false)
	if not _tracked_unit.hp_changed.is_connected(_update_health_ui):
		_tracked_unit.hp_changed.connect(_update_health_ui)


func set_active(is_active: bool) -> void:
	if is_active:
		portrait.modulate = Color(0.0, 0.0, 0.0, 1.0)
		# Slight scale effect when it's this unit's turn
	else:
		portrait.modulate = Color(0.6, 0.6, 0.6, 0.7)


func _update_health_ui() -> void:
	if not _tracked_unit or not _tracked_unit.data: return
	if health_bar:
		health_bar.max_value = _tracked_unit.max_health
		health_bar.value = _tracked_unit.current_health
