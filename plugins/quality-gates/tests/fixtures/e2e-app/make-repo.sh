#!/usr/bin/env bash
# make-repo.sh <dest> — e2e fixture 리포를 <dest> 에 만든다.
#   main    : 목록만 보여 주는 앱
#   e2e-ok  : 항목 추가(POST /api/items · 폼)를 바르게 더한 브랜치
#   e2e-bug : 같은 커밋 메시지에 POST /api/items 가 `title` 키를 읽는 결함을 심은 브랜치
# 끝나면 main 에 체크아웃돼 있다. stdout 은 <dest> 절대경로 한 줄이다.
set -eu
dest="${1:-}"
[ -n "$dest" ] || { echo "usage: make-repo.sh <dest>" >&2; exit 2; }
if [ -e "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ]; then
  echo "make-repo: $dest 가 비어 있지 않다" >&2; exit 2
fi
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$dest"
dest="$(cd "$dest" && pwd -P)"
g() { git -C "$dest" -c core.hooksPath=/dev/null -c user.email=e2e-fixture@devbrew.local -c user.name='e2e fixture' -c commit.gpgsign=false "$@"; }
cp -R "$here/base/." "$dest/"
chmod +x "$dest/tests/test_store.sh"
g init -q -b main
g add -A
g commit -q -m "feat: item list app"
msg='feat(items): add item creation

POST /api/items with JSON {"name": "<item>"} stores the item and returns 201 {"count": <n>}.
The home page gets a form that adds an item by name. GET /api/items lists the added items.'
for v in ok bug; do
  g checkout -q -b "e2e-$v" main
  cp "$here/variants/$v/app.py" "$dest/app.py"
  g add -A
  g commit -q -m "$msg"
done
g checkout -q main
printf '%s\n' "$dest"
