#!/usr/bin/env python3
"""The ship test over bench lines, and the check of one arm-round block. Two modes with two line grammars: vLLM (`ship`,
`check-block`) and ComfyUI (`comfy`, `comfy-check-block`).

  verdict.py ship --base <arm> --arm <arm> [--arm ...] --bench <file> [--bench ...] --prefill-lens "<lens>"
                  [--rounds 3] (--gsm8k-dir <dir> | --no-quality) [--json <file>]
  verdict.py check-block --tag <tag> --prefill-lens "<lens>" <file>
  verdict.py comfy --workflow <name> --metrics "<metrics>" --decide <metric> --direction (lower|higher) --base <arm>
                   --arm <arm> [--arm ...] --bench <file> [--bench ...] [--rounds 3] [--json <file>]
  verdict.py comfy-check-block --tag <tag> --workflow <name> --metrics "<metrics>" <file>

The rule (written before the 2026-10-27 run): an arm passes on speed when its output-throughput median is higher than the
base's by MORE than the base spread at c=1 or c=4 (rule 1), and at no concurrency is it lower by more than that
concurrency's base spread (rule 2); and on quality when |GSM8K accuracy delta| <= 2 * max(stderr of the two). The spread is
max - min over ALL of the base's values (rounds x seeds), never over round medians. Only complete arm-round blocks count.
The GSM8K files must be comparable: the arm and the base have the same n, and n is at least 200 (`--min-gsm8k-n N` lowers the
minimum; the output then says so in a `note:` line); each file's stderr must equal sqrt(p(1-p)/n) for its own accuracy p and n
within 0.00001, because the limit is built from it; otherwise the file is refused (exit 2). A different n or a too small n leaves
the arm INCOMPLETE (exit 1).
Numbers are decimal.Decimal parsed from the text: binary floating point calls "exactly one spread above" higher.

The comfy rule applies the same spread rule to one workflow's metrics, and ONE metric (`--decide`) decides: the arm's median
over every run of every round is compared with the base's, and the direction says which way is better (seconds: lower). Beyond
the base's spread in the better direction is PASS, beyond it in the worse direction is FAIL (`<metric> higher|lower than the base
by more than its spread`), and inside the spread (`within, lower` or `within, not lower`) is NOT DECIDED, never FAIL.
An arm with a missing complete arm-round is INCOMPLETE, never PASS or FAIL. The other metrics are printed as `(information)`
and never decide.
A comfy line is `<arm>-<round> <workflow> r=<n> <metric>: <value>`, n in COMFY_RUNS; a complete block is one line for every
(run, metric) pair of `--metrics`, and a line of a metric that is not in `--metrics` is an input error. The words of `--metrics`
are given in the order bench.py prints them: the first word starts a block (its `r=1` line), so another order cuts every block
in two and nothing is complete. Numbers are Decimal, printed with three places.

Exit codes. ship: 0 every arm decided (PASS or FAIL), 1 at least one INCOMPLETE, 2 input error.
comfy: 0 every arm PASS, FAIL or NOT DECIDED, 1 at least one INCOMPLETE, 2 input error.
check-block and comfy-check-block: 0 complete, 1 incomplete, 2 input error. Python >= 3.10, standard library only.
"""
import argparse
import json
import os
import re
import statistics
import sys
from dataclasses import dataclass
from decimal import ROUND_HALF_EVEN, Decimal
from pathlib import Path

THROUGHPUT = "Output token throughput (tok/s)"
DECODE_METRICS = (THROUGHPUT, "Mean TTFT (ms)", "Mean TPOT (ms)")
PREFILL_METRICS = (THROUGHPUT, "Mean TTFT (ms)", "Median TTFT (ms)")
CONCURRENCIES = ("1", "4")
REPEATS = (1, 2, 3)
COMFY_RUNS = (1, 2, 3)  # the measured runs of one ComfyUI arm-round: the parent plan's contract (three runs after the cold one)
START_KEY = f"c=1 r=1 {THROUGHPUT}"
CENT = Decimal("0.01")
MILLI = Decimal("0.001")
QUALITY_DIGITS = Decimal("0.0001")
DEFAULT_MIN_N = 200
STDERR_TOLERANCE = Decimal("0.00001")  # a stderr rounded to five places still passes; the recorded files carry full precision

