#!/usr/bin/env bash
# control_plane.py — 캐시 · 받은 시각 · 끄기 스위치 · 읽기 전용 · 작업 목록 rc 를 버릴 git 저장소에서 잰다
# (R6 AC3 · AC4 · AC5 · AC6 · AC7 · AC11 · AC13). 상태 계산은 대역으로 바꿔 호출 수를 센다 — 대역은
# 부를 때마다 calls.log 에 인자를 적는다. 끝에서 진짜 상태 계산으로 인자 계약을 한 번 잰다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_control_plane.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset DEVBREW_SPEC_DISTILL_DISABLE DEVBREW_SKIP_HOOKS CLAUDE_CONFIG_DIR
REAL="$ROOT/plugins/spec-distill/scripts"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
W="$T/work"; U="$T/up"; S="$T/scripts"; LOG="$S/calls.log"; CACHE="$W/.git/devbrew/control-plane.json"
RM="docs/superpowers/roadmaps/rm/roadmap.md"
g() { git -C "$W" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }
u() { git -C "$U" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }
push_file() {  # push_file <경로> <내용> — 다른 사본(U)이 main 에 올리고 W 는 받기만 한다 — W 의 로컬 브랜치는 그대로다
  mkdir -p "$(dirname "$U/$1")" && printf '%s\n' "$2" > "$U/$1" && u add -- "$1" && u commit -qm "$1" \
    && u push -q origin main && g fetch -q origin
}
calls() { if [ -f "$LOG" ]; then wc -l < "$LOG" | tr -d ' '; else echo 0; fi; }
sl()   { (cd "$W" && python3 "$S/control_plane.py" statusline </dev/null); }
show() { (cd "$W" && python3 "$S/control_plane.py" show "$@" </dev/null); }
age()  { python3 -I -c 'import os,sys,time; t=time.time()-int(sys.argv[2]); os.utime(sys.argv[1],(t,t))' "$1" "$2"; }

# ── 픽스처 ────────────────────────────────────────────────────────────────────
git init -q --bare -b main "$T/origin.git"
git clone -q "$T/origin.git" "$U" 2>/dev/null
printf 'x\n' > "$U/README.txt" && u add README.txt && u commit -qm init && u push -q -u origin main
git clone -q "$T/origin.git" "$W" 2>/dev/null
push_file "$RM" "로드맵"
mkdir -p "$S"
cp "$REAL/control_plane.py" "$REAL/kill_switch_active.py" "$S/"
cat > "$S/roadmap_status.py" <<'PY'
#!/usr/bin/env python3
"""테스트 대역 — 부를 때마다 calls.log 에 인자를 적고 stub-<로드맵 폴더>.json(없으면 report.json)을 낸다."""
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))


def render(report):
    return "대역 첫 줄 — 블록 %d개" % len(report.get("blocks") or [])


if __name__ == "__main__":
    with open(os.path.join(HERE, "calls.log"), "a", encoding="utf-8") as fh:
        fh.write(" ".join(sys.argv[1:]) + "\n")
    if os.path.exists(os.path.join(HERE, "hang.flag")):
        time.sleep(30)
    if os.path.exists(os.path.join(HERE, "garbage.flag")):
        print("상태 계산이 깨졌다")
        sys.exit(2)
    parts = sys.argv[1].split("/")
    path = os.path.join(HERE, "stub-%s.json" % (parts[-2] if len(parts) > 1 else ""))
    if not os.path.exists(path):
        path = os.path.join(HERE, "report.json")
    with open(path, encoding="utf-8") as fh:
        report = json.load(fh)
    print(json.dumps(report, ensure_ascii=False))
    sys.exit(report["exit"])
PY
cat > "$S/report.json" <<'JSON'
{"roadmap": "r", "source": "origin/main", "fetched_at": null, "notice": "", "overlaps": [],
 "unassigned": [], "orphans": ["S9"], "unknown_ids": [], "format_errors": [], "unknown_reasons": [], "exit": 1,
 "blocks": [
  {"id": "R1", "title": "하나", "kind": "bundle", "stage": "설계 중", "reason": "spec 있음", "task_status": "in_progress", "deps": [], "warnings": ["경고 하나"], "notes": []},
  {"id": "R2", "title": "둘", "kind": "bundle", "stage": "계획", "reason": "계획 있음", "task_status": "in_progress", "deps": ["R1"], "warnings": [], "notes": []},
  {"id": "R3", "title": "셋", "kind": "bundle", "stage": "준비", "reason": "의존 완료", "task_status": "pending", "deps": [], "warnings": [], "notes": []}]}
