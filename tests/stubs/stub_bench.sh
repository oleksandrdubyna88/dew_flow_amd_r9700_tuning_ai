#!/usr/bin/env bash
# The ComfyUI bench part of the wslc stub (E2.S2): the container of one arm-round, the `exec` of comfyui/bench.py with scripted answers, the clean stop, the cache clear and the
# report, the model listing and the widened readiness answer. SOURCED by tests/stubs/wslc after stub_common.sh (which lists every answer file in its header), never run. It reads
# and writes only below $R9700_STUB_DIR and $R9700_WORK_DIR (the folder the real containers see as /work); it never runs bench.py: a run is a scripted answer.

# bench_answer <file name> <default>: the first line of answers/<file name>, else the default (a missing file is NOT an error here, unlike stub_answer)
bench_answer() { moe_answer "$@"; }

# bench_vram_line: the line for this probe call: answers/comfy_vram, call k takes line k, the last repeats; default `34000000000 34359738368`; the word `none` is "not in the answer"
bench_vram_line() {
  if [ -f "$R9700_STUB_DIR/answers/comfy_vram" ]; then stub_answer comfy_vram; else echo "34000000000 34359738368"; fi
}

# comfy_ready_ok: the answer of the widened ComfyUI probe when answers/comfy_ready says ok: device, vram_free, vram_total (or the one `vram:` line), ready
comfy_ready_ok() {
  local free total line
  line="$(bench_vram_line)"
  printf 'device cuda:0 AMD Radeon AI PRO R9700 : native%s\n' "$CRLF"
  if [ "$line" = none ]; then
    printf 'vram: not in the answer%s\n' "$CRLF"
  else
    read -r free total <<< "$line"
    printf 'vram_free %s%s\nvram_total %s%s\n' "$free" "$CRLF" "$total" "$CRLF"
  fi
  printf 'ready%s\n' "$CRLF"
}

# comfy_bench_is <argv...>: 0 when the exec words are `[env KEY=VALUE...] python3 <path>/bench.py <command> ...` (sets BENCH_ARGS to the words from bench.py on)
comfy_bench_is() {
  BENCH_ARGS=()
  while [ "${1:-}" = env ] || [[ ${1:-} == [A-Z_]*=* ]]; do shift; done
  [ "${1:-}" = python3 ] && [[ ${2:-} == */bench.py ]] || return 1
  shift 2
  BENCH_ARGS=("$@")
}

# comfy_clean_stop_is <argv...>: `python3 -c <program naming SIGINT>`: the worker's clean stop of a bench container
comfy_clean_stop_is() { [ "${1:-}" = python3 ] && [ "${2:-}" = -c ] && [[ ${3:-} == *SIGINT* ]]; }

# comfy_clean_stop <name>: SIGINT to the container's server: it ends like a stop (and the test's on-stop hook runs) unless answers/comfy_clean_stop says `ignore`
comfy_clean_stop() {
  [ "$(bench_answer comfy_clean_stop clean)" = ignore ] && return 0
  stub_container_stop "$1" > /dev/null 2>&1
  [ -f "$R9700_STUB_DIR/on-stop-$1" ] && bash "$R9700_STUB_DIR/on-stop-$1"
  return 0
}

# bench_mode <arm> <run>: the scripted mode of a run: answers/comfy_bench_mode.<arm>.<run>, else .<run>, else ok
bench_mode() {
  if [ -f "$R9700_STUB_DIR/answers/comfy_bench_mode.$1.$2" ]; then bench_answer "comfy_bench_mode.$1.$2" ok
  else bench_answer "comfy_bench_mode.$2" ok; fi
}

# bench_lines_of <tag> <workflow> <run>: the three lines of a measured run: answers/comfy_bench_lines (lines `r=<n> <metric>: <value>`, the tag and the workflow put in front) or the defaults
bench_lines_of() {
  local tag="$1" workflow="$2" run="$3" file="$R9700_STUB_DIR/answers/comfy_bench_lines"
  if [ -f "$file" ]; then
    awk -v p="$tag $workflow " -v g="r=$run " -v crlf="$CRLF" 'index($0, g) == 1 { printf "%s%s%s\n", p, $0, crlf }' "$file"
  else
    awk -v p="$tag $workflow r=$run " -v n="$run" -v crlf="$CRLF" 'BEGIN { d = (n - 1) * 0.010; printf "%stotal_s: %.3f%s\n%ssampler_s: %.3f%s\n%svae_s: %.3f%s\n", p, 12.345 + d, crlf, p, 10.000 + d, crlf, p, 1.500 + d, crlf }'
  fi
}

