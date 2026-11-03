"""lib/moe_kernel_ab.py: the table and the decision of the MoE kernel A/B, reproduced from the recorded 2026-10-31 (B1) and 2026-11-01 (B2) logs (E2.S1, K1-K12)."""
import importlib.util
import shutil
import subprocess
import sys

from conftest import FIXTURES, LIB, catalogue_rows

AB1 = FIXTURES / "moe" / "b1_ab"
AB2 = FIXTURES / "moe" / "b2_ab"
KEYS1 = "1 2 3 4 6 8 12 16"
KEYS2 = "8 16 20 24 32 48 64 96 128 192 256"
ARMS = ("default", "tuned")


def run(args):
    """Call lib/moe_kernel_ab.py as a subprocess; returns (exit code, stdout, stderr)."""
    done = subprocess.run([sys.executable, "-I", str(LIB / "moe_kernel_ab.py"), *map(str, args)],
                          capture_output=True, text=True, timeout=120)
    return done.returncode, done.stdout, done.stderr


def decide(folder, keys, rule, rule_keys, *extra):
    return run(["decide", folder, "--keys", keys, "--rule", rule, "--rule-keys", rule_keys, *extra])


def load_module():
    spec = importlib.util.spec_from_file_location("moe_kernel_ab_under_test", LIB / "moe_kernel_ab.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write_logs(folder, table, reps=3):
    """Logs in the exact two-line shape of benchmark_moe.py: table is {arm: {batch size: [one kernel time per rep]}}; Ray noise comes first."""
    folder.mkdir(parents=True, exist_ok=True)
    for arm in ARMS:
        for rep in range(1, reps + 1):
            lines = ["2026-11-01 12:00:00,000\tINFO worker.py:1 -- Started a local Ray instance.", "Namespace(tune=False)"]
            for bs, values in table[arm].items():
                lines += [f"Batch size: {bs}, config: {{}}", f"Kernel time: {values[rep - 1]} us"]
            (folder / f"{arm}-{rep}.log").write_text("\n".join(lines) + "\n")
    return folder


def same(bs_values, default="100.00"):
    """{arm: {bs: [x, x, x]}} where the default is `default` and the tuned value is given per bs as one text repeated over the three reps."""
    return {"default": {bs: [default] * 3 for bs in bs_values}, "tuned": {bs: [value] * 3 for bs, value in bs_values.items()}}


# ---- K1, K2: the recorded tables and decisions ------------------------------------------------------------------------------------------------

def test_the_b1_table_and_decision_are_reproduced_exactly():
    """The recorded B1 run printed config lines for bs 1 and 4 only (an older version of the script); the B2 record, the published script and decide
    print one per batch size. So: the recorded lines are all there, in order, and the only other lines are the config lines of the other sizes."""
    code, out, err = decide(AB1, KEYS1, "each", "1 4")
    recorded = (AB1 / "expected.txt").read_text().splitlines()
    lines = out.splitlines()
    assert code == 0, err
    assert [line for line in lines if line in recorded or " config: " not in line] == recorded
    extra = [line for line in lines if line not in recorded]
    expected_extra = [f"{arm} bs {bs} config: " for arm in ARMS for bs in (2, 3, 6, 8, 12, 16)]
    assert len(extra) == 12 and [line[:len(prefix)] for line, prefix in zip(extra, expected_extra)] == expected_extra, extra
    assert lines[-1] == "KERNEL: faster (each of 1 4 is faster by more than 3 %)"


def test_the_b2_table_and_decision_are_reproduced_exactly():
    code, out, err = decide(AB2, KEYS2, "median", "24 32 64 128")
    assert code == 1, err
    assert out == (AB2 / "expected.txt").read_text()
    assert out.splitlines()[-1] == "KERNEL: not faster (median change at 24 32 64 128: +0.0 %)"
    assert any(line.startswith("48 ") and "-0.0 %" in line for line in out.splitlines()), "the 48 row prints -0.0 % as the source did"


# ---- K3, K4: the two rules -------------------------------------------------------------------------------------------------------------------------

def test_rule_each_fails_on_the_first_key_that_is_not_faster_naming_it():
    code, out, err = decide(AB1, KEYS1, "each", "1 16")
    assert code == 1
    assert out.splitlines()[-1] == "KERNEL: not faster (bs 16: -2.5 % is not below -3 %)"


def test_rule_median_is_refused_by_one_size_slower_than_the_threshold_and_passes_at_the_threshold(tmp_path):
    slow = write_logs(tmp_path / "slow", same({8: "103.01", 24: "90.00", 32: "90.00"}))
    code, out, err = decide(slow, "8 24 32", "median", "24 32")
    assert code == 1
    assert out.splitlines()[-1] == "KERNEL: not faster (median change at 24 32: -10.0 %; bs 8 is slower by 3.0 %)"
    edge = write_logs(tmp_path / "edge", same({8: "103.00", 24: "90.00", 32: "90.00"}))
    code, out, err = decide(edge, "8 24 32", "median", "24 32")
    assert code == 0
    assert out.splitlines()[-1] == "KERNEL: faster (median change at 24 32: -10.0 %; no size slower by more than 3 %)"


def test_rule_median_says_not_faster_when_the_median_is_not_below_the_threshold(tmp_path):
    folder = write_logs(tmp_path / "flat", same({24: "99.00", 32: "99.00", 64: "99.00"}))
    code, out, err = decide(folder, "24 32 64", "median", "24 32 64")
    assert code == 1
    assert out.splitlines()[-1] == "KERNEL: not faster (median change at 24 32 64: -1.0 %)"


def test_rule_median_of_an_even_number_of_keys_is_the_mean_of_the_two_middle_gains(tmp_path):
    folder = write_logs(tmp_path / "even", same({24: "90.00", 32: "96.00", 64: "100.00", 128: "100.00"}))
    code, out, err = decide(folder, "24 32 64 128", "median", "24 32 64 128")
    assert out.splitlines()[-1] == "KERNEL: not faster (median change at 24 32 64 128: -2.0 %)"


# ---- K5, K6: refusals ---------------------------------------------------------------------------------------------------------------------------------

def test_an_arm_short_of_a_rep_is_incomplete_not_a_decision(tmp_path):
    folder = tmp_path / "ab"
    shutil.copytree(AB1, folder)
    (folder / "tuned-3.log").unlink()
    code, out, err = decide(folder, KEYS1, "each", "1 4")
    assert code == 2
    assert err.splitlines()[0] == "incomplete: tuned bs 1 has 2 of 3 values"
    assert "KERNEL:" not in out and out == ""


def test_a_missing_log_is_refused_naming_the_file(tmp_path):
    folder = tmp_path / "ab"
    shutil.copytree(AB1, folder)
    (folder / "tuned-3.log").unlink()
    code, out, err = decide(folder, KEYS1, "each", "1 4")
    assert code == 2
    assert f"missing log: {folder / 'tuned-3.log'}" in err.splitlines()


def test_two_logs_joined_into_one_do_not_pass_for_three_reps(tmp_path):
    """The reviewer's case: tuned-2 appended to tuned-1 and tuned-3 deleted made n=3/3 and `faster`. Each log holds each key once."""
    folder = tmp_path / "ab"
    shutil.copytree(AB1, folder)
    first = folder / "tuned-1.log"
    first.write_text(first.read_text() + (folder / "tuned-2.log").read_text())
    (folder / "tuned-2.log").unlink()
    (folder / "tuned-3.log").unlink()
    code, out, err = decide(folder, KEYS1, "each", "1 4")
    assert code == 2 and out == ""
    assert f"bs 1 is in {first} 2 times" in err.splitlines()
    assert f"missing log: {folder / 'tuned-3.log'}" in err.splitlines()


def test_a_key_twice_in_one_log_is_refused_naming_the_file(tmp_path):
    folder = tmp_path / "ab"
    shutil.copytree(AB1, folder)
    log = folder / "default-2.log"
    log.write_text(log.read_text() + "Batch size: 1, config: {}\nKernel time: 1.00 us\n")
    code, out, err = decide(folder, KEYS1, "each", "1 4")
    assert code == 2 and out == ""
    assert f"bs 1 is in {log} 2 times" in err.splitlines()


def test_a_batch_size_the_logs_do_not_hold_is_refused_and_a_rule_key_outside_the_keys_too():
    code, out, err = decide(AB1, "1 2 99", "each", "1")
    assert code == 2
    assert err.splitlines()[0] == "incomplete: default bs 99 has 0 of 3 values"
    code, out, err = decide(AB1, "1 4", "each", "5")
    assert code == 2
    assert "rule key 5 is not in --keys" in err


def test_a_batch_size_in_the_logs_that_is_not_in_the_keys_is_refused():
    code, out, err = decide(AB1, "1 4", "each", "1 4")
    assert code == 2
    assert "bs 2 in " in err and "is not in --keys" in err
    assert out == ""


def test_a_default_time_of_zero_is_refused_not_divided_by(tmp_path):
    folder = write_logs(tmp_path / "zero", {"default": {1: ["0.00"] * 3}, "tuned": {1: ["5.00"] * 3}})
    code, out, err = decide(folder, "1", "each", "1")
    assert code == 2
    assert "bs 1: the default median is 0" in err


# ---- K7, K8: the arithmetic ---------------------------------------------------------------------------------------------------------------------------

def test_float_arithmetic_would_call_exactly_minus_3_percent_faster_and_that_is_the_point(tmp_path):
    # The formula of the published script, in binary floating point, on a pair that is exactly -3 %. (100.00 and 97.00, the pair the plan names,
    # happen to come out as exactly -3.0 in float; 10.00 and 9.70 are one of the pairs that do not.)
    assert (9.70 - 10.00) / 10.00 * 100 < -3, "the refuted approach: binary float says exactly -3 % is below -3 %"
    exact = write_logs(tmp_path / "exact", {"default": {1: ["10.00"] * 3}, "tuned": {1: ["9.70"] * 3}})
    code, out, err = decide(exact, "1", "each", "1")
    assert code == 1
    assert out.splitlines()[-1] == "KERNEL: not faster (bs 1: -3.0 % is not below -3 %)"
    better = write_logs(tmp_path / "better", {"default": {1: ["10.00"] * 3}, "tuned": {1: ["9.69"] * 3}})
    code, out, err = decide(better, "1", "each", "1")
    assert code == 0
    assert out.splitlines()[-1] == "KERNEL: faster (each of 1 is faster by more than 3 %)"


def test_the_median_of_three_reps_is_the_middle_value_not_the_mean(tmp_path):
    folder = write_logs(tmp_path / "m", {"default": {1: ["100.00"] * 3}, "tuned": {1: ["90.00", "97.00", "97.00"]}})
    code, out, err = decide(folder, "1", "each", "1")
    row = next(line for line in out.splitlines() if line.startswith(" 1 "))
    assert "97.00" in row and "-3.0 %" in row and "94.67" not in out
    assert code == 1
    assert out.splitlines()[-1] == "KERNEL: not faster (bs 1: -3.0 % is not below -3 %)"


# ---- K9-K11 ---------------------------------------------------------------------------------------------------------------------------------------------------

def test_reps_and_threshold_are_read():
    code, out, err = decide(AB1, KEYS1, "each", "1 4", "--reps", "2")
    assert code == 0, err
    assert "n=2/2" in out and "n=3/3" not in out
    code, out, err = decide(AB1, KEYS1, "each", "1 4", "--threshold", "10")
    assert code == 1
    assert out.splitlines()[-1] == "KERNEL: not faster (bs 1: -9.4 % is not below -10 %)"


def test_a_log_line_that_is_not_a_measurement_is_ignored_and_a_malformed_kernel_time_is_refused(tmp_path):
    assert decide(AB1, KEYS1, "each", "1 4")[0] == 0, "the fixture logs hold Ray and warning lines before the pairs"
    folder = tmp_path / "ab"
    shutil.copytree(AB1, folder)
    log = folder / "tuned-2.log"
    log.write_text(log.read_text().replace("Kernel time: 195.61 us", "Kernel time: abc us", 1))
    number = next(n for n, line in enumerate(log.read_text().splitlines(), 1) if "abc" in line)
    code, out, err = decide(folder, KEYS1, "each", "1 4")
    assert code == 2
    assert f"{log}:{number}: not a kernel time" in err.splitlines()


def test_the_config_lines_follow_the_table_in_arm_then_batch_size_order():
    code, out, err = decide(AB1, KEYS1, "each", "1 4")
    lines = out.splitlines()
    config_lines = [line for line in lines if " config: " in line]
    assert config_lines[0].startswith("default bs 1 config: {'BLOCK_SIZE_M': 16, 'BLOCK_SIZE_N': 64, ")
    assert config_lines[-1].startswith("tuned bs 16 config: ")
    assert lines.index(config_lines[0]) == len(KEYS1.split()) + 1, "the config lines follow the header and one row per key"


def test_the_rule_and_arguments_are_checked_before_any_log_is_read(tmp_path):
    code, out, err = run(["decide", tmp_path / "nowhere", "--keys", "1 x", "--rule", "each", "--rule-keys", "1"])
    assert code == 2 and '--keys "1 x" is not a list of whitespace-separated batch sizes, e.g. "8 16 24"' in err
    code, out, err = decide(AB1, KEYS1, "each", "1", "--reps", "0")
    assert code == 2 and "--reps must be at least 1" in err
    code, out, err = decide(AB1, KEYS1, "each", "1", "--threshold", "abc")
    assert code == 2 and "--threshold" in err
    code, out, err = decide(AB1, KEYS1, "each", "1", "--threshold", "-1")
    assert code == 2 and "--threshold" in err


# ---- K12: the catalogue ------------------------------------------------------------------------------------------------------------------------------------

def test_every_command_has_a_covered_row_in_the_flow_catalogue():
    rows = catalogue_rows("lib/moe_kernel_ab.py", load_module().build_parser())
    assert sorted(rows) == ["decide"]
    for command, found in rows.items():
        assert found, f"lib/moe_kernel_ab.py {command} has no row in research/module_tests.md"
        assert all("covered" in row for row in found), command
