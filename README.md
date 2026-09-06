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
   The relay URL is baked into `NetworkManager.default_relay_url`; on the
   web it can be overridden per-link with `?relay=ws://127.0.0.1:8765`.
4. One instance clicks **Create Room**, the others enter that room code
   and click **Join Room**. Host clicks **Start Game** once everyone's in.

### Shareable join links (web)

The lobby shows a link that carries the room code, so the host can paste it
into a chat instead of dictating four characters. Supported parameters:

- `?room=AB12` — prefills the room code
- `?name=alice` — prefills the username
- `&go=1` — with a name present, creates or joins immediately

`?room=AB12&name=bob&go=1` drops a player straight into that room.

## Playing in a browser

The game exports to web, so players just open a link — no download.

Build it:

```bash
cd godot && "/c/Program Files/Godot/godot.exe" --headless --export-release "Web" ../build/web/index.html
```

Test it locally:

```bash
cd build/web && python -m http.server 8080
```

Then open `http://localhost:8080/index.html`. Add `?relay=ws://127.0.0.1:8765`
to point at a local relay instead of the deployed one — handy while developing.

### Deploying to Netlify

The exported build is plain static files, so Netlify hosts it happily. The
`index.wasm` is ~39 MB, which is why `build/` stays out of git — deploy the
folder directly rather than committing it:

- **Easiest:** drag the `build/web` folder onto the Netlify dashboard
  (netlify.com → "Add new site" → "Deploy manually").
- **Or with the CLI:** `npx netlify-cli deploy --prod --dir=build/web`

Re-run the export and re-deploy whenever you change the game. The relay server
is separate and keeps running on Render — Netlify only serves the client.

## Rules (v1)

- Each round starts with 5 live dice.
- Roll all live dice. Any showing a 1 busts and is set aside for the round.
- Choose which non-busted dice to lock in (adds their value to the round
  pot) and which to leave live for another reroll.
- If every die still in play busts on a single roll before you lock
  anything from it, the whole round pot is lost.
- With at least one live die left, reroll or bank (add the pot to your
  score and pass the turn).
- **The game ends when someone reaches 4000 points** (`TARGET_SCORE` in
  `godot/autoload/GameState.gd`) — they win immediately and a game-over panel
  shows the final standings.

There's also a room chat, shared between the lobby and the game.

Cut from v1: the between-round shop/modifiers and persisted high scores —
see the original design doc for that scope if it gets added back later.
