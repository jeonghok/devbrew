#!/usr/bin/env bash
# 작업공간 불변 락(R8 AC27 · §9)과 devbrew 밖 레포 회귀 픽스처(R8 AC29 의 계획 1 몫).
#
# 불변 락: 한 레포의 서로 다른 브랜치 worktree 둘(한쪽은 로드맵 · 레포 설정 파일을 고쳐 자기 브랜치에만 커밋)에서
# 해결자 `get`(아홉 키 · 로드맵 층 포함) · 로드맵 찾기 · 상태 계산 JSON 의 stdout · stderr · rc 가 바이트까지 같다.
# 비교에서 빼는 것은 `read_tree` 가 「이 작업공간」인 칸 하나다. 양성 대조: 설정이 다른 두 레포는 다른 답을 낸다.
#
# 한계: 기본 브랜치를 개명한 뒤 `git fetch` 만 하고 `--prune` 하지 않으면 옛 원격 브랜치가 남아 origin/HEAD 가
# 여전히 풀리므로 qg resolve-baseline 은 옛 기준으로 조용히 풀린다(qg 는 원격과 대조하지 않는다 — spec-distill 은
# 원격 대조로 rc 5 에서 멈춘다). 이 파일은 prune 해 dangling 이 된 경우만 사유를 단언한다.
#
# 픽스처는 모두 `mktemp -d` 의 임시 레포다 — 원격은 로컬 bare, origin/HEAD 는 `remote set-head --auto`.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_workspace_invariance.sh
set -u
unset GIT_DIR GIT_WORK_TREE DEVBREW_SPEC_DISTILL_DISABLE DEVBREW_SKIP_HOOKS
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid   # 펜스의 git commit
SD="$ROOT/plugins/spec-distill"
S="$SD/scripts"
RD="$S/repo_defaults.py"; RS="$S/roadmap_status.py"; CL="$S/conductor_ledger.py"
RB="$ROOT/plugins/quality-gates/scripts/resolve-baseline.sh"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
T="$(cd "$T" && pwd -P)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT

KEYS="specs_dir plans_dir roadmaps_dir interview_dir test_command test_failure_pattern review_model parallel_default branch_prefix"
RMD=docs/superpowers/roadmaps/rm
RM="$RMD/roadmap.md"

