#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/*/SKILL.md plugins/spec-distill/skills/*/references/*.md
#
# proceed 게이트 **공통 계약의 채택자 대칭** — `references/proceed-gate.md` 를 채택한
# 모든 skill 이 **자기 표면에** 기계적 검증 앵커를 갖는가.
#
# ── 왜 새 파일인가 (Task 33 fix round 2) ────────────────────────────────────
# 정본 `proceed-gate.md` 의 「검증」 절은 *"**각 skill 표면에** 정지 어휘가 실재하는지를
# grep 이 잰다"* 고 주장하고, `reviewing-spec/SKILL.md` 의 AC19 불릿은 한 걸음 더 나가
# *"기계적 검증 앵커가 거기 산다"* 고 적는다. **둘 다 거짓이었다** 〔실측〕: `턴 종료|다음 턴`
# 을 재는 단언은 리포 전체에 둘뿐이고(`test_conducting_interview_stage.sh` 의 `ci_cat`,
# `test_brief_review_entry.sh` 의 `CI_FILES`) 둘 다 conducting-interview 표면만 본다.
# `reviewing-spec` 의 정지 어휘는 **아무도 재지 않았다** — 계약을 통일해 놓고 그 계약의
# 이행 검증은 한쪽에만 있었던 셈이다.
#
# 그 자리를 기존 `reviewing-spec` 테스트 중 하나에 끼워 넣지 **않은** 이유: 그러면 같은
# 검사가 두 벌 독립 저술되고(interview 쪽 하나 + reviewing-spec 쪽 하나) 스코프 규칙이
# 서로 다른 채로 자유롭게 갈라진다 — **이 결함을 만든 바로 그 구조**다. Task 33 의 산출물이
# "두 게이트가 한 계약을 공유한다"이므로, 그 계약의 이행 검증도 하나여야 하고 대상은
# **열거가 아니라 도출**이어야 한다. 아래는 채택자를 포인터에서 도출한다 — 세 번째 skill 이
# 정본을 채택하면 자동으로 같은 요구를 받는다.
#
# interview 쪽은 자기 stage 테스트에도 같은 단언이 있다(AC21(i)/AC22). 중복이지만 출처가
# 다르다 — 그쪽은 *그 stage 의 계약*을, 여기는 *공유 계약의 채택자 대칭*을 잰다. 어느 한쪽이
# 지워져도 다른 쪽이 남는 defense-in-depth 이며, 둘 다 아래와 같은 스코프 규칙을 따른다.
#
# ── 코퍼스 스코프 (F1 위험이 여기에도 그대로 적용된다) ──────────────────────
# **정본 `plugins/spec-distill/references/proceed-gate.md` 를 코퍼스에 넣지 말 것.**
# 그 파일은 계약을 서술하느라 앵커 리터럴(`턴 종료` · `다음 턴` · `polite stop`)을 **그대로
# 담고 있다**. 코퍼스에 들어오면 아래 단언은 정본 하나로 만족되고, 채택 skill 이 자기 옵션 ①
# 문구를 통째로 잃어도 GREEN 이 된다. 각 채택자의 표면은 **그 skill 이 소유한 파일**
# (`skills/<s>/SKILL.md` + `skills/<s>/references/*.md`)로만 구성한다.
#
# "코퍼스를 넓혀 도출로 바꾸라"는 처방(감사문서 §3)은 **부재** 검사의 것이다. 아래는 전부
# **존재** 검사이므로 그 처방을 적용하면 이빨이 0 이 된다(감사문서 §8). 아래 구조적 가드가
# 그 편집을 막는다.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
CANON="$SD/references/proceed-gate.md"
CANON_REF='references/proceed-gate\.md'

. "$REPO_ROOT/shared/tests/assert.sh"
. "$REPO_ROOT/shared/tests/presence_corpus.sh"

# `--emit-scanned` — test_guards_coverage_bidirectional.sh 가 읽는다. 실제로 훑는 것은
# 채택자들의 표면뿐이다(정본은 스캔하지 않는다 — 위 스코프 규칙).
emit_only=0
[ "${1:-}" = "--emit-scanned" ] && emit_only=1

