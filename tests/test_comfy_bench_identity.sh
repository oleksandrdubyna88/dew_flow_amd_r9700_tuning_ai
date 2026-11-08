#!/usr/bin/env bash
# The identity of a ComfyUI experiment (E2.S2): the bash half of scenarios BF1-BF5 (the Python half, `build-comfy`, is tests/test_fingerprint.py).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"
# shellcheck source=tests/lib/lifecycle.sh
source "$HERE/lib/lifecycle.sh"
# shellcheck source=tests/lib/benchcase.sh
source "$HERE/lib/benchcase.sh"
# BF1-BF5, the bash half

# BF1
t_the_fingerprint_is_a_version_1_document_with_every_component_and_compares_with_itself() {
  bench_setup "$FUNCNAME"
  assert_exit 0 "the fingerprint of two arms and two rounds" -- bench_fp zimage 2 base fp16acc
  local fp="$OUTD/fingerprint.json" show
  show() { python3 "$REPO/lib/fingerprint.py" show "$fp" "$1" | tr '\n' ' ' | sed 's/ $//'; }
  assert_eq "comfy zimage base 2" "$(show kind) $(show workflow) $(show base) $(show rounds)" "kind, workflow, base, rounds"
  assert_eq "base fp16acc" "$(show arms)" "the arms"
  assert_eq "comfyui-r9700:local sha256:stub v0.44.0" "$(show image.ref) $(show image.id) $(show comfy_ref)" "the image and the ComfyUI tag"
  assert_eq "4242 1800" "$(show constants.seeds.cold) $(show constants.ceilings.cold_max_s)" "the constants of the workflow"
  assert_eq "diffusion_models/z_image_turbo_bf16.safetensors text_encoders/qwen_3_4b.safetensors vae/ae.safetensors" "$(show models)" "the three model files of zimage, and no loras/ key"
  local tools mod missing=""
  tools=" $(show tools) "
  for mod in bench_py arms_conf evidence_conf comfy_bench_sh fingerprint_py verdict_py; do [[ $tools == *" $mod "* ]] || missing+="$mod "; done
  for mod in $_CB_UNIT_SH; do [[ $tools == *" ${mod}_sh "* ]] || missing+="${mod}_sh "; done
  assert_eq "" "$missing" "the tools name bench.py, both tables, the worker, the Python programs and every module of the unit (the list is the worker's own)"
  assert_exit 0 "compare with itself" -- python3 "$REPO/lib/fingerprint.py" compare "$fp" "$fp"
  assert_eq "" "$OUT" "prints nothing"
  assert_eq "$(sha256sum < "$(container_host_path /work/r9700/comfyui/bench.py)" | cut -c1-64)" "$(show tools.bench_py)" "tools.bench_py is the hash of the placed copy"
}