g() {  # g <레포> <git 인자…>
  local r="$1"; shift
  git -C "$r" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"
}
fence() {  # fence <파일> <마커 이름> → 그 마커 사이 첫 bash 펜스 본문
  awk -v b="<!-- $2:begin -->" -v e="<!-- $2:end -->" '
    index($0,b){f=1;next} index($0,e){f=0} f&&/^```bash$/{c=1;next} f&&c&&/^```$/{c=0;next} f&&c' "$1"
}
docs() {  # docs <작업 트리> <로드맵 폴더(레포 상대)> <R1 제목 꼬리> — brief · audit · 묶음 둘 · 로드맵
  local w="$1" d="$2"
  mkdir -p "$w/docs/br" "$w/$d"
  cat > "$w/docs/br/b.md" <<'MD'
---
type: interview-brief
user_sourced_items:
  - id: C1
    statement: "가"
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

## 3. Open Questions

- OQ1: 하나

## 4. External Landscape

- 바깥 사례 «k1» — [취함] [→ OQ1]

## 5. 기각 · Blind Spots

- 기각 — 다른 길 — verdict: refined — ST1 — 부착 1/1
- 위험 — 숨은 가정: 가정 하나 — 근거 없음

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > 처음 요청

## 7. Next Action

다음.
MD
  printf '# audit\n\n## 6. 사용자 원문\n\n- 없음\n\n## 7. 확산 원자료\n\n- 없음\n' > "$w/docs/br/b.audit.md"
  printf -- '---\ntype: epic-bundle\nepic: R1\nroadmap: %s\nsource_brief: docs/br/b.md\nids: [C1, OQ1, ST1, «k1», K1, S1]\n---\n\n# R1\n' "$d/roadmap.md" > "$w/$d/R1.md"
  printf -- '---\ntype: epic-bundle\nepic: R2\nroadmap: %s\nsource_brief: docs/br/b.md\nids: [C1, S1]\n---\n\n# R2\n' "$d/roadmap.md" > "$w/$d/R2.md"
  { printf -- '---\ntype: roadmap\nsource_brief: docs/br/b.md\n---\n\n# 로드맵\n\n## 에픽\n\n'
    printf '### R1 — 에픽 하나%s\n- 의도: 하나\n- 범위: 한다 하나 / 안 한다 없음\n- 의존: 없음\n- 브랜치: feature/r1\n- 묶음: R1.md\n- 경로 예약: src/a.txt\n\n' "$3"
    printf '### R2 — 에픽 둘\n- 의도: 둘\n- 범위: 한다 둘 / 안 한다 없음\n- 의존: R1\n- 브랜치: feature/r2\n- 묶음: R2.md\n- 경로 예약: src/b.txt\n\n'
    printf '## 지휘 절차\n\n1. fetch\n\n## 결정 기록\n\n기록 없음.\n\n## 재분해 이력\n\n- 없음\n\n## 위험 번호표\n\n- K1 — 위험 — 숨은 가정: 가정 하나 — 근거 없음\n'
  } > "$w/$d/roadmap.md"
}
mkrepo() {  # mkrepo <이름> <기본 브랜치> [레포 설정 파일 원본] — $T/<이름>/remote.git + $T/<이름>/work. 기본 브랜치에 커밋 · push · set-head
  local d="$T/$1"
  mkdir -p "$d" && git init -q --bare -b "$2" "$d/remote.git" && git init -q -b "$2" "$d/work" || return 1
  if [ -n "${3:-}" ]; then cp "$3" "$d/work/.devbrew.md" || return 1; fi
  printf 'x\n' > "$d/work/README.txt"
  g "$d/work" add -A && g "$d/work" commit -qm init && g "$d/work" remote add origin "$d/remote.git" \
    && g "$d/work" push -q origin "$2" && g "$d/work" remote set-head origin --auto >/dev/null
}
settings() {  # settings <파일> <머리말 줄…> — 레포 설정 파일 원본을 $T 에 만든다
  local f="$1"; shift
  { printf -- '---\n'; printf '%s\n' "$@"; printf -- '---\n'; } > "$f"
}
battery() {  # battery <cwd> <출력 폴더> — 비교할 명령마다 <이름>.out · .err · .rc
  local c="$1" o="$2" k
  mkdir -p "$o" || return 1
  for k in $KEYS; do
    (cd "$c" && python3 "$RD" get "$k") > "$o/get-$k.out" 2> "$o/get-$k.err"; echo "$?" > "$o/get-$k.rc"
    (cd "$c" && python3 "$RD" get "$k" --roadmap "$RM") > "$o/getr-$k.out" 2> "$o/getr-$k.err"; echo "$?" > "$o/getr-$k.rc"
  done
  (cd "$c" && python3 "$CL" roadmaps) > "$o/roadmaps.out" 2> "$o/roadmaps.err"; echo "$?" > "$o/roadmaps.rc"
  (cd "$c" && python3 "$RS" --json "$RM") > "$o/status.out" 2> "$o/status.err"; echo "$?" > "$o/status.rc"
  (cd "$c" && python3 "$RS" --json --roadmap-file "$RM") > "$o/status-file.out" 2> "$o/status-file.err"; echo "$?" > "$o/status-file.rc"
}
# 두 출력 폴더를 비교한다: 같은 이름의 파일은 바이트까지 같아야 한다. JSON 출력에 `read_tree` 가 「이 작업공간」인 칸이
# 있으면 그 칸만 자리표로 바꾼 뒤 비교한다. 다른 이름을 줄마다 stdout 에, 비교한 파일 수를 stderr 에 낸다. rc 0 같음 · 1 다름.
cat > "$T/cmp.py" <<'PY'
import json, os, sys
WS = "이 작업공간"

