#!/usr/bin/env bash
# guards: shared/docreview/references/reviewing-document.md
#
# 절차서(`shared/docreview/references/reviewing-document.md`)의 「## 한 라운드」 절이
# 스크립트를 **배포 경로**(`<플러그인 루트>/scripts/…`)에서 부르라고 명시하는지 잰다
# (Park P10). 실행자가 정본 자리(`shared/docreview/scripts/`)에서 직접 부르면
# `runner_common.sh`·`adjudication` 모듈 같은 형제 파일이 없어 라운드가 죽는다 — 그
# 이유를 절차서 본문이 가르쳐야 T3 이후의 실행자가 두 번 안 걸린다(Task 2 brief).
#
# ── 두 단언과 그 관계 ────────────────────────────────────────────────────
# 1. 존재 — 본문에 「배포 경로에서 부른다」는 지시가 **body-unique** 문구로 있는지
#    본다. 헤더나 목차가 그 문구를 만족시키면 본문을 지워도 GREEN 이 되는 함정이
#    있어(리포에 기록된 실패 유형) 헤더 줄('#' 시작)을 코퍼스에서 통째로 빼고
#    본문만 검사한다 — 이 문서에 목차는 없지만 함정 자체를 구조적으로 막는다.
# 2. 양의 짝 — 절차서가 실제로 스크립트를 **부르는**(인자를 동반한) 줄이 하나
#    이상 있는지 하한으로 잰다. 이게 없으면 1번이 지키는 문단만 남기고 실제 호출
#    줄을 전부 지워도 1번은 계속 GREEN 이다(리터럴 존재만 보고 호출 관례는 안
#    보므로) — 2번이 그 사각을 잡는다. 1번이 더하는 문단은 스크립트 이름을
#    인자 없는 backtick 나열로만 쓰므로 2번의 정규식(이름 뒤 공백+토큰)에 걸리지
#    않는다 — 1번 문단만 지워도 2번은 격리돼 그대로 GREEN 이어야 한다(Step 7).
set -u -o pipefail
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/references/reviewing-document.md"
  exit 0
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"

REF="$REPO_ROOT/shared/docreview/references/reviewing-document.md"

if [ ! -r "$REF" ]; then
  echo "✗ FATAL: $REF 를 읽을 수 없다"
  exit 1
fi

# 헤더(줄이 '#' 로 시작)를 빼고 본문만 남긴다 — body-unique 를 구조적으로 강제한다.
BODY="$(grep -vE '^#' "$REF")"

# ── 1. 존재 — 본문(헤더 제외)에 배포 경로 지시가 있는가 ────────────────────
assert_contains "$BODY" '정본(`shared/docreview/scripts/`)에서 부르면 안 된다' \
  "절차서 본문(헤더 제외)이 배포 경로에서 부르라는 지시를 담는다 (Park P10, body-unique)"

# ── 2. 양의 짝 — 실제 호출 줄이 하나 이상 있는가(하한, 1번과 격리) ─────────
n_calls="$(grep -cE '(docreview_anchor\.py|docreview_state\.py|docreview_route\.py|run_docreview_codex_reviewer\.sh)[[:space:]]+[a-zA-Z-]' "$REF" || true)"
if [ "${n_calls:-0}" -ge 1 ]; then
  ok "절차서가 스크립트를 실제로 부르는 줄을 ${n_calls}개 갖는다 (하한 1, 양의 짝)"
else
  no "절차서에 스크립트 호출 줄이 하나도 없다 — 배포 경로 지시가 가리킬 실행이 사라졌다"
fi

finish
