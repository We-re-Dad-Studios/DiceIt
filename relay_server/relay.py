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

    def to_dict(self):
        return {"id": self.id, "username": self.username, "color_index": self.color_index}


class Room:
    def __init__(self, code, host_id):
        self.code = code
        self.host_id = host_id
        self.players = {}  # id -> Player

    def next_color_index(self):
        used = {p.color_index for p in self.players.values()}
        for i in range(COLOR_COUNT):
            if i not in used:
                return i
        return len(self.players) % COLOR_COUNT

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
    try:
        await ws.send(json.dumps(message))
    except websockets.exceptions.ConnectionClosed:
        pass


async def broadcast(room, message, exclude_id=None):
    for player in list(room.players.values()):
        if player.id != exclude_id:
            await send(player.ws, message)


async def handle_create_room(ws, data):
    username = str(data.get("username", "Player"))[:20]
    code = generate_room_code()
    player_id = uuid.uuid4().hex[:8]
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

    player_id = uuid.uuid4().hex[:8]
    color_index = room.next_color_index()
    player = Player(player_id, username, color_index, ws)
    room.players[player_id] = player
    socket_to_room[ws] = (code, player_id)

    await send(ws, {
        "type": "room_joined",
        "code": code,
        "player_id": player_id,
        "color_index": color_index,
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
    entry = socket_to_room.pop(ws, None)
    if entry is None:
        return
    code, player_id = entry
    room = rooms.get(code)
    if room is None:
        return
    room.players.pop(player_id, None)

    if not room.players:
        rooms.pop(code, None)
        return

    if player_id == room.host_id:
        # Host left: promote the earliest-joined remaining player.
        room.host_id = next(iter(room.players))

    await broadcast(room, {"type": "player_left", "player_id": player_id})
    await broadcast(room, room.lobby_update_message())


HANDLERS = {
    "create_room": handle_create_room,
    "join_room": handle_join_room,
    "game_state": handle_game_state,
    "action": handle_action,
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