def strip(x):
    if isinstance(x, dict):
        if x.get("read_tree") == WS:
            return {"read_tree": WS}
        return {k: strip(v) for k, v in x.items()}
    if isinstance(x, list):
        return [strip(v) for v in x]
    return x

def view(data):
    try:
        j = json.loads(data.decode("utf-8"))
    except ValueError:
        return data
    s = strip(j)
    return data if s == j else json.dumps(s, ensure_ascii=False, sort_keys=True).encode("utf-8")

a, b = sys.argv[1], sys.argv[2]
names = sorted(set(os.listdir(a)) | set(os.listdir(b)))
diff = []
for n in names:
    pa, pb = os.path.join(a, n), os.path.join(b, n)
    if not (os.path.isfile(pa) and os.path.isfile(pb)):
        diff.append(n)
        continue
    with open(pa, "rb") as fa, open(pb, "rb") as fb:
        if view(fa.read()) != view(fb.read()):
            diff.append(n)
print("\n".join(diff))
print(len(names), file=sys.stderr)
sys.exit(1 if diff else 0)
PY
cmp_dirs() {  # cmp_dirs <A> <B> → DIFF(다른 이름들) · NCMP(비교한 파일 수) · CRC
  DIFF="$(python3 -I "$T/cmp.py" "$1" "$2" 2>"$T/cmp.err")"; CRC=$?
  NCMP="$(cat "$T/cmp.err")"
}
js() {  # js <json 파일> <파이썬 식 — r 이 보고서>. 식은 이 테스트가 쓴 고정 문자열뿐이다.
  python3 -I -c 'import json,sys; r=json.load(open(sys.argv[1],encoding="utf-8")); print(eval(sys.argv[2]))' "$1" "$2"
}
NFILES=$(( (9 * 2 + 3) * 3 ))

echo "=== 작업공간 불변 락(AC27) ==="
settings "$T/inv.devbrew.md" "interview_dir: notes/interview/" 'test_command: "true"'
mkrepo inv main "$T/inv.devbrew.md" || { no "픽스처 inv"; finish; exit 1; }
IW="$T/inv/work"
docs "$IW" "$RMD" ""
g "$IW" add -A && g "$IW" commit -qm docs && g "$IW" push -q origin main
g "$IW" worktree add -q -b feature/r1 "$T/inv/A" main && g "$IW" worktree add -q -b feature/b "$T/inv/B" main \
  || { no "픽스처 inv: worktree 둘"; finish; exit 1; }
printf 'a\n' > "$T/inv/A/src-a.txt"; g "$T/inv/A" add -A; g "$T/inv/A" commit -qm r1
settings "$T/inv/B/.devbrew.md" "interview_dir: other/" "roadmaps_dir: plan/"
docs "$T/inv/B" "$RMD" " 고침"
g "$T/inv/B" add -A; g "$T/inv/B" commit -qm "로드맵 · 설정을 자기 브랜치에서만 고침"
[ "$(g "$T/inv/A" rev-parse --abbrev-ref HEAD) $(g "$T/inv/B" rev-parse --abbrev-ref HEAD)" = "feature/r1 feature/b" ] \
  && ok "전제: 서로 다른 브랜치의 worktree 둘" || no "전제: worktree 둘의 브랜치가 다르지 않다"
[ -n "$(g "$IW" diff main feature/b -- .devbrew.md "$RM")" ] \
  && ok "전제: 한쪽 브랜치만 레포 설정 파일과 로드맵을 고쳤다" || no "전제: 고친 브랜치가 기본 브랜치와 같다 — 락이 공허하다"
