#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/quality-pipeline/references/differential-test.md plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/verdict.py plugins/quality-gates/scripts/angles.py plugins/quality-gates/scripts/recritic_bridge.py plugins/quality-gates/tests/lib/recritic_fixture.sh
# test_pipeline_verdict_wiring.sh — 판정 상시 배선 (설계 §6.1 ⑤ · §6.3.5 · §6.4.3, AC2 · AC8–AC12).
#
# 합성기 쪽 총 함수는 test_verdict_vocabulary.sh · test_angle_coverage.sh 가 잰다. 이 락은
# 오케스트레이터가 그것을 «실제로 부르는가»를 잰다 — 부르지 않으면 두 락의 GREEN 은 락
# 안에서만 참이다.
#
# 잴 수 없는 것: 모델이 각도 파일을 «참되게» 쓰는가(설계 §15-4). 이 락은 모양과 합성기의
# 행동만 잰다.
set -u
[ "${1:-}" = "--emit-scanned" ] && { printf '%s\n' \
  plugins/quality-gates/skills/quality-pipeline/SKILL.md \
  plugins/quality-gates/skills/quality-pipeline/references/differential-test.md \
  plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/verdict.py \
  plugins/quality-gates/scripts/angles.py plugins/quality-gates/scripts/recritic_bridge.py \
  plugins/quality-gates/tests/lib/recritic_fixture.sh; exit 0; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"
. "$SCRIPT_DIR/lib/recritic_fixture.sh"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
REF="$PLUGIN_ROOT/skills/quality-pipeline/references/differential-test.md"
V="$PLUGIN_ROOT/scripts/verdict.py"
export PYTHONDONTWRITEBYTECODE=1

case_every_synth_call_emits_verdict_and_angles() {
  # Fix round 1, Minor 5 — 옛 버전은 «펜스» 단위로 봤다: 한 펜스 안 여러 호출 중 하나만
  # 플래그를 실어도(S2), 다른 언어 태그의 새 펜스(S1), 플래그가 주석 안에만 있어도(S3)
  # 전부 GREEN 이었다. 이제 «호출» 단위 — 모든 펜스 언어를 보고, `#` 주석을 지운 뒤
  # `\` 로 이어지는 논리 줄 단위로 쪼개 그 호출 자신의 줄에서만 플래그를 찾는다.
  # trivia 호출(T1 — 콜을 echo 로 갈아치우고 사유를 주석에만 남기는 변이)은 verdict.py
  # 와 --reason trivia 가 «같은 논리 줄»에 있어야 한다.
  local got
  got=$(python3 - "$SKILL" "$REF" <<'PY'
import re, sys

def strip_hash_comment(line):
    # Fix round 2, Minor B — bash 처럼 «단어 시작 위치» 의 `#` 만 주석으로 지운다.
    # 단어는 줄 시작 · 공백 뒤 · `;` `|` `&` `(` 뒤(공백 없이 붙어도)에서 시작한다.
    # 옛 버전(「공백 또는 줄 시작 뒤의 #」)은 `;#`(S7 — 공백 없이 붙은 `;#comment`)를
    # 못 잡았다. 따옴표 안의 `#` 는 «단어 시작」이라도 절대 안 지운다(P2/P3 — 그
    # 뒤에 이어지는 `\` continuation 을 삼키면 다음 논리 줄이 통째로 잘못 붙는다).
    quote = None
    at_word_start = True
    i, n = 0, len(line)
    while i < n:
        c = line[i]
        if quote:
            if c == quote:
                quote = None
            elif quote == '"' and c == '\\' and i + 1 < n:
                i += 1
            at_word_start = False
            i += 1
            continue
        if c.isspace():
            at_word_start = True
            i += 1
            continue
        if c in ';|&(':
            at_word_start = True
            i += 1
            continue
        if c == '#' and at_word_start:
            return line[:i]
        if c in ("'", '"'):
            quote = c
            at_word_start = False
            i += 1
            continue
        if c == '\\' and i + 1 < n:
            i += 2
            at_word_start = False
            continue
        at_word_start = False
        i += 1
    return line

def strip_comments(line):
    # `//` — Agent({...}) 의사-JS 펜스의 처분 주석(`  // **처분** —
    # consumer=...synthesize_findings.py...`)은 줄 전체가 주석이다 — 그 안의
    # `synthesize_findings.py` 언급을 호출로 오인하면 안 된다. 줄 «전체»가 `//`
    # 로 시작할 때만 지운다 — `sed -n 's/^x: //p'` 처럼 줄 중간의 `//` 는 셸
    # 문법(빈 치환)이라 건드리지 않는다.
    line = strip_hash_comment(line)
    if line.lstrip().startswith('//'):
        return ''
    return line

def logical_lines(body):
    out, buf = [], ""
    for raw in body.split("\n"):
        line = strip_comments(raw)
        if line.rstrip().endswith("\\"):
            buf += line.rstrip()[:-1] + " "
        else:
            buf += line
            out.append(buf)
            buf = ""
    if buf:
        out.append(buf)
    return out

calls = bad = trivia = 0
for path in sys.argv[1:]:
    text = open(path, encoding="utf-8").read()
    for body in re.findall(r"^[ \t]*```[a-zA-Z]*\n(.*?)^[ \t]*```[ \t]*$", text, re.M | re.S):
        for ll in logical_lines(body):
            if "synthesize_findings.py" in ll:
                calls += 1
                if "--emit-verdict" not in ll or "--angles" not in ll:
                    bad += 1
            if "verdict.py" in ll and "--reason trivia" in ll:
                trivia += 1
print(f"CALLS:{calls}")
print(f"BAD:{bad}")
print(f"TRIVIA:{trivia}")
PY
)
  assert_grep "$got" '^CALLS:[1-9]' "합성기를 부르는 호출이 하나 이상 있다(0 이면 아래가 공허하다)"
  assert_grep "$got" '^BAD:0$'      "합성기를 부르는 호출 ∀(펜스 언어 무관 · 호출 단위) 가 --emit-verdict 와 --angles 를 싣는다"
  assert_grep "$got" '^TRIVIA:[1-9]' "trivia 호출은 verdict.py 와 --reason trivia 가 같은 논리 줄에 있다(주석만으로는 안 된다)"
}

case_blocking_angle_dispatches_are_fail_closed() {
  # §6.3.5 — 보안 · 판정 각도 디스패치는 fail-closed. 처분 줄은 dispatch 블록 바로 안에 있다.
  local got
  got=$(python3 - "$SKILL" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
for agent in ("quality-gates:security-reviewer", "quality-gates:doc-recritic"):
    m = re.search(r'subagent_type:\s*"' + re.escape(agent)
                  + r'",?\s*\n\s*//\s*\*\*처분\*\*\s*—\s*consumer=\S+\s*·\s*fail-(open|closed)', text)
    print(f"{agent}:{m.group(1) if m else 'MISSING'}")
PY
)
  assert_grep "$got" '^quality-gates:security-reviewer:closed$' "보안 각도 디스패치는 fail-closed"
  assert_grep "$got" '^quality-gates:doc-recritic:closed$'      "판정 각도 디스패치는 fail-closed"
}

case_reason_literals_are_closed_and_pinned() {
  # SKILL · 레퍼런스가 싣는 `--reason <사유>` 리터럴 ∀ ⊆ verdict.REASONS, 그리고 그 집합은
  # 파일 밖 핀과 같다 — 재도출만 하면 오타(`killswitch`)가 새 이름으로 샌다.
  local got
  got=$(python3 - "$SKILL" "$REF" "$PLUGIN_ROOT/scripts" <<'PY'
import re, sys
sys.path.insert(0, sys.argv[3]); import verdict
found = set()
for path in sys.argv[1:3]:
    found |= set(re.findall(r"--reason ([a-z][a-z-]*)", open(path, encoding="utf-8").read()))
print("OUTSIDE:" + ",".join(sorted(found - set(verdict.REASONS))))
print("SET:" + " ".join(sorted(found)))
PY
)
  assert_grep "$got" '^OUTSIDE:$' "SKILL 이 싣는 사유는 전부 닫힌 열거 안이다"
  assert_grep "$got" '^SET:error-axis kill-switch scope-empty silent-drop trivia$' \
    "SKILL 이 싣는 사유 집합(핀) — declaration-invalid · merge-conflict 는 4c"
}

case_angle_template_is_total() {
  # SKILL 의 각도 파일 견본이 angles.parse 를 통과한다. 견본이 셋 중 하나를 빠뜨리거나 문법
  # 밖 상태를 적으면 모델이 그대로 베껴 쓰는 파일이 exit 4 가 된다.
  local got
  got=$(python3 - "$SKILL" "$PLUGIN_ROOT/scripts" <<'PY' 2>/dev/null
import re, sys
sys.path.insert(0, sys.argv[2]); import angles
text = open(sys.argv[1], encoding="utf-8").read()
blocks = re.findall(r"^[ \t]*```text\n(.*?)^[ \t]*```[ \t]*$", text, re.M | re.S)
cands = [b for b in blocks if re.search(r"^\s*security:", b, re.M)]
print(f"N:{len(cands)}")
for b in cands:
    angles.parse("\n".join(l.strip() for l in b.splitlines()))
print("PARSED")
PY
) || true
  assert_grep "$got" '^N:1$'    "각도 파일 견본이 정확히 하나 있다"
  assert_grep "$got" '^PARSED$' "견본이 angles.parse 를 통과한다(세 각도 · 문법 안)"
}

case_differential_runs_inside_every_iteration() {
  # Review Focus 3 · R-AC — ② 는 iteration 루프 «안»이다.
  local body it d fin
  body=$(awk '/^## Pipeline$/{f=1;next} f&&/^## /{exit} f' "$SKILL")
  it=$(printf '%s\n' "$body" | grep -n 'iteration N = 1\.\.5' | head -1 | cut -d: -f1)
  d=$(printf '%s\n' "$body" | grep -n '②' | head -1 | cut -d: -f1)
  fin=$(printf '%s\n' "$body" | grep -n 'Final Summary' | head -1 | cut -d: -f1)
  local inside=0
  if [ -n "$it" ] && [ -n "$d" ] && [ -n "$fin" ] && [ "$it" -lt "$d" ] && [ "$d" -lt "$fin" ]; then inside=1; fi
  assert_eq "$inside" "1" "② 가 iteration 항목과 Final Summary 사이(루프 안)에 있다"
  assert_grep "$body" '매 iteration 돈다' "② 가 매 iteration 돈다고 적혀 있다"
}

case_security_switch_is_not_certified_even_with_zero_findings() {
  # Review Focus 5 · §6.5.1 9행 — 보안 kill switch 의 새 뜻: 배너가 아니라 판정이다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []
added: []'
  printf 'security: absent\nadjudication: filled\ndifferent-premise: filled\n' > "$T/angles.txt"
  local out; out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt")
  assert_grep "$out" '^verdict: not-certified$' "보안 각도 부재는 탐지 0 이어도 clean 이 아니다"
  assert_grep "$out" '^reason: angle-absent$'   "사유는 angle-absent"
  printf 'security: filled\nadjudication: filled\ndifferent-premise: filled\n' > "$T/angles.txt"
  out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt")
  assert_grep "$out" '^verdict: clean$' "같은 실행에서 보안 각도가 채워지면 clean(양의 짝)"
  rm -rf "$T"
}

case_different_premise_absent_is_disclosed_not_blocked() {
  # AC12 — 다른 전제(codex) 부재는 공시만 한다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []
added: []'
  printf 'security: filled\nadjudication: filled\ndifferent-premise: absent(not-installed)\n' > "$T/angles.txt"
  local out; out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt")
  assert_grep "$out" '^verdict: clean$'                                 "다른 전제 부재는 막지 않는다"
  assert_grep "$out" '^  different-premise: absent\(not-installed\)$'  "부재가 각도 블록에 공시된다"
  rm -rf "$T"
}

case_caller_reasons_reach_the_verdict() {
  # AC9 · R-Y — 호출자 사유가 판정에 닿는다. 탐지 0 · 각도 전부 filled 인 «깨끗한» 실행에
  # 사유 하나씩을 얹는다.
  local T r out; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []
added: []'
  printf 'security: filled\nadjudication: filled\ndifferent-premise: filled\n' > "$T/angles.txt"
  for r in kill-switch scope-empty silent-drop error-axis; do
    out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --reason "$r")
    assert_grep "$out" '^verdict: not-certified$' "--reason $r → not-certified"
    assert_grep "$out" "^reason: $r\$"            "사유는 $r"
  done
  out=$(python3 "$V" --reason trivia)
  assert_grep "$out" '^reason: trivia$' "trivia 는 verdict.py 가 직접 낸다"
  rm -rf "$T"
}

