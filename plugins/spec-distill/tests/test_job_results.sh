#!/usr/bin/env bash
# job_results.py — 결과 대조(check)와 받음 줄 다시 계산(receipt) · Git.names · Git.touched (AC10 · AC29).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_job_results.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
. "$ROOT/plugins/spec-distill/tests/fixtures/team_repo.sh"
JRC="$S/job_results.py"
team_repo && ok "팀 레포를 세웠다(${TM})" || { no "팀 레포를 세우지 못했다 — $(cat "$T/out.txt")"; finish; }
claim || { no "지휘 표지를 쥐지 못했다 — $(cat "$T/led.txt")"; finish; }   # 사람 줄 관문(과제 11)이 대조 전에 결과의 줄을 본다

JOB=E1
jr() {  # jr <브랜치> <결과 파일 이름> [인자…] — $JOB 의 결과 파일을 대조하고 rc 를 echo 한다. 출력은 $T/out.txt
  local br="$1" name="$2"; shift 2
  (cd "$W" && python3 "$JRC" check --roadmap "$RM" --job "$JOB" --branch "$br" --result "$name" --date 2026-11-20 "$@") > "$T/out.txt" 2>&1
  echo $?
}
jraw() {  # jraw <인자…> — check 를 그 인자 그대로 부르고 rc 를 echo 한다
  (cd "$W" && python3 "$JRC" check "$@") > "$T/out.txt" 2>&1
  echo $?
}
mutate() {  # mutate <결과 파일> <변이 이름> — 결과 파일 글을 그 변이로 고친다(CODE · GOOD · OTHER 는 환경에서)
  python3 - "$1" "$2" <<'PY'
import os, re, sys
path, kind = sys.argv[1], sys.argv[2]
t = open(path, encoding="utf-8", newline="").read()
code, good, other = os.environ["CODE"], os.environ.get("GOOD", ""), os.environ.get("OTHER", "")
lines = t.split("\n")
if kind == "no-end":
    t = "\n".join(l for l in lines if not l.startswith("끝 — "))
elif kind == "end-differs":
    t = t.replace("끝 — " + code, "끝 — " + good)
elif kind == "no-head":
    close = lines.index("---", 1)
    t = "\n".join(lines[close + 1:])
elif kind == "head-elsewhere":
    t = t.replace("head: " + code, "head: " + other).replace("끝 — " + code, "끝 — " + other)
elif kind == "head-ghost":
    t = t.replace("head: " + code, "head: " + "c" * 40).replace("끝 — " + code, "끝 — " + "c" * 40)
elif kind == "bundle-ghost":
    t = re.sub(r"(?m)^bundle_at: .*$", "bundle_at: " + "d" * 40, t)
elif kind == "job-ghost":
    t = re.sub(r"(?m)^job_at: .*$", "job_at: " + "e" * 40, t)
elif kind == "ac-missing":
    t = "\n".join(l for l in lines if not l.startswith("AC2:"))
elif kind == "ac-unknown":
    t = t.replace("끝 — ", "AC9: 구현됨 — 설계에 없는 번호\n끝 — ")
elif kind == "ac-shape":
    t = t.replace("AC1: 구현됨 — src/e1/a.txt", "AC1: 했다")
elif kind == "fenced":
    t = t.replace("끝 — " + code, "```text\n끝 — " + code + "\n```")
elif kind == "bom":
    t = "﻿" + t
elif kind == "crlf":
    t = t.replace("\n", "\r\n")
elif kind == "stage-skew":
    t = re.sub(r"(?m)^stage: .*$", "stage: plan", t)
elif kind == "plan-skew":
    t = re.sub(r"(?m)^plan: .*$", "plan: 2", t)
elif kind == "empty-end":
    t = t.replace("끝 — " + code, "끝 — ")
elif kind == "ac-twice":
    t = t.replace("끝 — ", "AC3: 구현됨 — 한 번\nAC3: 미룸 — 두 번\n끝 — ")
elif kind == "ac-out-of-scope":
    t = t.replace("끝 — ", "AC3: 구현됨 — 범위 밖이지만 적었다\n끝 — ")
elif kind == "attempt-2":
    t = t.replace("attempt: 1", "attempt: 2")
elif kind == "no-output":
    t = "\n".join(l for l in lines if not l.startswith("산출물:"))
elif kind == "ghost-output":
    t = re.sub(r"(?m)^산출물: .*$", "산출물: src/e2/none.md", t)
else:
    sys.exit("모르는 변이: " + kind)
open(path, "w", encoding="utf-8", newline="").write(t)
PY
}
variant() {  # variant <바탕 커밋> <이름> <명령…> — 바탕에서 v/<이름> 을 갈라 명령을 돌리고 커밋한다(push 하지 않는다)
  local base="$1" name="$2"; shift 2
  g checkout -q -b "v/$name" "$base" && "$@" && g add -A -- . && g commit -qm "변이 $name" && g checkout -q main
}
reject() {  # reject <변이 이름> <말> <라벨> [결과 파일 이름] — rc 1 과 사유의 말을 함께 단언한다
  assert_eq "$(jr "v/$1" "${4:-implement-plan-1-1.md}")" "1" "대조: $3 — rc 1"
  assert_contains "$(cat "$T/out.txt")" "$2" "대조: $3 — 사유에 「${2}」"
  assert_contains "$(sed -n 1p "$T/out.txt")" "결과 대조: 거절 " "대조: $3 — 첫 줄이 거절"
  assert_not_contains "$(cat "$T/out.txt")" "- 결과 받음 · " "대조: $3 — 거절이면 받음 줄을 내지 않는다"
}

