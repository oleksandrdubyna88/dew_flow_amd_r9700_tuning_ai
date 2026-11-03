#!/usr/bin/env python3
"""The check and the merge of MoE tuning chunk files (E2.S1, decisions 1 and 2).

  merge_moe.py check --keys "<batch sizes>" <chunk file>
  merge_moe.py merge --out <dir> [--base <file>] [--expect "<batch sizes>"] <chunk dir> [<chunk dir> ...]

A chunk file is `{"triton_version": "<v>", "<batch size>": {<config>}, ...}` (benchmark_moe.py `save_configs`). A chunk dir holds exactly one
`E=*.json` (its name comes from vLLM and is read back, never typed) and, when present, a `chunk.env` with `KEYS=` (the batch sizes the chunk
promised) and the identity words IMAGE, MODEL_DIR, DTYPE and LAYER. The file is parsed in ONE place, so `check` (the validity of one chunk file,
used by the records of S2) and `merge` cannot disagree.

check: exit 0, or 1 with the FIRST problem on stdout. merge: exit 0, or 2 with every problem found, one `merge: ` line each on stderr. The output
is `<out>/<NAME>`, the sources' key order (`json.dumps(indent=4)` and a newline), written to `<NAME>.part-<pid>-<start ticks>` (the part names
its writer, as the marker of a worker does) and moved to its name by `os.link` (atomic, and it fails when the name exists). A merge never
replaces a file: every merge is a new file, and which file a server reads is a separate, explicit step (`activate`).
A part (or claim) whose owner is gone (no such pid, or other start ticks) is removed before a write; a part whose owner lives is a refusal.

Fallback: in a folder that cannot make hard links the write takes `<NAME>.claim` (created with O_EXCL, holding the owner's pid and start ticks),
checks that the name is free, replaces, and removes the claim. A claim whose owner is gone is swept like a part; one whose owner lives is a
refusal. Residual: the claim and the part are removed by their owner only, so a writer killed between the two leaves them for the next sweep.
Test knob (environment only): R9700_TEST_MERGE_HOLD_S sleeps that many seconds between the part write and the move, so a test can kill the
writer inside the window. Python >= 3.10, standard library only.
"""
import argparse
import json
import os
import re
import sys
import time
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # lib/moekeys.py beside this file (`python3 -I` does not put the script's folder on the path)
import moekeys  # noqa: E402

# The fields every config must hold; more are allowed (`waves_per_eu`, `SPLIT_K`). Typed once: merge_moe.py line 12 of the published script.
FIELDS = frozenset({"BLOCK_SIZE_M", "BLOCK_SIZE_N", "BLOCK_SIZE_K", "GROUP_SIZE_M", "num_warps", "num_stages"})
IDENTITY = ("IMAGE", "MODEL_DIR", "DTYPE", "LAYER")  # the words of chunk.env that must be equal between chunks
CHUNK_GLOB = "E=*.json"
HOLD_ENV = "R9700_TEST_MERGE_HOLD_S"
CLAIM_STALE_ENV = "R9700_TEST_CLAIM_STALE_S"  # test knob: the age (s) after which an empty or unreadable claim counts as left behind
CLAIM_STALE_S = 60
KEY = re.compile(r"[1-9][0-9]*")
ENV_LINE = re.compile(r"([A-Z][A-Z0-9_]*)=(.*)")
PART = re.compile(r"\.part-([0-9]+)-([0-9]+)$")


class InputError(Exception):
    """A refusal that is not a list of problems: the message is printed on stderr and the exit code is 2."""


@dataclass(frozen=True)
class Source:
    label: str  # what a message calls it: the chunk dir, or the file for a base and for `check`
    name: str  # the file name (E=....json)
    version: object
    configs: dict  # {batch size: config}
    promise: object  # the KEYS of chunk.env as a tuple, or None
    env: dict
    base: bool = False  # a base file is not a chunk: it has no chunk.env and takes no part in the identity words


# ---------- reading one file ----------
def key_list(text, what):
    """The batch sizes of an argument, sorted (the grammar is lib/moekeys.py's, shared by both programs); anything else is a refusal."""
    try:
        return moekeys.key_list(text, what)
    except moekeys.KeyListError as error:
        raise InputError(str(error)) from None


def pairs_hook(duplicates):
    def hook(pairs):
        seen = {}
        for key, value in pairs:
            if key in seen:
                duplicates.append(key)
            seen[key] = value
        return seen
    return hook


