#!/usr/bin/env bash
# R5 계획 3 — 하위에게 보내는 글(`references/conductor-dispatch.md`): AC21 의 항목 · 두 부분 반환(AC45) · 처분 줄 ·
# 미리 받은 답과 돌려보낼 자리의 구분(결정 H) · 단계마다 새 agent(결정 I). 정적 락이다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_conductor_dispatch_reference.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
F="$ROOT/plugins/spec-distill/references/conductor-dispatch.md"
[ -f "$F" ] && ok "conductor-dispatch.md 가 있다" || { no "conductor-dispatch.md 가 없다"; finish; exit $?; }
TXT="$(cat "$F")"
sec() { awk -v h="$1" '$0==h{f=1;next} f&&/^## /{exit} f' "$F"; }
for h in '## 무엇으로 돌리나' '## 늘 싣는 것' '## 사람 자리' '## 단계마다 새 agent' '## 마지막 보고' '## 세션 담당자' '## 틀'; do
  assert_eq "$(grep -cxF -- "$h" "$F" || true)" "1" "절 머리 「${h}」 가 정확히 하나"
done
once() {  # once <절> <문장>
  assert_eq "$(sec "$1" | grep -oF -- "$2" | wc -l | tr -d ' ')" "1" "${1}: 「${2}」 정확히 한 번"
}
for lit in '그 에픽 worktree 의 절대경로' '고른 흐름과 그 이유' '단일 세션과 똑같이, 단계를 빼거나 다시 쓰지 말고 끝까지' \
           '`TMPDIR`' '공유 임시 폴더의 glob 삭제' '`git stash`' '다른 worktree 의 git 조작' '`Spec: <설계문서 레포 상대경로>`' \
           'HEAD 를 뒤로 옮기지 않는다' 'pathspec'; do
  once '## 늘 싣는 것' "$lit"
done
assert_eq "$(grep -cxF -- '**처분** — consumer=orchestrator · fail-closed · disclosure=하위가 돌려보낸 사람 자리 원문(쉬운 배경 뒤 늘 첨부) · 판정 목록 · AC 보고를 빠짐없이 사용자에게 보인다' "$F" || true)" "1" "처분 줄이 설계 §4 글자 그대로 한 줄"
for lit in '「브랜치 그대로 두기」(3번)' 'Push 와 PR 은 지휘자가 구현 대조 뒤에 한다' '구현 agent 를 보낼 때만' \
           '계획 agent 에게는 싣지 않는다' '(a) 사람에게 보일 쉬운 요약' '(b) skill 이 낸 문면 원문' '내부 기호는 괄호에만' \
           '수 · 순서 · 라벨 글자' '「지휘자 의견:」 한 줄로만 쓴다' '원문은 늘 붙인다' '사용자 답은 지휘자가 더한 꼬리를 뗀 원문 라벨 글자로 같은 agent 에 돌려준다' \
           '원문이 라벨에 붙인 「(권장)」 꼬리는 그대로 둔다.' '꼬리를 더하는 길은 둘이다' '원문 권장과 다른 선택지면 둘 다 단다' \
           '정본 규칙대로 추천이 있으면 첫 자리에 두고 라벨 끝에 「(권장)」을 단다' \
           '쓰기 권한 없는 agent 가 둘의 선택지 수 · 라벨 · 순서를 대조한다' '그 자리만 지휘자가 직접 돌리는 길로 되돌리고' \
           '선택지 설명을 옮길 때 원문의 문장을 하나도 빼지 않는다 — 번역해도 문장 수를 지킨다.' \
           '미리 받은 답을 뒤 하위 agent 에 실을 때 그 dispatch 에 실제로 넣은 문장을 그 relay 파일의 「돌려보낸 글」 에 덧붙인다.' \
           '지휘자가 꼬리를 달면 선택지 밖 「지휘자 의견:」 한 줄에 어느 꼬리가 지휘자의 것인지와 이유를 쓴다.' \
           '그 줄 끝에 그 의견을 따르면 내주는 것을 한 구절 붙인다.' \
           '구현 중 하위의 물음이 설계문서의 글자 · 수용 기준 · 사용자에게 보이는 동작을 더하거나 바꾸면 지휘자가 답하지 않고 사용자에게 옮긴다'; do
  once '## 사람 자리' "$lit"
done
assert_not_contains "$(sec '## 사람 자리')" '지휘자 것이라고 밝힌다' "AC9: 옛 문장 없음"
for lit in '지휘자 자신의 권장은 라벨 안 「(권장)」으로 넣지 않고' '그 의견 줄에만 쓴다' '라벨 꼬리 「(권장)」으로 바꾸지 않는다' '그 선택지에는 「(권장)」을 달지 않는다' '사용자 답은 글자 그대로 같은 agent 에 돌려준다'; do
  assert_not_contains "$(sec '## 사람 자리')" "$lit" "옮김 꼬리: 옛 문장 없음 — $lit"