# BF2
t_a_change_of_any_component_refuses_before_anything_is_stopped_and_an_extension_merges() {
  bench_setup "$FUNCNAME"
  bench_fp zimage 2 base fp16acc > /dev/null 2>&1
  local fp="$OUTD/fingerprint.json" h placed="$R9700_WORK_DIR/r9700/comfyui/bench.py" arms="$CASE/arms.conf" ev="$CASE/arm_evidence.conf" models="$CASE/models.conf" stops_before
  h="$(sha256sum < "$fp")"
  stops_before="$(stops | wc -l | tr -d ' ')"
  cp "$REPO/comfyui/arms.conf" "$arms"
  sed -i 's/^fp16acc .*/fp16acc | --fast fp16_accumulation --x | |/' "$arms"
  R9700_COMFY_ARMS_CONF="$arms" assert_exit 2 "an arms.conf edit" -- bench_fp zimage 2 base fp16acc
  assert_contains "$ERR" 'fingerprint differs: arms.fp16acc.args: ["--fast","fp16_accumulation"] -> ["--fast","fp16_accumulation","--x"]' "names the leaf, old and new"
  cp "$REPO/comfyui/arm_evidence.conf" "$ev"
  sed -i 's/Enabled fp16 accumulation/Enabled fp16 accumulation x/' "$ev"
  R9700_COMFY_EVIDENCE_CONF="$ev" assert_exit 2 "an evidence row edit" -- bench_fp zimage 2 base fp16acc
  assert_contains "$ERR" "fingerprint differs: tools.evidence_conf: " "tools.evidence_conf"
  echo '# edited' >> "$placed"
  assert_exit 2 "an edit of the placed bench.py" -- bench_fp zimage 2 base fp16acc
  assert_contains "$ERR" "fingerprint differs: tools.bench_py: " "tools.bench_py"
  cp "$REPO/comfyui/bench.py" "$placed"
  sed 's/^\(zimage  *diffusion_models .*\)2407613050b809ffdff18a4ac99af83ea6b95443ecebdf80e064a79c825574a6$/\1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/' "$REPO/comfyui/models.conf" > "$models"
  R9700_COMFY_MODELS_CONF="$models" assert_exit 2 "a changed pin" -- bench_fp zimage 2 base fp16acc
  assert_contains "$ERR" "fingerprint differs: models.diffusion_models/z_image_turbo_bf16.safetensors: " "names the model file"
  R9700_COMFY_REF=v0.45.0 assert_exit 2 "another ComfyUI tag" -- bench_fp zimage 2 base fp16acc
  assert_contains "$ERR" "fingerprint differs: comfy_ref: v0.44.0 -> v0.45.0" "comfy_ref"
  printf '[{"Id": "sha256:other"}]\n' > "$STUB/answers/inspect"
  assert_exit 2 "another image Id" -- bench_fp zimage 2 base fp16acc
  assert_contains "$ERR" "fingerprint differs: image.id: sha256:stub -> sha256:other" "image.id"
  rm -f "$STUB/answers/inspect"
  assert_eq "$h" "$(sha256sum < "$fp")" "the stored file was not changed by any refused call"
  assert_eq "" "$(bench_names)" "no bench container"
  assert_eq "$stops_before" "$(stops | wc -l | tr -d ' ')" "and nothing was stopped"
  assert_exit 0 "more rounds" -- bench_fp zimage 3 base fp16acc
  assert_contains "$OUT" "fingerprint: rounds extended 2 -> 3" "an extension"
  assert_eq "3" "$(python3 "$REPO/lib/fingerprint.py" show "$fp" rounds)" "merged"
  assert_exit 0 "a new arm" -- bench_fp zimage 3 base fp16acc miopen
  assert_contains "$OUT" "fingerprint: arm miopen added" "an extension"
  assert_eq "base fp16acc miopen" "$(python3 "$REPO/lib/fingerprint.py" show "$fp" arms | tr '\n' ' ' | sed 's/ $//')" "merged"
  h="$(sha256sum < "$fp")"
  assert_exit 0 "a dry run of a larger experiment" -- comfy_bench_check zimage 4 base fp16acc
  comfy_bench_fingerprint "$OUTD" zimage 4 dry base fp16acc > /dev/null 2>&1
  assert_eq "$h" "$(sha256sum < "$fp")" "dry writes nothing: the stored file is byte-identical"
  newout cb2
  comfy_bench_check zimage 1 base
  assert_exit 0 "a dry run in a new outdir" -- comfy_bench_fingerprint "$OUTD" zimage 1 dry base
  assert_missing "$OUTD" "writes no folder"
}

# BF3
t_no_new_fingerprint_is_built_over_records_whose_identity_is_lost() {
  bench_setup "$FUNCNAME"
  mkdir -p "$OUTD/rounds/base-1"
  comfy_bench_check zimage 1 base
  assert_exit 2 "rounds/ and no fingerprint.json" -- comfy_bench_fingerprint "$OUTD" zimage 1 real base
  assert_contains "$ERR" "r9700: comfy: bench: $OUTD has rounds/ or rejected/ but no fingerprint.json: " "the series' line with bench in it"
  assert_contains "$ERR" "use a new --out name" "and the advice"
  assert_missing "$OUTD/fingerprint.json" "nothing was written"
  assert_exit 2 "a dry run is refused too" -- comfy_bench_fingerprint "$OUTD" zimage 1 dry base
  assert_contains "$ERR" "has rounds/ or rejected/ but no fingerprint.json" "with the same line"
  newout cb2
  mkdir -p "$OUTD/rejected/base-1-x"
  assert_exit 2 "rejected/ alone" -- comfy_bench_fingerprint "$OUTD" zimage 1 real base
}

