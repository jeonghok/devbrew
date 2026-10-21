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
sp_off() {  # 인터뷰 상태 파일 지원이 꺼진 state_path.py — 진짜 모듈에서 지원 표지만 지운다
  sed 's/interview-state/interview_state/g' "$REAL/state_path.py" > "$1"
}
g() { git -C "$W" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }
u() { git -C "$U" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }
push_file() {  # push_file <경로> <내용> — 다른 사본(U)이 main 에 올리고 W 는 받기만 한다 — W 의 로컬 브랜치는 그대로다
  mkdir -p "$(dirname "$U/$1")" && printf '%s\n' "$2" > "$U/$1" && u add -- "$1" && u commit -qm "$1" \
    && u push -q origin main && g fetch -q origin
}
rmtext() { printf -- '---\ntype: roadmap\n---\n%s' "$1"; }   # 로드맵 표지(type: roadmap)를 단 글
calls() { if [ -f "$LOG" ]; then wc -l < "$LOG" | tr -d ' '; else echo 0; fi; }
sl()   { (cd "$W" && python3 "$S/control_plane.py" statusline </dev/null); }
show() { (cd "$W" && python3 "$S/control_plane.py" show "$@" </dev/null); }
age()  { python3 -I -c 'import os,sys,time; t=time.time()-int(sys.argv[2]); os.utime(sys.argv[1],(t,t))' "$1" "$2"; }

# ── 픽스처 ────────────────────────────────────────────────────────────────────
git init -q --bare -b main "$T/origin.git"
git clone -q "$T/origin.git" "$U" 2>/dev/null
printf 'x\n' > "$U/README.txt" && u add README.txt && u commit -qm init && u push -q -u origin main
git clone -q "$T/origin.git" "$W" 2>/dev/null
push_file "$RM" "$(rmtext 로드맵)"
mkdir -p "$S"
cp "$REAL/control_plane.py" "$REAL/kill_switch_active.py" "$REAL/conductor_state.py" "$REAL/repo_defaults.py" \
  "$REAL/ledger_marker.py" "$REAL/roadmap_model.py" "$REAL/section6.py" "$REAL/brief_body.py" "$REAL/suite_lock.py" "$S/"
# 기계 상태 읽기는 scripts/ 의 형제 .claude-plugin/plugin.json 에서 자기 판을 읽는다 — 사본(S · m-*)의 부모에도 둔다
mkdir -p "$T/.claude-plugin" && cp "$ROOT/plugins/spec-distill/.claude-plugin/plugin.json" "$T/.claude-plugin/"
sp_off "$S/state_path.py"
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
LINE="rm · 설계 1 · 구현 1 · 준비 1 · 경고 2 · 기본 브랜치 main · 받은 지 0분(어느 원격 · 브랜치든)"
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
push_file "$RM" "$(rmtext '로드맵 바뀜')"
sl >/dev/null; assert_eq "$(calls)" "4" "키 요소 — 대상 로드맵 사본이 바뀌면 다시 계산"
cp "$REAL/state_path.py" "$S/state_path.py"
sl >/dev/null; assert_eq "$(calls)" "4" "인터뷰 상태 파일 지원이 켜져도 키가 아니므로 다시 계산하지 않는다"
write_state "$STATE_DIR" 2026-10-15-t-interview.state.md 1
assert_eq "$(sl)" "$LINE · 인터뷰 조사 3/20" "진행 중 인터뷰 조각"
assert_eq "$(calls)" "4" "진행 중 인터뷰 상태 파일이 생겨도 상태 계산은 다시 부르지 않는다(인터뷰는 캐시 밖)"
age "$STATE_DIR/2026-10-15-t-interview.state.md" 3000
assert_eq "$(sl)" "$LINE · 인터뷰 조사 3/20" "인터뷰 상태 파일 수정 시각이 바뀌어도 줄은 맞고"
assert_eq "$(calls)" "4" "상태 계산은 다시 부르지 않는다"
# R10 — 장치 칸 다섯(open_researcher 포함) · 기본 60. 마지막 칸이 0 이 아니어야 «마지막 칸 빠뜨림»이 보인다.
printf -- '---\ntype: interview-state\nseed: none\norchestration:\n  research_dispatches: {coverage_mapper: 1, blind_spot_prober: 1, steelman_builder: 1, repo_researcher: 1, open_researcher: 2}\n  research_limit: 60\n---\n' \
  > "$STATE_DIR/2026-10-19-o-interview.state.md"
