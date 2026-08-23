#!/usr/bin/env bash
# guards: plugins/**
#
# 모든 dispatch 자리가 자기 처분을 밝히는지 검사한다.
#
# 도출을 «표기 열거»에서 출발시키지 않는다. 열거는 fail-open 이다 — 저자가
# 두 번 물렸다(subagent_type grep 이 5표기 중 1개만 덮은 것, 프로토타입이
# 표기 ②④를 놓쳐 18 중 16 만 센 것). 에이전트 «정의 집합»(∀)에서 출발하면
# `0건` 이 답이 되어 누락이 드러난다.
#
# 축 C 는 축 B 보다 «약하다». `disclosure=` 리터럴이 파일에 있다는 것이 그
# 채널이 실제로 읽힌다는 증거는 아니다. 값이 저자 손에 있는 한 축 B 급 이빨은
# 이 축에서 나오지 않는다 — 이 락은 그것을 없앴다고 주장하지 않고 «어디로
# 옮겼는지» 밝힌다. `consumer=` 를 `.py` 대신 orchestrator/human 으로 쓰면
# 축 B 를 벗어나는데, 그 이동은 M10 이 «측정»한다(PRINT_5_axis 수치가 움직인다).
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  # 실제로 훑은 경로를 낸다. 선언에서 목록을 도출하면 자기 반복이라
  # 커버리지 증거가 되지 않는다.
  REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
  PYTHONDONTWRITEBYTECODE=1 python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path
repo = Path(sys.argv[1])
seen = set()
for pat in ("plugins/*/skills/**/*", "plugins/*/commands/**/*",
            "plugins/*/scripts/*.js", "plugins/*/hooks/**/*"):
    for f in repo.glob(pat):
        if f.is_file() and f.suffix in (".md", ".js"):
            seen.add(str(f.relative_to(repo)))
for f in repo.glob("plugins/*/agents/*.md"):
    seen.add(str(f.relative_to(repo)))
for p in sorted(seen):
    print(p)
PY
  exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

# ── 도출은 파이썬으로 한다 (경계 규칙·창 매칭·앵커 검출이 정규식 무거움).
#    **heredoc 을 `$( … )` 안에 넣지 않는다.** `OUT="$(python3 - <<'PY' … PY)"` 는
#    파이썬 본문에 `r'(?=["\'\s,)]|$)'` 같은 `\'` + `)` 조합이 들어오는 순간
#    `bash -n` 이 `syntax error near unexpected token ')'` 로 죽는다 — bash 의
#    치환 괄호 매칭 선-스캔이 single-quoted heredoc 본문을 완전히 불투명하게
#    다루지 않기 때문이다. 목 둘로 확인했다: 같은 구조 + 단순 파이썬은 통과하고,
#    같은 파이썬 줄 + heredoc 이 치환 밖이면 통과한다 — **교차항일 때만** 터진다.
#    형제 test_no_new_duplication.sh:82 가 같은 구조를 쓰는 것은 그 본문에 트리거
#    문자가 없어서이지 구조가 안전해서가 아니다. 파일로 받으면 셸이 파이썬 내용을
#    아예 안 본다.
TMPD="$(mktemp -d -t dispdisp-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT
PYTHONDONTWRITEBYTECODE=1 python3 - "$REPO_ROOT" > "$TMPD/out.txt" <<'PY'
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(sys.argv[1])
WINDOW = 40

# ── 1) 에이전트 집합 (∀) — 정의의 frontmatter `name:` 에서
agents = {}
for p in sorted(REPO.glob("plugins/*/agents/*.md")):
    m = re.search(r'^name:\s*(\S+)\s*$', p.read_text(encoding="utf-8"), re.M)
    if m:
        agents[m.group(1)] = str(p.relative_to(REPO))

# ── 2) 코퍼스는 **구조 규칙**이다. `.py` 는 Agent 도구를 호출할 수 없으므로
#       코퍼스 밖 — 이름 열거가 아니라 성질이다.
corpus = []
for pat in ("plugins/*/skills/**/*", "plugins/*/commands/**/*",
            "plugins/*/scripts/*.js", "plugins/*/hooks/**/*"):
    for f in REPO.glob(pat):
        if f.is_file() and f.suffix in (".md", ".js"):
            corpus.append(f)
corpus = sorted(set(corpus))

# ── 3) **표기 필터가 이름 매칭보다 먼저** 걸린다. 순서를 뒤집으면 산문 속
#       영어 단어가 dispatch 로 잡힌다 (실측: critiquing-artifacts/SKILL.md 에서
#       맨 `adversarial` 이 5줄에 등장하고 전부 산문이다).
#       **콜론까지 포함**해야 한다. `agentType`(콜론 없음)으로 쓰면
#       smoke-workflow.js:8 의 주석이 19번째 dispatch 로 잡힌다.
NOTATION = re.compile(r'subagent_type:|agentType:|Agent\(|^\s*agent:\s')

