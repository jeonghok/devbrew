#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/quality-pipeline/references/differential-test.md plugins/quality-gates/scripts/scope_tuple.py
# test_topic_scope_wiring.sh — 토픽 스코프 배선 (설계 §6.2 · §6.4.1, AC3–AC7 · AC15 · AC16).
#
# 오케스트레이터 산문이 스크립트 산출물을 «실제로» 흘리는가를 잰다. 각 사실은 그것이 적힌
# 한 줄(또는 한 펜스)에서 잰다 — 다른 행이 대신 만족시키면 뒤집기를 못 잡는다. 열거가
# 필요한 단언은 코드의 열거(scope_tuple.STATUSES)에서 도출한다.
set -u
[ "${1:-}" = "--emit-scanned" ] && { printf '%s\n' \
  plugins/quality-gates/skills/quality-pipeline/SKILL.md \
  plugins/quality-gates/skills/quality-pipeline/references/differential-test.md \
  plugins/quality-gates/scripts/scope_tuple.py; exit 0; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
REF="$PLUGIN_ROOT/skills/quality-pipeline/references/differential-test.md"
export PYTHONDONTWRITEBYTECODE=1

# 파이썬 본문은 `$( )` 안 heredoc 으로 두지 않는다 — bash 3.2 는 그 본문의 짝 없는 괄호 ·
# 따옴표로 치환 경계를 잘못 잡는다. 최상위 heredoc 으로 변수에 담고 `python3 -c` 로 넘긴다.
IFS= read -r -d '' PY_TRIVIA <<'PY' || true
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'^## Trivia escape\n(.*?)(?=^## )', text, re.S | re.M)
lines = (m.group(1) if m else "").splitlines()
det = [i for i, l in enumerate(lines) if 'resolve-topic.sh" detect' in l]
trv = [i for i, l in enumerate(lines) if 'check-trivia.sh' in l]
print("DETECT:%d" % len(det))
print("DETECT_FIRST:%d" % (1 if det and trv and det[0] < trv[0] else 0))
skip_needle = 'trivia escape 를 **쓰지 않고** 곧장 iteration 1 로 간다'
skip = [l for l in lines if 'status: ok' in l and 'status: declaration-invalid' in l and skip_needle in l]
print("SKIP_LINE:%d" % len(skip))
nodecl_violation = [l for l in lines if 'no-declaration' in l and ('iteration 1' in l or ('trivia escape' in l and '쓰지 않' in l))]
print("NODECL_VIOLATION:%d" % len(nodecl_violation))
PY

IFS= read -r -d '' PY_1A <<'PY' || true
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
lines = text.splitlines()
open_re = re.compile(r'^[ \t]*```bash\s*$')
close_re = re.compile(r'^[ \t]*```\s*$')
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
needle = '"$QG/scripts/topic-head.sh" "<session-id>"'
hits = [b for b in fences if any(needle in l for l in b)]
print("FENCES:%d" % len(hits))
body = hits[0] if hits else []
th = [k for k, l in enumerate(body) if needle in l]
print("TH_LINES:%d" % len(th))
th_exact = '"$QG/scripts/topic-head.sh" "<session-id>" > "$S" && cat "$S"'
print("TH_EXACT:%d" % (1 if len(th) == 1 and body[th[0]] == th_exact else 0))
s_last = None
for l in (body[:th[0]] if th else []):
    for part in l.split(";"):
        p = part.strip()
        if p.startswith("export "):
            p = p[len("export "):].strip()
        if p.startswith("S="):
            s_last = l
s_exact = 'S="$(git rev-parse --show-toplevel)/.claude/quality-gates/<session-id>/topic-scope.txt"; mkdir -p "${S%/*}"'
print("S_EXACT:%d" % (1 if s_last == s_exact else 0))
PY

IFS= read -r -d '' PY_STATUS <<'PY' || true
import re, sys
sys.path.insert(0, sys.argv[2])
import scope_tuple
text = open(sys.argv[1], encoding="utf-8").read()
missing, wrong = [], []
for st in scope_tuple.STATUSES:
    pat = re.compile(r'^\s*\| `' + re.escape(st) + r'` \|')
    rows = [l for l in text.splitlines() if pat.match(l)]
    if len(rows) != 1:
        missing.append(st)
        continue
    r = rows[0]
    if st == "ok":
        if "**topic**" not in r or "| session |" in r:
            wrong.append(st)
    elif "| session |" not in r or "**topic**" in r:
        wrong.append(st)
