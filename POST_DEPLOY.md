# Post-deploy checks — dew_flow_amd_r9700_tuning_ai

Target: the toolkit checkout on the operator's R9700 PC (the WSL folder the operator runs `bin/r9700` from); pass its path as `--target`. "Deploy" here
is installing the toolkit or updating it (`git pull`) on that machine. Run this file after every install or update.
Last verified: 2026-11-02 · none (shape only: no install on the PC yet) · b636501

| # | What a person loses if this is broken | Check | Auto |
|---|---|---|---|
| 1 | A series stops at the first step: `machine.env` does not match this PC (paths, image, wslc, telemetry), and nobody finds out before a night is spent | `cd "$TARGET" && bin/r9700 init` | auto |
| 2 | The 35B series cannot start: the model folder, the patch files, the generation config or the image are not where this PC keeps them | `cd "$TARGET" && bin/r9700 series qwen3.6-35b-a3b-gptq base ta3 --out postdeploy-35b --rounds 1 --dry-run` | auto |
| 3 | The 27B series cannot start, for the same reasons with the other model file | `cd "$TARGET" && bin/r9700 series qwen3.8-27b-awq base --out postdeploy-27b --rounds 1 --dry-run` | auto |
| 4 | After a run the operator's own server is not back: the toolkit says "restored" and a request to production still fails | the operator sends a one-token completion request to their own server (the same one they use every day) and gets an answer | manual |
| 5 | Test containers keep the GPU after a run: the next start of production finds no memory | `test "$(wslc list --no-trunc \| grep -cE 'vllmprtest\|r9700tune-')" = 0` | auto |
| 6 | Every later run is refused with "another run holds the lock": a lock or a stale holder is left behind | `flock -n "${R9700_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/r9700}/lock" true` | auto |
| 7 | The next invocation restores a server that is already up, or stops one it should not: a recovery marker is left over from a run that ended badly | `test ! -e "${R9700_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/r9700}/recovery.env"` | auto |
| 8 | The quality step measures with an old harness: the copy in the work folder is not the one of this version | `cmp "$TARGET/lib/harness.py" "$(sed -n 's/^WORK_DIR=//p' "$TARGET/machine.env")/r9700/harness.py"` (it exists after the first series) | auto |
| 9 | Round 1 of a real series fails late: the GSM8K test file is not where `GSM8K_DATA` says | `test -s "$(sed -n 's/^WORK_DIR=//p' "$TARGET/machine.env")/gsm8k/test.jsonl"` | auto |
| 10 | The checkout on the PC is not the released version, or has local edits: results would carry an identity nobody can reproduce | `git -C "$TARGET" status --porcelain` is empty and `git -C "$TARGET" rev-parse HEAD` is the released commit | manual |
| 11 | The release was never measured on the real GPU: every test is a stub | the acceptance run of `research/ACCEPTANCE_series_2026-11-02.md` was done for this commit and its observed sections are filled | manual |
