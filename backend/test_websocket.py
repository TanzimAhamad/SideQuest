
import asyncio
import websockets

TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI0IiwiZXhwIjoxNzkzMTY2NDc1fQ.MEgqDb-4gTA7zj0j3MxCaTsrPG5ZNnIZWHQvlkaz8Rk"
URI = f"ws://127.0.0.1:8000/ws/groups/10?token={TOKEN}"


async def main():
    async with websockets.connect(URI) as websocket:
        print("Connected successfully!")

        await websocket.send("Hello from SideQuest!")
        response = await websocket.recv()

        print("Received:", response)


asyncio.run(main())
