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

# 담당 agent 분담 · 게이트 문면 중계 · 메인 체크아웃(걸음 2~3).
for lit in '담당 agent' '그대로 돌려보내' '문면을 고쳐 쓰지 않고' '이유를 설계문서에 적는다'; do
  assert_contains "$(step 3)" "$lit" "걸음 3(리뷰는 담당 agent · 문면 중계): $lit"
done
assert_contains "$(step 2)" '메인 체크아웃' "걸음 2: 메인 체크아웃에 머문다"
assert_contains "$(step 2)" '권한다' "걸음 2: worktree 안 시작이면 메인에서 부르기를 권한다"
assert_contains "$(step 5)" '다른 에픽은 계속' "걸음 5: 한 에픽이 멈춰도 다른 에픽은 계속"

# 부재 락 — 문장 하나가 아니라 개념으로. 판정은 함수라 변이 대조가 같은 함수를 부른다.
forbid_23() {  # 걸음 2~3 글: 새 세션을 열게 하는 말(명시 부정문 제외)
  local t="${1//다른 세션을 열라고 하지 않는다/}" w
  for w in '/new' '세션을 따로' '새 세션' '다른 세션을 열' '세션을 연다' '세션을 열어'; do
    case "$t" in *"$w"*) printf '%s\n' "$w";; esac
  done
}
forbid_4() {  # 걸음 4 글: 계획 검토를 안 기다림 · Push(허용 문장 밖) · 실행 방식 고정
  local t="${1//Push 와 PR 은 지휘 세션이/}" w
  for w in '기다리지 않' 'Push' '푸시'; do
    case "$t" in *"$w"*) printf '%s\n' "$w";; esac
  done
}
forbid_always_method() {  # 줄에 «언제나/항상» 과 실행 방식 이름이 함께
  printf '%s\n' "$1" | grep -E '언제나|항상' | grep -E 'subagent|executing-plans|인라인|inline' || true
}
forbid_5() {
  local w
  for w in '모두 멈춘' '전부 멈춘'; do
    case "$1" in *"$w"*) printf '%s\n' "$w";; esac
  done
}
S23="$(step 2; step 3)"
assert_eq "$(forbid_23 "$S23")" "" "걸음 2~3: 새 세션을 열게 하는 말이 없다"
assert_eq "$(forbid_4 "$(step 4)")" "" "걸음 4: 계획 검토 무대기 · 허용 문장 밖 Push 가 없다"
assert_eq "$(forbid_always_method "$MAN")" "" "손 절차: 「언제나/항상」+실행 방식 고정이 없다"
assert_eq "$(forbid_5 "$(step 5)")" "" "걸음 5: 다른 에픽까지 멈추는 말이 없다"
for lit in '/new 로 에픽 worktree 세션을 연다' '에픽마다 세션을 따로 열어' '새 세션에서 이어 간다' '사용자가 다른 세션을 열어 진행'; do
  [ -n "$(forbid_23 "$S23 $lit")" ] && ok "양성 대조(2~3): 「${lit}」 를 잡는다" || no "양성 대조(2~3): 「${lit}」 를 못 잡는다"
done
for lit in '계획 검토는 기다리지 않는다' 'Push 하고 PR 만들기' '푸시 후 PR'; do
  [ -n "$(forbid_4 "$(step 4) $lit")" ] && ok "양성 대조(4): 「${lit}」 를 잡는다" || no "양성 대조(4): 「${lit}」 를 못 잡는다"
done
for lit in '실행 방식은 언제나 subagent-driven 이다' '항상 인라인으로 실행한다'; do
  [ -n "$(forbid_always_method "$MAN"$'\n'"$lit")" ] && ok "양성 대조(방식): 「${lit}」 를 잡는다" || no "양성 대조(방식): 「${lit}」 를 못 잡는다"
done
[ -n "$(forbid_5 "$(step 5) 다른 에픽도 모두 멈춘다")" ] && ok "양성 대조(5): 다른 에픽도 모두 멈춘다 를 잡는다" || no "양성 대조(5): 못 잡는다"

# `--acs` 는 «--plan 문장» 안에 있어야 한다(--impl 문장의 것으로 갈음 못 한다).
acs_in_plan() {
  local s="${1#*check_bundle_coverage.py --plan}"
  s="${s%%. *}"
  case "$s" in *'--acs'*) printf 'yes\n';; *) printf 'no\n';; esac
}
assert_eq "$(acs_in_plan "$(step 5)")" "yes" "걸음 5: --plan 문장 안에 --acs"
S5M="$(step 5 | sed 's/`--acs` 뒤에 그 계획이 맡은 AC 목록을 준다/그 계획이 맡은 AC 목록을 준다/')"
[ "$S5M" != "$(step 5)" ] && ok "변이 입력이 실제로 달라졌다" || no "변이 입력이 원문과 같다 — 위 대조가 공허하다"
assert_eq "$(acs_in_plan "$S5M")" "no" "양성 대조: --plan 문장에서 --acs 를 빼면 잡는다(--impl 문장에 남아도)"

# 레포 전용 값 · 루트 토큰 · references/ 꼴 가리킴 — 줄마다 낸다.
banned() {
  python3 -I - "$1" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
pats = [r"origin/main", r"(?<![A-Za-z])main(?![A-Za-z])", r"(?<![A-Za-z])opus(?![A-Za-z])",
        r"(?<![A-Za-z])fable(?![A-Za-z])", r"plugins/spec-distill", r"docs/superpowers", r"feature/",
        r"(?<![A-Za-z])master(?![A-Za-z])", r"(?<![A-Za-z])sonnet(?![A-Za-z])", r"(?<![A-Za-z])haiku(?![A-Za-z])",
        r"plugins/", r"shared/tests", r"\.superpowers/", r"DEVBREW_", r"\$\{CLAUDE_PLUGIN_ROOT\}", r"references/[A-Za-z0-9_.-]+\.md"]
for i, line in enumerate(text.splitlines(), 1):
    for p in pats:
        if re.search(p, line):
            print("%d: %s — %s" % (i, p, line.strip()[:80]))
PY
}
assert_eq "$(banned "$CD")" "" "레포 전용 값 · 루트 토큰 · references/ 꼴 가리킴이 없다"
for lit in 'origin/main' 'review_model: opus' 'python3 plugins/spec-distill/scripts/x.py' '${CLAUDE_PLUGIN_ROOT}/scripts' \
           'references/epic-handoff.md' 'feature/roadmap-x' 'main 에서 만든다' '.superpowers/sdd/x' \
           'origin/master' 'review_model: sonnet' 'haiku 로 부른다' 'plugins/other/x.py' 'shared/tests/x.sh'; do
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
