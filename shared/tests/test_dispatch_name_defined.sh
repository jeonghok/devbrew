#!/usr/bin/env bash
# guards: plugins/*/skills/**/*.md plugins/*/commands/*.md plugins/*/agents/*.md plugins/*/README.md plugins/*/*.py tools/adjudication/check_names.py
#
# 수정 라운드 1 (F6) — 판정기 자신을 declare 한다. `fixtures/adjudication/
# run_names.py` 가 `import check_names` 하므로 이 락이 그 코퍼스다(도출은
# import 로, 27개 `# guards:` 선언 전수를 손으로 세지 않는다).
#
# `commands/*.md` — 단일 `*` 다(`**` 아님). 이 락이 실제로 읽는 명령 파일은
# 전부 flat(`commands/<name>.md`) 인데, `# guards:` 를 소비하는 bash `case`
# 패턴에서 `**` 는 인접한 리터럴 `/` 를 요구해 flat 경로를 구조적으로 못
# 맞춘다 — `*` 는 이미 `/` 를 넘으므로(기존 test_skill_reference_pointers.sh
# 관례) flat·중첩 양쪽을 다 잡는다. 파이썬 쪽 `check_names._REF_GLOBS` 는
# `**` 그대로 둔다(pathlib 의 `**` 는 zero-or-more 라 flat 도 이미 맞는다) —
# 어긋나는 쪽은 이 bash 선언뿐이었다.
# `README.md` — `check_names.references()` 가 넷째 글롭으로 읽는다(kill
# switch 키 문서화 대응) — 기존 선언에 빠져 있었다.
# `plugins/*/*.py` — `check_names._KILLSWITCH_GLOB`(`plugins/*/**/*.py`,
# pathlib) 를 bash case 로 옮긴 것. 여기도 단일 `*` 다 — 그 파이썬 글롭은
# 실측 155개 중 상당수가 flat(`plugins/<name>/<file>.py`, 예:
# `plugins/*/scripts/kill_switch_active.py`)가 아니라 최소 1단 이상
# 중첩이라 bash `**` 로도 대부분 맞지만, 단일 `*` 로 통일해 향후 flat 파일이
# 생겨도 어긋나지 않게 한다(실측: `plugins/*/*.py` 가 155개 전부를 덮는다 —
# `/tmp/checkpyglob.sh` 로 확인). `killswitch_keys()` 가 실제로 여는 코퍼스라
# `scanned_paths()` 도 이제 이것을 낸다 — 이전 판은 "정밀도를 죽인다"며
# 뺐으나, `dangling()` 이 이 코퍼스를 실제로 소비해(README 참조 판정에
# `defined(allow_killswitch=True)` 를 통해) 판정이 바뀔 수 있었다.
#
# 백틱으로 불린 `<plugin>:<name>` 이 실재 정의를 갖는지 검사한다.
#
# 기존 dispatch 락과 «방향이 반대»다: 그쪽은 정의에서 출발해 호출을 찾고,
# 이쪽은 호출에서 출발해 정의를 찾는다. 지워진 정의를 가리키는 이름은 그쪽
# 방향에서 구조적으로 안 보인다.
#
# 백틱과 콜론을 «동시에» 요구한다. 산문 속 맨 영어 단어는 둘 다 없으므로
# 기존 락의 표기 필터와 겹치지 않는다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

# `--emit-scanned` — test_guards_coverage_bidirectional.sh 가 읽는다. 코퍼스
# 도출은 run_names.py 안에 산다(판정기가 파이썬) — 같은 러너를 `--emit-scanned`
# 모드로 부른다.
if [ "${1:-}" = "--emit-scanned" ]; then
  PYTHONDONTWRITEBYTECODE=1 python3 "$HERE/fixtures/adjudication/run_names.py" \
    "$REPO_ROOT" --emit-scanned
  printf '%s\n' "tools/adjudication/check_names.py"
  exit 0
fi

TMPD="$(mktemp -d -t dispname-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

PYTHONDONTWRITEBYTECODE=1 python3 "$HERE/fixtures/adjudication/run_names.py" \
  "$REPO_ROOT" > "$TMPD/out.txt" 2>&1
OUT="$(cat "$TMPD/out.txt")"
note "$OUT"

note "── 판정기 자체 (fixture)"
assert_contains "$OUT" "fx_stale=1"  "지워진 이름을 잡는다"
assert_contains "$OUT" "fx_ok=0"     "실재하는 이름을 통과시킨다"
assert_contains "$OUT" "fx_prose=0"  "산문 속 맨 단어와 백틱 없는 콜론은 잡지 않는다 (기존 락의 실측 제약)"

note "── 정의 집합"
ndef="$(printf '%s\n' "$OUT" | sed -n 's/^defined=//p')"
if [ "${ndef:-0}" -gt 0 ] 2>/dev/null; then
  ok "정의 $ndef 개 (agent + skill + command)"
else
  no "정의 도출이 0 이다 — 락이 vacuous 하다"
fi

note "── 참조 코퍼스"
nref="$(printf '%s\n' "$OUT" | sed -n 's/^refs=//p')"
if [ "${nref:-0}" -gt 0 ] 2>/dev/null; then
  ok "참조 $nref 건"
else
  no "참조 도출이 0 이다 — 코퍼스 glob 이 깨졌으면 이 락의 단언이 전부 공허하다"
fi

note "── 존재하지 않는 정의를 가리키는 참조"
nd="$(printf '%s\n' "$OUT" | sed -n 's/^dangling=//p')"
assert_eq "$nd" "0" "모든 참조가 실재 정의를 가리킨다"
printf '%s\n' "$OUT" | sed -n 's/^  DANGLING //p' | while IFS= read -r l; do
  note "      매달림: $l"
done

finish
