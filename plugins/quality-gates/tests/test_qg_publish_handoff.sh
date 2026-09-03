#!/usr/bin/env bash
# B2 — 파이프라인 종료가 자동 offer 가 아니라 명시 안내로 끝나는가.
#
# 양성 증인을 먼저 세운다: 종료 절이 **존재**하고 그 안에 /qg-publish 안내가
# 있는가. 그다음에야 부재를 묻는다. 부재만 보는 단언은 절을 통째로 지워도
# 통과하므로 스위트의 GREEN 을 완료로 오독하게 만든다.
#
# 술어를 절 스코프로 앵커하는 이유: qg.md 에는 삭제 대상과 무관한
# AskUserQuestion 이 여럿 남는다. 파일 전역으로 읽으면 영구 실패하고, 삭제된
# 구간으로 읽으면 그 구간이 사라졌으므로 공허참이다. **남는 절**을 앵커로 잡아야
# 둘 다 피한다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CMD="$PLUGIN_ROOT/commands/qg.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
test -f "$CMD" || { echo "FAIL: command missing at $CMD"; exit 1; }

# 남는 절을 앵커로 잡는다 — 헤딩부터 다음 '##'/'###' 헤딩 앞까지.
WIN="$(awk '/^### After the pipeline/{f=1;print;next} f&&/^#{2,3} /{exit} f{print}' "$CMD")"

# (1) 양성 증인 — 그 절이 실재한다 (비어 있으면 절이 통째로 사라진 것).
[ -n "$WIN" ] && ok "종료 절이 실재한다 (앵커 유효)" \
  || no "종료 절이 없다 — 앵커가 죽었다. 부재 단언이 공허참이 된다"

# (2) 양성 증인 — 그 절이 /qg-publish 안내를 담는다.
grep -qF '/qg-publish' <<<"$WIN" \
  && ok "종료 절이 /qg-publish 안내를 담는다" \
  || no "종료 절에 /qg-publish 안내가 없다 — 대체 경로가 사라졌다"

# (3) 부재 — 그 절 안에 자동 offer 가 없다.
grep -qF 'AskUserQuestion' <<<"$WIN" \
  && no "종료 절에 AskUserQuestion 이 남아 있다 — 자동 offer 가 철회되지 않았다" \
  || ok "종료 절에 AskUserQuestion 없음 (자동 offer 철회됨)"

# (4) 부재 — 그 절이 sentinel 을 읽지 않는다.
grep -qF 'publish-eligible' <<<"$WIN" \
  && no "종료 절이 여전히 publish-eligible sentinel 을 읽는다" \
  || ok "종료 절이 sentinel 을 읽지 않음 (소비자 0)"

# (5) B3a/B3b — 생산자 둘이 각자 사라졌는가. 양성 증인을 각 경로마다 따로 세운다:
#     한 테스트로 묶으면 한쪽만 지워도 통과한다.
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
RG="$PLUGIN_ROOT/skills/quality-pipeline/references/runtime-gate.md"

FS="$(awk '/^## Final Summary/{f=1;print;next} f&&/^## /{exit} f{print}' "$SKILL")"
grep -qF 'render-terminal.py table' <<<"$FS" \
  && ok "B3a 양성 증인: Final Summary 절이 자기 고유 산출물(표 렌더)을 담는다" \
  || no "B3a 앵커 죽음 — Final Summary 절을 못 찾았다"
grep -qF 'publish-eligible' <<<"$FS" \
  && no "B3a: Final Summary 가 여전히 sentinel 을 쓴다" \
  || ok "B3a: Final Summary 가 sentinel 을 쓰지 않음"

R8="$(awk '/^\*\*Step R8/{f=1} f{print} f&&/^\*\*Step R9/{exit}' "$RG")"
grep -qF 'Step R9' <<<"$R8" \
  && ok "B3b 양성 증인: R8 창이 R9 경계까지 실재한다" \
  || no "B3b 앵커 죽음 — R8 창을 못 찾았다"
grep -qF 'publish-eligible' <<<"$R8" \
  && no "B3b: Runtime R8 이 여전히 sentinel 을 쓴다" \
  || ok "B3b: Runtime R8 이 sentinel 을 쓰지 않음"

# (6) publish-active.md 는 **유지**다 — 이 테스트가 엉뚱한 표식을 지우게 만들지
#     않도록 그 생산자·소비자가 살아 있음을 양성으로 확인한다.
grep -qF 'publish-active.md' "$PLUGIN_ROOT/hooks/post-tool-use.py" \
  && ok "publish-active.md 소비자 생존 (지우면 안 되는 쪽)" \
  || no "publish-active.md 소비자가 사라졌다 — 엉뚱한 표식을 지웠다"
grep -qF 'publish-active.md' "$PLUGIN_ROOT/skills/publishing-pr-understanding/SKILL.md" \
  && ok "publish-active.md 생산자 생존" \
  || no "publish-active.md 생산자가 사라졌다 — 엉뚱한 표식을 지웠다"
finish
