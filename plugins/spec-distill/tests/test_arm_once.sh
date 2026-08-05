#!/usr/bin/env bash
# T1·T2·T3 — arm-once 게이트 (v0.25.0 §5.1).
#
# 재는 것은 **pending 파일 쓰기 횟수가 아니라 dispatch emit 횟수**다(§10 T1). 두 번째
# 편집이 pending을 덮어쓰는 것은 §5.2가 명시한 의도된 동작이므로 "기록 1회"를 assert하면
# 설계와 모순되는 것을 재게 된다.
set -u -o pipefail
source "$(dirname "$0")/arm_test_helpers.sh"
arm_work_init specdistill-armonce

# --- T1: 리뷰가 완료된 뒤의 편집은 재arm 하지 않는다 (dispatch emit 1회) ---
# mark-reviewed가 시퀀스에 반드시 포함된다 — 그것이 T1(verdict 이후 재arm 없음)과
# T8(verdict 이전 재시도 있음)을 가르는 유일한 사건이다. 빼면 두 락이 같은 상태에
# 반대 결과를 요구해 하나는 반드시 실패한다.
SID1=t1-armonce
REL1="docs/superpowers/specs/2026-08-01-t1-design.md"
new_doc "$REL1"
run_validator "$REL1" "$SID1" >/dev/null
emit1=$(run_stop "$SID1")
run_ledger mark-reviewed "$SID1" "$WORK/$REL1" >/dev/null 2>&1
edit_doc "$REL1" 2
run_validator "$REL1" "$SID1" >/dev/null
emit2=$(run_stop "$SID1")
if echo "$emit1" | jq -e '.decision == "block"' >/dev/null 2>&1 && [[ -z "$emit2" ]]; then
  note PASS "T1: verdict 이후 편집은 재arm 없음 (dispatch emit 1회)"
else
  note FAIL "T1 실패: emit1='$emit1' emit2='$emit2' state=$(cat "$(state_of "$SID1")")"
fi

# --- T2: git이 아는 문서는 armed_paths가 비어 있어도 arm 하지 않는다 ---
SID2=t2-borned
REL2="docs/superpowers/specs/2026-08-01-t2-design.md"
new_doc "$REL2"
( cd "$WORK" && git add "$REL2" && git commit -q -m born ) || exit 1
out2=$(run_validator "$REL2" "$SID2")
sf2="$(state_of "$SID2")"
armed_empty=1
[[ -f "$sf2" ]] && grep -q '^armed_paths:' "$sf2" && armed_empty=0
if [[ $armed_empty -eq 1 ]] \
  && { [[ ! -f "$sf2" ]] || ! grep -q '^pending_review:' "$sf2"; } \
  && echo "$out2" | jq -e '.hookSpecificOutput.additionalContext | contains("git이 아는 문서")' >/dev/null 2>&1; then
  note PASS "T2: git-tracked 문서 → 원장이 비어도 arm 없음 + git 사유 advisory"
else
  note FAIL "T2 실패: out='$out2' state=$( [[ -f "$sf2" ]] && cat "$sf2" || echo '(없음)')"
fi

# --- T3: git 판정 실패는 arm 쪽으로 fail-open **하고** loud 하다 (양방향 락) ---
# 한 방향(arm 발생)만 잠그면 advisory 없이 조용히 arm해도 통과한다.
SID3=t3-nogit
REL3="docs/superpowers/specs/2026-08-01-t3-design.md"
new_doc "$REL3"
mkdir -p "$WORK/fakebin"
printf '#!/bin/sh\nexit 42\n' > "$WORK/fakebin/git"
chmod +x "$WORK/fakebin/git"
all3=$(run_validator_all "$REL3" "$SID3" "PATH=$WORK/fakebin:$PATH")
sf3="$(state_of "$SID3")"
if [[ -f "$sf3" ]] && grep -q '^pending_review:' "$sf3" \
  && grep -q 'exit=42' <<<"$all3"; then
  note PASS "T3: git 불능 → arm 발생(fail-open) + exit code 포함 loud advisory"
else
  note FAIL "T3 실패: out='$all3' state=$( [[ -f "$sf3" ]] && cat "$sf3" || echo '(없음)')"
