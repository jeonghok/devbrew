#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/context-build/references/finishing.md plugins/spec-distill/templates/interview-brief-template.md plugins/spec-distill/skills/spec-review/SKILL.md plugins/spec-distill/references/brief-handoff.md
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
FIN="$ROOT/plugins/spec-distill/skills/context-build/references/finishing.md"
TPL="$ROOT/plugins/spec-distill/templates/interview-brief-template.md"
SKILL="$ROOT/plugins/spec-distill/skills/spec-review/SKILL.md"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/skills/context-build/references/finishing.md"
  echo "plugins/spec-distill/templates/interview-brief-template.md"
  echo "plugins/spec-distill/skills/spec-review/SKILL.md"
  echo "plugins/spec-distill/references/brief-handoff.md"
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"

TMP="$(mktemp -d)" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
trap 'rm -rf "$TMP"' EXIT

RETURN_TAIL='리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 이 설계문서 점검을 마친 뒤 문서를 승인받는 자리).'

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
BH="$ROOT/plugins/spec-distill/references/brief-handoff.md"
bh_sec() { awk -v h="## $2" '$0==h{f=1;next} f&&/^## /{exit} f' "$1"; }   # bh_sec <파일> <절 이름> → 그 절의 본문
bh_items() { bh_sec "$1" "$2" | sed -n 's/^- //p'; }                        # 그 절의 불릿 문장(불릿을 뗀 글)
POINT_BS='시작하기 전에 ${CLAUDE_PLUGIN_ROOT}/references/brief-handoff.md 의 ## brainstorming 지시 절을 읽고 그 지시를 따른다 — 그 파일의 플러그인 루트 변수는 ${CLAUDE_PLUGIN_ROOT} 로 읽는다. 읽지 못하면 추측하지 말고 멈춰 보고한다.'
POINT_CM='시작하기 전에 ${CLAUDE_PLUGIN_ROOT}/references/brief-handoff.md 의 ## 공통 지시 절을 읽고 그 지시를 따른다 — 그 파일의 플러그인 루트 변수는 ${CLAUDE_PLUGIN_ROOT} 로 읽는다. 읽지 못하면 추측하지 말고 멈춰 보고한다.'
# 옛 다음 세션 줄의 지시 문장 열다섯 — 그 순서 그 글자(「사용자 선호:」 라벨만 뗐다). 있는 것 검토 괄호와 마지막 전체 리뷰의 묻는 구절은 에픽 넘김 줄과 같은 글자다(test_end_gates.sh).
cat > "$TMP/want_bs.txt" <<'WANT'
confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.
brief 의 §2 확정 항목뿐 아니라 §3 열린 질문 · §4 조사 · §5 위험을 번호째 설계의 입력으로 읽는다 — /compact 요약에 기대지 말고 첨부한 brief 를 다시 읽는다.
설계문서에 ## 번호 대조 표(칸: 번호 · 반영/기각 · 자리 또는 이유)를 두어 brief 의 모든 번호와 brief frontmatter audit_file(같은 폴더) §6 의 S 번호를 싣고, 설계문서 frontmatter source_intent 에 이 brief 의 레포 루트 기준 상대경로를 적는다.
설계문서의 수용 기준은 ## Acceptance Criteria 아래 AC1 · AC2 … 처럼 번호를 단다.
설계의 규칙은 「기본은 X, 일의 모양이 다르면 모델이 판단하고 이유를 적는다」로 쓰고 정석 흐름(설계 → 계획 → 구현)의 의도는 지킨다.
설계문서에 ## 있는 것 검토 절(맞는 있는 것이 있으면 그 위에서 만드는 것이 기본이다 — 찾아본 후보를 이름으로 먼저 적고, 직접 만들려면 그 후보에 대한 구체 이유를 적어 사용자 승인을 받는다. 레포 밖 것은 후보와 차이를 보여 사용자가 승인한 뒤에만 쓴다. 적는 법은 ${CLAUDE_PLUGIN_ROOT}/references/existing-first.md 를 읽어 따른다)과 ## 상류 · 하류 연계 절(이 일이 받는 곳 · 넘기는 곳 · 되돌아오는 길 · 같은 상태를 읽는 다른 표면)을 두고, 경로 · 테스트 명령 · 기본 브랜치 · 브랜치 이름 · 모델 같은 레포 전용 값은 박지 말고 도출하거나 레포 설정에서 읽게 설계한다.
이 brief 의 설계는 설계문서를 쓰는 크기다 — 질문을 건너뛰어도 설계문서를 쓰고 spec-review 를 거친다.
brief 의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다.
설계문서를 쓰고 커밋한 뒤, brainstorming 의 설계문서 점검(builder check)과 그 질문을 마치고 문서를 승인받는 자리에서 그 설계문서 경로 뒤에 --bundle 과 source_intent 에 적은 것과 같은 상대경로를 붙여 Skill spec-distill:spec-review 를 부른다.
superpowers:writing-plans 는 spec-review 의 승인 게이트에서 진행이 선택된 뒤에만 부른다.
spec-review 가 게이트 없이 끝나면 brainstorming 의 문서 승인 자리로 돌아간다.
writing-plans 가 계획을 쓴 뒤 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --plan 에 설계문서와 계획 경로를 넘겨 돌리고, 계획에 없는 AC 는 계획에 더한다.
고른 실행 방식의 마지막 전체 리뷰에 설계문서 ## Acceptance Criteria 의 AC 목록을 싣고, 리뷰가 AC 마다 한 줄씩 AC1: 구현됨 — 근거 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)로 보고하게 해 그 보고를 git 이 추적하지 않는 파일에 적는다. 그 리뷰가 설계문서 ## 있는 것 검토 절이 고른 것을 실제로 썼는지(같은 것을 다시 만들지 않았는지)도 묻게 한다.
미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 ## 미룸 표(항목 · 이유 · 받는 곳)에 올리고, PR 을 만들기 전에 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --impl 에 설계문서와 보고 파일 경로를 넘겨 돌려 경고를 사용자에게 보인다.
사람에게 쓰는 글의 낱말 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에)을 지키고, 메시지 모양(첫 메시지 · 질문 하나 · 되비춤)은 brainstorming 을 따른다.
WANT
# 「다른 다음 단계의 줄」 이 글자로 싣던 네 문장.
cat > "$TMP/want_cm.txt" <<'WANT'
confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.
brief 의 §2 확정 항목뿐 아니라 §3 열린 질문 · §4 조사 · §5 위험을 번호째 입력으로 읽는다 — /compact 요약에 기대지 말고 첨부한 brief 를 다시 읽는다.
brief 의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다.
사람에게 쓰는 글의 낱말 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에)을 지킨다.
WANT
ONE="$(nsl "$FIN")"
n1="$(grep -cE '^[[:space:]]*> `(@<[^<>]+> )+이 context brief 로' "$FIN" || true)"
if nonempty "다음 세션 줄" "$ONE"; then
  assert_eq "$n1" "1" "다음 세션 줄 모양의 인용 줄이 finishing.md 에 정확히 하나 (①·② 가 따로 정의하지 않는다)"
  assert_eq "$(split_line "$ONE" first)" "@<brief-path>" "다음 세션 줄의 첫 토큰은 @<brief-path> (주 산출물)"
  # F4 AC1 — 줄은 brief 첨부 · 시작 문장 · 지시 파일을 가리키는 문장뿐이다(등호 — 문장 하나가 더 붙어도 실패한다)
  assert_eq "$(split_line "$ONE" rest)" "이 context brief 로 Skill superpowers:brainstorming 을 시작하라. ${POINT_BS}" "F4 AC1: 다음 세션 줄은 시작 문장과 지시 파일을 가리키는 문장뿐이다"
  assert_eq "$(lead_only "$ONE")" "ok" "다음 세션 줄 안의 꺾쇠 자리표는 줄 앞 @<…> 토큰의 이름뿐이다"
  assert_eq "$(lead_only '@<a> x <a> y')" "ok" "꺾쇠 규칙: 줄 앞 토큰의 이름은 줄 안에 다시 쓸 수 있다"
  assert_eq "$(lead_only '@<a> x <b> y')" "no" "꺾쇠 규칙 양성 대조: 줄 앞 토큰에 없는 이름은 거부한다"
  # F4 AC2 — 지시 파일의 brainstorming 절이 옛 줄의 지시 문장을 그 순서 그 글자로 싣는다(등호 — 빠짐 · 순서 바뀜 · 더해짐 모두 실패)
  [ -f "$BH" ] && ok "지시 파일이 있다: references/brief-handoff.md" || no "지시 파일이 없다: references/brief-handoff.md"
  GOT_BS="$(bh_items "$BH" 'brainstorming 지시')"
  assert_eq "$(printf '%s\n' "$GOT_BS" | grep -c .)" "15" "F4 AC2(양성 대조): brainstorming 지시 절에서 문장 열다섯을 읽었다"
  assert_eq "$GOT_BS" "$(cat "$TMP/want_bs.txt")" "F4 AC2: brainstorming 지시 절이 옛 줄의 지시 문장을 순서대로 모두 싣는다"
  assert_not_contains "$(bh_sec "$BH" 'brainstorming 지시')" '사용자 선호:' "F4 AC2: 「사용자 선호:」 라벨이 없다(양성 짝: 라벨 뗀 그 문장은 위 등호가 본다)"
  # F4 AC1 — 옛 지시 문장은 줄에 하나도 없다(양성 짝: 같은 문장이 지시 파일에 있다 — 위 등호)
  k=0
  while IFS= read -r s; do
    k=$((k + 1))
    assert_not_contains "$ONE" "$s" "F4 AC1: 옛 지시 문장 ${k} 이 다음 세션 줄에 없다"
  done < "$TMP/want_bs.txt"
  assert_eq "$k" "15" "F4 AC1(양성 대조): 옛 지시 문장 열다섯을 줄과 대조했다"
  # AC8 · AC16 — 순서는 지시 절 안에서 잰다
  INS="$(printf '%s\n' "$GOT_BS" | tr '\n' ' ')"
  order "brainstorming 지시 절" "$INS" "spec-distill:spec-review" "writing-plans"
  order "brainstorming 지시 절" "$INS" "--plan" "--impl"
  order "brainstorming 지시 절" "$INS" "이 brief 의 설계는 설계문서를 쓰는 크기다" "spec-distill:spec-review"
  assert_not_contains "$INS" "보다 이 순서가 우선한다" "AC1: 지시 절에 brainstorming 지시를 덮어쓰는 문장이 없다(D42)"
  assert_not_contains "$ONE" "보다 이 순서가 우선한다" "AC1: 다음 세션 줄에 brainstorming 지시를 덮어쓰는 문장이 없다(D42)"
  # 두 절은 서로를 가리키지 않는다(양성 짝: 두 절을 읽었다 — 위 · 아래 등호)
  assert_not_contains "$(bh_sec "$BH" 'brainstorming 지시')" '공통 지시' "F4: brainstorming 지시 절이 공통 지시 절을 가리키지 않는다"
  assert_not_contains "$(bh_sec "$BH" '공통 지시')" 'brainstorming 지시' "F4: 공통 지시 절이 brainstorming 지시 절을 가리키지 않는다"
  # F4 AC3 — 「다른 다음 단계의 줄」 이 공통 지시를 지시 파일의 절로 가리킨다
  OTHER="$(grep -F '**다른 다음 단계의 줄 — 둘째 질문에서 제안을 골랐을 때.**' "$FIN" || true)"
  if nonempty "다른 다음 단계의 줄" "$OTHER"; then
    assert_contains "$OTHER" "「${POINT_CM}」" "F4 AC3: 다른 다음 단계의 줄이 공통 지시 절을 가리키는 문장을 싣는다"
    assert_contains "$OTHER" '줄에는 공통 지시를 글자로 싣지 않고' "F4 AC3: 공통 지시를 글자로 싣지 않는다고 적는다"
    GOT_CM="$(bh_items "$BH" '공통 지시')"
    assert_eq "$GOT_CM" "$(cat "$TMP/want_cm.txt")" "F4 AC3: 공통 지시 절이 네 문장을 싣는다"
    k=0
    while IFS= read -r s; do
      k=$((k + 1))
      assert_not_contains "$OTHER" "$s" "F4 AC3: 공통 지시 문장 ${k} 이 문단에 글자로 없다"
    done < "$TMP/want_cm.txt"
    assert_eq "$k" "4" "F4 AC3(양성 대조): 공통 지시 문장 넷을 문단과 대조했다"
  fi
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
  assert_contains "$SEV" "설계문서 점검과 그 질문을 마친 뒤 문서를 승인받는 자리" "지휘자 수리 2: §7 이 spec-review 의 자리를 7.0.0 이름으로 적는다"
  assert_not_contains "$SEV" "사용자 리뷰 게이트" "지휘자 수리 2: §7 에 옛 이름이 없다(양성 짝: 위 단언)"