BENCH_LINE = re.compile(
    r"^(?P<arm>[a-z0-9]+)-(?P<round>[1-9][0-9]*) "
    r"(?:c=(?P<c>[14]) r=(?P<r>[1-9])|prefill(?P<len>[0-9]+) r=(?P<pr>[1-9])) "
    r"(?P<metric>Output token throughput \(tok/s\)|Mean TTFT \(ms\)|Mean TPOT \(ms\)|Median TTFT \(ms\)):"
    r"\s+(?P<value>[0-9]+(?:\.[0-9]+)?)\s*$")
# The arm part is one named group: the arm-name grammar of lib/config.sh (_RE_ARM) changes here and in arm_name.
COMFY_LINE = re.compile(
    r"^(?P<arm>[a-z0-9]+)-(?P<round>[1-9][0-9]*) (?P<workflow>[a-z0-9]+) r=(?P<run>[1-9][0-9]*) "
    r"(?P<metric>[a-z][a-z0-9_]*):\s+(?P<value>[0-9]+(?:\.[0-9]+)?)\s*$")
METRICS_HELP = ("the metrics of a block, in the order bench.py prints them; the first word starts a block (its `r=1` line), "
                "a line of any other metric is refused")
METRIC_WORD = re.compile(r"[a-z][a-z0-9_]*")


class InputError(Exception):
    """A bad input: the message is printed on stderr and the exit code is 2."""


@dataclass(frozen=True)
class Line:
    file: str
    number: int
    tag: str
    key: str
    value: Decimal


@dataclass(frozen=True)
class Block:
    tag: str
    lines: tuple

    @property
    def first(self):
        return self.lines[0]

    def values(self):
        return {line.key: line.value for line in self.lines}


@dataclass(frozen=True)
class Stat:
    median: Decimal
    base_median: Decimal
    delta: Decimal
    spread: Decimal
    n: int


@dataclass(frozen=True)
class Quality:
    accuracy: Decimal
    base_accuracy: Decimal
    delta: Decimal
    limit: Decimal
    passed: bool


# ---------- keys and parsing ----------
def expected_keys(prefill_lens):
    """The keys of a complete block, in canonical order: c=1 r=1..3, c=4 r=1..3, then each prefill length r=1..3."""
    groups = [(f"c={c}", DECODE_METRICS) for c in CONCURRENCIES] + [(f"prefill{n}", PREFILL_METRICS) for n in prefill_lens]
    return [f"{group} r={r} {metric}" for group, metrics in groups for r in REPEATS for metric in metrics]


def parse_line(text, file, number):
    match = BENCH_LINE.match(text)
    if not match:
        raise InputError(f"{file}:{number}: not a bench line")
    group = f"c={match['c']} r={match['r']}" if match["c"] else f"prefill{match['len']} r={match['pr']}"
    return Line(file, number, f"{match['arm']}-{match['round']}", f"{group} {match['metric']}", Decimal(match["value"]))


def comfy_parser(workflow, metrics):
    """A line parser for read_lines: tag `<arm>-<round>`, key `r=<n> <metric>`; a line of another workflow or of a metric
    that is not in `metrics` is refused."""
    def parse(text, file, number):
        match = COMFY_LINE.match(text)
        if not match or int(match["run"]) not in COMFY_RUNS:
            raise InputError(f"{file}:{number}: not a bench line")
        if match["workflow"] != workflow:
            raise InputError(f'{file}:{number}: workflow "{match["workflow"]}" is not the expected "{workflow}"')
        if match["metric"] not in metrics:
            raise InputError(f'{file}:{number}: metric "{match["metric"]}" is not one of --metrics "{" ".join(metrics)}"')
        tag, key = f"{match['arm']}-{match['round']}", f"r={match['run']} {match['metric']}"
        return Line(file, number, tag, key, Decimal(match["value"]))
    return parse


