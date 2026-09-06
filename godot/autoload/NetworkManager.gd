extends Node
## Wraps a WebSocketPeer connection to the relay server and exposes
## high-level signals for the rest of the game. See relay_server/relay.py
## for the exact JSON message protocol this speaks.

signal connected_to_relay
signal connection_failed
signal disconnected

signal room_created(code: String)
signal room_joined(code: String)
signal join_failed(message: String)
signal lobby_updated(players: Array, host_id: String)
signal player_left(player_id: String)

signal game_state_received(payload: Dictionary)
signal action_received(payload: Dictionary, from_id: String)

const PLAYER_COLORS: Array[Color] = [
	Color("e63946"), # red
	Color("2a9d8f"), # teal
	Color("f4a261"), # orange
	Color("457b9d"), # blue
	Color("e9c46a"), # yellow
	Color("9d4edd"), # purple
	Color("06d6a0"), # green
	Color("ff70a6"), # pink
]

var default_relay_url := "ws://127.0.0.1:8765"

var _socket: WebSocketPeer
var _pending_username := ""
var _pending_action := "" # "create" or "join"
var _pending_code := ""

var room_code := ""
var player_id := ""
var color_index := 0
var is_host := false
var players: Array = [] # [{id, username, color_index}]
var host_id := ""


func _process(_delta: float) -> void:
	if _socket == null:
		return

	_socket.poll()
	var state := _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		while _socket.get_available_packet_count() > 0:
			var packet := _socket.get_packet().get_string_from_utf8()
			_handle_message(packet)
	elif state == WebSocketPeer.STATE_CLOSED:
		var was_connecting := _pending_action != ""
		_socket = null
		if was_connecting:
			connection_failed.emit()
		else:
			disconnected.emit()


func connect_and_create_room(relay_url: String, username: String) -> void:
	_pending_username = username
	_pending_action = "create"
	_start_connection(relay_url)


func connect_and_join_room(relay_url: String, username: String, code: String) -> void:
	_pending_username = username
	_pending_action = "join"
	_pending_code = code.to_upper()
	_start_connection(relay_url)


func _start_connection(relay_url: String) -> void:
	var url := relay_url.strip_edges()
	if url.is_empty():
		url = default_relay_url

	_socket = WebSocketPeer.new()
	var err := _socket.connect_to_url(url)
	if err != OK:
		_socket = null
		connection_failed.emit()
		return

	# Wait for the handshake to finish, then send the queued create/join request.
	_await_open_then_send()


func _await_open_then_send() -> void:
	while _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		_socket.poll()
		await get_tree().process_frame

	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	connected_to_relay.emit()

	if _pending_action == "create":
		_send({"type": "create_room", "username": _pending_username})
	elif _pending_action == "join":
		_send({"type": "join_room", "code": _pending_code, "username": _pending_username})
	_pending_action = ""


func send_game_state(payload: Dictionary) -> void:
	_send({"type": "game_state", "payload": payload})


func send_action(payload: Dictionary) -> void:
	_send({"type": "action", "payload": payload})


func leave_room() -> void:
	if _socket != null:
		_socket.close()
	_socket = null
	room_code = ""
	player_id = ""
	is_host = false
	players = []
	host_id = ""


func get_player_color(idx: int) -> Color:
	return PLAYER_COLORS[idx % PLAYER_COLORS.size()]


func _send(data: Dictionary) -> void:
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_socket.send_text(JSON.stringify(data))


func _handle_message(raw: String) -> void:
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	var msg_type: String = data.get("type", "")

	match msg_type:
		"room_created":
			room_code = data.get("code", "")
			player_id = data.get("player_id", "")
			color_index = data.get("color_index", 0)
			is_host = true
			room_created.emit(room_code)
		"room_joined":
			room_code = data.get("code", "")
			player_id = data.get("player_id", "")
			color_index = data.get("color_index", 0)
			is_host = false
			room_joined.emit(room_code)
		"lobby_update":
			players = data.get("players", [])
			host_id = data.get("host_id", "")
			is_host = (host_id == player_id)
			lobby_updated.emit(players, host_id)
		"game_state":
			game_state_received.emit(data.get("payload", {}))
		"action":
			action_received.emit(data.get("payload", {}), data.get("from", ""))
		"player_left":
			player_left.emit(data.get("player_id", ""))
		"error":
			join_failed.emit(data.get("message", "Unknown error."))
