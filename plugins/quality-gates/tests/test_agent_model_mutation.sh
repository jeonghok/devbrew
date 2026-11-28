#!/usr/bin/env bash
# 변이 락 — 모델 락(스윕 1 + 아래 pairs 의 per-agent 락)이 실제로 문다.
#
# 모든 agent 는 model 키 «부재»가 정답이다(통과가 정답인 부재 단언은 모양만으로 이빨을 판별할 수
# 없다). qg 리뷰 agent 둘(security-reviewer · code-recritic)도 마찬가지다 — 옛 재결정 R3 의
# `model: opus` 고정은 R2a 사용자 결정 「세션 모델을 따른다」로 풀렸다.
#   (1) 스윕: model 키를 다섯 표기로 agent 에 넣으면 RED — (a) `model: inherit`
#       (b) `model: opus` (c) `model:inherit` (d) `"model": inherit` (e) `model : inherit`.
#   (2) per-agent 락: (a)·(d) 를 넣으면 RED — 키가 생겨서.
#   (g) qg 리뷰 agent 에 `model: opus` 를 되살리면 스윕과 per-agent 락이 RED.
#   (f) 스윕 하한 — glob 을 빈 dir 로 돌리면 RED.
# 각 per-agent 락은 변이 전 GREEN 이어야 한다(양성 대조) — 아니면 변이 RED 는 증거가 아니다.
#
# 레포의 agents 를 고치지 않는다 — plugins/ · shared/ 를 링크째 임시 폴더에 떠서 git init · 커밋한
# 사본 레포에서 변이 · 복원한다. 락은 사본을 cwd 로 돈다(cwd 상대 경로 · `git rev-parse --show-toplevel`).
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

SWEEP="plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh"

# agent → 그 agent 를 보는 per-agent 락. 카운트는 하드코딩된 기대값이 없다(pairs[@] 순회).
pairs=(
  "plugins/quality-gates/agents/security-reviewer.md|plugins/quality-gates/tests/test_security_reviewer_persona.sh"
  "plugins/quality-gates/agents/code-recritic.md|plugins/quality-gates/tests/test_code_recritic_frontmatter.sh"
  "plugins/quality-gates/agents/artifact-critic.md|plugins/quality-gates/tests/test_artifact_critic_frontmatter.sh"
  "plugins/quality-gates/agents/artifact-adversarial.md|plugins/quality-gates/tests/test_artifact_adversarial_frontmatter.sh"
  "plugins/spec-distill/agents/blind-spot-prober.md|plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh"
  "plugins/spec-distill/agents/coverage-mapper.md|plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh"
  "plugins/spec-distill/agents/steelman-builder.md|plugins/spec-distill/tests/test_steelman_builder_scope.sh"
  "plugins/spec-distill/agents/doc-critic.md|plugins/spec-distill/tests/test_brief_agents.sh"
  "plugins/spec-distill/agents/doc-critic-web.md|plugins/spec-distill/tests/test_brief_agents.sh"
)
variants=("model: inherit" "model: opus" "model:inherit" "\"model\": inherit" "model : inherit")

unset $(git rev-parse --local-env-vars)
COPY="$(mktemp -d)" || COPY=""
if [ -z "$COPY" ] || [ ! -d "$COPY" ]; then no "0 — 사본 폴더를 만들지 못했다"; finish; exit; fi
trap 'rm -rf "$COPY"' EXIT
if cp -R plugins shared "$COPY/" \
   && git -C "$COPY" init -q && git -C "$COPY" config user.email t@t && git -C "$COPY" config user.name t \
   && git -C "$COPY" add -- plugins shared && git -C "$COPY" commit -qm copy \
   && cd "$COPY" \
   && [ "$(git rev-parse --show-toplevel)" = "$(cd "$COPY" && pwd -P)" ]; then
  ok "0 — 사본 레포 준비 (plugins/ · shared/ · 락의 레포 꼭대기 = 사본)"
else
  no "0 — 사본 레포를 뜨지 못했거나 레포 꼭대기가 사본이 아니다"; finish; exit
fi

inject() {  # inject <file> <line>  — name: 줄 바로 뒤에 넣는다
  awk -v L="$2" 'BEGIN{d=0} {print} !d && /^name:/{print L; d=1}' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}
revert() { git checkout -q HEAD -- "$1"; }  # 사본 레포의 커밋으로

# 양성 대조 — 변이 전 전부 GREEN 이어야 변이 RED 가 의미를 갖는다
bash "$SWEEP" >/dev/null && ok "양성 — 스윕 GREEN (변이 전)" || no "양성 — 스윕이 변이 전에 이미 RED"

for v in "${variants[@]}"; do
  # (1) 스윕: agent 하나에 넣으면 RED
  f="plugins/plugin-audit/agents/smoke-probe.md"
  inject "$f" "$v"
  bash "$SWEEP" >/dev/null && no "스윕: «${v}» 를 넣어도 GREEN — 이빨 없음" || ok "스윕: «${v}» → RED"
  revert "$f"
done

# (2) per-agent 락: (a)·(d) 두 표기로 각 락이 RED
for p in "${pairs[@]}"; do
  agent="${p%%|*}"; lock="${p##*|}"
  bash "$lock" >/dev/null && ok "양성 — ${lock##*/} GREEN (변이 전)" || no "양성 — ${lock##*/} 변이 전 RED"
  for v in "model: inherit" "\"model\": inherit"; do
    inject "$agent" "$v"
    bash "$lock" >/dev/null && no "${lock##*/}: «${v}» 를 넣어도 GREEN" || ok "${lock##*/}: «${v}» → RED"
    revert "$agent"
  done
done

# (g) qg 리뷰 agent 에 옛 고정 `model: opus` 를 되살리면 스윕과 per-agent 락이 RED 다(R2a 결정으로 풀린 R3)
for p in "plugins/quality-gates/agents/security-reviewer.md|plugins/quality-gates/tests/test_security_reviewer_persona.sh" \
         "plugins/quality-gates/agents/code-recritic.md|plugins/quality-gates/tests/test_code_recritic_frontmatter.sh"; do
  agent="${p%%|*}"; lock="${p##*|}"
  inject "$agent" "model: opus"
  bash "$SWEEP" >/dev/null && no "스윕: ${agent##*/} 에 opus 를 되살려도 GREEN" || ok "스윕: ${agent##*/} 에 opus 되살림 → RED"
  bash "$lock" >/dev/null && no "${lock##*/}: opus 를 되살려도 GREEN" || ok "${lock##*/}: opus 되살림 → RED"
  revert "$agent"
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
