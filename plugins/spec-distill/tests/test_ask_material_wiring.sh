#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/spec-review/SKILL.md plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/skills/request-framing/SKILL.md shared/docreview/references/reviewing-document.md plugins/spec-distill/references/proceed-gate.md plugins/spec-distill/skills/pm-interview/references/finishing.md shared/docreview/scripts/docreview_state.py shared/docreview/scripts/docreview_ask.py shared/docreview/scripts/nofollow_write.py plugins/spec-distill/scripts/ledger_marker.py
#
# 리뷰 결정 질문이 엔진의 질문 재료를 싣는다(present-tradeoffs AC7 · AC3 · AC8).
#   정적 — 진입 skill 셋에 질문 재료 펜스가 있고, 표지 확인이 전문 파일 쓰기보다 앞이며, 8단계 재진술이
#          새 문장이다. 절차서 8단계가 질문 꼴 · 선택지 설명 · 줄일 때의 규칙 넷 · 기타 칸의 「전문」을 적는다.
#          다음 단계 질문을 띄우는 자리가 두 줄을 표지를 푸는 펜스보다 먼저 돈 질문 재료 펜스에서 받는다고 적는다.
#   행동 — spec-review 의 펜스 글을 그대로 잘라 원장이 열린 설계문서로 돌린다(표지 주인 · 채널 줄 ·
#          남의 표지 · 전문 파일 자리가 링크 · 질문 행 없는 승인 게이트에서 참고 목록 펜스 앞).
#          펜스가 부르는 엔진 · writer · 표지 스크립트도 이 테스트가 실제로 돌린다(그 출력을 받는 쪽의 유일한 시험).
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/skills/spec-review/SKILL.md"
  echo "plugins/spec-distill/skills/reviewing-brief/SKILL.md"
  echo "plugins/spec-distill/skills/request-framing/SKILL.md"
  echo "shared/docreview/references/reviewing-document.md"
  echo "plugins/spec-distill/references/proceed-gate.md"
  echo "plugins/spec-distill/skills/pm-interview/references/finishing.md"
  echo "shared/docreview/scripts/docreview_state.py"
  echo "shared/docreview/scripts/docreview_ask.py"
  echo "shared/docreview/scripts/nofollow_write.py"
  echo "plugins/spec-distill/scripts/ledger_marker.py"; exit 0
fi
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
. "$REPO_ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
unset DEVBREW_SPEC_DISTILL_DISABLE DEVBREW_SKIP_HOOKS DEVBREW_SPEC_DISTILL_TTL_HOURS DEVBREW_DOCREVIEW_ASK_WIDTH
T="$(mktemp -d)"; [ -n "$T" ] && [ -d "$T" ] || { echo "mktemp 실패"; exit 1; }
T="$(cd "$T" && pwd -P)"; trap 'rm -rf "$T"' EXIT

SR="$SD/skills/spec-review/SKILL.md"; RB="$SD/skills/reviewing-brief/SKILL.md"; RF="$SD/skills/request-framing/SKILL.md"
PROC="$REPO_ROOT/shared/docreview/references/reviewing-document.md"
am_body() {   # am_body <파일> → 질문 재료 펜스의 bash 본문(여는 ```bash 줄과 닫는 ``` 줄을 뺀다)
  awk '/<!-- ask-material:begin -->/{f=1;next} /<!-- ask-material:end -->/{f=0} f' "$1" | sed -e '1d' -e '$d'
}

