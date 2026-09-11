#!/usr/bin/env bash
# guards: shared/docreview/references/reviewing-document.md plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/skills/reviewing-brief/SKILL.md shared/docreview/scripts/docreview_state.py
#
# 절차서(`shared/docreview/references/reviewing-document.md`)의 「## 한 라운드」 절이
# 스크립트를 **배포 경로**(`<플러그인 루트>/scripts/…`)에서 부르라고 명시하는지 잰다
# (Park P10). 실행자가 정본 자리(`shared/docreview/scripts/`)에서 직접 부르면
# `runner_common.sh`·`adjudication` 모듈 같은 형제 파일이 없어 라운드가 죽는다 — 그
# 이유를 절차서 본문이 가르쳐야 T3 이후의 실행자가 두 번 안 걸린다(Task 2 brief).
#
# ── 두 단언과 그 관계 ────────────────────────────────────────────────────
# 1. 존재 — 본문에 「배포 경로에서 부른다」는 지시가 **body-unique** 문구로 있는지
#    본다. 헤더나 목차가 그 문구를 만족시키면 본문을 지워도 GREEN 이 되는 함정이
#    있어(리포에 기록된 실패 유형) 헤더 줄('#' 시작)을 코퍼스에서 통째로 빼고
#    본문만 검사한다 — 이 문서에 목차는 없지만 함정 자체를 구조적으로 막는다.
# 2. 양의 짝 — 절차서가 실제로 스크립트를 **부르는**(인자를 동반한) 줄이 하나
#    이상 있는지 하한으로 잰다. 이게 없으면 1번이 지키는 문단만 남기고 실제 호출
#    줄을 전부 지워도 1번은 계속 GREEN 이다(리터럴 존재만 보고 호출 관례는 안
#    보므로) — 2번이 그 사각을 잡는다. 1번이 더하는 문단은 스크립트 이름을
#    인자 없는 backtick 나열로만 쓰므로 2번의 정규식(이름 뒤 공백+토큰)에 걸리지
#    않는다 — 1번 문단만 지워도 2번은 격리돼 그대로 GREEN 이어야 한다(Step 7).
# 3. init rc 규칙 — 절차서 선결과 두 진입 skill 의 「`init` 이 rc 0 이 아니면 라운드를 진행하지
#    않는다」(아래 절 주석).
# 4. finalize rc 규칙 — 절차서 7단계와 두 진입 skill 의 「`finalize` 가 rc 0 이 아니면 정상 게이트로
#    넘기지 않는다」(아래 절 주석).
# 5. 「미검증」 라벨 · 완료 기록 신호의 출처 — 엔진 출력(`approval_label` · `round_reviewed`). 라벨의
#    정본 상수를 엔진에서 읽어 산문과 대조한다(그래서 이 락은 `docreview_state.py` 도 읽는다).
set -u -o pipefail
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/references/reviewing-document.md"
  echo "plugins/spec-distill/skills/reviewing-spec/SKILL.md"
  echo "plugins/spec-distill/skills/reviewing-brief/SKILL.md"
  echo "shared/docreview/scripts/docreview_state.py"
  exit 0
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"

REF="$REPO_ROOT/shared/docreview/references/reviewing-document.md"

if [ ! -r "$REF" ]; then
  echo "✗ FATAL: $REF 를 읽을 수 없다"
  exit 1
fi

# 헤더(줄이 '#' 로 시작)를 빼고 본문만 남긴다 — body-unique 를 구조적으로 강제한다.
BODY="$(grep -vE '^#' "$REF")"

# ── 1. 존재 — 본문(헤더 제외)에 배포 경로 지시가 있는가 ────────────────────
assert_contains "$BODY" '정본(`shared/docreview/scripts/`)에서 부르면 안 된다' \
  "절차서 본문(헤더 제외)이 배포 경로에서 부르라는 지시를 담는다 (Park P10, body-unique)"

# ── 2. 양의 짝 — 실제 호출 줄이 하나 이상 있는가(하한, 1번과 격리) ─────────
n_calls="$(grep -cE '(docreview_anchor\.py|docreview_state\.py|docreview_route\.py|run_docreview_codex_reviewer\.sh)[[:space:]]+[a-zA-Z-]' "$REF" || true)"
if [ "${n_calls:-0}" -ge 1 ]; then
  ok "절차서가 스크립트를 실제로 부르는 줄을 ${n_calls}개 갖는다 (하한 1, 양의 짝)"
