#!/usr/bin/env python3
"""A scripted stand-in for ComfyUI's HTTP and websocket surface (E2.S2): POST /prompt, GET /history/<id>, GET /ws, GET /system_stats.

  comfy_server.py --script <json> --out <folder> --port-file <file>

It listens on 127.0.0.1 on a free port, writes the port to --port-file once it listens, and writes ONLY below --out (the output files a run saves there, the way
ComfyUI saves into its --output-directory). The JSON script (the test writes it before the start):

  {"system_stats": {"argv": [...], "vram_free": n, "vram_total": n},     what GET /system_stats answers (devices[0] and system.argv)
   "prompts": [ <one script per POSTed prompt, in order; the last one repeats> ]}

  one prompt script (every key optional):
   "refuse": {"status": 400, "body": {...}}        /prompt answers this and nothing else happens
   "messages": [{"type": "...", "data": {...}, "after": <seconds slept AFTER sending it>}, ...]   the websocket messages of the run; `prompt_id` is added to `data`
   "history_delay": <seconds after the last message before /history/<id> has the entry>
   "history": {"status": {...}, ...}               keys merged over the entry the server builds (status, outputs)
   "output": {"kind": "image", "width": n, "height": n, "fill": "noise" | [r, g, b]}   or   {"kind": "video", "width", "height", "frames", "source": "testsrc" | "color"}
                                                   the file written into --out, named like ComfyUI's SaveImage / SaveVideo (<filename_prefix>_00001_.png | .mp4); a video is
                                                   made by ffmpeg (a test that needs one needs the program)

GET /_recorded answers the list of the prompts that were POSTed (the graphs), so a test can read the seeds a bench sent.
Standard library, aiohttp, Pillow and numpy (the tests' pinned requirements); ffmpeg only for a video."""
import argparse
import asyncio
import json
import os
import subprocess
import sys
import uuid
from pathlib import Path

from aiohttp import web


def write_image(path, spec):
    import numpy
    from PIL import Image
    width, height, fill = spec["width"], spec["height"], spec.get("fill", "noise")
    if fill == "noise":
        array = numpy.random.default_rng(7).integers(0, 256, size=(height, width, 3), dtype=numpy.uint8)
    else:
        array = numpy.full((height, width, 3), fill, dtype=numpy.uint8)
    Image.fromarray(array).save(path)


def write_video(path, spec):
    size = f"size={spec['width']}x{spec['height']}:rate=24"
    lavfi = f"testsrc={size}" if spec.get("source", "testsrc") == "testsrc" else f"color=c=gray:{size}"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", lavfi, "-frames:v", str(spec["frames"]), "-pix_fmt", "yuv420p", str(path)], check=True)


class Server:
    def __init__(self, script, out):
        self.script, self.out = script, Path(out)
        self.sockets, self.history, self.recorded, self.posted = {}, {}, [], 0

    def prompt_script(self, number):
        prompts = self.script.get("prompts") or [{}]
        return prompts[min(number, len(prompts) - 1)]

    async def system_stats(self, request):
        stats = self.script.get("system_stats") or {}
        card = {"name": "cuda:0 fixture : native", "vram_total": stats.get("vram_total", 34359738368), "vram_free": stats.get("vram_free", 34000000000)}
        return web.json_response({"system": {"argv": stats.get("argv", ["main.py"])}, "devices": [card]})

    async def ws(self, request):
        socket = web.WebSocketResponse()
        await socket.prepare(request)
        client = request.query.get("clientId", "")
        self.sockets[client] = socket
        async for _ in socket:
            pass
        return socket

    async def prompt(self, request):
        body = await request.json()
        number, self.posted = self.posted, self.posted + 1
        self.recorded.append(body["prompt"])
        script = self.prompt_script(number)
        if "refuse" in script:
            return web.json_response(script["refuse"].get("body", {}), status=script["refuse"].get("status", 400))
        prompt_id = str(uuid.uuid4())
        asyncio.get_running_loop().create_task(self.play(prompt_id, body.get("client_id", ""), body["prompt"], script))
        return web.json_response({"prompt_id": prompt_id, "number": number, "node_errors": {}})

    async def play(self, prompt_id, client, graph, script):
        socket = self.sockets.get(client)
        for item in script.get("messages", []):
            if socket is not None and not socket.closed:
                await socket.send_str(json.dumps({"type": item["type"], "data": {"prompt_id": prompt_id, **item.get("data", {})}}))
            await asyncio.sleep(item.get("after", 0))
        await asyncio.sleep(script.get("history_delay", 0))
        entry = {"status": {"status_str": "success", "completed": True, "messages": []}, "outputs": {}}
        output = script.get("output")
        if output:
            save = graph["save"]["inputs"]["filename_prefix"]
            name = f"{save}_00001_.{'png' if output['kind'] == 'image' else 'mp4'}"
            self.out.mkdir(parents=True, exist_ok=True)
            (write_image if output["kind"] == "image" else write_video)(self.out / name, output)
            entry["outputs"] = {"save": {"images": [{"filename": name, "subfolder": "", "type": "output"}]}}
        entry.update(script.get("history", {}))
        self.history[prompt_id] = entry

    async def history_one(self, request):
        pid = request.match_info["prompt_id"]
        return web.json_response({pid: self.history[pid]} if pid in self.history else {})

    async def recorded_prompts(self, request):
        return web.json_response(self.recorded)


async def serve(script, out, port_file):
    server = Server(script, out)
    app = web.Application()
    app.add_routes([web.get("/system_stats", server.system_stats), web.get("/ws", server.ws), web.post("/prompt", server.prompt),
                    web.get("/history/{prompt_id}", server.history_one), web.get("/_recorded", server.recorded_prompts)])
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", 0)
    await site.start()
    port = site._server.sockets[0].getsockname()[1]
    part = f"{port_file}.part"
    Path(part).write_text(str(port))
    os.replace(part, port_file)
    await asyncio.Event().wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--script", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--port-file", required=True)
    args = parser.parse_args()
    asyncio.run(serve(json.loads(Path(args.script).read_text()), args.out, args.port_file))


if __name__ == "__main__":
    sys.exit(main())
