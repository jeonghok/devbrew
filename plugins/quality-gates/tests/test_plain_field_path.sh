#!/usr/bin/env bash
# guards: plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/synthesize_artifact_findings.py shared/codex/codex_findings_to_yaml.py plugins/quality-gates/agents/security-reviewer.md plugins/quality-gates/agents/code-recritic.md plugins/quality-gates/agents/artifact-critic.md plugins/quality-gates/agents/artifact-adversarial.md plugins/quality-gates/scripts/build_codex_prompt.py plugins/quality-gates/scripts/build_artifact_codex_prompt.py plugins/quality-gates/references/recritic-code-profile.md plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/tests/lib/recritic_fixture.sh plugins/quality-gates/scripts/extract_codex_artifact_yaml.py
#
# 쉬운 말 출력 설계 §5 · AC9 · D2.8 — 생산자마다 리뷰어 출력 하나가 변환·합성을 지나 화면까지 가고, 거기서 plain 이
# 먼저 나온다. plain 이 없는 지적은 버려지지 않고 지금처럼 나온다. 재비판자에게는 plain 을 넘기지 않는다(프레이밍 차단).
set -u
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  sed -n '2s/^# guards: //p' "$0" | tr ' ' '\n'
  exit 0
fi
. "$REPO_ROOT/shared/tests/assert.sh"
. "$PLUGIN_ROOT/tests/lib/recritic_fixture.sh"
export PYTHONDONTWRITEBYTECODE=1
SYNTH="$PLUGIN_ROOT/scripts/synthesize_findings.py"
ART="$PLUGIN_ROOT/scripts/synthesize_artifact_findings.py"
CONV="$REPO_ROOT/shared/codex/codex_findings_to_yaml.py"
S="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
A="$PLUGIN_ROOT/agents"
T="$(mktemp -d)" || exit 1
trap 'rm -rf "$T"' EXIT
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }

# ① 형식 — 생산자마다 plain 칸이 형식에 있다. 「explain」 같은 낱말이 우연히 맞지 않게 칸 모양으로 잰다.
assert_file_grep "$A/security-reviewer.md" '^  plain: <optional — the same finding in one plain sentence' "AC9 형식: security-reviewer 의 finding 형식에 plain 칸"
assert_file_grep "$A/artifact-critic.md" '^    plain: "optional — the same finding in one plain sentence' "AC9 형식: artifact-critic 의 finding 형식에 plain 칸"
assert_file_grep "$A/artifact-adversarial.md" '^    plain: "optional — one plain sentence' "AC9 형식: artifact-adversarial 의 new_findings 형식에 plain 칸"
assert_file_grep "$PLUGIN_ROOT/scripts/build_codex_prompt.py" '^      "plain": "<optional: the same finding in one plain sentence' "AC9 형식: codex 코드 리뷰 프롬프트에 plain 칸"
assert_file_grep "$PLUGIN_ROOT/scripts/build_artifact_codex_prompt.py" '^    plain: "optional — the same finding in one plain sentence' "AC9 형식: codex 비코드 리뷰 프롬프트에 plain 칸"
assert_contains "$(flat "$PLUGIN_ROOT/references/recritic-code-profile.md")" '`plain`(선택)에는 같은 지적을 처음 보는 사람이 읽을 쉬운 한 문장으로 — 내부 번호 없이 — 쓴다' "AC9 형식(D2.8): 재비판 프로필의 added 형식에 plain"
assert_contains "$(flat "$A/code-recritic.md")" '`plain`(선택)에는 같은 지적을 처음 보는 사람이 읽을 쉬운 한 문장을 — 내부 번호 없이 — 쓴다' "AC9 형식(D2.8): code-recritic 의 added 문장에 plain"
assert_file_grep "$A/code-recritic.md" '^    plain: "선택 — 처음 보는 사람이 읽을 쉬운 한 문장"$' "AC9 형식(D2.8): code-recritic 의 출력 예시에 plain"
assert_contains "$(flat "$S")" 'summary, plain (optional — the same finding in one plain sentence a first-time reader understands, no internal IDs), proposed_fix.' "AC9 형식(D2.8 · R3): 외부 리뷰어 dispatch 프롬프트가 plain 을 묻는다"
assert_contains "$(flat "$S")" '**각 항목의 `plain:` 은 리뷰어가 쓴 문장 그대로 싣는다** — 없으면 키를 뺀다(지어내지 않는다).' "R4: 오케스트레이터가 findings.yaml 에 plain 을 옮기고 지어내지 않는다"
# 생성된 codex 프롬프트에 칸이 실제로 실린다(파일 문면이 아니라 빌더 출력)
assert_contains "$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import build_codex_prompt as b; print(b.PROMPT_TEMPLATE)' "$PLUGIN_ROOT/scripts" 2>/dev/null)" '"plain":' "AC9 형식: codex 코드 리뷰 빌더의 PROMPT_TEMPLATE 이 plain 을 싣는다"
# 형식 칸만 더했다 — 리뷰어 도구 목록은 그대로다(Law 2)
assert_file_grep "$A/security-reviewer.md" '^tools: Read, Grep, Glob$' "Law 2: security-reviewer 의 tools 는 그대로다"
assert_file_grep "$A/code-recritic.md" '^tools: Read, Grep, Glob$' "Law 2: code-recritic 의 tools 는 그대로다"

