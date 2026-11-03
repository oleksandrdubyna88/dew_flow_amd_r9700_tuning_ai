"""lib/prefixtest.py: the prefix-cache check, its twelve requests and its ratios (E3.S1, PT1-PT9). A local HTTP stub (the class of tests/test_harness.py) stands in for the server."""
import importlib.util
import socket
import subprocess
import sys

import pytest

from conftest import FIXTURES, LIB, catalogue_rows
from test_harness import StubServer

RAW = FIXTURES / "kernels" / "prefixtest.txt"
LINE_NAMES = ["A cold", "A hit", "A hit", "B cold", "B hit", "A partial"]


def load_module():
    spec = importlib.util.spec_from_file_location("prefixtest_under_test", LIB / "prefixtest.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run(args):
    done = subprocess.run([sys.executable, "-I", str(LIB / "prefixtest.py"), *map(str, args)], capture_output=True, text=True, timeout=120)
    return done.returncode, done.stdout, done.stderr


def prompts(stub):
    return [body["prompt"] for _path, body in stub.requests]


# ---- PT1: the twelve requests have the recorded shape, in order -------------------------------------------------------------------------------------

def test_the_twelve_requests_have_the_recorded_shape_in_order():
    with StubServer() as stub:
        code, out, err = run(["run", stub.url, "m", "t", "--seed", "1"])
    assert code == 0, err
    assert len(stub.requests) == 12
    assert {path for path, _body in stub.requests} == {"/v1/completions"}
    for _path, body in stub.requests:
        assert sorted(body) == ["max_tokens", "model", "prompt", "temperature"]
        assert (body["model"], body["max_tokens"], body["temperature"]) == ("m", 1, 0)
        assert all(isinstance(i, int) and 1000 <= i < 150000 for i in body["prompt"])
    p = prompts(stub)
    assert [len(x) for x in p] == [8192] * 6 + [1024] * 6
    for start in (0, 6):
        a, a2, a3, b, b2, partial = p[start:start + 6]
        assert a == a2 == a3 and b == b2 and a != b
        n = len(a)
        assert partial[:n - 64] == a[:n - 64] and partial[n - 64:] != a[n - 64:], "the partial prompt is A with its last 64 ids changed"


# ---- PT2: the output line is the recorded format ----------------------------------------------------------------------------------------------------

def test_the_printed_lines_are_the_recorded_format_and_the_lens_option_changes_the_lengths():
    module = load_module()
    with StubServer() as stub:
        code, out, err = run(["run", stub.url, "m", "tag-1", "--seed", "1"])
        assert code == 0, err
        lines = out.splitlines()
        assert len(lines) == 2
        parsed = [module.parse_line(line) for line in lines]
        assert [p["len"] for p in parsed] == [8192, 1024] and {p["tag"] for p in parsed} == {"tag-1"}
        for line in lines:
            assert line.startswith("tag-1 prefixtest len=") and all(f"{name}=" in line for name in set(LINE_NAMES)) and line.endswith("s")
        stub.requests.clear()
        code, out, err = run(["run", stub.url, "m", "t", "--lens", "512", "--tail", "32", "--seed", "1"])
        assert code == 0, err
        assert len(out.splitlines()) == 1 and "len=512 " in out
        assert [len(x) for x in prompts(stub)] == [512] * 6


# ---- PT3: seeds ------------------------------------------------------------------------------------------------------------------------------------------

def test_without_a_seed_the_prompts_differ_between_two_runs_and_with_one_they_are_equal():
    seen = []
    for seed in ([], [], ["--seed", "7"], ["--seed", "7"]):
        with StubServer() as stub:
            assert run(["run", stub.url, "m", "t", "--lens", "64", "--tail", "8", *seed])[0] == 0
            seen.append(prompts(stub))
    assert seen[0] != seen[1], "new prompts per run: no cache hit from an earlier run"
    assert seen[2] == seen[3]


# ---- PT4, PT5: a failure is one line and exit 1, nothing retried ----------------------------------------------------------------------------------------

def test_an_http_failure_is_one_line_and_exit_1_and_nothing_is_retried():
    with StubServer(fail_on=4) as stub:
        code, out, err = run(["run", stub.url, "m", "t", "--seed", "1"])
    assert code == 1 and out == ""
    assert err.splitlines() == ["prefix: B cold at len=8192: HTTP 500"]
    assert len(stub.requests) == 4


def test_a_timeout_is_the_same_one_line_and_one_request():
    with socket.socket() as silent:  # accepts connections (the backlog) and never answers
        silent.bind(("127.0.0.1", 0))
        silent.listen(5)
        code, out, err = run(["run", f"http://127.0.0.1:{silent.getsockname()[1]}", "m", "t", "--timeout", "0.3", "--seed", "1"])
    assert code == 1 and out == ""
    assert err.splitlines() == ["prefix: A cold at len=8192: timed out"]


def test_a_server_that_is_not_there_is_one_line_too():
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    code, out, err = run(["run", f"http://127.0.0.1:{port}", "m", "t", "--seed", "1"])
    assert code == 1 and err.startswith("prefix: A cold at len=8192: ") and len(err.splitlines()) == 1


# ---- PT6: summarize reproduces the ratios of the raw file -----------------------------------------------------------------------------------------------

def test_summarize_reproduces_the_ratios_of_the_raw_file():
    code, out, err = run(["summarize", RAW])
    assert code == 0, err
    lines = out.splitlines()
    assert len(lines) == 16
    assert lines[0] == "PREFIX fcombo-1 len=8192: cold 2.13 s, hit 0.50 s (4.3x), partial 0.49 s"
    assert lines[1] == "PREFIX fcombo-1 len=1024: cold 0.21 s, hit 0.21 s (1.0x), partial 0.19 s"
    fbase3 = [line for line in lines if line.startswith("PREFIX fbase-3 len=8192")]
    assert fbase3 == ["PREFIX fbase-3 len=8192: cold 1.98 s, hit 0.47 s (4.2x), partial 0.46 s"]
    print(out)


# ---- PT7: a line that is not the format is refused with its number --------------------------------------------------------------------------------------

def test_a_line_that_is_not_the_format_is_refused_with_its_number(tmp_path):
    lines = RAW.read_text().splitlines()
    lines[2] = lines[2].replace(" A partial=0.47s", "")
    bad = tmp_path / "bad.txt"
    bad.write_text("\n".join(lines) + "\n")
    code, out, err = run(["summarize", bad])
    assert code == 2 and out == ""
    assert err.splitlines() == ["prefix: line 3: not a prefixtest line"]


def test_an_empty_file_and_a_missing_file_are_refused(tmp_path):
    empty = tmp_path / "empty.txt"
    empty.write_text("")
    for path in (empty, tmp_path / "missing.txt"):
        code, out, err = run(["summarize", path])
        assert code == 2 and err.startswith("prefix: ") and len(err.splitlines()) == 1, err


# ---- PT8: the arithmetic is exact and the mean is a mean ------------------------------------------------------------------------------------------------

def line(cold_a, cold_b, hits, partial, tag="t", n=8192):
    a1, a2, b1 = hits
    return f"{tag} prefixtest len={n} A cold={cold_a}s A hit={a1}s A hit={a2}s B cold={cold_b}s B hit={b1}s A partial={partial}s"


def test_a_float_mean_would_print_2_12_where_the_decimal_mean_prints_2_13_and_that_is_the_point(tmp_path):
    assert f"{(2.1 + 2.15) / 2:.2f}" == "2.12", "the premise: the binary float mean of the two cold values ties and rounds to even"
    path = tmp_path / "one.txt"
    path.write_text(line("2.1", "2.15", ("0.5", "0.5", "0.5"), "0.5") + "\n")
    code, out, err = run(["summarize", path])
    assert code == 0, err
    assert "cold 2.13 s" in out


def test_the_cold_mean_is_the_mean_of_the_two_cold_values_not_the_first(tmp_path):
    path = tmp_path / "one.txt"
    path.write_text(line("2.0", "3.0", ("0.5", "0.5", "0.5"), "0.5") + "\n")
    code, out, err = run(["summarize", path])
    assert code == 0, err
    assert out.splitlines() == ["PREFIX t len=8192: cold 2.50 s, hit 0.50 s (5.0x), partial 0.50 s"]


def test_a_zero_hit_time_has_no_ratio_instead_of_a_division_by_zero(tmp_path):
    path = tmp_path / "zero.txt"
    path.write_text(line("1.0", "1.0", ("0.0", "0.0", "0.0"), "0.5") + "\n")
    code, out, err = run(["summarize", path])
    assert code == 0, err
    assert "(n/a)" in out


# ---- run: its arguments ----------------------------------------------------------------------------------------------------------------------------------

@pytest.mark.parametrize("args, message", [
    (["--lens", "8192 8192"], "repeats a value"),
    (["--lens", "x"], "--lens"),
    (["--tail", "0"], "--tail"),
    (["--tail", "1024", "--lens", "1024"], "--tail 1024 is not below the shortest length 1024"),
    (["--timeout", "0"], "--timeout"),
])
def test_run_refuses_its_arguments_before_any_request(args, message):
    with StubServer() as stub:
        code, out, err = run(["run", stub.url, "m", "t", *args])
    assert code == 2 and message in err and err.startswith("prefix: ") and len(err.splitlines()) == 1, err
    assert stub.requests == []


# ---- check: exactly one line per requested length ------------------------------------------------------------------------------------------------------

LINE_8K = "t prefixtest len=8192 A cold=2.0s A hit=0.5s A hit=0.5s B cold=2.0s B hit=0.5s A partial=0.5s"
LINE_1K = LINE_8K.replace("8192", "1024")


def check(tmp_path, lines, lens="8192 1024", tag="t"):
    path = tmp_path / "p.txt"
    path.write_text("\n".join(lines) + "\n")
    return run(["check", path, "--lens", lens, "--tag", tag])


def test_check_accepts_exactly_one_line_per_requested_length_in_any_order(tmp_path):
    assert check(tmp_path, [LINE_8K, LINE_1K])[0] == 0
    assert check(tmp_path, [LINE_1K, LINE_8K])[0] == 0


def test_check_names_a_missing_a_duplicate_and_an_unexpected_length(tmp_path):
    code, out, err = check(tmp_path, [LINE_8K])
    assert code == 2 and err.splitlines() == ["prefix: missing len=1024"]
    code, out, err = check(tmp_path, [LINE_8K, LINE_8K])
    assert code == 2 and "duplicate len=8192" in err and "missing len=1024" in err and len(err.splitlines()) == 1, "two lines, as many as asked, and still refused"
    code, out, err = check(tmp_path, [LINE_8K, LINE_1K, LINE_8K.replace("8192", "512")])
    assert code == 2 and err.splitlines() == ["prefix: unexpected len=512"]


def test_check_refuses_a_line_that_is_not_the_format_a_wrong_tag_and_an_empty_file(tmp_path):
    code, out, err = check(tmp_path, [LINE_8K, "stub noise"])
    assert code == 2 and err.splitlines() == ["prefix: line 2: not a prefixtest line"]
    code, out, err = check(tmp_path, [LINE_8K, LINE_1K], tag="other")
    assert code == 2 and "line 1: the tag is t, not other" in err
    code, out, err = check(tmp_path, [])
    assert code == 2 and err.startswith("prefix: ")


# ---- PT9: the commands are catalogued --------------------------------------------------------------------------------------------------------------------

def test_every_command_has_a_covered_row_in_the_flow_catalogue():
    rows = catalogue_rows("lib/prefixtest.py", load_module().build_parser())
    assert sorted(rows) == ["check", "run", "summarize"]
    for command, found in rows.items():
        assert found, f"lib/prefixtest.py {command} has no row in research/module_tests.md"
        assert all("covered" in row for row in found), command