battery "$T/inv/A" "$T/out-A"; battery "$T/inv/B" "$T/out-B"
cmp_dirs "$T/out-A" "$T/out-B"
assert_eq "$NCMP" "$NFILES" "불변: 비교한 파일 수(아홉 키 × 두 꼴 + 로드맵 찾기 + 상태 계산 둘, 각 stdout · stderr · rc)"
assert_eq "$CRC:$DIFF" "0:" "불변: 두 worktree 의 출력이 바이트까지 같다(읽은 트리가 이 작업공간인 칸만 뺀다)"
assert_eq "$(js "$T/out-A/status.out" "r['read_tree']")|$(js "$T/out-B/status.out" "r['read_tree']")" "기본 브랜치|기본 브랜치" \
  "불변: 경로로 준 로드맵의 상태 계산은 두 자리 다 기본 브랜치를 읽었다고 밝힌다"
assert_eq "$(js "$T/out-A/status.out" "[(b['id'], b['read_tree']) for b in r['blocks']]")" "[('R1', '에픽 끝'), ('R2', '기본 브랜치')]" \
  "읽은 트리: 진행 중인 에픽은 에픽 끝, 브랜치 없는 에픽은 기본 브랜치"
assert_eq "$(js "$T/out-A/status.out" "r['exit']")" "0" "전제: 상태 계산이 로드맵을 끝까지 셌다(검사 불가가 아니다)"
assert_contains "$(cat "$T/out-A/roadmaps.out")" "$RM" "전제: 로드맵 찾기가 로드맵을 찾았다"
assert_eq "$(cat "$T/out-A/get-interview_dir.out")" "notes/interview/" "전제: 해결자는 기본 브랜치 판의 설정 값을 낸다"
assert_eq "$(js "$T/out-A/status-file.out" "r['read_tree']")" "이 작업공간" "읽은 트리: --roadmap-file 은 이 작업공간"
if cmp -s "$T/out-A/status-file.out" "$T/out-B/status-file.out"; then
  no "빼는 칸의 증인: --roadmap-file 출력이 두 자리에서 같다 — 빼는 규칙이 하는 일이 없다"
else
  ok "빼는 칸의 증인: --roadmap-file 출력은 두 자리에서 실제로 다르다(위 같음은 그 칸을 뺀 덕이다)"
fi

echo "=== 양성 대조: 설정이 다른 두 레포는 다른 답(AC27) ==="
settings "$T/oth.devbrew.md" "interview_dir: elsewhere/" 'test_command: "true"'
mkrepo oth main "$T/oth.devbrew.md" || { no "픽스처 oth"; finish; exit 1; }
docs "$T/oth/work" "$RMD" ""
g "$T/oth/work" add -A && g "$T/oth/work" commit -qm docs && g "$T/oth/work" push -q origin main && g "$T/oth/work" switch -q -c feature/r1
battery "$T/oth/work" "$T/out-O"
cmp_dirs "$T/out-A" "$T/out-O"
assert_eq "$(cat "$T/out-O/get-interview_dir.out")" "elsewhere/" "양성 대조: 다른 레포의 get interview_dir"
assert_contains "$DIFF" "get-interview_dir.out" "양성 대조: 비교가 get interview_dir 의 차이를 본다"
assert_contains "$DIFF" "status.out" "양성 대조: 비교가 상태 계산 JSON 의 차이를 본다(빼는 칸이 전체를 덮지 않는다)"

