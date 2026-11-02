#!/usr/bin/env python3
"""The table and the decision of the MoE kernel A/B (E2.S1, decision 3).

  moe_kernel_ab.py decide <log dir> --keys "<batch sizes>" --rule each|median --rule-keys "<batch sizes>" [--reps 3] [--threshold 3]

Reads `default-<n>.log` and `tuned-<n>.log` for n in 1..reps (the logs of benchmark_moe.py WITHOUT --tune: a `Batch size: <n>, config: <dict>`
line and the `Kernel time: <us> us` line after it), takes the median per batch size and arm, and prints the table, one config line per arm and
batch size, and ONE decision line, `KERNEL: faster (...)` or `KERNEL: not faster (...)`. Rule `each`: every rule key is faster by more than the
threshold. Rule `median`: the median change over the rule keys is below minus the threshold AND no key is slower by more than the threshold.
Numbers are decimal.Decimal parsed from the text and compared unrounded and strict: (97.00 - 100.00) / 100.00 * 100 is -3.0000000000000004 in
binary floating point, which a float comparison calls "faster" at exactly -3 %.

A decision is made only when every log is there and holds every batch size exactly once (a missing log, a batch size twice in one log and a short
arm are each refused, naming the file or the arm and batch size). Exit codes: 0 faster, 1 not faster, 2 an input that cannot be decided (stderr, nothing on stdout).
Python >= 3.10, standard library only.
"""
import argparse
import re
import statistics
import sys
from decimal import Decimal, InvalidOperation
from pathlib import Path

ARMS = ("default", "tuned")
PAIR = re.compile(r"Batch size: (\d+), config: (.*)\nKernel time: ([\d.]+) us")  # moe_kernel_ab.py line 14 of the published script
KERNEL_TIME = re.compile(r"Kernel time: [0-9]+(?:\.[0-9]+)? us")
KEY = re.compile(r"[1-9][0-9]*")
HEADER = "bs  default_us  tuned_us  change   (median of reps)"
HUNDRED = Decimal(100)


class InputError(Exception):
    """An input that cannot be decided: the message is printed on stderr and the exit code is 2."""


# ---------- reading ----------
def key_list(text, what):
    """The batch sizes of an argument, sorted and without repeats (merge_moe.py has the same function: the two files stand alone)."""
    words = text.split()
    if not words or not all(KEY.fullmatch(word) for word in words):
        raise InputError(f'{what} "{text}" is not a list of positive integers')
    return sorted({int(word) for word in words})


def read_log(path):
    """[(batch size, config text, kernel time)] of one log; a line that starts `Kernel time:` and is not a measurement is refused."""
    text = path.read_text(encoding="utf-8", errors="replace").replace("\r", "")
    for number, line in enumerate(text.splitlines(), 1):
        if line.startswith("Kernel time:") and not KERNEL_TIME.fullmatch(line.rstrip()):
            raise InputError(f"{path}:{number}: not a kernel time")
    return [(int(bs), config, Decimal(us)) for bs, config, us in PAIR.findall(text)]


def log_problems(path, rows, keys):
    """The problems of ONE present log: a batch size outside --keys (the first, once), a batch size written more than once (each, naming the file)."""
    seen = [bs for bs, _config, _us in rows]
    problems = [f"bs {bs} is in {path} {seen.count(bs)} times" for bs in dict.fromkeys(seen) if seen.count(bs) > 1 and bs in keys]
    outside = next((bs for bs in seen if bs not in keys), None)
    return problems + ([f"bs {outside} in {path} is not in --keys"] if outside is not None else [])


def collect(folder, reps, keys):
    """({arm: {bs: [times]}}, {arm: {bs: config text}}, [problems]); the config is the one of the last log read, as in the published script.

    A rep is a LOG: each present log must hold each batch size once, so two logs joined into one cannot pass for two reps; a log that is not there
    is refused by name."""
    times, configs, problems = {arm: {} for arm in ARMS}, {arm: {} for arm in ARMS}, []
    for arm in ARMS:
        for number in range(1, reps + 1):
            path = folder / f"{arm}-{number}.log"
            if not path.is_file():
                problems.append(f"missing log: {path}")
                continue
            rows = read_log(path)
            problems += log_problems(path, rows, keys)
            for bs, config, us in rows:
                if bs in keys:
                    times[arm].setdefault(bs, []).append(us)
                    configs[arm][bs] = config
    return times, configs, problems