# ── 정적 ────────────────────────────────────────────────────────────────────
for f in "$SR" "$RB" "$RF"; do
  name="$(basename "$(dirname "$f")")"
  body="$(am_body "$f")"
  [ -n "$body" ] && ok "$name: 질문 재료 펜스가 있다" || no "$name: 질문 재료 펜스가 없다"
  printf '%s\n' "$body" | bash -n 2>/dev/null && [ -n "$body" ] && ok "$name: 펜스가 bash 문법에 맞다" || no "$name: 펜스가 bash 문법에 맞지 않다"
  g="$(printf '%s\n' "$body" | grep -n 'ledger_marker.py" check --dir "$STATE_DIR"' | head -1 | cut -d: -f1)"
  w="$(printf '%s\n' "$body" | grep -n 'docreview_state.py" gate-file --state-dir "$STATE_DIR"' | head -1 | cut -d: -f1)"
  [ -n "$g" ] && [ -n "$w" ] && [ "$g" -lt "$w" ] && ok "$name: 표지 확인이 전문 파일 쓰기보다 앞 줄이다" || no "$name: 표지 확인이 전문 파일 쓰기 앞에 없다"
  assert_contains "$body" 'ask-material --state-dir "$STATE_DIR" --gate-file-result "$gf"' "$name: 질문 재료가 쓰기 결과를 받는다"
  assert_contains "$body" 'nofollow_write.py" append --out "$gf_path"' "$name: 채널 줄은 링크를 따라가지 않는 writer 로 덧붙인다"
  assert_contains "$body" "printf '\n## 다른 채널의 경고\n%s\n'" "$name: 채널 구역의 제목 줄이 엔진이 알아보는 글자다"
  assert_eq "$(grep -cF '질문 본문은 엔진의 질문 재료가 낸 「본문」 · 「상태」 · 「덧줄」 · 「전문」 줄을 그대로 싣고' "$f")" "1" "$name: 8단계 재진술이 새 문장이다"
  assert_eq "$(grep -cF '<!-- ask-material:begin -->' "$f")" "1" "$name: 질문 재료 펜스는 하나다"
done
assert_contains "$(awk '/<!-- ask-material:begin -->/{f=1} /<!-- ask-material:end -->/{f=0} f' "$RF")" '--fix-rows --ask-rows' "request-framing 은 수정 행과 질문 행의 묶음도 받는다"
assert_not_contains "$(am_body "$SR")$(am_body "$RB")" '--fix-rows' "spec-review · reviewing-brief 는 수정 행 묶음을 받지 않는다(양의 짝)"
for lit in '질문마다 엔진의 질문 재료(`docreview_state.py ask-material`) 한 묶음을 쓴다' '**선택지 설명** — 「고친다」의 설명은 고치면 무엇이 바뀌는지' \
           '**줄일 때의 규칙 넷** — 「스크립트·subagent 가 낸 원문은 고치지 않는다」의 예외는 이 자리의 두 칸' '리뷰어가 낸 길이 아니다' \
           '**기타 칸의 「전문」** — 사용자가 기타 칸에 「전문」' '그 줄은 질문 재료의 「덧줄」로 나온다 — 질문 본문에 그대로 싣는다.'; do
  assert_eq "$(grep -cF -- "$lit" "$PROC")" "1" "절차서: ${lit:0:24}…"
done
[ -L "$REPO_ROOT/plugins/spec-distill/references/reviewing-document.md" ] && ok "절차서의 플러그인 쪽은 정본을 가리키는 링크다" || no "절차서의 플러그인 쪽이 링크가 아니다"

