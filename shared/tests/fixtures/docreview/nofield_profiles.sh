#!/usr/bin/env bash
# nofield_profiles.sh — spec-distill 프로필 셋(brief · design-doc · seed)에서 frontmatter 의 `must_catch:` 줄만 뺀
# 사본 디렉토리를 만들고 그 경로 한 줄을 낸다. cases.sh 의 케이스와 golden 은 필드 없는 프로필의 동작(라우팅
# 현행)을 재므로 이 사본으로 돌고, 필드를 지목한 동작은 cases_advice.sh 가 실제 프로필로 잰다.
# 경로는 세 원본 내용의 해시다 — 같은 내용이면 다시 만들지 않고, 원본이 바뀌면 새 자리를 만든다.
#
# 사본은 캐시 디렉토리 바로 아래가 아니라 그 안의 `docreview-profiles/` 서브디렉토리에 둔다 —
# `cases.sh` 의 `case_init_same_doc_idempotent` 가 `$PROF_SD/../docreview-profiles/design-doc.md`
# 표기로 같은 프로필을 다시 가리키는 셀을 갖고 있다(원본 트리의 실제 형제 디렉토리 이름이
# `docreview-profiles`). 이 함수가 낸 경로가 그 서브디렉토리이면 `..` 가 캐시 디렉토리로
# 올라갔다가 같은 서브디렉토리로 다시 내려와 같은 파일을 가리킨다 — 캐시 디렉토리 자체를
# 냈으면 `../docreview-profiles/` 는 존재하지 않는 자리가 되어 그 셀이 무너진다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$(cd "$HERE/../../../.." && pwd)/plugins/spec-distill/references/docreview-profiles"
base="${TMPDIR:-/tmp}"; base="${base%/}"
h="$(cat "$SRC/brief.md" "$SRC/design-doc.md" "$SRC/seed.md" \
  | python3 -c 'import hashlib, sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest()[:12])')" || exit 1
cache="$base/docreview-nofield-$h"
dst="$cache/docreview-profiles"
if [ ! -f "$dst/seed.md" ]; then
  tmp="$(mktemp -d "$base/docreview-nofield-tmp.XXXXXX")" || exit 1
  mkdir -p "$tmp/docreview-profiles" || exit 1
  for p in brief design-doc seed; do
    python3 "$HERE/strip_must_catch.py" "$SRC/$p.md" "$tmp/docreview-profiles/$p.md" || exit 1
  done
  # 동시 실행이 같은 자리를 먼저 만들었으면 rename 이 실패한다 — 그쪽 것을 쓰고 내 사본은 치운다.
  python3 -c 'import os, shutil, sys
try:
    os.rename(sys.argv[1], sys.argv[2])
except OSError:
    shutil.rmtree(sys.argv[1], ignore_errors=True)' "$tmp" "$cache"
fi
# rename 이 실패한 경우 「동시 실행이 먼저 만들었다」고만 가정했다 — 그 자리가 실은 무관한
# 선재 디렉토리(비어있지 않은 stale dir 등)였으면 사본이 없는 채로 이 경로를 낼 뻔했다.
# 낙관적 가정을 여기서 실측으로 확인한다: 셋 다 있어야 성공이다.
if [ ! -f "$dst/brief.md" ] || [ ! -f "$dst/design-doc.md" ] || [ ! -f "$dst/seed.md" ]; then
  echo "사본 프로필 캐시 손상: $cache — 지우고 다시 돌려라" >&2
  exit 1
fi
printf '%s\n' "$dst"
