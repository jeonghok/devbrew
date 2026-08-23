#!/usr/bin/env bash
# extract_codex_invocations.py 의 디렉토리 prune 좌표계 락.
#
# 이 수집기는 `test_sandbox_enforced.sh` 의 "두 수집기 합치" standing assertion 이
# 유일한 소비자였고, 전용 테스트가 없었다. 그래서 prune 판정이 틀려도 그 소비자가
# **다른 이유로** RED 를 내는 것으로만 드러났다(워크트리 상시 RED).
#
# 여기서 재는 것은 **양방향**이다. 한 방향만 재면 틀린 수정이 통과한다:
#   ① 조상 경로에 `.claude` 가 있어도 수집이 **된다**  ← 2026-08-23 결함
#   ② 스캔 root **안쪽**의 `plugins/<x>/.claude` 는 여전히 **걸러진다**  ← 원래 의도
# ①만 걸면 `SKIP_DIRS` 에서 `.claude` 를 통째로 지우는 수정이 GREEN 이 된다 —
# 그러면 플러그인별 git-ignore 세션 상태(실재: 3곳)가 소스로 세어진다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
EXTRACTOR="$ROOT/plugins/quality-gates/tests/lib/extract_codex_invocations.py"
. "$ROOT/shared/tests/assert.sh"

tmp="$(mktemp -d -t qg-extract-XXXXXX)" || exit 1
trap 'rm -rf "$tmp"' EXIT

# codex 호출을 담은 최소 픽스처. `codex exec` 는 비-주석 줄에 있어야 한다.
mk_invoker() { mkdir -p "$(dirname "$1")"; printf '#!/bin/sh\ncodex exec - -s read-only\n' > "$1"; }

# ── ① 조상에 `.claude` 가 있어도 수집된다 ────────────────────────────────────
# devbrew 의 워크트리 관례가 `<repo>/.claude/worktrees/<name>` 이라 이것이 실제 배치다.
anc="$tmp/.claude/worktrees/wt/plugins"
mk_invoker "$anc/quality-gates/scripts/runner.sh"
got="$(python3 "$EXTRACTOR" "$anc" 2>/dev/null)"
if printf '%s\n' "$got" | grep -q 'runner.sh'; then
  ok "① 조상 경로의 .claude 가 스캔을 prune 하지 않는다 (워크트리 배치)"
else
  no "① 조상 .claude 때문에 트리가 통째로 prune 됐다 — 워크트리에서 이 수집기가 항상 0건 (got=[$got])"
fi

# ── ② root 안쪽의 `.claude` 는 여전히 걸러진다 ───────────────────────────────
# 플러그인별 세션 상태 디렉토리. 소스가 아니므로 후보에 들어오면 안 된다.
inner="$tmp/inner/plugins"
mk_invoker "$inner/quality-gates/scripts/real.sh"
mk_invoker "$inner/quality-gates/.claude/sessions/state.sh"
got2="$(python3 "$EXTRACTOR" "$inner" 2>/dev/null)"
if printf '%s\n' "$got2" | grep -q 'real.sh'; then
  ok "② root 안쪽 일반 소스는 수집된다"
else
  no "② root 안쪽 일반 소스를 놓쳤다 (got=[$got2])"
fi
if printf '%s\n' "$got2" | grep -q '\.claude/sessions/state.sh'; then
  no "② root 안쪽 plugins/<x>/.claude 가 후보로 새어 들어왔다 — 세션 상태를 소스로 센다 (got=[$got2])"
else
  ok "② root 안쪽 plugins/<x>/.claude 는 여전히 걸러진다 (원래 의도 유지)"
fi

# ── 나머지 SKIP_DIRS 도 같은 좌표계를 쓴다 ───────────────────────────────────
# `.claude` 만 상대화하고 나머지를 절대 성분으로 두는 반쪽 수정을 봉쇄한다.
skipd="$tmp/skip/plugins"
mk_invoker "$skipd/quality-gates/scripts/keep.sh"
mk_invoker "$skipd/quality-gates/__pycache__/dropme.sh"
got3="$(python3 "$EXTRACTOR" "$skipd" 2>/dev/null)"
{ printf '%s\n' "$got3" | grep -q 'keep.sh' && ! printf '%s\n' "$got3" | grep -q 'dropme.sh'; } \
  && ok "SKIP_DIRS 의 다른 항목도 root 안쪽에서 계속 걸린다" \
  || no "SKIP_DIRS 의 다른 항목이 깨졌다 (got=[$got3])"

finish
