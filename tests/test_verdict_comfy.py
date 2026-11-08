"""lib/verdict.py comfy and comfy-check-block (E2.S1): the comfy mode of the ship test, scenarios VC1-VC13.

Every test calls lib/verdict.py as a subprocess on bench files written below pytest's `tmp_path`. The vLLM mode keeps its own
tests in tests/test_verdict.py, which this file does not edit (VC11)."""
import json
import re
from decimal import Decimal

from conftest import FIXTURES
from test_verdict import AB, run, verdict_line  # the helpers of the vLLM tests: one copy each

METRICS = "total_s sampler_s vae_s"
# median 12.040, spread 0.100
BASE_TOTAL = ["12.000", "12.010", "12.020", "12.030", "12.040", "12.050", "12.060", "12.080", "12.100"]
BASE = {"total_s": BASE_TOTAL, "sampler_s": ["10.000"] * 9, "vae_s": ["1.500"] * 9}


def flat(total, sampler="10.000", vae="1.500", count=9):
    """An arm whose every run has the same value per metric."""
    return {"total_s": [total] * count, "sampler_s": [sampler] * count, "vae_s": [vae] * count}


def block(tag, values, rnd, workflow="zimage"):
    """The nine lines of one arm-round: run 1..3, each metric in the order of `values`; round `rnd` takes 3(rnd-1)..3rnd."""
    lines = []
    for run_no in (1, 2, 3):
        for metric, series in values.items():
            lines.append(f"{tag} {workflow} r={run_no} {metric}: {series[3 * (rnd - 1) + run_no - 1]}")
    return lines


def write_bench(path, arms, rounds=3, omit=(), workflow="zimage"):
    """arms: {arm: {metric: [3 * rounds values]}}; one complete block per arm-round, except the tags in `omit`."""
    lines = []
    for rnd in range(1, rounds + 1):
        for arm, values in arms.items():
            if f"{arm}-{rnd}" not in omit:
                lines += block(f"{arm}-{rnd}", values, rnd, workflow)
    path.write_text("\n".join(lines) + "\n")
    return path


def comfy(bench, arms, *extra, base="base", direction="lower", rounds=3, metrics=METRICS, decide="total_s", workflow="zimage"):
    args = ["comfy", "--workflow", workflow, "--metrics", metrics, "--decide", decide, "--direction", direction,
            "--base", base, "--rounds", rounds]
    for arm in arms:
        args += ["--arm", arm]
    for path in (bench if isinstance(bench, (list, tuple)) else [bench]):
        args += ["--bench", path]
    return run([*args, *extra])


def check_block(path, tag="fp16acc-1", metrics=METRICS, workflow="zimage"):
    return run(["comfy-check-block", "--tag", tag, "--workflow", workflow, "--metrics", metrics, path])


def one_arm(tmp_path, values, name="fp16acc", **kwargs):
    return write_bench(tmp_path / "bench.txt", {"base": BASE, name: values}, **kwargs)


# ---- VC1 - VC4: the rule ---------------------------------------------------------------------------------------

def test_vc1_an_arm_below_the_base_spread_passes_and_the_lines_are_exact(tmp_path):
    bench = one_arm(tmp_path, flat("11.900", sampler="9.800"))
    code, out, err = comfy(bench, ["fp16acc"])
    assert code == 0, err
    assert out.splitlines() == [
        "arm fp16acc vs base: 3 rounds, 9 values per metric",
        "  total_s: median 11.900 vs 12.040, delta -0.140, base spread 0.100 -> lower",
        "  sampler_s: median 9.800 vs 10.000, delta -0.200, base spread 0.000 (information)",
        "  vae_s: median 1.500 vs 1.500, delta +0.000, base spread 0.000 (information)",
        "verdict fp16acc: PASS"]


def test_vc2_an_arm_above_the_base_spread_fails(tmp_path):
    bench = one_arm(tmp_path, flat("12.200"), name="slow")
    code, out, err = comfy(bench, ["slow"])
    lines = out.splitlines()
    assert code == 0, err
    assert "  total_s: median 12.200 vs 12.040, delta +0.160, base spread 0.100 -> higher" in lines
    assert "verdict slow: FAIL (total_s higher than the base by more than its spread)" in lines