# ── 픽스처: E1 (설계 흐름) ───────────────────────────────────────────────────
R1="$TM/jobs/E1/results/implement-plan-1-1.md"
B="$(g rev-parse origin/main)"
g checkout -q -b other main && put src/other.txt "다른 브랜치의 글" && g commit -qm "다른 브랜치" && OTHER="$(g rev-parse HEAD)"
g checkout -q -b feature/tm-e1 main
put "$TM/jobs/E1/design.md" "$(printf -- '---\ntype: design\njob: E1\n---\n\n# 첫 읽기 — 결과 대조 픽스처 설계\n\n## Acceptance Criteria\n\n- AC1: 결과 파일의 기계 줄을 펜스 밖에서만 읽는다\n- AC2: 받음 줄을 그 결과 파일로 다시 잰다\n- AC3: 받은 뒤의 변경으로 낡음을 잰다\n\n## 미룸\n\n| 항목 | 이유 | 받는 곳 |\n|---|---|---|')"
put "$TM/jobs/E1/plan-1.md" "$(printf '# 첫 읽기 — 대조 픽스처 계획\n\n## 머리\n\n범위 밖 글: AC3 은 다음 계획이다.\n\n### Task 1: 읽기와 다시 재기\n\nAC1 · AC2 를 덮는다.')"
put src/e1/a.txt "첫 읽기의 코드"
g commit -qm "E1 설계 · 계획 · 코드" && CODE="$(g rev-parse HEAD)"
export CODE OTHER
assert_eq "$(sync E1 implement-plan-1-1.md --role worker --bundle-at "$B" --job-at "$CODE")" "0" "준비: 결과 파일 머리"
printf 'AC1: 구현됨 — src/e1/a.txt\nAC2: 미룸 — 다음 계획\n' >> "$W/$R1"
assert_eq "$(sync E1 implement-plan-1-1.md --end "$CODE")" "0" "준비: 끝 줄"
g add -- "$R1" && g commit -qm "E1 결과"
assert_eq "$(human "spec 승인" E1 - - 2026-11-20)" "0" "준비: E1 의 spec 승인 줄"
assert_eq "$(human "계획 검토" E1 1 - 2026-11-21)" "0" "준비: E1 의 계획 검토 줄"
g add -- "$TM/jobs/E1/INTENT.md" && g commit -qm "E1 승인 줄" && g push -q origin feature/tm-e1 && GOOD="$(g rev-parse HEAD)"
export GOOD
g checkout -q main

# ── 통과 ─────────────────────────────────────────────────────────────────────
FIRST="결과 대조: 통과 — implement-plan-1-1.md · head ${CODE:0:8} · AC 2개(구현됨 1 · 미룸 1 · 빠짐 0)"
assert_eq "$(jr feature/tm-e1 implement-plan-1-1.md)" "0" "대조: 통과 rc 0"
assert_eq "$(sed -n 1p "$T/out.txt")" "$FIRST" "대조: 첫 줄(범위는 계획 1 의 AC 둘 — AC3 은 범위 밖)"
assert_contains "$(cat "$T/out.txt")" "- 결과 받음 · 2026-11-20 · 「implement-plan-1-1.md · $CODE · ${FIRST}」" "대조: 리더가 적을 받음 줄을 낸다"
assert_eq "$(grep -c '^- 결과 받음 · ' "$T/out.txt")" "1" "대조: 받음 줄은 줄 머리에 한 번"

# ── 거절 갈래 ────────────────────────────────────────────────────────────────
for v in no-end end-differs no-head head-elsewhere head-ghost bundle-ghost job-ghost ac-missing ac-unknown ac-shape fenced bom crlf \
         stage-skew plan-skew empty-end ac-twice ac-out-of-scope; do
  variant "$GOOD" "$v" mutate "$W/$R1" "$v" || no "변이 브랜치 $v 를 만들지 못했다"
