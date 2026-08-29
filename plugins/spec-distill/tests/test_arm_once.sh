#!/usr/bin/env bash
# arm-once 게이트 (v0.25.0 §5.1) — Stop 훅 e2e.
#
# 재는 것은 **상태 파일 write 횟수가 아니라 dispatch emit 횟수**다(§10 T1).
# 연료는 발견(git 의 dirty 집합)이므로 케이스는 문서를 만들고 Stop 을 돌린다.
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
emit1=$(run_stop "$SID1")
run_ledger mark-reviewed "$SID1" "$WORK/$REL1" >/dev/null 2>&1
edit_doc "$REL1" 2
emit2=$(run_stop "$SID1")
if echo "$emit1" | jq -e '.decision == "block"' >/dev/null 2>&1 && [[ -z "$emit2" ]]; then
  note PASS "T1: verdict 이후 편집은 재arm 없음 (dispatch emit 1회)"
else
  note FAIL "T1 실패: emit1='$emit1' emit2='$emit2' state=$(cat "$(state_of "$SID1")")"
fi

# --- T2: git이 아는 문서는 armed_paths가 비어 있어도 dispatch 하지 않는다 ---
# `is_born` 은 "저자가 리포에 넣기로 결정했다" 는 뜻이고, 그 판정은 세션 원장과
# **독립**이다 — 원장이 완전히 비어 있어도 born 문서는 발동하지 않아야 한다.
#
# **커밋 뒤에 편집한다.** 커밋만 하면 그 문서는 dirty 가 아니라 발견 목록에 아예
# 오르지 않고, 그러면 이 케이스는 born 축을 재지 못한 채 통과한다(측정 확인:
# 그 모양에서는 `if c.born: continue` 를 지워도 GREEN 이었다). born 이면서 동시에
# 후보인 유일한 상태가 "커밋됨 + 그 뒤 수정됨" 이다.
#
# 이빨: "emit 없음"만 재면 훅이 죽어도 통과한다(무이빨 no-emit assert). 그래서 같은
# 세션에 **미커밋 문서 하나**를 함께 둔다 — 살아 있는 훅은 같은 턴에 그쪽을 고른다.
# 침묵이 born 축 때문임을 그것이 증명한다(생존 제어). born 문서가 정렬상 앞이므로,
# 제외된 첫 후보가 뒤의 적격 후보를 가리지 않는다는 것도 함께 잠긴다.
SID2=t2-borned
REL2="docs/superpowers/specs/2026-08-01-t2a-design.md"
REL2B="docs/superpowers/specs/2026-08-01-t2b-design.md"
new_doc "$REL2"
( cd "$WORK" && git add "$REL2" && git commit -q -m born ) || exit 1
edit_doc "$REL2" born-then-edited
# 두 번째 문서는 new_doc 을 쓰지 않는다 — 그 헬퍼는 앞 문서를 커밋해 발견에서 뺀다.
cp "$FIX/2026-05-17-test-design.md" "$WORK/$REL2B"
emit2c=$(run_stop "$SID2")
sf2="$(state_of "$SID2")"
armed_empty=1
[[ -f "$sf2" ]] && grep -q '^armed_paths:' "$sf2" && armed_empty=0
if [[ $armed_empty -eq 1 ]] \
  && echo "$emit2c" | jq -e --arg p "$REL2B" '.reason | contains($p)' >/dev/null 2>&1 \
  && ! echo "$emit2c" | jq -e --arg p "$REL2" '.reason | contains($p)' >/dev/null 2>&1; then
  note PASS "T2: git-tracked 문서 → 원장이 비어도 무-dispatch (옆 미커밋 문서는 정상 dispatch)"
else
  note FAIL "T2 실패: emit='$emit2c' armed_empty=$armed_empty state=$( [[ -f "$sf2" ]] && cat "$sf2" || echo '(없음)')"
fi

# --- T13: 원장이 완료라고 말하는 문서는 여전히 dirty 해도 dispatch 하지 않는다 ---
# 연료가 발견으로 바뀌어도 이 성질은 그대로다. 오히려 시험이 세졌다: 예전에는 리뷰가
# 끝나면 연료가 사라졌지만, 지금 그 문서는 커밋하기 전까지 **매 턴 다시 발견된다.**
# 원장의 완료 기록만이 그것을 막는다.
#
# 이빨: T2 와 같은 생존 제어 — 같은 세션에 미리뷰 문서 하나를 함께 둔다. 이 두
# 케이스가 **다른 축**(원장 vs git)으로 같은 침묵을 요구하므로 둘 다 필요하다.
SID13=t13-armed-veto
REL13="docs/superpowers/specs/2026-08-01-t13-design.md"
REL13B="docs/superpowers/specs/2026-08-01-t13b-design.md"
new_doc "$REL13"
cp "$FIX/2026-05-17-test-design.md" "$WORK/$REL13B"
run_ledger mark-reviewed "$SID13" "$WORK/$REL13" >/dev/null 2>&1
emit13=$(run_stop "$SID13")
sf13="$(state_of "$SID13")"
armed_still=0
grep -q "^  - $REL13\$" "$sf13" && armed_still=1
if [[ $armed_still -eq 1 ]] \
  && echo "$emit13" | jq -e --arg p "$REL13B" '.reason | contains($p)' >/dev/null 2>&1 \
  && ! echo "$emit13" | jq -e --arg p "$REL13" '.reason | contains($p)' >/dev/null 2>&1; then
  note PASS "T13: 원장 완료 문서 → 여전히 dirty 해도 무-dispatch (옆 문서는 정상 dispatch)"
