#!/usr/bin/env bash
# guards: plugins/*/scripts/*codex*.sh
#
# 외부 모델 판정자(codex 러너)가 자기 처분을 밝히는지 검사한다.
#
# 모집단은 신설하지 않는다 — 리포에 도출기가 이미 있고 standing assertion 에
# 묶여 있다. 그 도구를 «고치지 않고» 출력에 /scripts/ 후처리만 건다.
#
# 이 축은 약하다. `disclosure=` 리터럴이 파일에 있다는 것이 그 채널이 실제로
# 읽힌다는 증거는 아니다 — 값이 저자 손에 있는 한 이 축에서 그 이상은 나오지
# 않는다. 없앴다고 주장하지 않고 어디로 옮겼는지 밝힌다.
#
# `consumer=` 가 경로 모양(`/` 포함 또는 `.py`/`.js` 로 끝남)이면 그 값의 «성질»을
# 잰다 — 추적된 파일로 실재하는가, 앵커가 사는 플러그인과 같은가(설치본에서 다른
# 플러그인의 스크립트는 도달 불가라는 것이 이 규칙의 근거, CLAUDE.md). Task 13
# 수정 라운드 1 실측: `run_audit_codex_reviewer.sh` 의 `consumer=orchestrator` 가
# 거짓이었는데(실제 소비자는 같은 플러그인의 `.py`) 이 락은 그것을 잡지 못했다 —
# 세 `assert_grep` 이 문자열 존재만 쟀지 값의 참·거짓을 재지 않았기 때문이다.
# 형제 `test_dispatch_disposition.sh` 의 축 A④/A⑤(인라인 python, `.md`/`.js` 코퍼스)가
# 같은 규칙을 이미 구현한다 — **로직을 복사하지 않고 같은 판정을 이 락의 언어(순수
# bash, `.sh` 코퍼스)로 독립 구현한다.** 두 구현이 코드를 공유하지 않는 이유:
# 형제 쪽은 이 검사가 단일 인라인 python 스크립트 안에 있고 이 락은 순수 bash라
# 함수 하나를 두 언어가 나눠 가질 자리가 없다(하나를 다른 언어로 옮기는 리팩터는
# 이 Task 범위 밖) — 대신 같은 규칙(추적 + 동일 플러그인)이라는 사실을 여기 문서로
# 못박아, 둘 중 하나가 규칙을 바꾸면 이 주석이 다음 저자에게 나머지 하나를 보게 한다.
#
# `orchestrator`/`human` 은 참·거짓을 구조적으로 못 잰다 — 검증 대상이 없다. 조용히
# 건너뛰지 않고 `unverifiable_consumer=N` 으로 개수를 낸다(셀 수 없으면 셀 수 없음을
# 내라는 이 리포의 규약 — 침묵과 0 은 다른 사실이다).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

EXTRACT="$REPO_ROOT/plugins/quality-gates/tests/lib/extract_codex_invocations.py"
if [ ! -f "$EXTRACT" ]; then
  no "도출기 부재: $EXTRACT — 모집단을 계산할 수 없다"
  finish; exit
fi

TMPD="$(mktemp -d -t rundisp-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

PYTHONDONTWRITEBYTECODE=1 python3 "$EXTRACT" "$REPO_ROOT/plugins" > "$TMPD/all.txt" 2>&1
grep '/scripts/' "$TMPD/all.txt" > "$TMPD/runners.txt" || true

# `--emit-scanned` — test_guards_coverage_bidirectional.sh 가 읽는다. 코퍼스는
# 위에서 이미 만든 runners.txt(도출기 + /scripts/ 후처리, ㉯) 다 — 다시
# 도출하지 않고 같은 파일을 그대로 낸다. 절대경로 → repo-relative 변환만
# 한다(선언 글롭이 repo-relative 라 매칭시키려면 필요) — 이것은 재도출이
# 아니라 서식 변환이다.
if [ "${1:-}" = "--emit-scanned" ]; then
  while IFS= read -r abs; do
    [ -n "$abs" ] || continue
    printf '%s\n' "${abs#"$REPO_ROOT"/}"
  done < "$TMPD/runners.txt"
  exit 0
fi

n_all="$(wc -l < "$TMPD/all.txt" | tr -d ' ')"
n_run="$(wc -l < "$TMPD/runners.txt" | tr -d ' ')"
note "도출기 출력 $n_all → /scripts/ 후처리 후 $n_run"

# 0 은 통과가 아니라 실패다.
if [ "${n_run:-0}" -gt 0 ] 2>/dev/null; then
  ok "㉯ 도출 $n_run 개 (0 이 아니다 — 락이 vacuous 하지 않다)"
else
  no "㉯ 도출이 0 이다 — 도출기 출력이나 후처리가 깨졌다. 이 락의 모든 단언이 공허하다"
fi

