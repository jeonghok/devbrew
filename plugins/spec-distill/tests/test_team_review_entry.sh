#!/usr/bin/env bash
# spec-review 진입(AC16) — spec_review_bundle.py 가 과제 파일(INTENT.md, 머리 type: job)을 --bundle 로 받는다.
# 진입 번호 대조는 같은 폴더의 번호 파일로 · 리뷰어의 정답 출처 알림 한 줄 · 단순 작업은 건너뜀 · neighbors 는 머리의 job · roadmap.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_team_review_entry.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
T0="$(mktemp -d)" || exit 1
[ -n "$T0" ] && [ -d "$T0" ] || exit 1
T="$(cd "$T0" && pwd -P)"   # PROCEED 줄은 realpath 다 — 임시 폴더의 링크(/var → /private/var)를 먼저 푼다
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
. "$ROOT/plugins/spec-distill/tests/fixtures/team_repo.sh"
team_repo && ok "팀 레포를 세웠다(${TM})" || { no "팀 레포를 세우지 못했다 — $(cat "$T/out.txt")"; finish; }

SRB="$S/spec_review_bundle.py"
ent() { python3 "$SRB" entry --spec "$1" --bundle "$2" --root "$W" > "$T/out.txt"; echo $?; }
nb() { python3 "$SRB" neighbors --bundle "$1" --root "$W" > "$T/out.txt"; echo $?; }
ORIGIN_TABLE="$(printf '## 원문 대조\n\n| 원문 요소 | 설계 요소 | 그대로/바꿈 | 근거 |\n|---|---|---|---|\n| 결과를 파일로 받아 읽자 | 리뷰 진입이 과제 파일을 받는다 | 바꿈 | 작성자 제안 |')"
design_at() {  # design_at <레포 상대 설계문서> <source_interview> <번호 대조 행들> — 과제 파일 리뷰 진입 픽스처
  printf -- '---\ntype: design\nsource_interview: %s\n---\n\n# 리뷰 진입 — 과제 파일 픽스처\n\n### §1 진입\n\n과제 파일을 정답 출처로 받는다.\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n%s\n\n%s\n\n## Acceptance Criteria\n\n- AC1: 과제 파일을 받는다\n' \
    "$2" "$3" "$ORIGIN_TABLE" > "$W/$1"
}
design_with_source() { design_at "$TM/jobs/E1/design.md" "$1" '| C1 · S1 | 반영 | §1 |'; }

# ── AC16: INTENT.md 를 --bundle 로 ──────────────────────────────────────────
I="$TM/jobs/E1/INTENT.md"
design_with_source "$I"          # 작업 폴더의 E1 design.md — 머리 source_interview: $I · 번호 대조 표 · 원문 대조 표
assert_eq "$(ent "$TM/jobs/E1/design.md" "$I")" "0" "AC16: INTENT.md 를 --bundle 로"
assert_eq "$(tail -n 1 "$T/out.txt")" "bundle-entry: PROCEED $W/$I" "AC16: PROCEED 와 INTENT.md 의 절대경로"
assert_eq "$(tail -n 2 "$T/out.txt" | head -n 1)" "번호 대조 경고 0개" "AC16: PROCEED 바로 앞 줄은 지금 계약 그대로"
assert_eq "$(grep -c 'team 형식 — 리뷰어가 번호 항목(sources.md)과 원자료(intent/original.md)를 정답으로 읽지 못한다' "$T/out.txt")" "1" "AC16: 알림 한 줄"
assert_contains "$(sed -n 1p "$T/out.txt")" "번호 대조: 빠진 번호 없음 (번호 파일 번호" "AC16: 진입 번호 대조는 옆 번호 파일로 한다"
assert_eq "$(tail -n 3 "$T/out.txt" | head -n 1)" "[spec-distill] team 형식 — 리뷰어가 번호 항목(sources.md)과 원자료(intent/original.md)를 정답으로 읽지 못한다. 리뷰어에게 가는 정답 출처는 INTENT.md 하나다." "AC16: 경고 수 바로 앞 줄이 알림 전체(번호 대조 글은 그 앞 — 글의 줄 수는 재지 않는다)"
assert_not_contains "$(cat "$T/out.txt")" "질문 줄:" "AC16: 경고가 0 이면 「질문 줄:」 을 내지 않는다"