# bench_evidence <arm>: the log lines of the cold run: answers/comfy_evidence.<arm> (even an empty file) or the activation lines of the arm's row of comfyui/arm_evidence.conf
bench_evidence() {
  local file="$R9700_STUB_DIR/answers/comfy_evidence.$1"
  if [ -f "$file" ]; then cat "$file"; return 0; fi
  case $1 in
    base) echo "Using pytorch attention" ;;
    fp16acc) echo "Enabled fp16 accumulation." ;;
    fp8wmm) echo "model weight dtype torch.float8_e4m3fn, manual cast: torch.bfloat16" ;;
    miopen) echo "MIOpen(HIP): Info [Find] FindConvFwdAlgorithm fast find" ;;
  esac
}

# bench_json <arm> <run> <workflow> <tag>: run-<run>.json: the keys the worker reads (nodes, cached_nodes, server_argv, cache_after, cold) over answers/comfy_bench_json
bench_json() {
  local arm="$1" run="$2" workflow="$3" tag="$4" nodes_file="$R9700_STUB_DIR/answers/comfy_bench_nodes.$2" cache_file="$R9700_STUB_DIR/answers/comfy_bench_cache" over="$R9700_STUB_DIR/answers/comfy_bench_json"
  python3 -c '
import json, os, sys
arm, run, workflow, tag, nodes_file, cache_file, over = sys.argv[1:8]
# a real measured run (observed shape): the execution cache of ComfyUI reuses the loaders, the text encoding and the compile node, so only the sampler, the decode and the save are `executing`;
# the cold run executes everything. answers/comfy_bench_nodes.<run> replaces the executed list and leaves nothing cached.
loaders = [("unet", "UNETLoader"), ("clip", "CLIPLoader"), ("vaeload", "VAELoader"), ("pos", "CLIPTextEncode")]
if arm == "compile":
    loaders.insert(1, ("compile", "TorchCompileModel"))
tail = ["KSampler", "VAEDecode", "SaveImage"]
if run == "cold":
    nodes, cached = [c for _, c in loaders] + tail, []
else:
    nodes, cached = tail, loaders
if os.path.isfile(nodes_file):
    nodes, cached = open(nodes_file).read().split(), []
argv = ["main.py"] + (["--fast", "fp8_matrix_mult"] if arm == "fp8wmm" else []) + (["--fast", "fp16_accumulation"] if arm == "fp16acc" else [])
cache = {"inductor": 3 if arm == "compile" else 0}
if os.path.isfile(cache_file):
    cache = {line.split()[0]: int(line.split()[1]) for line in open(cache_file) if line.strip()}
doc = {"tag": tag, "workflow": workflow, "run": run, "cold": run == "cold", "nodes": nodes, "cached_nodes": [i for i, _ in cached], "cached_types": [c for _, c in cached], "server_argv": argv,
       "cache_after": {k: {"files": v, "bytes": v * 1000} for k, v in cache.items()}, "total_s": 40.0 if run == "cold" else 12.345}
if os.path.isfile(over):
    doc.update(json.load(open(over)))
json.dump(doc, open(sys.argv[8], "w"))
' "$arm" "$run" "$workflow" "$tag" "$nodes_file" "$cache_file" "$over" "$5"
}