print("MISSING:" + ",".join(missing))
print("WRONG:" + ",".join(wrong))
PY

IFS= read -r -d '' PY_RINIT <<'PY' || true
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
fences = [b for b in re.findall(r'```bash\n(.*?)```', text, re.S) if 'topic-scope.txt' in b]
print("FENCES:%d" % len(fences))
lines = fences[0].splitlines() if fences else []
def idx(pred, start):
    for i in range(start, len(lines)):
        if pred(lines[i]):
            return i
    return -1
i_if = idx(lambda l: l.startswith('if [ "') and "s/^status: //p" in l and l.endswith('= ok ]; then'), 0)
i_else = idx(lambda l: l == 'else', i_if + 1) if i_if >= 0 else -1
i_fi = idx(lambda l: l == 'fi', i_else + 1) if i_else >= 0 else -1
shaped = i_fi > i_else > i_if >= 0
print("IF:%d" % (1 if shaped else 0))
ok_lines = lines[i_if + 1:i_else] if shaped else []
el_lines = lines[i_else + 1:i_fi] if shaped else []
ok_b = "\n".join(ok_lines)
el_b = "\n".join(el_lines)


def last_assign(prefix, block_lines):
    # 갈래 «안»의 마지막 대입 — 뒤에 같은 변수를 한 번 더 대입해 앞 값을 덮는
    # 변이(부분 문자열 락은 「그 값이 어딘가에 있다」만 보고 못 잡는다)를 구조로 잡는다.
    # 한 줄에 `;` 로 붙은 대입 · `export ` 접두 대입도 대입이다 — 줄 머리만 보면
    # `x=1; scan_dir=…` · `export scan_dir=…` 로 덮는 변이가 산다.
    val = None
    for l in block_lines:
        for part in l.split(";"):
            p = part.strip()
            if p.startswith("export "):
                p = p[len("export "):].strip()
            if p.startswith(prefix):
                val = p
    return val


ok_last_baseline = last_assign('baseline_commit=', ok_lines)
ok_last_scan = last_assign('scan_dir=', ok_lines)
ok_last_sealed = last_assign('sealed=', ok_lines)
printf_idx = idx(lambda l: l.startswith('printf '), i_fi + 1) if shaped else -1
between_fi_and_printf = lines[i_fi + 1:printf_idx] if (shaped and printf_idx >= 0) else None
checks = [
    ("OK_BASE", "baseline_commit=$(sed -n 's/^boundary: //p' \"$S\")" in ok_b),
    ("OK_SEALED", "sealed=$(sed -n 's/^head_commit: //p' \"$S\")" in ok_b),
    ("OK_TOPIC", 'create-head "$sealed" "<session-id>" --topic "$topic_key"' in ok_b),
    ("OK_SCAN", 'scan_dir="${head_tree_dir:-$project_dir}"' in ok_b),
    ("OK_BASE_LAST", ok_last_baseline == "baseline_commit=$(sed -n 's/^boundary: //p' \"$S\")"),
    ("OK_SCAN_LAST", ok_last_scan == 'scan_dir="${head_tree_dir:-$project_dir}"'),
    ("OK_SEALED_LAST", ok_last_sealed == "sealed=$(sed -n 's/^head_commit: //p' \"$S\")"),
    ("S_ROOT", shaped and last_assign('S=', lines[:i_if]) == 'S="$(git rev-parse --show-toplevel)/.claude/quality-gates/<session-id>/topic-scope.txt"'),
    ("ELSE_BASE", 'baseline_commit="<위 6키의 merge_base>"' in el_b),
    ("ELSE_SCAN", 'scan_dir="$project_dir"' in el_b),
    ("ELSE_NO_TOPIC", "--topic" not in el_b),
    ("NO_REASSIGN_AFTER_FI", between_fi_and_printf == []),
]
for k, v in checks:
    print("%s:%d" % (k, 1 if v else 0))
PY

IFS= read -r -d '' PY_R4 <<'PY' || true
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'^\*\*Step R4 — .*?(?=^\*\*Step R5b)', text, re.S | re.M)
win = m.group(0) if m else ""
fences = "\n".join(re.findall(r'```bash\n(.*?)```', win, re.S))
calls = re.findall(r'(?:baseline-cache\.sh" (?:get|put)|qg-worktree\.sh" create-baseline)[^\n\\]*(?:\\\n[^\n\\]*)*', fences)
good = [c for c in calls if '"$baseline_commit"' in c]
print("CALLS:%d" % len(calls))
print("GOOD:%d" % len(good))
print("MERGE_BASE_IN_FENCES:%d" % fences.count('$merge_base'))
PY

