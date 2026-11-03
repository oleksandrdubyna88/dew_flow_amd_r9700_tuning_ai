"""lib/linear_bench.py: the pure parts of the linear-kernel micro-benchmark (E3.S1, LB1-LB7). The benchmark itself (`run`, torch and a GPU) never runs here."""
import importlib.util
import json
import subprocess
import sys

import pytest

from conftest import FIXTURES, LIB, catalogue_rows

KERNELS = FIXTURES / "kernels"
PUBLISHED = KERNELS / "linear_bench_graph.json"
FIVE = ("linear_attn.in_proj_qkvz:2048:12288:30 linear_attn.out_proj+self_attn.o_proj:4096:2048:40 self_attn.qkv_proj:2048:9216:10 "
        "shared_expert.gate_up_proj:2048:1024:40 shared_expert.down_proj:512:2048:40")
# the table of results § 12.1 as the results document prints it: M -> default, Triton default, split, best of 144 tiles, change
RESULTS_DOC = {
    1: ("2.48", "4.97", "2.79", "-", "-"), 4: ("2.95", "4.73", "3.27", "-", "-"), 5: ("3.31", "4.45", "3.63", "-", "-"),
    6: ("4.91", "4.79", "5.89", "4.28", "-13 %"), 8: ("5.16", "5.20", "6.28", "4.45", "-14 %"), 10: ("5.14", "5.05", "6.87", "-", "-"),
    12: ("4.42", "4.46", "8.94", "4.39", "-1 %"), 16: ("6.93", "6.69", "11.67", "5.95", "-14 %"),
}


