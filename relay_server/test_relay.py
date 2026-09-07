"""End-to-end checks for the relay's seat handling.

Run the relay first:  python relay.py
Then:                 python test_relay.py
"""

import asyncio
import json

import websockets

URL = "ws://127.0.0.1:8765"


async def recv_until(ws, kind, timeout=3):
    """Reads until a message of `kind` arrives, skipping the rest."""
    async def pump():
        while True:
            data = json.loads(await ws.recv())
            if data.get("type") == kind:
                return data
    return await asyncio.wait_for(pump(), timeout)


async def create(username="host", token=None):
    ws = await websockets.connect(URL)
    await ws.send(json.dumps({"type": "create_room", "username": username, "token": token}))
    created = await recv_until(ws, "room_created")
    return ws, created


async def join(code, username, token=None):
    ws = await websockets.connect(URL)
    await ws.send(json.dumps({
        "type": "join_room", "code": code, "username": username, "token": token,
    }))
    joined = await recv_until(ws, "room_joined")
    return ws, joined


async def test_seat_is_reclaimed_after_a_drop():
    host_ws, created = await create()
    code = created["code"]
    token = "a1b2c3d4e5f60718"

    guest_ws, joined = await join(code, "guest", token)
    assert joined["player_id"] == token, joined
    assert joined["reclaimed"] is False
    colour = joined["color_index"]

    await guest_ws.close()
    left = await recv_until(host_ws, "player_left")
    assert left["player_id"] == token, left

    # The seat is still listed, marked as away.
    lobby = await recv_until(host_ws, "lobby_update")
    seats = {p["id"]: p for p in lobby["players"]}
    assert seats[token]["connected"] is False, lobby

    back_ws, rejoined = await join(code, "guest", token)
    assert rejoined["reclaimed"] is True, rejoined
    assert rejoined["player_id"] == token
    assert rejoined["color_index"] == colour, "colour should survive a reconnect"

    await recv_until(host_ws, "player_rejoined")
    await host_ws.close()
    await back_ws.close()
    print("ok  seat is reclaimed after a drop, with its colour")


async def test_active_seat_cannot_be_stolen():
    host_ws, created = await create()
    code = created["code"]
    token = "beefbeefbeefbeef"

    first_ws, first = await join(code, "guest", token)
    assert first["player_id"] == token

    # Someone replaying the token while the seat is occupied gets their own.
    thief_ws, thief = await join(code, "thief", token)
    assert thief["player_id"] != token, thief
    assert thief["reclaimed"] is False

    await host_ws.close()
    await first_ws.close()
    await thief_ws.close()
    print("ok  an occupied seat cannot be taken over with the same token")


async def test_host_moves_on_when_the_host_drops():
    host_ws, created = await create()
    code = created["code"]
    guest_ws, joined = await join(code, "guest")
    await recv_until(guest_ws, "lobby_update")

    await host_ws.close()
    lobby = await recv_until(guest_ws, "lobby_update")
    assert lobby["host_id"] == joined["player_id"], lobby

    await guest_ws.close()
    print("ok  host role moves to a player who is still connected")


async def test_room_closes_once_everyone_is_gone():
    host_ws, created = await create()
    code = created["code"]
    await host_ws.close()
    await asyncio.sleep(0.3)

    ws = await websockets.connect(URL)
    await ws.send(json.dumps({"type": "join_room", "code": code, "username": "late"}))
    err = await recv_until(ws, "error")
    assert "not found" in err["message"].lower(), err
    await ws.close()
    print("ok  room is discarded once every seat is empty")


async def main():
    await test_seat_is_reclaimed_after_a_drop()
    await test_active_seat_cannot_be_stolen()
    await test_host_moves_on_when_the_host_drops()
    await test_room_closes_once_everyone_is_gone()
    print("\nall relay tests passed")


asyncio.run(main())
