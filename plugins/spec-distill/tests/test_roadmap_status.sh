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
spec_doc docs/rm/V1.md "C1 · S1" > "$W/docs/superpowers/specs/v1-design.md"
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
assert_eq "$(js "$OUT" "r['unassigned']")" "[]" "미배정 번호 0"
assert_eq "$(js "$OUT" "r['orphans']")" "[]" "고아 발화 0"
assert_eq "$(js "$OUT" "[o['blocks'] for o in r['overlaps']]")" "[['E1', 'W1']]" "겹침(정보): E1 ↔ W1 만(README 는 빼고, J1→W1 은 의존이 있어 뺀다)"
assert_eq "$(js "$OUT" "next(b['task_status'] for b in r['blocks'] if b['id']=='H1')")" "in_progress" "작업 목록 대응: 계획 → in_progress"
txt="$(cd "$W" && python3 "$RS" docs/rm/roadmap.md)"
assert_grep "$txt" "^로드맵 상태 — 블록 22개 · " "사람용 글 첫 줄이 상태"
assert_contains "$txt" "머지됨 자동 판정은 merge commit 방식에서만 된다" "한계 공시 줄"
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
assert_grep "$info_txt" "^로드맵 상태 — 블록 3개 · 경고 0개 · 정보 3개 · 검사 불가 0개 " "정보 로드맵 머리 줄: 정보 3개 = I1 위반 2 + 겹침 1(둘 다 센다)"

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

# ── 4. origin/main 없음 → 모든 블록 알 수 없음 · rc 3 ─────────────────────────
git clone -q "$T/origin.git" "$T/noorigin" 2>/dev/null
git -C "$T/noorigin" remote remove origin
(cd "$T/noorigin" && python3 "$RS" --json --roadmap-file docs/rm/roadmap.md > "$T/no.json"); rc=$?
assert_eq "$rc" "3" "origin/main 없음 → rc 3"
assert_eq "$(js "$T/no.json" "sorted({b['stage'] for b in r['blocks']})")" "['알 수 없음']" "모든 블록 알 수 없음"
(cd "$T/noorigin" && python3 "$RS" --json docs/rm/roadmap.md > "$T/no2.json"); rc=$?
assert_eq "$rc" "3" "origin/main 사본 모드에서 origin/main 없음 → rc 3"

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
PY="$(command -v python3)"
(cd "$W" && PATH=/nonexistent-dir "$PY" "$RS" --json docs/rm/roadmap.md > "$T/crash.json"); rc=$?
assert_eq "$rc" "3" "내부 오류(git 을 실행하지 못함) → rc 3"
assert_contains "$(js "$T/crash.json" "r['unknown_reasons']")" "내부 오류" "내부 오류가 검사 불가로 올라왔다"

# ── 5. 읽기 전용(AC7) — 정적 검사 + 실행 전후 비교, 각각 양성 대조 ──────────────
static_check() {  # static_check <파일...> — 쓰기 · 네트워크 · 허용 밖 git · 이름 import 를 찾으면 줄을 낸다. 끝에 CHECKED n.
  python3 - "$@" <<'PY'
import ast, sys
WRITE_ATTRS = {"write_text", "write_bytes", "unlink", "rmdir", "mkdir", "rename", "replace",
               "touch", "chmod", "remove", "makedirs", "rmtree", "symlink_to", "system", "popen"}
NET_MODS = {"socket", "urllib", "http", "requests", "ftplib", "smtplib", "shutil"}
READ_GIT = {"show", "rev-parse", "log", "diff", "merge-base", "cat-file", "grep"}
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
        if isinstance(node, ast.Call):
            f = node.func
            name = getattr(f, "attr", getattr(f, "id", ""))
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
out="$(static_check "$RS" "$S/check_bundle_coverage.py")"; rc=$?
assert_eq "$rc" "0" "정적 검사기가 죽지 않았다(rc 0)"
assert_eq "$(printf '%s\n' "$out" | grep -v '^CHECKED ')" "" "정적: 두 스크립트에 쓰기 · 네트워크 · git 밖 subprocess · 허용 밖 git · 이름 import 가 없다"
assert_eq "$(printf '%s\n' "$out" | grep '^CHECKED ')" "CHECKED 2" "정적 검사가 두 스크립트를 셌다"
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
printf 'from subprocess import run\n' > "$T/ctl_from.py"
assert_contains "$(static_check "$T/ctl_from.py")" "subprocess 를 이름으로 import" "양성 대조: from subprocess import 를 잡는다"
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
M="$T/mut"; mkdir -p "$M"; cp "$S/section6.py" "$S/check_bundle_coverage.py" "$M/"
sed 's/"log", "--first-parent", "--merges"/"log", "--merges"/' "$RS" > "$M/roadmap_status.py"
cmp -s "$RS" "$M/roadmap_status.py" && no "변이 적용 안 됨(--first-parent)" || ok "변이 적용됨(--first-parent)"
(cd "$W" && python3 "$M/roadmap_status.py" --json docs/rm/roadmap.md > "$T/mfp.json")
assert_eq "$(stage "$T/mfp.json" U1)" "머지됨" "변이: --first-parent 를 빼면 U1 이 머지됨 — 위 U1 단언에 이빨이 있다"
sed 's/if m and m.group(1) == branch:/if m and m.group(1).startswith(branch):/' "$RS" > "$M/roadmap_status.py"
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

# ── 7. 실데이터 — 이번 일의 로드맵 · 묶음(R0 AC1 · AC2 · AC3) ─────────────────
# git 없이 함수로 잰다 — origin 이 없는 클론에서도 같은 판정이 나야 한다.
real_check() {  # real_check <리포 루트> — 키<TAB>값 줄들
  (cd "$S" && python3 - "$1" <<'PY'
import re, sys
from pathlib import Path
import check_bundle_coverage as cbc, roadmap_status as rs, section6
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
    if mine.splitlines() != ["- 의도: " + b["fields"]["의도"], "- 범위: " + b["fields"]["범위"]]:
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
assert_eq "$(field_of BLOCKS)" "P1:branch P2:branch P3:decision P4:decision R0:branch R1:bundle R2:bundle R7:bundle R3:bundle R4:bundle R6:bundle R2a:bundle R5:bundle R8:bundle R9:bundle" "실데이터 AC1: 블록 15개와 종류"
assert_eq "$(field_of RISK)" "True" "실데이터: 위험 번호표 K1~K15 가 brief §5 원문과 같다"
assert_eq "$(field_of BAD)" "[]" "실데이터 AC2: 묶음 10개의 frontmatter · 절 · §6 · 공통 목표 · 의도 · 범위가 바이트 그대로"
assert_eq "$(field_of UNASSIGNED)" "[]" "실데이터 AC3: 미배정 번호 0"
assert_eq "$(field_of ORPHANS)" "[]" "실데이터 AC3: 고아 발화 0"
assert_eq "$(field_of UNKNOWN)" "[]" "실데이터: brief 에 없는 번호 0"
assert_eq "$(field_of OVERLAPS)" "[{'blocks': ['R2', 'R3'], 'paths': ['plugins/spec-distill/references/docreview-profiles/design-doc.md']}]" "실데이터: 의존 없이 겹치는 경로 예약은 정보 하나 — R2 ↔ R3 의 design-doc.md(병렬 유지, 충돌은 머지 때 푼다)"
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

finish
