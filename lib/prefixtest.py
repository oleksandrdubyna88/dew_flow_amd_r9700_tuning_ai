"""lib/prefixtest.py: the prefix-cache check of results § 6.1 — is a full prefix-cache hit slow on this model? (E3.S1)

  run <url> <model> <tag> [--lens "8192 1024"] [--tail 64] [--seed <int>] [--timeout 900]
      INSIDE the container of a running server, stdlib only. Random token-id prompts (new per run unless --seed is given, so no hit from an earlier
      run), max_tokens=1, sent one at a time. For every length: A cold, A again (full hit), A again, B cold, B again, A with its last --tail ids
      changed (partial hit). One line per length, printed as the length ends:
        <tag> prefixtest len=<n> A cold=<s>s A hit=<s>s A hit=<s>s B cold=<s>s B hit=<s>s A partial=<s>s
      (seconds rounded to two decimals, as the recorded file has them). Nothing is retried: a failed or stalled request is a measurement, one
      `prefix: <name> at len=<n>: <reason>` line and exit 1.
  check <file> --lens "..." --tag <tag>
      the validation of a result file before the worker records it: every line of the exact format with the tag, and EXACTLY one line per
      requested length (a missing, a doubled or an unexpected length is named; a line count alone would pass a duplicate).
  summarize <file>
      one line per line of the file: PREFIX <tag> len=<n>: cold <c> s, hit <h> s (<r>x), partial <p> s — the mean of the two cold values, the mean of
      the three hit values, their ratio with one decimal; exact decimals. No threshold and no verdict.

Source: dew_flow_benchmark research/vllm-r9700-speed-options/harness/prefixtest.py (34 lines).
Exit codes: 0 done; 1 a request failed; 2 the arguments or the file are refused (one `prefix: ...` line on stderr).
"""
import argparse
import json
import random
import re
import socket
import sys
import time
import urllib.error
import urllib.request
from decimal import ROUND_HALF_UP, Decimal

DEFAULT_LENS = "8192 1024"
DEFAULT_TAIL = 64
DEFAULT_TIMEOUT_S = 900.0
ID_RANGE = (1000, 150000)  # prefixtest.py line 26: randrange(1000, 150000)
STEPS = ("A cold", "A hit", "A hit", "B cold", "B hit", "A partial")
_SECONDS = r"([0-9]+(?:\.[0-9]+)?)s"
LINE_RE = re.compile(
    r"^(?P<tag>[A-Za-z0-9][A-Za-z0-9._-]*) prefixtest len=(?P<len>[1-9][0-9]*) A cold=" + _SECONDS + r" A hit=" + _SECONDS + r" A hit=" + _SECONDS
    + r" B cold=" + _SECONDS + r" B hit=" + _SECONDS + r" A partial=" + _SECONDS + r"$")


class PrefixError(ValueError):
    """A refusal that names its reason; main prints it as `prefix: <reason>` and exits 2."""


class RequestError(Exception):
    """A request that failed: the reason is one short phrase."""


# ---- the pure half: the line and its ratios ------------------------------------------------------------------------------------------------------------

def parse_line(text):
    """{tag, len, a_cold, a_hit1, a_hit2, b_cold, b_hit, a_partial} (the times as Decimals) of one line of the exact format, or a PrefixError."""
    match = LINE_RE.match(text)
    if not match:
        raise PrefixError("not a prefixtest line")
    keys = ("a_cold", "a_hit1", "a_hit2", "b_cold", "b_hit", "a_partial")
    parsed = {"tag": match["tag"], "len": int(match["len"])}
    parsed.update({key: Decimal(value) for key, value in zip(keys, match.groups()[2:])})
    return parsed


def _two(value):
    return str(value.quantize(Decimal("0.01"), ROUND_HALF_UP))


def summarize_line(parsed):
    cold = (parsed["a_cold"] + parsed["b_cold"]) / 2
    hit = (parsed["a_hit1"] + parsed["a_hit2"] + parsed["b_hit"]) / 3
    ratio = "n/a" if hit == 0 else str((cold / hit).quantize(Decimal("0.1"), ROUND_HALF_UP)) + "x"
    return f"PREFIX {parsed['tag']} len={parsed['len']}: cold {_two(cold)} s, hit {_two(hit)} s ({ratio}), partial {_two(parsed['a_partial'])} s"


def summarize_file(path):
    try:
        with open(path, encoding="utf-8") as handle:
            lines = handle.read().splitlines()
    except OSError as error:
        raise PrefixError(f"{path}: cannot be read ({error.strerror or error})")
    lines = [line.rstrip("\r") for line in lines]
    if not any(line.strip() for line in lines):
        raise PrefixError(f"{path}: holds no line")
    out = []
    for number, text in enumerate(lines, 1):
        try:
            out.append(summarize_line(parse_line(text)))
        except PrefixError:
            raise PrefixError(f"line {number}: not a prefixtest line")
    return "\n".join(out)


