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
g remote set-head origin main

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
assert_file_has "$W/docs/rm/roadmap.md" "### 2026-10-15 · 처음 로드맵" "재분해 이력 첫 머리"
assert_file_has "$W/docs/rm/roadmap.md" "  - 「이대로 승인 (권장)」" "재분해 이력 첫 원문"
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

# ── update 픽스처: docs/rm 을 main 에 올리고 E1 을 머지한다 ──────────────────
g add -- docs/rm && g commit -qm roadmap
g checkout -qb feature/e1 && mkdir -p "$W/a" && printf 'x\n' > "$W/a/x.py" && g add -- a && g commit -qm e1
g checkout -q main && g merge -q --no-ff feature/e1 -m "Merge pull request #1 from o/feature/e1"
g push -q origin main && g fetch -q origin
snap() { rm -rf "$T/snap" && cp -R "$W/docs/rm" "$T/snap"; }
same_as_snap() { diff -r "$T/snap" "$W/docs/rm" >/dev/null 2>&1 && echo same || echo changed; }
update() {  # update <표 파일> — rc 를 echo 한다
  local rc=0
  (cd "$W" && python3 "$RW" update --roadmap docs/rm/roadmap.md --brief docs/iv/brief.md \
     --audit docs/iv/brief.audit.md --plan-table "$1" --date 2026-10-16 --change "경계 조정" \
     --approval "${APPROVAL:-이대로 다시 나눈다}") > "$T/out.txt" 2>&1 || rc=$?
  echo "$rc"
}
(cd "$W" && python3 "$RW" extract --roadmap docs/rm/roadmap.md) > "$T/now.md"
E1_NOW="$(grep '^| E1 |' "$T/now.md")"
E2_NOW="$(grep '^| E2 |' "$T/now.md")"
P1_NOW="$(grep '^| P1 |' "$T/now.md")"

# 바뀐 것 없음 — 쓰지 않는다
snap
assert_eq "$(update "$T/now.md")" "0" "update 변화 없음: rc 0"
assert_eq "$(same_as_snap)" "same" "update 변화 없음: 아무것도 쓰지 않는다"

# 처음 표(E1 행의 번호가 정렬 순서가 아니다; E2 는 다시 생성에서 고친 대로)를 그대로 다시 내도 순서만 다른 것은 바뀜이 아니다
E2_REGEN="${E2_ROW/둘째 의도/둘째 의도 고침}"
table "$T/o0.md" "$P1_ROW" "$E1_ROW" "$E2_REGEN"
snap
assert_eq "$(update "$T/o0.md")" "0" "처음 표 그대로 update(E1 머지 뒤): rc 0"
assert_file_has "$T/out.txt" "바뀐 에픽이 없다" "처음 표 그대로 update: 바뀐 에픽이 없다"
assert_eq "$(same_as_snap)" "same" "처음 표 그대로 update: 아무것도 쓰지 않는다"
# 처음 표 순서에서 E2 만 고치면 바뀜은 E2 하나다
table "$T/o1.md" "$P1_ROW" "$E1_ROW" "${E2_REGEN/둘째 의도 고침/둘째 의도 다시}"
assert_eq "$(update "$T/o1.md")" "0" "처음 표 순서에서 E2 만 고침: rc 0"
grep -qxF -- "- 바뀜: 바뀐 에픽 E2 「이대로 다시 나눈다」" "$W/docs/rm/roadmap.md" && ok "처음 표 순서에서 E2 만 고침: 바뀜은 E2 하나" || no "처음 표 순서에서 E2 만 고침: 바뀜은 E2 하나: 이력 줄이 다르다"
g checkout -q -- docs/rm
# --audit 이 brief 의 `.md` → `.audit.md` 가 아니면 사용법 오류
cp "$W/docs/iv/brief.audit.md" "$W/docs/iv/other.md"
rc=0; (cd "$W" && python3 "$RW" update --roadmap docs/rm/roadmap.md --brief docs/iv/brief.md --audit docs/iv/other.md \
  --plan-table "$T/state.md" --date 2026-10-16 --change x --approval y) > "$T/out.txt" 2>&1 || rc=$?
assert_eq "$rc" "2" "update: --audit 이름이 어긋나면 rc 2"
rc=0; (cd "$W" && python3 "$RW" create --brief docs/iv/brief.md --audit docs/iv/other.md --plan-table "$T/state.md" \
  --out docs/rmx --title t --date 2026-10-15 --approval y) > "$T/out.txt" 2>&1 || rc=$?