# ② 보안 리뷰어 · 외부 리뷰어 경로 — 오케스트레이터가 쓴 findings.yaml → 재비판 → 합성기 표
mkdir -p "$T/sec"
printf -- '- {agent: security-reviewer, file: app.py, line: 3, severity: CRITICAL, summary: "SQL 문자열 결합", plain: "입력값이 그대로 데이터베이스 명령에 들어간다", proposed_fix: "바인딩"}\n- {agent: code-reviewer, file: lib.py, line: 7, severity: IMPORTANT, summary: "예외를 삼킨다", proposed_fix: "다시 던진다"}\n- {agent: code-reviewer, file: k.py, line: 9, severity: IMPORTANT, summary: "빈 칸", plain: "   ", proposed_fix: p}\n' > "$T/sec/findings.yaml"
rf_prep "$T/sec"; rf_reply "$T/sec" 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}
  - {f: f3, verdict: confirm}'
out="$(rf_synth "$T/sec")"
assert_grep "$out" '\| 입력값이 그대로 데이터베이스 명령에 들어간다 \(SQL 문자열 결합\) \|' "AC9: plain 이 먼저, 원래 요약은 뒤 괄호"
assert_grep "$out" '\| 예외를 삼킨다 \| code-reviewer \|$' "AC9(Review Focus 1): plain 없는 지적도 지금처럼 나온다"
assert_grep "$out" '\| 빈 칸 \| code-reviewer \|$' "공백뿐인 plain 은 없는 것으로 친다"
assert_grep "$out" '^\*\*Findings:\*\* 1 CRITICAL / 2 IMPORTANT / 0 SUGGESTION$' "AC9: 세 지적 모두 셌다(버린 것 없음)"
# 재비판자에게는 plain 을 넘기지 않는다 — 누가 어떻게 풀어 썼는지가 판단을 끌고 간다
assert_not_contains "$(cat "$T/sec/rf.yaml")" "plain" "프레이밍 차단: 익명 목록에 plain 이 없다"
assert_not_contains "$(cat "$T/sec/rf.yaml")" "입력값이 그대로 데이터베이스 명령에 들어간다" "프레이밍 차단: 익명 목록에 plain 문장 자체가 어느 키로도 실리지 않는다"
assert_contains "$(cat "$T/sec/rf.yaml")" "SQL 문자열 결합" "익명 목록에 요약은 있다(양성 짝)"

# ③ codex 코드 리뷰 경로 — codex JSONL → codex_findings_to_yaml(default) → 합성기
python3 - "$T/codex.jsonl" <<'PY'
import json, sys
text = "```json\n" + json.dumps({"findings": [{"file": "x.py", "line": 2, "severity": "IMPORTANT",
        "summary": "경계 검사 누락", "plain": "길이를 확인하지 않아 범위를 넘어 읽는다", "proposed_fix": "검사 추가"}]}, ensure_ascii=False) + "\n```"
