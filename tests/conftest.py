"""Shared test paths and the scripted ComfyUI server fixture. Tests write only below pytest's `tmp_path`, which tests/run.mjs puts inside its owned run folder."""
import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

import pytest

sys.dont_write_bytecode = True  # a test run must not leave __pycache__ beside lib/

TESTS = Path(__file__).parent
ROOT = TESTS.parent
FIXTURES = TESTS / "fixtures"
LIB = ROOT / "lib"
COMFY_SERVER = FIXTURES / "comfy" / "comfy_server.py"


def own_ticks(pid):
    return open(f"/proc/{pid}/stat").read().rsplit(") ", 1)[1].split()[19]


@pytest.fixture
def server(tmp_path):
    """The scripted ComfyUI stand-in (tests/fixtures/comfy/comfy_server.py) of tests/test_comfy_bench_py.py and tests/test_comfy_tools.py:
    start(script) -> (port, folder the server writes into). Its pid is recorded below `containers/`, where tests/run.mjs finds and kills what a test left;
    every server is killed at the end of the test."""
    started = []

    def start(script):
        n = len(started) + 1
        script_file, port_file, out = tmp_path / f"script{n}.json", tmp_path / f"port{n}", tmp_path / f"out{n}"
        script_file.write_text(json.dumps(script))
        proc = subprocess.Popen([sys.executable, "-I", str(COMFY_SERVER), "--script", str(script_file), "--out", str(out), "--port-file", str(port_file)],
                                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        started.append(proc)
        (tmp_path / "containers").mkdir(exist_ok=True)
        (tmp_path / "containers" / f"fixture-{n}.pid").write_text(f"{proc.pid} {own_ticks(proc.pid)}\n")
        for _ in range(100):
            if port_file.exists():
                return int(port_file.read_text()), out
            if proc.poll() is not None:
                pytest.fail(f"the fixture server ended: {proc.stderr.read()}")
            time.sleep(0.1)
        pytest.fail("the fixture server never wrote its port")

    yield start
    for proc in started:
        proc.kill()
        proc.wait()
        proc.stderr.close()


def pytest_configure(config):
    """Every test writes inside the run folder `tests/run.mjs` owns; pytest's own default base folder would leave one behind."""
    if config.option.basetemp is None:
        raise pytest.UsageError("run the Python tests through `node tests/run.mjs [file]`: it gives pytest an owned --basetemp (common/test-leftovers.md)")


def catalogue_rows(program, parser):
    """{command: the rows of the flow catalogue in research/module_tests.md that name it}, for every command of a program's own argparse parser.

    The command list is read from the parser, never typed: a command added without a `covered` row makes the caller fail."""
    action = next(a for a in parser._actions if isinstance(a, argparse._SubParsersAction))
    doc = (ROOT / "research" / "module_tests.md").read_text().splitlines()
    return {cmd: [row for row in doc if row.startswith(f"| `{program} {cmd}`")] for cmd in action.choices}