# comfy_drift_answer <workflow> <bench.py words...>: `drift --out <dir> --ref <dir>` by what the two folders hold: per seed the file `<workflow>_r<n>_*` of each; identical content: `mad 0.000 psnr
# identical`; another content: `mad 1.000 psnr 48.131`; a file missing: `unavailable (...)`, as the program says. answers/comfy_drift replaces all three lines. The stub images of one workflow and run have
# one content whatever the arm, so a same-seed pair is identical.
comfy_drift_answer() {
  local workflow="$1" out="" ref="" prev="" arg n a b
  shift
  [ -f "$R9700_STUB_DIR/answers/comfy_drift" ] && { sed "s/\$/$CRLF/" "$R9700_STUB_DIR/answers/comfy_drift"; return 0; }
  for arg in "$@"; do
    [ "$prev" = --out ] && out="${R9700_WORK_DIR:?}/${arg#/work/}"
    [ "$prev" = --ref ] && ref="${R9700_WORK_DIR:?}/${arg#/work/}"
    prev="$arg"
  done
  for n in 1 2 3; do
    a="$(ls "$out"/"${workflow}_r${n}_"* 2> /dev/null | head -n 1)"
    b="$(ls "$ref"/"${workflow}_r${n}_"* 2> /dev/null | head -n 1)"
    if [ -z "$a" ]; then printf 'drift r=%s: unavailable (the output of seed %s is missing)%s\n' "$n" "$n" "$CRLF"
    elif [ -z "$b" ]; then printf 'drift r=%s: unavailable (the reference of seed %s is missing)%s\n' "$n" "$n" "$CRLF"
    elif cmp -s "$a" "$b"; then printf 'drift r=%s: mad 0.000 psnr identical%s\n' "$n" "$CRLF"
    else printf 'drift r=%s: mad 1.000 psnr 48.131%s\n' "$n" "$CRLF"; fi
  done
}

# comfy_bench_call <name> <argv...>: `exec <name> [env ...] python3 <...>/bench.py <command> ...`: run (a scripted run), drift (scripted lines) or check
comfy_bench_call() {
  local name="$1" command="${BENCH_ARGS[0]:-}" workflow="${BENCH_ARGS[1]:-}" tag="" run="" out="" mode word seconds prev="" arg arm i
  shift
  for arg in "${BENCH_ARGS[@]}"; do
    [ "$prev" = --tag ] && tag="$arg"
    [ "$prev" = --run ] && run="$arg"
    [ "$prev" = --out ] && out="$arg"
    prev="$arg"
  done
  case $command in
    drift) comfy_drift_answer "$workflow" "${BENCH_ARGS[@]}"; return 0 ;;
    check) printf 'OUTPUT ok: stub%s\n' "$CRLF"; return 0 ;;
    run) ;;
    *) echo "stub: bench.py: unknown command \"$command\"" >&2; return 2 ;;
  esac
  arm="${tag%-*}"
  mkdir -p "${R9700_WORK_DIR:?}/${out#/work/}" 2> /dev/null
  stub_mkdir "$R9700_STUB_DIR/logs.d"
  # the server's log grows with the run: the evidence first (cold run only), then the scripted lines of this run
  { [ "$run" = cold ] && bench_evidence "$arm"; [ -f "$R9700_STUB_DIR/answers/comfy_bench_log.$run" ] && cat "$R9700_STUB_DIR/answers/comfy_bench_log.$run"; } >> "$R9700_STUB_DIR/logs.d/$name" 2> /dev/null
  mode="$(bench_mode "$arm" "$run")"
  read -r word seconds <<< "$mode"
  case $word in
    hang) stub_hang ;;
    slow)
      sleep "${seconds:-1}" < /dev/null > /dev/null 2>&1 &
      stub_record_pid "$R9700_STUB_DIR/hung/containers/$(stub_next hung || echo 0).pid" "$!"
      wait "$!"
      ;;
    error) printf 'EXECUTION_ERROR: node sampler (KSampler): boom%s\n' "$CRLF"; return 1 ;;
    constant) printf 'OUTPUT: the image is constant (every pixel 128)%s\n' "$CRLF"; return 1 ;;
    cached) printf 'CACHED: the sampler did not execute (cached: sampler)%s\n' "$CRLF"; return 1 ;;
    refused) printf 'PROMPT: refused: x%s\n' "$CRLF"; return 1 ;;
    cold_timeout) printf 'COLD_TIMEOUT 1801.0%s\n' "$CRLF"; return 3 ;;
    run_timeout) printf 'RUN_TIMEOUT 601.0%s\n' "$CRLF"; return 3 ;;
  esac
  bench_json "$arm" "$run" "$workflow" "$tag" "${R9700_WORK_DIR:?}/${out#/work/}/run-$run.json"
  printf 'stub image %s %s\n' "$workflow" "$run" > "${R9700_WORK_DIR:?}/${out#/work/}/${workflow}_r${run}_00001_.png"
  if [ "$run" = cold ]; then printf 'cold: total 40.000 s%s\n' "$CRLF"; else bench_lines_of "$tag" "$workflow" "$run"; fi
  return 0
}

