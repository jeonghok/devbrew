#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/raw_source.py plugins/spec-distill/scripts/roadmap_write.py
#
# 새 첫 칸(원자료 사본이 든 S1)이 옆 로드맵 생성기와 에픽 묶음까지 따라가는지 잰다(AC16 · AC17 · AC19).
#   original — 원자료 사본(intent/original.md)의 사용자 원문 구간에 framing 기록의 두 절이 있고 seed 전문은 어디에도 없다.
#   create   — 검사기 네 목록이 비고, 에픽 묶음의 사용자 원문 절에 같은 두 절이 있다.
#   untouched — 옆 생성기 파일은 기본 브랜치와 같다.
#   변이 — place 를 건너뛰고 S1 에 seed 전문을 인용으로 실은 레포에서는 같은 판정이 실패한다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/scripts/raw_source.py"
  echo "plugins/spec-distill/scripts/roadmap_write.py"; exit 0
fi
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
SD="$ROOT/plugins/spec-distill"
RW="$SD/scripts/roadmap_write.py"
RS="$SD/scripts/raw_source.py"
FX="$SD/tests/raw_source_fixture.py"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
RD="docs/superpowers/roadmaps/"

g_() { local r="$1"; shift; git -C "$r" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false \
         -c core.hooksPath=/dev/null "$@"; }

