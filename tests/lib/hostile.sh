#!/usr/bin/env bash
# The ONE list of hostile model-url shapes, iterated by BOTH tests/test_comfy.sh (MC2: comfy_models_load) and tests/test_comfy_fetch_model.sh (FM10: comfyui/fetch_model.sh), so the two
# implementations of the url and file-name rule (lib/comfy.sh and the script, which cannot source it) are fed the same shapes. Sourced, never run; no t_ function in it.
#
#   HOSTILE_URL_TAILS    each is the part of a url after the host and a `/`: a file name that is not a name (`-x.bin`, `.`, `..`, a trailing `/`), or a url with a character a url must not hold
#                        (a quote, a backslash, a backtick, a bracket, a brace, a blank). The tests put their own scheme and host in front: https in models.conf, http for the local server of FM10
#   HOSTILE_URL_NAMES    the file name of a url that is NOT hostile, and the urls whose names both derivations must agree on (MC4)

HOSTILE_URL_TAILS=(
  "r/-x.bin"
  "r/.."
  "r/."
  "r/dir/"
  "r/a[1].bin"
  "r/a{1,2}.bin"
  'r/a"b.bin'
  'r/a\b.bin'
  'r/a`b.bin'
  "r/a.bin?x=[1]"
  "r/a b.bin"
)

# urls whose file name both derivations must give identically (the first column of each pair is the url, the second what both must print)
NAME_DERIVATION_URLS=(
  "https://h.example/r/x.bin|x.bin"
  "https://h.example/r/x.bin?download=true|x.bin"
  "https://h.example/r/x.bin#frag|x.bin"
  "https://h.example/r/x.bin?a=/b/c|x.bin"
  "https://h.example/r/dir/|"
  "https://h.example/r/..|.."
  "https://h.example/r/.|."
  "https://h.example/r/-x.bin|-x.bin"
  "https://h.example/r/a.b-c_d.safetensors|a.b-c_d.safetensors"
  "https://h.example|h.example"
  "https://h.example/r/..?x=/y.bin|.."
)