def comfy_keys(metrics):
    """The keys of a complete comfy block, in canonical order: every run, every metric."""
    return [f"r={run} {metric}" for run in COMFY_RUNS for metric in metrics]


def metrics_of(text):
    words = text.split()
    if not words:
        raise InputError(f'--metrics "{text}" needs at least one metric')
    wrong = next((word for word in words if not METRIC_WORD.fullmatch(word)), None)
    if wrong is not None:
        raise InputError(f'--metrics "{text}" has "{wrong}", which is not a metric name '
                         "(lower-case letters, digits and _, starting with a letter)")
    repeated = next((word for word in words if words.count(word) > 1), None)
    if repeated is not None:
        raise InputError(f'--metrics "{text}" repeats a metric: {repeated}')
    return words


def read_lines(path, parser=parse_line):
    path = Path(path)
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        raise InputError(f"{path}: cannot read ({getattr(error, 'strerror', None) or error})") from error
    return [parser(raw, path.name, number) for number, raw in enumerate(text.splitlines(), 1) if raw.strip()]


def split_blocks(lines, start_key=START_KEY):
    """A block starts at its start-key line (vLLM: `c=1 r=1 Output token throughput`) and runs to the next one of the same tag."""
    blocks, current = [], {}
    for line in lines:
        if line.key == start_key or line.tag not in current:
            current[line.tag] = []
            blocks.append(current[line.tag])
        current[line.tag].append(line)
    return [Block(rows[0].tag, tuple(rows)) for rows in blocks]


def is_complete(block, keys):
    seen = [line.key for line in block.lines]
    return len(seen) == len(set(seen)) and set(seen) == set(keys)


def describe(prefix, block):
    return f"{prefix}: {block.tag}, {len(block.lines)} lines from {block.first.file}:{block.first.number}"


def pick_blocks(blocks, keys):
    """(the last complete block per tag, the notes about every block that is not used)."""
    usable, notes = {}, []
    for block in blocks:
        if not is_complete(block, keys):
            notes.append(describe("ignored incomplete block", block))
            continue
        if block.tag in usable:
            notes.append(describe("superseded complete block", usable[block.tag]))
        usable[block.tag] = block
    return usable, notes


# ---------- numbers ----------
def two_places(value):
    return value.quantize(CENT, rounding=ROUND_HALF_EVEN)


def plain(value):
    return f"{two_places(value):f}"


def signed(value):
    return f"{two_places(value):+f}"


def three_places(value):
    return value.quantize(MILLI, rounding=ROUND_HALF_EVEN)


def plain3(value):
    return f"{three_places(value):f}"


def signed3(value):
    return f"{three_places(value):+f}"


def stat_of(arm_values, base_values):
    base_median, median = statistics.median(base_values), statistics.median(arm_values)
    return Stat(median, base_median, median - base_median, max(base_values) - min(base_values), len(arm_values))


def word_of(stat):
    if stat.delta > stat.spread:
        return "higher"
    if stat.delta >= 0:
        return "within, not lower"
    return "within, lower" if stat.delta >= -stat.spread else "lower"


def series(blocks, tags, group, metric):
    return [blocks[tag].values()[f"{group} r={r} {metric}"] for tag in tags for r in REPEATS]


def stats_for(blocks, arm_tags, base_tags, prefill_lens):
    decode = {c: stat_of(series(blocks, arm_tags, f"c={c}", THROUGHPUT), series(blocks, base_tags, f"c={c}", THROUGHPUT))
              for c in CONCURRENCIES}
    prefill = {str(n): stat_of(series(blocks, arm_tags, f"prefill{n}", "Median TTFT (ms)"),
                               series(blocks, base_tags, f"prefill{n}", "Median TTFT (ms)")) for n in prefill_lens}
    return decode, prefill