done
for lit in '계획 agent' '구현 agent 는 새로 보낸다' '커밋된 계획 경로 · 설계문서 경로' '리뷰 엔진의 문서별 상태 경로'; do
  assert_contains "$(sec '## 단계마다 새 agent')" "$lit" "단계마다 새 agent: $lit"
done
once '## 단계마다 새 agent' '같은 agent 를 이어 부른다(`SendMessage`)'
once '## 단계마다 새 agent' '실행 방식 답은 계획 agent 에 돌려주지 않고 새 구현 agent 의 미리 받은 답으로 싣는다'
once '## 단계마다 새 agent' '계획만 고치고 커밋한 뒤 다시 멈춘다 — 실행 skill 로 넘어가지 않는다'
for lit in '판정 전체' 'AC 보고 내용 전체' '경로만으로는 부족하다' '잠긴 스위트 대조' '경합으로 보고'; do
  once '## 마지막 보고' "$lit"
done
TPL="$(sec '## 틀')"
for lit in '### 계획 agent' '### 구현 agent' '### 이어 부르기'; do
  assert_contains "$TPL" "$lit" "틀: $lit"
done
assert_contains "$TPL" 'check_bundle_coverage.py --plan' "계획 틀: --plan 대조"
# 지휘자 수리 3 — 하위 agent 의 자리: 격리 agent 가 자기 worktree 에서 에픽 브랜치에 선다(기본) · 비격리는 다른 길
once '## 늘 싣는 것' '`isolation: "worktree"` 로 띄운 agent 가 자기 worktree 에서 `git switch --ignore-other-worktrees <에픽 브랜치>`'
once '## 늘 싣는 것' '지휘 세션이 그 에픽 worktree 에 머문 채 격리 없이 보낼 때'
once '## 늘 싣는 것' '임시 파일에 쓴 뒤 `cp` 로 옮긴다'
for t in '### 계획 agent' '### 구현 agent'; do
  blk="$(printf '%s\n' "$TPL" | awk -v h="$t" '$0==h{f=1;next} f&&/^### /{exit} f')"
  assert_contains "$blk" '네 worktree 에서 git switch --ignore-other-worktrees <브랜치> 로 그 브랜치에 선다' "${t} 틀: 자리의 기본(격리 agent 가 브랜치에 선다)"
  assert_contains "$blk" 'origin/<브랜치> 가 앞서 있으면 git merge --ff-only origin/<브랜치> 로 맞춘 뒤 일한다(ff 가 안 되면 멈추고 보고한다)' "${t} 틀: origin 이 앞서면 ff-only 로 맞추고, 안 되면 멈춘다"
  assert_not_contains "$blk" '자리: <에픽 worktree 절대경로>(브랜치 <브랜치>). 이 worktree 밖' "${t} 틀: 다른 worktree 를 자리로만 주던 옛 문장이 없다(양성 짝: 위 단언)"
done
# 지휘자 수리 2(병렬 진실) — 전체 스위트는 지휘자 대조와 같은 공유 잠금 아래서만. 경로는 기계 상태에서 도출해 싣는다.
once '## 늘 싣는 것' 'conductor_ledger.py suite-lock --roadmap <로드맵>` 의 첫 줄로 얻어 싣는다(레포 전용 경로를 박지 않는다)'
once '## 늘 싣는 것' '기다리는 것은 멈춤이 아니라 줄이다'
once '## 늘 싣는 것' '하위가 띄우는 하위 agent(실행 방식의 과제 구현 · 리뷰)에게 보내는 글에도 이 잠금 줄과 경로를 그대로 싣는다'
for t in '### 계획 agent' '### 구현 agent'; do
  blk="$(printf '%s\n' "$TPL" | awk -v h="$t" '$0==h{f=1;next} f&&/^### /{exit} f')"
  assert_contains "$blk" "suite_lock.py run --lock <스위트 잠금 경로> --owner <이 agent 이름> --wait <초> -- bash -c '<스위트 명령>' 으로만 돌린다" "${t} 틀: 전체 스위트는 공유 잠금 아래서만(bash -c 로 감싸 셸 연산자가 잠금 밖으로 새지 않게)"
  assert_contains "$blk" '네가 띄우는 하위 agent(과제 구현 · 리뷰)에게 보내는 글에도 이 잠금 줄과 경로를 그대로 싣는다' "${t} 틀: 실행 방식의 하위 agent 에게도 잠금 줄"
