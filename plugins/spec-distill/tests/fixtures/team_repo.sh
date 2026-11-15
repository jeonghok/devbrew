#!/usr/bin/env bash
# 팀 로드맵 셸 테스트가 함께 source 하는 팀 레포 만들기. 부르는 쪽이 ROOT · T 를 정하고 shared/tests/assert.sh 를 먼저 source 한다.
# source 하면 S · RW · RS · W · g · js · status · put · decide · sync 가 생기고, team_repo 를 부르면 W 에 레포가 선다.
export PYTHONDONTWRITEBYTECODE=1 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
S="$ROOT/plugins/spec-distill/scripts"
RW="$S/roadmap_write.py"
RS="$S/roadmap_status.py"
W="$T/repo"

g() { git -C "$W" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false -c init.defaultBranch=main "$@"; }
# js <json 파일> <파이썬 식 — r 이 보고서>. 식은 부르는 테스트가 쓴 고정 문자열뿐이다.
js() { python3 -c 'import json,sys; r=json.load(open(sys.argv[1], encoding="utf-8")); print(eval(sys.argv[2]))' "$1" "$2"; }
status() {  # status <json 파일> [인자…] — 팀 로드맵의 현황을 파일에 쓰고 rc 를 echo 한다. 기본 브랜치 · 브랜치 끝을 읽으니 커밋 · push 뒤에 부른다
  local out="$1"; shift
  local rc=0
  (cd "$W" && python3 "$RS" "$RM" --json "$@") > "$out" 2>/dev/null || rc=$?
  echo "$rc"
}
put() {  # put <레포 상대 경로> <글> — 쓰고 add 한다
  mkdir -p "$(dirname "$W/$1")"
  printf '%s\n' "$2" > "$W/$1"
  g add -- "$1"
}
decide() {  # decide <과제> <줄> — 그 과제 INTENT.md 의 결정 기록에 한 줄을 더한다
  python3 - "$S" "$W/$TM/jobs/$1/INTENT.md" "$2" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import team_files
path, line = sys.argv[2], sys.argv[3]
text = open(path, encoding="utf-8", newline="").read()
open(path, "w", encoding="utf-8", newline="").write(team_files.append_decision(text, line))
PY
}
sync() {  # sync <과제> <결과 파일 이름> <job sync 인자…> — 그 과제 결과 폴더의 그 이름으로 job sync 를 부르고 rc 를 echo 한다. 출력은 $T/out.txt
  local job="$1" name="$2"; shift 2
  (cd "$W" && python3 "$RW" job sync --result "$TM/jobs/${job}/results/${name}" "$@") > "$T/out.txt" 2>&1
  echo $?
}

team_repo() {
  mkdir -p "$W/docs/tv"
  cat > "$W/docs/tv/brief.md" <<'MD'
---
type: interview-brief
user_sourced_items:
  - id: C1
    statement: "읽기 쪽 첫 확정"
  - id: D2
    statement: "읽기 쪽 둘째 결정"
  - id: C3
    statement: "읽기 쪽 셋째 확정"
---

# 팀 읽기 픽스처 brief

## 0. 한눈에

**결정 목록**

- OQ1 [열림] — 읽기 쪽 열린 물음

## 1. Goal · Non-goal

- Goal: 결과 파일을 읽는다.
- Non-goal: 결과 파일을 새로 설계한다.

## 2. 제약

- 🗣 confirmed **C1** — 읽기 쪽 첫 확정 ⟨S1⟩
- ☑ confirmed **D2** — 읽기 쪽 둘째 결정 ⟨S2⟩
- 🗣 confirmed **C3** — 읽기 쪽 셋째 확정 ⟨S1⟩

## 3. Open Questions

- OQ1: 읽기 쪽 열린 물음

## 4. External Landscape

- 없음

## 5. 기각 · Blind Spots

- 없음

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > 결과를 파일로 받아 읽자
- **S2** 🗣 발화 (round 1):
  > 단계는 파일로 센다
- **S3** ☑ 선택 (round 2):
  > 대조는 커밋으로 한다
- **S4** 🗣 발화 (round 3):
  > 막히면 막힘 파일을 둔다

## 7. Next Action

읽기 쪽을 만든다.
MD
  cat > "$W/docs/tv/brief.audit.md" <<'MD'
# 읽기 픽스처 audit

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > 결과를 파일로 받아 읽자
- **S2** 🗣 발화 (round 1):
  > 단계는 파일로 센다
- **S3** ☑ 선택 (round 2):
  > 대조는 커밋으로 한다
- **S4** 🗣 발화 (round 3):
  > 막히면 막힘 파일을 둔다

## 7. 원자료

- 없음
MD
  git init -q --bare -b main "$T/origin.git"
  git init -q -b main "$W"
  g remote add origin "$T/origin.git"
  g add -- docs && g commit -qm "읽기 brief" && g push -q origin main && g fetch -q origin
  g remote set-head origin main
  RD="$(cd "$W" && python3 "$S/repo_defaults.py" get roadmaps_dir 2>/dev/null)"
  TM="${RD}tm"
  RM="$TM/roadmap.md"
  (cd "$W" && python3 "$RW" original --brief docs/tv/brief.md --out "$TM") > "$T/out.txt" 2>&1 || return 1
  g add -- "$TM" && g commit -qm "원자료 사본"
  local head='| 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 | 지시 원문 범위 |'
  {
    printf '# 읽기 픽스처 분해\n\n## 분해안\n\n%s\n|---|---|---|---|---|---|---|---|---|---|---|---|\n' "$head"
    printf '%s\n' \
      '| P1 | 읽는 법 정하기 | 결정 | 읽는 법을 정한다 | 한다 정함 / 안 한다 구현 | 없음 | 없음 | 없음 | S3 · OQ1 | 없음 | 없음 | 없음 |' \
      '| E1 | 첫 읽기 | 묶음 | 첫 읽기를 만든다 | 한다 읽기 / 안 한다 쓰기 | 없음 | feature/tm-e1, feature/tm-e1b | src/e1/ | C1 · S1 | 없음 | E3 에 읽기 | 2–4 |' \
      '| E2 | 조사 하나 | 묶음 | 표로 정리한다 | 한다 표 / 안 한다 코드 | 없음 | feature/tm-e2 | src/e2/ | D2 · S2 | 없음 | 없음 | 5–7 |' \
      '| E3 | 이어 읽기 | 묶음 | 첫 읽기 위에 얹는다 | 한다 얹기 / 안 한다 고치기 | E1 | feature/tm-e3 | src/e3/ | C3 · S1 · S4 | E1 의 읽기 | 없음 | 2–4 |'
  } > "$T/tm-table.md"
  (cd "$W" && python3 "$RW" create --layout team --brief docs/tv/brief.md --audit docs/tv/brief.audit.md \
     --plan-table "$T/tm-table.md" --out "$TM" --title "읽기 픽스처" --date 2026-11-14 --approval "이대로 승인") > "$T/out.txt" 2>&1 || return 1
  python3 - "$W/$RM" "$TM" <<'PY'
import sys
path, tm = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
at = text.index("### E2")
end = text.index("\n- 의도:", at)
line_end = text.index("\n", end + 1)
extra = "\n- 흐름: 조사 — 파일을 읽어 표로 낸다\n- 산출물: %s/jobs/E2/survey.md" % tm
open(path, "w", encoding="utf-8").write(text[:line_end] + extra + text[line_end:])
PY
  g add -- "$TM" && g commit -qm "팀 tm" && g push -q origin main && g fetch -q origin
  g remote set-head origin main
}
