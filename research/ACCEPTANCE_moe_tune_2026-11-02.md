# Acceptance of `bin/r9700 moe-tune` on the R9700 — prepared 2026-11-02, RUN 2026-11-03 (quiet gate off, activate forced)

The flow that CI cannot run (`research/module_tests.md`): it needs the GPU, the real `wslc`, the real image, the model and the vendored benchmark. The
operator's session runs it before a release and pastes the output below. It was run on 2026-11-03 (the sections below); the prediction section is as it was written before the run, unchanged.

## Subject and conditions (fill in at the run)

| | |
|---|---|
| Subject (commit of this repository) | `d983327` (main after #8) |
| Harness | `bin/r9700` (verbs `init`, `moe-tune`) |
| Date of the run, machine | 2026-11-03 19:39–20:06 CET (chunk 19:39–19:57, merge and activate 19:57, A/B 19:58–20:06), the R9700 PC |
| Model file | `models/qwen3.6-35b-a3b-gptq.env`, unedited |
| Out | `acceptance-moe` (`<RESULTS_DIR>/acceptance-moe`) |
| Commands | those of the section below, each GPU command with `R9700_QUIET_CHECKS=1` and `QUIET_LOAD_MAX=16` in `machine.env` (the operator: "don't wait"); `activate` with `--force` (finding (b) below); the stamp of the merge was `20261103T185726Z` |
| Pinned, not varied | the image tag, the vendored benchmark (`vendor/benchmark_moe.py`, hash in `chunk.env`: `BENCHMARK_SHA256=1584d339831452d4…`), the coarse candidates (`CANDIDATES_SHA256=d23483de2f75986…`), the model file's `TUNED_CONFIG_DIR` (the production file of 2026-10-27, 9 keys) |
| Machine file | the operator's `machine.env` (not copied here: it holds the machine's paths) |
| The server at `activate` | `--force`, after the operator confirmed (with `wslc inspect vllm`) that the server does not mount the exchange folder; `activate.env` has `FORCED=yes` (finding (b) below) |
| Quiet gate | OFF by the operator's decision: one quiet check and a load limit of 16 (finding (c) below) |

## Commands

```bash
bin/r9700 init
bin/r9700 moe-tune chunk qwen3.6-35b-a3b-gptq --keys "24" --coarse --out acceptance-moe
bin/r9700 moe-tune merge qwen3.6-35b-a3b-gptq --out acceptance-moe experts-coarse-24
bin/r9700 moe-tune activate qwen3.6-35b-a3b-gptq <the stamp the merge printed> --out acceptance-moe
bin/r9700 moe-tune ab qwen3.6-35b-a3b-gptq --keys "8 12 16 24" --rule median --rule-keys "24" --out acceptance-moe
```