# build <이름> <placed|skipped|seeded> — $T/<이름>/repo 에 임시 레포를 짓고 결과 글은 $T/<이름>/ 아래 파일로 남긴다.
build() {
  local d="$T/$1" how="$2" W
  mkdir -p "$d"
  W="$d/repo"
  python3 -I -B "$FX" make "$W" > "$d/make.txt" 2>&1 || { echo "픽스처 실패: $(cat "$d/make.txt")"; return 1; }
  # 결과물 셋을 작은 §0–§7 brief 로 다시 쓴다(make_repo 는 그대로 — 지휘자 판정 R-F2)
  cat > "$W/docs/iv/t-brief-interview.md" <<'MD'
---
type: interview-brief
audit_file: t-brief-interview.audit.md
user_sourced_items:
  - id: C1
    statement: "읽는 쪽부터 고친다"
---

# 아래쪽 이음매 brief

## 0. 한눈에

**결정 목록**

- OQ1 [열림] — 어느 쪽부터 고칠지

## 1. Goal · Non-goal

- Goal: 읽는 쪽을 먼저 고친다.
- Non-goal: 쓰는 쪽은 이번에 안 본다.

## 2. 제약

- 🗣 confirmed **C1** — 읽는 쪽부터 고친다 ⟨S2⟩

## 3. Open Questions

- OQ1: 어느 쪽부터 고칠지

## 4. External Landscape

- 바깥 사례 하나 «ext-a» — [취함] [→ OQ1]

## 5. 기각 · Blind Spots

- 기각 — 없음 — 해당 없음
- 위험 — 숨은 가정: 읽는 쪽이 따로 있다 — 근거 약함

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > 대시보드가 너무 느려요.
- **S2** 🗣 답:
  > 읽는 쪽

## 7. Next Action

다음 단계로 간다.
MD
  if [ "$how" = "skipped" ]; then
    # 변이 — place 를 건너뛰고 S1 에 seed 전문을 인용으로 싣는다
    python3 -I -B - "$W/docs/iv/t-brief-interview.md" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
old = "  > 대시보드가 너무 느려요.\n"
assert t.count(old) == 1
open(p, "w", encoding="utf-8").write(t.replace(old, "  > seed전문표지 — 모델이 줄인 요청 한 문단.\n"))
PY
  fi
  cat > "$W/docs/iv/t-brief-interview.audit.md" <<'MD'
---
type: interview-audit
payload: t-brief-interview.md
---

# 아래쪽 이음매 — audit

## 6. 사용자 원문

- **S2** 🗣 답 (round 1):
  > 읽는 쪽
MD
  cat > "$W/docs/iv/t-brief-interview.state.md" <<'MD'
---
type: interview-state
seed: docs/iv/t-seed-interview.md
user_statements:
- id: S2
  source: verbatim
  round: 1
  text: "읽는 쪽"
---
MD
  if [ "$how" = "seeded" ]; then
    # 변이 — place 는 돌리되 §6 의 S2 인용에 seed 전문 표지를 더 싣는다(첫 칸의 양의 글은 그대로 있다)
    python3 -I -B - "$W/docs/iv/t-brief-interview.md" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
old = "\n  > 읽는 쪽\n"
assert t.count(old) == 1
open(p, "w", encoding="utf-8").write(t.replace(old, "\n  > 읽는 쪽\n  > seed전문표지\n"))
PY
  fi
  if [ "$how" = "placed" ] || [ "$how" = "seeded" ]; then
    (cd "$W" && python3 -I -B "$RS" place --interview docs/iv/t-brief-interview.state.md) > "$d/place.txt" 2>&1
    echo "$?" > "$d/place.rc"
  fi
  git init -q --bare -b main "$d/origin.git"
  if ! { g_ "$W" add -- docs && g_ "$W" commit -qm "brief" && g_ "$W" branch -M main \
    && g_ "$W" remote add origin "$d/origin.git" && g_ "$W" push -q origin main \
    && g_ "$W" fetch -q origin && g_ "$W" remote set-head origin main; } >> "$d/git.txt" 2>&1; then
    echo "레포 준비의 git 연쇄가 실패했다($1) — $(tail -c 300 "$d/git.txt")"
    return 1
  fi
  {
    printf '# state\n\n## 분해안\n\n'
    printf '%s\n' '| 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 |'
    printf '%s\n' '|---|---|---|---|---|---|---|---|---|---|---|'
    printf '%s\n' '| E1 | 한 에픽 | 묶음 | 읽는 쪽 | 한다 읽기 / 안 한다 쓰기 | 없음 | feature/e1 | 없음 | C1 · OQ1 · K1 · «ext-a» · S1 · S2 | 없음 | 없음 |'
  } > "$d/plan.md"
  (cd "$W" && python3 -I -B "$RW" original --brief docs/iv/t-brief-interview.md --out "${RD}t1" \
      --framing-audit docs/iv/t-seed-interview.audit.md) > "$d/orig.txt" 2>&1
  echo "$?" > "$d/orig.rc"
  (cd "$W" && python3 -I -B "$RW" create --brief docs/iv/t-brief-interview.md --audit docs/iv/t-brief-interview.audit.md \
      --plan-table "$d/plan.md" --out "${RD}rm1" --title "이음매 로드맵" --date 2026-11-18 --approval "이대로 승인 (권장)") \
      > "$d/create.txt" 2>&1
  echo "$?" > "$d/create.rc"
}

has() { grep -qF -- "$2" "$1" 2>/dev/null; }

# user_span <original.md> <출력 파일> — 출처 줄에 `· 사용자 원문 ·` 이 든 구간(다음 출처 줄 앞까지)의 글을 뜬다
user_span() {
  python3 -I -B - "$1" "$2" <<'PY'
import sys
src, out = sys.argv[1:3]
keep, on = [], False
for ln in open(src, encoding="utf-8").read().split("\n"):
    if "· 사용자 원문 ·" in ln:
        on = True
    elif on and ln.startswith("<!-- "):
        on = False
    if on:
        keep.append(ln)
open(out, "w", encoding="utf-8").write("\n".join(keep))
PY
}
# section6 <묶음 파일> <출력 파일> — `## 6. 사용자 원문` 절(다음 `## ` 제목 앞까지)의 글을 뜬다
section6() {
  python3 -I -B - "$1" "$2" <<'PY'
import sys
src, out = sys.argv[1:3]
keep, on = [], False
for ln in open(src, encoding="utf-8").read().split("\n"):
    if ln.startswith("## "):
        on = ln.startswith("## 6. 사용자 원문")
    if on:
        keep.append(ln)
open(out, "w", encoding="utf-8").write("\n".join(keep))
PY
}
# 판정은 양의 글(pos)과 seed 부재(seedfree) 두 갈래 — 변이가 어느 갈래로 실패하는지 따로 본다
span_pos() { user_span "$1" "$2"; has "$2" "    ## 1. 원문" && has "$2" "원문절표지" && has "$2" "당신이 답한 것"; }
bundle_pos() { section6 "$1" "$2"; has "$2" "    ## 1. 원문" && has "$2" "원문절표지" && has "$2" "    ## 2. 질문 전체" && has "$2" "당신이 답한 것"; }
seedfree() { ! has "$1" "seed전문표지"; }   # seedfree <뜬 구간 파일> — span_pos · bundle_pos 가 뜬 파일을 받는다
span_ok() { span_pos "$1" "$2" && seedfree "$2"; }
bundle_ok() { bundle_pos "$1" "$2" && seedfree "$2"; }