# 다음 단계 질문의 두 줄 — 표지를 푸는 펜스보다 먼저 돈 질문 재료 펜스의 마지막 출력에서(AC8 · §4-3)
PG="$SD/references/proceed-gate.md"; FIN="$SD/skills/pm-interview/references/finishing.md"
assert_eq "$(grep -cF '엔진의 「상태」 줄과 「전문」 줄은 표지를 푸는 펜스(참고 목록 · 계수 기록)보다 먼저 돈 질문 재료 펜스의 마지막 출력에서 받는다' "$PG")" "1" "정본: 두 줄의 출처와 순서"
assert_eq "$(grep -cF '경고 줄과 「전문」 줄은 표지를 푸는 펜스(아래 참고 목록 펜스)보다 먼저 돈 질문 재료 펜스의 마지막 출력에서 받는다' "$SR")" "1" "spec-review: 2단계 · 승인 질문 하나의 두 줄 출처"
assert_eq "$(grep -cF '참고 목록 펜스 뒤에는 질문 재료 펜스를 돌리지 않는다' "$SR")" "1" "spec-review: 표지를 푼 뒤에는 그 펜스를 돌리지 않는다"
assert_eq "$(grep -cF 'Step B 로 돌아가기 직전에 `## 게이트` 의 질문 재료 펜스를 한 번 더 돈다' "$RB")" "1" "reviewing-brief: 돌아가기 직전의 마지막 질문 재료 펜스"
assert_eq "$(grep -cF '마지막 질문 재료 펜스에 `channel_lines` 로 넣는다' "$RB")" "1" "reviewing-brief: 원장 줄 전체가 그 한 번에 실린다"
assert_eq "$(grep -cF '경고 줄과 「전문」 줄은 표지를 푸는 이 계수 기록 펜스보다 먼저 돈 질문 재료 펜스의 마지막 출력에서 받는다' "$RF")" "1" "request-framing: 확정 게이트의 두 줄 출처"
assert_eq "$(grep -cF '돈 질문 재료 펜스(B-A 가 표지를 풀기 전의 마지막 출력)의 「상태」 줄' "$FIN")" "1" "인터뷰 끝 B-2: 엔진 줄의 출처"
assert_eq "$(grep -cF '「전문」 줄은 그 마지막 질문 재료 출력의 「전문:」 줄 그대로입니다' "$FIN")" "1" "인터뷰 끝 B-2: 전문 줄의 출처"
assert_eq "$(grep -cF '2단계 질문의 「상태」 · 「전문」 줄은 표지를 푸는 펜스보다 먼저 돈 질문 재료 펜스의 마지막 출력에서 받는다' "$PROC")" "1" "절차서 8단계: 두 줄의 출처"
assert_eq "$(grep -cF '질문 재료 펜스가 0 이 아닌 코드로 끝나면' "$PROC")" "1" "절차서 8단계: 질문 재료가 실패했을 때의 길"
assert_eq "$(grep -cF '그 문구는 빼고 그 채널의 짧은 줄만 싣는다' "$PROC")" "1" "절차서 8단계: 경고 없는 문구와 다른 채널 줄이 부딪힐 때"
for f in "$RB" "$RF"; do
  assert_eq "$(grep -cF '그 줄이 있으면(경고가 있으면) 「상태」 줄의 「이상 없음」·「경고 없음」은 쓰지 않는다.' "$f")" "1" "$(basename "$(dirname "$f")"): 라운드 게이트의 경고 없는 문구 빼기"
done

# ── 행동 — spec-review 의 펜스를 원장이 열린 설계문서로 돌린다 ─────────────────────────────
fence() {   # fence <파일> <마커 이름> → 그 마커 사이 첫 bash 펜스 본문
  awk -v b="<!-- $2:begin -->" -v e="<!-- $2:end -->" '
    index($0,b){f=1;next} index($0,e){f=0} f&&/^```bash$/{c=1;next} f&&c&&/^```$/{c=0;next} f&&c' "$1"
}
repo="$T/repo"; mkdir -p "$repo/docs" && git -C "$repo" init -q
doc="$repo/docs/a-design.md"; cp "$REPO_ROOT/shared/tests/fixtures/docreview/design-sample.md" "$doc"
OWNER=sess-aaaa1111; OTHER=sess-bbbb2222
o="$( cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID="$OWNER" DEVBREW_SPEC_DISTILL_SESSION_ID="$OWNER" \
      bash -c "spec_path='$doc'
$(fence "$SR" ledger-open)" 2>&1 )"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: HELD" "준비: 원장 열기가 표지를 잡았다"
D="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$repo/.claude/spec-distill" --doc "$doc")"
python3 "$SD/scripts/docreview_state.py" init --state-dir "$D" --doc "$doc" --profile "$SD/references/docreview-profiles/design-doc.md" >/dev/null
python3 "$SD/scripts/docreview_state.py" begin-round --state-dir "$D" >/dev/null
printf '%s' '[{"id":"aaaa0001#r1.1","lineage":"aaaa0001#r1.1","bucket":"aaaa0001","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"decide","summary":"파일 목록이 두 가지로 읽힌다","evidence":"12행","blocks":[],"kind":"pre"}]' > "$T/f.json"
python3 "$SD/scripts/docreview_state.py" record-findings --state-dir "$D" --json "$T/f.json" >/dev/null \
  && ok "준비: 결정 하나가 원장에 있다" || no "준비: 결정을 원장에 적지 못했다"
