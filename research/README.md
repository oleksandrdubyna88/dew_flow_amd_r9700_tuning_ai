# research — the system as it is

Architecture, module deep-dives and records of decisions that shipped. Open work is in `../todo/` (the GPU acceptance runs that are still NOT RUN).

| Document | What |
|---|---|
| [module_config.md](module_config.md) | every config field: file, type, legal values, default, origin, and the arm table grammar |
| [module_tests.md](module_tests.md) | the test harness: where it is, the commands, the flow catalogue, what it does not prove |
| [architecture.md](architecture.md) | what exists, by module: the module map, the verb table, the config layer, the verdict, the quality harness, the adapter, the supervisor and its guards, the series and its run identity, MoE tuning, the kernel checks, the run driver, the test base, the flow, the other repositories |
| [INPUTS_homes.md](INPUTS_homes.md) | the home of every script of the old harness folder (33 names) in this toolkit, or the reason it has none; what was checked for the two names the folder does not hold |
| [ACCEPTANCE_series_2026-11-02.md](ACCEPTANCE_series_2026-11-02.md) | the acceptance run of `series` on the R9700: the predictions written before it, then the observed output (filled in by the operator's session) |
| [ACCEPTANCE_moe_tune_2026-11-02.md](ACCEPTANCE_moe_tune_2026-11-02.md) | the acceptance run of `moe-tune` on the R9700 (a coarse chunk of key 24, merge, activate, the kernel A/B): the prediction written before it, NOT RUN yet; the observed sections are filled in by the operator's session |
| [ACCEPTANCE_linear_bench_2026-11-03.md](ACCEPTANCE_linear_bench_2026-11-03.md) | the acceptance run of `linear-bench` on the R9700 (the 35B file's five shapes against results § 12.1): the prediction written before it, NOT RUN yet |
| [ACCEPTANCE_prefixtest_2026-11-03.md](ACCEPTANCE_prefixtest_2026-11-03.md) | the acceptance run of `prefixtest` on the R9700 (one fresh server, against results § 13.3): the prediction written before it, NOT RUN yet |
| [ACCEPTANCE_run_2026-11-03.md](ACCEPTANCE_run_2026-11-03.md) | the acceptance run of `run` on the R9700 (a two-step plan, a forced RAM stop and one restore, then the clean chain): the prediction written before it, NOT RUN yet |
| [PLAN_r9700_tuning_toolkit.md](PLAN_r9700_tuning_toolkit.md) | IMPLEMENTED (2026-11-03): the plan of the whole toolkit (goal, design, inputs, epics) and its deviations |
| [PLAN_r9700_tuning_toolkit_E1.md](PLAN_r9700_tuning_toolkit_E1.md) | IMPLEMENTED: the stories of E1 (config, verdict, harness, test base; lifecycle and restore; run identity and the series), the amendments A1 to A24 and the deviations |
| [PLAN_r9700_tuning_toolkit_E2.md](PLAN_r9700_tuning_toolkit_E2.md) | IMPLEMENTED: the stories of E2 (the pure parts of MoE tuning; the chunk and the A/B as workers; `moe-tune`) and the deviations |
| [PLAN_r9700_tuning_toolkit_E3.md](PLAN_r9700_tuning_toolkit_E3.md) | IMPLEMENTED: the stories of E3 (`linear-bench` and `prefixtest`; the `run` driver; publication) and the deviations |
