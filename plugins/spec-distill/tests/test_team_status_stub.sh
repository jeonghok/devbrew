#!/usr/bin/env bash
# roadmap_status.py — team 로드맵(머리말 `layout: team`)은 번호 대조까지만 하고 단계 계산은 검사 불가(3)로 멈춘다 ·
# 모르는 layout 값은 번호도 세지 않고 검사 불가 · layout 이 없는 옛 형식은 그대로 계산한다(R1 AC3 · AC12).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_team_status_stub.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"
RS="$S/roadmap_status.py"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
W="$T/repo"
g() { git -C "$W" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false \
        -c init.defaultBranch=main "$@"; }
# js <json 파일> <파이썬 식 — r 이 보고서>. 식은 이 테스트가 쓴 고정 문자열뿐이다.
js() { python3 -c 'import json,sys; r=json.load(open(sys.argv[1], encoding="utf-8")); print(eval(sys.argv[2]))' "$1" "$2"; }
status_of() {  # status_of <json 파일> — 작업 트리의 로드맵으로 계산하고 rc 를 echo 한다
  local rc=0
  (cd "$W" && python3 "$RS" --roadmap-file "$RM" --json) > "$1" 2>/dev/null || rc=$?
  echo "$rc"
}

# ── 픽스처: brief · audit (이 파일만의 글) ───────────────────────────────────
mkdir -p "$W/docs/iv"
cat > "$W/docs/iv/brief.md" <<'MD'
---
type: interview-brief
user_sourced_items:
  - id: C1
    statement: "팀 형식 확정 하나"
  - id: D2
    statement: "팀 형식 결정 둘"
---

# 팀 형식 픽스처 brief

## 0. 한눈에

**결정 목록**

- OQ1 [열림] — 팀 형식의 열린 물음

## 1. Goal · Non-goal

- Goal: 팀 형식 상태 계산을 멈춘다.
- Non-goal: 팀 형식 단계를 센다.

## 2. 제약

- 🗣 confirmed **C1** — 팀 형식 확정 하나 ⟨S1⟩
- ☑ confirmed **D2** — 팀 형식 결정 둘 ⟨S2⟩

## 3. Open Questions

- OQ1: 팀 형식의 열린 물음

## 4. External Landscape

- 없음

## 5. 기각 · Blind Spots

- 없음

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > 팀 형식으로 해 보자

## 7. Next Action

팀 형식 다음.
MD
cat > "$W/docs/iv/brief.audit.md" <<'MD'
# 팀 형식 audit

## 6. 사용자 원문

- **S2** 🗣 발화 (round 1):
  > 번호 대조만 하자

## 7. 원자료

- 없음
MD
git init -q --bare -b main "$T/origin.git"
git init -q -b main "$W"
g remote add origin "$T/origin.git"
g add -- docs && g commit -qm "팀 brief" && g push -q origin main && g fetch -q origin
g remote set-head origin main

# ── 손으로 쓴 team 로드맵 — 해결자의 기본 roadmaps_dir 아래 팀 t1 ─────────────
D="docs/superpowers/roadmaps/t1"
RM="$D/roadmap.md"
mkdir -p "$W/$D/jobs/E1"
team_roadmap() {  # team_roadmap <머리말 layout 줄(없으면 빈 글)> <묶음 값>
  printf -- '---\ntype: roadmap\n%bsource_brief: docs/iv/brief.md\n---\n\n# 팀 픽스처\n\n## 에픽\n\n' "$1"
  printf '### E1 — 손으로 쓴 일\n- 의도: 번호 대조를 본다\n- 범위:\n  - 한다: 대조\n  - 안 한다: 단계\n'
  printf -- '- 의존: 없음\n- 브랜치: feature/team-e1\n- 묶음: %s\n- 경로 예약: 없음\n\n' "$2"
  printf '## 결정 기록\n\n## 재분해 이력\n\n### 2026-11-02 · 손으로 만듦\n- 원문:\n  - 「팀 로드맵을 손으로 쓴다」\n'
}
job_sources() {  # job_sources <ids>
  printf -- '---\ntype: job-sources\njob: E1\nids: [%s]\n---\n\n# E1 — 손으로 쓴 일 · 번호 항목\n\n## 인터페이스\n\n- 받는 것: 없음\n- 넘기는 것: 없음\n' \
    "$1" > "$W/$D/jobs/E1/sources.md"
}
team_roadmap 'layout: team\n' jobs/E1/sources.md > "$W/$RM"
job_sources "C1, D2, OQ1, S1, S2"

# ── team: 번호 대조까지 하고 멈춘다 ──────────────────────────────────────────
rc="$(status_of "$T/team.json")"
assert_eq "$rc" "3" "team 로드맵: 단계 계산은 검사 불가(3)로 멈춘다"
assert_contains "$(js "$T/team.json" "' | '.join(r['unknown_reasons'])")" "이 판은 team 형식의 단계를 계산하지 않는다" "team: 사유를 낸다"
assert_eq "$(js "$T/team.json" "[r[k] for k in ('format_errors','unassigned','orphans','unknown_ids')]")" "[[], [], [], []]" "team: 번호 네 목록은 센다"
assert_eq "$(js "$T/team.json" "sorted(set(b['stage'] for b in r['blocks']))")" "['알 수 없음']" "team: 블록 단계를 옛 계산으로 세지 않는다"
assert_eq "$(js "$T/team.json" "[(b['id'], b['reason'], b['ids']) for b in r['blocks']]")" \
  "[('E1', '이 판은 team 형식의 단계를 계산하지 않는다 — 번호 대조까지만 했다', ['C1', 'D2', 'OQ1', 'S1', 'S2'])]" \
  "team: 블록 사유는 같은 글이고 ids 는 번호 파일의 배정 번호"

