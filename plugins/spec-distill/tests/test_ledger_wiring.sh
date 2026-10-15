#!/usr/bin/env bash
# R7 §2-2 · §2-4 · §3-2 — 리뷰 진입 펜스의 표지 · 정리 배선 (AC7 · AC8 · AC10 양의 짝).
set -u
ROOT_REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT_REPO/plugins/spec-distill"
. "$ROOT_REPO/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
unset DEVBREW_SPEC_DISTILL_DISABLE DEVBREW_SKIP_HOOKS DEVBREW_SPEC_DISTILL_TTL_HOURS
T="$(mktemp -d)"; [ -n "$T" ] && [ -d "$T" ] || { echo "mktemp 실패"; exit 1; }
T="$(cd "$T" && pwd -P)"; trap 'rm -rf "$T"' EXIT

fence() {   # fence <파일> <마커 이름> → 그 마커 사이 첫 bash 펜스 본문
  awk -v b="<!-- $2:begin -->" -v e="<!-- $2:end -->" '
    index($0,b){f=1;next} index($0,e){f=0} f&&/^```bash$/{c=1;next} f&&c&&/^```$/{c=0;next} f&&c' "$1"
}
SR="$SD/skills/spec-review/SKILL.md"; RB="$SD/skills/reviewing-brief/SKILL.md"
FIN="$SD/skills/spec-interview/references/finishing.md"

repo="$T/repo"; mkdir -p "$repo/docs" && git -C "$repo" init -q
doc="$repo/docs/a-design.md"; printf '# A\n' > "$doc"
run_open() {   # run_open <sid> → 원장 열기 펜스 출력
  ( cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID="$1" DEVBREW_SPEC_DISTILL_SESSION_ID="$1" \
      bash -c "spec_path='$doc'
$(fence "$SR" ledger-open)" 2>&1 )
}

o1="$(run_open sess-aaaa1111)"
assert_eq "$(printf '%s\n' "$o1" | tail -n 1)" "ledger-open: HELD" "AC8: 빈 원장에서 원장 열기가 표지를 잡는다"
SDIR="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$repo/.claude/spec-distill" --doc "$doc")"
assert_eq "$(cat "$SDIR/reviewing-by")" "sess-aaaa1111" "AC8: 표지가 원장 폴더에 세션 id 한 줄로 선다"
o2="$(run_open sess-bbbb2222)"
assert_eq "$(printf '%s\n' "$o2" | tail -n 1)" "ledger-open: OTHER:sess-aaaa1111" "AC8: 다른 세션의 표지가 있으면 멈추고 그 세션을 댄다"
grep -qF '「그만둠 (권장)」' "$SR" && grep -qF '「이어 씀 — 표지를 내 것으로 바꾼다」' "$SR" \
  && ok "AC8: OTHER 판결이 그만둠/이어 씀 질문으로 간다(문면)" || no "AC8: 표지 질문 문면이 없다"
o3="$(cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" bash -c "unset CLAUDE_CODE_SESSION_ID DEVBREW_SPEC_DISTILL_SESSION_ID; spec_path='$doc'
$(fence "$SR" ledger-open)" 2>&1)"
assert_eq "$(printf '%s\n' "$o3" | tail -n 1)" "ledger-open: NO_SESSION" "§2-4: 세션 id 가 없으면 리뷰를 시작하지 않는다"

# AC7 — 이어 감 줄 두 분기
printf -- '---\ndocreview:\n  doc: %s\n  profile: design-doc\n  round: 2\n---\n# x\n' "$doc" > "$SDIR/docreview-state.md"
python3 "$SD/scripts/ledger_marker.py" release --dir "$SDIR" --session sess-aaaa1111 >/dev/null
o4="$(run_open sess-cccc3333)"
printf '%s\n' "$o4" | grep -qF "[spec-distill] 이전 리뷰 라운드 2 에서 이어 간다 — $SDIR" \
  && ok "AC7: 다른 세션이 이어 받으면 이어 감 줄이 난다" || no "AC7: 이어 감 줄이 없다: $o4"
o5="$(run_open sess-cccc3333)"
printf '%s\n' "$o5" | grep -qF "이전 리뷰 라운드" && no "AC7: 같은 세션의 다음 라운드에서 이어 감 줄이 났다" \
  || ok "AC7: 같은 세션의 다음 라운드에서는 이어 감 줄이 없다"

