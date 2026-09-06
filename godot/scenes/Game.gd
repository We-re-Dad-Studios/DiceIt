extends Control

@onready var scoreboard: VBoxContainer = %Scoreboard
@onready var turn_label: Label = %TurnLabel
@onready var live_count_label: Label = %LiveCountLabel
@onready var pot_label: Label = %PotLabel
@onready var dice_row: HBoxContainer = %DiceRow
@onready var roll_button: Button = %RollButton
@onready var lock_button: Button = %LockButton
@onready var bank_button: Button = %BankButton
@onready var message_label: Label = %MessageLabel
@onready var game_over_panel: PanelContainer = %GameOverPanel
@onready var winner_label: Label = %WinnerLabel
@onready var back_to_title_button: Button = %BackToTitleButton

var state: Dictionary = {}
var selected_indices: Array = []


func _ready() -> void:
	roll_button.pressed.connect(_on_roll_pressed)
	lock_button.pressed.connect(_on_lock_pressed)
	bank_button.pressed.connect(_on_bank_pressed)
	back_to_title_button.pressed.connect(_on_back_to_title_pressed)
	NetworkManager.disconnected.connect(_on_disconnected)

	if NetworkManager.is_host:
		GameState.state_changed.connect(_on_host_state_changed)
		NetworkManager.action_received.connect(_on_action_received_as_host)
		_render(GameState.to_payload())
	else:
		NetworkManager.game_state_received.connect(_on_client_state_received)
		_render(GameState.to_payload()) # placeholder until first broadcast arrives


func _on_host_state_changed(payload: Dictionary) -> void:
	_render(payload)
	NetworkManager.send_game_state(payload)


func _on_client_state_received(payload: Dictionary) -> void:
	_render(payload)


func _on_action_received_as_host(payload: Dictionary, from_id: String) -> void:
	GameState.apply_action(from_id, payload.get("action", ""), payload)


func _is_my_turn() -> bool:
	return state.get("current_player_id", "") == NetworkManager.player_id


func _send_or_apply_action(action: String, extra: Dictionary = {}) -> void:
	var payload := extra.duplicate()
	payload["action"] = action
	if NetworkManager.is_host:
		GameState.apply_action(NetworkManager.player_id, action, payload)
	else:
		NetworkManager.send_action(payload)


func _on_roll_pressed() -> void:
	selected_indices = []
	_send_or_apply_action("roll")


func _on_lock_pressed() -> void:
	_send_or_apply_action("lock", {"indices": selected_indices})
	selected_indices = []


func _on_bank_pressed() -> void:
	_send_or_apply_action("bank")


func _on_back_to_title_pressed() -> void:
	NetworkManager.leave_room()
	get_tree().change_scene_to_file("res://scenes/Title.tscn")


func _on_disconnected() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")


func _render(payload: Dictionary) -> void:
	state = payload
	if state.is_empty():
		return

	_render_scoreboard()
	_render_turn_info()
	_render_dice()
	_render_controls()

	game_over_panel.visible = state.get("phase", "") == "game_over"
	if game_over_panel.visible:
		var winner := _player_by_id(state.get("winner_id", ""))
		winner_label.text = "%s wins with %d points!" % [winner.get("username", "Someone"), winner.get("score", 0)]


func _player_by_id(pid: String) -> Dictionary:
	for p in state.get("players", []):
		if p.get("id", "") == pid:
			return p
	return {}


func _render_scoreboard() -> void:
	for child in scoreboard.get_children():
		child.queue_free()

	var current_id: String = state.get("current_player_id", "")
	for p in state.get("players", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(16, 16)
		swatch.color = NetworkManager.get_player_color(p.get("color_index", 0))
		row.add_child(swatch)

		var label := Label.new()
		var marker := " <- turn" if p.get("id", "") == current_id else ""
		label.text = "%s: %d%s" % [p.get("username", "Player"), p.get("score", 0), marker]
		row.add_child(label)

		scoreboard.add_child(row)


func _render_turn_info() -> void:
	var current := _player_by_id(state.get("current_player_id", ""))
	turn_label.text = "%s's turn" % current.get("username", "...")
	live_count_label.text = "Live dice: %d" % state.get("live_count", 0)
	pot_label.text = "Round pot: %d" % state.get("round_pot", 0)
	message_label.text = state.get("message", "")


func _render_dice() -> void:
	for child in dice_row.get_children():
		child.queue_free()
	selected_indices = []

	var phase: String = state.get("phase", "")
	if phase != "await_choice":
		return

	var last_roll: Array = state.get("last_roll", [])
	var my_turn := _is_my_turn()

	for i in range(last_roll.size()):
		var entry: Dictionary = last_roll[i]
		var value: int = entry.get("value", 0)
		var busted: bool = entry.get("busted", false)

		var btn := Button.new()
		btn.text = str(value)
		btn.custom_minimum_size = Vector2(48, 48)
		btn.toggle_mode = true
		btn.disabled = busted or not my_turn
		if busted:
			btn.modulate = Color(0.55, 0.55, 0.55)
			btn.text = "%d (bust)" % value
		var idx := i
		btn.toggled.connect(func(pressed: bool): _on_die_toggled(idx, pressed))
		dice_row.add_child(btn)


func _on_die_toggled(idx: int, pressed: bool) -> void:
	if pressed:
		if not selected_indices.has(idx):
			selected_indices.append(idx)
	else:
		selected_indices.erase(idx)


func _render_controls() -> void:
	var phase: String = state.get("phase", "")
	var my_turn := _is_my_turn()

	roll_button.visible = phase == "await_roll"
	roll_button.disabled = not my_turn

	lock_button.visible = phase == "await_choice"
	lock_button.disabled = not my_turn

	bank_button.visible = phase == "await_roll"
	bank_button.disabled = not my_turn
