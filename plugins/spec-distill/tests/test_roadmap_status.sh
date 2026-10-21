#!/usr/bin/env bash
# roadmap_status.py — 로드맵 · git 에서 에픽 단계 · 경고 · 정보를 계산한다(R0 AC1 · AC3 · AC5 · AC7).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_roadmap_status.sh
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
# origin 은 로컬 bare 레포다 — 머지 메시지 길은 origin 소유자가 필요하므로 `git -C <d> remote get-url origin` 만
# FAKE_ORIGIN_URL 로 답하는 git 을 PATH 앞에 둔다(그 밖의 git 은 그대로). FAKE_ORIGIN_URL 을 비우면 실제 URL 이 나온다.
mkdir -p "$T/fakebin-origin"
cat > "$T/fakebin-origin/git" <<SH
#!/bin/bash
if [ -n "\${FAKE_ORIGIN_URL:-}" ] && [ "\$1" = "-C" ] && [ "\$3" = "remote" ] && [ "\$4" = "get-url" ] && [ "\$5" = "origin" ]; then
  printf '%s\n' "\$FAKE_ORIGIN_URL"; exit 0
fi
exec "$(command -v git)" "\$@"
SH
chmod +x "$T/fakebin-origin/git"
export PATH="$T/fakebin-origin:$PATH" FAKE_ORIGIN_URL="https://github.com/o/r.git"
W="$T/work"
g() { git -C "$W" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false \
        -c init.defaultBranch=main "$@"; }
commit_file() {  # commit_file <경로> <내용> <메시지>
  mkdir -p "$(dirname "$W/$1")" && printf '%s\n' "$2" > "$W/$1" && g add -- "$1" && g commit -qm "$3"
}
pr_merge() {     # pr_merge <번호> <브랜치> — GitHub merge commit 모양
  g checkout -q main && g merge -q --no-ff "$2" -m "Merge pull request #$1 from o/$2"
}
spec_doc() {     # spec_doc <source_interview> <번호 대조 첫 칸>
  printf -- '---\nsource_interview: %s\n---\n\n# 설계\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| %s | 반영 | §1 |\n' "$1" "$2"
}
js() {           # js <json 파일> <파이썬 식 — r 이 보고서>. 식은 이 테스트가 쓴 고정 문자열뿐이다.
  python3 -c 'import json,sys; r=json.load(open(sys.argv[1],encoding="utf-8")); print(eval(sys.argv[2]))' "$1" "$2"
}
stage() { js "$1" "next(b['stage'] for b in r['blocks'] if b['id']=='$2')"; }
warns() { js "$1" "' | '.join(next(b['warnings'] for b in r['blocks'] if b['id']=='$2'))"; }
notes() { js "$1" "' | '.join(next(b['notes'] for b in r['blocks'] if b['id']=='$2'))"; }

# ── 픽스처: brief · audit · 묶음 · 로드맵 ─────────────────────────────────────
write_brief() {  # write_brief <디렉토리>
  mkdir -p "$1"
  cat > "$1/b.md" <<'MD'
---
type: interview-brief
user_sourced_items:
  - id: C1
    statement: "가"
  - id: D2
    statement: "나"
---

# brief

## 0. 한눈에

**결정 목록**

- OQ1 [열림] — 하나

## 1. Goal · Non-goal

- Goal: 목표 문장.
- Non-goal: 아닌 것.

## 2. 제약

- 🗣 confirmed **C1** — 가 ⟨S1⟩
- ☑ confirmed **D2** — 나 ⟨S2⟩

## 3. Open Questions

- OQ1: 하나

## 4. External Landscape

- 바깥 사례 «k1» — [취함] [→ OQ1]

## 5. 기각 · Blind Spots

- 기각 — 다른 길 — verdict: refined — ST1 — 부착 1/1
- 위험 — 숨은 가정: 가정 하나 — 근거 없음
- 위험 — 실패 양식: 실패 하나 — 근거 없음
- 위험 — 장치 | 장치 — RC1 (x.md) [RC1 → OQ1]

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > 처음 요청

## 7. Next Action

다음.
MD
  cat > "$1/b.audit.md" <<'MD'
# audit

## 6. 사용자 원문

- **S2** 🗣 발화 (round 0):
  > 둘째 말

## 7. 확산 원자료

- 없음
MD
}

bundle() {  # bundle <로드맵 디렉토리> <블록> <ids>
  printf -- '---\ntype: epic-bundle\nepic: %s\nroadmap: %s/roadmap.md\nsource_brief: docs/br/b.md\nids: [%s]\n---\n\n# %s\n' \
    "$2" "$1" "$3" "$2" > "$W/$1/$2.md"
}

block() {   # block <id> <브랜치> <의존> <경로 예약> [묶음 값]
  printf '### %s — 에픽 %s\n- 의도: %s 의 의도\n- 범위: 한다 %s / 안 한다 없음\n- 의존: %s\n- 브랜치: %s\n- 묶음: %s\n- 경로 예약: %s\n\n' \
    "$1" "$1" "$1" "$1" "$3" "$2" "${5:-$1.md}" "$4"
}

roadmap_head() {
  printf -- '---\ntype: roadmap\nsource_brief: docs/br/b.md\n---\n\n# 로드맵\n\n## 에픽\n\n'
}
roadmap_tail() {  # roadmap_tail <결정 기록 줄들>
  printf '## 지휘 절차\n\n1. fetch\n\n## 결정 기록\n\n쉬운 말 PR 은 이미 머지됐다 — 블록 없음.\n%s\n\n## 재분해 이력\n\n- 없음\n\n## 위험 번호표\n\n- K1 — 위험 — 숨은 가정: 가정 하나 — 근거 없음\n- K2 — 위험 — 실패 양식: 실패 하나 — 근거 없음\n' "$1"
}

# ── 픽스처: git 이력 ─────────────────────────────────────────────────────────
git init -q --bare -b main "$T/origin.git"
git clone -q "$T/origin.git" "$W" 2>/dev/null
commit_file README.txt "시작" "init"
g push -q origin main
g remote set-head origin main

# A1 — merge commit 으로 머지, 브랜치 남음 → 머지됨
g checkout -q -b feature/a1 main; commit_file src/a.txt a "a1"; g checkout -q main && g merge -q --no-ff feature/a1 -m "Merge branch 'feature/a1'"
# 동기화 머지: feature/sx 가 main 을 받아온 뒤 main 에 머지된다. U1 은 그 둘째 부모(그때의 main)에서 만든 빈 브랜치.
SYNC_PARENT="$(g rev-parse main)"
g checkout -q -b feature/sx main~1; commit_file src/sx.txt sx "sx"
g merge -q --no-ff main -m "Merge origin/main into feature/sx"
pr_merge 2 feature/sx
g branch -q feature/u1 "$SYNC_PARENT"
# B1 — 머지 뒤 브랜치 지움 → 머지 메시지로 머지됨
g checkout -q -b feature/b1 main; commit_file src/b.txt b "b1"; pr_merge 3 feature/b1; g branch -q -D feature/b1
# E1 의 이웃 — feature/e1-extra 만 머지되고 지워짐. E1 의 feature/e1 은 이름 앞부분만 같다.
g checkout -q -b feature/e1-extra main; commit_file src/e.txt e "e1x"; pr_merge 4 feature/e1-extra; g branch -q -D feature/e1-extra
# F1 — squash 머지(머지 커밋 없음) + 지움 → 결정 기록의 머지 기록으로만 머지됨
g checkout -q main; commit_file src/f.txt f "F1 squash"
# Y1 — 머지된 뒤 같은 브랜치에 커밋이 더 붙음 → 머지됨이 아니다
g checkout -q -b feature/y1 main; commit_file src/y.txt y1 "y1a"; pr_merge 5 feature/y1
g checkout -q feature/y1; commit_file src/y.txt y2 "y1b"
# Q1 — 머지 뒤 로컬 브랜치를 main 으로 앞당김(브랜치 끝 = 머지 커밋 자신) → 머지 메시지로 머지됨
g checkout -q -b feature/q1 main; commit_file src/q.txt q "q1"; pr_merge 6 feature/q1; g branch -q -f feature/q1 main
# G9 — main 이력의 머지 커밋인데 둘째 부모가 이미 첫째 부모 안에 있다(루트 커밋). 조상 아님 조건이 없으면 머지됨으로 읽힌다.
G9_ANC="$(g rev-list --max-parents=0 main)"
G9_SHA="$(g commit-tree 'main^{tree}' -p main -p "$G9_ANC" -m "Merge branch 'feature/g9'")"
g update-ref refs/heads/main "$G9_SHA"
g branch -q feature/g9 "$G9_ANC"
g checkout -q main
g push -q origin main

# 문서(brief · 묶음 · 로드맵)는 main 의 마지막 커밋으로 둔다
write_brief "$W/docs/br"
mkdir -p "$W/docs/rm"
for b in A1 B1 E1 F1 G1 G9 H1 I1 J1 W1 M1 T1 U1 Y1 Q1 Z1; do bundle docs/rm "$b" "C1, S1"; done
bundle docs/rm A1 "C1, D2, OQ1, RC1, ST1, «k1», K1, K2, S1, S2"
bundle docs/rm V1 "C1, D2, S1"
{ roadmap_head
  block A1 feature/a1 없음 "plugins/p/README.md, src/a.txt"
  block B1 feature/b1 없음 "plugins/p/README.md"
  block E1 feature/e1 없음 "docs/shared/"
  block F1 feature/f1 없음 없음
  block G1 feature/g1 없음 없음
  block G9 feature/g9 없음 없음
  block H1 feature/h1 없음 없음
  block I1 feature/i1 없음 "src/i.txt"
  block J1 feature/j1 W1 "src/j.txt, src/jw.txt, src/한 글.txt"
  block W1 feature/w1 없음 "docs/shared/x.md, src/jw.txt"
  block L1 feature/l1 없음 없음
  block M1 feature/m1 없음 없음
  block T1 feature/t1 A1 없음
  block U1 feature/u1 없음 없음
  block V1 feature/v1 없음 없음
  block Y1 feature/y1 없음 없음
  block Q1 feature/q1 없음 없음
  block Z1 feature/z1 W1 없음
  printf '### N1 — 묶음 없는 브랜치\n- 의도: n\n- 범위: n\n- 의존: 없음\n- 브랜치: feature/n1\n- 묶음: 없음\n- 경로 예약: 없음\n- spec: docs/superpowers/specs/n1-design.md\n- 발화: S1\n- 항목: C1\n\n'
  printf '### P1 — 결정 끝\n- 의도: p\n- 범위: p\n- 의존: 없음\n- 완료: 결정 기록\n- 묶음: 없음\n- 경로 예약: 없음\n- 발화: S2\n- 항목: D2\n\n'
  printf '### P2 — 결정 대기\n- 의도: p\n- 범위: p\n- 의존: W1\n- 완료: 결정 기록\n- 묶음: 없음\n- 경로 예약: 없음\n- 발화: S2\n- 항목: D2\n\n'
  printf '### P3 — 결정 기록 없음\n- 의도: p\n- 범위: p\n- 의존: 없음\n- 완료: 결정 기록\n- 묶음: 없음\n- 경로 예약: 없음\n- 발화: S2\n- 항목: D2\n\n'
  roadmap_tail "$(printf -- '- F1 · 머지 · 2026-10-11 · 「squash 로 머지했다」\n- P1 · 결정 · 2026-10-11 · 「이걸로 정한다」')"
} > "$W/docs/rm/roadmap.md"
g add -- docs && g commit -qm "docs: 로드맵" && g push -q origin main

# T1 — main 에서 막 만든 빈 브랜치(머지됨이 아니다 — D1.1)
g branch -q feature/t1 main
# G1 — 로컬에만, spec 있음 → 설계 중
g checkout -q -b feature/g1 main
spec_doc docs/rm/G1.md "C1 · S1" > "$W/g1.md"; mkdir -p "$W/docs/superpowers/specs"; mv "$W/g1.md" "$W/docs/superpowers/specs/g1-design.md"
g add -- docs && g commit -qm "g1 spec"
# H1 — 원격에만, spec + 계획 → 계획
g checkout -q -b feature/h1 main
mkdir -p "$W/docs/superpowers/specs" "$W/docs/superpowers/plans"
spec_doc docs/rm/H1.md "C1, S1" > "$W/docs/superpowers/specs/h1-design.md"
printf '# 계획\n\n**Spec:** `docs/superpowers/specs/h1-design.md` (§1 · §2) — 참고 `docs/other.md`\n' > "$W/docs/superpowers/plans/h1.md"
g add -- docs && g commit -qm "h1" && g push -q origin feature/h1 && g checkout -q main && g branch -q -D feature/h1
# I1 — J1 만 예약한 src/j.txt 를 바꿈 → 경로 예약 위반(정보)
g checkout -q -b feature/i1 main; commit_file src/j.txt i "i1 touches j"; commit_file "src/한 글.txt" i "i1 touches 한글 경로"
# J1 — 의존 W1(준비) 인데 브랜치가 있다 → 설계 중 + 의존 미머지 경고
g checkout -q -b feature/j1 main; commit_file src/j.txt j "j1"
# M1 — spec 둘이 같은 묶음을 가리킨다 → spec 여럿
g checkout -q -b feature/m1 main; mkdir -p "$W/docs/superpowers/specs"
spec_doc docs/rm/M1.md "C1 · S1" > "$W/docs/superpowers/specs/m1-a-design.md"
spec_doc "\"docs/rm/M1.md\"" "C1 · S1" > "$W/docs/superpowers/specs/m1-b-design.md"
g add -- docs && g commit -qm "m1"
# N1 — 묶음 없는 브랜치 블록: spec: 줄의 spec 을 가리키는 계획 → 계획
g checkout -q -b feature/n1 main; mkdir -p "$W/docs/superpowers/specs" "$W/docs/superpowers/plans"
printf '# n1\n' > "$W/docs/superpowers/specs/n1-design.md"
printf '**Spec:** `docs/superpowers/specs/n1-design.md`\n' > "$W/docs/superpowers/plans/n1.md"
g add -- docs && g commit -qm "n1"
# V1 — spec 의 번호 대조가 D2 를 빠뜨림 → 생략 경고
g checkout -q -b feature/v1 main; mkdir -p "$W/docs/superpowers/specs"
spec_doc docs/rm/V1.md "C1" > "$W/docs/superpowers/specs/v1-design.md"
printf '| S1 | 기각 | 범위 밖 |\n' >> "$W/docs/superpowers/specs/v1-design.md"
g add -- docs && g commit -qm "v1"
g checkout -q main
g fetch -q origin