# AC8 — 넘겨받기 뒤 넘겨준 세션의 쓰기가 멈추고 원장이 그대로다
( cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-dddd4444 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-dddd4444 \
    bash -c "spec_path='$doc'
$(fence "$SR" ledger-takeover)" >/dev/null 2>&1 )
assert_eq "$(cat "$SDIR/reviewing-by")" "sess-dddd4444" "AC8: 「이어 씀」 뒤 표지가 바뀐다"
before="$(cksum < "$SDIR/docreview-state.md")"
guard="$(fence "$SR" ledger-guard)"
( cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-cccc3333 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-cccc3333 \
    bash -c "SD='$SD'; STATE_DIR='$SDIR'; harness_sid=sess-cccc3333
$guard
python3 \"\$SD/scripts/docreview_state.py\" begin-round --state-dir \"\$STATE_DIR\" --snapshot /dev/null" >/dev/null 2>&1 ); rc=$?
assert_eq "$rc" "3" "AC8: 남의 표지 — 쓰기 전 확인이 rc 3 으로 멈춘다"
assert_eq "$(cksum < "$SDIR/docreview-state.md")" "$before" "AC8: 남의 표지 — 원장 파일이 바뀌지 않았다"
# 양의 짝 — 표지 주인은 확인을 지나 다음 명령에 닿는다(확인이 늘 멈추는 것이 아니다)
pos="$(cd "$repo" && bash -c "SD='$SD'; STATE_DIR='$SDIR'; harness_sid=sess-dddd4444
$guard
echo guard-passed" 2>&1)"; rc=$?
{ [ "$rc" -eq 0 ] && [ "$pos" = "guard-passed" ]; } \
  && ok "AC8: 표지 주인 — 쓰기 전 확인을 지나 다음 명령이 돈다(양의 짝)" || no "AC8: 표지 주인인데 확인이 막았다(rc $rc): $pos"
# 끝맺음 펜스 — 남의 표지면 박제 · 계수 · 표시를 하지 않고 표지도 풀지 않는다
adv_out="$(cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-cccc3333 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-cccc3333 \
    bash -c "spec_path='$doc'
$(fence "$SR" advice-display)" 2>&1)"
assert_contains "$adv_out" "표지가 다른 세션 것이다" "AC8: 남의 표지 — 끝맺음 펜스가 참고 목록을 건너뛴다"
assert_eq "$(cksum < "$SDIR/docreview-state.md")" "$before" "AC8: 남의 표지 — 끝맺음 펜스 뒤에도 원장 파일이 그대로다"
assert_eq "$(cat "$SDIR/reviewing-by")" "sess-dddd4444" "AC8: 남의 표지 — 끝맺음 펜스의 해제가 남의 표지를 지우지 않는다"
rm -f "$SDIR/reviewing-by"
( cd "$repo" && bash -c "SD='$SD'; STATE_DIR='$SDIR'; harness_sid=sess-cccc3333
$guard
python3 \"\$SD/scripts/docreview_state.py\" begin-round --state-dir \"\$STATE_DIR\" --snapshot /dev/null" >/dev/null 2>&1 ); rc=$?
assert_eq "$rc" "3" "AC8: 표지 없음 — 쓰기 전 확인이 rc 3 으로 멈춘다"
assert_eq "$(cksum < "$SDIR/docreview-state.md")" "$before" "AC8: 표지 없음 — 원장 파일이 바뀌지 않았다"

# AC8 — 원장에 쓰는 명령마다 같은 펜스 안 앞에 확인이 있다(정적). request-framing 은 Task 8 이 이 목록에 더한다.
WRITERS='docreview_state\.py" (init|begin-round|record-findings|decide|fix|ask|defer|observe-diff|advice)|docreview_route\.py" (prepare-recritic|finalize)|docreview_anchor\.py" check-intent'
GUARDED="$SR $RB $FIN"
for f in $GUARDED; do
  python3 -I - "$f" "$WRITERS" <<'PY' && ok "AC8: $(basename "$(dirname "$f")")/$(basename "$f") — 원장 쓰기 명령 앞에 확인이 있다" || no "AC8: $f — 확인 없는 원장 쓰기"
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
w = re.compile(sys.argv[2]); g = 'ledger_marker.py" check --dir "$STATE_DIR"'
bad = []
for body in re.findall(r"^```bash\n(.*?)^```$", text, re.S | re.M):
    for i, line in enumerate(body.splitlines()):
        if w.search(line) and g not in "\n".join(body.splitlines()[:i]):
            bad.append(line.strip()[:120])
print("\n".join(bad), file=sys.stderr)
sys.exit(1 if bad else 0)
PY
done

# AC8 — 해제는 게이트 응답 기록 뒤(문면 순서) · 끝맺음 펜스가 release 로 끝난다
adv="$(fence "$SR" advice-display)"
printf '%s\n' "$adv" | grep -qF 'ledger_marker.py" acquire' && printf '%s\n' "$adv" | tail -n 3 | grep -qF 'ledger_marker.py" release' \
  && ok "AC8: spec-review 끝맺음 펜스가 acquire 로 시작해 release 로 끝난다" || no "AC8: spec-review 끝맺음 펜스 꼴"
python3 -I - "$SR" <<'PY' && ok "AC8: 해제가 finalize · 게이트 응답 반영 뒤에 온다(문면 순서)" || no "AC8: 해제 문면 순서"
import sys
t = open(sys.argv[1], encoding="utf-8").read()
a = t.find("응답을 `decide`·`fix`·`ask` 서브커맨드로 반영한다"); r = t.find("<!-- advice-display:begin -->")
sys.exit(0 if 0 <= a < r else 1)
PY
finb="$(fence "$FIN" advice-ba)"
printf '%s\n' "$finb" | tail -n 3 | grep -qF 'ledger_marker.py" release' && ok "AC8: finishing B-A 가 release 로 끝난다" || no "AC8: finishing B-A 해제 없음"
grep -qF 'ledger_marker.py" release' "$RB" && no "AC8: reviewing-brief 가 스스로 표지를 푼다(B-A 가 푼다)" || ok "AC8: reviewing-brief 는 표지를 풀지 않는다"

# AC10 양의 짝 — 리뷰 진입이 ledger_sweep.py 를 부른다. request-framing 은 Task 8 이 이 목록에 더한다.
SWEEPERS="$SR $RB"
for f in $SWEEPERS; do
  fence "$f" ledger-open | grep -qF 'ledger_sweep.py" --root "$ROOT"' && ok "AC10: $(basename "$(dirname "$f")") 원장 열기가 정리를 부른다" || no "AC10: $f 정리 호출 없음"
done

# ── 보충 A1 — 정리는 mkdir · acquire 앞에서, 같은 세션의 다음 라운드에서는 건너뛴다 ───────────────
age() {   # age <경로> → 그 경로와 아래 전부의 mtime 을 48시간 전으로
  python3 -I - "$1" <<'PY'
import os, sys, time
when = time.time() - 48 * 3600
for dp, dns, fns in os.walk(sys.argv[1]):
    for n in dns + fns:
        os.utime(os.path.join(dp, n), (when, when), follow_symlinks=False)
os.utime(sys.argv[1], (when, when))
PY
}
open_at() {   # open_at <repo> <문서> <sid> <skill 파일> → 원장 열기 펜스 출력(spec_path · PAYLOAD 둘 다 문서)
  ( cd "$1" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID="$3" DEVBREW_SPEC_DISTILL_SESSION_ID="$3" \
      bash -c "spec_path='$2'; PAYLOAD='$2'
$(fence "$4" ledger-open)" 2>&1 )
}
ledger() {   # ledger <파일> <문서> <라운드>
  printf -- '---\ndocreview:\n  doc: %s\n  profile: design-doc\n  round: %s\n---\n# x\n' "$2" "$3" > "$1"
}

# (i) 올린 뒤 첫 리뷰 — 같은 문서의 옛 원장이 원장 열기에서 .docreview 로 옮겨진다
r2="$T/repo2"; mkdir -p "$r2/docs" && git -C "$r2" init -q
d2="$r2/docs/b-design.md"; printf '# B\n' > "$d2"
R2="$r2/.claude/spec-distill"; mkdir -p "$R2/oldsess0001/docreview/k1"
ledger "$R2/oldsess0001/docreview/k1/docreview-state.md" "$d2" 1
printf 'x\n' > "$R2/oldsess0001/interview-basename"   # 직속 파일 — 옛 세션의 모양(ctime 은 되돌릴 수 없어 빈 폴더 유예 창을 비켜 간다)
age "$R2/oldsess0001"
S2="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$R2" --doc "$d2")"
oi="$(open_at "$r2" "$d2" sess-eeee5555 "$SR")"
assert_eq "$(printf '%s\n' "$oi" | tail -n 1)" "ledger-open: HELD" "A1(i): 옛 원장이 있는 첫 리뷰도 표지를 잡는다"
[ -f "$S2/docreview-state.md" ] && grep -qF "doc: $d2" "$S2/docreview-state.md" \
  && ok "A1(i): 같은 문서의 옛 원장이 .docreview/<키> 로 옮겨졌다(정리가 mkdir · acquire 보다 먼저 돈다)" \
  || no "A1(i): 옛 원장이 옮겨지지 않았다: $oi"
[ -d "$R2/oldsess0001" ] && no "A1(i): 옛 세션 폴더가 남았다" || ok "A1(i): 옮긴 뒤 옛 세션 폴더가 걷혔다"
assert_contains "$oi" "이전 리뷰 라운드 1 에서 이어 간다 — $S2" "A1(i): 옮겨진 원장에서 이어 감 줄이 난다"
assert_not_contains "$oi" "읽지 못한 원장" "A1(i): 막 연 자리가 「읽지 못한 원장」 으로 보고되지 않는다"

# (ii) 같은 세션의 다음 라운드는 정리를 건너뛰고, 다른 세션의 진입은 정리를 부른다
mkdir -p "$R2/.docreview/zz-0000000000000000"
ledger "$R2/.docreview/zz-0000000000000000/docreview-state.md" "$T/nope-design.md" 1
age "$R2/.docreview/zz-0000000000000000"
oii="$(open_at "$r2" "$d2" sess-eeee5555 "$SR")"
assert_eq "$(printf '%s\n' "$oii" | tail -n 1)" "ledger-open: HELD" "A1(ii): 같은 세션의 다음 라운드 — HELD"
[ -d "$R2/.docreview/zz-0000000000000000" ] && ok "A1(ii): 같은 세션의 다음 라운드는 정리를 부르지 않는다(문서 없는 원장이 남는다)" \
  || no "A1(ii): 같은 세션의 다음 라운드에서 정리가 돌았다"
oiii="$(open_at "$r2" "$d2" sess-ffff6666 "$SR")"
assert_eq "$(printf '%s\n' "$oiii" | tail -n 1)" "ledger-open: OTHER:sess-eeee5555" "A1(ii): 다른 세션 — OTHER"
[ -d "$R2/.docreview/zz-0000000000000000" ] && no "A1(ii): 다른 세션의 진입이 정리를 부르지 않았다" \
  || ok "A1(ii): 다른 세션의 진입은 표지 판결 전에 정리를 부른다(문서 없는 원장이 걷혔다)"

# (iii) .docreview 가 밖을 가리키는 링크면 원장 자리를 만들지 않는다
r3="$T/repo3"; mkdir -p "$r3/docs" && git -C "$r3" init -q
d3="$r3/docs/c-design.md"; printf '# C\n' > "$d3"
outside="$T/outside"; mkdir -p "$outside" "$r3/.claude/spec-distill"
ln -s "$outside" "$r3/.claude/spec-distill/.docreview"
for f in "$SR" "$RB"; do
  o="$(open_at "$r3" "$d3" sess-gggg7777 "$f")"
  assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: NO_DIR" "A1(iii): $(basename "$(dirname "$f")") — 링크된 .docreview 면 NO_DIR"
  assert_eq "$(ls -A "$outside")" "" "A1(iii): $(basename "$(dirname "$f")") — 링크 너머 폴더가 비어 있다"
done
# 상태 루트(.claude/spec-distill) 자신이 밖을 가리키는 링크여도 같다
outside2="$T/outside2"; mkdir -p "$outside2"
mv "$r3/.claude/spec-distill" "$T/r3-root-saved"; ln -s "$outside2" "$r3/.claude/spec-distill"
o="$(open_at "$r3" "$d3" sess-gggg7777 "$SR")"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: NO_DIR" "A1(iii): 상태 루트가 링크면 NO_DIR"
assert_eq "$(ls -A "$outside2")" "" "A1(iii): 상태 루트 링크 너머 폴더가 비어 있다"
rm -f "$r3/.claude/spec-distill"; mv "$T/r3-root-saved" "$r3/.claude/spec-distill"
# 양성 대조 — 링크를 걷으면 같은 진입이 표지를 잡는다(위 NO_DIR 이 상시 실패가 아니다)
rm -f "$r3/.claude/spec-distill/.docreview"
o="$(open_at "$r3" "$d3" sess-gggg7777 "$SR")"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: HELD" "A1(iii) 양성 대조: 링크가 없으면 HELD"

# reviewing-brief 원장 열기도 실제로 돈다 — HELD · OTHER
d4="$repo/docs/b-brief.md"; printf '# brief\n' > "$d4"
ob1="$(open_at "$repo" "$d4" sess-aaaa1111 "$RB")"
assert_eq "$(printf '%s\n' "$ob1" | tail -n 1)" "ledger-open: HELD" "AC8: reviewing-brief 원장 열기가 표지를 잡는다"
ob2="$(open_at "$repo" "$d4" sess-bbbb2222 "$RB")"
assert_eq "$(printf '%s\n' "$ob2" | tail -n 1)" "ledger-open: OTHER:sess-aaaa1111" "AC8: reviewing-brief — 남의 표지면 OTHER"
finish