echo "=== devbrew 밖 레포: 기본 브랜치 trunk 끝에서 끝(AC29) ==="
settings "$T/tr.devbrew.md" 'test_command: "true"'
mkrepo tr trunk "$T/tr.devbrew.md" || { no "픽스처 tr"; finish; exit 1; }
TW="$T/tr/work"
docs "$TW" "$RMD" ""
g "$TW" add -A && g "$TW" commit -qm docs && g "$TW" push -q origin trunk && g "$TW" fetch -q origin
g "$TW" switch -q -c feature/r1 && printf 'a\n' > "$TW/src-a.txt" && g "$TW" add -A && g "$TW" commit -qm r1
out="$(cd "$TW" && python3 "$RD" default-branch --check-remote 2>&1)"; rc=$?
assert_eq "$rc:$out" "0:trunk" "trunk: 기본 브랜치는 trunk(원격과 같다)"
line="$(cd "$TW" && python3 "$S/control_plane.py" statusline </dev/null 2>&1)"
assert_contains "$line" "기본 브랜치 trunk" "trunk 상태줄: 기본 브랜치 이름"
assert_contains "$line" "rm · 설계 1 · " "trunk 상태줄: 로드맵을 셌다(진행 중인 에픽 하나)"
out="$(cd "$TW" && python3 "$CL" roadmaps 2>&1)"; rc=$?
assert_eq "$rc" "0" "trunk 로드맵 찾기: rc 0"
assert_contains "$out" "$RM" "trunk 로드맵 찾기: 기본 브랜치의 로드맵"
out="$(cd "$TW" && python3 "$S/merge_check.py" run --roadmap "$RM" --branch feature/r1 2>&1)"; rc=$?
assert_eq "$rc" "0" "trunk merge_check: rc 0(원격과 대조하고 스위트 대조까지 갔다)"
assert_contains "$out" "스위트 대조 — feature/r1($(g "$TW" rev-parse --short=8 feature/r1)) 를 기본 브랜치 trunk(" "trunk merge_check: 에픽 끝을 기본 브랜치 trunk 에 합쳐 대조했다"
assert_contains "$out" "판정: 새 실패 없음" "trunk merge_check: 판정 줄"
assert_not_contains "$out" "다르다" "trunk merge_check: 원격과 다르다고 하지 않는다"
CF="$(fence "$SD/skills/pm-interview/references/finishing.md" interview-commit)"
PH='<Step A.5 의 PAYLOAD 절대경로>'
case "$CF" in *"BRIEF=\"$PH\""*) ok "전제: 끝내기 커밋 펜스에 BRIEF 자리표" ;; *) no "전제: 끝내기 커밋 펜스에 BRIEF 자리표가 없다 — 아래 칸이 공허하다" ;; esac
icommit() {  # icommit <클론> <brief 레포 상대 경로(.md)> → 끝내기 커밋 펜스 출력
  local c="$1" b="$2" s
  mkdir -p "$c/$(dirname "$b")"
  for s in .md .audit.md .state.md; do printf 'x\n' > "$c/${b%.md}$s"; done
  ( cd "$c" && CLAUDE_PLUGIN_ROOT="$SD" bash -c "${CF//"$PH"/$c/$b}" 2>&1 )
}
n0="$(g "$TW" rev-list --count HEAD)"
out="$(icommit "$TW" docs/superpowers/interview/2026-10-22-t-interview.md)"
assert_contains "$out" "brief · audit · 상태 파일을 커밋했다" "trunk 인터뷰 끝 커밋: 세 파일을 커밋했다"
assert_contains "$out" "(feature/r1)" "trunk 인터뷰 끝 커밋: 작업 브랜치에(기본 브랜치 trunk 가 아니다)"
assert_eq "$(g "$TW" rev-list --count HEAD)" "$((n0 + 1))" "trunk 인터뷰 끝 커밋: 커밋 하나"
assert_eq "$(printf '%s\n' "$out" | head -n 1)" "[spec-distill] 읽은 트리: 이 작업공간" "읽은 트리: 끝내기 커밋 펜스 출력 첫 줄"
EF="$(fence "$SD/skills/spec-review/SKILL.md" bundle-entry)"
out="$(cd "$TW" && CLAUDE_PLUGIN_ROOT="$SD" bash -c "spec_path=$TW/x-design.md; bundle_arg=; repo_root=$TW
$EF" 2>&1)"
assert_eq "$(printf '%s\n' "$out" | head -n 1)" "[spec-distill] 읽은 트리: 이 작업공간" "읽은 트리: spec-review 진입 펜스 출력 첫 줄"
assert_contains "$(printf '%s\n' "$out" | tail -n 1)" "bundle-entry: PROCEED" "양성 대조: spec-review 진입 펜스가 끝까지 돌았다"