# 후처리가 실제로 무언가를 걸러냈는지 — 안 걸러내면 후처리가 죽은 것이다.
if [ "${n_all:-0}" -gt "${n_run:-0}" ] 2>/dev/null; then
  ok "/scripts/ 후처리가 $((n_all - n_run)) 개를 걸러냈다 (spike/ 등)"
else
  no "후처리가 아무것도 안 걸러냈다 — 도출기 출력이 바뀌었거나 필터가 죽었다"
fi

# consumer= 경로 검증에 쓸 tracked-files 스냅샷 — `git ls-files --error-unmatch` 를
# 러너마다 반복 호출하는 대신 한 번 찍어 정확일치로 대조한다(동치: 추적 안 된
# 잔여 파일은 `[ -f ]` 로는 걸러지지 않지만 `git ls-files` 목록엔 없다).
git -C "$REPO_ROOT" ls-files > "$TMPD/tracked.txt" 2>/dev/null || : > "$TMPD/tracked.txt"

unverifiable_consumer=0

while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  # 도출기는 «절대» 경로를 낸다(`"$REPO_ROOT/plugins"` 로 호출하므로).
  # `$REPO_ROOT/` 를 다시 붙이면 전부 「파일 없음」으로 떨어져 아래 세 축이
  # 통째로 안 돈다 — 시끄러운 RED 가 조용한 vacuous 로 바뀐다.
  f="$rel"
  base="$(basename "$rel")"
  if [ ! -f "$f" ]; then no "$base: 도출된 경로가 실재하지 않는다"; continue; fi
  rel_repo="${rel#"$REPO_ROOT"/}"

  # **파일 본문이 아니라 «앵커 줄»에서 찾는다.** 본문 전체를 보면 산문이
  # 검사를 만족시킨다 — 실측: 여섯 중 셋이 에러 메시지와 설명 주석에
  # `fail-closed` 를 담고 있어 그 축이 «선언과 무관하게» 통과했다. 그러면
  # 나중에 진짜 선언을 넣었다 지워도 그 셋은 계속 초록이다(이빨 0).
  anchor="$(grep -F '**처분**' "$f" || true)"
  if [ -n "$anchor" ]; then
    ok "$base: 처분 앵커가 있다"
  else
    no "$base: 처분 앵커(\`**처분** — …\`)가 없다 — 아래 세 축은 빈 줄을 검사한다"
  fi
  assert_grep "$anchor" 'consumer=' \
    "$base: 앵커가 consumer= 를 밝힌다 (누가 이 판정을 읽는가)"
  assert_grep "$anchor" 'fail-(open|closed)' \
    "$base: 앵커가 fail-open/fail-closed 를 밝힌다 (죽었을 때 어느 쪽으로 기우는가)"
  assert_grep "$anchor" 'disclosure=' \
    "$base: 앵커가 disclosure= 를 밝힌다 (어느 채널로 드러나는가)"

  # ── consumer= 값의 «성질» — 문자열 존재가 아니라 참·거짓 (Task 13 수정 라운드 2) ──
  cons="$(printf '%s' "$anchor" | sed -n 's/.*consumer=\([^ ·]*\).*/\1/p')"
  case "$cons" in
    */*|*.py|*.js)
      # 경로 모양 — ⑴ 추적된 파일로 실재하는가 ⑵ 앵커와 같은 플러그인인가.
      if grep -Fxq "$cons" "$TMPD/tracked.txt"; then
        ok "$base: consumer=$cons 가 추적된 파일로 실재한다"
      else
        no "$base: consumer=$cons 가 추적되지 않는다 (git ls-files 부재 — 미추적 잔여 파일이거나 존재하지 않는 경로)"
      fi
      anchor_plugin=""
      case "$rel_repo" in plugins/*/*) anchor_plugin="$(printf '%s' "$rel_repo" | cut -d/ -f2)" ;; esac
      cons_plugin=""
      case "$cons" in plugins/*/*) cons_plugin="$(printf '%s' "$cons" | cut -d/ -f2)" ;; esac
      if [ -n "$anchor_plugin" ] && [ "$anchor_plugin" = "$cons_plugin" ]; then
        ok "$base: consumer=$cons 가 앵커와 같은 플러그인이다 ($anchor_plugin)"
      else
        no "$base: consumer=$cons 는 앵커($anchor_plugin)와 다른/불명 플러그인이다 (cons_plugin=${cons_plugin:-<없음>}) — 설치본에서 도달 불가"
      fi
      ;;
    *)
      # orchestrator/human(그 밖의 비-경로 값 포함) — 참·거짓을 구조적으로 못 잰다.
      # 조용히 건너뛰지 않고 개수로 낸다(아래 finish 직전에 출력).
      unverifiable_consumer=$((unverifiable_consumer + 1))
      ;;
  esac
done < "$TMPD/runners.txt"

note "unverifiable_consumer=$unverifiable_consumer (orchestrator/human — 이 축이 참·거짓을 구조적으로 못 잰다)"

finish
