"""lib/linear_bench.py: the hybrid W4A16 linear kernel at small M, as one file with two commands (E3.S1).

  run --out <json> --shapes "<name>:<K>:<N>:<layers> ..." [--group-size 128] [--ms "1 2 ..."] [--sweep-ms "6 8 ..."] [--timer graph|eager]
      the benchmark, INSIDE the container (torch, triton and vllm are imported there and nowhere else). For every shape and M it times
        default  - the op as vLLM dispatches it (HIP skinny for M <= 5, Triton tiles of gfx12x above)
        split    - the HIP skinny op on chunks of <= 5 rows, outputs concatenated (a Python-only change)
        tuned    - the Triton kernel with the best tile of a small sweep at this M (only at the --sweep-ms values)
      and checks split and tuned against default (max abs diff). Random int4 weights, bf16 activations. One JSON row per shape and M is
      printed as it is made; the list is written to --out; the table of `summarize` is printed at the end.
  check <json> --shapes "..." --group-size N --ms "..." --sweep-ms "..."
      the validation of a result file before the worker records it: every row well formed (as `summarize`), EVERY expected (shape, M) pair
      EXACTLY once (no missing, doubled or unexpected pair: a row count alone would pass a duplicate standing in for a missing pair), and a
      tuned value in every row of a sweep M.
  summarize <json>
      the table of results § 12.1 (per M the sum over the shapes of <value>_us x layers, in ms), stdlib only, exact decimals.

Sources: dew_flow_benchmark research/vllm-r9700-speed-options/harness/linear_bench.py (the benchmark) and linear_bench_graph.py (the CUDA-graph
timer, here `--timer graph`, the default: the eager timer held Python and launch work, so its sum was not a decode time).

Exit codes: 0 done; 2 the arguments or the file are refused (one `linear: ...` line on stderr); 1 the run failed after the arguments were good.
"""
import argparse
import itertools
import json
import re
import sys
from decimal import ROUND_HALF_UP, Decimal

DEFAULT_GROUP_SIZE = 128
DEFAULT_MS = "1 2 3 4 5 6 8 10 12 16"
DEFAULT_SWEEP_MS = "6 8 12 16"
TIMERS = ("graph", "eager")
NAME_RE = re.compile(r"^[A-Za-z0-9._+-]+$")
# the tiles of the sweep (linear_bench.py line 31): (BLOCK_M, BLOCK_N, BLOCK_K, num_warps, num_stages); a constant of the kernel, not of the model
TILES = list(itertools.product([16], [16, 32, 64, 128], [32, 64, 128], [1, 2, 4, 8], [None, 1, 2]))
CALLS, REPLAYS = 20, 50  # the graph timer: calls captured into one graph, replays timed (linear_bench_graph.py line 15)
KEPT_K_MULTIPLE = 8  # the kernel reads k // 8 (linear_bench.py line 52)
SMALLEST_BLOCK_N = 16  # the smallest BLOCK_N of the sweep (line 31)


class LinearError(ValueError):
    """A refusal that names its reason; main prints it as `linear: <reason>` and exits 2."""


# ---- the arguments (stdlib only) ---------------------------------------------------------------------------------------------------------------------

def parse_ints(text, what):
    """The distinct positive integers of a whitespace-separated list."""
    words = text.split()
    if not words or not all(re.fullmatch(r"[1-9][0-9]{0,8}", word) for word in words):
        raise LinearError(f'{what} "{text}" is not a list of positive integers of at most 9 digits')
    values = [int(word) for word in words]
    if len(set(values)) != len(values):
        raise LinearError(f'{what} "{text}" repeats a value')
    return values