# ── 1. origin/main 사본으로 계산 ─────────────────────────────────────────────
OUT="$T/main.json"
(cd "$W" && python3 "$RS" --json docs/rm/roadmap.md > "$OUT"); rc=$?
assert_eq "$rc" "1" "경고가 있는 로드맵 → rc 1"
assert_eq "$(js "$OUT" "r['source']")" "origin/main" "기본 사본은 origin/main"
assert_eq "$(js "$OUT" "r['format_errors']")" "[]" "형식 깨짐 없음"
assert_eq "$(stage "$OUT" A1)" "머지됨" "A1: 머지 커밋의 둘째 부모 = 브랜치 끝 → 머지됨"
assert_eq "$(stage "$OUT" B1)" "머지됨" "B1: 지운 브랜치 · 머지 메시지 정확히 같음 → 머지됨"
assert_eq "$(stage "$OUT" E1)" "준비" "E1: 이름 앞부분만 같은 머지 메시지 → 머지됨 아님(준비)"
assert_eq "$(stage "$OUT" F1)" "머지됨" "F1: 결정 기록의 머지 기록(squash 대체) → 머지됨"
assert_contains "$(js "$OUT" "next(b['reason'] for b in r['blocks'] if b['id']=='F1')")" "결정 기록의 머지 기록" "F1 근거가 결정 기록"
assert_eq "$(stage "$OUT" T1)" "설계 중" "T1: 커밋 없는 새 브랜치는 머지됨이 아니다(D1.1)"
assert_eq "$(stage "$OUT" U1)" "설계 중" "U1: 동기화 머지의 둘째 부모에서 만든 빈 브랜치는 머지됨이 아니다(D4.24)"
assert_eq "$(stage "$OUT" Y1)" "설계 중" "Y1: 머지 뒤 커밋이 더 붙은 브랜치는 머지됨이 아니다"
assert_eq "$(stage "$OUT" Q1)" "머지됨" "Q1: 머지 뒤 main 으로 앞당긴 로컬 브랜치 → 머지 메시지로 머지됨"
assert_eq "$(stage "$OUT" G9)" "설계 중" "G9: 둘째 부모가 이미 첫째 부모 안에 있는 머지 커밋은 머지됨이 아니다(조상 아님 조건)"
assert_eq "$(stage "$OUT" G1)" "설계 중" "G1: 로컬에만 있는 브랜치 · spec 있음 → 설계 중"
assert_eq "$(js "$OUT" "next(b['reason'] for b in r['blocks'] if b['id']=='G1')")" "spec 있음" "G1 근거 「spec 있음」"
assert_eq "$(stage "$OUT" H1)" "계획" "H1: 원격에만 있는 브랜치 · **Spec:** 뒤에 설명과 둘째 백틱 → 계획"
assert_eq "$(stage "$OUT" N1)" "계획" "N1: 묶음 없는 블록의 spec: 으로 계획"
assert_eq "$(stage "$OUT" W1)" "준비" "W1: 브랜치 없음 · 의존 없음 → 준비"
assert_eq "$(stage "$OUT" L1)" "준비" "L1: 브랜치 없음 → 준비"
assert_eq "$(stage "$OUT" P1)" "끝남" "P1: 결정 기록 있음 → 끝남"
assert_eq "$(stage "$OUT" P2)" "대기" "P2: 의존 W1 이 끝나지 않음 → 대기"
assert_eq "$(stage "$OUT" Z1)" "대기" "Z1: 브랜치 없음 · 의존 미완료 → 대기"
assert_eq "$(stage "$OUT" P3)" "준비" "P3: 결정 블록 · 결정 기록 없음 · 의존 없음 → 준비"
assert_eq "$(stage "$OUT" J1)" "설계 중" "J1: 의존 미머지여도 단계는 그대로 계산"
assert_contains "$(warns "$OUT" J1)" "의존 미머지 상태에서 진행 중: W1" "J1: 의존 미머지 진행 경고"
assert_contains "$(notes "$OUT" I1)" "경로 예약 위반: src/j.txt 은 J1 만 예약했다" "I1: 경로 예약 위반은 정보(notes)로 낸다"
assert_eq "$(warns "$OUT" I1)" "" "I1: 경로 예약 위반은 경고가 아니다(경고 0)"
assert_not_contains "$(notes "$OUT" J1)" "경로 예약 위반" "J1: 자기가 예약한 파일은 위반이 아니다"
assert_contains "$(notes "$OUT" I1)" "경로 예약 위반: src/한 글.txt 은 J1 만 예약했다" "I1: 한글 · 공백 경로도 이스케이프 없이 대조한다"
assert_grep "$(js "$OUT" "r['fetched_at']")" "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}$" "origin/main 받은 시각을 낸다(FETCH_HEAD)"
lc="$(cd "$W" && LC_ALL=C LANG=C PYTHONIOENCODING= python3 "$RS" docs/rm/roadmap.md 2>&1)"; rc=$?
assert_eq "$rc" "1" "비UTF-8 로캘(LC_ALL=C)에서도 같은 rc"
assert_contains "$lc" "로드맵 상태 — " "비UTF-8 로캘에서도 한국어 출력이 깨지지 않는다"
assert_file_grep "$RS" 'GIT_NO_LAZY_FETCH="1"' "partial clone 에서 빠진 객체를 받으러 나가지 않게 한다"
assert_contains "$(warns "$OUT" L1)" "묶음 없음: docs/rm/L1.md" "L1: 묶음 없음"
assert_contains "$(warns "$OUT" M1)" "spec 여럿" "M1: spec 여럿(따옴표 친 source_interview 포함)"
assert_contains "$(warns "$OUT" V1)" "생략: docs/superpowers/specs/v1-design.md 이 번호 1개를 빠뜨렸다 — D2" "V1: 생략 경고"
assert_contains "$(warns "$OUT" V1)" "얕은 답 1개: docs/superpowers/specs/v1-design.md — C1(" "V1: 얕은 답(R3)이 경고 줄로 나온다 — 반영 자리 §1 이 설계문서에 없다"
assert_not_contains "$(warns "$OUT" V1)" "받드는 에픽 없는 발화" "V1: 기각한 S1 을 다른 에픽(N1 등)이 받들면 경고가 없다 — 로드맵을 main 트리에서 읽었다는 음의 짝"
uk="$(python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import roadmap_status as rs; print(rs.coverage_warnings({"unknown": ["S1 — 사유"]}, "x.md"))' "$S")"
assert_eq "$uk" "['번호 대조 셀 수 없음 1개: x.md — S1 — 사유']" "셀 수 없음 경고 줄의 모양"
uw="$(python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import roadmap_status as rs; print(rs.coverage_warnings({"shallow": [], "unserved": ["S7", "S9"]}, "x.md"))' "$S")"
assert_eq "$uw" "['받드는 에픽 없는 발화 2개: x.md — S7 · S9']" "받드는 에픽 없는 발화 경고 줄의 모양"
assert_eq "$(js "$OUT" "r['unassigned']")" "[]" "미배정 번호 0"
assert_eq "$(js "$OUT" "r['orphans']")" "[]" "고아 발화 0"
assert_eq "$(js "$OUT" "[o['blocks'] for o in r['overlaps']]")" "[['E1', 'W1']]" "겹침(정보): E1 ↔ W1 만(README 는 빼고, J1→W1 은 의존이 있어 뺀다)"
assert_eq "$(js "$OUT" "next(b['task_status'] for b in r['blocks'] if b['id']=='H1')")" "in_progress" "작업 목록 대응: 계획 → in_progress"
txt="$(cd "$W" && python3 "$RS" docs/rm/roadmap.md)"
assert_grep "$txt" "^로드맵 상태 — 블록 22개 · " "사람용 글 첫 줄이 상태"
assert_contains "$txt" "머지됨은 PR 상태로 판정한다(지휘자가 채운 PR 캐시) — 캐시가 없으면 머지 커밋과 이 레포 소유자의 머지 메시지로 알아보고 「PR 상태 미확인」을 보인다. 결정 기록의 머지 줄은 PR 없이 로컬에서 머지한 경우에만 쓴다" "판정 공시 줄(양의 짝)"
assert_not_contains "$txt" "merge commit 방식에서만" "옛 공시 「merge commit 방식에서만」 이 없다"
assert_not_contains "$txt" "squash · rebase 로 머지했거나" "옛 공시 「squash · rebase 로 머지했거나 … 머지 줄을 적는다」 가 없다"
SDR="$ROOT/plugins/spec-distill"
assert_contains "$(cat "$SDR/README.md")" "캐시가 없으면 머지 커밋과 이 레포 소유자의 머지 메시지(\`Merge pull request #<n> from <owner>/<브랜치>\`)로 알아보고 「PR 상태 미확인」을 보입니다. 결정 기록의 머지 줄은 PR 없이 로컬에서 머지한 경우에만 씁니다." "README 상태 계산 줄: 새 규칙(양의 짝)"
assert_not_contains "$(cat "$SDR/README.md")" "squash · rebase 로 머지했거나" "README: 옛 「squash · rebase 로 머지했거나 … 머지 줄을 적어야」 가 없다"
assert_not_contains "$(cat "$SDR/README.md")" "merge commit 방식에서만" "README: 옛 「merge commit 방식에서만」 이 없다"
assert_contains "$(cat "$SDR/templates/roadmap-template.md")" "「머지」 줄은 PR 없이 로컬에서 머지한 에픽에만 적는다" "템플릿 머지 줄 안내: 새 규칙(양의 짝)"
assert_not_contains "$(cat "$SDR/templates/roadmap-template.md")" "머지 커밋이 없는 에픽은 「머지」 줄로 적는다" "템플릿: 옛 「squash · rebase 로 머지해 … 「머지」 줄로 적는다」 가 없다"
assert_contains "$(notes "$OUT" A1)" "PR 상태 미확인 — 지휘자를 돌려라(feature/a1)" "캐시 없음: 블록마다 「PR 상태 미확인」 정보 줄"
assert_not_contains "$(warns "$OUT" A1)" "PR 상태 미확인" "캐시 없음: 「PR 상태 미확인」 은 경고가 아니다"
assert_contains "$txt" "경로 예약 겹침과 다른 에픽이 예약한 파일의 편집은 경고가 아니라 정보다" "공시: 겹침 · 위반은 정보"
assert_contains "$txt" "경로 예약 겹침(정보): 1개" "사람용 글: 겹침은 정보 머리 아래"
assert_contains "$txt" "    정보: 경로 예약 위반: src/j.txt 은 J1 만 예약했다" "사람용 글: 위반은 「정보:」 줄"

# ── 1b. 정보만 있는 로드맵은 rc 0 — 같은 로드맵에 진짜 경고 하나를 더하면 rc 1(양성 짝) ──
mkdir -p "$W/docs/rm5" "$W/docs/rm6"
for d in docs/rm5 docs/rm6; do
  bundle "$d" I1 "C1, D2, OQ1, RC1, ST1, «k1», K1, K2, S1, S2"
  bundle "$d" J5 "C1, S1"
  bundle "$d" W5 "C1, S1"
done
{ roadmap_head
  block I1 feature/i1 없음 "src/i.txt"
  block J5 feature/j5 없음 "src/j.txt, src/한 글.txt, docs/shared/"
  block W5 feature/w5 없음 "docs/shared/x.md"
  roadmap_tail ""
} > "$W/docs/rm5/roadmap.md"
{ sed '/^## 지휘 절차$/,$d' "$W/docs/rm5/roadmap.md"
  block L5 feature/l5 없음 없음
  sed -n '/^## 지휘 절차$/,$p' "$W/docs/rm5/roadmap.md"
} > "$W/docs/rm6/roadmap.md"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm5/roadmap.md > "$T/info.json"); rc=$?
assert_eq "$rc" "0" "정보(겹침 · 위반)만 있는 로드맵 → rc 0 — 정보는 종료 코드를 바꾸지 않는다"
assert_eq "$(js "$T/info.json" "[o['blocks'] for o in r['overlaps']]")" "[['J5', 'W5']]" "정보 로드맵: 겹침 J5 ↔ W5 가 있다"
assert_contains "$(notes "$T/info.json" I1)" "경로 예약 위반: src/j.txt 은 J5 만 예약했다" "정보 로드맵: I1 의 위반 정보가 있다"
assert_eq "$(js "$T/info.json" "sum(len(b['warnings']) for b in r['blocks'])")" "0" "정보 로드맵: 경고 0개"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm6/roadmap.md > "$T/info-warn.json"); rc=$?
assert_eq "$rc" "1" "양성 짝: 같은 로드맵에 묶음 없음 경고 하나를 더하면 rc 1"
assert_contains "$(warns "$T/info-warn.json" L5)" "묶음 없음: docs/rm6/L5.md" "양성 짝: 더한 경고는 L5 의 묶음 없음"
info_txt="$(cd "$W" && python3 "$RS" --roadmap-file docs/rm5/roadmap.md)"
assert_grep "$info_txt" "^로드맵 상태 — 블록 3개 · 경고 0개 · 정보 6개 · 검사 불가 0개 " "정보 로드맵 머리 줄: 정보 6개 = I1 위반 2 + 겹침 1 + PR 상태 미확인 3(모두 센다)"

# ── 2. --roadmap-file(작업 트리) 사본 · 번호 대조 검사 불가 · 미배정 · 고아 ─────────
mkdir -p "$W/docs/rm2"
bundle docs/rm2 X1 "C1, S1"
bundle docs/rm2 A1 "C1, OQ1, RC1, ST1, «k1», K1, K2, S1, C99"
{ roadmap_head; block A1 feature/a1 없음 없음; block X1 feature/x1 없음 없음; roadmap_tail ""; } > "$W/docs/rm2/roadmap.md"
g checkout -q -b feature/x1 main; mkdir -p "$W/docs/superpowers/specs"
printf -- '---\nsource_interview: docs/rm2/X1.md\n---\n\n# 번호 대조 절이 없다\n' > "$W/docs/superpowers/specs/x1-design.md"
g add -- docs/superpowers && g commit -qm "x1"; g checkout -q main
OUT2="$T/wt.json"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm2/roadmap.md > "$OUT2"); rc=$?
assert_eq "$rc" "3" "번호 대조 검사 불가가 있으면 rc 3"
assert_eq "$(js "$OUT2" "r['source']")" "작업 트리" "--roadmap-file 은 작업 트리 사본"
assert_eq "$(js "$OUT2" "[b['id'] for b in r['blocks']]")" "['A1', 'X1']" "작업 트리 로드맵의 블록을 읽었다(origin/main 사본과 다름)"
assert_contains "$(warns "$OUT2" X1)" "번호 대조 검사 불가(spec 에 \`## 번호 대조\` 절이 없다)" "X1: 검사 불가 경고"
assert_eq "$(js "$OUT2" "r['unassigned']")" "['D2']" "미배정 번호 D2"
assert_eq "$(js "$OUT2" "r['orphans']")" "['S2']" "고아 발화 S2"
assert_eq "$(js "$OUT2" "r['unknown_ids']")" "['C99']" "brief 에 없는 번호 C99"

# ── 3. 형식 깨짐(rc 3) ───────────────────────────────────────────────────────
sed '/^- 의도: A1 의 의도$/d' "$W/docs/rm2/roadmap.md" > "$W/docs/rm2/broken.md"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm2/broken.md > "$T/broken.json"); rc=$?
assert_eq "$rc" "3" "머리말 빠진 블록 → rc 3"
assert_contains "$(js "$T/broken.json" "r['format_errors']")" "A1: 머리말 의도 가 없다" "형식 깨짐 사유"
mkdir -p "$W/docs/rm3"
for f in A1 X1; do sed 's|docs/rm2/|docs/rm3/|' "$W/docs/rm2/$f.md" > "$W/docs/rm3/$f.md"; done
sed 's/^- K2 — .*/- K2 — 다른 문장/' "$W/docs/rm2/roadmap.md" > "$W/docs/rm3/roadmap.md"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm3/roadmap.md > "$T/k.json"); rc=$?
assert_eq "$rc" "3" "위험 번호표가 brief 와 다르면 rc 3"
assert_contains "$(js "$T/k.json" "r['format_errors']")" "위험 번호표가 brief §5 위험 줄과 다르다: K2" "위험 번호표 대조"
mkdir -p "$W/docs/rm4"
{ roadmap_head; block A1 feature/a1 없음 없음; roadmap_tail ""; } > "$W/docs/rm4/roadmap.md"
printf '\377\376\n' > "$W/docs/rm4/A1.md"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm4/roadmap.md > "$T/unread.json"); rc=$?
assert_eq "$rc" "3" "읽을 수 없는 묶음(비UTF-8) → rc 3"
assert_contains "$(js "$T/unread.json" "r['format_errors']")" "A1 묶음을 읽지 못했다: docs/rm4/A1.md" "읽기 실패는 「묶음 없음」이 아니라 읽지 못했다고 보고한다"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm2/없음.md > "$T/none.json"); rc=$?
assert_eq "$rc" "3" "로드맵 없음 → rc 3"
(cd "$W" && python3 "$RS" >/dev/null 2>&1); rc=$?
assert_eq "$rc" "2" "인자 없음 → rc 2"

# ── 4. origin/HEAD 없음(기본 브랜치를 모름) → 모든 블록 알 수 없음 · rc 3 ─────────────────────────
git clone -q "$T/origin.git" "$T/noorigin" 2>/dev/null
git -C "$T/noorigin" remote remove origin
(cd "$T/noorigin" && python3 "$RS" --json --roadmap-file docs/rm/roadmap.md > "$T/no.json"); rc=$?
assert_eq "$rc" "3" "origin/HEAD 없음 → rc 3"
assert_eq "$(js "$T/no.json" "sorted({b['stage'] for b in r['blocks']})")" "['알 수 없음']" "모든 블록 알 수 없음"
(cd "$T/noorigin" && python3 "$RS" --json docs/rm/roadmap.md > "$T/no2.json"); rc=$?
assert_eq "$rc" "3" "기본 브랜치 사본 모드에서 origin/HEAD 없음 → rc 3"

# ── 4b. git 읽기 실패 · 내부 오류 → 검사 불가(3) — 빈 결과로 이상 없음을 내지 않는다(N3) ──
REAL_GIT="$(command -v git)"
mkdir -p "$T/fakebin-grep" "$T/fakebin-diff"
cat > "$T/fakebin-grep/git" <<SH
#!/bin/bash
for a in "\$@"; do if [ "\$a" = grep ]; then echo "error: unable to read deadbeef" >&2; exit 1; fi; done
exec "$REAL_GIT" "\$@"
SH
cat > "$T/fakebin-diff/git" <<SH
#!/bin/bash
for a in "\$@"; do if [ "\$a" = diff ]; then echo "error: unable to read deadbeef" >&2; exit 1; fi; done
exec "$REAL_GIT" "\$@"
SH
chmod +x "$T/fakebin-grep/git" "$T/fakebin-diff/git"
(cd "$W" && PATH="$T/fakebin-grep:$PATH" python3 "$RS" --json docs/rm/roadmap.md > "$T/fg.json"); rc=$?
assert_eq "$rc" "3" "git grep 실패 → rc 3(빈 결과로 이상 없음을 내지 않는다)"
assert_contains "$(js "$T/fg.json" "r['unknown_reasons']")" "git grep 실패" "git grep 실패가 검사 불가로 올라왔다"
(cd "$W" && PATH="$T/fakebin-diff:$PATH" python3 "$RS" --json docs/rm/roadmap.md > "$T/fd.json"); rc=$?
assert_eq "$rc" "3" "git diff 실패 → rc 3"
assert_contains "$(js "$T/fd.json" "r['unknown_reasons']")" "git diff 실패" "git diff 실패가 검사 불가로 올라왔다"
# 로드맵 blob 을 첫 읽기 뒤로 못 읽는 git(얕은 클론 · partial clone 흉내) — 「경고 없음」이 아니라 셀 수 없음 경고 줄이 나와야 한다
mkdir -p "$T/fakebin-blob"
cat > "$T/fakebin-blob/git" <<SH
#!/bin/bash
case "\$*" in
  *"cat-file blob "*":docs/rm/roadmap.md"*)
    if [ -e "$T/blob-first" ]; then echo "fatal: unable to read" >&2; exit 128; fi
    : > "$T/blob-first" ;;
esac
exec "$REAL_GIT" "\$@"
SH
chmod +x "$T/fakebin-blob/git"; rm -f "$T/blob-first"
(cd "$W" && PATH="$T/fakebin-blob:$PATH" python3 "$RS" --json docs/rm/roadmap.md > "$T/fb.json")
assert_contains "$(warns "$T/fb.json" V1)" "번호 대조 셀 수 없음 1개: docs/superpowers/specs/v1-design.md — S1 — 로드맵을 못 읽었다: docs/rm/roadmap.md" "V1: 로드맵 blob 을 못 읽으면 셀 수 없음 경고 줄이 나온다(양성 짝)"
assert_not_contains "$(warns "$OUT" V1)" "번호 대조 셀 수 없음" "V1: 읽히는 정상 실행에는 그 줄이 없다"
PY="$(command -v python3)"
(cd "$W" && PATH=/nonexistent-dir "$PY" "$RS" --json docs/rm/roadmap.md > "$T/crash.json"); rc=$?
assert_eq "$rc" "3" "내부 오류(git 을 실행하지 못함) → rc 3"
assert_contains "$(js "$T/crash.json" "r['unknown_reasons']")" "내부 오류" "내부 오류가 검사 불가로 올라왔다"
assert_eq "$(js "$T/crash.json" "r['handoffs']")" "None" "내부 오류 보고서에도 handoffs 키가 있다(계산 못 함 = None)"

