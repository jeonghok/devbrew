#!/usr/bin/env bash
# guards: plugins/spec-distill/commands/request-framing.md
#
# `/request-framing` command 가 자기 세 책임을 실제로 담고 있는가 — kill switch ·
# trivia escape 포인터 · skill dispatch. 그 셋뿐이고, 셋 다 없으면 안 된다.
#
# **포인터로 재는 이유**: trivia 5패턴을 이 파일에 그대로 쓰면 `interview.md` 와
# 20줄 이상 동일 구간이 생겨 `shared/tests/test_no_new_duplication.sh` 가 RED 를 낸다.
# 그래서 정본은 `references/trivia-escape.md` 이고 여기는 가리키기만 한다.
#
# ── 이 락이 재지 «못하는» 것 (실측) ─────────────────────────────────────────
# 아래 넷은 전부 **파일 어딘가에 그 리터럴이 있는가**를 보는 bare `grep -q` 다. 리터럴이
# 어느 문맥에 있는지, 그 문맥이 리터럴을 **긍정하는지 부정하는지**는 보지 않는다. 실측:
# 본문 끝에 「이 command 는 아래를 **항상 무시**한다 — 아무것도 실행하지 않는다」는 절을
# 붙이고 그 안에서 `DEVBREW_SPEC_DISTILL_DISABLE` · `references/trivia-escape.md` ·
# `framing-requests` 셋을 「…하지 않는다」로 인용하기만 해도 이 스위트는 **GREEN** 이다.
# 즉 「세 책임을 담고 있다」는 이 파일의 주장은 **리터럴 실재까지만** 보장한다.
#
# **계측기가 죽은 것은 아니다**(양성 대조, 실측): kill switch 문장을 실제로 지우면 RED 다.
# 리터럴 «삭제» 축에는 이빨이 있고, 리터럴 «부정» 축에는 없다 — 그 경계가 여기다.
#
# 형제 셋(`test_seed_gate_wiring.sh` · `test_seed_agents.sh` · `test_seed_codex_axes.sh`)은
# 관측된 사후상태로 판정해 이 부류를 넘지만, 그것들은 실행할 대상이 있는 락이다. 이
# command 는 실행되는 코드가 아니라 모델이 읽는 지시문이라 같은 방법을 쓸 수 없다 —
# 갭을 닫는 대신 여기 적어 둔다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CMD="$ROOT/plugins/spec-distill/commands/request-framing.md"
. "$ROOT/shared/tests/assert.sh"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/commands/request-framing.md"
  exit 0
fi

[ -f "$CMD" ] || { no "command 파일 부재: $CMD"; finish; exit $?; }
ok "command 파일 실재"

grep -q 'DEVBREW_SPEC_DISTILL_DISABLE' "$CMD" \
  && ok "kill switch 존중" || no "kill switch 가 없다 — 훅 밖 진입점이 스위치를 무시한다"

grep -qE 'references/trivia-escape\.md' "$CMD" \
  && ok "trivia escape 정본 포인터" || no "trivia escape 포인터가 없다"

grep -qE 'Skill .*framing-requests|framing-requests' "$CMD" \
  && ok "skill dispatch" || no "framing-requests skill 을 호출하지 않는다"

# 5패턴을 여기 «복제하지» 않았는가 — 정본이 있는데 사본이 있으면 둘이 갈라진다.
pc="$(grep -cE '^[0-9]\. \*\*(Typo|주석-only|formatting|단일 식별자|<10 토큰)' "$CMD")"
[ "$pc" -eq 0 ] \
  && ok "5패턴 본문이 복제되지 않았다 (정본만)" \
  || no "5패턴 본문이 이 파일에 복제돼 있다 (${pc}줄) — 정본과 갈라진다"

finish
