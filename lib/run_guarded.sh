#!/usr/bin/env bash
# lib/run_guarded.sh — the supervisor's engine. SOURCED; defines functions and runs nothing. Bash >= 4.4, `set -u` safe, no `set -e`.
#
# E1.S2 part (a) holds only the two scale functions the adapter and the guards need; the engine itself (lock, steps, guards, the cleanup
# path) is added by the parts that build it.
#
#   t_scale <seconds>     <seconds> / R9700_TIME_SCALE, two decimals: every sleep in lib/
#   t_ceiling <seconds>   <seconds> / R9700_CEILING_SCALE (default: R9700_TIME_SCALE), two decimals: every ceiling of the adapter
#                         both: 1 when the scale is not a positive integer, 2 on bad seconds

# _scale_div <scale variable name> <scale value> <seconds>: the one division. The result is never below 0.01, because `timeout 0` means
# no ceiling at all.
_scale_div() {
  local name="$1" scale="$2" seconds="${3:-}"
  case $scale in
    '' | *[!0-9]* | 0 | 0[0-9]*)
      echo "t_scale: $name must be a positive integer without a leading zero (got \"$scale\")" >&2
      return 1
      ;;
  esac
  if ! [[ $seconds =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "t_scale: usage: t_scale <seconds> (a non-negative number; got \"$seconds\")" >&2
    return 2
  fi
  awk -v seconds="$seconds" -v scale="$scale" 'BEGIN { v = seconds / scale; if (v < 0.01) v = 0.01; printf "%.2f\n", v }'
}

# t_scale <seconds>: EVERY sleep in lib/ takes its number from here, so a test can run 1200 s as 12 s (R9700_TIME_SCALE=100). The default
# scale is 1: the production values are the literals of the old scripts. R9700_TIME_SCALE is a test knob: the environment only, never
# machine.env.
t_scale() { _scale_div R9700_TIME_SCALE "${R9700_TIME_SCALE-1}" "${1:-}"; }

# t_ceiling <seconds>: every ceiling of an adapter call (and its kill-after grace). R9700_CEILING_SCALE divides only these; it defaults to
# R9700_TIME_SCALE, and a test sets it to 1 to keep the ceilings real while the sleeps run fast.
t_ceiling() {
  if [ -n "${R9700_CEILING_SCALE+set}" ]; then
    _scale_div R9700_CEILING_SCALE "$R9700_CEILING_SCALE" "${1:-}"
  else
    _scale_div R9700_TIME_SCALE "${R9700_TIME_SCALE-1}" "${1:-}"
  fi
}
