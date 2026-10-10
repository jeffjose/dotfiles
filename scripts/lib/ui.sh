# Cargo-style output, shared by the update scripts and appimage.sh so they read
# like ./setup: a right-aligned coloured verb, then the detail.
#
#     Updating mise
#        Fresh ghostty  1.2.3
#     Finished 5 steps in 1m 12s
#
# Source this file; it only defines colours and a few helpers. Colours are empty
# when stdout is not a terminal or NO_COLOR is set, so piped output stays plain.

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  GREEN=$'\e[1;32m' YELLOW=$'\e[1;33m' RED=$'\e[1;31m' CYAN=$'\e[1;36m'
  BOLD=$'\e[1m' DIM=$'\e[2m' RESET=$'\e[0m'
else
  GREEN='' YELLOW='' RED='' CYAN='' BOLD='' DIM='' RESET=''
fi

# say <colour> <verb> <detail>
say() { printf '%s%12s%s %s\n' "$1" "$2" "$RESET" "$3"; }

# A continuation line, aligned under the detail of the verb above it.
detail() { printf '%12s %s\n' '' "$*"; }

# Problems go to stderr, like cargo's warning:/error: lines.
warn() { say "$YELLOW" "Warning" "$*" >&2; }
err() { say "$RED" "Error" "$*" >&2; }

# Microseconds since the epoch, for timing a run.
now_us() { printf '%s' "${EPOCHREALTIME//[^0-9]/}"; }

# elapsed <start_us>: time since then as "840ms", "12.3s" or "1m 32s".
elapsed() {
  local ms=$((($(now_us) - $1) / 1000))
  if [ "$ms" -lt 1000 ]; then
    printf '%dms' "$ms"
  elif [ "$ms" -lt 60000 ]; then
    printf '%d.%ds' $((ms / 1000)) $((ms % 1000 / 100))
  else
    printf '%dm %ds' $((ms / 60000)) $((ms % 60000 / 1000))
  fi
}
