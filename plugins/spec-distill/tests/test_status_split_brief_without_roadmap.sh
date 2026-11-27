#!/usr/bin/env bash
# 상태 보기(control_plane.py · roadmap_status.py)가 「나눈다」 결과물(§7 첫 줄 `분해됨 — <없는 로드맵 경로>`)이
# 커밋돼 있고 그 로드맵은 아직 없는 저장소에서 오류 없이 도는지 잰다(front-stage-restructure AC18).
# 호출: control_plane.py show · statusline 은 로드맵 인자 없이(목록 모드). roadmap_status.py 는 인자 없는 호출이
# 없다(roadmap · --roadmap-file 중 하나가 필수, 없으면 rc 2) — 같은 저장소의 있는 로드맵을 주어 돌리고,
# 양성 대조로 --roadmap-file <없는 경로> 가 「로드맵을 못 읽었다」 · rc 3 을 내는지 본다(시험이 오류를 볼 수 있다는 증거).
# 환경: RS_SCRIPT 로 roadmap_status.py 대신 다른 사본을 가리킬 수 있다(변이 시험용).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_status_split_brief_without_roadmap.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset DEVBREW_SPEC_DISTILL_DISABLE DEVBREW_SKIP_HOOKS CLAUDE_CONFIG_DIR
SD="$ROOT/plugins/spec-distill/scripts"
RS="${RS_SCRIPT:-$SD/roadmap_status.py}"
CP="$SD/control_plane.py"
FX="$ROOT/plugins/spec-distill/tests/fixtures"   # 결과물이 가리키는 brief · audit 본문
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
W="$T/work"
MISSING="docs/superpowers/roadmaps/nope/roadmap.md"   # 결과물 §7 이 가리키는, 없는 로드맵
g() { git -C "$W" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }

git init -q --bare -b main "$T/origin.git"
git clone -q "$T/origin.git" "$W" 2>/dev/null
# 「나눈다」 결과물 세 파일은 상태 보기가 실제로 여는 자리(레포 설정의 의도 폴더 기본값)에 정본 이름 꼴로 둔다.
# 같은 폴더에 짝 결과물이 없는 진행 중 상태 파일 하나를 함께 둔다 — 상태 보기가 그 폴더를 읽는다는 양의 짝이다.
IV="docs/superpowers/intent"
SPLIT="$IV/2026-11-20-split-context"
mkdir -p "$W/$IV" "$W/docs/superpowers/roadmaps/rm" "$W/.claude/spec-distill"
python3 -I - "$FX/status-split-brief.md" "$W/$SPLIT.md" "$MISSING" <<'PY'
import sys
src, dst, missing = sys.argv[1:4]
t = open(src, encoding="utf-8").read()
head = "## 7. Next Action\n"
assert t.count(head) == 1
open(dst, "w", encoding="utf-8").write(t.replace(head, head + "\n- `분해됨 — %s`\n" % missing, 1))
PY
cp "$FX/status-split-brief.audit.md" "$W/$SPLIT.audit.md"
state_body() { printf -- '---\ntype: context-state\nseed: 없음\nsession_id: %s\nphase: %s\nresearch_dispatches: {repo: 1}\nresearch_limit: 12\n---\n\n## audit §2 대기 줄\n\n' "$1" "$2"; }
state_body 5a1170aa 분해됨 > "$W/$SPLIT.state.md"
state_body 0e1b2c3d 1 > "$W/$IV/2026-11-20-wip-context.state.md"
{ printf -- '---\ntype: roadmap\nsource_brief: docs/br/b.md\n---\n\n# 로드맵\n\n## 에픽\n\n'
  printf '## 지휘 절차\n\n1. fetch\n\n## 결정 기록\n\n쉬운 말 PR 은 이미 머지됐다 — 블록 없음.\n\n## 재분해 이력\n\n- 없음\n\n## 위험 번호표\n\n- K1 — 위험 — 숨은 가정: 가정 하나 — 근거 없음\n- K2 — 위험 — 실패 양식: 실패 하나 — 근거 없음\n'
} > "$W/docs/superpowers/roadmaps/rm/roadmap.md"
mkdir -p "$W/docs/br"
cp "$FX/status-split-brief.md" "$W/docs/br/b.md"
cp "$FX/status-split-brief.audit.md" "$W/docs/br/b.audit.md"
g add -A -- docs && g commit -qm "split brief without roadmap" && g push -q origin main
g remote set-head origin main
[ ! -e "$W/$(dirname "$MISSING")" ] && ok "fixture: 결과물이 가리키는 로드맵 폴더가 없다" || no "fixture: 로드맵 폴더가 있다"
grep -qF "분해됨 — $MISSING" "$W/$SPLIT.md" && ok "fixture: 결과물 §7 에 분해됨 줄이 있다" || no "fixture: 결과물에 분해됨 줄이 없다"

run() {  # run <이름> <명령...> — W 에서 돌려 OUT_<이름> · ERR_<이름> · RC_<이름> 에 담는다
  local n="$1"; shift
  ( cd "$W" && "$@" </dev/null >"$T/$n.out" 2>"$T/$n.err" ); eval "RC_$n=$?"
}
check_clean() {  # check_clean <이름> <허용 rc 목록> — 오류 아님 · Traceback 없음 · 결과물 · 분해됨 을 이유로 한 오류 줄 없음
  local n="$1" allowed="$2" rc ok_rc=0 w
  eval "rc=\$RC_$n"
  for w in $allowed; do [ "$rc" = "$w" ] && ok_rc=1; done
  [ "$ok_rc" = 1 ] && ok "$n: rc ${rc} 는 정상 · 안내 값(${allowed})" || { no "$n: rc ${rc} (허용: ${allowed})"; grep -v '^머지됨' "$T/$n.out" | cut -c1-200 | head -12; }
  assert_file_absent "$T/$n.err" 'Traceback' "$n: stderr 에 Traceback 이 없다"
  assert_file_absent "$T/$n.out" "split-context|분해됨|$MISSING" "$n: 출력이 결과물 경로 · 분해됨 을 말하지 않는다"
  assert_file_absent "$T/$n.err" "split-context|분해됨|$MISSING" "$n: stderr 가 결과물 경로 · 분해됨 을 말하지 않는다"
}

run cp_show python3 "$CP" show
check_clean cp_show "0"
# 양의 짝 — 같은 폴더의 진행 중 컨텍스트 쌓기는 보인다(상태 보기가 결과물이 놓인 폴더를 실제로 읽는다)
assert_file_grep "$T/cp_show.out" "wip-context" "양의 짝: show 가 같은 의도 폴더의 진행 중 상태 파일을 보인다"
run cp_line python3 "$CP" statusline
check_clean cp_line "0"
run rs_real python3 "$RS" docs/superpowers/roadmaps/rm/roadmap.md
check_clean rs_real "0 1"

# 양성 대조 — 없는 로드맵을 직접 주면 「못 읽었다」 와 rc 3 이 난다(이 시험이 오류를 볼 수 있다)
run rs_missing python3 "$RS" --roadmap-file "$MISSING"
assert_eq "$RC_rs_missing" "3" "양성 대조: 없는 로드맵 파일은 rc 3"
assert_file_grep "$T/rs_missing.out" '로드맵을 못 읽었다' "양성 대조: 「로드맵을 못 읽었다」 가 나온다"

finish
