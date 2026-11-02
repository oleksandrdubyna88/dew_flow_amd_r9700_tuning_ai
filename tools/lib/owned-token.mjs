// This repository's token and its `## Tokens` row (rule §1 of `common/test-leftovers.md`) — the ONE file of the helper that is not shipped as it is.
//
// `owned.mjs`, `git.mjs` and `leftovers-sweep.mjs` beside it are byte-identical copies of the files under `.agents/conventions/tools/lib/`
// (`tests/test_static.sh` compares their sha256). They live in `tools/lib/`, where the leftovers guard looks for a copied helper and reads it as
// product code, not as a test that makes a temp folder. They hold no token, so a copy never carries the token of the repository it came from.
//
//   REPO_TOKEN  this repository's row of the rule's `## Tokens` table: `[a-z0-9]{2,12}`, not of the owner grammar `^[uw][0-9]{1,10}$`
//   REPO_ROW    the "repository" column of that row, which the guard takes as `--identity`

export const REPO_TOKEN = "r9700";                          // rule §1 — the ONLY place this repository's token is written
export const REPO_ROW = "the R9700 vLLM tuning toolkit";    // rule §1 — the `## Tokens` row (its repository column) that names THIS repository
