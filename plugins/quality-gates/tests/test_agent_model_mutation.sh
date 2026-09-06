#!/usr/bin/env bash
# 변이 락 — 반전된 모델 락(스윕 1 + per-agent 14)이 실제로 문다.
#
# 통과가 정답인 부재 단언은 모양만으로 이빨을 판별할 수 없다. 여기서 agent 파일에
# model 키를 다섯 표기로 넣고 해당 락이 RED 가 되는지, 되돌리면 GREEN 인지 잰다.
# 다섯 표기 (spec C2): (a) `model: inherit` (b) `model: opus` (c) `model:inherit`
# (d) `"model": inherit` (e) `model : inherit`. (f) 스윕 하한은 glob 을 빈 dir 로 돌려 잰다.
#
# 실제 파일을 건드리므로 clean tree 를 요구하고 trap 으로 복원한다. 변이 중 실패해도
# `git checkout -- <file>` 이 되돌린다 — 그래서 이 락은 «커밋된» 파일만 변이한다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

SWEEP="plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh"

# agent → 그 agent 를 보는 per-agent 락 (spec §설계 2 표)
pairs=(
  "plugins/quality-gates/agents/adversarial.md|plugins/quality-gates/tests/test_adversarial_persona.sh"
  "plugins/quality-gates/agents/adversarial.md|plugins/quality-gates/tests/test_adversarial_model_consistency.sh"
  "plugins/quality-gates/agents/security-reviewer.md|plugins/quality-gates/tests/test_security_reviewer_persona.sh"
  "plugins/quality-gates/agents/artifact-critic.md|plugins/quality-gates/tests/test_artifact_critic_frontmatter.sh"
  "plugins/quality-gates/agents/artifact-adversarial.md|plugins/quality-gates/tests/test_artifact_adversarial_frontmatter.sh"
  "plugins/quality-gates/agents/test-scope-validator.md|plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh"
  "plugins/quality-gates/agents/pr-understanding-builder.md|plugins/quality-gates/tests/test_pr_understanding_builder_frontmatter.sh"
  "plugins/quality-gates/agents/runtime-verifier.md|plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh"
  "plugins/spec-distill/agents/blind-spot-prober.md|plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh"
  "plugins/spec-distill/agents/coverage-mapper.md|plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh"
  "plugins/spec-distill/agents/spec-reviewer.md|plugins/spec-distill/tests/test_spec_reviewer_frontmatter.sh"
  "plugins/spec-distill/agents/steelman-builder.md|plugins/spec-distill/tests/test_steelman_builder_scope.sh"
  "plugins/spec-distill/agents/brief-critic.md|plugins/spec-distill/tests/test_brief_agents.sh"
  "plugins/spec-distill/agents/seed-critic.md|plugins/spec-distill/tests/test_seed_agents.sh"
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

# (f) 스윕 하한 — glob 이 비면 RED
EMPTY="$(mktemp -d)" || { no "mktemp 실패"; finish; exit; }
mkdir -p "$EMPTY/plugins/x/agents" "$EMPTY/shared/tests"
cp shared/tests/assert.sh "$EMPTY/shared/tests/"
mkdir -p "$EMPTY/plugins/quality-gates/tests"; cp "$SWEEP" "$EMPTY/plugins/quality-gates/tests/"
( cd "$EMPTY" && bash plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh >/dev/null ) \
  && no "스윕 하한: agent 0개인데 GREEN (vacuous pass)" || ok "스윕 하한: agent 0개 → RED"
rm -rf "$EMPTY"
finish