def test_vc3_an_arm_inside_the_spread_is_not_decided_never_fail(tmp_path):
    for total, word in (("12.050", "within, not lower"), ("12.000", "within, lower")):
        bench = one_arm(tmp_path, flat(total), name="mid")
        code, out, err = comfy(bench, ["mid"])
        assert code == 0, err
        assert out.splitlines()[1].endswith(f"-> {word}"), out
        assert verdict_line(out, "mid") == "verdict mid: NOT DECIDED (inside the base spread)"


def test_vc4_exactly_one_spread_below_is_inside_by_exact_decimals(tmp_path):
    base = {"total_s": ["1.100"] * 4 + ["1.200"] + ["1.400"] * 4, "sampler_s": ["1.0"] * 9, "vae_s": ["1.0"] * 9}
    bench = write_bench(tmp_path / "bench.txt", {"base": base, "edge": flat("0.900", "1.0", "1.0")})
    code, out, err = comfy(bench, ["edge"])
    assert code == 0, err
    assert "  total_s: median 0.900 vs 1.200, delta -0.300, base spread 0.300 -> within, lower" in out.splitlines()
    assert verdict_line(out, "edge") == "verdict edge: NOT DECIDED (inside the base spread)"


def test_vc4_companion_the_float_trap_is_alive():
    # In binary floats the arm is "one spread below plus a hair": a float version of the rule would have said PASS.
    assert 0.9 - 1.2 < -(1.4 - 1.1)
    assert Decimal("0.900") - Decimal("1.200") == -(Decimal("1.400") - Decimal("1.100"))


# ---- VC5: a missing arm-round decides nothing --------------------------------------------------------------------

def test_vc5_a_missing_arm_round_is_incomplete_and_prints_no_metric_line(tmp_path):
    bench = one_arm(tmp_path, flat("11.900"), omit={"fp16acc-2"})
    code, out, err = comfy(bench, ["fp16acc"])
    assert code == 1, err
    assert out.splitlines() == ["arm fp16acc vs base: 2 of 3 rounds complete",
                                "verdict fp16acc: INCOMPLETE (missing complete arm-rounds: fp16acc-2)"]


def test_vc5_a_block_without_its_last_line_is_ignored_and_named(tmp_path):
    bench = one_arm(tmp_path, flat("11.900"), omit={"fp16acc-2"})
    text = bench.read_text().splitlines()
    partial = block("fp16acc-2", flat("11.900"), 2)[:-1]  # without `r=3 vae_s`
    bench.write_text("\n".join(text + partial) + "\n")
    start = len(text) + 1
    code, out, err = comfy(bench, ["fp16acc"])
    lines = out.splitlines()
    assert code == 1, err
    assert lines[0] == f"ignored incomplete block: fp16acc-2, 8 lines from bench.txt:{start}"
    assert lines[-1] == "verdict fp16acc: INCOMPLETE (missing complete arm-rounds: fp16acc-2)"


def test_vc5_a_base_without_round_3_names_the_base(tmp_path):
    bench = one_arm(tmp_path, flat("11.900"), omit={"base-3"})
    code, out, err = comfy(bench, ["fp16acc"])
    assert code == 1, err
    assert "verdict fp16acc: INCOMPLETE (base base missing complete arm-rounds: base-3)" in out.splitlines()


def test_vc5_a_later_complete_block_of_the_same_tag_wins(tmp_path):
    bench = one_arm(tmp_path, flat("12.500"))  # the first measurement of the arm: slow
    first_lines = len(bench.read_text().splitlines())
    later = [line for rnd in (1, 2, 3) for line in block(f"fp16acc-{rnd}", flat("11.900"), rnd)]
    bench.write_text(bench.read_text() + "\n".join(later) + "\n")
    code, out, err = comfy(bench, ["fp16acc"])
    lines = out.splitlines()
    assert code == 0, err
    assert sum(line.startswith("superseded complete block: fp16acc-") for line in lines) == 3
    assert re.search(rf"^superseded complete block: fp16acc-1, 9 lines from bench\.txt:\d+$", out, re.M)
    assert verdict_line(out, "fp16acc") == "verdict fp16acc: PASS" and first_lines > 0


