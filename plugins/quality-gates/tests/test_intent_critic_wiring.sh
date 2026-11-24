#!/usr/bin/env bash
# intent-critic 단계 배선 — SKILL 자리 · 절차 문서 · 상태 형식 · kill switch 공시(AC3 · AC14 · AC17),
# 판정 불변(AC4 · AC15)과 답 커밋 범위(AC10). 판정 불변과 커밋 범위는 임시 리포에서 단계를 끝까지 돌려 잰다.
# 실행 모드 여섯(kill · kill-global · pr · range · wide · prwide). 변이 일곱(양성 대조 — 넓게 보는 실행의 둘 · 전역 스위치의 하나 포함)이
# 같은 검사를 RED 로 만들고, 바꾸지 않은 사본은 GREEN 이다. 넓게 보는 실행(새 세션 파일 other-teams.md)의 판정 불변은 AC11 이다.
# gh 는 PATH 앞의 가짜이고 넓게 본 실행에서 불리지 않는다. kill 짝 실행은 스위치를 끈 채 그 실행만의 가짜 gh 를 부른다.
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
GLOBAL=DEVBREW_QUALITY_GATES_DISABLE
ANS_DIR=docs/qg-intent-answers
SID=sess-intent-0001
LEAD="intent-critic 은 의도대로 만들었는지가 아니라 의도 자체(사용자가 고른 방향 · 기능 · 동작)가 맞는지를 점검한다. 이 절은 판정에 들지 않는다."
SENT_PUBLISH="Then run [Publish](#publish), then the intent-critic stage ([\`references/intent-critic.md\`](references/intent-critic.md)) — the intent-critic result line (or its skip notice) is the run's last script output, followed by the return block. The session folder stays for the TTL GC."
SENT_NEXT="After the intent-critic result line and the return block, end with the user's next action — one by default; if there are several, or they can run together (in parallel), say so and list them together"
PUB_NEXT="그다음 intent-critic 단계를 돈다 — 판정 밖이라 판정 줄 · 게시 본문에 들지 않는다."
P2_CLEAN="( cd \"\$RD\" && find . ! -name . -prune -type f -name 'intent-*' -exec rm -f {} + )"
KILL_BULLET='- `DEVBREW_QUALITY_GATES_DISABLE_INTENT_CRITIC=1` — intent-critic 단계만 끈다(「intent-critic 꺼짐(kill switch)」 한 줄). 판정 밖 단계라 판정에 닿지 않는다. 집행은 `scripts/intent_critic.py gate` 이고, 준비 걸음(`prepare`)도 이 스위치를 스스로 읽어 다른 팀 읽기 · PR 조회가 함께 꺼진다.'
ALREADY="intent-critic — 이 실행은 이미 intent-critic 단계를 돌았다"
DESC_END="The run ends with the intent-critic stage (outside the verdict), which may ask about the user's own choices and commits the answers as answer files on the current branch (no push)."
LAW2_READERS='`security-reviewer` · `code-recritic` · `intent-critic` are read-only (`tools: Read, Grep, Glob`).'
LAW2_WRITES="you write to the repository in one place only: the intent-critic answer files with their commit (\`scripts/intent_critic.py record\`). The session state folder and the throwaway worktrees are not repository writes."
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
assert_grep "$(section "$S" '## Requirement index')" '^\| IC1 intent-critic 은 판정 밖 — `findings\.yaml` · `qg-verdict-args:` · 게시 본문에 들지 않는다 · 답 커밋은 답 파일만 \|' "Requirement index: IC1 intent-critic 은 판정 밖(절차 문서의 걸음 I1 과 번호가 겹치지 않는다)"
assert_not_grep "$(section "$S" '## Requirement index')" '^\| I1 ' "Requirement index: 옛 번호 I1 행이 없다(위 양성 짝)"
P2F="$(awk '/^\*\*P2 — setup\.\*\*/{p=1} p&&/^```bash$/{f=1;next} f&&/^```$/{exit} f' "$S")"
P2_LINE="$(printf '%s\n' "$P2F" | grep -F -- "-name 'intent-*'")"
assert_eq "$P2_LINE" "$P2_CLEAN" "P2 펜스: intent-* 정리 줄"
assert_file_grep "$S" '^argument-hint: ".*\[--origin <경로>\] \[--answered <경로>\]"$' "argument-hint 끝에 --origin 과 --answered"
assert_contains "$SF" '`--origin <경로>` 는 부른 쪽이 넘기는 원문 파일(리포 안 추적 파일)이고 범위 인자가 아니다 — `--paths` 의 glob 으로 읽지 않는다.' "Arguments: --origin 은 범위 인자가 아니다"
assert_contains "$SF" '`--answered <경로>` 는 부른 쪽(지휘자)이 넘기는 「이미 답한 것」 파일의 절대 경로이고 범위 인자가 아니다.' "Arguments: --answered 는 범위 인자가 아니다"
IR="$(fenced "$PROC")"
assert_contains "$IR" "<<'QG_INTENT_ANSWERED'" "I2 펜스: QG_INTENT_ANSWERED heredoc"
assert_contains "$IR" 'A_ARGS=(--answered "$ANSWERED_ARG")' "I2 펜스: A_ARGS 목록"
assert_contains "$IR" '"${A_ARGS[@]}"' "I2 펜스: prepare 줄 끝의 A_ARGS"
assert_file_grep "$S" '^ ├ Publish ── ' "Flow: Publish 는 마지막 가지가 아니다"
assert_file_grep "$S" '^ └ intent-critic ── 판정 밖 질문 · 판정 · 게시 뒤 · 답 파일만 커밋 \(references/intent-critic\.md · 범위 모드는 묻지 않음\)$' "Flow: intent-critic 이 마지막 가지"
assert_contains "$SF" 'intent-critic 답 커밋은 `scripts/intent_critic.py record` 하나가 한다 — 답 파일만 경로 지정으로, push 없이.' "Rules: 답 커밋은 record 하나"
# frontmatter description · Law 2 문단 — 실행의 끝(intent-critic 단계)과 쓰는 것(답 파일 · 답 커밋)을 옛 문장으로 말하지 않는다.
FM="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$S" | flat)"
assert_eq "$(count "$FM" "$DESC_END")" 1 "description: 실행은 intent-critic 단계로 끝난다"
assert_eq "$(count "$FM" "ends by posting one new PR comment")" 0 "description: 옛 문장(게시로 끝난다) 0"
assert_eq "$(count "$FM" "posts one new PR comment (understanding text + verdict line) through the publish sink.")" 1 "description: 게시 문장은 남는다(양성 짝)"
LAW2="$(awk '/^\*\*Law 2 \(Writer ≠ Reviewer\):\*\*/{f=1} f&&/^$/{exit} f' "$S" | flat)"
assert_eq "$(count "$LAW2" "$LAW2_READERS")" 1 "Law 2: 읽기 전용 리뷰어 셋(intent-critic 포함)"
assert_eq "$(count "$LAW2" "$LAW2_WRITES")" 1 "Law 2: 저장소에 쓰는 자리는 답 파일 · 답 커밋 하나다(세션 폴더 · 일회용 worktree 는 저장소 쓰기가 아니다)"
assert_eq "$(count "$LAW2" "the fixes the user approved at the Fix-loop gate")" 0 "Law 2: 고치기 반복의 고침을 쓰던 옛 문장 0(위 양성 짝)"
assert_eq "$(count "$LAW2" "you edit files only for the fixes the user approved at the Fix-loop gate.")" 0 "Law 2: 옛 문장(고침만 쓴다) 0"

