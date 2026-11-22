#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/context-build/* plugins/spec-distill/skills/roadmap-draft/*
# 앞단 가르기(AC3 · AC4 · AC9 · AC15) — 표 짜기 · 생성 · PR 과 머지 · 지휘자 줄은 로드맵 잡기에만 있고,
# 컨텍스트 쌓기는 「나눌 것인가」 질문과 §7 분해됨 줄까지만 갖는다.
# 정적 락이다 — 모델이 이 글을 실제로 따르는지는 재지 못한다. 헤더 글자가 아니라 본문 토큰으로 문다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_stage_split.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"
if [ "${1:-}" = "--emit-scanned" ]; then   # 읽는 파일: 컨텍스트 쌓기 · 로드맵 잡기 추적 파일 전부
  git -C "$ROOT" ls-files -- 'plugins/spec-distill/skills/context-build/*' 'plugins/spec-distill/skills/roadmap-draft/*'
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
FIN="$SD/skills/context-build/references/finishing.md"
CB_SKILL="$SD/skills/context-build/SKILL.md"
CB="$(git -C "$ROOT" ls-files 'plugins/spec-distill/skills/context-build/*')"
RD="$(git -C "$ROOT" ls-files 'plugins/spec-distill/skills/roadmap-draft/*')"
case "$CB" in *context-build/references/finishing.md*) ok "코퍼스(양성 짝): context-build 추적 파일 $(printf '%s\n' "$CB" | grep -c .)개에 finishing.md 가 든다" ;;
  *) no "코퍼스(양성 짝): context-build 추적 파일에 finishing.md 가 없다 — 부재 단언이 공허하다" ;; esac
case "$RD" in *roadmap-draft/SKILL.md*) ok "코퍼스(양성 짝): roadmap-draft 추적 파일에 SKILL.md 가 든다" ;;
  *) no "코퍼스(양성 짝): roadmap-draft 추적 파일이 없다 — 존재 단언이 공허하다" ;; esac

none_in() {   # none_in <파일 목록> <리터럴> — 목록의 어느 파일에도 없다
  local f hit=""
  for f in $1; do grep -qF -- "$2" "$ROOT/$f" && hit="${hit} ${f}"; done
  assert_eq "$hit" "" "context-build 어느 파일에도 「$2」 가 없다"
}
some_in() {   # some_in <파일 목록> <리터럴> — 목록의 어느 파일엔가 있다(rc 로만 답한다)
  local f
  for f in $1; do grep -qF -- "$2" "$ROOT/$f" && return 0; done
  return 1
}
has() {    # has <파일> <리터럴>
  if grep -qF -- "$2" "$1" 2>/dev/null; then ok "${1#"$ROOT"/}: 「$2」"; else no "${1#"$ROOT"/}: 「$2」 가 없다"; fi
}
lacks() {  # lacks <파일> <리터럴> — 파일이 없으면 실패(공허한 통과를 막는다)
  if [ ! -f "$1" ]; then no "${1#"$ROOT"/}: 파일이 없다 — 부재 단언이 공허하다"; return; fi
  if grep -qF -- "$2" "$1"; then no "${1#"$ROOT"/}: 「$2」 가 있다"; else ok "${1#"$ROOT"/}: 「$2」 가 없다"; fi
}
order() {  # order <파일> <앞 줄 리터럴> <뒤 줄 리터럴> — 둘 다 있고 앞이 먼저다
  local a b
  a="$(grep -nF -- "$2" "$1" | head -n 1 | cut -d: -f1)"; b="$(grep -nF -- "$3" "$1" | head -n 1 | cut -d: -f1)"
  if [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; then ok "${1#"$ROOT"/}: 「$2」(${a}) 가 「$3」(${b}) 앞"
  else no "${1#"$ROOT"/}: 「$2」(${a:-없음}) 가 「$3」(${b:-없음}) 앞이 아니다"; fi
}

# AC3 — 표 짜기 · 승인 · 고친 횟수 · 생성 · PR 과 머지 펜스 · 지휘자 줄은 context-build 에 없고 roadmap-draft 에 있다.
# 펜스 표지는 옛 이름(interview-*)과 새 이름(roadmap-*)을 둘 다 적는다 — 이름을 바꾸는 과제 전후 모두 이빨이 있게.
for tok in '3. **분해안 표.**' '4. **고치기 · 승인.**' 'roadmap_write.py" create' \
           'interview-''pr:begin' 'interview-''merge:begin' 'roadmap-pr:begin' 'roadmap-merge:begin' \
           '/spec-distill:epic-conductor' '고친 횟수: '; do
  none_in "$CB" "$tok"
  alt1="${tok/interview-/roadmap-}"; alt2="${tok/roadmap-/interview-}"
  if some_in "$RD" "$tok" || some_in "$RD" "$alt1" || some_in "$RD" "$alt2"; then ok "roadmap-draft 에 「${tok}」(또는 표지의 옛 · 새 이름)가 있다"
  else no "roadmap-draft 에 「${tok}」 가 없다(옛 · 새 표지 이름 모두) — 옮긴 곳이 비었다"; fi
done
# 「나눌 것인가」 질문은 조사를 닫은 직후, 결과물을 쓰기 전에 있다
order "$FIN" '### 분해 판단 — Step A 직전' '### Step A — brief 작성'
has "$FIN" '나눈다 — 확정 뒤 로드맵 잡기로'
lacks "$FIN" '나눈다 — 분해안 보기'
# AC9 — 다시 생성 걸음이 어느 단계의 글에도 없다
n=0
for f in $(git -C "$ROOT" ls-files 'plugins/spec-distill/skills/*'); do n=$((n + 1)); lacks "$ROOT/$f" '다시 생성'; done
[ "$n" -ge 3 ] && ok "AC9 코퍼스(양성 짝): skill 글 ${n}개" || no "AC9 코퍼스가 ${n}개 — 부재 단언이 공허하다"
# AC4 — 「나눈다」 결과물의 §7 첫 줄은 Step A 가 쓴다(구조 게이트의 「나눈 일은 건너뛸 수 없다」 가 이 줄을 읽는다)
has "$FIN" '§7 첫 줄에 `분해됨 — <로드맵 경로>` 를 쓰고'
# AC15 — 소개 문구와 종료 조건 문장이 모델 판단 건너뜀을 말한다
DESC="$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f' "$CB_SKILL" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$DESC" '또는 모델 판단으로 건너뛸 때(건너뜀 줄을 남긴다)' "AC15: 소개 문구(description)가 모델 판단 건너뜀을 말한다"
END="$(awk '/^## 종료 — /{f=1;next} f&&/^### /{exit} f' "$CB_SKILL" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$END" '또는 모델 판단으로 건너뛸 때(건너뜀 줄을 남긴다)' "AC15: \`## 종료\` 의 종료 조건 문장이 모델 판단 건너뜀을 말한다"
finish