**Key 24 is the measured case.** Keys 8, 12 and 16 are regression coverage: they are in the production file and in the merged file with the same tiles, so their
change should be noise (key 32 is in neither file: vLLM would run it with the nearest key's tile, so it is not a regression key). A change there beyond ± 3 % would say the activated file broke a key it did not touch, not that key 24 is good or bad.

## Prediction, written BEFORE the run (measurement rule 4)

From `RESULTS_vllm_029_r9700_speed_options.md` § 14.1 (the coarse grid picked the current tile at every key, and the A/B was within ± 0.6 %):

- the chunk takes about 5 to 6 minutes (the four-key coarse chunk of 2026-11-01 took 1,244 s); its key 24 is `BLOCK 16/16/64, GROUP 1, 1 warp, 2 stages,
  waves_per_eu 4`, the same config as key 24 of the merged fixture `tests/fixtures/moe/b2/`.
- the merge writes a 10-key file: the 9 production keys plus 24. Its keys 1 to 16 and 256 to 2048 equal the production file's, and its key 24 equals the chunk's.
- `activate` prints `previous kept as none` (a fresh exchange folder) and `merged/activate.env` names the stamp.
- **the tuned arm loaded the activated file.** Every `tuned-<rep>.log` of the A/B holds the line
  `Using configuration from /work/r9700/moe/qwen3.6-35b-a3b-gptq/merged/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json for MoE layer`
  (the worker refuses to record the A/B without it). `ab.env` holds it as `B_CONFIG_LINE`; paste it, and `A_CONFIG_LINE` with it (what the default arm prints
  for the production folder).
- the A/B's key-24 change is within ± 1 % and the decision is `KERNEL: not faster (median change at 24: <±0.x> %)`; the three regression keys are within ± 1 %.
- the operator's server is stopped twice (one per GPU invocation: the chunk and the A/B) and is back, ready, after each; `activate` stops nothing.
- the cache clear line shows a size near 1 GB before the A/B (the chunk filled it), and the exit-path clear ran after each GPU invocation: two
  `cleanup hook: moe_cache_clear rc=0` lines in the two supervisor logs, each before its `restored` line.
- no `rejected/` folder.

What would make it wrong, and what it would mean:

- a different key-24 tile: the coarse grid is not deterministic across runs. Then the A/B decides, and either decision is a record.
- a key-24 change outside ± 3 %: the kernel timing on this day was noisy, or the file differs; read `ab.env`.
- a regression key outside ± 3 %: the file broke something it did not touch; read `B_CONFIG_LINE` and the merged file.
- a `tuned-<rep>.log` without the `Using configuration from <activated file>` line: the A/B is rejected, and the real log line is the evidence (the text of vLLM may differ).

## Observed: `init`

```
init: config: ok
init: results dir: ok
init: state dir: ok
init: wslc: ok
init: vllm: running
init: leftover containers: none
init: ram telemetry: ok (32058 MB)
init: disk telemetry: ok (record 4566)
rc=0
```

## Observed: the chunk

Command output (`start …` and `end …` are the operator's session's time stamps, in CET; the other times are UTC, `Z`), then `ls -R <RESULTS_DIR>/acceptance-moe/chunks`, `chunk.env` and `chunk.summary` (the terminal colour codes of the progress bar are removed; nothing else is cut):

```
start 2026-11-03 19:39:36
moe-tune: outdir <RESULTS_DIR>/acceptance-moe
2026-11-03T18:39:38Z coai-exp processes=0 load=8.31 quiet-checks=1/1
2026-11-03T18:39:38Z QUIET
2026-11-03T18:39:43Z disk gate: baseline 4566
2026-11-03T18:40:06Z failed try 1 of 3: admit stopping vllm failed (code 1)
2026-11-03T18:40:06Z coai-exp processes=0 load=18.07 quiet-checks=0/1 next check in 300 s
2026-11-03T18:45:06Z coai-exp processes=0 load=1.18 quiet-checks=1/1
2026-11-03T18:45:06Z QUIET
2026-11-03T18:45:09Z disk gate: OK: no new disk event (newest 4566)
2026-11-03T18:45:12Z admitted
2026-11-03T18:45:12Z worker started: session 1294529, start ticks 3480264
2026-11-03T18:51:43Z worker ended rc=0
recorded chunks/experts-coarse-24
2026-11-03T18:51:44Z cleanup hook: moe_cache_clear rc=0
restore: starting vllm with <RESTORE_SCRIPT_WIN>
vLLM patches active from <the start script's patch folder>: auto_gptq.py, gptq_utils.py, moe\ tuned config (see README.md there)
5486b6a0b86d0fe66076fdf68ee1b09119b48eb74a47ddc3026965f5346f6406
2026-11-03T18:57:11Z restored
rc=0
end 2026-11-03 19:57:11
--- ls -R <RESULTS_DIR>/acceptance-moe/chunks
<RESULTS_DIR>/acceptance-moe/chunks:
experts-coarse-24

<RESULTS_DIR>/acceptance-moe/chunks/experts-coarse-24:
E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json
chunk.env
chunk.log
chunk.summary
--- chunk.env
CHUNK=experts-coarse-24
LAYER=experts
SEARCH=coarse
KEYS=24
DTYPE=int4_w4a16
ACT_DTYPE=
BENCHMARK_SHA256=1584d339831452d4a568091e4d2a573dfed10200b04bdb4b49add37242698640
CANDIDATES_SHA256=d23483de2f75986046f3d36817cefa6cd3ea4a787a5b9c3c6ad2cee556d79273
HARNESS_SHA256=577e87b1058245c649daa54cca1abc0a119fc8b4fbbfc3c60de51511bd707f41
IMAGE=rocm/vllm:rocm10.1.0_ubuntu24.04_py3.14-pytorch_2.13.0_vllm-0.29.0
MODEL_DIR=/root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ
CONTAINER=r9700tune-moe-tune-experts-coarse-24
RUN_ID=20261103T183937Z-1267724
STARTED_AT=2026-11-03T18:45:14Z
FINISHED_AT=2026-11-03T18:51:41Z
SECONDS=387
RC=0
--- chunk.summary
Start tuning over 82 configurations...
                                                              (pid=396) : 100%|██████████| 79.0/79.0 [05:46<00:00, 8.40s/it](BenchmarkWorker pid=396) Tue Nov  3 18:51:36 2026] Completed tuning for batch_size=24
Traceback (most recent call last):
ImportError: sys.meta_path is None, Python is likely shutting down
```

Read back: the key-24 config of the chunk's JSON (the whole file, one key):

```
{
    "triton_version": "3.8.0",
    "24": {
        "BLOCK_SIZE_M": 16,
        "BLOCK_SIZE_N": 16,
        "BLOCK_SIZE_K": 64,
        "GROUP_SIZE_M": 1,
        "num_warps": 1,
        "num_stages": 2,
        "waves_per_eu": 4,
        "SPLIT_K": 1
    }
}
```

It is the config predicted: `BLOCK 16/16/64, GROUP 1, 1 warp, 2 stages, waves_per_eu 4`, and equal to key 24 of `tests/fixtures/moe/b2/` (compared with a short Python program). The size line of the cache clear before the chunk, the exit-path clear, and the supervisor log of the run folder `runs/20261103T183937Z-1267724` (steps/2.worker.log, guard/cleanup-hook.log, steps/2.ram_guard.log, supervisor.log):

```
=== 2026-11-03T18:45:13Z chunk experts-coarse-24 (experts, coarse, keys 24)
cache clear: running (ceiling 90 s)
cache before clear: 
  chunk experts-coarse-24: running 5 min
recorded chunks/experts-coarse-24
--- guard/cleanup-hook.log
cache clear: running (ceiling 90 s)
cache before clear: 78M /root/.cache/vllm/triton-moe-tune
--- steps/2.ram_guard.log
2026-11-03T18:45:15Z available RAM 63411 MB
2026-11-03T18:50:55Z available RAM 56886 MB
--- supervisor.log
2026-11-03T18:39:38Z coai-exp processes=0 load=8.31 quiet-checks=1/1
2026-11-03T18:39:38Z QUIET
2026-11-03T18:39:43Z disk gate: baseline 4566
2026-11-03T18:40:06Z failed try 1 of 3: admit stopping vllm failed (code 1)
2026-11-03T18:40:06Z coai-exp processes=0 load=18.07 quiet-checks=0/1 next check in 300 s
2026-11-03T18:45:06Z coai-exp processes=0 load=1.18 quiet-checks=1/1
2026-11-03T18:45:06Z QUIET
2026-11-03T18:45:09Z disk gate: OK: no new disk event (newest 4566)
2026-11-03T18:45:12Z admitted
2026-11-03T18:45:12Z worker started: session 1294529, start ticks 3480264
2026-11-03T18:51:43Z worker ended rc=0
2026-11-03T18:51:44Z cleanup hook: moe_cache_clear rc=0
2026-11-03T18:57:11Z restored
```

The chunk took 6 min 27 s in the container (`SECONDS=387`, `chunk.env`; the benchmark itself printed `Tuning took 354.55 seconds`), a little above the predicted "about 5 to 6 minutes" for one key. The traceback at the end of `chunk.summary` (`ImportError: sys.meta_path is None, Python is likely shutting down`) comes from `tqdm` at the interpreter exit, after `Writing best config` and `Tuning took`; the worker's rc was 0.

## Observed: the merge

```
moe-tune: outdir <RESULTS_DIR>/acceptance-moe
base: <WORK_DIR>/moe/tune/merged/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json
wrote <RESULTS_DIR>/acceptance-moe/merged/20261103T185726Z/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json: triton 3.8.0, keys [1, 2, 4, 8, 12, 16, 24, 256, 1024, 2048]
merged: 20261103T185726Z (activate it with: moe-tune activate qwen3.6-35b-a3b-gptq 20261103T185726Z --out acceptance-moe)
rc=0
--- merged/20261103T185726Z/merge.env
CHUNKS=experts-coarse-24
LAYER=experts
BASE=<WORK_DIR>/moe/tune/merged/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json
BASE_SHA256=072d25060edbc1b3c5d1ad6caaec59d7d6db99bb4208a14a49a1a9f565537839
OUTPUT_SHA256=a4905ebcee52b5e3244604a991cbd58eedff087ed5a7d690a2e3d467b4845f76
WRITTEN_AT=2026-11-03T18:57:26Z
```

The keys of the merged file are the ones the command printed: `[1, 2, 4, 8, 12, 16, 24, 256, 1024, 2048]`, with `triton_version` `3.8.0`. They were also compared, key by key, with the production file (`base:` above) and the chunk, with a short Python program.

Observed against predicted:

| | predicted | observed | held? |
|---|---|---|---|
| number of keys | 10 (the 9 production keys plus 24) | 10: `[1, 2, 4, 8, 12, 16, 24, 256, 1024, 2048]` | yes |
| keys 1 to 16 and 256 to 2048 | equal the production file's | all nine equal the production file's | yes |
| key 24 | equals the chunk's | equals the chunk's (and is the only key not in the production file) | yes |

## Observed: the activation

The first call, without `--force`, was refused, as the template expects when the server is listed; the second call used `--force`. The two calls' output as printed (the label lines are the operator's session's), then the supervisor log of the forced call's run folder and `activate.env` (it is in the exchange folder, `<WORK_DIR>/r9700/moe/qwen3.6-35b-a3b-gptq/merged/`, next to the activated file):

```
--- without --force (expected: refused, a server is listed)
moe-tune: outdir <RESULTS_DIR>/acceptance-moe
moe-tune: activate: vllm is running and may read <WORK_DIR>/r9700/moe/qwen3.6-35b-a3b-gptq/merged; stop it, or pass --force
rc=2
--- with --force (production reads <the start script's patch folder>\moe at /vllm-tuned-moe, not the exchange folder)
moe-tune: outdir <RESULTS_DIR>/acceptance-moe
2026-11-03T18:57:42Z activate: forced while vllm running
activated: <WORK_DIR>/r9700/moe/qwen3.6-35b-a3b-gptq/merged/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json (20261103T185726Z, sha256 a4905ebcee52; previous kept as none)
rc=0
--- supervisor.log of the forced call (runs/20261103T185742Z-1350663)
2026-11-03T18:57:42Z activate: forced while vllm running
--- <WORK_DIR>/r9700/moe/qwen3.6-35b-a3b-gptq/merged/activate.env
STAMP=20261103T185726Z
NAME=E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json
LAYER=experts
SHA256=a4905ebcee52b5e3244604a991cbd58eedff087ed5a7d690a2e3d467b4845f76
PREVIOUS=none
ACTIVATED_AT=2026-11-03T18:57:42Z
FORCED=yes
```

How the server was handled: `--force`, after the operator confirmed that the server does not mount the exchange folder. The reason, read with `wslc inspect vllm` by the operator's session (its output is not copied here): production mounts its MoE config from the start script's own patch folder (`<the start script's patch folder>\moe`) at `/vllm-tuned-moe`, and `VLLM_TUNED_CONFIG_FOLDER` is `/vllm-tuned-moe`. It does NOT mount the toolkit's exchange folder (`<WORK_DIR>/r9700/moe/<model>/merged`), so the forced activation could not change what production reads. `activate` printed `previous kept as none` and `activate.env` names the stamp, as predicted; it stopped nothing (no `stop` line in its log).

## Observed: the kernel A/B

Command output (`start …` and `end …` are the operator's session's time stamps, in CET), `summary.txt` (the same text as the output's `KERNEL:` line and the table above it), and the `B_CONFIG_LINE` and `A_CONFIG_LINE` of `ab.env`:

```
start 2026-11-03 19:58:27
moe-tune: outdir <RESULTS_DIR>/acceptance-moe
2026-11-03T18:58:27Z coai-exp processes=0 load=1.16 quiet-checks=1/1
2026-11-03T18:58:27Z QUIET
2026-11-03T18:58:31Z disk gate: baseline 4566
2026-11-03T18:58:45Z stopped the operator's server (stop 1 of 3)
2026-11-03T18:58:45Z admitted
2026-11-03T18:58:45Z worker started: session 1354509, start ticks 3561530
2026-11-03T19:02:26Z worker ended rc=0
recorded ab/20261103T185846Z
KERNEL: not faster (median change at 24: -0.2 %)
2026-11-03T19:02:26Z cleanup hook: moe_cache_clear rc=0
restore: starting vllm with <RESTORE_SCRIPT_WIN>
vLLM patches active from <the start script's patch folder>: auto_gptq.py, gptq_utils.py, moe\ tuned config (see README.md there)
0c8c982a9261b235fb005a23a4a75a989eb122b45b82eb5cff0efabc092745df
2026-11-03T19:06:10Z restored
rc=0
end 2026-11-03 20:06:10
--- ab/20261103T185846Z/summary.txt
bs  default_us  tuned_us  change   (median of reps)
 8      274.64    274.95    +0.1 %   n=3/3
12      352.40    351.87    -0.2 %   n=3/3
16      432.62    430.88    -0.4 %   n=3/3
24      566.77    565.47    -0.2 %   n=3/3
default bs 8 config: {'BLOCK_SIZE_M': 16, 'BLOCK_SIZE_N': 16, 'BLOCK_SIZE_K': 64, 'GROUP_SIZE_M': 4, 'num_warps': 1, 'num_stages': 2, 'waves_per_eu': 4, 'SPLIT_K': 1}
default bs 12 config: {'BLOCK_SIZE_M': 16, 'BLOCK_SIZE_N': 16, 'BLOCK_SIZE_K': 64, 'GROUP_SIZE_M': 1, 'num_warps': 1, 'num_stages': 2, 'waves_per_eu': 2, 'SPLIT_K': 1}
default bs 16 config: {'BLOCK_SIZE_M': 16, 'BLOCK_SIZE_N': 16, 'BLOCK_SIZE_K': 64, 'GROUP_SIZE_M': 1, 'num_warps': 1, 'num_stages': 2, 'waves_per_eu': 4, 'SPLIT_K': 1}
default bs 24 config: {'BLOCK_SIZE_M': 16, 'BLOCK_SIZE_N': 16, 'BLOCK_SIZE_K': 64, 'GROUP_SIZE_M': 1, 'num_warps': 1, 'num_stages': 2, 'waves_per_eu': 4, 'SPLIT_K': 1}
tuned bs 8 config: {'BLOCK_SIZE_M': 16, 'BLOCK_SIZE_N': 16, 'BLOCK_SIZE_K': 64, 'GROUP_SIZE_M': 4, 'num_warps': 1, 'num_stages': 2, 'waves_per_eu': 4, 'SPLIT_K': 1}
tuned bs 12 config: {'BLOCK_SIZE_M': 16, 'BLOCK_SIZE_N': 16, 'BLOCK_SIZE_K': 64, 'GROUP_SIZE_M': 1, 'num_warps': 1, 'num_stages': 2, 'waves_per_eu': 2, 'SPLIT_K': 1}
tuned bs 16 config: {'BLOCK_SIZE_M': 16, 'BLOCK_SIZE_N': 16, 'BLOCK_SIZE_K': 64, 'GROUP_SIZE_M': 1, 'num_warps': 1, 'num_stages': 2, 'waves_per_eu': 4, 'SPLIT_K': 1}
tuned bs 24 config: {'BLOCK_SIZE_M': 16, 'BLOCK_SIZE_N': 16, 'BLOCK_SIZE_K': 64, 'GROUP_SIZE_M': 1, 'num_warps': 1, 'num_stages': 2, 'waves_per_eu': 4, 'SPLIT_K': 1}
KERNEL: not faster (median change at 24: -0.2 %)
--- ab/20261103T185846Z/ab.env (the two lines)
A_CONFIG_LINE="Using configuration from /work/moe/tune/merged/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json for MoE layer"
B_CONFIG_LINE="Using configuration from /work/r9700/moe/qwen3.6-35b-a3b-gptq/merged/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json for MoE layer"
```

`grep 'Using configuration from' <RESULTS_DIR>/acceptance-moe/ab/20261103T185846Z/tuned-*.log`, and the same for `default-*.log` (the terminal colour codes in front of the log text are removed; the line is vLLM's, it ends with a full stop that `ab.env` does not keep):

```
<RESULTS_DIR>/acceptance-moe/ab/20261103T185846Z/tuned-1.log:(BenchmarkWorker pid=396) INFO 11-03 18:59:51 [fused_moe.py:1154] Using configuration from /work/r9700/moe/qwen3.6-35b-a3b-gptq/merged/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json for MoE layer.
<RESULTS_DIR>/acceptance-moe/ab/20261103T185846Z/tuned-2.log:(BenchmarkWorker pid=394) INFO 11-03 19:01:03 [fused_moe.py:1154] Using configuration from /work/r9700/moe/qwen3.6-35b-a3b-gptq/merged/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json for MoE layer.
<RESULTS_DIR>/acceptance-moe/ab/20261103T185846Z/tuned-3.log:(BenchmarkWorker pid=393) INFO 11-03 19:02:15 [fused_moe.py:1154] Using configuration from /work/r9700/moe/qwen3.6-35b-a3b-gptq/merged/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json for MoE layer.
<RESULTS_DIR>/acceptance-moe/ab/20261103T185846Z/default-1.log:(BenchmarkWorker pid=403) INFO 11-03 18:59:14 [fused_moe.py:1154] Using configuration from /work/moe/tune/merged/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json for MoE layer.
<RESULTS_DIR>/acceptance-moe/ab/20261103T185846Z/default-2.log:(BenchmarkWorker pid=396) INFO 11-03 19:00:27 [fused_moe.py:1154] Using configuration from /work/moe/tune/merged/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json for MoE layer.
<RESULTS_DIR>/acceptance-moe/ab/20261103T185846Z/default-3.log:(BenchmarkWorker pid=399) INFO 11-03 19:01:38 [fused_moe.py:1154] Using configuration from /work/moe/tune/merged/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json for MoE layer.
```

Every one of the three tuned logs holds `Using configuration from /work/r9700/moe/qwen3.6-35b-a3b-gptq/merged/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json for MoE layer.`, the file of the exchange folder that `activate` wrote (`B_SHA256` in `ab.env` is the `SHA256` of `activate.env`), and the default arm printed the production folder `/work/moe/tune/merged/…`. This is the benchmark's container reading the activated file (what the worker requires before it records), NOT the operator's own server.

Observed against predicted:

| | predicted | observed | held? |
|---|---|---|---|
| key 24 change | within ± 1 % | -0.2 % (566.77 µs default, 565.47 µs tuned, `n=3/3`) | yes |
| keys 8, 12, 16 | within ± 1 % | +0.1 %, -0.2 %, -0.4 % | yes |
| decision | `KERNEL: not faster (median change at 24: <±0.x> %)` | `KERNEL: not faster (median change at 24: -0.2 %)` | yes |
| the tuned arm loaded the activated file | every `tuned-<rep>.log` holds the line | 3 of 3 tuned logs hold it; `B_CONFIG_LINE` is the same text | yes |
| `A_CONFIG_LINE` | what the default arm prints | `Using configuration from /work/moe/tune/merged/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json for MoE layer` (3 of 3 default logs hold it, with a full stop) | (a result) |
| the two stops and restores | the server is stopped twice (chunk, A/B), back after each | chunk: the stop call returned 1 and the server was gone (finding (a)); A/B: `stopped the operator's server (stop 1 of 3)`; `restored` at 18:57:11Z and 19:06:10Z | **partly** |
| the cache clear before the A/B | near 1 GB (the chunk filled it) | empty: `cache before clear:` with nothing after it at the start of the A/B (the exit-path clear of the chunk had emptied the cache); the chunk's cache was `78M /root/.cache/vllm/triton-moe-tune`, the A/B's `1.9M /root/.cache/vllm/triton-moe-ab` | **no** |
| the exit-path clear | two `cleanup hook: moe_cache_clear rc=0` lines, each before its `restored` | 18:51:44Z (restored 18:57:11Z) and 19:02:26Z (restored 19:06:10Z) | yes |
| no `rejected/` folder | none | none in `acceptance-moe/` (`ab`, `chunks`, `merged`) | yes |

The key-24 result has a reading the prediction did not state: in `summary.txt` the default arm's config for batch size 24 is `16/16/64, GROUP 1, 1 warp, 2 stages, waves_per_eu 4`, the same as the tuned arm's. The production file has no key 24, and vLLM then takes the nearest key's tile, which is the one the coarse grid picked for key 24. So the A/B at key 24 compared one tile with itself and the -0.2 % is the noise of the benchmark; this is what § 14.1 recorded (the coarse grid picks the current tile).

## Findings the prediction did not have

**(a) The stop of the operator's server returned code 1 in 2 of the 6 admissions that had to stop it, and the server WAS stopped each time.** The six are the units of this day that found `vllm` listed: `linear-bench` (19:25 CET), the chunk (19:40), the A/B (19:58), `prefixtest` (20:06), run 1 (20:16) and run 2 (20:20) of the run record. Four stops returned 0. Two did not:

```
2026-11-03T18:25:35Z failed try 1 of 3: admit stopping vllm failed (code 1)     (linear-bench; runs/20261103T182511Z-1251184)
2026-11-03T18:40:06Z failed try 1 of 3: admit stopping vllm failed (code 1)     (the chunk;    runs/20261103T183937Z-1267724)
```

(Both lines are in the supervisor logs pasted in this record and in the `linear-bench` record.) After each, the next admission did NOT call a stop: it found the server not listed (its log has `disk gate: OK …` and `admitted` and no `stopped the operator's server` line, and no second stop was charged), and the unit then ran normally (`worker ended rc=0`) and the server was restored. So `wslc stop vllm` returned 1 and removed the container anyway. What it cost: a failed try each (1 of 3), 3 seconds for `linear-bench`, and 5 minutes 6 seconds for the chunk (its quiet phase ran again, read load 18.07 against the limit of 16, `quiet-checks=0/1`, and waited 300 s). With `MAX_FAILED_TRIES=1`, as in run 1 of the run record, the same stop would have ended the step with exit 7 after a stop that had worked; the restore still runs, so the server would have come back.

**The cause is NOT known.** `wslc_stop` in `lib/adapter.sh` discards wslc's output (`> /dev/null`) and the step logs only the code, so what wslc printed on those two calls is lost. Not checked: that text, whether `wslc stop` returns 1 for a container that is still on its way out, whether the time since the last start of the container matters. The two failures were the first two stop calls of the day and the next four returned 0; that is two observations and says nothing about a rate or a cause. The toolkit change that follows from this (the output of the stop is kept and logged on a failure; after a non-zero stop the step lists again and counts a server that is gone as stopped) was made on the branch that carries this record, tested against the stub only; the PC was not run again.

**(b) `activate` was refused without `--force` and run WITH `--force`.** The refusal is the code's rule: the server is listed and "may read" the exchange folder. The operator's session then checked with `wslc inspect vllm` that this server mounts its MoE config from the start script's patch folder at `/vllm-tuned-moe` (`VLLM_TUNED_CONFIG_FOLDER=/vllm-tuned-moe`), not the exchange folder, and forced the activation; `activate.env` has `FORCED=yes`. The consequence is the one `POST_DEPLOY.md` item 12 names: the file `activate` wrote is read by the toolkit's own A/B container (above), and is NOT read by this machine's production server, whose mount is another folder. Getting the merged file into production would be a copy into the patch folder's `moe` folder; this run did not do it.

**(c) The quiet gate was off by the operator's decision.** Every command of the day ran with `R9700_QUIET_CHECKS=1` and `QUIET_LOAD_MAX=16` in `machine.env` ("don't wait"): one read, load limit 16, instead of three reads 300 s apart. It was not fully off: at the chunk's second read the 1-minute load was 18.07, above the limit, and the supervisor waited one 300 s step (`quiet-checks=0/1 next check in 300 s`, then load 1.18, `QUIET`). The loads read at the quiet checks of the day were 0.58, 1.09, 8.31, 18.07, 1.18, 1.16, 1.68, 2.85, 0.79 and 0.45, so only the chunk's window was busy (the cause of that load is not recorded). The loads read just before the two timed windows were 1.18 (chunk) and 1.16 (A/B); none was read during them, and neither window was preceded by three quiet reads.

## Questions the run answers

- Does a foreground `wslc run --rm --name <name>` appear in `wslc list` while it runs, and does `wslc stop <name>` end it? (E2.S2 decision 9 and the refusal of
  `activate` rest on it; UNVERIFIED.) Answer: NOT answered. No `wslc list` was taken during the chunk or any other unit of the day. (Run 1 of the run record shows a DETACHED prefixed container listed and stopped by name by the guard; that is another call.) The refusal of `activate` did not rest on a foreground container: it listed the operator's own `vllm`.
- Does the clear container's `du` print what the code expects (one line per cache folder, in `cache before clear: …`)? Answer: yes, one comma-joined entry per folder that exists: `cache before clear: 78M /root/.cache/vllm/triton-moe-tune` (exit of the chunk), `cache before clear: 1.9M /root/.cache/vllm/triton-moe-ab` (exit of the A/B), `cache before clear: 4.7M /root/.cache/vllm/triton-moe-ab,135M /root/.cache/vllm/triton-linear` (the start of `linear-bench`); and `cache before clear: ` with nothing when no folder exists (the start of the chunk and of the A/B).
- What does the default arm print for a folder that holds the file (`A_CONFIG_LINE`)? Answer: `Using configuration from /work/moe/tune/merged/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json for MoE layer` (vLLM adds a full stop at the end of the log line).
- Is hook 3 observed? No: a draft chunk is not in this run (`--layer draft`); it stays unobserved until a draft chunk runs on the machine.
- Did every guard stay quiet? Answer: no guard stopped any step. The RAM guard read 63411 MB (chunk) and 37953 MB (A/B) at its first read; the disk gate printed `baseline 4566` then `OK: no new disk event`; no deadline watcher fired. The quiet phase printed one `quiet-checks=0/1` (the chunk, load 18.07) and the stop of the operator's server returned code 1 twice in the day (finding (a)).

## What this record does not settle

One key, one model, one night. It does not tune keys by a full search, does not run the draft layer (hook 3), and says nothing about the 27B model (its file
may need `MOE_DTYPE=none`; whether it has MoE layers is not known here). A decision of "not faster" is a result, not a failure.
It also does not show that the operator's own server reads the activated file: this machine's server mounts another folder (finding (b)), and the one thing read from the activated file here is the benchmark's container.
