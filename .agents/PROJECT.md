---
requires: ["README.md"]
---
# Project instructions — dew_flow_amd_r9700_tuning_ai

Shared family rules are mounted at `.agents/conventions` (the `dew_flow_conventions` submodule, tracking
its `release` branch) and apply here exactly as local rules would. Fresh clone:
`git submodule update --init .agents/conventions` and
`npm ci --ignore-scripts --prefix .agents/conventions`.

## What this repository is

A toolkit to tune and measure vLLM on an AMD Radeon AI PRO R9700 (gfx1201, RDNA4) under Windows + WSL2,
where containers run with `wslc`: fused-MoE config tuning, server-flag A/B series with a ship test,
kernel micro-benchmarks, and the guards that make an unattended night run safe (RAM, quiet PC,
deadline, restore of the operator's own server). A new model is tuned by writing one model config and
running the commands — not by writing scripts. The implemented plans are in `research/` (`PLAN_r9700_tuning_toolkit*.md`) and the open one, the GPU acceptance runs, in `todo/`; the measurements that produced
these scripts are in `dew_flow_benchmark · research/RESULTS_vllm_029_r9700_*.md`.

## Non-negotiables

- **It drives a person's GPU and their production server.** Every run stops the operator's server only
  for its own duration and restores it once at the end; every wait has a ceiling; a guard stop kills the
  whole process group, never only the top script.
- **Measured before recommended.** A verdict comes from the ship test (the base arm's spread over all
  its values), never from one run.
- **Collected data is append-only.** Results, logs and decisions are added, never rewritten or dropped.
- **Public repository.** No personal paths, account names, tokens or machine names in tracked files;
  machine specifics live in an untracked `machine.env` made from `machine.env.example`.
