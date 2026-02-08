extends CanvasLayer

@onready var _log_text: Label = $LogWindow/MarginContainer/VBoxContainer/ScrollContainer/LogText
@onready var _scroll_container: ScrollContainer = $LogWindow/MarginContainer/VBoxContainer/ScrollContainer


# --- Lifecycle ---
func _ready() -> void:
	# Listen for any log requests from anywhere in the game
	GameEvents.log_requested.connect(_on_log_requested)


# --- Signal Handlers ---
func _on_log_requested(message: String) -> void:
	_add_message(message)


func _on_end_turn_button_pressed() -> void:
	if TurnManager.current_state == TurnManager.State.COMBAT:
		TurnManager.next_combat_turn()
	else:
		TurnManager.end_exploration_turn()


# --- Internal UI Logic ---
func _add_message(text: String) -> void:
	_log_text.text += "\n" + text
	_autoscroll()
	# Autoscroll to buttom
	#await get_tree().process_frame
	#scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value


func _autoscroll() -> void:
	await get_tree().process_frame
	_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)
