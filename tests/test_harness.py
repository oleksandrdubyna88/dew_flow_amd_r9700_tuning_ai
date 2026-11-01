"""lib/harness.py: the quality harness (scenarios 35-40). An HTTP stub on 127.0.0.1 stands in for the vLLM server."""
import importlib.util
import json
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest

from conftest import FIXTURES, LIB

PROMPT_FILES = FIXTURES / "prompts"


def load_harness():
    spec = importlib.util.spec_from_file_location("harness_under_test", LIB / "harness.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run(args):
    done = subprocess.run([sys.executable, "-I", str(LIB / "harness.py"), *map(str, args)],
                          capture_output=True, text=True, timeout=120)
    return done.returncode, done.stdout, done.stderr


class StubServer:
    """Answers /v1/completions and /v1/chat/completions; records every request body."""

    def __init__(self, fail_on=None, chat_text="... #### 5"):
        self.requests = []
        self.fail_on = fail_on
        stub = self

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                stub.requests.append((self.path, body))
                if stub.fail_on == len(stub.requests):
                    self.reply(500, {"error": "boom"})
                elif self.path == "/v1/completions":
                    self.reply(200, {"choices": [{"text": "x", "finish_reason": "length", "logprobs": {
                        "tokens": ["token_id:1", "token_id:2"],
                        "top_logprobs": [{"token_id:1": -0.1, "token_id:9": -2.0}, {"token_id:2": -0.2, "token_id:8": -3.0}],
                        "token_logprobs": [-0.1, -0.2]}}]})
                else:
                    self.reply(200, {"choices": [{"message": {"content": chat_text}, "finish_reason": "stop"}]})

            def reply(self, status, payload):
                data = json.dumps(payload).encode()
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)

            def log_message(self, *args):
                pass

        self.httpd = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.url = f"http://127.0.0.1:{self.httpd.server_address[1]}"
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)

    def __enter__(self):
        self.thread.start()
        return self

    def __exit__(self, *exc):
        self.httpd.shutdown()
        self.httpd.server_close()
        self.thread.join(timeout=10)


# ---- scenario 35: the original self-test cases, one test each --------------------------------------------------

def test_parse_token_id_reads_the_number_of_token_id_form():
    assert load_harness().parse_token_id("token_id:42") == 42


@pytest.mark.parametrize("bad", ["42", "token_id:x", "tok", None])
def test_parse_token_id_refuses_anything_not_in_token_id_form(bad):
    with pytest.raises(ValueError):
        load_harness().parse_token_id(bad)


def test_parse_top_sorts_by_logprob_descending():
    assert load_harness().parse_top({"token_id:5": -2.0, "token_id:7": -0.1}) == [[7, -0.1], [5, -2.0]]


def item(ids, tops, fin="length"):
    return {"token_ids": ids, "top": tops, "finish_reason": fin}


TOPS = [[[1, -0.1], [2, -3.0]], [[10, -0.50], [11, -0.60]], [[20, -0.1], [21, -2.0]]]
REFERENCE = item([1, 10, 20], TOPS)


def test_compare_item_calls_the_same_tokens_identical():
    assert load_harness().compare_item(REFERENCE, item([1, 10, 20], TOPS), 0.5)["identical"]


def test_compare_item_calls_a_swap_inside_the_top_two_within_the_gap_a_near_tie():
    result = load_harness().compare_item(REFERENCE, item([1, 11, 99], TOPS), 0.5)
    assert result["k"] == 1 and result["near_tie"] is True and result["kind"] == "token"


def test_compare_item_refuses_a_near_tie_when_the_gap_is_too_large():
    assert load_harness().compare_item(REFERENCE, item([1, 11, 99], TOPS), 0.05)["near_tie"] is False


def test_compare_item_refuses_a_near_tie_when_the_top_two_are_1_9_apart():
    assert load_harness().compare_item(REFERENCE, item([1, 10, 21], TOPS), 0.5)["near_tie"] is False


def test_compare_item_refuses_a_near_tie_when_the_candidate_token_is_not_in_the_top_two():
    assert load_harness().compare_item(REFERENCE, item([1, 77, 99], TOPS), 0.5)["near_tie"] is False


def test_compare_item_reports_a_length_mismatch_with_its_finish_reasons():
    result = load_harness().compare_item(REFERENCE, item([1, 10], TOPS[:2], "stop"), 0.5)
    assert result["kind"] == "length" and result["k"] == 2 and result["near_tie"] is False and result["b_finish"] == "stop"


@pytest.mark.parametrize("text, expected", [
    ("blah\n#### 1,234", "1234"),
    ("The answer is $5.00.", "5"),
    ("#### 3.5", "3.5"),
    ("12 apples, then #### 7 and 9", "7"),
    ("no digits", ""),
])
def test_extract_number_reads_the_answer_after_the_last_marker_else_the_last_number(text, expected):
    assert load_harness().extract_number(text) == expected