IFS= read -r -d '' PY_RM <<'PY' || true
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
lines = text.splitlines()
open_re = re.compile(r'^[ \t]*```bash\s*$')
close_re = re.compile(r'^[ \t]*```\s*$')
fences = []
i = 0
while i < len(lines):
    if open_re.match(lines[i]):
        start = i
        j = i + 1
        body = []
        while j < len(lines) and not close_re.match(lines[j]):
            body.append(lines[j])
            j += 1
        fences.append((start, body))
        i = j + 1
    else:
        i += 1
rm_needle = 'rm -f "$(git rev-parse --show-toplevel)/.claude/quality-gates/<session-id>/topic-scope.txt"'
hits = [f for f in fences if any(rm_needle in l for l in f[1])]
print("RM_FENCES:%d" % len(hits))
if hits:
    start = hits[0][0]
    k = start - 1
    while k >= 0 and lines[k].strip() == "":
        k -= 1
    para = []
    while k >= 0 and lines[k].strip() != "":
        para.append(lines[k])
        k -= 1
    para_text = "\n".join(reversed(para))
else:
    para_text = ""
print("PARA_OVERRIDE:%d" % (1 if "override" in para_text else 0))
print("PARA_BRANCH:%d" % (1 if "branch" in para_text else 0))
print("PARA_PATHS:%d" % (1 if "--paths" in para_text else 0))
print("PARA_DELETE_POS:%d" % (1 if "지운다" in para_text else 0))
print("PARA_DELETE_NEG:%d" % (1 if "지우지 않" in para_text else 0))
# override 조건 자체의 극성 — 문단 전체가 「override 다」쪽으로 조건을 뒤집어도
# 위 네 토큰 존재 검사는 전부 그대로 만족된다(토큰은 안 지웠다). 조건절의 긍정형을
# 리터럴로 고정하고, 그 부정형 표지가 섞여 있지 않은지 별도로 잰다.
print("PARA_OVERRIDE_POSITIVE:%d" % (1 if "override(`branch` · `--paths`)면" in para_text else 0))
print("PARA_OVERRIDE_NEGATED:%d" % (1 if ("가 없으면" in para_text or "가 없을 때" in para_text) else 0))
PY

case_trivia_escape_is_gated_by_declaration() {
  # Review Focus 2 · R-AO — 선언이 있으면 trivia escape 를 쓰지 않는다.
  local got; got=$(python3 -c "$PY_TRIVIA" "$SKILL")
  assert_grep "$got" '^DETECT:1$'         "Trivia escape 절에 detect 호출 펜스가 하나"
  assert_grep "$got" '^DETECT_FIRST:1$'   "detect 가 check-trivia 보다 먼저 나온다"
  assert_grep "$got" '^SKIP_LINE:1$'      "ok · declaration-invalid 면 trivia escape 를 쓰지 않고 곧장 iteration 1 로 간다(같은 줄, 긍정 목적지 단언)"
  assert_grep "$got" '^NODECL_VIOLATION:0$' "Trivia 절 전체에서 no-declaration 과 trivia escape 를 쓰지 않음이 한 줄에 함께 나오지 않는다"
}