# ---------- quality ----------
def number(value, what, path):
    """A JSON number (never a string or a boolean) that is finite, as a Decimal."""
    if isinstance(value, bool) or not isinstance(value, (Decimal, int, float)):
        raise InputError(f"{path}: {what} must be a number, found {value!r}")
    result = value if isinstance(value, Decimal) else Decimal(str(value))
    if not result.is_finite():
        raise InputError(f"{path}: {what} must be finite, found {value!r}")
    return result


def read_summary(path):
    """(accuracy, stderr, n) of a GSM8K result file; anything that is not a sane summary is an input error."""
    try:
        summary = json.loads(Path(path).read_text(encoding="utf-8"), parse_float=Decimal)["summary"]
        accuracy, err = number(summary["accuracy"], "summary.accuracy", path), number(summary["stderr"], "summary.stderr", path)
        n = summary["n"]
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise InputError(f"{path}: not a gsm8k result with summary.n, summary.accuracy and summary.stderr ({error})") from error
    if not 0 <= accuracy <= 1:
        raise InputError(f"{path}: summary.accuracy must be within 0..1, found {accuracy}")
    if err < 0:
        raise InputError(f"{path}: summary.stderr must not be negative, found {err}")
    if isinstance(n, bool) or not isinstance(n, int) or n < 1:
        raise InputError(f"{path}: summary.n must be a positive integer, found {n!r}")
    expected = (accuracy * (1 - accuracy) / n).sqrt()
    if abs(err - expected) > STDERR_TOLERANCE:
        shown = expected.quantize(Decimal("0.000001"), rounding=ROUND_HALF_EVEN)
        raise InputError(f"{path}: gsm8k stderr {err} does not match accuracy {accuracy} and n {n} (expected {shown})")
    return accuracy, err, n


def quality_of(directory, arm, base, min_n):
    """(Quality or None, the list of reasons the quality cannot be judged)."""
    paths = {name: Path(directory) / f"gsm8k_{name}.json" for name in (arm, base)}
    missing = [f"no {path.name}" for path in paths.values() if not path.is_file()]
    if missing:
        return None, missing
    (accuracy, err, n), (base_accuracy, base_err, base_n) = read_summary(paths[arm]), read_summary(paths[base])
    if n != base_n:
        return None, [f"gsm8k n differs: {arm} {n}, {base} {base_n}"]
    if n < min_n:
        return None, [f"gsm8k n {n} is below the minimum {min_n}"]
    delta, limit = accuracy - base_accuracy, 2 * max(err, base_err)
    return Quality(accuracy, base_accuracy, delta, limit, abs(delta) <= limit), []


# ---------- the decision ----------
def fail_reasons(decode, quality):
    reasons = []
    if not any(word_of(stat) == "higher" for stat in decode.values()):
        reasons.append("no decode median is higher than the base spread")
    reasons += [f"c={c} is lower by more than the base spread" for c, stat in decode.items() if word_of(stat) == "lower"]
    if quality is not None and not quality.passed:
        reasons.append("gsm8k")
    return reasons


def missing_tags(usable, arm, rounds):
    return [f"{arm}-{r}" for r in range(1, rounds + 1) if f"{arm}-{r}" not in usable]


