#!/usr/bin/env python3
"""The run identity of a series, and the check of the quality files of a record (E1.S3, decisions 1, 2 and 3).

  fingerprint.py build <inputs dir> --out <file> [--probe-from <stored>]
                                                     assemble the components from the files lib/series.sh wrote, hash them, write the document
                                                     (--probe-from: the listing and generation config hashes come from <stored>)
  fingerprint.py compare [--merge] <stored> <new>    one line per differing leaf; a new arm and a larger round count are extensions (exit 0)
  fingerprint.py show <file> <path>                  one leaf: a string or a number bare, a list on one line, a dict as its keys
  fingerprint.py check-quality <prompts> <gsm8k>     the round-1 files of a record: 20 results, GSM8K summary n 200

Bash gathers the inputs and writes one file per component group (no JSON is built in bash); this file builds the JSON. The document is
{"version": 1, "sha256": <hex>, "components": {...}} and the hash is over the canonical form of `components`:
json.dumps(components, sort_keys=True, separators=(",", ":"), ensure_ascii=True).

Inputs directory: config.env (R9700_<KEY>=<value> lines, the config_resolved output), arms/<arm>.args|.env|.mounts (one word per line),
patches (<path> <64 hex>), listing (the model's file names and sizes), genconfig (<path> <64 hex>), tools (<key> <64 hex>), series
(base=, rounds=, prefill_lens=).

Exit codes: 0 ok (compare: the same, or only new arms), 1 compare found a difference or check-quality a problem, 2 an input or a
file that cannot be used (one line starting `fingerprint:`). Python >= 3.10, standard library only.
"""
import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path

VERSION = 1
HEX64 = r"[0-9a-f]{64}"
ABSENT = "<absent>"
QUALITY_PROMPTS = 20  # the number of prompts of lib/harness.py `collect`
QUALITY_GSM8K_N = 200  # `--n 200` of lib/series.sh

# The workload: typed here ONCE. bench: lib/bench.sh (random 1024 input, 512 output, concurrency 1 with 6 prompts and 4 with 12, seeds 1-3);
# prefill: lib/bench.sh prefill_run, speed_A.sh lines 30-37 of the old script (128 output tokens, 3 prompts at c=1, seeds 1-3).
WORKLOAD_BENCH = {"input": 1024, "output": 512, "prompts": {"1": 6, "4": 12}, "seeds": [1, 2, 3]}
WORKLOAD_PREFILL = {"output": 128, "prompts": 3, "seeds": [1, 2, 3]}

# config.env keys -> (component name, type); every one is required
MODEL_KEYS = {
    "MODEL_DIR": ("dir", str), "SERVED_NAME": ("served_name", str), "MAX_MODEL_LEN": ("max_model_len", int),
    "MAX_NUM_SEQS": ("max_num_seqs", int), "GPU_MEM_UTIL": ("gpu_mem_util", str), "EXTRA_SERVE_ARGS": ("extra_serve_args", str),
    "TUNED_CONFIG_DIR": ("tuned_config_dir", str), "MOUNTS": ("mounts", str),
}
OTHER_KEYS = ("IMAGE", "CONTAINER_PREFIX", "GSM8K_DATA")


class InputError(Exception):
    """An input or a file that cannot be used: one `fingerprint:` line and exit 2."""


def fail(where, text):
    raise InputError(f"fingerprint: {where}: {text}" if where else f"fingerprint: {text}")


# ---------- reading the inputs ----------
def read_text(folder, name):
    path = folder / name
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(name, "the input file is missing")
    except (OSError, UnicodeDecodeError) as error:
        fail(name, f"cannot be read ({getattr(error, 'strerror', None) or error})")


def numbered(text):
    """(line number, text) of every non-blank line."""
    return [(n, line) for n, line in enumerate(text.splitlines(), 1) if line.strip()]


