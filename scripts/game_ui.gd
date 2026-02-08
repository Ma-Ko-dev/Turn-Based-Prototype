extends CanvasLayer

@onready var _log_text: Label = $LogWindow/MarginContainer/VBoxContainer/ScrollContainer/LogText
@onready var _scroll_container: ScrollContainer = $LogWindow/MarginContainer/VBoxContainer/ScrollContainer
@onready var _end_turn_button: Button = $LogWindow/MarginContainer/VBoxContainer/EndTurnButton


# --- Lifecycle ---
func _ready() -> void:
	# Listen for any log requests from anywhere in the game
	GameEvents.log_requested.connect(_on_log_requested)
	TurnManager.active_unit_changed.connect(_on_active_unit_changed)


# --- Signal Handlers ---
func _on_log_requested(message: String) -> void:
	_add_message(message)


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


# --- Internal UI Logic ---
func _add_message(text: String) -> void:
	_log_text.text += "\n" + text
	_autoscroll()


func _autoscroll() -> void:
	await get_tree().process_frame
	_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)