done
reject no-end "끝 줄이 없다" "「끝」 없음(no-end)"
reject end-differs "head 와 다르다" "head ≠ 「끝」(end-differs)"
reject no-head "머리" "머리 없음(no-head)"
reject head-elsewhere "과제 브랜치에 없다" "head 가 브랜치에 없음(head-elsewhere)"
reject head-ghost "head cccccccc 가 없는 커밋" "head 가 없는 커밋(head-ghost)"
reject bundle-ghost "bundle_at" "bundle_at 이 없는 커밋(bundle-ghost)"
reject job-ghost "job_at" "job_at 이 없는 커밋(job-ghost)"
reject ac-missing "AC2" "범위 AC 빠짐(ac-missing)"
reject ac-unknown "AC9" "설계에 없는 AC(ac-unknown)"
reject ac-shape "보고 줄" "AC 줄 꼴 깨짐(ac-shape)"
reject fenced "끝 줄이 없다" "펜스 안의 끝 줄은 끝 줄이 아니다(fenced)"
reject bom "머리" "BOM 은 머리 없음(bom)"
assert_eq "$(jr v/crlf implement-plan-1-1.md)" "0" "대조: CRLF 는 LF 와 같게 읽는다(crlf) — rc 0"
assert_eq "$(sed -n 1p "$T/out.txt")" "$FIRST" "대조: CRLF 의 첫 줄은 통과 그대로"
variant "$GOOD" renamed g mv -- "$R1" "$TM/jobs/E1/results/implement-plan-1-2.md" || no "변이 브랜치 renamed 를 만들지 못했다"
reject renamed "이름과 다르다" "이름과 머리 어긋남(renamed)" implement-plan-1-2.md
reject stage-skew "머리의 단계 · 계획 · 시도(plan · 1 · 1)가 이름과 다르다" "이름과 머리 어긋남 — 단계 축(stage-skew)"
reject plan-skew "머리의 단계 · 계획 · 시도(implement · 2 · 1)가 이름과 다르다" "이름과 머리 어긋남 — 계획 번호 축(plan-skew)"
reject empty-end "「끝」 줄에 커밋 글이 없다" "끝 줄의 커밋 글이 빔(empty-end)"
assert_eq "$(sed -n 1p "$T/out.txt")" "결과 대조: 거절 1건 — implement-plan-1-1.md" "대조: 빈 끝 줄은 「끝 줄이 없다」 를 덧내지 않는다(empty-end)"
reject ac-twice "보고에 AC3 가 두 번 있다" "같은 AC 줄 둘 — 범위 밖 AC 라도(ac-twice)"
assert_eq "$(jr v/ac-out-of-scope implement-plan-1-1.md)" "0" "대조: 설계에 있고 계획 범위 밖인 AC 줄은 거절이 아니다(ac-out-of-scope) — rc 0"
assert_eq "$(sed -n 1p "$T/out.txt")" "$FIRST" "대조: 범위 밖 AC 줄은 첫 줄의 수에 실리지 않는다(ac-out-of-scope)"
plan_noac() { put "$TM/jobs/E1/plan-1.md" "$(printf '# 번호 없는 계획\n\n### Task 1: 번호를 적지 않은 일\n\n그냥 한다.')"; }
variant "$GOOD" plan-noac plan_noac || no "변이 브랜치 plan-noac 을 만들지 못했다"
assert_eq "$(jr v/plan-noac implement-plan-1-1.md)" "3" "대조: 계획 파일이 있는데 범위가 비면 검사 불가(plan-noac) — rc 3"
assert_contains "$(cat "$T/out.txt")" "검사 불가 사유: 범위를 정할 수 없다 — $TM/jobs/E1/plan-1.md" "대조: 빈 범위의 사유가 계획 파일을 댄다(plan-noac)"
assert_not_contains "$(cat "$T/out.txt")" "- 결과 받음 · " "대조: 빈 범위면 받음 줄을 내지 않는다(plan-noac)"
as_dir() { g rm -q -- "$1" && put "$1/inner.md" "파일 자리에 둔 폴더"; }
variant "$GOOD" design-dir as_dir "$TM/jobs/E1/design.md" || no "변이 브랜치 design-dir 을 만들지 못했다"
variant "$GOOD" plan-dir as_dir "$TM/jobs/E1/plan-1.md" || no "변이 브랜치 plan-dir 을 만들지 못했다"
variant "$GOOD" result-dir as_dir "$R1" || no "변이 브랜치 result-dir 을 만들지 못했다"
for d in design-dir:"$TM/jobs/E1/design.md" plan-dir:"$TM/jobs/E1/plan-1.md" result-dir:"$R1"; do
  v="${d%%:*}"; at="${d#*:}"
  assert_eq "$(jr "v/$v" implement-plan-1-1.md)" "3" "대조: 파일 자리가 폴더면 검사 불가($v) — rc 3"
  assert_eq "$(sed -n 1p "$T/out.txt")" "결과 대조: 검사 불가 — implement-plan-1-1.md" "대조: 파일 자리가 폴더일 때의 첫 줄($v)"
  assert_contains "$(cat "$T/out.txt")" "파일이 아닌 경로다" "대조: 파일 자리가 폴더라는 사유($v)"
  assert_contains "$(cat "$T/out.txt")" "$at" "대조: 그 경로를 댄다($v)"
  assert_not_contains "$(cat "$T/out.txt")" "- 결과 받음 · " "대조: 파일 자리가 폴더면 받음 줄을 내지 않는다($v)"
done
newer_file() { cp "$W/$R1" "$W/$TM/jobs/E1/results/implement-plan-1-2.md" && mutate "$W/$TM/jobs/E1/results/implement-plan-1-2.md" attempt-2; }
variant "$GOOD" newer newer_file || no "변이 브랜치 newer 를 만들지 못했다"
reject newer "더 새 시도 implement-plan-1-2.md" "더 새 시도(newer)"
variant "$GOOD" no-plan g rm -q -- "$TM/jobs/E1/plan-1.md" || no "변이 브랜치 no-plan 을 만들지 못했다"
reject no-plan "AC3" "계획 파일 없음 — 범위가 AC 전부(no-plan)"
assert_eq "$(jr v/no-end implement-plan-1-1.md)" "1" "대조: 사유를 모두 모은다 — 준비"
variant v/no-end no-end-ghost mutate "$W/$R1" bundle-ghost || no "변이 브랜치 no-end-ghost 를 만들지 못했다"
assert_eq "$(jr v/no-end-ghost implement-plan-1-1.md)" "1" "대조: 사유 둘 — rc 1"
assert_eq "$(sed -n 1p "$T/out.txt")" "결과 대조: 거절 2건 — implement-plan-1-1.md" "대조: 하나에서 멈추지 않고 사유를 센다"
assert_eq "$(jr feature/tm-e1 BLOCKED.md)" "1" "AC29: 막힘 파일은 결과 대조의 대상이 아니다"
assert_contains "$(cat "$T/out.txt")" "결과 파일 이름 꼴이 아니다" "AC29: 그 사유"
variant "$GOOD" design-noac put "$TM/jobs/E1/design.md" "# 수용 기준 절이 없는 설계" || no "변이 브랜치 design-noac 을 만들지 못했다"
assert_eq "$(jr v/design-noac implement-plan-1-1.md)" "3" "대조: 설계문서에 수용 기준 절이 없으면 검사 불가 — rc 3"
assert_eq "$(sed -n 1p "$T/out.txt")" "결과 대조: 검사 불가 — implement-plan-1-1.md" "대조: 검사 불가의 첫 줄"
assert_contains "$(cat "$T/out.txt")" "검사 불가 사유: 설계문서에 수용 기준 절이 없다" "대조: 검사 불가 사유"
assert_not_contains "$(cat "$T/out.txt")" "- 결과 받음 · " "대조: 검사 불가면 받음 줄을 내지 않는다"
assert_eq "$(jr feature/tm-e1 implement-plan-1-7.md)" "1" "대조: 그 끝에 없는 결과 파일 — rc 1"
assert_contains "$(cat "$T/out.txt")" "결과 파일이 없다" "대조: 없는 결과 파일의 사유"

