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

# (a)+(a-값) codex 웹 posture — **실행 관측**으로 판정한다 (설계 §4.3, AC11과 동형).
#
# 정적 grep 판정은 Fix round 1(codex 독립 리뷰, 2026-08-09)에서 무이빨로 확인됐다:
#   - kill switch **헤더**(`if [[ ... ]]`)의 존재만 쟀지 **분기 바디**는 안 쟀다 —
#     분기 안에서 web을 그대로 켜 둬도 헤더 grep은 만족된다. 스위치가 "껐다"고
#     loud하게 stderr에 적으면서 실제로는 계속 검색하는 상태가 GREEN이었다(Critical 1).
#   - `web_search` 모드(`live`/`disabled`) — 이 태스크 전체의 존재 이유인 그 키 —
#     는 애초에 한 번도 값으로 검사되지 않았다. 그 플래그를 통째로 지워도
#     27/27이었다(Critical 2).
#   - 그 이전 라운드의 자체 수정(`web_true_in_code()`, 주석 줄만 제외)도 무이빨
#     이었다: trailing 주석은 안 걸러졌고, posture-명시 체크는 그 헬퍼를 아예
#     쓰지 않았다(Important 4).
# 공통 근본원인: grep은 주석·heredoc·죽은 분기·설명 문구로 항상 만족시킬 수 있다.
# 소스를 읽는 대신 **mock codex를 PATH 앞에 놓고 각 러너를 실제로 실행**해 관측된
# argv로 판정한다 — `plugins/quality-gates/tests/lib/codex_observation.sh`
# (`test_codex_invocation_contract.sh`가 AC11을 재는 것과 동형, DRY). 관측된 argv는
# 주석·heredoc·죽은 분기로 만족될 수 없다: 실행되지 않으면 애초에 mock에 도달하지
# 않는다.
#
# 여섯 호출부 전부를 평시(kill switch 미설정) 1회 실행해 AC21 표의 두 열
# (`tools.web_search`·`web_search` 모드)을 양방향 대조하고, 웹 ON 세 곳은
# **kill switch를 세팅한 채 두 번째로 실행**해 분기가 실제로 두 값을 OFF로
# 뒤집는지 관측한다 — 헤더가 아니라 effect를 잰다(Critical 1을 직접 겨냥).
#
# OBS_REPO는 **소싱 전에** 명시적으로 세팅한다. codex_observation.sh 자신의
# fallback(`${OBS_REPO:-$(dirname BASH_SOURCE[0])/../../..}`)은 이 파일 위치
# 기준 3단 `..`만 올라가 `plugins/`에서 멈춘다 — sibling
# test_codex_invocation_contract.sh가 이 결함을 겪지 않는 이유는 그 fallback을
# 태우지 않고 항상 미리 세팅해서 넘기기 때문이다(같은 패턴을 따른다).
OBS_REPO="$REPO_ROOT"
. "$REPO_ROOT/plugins/quality-gates/tests/lib/codex_observation.sh"

SCRATCH="$(mktemp -d -t sd-web-obs-XXXXXX)" || SCRATCH=""
if [[ -z "$SCRATCH" || ! -d "$SCRATCH" ]]; then
  note FAIL "관측 scratch 디렉토리 생성 실패 — 아래 AC21 실행-관측 판정은 전부 건너뛴다"