def evaluate(arm, ctx):
    """One arm's result: a dict with the numbers, the verdict word and its reason."""
    base, usable, rounds = ctx["base"], ctx["usable"], ctx["rounds"]
    gaps = missing_tags(usable, arm, rounds)
    base_gaps = missing_tags(usable, base, rounds)
    result = {"arm": arm, "base": base, "rounds": rounds, "decode": None, "prefill": None, "quality": None,
              "verdict": "INCOMPLETE", "reason": None, "have": rounds - len(gaps)}
    incomplete = ([f"missing complete arm-rounds: {', '.join(gaps)}"] if gaps else []) \
        + ([f"base {base} missing complete arm-rounds: {', '.join(base_gaps)}"] if base_gaps else [])
    if not incomplete:
        tags = [f"{arm}-{r}" for r in range(1, rounds + 1)], [f"{base}-{r}" for r in range(1, rounds + 1)]
        result["decode"], result["prefill"] = stats_for(usable, *tags, ctx["prefill_lens"])
    if ctx["gsm8k_dir"] is not None:
        result["quality"], gaps_q = quality_of(ctx["gsm8k_dir"], arm, base, ctx["min_n"])
        incomplete += gaps_q
    if incomplete:
        return {**result, "reason": "; ".join(incomplete)}
    reasons = fail_reasons(result["decode"], result["quality"])
    if reasons:
        return {**result, "verdict": "FAIL", "reason": reasons[0]}
    return {**result, "verdict": "PASS", "reason": None if ctx["gsm8k_dir"] is not None else "quality NOT checked"}


# ---------- the comfy decision ----------
def comfy_verdict(word, direction, metric):
    """(verdict, reason) of the deciding word: beyond the spread in the better direction passes, in the worse one fails."""
    better, worse = ("lower", "higher") if direction == "lower" else ("higher", "lower")
    if word == better:
        return "PASS", None
    if word == worse:
        return "FAIL", f"{metric} {worse} than the base by more than its spread"
    return "NOT DECIDED", "inside the base spread"


def comfy_series(usable, tags, metric):
    return [usable[tag].values()[f"r={r} {metric}"] for tag in tags for r in COMFY_RUNS]


def evaluate_comfy(arm, ctx):
    """One arm's comfy result: the gaps first (as `evaluate`), then each metric's stat (the deciding first), then the verdict."""
    base, usable, rounds, metrics, decide = ctx["base"], ctx["usable"], ctx["rounds"], ctx["metrics"], ctx["decide"]
    gaps, base_gaps = missing_tags(usable, arm, rounds), missing_tags(usable, base, rounds)
    result = {"arm": arm, "base": base, "workflow": ctx["workflow"], "rounds": rounds, "direction": ctx["direction"],
              "decide": decide, "stats": None, "verdict": "INCOMPLETE", "reason": None, "have": rounds - len(gaps)}
    if gaps or base_gaps:
        incomplete = ([f"missing complete arm-rounds: {', '.join(gaps)}"] if gaps else []) \
            + ([f"base {base} missing complete arm-rounds: {', '.join(base_gaps)}"] if base_gaps else [])
        return {**result, "reason": "; ".join(incomplete)}
    arm_tags, base_tags = [f"{arm}-{r}" for r in range(1, rounds + 1)], [f"{base}-{r}" for r in range(1, rounds + 1)]
    stats = {metric: stat_of(comfy_series(usable, arm_tags, metric), comfy_series(usable, base_tags, metric))
             for metric in [decide, *[m for m in metrics if m != decide]]}
    verdict, reason = comfy_verdict(word_of(stats[decide]), ctx["direction"], decide)
    return {**result, "stats": stats, "verdict": verdict, "reason": reason}


# ---------- output ----------
def stat_line(label, stat, tail):
    return (f"  {label}: median {plain(stat.median)} vs {plain(stat.base_median)}, delta {signed(stat.delta)}, "
            f"base spread {plain(stat.spread)} {tail}")


def four(value):
    return f"{value.quantize(QUALITY_DIGITS, rounding=ROUND_HALF_EVEN):f}"


def signed_four(value):
    return f"{value.quantize(QUALITY_DIGITS, rounding=ROUND_HALF_EVEN):+f}"


def quality_line(quality):
    return (f"  gsm8k accuracy: {four(quality.accuracy)} vs {four(quality.base_accuracy)}, delta {signed_four(quality.delta)}, "
            f"limit {four(quality.limit)} -> {'pass' if quality.passed else 'fail'}")