open(sys.argv[1], "w", encoding="utf-8").write(json.dumps({"type": "item.completed", "item": {"type": "agent_message", "text": text}}, ensure_ascii=False) + "\n")
PY
python3 "$CONV" < "$T/codex.jsonl" > "$T/codex.yaml"
assert_file_grep "$T/codex.yaml" '^ *plain: ' "AC9: codex 변환이 plain 을 넘긴다"
mkdir -p "$T/cx"
python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1],encoding="utf-8")); fs=d["findings"]; [f.__setitem__("agent","codex-reviewer") for f in fs]; open(sys.argv[2],"w",encoding="utf-8").write(yaml.safe_dump(fs,allow_unicode=True))' "$T/codex.yaml" "$T/cx/findings.yaml"
rf_prep "$T/cx"; rf_reply "$T/cx" 'verdicts:
  - {f: f1, verdict: confirm}'
out="$(rf_synth "$T/cx")"
assert_grep "$out" '\| 길이를 확인하지 않아 범위를 넘어 읽는다 \(경계 검사 누락\) \|' "AC9: codex 지적의 plain 이 화면에 먼저 나온다"
# 쓸 수 없는 plain(목록 · 객체 · 숫자)은 변환기가 칸째 뺀다 — str() 로 옮기면 「['x', 'y']」 같은 글자가 화면에 나간다(합친 qg #5)
python3 - "$T/codex-bad.jsonl" <<'PY'
import json, sys
fs = [{"file": "y.py", "line": 1, "severity": "IMPORTANT", "summary": "목록칸", "plain": ["x", "y"], "proposed_fix": "f"},
      {"file": "y.py", "line": 2, "severity": "IMPORTANT", "summary": "객체칸", "plain": {}, "proposed_fix": "f"},
      {"file": "y.py", "line": 3, "severity": "IMPORTANT", "summary": "숫자칸", "plain": 5, "proposed_fix": "f"},
      {"file": "y.py", "line": 4, "severity": "IMPORTANT", "summary": "문장칸", "plain": "쓸 수 있는 문장", "proposed_fix": "f"}]
text = "```json\n" + json.dumps({"findings": fs}, ensure_ascii=False) + "\n```"
open(sys.argv[1], "w", encoding="utf-8").write(json.dumps({"type": "item.completed", "item": {"type": "agent_message", "text": text}}, ensure_ascii=False) + "\n")
PY
python3 "$CONV" < "$T/codex-bad.jsonl" > "$T/codex-bad.yaml"
assert_eq "$(grep -c '^ *plain: ' "$T/codex-bad.yaml")" "1" "#5: 변환기는 문자열 plain 만 넘기고 목록 · 객체 · 숫자는 칸째 뺀다"
assert_eq "$(python3 -c 'import sys,yaml; print(len(yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["findings"]))' "$T/codex-bad.yaml")" "4" "#5(양의 짝): 지적 넷은 모두 남는다"
mkdir -p "$T/cxb"
python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1],encoding="utf-8")); fs=d["findings"]; [f.__setitem__("agent","codex-reviewer") for f in fs]; open(sys.argv[2],"w",encoding="utf-8").write(yaml.safe_dump(fs,allow_unicode=True))' "$T/codex-bad.yaml" "$T/cxb/findings.yaml"
rf_prep "$T/cxb"; rf_reply "$T/cxb" 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}
  - {f: f3, verdict: confirm}
  - {f: f4, verdict: confirm}'
out="$(rf_synth "$T/cxb")"
assert_not_contains "$out" "['x', 'y']" "#5: 목록 plain 의 파이썬 표기가 화면에 없다"
assert_grep "$out" '\| 목록칸 \| codex-reviewer \|$' "#5: 목록 plain 지적은 요약만 나온다"
assert_grep "$out" '\| 객체칸 \| codex-reviewer \|$' "#5: 객체 plain 지적은 요약만 나온다"
assert_grep "$out" '\| 숫자칸 \| codex-reviewer \|$' "#5: 숫자 plain 지적은 요약만 나온다(Review Focus)"
assert_grep "$out" '\| 쓸 수 있는 문장 \(문장칸\) \| codex-reviewer \|$' "#5(양의 짝): 문자열 plain 은 그대로 먼저 나온다"