def read_json(path):
    """(the top-level object, the keys written twice, []) or (None, [], [the problem])."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        return None, [], [f"{path}: cannot read ({getattr(error, 'strerror', None) or error})"]
    duplicates = []
    try:
        data = json.loads(text, object_pairs_hook=pairs_hook(duplicates))
    except ValueError as error:
        return None, [], [f"{path}: not JSON ({error})"]
    if not isinstance(data, dict):
        return None, [], [f"{path}: not a JSON object"]
    return data, duplicates, []


def entry_problems(label, data):
    version = data.get("triton_version")
    problems = []
    if version is None:
        problems.append(f"missing triton_version in {label}")
    elif not isinstance(version, str) or not version:
        problems.append(f"triton_version in {label} is not a text")
    for key, config in data.items():
        if key == "triton_version":
            continue
        if not KEY.fullmatch(key):
            problems.append(f'key "{key}" in {label} is not a positive integer')
        elif not isinstance(config, dict):
            problems.append(f"key {key} in {label} is not an object")
        elif not FIELDS <= config.keys():
            problems.append(f"key {key} in {label} misses {sorted(FIELDS - config.keys())}")
    return problems


def load_file(path, label, env=None, promise=None, base=False):
    """(Source or None, [problems]) of one chunk file. A Source is returned even when its entries have problems, so the key sets stay complete."""
    data, duplicates, problems = read_json(path)
    if data is None:
        return None, problems
    problems = [f"duplicate key {key} in {label} (twice in the file)" for key in dict.fromkeys(duplicates)] + entry_problems(label, data)
    configs = {int(key): config for key, config in data.items() if KEY.fullmatch(key) and isinstance(config, dict)}
    return Source(label, path.name, data.get("triton_version"), configs, promise, env or {}, base), problems


# ---------- reading a chunk dir ----------
def read_env(path):
    """({word: value}, [problems]) of a chunk.env: KEY=value lines, bare or in double quotes, never sourced."""
    env, problems = {}, []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        match = ENV_LINE.fullmatch(line.strip())
        if not match:
            problems.append(f"{path}:{number}: not KEY=value")
            continue
        value = match[2]
        env[match[1]] = value[1:-1] if len(value) >= 2 and value[0] == value[-1] == '"' else value
    return env, problems


def chunk_env(directory):
    """(env, promise, [problems]) of the chunk.env of a chunk dir, when there is one."""
    path = directory / "chunk.env"
    if not path.is_file():
        return {}, None, []
    try:
        env, problems = read_env(path)
    except (OSError, UnicodeDecodeError) as error:
        return {}, None, [f"{path}: cannot read ({getattr(error, 'strerror', None) or error})"]
    if "KEYS" not in env:  # a chunk.env that promises nothing would make the promise a no-op: refused (no chunk.env at all is another case)
        return env, None, [*problems, f"{path}: KEYS= is missing"]
    try:
        return env, tuple(key_list(env["KEYS"], f"{path}: KEYS")), problems
    except InputError as error:
        return env, None, [*problems, str(error)]


def load_chunk_dir(label):
    directory = Path(label)
    if not directory.is_dir():
        return None, [f"missing chunk: {label} is not a directory"]
    found = sorted(directory.glob(CHUNK_GLOB))
    if len(found) != 1:
        return None, [f"missing chunk: {label} has no {CHUNK_GLOB}" if not found else
                      f"{label} has {len(found)} {CHUNK_GLOB} files: {', '.join(path.name for path in found)}"]
    env, promise, env_problems = chunk_env(directory)
    source, problems = load_file(found[0], label, env, promise)
    return source, env_problems + problems


# ---------- putting the sources together ----------
def identity_problems(sources):
    """An identity word must be held by every chunk or by none, and be equal where held (a base file is not a chunk)."""
    chunks, problems = [source for source in sources if not source.base], []
    for word in IDENTITY:
        holders = [source for source in chunks if word in source.env]
        if not holders:
            continue
        problems += [f"{word} is set in {holders[0].label} but not in {other.label}" for other in chunks if word not in other.env]
        problems += [f"{word} differs: {holders[0].label} {holders[0].env[word]} vs {other.label} {other.env[word]}"
                     for other in holders[1:] if other.env[word] != holders[0].env[word]]
    return problems


def duplicate_problems(sources):
    owners, problems = {}, []
    for source in sources:
        for bs in source.configs:
            if bs in owners:
                problems.append(f"duplicate key {bs} in {source.label} (first in {owners[bs]})")
            else:
                owners[bs] = source.label
    return problems


def shape_problems(sources):
    """The file names and the triton versions must be one, measured against the first source."""
    first, problems = sources[0], []
    for other in sources[1:]:
        if other.name != first.name:
            problems.append(f"file names differ: {first.name} vs {other.name}")
        if None not in (first.version, other.version) and other.version != first.version:
            problems.append(f"triton_version mismatch in {other.label}: {other.version} vs {first.version}")
    return problems


def expected_keys(sources, explicit):
    """--expect when given; else the base's keys plus every chunk's promise (what the chunk holds when it promised nothing)."""
    if explicit is not None:
        return explicit
    return sorted({bs for source in sources for bs in (source.promise if source.promise is not None else source.configs)})


def merged_text(sources):
    configs = {bs: config for source in sources for bs, config in source.configs.items()}
    return json.dumps({"triton_version": sources[0].version} | {str(bs): configs[bs] for bs in sorted(configs)}, indent=4) + "\n"


# ---------- the write ----------
def proc_ticks(pid):
    """Field 22 of /proc/<pid>/stat (the start time), cut after the LAST `)` because the command name may hold one; None when there is no such process or the line cannot be read."""
    try:
        stat = Path(f"/proc/{pid}/stat").read_text()
        return stat[stat.rindex(")") + 2:].split()[19]
    except (OSError, IndexError, ValueError):  # gone, or a line that cannot be read: not known, which the sweep refuses safely
        return None


def claim_owner(claim):
    """(pid, ticks) written in a claim file, or None when it cannot be read."""
    try:
        pid, ticks = claim.read_text().split()
    except (OSError, ValueError):
        return None
    return (pid, ticks) if pid.isdigit() and ticks.isdigit() else None


def claim_stale_after():
    """Seconds after which a claim that names no owner is taken for one left by a writer killed between the O_EXCL create and the write (60; the test knob scales it)."""
    try:
        return float(os.environ.get(CLAIM_STALE_ENV) or CLAIM_STALE_S)
    except ValueError:
        return CLAIM_STALE_S


def claim_left_behind(claim):
    """True for a claim that is empty or unparseable AND older than the limit: no live writer is between its create and its write for that long."""
    try:
        return time.time() - claim.stat().st_mtime > claim_stale_after()
    except OSError:
        return False


def take_claim(claim):
    """The fallback's lock: `<NAME>.claim`, created with O_EXCL, holding `<pid> <start ticks>`. A claim of a dead owner is swept (once); a live or unreadable one is a refusal."""
    for _attempt in range(2):
        try:
            descriptor = os.open(claim, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
        except FileExistsError:
            owner = claim_owner(claim)
            if owner is None:
                if claim_left_behind(claim):
                    claim.unlink(missing_ok=True)
                    continue
                raise InputError(f"merge: cannot tell the owner of {claim}; remove it by hand") from None
            if proc_ticks(owner[0]) == owner[1]:
                raise InputError(f"merge: another merge is writing {claim} (pid {owner[0]})") from None
            claim.unlink(missing_ok=True)
            continue
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(f"{os.getpid()} {proc_ticks('self')}\n")
        return
    raise InputError(f"merge: another merge is writing {claim}")


def sweep_claim(out, name):
    """The line printed when a claim of a dead owner is removed before a write (a live one is left: `take_claim` refuses it)."""
    claim = out / f"{name}.claim"
    owner = claim_owner(claim) if claim.exists() else None
    if owner is None and claim.exists() and claim_left_behind(claim):
        claim.unlink(missing_ok=True)
        return [f"merge: removed stale {claim} (empty or unreadable, older than {claim_stale_after():g} s)"]
    if owner is None or proc_ticks(owner[0]) == owner[1]:
        return []
    claim.unlink(missing_ok=True)
    return [f"merge: removed stale {claim} (owner {owner[0]} gone)"]


def sweep_parts(out, name):
    """Remove the parts of dead owners (the lines it prints); a part of a live owner, or one whose name tells no owner, is a refusal."""
    lines = sweep_claim(out, name)
    for part in sorted(path for path in out.iterdir() if path.name.startswith(f"{name}.part-")):
        match = PART.search(part.name)
        if not match:
            raise InputError(f"merge: cannot tell the owner of {part} from its name; remove it by hand")
        pid, ticks = match[1], match[2]
        if proc_ticks(pid) == ticks:
            raise InputError(f"merge: another merge is writing {part} (pid {pid})")
        part.unlink(missing_ok=True)
        lines.append(f"merge: removed stale {part} (owner {pid} gone)")
    return lines


def exists_error(target):
    return InputError(f"merge: {target} exists; merges are append-only, choose another --out")


def publish(part, target):
    """Move the part to its name without ever replacing a file: os.link fails when the name exists."""
    try:
        os.link(part, target)
    except FileExistsError as error:
        raise exists_error(target) from error
    except OSError:  # a folder that cannot link: under a claim (O_EXCL), check, then replace
        claim = target.with_name(f"{target.name}.claim")
        take_claim(claim)
        try:
            if target.exists():
                raise exists_error(target) from None
            os.replace(part, target)
        finally:
            claim.unlink(missing_ok=True)
        return
    part.unlink()


def write_output(out, name, text):
    target = out / name
    part = out / f"{name}.part-{os.getpid()}-{proc_ticks('self')}"
    try:
        descriptor = os.open(part, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        time.sleep(float(os.environ.get(HOLD_ENV) or 0))
        publish(part, target)
    except BaseException:
        part.unlink(missing_ok=True)
        raise


def prepare_out(out, name):
    """Refuse an existing target, make the folder, sweep the dead parts; returns the sweep's lines."""
    if out.exists() and not out.is_dir():
        raise InputError(f"merge: {out} is not a directory")
    if (out / name).exists():
        raise exists_error(out / name)
    try:
        out.mkdir(parents=True, exist_ok=True)
    except OSError as error:
        raise InputError(f"merge: cannot make {out} ({error.strerror or error})") from error
    return sweep_parts(out, name)


# ---------- commands ----------
def load_inputs(base, chunk_dirs):
    """([sources, base first], [problems], whether every input could be read)."""
    sources, problems, complete = [], [], True
    loaded = [load_file(Path(base), base, base=True)] if base else []
    loaded += [load_chunk_dir(label) for label in chunk_dirs]
    for source, found in loaded:
        problems += found
        if source is None:
            complete = False
        else:
            sources.append(source)
    return sources, problems, complete


def merge_problems(args):
    """(sources, every problem of the inputs, in one pass)."""
    explicit = key_list(args.expect, "merge: --expect") if args.expect is not None else None
    sources, problems, complete = load_inputs(args.base, args.chunk_dirs)
    if sources:
        problems += shape_problems(sources) + duplicate_problems(sources) + identity_problems(sources)
    if complete:
        got, expected = sorted({bs for source in sources for bs in source.configs}), expected_keys(sources, explicit)
        if got != expected:
            problems.append(f"keys {got} != expected {expected}")
    return sources, problems


def cmd_merge(args):
    sources, problems = merge_problems(args)
    if problems:
        print("\n".join(f"merge: {problem}" for problem in problems), file=sys.stderr)
        return 2
    out = Path(args.out)
    for line in prepare_out(out, sources[0].name):
        print(line)
    try:
        write_output(out, sources[0].name, merged_text(sources))
    except OSError as error:
        raise InputError(f"merge: cannot write {out / sources[0].name} ({error.strerror or error})") from error
    print(f"wrote {out / sources[0].name}: triton {sources[0].version}, keys {sorted({bs for s in sources for bs in s.configs})}")
    return 0


def cmd_check(args):
    keys = key_list(args.keys, "--keys")
    source, problems = load_file(Path(args.file), args.file)
    if source is not None and not problems and sorted(source.configs) != keys:
        problems = [f"keys {sorted(source.configs)} != expected {keys}"]
    if problems:
        print(problems[0])
        return 1
    return 0


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    check = sub.add_parser("check", help="is this file a valid chunk file with exactly these batch sizes")
    check.add_argument("--keys", required=True)
    check.add_argument("file")
    check.set_defaults(fn=cmd_check)
    merge = sub.add_parser("merge", help="chunk dirs (and a base file) into one new file under --out")
    merge.add_argument("--out", required=True)
    merge.add_argument("--base")
    merge.add_argument("--expect")
    merge.add_argument("chunk_dirs", nargs="+", metavar="chunk_dir")
    merge.set_defaults(fn=cmd_merge)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        return args.fn(args)
    except InputError as error:
        print(error, file=sys.stderr)
        return 2
    except Exception as error:  # exit 1 of `check` means "not valid": nothing unexpected may look like it
        print(f"merge_moe.py: unexpected {type(error).__name__}: {str(error).splitlines()[0] if str(error) else ''}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