note "[절차 문서]"
PF="$(cat "$PROC")"
assert_eq "$(count "$PF" '범위 모드에서도 바뀐 파일 가운데 의도 문서')" 1 "절차 문서: 범위 모드도 바뀐 의도 문서의 머리 줄을 따라간다(AC18)"
assert_eq "$(count "$PF" 'qg-verdict-args')" 0 "절차 문서: qg-verdict-args 0"
assert_eq "$(count "$PF" 'findings.yaml')" 0 "절차 문서: findings.yaml 0"
assert_eq "$(printf '%s\n' "$PF" | grep -c -E '(>|tee[[:space:]]+(-a[[:space:]]+)?)[[:space:]]*"?[^[:space:]"]*/comment')" 0 "절차 문서: comment* 파일에 쓰는 줄 0"
assert_eq "$(fenced "$PROC" | grep -c -E '^[[:space:]]*git[[:space:]]')" 0 "절차 문서: git 으로 시작하는 펜스 줄 0 — 커밋은 record 만"
assert_eq "$(count "$PF" 'subagent_type: "quality-gates:intent-critic"')" 2 "절차 문서: dispatch 2"
assert_eq "$(count "$PF" '// **처분** — consumer=plugins/quality-gates/scripts/intent_critic.py · fail-open')" 2 "절차 문서: 처분 줄 2"
assert_eq "$(count "$PF" '<roadmap>${ROADMAP}</roadmap>')" 2 "절차 문서: roadmap 칸 2"
assert_eq "$(count "$PF" '<scope>${SCOPE}</scope>')" 2 "절차 문서: scope 칸 2"
# gate 길 — prepare(I1 · I2)로 가는 것은 `intent-gate: run` 행 하나뿐이다. 스위치 하나가 넓게 보기와 다른 팀 읽기를 함께
# 끄는 것(AC12)은 이 길과 prepare 자신의 스위치 검사(아래 kill 실행)가 함께 지킨다.
GATE_RUN_ROW='| `intent-gate: run` | 아래 비용 줄을 내고 범위 모드면 [I1](#i1-리뷰-트리-범위-모드만), PR 범위면 [I2](#i2-설정--준비) |'
GATE_SKIP_ROW='| `intent-critic 꺼짐(kill switch)` · `intent-critic — 건너뜀(…)` | 그 줄이 마지막 스크립트 출력이다 — [I7](#i7-돌려주기) |'
assert_eq "$(printf '%s\n' "$PF" | grep -c -F -x -- "$GATE_RUN_ROW")" 1 "절차 문서: intent-gate: run 행이 I1 · I2 로 간다(한 번)"
assert_eq "$(printf '%s\n' "$PF" | grep -c -F -x -- "$GATE_SKIP_ROW")" 1 "절차 문서: 꺼짐 · 건너뜀 행이 I7 로 간다(한 번)"
assert_eq "$(printf '%s\n' "$PF" | grep '^|' | grep -F -e '꺼짐(kill switch)' -e '건너뜀(' | grep -c -F -e '(#i1-' -e '(#i2-')" 0 "절차 문서: 꺼짐 · 건너뜀 행은 I1 · I2 로 가지 않는다"
# gate 가 내는 줄(`intent-gate:` · `intent-critic …`)로 시작하는 행 가운데 I1 · I2 로 가는 것은 하나. I1 의 출력 행(`intent-review-tree:`)은 run 뒤라 뺀다.
assert_eq "$(printf '%s\n' "$PF" | grep -e '^| `intent-gate' -e '^| `intent-critic' | grep -c -F -e '(#i1-' -e '(#i2-')" 1 "절차 문서: I1 · I2 로 가는 gate 출력 행은 하나뿐"

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

note "[새 세션 파일 — 세 곳]"
P2_RM="$(printf '%s\n' "$P2F" | grep -F -- 'rm -f "$RD/differential.yaml"')"
assert_contains "$P2_RM" '"$RD/other-teams.md"' "P2 펜스: other-teams.md 를 지운다"
assert_eq "$(grep -c -F -- "|other-teams\\.md'" "$SCRIPTS/review-diff.sh")" 1 "QG_NAMES: other-teams.md"
assert_contains "$(awk '/^같은 폴더의 다른 파일/{on=1} on{print} on&&/같은 생명주기를 따른다/{exit}' "$SFF")" '`other-teams.md`' "상태 문서: 다른 파일 목록에 other-teams.md"
assert_contains "$SFFF" '| 정체 | 상태 | 근거 | 답 | 답 파일 | 질문 |' "형식: 표 머리에 근거 칸"
assert_contains "$SFFF" '다른 팀과 겹치는 곳:' "형식: 겹침 목록"
assert_eq "$(count "$SF" 'gh 는 두 스크립트만')" 0 "Rules: 옛 gh 문장 0"
assert_contains "$SF" '열린 PR 목록 읽기는 `scripts/other_teams.py` 가 한다' "Rules: other_teams 의 gh"
assert_grep "$(section "$S" '## Requirement index')" '^\| gh 는 세 파일\(AC15.*\| .*`scripts/other_teams\.py`' "Requirement index: gh 행이 other_teams.py 를 든다"
assert_eq "$(count "$SF" 'gh 는 두 파일')" 0 "Requirement index: 옛 gh 행(두 파일) 0"

note "[kill switch 공시]"
RKS="$(awk '/^### Kill switches/{f=1;next} f&&/^#{1,3} /{exit} f' "$RM")"
n="$(printf '%s\n' "$RKS" | grep -c -F -- "$KILL")"
if [ "${n:-0}" -ge 1 ]; then ok "README kill switch 표에 ${KILL} (${n})"
else no "README kill switch 표에 ${KILL} 가 없다"; fi

note "[README 뜻 문장 — AC17 자리 4]"
assert_contains "$(flat < "$RM")" "intent-critic 은 의도대로 만들었는지가 아니라 의도 자체(사용자가 고른 방향 · 기능 · 동작)가 맞는지를 점검한다." "README: intent-critic 뜻 문장"

note "[README 17.0.0 — --answered · 돌려주는 꼴 3판 · 직접 묻는 틀 · 합치기 전 목록]"
RMF="$(flat < "$RM")"
assert_contains "$RMF" '`--answered <경로>` 는 지휘하는 쪽이 이미 사용자에게 물어 답을 받은 것을 담은 파일을 qg 에 넘기는 인자다' "README: --answered 뜻 문장"
assert_contains "$RMF" '돌려주는 꼴은 3판이다 — `contract: 3`' "README: 돌려주는 꼴 3판"
for k in why asked_before changed_observation answered_filtered; do
  assert_contains "$RMF" "새 칸 \`$k\`" "README: 새 칸 $k"
done
assert_contains "$RMF" '직접 묻는 틀은 질문 문장을 먼저 보이고 「왜 묻나」 한 줄을 그 아래에 단다' "README: 직접 묻는 틀 문장"
assert_contains "$RMF" '`findings-pre-merge.yaml` 은 재비판 처분을 반영한 뒤 · 같은 지적을 합치기 전의 목록이다' "README: 합치기 전 목록 파일"
assert_contains "$RMF" '`type: roadmap-review` 문서는 다른 팀 기록에 싣지 않는다' "README: roadmap-review 제외"
assert_contains "$RMF" '넘겨받은 답을 읽지 못함 — <사유>' "README: 읽지 못함 알림"
# R6 통합 리뷰 F5 — README 가 화면 틀 · asked_before 값과 맞는다
assert_contains "$RMF" '를 결과 절 표의 `근거` 칸 · 돌려주는 꼴에 남긴다 — 질문 화면에는 싣지 않고 `자세히` 줄의 파일에 있다' "README(F5 가): 근거의 종류는 질문 화면에 싣지 않는다"
assert_not_contains "$RMF" '질문 앞 글 · 결과 절 표의 `근거` 칸' "README(F5 가) 음성: 근거의 종류를 질문 앞 글에 보인다던 옛 문장이 없다(양성 짝: 질문 화면에는 싣지 않고)"
assert_contains "$RMF" '열쇠 또는 정체 · 다시 묻는 까닭 — `근거가 달라짐` 또는 `고친 뒤에도 보임`)' "README(F5 다): asked_before 넷째 칸은 다시 묻는 까닭 두 값"
assert_not_contains "$RMF" '열쇠 또는 정체 · 근거가 달라졌는지' "README(F5 다) 음성: 넷째 칸을 「근거가 달라졌는지」 로 적던 옛 글이 없다(양성 짝: 다시 묻는 까닭 두 값)"
CHG="$(flat < "$PLUGIN_ROOT/CHANGELOG.md")"
assert_contains "$CHG" '## [17.0.0] — 2026-11-24' "CHANGELOG: 17.0.0 절"
# 판은 major 의 바닥만 본다 — 돌려주는 꼴 3판이 17 에서 나왔고 그 아래로 돌아가지 않았다. 판 글자를 박으면 다음 bump 마다 RED 다.
QG_VER="$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$PLUGIN_ROOT/.claude-plugin/plugin.json" | head -1)"
QG_MAJOR="${QG_VER%%.*}"
case "$QG_MAJOR" in
  ''|*[!0-9]*) no "plugin.json 판을 읽지 못했다(${QG_VER})" ;;
  *) if [ "$QG_MAJOR" -ge 17 ]; then ok "plugin.json 판의 major 가 17 이상(${QG_VER})"; else no "plugin.json 판의 major 가 17 이상(${QG_VER})"; fi ;;
