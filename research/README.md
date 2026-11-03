# research — the system as it is

Architecture, module deep-dives and records of decisions that shipped. Open work is in `../todo/`.

| Document | What |
|---|---|
| [module_config.md](module_config.md) | every config field: file, type, legal values, default, origin, and the arm table grammar |
| [module_tests.md](module_tests.md) | the test harness: where it is, the commands, the flow catalogue, what it does not prove |
| [architecture.md](architecture.md) | what exists: the config layer, the verdict, the quality harness, the adapter, the supervisor and its guards, the series and its run identity, the test base |
| [ACCEPTANCE_series_2026-11-02.md](ACCEPTANCE_series_2026-11-02.md) | the acceptance run of `series` on the R9700: the predictions written before it, then the observed output (filled in by the operator's session) |
| [ACCEPTANCE_moe_tune_2026-11-02.md](ACCEPTANCE_moe_tune_2026-11-02.md) | the acceptance run of `moe-tune` on the R9700 (a coarse chunk of key 24, merge, activate, the kernel A/B): the prediction written before it, NOT RUN yet; the observed sections are filled in by the operator's session |