case_step1_writes_scope_file() {
  # R-AJ — ① 1a 가 매 iteration topic-head.sh 출력을 고정 경로에 쓴다. 산문으로 옮기면
  # 실행되지 않으므로 bash 펜스 «안»의 줄만 센다. 줄 전체를 fullmatch 로 잰다 — 부분
  # 문자열 락은 꼬리에 `|| true` 를 붙여 실패를 삼키는 변이를 못 잡는다.
  # 경로는 리포 루트 기준이다 — cwd 상대면 하위 디렉토리 cwd 에서 리다이렉트가 먼저 만든
  # 빈 파일이 봉인에 섞여 R-init 재도출 대조가 매번 어긋난다(test_topic_head.sh
  # case_scope_file_under_subdir_cwd 가 그 동작을 잰다).
  local got; got=$(python3 -c "$PY_1A" "$SKILL")
  assert_grep "$got" '^FENCES:1$'   "① 1a: topic-head.sh 를 부르는 bash 펜스가 정확히 하나"
  assert_grep "$got" '^TH_LINES:1$' "① 1a 펜스에 topic-head.sh 출력을 쓰는 줄이 정확히 하나"
  assert_grep "$got" '^TH_EXACT:1$' "① 1a: topic-head.sh 출력을 \"\$S\" 에 쓰고 && 로 그대로 cat 한다(줄 전체 fullmatch, || true 로 삼키지 않는다)"
  assert_grep "$got" '^S_EXACT:1$'  "① 1a: 그 줄 앞의 «마지막» S 대입이 리포 루트 경로 + mkdir -p 한 줄이다(줄 전체 fullmatch)"
  local stale
  stale=$(grep -hF '".claude/quality-gates/<session-id>/topic-scope.txt"' "$SKILL" "$REF")
  assert_eq "$(printf '%s' "$stale" | grep -c .)" "0" "SKILL · 레퍼런스에 cwd 상대 스코프 파일 경로(\".claude/…/topic-scope.txt\")가 남지 않는다"
  assert_eq "$(grep -cF '"$(git rev-parse --show-toplevel)/.claude/quality-gates/<session-id>/topic-scope.txt"' "$SKILL")" "4" \
    "SKILL 의 네 자리(1a · 파일 집합 · override 정리 · Step 4 --scope)가 리포 루트 경로를 쓴다(부재 락의 양의 짝)"
}

case_status_table_is_total_over_statuses() {
  # R-AK — 상태 표가 scope_tuple.STATUSES 전부를 받고, ok 만 topic 이다.
  local got; got=$(python3 -c "$PY_STATUS" "$SKILL" "$PLUGIN_ROOT/scripts")
  assert_grep "$got" '^MISSING:$' "상태 표가 STATUSES 여덟 전부를 정확히 한 행씩 받는다"
  assert_grep "$got" '^WRONG:$'   "ok 행만 **topic**, 나머지는 session"
}

case_topic_diff_uses_boundary_and_tree() {
  # ② · ③ 이 같은 트리를 본다 — 파일 집합 · diff 는 스코프 파일의 boundary · tree 에서.
  # `git ` 으로 시작하는 줄이면 A20 락이 session 합집합으로 끌어가 실행한다.
  local got
  got=$(grep -F "sed -n 's/^boundary: //p'" "$SKILL" | grep -F "sed -n 's/^tree: //p'" | grep -F 'git diff --name-only "$b" "$t"')
  assert_eq "$(printf '%s\n' "$got" | grep -c .)" "1" "파일 집합 질의가 boundary · tree 를 한 줄에서 읽는다"
  assert_not_grep "$got" '^[[:space:]]*git ' "그 줄은 git 으로 시작하지 않는다(A20 session 오라클 밖)"
  # 부분 문자열 계수(`git diff` 하나)는 `git diff` 가 아닌 git 호출(예: `git log`)을 중간에
  # 끼워 넣는 변이를 못 잡는다 — 줄 전체를 fullmatch 로 잰다.
  assert_eq "$(printf '%s' "$got" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')" \
    'S="$(git rev-parse --show-toplevel)/.claude/quality-gates/<session-id>/topic-scope.txt"; b=$(sed -n '\''s/^boundary: //p'\'' "$S"); t=$(sed -n '\''s/^tree: //p'\'' "$S"); git diff --name-only "$b" "$t"' \
    "그 줄 전체가 리포 루트 스코프 파일 · boundary · tree · git diff --name-only 하나다(줄 전체 fullmatch — 다른 git 호출을 끼워 넣지 않는다)"
  case "$got" in
    *'git diff --name-only "$b" "$t"') ok "그 줄이 git diff --name-only \"\$b\" \"\$t\" 로 끝난다(뒤에 다른 git 호출을 덧붙이지 않는다)" ;;
    *) no "그 줄이 git diff --name-only \"\$b\" \"\$t\" 로 끝난다(뒤에 다른 git 호출을 덧붙이지 않는다)"
       printf '      actual tail: %s\n' "$got" ;;
  esac
}

