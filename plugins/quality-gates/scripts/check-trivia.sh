#!/usr/bin/env bash
# Trivia escape detector. (qg-cost-reduction plan §E + T2-1 expansion)
#
#   exit 0 + stdout "trivia: <kind>"  → skip pipeline
#   exit 1                            → not trivia (run pipeline)
#
# kinds: whitespace | rename | comment | typo | untracked-newfile

set -euo pipefail

paths=()
if [[ $# -gt 0 && "$1" == "--paths" ]]; then
  shift
  paths=("$@")
fi

gd() {
  if [[ ${#paths[@]} -gt 0 ]]; then
    git diff HEAD "$@" -- "${paths[@]}"
  else
    git diff HEAD "$@"
  fi
}

tracked_count="$(gd --name-only | wc -l | tr -d ' ')"
untracked_files=()
if [[ ${#paths[@]} -eq 0 ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && untracked_files+=("$f")
  done < <(git ls-files --others --exclude-standard 2>/dev/null || true)
fi

# === Untracked single-file detector (AC3) ===
if [[ "$tracked_count" -eq 0 && "${#untracked_files[@]}" -eq 1 ]]; then
  f="${untracked_files[0]}"
  line_count=$(wc -l < "$f" | tr -d ' ')
  if [[ "$line_count" -le 3 ]]; then
    eligible=true
    while IFS= read -r line; do
      if [[ -z "$line" ]]; then
        continue
      elif [[ "$line" =~ ^[[:space:]]*(#|//|--|/\*) ]]; then
        continue
      elif [[ "$line" =~ ^#! ]]; then
        continue
      else
        eligible=false
        break
      fi
    done < "$f"
    if $eligible; then
      echo "trivia: untracked-newfile"
      exit 0
    fi
  fi
fi

if [[ "$tracked_count" -ne 1 ]]; then
  exit 1
fi

line_count="$(gd --shortstat 2>/dev/null \
  | grep -oE '[0-9]+ (insertion|deletion)' \
  | awk '{s+=$1} END {print s+0}')"

# Whitespace-only (kept)
if [[ -z "$(gd -w)" ]]; then
  echo "trivia: whitespace"
  exit 0
fi

# Rename-only (kept)
renames="$(gd --diff-filter=R --name-only | wc -l | tr -d ' ')"
content_changes="$(gd --name-only --diff-filter=ACMD | wc -l | tr -d ' ')"
if [[ "$renames" -ge 1 && "$content_changes" -eq 0 ]]; then
  echo "trivia: rename"
  exit 0
fi

# Comment-only (T2-1 new)
if [[ "$line_count" -le 3 ]]; then
  changed="$(gd --unified=0 | grep -E '^[+-]' | grep -vE '^(---|\+\+\+)')"
  if [[ -n "$changed" ]]; then
    non_comment="$(echo "$changed" | grep -vE '^[+-][[:space:]]*($|#|//|--|/\*|\*)' || true)"
    if [[ -z "$non_comment" ]]; then
      echo "trivia: comment"
      exit 0
    fi
  fi
fi

# Typo (T2-1 new): exactly 1 changed line, 1 differing token, length-diff ≤ 2
if [[ "$line_count" -eq 2 ]]; then
  added="$(gd --unified=0 | grep -E '^\+' | grep -v '^+++' | sed 's/^+//')"
  removed="$(gd --unified=0 | grep -E '^-' | grep -v '^---' | sed 's/^-//')"
  added_lines=$(echo "$added" | wc -l | tr -d ' ')
  removed_lines=$(echo "$removed" | wc -l | tr -d ' ')
  if [[ "$added_lines" -eq 1 && "$removed_lines" -eq 1 ]]; then
    a_toks=$(echo "$added"   | tr ' ,.;()[]{}=' '\n' | grep -v '^$' || true)
    r_toks=$(echo "$removed" | tr ' ,.;()[]{}=' '\n' | grep -v '^$' || true)
    diff_out="$(diff <(echo "$a_toks") <(echo "$r_toks") || true)"
    added_tok=$(echo "$diff_out" | grep '^<' | sed 's/^< //' | head -1)
    removed_tok=$(echo "$diff_out" | grep '^>' | sed 's/^> //' | head -1)
    extra_a=$(echo "$diff_out" | grep -c '^<' || true)
    extra_r=$(echo "$diff_out" | grep -c '^>' || true)
    if [[ "$extra_a" -eq 1 && "$extra_r" -eq 1 ]]; then
      len_a=${#added_tok}; len_r=${#removed_tok}
      delta=$(( len_a - len_r ))
      delta=${delta#-}
      if [[ "$delta" -le 2 && "$added_tok" != "$removed_tok" ]]; then
        echo "trivia: typo"
        exit 0
      fi
    fi
  fi
fi

exit 1