# 번호 하나를 표에서 뺀 설계문서 — 경고 1개 · PROCEED 그대로
design_at "$TM/jobs/E1/design.md" "$I" '| S1 | 반영 | §1 |'
assert_eq "$(ent "$TM/jobs/E1/design.md" "$I")" "0" "빠진 번호: rc 0"
assert_eq "$(tail -n 2 "$T/out.txt" | head -n 1)" "번호 대조 경고 1개" "빠진 번호: 번호 대조 경고 1개"
assert_eq "$(tail -n 1 "$T/out.txt")" "bundle-entry: PROCEED $W/$I" "빠진 번호: PROCEED 그대로"
assert_contains "$(cat "$T/out.txt")" "빠진 번호 1개 — C1" "빠진 번호: 번호 파일의 C1 이 빠졌다고 말한다"
assert_eq "$(grep -c '^질문 줄: 번호 대조 경고 1개: 빠진 번호 1$' "$T/out.txt")" "1" "빠진 번호: 질문의 경고 줄에 이을 「질문 줄:」 을 옛 형식과 같은 꼴로 낸다"
assert_contains "$(tail -n 3 "$T/out.txt" | head -n 1)" "[spec-distill] team 형식 — 리뷰어가 번호 항목" "빠진 번호: 질문 줄이 있어도 경고 수 바로 앞 줄은 알림이다"

# source_interview 가 다른 과제의 INTENT.md — 거절
design_at "$TM/jobs/E1/design.md" "$TM/jobs/E3/INTENT.md" '| C1 · S1 | 반영 | §1 |'
ent "$TM/jobs/E1/design.md" "$I" >/dev/null
assert_eq "$(tail -n 1 "$T/out.txt")" "bundle-entry: REFUSE" "다른 과제의 INTENT.md 를 가리키는 source_interview: REFUSE"
assert_contains "$(cat "$T/out.txt")" "와 다른 파일이다" "다른 과제: 사유는 지금 글 그대로"
assert_not_contains "$(cat "$T/out.txt")" "team 형식 — " "거절에는 알림을 싣지 않는다"

# 번호 파일을 --bundle 로 — 지금처럼 거절(정답 출처는 INTENT.md 다)
design_at "$TM/jobs/E1/design.md" "$TM/jobs/E1/sources.md" '| C1 · S1 | 반영 | §1 |'
ent "$TM/jobs/E1/design.md" "$TM/jobs/E1/sources.md" >/dev/null
assert_eq "$(tail -n 1 "$T/out.txt")" "bundle-entry: REFUSE" "번호 파일을 --bundle 로: REFUSE"
assert_contains "$(cat "$T/out.txt")" "type 이 epic-bundle · context-brief 가 아니다(job-sources)" "번호 파일: 사유는 지금 글 그대로"

# 번호 파일이 없어진 에픽 과제 — 「단순 작업」 으로 건너뛰지 않고 검사 불가(경고 1)
design_with_source "$I"
mv "$W/$TM/jobs/E1/sources.md" "$T/e1-sources.held"
ent "$TM/jobs/E1/design.md" "$I" >/dev/null
assert_contains "$(sed -n 1p "$T/out.txt")" "번호 대조 검사 불가 — kind: epic 과제인데 번호 파일이 없다" "번호 파일 없는 에픽: 검사 불가 줄"
assert_not_contains "$(cat "$T/out.txt")" "단순 작업" "번호 파일 없는 에픽: 단순 작업이라 말하지 않는다"
assert_eq "$(tail -n 2 "$T/out.txt" | head -n 1)" "번호 대조 경고 1개" "번호 파일 없는 에픽: 경고 1개(셀 수 없음은 0 이 아니다)"
assert_eq "$(grep -c '^질문 줄: 번호 대조 경고 1개: 검사 불가$' "$T/out.txt")" "1" "번호 파일 없는 에픽: 「질문 줄:」 이 검사 불가를 말한다"
assert_eq "$(tail -n 1 "$T/out.txt")" "bundle-entry: PROCEED $W/$I" "번호 파일 없는 에픽: PROCEED"
mv "$T/e1-sources.held" "$W/$TM/jobs/E1/sources.md"

# 옛 형식 정답 출처(brief) — 알림이 없다
design_at "docs/tv/old-design.md" "docs/tv/brief.md" '| C1 | 반영 | §1 |'
ent "docs/tv/old-design.md" "docs/tv/brief.md" >/dev/null
assert_eq "$(tail -n 1 "$T/out.txt")" "bundle-entry: PROCEED $W/docs/tv/brief.md" "옛 형식 brief: PROCEED"
assert_not_contains "$(cat "$T/out.txt")" "team 형식 — " "옛 형식 brief: 알림 줄이 없다"