def _shape_problem(word, group_size):
    """The first thing wrong with one `<name>:<K>:<N>:<layers>` word, or None."""
    parts = word.split(":")
    if len(parts) != 4:
        return f'"{word}" is not <name>:<K>:<N>:<layers>'
    name, *numbers = parts
    if not NAME_RE.fullmatch(name):
        return f'the name "{name}" is not letters, digits, . _ + -'
    if not all(re.fullmatch(r"[1-9][0-9]{0,8}", number) for number in numbers):
        return f'"{word}": K, N and layers are positive integers'
    k, n, _layers = (int(number) for number in numbers)
    if k % KEPT_K_MULTIPLE or k % group_size:
        return f'"{word}": K {k} is not a multiple of 8 and of the group size {group_size}'
    if n % SMALLEST_BLOCK_N:
        return f'"{word}": N {n} is not a multiple of {SMALLEST_BLOCK_N}'
    return None


def parse_shapes(text, group_size):
    """[(name, K, N, layers)] from the words of LINEAR_SHAPES. One function for the container and for the checks: a group size of zero is refused
    by name before any `%` (the config's type keeps it above zero, but this is also called with an argument)."""
    if not isinstance(group_size, int) or group_size <= 0:
        raise LinearError(f"the group size {group_size} is not a positive integer")
    words = text.split()
    if not words:
        raise LinearError("--shapes holds no shape")
    for word in words:
        problem = _shape_problem(word, group_size)
        if problem:
            raise LinearError(problem)
    shapes = [(parts[0], int(parts[1]), int(parts[2]), int(parts[3])) for parts in (word.split(":") for word in words)]
    names = [shape[0] for shape in shapes]
    for name in names:
        if names.count(name) > 1:
            raise LinearError(f'the shape name "{name}" is given twice')
    return shapes


def check_run_arguments(args):
    """Everything `run` can refuse before it imports torch; returns (shapes, ms, sweep_ms)."""
    if args.timer not in TIMERS:
        raise LinearError(f'--timer "{args.timer}" is not one of: {" ".join(TIMERS)}')
    shapes = parse_shapes(args.shapes, args.group_size)
    ms = parse_ints(args.ms, "--ms")
    sweep = parse_ints(args.sweep_ms, "--sweep-ms")
    for m in sweep:
        if m not in ms:
            raise LinearError(f"sweep M {m} is not in --ms")
    return shapes, ms, sweep


# ---- summarize (stdlib only, exact decimals) ----------------------------------------------------------------------------------------------------------

def _number(row, key, index, required):
    """A finite number of a row as a Decimal, or None when the key is absent and not required."""
    if key not in row:
        if required:
            raise LinearError(f"row {index}: {key} is missing")
        return None
    value = row[key]
    if isinstance(value, bool) or not isinstance(value, (int, Decimal)) or not Decimal(value).is_finite():
        raise LinearError(f"row {index}: {key} is not a finite number")
    return Decimal(value)


def _positive_int(row, key, index):
    value = row.get(key)
    if isinstance(value, bool) or not isinstance(value, int) or value < 1:
        raise LinearError(f"row {index}: {key} is not a positive integer")
    return value


def _tile(row, index):
    tile = row.get("tuned_tile")
    ok = isinstance(tile, list) and len(tile) == 5 and all(item is None or (isinstance(item, int) and not isinstance(item, bool)) for item in tile)
    if not ok:
        raise LinearError(f"row {index}: tuned_tile is missing or is not a list of 5 integers or null")
    return tile


def check_rows(rows):
    """[{shape, layers, M, values: {default, triton_default, split?, tuned?}, tile?}] from the JSON list, or a LinearError naming row and key."""
    if not isinstance(rows, list) or not rows:
        raise LinearError("the file is not a non-empty JSON list of rows")
    checked = []
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise LinearError(f"row {index}: not an object")
        if not isinstance(row.get("shape"), str) or not row["shape"]:
            raise LinearError(f"row {index}: shape is missing or is not a name")
        entry = {"shape": row["shape"], "layers": _positive_int(row, "layers", index), "M": _positive_int(row, "M", index), "values": {},
                 "index": index, "K": row.get("K"), "N": row.get("N")}
        for key, required in (("default", True), ("triton_default", True), ("split", False), ("tuned", False)):
            value = _number(row, f"{key}_us", index, required)
            if value is not None:
                entry["values"][key] = value
        if "tuned" in entry["values"]:
            entry["tile"] = _tile(row, index)
        for key in ("split_maxdiff", "tuned_maxdiff"):
            _number(row, key, index, False)
        checked.append(entry)
    return checked


