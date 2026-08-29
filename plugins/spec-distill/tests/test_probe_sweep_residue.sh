#!/usr/bin/env bash
# guards: plugins/spec-distill/**
#
# probe 상한 스윕의 **완결성**을 잰다 — 단측 단언이다.
#
# 완료 조건: 아래 오라클의 출력에 `tests/fixtures/` · `CHANGELOG.md` · 이 파일 자신
# **밖** 경로가 0건. 오라클은 두 층이다 — ① 식별자(`ALIAS_RE`, 코드/스키마 리터럴)
# ② 개념명 근접(`CONCEPT_RE`, 산문 부활 탐지 — fix round 1 이후 추가, 아래 참조).
# 집합 일치가 아니라 단측인 이유와 세 제외의 이유를 여기 함께 적는다 — **이유 없는
# 면제 목록은 그 질문을 영구히 닫는다.**
#
#  · `tests/fixtures/` 제외 — audit 템플릿의 `## 2. Budget` 절을 **삭제하지 않기로** 한
#    비용 판단의 결과다(절을 지우면 `check_brief.py` 의 `AUDIT_SECTIONS` 와 픽스처
#    61건이 함께 스윕 대상이 된다). 절은 남기고 본문만 바꾼다. 대가는 «삭제된 개념을
#    계속 인용하는 픽스처가 락으로 굳는 것»이고, 그 대가를 알고 치른다.
#  · `CHANGELOG.md` 제외 — **지울 수 없는 과거 릴리스 이력**이다. 빼지 않으면 이 락은
#    원리적으로 green 이 될 수 없고, 무엇보다 **이 스윕 자신의 `Removed: probe_budget.py`
#    엔트리가 락을 RED 로 만든다.** 락을 만족시키는 커밋이 락을 깨뜨리는 형태다.
#  · 이 파일(`test_probe_sweep_residue.sh`) 자신 제외 — `ALIAS_RE`·`CONCEPT_RE` 정의
#    리터럴 자체가 별칭·개념 문자열을 담아야 정규식으로 동작한다. git add 되는 순간부터
#    이 파일이 tracked 코퍼스에 들어가 스스로를 잡는다 — CHANGELOG.md 와 같은 형태의
#    자기지시 함정이고, 같은 이유로 제외한다: 자신을 잡는 락은 커밋될 수 없다. **양성
#    대조·vacuity 하한에서도** 같은 이유로 뺀다 — 안 빼면 두 정규식을 통째로 없는
#    토큰으로 바꿔도 이 파일 자신의 정의 줄이 "1건"으로 잡혀 정규식이 깨진 상태를
#    «살아있음»으로 오판하고(양성 대조 자기지시, M9 실증), 코퍼스가 이 파일 하나만
#    남도록 다 지워져도 `corpus_n`이 이 파일 자신을 세어 vacuity 를 못 잡는다(fix round
#    1, 리뷰 Minor 1 실증 — all_hits 와 같은 자기지시 계열, 대칭으로 고친다).
#
#  **세 제외의 대가(fix round 1, 리뷰 Minor 2)**: 이 셋 밖의 파일에 "이 기능은 v0.38.0 에
#  제거됐다" 같은 정당한 후속 이력 문장을 적으면 — 그 문장이 `ALIAS_RE`·`CONCEPT_RE` 중
#  하나에라도 걸리는 한 — 그 파일은 **영구히 RED**다(면제 목록 밖이므로). 이것이 이
#  태스크가 README.md 의 probe 상한 서술을 이력 문단으로 **주석 처리하지 않고 통째로
#  삭제한** 이유다 — 주석을 남겼다면 그 문장 자체가 이 락을 영원히 깨뜨렸을 것이다.
#  이력을 남기고 싶으면 CHANGELOG.md 에 적는다(이미 면제됨).
#
# 집합 «일치»로 잠그지 않는 이유: 픽스처 61건 중 `state-probe-at-cap.md` 와
# `state-probe-within.md` 둘은 audit 픽스처가 아니라 삭제 대상 `test_probe_budget.sh`
# 전용 state 픽스처라 함께 지워지는 것이 옳다(잔존이 59 가 된다). 일치로 잠그면 그
# 올바른 정리에 거짓 RED 가 난다. 단측은 판별력이 같고 그 부작용이 없다.
#
# --- fix round 1 (리뷰 Important 3): 식별자만으로는 산문 부활을 못 잡는다 ---
# 리뷰어가 SKILL.md 에 `## probe 상한 백스톱 (부활)` 절을 새로 추가해 상한(기본 12) ·
# 계속/박제/abort 세 선택지 · "프로즈 self-tracking" 금지를 **식별자 없이 순수 한국어
# 산문으로만** 재현했다 — `ALIAS_RE`(식별자 전용) 는 이걸 못 본다(3/3 GREEN, 스위트도
# 86/86 GREEN, 실측·재현 완료). grep 은 산문을 이해하지 못하므로 "산문을 이해"시키는
# 수정은 할 수 없다 — 대신 두 가지만 한다: ① 개념을 가리키는 이름 자체를 스캔 대상에
# 추가 ② 못 보는 것을 여기 명시한다.
#
# `CONCEPT_RE` — "probe" 와 "백스톱"/"self-tracking" 이 **같은 줄에서 10~15자 이내**로
# 근접할 때만 잡는다(파일 전체 co-occurrence 가 아니라 근접). 이유: `백스톱` 단독은 이
# 플러그인 안에서만도 7개 파일에 다른 백스톱(재리뷰 cap, arm-once 등)을 가리키며 legitimately
# 등장하고, `self-tracking` 단독도 finishing.md·이 스위트 자신에서 **다른** 카운터(재제시
# cap)를 가리키며 등장한다 — 단독 토큰으로 넣으면 그 문서들이 전부 거짓 잔존이 된다(실측).
# `probe` 단독도 이 스킬 전체에서 "매 probe"처럼 흔히 쓰이고, reviewing-brief/SKILL.md 는
# **다른** "zero-tool probe" 개념 때문에 `probe` 와 `백스톱` 을 **파일 전체에서는** 둘 다
# 담고 있다(실측 — 파일-단위 co-occurrence 로 걸었다면 거짓 잔존이었다). 그래서 파일
# 전체가 아니라 **같은 줄 근접**으로 좁혔다 — 이 두 파일 어디에도 `probe` 와 `백스톱`이
# 한 줄 안에서 만나는 자리가 없음을 확인했다(실측, 이하 두 조건 전부 GREEN 그대로).
#
# **`상한`(cap 의 한국어)은 추가하지 않는다** — 이 플러그인 안에서만 32곳에 legitimately
# 등장하는 극히 흔한 한국어 낱말이다(rhythm-guard threshold · rereview cap ·
# confirm_repost_count cap 등, 실측). 추가하면 락이 그 32곳 전부를 거짓 잔존으로 묻고
# 그 소음 아래서 진짜 잔존이 안 보이게 된다("드라운"). 이유 없이 빼는 게 아니라, 넣으면
# 이빨이 아니라 소음이 된다는 근거를 확인한 뒤 뺐다.
#
# **이 오라클이 여전히 못 보는 것(알려진 채로 남긴다)**: `CONCEPT_RE` 는 "probe" 와
# "백스톱"/"self-tracking" 이 **같은 줄**에 근접해야 잡는다 — 부활 산문이 두 어휘를
# 다른 줄로 떼어 쓰거나("무한 반복을 막는 절차" 처럼 두 어휘 모두를 피해 다른 말로
# 완전히 바꿔 쓰면(예: "질문 개수가 12를 넘으면 계속/보류/중단을 고른다") 이 오라클은
# 그 산문을 **전혀** 못 본다. grep 은 식별자·근접 어휘까지만 재고, 의미를 재지 않는다 —
# 이것이 grep 기반 완결성 오라클의 구조적 상한이며, 이 상한을 넘는 방어는 리뷰(사람 ·
# 다른 모델)의 몫이지 이 락의 몫이 아니다.
#
# 아래 `AUDIT_SECTIONS` 관련 사각지대도 별도로 남는다: grep 은 산문 언급을 찾지
# **구조화된 상수**를 못 본다. `check_brief.py` 의 `AUDIT_SECTIONS` 는 절 제목을 튜플
# 원소로 들고 있어 `## 2. Budget` 패턴에 안 걸린다. 위의 «절을 삭제하지 않는다» 결정이
# 이 사각지대를 무해하게 만든다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