JSON
LINE="rm · 설계 1 · 구현 1 · 준비 1 · 경고 2 · 받은 지 0분"
STATE_DIR="$W/docs/superpowers/interview"
write_state() {  # write_state <폴더> <파일 이름> <조사 수 하나> — 진행 중 인터뷰 상태 파일
  mkdir -p "$1"
  printf -- '---\ntype: interview-state\nseed: none\norchestration:\n  research_dispatches: {coverage_mapper: %s, blind_spot_prober: 1, steelman_builder: 1, repo_researcher: 0}\n  research_limit: 20\n---\n\n## audit §2 대기 줄\n\n- 포화 판정 1: 아직 — 빈 곳 1개\n' "$3" > "$1/$2"
}

echo "=== 상태줄 · 캐시(AC1 · AC4) ==="
assert_eq "$(sl)" "$LINE" "상태줄 모양"
assert_eq "$(calls)" "1" "양성 대조: 첫 호출은 상태 계산을 부른다"
assert_eq "$(head -n 1 "$LOG")" "$RM --json" "상태 계산 인자 = <경로> --json"
assert_eq "$(sl)" "$LINE" "캐시가 맞는 둘째 호출도 같은 줄"
assert_eq "$(calls)" "1" "캐시가 맞으면 상태 계산을 다시 부르지 않는다"
g branch -q topic
sl >/dev/null; assert_eq "$(calls)" "2" "키 요소 — 브랜치 머리 목록이 바뀌면 다시 계산"
sl >/dev/null; assert_eq "$(calls)" "2" "다시 맞으면 부르지 않는다"
push_file other.txt "다른 파일"
sl >/dev/null; assert_eq "$(calls)" "3" "키 요소 — origin/main 커밋만 바뀌어도(로드맵 그대로) 다시 계산"
push_file "$RM" "로드맵 바뀜"
sl >/dev/null; assert_eq "$(calls)" "4" "키 요소 — 대상 로드맵 사본이 바뀌면 다시 계산"
printf 'interview-state\n' > "$S/state_path.py"
sl >/dev/null; assert_eq "$(calls)" "5" "인터뷰 상태 파일 지원이 켜지면 다시 계산"
write_state "$STATE_DIR" 2026-10-15-t-interview.state.md 1
assert_eq "$(sl)" "$LINE · 인터뷰 조사 3/20" "진행 중 인터뷰 조각"
assert_eq "$(calls)" "6" "키 요소 — 진행 중 인터뷰 상태 파일이 생기면 다시 계산"
age "$STATE_DIR/2026-10-15-t-interview.state.md" 3000
sl >/dev/null; assert_eq "$(calls)" "7" "키 요소 — 인터뷰 상태 파일 수정 시각이 바뀌면 다시 계산"
printf 'brief\n' > "$STATE_DIR/2026-10-15-t-interview.md"
assert_eq "$(sl)" "$LINE" "짝 brief 가 생기면 진행 중이 아니다"
printf -- '---\ntype: interview-state\n' > "$STATE_DIR/2026-10-16-u-interview.state.md"
assert_eq "$(sl)" "$LINE · 인터뷰 셀 수 없음" "읽지 못한 상태 파일은 셀 수 없음 — 로드맵 부분은 그대로"
assert_contains "$(show)" "    docs/superpowers/interview/2026-10-16-u-interview.state.md — 셀 수 없음(frontmatter 가 닫히지 않았다)" "지도에 사유"
rm -f "$STATE_DIR/2026-10-16-u-interview.state.md" "$S/state_path.py"

echo "=== 받은 시각은 캐시 밖(AC13) ==="
sl >/dev/null; before="$(calls)"
assert_contains "$(sl)" "· 받은 지 0분" "양성 대조: 방금 받았으면 0분"
age "$W/.git/FETCH_HEAD" 600
assert_contains "$(sl)" "· 받은 지 10분" "새 커밋 없이 FETCH_HEAD 만 바뀌어도 경과가 따라온다"
assert_eq "$(calls)" "$before" "그때 상태 계산은 다시 부르지 않는다"
assert_contains "$(show)" "대역 첫 줄" "지도 첫 줄은 상태 계산의 첫 줄"
g fetch -q origin

echo "=== 캐시를 못 쓸 때(AC5) ==="
printf 'not json' > "$CACHE"
out="$(show)"
assert_contains "$out" "캐시를 쓰지 못했다 — 캐시 파일이 깨져 있었다" "깨진 캐시 — 지도에 사유 한 줄"
assert_contains "$out" "R1 하나 — 설계 중 · spec 있음" "깨진 캐시 — 결과는 맞다"
printf 'not json' > "$CACHE"
assert_eq "$(sl)" "$LINE" "깨진 캐시 — 상태줄도 맞다"
rm -rf "$W/.git/devbrew"; printf 'x' > "$W/.git/devbrew"
out="$(show)"
assert_contains "$out" "캐시를 쓰지 못했다 — 캐시 파일을 쓰지 못했다" "쓸 수 없는 캐시 자리 — 사유 한 줄"
assert_contains "$out" "R1 하나 — 설계 중 · spec 있음" "쓸 수 없는 캐시 자리 — 결과는 맞다"
assert_eq "$(sl)" "$LINE" "쓸 수 없는 캐시 자리 — 상태줄도 맞다"
rm -f "$W/.git/devbrew"