def hex_pairs(folder, name, shape):
    """{path: 64 hex} from lines `<path> <64 hex>`; the path may hold spaces, the hash is the last word."""
    found = {}
    for n, line in numbered(read_text(folder, name)):
        match = re.fullmatch(rf"(.+) ({HEX64})", line)
        if not match:
            fail(f"{name}:{n}", f'expected "{shape}"')
        found[match[1]] = match[2]
    return found


def read_config(folder):
    values = {}
    for n, line in numbered(read_text(folder, "config.env")):
        match = re.fullmatch(r"R9700_([A-Z0-9_]+)=(.*)", line)
        if not match:
            fail(f"config.env:{n}", 'expected "R9700_<KEY>=<value>"')
        values[match[1]] = match[2]
    for key in [*MODEL_KEYS, *OTHER_KEYS]:
        if key not in values:
            fail("config.env", f"R9700_{key} is missing")
        if key in MODEL_KEYS and MODEL_KEYS[key][1] is int and not re.fullmatch(r"[0-9]+", values[key]):
            fail("config.env", f'expected "R9700_{key}=<number>", got "{values[key]}"')
    return values


def read_series(folder):
    values = {}
    for n, line in numbered(read_text(folder, "series")):
        match = re.fullmatch(r"(base|rounds|prefill_lens)=(.*)", line)
        if not match:
            fail(f"series:{n}", 'expected "base=<arm>", "rounds=<number>" or "prefill_lens=<numbers>"')
        if match[1] == "rounds" and not re.fullmatch(r"[0-9]+", match[2]):
            fail(f"series:{n}", f'expected "rounds=<number>", got "{match[2]}"')
        if match[1] == "prefill_lens" and not re.fullmatch(r"[0-9]+( [0-9]+)*", match[2]):
            fail(f"series:{n}", f'expected "prefill_lens=<numbers separated by spaces>", got "{match[2]}"')
        values[match[1]] = match[2]
    for key in ("base", "rounds", "prefill_lens"):
        if key not in values:
            fail("series", f"{key}= is missing")
    return values


def read_arms(folder):
    """{arm: {"args": [...], "env": [...], "mounts": [...]}}, one word per line in each file."""
    arms_dir = folder / "arms"
    names = sorted(p.name[: -len(".args")] for p in arms_dir.glob("*.args")) if arms_dir.is_dir() else []
    if not names:
        fail("arms", "no arm: the input folder holds no arms/<arm>.args")
    arms = {}
    for name in names:
        arms[name] = {kind: [w for w in read_text(folder, f"arms/{name}.{kind}").split()] for kind in ("args", "env", "mounts")}
    return arms


def build_components(folder, probe=None):
    """The components of an inputs folder. With `probe` (a stored document) the two probed hashes, the model listing and the generation config, come
    from it: the folder then needs neither file (the worker's re-check does not run the throwaway container)."""
    config, series = read_config(folder), read_series(folder)
    arms = read_arms(folder)
    if series["base"] not in arms:
        fail("series", f'base "{series["base"]}" is not one of the arms ({" ".join(arms)})')
    model = {name: kind(config[key]) for key, (name, kind) in MODEL_KEYS.items()}
    if probe is None:
        model["listing"] = hashlib.sha256(read_text(folder, "listing").encode()).hexdigest()
        hex_pairs(folder, "genconfig", "<path> <64 hex>")  # the shape is checked; the component is the hash of the whole file
        genconfig = hashlib.sha256(read_text(folder, "genconfig").encode()).hexdigest()
    else:
        model["listing"] = probe["components"].get("model", {}).get("listing")
        genconfig = probe["components"].get("genconfig")
    return {
        "model": model,
        "genconfig": genconfig,
        "image": config["IMAGE"],
        "patches": hex_pairs(folder, "patches", "<path> <64 hex>"),
        "arms": arms,
        "base": series["base"],
        "workload": {
            "bench": WORKLOAD_BENCH,
            "prefill": {"lens": [int(n) for n in series["prefill_lens"].split()], **WORKLOAD_PREFILL},
            "quality": {"prompts": QUALITY_PROMPTS, "gsm8k_n": QUALITY_GSM8K_N},
        },
        "rounds": int(series["rounds"]),
        "tools": hex_pairs(folder, "tools", "<key> <64 hex>"),
        "machine": {"container_prefix": config["CONTAINER_PREFIX"], "gsm8k_data": config["GSM8K_DATA"]},
    }