case_step4_row_carries_scope() {
  # R-AL — 두 사유와 scope: 블록은 합성기가 이 파일에서 낸다. SKILL 의 의무는 싣는 것 하나.
  local rows
  rows=$(grep -F -- '--scope "$(git rev-parse --show-toplevel)/.claude/quality-gates/<session-id>/topic-scope.txt"' "$SKILL")
  assert_eq "$(printf '%s\n' "$rows" | grep -c '^[[:space:]]*|')" "1" "Step 4 판정 입력 표에 --scope 행이 하나"
  assert_grep "$rows" 'topic-head\.sh' "그 행이 조건(① 이 topic-head.sh 를 불렀다)을 같은 줄에 적는다"
  assert_grep "$rows" '불렀다' "그 행의 조건이 1a 호출을 긍정형(불렀다)으로 적는다"
  assert_not_grep "$rows" '부르지|않았' "그 행의 조건이 호출-부정형(부르지 · 않았)이 아니다"
  assert_not_grep "$rows" '싣지 (않|말)|없음|생략' "그 행이 부정형(싣지 않는다 · 싣지 말 것 · 없음 · 생략)이 아니다"
}

case_scope_block_surfaces() {
  # AC15 — scope: 블록이 판정 옆(Step 4.5)과 Final Summary 에 그대로 나간다.
  local s45 fs fs_needle
  s45=$(grep -F '`scope:` 블록' "$SKILL" | grep -F '**그대로** 보인다')
  assert_eq "$(printf '%s\n' "$s45" | grep -c .)" "1" "Step 4.5 가 scope: 블록을 그대로 보인다(한 줄, 긍정형 — '보이지 말고' 는 이 needle 을 못 만족한다)"
  fs_needle='the last synthesizer output'\''s `scope:` block and `angles:` block verbatim'
  fs=$(awk '/^## Final Summary$/{f=1;next} f&&/^## /{exit} f' "$SKILL" | grep -F -- "$fs_needle")
  assert_eq "$(printf '%s\n' "$fs" | grep -c .)" "1" "Final Summary 가 scope: · angles: 블록을 이 순서로 verbatim 싣는다(한 줄, 리터럴)"
}

case_filtered_diff_uses_boundary_and_tree() {
  # 리뷰 라운드 1 신규 — FILTERED_DIFF 도 topic 스코프에서는 경계 · 합친 트리에서 뽑는다.
  # session 베이스라인(MERGE_BASE·HEAD)으로 새면 리뷰어 diff 가 스코프 파일과 어긋난다.
  local got
  got=$(grep -F 'FILTERED_DIFF' "$SKILL" | grep -F 'git diff "$b" "$t"')
  assert_eq "$(printf '%s\n' "$got" | grep -c .)" "1" "FILTERED_DIFF 문장이 같은 줄에서 git diff \"\$b\" \"\$t\" 를 쓴다"
  assert_not_grep "$got" 'MERGE_BASE|HEAD' "그 줄에 MERGE_BASE · HEAD 가 없다(session 베이스라인으로 새지 않는다)"
}

case_rinit_topic_branch_sets_axes() {
  # AC5 · AC6 · R-AP — 선언 경로의 기준선은 경계, HEAD 축은 create-head --topic 이 재도출 대조한
  # 합친 커밋. 각 값은 «그 갈래 안»에서 잰다 — 반대 갈래에 옮겨 적으면 RED.
  local got; got=$(python3 -c "$PY_RINIT" "$REF")
  assert_grep "$got" '^FENCES:1$'        "스코프 파일을 읽는 레퍼런스 펜스가 하나(R-init)"
  assert_grep "$got" '^IF:1$'            "그 펜스가 status == ok 로 if/else/fi 를 가른다"
  assert_grep "$got" '^OK_BASE:1$'       "ok 갈래: baseline_commit = boundary"
  assert_grep "$got" '^OK_SEALED:1$'     "ok 갈래: sealed = head_commit(전사 없이 파일에서)"
  assert_grep "$got" '^OK_TOPIC:1$'      "ok 갈래: create-head 가 --topic 으로 재도출 대조한다"
  assert_grep "$got" '^OK_SCAN:1$'       "ok 갈래: scan_dir = HEAD 축 트리"
  assert_grep "$got" '^OK_BASE_LAST:1$'  "ok 갈래: baseline_commit 의 «마지막» 대입도 boundary 다(뒤에 덮어쓰기 없음)"
  assert_grep "$got" '^OK_SCAN_LAST:1$'  "ok 갈래: scan_dir 의 «마지막» 대입도 HEAD 축 트리다(; · export 대입 포함)"
  assert_grep "$got" '^OK_SEALED_LAST:1$' "ok 갈래: sealed 의 «마지막» 대입도 head_commit 이다(; · export 대입 포함)"
  assert_grep "$got" '^S_ROOT:1$'        "R-init 이 스코프 파일을 리포 루트 경로로 읽는다(if 앞, 줄 전체)"
  assert_grep "$got" '^ELSE_BASE:1$'     "else 갈래: baseline_commit = merge_base"
  assert_grep "$got" '^ELSE_SCAN:1$'     "else 갈래: scan_dir = project_dir"
  assert_grep "$got" '^ELSE_NO_TOPIC:1$' "else 갈래에 --topic 이 없다"
  assert_grep "$got" '^NO_REASSIGN_AFTER_FI:1$' "fi 뒤 printf 앞에 축 재대입이 없다(양 갈래 값을 무조건 덮지 않는다)"
}