echo "=== 동시 호출 ==="
rm -f "$CACHE"
for i in 1 2 3 4; do sl >/dev/null & done; wait
python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1],encoding="utf-8")); sys.exit(0 if d.get("version")==1 else 1)' "$CACHE" \
  && ok "동시 호출 뒤에도 캐시는 온전한 JSON" || no "동시 호출 뒤 캐시가 깨졌다"
left="$(find "$W/.git/devbrew" -name '.control-plane.*' | wc -l | tr -d ' ')"
assert_eq "$left" "0" "임시 파일이 남지 않는다"

echo "=== 끄기 스위치(AC6) ==="
rm -f "$CACHE"
before="$(calls)"
out="$(cd "$W" && DEVBREW_SPEC_DISTILL_DISABLE=1 python3 "$S/control_plane.py" statusline </dev/null)"; rc=$?
assert_eq "$out|$rc" "|0" "DISABLE=1 — 상태줄 빈 줄 · rc 0"
out="$(cd "$W" && DEVBREW_SPEC_DISTILL_DISABLE=1 python3 "$S/control_plane.py" show)"; rc=$?
assert_eq "$out|$rc" "꺼져 있다 — DEVBREW_SPEC_DISTILL_DISABLE=1|0" "DISABLE=1 — 지도 한 줄 · rc 0"
out="$(cd "$W" && DEVBREW_SKIP_HOOKS="x:y,spec-distill:statusline" python3 "$S/control_plane.py" statusline </dev/null)"; rc=$?
assert_eq "$out|$rc" "|0" "SKIP_HOOKS — 상태줄 빈 줄 · rc 0"
out="$(cd "$W" && DEVBREW_SKIP_HOOKS="spec-distill:statusline" python3 "$S/control_plane.py" show)"; rc=$?
assert_eq "$out|$rc" "꺼져 있다 — DEVBREW_SKIP_HOOKS 의 spec-distill:statusline|0" "SKIP_HOOKS — 지도 한 줄 · rc 0"
out="$(cd "$W" && DEVBREW_SPEC_DISTILL_DISABLE=1 python3 "$S/control_plane.py" show --tasks 2>"$T/err")"; rc=$?
assert_eq "$out|$rc" "|3" "꺼짐 — 작업 목록 줄은 비고 rc 3"
assert_contains "$(cat "$T/err")" "꺼져 있다 — DEVBREW_SPEC_DISTILL_DISABLE=1" "꺼짐 — 사유는 표준 오류"
assert_eq "$(calls)" "$before" "꺼져 있으면 상태 계산을 부르지 않는다"
assert_eq "$(cd "$W" && DEVBREW_SPEC_DISTILL_DISABLE=0 python3 "$S/control_plane.py" statusline </dev/null)" "$LINE" "양성 대조: DISABLE=0 은 끄지 않는다"
assert_eq "$(cd "$W" && DEVBREW_SKIP_HOOKS="spec-distill:statusline-x" python3 "$S/control_plane.py" statusline </dev/null)" "$LINE" "양성 대조: 다른 토큰은 끄지 않는다"

echo "=== 읽기 전용(AC7) ==="
rm -f "$CACHE"
s0="$(g status --porcelain --untracked-files=all)"; h0="$(g rev-parse HEAD)"; r0="$(g for-each-ref)"
sl >/dev/null; show >/dev/null; show --tasks >/dev/null 2>&1
assert_eq "$(g status --porcelain --untracked-files=all)" "$s0" "작업 트리 상태가 같다"
assert_eq "$(g rev-parse HEAD)|$(g for-each-ref)" "$h0|$r0" "HEAD 와 참조가 같다"
[ -f "$CACHE" ] && ok "양성 짝: 캐시는 git 디렉토리 안에 실제로 쓰였다" || no "캐시 파일이 없다 — 읽기 전용 단언이 공허하다"

echo "=== 작업 목록(AC3) ==="
out="$(show --tasks 2>/dev/null)"; rc=$?
assert_eq "$rc" "0" "작업 목록 rc 0"
assert_eq "$(printf '%s\n' "$out" | head -n 1)" "$(printf 'R1 하나 — 설계 중\tin_progress')" "첫 줄 = 제목 탭 상태"
cp "$S/report.json" "$S/stub-rm.json"
python3 -I -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p,encoding="utf-8")); d["exit"]=3; d["unknown_reasons"]=["로드맵을 못 읽었다: x"]; json.dump(d,open(p,"w",encoding="utf-8"),ensure_ascii=False)' "$S/stub-rm.json"
rm -f "$CACHE"
out="$(show --tasks 2>"$T/err")"; rc=$?
assert_eq "$out|$rc" "|3" "상태 계산이 3 이면 표준 출력이 비고 rc 3"
assert_eq "$(cat "$T/err")" "검사 불가 — 로드맵을 못 읽었다: x" "사유는 표준 오류"
assert_eq "$(sl)" "rm · 설계 1 · 구현 1 · 준비 1 · 경고 2 · 받은 지 0분 · 검사 불가" "상태줄은 검사 불가 조각"
rm -f "$S/stub-rm.json" "$CACHE"

