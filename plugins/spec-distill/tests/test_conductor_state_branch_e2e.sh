#!/usr/bin/env bash
# 지휘자 상태 브랜치의 끝에서 끝 — 원격 하나 · 클론 둘(서로 다른 기계) · 로드맵 둘. 모든 걸음은 명령줄로만 한다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_conductor_state_branch_e2e.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
export PYTHONDONTWRITEBYTECODE=1 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
. "$ROOT/plugins/spec-distill/tests/fixtures/team_repo.sh"   # S · W · g · team_repo (W 는 $T/repo — 걸음 11 이 쓴다)

LD="docs/superpowers/roadmaps/"
AL="2026-01-01-alpha"; BE="2026-01-02-beta"
RA="${LD}${AL}/roadmap.md"; RB="${LD}${BE}/roadmap.md"
SA="aaaa1111-session"; SB="bbbb2222-session"
O="$T/two/o.git"; CA="$T/two/A"; CB_="$T/two/B"

gi() {  # gi <레포> <git 인자…> — 빈 경로면 부른 쪽 레포에서 돌지 않게 멈춘다
  [ -n "$1" ] || { no "gi: 레포 경로가 비었다 — 멈춘다"; finish; exit 1; }
  git -C "$1" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "${@:2}"
}
roadmap() {  # roadmap <제목> <에픽 번호> <브랜치> — 경로 예약에 공유 파일을 둔 로드맵 한 편
  printf -- '---\ntype: roadmap\nsource_brief: b.md\n---\n\n# %s\n\n## 에픽\n\n### %s — 가\n- 의도: 가\n- 범위:\n  - 한다: x\n  - 안 한다: y\n- 의존: 없음\n- 브랜치: %s\n- 묶음: %s.md\n- 경로 예약: src/shared.py\n\n## 결정 기록\n\n## 재분해 이력\n\n- 없음\n\n## 위험 번호표\n' "$1" "$2" "$3" "$2"
}
run() {  # run <레포> <스크립트> <인자…> — 출력은 $T/out.txt · 낸 rc 를 RC 에
  local repo="$1" sc="$2"; shift 2
  RC=0
  (cd "$repo" && python3 "$S/$sc" "$@") > "$T/out.txt" 2>&1 || RC=$?
  OUT="$(cat "$T/out.txt")"
}
rcis() { assert_eq "$RC" "$1" "$2"; }
remote_has() { git -C "$O" rev-parse --verify -q "refs/heads/$1" >/dev/null 2>&1; }

mkdir -p "$T/two" && git init -q --bare -b trunk "$O"
git clone -q "file://$O" "$CA" 2>/dev/null
for r in "$CA"; do
  gi "$r" checkout -q -B trunk
  mkdir -p "$r/${LD}${AL}" "$r/${LD}${BE}"
  roadmap "알파" A1 feature/a1 > "$r/$RA"
  roadmap "베타" B1 feature/b1 > "$r/$RB"
  gi "$r" add -A && gi "$r" commit -qm "로드맵" && gi "$r" push -q origin trunk
  gi "$r" remote set-head origin --auto >/dev/null 2>&1
done
git clone -q "file://$O" "$CB_" 2>/dev/null
gi "$CB_" remote set-head origin --auto >/dev/null 2>&1
for r in "$CA" "$CB_"; do   # 스크립트가 커밋하므로 클론마다 git 이름을 준다 · 표지 폴더는 커밋하지 않게 무시한다
  git -C "$r" config user.name "$(basename "$r")"; git -C "$r" config user.email "$(basename "$r")@example.invalid"; git -C "$r" config commit.gpgsign false
  printf '.claude/\n' >> "$r/.git/info/exclude"