assert_eq "$(sl)" "$LINE · 인터뷰 조사 6/60 외 1" "장치 칸 다섯을 모두 더한다(open_researcher 2 포함)"
rm -f "$STATE_DIR/2026-10-19-o-interview.state.md"
git -C "$W" worktree add -q --detach "$T/wt2" HEAD
sl2() { (cd "$T/wt2" && python3 "$S/control_plane.py" statusline </dev/null); }
sl >/dev/null; sl2 >/dev/null; base="$(calls)"
sl >/dev/null; sl2 >/dev/null; sl >/dev/null; sl2 >/dev/null
assert_eq "$(calls)" "$base" "worktree 둘이 번갈아 불러도 둘 다 캐시가 맞는다(서로의 칸을 밀지 않는다)"
write_state "$T/wt2/docs/superpowers/interview" 2026-10-15-w-interview.state.md 5
sl >/dev/null; sl2 >/dev/null; sl >/dev/null; sl2 >/dev/null
assert_eq "$(calls)" "$base" "한쪽 worktree 에 인터뷰가 생겨도 다른 쪽 캐시를 밀지 않는다"
assert_contains "$(sl2)" "인터뷰 조사 7/20" "그 인터뷰는 그 worktree 에서만 보인다"
assert_not_contains "$(sl)" "7/20" "다른 worktree 의 인터뷰는 이쪽에 안 보인다"
git -C "$W" worktree remove --force "$T/wt2"
printf 'brief\n' > "$STATE_DIR/2026-10-15-t-interview.md"
assert_eq "$(sl)" "$LINE" "짝 brief 가 생기면 진행 중이 아니다"
printf -- '---\ntype: interview-state\n' > "$STATE_DIR/2026-10-16-u-interview.state.md"
assert_eq "$(sl)" "$LINE · 인터뷰 셀 수 없음" "읽지 못한 상태 파일은 셀 수 없음 — 로드맵 부분은 그대로"
assert_contains "$(show)" "    docs/superpowers/interview/2026-10-16-u-interview.state.md — 셀 수 없음(frontmatter 가 닫히지 않았다)" "지도에 사유"
rm -f "$STATE_DIR/2026-10-16-u-interview.state.md"; sp_off "$S/state_path.py"

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
assert_eq "$(sl)" "rm · 설계 1 · 구현 1 · 준비 1 · 경고 2 · 기본 브랜치 main · 받은 지 0분(어느 원격 · 브랜치든) · 검사 불가" "상태줄은 검사 불가 조각"
rm -f "$S/stub-rm.json" "$CACHE"

echo "=== 상태 계산이 깨짐 ==="
: > "$S/garbage.flag"
assert_eq "$(sl)" "rm · 설계 0 · 구현 0 · 준비 0 · 경고 없음 · 기본 브랜치 main · 받은 지 0분(어느 원격 · 브랜치든) · 검사 불가" "JSON 이 아닌 출력은 검사 불가"
assert_contains "$(show)" "검사 불가: 상태 계산 출력을 읽지 못했다(rc 2)" "지도에 사유"
rm -f "$S/garbage.flag"
assert_eq "$(sl)" "$LINE" "깨진 출력은 캐시에 남지 않는다 — 고쳐지면 바로 정상 줄"
rm -f "$CACHE"

echo "=== 로드맵 여럿 · 고르기 ==="
printf '{"roadmap":"d","source":"origin/main","fetched_at":null,"notice":"","overlaps":[],"unassigned":[],"orphans":[],"unknown_ids":[],"format_errors":[],"unknown_reasons":[],"exit":0,"blocks":[{"id":"A1","title":"끝","kind":"bundle","stage":"머지됨","reason":"r","task_status":"completed","deps":[],"warnings":[],"notes":[]}]}\n' > "$S/stub-done.json"
push_file docs/superpowers/roadmaps/done/roadmap.md "$(rmtext '끝난 로드맵')"
assert_eq "$(sl)" "$LINE" "블록이 다 끝난 로드맵은 고르지 않는다"
push_file docs/superpowers/roadmaps/rn/roadmap.md "$(rmtext '둘째 로드맵')"
assert_eq "$(sl)" "rm 외 1 · 설계 2 · 구현 2 · 준비 2 · 경고 4 · 기본 브랜치 main · 받은 지 0분(어느 원격 · 브랜치든)" "로드맵 둘 — 첫 이름 + 외 1, 수는 합"
out="$(show --tasks 2>"$T/err")"; rc=$?
assert_eq "$out|$rc" "|2" "로드맵이 여럿인데 경로 없음 — rc 2"
out="$(show --tasks "docs/superpowers/roadmaps/rn/roadmap.md" 2>/dev/null)"; rc=$?
assert_eq "$rc|$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "0|3" "경로를 주면 그 로드맵만"
out="$(show --tasks "$W/docs/superpowers/roadmaps/rn/roadmap.md" 2>/dev/null)"; rc=$?
assert_eq "$rc" "0" "절대 경로 인자도 레포 상대로 바뀐다"
assert_eq "$(tail -n 1 "$LOG")" "docs/superpowers/roadmaps/rn/roadmap.md --json" "절대 경로 → 상대 경로로 상태 계산에"
out="$(show -- -x 2>/dev/null)"; rc=$?
assert_eq "$rc" "2" "- 로 시작하는 경로는 사용법 오류"

