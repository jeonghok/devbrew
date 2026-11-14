#!/usr/bin/env bash
# intent-critic 단계 배선 — SKILL 자리 · 절차 문서 · 상태 형식 · kill switch 공시(AC3 · AC14 · AC17),
# 판정 불변(AC4 · AC15)과 답 커밋 범위(AC10). 판정 불변과 커밋 범위는 임시 리포에서 단계를 끝까지 돌려 잰다.
# 변이 넷(양성 대조)이 같은 검사를 RED 로 만들고, 바꾸지 않은 사본은 GREEN 이다.
set -u
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"

S="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
PROC="$PLUGIN_ROOT/skills/quality-pipeline/references/intent-critic.md"
SFF="$PLUGIN_ROOT/skills/quality-pipeline/references/state-file-format.md"
RM="$PLUGIN_ROOT/README.md"
SCRIPTS="$PLUGIN_ROOT/scripts"
KILL=DEVBREW_QUALITY_GATES_DISABLE_INTENT_CRITIC
ANS_DIR=docs/qg-intent-answers
SID=sess-intent-0001
LEAD="intent-critic 은 의도대로 만들었는지가 아니라 의도 자체(사용자가 고른 방향 · 기능 · 동작)가 맞는지를 점검한다. 이 절은 판정에 들지 않는다."
SENT_PUBLISH="Then run [Publish](#publish), then the intent-critic stage ([\`references/intent-critic.md\`](references/intent-critic.md)) — the intent-critic result line (or its skip notice) is the run's last script output, followed by the return block. The session folder stays for the TTL GC."
SENT_NEXT="After the intent-critic result line and the return block, end with the user's next action — one by default; if there are several, or they can run together (in parallel), say so and list them together"
PUB_NEXT="그다음 intent-critic 단계를 돈다 — 판정 밖이라 판정 줄 · 게시 본문에 들지 않는다."
P2_CLEAN="( cd \"\$RD\" && find . ! -name . -prune -type f -name 'intent-*' -exec rm -f {} + )"
KILL_BULLET='- `DEVBREW_QUALITY_GATES_DISABLE_INTENT_CRITIC=1` — intent-critic 단계만 끈다(「intent-critic 꺼짐(kill switch)」 한 줄). 판정 밖 단계라 판정에 닿지 않는다. 집행은 `scripts/intent_critic.py gate` 다.'
ALREADY="intent-critic — 이 실행은 이미 intent-critic 단계를 돌았다"
# 옛 이름은 이 파일에 이어 쓰지 않는다 — 이 파일도 아래 부재 검사의 대상이다.
OLD="쓴""소리"

section() { awk -v h="$2" '$0==h{f=1;next} f&&/^## /{exit} f' "$1"; }   # section <파일> <## 머리 줄>
flat() { tr '\n' ' ' | tr -s ' '; }
count() { printf '%s' "$1" | grep -o -F -- "$2" | wc -l | tr -d ' '; }   # count <글> <글자> — 나온 횟수
fenced() { awk '/^[[:space:]]*```/{f=!f; next} f' "$1"; }              # fenced <파일> — 펜스 안 줄만

note "[SKILL 자리]"
SF="$(flat < "$S")"
FV="$(section "$S" '## Final verdict' | flat)"
assert_eq "$(count "$FV" "$SENT_PUBLISH")" 1 "Final verdict: 게시 다음 intent-critic 단계 문장이 한 번"
assert_eq "$(count "$FV" "$SENT_NEXT")" 1 "Final verdict: 완료 보고 끝 할 일 문장이 한 번"
assert_eq "$(count "$SF" "the publish result line is the run's last script output.")" 0 "옛 문장(게시 결과 줄이 마지막 스크립트 출력) 0"
assert_eq "$(count "$SF" "After the publish result line,")" 0 "옛 문장(게시 결과 줄 뒤 할 일) 0"
PUB="$(section "$S" '## Publish')"
end_ln="$(printf '%s\n' "$PUB" | grep -n -F -x '<!-- publish-fence:end -->' | head -n 1 | cut -d: -f1)"
next_ln="$(printf '%s\n' "$PUB" | grep -n -F -x -- "$PUB_NEXT" | head -n 1 | cut -d: -f1)"
if [ -n "$end_ln" ] && [ -n "$next_ln" ] && [ "$next_ln" -gt "$end_ln" ]; then
  ok "## Publish: 게시 펜스 끝 뒤에 「그다음 intent-critic 단계를 돈다」 줄"
