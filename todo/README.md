# todo — open plans

Plans for work that is not finished. A finished plan moves to `research/` with status `IMPLEMENTED <date>`.

## Currently open

| Plan | Status | Scope |
|---|---|---|
| [PLAN_comfyui_r9700.md](PLAN_comfyui_r9700.md) | E1 merged and accepted on the card; E2 merged (PR #20), its acceptance owed; epoch 2 (entry 1.2 stopped epoch 1); E3 not started | ComfyUI on the R9700 in a wslc container as `bin/r9700 comfy` verbs, and a measured tuning series of ComfyUI arms |
| [PLAN_comfyui_r9700_E1.md](PLAN_comfyui_r9700_E1.md) | S1–S3 merged in PR #18 (2026-11-08); the three acceptance runs recorded (PR #19) | the three stories of E1 of the ComfyUI plan: the machine fields and three adapter calls; one owner of the card (cornerstone, `model: fable`); the image, the pinned model sets, `comfy build` and `comfy fetch` |
| [PLAN_comfyui_r9700_E2.md](PLAN_comfyui_r9700_E2.md) | S1–S3 merged in PR #20 (2026-11-08); the acceptance on the card owed | the three stories of E2 of the ComfyUI plan: the comfy mode of the ship test; the arm-round and its measurement contract (cornerstone, `model: fable`); the verb `comfy bench`, the verdict over a bench folder, the documents and the first bench runs on the R9700 |
| [PLAN_comfy_watch_flake.md](PLAN_comfy_watch_flake.md) | plan only, 2026-11-11 | `test_comfy_watch.sh` fails when the guard starts just before a second boundary: `--max-s` counts whole seconds (three CI failures on 2026-11-10/11) |

The GPU acceptance plan itself was promoted on 2026-11-03 to [`../research/PLAN_r9700_gpu_acceptance.md`](../research/PLAN_r9700_gpu_acceptance.md) with its deviations.
The follow-up plan of that acceptance (the load flakes of the tests and the `moe-tune` activation dtype) was promoted on 2026-11-05 to [`../research/PLAN_r9700_acceptance_followups.md`](../research/PLAN_r9700_acceptance_followups.md) with its deviations.