def _ms(value):
    """The sum of a column over its rows in ms with two decimals (half up), or `-` when some row of the M lacks the value."""
    return "-" if value is None else str((value / 1000).quantize(Decimal("0.01"), ROUND_HALF_UP))


def _column(rows, key):
    """The sum of <key>_us x layers over the rows, or None when a row lacks the value."""
    if any(key not in row["values"] for row in rows):
        return None
    return sum((row["values"][key] * row["layers"] for row in rows), Decimal(0))


def _change(default, tuned):
    if tuned is None or default == 0:
        return "-"
    return f"{int(((tuned - default) / default * 100).quantize(Decimal('1'), ROUND_HALF_UP)):+d} %"


def summarize_rows(rows):
    """The text of the table (the lines of § 12.1, then one tiles line per sweep M); the rows were checked by check_rows."""
    by_m = {}
    for row in rows:
        by_m.setdefault(row["M"], []).append(row)
    lines = ["M  default_ms  triton_default_ms  split_ms  tuned_ms  change"]
    for m in sorted(by_m):
        group = by_m[m]
        default, tuned = _column(group, "default"), _column(group, "tuned")
        cells = [_ms(default), _ms(_column(group, "triton_default")), _ms(_column(group, "split")), _ms(tuned), _change(default, tuned)]
        lines.append(f"{m}  " + "  ".join(cells))
    for m in sorted(by_m):
        tiles = [f"{row['shape']}={json.dumps(row['tile'])}" for row in by_m[m] if "tile" in row]
        if tiles:
            lines.append(f"tiles M={m}: " + " ".join(tiles))
    return "\n".join(lines)


def _constant(name):
    return Decimal(name)  # NaN and Infinity become non-finite numbers, which check_rows names


def _load_rows(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle, parse_float=Decimal, parse_constant=_constant)
    except (OSError, ValueError) as error:
        raise LinearError(f"{path}: cannot be read as JSON ({error})")


def check_pairs(rows, shapes, ms, sweep):
    """The reasons (empty when the rows are exactly the product of the shapes and the Ms, each once, with a tuned value at every sweep M)."""
    wanted = {shape[0]: shape for shape in shapes}
    counts = {}
    for row in rows:
        counts[(row["shape"], row["M"])] = counts.get((row["shape"], row["M"]), 0) + 1
    expected = [(shape[0], m) for shape in shapes for m in ms]
    reasons = []
    for pair in expected:
        if counts.get(pair, 0) == 0:
            reasons.append(f"missing ({pair[0]}, M {pair[1]})")
        elif counts[pair] > 1:
            reasons.append(f"duplicate ({pair[0]}, M {pair[1]})")
    reasons += [f"unexpected ({shape}, M {m})" for (shape, m) in counts if (shape, m) not in expected]
    for row in rows:
        if row["M"] in sweep and "tuned" not in row["values"]:
            reasons.append(f"no tuned_us in ({row['shape']}, M {row['M']}): a sweep M")
        if (row["shape"], row["M"]) in expected:
            reasons += _shape_mismatches(row, wanted[row["shape"]])
    return reasons


def _shape_mismatches(row, shape):
    """A row of a requested shape must carry that shape's K, N and layers: a result of another model or another file is not this experiment."""
    _name, k, n, layers = shape
    out = []
    for key, asked in (("K", k), ("N", n)):
        if not isinstance(row[key], int) or isinstance(row[key], bool):
            raise LinearError(f"row {row['index']}: {key} is missing or is not a whole number")
        if row[key] != asked:
            out.append(f"({row['shape']}, M {row['M']}): {key} is {row[key]}, not the requested {asked}")
    if row["layers"] != layers:
        out.append(f"({row['shape']}, M {row['M']}): layers is {row['layers']}, not the requested {layers}")
    return out


def command_check(args):
    shapes, ms, sweep = check_run_arguments(args)
    reasons = check_pairs(check_rows(_load_rows(args.file)), shapes, ms, sweep)
    if reasons:
        raise LinearError("; ".join(reasons))
    return 0