GF="$D/gate-r1.md"

am_run() {   # am_run <sid> [<채널 줄>] → spec-review 질문 재료 펜스 출력(앞에 경로 대입과 따옴표 heredoc 의 채널 대입)
  local pre=""
  [ -z "${2:-}" ] || pre="IFS= read -r -d '' channel_lines <<'DEVBREW_CHANNEL_EOF' || true
$2
DEVBREW_CHANNEL_EOF
channel_lines=\"\${channel_lines%\$'\\n'}\""
  ( cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID="$1" DEVBREW_SPEC_DISTILL_SESSION_ID="$1" \
      bash -c "spec_path='$doc'
$pre
$(am_body "$SR")" 2>&1 )
}

# 1 — 표지 주인 · 결정 하나
out="$(am_run "$OWNER")"; rc=$?
assert_eq "$rc" "0" "표지 주인: 펜스가 rc 0 으로 끝난다"
assert_grep "$out" '^질문 1/' "표지 주인: 질문마다 묶음이 나온다"
assert_grep "$out" '^전문: ' "표지 주인: 전문 줄이 있다"
assert_not_contains "$out" "전문 파일을 쓰지 못했다" "표지 주인: 전문 파일을 썼다"
[ -f "$GF" ] && [ ! -L "$GF" ] && ok "표지 주인: 상태 폴더에 gate-r1.md 가 있다" || no "표지 주인: gate-r1.md 가 없다"
assert_eq "$(grep -c '^## 다른 채널의 경고$' "$GF" 2>/dev/null)" "0" "채널 줄이 없으면 채널 구역을 덧붙이지 않는다(양의 짝)"

# 2 — 채널 줄이 있으면 전문 파일에 한 번, 두 번 돌려도 한 번
out="$(am_run "$OWNER" '번호 대조 경고 2개')"; rc=$?
assert_eq "$rc" "0" "채널 줄: 펜스가 rc 0 으로 끝난다"
assert_eq "$(grep -c '^## 다른 채널의 경고$' "$GF")" "1" "채널 줄: 전문 파일에 다른 채널의 경고 구역이 한 번"
assert_file_grep "$GF" '^번호 대조 경고 2개$' "채널 줄: 그 줄이 글자 그대로 있다"
am_run "$OWNER" '번호 대조 경고 2개' >/dev/null
assert_eq "$(grep -c '^## 다른 채널의 경고$' "$GF")" "1" "채널 줄: 펜스를 두 번 돌려도 구역은 한 번"
assert_eq "$(grep -c '^번호 대조 경고 2개$' "$GF")" "1" "채널 줄: 두 번 돌려도 줄은 한 번"

# 3 — 남의 표지: 표지 확인이 멈추고 전문 파일도 질문 재료도 없다
python3 "$SD/scripts/ledger_marker.py" takeover --dir "$D" --session "$OTHER" >/dev/null
rm -f "$GF"; before="$(cksum < "$D/docreview-state.md")"
out="$(am_run "$OWNER")"; rc=$?
assert_eq "$rc" "3" "남의 표지: 펜스가 rc 3 으로 멈춘다"
[ ! -e "$GF" ] && ok "남의 표지: gate-r1.md 가 생기지 않는다" || no "남의 표지: gate-r1.md 가 생겼다"
assert_not_contains "$out" "질문 1/" "남의 표지: 질문 재료를 내지 않는다"
assert_eq "$(cksum < "$D/docreview-state.md")" "$before" "남의 표지: 원장이 그대로다"
python3 "$SD/scripts/ledger_marker.py" takeover --dir "$D" --session "$OWNER" >/dev/null

# 4 — 전문 파일 자리가 링크: 쓰지 않고 사유를 전문 줄에 낸다 · 질문은 그대로 · 링크 너머에 쓰지 않는다
printf '바깥 글\n' > "$T/outside.md"; ln -s "$T/outside.md" "$GF"
out="$(am_run "$OWNER" '번호 대조 경고 2개')"; rc=$?
assert_eq "$rc" "0" "링크 자리: 펜스가 rc 0 으로 끝난다"
assert_grep "$out" '^전문: 전문 파일을 쓰지 못했다 — gate_file_write_failed' "링크 자리: 전문 줄이 쓰지 못한 사유로 시작한다"
assert_grep "$out" '^질문 1/' "링크 자리: 질문 재료는 그대로 나온다"
assert_eq "$(cat "$T/outside.md")" "바깥 글" "링크 자리: 링크 너머의 파일에 쓰지 않았다(채널 줄도 덧붙이지 않았다)"

# 5 — 다음 단계 질문이 받는 두 줄: 원장 열기 → 지적 없는 라운드 → 질문 재료 펜스 → 참고 목록 펜스(표지를 푼다)
repo2="$T/repo2"; mkdir -p "$repo2/docs" && git -C "$repo2" init -q
doc2="$repo2/docs/b-design.md"; cp "$REPO_ROOT/shared/tests/fixtures/docreview/design-sample.md" "$doc2"
run2() { ( cd "$repo2" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID="$OWNER" DEVBREW_SPEC_DISTILL_SESSION_ID="$OWNER" \
             bash -c "spec_path='$doc2'
$1" 2>&1 ); }
assert_eq "$(run2 "$(fence "$SR" ledger-open)" | tail -n 1)" "ledger-open: HELD" "다음 단계 준비: 원장 열기가 표지를 잡았다"
D2="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$repo2/.claude/spec-distill" --doc "$doc2")"
python3 "$SD/scripts/docreview_state.py" init --state-dir "$D2" --doc "$doc2" --profile "$SD/references/docreview-profiles/design-doc.md" >/dev/null
python3 "$SD/scripts/docreview_state.py" begin-round --state-dir "$D2" >/dev/null
out="$(run2 "$(am_body "$SR")")"; rc=$?
assert_eq "$rc" "0" "다음 단계: 표지를 쥔 채 돈 질문 재료 펜스가 rc 0 으로 끝난다"
assert_not_grep "$out" '^질문 [0-9]+/' "다음 단계 전제: 질문으로 뜨는 행이 없다"
assert_grep "$out" '^상태: ' "다음 단계: 묶음이 0 이어도 「상태」 줄이 나온다"
assert_grep "$out" '^전문: [^ ]*gate-r1\.md$' "다음 단계: 묶음이 0 이어도 전문 파일 경로가 「전문」 줄로 나온다"
adv="$(run2 "$(fence "$SR" advice-display)")"
assert_not_grep "$adv" '^전문: ' "다음 단계: 참고 목록 펜스는 「전문:」 으로 시작하는 줄을 내지 않는다(전문 줄의 출처는 질문 재료 펜스뿐)"
m_out="$(python3 "$SD/scripts/ledger_marker.py" check --dir "$D2" --session "$OWNER" 2>&1)"; m_rc=$?
[ "$m_rc" -ne 0 ] && printf '%s' "$m_out" | grep -q '표지 없음' \
  && ok "다음 단계: 참고 목록 펜스 뒤 표지가 풀린 채 끝난다" || no "다음 단계: 참고 목록 펜스 뒤에도 표지가 남았다(rc ${m_rc})"
run2 "$(am_body "$SR")" >/dev/null; rc=$?
assert_eq "$rc" "3" "다음 단계: 표지가 풀린 뒤의 질문 재료 펜스는 rc 3 — 그래서 두 줄은 참고 목록 펜스보다 먼저 받는다"

finish
