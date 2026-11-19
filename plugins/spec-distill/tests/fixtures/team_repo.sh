#!/usr/bin/env bash
# 팀 로드맵 셸 테스트가 함께 source 하는 팀 레포 만들기. 부르는 쪽이 ROOT · T 를 정하고 shared/tests/assert.sh 를 먼저 source 한다.
# source 하면 S · RW · RS · W · g · js · status · put · decide · sync 와 사람 줄 도우미(SID · SID2 · CL · SFX · led · claim ·
# answer · human · approved)와 시작 묶음 도우미(bundle · refused · check · finish_attempt · write_line · use_repo · new_repo)가 생기고, team_repo 를 부르면 W 에 레포가 선다.
export PYTHONDONTWRITEBYTECODE=1 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
S="$ROOT/plugins/spec-distill/scripts"
RW="$S/roadmap_write.py"
RS="$S/roadmap_status.py"
W="$T/repo"
SID="00000000-0000-4000-8000-00000000c0de"          # 지휘 표지를 쥔 가짜 세션
SID2="00000000-0000-4000-8000-00000000c0df"         # 그 세션을 이어받은 가짜 세션
export CLAUDE_CONFIG_DIR="$T/claude"                  # 세션 기록 자리 — 실제 설정 폴더를 읽지 않는다
export TZ=UTC                                         # 사람 줄의 날짜는 답한 시각의 지역 날짜다 — 테스트는 UTC 로 고정한다
CL="$S/conductor_ledger.py"
SFX="$ROOT/plugins/spec-distill/tests/fixtures/session_fixture.py"

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

led() { (cd "$W" && python3 "$CL" "$@") > "$T/led.txt" 2>&1; echo $?; }   # 지휘 원장 명령 — rc 를 echo, 출력은 $T/led.txt
claim() { [ "$(led claim --roadmap "$RM" --session "$SID")" = "0" ]; }
answer() {  # answer <질문 글> <고른 글> [session_fixture answer 의 나머지 인자…] — 지휘 세션 기록에 질문 창 답 하나를 덧붙인다. 답 항목의 uuid 는 $T/entry.txt
  local q="$1" a="$2"; shift 2
  python3 "$SFX" answer --config "$CLAUDE_CONFIG_DIR" --session "$SID" --question "$q" --label "$a" "$@" > "$T/entry.txt"
}
human() {  # human <종류> <과제> [계획|-] [관문 이름|-] [날짜] — 머리를 받아 통과 라벨로 답한 기록을 짓고 줄을 적는다. 날짜를 주면 그날 낮 12시(UTC)에 답한 것으로 짓는다. rc 를 echo(커밋은 부르는 쪽)
  # 관문 이름에 계획 번호가 있으면 --plan 으로도 넘긴다 — 그 계획의 브랜치에 쓴다(J7). 머리는 ask-head 의 표준 출력에서만 받는다.
  local kind="$1" job="$2" plan="${3:--}" gate="${4:--}" date="${5:-}" label head q rc
  case "$kind" in
    "spec 승인") label="승인 — 계획 담당자에게 (권장)" ;;
    "계획 검토") label="계획대로 구현한다" ;;
    "흐름 승인") label="설계 없이 진행" ;;
    *) case "$gate" in "다시 시도"*) label="다시 시도한다" ;; *) label="건너뛴다" ;; esac ;;
  esac
  if [ "$plan" = "-" ] && [ "$gate" != "-" ]; then
    plan="$(printf '%s\n' "$gate" | sed -n 's/.* plan \([1-9][0-9]*\).*/\1/p')"
    [ -n "$plan" ] || plan="-"
  fi
  set -- --human "$kind" --roadmap "$RM" --job "$job"
  [ "$plan" = "-" ] || set -- "$@" --plan "$plan"
  head="$(cd "$W" && python3 "$CL" ask-head "$@" 2> "$T/led.txt")"; rc=$?
  if [ "$rc" != "0" ]; then echo "ask-head 실패(rc ${rc}) — ${head} $(cat "$T/led.txt")" >&2; echo 1; return; fi
  if [ "$gate" = "-" ]; then q="${head} — 자리표시 질문"; else q="${head} — ${gate} 자리표시 질문"; set -- "$@" --gate "$gate"; fi
  if [ -n "$date" ]; then answer "$q" "$label" --when "${date}T12:00:00.000Z"; else answer "$q" "$label"; fi
  led record "$@"
}
approved() {  # approved <human 의 인자…> — 줄을 적고 그 과제의 INTENT.md 를 커밋한다
  [ "$(human "$@")" = "0" ] && g add -- "$TM/jobs/$2/INTENT.md" && g commit -qm "$1 — $2"
}

