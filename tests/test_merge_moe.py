"""lib/merge_moe.py: `check` and `merge` of MoE tuning chunk files (E2.S1, scenarios M1-M17 and the edges around them).

A chunk dir the tests build holds ONE file with the name of the fixture it is cut from and the fixture's own entries for the asked keys: the chunk
files of 2026-10-28..11-01 are not published, and this is exactly how the merged files were made. The file name is always read back from the
fixture folder, never typed.
"""
import errno
import importlib.util
import json
import os
import signal
import subprocess
import sys
import time

import pytest

from conftest import FIXTURES, LIB, catalogue_rows

B1 = FIXTURES / "moe" / "b1"
B2 = FIXTURES / "moe" / "b2"
BASE = FIXTURES / "moe" / "b2_base"
NAME_ENV = "R9700_TEST_MERGE_HOLD_S"
B1_GROUPS = ("256 1024 2048", "1", "2", "4", "12")


def run(args, env=None):
    """Call lib/merge_moe.py as a subprocess; returns (exit code, stdout, stderr)."""
    done = subprocess.run([sys.executable, "-I", str(LIB / "merge_moe.py"), *map(str, args)],
                          capture_output=True, text=True, timeout=120, env=env)
    return done.returncode, done.stdout, done.stderr


def load_module():
    spec = importlib.util.spec_from_file_location("merge_moe_under_test", LIB / "merge_moe.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def fixture_file(folder):
    """The one E=*.json of a fixture folder (read back, never typed)."""
    found = sorted(folder.glob("E=*.json"))
    assert len(found) == 1, folder
    return found[0]


def chunk_dir(tmp_path, label, folder, keys, version=None, env=None, mutate=None, promise=True):
    """A chunk dir under tmp_path cut from a merged fixture: the fixture's file name, its triton_version (or `version`), its entries for `keys`.

    `mutate(data)` may change the written dictionary; `env` is the text of a chunk.env, which gets `KEYS="<keys>"` in front unless it holds one or
    `promise` is False (a chunk.env must promise)."""
    if env is not None and promise and "KEYS=" not in env:
        env = f'KEYS="{keys}"\n' + env
    source = fixture_file(folder)
    whole = json.loads(source.read_text())
    data = {"triton_version": version or whole["triton_version"]}
    data.update({str(key): whole[str(key)] for key in keys.split()})
    if mutate:
        mutate(data)
    target = tmp_path / label
    target.mkdir()
    (target / source.name).write_text(json.dumps(data, indent=4) + "\n")
    if env is not None:
        (target / "chunk.env").write_text(env)
    return target


def b1_chunks(tmp_path):
    return [chunk_dir(tmp_path, f"b1-{n}", B1, keys) for n, keys in enumerate(B1_GROUPS)]


def scenario_1(tmp_path, chunks=None, out_name="m"):
    return run(["merge", "--out", tmp_path / out_name, *(chunks or b1_chunks(tmp_path))])


def parts_under(folder):
    return sorted(str(path) for path in folder.rglob("*.part-*"))


def own_ticks(pid="self"):
    """Field 22 of /proc/<pid>/stat, read after the last `)`."""
    stat = open(f"/proc/{pid}/stat").read()
    return stat[stat.rindex(")") + 2:].split(" ")[19]


# ---- M1, M2, M7: the two published merged files, byte for byte --------------------------------------------------------------------------------

def test_the_five_b1_chunk_groups_merge_into_the_published_merged_b1_byte_for_byte(tmp_path):
    code, out, err = scenario_1(tmp_path)
    expected = fixture_file(B1)
    assert code == 0, err
    assert (tmp_path / "m" / expected.name).read_bytes() == expected.read_bytes()
    assert out.splitlines()[-1] == f"wrote {tmp_path / 'm' / expected.name}: triton 3.8.0, keys [1, 2, 4, 12, 256, 1024, 2048]"


def test_the_nine_key_production_file_plus_the_coarse_chunk_gives_the_published_merged_b2_byte_for_byte(tmp_path):
    coarse = chunk_dir(tmp_path, "coarse", B2, "24 32 64 128")
    code, out, err = run(["merge", "--out", tmp_path / "m", "--base", fixture_file(BASE), coarse])
    expected = fixture_file(B2)
    assert code == 0, err
    assert (tmp_path / "m" / expected.name).read_bytes() == expected.read_bytes()
    assert out.splitlines()[-1].endswith("keys [1, 2, 4, 8, 12, 16, 24, 32, 64, 128, 256, 1024, 2048]")


def test_extra_fields_pass_the_same_validator_that_refuses_a_missing_one(tmp_path):
    """The B2 entries carry waves_per_eu and SPLIT_K (the positive for the validator of M6)."""
    chunk = chunk_dir(tmp_path, "c", B2, "24")
    assert {"waves_per_eu", "SPLIT_K"} <= set(json.loads(fixture_file(chunk).read_text())["24"])
    assert run(["check", "--keys", "24", fixture_file(chunk)])[:2] == (0, "")


# ---- M3-M6, M9-M11, M15: the refusals ------------------------------------------------------------------------------------------------------------

def test_a_chunk_dir_without_its_json_is_a_missing_chunk_and_leaves_nothing_behind(tmp_path):
    empty = tmp_path / "empty"
    empty.mkdir()
    code, out, err = run(["merge", "--out", tmp_path / "m", *b1_chunks(tmp_path), empty])
    assert code == 2
    assert f"merge: missing chunk: {empty} has no E=*.json" in err.splitlines()
    assert not (tmp_path / "m").exists() or (list((tmp_path / "m").iterdir()) == [])


def test_a_chunk_dir_with_two_json_files_is_refused(tmp_path):
    chunk = chunk_dir(tmp_path, "c", B1, "1")
    (chunk / "E=1,N=1.json").write_text(fixture_file(chunk).read_text())
    code, out, err = run(["merge", "--out", tmp_path / "m", chunk])
    assert code == 2
    assert f"merge: {chunk} has 2 E=*.json files" in err


def test_a_duplicate_key_is_refused_naming_both_chunks(tmp_path):
    first, second = chunk_dir(tmp_path, "first", B1, "1 4"), chunk_dir(tmp_path, "second", B1, "4 12")
    code, out, err = run(["merge", "--out", tmp_path / "m", first, second])
    assert code == 2
    assert f"merge: duplicate key 4 in {second} (first in {first})" in err.splitlines()
    assert not (tmp_path / "m").exists()


def test_a_triton_version_mismatch_is_refused(tmp_path):
    first, second = chunk_dir(tmp_path, "first", B1, "1"), chunk_dir(tmp_path, "second", B1, "2", version="3.7.0")
    code, out, err = run(["merge", "--out", tmp_path / "m", first, second])
    assert code == 2
    assert f"merge: triton_version mismatch in {second}: 3.7.0 vs 3.8.0" in err.splitlines()


def test_a_missing_triton_version_is_refused(tmp_path):
    chunk = chunk_dir(tmp_path, "c", B1, "1", mutate=lambda data: data.pop("triton_version"))
    code, out, err = run(["merge", "--out", tmp_path / "m", chunk])
    assert code == 2
    assert f"merge: missing triton_version in {chunk}" in err.splitlines()


def test_a_config_missing_a_field_is_refused_naming_the_fields(tmp_path):
    def break_key_2(data):
        for field in ("num_warps", "num_stages"):
            del data["2"][field]
    chunk = chunk_dir(tmp_path, "c", B1, "1 2", mutate=break_key_2)
    code, out, err = run(["merge", "--out", tmp_path / "m", chunk])
    assert code == 2
    assert f"merge: key 2 in {chunk} misses ['num_stages', 'num_warps']" in err.splitlines()


def test_a_key_that_is_not_a_batch_size_is_refused(tmp_path):
    for number, bad in enumerate(("abc", "0", "-3", "04", "1.5")):
        def rename(data, bad=bad):
            data[bad] = data.pop("1")
        chunk = chunk_dir(tmp_path, f"bad-{number}", B1, "1", mutate=rename)
        code, out, err = run(["merge", "--out", tmp_path / "m", chunk])
        assert code == 2, bad
        assert f'merge: key "{bad}" in {chunk} is not a positive integer' in err.splitlines()


def test_a_key_twice_inside_one_file_is_refused(tmp_path):
    chunk = chunk_dir(tmp_path, "c", B1, "1 2")
    path = fixture_file(chunk)
    text = path.read_text()
    path.write_text(text.replace('    "2": {', '    "1": {"BLOCK_SIZE_M": 1},\n    "2": {', 1))
    code, out, err = run(["merge", "--out", tmp_path / "m", chunk])
    assert code == 2
    assert f"merge: duplicate key 1 in {chunk} (twice in the file)" in err.splitlines()


def test_a_file_that_is_not_json_or_not_an_object_is_refused(tmp_path):
    chunk = chunk_dir(tmp_path, "c", B1, "1")
    fixture_file(chunk).write_text("{not json")
    code, out, err = run(["merge", "--out", tmp_path / "m", chunk])
    assert code == 2
    assert f"merge: {fixture_file(chunk)}: not JSON (" in err
    fixture_file(chunk).write_text("[1, 2]\n")
    code, out, err = run(["merge", "--out", tmp_path / "m", chunk])
    assert code == 2
    assert f"merge: {fixture_file(chunk)}: not a JSON object" in err


def test_keys_not_delivered_are_refused_against_the_promise_and_an_explicit_set_wins(tmp_path):
    base = fixture_file(BASE)
    short = chunk_dir(tmp_path, "short", B2, "24 32 64", env='KEYS="24 32 64 128"\n')
    code, out, err = run(["merge", "--out", tmp_path / "m", "--base", base, short])
    assert code == 2
    assert ("merge: keys [1, 2, 4, 8, 12, 16, 24, 32, 64, 256, 1024, 2048] != expected "
            "[1, 2, 4, 8, 12, 16, 24, 32, 64, 128, 256, 1024, 2048]") in err.splitlines()
    code, out, err = run(["merge", "--out", tmp_path / "m2", "--base", base, "--expect", "1 2 4 8 12 16 24 32 64 256 1024 2048", short])
    assert code == 0, err


def test_a_chunk_that_delivers_a_key_it_did_not_promise_is_refused(tmp_path):
    chunk = chunk_dir(tmp_path, "c", B1, "1 2", env='KEYS="1"\n')
    code, out, err = run(["merge", "--out", tmp_path / "m", chunk])
    assert code == 2
    assert "merge: keys [1, 2] != expected [1]" in err.splitlines()


def test_a_chunk_without_a_promise_promises_what_it_holds(tmp_path):
    """No chunk.env and no --expect: the chunk's own keys are the expectation (scenario 1 relies on it)."""
    assert scenario_1(tmp_path)[0] == 0


def test_two_layers_can_never_be_merged_into_one_file(tmp_path):
    one, two = chunk_dir(tmp_path, "one", B1, "1"), chunk_dir(tmp_path, "two", B2, "24")
    code, out, err = run(["merge", "--out", tmp_path / "m", one, two])
    assert code == 2
    assert f"merge: file names differ: {fixture_file(B1).name} vs {fixture_file(B2).name}" in err.splitlines()


def test_a_chunk_tuned_on_another_image_is_refused_and_equal_images_merge(tmp_path):
    one = chunk_dir(tmp_path, "one", B1, "1", env="IMAGE=rocm/vllm:a\n")
    two = chunk_dir(tmp_path, "two", B1, "2", env='IMAGE="rocm/vllm:b"\n')
    code, out, err = run(["merge", "--out", tmp_path / "m", one, two])
    assert code == 2
    assert f"merge: IMAGE differs: {one} rocm/vllm:a vs {two} rocm/vllm:b" in err.splitlines()
    same = chunk_dir(tmp_path, "same", B1, "2", env="IMAGE=rocm/vllm:a\n")
    assert run(["merge", "--out", tmp_path / "m", one, same])[0] == 0


def test_every_identity_word_of_chunk_env_is_compared(tmp_path):
    module = load_module()
    for word in module.IDENTITY:
        one = chunk_dir(tmp_path, f"one-{word}", B1, "1", env=f"{word}=x\n")
        two = chunk_dir(tmp_path, f"two-{word}", B1, "2", env=f"{word}=y\n")
        code, out, err = run(["merge", "--out", tmp_path / f"m-{word}", one, two])
        assert code == 2, word
        assert f"merge: {word} differs: {one} x vs {two} y" in err.splitlines()


def test_a_chunk_env_that_is_not_the_grammar_is_refused_never_executed(tmp_path):
    chunk = chunk_dir(tmp_path, "c", B1, "1", env="not a pair\n", promise=False)
    code, out, err = run(["merge", "--out", tmp_path / "m", chunk])
    assert code == 2
    assert f"merge: {chunk / 'chunk.env'}:1: not KEY=value" in err.splitlines()
    chunk2 = chunk_dir(tmp_path, "c2", B1, "1", env='KEYS="1 x"\n')
    assert "is not a list of whitespace-separated batch sizes" in run(["merge", "--out", tmp_path / "m", chunk2])[2]


def test_a_chunk_env_without_keys_is_refused_so_the_promise_cannot_be_a_no_op(tmp_path):
    chunk = chunk_dir(tmp_path, "c", B1, "1", env="IMAGE=rocm/vllm:a\n", promise=False)
    code, out, err = run(["merge", "--out", tmp_path / "m", chunk])
    assert code == 2
    assert f"merge: {chunk / 'chunk.env'}: KEYS= is missing" in err.splitlines()


def test_an_identity_word_held_by_only_some_chunks_is_refused(tmp_path):
    one = chunk_dir(tmp_path, "one", B1, "1", env='KEYS="1"\nIMAGE=rocm/vllm:a\n')
    two = chunk_dir(tmp_path, "two", B1, "2", env='KEYS="2"\n')
    three = chunk_dir(tmp_path, "three", B1, "4")
    code, out, err = run(["merge", "--out", tmp_path / "m", one, two, three])
    assert code == 2
    lines = err.splitlines()
    assert f"merge: IMAGE is set in {one} but not in {two}" in lines
    assert f"merge: IMAGE is set in {one} but not in {three}" in lines
    assert run(["merge", "--out", tmp_path / "ok", one, chunk_dir(tmp_path, "four", B1, "2", env='KEYS="2"\nIMAGE=rocm/vllm:a\n')])[0] == 0


def test_a_base_file_does_not_count_as_a_chunk_that_lacks_an_identity_word(tmp_path):
    chunk = chunk_dir(tmp_path, "coarse", B2, "24 32 64 128", env='KEYS="24 32 64 128"\nIMAGE=rocm/vllm:a\n')
    code, out, err = run(["merge", "--out", tmp_path / "m", "--base", fixture_file(BASE), chunk])
    assert code == 0, err


def test_all_problems_are_reported_in_one_pass(tmp_path):
    first, second = chunk_dir(tmp_path, "first", B1, "1 4"), chunk_dir(tmp_path, "second", B1, "4", version="3.7.0")
    code, out, err = run(["merge", "--out", tmp_path / "m", first, second])
    assert code == 2
    assert [line for line in err.splitlines() if line.startswith("merge: ")] == [
        f"merge: triton_version mismatch in {second}: 3.7.0 vs 3.8.0",
        f"merge: duplicate key 4 in {second} (first in {first})"]


# ---- M12, M13, M17: the write ----------------------------------------------------------------------------------------------------------------------

def test_merges_are_append_only(tmp_path):
    chunks = b1_chunks(tmp_path)
    assert scenario_1(tmp_path, chunks)[0] == 0
    target = tmp_path / "m" / fixture_file(B1).name
    before = (target.read_bytes(), target.stat().st_mtime_ns)
    code, out, err = scenario_1(tmp_path, chunks)
    assert code == 2
    assert f"merge: {target} exists; merges are append-only, choose another --out" in err.splitlines()
    assert (target.read_bytes(), target.stat().st_mtime_ns) == before


def test_an_output_that_cannot_be_a_directory_is_refused_and_leaves_no_part(tmp_path):
    (tmp_path / "plain").write_text("a file")
    code, out, err = run(["merge", "--out", tmp_path / "plain", *b1_chunks(tmp_path)])
    assert code == 2
    assert "merge: " in err
    assert parts_under(tmp_path) == []
    assert (tmp_path / "plain").read_text() == "a file"


def test_a_part_with_a_dead_owner_is_swept_and_the_merge_goes_on(tmp_path):
    out = tmp_path / "m"
    out.mkdir()
    stale = out / f"{fixture_file(B1).name}.part-999999-1"
    stale.write_text("half")
    code, stdout, err = run(["merge", "--out", out, *b1_chunks(tmp_path)])
    assert code == 0, err
    assert f"merge: removed stale {stale} (owner 999999 gone)" in stdout.splitlines()
    assert (out / fixture_file(B1).name).read_bytes() == fixture_file(B1).read_bytes()
    assert parts_under(out) == []


def test_a_part_whose_pid_lives_on_with_other_start_ticks_is_a_dead_owner(tmp_path):
    out = tmp_path / "m"
    out.mkdir()
    stale = out / f"{fixture_file(B1).name}.part-{os.getpid()}-{int(own_ticks()) + 1}"
    stale.write_text("half")
    code, stdout, err = run(["merge", "--out", out, *b1_chunks(tmp_path)])
    assert code == 0, err
    assert f"merge: removed stale {stale} (owner {os.getpid()} gone)" in stdout.splitlines()
    assert parts_under(out) == []


def test_a_part_with_a_live_owner_is_a_refusal_and_stays_untouched(tmp_path):
    out = tmp_path / "m"
    out.mkdir()
    live = out / f"{fixture_file(B1).name}.part-{os.getpid()}-{own_ticks()}"
    live.write_text("being written")
    code, stdout, err = run(["merge", "--out", out, *b1_chunks(tmp_path)])
    assert code == 2
    assert f"merge: another merge is writing {live} (pid {os.getpid()})" in err.splitlines()
    assert live.read_text() == "being written"
    assert not (out / fixture_file(B1).name).exists()


def test_a_part_whose_owner_cannot_be_read_from_its_name_is_a_refusal(tmp_path):
    out = tmp_path / "m"
    out.mkdir()
    odd = out / f"{fixture_file(B1).name}.part-abc"
    odd.write_text("?")
    code, stdout, err = run(["merge", "--out", out, *b1_chunks(tmp_path)])
    assert code == 2
    assert f"merge: cannot tell the owner of {odd}" in err
    assert odd.exists()


def test_a_merge_killed_in_its_write_window_leaves_nothing_a_retry_trips_over(tmp_path):
    chunks = b1_chunks(tmp_path)
    out = tmp_path / "m"
    env = {**os.environ, NAME_ENV: "30"}
    proc = subprocess.Popen([sys.executable, "-I", str(LIB / "merge_moe.py"), "merge", "--out", str(out), *map(str, chunks)],
                            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        deadline = time.monotonic() + 15
        while not parts_under(tmp_path) and time.monotonic() < deadline:
            time.sleep(0.05)
        assert len(parts_under(tmp_path)) == 1, "the merge never reached its write window"
        assert not (out / fixture_file(B1).name).exists(), "nothing is final inside the window"
    finally:
        proc.send_signal(signal.SIGKILL)
        proc.wait(timeout=10)
    assert len(parts_under(out)) == 1, "the kill leaves the part, and it names its owner"
    code, stdout, err = run(["merge", "--out", out, *chunks])
    assert code == 0, err
    assert (out / fixture_file(B1).name).read_bytes() == fixture_file(B1).read_bytes()
    assert parts_under(out) == []


def test_two_merges_started_at_once_into_one_out_never_make_two_outputs_or_a_half_file(tmp_path):
    chunks = b1_chunks(tmp_path)
    out = tmp_path / "m"
    env = {**os.environ, NAME_ENV: "2"}
    command = [sys.executable, "-I", str(LIB / "merge_moe.py"), "merge", "--out", str(out), *map(str, chunks)]
    procs = [subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for _ in range(2)]
    results = [(proc.wait(timeout=60), proc.stderr.read()) for proc in procs]
    for proc in procs:
        proc.stdout.close()
        proc.stderr.close()
    assert sorted(code for code, _ in results) == [0, 2], results
    loser = next(text for code, text in results if code == 2)
    assert "another merge is writing" in loser or "exists" in loser
    assert [path.name for path in out.iterdir()] == [fixture_file(B1).name]
    assert (out / fixture_file(B1).name).read_bytes() == fixture_file(B1).read_bytes()


def test_without_hard_links_the_write_still_never_replaces_an_existing_file(tmp_path, monkeypatch):
    """The atomic no-clobber step is os.link; where a folder cannot link, the fallback checks and replaces (its residual window is in the header)."""
    module = load_module()

    def no_links(*_args, **_kwargs):
        raise OSError(errno.EPERM, "links not supported")
    monkeypatch.setattr(module.os, "link", no_links)
    chunks = b1_chunks(tmp_path)
    assert module.main(["merge", "--out", str(tmp_path / "m"), *map(str, chunks)]) == 0
    target = tmp_path / "m" / fixture_file(B1).name
    assert target.read_bytes() == fixture_file(B1).read_bytes()
    assert parts_under(tmp_path / "m") == []
    assert module.main(["merge", "--out", str(tmp_path / "m"), *map(str, chunks)]) == 2


def test_publishing_over_an_existing_name_is_refused_and_the_file_is_untouched(tmp_path):
    """The deterministic form of the race in the test above: the move itself, with the target already there, never replaces it."""
    module = load_module()
    target, part = tmp_path / "E=1.json", tmp_path / "E=1.json.part-1-1"
    target.write_text("first")
    part.write_text("second")
    with pytest.raises(module.InputError, match="exists; merges are append-only"):
        module.publish(part, target)
    assert target.read_text() == "first"


def forced_fallback(monkeypatch):
    module = load_module()

    def no_links(*_args, **_kwargs):
        raise OSError(errno.EPERM, "links not supported")
    monkeypatch.setattr(module.os, "link", no_links)
    return module


def test_in_the_fallback_a_live_claim_stops_a_second_merge_before_it_replaces_anything(tmp_path, monkeypatch, capsys):
    module = forced_fallback(monkeypatch)
    out = tmp_path / "m"
    out.mkdir()
    claim = out / f"{fixture_file(B1).name}.claim"
    claim.write_text(f"{os.getpid()} {own_ticks()}\n")
    assert module.main(["merge", "--out", str(out), *map(str, b1_chunks(tmp_path))]) == 2
    assert f"merge: another merge is writing {claim} (pid {os.getpid()})" in capsys.readouterr().err.splitlines()
    assert not (out / fixture_file(B1).name).exists() and claim.exists()


def test_in_the_fallback_a_claim_with_a_dead_owner_is_swept_and_no_claim_is_left(tmp_path, monkeypatch, capsys):
    module = forced_fallback(monkeypatch)
    out = tmp_path / "m"
    out.mkdir()
    claim = out / f"{fixture_file(B1).name}.claim"
    claim.write_text("999999 1\n")
    assert module.main(["merge", "--out", str(out), *map(str, b1_chunks(tmp_path))]) == 0
    assert f"merge: removed stale {claim} (owner 999999 gone)" in capsys.readouterr().out.splitlines()
    assert (out / fixture_file(B1).name).read_bytes() == fixture_file(B1).read_bytes()
    assert sorted(path.name for path in out.iterdir()) == [fixture_file(B1).name]


# ---- M14: check ------------------------------------------------------------------------------------------------------------------------------------------------

def test_check_accepts_a_complete_chunk_file_and_names_the_first_problem_of_a_bad_one(tmp_path):
    chunk = fixture_file(chunk_dir(tmp_path, "c", B2, "24 32 64 128"))
    assert run(["check", "--keys", "24 32 64 128", chunk]) == (0, "", "")
    code, out, err = run(["check", "--keys", "24 32 64 128 256", chunk])
    assert (code, out.splitlines()) == (1, ["keys [24, 32, 64, 128] != expected [24, 32, 64, 128, 256]"])

    def drop_field(data):
        del data["24"]["BLOCK_SIZE_K"]
    bad = fixture_file(chunk_dir(tmp_path, "bad", B2, "24 32", mutate=drop_field))
    code, out, err = run(["check", "--keys", "24 32", bad])
    assert (code, out.splitlines()) == (1, [f"key 24 in {bad} misses ['BLOCK_SIZE_K']"])
    bad.write_text("{nope")
    code, out, err = run(["check", "--keys", "24 32", bad])
    assert code == 1 and out.startswith(f"{bad}: not JSON (")
    code, out, err = run(["check", "--keys", "24 32", tmp_path / "absent.json"])
    assert code == 1 and "cannot read" in out


def test_check_refuses_a_key_list_that_is_not_batch_sizes(tmp_path):
    chunk = fixture_file(chunk_dir(tmp_path, "c", B1, "1"))
    code, out, err = run(["check", "--keys", "1 x", chunk])
    assert code == 2
    assert '--keys "1 x" is not a list of whitespace-separated batch sizes, e.g. "8 16 24"' in err


# ---- M16: the catalogue ------------------------------------------------------------------------------------------------------------------------------------

def test_every_command_has_a_covered_row_in_the_flow_catalogue():
    rows = catalogue_rows("lib/merge_moe.py", load_module().build_parser())
    assert sorted(rows) == ["check", "merge"]
    for command, found in rows.items():
        assert found, f"lib/merge_moe.py {command} has no row in research/module_tests.md"
        assert all("covered" in row for row in found), command


class FakeStat:
    """What `Path('/proc/<pid>/stat')` is in proc_ticks: an object whose read_text gives a scripted line."""

    def __init__(self, text):
        self.text = text

    def read_text(self):
        return self.text


def test_proc_ticks_reads_field_22_after_the_last_bracket_and_knows_nothing_from_an_unreadable_line(monkeypatch):
    """An owner whose /proc line cannot be read is 'not known' (None), which the sweep already refuses safely: never an exception out of the sweep."""
    module = load_module()
    fields = ["S"] + [str(n) for n in range(1, 40)]  # after the name: field 3 is the state, field 22 is the 20th word (index 19)
    line = "123 (a name) with) brackets) " + " ".join(fields) + "\n"
    cases = {
        line: fields[19],
        "123 (a name) " + "  ".join(fields) + "\n": fields[19],  # a doubled space must not shift the fields
        "123 (short) S 1 2\n": None,  # fewer fields than 22
        "123 no bracket at all": None,
        "": None,
    }
    for text, want in cases.items():
        monkeypatch.setattr(module, "Path", lambda _path, text=text: FakeStat(text))
        assert module.proc_ticks(1) == want, repr(text)