# ④ 재비판자가 더한 지적(added) — qg-recritic 블록 → 합성기
mkdir -p "$T/add"; printf '[]\n' > "$T/add/findings.yaml"; rf_prep "$T/add"
rf_reply "$T/add" 'verdicts: []
added:
  - file: lib.py
    line: 4
    severity: CRITICAL
    summary: "놓친 경로 탐색"
    plain: "사용자가 준 경로로 다른 폴더의 파일을 읽을 수 있다"
    proposed_fix: "정규화 후 비교"'
out="$(rf_synth "$T/add")"
assert_grep "$out" '\| 사용자가 준 경로로 다른 폴더의 파일을 읽을 수 있다 \(놓친 경로 탐색\) \| code-recritic \|' "AC9(D2.8): 재비판 added 의 plain 이 화면에 먼저 나온다"

# ⑤ 비코드 산출물 경로 — key → synth 의 kept 에 plain 이 남는다(R7)
printf 'findings:\n  - {agent: artifact-critic, category: logic, target_anchor: "#s1", severity: CRITICAL, summary: "gap A", plain: "이 절은 앞 절과 반대로 말한다", proposed_fix: "fix A"}\n' > "$T/critic.yaml"
python3 "$ART" --phase key --findings "$T/critic.yaml" > "$T/merged.yaml" 2>/dev/null
assert_file_grep "$T/merged.yaml" '^ *plain: ' "AC9: artifact key 단계가 plain 을 넘긴다"
K="$(python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["findings"][0]["dedup_key"])' "$T/merged.yaml")"
printf 'verdicts:\n  - {finding_key: "%s", verdict: confirm, evidence: real}\n' "$K" > "$T/adv.yaml"
out="$(python3 "$ART" --phase synth --findings "$T/merged.yaml" --adversarial "$T/adv.yaml" 2>/dev/null)"
assert_contains "$out" "이 절은 앞 절과 반대로 말한다" "AC9: artifact synth 의 kept 에 plain 이 남는다"
# ⑤c 비코드 codex 경로 — codex JSONL → extract_codex_artifact_yaml → key → synth. 중간 변환을 실제로 지난다(AC9 · 합친 qg #4)
python3 - "$T/acx.jsonl" <<'PY'
import json, sys
text = "```yaml\nfindings:\n  - {category: logic, target_anchor: \"#x\", severity: IMPORTANT, summary: \"x 절이 비었다\", plain: \"이 절에는 내용이 없다\", proposed_fix: \"채운다\"}\n```"
open(sys.argv[1], "w", encoding="utf-8").write(json.dumps({"type": "item.completed", "item": {"type": "agent_message", "text": text}}, ensure_ascii=False) + "\n")
PY
python3 "$PLUGIN_ROOT/scripts/extract_codex_artifact_yaml.py" < "$T/acx.jsonl" > "$T/acx.yaml"
assert_file_grep "$T/acx.yaml" '^ *plain: ' "#4: 비코드 codex 추출기가 plain 을 넘긴다"
python3 "$ART" --phase key --findings "$T/acx.yaml" > "$T/acx-merged.yaml" 2>/dev/null
K="$(python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["findings"][0]["dedup_key"])' "$T/acx-merged.yaml")"
printf 'verdicts:\n  - {finding_key: "%s", verdict: confirm, evidence: real}\n' "$K" > "$T/acx-adv.yaml"
out="$(python3 "$ART" --phase synth --findings "$T/acx-merged.yaml" --adversarial "$T/acx-adv.yaml" 2>/dev/null)"
assert_contains "$out" "이 절에는 내용이 없다" "#4: 비코드 codex 의 plain 이 추출 · key · synth 를 지나 kept 에 남는다"
assert_contains "$out" "x 절이 비었다" "#4(양의 짝): 그 지적의 요약도 kept 에 있다"
# 쓸 수 없는 plain(공백뿐 · 문자열 아님)은 kept 로 나가지 않고, 지적은 남는다
printf 'findings:\n  - {agent: artifact-critic, category: logic, target_anchor: "#s3", severity: CRITICAL, summary: "gap C", plain: 42, proposed_fix: "fix C"}\n  - {agent: artifact-critic, category: logic, target_anchor: "#s4", severity: CRITICAL, summary: "gap D", plain: "   ", proposed_fix: "fix D"}\n' > "$T/bad.yaml"
python3 "$ART" --phase key --findings "$T/bad.yaml" > "$T/badm.yaml" 2>/dev/null
assert_eq "$(python3 -c 'import sys,yaml; fs=yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["findings"]; print(len(fs), sum(1 for f in fs if "plain" in f))' "$T/badm.yaml")" "2 0" "AC9: key 단계가 쓸 수 없는 plain 만 빼고 지적 둘은 남긴다"
python3 - "$T/badm.yaml" "$T/bad2.yaml" <<'PY'
import sys, yaml
m = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
for f in m["findings"]:
    f["plain"] = 42 if f["summary"] == "gap C" else "   "
