#!/usr/bin/env bash
# codex 를 부르는 러너 전부가 검토 트리의 AGENTS.md 를 지시로 불러오지 않게 하는 설정을
# 실제 호출에 싣고 있는지 잰다. 러너는 도출한다 — 새 러너가 생기면 자동으로 든다.
#
# 대상은 `codex exec -` 호출이 실제로 받는 인자 묶음이다. 호출 블록(그 줄부터 빈 줄 ·
# `||` 까지)을 읽고, 블록이 `"${이름[@]}"` 로 배열을 펼치면 그 배열의 첫 대입 내용을 그
# 자리에 넣은 뒤 센다. 그래서 인자를 인라인으로 쓰든 배열로 모으든 같은 락이 잰다.
set -u -o pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

FLAG="-c 'project_doc_max_bytes=0'"

# 호출 블록을 펼쳐 낸다. 인자: 파일. 출력: 줄마다 `<호출줄번호>\t<펼친 블록>`.
extract_blocks() {
  python3 -I - "$1" <<'PY'
import re, sys
path = sys.argv[1]
lines = open(path, encoding="utf-8").read().split("\n")
arrs = {}
for ln in lines:
    m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)=\((.*)\)\s*$", ln)
    if m and m.group(1) not in arrs:
        arrs[m.group(1)] = m.group(2)
for i, ln in enumerate(lines):
    if re.match(r"\s*#", ln) or not re.match(r"\s*codex exec -(\s|\\|$)", ln):
        continue
    blk = []
    for j in range(i, len(lines)):
        if j > i and lines[j].strip() == "":
            break
        blk.append(lines[j])
        if "||" in lines[j]:
            break
    text = " ".join(x.strip().rstrip("\\") for x in blk)
    text = re.sub(r'"\$\{([A-Za-z_][A-Za-z0-9_]*)\[@\]\}"',
                  lambda m: arrs.get(m.group(1), "<UNRESOLVED:%s>" % m.group(1)), text)
    print("%d\t%s" % (i + 1, text))
PY
}

count_flag() { printf '%s' "$1" | grep -o -F -- "$FLAG" | grep -c . ; }

derive_runners() {
  local f rp seen="" out=""
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    [ -L "$f" ] && continue   # 배포 링크는 정본이 대신 센다
    case "$f" in */tests/*|*/fixtures/*) continue ;; esac
    grep -qE '^[[:space:]]*codex exec -([[:space:]]|\\|$)' "$f" || continue
    rp="$(python3 -I -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$f")"
    case " $seen " in *" $rp "*) continue ;; esac
    seen="$seen $rp"
    out="$out$f
"
  done <<EOF_C
$(git ls-files -- 'plugins/*/scripts/*' 'shared/*/scripts/*' 'shared/codex/*' 2>/dev/null | sort)
EOF_C
  printf '%s' "$out"
}

RUNNERS="$(derive_runners)"
n_run=0
[ -n "$RUNNERS" ] && n_run="$(printf '%s\n' "$RUNNERS" | grep -c .)"
if [ "$n_run" -eq 0 ]; then
  no "도출: codex exec 러너가 0개 — 도출 기준이 깨졌다. 아래 검사는 공허하다"
  finish; exit
fi
ok "도출: 러너 ${n_run}개"

# 양성 대조: 알려진 넷이 모두 도출 목록에 든다.
for want in plugins/plugin-audit/scripts/run_audit_codex_reviewer.sh \
            plugins/quality-gates/scripts/run_artifact_codex_reviewer.sh \
            plugins/quality-gates/scripts/run_codex_reviewer.sh \
            shared/docreview/scripts/run_docreview_codex_reviewer.sh; do
  if printf '%s\n' "$RUNNERS" | grep -qxF -- "$want"; then
    ok "양성 대조: ${want##*/} 가 도출 목록에 있다"
  else
    no "양성 대조: $want 가 도출 목록에 없다"
  fi
done

while IFS= read -r f; do
  [ -n "$f" ] || continue
  blocks="$(extract_blocks "$f")"
  if [ -z "$blocks" ]; then no "${f##*/}: codex exec 호출 블록을 못 뽑았다"; continue; fi
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    n="$(count_flag "${b#*$'\t'}")"
    assert_eq "$n" "1" "${f##*/}:${b%%$'\t'*}: codex exec 호출 인자에 ${FLAG} 가 정확히 한 번"
  done <<EOF_B
$blocks
EOF_B
done <<EOF_R
$RUNNERS
EOF_R

# 판별력 대조: 플래그가 없는 블록 · 둘인 블록 · 배열로 펼쳐진 블록을 실제로 가른다.
T="$(mktemp -d)" || { no "임시 폴더 실패"; finish; exit; }
trap 'rm -rf "$T"' EXIT
printf 'codex exec - \\\n    -s read-only \\\n    --json \\\n    < in || rc=$?\n' > "$T/none.sh"
printf "codex exec - \\\\\n    -c 'project_doc_max_bytes=0' \\\\\n    -c 'project_doc_max_bytes=0' \\\\\n    --json || rc=\$?\n" > "$T/dup.sh"
printf "A=(-c 'project_doc_max_bytes=0')\ncodex exec - \\\\\n    \"\${A[@]}\" \\\\\n    --json || rc=\$?\n" > "$T/arr.sh"
assert_eq "$(count_flag "$(extract_blocks "$T/none.sh")")" "0" "음의 대조: 플래그 없는 호출은 0 으로 센다"
assert_eq "$(count_flag "$(extract_blocks "$T/dup.sh")")" "2" "음의 대조: 플래그가 둘인 호출은 2 로 센다"
assert_eq "$(count_flag "$(extract_blocks "$T/arr.sh")")" "1" "양의 대조: 배열로 펼쳐진 호출도 1 로 센다"
finish
