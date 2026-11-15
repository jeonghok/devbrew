#!/usr/bin/env bash
# check_bundle_coverage.py 의 team 형식(AC15) — 번호 파일(sources.md)의 ids 가 정답 출처 · `## 원문 대조` 표의 알림과 얕은 답 ·
# 다른 과제의 design.md 로 받듦 · 결과 파일의 AC 줄(--impl) · 옛 형식 그대로 · 단계 계산을 거친 경고와 알림.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_team_coverage.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
. "$ROOT/plugins/spec-distill/tests/fixtures/team_repo.sh"
team_repo && ok "팀 레포를 세웠다(${TM})" || { no "팀 레포를 세우지 못했다 — $(cat "$T/out.txt")"; finish; }

C="$S/check_bundle_coverage.py"
J1="$TM/jobs/E1"
J3="$TM/jobs/E3"
jsf() { python3 -c 'import json,sys; r=json.load(open(sys.argv[1], encoding="utf-8")); print(eval(sys.argv[2]))' "$T/out.txt" "$1"; }   # jsf <식> — out.txt 의 JSON 보고 r. 식은 이 테스트가 쓴 고정 문자열뿐이다
cov() { (cd "$W" && python3 "$C" "$J1/sources.md" "$J1/design.md" "$@") > "$T/out.txt" 2>&1; echo $?; }
design() {  # design <번호 대조 행들> <원문 대조 절 글> — 작업 폴더에 E1 의 design.md 를 쓴다
  printf -- '---\ntype: design\njob: E1\n---\n\n# 첫 읽기 — 번호 파일 대조 픽스처\n\n### §1 하나\n\n번호 파일의 번호를 표와 맞춘다.\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n%s\n\n%s\n\n## Acceptance Criteria\n\n- AC1: 번호 파일의 번호를 센다\n- AC2: 원문 대조 표를 본다\n' "$1" "$2" > "$W/$J1/design.md"
}
ROWS_ALL='| C1 · S1 | 반영 | §1 |'
ROWS_NO_C1='| S1 | 반영 | §1 |'
ROWS_REJECT_S1="$(printf '| C1 | 반영 | §1 |\n| S1 | 기각 | E3 가 받는다 |')"
ORIGIN_HEAD="$(printf '## 원문 대조\n\n| 원문 요소 | 설계 요소 | 그대로/바꿈 | 근거 |\n|---|---|---|---|')"
ORIGIN_OK="$(printf '%s\n| 결과를 파일로 받아 읽자 | 과제 폴더의 결과 파일 | 바꿈 | S1 — 폴더 하나에 모은다 |\n| 단계는 파일로 센다 | 단계는 파일로 센다 | 그대로 | S2 |' "$ORIGIN_HEAD")"
ORIGIN_CHANGED_NO_REASON="$(printf '%s\n| 팀 폴더 | 과제 폴더 | 바꿈 |  |' "$ORIGIN_HEAD")"
ORIGIN_CHANGED_WITH_REASON="$(printf '%s\n| 팀 폴더 | 과제 폴더 | 바꿈 | S1 — 한 곳에 둔다 |' "$ORIGIN_HEAD")"
ORIGIN_KEPT_NO_REASON="$(printf '%s\n| 팀 폴더 | 팀 폴더 | 그대로 |  |' "$ORIGIN_HEAD")"
ORIGIN_THREE_CELLS="$(printf '%s\n| 팀 폴더 | 과제 폴더 | 바꿈 |' "$ORIGIN_HEAD")"
LONG_ELEMENT="결과를 파일로 받아 읽고 단계를 파일로 세며 대조는 커밋으로 하고 막히면 막힘 파일을 둔다"
ORIGIN_LONG="$(printf '%s\n| %s | 과제 폴더 | 바꿈 | |' "$ORIGIN_HEAD" "$LONG_ELEMENT")"