def incomplete(times, keys, reps):
    return [f"incomplete: {arm} bs {bs} has {len(times[arm].get(bs, []))} of {reps} values"
            for bs in keys for arm in ARMS if len(times[arm].get(bs, [])) != reps]


# ---------- the numbers ----------
def medians(times, keys):
    return {arm: {bs: statistics.median(times[arm][bs]) for bs in keys} for arm in ARMS}


def gains_of(med, keys):
    """{bs: (tuned - default) / default * 100}, exact."""
    gains = {}
    for bs in keys:
        default = med["default"][bs]
        if default == 0:
            raise InputError(f"bs {bs}: the default median is 0")
        gains[bs] = (med["tuned"][bs] - default) / default * HUNDRED
    return gains


def table_lines(times, med, gains, keys):
    return [HEADER] + [f"{bs:>2}  {med['default'][bs]:10.2f}  {med['tuned'][bs]:8.2f}  {gains[bs]:+6.1f} %   "
                       f"n={len(times['default'][bs])}/{len(times['tuned'][bs])}" for bs in keys]


def config_lines(configs):
    return [f"{arm} bs {bs} config: {configs[arm][bs]}" for arm in ARMS for bs in sorted(configs[arm])]


# ---------- the rules: (faster, why) ----------
def shown(threshold):
    return format(threshold.normalize(), "f")


def words(keys):
    return " ".join(str(bs) for bs in keys)


def rule_each(gains, rule_keys, threshold):
    for bs in rule_keys:
        if not gains[bs] < -threshold:
            return False, f"bs {bs}: {gains[bs]:+.1f} % is not below -{shown(threshold)} %"
    return True, f"each of {words(rule_keys)} is faster by more than {shown(threshold)} %"


def rule_median(gains, keys, rule_keys, threshold):
    middle = statistics.median(gains[bs] for bs in rule_keys)
    head = f"median change at {words(rule_keys)}: {middle:+.1f} %"
    slower = next((bs for bs in keys if gains[bs] > threshold), None)
    if slower is not None:
        return False, f"{head}; bs {slower} is slower by {gains[slower]:.1f} %"
    if not middle < -threshold:
        return False, head
    return True, f"{head}; no size slower by more than {shown(threshold)} %"


# ---------- the command ----------
def positive_decimal(text, what):
    try:
        value = Decimal(text)
    except InvalidOperation:
        value = None
    if value is None or not value.is_finite() or value <= 0:
        raise InputError(f'{what} "{text}" is not a positive number')
    return value


def cmd_decide(args):
    keys, rule_keys = key_list(args.keys, "--keys"), key_list(args.rule_keys, "--rule-keys")
    outside = [bs for bs in rule_keys if bs not in keys]
    if outside:
        raise InputError(f"rule key {outside[0]} is not in --keys")
    if args.reps < 1:
        raise InputError("--reps must be at least 1")
    threshold = positive_decimal(args.threshold, "--threshold")
    times, configs, problems = collect(Path(args.dir), args.reps, keys)
    problems = incomplete(times, keys, args.reps) + problems
    if problems:
        raise InputError("\n".join(problems))
    med = medians(times, keys)
    gains = gains_of(med, keys)
    faster, why = rule_each(gains, rule_keys, threshold) if args.rule == "each" else rule_median(gains, keys, rule_keys, threshold)
    print("\n".join(table_lines(times, med, gains, keys) + config_lines(configs)))
    print(f"KERNEL: {'faster' if faster else 'not faster'} ({why})")
    return 0 if faster else 1


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    decide = sub.add_parser("decide", help="the table and the decision of one kernel A/B folder")
    decide.add_argument("dir")
    decide.add_argument("--keys", required=True)
    decide.add_argument("--rule", required=True, choices=("each", "median"))
    decide.add_argument("--rule-keys", required=True)
    decide.add_argument("--reps", type=int, default=3)
    decide.add_argument("--threshold", default="3")
    decide.set_defaults(fn=cmd_decide)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        return args.fn(args)
    except InputError as error:
        print(error, file=sys.stderr)
        return 2
    except Exception as error:  # exit 1 means "not faster": nothing unexpected may look like it
        print(f"moe_kernel_ab.py: unexpected {type(error).__name__}: {str(error).splitlines()[0] if str(error) else ''}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
