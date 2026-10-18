#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/spec-interview/references/finishing.md plugins/spec-distill/templates/interview-brief-template.md plugins/spec-distill/skills/spec-review/SKILL.md
#
# AC8 · AC16 — 핸드오프 자리(interview 의 다음 세션 줄 · brief 템플릿 §7 · spec-review description)가
# brainstorming → `spec-distill:spec-review` → writing-plans 순서를 싣고, `spec-review` 의 게이트 없는
# 두 종료 경로가 같은 복귀 지시로 끝나는가. spec-review 승인 게이트의 표 · 다음 세션 줄 · 정지 요건도 잰다.
#
# **정적 락이다.** 문구의 존재와 순서만 증명한다 — 오케스트레이터가 그 문구대로 부르는지는
# 재지 못한다(AC14 수동 e2e 몫). 게이트 없는 종료의 «실행 출력»은
# `test_reviewing_spec_entry_fence.sh` 가 잰다 — 여기는 그 문장이 표면에 있는지만 본다.
#
# 자리마다 창을 따로 자른다 — 파일 어딘가에 순서가 있으면 통과하는 것이 아니라 그 자리에
# 있어야 한다. 순서는 창 안의 문자 오프셋으로 잰다(한 줄 안의 순서까지).
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIN="$ROOT/plugins/spec-distill/skills/spec-interview/references/finishing.md"
TPL="$ROOT/plugins/spec-distill/templates/interview-brief-template.md"
SKILL="$ROOT/plugins/spec-distill/skills/spec-review/SKILL.md"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/skills/spec-interview/references/finishing.md"
  echo "plugins/spec-distill/templates/interview-brief-template.md"
  echo "plugins/spec-distill/skills/spec-review/SKILL.md"
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"

TMP="$(mktemp -d)" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
trap 'rm -rf "$TMP"' EXIT

RETURN_TAIL='리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트).'

nonempty() {   # nonempty <라벨> <창> — 빈 창은 통과가 아니라 앵커 파손
  if [ -n "$2" ]; then ok "$1: 창 추출 ($(printf '%s\n' "$2" | wc -l | tr -d ' ')줄)"; return 0; fi
  no "$1: 창이 비었다 — 구조 앵커 파손 (통과 아님)"; return 1
}
order() {   # order <라벨> <창> <앞> <뒤>
  local r
  r="$(WIN="$2" A="$3" B="$4" python3 -c '
import os
w, a, b = os.environ["WIN"], os.environ["A"], os.environ["B"]
i, j = w.find(a), w.find(b)
print("앞 없음" if i < 0 else "뒤 없음" if j < 0 else "ok" if i < j else "역순")
')"
  if [ "$r" = "ok" ]; then ok "$1: '$3' → '$4'"; else no "$1: 순서 판정 $r ('$3' → '$4')"; fi
}