# ── 정답 출처 · 빠진 번호 ───────────────────────────────────────────────────
design "$ROWS_ALL" "$ORIGIN_OK"
assert_eq "$(cov)" "0" "AC15: 번호 파일의 ids 가 정답 출처 — 모두 있으면 0"
assert_contains "$(sed -n 1p "$T/out.txt")" "번호 파일 번호" "AC15: 첫 줄이 정답 출처를 번호 파일이라 말한다"
assert_not_contains "$(cat "$T/out.txt")" "알림 — " "AC15: 원문 대조 표가 있으면 알림이 없다"
assert_eq "$(sed -n 1p "$T/out.txt")" "번호 대조: 빠진 번호 없음 (번호 파일 번호 2개 · 표 번호 2개)" "AC15: 첫 줄 전체 — 번호 파일의 ids 둘(C1 · S1)"
cov --json >/dev/null
assert_eq "$(jsf "(r['mode'], r['notices'], r['shallow'], r['bundle_count'])")" "('sources', [], [], 2)" "AC15: --json 의 mode 는 sources · 빈 notices · 얕은 답 없음"
design "$ROWS_NO_C1" "$ORIGIN_OK"
assert_eq "$(cov)" "1" "AC15: 번호 파일의 번호가 표에 없으면 1"
assert_contains "$(cat "$T/out.txt")" "C1" "AC15: 빠진 번호를 낸다"
assert_contains "$(cat "$T/out.txt")" "빠진 번호 1개 — C1" "AC15: 빠진 번호 줄"

# ── `## 원문 대조` 표 ───────────────────────────────────────────────────────
design "$ROWS_ALL" ""
assert_eq "$(cov)" "0" "AC15: 원문 대조 표가 없어도 종료 코드는 그대로"
assert_contains "$(cat "$T/out.txt")" '알림 — 설계문서에 `## 원문 대조` 표가 없다' "AC15: 알림 한 줄"
assert_eq "$(cov --json >/dev/null; python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["notices"])' "$T/out.txt")" '['"'"'설계문서에 `## 원문 대조` 표가 없다'"'"']' "AC15: --json 의 notices"
cov >/dev/null
assert_eq "$(sed -n '$p' "$T/out.txt")" '알림 — 설계문서에 `## 원문 대조` 표가 없다' "AC15: 알림은 끝 줄이다"
design "$ROWS_ALL" "$ORIGIN_CHANGED_NO_REASON"     # 「| 팀 폴더 | 과제 폴더 | 바꿈 |  |」 한 행
assert_eq "$(cov)" "0" "AC15: 얕은 답은 종료 코드를 바꾸지 않는다"
assert_contains "$(cat "$T/out.txt")" "원문 대조의 「바꿈」 행에 근거가 없다" "AC15: 근거 칸이 빈 「바꿈」 은 얕은 답"
assert_contains "$(cat "$T/out.txt")" "얕은 답 — 팀 폴더: 원문 대조의 「바꿈」 행에 근거가 없다" "AC15: 얕은 답 줄의 번호 자리는 원문 요소 글"
cov --json >/dev/null
assert_eq "$(jsf "(r['status'], r['shallow'], r['notices'])")" "(0, [{'id': '팀 폴더', 'reason': '원문 대조의 「바꿈」 행에 근거가 없다'}], [])" "AC15: --json 의 shallow 한 칸 · 알림 없음"
design "$ROWS_ALL" "$ORIGIN_LONG"
cov --json >/dev/null
assert_eq "$(jsf "r['shallow'][0]['id']")" "$(python3 -c 'import sys; print(sys.argv[1][:40])' "$LONG_ELEMENT")" "AC15: 얕은 답의 id 는 원문 요소 글 40자까지"
design "$ROWS_ALL" "$ORIGIN_CHANGED_WITH_REASON"
assert_eq "$(cov)" "0" "원문 대조: 「바꿈」 에 근거가 있으면 rc 0"
assert_not_contains "$(cat "$T/out.txt")" "얕은 답" "원문 대조: 「바꿈」 에 근거가 있으면 얕은 답이 없다"
design "$ROWS_ALL" "$ORIGIN_KEPT_NO_REASON"
assert_eq "$(cov)" "0" "원문 대조: 「그대로」 에 근거가 비어도 rc 0"
assert_not_contains "$(cat "$T/out.txt")" "얕은 답" "원문 대조: 「그대로」 는 근거가 비어도 얕은 답이 아니다"
design "$ROWS_ALL" "$ORIGIN_THREE_CELLS"
assert_eq "$(cov)" "0" "원문 대조: 칸이 셋인 행이 있어도 rc 0"
assert_contains "$(cat "$T/out.txt")" "알림 — 원문 대조 표를 읽지 못했다 — " "원문 대조: 칸이 셋인 행은 「읽지 못했다」 알림"
assert_not_contains "$(cat "$T/out.txt")" "얕은 답" "원문 대조: 읽지 못한 표에서 얕은 답을 세지 않는다"
design "$ROWS_ALL" "$(printf '## 원문 대조\n\n| 원문 요소 | 설계 요소 | 근거 |\n|---|---|---|\n| 팀 폴더 | 과제 폴더 | S1 |')"
assert_eq "$(cov) · $(sed -n '$p' "$T/out.txt")" "0 · 알림 — 원문 대조 표를 읽지 못했다 — 원문 대조 표 머리 행이 칸 넷이 아니다" "원문 대조: 머리 행이 칸 셋이면 「읽지 못했다」 알림"
design "$ROWS_ALL" "$ORIGIN_HEAD"
assert_eq "$(cov) · $(sed -n '$p' "$T/out.txt")" "0 · 알림 — 원문 대조 표를 읽지 못했다 — 원문 대조 표가 없거나 데이터 행이 없다" "원문 대조: 데이터 행이 없는 표는 「읽지 못했다」 알림"

