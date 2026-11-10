"""The one HTTP client of the ComfyUI tools in this folder: queue one prompt (a graph in ComfyUI's API format) and wait for its history entry.

Standard library only, synchronous. comfyui/bench.py keeps its own asynchronous client: it times websocket events between nodes and prints the verdict grammar,
which these tools do not need, and its client is bound to that timing — reusing it here would tie a measured tool to tools that change for other reasons.

  run(graph, ceiling_s, api_url=None) -> (seconds, files)   files: the {"filename", "subfolder", "type"} dicts of every output of the entry
  api()                                                 COMFY_TOOLS_API, default http://127.0.0.1:8188 (the server as seen from inside its container)

Every wait has a ceiling: each HTTP call 30 s (CALL_TIMEOUT_S), the whole run `ceiling_s`. A prompt the server refuses, an execution error in the history and a run past
its ceiling each raise ToolError with one line that names which of them happened. The ceiling ends the WAIT, not the prompt: the line keeps the prompt id and says the
prompt may still run (nothing is cancelled; the server finishes it and its history names the output), and that a retry queues a second one."""
import json
import os
import time
import urllib.error
import urllib.request
import uuid

CALL_TIMEOUT_S = 30
POLL_S = 1.0


class ToolError(Exception):
    """One line for the operator: what failed, in its own words."""


def api():
    return os.environ.get("COMFY_TOOLS_API", "http://127.0.0.1:8188").rstrip("/")


def _call(url, body=None):
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"} if data else {})
    try:
        with urllib.request.urlopen(request, timeout=CALL_TIMEOUT_S) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        try:
            return json.load(error)
        except ValueError:
            raise ToolError(f"PROMPT: HTTP {error.code} from {url}") from None


def _refusal(body):
    error = body.get("error") if isinstance(body, dict) else None
    text = error.get("message") if isinstance(error, dict) else error
    return f"PROMPT: refused: {text or body}"


def _failure(entry):
    status = entry.get("status") or {}
    for name, data in status.get("messages") or []:
        if name == "execution_error":
            return f"EXECUTION_ERROR: node {data.get('node_id')} ({data.get('node_type')}): {data.get('exception_message')}"
    if status.get("status_str") not in (None, "success"):
        return f"EXECUTION_ERROR: the history says {status.get('status_str')}"
    return None


def _files(entry):
    found = []
    for output in (entry.get("outputs") or {}).values():
        for value in output.values():
            if isinstance(value, list):
                found += [f for f in value if isinstance(f, dict) and "filename" in f]
    return found


def run(graph, ceiling_s, api_url=None):
    base = (api_url or api()).rstrip("/")
    body = _call(f"{base}/prompt", {"prompt": graph, "client_id": str(uuid.uuid4())})
    if not isinstance(body, dict) or "prompt_id" not in body:
        raise ToolError(_refusal(body))
    prompt_id = body["prompt_id"]
    start = time.monotonic()
    while time.monotonic() - start < ceiling_s:
        history = _call(f"{base}/history/{prompt_id}")
        if isinstance(history, dict) and prompt_id in history:
            entry = history[prompt_id]
            failure = _failure(entry)
            if failure:
                raise ToolError(failure)
            return time.monotonic() - start, _files(entry)
        time.sleep(POLL_S)
    raise ToolError(f"RUN_TIMEOUT: prompt {prompt_id} not finished after {ceiling_s} s; it may still run on the server: GET /history/{prompt_id} names its "
                    "output when it ends, and a retry queues a second prompt")