# the foreground containers of the arm-round --------------------------------------------------------------------------------------------------------------
# comfy_clear_is / comfy_report_is / comfy_listing_is <argv...>: the program after `-c` decides which throwaway container it is
comfy_program_of() {
  local arg prev="" entry=no seen=no skip=1
  COMFY_PROGRAM="" COMFY_REST=()
  for arg in "$@"; do
    if [ "$seen" = yes ]; then
      if [ "$skip" -eq 1 ]; then skip=0; else COMFY_REST+=("$arg"); fi # the word after the program is $0 of `sh -c`; the rest are its arguments
    fi
    [ "$prev" = --entrypoint ] && [ "$arg" = sh ] && entry=yes
    if [ "$prev" = -c ] && [ "$seen" = no ]; then COMFY_PROGRAM="$arg"; seen=yes; fi
    prev="$arg"
  done
  [ "$entry" = yes ] && [ -n "$COMFY_PROGRAM" ]
}
comfy_clear_is() { comfy_program_of "$@" && [[ $COMFY_PROGRAM == */cache/tunableop* && $COMFY_PROGRAM == *"rm -rf"* ]]; }
comfy_report_is() { comfy_program_of "$@" && [[ $COMFY_PROGRAM == *tunableop_results* && $COMFY_PROGRAM != *"rm -rf"* ]]; }
comfy_listing_is() { comfy_program_of "$@" && [[ $COMFY_PROGRAM == */models/* && $COMFY_PROGRAM == *stat* ]]; }

# comfy_clear_answer: the clear: prints answers/comfy_cache (default four du lines) with CRLF, empties $STUB/cache, exits answers/comfy_clear_rc (default 0)
comfy_clear_answer() {
  if [ -f "$R9700_STUB_DIR/answers/comfy_cache" ]; then sed "s/\$/$CRLF/" "$R9700_STUB_DIR/answers/comfy_cache"
  else printf '12\t/cache/miopen%s\n4\t/cache/triton%s\n0\t/cache/tunableop%s\n0\t/cache/inductor%s\n' "$CRLF" "$CRLF" "$CRLF" "$CRLF"; fi
  rm -rf "${R9700_STUB_DIR:?}/cache"
  return "$(bench_answer comfy_clear_rc 0)"
}

# comfy_report_answer: the report after a clean stop: answers/comfy_cache_report (default four du lines), then, when answers/comfy_tunableop exists, `--- <name>` and its lines; the name is
# answers/comfy_tunableop_name (default tunableop_results0.csv: TunableOp writes the device number before the extension)
comfy_report_answer() {
  if [ -f "$R9700_STUB_DIR/answers/comfy_cache_report" ]; then sed "s/\$/$CRLF/" "$R9700_STUB_DIR/answers/comfy_cache_report"
  else printf '1200\t/cache/miopen%s\n400\t/cache/triton%s\n4\t/cache/tunableop%s\n0\t/cache/inductor%s\n' "$CRLF" "$CRLF" "$CRLF" "$CRLF"; fi
  if [ -f "$R9700_STUB_DIR/answers/comfy_tunableop" ]; then
    printf -- '--- %s%s\n' "$(bench_answer comfy_tunableop_name tunableop_results0.csv)" "$CRLF"
    sed "s/\$/$CRLF/" "$R9700_STUB_DIR/answers/comfy_tunableop"
  fi
  return "$(bench_answer comfy_report_rc 0)"
}

# comfy_listing_answer <files...>: `<folder>/<file> <size>` for every file asked (the arguments after the program), or answers/comfy_models_listing
comfy_listing_answer() {
  local file
  if [ -f "$R9700_STUB_DIR/answers/comfy_models_listing" ]; then sed "s/\$/$CRLF/" "$R9700_STUB_DIR/answers/comfy_models_listing"; return 0; fi
  for file in "$@"; do [[ $file == dir:* ]] || printf '%s 1000%s\n' "$file" "$CRLF"; done # a `dir:<folder>` word is a folder check: every folder exists unless the scripted listing says missing-dir
}