# ---------- the document ----------
def canonical_sha(components):
    text = json.dumps(components, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(text.encode()).hexdigest()


def document_of(components):
    return {"version": VERSION, "sha256": canonical_sha(components), "components": components}


def write_atomic(path, document):
    """<path>.part, then os.replace: a reader sees the old file or the whole new one; a failure leaves no part file."""
    part = f"{path}.part"
    try:
        with open(part, "w", encoding="utf-8") as handle:
            json.dump(document, handle, indent=1)
            handle.write("\n")
        os.replace(part, path)
    except OSError as error:
        try:
            os.remove(part)
        except OSError:
            pass
        fail("", f"cannot write {path}: {error.strerror or error}")


def read_document(path):
    try:
        document = json.loads(Path(path).read_text(encoding="utf-8"))
    except FileNotFoundError:
        fail(str(path), "the file is missing")
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(str(path), f"cannot be read as JSON ({getattr(error, 'strerror', None) or error})")
    if not isinstance(document, dict) or not isinstance(document.get("components"), dict):
        fail(str(path), "is not a fingerprint document (no components)")
    if document.get("version") != VERSION:
        fail(str(path), f"is version {document.get('version')!r}; this program reads version {VERSION}")
    if document.get("sha256") != canonical_sha(document["components"]):
        fail(str(path), "the stored digest does not match the digest of its components (the file was edited or damaged): it cannot be trusted as the identity of a series")
    return document


# ---------- compare ----------
def leaves(node, prefix=()):
    """{path tuple: value}; a dict is walked, everything else (a list too) is one leaf."""
    if not isinstance(node, dict):
        return {prefix: node}
    found = {}
    for key, value in node.items():
        found.update(leaves(value, (*prefix, key)))
    return found


def shown(value):
    """A string bare, anything else as compact JSON, an absent side as <absent>."""
    if value is None:
        return ABSENT
    return value if isinstance(value, str) else json.dumps(value, separators=(",", ":"))


def rounds_extended(old, new):
    """True when the new document asks for MORE rounds: a record depends on its own arm, round, model, image, patches and workload, not on how many
    rounds the series was asked for, so the rounds already recorded stay valid (the same reason as for a new arm). Fewer rounds is a difference."""
    before, after = old["components"].get("rounds"), new["components"].get("rounds")
    return isinstance(before, int) and isinstance(after, int) and after > before


def compare_lines(old, new):
    """(difference lines, the arms that are new): arms are compared per name; a new arm is an extension, an arm left out is not a difference."""
    old_leaves, new_leaves = leaves(old["components"]), leaves(new["components"])
    old_arms = {path[1] for path in old_leaves if path[0] == "arms" and len(path) > 1}
    new_arms = {path[1] for path in new_leaves if path[0] == "arms" and len(path) > 1}
    lines = []
    for path in sorted({*old_leaves, *new_leaves}, key=lambda p: ".".join(p)):
        if path[0] == "arms" and len(path) > 1 and (path[1] not in old_arms or path[1] not in new_arms):
            continue
        if path == ("rounds",) and rounds_extended(old, new):
            continue
        before, after = old_leaves.get(path), new_leaves.get(path)
        if before != after:
            lines.append(f"fingerprint differs: {'.'.join(path)}: {shown(before)} -> {shown(after)}")
    return lines, sorted(new_arms - old_arms)


def cmd_compare(args):
    old, new = read_document(args.stored), read_document(args.new)
    lines, added = compare_lines(old, new)
    if lines:
        print("\n".join(lines))
        return 1
    for name in added:
        print(f"fingerprint: arm {name} added")
    more = rounds_extended(old, new)
    if more:
        print(f"fingerprint: rounds extended {old['components']['rounds']} -> {new['components']['rounds']}")
    if (added or more) and args.merge:
        merged = {**old["components"], "arms": {**old["components"]["arms"], **{name: new["components"]["arms"][name] for name in added}}}
        if more:
            merged["rounds"] = new["components"]["rounds"]
        write_atomic(args.stored, document_of(merged))
    return 0


# ---------- build, show, check-quality ----------
def cmd_build(args):
    probe = read_document(args.probe_from) if args.probe_from else None
    document = document_of(build_components(Path(args.inputs), probe))
    write_atomic(args.out, document)
    print(document["sha256"])
    return 0


def descend(node, parts, path):
    """The value at a dotted path; a key may hold dots (a patch path), so the longest matching key is tried first."""
    if not parts:
        return node
    if isinstance(node, dict):
        for size in range(len(parts), 0, -1):
            key = ".".join(parts[:size])
            if key in node:
                return descend(node[key], parts[size:], path)
    fail("", f"{path} is not in the document")


def cmd_show(args):
    document = read_document(args.file)
    parts = args.path.split(".")
    value = document[args.path] if args.path in ("sha256", "version") and args.path in document else descend(document["components"], parts, args.path)
    if isinstance(value, dict):
        print("\n".join(value))
    elif isinstance(value, list):
        print(" ".join(str(item) for item in value))
    else:
        print(value)
    return 0


def quality_problems(prompts_path, gsm_path):
    problems, loaded = [], {}
    for label, path in (("prompts", prompts_path), ("gsm8k", gsm_path)):
        try:
            loaded[label] = json.loads(Path(path).read_text(encoding="utf-8"))
        except FileNotFoundError:
            problems.append(f"quality: {path} is missing")
        except (OSError, UnicodeDecodeError, json.JSONDecodeError):
            problems.append(f"quality: {path} is not JSON")
    if "prompts" in loaded:
        results = loaded["prompts"].get("results") if isinstance(loaded["prompts"], dict) else None
        count = len(results) if isinstance(results, list) else 0
        if count != QUALITY_PROMPTS:
            problems.append(f"quality: prompts has {count} results, expected {QUALITY_PROMPTS}")
    if "gsm8k" in loaded:
        summary = loaded["gsm8k"].get("summary") if isinstance(loaded["gsm8k"], dict) else None
        n = summary.get("n") if isinstance(summary, dict) else None
        if n != QUALITY_GSM8K_N:
            problems.append(f"quality: gsm8k summary.n is {n}, expected {QUALITY_GSM8K_N}")
    return problems


def cmd_check_quality(args):
    problems = quality_problems(args.prompts, args.gsm8k)
    print("\n".join(problems) if problems else "quality: ok")
    return 1 if problems else 0


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    build = sub.add_parser("build", help="assemble, hash and write the fingerprint document")
    build.add_argument("inputs")
    build.add_argument("--out", required=True)
    build.add_argument("--probe-from", help="a stored document: the model listing and the generation config are taken from it, not from the inputs")
    build.set_defaults(fn=cmd_build)
    compare = sub.add_parser("compare", help="name every differing leaf of two documents")
    compare.add_argument("--merge", action="store_true", help="write the stored document with the new arms added")
    compare.add_argument("stored")
    compare.add_argument("new")
    compare.set_defaults(fn=cmd_compare)
    show = sub.add_parser("show", help="print one leaf of a document")
    show.add_argument("file")
    show.add_argument("path")
    show.set_defaults(fn=cmd_show)
    quality = sub.add_parser("check-quality", help="the round-1 quality files of a record")
    quality.add_argument("prompts")
    quality.add_argument("gsm8k")
    quality.set_defaults(fn=cmd_check_quality)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        return args.fn(args)
    except InputError as error:
        print(error, file=sys.stderr)
        return 2
    except Exception as error:  # exit 1 means a difference: nothing unexpected may look like it
        print(f"fingerprint: unexpected {type(error).__name__}: {str(error).splitlines()[0] if str(error) else ''}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