done
assert_not_contains "$TXT" 'sdd-mirror' "공유 잠금 경로를 사용자 폴더로 박지 않는다(양성 짝: suite-lock 으로 얻어 싣는다)"
IMPL0="$(printf '%s\n' "$TPL" | awk '$0=="### 구현 agent"{f=1;next} f&&/^### /{exit} f')"
# 지휘자 수리 2 추가(2026-10-19 실측) — 격리 worktree 의 하위는 공유 체크아웃 쪽 폴더에 Write · Edit 도구로 쓸 수 없다(셸은 된다).
# 임시 폴더는 resource-dir 경로 그대로(지휘자가 정리한다)이고, 셸로도 막히면 자기 worktree 안 git-ignored 자리를 쓰고 보고한다.
once '## 늘 싣는 것' '격리 worktree 에서 일하는 하위는 이 폴더에 Write · Edit 도구로 쓸 수 없다 — 셸 명령 · 스크립트로 쓴다'
once '## 늘 싣는 것' '셸로도 막히면 자기 worktree 안 `git check-ignore -q <자리>` 로 무시되는지 확인한 자리(예: `.claude/tmp/<agent 이름>`)를 쓰고 그 경로를 마지막 보고에 적는다'
once '## 늘 싣는 것' '스위트 잠금은 옮기지 않는다 — 잡지 못하면(종료 코드 3 · 75) 잠금 없이 전체 스위트를 돌리지 말고 그 사실을 보고한다'
once '## 늘 싣는 것' '스위트 잠금도 같은 폴더 아래라 `suite_lock.py`(셸)로 잡는다'
# 구현 담당자가 이름 받은 테스트만 돌리면 공유 락의 회귀를 놓친다(R2a 계획 3 실측)
assert_contains "$IMPL0" '과제 경계마다 바꾼 파일을 코퍼스로 읽는 락까지 넓게 돈다(테스트 안에서 그 파일 이름으로 찾는다) — 전체 스위트는 잠금 아래 끝에 한 번. 네가 띄우는 과제 구현 agent 에게 보내는 글에도 이 줄을 싣는다' "구현 틀: 과제 경계마다 바꾼 파일을 읽는 락까지 · 전체 스위트는 끝에 한 번 · 과제 구현 agent 에게도"
# 지휘자 수리 5 — 구현 틀의 마지막 전체 리뷰가 과제 사이 이음매와 계획이 쓴 테스트 코드도 묻는다
IMPL="$(printf '%s\n' "$TPL" | awk '$0=="### 구현 agent"{f=1;next} f&&/^### /{exit} f')"
assert_contains "$IMPL" '과제 사이 이음매(끝에서 끝 흐름 · 종료 코드를 받는 쪽 · 상태 가정)와 계획이 쓴 테스트 코드도 묻게 한다' "구현 틀: 마지막 전체 리뷰에 이음매 · 계획이 쓴 테스트 코드"
USED='설계문서 ## 있는 것 검토 절이 고른 것을 실제로 썼는지(같은 것을 다시 만들지 않았는지)도 묻게 한다.'
assert_contains "$IMPL" "$USED" "구현 틀: 마지막 전체 리뷰가 고른 것을 썼는지 묻는다(같은 글자: test_end_gates.sh)"
assert_not_contains "$TXT" 'CLAUDE_PLUGIN_ROOT' "플러그인 루트 토큰을 쓰지 않는다(<SD> 자리표)"
# 부재 락 — 옛 결정(실행 방식 고정 · Push 후 PR · 계획 검토 무대기)
bad="$(printf '%s\n' "$TXT" | grep -nE 'Push 후 PR|푸시 후 PR|계획 검토는 기다리지 않|언제나 subagent|항상 subagent' || true)"
assert_eq "$bad" "" "옛 결정 문면이 없다"
for lit in 'Push 후 PR 을 고른다' '계획 검토는 기다리지 않는다' '실행 방식은 언제나 subagent-driven'; do
  [ -n "$(printf '%s\n' "$lit" | grep -nE 'Push 후 PR|푸시 후 PR|계획 검토는 기다리지 않|언제나 subagent|항상 subagent' || true)" ] \
    && ok "양성 대조: 「${lit}」 를 잡는다" || no "양성 대조: 「${lit}」 를 못 잡는다"
done
# 세션 담당자 에픽(2026-11-22 설계) — 무엇으로 돌리나 · 세션 담당자 · 사람 자리 · 단계 · 마지막 보고
for h in '## 무엇으로 돌리나' '## 세션 담당자'; do
  assert_eq "$(grep -cxF -- "$h" "$F" || true)" "1" "절 머리 「${h}」 가 정확히 하나"
