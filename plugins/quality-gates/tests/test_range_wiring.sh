#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/quality-pipeline/references/differential-test.md plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md plugins/quality-gates/README.md
# test_range_wiring.sh — 범위 모드(range <시작>[..<끝>])가 파이프라인 전체에 이어져 있다(AC21 · AC22).
#
# 문면 락은 각 사실이 적힌 절 창 안에서 잰다(제목이 대신 만족시키지 못하게). 끝에서 끝 사슬은
# 실제 스크립트와 SKILL · reference 의 펜스를 시작 커밋에 체크아웃한 픽스처에서 돌려 모든 소비자가
# 같은 두 커밋(diff 기준 · 차등 기준선 = <시작>, HEAD 축 · 판정 커밋 = <끝>)을 쓰는지 본다.
set -u
[ "${1:-}" = "--emit-scanned" ] && { printf '%s\n' \
  plugins/quality-gates/skills/quality-pipeline/SKILL.md \
  plugins/quality-gates/skills/quality-pipeline/references/differential-test.md \
  plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md \
  plugins/quality-gates/README.md; exit 0; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"
SK="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
DT="$PLUGIN_ROOT/skills/quality-pipeline/references/differential-test.md"
SF="$PLUGIN_ROOT/skills/quality-pipeline/references/state-file-format.md"
RM="$PLUGIN_ROOT/README.md"
export PYTHONDONTWRITEBYTECODE=1

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

# 펜스 뽑기 — stdin 의 글에서 본문에 needle 이 든 첫 ```bash 펜스(들여쓰기를 걷어 낸 본문).
# 파이썬 본문은 `$( )` 안 heredoc 으로 두지 않는다 — 최상위 heredoc 으로 변수에 담는다.
IFS= read -r -d '' PY_FENCE <<'PY' || true
import re, sys, textwrap
text = sys.stdin.read()
needle = sys.argv[1]
lines = text.splitlines()
open_re = re.compile(r'^[ \t]*```bash\s*$')
close_re = re.compile(r'^[ \t]*```\s*$')
i = 0
while i < len(lines):
    if open_re.match(lines[i]):
        j = i + 1
        body = []
        while j < len(lines) and not close_re.match(lines[j]):
            body.append(lines[j])
            j += 1
        if any(needle in l for l in body):
            print(textwrap.dedent("\n".join(body)))
            break
        i = j + 1
    else:
        i += 1
PY
fence_with() { python3 -I -X utf8 -c "$PY_FENCE" "$1"; }

# 판정 펜스 셋(일반 · trivia · scope-empty) — verdict.py 를 부르는 펜스마다 SHA_ARG 를 쓰는가
IFS= read -r -d '' PY_VERDICT_FENCES <<'PY' || true
import re, sys
text = sys.stdin.read()
lines = text.splitlines()
open_re = re.compile(r'^[ \t]*```bash\s*$')
close_re = re.compile(r'^[ \t]*```\s*$')
sha_line = ('SHA_ARG="$(git rev-parse --short HEAD)"; RS="$RD/range-scope.txt"; '
            'if [ -f "$RS" ]; then SHA_ARG="$(git rev-parse --short "$(sed -n \'s/^end: //p\' "$RS")")"; fi')
fences = []
i = 0
while i < len(lines):
    if open_re.match(lines[i]):
        j = i + 1
        body = []
        while j < len(lines) and not close_re.match(lines[j]):
            body.append(lines[j].strip())
            j += 1
        fences.append(body)
        i = j + 1
    else:
        i += 1
vf = [b for b in fences if any('scripts/verdict.py' in l for l in b)]
print("VERDICT_FENCES:%d" % len(vf))
good = 0
for b in vf:
    s = [k for k, l in enumerate(b) if l == sha_line]
    v = [k for k, l in enumerate(b) if 'scripts/verdict.py' in l]
    calls = " ".join(b[v[0]:]) if v else ""
    if len(s) == 1 and v and s[0] < v[0] and '--sha "$SHA_ARG"' in calls and '--short HEAD)" --e2e' not in calls:
        good += 1
print("SHA_ARG_FENCES:%d" % good)
PY

g() {   # g <repo> <git args…> — 전역 설정에 기대지 않는 커밋
  local r="$1"; shift
  git -C "$r" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "$@"
}

# ── 문면 락 ─────────────────────────────────────────────────────────────

case_text_locks() {
  echo "[문면 — SKILL]"
  assert_grep "$(sed -n '1,20p' "$SK")" '^argument-hint: .*range <시작>\[\.\.<끝>\]' "인자 안내에 range 가 있다 — R5 가 이것으로 범위 입력 여부를 정한다"
  assert_grep "$(awk '/^\*\*P2 — /{f=1} /^\*\*P2b — /{f=0} f' "$SK")" '^Arguments: .*`range <시작>\[\.\.<끝>\]`.*origin/HEAD' "Arguments 줄: range 와 끝 생략 = origin/HEAD"

  local P2B; P2B="$(awk '/^\*\*P2b — /{f=1} /^\*\*P3 — /{f=0} f' "$SK")"
  [ -n "$P2B" ] && ok "P2b 창이 있다(양성 짝)" || no "P2b 창이 없다 — 아래 단언이 공허하다"
  assert_contains "$P2B" 'resolve-range.sh" --out "$RD/range-scope.txt" -- $ARGUMENTS' "P2b 가 범위를 한 번 얼린다"
  assert_contains "$P2B" '범위를 풀지 못했다' "P2b: 못 풀면 판정 없이 멈추는 줄"
  assert_contains "$P2B" '리뷰 범위: <start 앞 12자>..<end 앞 12자>' "P2b: 풀리면 범위 한 줄을 낸다"
  assert_contains "$(awk '/^\*\*P2 — /{f=1} /^\*\*P2b — /{f=0} f && /^rm -f /' "$SK")" '"$RD/range-scope.txt"' "P2 가 앞 실행의 range-scope.txt 를 지운다"

  # 리뷰어가 읽는 트리(final-review I1) — 범위 모드의 리뷰어 · codex · 재비판은 끝 커밋을 읽는다.
  assert_contains "$(awk '/^\*\*P2 — /{f=1} /^\*\*P2b — /{f=0} f && /^rm -f /' "$SK")" '"$RD/review-tree.txt"' "P2 가 앞 실행의 review-tree.txt 를 지운다"
  assert_contains "$P2B" ' · 리뷰어가 읽는 트리: 끝 커밋의 임시 트리.`' "P2b: 범위 줄이 리뷰어가 읽는 트리(늘 끝 커밋의 임시 트리)를 밝힌다"
  # 보안 리뷰 S4 — head_is_end 로 갈라 체크아웃을 넘기던 지름길이 없다(펜스 본문 · SKILL 전체). 양성 짝은 위 create-head 줄.
  assert_not_contains "$(printf '%s\n' "$P2B" | fence_with 'review_tree:')" 'head_is_end' "P2b 리뷰 트리 펜스: head_is_end 로 갈라지지 않는다"
  assert_eq "$(grep -c 'review_tree: checkout' "$SK")" "0" "SKILL: 지금 체크아웃을 리뷰 트리로 내는 갈래가 없다"
  assert_contains "$P2B" '범위 모드는 늘 끝 커밋의 임시 트리를 하나 만들어 그 경로를 `project_dir` 로 쓴다 — 지금 체크아웃이 범위 끝이어도(`head_is_end: yes`) 그렇다.' "P2b: 체크아웃이 끝이어도 임시 트리(규칙 줄)"
  assert_contains "$(printf '%s\n' "$P2B" | fence_with 'review_tree:')" 'RT="$("$QG/scripts/qg-worktree.sh" create-head "$(sed -n '"'s/^end: //p'"' "$RS")" "<session-id>" --range "$RS")"' \
    "P2b 리뷰 트리 펜스: 끝 커밋으로 create-head --range 를 부른다"
  assert_contains "$P2B" '- `review_tree: <경로>` 의 그 경로가 이 실행의 `project_dir` 이다' "P2b: 임시 트리 경로가 project_dir 가 된다(규칙 줄)"
  assert_contains "$P2B" '지금 체크아웃으로 대신하지 않는다' "P2b: 트리를 못 만들면 체크아웃으로 대신하지 않는다(규칙 줄)"
  assert_contains "$(awk '/^\*\*P0 — /{f=1} /^\*\*P0b — /{f=0} f' "$SK")" '범위 모드만 예외가 하나다 — P2b 의 리뷰 트리 펜스가 낸 `review_tree: <경로>`(끝 커밋의 임시 트리)가 이 실행의 `project_dir` 이다' \
    "P0: 범위 모드의 project_dir 예외"
  local S3W; S3W="$(awk '/^### Step 3 — reviewers$/{f=1;next} f&&/^### Step 3\.5/{exit} f' "$SK")"
  assert_contains "$S3W" '- `PROJECT_DIR` = P0 의 `project_dir` — 범위 모드에서 P2b 의 리뷰 트리 펜스가 `review_tree: <경로>` 를 냈으면 그 경로다.' \
    "Step 3: 모든 dispatch 의 PROJECT_DIR 는 범위 모드의 리뷰 트리 경로"
  assert_contains "$(awk '/^\*\*다른 전제 각도 — codex/{f=1} f&&/^\*\*Capture the runner/{exit} f' "$SK")" '`<project_dir>` 는 Step 3 의 `PROJECT_DIR` 다(범위 모드의 리뷰 트리면 그 경로 — 러너가 그리로 `cd` 한다)' \
    "Step 3: codex 러너의 project_dir 도 리뷰 트리"
  assert_contains "$(awk '/^### Step 3\.5 /{f=1;next} f&&/^### Step 4 /{exit} f' "$SK")" '`<project_dir>` = Step 3 의 `PROJECT_DIR`' "Step 3.5: 재비판의 project_dir 도 리뷰 트리"
  assert_contains "$(awk '/^## Final verdict$/{f=1;next} f&&/^## Publish$/{exit} f' "$SK" | fence_with 'review-tree.txt')" \
    'if "$QG/scripts/qg-worktree.sh" remove "$(cat "$RD/review-tree.txt")"; then' "Final verdict: 리뷰 트리를 지우는 펜스"
  # 지우기 실패 안내 — 세션 정리(qg-gc.py)는 worktrees/ 를 건드리지 않는다. 거짓 약속이 없고 직접 지우는 명령이 있다(양의 짝).
  local RMF; RMF="$(awk '/^## Final verdict$/{f=1;next} f&&/^## Publish$/{exit} f' "$SK" | fence_with 'review-tree.txt')"
  assert_not_contains "$RMF" '세션 정리가 회수' "Final verdict: 지우기 실패 안내가 세션 정리가 회수한다고 약속하지 않는다"
  assert_not_contains "$(cat "$SK" "$RM" "$SF")" '오래된 세션 정리가 회수' "SKILL · README · state-file-format: 리뷰 트리를 세션 정리가 회수한다는 문장이 없다"
  assert_contains "$RMF" "git worktree remove --force \$(cat \"\$RD/review-tree.txt\")" "Final verdict: 실패 안내가 git worktree remove 와 실제 경로 변수를 보인다"
  assert_not_contains "$(cat "$RM")" '리뷰 diff · 의도 출처 · codex · 차등 테스트 · 판정 줄이 모두 같은 두 커밋을 쓴다 — diff 의 기준과 차등 테스트 기준선은 시작 커밋, HEAD 축과 판정 줄의 커밋은 끝 커밋이다. 지금 작업 트리는 보지 않는다.' \
    "README: 리뷰어가 작업 트리를 보지 않는다던 틀린 문장이 없다"
  assert_contains "$(cat "$RM")" '리뷰어 · codex 가 diff 밖 코드를 열어 볼 때도 끝 커밋을 본다 — 지금 체크아웃이 끝 커밋이어도 늘 끝 커밋의 임시 트리를 하나 만들어 읽고(커밋 안 된 변경 · 추적 안 된 파일을 리뷰어가 읽지 않게 한다, 실행 끝에 지운다), 그 트리를 만들지 못하면 판정 없이 멈춘다.' \
    "README: 리뷰어가 읽는 트리(옛 문장 부재의 양성 짝)"

  local P3W; P3W="$(awk '/^\*\*P3 — /{f=1} /^## Flow/{f=0} f' "$SK")"
  assert_contains "$P3W" '설계문서 N개' "P3: 여러 설계문서의 의도 줄"
  # 위 단언은 형식 줄(`<spec 첫 제목 | 설계문서 N개 …>`)로도 채워진다 — 규칙 문단 자신의 글을 잰다
  assert_contains "$P3W" 'paths in `specs`, the tail is `설계문서 N개 (<경로> · <경로> …)`' "P3: 둘 이상이면 꼬리가 설계문서 N개다(규칙 문단)"
  assert_contains "$P3W" "Do not take the intent file's first heading then" "P3: 여러 문서면 의도 파일의 첫 제목을 쓰지 않는다(규칙 문단)"
  assert_contains "$(printf '%s\n' "$P3W" | fence_with ' --range ')" '"$QG/scripts/discover-spec.sh" --intent-out "$RD/intent.md" --range "$(sed -n '"'s/^start: //p'"' "$RS")" "$(sed -n '"'s/^end: //p'"' "$RS")"' \
    "P3: 범위 모드 펜스가 얼린 두 커밋으로 discover-spec 을 부른다"

  local S1; S1="$(awk '/^### Step 1 — scope$/{f=1;next} f&&/^### Step 1b/{exit} f' "$SK")"
  assert_grep "$S1" '^ *\| range \| `--mode range --scope-file "\$RD/range-scope\.txt"` \|$' "Step 1c 표: range 행이 범위 파일을 넘긴다"
  assert_contains "$S1" '범위 모드는 1a 를 돌리지 않는다' "Step 1: 범위 모드는 override — 1a 를 돌리지 않는다"
  assert_contains "$(awk '/^### Step 1b /{f=1;next} f&&/^### Step 3 /{exit} f' "$SK")" '범위 모드는 `check-review-scope.sh` 를 돌리지 않는다' "Step 1b: 범위 모드는 건너뛴다"
  # final-review M1 — 반복 상한은 5 고정이 아니다(CAP) — 캐시를 다시 쓰는 반복을 숫자로 묶지 않는다
  assert_contains "$(awk '/^### Step 1b /{f=1;next} f&&/^### Step 3 /{exit} f' "$SK")" '`$degraded` for the turn — later iterations (up to CAP) reuse them.' "Step 1b: 뒤 반복(CAP 까지)이 캐시를 다시 쓴다"
  assert_not_contains "$(awk '/^### Step 1b /{f=1;next} f&&/^### Step 3 /{exit} f' "$SK")" 'iterations 2–5' "Step 1b: 반복 2–5 로 묶던 옛 문구가 없다"
  assert_contains "$(awk '/^\*\*다른 전제 각도 — codex/{f=1} f&&/^\*\*Capture the runner/{exit} f' "$SK")" '<산출물 경로> --range "$(sed -n '"'s/^start: //p'"' "$RD/range-scope.txt")" "$(sed -n '"'s/^end: //p'"' "$RD/range-scope.txt")"' "Step 3: codex 러너에 범위 파일의 두 커밋을 sed 로 넘긴다"
  assert_contains "$(awk '/^### Step 4\.5 /{f=1;next} f&&/^---$/{exit} f' "$SK")" '`$RD/range-scope.txt` 를 그대로' "Step 4.5: 범위 모드면 범위 파일을 판정 꼬리 뒤에 보인다"

  local FL; FL="$(awk '/^### Fix-loop decision$/{f=1;next} f&&/^### Max-iter/{exit} f' "$SK")"
  assert_contains "$FL" '범위 모드' "Fix-loop: 범위 모드 갈래가 있다(양성 짝)"
  assert_contains "$FL" '범위 모드는 반복 1 에서 끝나므로 Max-iter 에 닿지 않는다' "Fix-loop: 범위 모드는 Max-iter 에 닿지 않는다"
  # 범위 모드 질문의 선택지 줄들에 「고치고 다시 돌기」가 없다 — 범위 갈래 블록(그 질문을 담은 펜스)을 잘라 잰다
  local RB; RB="$(printf '%s\n' "$FL" | awk '/^\*\*범위 모드 갈래/{f=1} f' | awk '/^```$/{n++; if(n==1){f=1;next} if(n==2){exit}} f')"
  assert_contains "$RB" '범위 모드는 이미 있는 커밋을 본다 — 고칠 것은 새 브랜치에서 고친다. 어떻게 끝낼까?' "범위 갈래: 질문 문구(양성 짝)"
  assert_contains "$RB" 'label: "지금 판정으로 끝내기"' "범위 갈래: 「지금 판정으로 끝내기」 선택지"
  assert_contains "$RB" 'label: "멈추기"' "범위 갈래: 「멈추기」 선택지"
  assert_not_contains "$RB" '고치고 다시 돌기' "범위 갈래: 「고치고 다시 돌기」 선택지가 없다"
  assert_not_contains "$RB" 'header: "분류"' "범위 갈래: 분류 질문이 없다"

  local E2; E2="$(awk '/^## e2e$/{f=1;next} f&&/^\*\*E0/{exit} f' "$SK")"
  assert_contains "$E2" '범위 모드' "e2e: 범위 모드는 걷지 않는다"
  assert_contains "$E2" '> [quality-gates] 범위 모드라 앱을 걷지 않는다 — 지금 체크아웃이 범위 끝과 다를 수 있다.' "e2e: 걷지 않는 이유를 공시한다"

  local FV; FV="$(awk '/^## Final verdict$/{f=1;next} f&&/^## Publish$/{exit} f' "$SK")"
  assert_count_ge "printf '%s\n' \"\$FV\" | grep -c 'range-scope.txt'" 3 "판정 펜스(일반 · trivia · scope-empty)가 범위 모드면 끝 커밋을 쓴다"
  local vf; vf="$(printf '%s\n' "$FV" | python3 -I -X utf8 -c "$PY_VERDICT_FENCES")"
  assert_grep "$vf" '^VERDICT_FENCES:3$' "판정 펜스는 셋이다(양성 짝)"
  assert_grep "$vf" '^SHA_ARG_FENCES:3$' "판정 펜스 셋 모두 verdict.py 앞에서 SHA_ARG 를 정하고 --sha 에 그것을 넘긴다"
  assert_eq "$(printf '%s\n' "$FV" | grep -cF -- '--sha "$(git rev-parse --short HEAD)"')" "0" "판정 펜스에 HEAD 를 바로 넘기는 --sha 가 남지 않았다"
  assert_contains "$(printf '%s\n' "$FV" | fence_with "printf '\n## 판정")" "if [ -f \"\$RD/range-scope.txt\" ]; then printf '\n## 범위\n\n'; cat \"\$RD/range-scope.txt\"; fi" "기록 펜스: 범위 모드면 ## 범위 절을 남긴다"

  local PB; PB="$(awk '/^## Publish$/{f=1;next} f&&/^## kill switch$/{exit} f' "$SK")"
  assert_contains "$PB" '게시 안 함 — 범위 모드라 PR 코멘트를 달지 않는다' "게시: 범위 모드는 달지 않고 공시한다"
  # 범위 거절은 게시 펜스 하나 안에 있다 — 「한 번만」 검사 뒤, OUTCOME 갈래 앞(aborted 여도 범위 공시 · sink 에 닿지 않음)
  local pf; pf="$(printf '%s\n' "$PB" | fence_with 'scripts/publish-comment.sh')"
  local l_once l_rng l_case
  l_once="$(printf '%s\n' "$pf" | grep -n "^if grep -qx '## 게시' \"\$RESULT\"" | head -n 1 | cut -d: -f1)"
  l_rng="$(printf '%s\n' "$pf" | grep -nxF 'if [ -f "$D/range-scope.txt" ]; then' | head -n 1 | cut -d: -f1)"
  l_case="$(printf '%s\n' "$pf" | grep -nxF 'case "$OUTCOME" in' | head -n 1 | cut -d: -f1)"
  if [ -n "$l_once" ] && [ -n "$l_rng" ] && [ -n "$l_case" ] && [ "$l_once" -lt "$l_rng" ] && [ "$l_rng" -lt "$l_case" ]; then
    ok "게시 펜스: 범위 거절이 「한 번만」 검사 뒤 · OUTCOME 갈래 앞에 있다"
  else no "게시 펜스: 범위 거절 위치 (once=$l_once range=$l_rng case=$l_case)"; fi
  assert_eq "$(printf '%s\n' "$PB" | grep -c '범위 모드라 PR 코멘트를 달지 않는다(범위에는')" "2" "게시: 범위 문구는 설명 한 줄 + 게시 펜스 한 줄뿐이다(따로 떨어진 범위 펜스가 없다)"

  echo "[문면 — differential-test.md · state-file-format.md]"
  assert_file_grep "$DT" 'scope0=range' "D0: 범위 모드의 기준선은 시작 커밋"
  # 위 단언은 D0 아래 설명 줄(`scope0=range` 이면 …)로도 채워진다 — 펜스 본문의 판별 줄을 따로 잰다
  assert_contains "$(fence_with 'scope0=' < "$DT")" "printf 'scope0=range\\nboundary=%s\\n' \"\$(sed -n 's/^start: //p' \"\$RS\")\"" "D0 펜스: 범위면 시작 커밋을 기준선으로 찍는다"
  assert_file_grep "$DT" '\-\-range "\$RD/range-scope.txt"' "D1: HEAD 축은 create-head --range"
  assert_file_grep "$DT" '\-\-topic <start> <end>' "D2: 범위의 후보는 --topic <start> <end>"
  assert_file_grep "$DT" '\-\-total \-\-tree <end>' "D2: 범위의 분모는 --total --tree <end>"
  # 위 둘은 산문이다 — D2 펜스 본문이 범위 파일에서 두 커밋을 읽어 넘기는지 따로 잰다
  local d2; d2="$(fence_with 'compute-test-scope-candidates.sh" --topic' < "$DT")"
  assert_contains "$d2" "b=\$(sed -n 's/^start: //p' \"\$RS\"); t=\$(sed -n 's/^end: //p' \"\$RS\")" "D2 펜스: 범위면 시작 · 끝을 범위 파일에서 읽는다"
  assert_contains "$d2" '"$QG/scripts/compute-test-scope-candidates.sh" --topic "$b" "$t"; echo "candidates rc=$?"' "D2 펜스: 후보는 --topic <시작> <끝>"
  assert_contains "$d2" '"$QG/scripts/compute-test-scope-candidates.sh" --total --tree "$t"; echo "total rc=$?"' "D2 펜스: 분모는 --total --tree <끝>"
  assert_file_grep "$SF" '^## 범위$' "state-file-format: ## 범위 절"
  assert_contains "$(awk '/^같은 폴더의 다른 파일/{f=1} f' "$SF")" '`range-scope.txt`' "state-file-format: 다른 파일 목록에 range-scope.txt"
  assert_contains "$(awk '/^같은 폴더의 다른 파일/{f=1} f' "$SF")" '`review-tree.txt`' "state-file-format: 다른 파일 목록에 review-tree.txt"
}