echo "=== 설정 폴더가 다른 레포(R8 AC6 · AC29) ==="
P="$T/plan-work"
pg() { git -C "$P" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }
pput() { mkdir -p "$(dirname "$P/$1")" && printf '%s\n' "$2" > "$P/$1"; }
git init -q --bare -b main "$T/plan-origin.git"
git clone -q "$T/plan-origin.git" "$P" 2>/dev/null
pput .devbrew.md "$(printf -- '---\nroadmaps_dir: plan/roadmaps/\n---')"
pput plan/roadmaps/pa/roadmap.md "$(rmtext 가)"
pput plan/roadmaps/pb/plan.md "$(rmtext 나)"
pput plan/roadmaps/pa/A1.md "$(printf -- '---\ntype: epic-bundle\n---')"
pput plan/roadmaps/pa/notes.md "# 메모"
pput plan/roadmaps/pa/deep/roadmap.md "$(rmtext 깊음)"
pput plan/roadmaps/pc/broken.md "$(printf -- '---\ntype: roadmap\n# 머리말이 닫히지 않았다')"
pput docs/superpowers/roadmaps/dz/roadmap.md "$(rmtext 기본폴더)"
pput templates/roadmap-template.md "$(rmtext 템플릿)"
pg add -A && pg commit -qm init && pg push -q -u origin main && pg remote set-head origin --auto >/dev/null \
  || no "픽스처: 설정 폴더가 다른 레포를 만들지 못했다"
WANT="$(printf '%s\n' plan/roadmaps/pa/roadmap.md plan/roadmaps/pb/plan.md plan/roadmaps/pc/broken.md)"
cp_list="$(python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import control_plane as cp
r = cp.Repo(sys.argv[2], cp.Deadline(30)); tree, folder, why = cp.listing(r, cp.default_ref(r)[0])
print("\n".join(cp.candidates(r, tree, folder)[0])); print(why or "사유 없음")' "$S" "$P")"
assert_eq "$cp_list" "$WANT
사유 없음" "상태줄 후보: 설정 폴더 바로 아래 폴더의 type: roadmap 과 못 읽는 후보만(기본 폴더 · 템플릿 · 두 단계 · 다른 표지 아님)"
ledger_list="$(python3 "$REAL/conductor_ledger.py" --root "$P" roadmaps | cut -f1 | sort)"
assert_eq "$ledger_list" "$WANT" "로드맵 목록(conductor_ledger roadmaps)도 같은 목록"
before="$(calls)"
pline="$(cd "$P" && python3 "$S/control_plane.py" statusline </dev/null)"
assert_contains "$pline" "검사 불가" "상태줄: 머리말을 못 읽는 후보는 검사 불가로 센다(조용히 빼지 않는다)"
assert_eq "$(tail -n +"$((before + 1))" "$LOG" | sort | tr '\n' '|')" \
  "plan/roadmaps/pa/roadmap.md --json|plan/roadmaps/pb/plan.md --json|" "상태줄: 상태 계산은 찾은 로드맵에만 부른다"
assert_contains "$(cd "$P" && python3 "$S/control_plane.py" show </dev/null)" "plan/roadmaps/pc/broken.md" "지도: 못 읽는 후보의 경로를 보인다"
cat > "$T/catcount.py" <<'PY'
"""gather 를 두 번 돌려 로드맵 후보 글 읽기(cat-file, 레포 설정 파일 제외) 수를 센다. fail 모드는 첫 번째에 pa 읽기를 실패시킨다."""
import os
import subprocess
import sys

sys.path.insert(0, sys.argv[1])
import control_plane as cp  # noqa: E402

P, mode = sys.argv[2], sys.argv[3]


