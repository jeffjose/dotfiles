#!/usr/bin/env -S bash --noprofile
#
# Update mise tools
#
# Usage: update_mise.sh [-v|--verbose] [--filter PATTERN | PATTERN...]
#        update_mise.sh -c|--check [-u|--update] [PATTERN...]
#        update_mise.sh -b|--branches
#
#   -c, --check       Change nothing: list the tools built from a git branch
#                     (the cargo:https://... = "branch:..." ones) and say for
#                     each whether the installed build is the branch's latest
#                     commit. mise itself cannot tell: to it "branch:main" is
#                     the version, and that is installed.
#   -u, --update      With --check (which it implies): after the list, update
#                     the tools in it that are behind, as `update_mise.sh
#                     NAME...` would.
#   -b, --branches    Only the branch-built tools: check each against its
#                     branch on GitHub and rebuild the ones that are behind,
#                     then check that every mise tool is installed, shimmed
#                     and executable (reinstalling the ones that are not).
#                     Nothing else is upgraded. This is what `m` runs.
#   -v, --verbose     Show everything mise prints, live. By default only what
#                     changed and what went wrong is shown; the rest goes to a
#                     log, whose path is printed when something fails.
#   --filter PATTERN  Only upgrade, prune and check the tools whose name contains
#                     PATTERN (case-insensitive substring). Skips the dotfiles
#                     pull and mise self-update.
#                     e.g. `update_mise.sh --filter claude` upgrades both
#                     `claude` and `npm:@anthropic-ai/claude-code`.
#                     A bare PATTERN is the same thing, and there can be
#                     several: `update_mise.sh safeclean magicfs`.

# The whole script sits inside one { ... } so that bash has read all of it before
# it runs any of it. Bash otherwise reads a script a piece at a time as it goes,
# and this one runs for many minutes: edit the file meanwhile and the running
# copy carries on from the same byte offset in the new text, which lands
# mid-line and fails with something like "line 219: prevent: command not found".
{
set -euo pipefail

source "$HOME/dotfiles/scripts/lib/ui.sh"

# mise is in ~/.local/bin (the installer firstrun uses) or ~/.cargo/bin (older
# machines). The shell rc puts both on PATH, but a shell that has not read it
# yet — the one firstrun was started from, cron — has neither.
command -v mise >/dev/null 2>&1 || export PATH="$HOME/.cargo/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

# Force npm to run postinstall scripts and pull platform-native optional deps
# even if ~/.npmrc disables them (e.g. corporate hardening). Without this, mise's
# npm: backend silently produces broken installs of @anthropic-ai/claude-code etc.
export npm_config_ignore_scripts=false
export npm_config_omit=

# On a corp host, keep the tools listed in apps/mise-corp.toml out of every mise
# call below. ./setup links that file into mise's config, which covers mise run
# by hand too — but setup is best-effort in a uq run, and this must not depend
# on it having worked.
source "$HOME/dotfiles/scripts/lib/host.sh"
if is_corp_host; then
  corp_blocked=$(corp_blocked_mise_tools | paste -sd, -)
  if [[ -n "$corp_blocked" ]]; then
    export MISE_DISABLE_TOOLS="$corp_blocked"
    say "$YELLOW" "Corp host" "mise will not install or upgrade: ${corp_blocked//,/, }"
  fi
fi

MISE_DATA_DIR="${MISE_DATA_DIR:-$HOME/.local/share/mise}"
MISE_CACHE_DIR="${MISE_CACHE_DIR:-$HOME/.cache/mise}"

# Bytes used by mise's installs + cache, for the before/after report.
mise_disk_usage() {
  du -sb "$MISE_DATA_DIR" "$MISE_CACHE_DIR" 2>/dev/null | awk '{s+=$1} END {printf "%.0f\n", s}'
}

filter=""
verbose=0
check=0
branches=0
update=0
names=() # bare words: the same as --filter, any number of them
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbose) verbose=1; shift ;;
    -c|--check) check=1; shift ;;
    -u|--update) update=1; check=1; shift ;;
    -b|--branches) branches=1; shift ;;
    -f|--filter) filter="${2:?--filter needs a pattern}"; shift 2 ;;
    --filter=*)  filter="${1#*=}"; shift ;;
    -h|--help)   sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
    -*) err "unknown argument: $1"; exit 2 ;;
    *) names+=("$1"); shift ;;
  esac
done