fi

# --- T13: 원장이 완료라고 말하는 문서는 stale pending 이 남아 있어도 dispatch 하지 않는다 ---
# 재현 경로에 디스크 실패가 필요 없다. skill 은 Step 1(strip-pending)과 Step 3
# (mark-reviewed)을 **분리된 두 bash 블록**으로 실행하고, 둘 다 돌았음을 강제하는 것은
# 아무것도 없다. Step 1 만 빠지면 pending 이 살아남고, 실제 리뷰는 30초 TTL 을 훨씬
# 넘기므로 다음 Stop 이 이미 리뷰된 문서에 block 을 다시 낸다 — 이 릴리스가 없애려는
# 재발동 그 자체다. pending strip 을 유일한 가드로 만든 대가.
#
# 이빨: "emit 없음"만 재면 훅이 죽어도 통과한다(무이빨 no-emit assert). 그래서 **strip
# 되었는지**를 함께 잰다 — 크래시하면 pending 이 그대로 남으므로 이 쪽이 생존 제어다.
SID13=t13-stalepending
REL13="docs/superpowers/specs/2026-08-01-t13-design.md"
new_doc "$REL13"
run_validator "$REL13" "$SID13" >/dev/null
sf13="$(state_of "$SID13")"
# 전제 확인 — pending 이 실제로 깔려 있어야 이 테스트가 무언가를 재는 것이다.
pending_seeded=0
[[ -f "$sf13" ]] && grep -q '^pending_review:' "$sf13" && pending_seeded=1
# skill Step 3 만 실행(Step 1 strip-pending 은 건너뛴 상태) — 원장엔 완료, 디스크엔 pending.
run_ledger mark-reviewed "$SID13" "$WORK/$REL13" >/dev/null 2>&1
emit13=$(run_stop "$SID13")
pending_cleared=0
grep -q '^pending_review:' "$sf13" || pending_cleared=1
armed_still=0
grep -q "$REL13" "$sf13" && armed_still=1
if [[ $pending_seeded -eq 1 && -z "$emit13" && $pending_cleared -eq 1 && $armed_still -eq 1 ]]; then
  note PASS "T13: 원장 완료 문서의 stale pending → dispatch 없음 + pending 정리(훅 생존)"
else
  note FAIL "T13 실패: seeded=$pending_seeded emit='$emit13' cleared=$pending_cleared armed=$armed_still state=$(cat "$sf13")"
fi

# --- T14: reminder(L4b)도 같은 원장 게이트를 지난다 ---
# T13 이 Stop 만 잠그면 형제 소비자 비대칭이 그대로 남는다 — 이 리포가 반복해 겪은
# "한쪽만 고친 수정" 패턴. reminder 는 조언자이므로 strip 하지 않는다: pending 이
# **남아 있어야** 하고(조용해진 것이지 치운 것이 아님), stderr advisory 로 게이트가
# 실제로 돌았음을 증명한다(크래시와 구분).
SID14=t14-reminder
REL14="docs/superpowers/specs/2026-08-01-t14-design.md"
new_doc "$REL14"
run_validator "$REL14" "$SID14" >/dev/null
sf14="$(state_of "$SID14")"
nag_before=$(run_reminder "$SID14")
run_ledger mark-reviewed "$SID14" "$WORK/$REL14" >/dev/null 2>&1
nag_after=$(run_reminder "$SID14")
all14=$(run_reminder_all "$SID14")
pending_kept=0; grep -q '^pending_review:' "$sf14" && pending_kept=1
if [[ -n "$nag_before" && -z "$nag_after" && $pending_kept -eq 1 ]] \
  && grep -q 'nag 생략' <<<"$all14"; then
  note PASS "T14: 원장 완료 문서 → reminder 침묵 + pending 보존 + advisory(게이트 생존)"
else
  note FAIL "T14 실패: before='$nag_before' after='$nag_after' kept=$pending_kept all='$all14'"
fi