# ── 받듦 — 다른 과제(E3)의 design.md 를 읽는다 ─────────────────────────────
design "$ROWS_REJECT_S1" "$ORIGIN_OK"
assert_eq "$(cov)" "0" "받듦: E1 이 S1 을 기각해도 rc 0"
assert_not_contains "$(cat "$T/out.txt")" "받드는 에픽 없는 발화" "받듦: E3 에 배정됐고 E3 의 design.md 가 없으면 받든다"
assert_not_contains "$(cat "$T/out.txt")" "셀 수 없음" "받듦: 옆 INTENT.md 의 roadmap 으로 로드맵을 읽었다(셀 수 없음이 아니다)"
printf -- '---\ntype: design\njob: E3\n---\n\n# 이어 읽기 — 받듦 픽스처\n\n### §1 얹기\n\n첫 읽기 위에 얹는다.\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| C3 · S4 | 반영 | §1 |\n| S1 | 기각 | E1 이 받는다 |\n' > "$W/$J3/design.md"
assert_eq "$(cov)" "0" "받듦: 받드는 에픽 없는 발화도 종료 코드를 바꾸지 않는다"
assert_contains "$(cat "$T/out.txt")" "받드는 에픽 없는 발화 1개" "받듦: E3 의 design.md 가 S1 을 기각하면 받드는 에픽 없는 발화 1개"
assert_contains "$(cat "$T/out.txt")" "받드는 에픽 없는 발화 — S1" "받듦: 과제 폴더의 설계문서를 읽었다는 증거 — S1"
chmod 000 "$W/$J3/design.md"
assert_eq "$(cov)" "0" "받듦: E3 의 design.md 를 읽지 못해도 rc 0"
assert_contains "$(cat "$T/out.txt")" "셀 수 없음 — S1 — E3 의 설계문서를 못 읽었다: $J3/design.md" "받듦: 읽지 못한 과제 설계문서는 셀 수 없음"
chmod 644 "$W/$J3/design.md"
rm -f "$W/$J3/design.md"