ALIAS_RE='probe_budget|probe_count|probe_cap|effective_cap|raise-cap|PROBE_CAP|coverage_mapper_last_probe'
CONCEPT_RE='probe.{0,10}백스톱|백스톱.{0,10}probe|probe.{0,15}self-tracking|self-tracking.{0,15}probe'
SCAN_RE="${ALIAS_RE}|${CONCEPT_RE}"
SCOPE='plugins/spec-distill'
SELF='test_probe_sweep_residue\.sh$'

if [ "${1:-}" = "--emit-scanned" ]; then
  git ls-files -- "$SCOPE"
  exit 0
fi

# vacuity 하한 — 코퍼스가 비면 「잔존 0」이 「안 봤다」가 된다. 이 파일 자신은 여기서도
# 뺀다(위 헤더 세 번째 제외 참조) — 안 빼면 나머지가 전부 지워져도 이 파일 하나가 남아
# corpus_n >= 1 이 항상 성립해 vacuity 를 원리적으로 못 잡는다.
corpus_n="$(git ls-files -- "$SCOPE" | grep -v "$SELF" | wc -l | tr -d ' ')"
if [ "${corpus_n:-0}" -lt 1 ]; then
  no "코퍼스가 0건 — 이 검사가 vacuous 하다"
  finish; exit $?