open(sys.argv[2], "w", encoding="utf-8").write(yaml.safe_dump(m, allow_unicode=True))
PY
K1="$(python3 -c 'import sys,yaml; print([f["dedup_key"] for f in yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["findings"]][0])' "$T/badm.yaml")"
K2="$(python3 -c 'import sys,yaml; print([f["dedup_key"] for f in yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["findings"]][1])' "$T/badm.yaml")"
printf 'verdicts:\n  - {finding_key: "%s", verdict: confirm, evidence: real}\n  - {finding_key: "%s", verdict: confirm, evidence: real}\n' "$K1" "$K2" > "$T/adv2.yaml"
python3 "$ART" --phase synth --findings "$T/bad2.yaml" --adversarial "$T/adv2.yaml" > "$T/bado2.yaml" 2>/dev/null
assert_eq "$(python3 -c 'import sys,yaml; ks=yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["kept"]; print(len(ks), sum(1 for k in ks if "plain" in k))' "$T/bado2.yaml")" "2 0" "AC9: synth 의 kept 에 쓸 수 없는 plain(숫자 · 공백뿐)이 실리지 않고 지적 둘은 남는다"

# ⑤b 비코드 adversarial 의 new_findings 도 같은 규칙이다 — 쓸 수 없는 plain 은 빠지고, 같은 키에 흡수되면 plain 을 물려받는다
printf 'findings:\n  - {agent: artifact-critic, category: logic, target_anchor: "#a", severity: CRITICAL, summary: "gap NA", proposed_fix: "fix NA"}\n' > "$T/nf-c.yaml"
python3 "$ART" --phase key --findings "$T/nf-c.yaml" > "$T/nf-m.yaml" 2>/dev/null
KA="$(python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["findings"][0]["dedup_key"])' "$T/nf-m.yaml")"
printf 'verdicts:\n  - {finding_key: "%s", verdict: confirm, evidence: real}\nnew_findings:\n  - {category: logic, target_anchor: "#a", severity: CRITICAL, summary: "gap NA", plain: "흡수된 쪽이 쓴 쉬운 문장", proposed_fix: "x"}\n  - {category: logic, target_anchor: "#b", severity: CRITICAL, summary: "gap NB", plain: "   ", proposed_fix: "x"}\n  - {category: logic, target_anchor: "#c", severity: CRITICAL, summary: "gap NC", plain: 42, proposed_fix: "x"}\n  - {category: logic, target_anchor: "#d", severity: CRITICAL, summary: "gap ND", plain: "새 지적의 쉬운 문장", proposed_fix: "x"}\n' "$KA" > "$T/nf-adv.yaml"
python3 "$ART" --phase synth --findings "$T/nf-m.yaml" --adversarial "$T/nf-adv.yaml" > "$T/nf-out.yaml" 2>/dev/null
nfq() { python3 -c 'import sys,yaml; ks={k["target_anchor"]:k for k in yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["kept"]}; k=ks.get(sys.argv[2]); print("absent" if k is None else k.get("plain","none"))' "$T/nf-out.yaml" "$1"; }
assert_eq "$(nfq '#a')" "흡수된 쪽이 쓴 쉬운 문장" "I1: 같은 키로 흡수될 때 남는 쪽에 plain 이 없으면 흡수된 쪽 것을 물려받는다"
assert_eq "$(nfq '#b')" "none" "I1: new_findings 의 공백뿐인 plain 은 kept 에서 빠지고 지적은 남는다"
assert_eq "$(nfq '#c')" "none" "I1: new_findings 의 숫자 plain 은 kept 에서 빠지고 지적은 남는다"
assert_eq "$(nfq '#d')" "새 지적의 쉬운 문장" "I1(양의 짝): new_findings 의 쓸 수 있는 plain 은 kept 에 그대로 실린다"
printf 'findings:\n  - {agent: artifact-critic, category: logic, target_anchor: "#e", severity: CRITICAL, summary: "gap NE", plain: "남는 쪽의 문장", proposed_fix: "fix"}\n' > "$T/nf2-c.yaml"
python3 "$ART" --phase key --findings "$T/nf2-c.yaml" > "$T/nf2-m.yaml" 2>/dev/null
KE="$(python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["findings"][0]["dedup_key"])' "$T/nf2-m.yaml")"
printf 'verdicts:\n  - {finding_key: "%s", verdict: confirm, evidence: real}\nnew_findings:\n  - {category: logic, target_anchor: "#e", severity: CRITICAL, summary: "gap NE", plain: "흡수된 쪽의 다른 문장", proposed_fix: "x"}\n' "$KE" > "$T/nf2-adv.yaml"
python3 "$ART" --phase synth --findings "$T/nf2-m.yaml" --adversarial "$T/nf2-adv.yaml" > "$T/nf2-out.yaml" 2>/dev/null
assert_eq "$(python3 -c 'import sys,yaml; ks=yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["kept"]; print(len(ks), ks[0].get("plain"))' "$T/nf2-out.yaml")" "1 남는 쪽의 문장" "I1: 같은 키로 흡수돼도 남는 쪽에 이미 있는 plain 은 덮어쓰지 않는다"