else
  trap 'rm -rf "$SCRATCH"' EXIT
  obs_setup "$SCRATCH"

  # 어느 호출부가 웹 ON이어야 하는지는 코드에서 도출할 수 없는 의미론적 판단이라
  # 표가 불가피하다(AC21). 표에 없는 호출부가 나타나면 RED — 표가 조용히 낡는
  # 것을 막는다.
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
  # ON 사이트에만 의미가 있다. qg 두 곳은 현재 OFF라 이 표에 미도달이지만, ON
  # 전환 시 쓸 이름을 미리 등록해둔다(지금 죽은 스위치를 만들지는 않는다).
  kill_switch_for() {  # <basename> -> switch var name
    case "$1" in
      run_spec_codex_reviewer.sh|run_brief_codex_reviewer.sh) echo 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' ;;
      run_audit_codex_reviewer.sh) echo 'DEVBREW_DISABLE_PLUGIN_AUDIT_WEB' ;;
      run_codex_reviewer.sh|run_artifact_codex_reviewer.sh) echo 'DEVBREW_DISABLE_QG_WEB' ;;
      *) echo '' ;;
    esac
  }

  # 관측된 argv에서 `-c 'KEY=VAL'`의 VAL 토큰과 정확히 일치하는 줄이 있는가.
  # argv는 NUL 구분으로 캡처되므로(`obs_argv`) 주석·설명 문구는 애초에 여기
  # 나타날 수 없다 — 실행되지 않은 텍스트는 mock에 도달하지 않는다.
  argv_has() { obs_argv "$1" | grep -qxF -- "$2"; }

  # 두 열(`tools.web_search`·`web_search` 모드)을 **양방향**으로 잰다: 기대값
  # 부재 → RED, 반대값 존재 → RED. 평시 판정과 kill-switch effect 판정 둘 다
  # 이 하나의 함수를 공유한다 — kill 상태는 그냥 expect=off로 같은 잣대를 쓴다.
  check_posture() {  # <call-dir> <label> <expect: on|off>
    local d="$1" label="$2" expect="$3" want_web want_mode avoid_web avoid_mode ok=1
    if [[ "$expect" == on ]]; then
      want_web='tools.web_search=true'; want_mode='web_search="live"'
      avoid_web='tools.web_search=false'; avoid_mode='web_search="disabled"'
    else
      want_web='tools.web_search=false'; want_mode='web_search="disabled"'
      avoid_web='tools.web_search=true'; avoid_mode='web_search="live"'
    fi
    argv_has "$d" "$want_web"   || { note FAIL "$label: 관측된 argv에 '$want_web' 부재"; ok=0; }
    argv_has "$d" "$want_mode"  || { note FAIL "$label: 관측된 argv에 '$want_mode' 부재"; ok=0; }
    argv_has "$d" "$avoid_web"  && { note FAIL "$label: 관측된 argv에 '$avoid_web' 존재(반대 방향 위반)"; ok=0; }
    argv_has "$d" "$avoid_mode" && { note FAIL "$label: 관측된 argv에 '$avoid_mode' 존재(반대 방향 위반)"; ok=0; }
    [[ "$ok" -eq 1 ]] && note PASS "$label: tools.web_search·web_search 모드 둘 다 기대값과 일치"
  }

  # 코퍼스: codex_observation.sh의 codex_candidates() — plugins/ 전체를 비주석
  # 실행줄 기준으로 스캔한다(AC11과 동일 앵커, DRY — 이 파일이 따로 glob을 들고
  # 있지 않는다).
  #
  # floor는 단순 개수(`-lt 1`)가 아니라 **AC21 표 자체에서 도출한 부분집합
  # 검사**다(Suggestion, Fix round 2). 개수 문턱만으로는 변수 간접 호출
  # (`CODEX_BIN=codex; "$CODEX_BIN" exec`)처럼 codex_candidates()의 정규식이
  # 못 잡는 새 호출부가 생겨 6→5로 줄어도 여전히 통과한다(재현: 실제로 GREEN
  # 이었다) — 이름 단위 부재만 그것을 잡는다. `known_posture_names()`는
  # `expected_posture()` 자신에서 라벨을 뽑는다(둘째 목록을 안 만든다 —
  # obs_known_candidates()와 같은 원리).
  # `declare -f`는 `case` 본문을 **라벨 줄과 body 줄을 분리해** 재포맷한다
  # (label 다음 줄이 `echo on/off`, 그다음 `;;`) — 한 줄 `label) echo X ;;`가
  # 아니다. obs_known_candidates()(:117-165, codex_observation.sh)와 같은
  # awk 스캔으로 라벨만 뽑는다(실측 확인, sed 한 줄로는 매치가 하나도 안 됨).
  known_posture_names() {
    local src label_lines label
    src="$(declare -f expected_posture)"
    label_lines="$(printf '%s\n' "$src" | awk '
      /case "\$1" in/ { incase=1; expect=1; next }
      incase && /^[[:space:]]*esac/ { incase=0; next }
      incase && expect { print; expect=0; next }
      incase && /^[[:space:]]*;;[[:space:]]*$/ { expect=1 }
    ')"
    while IFS= read -r label; do
      [ -n "$label" ] || continue
      label="$(printf '%s' "$label" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/\)$//')"
      [ "$label" = "*" ] && continue
      printf '%s\n' "$label" | tr '|' '\n'
    done <<EOF_LBL
$label_lines
EOF_LBL
  }

  candidates="$(codex_candidates)"
  n_cand=0
  [ -n "$candidates" ] && n_cand="$(printf '%s\n' "$candidates" | wc -l | tr -d ' ')"
  known_names="$(known_posture_names)"
  n_known=0
  [ -n "$known_names" ] && n_known="$(printf '%s\n' "$known_names" | wc -l | tr -d ' ')"

  if [ "$n_known" -lt 1 ]; then
    note FAIL "expected_posture 표에서 이름을 하나도 추출하지 못했다 — 추출기가 표 문법과 어긋났다(아래 AC21 판정은 건너뛴다)"
  elif [ "$n_cand" -lt 1 ]; then
    note FAIL "도출: codex 호출부를 하나도 못 찾았다 — 도출 기준이 깨졌다(아래 AC21 실행-관측 판정은 건너뛴다)"
  else
    note PASS "도출: codex 호출부 ${n_cand}곳 (실행 관측 대상, AC21)"

    scanned_names="$(printf '%s\n' "$candidates" | xargs -n1 basename 2>/dev/null | sort -u)"
    missing=0
    while IFS= read -r k; do
      [ -n "$k" ] || continue
      if ! printf '%s\n' "$scanned_names" | grep -qxF "$k"; then
        missing=$((missing + 1))
        note FAIL "AC21 표의 '$k'가 codex_candidates() 스캔 결과에 없다 — 코퍼스 도출이 놓쳤다(변수 간접 호출 등)"
      fi
    done <<EOF_KNOWN
