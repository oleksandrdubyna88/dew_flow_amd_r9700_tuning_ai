#!/usr/bin/env bash
# The config tests' folders and files (tests/test_config.sh, tests/test_config_comfy.sh). Sourced after tests/lib/assert.sh, with $HERE and $REPO set; no t_ function in it.
#
#   case_root <name>                                  a fresh folder with the files the machine fixture names
#   variant <source> <dest> <root> [<KEY> [<line>]]   the source with @ROOT@ replaced and the line of KEY replaced, removed (an empty line) or added
#   machine <root> [<KEY> [<line>]]                   <root>/machine.env from the machine fixture
#   model <model file> <root> [<KEY> [<line>]]        <root>/model.env from a model file

FIXTURE="$HERE/fixtures/config/machine.env.in"
MODEL_35B="$REPO/models/qwen3.6-35b-a3b-gptq.env"

# case_root <name>: a fresh folder with the files the machine fixture names (empty files stand in for the patches).
case_root() {
  local root="$R9700_TEST_ROOT/case-$1" file
  mkdir -p "$root/work" "$root/patches/C" "$root/patches/work/speed/o7" "$root/patches/work/speed/ra"
  for file in C/auto_gptq.py C/gptq_utils.py work/speed/o7/rdna_hybrid_w4a16.py work/speed/ra/rocm_attn.py; do : > "$root/patches/$file"; done
  echo "$root"
}

# variant <source file> <dest file> <root> [<KEY> [<replacement line, empty = remove the key>]]
# The source with every @ROOT@ replaced; the line of KEY replaced, removed, or (when absent) added.
variant() {
  local src="$1" dest="$2" root="$3" key="${4:-}" repl="${5-}" line out="" hit=0
  repl="${repl//@ROOT@/$root}"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line//@ROOT@/$root}"
    if [ -n "$key" ] && [[ $line == "$key="* ]]; then
      hit=1
      [ -n "$repl" ] && out+="$repl"$'\n'
      continue
    fi
    out+="$line"$'\n'
  done < "$src"
  if [ -n "$key" ] && [ "$hit" = 0 ] && [ -n "$repl" ]; then out+="$repl"$'\n'; fi
  printf '%s' "$out" > "$dest"
}

machine() { variant "$FIXTURE" "$1/machine.env" "$1" "${@:2}"; }
model() { variant "$1" "$2/model.env" "$2" "${@:3}"; }
