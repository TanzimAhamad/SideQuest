
import asyncio
import websockets


async def main():
    uri = "ws://127.0.0.1:8000/ws/groups/10"

    async with (
        websockets.connect(uri) as client_a,
        websockets.connect(uri) as client_b,
    ):
        print("Both clients connected to group 10.")

        # Client A sends a message
        await client_a.send("Hello from Client A!")

        # Both clients should receive the broadcast
        message_a = await client_a.recv()
        message_b = await client_b.recv()

        print("Client A received:", message_a)
        print("Client B received:", message_b)


asyncio.run(main())
