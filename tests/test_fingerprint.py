"""lib/fingerprint.py: the run identity of a series (E1.S3, scenarios F1-F6 and the helpers around them)."""
import hashlib
import importlib.util
import json
import subprocess
import sys

import pytest

from conftest import LIB, catalogue_rows

HEX_A = "a" * 64
HEX_B = "b" * 64
HEX_C = "c" * 64
CONFIG = {
    "MODEL_DIR": "/root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ",
    "SERVED_NAME": "qwen3.6-35b-a3b",
    "MAX_MODEL_LEN": "131072",
    "MAX_NUM_SEQS": "4",
    "GPU_MEM_UTIL": "0.85",
    "EXTRA_SERVE_ARGS": "--limit-mm-per-prompt.image 0",
    "TUNED_CONFIG_DIR": "/work/moe/tune/merged",
    "MOUNTS": "C/auto_gptq.py:/opt/x.py:ro",
    "IMAGE": "rocm/vllm:test",
    "CONTAINER_PREFIX": "r9700tune-",
    "GSM8K_DATA": "/work/gsm8k/test.jsonl",
}


def run(args):
    """Call lib/fingerprint.py as a subprocess; returns (exit code, stdout, stderr)."""
    done = subprocess.run([sys.executable, "-I", str(LIB / "fingerprint.py"), *map(str, args)],
                          capture_output=True, text=True, timeout=120)
    return done.returncode, done.stdout, done.stderr


def load_module():
    spec = importlib.util.spec_from_file_location("fingerprint_under_test", LIB / "fingerprint.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write_inputs(folder, config=None, patches=None, arms=None, series=None, listing="a.safetensors 100\nconfig.json 10\n",
                 genconfig=None, tools=None):
    """An inputs directory as lib/series.sh writes it: one file per component group."""
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "arms").mkdir(exist_ok=True)
    values = {**CONFIG, **(config or {})}
    (folder / "config.env").write_text("".join(f"R9700_{key}={value}\n" for key, value in values.items()))
    patches = {"C/auto_gptq.py": HEX_A, "C/gptq_utils.py": HEX_B} if patches is None else patches
    (folder / "patches").write_text("".join(f"{path} {digest}\n" for path, digest in patches.items()))
    arms = {"fbase": ("--speculative-config.method mtp", "", ""), "fcombo": ("--attention-backend TRITON_ATTN", "", "")} if arms is None else arms
    for name, (args, env, mounts) in arms.items():
        for suffix, text in (("args", args), ("env", env), ("mounts", mounts)):
            words = text.split()
            (folder / "arms" / f"{name}.{suffix}").write_text("".join(f"{word}\n" for word in words))
    (folder / "listing").write_text(listing)
    (folder / "genconfig").write_text("generation_config.json " + HEX_C + "\n" if genconfig is None else genconfig)
    tools = {"harness_py": HEX_A, "bench_sh": HEX_B, "series_sh": HEX_C} if tools is None else tools
    (folder / "tools").write_text("".join(f"{key} {digest}\n" for key, digest in tools.items()))
    (folder / "series").write_text(series or "base=fbase\nrounds=3\nprefill_lens=8192 32768\n")
    return folder


def build(folder, out):
    return run(["build", folder, "--out", out])