# 경계 규칙: 이름 앞은 줄머리·공백·따옴표·`:` 중 하나, 뒤는 따옴표·공백·
# 쉼표·닫는괄호·줄끝 중 하나. `-` 는 경계가 아니다 — 그래야
# `adversarial` 이 `artifact-adversarial` 을 먹지 않는다.
# 접두사는 **선택적**이다: 저자가 접두사를 빼서 자기를 감사 대상에서
# 제외하는 경로를 봉쇄한다 (spec-distill/CHANGELOG.md:1197-1198 의 실패).
PRE, POST = r'(?:^|[\s"\':])', r'(?=["\'\s,)]|$)'


def name_re(n):
    return re.compile(PRE + r'(?:[A-Za-z0-9_-]+:)?' + re.escape(n) + POST)


# ── 4) 앵커 «검출»은 느슨하다 (주석 접두사 허용). 서식 검증은 축 A④ 가 한다.
#       검출을 서식 정규식으로 하면 서식 위반 앵커가 «아예 검출되지 않아»
#       A①(17 != 18) 로 RED 가 나고 A④ 를 한 번도 재지 못한다.
ANCHOR_DETECT = re.compile(r'^\s*(?:\S+\s+)?\*\*처분\*\*\s+—')

dispatch = []   # (relpath, lineno, agent)
anchors = []    # (relpath, lineno, rawline)
per_file_disp = {}
per_file_anch = {}

for f in corpus:
    rel = str(f.relative_to(REPO))
    lines = f.read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(lines, 1):
        if ANCHOR_DETECT.match(line):
            anchors.append((rel, i, line))
            per_file_anch.setdefault(rel, []).append(i)
        if not NOTATION.search(line):
            continue
        for a in agents:
            if name_re(a).search(line):
                dispatch.append((rel, i, a))
                per_file_disp.setdefault(rel, []).append(i)

per_agent = {a: 0 for a in agents}
for (_r, _l, a) in dispatch:
    per_agent[a] += 1

print("PRINT_1_agents %d" % len(agents))
print("PRINT_2_dispatch %d" % len(dispatch))
print("PRINT_3_anchors %d" % len(anchors))
for a in sorted(per_agent):
    print("PRINT_4_per_agent %s %d" % (a, per_agent[a]))
zero = sorted(a for a in per_agent if per_agent[a] == 0)

# ── 축 A① : 앵커 수 == dispatch 수 (1:1 계약)
print("AXIS_A1 %d %d" % (len(dispatch), len(anchors)))

# ── 축 A② : 위치 규칙(결정론). 각 dispatch 줄에 대해, 그 **바로 아래**
#    WINDOW 줄 안의 앵커 중 **그 사이에 다른 dispatch 줄이 없는** 것이 정확히 하나.
#
#    「∃ 완전매칭」이 아니라 결정론 배정이다 — 배정 규칙이 없으면 구현할 수
#    없고, greedy-최근접과 완전매칭은 창이 겹치는 배치에서 정확히 갈린다.
#
#    방향이 「아래」인 이유: briefing-current-state/SKILL.md 의 dispatch 는
#    frontmatter 안 6행이고 `---` 닫힘이 9행이라 «위»에는 아무것도 놓을 수 없다.
#    「위」로 쓰면 그 파일이 배달 즉시 RED 다.
a2_fail = []
for (rel, dl, ag) in dispatch:
    later_disp = sorted(x for x in per_file_disp.get(rel, []) if x > dl)
    cut = later_disp[0] if later_disp else 10 ** 9
    qualifying = [x for x in per_file_anch.get(rel, [])
                  if dl < x <= dl + WINDOW and x < cut]
    if len(qualifying) != 1:
        a2_fail.append("%s:%d(%s)->%d개" % (rel, dl, ag, len(qualifying)))
print("AXIS_A2_FAIL %s" % "|".join(a2_fail))

print("ZERO_AGENTS %s" % ",".join(zero))

# ── 축 A③ : 각 dispatch 줄은 «정확히 한 에이전트»에 귀속.
#    이것이 경계 규칙(§5.1③)의 진짜 계측기다 — 규칙이 없으면
#    critiquing-artifacts/SKILL.md:194 한 줄이 `adversarial` 과
#    `artifact-adversarial` 둘 다에 귀속되어 여기서 RED 가 난다.
attrib = {}
for (rel, dl, ag) in dispatch:
    attrib.setdefault((rel, dl), []).append(ag)
a3_fail = ["%s:%d->%s" % (r, l, "+".join(sorted(v)))
           for ((r, l), v) in sorted(attrib.items()) if len(v) != 1]
