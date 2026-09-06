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
signal chat_received(entry: Dictionary)


var default_relay_url := "wss://diceit-pjz7.onrender.com"

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
var last_game_state: Dictionary = {}
var chat_log: Array = [] # [{username, color_index, text}], newest last


func _ready() -> void:
	# On web, ?relay=ws://host:port overrides the built-in default, so a link
	# can point players at a specific relay without a rebuild.
	var relay := get_query_param("relay")
	if not relay.is_empty():
		default_relay_url = relay


## A link that drops someone straight onto the title screen with this room's
## code already filled in. Empty off the web, where there is no page URL.
func join_link() -> String:
	if not OS.has_feature("web") or JavaScriptBridge.get_interface("window") == null:
		return ""
	if room_code.is_empty():
		return ""
	var origin: String = str(JavaScriptBridge.eval("window.location.origin + window.location.pathname", true))
	return "%s?room=%s" % [origin, room_code]


## Reads a query-string parameter from the page URL. Always "" off the web.
func get_query_param(key: String) -> String:
	if not OS.has_feature("web") or JavaScriptBridge.get_interface("window") == null:
		return ""

	var search: String = str(JavaScriptBridge.eval("window.location.search", true))
	var marker := key + "="
	var at := search.find(marker)
	if at == -1:
		return ""

	var raw := search.substr(at + marker.length())
	var amp := raw.find("&")
	if amp != -1:
		raw = raw.substr(0, amp)
	if raw.is_empty():
		return ""
	return str(JavaScriptBridge.eval("decodeURIComponent('%s')" % raw, true))


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


func send_chat(text: String) -> void:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	_send({"type": "chat", "text": trimmed})


func leave_room() -> void:
	if _socket != null:
		_socket.close()
	_socket = null
	room_code = ""
	player_id = ""
	is_host = false
	players = []
	host_id = ""
	last_game_state = {}
	chat_log = []


func get_player_color(idx: int) -> Color:
	return Style.player_color(idx)


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
			last_game_state = data.get("payload", {})
			game_state_received.emit(last_game_state)
		"action":
			action_received.emit(data.get("payload", {}), data.get("from", ""))
		"chat":
			var entry := {
				"username": data.get("username", "Player"),
				"color_index": data.get("color_index", 0),
				"text": data.get("text", ""),
			}
			chat_log.append(entry)
			if chat_log.size() > 50:
				chat_log.pop_front()
			chat_received.emit(entry)
		"player_left":
			player_left.emit(data.get("player_id", ""))
		"error":
			join_failed.emit(data.get("message", "Unknown error."))