def check_file(path, lens, tag):
    """Raises a PrefixError naming the first line that is not the format, or every missing, doubled and unexpected length."""
    try:
        with open(path, encoding="utf-8") as handle:
            lines = [line.rstrip("\r") for line in handle.read().splitlines()]
    except OSError as error:
        raise PrefixError(f"{path}: cannot be read ({error.strerror or error})")
    if not any(line.strip() for line in lines):
        raise PrefixError(f"{path}: holds no line")
    seen = []
    for number, text in enumerate(lines, 1):
        try:
            parsed = parse_line(text)
        except PrefixError:
            raise PrefixError(f"line {number}: not a prefixtest line")
        if parsed["tag"] != tag:
            raise PrefixError(f"line {number}: the tag is {parsed['tag']}, not {tag}")
        seen.append(parsed["len"])
    reasons = [f"missing len={n}" for n in lens if n not in seen]
    reasons += [f"duplicate len={n}" for n in lens if seen.count(n) > 1]
    reasons += [f"unexpected len={n}" for n in dict.fromkeys(seen) if n not in lens]
    if reasons:
        raise PrefixError("; ".join(reasons))


# ---- the arguments ---------------------------------------------------------------------------------------------------------------------------------------

def parse_lens(text):
    words = text.split()
    if not words or not all(re.fullmatch(r"[1-9][0-9]{0,8}", word) for word in words):
        raise PrefixError(f'--lens "{text}" is not a list of positive integers of at most 9 digits')
    values = [int(word) for word in words]
    if len(set(values)) != len(values):
        raise PrefixError(f'--lens "{text}" repeats a value')
    return values


def check_run_arguments(args):
    """(lens) after every check of `run`; the arguments are refused before the first request."""
    lens = parse_lens(args.lens)
    if args.tail < 1:
        raise PrefixError(f"--tail {args.tail} is not a positive integer")
    if args.tail >= min(lens):
        raise PrefixError(f"--tail {args.tail} is not below the shortest length {min(lens)}")
    if not args.timeout > 0:
        raise PrefixError(f"--timeout {args.timeout} is not a positive number of seconds")
    return lens


# ---- run -----------------------------------------------------------------------------------------------------------------------------------------------------

def ask(url, model, ids, timeout):
    """One completion of one token; the wall time in seconds (prefixtest.py lines 17-22). A failure is a RequestError with one phrase."""
    body = json.dumps({"model": model, "prompt": ids, "max_tokens": 1, "temperature": 0}).encode()
    request = urllib.request.Request(url + "/v1/completions", body, {"Content-Type": "application/json"})
    start = time.perf_counter()
    try:
        urllib.request.urlopen(request, timeout=timeout).read()
    except urllib.error.HTTPError as error:
        raise RequestError(f"HTTP {error.code}")
    except (TimeoutError, socket.timeout):
        raise RequestError("timed out")
    except urllib.error.URLError as error:
        raise RequestError("timed out" if isinstance(error.reason, (TimeoutError, socket.timeout)) else str(error.reason))
    except OSError as error:
        raise RequestError(str(error))
    return time.perf_counter() - start


def measure_length(args, rng, length):
    """The line of one length: the six requests of the source, in order."""
    def prompt(count):
        return [rng.randrange(*ID_RANGE) for _ in range(count)]

    a, b = prompt(length), prompt(length)
    a_changed = a[:-args.tail] + prompt(args.tail)
    times = []
    for name, ids in zip(STEPS, (a, a, a, b, b, a_changed)):
        try:
            times.append((name, round(ask(args.url, args.model, ids, args.timeout), 2)))
        except RequestError as error:
            raise RequestError(f"{name} at len={length}: {error}")
    return f"{args.tag} prefixtest len={length} " + " ".join(f"{name}={seconds}s" for name, seconds in times)


def command_run(args):
    lens = check_run_arguments(args)
    rng = random.Random(args.seed if args.seed is not None else time.time_ns())  # no seed: new prompts per run (prefixtest.py line 14)
    try:
        for length in lens:
            print(measure_length(args, rng, length), flush=True)
    except RequestError as error:
        print(f"prefix: {error}", file=sys.stderr)
        return 1
    return 0


def command_check(args):
    check_file(args.file, parse_lens(args.lens), args.tag)
    return 0


def command_summarize(args):
    print(summarize_file(args.file))
    return 0


def build_parser():
    parser = argparse.ArgumentParser(prog="prefixtest.py", description=__doc__.split("\n", 1)[0])
    commands = parser.add_subparsers(dest="command", required=True)
    run = commands.add_parser("run", help="the twelve requests, against a running server")
    run.add_argument("url")
    run.add_argument("model")
    run.add_argument("tag")
    run.add_argument("--lens", default=DEFAULT_LENS)
    run.add_argument("--tail", type=int, default=DEFAULT_TAIL)
    run.add_argument("--seed", type=int, default=None)
    run.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT_S)
    run.set_defaults(handler=command_run)
    check = commands.add_parser("check", help="a result file against the lengths that were asked for")
    check.add_argument("file")
    check.add_argument("--lens", default=DEFAULT_LENS)
    check.add_argument("--tag", required=True)
    check.set_defaults(handler=command_check)
    summarize = commands.add_parser("summarize", help="the ratios of a result file")
    summarize.add_argument("file")
    summarize.set_defaults(handler=command_summarize)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        return args.handler(args)
    except PrefixError as error:
        print(f"prefix: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
