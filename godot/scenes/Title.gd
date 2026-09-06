extends Control

@onready var username_edit: LineEdit = %UsernameEdit
@onready var room_code_edit: LineEdit = %RoomCodeEdit
@onready var create_button: Button = %CreateButton
@onready var join_button: Button = %JoinButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	create_button.pressed.connect(_on_create_pressed)
	join_button.pressed.connect(_on_join_pressed)
	NetworkManager.connected_to_relay.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.room_created.connect(_on_room_ready)
	NetworkManager.room_joined.connect(_on_room_ready)
	NetworkManager.join_failed.connect(_on_join_failed)


func _set_buttons_enabled(enabled: bool) -> void:
	create_button.disabled = not enabled
	join_button.disabled = not enabled


func _on_create_pressed() -> void:
	var username := username_edit.text.strip_edges()
	if username.is_empty():
		status_label.text = "Enter a username first."
		return
	_set_buttons_enabled(false)
	status_label.text = "Connecting..."
	NetworkManager.connect_and_create_room(NetworkManager.default_relay_url, username)


func _on_join_pressed() -> void:
	var username := username_edit.text.strip_edges()
	var code := room_code_edit.text.strip_edges()
	if username.is_empty():
		status_label.text = "Enter a username first."
		return
	if code.is_empty():
		status_label.text = "Enter a room code to join."
		return
	_set_buttons_enabled(false)
	status_label.text = "Connecting..."
	NetworkManager.connect_and_join_room(NetworkManager.default_relay_url, username, code)


func _on_connected() -> void:
	status_label.text = "Connected. Setting up room..."


func _on_connection_failed() -> void:
	_set_buttons_enabled(true)
	status_label.text = "Couldn't reach the relay server. Check the URL and try again."


func _on_join_failed(message: String) -> void:
	_set_buttons_enabled(true)
	status_label.text = message


func _on_room_ready(_code: String) -> void:
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