case_scan_dir_feeds_detect_and_assign() {
  # R-AP — 형제에만 있는 테스트 파일은 합친 트리에만 있다.
  assert_eq "$(grep -cF 'run-test-selection.sh" detect "$scan_dir"' "$REF")" "1" "R1a detect 가 \$scan_dir 를 본다"
  assert_eq "$(grep -cF 'run-test-selection.sh" assign "$scan_dir"' "$REF")" "1" "R1b assign 이 \$scan_dir 를 본다"
  assert_eq "$(grep -cE 'run-test-selection\.sh" (detect|assign) "\$project_dir"' "$REF")" "0" "R1a · R1b 에 \$project_dir 호출이 남지 않았다"
}

case_r4_calls_use_baseline_commit() {
  # AC5 — R4 의 세 호출(cache get · create-baseline · cache put)은 전부 $baseline_commit.
  local got; got=$(python3 -c "$PY_R4" "$REF")
  assert_grep "$got" '^CALLS:3$'               "R4 펜스에 호출 셋(get · create-baseline · put)"
  assert_grep "$got" '^GOOD:3$'                "셋 전부 \"\$baseline_commit\" 을 싣는다"
  assert_grep "$got" '^MERGE_BASE_IN_FENCES:0$' "R4 펜스에 \$merge_base 가 남지 않았다"
}

case_r5b_skips_on_topic() {
  # R-AP — 선언 경로의 R5b 는 봉인 · 트리 생성을 건너뛰고 R-init 의 값을 쓴다. 한 줄로 잰다.
  local got
  got=$(grep -F '**선언 경로면 이 스텝에서 봉인하지 않는다.**' "$REF")
  assert_eq "$(printf '%s\n' "$got" | grep -c .)" "1" "R5b 에 선언 경로 규칙 문장이 하나"
  assert_grep "$got" 'R-init' "그 문장이 R-init 의 값을 쓴다고 적는다"
  assert_grep "$got" '\$head_tree_dir' "그 문장이 \$head_tree_dir 를 이름 붙인다"
}

case_r1b_topic_candidates_supplemented() {
  # 최종 리뷰 I3 — 후보 스크립트는 session 범위를 본다. 선언 경로면 경계..합친 트리의
  # 테스트 파일 · 이름-매칭 테스트를 후보에 더한다. 한 줄 · R1b 창 안 · 긍정 목적지.
  local win got
  win=$(awk '/^\*\*Step R1b /{f=1} /^\*\*Step R2 /{f=0} f' "$REF")
  got=$(printf '%s\n' "$win" | grep -F 'git diff --name-only <boundary> <tree>')
  assert_eq "$(printf '%s\n' "$got" | grep -c .)" "1" "R1b 에 선언 경로 후보 보충 문장이 한 줄"
  assert_grep "$got" '^선언 경로면' "그 줄이 선언 경로 조건으로 시작한다"
  assert_grep "$got" '테스트 파일을 후보에 더한다\.$' "그 줄이 후보에 더한다(긍정 목적지)로 끝난다"
  assert_grep "$got" '\$scan_dir' "그 줄이 이름-매칭을 \$scan_dir(합친 트리) 안에서 찾는다"
  assert_not_grep "$got" '더하지 않|빼' "그 줄에 부정형(더하지 않 · 뺀다)이 없다"
}

case_early_exit_discards_head_tree() {
  # 최종 리뷰 M3 — R6 전에 끝나는 경로에서도 R-init 의 HEAD 축 트리를 폐기한다. 한 줄.
  local got; got=$(grep -F 'R6 전에 끝내는 모든 경로' "$REF")
  assert_eq "$(printf '%s\n' "$got" | grep -c .)" "1" "R6 전 종료 경로의 폐기 문장이 한 줄"
  assert_grep "$got" 'R3 `중단`' "그 줄이 R3 중단을 이름 붙인다"
  assert_grep "$got" '\$head_tree_dir` 가 있으면 R6 의 폐기 펜스를 먼저 돈다\.$' "그 줄이 폐기 펜스를 먼저 돈다(긍정 목적지)로 끝난다"
}