# ── 옆 INTENT.md 가 없는 번호 파일 — 로드맵을 모른다 ─────────────────────────
mkdir -p "$T/lone"
cp "$W/$J1/sources.md" "$T/lone/sources.md" && cp "$W/$J1/design.md" "$T/lone/design.md"
lone() { (cd "$T/lone" && python3 "$C" sources.md design.md) > "$T/out.txt" 2>&1; echo $?; }
assert_eq "$(lone)" "0" "INTENT.md 없음: 빠진 번호가 없으면 rc 0"
assert_contains "$(cat "$T/out.txt")" "셀 수 없음 — S1 — 로드맵을 모른다" "INTENT.md 없음: 기각 행이 셀 수 없음"
printf -- '---\ntype: job\njob: E1\nroadmap: %s\n\n## 목표\n' "$RM" > "$T/lone/INTENT.md"
assert_eq "$(lone)" "0" "INTENT.md 머리가 닫히지 않음: 죽지 않고 rc 0"
assert_contains "$(cat "$T/out.txt")" "셀 수 없음 — S1 — 로드맵을 모른다" "INTENT.md 머리가 닫히지 않음: 로드맵 없이 센다"
printf -- '---\ntype: job\njob: E1\n---\n\n## 목표\n' > "$T/lone/INTENT.md"
assert_eq "$(lone) · $(grep -c '셀 수 없음 — S1 — 로드맵을 모른다' "$T/out.txt")" "0 · 1" "INTENT.md 머리에 roadmap 이 없음: 로드맵 없이 센다"
rm -f "$T/lone/INTENT.md"
# team 로드맵인데 팀 자리(<roadmaps_dir><팀>/roadmap.md)가 아니다 — 한 층 깊은 사본을 가리키는 INTENT.md
mkdir -p "$W/${RD}deep/tm" "$W/deep-lone"
cp "$W/$RM" "$W/${RD}deep/tm/roadmap.md"
cp "$T/lone/sources.md" "$T/lone/design.md" "$W/deep-lone/"
printf -- '---\ntype: job\njob: E1\nroadmap: %s\n---\n\n## 목표\n' "${RD}deep/tm/roadmap.md" > "$W/deep-lone/INTENT.md"
(cd "$W/deep-lone" && python3 "$C" sources.md design.md) > "$T/out.txt" 2>&1
assert_contains "$(cat "$T/out.txt")" "셀 수 없음 — S1 — team 로드맵의 자리가 아니다 — " "team 로드맵의 자리가 아니면 기각 행이 셀 수 없음"
rm -rf "$W/${RD}deep" "$W/deep-lone"
# 커밋 트리를 읽는 repo(뿌리 없음)가 roadmaps_dir 을 넘기지 않으면 죽지 않고 사유를 낸다
tree_repo_view() {  # tree_repo_view — 뿌리 없는 repo 로 _roadmap_view 를 부른 값
  (cd "$W" && python3 - "$S" "$RM") <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import check_bundle_coverage as cbc
class TreeRepo:   # roadmap_status._GitTreeRepo 처럼 root 가 없고 specs_dir 만 있다
    specs_dir, roadmaps_dir = "docs/superpowers/specs/", None
    def read(self, rel):
        return open(rel, encoding="utf-8").read()
    def exists(self, rel):
        return True
print(cbc._roadmap_view({}, TreeRepo(), sys.argv[2]))
PY
}
assert_contains "$(tree_repo_view)" "(None, '레포 설정을 읽지 못했다: 읽는 자리가 로드맵 폴더(roadmaps_dir)를 넘기지 않았다')" "뿌리 없는 repo 가 roadmaps_dir 을 넘기지 않으면 사유(죽지 않는다)"
python3 -c 'import sys; p=sys.argv[1]; s=open(p, encoding="utf-8").read(); s=s.replace("| C1 | 반영 | §1 |\n", ""); open(p, "w", encoding="utf-8").write(s)' "$T/lone/design.md"
assert_eq "$(lone)" "1" "INTENT.md 없음: rc 는 빠진 번호 규칙 그대로(C1 이 빠지면 1)"

# ── --impl — 결과 파일은 머리와 펜스 안을 뺀 본문에서 AC 줄을 읽는다 ─────────
design "$ROWS_ALL" "$ORIGIN_OK"
SHA="$(g rev-parse HEAD)"
printf -- '---\ntype: job-result\nstage: implement\nplan: 1\nattempt: 1\nrole: worker\nhead: %s\nbundle_at: %s\njob_at: %s\n---\n\nAC1: 구현됨 — a\n\n```text\nAC1: 구현됨 — 인용\n```\n\nAC2: 미룸 — 뒤\n' "$SHA" "$SHA" "$SHA" > "$T/result.md"
(cd "$W" && python3 "$C" --impl "$J1/design.md" "$T/result.md") > "$T/out.txt" 2>&1
assert_not_contains "$(cat "$T/out.txt")" "보고에 AC1 가 두 번" "--impl: 결과 파일의 펜스 안 AC 줄은 읽지 않는다"
assert_grep "$(sed -n 1p "$T/out.txt")" "^구현 대조:" "--impl: 결과 파일의 첫 줄이 「구현 대조:」 로 시작"
assert_contains "$(cat "$T/out.txt")" "미룸 표에 없는 미룸/빠짐 — AC2(미룸)" "--impl: 결과 파일의 펜스 밖 AC 줄은 읽는다"
sed -n '/^AC1: 구현됨 — a$/,$p' "$T/result.md" > "$T/plain.md"
(cd "$W" && python3 "$C" --impl "$J1/design.md" "$T/plain.md") > "$T/out.txt" 2>&1
assert_contains "$(cat "$T/out.txt")" "구현 대조 검사 불가 — 보고에 AC1 가 두 번 있다" "--impl: 결과 파일이 아닌 보고는 지금 그대로(펜스 안 줄도 읽는다)"