# ---- VC6 - VC8: direction, places, the deciding metric -------------------------------------------------------------

def test_vc6_the_direction_is_a_parameter(tmp_path):
    bench = write_bench(tmp_path / "bench.txt", {"base": BASE, "fp16acc": flat("11.900"), "slow": flat("12.200")})
    code, out, err = comfy(bench, ["fp16acc", "slow"], direction="higher")
    assert code == 0, err
    assert verdict_line(out, "fp16acc") == "verdict fp16acc: FAIL (total_s lower than the base by more than its spread)"
    assert verdict_line(out, "slow") == "verdict slow: PASS"


def test_vc7_three_places_half_even_from_exact_decimals(tmp_path):
    arm = flat("0", count=6)
    arm["total_s"] = ["11.800", "11.900", "12.000", "11.800", "11.905", "12.000"]  # sorted middle: 11.900 and 11.905
    base = {metric: series[:6] for metric, series in BASE.items()}
    bench = write_bench(tmp_path / "bench.txt", {"base": base, "mid": arm}, rounds=2)
    json_path = tmp_path / "out.json"
    code, out, err = comfy(bench, ["mid"], "--json", json_path, rounds=2)
    assert code == 0, err
    lines = out.splitlines()
    assert lines[0] == "arm mid vs base: 2 rounds, 6 values per metric"
    assert lines[1].startswith("  total_s: median 11.902 vs 12.025, delta -0.122, ")
    assert json.loads(json_path.read_text())[0]["decide"]["median"] == "11.902"


def test_vc8_only_the_deciding_metric_decides(tmp_path):
    bench = one_arm(tmp_path, flat("11.900", sampler="12.000"))
    code, out, err = comfy(bench, ["fp16acc"])
    lines = out.splitlines()
    assert code == 0, err
    assert verdict_line(out, "fp16acc") == "verdict fp16acc: PASS"
    assert next(line for line in lines if line.startswith("  sampler_s:")).endswith("(information)")


# ---- VC9: bad input is exit 2, one stderr line, no verdict line ------------------------------------------------------

def bad(code, out, err, message):
    assert code == 2 and "verdict " not in out, (code, out)
    assert err.strip() == message, err


def test_vc9_a_vllm_line_in_a_comfy_file(tmp_path):
    bench = tmp_path / "bench.txt"
    bench.write_text("a-1 c=1 r=1 Output token throughput (tok/s):  5.0\n")
    bad(*comfy(bench, ["a"]), "bench.txt:1: not a bench line")


def test_vc9_a_line_of_another_workflow(tmp_path):
    bench = one_arm(tmp_path, flat("11.900"))
    bench.write_text(bench.read_text() + "fp16acc-3 wan5b r=1 total_s: 30.000\n")
    number = len(bench.read_text().splitlines())
    bad(*comfy(bench, ["fp16acc"]), f'bench.txt:{number}: workflow "wan5b" is not the expected "zimage"')


def test_vc9_the_metrics_and_the_deciding_metric(tmp_path):
    bench = one_arm(tmp_path, flat("11.900"))
    bad(*comfy(bench, ["fp16acc"], decide="x"), '--decide "x" is not one of --metrics "total_s sampler_s vae_s"')
    bad(*comfy(bench, ["fp16acc"], metrics=""), '--metrics "" needs at least one metric')
    bad(*comfy(bench, ["fp16acc"], metrics="total_s total_s"), '--metrics "total_s total_s" repeats a metric: total_s')
    bad(*comfy(bench, ["fp16acc"], metrics="total_s Bad-Word"),
        '--metrics "total_s Bad-Word" has "Bad-Word", which is not a metric name '
        "(lower-case letters, digits and _, starting with a letter)")


def test_vc9_a_metric_that_is_not_in_metrics_is_refused_by_name(tmp_path):
    bench = one_arm(tmp_path, flat("11.900"))
    bench.write_text(bench.read_text() + "fp16acc-1 zimage r=2 load_s: 3.0\n")
    number = len(bench.read_text().splitlines())
    bad(*comfy(bench, ["fp16acc"]), f'bench.txt:{number}: metric "load_s" is not one of --metrics "{METRICS}"')
    block_file = tmp_path / "block.txt"
    block_file.write_text("\n".join(block("fp16acc-1", flat("11.900"), 1) + ["fp16acc-1 zimage r=2 load_s: 3.0"]) + "\n")
    bad(*check_block(block_file), f'block.txt:10: metric "load_s" is not one of --metrics "{METRICS}"')


