#!/usr/bin/env bash
# V7 — stale-term 회귀 락. rename 완결을 **production artifacts**에서 확인한다.
# (a) breadth-keeper → coverage-mapper 재명명이 production에 완결(잔존 0).
# (b) interview_round는 활성 코드서 제거, SKILL은 migration 섹션에만.
# (c) v0.23.0 권위 문법 6개 리터럴이 production에서 제거됐다(AC13). README.md도 스코프 안 —
#     제외했던 근거("Principles Instantiated가 무엇이 왜 사라졌는지 설명하려면 옛 용어를
#     인용해야 한다")는 검증 가능한 예측이었고 실패했다: v0.23.0 README는 이 6개 리터럴을
#     grep -cF로 **0건** 인용한다. CHANGELOG.md는 실제로 4건 인용하므로(released 기록) 그
#     제외만 유효하다.
# 스코프: $SD 아래 전체 production 파일 — 확장자 whitelist 없이 sweep(SKILL.md/README.md/agents/
#         templates/scripts/plugin.json 뿐 아니라 scripts/ambiguity-blacklist.txt 같은 .txt/.yaml/
#         확장자없는 production 파일도 포함). 확장자 whitelist는 header 주장(scripts/ 커버)보다
#         좁아지는 grep-lock header-satisfiable 함정이라 폐기했다.
#         리포 루트의 docs/는 $SD 밖이라 자동으로 스코프 밖 — 중복 필터를 두지 않는다.
# 제외: (1) CHANGELOG.md(released 기록 + 이 rename을 서술하는 [0.22.0] 엔트리 — Keep-a-Changelog 불변),
#       (2) tests/(락·stage test가 토큰을 *집행/assert*하는 층 — stale ref면 그 테스트가 자체 fail),
#       (3) .pytest_cache/·__pycache__/·.git/(캐시·바이너리, production 아님),
#       (4) .claude/ — 플러그인 디렉토리 아래 .claude/는 **툴링이 쓰는 세션 상태**이지 플러그인이
#           출하하는 artifact가 아니다(quality-gates 세션 파일 등, git-untracked). 아무도 작성하지
#           않은 일시 파일이 락을 빨갛게 만들 수 있으면 사람들이 락을 무시하도록 훈련된다.
#           패턴은 **$SD 기준으로 앵커**한다('*/.claude/*'는 앵커가 없어, 하니스 워크트리가
#           <repo>/.claude/worktrees/<name>/ 아래 사는 순간 production 전량을 삼켰다 — 락이
#           워크트리에서 실행 불가였다). .claude-plugin/은 이름이 달라 여전히 제외되지 않는다.
#       테스트의 토큰 참조는 제거를 강제하는 enforcement 층이지 stale 참조가 아니다.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
SKILL="$SD/skills/conducting-interview/SKILL.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# grep은 세 결과를 구분한다: 0=매치(금지어 발견), 1=매치 없음(정상), >=2=grep 자체 실패
# (읽을 수 없는 파일·잘못된 인자 등). `|| true`로 상태를 삼키면 >=2가 1과 뭉뚱그려져
# **검사가 실행되지 않았는데 PASS**가 된다 — fail-closed가 존재 이유인 락에서 최악의 fail-open.
# 그래서 상태를 명시 포착하고(이 스크립트는 set -e를 쓰지 않으므로 안전) 호출자가 3-way로 분기한다.
# stderr를 2>/dev/null로 버리지 않고 캡처하는 이유: >=2일 때 원인 메시지가 유일한 단서다.
SCAN_OUT=""; SCAN_RC=0
scan() { SCAN_OUT="$(grep "$@" 2>&1)"; SCAN_RC=$?; }

