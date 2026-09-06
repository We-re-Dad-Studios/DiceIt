extends VBoxContainer
## Room chat. Attached to a ChatBox node in both Lobby.tscn and Game.tscn -
## history lives in NetworkManager so it survives the scene change between them.

@onready var chat_log_box: VBoxContainer = %ChatLog
@onready var chat_scroll: ScrollContainer = %ChatScroll
@onready var chat_input: LineEdit = %ChatInput
@onready var chat_send_button: Button = %ChatSendButton


func _ready() -> void:
	chat_send_button.pressed.connect(_send_current_text)
	chat_input.text_submitted.connect(func(_t: String): _send_current_text())
	NetworkManager.chat_received.connect(_on_chat_received)

	for entry in NetworkManager.chat_log:
		_append_entry(entry)


func _send_current_text() -> void:
	NetworkManager.send_chat(chat_input.text)
	chat_input.text = ""


func _on_chat_received(entry: Dictionary) -> void:
	_append_entry(entry)


func _append_entry(entry: Dictionary) -> void:
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.scroll_active = false

	var color: Color = NetworkManager.get_player_color(entry.get("color_index", 0))
	var username: String = entry.get("username", "Player")
	var text: String = entry.get("text", "")
	line.text = "[color=#%s]%s:[/color] %s" % [color.to_html(false), username, text]

	chat_log_box.add_child(line)
	await get_tree().process_frame
	chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)