else
  no "절차서에 스크립트 호출 줄이 하나도 없다 — 배포 경로 지시가 가리킬 실행이 사라졌다"
fi

# ── 3. init rc 규칙(Task 2e M3) — 선결 `init` 이 rc 0 이 아니면 라운드를 진행하지 않는다 ──
# 절차서와 두 진입 skill 이 같은 규칙을 산문으로만 적고 락이 없었다. `begin-round` 는 문서를
# 보지 않으므로 거부를 넘어 진행하면 다른 문서의 원장 위에서 라운드가 돈다. 문장이 줄바꿈을
# 넘으므로 헤더 줄을 뺀 본문을 한 줄로 접어 본다(body-unique). 1단계 `begin-round` 의 비슷한
# 규칙(「rc 가 0 이 아니면 값과 무관하게 이 라운드를 진행하지 않는다」)과 갈리도록 주어 `init`
# 을 문구에 넣고, 그 구분이 실제로 서는지를 아래 음성 셀이 잰다.
flat() { grep -vE '^#' "$1" | tr '\n' ' ' | tr -s ' '; }
INIT_RULE_REF='`init` 의 rc 가 0 이 아니면 값과 무관하게 이 라운드를 진행하지 않는다'
INIT_RULE_SKILL='선결의 `init` 이 rc 0 이 아니면 값과 무관하게 이 라운드를 진행하지 않는다'
REF_FLAT="$(flat "$REF")"
assert_contains "$REF_FLAT" "$INIT_RULE_REF" \
  "절차서 선결: init rc≠0 이면 값과 무관하게 라운드를 진행하지 않는다 (body-unique)"
# 양의 짝 — 규칙이 가리키는 호출이 절차서에 실재한다.
assert_contains "$REF_FLAT" 'docreview_state.py init --state-dir' \
  "절차서 선결: 규칙이 가리키는 init 호출이 실재한다 (양의 짝)"
# 구분의 이빨 둘 — 판정 문구가 begin-round 규칙과 공유하는 꼬리(「값과 무관하게 이 라운드를 진행하지
# 않는다」)로 약화되면 둘 다 RED 다. ① 문구가 본문에 정확히 한 번 나온다(공유 꼬리면 두 번). ② 그 한 번을
# 지운 사본에 begin-round 문장이 온전히 남는다(공유 꼬리를 지우면 begin-round 문장까지 잘린다).
n_rule="$(printf '%s' "$REF_FLAT" | python3 -c 'import sys; print(sys.stdin.read().count(sys.argv[1]))' "$INIT_RULE_REF")"
assert_eq "$n_rule" "1" "절차서 init 규칙 문구가 본문에 정확히 한 번 나온다 (begin-round 규칙과 공유하지 않는다)"
NEG_FLAT="$(printf '%s' "$REF_FLAT" | python3 -c 'import sys; print(sys.stdin.read().replace(sys.argv[1], ""))' "$INIT_RULE_REF")"
assert_contains "$NEG_FLAT" '**rc 가 0 이 아니면 값과 무관하게 이 라운드를 진행하지 않는다**' \
  "음성 셀: init 규칙을 지워도 begin-round 규칙은 온전히 남는다 (판정 문구가 init 쪽만 가리킨다)"
for s in reviewing-spec reviewing-brief; do
  SK_FLAT="$(flat "$REPO_ROOT/plugins/spec-distill/skills/$s/SKILL.md")"
  assert_contains "$SK_FLAT" "$INIT_RULE_SKILL" \
    "$s: 선결 init rc≠0 이면 값과 무관하게 라운드를 진행하지 않는다 (body-unique)"
  # 양의 짝 — 규칙이 가리키는 선결의 정본(절차서)을 그 skill 이 실제로 읽는다.
  assert_contains "$SK_FLAT" 'references/reviewing-document.md' \
    "$s: 선결의 정본(절차서)을 읽는다 (양의 짝)"
done