case_degraded_ledger_row_reaches_silent_drop() {
  # 컨트롤러 ruling(carry-notes Task 8, R-Y ADDITION) — R8 원장(runtime-evidence.md)의
  # floor 5차원 중 하나라도 `degraded` 이거나 unclaimed unit 이 있으면 `check_qa_ledger.py`
  # 는 원장 내부 일관성만 보고 그래도 exit 0 을 낼 수 있다(구조 게이트가 이 축을 못 잡는다).
  # SKILL Step 4 의 판정 입력 표가 이 경우를 별도 행으로 `--reason silent-drop` 에 연결하지
  # 않으면 그 실행이 clean 으로 샌다.
  #
  # Fix round 1, Important 1 — 옛 버전은 표 «창 전체» 에서 `--reason silent-drop` 을 찾았다.
  # 그런데 `check_qa_ledger.py non-zero` 행(SKILL.md:514)도 같은 리터럴을 싣고 있어, L1(이
  # 행의 오른쪽 칸을 「싣지 않는다 — 공시만 한다」로 바꿔치기)· L2(「없음 — --reason
  # silent-drop 은 위 non-zero 행에만」으로 바꿔치기) 둘 다 창 안 다른 행이 리터럴을
  # 대신 만족시켜 GREEN 으로 남았다. 이제 *이 행 자신*(degraded· unclaimed 를 동시에 담은
  # «그 줄»)에서만 잰다 — 다른 행이 대신 만족시킬 수 없다.
  #
  # 최종 리뷰 M2 — 이 행은 `floor:attribution` degraded 에도 발화했는데, 그 값은
  # `--differential` 행(위)이 이미 `degrade_causes` 로 옮기는 것과 겹치고, `silent-drop` 이
  # REASONS 에서 먼저 정렬돼 더 구체적인 사유(baseline-unrunnable · error-axis ·
  # granularity-smear)를 덮어썼다. `floor:verification` degraded 이거나 `unclaimed` unit
  # 존재로 좁혔다 — SKILL.md 와 레퍼런스(R8 표 미러) 양쪽에서.
  #
  # 최종 리뷰(2차) — 「5차원」 리터럴 부재만 보는 옛 검사는 세 우회를 놓쳤다:
  # (a) 「어느 floor 차원이든(`floor:verification` 포함)」처럼 "5차원" 없이 다시 넓히기,
  # (b) `이거나`(OR)를 `이고`(AND)로 바꿔 두 조건이 «동시»일 때만 발화하게 좁히기(반대
  # 방향 결함 — 실제로는 과소-발화),
  # (c) `floor:attribution` 으로 조건 자체를 바꿔치면서 `floor:verification` 이라는
  # 단어는 설명절에 남겨 두기.
  # 이제 그 행 자신에서 다섯을 함께 잰다: `floor:verification` · `unclaimed` 존재,
  # `floor:attribution` 부재, OR 접속사(`이거나`/`또는`) 존재, 「5차원」도 「어느 …
  # 차원」도 부재.
  local got
  got=$(python3 - "$SKILL" "$REF" <<'PY'
import re, sys
rows = []
for path in sys.argv[1:3]:
    text = open(path, encoding="utf-8").read()
    # "exit 0" 도 요구한다 — REF 에는 이 목표 행과 무관하게 degraded·unclaimed 를
    # 둘 다 언급하는 다른 산문(R8 표의 일반 설명 행 · unclaimed 단독 규칙 문단)이
    # 있어, 그 둘만으로는 목표 행(판정 입력 라우팅 행)을 못 가른다.
    rows += [l for l in text.splitlines()
             if "degraded" in l and "unclaimed" in l and "exit 0" in l]
print(f"ROWS:{len(rows)}")
ok = 0
narrow_ok = 0
for l in rows:
    has_reason = "--reason silent-drop" in l
    negated = any(neg in l for neg in ("싣지 않는다", "없음", "공시만"))
    if has_reason and not negated:
        ok += 1
    has_verification = "floor:verification" in l
    has_unclaimed = "unclaimed" in l
    no_attribution_leak = "floor:attribution" not in l
    has_or_join = ("이거나" in l or "또는" in l)
    no_any_dimension_leak = not re.search(r"5차원|어느[^\n]{0,12}차원", l)
    if (has_verification and has_unclaimed and no_attribution_leak
            and has_or_join and no_any_dimension_leak):
        narrow_ok += 1
print(f"OK:{ok}")
print(f"NARROW_OK:{narrow_ok}")
PY
)
  assert_grep "$got" '^ROWS:2$' "degraded 이면서 unclaimed 인 조건을 담은 행이 SKILL·레퍼런스 각각 하나씩(합쳐 둘) 있다"
  assert_grep "$got" '^OK:2$'   "그 행들 자신이 --reason silent-drop 을 싣고 부정형(싣지 않는다·없음·공시만)을 담지 않는다"
  assert_grep "$got" '^NARROW_OK:2$' "그 행들이 floor:verification 으로 좁혀졌고 「floor 5차원」으로 도로 넓어지지 않았다"
  # 양의 짝 — 새 행이 정상 경로(check_qa_ledger.py 가 돌아 원장이 전부 filled 인 실행)의
  # --differential 행을 밀어내지 않았다.
  assert_grep "$(cat "$SKILL")" -- '--differential "<\$aggregate_yaml' \
    "정상 --differential 행이 SKILL 표에 여전히 남아 있다(새 행이 대체하지 않았다)"
  assert_grep "$(cat "$REF")" -- '--differential "\$aggregate_yaml"' \
    "정상 --differential 행이 레퍼런스 R8 표에도 여전히 남아 있다(새 행이 대체하지 않았다)"
}

