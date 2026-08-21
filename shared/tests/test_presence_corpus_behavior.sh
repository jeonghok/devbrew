#!/usr/bin/env bash
# guards: shared/tests/** plugins/spec-distill/tests/*.sh
#
# `presence_corpus.sh` 헬퍼의 **행동**을 고정한다 — 그리고 그것을 쓰는 세 락이 실제로
# 그것을 통해 이빨을 갖는지까지 잰다.
#
# 왜 필요한가 (Task 33 fix round 5): fix round 4 가 24줄 중복을 지우면서 세 락
# (`test_conducting_interview_stage.sh` · `test_brief_review_entry.sh` ·
# `test_proceed_gate_adopters.sh`)의 presence 코퍼스 가드를 이 헬퍼 **한 파일**로 모았다.
# 이빨이 한 곳에 모이면 그 한 곳이 조용히 무력화될 때 **세 락이 동시에** 이빨을 잃는다.
# 헬퍼는 라이브러리라 `# guards:` 도 `--emit-scanned` 도 없다 — `assert.sh` 와 같은
# 상황이고, 이 리포는 그것을 `test_assert_behavior.sh` 로 답했다. 이 파일이 그 짝이다.
#
# 호출 수로는 부족하다(`test_assert_behavior.sh` 헤더와 같은 이유): 분류기의 판정을
# 반전시켜도 "세 소비자가 헬퍼를 부른다"는 사실은 불변이다. 그래서 여기서는
#  (1) 분류기의 **판정**을 rc 로 직접 관측하고(픽스처 probe),
#  (2) 세 소비자를 **실제로 돌려** 헬퍼의 판정 줄이 나오는지와 코퍼스 크기를 읽고,
#  (3) 채택자 락의 **격리 불변식**(각 채택자는 자기 파일만 본다)을 산술로 잰다.
#
# (2)·(3)은 fix round 4 에서 **한 번 손으로 돌린 통제**다 — 매 실행마다 돌게 여기 옮겼다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

# `# guards:` 선언의 짝. 이 파일이 실제로 읽는 것: 헬퍼 하나 + 그것을 쓰는 소비자 셋
# (소비자를 실행해 출력을 판정하므로 진짜 의존이다 — 소비자가 헬퍼 호출을 잃으면 이
# 락이 발화해야 한다). 빈 출력으로 답하면 bidirectional 락이 "미지원"으로 분류해
# 선언이 검증되지 않은 채 남는다(test_assert_behavior.sh:20 관례).
CONSUMERS="plugins/spec-distill/tests/test_conducting_interview_stage.sh
plugins/spec-distill/tests/test_brief_review_entry.sh
plugins/spec-distill/tests/test_proceed_gate_adopters.sh"
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/tests/presence_corpus.sh"
  printf '%s\n' "$CONSUMERS"
  exit 0
fi

pass=0; fail=0
t_ok() { pass=$((pass+1)); echo "  ✓ $1"; }
t_no() { fail=$((fail+1)); echo "  ✗ $1"; }
TMP="$(mktemp -d -t presence-behav-XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT

# 픽스처 probe — 헬퍼를 그 자리(리포 원래 경로)에서 source 해 호출하고 rc 를 돌려준다.
# rc 로 재는 이유: ok()/no() 가 같은 접두로 찍히므로 메시지만으로는 **판정 반전**을
# 구별할 수 없다(test_assert_behavior.sh C1 과 같은 논리).
probe() {   # $1.. = 코퍼스 파일 경로들 (0개도 가능)
  {
    echo '#!/usr/bin/env bash'
    echo 'set -u'
    echo ". \"$HERE/assert.sh\""
    echo ". \"$HERE/presence_corpus.sh\""
    printf 'assert_presence_corpus_skill_owned "PROBE"'
    for a in "$@"; do printf ' %s' "\"$a\""; done
    printf '\n'
    echo 'finish'
  } > "$TMP/probe.sh"
  bash "$TMP/probe.sh" 2>&1
}

echo "=== (1) 분류기의 판정 ==="

# skill 소유 두 모양은 통과해야 한다. 이것이 없으면 아래 거절 검사들이 "항상 실패"
# 헬퍼와 구별되지 않는다(양의 짝).
probe "plugins/p/skills/s/SKILL.md" >/dev/null 2>&1
[ $? -eq 0 ] && t_ok "분류: skills/<s>/SKILL.md 는 소유로 통과" \
             || t_no "분류: skills/<s>/SKILL.md 를 거절한다 — 항상-실패 헬퍼"
probe "plugins/p/skills/s/references/x.md" >/dev/null 2>&1
[ $? -eq 0 ] && t_ok "분류: skills/<s>/references/*.md 는 소유로 통과" \
             || t_no "분류: skills/<s>/references/*.md 를 거절한다"