# ── 4. finalize rc 규칙(Task 7b, R51) — 7단계 `finalize` 가 rc 0 이 아니면 정상 게이트로 넘기지 않는다 ──
# 선결 `init` · 1단계 `begin-round` 의 rc 규칙과 같은 모양(「값과 무관하게」)이되 주어가 `finalize` 이고 끝이
# 「진행하지 않는다」가 아니라 「정상 게이트로 넘기지 않는다」다 — 탐지가 이미 돈 뒤라 라운드를 되돌리지 않고
# 엔진이 「미검증」으로 낸 게이트로 닫는다. 규칙 문장만 남고 판정 근거(엔진 신호)가 사라지면 모델 기억으로
# 되돌아가므로 근거 문구도 함께 잰다. 이웃 규칙과 갈리는지는 3 절과 같은 두 이빨로 잰다.
FIN_RULE='`finalize` 의 rc 가 0 이 아니면 값과 무관하게 이 라운드를 정상 게이트로 넘기지 않는다'
assert_contains "$REF_FLAT" "$FIN_RULE" \
  "절차서 7단계: finalize rc≠0 이면 값과 무관하게 정상 게이트로 넘기지 않는다 (body-unique)"
assert_contains "$REF_FLAT" 'docreview_route.py finalize --state-dir' \
  "절차서 7단계: 규칙이 가리키는 finalize 호출이 실재한다 (양의 짝)"
assert_contains "$REF_FLAT" '엔진이 「미검증」으로 낸 게이트다(`unverified: finalize_incomplete`)' \
  "절차서 7단계: 그 라운드의 판정 근거가 엔진 신호다 (모델 기억이 아니다)"
n_fin="$(printf '%s' "$REF_FLAT" | python3 -c 'import sys; print(sys.stdin.read().count(sys.argv[1]))' "$FIN_RULE")"
assert_eq "$n_fin" "1" "절차서 finalize 규칙 문구가 본문에 정확히 한 번 나온다 (이웃 규칙과 공유하지 않는다)"
NEG_FIN="$(printf '%s' "$REF_FLAT" | python3 -c 'import sys; print(sys.stdin.read().replace(sys.argv[1], ""))' "$FIN_RULE")"
assert_contains "$NEG_FIN" "$INIT_RULE_REF" \
  "음성 셀: finalize 규칙을 지워도 선결 init 규칙은 온전히 남는다"
assert_contains "$NEG_FIN" '**rc 가 0 이 아니면 값과 무관하게 이 라운드를 진행하지 않는다**' \
  "음성 셀: finalize 규칙을 지워도 1단계 begin-round 규칙은 온전히 남는다"
assert_contains "$NEG_FLAT" "$FIN_RULE" \
  "음성 셀: init 규칙을 지워도 finalize 규칙은 온전히 남는다 (두 판정 문구가 서로를 품지 않는다)"
for s in reviewing-spec reviewing-brief; do
  SK_FLAT="$(flat "$REPO_ROOT/plugins/spec-distill/skills/$s/SKILL.md")"
  assert_contains "$SK_FLAT" "$FIN_RULE" \
    "$s: finalize rc≠0 이면 값과 무관하게 정상 게이트로 넘기지 않는다 (절차서와 같은 규칙)"
done

# ── 5. 「미검증」 라벨 · 완료 기록 신호의 출처 — 엔진 출력(Task 7b, R51) ──────────────────
# 라벨의 정본은 엔진 상수(`UNVERIFIED_LABEL`)이고 게이트 요약의 `approval_label` 로 나온다. 진입 skill 은 그
# 값을 읽는다 — 모델이 critic 사망 횟수를 기억해 라벨을 붙이던 옛 문면은 다음 턴·compact 뒤에 무너진다.
# 산문의 라벨을 엔진 상수로 짓기 때문에, 상수가 사라지거나 이름이 바뀌면 아래 단언들이 함께 RED 다(양의 짝).
LABEL="$(PYTHONDONTWRITEBYTECODE=1 python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import docreview_state as s; print(s.UNVERIFIED_LABEL)' "$REPO_ROOT/shared/docreview/scripts" 2>/dev/null)"
assert_eq "$LABEL" "미검증" "엔진: 「미검증」 라벨의 정본 상수가 실재한다 (산문 라벨 단언의 양의 짝)"
assert_contains "$REF_FLAT" "\`approval_label\` 이 있으면(「${LABEL}」)" \
  "절차서 8단계: 승인 게이트 라벨을 엔진 요약의 approval_label 에서 읽는다"