case_pre_r6_abort_reaches_error_axis_catchall() {
  # Fix round 1, Important 2 → Fix round 2, finding A(open) — 컨트롤러 ruling 은
  # «R-init 가드»만이 아니라 진짜 포괄이다: ② 가 kill switch 없이 R6 집계까지
  # «어느 스텝에서든» 끝나지 못하면(R-init 가드 · R3 갭 게이트의 `중단` 선택 ·
  # 그 밖의 R1–R5 중단) 전부 이 행이다. Fix round 1 판은 R-init 만 이름 붙여 실제
  # 포괄이 아니었다 — R3 의 `중단` 은 여전히 어떤 행에도 안 걸렸다. 이제 같은 줄에
  # `R6` · `중단` · `--reason error-axis` 뿐 아니라 `R-init` 과 `R3` 이 «함께» 있는지
  # 잰다 — 후자 둘이 없으면 R-init 전용으로 좁혀진 것이다(narrow-back 변이가 이걸
  # 잡는다). R2·R4·R5b 가 degrade 로 R6 까지 이어지는 정상 경로는 이 행의 대상이
  # «아니다» — 그건 R6-non-zero 행이 잡는다(그 행은 `중단` 을 안 써서 이 검색에
  # 안 걸린다, 겹쳐도 무방하지만 오늘은 안 겹친다).
  local got
  got=$(python3 - "$SKILL" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
rows = [l for l in text.splitlines()
        if "R6" in l and "중단" in l and "error-axis" in l]
print(f"ROWS:{len(rows)}")
ok = sum(1 for l in rows
         if "--reason error-axis" in l and "R-init" in l and "R3" in l)
print(f"OK:{ok}")
PY
)
  assert_grep "$got" '^ROWS:1$' "R6 집계 전 어느 스텝에서든 중단을 담은 행이 정확히 하나 있다"
  assert_grep "$got" '^OK:1$'   "그 행이 --reason error-axis 를 싣고 R-init·R3 를 «함께» 언급한다(R-init 전용으로 좁히면 RED)"
}

