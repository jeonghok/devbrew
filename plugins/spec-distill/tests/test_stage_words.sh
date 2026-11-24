#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/* plugins/spec-distill/references/* plugins/spec-distill/templates/* plugins/spec-distill/agents/* plugins/spec-distill/README.md plugins/spec-distill/switches.md plugins/spec-distill/dependencies.md shared/docreview/agents/* shared/docreview/references/* shared/docreview/scripts/docreview_state.py plugins/spec-distill/scripts/* plugins/quality-gates/*
# 글 속 낱말(AC40 의 계획 1 몫) — skill 글 · 펜스 · 템플릿 · README · reference · agent 정의 · 리뷰 기준에
# 단계를 가리키는 옛 낱말(「인터뷰」 · interview brief · docs(interview) · 옛 펜스 표지 · 홀로 쓰인 영어 interview)이 없고,
# 새 글자가 자리마다 실제로 있다(양의 짝). 쉬운 말 규칙 블록과 면제 목록의 줄은 건너뛴다.
# 정적 락이다 — 모델이 이 글을 실제로 따르는지는 재지 못한다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_stage_words.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"
if [ "${1:-}" = "--emit-scanned" ]; then   # 읽는 파일: 아래 corpus() 와 같은 묶음
  git -C "$ROOT" ls-files -- 'plugins/spec-distill/skills/*' 'plugins/spec-distill/references/*' \
    'plugins/spec-distill/templates/*' 'plugins/spec-distill/agents/*' 'plugins/spec-distill/README.md' \
    'plugins/spec-distill/switches.md' 'plugins/spec-distill/dependencies.md' \
    'shared/docreview/agents/*' 'shared/docreview/references/*' 'shared/docreview/scripts/docreview_state.py' \
    'plugins/spec-distill/scripts/*'
  git -C "$ROOT" ls-files -- plugins/quality-gates ':!plugins/quality-gates/tests' ':!plugins/quality-gates/CHANGELOG.md'
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"

corpus() { git -C "$ROOT" ls-files -- 'plugins/spec-distill/skills/*' 'plugins/spec-distill/references/*' \
  'plugins/spec-distill/templates/*' 'plugins/spec-distill/agents/*' 'plugins/spec-distill/README.md' \
  'plugins/spec-distill/switches.md' 'plugins/spec-distill/dependencies.md' \
  'shared/docreview/agents/*' 'shared/docreview/references/*' 'shared/docreview/scripts/docreview_state.py' \
  'plugins/spec-distill/scripts/*'
  git -C "$ROOT" ls-files -- plugins/quality-gates ':!plugins/quality-gates/tests' ':!plugins/quality-gates/CHANGELOG.md'; }

CORPUS="$(corpus)"
n_files="$(printf '%s\n' "$CORPUS" | grep -c .)"
[ "$n_files" -ge 40 ] && ok "코퍼스(양성 짝): 추적 파일 ${n_files}개" || no "코퍼스가 ${n_files}개 — 부재 단언이 공허하다"

# 부재 — 쉬운 말 규칙 블록을 뺀 본문에서 금지 토큰을 찾는다
# (heredoc 을 $( ) 안에 두지 않는다 — 본문 글자에 따라 파싱이 깨진다. 결과는 임시 파일로 받는다)
SCAN_OUT="$(mktemp)"; LIST="$(mktemp)"
trap 'rm -f "$SCAN_OUT" "$LIST"' EXIT
printf '%s\n' "$CORPUS" > "$LIST"
python3 - "$ROOT" "$LIST" > "$SCAN_OUT" <<'PY'
import io
import re
import sys
import tokenize
from pathlib import Path

root = Path(sys.argv[1])
STAGE = re.compile(
    r"(?<!옛 )인터뷰|interview brief|docs\(interview\)"
    r"|interview-(?:commit|pr|merge)(?![A-Za-z0-9_])"
    r"|interview-(?:pr|merge)-(?:files|head|recheck|requested)",
    re.I,
)
# 홀로 쓰인 영어 낱말 — 앞뒤에 식별자 글자가 붙은 꼴(--interview · interview_state.py · interview-seed …)은 걸리지 않는다.
# 뒤의 `.` 은 확장자처럼 영숫자가 이어질 때만 식별자로 본다 — 문장 끝 마침표(「… interviews.」)는 걸린다.
BARE = re.compile(r"(?<![-_/.$A-Za-z0-9])interview(?:s|er|ers|ing)?(?![-_/A-Za-z0-9]|\.[A-Za-z0-9])", re.I)
# 옛 층 글자 — 스크립트 밖 글에서는 같은 줄에 「옛 」 이 있을 때만 받는다(옛 기록을 가리키는 말).
LAYER = re.compile(
    r"interview_dir|source_interview|docs/superpowers/interview/"
    r"|interview-(?:seed-audit|seed|state|brief|audit)(?![-A-Za-z0-9_])"
    r"|-interview\.(?:state\.|audit\.)?md"
)
IDENT_STRING = re.compile(r"[rbuRBU]{0,2}[\"'][A-Za-z_][A-Za-z0-9_]*[\"']")   # "interview" 같은 사전 키 — 식별자로 본다


