"""
Bank or Bust - relay server.

A dumb message router keyed by room code. Never runs game logic - it just
lets a host client and joining clients exchange JSON messages by room.

Protocol (all messages are JSON text frames):

  Client -> server:
    {"type": "create_room", "username": "..."}
    {"type": "join_room", "code": "AB12", "username": "..."}
    {"type": "game_state", "payload": {...}}   # host only, broadcast to room
    {"type": "action", "payload": {...}}       # any client, routed to host
    {"type": "leave_room"}

  Server -> client:
    {"type": "room_created", "code": "AB12", "player_id": "...", "color_index": 0}
    {"type": "room_joined", "code": "AB12", "player_id": "...", "color_index": 1}
    {"type": "lobby_update", "players": [{"id","username","color_index"}, ...], "host_id": "..."}
    {"type": "game_state", "payload": {...}}
    {"type": "action", "payload": {...}, "from": "player_id"}
    {"type": "player_left", "player_id": "..."}
    {"type": "error", "message": "..."}
"""

import asyncio
import json
import os
import random
import string
import uuid

import websockets

COLOR_COUNT = 8
ROOM_CODE_CHARS = string.ascii_uppercase + string.digits
ROOM_CODE_LENGTH = 4


class Player:
    def __init__(self, player_id, username, color_index, ws):
        self.id = player_id
        self.username = username
        self.color_index = color_index
        self.ws = ws

    @property
    def connected(self):
        return self.ws is not None

    def to_dict(self):
        return {
            "id": self.id,
            "username": self.username,
            "color_index": self.color_index,
            "connected": self.connected,
        }


class Room:
    def __init__(self, code, host_id):
        self.code = code
        self.host_id = host_id
        self.players = {}  # id -> Player, including seats whose player dropped

    def next_color_index(self):
        used = {p.color_index for p in self.players.values()}
        for i in range(COLOR_COUNT):
            if i not in used:
                return i
        return len(self.players) % COLOR_COUNT

    def connected_players(self):
        return [p for p in self.players.values() if p.connected]

    def lobby_update_message(self):
        return {
            "type": "lobby_update",
            "players": [p.to_dict() for p in self.players.values()],
            "host_id": self.host_id,
        }


rooms = {}  # code -> Room
socket_to_room = {}  # websocket -> (room_code, player_id)


def generate_room_code():
    while True:
        code = "".join(random.choices(ROOM_CODE_CHARS, k=ROOM_CODE_LENGTH))
        if code not in rooms:
            return code


async def send(ws, message):
    if ws is None:
        return
    try:
        await ws.send(json.dumps(message))
    except websockets.exceptions.ConnectionClosed:
        pass


async def broadcast(room, message, exclude_id=None):
    for player in list(room.players.values()):
        if player.id != exclude_id:
            await send(player.ws, message)


def sanitize_token(raw):
    """A client-supplied seat token. Random and never displayed, so it works as
    a bearer token for reclaiming a seat after a dropped connection."""
    token = str(raw or "")
    if 8 <= len(token) <= 64 and all(c in string.hexdigits for c in token):
        return token
    return None


async def handle_create_room(ws, data):
    username = str(data.get("username", "Player"))[:20]
    code = generate_room_code()
    player_id = sanitize_token(data.get("token")) or uuid.uuid4().hex[:8]
    room = Room(code, host_id=player_id)
    player = Player(player_id, username, 0, ws)
    room.players[player_id] = player
    rooms[code] = room
    socket_to_room[ws] = (code, player_id)

    await send(ws, {
        "type": "room_created",
        "code": code,
        "player_id": player_id,
        "color_index": player.color_index,
    })
    await broadcast(room, room.lobby_update_message())