# ── 번호 하나를 번호 파일에서 빼면 unassigned 에 나온다(번호 대조가 실제로 그 파일을 읽는다) ──
job_sources "C1, OQ1, S1, S2"
rc="$(status_of "$T/team-d2.json")"
assert_eq "$(js "$T/team-d2.json" "r['unassigned']")" "['D2']" "team: 번호 파일에서 D2 를 빼면 unassigned 에 D2"
assert_eq "$(js "$T/team-d2.json" "[r[k] for k in ('format_errors','orphans','unknown_ids')]")" "[[], [], []]" "team: 나머지 세 목록은 그대로 빈 목록"
assert_eq "$rc" "3" "team: 번호가 빠져도 단계 계산은 멈춘 채(3)"

# ── 번호 파일이 없으면 형식 깨짐 — 번호가 배정되지 않은 것처럼 보이지 않는다 ─────
rm -f "$W/$D/jobs/E1/sources.md"
rc="$(status_of "$T/team-nosrc.json")"
assert_eq "$rc" "3" "team: 번호 파일이 없으면 검사 불가(3)"
assert_contains "$(js "$T/team-nosrc.json" "' | '.join(r['format_errors'])")" "E1 번호 파일이 없다: $D/jobs/E1/sources.md" \
  "team: 형식 깨짐이 없는 번호 파일의 경로를 댄다"
assert_eq "$(js "$T/team-nosrc.json" "r['unassigned']")" "None" "team: 번호 파일이 없으면 미배정으로 세지 않는다"
job_sources "C1, D2, OQ1, S1, S2"

# 옛 형식의 묶음 — 옛 형식 계산과 「모르는 형식을 옛 규칙으로 읽지 않는다」 를 함께 잰다
printf -- '---\ntype: epic-bundle\nepic: E1\nroadmap: %s\nsource_brief: docs/iv/brief.md\nids: [C1, D2, OQ1, S1, S2]\n---\n\n# E1\n' \
  "$RM" > "$W/$D/E1.md"

# ── layout: no-such 로 바꾸면 번호도 세지 않고 검사 불가 ─────────────────────
team_roadmap 'layout: no-such\n' jobs/E1/sources.md > "$W/$RM"
rc="$(status_of "$T/unk.json")"
assert_eq "$rc" "3" "모르는 layout: 검사 불가(3)"
assert_contains "$(js "$T/unk.json" "' | '.join(r['unknown_reasons'])")" "모르는 형식" "모르는 layout: 사유"
assert_contains "$(js "$T/unk.json" "' | '.join(r['unknown_reasons'])")" "layout: no-such (아는 값: team)" "모르는 layout: 사유에 그 값과 아는 값"
assert_eq "$(js "$T/unk.json" "r['unassigned']")" "None" "모르는 layout: 번호도 세지 않는다"
assert_eq "$(js "$T/unk.json" "r['format_errors']")" "[]" "모르는 layout: 옛 형식 규칙으로 형식 깨짐을 내지 않는다"
assert_eq "$(js "$T/unk.json" "[(b['stage'], b['reason']) for b in r['blocks']]")" "[('알 수 없음', '모르는 형식')]" \
  "모르는 layout: 블록은 알 수 없음 · 사유 모르는 형식"
# 옛 규칙으로는 깨짐 없이 셀 수 있는 글(묶음 E1.md)이어도 모르는 형식이면 번호 · 단계를 세지 않는다
team_roadmap 'layout: no-such\n' E1.md > "$W/$RM"
rc="$(status_of "$T/unk-old.json")"
assert_eq "$rc" "3" "모르는 layout(옛 꼴 묶음 값): 검사 불가(3)"
assert_eq "$(js "$T/unk-old.json" "r['unassigned']")" "None" "모르는 layout(옛 꼴 묶음 값): 번호도 세지 않는다"
assert_eq "$(js "$T/unk-old.json" "[(b['stage'], b['reason']) for b in r['blocks']]")" "[('알 수 없음', '모르는 형식')]" \
  "모르는 layout(옛 꼴 묶음 값): 단계를 옛 계산으로 세지 않는다"

# ── 옛 형식(layout 줄 없음 · 묶음 E1.md)은 단계 계산을 그대로 한다 ─────────────
team_roadmap '' E1.md > "$W/$RM"
rc="$(status_of "$T/old.json")"
[ "$rc" != "3" ] && ok "옛 형식: rc 가 3 이 아니다($rc)" || no "옛 형식: rc 가 3 이다 — $(js "$T/old.json" "r['unknown_reasons'] + r['format_errors']")"
assert_not_contains "$(js "$T/old.json" "' | '.join(r['unknown_reasons'])")" "이 판은 team 형식의 단계를 계산하지 않는다" "옛 형식: team 멈춤 사유가 없다"
assert_not_contains "$(js "$T/old.json" "' | '.join(r['unknown_reasons'])")" "모르는 형식" "옛 형식: 모르는 형식 사유가 없다"
assert_eq "$(js "$T/old.json" "[r[k] for k in ('format_errors','unassigned','orphans','unknown_ids')]")" "[[], [], [], []]" "옛 형식: 번호 네 목록이 빈 목록"
assert_eq "$(js "$T/old.json" "'알 수 없음' in [b['stage'] for b in r['blocks']]")" "False" "옛 형식: 블록 단계를 계산한다(알 수 없음이 아니다)"

finish
