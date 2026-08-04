#!/usr/bin/env bash
# AC7b·AC7c — web kill switch가 두 소비자 각각에 인라인으로 살아 있다.
#
# 왜 소비자별로 나누는가: v0.24.12가 web_budget.py를 지우면서 kill switch 구현을
# 두 소비자로 이전했다. 한 파일에 대한 assert가 다른 파일을 덮으면, 한쪽에서
# 스위치가 사라져도 GREEN이 난다 — 스위치가 거짓말을 하는 상태다.
#
# 계약(설계 §6 S3d): 정확히 문자열 "1"만 참. 미설정 = 웹 활성. 평가는 각 웹 작업 직전.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
pass=0; fail=0
note() { if [[ "$1" == PASS ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# ── 소비자 목록은 **열거하지 않고 도출한다** ────────────────────────────────
# 원래 이 루프는 두 SKILL을 하드코딩했다. 그래서 `scripts/run_brief_codex_reviewer.sh`
# 가 같은 스위치를 독립 확인하는 **세 번째 소비자**인데도 커버리지가 0이었다 —
# 거기 스위치를 `if false`로 죽여도 이 락과 test_brief_codex_axes.sh 둘 다 GREEN이었다
# (2026-08-04 /qg 라운드 1, mutation 확인). 열거는 공간에도 시간에도 fail-open이다.
#
# 도출 기준은 "스위치를 언급하는가"가 **아니다** — 그건 순환이다(스위치를 지우면
# 목록에서도 사라져 GREEN이 난다). 기준은 **웹에 도달할 수 있는가**이다:
#   (a) codex 웹 검색을 켜는 스크립트  → 스스로 확인해야 한다
#   (b) 웹 도구를 가진 agent를 dispatch하는 skill → orchestrator가 확인해야 한다
#       (agent는 `tools:`에 Bash가 없어 자기 스위치를 볼 수 없다 — Law 2)
CHECK='^[[:space:]]*if \[\[ "\$\{DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0\}" == "1" \]\]'

web_agents="$(grep -lE '^tools:.*Web(Search|Fetch)' "$SD"/agents/*.md 2>/dev/null \
              | while IFS= read -r a; do basename "$a" .md; done)"
if [[ -n "$web_agents" ]]; then
  note PASS "도출: 웹 도구 보유 agent $(echo "$web_agents" | wc -l | tr -d ' ')개 식별"
else
  note FAIL "도출: 웹 도구 보유 agent를 하나도 못 찾았다 — 도출 기준이 깨졌다(아래 결과 무의미)"
fi

# (a) codex 웹 검색을 켜는 스크립트
web_scripts="$(grep -lE 'tools\.web_search' "$SD"/scripts/*.sh 2>/dev/null || true)"
if [[ -z "$web_scripts" ]]; then
  note FAIL "도출: codex 웹을 켜는 스크립트를 못 찾았다 — 도출 기준이 깨졌다"
else
  for f in $web_scripts; do
    grep -qE "$CHECK" "$f" \
      && note PASS "$(basename "$f"): kill switch 확인 실재" \
      || note FAIL "$(basename "$f"): 웹을 켜면서 kill switch를 확인하지 않는다"
  done
fi

# (b) 웹 도구 agent를 dispatch하는 skill
#
# 앵커를 **피검자 손에서 뺏는다** (2026-08-05 /qg 라운드 2, adversarial meta_note):
#   예전 판정은 `grep -q "spec-distill:$a"` 였다. 그러면 접두사 없이
#   `subagent_type: "spec-reviewer"` 로 쓴 저자는 **자기 skill을 감사 대상에서
#   스스로 빼낸다** — 검사받는 파일이 자기가 검사받을지를 결정하는 구조다.
#   실제로 reviewing-spec이 그렇게 통째로 누락됐고, 그 사이 이 브랜치가
#   spec-reviewer에 WebSearch를 부여했다. 도구 권한은 Law 2로 나눠도 **감사 범위**가
#   피검자에게 있으면 소용없다. 그래서 접두사를 선택적으로 만든다.
#
# 그리고 존재 검사를 **지배 관계**로 바꾼다:
#   예전엔 "이 파일 어딘가에 CHECK가 있다"였다. 그 명제는 dispatch가 열 개여도
#   가드가 하나면 참이다 — conducting-interview가 정확히 그 상태였다(R2 블록 하나가
#   coverage-mapper dispatch까지 '덮는' 것처럼 보였다). 이제 각 dispatch 지점마다
#   그 **위쪽 WINDOW줄 안에** 스위치 확인이 있어야 한다.
GUARD_WINDOW=40
for sk in "$SD"/skills/*/SKILL.md; do
  [[ -f "$sk" ]] || continue
  name="$(basename "$(dirname "$sk")")"

  # 이 skill이 dispatch하는 web agent의 줄번호를 전부 모은다(접두사 선택적).
  dispatch_lines=""
  for a in $web_agents; do
    ls="$(grep -nE "subagent_type:[[:space:]]*\"(spec-distill:)?${a}\"" "$sk" | cut -d: -f1 || true)"
    [[ -n "$ls" ]] && dispatch_lines="$dispatch_lines $ls"
  done
  [[ -n "${dispatch_lines// /}" ]] || continue

  # 스위치가 확인되는 줄번호(그 형태가 무엇이든 — bash 블록이든 산문이든).
  guard_lines="$(grep -n 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' "$sk" | cut -d: -f1 || true)"

  unguarded=""
  for d in $dispatch_lines; do
    nearest=-1
    for g in $guard_lines; do
      [[ "$g" -le "$d" && "$g" -gt "$nearest" ]] && nearest="$g"
    done
    if [[ "$nearest" -lt 0 || $((d - nearest)) -gt "$GUARD_WINDOW" ]]; then
      unguarded="$unguarded $d"
    fi
  done
  if [[ -z "${unguarded// /}" ]]; then
    note PASS "$name: web agent dispatch $(echo $dispatch_lines | wc -w | tr -d ' ')곳 전부가 스위치 확인 아래에 있다"
  else
    note FAIL "$name: 스위치 확인 없는 web agent dispatch — 줄$unguarded (위 ${GUARD_WINDOW}줄 내 확인 부재)"
  fi

  grep -qE "$CHECK" "$sk" \
    && note PASS "$name: 실행 가능한 스위치 확인 블록 실재" \
    || note FAIL "$name: 스위치 확인이 실행 가능한 형태가 아니다(산문만으로는 집행되지 않는다)"
  grep -qE 'DEVBREW_SPEC_DISTILL_DISABLE_WEB.*(true|yes|-n |!= *"")' "$sk" \
    && note FAIL "$name: 느슨한 참 판정 — 계약은 정확히 \"1\"이다" \
    || note PASS "$name: 참 판정이 \"1\" 한정"
  grep -qE 'web_budget|SWEEP_CAP|SESSION_CAP' "$sk" \
    && note FAIL "$name: 상한 게이트 재도입" \
    || note PASS "$name: 상한 게이트 없음"
done

# ── 스위치가 **소비되는가** (선언만으로는 부족하다) ──────────────────────────
# reviewing-brief의 확인 블록은 `web_disabled` 변수를 세팅만 한다. 그 변수를 읽는
# 두 bullet과 dispatch 프롬프트 문구를 전부 지워도 두 락이 GREEN이었다 — 죽은
# 스위치가 산 것으로 읽혔다(mutation M12). 선언이 아니라 소비를 앵커한다.
RB="$SD/skills/reviewing-brief/SKILL.md"
if [[ -f "$RB" ]]; then
  reads="$(grep -cE 'web_disabled[[:space:]]*==[[:space:]]*1|web_disabled[[:space:]]*==[[:space:]]*0' "$RB" 2>/dev/null || echo 0)"
  if [[ "$reads" -ge 1 ]]; then
    note PASS "reviewing-brief: web_disabled가 실제로 **읽히는** 분기가 있다"
  else
    note FAIL "reviewing-brief: web_disabled를 세팅만 하고 아무도 읽지 않는다 (죽은 스위치)"
  fi
  grep -qE 'kill switch 활성' "$RB" \
    && note PASS "reviewing-brief: dispatch 프롬프트에 web-disabled 조건이 실린다" \
    || note FAIL "reviewing-brief: dispatch 프롬프트에서 web-disabled 조건이 사라졌다"
fi

# production 전역 — 스크립트와 카운터가 실제로 사라졌다(AC7a).
# tests/·CHANGELOG는 제외: 전자는 부재를 assert하는 층이고 후자는 이력이다(C2).
leftover="$(grep -rln 'web_budget\|web_sweep_count\|web_search_count' "$SD" \
  --exclude-dir=tests --exclude=CHANGELOG.md 2>/dev/null || true)"
if [[ -z "$leftover" ]]; then
  note PASS "AC7a: production에 web_budget/카운터 잔존 0"
else
  note FAIL "AC7a: production 잔존:"; printf '    %s\n' $leftover
fi

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
