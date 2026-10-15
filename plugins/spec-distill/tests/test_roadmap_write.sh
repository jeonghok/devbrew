#!/usr/bin/env bash
# roadmap_write.py — 분해안 표로 로드맵 · 묶음을 만들고 검증 · 되돌린다(R4 AC4 · AC5 · AC10).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_roadmap_write.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"
RW="$S/roadmap_write.py"
RS="$S/roadmap_status.py"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
W="$T/repo"
g() { git -C "$W" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false \
        -c init.defaultBranch=main "$@"; }
four_empty() {   # four_empty <로드맵> — 검사기 네 목록이 모두 빈 목록이면 ok
  (cd "$W" && python3 "$RS" --roadmap-file "$1" --json) | python3 -c '
import json, sys
r = json.load(sys.stdin)
print("ok" if all(r.get(k) == [] for k in ("format_errors", "unassigned", "orphans", "unknown_ids")) else r)'
}
tree_of() { (cd "$1" && find . -type f | LC_ALL=C sort); }
assert_file_has() {  # assert_file_has <파일> <고정 문자열> <라벨>
  if grep -qF -- "$2" "$1" 2>/dev/null; then ok "$3"; else no "$3 — 없음: $2"; fi
}

# ── 픽스처: brief · audit (test_roadmap_status.sh 와 다른 글) ────────────────
mkdir -p "$W/docs/iv"
cat > "$W/docs/iv/brief.md" <<'MD'
---
type: interview-brief
user_sourced_items:
  - id: C1
    statement: "첫 확정"
  - id: D2
    statement: "둘째 확정"
  - id: C3
    statement: "셋째 확정"
---

# 픽스처 brief

## 0. 한눈에

**결정 목록**

- OQ1 [열림] — 열린 하나
- OQ2 [해결 ⟨S2⟩] — 닫힌 하나

## 1. Goal · Non-goal

- Goal: 픽스처 목표.
- Non-goal: 픽스처 비목표.

## 2. 제약

- 🗣 confirmed **C1** — 첫 확정 ⟨S1⟩
- ☑ confirmed **D2** — 둘째 확정 ⟨S2⟩
- 🗣 confirmed **C3** — 셋째 확정 ⟨S1⟩

## 3. Open Questions

- OQ1: 열린 하나

## 4. External Landscape

- 바깥 하나 «ext-a» — [취함] [→ OQ1]
- 바깥 둘 «ext-b» — [중립] [→ 없음]

## 5. 기각 · Blind Spots

- 기각 — 다른 길 — verdict: kept — ST1 — 부착 2/2
- 위험 — 숨은 가정: 가정 — 근거 약함
- 위험 — 실패 양식: 실패 — 근거 약함
- 위험 — 사실 | 사실 하나 — RC1 (a/b.py) [RC1 → OQ1]

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > 처음 말

## 7. Next Action

다음.
MD
cat > "$W/docs/iv/brief.audit.md" <<'MD'
# audit

## 6. 사용자 원문

- **S2** 🗣 발화 (round 1):
  > 둘째 말
- **S3** ☑ 선택 (round 2):
  > 셋째 말

## 7. 기타

- 없음
MD
git init -q --bare -b main "$T/origin.git"
git init -q -b main "$W"
g remote add origin "$T/origin.git"
g add -- docs && g commit -qm brief && g push -q origin main && g fetch -q origin