# ── 5. 읽기 전용(AC7) — 정적 검사 + 실행 전후 비교, 각각 양성 대조 ──────────────
static_check() {  # static_check <파일...> — 쓰기 · 네트워크 · 허용 밖 git · 이름 import 를 찾으면 줄을 낸다. 끝에 CHECKED n.
  python3 - "$@" <<'PY'
import ast, os, sys
WRITE_ATTRS = {"write_text", "write_bytes", "unlink", "rmdir", "mkdir", "rename", "replace",
               "touch", "chmod", "remove", "makedirs", "rmtree", "symlink_to", "system", "popen"}
NET_MODS = {"socket", "urllib", "http", "requests", "ftplib", "smtplib", "shutil"}
READ_GIT = {"show", "rev-parse", "log", "diff", "merge-base", "cat-file", "grep", "ls-tree", "config"}  # config 는 --get 꼴만(아래)
LOCAL = set()
if os.environ.get("LOCAL_DIR"):
    LOCAL = {f[:-3] for f in os.listdir(os.environ["LOCAL_DIR"]) if f.endswith(".py")}
ARGS = {os.path.basename(a)[:-3] for a in sys.argv[1:]}
# 상태 계산이 잠긴 파일 밖에서 이름으로만 가져오는 읽기 함수 — PR 캐시 읽기 · origin 소유자 읽기
READERS = {"conductor_state": {"MachineError", "machine_path", "parse_machine"},
           "gh_repo": {"GhStop", "origin_slug"},
           "state_path": {"state_root_for_common"}}


def is_write_call(node):
    f = node.func
    name = getattr(f, "attr", getattr(f, "id", ""))
    if name in WRITE_ATTRS:
        return name
    if name == "open":
        pos = (node.args[0] if node.args else None) if isinstance(f, ast.Attribute) else (
            node.args[1] if len(node.args) > 1 else None)
        mode = pos.value if isinstance(pos, ast.Constant) else ""
        for kw in node.keywords:
            if kw.arg == "mode" and isinstance(kw.value, ast.Constant):
                mode = kw.value.value
        if set(str(mode)) & set("wax+"):
            return "open(%s)" % mode
    if name in ("run", "Popen", "call", "check_output", "check_call") and getattr(getattr(f, "value", None), "id", "") == "subprocess":
        first = node.args[0] if node.args else None
        head = first.elts[0] if isinstance(first, ast.List) and first.elts else None
        if not (isinstance(head, ast.Constant) and head.value == "git"):
            return "git 이 아닌 subprocess"
    return None


def reader_writes(mod, names):
    """mod 의 names 함수와 그 함수가 부르는 같은 모듈 함수(재귀)에서 쓰기 호출을 찾는다."""
    tree = ast.parse(open(os.path.join(os.environ["LOCAL_DIR"], mod + ".py"), encoding="utf-8").read())
    funcs = {n.name: n for n in tree.body if isinstance(n, ast.FunctionDef)}
    todo, seen, out = [n for n in names if n in funcs], set(), []
    while todo:
        name = todo.pop()
        if name in seen:
            continue
        seen.add(name)
        for node in ast.walk(funcs[name]):
            if isinstance(node, ast.Call):
                what = is_write_call(node)
                if what:
                    out.append("읽기 함수 %s.%s 에 쓰기 호출 %s(%d줄)" % (mod, name, what, node.lineno))
                if isinstance(node.func, ast.Name) and node.func.id in funcs:
                    todo.append(node.func.id)
    return out


count = 0
for path in sys.argv[1:]:
    count += 1
    tree = ast.parse(open(path, encoding="utf-8").read())
    allowed, shape_ok = None, True
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign) and any(getattr(t, "id", "") == "GIT_ALLOWED" for t in node.targets):
            v = node.value
            lit = v.args[0] if isinstance(v, ast.Call) and getattr(v.func, "id", "") == "frozenset" and v.args else None
            if isinstance(lit, (ast.Set, ast.List)) and all(isinstance(e, ast.Constant) and isinstance(e.value, str) for e in lit.elts):
                allowed = {e.value for e in lit.elts}
            else:
                shape_ok = False
    uses_subprocess = any(isinstance(n, ast.Import) and any(a.name == "subprocess" for a in n.names)
                          for n in ast.walk(tree))
    if not shape_ok:
        print("%s: GIT_ALLOWED 모양이 frozenset({...}) 가 아니다" % path)
    elif uses_subprocess and (allowed is None or not allowed <= READ_GIT):
        print("%s: GIT_ALLOWED 가 없거나 읽기 명령 밖을 담는다: %r" % (path, allowed))
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom) and (node.module or "").split(".")[0] == "subprocess":
            print("%s:%d: subprocess 를 이름으로 import" % (path, node.lineno))
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            mods = [a.name for a in node.names] if isinstance(node, ast.Import) else [node.module or ""]
            for mod in mods:
                if mod.split(".")[0] in NET_MODS:
                    print("%s:%d: 네트워크 · 파일 조작 모듈 %s" % (path, node.lineno, mod))
                if mod.split(".")[0] in LOCAL and mod.split(".")[0] not in ARGS:
                    names = {a.name for a in node.names} if isinstance(node, ast.ImportFrom) else None
                    if (os.path.basename(path) == "roadmap_status.py" and mod in READERS and names is not None
                            and names <= READERS[mod]):
                        for line in reader_writes(mod, names):   # 이름으로 허용한 읽기 함수 — 그 몸과 부르는 같은 모듈 함수에 쓰기가 없다
                            print("%s:%d: %s" % (path, node.lineno, line))
                    else:
                        print("%s:%d: 잠긴 파일 밖 로컬 모듈 import %s" % (path, node.lineno, mod))
        if isinstance(node, ast.Call):
            f = node.func
            name = getattr(f, "attr", getattr(f, "id", ""))
            pos = node.args[0].elts if node.args and isinstance(node.args[0], ast.List) else list(node.args)
            for i, arg in enumerate(pos):
                if isinstance(arg, ast.Constant) and arg.value == "config":
                    nxt = pos[i + 1] if i + 1 < len(pos) else None
                    if not (isinstance(nxt, ast.Constant) and nxt.value == "--get"):
                        print("%s:%d: git config 를 --get 꼴 밖으로 부른다" % (path, node.lineno))
            if name in WRITE_ATTRS:
                print("%s:%d: 쓰기 호출 %s" % (path, node.lineno, name))
            if name == "open":
                if isinstance(f, ast.Attribute):
                    pos = node.args[0] if node.args else None      # x.open(mode, ...)
                else:
                    pos = node.args[1] if len(node.args) > 1 else None  # open(path, mode, ...)
                mode = pos.value if isinstance(pos, ast.Constant) else ""
                for kw in node.keywords:
                    if kw.arg == "mode" and isinstance(kw.value, ast.Constant):
                        mode = kw.value.value
                if set(str(mode)) & set("wax+"):
                    print("%s:%d: 쓰기 모드 open" % (path, node.lineno))
            if name in ("run", "Popen", "call", "check_output", "check_call") and getattr(getattr(f, "value", None), "id", "") == "subprocess":
                first = node.args[0] if node.args else None
                head = first.elts[0] if isinstance(first, ast.List) and first.elts else None
                if not (isinstance(head, ast.Constant) and head.value == "git"):
                    print("%s:%d: git 이 아닌 subprocess" % (path, node.lineno))