build good placed || { echo "good 레포 실패"; exit 1; }
G="$T/good"; GW="$G/repo"
ORIG="$GW/${RD}t1/intent/original.md"
E1="$(ls "$GW/${RD}rm1/"E1.md "$GW/${RD}rm1/"*/E1.md 2>/dev/null | head -1)"

assert_eq "$(cat "$G/place.rc")" "0" "place_rc: 첫 칸을 싣는다"
assert_eq "$(cat "$G/orig.rc")" "0" "orig_rc: original rc 0 (AC17)"
if [ -f "$ORIG" ]; then ok "original.md 가 있다"; else no "original.md 없음 — $(cat "$G/orig.txt")"; fi
if span_ok "$ORIG" "$G/span.txt"; then ok "orig_user_span: 사용자 원문 구간에 원문 절 · 질문 절이 있고 seed 전문이 없다"
else no "orig_user_span — 구간: $(head -c 400 "$G/span.txt" 2>/dev/null)"; fi
if has "$ORIG" "seed전문표지"; then no "orig_no_seed_anywhere: original.md 에 seed 전문이 있다"
else ok "orig_no_seed_anywhere: original.md 에 seed 전문이 없다"; fi
assert_eq "$(grep -cF '원문절표지' "$ORIG" 2>/dev/null)" "2" "orig_positive_pair: 원문절표지 가 둘(framing 구간 · brief 구간)"
assert_eq "$(cat "$G/create.rc")" "0" "create_rc: create rc 0 — $(tail -c 300 "$G/create.txt")"
assert_contains "$(cat "$G/create.txt")" "검사기 네 목록이 비었다" "create_four_empty: 검사기 네 목록이 비었다 (AC19)"
if [ -n "$E1" ] && bundle_ok "$E1" "$G/b6.txt"; then ok "bundle_user_span: E1.md 의 \`## 6. 사용자 원문\` 절에 두 절이 있고 seed 전문이 없다 (AC16)"
else no "bundle_user_span — E1=${E1:-없음}"; fi

# 변이 둘 — 실패가 어느 갈래에서 나는지 가른다
#   bad    : place 건너뜀 + S1 에 seed 전문 인용 → 양의 글이 없어 pos 갈래가 실패한다
#   seeded : place 는 돌림 + §6 의 S2 에 seed 전문 표지 → pos 는 통과하고 seedfree 갈래만 실패한다
build bad skipped || { echo "bad 레포 실패"; exit 1; }
B="$T/bad"; BW="$B/repo"
BE1="$(ls "$BW/${RD}rm1/"E1.md "$BW/${RD}rm1/"*/E1.md 2>/dev/null | head -1)"
assert_eq "$(cat "$B/orig.rc")$(cat "$B/create.rc")" "00" "mutant_bad_rc: 변이 레포에서도 두 생성기는 rc 0 — 실패는 글 판정에서만 난다"
if span_pos "$BW/${RD}t1/intent/original.md" "$B/span.txt"; then no "mutant_bad_span_pos: place 를 건너뛴 레포에서 양의 글이 있다(이빨 없음)"
else ok "mutant_bad_span_pos: place 를 건너뛴 레포는 양의 글(원문 절 표지)이 없어 실패한다"; fi
if [ -n "$BE1" ] && bundle_pos "$BE1" "$B/b6.txt"; then no "mutant_bad_bundle_pos: place 를 건너뛴 레포의 묶음에 양의 글이 있다(이빨 없음)"
else ok "mutant_bad_bundle_pos: place 를 건너뛴 레포의 묶음은 양의 글이 없어 실패한다"; fi