assert_eq "$rc" "2" "create: --audit 이름이 어긋나면 rc 2"
assert_eq "$([ -e "$W/docs/rmx" ] && echo exists || echo none)" "none" "create: --audit 어긋남은 아무것도 만들지 않는다"
rm -f "$W/docs/iv/other.md"

# 머지된 E1 은 그대로, 진행 전 E2 만 바뀐다 (AC10)
table "$T/u1.md" "$P1_NOW" "$E1_NOW" "${E2_NOW/한다 다 /한다 다 · 마 }"
cp "$W/docs/rm/E1.md" "$T/E1.keep"
assert_eq "$(update "$T/u1.md")" "0" "update: rc 0"
cmp -s "$T/E1.keep" "$W/docs/rm/E1.md" && ok "update: 머지된 E1 묶음은 바이트 그대로" || no "update: E1 묶음이 바뀌었다"
assert_file_has "$W/docs/rm/E2.md" "- 범위: 한다 다 · 마 / 안 한다 라" "update: 바뀐 E2 묶음 범위 줄"
assert_file_has "$W/docs/rm/roadmap.md" "  - 한다: 다 · 마" "update: 바뀐 E2 블록 범위 한다"
assert_file_has "$W/docs/rm/roadmap.md" "  - 안 한다: 라" "update: 바뀐 E2 블록 범위 안 한다"
assert_file_has "$W/docs/rm/roadmap.md" "### 2026-10-16 · 경계 조정" "update: 재분해 이력 머리"
grep -qxF -- "- 바뀜: 바뀐 에픽 E2 「이대로 다시 나눈다」" "$W/docs/rm/roadmap.md" && ok "update: 재분해 이력 바뀜 끝에 승인 인용" || no "update: 재분해 이력 바뀜 끝에 승인 인용: 이력 줄이 다르다"
assert_file_has "$W/docs/rm/roadmap.md" "  - 「이대로 다시 나눈다」" "update: 재분해 이력 원문"
assert_eq "$(four_empty docs/rm/roadmap.md)" "ok" "update: 검사기 네 목록이 빈 목록"

# 머지된 E1 을 바꾸는 표는 거부 — 아무것도 쓰지 않는다
snap
table "$T/u2.md" "$P1_NOW" "${E1_NOW/첫 의도/첫 의도 고침}" "$(grep '^| E2 |' "$T/u1.md")"
assert_eq "$(update "$T/u2.md")" "1" "머지된 에픽 변경: rc 1"
assert_file_has "$T/out.txt" "E1" "머지된 에픽 변경: 사유에 번호"
assert_file_has "$T/out.txt" "머지" "머지된 에픽 변경: 사유에 머지"
assert_eq "$(same_as_snap)" "same" "머지된 에픽 변경: 바이트 그대로"

# 새 에픽 E3 — 다음 번호 · 묶음 생성, 그다음 E3 를 지우고, 같은 번호 재사용은 거부
E2_U1="$(grep '^| E2 |' "$T/u1.md")"
E3_ROW='| E3 | 셋째 에픽 | 묶음 | 셋째 의도 | 한다 바 / 안 한다 사 | E2 | feature/e3 | 없음 | C3 · S1 | E2 의 결과 | 없음 |'
table "$T/u3.md" "$P1_NOW" "$E1_NOW" "$E2_U1" "$E3_ROW"
assert_eq "$(update "$T/u3.md")" "0" "새 에픽: rc 0"
[ -f "$W/docs/rm/E3.md" ] && ok "새 에픽: 묶음을 만든다" || no "새 에픽: E3.md 없음"
grep -qxF -- "- 바뀜: 새 에픽 E3 「이대로 다시 나눈다」" "$W/docs/rm/roadmap.md" && ok "새 에픽: 이력 바뀜 줄" || no "새 에픽: 이력 바뀜 줄: 이력 줄이 다르다"
table "$T/u4.md" "$P1_NOW" "$E1_NOW" "$E2_U1"
assert_eq "$(update "$T/u4.md")" "0" "에픽 지우기: rc 0"
[ -e "$W/docs/rm/E3.md" ] && no "에픽 지우기: E3.md 가 남았다" || ok "에픽 지우기: 묶음을 지운다"
assert_file_has "$W/docs/rm/roadmap.md" "- 바뀜: 사라진 에픽 E3 「이대로 다시 나눈다」" "에픽 지우기: 이력에 사라진 번호"
snap
assert_eq "$(update "$T/u3.md")" "1" "번호 재사용: rc 1"
assert_eq "$(same_as_snap)" "same" "번호 재사용: 바이트 그대로"
table "$T/u5.md" "$P1_NOW" "$E1_NOW" "$E2_U1" "${E3_ROW/| E3 |/| E4a |}"
assert_eq "$(update "$T/u5.md")" "1" "꼬리 붙은 새 번호: rc 1"
assert_file_has "$T/out.txt" "다음 번호" "꼬리 붙은 새 번호: 번호 규칙에서 막혔다"