else
  no "## Publish: 게시 펜스 끝(${end_ln:-없음}) 뒤에 intent-critic 진입 줄(${next_ln:-없음})이 없다"
fi
KS="$(section "$S" '## kill switch')"
assert_eq "$(printf '%s\n' "$KS" | grep -c -F -x -- "$KILL_BULLET")" 1 "## kill switch: intent-critic bullet 한 줄"
assert_eq "$(count "$KS" "$KILL")" 1 "## kill switch: ${KILL} 가 한 번"
assert_grep "$(section "$S" '## Requirement index')" '^\| I1 intent-critic 은 판정 밖 — `findings\.yaml` · `qg-verdict-args:` · 게시 본문에 들지 않는다 · 답 커밋은 답 파일만 \|' "Requirement index: I1 intent-critic 은 판정 밖"
P2F="$(awk '/^\*\*P2 — setup\.\*\*/{p=1} p&&/^```bash$/{f=1;next} f&&/^```$/{exit} f' "$S")"
P2_LINE="$(printf '%s\n' "$P2F" | grep -F -- "-name 'intent-*'")"
assert_eq "$P2_LINE" "$P2_CLEAN" "P2 펜스: intent-* 정리 줄"
assert_file_grep "$S" '^argument-hint: ".*\[--origin <경로>\]"$' "argument-hint 끝에 --origin"
assert_contains "$SF" '`--origin <경로>` 는 부른 쪽이 넘기는 원문 파일(리포 안 추적 파일)이고 범위 인자가 아니다 — `--paths` 의 glob 으로 읽지 않는다.' "Arguments: --origin 은 범위 인자가 아니다"
assert_file_grep "$S" '^ ├ Publish ── ' "Flow: Publish 는 마지막 가지가 아니다"
assert_file_grep "$S" '^ └ intent-critic ── 판정 밖 질문 · 판정 · 게시 뒤 · 답 파일만 커밋 \(references/intent-critic\.md · 범위 모드는 묻지 않음\)$' "Flow: intent-critic 이 마지막 가지"
assert_contains "$SF" 'intent-critic 답 커밋은 `scripts/intent_critic.py record` 하나가 한다 — 답 파일만 경로 지정으로, push 없이.' "Rules: 답 커밋은 record 하나"