# --filter X and a bare X are the same thing.
[[ -z "$filter" ]] || names+=("$filter")

# mise prints a line for every tool it looks at, 120-odd on a run that changes
# nothing, and the one line that matters scrolls away among them. So unless -v
# was given its output goes to a log instead, and this script says what changed.
# Under uq the log sits with the other step logs of that run.
MISE_LOG="${UQ_LOG_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/uq}/mise-detail.log"
if [[ $verbose -eq 0 ]]; then
  mkdir -p "${MISE_LOG%/*}" 2>/dev/null && : >"$MISE_LOG" 2>/dev/null || verbose=1
fi

# The part of the log written since byte offset $1, as plain text: no escape
# sequences, progress-bar redraws split into lines, repeats dropped.
log_since() {
  tail -c +"$(($1 + 1))" "$MISE_LOG" 2>/dev/null |
    sed -e 's/\x1b\[[0-9;?]*[A-Za-z]//g' -e 's/\r/\n/g' | awk 'NF && !seen[$0]++'
}

# quietly <command...>: run a command with its output in the log, not on screen
#
# If it fails, the lines of its output that say why are printed, with the path
# of the log for the rest. QUIET_FROM is left at the offset where the command's
# output starts, for callers that want to read more out of it.
QUIET_FROM=0
quietly() {
  if [[ $verbose -eq 1 ]]; then
    "$@"
    return
  fi
  local status=0 line
  QUIET_FROM=$(stat -c %s "$MISE_LOG" 2>/dev/null || echo 0)
  printf '\n$ %s\n' "$*" >>"$MISE_LOG"
  "$@" >>"$MISE_LOG" 2>&1 || status=$?
  if [[ $status -ne 0 ]]; then
    err "\`$*\` failed (exit $status)"
    while IFS= read -r line; do
      detail "$line" >&2
    done < <(log_since "$QUIET_FROM" | grep -E 'ERROR|✗|error(:|\[)|[Ff]ailed|not supported|No such file' | tail -n 10)
    detail "${DIM}full output: ${MISE_LOG/#$HOME/\~}$RESET" >&2
  fi
  return $status
}