def summarize_file(path):
    return summarize_rows(check_rows(_load_rows(path)))


# ---- run (inside the container: torch, triton and vllm are imported here and nowhere else) ----------------------------------------------------------

class Kernels:
    """The imports of the image's vLLM, made once by `run`."""

    def __init__(self):
        import torch
        import triton
        import vllm._custom_ops as ops
        from vllm.model_executor.kernels.linear.mixed_precision import rdna_hybrid_w4a16 as rh
        from vllm.utils.platform_utils import num_compute_units

        self.torch, self.triton, self.ops, self.rh = torch, triton, ops, rh
        self.cu = num_compute_units()


def make_timer(kernels, timer):
    """bench(fn) -> microseconds per call: `eager` is triton's do_bench; `graph` captures CALLS calls into one CUDA graph and times the replay."""
    torch, triton = kernels.torch, kernels.triton
    if timer == "eager":
        return lambda fn: triton.testing.do_bench(fn, warmup=25, rep=100) * 1000.0

    def bench_graph(fn):
        side = torch.cuda.Stream()
        side.wait_stream(torch.cuda.current_stream())
        with torch.cuda.stream(side):
            for _ in range(3):  # compile and warm up outside the capture
                fn()
        torch.cuda.current_stream().wait_stream(side)
        graph = torch.cuda.CUDAGraph()
        with torch.cuda.graph(graph):
            for _ in range(CALLS):
                fn()
        graph.replay()
        torch.cuda.synchronize()
        start, end = torch.cuda.Event(enable_timing=True), torch.cuda.Event(enable_timing=True)
        times = []
        for _ in range(REPLAYS):
            start.record()
            graph.replay()
            end.record()
            end.synchronize()
            times.append(start.elapsed_time(end) * 1000.0 / CALLS)  # us per call
        del graph
        return sorted(times)[len(times) // 2]

    return bench_graph


def split_skinny(kernels, x, w_q, w_s, group_size):
    n_chunks = -(-x.shape[0] // kernels.rh.MAX_SKINNY_BATCH_SIZE)
    parts = kernels.torch.tensor_split(x, n_chunks, dim=0)
    return kernels.torch.cat([kernels.ops.wvSplitK_int4_g(w_q, p.contiguous(), w_s, kernels.cu, group_size, None, None) for p in parts], dim=0)


def triton_tile(kernels, x, w_q32, w_s, tile, group_size):
    bm, bn, bk, warps, stages = tile
    m, k = x.shape
    n = w_q32.shape[0]
    c = kernels.torch.empty((m, n), dtype=x.dtype, device=x.device)
    extra = {} if stages is None else {"num_stages": stages}
    kernels.rh._triton_w4a16_skinny_fmt_kernel[(kernels.triton.cdiv(m, bm), kernels.triton.cdiv(n, bn))](
        x, w_q32, w_s, w_s, c, m, n, k, k // 8, k // group_size, group_size=group_size, ZP_BIAS=8, HAS_ZP=False,
        BLOCK_M=bm, BLOCK_N=bn, BLOCK_K=min(bk, group_size), num_warps=warps, **extra)
    return c


def sweep_tiles(kernels, bench, x, w_q32, w_s, group_size):
    """(best us, best tile) over TILES; a tile Triton cannot compile for this shape is skipped with a stderr line."""
    timings = []
    for tile in TILES:
        try:
            triton_tile(kernels, x, w_q32, w_s, tile, group_size)
            timings.append((bench(lambda: triton_tile(kernels, x, w_q32, w_s, tile, group_size)), tile))
        except Exception as error:  # noqa: BLE001 - a tile Triton cannot compile is skipped
            print(f"skip tile {tile}: {type(error).__name__}", file=sys.stderr)
    return min(timings)


def measure_row(kernels, bench, spec, m, weights, sweep_ms, group_size):
    """One row dict (the keys and their order are those of the published JSON) for one shape and M."""
    torch, rh = kernels.torch, kernels.rh
    name, k, n, layers = spec
    w_q, w_s, w_q32 = weights
    cu = kernels.cu
    x = torch.randn((m, k), dtype=torch.bfloat16, device="cuda") * 0.1
    ref = torch.ops.vllm.rdna_hybrid_w4a16_apply(x, w_q, w_s, None, None, cu, group_size)
    row = {"shape": name, "K": k, "N": n, "layers": layers, "M": m,
           "default_us": bench(lambda: torch.ops.vllm.rdna_hybrid_w4a16_apply(x, w_q, w_s, None, None, cu, group_size)),
           "triton_default_us": bench(lambda: rh.triton_w4a16_skinny_fmt_gemm(x, w_q32, w_s, group_size))}
    if k * min(m, rh.MAX_SKINNY_BATCH_SIZE) <= rh.LDS_CAPACITY_ELEMENTS:
        out = split_skinny(kernels, x, w_q, w_s, group_size)
        row["split_us"] = bench(lambda: split_skinny(kernels, x, w_q, w_s, group_size))
        row["split_maxdiff"] = (out.float() - ref.float()).abs().max().item()
    if m in sweep_ms:
        best_us, tile = sweep_tiles(kernels, bench, x, w_q32, w_s, group_size)
        row["tuned_us"], row["tuned_tile"] = best_us, list(tile)
        row["tuned_maxdiff"] = (triton_tile(kernels, x, w_q32, w_s, tile, group_size).float() - ref.float()).abs().max().item()
    return row


def run_benchmark(shapes, group_size, ms, sweep_ms, timer):
    """The rows of the benchmark (printed as they are made)."""
    kernels = Kernels()
    torch = kernels.torch
    bench = make_timer(kernels, timer)
    torch.manual_seed(0)  # the same seed gives the same weights on every run
    rows = []
    for spec in shapes:
        _name, k, n, _layers = spec
        w_q = torch.randint(-128, 127, (n, k // 2), dtype=torch.int8, device="cuda")
        w_s = (torch.rand((n, k // group_size), dtype=torch.bfloat16, device="cuda") * 0.02 + 0.001).contiguous()
        weights = (w_q, w_s, w_q.view(torch.int32))
        for m in ms:
            rows.append(measure_row(kernels, bench, spec, m, weights, sweep_ms, group_size))
            print(json.dumps(rows[-1]), flush=True)
    return rows


def command_run(args):
    shapes, ms, sweep = check_run_arguments(args)  # every refusal comes before torch is imported
    rows = run_benchmark(shapes, args.group_size, ms, sweep, args.timer)
    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump(rows, handle, indent=1)
    print(summarize_file(args.out))
    return 0


def command_summarize(args):
    print(summarize_file(args.file))
    return 0


def add_workload_arguments(parser):
    parser.add_argument("--shapes", required=True)
    parser.add_argument("--group-size", type=int, default=DEFAULT_GROUP_SIZE)
    parser.add_argument("--ms", default=DEFAULT_MS)
    parser.add_argument("--sweep-ms", default=DEFAULT_SWEEP_MS)


def build_parser():
    parser = argparse.ArgumentParser(prog="linear_bench.py", description=__doc__.split("\n", 1)[0])
    commands = parser.add_subparsers(dest="command", required=True)
    run = commands.add_parser("run", help="the benchmark, inside the container")
    run.add_argument("--out", required=True)
    add_workload_arguments(run)
    run.add_argument("--timer", default="graph")
    run.set_defaults(handler=command_run)
    check = commands.add_parser("check", help="a result file against the shapes and Ms that were asked for")
    check.add_argument("file")
    add_workload_arguments(check)
    check.set_defaults(handler=command_check, timer="graph")
    summarize = commands.add_parser("summarize", help="the table of § 12.1 from a result file")
    summarize.add_argument("file")
    summarize.set_defaults(handler=command_summarize)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        return args.handler(args)
    except LinearError as error:
        print(f"linear: {error}", file=sys.stderr)
        return 2
    except Exception as error:  # noqa: BLE001 - a failure of the run itself, after the arguments were good
        print(f"linear: the run failed: {type(error).__name__}: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
