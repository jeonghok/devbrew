#!/usr/bin/env bash
# detect_codex.sh — emit YAML manifest describing Codex CLI availability.
# Vendored from quality-gates (spec-distill design §6 #1). Read-only, exit 0
# always (graceful degradation). ONLY adaptation vs qg: the codex-only kill
# switch var is namespaced to spec-distill (see below), not the qg plugin's var.

set -u

emit_skip() {
  printf 'codex_available: false\n'
  printf 'skip_reason: %s\n' "$1"
}

# 1. Kill switch (codex-only opt-out; spec-distill namespace)
if [[ "${DEVBREW_DISABLE_SPEC_DISTILL_CODEX:-0}" == "1" ]]; then
  emit_skip 'kill_switch'
  exit 0
fi

# 2. Recursion guard: already inside a Codex sandbox
if [[ -n "${CODEX_SANDBOX:-}" || -n "${CODEX_SESSION_ID:-}" ]]; then
  emit_skip 'inside_codex_sandbox'
  exit 0
fi

# 3. Install check
CODEX_PATH="$(command -v codex 2>/dev/null || true)"
if [[ -z "$CODEX_PATH" || "$CODEX_PATH" != /* ]]; then
  emit_skip 'not_installed'
  exit 0
fi

# 4. Auth check
if [[ -z "${CODEX_API_KEY:-}" && -z "${OPENAI_API_KEY:-}" && ! -f "${HOME:-/nonexistent}/.codex/auth.json" ]]; then
  emit_skip 'auth_missing'
  exit 0
fi

# 5. Timeout binary check (prevents pipeline freeze on hung version probe)
TIMEOUT_BIN=$(command -v gtimeout 2>/dev/null || command -v timeout 2>/dev/null)
if [ -z "$TIMEOUT_BIN" ]; then
  cat <<YAML
codex_available: false
codex_path: ""
codex_version: ""
skip_reason: timeout_binary_missing
YAML
  exit 0
fi

# 6. Version probe. **판독 실패는 fail-closed다.**
#    `|| echo unknown`은 도달하지 않는다: `||`가 파이프라인 전체에 걸리고 파이프라인의
#    종료 코드는 `head`의 것인데 `head -1`은 빈 입력에도 exit 0이다 (실측:
#    `bash -c 'v="$(true | head -1 || echo unknown)"'` → v는 빈 문자열). 그래서 판정을
#    문자열 `unknown`이 아니라 **semver 파싱 성공 여부**에 건다 — 빈 문자열도 여기서 잡힌다.
CODEX_VERSION="$("$TIMEOUT_BIN" 5 codex --version 2>/dev/null | head -1)"
CODEX_SEMVER="$(printf '%s' "$CODEX_VERSION" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
if [ -z "$CODEX_SEMVER" ]; then
  printf 'codex_available: false\n'
  printf 'skip_reason: version_unreadable\n'
  printf 'detected_version: %s\n' "$CODEX_VERSION"
  exit 0
fi

# 6a. known-bad (0.120.0/1/2 stdin deadlock). 갱신 경로는 이 사이클 밖이다.
if echo "$CODEX_VERSION" | grep -Eq '(^|[^0-9.])0\.120\.(0|1|2)([^0-9.]|$)'; then
  printf 'codex_available: false\n'
  printf 'skip_reason: known_bad_version\n'
  printf 'detected_version: %s\n' "$CODEX_VERSION"
  exit 0
fi

# 6b. 버전 바닥. stdin prompt(`codex exec -`)는 rust-v0.118.0에서 도입됐고(PR #15917)
#     이 하니스의 모든 러너가 stdin 규약을 쓴다 — 미만은 실행해도 실패한다.
#     바닥이 실제보다 높으면 멀쩡한 버전을 degrade시키는 **능력 억제**가 되므로,
#     이 값의 근거는 §11의 능력 probe로 한 번 재고 확정해야 한다 (설계 §10 미해결 4).
CODEX_VERSION_FLOOR='0.118.0'
_ver_lt() {   # _ver_lt A B → A < B 이면 0. 인자는 이미 검증된 semver triple.
  local ax ay az bx by bz
  IFS=. read -r ax ay az <<< "$1"
  IFS=. read -r bx by bz <<< "$2"
  [ "$((10#$ax))" -lt "$((10#$bx))" ] && return 0
  [ "$((10#$ax))" -gt "$((10#$bx))" ] && return 1
  [ "$((10#$ay))" -lt "$((10#$by))" ] && return 0
  [ "$((10#$ay))" -gt "$((10#$by))" ] && return 1
  [ "$((10#$az))" -lt "$((10#$bz))" ] && return 0
  return 1
}
if _ver_lt "$CODEX_SEMVER" "$CODEX_VERSION_FLOOR"; then
  printf 'codex_available: false\n'
  printf 'skip_reason: version_below_floor\n'
  printf 'detected_version: %s\n' "$CODEX_VERSION"
  printf 'required_version: %s\n' "$CODEX_VERSION_FLOOR"
  exit 0
fi

# 7. All checks pass
printf 'codex_available: true\n'
printf 'codex_path: %s\n' "$CODEX_PATH"
printf 'codex_version: %s\n' "$CODEX_VERSION"
exit 0