# ── 설계 없는 흐름 (E2 — 블록에 산출물 칸) ───────────────────────────────────
R2="$TM/jobs/E2/results/implement-1.md"
g checkout -q -b feature/tm-e2 main
put "$TM/jobs/E2/survey.md" "$(printf '| 파일 | 읽은 것 |\n|---|---|\n| a | 결과 대조 |')"
g commit -qm "E2 조사 표" && SURVEY="$(g rev-parse HEAD)"
assert_eq "$(sync E2 implement-1.md --role worker --bundle-at "$B" --job-at "$SURVEY")" "0" "준비: E2 결과 파일 머리"
printf '산출물: %s/jobs/E2/survey.md\n' "$TM" >> "$W/$R2"
assert_eq "$(sync E2 implement-1.md --end "$SURVEY")" "0" "준비: E2 끝 줄"
g add -- "$R2" && g commit -qm "E2 결과"
assert_eq "$(human "흐름 승인" E2 - - 2026-11-22)" "0" "준비: E2 의 흐름 승인 줄"
g add -- "$TM/jobs/E2/INTENT.md" && g commit -qm "E2 승인 줄" && g push -q origin feature/tm-e2 && GOOD2="$(g rev-parse HEAD)"
g checkout -q main
JOB=E2
assert_eq "$(jr feature/tm-e2 implement-1.md)" "0" "대조: 설계 없는 흐름 통과 rc 0"
assert_eq "$(sed -n 1p "$T/out.txt")" "결과 대조: 통과 — implement-1.md · head ${SURVEY:0:8} · 산출물 1개" "대조: 설계 없는 흐름의 첫 줄 끝이 산출물 수"
variant "$GOOD2" no-output mutate "$W/$R2" no-output || no "변이 브랜치 no-output 을 만들지 못했다"
variant "$GOOD2" ghost-output mutate "$W/$R2" ghost-output || no "변이 브랜치 ghost-output 을 만들지 못했다"
reject no-output "산출물 줄이 없다" "산출물 줄 없음(no-output)" implement-1.md
reject ghost-output "head 커밋에 없다" "산출물 경로가 head 에 없음(ghost-output)" implement-1.md
g branch -q -D feature/tm-e2
assert_eq "$(jr feature/tm-e2 implement-1.md)" "0" "대조: 로컬 브랜치가 없으면 origin 끝을 읽는다"
JOB=E1

# 끝 — 로컬에만 있는 브랜치: rc 0 과 「아직 안 올라옴」 줄 · 갈라진 브랜치: rc 3 「갈라짐」 (위의 v/* 는 모두 로컬에만 있다)
assert_eq "$(jr v/crlf implement-plan-1-1.md)" "0" "끝: 로컬에만 있는 브랜치 — rc 0"
assert_contains "$(cat "$T/out.txt")" "아직 안 올라옴" "끝: 로컬에만 있는 브랜치 — 알림"
assert_eq "$(sed -n 2p "$T/out.txt" | grep -c "^아직 안 올라옴 — v/crlf 의 로컬 끝")" "1" "끝: 알림은 첫 줄 뒤 한 줄"
FORK="$T/fork"
git clone -q "$T/origin.git" "$FORK"
fk() { git -C "$FORK" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }
g branch -q x/fork feature/tm-e1 && g push -q origin x/fork
fk fetch -q origin && fk checkout -q -b x/fork origin/x/fork
printf 'o\n' > "$FORK/other-side.txt"
fk add -- other-side.txt
fk commit -qm "다른 쪽 커밋"
fk push -q origin x/fork
g checkout -q x/fork && put local-side.txt l && g commit -qm "로컬 쪽 커밋" && g checkout -q main && g fetch -q origin
assert_eq "$(jr x/fork implement-plan-1-1.md)" "3" "끝: 갈라진 브랜치 — rc 3"
assert_contains "$(cat "$T/out.txt")" "갈라짐" "끝: 갈라진 브랜치 — 사유"

