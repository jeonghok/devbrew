# presence_corpus.sh — **존재(presence) 검사 코퍼스**의 소유 규칙을 재는 공용 단언.
# 실행 파일이 아니라 라이브러리다(`assert.sh` 와 같은 권한/관례). `. assert.sh` **뒤에**
# source 할 것 — `ok`/`no` 를 쓴다.
#
#   . "$REPO_ROOT/shared/tests/assert.sh"
#   . "$REPO_ROOT/shared/tests/presence_corpus.sh"
#   assert_presence_corpus_skill_owned "CI_FILES" "${CI_FILES[@]}"
#
# ── 무엇을 재는가 ────────────────────────────────────────────────────────────
# 존재 검사가 보는 코퍼스에 **그 skill 소유가 아닌 파일**이 들어왔는지. 특히 두 skill 이
# **공유**하는 계약 파일(`plugins/<p>/references/*.md`, 예: proceed-gate.md)이 위험하다 —
# 그 파일은 계약을 서술하느라 각 skill 의 앵커 어휘(`턴 종료`·`다음 턴`·`polite stop` 등)를
# 그대로 담고 있어서, 코퍼스에 들어오면 **그 skill 이 자기 문구를 통째로 잃어도 스캔이
# 만족된다.**
#
# 그 편집은 그럴듯하다 — 부재(absence) 락의 처방("코퍼스를 넓혀 도출로")이 바로 그것이기
# 때문이다. 그 처방은 *부재* 검사의 것이고 presence 에 적용하면 이빨이 사라진다. 넓히려면
# 부재 전용 배열 쪽으로 넓혀야 한다(감사문서 「공유 참조 파일」 절).
#
# ── 왜 공용인가 (Task 33 fix round 4, F3) ───────────────────────────────────
# 이 규칙은 정본(`proceed-gate.md` 「앵커는 각 skill 에」)이 **이 계약을 재는 모든 스캔**에
# 요구하는 것이라, 스캔 수만큼 사본이 생긴다. 실제로 24줄 블록이 두 테스트에 바이트 동일로
# 복제됐고, 한 라운드 뒤 "통과 시 침묵" 결함을 **양쪽에 따로** 고쳐야 했다. 중복 제거가
# 이 브랜치의 산출물인데 그 태스크가 새 중복을 만든 셈이다. 여기 한 벌만 둔다.
#
# ── 통과 시에도 반드시 한 줄을 낸다 ─────────────────────────────────────────
# 실패 분기에서만 말하는 가드는 깨져도 단언 수·출력이 그대로라 "아무것도 안 하면서 GREEN"
# 을 구별할 수 없다. 앞선 판본이 정확히 그랬다(감사문서 「계측기」 절).
#
# $1 = 배열 이름(메시지용 라벨) · $2.. = 코퍼스 파일 경로들
assert_presence_corpus_skill_owned() {
  local label="$1"; shift
  local f own=0 foreign=0
  for f in "$@"; do
    case "$f" in
      */skills/*/SKILL.md|*/skills/*/references/*.md) own=$((own + 1)) ;;
      *) no "코퍼스: ${label} 에 이 skill 소유가 아닌 파일이 들어왔다 ($f) — presence 검사가 공유 계약 파일로 만족될 수 있다. 부재 검사용 코퍼스로 옮겨라(proceed-gate.md 「앵커는 각 skill 에」 절)."
         foreign=$((foreign + 1)) ;;
    esac
  done
  # **빈 코퍼스는 통과가 아니라 실패다.** 앞 판본은 `own=0 foreign=0` 에 `ok` 를 냈다
  # 〔실측〕 — 소비자의 도출이 깨져 0건이 되면 그 스위트의 존재 검사가 **전부 vacuous**
  # 해지는데, 이 가드는 "전부 skill 소유 표면"이라며 초록을 찍는다. 세 락이 동시에
  # 이빨을 잃는 경로이고, 이 헬퍼가 그것을 감춰 준다. 0 은 시끄럽게 답한다.
  if [ "$#" -eq 0 ] || [ "$((own + foreign))" -eq 0 ]; then
    no "코퍼스: ${label} 이 비어 있다 — 도출이 0건이면 이 스위트의 존재 검사가 전부 vacuous 하다 ('소유 밖 0건'을 '문제 없음'으로 읽지 않는다)"
    return
  fi
  if [ "$foreign" -eq 0 ]; then
    ok "코퍼스: ${label} 의 presence 대상 ${own}개가 전부 skill 소유 표면 (공유 계약 파일은 코퍼스 밖)"
  else
    no "코퍼스: ${label} 에 skill 소유 밖 파일 ${foreign}건"
  fi
}