esac

note "[옛 이름 부재]"
for f in "$S" "$PROC" "$SFF" "$RM" "$SCRIPTS/setup-qg.sh" "$PLUGIN_ROOT/agents/intent-critic.md" \
         "$PLUGIN_ROOT/tests/test_plain_qg_templates.sh" "$PLUGIN_ROOT/tests/test_setup_qg.sh" "$0"; do
  assert_file_absent "$f" "$OLD" "옛 이름 없음: ${f##*/}"
done

# ---------------------------------------------------------------- 판정 불변 · 답 커밋 범위
TMP="$(mktemp -d)"
[ -n "${TMP}" ] && [ -d "${TMP}" ] || { echo "mktemp -d 실패"; exit 1; }
trap 'rm -rf "${TMP}"' EXIT

# 가짜 gh — 부르면 argv 를 적고 실패한다. 임시 리포에는 origin 이 없어 gh-repo.sh 가 gh 를 부르기 전에 멈춘다.
# 기록이 비어 있음을 아래에서 단언한다(테스트는 네트워크에 닿지 않는다).
FAKEBIN="$TMP/fakebin"; GH_LOG="$TMP/gh-argv.log"
mkdir -p "$FAKEBIN" && : > "$GH_LOG"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s"\nexit 1\n' "$GH_LOG" > "$FAKEBIN/gh" && chmod +x "$FAKEBIN/gh"