# 검증 실패 — 덮어쓴 파일은 원래 바이트, 새 묶음은 남지 않는다 (AC10)
snap
E4_ROW='| E4 | 넷째 에픽 | 묶음 | 넷째 의도 | 한다 아 / 안 한다 자 | E2 | feature/e4 | 없음 | C1 · S1 | 없음 | 없음 |'
table "$T/u6.md" "${P1_NOW/S3 · OQ2/S3 · OQ2 · C99}" "$E1_NOW" "${E2_U1/둘째 에픽/둘째 에픽 고침}" "$E4_ROW"
assert_eq "$(update "$T/u6.md")" "1" "update 검증 실패: rc 1"
assert_file_has "$T/out.txt" "unknown_ids" "update 검증 실패: 사유"
assert_eq "$(same_as_snap)" "same" "update 검증 실패: 로드맵 · 묶음이 원래 바이트, 새 묶음 없음"

# origin/main 없음 — 머지 여부를 모르면 쓰지 않는다
snap
MAIN_SHA="$(g rev-parse refs/remotes/origin/main)"
g update-ref -d refs/remotes/origin/main
assert_eq "$(update "$T/u3.md")" "1" "origin/main 없음: rc 1"
assert_file_has "$T/out.txt" "머지 여부를 알 수 없다" "origin/main 없음: 사유"
assert_eq "$(same_as_snap)" "same" "origin/main 없음: 바이트 그대로"
g update-ref refs/remotes/origin/main "$MAIN_SHA"

# ── 번호는 빈틈없이 이어 붙인다 · 내 것이 아닌 파일은 건드리지 않는다 ────────
cur_row() { (cd "$W" && python3 "$RW" extract --roadmap docs/rm/roadmap.md) | grep "^| $1 |"; }
block_of() { awk -v id="$1" '/^## /{f=0} /^### /{f=($2==id)} f' "$W/docs/rm/roadmap.md"; }
E5_ROW='| E5 | 다섯째 에픽 | 묶음 | 다섯째 의도 | 한다 차 / 안 한다 카 | E4 | feature/e5 | 없음 | C1 · S1 | 없음 | 없음 |'
P1_CUR="$(cur_row P1)"; E1_CUR="$(cur_row E1)"; E2_CUR="$(cur_row E2)"

snap
table "$T/v1.md" "$P1_CUR" "$E1_CUR" "$E2_CUR" "$E5_ROW"
assert_eq "$(update "$T/v1.md")" "1" "번호 빈틈: rc 1"
assert_file_has "$T/out.txt" "다음 번호 E4" "번호 빈틈: 기대 번호를 알린다"
assert_eq "$(same_as_snap)" "same" "번호 빈틈: 바이트 그대로"

