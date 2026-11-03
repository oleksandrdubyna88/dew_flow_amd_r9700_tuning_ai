#!/usr/bin/env bash
# A test file that forks without end ON PURPOSE. It is NOT in tests/ (the runner never lists it): tests/test_runner.sh points the nested runner at this
# folder (R9700_RUNNER_TESTS_DIR) to prove the process cap of tests/run.mjs. It refuses to run unless it is told to AND runs under a process cap:
# without the cap it would fork until the user's limit, which is what the cap exists to prevent.
set -u
# R9700_RUNNER_FIXTURE_HARD_LIMIT stands in for the hard limit when the check alone is tested (`--check` exits before any fork)
hard="${R9700_RUNNER_FIXTURE_HARD_LIMIT:-$(ulimit -H -u)}"
if [ "${R9700_RUNNER_FORKBOMB_OK:-}" != 1 ] || [ "$hard" = unlimited ] || [ "$hard" -gt 20000 ]; then
  echo "test_forks_without_end.sh: refuses to run without R9700_RUNNER_FORKBOMB_OK=1 and a process cap of at most 20000 (hard limit: $hard)" >&2
  exit 3
fi
[ "${1:-}" = --check ] && exit 0
while :; do sleep 600 & done