bundle() {  # bundle <start_bundle 인자…> — W 에서 과제 시작 묶음을 불러 rc 를 echo 한다. 출력은 $T/b.txt · 표준 오류는 $T/b.err
  (cd "$W" && python3 "$S/start_bundle.py" --roadmap "$RM" "$@") > "$T/b.txt" 2> "$T/b.err"; echo $?
}
refused() { [ "$(bundle "$@")" = "1" ] && [ ! -s "$T/b.txt" ]; }   # 멈춤(1)이고 표준 출력이 빈다
check() {  # check <기대 rc> <메시지> <bundle 인자…> — rc 를 재고, 0 이 아니면 표준 출력이 빈 것도 잰다
  local want="$1" msg="$2"; shift 2
  assert_eq "$(bundle "$@")" "$want" "$msg"
  [ "$want" = "0" ] || assert_eq "$(wc -c < "$T/b.txt" | tr -d ' ')" "0" "$msg — 표준 출력이 비었다"
}
finish_attempt() {  # finish_attempt <k> [AC 줄] — E1 의 implement 계획 1 시도 k: 묶음의 맞추는 명령 줄 그대로 결과 파일을 만들고, 준 줄을 넣고, 끝 줄을 적어 올린다(feature/tm-e1)
  local k="$1" ac="${2:-}" cmd code E1="$TM/jobs/E1"
  g checkout -q feature/tm-e1
  [ "$(bundle --job E1 --stage implement --plan 1)" = "0" ] || { echo "finish_attempt ${k}: 묶음이 나가지 않았다 — $(cat "$T/b.err")" >&2; return 1; }
  cmd="$(grep '^맞추는 명령: ' "$T/b.txt")"
  (cd "$W" && bash -c "${cmd#맞추는 명령: }") > "$T/out.txt" 2>&1 || { echo "finish_attempt ${k}: 맞추기 실패 — $(cat "$T/out.txt")" >&2; return 1; }
  put "src/e1/a${k}.txt" "시도 ${k}" && g commit -qm "시도 ${k} 코드" && code="$(g rev-parse HEAD)"
  [ -z "$ac" ] || printf '%s\n' "$ac" >> "$W/$E1/results/implement-plan-1-${k}.md"
  [ "$(sync E1 "implement-plan-1-${k}.md" --end "$code")" = "0" ] || { echo "finish_attempt ${k}: 끝 줄 실패 — $(cat "$T/out.txt")" >&2; return 1; }
  g add -- "$E1" && g commit -qm "결과 ${k}" && g push -q origin feature/tm-e1 && g fetch -q origin
}
write_line() { sed -n 's/^쓸 것: //p' "$T/b.txt"; }   # 마지막 bundle 이 낸 쓸 것 줄의 경로

use_repo() {  # use_repo <폴더> — 그 폴더에 선 팀 레포를 쓰도록 T · W · CLAUDE_CONFIG_DIR 를 옮긴다
  T="$1"; W="$T/repo"; CLAUDE_CONFIG_DIR="$T/claude"; export CLAUDE_CONFIG_DIR
}
new_repo() {  # new_repo <새 폴더> — 새 팀 레포를 세우고 공통 문서를 기본 브랜치에 올리고 지휘 표지를 쥔다. use_repo 도 한다
  mkdir -p "$1" || return 1
  use_repo "$1"
  team_repo || return 1
  g add -- "${RD}leader" "${RD}designer" "${RD}writer" "${RD}worker" "${RD}HANDBOOK.md" && g commit -qm "공통 문서" \
    && g push -q origin main && g fetch -q origin && claim
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