ic_run() {   # ic_run <intent_critic.py> <하위 명령 …> — 이 단계의 환경 변수를 비운 채 돈다(gh 는 가짜)
  ( unset "$KILL" "$GLOBAL" DEVBREW_QUALITY_GATES_INTENT_ANSWERS_DIR DEVBREW_QUALITY_GATES_INTENT_CRITIC_MAX_BYTES \
      DEVBREW_QUALITY_GATES_OTHER_TEAMS_MAX_BYTES DEVBREW_QUALITY_GATES_INTENT_DOC_MARKERS
    PATH="$FAKEBIN:$PATH" PYTHONDONTWRITEBYTECODE=1 python3 "$@" )
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

mkrd_wide() {   # mkrd_wide <세션 폴더> — mkrd 와 같되 걷기 기록이 없고 차등 귀속이 STILL_GREEN, 바뀐 파일 목록에 a.txt
  mkrd "$1" || return 1
  rm -f "$1/e2e-record.md"
  printf 'per_adapter:\n  - runner: pytest\n    attributions:\n      - unit: t::a\n        verdict: STILL_GREEN\n        note: ""\n' > "$1/differential.yaml"
  printf 'a.txt\n' > "$1/review-i1.names"
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

INTENT_DOC=docs/x-design.md
mkrd_prwide() {   # mkrd_prwide <리포> <세션 폴더> — PR 범위 · 바뀐 파일은 커밋된 의도 문서 하나 · 돌려 본 근거 없음
  mkdir -p "$1/docs" || return 1
  printf -- '---\nsource_interview: docs/brief.md\n---\n# 설계\n고른 구절\n' > "$1/$INTENT_DOC"
  # mkrepo 가 스테이지한 b.txt 는 그대로 두고 그 문서만 커밋한다.
  git -C "$1" add -- "$INTENT_DOC" && git -C "$1" commit -q -m doc --only -- "$INTENT_DOC" || return 1
  mkrd_wide "$2" && printf '%s\n' "$INTENT_DOC" > "$2/review-i1.names"
}

reviewer_out_prwide() {   # reviewer_out_prwide <파일> — 의도 문서 5줄의 읽은 인용만 가진 질문 하나
  cat > "$1" <<'EOF'
살펴본 결과다.
```qg-intent-critic
questions:
- target_source: diff
  target_id: docs/x-design.md
  kind: 중복
  weight: 기능
  quote: 고른 구절
  label: 고른 라벨
  question: 이 설계가 이미 있는 것과 겹치는데 정말 새로 만드는 것인가?
  read_quotes:
  - path: docs/x-design.md
    line: 5
    text: 고른 구절
```
끝.
EOF
}

reviewer_out_wide() {   # reviewer_out_wide <파일> — 근거 줄 없이 읽은 인용(a.txt 1줄)만 가진 질문 하나
  cat > "$1" <<'EOF'
살펴본 결과다.
```qg-intent-critic
questions:
- target_source: diff
  target_id: a.txt
  kind: 중복
  weight: 기능
  quote: 고른 구절
  label: 고른 라벨
  question: a.txt 가 이미 있는 것과 겹치는데 정말 새로 만든 것인가?
  read_quotes:
  - path: a.txt
    line: 1
    text: x
```
끝.
EOF
}

origin_head() {   # origin_head <리포> — origin/HEAD → origin/main(원격 없이 ref 만)
  git -C "$1" update-ref refs/remotes/origin/main HEAD \
    && git -C "$1" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
}

kill_run() {   # kill_run <켤 변수 이름> <폴더> <intent_critic.py> <하위 명령 …> — 그 스위치만 켜고, PATH 앞에 이 실행만의 가짜 gh
  local var="$1" d="$2" other
  shift 2
  other="$KILL"; [ "$var" = "$KILL" ] && other="$GLOBAL"
  ( unset "$other" DEVBREW_QUALITY_GATES_INTENT_ANSWERS_DIR DEVBREW_QUALITY_GATES_INTENT_CRITIC_MAX_BYTES \
      DEVBREW_QUALITY_GATES_OTHER_TEAMS_MAX_BYTES DEVBREW_QUALITY_GATES_INTENT_DOC_MARKERS
    export "$var=1"
    PATH="$d/fakebin:$PATH" PYTHONDONTWRITEBYTECODE=1 python3 "$@" )
}

# run_stage <intent_critic.py> <kill|kill-global|pr|range|wide|prwide> <폴더> — 임시 리포 · 세션 폴더를 만들고 절차 순서대로 단계를 돈다.
# wide 는 범위 모드로 돌되 돌려 본 근거 없이 바뀐 파일 목록과 읽은 인용으로 넓게 본다. prwide 는 PR 범위에서 바뀐 파일이
# 커밋된 의도 문서 하나라 넓게 보고, 읽은 인용의 질문에 답해 답 커밋까지 간다.
# stdout 은 <폴더>/out.txt, 하위 명령마다의 rc 는 <폴더>/rc.txt 에 모인다.
run_stage() {
  local ic="$1" mode="$2" d="$3" repo rd m f var
  repo="$d/repo"; rd="$repo/.claude/quality-gates/$SID"
  # wide 의 리포에는 origin/HEAD 가 있고 origin URL 은 없다 — 다른 팀 읽기가 열린 PR 조회까지 가서 gh 앞에서 멈춘다.
  # kill · kill-global 의 리포에는 origin/HEAD 와 origin URL 이 함께 있다 — 스위치가 prepare 를 끄지 못하면 이 실행의 가짜 gh 가 불린다.
  case "$mode" in
    wide) mkrepo "$repo" && origin_head "$repo" && mkrd_wide "$rd" ;;
    kill|kill-global) mkrepo "$repo" && origin_head "$repo" \
            && git -C "$repo" remote add origin https://example.invalid/o/r.git && mkrd_wide "$rd" \
            && mkdir -p "$d/fakebin" && : > "$d/gh.log" \
            && printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s"\nexit 1\n' "$d/gh.log" > "$d/fakebin/gh" \
            && chmod +x "$d/fakebin/gh" ;;
    prwide) mkrepo "$repo" && mkrd_prwide "$repo" "$rd" ;;
    *) mkrepo "$repo" && mkrd "$rd" ;;
  esac || { echo "fixture 실패" >> "$d/out.txt"; return 1; }
  mkdir -p "$d/before"
  for f in verdict.out comment-head.md comment.md findings.yaml result.md; do cp "$rd/$f" "$d/before/$f"; done
  git -C "$repo" rev-parse HEAD > "$d/head-before"
  : > "$d/out.txt"; : > "$d/rc.txt"
  if [ "$mode" = kill ] || [ "$mode" = kill-global ]; then
    var="$KILL"; [ "$mode" = kill-global ] && var="$GLOBAL"
    kill_run "$var" "$d" "$ic" gate --rd "$rd" --path final --mode range >> "$d/out.txt" 2>> "$d/err.txt"
    echo "$?" >> "$d/rc.txt"
    # gate 를 건너뛰고 prepare 를 바로 불러도 스위치가 넓게 보기 · 다른 팀 읽기 · gh 조회를 끈다 — prepare 가 스스로 지킨다.
    kill_run "$var" "$d" "$ic" config --rd "$rd" --repo "$repo" --base HEAD --project-dir "$repo" > /dev/null 2>> "$d/err.txt"
    echo "$?" >> "$d/rc.txt"
    kill_run "$var" "$d" "$ic" prepare --rd "$rd" --repo "$repo" --tree-root "$repo" --mode range --head HEAD \
      --review-commit HEAD --specs-json "$rd/intent-specs.json" > "$d/prepare-out.txt" 2>> "$d/err.txt"
    echo "$?" >> "$d/rc.txt"
    return 0
  fi
  m=pr; case "$mode" in range|wide) m=range ;; esac
  step() { ic_run "$ic" "$@" >> "$d/out.txt" 2>> "$d/err.txt"; echo "$?" >> "$d/rc.txt"; }
  step gate --rd "$rd" --path final --mode "$m"
  step config --rd "$rd" --repo "$repo" --base HEAD --project-dir "$repo"
  step prepare --rd "$rd" --repo "$repo" --tree-root "$repo" --mode "$m" --head HEAD \
    --review-commit HEAD --specs-json "$rd/intent-specs.json"
  case "$mode" in
    wide) reviewer_out_wide "$rd/intent-critic-1.txt" ;;
    prwide) reviewer_out_prwide "$rd/intent-critic-1.txt" ;;
    *) reviewer_out "$rd/intent-critic-1.txt" ;;
  esac
  step check-output "$rd/intent-critic-1.txt"
  step filter --rd "$rd"
  if [ "$m" = pr ]; then
    if [ "$mode" = prwide ]; then
      printf '=== n: 1 · id: diff#%s#중복 · pick: 의도다\n' "$INTENT_DOC" > "$rd/intent-answers.txt"
    else
      printf '=== n: 1 · id: diff#a.txt#기본값 · pick: 의도다\n' > "$rd/intent-answers.txt"
    fi
    step record --rd "$rd" --repo "$repo" --answers "$rd/intent-answers.txt"
  fi
  step render --rd "$rd" --mode "$m"
}