def rev(spec):
    return subprocess.run(["git", "-C", P, "rev-parse", spec], capture_output=True, encoding="utf-8").stdout.strip()


settings, pa = rev("origin/HEAD:.devbrew.md"), rev("origin/HEAD:plan/roadmaps/pa/roadmap.md")
orig, log, fail, procs = cp.Repo.raw, [], set(), []


def raw(self, *args, data=None):
    if args[0] == "cat-file" and args[1:] == ("--batch",):
        shas = data.decode("ascii").split()
        log.extend(shas)
        procs.append(len(shas))
        data = "".join(s + "\n" for s in shas if s not in fail).encode("ascii")   # 실패시킬 blob 은 빼고 묻는다
    elif args[0] == "cat-file" and args[-1] != settings:
        log.append(args[-1])
        procs.append(1)
    return orig(self, *args, data=data)


cp.Repo.raw = raw
try:
    os.unlink(os.path.join(P, ".git", "devbrew", "control-plane.json"))
except FileNotFoundError:
    pass


def gather():
    del log[:], procs[:]
    v = cp.gather(P, None, cp.Deadline(30), {}, use_gh=False)
    return len(log), dict((p, r.get("exit")) for p, r in v["items"])


if mode == "fail":
    fail.add(pa)
n1, items1 = gather()
procs1 = len(procs)
fail.clear()
n2, items2 = gather()
pa_path = "plan/roadmaps/pa/roadmap.md"
print("%s:%d %s:%d pa=%s>%s procs=%d" % ("miss" if n1 else "none", n1, "hit" if not n2 else "read", n2,
                                         items1.get(pa_path), items2.get(pa_path), procs1))
PY
out="$(python3 "$T/catcount.py" "$S" "$P" hit)"
case "$out" in miss:*" hit:0 "*) ok "캐시가 맞으면 로드맵 후보 글을 하나도 읽지 않는다(cat-file 0) — $out" ;;
  *) no "캐시가 맞을 때도 후보 글을 읽는다 — $out" ;; esac
assert_contains "$out" "miss:5 " "양성 대조: 캐시가 없으면 로드맵 자리의 .md 다섯을 읽는다(pa 셋 · pb · pc)"
assert_contains "$out" " procs=1" "캐시가 없을 때 후보 글은 git 한 번(cat-file --batch)으로 읽는다 — 파일 수만큼 부르지 않는다"
out="$(python3 "$T/catcount.py" "$S" "$P" fail)"
assert_contains "$out" "pa=3>1" "읽기 실패는 검사 불가로 보이되 캐시에 남지 않는다 — 다시 읽으면 상태 계산이 돈다($out)"
assert_not_contains "$out" " hit:0 " "읽기 실패 뒤 둘째 호출은 캐시를 쓰지 않고 다시 읽는다"
pput .devbrew.md "$(printf -- '---\nroadmaps_dir: plan/roadmaps/\ntypo_key: x\n---')"
pg commit -qam typo && pg push -q origin main || no "픽스처: 깨진 설정을 올리지 못했다"
assert_contains "$(cd "$P" && python3 "$S/control_plane.py" statusline </dev/null)" "검사 불가" "상태줄: 레포 설정이 깨지면 기본 폴더로 조용히 찾지 않고 검사 불가"
assert_contains "$(cd "$P" && python3 "$S/control_plane.py" show </dev/null)" "typo_key" "지도: 깨진 설정의 사유를 보인다"

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
cp "$REAL/state_path.py" "$S/state_path.py"
write_state "$T/noorigin/docs/superpowers/interview" 2026-10-15-v-interview.state.md 2
assert_eq "$(cd "$T/noorigin" && python3 "$S/control_plane.py" statusline </dev/null)" "인터뷰 조사 4/20" "로드맵 없이 진행 중 인터뷰 — 인터뷰 조각만"
sp_off "$S/state_path.py"

echo "=== 진짜 상태 계산과의 인자 계약 ==="
out="$(cd "$W" && python3 "$REAL/control_plane.py" show docs/superpowers/roadmaps/none/roadmap.md)"
assert_contains "$out" "로드맵이 아직 기본 브랜치(origin/main)에 없다" "기본 브랜치에 없는 로드맵 — 없음 줄"
out="$(cd "$W" && python3 "$REAL/control_plane.py" show --tasks docs/superpowers/roadmaps/none/roadmap.md 2>"$T/err4")"; rc=$?
assert_eq "$out|$rc" "|4" "작업 목록: 기본 브랜치에 없는 로드맵 → 표준 출력 비고 rc 4"
assert_contains "$(cat "$T/err4")" "--roadmap-file" "작업 목록: 머지 전이면 작업 트리 사본으로 계산하라는 안내(표준 오류)"

