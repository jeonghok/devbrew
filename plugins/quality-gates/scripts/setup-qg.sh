#!/bin/bash

# Quality Gates — 진입 setup. 세 가지만 한다: kill switch · 세션 폴더(SID 가드) · 인자 거부.
# 파일 I/O 는 여기(bash)에서 한다 — SKILL 의 Write 도구를 거치지 않아 권한 질문이 뜨지 않는다.

set -euo pipefail

# --- kill switch (SKILL Preflight P1 도 같은 스위치를 본다 — 직접 호출도 막는다) ---
if [[ "${DEVBREW_QUALITY_GATES_DISABLE:-}" == "1" ]]; then
  echo "[quality-gates] setup-qg disabled via DEVBREW_QUALITY_GATES_DISABLE=1" >&2
  exit 1
fi

# --- 인자 ---
REMOVED_ARGS=""   # v9 에서 없앤 게이트 인자 — 공지 후 진행
GONE_ARGS=""      # v10 에서 없앤 인자 — 공지 후 실행하지 않음
PLAN_FILE="auto"
ENSURE_MODE="false"
SESSION_ID=""

gone() {   # gone <인자 표기> <안내>
  GONE_ARGS="${GONE_ARGS}> [quality-gates] \`${1}\` 인자는 없어졌다 — ${2}. 실행하지 않는다."$'\n'
}

while [[ $# -gt 0 ]]; do
  case $1 in
    review|runtime|both|--skip-runtime)
      REMOVED_ARGS="$REMOVED_ARGS $1"
      shift
      ;;
    --paths)
      # 범위 override 는 SKILL 이 $ARGUMENTS 에서 직접 읽는다 — 여기서는 소비만 한다.
      # 글롭 0개 조건은 아래 while 이 한 번도 안 돌 조건과 같아야 한다.
      shift
      if [[ $# -eq 0 ]] || [[ "$1" =~ ^-- ]] || [[ "$1" =~ ^(review|runtime|both|branch)$ ]]; then
        echo "❌ Error: --paths requires at least one glob" >&2
        exit 1
      fi
      while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]] && [[ ! "$1" =~ ^(review|runtime|both|branch)$ ]]; do
        shift
      done
      ;;
    branch)
      # 맨 `branch` 는 범위 override 다(SKILL 이 읽는다). 뒤에 이름이 오면 v9 의 worktree 모드다.
      shift
      if [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]] && [[ ! "$1" =~ ^(review|runtime|both)$ ]]; then
        gone "branch <name>" "다른 브랜치는 체크아웃하거나 그 브랜치의 git worktree 안에서 /qg 를 돌린다"
        shift
      fi
      ;;
    --reset)
      gone "--reset" "세션 폴더는 /qg 를 시작할 때마다 지우고 다시 만든다"
      shift
      ;;
    --gc)
      gone "--gc" "TTL GC 는 /qg 를 시작할 때마다 자동으로 돈다"
      shift
      ;;
    --pr-url)
      gone "--pr-url" "이 값을 읽는 곳이 없었다"
      shift
      if [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; then shift; fi
      ;;
    --plan)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --plan requires a file path argument" >&2
        exit 1
      fi
      PLAN_FILE="$2"
      shift 2
      ;;
    --ensure)
      ENSURE_MODE="true"
      shift
      ;;
    --session-id)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --session-id requires an argument" >&2
        exit 1
      fi
      SESSION_ID="$2"
      shift 2
      ;;
    -h|--help)
      cat << 'HELP_EOF'
Quality Gates Pipeline Setup

USAGE:
  /qg [branch] [--paths <glob>...] [--plan <path>]

ARGUMENTS:
  (none)               Review git-derived changes (branch + worktree) or the Spec: topic
  branch               Review the full branch diff against base

OPTIONS:
  --paths <glob>...    Scope override — review only the matched paths
  --plan <path>        Specify plan file path (default: auto-detect)
  --session-id <id>    Override session ID (defaults to CLAUDE_CODE_SESSION_ID)
  --ensure             Keep this session's folder if it already exists (skill preflight)
  -h, --help           Show this help message

REMOVED (v10): branch <name> · --reset · --gc · --pr-url — one notice line each, then exit 2.
REMOVED (v9):  review · runtime · both · --skip-runtime — one notice line each, the run proceeds.
HELP_EOF
      exit 0
      ;;
    *)
      echo "❌ Error: Unknown argument: $1" >&2
      echo "   Use --help for usage information" >&2
      exit 1
      ;;
  esac
done

if [[ -n "$GONE_ARGS" ]]; then
  printf '%s' "$GONE_ARGS"
  exit 2
fi

# --- 세션 ID (E1) ---
if [[ -z "$SESSION_ID" ]]; then
  SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"
fi
if [[ -z "$SESSION_ID" ]]; then
  cat >&2 <<EOF
❌ Quality Gates: cannot create pipeline state — session ID is empty.
   Neither --session-id <id> argument nor CLAUDE_CODE_SESSION_ID env var was provided.
   Re-run /qg from Claude Code, or pass --session-id explicitly.
EOF
  exit 1
fi
# 전체 일치 — qg-gc.py 의 SESSION_PATTERN 과 같은 문법. 아래에서 이 값으로 폴더를 지우므로
# 패턴 밖 값(빈 값 · `..` · `/` · 개행)은 거부한다.
if [[ ! "$SESSION_ID" =~ ^[A-Za-z0-9_-]{8,}$ ]]; then
  echo "❌ Quality Gates: session ID '$SESSION_ID' fails pattern guard ([A-Za-z0-9_-]{8,})." >&2
  exit 1