build seeded seeded || { echo "seeded 레포 실패"; exit 1; }
S="$T/seeded"; SW="$S/repo"
SE1="$(ls "$SW/${RD}rm1/"E1.md "$SW/${RD}rm1/"*/E1.md 2>/dev/null | head -1)"
assert_eq "$(cat "$S/place.rc")$(cat "$S/orig.rc")$(cat "$S/create.rc")" "000" "mutant_seeded_rc: place · original · create 모두 rc 0"
if span_pos "$SW/${RD}t1/intent/original.md" "$S/span.txt"; then ok "mutant_seeded_span_pos: 양의 글은 통과(실패는 seed 갈래에서만 난다)"
else no "mutant_seeded_span_pos: 양의 글이 없다 — 변이가 두 갈래를 함께 건드렸다"; fi
if seedfree "$S/span.txt"; then no "mutant_seeded_span_seed: 구간에 seed전문표지 가 있는데 seedfree 가 통과했다(이빨 없음)"
else ok "mutant_seeded_span_seed: 구간의 seed전문표지 를 seedfree 가 잡는다"; fi
if [ -n "$SE1" ] && bundle_pos "$SE1" "$S/b6.txt"; then ok "mutant_seeded_bundle_pos: 묶음의 양의 글은 통과"
else no "mutant_seeded_bundle_pos: 묶음의 양의 글이 없다 — 변이가 두 갈래를 함께 건드렸다"; fi
if seedfree "$S/b6.txt"; then no "mutant_seeded_bundle_seed: 묶음 §6 에 seed전문표지 가 있는데 seedfree 가 통과했다(이빨 없음)"
else ok "mutant_seeded_bundle_seed: 묶음 §6 의 seed전문표지 를 seedfree 가 잡는다"; fi

# untouched — 옆 생성기 파일이 기본 브랜치와 같다. 비교 기준을 못 구하면 건너뛴다(빈 기준으로 통과하지 않는다).
SIDE="plugins/spec-distill/scripts/team_write.py plugins/spec-distill/scripts/team_files.py
plugins/spec-distill/scripts/team_check.py plugins/spec-distill/scripts/roadmap_write.py
plugins/spec-distill/scripts/roadmap_model.py plugins/spec-distill/scripts/roadmap_render.py
plugins/spec-distill/tests/test_team_write.sh plugins/spec-distill/tests/test_team_files.py"
MB=""
if git -C "$ROOT" rev-parse -q --verify origin/HEAD >/dev/null 2>&1; then
  MB="$(git -C "$ROOT" merge-base HEAD origin/HEAD 2>/dev/null)"
fi
if [ -n "$MB" ]; then
  # shellcheck disable=SC2086
  assert_eq "$(git -C "$ROOT" diff --stat "$MB" -- $SIDE)" "" "untouched: 옆 생성기 파일이 기본 브랜치와 같다"
  # 음의 짝 — 같은 diff 가 이 브랜치에서 바뀐 파일(이 테스트)에는 출력을 낸다
  if [ -n "$(git -C "$ROOT" diff --stat "$MB" -- plugins/spec-distill/tests/test_raw_source_downstream.sh)" ]; then
    ok "untouched_negative_pair: 같은 diff 가 바뀐 파일에는 출력을 낸다"
  else no "untouched_negative_pair: 바뀐 파일에도 diff 가 비었다 — 기준이 틀렸다"; fi
else
  note "untouched 건너뜀 — origin/HEAD 나 merge-base 를 구하지 못했다"
fi
finish