# ── neighbors — 머리의 job · roadmap 으로 ────────────────────────────────────
assert_eq "$(nb "$I")" "0" "neighbors --bundle INTENT.md: rc 0"
assert_eq "$(sed -n 1p "$T/out.txt")" "로드맵 속 위치 — $RM" "neighbors: 첫 줄은 INTENT.md 머리의 roadmap"
assert_contains "$(sed -n 2p "$T/out.txt")" "  E1 첫 읽기 — " "neighbors: 둘째 줄은 머리의 job(E1) 블록"
assert_eq "$(grep -c '^  이 에픽에 의존: E3 ' "$T/out.txt")" "1" "neighbors: 「이 에픽에 의존: E3」 줄"
J3I="$TM/jobs/E3/INTENT.md"
assert_eq "$(sed -n '/^이웃 에픽의 결정/,$p' "$T/out.txt")" "$(printf '이웃 에픽의 결정\n  E3 — 결정 줄 없음 — %s' "$J3I")" \
  "neighbors: 설계 전(준비)인 team 이웃도 과제 파일의 결정 기록을 읽는다(기본 브랜치)"

# INTENT.md 머리 roadmap 이 레포 밖으로 나가는 경로 — 그 자리에 진짜 team 로드맵이 있어도 열지 않는다
mkdir -p "$W/out-neighbors/a" "$W/out-neighbors/outside"
cp "$W/$RM" "$W/out-neighbors/outside/roadmap.md"
printf -- '---\ntype: job\njob: E1\nroadmap: ../../outside/roadmap.md\n---\n\n## 목표\n' > "$W/out-neighbors/a/INTENT.md"
assert_eq "$(nb "out-neighbors/a/INTENT.md")" "0" "neighbors: 머리 roadmap 이 .. 경로여도 rc 0(종료 코드는 그대로)"
assert_not_contains "$(cat "$T/out.txt")" "로드맵 속 위치 — " "neighbors: 머리 roadmap 이 .. 경로면 그 자리의 로드맵을 열지 않는다"
assert_contains "$(cat "$T/out.txt")" "레포 상대 경로가 아니다" "neighbors: 머리 roadmap 이 .. 경로면 사유를 댄다"
rm -rf "$W/out-neighbors"

# ── neighbors — team 이웃의 결정은 그 과제 INTENT.md 의 결정 기록에서 읽는다 ─────────────
g checkout -q -b feature/tm-e3 main
put "$TM/jobs/E3/design.md" "$(printf -- '---\ntype: design\n---\n\n# 이어 읽기 — 이웃 결정 픽스처\n')"
g commit -qm "E3 설계 시작" && g push -q origin feature/tm-e3 && g fetch -q origin
assert_eq "$(nb "$I")" "0" "이웃 결정 없음: rc 0"
assert_eq "$(sed -n '/^이웃 에픽의 결정/,$p' "$T/out.txt")" "$(printf '이웃 에픽의 결정\n  E3 — 결정 줄 없음 — %s' "$J3I")" "이웃 결정 없음(브랜치 끝): 「결정 줄 없음」 과 INTENT.md 경로"
decide E3 '- 결정 · 2026-11-15 · 「이웃은 결과 파일만 읽는다」'
decide E3 '- 넘김 확인 · E1 · 0123abcd · E1 의 읽기를 받는다'
g add -- "$J3I" && g commit -qm "E3 결정 둘" && g push -q origin feature/tm-e3 && g fetch -q origin
nb "$I" >/dev/null
assert_eq "$(sed -n '/^이웃 에픽의 결정/,$p' "$T/out.txt")" "$(printf '이웃 에픽의 결정\n  E3 — %s\n    - 결정 · 2026-11-15 · 「이웃은 결과 파일만 읽는다」\n    - 넘김 확인 · E1 · 0123abcd · E1 의 읽기를 받는다' "$J3I")" \
  "이웃 결정: INTENT.md 결정 기록의 줄을 그대로(날짜 없는 넘김 확인 포함)"
# 있는데 못 읽음 — 브랜치 끝의 INTENT.md 객체(느슨한 파일)를 지운다: cat-file -e 가 「경로 없음」 이 아닌 실패를 낸다
BLOB="$(g rev-parse "feature/tm-e3:$J3I")"
BLOB_FILE="$W/.git/objects/$(printf '%s' "$BLOB" | cut -c1-2)/$(printf '%s' "$BLOB" | cut -c3-)"
[ -f "$BLOB_FILE" ] && rm -f "$BLOB_FILE" && ok "픽스처: 이웃 E3 의 INTENT.md 객체를 지웠다" || no "픽스처: 느슨한 객체 파일이 없다(${BLOB_FILE})"
nb "$I" >/dev/null
assert_eq "$(sed -n '/^이웃 에픽의 결정/,$p' "$T/out.txt")" "$(printf '이웃 에픽의 결정\n  E3 — 셀 수 없음: 과제 파일을 읽지 못했다 — %s' "$J3I")" \
  "INTENT.md 를 읽지 못한 이웃: 셀 수 없음 · 읽지 못했다(「없다」 · 「결정 줄 없음」 이 아니다)"