# origin/HEAD 만 없는 레포 — 「로드맵 없음」이 아니라 기본 브랜치를 모른다고 말한다
git clone -q "$T/origin.git" "$T/nohead" 2>/dev/null
git -C "$T/nohead" remote set-head origin -d >/dev/null 2>&1
out="$(cd "$T/nohead" && python3 "$REAL/control_plane.py" show </dev/null)"
assert_contains "$out" "기본 브랜치를 알 수 없다" "origin/HEAD 없음: show 는 기본 브랜치를 모른다고 말한다"
assert_not_contains "$out" "로드맵 없음" "origin/HEAD 없음: 「로드맵 없음」으로 뭉개지 않는다"
out="$(cd "$T/nohead" && python3 "$REAL/control_plane.py" show --tasks </dev/null 2>"$T/err5")"; rc=$?
assert_eq "$out|$rc" "|3" "origin/HEAD 없음: 작업 목록은 비고 rc 3"
assert_contains "$(cat "$T/err5")" "기본 브랜치를 알 수 없다" "origin/HEAD 없음: 사유가 표준 오류에"
assert_eq "$(cd "$T/nohead" && python3 "$REAL/control_plane.py" statusline </dev/null)" "" "origin/HEAD 없음: 상태줄은 조용하다"

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
mutant stamps 'interview = read_interviews(supported, files, folder_error, deadline)  # 캐시 밖' 'interview = {"supported": False, "items": [], "errors": []}  # 캐시 밖'
cp "$REAL/state_path.py" "$T/m-stamps/state_path.py"
write_state "$STATE_DIR" 2026-10-15-t-interview.state.md 1; rm -f "$STATE_DIR/2026-10-15-t-interview.md"
rm -f "$CACHE"; msl stamps >/dev/null
mutant stampsctl 'interview = read_interviews(supported, files, folder_error, deadline)  # 캐시 밖' 'interview = read_interviews(supported, files, folder_error, deadline)  # 캐시 밖'
cp "$REAL/state_path.py" "$T/m-stampsctl/state_path.py"
[[ "$(msl stampsctl)" == *"인터뷰 조사 3/20" ]] && ok "양성 대조: 변이 없는 사본은 인터뷰 조각을 낸다" || no "양성 대조 실패 — 아래 단언이 공허하다"
[[ "$(msl stamps)" != *"인터뷰 조사"* ]] && ok "변이 잡힘: 인터뷰를 안 읽으면 인터뷰 조각 단언이 RED" || no "변이 생존: 인터뷰 읽기"
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
LINE2="rm 외 1 · 설계 2 · 구현 2 · 준비 2 · 경고 4 · 기본 브랜치 main · 받은 지 0분(어느 원격 · 브랜치든)"

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

