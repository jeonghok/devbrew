#!/usr/bin/env bash
# 변이 락 — 모델 락(스윕 1 + 아래 pairs 의 per-agent 락)이 실제로 문다.
#
# 두 방향이 있다. 대부분의 agent 는 model 키 «부재»가 정답이고(통과가 정답인 부재 단언은
# 모양만으로 이빨을 판별할 수 없다), qg 소유 리뷰 agent 둘(security-reviewer · code-recritic)은
# 정확히 `model: opus` 한 줄이 정답이다(qg v10 재결정 R3).
#   (1) 스윕: model 키를 다섯 표기로 PINNED 밖 agent 에 넣으면 RED — (a) `model: inherit`
#       (b) `model: opus` (c) `model:inherit` (d) `"model": inherit` (e) `model : inherit`.
#   (2) per-agent 락: (a)·(d) 를 넣으면 RED — 부재 agent 는 키가 생겨서, PINNED 는 키가 둘이 돼서.
#   (g) PINNED 의 opus 줄을 지우거나 `model: sonnet` 으로 바꾸면 스윕과 per-agent 락이 RED.
#   (f) 스윕 하한 — glob 을 빈 dir 로 돌리면 RED.
# 각 per-agent 락은 변이 전 GREEN 이어야 한다(양성 대조) — 아니면 변이 RED 는 증거가 아니다.
#
# 실제 파일을 건드리므로 clean tree 를 요구하고 trap 으로 복원한다. 변이 중 실패해도
# `git checkout -- <file>` 이 되돌린다 — 그래서 이 락은 «커밋된» 파일만 변이한다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

SWEEP="plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh"

# agent → 그 agent 를 보는 per-agent 락. 카운트는 하드코딩된 기대값이 없다(pairs[@] 순회).
# doc-recritic 사본은 공유 정본과의 copy-of 동일성(`shared/tests/test_copy_of_contract.sh`)이
# 대신 잰다 — ② 가 그 사본을 지우면 그 줄도 사라진다.
pairs=(
  "plugins/quality-gates/agents/security-reviewer.md|plugins/quality-gates/tests/test_security_reviewer_persona.sh"
  "plugins/quality-gates/agents/code-recritic.md|plugins/quality-gates/tests/test_code_recritic_frontmatter.sh"
  "plugins/quality-gates/agents/artifact-critic.md|plugins/quality-gates/tests/test_artifact_critic_frontmatter.sh"
  "plugins/quality-gates/agents/artifact-adversarial.md|plugins/quality-gates/tests/test_artifact_adversarial_frontmatter.sh"
  "plugins/quality-gates/agents/test-scope-validator.md|plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh"
  "plugins/quality-gates/agents/pr-understanding-builder.md|plugins/quality-gates/tests/test_pr_understanding_builder_frontmatter.sh"
  "plugins/spec-distill/agents/blind-spot-prober.md|plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh"
  "plugins/spec-distill/agents/coverage-mapper.md|plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh"
  "plugins/spec-distill/agents/steelman-builder.md|plugins/spec-distill/tests/test_steelman_builder_scope.sh"
  "plugins/spec-distill/agents/doc-critic.md|plugins/spec-distill/tests/test_brief_agents.sh"
  "plugins/spec-distill/agents/doc-critic-web.md|plugins/spec-distill/tests/test_brief_agents.sh"
)
variants=("model: inherit" "model: opus" "model:inherit" "\"model\": inherit" "model : inherit")

if [ -n "$(git status --porcelain -- plugins/*/agents/)" ]; then
  no "0 — agents/ 에 미커밋 변경이 있다. 변이 락은 clean tree 에서만 돈다 (복원이 HEAD 로 간다)"
  finish; exit
fi
ok "0 — agents/ clean"

touched=()
restore() { for f in "${touched[@]:-}"; do [ -n "$f" ] && git checkout -q -- "$f"; done; }
trap restore EXIT

inject() {  # inject <file> <line>  — name: 줄 바로 뒤에 넣는다
  awk -v L="$2" 'BEGIN{d=0} {print} !d && /^name:/{print L; d=1}' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
  touched+=("$1")
}

# 양성 대조 — 변이 전 전부 GREEN 이어야 변이 RED 가 의미를 갖는다
bash "$SWEEP" >/dev/null && ok "양성 — 스윕 GREEN (변이 전)" || no "양성 — 스윕이 변이 전에 이미 RED"

for v in "${variants[@]}"; do
  # (1) 스윕: agent 하나에 넣으면 RED
  f="plugins/plugin-audit/agents/smoke-probe.md"
  inject "$f" "$v"
  bash "$SWEEP" >/dev/null && no "스윕: «${v}» 를 넣어도 GREEN — 이빨 없음" || ok "스윕: «${v}» → RED"
  git checkout -q -- "$f"
done

# (2) per-agent 락: (a)·(d) 두 표기로 각 락이 RED
for p in "${pairs[@]}"; do
  agent="${p%%|*}"; lock="${p##*|}"
  bash "$lock" >/dev/null && ok "양성 — ${lock##*/} GREEN (변이 전)" || no "양성 — ${lock##*/} 변이 전 RED"
  for v in "model: inherit" "\"model\": inherit"; do
    inject "$agent" "$v"
    bash "$lock" >/dev/null && no "${lock##*/}: «${v}» 를 넣어도 GREEN" || ok "${lock##*/}: «${v}» → RED"
    git checkout -q -- "$agent"
  done
done

# (g) PINNED 의 opus 줄을 지우거나 바꾸면 스윕과 per-agent 락이 RED 다(재결정 R3)
for p in "plugins/quality-gates/agents/security-reviewer.md|plugins/quality-gates/tests/test_security_reviewer_persona.sh" \
         "plugins/quality-gates/agents/code-recritic.md|plugins/quality-gates/tests/test_code_recritic_frontmatter.sh"; do
  agent="${p%%|*}"; lock="${p##*|}"
  for to in "" "model: sonnet"; do
    awk -v T="$to" '/^model: opus$/ && !d {d=1; if (T != "") print T; next} {print}' "$agent" > "$agent.tmp" && mv "$agent.tmp" "$agent"
    touched+=("$agent")
    bash "$SWEEP" >/dev/null && no "스윕: ${agent##*/} 의 opus 를 «${to:-삭제}» 해도 GREEN" || ok "스윕: ${agent##*/} opus → «${to:-삭제}» → RED"
    bash "$lock" >/dev/null && no "${lock##*/}: opus 를 «${to:-삭제}» 해도 GREEN" || ok "${lock##*/}: opus → «${to:-삭제}» → RED"
    git checkout -q -- "$agent"
  done
done

# (f) 스윕 하한 — glob 이 비면 RED
EMPTY="$(mktemp -d)" || { no "mktemp 실패"; finish; exit; }
mkdir -p "$EMPTY/plugins/x/agents" "$EMPTY/shared/tests"
cp shared/tests/assert.sh "$EMPTY/shared/tests/"
mkdir -p "$EMPTY/plugins/quality-gates/tests"; cp "$SWEEP" "$EMPTY/plugins/quality-gates/tests/"
( cd "$EMPTY" && bash plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh >/dev/null ) \
  && no "스윕 하한: agent 0개인데 GREEN (vacuous pass)" || ok "스윕 하한: agent 0개 → RED"
rm -rf "$EMPTY"
finish