python3 - "$W/$J3I" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(t.replace("\n## 결정 기록\n", "\n## 결정 메모\n"))
PY
g add -- "$J3I" && g commit -qm "E3 결정 칸 이름을 망가뜨림" && g push -q origin feature/tm-e3 && g fetch -q origin
nb "$I" >/dev/null
assert_contains "$(sed -n '/^이웃 에픽의 결정/,$p' "$T/out.txt")" "  E3 — 셀 수 없음: 결정 기록 칸을 읽지 못했다(" "결정 칸이 깨진 이웃: 셀 수 없음 줄"
assert_not_contains "$(sed -n '/^이웃 에픽의 결정/,$p' "$T/out.txt")" "결정 줄 없음" "결정 칸이 깨진 이웃: 「결정 줄 없음」 이 아니다"
g rm -q -- "$J3I" && g commit -qm "E3 INTENT.md 지움" && g push -q origin feature/tm-e3 && g fetch -q origin
nb "$I" >/dev/null
assert_contains "$(sed -n '/^이웃 에픽의 결정/,$p' "$T/out.txt")" "  E3 — 셀 수 없음: 과제 파일이 없다 — $J3I" "INTENT.md 가 없는 이웃: 셀 수 없음 · 없다"
assert_not_contains "$(sed -n '/^이웃 에픽의 결정/,$p' "$T/out.txt")" "결정 줄 없음" "INTENT.md 가 없는 이웃: 「결정 줄 없음」 이 아니다"
g checkout -q main
python3 - "$W/$RM" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
assert "\nlayout: team\n" in t
open(p, "w", encoding="utf-8").write(t.replace("\nlayout: team\n", "\nlayout: crew\n", 1))
PY
nb "$I" >/dev/null
assert_eq "$(tail -n 1 "$T/out.txt")" "이웃 에픽의 결정 — 셀 수 없음: 모르는 형식 — $RM 머리말 layout: crew (아는 값: team)" "모르는 layout: 결정을 옛 형식으로 읽지 않고 모르는 형식으로 멈춘다"
g checkout -q -- "$RM"
g push -q origin --delete feature/tm-e3 && g branch -q -D feature/tm-e3 && g fetch -q --prune origin   # 뒤 픽스처는 E3 가 준비인 레포에서

# ── 단순 작업 — 번호 파일이 없는 과제 ───────────────────────────────────────
printf '오타 하나를 고친다\n' > "$T/said.txt"
(cd "$W" && python3 "$RW" job new --roadmap "$RM" --name fix-entry --branch fix/entry --paths a.py --goal "오타를 고친다" < "$T/said.txt") > "$T/out.txt" 2>&1 \
  && ok "픽스처: 단순 작업 과제 fix-entry" || no "픽스처: job new 실패 — $(cat "$T/out.txt")"
IT="$TM/jobs/fix-entry/INTENT.md"
design_at "$TM/jobs/fix-entry/design.md" "$IT" '| C1 | 반영 | §1 |'
assert_eq "$(ent "$TM/jobs/fix-entry/design.md" "$IT")" "0" "단순 작업: rc 0"
assert_eq "$(sed -n 1p "$T/out.txt")" "번호 대조 건너뜀 — 번호 파일이 없는 과제다(단순 작업)." "단순 작업: 건너뜀 한 줄"
assert_eq "$(grep -c 'team 형식 — 리뷰어가 번호 항목' "$T/out.txt")" "1" "단순 작업: 알림 한 줄"
assert_eq "$(tail -n 2 "$T/out.txt" | head -n 1)" "번호 대조 경고 0개" "단순 작업: 경고 0개"
assert_not_contains "$(cat "$T/out.txt")" "질문 줄:" "단순 작업: 경고가 없으면 「질문 줄:」 을 내지 않는다"
assert_eq "$(tail -n 1 "$T/out.txt")" "bundle-entry: PROCEED $W/$IT" "단순 작업: PROCEED"
assert_eq "$(nb "$IT") · $(wc -c < "$T/out.txt" | tr -d ' ')" "0 · 0" "neighbors: 로드맵에 블록이 없는 단순 작업은 아무것도 내지 않는다"
finish