print("CHECKED %d" % count)
PY
}
out="$(LOCAL_DIR="$S" static_check "$RS" "$S/check_bundle_coverage.py" "$S/roadmap_model.py" "$S/spec_review_bundle.py" "$S/repo_defaults.py" "$S/section6.py" "$S/brief_body.py")"; rc=$?
assert_eq "$rc" "0" "정적 검사기가 죽지 않았다(rc 0)"
assert_eq "$(printf '%s\n' "$out" | grep -v '^CHECKED ')" "" "정적: 일곱 스크립트에 쓰기 · 네트워크 · git 밖 subprocess · 허용 밖 git · 이름 import · 잠긴 파일 밖 로컬 import 가 없다"
assert_eq "$(printf '%s\n' "$out" | grep '^CHECKED ')" "CHECKED 7" "정적 검사가 일곱 스크립트를 셌다"
sed 's/GIT_ALLOWED = frozenset({"show",/GIT_ALLOWED = frozenset({"fetch", "show",/' "$RS" > "$T/mut_fetch.py"
assert_contains "$(static_check "$T/mut_fetch.py")" "GIT_ALLOWED" "양성 대조: fetch 를 허용 목록에 넣으면 정적 검사가 잡는다"
printf 'from pathlib import Path\nPath("x").write_text("y", encoding="utf-8")\nimport urllib.request\n' > "$T/mut_write.py"
out="$(static_check "$T/mut_write.py")"
assert_contains "$out" "쓰기 호출 write_text" "양성 대조: write_text 를 잡는다"
assert_contains "$out" "네트워크 · 파일 조작 모듈 urllib.request" "양성 대조: urllib 을 잡는다"
printf 'import subprocess\nGIT_ALLOWED = {"show", "fetch"}\n' > "$T/ctl_set.py"
assert_contains "$(static_check "$T/ctl_set.py")" "GIT_ALLOWED 모양이 frozenset({...}) 가 아니다" "양성 대조: 집합 리터럴 GIT_ALLOWED 를 잡는다"
printf 'open("x", "w", encoding="utf-8")\n' > "$T/ctl_open.py"
assert_contains "$(static_check "$T/ctl_open.py")" "쓰기 모드 open" "양성 대조: 내장 open 의 쓰기 모드를 잡는다"
printf 'from pathlib import Path\nPath("x").open("w", encoding="utf-8")\n' > "$T/ctl_popen.py"
assert_contains "$(static_check "$T/ctl_popen.py")" "쓰기 모드 open" "양성 대조: Path.open 의 쓰기 모드를 잡는다"
printf 'import subprocess\nsubprocess.run(["ls"])\n' > "$T/ctl_run.py"
assert_contains "$(static_check "$T/ctl_run.py")" "git 이 아닌 subprocess" "양성 대조: git 밖 subprocess.run 을 잡는다"
printf 'import conductor_state\n' > "$T/ctl_local.py"
assert_contains "$(LOCAL_DIR="$S" static_check "$T/ctl_local.py")" "잠긴 파일 밖 로컬 모듈 import conductor_state" "양성 대조: 잠긴 파일 밖 로컬 모듈 import 를 잡는다"
# 상태 계산은 잠긴 파일 밖에서 읽기 함수만 이름으로 가져온다(PR 캐시 · origin 소유자) — 허용 밖 이름 · 모듈째 import · 다른 파일은 잡는다
mkdir -p "$T/ctlrs" "$T/ctlmods"
assert_contains "$(cat "$RS")" "from conductor_state import MachineError, machine_path, parse_machine" "양의 짝: 상태 계산이 PR 캐시 읽기 함수를 이름으로 가져온다"
assert_contains "$(cat "$RS")" "from gh_repo import GhStop, origin_slug" "양의 짝: 상태 계산이 origin 소유자 읽기 함수를 이름으로 가져온다"
printf 'from conductor_state import parse_machine, save\n' > "$T/ctlrs/roadmap_status.py"
assert_contains "$(LOCAL_DIR="$S" static_check "$T/ctlrs/roadmap_status.py")" "잠긴 파일 밖 로컬 모듈 import conductor_state" "양성 대조: 허용 밖 이름(save)을 함께 가져오면 잡는다"
printf 'import gh_repo\n' > "$T/ctlrs/roadmap_status.py"
assert_contains "$(LOCAL_DIR="$S" static_check "$T/ctlrs/roadmap_status.py")" "잠긴 파일 밖 로컬 모듈 import gh_repo" "양성 대조: 모듈째 import 는 잡는다"
printf 'from gh_repo import gh_json\n' > "$T/ctlrs/roadmap_status.py"
assert_contains "$(LOCAL_DIR="$S" static_check "$T/ctlrs/roadmap_status.py")" "잠긴 파일 밖 로컬 모듈 import gh_repo" "양성 대조: gh 를 부르는 gh_json 은 잡는다"
printf 'from gh_repo import origin_slug\n' > "$T/ctl_other.py"
assert_contains "$(LOCAL_DIR="$S" static_check "$T/ctl_other.py")" "잠긴 파일 밖 로컬 모듈 import gh_repo" "양성 대조: 허용은 상태 계산 파일에만"
cp "$S"/*.py "$T/ctlmods/"
python3 -I -c 'import sys; p = sys.argv[1]; s = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(s.replace("def own_version() -> str:\n", "def own_version() -> str:\n    Path(\"x\").write_text(\"y\", encoding=\"utf-8\")\n", 1))' "$T/ctlmods/conductor_state.py"
cmp -s "$S/conductor_state.py" "$T/ctlmods/conductor_state.py" && no "변이 적용 안 됨(읽기 함수가 부르는 함수의 쓰기)" || ok "변이 적용됨(읽기 함수가 부르는 함수의 쓰기)"
assert_contains "$(LOCAL_DIR="$T/ctlmods" static_check "$RS")" "읽기 함수 conductor_state.own_version 에 쓰기 호출 write_text" "양성 대조: parse_machine 이 부르는 함수의 쓰기까지 따라가 잡는다"
printf 'from subprocess import run\n' > "$T/ctl_from.py"
assert_contains "$(static_check "$T/ctl_from.py")" "subprocess 를 이름으로 import" "양성 대조: from subprocess import 를 잡는다"
# 네트워크 축 — 원격 대조(ls-remote)는 repo_defaults.py 의 NET_GIT_ALLOWED 하나 · check_remote_head 안에서만 쓰고,
# 상태 계산 · 상태줄(roadmap_status · control_plane)은 check_remote_head 를 부르지 않는다.
net_check() {  # net_check <파일...> — 네트워크 축 위반을 찾으면 줄을 낸다. 끝에 CHECKED n.
  python3 - "$@" <<'PY'
import ast, os, sys
count = 0
for path in sys.argv[1:]:
    count += 1
    base = os.path.basename(path)
    tree = ast.parse(open(path, encoding="utf-8").read())
    inside = set()
    for fn in ast.walk(tree):
        if isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef)) and fn.name == "check_remote_head":
            inside |= {id(n) for n in ast.walk(fn)}
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign) and any(getattr(t, "id", "") == "NET_GIT_ALLOWED" for t in node.targets):
            v = node.value
            lit = v.args[0] if isinstance(v, ast.Call) and getattr(v.func, "id", "") == "frozenset" and v.args else None
            vals = ({e.value for e in lit.elts} if isinstance(lit, (ast.Set, ast.List))
                    and all(isinstance(e, ast.Constant) for e in lit.elts) else None)
            if base != "repo_defaults.py":
                print("%s:%d: NET_GIT_ALLOWED 는 repo_defaults.py 에만 둔다" % (path, node.lineno))
            if vals != {"ls-remote"}:
                print("%s:%d: NET_GIT_ALLOWED 가 frozenset({'ls-remote'}) 가 아니다: %r" % (path, node.lineno, vals))
        elif isinstance(node, ast.Name) and node.id == "NET_GIT_ALLOWED" and isinstance(node.ctx, ast.Load) \
                and id(node) not in inside:
            print("%s:%d: NET_GIT_ALLOWED 를 check_remote_head 밖에서 쓴다" % (path, node.lineno))
        elif isinstance(node, ast.keyword) and node.arg == "allowed" and id(node) not in inside:
            print("%s:%d: git 허용 목록(allowed=)을 check_remote_head 밖에서 바꾼다" % (path, node.value.lineno))
        if base in ("roadmap_status.py", "control_plane.py"):
            name = (node.attr if isinstance(node, ast.Attribute) else node.id if isinstance(node, ast.Name)
                    else node.name if isinstance(node, ast.alias) else "")
            if name == "check_remote_head":
                print("%s:%d: 네트워크 대조 check_remote_head 를 부른다" % (path, getattr(node, "lineno", 0)))
print("CHECKED %d" % count)
PY
}
out="$(net_check "$RS" "$S/control_plane.py" "$S/repo_defaults.py")"; rc=$?
assert_eq "$rc:$(printf '%s\n' "$out" | grep -v '^CHECKED ')" "0:" "네트워크 축: ls-remote 는 check_remote_head 안에만 · 상태 계산 · 상태줄은 부르지 않는다"
assert_eq "$(printf '%s\n' "$out" | grep '^CHECKED ')" "CHECKED 3" "네트워크 축이 세 스크립트를 셌다"
assert_contains "$(cat "$S/repo_defaults.py")" 'NET_GIT_ALLOWED = frozenset({"ls-remote"})' "양의 짝: 네트워크 허용 목록이 실제로 있다"
sed 's/^    main, main_full, main_short, why = default_ref(repo)$/    main, main_full, main_short, why = default_ref(repo); repo_defaults.check_remote_head(repo.cwd, main_short)/' \
  "$S/control_plane.py" > "$T/control_plane.py"
cmp -s "$S/control_plane.py" "$T/control_plane.py" && no "변이 적용 안 됨(상태줄이 원격 대조)" || ok "변이 적용됨(상태줄이 원격 대조)"
assert_contains "$(net_check "$T/control_plane.py")" "네트워크 대조 check_remote_head 를 부른다" "양성 대조: 상태줄이 check_remote_head 를 부르면 잡는다"
printf 'from repo_defaults import check_remote_head\n' > "$T/roadmap_status.py"
assert_contains "$(net_check "$T/roadmap_status.py")" "네트워크 대조 check_remote_head 를 부른다" "양성 대조: 상태 계산이 이름으로 import 해도 잡는다"
sed 's/^def _toplevel(cwd: str) -> str:$/def _toplevel(cwd: str, allowed=NET_GIT_ALLOWED) -> str:/' "$S/repo_defaults.py" > "$T/repo_defaults.py"
cmp -s "$S/repo_defaults.py" "$T/repo_defaults.py" && no "변이 적용 안 됨(밖에서 네트워크 목록)" || ok "변이 적용됨(밖에서 네트워크 목록)"
assert_contains "$(net_check "$T/repo_defaults.py")" "NET_GIT_ALLOWED 를 check_remote_head 밖에서 쓴다" "양성 대조: check_remote_head 밖에서 네트워크 목록을 쓰면 잡는다"
sed 's/^NET_GIT_ALLOWED = frozenset({"ls-remote"})/NET_GIT_ALLOWED = frozenset({"ls-remote", "fetch"})/' "$S/repo_defaults.py" > "$T/repo_defaults.py"
assert_contains "$(net_check "$T/repo_defaults.py")" "NET_GIT_ALLOWED 가 frozenset" "양성 대조: 네트워크 목록에 fetch 를 더하면 잡는다"
printf 'import subprocess\nNET_GIT_ALLOWED = frozenset({"ls-remote"})\n' > "$T/roadmap_status.py"
assert_contains "$(net_check "$T/roadmap_status.py")" "NET_GIT_ALLOWED 는 repo_defaults.py 에만 둔다" "양성 대조: 다른 파일의 네트워크 목록을 잡는다"
printf 'def f(top):\n    return _git(top, "ls-remote", "origin", allowed=frozenset({"ls-remote"}))\n' > "$T/ctl_allowed.py"
assert_contains "$(net_check "$T/ctl_allowed.py")" "git 허용 목록(allowed=)을 check_remote_head 밖에서 바꾼다" "양성 대조: 허용 목록을 글자로 넘겨 우회하면 잡는다"
printf 'import subprocess\nGIT_ALLOWED = frozenset({"config"})\nsubprocess.run(["git", "config", "user.name", "x"])\n' > "$T/ctl_config.py"
assert_contains "$(static_check "$T/ctl_config.py")" "git config 를 --get 꼴 밖으로 부른다" "양성 대조: config 를 --get 없이 부르면 잡는다"
printf 'import subprocess\nGIT_ALLOWED = frozenset({"config"})\nsubprocess.run(["git", "config", "--get", "remote.origin.url"])\n' > "$T/ctl_config_ok.py"
assert_not_contains "$(static_check "$T/ctl_config_ok.py")" "config 를 --get 꼴 밖" "양의 짝: config --get 꼴은 통과"
for sub in fetch push update-ref; do
  out="$(cd "$S" && python3 -c 'import sys; import roadmap_status as r
try:
    r.Git(".").run(sys.argv[1])
    print("RAN")
except RuntimeError:
    print("REFUSED")' "$sub")"
  assert_eq "$out" "REFUSED" "실행: 허용 밖 git 하위 명령 $sub 은 부르기 전에 거부한다"
done
snap() { (cd "$W" && find . -path ./.git/objects -prune -o -type f -print0 | sort -z | xargs -0 shasum) ; git -C "$W" for-each-ref --format='%(refname) %(objectname)'; }
before="$(snap)"
(cd "$W" && python3 "$RS" --json docs/rm/roadmap.md >/dev/null; python3 "$RS" --roadmap-file docs/rm2/roadmap.md >/dev/null; python3 "$S/check_bundle_coverage.py" docs/rm/V1.md docs/rm/V1.md >/dev/null)
after="$(snap)"
[ "$before" = "$after" ] && ok "실행: 작업 트리 · .git · ref 가 실행 전후 같다" || no "실행: 스크립트가 무언가를 썼다"
printf 'x\n' >> "$W/README.txt"; after2="$(snap)"; git -C "$W" checkout -q -- README.txt
[ "$before" != "$after2" ] && ok "양성 대조: 파일 하나를 바꾸면 비교가 잡는다" || no "양성 대조: 비교가 변화를 못 본다"

# ── 6. 변이 — 첫째 부모 이력 제한(D4.24)과 조상 아님 조건(D1.1)에 이빨이 있는지 ──────
M="$T/mut"; mkdir -p "$M"; cp "$S/section6.py" "$S/brief_body.py" "$S/check_bundle_coverage.py" "$S/roadmap_model.py" "$S/repo_defaults.py" \
  "$S/conductor_state.py" "$S/gh_repo.py" "$S/state_path.py" "$S/ledger_marker.py" "$M/"
sed 's/"log", "--first-parent", "--merges"/"log", "--merges"/' "$RS" > "$M/roadmap_status.py"
cmp -s "$RS" "$M/roadmap_status.py" && no "변이 적용 안 됨(--first-parent)" || ok "변이 적용됨(--first-parent)"
(cd "$W" && python3 "$M/roadmap_status.py" --json docs/rm/roadmap.md > "$T/mfp.json")
assert_eq "$(stage "$T/mfp.json" U1)" "머지됨" "변이: --first-parent 를 빼면 U1 이 머지됨 — 위 U1 단언에 이빨이 있다"
sed 's/and m.group(2) == branch:/and m.group(2).startswith(branch):/' "$RS" > "$M/roadmap_status.py"
cmp -s "$RS" "$M/roadmap_status.py" && no "변이 적용 안 됨(정확히 같음)" || ok "변이 적용됨(정확히 같음)"
(cd "$W" && python3 "$M/roadmap_status.py" --json docs/rm/roadmap.md > "$T/mpx.json")
assert_eq "$(stage "$T/mpx.json" E1)" "머지됨" "변이: 정확히 같음을 앞부분 같음으로 바꾸면 E1 이 머지됨 — E1 단언에 이빨이 있다"
sed '/if tip and not git.is_ancestor(tip, main):/,/return None/d' "$RS" > "$M/roadmap_status.py"
cmp -s "$RS" "$M/roadmap_status.py" && no "변이 적용 안 됨(main 에 다 들어 있음)" || ok "변이 적용됨(main 에 다 들어 있음)"
(cd "$W" && python3 "$M/roadmap_status.py" --json docs/rm/roadmap.md > "$T/mff.json")
assert_eq "$(stage "$T/mff.json" Y1)" "머지됨" "변이: 「브랜치 끝이 main 에 들어 있음」 조건을 지우면 Y1 이 머지됨 — Y1 단언에 이빨이 있다"
sed 's/if len(parents) >= 2 and parents\[1\] == tip and not git.is_ancestor(tip, parents\[0\]):/if False:/' "$RS" > "$M/roadmap_status.py"
cmp -s "$RS" "$M/roadmap_status.py" && no "변이 적용 안 됨(머지 커밋 둘째 부모 규칙)" || ok "변이 적용됨(머지 커밋 둘째 부모 규칙)"
(cd "$W" && python3 "$M/roadmap_status.py" --json docs/rm/roadmap.md > "$T/mA1.json")
[ "$(stage "$T/mA1.json" A1)" != "머지됨" ] && ok "변이: 둘째 부모 규칙을 끄면 A1 은 머지됨이 아니다 — A1 단언에 이빨이 있다" || no "변이: 둘째 부모 규칙을 꺼도 A1 이 머지됨이다"
sed 's/ and not git.is_ancestor(tip, parents\[0\])//' "$RS" > "$M/roadmap_status.py"
cmp -s "$RS" "$M/roadmap_status.py" && no "변이 적용 안 됨(조상 아님 조건)" || ok "변이 적용됨(조상 아님 조건)"
(cd "$W" && python3 "$M/roadmap_status.py" --json docs/rm/roadmap.md > "$T/mg9.json")
assert_eq "$(stage "$T/mg9.json" G9)" "머지됨" "변이: 조상 아님 조건을 지우면 G9 가 머지됨 — G9 단언에 이빨이 있다"

# ── 6b. 미룸 경고(R3 AC9) — 받는 곳 없는 행 · 머지 뒤에도 · 깨진 표는 셀 수 없음 · 변이 ─────
mkdir -p "$W/docs/rm8" "$W/docs/rm9"
bundle docs/rm8 D8 "C1, D2, OQ1, RC1, ST1, «k1», K1, K2, S1, S2"
bundle docs/rm8 E8 "C1"
bundle docs/rm9 F9 "C1, D2, OQ1, RC1, ST1, «k1», K1, K2, S1, S2"
{ roadmap_head; block D8 feature/d8 없음 없음; block E8 feature/e8 없음 없음; roadmap_tail ""; } > "$W/docs/rm8/roadmap.md"
{ roadmap_head; block F9 feature/f9 없음 없음; roadmap_tail ""; } > "$W/docs/rm9/roadmap.md"
g checkout -q main
g add -- docs/rm8 docs/rm9 && g commit -qm "rm8 · rm9" && g push -q origin main
defer_spec() {  # defer_spec <source_interview> <미룸 절 본문>
  printf -- '---\nsource_interview: %s\n---\n\n# 설계\n\n### §1 절\n\n1. 하나\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| C1 · D2 · OQ1 · RC1 · ST1 · «k1» · K1 · K2 · S1 · S2 | 반영 | §1 |\n\n## 미룸\n\n%b\n' "$1" "$2"
}
g checkout -q -b feature/d8 main; mkdir -p "$W/docs/superpowers/specs"
defer_spec docs/rm8/D8.md '| 항목 | 이유 | 받는 곳 |\n|---|---|---|\n| AC2 | 시간 | 없음 |\n| AC3 | 넘김 | R99 |\n| AC4 | 후속 | #12 |\n| r1.2 | 리뷰 후속 | `E8` |' > "$W/docs/superpowers/specs/d8-design.md"
g add -- docs/superpowers/specs/d8-design.md && g commit -qm "d8 spec"
pr_merge 81 feature/d8; g push -q origin main
g checkout -q -b feature/f9 main
defer_spec docs/rm9/F9.md '| 항목 | 받는 곳 |\n|---|---|\n| AC2 | 없음 |' > "$W/docs/superpowers/specs/f9-design.md"
g add -- docs/superpowers/specs/f9-design.md && g commit -qm "f9 spec"; g checkout -q main
g fetch -q origin
(cd "$W" && python3 "$RS" --json docs/rm8/roadmap.md > "$T/d8.json"); rc=$?
assert_eq "$(stage "$T/d8.json" D8)" "머지됨" "D8 은 머지됐다"
assert_contains "$(warns "$T/d8.json" D8)" "받는 곳 없는 미룸 2개: docs/superpowers/specs/d8-design.md — AC2 · AC3" "AC9: 받는 곳이 없음 · 로드맵에 없는 에픽인 행을 경고한다(머지 뒤에도)"
assert_not_contains "$(warns "$T/d8.json" D8)" "AC4" "AC9 양성 짝: #12 · 로드맵에 있는 에픽(백틱 친 E8)은 경고하지 않는다"
assert_eq "$rc" "1" "AC9: 미룸 경고는 경고(rc 1)다"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm9/roadmap.md > "$T/f9.json"); rc=$?
assert_eq "$rc" "3" "AC9: ## 미룸 표가 깨지면 검사 불가(rc 3)"
assert_contains "$(warns "$T/f9.json" F9)" "미룸 셀 수 없음(" "AC9: 깨진 표는 「셀 수 없음」"
assert_contains "$(js "$T/f9.json" "r['unknown_reasons']")" "F9 미룸 표" "AC9: 셀 수 없음이 검사 불가 사유로 올라온다"
# 변이(AC15) — 받는 곳 판정을 끄면 경고가 사라진다
M3="$T/mut3"; mkdir -p "$M3"; cp "$S/section6.py" "$S/brief_body.py" "$S/check_bundle_coverage.py" "$S/roadmap_model.py" "$S/repo_defaults.py" \
  "$S/conductor_state.py" "$S/gh_repo.py" "$S/state_path.py" "$S/ledger_marker.py" "$M3/"
sed 's/^            bad = \[item for item, _why, recv in rows if not receiver_ok(recv, known_ids)\]$/            bad = []/' "$RS" > "$M3/roadmap_status.py"
cmp -s "$RS" "$M3/roadmap_status.py" && no "변이 적용 안 됨(받는 곳 판정)" || ok "변이 적용됨(받는 곳 판정)"
(cd "$W" && python3 "$M3/roadmap_status.py" --json docs/rm8/roadmap.md > "$T/md8.json")
assert_not_contains "$(warns "$T/md8.json" D8)" "받는 곳 없는 미룸" "변이: 받는 곳 판정을 끄면 경고가 사라진다 — AC9 단언에 이빨이 있다"

# ── 6c. 끝에서 끝(R3 Verification) — 묶음 → 설계문서(얕은 행 하나) → spec-review 진입 → 계획(AC 하나 빠짐)
#        → --plan → ## 미룸 → --impl → roadmap_status 경고 ─────────────────────────────
mkdir -p "$W/docs/rm7"
bundle docs/rm7 G7 "C1, D2, OQ1, RC1, ST1, «k1», K1, K2, S1, S2"
{ roadmap_head; block G7 feature/g7 없음 없음; roadmap_tail ""; } > "$W/docs/rm7/roadmap.md"
g checkout -q main; g add -- docs/rm7 && g commit -qm "rm7" && g push -q origin main
g checkout -q -b feature/g7 main; mkdir -p "$W/docs/superpowers/specs" "$W/docs/superpowers/plans"
printf -- '---\nsource_interview: docs/rm7/G7.md\n---\n\n# G7 설계\n\n### §1 절\n\n1. 하나\n\n## Acceptance Criteria\n\n- AC1 하나\n- AC2 둘\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| C1 · D2 · OQ1 · RC1 · ST1 · «k1» · K1 · K2 · S1 | 반영 | §1 · AC1 |\n| S2 | 반영 | 자리를 말하지 않는다 |\n\n## 미룸\n\n| 항목 | 이유 | 받는 곳 |\n|---|---|---|\n| AC2 | 다음에 | 없음 |\n' > "$W/docs/superpowers/specs/g7-design.md"
printf '# 계획\n\n**Spec:** `docs/superpowers/specs/g7-design.md`\n\n### Task 1: 하나\n\n- AC1\n' > "$W/docs/superpowers/plans/g7.md"
g add -- docs/superpowers && g commit -qm "g7 설계 · 계획"; g checkout -q main
g checkout -q feature/g7
E2E="$(cd "$W" && python3 "$S/spec_review_bundle.py" entry --spec docs/superpowers/specs/g7-design.md --bundle docs/rm7/G7.md --root "$W")"
assert_contains "$E2E" "얕은 답 — S2: 가리킨 자리가 없다" "끝에서 끝: spec-review 진입이 얕은 행을 보인다"
assert_contains "$E2E" "번호 대조 경고 1개" "끝에서 끝: 경고 수 1"
PLN="$(cd "$W" && python3 "$S/check_bundle_coverage.py" --plan docs/superpowers/specs/g7-design.md docs/superpowers/plans/g7.md)"; rc=$?
assert_eq "$rc:$PLN" "1:계획 대조: 계획에 없는 AC 1개 — AC2 (AC 2개)" "끝에서 끝: --plan 이 빠진 AC2 를 잡는다"
printf 'AC1: 구현됨 — 됐다\nAC2: 미룸 — 다음에\n' > "$T/g7-report.md"
IMP="$(cd "$W" && python3 "$S/check_bundle_coverage.py" --impl docs/superpowers/specs/g7-design.md "$T/g7-report.md")"
assert_contains "$IMP" "받는 곳 없는 미룸 — AC2" "끝에서 끝: --impl 이 받는 곳 없는 미룸을 잡는다"
g checkout -q main
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm7/roadmap.md > "$T/g7.json")
assert_eq "$(stage "$T/g7.json" G7)" "계획" "끝에서 끝: G7 은 계획 단계"
assert_contains "$(warns "$T/g7.json" G7)" "받는 곳 없는 미룸 1개: docs/superpowers/specs/g7-design.md — AC2" "끝에서 끝: roadmap_status 가 같은 미룸을 경고한다"

# ── 7. 실데이터 — 이번 일의 로드맵 · 묶음(R0 AC1 · AC2 · AC3) ─────────────────
# git 없이 함수로 잰다 — origin 이 없는 클론에서도 같은 판정이 나야 한다.
real_check() {  # real_check <리포 루트> — 키<TAB>값 줄들
  (cd "$S" && python3 - "$1" <<'PY'
import re, sys
from pathlib import Path
import check_bundle_coverage as cbc, roadmap_render as R, roadmap_status as rs, section6
root = Path(sys.argv[1])
rm = "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose"
text = (root / rm / "roadmap.md").read_text(encoding="utf-8")
meta, blocks, records, risk, errors = rs.parse_roadmap(text)
print("ERRORS\t%s" % errors)
print("BLOCKS\t%s" % " ".join("%s:%s" % (b["id"], b["kind"]) for b in blocks))
brief = (root / meta["source_brief"]).read_text(encoding="utf-8")
audit = (root / meta["source_brief"].replace(".md", ".audit.md")).read_text(encoding="utf-8")
non_s, s_ids, k_expected = rs.brief_universe(brief, audit)
print("RISK\t%s" % (risk == k_expected and len(risk) == 15))
union, bad = set(), []
want6 = section6.body(brief).rstrip("\n") + "\n\n" + section6.body(audit)
s1 = cbc.section_body(brief, "## 1.")
for b in blocks:
    if b["kind"] != "bundle":
        union |= set(b["assigned"])
        continue
    bt = (root / rm / b["fields"]["묶음"]).read_text(encoding="utf-8")
    fm = cbc.frontmatter(bt)
    if (fm.get("type"), fm.get("epic"), fm.get("roadmap"), fm.get("source_brief")) != (
            "epic-bundle", b["id"], rm + "/roadmap.md", meta["source_brief"]):
        bad.append(b["id"] + ":frontmatter")
    union |= set(cbc.bundle_ids(bt))
    if [l for l in bt.splitlines() if l.startswith("## ")] != [
            "## 0. 역참조", "## 1. Goal · Non-goal", "## 2. 제약", "## 3. 열린 질문",
            "## 4. 웹 근거", "## 5. 기각 · 위험", "## 6. 사용자 원문", "## 7. 인터페이스"]:
        bad.append(b["id"] + ":절")
    if section6.body(bt) != want6:
        bad.append(b["id"] + ":§6")
    if bt.split("### 공통 목표\n", 1)[1].split("\n## 2. ", 1)[0] + "\n" != s1:
        bad.append(b["id"] + ":공통 목표")
    mine = bt.split("### 이 에픽의 Goal · Non-goal\n\n", 1)[1].split("\n\n### 공통 목표", 1)[0]
    if mine.splitlines() != ["- 의도: " + b["fields"]["의도"], "- 범위: " + R.scope_text(b["fields"]["범위"])]:
        bad.append(b["id"] + ":의도 · 범위")
print("BAD\t%s" % bad)
print("UNASSIGNED\t%s" % sorted(non_s - union, key=cbc.id_sort_key))
print("ORPHANS\t%s" % sorted(s_ids - union, key=cbc.id_sort_key))
print("UNKNOWN\t%s" % sorted(union - non_s - s_ids, key=cbc.id_sort_key))
print("OVERLAPS\t%s" % rs.overlaps(blocks))
r0 = next(b for b in blocks if b["id"] == "R0")
spec = (root / r0["fields"]["spec"]).read_text(encoding="utf-8")
print("R0TABLE\t%s" % (set(r0["assigned"]) == cbc.table_ids(spec)))


def lock_rows(text, blocks):
    """락 지도 표의 (파일, 에픽) 중 파일을 다른 에픽이 예약한 줄 — (검사한 줄 수, 위반 목록)."""
    checked, bad_rows = 0, []
    for line in text.splitlines():
        cells = [c.strip() for c in re.split(r"(?<!\\)\|", line)[1:-1]]
        m = re.fullmatch(r"(\S+):(\d+)", cells[0]) if len(cells) >= 4 else None
        if not m:
            continue
        checked += 1
        others = [b["id"] for b in blocks if b["id"] != cells[2]
                  and any(rs._reserves(e, m.group(1)) for e in b["reserved"])]
        if others:
            bad_rows.append("%s %s 는 %s 가 예약했다" % (cells[2], m.group(1), "·".join(others)))
    return checked, bad_rows


n, bad_rows = lock_rows((root / rm / "locks.md").read_text(encoding="utf-8"), blocks)
print("LOCKROWS\t%d" % n)
print("LOCKBAD\t%s" % bad_rows)
synthetic = "| plugins/spec-distill/tests/test_conducting_interview_stage.sh:149 | x | R2 | y |"
print("LOCKCTL\t%s" % lock_rows(synthetic, blocks)[1])
PY
  )
}
REAL="$(real_check "$ROOT")"
field_of() { printf '%s\n' "$REAL" | awk -F'\t' -v k="$1" '$1==k {print $2}'; }
assert_eq "$(field_of ERRORS)" "[]" "실데이터 AC1: 로드맵 형식 깨짐 없음"
# 처음 15블록은 이름 · 종류 · 순서가 그대로이고, 재분해로 뒤에 붙은 블록은 묶음 에픽이어야 한다
# (references/redecompose.md — 새 에픽은 R<max+1>). 블록 수를 박지 않는다.
assert_grep "$(field_of BLOCKS)" '^P1:branch P2:branch P3:decision P4:decision R0:branch R1:bundle R2:bundle R7:bundle R3:bundle R4:bundle R6:bundle R2a:bundle R5:bundle R8:bundle R9:bundle( R[0-9]+[a-z]?:bundle)*$' "실데이터 AC1: 처음 15블록과 종류 · 뒤에 붙은 블록은 묶음"
assert_eq "$(field_of RISK)" "True" "실데이터: 위험 번호표 K1~K15 가 brief §5 원문과 같다"
assert_eq "$(field_of BAD)" "[]" "실데이터 AC2: 묶음 10개의 frontmatter · 절 · §6 · 공통 목표 · 의도 · 범위가 바이트 그대로"
assert_eq "$(field_of UNASSIGNED)" "[]" "실데이터 AC3: 미배정 번호 0"
assert_eq "$(field_of ORPHANS)" "[]" "실데이터 AC3: 고아 발화 0"
assert_eq "$(field_of UNKNOWN)" "[]" "실데이터: brief 에 없는 번호 0"
assert_eq "$(field_of OVERLAPS)" "[{'blocks': ['R2', 'R3'], 'paths': ['plugins/spec-distill/references/docreview-profiles/design-doc.md']}, {'blocks': ['R2a', 'R10'], 'paths': ['plugins/spec-distill/scripts/brief_body.py', 'plugins/spec-distill/scripts/check_brief.py']}, {'blocks': ['R5', 'R10'], 'paths': ['plugins/spec-distill/references/proceed-gate.md', 'plugins/spec-distill/scripts/roadmap_model.py', 'plugins/spec-distill/scripts/roadmap_render.py', 'plugins/spec-distill/scripts/state_path.py', 'plugins/spec-distill/skills/pm-interview/references/finishing.md']}, {'blocks': ['R5', 'R12'], 'paths': ['plugins/spec-distill/references/conducting.md', 'plugins/spec-distill/references/conductor-dispatch.md', 'plugins/spec-distill/references/redecompose.md', 'plugins/spec-distill/skills/spec-review/SKILL.md']}, {'blocks': ['R5', 'R13'], 'paths': ['plugins/spec-distill/scripts/state_path.py', 'plugins/spec-distill/skills/pm-interview/references/finishing.md', 'plugins/spec-distill/skills/spec-review/SKILL.md']}, {'blocks': ['R10', 'R12'], 'paths': ['plugins/spec-distill/skills/request-framing/SKILL.md', 'plugins/spec-distill/skills/reviewing-brief/SKILL.md']}]" "실데이터: 의존 없이 겹치는 경로 예약은 정보 여섯 —R2 ↔ R3 의 design-doc.md · R2a ↔ R10 의 brief_body.py · check_brief.py(R10 계획 셋 예약) · R5 ↔ R10 의 proceed-gate.md · roadmap_model.py · roadmap_render.py · state_path.py · pm-interview finishing.md(R10 계획 셋 예약 · R5 예약은 이름 따라가기) · R5 ↔ R12 의 conducting.md · conductor-dispatch.md · redecompose.md · spec-review SKILL.md · R5 ↔ R13 의 state_path.py · pm-interview finishing.md · spec-review SKILL.md ·R10 ↔ R12 의 request-framing · reviewing-brief SKILL.md(병렬 유지, 충돌은 머지 때 푼다)"
assert_eq "$(field_of R0TABLE)" "True" "실데이터: R0 블록의 항목 · 발화 = R0 설계문서 번호 대조 표의 첫 칸"
assert_eq "$(field_of LOCKBAD)" "[]" "실데이터: 락 지도의 모든 줄이 다른 에픽이 예약한 파일을 자기 것으로 적지 않았다"
[ "$(field_of LOCKROWS)" -ge 10 ] && ok "실데이터: 락 지도 줄 $(field_of LOCKROWS)개를 읽었다(양성 대조 — 표를 못 읽으면 0)" || no "실데이터: 락 지도 줄을 10개 미만으로 읽었다($(field_of LOCKROWS))"
assert_contains "$(field_of LOCKCTL)" "R2 plugins/spec-distill/tests/test_conducting_interview_stage.sh 는 R1 가 예약했다" "양성 대조: 다른 에픽이 예약한 파일의 줄을 잡는다"
# 양성 대조 — 사본에서 묶음 하나의 번호를 빼고 다른 묶음의 §6 을 한 글자 바꾸면 위 검사가 잡는다
RMD=docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose
mkdir -p "$T/ctl/docs/superpowers/roadmaps" "$T/ctl/docs/superpowers/interview" "$T/ctl/docs/superpowers/specs"
cp -R "$ROOT/$RMD" "$T/ctl/docs/superpowers/roadmaps/"
cp "$ROOT"/docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview*.md "$T/ctl/docs/superpowers/interview/"
cp "$ROOT/docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md" "$T/ctl/docs/superpowers/specs/"
sed -i.bak 's/^ids: \[\(.*\), D46, /ids: [\1, /' "$T/ctl/$RMD/R7.md"
sed -i.bak 's/^  > 내 의도를 왜곡하는 장치들 다 제거야$/  > 내 의도를 왜곡하는 장치들 다 제거다/' "$T/ctl/$RMD/R2.md"
rm -f "$T/ctl/$RMD"/*.bak
CTL="$(real_check "$T/ctl")"
ctl_of() { printf '%s\n' "$CTL" | awk -F'\t' -v k="$1" '$1==k {print $2}'; }
assert_eq "$(ctl_of UNASSIGNED)" "['D46']" "양성 대조: 묶음에서 D46 을 빼면 미배정으로 잡힌다"
assert_contains "$(ctl_of BAD)" "R2:§6" "양성 대조: 묶음 §6 의 한 글자 변경을 잡는다"

# ── R5 AC39 · AC11 — 기본 브랜치 이름이 main 이 아닌 레포 · origin/HEAD 없음 · 기본 브랜치에 없는 로드맵 ──
git init -q --bare -b trunk "$T/trunk.git"
git clone -q "$T/trunk.git" "$T/tw" 2>/dev/null
W_SAVE="$W"; W="$T/tw"
g symbolic-ref HEAD refs/heads/trunk
commit_file README.txt "시작" "init"
g push -q origin trunk
write_brief "$W/docs/br"; mkdir -p "$W/docs/rm"
bundle docs/rm A1 "C1, D2, OQ1, RC1, ST1, «k1», K1, K2, S1, S2"
{ roadmap_head; block A1 feature/a1 없음 없음; roadmap_tail ""; } > "$W/docs/rm/roadmap.md"
g add -- docs && g commit -qm "docs" && g push -q origin trunk
g checkout -q -b feature/a1 trunk; commit_file src/a.txt a "a1"
g checkout -q trunk && g merge -q --no-ff feature/a1 -m "Merge pull request #9 from o/feature/a1" && g push -q origin trunk
g fetch -q origin
g remote set-head origin -d >/dev/null 2>&1   # 새 git 은 push · fetch 때 origin/HEAD 를 만든다 — 없는 상태를 확정한다
(cd "$W" && python3 "$RS" --json docs/rm/roadmap.md > "$T/trunk-nohead.json"); rc=$?
assert_eq "$rc" "3" "origin/HEAD 없음 → 검사 불가(rc 3)"
assert_contains "$(js "$T/trunk-nohead.json" "' | '.join(r['unknown_reasons'])")" "origin/HEAD" "origin/HEAD 없음 사유가 보인다 — 조용한 「로드맵 없음」이 아니다"
g remote set-head origin trunk
(cd "$W" && python3 "$RS" --json docs/rm/roadmap.md > "$T/trunk.json"); rc=$?
assert_eq "$(js "$T/trunk.json" "r['default_branch']")" "origin/trunk" "기본 브랜치 이름을 origin/HEAD 에서 읽는다"
assert_eq "$(js "$T/trunk.json" "r['source']")" "origin/trunk" "사본 이름도 기본 브랜치"
assert_eq "$(stage "$T/trunk.json" A1)" "머지됨" "기본 브랜치가 trunk 여도 머지됨"
out="$(cd "$W" && python3 "$RS" docs/none/roadmap.md)"; rc=$?
assert_eq "$rc" "4" "기본 브랜치에 없는 로드맵 → rc 4(검사 불가 3 과 다르다)"
assert_contains "$out" "로드맵이 아직 기본 브랜치(origin/trunk)에 없다" "기본 브랜치에 없음 줄"
(cd "$W" && python3 "$RS" --json docs/none/roadmap.md > "$T/none.json")
assert_eq "$(js "$T/none.json" "r['handoffs']")" "None" "rc 4 조기 반환 보고서에도 handoffs 키가 있다(계산 못 함 = None)"
assert_not_contains "$out" "검사 불가: " "기본 브랜치에 없음은 검사 불가 줄이 아니다"
for f in roadmap_status.py control_plane.py spec_review_bundle.py; do
  assert_eq "$(grep -c 'origin/main' "$S/$f")" "0" "$f 에 origin/main 을 박지 않는다(AC39)"
done
W="$W_SAVE"

# ── R5 AC14 · AC11 · AC12 — 레포 설정 폴더 · 백틱 없는 **Spec:** · 대조를 건너뛴 블록 ───────────
g checkout -q main
mkdir -p "$W/docs/rm2"
bundle docs/rm2 D1 "C1, S1"; bundle docs/rm2 D2 "C1, S1"
{ printf -- '---\ntype: roadmap\nsource_brief: docs/br/b.md\nspecs_dir: design\nplans_dir: work/plans/\n---\n\n# 로드맵\n\n## 에픽\n\n'
  block D1 feature/d1 없음 없음
  block D2 feature/d2 없음 없음
  printf '### N2 — 묶음 없는 블록\n- 의도: n\n- 범위: n\n- 의존: 없음\n- 브랜치: feature/n2\n- 묶음: 없음\n- 경로 예약: 없음\n- spec: design/n2-design.md\n- 발화: S1\n- 항목: C1\n\n'
  roadmap_tail ""
} > "$W/docs/rm2/roadmap.md"
g add -- docs/rm2 && g commit -qm "rm2" && g push -q origin main
# D1 — 설계문서는 design/ 에 · 계획은 work/plans/ 에 · **Spec:** 뒤에 백틱 없이 → 계획
g checkout -q -b feature/d1 main; mkdir -p "$W/design" "$W/work/plans" "$W/docs/superpowers/specs"
spec_doc docs/rm2/D1.md "C1 · S1" > "$W/design/d1-design.md"
printf '# 계획\n\n**Spec:** design/d1-design.md (§1)\n' > "$W/work/plans/d1.md"
g add -- design work && g commit -qm "d1" && g push -q origin feature/d1
# D2 — 기본 폴더(docs/superpowers/specs/)에만 설계문서 → 이 로드맵은 찾지 않는다
g checkout -q -b feature/d2 main; mkdir -p "$W/docs/superpowers/specs"
spec_doc docs/rm2/D2.md "C1 · S1" > "$W/docs/superpowers/specs/d2-design.md"
g add -- docs && g commit -qm "d2" && g push -q origin feature/d2
# N2 — 묶음 아닌 블록이 계획 단계
g checkout -q -b feature/n2 main; mkdir -p "$W/design" "$W/work/plans"
printf '# n2\n' > "$W/design/n2-design.md"; printf '**Spec:** `design/n2-design.md`\n' > "$W/work/plans/n2.md"
g add -- design work && g commit -qm "n2" && g push -q origin feature/n2
g checkout -q main; g fetch -q origin
(cd "$W" && python3 "$RS" --json docs/rm2/roadmap.md > "$T/rm2.json"); rc=$?
assert_eq "$rc" "1" "N17 만 있는 실행은 경고(rc 1) — 검사 불가(3)가 아니다"
assert_eq "$(js "$T/rm2.json" "r['settings']['specs_dir']")" "design/" "레포 설정: specs_dir 를 frontmatter 에서"
assert_eq "$(stage "$T/rm2.json" D1)" "계획" "D1: frontmatter 폴더 + 백틱 없는 **Spec:** → 계획"
assert_eq "$(stage "$T/rm2.json" D2)" "설계 중" "D2: 기본 폴더의 설계문서는 frontmatter 가 폴더를 정한 로드맵에서 찾지 않는다"
assert_eq "$(js "$T/rm2.json" "next(b['reason'] for b in r['blocks'] if b['id']=='D2')")" "브랜치 있음 · spec 없음" "D2 근거"
assert_contains "$(warns "$T/rm2.json" N2)" "번호 대조 건너뜀(셀 수 없음) — 묶음이 아닌 블록" "N17: 묶음 아닌 블록이 계획 단계면 경고"
assert_contains "$(warns "$OUT" A1)" "번호 대조 건너뜀(셀 수 없음) — 설계문서 없는 묶음" "N17: 설계문서 없이 머지된 묶음은 경고"
assert_not_contains "$(warns "$T/rm2.json" D2)" "번호 대조 건너뜀" "N17: 설계문서 없는 묶음이어도 설계 중 단계는 아직 경고하지 않는다"
sp="$(python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import roadmap_status as rs
for l in ("**Spec:** 설계 `design/a.md`", "**Spec:** design/a.md, design/b.md", "**Spec:** `design/c.md` (§1)", "**Spec:** design/d.md.", "**Spec:** design/e.md`", "**Spec:** (design/f.md)"): print(rs.spec_line_path(l))' "$S")"
assert_eq "$sp" "design/a.md
design/a.md
design/c.md
design/d.md
design/e.md
design/f.md" "Spec 줄 경로: 백틱 토큰 우선 · 없으면 첫 토큰의 끝 구두점 · 짝 없는 백틱 · 앞 여는 괄호를 뗀다"
sed 's/^specs_dir: design$/specs_dir: ..\/x/' "$W/docs/rm2/roadmap.md" > "$T/rm2-bad.md"
cp "$T/rm2-bad.md" "$W/docs/rm2/roadmap.md"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm2/roadmap.md > "$T/rm2-bad.json"); rc=$?
assert_eq "$rc" "3" "레포 설정 값이 잘못되면 검사 불가"
assert_contains "$(js "$T/rm2-bad.json" "' | '.join(r['format_errors'])")" "로드맵(docs/rm2/roadmap.md): specs_dir" "잘못된 레포 설정 사유"
assert_eq "$(js "$T/rm2-bad.json" "len(r['blocks']) > 0 and all(b['parallel'] is None for b in r['blocks'])")" "True" "형식 깨짐 보고서의 블록 parallel 은 None(빈 목록이 아니다)"
# R8 AC23b — 로드맵 머리말은 로드맵 층이 받는 키만 받는다(roadmaps_dir 는 레포 설정 파일 몫)
g checkout -q -- docs/rm2/roadmap.md
awk '{ print } /^specs_dir: design$/ { print "roadmaps_dir: docs/plans-x/" }' "$W/docs/rm2/roadmap.md" > "$T/rm2-layer.md"
assert_eq "$(grep -c '^roadmaps_dir: docs/plans-x/$' "$T/rm2-layer.md")" "1" "픽스처: 로드맵 머리말에 roadmaps_dir 줄이 들어갔다"
cp "$T/rm2-layer.md" "$W/docs/rm2/roadmap.md"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm2/roadmap.md > "$T/rm2-layer.json"); rc=$?
assert_eq "$rc" "3" "로드맵 머리말에 로드맵 층이 받지 않는 키(roadmaps_dir) → 검사 불가"
assert_contains "$(js "$T/rm2-layer.json" "' | '.join(r['format_errors'])")" "로드맵(docs/rm2/roadmap.md) 은 이 설정을 받지 않는다(roadmaps_dir)" "로드맵 층이 받지 않는 키 사유가 format_errors 에"
g checkout -q -- docs/rm2/roadmap.md

# ── R5 AC5 · AC6 · AC7 — 여러 브랜치 · 구현 중 · 구현 끝 · 산출물 ─────────────────────────────
g checkout -q main
mkdir -p "$W/docs/rm3"
for b in K1 K2 K3 M2 O1; do bundle docs/rm3 "$b" "C1, S1"; done
{ roadmap_head | sed 's|^# 로드맵|# 로드맵 셋|'
  block K1 "feature/k1a · feature/k1b · feature/k1c" 없음 없음
  block K2 feature/k2 없음 없음
  block K3 feature/k3 없음 없음
  block M2 "feature/m2a · feature/m2b" 없음 없음
  printf '### O1 — 조사\n- 의도: o\n- 범위: o\n- 의존: 없음\n- 브랜치: feature/o1\n- 묶음: O1.md\n- 경로 예약: 없음\n- 병렬: 없음\n- 흐름: 조사 「조사로 간다」\n- 산출물: docs/research/o1.md\n\n'
  roadmap_tail ""
} > "$W/docs/rm3/roadmap.md"
g add -- docs/rm3 && g commit -qm "rm3" && g push -q origin main
mkdir -p "$W/docs/superpowers/specs" "$W/docs/superpowers/plans"
SPEC_K1=docs/superpowers/specs/k1-design.md
# K1 — 첫 브랜치(계획 1)는 구현 대조 절까지 · 머지. 둘째 브랜치(계획 2)는 계획만 — 첫 계획의 절을 물려받는다.
g checkout -q -b feature/k1a main
spec_doc docs/rm3/K1.md "C1 · S1" > "$W/$SPEC_K1"
printf '**Spec:** `%s`\n' "$SPEC_K1" > "$W/docs/superpowers/plans/k1-p1.md"
g add -- docs && g commit -qm "k1 계획 1"
commit_file src/k1.txt k1 "$(printf 'k1 구현\n\nSpec: %s' "$SPEC_K1")"
printf '\n## 구현 대조 — docs/superpowers/plans/k1-p1.md\n\n- 요약\n' >> "$W/$SPEC_K1"
g add -- docs && g commit -qm "k1 구현 대조"
(cd "$W" && python3 "$RS" --json docs/rm3/roadmap.md > "$T/rm3-pre.json")
assert_eq "$(stage "$T/rm3-pre.json" K1)" "구현 끝" "AC7: 계획의 구현 대조 절이 모두 있으면 구현 끝"
pr_merge 21 feature/k1a; g push -q origin main
g checkout -q -b feature/k1b main
printf '**Spec:** `%s`\n' "$SPEC_K1" > "$W/docs/superpowers/plans/k1-p2.md"
g add -- docs && g commit -qm "k1 계획 2"
# K2 — 계획 뒤 Spec: 트레일러 커밋 → 구현 중
g checkout -q -b feature/k2 main
spec_doc docs/rm3/K2.md "C1 · S1" > "$W/docs/superpowers/specs/k2-design.md"
printf '**Spec:** `docs/superpowers/specs/k2-design.md`\n' > "$W/docs/superpowers/plans/k2.md"
g add -- docs && g commit -qm "$(printf 'k2 계획\n\nSpec: docs/superpowers/specs/k2-design.md')"
commit_file src/k2.txt k2 "$(printf 'k2 구현\n\nSpec: docs/superpowers/specs/k2-design.md')"
# K3 — 계획 커밋 자신에만 트레일러 → 아직 계획
g checkout -q -b feature/k3 main
spec_doc docs/rm3/K3.md "C1 · S1" > "$W/docs/superpowers/specs/k3-design.md"
printf '**Spec:** `docs/superpowers/specs/k3-design.md`\n' > "$W/docs/superpowers/plans/k3.md"
g add -- docs && g commit -qm "$(printf 'k3 계획\n\nSpec: docs/superpowers/specs/k3-design.md')"
# M2 — 두 브랜치 모두 머지
for br in feature/m2a feature/m2b; do
  g checkout -q -b "$br" main; commit_file "src/${br##*/}.txt" x "$br"; pr_merge 30 "$br"
