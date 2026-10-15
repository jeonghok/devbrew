#!/usr/bin/env bash
# R4 분해 판단 · 재분해 문면 락(AC1 · AC2 · AC3 · AC7 · AC8 · AC11).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_decompose_surface.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SD="$ROOT/plugins/spec-distill"
FIN="$SD/skills/spec-interview/references/finishing.md"
SKILL="$SD/skills/spec-interview/SKILL.md"
TPL="$SD/templates/interview-brief-template.md"

win() {  # win <파일> <시작 줄 리터럴> <끝 줄 접두> — 시작 줄 다음부터 끝 줄 앞까지
  awk -v s="$2" -v e="$3" '$0==s{f=1;next} f&&index($0,e)==1{exit} f' "$1"
}
has() {  # has <창> <리터럴> <라벨>
  case "$1" in *"$2"*) ok "$3" ;; *) no "$3 — 없음: $2" ;; esac
}
assert_file_has() {  # assert_file_has <파일> <고정 문자열> <라벨>
  if grep -qF -- "$2" "$1" 2>/dev/null; then ok "$3"; else no "$3 — 없음: $2"; fi
}

# ── AC1 · AC2 — 분해 판단 단계 ──────────────────────────────────────────────
DEC="$(win "$FIN" '### 분해 판단 — Step A 직전' '### Step A')"
if [ -n "$DEC" ]; then ok "분해 판단 절이 Step A 앞에 있다"; else no "분해 판단 절 창이 비었다 — 앵커 파손"; fi
for lit in '따로 승인할 수 있는 덩어리 수' '파일 영역 수' '사용자 원문 갈래 수' '근거 번호' \
           '컷오프는 두지 않는다' '하나로 충분해 보인다' '나누는 게 좋아 보인다' \
           '"spec 하나로"' '"나눈다 — 분해안 보기"' \
           '| 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 |' \
           '「묶음」' '「브랜치 <설계문서 경로>」' '「결정」' '걷는 뼈대' \
           '미배정 번호 <n> · 고아 발화 <m>' '「승인」' '「고치기」' '「spec 하나로」' '계속 고칠까요' \
           '자동으로 끝내지 않는다' '## 분해안' '분해됨 — <로드맵 경로>'; do
  has "$DEC" "$lit" "분해 판단: $lit"
done
# 부재 · 존재 짝 — 숫자 컷오프 문면이 없다(존재 짝은 위 「컷오프는 두지 않는다」).
cut="$(printf '%s\n' "$DEC" | grep -nE '[0-9]+ ?(개|곳|갈래|영역|덩어리)( 이상| 넘| 초과|보다 많)' || true)"
assert_eq "$cut" "" "분해 판단: 숫자 컷오프 문면이 없다"
assert_file_absent "$FIN" '이상이면 나눈다' "finishing: 「이상이면 나눈다」 문면이 없다"

# ── AC3 · AC4 — 생성 · 재생성 ───────────────────────────────────────────────
STEPA="$(win "$FIN" '### Step A — brief 작성 (terminal 산출물, 2파일)' '### Step A.5')"
has "$STEPA" 'roadmap_write.py" create' "Step A: 생성기 create 를 부른다"
has "$STEPA" '--plan-table' "Step A: 분해안 표를 넘긴다"
has "$STEPA" '분해 판단 3' "Step A: 실패하면 분해안 표로 돌아간다"
REGEN="$(win "$FIN" '#### B-R — 로드맵 다시 생성 (분해된 일만)' '#### ')"
if [ -n "$REGEN" ]; then ok "Step B: 다시 생성 절이 있다"; else no "Step B: B-R 창이 비었다"; fi
for lit in 'brief 를 마지막으로 쓴 직후' '언제나 한 번' '항목이 바뀌었는지와 상관없다' '## 생성 기록' \
           '커밋 전에 도는 단계' 'brief · audit · 상태 파일 · 로드맵 폴더를 함께 커밋하라'; do
  has "$REGEN" "$lit" "B-R: $lit"
done
assert_file_absent "$FIN" '항목이 바뀌면 확정 직후' "옛 「항목이 바뀌면」 재생성 조건이 없다"

# ── AC7 — 분해된 일의 다음 세션 줄 ──────────────────────────────────────────
MARK='**다음 세션 줄 — 분해된 일 ①/② 공통**'
DLINE="$(awk -v m="$MARK" '$0==m{f=1;next} f&&NF{print;exit}' "$FIN")"
case "$DLINE" in
  '`@<roadmap-path> 이 로드맵의 지휘 절차대로 진행하라.'*) ok "분해된 일: 다음 세션 줄이 @<roadmap-path> 지휘 줄" ;;
  *) no "분해된 일: 다음 세션 줄이 다르다: $DLINE" ;;
esac
has "$DLINE" '사람에게 쓰는 글 규칙' "분해된 일: 다음 세션 줄이 글 규칙을 싣는다"
n_brief="$(grep -cE '^[[:space:]]*> `(@<[^<>]+> )+이 interview brief 로' "$FIN" || true)"
assert_eq "$n_brief" "1" "나누지 않은 일의 brief 줄은 그대로 하나"

# ── SKILL · 템플릿 ──────────────────────────────────────────────────────────
assert_file_has "$SKILL" "「분해 판단」 단계부터" "SKILL: 종료 뒤 분해 판단을 가리킨다"
assert_file_has "$TPL" "분해됨 — <로드맵 경로>" "brief 템플릿 §7: 분해 줄"

finish