def test_vc9_a_subset_of_the_metrics_names_the_first_foreign_metric(tmp_path):
    bench = one_arm(tmp_path, flat("11.900"))
    bad(*comfy(bench, ["fp16acc"], metrics="total_s", decide="total_s"),
        'bench.txt:2: metric "sampler_s" is not one of --metrics "total_s"')


def test_the_first_word_of_metrics_starts_a_block_so_the_order_is_the_order_bench_py_prints(tmp_path):
    """Pins the reorder case: the standard blocks print total_s first; `--metrics "sampler_s total_s vae_s"` starts a block at
    `r=1 sampler_s`, which is their second line, so every block is cut in two and nothing is complete."""
    bench = one_arm(tmp_path, flat("11.900"))
    bad(*comfy(bench, ["fp16acc"], metrics="sampler_s total_s vae_s"), 'base arm "base" has no complete arm-round in the inputs')
    code, out, err = comfy(bench, ["fp16acc"])
    assert code == 0, err  # the order bench.py prints: the same files are judged


def test_vc9_a_bad_direction_is_argparses_exit_2(tmp_path):
    bench = one_arm(tmp_path, flat("11.900"))
    code, out, err = comfy(bench, ["fp16acc"], direction="sideways")
    assert code == 2 and out == "" and "invalid choice: 'sideways'" in err


def test_vc9_a_base_without_a_complete_block_and_bad_rounds(tmp_path):
    bench = one_arm(tmp_path, flat("11.900"), omit={"base-1", "base-2", "base-3"})
    bad(*comfy(bench, ["fp16acc"]), 'base arm "base" has no complete arm-round in the inputs')
    bad(*comfy(bench, ["fp16acc"], rounds=0), "--rounds must be at least 1")


# ---- VC10: the block check -----------------------------------------------------------------------------------------

def test_vc10_a_complete_block(tmp_path):
    path = tmp_path / "block.txt"
    path.write_text("\n".join(block("fp16acc-1", flat("11.900"), 1)) + "\n")
    code, out, err = check_block(path)
    assert (code, out) == (0, "fp16acc-1: complete, 9 lines\n"), err


def test_vc10_a_missing_line(tmp_path):
    path = tmp_path / "block.txt"
    path.write_text("\n".join(block("fp16acc-1", flat("11.900"), 1)[:-1]) + "\n")
    code, out, _ = check_block(path)
    assert code == 1 and out.splitlines() == ["expected 9 lines, found 8", "missing: r=3 vae_s"]


def test_vc10_a_line_twice(tmp_path):
    path = tmp_path / "block.txt"
    lines = block("fp16acc-1", flat("11.900"), 1)
    path.write_text("\n".join(lines + [lines[0]]) + "\n")
    code, out, _ = check_block(path)
    assert code == 1 and out.strip() == "expected 9 lines, found 10 (duplicate: r=1 total_s)"


def test_vc10_an_empty_file_misses_every_line(tmp_path):
    path = tmp_path / "block.txt"
    path.write_text("")
    code, out, _ = check_block(path)
    lines = out.splitlines()
    assert code == 1 and lines[0] == "expected 9 lines, found 0"
    assert lines[1:] == [f"missing: r={r} {metric}" for r in (1, 2, 3) for metric in METRICS.split()]


def test_vc10_another_tag_or_workflow_is_an_input_error(tmp_path):
    path = tmp_path / "block.txt"
    path.write_text("\n".join(block("fp16acc-2", flat("11.900"), 2)) + "\n")
    bad(*check_block(path), 'block.txt:1: tag "fp16acc-2" is not the expected "fp16acc-1"')
    path.write_text("\n".join(block("fp16acc-1", flat("11.900"), 1, workflow="wan5b")) + "\n")
    bad(*check_block(path), 'block.txt:1: workflow "wan5b" is not the expected "zimage"')