# check_stage <kill|kill-global|pr|range|wide|prwide> <폴더> — 판정 불변 · 답 커밋 범위를 잰다. 줄마다 「PASS <이름>」 또는 「FAIL <이름>」.
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
if mode in ("kill", "kill-global"):
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
    pr|prwide)
      cnt="$(git -C "$repo" rev-list --count "$(cat "$d/head-before")..HEAD")"
      files="$(git -C "$repo" show --name-only --format= HEAD)"
      [ "$cnt" = 1 ] && [ "$(printf '%s\n' "$files" | grep -c .)" = 1 ] \
        && [ "$(printf '%s\n' "$files" | grep -c "^${ANS_DIR}/[^/]*\.md$")" = 1 ]; r commit-scope "$?"
      grep -q '^답 파일 1개를 커밋했다(' "$d/out.txt"; r commit-line "$?"
      [ "$last" = "intent-critic — 질문 1개를 물었다 · 답 1개(잘못 골랐다 0개)" ]; r result-line "$?"
      if [ "$mode" = prwide ]; then
        # 의도 문서가 바뀐 PR 의 넓은 갈래가 거르기 · 렌더까지 간다 — 읽은 인용만으로 물었고 그 종류가 돌려주는 꼴에 실린다.
        grep -q -x -F 'breadth: intent-docs' "$rd/intent-return.md" 2>/dev/null; r breadth-intent-docs "$?"
        grep -q -x -F '    evidence: "읽어서 봄"' "$rd/intent-return.md" 2>/dev/null; r evidence-read "$?"
      fi
      ;;
    range|kill|kill-global|wide)
      [ "$(git -C "$repo" rev-parse HEAD)" = "$(cat "$d/head-before")" ]; r no-commit "$?"
      [ ! -e "$repo/$ANS_DIR" ]; r no-answer-files "$?"
      if [ "$mode" = kill ] || [ "$mode" = kill-global ]; then
        [ "$(cat "$d/out.txt")" = "intent-critic 꺼짐(kill switch)" ]; r kill-line "$?"
        grep -q -F 'intent-critic 꺼짐(kill switch)' "$rd/intent-return.md" 2>/dev/null; r kill-return "$?"
        grep -q -x 'reason: kill-switch' "$rd/intent-return.md" 2>/dev/null; r kill-reason "$?"
        # 스위치 하나가 넓게 보기와 다른 팀 읽기를 함께 끈다(AC12) — gate 를 건너뛴 prepare 에서도.
        [ "$(cat "$d/prepare-out.txt" 2>/dev/null)" = "intent-critic 꺼짐(kill switch)" ]; r prepare-kill-line "$?"
        [ -f "$d/prepare-out.txt" ] && ! grep -q -F '넓게 본다' "$d/prepare-out.txt"; r no-wide-line "$?"
        [ -f "$d/gh.log" ] && [ ! -s "$d/gh.log" ]; r no-gh-call "$?"
        [ ! -e "$rd/other-teams.md" ]; r no-teams-file "$?"
        [ ! -e "$rd/intent-scope.md" ]; r no-scope-file "$?"
      else
        [ "$last" = "intent-critic — 질문 1개 묻지 않음(범위 모드)" ]; r result-line "$?"
      fi
      if [ "$mode" = wide ]; then
        [ -f "$rd/other-teams.md" ]; r teams-file "$?"
        grep -q -x -F '다른 팀과 겹치는 곳:' "$rd/result.md"; r overlap-list "$?"
      fi
      ;;
  esac
}

