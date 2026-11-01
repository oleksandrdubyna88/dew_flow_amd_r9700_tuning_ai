"""Shared test paths. Tests write only below pytest's `tmp_path`, which tests/run.mjs puts inside its owned run folder."""
import argparse
import sys
from pathlib import Path

import pytest

sys.dont_write_bytecode = True  # a test run must not leave __pycache__ beside lib/

TESTS = Path(__file__).parent
ROOT = TESTS.parent
FIXTURES = TESTS / "fixtures"
LIB = ROOT / "lib"


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