async def handle_join_room(ws, data):
    code = str(data.get("code", "")).upper().strip()
    username = str(data.get("username", "Player"))[:20]
    room = rooms.get(code)
    if room is None:
        await send(ws, {"type": "error", "message": "Room not found."})
        return

    # Reclaiming a seat after a dropped connection: same id, same colour, and
    # the host's game state still has the player's score waiting. Only seats
    # that are actually vacant can be reclaimed, so an active player cannot be
    # kicked off by someone replaying their token.
    token = sanitize_token(data.get("token"))
    existing = room.players.get(token) if token else None
    if existing is not None and not existing.connected:
        existing.ws = ws
        existing.username = username or existing.username
        socket_to_room[ws] = (code, existing.id)

        await send(ws, {
            "type": "room_joined",
            "code": code,
            "player_id": existing.id,
            "color_index": existing.color_index,
            "reclaimed": True,
        })
        await broadcast(room, {"type": "player_rejoined", "player_id": existing.id})
        await broadcast(room, room.lobby_update_message())
        return

    player_id = token if (token and token not in room.players) else uuid.uuid4().hex[:8]
    color_index = room.next_color_index()
    player = Player(player_id, username, color_index, ws)
    room.players[player_id] = player
    socket_to_room[ws] = (code, player_id)

    await send(ws, {
        "type": "room_joined",
        "code": code,
        "player_id": player_id,
        "color_index": color_index,
        "reclaimed": False,
    })
    await broadcast(room, room.lobby_update_message())


async def handle_game_state(ws, data):
    entry = socket_to_room.get(ws)
    if entry is None:
        return
    code, player_id = entry
    room = rooms.get(code)
    if room is None or player_id != room.host_id:
        return  # only the host may broadcast game state
    await broadcast(room, {"type": "game_state", "payload": data.get("payload", {})}, exclude_id=player_id)


async def handle_chat(ws, data):
    entry = socket_to_room.get(ws)
    if entry is None:
        return
    code, player_id = entry
    room = rooms.get(code)
    if room is None:
        return
    player = room.players.get(player_id)
    if player is None:
        return
    text = str(data.get("text", ""))[:300]
    if not text.strip():
        return
    await broadcast(room, {
        "type": "chat",
        "player_id": player.id,
        "username": player.username,
        "color_index": player.color_index,
        "text": text,
    })


async def handle_action(ws, data):
    entry = socket_to_room.get(ws)
    if entry is None:
        return
    code, player_id = entry
    room = rooms.get(code)
    if room is None:
        return
    host = room.players.get(room.host_id)
    if host is None:
        return
    await send(host.ws, {"type": "action", "payload": data.get("payload", {}), "from": player_id})


async def remove_player(ws):
    """A dropped connection vacates the seat but does not destroy it, so the
    player can reclaim it (score intact) by rejoining with the same token."""
    entry = socket_to_room.pop(ws, None)
    if entry is None:
        return
    code, player_id = entry
    room = rooms.get(code)
    if room is None:
        return

    player = room.players.get(player_id)
    if player is None:
        return
    player.ws = None

    remaining = room.connected_players()
    if not remaining:
        # Nobody left to hold the room open; the seats go with it.
        rooms.pop(code, None)
        return

    if player_id == room.host_id:
        # The host runs the game logic, so it has to move to someone present.
        room.host_id = remaining[0].id

    await broadcast(room, {"type": "player_left", "player_id": player_id})
    await broadcast(room, room.lobby_update_message())


HANDLERS = {
    "create_room": handle_create_room,
    "join_room": handle_join_room,
    "game_state": handle_game_state,
    "action": handle_action,
    "chat": handle_chat,
}


async def handle_connection(ws):
    try:
        async for raw in ws:
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                continue
            handler = HANDLERS.get(data.get("type"))
            if handler:
                await handler(ws, data)
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        await remove_player(ws)


async def main():
    port = int(os.environ.get("PORT", 8765))
    async with websockets.serve(handle_connection, "0.0.0.0", port):
        print(f"Relay server listening on 0.0.0.0:{port}")
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
