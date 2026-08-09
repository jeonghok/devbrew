#!/usr/bin/env bash
# AC7b·AC7c·AC21 — web kill switch가 소비자 각각에 인라인으로 살아 있고, 어느
# codex 호출부가 웹 ON/OFF여야 하는지(AC21 표)가 값 단위로 지켜진다.
#
# 왜 소비자별로 나누는가: v0.24.12가 web_budget.py를 지우면서 kill switch 구현을
# 두 소비자로 이전했다. 한 파일에 대한 assert가 다른 파일을 덮으면, 한쪽에서
# 스위치가 사라져도 GREEN이 난다 — 스위치가 거짓말을 하는 상태다.
#
# 왜 플러그인 횡단 + 값 인식인가 (AC21, Task 18): 코퍼스가 spec-distill 한 플러그인
# 이었을 때는 quality-gates·plugin-audit에 새 codex 호출부가 생겨도 이 락이 보지
# 못했다. 그리고 술어가 존재만 봤을 때는 `tools.web_search=true`를 `false`로 값만
# 바꿔도(웹을 꺼도) 도출 집합에서 조용히 빠져나가 통과했다 — 그래서 아래 (a)는
# 플러그인 횡단으로 도출하고, (a-값)은 AC21 표 대비 실제 값을 양방향으로 대조한다.
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