# BF4
t_a_missing_image_or_model_file_refuses_before_anything_is_stopped() {
  bench_setup "$FUNCNAME"
  printf '1\n' > "$STUB/answers/inspect_rc"
  comfy_bench_check zimage 1 base
  assert_exit 2 "an image that is not there" -- comfy_bench_fingerprint "$OUTD" zimage 1 real base
  assert_eq "r9700: comfy: bench: the image comfyui-r9700:local is not there (inspect code 1); run bin/r9700 comfy build first" "$ERR" "names the code and the verb to run"
  assert_missing "$OUTD/fingerprint.json" "no fingerprint"
  assert_eq "" "$(bench_names)" "no container"
  rm -f "$STUB/answers/inspect_rc" "$STUB/calls.log" "$STUB/calls.argv"
  printf 'diffusion_models/z_image_turbo_bf16.safetensors 1000\ntext_encoders/qwen_3_4b.safetensors 1000\n' > "$STUB/answers/comfy_models_listing"
  assert_exit 2 "a model file that is not in the volume" -- comfy_bench_fingerprint "$OUTD" zimage 1 real base
  assert_eq "r9700: comfy: bench: /models/vae/ae.safetensors is not in the models volume (zimage of comfyui/models.conf); run bin/r9700 comfy fetch zimage first" "$ERR" "names the file, the set and the verb to run"
  argv_of_verb run 1
  assert_exit 0 "the listing container has the models volume read-only" -- has_pair -v comfy-models:/models:ro
  assert_exit 0 "runs sh as its entrypoint" -- has_pair --entrypoint sh
  assert_exit 1 "and has no card" -- has_word --gpus
}

# BF4 (E2.S2 review): the folders the entrypoint of a bench container makes, and the listing kept in the record
t_a_missing_model_folder_refuses_naming_comfy_start_and_the_listing_is_kept_in_the_record() {
  bench_setup "$FUNCNAME"
  assert_exit 0 "the scan is alive: the folders are read from comfyui/entrypoint.sh" -- test "$(_cb_entry_folders | wc -l | tr -d ' ')" -ge 12
  assert_contains "$(_cb_entry_folders | tr '\n' ' ')" "loras " "among them the folder of the LoRA"
  comfy_bench_check zimage 1 base
  printf 'diffusion_models/z_image_turbo_bf16.safetensors 1000\ntext_encoders/qwen_3_4b.safetensors 1000\nvae/ae.safetensors 1000\nmissing-dir loras\n' > "$STUB/answers/comfy_models_listing"
  assert_exit 2 "a models volume without the loras folder (the entrypoint cannot make it on a read-only volume)" -- comfy_bench_fingerprint "$OUTD" zimage 1 real base
  assert_contains "$ERR" "/models/loras is not a folder of the models volume" "names the folder"
  assert_contains "$ERR" "run bin/r9700 comfy start once (it creates them)" "and the verb that makes it"
  assert_missing "$OUTD/fingerprint.json" "no fingerprint"
  assert_eq "" "$(bench_names)" "no container"
  rm -f "$STUB/answers/comfy_models_listing"
  assert_exit 0 "a complete volume" -- comfy_bench_fingerprint "$OUTD" zimage 1 real base
  assert_exit 0 "the listing is kept in the record, appended with its time and workflow" -- grep -Eq '^# [0-9T:Z-]+ zimage$' "$OUTD/models_listing.txt"
  assert_contains "$(cat "$OUTD/models_listing.txt")" "vae/ae.safetensors 1000" "with the files it listed"
  assert_exit 0 "a second call" -- comfy_bench_fingerprint "$OUTD" zimage 1 real base
  assert_eq "2" "$(grep -c '^# ' "$OUTD/models_listing.txt")" "appends: nothing is rewritten"
  assert_exit 0 "a dry call" -- comfy_bench_fingerprint "$OUTD" zimage 1 dry base
  assert_eq "2" "$(grep -c '^# ' "$OUTD/models_listing.txt")" "writes nothing"
}