def report_lines(result):
    arm, base, rounds = result["arm"], result["base"], result["rounds"]
    if result["decode"] is None:
        head = f"arm {arm} vs {base}: {result['have']} of {rounds} rounds complete"
    else:
        head = f"arm {arm} vs {base}: {rounds} round{'s' if rounds != 1 else ''}, {3 * rounds} values per concurrency"
    lines = [head]
    if result["decode"] is not None:
        lines += [stat_line(f"c={c} output tok/s", stat, f"-> {word_of(stat)}") for c, stat in result["decode"].items()]
        lines += [stat_line(f"prefill{n} median TTFT ms", stat, "(information)") for n, stat in result["prefill"].items()]
    if result["quality"] is not None:
        lines.append(quality_line(result["quality"]))
    detail = result["reason"]
    if result["verdict"] == "PASS":
        lines.append(f"verdict {arm}: PASS" + (" (quality NOT checked)" if detail else ""))
    else:
        lines.append(f"verdict {arm}: {result['verdict']} ({detail})")
    return lines


def comfy_stat_line(label, stat, tail):
    return (f"  {label}: median {plain3(stat.median)} vs {plain3(stat.base_median)}, delta {signed3(stat.delta)}, "
            f"base spread {plain3(stat.spread)} {tail}")


def comfy_report_lines(result):
    arm, base, rounds, decide, stats = result["arm"], result["base"], result["rounds"], result["decide"], result["stats"]
    if stats is None:
        lines = [f"arm {arm} vs {base}: {result['have']} of {rounds} rounds complete"]
    else:
        lines = [f"arm {arm} vs {base}: {rounds} round{'s' if rounds != 1 else ''}, {len(COMFY_RUNS) * rounds} values per metric"]
        lines += [comfy_stat_line(metric, stat, f"-> {word_of(stat)}" if metric == decide else "(information)")
                  for metric, stat in stats.items()]
    detail = f" ({result['reason']})" if result["reason"] else ""
    return [*lines, f"verdict {arm}: {result['verdict']}{detail}"]


def stat_json(stat, word):
    return {"median": plain(stat.median), "base_median": plain(stat.base_median), "delta": plain(stat.delta),
            "spread": plain(stat.spread), "n": stat.n, "word": word}


def result_json(result):
    quality = result["quality"]
    decode, prefill = result["decode"], result["prefill"]
    return {"arm": result["arm"], "base": result["base"], "rounds": result["rounds"],
            "c1": stat_json(decode["1"], word_of(decode["1"])) if decode else None,
            "c4": stat_json(decode["4"], word_of(decode["4"])) if decode else None,
            "prefill": {n: stat_json(stat, "information") for n, stat in prefill.items()} if prefill else {},
            "gsm8k": None if quality is None else {
                "accuracy": four(quality.accuracy), "base_accuracy": four(quality.base_accuracy),
                "delta": signed_four(quality.delta), "limit": four(quality.limit), "pass": quality.passed},
            "verdict": result["verdict"], "reason": result["reason"]}


def comfy_stat_json(stat, word):
    return {"median": plain3(stat.median), "base_median": plain3(stat.base_median), "delta": plain3(stat.delta),
            "spread": plain3(stat.spread), "n": stat.n, "word": word}


def comfy_result_json(result):
    stats, decide = result["stats"], result["decide"]
    return {"arm": result["arm"], "base": result["base"], "workflow": result["workflow"], "rounds": result["rounds"],
            "direction": result["direction"],
            "decide": None if stats is None else {"metric": decide, **comfy_stat_json(stats[decide], word_of(stats[decide]))},
            "information": None if stats is None
            else {m: comfy_stat_json(stat, "information") for m, stat in stats.items() if m != decide},
            "verdict": result["verdict"], "reason": result["reason"]}