# ── 브랜치 고르기 · 사용법 ───────────────────────────────────────────────────
assert_eq "$(jraw --roadmap "$RM" --job E1 --result implement-plan-1-1.md --date 2026-11-20)" "0" "브랜치: --branch 가 없으면 블록의 계획 1 번째 브랜치"
assert_eq "$(sed -n 1p "$T/out.txt")" "$FIRST" "브랜치: 고른 브랜치의 결과 파일을 대조했다"
assert_eq "$(jraw --roadmap "$RM" --job E1 --result implement-plan-2-1.md)" "3" "브랜치: 계획 2 는 둘째 브랜치 — 그 브랜치가 없으면 3"
assert_contains "$(cat "$T/out.txt")" "feature/tm-e1b" "브랜치: 없는 브랜치의 이름을 댄다"
assert_eq "$(jraw --roadmap "$RM" --job E1 --result implement-plan-3-1.md)" "2" "브랜치: 블록에 없는 계획 번호의 브랜치 — 2"
assert_contains "$(cat "$T/out.txt")" "계획 3" "브랜치: 그 사유"
assert_eq "$(jraw --roadmap "$RM" --job E1 --branch feature/tm-e1)" "2" "사용법: --result 없음 → 2"
assert_contains "$(cat "$T/out.txt")" "required: --result" "사용법: --result 가 없다고 말한다"
assert_eq "$(jraw --roadmap "$RM" --job fix-typo --result implement-1.md)" "2" "사용법: 블록이 아닌 과제에 --branch 없음 → 2"
assert_contains "$(cat "$T/out.txt")" "--branch" "사용법: --branch 가 필요하다고 말한다"
assert_eq "$(jraw --roadmap "$RM" --job "../x" --branch feature/tm-e1 --result implement-plan-1-1.md)" "2" "사용법: 과제 이름 꼴이 아니면 2"
assert_contains "$(cat "$T/out.txt")" "사용법 오류 — 작업 이름은" "사용법: 과제 이름 사유"
assert_eq "$(jraw --roadmap "$RM" --job E1 --branch feature/tm-e1 --result implement-plan-1-1.md --date 2026-13-01)" "2" "사용법: 날짜 꼴이 아니면 2"
assert_contains "$(cat "$T/out.txt")" "--date" "사용법: 날짜 사유"
assert_eq "$(jraw --roadmap docs/tv/brief.md --job E1 --branch feature/tm-e1 --result implement-plan-1-1.md)" "2" "사용법: 로드맵 자리가 아니면 2"
assert_contains "$(cat "$T/out.txt")" "사용법 오류 — 로드맵 폴더(" "사용법: 로드맵 자리 사유"
put "${RD}old/roadmap.md" "$(printf -- '---\ntype: roadmap\nsource_brief: docs/tv/brief.md\n---\n\n# 옛 형식 대조 픽스처\n\n## 에픽\n')"
g commit -qm "옛 형식 로드맵" && g push -q origin main && g fetch -q origin
assert_eq "$(jraw --roadmap "${RD}old/roadmap.md" --job E1 --branch feature/tm-e1 --result implement-plan-1-1.md)" "2" "사용법: team 형식이 아닌 로드맵 → 2"
assert_contains "$(cat "$T/out.txt")" "team 형식" "사용법: team 형식이 아니라고 말한다"
assert_eq "$(jraw --roadmap "${RD}none/roadmap.md" --job E1 --branch feature/tm-e1 --result implement-plan-1-1.md)" "3" "검사 불가: 기본 브랜치에 로드맵이 없으면 3"
assert_contains "$(cat "$T/out.txt")" "기본 브랜치에 로드맵이 없다" "검사 불가: 로드맵 없음 사유"
assert_eq "$(jr no/such-branch implement-plan-1-1.md)" "3" "검사 불가: 브랜치가 로컬에도 origin 에도 없으면 3"
assert_contains "$(cat "$T/out.txt")" "no/such-branch" "검사 불가: 그 브랜치 이름을 댄다"
g remote set-head origin -d
assert_eq "$(jr feature/tm-e1 implement-plan-1-1.md)" "3" "검사 불가: 기본 브랜치(origin/HEAD)를 모르면 3"
assert_contains "$(sed -n 1p "$T/out.txt")" "결과 대조: 검사 불가 — 기본 브랜치를 알 수 없다 — origin/HEAD 가 없다" "검사 불가: 기본 브랜치를 모를 때의 첫 줄과 사유"
g remote set-head origin main