def test_the_selftest_flag_still_runs_and_says_so():
    code, out, err = run(["--selftest"])
    assert code == 0, err
    assert out.strip() == "selftest OK"


def test_the_twenty_greedy_prompts_are_kept_exactly():
    harness = load_harness()
    assert len(harness.PROMPTS) == 20 and harness.PROMPTS[0] == "Q: What is the capital of France?\nA:"
    assert harness.GSM_SUFFIX == "\n\nSolve step by step, then give the final answer on the last line as: #### <number>"


# ---- scenarios 36-37: compare reproduces the recorded results --------------------------------------------------

def test_compare_of_fbase_and_fb1_is_twenty_identical():
    code, out, _ = run(["compare", PROMPT_FILES / "prompts_fbase.json", PROMPT_FILES / "prompts_fb1.json"])
    assert code == 0
    assert out.splitlines()[-1] == "20 identical of 20; divergences all near-tie: yes"


def test_compare_of_fbase_and_fcombo_is_twelve_identical_and_not_all_near_tie():
    code, out, _ = run(["compare", PROMPT_FILES / "prompts_fbase.json", PROMPT_FILES / "prompts_fcombo.json"])
    assert code == 1
    assert out.splitlines()[-1] == "12 identical of 20; divergences all near-tie: no"


def test_gsm8k_compare_reproduces_the_recorded_quality_check():
    quality = FIXTURES / "ship_test" / "quality"
    code, out, _ = run(["gsm8k-compare", quality / "gsm8k_fbase.json", quality / "gsm8k_fcombo.json"])
    assert code == 0
    assert out.strip() == "accuracy A=0.8550 B=0.8450 delta=-0.0100 limit=2*max(stderr)=0.0512 pass=yes"


# ---- scenarios 38-39: collect ----------------------------------------------------------------------------------

def test_collect_writes_twenty_results_from_a_server(tmp_path):
    out_file = tmp_path / "p.json"
    with StubServer() as server:
        code, _, err = run(["collect", "--url", server.url, "--model", "m", "--out", out_file])
    assert code == 0, err
    results = json.loads(out_file.read_text())["results"]
    assert len(results) == 20 and all(r["token_ids"] == [1, 2] for r in results)
    assert len(server.requests) == 20
    for path, body in server.requests:
        assert path == "/v1/completions"
        assert (body["temperature"], body["logprobs"], body["return_tokens_as_token_ids"]) == (0, 2, True)


def test_a_failing_server_leaves_no_result_file(tmp_path):
    out_file = tmp_path / "p.json"
    with StubServer(fail_on=3) as server:
        code, _, err = run(["collect", "--url", server.url, "--model", "m", "--out", out_file])
    assert code != 0
    assert "HTTP 500" in err
    assert not out_file.exists() and not (tmp_path / "p.json.part").exists()


# ---- scenario 40: gsm8k ----------------------------------------------------------------------------------------

def test_gsm8k_scores_from_a_server(tmp_path):
    data = tmp_path / "test.jsonl"
    data.write_text("".join(json.dumps({"question": f"q{i}", "answer": f"work\n#### {gold}"}) + "\n"
                            for i, gold in enumerate((5, 5, 7))))
    out_file = tmp_path / "g.json"
    with StubServer() as server:
        code, _, err = run(["gsm8k", "--url", server.url, "--model", "m", "--data", data, "--n", "3",
                            "--concurrency", "1", "--out", out_file])
    assert code == 0, err
    summary = json.loads(out_file.read_text())["summary"]
    assert (summary["correct"], summary["n"]) == (2, 3)
    assert len(server.requests) == 3
    for path, body in server.requests:
        assert path == "/v1/chat/completions"
        assert body["temperature"] == 0 and body["chat_template_kwargs"] == {"enable_thinking": False}


# ---- the one change to the measured script: an atomic result write ---------------------------------------------

def test_save_json_writes_beside_the_file_and_moves_it_over(tmp_path):
    target = tmp_path / "r.json"
    load_harness().save_json(str(target), {"a": 1})
    assert json.loads(target.read_text()) == {"a": 1}
    assert not (tmp_path / "r.json.part").exists()


def test_save_json_that_fails_keeps_the_old_file_and_leaves_no_part(tmp_path):
    target = tmp_path / "r.json"
    target.write_text('{"old": true}')
    with pytest.raises(TypeError):
        load_harness().save_json(str(target), {"not json": {1, 2}})
    assert json.loads(target.read_text()) == {"old": True}
    assert not (tmp_path / "r.json.part").exists()


# ---- the flow catalogue is derived from the parser, not typed --------------------------------------------------

def test_every_harness_command_has_one_covered_row_in_the_flow_catalogue():
    from conftest import catalogue_rows
    rows = catalogue_rows("lib/harness.py", load_harness().build_parser())
    assert len(rows) >= 4, "the scan found the commands of the parser"
    for command, found in rows.items():
        assert len(found) == 1 and "| covered |" in found[0], f"lib/harness.py {command} needs one `covered` row in research/module_tests.md"
