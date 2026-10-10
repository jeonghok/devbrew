#!/usr/bin/env bash
# test_publish_surface_removed.sh — AC16: Files to Modify ③ 의 삭제 대상과 `/qg-publish` 표면이 없다.
#
# 세 축을 함께 잰다. (1) 삭제 대상 파일이 추적 트리에 없다. (2) 옛 게시 표면의 개념 별칭(명령 · skill · agent ·
# 스크립트 이름 · 옛 corpus 헤더)이 살아 있는 코퍼스 어디에도 없다. (3) 양의 짝 — 새 sink 가 실행 파일로 있고,
# render-terminal 은 `table` 하나만 남았고, qg 진입이 파이프라인 skill 을 부른다.
# 코퍼스에서 빼는 것과 이유: 각 플러그인 CHANGELOG(이력) · docs/archive · docs/superpowers(이력 문서) ·
# 이 파일 자신(토큰 목록).
# (qg v10 ③ plan 이 쓴 테스트 코드다 — 리뷰는 이 파일도 검사 대상으로 본다.)
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
QG="$ROOT/plugins/quality-gates"
SELF="plugins/quality-gates/tests/$(basename "$0")"
export PYTHONDONTWRITEBYTECODE=1

# ── (1) 삭제 대상 ───────────────────────────────────────────────────────────
TRACKED="$(git -C "$ROOT" ls-files -- plugins/quality-gates)"
[ -n "$TRACKED" ] && ok "추적 트리를 읽었다" || no "git ls-files 가 비었다 — 판정하지 않는다"
for p in commands/qg-publish.md skills/publishing-pr-understanding/SKILL.md agents/pr-understanding-builder.md \
         scripts/comment-upsert.py scripts/gh-identity.sh scripts/pr-create.sh scripts/pr-detect.sh \
         scripts/build-pr-context.sh scripts/diagram-facts.sh \
         tests/test_comment_upsert.py tests/test_gh_identity.sh tests/test_pr_create.sh tests/test_pr_detect.sh \
         tests/test_build_pr_context.sh tests/test_diagram_facts.sh tests/test_accuracy_warnings.py \
         tests/test_pr_understanding_builder_frontmatter.sh tests/test_qg_publish_command.sh \
         tests/test_qg_publish_docs.sh tests/test_qg_publish_handoff.sh tests/test_qg_publish_skill_orchestration.sh \
         tests/test_publish_degrade.sh tests/test_publish_dry_run_zero_network.sh tests/test_publish_kill_switch.py \
         tests/test_qg_pipeline_no_gh.sh; do
  if printf '%s\n' "$TRACKED" | grep -qxF "plugins/quality-gates/$p"; then no "AC16: 삭제 대상이 남았다 — $p"; else ok "AC16: 없음 — $p"; fi
done

# ── (2) 개념 별칭 스윕 ───────────────────────────────────────────────────────
SWEEP_FILES="$(git -C "$ROOT" -c core.quotePath=false ls-files -- plugins shared tools docs CLAUDE.md .claude-plugin \
  | grep -vE '^plugins/[^/]+/CHANGELOG\.md$|^docs/(archive|superpowers)/' | grep -vxF "$SELF")"
NSWEEP="$(printf '%s\n' "$SWEEP_FILES" | grep -c .)"
[ "$NSWEEP" -ge 500 ] && ok "AC16: 스윕 코퍼스 ${NSWEEP}개(하한 500)" || no "AC16: 스윕 코퍼스가 ${NSWEEP}개뿐이다(하한 500) — 비면 0건 판정이 공허하다"
HITS="$(printf '%s\n' "$SWEEP_FILES" | tr '\n' '\0' \
  | (cd "$ROOT" && xargs -0 grep -I -n -i -E 'qg-publish|pr-understanding|comment-upsert|gh-identity|pr-create\.sh|pr-detect|build-pr-context|diagram-facts|accuracy-warnings|=== PR CONTEXT' 2>/dev/null) || true)"
if [ -z "$HITS" ]; then ok "AC16: 옛 게시 표면의 개념 별칭이 살아 있는 코퍼스에 0건"; else no "AC16: 개념 별칭 잔존 — $(printf '%s\n' "$HITS" | head -n 5)"; fi
# 스윕 매처 대조 — 같은 grep 이 합성 줄을 잡는다.
printf 'see /qg-publish and PR-Understanding\n' | grep -q -i -E 'qg-publish|pr-understanding' \
  && ok "스윕 매처 대조" || no "스윕 매처가 합성 줄을 못 잡는다"

# ── (3) 양의 짝 ─────────────────────────────────────────────────────────────
mode="$(git -C "$ROOT" ls-files -s -- plugins/quality-gates/scripts/publish-comment.sh | cut -d' ' -f1)"
assert_eq "$mode" "100755" "양의 짝: publish-comment.sh 가 실행 파일로 추적된다"
out="$(printf 'k\tv\n' | python3 "$QG/scripts/render-terminal.py" table --title T)"; rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '^k   v$' && ok "render-terminal table 이 남아 있다" || no "render-terminal table 이 깨졌다(rc=$rc)"
for sub in diagram accuracy-warnings; do
  err="$(python3 "$QG/scripts/render-terminal.py" "$sub" </dev/null 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc" "2" "render-terminal ${sub} 하위명령이 없다(argparse rc 2)"
  printf '%s\n' "$err" | grep -q 'invalid choice' \
    && ok "render-terminal ${sub}: 사유가 invalid choice 다(필수 인자 누락이 아니다)" || no "render-terminal ${sub}: stderr 에 invalid choice 가 없다 — $(printf '%s' "$err" | head -n 1)"
done
grep -qF 'Skill("quality-gates:quality-pipeline")' "$QG/commands/qg.md" \
  && ok "qg 진입이 파이프라인 skill 을 부른다(양성 증인)" || no "qg.md 가 파이프라인 skill 을 부르지 않는다"
finish
