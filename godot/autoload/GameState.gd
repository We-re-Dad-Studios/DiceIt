extends Node
## Authoritative push-your-luck rules. Only the host's copy of this node is
## ever actually driving the game - joiners just render the state_changed
## payloads the host broadcasts over the network. See Game.gd for the glue.

signal state_changed(payload: Dictionary)

const STARTING_DICE := 5
const TARGET_SCORE := 4000

var players: Array = []       # [{id, username, color_index, score}]
var turn_order: Array = []    # [player_id, ...]
var current_turn_index := 0

var live_count := STARTING_DICE
var last_roll: Array = []     # [{value:int, busted:bool}]
var locked_dice: Array = []   # [int, ...] values locked in so far this round
var round_pot := 0
var phase := "lobby"          # lobby | await_roll | await_choice | round_lost | game_over
var winner_id := ""
var message := ""

## Dice from the turn that just ended, kept so the next state still shows what
## happened (busted or banked) without needing a timed pause between turns.
var last_turn_dice: Array = []


func start_game(player_list: Array) -> void:
	players = []
	for p in player_list:
		players.append({
			"id": p.get("id", ""),
			"username": p.get("username", "Player"),
			"color_index": p.get("color_index", 0),
			"score": 0,
			"turns": 0,   # turns finished, for the final standings line
			"banks": 0,   # of those, how many ended in a bank rather than a bust
			"connected": true,
		})
	turn_order = players.map(func(p): return p["id"])
	current_turn_index = 0
	winner_id = ""
	_reset_turn()
	_emit_state()


## Host-only: deal a fresh game, keeping the room intact. Pass the room's
## current roster so anyone who joined mid-game (and has been spectating) is
## dealt in, and anyone who left is dropped.
func restart(roster: Array = []) -> void:
	if roster.is_empty():
		# Taken from the room rather than a client's request, so nobody can
		# rewrite the table by sending a doctored roster.
		roster = NetworkManager.players.filter(func(p): return bool(p.get("connected", true)))
	if roster.is_empty():
		roster = players.map(func(p): return {
			"id": p["id"], "username": p["username"], "color_index": p["color_index"],
		})
	start_game(roster)