fi
ok "코퍼스 ${corpus_n}개 파일 (vacuous 아님)"

# 양성 대조 — 오라클 자체가 살아 있는가. 별칭·개념 근접이 «어딘가에는» 남아 있어야
# 한다(픽스처·CHANGELOG). 0건이면 정규식이 깨진 것이지 스윕이 완벽한 것이 아니다.
# 이 파일 자신은 여기서도 뺀다 — `SCAN_RE`가 무엇으로 바뀌든 그 리터럴이 이 파일
# 안에 그대로 있으므로, 자신을 포함하면 어떤 깨진 정규식(예: 존재하지 않는 토큰
# 하나)도 "1건"으로 살아있는 척한다 — 양성 대조 자체가 자기지시로 무력화된다
# (잔존 계산과 같은 함정, M9 실증).
#
# --- Step 4-b (R-K, 계열별 분리): 합본 SCAN_RE 하나로만 재면 한쪽 계열이 죽어도 다른
# 계열이 건수를 채워 통과한다 — 실측: `ALIAS_RE`만 매칭 안 되는 토큰으로 바꿔도(예:
# 오타 하나) 이 대조는 GREEN 이었다(CONCEPT_RE 가 CHANGELOG.md 의 "probe 백스톱" 한
# 줄을 여전히 잡아 all_hits >= 1 을 만족시켰기 때문). 부재 락엔 양의 짝이 필요하다의
# 두 번째 층 — 짝이 하나뿐이면 합집합만 지키고 각 항은 안 지킨다. 그래서 계열마다
# 따로 재고, 자기지시 제외(`$SELF`)는 두 계열 모두에서 유지한다.
alias_hits="$(git grep -lE "$ALIAS_RE" -- "$SCOPE" | grep -v "$SELF" | wc -l | tr -d ' ')"
if [ "${alias_hits:-0}" -lt 1 ]; then
  no "양성 대조: ALIAS_RE 가 리포 어디에도 0건 — 식별자 정규식이 깨졌다"
  finish; exit $?
fi
ok "양성 대조: ALIAS_RE ${alias_hits}건 (정규식 살아 있음)"

concept_hits="$(git grep -lE "$CONCEPT_RE" -- "$SCOPE" | grep -v "$SELF" | wc -l | tr -d ' ')"
if [ "${concept_hits:-0}" -lt 1 ]; then
  no "양성 대조: CONCEPT_RE 가 리포 어디에도 0건 — 개념명 근접 정규식이 깨졌다"
  finish; exit $?
fi
ok "양성 대조: CONCEPT_RE ${concept_hits}건 (정규식 살아 있음)"

residue="$(git grep -lE "$SCAN_RE" -- "$SCOPE" \
  | grep -v 'tests/fixtures/' | grep -v 'CHANGELOG\.md$' \
  | grep -v "$SELF" || true)"
n=0
while IFS= read -r f; do [ -n "$f" ] && n=$((n + 1)); done <<< "$residue"
if [ "$n" -eq 0 ]; then
  ok "잔존 0건 (tests/fixtures/ · CHANGELOG.md · 이 파일 자신 제외 — 위 헤더에 각각의 이유)"
else
  printf '%s\n' "$residue" | while IFS= read -r f; do
    [ -n "$f" ] && echo "     잔존: $f"
  done
  no "probe 별칭·개념 잔존 ${n}건 — 스윕이 끝나지 않았다"
fi

finish