# 모드마다 check_stage 가 내는 검사 수 — 줄면 검사가 조용히 빠진 것이다
expect_checks() { case "$1" in kill|kill-global) echo 20 ;; wide|prwide) echo 16 ;; *) echo 14 ;; esac; }

note "[판정 불변 · 답 커밋 범위 — 실제 스크립트]"
for mode in kill kill-global pr range wide prwide; do
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
VW="$TMP/real-wide/repo/.claude/quality-gates/$SID/verdict.out"
VK="$TMP/real-kill/repo/.claude/quality-gates/$SID/verdict.out"
[ -s "$VW" ] && [ -s "$VK" ]; assert_eq "$?" 0 "판정 줄 견주기: 넓게 본 실행 · 끈 실행의 verdict.out 이 둘 다 비어 있지 않다"
assert_eq "$(tail -n 1 "$VW")" "qg: defect · 지적 0 · 차등 새 실패 1" "판정 줄 견주기: 넓게 본 실행의 판정 줄이 fixture 가 쓴 줄 그대로"
assert_eq "$(tail -n 1 "$VW")" "$(tail -n 1 "$VK")" "넓게 본 실행과 끈 실행의 판정 줄이 같다"

note "[네트워크 — 열린 PR 조회는 gh 를 부르지 않고 멈춘다]"
assert_eq "$(git -C "$TMP/real-wide/repo" remote)" "" "넓게 본 실행의 임시 리포에 원격이 없다"
assert_file_grep "$TMP/real-wide/repo/.claude/quality-gates/$SID/other-teams.md" '^- 열린 PR 확인 못 함 — origin 을 읽지 못함$' "열린 PR 조회 길을 탔고 origin 에서 멈췄다(양의 짝)"
assert_eq "$(wc -c < "$GH_LOG" | tr -d ' ')" 0 "가짜 gh 가 한 번도 불리지 않았다"