done
g push -q origin main
# O1 — 산출물이 생김(번호 대조 절 없음)
g checkout -q -b feature/o1 main; mkdir -p "$W/docs/research"
printf -- '---\nsource_interview: docs/rm3/O1.md\n---\n\n# 조사 결과\n\n## 결정 기록\n\n- B1 · 결정 · 조사 결론\n' > "$W/docs/research/o1.md"
g add -- docs && g commit -qm "o1"
g checkout -q main; g fetch -q origin
(cd "$W" && python3 "$RS" --json docs/rm3/roadmap.md > "$T/rm3.json")
assert_eq "$(stage "$T/rm3.json" K1)" "일부 머지 1/3" "AC5: 세 브랜치 중 하나 머지 → 일부 머지 1/3"
assert_contains "$(js "$T/rm3.json" "next(b['reason'] for b in r['blocks'] if b['id']=='K1')")" "feature/k1b — 계획" "AC7: 둘째 브랜치는 앞 계획의 구현 대조 절을 물려받아도 계획 단계"
assert_eq "$(js "$T/rm3.json" "next(b['task_status'] for b in r['blocks'] if b['id']=='K1')")" "in_progress" "일부 머지는 진행 중"
assert_eq "$(stage "$T/rm3.json" K2)" "구현 중" "AC7: 계획 뒤 Spec: 트레일러 커밋 → 구현 중"
assert_eq "$(stage "$T/rm3.json" K3)" "계획" "AC7: 계획 커밋 자신의 트레일러는 구현 중이 아니다"
assert_eq "$(stage "$T/rm3.json" M2)" "머지됨" "AC5: 모든 브랜치 머지 → 머지됨"
assert_eq "$(stage "$T/rm3.json" O1)" "설계 중" "AC6: 산출물이 생기면 설계문서처럼 단계를 매긴다"
assert_eq "$(js "$T/rm3.json" "next(b['specs'] for b in r['blocks'] if b['id']=='O1')")" "['docs/research/o1.md']" "AC6: 산출물을 설계문서 자리로 읽는다"
assert_eq "$(js "$T/rm3.json" "' | '.join(r['unknown_reasons'])")" "" "AC6: 번호 대조 절 없는 산출물은 검사 불가가 아니다"
# K1 — 둘째 브랜치를 아직 만들지 않았으면(첫 브랜치만 머지) 예정 브랜치를 미완료로 센다
g branch -q -D feature/k1b
(cd "$W" && python3 "$RS" --json docs/rm3/roadmap.md > "$T/rm3b.json")
assert_eq "$(stage "$T/rm3b.json" K1)" "일부 머지 1/3" "AC5: 첫 머지 뒤 남은 예정 브랜치 때문에 머지됨이 아니다"
assert_contains "$(js "$T/rm3b.json" "next(b['reason'] for b in r['blocks'] if b['id']=='K1')")" "다음 브랜치 없음: feature/k1b" "다음 예정 브랜치 이름을 보인다"

