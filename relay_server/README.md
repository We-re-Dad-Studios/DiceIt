# Bank or Bust — Relay Server

A tiny WebSocket relay used to connect players by room code. It never runs
game logic — it just routes JSON messages between the host and joiners in
the same room. See the docstring at the top of `relay.py` for the message
protocol.

## Run locally

```bash
pip install -r requirements.txt
python relay.py
```

Listens on `ws://localhost:8765` by default (or `$PORT` if set).

Point the Godot client at `ws://127.0.0.1:8765` while developing — this lets
you test the full create-room / join-room / play loop with multiple Godot
instances on one machine before deploying anywhere.

## Deploy to Render.com (free tier)

1. Push this repo (or just the `relay_server/` folder) to a GitHub repo.
2. On [render.com](https://render.com), create a free account.
3. **New +** → **Web Service** → connect the GitHub repo.
4. Settings:
   - **Root directory**: `relay_server` (if the repo has other folders too)
   - **Runtime**: Python 3
   - **Build command**: `pip install -r requirements.txt`
   - **Start command**: `python relay.py`
   - **Instance type**: Free
5. Deploy. Render assigns a public URL like `https://your-app.onrender.com`.
   The WebSocket URL to use in the Godot client is the `wss://` version of
   that same host: `wss://your-app.onrender.com`.
6. Free-tier note: the service spins down after ~15 minutes idle. The first
   connection after that will take 30-60 seconds to wake it up — totally
   fine for casual play with friends, just don't expect an instant connect
   if nobody's played in a while.
