#!/usr/bin/env bash
# The name rules of the operator's ComfyUI container (E1.S2, scenarios NR1-NR6): COMFY_CONTAINER and the fetch name derived from it must not start with CONTAINER_PREFIX
# (the toolkit stops every container with that prefix) and must differ from PROD_CONTAINER (the toolkit stops and restores that one). A separate file because
# tests/test_config.sh is at the file-size limit. Every test body is a function t_<guarantee>; each runs in its own subshell and writes only below $R9700_TEST_ROOT.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=lib/config.sh
source "$REPO/lib/config.sh"
# shellcheck source=lib/run_guarded.sh
source "$REPO/lib/run_guarded.sh"
# shellcheck source=lib/comfy.sh
source "$REPO/lib/comfy.sh"
# shellcheck source=tests/lib/configcase.sh
source "$HERE/lib/configcase.sh"

_PREFIX_LEGAL='COMFY_CONTAINER must not start with CONTAINER_PREFIX (the toolkit stops every container with that prefix)'
_PROD_LEGAL='COMFY_CONTAINER must differ from PROD_CONTAINER (the toolkit stops and restores one, never the other)'

# NR1
t_comfy_container_must_not_start_with_the_container_prefix() {
  local root; root="$(case_root "$FUNCNAME")"
  machine "$root" COMFY_CONTAINER "COMFY_CONTAINER=r9700tune-comfy"
  assert_exit 2 "a name under the default prefix is refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_eq 1 "$(grep -c '^config: ' <<< "$ERR")" "exactly one config: line"
  assert_contains "$ERR" "COMFY_CONTAINER: \"r9700tune-comfy\" starts with the container prefix \"r9700tune-\"; legal: $_PREFIX_LEGAL" "the problem and the legal text"
  assert_contains "$ERR" "$root/machine.env:" "naming the machine file"
  machine "$root" COMFY_CONTAINER "COMFY_CONTAINER=x-comfy"
  printf '%s\n' "CONTAINER_PREFIX=x-" >> "$root/machine.env"
  assert_exit 2 "the same for a custom prefix" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_eq 1 "$(grep -c '^config: ' <<< "$ERR")" "still one line"
  assert_contains "$ERR" 'starts with the container prefix "x-"' "naming the custom prefix"
}

# NR2
t_comfy_container_must_differ_from_prod_container() {
  local root; root="$(case_root "$FUNCNAME")"
  machine "$root" COMFY_CONTAINER "COMFY_CONTAINER=vllm"
  assert_exit 2 "COMFY_CONTAINER=vllm is refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_eq 1 "$(grep -c '^config: ' <<< "$ERR")" "exactly one config: line"
  assert_contains "$ERR" "COMFY_CONTAINER: \"vllm\" is also PROD_CONTAINER; legal: $_PROD_LEGAL" "the problem and the legal text"
  machine "$root" PROD_CONTAINER "PROD_CONTAINER=comfyui"
  assert_exit 2 "PROD_CONTAINER=comfyui with the default COMFY_CONTAINER is refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_eq 1 "$(grep -c '^config: ' <<< "$ERR")" "exactly one config: line"
  assert_contains "$ERR" "config: $root/machine.env: COMFY_CONTAINER: \"comfyui\" is also PROD_CONTAINER" "attributed to COMFY_CONTAINER, with the machine file and no line"
}

# NR3
t_the_fetch_name_is_checked_by_the_same_rules() {
  local root; root="$(case_root "$FUNCNAME")"
  machine "$root" COMFY_CONTAINER "COMFY_CONTAINER=r9700tune"
  assert_exit 2 "a name that passes NR1 but whose fetch name is prefixed" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_eq 1 "$(grep -c '^config: ' <<< "$ERR")" "exactly one config: line"
  assert_contains "$ERR" 'COMFY_CONTAINER: "r9700tune-fetch" (the fetch container'"'"'s name) starts with the container prefix "r9700tune-"' "the fetch name and the prefix"
  machine "$root" PROD_CONTAINER "PROD_CONTAINER=comfyui-fetch"
  assert_exit 2 "a server named like the fetch container" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_eq 1 "$(grep -c '^config: ' <<< "$ERR")" "exactly one config: line"
  assert_contains "$ERR" 'COMFY_CONTAINER: "comfyui-fetch" (the fetch container'"'"'s name) is also PROD_CONTAINER' "the fetch name and the server"
}

# NR4
t_a_legal_pair_loads_and_the_fetch_name_is_built_from_the_one_constant() {
  local root; root="$(case_root "$FUNCNAME")"
  machine "$root" COMFY_CONTAINER "COMFY_CONTAINER=comfy-ui"
  assert_exit 0 "a legal pair loads" -- config_load_machine "$root/machine.env"
  assert_eq "" "$ERR" "nothing on stderr"
  assert_eq "-fetch" "$_COMFY_FETCH_SUFFIX" "the suffix is -fetch"
  assert_eq "comfy-ui$_COMFY_FETCH_SUFFIX" "$(comfy_fetch_name)" "comfy_fetch_name prints the name made from the constant"
  assert_eq "comfy-ui-fetch" "$(comfy_fetch_name)" "comfy-ui-fetch"
  machine "$root"
  assert_exit 0 "the defaults load" -- config_load "$root/machine.env" "$MODEL_35B"
}

# NR5
t_the_name_rules_run_over_fields_that_passed_and_report_in_one_pass() {
  local root; root="$(case_root "$FUNCNAME")"
  machine "$root" RAM_MIN_MB "RAM_MIN_MB=x"
  printf '%s\n' "COMFY_CONTAINER=vllm" >> "$root/machine.env"
  assert_exit 2 "a wrong field and a wrong pair" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_eq 2 "$(grep -c '^config: ' <<< "$ERR")" "exactly two config: lines"
  assert_contains "$ERR" "RAM_MIN_MB" "one is the single field"
  assert_contains "$ERR" '"vllm" is also PROD_CONTAINER' "the other the cross-field rule"
  machine "$root" COMFY_CONTAINER "COMFY_CONTAINER=Bad"
  assert_exit 2 "a COMFY_CONTAINER that fails its own type" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_eq 1 "$(grep -c '^config: ' <<< "$ERR")" "one line"
  assert_not_contains "$ERR" "container prefix" "no cross-field line about it"
  assert_not_contains "$ERR" "PROD_CONTAINER" "not the other rule either"
}

# NR6
t_config_load_machine_applies_both_name_rules() {
  local root; root="$(case_root "$FUNCNAME")"
  machine "$root" COMFY_CONTAINER "COMFY_CONTAINER=r9700tune-comfy"
  assert_exit 2 "the prefix rule through config_load_machine" -- config_load_machine "$root/machine.env"
  assert_eq 1 "$(grep -c '^config: ' <<< "$ERR")" "one line"
  assert_contains "$ERR" "COMFY_CONTAINER: \"r9700tune-comfy\" starts with the container prefix \"r9700tune-\"; legal: $_PREFIX_LEGAL" "the NR1 line"
  machine "$root" COMFY_CONTAINER "COMFY_CONTAINER=vllm"
  assert_exit 2 "the equality rule through config_load_machine" -- config_load_machine "$root/machine.env"
  assert_eq 1 "$(grep -c '^config: ' <<< "$ERR")" "one line"
  assert_contains "$ERR" "COMFY_CONTAINER: \"vllm\" is also PROD_CONTAINER; legal: $_PROD_LEGAL" "the NR2 line"
}

run_all_tests