echo "=== devbrew 밖 레포: 설정 폴더 plan/…(AC29) ==="
settings "$T/pl.devbrew.md" "specs_dir: plan/specs/" "plans_dir: plan/plans/" "roadmaps_dir: plan/roadmaps/" "interview_dir: plan/interview/"
mkrepo pl main "$T/pl.devbrew.md" || { no "픽스처 pl"; finish; exit 1; }
PW="$T/pl/work"
docs "$PW" plan/roadmaps/pl ""
docs "$PW" "$RMD" ""   # 기본 폴더의 미끼(폴더 이름 rm) — 설정 폴더 밖이라 로드맵이 아니다
g "$PW" add -A && g "$PW" commit -qm docs && g "$PW" push -q origin main && g "$PW" switch -q -c feature/r1
out="$(cd "$PW" && python3 "$CL" roadmaps 2>&1)"; rc=$?
assert_eq "$rc" "0" "plan/: 로드맵 찾기 rc 0"
assert_contains "$out" "plan/roadmaps/pl/roadmap.md" "plan/: 설정 폴더의 로드맵을 찾는다"
assert_not_contains "$out" "$RM" "plan/: 기본 폴더의 로드맵은 찾지 않는다"
line="$(cd "$PW" && python3 "$S/control_plane.py" statusline </dev/null 2>&1)"
assert_contains "$line" "pl · " "plan/ 상태줄: 설정 폴더의 로드맵을 셌다"
assert_not_contains "$line" "rm · " "plan/ 상태줄: 기본 폴더의 미끼는 세지 않는다"
out="$(cd "$PW" && python3 "$RD" get interview_dir 2>/dev/null)"
assert_eq "$out" "plan/interview/" "plan/: get interview_dir"
n0="$(g "$PW" rev-list --count HEAD)"
out="$(icommit "$PW" docs/superpowers/interview/2026-10-22-t-interview.md)"
assert_contains "$out" "커밋하지 않았다 — brief 가 정해진 인터뷰 폴더 바로 아래가 아니다" "plan/: 기본 인터뷰 폴더의 brief 는 커밋하지 않는다"
assert_eq "$(g "$PW" rev-list --count HEAD)" "$n0" "plan/: 거부하면 커밋이 없다"
out="$(icommit "$PW" plan/interview/2026-10-22-t-interview.md)"
assert_contains "$out" "brief · audit · 상태 파일을 커밋했다" "plan/: 설정 인터뷰 폴더의 brief 는 커밋한다"
assert_eq "$(g "$PW" show --name-only --pretty=format: HEAD | sed '/^$/d' | sort | tr '\n' ' ')" \
  "plan/interview/2026-10-22-t-interview.audit.md plan/interview/2026-10-22-t-interview.md plan/interview/2026-10-22-t-interview.state.md " \
  "plan/: 커밋은 설정 폴더의 세 파일"