case_pre_r6_abort_catchall_mirrored_in_reference() {
  # Fix round 2, finding A — 레퍼런스 R8 의 판정 입력 표도 SKILL Step 4 와 같은
  # 포괄 행을 거울처럼 갖고 있어야 한다. 미러 행 삭제(F1 계열)를 독립적으로 잡는다.
  local got
  got=$(python3 - "$REF" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
rows = [l for l in text.splitlines()
        if "R6" in l and "중단" in l and "error-axis" in l]
print(f"ROWS:{len(rows)}")
ok = sum(1 for l in rows
         if "--reason error-axis" in l and "R-init" in l and "R3" in l)
print(f"OK:{ok}")
PY
)
  assert_grep "$got" '^ROWS:1$' "레퍼런스 R8 표에도 같은 포괄 행이 정확히 하나 있다"
  assert_grep "$got" '^OK:1$'   "그 행이 --reason error-axis 를 싣고 R-init·R3 를 함께 언급한다"
}

case_r3_stop_choice_routes_to_error_axis() {
  # Fix round 2, finding A — R3 갭 게이트의 `중단` 선택지는 (fix round 1까지) 어디로도
  # 가지 않았다: 사용자가 고르면 파이프라인이 조용히 죽었다. 레퍼런스 R3 절 자신이
  # 「② 를 끝내고 SKILL Step 4 로 간다 — --reason error-axis」 를 명시하는지 R3
  # 섹션 창(다음 **Step R4 전까지)으로 좁혀 잰다 — 창 밖(예: 포괄 행 자신의 `중단`
  # 언급)이 대신 만족시키지 못하게.
  local got
  got=$(python3 - "$REF" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'\*\*Step R3 —.*?(?=\*\*Step R4 )', text, re.S)
window = m.group(0) if m else ""
print(f"WINDOW_LEN:{len(window)}")
print(f"HAS_STOP:{1 if '중단' in window else 0}")
print(f"HAS_ROUTE:{1 if '--reason error-axis' in window else 0}")
PY
)
  assert_grep "$got" '^WINDOW_LEN:[1-9]' "R3 섹션 창을 찾았다(0 이면 앵커가 깨졌다)"
  assert_grep "$got" '^HAS_STOP:1$'  "R3 창에 「중단」 선택지가 있다"
  assert_grep "$got" '^HAS_ROUTE:1$' "R3 창 자신이 --reason error-axis 라우트를 적는다(창 밖 포괄 행이 대신 못 채운다)"
}