HEAD_ROW='| 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 |'
SEP_ROW='|---|---|---|---|---|---|---|---|---|---|---|'
P1_ROW='| P1 | 결정 하나 | 결정 | 무엇을 정한다 | 한다 결정 / 안 한다 코드 | 없음 | 없음 | 없음 | S3 · OQ2 | 없음 | 없음 |'
E1_ROW='| E1 | 첫 에픽 | 묶음 | 첫 의도 | 한다 가 / 안 한다 나 | P1 | feature/e1 | a/x.py | C1 · D2 · OQ1 · RC1 · K1 · «ext-a» · S1 · S2 | 없음 | E2 에 x |'
E2_ROW='| E2 | 둘째 에픽 | 묶음 | 둘째 의도 | 한다 다 / 안 한다 라 | E1 | feature/e2 | 없음 | C3 · ST1 · K2 · «ext-b» · S1 | E1 의 x | 없음 |'
table() {  # table <파일> <행들…>
  local f="$1"; shift
  { printf '# state\n\n## 분해안\n\n%s\n%s\n' "$HEAD_ROW" "$SEP_ROW"; printf '%s\n' "$@"; } > "$f"
}
create() {  # create <표 파일> <폴더 레포 상대> — rc 를 echo 한다
  local rc=0
  (cd "$W" && python3 "$RW" create --brief docs/iv/brief.md --audit docs/iv/brief.audit.md \
     --plan-table "$1" --out "$2" --title "픽스처 일" --date 2026-10-15 --approval "이대로 승인 (권장)") \
     > "$T/out.txt" 2>&1 || rc=$?
  echo "$rc"
}

# ── create 성공 (AC4) ───────────────────────────────────────────────────────
table "$T/state.md" "$P1_ROW" "$E1_ROW" "$E2_ROW"
assert_eq "$(create "$T/state.md" docs/rm)" "0" "create: rc 0"
assert_eq "$(tree_of "$W/docs/rm")" "$(printf './E1.md\n./E2.md\n./roadmap.md')" "create: 로드맵 하나 · 묶음 둘"
assert_eq "$(four_empty docs/rm/roadmap.md)" "ok" "create: 검사기 네 목록이 빈 목록"
assert_file_has "$W/docs/rm/E1.md" "roadmap: docs/rm/roadmap.md" "묶음 frontmatter 의 roadmap 은 레포 상대경로"
assert_file_has "$W/docs/rm/E1.md" "source_brief: docs/iv/brief.md" "묶음 frontmatter 의 source_brief 는 레포 상대경로"
assert_file_has "$W/docs/rm/E1.md" "- 받는 것: 없음" "묶음 §7 받는 것은 표 칸 그대로"
assert_file_has "$W/docs/rm/E2.md" "- 받는 것: E1 의 x" "묶음 §7 받는 것은 표 칸 그대로(둘째)"
assert_file_has "$W/docs/rm/E1.md" "- 넘기는 것: E2 에 x" "묶음 §7 넘기는 것은 표 칸 그대로"
assert_file_has "$W/docs/rm/roadmap.md" "- 2026-10-15 · 처음 로드맵 · 승인 원문 「이대로 승인 (권장)」" "재분해 이력 첫 줄"
assert_file_has "$T/state.md" "## 생성 기록" "표 파일에 생성 기록 절"
assert_file_has "$T/state.md" "- docs/rm/E2.md" "생성 기록에 묶음 경로"

# ── 다시 생성 — 기록에 있는 파일만 덮어쓴다 (AC4 재생성) ─────────────────────
table "$T/state2.md" "$P1_ROW" "$E1_ROW" "${E2_ROW/둘째 의도/둘째 의도 고침}"
sed -n '/^## 생성 기록/,$p' "$T/state.md" >> "$T/state2.md"
cp "$W/docs/rm/E1.md" "$T/E1.before"
assert_eq "$(create "$T/state2.md" docs/rm)" "0" "다시 생성: rc 0"
assert_file_has "$W/docs/rm/E2.md" "- 의도: 둘째 의도 고침" "다시 생성: 바뀐 표가 묶음에 실린다"
cmp -s "$T/E1.before" "$W/docs/rm/E1.md" && ok "다시 생성: 안 바뀐 묶음은 같은 바이트" || no "다시 생성: E1 묶음이 바뀌었다"

# ── 기록에 없는 파일은 덮어쓰지 않는다 ──────────────────────────────────────
mkdir -p "$W/docs/rm2" && printf 'hand\n' > "$W/docs/rm2/roadmap.md"
table "$T/state3.md" "$P1_ROW" "$E1_ROW" "$E2_ROW"
cp "$T/state3.md" "$T/state3.before"
assert_eq "$(create "$T/state3.md" docs/rm2)" "1" "기록 밖 파일: rc 1"
assert_file_has "$T/out.txt" "덮어쓰지 않는다" "기록 밖 파일: 사유를 낸다"
assert_eq "$(cat "$W/docs/rm2/roadmap.md")" "hand" "기록 밖 파일: 바이트 그대로"
assert_eq "$(tree_of "$W/docs/rm2")" "./roadmap.md" "기록 밖 파일: 새 파일 없음"
cmp -s "$T/state3.before" "$T/state3.md" && ok "기록 밖 파일: 표 파일 그대로" || no "기록 밖 파일: 표 파일이 바뀌었다"