echo "=== devbrew 밖 레포: origin 없음(AC29) ==="
NO="$T/noorigin"
mkdir -p "$NO" && git init -q -b main "$NO" && printf 'x\n' > "$NO/README.txt" && g "$NO" add -A && g "$NO" commit -qm init && g "$NO" switch -q -c feature/r1
out="$(cd "$NO" && python3 "$RD" default-branch 2>&1)"; rc=$?
assert_eq "$rc" "3" "origin 없음: default-branch rc 3"
assert_contains "$out" "git remote add origin" "origin 없음: 원격을 더하라는 안내"
out="$(cd "$NO" && python3 "$RD" get interview_dir 2>&1)"; rc=$?
assert_eq "$rc" "0" "origin 없음: get 은 멈추지 않는다(상수)"
assert_contains "$out" "값의 출처: 기본값(기본 브랜치 없음 — 설정 파일 못 읽음)(interview_dir)" "origin 없음: 상수를 쓴 출처를 밝힌다"
out="$(cd "$NO" && python3 "$CL" roadmaps 2>&1)"; rc=$?
assert_eq "$rc" "3" "origin 없음: 로드맵 찾기 rc 3"
assert_contains "$out" "git remote add origin" "origin 없음: 로드맵 찾기도 안내"
out="$(cd "$NO" && python3 "$RS" --json "$RM" 2>&1)"; rc=$?
assert_eq "$rc" "3" "origin 없음: 상태 계산 rc 3"
assert_contains "$out" "git remote add origin" "origin 없음: 상태 계산도 안내"
out="$(cd "$NO" && python3 "$S/merge_check.py" run --roadmap "$RM" --branch feature/r1 2>&1)"; rc=$?
assert_eq "$rc" "3" "origin 없음: merge_check rc 3"
assert_contains "$out" "git remote add origin" "origin 없음: merge_check 도 안내"
n0="$(g "$NO" rev-list --count HEAD)"
out="$(icommit "$NO" docs/superpowers/interview/2026-10-22-t-interview.md)"
assert_contains "$out" "커밋하지 않았다 — 기본 브랜치를 판정하지 못했다" "origin 없음: 인터뷰 끝 커밋은 멈춘다"
assert_contains "$out" "git remote add origin" "origin 없음: 인터뷰 끝 커밋도 안내"
assert_eq "$(g "$NO" rev-list --count HEAD)" "$n0" "origin 없음: 커밋하지 않았다"

echo "=== 기본 브랜치 개명(AC29 — spec-distill · qg) ==="
mkrepo ren main || { no "픽스처 ren"; finish; exit 1; }
REN="$T/ren/work"
g "$REN" switch -q -c feature/r1 && printf 'a\n' > "$REN/src-a.txt" && g "$REN" add -A && g "$REN" commit -qm r1
g "$REN" push -q origin main:trunk && git -C "$T/ren/remote.git" symbolic-ref HEAD refs/heads/trunk
g "$REN" fetch -q origin
out="$(cd "$REN" && python3 "$RD" default-branch --check-remote 2>&1)"; rc=$?
assert_eq "$rc" "5" "개명(fetch 만): spec-distill default-branch --check-remote rc 5"
assert_contains "$out" "원격 기본 브랜치(trunk)가 로컬 기본 브랜치(main)와 다르다" "개명(fetch 만): 두 이름을 함께"
git -C "$T/ren/remote.git" update-ref -d refs/heads/main
g "$REN" fetch -q --prune origin
[ -z "$(g "$REN" rev-parse --verify --quiet refs/remotes/origin/main)" ] && [ -n "$(g "$REN" symbolic-ref -q refs/remotes/origin/HEAD)" ] \
  && ok "전제: prune 뒤 origin/HEAD 가 없는 브랜치를 가리킨다(dangling)" || no "전제: origin/HEAD 가 dangling 이 아니다"
out="$(cd "$REN" && bash "$RB" 2>"$T/rb.err")"
assert_eq "$(field degraded "$out")|$(field degraded_reason "$out")" "yes|no-default-branch" "개명(prune): qg resolve-baseline 은 degraded · no-default-branch"
assert_contains "$(cat "$T/rb.err")" "git remote set-head origin --auto" "개명(prune): qg 도 고치는 법을 보인다"
out="$(cd "$REN" && python3 "$RD" default-branch 2>&1)"; rc=$?
assert_eq "$rc" "3" "개명(prune): spec-distill default-branch 는 기본 브랜치 없음 rc 3"
assert_contains "$out" "git remote set-head origin --auto" "개명(prune): spec-distill 도 같은 고치는 법"
g "$REN" remote set-head origin --auto >/dev/null
out="$(cd "$REN" && bash "$RB" 2>/dev/null)"
assert_eq "$(field degraded "$out")|$(field base_ref "$out")" "no|refs/remotes/origin/trunk" "양성 대조: set-head --auto 뒤 qg 기준은 trunk 전체 이름"