echo "=== 상태 계산이 깨짐 ==="
: > "$S/garbage.flag"
assert_eq "$(sl)" "rm · 설계 0 · 구현 0 · 준비 0 · 경고 없음 · 받은 지 0분 · 검사 불가" "JSON 이 아닌 출력은 검사 불가"
assert_contains "$(show)" "검사 불가: 상태 계산 출력을 읽지 못했다(rc 2)" "지도에 사유"
rm -f "$S/garbage.flag"
assert_eq "$(sl)" "$LINE" "깨진 출력은 캐시에 남지 않는다 — 고쳐지면 바로 정상 줄"
rm -f "$CACHE"

echo "=== 로드맵 여럿 · 고르기 ==="
printf '{"roadmap":"d","source":"origin/main","fetched_at":null,"notice":"","overlaps":[],"unassigned":[],"orphans":[],"unknown_ids":[],"format_errors":[],"unknown_reasons":[],"exit":0,"blocks":[{"id":"A1","title":"끝","kind":"bundle","stage":"머지됨","reason":"r","task_status":"completed","deps":[],"warnings":[],"notes":[]}]}\n' > "$S/stub-done.json"
push_file docs/superpowers/roadmaps/done/roadmap.md "끝난 로드맵"
assert_eq "$(sl)" "$LINE" "블록이 다 끝난 로드맵은 고르지 않는다"
push_file docs/superpowers/roadmaps/rn/roadmap.md "둘째 로드맵"
assert_eq "$(sl)" "rm 외 1 · 설계 2 · 구현 2 · 준비 2 · 경고 4 · 받은 지 0분" "로드맵 둘 — 첫 이름 + 외 1, 수는 합"
out="$(show --tasks 2>"$T/err")"; rc=$?
assert_eq "$out|$rc" "|2" "로드맵이 여럿인데 경로 없음 — rc 2"
out="$(show --tasks "docs/superpowers/roadmaps/rn/roadmap.md" 2>/dev/null)"; rc=$?
assert_eq "$rc|$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "0|3" "경로를 주면 그 로드맵만"
out="$(show --tasks "$W/docs/superpowers/roadmaps/rn/roadmap.md" 2>/dev/null)"; rc=$?
assert_eq "$rc" "0" "절대 경로 인자도 레포 상대로 바뀐다"
assert_eq "$(tail -n 1 "$LOG")" "docs/superpowers/roadmaps/rn/roadmap.md --json" "절대 경로 → 상대 경로로 상태 계산에"
out="$(show -- -x 2>/dev/null)"; rc=$?
assert_eq "$rc" "2" "- 로 시작하는 경로는 사용법 오류"

echo "=== 레포 밖 · 표준 입력 작업 디렉토리 ==="
mkdir -p "$T/plain"
assert_eq "$(cd "$T/plain" && python3 "$S/control_plane.py" statusline </dev/null)" "" "레포 밖 — 빈 줄"
out="$(cd "$T/plain" && printf '{"workspace":{"current_dir":"%s"}}' "$W" | python3 "$S/control_plane.py" statusline)"
assert_contains "$out" "rm 외 1 · " "표준 입력 JSON 의 workspace.current_dir 를 쓴다"
out="$(cd "$T/plain" && printf '{"cwd":"%s"}' "$W" | python3 "$S/control_plane.py" statusline)"
assert_contains "$out" "rm 외 1 · " "표준 입력 JSON 의 cwd 도 쓴다"
git init -q "$T/noorigin"
assert_eq "$(cd "$T/noorigin" && python3 "$S/control_plane.py" statusline </dev/null)" "" "origin 없는 레포 — 빈 줄"
mkdir -p "$T/noorigin/docs/superpowers/interview"
printf 'interview-state\n' > "$S/state_path.py"
write_state "$T/noorigin/docs/superpowers/interview" 2026-10-15-v-interview.state.md 2
assert_eq "$(cd "$T/noorigin" && python3 "$S/control_plane.py" statusline </dev/null)" "인터뷰 조사 4/20" "로드맵 없이 진행 중 인터뷰 — 인터뷰 조각만"
rm -f "$S/state_path.py"