# (a) codex 웹 검색을 **켜는** 스크립트. 플러그인 횡단으로 도출한다.
#
# 두 가지를 고친다:
#   1. 코퍼스가 `$SD/scripts/*.sh` 한 플러그인이었다 — quality-gates·plugin-audit에
#      새 호출부를 만들면 아무 락도 보지 못했다. 열거는 공간에도 시간에도 fail-open이다.
#   2. 술어가 **값을 보지 않았다**. `tools.web_search=false`를 명시하는 순간 웹을 *끄는*
#      호출부가 도출 집합에 들어와 kill switch 확인을 요구받았고, 그것은 죽은 스위치를
#      만들라는 요구다. 이제 **켜는** 것만 요구한다.
#
# kill switch 변수명은 플러그인마다 다르므로 그 축은 파라미터다.
WEB_ON='tools\.web_search[[:space:]]*=[[:space:]]*.?true'
# 주석 줄(선행 공백 후 `#`)은 실행되지 않는다 — 값 판정은 실행되는 코드에서만 해야
# 한다. 이 함수 없이 파일 전체를 grep하면, "`tools.web_search=true` 단독은 codex
# 기본 모드..." 같은 **설명 주석**이 실제 코드를 `false`로 되돌려도 매치를 만족시켜
# 값 검사가 무이빨이 된다 — 이 파일 자신의 초안이 바로 그 실패를 냈다(m27 회귀,
# 2026-08-09 mutation 확인: run_spec_codex_reviewer.sh의 두 분기를 전부 `false`로
# 바꿨는데도 자신의 설명 주석이 "실제 ON 일치"를 GREEN으로 냈다).
web_true_in_code() {  # <file> -> exit 0 if 주석이 아닌 실행 코드가 tools.web_search=true를 설정
  grep -vE '^[[:space:]]*#' "$1" 2>/dev/null | grep -qE "$WEB_ON"
}
declare -a WEB_ROOTS=("$REPO_ROOT/plugins/spec-distill" "$REPO_ROOT/plugins/quality-gates" "$REPO_ROOT/plugins/plugin-audit")
switch_for() {
  case "$1" in
    */spec-distill/*) echo 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' ;;
    */quality-gates/*) echo 'DEVBREW_DISABLE_QG_WEB' ;;
    */plugin-audit/*) echo 'DEVBREW_DISABLE_PLUGIN_AUDIT_WEB' ;;
    *) echo '' ;;
  esac
}

web_on_scripts=""
for r in "${WEB_ROOTS[@]}"; do
  for cand in "$r"/scripts/*.sh; do
    [ -f "$cand" ] || continue
    web_true_in_code "$cand" && web_on_scripts="$web_on_scripts
$cand"
  done
done
web_on_scripts="$(printf '%s\n' "$web_on_scripts" | grep -v '^$' || true)"

if [[ -z "$web_on_scripts" ]]; then
  note FAIL "도출: codex 웹을 켜는 스크립트를 하나도 못 찾았다 — 도출 기준이 깨졌다"
else
  note PASS "도출: 웹을 켜는 스크립트 $(printf '%s\n' "$web_on_scripts" | wc -l | tr -d ' ')개 (플러그인 횡단)"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    sw="$(switch_for "$f")"
    if [[ -z "$sw" ]]; then
      note FAIL "$(basename "$f"): 어느 플러그인인지 판정 불가 — kill switch 변수를 특정할 수 없다"
      continue
    fi
    grep -qE "^[[:space:]]*if \[\[ \"\\\$\{$sw:-0\}\" == \"1\" \]\]" "$f" \
      && note PASS "$(basename "$f"): $sw 확인 실재" \
      || note FAIL "$(basename "$f"): 웹을 켜면서 $sw 를 확인하지 않는다"
  done <<EOF
$web_on_scripts
EOF
fi

# 웹을 **끄는** 호출부에는 스위치를 요구하지 않는다 — 죽은 스위치를 만들지 않기 위해서다.
# 대신 posture가 **명시**돼 있는지는 확인한다: 미지정은 codex 기본값(cached)에 맡기는
# 것이라 "이 호출부는 웹을 쓰지 않는다"가 어디에도 적혀 있지 않게 된다.
codex_runners="$(grep -rlE '(^|[[:space:]])codex[[:space:]]+exec[[:space:]]' \
                 "$REPO_ROOT"/plugins/*/scripts/*.sh "$REPO_ROOT"/plugins/*/tests/spike/*.sh 2>/dev/null || true)"
missing_posture=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  grep -qE 'tools\.web_search' "$f" || missing_posture="$missing_posture $(basename "$f")"
done <<EOF
$codex_runners
EOF
if [[ -z "${missing_posture// /}" ]]; then
  note PASS "codex 호출부 전부가 웹 posture를 명시한다 (미지정 = 기본값 cached에 맡김 방지)"
else
  note FAIL "웹 posture 미명시 →$missing_posture"
fi

# ── (a-값) AC21 표 — 호출부별 기대 posture를 양방향으로 대조한다 ────────────
# 위 web_on_scripts 도출은 **존재**만 잰다 — `tools.web_search`를 true→false로
# 값만 바꾸면 도출 집합에서 조용히 빠져나가고, kill switch 확인 요구도 함께
# 빠진다(웹 ON이어야 할 호출부를 끄는 회귀가 무이빨로 통과한다). 어느 호출부가
# 웹 ON이어야 하는지는 코드에서 도출할 수 없는 의미론적 판단이라 표가 불가피하다
# (AC21) — 그래서 표의 기대값과 실제 값을 **양방향**으로 대조한다:
#   - ON이어야 하는데 실제로 아니면 RED
#   - OFF여야 하는데 실제로 켜져 있으면 RED (반대 방향도 문다)
#   - 표에 없는 codex 호출부가 나타나면 RED (표가 조용히 낡는 것을 막는다)
expected_posture() {  # <basename> -> on|off|"" (표에 없음)
  case "$1" in
    run_codex_reviewer.sh) echo off ;;
    run_artifact_codex_reviewer.sh) echo off ;;
    run_spec_codex_reviewer.sh) echo on ;;
    run_brief_codex_reviewer.sh) echo on ;;
    run_audit_codex_reviewer.sh) echo on ;;
    test_codex_json_extraction.sh) echo off ;;
    *) echo '' ;;
  esac
}

while IFS= read -r f; do
  [ -n "$f" ] || continue
  bn="$(basename "$f")"
  exp="$(expected_posture "$bn")"
  if [[ -z "$exp" ]]; then
    note FAIL "$bn: AC21 표에 없는 codex 호출부 — 표가 낡았다(expected_posture()에 추가하라)"
    continue
  fi
  is_on=0
  web_true_in_code "$f" && is_on=1
  if [[ "$exp" == on ]]; then
    if [[ "$is_on" -eq 1 ]]; then
      note PASS "$bn: AC21 표=ON, 실제 ON 일치"
    else
      note FAIL "$bn: AC21 표=ON인데 tools.web_search=true 실재가 없다"
    fi
  else
    if [[ "$is_on" -eq 0 ]]; then
      note PASS "$bn: AC21 표=OFF, 실제 OFF 일치"
    else
      note FAIL "$bn: AC21 표=OFF인데 tools.web_search=true 가 있다(웹이 켜졌다)"
    fi
  fi
done <<EOF
$codex_runners
EOF

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