fi

STATE_ROOT=".claude/quality-gates"

# state root 아래의 비-세션 형제 폴더(qg-worktree.sh · baseline-cache.sh 가 쓴다)는 SID 로 받지 않는다.
if [[ "$SESSION_ID" == "worktrees" || "$SESSION_ID" == "baseline-cache" ]]; then
  echo "[quality-gates] session ID '$SESSION_ID' 는 state root 의 예약 폴더 이름이다 — 지우지 않는다. 아무것도 쓰지 않는다." >&2
  exit 1
fi
STATE_DIR="$STATE_ROOT/$SESSION_ID"
STATE_FILE="$STATE_DIR/pipeline.md"

# --ensure: 이 세션 폴더가 이미 있으면 아무것도 하지 않는다.
if [[ "$ENSURE_MODE" == "true" ]] && [[ -f "$STATE_FILE" ]]; then
  exit 0
fi

# --- 자기 세션 폴더를 지우고 다시 만든다 (E1 · E4) ---
# `.claude` 나 state root 가 링크를 거쳐 제자리 밖으로 풀리면 지우지 않는다 — 링크 너머를
# 지울 수 있다(qg-gc.py 의 root_escapes 와 같은 판단). 자기 폴더 자신이 링크여도 지우지 않는다.
root_escapes() {
  local here rel got
  here="$(pwd -P)"
  for rel in ".claude" ".claude/quality-gates"; do
    if [[ -L "$rel" ]] || [[ -e "$rel" ]]; then
      got="$(cd -P "$rel" 2>/dev/null && pwd -P)" || return 0
      [[ "$got" == "$here/$rel" ]] || return 0
    fi
  done
  return 1
}
# 세션 마커 목록은 qg-gc.py 정본에서 읽는다 — 여기에 적지 않는다. 플러그인 루트는 BASH_SOURCE 에서 도출한다(cwd 아님).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_MARKERS=()
has_session_marker() {
  local m
  for m in "${SESSION_MARKERS[@]}"; do
    [[ -f "$STATE_DIR/$m" ]] && return 0
  done
  return 1
}
refuse() {
  echo "[quality-gates] $1 — 지우지 않는다. 아무것도 쓰지 않는다." >&2
  exit 1
}
load_markers() {
  local out m
  out="$(python3 -c 'import importlib.util as u, sys
s = u.spec_from_file_location("qg_gc", sys.argv[1] + "/qg-gc.py")
m = u.module_from_spec(s)
s.loader.exec_module(m)
print("\n".join(m.SESSION_MARKERS + m.LEGACY_SESSION_MARKERS))' "$SCRIPT_DIR" 2>/dev/null)" || return 1
  while IFS= read -r m; do
    [[ -n "$m" ]] && SESSION_MARKERS+=("$m")
  done <<EOF2
$out
EOF2
  [[ ${#SESSION_MARKERS[@]} -gt 0 ]]
}
if ! load_markers; then
  refuse "qg-gc.py 에서 세션 마커 목록을 읽지 못했다"
fi
if root_escapes; then
  refuse "state root '$STATE_ROOT' 가 링크를 거쳐 제자리 밖으로 풀린다"
elif [[ -L "$STATE_DIR" ]]; then
  refuse "세션 폴더 '$STATE_DIR' 자신이 링크다"
elif [[ -e "$STATE_DIR" ]] && [[ ! -d "$STATE_DIR" ]]; then
  refuse "'$STATE_DIR' 가 폴더가 아니다"
elif [[ -d "$STATE_DIR" ]]; then
  # 비어 있거나 세션 마커가 있는 폴더만 이전 실행의 것으로 보고 지운다.
  if [[ -n "$(ls -A "$STATE_DIR" 2>/dev/null)" ]] && ! has_session_marker; then
    refuse "'$STATE_DIR' 는 세션 마커가 없는 비어 있지 않은 폴더라 이전 실행의 것이 아니다"
  fi
  rm -rf -- "./.claude/quality-gates/${SESSION_ID:?}"
fi

# --- TTL GC (best-effort; setup 을 막지 않는다) ---
python3 "$SCRIPT_DIR/qg-gc.py" --session-id "$SESSION_ID" || true

mkdir -p "$STATE_DIR"

TEMP_FILE="${STATE_FILE}.tmp.$$"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "$TEMP_FILE" << EOF
---
session_id: "$SESSION_ID"
started_at: "$TIMESTAMP"
---

# Quality Gates Pipeline State

## History
- [$TIMESTAMP] Pipeline started
EOF
mv "$TEMP_FILE" "$STATE_FILE"

echo "🔄 Quality Gates Pipeline"
echo ""
echo "Pipeline: scope → differential test → reviewers → re-critique → verdict"
for a in $REMOVED_ARGS; do
  echo "> [quality-gates] \`${a}\` 인자는 제거됐다 — 이제 한 파이프라인이라 게이트 범위를 고르지 않는다. 그대로 진행한다."
done
if [[ "$PLAN_FILE" != "auto" ]]; then
  echo "Plan file: $PLAN_FILE"
fi
echo ""
echo "Pipeline runs in this turn."