case_security_kill_switch_routes_to_absent() {
  # Fix round 1, Important 3(a)(plan-mandated) — Review Focus 5 의 A2 변이(각도
  # 표 :499 를 `filled` 로, IF item 4 :287 를 `security: filled` 로 바꿔치기)가
  # 기존 락 전부를 GREEN 인 채로 통과시켰다: 옛 락은 한 번도 «이 kill switch 가
  # absent 로 간다» 는 라우팅 자체를 재지 않았다(합성기 행동만 rf_synth 픽스처로
  # 쟀지, SKILL 문서가 그 경로로 실제로 매핑하는지는 안 쟀다). 이제 세 지점을
  # 각각 같은-줄/같은-문단으로 고정한다.
  local got
  got=$(python3 - "$SKILL" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
lines = text.splitlines()

# (i) 각도 표의 kill-switch 행 — `| | `absent` | `DEVBREW_...SECURITY_REVIEWER=1` |`
tbl = [l for l in lines if l.lstrip().startswith("|") and "DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1" in l]
print(f"TBL_ROWS:{len(tbl)}")
tbl_ok = sum(1 for l in tbl if "absent" in l and "filled" not in l)
print(f"TBL_OK:{tbl_ok}")

# (ii) IF item 4 — "각도 파일(Step 4)에" 와 같은 줄에 `security: absent`
item4 = [l for l in lines if "각도 파일(Step 4)에" in l]
print(f"ITEM4_ROWS:{len(item4)}")
item4_ok = sum(1 for l in item4 if "security: absent" in l and "security: filled" not in l)
print(f"ITEM4_OK:{item4_ok}")

# (iii) fail-closed 문단 — "absent(source-failed)" 를 담는다(문단 창, 다음 빈 줄까지)
m = re.search(r'\*\*fail-closed 의 뜻\*\*.*?(?=\n\s*\n)', text, re.S)
print(f"FC_OK:{1 if (m and 'absent(source-failed)' in m.group(0)) else 0}")
PY
)
  assert_grep "$got" '^TBL_ROWS:1$'  "각도 표의 보안 kill-switch 행이 정확히 하나 있다"
  assert_grep "$got" '^TBL_OK:1$'    "그 행이 absent 이고 filled 가 아니다(A2 가 filled 로 바꾸면 RED)"
  assert_grep "$got" '^ITEM4_ROWS:1$' "IF item 4(각도 파일(Step 4)에 쓰는 줄)가 정확히 하나 있다"
  assert_grep "$got" '^ITEM4_OK:1$'   "그 줄이 security: absent 를 쓰고 security: filled 가 아니다"
  assert_grep "$got" '^FC_OK:1$'      "fail-closed 문단이 absent(source-failed) 로 매핑한다"
}