# 범위 모드의 리뷰어가 읽는 트리(final-review I1 · 보안 리뷰 S4) — 체크아웃이 시작이든 끝이든, 커밋 안 된 변경과
# 추적 안 된 파일이 있어도 리뷰어는 늘 끝 커밋의 임시 트리를 읽는다. P2b · 리뷰 트리 · 지우기 펜스를 그대로 돌린다.
case_review_tree() {
  echo "[리뷰 트리 — 펜스]"
  local sid=sid12345 p2b tree rmf out rc rt where
  rt_run() {   # rt_run <본문> — R 에서 플러그인 루트를 주고 돌린다. out · rc 를 채운다.
    printf '%s\n' "$1" > "$ROOT/rt.sh"
    out=$(cd "$R" && CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$ROOT/rt.sh" 2>"$ROOT/rt.err"); rc=$?
  }
  local P2B; P2B="$(awk '/^\*\*P2b — /{f=1} /^\*\*P3 — /{f=0} f' "$SK")"
  p2b="$(printf '%s\n' "$P2B" | fence_with 'resolve-range.sh')"
  tree="$(printf '%s\n' "$P2B" | fence_with 'review_tree:' | LC_ALL=C sed "s/<session-id>/$sid/g")"
  rmf="$(awk '/^## Final verdict$/{f=1;next} f&&/^## Publish$/{exit} f' "$SK" | fence_with 'review-tree.txt' | LC_ALL=C sed "s/<session-id>/$sid/g")"
  [ -n "$tree" ] && ok "P2b 의 리뷰 트리 펜스를 뽑았다" || no "P2b 에 리뷰 트리 펜스(review_tree:)가 없다"
  [ -n "$rmf" ] && ok "Final verdict 의 리뷰 트리 지우기 펜스를 뽑았다" || no "Final verdict 에 리뷰 트리 지우기 펜스가 없다"

  for where in end start; do
    # 체크아웃을 끝(where=end) 또는 시작(where=start)에 두고, 추적 파일을 고치고 추적 안 된 파일을 둔다
    mkfix
    if [ "$where" = end ]; then git -C "$R" checkout -q --detach "$E"; fi
    rt_run "$(printf '%s\n' "$p2b" | LC_ALL=C sed -e "s/<session-id>/$sid/g" -e "s/\\\$ARGUMENTS/range $S/g")"
    if [ "$where" = end ]; then
      assert_eq "$(sed -n 's/^head_is_end: //p' "$F" 2>/dev/null)" "yes" "[$where] 전제: 체크아웃이 범위 끝이다(head_is_end 는 그대로 공시된다)"
    else
      assert_eq "$(sed -n 's/^head_is_end: //p' "$F" 2>/dev/null)" "no" "[$where] 전제: 체크아웃(시작 커밋)은 범위 끝이 아니다"
    fi
    printf '# dirty\n' > "$R/README.md"; printf 'x\n' > "$R/untracked-probe.txt"
    rt_run "$tree"
    assert_eq "$rc" "0" "[$where] 리뷰 트리 펜스 rc 0"
    assert_eq "$(printf '%s\n' "$out" | grep -c '^review_tree: checkout$')" "0" "[$where] 지금 체크아웃을 리뷰어에게 넘기지 않는다"
    rt="$(printf '%s\n' "$out" | sed -n 's/^review_tree: //p')"
    if [ -n "$rt" ] && [ -d "$rt" ]; then
      assert_eq "$(git -C "$rt" rev-parse HEAD)" "$E" "[$where] 리뷰 트리의 HEAD = 끝 커밋"
      assert_eq "$(cat "$rt/README.md")" "# a" "[$where] 커밋 안 된 추적 변경이 리뷰 트리에 없다"
      [ ! -e "$rt/untracked-probe.txt" ] && ok "[$where] 추적 안 된 파일이 리뷰 트리에 없다" || no "[$where] 추적 안 된 파일이 리뷰 트리에 있다"
      assert_eq "$(cat "$R/README.md")" "# dirty" "[$where] 체크아웃의 변경은 그대로다"
      assert_eq "$(cat "$D/review-tree.txt" 2>/dev/null)" "$rt" "[$where] review-tree.txt 에 그 경로를 남긴다"
      rt_run "$rmf"
      [ ! -d "$rt" ] && ok "[$where] 지우기 펜스가 리뷰 트리를 지웠다" || no "[$where] 리뷰 트리가 남았다: $rt"
      [ ! -e "$D/review-tree.txt" ] && ok "[$where] 지우기 펜스가 review-tree.txt 도 지웠다" || no "[$where] review-tree.txt 가 남았다"
    else
      no "[$where] 끝 커밋의 임시 트리를 내지 않았다 (out: $out · err: $(cat "$ROOT/rt.err"))"
    fi
  done

  # 트리를 못 만들면 0 이 아닌 값으로 멈춘다 — 체크아웃으로 대신하지 않는다
  cp "$F" "$ROOT/rs.bak"
  sed 's/^end: .*/end: 0000000000000000000000000000000000000000/' "$ROOT/rs.bak" > "$F"
  rt_run "$tree"
  [ "$rc" -ne 0 ] && ok "트리를 못 만들면 0 이 아닌 값으로 끝난다 (rc $rc)" || no "트리를 못 만들었는데 rc 0"
  assert_not_contains "$out" 'review_tree:' "못 만들면 리뷰 트리 줄을 내지 않는다(체크아웃으로 대신하지 않는다)"
  [ ! -e "$D/review-tree.txt" ] && ok "못 만들면 review-tree.txt 가 없다" || no "못 만들었는데 review-tree.txt 가 있다"
  assert_contains "$(cat "$ROOT/rt.err")" '지금 체크아웃으로 대신하지 않고 멈춘다' "못 만들면 멈춤 줄을 낸다"
  rm -f "$D/review-tree.txt"; rt_run "$rmf"
  assert_eq "$rc" "0" "지울 트리가 없으면 지우기 펜스는 아무 일 없이 끝난다"
}


# ── 끝에서 끝 사슬 ───────────────────────────────────────────────────────
# 픽스처: 레포 A(trunk: S → c1(설계 a · 코드) → E(설계 b · tests/test_x.sh 100755)) · 클론 R 을 S 에 체크아웃.
# 전역 A R S E D F 를 채운다.
mkfix() {
  local d; d=$(mktemp -d "$ROOT/fix.XXXXXX")
  A="$d/A"; R="$d/R"
  git init -q -b trunk "$A"
  echo "# a" > "$A/README.md"; g "$A" add README.md; g "$A" commit -q -m c0
  S=$(git -C "$A" rev-parse HEAD)
  mkdir -p "$A/docs/specs" "$A/src" "$A/tests"
  printf '# A 설계\n- a\n' > "$A/docs/specs/a-design.md"
  printf 'echo x\n' > "$A/src/x.sh"
  g "$A" add -A; g "$A" commit -q -m "feat: x" -m "Spec: docs/specs/a-design.md"
  printf '# B 설계\n- b\n' > "$A/docs/specs/b-design.md"
  printf '#!/bin/sh\n. ./src/x.sh\n' > "$A/tests/test_x.sh"; chmod +x "$A/tests/test_x.sh"
  g "$A" add -A; g "$A" commit -q -m "test: x" -m "Spec: docs/specs/b-design.md"
  E=$(git -C "$A" rev-parse HEAD)
  git clone -q "$A" "$R"
  git -C "$R" checkout -q --detach "$S"
  D="$R/.claude/quality-gates/sid12345"; mkdir -p "$D"; F="$D/range-scope.txt"
}

specs_of() {   # 읽을 수 없는 JSON 은 빈 줄 — 단언이 실패로 센다
  python3 -I -X utf8 -c '
import json, sys
try:
    print(" ".join(json.loads(sys.stdin.read())["specs"]))
except Exception:
    print("")'
}

case_chain_agrees() {
  echo "[사슬 — 스크립트]"
  mkfix
  assert_eq "$(git -C "$R" rev-parse HEAD)" "$S" "전제: R 은 시작 커밋에 체크아웃돼 있다"
  assert_eq "$(git -C "$A" ls-files -s tests/test_x.sh | cut -c1-6)" "100755" "전제: tests/test_x.sh 는 실행 비트가 있다"
  local out rc
  out=$(cd "$R" && bash "$PLUGIN_ROOT/scripts/resolve-range.sh" --out "$F" -- range "$S" 2>"$ROOT/err"); rc=$?
  assert_eq "$rc" "0" "resolve-range rc 0"
  assert_eq "$(sed -n 's/^start: //p' "$F")" "$S" "범위 파일 start = S"
  assert_eq "$(sed -n 's/^end: //p' "$F")" "$E" "범위 파일 end = E (origin/HEAD)"
  assert_eq "$(sed -n 's/^end_from: //p' "$F")" "origin/HEAD" "끝을 생략하면 origin/HEAD 에서 온다"

  out=$(cd "$R" && bash "$PLUGIN_ROOT/scripts/review-diff.sh" --dir "$D" --iter 1 --mode range --scope-file "$F" 2>"$ROOT/err"); rc=$?
  assert_eq "$rc" "0" "review-diff rc 0"
  assert_eq "$(field base "$out")" "$S" "review-diff 의 base: = S"
  assert_eq "$(field head "$out")" "$E" "review-diff 의 head: = E"
  assert_file_grep "$D/review-i1.names" '^src/x\.sh$' "리뷰 diff 에 범위 안 코드 변경이 있다"

  out=$(cd "$R" && bash "$PLUGIN_ROOT/scripts/discover-spec.sh" --intent-out "$D/intent.md" --range "$S" "$E" 2>"$ROOT/err"); rc=$?
  assert_eq "$rc" "0" "discover-spec rc 0"
  assert_eq "$(printf '%s' "$out" | specs_of)" "docs/specs/a-design.md docs/specs/b-design.md" "specs 둘, 커밋 순서"
  assert_file_grep "$D/intent.md" '^<!-- qg-spec 2/2: docs/specs/b-design\.md -->$' "의도 파일에 문서 구분 줄이 있다"

  out=$(cd "$R" && bash "$PLUGIN_ROOT/scripts/compute-test-scope-candidates.sh" --topic "$S" "$E" 2>"$ROOT/err"); rc=$?
  assert_eq "$rc" "0" "후보 rc 0"
  assert_grep "$out" '^tests/test_x\.sh$' "후보에 tests/test_x.sh"

  local ht
  ht=$(cd "$R" && bash "$PLUGIN_ROOT/scripts/qg-worktree.sh" create-head "$E" sid12345 --range "$F" 2>"$ROOT/err"); rc=$?
  assert_eq "$rc" "0" "create-head --range rc 0"
  if [ -n "$ht" ] && [ -d "$ht" ]; then
    assert_eq "$(git -C "$ht" rev-parse HEAD)" "$E" "HEAD 축 트리의 HEAD = E"
    (cd "$R" && bash "$PLUGIN_ROOT/scripts/qg-worktree.sh" remove "$ht" >/dev/null 2>&1)
    [ ! -d "$ht" ] && ok "만든 트리를 지웠다" || no "만든 트리가 남았다: $ht"
  else
    no "HEAD 축 트리를 만들지 못했다: $(cat "$ROOT/err")"
  fi
}

# 같은 사슬을 SKILL · reference 의 펜스 그대로 — 펜스가 스크립트에 넘기는 값이 범위 파일의 두 커밋인가
case_fences_agree() {
  echo "[사슬 — 펜스]"
  mkfix
  local sid=sid12345 body out rc
  run_fence() {   # run_fence <본문> — R 에서 플러그인 루트를 주고 돌린다. out · rc 를 채운다.
    printf '%s\n' "$1" > "$ROOT/fence.sh"
    out=$(cd "$R" && CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$ROOT/fence.sh" 2>"$ROOT/err"); rc=$?
  }

  body="$(awk '/^\*\*P2b — /{f=1} /^\*\*P3 — /{f=0} f' "$SK" | fence_with 'resolve-range.sh')"
  [ -n "$body" ] && ok "P2b 펜스를 뽑았다" || no "P2b 펜스가 없다"
  body="$(printf '%s\n' "$body" | LC_ALL=C sed -e "s/<session-id>/$sid/g" -e "s/\\\$ARGUMENTS/range $S/g")"
  run_fence "$body"
  assert_contains "$out" 'range rc=0' "P2b 펜스: range rc=0"
  assert_eq "$(sed -n 's/^end: //p' "$F" 2>/dev/null)" "$E" "P2b 펜스가 범위 파일을 세션 폴더에 썼다(end = E)"

  body="$(awk '/^\*\*P3 — /{f=1} /^## Flow/{f=0} f' "$SK" | fence_with ' --range ' | LC_ALL=C sed "s/<session-id>/$sid/g")"
  run_fence "$body"
  assert_contains "$out" 'intent rc=0' "P3 범위 펜스: intent rc=0"
  assert_eq "$(printf '%s\n' "$out" | grep '^{' | specs_of)" "docs/specs/a-design.md docs/specs/b-design.md" "P3 범위 펜스: specs 둘"

  body="$(fence_with 'scope0=' < "$DT" | LC_ALL=C sed "s/<session-id>/$sid/g")"
  run_fence "$body"
  assert_grep "$out" '^scope0=range$' "D0 펜스: scope0=range"
  assert_grep "$out" "^boundary=$S\$" "D0 펜스: 기준선 커밋 = S"

  body="$(fence_with 'create-head' < "$DT" | LC_ALL=C sed -e "s/<session-id>/$sid/g" -e 's/<D0 의 스코프: [^>]*>/range/' -e "s/<D0 의 기준선 커밋>/$S/")"
  run_fence "$body"
  assert_grep "$out" '^axis=ok$' "D1 펜스: axis=ok"
  assert_grep "$out" '^scope=range$' "D1 펜스: scope=range"
  assert_grep "$out" "^head_commit=$E\$" "D1 펜스: head_commit = E"
  local ht; ht="$(printf '%s\n' "$out" | sed -n 's/^head_tree=//p')"
  if [ -n "$ht" ] && [ -d "$ht" ]; then
    assert_eq "$(git -C "$ht" rev-parse HEAD)" "$E" "D1 펜스: HEAD 축 트리의 HEAD = E"
    (cd "$R" && bash "$PLUGIN_ROOT/scripts/qg-worktree.sh" remove "$ht" >/dev/null 2>&1)
  else
    no "D1 펜스가 HEAD 축 트리를 만들지 못했다: $(cat "$ROOT/err")"
  fi

  body="$(fence_with 'compute-test-scope-candidates.sh" --topic' < "$DT" | LC_ALL=C sed "s/<session-id>/$sid/g")"
  run_fence "$body"
  assert_grep "$out" '^tests/test_x\.sh$' "D2 펜스: 후보에 범위 안 테스트(tests/test_x.sh)"
  assert_contains "$out" 'candidates rc=0' "D2 펜스: candidates rc=0"
  assert_grep "$out" '^1$' "D2 펜스: 분모는 끝 커밋 트리의 테스트 수(1)"
  assert_contains "$out" 'total rc=0' "D2 펜스: total rc=0"

  local line; line="$(awk '/^## Final verdict$/{f=1;next} f&&/^## Publish$/{exit} f' "$SK" | grep '^SHA_ARG=' | head -n 1)"
  run_fence "RD=\"$D\"; $line; printf 'sha=%s\n' \"\$SHA_ARG\""
  assert_eq "$out" "sha=$(git -C "$R" rev-parse --short "$E")" "판정 커밋: 범위 모드면 끝 커밋(체크아웃은 시작 커밋)"
  run_fence "RD=\"$ROOT/no-range\"; $line; printf 'sha=%s\n' \"\$SHA_ARG\""
  assert_eq "$out" "sha=$(git -C "$R" rev-parse --short HEAD)" "판정 커밋: 범위 파일이 없으면 HEAD(양성 짝)"

  printf -- '---\nsession_id: "%s"\n---\n\n# qg result\n' "$sid" > "$D/result.md"
  # 게시 펜스(하나뿐) — 플러그인 루트는 sink 호출을 기록하는 대역이다
  mkdir -p "$ROOT/fakeplug/scripts"
  printf '#!/bin/sh\necho called >> "%s"\necho "posted: x"\n' "$ROOT/sink.log" > "$ROOT/fakeplug/scripts/publish-comment.sh"
  chmod +x "$ROOT/fakeplug/scripts/publish-comment.sh"; : > "$ROOT/sink.log"
  body="$(awk '/^## Publish$/{f=1;next} f&&/^## kill switch$/{exit} f' "$SK" | fence_with 'scripts/publish-comment.sh' \
    | LC_ALL=C sed -e "s/<session-id>/$sid/g" -e "s|\${CLAUDE_PLUGIN_ROOT}|$ROOT/fakeplug|" -e 's/^OUTCOME=".*"$/OUTCOME="aborted iter 1"/')"
  run_fence "$body"
  assert_eq "$out" "게시 안 함 — 범위 모드라 PR 코멘트를 달지 않는다(범위에는 열린 PR 이 없다)" "게시 펜스: 범위 모드면 aborted 여도 범위 공시 줄"
  assert_eq "$(grep -cx '## 게시' "$D/result.md")" "1" "게시 펜스: ## 게시 절을 남긴다"
  assert_eq "$(cat "$ROOT/sink.log")" "" "게시 펜스: 범위 모드면 sink 를 부르지 않는다"
  run_fence "$body"
  assert_eq "$out" "게시 안 함 — 이 실행은 이미 게시 단계를 돌았다" "게시 펜스: 두 번째는 거절한다"
  assert_eq "$(grep -cx '## 게시' "$D/result.md")" "1" "게시 펜스: ## 게시 는 하나뿐이다"
}

case_text_locks
case_chain_agrees
case_fences_agree
case_review_tree
finish