fi

# ── spec-review description — 자기 자신을 가리키므로 이름 대신 «앞/뒤» 를 잰다 ─
DESC="$(awk 'NR==1 && /^---$/{f=1; next} f && /^---$/{exit} f' "$SKILL" \
  | awk '/^description:/{d=1; print; next} d && /^[a-z_]+:/{d=0} d')"
if nonempty "description" "$DESC"; then
  order "description" "$DESC" "superpowers:brainstorming" "superpowers:writing-plans"
  assert_contains "$DESC" "before superpowers:writing-plans" "description: writing-plans «앞» 에 쓴다고 적는다"
  assert_contains "$DESC" "after its builder check and that check's questions, hands the document" "description: brainstorming 의 설계문서 점검 뒤 문서 승인 자리를 대신한다고 적는다(superpowers 7.0.0)"
  assert_not_contains "$DESC" "user-review gate" "description: 7.0.0 에 없는 「사용자 리뷰 게이트」 이름을 쓰지 않는다(양성 짝: 위 단언)"
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
  assert_contains "$r3" '`context-build` 재진입' "spec-review ③ 행: 인터뷰 재진입 갈래는 그대로 있다"
  assert_contains "$r3" '로드맵 에픽이면 이 에픽 다시 설계도' "AC33: spec-review ③ 행이 로드맵 에픽의 넷째 갈래를 말한다"
  BR="$(printf '%s\n' "$GATE" | awk '/^\*\*③ 의 갈래와 로드맵 에픽\.\*\*/{f=1} f&&/^- \*\*①\/② 의 정지 요건\*\*/{exit} f')"
  if [ -n "$BR" ]; then ok "spec-review: ③ 로드맵 분기 문단 창"; else no "spec-review: ③ 로드맵 분기 문단이 없다"; fi
  for n in '「지적대로 고치기」' '「컨텍스트 쌓기 다시 열기」' '「직접 편집」' 'frontmatter 에 `roadmap:` 줄이 있으면' \
           'references/redecompose.md' '지금 그대로다'; do
    assert_contains "$BR" "$n" "spec-review ③ 로드맵 분기: $n"
  done
  for n in '「이 에픽 다시 설계」' '이 에픽의 묶음 안에서 끝날 때' 'Skill superpowers:brainstorming 을 다시 시작한다' \
           '같은 경로에 고쳐 쓰고 커밋한 뒤' '묶음 · 로드맵은 고치지 않는다' '지적이 다른 에픽의 경계에 닿을 때' '「컨텍스트 쌓기 다시 열기」 갈래의 라벨은 로드맵 에픽이면 「로드맵 다시 잡기」 다' \
           '라벨에 「(권장)」을 달고 그 이유는 그 선택지의 얻음에 담는다' '고르는 것은 사용자다' '`roadmap:` 줄이 없는 문서의 세 갈래는 지금 그대로다'; do
    assert_contains "$BR" "$n" "AC33: spec-review ③ 로드맵 갈래 — $n"
  done
  for n in '**기타 칸 — 기각 번호 되돌리기.**' '「반영」으로 되돌린다' '`## 번호 대조` 표의 그 행' \
           '- B<n> · 결정 · <YYYY-MM-DD> · 기각 되돌림' '그 문서 `## 결정 기록` 의 다음 B 번호' \
           '먼저 원장 열기를 다시 돈다' '기각 목록에 없으면 그 사실을 보이고 다시 묻는다' '컨텍스트 쌓기 다시 열기」(재분해, 로드맵 에픽이면 「로드맵 다시 잡기」) 갈래를 권한다' '「지적대로 고치기」 와 같은 길' '로드맵 에픽이 아니어도 같다'; do
    assert_contains "$BR" "$n" "AC34: ③ 기타 칸의 기각 번호 되돌리기 — $n"
  done
  for n in '표 행을 고치기 전에' '`docreview_state.py declare-related --state-dir D --decision <D#> --anchors' '채택한 결정이 없으면' \
           '다음 게이트에 「허가 없이 바뀜」 결정으로 다시 온다' '고친 대로 둠' \
           '`declare-related` 가 rc 0 이 아니면' "'<내용을 더한 절 앵커>'" '`insert-after:<그 앞 절 앵커>`' \
           '채택한 결정이 없으면 고친 행과 내용을 더한 절은'; do
    assert_contains "$BR" "$n" "AC13: 기각 되돌리기가 표 행을 고치기 전 허가 걸음을 적는다 — $n"
  done
  assert_not_contains "$BR" '채택한 결정이 없으면 고친 행은' "AC13: 알림이 고친 행만 덮지 않는다 — 내용을 더한 절도 다시 온다(양성 짝: 위 「고친 행과 내용을 더한 절은」)"
  assert_not_contains "$BR" '`- 결정 · <YYYY-MM-DD>' "AC34: 되돌림 결정 줄에 읽히지 않는 옛 꼴(B 번호 없는 줄머리)이 없다(양성 짝: 위 B<n> 꼴)"
  BR3="$(printf '%s\n' "$BR" | awk '/^\*\*다음 세션 줄 — ①\/② 공통\*\*/{exit} {print}')"
  BR_RD="$(printf '%s\n' "$BR3" | grep -n '^Read \${CLAUDE_PLUGIN_ROOT}/references/redecompose\.md$' | cut -d: -f1)"
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
    USED='설계문서 ## 있는 것 검토 절이 고른 것을 실제로 썼는지(같은 것을 다시 만들지 않았는지)도 묻게 한다.'
    assert_contains "$RSL" "$USED" "있는 것 먼저: 승인 게이트 다음 세션 줄의 마지막 전체 리뷰가 고른 것을 썼는지 묻는다(같은 글자: test_end_gates.sh)"
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
assert_file_grep "$ROOT/plugins/spec-distill/references/conducting.md" 'epic-handoff\.md' "conducting.md 가 에픽 넘김 줄 reference 를 가리킨다(고아 reference 방지 — 나눈 일의 다음 세션 줄은 지휘자 호출이 됐다)"
# 「위 복귀 문장」 을 가리키는 행보다 앞에 그 문장의 전문이 있다 — 가리킬 앞 자리가 사라지면 모델이 복귀 지시를 낼 근거가 없다
first_full="$(grep -nF "[spec-distill] $RETURN_TAIL" "$SKILL" | head -1 | cut -d: -f1)"
first_ref="$(grep -nF '위 복귀 문장' "$SKILL" | head -1 | cut -d: -f1)"
if [ -n "$first_full" ] && [ -n "$first_ref" ] && [ "$first_full" -lt "$first_ref" ]; then ok "「위 복귀 문장」 이 처음 나오는 줄($first_ref)보다 앞($first_full)에 복귀 문장 전문이 있다"
else no "「위 복귀 문장」 이 처음 나오는 줄(${first_ref:-없음})보다 앞에 복귀 문장 전문이 없다(전문 줄 ${first_full:-없음})"; fi

finish