case_differential_kill_switch_env_name_is_pinned() {
  # Fix round 1, Important 3(b) — KS 변이(SKILL 의 세 자리 모두에서
  # DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST 를 오탈자로 바꿔치기)가 R-V 의
  # 보안 컨트롤을 무력화해도 옛 락은 잡지 못했다. 정확한 이름을 이 락 «안에서» 한 번
  # 핀하고, ② 를 건너뛴다는 문단과 kill-switch 색인 둘 다 그 정확한 철자를 쓰는지 잰다.
  local KS_ENV='DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST'
  local got
  got=$(python3 - "$SKILL" "$KS_ENV" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
env = sys.argv[2]
m = re.search(r'\*\*Kill switch —[^\n]*' + re.escape(env) + r'=1.*?(?=\n\s*\n)', text, re.S)
para = m.group(0) if m else ""
print(f"PARA_ENV:{1 if env in para else 0}")
print(f"PARA_SKIP:{1 if ('②' in para and ('건너뛴다' in para)) else 0}")
print(f"PARA_REASON:{1 if '--reason kill-switch' in para else 0}")
idx_lines = [l for l in text.splitlines() if l.lstrip().startswith('-') and env in l]
print(f"IDX_ROWS:{len(idx_lines)}")
PY
)
  assert_grep "$got" '^PARA_ENV:1$'    "Kill-switch 문단이 정확한 env 이름을 싣는다(오탈자면 RED)"
  assert_grep "$got" '^PARA_SKIP:1$'   "그 문단이 ② 를 건너뛴다고 적는다"
  assert_grep "$got" '^PARA_REASON:1$' "그 문단이 --reason kill-switch 를 싣는다"
  assert_grep "$got" '^IDX_ROWS:1$'    "kill-switch 색인에도 같은 정확한 철자의 행이 하나 있다"
}