else
  note FAIL "T13 실패: emit='$emit13' armed=$armed_still state=$(cat "$sf13")"
fi

# --- T15: 판독 불가 원장이 훅을 죽이지 않는다 (UnicodeDecodeError ⊄ OSError) ---
# `except OSError` 만으로는 이 입력이 traceback 으로 새어 dispatch 가 통째로 사라진다 —
# 리뷰를 *덜* 하는 방향. Python 쪽 보존 테스트는 이 경우에 green 인 채로 프로덕션 훅이
# 죽고 있었다(계층이 달라 서로를 못 본다). rc 0 + 파일 보존이어야 한다.
SID15=t15-undecodable
REL15="docs/superpowers/specs/2026-08-01-t15-design.md"
new_doc "$REL15"
run_stop "$SID15" >/dev/null          # 상태 파일을 만든다 (발동 대상이 있어야 한다)
sf15="$(state_of "$SID15")"
printf '\xff' >> "$sf15"
# 다이제스트 도구 대신 `cmp` — `md5 -q || md5sum|cut` 는 둘 다 실패하면 양쪽이 빈 문자열이
# 돼 `"" == ""` 로 **어떤 훼손에도** 통과한다(도구 고장이 락을 조용히 무력화).
cp "$sf15" "$WORK/t15.expected" || exit 1
out15=$(run_stop_all "$SID15"); rc15=$?
preserved15=0; cmp -s "$sf15" "$WORK/t15.expected" && preserved15=1
# 생존 제어 — rc 0 · traceback 없음 · 파일 보존은 **훅이 아무것도 안 해도** 전부 참이다
# (예: exists() 직후 return 0 을 넣는 mutation = dispatch 집행 통째 제거인데도 GREEN).
# 그래서 훅이 자기 degrade advisory 를 실제로 냈는지를 함께 잰다. 앵커는 ASCII
# sentinel 이다 — json.dumps 는 기본 ensure_ascii=True 라 한국어가 \uXXXX 로
# 이스케이프돼 한국어 grep 은 절대 매치하지 않는다(계측기 고장).
stop_spoke=0; grep -q 'arm-once:state-unreadable' <<<"$out15" && stop_spoke=1
if [[ $rc15 -eq 0 && $preserved15 -eq 1 && $stop_spoke -eq 1 ]] \
  && ! grep -q 'Traceback' <<<"$out15"; then
  note PASS "T15: 판독 불가 원장 → Stop rc 0 + loud advisory + 파일 보존"
else
  note FAIL "T15 실패: rc=$rc15 preserved=$preserved15 spoke=$stop_spoke out='$out15'"
fi

# --- T17: UTF-8 stdio 고정이 한국어 진단 출력을 지킨다 ---
# 이 핀(`configure_utf8_streams()`)은 커버리지가 0 이었다 — 지워도 전 스위트가
# GREEN 이었다.
#
# **계측 주의(이 락을 만들며 실제로 겪은 것).** 트리거를 `LC_ALL=C` 로 잡으면 안 된다:
# macOS 의 CPython 은 C 로케일에서도 stdio 를 UTF-8 로 강제하므로(PEP 538 coercion +
# 플랫폼 특수 처리) `LC_ALL=C` 로는 **핀을 통째로 제거해도 아무 차이가 없다**.
# 실제로 효과가 갈리는 축은 `PYTHONIOENCODING` 이다.
#
# 무엇을 재는가: git 불능은 **한국어** stderr 진단을 낸다. 핀이 없으면 그 진단이
# `\uXXXX` 로 이스케이프돼 사람이 읽을 수 없게 된다(측정: 핀 제거 → Hangul 0건).
# 앵커는 **어느 가드가 처리했는지와 무관하게** "한글이 살아 있는가" 하나다 — 특정
# 문구로 잡으면 그 가드를 건드린 무관한 변경이 "stdio 고정 없음" 이라고 거짓 진단을
# 한다. 짝이 되는 생존 제어는 ASCII sentinel `[spec-distill]` 이다(핀이 없어도 남으므로
# 훅이 죽은 것과 구분된다).
SID17=t17-stdio-lock
REL17="docs/superpowers/specs/2026-08-01-t17-design.md"
new_doc "$REL17"
mkdir -p "$WORK/fakebin"
printf '#!/bin/sh\nexit 42\n' > "$WORK/fakebin/git"
chmod +x "$WORK/fakebin/git"
err17=$( cd "$WORK" && echo '{}' \
  | env PATH="$WORK/fakebin:$PATH" PYTHONIOENCODING=ascii \
        DEVBREW_SPEC_DISTILL_SESSION_ID="$SID17" \
        DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=0 \
        python3 "$DISPATCH" 2>&1 >/dev/null )
alive17=0; grep -q '\[spec-distill\]' <<<"$err17" && alive17=1
hangul17=0; grep -q '[가-힣]' <<<"$err17" && hangul17=1
if [[ $alive17 -eq 1 && $hangul17 -eq 1 ]]; then
  note PASS "T17: PYTHONIOENCODING=ascii 에서도 한국어 진단이 보존된다 (stdio 고정)"
else
  note FAIL "T17 실패: alive=$alive17 hangul=$hangul17 (0이면 stdio 고정 없음). err=$(head -c 200 <<<"$err17")"
fi

arm_summary