# ── 검증 실패 — 만든 파일을 지우고 미리 있던 파일은 그대로 (AC5) ────────────
mkdir -p "$W/docs/rm3" && printf 'keep\n' > "$W/docs/rm3/keep.md"
table "$T/state4.md" "${P1_ROW/S3 · OQ2/S3 · OQ2 · C99}" "$E1_ROW" "$E2_ROW"
cp "$T/state4.md" "$T/state4.before"
assert_eq "$(create "$T/state4.md" docs/rm3)" "1" "unknown_ids: rc 1"
assert_file_has "$T/out.txt" "unknown_ids" "unknown_ids: 사유에 목록 이름"
assert_file_has "$T/out.txt" "C99" "unknown_ids: 사유에 번호"
assert_eq "$(tree_of "$W/docs/rm3")" "./keep.md" "unknown_ids: 만든 파일이 남지 않는다"
assert_eq "$(cat "$W/docs/rm3/keep.md")" "keep" "unknown_ids: 미리 있던 파일은 그대로"
cmp -s "$T/state4.before" "$T/state4.md" && ok "unknown_ids: 생성 기록을 쓰지 않는다" || no "unknown_ids: 표 파일이 바뀌었다"

table "$T/state5.md" "$P1_ROW" "$E1_ROW" "${E2_ROW/ · K2/}"
assert_eq "$(create "$T/state5.md" docs/rm4)" "1" "unassigned: rc 1"
assert_file_has "$T/out.txt" "unassigned" "unassigned: 사유에 목록 이름"
[ -e "$W/docs/rm4" ] && no "unassigned: 만든 폴더가 남았다" || ok "unassigned: 만든 폴더도 남지 않는다"

table "$T/state6.md" "$P1_ROW" "${E1_ROW/ · S2 |/ |}" "$E2_ROW"
assert_eq "$(create "$T/state6.md" docs/rm5)" "1" "orphans: rc 1"
assert_file_has "$T/out.txt" "orphans" "orphans: 사유에 목록 이름"
assert_file_has "$T/out.txt" "S2" "orphans: 사유에 번호"

# ── 실패 뒤 재실행 — 표를 고치면 성공한다 ───────────────────────────────────
table "$T/state4.md" "$P1_ROW" "$E1_ROW" "$E2_ROW"
assert_eq "$(create "$T/state4.md" docs/rm3)" "0" "실패 뒤 재실행: rc 0"
assert_eq "$(four_empty docs/rm3/roadmap.md)" "ok" "실패 뒤 재실행: 검사기 네 목록이 빈 목록"

# ── 표 오류 · 사용법 오류 ────────────────────────────────────────────────────
table "$T/state7.md" "$P1_ROW" "${E1_ROW/| 묶음 |/| 꾸러미 |}"
assert_eq "$(create "$T/state7.md" docs/rm6)" "1" "표 오류: rc 1"
[ -e "$W/docs/rm6" ] && no "표 오류: 폴더가 생겼다" || ok "표 오류: 아무것도 쓰지 않는다"
rc=0; (cd "$W" && python3 "$RW" create --brief docs/iv/brief.md) >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "2" "사용법 오류: rc 2"

# ── extract — 만든 로드맵에서 같은 표를 뽑는다 ──────────────────────────────
(cd "$W" && python3 "$RW" extract --roadmap docs/rm3/roadmap.md) > "$T/extracted.md"
assert_eq "$(sed -n '3,4p' "$T/extracted.md")" "$(printf '%s\n%s' "$HEAD_ROW" "$SEP_ROW")" "extract: 표 머리"
assert_file_has "$T/extracted.md" "$P1_ROW" "extract: 결정 행이 표 행과 같다"
assert_file_has "$T/extracted.md" "| E2 | 둘째 에픽 | 묶음 |" "extract: 묶음 행"

