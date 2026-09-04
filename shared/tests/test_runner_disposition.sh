#!/usr/bin/env bash
# guards: plugins/*/scripts/*codex*.sh
#
# 외부 모델 판정자(codex 러너)가 자기 처분을 밝히는지 검사한다.
#
# 모집단은 신설하지 않는다 — 리포에 도출기가 이미 있고 standing assertion 에
# 묶여 있다. 그 도구를 «고치지 않고» 출력에서 **명시 제외된 것만** 뺀다.
# 이전 판본은 여기에 `grep '/scripts/'` 를 걸었고, 그것이 걸러낸 것을 세지도
# 이름을 대지도 않아 다른 디렉터리의 러너가 앵커 없이 통과했다(최종 리뷰 K4c).
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

# ── 모집단 = 도출 전체 − «명시 제외». 이전엔 `grep '/scripts/'` 였다 ──────
# 그 후처리는 «걸러낸 것을 세지도 이름을 대지도 않았고», 그래서 `plugins/*/lib/`
# 같은 다른 자리에 놓인 codex 러너가 앵커 없이 통과했다. 게다가 vacuity 가드
# (`n_all > n_run`)가 그 버림을 «성공»으로 읽었다 — 많이 버릴수록 초록이었다
# (최종 리뷰 K4c). 이제 제외는 «열거된 하나»뿐이고 나머지는 무엇이 어디에
# 있든 전부 모집단에 든다. `/scripts/` 밖이면 세어서 이름을 댄다(공시).
#
# 각 항목은 사유를 갖는다:
#   · plugins/quality-gates/tests/spike/test_codex_json_extraction.sh —
#     러너가 아니라 «러너를 시험하는 spike 테스트»다. 실제 codex 를 호출하고
#     자기 fixture 를 덮어쓰므로 프로덕션 판정 경로가 아니다. 처분 앵커를
#     요구할 dispatch 자리 자체가 없다.
EXCLUDED_DECL='plugins/quality-gates/tests/spike/test_codex_json_extraction.sh'
read -r -a excluded_globs <<< "$EXCLUDED_DECL"

: > "$TMPD/runners.txt"
: > "$TMPD/excluded.txt"
: > "$TMPD/outside.txt"
while IFS= read -r abs; do
  [ -n "$abs" ] || continue
  rel_repo="${abs#"$REPO_ROOT"/}"
  hit=0
  for e in "${excluded_globs[@]}"; do
    [ "$rel_repo" = "$e" ] && { hit=1; break; }
  done
  if [ "$hit" -eq 1 ]; then
    printf '%s\n' "$rel_repo" >> "$TMPD/excluded.txt"
    continue
  fi
  printf '%s\n' "$abs" >> "$TMPD/runners.txt"
  case "$rel_repo" in
    */scripts/*) ;;
    *) printf '%s\n' "$rel_repo" >> "$TMPD/outside.txt" ;;
  esac
done < "$TMPD/all.txt"

# `--emit-scanned` — test_guards_coverage_bidirectional.sh 가 읽는다. 코퍼스는
# 위에서 이미 만든 runners.txt(도출기 − 명시 제외, ㉯) 다 — 다시 도출하지
# 않고 같은 파일을 그대로 낸다. 절대경로 → repo-relative 변환만 한다(선언
# 글롭이 repo-relative 라 매칭시키려면 필요) — 이것은 재도출이 아니라 서식
# 변환이다. 모집단이 `/scripts/` 밖으로 넓어지면 이 락의 `# guards:` 선언도
# 같이 넓혀야 한다 — 그 불일치는 저 양방향 검사가 잡는다(의도된 시끄러움).
if [ "${1:-}" = "--emit-scanned" ]; then
  while IFS= read -r abs; do
    [ -n "$abs" ] || continue
    printf '%s\n' "${abs#"$REPO_ROOT"/}"
  done < "$TMPD/runners.txt"
  exit 0
fi

n_all="$(wc -l < "$TMPD/all.txt" | tr -d ' ')"
n_run="$(wc -l < "$TMPD/runners.txt" | tr -d ' ')"
n_exc="$(wc -l < "$TMPD/excluded.txt" | tr -d ' ')"
n_out="$(wc -l < "$TMPD/outside.txt" | tr -d ' ')"
note "도출기 출력 $n_all → 명시 제외 $n_exc → 모집단 $n_run (그중 /scripts/ 밖 $n_out)"

# 0 은 통과가 아니라 실패다.
if [ "${n_run:-0}" -gt 0 ] 2>/dev/null; then
  ok "㉯ 도출 $n_run 개 (0 이 아니다 — 락이 vacuous 하지 않다)"
else
  no "㉯ 도출이 0 이다 — 도출기 출력이나 모집단 계산이 깨졌다. 이 락의 모든 단언이 공허하다"
fi

# 조용히 사라진 것이 없는가. 이전 vacuity 가드(`n_all > n_run`)는 이것의
# «반대»를 재고 있었다 — 버려진 게 있어야 통과였다. 이제는 도출된 것 중
# 명시 제외를 뺀 전부가 모집단이어야 한다(등식). 하나라도 어긋나면 어딘가에서
# 조용히 버려졌다는 뜻이다.
if [ "$((n_all - n_exc))" -eq "${n_run:-0}" ] 2>/dev/null; then
  ok "조용히 버려진 항목 0 (도출 $n_all − 명시 제외 $n_exc = 모집단 $n_run)"
else
  no "도출 $n_all − 명시 제외 $n_exc ≠ 모집단 $n_run — 어딘가에서 조용히 버려졌다"
fi

# 명시 제외가 «살아 있는가». 대상이 사라졌는데 선언만 남으면 그건 죽은
# 필터다(이전 후처리 가드가 잡으려던 것 — 방향만 바로잡아 여기 남긴다).
for e in "${excluded_globs[@]}"; do
  if grep -Fxq "$e" "$TMPD/excluded.txt"; then
    ok "명시 제외 '$e' 가 실제로 1건 이상 걸렀다 (죽은 선언이 아니다)"
  else
    no "명시 제외 '$e' 가 아무것도 안 걸렀다 — 대상이 이동·삭제됐다. 선언을 지우거나 갱신하라"
  fi
done

# `/scripts/` 밖은 «세어서 이름을 댄다». 버리지 않는다 — 아래 축들이 그대로
# 적용된다(그 자리에 놓인 러너가 앵커 없이 통과하던 것이 K4c 의 결함이다).
if [ "${n_out:-0}" -gt 0 ] 2>/dev/null; then
  note "      /scripts/ 밖 $n_out 건 — 모집단에 포함해 아래 축을 그대로 적용한다:"
  while IFS= read -r l; do
    [ -n "$l" ] && note "        $l"
  done < "$TMPD/outside.txt"
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
  rel_repo="${rel#"$REPO_ROOT"/}"
  if [ ! -f "$f" ]; then no "$rel_repo: 도출된 경로가 실재하지 않는다"; continue; fi
  # 실패 자리는 `file:line` 으로 이름 댄다 — basename 만으로는 같은 이름의
  # 다른 파일과 구분이 안 되고, 형제 락 넷이 이미 `file:line` 이다(A/m4).
  # 앵커가 없으면 줄이 없으므로 `:0` — 그 자체가 「앵커 없음」의 표기다.
  anchor_ln="$(grep -n -F '**처분**' "$f" | head -1 | cut -d: -f1)"
  base="$rel_repo:${anchor_ln:-0}"

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