case_override_clears_stale_scope_file() {
  # I1 수정 — override 는 이번 iteration 에 1a 를 돌리지 않으므로, 남아 있을 수 있는 이전
  # 스코프 파일을 지운다. 파일 부재는 차등 테스트 R-init 의 else 갈래로 간다(sed …
  # "$S" 2>/dev/null 이 빈 값을 내 status==ok 를 만족 못한다). rm 줄이 1a(기본 모드) 쪽에
  # 있으면(mutation) 그 펜스 바로 위 문단에 override · branch · --paths 가 함께 없다.
  local got; got=$(python3 -c "$PY_RM" "$SKILL")
  assert_grep "$got" '^RM_FENCES:1$'       "스코프 파일을 지우는 rm -f 줄을 담은 펜스가 정확히 하나"
  assert_grep "$got" '^PARA_OVERRIDE:1$'   "그 펜스 바로 위 문단이 override 를 언급한다"
  assert_grep "$got" '^PARA_BRANCH:1$'     "그 문단이 branch 를 언급한다"
  assert_grep "$got" '^PARA_PATHS:1$'      "그 문단이 --paths 를 언급한다"
  assert_grep "$got" '^PARA_DELETE_POS:1$' "그 문단이 삭제를 긍정형(지운다)으로 적는다"
  assert_grep "$got" '^PARA_DELETE_NEG:0$' "그 문단에 삭제 부정형(지우지 않)이 섞여 있지 않다"
  assert_grep "$got" '^PARA_OVERRIDE_POSITIVE:1$' "override 조건절이 긍정형(override(...)면)이다"
  assert_grep "$got" '^PARA_OVERRIDE_NEGATED:0$'  "override 조건절에 부정형(가 없으면 · 가 없을 때)이 섞여 있지 않다"
}

case_in_base_notice() {
  # AC4 재정의 — 머지된 앞 조각이 토픽 구성원에서 빠졌고 형제와 그 조각을 품은 구성원이 함께 있으면 그 변경이 diff 에 다시 보인다는 사실을 ① 1a 가 공지한다(같은 줄).
  # 1a 창(「**1a — 토픽 선언」 ~ 「**session 스코프**」) 안에서만 찾는다 — 다른 절로 옮기면 RED.
  # 끝 마커 자체의 실재를 별도로 잰다(PR4d 닫기 #19) — 마커를 개명(예: "**session scope**")하면
  # awk 의 종료 조건이 다시는 안 걸려 창이 파일 끝까지 넓어지고, 옮겨진 공지 줄이 그 넓은
  # 창 안에서 «다시» 걸려 뒤집기를 못 잡는다. 마커가 정확히 한 번 리터럴로 있어야 창이 닫힌다.
  assert_eq "$(grep -c -F '**session 스코프**' "$SKILL")" "1" "1a 창의 끝 마커가 SKILL 에 정확히 한 번 리터럴로 있다(양의 짝 — 없으면 창이 파일 끝까지 새는 것을 못 잡는다)"
  local win got
  win=$(awk '/\*\*1a — 토픽 선언/{f=1} /\*\*session 스코프\*\*/{f=0} f' "$SKILL")
  got=$(printf '%s\n' "$win" | grep -F '`in_base:`' | grep -F '토픽 구성원에서 빠졌다' | grep -F '이번 diff 에 다시 보인다')
  assert_eq "$(printf '%s\n' "$got" | grep -c .)" "1" "① 1a 창에 in_base 공지가 한 줄 있다"
  assert_grep "$got" '^[[:space:]]*`status: ok` 이고 파일의 `in_base:` 가 0 보다 크면 공지 한 줄: `> \[quality-gates\] 토픽 ' \
    "조건(status ok · in_base > 0)과 목적지(공지 한 줄: …)가 같은 줄의 긍정형이다"
  assert_not_grep "$got" '않|말 것|생략|아니고' "그 줄에 부정 · 반전 토큰이 없다(「토픽 구성원에서 빠졌다」는 위에서 따로 잰다)"
  # 줄 전체 끝 앵커(PR4d 닫기 #20) — 위 긍정형 단언은 접두만 고정해, 닫는 백틱 뒤에 꼬리를
  # 덧붙이는 변이(부정 토큰 없이)를 못 잡는다. 문장이 그 백틱에서 «끝난다»를 별도로 잰다.
  assert_grep "$got" '이번 diff 에 다시 보인다\.`$' "그 문장이 닫는 백틱 직후에 끝난다(줄 끝 앵커 — 백틱 뒤 덧붙임을 잡는다)"
  assert_eq "$(printf '%s\n' "$got" | grep -c -F '이미 base 에 있어 토픽 구성원에서 빠졌다 — 그 머지 전에 갈라져 base 를 아직 안 들인 형제 구성원이 그 조각을 품은 구성원과 함께 있으면 그 변경이 이번 diff 에 다시 보인다.`')" "1" "공지 문장 전체가 글자 그대로다(조건절의 양보 · 한정 삭제 · 「형제」 치환을 잡는다)"
  assert_not_grep "$win" '기준선에 포함' "① 1a 창에 「기준선에 포함」이 없다 — 형제 토폴로지에서는 그 조각이 경계 트리에 없다(설계 §6.2.2 2)"
  assert_not_grep "$win" '자기 PR 에서 판정' "① 1a 창에 「자기 PR 에서 판정」이 없다 — qg 는 앞 조각이 /qg 로 판정됐는지 확인하지 못한다"
  assert_not_grep "$win" '판정 대상에서 빠졌다' "① 1a 창에 「판정 대상에서 빠졌다」가 없다 — 형제 토폴로지에서는 그 변경이 리뷰 diff 와 차등 테스트에 다시 든다(설계 §6.2.2 2)"
}