# ── 다음 세션 줄 — 표지 블록의 한 줄 (①·② 공통) ────────────────────────────
NSL_MARK='**다음 세션 줄 — ①/② 공통**'
nsl() { awk -v m="$NSL_MARK" '$0==m{f=1;next} f&&NF{print;exit}' "$1" | sed -e 's/^> `//' -e 's/`$//'; }
# 줄 앞 `@<…>` 토큰들을 다루는 셋 — 목록 원소(토큰)가 늘어도 같은 판정이 나온다(설계 G3).
#   lead_only <줄>        줄 안의 꺾쇠 자리표가 줄 앞 토큰의 이름뿐이면 ok
#   split_line <줄> first 첫 토큰(주 산출물)
#   split_line <줄> rest  토큰들을 뗀 나머지
lead_only() { LINE="$1" python3 -I -c '
import os, re
l = os.environ["LINE"]
m = re.match(r"((?:@<[^<>]+> )+)", l)
names = set(re.findall(r"@<([^<>]+)>", m.group(1))) if m else set()
rest = re.findall(r"<([^<>]+)>", l[m.end():]) if m else ["(앞 토큰 없음)"]
print("ok" if m and all(x in names for x in rest) else "no")'; }
split_line() { LINE="$1" WHAT="$2" python3 -c '
import os, re
l = os.environ["LINE"]
m = re.match(r"((?:@<[^<>]+> )+)", l)
if not m:
    print("")
elif os.environ["WHAT"] == "first":
    print(re.findall(r"@<[^<>]+>", m.group(1))[0])
else:
    print(l[m.end():])'; }
ONE="$(nsl "$FIN")"
n1="$(grep -cE '^[[:space:]]*> `(@<[^<>]+> )+이 interview brief 로' "$FIN" || true)"
if nonempty "다음 세션 줄" "$ONE"; then
  assert_eq "$n1" "1" "다음 세션 줄 모양의 인용 줄이 finishing.md 에 정확히 하나 (①·② 가 따로 정의하지 않는다)"
  assert_eq "$(split_line "$ONE" first)" "@<brief-path>" "다음 세션 줄의 첫 토큰은 @<brief-path> (주 산출물)"
  case "$(split_line "$ONE" rest)" in
    "이 interview brief 로 Skill superpowers:brainstorming 을 시작하라."*) ok "다음 세션 줄이 토큰 뒤에 brainstorming 을 부른다" ;;
    *) no "다음 세션 줄의 토큰 뒤 머리가 다르다: $ONE" ;;
  esac
  order "다음 세션 줄" "$ONE" "Skill superpowers:brainstorming" "spec-distill:spec-review"
  order "다음 세션 줄" "$ONE" "spec-distill:spec-review" "writing-plans"
  assert_not_contains "$ONE" "보다 이 순서가 우선한다" "AC1: 다음 세션 줄에 brainstorming 지시를 덮어쓰는 문장이 없다(D42)"
  for n in '§3 열린 질문 · §4 조사 · §5 위험' '번호째' '## 번호 대조 표' 'source_interview' '--bundle 과 source_interview 에 적은 것과 같은 상대경로를 붙여' \
           'brief frontmatter audit_file(같은 폴더) §6 의 S 번호를 싣고' 'AC1 · AC2 … 처럼 번호를 단다' \
           'check_bundle_coverage.py --plan' '## Acceptance Criteria 의 AC 목록' '구현됨 · 미룸 · 빠짐' \
           'git 이 추적하지 않는 파일' '## 미룸 표' 'check_bundle_coverage.py --impl' '/compact 요약에 기대지 말고'; do
    assert_contains "$ONE" "$n" "AC1 · AC10: brief 다음 세션 줄에 「${n}」"
  done
  order "다음 세션 줄" "$ONE" "--plan" "--impl"
  assert_contains "$ONE" "게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다" "다음 세션 줄: 게이트 없는 종료의 복귀 분기를 싣는다 (AC16)"
  assert_eq "$(lead_only "$ONE")" "ok" "다음 세션 줄 안의 꺾쇠 자리표는 줄 앞 @<…> 토큰의 이름뿐이다"
  assert_eq "$(lead_only '@<a> x <a> y')" "ok" "꺾쇠 규칙: 줄 앞 토큰의 이름은 줄 안에 다시 쓸 수 있다"
  assert_eq "$(lead_only '@<a> x <b> y')" "no" "꺾쇠 규칙 양성 대조: 줄 앞 토큰에 없는 이름은 거부한다"
  sed 's/Skill superpowers:brainstorming 을 시작하라\./Skill superpowers:brainstorming 을 시작하라. brainstorming 의 「다음은 writing-plans 뿐」 지시보다 이 순서가 우선한다./' "$FIN" > "$TMP/fin_mut.md"
  case "$(nsl "$TMP/fin_mut.md")" in
    *"보다 이 순서가 우선한다"*) ok "변이(AC15): 덮어쓰기 문장을 되넣으면 같은 추출이 그것을 본다 — AC1 부재 단언에 이빨이 있다" ;;
    *) no "변이(AC15): 되넣은 덮어쓰기 문장을 추출이 못 본다 — 부재 단언이 공허하다" ;;
  esac
fi
assert_file_absent "$FIN" '/compact interview brief at' "옛 /compact 보존 템플릿이 없다"
assert_file_absent "$FIN" '확정하고 바로 brainstorming' "옛 「바로 brainstorming」 옵션이 없다"

# ── brief 템플릿 §7 ─────────────────────────────────────────────────────────
SEV="$(awk '/^## 7\. Next Action/{f=1} f' "$TPL")"
if nonempty "§7" "$SEV"; then
  order "brief 템플릿 §7" "$SEV" "superpowers:brainstorming" "spec-distill:spec-review"
  order "brief 템플릿 §7" "$SEV" "spec-distill:spec-review" "writing-plans"
fi

# ── spec-review description — 자기 자신을 가리키므로 이름 대신 «앞/뒤» 를 잰다 ─
DESC="$(awk 'NR==1 && /^---$/{f=1; next} f && /^---$/{exit} f' "$SKILL" \
  | awk '/^description:/{d=1; print; next} d && /^[a-z_]+:/{d=0} d')"
