# vendor/ — the MoE tuning benchmark, upstream plus three local changes

## What this is

`benchmark_moe.py` is vLLM's own MoE kernel benchmark and tuner, with three small local changes (below). The toolkit runs it inside the
container for two jobs: **tuning** (`--tune`, one chunk of batch sizes at a time) and the **kernel A/B** (no `--tune`: it times the config
that vLLM picks, 100 iterations per batch size).

| | |
|---|---|
| Upstream | vLLM `main`, commit `2c880f1e68200f79c4663dd0f1e7beab6f536cfa` |
| Upstream path | `benchmarks/kernels/benchmark_moe.py` (1169 lines) |
| Upstream sha256 | `8e4d60d12f5ccee9a5b66fe7b50bba7a9525b7edea0b6750eb9d46d71f788f83` (also in `vendor/UPSTREAM`) |
| This file | `vendor/benchmark_moe.py`, 1173 lines, sha256 `1584d339831452d4a568091e4d2a573dfed10200b04bdb4b49add37242698640` |
| Copied from | `<WORK_DIR>/moe/benchmark_moe.py` on the operator's PC: the copy that ran the B1 chunks and the B2 run of 2026-10-28..11-01 |
| Licence | Apache-2.0, the same as this repository. The header of the file (the two `SPDX` lines) is kept as upstream wrote it |

The file is copied byte for byte. `tests/test_vendor.sh` proves it is upstream plus the diff below and nothing else: `patch -R` over this
file gives back a file whose sha256 is the upstream hash above. Upstream itself is never stored here, only its hash. To move to a newer
upstream, re-apply the three changes to the new file, write the new diff, and change this README, `vendor/UPSTREAM` and the diff together.

## The three hooks

Each change is marked with the words `LOCAL CHANGE` in an added comment line.

1. **No `HIP_VISIBLE_DEVICES` to `ROCR_VISIBLE_DEVICES` rename.** Upstream replaces the first by the second before `ray.init()`. Ray 2.59 in the
   `rocm/vllm` image refuses `ROCR_VISIBLE_DEVICES`, and without `HIP_VISIBLE_DEVICES` Ray also schedules a worker on the integrated GPU. The
   nine lines of the rename are replaced by a four-line comment, so `HIP_VISIBLE_DEVICES=0`, as the caller sets it, stays. Where: `main`, after
   `use_deep_gemm = ...`. Source: the measured work of 2026-10-26, `RESULTS_vllm_029_r9700_fixes.md` § 3.
2. **`MOE_TUNE_CANDIDATES`.** When the variable names a file, the JSON list in that file replaces the search space (the ROCm pruning still
   applies per batch size). This is the coarse search: `config/coarse_candidates.json` has 82 candidates, which tunes a batch size in minutes
   where the full space takes hours. Where: `main`, after `search_space = get_configs_compute_bound(...)`. Source: the same § 3.
3. **`MOE_TUNE_ACT_DTYPE`.** In `resolve_dtype`, upstream forces `float16` activations on ROCm. With `MOE_TUNE_ACT_DTYPE=bfloat16` it returns
   `torch.bfloat16`, so the BF16 draft (MTP) experts are tuned with the activations they really run with. Where: the top of `resolve_dtype`.
   Source: `RESULTS_vllm_029_r9700_speed_options.md` § 11.4 and the speed-options notes on the code facts.

## The diff

Upstream to this file, as `diff -u`. The block below is `vendor/hooks.diff` verbatim (a test compares them).

```diff
--- a/benchmark_moe.py
+++ b/benchmark_moe.py
@@ -922,6 +922,10 @@
 
 
 def resolve_dtype(config) -> torch.dtype:
+    # LOCAL CHANGE (vllm_pr_work speed-options plan, 2026-10-27): MOE_TUNE_ACT_DTYPE=bfloat16 tunes the
+    # BF16 MTP draft experts with BF16 activations instead of ROCm's fixed fp16.
+    if os.environ.get("MOE_TUNE_ACT_DTYPE") == "bfloat16":
+        return torch.bfloat16
     if current_platform.is_rocm():
         return torch.float16
 
@@ -1029,15 +1033,10 @@
 
     use_deep_gemm = bool(args.use_deep_gemm)
 
-    if current_platform.is_rocm() and "HIP_VISIBLE_DEVICES" in os.environ:
-        # Ray will set ROCR_VISIBLE_DEVICES for device visibility
-        logger.warning(
-            "Ray uses ROCR_VISIBLE_DEVICES to control device accessibility."
-            "Replacing HIP_VISIBLE_DEVICES with ROCR_VISIBLE_DEVICES."
-        )
-        val = os.environ["HIP_VISIBLE_DEVICES"]
-        os.environ["ROCR_VISIBLE_DEVICES"] = val
-        del os.environ["HIP_VISIBLE_DEVICES"]
+    # LOCAL CHANGE (vllm_pr_work plan 2, 2026-10-26): the HIP->ROCR rename is removed. Ray 2.59 in
+    # the rocm/vllm image raises "Please use HIP_VISIBLE_DEVICES instead of ROCR_VISIBLE_DEVICES"
+    # (ray/_private/accelerators/amd_gpu.py:46), and without HIP_VISIBLE_DEVICES Ray also schedules a
+    # worker on the 890M iGPU. HIP_VISIBLE_DEVICES=0 is kept as set by the caller.
 
     ray.init()
     num_gpus = int(ray.available_resources()["GPU"])
@@ -1064,6 +1063,11 @@
         # search space (e.g. BLOCK_SIZE_K=64 with group_size=128).
         tune_block_quant_shape = None if use_int4_w4a16 else block_quant_shape
         search_space = get_configs_compute_bound(is_fp16, tune_block_quant_shape)
+        # LOCAL CHANGE (vllm_pr_work plan 2, 2026-10-26): optional fixed candidate list for a
+        # coarse large-M sweep; the ROCm pruning below still applies per batch size.
+        if os.environ.get("MOE_TUNE_CANDIDATES"):
+            with open(os.environ["MOE_TUNE_CANDIDATES"]) as f:
+                search_space = json.load(f)
         if use_int4_w4a16:
             # SPLIT_K is a required kernel constexpr for gptq_awq kernel;
             # only SPLIT_K=1 is used at runtime, so fix it during tuning.
```

## How it is used

The supervisor's tuning commands (a later story, `moe-tune`) place this file under `WORK_DIR/r9700/` with its hash checked, and the container
runs it from `/work/r9700`. Nothing else in the repository imports it, and no test runs it: it needs a GPU and the vLLM image.

## Verified on the machine

Empty until the acceptance run of the MoE tuning story is done on the R9700.

- Hooks 1 and 2: observed in the work of 2026-10-26..11-01 (the chunks and the B2 run ran with this file); not yet observed through the toolkit.
- Hook 3 (`MOE_TUNE_ACT_DTYPE`) has NOT yet been observed on the machine through the toolkit. It is known only by its effect, in the B1 draft-layer chunks of
  2026-10-28..31 (BF16 activations; the kernel A/B of the draft layer ran with `MOE_TUNE_ACT_DTYPE=bfloat16`). The acceptance run does not run a draft-layer chunk,
  so it stays unobserved until one runs.