note "[절차 문서]"
PF="$(cat "$PROC")"
assert_eq "$(count "$PF" 'qg-verdict-args')" 0 "절차 문서: qg-verdict-args 0"
assert_eq "$(count "$PF" 'findings.yaml')" 0 "절차 문서: findings.yaml 0"
assert_eq "$(printf '%s\n' "$PF" | grep -c -E '(>|tee[[:space:]]+(-a[[:space:]]+)?)[[:space:]]*"?[^[:space:]"]*/comment')" 0 "절차 문서: comment* 파일에 쓰는 줄 0"
assert_eq "$(fenced "$PROC" | grep -c -E '^[[:space:]]*git[[:space:]]')" 0 "절차 문서: git 으로 시작하는 펜스 줄 0 — 커밋은 record 만"
assert_eq "$(count "$PF" 'subagent_type: "quality-gates:intent-critic"')" 2 "절차 문서: dispatch 2"
assert_eq "$(count "$PF" '// **처분** — consumer=plugins/quality-gates/scripts/intent_critic.py · fail-open')" 2 "절차 문서: 처분 줄 2"
assert_eq "$(count "$PF" '<roadmap>${ROADMAP}</roadmap>')" 2 "절차 문서: roadmap 칸 2"

note "[상태 형식]"
FMT="$(awk '/^```markdown$/{f=1;next} f&&/^```$/{exit} f' "$SFF")"
g_ln="$(printf '%s\n' "$FMT" | grep -n -x '## 게시' | cut -d: -f1)"
i_ln="$(printf '%s\n' "$FMT" | grep -n -x '## intent-critic' | cut -d: -f1)"
if [ -n "$g_ln" ] && [ -n "$i_ln" ] && [ "$i_ln" -gt "$g_ln" ]; then ok "형식: ## intent-critic 은 ## 게시 뒤"
else no "형식: ## intent-critic(${i_ln:-없음}) 이 ## 게시(${g_ln:-없음}) 뒤에 없다"; fi
SFFF="$(flat < "$SFF")"
assert_contains "$SFFF" "$LEAD" "형식: 절의 첫 줄(뜻 문장)"
assert_contains "$SFFF" '이 범위가 더한 답 파일' "형식: 거른 질문 목록의 범위 표시"
assert_contains "$SFFF" '그 뒤 intent-critic 단계가 끝에 `## intent-critic` 을 덧붙인다(하나뿐 — 이미 있으면 덧붙이지 않는다)' "생명주기 2: intent-critic 절"
assert_contains "$SFFF" '답 파일은 세션 폴더가 아니라 docs 답 자리에 산다' "다른 파일: 답 파일의 자리"
assert_contains "$SFFF" '`intent-*`' "다른 파일: intent-* 실행 파일"

note "[kill switch 공시]"
RKS="$(awk '/^### Kill switches/{f=1;next} f&&/^#{1,3} /{exit} f' "$RM")"
n="$(printf '%s\n' "$RKS" | grep -c -F -- "$KILL")"
if [ "${n:-0}" -ge 1 ]; then ok "README kill switch 표에 ${KILL} (${n})"
else no "README kill switch 표에 ${KILL} 가 없다"; fi

note "[옛 이름 부재]"
for f in "$S" "$PROC" "$SFF" "$RM" "$SCRIPTS/setup-qg.sh" "$PLUGIN_ROOT/agents/intent-critic.md" \
         "$PLUGIN_ROOT/tests/test_plain_qg_templates.sh" "$PLUGIN_ROOT/tests/test_setup_qg.sh" "$0"; do
  assert_file_absent "$f" "$OLD" "옛 이름 없음: ${f##*/}"
done

# ---------------------------------------------------------------- 판정 불변 · 답 커밋 범위
TMP="$(mktemp -d)"
[ -n "${TMP}" ] && [ -d "${TMP}" ] || { echo "mktemp -d 실패"; exit 1; }
trap 'rm -rf "${TMP}"' EXIT

ic_run() {   # ic_run <intent_critic.py> <하위 명령 …> — 이 단계의 환경 변수를 비운 채 돈다
  ( unset "$KILL" DEVBREW_QUALITY_GATES_INTENT_ANSWERS_DIR DEVBREW_QUALITY_GATES_INTENT_CRITIC_MAX_BYTES
    PYTHONDONTWRITEBYTECODE=1 python3 "$@" )
}

mkrepo() {   # mkrepo <폴더> — 첫 커밋 위 브랜치 + 무관한 스테이지 변경 하나 + 추적 안 된 파일 하나
  mkdir -p "$1" && git -C "$1" init -q -b main && git -C "$1" config user.name t \
    && git -C "$1" config user.email t@example.com && git -C "$1" config commit.gpgsign false || return 1
  printf 'x\n' > "$1/a.txt"; printf 'y\n' > "$1/b.txt"
  git -C "$1" add a.txt b.txt && git -C "$1" commit -q -m init || return 1
  printf 'user change\n' > "$1/b.txt"; git -C "$1" add b.txt
  printf 'stray\n' > "$1/stray.txt"
}

mkrd() {   # mkrd <세션 폴더> — 판정 · 게시가 끝난 세션 폴더
  mkdir -p "$1" || return 1
  printf 'verdict: defect\nreason: differential\nqg: defect · 지적 0 · 차등 새 실패 1\n' > "$1/verdict.out"
  printf -- '---\nsession_id: "%s"\nstarted_at: "2026-11-14T00:00:00Z"\n---\n\n# qg result\n\n## 판정\n\nverdict: defect\nqg: defect · 지적 0 · 차등 새 실패 1\n\n## 차등 테스트\n\nattribution_status: ok\n\n## 게시\n\nposted: https://example.invalid/pull/1#issuecomment-1\n' "$SID" > "$1/result.md"
  printf '## 저장 버튼을 고친다\n저장이 된다.\n' > "$1/comment-head.md"
  { cat "$1/comment-head.md"; printf '\n---\nqg: defect · 지적 0 · 차등 새 실패 1\n'; } > "$1/comment.md"
  printf 'findings:\n  - id: F1\n    severity: BLOCKING\n    file: a.txt\n    line: 1\n' > "$1/findings.yaml"
  printf '걷기 1 — 저장 버튼을 눌렀더니 저장되지 않았다\n' > "$1/e2e-record.md"
  printf 'per_adapter:\n  - runner: pytest\n    attributions:\n      - unit: t::a\n        verdict: NEW_REGRESSION\n        note: ""\n' > "$1/differential.yaml"
  printf '## Goals\n저장한다\n' > "$1/intent.md"
  printf '{}\n' > "$1/intent-specs.json"
}

reviewer_out() {   # reviewer_out <파일> — 근거 줄 1 을 인용한 질문 하나
  cat > "$1" <<'EOF'
살펴본 결과다.
```qg-intent-critic
questions:
- target_source: diff
  target_id: a.txt
  kind: 기본값
  weight: 동작
  quote: 고른 구절
  label: 고른 라벨
  question: a.txt 의 기본값을 정말 이렇게 고른 것인가?
  evidence_lines:
  - 1
```
끝.
EOF
}

# run_stage <intent_critic.py> <kill|pr|range> <폴더> — 임시 리포 · 세션 폴더를 만들고 절차 순서대로 단계를 돈다.
# stdout 은 <폴더>/out.txt, 하위 명령마다의 rc 는 <폴더>/rc.txt 에 모인다.
run_stage() {
  local ic="$1" mode="$2" d="$3" repo rd m f
  repo="$d/repo"; rd="$repo/.claude/quality-gates/$SID"
  mkrepo "$repo" && mkrd "$rd" || { echo "fixture 실패" >> "$d/out.txt"; return 1; }
  mkdir -p "$d/before"
  for f in verdict.out comment-head.md comment.md findings.yaml result.md; do cp "$rd/$f" "$d/before/$f"; done
  git -C "$repo" rev-parse HEAD > "$d/head-before"
  : > "$d/out.txt"; : > "$d/rc.txt"
  if [ "$mode" = kill ]; then
    ( export "$KILL=1"; PYTHONDONTWRITEBYTECODE=1 python3 "$ic" gate --rd "$rd" --path final --mode pr ) >> "$d/out.txt" 2>> "$d/err.txt"
    echo "$?" >> "$d/rc.txt"
    return 0
  fi
  m=pr; [ "$mode" = range ] && m=range
  step() { ic_run "$ic" "$@" >> "$d/out.txt" 2>> "$d/err.txt"; echo "$?" >> "$d/rc.txt"; }
  step gate --rd "$rd" --path final --mode "$m"
  step config --rd "$rd" --repo "$repo" --base HEAD --project-dir "$repo"
  step prepare --rd "$rd" --repo "$repo" --tree-root "$repo" --mode "$m" --head HEAD \
    --review-commit HEAD --specs-json "$rd/intent-specs.json"
  reviewer_out "$rd/intent-critic-1.txt"
  step check-output "$rd/intent-critic-1.txt"
  step filter --rd "$rd"
  if [ "$m" = pr ]; then
    printf '=== id: diff#a.txt#기본값 · pick: 의도다\n' > "$rd/intent-answers.txt"
    step record --rd "$rd" --repo "$repo" --answers "$rd/intent-answers.txt"
  fi
  step render --rd "$rd" --mode "$m"
}

# check_stage <kill|pr|range> <폴더> — 판정 불변 · 답 커밋 범위를 잰다. 줄마다 「PASS <이름>」 또는 「FAIL <이름>」.
check_stage() {
  local mode="$1" d="$2" repo rd f last cnt files staged
  repo="$d/repo"; rd="$repo/.claude/quality-gates/$SID"
  r() { if [ "$2" = 0 ]; then echo "PASS $1"; else echo "FAIL $1"; fi; }
  for f in verdict.out comment-head.md comment.md findings.yaml; do
    cmp -s "$d/before/$f" "$rd/$f"; r "same:$f" "$?"
  done
  python3 -I - "$d/before/result.md" "$rd/result.md" "$mode" "$LEAD" <<'PY'
import sys
before = open(sys.argv[1], encoding="utf-8").read()
after = open(sys.argv[2], encoding="utf-8").read()
mode, lead = sys.argv[3], sys.argv[4]
print(("PASS" if after.startswith(before) else "FAIL") + " result-prefix")
lines = after.split("\n")
heads = [i for i, line in enumerate(lines) if line == "## intent-critic"]
posts = [i for i, line in enumerate(lines) if line == "## 게시"]
rest = after[len(before):].lstrip("\n")
if mode == "kill":
    print(("PASS" if not heads else "FAIL") + " section-absent")
else:
    placed = len(heads) == 1 and len(posts) == 1 and heads[0] > posts[0] and rest.startswith("## intent-critic\n")
    print(("PASS" if placed else "FAIL") + " section-after-publish")
    first = [line for line in lines[heads[0] + 1:] if line.strip()][:1] if heads else []
    print(("PASS" if first == [lead] else "FAIL") + " section-lead")
PY
  grep -q '^qg-verdict-args:' "$d/out.txt"; [ "$?" = 1 ]; r no-verdict-args "$?"
  [ -s "$d/rc.txt" ] && ! grep -qv '^0$' "$d/rc.txt"; r rc-zero "$?"
  staged="$(git -C "$repo" diff --cached --name-only)"
  [ "$staged" = b.txt ]; r stage-kept "$?"
  [ "$(git -C "$repo" status --porcelain -- stray.txt)" = '?? stray.txt' ]; r untracked-kept "$?"
  last="$(tail -n 1 "$d/out.txt")"
  case "$mode" in
    pr)
      cnt="$(git -C "$repo" rev-list --count "$(cat "$d/head-before")..HEAD")"
      files="$(git -C "$repo" show --name-only --format= HEAD)"
      [ "$cnt" = 1 ] && [ "$(printf '%s\n' "$files" | grep -c .)" = 1 ] \
        && [ "$(printf '%s\n' "$files" | grep -c "^${ANS_DIR}/[^/]*\.md$")" = 1 ]; r commit-scope "$?"
      grep -q '^답 파일 1개를 커밋했다(' "$d/out.txt"; r commit-line "$?"
      [ "$last" = "intent-critic — 질문 1개를 물었다 · 답 1개(잘못 골랐다 0개)" ]; r result-line "$?"
      ;;
    range|kill)
      [ "$(git -C "$repo" rev-parse HEAD)" = "$(cat "$d/head-before")" ]; r no-commit "$?"
      [ ! -e "$repo/$ANS_DIR" ]; r no-answer-files "$?"
      if [ "$mode" = range ]; then
        [ "$last" = "intent-critic — 질문 1개 아직 묻지 않음(범위 모드)" ]; r result-line "$?"
      else
        [ "$(cat "$d/out.txt")" = "intent-critic 꺼짐(kill switch)" ]; r kill-line "$?"
        grep -q -F 'intent-critic 꺼짐(kill switch)' "$rd/intent-return.md" 2>/dev/null; r kill-return "$?"
      fi
      ;;
  esac
}

