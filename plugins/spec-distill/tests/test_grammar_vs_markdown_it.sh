#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/brief_body.py plugins/spec-distill/scripts/seed_body.py plugins/spec-distill/scripts/section6.py pyproject.toml uv.lock
# AC19 — 허용 문법과 markdown-it-py 토큰의 교차 확인. 파서가 없으면 「확인 못 함」 rc 3.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' plugins/spec-distill/scripts/brief_body.py plugins/spec-distill/scripts/seed_body.py \
    plugins/spec-distill/scripts/section6.py pyproject.toml uv.lock
  exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1
if command -v uv >/dev/null 2>&1; then
  ( cd "$HERE" && uv run --frozen --group dev --project "$ROOT" python -W ignore -m unittest -q test_grammar_vs_markdown_it )
else
  ( cd "$HERE" && python3 -W ignore -m unittest -q test_grammar_vs_markdown_it )
fi