if nonempty "description" "$DESC"; then
  order "description" "$DESC" "superpowers:brainstorming" "superpowers:writing-plans"
  assert_contains "$DESC" "before superpowers:writing-plans" "description: writing-plans «앞» 에 쓴다고 적는다"
  assert_contains "$DESC" "user-review gate" "description: brainstorming 의 사용자 리뷰 게이트를 대신한다고 적는다"
  assert_contains "$DESC" "path as the argument" "description: 설계문서 경로를 인자로 받는다고 적는다"
fi

# ── AC16 — 게이트 없는 두 종료 경로 ──────────────────────────────────────────
STEPA="$(grep -E '^> `\[spec-distill\] current_spec ' "$SKILL" || true)"
na="$(printf '%s' "$STEPA" | grep -c . || true)"
if [ "$na" = "1" ]; then
  case "$STEPA" in
    *"$RETURN_TAIL\`") ok "대상 부재 advisory 가 복귀 지시로 끝난다" ;;
    *) no "대상 부재 advisory 의 마지막 문장이 복귀 지시가 아니다: $STEPA" ;;
  esac
else
  no "대상 부재 advisory 인용 줄이 ${na}개 — 정확히 하나여야 한다"
fi
FENCE="$(awk 'index($0,"<!-- review-entry:begin -->"){f=1;next} index($0,"<!-- review-entry:end -->"){f=0} f' "$SKILL")"
if nonempty "진입 펜스" "$FENCE"; then
  assert_contains "$FENCE" "$RETURN_TAIL" "진입 펜스가 복귀 지시 문장을 갖는다"
fi