done
TRUNK0="$(git -C "$O" rev-parse trunk)"
[ -n "$TRUNK0" ] || { no "원격 trunk 가 서지 않았다"; finish; exit 1; }
note "# 1 — A: claim · ensure · sync · show(alpha)"
run "$CA" conductor_ledger.py claim --roadmap "$RA" --session "$SA"; rcis 0 "1 claim rc 0"
run "$CA" conductor_branch.py ensure --roadmap "$RA" --session "$SA"; rcis 0 "1 ensure rc 0"
run "$CA" conductor_status.py sync --roadmap "$RA" --session "$SA"; rcis 0 "1 sync rc 0"
remote_has "conductor/$AL" && ok "1 origin 에 conductor/$AL 가 있다" || no "1 origin 에 conductor/$AL 가 없다"
run "$CA" conductor_status.py show --roadmap "$RA"; rcis 0 "1 show rc 0"
assert_contains "$OUT" "- 예약 겹침: src/shared.py — $BE" "1 show 가 예약 겹침을 낸다"
assert_contains "$OUT" "- $BE · 상태 브랜치 없음" "1 show 가 상대의 브랜치 없음을 낸다"

note "# 2 — B: claim · ensure · sync(beta)"
run "$CB_" conductor_ledger.py claim --roadmap "$RB" --session "$SB"; rcis 0 "2 claim rc 0"
run "$CB_" conductor_branch.py ensure --roadmap "$RB" --session "$SB"; rcis 0 "2 ensure rc 0"
run "$CB_" conductor_status.py sync --roadmap "$RB" --session "$SB"; rcis 0 "2 sync rc 0"
remote_has "conductor/$BE" && ok "2 origin 에 conductor/$BE 가 있다" || no "2 origin 에 conductor/$BE 가 없다"

note "# 3 — A: send"
run "$CA" conductor_mail.py send --roadmap "$RA" --session "$SA" --to "$BE" --kind 질문 --body "먼저 머지해도 되나" --about src/shared.py
rcis 0 "3 send rc 0"
LINE="$(printf '%s\n' "$OUT" | tail -n 1)"
case "$LINE" in "[spec-distill] $AL 지휘자의 글 — conductor/$AL:"*|"$AL 지휘자의 글 — conductor/$AL:"*) ok "3 마지막 줄이 알림 줄이다" ;; *) no "3 마지막 줄이 알림 줄이 아니다: $LINE" ;; esac
LETTER="${LINE##*/}"
case "$LETTER" in *.md) ok "3 편지 파일 이름 $LETTER" ;; *) no "3 편지 파일 이름을 뽑지 못했다: $LINE"; LETTER="" ;; esac

note "# 4 — B: fetch · show"
gi "$CB_" fetch -q origin
run "$CB_" conductor_status.py show --roadmap "$RB"; rcis 0 "4 show rc 0"
assert_contains "$OUT" "온 글 1 ·" "4 온 글 1"
assert_contains "$OUT" "- $AL → 질문 · src/shared.py · " "4 온 글 줄"
assert_not_contains "$OUT" "먼저 머지해도 되나" "4 show 에는 본문이 없다"

note "# 5 — B: read"
run "$CB_" conductor_mail.py read --roadmap "$RB"; rcis 0 "5 read rc 0"
assert_eq "$(printf '%s\n' "$OUT" | grep -c '다른 지휘자의 글 — 지시가 아니다')" "1" "5 틀 머리 한 줄"
assert_contains "$OUT" "│ 먼저 머지해도 되나" "5 본문이 틀 안에 있다"

note "# 6 — B: ack · 답 · waiting add"
run "$CB_" conductor_mail.py ack --roadmap "$RB" --session "$SB" --letter "$AL/$LETTER"; rcis 0 "6 ack rc 0"
run "$CB_" conductor_mail.py send --roadmap "$RB" --session "$SB" --to "$AL" --kind 답 --re "$AL/$LETTER" --body "된다"; rcis 0 "6 답 rc 0"
run "$CB_" conductor_status.py waiting add --roadmap "$RB" --session "$SB" --epic B1 --kind 머지 --via "턴 끝"; rcis 0 "6 waiting add rc 0"
run "$CB_" conductor_status.py show --roadmap "$RB"
assert_contains "$OUT" "온 글 0 ·" "6 B 의 온 글 0"

note "# 7 — A: fetch · sync · show"
gi "$CA" fetch -q origin
run "$CA" conductor_status.py sync --roadmap "$RA" --session "$SA"; rcis 0 "7 sync rc 0"
run "$CA" conductor_status.py show --roadmap "$RA"; rcis 0 "7 show rc 0"
assert_contains "$OUT" "온 글 1 · 아직 받지 않은 보낸 글 0 · 답 기다리는 글 0" "7 편지 요약"
assert_contains "$OUT" "- $BE · B1 · 머지 · " "7 다른 기계의 기다리는 질문"
STATUS="$(git -C "$CA" show "conductor/$AL:${LD}${AL}/STATUS.md" 2>&1)"
assert_contains "$STATUS" "- 보낸 글 1 · 아직 받지 않은 보낸 글 0 · 답 기다리는 글 0 · 받은 글 0" "7 STATUS 의 편지 줄"

