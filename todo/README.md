# todo — open plans

Plans for work that is not finished. A finished plan moves to `research/` with status `IMPLEMENTED <date>`.

## Currently open

| Plan | Status | Scope |
|---|---|---|
| [PLAN_r9700_tuning_toolkit.md](PLAN_r9700_tuning_toolkit.md) | plan only (2026-11-01) | the ad-hoc tuning scripts of 2026-10-25..11-01 as one model-independent, tested toolkit: one model config, one entry point, guards built in |
| [PLAN_r9700_tuning_toolkit_E1.md](PLAN_r9700_tuning_toolkit_E1.md) | plan only (2026-11-01) | the stories of epic E1 (a usable, trustworthy server-flag comparison): S1 config, verdict, harness, test and CI base; S2 lifecycle and restore (cornerstone); S3 run identity and completion (cornerstone) |
| [PLAN_r9700_tuning_toolkit_E2.md](PLAN_r9700_tuning_toolkit_E2.md) | plan only (2026-11-02) | the stories of epic E2 (MoE config tuning on the E1 supervisor): S1 merge, A/B decision, candidates, vendored benchmark; S2 the chunk and A/B workers, the cache clear in the exit path, the fields; S3 `moe-tune`, docs, acceptance template (NOT RUN) |
| [PLAN_r9700_tuning_toolkit_E3.md](PLAN_r9700_tuning_toolkit_E3.md) | plan only (2026-11-03) | the stories of epic E3 (kernels, prefix check, the unattended driver, publication): S1 `linear-bench` and `prefixtest` as steps (pure parts first, shapes from the model config); S2 the `run` driver over a plan file (one supervisor, exit 3 waits, the deadline ends the chain, the exit code names the stopped step); S3 publication and closing (every old script has a home or is dropped with a reason, final docs, `POST_DEPLOY.md`, three acceptance templates NOT RUN, the consumer row) |