# --- T15: 판독 불가 원장이 훅을 죽이지 않는다 (UnicodeDecodeError ⊄ OSError) ---
# `except OSError` 만으로는 이 입력이 traceback 으로 새어 dispatch 가 통째로 사라진다 —
# 리뷰를 *덜* 하는 방향. Python 쪽 보존 테스트는 이 경우에 green 인 채로 프로덕션 훅이
# 죽고 있었다(계층이 달라 서로를 못 본다). 두 훅 모두 rc 0 + 파일 보존이어야 한다.
SID15=t15-undecodable
REL15="docs/superpowers/specs/2026-08-01-t15-design.md"
new_doc "$REL15"
run_validator "$REL15" "$SID15" >/dev/null
sf15="$(state_of "$SID15")"
printf '\xff' >> "$sf15"
# 다이제스트 도구 대신 `cmp` — `md5 -q || md5sum|cut` 는 둘 다 실패하면 양쪽이 빈 문자열이
# 돼 `"" == ""` 로 **어떤 훼손에도** 통과한다(도구 고장이 락을 조용히 무력화).
cp "$sf15" "$WORK/t15.expected" || exit 1
out15=$(run_stop_all "$SID15"); rc15=$?
rout15=$(run_reminder_all "$SID15"); rrc15=$?
preserved15=0; cmp -s "$sf15" "$WORK/t15.expected" && preserved15=1
# 생존 제어 — rc 0 · traceback 없음 · 파일 보존은 **훅이 아무것도 안 해도** 전부 참이다
# (예: exists() 직후 return 0 을 넣는 mutation = dispatch 집행 통째 제거인데도 GREEN).
# 그래서 각 훅이 자기 degrade advisory 를 실제로 냈는지를 스트림별로 따로 잰다.
# 앵커는 ASCII sentinel 이다 — json.dumps 는 기본 ensure_ascii=True 라 한국어가
# \uXXXX 로 이스케이프돼 한국어 grep 은 절대 매치하지 않는다(계측기 고장).
# 두 sentinel 은 서로의 부분문자열이 아니다 — stderr 쪽("state read failed" ⊂ "reminder
# state read failed")을 쓰면 reminder 하나로 양쪽 assert 가 만족돼 이빨이 사라진다.
stop_spoke=0; grep -q 'arm-once:state-unreadable'    <<<"$out15"  && stop_spoke=1
rem_spoke=0;  grep -q 'arm-once:reminder-unreadable' <<<"$rout15" && rem_spoke=1
if [[ $rc15 -eq 0 && $rrc15 -eq 0 && $preserved15 -eq 1 \
      && $stop_spoke -eq 1 && $rem_spoke -eq 1 ]] \
  && ! grep -q 'Traceback' <<<"$out15$rout15"; then
  note PASS "T15: 판독 불가 원장 → 두 훅 rc 0 + 각자 loud advisory + 파일 보존"
else
  note FAIL "T15 실패: stop_rc=$rc15 rem_rc=$rrc15 preserved=$preserved15 stop_spoke=$stop_spoke rem_spoke=$rem_spoke out='$out15$rout15'"
fi

# --- T16: 개행이 든 file_path 는 원장을 위조하지 못한다 (writer 에서 차단) ---
# 상태 파일은 0-indent 블록으로 파싱되는 마크다운이라, 경로가 그대로 보간되면
# `armed_paths:` 를 위조해 **다른 문서**의 리뷰를 영구 억제할 수 있다.
# 락을 writer(validator)에 건다 — reader 마다 걸러내면 새 reader 가 생길 때마다
# 두더지잡기가 된다. canonical_key 쪽 거부는 python 유닛이 따로 잠근다.
SID16=t16-injection
REL16="docs/superpowers/specs/2026-08-01-t16-design.md"
VICTIM="docs/superpowers/specs/2026-08-01-victim-design.md"
new_doc "$REL16"
# 정상 편집으로 세션 상태를 먼저 만든다(위조 대상이 존재해야 의미가 있다).
run_validator "$REL16" "$SID16" >/dev/null
sf16="$(state_of "$SID16")"
# 위조 시도: file_path 안에 개행 + armed_paths 블록.
forged=$(printf '%s/docs/superpowers/specs/a\\narmed_paths:\\n  - %s\\nx-design.md' "$WORK" "$VICTIM")
payload=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$forged")
( cd "$WORK" && env DEVBREW_SPEC_DISTILL_SESSION_ID="$SID16" \
    bash -c "echo '$payload' | python3 '$VALIDATOR'" ) >/dev/null 2>&1
