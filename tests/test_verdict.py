"""lib/verdict.py: the ship test, reproduced from the recorded 2026-10-31 bench lines (scenarios 19-34)."""
import importlib.util
import json
import math
import re
import statistics
import subprocess
import sys
from decimal import Decimal

import pytest

from conftest import FIXTURES, LIB

AB = FIXTURES / "ship_test" / "bench_final_ab.txt"
O7 = FIXTURES / "ship_test" / "bench_option7.txt"
Q = FIXTURES / "ship_test" / "quality"
LENS = "8192 32768"
OUTPUT_LINE = re.compile(r"^(?P<tag>\S+) c=(?P<c>[14]) r=[1-9] Output token throughput \(tok/s\):\s+(?P<v>[0-9.]+)\s*$")


def run(args):
    """Call lib/verdict.py as a subprocess; returns (exit code, stdout, stderr)."""
    done = subprocess.run([sys.executable, "-I", str(LIB / "verdict.py"), *map(str, args)],
                          capture_output=True, text=True, timeout=120)
    return done.returncode, done.stdout, done.stderr


def ship(base, arms, bench, *extra, lens=LENS):
    args = ["ship", "--base", base]
    for arm in arms:
        args += ["--arm", arm]
    for path in (bench if isinstance(bench, (list, tuple)) else [bench]):
        args += ["--bench", path]
    return run([*args, "--prefill-lens", lens, *extra])