# ── R5 수정 1 — 산출물에 `## 번호 대조` 머리가 둘이면 그 블록만 검사 불가 ────────────────────
g checkout -q main
mkdir -p "$W/docs/rm4"
bundle docs/rm4 P1 "C1, S1"; bundle docs/rm4 Q1 "C1, S1"
{ roadmap_head
  printf '### P1 — 조사\n- 의도: p\n- 범위: p\n- 의존: 없음\n- 브랜치: feature/p1\n- 묶음: P1.md\n- 경로 예약: 없음\n- 흐름: 조사 「조사로 간다」\n- 산출물: docs/research/p1d.md\n\n'
  block Q1 feature/q4 없음 없음
  roadmap_tail ""
} > "$W/docs/rm4/roadmap.md"
g add -- docs/rm4 && g commit -qm "rm4" && g push -q origin main
g checkout -q -b feature/p1 main; mkdir -p "$W/docs/research"
printf -- '---\nsource_interview: docs/rm4/P1.md\n---\n\n# 조사\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| C1 · S1 | 반영 | §1 |\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| C1 | 반영 | §2 |\n\n## 미룸\n\n| 항목 | 이유 | 받는 곳 |\n|---|---|---|\n| AC9 | 늦음 | 없음 |\n' > "$W/docs/research/p1d.md"
g add -- docs && g commit -qm "p1 중복 머리"; g checkout -q main; g fetch -q origin
(cd "$W" && python3 "$RS" --json docs/rm4/roadmap.md > "$T/rm4.json")
assert_eq "$(stage "$T/rm4.json" Q1)" "준비" "산출물 번호 대조 머리가 둘이어도 다른 블록의 단계는 나온다"
assert_contains "$(warns "$T/rm4.json" P1)" "번호 대조 검사 불가(" "산출물의 번호 대조 머리가 둘이면 그 블록에 경고"
assert_contains "$(js "$T/rm4.json" "' | '.join(r['unknown_reasons'])")" "P1 산출물 번호 대조 절" "산출물 머리 중복이 검사 불가 사유로 올라온다"
assert_contains "$(warns "$T/rm4.json" P1)" "받는 곳 없는 미룸 1개" "번호 대조 머리가 깨져도 미룸 표 검사는 이어진다"

# ── R5 수정 2 · 3 · 5 — 기본 브랜치를 받아온 뒤 · 결정 기록 머지 줄 · 구현 끝 · 다른 spec 트레일러 ────────
g checkout -q main
mkdir -p "$W/docs/rm5"
for b in Z5 V5 X5 H5 G5 J5 K5 L5 M5 N5 O5 S5; do bundle docs/rm5 "$b" "C1, S1"; done
{ roadmap_head | sed 's|^# 로드맵|# 로드맵 다섯|'
  block Z5 "feature/z5a · feature/z5b" 없음 없음
  block V5 feature/v5 없음 없음
  block X5 feature/x5 없음 없음
  block H5 "feature/h5a · feature/h5b" 없음 없음
  block G5 feature/g5 H5 없음
  block J5 "feature/j5a · feature/j5b" 없음 없음
  block K5 feature/k5 J5 없음
  block L5 "feature/l5a · feature/l5b" 없음 없음
  block M5 "feature/m5a · feature/m5b" 없음 없음
  block N5 "feature/n5a · feature/n5b" 없음 없음
  block O5 feature/o5 N5 없음
  printf '### S5 — 목록 브랜치\n- 의도: s\n- 범위: s\n- 의존: 없음\n- 브랜치:\n  - feature/s5a\n  - feature/s5b\n- 묶음: S5.md\n- 경로 예약: 없음\n\n'
  roadmap_tail "$(printf -- '- H5 · 머지 · 2026-10-17 · 「feature/h5a 를 squash 로 머지했다」\n- J5 · 머지 · 2026-10-17 · 「feature/j5a 를 squash 로 머지했다」\n- L5 · 머지 · 2026-10-17 · 「feature/l5a2 를 squash 로 머지했다」\n- M5 · 머지 · 2026-10-17 · 「feature/m5a 를 머지했다」\n- N5 · 머지 · 2026-10-17 · 「feature/n5a를 squash 로 머지했다」\n- N5 · 머지 · 2026-10-18 · 「feature/n5b. 이것도 머지했다」')"
} > "$W/docs/rm5/roadmap.md"
g add -- docs/rm5 && g commit -qm "rm5" && g push -q origin main
mkdir -p "$W/docs/superpowers/specs" "$W/docs/superpowers/plans"
SPEC_Z=docs/superpowers/specs/z5-design.md
# Z5 — z5b 는 z5a 가 머지되기 전에 갈라져 계획 2 를 더하고(트레일러 없음) 기본 브랜치를 받아온다.
g checkout -q -b feature/z5b main
printf '**Spec:** `%s`\n' "$SPEC_Z" > "$W/docs/superpowers/plans/z5-p2.md"
g add -- docs && g commit -qm "z5 계획 2"
g checkout -q -b feature/z5a main
spec_doc docs/rm5/Z5.md "C1 · S1" > "$W/$SPEC_Z"
printf '**Spec:** `%s`\n' "$SPEC_Z" > "$W/docs/superpowers/plans/z5-p1.md"
g add -- docs && g commit -qm "z5 계획 1"
commit_file src/z5.txt z5 "$(printf 'z5 구현\n\nSpec: %s' "$SPEC_Z")"
pr_merge 50 feature/z5a; g push -q origin main
g checkout -q feature/z5b; g merge -q main -m "sync main"; g checkout -q main
# V5 — 계획 뒤 커밋의 트레일러가 다른 spec 을 가리킨다 → 계획
g checkout -q -b feature/v5 main
spec_doc docs/rm5/V5.md "C1 · S1" > "$W/docs/superpowers/specs/v5-design.md"
printf '**Spec:** `docs/superpowers/specs/v5-design.md`\n' > "$W/docs/superpowers/plans/v5.md"
g add -- docs && g commit -qm "v5 계획"
commit_file src/v5.txt v5 "$(printf 'v5 다른 일\n\nSpec: docs/superpowers/specs/other-design.md')"
# X5 — 한 브랜치 계획 둘, 첫 계획만 구현 대조 절이 있다 → 구현 끝이 아니다
g checkout -q -b feature/x5 main
spec_doc docs/rm5/X5.md "C1 · S1" > "$W/docs/superpowers/specs/x5-design.md"
printf '\n## 구현 대조 — docs/superpowers/plans/x5-p1.md\n\n- 요약\n' >> "$W/docs/superpowers/specs/x5-design.md"
printf '**Spec:** `docs/superpowers/specs/x5-design.md`\n' > "$W/docs/superpowers/plans/x5-p1.md"
printf '**Spec:** `docs/superpowers/specs/x5-design.md`\n' > "$W/docs/superpowers/plans/x5-p2.md"
g add -- docs && g commit -qm "x5 계획 둘"
# H5 — h5a 는 squash 머지 뒤 지워졌고(결정 기록의 머지 줄) h5b 는 열려 있다
g checkout -q -b feature/h5a main; commit_file src/h5a.txt h5a "h5a"
g checkout -q main; g merge -q --squash feature/h5a; g commit -qm "squash h5a"; g branch -q -D feature/h5a; g push -q origin main
g checkout -q -b feature/h5b main; commit_file src/h5b.txt h5b "h5b"
g checkout -q -b feature/m5a main; commit_file src/m5a.txt m5a "m5a"
# N5 — 머지 줄 둘(브랜치마다 한 줄 · 한글 조사 · 문장 부호), 두 브랜치 모두 squash 뒤 지워졌다
for br in n5a n5b; do
  g checkout -q -b "feature/$br" main; commit_file "src/$br.txt" "$br" "$br"
  g checkout -q main; g merge -q --squash "feature/$br"; g commit -qm "squash $br"; g branch -q -D "feature/$br"
done
g push -q origin main
# J5 — j5a 는 squash 머지 뒤 지워졌고 j5b 는 아직 만들지 않았다(줄은 j5a 만 부른다)
g checkout -q -b feature/j5a main; commit_file src/j5a.txt j5a "j5a"
g checkout -q main; g merge -q --squash feature/j5a; g commit -qm "squash j5a"; g branch -q -D feature/j5a; g push -q origin main
g checkout -q main; g fetch -q origin
(cd "$W" && python3 "$RS" --json docs/rm5/roadmap.md > "$T/rm5.json")
assert_eq "$(stage "$T/rm5.json" Z5)" "일부 머지 1/2" "수정 2: 기본 브랜치를 받아온 브랜치는 남의 트레일러로 구현 중이 되지 않는다"
assert_contains "$(js "$T/rm5.json" "next(b['reason'] for b in r['blocks'] if b['id']=='Z5')")" "feature/z5b — 계획" "수정 2: 계획 단계로 읽는다"
assert_eq "$(stage "$T/rm5.json" V5)" "계획" "다른 spec 을 가리키는 트레일러는 구현 중이 아니다"
assert_eq "$(stage "$T/rm5.json" X5)" "구현 중" "수정 5: 계획 둘 중 하나만 구현 대조 절이 있으면 구현 끝이 아니다"
assert_not_contains "$(js "$T/rm5.json" "next(b['reason'] for b in r['blocks'] if b['id']=='X5')")" "트레일러" "구현 중 근거는 구현 대조 절만 말한다(트레일러를 붙이지 않는다)"
assert_eq "$(stage "$T/rm5.json" H5)" "일부 머지 1/2" "수정 3: 결정 기록 머지 줄은 ref 가 사라진 브랜치에만 닿는다"
assert_contains "$(warns "$T/rm5.json" H5)" "결정 기록의 머지 줄이 feature/h5b 를 가리키지 않아 적용하지 않았다" "수정 3: 줄이 부르지 않은 브랜치를 경고한다"
assert_eq "$(stage "$T/rm5.json" G5)" "대기" "수정 3: 일부 머지인 에픽에 의존하면 준비가 아니다"
assert_eq "$(stage "$T/rm5.json" M5)" "설계 중" "수정 3: 줄이 부른 브랜치가 남아 있으면 머지로 세지 않는다"
assert_contains "$(warns "$T/rm5.json" M5)" "결정 기록의 머지 줄을 feature/m5a 에 적용하지 않았다 — 브랜치가 남아 있다" "수정 3: 이름이 적힌 브랜치가 남아 있으면 남아 있다 경고"
assert_eq "$(stage "$T/rm5.json" J5)" "일부 머지 1/2" "수정 3: 아직 만들지 않은 예정 브랜치는 머지 줄에 이름이 없으면 머지가 아니다"
assert_contains "$(warns "$T/rm5.json" J5)" "결정 기록의 머지 줄이 feature/j5b 를 가리키지 않아 적용하지 않았다" "수정 3: 이름 없는 브랜치 경고"
assert_eq "$(stage "$T/rm5.json" N5)" "머지됨" "수정: 머지 줄은 쌓인다 — 브랜치마다 한 줄이면 여러 브랜치 블록이 머지됨"
assert_eq "$(stage "$T/rm5.json" O5)" "준비" "수정: 머지됨인 N5 에 의존하면 준비"
assert_eq "$(stage "$T/rm5.json" K5)" "대기" "수정 3: J5 에 의존하는 에픽은 준비가 아니다"
assert_eq "$(stage "$T/rm5.json" L5)" "준비" "수정 3: 브랜치 이름이 없는 머지 줄은 여러 브랜치 블록을 머지로 만들지 않는다"
assert_contains "$(warns "$T/rm5.json" L5)" "feature/l5a 를 가리키지 않아 적용하지 않았다" "수정 3: 이름 없는 머지 줄 경고(앞 브랜치)"
assert_contains "$(warns "$T/rm5.json" L5)" "feature/l5b 를 가리키지 않아 적용하지 않았다" "수정 3: 이름 없는 머지 줄 경고(뒤 브랜치)"
assert_eq "$(js "$T/rm5.json" "next(b['branch'] for b in r['blocks'] if b['id']=='S5')")" "feature/s5a · feature/s5b" "보고서의 branch 는 하위 항목 목록도 한 줄 글로 낸다"

