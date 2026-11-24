#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/*
# AC23 — 옛 글자(종류 글자 · 파일 이름 끝 · 머리 키 · 옛 기본 폴더)의 리터럴은 대응표 모듈(scripts/legacy_names.py) 한 곳에만 있다.
# 파이썬은 tokenize 로 문자열 · 주석 토큰만 본다(변수 · 함수 이름은 보지 않는다). 셸은 본문 전체를 본다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_legacy_literals.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  git -C "$ROOT" ls-files -- 'plugins/spec-distill/scripts/*'
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
LIST="$(mktemp)"; OUT="$(mktemp)"
trap 'rm -f "$LIST" "$OUT"' EXIT
git -C "$ROOT" ls-files -- 'plugins/spec-distill/scripts/*' > "$LIST"
n_py="$(grep -c '\.py$' "$LIST")"
[ "$n_py" -ge 60 ] && ok "코퍼스(양성 짝): 스크립트 ${n_py}개" || no "코퍼스가 ${n_py}개 — 부재 단언이 공허하다"
python3 - "$ROOT" "$LIST" > "$OUT" <<'PY'
import io
import re
import sys
import tokenize
from pathlib import Path

root = Path(sys.argv[1])
MODULE = "plugins/spec-distill/scripts/legacy_names.py"
OLD = [
    re.compile(r"interview-(?:seed-audit|seed|state|brief|audit)(?![-A-Za-z0-9_])"),
    re.compile(r"-interview\.(?:state\.|audit\.)?md"),
    re.compile(r"source_interview"),
    re.compile(r"docs/superpowers/interview/"),
]
STEM = re.compile(r"(?<!-)-interview(?=[\"'])")   # 줄기를 짓는 문자열 조각 — 문자열 토큰에만
STEM_F = re.compile(r"(?<!-)-interview$")          # 3.12+ 의 f-string 조각(FSTRING_MIDDLE) — 따옴표가 토큰 밖이라 끝에서 본다
KINDS = ("STRING", "COMMENT", "FSTRING_MIDDLE")
hits = []
for rel in Path(sys.argv[2]).read_text(encoding="utf-8").split():
    if rel == MODULE:
        continue
    text = (root / rel).read_text(encoding="utf-8")
    if rel.endswith(".py"):
        pieces = []
        for tok in tokenize.generate_tokens(io.StringIO(text).readline):
            name = tokenize.tok_name.get(tok.type, "")
            if name in KINDS:
                pieces.append((tok.start[0], name, tok.string))
    else:
        pieces = [(no, "TEXT", line) for no, line in enumerate(text.splitlines(), 1)]
    for no, name, s in pieces:
        bad = [p.pattern for p in OLD if p.search(s)]
        if name == "STRING" and STEM.search(s):
            bad.append(STEM.pattern)
        if name == "FSTRING_MIDDLE" and STEM_F.search(s):
            bad.append(STEM_F.pattern)
        if bad:
            hits.append("%s:%d: %s" % (rel, no, s.strip().splitlines()[0][:120]))
for h in hits:
    print("HIT " + h)
PY
rc_py=$?
[ "$rc_py" -eq 0 ] && ok "스캐너가 돌았다" || no "스캐너 rc=${rc_py}"
n_hit="$(grep -c '^HIT ' "$OUT")"
if [ "$n_hit" -eq 0 ]; then ok "대응표 모듈 밖의 스크립트에 옛 글자 리터럴이 없다"
else sed 's/^HIT /  /' "$OUT"; no "옛 글자 리터럴 ${n_hit}곳"; fi
# 양의 짝 — 모듈이 옛 글자를 실제로 쥐고, 읽는 스크립트가 모듈을 쓴다
M="$ROOT/plugins/spec-distill/scripts/legacy_names.py"
for lit in 'interview-seed-audit' 'interview-brief' '-interview' 'source_interview' 'docs/superpowers/interview/'; do
  grep -qF -- "$lit" "$M" && ok "모듈: 「${lit}」" || no "모듈에 「${lit}」 가 없다"
done
for s in state_path interview_state check_brief check_bundle_coverage spec_review_bundle roadmap_status raw_source \
         control_plane repo_defaults team_write team_check roadmap_draft_entry; do
  grep -qE '^(import legacy_names|from legacy_names import|import legacy_names as)' "$ROOT/plugins/spec-distill/scripts/$s.py" \
    && ok "${s}.py 가 대응표 모듈을 쓴다" || no "${s}.py 가 대응표 모듈을 쓰지 않는다"
done
finish
