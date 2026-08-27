#!/usr/bin/env bash
# A7·A8·A9·A18 — 쓰기 **도구**가 아니라 git 이 연료라는 것을 실제 턴으로 잰다.
#
# 이 파일만 다른 점: 진짜 `claude -p` 턴을 돈다. API 크레딧과 네트워크가 필요하므로
# 기본은 skip 이고 `DEVBREW_BEHAVIOR_TESTS=1` 일 때만 돈다. 정적 락(형제 파일들)이
# 잡을 수 없는 것 — 훅이 **실제로 발화하는가** — 만 여기서 잰다.
#
# 관측 채널은 모델의 산문이 아니라 **원장 파일**이다. 훅은 emit 보다 먼저 원장을
# 쓰므로(AC7.1), 원장이 그 턴에 훅이 무엇을 했는지의 1차 기록이다. 산문을 grep 하면
# 모델이 문구를 바꾸는 날 조용히 통과한다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd -P)"
. "$REPO_ROOT/shared/tests/assert.sh"
PLUGIN="$REPO_ROOT/plugins/spec-distill"

# ── 관측 채널의 정적 락 (API 호출 0회, opt-in 과 무관하게 항상 돈다) ───────
# 아래 케이스들은 원장의 **키 이름**을 관측 채널로 쓴다. 그 이름이 바뀌면 케이스는
# 조용히 무의미해지는데, 케이스 자신은 기본 skip 이라 그 사실을 알려 줄 수 없다.
# 그래서 이름의 실재만은 여기서 판정한다 — 이 스위트가 skip 될 때도 돈다.
lock_literal() {  # $1=리터럴  $2..=이 중 한 파일에는 있어야 한다
  local lit="$1"; shift
  local f
  for f in "$@"; do
    if grep -qF -- "$lit" "$f" 2>/dev/null; then
      ok "관측 채널 «${lit}» 이 실재한다 ($(basename "$f"))"; return
    fi
  done
  no "관측 채널 «${lit}» 이 사라졌다 — 아래 케이스들이 재는 대상을 잃는다 (찾은 곳: $*)"
}
LEDGER="$PLUGIN/scripts/arm_ledger.py"
DISPATCH="$PLUGIN/hooks/review-dispatch.py"
lock_literal "inflight_paths:"      "$LEDGER" "$DISPATCH"
lock_literal "dispatch_attempts:"   "$LEDGER" "$DISPATCH"
lock_literal "validation_attempts:" "$LEDGER" "$DISPATCH"
lock_literal "discovery_cursor:"    "$DISPATCH" "$LEDGER"

if [ "${DEVBREW_BEHAVIOR_TESTS:-}" != "1" ]; then
  note "SKIP: 실제 claude -p 턴을 도는 행동 케이스 (API 크레딧 소모)."
  note "      돌리려면: DEVBREW_BEHAVIOR_TESTS=1 bash $0"
  note "      스크래치는 DEVBREW_TEST_TMPDIR 로 옮길 수 있다."
  finish; exit
fi

# 도구 부재는 skip 이 아니라 **실패**다 (설계 §8: 추정치를 만들지 않는다).
if ! command -v claude >/dev/null 2>&1; then
  no "claude CLI 가 없다 — 이 케이스들은 측정 불가다"
  finish; exit 1
fi

BASE="${DEVBREW_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
WORK="$(mktemp -d "${BASE%/}/specdistill-behav.XXXXXX")" || exit 1
# macOS 의 /tmp·$TMPDIR 은 심볼릭 링크다 — 정규화하지 않으면 경로 비교가 조용히
# 무너져 무관한 RED 를 대량으로 낸다.
WORK="$(cd "$WORK" && pwd -P)" || exit 1
trap 'rm -rf "$WORK"' EXIT