case_differential_defect_zero_kept_routes_to_fixloop() {
  # 최종 리뷰 I1(1차) → 2차 re-review 지적(section-window 는 같은-줄이 아니다) — 옛 버전은
  # Step 4.5–Fix-loop decision 사이 거대한 창 «전체» 에서 네 토큰의 존재만 봤다. 그러면
  # I1-C(라우팅 문장은 그대로 두고 실제 목적지만 Final Summary 로 바꿔치기 — "Fix-loop
  # decision" 단어 자체는 남겨 언급만 함) · I1-D(resolution_disclosure 단어는 남기고
  # verbatim/그대로 지시만 삭제) · I1-E(STILL_GREEN 선택을 "아닌"에서 "인 것만"으로 뒤집기 —
  # 단어 STILL_GREEN 은 그대로) 셋 다 창 안 어딘가에 토큰이 남아 GREEN 으로 샜다. 이제 각
  # 사실을 **그 사실이 실제로 적힌 좁은 구간**(정규식으로 앵커 사이만 자르고 공백을
  # 접어 한 "논리 줄"로 만든 것)에서 잰다 — 다른 구간이 대신 만족시킬 수 없다.
  local got
  got=$(python3 - "$SKILL" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()

def norm(s):
    return re.sub(r'\s+', ' ', s)

def seg(pattern):
    m = re.search(pattern, text, re.S)
    return norm(m.group(0)) if m else None

# --- I1-D: resolution_disclosure 공시 줄 — 「verbatim/그대로」 지시가 같은 좁은 구간에 있다 ---
d = seg(r'`resolution_disclosure:`.{0,80}')
print(f"DISCLOSURE_FOUND:{1 if d is not None else 0}")
print(f"DISCLOSURE_VERBATIM:{1 if (d and re.search(r'verbatim|그대로', d)) else 0}")

# --- I1-E: non-green 선택 — STILL_GREEN 바로 뒤에 「아닌」 부정이 있고, 예시로
#     NEW_REGRESSION 이 있으며, "STILL_GREEN 만/인 것만"(선택 반전) 은 없다 ---
a = seg(r'.{0,20}STILL_GREEN.{0,160}')
print(f"ATTR_FOUND:{1 if a is not None else 0}")
# 이 정규식은 backtick 을 담는다 — f-string 중괄호 «안» 에 직접 넣지 않는다
# (bash 가 $(...) 의 짝을 heredoc 본문까지 통틀어 backtick 짝수로 찾다가, 홀수
# backtick 하나로 이 스크립트 자체의 문법을 깬다 — 실측: /qg 최종 리뷰 2차 라운드).
attr_negated = bool(a and re.search(r'STILL_GREEN`?\s*이?\s*\*{0,2}아닌', a))
print(f"ATTR_NEGATED:{1 if attr_negated else 0}")
print(f"ATTR_EXAMPLE:{1 if (a and 'NEW_REGRESSION' in a) else 0}")
print(f"ATTR_FLIPPED_TO_ONLY_GREEN:{1 if (a and re.search(r'STILL_GREEN[^가-힣]{0,6}(만|인 것만)', a)) else 0}")

# --- I1-C: kept=0 차등 기원 라우팅 — 조건 언급부터 실제 호출 동사(「그대로 부르되」)
#     까지를 한 구간으로 자른다. 그 구간 안의 Final Summary 언급은 정확히 «부정문
#     하나» 여야 한다 — 부정문을 지우고도 Final Summary 가 남으면 실제 목적지가
#     바뀐 것이다(단어만 살려 둔 I1-C 변이).
r = seg(r'`verdict: defect` 이고 kept = 0.*?그대로 부르되')
print(f"ROUTE_FOUND:{1 if r is not None else 0}")
print(f"ROUTE_HAS_DIFFERENTIAL:{1 if (r and '차등' in r) else 0}")
print(f"ROUTE_HAS_DEFECT_FLAG:{1 if (r and 'confirmed_product_defect: true' in r) else 0}")
print(f"ROUTE_HAS_INVOKE:{1 if (r and '그대로 부르되' in r) else 0}")
route_no_leak = 0
if r is not None:
    stripped = r.replace('Final Summary 로 직행하지 않는다', '')
    route_no_leak = 1 if 'Final Summary' not in stripped else 0
print(f"ROUTE_NO_FINAL_SUMMARY_LEAK:{route_no_leak}")
PY
)
  assert_grep "$got" '^DISCLOSURE_FOUND:1$'    "resolution_disclosure 앵커를 찾았다"
  assert_grep "$got" '^DISCLOSURE_VERBATIM:1$' "그 줄 자신이 verbatim/그대로 지시를 담는다(I1-D 가 지우면 RED)"
  assert_grep "$got" '^ATTR_FOUND:1$'          "STILL_GREEN 앵커를 찾았다"
  assert_grep "$got" '^ATTR_NEGATED:1$'        "STILL_GREEN 바로 뒤에 「아닌」 부정이 있다(I1-E 가 「인 것만」으로 뒤집으면 RED)"
  assert_grep "$got" '^ATTR_EXAMPLE:1$'        "non-green 예시로 NEW_REGRESSION 이 같은 구간에 있다"
  assert_grep "$got" '^ATTR_FLIPPED_TO_ONLY_GREEN:0$' "「STILL_GREEN 만/인 것만」(선택 반전)이 없다"
  assert_grep "$got" '^ROUTE_FOUND:1$'                "kept=0 차등 기원 라우팅 구간을 찾았다"
  assert_grep "$got" '^ROUTE_HAS_DIFFERENTIAL:1$'     "그 구간이 차등 테스트 기원임을 말한다"
  assert_grep "$got" '^ROUTE_HAS_DEFECT_FLAG:1$'      "그 구간이 confirmed_product_defect: true 를 싣는다"
  assert_grep "$got" '^ROUTE_HAS_INVOKE:1$'           "그 구간이 Fix-loop decision 을 «그대로 부르되」로 실제 호출한다"
  assert_grep "$got" '^ROUTE_NO_FINAL_SUMMARY_LEAK:1$' "그 구간의 Final Summary 언급은 부정문 하나뿐이다(I1-C 가 실제 목적지를 바꾸면 RED)"
}

