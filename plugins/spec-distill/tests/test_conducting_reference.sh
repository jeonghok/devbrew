#!/usr/bin/env bash
# R5 계획 2 — 손으로 따르는 지휘 절차(`references/conducting.md`)의 걸음 · 레포 전용 값 없음 · 가리킴.
# 정적 락이다 — 지휘 세션이 이 절차를 실제로 따르는지는 재지 못한다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_conducting_reference.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SD="$ROOT/plugins/spec-distill"
CD="$SD/references/conducting.md"
RED="$SD/references/redecompose.md"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT

[ -f "$CD" ] && ok "conducting.md 가 있다" || { no "conducting.md 가 없다"; finish; exit $?; }
assert_eq "$(grep -cxF '## 손으로 따르는 절차' "$CD" || true)" "1" "손 절차 절 머리가 정확히 하나"
MAN="$(awk '$0=="## 손으로 따르는 절차"{f=1;next} f&&/^## /{exit} f' "$CD")"
[ -n "$MAN" ] && ok "손 절차 절을 읽었다" || no "손 절차 절이 비었다 — 아래 단언이 공허하다"
assert_eq "$(printf '%s\n' "$MAN" | grep -oE '^[1-9]\. ' | tr -d '. ' | tr '\n' ' ')" "1 2 3 4 5 6 7 8 9 " "걸음 1~9 가 차례로 있다"
step() {  # step <n> — 손 절차 걸음 n 의 글(다음 번호 걸음 앞까지)
  printf '%s\n' "$MAN" | awk -v n="$1" 'index($0, n ". ")==1{f=1; print; next} f && /^[1-9]\. /{exit} f'
}
for n in 1 2 3 4 5 6 7 8 9; do
  [ -n "$(step "$n")" ] && ok "걸음 $n 을 읽었다" || no "걸음 $n 이 비었다"
done
for lit in 'control_plane.py show --tasks <로드맵>' '종료 코드 4' 'roadmap_status.py --roadmap-file <로드맵>' '기억에 기대지 않는다'; do
  assert_contains "$(step 1)" "$lit" "걸음 1(맞추기): $lit"
done
for lit in '`브랜치:` 가 여럿이면' '앞 계획이 머지됐으면 기본 브랜치에서' '한 번에 한 에픽씩'; do
  assert_contains "$(step 2)" "$lit" "걸음 2(에픽과 브랜치): $lit"
done
for lit in 'AskUserQuestion' '거절되면 설계 흐름으로 간다' '`epic-handoff.md` 의 에픽 넘김 줄' '다른 세션을 열라고 하지 않는다' '`--bundle <묶음>`'; do
  assert_contains "$(step 3)" "$lit" "걸음 3(흐름과 설계): $lit"
done
for lit in 'writing-plans 가 권하는 방식' '설계에 없던 결정' '답 전에는 그 에픽의 구현을 보내지 않으며' '「브랜치 그대로 두기」'; do
  assert_contains "$(step 4)" "$lit" "걸음 4(설계가 정한 뜻): $lit"
done
assert_not_contains "$(step 4)" 'Push 후 PR' "걸음 4: 옛 미리 받은 답(Push 후 PR)이 없다(양성 짝: 「브랜치 그대로 두기」)"
assert_not_contains "$(step 4)" '기다리지 않고' "걸음 4: 계획 검토를 늘 안 기다리는 옛 문면이 없다(양성 짝: 설계에 없던 결정)"
for lit in 'check_bundle_coverage.py --plan' '--acs' '그 에픽만 멈추고' 'check_bundle_coverage.py --impl' '`### <계획 경로>`'; do
  assert_contains "$(step 5)" "$lit" "걸음 5(계획 · 구현): $lit"
done
assert_contains "$(step 6)" '`redecompose.md`' "걸음 6(머지 뒤): 재분해 절차를 가리킨다"
assert_contains "$(step 7)" 'Spec: <에픽 설계문서 레포 상대경로>' "걸음 7: Spec 트레일러"
for lit in '실패 «이름»' '`test_command`' '`review_model`' '같은 시각에 돌리지 않는다' '`## 통합 리뷰 인계`' '**리뷰 뒤 반영.**' '머지 직전' '스위트 대조 없음'; do
  assert_contains "$(step 8)" "$lit" "걸음 8(머지 전 확인): $lit"
done
for lit in '끝에서 끝' '브랜치는 지우지 않는다'; do
  assert_contains "$(step 9)" "$lit" "걸음 9(끝): $lit"
done

# 레포 전용 값 · 루트 토큰 · references/ 꼴 가리킴 — 줄마다 낸다.
banned() {
  python3 -I - "$1" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
pats = [r"origin/main", r"(?<![A-Za-z])main(?![A-Za-z])", r"(?<![A-Za-z])opus(?![A-Za-z])",
        r"(?<![A-Za-z])fable(?![A-Za-z])", r"plugins/spec-distill", r"docs/superpowers", r"feature/",
        r"\.superpowers/", r"DEVBREW_", r"\$\{CLAUDE_PLUGIN_ROOT\}", r"references/[A-Za-z0-9_.-]+\.md"]
for i, line in enumerate(text.splitlines(), 1):
    for p in pats:
        if re.search(p, line):
            print("%d: %s — %s" % (i, p, line.strip()[:80]))
PY
}
assert_eq "$(banned "$CD")" "" "레포 전용 값 · 루트 토큰 · references/ 꼴 가리킴이 없다"
for lit in 'origin/main' 'review_model: opus' 'python3 plugins/spec-distill/scripts/x.py' '${CLAUDE_PLUGIN_ROOT}/scripts' \
           'references/epic-handoff.md' 'feature/roadmap-x' 'main 에서 만든다' '.superpowers/sdd/x'; do
  { cat "$CD"; printf '%s\n' "$lit"; } > "$T/mut.md"
  [ -n "$(banned "$T/mut.md")" ] && ok "양성 대조: 「${lit}」 를 넣으면 잡는다" || no "양성 대조: 「${lit}」 를 못 잡는다"
done

# 가리키는 skill 은 실재한다(아직 없는 skill 을 가리키는 릴리스 금지 — 설계 §11).
n=0
for s in $(grep -ohE 'spec-distill:[a-z][a-z-]*' "$CD" "$SD/references/epic-handoff.md" "$RED" "$SD/references/proceed-gate.md" | sed 's/^spec-distill://' | LC_ALL=C sort -u); do
  n=$((n+1))
  [ -f "$SD/skills/$s/SKILL.md" ] && ok "가리키는 skill 이 있다: $s" || no "없는 skill 을 가리킨다: $s"
done
[ "$n" -ge 1 ] && ok "skill 이름을 ${n}개 읽었다" || no "skill 이름을 하나도 못 읽었다 — 위 검사가 공허하다"

# 고아 방지 — 재분해 6 이 손 절차를 가리킨다.
assert_file_grep "$RED" '\$\{CLAUDE_PLUGIN_ROOT\}/references/conducting\.md' "재분해 6 이 손 절차를 가리킨다"
finish