## Host-only: take over an in-progress game from a state broadcast. Used when
## the host drops and the relay promotes another player, who would otherwise
## hold no game state and leave everyone stuck.
func adopt(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	players = payload.get("players", []).duplicate(true)
	turn_order = payload.get("turn_order", []).duplicate(true)
	current_turn_index = int(payload.get("current_turn_index", 0))
	live_count = int(payload.get("live_count", STARTING_DICE))
	last_roll = payload.get("last_roll", []).duplicate(true)
	locked_dice = payload.get("locked_dice", []).duplicate(true)
	last_turn_dice = payload.get("last_turn_dice", []).duplicate(true)
	round_pot = int(payload.get("round_pot", 0))
	phase = str(payload.get("phase", "await_roll"))
	winner_id = str(payload.get("winner_id", ""))
	message = str(payload.get("message", ""))


## Host-only: a player's connection dropped or came back. An absent player's
## turn is forfeited rather than left to stall the table.
func set_connected(pid: String, is_connected: bool) -> void:
	var player := _find_player(pid)
	if player.is_empty() or bool(player.get("connected", true)) == is_connected:
		return
	player["connected"] = is_connected

	if is_connected or phase == "game_over" or turn_order.is_empty():
		_emit_state()
		return

	if pid == current_player_id():
		var lost := round_pot
		round_pot = 0
		var summary := "%s disconnected" % player.get("username", "Player")
		if lost > 0:
			summary += " and lost %d points" % lost
		_advance_turn(summary + ".", [])
	else:
		_emit_state()


func apply_action(from_id: String, action: String, payload: Dictionary) -> void:
	# Play Again is open to anyone once the game is over, not just whoever
	# happens to be first in the turn order.
	if action == "restart":
		if phase == "game_over":
			restart()
		return

	if phase == "game_over":
		return
	if from_id != current_player_id():
		return # not this player's turn

	match action:
		"roll":
			if phase == "await_roll":
				_do_roll()
		"lock":
			if phase == "await_choice":
				_do_lock(payload.get("indices", []))
		"bank":
			if phase == "await_roll" or phase == "await_choice":
				_do_bank()


func current_player_id() -> String:
	if turn_order.is_empty():
		return ""
	return turn_order[current_turn_index]


func _find_player(pid: String) -> Dictionary:
	for p in players:
		if p["id"] == pid:
			return p
	return {}


func _reset_turn() -> void:
	live_count = STARTING_DICE
	last_roll = []
	locked_dice = []
	last_turn_dice = []
	round_pot = 0
	phase = "await_roll"
	message = ""


func _do_roll() -> void:
	var results: Array = []
	var busted_count := 0
	for i in range(live_count):
		var value := randi_range(1, 6)
		var busted := value == 1
		if busted:
			busted_count += 1
		results.append({"value": value, "busted": busted})

	last_roll = results

	if busted_count == live_count:
		# Every die still in play busted before anything from this roll locked in.
		var lost := round_pot
		round_pot = 0
		var busting_player := _find_player(current_player_id())
		if not busting_player.is_empty():
			busting_player["turns"] = int(busting_player.get("turns", 0)) + 1
		_advance_turn("%s busted and lost %d points." % [_current_username(), lost], results)
		return

	live_count -= busted_count
	phase = "await_choice"
	_emit_state()


func _do_lock(indices: Array) -> void:
	var locked_value := 0
	var locked_count := 0
	for i in indices:
		var idx := int(i)
		if idx < 0 or idx >= last_roll.size():
			continue
		var entry: Dictionary = last_roll[idx]
		if entry.get("busted", true):
			continue
		locked_value += int(entry.get("value", 0))
		locked_count += 1
		locked_dice.append(int(entry.get("value", 0)))

	round_pot += locked_value
	live_count -= locked_count
	last_roll = []

	if live_count <= 0:
		_do_bank()
		return

	phase = "await_roll"
	message = ""
	_emit_state()


func _do_bank() -> void:
	var player := _find_player(current_player_id())
	var banked := round_pot
	if not player.is_empty():
		player["score"] += banked
		player["turns"] = int(player.get("turns", 0)) + 1
		player["banks"] = int(player.get("banks", 0)) + 1

	if player.get("score", 0) >= TARGET_SCORE:
		phase = "game_over"
		winner_id = player.get("id", "")
		message = "%s banked %d points." % [player.get("username", "Player"), banked]
		_emit_state()
		return

	var banked_faces: Array = locked_dice.map(func(v): return {"value": v, "busted": false})
	_advance_turn("%s banked %d points." % [player.get("username", "Player"), banked], banked_faces)


func _current_username() -> String:
	return _find_player(current_player_id()).get("username", "Player")


func _advance_turn(summary: String, closing_dice: Array) -> void:
	current_turn_index = _next_present_index(current_turn_index)
	_reset_turn()
	message = summary
	last_turn_dice = closing_dice
	_emit_state()


## The next seat whose player is still connected. Falls back to simply moving
## along if nobody is, so a table of dropped players can never spin forever.
func _next_present_index(from_index: int) -> int:
	var count := turn_order.size()
	for step in range(1, count + 1):
		var candidate := (from_index + step) % count
		var player := _find_player(turn_order[candidate])
		if player.is_empty() or bool(player.get("connected", true)):
			return candidate
	return (from_index + 1) % count


func _emit_state() -> void:
	state_changed.emit(to_payload())


func to_payload() -> Dictionary:
	return {
		"players": players.duplicate(true),
		"turn_order": turn_order.duplicate(true),
		"current_turn_index": current_turn_index,
		"current_player_id": current_player_id(),
		"live_count": live_count,
		"last_roll": last_roll.duplicate(true),
		"locked_dice": locked_dice.duplicate(true),
		"last_turn_dice": last_turn_dice.duplicate(true),
		"round_pot": round_pot,
		"phase": phase,
		"winner_id": winner_id,
		"message": message,
		"target_score": TARGET_SCORE,
	}