# production artifact 파일 집합 — tests/·CHANGELOG.md·.claude/·cache/binary 제외,
# **확장자 whitelist 없이 전체**.
# (whitelist는 scripts/ambiguity-blacklist.txt 같은 .txt production 파일을 놓쳐 lock이 자기 헤더 주장보다
#  좁아진다 — grep-lock header-satisfiable 함정. grep -I로 binary는 스킵.)
# .claude/ 제외는 V7a·V7b·V8이 **함께** 쓰는 이 find 한 곳에 둔다 — 한 검사에만 걸면
# 검사별 스코프가 갈려 헤더 주장이 다시 거짓이 된다.
prod_files=()
while IFS= read -r f; do prod_files+=("$f"); done < <(
  find "$SD" -type f \
    -not -path '*/tests/*' -not -name 'CHANGELOG.md' \
    -not -path "$SD/.claude/*" \
    -not -path '*/.pytest_cache/*' -not -path '*/__pycache__/*' -not -path '*/.git/*'
)
# macOS bash 3.2: 빈 배열에 "${arr[@]}" 확장은 set -u 하에서 crash — 명시 guard(빈 집합=find 깨짐=FAIL).
if [[ ${#prod_files[@]} -eq 0 ]]; then
  no "V7: no production files found — find filter broken"
  echo; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1
fi

# V7a: breadth-keeper production 잔존 0
scan -InE 'breadth-keeper|breadth_keeper|Breadth-Keeper' "${prod_files[@]}"
if [[ $SCAN_RC -ge 2 ]]; then
  no "V7a: grep 자체 실패(exit=$SCAN_RC) — 검사가 실행되지 않았다:"; printf '%s\n' "$SCAN_OUT"
elif [[ $SCAN_RC -eq 0 ]]; then
  no "V7a: stale breadth-keeper in production:"; printf '%s\n' "$SCAN_OUT"
else
  ok "V7a: no breadth-keeper in production artifacts"
fi

# V7b-1: SKILL.md interview_round는 migration 섹션에만
mig="$(awk '/^## In-flight state migration/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
all_ir=$(grep -c interview_round "$SKILL" 2>/dev/null || true)
mig_ir=$(printf '%s\n' "$mig" | grep -c interview_round 2>/dev/null || true)
{ [[ "$all_ir" -ge 1 ]] && [[ "$all_ir" -eq "$mig_ir" ]]; } \
  && ok "V7b: interview_round in SKILL confined to migration ($all_ir)" \
  || no "V7b: interview_round leaks outside SKILL migration (total=$all_ir mig=$mig_ir)"

# V7b-2: interview_round production(SKILL 제외) 잔존 0
# 파일별 루프라 grep 실패도 파일별로 모은다 — 한 파일이 안 읽히면 그 파일은 검사되지 않은 것이므로
# "매치 없음"으로 넘기지 않고 err 버킷에 쌓아 FAIL로 만든다.
ir=""; ir_err=""
for f in "${prod_files[@]}"; do
  [[ "$f" == "$SKILL" ]] && continue
  scan -InH interview_round "$f"
  if [[ $SCAN_RC -ge 2 ]]; then ir_err+="$SCAN_OUT"$'\n'
  elif [[ $SCAN_RC -eq 0 ]]; then ir+="$SCAN_OUT"$'\n'
  fi
done
if [[ -n "$ir_err" ]]; then
  no "V7b: grep 자체 실패 — 아래 파일은 검사되지 않았다:"; printf '%s\n' "$ir_err"
elif [[ -z "$ir" ]]; then
  ok "V7b: no interview_round in production outside SKILL migration"
else
  no "V7b: interview_round in unexpected production files:"; printf '%s\n' "$ir"
fi

# --- V8 (AC13): v0.23.0 권위 문법 6개 리터럴 회귀 락 ---
# 스코프 = prod_files 그대로(README.md 포함) — AC13이 production 전체를 요구한다.
# prod_files는 위에서 이미 비어있지 않음이 확인됐으므로 별도 empty-guard는 불필요하다.
# 배열 리터럴 + "${arr[@]}" 확장으로만 다룬다 — 6개 중 3개가 공백을 품은 구(句)라
# 단일 문자열 word-split은 그것들을 조용히 쪼갠다. 각 원소는 quote된 채 grep에 그대로 간다.
# 매칭은 반드시 -F(고정 문자열): 한국어 조사·markdown 백틱이 regex 경계를 소리 없이
# 깨뜨린 전례가 있다(Task 7). '·'는 metachar가 아니지만 -F면 그 판단 자체가 불필요해진다.
authority_terms=(
  'locked_directions'
  'pending_locked_decisions'
  '재논쟁 금지'
  'Locked Directions'
  '다시 묻지 않는다'
  '확정·재논쟁'
)
for term in "${authority_terms[@]}"; do
  scan -InIF -- "$term" "${prod_files[@]}"
  if [[ $SCAN_RC -ge 2 ]]; then
    no "V8/AC13: '$term' 검사가 실행되지 않았다 — grep 자체 실패(exit=$SCAN_RC):"
    printf '%s\n' "$SCAN_OUT"
  elif [[ $SCAN_RC -eq 0 ]]; then
    no "V8/AC13: '$term' 가 production에 잔존:"; printf '%s\n' "$SCAN_OUT"
  else
    ok "V8/AC13: '$term' 잔존 0건 (production)"
  fi
done

# --- V9 (v0.25.0 / T4): arm-once 삭제 스윕 완결 락 ---
# 스코프 = prod_files 그대로(README.md 포함, tests/·CHANGELOG.md 제외).
# 식별자만이 아니라 **같은 것을 다른 이름으로 부른 참조**까지 열거한다 — 식별자만
# grep하면 개념 별칭으로 살아남은 참조를 놓친다.
# CHANGELOG.md 제외는 released 기록이라 유효하다(이 삭제를 서술하는 [0.25.0] 엔트리가
# 이 리터럴들을 인용해야 한다). tests/ 제외는 이 파일 자신이 토큰을 *집행*하는 층이기
# 때문이다 — 배열 리터럴이 매치를 자기 자신에게서 찾으면 락이 영구 RED가 된다.
removed_terms=(
  'review_lock'
  'review_in_progress'
  'suppress_state'
  'suppressed_paths'
  'cancel_review'
  'cancel-review'
  'approve_handoff'
  'DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC'
  # 되살아나면 안 되는 marker 하니스 계열(전 test_handoff_compact_chain.sh 가 잠그던
  # 토큰). 현재 잔존 0건이며, 이 항목들은 *부재*를 잠근다 — 사건 기록이 아니다.
  'FIRE_COUNT'
  'compact-induction'
  'compact-detect'
)

# 개념 별칭 — 식별자만 grep 하면 **같은 것을 다른 이름으로 부른 참조**가 살아남는다.
# 근거는 실적이다: 식별자 'review_lock' 만 열거했을 때 살아남았던 생존자 두 건이
#   hooks/state_path.py — "keys the review lock to the SAME state file" (공백 표기)
#   skills/reviewing-spec/SKILL.md — "락이 훅에 보인다" (한국어)
# 였고, 영어 식별자 grep 은 어느 쪽에도 닿지 못했다. 세 번째 항목 'suppressed path' 는
# 위 두 건 같은 실적이 없는 **예방적 별칭**이다 — 같은 문단이 근거를 대는 척하면 안 되므로
# 여기서 구분해 적는다.
#
# 이 그룹은 **README.md 를 제외한** production 만 훑는다.
#
# 이유: 위 헤더가 선언한 "살아있는 주장만" 기준을 이 항목들이 지키지 못한다.
# 'review lock'·'suppressed path' 는 삭제를 정직하게 서술하는 문장에도 그대로 들어간다
# ("the review lock added in v0.18.0 was removed in v0.25.0"). 그리고 이 플러그인이
# 자기 삭제 연혁을 적는 곳이 정확히 README.md 다(README:50-62 가 이미 그 문체다).
# 측정으로 확인됐다 — 현실적 릴리스 노트 문장을 README 에 붙이면 이 항목들이 발화한다.
# 락이 정직한 문서 작성에 RED 를 내면 사람들은 락을 무시하게 된다.
#
# 커버리지는 줄지 않는다: 이 별칭들이 잡아낸 **실제 생존자 두 건**은 README 가 아니라
# hooks/state_path.py 와 skills/reviewing-spec/SKILL.md 였다. README 만 면제하면
# 위양성 표면은 사라지고 실적은 그대로 남는다.
alias_terms=(
  'review lock'
  'suppressed path'
  '락이 훅에'
)
alias_files=()
for f in "${prod_files[@]}"; do
  [[ "$(basename "$f")" == "README.md" ]] || alias_files+=("$f")
done

# `-i` 를 붙인다. 기존 `-InIF` 는 `-I -n -I -F` 로 대문자 I 가 두 번 들어간 것이고
# `-i` 는 없었다 — 즉 대소문자를 구분했다. 되살아난 개념이 가장 먼저 자리잡는 곳은
# `### Review Lock` 같은 헤딩인데 그게 통째로 빠져나갔다.
for term in "${removed_terms[@]}"; do
  scan -inIF -- "$term" "${prod_files[@]}"
  if [[ $SCAN_RC -ge 2 ]]; then
    no "V9/T4: '$term' 검사가 실행되지 않았다 — grep 자체 실패(exit=$SCAN_RC):"
    printf '%s\n' "$SCAN_OUT"
  elif [[ $SCAN_RC -eq 0 ]]; then
    no "V9/T4: '$term' 가 production에 잔존:"; printf '%s\n' "$SCAN_OUT"
  else
    ok "V9/T4: '$term' 잔존 0건 (production)"
  fi
done
for term in "${alias_terms[@]}"; do
  scan -inIF -- "$term" "${alias_files[@]}"
  if [[ $SCAN_RC -ge 2 ]]; then
    no "V9/T4: 별칭 '$term' 검사가 실행되지 않았다 — grep 자체 실패(exit=$SCAN_RC):"
    printf '%s\n' "$SCAN_OUT"
  elif [[ $SCAN_RC -eq 0 ]]; then
    no "V9/T4: 별칭 '$term' 가 production에 잔존:"; printf '%s\n' "$SCAN_OUT"
  else
    ok "V9/T4: 별칭 '$term' 잔존 0건 (README 제외 production)"
  fi
done

# --- V10 (v0.25.0 / T5): 삭제 대상 파일 부재 ---
# 파일이 되살아나면 무참조 상태로 조용히 눌러앉는다 — 참조 스윕(V9)만으로는 못 잡는다.
removed_files=(
  'scripts/review_lock.py'
  'scripts/cancel_review.py'
  'scripts/approve_handoff.sh'
  'scripts/suppress_state.py'
  'commands/cancel-review.md'
  'tests/test_review_lock.py'
  'tests/test_review_lock_session_id.sh'
  'tests/test_reviewing_spec_lock.sh'   # Task 7 에서 test_reviewing_spec_state_keying.sh 로 개명
  'tests/test_cancel_review.py'
  'tests/test_approve_handoff.sh'
  'tests/test_handoff_compact_chain.sh'
  'tests/test_handoff_spec_path_validation.sh'
  # 전 test_handoff_compact_chain.sh 가 이 두 훅의 부재를 잠그고 있었다 — 그 락이
  # 승계 없이 삭제돼, 되살아나도 아무것도 잡지 못하는 상태였다.
  'hooks/compact-induction.py'
  'hooks/compact-detect.py'
)
for rf in "${removed_files[@]}"; do
  [[ ! -e "$SD/$rf" ]] \
    && ok "V10/T5: '$rf' 부재" \
    || no "V10/T5: '$rf' 가 되살아났다"
done

# --- V11 (v0.25.0): 대체 surface 가 실재한다 (음의 락만 두면 전부 지워도 통과) ---
# 두 conjunct는 "대체 machinery가 진짜로 있다"는 하나의 주장을 나눠 진다 — 어느 한쪽만으로는
# 부족하다. (1) 파일 존재만 보면 빈 파일도 통과하므로 arm_ledger.py가 should_arm을 **정의**
# 하는지(`^def should_arm(`)까지 확인한다. (2) 'should_arm'이라는 bare 토큰 존재만 grep하면
# 세 가지 거짓양성을 놓친다 — 주석(`# should_arm 대신 항상 arm`), neutered 호출(반환값을
# 버리는 `arm_ledger.should_arm(...)` 단독 문장), 스텁화된 정의(`should_arm` 이 항상 True를
# 반환). 앞의 둘은 호출부가 **소비 위치**(`if (not )?arm_ledger\.should_arm\(`)에 있는지로
# 잡는다 — 반환값이 실제로 control flow를 가른다는 증거. 스텁화는 이 락의 범위 밖이다(함수
# 본문 의미는 grep으로 못 잡는다 — T-lock류의 한계와 같은 이유).
scan -InE -- '^def should_arm\(' "$SD/scripts/arm_ledger.py"
[[ $SCAN_RC -eq 0 ]] \
  && ok "V11: arm_ledger.py 가 should_arm 을 정의한다" \
  || no "V11: arm_ledger.py 에 should_arm 정의가 없다 (파일 부재 포함 — 대체 machinery 없음)"
scan -InE -- 'if (not )?arm_ledger\.should_arm\(' "$SD/hooks/spec-write-validator.py"
[[ $SCAN_RC -eq 0 ]] \
  && ok "V11: validator 가 should_arm 을 소비 위치(if)에서 부른다" \
  || no "V11: validator 의 should_arm 호출이 소비 위치에 없다 (주석/neutered 호출 의심 — 게이트 증발)"
finish
