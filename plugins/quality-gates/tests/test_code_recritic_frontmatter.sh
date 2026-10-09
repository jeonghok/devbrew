#!/usr/bin/env bash
# test_code_recritic_frontmatter.sh — AC10 · V4: code-recritic 의 frontmatter 와 출력 계약.
#
# 재비판자는 판정 각도의 주 판정자다. 쓰기 도구를 가지면 Law 2 위반이고, opus 가 아니면 재결정
# R3 위반이며, 출력 블록 이름이 합성기의 BLOCK 과 다르면 모든 응답이 「판정자 사망」으로 읽힌다.
# frontmatter 가 YAML 로 파싱되지 않으면 런타임은 전 도구로 싣는다 — 그래서 tools · model 을
# 줄 grep 과 YAML 파서 양쪽에서 잰다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
A="$PLUGIN_ROOT/agents/code-recritic.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
[ -f "$A" ] || { no "agent 파일 부재: $A"; finish; exit; }

fm="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$A")"
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
assert_grep "$fm" '^name: code-recritic$' "name"
assert_eq "$(printf '%s\n' "$fm" | grep -cE "$MODEL_KEY")" "1" "model 키는 정확히 한 줄"
assert_eq "$(printf '%s\n' "$fm" | grep -E "$MODEL_KEY")" "model: opus" "model: opus (재결정 R3)"
assert_grep "$fm" '^tools: Read, Grep, Glob$' "tools: Read, Grep, Glob (Law 2 — 쓰기·실행·웹 없음)"
assert_not_grep "$fm" '^(allowedTools|disallowedTools):' "allowlist 하나로만 막는다"

# YAML 파서가 보는 값 — 줄 grep 이 맞아도 파싱이 깨지면 런타임은 전 도구로 싣는다.
parsed="$(python3 -c '
import sys, yaml
t = open(sys.argv[1], encoding="utf-8").read()
assert t.startswith("---\n")
fm = yaml.safe_load(t[4:t.find("\n---\n", 4)])
assert isinstance(fm, dict)
print("tools=%s" % fm.get("tools"))
print("model=%s" % fm.get("model"))
print("slots=%s" % " ".join(s["tag"] for s in fm["input_slots"]))' "$A" 2>&1)"
assert_grep "$parsed" '^tools=Read, Grep, Glob$' "YAML 파싱 — tools 값이 정확히 Read, Grep, Glob"
assert_grep "$parsed" '^model=opus$' "YAML 파싱 — model 값이 opus"
assert_grep "$parsed" '^slots=project_dir scope findings diff intent profile$' "입력 슬롯 여섯 — 출처·이력 슬롯이 없다"

# 출력 블록 이름은 리터럴로 잰다 — 합성기 import 가 실패해 값이 비면 `^```$` 가 아무 펜스에나
# 맞아 공허하게 통과한다(C-6).
assert_file_grep "$A" '^```qg-recritic$' "agent 의 출력 예시가 qg-recritic 블록을 쓴다"
block="$(python3 -c "import sys; sys.path.insert(0, '$PLUGIN_ROOT/scripts'); import synthesize_findings as s; print(s.BLOCK)" 2>/dev/null)"
assert_eq "$block" "qg-recritic" "합성기의 BLOCK 상수가 agent 의 블록 이름과 같다"
assert_file_grep "$A" 'verdict: lower' "lower 판정을 예시한다"
assert_file_grep "$A" '목적지는 `SUGGESTION` 하나뿐이다' "lower 의 목적지는 SUGGESTION 하나 (관문 E)"
assert_file_grep "$A" '반드시 `evidence` 에 의도 출처나 diff 를 인용' "lower 에는 근거가 필요하다"
finish