case_n5_and_retry_cover_differential_origin() {
  # 최종 리뷰 (2차) 항목 1–2 — N=5 상한(P18)과 Retry 옵션 문구가 kept=0 차등 기원
  # defect 를 커버하는지 잰다. 「N=5 확장을 지우는」 변이(옛 「kept > 0」 전용 문구로
  # 되돌리기)와 Retry 문장이 빠지는 변이를 각각 잡는다.
  local got
  got=$(python3 - "$SKILL" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()

def norm(s):
    return re.sub(r'\s+', ' ', s)

def seg(pattern):
    m = re.search(pattern, text, re.S)
    return norm(m.group(0)) if m else None

n5 = seg(r'\*\*N=5 에서 도달하면\.\*\*.*?(?=\n\n---)')
print(f"N5_FOUND:{1 if n5 is not None else 0}")
print(f"N5_HAS_DIFFERENTIAL:{1 if (n5 and '차등' in n5 and 'kept = 0' in n5) else 0}")
print(f"N5_HAS_MAXITER:{1 if (n5 and 'Max-iter decision' in n5) else 0}")

note = seg(r'\*\*Retry 옵션 문구.*?(?=\n\nBranch on answer:)')
print(f"RETRY_NOTE_FOUND:{1 if note is not None else 0}")
print(f"RETRY_NOTE_HAS_DIFFERENTIAL:{1 if (note and '차등 테스트 기원' in note) else 0}")

bullet = seg(r'- \*\*Retry\*\* →.*?(?=\n- \*\*Accept)')
print(f"RETRY_BULLET_FOUND:{1 if bullet is not None else 0}")
print(f"RETRY_BULLET_HAS_DIFFERENTIAL:{1 if (bullet and '차등 테스트 기원' in bullet) else 0}")
print(f"RETRY_BULLET_HAS_FIX_MEANING:{1 if (bullet and ('회귀' in bullet or 'NEW_REGRESSION' in bullet)) else 0}")
PY
)
  assert_grep "$got" '^N5_FOUND:1$'                    "「N=5 에서 도달하면」 문단을 찾았다"
  assert_grep "$got" '^N5_HAS_DIFFERENTIAL:1$'         "그 문단이 kept=0 차등 기원 defect 도 포함한다고 말한다(N=5 확장 삭제 변이 → RED)"
  assert_grep "$got" '^N5_HAS_MAXITER:1$'              "그 문단이 Max-iter decision 을 부른다고 말한다"
  assert_grep "$got" '^RETRY_NOTE_FOUND:1$'            "Retry 옵션 문구 안내를 찾았다"
  assert_grep "$got" '^RETRY_NOTE_HAS_DIFFERENTIAL:1$' "그 안내가 차등 테스트 기원 kept=0 을 지목한다"
  assert_grep "$got" '^RETRY_BULLET_FOUND:1$'          "Branch on answer 의 Retry 불릿을 찾았다"
  assert_grep "$got" '^RETRY_BULLET_HAS_DIFFERENTIAL:1$' "그 불릿이 차등 테스트 기원 경우를 갈라 말한다"
  assert_grep "$got" '^RETRY_BULLET_HAS_FIX_MEANING:1$'  "그 불릿이 회귀 unit 을 고치는 의미로 Retry 를 재정의한다(suggested patches 없음을 인정)"
}

case_zero_adapter_aggregate_skips_glob() {
  # 최종 리뷰 M3 — `$adapter_count == 0` 이면 R6 집계 호출이 `per-adapter-*.yaml` glob 을
  # 아예 안 쓴다(매치 없는 glob 이 쉘에 따라 명령을 통째로 죽이거나(zsh) 리터럴 파일명을
  # 넘겨 exit 4 를 내(bash) error-axis 로 오분류됐다 — 실제 사실은 no-adapters 다). then
  # 분기는 glob 없이 `--expected-adapters 0`, else 분기만 glob 을 쓴다.
  local got
  got=$(python3 - "$REF" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'if \[ "\$adapter_count" -eq 0 \]; then\n(.*?)\nelse\n(.*?)\nfi', text, re.S)
print(f"FOUND:{1 if m else 0}")
then_body, else_body = (m.group(1), m.group(2)) if m else ("", "")
print(f"THEN_HAS_AGG:{1 if ('diff-test-results.py' in then_body and '--aggregate' in then_body) else 0}")
print(f"THEN_NO_GLOB:{1 if 'per-adapter-*.yaml' not in then_body else 0}")
print(f"ELSE_HAS_GLOB:{1 if 'per-adapter-*.yaml' in else_body else 0}")
PY
)
  assert_grep "$got" '^FOUND:1$'         "adapter_count==0 분기(if/else/fi)를 찾았다"
  assert_grep "$got" '^THEN_HAS_AGG:1$'  "0 분기도 diff-test-results.py --aggregate 를 부른다(무응답이 아니다)"
  assert_grep "$got" '^THEN_NO_GLOB:1$'  "0 분기는 per-adapter-*.yaml glob 을 쓰지 않는다(매치 없는 glob 회피)"
  assert_grep "$got" '^ELSE_HAS_GLOB:1$' "1개 이상 분기는 여전히 glob 을 쓴다(정상 경로 안 밀림)"
}

for c in case_every_synth_call_emits_verdict_and_angles case_blocking_angle_dispatches_are_fail_closed \
         case_reason_literals_are_closed_and_pinned case_angle_template_is_total \
         case_differential_runs_inside_every_iteration \
         case_security_switch_is_not_certified_even_with_zero_findings \
         case_different_premise_absent_is_disclosed_not_blocked case_caller_reasons_reach_the_verdict \
         case_degraded_ledger_row_reaches_silent_drop case_pre_r6_abort_reaches_error_axis_catchall \
         case_pre_r6_abort_catchall_mirrored_in_reference case_r3_stop_choice_routes_to_error_axis \
         case_security_kill_switch_routes_to_absent case_differential_kill_switch_env_name_is_pinned \
         case_differential_defect_zero_kept_routes_to_fixloop case_zero_adapter_aggregate_skips_glob \
         case_n5_and_retry_cover_differential_origin; do
  "$c"
done
finish