expect_checks() { echo 14; }   # 모드마다 check_stage 가 내는 검사 수 — 줄면 검사가 조용히 빠진 것이다

note "[판정 불변 · 답 커밋 범위 — 실제 스크립트]"
for mode in kill pr range; do
  d="$TMP/real-$mode"; mkdir -p "$d"
  run_stage "$SCRIPTS/intent_critic.py" "$mode" "$d"
  res="$(check_stage "$mode" "$d")"
  assert_eq "$(printf '%s\n' "$res" | grep -c '^\(PASS\|FAIL\) ')" "$(expect_checks "$mode")" "${mode}: 검사 수"
  while read -r st name; do
    [ -n "$st" ] || continue
    if [ "$st" = PASS ]; then ok "${mode}: ${name}"; else no "${mode}: ${name}"; fi
  done <<EOF
$res
EOF
done
[ -s "$TMP/real-pr/err.txt" ] && { echo "--- pr stderr"; cat "$TMP/real-pr/err.txt"; }

note "[다시 돌기 — P2 정리 뒤에는 다시 렌더한다]"
RD="$TMP/real-pr/repo/.claude/quality-gates/$SID"
again="$(ic_run "$SCRIPTS/intent_critic.py" render --rd "$RD" --mode pr | tail -n 1)"
assert_eq "$again" "$ALREADY" "같은 세션 폴더에서 두 번째 render 는 덧붙이지 않는다"
[ -n "${RD}" ] && [ -d "${RD}" ] || { echo "세션 폴더 사본이 없다: ${RD}"; exit 1; }   # 빈 값이면 정리 줄이 cwd 를 지운다
eval "$P2_LINE"
assert_eq "$(cd "$RD" && find . ! -name . -prune -type f -name 'intent-*' | wc -l | tr -d ' ')" 0 "SKILL P2 정리 줄이 intent-* 를 지운다"
[ -f "$RD/verdict.out" ] && [ -f "$RD/result.md" ]; assert_eq "$?" 0 "SKILL P2 정리 줄은 intent-* 밖의 파일을 남긴다(양성 짝)"
cp "$TMP/real-pr/before/result.md" "$RD/result.md"   # 다음 실행의 setup 이 새로 만든 result.md 자리
again="$(ic_run "$SCRIPTS/intent_critic.py" render --rd "$RD" --mode pr | tail -n 1)"
assert_not_contains "$again" "$ALREADY" "정리 뒤 render 는 다시 렌더한다"
assert_eq "$(grep -c -x '## intent-critic' "$RD/result.md")" 1 "정리 뒤 render 가 절 하나를 덧붙인다"