# `mise upgrade` warns twice per branch-pinned tool (the cargo:…jeffjose/* repos
# on branch:main) on every run — "something weird happened with versioning" and
# "upgrading non-version tool requests". Both are expected for a branch ref, so
# drop just those lines from stderr; every other warning still gets through.
#
# Without -v none of that is on screen anyway: the tools about to change are
# listed first, the upgrade itself runs quietly, and the releases mise held back
# for being under a day old (minimum_release_age) are summed up in one line.
mise_upgrade() {
  if [[ $verbose -eq 1 ]]; then
    mise upgrade "$@" 2> >(grep -v -e 'something weird happened with versioning' \
                                 -e 'upgrading non-version tool requests' >&2)
    return
  fi

  # Tools are named the short way in both lists below: "codex", not
  # "npm:@openai/codex".
  local name cur new status=0 held outdated width=0 cwidth=0
  outdated=$(mise outdated --json "$@" 2>/dev/null |
    jq -r 'to_entries[] | "\(.key | sub(".*[:/]"; ""))\t\(.value.current // "-")\t\(.value.latest // "?")"' 2>/dev/null || true)
  while IFS=$'\t' read -r name cur new; do
    ((${#name} > width)) && width=${#name}
    ((${#cur} > cwidth)) && cwidth=${#cur}
  done <<<"$outdated"
  while IFS=$'\t' read -r name cur new; do
    [[ -n "$name" ]] || continue
    say "$GREEN" "Upgrading" "$(printf '%-*s  %-*s → %s' "$width" "$name" "$cwidth" "$cur" "$new")"
  done <<<"$outdated"
  [[ -n "$outdated" ]] || say "$DIM" "Fresh" "${DIM}nothing to upgrade$RESET"

  quietly mise upgrade "$@" || status=$?

  held=$(log_since "$QUIET_FROM" |
    sed -nE 's/.*newer (.+) release ([^ ]+) \(.*ignored by minimum_release_age.*/\1 \2/p' |
    sed -E 's|^[^ ]*[:/]||')
  local vwidth=0
  width=0
  while read -r name new; do
    ((${#name} > width)) && width=${#name}
    ((${#new} > vwidth)) && vwidth=${#new}
  done <<<"$held"
  while read -r name new; do
    [[ -n "$name" ]] || continue
    say "$DIM" "Held back" "$(printf '%s%-*s  %-*s  (under 24h old)%s' "$DIM" "$width" "$name" "$vwidth" "$new" "$RESET")"
  done <<<"$held"
  return $status
}

# Rebuild the branch-pinned cargo git tools whose branch has moved.
#
# To mise, "branch:main" is the version, and it is already installed — so
# `mise upgrade` never looks at those repos again and a push to one of them
# reaches no machine. (This is not minimum_release_age: a branch ref has no
# release date, so the quarantine never applies to it.) cargo records the commit
# it built in .crates.toml; compare that to the branch tip and force a reinstall
# when they differ.
#
# A tool that is not installed yet counts as stale too, so this is also what
# installs a newly listed one — which is why it runs ahead of `mise upgrade`.
#
# Each tool mise (re)builds here also loses its copy in ~/.cargo/bin, see
# drop_dev_copy. A tool whose branch has not moved is left alone, dev copy and
# all.
#
# refresh_branch_tools [tool...]: all such tools, or only the ones named.
refresh_branch_tools() {
  local tool path branch url built tip entry
  local -a stale=()
  while IFS=$'\t' read -r tool path branch; do
    if [[ $# -gt 0 ]] && ! printf '%s\n' "$@" | grep -qxF -- "$tool"; then
      continue
    fi
    url=${tool#cargo:}
    built=$(grep -oE '#[0-9a-f]{40}' "$path/.crates.toml" 2>/dev/null | head -n1 | tr -d '#') || true
    tip=$(git ls-remote "$url" "refs/heads/$branch" 2>/dev/null | cut -f1) || true
    if [[ -z "$tip" ]]; then
      warn "could not read $branch of $url; leaving it as is"
    elif [[ "$built" != "$tip" ]]; then
      if [[ -n "$built" ]]; then
        say "$GREEN" "Rebuilding" "${url##*/} ${built:0:7} → ${tip:0:7}"
      else
        say "$GREEN" "Installing" "${url##*/} ${tip:0:7}"
      fi
      stale+=("$tool"$'\t'"$path")
    fi
  done < <(mise ls --current --json 2>/dev/null |
    jq -r 'to_entries[] | .key as $k | .value[]
           | select(($k | startswith("cargo:https://")) and (.version | startswith("branch:")))
           | "\($k)\t\(.install_path)\t\(.version | ltrimstr("branch:"))"' 2>/dev/null || true)

  BRANCH_TOOLS_STALE=${#stale[@]}
  [[ ${#stale[@]} -gt 0 ]] || return 0
  for entry in "${stale[@]}"; do
    IFS=$'\t' read -r tool path <<<"$entry"
    if quietly mise install --force "$tool"; then
      drop_dev_copy "$path"
    else
      warn "building $tool failed; continuing"
    fi
  done
}

# ~/.cargo/bin sits ahead of the mise shims on PATH, so that a `cargo install
# --path .` of a tool under development wins over the copy mise built from its
# branch. The cost is that the dev copy would go on winning after the work is
# pushed and mise has built something newer. So when mise builds a tool, the
# copy of the same crate in ~/.cargo/bin goes; the next `cargo install --path .`
# puts it back.
#
# drop_dev_copy <mise install path>
drop_dev_copy() {
  local cargo_home="${CARGO_HOME:-$HOME/.cargo}" crate
  while read -r crate; do
    grep -q "^\"$crate " "$cargo_home/.crates.toml" 2>/dev/null || continue
    if cargo uninstall --quiet --root "$cargo_home" "$crate"; then
      say "$YELLOW" "Removed" "dev copy of $crate, in favor of mise"
    else
      warn "could not remove the dev copy of $crate from $cargo_home/bin"
    fi
  done < <(sed -nE 's/^"([^ "]+) .*/\1/p' "$1/.crates.toml" 2>/dev/null)
}

# Point rustup's default toolchain at the rust mise resolved.
#
# mise's rust is a numbered rustup toolchain, picked by the RUSTUP_TOOLCHAIN the
# mise shim sets. But ~/.cargo/bin is ahead of the shims on PATH, so a plain
# `cargo` is the rustup proxy and builds with rustup's own default instead —
# "stable", which nothing here updates. That one sits at whatever `rustup
# update` last left on each machine, so the same checkout builds on one box and
# dies with "rustc 1.85.1 is not supported by the following packages" on the
# next. Making mise's toolchain the default leaves one rust, and `mise upgrade`
# already keeps it current.
sync_rustup_default() {
  local want
  command -v rustup >/dev/null 2>&1 || return 0
  want=$(mise current rust 2>/dev/null) || return 0
  [[ -n "$want" ]] || return 0
  [[ "$(rustup default 2>/dev/null)" == "$want-"* ]] && return 0
  if rustup default "$want" >/dev/null 2>&1; then
    say "$GREEN" "Switched" "rustup default to $want, the rust mise manages"
  else
    warn "could not make $want the rustup default; plain \`cargo\` may use an older rust"
  fi
}

# Is every mise tool actually there to run?
#
# mise's own word for it is not enough. Each of these has happened, with mise
# listing the tool installed and current, so that `mise upgrade` had nothing to
# do and no number of re-runs fixed it:
#
#   - an empty bin/: cargo installs of gifski, cargo-update and tzupdate sat
#     empty for weeks (or an old copy in ~/.cargo/bin answered in their place)
#   - a placeholder: npm:pnpm ships a shebang-less stub that its postinstall
#     swaps for the native binary; aube blocks postinstall, so the stub stayed
#     and pnpm died in node's ESM loader
#   - dangling links: npm: tools link into the aube store under ~/.cache, which
#     anything clearing ~/.cache takes away
#   - a lost interpreter: pipx tools start with #!<venv>/bin/python, a link to a
#     python that `mise prune` can remove
#   - no shim: what `m` exists to fix
#
# So each command in each tool's bin paths is looked at: it must resolve, be a
# binary or a #! script whose interpreter exists, and have a shim. Nothing is
# run -- 150-odd commands, some of which would do something when started with
# no arguments, or with --version.
#
# A tool with a problem is reinstalled (forced: to mise it is installed
# already), then the shims are rebuilt and the tool looked at again.
#
# check_mise_tools [tool...]: all tools, or only the ones named.
check_mise_tools() {
  local line tool why
  local -a broken=() again=()

  scan_mise_tools "$@"
  if [[ ${#SCAN_PROBLEMS[@]} -eq 0 ]]; then
    local cmds="$SCAN_COMMANDS commands" tools="$SCAN_TOOLS tools"
    [[ $SCAN_COMMANDS -ne 1 ]] || cmds="1 command"
    [[ $SCAN_TOOLS -ne 1 ]] || tools="1 tool"
    say "$DIM" "Healthy" "${DIM}$cmds from $tools: all installed, shimmed and executable$RESET"
    return 0
  fi

  while IFS= read -r line; do
    IFS=$'\t' read -r tool why <<<"$line"
    say "$YELLOW" "Broken" "${tool##*[:/]} ${DIM}($why)$RESET"
    # A missing shim is fixed by the reshim below; anything else is the tool.
    [[ "$why" == *": no shim" ]] || broken+=("$tool")
  done < <(grouped_problems)
  mapfile -t broken < <(printf '%s\n' "${broken[@]}" | awk 'NF && !seen[$0]++')
  mapfile -t again < <(printf '%s\n' "${SCAN_PROBLEMS[@]}" | cut -f1 | awk '!seen[$0]++')

  for tool in "${broken[@]}"; do
    say "$YELLOW" "Repairing" "${tool##*[:/]}: reinstalling"
    quietly mise install --yes --force "$tool" || true
  done
  say "$YELLOW" "Repairing" "rebuilding the shims"
  quietly mise reshim || true
  hash -r

  scan_mise_tools "${again[@]}"
  if [[ ${#SCAN_PROBLEMS[@]} -eq 0 ]]; then
    say "$GREEN" "Repaired" "${again[*]##*[:/]}"
    return 0
  fi
  while IFS= read -r line; do
    IFS=$'\t' read -r tool why <<<"$line"
    err "${tool##*[:/]} is still broken ($why)"
  done < <(grouped_problems)
  detail "${DIM}full output: ${MISE_LOG/#$HOME/\~}$RESET" >&2
  return 1
}

# SCAN_PROBLEMS with the commands of one tool that are wrong in the same way on
# one line: "pnpm<TAB>pn, pnpm, pnpx: no shim", not three.
grouped_problems() {
  [[ ${#SCAN_PROBLEMS[@]} -gt 0 ]] || return 0
  printf '%s\n' "${SCAN_PROBLEMS[@]}" | awk -F'\t' '
    {
      name = ""; why = $2
      if (match($2, /^[^ ]+: /)) { name = substr($2, 1, RLENGTH - 2); why = substr($2, RLENGTH + 1) }
      key = $1 "\t" why
      if (!(key in names)) { order[++n] = key; names[key] = name }
      else if (name != "") names[key] = names[key] ", " name
    }
    END {
      for (i = 1; i <= n; i++) {
        split(order[i], k, "\t")
        print k[1] "\t" (names[order[i]] != "" ? names[order[i]] ": " : "") k[2]
      }
    }'
}

# scan_mise_tools [tool...]: look at all tools, or only the ones named. Leaves
# "tool<TAB>what is wrong" lines in SCAN_PROBLEMS, and how many commands and
# tools it looked at in SCAN_COMMANDS and SCAN_TOOLS.
SCAN_PROBLEMS=()
SCAN_COMMANDS=0
SCAN_TOOLS=0
scan_mise_tools() {
  local tool installed path dir file name why mine found
  local installs="$MISE_DATA_DIR/installs" shims="$MISE_DATA_DIR/shims"
  SCAN_PROBLEMS=()
  SCAN_COMMANDS=0
  SCAN_TOOLS=0

  while IFS=$'\t' read -r tool installed path; do
    if [[ $# -gt 0 ]] && ! printf '%s\n' "$@" | grep -qxF -- "$tool"; then
      continue
    fi
    if [[ "$installed" != true ]]; then
      SCAN_PROBLEMS+=("$tool"$'\t'"not installed")
      continue
    fi
    mine=0 found=0
    while IFS= read -r dir; do
      # rust's bin path is ~/.cargo/bin, which holds `cargo install` builds of
      # my own as well; those are not rust's, and not mise's to reinstall.
      [[ "$dir" == "$installs"/* ]] || continue
      mine=1
      for file in "$dir"/*; do
        [[ -L "$file" || (-f "$file" && -x "$file") ]] || continue
        found=1
        ((SCAN_COMMANDS++)) || true
        name=${file##*/}
        why=$(exec_problem "$file")
        [[ -e "$shims/$name" ]] || why=${why:-"no shim"}
        [[ -z "$why" ]] || SCAN_PROBLEMS+=("$tool"$'\t'"$name: $why")
      done
    done < <(mise bin-paths "$tool" 2>/dev/null)
    ((mine)) || continue
    ((SCAN_TOOLS++)) || true
    ((found)) || SCAN_PROBLEMS+=("$tool"$'\t'"no commands in ${path/#$HOME/\~}")
  done < <(mise ls --current --json 2>/dev/null |
    jq -r 'to_entries[] | .key as $k | .value[] | "\($k)\t\(.installed)\t\(.install_path)"' 2>/dev/null || true)
}

# exec_problem <file>: why <file> could not be run, or nothing if it could.
exec_problem() {
  local file=$1 magic line cmd i
  local -a words
  if [[ ! -e "$file" ]]; then
    echo "dangling link to $(readlink "$file")"
    return
  fi
  [[ -s "$file" ]] || { echo "empty file"; return; }
  magic=$(head -c 4 "$file" | od -An -tx1 | tr -d ' \n')
  case $magic in
    7f454c46 | cffaedfe | cefaedfe | cafebabe) return ;; # ELF, Mach-O
    2321*) ;;                                           # #!
    *) echo "neither a binary nor a #! script"; return ;;
  esac
  IFS= read -r line <"$file" || true
  read -ra words <<<"${line#\#!}"
  cmd=${words[0]:-}
  if [[ "$cmd" == */env ]]; then
    # #!/usr/bin/env [-S] [VAR=value...] command: the command is on PATH.
    for ((i = 1; i < ${#words[@]}; i++)); do
      [[ "${words[i]}" == -* || "${words[i]}" == *=* ]] || break
    done
    cmd=${words[i]:-}
    command -v "$cmd" >/dev/null 2>&1 || echo "its interpreter, $cmd, is not on PATH"
  elif [[ ! -x "$cmd" ]]; then
    echo "its interpreter, ${cmd/#$HOME/\~}, is gone"
  fi
}

report_disk_usage() {
  local size_after
  size_after=$(mise_disk_usage)
  say "$GREEN" "Disk" "mise $(numfmt --to=iec "$size_before") → $(numfmt --to=iec "$size_after") \
$DIM(saved $(numfmt --to=iec -- $((size_before - size_after))))$RESET"
}

size_before=$(mise_disk_usage)

# One tool that will not build must not take the rest of the run with it: the
# upgrade is allowed to fail, everything after it still runs, and the failure is
# reported (and the exit status set) at the end.
upgrade_ok=true

# --check: where each branch-built tool stands, without touching anything.
#
# Same comparison as refresh_branch_tools: the commit cargo recorded in
# .crates.toml against the tip of the branch. It also says when the copy that
# actually runs is not mise's — a `cargo install --path .` build in ~/.cargo/bin
# is ahead of the shims on PATH, and that one is whatever was in the working
# tree when it was built.
branch_status() {
  local tool path branch url name built tip bin note behind=0
  local -a rows=()
  while IFS=$'\t' read -r tool path branch; do
    url=${tool#cargo:}
    name=${url##*/}
    if [[ ${#names[@]} -gt 0 ]]; then
      grep -qiF -f <(printf '%s\n' "${names[@]}") <<<"$name" || continue
    fi
    built=$(grep -oE '#[0-9a-f]{40}' "$path/.crates.toml" 2>/dev/null | head -n1 | tr -d '#') || true
    tip=$(git ls-remote "$url" "refs/heads/$branch" 2>/dev/null | cut -f1) || true
    note=""
    while read -r bin; do
      [[ -n "$bin" && -x "${CARGO_HOME:-$HOME/.cargo}/bin/$bin" ]] && note="  ${YELLOW}but ~/.cargo/bin/$bin (a dev build) is what runs$RESET"
    done < <(sed -n 's/.*= \[\(.*\)\]/\1/p' "$path/.crates.toml" 2>/dev/null | tr -d '" ' | tr ',' '\n')
    if [[ -z "$tip" ]]; then
      rows+=("$YELLOW"$'\x1f'"Unknown"$'\x1f'"$name"$'\x1f'"${built:0:7}"$'\x1f'"could not read $branch of $url")
    elif [[ -z "$built" ]]; then
      rows+=("$RED"$'\x1f'"Not built"$'\x1f'"$name"$'\x1f'"-"$'\x1f'"$branch is at ${tip:0:7}")
      BEHIND_TOOLS+=("$tool")
      ((behind++)) || true
    elif [[ "$built" == "$tip" ]]; then
      rows+=("$GREEN"$'\x1f'"Latest"$'\x1f'"$name"$'\x1f'"${built:0:7}"$'\x1f'"${DIM}the tip of $branch$RESET$note")
    else
      rows+=("$YELLOW"$'\x1f'"Behind"$'\x1f'"$name"$'\x1f'"${built:0:7}"$'\x1f'"$branch is at ${tip:0:7}$note")
      BEHIND_TOOLS+=("$tool")
      ((behind++)) || true
    fi
  done < <(mise ls --current --json 2>/dev/null |
    jq -r 'to_entries[] | .key as $k | .value[]
           | select(($k | startswith("cargo:https://")) and (.version | startswith("branch:")))
           | "\($k)\t\(.install_path)\t\(.version | ltrimstr("branch:"))"' 2>/dev/null || true)

  if [[ ${#rows[@]} -eq 0 ]]; then
    say "$DIM" "Checked" "${DIM}no branch-built tools${names[*]:+ matching ${names[*]}}$RESET"
    return 0
  fi
  local width=0 row colour verb state
  for row in "${rows[@]}"; do
    IFS=$'\x1f' read -r colour verb name built state <<<"$row"
    ((${#name} > width)) && width=${#name}
  done
  for row in "${rows[@]}"; do
    IFS=$'\x1f' read -r colour verb name built state <<<"$row"
    say "$colour" "$verb" "$(printf '%-*s  %-7s  %s' "$width" "$name" "$built" "$state")"
  done
  [[ $behind -eq 0 || $update -eq 1 ]] ||
    detail "${DIM}bring them up to date with: mc --update   (or just some: up NAME...)$RESET"
}

# The tools to update, when it is not all of them: the ones the patterns match,
# or with --check --update the ones branch_status found behind.
tools=()
BEHIND_TOOLS=()

if [[ $check -eq 1 ]]; then
  branch_status
  [[ $update -eq 1 && ${#BEHIND_TOOLS[@]} -gt 0 ]] || exit 0
  tools=("${BEHIND_TOOLS[@]}")
fi

if [[ $branches -eq 1 ]]; then
  say "$CYAN" "Checking" "branch-built tools against GitHub"
  BRANCH_TOOLS_STALE=0
  refresh_branch_tools
  [[ $BRANCH_TOOLS_STALE -gt 0 ]] || say "$DIM" "Fresh" "${DIM}all at their branch's latest commit$RESET"
  quietly mise reshim || true
  check_mise_tools || exit 1
  exit 0
fi

if [[ $check -eq 0 && ${#names[@]} -gt 0 ]]; then
  all_tools=$(mise ls --current | awk '{print $1}' | sort -u)
  unmatched=()
  for name in "${names[@]}"; do
    grep -qiF -- "$name" <<<"$all_tools" || unmatched+=("$name")
  done
  # All the names are checked before any work starts: a typo in the third one
  # should not be found out after the first two have been rebuilt.
  if [[ ${#unmatched[@]} -gt 0 ]]; then
    err "no mise tools match: ${unmatched[*]}"
    exit 1
  fi
  mapfile -t tools < <(grep -iF -f <(printf '%s\n' "${names[@]}") <<<"$all_tools")
fi

if [[ ${#tools[@]} -gt 0 ]]; then
  say "$CYAN" "Upgrading" "${tools[*]}"
  refresh_branch_tools "${tools[@]}"
  mise_upgrade "${tools[@]}" || upgrade_ok=false
  sync_rustup_default
  quietly mise prune --yes "${tools[@]}" || warn "mise prune failed; continuing"

  if printf '%s\n' "${tools[@]}" | grep -q '^npm:'; then
    "$HOME/dotfiles/scripts/install/fix-mise-npm-installs.sh"
  fi
  check_mise_tools "${tools[@]}" || upgrade_ok=false

  report_disk_usage
  if ! $upgrade_ok; then
    err "mise upgrade failed for at least one tool, see above"
    exit 1
  fi
  exit 0
fi

# Update dotfiles first (best-effort — don't abort the mise update if this
# fails, e.g. offline, merge conflict, or detached HEAD). Run in a subshell so
# a failed `cd`/`git pull` can't strand us in the wrong directory.
# uq has just done this itself (it sets UQ_LOG_DIR); only a run on its own pulls.
if [[ -z "${UQ_LOG_DIR:-}" ]]; then
  say "$CYAN" "Updating" "dotfiles"
  if ! pull_dotfiles; then
    warn "dotfiles update failed; continuing with mise update"
  fi
fi

say "$CYAN" "Updating" "mise itself"
mise_was=$(mise --version 2>/dev/null | awk 'NR==1 {print $1}')
quietly mise self-update --yes || true
mise_now=$(mise --version 2>/dev/null | awk 'NR==1 {print $1}')
[[ "$mise_was" == "$mise_now" ]] || say "$GREEN" "Updated" "mise $mise_was → $mise_now"

say "$CYAN" "Checking" "branch-pinned tools for new commits"
refresh_branch_tools

say "$CYAN" "Checking" "mise tools for new versions"
# A tool that was added to the config since the last run (or that moved to
# another backend, which to mise is a new tool) is not an upgrade, so `mise
# upgrade` leaves it uninstalled.
install_missing() {
  local -a missing=()
  mapfile -t missing < <(mise ls --current --missing 2>/dev/null | awk '{print $1}')
  [ ${#missing[@]} -gt 0 ] || return 0
  say "$GREEN" "Installing" "$(printf '%s ' "${missing[@]##*[:/]}")${DIM}(new in the config)$RESET"
  quietly mise install --yes
}
install_missing || upgrade_ok=false

mise_upgrade || upgrade_ok=false
sync_rustup_default
# mise upgrade --bump  # Commented out to prevent auto-updating config.toml versions

# `mise upgrade` installs new versions alongside the old ones and never removes
# them, so installs/ grows without bound. Prune every version no tracked config
# still resolves to (mise reinstalls on demand if a project needs one again).
say "$CYAN" "Pruning" "unused tool versions"
quietly mise prune --yes || warn "mise prune failed; continuing"

# Self-heal npm: tools whose aube store under ~/.cache was cleared.
"$HOME/dotfiles/scripts/install/fix-mise-npm-installs.sh"

# Last, so that it sees what the upgrade, the prune and the npm repair left.
check_mise_tools || upgrade_ok=false

report_disk_usage

if ! $upgrade_ok; then
  err "mise upgrade failed for at least one tool, see above"
  exit 1
fi

exit 0
}