victim_armed=0; grep -qF "$VICTIM" "$sf16" && victim_armed=1
# 생존 제어 — 상태 파일이 여전히 정상이어야 한다(훅이 죽어서 통과하는 것과 구분).
state_ok=0; grep -q '^pending_review:' "$sf16" && state_ok=1
if [[ $victim_armed -eq 0 && $state_ok -eq 1 ]]; then
  note PASS "T16: 개행 든 file_path 가 armed_paths 를 위조하지 못한다 (상태 정상 유지)"
else
  note FAIL "T16 실패: victim_armed=$victim_armed state_ok=$state_ok state=$(cat "$sf16")"
fi

# --- T17: UTF-8 stdio 고정이 한국어 진단 출력을 지킨다 ---
# 이 릴리스가 세 훅에 넣은 `sys.std*.reconfigure(encoding="utf-8")` 은 커버리지가 0
# 이었다 — 세 곳 모두에서 지워도 전 스위트가 GREEN 이었다.
#
# **계측 주의(이 락을 만들며 실제로 겪은 것).** 코드 주석과 리뷰는 트리거를
# `LC_ALL=C` 라고 지목하지만, macOS 의 CPython 은 C 로케일에서도 stdio 를 UTF-8 로
# 강제하므로(PEP 538 coercion + 플랫폼 특수 처리) `LC_ALL=C` 로는 **핀을 통째로
# 제거해도 아무 차이가 없다**(측정: 4개 로케일 조합 × 핀 유무 = 8회 전부 동일).
# 그걸 모르고 `LC_ALL=C` 락을 넣었다면 핀이 사라져도 영원히 GREEN 인 가짜 락이 된다.
# 실제로 효과가 갈리는 축은 `PYTHONIOENCODING` 이다.
#
# 무엇을 재는가: 제어문자 경로 거부는 **한국어** stderr 진단을 낸다. 핀이 없으면
# 그 진단이 ascii 로 인코딩되며 소실돼, 사용자는 왜 리뷰가 안 붙었는지 알 수 없다
# (CLAUDE.md: graceful degradation 은 loud logging 을 동반해야 한다).
SID17=t17-stdio
mkdir -p "$WORK/docs/superpowers/specs"
pay17=$(python3 -c "import json;print(json.dumps({'tool_name':'Edit','tool_input':{'file_path':'docs/superpowers/specs/a\nb-design.md'}}))")
err17=$( cd "$WORK" && printf '%s' "$pay17" \
  | env PYTHONIOENCODING=ascii DEVBREW_SPEC_DISTILL_SESSION_ID="$SID17" \
        CLAUDE_PROJECT_DIR="$WORK" python3 "$VALIDATOR" 2>&1 >/dev/null )
# 앵커는 **어느 가드가 처리했는지와 무관한** 문구여야 한다. '제어문자' 로 잡으면 인코딩
# 주장이 가드 선택에 묶여, `unkeyable` 가드를 지웠을 때 T17 이 RED 를 내면서 "stdio 고정
# 없음" 이라고 **거짓 진단**을 한다 — 핀은 멀쩡하고 다른 가드가 다른 문구로 처리했을 뿐이다.
# '자동 리뷰가 붙지 않는다' 는 두 가드의 메시지에 공통이라 두 성질을 분리한다.
if grep -q '자동 리뷰가 붙지 않는다' <<<"$err17"; then
  note PASS "T17: PYTHONIOENCODING=ascii 에서도 한국어 진단이 보존된다 (stdio 고정)"
else
  note FAIL "T17 실패: 한국어 진단 소실 — stdio 고정 없음. err=$(head -c 160 <<<"$err17")"
fi