echo "=== 진짜 상태 계산과의 인자 계약 ==="
out="$(cd "$W" && python3 "$REAL/control_plane.py" show docs/superpowers/roadmaps/none/roadmap.md)"
assert_contains "$out" "검사 불가: 로드맵을 못 읽었다: docs/superpowers/roadmaps/none/roadmap.md (origin/main)" "main 에 없는 로드맵 — 검사 불가"
out="$(cd "$W" && python3 "$REAL/control_plane.py" show --tasks docs/superpowers/roadmaps/none/roadmap.md 2>"$T/err")"; rc=$?
assert_eq "$out|$rc" "|3" "진짜 상태 계산이 3 — 작업 목록 비고 rc 3"
assert_contains "$(cat "$T/err")" "로드맵을 못 읽었다" "진짜 사유가 표준 오류에"

echo "=== 변이(AC11) — 통과가 정답인 단언이 이빨을 갖는가 ==="
mutant() {  # mutant <이름> <옛 글자> <새 글자> — 대역 폴더 사본에 한 곳을 바꾼다. 못 심으면 계측기 고장
  rm -rf "$T/m-$1"; cp -R "$S" "$T/m-$1"; rm -f "$T/m-$1/calls.log"
  python3 -I -c 'import sys
p, old, new = sys.argv[1:4]
t = open(p, encoding="utf-8").read()
if t.count(old) != 1:
    sys.exit(1)
open(p, "w", encoding="utf-8").write(t.replace(old, new))' "$T/m-$1/control_plane.py" "$2" "$3" \
    || no "변이 심기 실패: $1 — '$2' 가 정확히 한 번 있지 않다"
}
mcalls() { if [ -f "$T/m-$1/calls.log" ]; then wc -l < "$T/m-$1/calls.log" | tr -d ' '; else echo 0; fi; }
msl() { (cd "$W" && python3 "$T/m-$1/control_plane.py" statusline </dev/null); }

# 각 변이: 캐시를 비우고 한 번 → 호출 수 c1 → 그 요소만 바꾸고 한 번 → c2. 원본은 위 단언에서 c2 > c1 이었다.
mutant hit "    if hit is not None:" "    if False:"
rm -f "$CACHE"; msl hit >/dev/null; c1="$(mcalls hit)"; msl hit >/dev/null; c2="$(mcalls hit)"
[ "$c2" -gt "$c1" ] && ok "변이 잡힘: 캐시를 안 쓰면 호출 수 단언이 RED" || no "변이 생존: 캐시 끄기($c1 → $c2)"
mutant refs 'main or "-", refs_hash,' 'main or "-", "refs",'
rm -f "$CACHE"; msl refs >/dev/null; c1="$(mcalls refs)"; g branch -q topic2; msl refs >/dev/null; c2="$(mcalls refs)"
[ "$c1" -gt 0 ] && [ "$c2" = "$c1" ] && ok "변이 잡힘: 브랜치 요소를 빼면 브랜치 단언이 RED" || no "변이 생존: 브랜치 요소($c1 → $c2)"
mutant main 'mode, main or "-",' 'mode, "-",'
rm -f "$CACHE"; msl main >/dev/null; c1="$(mcalls main)"; push_file other2.txt "또"; msl main >/dev/null; c2="$(mcalls main)"
[ "$c1" -gt 0 ] && [ "$c2" = "$c1" ] && ok "변이 잡힘: origin/main 요소를 빼면 커밋 단언이 RED" || no "변이 생존: origin/main 요소($c1 → $c2)"
mutant stamps '"\n".join(stamps)]' '""]'
printf 'interview-state\n' > "$T/m-stamps/state_path.py"
rm -f "$CACHE"; msl stamps >/dev/null; c1="$(mcalls stamps)"
age "$STATE_DIR/2026-10-15-t-interview.state.md" 9000; rm -f "$STATE_DIR/2026-10-15-t-interview.md"
msl stamps >/dev/null; c2="$(mcalls stamps)"
[ "$c1" -gt 0 ] && [ "$c2" = "$c1" ] && ok "변이 잡힘: 인터뷰 요소를 빼면 인터뷰 단언이 RED" || no "변이 생존: 인터뷰 요소($c1 → $c2)"
rm -rf "$W/docs/superpowers/interview"
mutant switch "        if switch_name():" "        if False:"
out="$(cd "$W" && DEVBREW_SPEC_DISTILL_DISABLE=1 python3 "$T/m-switch/control_plane.py" statusline </dev/null)"
[ -n "$out" ] && ok "변이 잡힘: 끄기 스위치를 안 보면 빈 줄 단언이 RED" || no "변이 생존: 끄기 스위치"
mutant place 'Path(repo.cwd, common) / "devbrew"' 'Path(repo.cwd) / "devbrew"'
s0="$(g status --porcelain --untracked-files=all)"; msl place >/dev/null
[ "$(g status --porcelain --untracked-files=all)" != "$s0" ] && ok "변이 잡힘: 캐시를 작업 트리에 쓰면 읽기 전용 단언이 RED" || no "변이 생존: 캐시 자리"
rm -rf "$W/devbrew"