# ── R5 AC8 · AC9 · AC43 — 판정 보관본 · 넘김 · 동시 가능 · 선택 칸 ──────────────────────────
g checkout -q feature/k2
printf '\n## 미룸\n\n| 항목 | 이유 | 받는 곳 |\n|---|---|---|\n| 넘길 일 | 이유 | K3 |\n| 이슈 일 | 이유 | #5 |\n\n## 판정\n\n- Task 1: Ruling: 가 — 왜 — 비용\n' >> "$W/docs/superpowers/specs/k2-design.md"
g add -- docs && g commit -qm "k2 미룸 · 판정"
g checkout -q main
(cd "$W" && python3 "$RS" --json docs/rm3/roadmap.md > "$T/rm3c.json")
assert_eq "$(js "$T/rm3c.json" "[(h['giver'], h['receiver'], h['state']) for h in r['handoffs']]")" "[('K2', 'K3', '열림'), ('K2', '#5', '이슈')]" "AC43: 넘김 줄을 상태 계산이 낸다"
assert_eq "$(js "$T/rm3c.json" "next(b['rulings_archived'] for b in r['blocks'] if b['id']=='K2')")" "['- Task 1: Ruling: 가 — 왜 — 비용']" "AC8: 설계문서 ## 판정 보관본"
assert_eq "$(js "$T/rm3c.json" "next(b['rulings_archived'] for b in r['blocks'] if b['id']=='K3')")" "None" "판정 절 없는 설계문서는 None(빈 목록과 다르다)"
assert_eq "$(js "$T/rm3c.json" "next(b['extras'] for b in r['blocks'] if b['id']=='O1')")" "{'흐름': '조사 「조사로 간다」', '산출물': 'docs/research/o1.md'}" "선택 칸을 보고서에 싣는다"
assert_eq "$(js "$T/rm3c.json" "'병렬' in next(b['extras'] for b in r['blocks'] if b['id']=='O1')")" "False" "없음 값 칸(- 병렬: 없음)은 extras 에서 빠진다"
assert_eq "$(js "$T/rm3c.json" "next(b['bundle'] for b in r['blocks'] if b['id']=='K2')")" "docs/rm3/K2.md" "묶음 경로"
assert_contains "$(js "$T/rm3c.json" "[p['id'] for p in next(b['parallel'] for b in r['blocks'] if b['id']=='K2')]")" "'K3'" "K2 와 K3 은 동시에 갈 수 있다"
assert_not_contains "$(js "$T/rm3c.json" "[p['id'] for p in next(b['parallel'] for b in r['blocks'] if b['id']=='K2')]")" "'M2'" "머지된 에픽은 동시 가능 목록에 없다"

# 판정 머리가 둘인 설계문서 하나가 보고서 전체를 지우지 않는다 — 그 블록에만 경고, 나머지 블록 · 넘김은 그대로
g checkout -q feature/k3
printf '\n## 판정\n\n- a\n\n## 판정\n\n- b\n' >> "$W/docs/superpowers/specs/k3-design.md"
g add -- docs && g commit -qm "k3 판정 머리 둘"
g checkout -q main
(cd "$W" && python3 "$RS" --json docs/rm3/roadmap.md > "$T/rm3d.json")
assert_contains "$(warns "$T/rm3d.json" K3)" "판정 읽기 불가(" "판정 머리가 둘이면 그 블록에 경고"
assert_eq "$(js "$T/rm3d.json" "next(b['rulings_archived'] for b in r['blocks'] if b['id']=='K3')")" "None" "읽지 못한 판정 절은 보관본 None"
assert_eq "$(js "$T/rm3d.json" "next(b['rulings_archived'] for b in r['blocks'] if b['id']=='K2')")" "['- Task 1: Ruling: 가 — 왜 — 비용']" "다른 블록의 보관본은 그대로 나온다"
assert_eq "$(js "$T/rm3d.json" "len(r['handoffs'])")" "2" "다른 블록의 넘김 줄도 그대로 나온다"
assert_contains "$(js "$T/rm3d.json" "' | '.join(r['unknown_reasons'])")" "K3 판정 읽기 불가" "읽을 수 없는 판정은 검사 불가 사유로도 올라온다"
assert_eq "$(js "$T/rm3c.json" "next(b['extras'] for b in r['blocks'] if b['id']=='K2')")" "{}" "선택 칸이 없는 블록은 빈 dict(없음 값은 싣지 않는다)"
assert_eq "$(js "$T/rm3c.json" "next(b['parallel'] for b in r['blocks'] if b['id']=='O1') is not None")" "True" "정상 보고서의 parallel 은 목록"

# 지휘 기록 — 확인 줄이 있으면 확인됨, 받는 에픽이 머지됐으나 확인 전이면 처리됨, 읽을 수 없으면 셀 수 없음(rc 3)
g checkout -q feature/k3
g revert --no-edit HEAD >/dev/null  # 판정 머리 둘 커밋을 되돌린다(revert 에는 -q 가 없다)
KEY="$(python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import conductor_state as c; print(c.handoff_key("K2", "넘길 일"))' "$S")"
printf '\n## 지휘 기록\n\n- 넘김 확인 · K2 · %s · 받았다\n' "$KEY" >> "$W/docs/superpowers/specs/k3-design.md"
g add -- docs && g commit -qm "k3 지휘 기록"
g checkout -q feature/k2
python3 -I -c 'import sys; p = sys.argv[1]; s = open(p, encoding="utf-8").read(); a = "| 이슈 일 | 이유 | #5 |\n"; assert a in s; open(p, "w", encoding="utf-8").write(s.replace(a, a + "| 머지 일 | 이유 | M2 |\n"))' "$W/docs/superpowers/specs/k2-design.md"
g add -- docs && g commit -qm "k2 미룸 셋"
g checkout -q main
(cd "$W" && python3 "$RS" --json docs/rm3/roadmap.md > "$T/rm3e.json"); rc3e=$?
assert_eq "$(js "$T/rm3e.json" "[(h['receiver'], h['state']) for h in r['handoffs']]")" "[('K3', '확인됨'), ('#5', '이슈'), ('M2', '처리됨')]" "넘김: 확인 줄 → 확인됨 · 받는 에픽 머지됨 + 확인 전 → 처리됨"
assert_not_contains "$(js "$T/rm3e.json" "' | '.join(r['unknown_reasons'])")" "지휘 기록" "읽을 수 있는 지휘 기록은 검사 불가 사유가 아니다"
g checkout -q feature/k3
printf '\n## 지휘 기록\n\n- 메모\n' >> "$W/docs/superpowers/specs/k3-design.md"
g add -- docs && g commit -qm "k3 지휘 기록 머리 둘"
g checkout -q main
(cd "$W" && python3 "$RS" --json docs/rm3/roadmap.md > "$T/rm3f.json"); rc=$?
assert_eq "$([ "$rc3e" -le 1 ] && echo ok || echo "rc $rc3e")" "ok" "지휘 기록 머리가 하나일 때는 검사 가능(rc 0 또는 1) — 아래 rc 3 의 다른 원인이 없다"
assert_eq "$rc" "3" "지휘 기록 머리가 둘로 읽을 수 없게 되면 검사 불가(rc 3)"
assert_eq "$(js "$T/rm3f.json" "[(h['receiver'], h['state'], h['basis']) for h in r['handoffs'] if h['receiver']=='K3']")" "[('K3', '셀 수 없음', 'K3 지휘 기록 읽기 불가')]" "읽을 수 없는 지휘 기록은 넘김을 셀 수 없음으로 — 처리됨 · 열림으로 오판하지 않는다"
assert_contains "$(js "$T/rm3f.json" "' | '.join(r['unknown_reasons'])")" "K3 지휘 기록 읽기 불가" "검사 불가 사유에 올라온다"
assert_eq "$(js "$T/rm3f.json" "[h['state'] for h in r['handoffs'] if h['receiver']!='K3']")" "['이슈', '처리됨']" "다른 받는 곳의 넘김은 그대로"
assert_eq "$(js "$T/rm3f.json" "len(r['blocks'])")" "$(js "$T/rm3e.json" "len(r['blocks'])")" "다른 블록은 그대로 나온다"

# ── 지휘자 수리 4 — 계획이 남은 에픽은 첫 계획 머지 뒤 「머지됨」이 아니다 ─────────────────────
# 기본 브랜치 블록의 `브랜치:` 에는 계획 1 만 있고, 계획 2 의 브랜치는 자기 브랜치의 로드맵 사본에서만 블록에 자신을 더한다.
g checkout -q main
mkdir -p "$W/docs/rm6"
bundle docs/rm6 E6 "C1, S1"
{ roadmap_head | sed 's|^# 로드맵|# 로드맵 여섯|'
  block E6 feature/e6a 없음 없음
  roadmap_tail ""
} > "$W/docs/rm6/roadmap.md"
g add -- docs/rm6 && g commit -qm "rm6" && g push -q origin main
SPEC_E6=docs/superpowers/specs/e6-design.md
g checkout -q -b feature/e6a main
mkdir -p "$W/docs/superpowers/specs" "$W/docs/superpowers/plans"
spec_doc docs/rm6/E6.md "C1 · S1" > "$W/$SPEC_E6"
printf '**Spec:** `%s`\n' "$SPEC_E6" > "$W/docs/superpowers/plans/e6-p1.md"
g add -- docs && g commit -qm "e6 계획 1"
pr_merge 61 feature/e6a; g push -q origin main
g checkout -q -b feature/e6b main
sed 's|^- 브랜치: feature/e6a$|- 브랜치: feature/e6a · feature/e6b|' "$W/docs/rm6/roadmap.md" > "$T/rm6-b.md" && cp "$T/rm6-b.md" "$W/docs/rm6/roadmap.md"
printf '**Spec:** `%s`\n' "$SPEC_E6" > "$W/docs/superpowers/plans/e6-p2.md"
g add -- docs && g commit -qm "e6 계획 2 — 블록에 자기 브랜치를 더함"
g checkout -q main
assert_eq "$(grep -c '^- 브랜치: feature/e6a$' "$W/docs/rm6/roadmap.md")" "1" "픽스처: 기본 브랜치 블록에는 계획 1 브랜치만 있다"
(cd "$W" && python3 "$RS" --json docs/rm6/roadmap.md > "$T/rm6.json")
assert_eq "$(stage "$T/rm6.json" E6)" "일부 머지 1/2" "수리 4: 다른 브랜치의 로드맵 사본이 더한 계획 브랜치가 남았으면 머지됨이 아니다"
assert_contains "$(js "$T/rm6.json" "next(b['reason'] for b in r['blocks'] if b['id']=='E6')")" "feature/e6b — 계획" "수리 4: 남은 계획 브랜치의 단계를 보인다"
assert_contains "$(notes "$T/rm6.json" E6)" "feature/e6b" "수리 4: 블록 밖에서 센 브랜치를 정보로 밝힌다"
assert_eq "$(js "$T/rm6.json" "next(b['branches'] for b in r['blocks'] if b['id']=='E6')")" "['feature/e6a', 'feature/e6b']" "수리 4: 보고서 branches 에 더한 브랜치가 실린다(PR 인계 · 통합 리뷰 묶음이 읽는다)"
assert_eq "$(js "$T/rm6.json" "next(b['task_status'] for b in r['blocks'] if b['id']=='E6')")" "in_progress" "수리 4: 작업 목록은 진행 중"
# 양성 짝 — 그 브랜치가 없으면(지웠거나 아직 안 만든 이름) 머지됨 그대로
g branch -q -m feature/e6b feature/e6b-kept
g checkout -q -b feature/e6c main
sed 's|^- 브랜치: feature/e6a$|- 브랜치: feature/e6a · feature/e6z|' "$W/docs/rm6/roadmap.md" > "$T/rm6-c.md" && cp "$T/rm6-c.md" "$W/docs/rm6/roadmap.md"
g add -- docs && g commit -qm "e6 사본 — 없는 브랜치 이름"
g checkout -q main
(cd "$W" && python3 "$RS" --json docs/rm6/roadmap.md > "$T/rm6b.json")
assert_eq "$(stage "$T/rm6b.json" E6)" "머지됨" "수리 4 양성 짝: 사본에만 있는 이름의 브랜치가 없으면 머지됨"
assert_eq "$(js "$T/rm6b.json" "next(b['branches'] for b in r['blocks'] if b['id']=='E6')")" "['feature/e6a']" "수리 4 양성 짝: 없는 브랜치는 branches 에 더하지 않는다"
# 양성 짝 — 더한 브랜치가 기본 브랜치에 머지됐으면(그 로드맵 사본도 함께 머지됨) 2/2 머지됨
g branch -q -m feature/e6b-kept feature/e6b
g branch -q -D feature/e6c
pr_merge 62 feature/e6b; g push -q origin main
(cd "$W" && python3 "$RS" --json docs/rm6/roadmap.md > "$T/rm6c.json")
assert_eq "$(stage "$T/rm6c.json" E6)" "머지됨" "수리 4 양성 짝: 둘째 계획까지 머지되면 머지됨"
# 수리 4 갈래 — F21: 결정 기록 머지 줄로 머지된 블록 브랜치 + 사본이 더한 브랜치 · G21: 사본이 더한 이름이 이미 머지됐으면 세지 않는다 ·
# H21: 형식이 깨진 사본은 건너뛰되 그 수를 정보로 밝힌다
g checkout -q main
mkdir -p "$W/docs/rm21"
for b in F21 G21 H21; do bundle docs/rm21 "$b" "C1, S1"; done
{ roadmap_head | sed 's|^# 로드맵|# 로드맵 스물하나|'
  block F21 feature/f21a 없음 없음
  block G21 feature/g21a 없음 없음
  block H21 feature/h21a 없음 없음
  roadmap_tail "$(printf -- '- F21 · 머지 · 2026-10-19 · 「feature/f21a 를 squash 로 머지했다」')"
} > "$W/docs/rm21/roadmap.md"
g add -- docs/rm21 && g commit -qm "rm21" && g push -q origin main
for br in feature/g21a feature/g21m feature/h21a; do
  g checkout -q -b "$br" main; commit_file "src/${br##*/}.txt" x "$br"; pr_merge 70 "$br"
done
g push -q origin main
g checkout -q -b feature/f21b main
sed 's|^- 브랜치: feature/f21a$|- 브랜치: feature/f21a · feature/f21b|; s|^- 브랜치: feature/g21a$|- 브랜치: feature/g21a · feature/g21m|' "$W/docs/rm21/roadmap.md" > "$T/rm21-b.md" && cp "$T/rm21-b.md" "$W/docs/rm21/roadmap.md"
g add -- docs && g commit -qm "f21 계획 2 · g21 사본(이미 머지된 이름)"
g checkout -q -b feature/h21x main
sed 's|^type: roadmap$|type: not-roadmap|' "$W/docs/rm21/roadmap.md" > "$T/rm21-x.md" && cp "$T/rm21-x.md" "$W/docs/rm21/roadmap.md"
g add -- docs && g commit -qm "h21 깨진 사본"
# 낡은 사본 — 블록의 브랜치를 품지 않고 다른 이름만 적은 사본(재분해 전 · 같은 경로를 다시 쓴 경우)은 이 블록을 잇는 사본이 아니다
g checkout -q -b feature/g21old main
sed 's|^- 브랜치: feature/g21a$|- 브랜치: feature/g21old|' "$W/docs/rm21/roadmap.md" > "$T/rm21-o.md" && cp "$T/rm21-o.md" "$W/docs/rm21/roadmap.md"
g add -- docs && g commit -qm "g21 낡은 사본"
g checkout -q main
(cd "$W" && python3 "$RS" --json docs/rm21/roadmap.md > "$T/rm21.json")
assert_eq "$(stage "$T/rm21.json" F21)" "일부 머지 1/2" "수리 4: 결정 기록 머지 줄로 머지된 블록 브랜치도 머지로 세고 사본이 더한 브랜치는 남은 것으로 센다"
assert_contains "$(js "$T/rm21.json" "next(b['reason'] for b in r['blocks'] if b['id']=='F21')")" "feature/f21b — " "수리 4: 결정 기록 갈래에서도 남은 브랜치의 단계를 보인다"
assert_eq "$(stage "$T/rm21.json" G21)" "머지됨" "수리 4: 사본이 더한 이름의 브랜치가 이미 머지됐거나, 블록의 브랜치를 품지 않은 낡은 사본이면 세지 않는다"
assert_eq "$(js "$T/rm21.json" "next(b['branches'] for b in r['blocks'] if b['id']=='G21')")" "['feature/g21a']" "수리 4: 이미 머지된 이름은 branches 에 더하지 않는다"
assert_contains "$(notes "$T/rm21.json" H21)" "로드맵 사본 1개" "수리 4: 형식이 깨진 사본은 건너뛴 수를 정보로 밝힌다(조용히 건너뛰지 않는다)"
assert_eq "$(stage "$T/rm21.json" H21)" "머지됨" "수리 4: 깨진 사본만 있으면 판정은 머지됨 그대로"