# ── spec-review 승인 게이트 2단계 — 표 · 다음 세션 줄 · ①/② 정지 요건 ─────
GATE="$(awk '/^## 게이트$/{f=1;next} f&&/^## /{exit} f' "$SKILL")"
if nonempty "spec-review 게이트 절" "$GATE"; then
  rows="$(printf '%s\n' "$GATE" | grep -E '^\| [①②③④] \|' || true)"
  assert_eq "$(printf '%s\n' "$rows" | grep -c . || true)" "4" "spec-review 2단계 표(양성): 행 4개를 읽었다"
  r1="$(printf '%s\n' "$rows" | grep -E '^\| ① \|' || true)"
  r2="$(printf '%s\n' "$rows" | grep -E '^\| ② \|' || true)"
  for n in '`/compact` 후 다음 세션 줄' '(권장)' '턴 종료'; do assert_contains "$r1" "$n" "spec-review ① 행에 $n"; done
  for n in '`/new` 후 같은 다음 세션 줄' '턴 종료'; do assert_contains "$r2" "$n" "spec-review ② 행에 $n"; done
  assert_not_contains "$r2" '권장' "spec-review: 권장은 ① 하나"
  assert_not_contains "$rows" '바로' "spec-review 2단계 표에 「바로」 진행 행이 없다"
  r3="$(printf '%s\n' "$rows" | grep -E '^\| ③ \|' || true)"
  assert_contains "$r3" '`spec-interview` 재진입' "spec-review ③ 행: 인터뷰 재진입 갈래는 그대로 있다"
  assert_contains "$r3" '로드맵 에픽이면 이 에픽 다시 설계도' "AC33: spec-review ③ 행이 로드맵 에픽의 넷째 갈래를 말한다"
  BR="$(printf '%s\n' "$GATE" | awk '/^\*\*③ 의 갈래와 로드맵 에픽\.\*\*/{f=1} f&&/^- \*\*①\/② 의 정지 요건\*\*/{exit} f')"
  if [ -n "$BR" ]; then ok "spec-review: ③ 로드맵 분기 문단 창"; else no "spec-review: ③ 로드맵 분기 문단이 없다"; fi
  for n in '「지적대로 고치기」' '「인터뷰 다시 열기」' '「직접 편집」' 'frontmatter 에 `roadmap:` 줄이 있으면' \
           'references/redecompose.md' '지금 그대로다'; do
    assert_contains "$BR" "$n" "spec-review ③ 로드맵 분기: $n"
  done
  for n in '「이 에픽 다시 설계」' '이 에픽의 묶음 안에서 끝날 때' 'Skill superpowers:brainstorming 을 다시 시작한다' \
           '같은 경로에 고쳐 쓰고 커밋한 뒤' '묶음 · 로드맵은 고치지 않는다' '지적이 다른 에픽의 경계에 닿을 때' \
           '「(권장)」 과 이유 한 줄' '고르는 것은 사용자다' '`roadmap:` 줄이 없는 문서의 세 갈래는 지금 그대로다'; do
    assert_contains "$BR" "$n" "AC33: spec-review ③ 로드맵 갈래 — $n"
  done
  for n in '**기타 칸 — 기각 번호 되돌리기.**' '「반영」으로 되돌린다' '`## 번호 대조` 표의 그 행' \
           '- 결정 · <YYYY-MM-DD> · 기각 되돌림' '「지적대로 고치기」 와 같은 길' '로드맵 에픽이 아니어도 같다'; do
    assert_contains "$BR" "$n" "AC34: ③ 기타 칸의 기각 번호 되돌리기 — $n"
  done
  BR_RD="$(printf '%s\n' "$BR" | grep -n '^Read \${CLAUDE_PLUGIN_ROOT}/references/redecompose\.md$' | cut -d: -f1)"
  [ -n "$BR_RD" ] && ok "AC33: 재분해 Read 줄이 ③ 문단 안에 들여쓰기 없이 있다" || no "AC33: 재분해 Read 줄이 ③ 문단 안에 없다(들여썼거나 꼬리가 붙었다)"
  RSL="$(nsl "$SKILL")"
  if nonempty "spec-review 다음 세션 줄" "$RSL"; then
    assert_eq "$(split_line "$RSL" first)" "@<spec_path>" "spec-review 다음 세션 줄의 첫 토큰은 @<spec_path> (주 산출물)"
    case "$(split_line "$RSL" rest)" in
      "이 설계문서로 Skill superpowers:writing-plans 를 시작하라."*) ok "spec-review 다음 세션 줄이 토큰 뒤에 writing-plans 를 부른다" ;;
      *) no "spec-review 다음 세션 줄의 토큰 뒤 머리가 다르다: $RSL" ;;
    esac
    assert_contains "$RSL" "보고 후 재결정" "spec-review 다음 세션 줄이 C4 문장을 싣는다"
    assert_grep "$RSL" '임의 변경.*금지' "spec-review 다음 세션 줄이 임의 변경 금지를 싣는다"
    for n in 'check_bundle_coverage.py --plan <spec_path>' '계획에 없는 AC 는 계획에 더한다' \
             '## Acceptance Criteria 의 AC 목록' '구현됨 · 미룸 · 빠짐' 'git 이 추적하지 않는 파일' \
             '## 미룸 표' 'check_bundle_coverage.py --impl <spec_path>'; do
      assert_contains "$RSL" "$n" "AC1 · AC10: spec-review 다음 세션 줄(writing-plans 진행 안내)에 「${n}」"
    done
    assert_contains "$RSL" '고른 실행 방식의 마지막 전체 리뷰' "AC42: 승인 게이트 다음 세션 줄이 고른 실행 방식의 마지막 전체 리뷰를 말한다"
    assert_not_contains "$RSL" 'SDD 의 마지막 전체 리뷰' "AC42: 다음 세션 줄이 SDD 로 고정하지 않는다(양성 짝: 위 줄)"
    assert_eq "$(lead_only "$RSL")" "ok" "spec-review 다음 세션 줄의 꺾쇠 자리표는 <spec_path> 뿐이다"
  fi
  STOP="$(printf '%s\n' "$GATE" | awk '/^- \*\*①\/② 의 정지 요건\*\*/{f=1;print;next} f&&/^- /{f=0} f' | tr '\n' ' ' | tr -s ' ')"
  [ -n "$STOP" ] && ok "spec-review(양성): ①/② 의 정지 요건 불릿을 읽었다" || no "spec-review: ①/② 의 정지 요건 불릿이 없다 — 아래 단언이 공허하다"
  for n in '턴 종료(STOP)' '같은 턴에서 `writing-plans` 를 호출하지 않는다' '**다음 턴**' '사용자 트리거로만'; do
    assert_contains "$STOP" "$n" "spec-review ①/② 정지 요건 불릿 안에 $n"
  done
fi
assert_file_absent "$SKILL" '/compact 설계문서' "spec-review: 옛 /compact 보존 틀이 없다"
assert_file_absent "$SKILL" '① 의 정지 요건' "spec-review: 옛 「① 의 정지 요건」 불릿 이름이 없다"
assert_file_grep "$FIN" '\$\{CLAUDE_PLUGIN_ROOT\}/references/epic-handoff\.md' "finishing.md 가 에픽 넘김 줄 reference 를 가리킨다(AC2 · 고아 reference 방지)"
finish