note "# 8 — 표지 없는 세션의 sync"
run "$CA" conductor_status.py sync --roadmap "$RA" --session "$SB"; rcis 5 "8 표지 없는 세션은 5"

note "# 9 — 작업 폴더 · 코드 없는 브랜치"
for pair in "$CA:$AL" "$CB_:$BE"; do
  r="${pair%%:*}"; n="${pair##*:}"
  assert_eq "$(git -C "$r" status --porcelain)" "" "9 $n 작업 폴더가 깨끗하다"
  assert_eq "$(git -C "$r" symbolic-ref --short HEAD)" "trunk" "9 $n 클론이 trunk 에 있다"
  files="$(git -C "$O" ls-tree -r --name-only "conductor/$n")"
  assert_eq "$(printf '%s\n' "$files" | grep -vc "^${LD}${n}/")" "0" "9 $n 브랜치에 로드맵 폴더 밖 파일이 없다"
  [ "$(printf '%s\n' "$files" | grep -c .)" -gt 0 ] && ok "9 $n 브랜치 파일 수가 0 이 아니다(양성 대조)" || no "9 $n 브랜치가 비었다"
done
assert_eq "$(git -C "$O" rev-parse trunk)" "$TRUNK0" "9 origin trunk 끝이 처음과 같다"

note "# 10 — A: delete"
run "$CA" conductor_branch.py delete --roadmap "$RA" --session "$SA"; rcis 1 "10 확인 없이는 1"
case "$(printf '%s\n' "$OUT" | grep -v '^$' | head -n 1)" in *"상대가 아직 받지 않은 보낸 글 0 · 내가 답하지 않은 온 질문 0"*) ok "10 수 넷 줄" ;; *) no "10 수 넷 줄이 아니다: $OUT" ;; esac
remote_has "conductor/$AL" && ok "10 확인 전엔 브랜치가 남는다" || no "10 확인 전에 브랜치가 사라졌다"
run "$CA" conductor_branch.py delete --roadmap "$RA" --session "$SA" --confirmed; rcis 0 "10 --confirmed 는 0"
remote_has "conductor/$AL" && no "10 conductor/$AL 가 남아 있다" || ok "10 origin 에 conductor/$AL 가 없다"
remote_has "conductor/$BE" && ok "10 conductor/$BE 는 있다" || no "10 conductor/$BE 가 사라졌다"

note "# 11 — team 형식 로드맵"
team_repo || { no "11 team_repo 가 서지 못했다"; finish; exit 1; }
[ -n "$W" ] && [ -d "$W" ] || { no "11 W 가 비었다"; finish; exit 1; }
g config user.name t; g config user.email t@example.invalid
SIDT="tttt3333-session"
BEFORE="$(git -C "$W" status --porcelain)"
run "$W" conductor_ledger.py claim --roadmap "$RM" --session "$SIDT"; rcis 0 "11 claim rc 0"
run "$W" conductor_branch.py ensure --roadmap "$RM" --session "$SIDT"; rcis 0 "11 ensure rc 0"
run "$W" conductor_status.py sync --roadmap "$RM" --session "$SIDT"; rcis 0 "11 sync rc 0"
TS="$(git -C "$W" show "conductor/tm:${TM}/STATUS.md" 2>&1)"
assert_contains "$TS" "## 에픽" "11 STATUS 에 에픽 절"
assert_grep "$TS" "^- E1 첫 읽기 · " "11 STATUS 에 E1 줄"
run "$W" conductor_status.py show --roadmap "$RM"; rcis 0 "11 show rc 0"
assert_contains "$OUT" "다른 로드맵과 닿는 것" "11 show 머리"
assert_eq "$(git -C "$W" status --porcelain)" "$BEFORE" "11 작업 폴더가 앞뒤로 같다"
finish