$known_names
EOF_KNOWN
    [ "$missing" -eq 0 ] && note PASS "AC21 표의 알려진 호출부 ${n_known}곳이 스캔 결과에서 전부 발견됨"

    while IFS= read -r f; do
      [ -n "$f" ] || continue
      bn="$(basename "$f")"
      exp="$(expected_posture "$bn")"
      if [[ -z "$exp" ]]; then
        note FAIL "$bn: AC21 표에 없는 codex 호출부 — 표가 낡았다(expected_posture()에 추가하라)"
        continue
      fi

      cap_normal="$SCRATCH/ac21-normal-$bn"
      mkdir -p "$cap_normal"
      if ! obs_invoke "$f" "$cap_normal"; then
        note FAIL "$bn: 후보인데 실행할 방법이 없다 (obs_invoke 인자 표에 부재이거나 mock 준비 실패)"
        continue
      fi
      n_calls="$(obs_call_count "$cap_normal")"
      if [[ "$n_calls" -lt 1 ]]; then
        note FAIL "$bn: 실행했으나 codex 호출이 관측되지 않았다 (calls=0) — 값 판정을 건너뛴다"
        continue
      fi
      # 관측된 **모든** 호출을 잰다(call-0만이 아니다) — 코퍼스 안에 이미
      # 다중-호출 사이트가 있다(spike가 for i in 1 2 3로 3회 호출). 두 번째
      # 호출에서 값이 갈라져도(예: 1번은 off로 위장, 2번은 실제 on) call-0만
      # 보면 못 잡는다(Important 1, Fix round 2). bash 3.2는 nullglob이 없어
      # `[ -d "$d" ] || continue`로 가드한다(codex_observation.sh:182와 동형).
      for d in "$cap_normal"/call-*; do
        [ -d "$d" ] || continue
        check_posture "$d" "$bn (평시, $(basename "$d"))" "$exp"
      done

      if [[ "$exp" == on ]]; then
        sw="$(kill_switch_for "$bn")"
        if [[ -z "$sw" ]]; then
          note FAIL "$bn: ON인데 kill switch 변수를 특정할 수 없다(kill_switch_for에 등록하라)"
          continue
        fi

        cap_killed="$SCRATCH/ac21-killed-$bn"
        mkdir -p "$cap_killed"
        export "$sw=1"
        obs_invoke "$f" "$cap_killed" || true
        unset "$sw"
        n_killed="$(obs_call_count "$cap_killed")"
        if [[ "$n_killed" -lt 1 ]]; then
          note FAIL "$bn: $sw=1로 실행했으나 codex 호출이 관측되지 않았다"
        else
          for d in "$cap_killed"/call-*; do
            [ -d "$d" ] || continue
            # 분기 바디가 실제로 값을 뒤집는지를 잰다 — 헤더의 존재가 아니라
            # effect다(Critical 1, Fix round 1). 분기가 no-op이면 여기서
            # tools.web_search=true / web_search="live"가 그대로 관측된다.
            check_posture "$d" "$bn ($sw=1, $(basename "$d"))" "off"
          done
        fi

        # 엄격성 계약(Important 2, Fix round 2): `:15`·설계 §6 S3d — 정확히
        # 문자열 "1"만 참, 그 밖은 전부 웹이 켜진 채로 남아야 한다. `yes`는
        # truthy해 보이지만 리터럴 "1"이 아니다 — 러너의 술어가
        # `[[ -n "${SW:-}" ]]`처럼 느슨해지면(리터럴 "1" 비교가 아니게 되면)
        # 이 실행에서 값이 off로 뒤집혀 잡힌다. `DEVBREW_SPEC_DISTILL_DISABLE_WEB=false`
        # 처럼 "끄지 마라"는 의도로 값을 채운 사용자가 조용히 웹을 잃는 사고를
        # 겨냥한다.
        cap_strict="$SCRATCH/ac21-strict-$bn"
        mkdir -p "$cap_strict"
        export "$sw=yes"
        obs_invoke "$f" "$cap_strict" || true
        unset "$sw"
        n_strict="$(obs_call_count "$cap_strict")"
        if [[ "$n_strict" -lt 1 ]]; then
          note FAIL "$bn: $sw=yes로 실행했으나 codex 호출이 관측되지 않았다"
        else
          for d in "$cap_strict"/call-*; do
            [ -d "$d" ] || continue
            check_posture "$d" "$bn ($sw=yes, 엄격성 계약)" "on"
          done
        fi
      fi
    done <<EOF_CAND
$candidates
EOF_CAND
  fi
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