cp "$REAL/state_path.py" "$S/state_path.py"; mkdir -p "$STATE_DIR"
python3 -I -c 'import sys
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    fh.write("---\ntype: interview-state\n  research_limit: " + "9" * 30000000 + "\n---\n")' "$STATE_DIR/2026-10-17-big-interview.state.md"
python3 -I -c 'import sys
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    fh.write("---\ntype: interview-state\norchestration:\n  research_dispatches: {a: 1}\n  research_limit: " + "9" * 60000 + "\n---\n")' "$STATE_DIR/2026-10-18-digits-interview.state.md"
out="$(cd "$W" && timed 15 python3 "$S/control_plane.py" statusline </dev/null)"
within "$out" 2.5 && ok "큰 상태 파일 · 긴 숫자 — 시간 안에 끝난다(${out##*@}초)" || no "큰 상태 파일에 막혔다: $out"
assert_eq "$(body "$out")" "$LINE2 · 인터뷰 셀 수 없음" "큰 상태 파일은 셀 수 없음 — 로드맵 부분은 그대로"
out="$(show)"
assert_contains "$out" "2026-10-17-big-interview.state.md — 셀 수 없음(파일이 65536바이트를 넘는다)" "사유: 크기 상한"
assert_contains "$out" "2026-10-18-digits-interview.state.md — 셀 수 없음(research_limit 가 수가 아니다" "사유: 수의 자릿수 상한"
long="$(printf '%s\n' "$out" | awk 'length($0) > 400' | wc -l | tr -d ' ')"
assert_eq "$long" "0" "사유는 줄여 낸다 — 400바이트 넘는 줄이 없다"
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
cp "$REAL/state_path.py" "$T/m-digits/state_path.py"; mkdir -p "$STATE_DIR"
python3 -I -c 'import sys
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    fh.write("---\ntype: interview-state\norchestration:\n  research_dispatches: {a: 1}\n  research_limit: " + "9" * 60000 + "\n---\n")' "$STATE_DIR/2026-10-18-digits-interview.state.md"
out="$(cd "$W" && timed 30 python3 "$T/m-digits/control_plane.py" show </dev/null)"
assert_contains "$out" "2026-10-18-digits-interview.state.md" "양성 짝: 자릿수 변이 실행이 그 상태 파일을 봤다"
case "$out" in *"research_limit 가 수가 아니다"*) no "변이 생존: 자릿수 상한" ;; *) ok "변이 잡힘: 자릿수 상한이 없으면 사유 단언이 RED" ;; esac
rm -rf "$STATE_DIR"
mutant cap 'STATE_MAX_BYTES = 1 << 16' 'STATE_MAX_BYTES = 1 << 26'
cp "$REAL/state_path.py" "$T/m-cap/state_path.py"; mkdir -p "$STATE_DIR"
python3 -I -c 'import sys
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    fh.write("---\ntype: interview-state\n  research_limit: " + "9" * 30000000 + "\n---\n")' "$STATE_DIR/2026-10-17-big-interview.state.md"
out="$(cd "$W" && python3 "$T/m-cap/control_plane.py" show </dev/null)"
assert_contains "$out" "2026-10-17-big-interview.state.md — 셀 수 없음(" "양성 짝: 크기 변이 실행이 그 상태 파일을 봤다"
case "$out" in *"바이트를 넘는다"*) no "변이 생존: 크기 상한" ;; *) ok "변이 잡힘: 크기 상한이 없으면 사유 단언이 RED" ;; esac
rm -rf "$STATE_DIR"
mutant nonblock 'os.O_RDONLY | os.O_NONBLOCK | getattr(os, "O_NOFOLLOW", 0)' 'os.O_RDONLY'
cp "$REAL/state_path.py" "$T/m-nonblock/state_path.py"; mkdir -p "$STATE_DIR"
mkfifo "$STATE_DIR/2026-10-20-pipe-interview.state.md"
out="$(cd "$W" && timed 10 python3 "$T/m-nonblock/control_plane.py" statusline </dev/null)"
assert_eq "$out" "TIMEOUT" "변이 잡힘: 파이프를 막힘 없이 열지 않으면 상태줄이 멈춘다(시간 단언이 RED)"
rm -rf "$STATE_DIR"

echo "=== 기계 상태 덧씌우기 — 배선 · 캐시 · 상한 ==="
MPATH="$(python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import conductor_state as c; print(c.machine_path(sys.argv[2], sys.argv[3]))' "$REAL" "$W/.claude/spec-distill" "$RM")"
LEDGER="$T/exec-ledger.md"
printf '# SDD ledger — plan: p\nTask 1: Ruling: 가 — 왜 — 비용\n' > "$LEDGER"
write_machine() {  # write_machine <PR 상태> <원장 경로> — 진짜 기계 상태 파일을 쓴다
  mkdir -p "$(dirname "$MPATH")"
  python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import conductor_state as c
d = c.empty()
d["PR"].append({"브랜치": "feature/a", "번호": "#12", "상태": sys.argv[4], "확인한 때": "2026-10-17 10:00",
                "headRefOid": "a" * 40, "교차 레포": "아니오", "baseRefName": "main", "mergeCommit": "-",
                "쓴 세션": "session-aaaa1111"})
d["실행 원장"].append({"에픽": "R5", "계획": "p.md", "원장": sys.argv[5], "읽은 줄": "0"})
open(sys.argv[2], "w", encoding="utf-8").write(c.render_machine(sys.argv[3], d))' "$REAL" "$MPATH" "$RM" "$1" "$2"
}
python3 -I -c 'import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
d["blocks"] = [{"id": "R5", "title": "다섯", "kind": "bundle", "stage": "구현 끝", "reason": "계획 구현 대조 있음",
                "task_status": "in_progress", "deps": [], "warnings": [], "notes": [],
                "branch_states": [{"branch": "feature/a", "tip": "abcdef12", "merged": None}]}]
