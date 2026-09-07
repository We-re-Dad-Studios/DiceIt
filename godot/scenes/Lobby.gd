extends Control

@onready var main_panel: PanelContainer = %MainPanel
@onready var code_caption: Label = %CodeCaption
@onready var room_code_label: Label = %RoomCodeLabel
@onready var rule: Panel = %Rule
@onready var players_caption: Label = %PlayersCaption
@onready var player_list: VBoxContainer = %PlayerList
@onready var start_button: Button = %StartButton
@onready var hint_label: Label = %HintLabel
@onready var chat_panel_container: PanelContainer = %ChatPanelContainer

var _leaving := false


func _ready() -> void:
	_apply_style()
	room_code_label.text = NetworkManager.room_code

	start_button.pressed.connect(_on_start_pressed)
	NetworkManager.lobby_updated.connect(_on_lobby_updated)
	NetworkManager.disconnected.connect(_on_disconnected)
	NetworkManager.game_state_received.connect(_on_game_state_received)
	_refresh(NetworkManager.players, NetworkManager.host_id)


func _apply_style() -> void:
	main_panel.add_theme_stylebox_override("panel", _card(36))
	chat_panel_container.add_theme_stylebox_override("panel", _card(22))

	code_caption.text = Style.spaced_caps("ROOM CODE")
	_caption(code_caption)

	# The room code is the one figure players read aloud - biggest brass on screen.
	room_code_label.add_theme_font_override("font", Style.mono_700)
	room_code_label.add_theme_font_size_override("font_size", 76)
	room_code_label.add_theme_color_override("font_color", Style.GOLD)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.BORDER
	rule.add_theme_stylebox_override("panel", sb)

	_caption(players_caption)

	start_button.add_theme_font_size_override("font_size", 19)

	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Style.INK3)


func _card(margin: int) -> StyleBoxFlat:
	var sb := Style.panel_box(Style.PANEL, Style.BORDER, 20)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb


func _caption(label: Label) -> void:
	label.add_theme_font_override("font", Style.archivo_500)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Style.INK3)


func _on_lobby_updated(players: Array, host_id: String) -> void:
	_refresh(players, host_id)


func _refresh(all_players: Array, host_id: String) -> void:
	# Seats are held for players who dropped, but the lobby only lists who is
	# actually here to start a game.
	var players: Array = all_players.filter(func(p): return bool(p.get("connected", true)))
	players_caption.text = Style.spaced_caps("PLAYERS · %d" % players.size())

	for child in player_list.get_children():
		child.queue_free()

	for p in players:
		player_list.add_child(_player_row(p, host_id))

	var is_host := NetworkManager.is_host
	start_button.visible = is_host
	start_button.disabled = players.size() < 2

	if not is_host:
		hint_label.text = "Waiting for the host to start the game..."
	elif players.size() < 2:
		hint_label.text = "Need at least 2 players to start.\n%s" % _share_hint()
	else:
		hint_label.text = _share_hint()


## On the web the room is shareable as a link; elsewhere the code is all there is.
func _share_hint() -> String:
	var link := NetworkManager.join_link()
	return "Share this link: %s" % link if not link.is_empty() else ""


## Row carries the player's colour as a 4px left edge rather than a swatch.
func _player_row(p: Dictionary, host_id: String) -> PanelContainer:
	var row := Style.row_with_edge(
		Style.PANEL_RAISED,
		Color("264035"),
		Style.player_color(p.get("color_index", 0)),
		14, 18
	)
	var content: HBoxContainer = row["content"]
	content.add_theme_constant_override("separation", 14)

	var name_label := Label.new()
	name_label.text = p.get("username", "Player")
	name_label.add_theme_font_override("font", Style.archivo_500)
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", Style.INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(name_label)

	var is_host_row: bool = p.get("id", "") == host_id
	var tag := Label.new()
	tag.text = Style.spaced_caps("HOST" if is_host_row else "READY")
	tag.add_theme_font_override("font", Style.archivo_500)
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Style.GOLD if is_host_row else Style.INK3)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(tag)

	return row["root"]


func _on_start_pressed() -> void:
	if not NetworkManager.is_host:
		return
	GameState.start_game(
		NetworkManager.players.filter(func(p): return bool(p.get("connected", true)))
	)
	NetworkManager.send_game_state(GameState.to_payload())
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_game_state_received(_payload: Dictionary) -> void:
	# A non-host player follows the host into the game.
	_change_scene("res://scenes/Game.tscn")


func _on_disconnected() -> void:
	_change_scene("res://scenes/Title.tscn")


## The host broadcasts state on every room change, so this can fire more than
## once. Leaving twice tears the scene out from under the second call.
func _change_scene(path: String) -> void:
	if _leaving or not is_inside_tree():
		return
	_leaving = true
	get_tree().change_scene_to_file.call_deferred(path)