[ -f "$CANON" ] || { [ "$emit_only" -eq 1 ] && exit 0
  no "정본 $CANON 부재 — 채택자 대칭을 잴 대상이 없다"; finish; exit $?; }

# ── 채택자 도출 ─────────────────────────────────────────────────────────────
# "정본을 가리키는 포인터가 그 skill 표면 어딘가에 있는가." reviewing-spec 은 SKILL.md 에서,
# conducting-interview 는 references/finishing.md 에서 가리킨다 — 그래서 둘 다 본다.
adopters=""
scanned=""
for skill_dir in "$SD"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  surface=""
  for f in "$skill_dir"SKILL.md "$skill_dir"references/*.md; do
    [ -f "$f" ] || continue
    surface="$surface$f
"
  done
  [ -n "$surface" ] || continue
  hit=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -qE -- "$CANON_REF" "$f" && { hit=1; break; }
  done < <(printf '%s' "$surface")
  if [ "$hit" -eq 1 ]; then
    adopters="$adopters${skill_dir%/}
"
    scanned="$scanned$surface"
  fi
done

if [ "$emit_only" -eq 1 ]; then
  printf '%s' "$scanned" | sed "s|^$REPO_ROOT/||"
  exit 0
fi

n_adopt=0
while IFS= read -r a; do [ -n "$a" ] && n_adopt=$((n_adopt + 1)); done < <(printf '%s' "$adopters")
# 하한이 1 이 아니라 **2** 인 이유: 이 파일이 플러그인 레벨에 사는 근거가 "두 skill 이
# 공유한다"이기 때문이다(Task 33). 채택자가 1 로 떨어지면 그것은 정상 상태가 아니라
# **한쪽이 조용히 이탈했다**는 뜻이고, 이탈한 skill 은 그 순간 이 스위트의 측정 밖으로
# 나간다 — 코퍼스 축소가 vacuity 검사(≥1)를 통과해 버리는 바로 그 모양이다. 채택자가
# 정말 하나뿐이라면 공유 파일일 이유가 없으므로 그 skill 밑으로 옮겨야 한다.
# 기대값을 숫자로 박는 것이 아니라 **파일의 배치 근거**에서 도출한 하한이다.
if [ "$n_adopt" -lt 2 ]; then
  no "채택자 도출 ${n_adopt}개 — 플러그인 레벨 공유 계약인데 채택자가 2 미만이다. 한쪽이 조용히 포인터를 잃었거나(그 skill 이 측정 밖으로 나간다), 애초에 공유가 아니라면 정본을 그 skill 밑으로 옮겨야 한다"
  finish; exit $?
fi
ok "채택자 도출 ${n_adopt}개 (열거 아님 — 정본 포인터에서 도출, 공유 하한 2 충족)"

# ── 이 도출이 재지 **못하는** 것 (알려진 채, 의도적으로 남긴다) ─────────────
#
# 1. **하한은 개수(cardinality)이지 구성원(membership)이 아니다.** 진짜 채택자가 포인터를
#    잃고 같은 변경에서 **다른 skill 이 포인터를 얻으면** `n_adopt` 는 2 그대로다. 오늘
#    그 치환이 RED 가 나는 것은 **우연**이다 — 유일한 대체 후보 `reviewing-brief/SKILL.md`
#    가 `턴 종료|다음 턴` 을 0줄 갖고 있어 아래 가드 2 단언이 대신 발화한다. 구성원을 못
#    박으려면 이름을 열거해야 하는데, 그것은 이 설계가 일부러 피한 바로 그 열거다
#    (열거는 세 번째 채택자를 자동으로 못 삼킨다). 개수 하한 + 채택자별 앵커 단언의
#    조합으로 남긴다.
# 2. **도출은 리터럴 등장을 셀 뿐 "의도"를 못 읽는다.** skill 표면 어디든
#    `references/proceed-gate.md` 라는 문자열이 있으면 채택자로 등록된다 — HTML 주석 안이든
#    "이렇게 쓰지 말 것" 예시든 마찬가지다. 그 경우 그 skill 은 채택하지도 않은 계약의
#    앵커를 요구받아 **거짓 RED** 를 얻는다. fail-closed 방향이고 시끄러우므로 남긴다.

# ── 구조적 가드 ① 모양: 스캔 대상은 채택 skill 소유 파일뿐 (공용 단언) ──────
# 정본(또는 다른 플러그인 레벨 공유 파일)이 여기 섞이면 아래 존재 단언이 그 파일 하나로
# 만족된다. 그 편집은 그럴듯하므로(부재 락의 처방과 모양이 같다) 주석이 아니라 가드로 막는다.
SCANNED_ARR=()
while IFS= read -r f; do
  [ -n "$f" ] && SCANNED_ARR+=("$f")
done < <(printf '%s' "$scanned")
assert_presence_corpus_skill_owned "채택자 표면" "${SCANNED_ARR[@]+"${SCANNED_ARR[@]}"}"

# 정본이 정말 코퍼스 밖인지 이름으로 한 번 더 확인한다 — 위 case 는 *모양*을 보고, 이것은
# *그 파일*을 본다. 정본이 언젠가 skills/ 아래로 옮겨지면 모양 검사만으로는 못 잡는다.
if printf '%s' "$scanned" | grep -qxF -- "$CANON"; then
  no "코퍼스: 정본($CANON)이 스캔 대상에 들어 있다 — 앵커 리터럴을 담은 파일이라 단언이 그것으로 만족된다"
else
  ok "코퍼스: 정본이 스캔 대상에 없다 (자기 만족 불가)"
fi

# ── 채택자마다: 자기 표면에 기계적 앵커가 실재하는가 ───────────────────────
while IFS= read -r skill_dir; do
  [ -n "$skill_dir" ] || continue
  name="$(basename -- "$skill_dir")"
  files=()
  for f in "$skill_dir/SKILL.md" "$skill_dir"/references/*.md; do
    [ -f "$f" ] && files+=("$f")
  done
  if [ "${#files[@]}" -lt 1 ]; then
    no "$name: 표면 파일 0건 — 도출이 깨졌다"
    continue
  fi

  # 가드 2(AC19) 기계적 레이어: 옵션 ① 의 정지 어휘.
  cc="$(cat "${files[@]}" | grep -cE '턴 종료|다음 턴')"
  [ "$cc" -ge 1 ] \
    && ok "$name: 가드 2 기계적 앵커(정지 어휘) 실재 — ${cc}줄 (자기 표면 ${#files[@]}파일)" \
    || no "$name: 가드 2 기계적 앵커(턴 종료 / 다음 턴)가 자기 표면에 없다 — 정본에 있는 같은 어휘는 계약 서술이지 이 skill 의 앵커가 아니다"

  # 가드 1(AP2): polite stop 금지가 이 skill 어휘로 성립하는가.
  pc="$(cat "${files[@]}" | grep -ciF 'polite stop')"
  [ "$pc" -ge 1 ] \
    && ok "$name: 가드 1 앵커(polite stop 금지) 실재 — ${pc}줄" \
    || no "$name: 가드 1 앵커(polite stop)가 자기 표면에 없다"

  # Step B 의무: 자기 **degrade 채널**을 이름으로 댔는가.
  #
  # 재는 것은 **라벨 있는 절의 존재**이지 채널의 *형태*가 아니다. 형태는 채택자마다 다르고
  # (`brief_review_degradations` 원장 vs `merge_review` 플래그 + `advisory:`) 둘로 일반화하면
  # 둘에 과적합한 정규식이 된다 — 그 검증은 세 번째 채택자가 나와야 형태가 생긴다(감사문서
  # 「이월된 미해결 항목」의 degrade 채널 항목). 여기서 잡는 것은 정확히 하나, 계약이 두려워한
  # 실패다: 새 채택자가 이 의무를 **해당 없음으로 넘기는 것**. 그때 이 줄이 RED 다.
  dc="$(cat "${files[@]}" | grep -cF 'degrade 채널')"
  [ "$dc" -ge 1 ] \
    && ok "$name: Step B degrade 채널을 이름으로 댔다 — ${dc}줄" \
    || no "$name: Step B 가 요구하는 degrade 채널 절이 자기 표면에 없다 — 채널이 없다는 사실 자체가 degrade 이므로 '해당 없음'으로 넘길 수 없다"
done < <(printf '%s' "$adopters")

finish