d["orphans"] = []; d["exit"] = 0
json.dump(d, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False)' "$S/report.json" "$S/stub-rm.json"
rm -f "$CACHE"
write_machine 열림 "$LEDGER"
sl >/dev/null
out="$(show)"
assert_contains "$out" "R5 다섯 — PR · #12 열림(기계 상태)" "기계 상태의 열린 PR 이 단계를 PR 로 바꾼다(gather 배선)"
assert_contains "$out" "    PR: #12 열림(기계 상태)" "PR 줄"
assert_contains "$out" "    R5: Task 1: Ruling: 가 — 왜 — 비용" "실행 원장의 판정 줄"
CALLS_BEFORE="$(calls)"
write_machine 닫힘 "$LEDGER"
sl >/dev/null
out="$(show)"
assert_eq "$(calls)" "$CALLS_BEFORE" "양성 짝: 캐시가 맞아 상태 계산은 다시 부르지 않았다"
assert_contains "$out" "    PR: #12 닫힘(기계 상태)" "기계 상태를 바꾸면 캐시 뒤의 화면이 따라간다 — 덧씌움이 캐시에 남지 않는다"
assert_not_contains "$out" "열림(기계 상태)" "옛 PR 상태가 캐시를 타고 남지 않는다"
assert_not_contains "$(cat "$CACHE")" "기계 상태" "캐시 파일에 덧씌움이 없다"
printf '깨진 파일\n' > "$MPATH"
out="$(show)"
assert_contains "$out" "기계 상태를 읽지 못했다 — frontmatter 가 없다" "깨진 기계 상태는 사유로 보인다"
assert_contains "$out" "R5 다섯 — 구현 끝" "깨진 파일 하나가 보고서를 비우지 않는다"
rm -f "$MPATH"; mkfifo "$MPATH"
out="$(cd "$W" && timed 10 python3 "$S/control_plane.py" show </dev/null)"
within "$out" 8 && ok "FIFO 기계 상태에도 지도가 멈추지 않는다" || no "FIFO 기계 상태에서 지도가 멈췄다: $(body "$out")"
assert_contains "$out" "기계 상태 파일을 읽지 못했다" "FIFO 는 사유로 보인다"
out="$(cd "$W" && timed 10 python3 "$S/control_plane.py" statusline </dev/null)"
within "$out" 8 && ok "FIFO 기계 상태에도 상태줄이 멈추지 않는다" || no "FIFO 기계 상태에서 상태줄이 멈췄다"
rm -f "$MPATH"
head -c 3000000 /dev/zero | tr '\0' x > "$MPATH"
out="$(cd "$W" && timed 10 python3 "$S/control_plane.py" show </dev/null)"
within "$out" 8 && ok "큰 기계 상태에도 지도가 멈추지 않는다" || no "큰 기계 상태에서 지도가 멈췄다"
assert_contains "$out" "바이트를 넘는다" "큰 파일은 사유로 보인다"
rm -f "$MPATH"
mkfifo "$T/fifo-ledger"
write_machine 열림 "$T/fifo-ledger"
out="$(cd "$W" && timed 10 python3 "$S/control_plane.py" show </dev/null)"
within "$out" 8 && ok "FIFO 원장에도 지도가 멈추지 않는다" || no "FIFO 원장에서 지도가 멈췄다"
assert_contains "$out" "    원장 읽기 불가: $T/fifo-ledger — 일반 파일이 아니다" "읽지 못한 원장은 경로와 사유를 보인다"
out="$(cd "$W" && timed 10 python3 "$S/control_plane.py" statusline </dev/null)"
within "$out" 8 && ok "FIFO 원장에도 상태줄이 멈추지 않는다" || no "FIFO 원장에서 상태줄이 멈췄다"
rm -f "$MPATH" "$S/stub-rm.json" "$CACHE" "$T/fifo-ledger"

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

