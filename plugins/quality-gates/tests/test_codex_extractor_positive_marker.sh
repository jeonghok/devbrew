#!/usr/bin/env bash
# 락 A (Task 15b, 결함 A) — 이 리포가 shipping하는 codex 추출기 전부가 성공 시
# 양성 표식(`codex_failed: false`)을 낸다.
#
# 왜 이 락이 필요한가: `extract_codex_artifact_yaml.py`의 성공 경로는 `meta:` 블록
# 자체를 만들지 않았다 — `codex_failed: true`(degrade)만 있고 짝이 없었다. 소비자는
# "codex가 깨끗하게 돌았고 발견 0건"과 "무언가 조용히 깨져 빈 결과가 나왔다"를 구별할
# 수 없었다(indeterminate ≠ clean, task-15b-brief.md 결함 A). 이 파일은 어떤 AC에도
# 배정되지 않아 그 갭을 아무 락도 보지 못했다.
#
# **열거 금지.** "이 리포의 codex 추출기 목록"을 손으로 적으면 새 추출기가 생겨도
# 이 락은 못 본다 — 정확히 결함 A가 살아남은 방식이다. 대신 **러너가 실제로 부르는
# 추출기**를 코드에서 도출한다: plugins/*/scripts/ 전체에서 `codex exec`를 호출하는
# 파일(=러너)을 찾고, 각 러너의 종단 `python3 ".../X.py" ... --meta-override-exit-code`
# 블록(줄끝 `\` 연속을 따라가며 자름 — 프롬프트-빌더 등 앞선 python3 호출과 구별하는
# 열쇠가 이 플래그다)에서 실제로 호출되는 추출기 파일을 읽는다. 아무도 부르지 않는
# 추출기는 이 도출에 잡히지 않는다 — shipping 중이 아니기 때문이다(브리프의 힌트).
set -u
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"

out="$(REPO="$REPO" python3 - <<'PYEOF'
import json
import os
import re
import subprocess
import sys

REPO = os.environ["REPO"]
INVOKE_RE = re.compile(r'(^|[\s])codex[\s]+exec[\s]')
PYEXTRACT_RE = re.compile(r'python3\s+"([^"]+\.py)"')
OVERRIDE_FLAG = "--meta-override-exit-code"

fail_lines = []


def fail(msg):
    fail_lines.append(msg)


# ── 1. 러너 도출: plugins/*/scripts/*.sh 중 codex exec를 실제로 호출하는 것 ──────
scan_dirs = sorted(
    d for d in
    (os.path.join(REPO, "plugins", p, "scripts") for p in os.listdir(os.path.join(REPO, "plugins")))
    if os.path.isdir(d)
)
runners = []
for d in scan_dirs:
    for fn in sorted(os.listdir(d)):
        if not fn.endswith(".sh"):
            continue
        path = os.path.join(d, fn)
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        code_lines = [ln for ln in text.splitlines() if not ln.strip().startswith("#")]
        if any(INVOKE_RE.search(ln) for ln in code_lines):
            runners.append(path)

# positive: 스캔이 실제로 러너를 봤는가 — 없으면 "추출기 위반 0"과 "아무것도 못 봄"이
# 구별되지 않는다.
if len(runners) < 3:
    fail(f"러너 코퍼스가 너무 작다(scan_dirs={len(scan_dirs)}, runners={len(runners)}) "
         "— 도출 경로가 깨졌을 수 있다, 아래 판정은 무의미")

# ── 2. 각 러너의 종단 추출기 도출 ───────────────────────────────────────────────
def scan_for_override_call(lines):
    """override-exit-code 플래그를 동반한 python3 호출 블록에서 대상 .py 를
    찾는다. 못 찾으면 None."""
    i = 0
    while i < len(lines):
        ln = lines[i]
        if ln.strip().startswith("#"):
            i += 1
            continue
        m = PYEXTRACT_RE.search(ln)
        if m:
            blk = [ln]
            j = i
            while blk[-1].rstrip().endswith("\\") and j + 1 < len(lines):
                j += 1
                blk.append(lines[j])
            blocktext = "\n".join(x for x in blk if not x.strip().startswith("#"))
            if OVERRIDE_FLAG in blocktext:
                return m.group(1)
            i = j + 1
            continue
        i += 1
    return None


