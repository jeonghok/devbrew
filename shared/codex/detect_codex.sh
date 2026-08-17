#!/usr/bin/env bash
# detect_codex.sh — emit YAML manifest describing Codex CLI availability.
# Spec AC1. Read-only, exit 0 always (graceful degradation).
#
# 이 파일이 정본이다. 세 플러그인(quality-gates · spec-distill · plugin-audit)의
# scripts/detect_codex.sh 는 이 파일을 가리키는 **상대 심볼릭 링크**다(물리 사본이
# 아니다 — 2026-08-17 실측, 설계 §16.1). 유일하게 달라야 하는 값(kill switch 변수명)은
# 형제 파일 `codex-killswitch.conf` 로 나가 있다 — 인자가 아니라 파일인 이유는 그 conf
# 파일의 주석과 설계 §6.4 에 있다(기존 행동 등가 락이 세 배포 지점을 **인자 없이** 태운다).
#
# 행동 등가는 `quality-gates/tests/test_codex_copies_agree.sh` 가 재고,
# 배포 지점이 이 정본을 가리키는지는 `shared/tests/test_copy_of_contract.sh` 가
# 잰다 — 두 락이 각자 다른 것을 잰다(설계 §6.4). 앞의 락 헤더가 *"왜 파일 diff 가
# 아닌가: 두 사본은 의도된 차이를 갖는다"* 라고 적어 둔 그 전제는 이 통합이 없앴다.
# (바이트 동일성은 이제 "측정할" 대상이 아니다 — 심볼릭 링크라 애초에 갈라질 수 없다.)

set -u

emit_skip() {
  printf 'codex_available: false\n'
  printf 'skip_reason: %s\n' "$1"
}

# 0. 형제 설정 로드 — **fail-closed**.
#    변수명이 빈 값으로 해석되어 kill switch 가 조용히 무반응이 되는 것은
#    보안 컨트롤 훼손이다(CLAUDE.md:48). 설정이 없으면 codex 를 쓰지 않는 쪽으로 닫는다.
#    `dirname "${BASH_SOURCE[0]}"` 는 리포·설치본의 깊이 차이와 무관하고,
#    기존 락의 `env -i` 아래서도 작동한다(env -i 는 환경변수만 비운다).
_CONF="$(dirname -- "${BASH_SOURCE[0]}")/codex-killswitch.conf"
if [[ ! -r "$_CONF" ]]; then
  emit_skip 'killswitch_config_missing'
  exit 0
fi
# shellcheck source=/dev/null
. "$_CONF"
if [[ -z "${CODEX_KILL_SWITCH_VAR:-}" ]]; then
  emit_skip 'killswitch_config_incomplete'
  exit 0
fi

# 1. Kill switch (highest priority — explicit user opt-out)
if [[ "${!CODEX_KILL_SWITCH_VAR:-0}" == "1" ]]; then
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

# 5. Timeout binary check (required to prevent pipeline freeze on hung version probe)
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