# BF5
t_the_model_identity_is_the_pinned_hash_of_exactly_the_files_the_workflow_loads() {
  bench_setup "$FUNCNAME"
  assert_exit 0 "the fingerprint of wan5b" -- bench_fp wan5b 1 base
  local fp="$OUTD/fingerprint.json" models="$CASE/models.conf" pin=79290493711b022e1c6e655d803715cd8a91a75cdb139856cad46f354e2f681c
  assert_eq "diffusion_models/wan2.2_ti2v_5B_fp16.safetensors loras/Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors vae/wan2.2_vae.safetensors" "$(python3 "$REPO/lib/fingerprint.py" show "$fp" models | tr '\n' ' ' | sed 's/ $//')" "exactly the four wan5b files, the LoRA among them"
  assert_eq "$pin" "$(python3 "$REPO/lib/fingerprint.py" show "$fp" models.loras/Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors)" "with the pinned hash"
  sed "s/$pin/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/" "$REPO/comfyui/models.conf" > "$models"
  R9700_COMFY_MODELS_CONF="$models" assert_exit 2 "a models.conf copy with the LoRA's pin changed" -- bench_fp wan5b 1 base
  assert_contains "$ERR" "fingerprint differs: models.loras/Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors: " "names the loras/ key"
  sed 's/e9476a13728cd75d8279f6ec8bad753a66a1957ca375a1464dc63b37db6e3916/cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc/' "$REPO/comfyui/models.conf" > "$models"
  R9700_COMFY_MODELS_CONF="$models" assert_exit 0 "a changed pin of an sd15 file" -- bench_fp wan5b 1 base
  assert_eq "" "$OUT" "is no difference for wan5b"
}

# the seam's dry run (the verb's `--dry-run` calls it; E2.S3 owns the call site)
t_the_dry_run_prints_the_commands_of_the_first_arm_round_and_starts_nothing() {
  bench_setup "$FUNCNAME"
  comfy_bench_check zimage 1 fp8wmm base
  rm -f "$STUB/calls.log" "$STUB/calls.argv"
  assert_exit 0 "the dry run of fp8wmm" -- comfy_bench_dry_run "$OUTD" zimage 1 fp8wmm base
  assert_eq "6" "$(grep -c '^dry-run: ' <<< "$OUT")" "the clear, the container and the four runs"
  assert_contains "$OUT" "dry-run: wslc run --rm --name r9700tune-comfy-clear-1 -v r9700tune-comfy-cache:/cache --entrypoint sh " "the clear"
  assert_contains "$OUT" "wslc run -d --rm --name r9700tune-comfy-fp8wmm-1 --gpus all --tmpfs /data:exec,size=8g -v comfy-models:/models:ro " "the container with the isolation words"
  assert_contains "$OUT" "-e COMFY_BENCH_WEIGHT_DTYPE=fp8_e4m3fn " "the arm's environment"
  assert_contains "$OUT" "--output-directory /work/r9700/comfyui/bench/cb/fp8wmm-1 --fast fp8_matrix_mult" "ComfyUI's arguments: the output folder, then the arm's"
  assert_contains "$OUT" "dry-run: run cold: wslc exec r9700tune-comfy-fp8wmm-1 env COMFY_BENCH_WEIGHT_DTYPE=fp8_e4m3fn python3 /work/r9700/comfyui/bench.py run zimage --tag fp8wmm-1 --run cold --out /work/r9700/comfyui/bench/cb/fp8wmm-1" "the cold run through exec with the arm's words on the line"
  assert_missing "$STUB/calls.log" "nothing was called"
  assert_missing "$OUTD" "and nothing was written"
}

run_all_tests