# ⑥ 표 칸을 깨는 글자 (Review Focus 2)
mkdir -p "$T/esc"
printf -- '- agent: security-reviewer\n  file: a.py\n  line: 1\n  severity: IMPORTANT\n  summary: "s"\n  plain: "왼쪽 | 오른쪽\\n둘째 줄"\n  proposed_fix: "p"\n' > "$T/esc/findings.yaml"
rf_prep "$T/esc"; rf_reply "$T/esc" 'verdicts:
  - {f: f1, verdict: confirm}'
out="$(rf_synth "$T/esc")"
assert_eq "$(printf '%s\n' "$out" | grep -c '^| IMPORTANT |')" "1" "Review Focus 2: plain 의 | 와 개행이 표 행을 깨지 않는다"
assert_grep "$out" '왼쪽 \\\| 오른쪽 둘째 줄 \(s\)' "Review Focus 2: | 는 이스케이프되고 개행은 공백이 된다"

# ⑦ 합칠 때 칸이 사라지지 않는다 (Review Focus 5) — 코드 경로 · 비코드 경로
mkdir -p "$T/dup"
printf -- '- {agent: security-reviewer, file: d.py, line: 5, severity: IMPORTANT, summary: "같은 지적", proposed_fix: p}\n- {agent: code-reviewer, file: d.py, line: 5, severity: IMPORTANT, summary: "같은 지적", plain: "같은 줄을 두 리뷰어가 짚었다", proposed_fix: p}\n- {agent: silent-failure-hunter, file: d.py, line: 5, severity: IMPORTANT, summary: "같은 지적", plain: "셋째가 쓴 다른 문장", proposed_fix: p}\n' > "$T/dup/findings.yaml"
rf_prep "$T/dup"; rf_reply "$T/dup" 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}
  - {f: f3, verdict: confirm}'