# ── Git.names · Git.touched · result_names · newest ──────────────────────────
pyq() {  # pyq <파이썬 식> — git · team · JR · rs 를 두고 식을 출력한다. 식은 이 테스트가 쓴 고정 문자열뿐이다
  (cd "$W" && python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import roadmap_status as rs, job_results as JR, team_layout as L
git = rs.Git(sys.argv[2]); team = L.team_from_roadmap(sys.argv[3], sys.argv[4])
print(eval(sys.argv[5]))' "$S" "$W/${AT:-}" "$RD" "$RM" "$1")
}
g checkout -q -b names main
for f in BLOCKED.md implement-plan-1-1.md implement-plan-1-3.md implement-plan-2-1.md review-1.md; do put "$TM/jobs/E3/results/$f" "이름만 보는 픽스처"; done
g commit -qm "결과 폴더 이름들" && NAMES="$(g rev-parse HEAD)" && g checkout -q main
export NAMES
assert_eq "$(pyq 'JR.check_result(git, git.commit("v/newer"), team, "E1", "implement-plan-1-1.md", newer_ok=True).problems')" "[]" "대조: newer_ok=True 면 「더 새 시도」 사유가 없다(newer)"
assert_contains "$(pyq 'JR.check_result(git, git.commit("v/newer"), team, "E1", "implement-plan-1-1.md").problems')" "더 새 시도 implement-plan-1-2.md" "대조: newer_ok 없이는 그 사유가 있다(양성 대조)"
assert_contains "$(pyq 'JR.check_result(git, git.commit("v/no-end"), team, "E1", "implement-plan-1-1.md", newer_ok=True).problems')" "끝 줄이 없다" "대조: newer_ok=True 여도 다른 사유는 그대로다"
assert_eq "$(pyq 'git.names(__import__("os").environ["NAMES"], team.results("E3"))')" "['.gitkeep', 'BLOCKED.md', 'implement-plan-1-1.md', 'implement-plan-1-3.md', 'implement-plan-2-1.md', 'review-1.md']" "Git.names: 폴더 바로 아래 이름들(정렬)"
assert_eq "$(pyq 'git.names("main", team.results("E9"))')" "[]" "Git.names: 없는 폴더는 []"
assert_eq "$(pyq '(git.names("f" * 40, team.results("E3")), len(git.failures))')" "(None, 1)" "Git.names: git 이 실패하면 None 과 failures"
assert_eq "$(pyq 'JR.result_names(git, __import__("os").environ["NAMES"], team, "E3")')" "['implement-plan-1-1.md', 'implement-plan-1-3.md', 'implement-plan-2-1.md', 'review-1.md']" "result_names: 막힘 파일 · .gitkeep 은 들지 않는다"
NM="['implement-plan-1-1.md', 'implement-plan-1-3.md', 'implement-plan-2-1.md', 'review-1.md']"
assert_eq "$(pyq "JR.newest(${NM}, L.STAGES[2], 1)")" "implement-plan-1-3.md" "newest: 같은 단계 · 같은 계획의 가장 큰 시도"
assert_eq "$(pyq "JR.newest(${NM}, L.STAGES[2], None)")" "None" "newest: 계획 번호 없는 이름이 없으면 None"
assert_eq "$(pyq "JR.newest(${NM}, L.STAGES[3], None)")" "review-1.md" "newest: 계획 번호 없는 이름"
assert_eq "$(pyq 'JR.result_names(git, "f" * 40, team, "E3")')" "None" "result_names: 폴더를 못 읽으면 None"
assert_eq "$(pyq '(git.touched("f" * 40, [], []), len(git.failures))')" "([], 0)" "Git.touched: 볼 자리가 비면 git 을 부르지 않고 []"
assert_eq "$(pyq '(git.touched("f" * 40, [], ["src/e1/"]), len(git.failures))')" "(None, 1)" "Git.touched: git 이 실패하면 None 과 failures"
assert_eq "$(pyq 'git.touched("feature/tm-e1", ["main"], ["src/e1/", team.design("E1")])')" "['$TM/jobs/E1/design.md', 'src/e1/a.txt']" "Git.touched: 볼 자리 아래 바뀐 파일(정렬)"
assert_eq "$(AT=docs/tv pyq 'git.touched("feature/tm-e1", ["main"], ["src/e1/", team.design("E1")])')" "['$TM/jobs/E1/design.md', 'src/e1/a.txt']" "Git.touched: 하위 폴더에서 불러도 레포 뿌리 기준으로 같은 파일"
assert_eq "$(pyq 'JR.plan_scope(None, ["AC1", "AC2"])')" "['AC1', 'AC2']" "plan_scope: 계획 글이 없으면 전부"
assert_eq "$(pyq 'JR.plan_scope("# p\n\nAC1 머리 밖\n\n### Task 1: x\n\nAC3 · AC2 · AC7\n", ["AC1", "AC2", "AC3"])')" "['AC2', 'AC3']" "plan_scope: task 절의 AC 가운데 설계에 있는 것(설계의 차례)"

# ── receipt — 받음 줄 다시 계산 (단계 계산 없이 닿는 갈래 · 나머지는 Task 7 의 「받음:」) ─
rcpt() {  # rcpt <끝 ref> <받음 줄…> — E1 INTENT.md 에 줄들을 더한 글로 receipt 를 부르고 「상태|알림 / …|가장 새 이름」 을 낸다
  local tip="$1"; shift
  (cd "$W" && python3 - "$S" "$W/${AT:-}" "$RD" "$RM" "$tip" "$@" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import roadmap_status as rs, job_results as JR, team_layout as L, team_files as F
import os
git = rs.Git(sys.argv[2]); team = L.team_from_roadmap(sys.argv[3], sys.argv[4])
main = git.commit("origin/main"); tip = git.commit(sys.argv[5]) or sys.argv[5]
text = git.blob(main, team.intent("E1"))
for line in sys.argv[6:]:
    text = F.append_decision(text, line) if F.decision_problem(line) is None else text.rstrip("\n") + "\n" + line + "\n"
state, notes, latest = JR.receipt(git, None if os.environ.get("NOMAIN") else main, tip, team, "E1", text, L.STAGES[2], 1, ["src/e1/"], [])
print("%s|%s|%s" % (state, " / ".join(notes), latest))
PY
  )
}
NOSUCH="ffffffffffffffffffffffffffffffffffffffff"   # 없는 커밋
LINE_GOOD="- 결과 받음 · 2026-11-20 · 「implement-plan-1-1.md · $CODE · ${FIRST}」"
LINE_OTHER="- 결과 받음 · 2026-11-19 · 「implement-plan-1-1.md · $OTHER · ${FIRST}」"
assert_eq "$(rcpt feature/tm-e1)" "없음||implement-plan-1-1.md" "받음: 받음 줄 없음 — 없음"
assert_eq "$(rcpt main "$LINE_GOOD")" "없음||None" "받음: 결과 파일이 없으면 받음 줄이 있어도 없음"
assert_eq "$(rcpt "$NOSUCH" "$LINE_GOOD")" "세지 않음|받음 줄을 세지 않았다: 결과 폴더를 읽지 못했다|None" "받음: 결과 폴더를 못 읽으면 세지 않음"
assert_eq "$(rcpt feature/tm-e1 "$LINE_GOOD")" "받음||implement-plan-1-1.md" "받음: 대조를 통과한 받음 줄 — 받음(RECEIVED)"
assert_eq "$(rcpt feature/tm-e1 "$LINE_OTHER" "$LINE_GOOD")" "받음||implement-plan-1-1.md" "받음: 받음 줄 둘이면 뒤의 것이 이긴다(뒤가 맞는 줄)"
assert_eq "$(rcpt feature/tm-e1 "$LINE_GOOD" "$LINE_OTHER" | cut -d'|' -f1)" "세지 않음" "받음: 받음 줄 둘이면 뒤의 것이 이긴다(뒤가 틀린 줄)"
assert_contains "$(rcpt feature/tm-e1 "$LINE_OTHER")" "받음 줄을 세지 않았다: implement-plan-1-1.md — " "받음: 받음 커밋 ≠ head — 세지 않음"
assert_eq "$(rcpt feature/tm-e1 "$LINE_OTHER" | cut -d'|' -f1)" "세지 않음" "받음: 받음 커밋 ≠ head 의 상태"
assert_eq "$(rcpt v/no-end "$LINE_GOOD")" "세지 않음|받음 줄을 세지 않았다: implement-plan-1-1.md — 끝 줄이 없다 — 아직 도는 중이다|implement-plan-1-1.md" "받음: 대조 불통 — 세지 않음과 첫 사유"
assert_eq "$(rcpt v/newer "$LINE_GOOD")" "낡음|받은 뒤 바뀜: implement-plan-1-1.md — 더 새 시도 implement-plan-1-2.md 가 있다|implement-plan-1-2.md" "받음: 더 새 시도 — 낡음"
assert_eq "$(rcpt feature/tm-e1 "- 결과 받음 · 2026-11-20 · 받았다" | cut -d'|' -f1,2)" "없음|받음 줄을 세지 않았다: 꼴이 깨졌다 — - 결과 받음 · 2026-11-20 · 받았다" "받음: 꼴이 깨진 받음 줄은 알리고 세지 않는다"
assert_eq "$(rcpt feature/tm-e1 "- 결과 받음 · 2026-11-20 · 「implement-plan-2-1.md · $CODE · x」" | cut -d'|' -f1)" "없음" "받음: 다른 계획의 받음 줄은 보지 않는다"
assert_eq "$(rcpt feature/tm-e1 "$LINE_GOOD" "- 결과 받음 · 2026-11-21 · 「implement-plan-2-1.md · $OTHER · x」")" "받음||implement-plan-1-1.md" "받음: 맞는 줄 뒤에 다른 계획의 받음 줄이 와도 그 결과 파일의 마지막 줄을 쓴다"
assert_eq "$(rcpt v/result-dir "$LINE_GOOD")" "세지 않음|받음 줄을 세지 않았다: implement-plan-1-1.md — 파일이 아닌 경로다(블롭이 아니다): $R1|implement-plan-1-1.md" "받음: 결과 파일 자리가 폴더면 죽지 않고 세지 않음"
assert_eq "$(rcpt v/design-dir "$LINE_GOOD" | cut -d'|' -f1)" "세지 않음" "받음: 설계문서 자리가 폴더면 세지 않음"
variant "$GOOD" code-after put src/e1/b.txt "받은 뒤의 코드" || no "변이 브랜치 code-after 를 만들지 못했다"
assert_eq "$(rcpt v/code-after "$LINE_GOOD")" "낡음|받은 뒤 바뀜: implement-plan-1-1.md — src/e1/b.txt|implement-plan-1-1.md" "받음: head 뒤 고칠 자리 변경 — 낡음"
assert_eq "$(AT=docs/tv rcpt v/code-after "$LINE_GOOD")" "낡음|받은 뒤 바뀜: implement-plan-1-1.md — src/e1/b.txt|implement-plan-1-1.md" "받음: 하위 폴더에서 불러도 고칠 자리 변경을 본다"
assert_eq "$(GIT_LITERAL_PATHSPECS=1 rcpt v/code-after "$LINE_GOOD")" "낡음|받은 뒤 바뀜: implement-plan-1-1.md — src/e1/b.txt|implement-plan-1-1.md" "받음: 환경에 GIT_LITERAL_PATHSPECS=1 이 있어도 받은 뒤 바뀜을 본다"
assert_eq "$(GIT_LITERAL_PATHSPECS=1 pyq 'git.touched("v/code-after", ["feature/tm-e1", "main"], ["src/e1/"])')" "['src/e1/b.txt']" "Git.touched: GIT_LITERAL_PATHSPECS=1 이어도 :(top,literal) 이 그 경로를 본다"
assert_eq "$(GIT_ICASE_PATHSPECS=1 pyq 'git.touched("v/code-after", ["feature/tm-e1", "main"], ["SRC/E1/"])')" "[]" "Git.touched: GIT_ICASE_PATHSPECS=1 이어도 글자 그대로(대소문자가 다른 경로는 보지 않는다)"
assert_eq "$(pyq 'git.touched("v/code-after", ["feature/tm-e1", "main"], ["src/e1/"])')" "['src/e1/b.txt']" "Git.touched: 양성 대조 — 변수 없이 같은 호출이 그 파일을 본다"
assert_eq "$(GIT_LITERAL_PATHSPECS=1 pyq 'git.env.get("GIT_LITERAL_PATHSPECS")')" "1" "Git.touched 의 환경만 끈다 — Git.env 에는 그 변수가 그대로다"
assert_eq "$(NOMAIN=1 rcpt v/code-after "$LINE_GOOD")" "세지 않음|받음 줄을 세지 않았다: implement-plan-1-1.md — 기본 브랜치를 몰라 받은 뒤의 변경을 가르지 못했다|implement-plan-1-1.md" "받음: 기본 브랜치를 모르면 받은 뒤의 변경을 세지 않고 세지 않음"
design_more() { python3 -c 'import sys; p = sys.argv[1]; t = open(p, encoding="utf-8").read(); i = t.index("\n# ") + 1; j = t.index("\n", i) + 1; open(p, "w", encoding="utf-8").write(t[:j] + "\n받은 뒤 설계 본문에 더한 문단\n" + t[j:])' "$W/$TM/jobs/E1/design.md"; }   # 제목 줄 바로 아래 = 본문(미룸 절이 아니다 — K13)
variant "$GOOD" design-after design_more || no "변이 브랜치 design-after 를 만들지 못했다"
STUBG='type("G", (), {"blob": lambda s, r, p: None, "absent": lambda s, r, p: ABS, "run": lambda s, *a: (128, "")})()'
assert_eq "$(pyq "JR._same_since($(printf '%s' "$STUBG" | sed 's/ABS/False/'), 'h', 't', 'src/e1/x.txt', '$TM/jobs/E1/', '$TM/jobs/E1/design.md')")" "False" "_same_since: 양쪽을 다 읽지 못하고 부재도 확인되지 않으면 다르다(낡음)"
assert_eq "$(pyq "JR._same_since($(printf '%s' "$STUBG" | sed 's/ABS/False/'), 'h', 't', '$TM/jobs/E1/design.md', '$TM/jobs/E1/', '$TM/jobs/E1/design.md')")" "False" "_same_since: 본문 파일도 양쪽을 읽지 못하고 부재가 확인되지 않으면 다르다"
assert_eq "$(pyq "JR._same_since($(printf '%s' "$STUBG" | sed 's/ABS/True/'), 'h', 't', 'src/e1/x.txt', '$TM/jobs/E1/', '$TM/jobs/E1/design.md')")" "True" "_same_since: 양성 대조 — 양쪽 다 부재가 확인되면 같다"
assert_eq "$(rcpt v/design-after "$LINE_GOOD" | cut -d'|' -f1,2)" "낡음|받은 뒤 바뀜: implement-plan-1-1.md — $TM/jobs/E1/design.md" "받음: design.md 변경 — 낡음"
plan_more() { printf '\n받은 뒤 계획에 더한 문단\n' >> "$W/$TM/jobs/E1/plan-1.md"; }
variant "$GOOD" plan-after plan_more || no "변이 브랜치 plan-after 를 만들지 못했다"
assert_eq "$(rcpt v/plan-after "$LINE_GOOD" | cut -d'|' -f1,2)" "낡음|받은 뒤 바뀜: implement-plan-1-1.md — $TM/jobs/E1/plan-1.md" "받음: 계획 파일 변경 — 낡음"
variant "$GOOD" intent-after decide E1 "- 결정 · 2026-11-21 · 「받은 뒤 결정 한 줄」" || no "변이 브랜치 intent-after 를 만들지 못했다"
variant v/intent-after review-after put "$TM/jobs/E1/results/review-1.md" "검수 결과" || no "변이 브랜치 review-after 를 만들지 못했다"
assert_eq "$(rcpt v/review-after "$LINE_GOOD")" "받음||implement-plan-1-1.md" "받음: INTENT.md · 결과 파일만 바뀌면 받음 그대로"
many() { local i; for i in 1 2 3 4 5 6 7; do put "src/e1/m$i.txt" "많이 $i" || return 1; done; }
variant "$GOOD" many-after many || no "변이 브랜치 many-after 를 만들지 못했다"
assert_eq "$(rcpt v/many-after "$LINE_GOOD" | cut -d'|' -f2)" "받은 뒤 바뀜: implement-plan-1-1.md — src/e1/m1.txt · src/e1/m2.txt · src/e1/m3.txt · src/e1/m4.txt · src/e1/m5.txt 외 2개" "받음: 바뀐 파일은 다섯까지 · 외 n개"
put src/e1/z.txt "기본 브랜치가 고친 고칠 자리" && g commit -qm "기본 브랜치에서 E1 자리" && g push -q origin main && g fetch -q origin
g checkout -q -b v/merged "$GOOD" && g merge -q --no-ff --no-edit main && g checkout -q main
assert_eq "$(rcpt v/merged "$LINE_GOOD")" "받음||implement-plan-1-1.md" "받음: 기본 브랜치를 합친 merge 뿐이면 받음 그대로(Review Focus 4)"
g checkout -q -b e2side main && put src/e1/q.txt "다른 에픽이 머지 전에 고친 자리" && g commit -qm "다른 에픽" && g checkout -q main
g checkout -q -b v/epic-merge "$GOOD" && g merge -q --no-ff --no-edit e2side && g checkout -q main
assert_eq "$(rcpt v/epic-merge "$LINE_GOOD" | cut -d'|' -f1,2)" "낡음|받은 뒤 바뀜: implement-plan-1-1.md — src/e1/q.txt" "받음: 기본 브랜치에 없는 다른 브랜치를 합친 변경은 받은 뒤 바뀜이다(Q6)"

finish