echo "=== 표시 명령이 멈추지 않는다(멈춘 하위 프로세스 · 닫히지 않는 입력 · 큰 파일) ==="
timed() {  # timed <초> <명령…> — 출력 끝에 「@<걸린 초>」. 상한을 넘기면 묶음째 죽이고 TIMEOUT. 표준 입력은 물려받는다
  python3 -I -c 'import os, signal, subprocess, sys, time
lim = float(sys.argv[1]); t = time.monotonic()
p = subprocess.Popen(sys.argv[2:], stdout=subprocess.PIPE, start_new_session=True)
try:
    out, _ = p.communicate(timeout=lim)
    sys.stdout.write(out.decode("utf-8", "replace").rstrip("\n") + "@%.1f" % (time.monotonic() - t))
except subprocess.TimeoutExpired:
    os.killpg(p.pid, signal.SIGKILL)
    p.communicate()
    sys.stdout.write("TIMEOUT")' "$@"
}
within() {  # within <timed 출력> <초> — 시간 안에 끝났는가
  [ "$1" != "TIMEOUT" ] && awk -v e="${1##*@}" -v l="$2" 'BEGIN { exit !(e + 0 < l + 0) }'
}
body() { printf '%s' "${1%@*}"; }
alive() {  # alive <pid 파일> — 아직 살아 있는 pid 수
  n=0; for pid in $(cat "$1" 2>/dev/null); do kill -0 "$pid" 2>/dev/null && n=$((n + 1)); done; echo "$n"
}
HANG="$T/hang"; mkdir -p "$HANG"
printf '#!/bin/sh\nsleep 30 &\necho $! >> "%s/orphans"\nwait\n' "$HANG" > "$HANG/git"; chmod +x "$HANG/git"
LINE2="rm 외 1 · 설계 2 · 구현 2 · 준비 2 · 경고 4 · 받은 지 0분"

rm -f "$CACHE"
out="$(cd "$W" && timed 15 env PATH="$HANG:$PATH" python3 "$S/control_plane.py" statusline </dev/null)"
within "$out" 6 && ok "멈춘 git — 상태줄이 시간 안에 끝난다(${out##*@}초)" || no "멈춘 git 에 상태줄이 막혔다: $out"
assert_eq "$(body "$out")" "상태줄 — 시간 초과" "기억한 줄이 없으면 시간 초과 한 줄"
[ -s "$HANG/orphans" ] && ok "양성 짝: 멈춘 git 대역이 실제로 불렸다" || no "멈춘 git 대역이 불리지 않았다 — 위 단언이 공허하다"
assert_eq "$(alive "$HANG/orphans")" "0" "시간 초과 뒤 하위 프로세스(손자까지)가 남지 않는다"
out="$(cd "$W" && timed 15 python3 "$S/control_plane.py" statusline </dev/null)"
assert_eq "$(body "$out")" "$LINE2" "양성 대조: 진짜 git 이면 정상 줄(그리고 이 줄을 기억한다)"

: > "$S/hang.flag"; g branch -q t-hang
out="$(cd "$W" && timed 15 python3 "$S/control_plane.py" statusline </dev/null)"
within "$out" 6 && ok "멈춘 상태 계산 — 상태줄이 시간 안에 끝난다(${out##*@}초)" || no "멈춘 상태 계산에 막혔다: $out"
assert_eq "$(body "$out")" "$LINE2 · 시간 초과" "기억한 마지막 줄 + 시간 초과"
rm -f "$S/hang.flag"

out="$( (printf '{"cwd": "'; sleep 4) | (cd "$W" && timed 15 python3 "$S/control_plane.py" statusline) )"
within "$out" 3 && ok "닫히지 않는 표준 입력 — 기다리지 않는다(${out##*@}초)" || no "닫히지 않는 표준 입력에 막혔다: $out"
assert_eq "$(body "$out")" "$LINE2" "읽다 만 입력은 버리고 프로세스 cwd 를 쓴다"