note "[재구성 헬퍼 — intent-critic 포인터 한 줄만 남긴다]"
. "$PLUGIN_ROOT/tests/lib/reconstruct-skill.sh"
if rs="$(reconstruct_skill_md "$S" 2>/dev/null)"; then
  assert_eq "$(grep -c -x 'Read ${CLAUDE_PLUGIN_ROOT}/skills/quality-pipeline/references/intent-critic.md' "$rs")" 1 "재구성본에 intent-critic 포인터가 그대로 남는다"
  rm -f "$rs"
else
  no "재구성 헬퍼가 지금 SKILL.md 를 받지 않는다"
fi
RC_SK="$TMP/rc/skills/quality-pipeline"
mkdir -p "$RC_SK/references" "$TMP/rc/references"
cp "$PLUGIN_ROOT/skills/quality-pipeline/references/differential-test.md" "$RC_SK/references/"
cp "$PLUGIN_ROOT/references/e2e.md" "$TMP/rc/references/"
{ cat "$S"; printf '\n```\nRead ${CLAUDE_PLUGIN_ROOT}/skills/quality-pipeline/references/intent-critic-other.md\n```\n'; } > "$RC_SK/SKILL.md"
if rs="$(reconstruct_skill_md "$RC_SK/SKILL.md" 2>/dev/null)"; then no "다른 포인터가 남은 SKILL 사본을 재구성 헬퍼가 받았다"; rm -f "$rs"
else ok "다른 포인터가 남은 SKILL 사본은 재구성 헬퍼가 거부한다(예외는 한 줄뿐)"; fi