# ── R8 AC1 — 상태 계산의 레포 설정은 해결자가 낸다: 기본 브랜치의 레포 설정 파일 · 출처 · 알림 ─────────
assert_eq "$(js "$T/rm21.json" "r['settings']['sources']['specs_dir']")" "기본값" "레포 설정 파일이 없으면 specs_dir 출처는 기본값"
assert_contains "$(js "$T/rm21.json" "' | '.join(r['settings']['notices'])")" "기계 상태 층 건너뜀" "보고 settings 에 해결자 알림(notices)이 실린다"
g checkout -q main
printf -- '---\nspecs_dir: docs/superpowers/specs/\n---\n' > "$W/.devbrew.md"
g add -- .devbrew.md && g commit -qm "레포 설정 파일" && g push -q origin main && g fetch -q origin
(cd "$W" && python3 "$RS" --json docs/rm21/roadmap.md > "$T/rm21-repo.json")
at="$(g rev-parse origin/HEAD | cut -c1-8)"
assert_eq "$(js "$T/rm21-repo.json" "r['settings']['sources']['specs_dir']")" "레포 설정@${at}" "레포 설정 파일이 기본 브랜치에 있으면 specs_dir 출처가 레포 설정@<커밋 8자>"
assert_eq "$(js "$T/rm21-repo.json" "r['settings']['sources']['test_command']")" "기본값" "레포 설정 파일에 없는 키는 기본값 그대로"
assert_eq "$(stage "$T/rm21-repo.json" F21)" "일부 머지 1/2" "레포 설정 파일이 같은 값이면 단계 판정은 그대로"

# ── R8 AC14 · AC15 — 머지됨은 PR 캐시(기계 상태 `## PR`)로 판정한다 ─────────────────────────────
g checkout -q main
sq() {  # sq <브랜치> — 브랜치를 기본 브랜치에 squash 로 머지한다(머지 커밋 없음)
  g checkout -q main && g merge -q --squash "$1" >/dev/null && g commit -qm "$1 (squash)"
}
# S30 — squash 머지, 브랜치는 남음 · 손 머지 줄 없음
g checkout -q -b feature/s30 main; commit_file src/s30.txt s "s30"; S30_TIP="$(g rev-parse HEAD)"; sq feature/s30; S30_MC="$(g rev-parse HEAD)"
# B30 — squash 머지 뒤 브랜치를 지움(캐시의 headRefOid 로 판정)
g checkout -q -b feature/b30 main; commit_file src/b30.txt b "b30"; B30_TIP="$(g rev-parse HEAD)"; sq feature/b30; B30_MC="$(g rev-parse HEAD)"; g branch -q -D feature/b30
# D30 — 내 PR 은 열림 · 같은 head 이름의 fork PR 이 머지됐고 기본 브랜치에 닿는다(캐시의 마지막 줄)
g checkout -q -b feature/d30 main; commit_file src/d30.txt d "d30"; D30_TIP="$(g rev-parse HEAD)"; sq feature/d30; D30_MC="$(g rev-parse HEAD)"
# K30 — 내 레포 PR 이 release 로 머지됨(기본 브랜치가 아닌 base)
g checkout -q -b feature/k30 main; commit_file src/k30.txt k "k30"; K30_TIP="$(g rev-parse HEAD)"; sq feature/k30; K30_MC="$(g rev-parse HEAD)"
# Y30 — squash 머지 뒤 로컬에만 커밋이 더 붙음(원격 끝은 머지한 끝)
g checkout -q -b feature/y30 main; commit_file src/y30.txt y "y30"; Y30_TIP="$(g rev-parse HEAD)"; g push -q origin feature/y30; sq feature/y30; Y30_MC="$(g rev-parse HEAD)"
g checkout -q feature/y30; commit_file src/y30.txt y2 "y30 더"
# N30 — gh 는 머지됐다는데 mergeCommit 을 아직 받지 않았다 → 받기 전 · 의존하는 O30 은 대기
g checkout -q -b feature/n30 main; commit_file src/n30.txt n "n30"; N30_TIP="$(g rev-parse HEAD)"; N30_MC="eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
# R30 — squash 머지 뒤 되돌림
g checkout -q -b feature/r30 main; commit_file src/r30.txt r "r30"; R30_TIP="$(g rev-parse HEAD)"; sq feature/r30; R30_MC="$(g rev-parse HEAD)"; g revert --no-edit "$R30_MC" >/dev/null; R30_REV="$(g rev-parse HEAD)"
# M30 — PR 캐시에 줄이 있는데 결정 기록에도 머지 줄이 있다(PR 은 열림 · 브랜치 지움)
g checkout -q -b feature/m30 main; commit_file src/m30.txt m "m30"; M30_TIP="$(g rev-parse HEAD)"; g checkout -q main; g branch -q -D feature/m30
# G30 — 캐시 줄 없음 · 남의 owner 머지 메시지 · 브랜치 지움 / H30 — 같은 꼴, 이 레포 owner(양의 짝)
g checkout -q -b feature/g30 main; commit_file src/g30.txt g "g30"; g checkout -q main
g merge -q --no-ff feature/g30 -m "Merge pull request #3 from other/feature/g30"; g branch -q -D feature/g30
g checkout -q -b feature/h30 main; commit_file src/h30.txt h "h30"; g checkout -q main
g merge -q --no-ff feature/h30 -m "Merge pull request #4 from o/feature/h30"; g branch -q -D feature/h30
g push -q origin main; g fetch -q origin
mkdir -p "$W/docs/rm30"
for b in S30 B30 D30 K30 Y30 N30 O30 R30 M30 G30 H30; do bundle docs/rm30 "$b" "C1, S1"; done
bundle docs/rm30 S30 "C1, D2, OQ1, RC1, ST1, «k1», K1, K2, S1, S2"
{ roadmap_head
  for b in S30 B30 D30 K30 Y30 N30 R30 M30 G30 H30; do block "$b" "feature/$(printf '%s' "$b" | tr 'A-Z' 'a-z')" 없음 없음; done
  block O30 feature/o30 N30 없음
  roadmap_tail "$(printf -- '- M30 · 머지 · 2026-10-20 · 「로컬에서 머지했다」')"
} > "$W/docs/rm30/roadmap.md"
MD30="$W/.claude/spec-distill/conductor/rm30"; mkdir -p "$MD30"
# 줄: 브랜치|번호|상태|headRefOid|교차 레포|baseRefName|mergeCommit — fork 줄은 그 브랜치의 마지막 줄이다
{ printf 'feature/s30|#31|머지됨|%s|아니오|main|%s\n' "$S30_TIP" "$S30_MC"
  printf 'feature/s30|#90|머지됨|%s|예|main|%s\n' "$S30_TIP" "$K30_MC"
  printf 'feature/b30|#32|머지됨|%s|아니오|main|%s\n' "$B30_TIP" "$B30_MC"
  printf 'feature/d30|#33|열림|%s|아니오|main|-\n' "$D30_TIP"
  printf 'feature/d30|#91|머지됨|%s|예|main|%s\n' "$D30_TIP" "$D30_MC"
  printf 'feature/k30|#34|머지됨|%s|아니오|release|%s\n' "$K30_TIP" "$K30_MC"
  printf 'feature/y30|#35|머지됨|%s|아니오|main|%s\n' "$Y30_TIP" "$Y30_MC"
  printf 'feature/n30|#36|머지됨|%s|아니오|main|%s\n' "$N30_TIP" "$N30_MC"
  printf 'feature/r30|#37|머지됨|%s|아니오|main|%s\n' "$R30_TIP" "$R30_MC"
  printf 'feature/m30|#38|열림|%s|아니오|main|-\n' "$M30_TIP"
} > "$T/rows30"
write_machine() {  # write_machine <machine.md> <로드맵 레포 상대경로> <줄 파일>
  python3 -I - "$S" "$1" "$2" "$3" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import conductor_state as cs
data = cs.empty()
for line in open(sys.argv[4], encoding="utf-8").read().splitlines():
    br, num, state, oid, cross, base, merge = line.split("|")
    data["PR"].append({"브랜치": br, "번호": num, "상태": state, "확인한 때": "2026-10-20 10:00", "headRefOid": oid,
                       "교차 레포": cross, "baseRefName": base, "mergeCommit": merge, "쓴 세션": "session-aaaa1111"})
open(sys.argv[2], "w", encoding="utf-8").write(cs.render_machine(sys.argv[3], data))
PY
}
write_machine "$MD30/machine.md" docs/rm30/roadmap.md "$T/rows30"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm30/roadmap.md > "$T/rm30.json"); rc=$?
reason() { js "$1" "next(b['reason'] for b in r['blocks'] if b['id']=='$2')"; }
assert_eq "$(stage "$T/rm30.json" S30)" "머지됨" "AC14: squash 머지(머지 커밋 없음) + PR 캐시 → 손 머지 줄 없이 머지됨"
assert_contains "$(reason "$T/rm30.json" S30)" "PR #31 머지됨(mergeCommit ${S30_MC:0:8})" "AC14: 근거는 내 레포 PR — 뒤에 적힌 같은 이름의 fork 줄(#90)이 아니다"
assert_not_contains "$(notes "$T/rm30.json" S30)" "PR 상태 미확인" "AC14: 캐시에 줄이 있으면 「PR 상태 미확인」 이 없다"
assert_eq "$(stage "$T/rm30.json" B30)" "머지됨" "AC15: 지운 브랜치는 캐시의 headRefOid 로 판정"
assert_contains "$(notes "$T/rm30.json" B30)" "브랜치 끝 없이 판정 — 캐시의 headRefOid ${B30_TIP:0:8}" "AC15: 지운 브랜치는 「브랜치 끝 없이 판정」 을 알린다"
assert_eq "$(stage "$T/rm30.json" D30)" "설계 중" "AC15: 같은 head 이름의 fork PR(마지막 줄 · 끝 같음 · 기본 브랜치에 닿음)은 머지됨을 정하지 않는다"
assert_eq "$(stage "$T/rm30.json" K30)" "설계 중" "AC15: 기본 브랜치가 아닌 base(release)로 머지된 PR 은 머지됨이 아니다"
assert_eq "$(stage "$T/rm30.json" Y30)" "설계 중" "AC15: 머지 뒤 로컬에만 커밋이 더 붙은 브랜치는 머지됨이 아니다"
assert_contains "$(notes "$T/rm30.json" Y30)" "로컬 끝 $(g rev-parse feature/y30 | cut -c1-8) · 원격 끝 ${Y30_TIP:0:8}" "로컬 · 원격 끝이 다르면 둘 다 보인다"
assert_eq "$(stage "$T/rm30.json" N30)" "설계 중" "AC14: 「머지됨(받기 전)」 은 단계가 아니다 — 단계는 그 전 계산대로"
assert_contains "$(warns "$T/rm30.json" N30)" "머지됨(받기 전) — git fetch 뒤 다시 계산한다(PR #36)" "AC14: 받기 전은 경고와 git fetch 안내"
assert_eq "$(stage "$T/rm30.json" O30)" "대기" "AC14: 「머지됨(받기 전)」 블록에 의존하는 블록은 대기(끝난 단계로 세지 않는다)"
assert_eq "$(stage "$T/rm30.json" R30)" "머지됨" "되돌림은 단계를 바꾸지 않는다"
assert_contains "$(warns "$T/rm30.json" R30)" "머지 뒤 되돌림 — ${R30_REV:0:8} 이 feature/r30 의 머지 커밋 ${R30_MC:0:8} 을 되돌렸다" "되돌림은 알린다"
assert_eq "$(stage "$T/rm30.json" M30)" "준비" "PR 캐시에 줄이 있으면 결정 기록의 머지 줄을 쓰지 않는다"
assert_contains "$(warns "$T/rm30.json" M30)" "결정 기록의 머지 줄을 feature/m30 에 적용하지 않았다 — PR 캐시에 그 브랜치의 PR 이 있어" "적용하지 않은 머지 줄은 경고로 밝힌다"
assert_eq "$(stage "$T/rm30.json" G30)" "준비" "캐시 없음: 남의 owner 머지 메시지(other/feature/g30)는 세지 않는다"
assert_contains "$(notes "$T/rm30.json" G30)" "PR 상태 미확인 — 지휘자를 돌려라(feature/g30)" "캐시 없음: 「PR 상태 미확인」"
assert_eq "$(stage "$T/rm30.json" H30)" "머지됨" "캐시 없음 양의 짝: 이 레포 owner 머지 메시지(o/feature/h30)는 센다"
assert_eq "$rc" "1" "PR 캐시 로드맵: 경고(받기 전 · 되돌림 · 머지 줄)만 있으면 rc 1"
# 변이 — 문면 길의 owner 비교를 지우면 G30 이 머지됨
sed 's/m and m.group(1).casefold() == origin_owner.casefold() and m.group(2) == branch:/m and m.group(2) == branch:/' "$RS" > "$M/roadmap_status.py"
cmp -s "$RS" "$M/roadmap_status.py" && no "변이 적용 안 됨(owner 비교)" || ok "변이 적용됨(owner 비교)"
(cd "$W" && python3 "$M/roadmap_status.py" --json --roadmap-file docs/rm30/roadmap.md > "$T/m30.json")
assert_eq "$(stage "$T/m30.json" G30)" "머지됨" "변이: owner 비교를 지우면 G30 이 머지됨 — G30 단언에 이빨이 있다"
# 지운 브랜치 · 같은 이름의 머지된 PR 둘(headRefOid 다름) → 셀 수 없음(검사 불가 rc 3)
mkdir -p "$W/docs/rm31"
bundle docs/rm31 B31 "C1, D2, OQ1, RC1, ST1, «k1», K1, K2, S1, S2"
{ roadmap_head; block B31 feature/b30 없음 없음; roadmap_tail ""; } > "$W/docs/rm31/roadmap.md"
MD31="$W/.claude/spec-distill/conductor/rm31"; mkdir -p "$MD31"
{ printf 'feature/b30|#12|머지됨|%s|아니오|main|%s\n' "$S30_TIP" "$S30_MC"; printf 'feature/b30|#32|머지됨|%s|아니오|main|%s\n' "$B30_TIP" "$B30_MC"; } > "$T/rows31"
write_machine "$MD31/machine.md" docs/rm31/roadmap.md "$T/rows31"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm31/roadmap.md > "$T/rm31.json"); rc=$?
assert_eq "$(stage "$T/rm31.json" B31)" "알 수 없음" "AC15: 지운 브랜치에 같은 이름의 머지된 PR 이 둘이면 머지됨이 아니라 셀 수 없음"
assert_contains "$(reason "$T/rm31.json" B31)" "셀 수 없음 — 같은 이름의 머지된 PR 이 여럿이고 브랜치 끝이 없다(#12 · #32)" "셀 수 없음의 사유"
assert_eq "$rc" "3" "셀 수 없음은 검사 불가(rc 3)"
# 기계 상태가 깨졌으면 캐시 없음으로 가고 사유를 싣는다
printf -- '---\ntype: conductor-machine\nroadmap: docs/rm31/roadmap.md\n---\n\n## PR\n\n- 깨진 줄\n' > "$MD31/machine.md"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm31/roadmap.md > "$T/rm31b.json")
assert_contains "$(notes "$T/rm31b.json" B31)" "PR 상태 미확인 — 지휘자를 돌려라(feature/b30 · 기계 상태를 읽지 못했다 — " "깨진 기계 상태: 캐시 없음으로 가고 사유를 알린다"
assert_eq "$(stage "$T/rm31b.json" B31)" "준비" "깨진 기계 상태: 캐시 없음 길(squash 는 머지됨이 아니다)"
# origin 소유자를 못 읽으면 문면 길을 세지 않고 사유를 싣는다
(cd "$W" && FAKE_ORIGIN_URL= python3 "$RS" --json --roadmap-file docs/rm30/roadmap.md > "$T/rm30-noowner.json")
assert_eq "$(stage "$T/rm30-noowner.json" H30)" "준비" "origin 소유자를 못 읽으면 머지 메시지 길을 세지 않는다"
assert_contains "$(notes "$T/rm30-noowner.json" H30)" "머지 메시지는 세지 않았다 — origin URL 에서 호스트 · owner · repo 를 뽑지 못했다" "origin 소유자를 못 읽은 사유를 싣는다"
assert_eq "$(stage "$T/rm30-noowner.json" S30)" "머지됨" "origin 소유자를 못 읽어도 PR 캐시 판정은 그대로"

nb="$(python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import roadmap_status as rs
b = "feature/h5a"
for t in ("feature/h5a를 머지", "feature/h5a. 끝", "feature/h5a.", "feature/h5a2", "https://x/feature/h5a", "origin/feature/h5a", "feature/h5a/sub", "-feature/h5a", "_feature/h5a", "Feature/H5A", "(feature/h5a)"): print(int(rs.names_branch(t, b)))' "$S")"
assert_eq "$(printf '%s' "$nb" | tr '\n' ' ')" "1 1 1 0 0 0 0 0 0 0 1" "이름 경계: 한글 조사 · 문장 부호 마침표는 경계, 숫자 · 경로 · 접두 · 대소문자 다름은 아니다"

finish
