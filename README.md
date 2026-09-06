# Bank or Bust

A multiplayer push-your-luck dice game. No accounts — enter a username,
create a room and share the code, or join with one. Sequential turns:
roll, choose which dice to lock in, bank your points or push your luck.

## Project layout

- `godot/` — the Godot 4.7 project (open this folder in Godot).
- `relay_server/` — a small Python WebSocket relay that lets a host and
  joiners find each other by room code. See `relay_server/README.md` for
  local run + Render.com deploy instructions.

## Quick start (local testing)

1. `cd relay_server && pip install -r requirements.txt && python relay.py`
2. Open `godot/project.godot` in Godot 4.7.
3. Run the project (F5). Use **Debug → Run Multiple Instances** (or just
   export/run a second copy) to test with 2+ "players" on one machine.
   The default relay URL (`ws://127.0.0.1:8765`) is pre-filled on the
   title screen.
4. One instance clicks **Create Room**, the others enter that room code
   and click **Join Room**. Host clicks **Start Game** once everyone's in.

## Rules (v1)

- Each round starts with 5 live dice.
- Roll all live dice. Any showing a 1 busts and is set aside for the round.
- Choose which non-busted dice to lock in (adds their value to the round
  pot) and which to leave live for another reroll.
- If every die still in play busts on a single roll before you lock
  anything from it, the whole round pot is lost.
- With at least one live die left, reroll or bank (add the pot to your
  score and pass the turn).
- First to 4000 points wins.

Cut from v1: the between-round shop/modifiers and persisted high scores —
see the original design doc for that scope if it gets added back later.