def write_json(path, payload):
    """Write `<path>.part`, then os.replace; on any error remove the `.part` and refuse."""
    part = Path(f"{path}.part")
    try:
        part.write_text(json.dumps(payload, indent=1) + "\n", encoding="utf-8")
        os.replace(part, path)
    except OSError as error:
        try:
            part.unlink(missing_ok=True)
        except OSError:
            pass  # a directory or a file we may not remove is not ours to delete
        raise InputError(f"cannot write {path}: {error.strerror or error}") from error


# ---------- commands ----------
def lens_of(text):
    try:
        lens = [int(part) for part in text.split()]
    except ValueError as error:
        raise InputError(f'--prefill-lens "{text}" is not a list of integers') from error
    if not lens or any(n <= 0 for n in lens):
        raise InputError(f'--prefill-lens "{text}" needs at least one positive integer')
    repeated = sorted({n for n in lens if lens.count(n) > 1})
    if repeated:
        raise InputError(f'--prefill-lens "{text}" repeats a length: {repeated[0]}')
    return lens


def cmd_ship(args):
    lens = lens_of(args.prefill_lens)
    if args.min_gsm8k_n < 1:
        raise InputError("--min-gsm8k-n must be at least 1")
    lines = [line for path in args.bench for line in read_lines(path)]
    usable, notes = pick_blocks(split_blocks(lines), expected_keys(lens))
    if not any(tag.rsplit("-", 1)[0] == args.base for tag in usable):
        raise InputError(f'base arm "{args.base}" has no complete arm-round in the inputs')
    ctx = {"base": args.base, "usable": usable, "rounds": args.rounds, "prefill_lens": lens,
           "gsm8k_dir": None if args.no_quality else args.gsm8k_dir, "min_n": args.min_gsm8k_n}
    if args.min_gsm8k_n < DEFAULT_MIN_N:
        notes = [*notes, f"note: gsm8k minimum n lowered to {args.min_gsm8k_n} (default {DEFAULT_MIN_N})"]
    results = [evaluate(arm, ctx) for arm in args.arm]
    print("\n".join(notes + [line for result in results for line in report_lines(result)]))
    if args.json:
        write_json(args.json, [result_json(result) for result in results])
    return 1 if any(result["verdict"] == "INCOMPLETE" for result in results) else 0


def check_block_lines(tag, keys, lines):
    """The block check of both modes: print how one file's lines compare with the keys of a complete block; the exit code."""
    for line in lines:
        if line.tag != tag:
            raise InputError(f'{line.file}:{line.number}: tag "{line.tag}" is not the expected "{tag}"')
    seen = [line.key for line in lines]
    duplicates = [key for key in dict.fromkeys(seen) if seen.count(key) > 1]
    missing = [key for key in keys if key not in seen]
    if not duplicates and not missing and len(seen) == len(keys):
        print(f"{tag}: complete, {len(keys)} lines")
        return 0
    suffix = f" (duplicate: {duplicates[0]})" if duplicates else ""
    print(f"expected {len(keys)} lines, found {len(seen)}{suffix}")
    print("\n".join(f"missing: {key}" for key in missing))
    return 1


def cmd_check_block(args):
    keys = expected_keys(lens_of(args.prefill_lens))
    return check_block_lines(args.tag, keys, read_lines(args.file))


def cmd_comfy(args):
    metrics = metrics_of(args.metrics)
    if args.decide not in metrics:
        raise InputError(f'--decide "{args.decide}" is not one of --metrics "{args.metrics}"')
    lines = [line for path in args.bench for line in read_lines(path, comfy_parser(args.workflow, metrics))]
    usable, notes = pick_blocks(split_blocks(lines, f"r={COMFY_RUNS[0]} {metrics[0]}"), comfy_keys(metrics))
    if not any(tag.rsplit("-", 1)[0] == args.base for tag in usable):
        raise InputError(f'base arm "{args.base}" has no complete arm-round in the inputs')
    ctx = {"base": args.base, "usable": usable, "rounds": args.rounds, "metrics": metrics, "decide": args.decide,
           "direction": args.direction, "workflow": args.workflow}
    results = [evaluate_comfy(arm, ctx) for arm in args.arm]
    print("\n".join(notes + [line for result in results for line in comfy_report_lines(result)]))
    if args.json:
        write_json(args.json, [comfy_result_json(result) for result in results])
    return 1 if any(result["verdict"] == "INCOMPLETE" for result in results) else 0