print("AXIS_A3_FAIL %s" % "|".join(a3_fail))

# ── 축 A④ : 서식 + 닫힌 어휘 + 경로 실재. 값 종류와 무관하게 «모든» 앵커에 건다.
#    A④ 가 없으면 §4.1 의 요구가 집행 자리를 잃는다 —
#    `consumer=plugins/x/scripts/없는파일.js` + 실재 리터럴이 세 축을 그대로 통과한다.
FIELD = re.compile(
    r'^\s*(?:\S+\s+)?\*\*처분\*\*\s+—\s+consumer=(\S+)\s+·\s+fail-(open|closed)'
    r'(?:\s+·\s+disclosure=(.+?))?\s*$')
tracked = set(subprocess.run(
    ["git", "-C", str(REPO), "ls-files"],
    capture_output=True, text=True, check=True).stdout.splitlines())

parsed = []     # (rel, lineno, consumer, faildir, disclosure)
a4_fail = []
for (rel, ln, raw) in anchors:
    m = FIELD.match(raw)
    if not m:
        a4_fail.append("%s:%d 서식 위반" % (rel, ln))
        continue
    cons, faildir, disc = m.group(1), m.group(2), m.group(3)
    if cons in ("orchestrator", "human"):
        pass
    elif cons.endswith(".py") or cons.endswith(".js"):
        if cons not in tracked:
            a4_fail.append("%s:%d 경로 미실재 consumer=%s" % (rel, ln, cons))
            continue
    else:
        a4_fail.append("%s:%d 닫힌 어휘 밖 consumer=%s" % (rel, ln, cons))
        continue
    if not cons.endswith(".py") and disc is None:
        a4_fail.append("%s:%d disclosure= 누락 (consumer=%s)" % (rel, ln, cons))
        continue
    parsed.append((rel, ln, cons, faildir, disc))
print("AXIS_A4_FAIL %s" % "|".join(a4_fail))

# ── 축 B : consumer= 가 `.py` 인 앵커 — 그 파일이 `adjudication` 을 import 한다.
#    가장 센 이빨이지만 `.py` 소비자에만 걸린다.
IMPORT = re.compile(
    r'^\s*(?:from\s+adjudication\s+import\b|import\s+adjudication\b)', re.M)
b_targets = [x for x in parsed if x[2].endswith(".py")]
b_fail = []
for (rel, ln, cons, _fd, _dc) in b_targets:
    src = (REPO / cons).read_text(encoding="utf-8")
    if not IMPORT.search(src):
        b_fail.append("%s:%d -> %s 가 adjudication 을 import 하지 않는다"
                      % (rel, ln, cons))
print("AXIS_B_FAIL %s" % "|".join(b_fail))

# ── 축 C : consumer= 가 `.js`·orchestrator·human 인 앵커 — disclosure= 리터럴이
#    **그 앵커가 사는 파일의 「앵커-제외 본문」**에 실재한다.
#
#    앵커 줄을 빼는 것은 선택이 아니라 «성립 조건»이다. 리터럴은 앵커 줄
#    자신에 적혀 있고 그 앵커는 검색 대상 파일 안에 있다 — 제외하지 않으면
#    저자가 무엇을 쓰든 검색이 자기 자신에 걸려 항상 GREEN 이고 이빨이 0 이다.
#    (「헤더가 문구를 만족시키면 body 를 삭제해도 GREEN」과 동형. 판정은
#    body-unique 여야 한다.)
#
#    코퍼스가 리포 전역도 플러그인 전체도 아니고 «파일 하나»인 이유: 전역이면
#    예시 리터럴 `degrade 채널` 이 proceed-gate.md:34-41 에 이미 있어 축이
#    다시 vacuous 해진다.
c_targets = [x for x in parsed if not x[2].endswith(".py")]
c_fail = []
for (rel, ln, cons, _fd, disc) in c_targets:
    lines = (REPO / rel).read_text(encoding="utf-8").splitlines()
    anchor_lines = set(per_file_anch.get(rel, []))
    body = "\n".join(t for (i, t) in enumerate(lines, 1) if i not in anchor_lines)
    if disc not in body:
        c_fail.append("%s:%d disclosure=%r 가 앵커-제외 본문에 없다"
                      % (rel, ln, disc))
print("AXIS_C_FAIL %s" % "|".join(c_fail))

# ── 인쇄 ⑤ 축별 대상 수. M10(green-expected) 의 관측 근거가 이것이다 —
#    인쇄되지 않는 수치를 관측 근거로 적는 것은 관측하지 않는 것과 같다.
print("PRINT_5_axis B %d" % len(b_targets))
print("PRINT_5_axis C %d" % len(c_targets))
PY
rc=$?
OUT="$(cat "$TMPD/out.txt")"
assert_eq "$rc" "0" "도출 스크립트가 정상 종료한다"