# 실측 함정: 경로에 `.claude` 가 있으면 Claude Code 가 그 아래 **모든** 파일을
# sensitive file 로 보고 Bash 쓰기를 permission_denied 시킨다 (`--permission-mode
# acceptEdits` 로도, settings 의 allow 규칙으로도 풀리지 않는다). 그러면 이 스위트는
# 아무것도 재지 못하면서 초록으로 보인다.
case "$WORK/" in
  */.claude/*)
    no "스크래치가 .claude 아래다 ($WORK) — Bash 쓰기가 sensitive-file 로 거부돼 측정이 성립하지 않는다. DEVBREW_TEST_TMPDIR 를 .claude 밖으로 지정하라."
    finish; exit 1 ;;
esac

new_repo() {  # $1 = 이름 → 경로를 stdout 으로
  local d="$WORK/$1"
  mkdir -p "$d/docs/superpowers/specs"
  ( cd "$d" && git init -q . \
      && git config user.email t@t && git config user.name t \
      && echo seed > seed.txt && git add -A && git commit -qm seed ) >/dev/null 2>&1
  printf '%s' "$d"
}

# 훅이 `decision:"block"` 을 내면 턴이 이어진다. 리뷰 skill 은 이 하네스에서 막아
# 두었으므로(비용), 없는 skill 을 찾아 파일시스템을 헤매는 것을 막는 한 줄을 얹는다 —
# 그 헤맴은 재는 대상이 아니면서 턴 수만 늘린다. 재시도를 막는 부작용은 **원하는
# 것**이다: 쓰기가 거부되면 조용히 재시도로 덮이지 않고 케이스가 실패로 드러난다.
GUARD='If a hook blocks the turn and demands a skill you do not have, reply in one sentence that it is unavailable and stop. Never search the filesystem for it.'

# `--plugin-dir` 는 설치 캐시를 이긴다 — 이것이 없으면 리포가 아니라 설치본을 잰다.
# `SessionEnd` 를 끄는 이유는 관측 때문이다: 그 훅이 세션 끝에 `<sid>/` 를 지워서
# 원장이 사라진다 (실측 — 이것 때문에 첫 판이 "훅이 안 돈다"로 오판됐다).
# `Stop` 은 건드리지 않는다. 그것이 피검자다.
# 턴 하나의 상한. `</dev/null` 이 짝이다 — 이 리포는 stdin 을 기다리다 멈추는
# 테스트 때문에 이미 한 파일을 무인 실행에서 제외하고 있다. 둘 다 없으면 이 스위트가
# 그 가족의 다음 구성원이 된다. `timeout` 이 없는 기계에서는 상한 없이 돌되(그것이
# 유일한 열화다) stdin 리다이렉트는 언제나 건다.
TIMEOUT_BIN=""
for c in timeout gtimeout; do command -v "$c" >/dev/null 2>&1 && { TIMEOUT_BIN="$c"; break; }; done
[ -n "$TIMEOUT_BIN" ] || note "  (참고: timeout/gtimeout 이 없어 턴 상한 없이 돈다)"

run_turn() {  # $1=리포  $2=sid  $3=프롬프트  [$4=추가 DEVBREW_SKIP_HOOKS 토큰]
  local extra="${4:-}"
  ( cd "$1" \
    && DEVBREW_SPEC_DISTILL_SESSION_ID="$2" \
       DEVBREW_SKIP_HOOKS="spec-distill:SessionEnd${extra:+,$extra}" \
       DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=600 \
       ${TIMEOUT_BIN:+$TIMEOUT_BIN 420} \
       claude -p "$3" \
         --permission-mode acceptEdits \
         --plugin-dir "$PLUGIN" \
         --disallowed-tools Skill Task Agent \
         --append-system-prompt "$GUARD" \
         </dev/null >/dev/null 2>&1 )
}

state_of() { printf '%s' "$1/.claude/spec-distill/$2/state.local.md"; }

# 원장의 **그 블록 안**만 낸다. 블록을 지정하지 않고 파일 전체를 grep 하면 다른
# 블록이 단언을 만족시킨다 — 실측으로 겪었다: `validation_attempts` 안의 «경로: 숫자»
# 를 찾는 패턴이 `inflight_paths` 의 «경로: 2026-…» 타임스탬프에 걸려, Layer 1 을
# 통째로 무력화한 변이에서도 그 줄이 초록으로 남았다.
ledger_block() {  # $1=원장 파일  $2=블록 키
  [ -f "$1" ] || return 0
  awk -v k="$2:" '$0 == k { f = 1; next } f && /^[^ ]/ { f = 0 } f' "$1"
}

# 프롬프트는 heredoc 으로 짓는다 — 본문에 따옴표로 감싼 heredoc 구분자가 들어가므로
# 셸의 작은따옴표 리터럴 안에 넣으면 문자열이 조용히 잘린다(실측: 그 상태로 케이스가
# "문서가 만들어지지 않았다"로 오판됐다).
#
# 본문이 명령을 글자 그대로 못 박는 이유도 실측이다. Claude Code 의 Bash 게이트는
# 두 형태를 **rc 0 인 채로** 거부한다:
#   · heredoc 이 `&&` 뒤에 오면  → `Parser did not consume trailing input`
#   · 구분자가 따옴표 없이 `<<EOF` → `Heredoc with unquoted delimiter undergoes shell expansion`
#   · `sed -i` · `python3 -c` 의 제자리 편집 → `requires explicit approval`
#     (그래서 A8 도 제자리 편집이 아니라 heredoc 덮어쓰기로 잰다 — 커밋된 파일을
#      Bash 로 dirty 하게 만든다는 성질은 그대로다)
# 모델이 둘 중 하나를 고르면 쓰기가 착지하지 않고, 그러면 이 케이스는 훅이 아니라
# 게이트를 잰다. 그래서 디렉터리는 하네스가 미리 만들고, 명령은 단일 heredoc 으로 고정한다.
read -r -d '' PROMPT_WRITE_A <<'ZPROMPT' || true
Run exactly ONE Bash command: a standalone heredoc that writes docs/superpowers/specs/a-design.md. The command must be literally this and nothing else, with no && and no other command before or after it:

cat > docs/superpowers/specs/a-design.md <<'EOF'
# A
content
EOF

The directory already exists. Do not use the Write tool or the Edit tool. Then stop with no commentary.
ZPROMPT

read -r -d '' PROMPT_WRITE_D <<'ZPROMPT' || true
Run exactly ONE Bash command: a standalone heredoc that writes docs/superpowers/specs/d-design.md. The command must be literally this and nothing else, with no && and no other command before or after it:

cat > docs/superpowers/specs/d-design.md <<'EOF'
# D
content
EOF

The directory already exists. Do not use the Write tool or the Edit tool. Then stop with no commentary.
ZPROMPT

read -r -d '' PROMPT_EDIT_B <<'ZPROMPT' || true
Run exactly ONE Bash command: a standalone heredoc that overwrites the existing file docs/superpowers/specs/b-design.md. The command must be literally this and nothing else, with no && and no other command before or after it:

cat > docs/superpowers/specs/b-design.md <<'EOF'
# B
content2
EOF

Do not use the Write tool or the Edit tool. Then stop with no commentary.
ZPROMPT

read -r -d '' PROMPT_WRITE_E <<'ZPROMPT' || true
Run exactly ONE Bash command: a standalone heredoc that writes docs/superpowers/specs/e-design.md. The command must be literally this and nothing else, with no && and no other command before or after it:

cat > docs/superpowers/specs/e-design.md <<'EOF'
# E
TODO: 미정
EOF

The directory already exists. Do not use the Write tool or the Edit tool.

IMPORTANT: after that one command, do not touch the file again. A hook will report a structural problem and ask you to fix it. Do not fix it and do not edit the file — reply in one sentence that you were told to leave it as is, and stop.
ZPROMPT

# ── preflight — 하네스가 살아 있는가 ────────────────────────────────────────
# 헤드리스 `claude -p` 는 여러 방식으로 **rc 0 인 채** 조용히 죽는다: 편집 권한
# 미승인 · 경로가 sensitive · Bash 게이트 거부. 전부 "훅이 발화하지 않았다"와
# 구별되지 않는다. 그래서 먼저 **쓰기가 착지하는지**를 확인하고, 착지하지 않으면
# 케이스를 돌리지 않고 실패로 끝낸다 — 재지 못하는 초록을 내지 않기 위해서다.
PRE="$(new_repo preflight)"
run_turn "$PRE" "preflight0001" 'Use the Bash tool to run exactly: printf "ok\n" > probe.txt   — then stop with no commentary.'
if [ ! -f "$PRE/probe.txt" ]; then
  no "preflight: Bash 쓰기가 착지하지 않았다 — 이 하네스는 아무것도 재지 못한다"
  finish; exit 1
fi
ok "preflight: Bash 쓰기가 착지한다 (하네스가 살아 있다)"

# ── B1 (A7) — Bash 로 쓴 미커밋 스코프 문서가 검증되고 dispatch 된다 ────────
D1="$(new_repo a7)"
run_turn "$D1" "behavA7cases" "$PROMPT_WRITE_A"
S1="$(state_of "$D1" behavA7cases)"
if [ ! -f "$D1/docs/superpowers/specs/a-design.md" ]; then
  no "A7: 문서가 만들어지지 않았다 — 이 케이스는 아무것도 재지 못했다"
else
  ok "A7: Bash 로 스코프 문서가 만들어졌다"
  assert_file_grep "$S1" '^inflight_paths:' "A7: 미커밋 문서가 dispatch 됐다 (in-flight 표시)"
  assert_file_grep "$S1" '^dispatch_attempts:' "A7: dispatch 시도가 원장에 기록됐다"
  assert_contains "$(ledger_block "$S1" inflight_paths)" "a-design.md" \
    "A7: in-flight 블록 **안**이 이 문서를 지목한다"
fi

# ── B2 (A8) — Bash 로 고친 **커밋된** 문서는 검증 창에 들되 arm 되지 않는다 ──
# born 은 status 의 인덱스 자리에서 나온다 — 커밋된 문서는 ` M` 이라 born 이고,
# born 은 dispatch 에서만 빠진다. 검증은 그대로 받는다.
D2="$(new_repo a8)"
printf '# B\n\ncontent\n' > "$D2/docs/superpowers/specs/b-design.md"
( cd "$D2" && git add -A && git commit -qm doc ) >/dev/null 2>&1
run_turn "$D2" "behavA8cases" "$PROMPT_EDIT_B"
S2="$(state_of "$D2" behavA8cases)"
if ! grep -q content2 "$D2/docs/superpowers/specs/b-design.md" 2>/dev/null; then
  no "A8: 문서가 고쳐지지 않았다 — 이 케이스는 아무것도 재지 못했다"
else
  ok "A8: Bash 로 커밋된 문서가 고쳐졌다"
  # 커서는 검증 **루프 밖**에서 전진한다(`review-dispatch.py` 의 `select_keys` 직후).
  # 그러므로 이 단언이 재는 것은 «검증됐다»가 아니라 **«상한 5의 검증 창에 들어갔다»**
  # 뿐이다. 실제로 Layer 1 이 돌았는지는 아래 B5 가 잰다 — 그것을 여기서 주장하면
  # `validate_document` 를 통째로 무력화해도 이 줄이 초록으로 남는다.
  assert_file_grep "$S2" '^discovery_cursor: .*b-design\.md' "A8: 커밋된 문서가 검증 창에 들어갔다 (커서가 전진)"
  assert_file_absent "$S2" '^inflight_paths:' "A8: 커밋된 문서는 arm 되지 않았다"
  assert_file_absent "$S2" '^dispatch_attempts:' "A8: dispatch 시도가 없다"
fi

# ── B3 (A9) — 스코프 **밖** 쓰기는 아무것도 깨우지 않는다 ──────────────────
# 발견은 무상태라 "읽기만 했다"를 훅이 알 방법이 없다 — 조용한 진짜 이유는 후보가
# 0 이라는 것이다. 그래서 이 케이스는 «깨끗한 트리»가 아니라 **«스코프 밖 파일이
# dirty»** 로 잰다. 그쪽이 발견의 술어(경로 접두) 자체를 재고, 동시에 **턴이 정말
# 돌았다는 양성 짝**을 준다.
#
# 양성 짝이 없으면 이 케이스는 fail-open 이다: `claude` 가 인증·쿼터·네트워크로
# 죽어도 원장이 없어 초록이 된다. preflight 는 스위트 머리에서 한 번, 다른 리포에서
# 돌 뿐이라 중간에 죽는 것을 잡지 못한다.
D3="$(new_repo a9)"
printf '# C\n\ncontent\n' > "$D3/docs/superpowers/specs/c-design.md"
( cd "$D3" && git add -A && git commit -qm doc ) >/dev/null 2>&1
run_turn "$D3" "behavA9cases" 'Use the Bash tool to run exactly: printf "ok\n" > notes.txt   — then read docs/superpowers/specs/c-design.md with the Read tool and reply with its first line. Do not modify any file under docs/.'
S3="$(state_of "$D3" behavA9cases)"
if [ ! -f "$D3/notes.txt" ]; then
  no "A9: 스코프 밖 쓰기가 착지하지 않았다 — 턴이 돌지 않았을 수 있다. 이 케이스는 아무것도 재지 못했다"
elif [ -f "$S3" ]; then
  no "A9: 스코프 밖 파일만 dirty 인데 원장이 쓰였다 — $(head -c 300 "$S3")"
else
  ok "A9: 턴이 돌았고(스코프 밖 쓰기 착지) 스코프 밖 dirty 는 조용하다 (원장 write 자체가 없다)"
fi

# ── B4 (A18) — kill switch 가 발견·검증·dispatch 를 **모두** 지배한다 ───────
# B1 과 같은 시나리오이되 `spec-distill:Stop` 을 켠다. 이 케이스가 B1 의 음성
# 대조다: B1 의 ✓ 가 훅에서 나온 것인지 주변 상태에서 나온 것인지를 가른다.
D4="$(new_repo a18)"
run_turn "$D4" "behavA18case" "$PROMPT_WRITE_D" "spec-distill:Stop"
S4="$(state_of "$D4" behavA18case)"
if [ ! -f "$D4/docs/superpowers/specs/d-design.md" ]; then
  no "A18: 문서가 만들어지지 않았다 — 이 케이스는 아무것도 재지 못했다"
else
  ok "A18: Bash 로 스코프 문서가 만들어졌다"
  if [ -f "$S4" ]; then
    no "A18: kill switch 가 켜졌는데 원장이 쓰였다 — $(head -c 300 "$S4")"
  else
    ok "A18: kill switch 가 발견·검증·dispatch 를 모두 껐다"
  fi
fi

# ── B5 (A11) — 구조 검증이 **실제로 돈다**, 그리고 실패한 턴에는 dispatch 가 없다 ──
# 앞의 네 케이스는 전부 구조 검증을 **통과하는** 문서를 쓴다. 그래서 `failures` 가
# 늘 비고, 커서는 검증 루프 밖에서 전진한다 — `validate_document` 가 항상 `[]` 를
# 내도록 무력화해도 네 케이스가 12/12 초록으로 남는다(실측 확인). 즉 릴리스의 표제
# 주장("구조 검증**과** 리뷰 dispatch 를 지난다") 중 절반에 행동 증거가 없었다.
#
# 그 절반을 여기서 잡는다. `validation_attempts:` 는 **검증이 실제로 돌아 실패했을
# 때만** 기록되므로, 이 원장 항목이 Layer 1 이 돌았다는 유일한 직접 관측이다.
# 동시에 `inflight_paths:` 부재가 CHANGELOG 의 계약("구조 실패가 있으면 dispatch 는
# 그 턴에 없다")을 잡고, 이 부재 단언은 위 존재 단언을 양성 짝으로 갖는다.
D5="$(new_repo a11)"
run_turn "$D5" "behavA11case" "$PROMPT_WRITE_E"
S5="$(state_of "$D5" behavA11case)"
E5="$D5/docs/superpowers/specs/e-design.md"
if [ ! -f "$E5" ]; then
  no "A11: 문서가 만들어지지 않았다 — 이 케이스는 아무것도 재지 못했다"
elif ! grep -q 'TODO' "$E5"; then
  # 모델이 훅의 지시를 따라 고쳐 버리면 그 뒤의 Stop 이 통과·dispatch 하므로
  # 아래 단언들이 재는 대상이 사라진다. 조용히 빨강을 내지 않고 그 사실을 말한다.
  no "A11: 모델이 문서를 고쳐 구조 실패가 사라졌다 — 이 케이스는 아무것도 재지 못했다"
else
  ok "A11: Bash 로 구조 실패 문서가 만들어졌고 그대로 남았다"
  assert_file_grep "$S5" '^validation_attempts:' "A11: 구조 검증이 실제로 돌아 실패를 기록했다"
  assert_contains "$(ledger_block "$S5" validation_attempts)" "e-design.md" \
    "A11: 검증 실패 원장의 **그 블록 안**이 이 문서를 지목한다"
  assert_file_absent "$S5" '^inflight_paths:' "A11: 구조 실패 턴에는 dispatch 가 없다"
fi

finish