def load_module():
    spec = importlib.util.spec_from_file_location("linear_bench_under_test", LIB / "linear_bench.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run(args):
    """lib/linear_bench.py as a subprocess, isolated (`-I`: nothing from the current folder or the environment is imported)."""
    done = subprocess.run([sys.executable, "-I", str(LIB / "linear_bench.py"), *map(str, args)], capture_output=True, text=True, timeout=120)
    return done.returncode, done.stdout, done.stderr


def write_rows(tmp_path, rows):
    path = tmp_path / "rows.json"
    path.write_text(json.dumps(rows))
    return path


def row(shape="a", m=1, layers=1, default=100.0, **more):
    return {"shape": shape, "K": 2048, "N": 1024, "layers": layers, "M": m, "default_us": default, "triton_default_us": 50.0, **more}


# ---- LB1: the table of § 12.1 is reproduced from the published JSON -----------------------------------------------------------------------------------

def test_the_table_of_the_results_document_is_reproduced_from_the_published_json():
    code, out, err = run(["summarize", PUBLISHED])
    assert code == 0, err
    assert out.splitlines() == (KERNELS / "linear_table.txt").read_text().splitlines()
    lines = {int(line.split("  ")[0]): tuple(line.split("  ")[1:]) for line in out.splitlines()[1:] if line[0].isdigit()}
    for m, cells in RESULTS_DOC.items():
        assert lines[m] == cells, f"M {m}: the program prints {lines[m]}, the results document {cells}"
    print(out)


def test_a_tiles_line_is_printed_per_sweep_m_and_only_for_those():
    code, out, err = run(["summarize", PUBLISHED])
    assert code == 0, err
    tiles = [line for line in out.splitlines() if line.startswith("tiles M=")]
    assert [line.split(":")[0] for line in tiles] == ["tiles M=6", "tiles M=8", "tiles M=12", "tiles M=16"]
    assert "shared_expert.down_proj=[16, 32, 64, 4, 1]" in tiles[0]


# ---- LB2: a missing value prints a dash and a present one a number -------------------------------------------------------------------------------------

def test_a_missing_value_prints_a_dash_and_a_present_one_a_number(tmp_path):
    rows = [row(m=1), row(m=6, tuned_us=80.0, tuned_tile=[16, 16, 32, 1, None], tuned_maxdiff=0.0)]
    code, out, err = run(["summarize", write_rows(tmp_path, rows)])
    assert code == 0, err
    m1, m6 = out.splitlines()[1:3]
    assert m1.split("  ")[1:] == ["0.10", "0.05", "-", "-", "-"]
    assert m6.split("  ")[4:] == ["0.08", "-20 %"]


def test_a_value_missing_from_one_row_of_an_m_makes_the_whole_column_a_dash(tmp_path):
    rows = [row("a", m=6, split_us=10.0), row("b", m=6)]
    code, out, err = run(["summarize", write_rows(tmp_path, rows)])
    assert code == 0, err
    assert out.splitlines()[1].split("  ")[3] == "-"


# ---- LB3: the arithmetic is exact -------------------------------------------------------------------------------------------------------------------

def test_the_sum_is_a_decimal_sum(tmp_path):
    code, out, err = run(["summarize", write_rows(tmp_path, [row("a", default=1000.5), row("b", default=1000.4)])])
    assert code == 0, err
    assert out.splitlines()[1].split("  ")[1] == "2.00"


def test_float_summing_would_print_44_27_where_decimal_prints_44_28_and_that_is_the_point(tmp_path):
    values, layers = (671.4, 929.6, 1561.2), (15, 20, 10)
    assert f"{sum(v * n for v, n in zip(values, layers)) / 1000:.2f}" == "44.27", "the premise: the binary float sum rounds down"
    rows = [row(shape, m=1, layers=n, default=v) for shape, v, n in zip("abc", values, layers)]
    code, out, err = run(["summarize", write_rows(tmp_path, rows)])
    assert code == 0, err
    assert out.splitlines()[1].split("  ")[1] == "44.28"


# ---- LB4: a malformed file is refused naming the problem ----------------------------------------------------------------------------------------------

@pytest.mark.parametrize("rows, words", [
    ({"not": "a list"}, "not a non-empty JSON list"),
    ([row(m=1), {k: v for k, v in row(m=2).items() if k != "layers"}], "row 1: layers is not a positive integer"),
    ([row(m="6")], "row 0: M is not a positive integer"),
    ([row(m=0)], "row 0: M is not a positive integer"),
    ([row(layers=True)], "row 0: layers is not a positive integer"),
    ([row(m=1), row(m=2, tuned_us=1.0)], "row 1: tuned_tile is missing"),
    ([{k: v for k, v in row().items() if k != "default_us"}], "row 0: default_us is missing"),
    ([row(default="1.5")], "row 0: default_us is not a finite number"),
])
def test_a_malformed_file_is_refused_with_one_line_that_names_the_row_and_the_key(tmp_path, rows, words):
    code, out, err = run(["summarize", write_rows(tmp_path, rows)])
    assert code == 2 and out == ""
    assert err.splitlines() == [f"linear: {words}"] or (err.startswith("linear: ") and words in err and len(err.splitlines()) == 1), err


def test_nan_in_the_file_is_refused_as_a_value_that_is_not_finite(tmp_path):
    path = tmp_path / "nan.json"
    path.write_text(json.dumps([row()]).replace("100.0", "NaN"))
    code, out, err = run(["summarize", path])
    assert code == 2 and "row 0: default_us is not a finite number" in err


def test_a_file_that_is_not_json_or_does_not_exist_is_refused(tmp_path):
    bad = tmp_path / "bad.json"
    bad.write_text("[1, ")
    for path in (bad, tmp_path / "missing.json"):
        code, out, err = run(["summarize", path])
        assert code == 2 and err.startswith("linear: ") and len(err.splitlines()) == 1, err


# ---- LB5: `run` refuses its arguments without touching torch ------------------------------------------------------------------------------------------

def run_args(*words):
    return ["run", "--out", "unused.json", *words]


def test_run_refuses_its_arguments_before_any_import_of_torch():
    cases = [
        (["--shapes", FIVE, "--ms", "1 2", "--sweep-ms", "7"], "linear: sweep M 7 is not in --ms"),
        (["--shapes", "a:2048:12288:30 b:100:16:1"], "K 100 is not a multiple of 8 and of the group size 128"),
        (["--shapes", FIVE, "--timer", "x"], "graph eager"),
        (["--shapes", FIVE, "--ms", "1 1"], "repeats a value"),
        (["--shapes", FIVE, "--group-size", "0"], "the group size 0 is not a positive integer"),
        (["--shapes", "a:2048:12:1"], "N 12 is not a multiple of 16"),
        (["--shapes", "a:2048:16:1 a:2048:16:2"], 'the shape name "a" is given twice'),
        (["--shapes", "a b:2048:16:1"], "is not <name>:<K>:<N>:<layers>"),
        (["--shapes", "a$:2048:16:1"], "is not letters, digits"),
    ]
    for words, message in cases:
        code, out, err = run(run_args(*words))
        assert code == 2, (words, err)
        assert message in err and "ModuleNotFoundError" not in err and "Traceback" not in err, (words, err)
        assert err.startswith("linear: ") and len(err.splitlines()) == 1


# ---- LB6: the shapes grammar is one function ------------------------------------------------------------------------------------------------------------

def test_parse_shapes_returns_the_five_shapes_of_the_source():
    shapes = load_module().parse_shapes(FIVE, 128)
    assert shapes == [("linear_attn.in_proj_qkvz", 2048, 12288, 30), ("linear_attn.out_proj+self_attn.o_proj", 4096, 2048, 40),
                      ("self_attn.qkv_proj", 2048, 9216, 10), ("shared_expert.gate_up_proj", 2048, 1024, 40), ("shared_expert.down_proj", 512, 2048, 40)]


def test_parse_shapes_refuses_a_group_size_of_zero_by_name_not_by_a_zero_division():
    module = load_module()
    for bad in (0, -128):
        with pytest.raises(module.LinearError, match="group size"):
            module.parse_shapes(FIVE, bad)


def shape_cases():
    """(verdict, group size, words) from the file the loader's test reads too: one list for the two implementations of the grammar."""
    rows = [line.split("|", 2) for line in (KERNELS / "shapes_cases.txt").read_text().splitlines() if line and not line.startswith("#")]
    return [(verdict, int(group), words) for verdict, group, words in rows]


@pytest.mark.parametrize("verdict, group, words", shape_cases())
def test_parse_shapes_judges_every_shared_case_as_the_file_says(verdict, group, words):
    module = load_module()
    if verdict == "good":
        assert module.parse_shapes(words, group)
    else:
        with pytest.raises(module.LinearError):
            module.parse_shapes(words, group)


def test_the_shared_case_file_holds_both_verdicts():
    assert {verdict for verdict, _g, _w in shape_cases()} == {"good", "bad"} and len(shape_cases()) >= 15


# ---- LB8: `check` — every expected (shape, M) pair exactly once --------------------------------------------------------------------------------------

THREE = "a:2048:16:1 b:2048:16:2 c:2048:16:3"


def pairs(shapes, ms, sweep):
    """The rows a good run of those shapes and Ms would print: tuned values at the sweep Ms only."""
    out = []
    for shape in shapes:
        for m in ms:
            extra = {"tuned_us": 80.0, "tuned_tile": [16, 16, 32, 1, None], "tuned_maxdiff": 0.0} if m in sweep else {}
            out.append(row(shape, m=m, **extra))
    return out


def check(tmp_path, rows, shapes=THREE, ms="1 2 6 8", sweep="6"):
    return run(["check", write_rows(tmp_path, rows), "--shapes", shapes, "--group-size", 128, "--ms", ms, "--sweep-ms", sweep])


def test_check_accepts_exactly_the_product_of_the_shapes_and_the_ms(tmp_path):
    code, out, err = check(tmp_path, pairs("abc", (1, 2, 6, 8), (6,)))
    assert code == 0 and err == "", err


def test_check_names_the_first_missing_pair(tmp_path):
    rows = [r for r in pairs("abc", (1, 2, 6, 8), (6,)) if not (r["shape"] == "b" and r["M"] == 6)]
    assert len(rows) == 11
    code, out, err = check(tmp_path, rows)
    assert code == 2 and err.splitlines() == ["linear: missing (b, M 6)"]


def test_check_refuses_a_duplicate_that_stands_in_for_a_missing_pair_though_the_row_count_is_right(tmp_path):
    rows = pairs("abc", (1, 2, 6, 8), (6,))
    rows[0] = dict(rows[1])  # the pair (a, M 2) now stands twice and (a, M 1) is gone: 12 rows, as many as expected
    rows[0]["M"] = 2
    assert len(rows) == 12
    code, out, err = check(tmp_path, rows)
    assert code == 2 and "duplicate (a, M 2)" in err and "missing (a, M 1)" in err and len(err.splitlines()) == 1


def test_check_refuses_a_pair_that_was_not_asked_for(tmp_path):
    rows = pairs("abc", (1, 2, 6, 8), (6,)) + [row("a", m=7)]
    code, out, err = check(tmp_path, rows)
    assert code == 2 and err.splitlines() == ["linear: unexpected (a, M 7)"]


def test_check_wants_a_tuned_value_in_every_row_of_a_sweep_m(tmp_path):
    rows = pairs("abc", (1, 2, 6, 8), (6,))
    for r in rows:
        if r["shape"] == "c" and r["M"] == 6:
            del r["tuned_us"], r["tuned_tile"], r["tuned_maxdiff"]
    code, out, err = check(tmp_path, rows)
    assert code == 2 and err.splitlines() == ["linear: no tuned_us in (c, M 6): a sweep M"]


def test_check_refuses_a_malformed_row_as_summarize_does_and_an_unreadable_file(tmp_path):
    rows = pairs("abc", (1, 2, 6, 8), (6,))
    rows[3]["default_us"] = "x"
    code, out, err = check(tmp_path, rows)
    assert code == 2 and "row 3: default_us is not a finite number" in err
    code, out, err = run(["check", tmp_path / "missing.json", "--shapes", THREE, "--group-size", 128, "--ms", "1", "--sweep-ms", "1"])
    assert code == 2 and err.startswith("linear: ")


def test_check_refuses_its_arguments_like_run_does(tmp_path):
    code, out, err = check(tmp_path, pairs("abc", (1,), ()), ms="1", sweep="7")
    assert code == 2 and "sweep M 7 is not in --ms" in err


# ---- LB7: the commands are catalogued -------------------------------------------------------------------------------------------------------------------

def test_every_command_has_a_covered_row_in_the_flow_catalogue():
    rows = catalogue_rows("lib/linear_bench.py", load_module().build_parser())
    assert sorted(rows) == ["check", "run", "summarize"]
    for command, found in rows.items():
        assert found, f"lib/linear_bench.py {command} has no row in research/module_tests.md"
        assert all("covered" in row for row in found), command