def load_module():
    spec = importlib.util.spec_from_file_location("verdict_under_test", LIB / "verdict.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# ---- synthetic bench files -------------------------------------------------------------------------------------

def block_lines(tag, c1, c4, lens=(8192, 32768)):
    """One complete 36-line block. c1 and c4 hold the three throughput values (r=1..3); every other metric is constant."""
    lines = []
    for conc, values in (("1", c1), ("4", c4)):
        for r, value in enumerate(values, 1):
            lines += [f"{tag} c={conc} r={r} Output token throughput (tok/s):         {value}     ",
                      f"{tag} c={conc} r={r} Mean TTFT (ms):                          100.00   ",
                      f"{tag} c={conc} r={r} Mean TPOT (ms):                          10.00    "]
    for length in lens:
        for r in (1, 2, 3):
            lines += [f"{tag} prefill{length} r={r} Output token throughput (tok/s):         5.00",
                      f"{tag} prefill{length} r={r} Mean TTFT (ms):                          1000.00",
                      f"{tag} prefill{length} r={r} Median TTFT (ms):                        900.00"]
    return lines


def write_bench(path, arms):
    """arms: {arm: (nine c=1 values, nine c=4 values)}; round i takes values 3(i-1)..3i of each list."""
    lines = []
    for rnd in (1, 2, 3):
        for arm, (c1, c4) in arms.items():
            lo, hi = 3 * (rnd - 1), 3 * rnd
            lines += block_lines(f"{arm}-{rnd}", c1[lo:hi], c4[lo:hi])
    path.write_text("\n".join(lines) + "\n")
    return path


def verdict_line(stdout, arm):
    return next(line for line in stdout.splitlines() if line.startswith(f"verdict {arm}:"))


# ---- scenarios 19-21: the three recorded verdicts --------------------------------------------------------------

def test_fcombo_passes_as_recorded():
    code, out, err = ship("fbase", ["fcombo"], AB, "--gsm8k-dir", Q)
    lines = out.splitlines()
    assert code == 0, err
    assert "  c=1 output tok/s: median 84.47 vs 76.08, delta +8.39, base spread 9.84 -> within, not lower" in lines
    assert "  c=4 output tok/s: median 202.44 vs 178.39, delta +24.05, base spread 10.90 -> higher" in lines
    assert "  gsm8k accuracy: 0.8450 vs 0.8550, delta -0.0100, limit 0.0512 -> pass" in lines
    assert "verdict fcombo: PASS" in lines


def test_fb1_fails_as_recorded():
    code, out, err = ship("fbase", ["fb1"], AB, "--gsm8k-dir", Q)
    lines = out.splitlines()
    assert code == 0, err
    assert "  c=1 output tok/s: median 77.33 vs 76.08, delta +1.25, base spread 9.84 -> within, not lower" in lines
    assert "  c=4 output tok/s: median 181.00 vs 178.39, delta +2.61, base spread 10.90 -> within, not lower" in lines
    assert "  gsm8k accuracy: 0.8550 vs 0.8550, delta +0.0000, limit 0.0498 -> pass" in lines
    assert "verdict fb1: FAIL (no decode median is higher than the base spread)" in lines


def test_o7_fails_as_recorded():
    code, out, err = ship("o7ref", ["o7"], O7, "--gsm8k-dir", Q)
    lines = out.splitlines()
    assert code == 0, err
    assert "  c=1 output tok/s: median 85.64 vs 85.66, delta -0.02, base spread 3.51 -> within, lower" in lines
    assert "  c=4 output tok/s: median 202.40 vs 203.39, delta -0.99, base spread 7.86 -> within, lower" in lines
    assert "verdict o7: FAIL (no decode median is higher than the base spread)" in lines


# ---- scenarios 22-24: complete blocks only ---------------------------------------------------------------------

def test_incomplete_blocks_are_ignored_and_named():
    code, out, err = ship("fbase", ["fcombo"], AB, "--gsm8k-dir", Q)
    lines = out.splitlines()
    assert code == 0, err
    assert "ignored incomplete block: fcombo-2, 30 lines from bench_final_ab.txt:145" in lines
    assert "ignored incomplete block: fb1-2, 3 lines from bench_final_ab.txt:211" in lines
    header = next(line for line in lines if line.startswith("arm fcombo"))
    assert "3 rounds, 9 values per concurrency" in header


def test_counting_every_line_would_give_fcombo_83_56_from_12_values_and_that_is_the_point():
    naive = [Decimal(m["v"]) for m in map(OUTPUT_LINE.match, AB.read_text().splitlines())
             if m and m["tag"].startswith("fcombo-") and m["c"] == "1"]
    assert len(naive) == 12
    assert f"{statistics.median(naive):.2f}" == "83.56"
    _, out, _ = ship("fbase", ["fcombo"], AB, "--gsm8k-dir", Q)
    assert "median 84.47 vs 76.08" in out and "median 83.56" not in out
    assert "3 rounds, 9 values per concurrency" in out


def test_spread_over_round_medians_would_be_1_36_and_is_not_used():
    per_round = {}
    for match in map(OUTPUT_LINE.match, AB.read_text().splitlines()):
        if match and match["tag"].startswith("fbase-") and match["c"] == "1":
            per_round.setdefault(match["tag"], []).append(Decimal(match["v"]))
    medians = [statistics.median(values) for values in per_round.values()]
    assert len(medians) == 3 and f"{max(medians) - min(medians):.2f}" == "1.36"
    _, out, _ = ship("fbase", ["fcombo"], AB, "--gsm8k-dir", Q)
    assert "base spread 9.84" in out and "base spread 1.36" not in out


# ---- scenarios 25-26: exact decimals, the two speed rules ------------------------------------------------------

BASE_C4 = ["50.00", "50.05", "50.10", "50.11", "50.12", "50.20", "50.30", "50.40", "60.90"]


def decide(tmp_path, base_c1, base_c4, arm_c1, arm_c4):
    bench = write_bench(tmp_path / "synthetic.txt", {"b": (base_c1, base_c4), "a": (arm_c1, arm_c4)})
    return ship("b", ["a"], bench, "--no-quality")


def test_an_arm_exactly_one_spread_above_the_base_is_within_not_higher(tmp_path):
    code, out, err = decide(tmp_path, ["40.00"] * 9, BASE_C4, ["40.00"] * 9, ["61.02"] * 9)
    assert code == 0, err
    assert "  c=4 output tok/s: median 61.02 vs 50.12, delta +10.90, base spread 10.90 -> within, not lower" in out.splitlines()
    assert verdict_line(out, "a") == "verdict a: FAIL (no decode median is higher than the base spread)"


def test_an_arm_one_hundredth_above_one_spread_is_higher(tmp_path):
    code, out, err = decide(tmp_path, ["40.00"] * 9, BASE_C4, ["40.00"] * 9, ["61.03"] * 9)
    assert code == 0, err
    assert "  c=4 output tok/s: median 61.03 vs 50.12, delta +10.91, base spread 10.90 -> higher" in out.splitlines()
    assert verdict_line(out, "a").startswith("verdict a: PASS")


def test_float_arithmetic_would_call_the_exact_spread_higher_and_that_is_the_point():
    assert 61.02 - 50.12 > 60.90 - 50.00      # binary floating point says "higher" for the exact-equal case
    assert Decimal("61.02") - Decimal("50.12") == Decimal("60.90") - Decimal("50.00")


def test_rule_2_lower_than_the_base_spread_at_the_other_concurrency_fails(tmp_path):
    base_c1 = ["40.00"] * 8 + ["50.00"]                      # median 40.00, spread 10.00
    base_c4 = ["50.00"] * 8 + ["60.00"]                      # median 50.00, spread 10.00
    code, out, err = decide(tmp_path, base_c1, base_c4, ["29.99"] * 9, ["70.00"] * 9)
    assert code == 0, err
    assert "  c=1 output tok/s: median 29.99 vs 40.00, delta -10.01, base spread 10.00 -> lower" in out.splitlines()
    assert "  c=4 output tok/s: median 70.00 vs 50.00, delta +20.00, base spread 10.00 -> higher" in out.splitlines()
    assert verdict_line(out, "a") == "verdict a: FAIL (c=1 is lower by more than the base spread)"


def test_rule_2_lower_by_exactly_the_spread_passes(tmp_path):
    base_c1 = ["40.00"] * 8 + ["50.00"]
    base_c4 = ["50.00"] * 8 + ["60.00"]
    code, out, err = decide(tmp_path, base_c1, base_c4, ["30.00"] * 9, ["70.00"] * 9)
    assert code == 0, err
    assert "  c=1 output tok/s: median 30.00 vs 40.00, delta -10.00, base spread 10.00 -> within, lower" in out.splitlines()
    assert verdict_line(out, "a").startswith("verdict a: PASS")


# ---- scenarios 27-28, 31: quality and completeness -------------------------------------------------------------

def test_quality_outside_two_stderr_fails_even_when_speed_passes(tmp_path):
    (tmp_path / "gsm8k_fbase.json").write_bytes((Q / "gsm8k_fbase.json").read_bytes())
    (tmp_path / "gsm8k_fcombo.json").write_text(json.dumps(
        {"summary": {"n": 200, "correct": 150, "accuracy": 0.75, "stderr": 0.030619}}))
    code, out, err = ship("fbase", ["fcombo"], AB, "--gsm8k-dir", tmp_path)
    assert code == 0, err
    assert "  gsm8k accuracy: 0.7500 vs 0.8550, delta -0.1050, limit 0.0612 -> fail" in out.splitlines()
    assert "  c=4 output tok/s: median 202.44 vs 178.39, delta +24.05, base spread 10.90 -> higher" in out.splitlines()
    assert verdict_line(out, "fcombo") == "verdict fcombo: FAIL (gsm8k)"


def test_a_missing_round_makes_the_arm_incomplete_not_a_verdict(tmp_path):
    kept = [line for line in O7.read_text().splitlines() if not line.startswith("o7-3 ")]
    bench = tmp_path / "o7_two_rounds.txt"
    bench.write_text("\n".join(kept) + "\n")
    code, out, err = ship("o7ref", ["o7"], bench, "--rounds", "3", "--gsm8k-dir", Q)
    assert code == 1, err
    assert "verdict o7: INCOMPLETE (missing complete arm-rounds: o7-3)" in out.splitlines()
    assert "verdict o7: PASS" not in out and "verdict o7: FAIL" not in out


def test_missing_quality_is_incomplete_and_skipping_it_is_said(tmp_path):
    (tmp_path / "gsm8k_fbase.json").write_bytes((Q / "gsm8k_fbase.json").read_bytes())
    code, out, _ = ship("fbase", ["fcombo"], AB, "--gsm8k-dir", tmp_path)
    assert code == 1
    assert "verdict fcombo: INCOMPLETE (no gsm8k_fcombo.json)" in out.splitlines()
    code, out, err = ship("fbase", ["fcombo"], AB, "--no-quality")
    assert code == 0, err
    assert "verdict fcombo: PASS (quality NOT checked)" in out.splitlines()


# ---- scenarios 29-30: input errors -----------------------------------------------------------------------------

def test_a_base_without_complete_rounds_is_an_input_error():
    code, _, err = ship("nosuch", ["fcombo"], AB, "--no-quality")
    assert code == 2
    assert 'base arm "nosuch" has no complete arm-round in the inputs' in err


def test_a_line_that_is_not_a_bench_line_is_refused_with_its_place(tmp_path):
    bench = tmp_path / "bench_final_ab.txt"
    bench.write_text(AB.read_text() + "garbage\n")
    code, _, err = ship("fbase", ["fcombo"], bench, "--no-quality")
    assert code == 2
    assert "bench_final_ab.txt:358: not a bench line" in err


# ---- scenarios 32-33: prefill is information; --json is the same numbers, atomically ---------------------------

def test_prefill_is_reported_not_judged():
    _, out, _ = ship("fbase", ["fcombo"], AB, "--gsm8k-dir", Q)
    lines = out.splitlines()
    assert ("  prefill32768 median TTFT ms: median 15586.41 vs 16164.65, delta -578.24, "
            "base spread 909.60 (information)") in lines
    assert "verdict fcombo: PASS" in lines


def test_json_writes_the_same_numbers_atomically(tmp_path):
    target = tmp_path / "v.json"
    code, _, err = ship("fbase", ["fcombo"], AB, "--gsm8k-dir", Q, "--json", target)
    assert code == 0, err
    entry = next(item for item in json.loads(target.read_text()) if item["arm"] == "fcombo")
    assert (entry["c4"]["delta"], entry["c4"]["spread"], entry["c4"]["n"], entry["verdict"]) == ("24.05", "10.90", 9, "PASS")
    assert entry["base"] == "fbase" and entry["rounds"] == 3 and entry["reason"] is None
    assert set(entry["prefill"]) == {"8192", "32768"} and entry["gsm8k"]["pass"] is True
    assert not (tmp_path / "v.json.part").exists()


def test_json_write_failure_leaves_no_partial_file(tmp_path):
    target = tmp_path / "out.json"
    target.mkdir()
    code, _, err = ship("fbase", ["fcombo"], AB, "--no-quality", "--json", target)
    assert code == 2 and err.strip()
    assert not (tmp_path / "out.json.part").exists()


def test_json_has_null_quality_when_it_was_not_checked(tmp_path):
    target = tmp_path / "v.json"
    code, _, err = ship("fbase", ["fcombo"], AB, "--no-quality", "--json", target)
    assert code == 0, err
    assert json.loads(target.read_text())[0]["gsm8k"] is None


# ---- scenario 34: check-block ----------------------------------------------------------------------------------

def ab_lines(first, last):
    return AB.read_text().splitlines()[first - 1:last]


def check_block(tmp_path, lines, tag="fcombo-2"):
    path = tmp_path / "block.txt"
    path.write_text("\n".join(lines) + "\n")
    return run(["check-block", "--tag", tag, "--prefill-lens", LENS, path])


def test_check_block_accepts_exactly_one_complete_block(tmp_path):
    code, out, err = check_block(tmp_path, ab_lines(175, 210))
    assert code == 0, (out, err)


def test_check_block_lists_the_missing_keys_in_canonical_order(tmp_path):
    code, out, _ = check_block(tmp_path, ab_lines(145, 174))
    assert code == 1
    missing = [line for line in out.splitlines() if line.startswith("missing: ")]
    assert missing[0] == "missing: prefill32768 r=2 Output token throughput (tok/s)"
    assert len(missing) == 6


def test_check_block_names_a_duplicated_key(tmp_path):
    lines = ab_lines(175, 210)
    code, out, _ = check_block(tmp_path, [lines[0], *lines])
    assert code == 1
    assert "expected 36 lines, found 37 (duplicate: c=1 r=1 Output token throughput (tok/s))" in out


def test_check_block_counts_a_short_block(tmp_path):
    code, out, _ = check_block(tmp_path, ab_lines(211, 213), tag="fb1-2")
    assert code == 1
    assert "expected 36 lines, found 3" in out


def test_check_block_refuses_a_line_of_another_tag(tmp_path):
    code, _, err = check_block(tmp_path, ab_lines(175, 210), tag="fcombo-3")
    assert code == 2
    assert "block.txt:1:" in err and "fcombo-3" in err


# ---- the block rules the brief states --------------------------------------------------------------------------

def test_expected_keys_are_the_36_of_a_complete_block_in_canonical_order():
    keys = load_module().expected_keys([8192, 32768])
    assert len(keys) == 36 and len(set(keys)) == 36
    assert keys[0] == "c=1 r=1 Output token throughput (tok/s)"
    assert keys[9] == "c=4 r=1 Output token throughput (tok/s)"
    assert keys[18] == "prefill8192 r=1 Output token throughput (tok/s)"
    assert keys[-1] == "prefill32768 r=3 Median TTFT (ms)"
    assert len(load_module().expected_keys([8192])) == 27


def test_a_later_complete_block_replaces_an_earlier_one_and_is_named(tmp_path):
    bench = tmp_path / "twice.txt"
    first, second = block_lines("a-1", ["1.00"] * 3, ["2.00"] * 3), block_lines("a-1", ["3.00"] * 3, ["4.00"] * 3)
    bench.write_text("\n".join(first + second) + "\n")
    other = write_bench(tmp_path / "base.txt", {"b": (["1.00"] * 9, ["2.00"] * 9)})
    code, out, err = ship("b", ["a"], [bench, other], "--no-quality", "--rounds", "1")
    assert code == 0, err
    assert "superseded complete block: a-1, 36 lines from twice.txt:1" in out.splitlines()
    assert "median 3.00 vs 1.00" in out


def test_blocks_are_read_across_several_bench_files_in_the_order_given(tmp_path):
    ref, new = tmp_path / "ref.txt", tmp_path / "new.txt"
    ref.write_text("\n".join(line for line in O7.read_text().splitlines() if line.startswith("o7ref-")) + "\n")
    new.write_text("\n".join(line for line in O7.read_text().splitlines() if line.startswith("o7-")) + "\n")
    code, out, err = ship("o7ref", ["o7"], [ref, new], "--gsm8k-dir", Q)
    assert code == 0, err
    assert "verdict o7: FAIL (no decode median is higher than the base spread)" in out.splitlines()


# ---- the flow catalogue is derived from the parser, not typed --------------------------------------------------

def test_every_verdict_command_has_one_covered_row_in_the_flow_catalogue():
    from conftest import catalogue_rows
    rows = catalogue_rows("lib/verdict.py", load_module().build_parser())
    assert len(rows) >= 2, "the scan found the commands of the parser"
    for command, found in rows.items():
        assert len(found) == 1 and "| covered |" in found[0], f"lib/verdict.py {command} needs one `covered` row in research/module_tests.md"


# ---- review round: unexpected input must exit 2 (never 1, which means INCOMPLETE) -------------------------------

def test_a_bench_file_with_a_non_utf8_byte_is_an_input_error(tmp_path):
    bench = tmp_path / "bench.txt"
    bench.write_bytes(AB.read_bytes() + b"fbase-9 c=1 r=1 caf\xff\n")
    code, _, err = ship("fbase", ["fcombo"], bench, "--no-quality")
    assert code == 2 and "bench.txt" in err and "Traceback" not in err


def test_check_block_on_a_non_utf8_file_is_an_input_error(tmp_path):
    bench = tmp_path / "block.txt"
    bench.write_bytes(b"fcombo-2 \xff\xfe\n")
    code, _, err = run(["check-block", "--tag", "fcombo-2", "--prefill-lens", LENS, bench])
    assert code == 2 and "block.txt" in err and "Traceback" not in err


def stderr_of(accuracy, n):
    """The binomial standard error sqrt(p(1-p)/n), rounded to six places the way a hand-written file would carry it."""
    return round(math.sqrt(accuracy * (1 - accuracy) / n), 6)


def write_summary(directory, name, accuracy, stderr, n=200):
    (directory / f"gsm8k_{name}.json").write_text(json.dumps({"summary": {"n": n, "correct": 0, "accuracy": accuracy, "stderr": stderr}}))


def quality_case(tmp_path, arm_summary, base_summary=(0.80, 200), *extra):
    """arm_summary and base_summary are (accuracy, n); the stderr of each is the one its accuracy and n imply."""
    write_summary(tmp_path, "fbase", base_summary[0], stderr_of(*base_summary), base_summary[1])
    write_summary(tmp_path, "fcombo", arm_summary[0], stderr_of(*arm_summary), arm_summary[1])
    return ship("fbase", ["fcombo"], AB, "--gsm8k-dir", tmp_path, *extra)


@pytest.mark.parametrize("accuracy, stderr", [
    (1.5, 0.01), (-0.1, 0.01), (0.8, -0.01), ("0.8", 0.01), (0.8, "0.5"), (0.8, None), (True, 0.01),
])
def test_an_accuracy_or_stderr_that_is_not_a_number_in_range_is_an_input_error(tmp_path, accuracy, stderr):
    write_summary(tmp_path, "fbase", 0.8, stderr_of(0.8, 200))
    write_summary(tmp_path, "fcombo", accuracy, stderr)
    code, _, err = ship("fbase", ["fcombo"], AB, "--gsm8k-dir", tmp_path)
    assert code == 2 and "gsm8k_fcombo.json" in err and "Traceback" not in err


@pytest.mark.parametrize("literal", ["NaN", "Infinity", "-Infinity"])
def test_a_non_finite_accuracy_or_stderr_is_an_input_error(tmp_path, literal):
    write_summary(tmp_path, "fbase", 0.8, stderr_of(0.8, 200))
    (tmp_path / "gsm8k_fcombo.json").write_text('{"summary": {"n": 200, "accuracy": 0.8, "stderr": %s}}' % literal)
    code, _, err = ship("fbase", ["fcombo"], AB, "--gsm8k-dir", tmp_path)
    assert code == 2 and "gsm8k_fcombo.json" in err and "Traceback" not in err


def test_a_json_part_that_is_a_directory_is_refused_without_a_traceback(tmp_path):
    target = tmp_path / "v.json"
    (tmp_path / "v.json.part").mkdir()
    code, _, err = ship("fbase", ["fcombo"], AB, "--no-quality", "--json", target)
    assert code == 2 and "Traceback" not in err and "cannot write" in err and "unexpected" not in err
    assert (tmp_path / "v.json.part").is_dir() and not target.exists()


def test_an_unexpected_error_exits_2_with_one_line_never_1(capsys, monkeypatch):
    module = load_module()
    monkeypatch.setattr(module, "cmd_ship", lambda args: (_ for _ in ()).throw(RuntimeError("boom")))
    code = module.main(["ship", "--base", "b", "--arm", "a", "--bench", "x", "--prefill-lens", "8192", "--no-quality"])
    err = capsys.readouterr().err
    assert code == 2 and err.count("\n") == 1 and "boom" in err


# ---- review round: the quality rule ----------------------------------------------------------------------------

def test_quality_exactly_at_the_limit_passes_and_just_over_it_fails(tmp_path):
    # base 0.80 (stderr 0.028284) is the larger stderr; the arm sits exactly 2 x 0.028284 = 0.056568 above it
    code, out, err = quality_case(tmp_path, (0.856568, 200))
    assert code == 0, err
    assert "delta +0.0566, limit 0.0566 -> pass" in out
    code, out, _ = quality_case(tmp_path, (0.856569, 200))                 # one millionth over
    assert "-> fail" in out and verdict_line(out, "fcombo") == "verdict fcombo: FAIL (gsm8k)"


def test_every_recorded_gsm8k_file_has_the_stderr_its_accuracy_and_n_imply():
    module = load_module()
    files = sorted(Q.glob("gsm8k_*.json"))
    assert len(files) == 5
    for path in files:
        module.read_summary(path)          # raises InputError when the stderr does not match


def test_a_forged_stderr_that_would_widen_the_limit_is_refused(tmp_path):
    write_summary(tmp_path, "fbase", 0.855, 0.02489728900904675)
    write_summary(tmp_path, "fcombo", 0.1, 0.5)
    code, out, err = ship("fbase", ["fcombo"], AB, "--gsm8k-dir", tmp_path)
    assert code == 2 and "PASS" not in out
    assert "gsm8k stderr 0.5 does not match accuracy 0.1 and n 200 (expected 0.021213)" in err
    assert "gsm8k_fcombo.json" in err


def test_a_stderr_rounded_to_six_places_is_still_accepted(tmp_path):
    code, _, err = quality_case(tmp_path, (0.75, 200))
    assert code == 0, err


def test_gsm8k_runs_of_different_size_cannot_be_compared(tmp_path):
    code, out, _ = quality_case(tmp_path, (0.8, 300))
    assert code == 1
    assert "INCOMPLETE (gsm8k n differs: fcombo 300, fbase 200)" in verdict_line(out, "fcombo")


def test_a_gsm8k_run_below_the_minimum_n_is_incomplete_until_the_flag_lowers_it(tmp_path):
    code, out, _ = quality_case(tmp_path, (0.8, 100), (0.8, 100))
    assert code == 1
    assert "INCOMPLETE (gsm8k n 100 is below the minimum 200)" in verdict_line(out, "fcombo")
    code, out, err = quality_case(tmp_path, (0.8, 100), (0.8, 100), "--min-gsm8k-n", "50")
    assert code == 0, err
    assert "note: gsm8k minimum n lowered to 50 (default 200)" in out.splitlines()


# ---- review round: the other inputs ----------------------------------------------------------------------------

def test_a_base_with_only_some_complete_rounds_makes_every_arm_incomplete(tmp_path):
    kept = [line for line in AB.read_text().splitlines() if not line.startswith("fbase-3 ")]
    bench = tmp_path / "base_two_rounds.txt"
    bench.write_text("\n".join(kept) + "\n")
    code, out, _ = ship("fbase", ["fcombo"], bench, "--no-quality")
    assert code == 1
    assert "verdict fcombo: INCOMPLETE (base fbase missing complete arm-rounds: fbase-3)" in out.splitlines()


def test_a_block_with_a_duplicated_key_is_not_complete(tmp_path):
    lines = AB.read_text().splitlines()
    first = next(i for i, line in enumerate(lines) if line.startswith("fcombo-1 c=1 r=2 Output"))
    bench = tmp_path / "dup.txt"
    bench.write_text("\n".join(lines[:first + 1] + [lines[first]] + lines[first + 1:]) + "\n")
    code, out, _ = ship("fbase", ["fcombo"], bench, "--no-quality")
    assert code == 1
    assert "ignored incomplete block: fcombo-1, 37 lines from dup.txt:" in out
    assert "INCOMPLETE (missing complete arm-rounds: fcombo-1)" in verdict_line(out, "fcombo")


def test_a_failing_json_write_keeps_the_old_file_and_leaves_no_part(tmp_path, monkeypatch):
    module = load_module()
    target = tmp_path / "v.json"
    target.write_text('{"old": true}')
    def refuse(src, dst):
        raise OSError(28, "No space left on device")
    monkeypatch.setattr(module.os, "replace", refuse)
    code = module.main(["ship", "--base", "fbase", "--arm", "fcombo", "--bench", str(AB), "--prefill-lens", LENS,
                        "--no-quality", "--json", str(target)])
    assert code == 2
    assert json.loads(target.read_text()) == {"old": True}
    assert not (tmp_path / "v.json.part").exists()


def test_duplicate_prefill_lengths_are_refused():
    code, _, err = ship("fbase", ["fcombo"], AB, "--no-quality", lens="8192 8192")
    assert code == 2 and "8192" in err


@pytest.mark.parametrize("name", ["../x", "a/b", "A1", "a b", ""])
def test_an_arm_or_base_name_that_could_build_a_path_is_refused(name):
    code, _, err = ship("fbase", [name], AB, "--no-quality")
    assert code == 2 and "--arm" in err and "is not an arm name" in err
    code, _, err = ship(name, ["fcombo"], AB, "--no-quality")
    assert code == 2 and "--base" in err and "is not an arm name" in err


# ---- review round: the n rule and the flag are documented where a reader looks ---------------------------------

def test_the_usage_text_and_the_architecture_document_the_gsm8k_n_rule():
    assert "--min-gsm8k-n" in load_module().__doc__ and "same n" in load_module().__doc__
    architecture = (FIXTURES.parent.parent / "research" / "architecture.md").read_text()
    assert "--min-gsm8k-n" in architecture and "stderr" in architecture