printf 'foreign\n' > "$W/docs/rm/E4.md"
snap
table "$T/v2.md" "$P1_CUR" "$E1_CUR" "$E2_CUR" "$E4_ROW"
assert_eq "$(update "$T/v2.md")" "1" "남의 파일 덮어쓰기(새 에픽): rc 1"
assert_file_has "$T/out.txt" "만들지 않은 파일" "남의 파일 덮어쓰기(새 에픽): 사유"
assert_eq "$(cat "$W/docs/rm/E4.md")" "foreign" "남의 파일 덮어쓰기(새 에픽): 남의 파일 그대로"
assert_eq "$(same_as_snap)" "same" "남의 파일 덮어쓰기(새 에픽): 폴더 그대로"
rm -f "$W/docs/rm/E4.md"
printf 'foreign\n' > "$W/docs/rm/P1.md"
snap
P1_BUNDLE='| P1 | 결정 하나 | 묶음 | 무엇을 정한다 | 한다 결정 / 안 한다 코드 | 없음 | feature/p1 | 없음 | S3 · OQ2 | 없음 | 없음 |'
table "$T/v3.md" "$P1_BUNDLE" "$E1_CUR" "$E2_CUR"
assert_eq "$(update "$T/v3.md")" "1" "남의 파일 덮어쓰기(종류 바꿈): rc 1"
assert_file_has "$T/out.txt" "P1.md" "남의 파일 덮어쓰기(종류 바꿈): 사유에 파일"
assert_eq "$(same_as_snap)" "same" "남의 파일 덮어쓰기(종류 바꿈): 폴더 그대로"
rm -f "$W/docs/rm/P1.md"

# 같은 글자의 새 에픽 둘은 한 번에 — E4 · E5 (빈틈 없이)
table "$T/v4.md" "$P1_CUR" "$E1_CUR" "$E2_CUR" "$E4_ROW" "$E5_ROW"
assert_eq "$(update "$T/v4.md")" "0" "연속 새 번호 둘: rc 0"
[ -f "$W/docs/rm/E4.md" ] && [ -f "$W/docs/rm/E5.md" ] && ok "연속 새 번호 둘: 묶음 둘" || no "연속 새 번호 둘: 묶음이 없다"

# 승인 원문 속 번호는 올림 바닥을 올리지 않는다 — E5 를 지우며 「E9 까지 보자」, 그다음 새 에픽은 E6
E6_ROW='| E6 | 여섯째 에픽 | 묶음 | 여섯째 의도 | 한다 타 / 안 한다 파 | E2 | feature/e6 | 없음 | C1 · S1 | 없음 | 없음 |'
table "$T/v5.md" "$P1_CUR" "$E1_CUR" "$E2_CUR" "$E4_ROW"
assert_eq "$(APPROVAL='E9 까지 보자' update "$T/v5.md")" "0" "승인 원문에 번호: 지우기 rc 0"
grep -qxF -- "- 바뀜: 사라진 에픽 E5 「E9 까지 보자」" "$W/docs/rm/roadmap.md" && ok "승인 원문에 번호: 이력에 바뀜" || no "승인 원문에 번호: 이력에 바뀜: 이력 줄이 다르다"
assert_file_has "$W/docs/rm/roadmap.md" "  - 「E9 까지 보자」" "승인 원문에 번호: 이력에 원문"
table "$T/v6.md" "$P1_CUR" "$E1_CUR" "$E2_CUR" "$E4_ROW" "$E6_ROW"
assert_eq "$(update "$T/v6.md")" "0" "승인 원문에 번호: 다음 번호는 E6 (E9 가 아님)"

# 종류 바꿈: 묶음 → 결정 → 묶음
E4_DEC='| E4 | 넷째 에픽 | 결정 | 넷째 의도 | 한다 아 / 안 한다 자 | E2 | 없음 | 없음 | C1 · S1 | 없음 | 없음 |'
table "$T/v7.md" "$P1_CUR" "$E1_CUR" "$E2_CUR" "$E4_DEC" "$E6_ROW"
assert_eq "$(update "$T/v7.md")" "0" "묶음 → 결정: rc 0"
[ -e "$W/docs/rm/E4.md" ] && no "묶음 → 결정: E4.md 가 남았다" || ok "묶음 → 결정: 묶음 파일을 지운다"
block_of E4 | grep -qF -- "- 완료: 결정 기록" && ok "묶음 → 결정: 블록에 완료 결정 기록" || no "묶음 → 결정: 블록이 결정 모양이 아니다"
assert_eq "$(four_empty docs/rm/roadmap.md)" "ok" "묶음 → 결정: 검사기 네 목록이 빈 목록"
table "$T/v8.md" "$P1_CUR" "$E1_CUR" "$E2_CUR" "$E4_ROW" "$E6_ROW"
assert_eq "$(update "$T/v8.md")" "0" "결정 → 묶음: rc 0"
[ -f "$W/docs/rm/E4.md" ] && ok "결정 → 묶음: 묶음 파일을 다시 만든다" || no "결정 → 묶음: E4.md 없음"
assert_eq "$(four_empty docs/rm/roadmap.md)" "ok" "결정 → 묶음: 검사기 네 목록이 빈 목록"