out="$(rf_synth "$T/dup")"
assert_eq "$(printf '%s\n' "$out" | grep -c '^| IMPORTANT | d\.py:5 |')" "1" "Review Focus 5: 같은 지적 셋이 한 행으로 합쳐졌다"
assert_contains "$out" "같은 줄을 두 리뷰어가 짚었다 (같은 지적)" "Review Focus 5: 남는 쪽에 plain 이 없으면 합쳐진 다른 쪽 중 먼저 온 쪽의 plain 을 물려받는다"
assert_not_contains "$out" "셋째가 쓴 다른 문장" "Review Focus 5: 물려받는 것은 하나 — 먼저 온 쪽이다"
# 요약이 다른 지적은 같은 줄에 합쳐져도 plain 을 물려받지 않는다 — 다른 결함의 쉬운 문장이 엉뚱한 설명 옆에 붙는다(합친 qg #1)
mkdir -p "$T/dupx"
printf -- '- {agent: code-reviewer, file: e.py, line: 7, severity: IMPORTANT, summary: "반복 경계가 하나 넘친다", proposed_fix: "< 로 바꾼다"}\n- {agent: security-reviewer, file: e.py, line: 7, severity: IMPORTANT, summary: "경로 탐색", plain: "사용자가 준 경로로 폴더 밖 파일을 읽을 수 있다", proposed_fix: "경로를 정규화한다"}\n' > "$T/dupx/findings.yaml"
rf_prep "$T/dupx"; rf_reply "$T/dupx" 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}'
out="$(rf_synth "$T/dupx")"
assert_eq "$(printf '%s\n' "$out" | grep -c '^| IMPORTANT | e\.py:7 |')" "1" "#1 전제: 같은 좌표의 두 지적이 한 행으로 합쳐졌다"
assert_not_contains "$out" "사용자가 준 경로로 폴더 밖 파일을 읽을 수 있다" "#1: 요약이 다른 지적의 plain 을 물려받지 않는다"
assert_grep "$out" '^\| IMPORTANT \| e\.py:7 \| 반복 경계가 하나 넘친다 \|' "#1(양의 짝): 남는 쪽은 자기 요약만 낸다"
# 요약이 공백 · 대소문자만 다르면 같은 지적이다 — plain 을 물려받는다(Review Focus)
mkdir -p "$T/dupw"
printf -- '- {agent: code-reviewer, file: f.py, line: 3, severity: IMPORTANT, summary: "Missing  Check", proposed_fix: p}\n- {agent: security-reviewer, file: f.py, line: 3, severity: IMPORTANT, summary: " missing check ", plain: "입력 검사가 빠졌다", proposed_fix: p}\n' > "$T/dupw/findings.yaml"
rf_prep "$T/dupw"; rf_reply "$T/dupw" 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}'
out="$(rf_synth "$T/dupw")"
assert_contains "$out" "입력 검사가 빠졌다 (Missing  Check)" "#1: 요약이 공백 · 대소문자만 다르면 같은 지적으로 보고 plain 을 물려받는다"
mkdir -p "$T/dup3"
printf -- '- {agent: security-reviewer, file: g.py, line: 8, severity: IMPORTANT, summary: "같은 지적", plain: "   ", proposed_fix: p}\n- {agent: code-reviewer, file: g.py, line: 8, severity: IMPORTANT, summary: "같은 지적", plain: "공백 뒤에 온 문장", proposed_fix: p}\n' > "$T/dup3/findings.yaml"
rf_prep "$T/dup3"; rf_reply "$T/dup3" 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}'
out="$(rf_synth "$T/dup3")"
assert_contains "$out" "공백 뒤에 온 문장 (같은 지적)" "Review Focus 5: 남는 쪽 plain 이 공백뿐이면 없는 것으로 치고 물려받는다"
mkdir -p "$T/dup2"
printf -- '- {agent: security-reviewer, file: e.py, line: 6, severity: IMPORTANT, summary: "같은 지적", plain: "먼저 온 쪽의 문장", proposed_fix: p}\n- {agent: code-reviewer, file: e.py, line: 6, severity: IMPORTANT, summary: "같은 지적", plain: "나중 쪽의 문장", proposed_fix: p}\n' > "$T/dup2/findings.yaml"
rf_prep "$T/dup2"; rf_reply "$T/dup2" 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}'
out="$(rf_synth "$T/dup2")"
assert_contains "$out" "먼저 온 쪽의 문장 (같은 지적)" "Review Focus 5: 남는 쪽에 plain 이 있으면 그대로다"
assert_not_contains "$out" "나중 쪽의 문장" "Review Focus 5: 남는 쪽의 plain 을 덮어쓰지 않는다"
printf 'findings:\n  - {agent: artifact-critic, category: logic, target_anchor: "#s2", severity: IMPORTANT, summary: "gap B", proposed_fix: "fix B"}\n' > "$T/c1.yaml"
printf 'findings:\n  - {agent: codex, category: logic, target_anchor: "#s2", severity: IMPORTANT, summary: "gap B", plain: "둘째 절이 빠졌다", proposed_fix: "fix B"}\n' > "$T/c2.yaml"
python3 "$ART" --phase key --findings "$T/c1.yaml" --findings "$T/c2.yaml" > "$T/m2.yaml" 2>/dev/null
assert_eq "$(python3 -c 'import sys,yaml; fs=yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["findings"]; print(len(fs), fs[0].get("plain"))' "$T/m2.yaml")" "1 둘째 절이 빠졌다" "Review Focus 5: 비코드 합치기는 한 지적으로 합치고 다른 쪽의 plain 을 물려받는다"
printf 'findings:\n  - {agent: artifact-critic, category: logic, target_anchor: "#s5", severity: IMPORTANT, summary: "gap E", plain: "   ", proposed_fix: "fix E"}\n' > "$T/c3.yaml"
printf 'findings:\n  - {agent: codex, category: logic, target_anchor: "#s5", severity: IMPORTANT, summary: "gap E", plain: "다섯째 절이 모호하다", proposed_fix: "fix E"}\n' > "$T/c4.yaml"
python3 "$ART" --phase key --findings "$T/c3.yaml" --findings "$T/c4.yaml" > "$T/m3.yaml" 2>/dev/null
assert_eq "$(python3 -c 'import sys,yaml; fs=yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["findings"]; print(len(fs), fs[0].get("plain"))' "$T/m3.yaml")" "1 다섯째 절이 모호하다" "Review Focus 5: 먼저 온 쪽의 plain 이 공백뿐이면 없는 것으로 치고 다른 쪽 것을 물려받는다"
printf 'findings:\n  - {agent: artifact-critic, category: logic, target_anchor: "#s6", severity: IMPORTANT, summary: "gap F", plain: 42, proposed_fix: "fix F"}\n' > "$T/c5.yaml"
printf 'findings:\n  - {agent: codex, category: logic, target_anchor: "#s6", severity: IMPORTANT, summary: "gap F", plain: "여섯째 절이 비었다", proposed_fix: "fix F"}\n' > "$T/c6.yaml"
python3 "$ART" --phase key --findings "$T/c5.yaml" --findings "$T/c6.yaml" > "$T/m4.yaml" 2>/dev/null
assert_eq "$(python3 -c 'import sys,yaml; fs=yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["findings"]; print(len(fs), fs[0].get("plain"))' "$T/m4.yaml")" "1 여섯째 절이 비었다" "Review Focus 5: 먼저 온 쪽의 plain 이 문자열이 아니면 없는 것으로 치고 다른 쪽 것을 물려받는다"