# ── 옛 형식 — notices 칸 · 알림 줄이 없다 ──────────────────────────────────
mkdir -p "$T/old"
printf -- '---\ntype: epic-bundle\nepic: X1\nroadmap: docs/none/roadmap.md\nids: [C1]\n---\n\n# X1 — 옛 묶음\n' > "$T/old/X1.md"
printf -- '---\nsource_interview: docs/none/X1.md\n---\n\n# 옛 설계\n\n### §1 하나\n\n- 하나\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| C1 | 반영 | §1 |\n' > "$T/old/x1-design.md"
(cd "$T/old" && python3 "$C" X1.md x1-design.md --json) > "$T/out.txt" 2>&1
assert_eq "$(jsf "('notices' in r, r['mode'], r['status'])")" "(False, 'bundle', 0)" "옛 형식: --json 에 notices 키가 없다"
(cd "$T/old" && python3 "$C" X1.md x1-design.md) > "$T/out.txt" 2>&1
assert_not_contains "$(cat "$T/out.txt")" "알림 — " "옛 형식: 원문 대조 절이 없어도 글 출력에 알림이 없다"
assert_eq "$(cat "$T/out.txt")" "번호 대조: 빠진 번호 없음 (묶음 번호 1개 · 표 번호 1개)" "옛 형식: 글 출력 전체 그대로"

# ── 모르는 layout — 옛 형식 규칙으로 읽지 않고 멈춘다(통합 리뷰 넘김 B) ───────
mkdir -p "$T/ul/docs/ul"
printf -- '---\ntype: roadmap\nlayout: foo\n---\n\n# 모르는 형식의 로드맵\n' > "$T/ul/docs/ul/roadmap.md"
printf -- '---\ntype: epic-bundle\nepic: U1\nroadmap: docs/ul/roadmap.md\nids: [C1]\n---\n\n# U1 — 묶음\n' > "$T/ul/docs/ul/U1.md"
printf -- '---\nsource_interview: docs/ul/U1.md\nroadmap: docs/ul/roadmap.md\n---\n\n# 모르는 형식 설계\n\n### §1 하나\n\n- 하나\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| C1 | 반영 | §1 |\n\n## Acceptance Criteria\n\n- AC1: 하나\n' > "$T/ul/docs/ul/u1-design.md"
printf 'AC1: 구현됨 — 하나\n' > "$T/ul/report.md"
ul() { (cd "$T/ul" && python3 "$C" "$@") > "$T/out.txt" 2>&1; echo $?; }
assert_eq "$(ul docs/ul/U1.md docs/ul/u1-design.md)" "3" "모르는 layout: 번호 대조는 검사 불가(3)"
assert_eq "$(cat "$T/out.txt")" "번호 대조 검사 불가 — 모르는 형식 — docs/ul/roadmap.md 머리말 layout: foo (아는 값: team)" "모르는 layout: 번호 대조의 사유"
assert_eq "$(ul --impl docs/ul/u1-design.md report.md)" "3" "모르는 layout: 구현 대조도 검사 불가(3)"
assert_eq "$(cat "$T/out.txt")" "구현 대조 검사 불가 — 모르는 형식 — docs/ul/roadmap.md 머리말 layout: foo (아는 값: team)" "모르는 layout: 구현 대조의 사유"
python3 -c 'import sys; p=sys.argv[1]; s=open(p, encoding="utf-8").read(); open(p, "w", encoding="utf-8").write(s.replace("layout: foo\n", ""))' "$T/ul/docs/ul/roadmap.md"
assert_eq "$(ul docs/ul/U1.md docs/ul/u1-design.md)" "0" "모르는 layout 양의 짝: layout 줄을 지우면 번호 대조 rc 0"
assert_not_contains "$(ul --impl docs/ul/u1-design.md report.md; cat "$T/out.txt")" "모르는 형식" "모르는 layout 양의 짝: layout 줄을 지우면 구현 대조에 「모르는 형식」 이 없다"

