extends Control

@onready var room_code_label: Label = %RoomCodeLabel
@onready var player_list: VBoxContainer = %PlayerList
@onready var start_button: Button = %StartButton
@onready var hint_label: Label = %HintLabel


func _ready() -> void:
	room_code_label.text = "Room Code: %s" % NetworkManager.room_code
	start_button.pressed.connect(_on_start_pressed)
	NetworkManager.lobby_updated.connect(_on_lobby_updated)
	NetworkManager.disconnected.connect(_on_disconnected)
	NetworkManager.game_state_received.connect(_on_game_state_received)
	_refresh(NetworkManager.players, NetworkManager.host_id)


func _on_lobby_updated(players: Array, host_id: String) -> void:
	_refresh(players, host_id)


func _refresh(players: Array, host_id: String) -> void:
	for child in player_list.get_children():
		child.queue_free()

	for p in players:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(18, 18)
		swatch.color = NetworkManager.get_player_color(p.get("color_index", 0))
		row.add_child(swatch)

		var name_label := Label.new()
		var suffix := " (host)" if p.get("id", "") == host_id else ""
		name_label.text = "%s%s" % [p.get("username", "Player"), suffix]
		row.add_child(name_label)

		player_list.add_child(row)

	var is_host := NetworkManager.is_host
	start_button.visible = is_host
	start_button.disabled = players.size() < 2
	hint_label.text = "" if is_host else "Waiting for the host to start the game..."
	if is_host and players.size() < 2:
		hint_label.text = "Need at least 2 players to start."
	elif is_host:
		hint_label.text = ""


func _on_start_pressed() -> void:
	if not NetworkManager.is_host:
		return
	GameState.start_game(NetworkManager.players)
	NetworkManager.send_game_state(GameState.to_payload())
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_game_state_received(_payload: Dictionary) -> void:
	# A non-host player receives this once the host starts the game.
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_disconnected() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