# ---------------------------------------------------------------- 변이(양성 대조)
mkcopy() { mkdir -p "$1" && cp -L "$SCRIPTS"/*.py "$1/"; }   # 형제 모듈까지 — 링크(adjudication.py 등)는 풀어서
mutate() {   # mutate <파일> <옛 글> <새 글> — 정확히 한 곳을 바꾼다. 못 바꾸면 rc 3
  python3 -I - "$@" <<'PY'
import sys
path, old, new = sys.argv[1:4]
with open(path, encoding="utf-8") as fh:
    text = fh.read()
if text.count(old) != 1:
    sys.exit(3)
with open(path, "w", encoding="utf-8") as fh:
    fh.write(text.replace(old, new))
PY
}
ANCHOR=$'    _write(marker, line + "\\n")\n    _emit(notices)\n    print(line)\n'

note "[변이 — 바꾸지 않은 사본은 GREEN]"
mkcopy "$TMP/copy-plain"
d="$TMP/mut-plain"; mkdir -p "$d"
run_stage "$TMP/copy-plain/intent_critic.py" pr "$d"
res="$(check_stage pr "$d")"
assert_eq "$(printf '%s\n' "$res" | grep -c '^PASS ')" "$(expect_checks pr)" "바꾸지 않은 사본: 검사 전부 PASS"

run_mutant() {   # run_mutant <이름> <과녁 검사> — 사본 폴더 $TMP/copy-<이름> 은 이미 변이됐다
  local d="$TMP/mut-$1" res
  mkdir -p "$d"
  run_stage "$TMP/copy-$1/intent_critic.py" pr "$d"
  res="$(check_stage pr "$d")"
  if printf '%s\n' "$res" | grep -q -x "FAIL $2"; then ok "변이 $1: ${2} 가 RED"
  else no "변이 $1: ${2} 가 RED 가 아니다 — $(printf '%s' "$res" | tr '\n' ' ')"; fi
}

note "[변이 — 넷 모두 RED]"
mkcopy "$TMP/copy-a"
mutate "$TMP/copy-a/intent_critic.py" "$ANCHOR" $'    _append(_path(rd, "findings.yaml"), "intent: leak\\n")\n'"$ANCHOR"
assert_eq "$?" 0 "변이 a(render 가 findings.yaml 에 덧붙인다)를 심었다"
run_mutant a same:findings.yaml
mkcopy "$TMP/copy-b"
mutate "$TMP/copy-b/intent_critic.py" "$ANCHOR" $'    print("qg-verdict-args: --blocking 1")\n'"$ANCHOR"
assert_eq "$?" 0 "변이 b(판정 인자 줄을 낸다)를 심었다"
run_mutant b no-verdict-args
mkcopy "$TMP/copy-c"
mutate "$TMP/copy-c/intent_critic.py" "$ANCHOR" $'    _append(_path(rd, "comment.md"), "intent leak\\n")\n'"$ANCHOR"
assert_eq "$?" 0 "변이 c(render 가 comment.md 에 덧붙인다)를 심었다"
run_mutant c same:comment.md
# 변이 d — 사본의 답 커밋을 경로 지정 없는 「git add -A」 · 「git commit -q -m …」 로 바꾼다. 작업 흐름이 아니라 변이 글이다.
mkcopy "$TMP/copy-d"
mutate "$TMP/copy-d/intent_answers.py" 'add = _git(repo_root, "add", "--", *paths)' 'add = _git(repo_root, "add", "-A")' \
  && mutate "$TMP/copy-d/intent_answers.py" 'commit = _git(repo_root, "commit", "--only", "-q", "-m", message, "--", *paths)' \
       'commit = _git(repo_root, "commit", "-q", "-m", message)'
assert_eq "$?" 0 "변이 d(답 커밋이 경로를 지정하지 않는다)를 심었다"
run_mutant d commit-scope

finish