# ── 기록에 있는 묶음을 표에서 뺀 성공 — 낡은 묶음을 지운다 ───────────────────
E1_ALL='| E1 | 첫 에픽 | 묶음 | 첫 의도 | 한다 가 / 안 한다 나 | P1 | feature/e1 | a/x.py | C1 · D2 · OQ1 · RC1 · K1 · «ext-a» · S1 · S2 · C3 · ST1 · K2 · «ext-b» | 없음 | 없음 |'
table "$T/state8.md" "$P1_ROW" "$E1_ROW" "$E2_ROW"
assert_eq "$(create "$T/state8.md" docs/rm7)" "0" "낡은 묶음: 처음 생성 rc 0"
table "$T/state9.md" "$P1_ROW" "$E1_ALL"
sed -n '/^## 생성 기록/,$p' "$T/state8.md" >> "$T/state9.md"
assert_eq "$(create "$T/state9.md" docs/rm7)" "0" "낡은 묶음: 다시 생성 rc 0"
[ -e "$W/docs/rm7/E2.md" ] && no "낡은 묶음: E2 묶음이 남았다" || ok "낡은 묶음: E2 묶음을 지웠다"
assert_eq "$(tree_of "$W/docs/rm7")" "$(printf './E1.md\n./roadmap.md')" "낡은 묶음: 로드맵 하나 · 묶음 하나"
if grep -qF -- "- docs/rm7/E2.md" "$T/state9.md"; then no "낡은 묶음: 생성 기록에 E2 가 남았다"; else ok "낡은 묶음: 생성 기록에서 E2 를 뺐다"; fi
assert_eq "$(four_empty docs/rm7/roadmap.md)" "ok" "낡은 묶음: 검사기 네 목록이 빈 목록"

# ── 기록에 있는 파일 위에서 검증 실패 — 덮어쓴 것 · 지운 것을 되돌린다 ─────────
table "$T/state10.md" "$P1_ROW" "$E1_ROW" "$E2_ROW"
assert_eq "$(create "$T/state10.md" docs/rm8)" "0" "되돌리기: 처음 생성 rc 0"
table "$T/state11.md" "${P1_ROW/S3 · OQ2/S3 · OQ2 · C99}" "${E1_ALL/첫 의도/첫 의도 고침}"
sed -n '/^## 생성 기록/,$p' "$T/state10.md" >> "$T/state11.md"
cp "$W/docs/rm8/roadmap.md" "$T/rm8.roadmap.before"
cp "$W/docs/rm8/E1.md" "$T/rm8.E1.before"
cp "$W/docs/rm8/E2.md" "$T/rm8.E2.before"
cp "$T/state11.md" "$T/state11.before"
assert_eq "$(create "$T/state11.md" docs/rm8)" "1" "되돌리기: 검증 실패 rc 1"
assert_file_has "$T/out.txt" "C99" "되돌리기: 사유에 번호"
cmp -s "$T/rm8.roadmap.before" "$W/docs/rm8/roadmap.md" && ok "되돌리기: 로드맵이 같은 바이트" || no "되돌리기: 로드맵이 바뀌었다"
cmp -s "$T/rm8.E1.before" "$W/docs/rm8/E1.md" && ok "되돌리기: 덮어쓴 E1 이 원래 바이트로" || no "되돌리기: E1 이 바뀌었다"
cmp -s "$T/rm8.E2.before" "$W/docs/rm8/E2.md" && ok "되돌리기: 지운 E2 가 원래 바이트로 돌아왔다" || no "되돌리기: E2 가 없거나 바뀌었다"
cmp -s "$T/state11.before" "$T/state11.md" && ok "되돌리기: 표 파일이 같은 바이트" || no "되돌리기: 표 파일이 바뀌었다"
assert_eq "$(tree_of "$W/docs/rm8")" "$(printf './E1.md\n./E2.md\n./roadmap.md')" "되돌리기: 폴더에 남은 임시 파일 없음"

finish