# ★ load-bearing: **플러그인 레벨 공유 계약**은 코퍼스에 들어오면 안 된다. 그 파일은
# 계약을 서술하느라 각 skill 의 앵커 어휘를 그대로 담고 있어, 코퍼스에 들어오는 순간
# 세 락이 전부 "그 파일 하나로" 만족된다. 대상은 열거하지 않고 git 에서 **도출**한다.
n_canon=0
while IFS= read -r c; do
  [ -n "$c" ] || continue
  case "$c" in */skills/*/references/*) continue ;; esac   # skill 레벨은 소유가 맞다
  n_canon=$((n_canon + 1))
  probe "$c" >/dev/null 2>&1
  [ $? -ne 0 ] && t_ok "분류: 플러그인 레벨 공유 계약 거절 — $c" \
               || t_no "분류: 플러그인 레벨 공유 계약을 소유로 통과시킨다 ($c) — 세 락이 이 파일 하나로 만족된다"
done < <(cd "$ROOT" && git ls-files -- 'plugins/*/references/*.md')
[ "$n_canon" -ge 1 ] \
  && t_ok "도출: 플러그인 레벨 공유 계약 ${n_canon}건을 실제로 검사했다 (vacuous 아님)" \
  || t_no "도출: 플러그인 레벨 공유 계약을 0건 도출 — 위 거절 검사가 한 번도 안 돌았다"

# 섞인 코퍼스: 소유 파일이 있어도 **한 건이라도** 소유 밖이면 실패해야 한다. 이것이
# 없으면 "아무 소유 파일 하나만 있으면 통과"하는 판본과 구별되지 않는다.
probe "plugins/p/skills/s/SKILL.md" "plugins/p/references/shared.md" >/dev/null 2>&1
[ $? -ne 0 ] && t_ok "분류: 소유+비소유 혼합 코퍼스를 실패로 센다 (파일별 판정)" \
             || t_no "분류: 혼합 코퍼스를 통과시킨다 — 판정이 '하나라도 소유면 OK' 로 약해졌다"

# 리포 밖 경로도 소유가 아니다.
probe "docs/audits/x.md" >/dev/null 2>&1
[ $? -ne 0 ] && t_ok "분류: plugins/ 밖 경로 거절" || t_no "분류: plugins/ 밖 경로를 소유로 통과시킨다"

# ★ vacuity: **빈 코퍼스는 통과가 아니다.** 소비자의 도출이 깨져 0건이 되면 그 스위트의
# 존재 검사가 전부 vacuous 해지는데, 앞 판본은 여기에 ok 를 냈다(fix round 5 실측).
probe >/dev/null 2>&1
[ $? -ne 0 ] && t_ok "vacuity: 빈 코퍼스를 시끄럽게 실패시킨다" \
             || t_no "vacuity: 빈 코퍼스를 조용히 통과시킨다 — 세 락이 동시에 vacuous 해진다"

echo "=== (2) 세 소비자가 실제로 이 헬퍼를 통해 판정받는가 ==="

# fix round 4 의 통제 ①("헬퍼의 ok 를 지우면 세 소비자 전부 단언 −1")을 상설화한 것.
# 소비자의 GREEN/RED 자체는 보지 않는다 — 다른 이유로 RED 인 소비자와 이 락을 묶지 않는다.
CORPUS_RE='presence 대상 [0-9][0-9]*개가 전부 skill 소유 표면'
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  name="$(basename -- "$rel")"
  out="$(cd "$ROOT" && bash "$rel" </dev/null 2>&1)"
  line="$(printf '%s\n' "$out" | grep -E "$CORPUS_RE" | head -1)"
  if [ -z "$line" ]; then
    t_no "소비자: $name 의 출력에 헬퍼 판정 줄이 없다 — 호출을 잃었거나 코퍼스가 비었다"
    continue
  fi
  t_ok "소비자: $name 이 헬퍼를 통해 판정한다"
  n="$(printf '%s\n' "$line" | sed -E 's/.*presence 대상 ([0-9]+)개가.*/\1/')"
  # 하한 2 는 구조에서 나온다: 두 CI 소비자는 SKILL.md + 참조 파일 ≥1, 채택자 락은
  # 채택자 ≥2 × 파일 ≥1. 1 이하면 도출이 무너진 것이다("짧은 코퍼스").
  [ "${n:-0}" -ge 2 ] \
    && t_ok "소비자: $name 의 presence 코퍼스 ${n}개 (구조적 하한 2 충족)" \
    || t_no "소비자: $name 의 presence 코퍼스가 ${n}개뿐 — 도출이 조용히 좁아졌다"
done < <(printf '%s\n' "$CONSUMERS")

echo "=== (3) 채택자 락의 격리 불변식 ==="

# 각 채택자는 **자기 파일만** 본다. 루프가 언젠가 합집합을 모든 채택자에게 넘기면
# Σ(채택자별 파일 수) = 채택자 수 × 전체 가 되어 전체와 어긋난다. 산술로 잰다 —
# "격리돼 있다"는 주석이 아니라 계산이다.
ad_out="$(cd "$ROOT" && bash plugins/spec-distill/tests/test_proceed_gate_adopters.sh </dev/null 2>&1)"
total="$(printf '%s\n' "$ad_out" | grep -E "$CORPUS_RE" | head -1 | sed -E 's/.*presence 대상 ([0-9]+)개가.*/\1/')"
sum=0; n_ad=0
while IFS= read -r per; do
  [ -n "$per" ] || continue
  sum=$((sum + per)); n_ad=$((n_ad + 1))
done < <(printf '%s\n' "$ad_out" | sed -nE 's/.*자기 표면 ([0-9]+)파일.*/\1/p')
if [ "$n_ad" -lt 2 ]; then
  t_no "격리: 채택자별 파일 수 줄을 ${n_ad}개만 찾았다 — 2 미만이면 이 불변식이 공허하다"
elif [ -z "${total:-}" ]; then
  t_no "격리: 채택자 락에서 전체 코퍼스 크기를 못 읽었다 — 산술 대조 불가"
elif [ "$sum" -eq "$total" ]; then
  t_ok "격리: 채택자 ${n_ad}개의 자기-파일 합 ${sum} = 전체 ${total} (아무도 남의 파일을 보지 않는다)"
else
  t_no "격리: 자기-파일 합 ${sum} ≠ 전체 ${total} — 채택자 루프가 합집합을 넘기거나 파일을 흘린다"
fi

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