# 머지된 E1 을 지우는 표는 거부
snap
table "$T/v9.md" "$P1_CUR" "$E2_CUR" "$E4_ROW" "$E6_ROW"
assert_eq "$(update "$T/v9.md")" "1" "머지된 에픽 지우기: rc 1"
assert_file_has "$T/out.txt" "머지" "머지된 에픽 지우기: 사유에 머지"
assert_eq "$(same_as_snap)" "same" "머지된 에픽 지우기: 폴더 그대로"

# 되돌리기: 지운 묶음(E6)이 원래 바이트로 돌아온다 — P1 에 모르는 번호를 끼워 검증을 실패시킨다
snap
cp "$W/docs/rm/E6.md" "$T/E6.keep"
table "$T/v10.md" "${P1_CUR/S3 · OQ2/S3 · OQ2 · C99}" "$E1_CUR" "$E2_CUR" "$E4_ROW"
assert_eq "$(update "$T/v10.md")" "1" "update 되돌리기: rc 1"
assert_file_has "$T/out.txt" "C99" "update 되돌리기: 사유에 번호"
cmp -s "$T/E6.keep" "$W/docs/rm/E6.md" && ok "update 되돌리기: 지운 묶음이 같은 바이트로" || no "update 되돌리기: E6.md 가 없거나 바뀌었다"
assert_eq "$(same_as_snap)" "same" "update 되돌리기: 폴더 그대로"

# 순서만 바뀐 표 — 묶음 파일은 그대로, 이력 줄엔 바뀜 · 새 · 사라짐이 없다
B_E2="$(block_of E2)"; B_E6="$(block_of E6)"
for f in E2 E4 E6; do cp "$W/docs/rm/$f.md" "$T/$f.keep"; done
table "$T/v11.md" "$P1_CUR" "$E1_CUR" "$E2_CUR" "$E6_ROW" "$E4_ROW"
assert_eq "$(update "$T/v11.md")" "0" "순서만: rc 0"
assert_eq "$(grep '^### [A-Z]' "$W/docs/rm/roadmap.md" | sed 's/^### \([A-Z0-9a-z]*\) .*/\1/' | tr '\n' ' ')" "P1 E1 E2 E6 E4 " "순서만: 블록 순서가 바뀌었다"
for f in E2 E4 E6; do cmp -s "$T/$f.keep" "$W/docs/rm/$f.md" && ok "순서만: $f 묶음 바이트 그대로" || no "순서만: $f 묶음이 바뀌었다"; done
assert_eq "$(block_of E2)" "$B_E2" "순서만: 바뀌지 않은 E2 블록(범위 하위 항목)은 바이트 그대로"
assert_eq "$(block_of E6)" "$B_E6" "순서만: 바뀌지 않은 E6 블록은 바이트 그대로"
assert_contains "$B_E2" "  - 한다: " "E2 블록은 새 꼴이다(이 단언이 하위 항목 블록을 잰다는 양성 짝)"
grep -qxF -- "- 바뀜: 순서만 「이대로 다시 나눈다」" "$W/docs/rm/roadmap.md" && ok "순서만: 이력에 순서만이라 적는다" || no "순서만: 이력 줄이 다르다"

# 끝남 에픽은 거부 — P1 의 결정 기록을 main 에 올린다
python3 - "$W/docs/rm/roadmap.md" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
i = t.index("## 결정 기록")
j = t.index("\n## ", i + 1)
t = t[:j].rstrip("\n") + "\n\n- P1 · 결정 · 2026-10-15 · 「정했다」\n" + t[j:]
open(p, "w", encoding="utf-8").write(t)
PY
g add -- docs/rm/roadmap.md && g commit -qm "P1 결정" && g push -q origin main && g fetch -q origin
snap
table "$T/v12.md" "${P1_CUR/무엇을 정한다/무엇을 정한다 고침}" "$E1_CUR" "$E2_CUR" "$(cur_row E6)" "$(cur_row E4)"
assert_eq "$(update "$T/v12.md")" "1" "끝남 에픽 변경: rc 1"
assert_file_has "$T/out.txt" "P1" "끝남 에픽 변경: 사유에 번호"
assert_eq "$(same_as_snap)" "same" "끝남 에픽 변경: 폴더 그대로"

finish