case_topic_denominator_uses_tree() {
  # Task 2 — R1b 가 분자를 경계..합친 트리로 보충하는데 R2 산문의 분모(--total)는
  # 현재 체크아웃만 세면 N > M 이 난다. `--total --tree <tree>` 로 분모도 합친
  # 트리에서 세는 규칙이 R2 산문 3번 분모 규칙 줄 바로 다음 두 줄 안에, 같은
  # 들여쓰기의 한 줄로 있어야 한다.
  local needle='--total --tree <tree>'
  local hits; hits=$(grep -F -- "$needle" "$REF")
  assert_eq "$(printf '%s\n' "$hits" | grep -c .)" "1" "REF 에 --total --tree <tree> 를 담은 줄이 정확히 1줄"
  assert_grep "$hits" '^[[:space:]]*선언 경로면' "그 줄이 선언 경로면 으로 시작한다"
  assert_contains "$hits" '`tree:`' "같은 줄에 tree: 가 있다(스코프 파일 필드를 이름 붙인다)"
  assert_not_grep "$hits" '않|말 것|생략|아니고' "그 줄에 부정 토큰이 없다"

  local new_line_no denom_line_no
  denom_line_no=$(grep -nF -- '부풀려 비율이 정상으로 보인다.' "$REF" | head -1 | cut -d: -f1)
  new_line_no=$(grep -nF -- "$needle" "$REF" | head -1 | cut -d: -f1)
  assert_grep "$denom_line_no" '^[0-9]+$' "분모 규칙 줄을 찾았다"
  assert_grep "$new_line_no" '^[0-9]+$' "--total --tree <tree> 줄을 찾았다"
  local delta; delta=$((new_line_no - denom_line_no))
  if [ "$delta" -ge 1 ] && [ "$delta" -le 2 ]; then
    ok "새 줄이 분모 규칙 줄 바로 다음 두 줄 안에 있다(delta=$delta)"
  else
    no "새 줄이 분모 규칙 줄 바로 다음 두 줄 안에 있다(delta=$delta)"
  fi
}

for c in case_trivia_escape_is_gated_by_declaration case_step1_writes_scope_file \
         case_status_table_is_total_over_statuses case_topic_diff_uses_boundary_and_tree \
         case_step4_row_carries_scope case_scope_block_surfaces \
         case_filtered_diff_uses_boundary_and_tree \
         case_rinit_topic_branch_sets_axes case_scan_dir_feeds_detect_and_assign \
         case_r4_calls_use_baseline_commit case_r5b_skips_on_topic \
         case_r1b_topic_candidates_supplemented case_early_exit_discards_head_tree \
         case_override_clears_stale_scope_file case_in_base_notice \
         case_topic_denominator_uses_tree; do
  echo "== $c"; $c
done
finish