note "[kill switch — 끈 prepare 검사의 양의 짝]"
# 같은 리포 · 같은 세션 폴더에서 스위치만 끄면 넓게 보고 이 실행의 가짜 gh 가 불린다 — 위 kill 검사가 공허하지 않다.
KD="$TMP/real-kill"; KRD="$KD/repo/.claude/quality-gates/$SID"
# 가짜 gh 가 없으면 이 실행이 진짜 gh 를 부를 수 있다 — 돌리지 않는다.
if [ -x "$KD/fakebin/gh" ]; then
  ( unset "$KILL" "$GLOBAL"; PATH="$KD/fakebin:$PATH" PYTHONDONTWRITEBYTECODE=1 python3 "$SCRIPTS/intent_critic.py" prepare \
      --rd "$KRD" --repo "$KD/repo" --tree-root "$KD/repo" --mode range --head HEAD --review-commit HEAD \
      --specs-json "$KRD/intent-specs.json" ) > "$KD/prepare-on.txt" 2>> "$KD/err.txt"
  assert_eq "$(grep -c -x -F '넓게 본다 — 범위 모드' "$KD/prepare-on.txt")" 1 "스위치를 끄면 같은 리포에서 넓게 본다(양의 짝)"
  [ -s "$KD/gh.log" ]; assert_eq "$?" 0 "스위치를 끄면 같은 리포에서 이 실행의 가짜 gh 가 불린다(양의 짝)"
  [ -f "$KRD/other-teams.md" ] && [ -f "$KRD/intent-scope.md" ]; assert_eq "$?" 0 "스위치를 끄면 두 파일이 생긴다(양의 짝)"