def cmd_comfy_check_block(args):
    metrics = metrics_of(args.metrics)
    return check_block_lines(args.tag, comfy_keys(metrics), read_lines(args.file, comfy_parser(args.workflow, metrics)))


def arm_name(text):
    if not re.fullmatch(r"[a-z0-9]+", text):
        raise argparse.ArgumentTypeError(f'"{text}" is not an arm name (lower-case letters and digits only)')
    return text


def workflow_name(text):
    if not re.fullmatch(r"[a-z0-9]+", text):
        raise argparse.ArgumentTypeError(f'"{text}" is not a workflow name (lower-case letters and digits only)')
    return text


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    ship = sub.add_parser("ship", help="the ship test of one or more arms against a base")
    ship.add_argument("--base", required=True, type=arm_name)
    ship.add_argument("--arm", action="append", required=True, type=arm_name)
    ship.add_argument("--bench", action="append", required=True)
    ship.add_argument("--prefill-lens", required=True)
    ship.add_argument("--rounds", type=int, default=3)
    quality = ship.add_mutually_exclusive_group(required=True)
    quality.add_argument("--gsm8k-dir")
    quality.add_argument("--no-quality", action="store_true")
    ship.add_argument("--min-gsm8k-n", type=int, default=DEFAULT_MIN_N, metavar="N",
                      help=f"the smallest GSM8K sample that is judged (default {DEFAULT_MIN_N}); a lower value is said in the output")
    ship.add_argument("--json")
    ship.set_defaults(fn=cmd_ship)
    check = sub.add_parser("check-block", help="is this file exactly one complete arm-round block")
    check.add_argument("--tag", required=True)
    check.add_argument("--prefill-lens", required=True)
    check.add_argument("file")
    check.set_defaults(fn=cmd_check_block)
    comfy = sub.add_parser("comfy", help="the ship test of the comfy mode: one workflow's metrics, one deciding metric")
    comfy.add_argument("--workflow", required=True, type=workflow_name)
    comfy.add_argument("--metrics", required=True, help=METRICS_HELP)
    comfy.add_argument("--decide", required=True)
    comfy.add_argument("--direction", required=True, choices=("lower", "higher"),
                       help="the better direction of the deciding metric")
    comfy.add_argument("--base", required=True, type=arm_name)
    comfy.add_argument("--arm", action="append", required=True, type=arm_name)
    comfy.add_argument("--bench", action="append", required=True)
    comfy.add_argument("--rounds", type=int, default=3)
    comfy.add_argument("--json")
    comfy.set_defaults(fn=cmd_comfy)
    comfy_check = sub.add_parser("comfy-check-block", help="is this file exactly one complete comfy arm-round block")
    comfy_check.add_argument("--tag", required=True)
    comfy_check.add_argument("--workflow", required=True, type=workflow_name)
    comfy_check.add_argument("--metrics", required=True, help=METRICS_HELP)
    comfy_check.add_argument("file")
    comfy_check.set_defaults(fn=cmd_comfy_check_block)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        if getattr(args, "rounds", 1) < 1:
            raise InputError("--rounds must be at least 1")
        return args.fn(args)
    except InputError as error:
        print(error, file=sys.stderr)
        return 2
    except Exception as error:  # exit 1 means INCOMPLETE: nothing unexpected may look like it
        print(f"verdict.py: unexpected {type(error).__name__}: {str(error).splitlines()[0] if str(error) else ''}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
