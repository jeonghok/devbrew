#!/usr/bin/env bash
# Final verdict 의 세 판정 펜스(일반 · trivia · 걸러진 diff 가 빈 실행)를 SKILL.md 에서 그대로 꺼내 돌린다.
# 세션 폴더의 review-i<N>.unreviewed(review-diff.sh 가 쓰는 「리뷰하지 않은 중첩 리포 폴더」 표시) 중 하나라도
# 비어 있지 않으면 판정은 clean 일 수 없고 findings-lost 를 싣는다. 비어 있거나 없으면 판정은 그대로다.
set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$PLUGIN_DIR/skills/quality-pipeline/SKILL.md"
V="$PLUGIN_DIR/scripts/verdict.py"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
SID=sessunrev01
LINE_TXT='안에 든 레포는 리뷰하지 않았다 — 커밋하거나 .gitignore 에 넣고 다시 돌려라'

# fence <k> <out> — `## Final verdict` 절의 k 번째 bash 펜스를 자리표시를 채워 out 에 쓴다.
fence() {
  python3 -I -X utf8 - "$SKILL" "$1" "$2" "$SID" <<'PY'
import re
import sys

skill, k, out, sid = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
text = open(skill, encoding="utf-8").read()
sec = text.split("\n## Final verdict\n", 1)[1].split("\n## ", 1)[0]
blocks = re.findall(r"^```bash\n(.*?)^```", sec, re.S | re.M)
body = blocks[k - 1]
body = body.replace("<session-id>", sid).replace("<N>", "2")
body = body.replace("<마지막 iteration 의 RV>", "__RV__").replace("'<e2e 칸>'", "'안 함'")
open(out, "w", encoding="utf-8").write(body)
PY
}

# 픽스처: 커밋 하나인 리포와 그 세션 폴더 · 깨끗한 합성 출력.
mkfix() {
  F=$(mktemp -d "$ROOT/fix.XXXXXX")
  git init -q -b trunk "$F/r"
  git -C "$F/r" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m c0
  RD="$F/r/.claude/quality-gates/$SID"; mkdir -p "$RD" "$F/r/__RV__"
  printf 'verdict: clean\nblocking: 0\noptional: 0\n' > "$F/r/__RV__/synth.out"
}

runfence() {   # runfence <k> — OUT · ERR · RC
  fence "$1" "$F/fence.sh"
  OUT=$(cd "$F/r" && CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" bash "$F/fence.sh" 2>"$F/err"); RC=$?
  ERR=$(cat "$F/err")
}

for k in 1 2 3; do
  fence "$k" "$ROOT/probe.sh"
  assert_file_grep "$ROOT/probe.sh" 'verdict\.py.*--unreviewed-dir "\$RD"' "펜스 $k 의 verdict.py 호출이 세션 폴더의 표시를 읽는다"
done

echo "[일반 펜스 — 표시가 비었으면 clean 그대로]"
mkfix
: > "$RD/review-i1.unreviewed"; : > "$RD/review-i2.unreviewed"
runfence 1
assert_contains "$OUT" "verdict rc=0" "rc 0"
assert_grep "$(cat "$RD/verdict.out")" '^verdict: clean$' "verdict: clean"
assert_not_contains "$ERR" "$LINE_TXT" "막는 줄 없음"

echo "[일반 펜스 — 한 iteration 이라도 표시가 있으면 clean 이 아니다]"
mkfix
printf 'vendor/lib/\n' > "$RD/review-i1.unreviewed"; : > "$RD/review-i2.unreviewed"
runfence 1
assert_contains "$OUT" "verdict rc=0" "rc 0"
assert_not_grep "$(cat "$RD/verdict.out")" '^verdict: clean$' "clean 이 아니다"
assert_grep "$(cat "$RD/verdict.out")" '^verdict: not-certified$' "verdict: not-certified"
assert_grep "$(cat "$RD/verdict.out")" '^reason: findings-lost$' "reason: findings-lost"
assert_contains "$ERR" "${LINE_TXT}: vendor/lib/" "쉬운 말 한 줄이 폴더를 밝힌다"

echo "[trivia 펜스 — 표시가 있으면 findings-lost 를 더 싣는다 · 없으면 그대로]"
mkfix
runfence 2
assert_grep "$(cat "$RD/verdict.out")" '^reasons: \[trivia\]$' "표시 파일이 없으면 reasons 는 trivia 하나"
printf 'vendor/x/\n' > "$RD/review-i1.unreviewed"
runfence 2
assert_grep "$(cat "$RD/verdict.out")" '^reasons: \[trivia, findings-lost\]$' "표시가 있으면 findings-lost 도"
assert_contains "$ERR" "${LINE_TXT}: vendor/x/" "trivia 펜스도 폴더를 밝힌다"

echo "[걸러진 diff 가 빈 실행 펜스]"
mkfix
: > "$RD/review-i2.unreviewed"
runfence 3
assert_grep "$(cat "$RD/verdict.out")" '^reasons: \[scope-empty\]$' "빈 표시면 reasons 는 scope-empty 하나"
printf 'a b/\n' > "$RD/review-i2.unreviewed"
runfence 3
assert_grep "$(cat "$RD/verdict.out")" '^reasons: \[scope-empty, findings-lost\]$' "표시가 있으면 findings-lost 도"

echo "[verdict.py --unreviewed-dir 입력 검사]"
rc=0; python3 "$V" --reason trivia --unreviewed-dir "" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" 2 "빈 문자열은 rc 2"
rc=0; python3 "$V" --reason trivia --unreviewed-dir "$ROOT/nope" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" 4 "없는 폴더는 rc 4(판정을 만들지 않는다)"
mkfix
printf 'v/\n' > "$RD/review-i3.unreviewed"
out=$(python3 "$V" --defect --unreviewed-dir "$RD" 2>/dev/null)
assert_grep "$out" '^verdict: defect$' "defect 는 defect 그대로(표시가 판정을 낮추지 않는다)"
printf 'v/\n' > "$RD/review-i3.unreviewed.bak"; : > "$RD/review-i3.unreviewed"
out=$(python3 "$V" --unreviewed-dir "$RD" 2>/dev/null)
assert_grep "$out" '^verdict: clean$' "이름 문법 밖 파일(review-i3.unreviewed.bak)은 읽지 않는다"

finish
