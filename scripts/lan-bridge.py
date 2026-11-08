"""Minimal TCP forwarder used to expose the web container beyond loopback.

Docker Desktop on Windows publishes container ports on 127.0.0.1 only, so a
phone on the same Wi-Fi cannot reach the app. This listens on 0.0.0.0 for the
public port and forwards to the loopback port the container is published on.

Usage: python lan_bridge.py 3000=3030 [8080=8080 ...]
"""

import asyncio
import sys


async def pipe(reader, writer):
    try:
        while True:
            chunk = await reader.read(65536)
            if not chunk:
                break
            writer.write(chunk)
            await writer.drain()
    except (ConnectionResetError, BrokenPipeError, asyncio.CancelledError):
        pass
    finally:
        try:
            writer.close()
        except Exception:
            pass


async def handle(client_reader, client_writer, target_port):
    try:
        server_reader, server_writer = await asyncio.open_connection(
            "127.0.0.1", target_port
        )
    except OSError:
        client_writer.close()
        return
    await asyncio.gather(
        pipe(client_reader, server_writer),
        pipe(server_reader, client_writer),
    )


async def serve(listen_port, target_port):
    server = await asyncio.start_server(
        lambda r, w: handle(r, w, target_port), "0.0.0.0", listen_port
    )
    print(
        f"forwarding 0.0.0.0:{listen_port} -> 127.0.0.1:{target_port}",
        flush=True,
    )
    async with server:
        await server.serve_forever()


def parse(arg):
    if "=" in arg:
        listen, target = arg.split("=", 1)
        return int(listen), int(target)
    return int(arg), int(arg)


async def main(pairs):
    await asyncio.gather(*(serve(listen, target) for listen, target in pairs))


if __name__ == "__main__":
    pairs = [parse(arg) for arg in sys.argv[1:]] or [(3000, 3030)]
    try:
        asyncio.run(main(pairs))
    except OSError as error:
        print(f"bind failed: {error}", flush=True)
        raise SystemExit(1)