# ── 번호 대조 표가 없는 team design.md — 옛 형식의 설계문서와 같은 규칙(검사 불가) ─
printf -- '---\ntype: design\njob: E1\n---\n\n# 첫 읽기 — 표 없는 설계\n\n### §1 하나\n\n번호 대조 표를 아직 두지 않았다.\n\n%s\n' "$ORIGIN_OK" > "$W/$J1/design.md"
assert_eq "$(cov)" "3" "번호 대조 없는 team design.md: 검사 불가(3)"
assert_eq "$(sed -n 1p "$T/out.txt")" '번호 대조 검사 불가 — spec 에 `## 번호 대조` 절이 없다' "번호 대조 없는 team design.md: 사유"
cov --json >/dev/null
assert_eq "$(jsf "(r['status'], r['notices'])")" "(3, [])" "번호 대조 없는 team design.md: team 의 검사 불가에도 notices 칸이 있다"
rm -f "$W/$J1/design.md"

# ── 단계 계산을 거쳐 — 블록 경고 · 알림 ─────────────────────────────────────
blk() { js "$T/s.json" "[b for b in r['blocks'] if b['id']=='$1'][0]['$2']"; }   # blk <번호> <칸>
commit_design() { g add -- "$J1/design.md" && g commit -qm "$1" && g push -q origin HEAD; }
g checkout -q -b feature/tm-e1 main
design "$ROWS_NO_C1" ""
commit_design "원문 대조 없는 설계 · C1 빠짐"
status "$T/s.json" >/dev/null
assert_contains "$(blk E1 warnings)" "생략: " "단계 계산: 번호 파일의 번호가 빠지면 「생략」"
assert_contains "$(blk E1 warnings)" "C1" "단계 계산: 빠진 번호 C1"
assert_contains "$(blk E1 notes)" '번호 대조 알림: 설계문서에 `## 원문 대조` 표가 없다' "단계 계산: 원문 대조 표가 없다는 알림이 블록 알림에"
design "$ROWS_ALL" "$ORIGIN_CHANGED_NO_REASON"
commit_design "원문 대조 · 얕은 답"
SRC="$(status "$T/s.json")"
assert_eq "$SRC" "1" "단계 계산: 얕은 답은 지금 규칙대로 경고(1)"
assert_not_contains "$(blk E1 notes)" "번호 대조 알림" "단계 계산: 원문 대조 표가 있으면 알림이 없다"
assert_contains "$(blk E1 warnings)" "얕은 답 1개: $J1/design.md — 팀 폴더(원문 대조의 「바꿈」 행에 근거가 없다)" "단계 계산: 원문 대조의 얕은 답이 경고 줄에"
design "$ROWS_REJECT_S1" "$ORIGIN_OK"
commit_design "S1 기각"
assert_eq "$(status "$T/s.json")" "0" "단계 계산: 기본 브랜치에 E3 의 design.md 가 없으면 S1 을 받든다(0)"
assert_eq "$(blk E1 warnings)" "[]" "단계 계산: 받듦 — 경고 없음(셀 수 없음도 없다)"
g checkout -q main
printf -- '---\ntype: design\njob: E3\n---\n\n# 이어 읽기 — 기본 브랜치의 받듦 픽스처\n\n### §1 얹기\n\n얹는다.\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| C3 · S4 | 반영 | §1 |\n| S1 | 기각 | E1 이 받는다 |\n' > "$W/$J3/design.md"
g add -- "$J3/design.md" && g commit -qm "E3 설계 — S1 기각" && g push -q origin main
g checkout -q feature/tm-e1
status "$T/s.json" >/dev/null
assert_contains "$(blk E1 warnings)" "받드는 에픽 없는 발화 1개: $J1/design.md — S1" "단계 계산: 기본 브랜치 과제 폴더의 E3 design.md 가 S1 을 기각하면 받드는 에픽 없는 발화"
printf -- '---\ntype: design\njob: E1\n---\n\n# 첫 읽기 — 표 없는 설계\n\n### §1 하나\n\n표가 없다.\n\n%s\n' "$ORIGIN_OK" > "$W/$J1/design.md"
commit_design "번호 대조 표 없는 설계"
assert_eq "$(status "$T/s.json")" "3" "단계 계산: 번호 대조 표가 없는 team design.md 는 검사 불가(3)"
assert_contains "$(js "$T/s.json" "r['unknown_reasons']")" 'E1 spec 에 `## 번호 대조` 절이 없다' "단계 계산: 그 사유가 검사 불가 사유에"

finish
