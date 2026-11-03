#!/usr/bin/env bash
# tests/test_docs.sh: the documents against the code and the files (E3.S3). Every list below is DERIVED from a source of truth the repository already
# holds (the verbs of `bin/r9700 commands`, the files of `lib/`, `tests/` and `research/`, the fixture list of the old harness folder), never typed
# twice. Each check is a function, so a companion test can run it over a planted document and see it fail: a check that finds nothing is not a pass.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
FIX="$HERE/fixtures/static"
HOMES="$REPO/research/INPUTS_homes.md"

# list_names <file>: the names of a fixture list: one per line, a `#` starts a comment, blank lines are skipped
list_names() {
  local line
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [ -n "$line" ] && printf '%s\n' "$line"
  done < "$1"
  return 0
}

# homes_problems <doc> <names file>: for every name a row `| `<name>` | <home> | <note> |` must be in the doc; the home is `**dropped**` or `**does not exist**`
# (with a reason of at least 40 characters), or holds at least one `lib/…`, `config/…`, `vendor/…` or `bin/…` path in backticks; every such path must exist in
# this repository, and a `bin/r9700 <verb>` must name a verb that `bin/r9700 commands` prints. One line per problem; returns 1 when there is one.
homes_problems() {
  local doc="$1" list="$2" name esc row home note tok word verb verbs bad=0 found
  verbs="$("$REPO/bin/r9700" commands)"
  while IFS= read -r name; do
    esc="${name//./\\.}"
    row="$(grep -E "^\| \`$esc\` \|" "$doc" | head -n 1)"
    if [ -z "$row" ]; then echo "$name: no row"; bad=1; continue; fi
    home="$(printf '%s' "$row" | awk -F'|' '{print $3}')"
    note="$(printf '%s' "$row" | awk -F'|' '{print $4}' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    case "$home" in
      *'**dropped**'* | *'**does not exist**'*)
        [ "${#note}" -ge 40 ] || { echo "$name: the reason is shorter than 40 characters"; bad=1; }
        continue
        ;;
    esac
    found=0
    while IFS= read -r tok; do
      [ -n "$tok" ] || continue
      tok="${tok//\`/}"
      word="${tok%% *}"
      case "$word" in
        lib/* | config/* | vendor/* | bin/*)
          found=1
          [ -e "$REPO/$word" ] || { echo "$name: the home $word does not exist"; bad=1; }
          if [ "$word" = bin/r9700 ]; then
            verb="${tok#bin/r9700}"
            verb="$(printf '%s' "$verb" | awk '{print $1}')"
            printf '%s\n' "$verbs" | grep -qx -- "$verb" || { echo "$name: the home names the verb \"$verb\", which bin/r9700 does not print"; bad=1; }
          fi
          ;;
      esac
    done < <(printf '%s' "$home" | grep -oE '`[^`]+`')
    [ "$found" -eq 1 ] || { echo "$name: no home and not dropped"; bad=1; }
    [ -n "$note" ] || { echo "$name: no note"; bad=1; }
  done < <(list_names "$list")
  return "$bad"
}

t_doc1_the_list_of_the_old_harness_folder_is_pinned_to_its_commit_and_holds_33_names() {
  assert_contains "$(head -n 1 "$FIX/harness_files.txt")" "c466652" "the first line names the commit the list was read at"
  assert_eq "33" "$(list_names "$FIX/harness_files.txt" | wc -l | tr -d ' ')" "31 files of the folder and the two names the plans use that it does not hold"
  assert_eq "33" "$(list_names "$FIX/harness_files.txt" | sort -u | wc -l | tr -d ' ')" "no name twice"
  assert_eq "3" "$(list_names "$FIX/inputs_outside.txt" | wc -l | tr -d ' ')" "the three inputs of the parent plan that are not in the folder"
}

t_doc2_every_file_of_the_old_harness_folder_has_a_home_or_a_reason() {
  assert_exit 0 "no problem in the harness table" -- homes_problems "$HOMES" "$FIX/harness_files.txt"
  assert_eq "" "$OUT" "nothing printed"
  assert_exit 0 "no problem for the inputs outside the folder" -- homes_problems "$HOMES" "$FIX/inputs_outside.txt"
}

t_doc3_the_homes_check_is_alive_over_planted_documents() {
  local good="$R9700_TEST_ROOT/homes-good.md" bad="$R9700_TEST_ROOT/homes-bad.md"
  cp "$HOMES" "$good"
  assert_exit 0 "a copy of the real document passes" -- homes_problems "$good" "$FIX/harness_files.txt"
  grep -vF '| `e2e_moe.sh` |' "$HOMES" > "$bad"
  assert_exit 1 "a name with no row is found" -- homes_problems "$bad" "$FIX/harness_files.txt"
  assert_contains "$OUT" "e2e_moe.sh: no row" "and named"
  sed 's|`lib/serve.sh`|`lib/nosuch.sh`|' "$HOMES" > "$bad"
  assert_exit 1 "a home that does not exist is found" -- homes_problems "$bad" "$FIX/harness_files.txt"
  assert_contains "$OUT" "serve.sh: the home lib/nosuch.sh does not exist" "and named"
  sed 's|`bin/r9700 run`|`bin/r9700 nosuchverb`|' "$HOMES" > "$bad"
  assert_exit 1 "a home that names a verb bin/r9700 does not print is found" -- homes_problems "$bad" "$FIX/harness_files.txt"
  assert_contains "$OUT" 'the verb "nosuchverb"' "and named"
  sed -E 's/^(\| `prodcheck.sh` \| )\*\*dropped\*\*/\1(nothing)/' "$HOMES" > "$bad"
  assert_exit 1 "a row with neither a home nor a drop is found" -- homes_problems "$bad" "$FIX/harness_files.txt"
  assert_contains "$OUT" "prodcheck.sh: no home and not dropped" "and named"
  sed -E 's/^(\| `prodcheck.sh` \| \*\*dropped\*\* \| ).*/\1too short |/' "$HOMES" > "$bad"
  assert_exit 1 "a drop without a real reason is found" -- homes_problems "$bad" "$FIX/harness_files.txt"
  assert_contains "$OUT" "prodcheck.sh: the reason is shorter" "and named"
}

# ---- the research folder and the flow catalogue

t_doc4_the_research_readme_names_every_document_of_research() {
  local file missing=""
  for file in "$REPO"/research/*.md; do
    [ "$(basename "$file")" = README.md ] && continue
    grep -qF "($(basename "$file"))" "$REPO/research/README.md" || missing+="$(basename "$file") "
  done
  assert_eq "" "$missing" "every research document is linked from research/README.md"
}

t_doc5_every_acceptance_record_is_in_the_flow_catalogue_and_in_post_deploy() {
  local file name missing_cat="" missing_pd="" n=0
  for file in "$REPO"/research/ACCEPTANCE_*.md; do
    name="$(basename "$file")"
    n=$((n + 1))
    grep -F "$name" "$REPO/research/module_tests.md" | grep -qE '^\|' || missing_cat+="$name "
    grep -qF "$name" "$REPO/POST_DEPLOY.md" || missing_pd+="$name "
  done
  assert_eq "5" "$n" "the scan is alive: two acceptance records of E1 and E2 and three of E3"
  assert_eq "" "$missing_cat" "every acceptance record has a row in the flow catalogue"
  assert_eq "" "$missing_pd" "POST_DEPLOY.md names every acceptance record"
}

t_doc6_every_row_of_the_flow_catalogue_says_covered_or_not_covered() {
  local rows bad
  rows="$(awk '/^## Flow catalogue/ { go = 1; next } /^## / { go = 0 } go && /^\| / && !/^\| Flow \|/ && !/^\|---/ { print }' "$REPO/research/module_tests.md")"
  assert_contains "$rows" "bin/r9700 run" "the scan is alive: it reads the rows of the catalogue"
  bad="$(printf '%s\n' "$rows" | awk -F'|' '{ c = $3; sub(/^[ \t]+/, "", c); if (c !~ /^(covered|not covered)/) print $2 }')"
  assert_eq "" "$bad" "the second cell of every row starts with covered or not covered"
}

t_doc7_every_test_file_is_in_module_tests() {
  local file missing="" n=0
  for file in "$REPO"/tests/test_*.sh "$REPO"/tests/test_*.py; do
    n=$((n + 1))
    grep -qF "\`tests/$(basename "$file")\`" "$REPO/research/module_tests.md" || missing+="$(basename "$file") "
  done
  assert_eq "" "$missing" "every test file has a row in the table of where the tests are"
  assert_exit 0 "the scan is alive: there are test files" -- test "$n" -gt 20
}

t_doc8_architecture_names_every_file_of_lib_and_bin() {
  local file name missing="" n=0
  for file in "$REPO"/lib/*.sh "$REPO"/lib/*.py "$REPO"/bin/r9700; do
    name="${file#"$REPO"/}"
    n=$((n + 1))
    grep -qF "$name" "$REPO/research/architecture.md" || missing+="$name "
  done
  assert_eq "" "$missing" "every file of lib/ and bin/ is named in research/architecture.md"
  assert_exit 0 "the scan is alive: there are files" -- test "$n" -gt 25
}

# ---- the verbs: derived from `bin/r9700 commands`

t_doc9_every_verb_is_in_the_readme_and_in_the_architecture_verb_table() {
  local verb missing_readme="" missing_arch="" rows extra n=0
  for verb in $("$REPO/bin/r9700" commands); do
    n=$((n + 1))
    grep -qF "bin/r9700 $verb" "$REPO/README.md" || missing_readme+="$verb "
    grep -qE "^\| \`bin/r9700 $verb\` \|" "$REPO/research/architecture.md" || missing_arch+="$verb "
  done
  assert_exit 0 "the scan is alive: the verbs were read" -- test "$n" -ge 9
  assert_eq "" "$missing_readme" "every verb is shown in README.md as bin/r9700 <verb>"
  assert_eq "" "$missing_arch" "every verb is a row of the verb table of research/architecture.md"
  rows="$(grep -oE '^\| `bin/r9700 [a-z-]+`' "$REPO/research/architecture.md" | sed -E 's/^\| `bin\/r9700 ([a-z-]+)`/\1/' | sort)"
  extra="$(comm -13 <("$REPO/bin/r9700" commands | sort) <(printf '%s\n' "$rows"))"
  assert_eq "" "$extra" "every row of the verb table is a verb"
}

# ---- POST_DEPLOY.md: the shape (the tool of the shared rules, structural mode) and the two things this repository adds

post_deploy_shape() { # [<folder with a POST_DEPLOY.md>]: the shared tool in structural mode, run in that folder (the tool refuses a file outside its working folder)
  (cd "${1:-$REPO}" && node "$REPO/.agents/conventions/tools/post-deploy-check.mjs" --file POST_DEPLOY.md)
}

t_doc10_post_deploy_keeps_its_shape_and_the_check_is_alive() {
  local dir="$R9700_TEST_ROOT/pd" i
  assert_exit 0 "POST_DEPLOY.md passes the structural check" -- post_deploy_shape
  mkdir -p "$dir"
  {
    sed -n '1,/^|---/p' "$REPO/POST_DEPLOY.md"
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13; do printf '| %s | a person loses something | `true` | auto |\n' "$i"; done
  } > "$dir/POST_DEPLOY.md"
  assert_exit 1 "a copy with thirteen items is refused" -- post_deploy_shape "$dir"
  sed -n '1,/^|---/p' "$REPO/POST_DEPLOY.md" > "$dir/POST_DEPLOY.md"
  for i in 1 2 3; do printf '| %s | a person loses something | `true` | auto |\n' "$i" >> "$dir/POST_DEPLOY.md"; done
  assert_exit 0 "the same copy with three items passes: the refusal above was the count" -- post_deploy_shape "$dir"
}

t_doc11_post_deploy_has_the_night_plan_item_and_names_the_plan_in_its_target_line() {
  assert_exit 0 "an item runs run --check over the operator's plan" -- grep -qE '^\| [0-9]+ \|.*bin/r9700 run --check "\$R9700_PLAN"' "$REPO/POST_DEPLOY.md"
  assert_exit 0 "the target line names \$R9700_PLAN" -- grep -qE '^Target:.*R9700_PLAN' "$REPO/POST_DEPLOY.md"
  assert_eq "12" "$(grep -cE '^\| [0-9]+ \|' "$REPO/POST_DEPLOY.md")" "the file is at its cap of twelve items, no more"
}

# ---- the acceptance templates: a prediction before the observed sections, and the observed sections empty while the record says NOT RUN

# template_problems <file>: the title is `# Acceptance of …`; the five headings are there, the first Prediction before the first Observed; while the title says
# NOT RUN, the first line of every fenced block in an `## Observed` section is a `(paste …)` prompt, and every such section has a block. A record that was run
# (its title says so) is only held to the headings: a filled-in record must not turn this check red.
template_problems() {
  awk '
    function problem(text) { print text; bad = 1 }
    NR == 1 { notrun = ($0 ~ /NOT RUN/); if ($0 !~ /^# Acceptance of /) problem("line 1 is not an acceptance title") }
    /^## / {
      if (insect && !hasfence) problem(cur ": no fenced block")
      insect = 0; infence = 0
      for (h = 1; h <= nreq; h++) if (index($0, req[h]) == 1) have[h] = 1
      if (index($0, "## Prediction") == 1 && !seen_obs) pred = 1
      if (index($0, "## Observed") == 1) { seen_obs = 1; insect = 1; hasfence = 0; cur = $0 }
      next
    }
    /^```/ { if (!infence) { infence = 1; first = 1; hasfence = 1 } else { infence = 0 } next }
    infence && first { first = 0; if (notrun && insect && $0 !~ /^\(paste/) problem("line " NR ": an observed block of a NOT RUN record is not a (paste ...) prompt") }
    BEGIN { nreq = split("## Subject and conditions|## Commands|## Prediction|## Questions the run answers|## What this record does not settle", req, "|") }
    END {
      if (insect && !hasfence) problem(cur ": no fenced block")
      for (h = 1; h <= nreq; h++) if (!have[h]) problem("missing heading: " req[h])
      if (!pred) problem("no Prediction section before the first Observed section")
      if (!seen_obs) problem("no Observed section")
      exit bad
    }' "$1"
}

t_doc12_the_acceptance_templates_exist_say_not_run_and_hold_a_prediction_before_empty_observed_sections() {
  local name
  for name in linear_bench prefixtest run; do
    assert_exit 0 "ACCEPTANCE_${name}_2026-11-03.md exists" -- test -f "$REPO/research/ACCEPTANCE_${name}_2026-11-03.md"
    assert_exit 0 "...is well formed" -- template_problems "$REPO/research/ACCEPTANCE_${name}_2026-11-03.md"
    assert_exit 0 "...and its title says NOT RUN, or that it was run" -- bash -c 'head -n 1 "$1" | grep -qE "NOT RUN|RUN 20"' _ "$REPO/research/ACCEPTANCE_${name}_2026-11-03.md"
  done
  assert_exit 0 "the template of moe-tune is well formed too (the model of the others)" -- template_problems "$REPO/research/ACCEPTANCE_moe_tune_2026-11-02.md"
}

t_doc13_the_template_check_is_alive_over_planted_records() {
  local src="$REPO/research/ACCEPTANCE_prefixtest_2026-11-03.md" bad="$R9700_TEST_ROOT/acc-bad.md"
  sed -E '0,/^\(paste the output of bin\/r9700 init\)$/s//The output was: ok/' "$src" > "$bad"
  assert_exit 1 "a NOT RUN record with a pasted output is refused" -- template_problems "$bad"
  assert_contains "$OUT" "not a (paste" "and says why"
  sed -E '1s/NOT RUN YET/RUN 2026-11-04/' "$bad" > "$bad.run"
  assert_exit 0 "the same record, once its title says it was run, is held to the headings only" -- template_problems "$bad.run"
  sed -E 's/^## Prediction.*$/## Expectation/' "$src" > "$bad"
  assert_exit 1 "a record with no Prediction section is refused" -- template_problems "$bad"
  assert_contains "$OUT" "## Prediction" "and names the heading"
  awk '/^## / { skip = ($0 ~ /^## Observed: `init`/) } !skip || /^## / { print }' "$src" > "$bad"
  assert_exit 1 "an Observed section with no block is refused" -- template_problems "$bad"
  sed '1s/^# Acceptance of/# Notes on/' "$src" > "$bad"
  assert_exit 1 "a file that is not an acceptance record is refused" -- template_problems "$bad"
}

run_all_tests
