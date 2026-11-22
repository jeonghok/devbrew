#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/* plugins/spec-distill/references/* plugins/spec-distill/templates/* plugins/spec-distill/agents/* plugins/spec-distill/README.md plugins/spec-distill/switches.md plugins/spec-distill/dependencies.md shared/docreview/agents/* shared/docreview/references/* shared/docreview/scripts/docreview_state.py
# 글 속 낱말(AC40 의 계획 1 몫) — skill 글 · 펜스 · 템플릿 · README · reference · agent 정의 · 리뷰 기준에
# 단계를 가리키는 옛 낱말(「인터뷰」 · interview brief · docs(interview) · 옛 펜스 표지 · 홀로 쓰인 영어 interview)이 없고,
# 새 글자가 자리마다 실제로 있다(양의 짝). 쉬운 말 규칙 블록과 면제 목록의 줄은 건너뛴다.
# 정적 락이다 — 모델이 이 글을 실제로 따르는지는 재지 못한다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_stage_words.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"
. "$ROOT/shared/tests/assert.sh"

corpus() { git -C "$ROOT" ls-files -- 'plugins/spec-distill/skills/*' 'plugins/spec-distill/references/*' \
  'plugins/spec-distill/templates/*' 'plugins/spec-distill/agents/*' 'plugins/spec-distill/README.md' \
  'plugins/spec-distill/switches.md' 'plugins/spec-distill/dependencies.md' \
  'shared/docreview/agents/*' 'shared/docreview/references/*' 'shared/docreview/scripts/docreview_state.py'; }

CORPUS="$(corpus)"
n_files="$(printf '%s\n' "$CORPUS" | grep -c .)"
[ "$n_files" -ge 40 ] && ok "코퍼스(양성 짝): 추적 파일 ${n_files}개" || no "코퍼스가 ${n_files}개 — 부재 단언이 공허하다"

# 부재 — 쉬운 말 규칙 블록을 뺀 본문에서 금지 토큰을 찾는다
# (heredoc 을 $( ) 안에 두지 않는다 — 본문 글자에 따라 파싱이 깨진다. 결과는 임시 파일로 받는다)
SCAN_OUT="$(mktemp)"; LIST="$(mktemp)"
trap 'rm -f "$SCAN_OUT" "$LIST"' EXIT
printf '%s\n' "$CORPUS" > "$LIST"
python3 - "$ROOT" "$LIST" > "$SCAN_OUT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
STAGE = re.compile(
    r"(?<!옛 )인터뷰|interview brief|docs\(interview\)"
    r"|interview-(?:commit|pr|merge)(?![A-Za-z0-9_])"
    r"|interview-(?:pr|merge)-(?:files|head|recheck|requested)",
    re.I,
)
# 홀로 쓰인 영어 낱말 — 앞뒤에 식별자 글자가 붙은 꼴(--interview · interview_state.py · interview-seed …)은 걸리지 않는다
BARE = re.compile(r"(?<![-_/.$A-Za-z0-9])interview(?:s|er|ers|ing)?(?![-_/.A-Za-z0-9])", re.I)
# 면제 목록 — (파일, 줄에 든 글자, 이유). 계획 2 이유의 줄은 계획 2 가 비운다.
EXEMPT = [
    ("plugins/spec-distill/skills/reviewing-brief/SKILL.md", "`advisories` 의 「인터뷰를 닫은 답 …」 줄",
     "계획 2 — 스크립트 출력 인용 · scripts/check_verbatim_coverage.py:run(L3 advisories)"),
]
hits = []
exempted = 0
used = set()
for rel in Path(sys.argv[2]).read_text(encoding="utf-8").split():
    text = (root / rel).read_text(encoding="utf-8")
    inside = False
    for no, line in enumerate(text.splitlines(), 1):
        if "<!-- plain-language:begin -->" in line:
            inside = True
        if inside:
            if "<!-- plain-language:end -->" in line:
                inside = False
            continue
        if not (STAGE.search(line) or BARE.search(line)):
            continue
        ex = [i for i, (f, frag, _r) in enumerate(EXEMPT) if f == rel and frag in line]
        if ex:
            exempted += 1
            used.update(ex)
            continue
        hits.append(f"{rel}:{no}: {line.strip()}")
stale = [f"{EXEMPT[i][0]} 「{EXEMPT[i][1]}」" for i in range(len(EXEMPT)) if i not in used]
print(f"EXEMPTED {exempted}")
for s in stale:
    print(f"STALE {s}")
for h in hits:
    print(f"HIT {h}")
PY
rc_py=$?
OUT="$(cat "$SCAN_OUT")"
[ "$rc_py" -eq 0 ] && ok "부재 스캐너가 돌았다" || no "부재 스캐너 rc=${rc_py}"
printf '%s\n' "$OUT" | grep '^EXEMPTED ' | sed 's/^EXEMPTED /면제한 줄 수: /'
n_hit="$(printf '%s\n' "$OUT" | grep -c '^HIT ')"
if [ "$n_hit" -eq 0 ]; then ok "단계를 가리키는 옛 낱말 · 표지가 범위에 없다"
else printf '%s\n' "$OUT" | grep '^HIT ' | sed 's/^HIT /  /'; no "옛 낱말 · 표지 ${n_hit}곳"; fi
n_stale="$(printf '%s\n' "$OUT" | grep -c '^STALE ')"
if [ "$n_stale" -eq 0 ]; then ok "면제 목록의 줄이 모두 아직 쓰인다"
else printf '%s\n' "$OUT" | grep '^STALE ' | sed 's/^STALE /  /'; no "쓰이지 않는 면제 ${n_stale}줄 — 목록에서 지운다"; fi

# 양의 짝 — 새 글자가 실제로 있다(자리마다 하나)
some_in() {   # some_in <파일 목록> <리터럴> — 목록의 어느 파일엔가 있다
  local f
  for f in $1; do
    if grep -qF -- "$2" "$ROOT/$f"; then ok "${f}: 「$2」"; return 0; fi
  done
  no "「$2」 가 [$(printf '%s' "$1" | tr '\n' ' ')] 어디에도 없다"
}
none_line_with() {   # none_line_with <파일 목록> <리터럴 1> <리터럴 2> — 둘을 함께 품은 줄이 없다
  local f hit=""
  for f in $1; do grep -F -- "$2" "$ROOT/$f" | grep -qF -- "$3" && hit="${hit} ${f}"; done
  assert_eq "$hit" "" "「$2」 와 「$3」 를 함께 품은 줄이 없다"
}
FIN="plugins/spec-distill/skills/context-build/references/finishing.md"
RD="$(git -C "$ROOT" ls-files 'plugins/spec-distill/skills/roadmap-draft/*')"
some_in "$FIN" '<!-- context-commit:begin -->'
some_in "$RD" '<!-- roadmap-pr:begin -->'
some_in "$RD" 'roadmap-merge: MERGED'
some_in "$FIN" 'docs(context): '
some_in "$FIN" 'context brief'
some_in "plugins/spec-distill/README.md" '컨텍스트 쌓기'
some_in "plugins/spec-distill/README.md" '로드맵 잡기'
some_in "plugins/spec-distill/README.md" '의도 폴더'
some_in "plugins/spec-distill/skills/context-build/SKILL.md" 'context-build stage'
# 「의도 폴더」 는 로드맵 폴더 아래 intent/ 를 가리키지 않는다
none_line_with "$CORPUS" '의도 폴더' 'roadmaps/'
finish