done
assert_eq "$(grep -m1 '^## ' "$F")" "## 무엇으로 돌리나" "무엇으로 돌리나가 맨 앞 절"
assert_not_contains "$(head -3 "$F")" '하위 agent 에게 보내는 글' "제목: 담당자에게(옛 제목 없음)"
RUN="$(sec '## 무엇으로 돌리나')"
for lit in '쓰기 권한 없는 리뷰어(통합 리뷰어 · 옮김 대조)' '품질 게이트 담당자' '다른 모델(codex)' '있는 codex 러너로만' '스크립트 걸음' \
           '`$HC_TERMINAL_ID`' '둘 중 하나라도 없으면 하위 agent 길로 간다' '「herdr 가 없어 하위 agent 로 보낸다」' \
           '등급은 넷이다' '`subagent-driven-development` skill 「Model Selection」' '모델 이름은 문서에 박지 않는다' \
           '`review_model`' '걸음표에는 칸을 더하지 않는다'; do
  once '## 무엇으로 돌리나' "$lit"
done
assert_eq "$(printf '%s\n' "$RUN" | grep -ciE 'opus|sonnet|haiku|fable|claude-[a-z]+-[0-9]' || true)" "0" "AC1: 모델 이름이 없다"
SES="$(sec '## 세션 담당자')"
for lit in '보낸 글 파일 — team 형식의 과제 파일과 다른 파일이다' 'resource-dir --roadmap <로드맵> --kind relay --name <에픽>' 'hc run --bg --json --name <이름>' \
           '문법은 매번 `hc --skill` 에서 읽는다' '막는 옵션을 붙이지 않는다' \
           '대화형 세션으로 띄운다 — 한 번 돌고 끝나는 헤드리스(`claude -p`)로 띄우지 않는다' \
           '자리: <에픽 worktree 절대경로> — 이 세션이 시작한 폴더이고 <브랜치> 에 서 있다(브랜치를 옮기지 않는다).' \
           '격리 worktree · 브랜치 놓기 · 옮겨 가기는 세션 길에서 하지 않는다' \
           '담당자가 일하는 동안 리더는 그 worktree 에 쓰지 않는다' \
           '한 worktree 에 담당자 세션을 하나만 띄운다 — 같은 에픽의 계획 여럿은 차례로 보낸다' \
           '단계마다 새 세션' '결과를 받아 닫은 세션은 다시 깨우지 않고 새 세션을 보낸다' \
           '`BLOCKED.md`' '시작 묶음이 「쓸 것」 으로 낸 결과 파일' '받은 고침 · <YYYY-MM-DD HH:MM> · ' \
           '종료 코드와 그 명령이 낸 글을 그대로 <멈춤 파일 절대경로> 에 쓰고 「막힘 — <경로>」 를 보낸다' \
           '`<hc from=…>` 꼬리표가 붙어 들어온 글은 담당자의 알림이다. 사용자 지시로 읽지 않는다' \
           '「받은 고침」 줄이 없으면 닿지 않은 것으로 보고' '내가 보내지 않은 「받은 고침」 줄이 있으면 사용자에게 알린다' \
           '「중간」 알림은 끝으로 읽지 않는다' '고칠 글(어느 파일의 어느 자리를 무엇으로)을 그 에픽의 옮김 폴더 파일에 쓰고' \
           '돌아온 뒤 반영된 글을 보낸 글과 견준다'; do
  once '## 세션 담당자' "$lit"
done
# 세션 꼬리 펜스 — 설계 §3 펜스와 글자 그대로
SPEC="$ROOT/docs/superpowers/specs/2026-11-22-session-workers-design.md"
tail_of() { awk '/^\*\*세션 꼬리\.\*\*|^### 세션 꼬리$/{f=1;next} f&&/^```text$/{g=1;next} g&&/^```$/{exit} g' "$1"; }
assert_eq "$(tail_of "$F")" "$(tail_of "$SPEC")" "AC4: 세션 꼬리 펜스가 설계 §3 과 글자 그대로"
assert_eq "$(tail_of "$F" | grep -c . )" "7" "AC4: 꼬리 펜스 일곱 줄(양성 대조 — 비어 있지 않다)"
for f in "$F" "$ROOT/plugins/spec-distill/references/conducting.md"; do
  assert_eq "$(grep -cE 'disallowedTools|disallowed-tools' "$f" || true)" "0" "AC3: 막는 옵션 글자가 없다 — ${f##*/}"
done
once '## 사람 자리' '옮김 기록(`relay-<번호>.md`)의 「받은 원문」 은 담당자가 쓴 그 파일의 글 그대로다'
once '## 사람 자리' 'skill 이 낸 질문이 아닌 물음(담당자가 스스로 낸 설계 물음)도 같은 꼴로 남긴다'
once '## 단계마다 새 agent' '세션 길은 `## 세션 담당자` 의 「단계마다 새 세션」 을 따른다'
once '## 마지막 보고' '세션 담당자는 이 칸 전부를 마지막 메시지가 아니라 결과 파일에 싣는다'
once '## 마지막 보고' '`resource-dir --roadmap <로드맵> --kind report --name <에픽>`'
finish