# --- T18: 기록 실패는 성공 advisory 로 새지 않는다 (arm-skip 라우팅) ---
# iteration-1 이 CRITICAL 로 잡은 결함: pending 이 기록되지 않았는데도 모델에게
# "Reviewer will be dispatched at turn end" 를 약속한다. 수정은 넣었지만 **락이 없어**
# 라우팅 블록을 통째로 지워도 전 스위트가 GREEN 이었다(측정).
#
# 두 축을 함께 잰다 — stdout 에 arm-skip 이 **있고**, 성공 문구가 **없다**. 앞의 것만
# 재면 두 JSON 이 다 나가는 회귀를 못 잡고, 뒤의 것만 재면 훅이 조용히 죽어도 통과한다.
#
# 구동 방식: `worktree_path` 는 `os.getcwd()` 이고 POSIX 는 디렉토리명에 개행을 허용한다.
# 개행이 든 cwd 에서 훅을 돌리면 완성된 pending 블록의 줄 수가 5 를 넘어 기록이 거부된다
# — 이것이 `worktree_path` 를 통한 `armed_paths` 위조를 막는 유일한 층이다.
T18DIR="$WORK/$(printf 'wt\narmed_paths:\n  - docs/superpowers/specs/2026-08-01-victim-design.md\nx')"
if mkdir -p "$T18DIR/docs/superpowers/specs" 2>/dev/null; then
  ( cd "$T18DIR" && git init -q . && printf '# t\n' > docs/superpowers/specs/2026-08-03-t18-design.md )
  pay18='{"tool_name":"Edit","tool_input":{"file_path":"docs/superpowers/specs/2026-08-03-t18-design.md"}}'
  out18=$( cd "$T18DIR" && printf '%s' "$pay18" \
    | env DEVBREW_SPEC_DISTILL_SESSION_ID=t18-route CLAUDE_PROJECT_DIR="$T18DIR" \
          python3 "$VALIDATOR" 2>/dev/null )
  sf18="$T18DIR/.claude/spec-distill/t18-route/state.local.md"
  if grep -q 'arm skipped' <<<"$out18" \
    && ! grep -q 'Reviewer will be dispatched' <<<"$out18" \
    && [[ ! -f "$sf18" ]]; then
    note PASS "T18: 개행 든 worktree_path → arm-skip advisory, 성공 문구 없음, pending 미기록"
  else
    note FAIL "T18 실패: state=$([[ -f "$sf18" ]] && echo EXISTS || echo none) out=$(head -c 200 <<<"$out18")"
  fi
else
  note FAIL "T18 실패: 개행 든 디렉토리를 만들 수 없어 검사가 실행되지 않았다(조용한 skip 금지)"
fi

# --- T19: 세션 id 미해석도 성공 advisory 로 새지 않는다 ---
# T18 과 같은 클래스의 **다른 분기**다. 이 라운드에 write 실패 분기만 고치고 세 줄 위의
# 주소-해석 분기를 놔뒀다가 재리뷰에서 적발됐다 — 인스턴스가 아니라 클래스를 잠근다.
# sid 미해석은 이 리포에 열려 있는 실제 이슈다(훅 payload sid vs 스킬 env sid 분기).
REL19="docs/superpowers/specs/2026-08-03-t19-design.md"
new_doc "$REL19"
pay19=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$WORK/$REL19")
# **두 env 를 모두 지워야 한다.** resolve_session_id 의 우선순위는
# DEVBREW_SPEC_DISTILL_SESSION_ID → CLAUDE_CODE_SESSION_ID → payload 이고, 후자는 실제
# 하니스가 설정한다. 하나만 지우면 sid 가 정상 해석돼 이 테스트는 자기가 재려는 분기에
# 닿지도 못한 채 "성공 advisory 가 나왔다" 며 실패한다(초안에서 실제로 그랬다).
out19=$( cd "$WORK" && printf '%s' "$pay19" \
  | env -u DEVBREW_SPEC_DISTILL_SESSION_ID -u CLAUDE_CODE_SESSION_ID \
        CLAUDE_PROJECT_DIR="$WORK" python3 "$VALIDATOR" 2>/dev/null )
if grep -q 'arm skipped' <<<"$out19" && ! grep -q 'Reviewer will be dispatched' <<<"$out19"; then
  note PASS "T19: session_id 미해석 → arm-skip advisory, 성공 문구 없음"
else
  note FAIL "T19 실패: out=$(head -c 200 <<<"$out19")"
fi

arm_summary