printf 'interview-state\n' > "$S/state_path.py"; mkdir -p "$STATE_DIR"
python3 -I -c 'import sys
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    fh.write("---\ntype: interview-state\n  research_limit: " + "9" * 30000000 + "\n---\n")' "$STATE_DIR/2026-10-17-big-interview.state.md"
python3 -I -c 'import sys
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    fh.write("---\ntype: interview-state\norchestration:\n  research_dispatches: {a: 1}\n  research_limit: " + "9" * 900000 + "\n---\n")' "$STATE_DIR/2026-10-18-digits-interview.state.md"
out="$(cd "$W" && timed 15 python3 "$S/control_plane.py" statusline </dev/null)"
within "$out" 2.5 && ok "큰 상태 파일 · 긴 숫자 — 시간 안에 끝난다(${out##*@}초)" || no "큰 상태 파일에 막혔다: $out"
assert_eq "$(body "$out")" "$LINE2 · 인터뷰 셀 수 없음" "큰 상태 파일은 셀 수 없음 — 로드맵 부분은 그대로"
out="$(show)"
assert_contains "$out" "2026-10-17-big-interview.state.md — 셀 수 없음(파일이 1048576바이트를 넘는다)" "사유: 크기 상한"
assert_contains "$out" "2026-10-18-digits-interview.state.md — 셀 수 없음(research_limit 가 수가 아니다" "사유: 수의 자릿수 상한"
rm -f "$STATE_DIR"/*
i=0; while [ "$i" -le 200 ]; do : > "$STATE_DIR/2026-10-19-n$i-interview.state.md"; i=$((i + 1)); done
assert_contains "$(show)" "진행 중 인터뷰 상태 파일이 200개를 넘는다(201개)" "진행 중 상태 파일 수 상한"
i=0; while [ "$i" -le 200 ]; do : > "$STATE_DIR/2026-10-19-n$i-interview.md"; i=$((i + 1)); done
out="$(show)"
assert_contains "$out" "인터뷰: 진행 중 없음" "짝 brief 가 있는 상태 파일은 상한에 세지 않는다"
assert_not_contains "$out" "개를 넘는다" "끝난 인터뷰가 많아도 셀 수 없음이 아니다"
rm -f "$STATE_DIR"/*
mkfifo "$STATE_DIR/2026-10-20-pipe-interview.state.md"
mkfifo "$T/fifo"; ln -s "$T/fifo" "$STATE_DIR/2026-10-20-link-interview.state.md"
out="$(cd "$W" && timed 15 python3 "$S/control_plane.py" statusline </dev/null)"
within "$out" 6 && ok "파이프 · 파이프로 가는 링크 — 기다리지 않는다(${out##*@}초)" || no "파이프에 상태줄이 막혔다: $out"
assert_eq "$(body "$out")" "$LINE2 · 인터뷰 셀 수 없음" "파이프 · 링크 상태 파일은 셀 수 없음"
out="$(show)"
assert_contains "$out" "2026-10-20-pipe-interview.state.md — 셀 수 없음(일반 파일이 아니다)" "사유: 일반 파일이 아니다"
assert_contains "$out" "2026-10-20-link-interview.state.md — 셀 수 없음(읽지 못했다(" "링크는 따라가지 않는다"
rm -rf "$STATE_DIR"; mkdir -p "$T/real-interview"; ln -s "$T/real-interview" "$STATE_DIR"
assert_contains "$(show)" "인터뷰 폴더 경로에 링크가 있다: docs/superpowers/interview" "링크된 인터뷰 폴더는 읽지 않는다"
rm -f "$STATE_DIR"

# 변이 — 위 단언들이 이빨을 갖는가
mutant group 'os.killpg(proc.pid, signal.SIGKILL)' 'proc.kill()'
rm -f "$CACHE" "$HANG/orphans"
(cd "$W" && timed 15 env PATH="$HANG:$PATH" python3 "$T/m-group/control_plane.py" statusline </dev/null) >/dev/null
[ "$(alive "$HANG/orphans")" -gt 0 ] && ok "변이 잡힘: 묶음째 죽이지 않으면 남은 하위 프로세스 단언이 RED" || no "변이 생존: 프로세스 묶음"
for pid in $(cat "$HANG/orphans" 2>/dev/null); do kill "$pid" 2>/dev/null; done
mutant budget 'STATUSLINE_BUDGET = 3.0' 'STATUSLINE_BUDGET = 60.0'
out="$(cd "$W" && timed 10 env PATH="$HANG:$PATH" python3 "$T/m-budget/control_plane.py" statusline </dev/null)"
within "$out" 6 && no "변이 생존: 상태줄 시간 예산" || ok "변이 잡힘: 예산을 늘리면 시간 단언이 RED"
for pid in $(cat "$HANG/orphans" 2>/dev/null); do kill "$pid" 2>/dev/null; done
mutant stdin 'end = time.monotonic() + STDIN_WAIT' 'end = time.monotonic() + 30'
out="$( (printf '{"cwd": "'; sleep 4) | (cd "$W" && timed 15 python3 "$T/m-stdin/control_plane.py" statusline) )"
within "$out" 3 && no "변이 생존: 표준 입력 대기 상한" || ok "변이 잡힘: 입력을 끝까지 기다리면 시간 단언이 RED"
mutant digits 'value.isdigit() and len(value) <= 9' 'value.isdigit()'
printf 'interview-state\n' > "$T/m-digits/state_path.py"; mkdir -p "$STATE_DIR"
python3 -I -c 'import sys
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    fh.write("---\ntype: interview-state\norchestration:\n  research_dispatches: {a: 1}\n  research_limit: " + "9" * 900000 + "\n---\n")' "$STATE_DIR/2026-10-18-digits-interview.state.md"
out="$(cd "$W" && timed 30 python3 "$T/m-digits/control_plane.py" show </dev/null)"
assert_contains "$out" "2026-10-18-digits-interview.state.md" "양성 짝: 자릿수 변이 실행이 그 상태 파일을 봤다"
case "$out" in *"research_limit 가 수가 아니다"*) no "변이 생존: 자릿수 상한" ;; *) ok "변이 잡힘: 자릿수 상한이 없으면 사유 단언이 RED" ;; esac
rm -rf "$STATE_DIR"
mutant cap 'STATE_MAX_BYTES = 1 << 20' 'STATE_MAX_BYTES = 1 << 40'
printf 'interview-state\n' > "$T/m-cap/state_path.py"; mkdir -p "$STATE_DIR"
python3 -I -c 'import sys
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    fh.write("---\ntype: interview-state\n  research_limit: " + "9" * 30000000 + "\n---\n")' "$STATE_DIR/2026-10-17-big-interview.state.md"
out="$(cd "$W" && python3 "$T/m-cap/control_plane.py" show </dev/null)"
assert_contains "$out" "2026-10-17-big-interview.state.md — 셀 수 없음(" "양성 짝: 크기 변이 실행이 그 상태 파일을 봤다"
case "$out" in *"바이트를 넘는다"*) no "변이 생존: 크기 상한" ;; *) ok "변이 잡힘: 크기 상한이 없으면 사유 단언이 RED" ;; esac
rm -rf "$STATE_DIR"
mutant nonblock 'os.O_RDONLY | os.O_NONBLOCK | getattr(os, "O_NOFOLLOW", 0)' 'os.O_RDONLY'
printf 'interview-state\n' > "$T/m-nonblock/state_path.py"; mkdir -p "$STATE_DIR"
mkfifo "$STATE_DIR/2026-10-20-pipe-interview.state.md"
out="$(cd "$W" && timed 10 python3 "$T/m-nonblock/control_plane.py" statusline </dev/null)"
assert_eq "$out" "TIMEOUT" "변이 잡힘: 파이프를 막힘 없이 열지 않으면 상태줄이 멈춘다(시간 단언이 RED)"
rm -rf "$STATE_DIR"

echo "=== README 상태줄 스크립트(AC9) ==="
README="$ROOT/plugins/spec-distill/README.md"
awk '/<!-- control-plane-statusline:begin -->/{f=1;next} /<!-- control-plane-statusline:end -->/{f=0} f&&/^```sh$/{b=1;next} f&&b&&/^```$/{exit} f&&b' "$README" > "$T/sl.sh"
[ -s "$T/sl.sh" ] && ok "README 에서 스크립트를 뽑았다" || no "README 표시 줄 사이에 sh 펜스가 없다"
assert_not_grep "$(cat "$T/sl.sh")" '[0-9]+\.[0-9]+\.[0-9]+' "스크립트에 버전 붙은 폴더가 박혀 있지 않다"
mkdir -p "$T/cfg-none"
out="$(cd "$W" && CLAUDE_CONFIG_DIR="$T/cfg-none" sh "$T/sl.sh" </dev/null)"; rc=$?
assert_eq "$out|$rc" "상태줄 꺼짐 — 플러그인을 못 찾음|0" "설치본이 없으면 꺼짐 문구(빈 줄 아님)"
mkdir -p "$T/cache/devbrew/spec-distill/9.9.9/scripts" "$T/cfg/plugins"
cp "$S/"*.py "$S/"*.json "$T/cache/devbrew/spec-distill/9.9.9/scripts/"
printf '{\n  "version": 2,\n  "plugins": {\n    "spec-distill@devbrew": [\n      {\n        "scope": "user",\n        "installPath": "%s/cache/devbrew/spec-distill/9.9.9",\n        "version": "9.9.9"\n      }\n    ]\n  }\n}\n' "$T" > "$T/cfg/plugins/installed_plugins.json"
out="$(cd "$W" && CLAUDE_CONFIG_DIR="$T/cfg" sh "$T/sl.sh" </dev/null)"
assert_contains "$out" "rm 외 1 · 설계 2" "installPath 의 control_plane.py 를 실행 때 찾아 부른다"
rm -f "$T/cache/devbrew/spec-distill/9.9.9/scripts/control_plane.py"
out="$(cd "$W" && CLAUDE_CONFIG_DIR="$T/cfg" sh "$T/sl.sh" </dev/null)"
assert_eq "$out" "상태줄 꺼짐 — 플러그인을 못 찾음" "installPath 에 control_plane.py 가 없으면(옛 버전) 꺼짐 문구"
for want in '"statusLine"' '이어 붙' 'spec-distill:statusline' '플러그인이 대신 켜 줄 수 없' '상태줄 — 시간 초과'; do
  assert_contains "$(cat "$README")" "$want" "README 에 '$want'"
done

finish