echo "=== 상태 루트 아래 추적 파일(AC29) ==="
mkrepo trk main || { no "픽스처 trk"; finish; exit 1; }
KW="$T/trk/work"
mkdir -p "$KW/.claude/spec-distill" && printf 't\n' > "$KW/.claude/spec-distill/kept.md" && g "$KW" add -f .claude/spec-distill/kept.md && g "$KW" commit -qm kept
out="$(cd "$KW" && python3 "$S/state_path.py" state-root --ensure 2>&1)"; rc=$?
assert_eq "$rc" "3" "추적 파일: state-root --ensure rc 3"
assert_contains "$out" "상태 폴더 아래 파일이 이미 추적된다 — git rm --cached -r $KW/.claude/spec-distill 로 추적을 푼 뒤 다시 돈다" "추적 파일: 고치는 법"
out="$(python3 "$CL" --root "$KW" claim --roadmap "$RM" --session sess-inv0001 2>&1)"; rc=$?
assert_eq "$rc" "3" "추적 파일: 지휘 표지 잡기도 rc 3"
[ ! -e "$KW/.claude/spec-distill/conductor" ] && ok "추적 파일: 지휘 폴더를 만들지 않았다" || no "추적 파일: 지휘 폴더가 생겼다"
g "$KW" rm -q --cached -r .claude/spec-distill && g "$KW" commit -qm untrack
out="$(cd "$KW" && python3 "$S/state_path.py" state-root --ensure 2>&1)"; rc=$?
assert_eq "$rc:$out" "0:$KW/.claude/spec-distill" "양의 짝: 추적을 풀면 rc 0"

echo "=== 레포 설정 파일이 깨짐 — BOM · 같은 키 둘 · 오타 키(AC29) ==="
printf '\357\273\277---\ninterview_dir: notes/\n---\n' > "$T/bom.devbrew.md"
settings "$T/dup.devbrew.md" "interview_dir: notes/" "interview_dir: other/"
settings "$T/typo.devbrew.md" "interveiw_dir: notes/"
settings "$T/good.devbrew.md" "interview_dir: notes/"
for c in bom dup typo good; do
  mkrepo "cfg-$c" main "$T/$c.devbrew.md" || { no "픽스처 cfg-$c"; continue; }
  g "$T/cfg-$c/work" switch -q -c feature/r1
  OUT="$(cd "$T/cfg-$c/work" && python3 "$RD" get interview_dir 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"
  ROUT="$(cd "$T/cfg-$c/work" && python3 "$CL" roadmaps 2>&1)"; RRC=$?
  case "$c" in
    bom)  assert_eq "$RC:$OUT" "3:" "BOM: get rc 3 · 값 없음"; assert_contains "$ERR" "BOM 이 있다" "BOM: 사유" ;;
    dup)  assert_eq "$RC:$OUT" "3:" "같은 키 둘: get rc 3 · 값 없음"; assert_contains "$ERR" "같은 키가 둘이다(interview_dir)" "같은 키 둘: 사유" ;;
    typo) assert_eq "$RC:$OUT" "3:" "오타 키: get rc 3 · 값 없음"; assert_contains "$ERR" "모르는 키가 있다(interveiw_dir)" "오타 키: 사유" ;;
    good) assert_eq "$RC:$OUT" "0:notes/" "양성 대조: 바른 설정 파일은 값을 낸다" ;;
  esac
  if [ "$c" = good ]; then assert_eq "$RRC:$ROUT" "2:끝나지 않은 로드맵이 없다" "양성 대조: 바른 설정이면 로드맵 찾기가 설정을 지나 폴더를 본다(로드맵 없음 rc 2)"
  else assert_eq "$RRC" "3" "${c}: 로드맵 찾기도 설정이 깨지면 멈춘다(기본 폴더로 조용히 찾지 않는다)"; fi
done

finish
