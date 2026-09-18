import asyncio
import os

import websockets

RDP_HOST = os.environ.get('RDP_HOST', '127.0.0.1')
RDP_PORT = int(os.environ.get('RDP_PORT', '3389'))
LISTEN_HOST = os.environ.get('RDP_WS_HOST', '127.0.0.1')
LISTEN_PORT = int(os.environ.get('RDP_WS_PORT', '6081'))


async def bridge(websocket):
    reader, writer = await asyncio.open_connection(RDP_HOST, RDP_PORT)

    async def ws_to_tcp():
        try:
            async for message in websocket:
                if isinstance(message, str):
                    message = message.encode()
                writer.write(message)
                await writer.drain()
        except Exception:
            pass
        finally:
            writer.close()

    async def tcp_to_ws():
        try:
            while True:
                data = await reader.read(65536)
                if not data:
                    break
                await websocket.send(data)
        except Exception:
            pass
        finally:
            await websocket.close()

    await asyncio.gather(ws_to_tcp(), tcp_to_ws())


async def main():
    print(f'RDP WebSocket bridge on {LISTEN_HOST}:{LISTEN_PORT} -> {RDP_HOST}:{RDP_PORT}', flush=True)
    async with websockets.serve(
        bridge,
        LISTEN_HOST,
        LISTEN_PORT,
        max_size=None,
        ping_interval=None,
    ):
        await asyncio.Future()


if __name__ == '__main__':
    asyncio.run(main())
