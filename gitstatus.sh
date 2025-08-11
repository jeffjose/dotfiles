#!/bin/bash
# -*- coding: utf-8 -*-
# gitstatus.sh -- produce the current git repo status on STDOUT
# Functionally equivalent to 'gitstatus.py', but written in bash (not python).
#
# Alan K. Stebbens <aks@stebbens.org> [http://github.com/aks]

if [ -z "${__GIT_PROMPT_DIR}" ]; then
  SOURCE="${BASH_SOURCE[0]}"
  while [ -h "${SOURCE}" ]; do
    DIR="$(cd -P "$(dirname "${SOURCE}")" && pwd)"
    SOURCE="$(readlink "${SOURCE}")"
    [[ $SOURCE != /* ]] && SOURCE="${DIR}/${SOURCE}"
  done
  __GIT_PROMPT_DIR="$(cd -P "$(dirname "${SOURCE}")" && pwd)"
fi

# Early exit for non-git directories
if [ ! -d .git ] && [ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" != "true" ]; then
  exit 0
fi

gitstatus=$(LC_ALL=C git status --untracked-files=${__GIT_PROMPT_SHOW_UNTRACKED_FILES:-all} --porcelain --branch)

# if the status is fatal, exit now
[[ "$?" -ne 0 ]] && exit 0

num_staged=0
num_changed=0
num_conflicts=0
num_untracked=0
while IFS='' read -r line || [[ -n "$line" ]]; do
  status=${line:0:2}
  while [[ -n $status ]]; do
    case "$status" in
    #two fixed character matches, loop finished
    \#\#)
      branch_line="${line/\.\.\./^}"
      break
      ;;
    \?\?)
      ((num_untracked++))
      break
      ;;
    U?)
      ((num_conflicts++))
      break
      ;;
    ?U)
      ((num_conflicts++))
      break
      ;;
    DD)
      ((num_conflicts++))
      break
      ;;
    AA)
      ((num_conflicts++))
      break
      ;;
    #two character matches, first loop
    ?M) ((num_changed++)) ;;
    ?D) ((num_changed++)) ;;
    ?\ ) ;;
    #single character matches, second loop
    U) ((num_conflicts++)) ;;
    \ ) ;;
    *) ((num_staged++)) ;;
    esac
    status=${status:0:(${#status} - 1)}
  done
done <<<"$gitstatus"

num_stashed=0
if [[ "$__GIT_PROMPT_IGNORE_STASH" != "1" ]]; then
  stash_file="$(git rev-parse --git-dir 2>/dev/null)/logs/refs/stash"
  if [[ -e "${stash_file}" ]]; then
    num_stashed=$(wc -l < "${stash_file}" 2>/dev/null || echo 0)
  fi
fi

clean=0
if ((num_changed == 0 && num_staged == 0 && num_untracked == 0 && num_stashed == 0 && num_conflicts == 0)); then
  clean=1
fi

IFS="^" read -ra branch_fields <<<"${branch_line/\#\# /}"
branch="${branch_fields[0]}"
remote=
upstream=

if [[ "$branch" == *"Initial commit on"* ]]; then
  IFS=" " read -ra fields <<<"$branch"
  branch="${fields[3]}"
  remote="_NO_REMOTE_TRACKING_"
elif [[ "$branch" == *"No commits yet on"* ]]; then
  IFS=" " read -ra fields <<<"$branch"
  branch="${fields[4]}"
  remote="_NO_REMOTE_TRACKING_"
elif [[ "$branch" == *"no branch"* ]]; then
  tag=$(git describe --tags --exact-match)
  if [[ -n "$tag" ]]; then
    branch="$tag"
  else
    branch="_PREHASH_$(git rev-parse --short HEAD)"
  fi
else
  if [[ "${#branch_fields[@]}" -eq 1 ]]; then
    remote="_NO_REMOTE_TRACKING_"
  else
    IFS="[,]" read -ra remote_fields <<<"${branch_fields[1]}"
    upstream="${remote_fields[0]}"
    for remote_field in "${remote_fields[@]}"; do
      if [[ "$remote_field" == "ahead "* ]]; then
        num_ahead=${remote_field:6}
        ahead="(ahead.${num_ahead}"
      fi
      if [[ "$remote_field" == "behind "* ]] || [[ "$remote_field" == " behind "* ]]; then
        num_behind=${remote_field:7}
        behind=" (behind.${num_behind# })"
      fi
    done
    remote="${behind}${ahead}"
  fi
fi

if [[ -z "$remote" ]]; then
  remote='.'
fi

if [[ -z "$upstream" ]]; then
  upstream='^'
fi

# jeffjose - optimized timeago without external command
if git log -1 --format=%ct &>/dev/null; then
  timeago_seconds=$(($(date +%s) - $(git log -1 --format=%ct 2>/dev/null || echo 0)))
  if [ $timeago_seconds -lt 60 ]; then
    timeago_str="${timeago_seconds}s"
  elif [ $timeago_seconds -lt 3600 ]; then
    timeago_str="$((timeago_seconds / 60))m"
  elif [ $timeago_seconds -lt 86400 ]; then
    timeago_str="$((timeago_seconds / 3600))h"
  elif [ $timeago_seconds -lt 604800 ]; then
    timeago_str="$((timeago_seconds / 86400))d"
  elif [ $timeago_seconds -lt 2592000 ]; then
    timeago_str="$((timeago_seconds / 604800))w"
  elif [ $timeago_seconds -lt 31536000 ]; then
    timeago_str="$((timeago_seconds / 2592000))mo"
  else
    timeago_str="$((timeago_seconds / 31536000))y"
  fi
else
  timeago_str=""
fi

# jeffjose | describe
#describe_str="$(git describe --tags --always)"

printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n" \
  "$branch" \
  "$remote" \
  "$upstream" \
  $num_staged \
  $num_conflicts \
  $num_changed \
  $num_untracked \
  $num_stashed \
  $clean \
  "$timeago_str"
exit