# ---- VC11: the vLLM mode is unchanged --------------------------------------------------------------------------------

def test_vc11_the_vllm_mode_still_gives_the_recorded_verdict():
    """The complete proof is tests/test_verdict.py, which this story does not edit; this is the smoke that the new commands
    share a parser with it."""
    code, out, err = run(["ship", "--base", "fbase", "--arm", "fcombo", "--bench", AB,
                          "--prefill-lens", "8192 32768", "--no-quality"])
    assert code == 0, err
    assert "verdict fcombo: PASS (quality NOT checked)" in out.splitlines()


# ---- VC12: --json -------------------------------------------------------------------------------------------------

def test_vc12_json_has_every_arm_with_three_places_and_leaves_no_part_file(tmp_path):
    bench = write_bench(tmp_path / "bench.txt", {"base": BASE, "fp16acc": flat("11.900", sampler="9.800"), "gap": flat("11.900")},
                        omit={"gap-2"})
    target = tmp_path / "result.json"
    code, _, err = comfy(bench, ["fp16acc", "gap"], "--json", target)
    assert code == 1, err
    done, partial = json.loads(target.read_text()), json.loads(target.read_text())[1]
    assert [item["arm"] for item in done] == ["fp16acc", "gap"]
    assert done[0] == {
        "arm": "fp16acc", "base": "base", "workflow": "zimage", "rounds": 3, "direction": "lower",
        "decide": {"metric": "total_s", "median": "11.900", "base_median": "12.040", "delta": "-0.140", "spread": "0.100", "n": 9,
                   "word": "lower"},
        "information": {
            "sampler_s": {"median": "9.800", "base_median": "10.000", "delta": "-0.200", "spread": "0.000", "n": 9,
                          "word": "information"},
            "vae_s": {"median": "1.500", "base_median": "1.500", "delta": "0.000", "spread": "0.000", "n": 9,
                      "word": "information"}},
        "verdict": "PASS", "reason": None}
    assert partial["decide"] is None and partial["information"] is None
    assert partial["verdict"] == "INCOMPLETE" and "gap-2" in partial["reason"]
    assert not list(tmp_path.glob("*.part"))


def test_vc12_an_unwritable_json_path_is_exit_2(tmp_path):
    bench = one_arm(tmp_path, flat("11.900"))
    code, out, err = comfy(bench, ["fp16acc"], "--json", tmp_path / "no" / "such" / "dir" / "r.json")
    assert code == 2 and err.startswith("cannot write ") and not list(tmp_path.rglob("*.part"))


# ---- VC13: the two grammars do not mix ---------------------------------------------------------------------------

def test_vc13_ship_refuses_a_comfy_file(tmp_path):
    bench = one_arm(tmp_path, flat("11.900"))
    code, out, err = run(["ship", "--base", "base", "--arm", "fp16acc", "--bench", bench,
                          "--prefill-lens", "8192", "--no-quality"])
    assert code == 2 and err.strip() == "bench.txt:1: not a bench line"


def test_vc13_comfy_refuses_a_vllm_file():
    assert AB.is_file() and AB.parent == FIXTURES / "ship_test"
    code, out, err = comfy(AB, ["fcombo"], base="fbase")
    assert code == 2 and err.strip() == f"{AB.name}:1: not a bench line"


def test_vc13_check_block_refuses_a_comfy_line(tmp_path):
    path = tmp_path / "block.txt"
    path.write_text("\n".join(block("fp16acc-1", flat("11.900"), 1)) + "\n")
    code, out, err = run(["check-block", "--tag", "fp16acc-1", "--prefill-lens", "8192", path])
    assert code == 2 and err.strip() == "block.txt:1: not a bench line"


# ---- the arm of the plan with a digit in the middle ----------------------------------------------------------------

def test_the_arm_fp8wmm_is_an_arm_name(tmp_path):
    bench = one_arm(tmp_path, flat("11.900"), name="fp8wmm")
    code, out, err = comfy(bench, ["fp8wmm"])
    assert code == 0, err
    assert verdict_line(out, "fp8wmm") == "verdict fp8wmm: PASS"
