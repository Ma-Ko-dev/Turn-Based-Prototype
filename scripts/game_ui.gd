extends CanvasLayer

@onready var _log_text: Label = $LogWindow/MarginContainer/VBoxContainer/ScrollContainer/LogText
@onready var _scroll_container: ScrollContainer = $LogWindow/MarginContainer/VBoxContainer/ScrollContainer
@onready var _end_turn_button: Button = $LogWindow/MarginContainer/VBoxContainer/EndTurnButton
@onready var _tracker_container: HBoxContainer = $CombatTracker/MarginContainer/HBoxContainer
@onready var _tracker_panel: NinePatchRect = $CombatTracker
@export var tracker_icon_scene: PackedScene


# --- Lifecycle ---
func _ready() -> void:
	# Listen for any log requests from anywhere in the game
	GameEvents.log_requested.connect(_on_log_requested)
	TurnManager.turn_mode_changed.connect(_on_turn_mode_changed)
	TurnManager.active_unit_changed.connect(_on_active_unit_changed)
	TurnManager.combat_queue_updated.connect(_rebuild_tracker)
	_tracker_panel.visible = false


# --- Signal Handlers ---
func _on_log_requested(message: String) -> void:
	_add_message(message)


func _on_turn_mode_changed(is_combat: bool) -> void:
	_tracker_panel.visible = is_combat
	if is_combat:
		_rebuild_tracker()


func _rebuild_tracker() -> void:
	for child in _tracker_container.get_children():
		child.queue_free()
	await get_tree().process_frame
	for unit in TurnManager.combat_queue:
		var icon = tracker_icon_scene.instantiate()
		_tracker_container.add_child(icon)
		icon.setup(unit)
	var active_u = TurnManager.get("active_unit")
	if TurnManager.current_state == TurnManager.State.COMBAT and not TurnManager.combat_queue.is_empty():
		var current_active = TurnManager.combat_queue[TurnManager.active_unit_index]
		_update_tracker_highlights(current_active)


func _update_tracker_highlights(active_unit: Unit) -> void:
	for icon in _tracker_container.get_children():
		if not icon.is_queued_for_deletion():
			icon.set_active(icon.name == str(active_unit.get_instance_id()))


func _on_end_turn_button_pressed() -> void:
	var player = get_tree().get_first_node_in_group("players") as Unit
	if not player or _end_turn_button.disabled: return
	if TurnManager.current_state == TurnManager.State.EXPLORATION:
		TurnManager.end_exploration_turn()
	elif player.is_active_unit:
		TurnManager.next_combat_turn()
	else:
		GameEvents.log_requested.emit("It's not your turn!")


func _on_active_unit_changed(unit: Unit) -> void:
	if TurnManager.current_state == TurnManager.State.COMBAT:
		_end_turn_button.disabled = not unit.is_in_group("players")
	else:
		_end_turn_button.disabled = false
	if TurnManager.current_state == TurnManager.State.COMBAT:
		_update_tracker_highlights(unit)


# --- Internal UI Logic ---
func _add_message(text: String) -> void:
	_log_text.text += "\n" + text
	_autoscroll()


func _autoscroll() -> void:
	await get_tree().process_frame
	_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)