def pieces(rel, text):
    """(줄 번호, 글) — .py 는 문자열 · 주석 토큰만(식별자 같은 문자열 하나는 뺀다), 그 밖은 쉬운 말 규칙 블록을 뺀 줄."""
    if rel.endswith(".py"):
        for tok in tokenize.generate_tokens(io.StringIO(text).readline):
            name = tokenize.tok_name.get(tok.type, "")
            if name not in ("STRING", "COMMENT", "FSTRING_MIDDLE"):
                continue
            if name == "STRING" and IDENT_STRING.fullmatch(tok.string):
                continue
            for i, line in enumerate(tok.string.splitlines()):
                yield tok.start[0] + i, line
        return
    inside = False
    for no, line in enumerate(text.splitlines(), 1):
        if "<!-- plain-language:begin -->" in line:
            inside = True
        if inside:
            if "<!-- plain-language:end -->" in line:
                inside = False
            continue
        yield no, line


def layer_hit(rel, line):
    return not rel.endswith(".py") and bool(LAYER.search(line)) and "옛 " not in line

# 면제 목록 — (파일, 줄에 든 글자, 이유).
EXEMPT = [
    ("plugins/quality-gates/README.md", "`source_intent,source_interview,roadmap,source_brief,type=roadmap,type=epic-bundle`",
     "기본 표지 목록 리터럴(설정 표의 `DEVBREW_QUALITY_GATES_INTENT_DOC_MARKERS` 줄) — 설정 기본값이라 같은 줄에 「옛 」 을 둘 수 없다(옛 머리 키를 읽는 표지)"),
]
hits = []
exempted = 0
accepted_old = 0
used = set()
for rel in Path(sys.argv[2]).read_text(encoding="utf-8").split():
    text = (root / rel).read_text(encoding="utf-8")
    for no, line in pieces(rel, text):
        if not rel.endswith(".py") and LAYER.search(line) and "옛 " in line:
            accepted_old += 1
        if not (STAGE.search(line) or BARE.search(line) or layer_hit(rel, line)):
            continue
        ex = [i for i, (f, frag, _r) in enumerate(EXEMPT) if f == rel and frag in line]
        if ex:
            exempted += 1
            used.update(ex)
            rest = line
            for i in ex:
                rest = rest.replace(EXEMPT[i][1], "")
            if not (STAGE.search(rest) or BARE.search(rest) or layer_hit(rel, rest)):
                continue
        hits.append(f"{rel}:{no}: {line.strip()}")
stale = [f"{EXEMPT[i][0]} 「{EXEMPT[i][1]}」" for i in range(len(EXEMPT)) if i not in used]
print(f"EXEMPTED {exempted}")
print(f"OLDOK {accepted_old}")
for s in stale:
    print(f"STALE {s}")
for h in hits:
    print(f"HIT {h}")
PY
rc_py=$?
OUT="$(cat "$SCAN_OUT")"
[ "$rc_py" -eq 0 ] && ok "부재 스캐너가 돌았다" || no "부재 스캐너 rc=${rc_py}"
printf '%s\n' "$OUT" | grep '^OLDOK ' | sed 's/^OLDOK /「옛 」 규칙으로 받은 줄 수: /'
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
some_in "plugins/spec-distill/scripts/interview_state.py" 'context-state: '
some_in "plugins/spec-distill/scripts/control_plane.py" '컨텍스트 쌓기 조사'
some_in "plugins/spec-distill/skills/context-build/SKILL.md" '<!-- context-state-entry:begin -->'
some_in "plugins/spec-distill/skills/context-build/references/state-file.md" 'context-state: RESUME'
some_in "plugins/spec-distill/README.md" 'intent_dir'
some_in "plugins/spec-distill/references/docreview-profiles/design-doc.md" 'source_intent'
some_in "plugins/quality-gates/scripts/other_teams.py" '컨텍스트 쌓기 단계의 팀'
some_in "plugins/quality-gates/scripts/intent_origin.py" '"source_intent"'
# 「의도 폴더」 는 로드맵 폴더 아래 intent/ 를 가리키지 않는다
none_line_with "$CORPUS" '의도 폴더' 'roadmaps/'
finish