n_agents="$(printf '%s\n' "$OUT" | sed -n 's/^PRINT_1_agents //p')"
n_disp="$(printf '%s\n' "$OUT" | sed -n 's/^PRINT_2_dispatch //p')"
n_anch="$(printf '%s\n' "$OUT" | sed -n 's/^PRINT_3_anchors //p')"
zero="$(printf '%s\n' "$OUT" | sed -n 's/^ZERO_AGENTS //p')"

# ── vacuity 하한 — 도출이 깨진 것을 「위반 없음」으로 읽지 않는다.
#    누산기를 «루프 밖에서» 0 으로 두고 최소치를 단언하므로, 루프를 통째로
#    지워도 0 이 남아 RED 가 된다 (test_copy_of_contract.sh:916-919 의 형태).
if [ "${n_agents:-0}" -lt 1 ]; then
  no "에이전트 도출이 0 — 도출이 깨졌다 (vacuity 하한)"
else
  ok "에이전트 ${n_agents}개 도출"
fi
if [ "${n_disp:-0}" -lt 1 ]; then
  no "dispatch 줄 도출이 0 — 도출이 깨졌다 (vacuity 하한)"
else
  ok "dispatch 줄 ${n_disp}건 도출"
fi

# ── §5.1⑤ 에이전트별 dispatch >= 1. 면제값을 두지 않는다.
#    `에이전트 수 == dispatch 수` 는 «걸지 않는다» — 오늘 18/18 인 것은
#    에이전트당 dispatch 가 우연히 하나여서이고, 한 에이전트를 두 skill 에서
#    부르는 것은 정당한 편집이다.
assert_eq "$zero" "" "dispatch 0건인 에이전트가 없다 (있으면 죽은 정의이거나 락이 모르는 표기다)"

# ── 인쇄 단언 — 여섯 인쇄값이 «실제로 나오는지». 인쇄되지 않는 수치를
#    관측 근거로 적는 것은 관측하지 않는 것과 같다. 인쇄값마다 계측기가 따로 있다.
assert_grep "$OUT" '^PRINT_1_agents [0-9]+$'   "인쇄 ① 에이전트 수"
assert_grep "$OUT" '^PRINT_2_dispatch [0-9]+$' "인쇄 ② dispatch 줄 수"
assert_grep "$OUT" '^PRINT_3_anchors [0-9]+$'  "인쇄 ③ 앵커 수"
assert_grep "$OUT" '^PRINT_4_per_agent \S+ [0-9]+$' "인쇄 ④ 에이전트별 dispatch 수"

a1="$(printf '%s\n' "$OUT" | sed -n 's/^AXIS_A1 //p')"
a1_disp="${a1% *}"; a1_anch="${a1#* }"
assert_eq "$a1_anch" "$a1_disp" "축 A① 앵커 수(${a1_anch}) == dispatch 수(${a1_disp})"

a2f="$(printf '%s\n' "$OUT" | sed -n 's/^AXIS_A2_FAIL //p')"
assert_eq "$a2f" "" "축 A② 각 dispatch 아래 창에 자기 앵커가 정확히 하나"

n_scanned="$(bash "$0" --emit-scanned | wc -l | tr -d ' ')"
if [ "${n_scanned:-0}" -lt 1 ]; then
  no "인쇄 ⑥ --emit-scanned 가 빈 목록 — 커버리지 대조 대상이 사라진다"
else
  ok "인쇄 ⑥ --emit-scanned ${n_scanned}개 경로"
fi

a3f="$(printf '%s\n' "$OUT" | sed -n 's/^AXIS_A3_FAIL //p')"
assert_eq "$a3f" "" "축 A③ 각 dispatch 줄이 정확히 한 에이전트에 귀속"
a4f="$(printf '%s\n' "$OUT" | sed -n 's/^AXIS_A4_FAIL //p')"
assert_eq "$a4f" "" "축 A④ 서식 + 닫힌 어휘 + 경로 실재"

bf="$(printf '%s\n' "$OUT" | sed -n 's/^AXIS_B_FAIL //p')"
assert_eq "$bf" "" "축 B .py 소비자가 adjudication 을 import 한다"
cf="$(printf '%s\n' "$OUT" | sed -n 's/^AXIS_C_FAIL //p')"
assert_eq "$cf" "" "축 C disclosure 리터럴이 앵커-제외 본문에 실재한다"
assert_grep "$OUT" '^PRINT_5_axis B [0-9]+$' "인쇄 ⑤ 축 B 대상 수"
assert_grep "$OUT" '^PRINT_5_axis C [0-9]+$' "인쇄 ⑤ 축 C 대상 수"

finish