assert_contains "$REF_FLAT" '`round_reviewed` 가 참일 때만 남긴다' \
  "절차서 8단계: 리뷰 완료 기록은 엔진 요약의 round_reviewed 가 참일 때만 남긴다"
BR_FLAT="$(flat "$REPO_ROOT/plugins/spec-distill/skills/reviewing-brief/SKILL.md")"
assert_contains "$BR_FLAT" "\`approval_label\` 이 「${LABEL}」이면" \
  "reviewing-brief: 「미검증」 라벨을 엔진 요약의 approval_label 에서 읽는다 (body-unique)"
assert_contains "$BR_FLAT" '그 값을 그대로 Step B 로 넘긴다' \
  "reviewing-brief: 엔진이 낸 그 값을 Step B 로 넘긴다"
assert_not_contains "$BR_FLAT" '**critic 사망이 두 번**이면 승인 게이트를 「미검증」으로 열고' \
  "reviewing-brief: 모델이 사망 횟수를 세어 라벨을 붙이던 옛 문면이 없다 (양의 짝은 위 두 단언)"
# R54(Task 7b fix) — `round_reviewed` 가 거짓인 **모든** 라운드(「미검증」이 아닌 `unrouted` 포함)의 공시 사유도
# 엔진 요약에서 온다. reviewing-brief 는 라벨만 넘기면 `unrouted` 라운드가 라벨 없이 Step B 로 가므로
# `round_reviewed` 를 읽어 그 사실과 사유를 넘긴다.
assert_contains "$REF_FLAT" '거짓인 라운드는 요약의 `unreviewed_reason` 이 사유를 말하고' \
  "절차서 8단계: round_reviewed 가 거짓인 모든 라운드의 공시 사유가 엔진 요약에서 온다"
assert_contains "$BR_FLAT" '`round_reviewed` 가 거짓이면(사유 `unreviewed_reason`' \
  "reviewing-brief: 리뷰 완료 여부를 엔진 요약의 round_reviewed 에서 읽는다 (body-unique)"
assert_contains "$BR_FLAT" '라벨이 없어도 그 사실과 사유를 그대로 Step B 로 넘긴다' \
  "reviewing-brief: 라벨이 없는 라운드도 그 사실과 사유를 Step B 로 넘긴다"
# M3 — Step B 넘김 절의 출처 문구. 절 창(다음 `## ` 에서 닫힘)으로 재서 다른 절로 옮기면 RED 다.
BR_STEPB="$(awk '/^## Step B 로 돌아간다/{f=1; next} f && /^## /{f=0} f' "$REPO_ROOT/plugins/spec-distill/skills/reviewing-brief/SKILL.md" | tr '\n' ' ' | tr -s ' ')"
assert_grep "$(cat "$REPO_ROOT/plugins/spec-distill/skills/reviewing-brief/SKILL.md")" '^## Step B 로 돌아간다$' \
  "양의 짝 — reviewing-brief 에 Step B 넘김 절이 실재한다 (아래 두 창 단언이 절 삭제로 헛통과하지 않는다)"
assert_contains "$BR_STEPB" '「미검증」은 마지막 요약의 `approval_label` 과 사유 `unverified` 그대로' \
  "reviewing-brief Step B 절: 「미검증」 사유의 출처가 마지막 요약이다 (body-unique)"
assert_contains "$BR_STEPB" '리뷰 완료 여부(마지막 요약의 `round_reviewed`' \
  "reviewing-brief Step B 절: 리뷰 완료 여부의 출처가 마지막 요약이다"
SP_FLAT="$(flat "$REPO_ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md")"
assert_contains "$SP_FLAT" "\`approval_label\` 이 「${LABEL}」이면 승인 게이트를 그 라벨로 연다" \
  "reviewing-spec ## 게이트: 「미검증」 라벨을 엔진 요약의 approval_label 에서 읽는다"

finish