# fix round 1 (Critical 1) — 러너가 종단 추출을 **소싱하는 공유 파일에 위임**할
# 수 있다(runner_common.sh, Task 14 `codex_extract_or_fallback`). 최초 구현은
# 러너 텍스트에 문자열 "runner_common.sh"가 **등장하는지**만 봤는데, 그 술어는
# 파일을 "언급"만 해도(예: source 줄, 주석) 참이 된다 — 러너가 그 파일 안의
# 어떤 함수도 실제로 **호출하지 않아도** 폴백이 발동해, run_brief_codex_reviewer.sh
# 처럼 자기 안에 종단 python3 호출을 직접 갖는 러너에서 그 블록을 지워도(진짜
# 결함) `_RUNNER_COMMON=".../runner_common.sh"` 대입 줄 하나 때문에 여전히
# GREEN이 나왔다(리뷰 실측 재현, Critical 1). 재는 것을 "파일이 언급되는가"에서
# "그 파일이 정의하는 **함수를 러너가 실제로 호출하는가**"로 바꾼다.
FUNC_DEF_RE = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)\(\)\s*\{')


def common_functions(common_lines):
    """runner_common.sh 안에서 정의된 함수 이름 -> 그 본문(줄 리스트). 이
    파일의 함수는 전부 들여쓰기 없는 `name() {` 로 열고 들여쓰기 없는 `}` 로
    닫는 관용구를 쓴다(실측) — 그 관용구로 본문 경계를 찾는다."""
    funcs = {}
    i = 0
    while i < len(common_lines):
        m = FUNC_DEF_RE.match(common_lines[i])
        if m:
            name = m.group(1)
            body = []
            j = i + 1
            while j < len(common_lines) and common_lines[j] != "}":
                body.append(common_lines[j])
                j += 1
            funcs[name] = body
            i = j + 1
            continue
        i += 1
    return funcs


def called_function_names(lines, names):
    """`names` 중 러너가 **호출**(정의가 아니라 실행 위치)하는 것의 부분집합.
    비-주석 줄이 (선행 공백 이후) 그 이름으로 시작하고 그 뒤가 공백·따옴표·
    줄끝이어야 호출로 센다 — 문자열 리터럴 안이나 trap 인자 문자열 중간에
    있는 이름은 줄 **머리**가 아니므로 잡히지 않는다(예: `_degrade_if_empty`가
    trap의 작은따옴표 문자열 중간에 있는 것)."""
    called = set()
    for ln in lines:
        if ln.strip().startswith("#"):
            continue
        for name in names:
            if re.match(r'^\s*' + re.escape(name) + r'(?:[\s"]|$)', ln):
                called.add(name)
    return called


extractors = {}  # resolved_path -> [runner, ...] (진단용)
derive_failed = []
for r in runners:
    with open(r, encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    found_path = scan_for_override_call(lines)
    if not found_path:
        common = os.path.join(os.path.dirname(r), "runner_common.sh")
        if os.path.isfile(common):
            with open(common, encoding="utf-8") as fh:
                common_lines = fh.read().splitlines()
            funcs = common_functions(common_lines)
            if funcs:
                for name in called_function_names(lines, funcs.keys()):
                    candidate = scan_for_override_call(funcs[name])
                    if candidate:
                        found_path = candidate
                        break
    if not found_path:
        derive_failed.append(r)
        continue
    resolved = os.path.realpath(os.path.join(os.path.dirname(r), os.path.basename(found_path)))
    extractors.setdefault(resolved, []).append(r)

if derive_failed:
    fail("종단 추출기를 도출하지 못한 러너: " + ", ".join(os.path.relpath(x, REPO) for x in derive_failed))

# mA-2 (음의 짝): 도출된 추출기 수가 1보다 커야 한다 — 하나만 잡고 통과하면
# 계측기가 붕괴한 것이다(브리프 명시 요구).
print(f"도출된 러너: {len(runners)}개, 도출된 고유 추출기: {len(extractors)}개")
for ex, rs in sorted(extractors.items()):
    print(f"  - {os.path.relpath(ex, REPO)}  <-  {', '.join(os.path.relpath(x, REPO) for x in rs)}")
if len(extractors) <= 1:
    fail(f"도출된 추출기 수가 {len(extractors)} — 1보다 커야 한다(mA-2 sanity)")

# ── 3. 각 추출기에 clean 샘플을 먹여 codex_failed: false를 잰다 ─────────────────
# 두 fence 관용구(json-fence / yaml·plain-fence)가 이 리포의 세 추출기 계열을
# 전부 덮는다. 어느 쪽이 맞는 관용구인지는 하드코딩하지 않는다 — 둘 다 시도해서
# **하나라도** 양성 표식을 내면 통과다(추출기가 실제로 요구하는 형태는 추출기
# 자신의 파서가 정한다).
def jsonl_event(text):
    return json.dumps({"type": "item.completed",
                        "item": {"type": "agent_message", "text": text}}) + "\n"


json_payload = json.dumps(
    {"findings": [], "d_verdicts": [], "oq_answers": [], "new_open_questions": []})
CLEAN_SAMPLES = [
    ("json-fence", jsonl_event("answer:\n```json\n" + json_payload + "\n```\n")),
    ("yaml-fence", jsonl_event("answer:\n```yaml\nfindings: []\n```\n")),
]

FALSE_RE = re.compile(r'codex_failed"?\s*:\s*false')

marker_missing = []
for ex in sorted(extractors):
    if not os.path.isfile(ex):
        fail(f"{os.path.relpath(ex, REPO)}: 도출된 경로에 파일이 없다")
        continue
    attempts = []
    ok = False
    for label, sample in CLEAN_SAMPLES:
        p = subprocess.run(["python3", ex], input=sample, capture_output=True, text=True)
        attempts.append(f"{label}: rc={p.returncode} out={p.stdout[:150]!r}")
        if p.returncode == 0 and FALSE_RE.search(p.stdout):
            ok = True
            break
    if not ok:
        marker_missing.append(os.path.relpath(ex, REPO))
        fail(f"{os.path.relpath(ex, REPO)}: 두 clean 샘플 모두에서 codex_failed: false를 "
             "못 냈다 — " + " | ".join(attempts))

if fail_lines:
    print("FAIL:")
    for line in fail_lines:
        print("  - " + line)
    sys.exit(1)

print(f"PASS: 도출된 추출기 {len(extractors)}개 전부 clean 샘플에서 codex_failed: false")
sys.exit(0)
PYEOF
)"
rc=$?
echo "$out"
if [ "$rc" -eq 0 ]; then
  echo "  PASS: 모든 shipping codex 추출기가 성공 시 양성 표식을 낸다"
else
  echo "  ✗ FAIL: 위 상세 참고"
fi
exit "$rc"