else
  no "kill 짝 실행: 가짜 gh 가 없다 — 진짜 gh 를 부를 수 있어 돌리지 않는다"
fi

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
# 형제 모듈까지 — 링크(adjudication.py 등)는 풀어서. gh-repo.sh 도 가져간다: 없으면 사본의 열린 PR 조회가 gh 앞에서 멈춰 변이 g 의 no-gh-call 이 공허해진다.
mkcopy() { mkdir -p "$1" && cp -L "$SCRIPTS"/*.py "$SCRIPTS/gh-repo.sh" "$1/"; }
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
d="$TMP/mut-plain-wide"; mkdir -p "$d"
run_stage "$TMP/copy-plain/intent_critic.py" wide "$d"
res="$(check_stage wide "$d")"
assert_eq "$(printf '%s\n' "$res" | grep -c '^PASS ')" "$(expect_checks wide)" "바꾸지 않은 사본(넓게): 검사 전부 PASS"
d="$TMP/mut-plain-kill-global"; mkdir -p "$d"
run_stage "$TMP/copy-plain/intent_critic.py" kill-global "$d"
res="$(check_stage kill-global "$d")"
assert_eq "$(printf '%s\n' "$res" | grep -c '^PASS ')" "$(expect_checks kill-global)" "바꾸지 않은 사본(전역 스위치): 검사 전부 PASS"

run_mutant() {   # run_mutant <이름> <과녁 검사[,검사 …]> [모드] — 사본 폴더 $TMP/copy-<이름> 은 이미 변이됐다. 모드 기본 pr
  local d="$TMP/mut-$1" res mode="${3:-pr}" target
  mkdir -p "$d"
  run_stage "$TMP/copy-$1/intent_critic.py" "$mode" "$d"
  res="$(check_stage "$mode" "$d")"
  for target in $(printf '%s' "$2" | tr ',' ' '); do
    if printf '%s\n' "$res" | grep -q -x "FAIL ${target}"; then ok "변이 $1: ${target} 가 RED"
    else no "변이 $1: ${target} 가 RED 가 아니다 — $(printf '%s' "$res" | tr '\n' ' ')"; fi
  done
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
mutate "$TMP/copy-d/intent_answers.py" 'add = _git(repo_root, "add", "--", *specs)' 'add = _git(repo_root, "add", "-A")' \
  && mutate "$TMP/copy-d/intent_answers.py" 'commit = _git(repo_root, "commit", "--only", "-q", "-m", message, "--", *specs)' \
       'commit = _git(repo_root, "commit", "-q", "-m", message)'
assert_eq "$?" 0 "변이 d(답 커밋이 경로를 지정하지 않는다)를 심었다"
run_mutant d commit-scope

note "[변이 — 넓게 보는 실행의 판정 불변]"
mkcopy "$TMP/copy-e"
mutate "$TMP/copy-e/intent_critic.py" '_write(_path(rd, OTHER_TEAMS), teams_text)' '_write(_path(rd, OTHER_TEAMS), teams_text); _append(_path(rd, "findings.yaml"), teams_text)'
assert_eq "$?" 0 "변이 e(다른 팀 기록을 findings.yaml 에 덧붙인다)를 심었다"
run_mutant e same:findings.yaml wide
mkcopy "$TMP/copy-f"
mutate "$TMP/copy-f/intent_critic.py" $'    print("intent-ask: %d" % asked)\n' $'    print("qg-verdict-args: --wide %d" % asked)\n    print("intent-ask: %d" % asked)\n'
assert_eq "$?" 0 "변이 f(넓게 본 결과를 판정 인자 줄로 낸다)를 심었다"
run_mutant f no-verdict-args wide

note "[변이 — 전역 스위치를 읽지 않는 꺼짐 판정]"
mkcopy "$TMP/copy-g"
mutate "$TMP/copy-g/intent_critic.py" '    names = _switches_on()
    if not names:
        return False' '    names = [n for n in _switches_on() if n != GLOBAL_KILL_ENV]
    if not names:
        return False'
assert_eq "$?" 0 "변이 g(_killed 가 전역 스위치를 읽지 않는다)를 심었다"
run_mutant g prepare-kill-line,no-gh-call kill-global

finish
