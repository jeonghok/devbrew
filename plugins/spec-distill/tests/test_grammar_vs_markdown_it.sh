#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/brief_body.py plugins/spec-distill/scripts/seed_body.py plugins/spec-distill/scripts/section6.py pyproject.toml uv.lock
# AC19 — 허용 문법과 markdown-it-py 토큰의 교차 확인. 파서가 없으면 「확인 못 함」 rc 3.
# 확인 모듈(grammar_vs_markdown_it_check.py)은 이름을 test_ 로 시작하지 않는다 — 일반 unittest 수집이 줍지 않게(파서 없이 수집되면 rc 3).
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
  ( cd "$HERE" && uv run --locked --group dev --project "$ROOT" python -W ignore -m unittest -q grammar_vs_markdown_it_check )
else
  echo "확인 못 함(uv 없음) — 고정한 개발 의존(markdown-it-py)을 받을 수 없어 교차 확인을 돌리지 못했다"
  exit 3
fi