# ⑧ 표 렌더의 plain 가지 — 문자열이 아니거나 비면 요약만 나온다(Task 2 의 렌더 분기를 잠근다)
mkdir -p "$T/ns"
printf -- '- {agent: code-reviewer, file: n.py, line: 1, severity: IMPORTANT, summary: "숫자칸", plain: 42, proposed_fix: p}\n- {agent: code-reviewer, file: n.py, line: 2, severity: IMPORTANT, summary: "빈문자칸", plain: "", proposed_fix: p}\n- {agent: code-reviewer, file: n.py, line: 3, severity: IMPORTANT, summary: "목록칸", plain: [a, b], proposed_fix: p}\n' > "$T/ns/findings.yaml"
rf_prep "$T/ns"; rf_reply "$T/ns" 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}
  - {f: f3, verdict: confirm}'
out="$(rf_synth "$T/ns")"
assert_grep "$out" '\| 숫자칸 \| code-reviewer \|$' "렌더: 문자열이 아닌 plain(숫자)은 요약만 나온다"
assert_grep "$out" '\| 빈문자칸 \| code-reviewer \|$' "렌더: 빈 plain 은 요약만 나온다"
assert_grep "$out" '\| 목록칸 \| code-reviewer \|$' "렌더: 문자열이 아닌 plain(목록)은 요약만 나온다"
assert_grep "$out" '^\*\*Findings:\*\* 0 CRITICAL / 3 IMPORTANT / 0 SUGGESTION$' "렌더: 형식이 이상한 plain 때문에 지적을 버리지 않는다"
finish