def canonical_sha(components):
    text = json.dumps(components, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(text.encode()).hexdigest()


@pytest.fixture
def built(tmp_path):
    """(inputs folder, the document built from it)."""
    folder = write_inputs(tmp_path / "in")
    out = tmp_path / "fp.json"
    code, stdout, stderr = build(folder, out)
    assert code == 0, stderr
    return folder, out


# ---- F1: the canonical form -------------------------------------------------------------------------------------

def test_f1_the_hash_is_over_the_canonical_form_and_does_not_depend_on_the_order_of_the_inputs(tmp_path):
    folder = write_inputs(tmp_path / "in")
    code, stdout, stderr = build(folder, tmp_path / "a.json")
    assert code == 0, stderr
    doc = json.loads((tmp_path / "a.json").read_text())
    assert doc["version"] == 1
    assert doc["sha256"] == canonical_sha(doc["components"])
    assert stdout.strip() == doc["sha256"]
    # the same inputs with the patches in another order give the same document hash
    other = write_inputs(tmp_path / "in2", patches={"C/gptq_utils.py": HEX_B, "C/auto_gptq.py": HEX_A})
    code, stdout2, _ = build(other, tmp_path / "b.json")
    assert code == 0
    assert stdout2.strip() == doc["sha256"]


def test_f1_the_components_are_the_ones_of_the_decision(built):
    _, out = built
    components = json.loads(out.read_text())["components"]
    assert sorted(components) == ["arms", "base", "genconfig", "image", "machine", "model", "patches", "rounds", "tools", "workload"]
    model = components["model"]
    assert model["dir"] == CONFIG["MODEL_DIR"]
    assert model["served_name"] == "qwen3.6-35b-a3b"
    assert model["max_model_len"] == 131072 and model["max_num_seqs"] == 4
    assert model["gpu_mem_util"] == "0.85"
    assert model["extra_serve_args"] == CONFIG["EXTRA_SERVE_ARGS"] and model["tuned_config_dir"] == CONFIG["TUNED_CONFIG_DIR"]
    assert model["mounts"] == CONFIG["MOUNTS"]
    assert model["listing"] == hashlib.sha256(b"a.safetensors 100\nconfig.json 10\n").hexdigest()
    assert components["genconfig"] == hashlib.sha256(("generation_config.json " + HEX_C + "\n").encode()).hexdigest()
    assert components["image"] == "rocm/vllm:test"
    assert components["patches"] == {"C/auto_gptq.py": HEX_A, "C/gptq_utils.py": HEX_B}
    assert components["arms"]["fbase"] == {"args": ["--speculative-config.method", "mtp"], "env": [], "mounts": []}
    assert components["base"] == "fbase" and components["rounds"] == 3
    assert components["tools"] == {"harness_py": HEX_A, "bench_sh": HEX_B, "series_sh": HEX_C}
    assert components["machine"] == {"container_prefix": "r9700tune-", "gsm8k_data": "/work/gsm8k/test.jsonl"}
    assert components["workload"] == {
        "bench": {"input": 1024, "output": 512, "prompts": {"1": 6, "4": 12}, "seeds": [1, 2, 3]},
        "prefill": {"lens": [8192, 32768], "output": 128, "prompts": 3, "seeds": [1, 2, 3]},
        "quality": {"prompts": 20, "gsm8k_n": 200},
    }


def test_f1_the_document_lists_every_arm_of_the_inputs_and_the_base_may_be_any_of_them(tmp_path):
    arms = {"zeta": ("--a", "", ""), "alpha": ("--b", "", "")}
    folder = write_inputs(tmp_path / "in", arms=arms, series="base=zeta\nrounds=1\nprefill_lens=8192\n")
    assert build(folder, tmp_path / "fp.json")[0] == 0
    assert sorted(run(["show", tmp_path / "fp.json", "arms"])[1].split()) == ["alpha", "zeta"]
    assert run(["show", tmp_path / "fp.json", "workload.prefill.lens"])[1].strip() == "8192"


# ---- F2-F4: compare ---------------------------------------------------------------------------------------------

def changed(tmp_path, name, mutate):
    """A second document: the built one with a change made to its components (the hash is recomputed)."""
    doc = json.loads((tmp_path / "fp.json").read_text())
    mutate(doc["components"])
    doc["sha256"] = canonical_sha(doc["components"])
    path = tmp_path / name
    path.write_text(json.dumps(doc))
    return path


def test_f2_compare_names_every_differing_leaf_with_its_path_old_and_new_in_sorted_order(tmp_path, built):
    def mutate(components):
        components["model"]["max_num_seqs"] = 8
        components["patches"]["C/auto_gptq.py"] = HEX_C
    new = changed(tmp_path, "new.json", mutate)
    code, stdout, _ = run(["compare", tmp_path / "fp.json", new])
    assert code == 1
    assert stdout.splitlines() == [
        "fingerprint differs: model.max_num_seqs: 4 -> 8",
        f"fingerprint differs: patches.C/auto_gptq.py: {HEX_A} -> {HEX_C}",
    ]


def test_f2_equal_documents_exit_0_and_print_nothing(tmp_path, built):
    code, stdout, stderr = run(["compare", tmp_path / "fp.json", tmp_path / "fp.json"])
    assert (code, stdout, stderr) == (0, "", "")


def test_f3_a_missing_leaf_is_absent(tmp_path, built):
    old = changed(tmp_path, "old.json", lambda components: components["tools"].pop("series_sh"))
    code, stdout, _ = run(["compare", old, tmp_path / "fp.json"])
    assert code == 1
    assert stdout.splitlines() == [f"fingerprint differs: tools.series_sh: <absent> -> {HEX_C}"]
    code, stdout, _ = run(["compare", tmp_path / "fp.json", old])
    assert stdout.splitlines() == [f"fingerprint differs: tools.series_sh: {HEX_C} -> <absent>"]


def test_f4_a_new_arm_is_an_extension_a_changed_arm_and_a_changed_base_are_differences(tmp_path, built):
    added = changed(tmp_path, "added.json", lambda c: c["arms"].update({"fb1": {"args": ["--x"], "env": ["A=1"], "mounts": []}}))
    code, stdout, _ = run(["compare", tmp_path / "fp.json", added])
    assert (code, stdout.splitlines()) == (0, ["fingerprint: arm fb1 added"])
    args = changed(tmp_path, "args.json", lambda c: c["arms"]["fcombo"].update({"args": ["--changed"]}))
    code, stdout, _ = run(["compare", tmp_path / "fp.json", args])
    assert code == 1 and stdout.startswith("fingerprint differs: arms.fcombo.args: ")
    base = changed(tmp_path, "base.json", lambda c: c.update({"base": "fcombo"}))
    code, stdout, _ = run(["compare", tmp_path / "fp.json", base])
    assert (code, stdout.splitlines()) == (1, ["fingerprint differs: base: fbase -> fcombo"])


def test_f4_an_arm_left_out_of_the_new_document_is_not_a_difference(tmp_path, built):
    left_out = changed(tmp_path, "left.json", lambda c: c["arms"].pop("fcombo"))
    code, stdout, _ = run(["compare", tmp_path / "fp.json", left_out])
    assert (code, stdout) == (0, "")


def test_f4_merge_writes_the_stored_document_with_the_new_arm_added_and_its_hash_recomputed(tmp_path, built):
    added = changed(tmp_path, "added.json", lambda c: c["arms"].update({"fb1": {"args": ["--x"], "env": [], "mounts": []}}))
    code, stdout, _ = run(["compare", "--merge", tmp_path / "fp.json", added])
    assert (code, stdout.splitlines()) == (0, ["fingerprint: arm fb1 added"])
    doc = json.loads((tmp_path / "fp.json").read_text())
    assert list(doc["components"]["arms"]) == ["fbase", "fcombo", "fb1"]
    assert doc["sha256"] == canonical_sha(doc["components"])
    assert sorted(p.name for p in tmp_path.iterdir() if p.name.startswith("fp.json")) == ["fp.json"]


def test_f4_merge_changes_nothing_when_a_difference_is_found(tmp_path, built):
    before = (tmp_path / "fp.json").read_text()
    both = changed(tmp_path, "both.json", lambda c: (c["arms"].update({"fb1": {"args": [], "env": [], "mounts": []}}), c.update({"image": "other:1"})))
    code, stdout, _ = run(["compare", "--merge", tmp_path / "fp.json", both])
    assert code == 1 and "fingerprint differs: image: rocm/vllm:test -> other:1" in stdout
    assert (tmp_path / "fp.json").read_text() == before


def test_f4_more_rounds_are_an_extension_fewer_rounds_are_a_difference(tmp_path, built):
    more = changed(tmp_path, "more.json", lambda c: c.update({"rounds": 5}))
    code, stdout, _ = run(["compare", tmp_path / "fp.json", more])
    assert (code, stdout.splitlines()) == (0, ["fingerprint: rounds extended 3 -> 5"])
    fewer = changed(tmp_path, "fewer.json", lambda c: c.update({"rounds": 2}))
    code, stdout, _ = run(["compare", tmp_path / "fp.json", fewer])
    assert (code, stdout.splitlines()) == (1, ["fingerprint differs: rounds: 3 -> 2"])


def test_f4_merge_writes_the_larger_round_count_with_its_hash_recomputed(tmp_path, built):
    more = changed(tmp_path, "more.json", lambda c: c.update({"rounds": 5}))
    code, _, _ = run(["compare", "--merge", tmp_path / "fp.json", more])
    doc = json.loads((tmp_path / "fp.json").read_text())
    assert code == 0 and doc["components"]["rounds"] == 5 and doc["sha256"] == canonical_sha(doc["components"])


def test_f4_a_document_that_cannot_be_read_is_exit_2_and_names_the_file(tmp_path):
    (tmp_path / "bad.json").write_text("{not json")
    code, _, stderr = run(["compare", tmp_path / "bad.json", tmp_path / "bad.json"])
    assert code == 2 and "bad.json" in stderr and stderr.startswith("fingerprint: ")
    code, _, stderr = run(["compare", tmp_path / "nosuch.json", tmp_path / "nosuch.json"])
    assert code == 2 and "nosuch.json" in stderr


# ---- F5, F6: build refusals and atomic writing ------------------------------------------------------------------

def test_f5_build_refuses_a_malformed_input_naming_the_file_and_the_line(tmp_path):
    folder = write_inputs(tmp_path / "in")
    (folder / "patches").write_text(f"C/a.py {HEX_A}\nC/b.py {HEX_B}\nC/no-hash.py\n")
    code, _, stderr = build(folder, tmp_path / "fp.json")
    assert code == 2
    assert stderr.strip() == 'fingerprint: patches:3: expected "<path> <64 hex>"'
    assert not (tmp_path / "fp.json").exists()


@pytest.mark.parametrize("name, text, shape", [
    ("genconfig", "x y\n", '<path> <64 hex>'),
    ("tools", "harness_py\n", '<key> <64 hex>'),
    ("series", "base=fbase\nrounds=three\nprefill_lens=8192\n", "rounds=<number>"),
    ("config.env", "not a line\n", "R9700_<KEY>=<value>"),
])
def test_f5_every_input_file_has_its_own_refusal(tmp_path, name, text, shape):
    folder = write_inputs(tmp_path / "in")
    (folder / name).write_text(text)
    code, _, stderr = build(folder, tmp_path / "fp.json")
    assert code == 2
    assert stderr.startswith(f"fingerprint: {name}:") and shape in stderr


def test_f5_a_missing_input_is_named(tmp_path):
    folder = write_inputs(tmp_path / "in")
    (folder / "listing").unlink()
    code, _, stderr = build(folder, tmp_path / "fp.json")
    assert code == 2 and stderr.strip() == "fingerprint: listing: the input file is missing"


def test_f5_an_arm_without_its_three_files_is_named(tmp_path):
    folder = write_inputs(tmp_path / "in")
    (folder / "arms" / "fcombo.env").unlink()
    code, _, stderr = build(folder, tmp_path / "fp.json")
    assert code == 2 and "arms/fcombo.env" in stderr


def test_f5_the_base_must_be_one_of_the_arms(tmp_path):
    folder = write_inputs(tmp_path / "in", series="base=nosuch\nrounds=3\nprefill_lens=8192\n")
    code, _, stderr = build(folder, tmp_path / "fp.json")
    assert code == 2 and "base" in stderr and "nosuch" in stderr


def test_f6_build_writes_atomically_and_leaves_no_part_file(tmp_path):
    folder = write_inputs(tmp_path / "in")
    target = tmp_path / "taken"
    target.mkdir()
    code, _, stderr = build(folder, target)
    assert code == 2 and stderr.startswith("fingerprint: ")
    assert not (tmp_path / "taken.part").exists()
    assert sorted(p.name for p in tmp_path.iterdir() if p.name.startswith("taken")) == ["taken"]


def test_f6_a_good_build_leaves_only_its_file(tmp_path, built):
    assert sorted(p.name for p in tmp_path.iterdir() if p.name.startswith("fp")) == ["fp.json"]


# ---- show -------------------------------------------------------------------------------------------------------

@pytest.mark.parametrize("path, expected", [
    ("base", "fbase"),
    ("rounds", "3"),
    ("workload.prefill.lens", "8192 32768"),
    ("arms", "fbase\nfcombo"),
    ("arms.fbase.args", "--speculative-config.method mtp"),
    ("model.max_num_seqs", "4"),
])
def test_show_prints_a_leaf_bare_a_list_on_one_line_and_a_dict_as_its_keys(tmp_path, built, path, expected):
    code, stdout, _ = run(["show", tmp_path / "fp.json", path])
    assert code == 0 and stdout.rstrip("\n") == expected


def test_show_prints_the_document_hash_and_refuses_an_unknown_path(tmp_path, built):
    doc = json.loads((tmp_path / "fp.json").read_text())
    assert run(["show", tmp_path / "fp.json", "sha256"])[1].strip() == doc["sha256"]
    code, _, stderr = run(["show", tmp_path / "fp.json", "no.such.path"])
    assert code == 2 and "no.such.path" in stderr


# ---- check-quality: the record's round-1 files -------------------------------------------------------------------

def quality_files(tmp_path, n=200, results=20):
    prompts = tmp_path / "prompts_a.json"
    gsm = tmp_path / "gsm8k_a.json"
    prompts.write_text(json.dumps({"results": [{"prompt": str(i)} for i in range(results)]}))
    gsm.write_text(json.dumps({"summary": {"n": n, "correct": 170, "accuracy": 0.85, "stderr": 0.0252}, "items": []}))
    return prompts, gsm


def test_check_quality_accepts_20_results_and_a_gsm8k_summary_of_200(tmp_path):
    prompts, gsm = quality_files(tmp_path)
    code, stdout, stderr = run(["check-quality", prompts, gsm])
    assert (code, stderr) == (0, "") and stdout.strip() == "quality: ok"


@pytest.mark.parametrize("kwargs, text", [
    ({"n": 199}, "gsm8k summary.n is 199, expected 200"),
    ({"results": 19}, "prompts has 19 results, expected 20"),
])
def test_check_quality_names_what_is_wrong(tmp_path, kwargs, text):
    prompts, gsm = quality_files(tmp_path, **kwargs)
    code, stdout, _ = run(["check-quality", prompts, gsm])
    assert code == 1 and text in stdout


def test_check_quality_names_a_missing_or_unparsable_file(tmp_path):
    prompts, gsm = quality_files(tmp_path)
    gsm.write_text("{broken")
    code, stdout, _ = run(["check-quality", prompts, gsm])
    assert code == 1 and "gsm8k_a.json" in stdout and "not JSON" in stdout
    code, stdout, _ = run(["check-quality", prompts, tmp_path / "gone.json"])
    assert code == 1 and "gone.json" in stdout and "missing" in stdout


# ---- build --probe-from: the cheap components again, the probed ones from the stored document ------------------------

def test_build_probe_from_takes_the_listing_and_the_generation_config_from_the_stored_document_and_needs_neither_file(tmp_path, built):
    folder, out = built
    (folder / "listing").unlink()
    (folder / "genconfig").unlink()
    code, stdout, stderr = run(["build", folder, "--out", tmp_path / "again.json", "--probe-from", out])
    assert code == 0, stderr
    assert json.loads((tmp_path / "again.json").read_text()) == json.loads(out.read_text())
    assert stdout.strip() == json.loads(out.read_text())["sha256"]


def test_build_probe_from_sees_a_changed_patch_and_a_changed_arm(tmp_path, built):
    folder, out = built
    (folder / "listing").unlink()
    (folder / "genconfig").unlink()
    (folder / "patches").write_text(f"C/auto_gptq.py {HEX_C}\nC/gptq_utils.py {HEX_B}\n")
    (folder / "arms" / "fcombo.args").write_text("--other\n")
    assert run(["build", folder, "--out", tmp_path / "again.json", "--probe-from", out])[0] == 0
    code, stdout, _ = run(["compare", out, tmp_path / "again.json"])
    assert code == 1
    assert f"fingerprint differs: patches.C/auto_gptq.py: {HEX_A} -> {HEX_C}" in stdout
    assert "fingerprint differs: arms.fcombo.args: " in stdout


def test_build_probe_from_a_missing_stored_document_is_named(tmp_path, built):
    folder, _ = built
    code, _, stderr = run(["build", folder, "--out", tmp_path / "x.json", "--probe-from", tmp_path / "nosuch.json"])
    assert code == 2 and "nosuch.json" in stderr


# ---- a stored document is trusted only when its digest is the digest of its components -------------------------------------------

def edited(tmp_path, name, mutate):
    """A copy of the built document with a change made to the raw JSON (the digest is NOT recomputed)."""
    doc = json.loads((tmp_path / "fp.json").read_text())
    mutate(doc)
    path = tmp_path / name
    path.write_text(json.dumps(doc))
    return path


def test_a_document_whose_sha256_was_edited_is_refused_by_compare_show_and_probe_from(tmp_path, built):
    bad = edited(tmp_path, "bad.json", lambda d: d.update({"sha256": "0" * 64}))
    for args in (["compare", bad, tmp_path / "fp.json"], ["compare", tmp_path / "fp.json", bad], ["show", bad, "base"],
                 ["build", built[0], "--out", tmp_path / "x.json", "--probe-from", bad]):
        code, _, stderr = run(args)
        assert code == 2, args
        assert "bad.json" in stderr and "stored digest does not match" in stderr, (args, stderr)


def test_a_document_whose_components_were_edited_without_the_digest_is_refused(tmp_path, built):
    bad = edited(tmp_path, "bad.json", lambda d: d["components"]["model"].update({"max_num_seqs": 8}))
    code, _, stderr = run(["compare", tmp_path / "fp.json", bad])
    assert code == 2 and "stored digest does not match" in stderr


def test_a_document_of_an_unsupported_version_is_refused(tmp_path, built):
    bad = edited(tmp_path, "bad.json", lambda d: d.update({"version": 2}))
    code, _, stderr = run(["show", bad, "base"])
    assert code == 2 and "bad.json" in stderr and "version" in stderr


def test_a_good_document_is_still_read(tmp_path, built):
    assert run(["show", tmp_path / "fp.json", "base"])[0] == 0


# ---- the catalogue ------------------------------------------------------------------------------------------------

def test_every_command_has_a_covered_row_in_the_flow_catalogue():
    rows = catalogue_rows("lib/fingerprint.py", load_module().build_parser())
    assert sorted(rows) == ["build", "check-quality", "compare", "show"]
    for command, found in rows.items():
        assert found, f"lib/fingerprint.py {command} has no row in research/module_tests.md"
        assert all("covered" in row for row in found), command