echo "=== 취소 신호 · 남은 임시 파일 · 코드가 바뀐 캐시 ==="
cancel_run() {  # cancel_run <control_plane.py> <출력 파일> — 멈춘 git 아래 상태줄을 띄우고, 대역이 뜨면 SIGTERM
  rm -f "$CACHE" "$HANG/orphans"
  (cd "$W" && exec env PATH="$HANG:$PATH" python3 "$1" statusline </dev/null >"$2") &
  bg=$!
  i=0; while [ ! -s "$HANG/orphans" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
  kill -TERM "$bg" 2>/dev/null; wait "$bg" 2>/dev/null; sleep 0.3
}
cancel_run "$S/control_plane.py" "$T/cancel.out"
[ -s "$HANG/orphans" ] && ok "양성 짝: 취소 전에 멈춘 git 대역이 떠 있었다" || no "멈춘 git 대역이 뜨지 않았다 — 아래 단언이 공허하다"
assert_eq "$(alive "$HANG/orphans")" "0" "취소 신호를 받으면 하위 프로세스 묶음도 끝난다"
assert_eq "$(cat "$T/cancel.out")" "상태줄 — 시간 초과" "취소돼도 한 줄을 낸다"
mutant cancel 'signal.signal(sig, _cancel)' 'None'
cancel_run "$T/m-cancel/control_plane.py" "$T/cancel-m.out"
[ "$(alive "$HANG/orphans")" -gt 0 ] && ok "변이 잡힘: 신호를 받지 않으면 남은 하위 프로세스 단언이 RED" || no "변이 생존: 취소 신호"
for pid in $(cat "$HANG/orphans" 2>/dev/null); do kill "$pid" 2>/dev/null; done

mkdir -p "$W/.git/devbrew"
: > "$W/.git/devbrew/.control-plane.old.tmp"; : > "$W/.git/devbrew/.control-plane.new.tmp"
age "$W/.git/devbrew/.control-plane.old.tmp" 3600
rm -f "$CACHE"; sl >/dev/null
[ ! -e "$W/.git/devbrew/.control-plane.old.tmp" ] && ok "끊긴 쓰기가 남긴 오래된 임시 파일을 지운다" || no "오래된 임시 파일이 남았다"
[ -e "$W/.git/devbrew/.control-plane.new.tmp" ] && ok "양성 짝: 방금 만든 임시 파일은 지우지 않는다" || no "방금 만든 임시 파일까지 지웠다"
rm -f "$W/.git/devbrew/.control-plane.new.tmp"

sl >/dev/null; c1="$(calls)"; sl >/dev/null
assert_eq "$(calls)" "$c1" "양성 대조: 코드가 그대로면 캐시를 쓴다"
age "$S/roadmap_status.py" 120; sl >/dev/null
[ "$(calls)" -gt "$c1" ] && ok "상태 계산 코드가 바뀌면 캐시를 쓰지 않는다" || no "코드가 바뀌어도 옛 캐시를 썼다"
mutant short 'return value if len(value) <= 80 else value[:80] + "…"' 'return value'
cp "$REAL/state_path.py" "$T/m-short/state_path.py"; mkdir -p "$STATE_DIR"
python3 -I -c 'import sys
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    fh.write("---\ntype: interview-state\norchestration:\n  research_dispatches: {a: 1}\n  research_limit: " + "9" * 60000 + "\n---\n")' "$STATE_DIR/2026-10-18-digits-interview.state.md"
out="$(cd "$W" && python3 "$T/m-short/control_plane.py" show </dev/null)"
assert_contains "$out" "2026-10-18-digits-interview.state.md — 셀 수 없음(" "양성 짝: 줄이기 변이 실행이 그 상태 파일을 봤다"
[ "$(printf '%s\n' "$out" | awk 'length($0) > 400' | wc -l | tr -d ' ')" -gt 0 ] && ok "변이 잡힘: 사유를 줄이지 않으면 줄 길이 단언이 RED" || no "변이 생존: 사유 줄이기"
rm -rf "$STATE_DIR"

echo "=== 인터뷰 폴더는 기본 브랜치의 레포 설정(R8) ==="
cp "$REAL/state_path.py" "$S/state_path.py"
push_file .devbrew.md "$(printf -- '---\ninterview_dir: notes/iv/\n---')"
write_state "$W/notes/iv" 2026-10-20-n-interview.state.md 2
write_state "$STATE_DIR" 2026-10-20-d-interview.state.md 7
out="$(show)"
assert_contains "$out" "notes/iv/2026-10-20-n-interview.state.md" "설정한 인터뷰 폴더의 상태 파일을 읽는다"
assert_not_contains "$out" "2026-10-20-d-interview.state.md" "기본 폴더의 상태 파일은 읽지 않는다"
assert_contains "$(sl)" "인터뷰 조사 4/20" "상태줄도 설정한 폴더의 인터뷰를 센다"
push_file .devbrew.md "$(printf -- '---\ninterview_dir: /abs/\n---')"
assert_contains "$(show)" "인터뷰 폴더를 정하지 못했다" "레포 설정이 깨지면 인터뷰 칸에 그 사유를 보인다"
rm -rf "$STATE_DIR" "$W/notes"; sp_off "$S/state_path.py"

finish
