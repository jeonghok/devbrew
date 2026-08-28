#!/usr/bin/env bash
# guards: plugins/spec-distill/**
#
# probe 상한 스윕의 **완결성**을 잰다 — 단측 단언이다.
#
# 완료 조건: 아래 별칭 oracle 의 출력에 `tests/fixtures/` · `CHANGELOG.md` · 이 파일 자신
# **밖** 경로가 0건. 집합 일치가 아니라 단측인 이유와 세 제외의 이유를 여기 함께 적는다 —
# **이유 없는 면제 목록은 그 질문을 영구히 닫는다.**
#
#  · `tests/fixtures/` 제외 — audit 템플릿의 `## 2. Budget` 절을 **삭제하지 않기로** 한
#    비용 판단의 결과다(절을 지우면 `check_brief.py` 의 `AUDIT_SECTIONS` 와 픽스처
#    61건이 함께 스윕 대상이 된다). 절은 남기고 본문만 바꾼다. 대가는 «삭제된 개념을
#    계속 인용하는 픽스처가 락으로 굳는 것»이고, 그 대가를 알고 치른다.
#  · `CHANGELOG.md` 제외 — **지울 수 없는 과거 릴리스 이력**이다. 빼지 않으면 이 락은
#    원리적으로 green 이 될 수 없고, 무엇보다 **이 스윕 자신의 `Removed: probe_budget.py`
#    엔트리가 락을 RED 로 만든다.** 락을 만족시키는 커밋이 락을 깨뜨리는 형태다.
#  · 이 파일(`test_probe_sweep_residue.sh`) 자신 제외 — `ALIAS_RE` 정의 리터럴 자체가
#    별칭 문자열을 담아야 정규식으로 동작한다. git add 되는 순간부터 이 파일이 tracked
#    코퍼스에 들어가 스스로를 잡는다 — CHANGELOG.md 와 같은 형태의 자기지시 함정이고,
#    같은 이유로 제외한다: 자신을 잡는 락은 커밋될 수 없다. **양성 대조에서도** 같은 이유로
#    뺀다 — 안 빼면 `ALIAS_RE`를 통째로 없는 토큰으로 바꿔도 이 파일 자신의 정의 줄이
#    "1건"으로 잡혀 정규식이 깨진 상태를 «살아있음»으로 오판한다(양성 대조 자체가
#    자기지시로 무력화, M9 실증).
#
# 집합 «일치»로 잠그지 않는 이유: 픽스처 61건 중 `state-probe-at-cap.md` 와
# `state-probe-within.md` 둘은 audit 픽스처가 아니라 삭제 대상 `test_probe_budget.sh`
# 전용 state 픽스처라 함께 지워지는 것이 옳다(잔존이 59 가 된다). 일치로 잠그면 그
# 올바른 정리에 거짓 RED 가 난다. 단측은 판별력이 같고 그 부작용이 없다.
#
# 이 oracle 이 못 보는 것(알려진 채로 남긴다): grep 은 산문 언급을 찾지 **구조화된
# 상수**를 못 본다. `check_brief.py` 의 `AUDIT_SECTIONS` 는 절 제목을 튜플 원소로 들고
# 있어 `## 2. Budget` 패턴에 안 걸린다. 위의 «절을 삭제하지 않는다» 결정이 이 사각지대를
# 무해하게 만든다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

ALIAS_RE='probe_budget|probe_count|probe_cap|effective_cap|raise-cap|PROBE_CAP|coverage_mapper_last_probe'
SCOPE='plugins/spec-distill'

if [ "${1:-}" = "--emit-scanned" ]; then
  git ls-files -- "$SCOPE"
  exit 0
fi

# vacuity 하한 — 코퍼스가 비면 「잔존 0」이 「안 봤다」가 된다.
corpus_n="$(git ls-files -- "$SCOPE" | wc -l | tr -d ' ')"
if [ "${corpus_n:-0}" -lt 1 ]; then
  no "코퍼스가 0건 — 이 검사가 vacuous 하다"
  finish; exit $?
fi
ok "코퍼스 ${corpus_n}개 파일 (vacuous 아님)"

# 양성 대조 — oracle 자체가 살아 있는가. 별칭이 «어딘가에는» 남아 있어야 한다
# (픽스처). 0건이면 정규식이 깨진 것이지 스윕이 완벽한 것이 아니다. 이 파일 자신은
# 여기서도 뺀다 — `ALIAS_RE`가 무엇으로 바뀌든 그 리터럴이 이 파일 안에 그대로 있으므로,
# 자신을 포함하면 어떤 깨진 정규식(예: 존재하지 않는 토큰 하나)도 "1건"으로 살아있는
# 척한다 — 양성 대조 자체가 자기지시로 무력화된다(잔존 계산과 같은 함정, M9 로 실증).
all_hits="$(git grep -lE "$ALIAS_RE" -- "$SCOPE" | grep -v 'test_probe_sweep_residue\.sh$' | wc -l | tr -d ' ')"
if [ "${all_hits:-0}" -lt 1 ]; then
  no "양성 대조: 별칭이 리포 어디에도 0건 — 정규식이 깨졌다 (스윕 완벽과 구별 불가)"
  finish; exit $?
fi
ok "양성 대조: 별칭 총 ${all_hits}건 (정규식 살아 있음)"

residue="$(git grep -lE "$ALIAS_RE" -- "$SCOPE" \
  | grep -v 'tests/fixtures/' | grep -v 'CHANGELOG\.md$' \
  | grep -v 'test_probe_sweep_residue\.sh$' || true)"
n=0
while IFS= read -r f; do [ -n "$f" ] && n=$((n + 1)); done <<< "$residue"
if [ "$n" -eq 0 ]; then
  ok "잔존 0건 (tests/fixtures/ · CHANGELOG.md · 이 파일 자신 제외 — 위 헤더에 각각의 이유)"
else
  printf '%s\n' "$residue" | while IFS= read -r f; do
    [ -n "$f" ] && echo "     잔존: $f"
  done
  no "probe 별칭 잔존 ${n}건 — 스윕이 끝나지 않았다"
fi

finish
