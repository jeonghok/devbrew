#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/interview_state.py plugins/spec-distill/skills/pm-interview/SKILL.md plugins/spec-distill/skills/pm-interview/references/state-file.md
# 이어 갈 후보 이름이 셸 리터럴(`ARG_PATH='<후보 경로>'`)에 붙기 전에 허용 글자로 걸러진다 — 심은 이름이 명령을 돌리지 못한다.
# 재현은 임시 레포에서만 돈다.
set -u
ROOT_REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT_REPO/plugins/spec-distill"
. "$ROOT_REPO/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
unset DEVBREW_SPEC_DISTILL_DISABLE DEVBREW_SKIP_HOOKS DEVBREW_SPEC_DISTILL_TTL_HOURS
T="$(mktemp -d)"; [ -n "$T" ] && [ -d "$T" ] || { echo "mktemp 실패"; exit 1; }
T="$(cd "$T" && pwd -P)"; trap 'rm -rf "$T"' EXIT

fence() {   # fence <파일> <마커 이름> → 그 마커 사이 첫 bash 펜스 본문
  awk -v b="<!-- $2:begin -->" -v e="<!-- $2:end -->" '
    index($0,b){f=1;next} index($0,e){f=0} f&&/^```bash$/{c=1;next} f&&c&&/^```$/{c=0;next} f&&c' "$1"
}
ENTRY="$(fence "$SD/skills/pm-interview/SKILL.md" interview-state-entry)"
[ -n "$ENTRY" ] && ok "전제: 진입 펜스를 뽑았다" || no "전제: 진입 펜스가 비었다 — 아래 칸이 공허하다"
in_sess() {   # in_sess <저장소> <스크립트>
  ( cd "$1" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-candname1 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-candname1 bash -c "$2" 2>&1 )
}

R="$T/repo"; mkdir -p "$R"; git -C "$R" init -q -b main
git -C "$R" config user.email t@t.t; git -C "$R" config user.name t
D="$R/docs/superpowers/interview"; mkdir -p "$D"
SEED="$D/2026-10-25-cand-interview.md"
printf -- '---\ntype: interview-seed\n---\n\n## 요청\n\n후보 이름.\n' > "$SEED"
st='---\ntype: interview-state\nseed: docs/superpowers/interview/2026-10-25-cand-interview.md\n---\n\n## R1\n\n- 기록.\n'
BAD="$D/x';touch PWNED;'-interview.state.md"
GOOD="$D/2026-10-25-cand-brief-interview.state.md"
printf -- "$st" > "$BAD"; printf -- "$st" > "$GOOD"
git -C "$R" add -- docs; git -C "$R" commit -q -m seed

o="$(in_sess "$R" "ARG_PATH='$SEED'
$ENTRY")"
cands="$(printf '%s\n' "$o" | sed -n 's/^candidate: //p')"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "interview-state: ASK" "1: 끝나지 않은 상태 파일이 있으면 ASK"
assert_eq "$cands" "$GOOD" "1: 허용 글자 밖 이름(작은따옴표 · 세미콜론)은 후보로 내지 않는다"
assert_contains "$o" "허용 글자" "1: 뺀 후보와 그 사유를 알린다"

# 상태 파일 문서의 지시대로 후보마다 펜스를 다시 돈다 — 무엇이 후보로 나와도 명령이 돌지 않아야 한다.
printf '%s\n' "$cands" | while IFS= read -r c; do
  [ -n "$c" ] || continue
  in_sess "$R" "ARG_PATH='$c'
$ENTRY" >/dev/null
done
[ ! -e "$R/PWNED" ] && ok "2: 후보로 다시 돌아도 심은 명령이 돌지 않는다" || no "2: 심은 이름이 셸 명령을 돌렸다(PWNED 생김)"

# 직접 넘긴 상태 파일 경로도 같은 글자 규칙으로 판정한다(이름 검사가 후보 목록에만 있지 않다).
o="$(cd "$R" && CLAUDE_PLUGIN_ROOT="$SD" python3 "$SD/scripts/interview_state.py" entry --arg "$BAD" --session sess-candname1 2>&1)"
assert_contains "$(printf '%s\n' "$o" | tail -n 1)" "interview-state: REJECT" "3: 허용 글자 밖 상태 파일 경로를 직접 넘기면 REJECT"

finish
