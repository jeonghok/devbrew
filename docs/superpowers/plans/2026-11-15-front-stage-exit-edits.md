# 앞단의 끝 (F4) — 바꿀 글 · 테스트 블록 · 시제품 패치

계획 `docs/superpowers/plans/2026-11-15-front-stage-exit.md` 의 짝 문서다. 계획의 과제가 「편집 F10」 · 「블록 T6」 · 「패치 A」 로 가리키는 글이 여기 있다. 전부 계획 단계에서 깨끗한 트리(브랜치 끝 6b923b62)에 과제 순서대로 걸어 돌려 본 글이다.

쓰는 법
- **바꿀 글(3절).** 편집마다 「찾을 글」 이 그 파일에 정확히 한 번 있는지 센 뒤 「바꿀 글」 로 바꾼다. 한 번이 아니면 고치지 말고 멈춰 보고한다(앞 과제가 그 줄을 이미 바꿨거나 기본 브랜치가 바뀐 것이다).
- **테스트 블록(4절).** 블록마다 넣을 자리가 적혀 있다. 테스트를 먼저 넣어 실패를 본 뒤 구현한다.
- **시제품 패치(5절).** 과제 2 · 5 · 8 · 9 의 코드와 테스트다. 패치가 그대로 걸리지 않으면(`git apply --check`) 손으로 옮기되, 옮긴 뒤 그 과제의 변이 표를 다시 잰다.
- **변이 표(6절).** 계획 단계의 결과다. 구현자는 같은 변이를 다시 걸어 표와 맞는지 본다 — 표는 증거가 아니라 기대값이다.

이 문서의 펜스는 물결(`~~~~`)로 감쌌다 — 안의 글이 백틱 펜스를 담기 때문이다.

## 1. 도구 셋

과제 1 이 `.claude/tmp/f4/` 에 쓴다(git 이 추적하지 않는다).

### recheck.sh — 설계가 근거로 든 자리 다시 보기

~~~~bash
#!/usr/bin/env bash
# 과제 1 — 설계문서가 근거로 든 자리가 지금 코드에서도 그런지 본다. 읽기만 한다.
# 쓰기(레포 루트에서): bash <이 파일>   → 줄마다 ok / NO, 끝에 합계. NO 가 하나라도 있으면 rc 1.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
SD=plugins/spec-distill
FIN=$SD/skills/pm-interview/references/finishing.md
CB=$SD/scripts/check_brief.py
SK=$SD/skills/pm-interview/SKILL.md
SAT=$SD/skills/pm-interview/references/saturation.md
RB=$SD/skills/reviewing-brief/SKILL.md
TPL=$SD/templates/interview-audit-template.md
bad=0
at() {   # at <파일> <줄> <그 줄에 있어야 할 글자> <설명>
  if sed -n "${2}p" "$1" | grep -qF -- "$3"; then echo "ok  $1:$2 — $4"; else echo "NO  $1:$2 — $4 (그 줄에 «${3}» 이 없다)"; bad=$((bad + 1)); fi
}
eq() {   # eq <얻은 값> <기대 값> <설명>
  if [ "$1" = "$2" ]; then echo "ok  $3 = $2"; else echo "NO  $3 — 기대 $2, 얻음 $1"; bad=$((bad + 1)); fi
}
eq "$(wc -l < "$FIN" | tr -d ' ')" "835" "finishing.md 줄 수"
eq "$(sed -n '553p' "$FIN" | python3 -I -c 'import sys; l = sys.stdin.read().rstrip("\n"); print(len(l) - 4)')" "2018" "553행 다음 세션 줄의 글자 수(인용 표시 넷을 뺀 수)"
at "$FIN" 20 '**사용자-승인 박제로 닫힌 floor**' "사용자-승인 박제 문단(20–22행)"
at "$FIN" 151 'audit §2 의 사건 줄' "다시 돌 때 사건 줄을 상태 파일에서 통째로 다시 쓴다"
at "$FIN" 434 '적은 뒤 구조 게이트를 다시 돕니다' "리뷰 뒤 이미 도는 구조 검사(434–440행)"
at "$FIN" 442 '#### B-1 — superpowers 가용성 분기' "B-1 머리"
at "$FIN" 444 '**정지(STOP)**' "superpowers 가 없으면 끝 화면 없이 멈춘다"
at "$FIN" 446 '커밋하지 않았다' "그때 커밋하지 않는다"
at "$FIN" 482 '4. **경고**' "게이트 앞 글의 경고 목록(482–503행)"
at "$FIN" 501 '`advisories` 도 게이트 앞 글(목록 4)에 씁니다' "구조 검사의 advisory 를 사람에게 넘기는 자리(501–503행)"
at "$FIN" 526 '선택지 넷의 개수 · 순서 · `(권장)` 은 어느 경우든 그대로' "B-2 의 선택지 넷 문장"
at "$FIN" 553 '사용자 선호: 이 brief 의 설계는 설계문서를 쓰는 크기다' "넘김 줄의 「사용자 선호:」 라벨"
at "$FIN" 555 '이 플러그인의 절대경로로 바꿔 노출한다' "자리표 치환 규칙(555–557행)"
at "$FIN" 560 '**다른 다음 단계의 줄 — 둘째 질문에서 제안을 골랐을 때.**' "다른 다음 단계의 줄"
at "$FIN" 565 '`check_brief.py gate` 재실행' "확정을 고른 뒤의 검사"
at "$FIN" 659 'B-1 superpowers 부재 정지' "B-R 의 갈래 목록"
at "$FIN" 666 'B-1 은 커밋하지 않고' "B-R 의 커밋 문장"
at "$FIN" 668 '④ · B-1 은 PR 을 열지 않는다' "PR 과 머지 절의 그 문장"
at "$FIN" 668 '판결 줄 없이 끝나면(시간 초과 · 끊김 포함) `NONE` 으로 읽는다' "판결 읽기 문장"
at "$FIN" 788 '상태를 다시 읽는다(15초까지)' "머지 뒤 상태 다시 읽기(788–797행)"
at "$FIN" 795 '[ "$n" -lt 4 ] || break' "다시 읽는 횟수 넷"
at "$FIN" 796 'sleep 5' "다시 읽는 간격 5초"
at "$FIN" 818 '/spec-distill:epic-conductor <roadmap-path>' "나눈 일의 넘김 줄은 이미 한 줄"
at "$FIN" 829 '(b) 게이트를 거치지 않는 예외' "B-4 의 예외 문장(829–830행)"
at "$CB" 1546 'MAPPER_RE = re.compile(' "MAPPER_RE(1546–1548행)"
at "$CB" 1547 '(unavailable:[^)]*)' "빈 이유도 받는 꼴"
at "$SK" 298 '필수 자리 둘' "필수 자리 둘 ①"
at "$SK" 386 '첫 호출 필수 자리 둘은 하한으로 남는다' "필수 자리 둘 ②"
at "$SK" 532 '필수 자리 둘' "필수 자리 둘 ③"
at "$SAT" 76 '조사가 두 묶음 미만' "판단만 남은 경로(76–80행)"
at "$SAT" 79 '사용자 판단 포화(@S<m>) — 조사 불필요' "사용자가 고르는 조사 불필요"
at "$RB" 237 'check_brief.py" gate "$PAYLOAD"' "리뷰 진입 검사가 구조 검사를 먼저 돈다(237–242행)"
at "$RB" 360 '조건을 산문으로 적지 않는다' "codex 는 리터럴 게이트(360행)"
at "$RB" 384 'codex 를 건너뛴 라운드' "잔존물 중화가 가용성 판정보다 앞(382–386행)"
at "$RB" 646 '`brief-readback` 은 리뷰가 아니라 가독성 **측정**' "읽어 보기는 라운드 밖(646–648행)"
at "$TPL" 40 '사유 없는 0은' "audit 템플릿 §2 의 옛 규칙 ①"
at "$TPL" 47 '줄이 없거나 마지막이' "audit 템플릿 §2 의 옛 규칙 ②"
eq "$(python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1]))["version"])' "$SD/.claude-plugin/plugin.json")" "8.14.0" "지금 판(머지된 PR #274 의 판)"
echo "합계: NO ${bad}개"
[ "$bad" -eq 0 ]
~~~~

### sweep.sh — 바뀌는 문장을 글자로 박아 둔 자리 찾기

~~~~bash
#!/usr/bin/env bash
# 과제 1 — 이 에픽이 바꾸는 문장을 글자로 박아 둔 자리(테스트 · 문서)를 찾는다. 읽기만 한다.
# 쓰기(레포 루트에서): bash <이 파일>   → 구절마다 그 구절이 있는 파일:줄. 설계문서 · 계획 · 옛 기록(docs/superpowers · docs/archive) · CHANGELOG 는 뺀다.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
while IFS= read -r p; do
  [ -n "$p" ] || continue
  echo "--- [${p}]"
  git grep -n -F -- "$p" -- . ':(exclude)docs/superpowers' ':(exclude)docs/archive' ':(exclude)plugins/spec-distill/CHANGELOG.md' | cut -d: -f1,2
done <<'PHRASES'
superpowers 가 없어 여기서 멈춘다
커밋하지 않았다 — 브랜치에서
superpowers 부재
정지(STOP)
loud advisory 후 정지
알린 뒤 멈추고
superpowers 있을 때만
B-1 은 커밋하지 않고
B-1 superpowers 부재 정지
게이트를 거치지 않는 예외
B-2 게이트를 다시 띄운다
사용자 선호: 이 brief
이 interview brief 로 Skill superpowers:brainstorming 을 시작하라
confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.
번호째 설계의 입력으로
번호째 입력으로
brief 의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다.
사람에게 쓰는 글의 낱말 규칙
check_bundle_coverage.py --plan 에
판 확인 문장
다른 다음 단계의 줄
필수 자리 둘
첫 호출 필수 자리
1회 필수로 dispatch
첫 dispatch 는 필수이고
네 때에 읽는다
coverage-mapper 0
unavailable:
사유 없는 0
포화 판정 줄 없음
cites no S<N> anchor
적은 뒤 구조 게이트를 다시 돕니다
이 skill 의 degrade 채널
판결 줄 없이
interview-merge
interview-pr
값의 출처
codex-gate
codex 리뷰를 건너뛰었다
recritic-skipped
PHRASES
~~~~

### narrow.sh — 좁은 러너

~~~~bash
#!/usr/bin/env bash
# 좁은 러너 — 주어진 낱말(파일 이름 등)을 읽는 테스트만 하나씩 돌려 FAILED 줄을 낸다. 전체 스위트가 아니다.
# 쓰기(레포 루트에서): bash <이 파일> <라벨> '<ERE 패턴>'   → .claude/tmp/f4/narrow-<라벨>.out (정렬된 FAILED 줄)
# 과제 1 이 고치기 전 기준선(base)을 뜨고, 과제마다 같은 패턴으로 다시 돌려 기준선과 diff 한다.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
LABEL="${1:?라벨}"; PAT="${2:?패턴}"
mkdir -p .claude/tmp/f4 || exit 2
OUT=".claude/tmp/f4/narrow-${LABEL}.out"
: > "$OUT"
n=0
while IFS= read -r f; do
  grep -qE -- "$PAT" "$f" || continue
  n=$((n + 1))
  o="$(bash "$f" 2>&1 < /dev/null)"; rc=$?
  names="$(printf '%s\n' "$o" | sed -nE 's/^ *(✗|FAIL:) //p')"
  if [ -n "$names" ]; then printf '%s\n' "$names" | sed "s|^|FAILED $f: |" >> "$OUT"
  elif [ "$rc" -ne 0 ]; then echo "FAILED $f: rc $rc(실패 표시 줄 없음)" >> "$OUT"; fi
done < <(find shared/tests plugins/spec-distill/tests -name 'test_*.sh' -not -path '*/spike/*' -not -path '*/fixtures/*' | LC_ALL=C sort)
while IFS= read -r f; do
  grep -qE -- "$PAT" "$f" || continue
  n=$((n + 1))
  o="$(python3 tools/suite/run_unittest_dir.py "$(dirname "$f")" "$(basename "$f")" 2>&1 < /dev/null)"; rc=$?
  printf '%s\n' "$o" | sed -nE '/^(FAIL|ERROR): /p' | sed "s|^|FAILED $f: |" >> "$OUT"
done < <(find plugins/spec-distill/tests -maxdepth 1 -name 'test_*.py' | LC_ALL=C sort)
LC_ALL=C sort -o "$OUT" "$OUT"
echo "테스트 ${n}개를 돌렸다 · FAILED 줄 $(grep -c . "$OUT")개 → $OUT"
~~~~

## 2. 새 파일 — brief-handoff.md

`plugins/spec-distill/references/brief-handoff.md` 전문(과제 3).

~~~~markdown
# brief 넘김 지시

넘김 줄이 가리킨 절 하나만 읽고 그 지시를 따른다. 이 파일의 `${CLAUDE_PLUGIN_ROOT}` 는 넘김 줄이 알려 준 플러그인 절대경로로 읽는다.

## brainstorming 지시

- brainstorming 을 불러온 직후 첫 메시지 전에 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_deps.py superpowers --plugin-root ${CLAUDE_PLUGIN_ROOT} --base 에 그 skill 을 불러올 때 보인 기준 폴더 경로를 넘겨 한 번 돌리고, 첫 줄이 「검증한 판과 같다」 가 아니면 그 줄을 첫 메시지에 한 줄로 보인다 — 판 확인 결과로는 멈추지 않는다.
- confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.
- brief 의 §2 확정 항목뿐 아니라 §3 열린 질문 · §4 조사 · §5 위험을 번호째 설계의 입력으로 읽는다 — /compact 요약에 기대지 말고 첨부한 brief 를 다시 읽는다.
- 설계문서에 ## 번호 대조 표(칸: 번호 · 반영/기각 · 자리 또는 이유)를 두어 brief 의 모든 번호와 brief frontmatter audit_file(같은 폴더) §6 의 S 번호를 싣고, 설계문서 frontmatter source_interview 에 이 brief 의 레포 루트 기준 상대경로를 적는다.
- 설계문서의 수용 기준은 ## Acceptance Criteria 아래 AC1 · AC2 … 처럼 번호를 단다.
- 설계의 규칙은 「기본은 X, 일의 모양이 다르면 모델이 판단하고 이유를 적는다」로 쓰고 정석 흐름(설계 → 계획 → 구현)의 의도는 지킨다.
- 설계문서에 ## 있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)과 ## 상류 · 하류 연계 절(이 일이 받는 곳 · 넘기는 곳 · 되돌아오는 길 · 같은 상태를 읽는 다른 표면)을 두고, 경로 · 테스트 명령 · 기본 브랜치 · 브랜치 이름 · 모델 같은 레포 전용 값은 박지 말고 도출하거나 레포 설정에서 읽게 설계한다.
- 이 brief 의 설계는 설계문서를 쓰는 크기다 — 질문을 건너뛰어도 설계문서를 쓰고 spec-review 를 거친다.
- brief 의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다.
- 설계문서를 쓰고 커밋한 뒤, brainstorming 의 설계문서 점검(builder check)과 그 질문을 마치고 문서를 승인받는 자리에서 그 설계문서 경로 뒤에 --bundle 과 source_interview 에 적은 것과 같은 상대경로를 붙여 Skill spec-distill:spec-review 를 부른다.
- superpowers:writing-plans 는 spec-review 의 승인 게이트에서 진행이 선택된 뒤에만 부른다.
- spec-review 가 게이트 없이 끝나면 brainstorming 의 문서 승인 자리로 돌아간다.
- writing-plans 가 계획을 쓴 뒤 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --plan 에 설계문서와 계획 경로를 넘겨 돌리고, 계획에 없는 AC 는 계획에 더한다.
- 고른 실행 방식의 마지막 전체 리뷰에 설계문서 ## Acceptance Criteria 의 AC 목록을 싣고, 리뷰가 AC 마다 한 줄씩 AC1: 구현됨 — 근거 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)로 보고하게 해 그 보고를 git 이 추적하지 않는 파일에 적는다.
- 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 ## 미룸 표(항목 · 이유 · 받는 곳)에 올리고, PR 을 만들기 전에 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --impl 에 설계문서와 보고 파일 경로를 넘겨 돌려 경고를 사용자에게 보인다.
- 사람에게 쓰는 글의 낱말 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에)을 지키고, 메시지 모양(첫 메시지 · 질문 하나 · 되비춤)은 brainstorming 을 따른다.

## 공통 지시

- confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.
- brief 의 §2 확정 항목뿐 아니라 §3 열린 질문 · §4 조사 · §5 위험을 번호째 입력으로 읽는다 — /compact 요약에 기대지 말고 첨부한 brief 를 다시 읽는다.
- brief 의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다.
- 사람에게 쓰는 글의 낱말 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에)을 지킨다.
- 부른 skill 이 `superpowers:` 로 시작하면 그 skill 을 불러온 직후 첫 메시지 전에 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_deps.py superpowers --plugin-root ${CLAUDE_PLUGIN_ROOT} --base 에 그 skill 을 불러올 때 보인 기준 폴더 경로를 넘겨 한 번 돌리고, 첫 줄이 「검증한 판과 같다」 가 아니면 그 줄을 첫 메시지에 한 줄로 보인다 — 판 확인 결과로는 멈추지 않는다.
~~~~

## 3. 바꿀 글

편집마다 「찾을 글」 은 그 파일에 정확히 한 번 있다(걸기 전에 센다 — 한 번이 아니면 멈춰 보고한다). 긴 찾을 글은 가운데를 줄여 보였다 — 그 줄 · 문단 전체가 대상이다.

### F1 맹점 건너뜀 floor (과제 4)

- 파일: `plugins/spec-distill/skills/pm-interview/references/finishing.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
아니라 「사용자가 지금은 안 하기로 했다」이므로, 다음 단계가 그것을 열린 질문으로 본다.
~~~~

바꿀 글:

~~~~
아니라 「사용자가 지금은 안 하기로 했다」이므로, 다음 단계가 그것을 열린 질문으로 본다.

**모델 판단으로 맹점 조사를 건너뛴 floor** — `floor:blind_spot` 의 `evidence` 가 `모델 판단으로 건너뜀` 으로
시작하면(audit §2 의 `맹점 조사` 건너뜀 줄과 짝이다) 사용자-승인 박제와 같은 길로 간다 — 그 내용을 payload
`## 3. Open Questions` 에 한 항목으로 옮겨 다음 단계가 열린 것으로 본다.
~~~~

### F2 mapper 0 건너뜀 (과제 4)

- 파일: `plugins/spec-distill/skills/pm-interview/references/finishing.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
   `coverage-mapper 0 (unavailable: <이유>)` — 게이트는 이를 advisory 로 통과시키고 Step B 가
   사람에게 보입니다.
~~~~

바꿀 글:

~~~~
   `coverage-mapper 0 (unavailable: <이유>)` — 게이트는 이를 advisory 로 통과시키고 Step B 가
   사람에게 보입니다.
   모델 판단으로 첫 범위 조사를 건너뛰었으면 `coverage-mapper 0` 으로 적는다 — 대기 줄 블록의
   `- 모델 판단으로 건너뜀 — 범위 조사: <이유>` 줄이 그 0 을 받친다(줄이 없으면 게이트가 막는다).
~~~~

### F16 나눈 일 사유를 줄 지우기로 넘기지 않는다 (과제 6)

- 파일: `plugins/spec-distill/skills/pm-interview/references/finishing.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
   위 3의 sentinel을 빠뜨리면 첫 게이트 실행이 항상 red입니다.
~~~~

바꿀 글:

~~~~
   위 3의 sentinel을 빠뜨리면 첫 게이트 실행이 항상 red입니다.
   사유가 「나눈 일은 건너뛸 수 없다」 면 건너뜀 줄만 지워 통과시키지 않는다 — B-S 대로 건너뛴 조사 · 리뷰를 돌린 뒤에 지운다.
~~~~

### F3 대기 줄 종류 (과제 4)

- 파일: `plugins/spec-distill/skills/pm-interview/references/finishing.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
상한 도달 · 판정 상한 도달 · 포화 판정 · 사용자 종료 줄이
   사건 순간 거기 쌓였습니다.
~~~~

바꿀 글:

~~~~
상한 도달 · 판정 상한 도달 · 포화 판정 · 사용자 종료 · 모델 판단으로 건너뜀 줄이
   사건 순간 거기 쌓였습니다.
~~~~

### F4 재제시 상한 선택지 설명 (과제 7)

- 파일: `plugins/spec-distill/skills/pm-interview/references/finishing.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
(B-3 확정 반영 절차) B-2 게이트를 다시 띄운다 — 다음 단계는 그 게이트에서 고른다."}
~~~~

바꿀 글:

~~~~
(B-3 확정 반영 절차) 왔던 끝 질문을 다시 띄운다 — 어떻게 끝낼지는 그 질문에서 고른다."}
~~~~

### F5 리뷰 뒤 다시 짓기 (과제 6)

- 파일: `plugins/spec-distill/skills/pm-interview/references/finishing.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
적은 뒤 구조 게이트를 다시 돕니다. failures 가 있으면 고치고 다시 돕니다:
~~~~

바꿀 글:

~~~~
적은 뒤 — 적을 참고 항목이 없어도 — audit §2 의 사건 줄을 상태 파일의 `## audit §2 대기 줄` 블록에서 다시 짓고 구조 게이트를 다시 돕니다.
리뷰가 그 블록에 더한 건너뜀 줄은 여기서 검사에 닿고, B-2 의 게이트 앞 글이 읽는 `advisories` 는 이 실행의 것입니다.
failures 가 있으면 고치고 다시 돕니다. 사유가 「나눈 일은 건너뛸 수 없다」 면 끝 질문을 띄우지 않고 아래 B-S 로 갑니다:
~~~~

### F6a B-S 절 (과제 6)

- 파일: `plugins/spec-distill/skills/pm-interview/references/finishing.md`

`#### B-1 — superpowers 가용성 분기` 제목 줄 바로 앞에 아래 절을 끼운다(절 끝에 빈 줄 하나):

~~~~
#### B-S — 건너뛴 것을 나중에 돌릴 때

두 경우에 온다 — 나누기로 정해 구조 게이트가 「나눈 일은 건너뛸 수 없다」 로 막았을 때와, 끝 질문(B-2 · B-1)의 기타 칸에
사용자가 건너뛴 것을 하라고 적었을 때. 새 길을 만들지 않고 지금 있는 길로 돌아간다. 건너뜀 줄의 집은 상태 파일의
`## audit §2 대기 줄` 블록이다 — 줄은 그 블록에서 지우고 audit §2 를 그 블록에서 다시 짓는다(audit 만 고치면 다음에 다시 지을 때 되살아난다).

- **조사(범위 조사 · 맹점 조사 · 포화 판정)** — 그 건너뜀 줄을 대기 줄 블록에서 지우고 Step A.5 의 「조사 계속」 갈래로 간다(라운드 루프로
  돌아가 그 조사를 돌리고, 다시 닫을 때 이 끝맺음을 처음부터 돈다). 맹점 조사를 건너뛴 차원은 다시 열려 지금 규칙대로 사용자 발화로 닫힌다.
- **재비판 · codex** — 그 건너뜀 줄을 대기 줄 블록에서 지우고 audit §2 를 다시 지은 뒤 `reviewing-brief` 를 한 라운드 더 돈다(탐지부터 —
  재리뷰 상한에 든다). 줄만 지우고 audit 을 그대로 두면 그 skill 의 진입 게이트가 옛 audit 으로 구조 게이트를 돌려 나눈 일은 다시 막힌다.
- **읽어 보기** — 그 건너뜀 줄을 지우고 audit §2 를 다시 지은 뒤 `reviewing-brief` 의 `## 냉독` 만 돌리고 끝 질문으로 돌아간다.
  리뷰 라운드를 다시 돌지 않고 재리뷰 상한을 쓰지 않는다.
- **나눈 일이라 게이트가 막았을 때** — 건너뛴 리뷰 부품을 모두 돌린다. 리뷰 부품의 줄(재비판 · codex · 읽어 보기)을 전부 지우고 audit §2 를
  다시 지은 뒤 리뷰 한 라운드를 돌고, 읽어 보기도 건너뛰었으면 그 라운드 뒤에 돌린다. 줄 하나만 지우면 남은 줄 때문에 진입 게이트가 다시 막는다.
  조사 줄이 남아 있으면 위 조사 갈래가 먼저다.
- **재리뷰 상한이 차 있으면** — 그 라운드는 `reviewing-brief` 의 `## 게이트` 가 정한 「추가 라운드 1회 열기」 질문의 답으로만 연다(끝 질문의 기타 칸에
  적은 말을 그 승인으로 쓰지 않는다). 사용자가 열지 않으면 지운 줄을 대기 줄 블록에 그대로 되돌리고 audit §2 를 다시 지은 뒤 끝 질문으로
  돌아간다 — 건너뛴 것이 그대로 보인다. 나눈 일이면 끝 질문으로 가지 못한다 — 줄을 되돌린 뒤
  `[spec-distill] 나눈 일은 건너뛴 리뷰 부품을 돌려야 끝낼 수 있다 — 추가 라운드를 열거나, 나누지 않기로 하면 그렇게 말해 달라.` 를 보이고 턴을 끝낸다.
- 어느 쪽이든 brief 가 바뀌면 리뷰를 다시 지난다 — 바뀐 brief 가 리뷰 없이 끝 질문에 닿지 않는다.
~~~~

### F6b B-1 의 「superpowers 부재 시」 갈래 (과제 7)

- 파일: `plugins/spec-distill/skills/pm-interview/references/finishing.md`

찾을 글(파일에 정확히 한 번 있다 — 불릿 줄 · 인용 줄 · 「분해된 일이면 끝 문장은」 줄까지 다섯 줄):

~~~~
- **superpowers 부재 시**: 현행 graceful degradation 그대로 — brief를 완료하고 **loud advisory**를 낸 뒤 **정지(STOP)**. 게이트 없음(다음 세션에 넘길 대상 자체가 없음). crash·spec-mode fallback **금지**(단독 완결, graceful degrade):

  > `[spec-distill] interview brief 를 만들었다: <payload 경로>. superpowers 가 없어 여기서 멈춘다. 이 brief 를 다음 작업의 입력으로 쓰세요. brief · audit · 상태 파일은 커밋하지 않았다 — 브랜치에서 직접 커밋하라.`

  분해된 일이면 끝 문장은 `brief · audit · 상태 파일 · 로드맵 폴더(<Step A 8 의 --out 값>)는 커밋하지 않았다 — 브랜치에서 함께 직접 커밋하라.` 다(B-R 다시 생성 뒤에 낸다).
~~~~

바꿀 글:

~~~~
- **superpowers 부재 시**: 다음 단계로 넘길 대상이 없어 B-2 의 proceed 게이트 대신 **선택지 셋의 따로 된 끝 질문**을 띄운다 — 공통 계약(`proceed-gate.md` Step B)의 질문이 아니다. crash·spec-mode fallback **금지**(단독 완결, graceful degrade).
  질문 앞에 B-0 의 확정 후보와 B-2 의 게이트 앞 글 목록(리뷰 게이트 결과 · 읽어 보기 · 남은 항목 · 경고 · 건너뛴 것)을 같은 순서 · 같은 규칙으로 보인다. superpowers 판 채널은 읽지 않는다(확인할 판이 없다). 질문의 상태 줄도 B-2 와 같은 꼴이다.

  ```javascript
  AskUserQuestion({
    questions: [{
      question: "interview brief 를 만들었다: <brief-path> (구조 검사 통과 · 리뷰 <게이트 결과 한 줄>). 경고 <N>개 — 위에 적었다 | 경고 없음 | 이상 없음. superpowers 가 없어 다음 단계로 넘기지 않는다. 어떻게 끝낼까?",
      header: "끝내기",
      options: [
        {label: "확정하고 끝낸다 (권장)", description: "확정 후보를 확정으로 바꿔 저장하고 커밋한 뒤 여기서 끝낸다. PR 은 열지 않는다."},
        {label: "확정 목록 수정", description: "확정 후보와 함께 보인 공시를 고쳐 다시 보여 준다(두 번 고친 뒤에는 계속할지 묻는다). 아직 아무것도 확정되지 않는다."},
        {label: "brief만 종료", description: "brief 를 여기서 끝낸다. 모든 항목이 잠정으로 남는다."}
      ],
      multiSelect: false
    }]
  })
  ```

  끝 질문의 답은 라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다.
  - **확정하고 끝낸다** — B-3 의 확정 반영 절차 → `check_brief.py gate` 재실행(통과 확인) → 분해된 일이면 B-R 다시 생성 → 커밋 펜스(`interview-commit`) → 여기서 멈춘다. 분해된 일이어도 「PR 과 머지」 로 가지 않는다. 끝에 `[spec-distill] superpowers 가 없어 다음 단계를 열지 못했다 — 설치한 뒤 새 세션에서 아래 줄로 잇는다.` 와 다음 세션 줄(하나짜리 일은 brief 줄, 분해된 일은 지휘자 줄 — 자리표 치환 규칙은 B-3 그대로)을 보인다. 분해된 일이면 그 앞에 지휘 세션을 이 커밋이 기본 브랜치에 머지된 뒤 열라고 한 줄로 알린다.
  - **확정 목록 수정** — B-3 의 ③ 과 같다. 고친 뒤에는 B-2 가 아니라 이 끝 질문을 다시 띄운다(재제시 상한 질문의 「지금 목록으로 확정」 도 이 끝 질문으로 돌아온다).
  - **brief만 종료** — B-3 의 ④ 와 같다.
  - 기타 칸에 「여기서 계속」 이 적히면 `[spec-distill] superpowers 가 없어 이어 갈 다음 단계가 없다.` 한 줄을 보이고 같은 질문을 다시 띄운다. 건너뛴 것을 하라는 말이면 B-S 로 간다.
~~~~

### F7 B-2 목록 4 뒤 건너뛴 것 (과제 6)

- 파일: `plugins/spec-distill/skills/pm-interview/references/finishing.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
   없을 때만 「이상 없음」, 남은 항목이 있으면 「경고 없음」 한 줄이다. 읽지 못한 채널은 「알 수 없음 — <사유>」
   로 따로 한 줄 쓴다.
~~~~

바꿀 글:

~~~~
   없을 때만 「이상 없음」, 남은 항목이 있으면 「경고 없음」 한 줄이다. 읽지 못한 채널은 「알 수 없음 — <사유>」
   로 따로 한 줄 쓴다.
   엔진의 재비판 경고 줄(「재비판이 돌지 않아 …」)은 괄호에 `kill switch` 라고 적혀 나온다 — `재비판` 건너뜀 줄이 있는 라운드면
   그 줄 끝에 「— 끄기 스위치가 아니라 모델 판단으로 건너뛰었다」 를 덧붙인다(엔진의 글자는 고치지 않는다).
5. **건너뛴 것 <N>개** — `check_brief.py gate` 의 `advisories` 가운데 `건너뜀 — ` 으로 시작하는 줄을 `- <자리>: <이유>` 로 한 줄씩 쓴다.
   이 줄들은 경고(목록 4)에 다시 쓰지 않되 질문의 「경고 N개」 에는 센다 — 건너뛴 것이 있으면 「이상 없음」 · 「경고 없음」 을 쓰지 않는다.
   재비판 · codex 를 건너뛴 라운드는 엔진이 그 부품이 돌지 않았다는 경고를 따로 낸다 — 그 경고는 목록 4 에 그대로 두고, 여기의 그 줄 끝에
   「(경고에도 있다)」 를 붙이며 경고 수에는 한 번만 센다. 항목 끝에 「하게 하려면 기타 칸에 적는다」 한 줄을 싣는다. 0개면 이 항목을 쓰지 않는다.
~~~~

### F8 기타 칸 건너뛴 것 (과제 6)

- 파일: `plugins/spec-distill/skills/pm-interview/references/finishing.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
**①② 이름 — 일의 모양에 따라.**
~~~~

바꿀 글:

~~~~
**기타 칸 — 건너뛴 것을 하라는 말.** 사용자가 기타 칸에 건너뛴 것을 하라고 적으면 B-S 로 간다. 그 말이 「여기서 계속」 인지 건너뛴 것을 하라는 것인지 불분명하면 다시 묻는다.

**①② 이름 — 일의 모양에 따라.**
~~~~

### F9 규약의 거처 (과제 3)

- 파일: `plugins/spec-distill/skills/pm-interview/references/finishing.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
아니라 **다음 세션 줄**(brainstorming 을 부르는 호출 프롬프트)에 싣습니다. brief는 순수 데이터
~~~~

바꿀 글:

~~~~
아니라 **다음 세션 줄**(brainstorming 을 부르는 호출 프롬프트)이 가리키는 지시 파일(`${CLAUDE_PLUGIN_ROOT}/references/brief-handoff.md`)에 싣습니다. brief는 순수 데이터
~~~~

### F10 다음 세션 줄 (과제 3)

- 파일: `plugins/spec-distill/skills/pm-interview/references/finishing.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
> `@<brief-path> 이 interview brief 로 Skill superpowers:brainstorming 을 시작하라. brainstorming 을 불러온 직후 첫 메시지 전에 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_deps.py superpowers --plugin-root ${CLAUDE_PLUGIN_ROOT} --base 에 그 skill 을 불러올 때 보인 기준 폴더 경로를 넘겨 한 번 돌리고, 첫
… (가운데 줄임 — 이 줄 · 문단 전체가 대상이다) …
coverage.py --impl 에 설계문서와 보고 파일 경로를 넘겨 돌려 경고를 사용자에게 보인다. 사람에게 쓰는 글의 낱말 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에)을 지키고, 메시지 모양(첫 메시지 · 질문 하나 · 되비춤)은 brainstorming 을 따른다.`
~~~~

바꿀 글:

~~~~
> `@<brief-path> 이 interview brief 로 Skill superpowers:brainstorming 을 시작하라. 시작하기 전에 ${CLAUDE_PLUGIN_ROOT}/references/brief-handoff.md 의 ## brainstorming 지시 절을 읽고 그 지시를 따른다 — 그 파일의 플러그인 루트 변수는 ${CLAUDE_PLUGIN_ROOT} 로 읽는다. 읽지 못하면 추측하지 말고 멈춰 보고한다.`
~~~~

### F11 다른 다음 단계의 줄 (과제 3)

- 파일: `plugins/spec-distill/skills/pm-interview/references/finishing.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
**다른 다음 단계의 줄 — 둘째 질문에서 제안을 골랐을 때.** ①/② 의 둘째 줄은 위 brief 줄 대신 정본 `## 다음 세션 명령` 규칙 3 대로 고른 skill 의 모양으로 짓고 `@<brief-path>` 를 원소로 삼는다. 줄에는 위 brief 줄의 공통 지시를 이 글자로 싣는다 — 「confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.」 · 「brief 의 §2 확정 항목뿐 아니라 §3 열린 질문 · §4 조사 · §5
… (가운데 줄임 — 이 줄 · 문단 전체가 대상이다) …
 skill 이 `superpowers:` 로 시작하면 위 brief 줄의 판 확인 문장도 `brainstorming` 을 그 skill 이름으로 바꿔 싣는다. 확정 반영 write 에서 brief frontmatter `next_phase:` 를 고른 skill 의 완전명으로 바꾼다.
~~~~

바꿀 글:

~~~~
**다른 다음 단계의 줄 — 둘째 질문에서 제안을 골랐을 때.** ①/② 의 둘째 줄은 위 brief 줄 대신 정본 `## 다음 세션 명령` 규칙 3 대로 고른 skill 의 모양으로 짓고 `@<brief-path>` 를 원소로 삼는다. 줄에는 공통 지시를 글자로 싣지 않고 이 문장을 싣는다 — 「시작하기 전에 ${CLAUDE_PLUGIN_ROOT}/references/brief-handoff.md 의 ## 공통 지시 절을 읽고 그 지시를 따른다 — 그 파일의 플러그인 루트 변수는 ${CLAUDE_PLUGIN_ROOT} 로 읽는다. 읽지 못하면 추측하지 말고 멈춰 보고한다.」 판 확인도 그 절의 끝 문장이 맡는다(부른 skill 이 `superpowers:` 로 시작할 때). 자리표 치환 · 거부 · 위치 공시는 위 brief 줄과 같다. 이 줄은 표지 블록 밖이라 인용 줄로 두지 않는다. 확정 반영 write 에서 brief frontmatter `next_phase:` 를 고른 skill 의 완전명으로 바꾼다.
~~~~

### F12 재제시 상한 질문의 답 (과제 7)

- 파일: `plugins/spec-distill/skills/pm-interview/references/finishing.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
「지금 목록으로 확정」은 확정 반영 절차를 적용한 뒤 B-2 게이트를 다시 띄우며
  스스로 멈추거나 넘기지 않는다 — 다음 단계는 그 게이트에서 고른다.
~~~~

바꿀 글:

~~~~
「지금 목록으로 확정」은 확정 반영 절차를 적용한 뒤 왔던 끝 질문(B-2 게이트 — superpowers 가 없어 B-1 의 끝 질문에서 왔으면 그 끝 질문)을 다시 띄우며
  스스로 멈추거나 넘기지 않는다 — 어떻게 끝낼지는 그 질문에서 고른다.
~~~~

### F13 B-R 갈래 목록 (과제 7)

- 파일: `plugins/spec-distill/skills/pm-interview/references/finishing.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
(① · ② · ④ · 재제시 상한 질문의 「brief 만 종료」(=④) · B-1 superpowers 부재 정지 — 「지금 목록으로 확정」은 B-2 로 돌아가 그 게이트의 갈래에서 한 번 돈다)에서, 그 갈래가 brief 를 마지막으로 쓴 직후 · 두 줄이나 정지 문구를 보이기 전에
~~~~

바꿀 글:

~~~~
(① · ② · ④ · 재제시 상한 질문의 「brief 만 종료」(=④) · B-1 끝 질문의 「확정하고 끝낸다」 · 「brief만 종료」 — 「지금 목록으로 확정」은 왔던 끝 질문으로 돌아가 그 질문의 갈래에서 한 번 돈다)에서, 그 갈래가 brief 를 마지막으로 쓴 직후 · 두 줄이나 끝 안내를 보이기 전에
~~~~

### F14 B-R 커밋 문장 (과제 7)

- 파일: `plugins/spec-distill/skills/pm-interview/references/finishing.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
세 파일과 한 커밋에 넣는다(B-1 은 커밋하지 않고 그 안내에 로드맵 폴더를 적는다). 분해된 일의 ①/② 는
~~~~

바꿀 글:

~~~~
세 파일과 한 커밋에 넣는다(B-1 끝 질문의 「확정하고 끝낸다」 · 「brief만 종료」 도 같은 펜스로 커밋한다). 분해된 일의 ①/② 는
~~~~

### F15 B-4 예외 (과제 7)

- 파일: `plugins/spec-distill/skills/pm-interview/references/finishing.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
  모든 경로는 (a) 위 proceed 게이트를 거치거나(①/②/③/④), (b) 게이트를 거치지 않는 예외
  (superpowers 부재 — B-1)면 명시적 advisory 단락을 동반해야 한다 — 게이트-less **silent 종료
  금지**.
~~~~

바꿀 글:

~~~~
  모든 경로는 (a) 위 proceed 게이트를 거치거나(①/②/③/④), (b) superpowers 가 없을 때의 B-1 끝 질문
  (선택지 셋)을 거친다 — 질문 없는 **silent 종료 금지**.
~~~~

### S1 필수 자리 ① 가리킴 (과제 4)

- 파일: `plugins/spec-distill/skills/pm-interview/SKILL.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
`blind-spot-prober`)과 조건 자리(`steelman-builder`)는 그대로다. 함께 띄운
~~~~

바꿀 글:

~~~~
`blind-spot-prober`)과 조건 자리(`steelman-builder`)는 그대로다(작은 일의 건너뜀은 `## 조사 상한 · 포화 판정` 의 「건너뜀」). 함께 띄운
~~~~

### S2 필수 자리 ② 규칙 정의 (과제 4)

- 파일: `plugins/spec-distill/skills/pm-interview/SKILL.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
첫 호출 필수 자리 둘은 하한으로 남는다.
~~~~

바꿀 글:

~~~~
첫 호출 필수 자리 둘은 하한으로 남는다.
**건너뜀.** 나누지 않을 작은 일로 보이면 필수 자리 둘과 포화 판정을 이유를 적고 건너뛸 수 있다 — 건너뛴 그 순간 state 본문 `## audit §2 대기 줄` 에
`- 모델 판단으로 건너뜀 — <자리>: <이유>` 한 줄을 덧붙인다(줄 모양은 아래 `Read` 줄의 파일 `### 건너뜀`). 나누기로 하면 건너뛴 조사를 그때 돌린다 —
나눈 일은 구조 게이트가 건너뜀 줄을 받지 않는다. 건너뛴 것은 끝 질문 앞에서 사용자에게 보이고, 사용자가 하라고 하면 그때 돌린다.
~~~~

### S3 필수 자리 ③ 가리킴 (과제 4)

- 파일: `plugins/spec-distill/skills/pm-interview/SKILL.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
blind_spot 차원의 첫 `blind-spot-prober` — 은 그대로).
~~~~

바꿀 글:

~~~~
blind_spot 차원의 첫 `blind-spot-prober` — 은 그대로이고, 작은 일의 건너뜀은 `## 조사 상한 · 포화 판정` 의 「건너뜀」 을 따른다).
~~~~

### S4 coverage-mapper 절 가리킴 (과제 4)

- 파일: `plugins/spec-distill/skills/pm-interview/SKILL.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
첫 dispatch 는 필수이고(하한) 그 뒤는 조사 호출 상한 하나가 총량을 묶는다:
~~~~

바꿀 글:

~~~~
첫 dispatch 는 필수이고(하한 — 작은 일의 건너뜀은 `## 조사 상한 · 포화 판정` 의 「건너뜀」) 그 뒤는 조사 호출 상한 하나가 총량을 묶는다:
~~~~

### S5 blind-spot 절 가리킴 (과제 4)

- 파일: `plugins/spec-distill/skills/pm-interview/SKILL.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
`blind-spot-prober`를 1회 필수로 dispatch 한다(하한).
~~~~

바꿀 글:

~~~~
`blind-spot-prober`를 1회 필수로 dispatch 한다(하한). 작은 일의 건너뜀은 `## 조사 상한 · 포화 판정` 의 「건너뜀」 을 따른다.
~~~~

### S6 지시 파일을 읽는 줄 (과제 3)

- 파일: `plugins/spec-distill/skills/pm-interview/SKILL.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
Read ${CLAUDE_PLUGIN_ROOT}/references/epic-handoff.md
```
~~~~

바꿀 글:

~~~~
Read ${CLAUDE_PLUGIN_ROOT}/references/epic-handoff.md
Read ${CLAUDE_PLUGIN_ROOT}/references/brief-handoff.md
```
~~~~

### S7 셋째 줄을 읽는 때 (과제 3)

- 파일: `plugins/spec-distill/skills/pm-interview/SKILL.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
둘째 줄(`epic-handoff.md`)은 로드맵 에픽의 설계를 여는 줄을 써야 할 때만 읽는다.
~~~~

바꿀 글:

~~~~
둘째 줄(`epic-handoff.md`)은 로드맵 에픽의 설계를 여는 줄을 써야 할 때만 읽는다.
셋째 줄(`brief-handoff.md`)은 끝 질문의 기타 칸에서 「여기서 계속」 을 받아 이 세션이 다음 세션 줄의 지시를 따를 때만 읽는다 — 그 밖에는 다음 세션이 읽는다.
~~~~

### T1 건너뜀 절 (과제 4)

- 파일: `plugins/spec-distill/skills/pm-interview/references/saturation.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
### audit §2 줄
~~~~

바꿀 글:

~~~~
### 건너뜀

나누지 않을 작은 일로 보이면 모델이 이유를 적고 건너뛸 수 있는 자리는 조사 쪽에 셋이다 — 범위 조사(첫 `coverage-mapper`) · 맹점 조사(첫
`blind-spot-prober`) · 포화 판정. 건너뛴 그 순간 대기 줄 블록에 자리마다 한 줄을 덧붙인다 — 같은 자리의 줄을 둘 두지 않는다:

- `- 모델 판단으로 건너뜀 — 범위 조사: <이유>` — audit §2 의 mapper 줄은 `coverage-mapper 0` 으로 적는다.
- `- 모델 판단으로 건너뜀 — 맹점 조사: <이유>` — 원장의 `floor:blind_spot` 은 `evidence` 를 `모델 판단으로 건너뜀 — <이유>` 로 적어 닫는다.
- `- 모델 판단으로 건너뜀 — 포화 판정: <이유>` — floor 다섯이 닫힌 뒤 판정자를 부르지 않고 `finishing.md` 로 간다. 포화 판정 줄이 이미 있으면
  이 줄을 쓰지 않는다(게이트는 판정 줄이 있으면 그 줄로 판정한다).

`<이유>` 는 비우지 않는다. 나누기로 정하면(분해 판단) 건너뛴 조사를 그때 돌리고 그 줄을 지운다 — 나눈 일은 구조 게이트가 건너뜀 줄을 받지 않는다.
리뷰 쪽 셋(재비판 · codex · 읽어 보기)의 줄은 결과물 리뷰 skill 이 같은 블록에 같은 모양으로 더한다.

### audit §2 줄
~~~~

### T2 줄 목록 (과제 4)

- 파일: `plugins/spec-distill/skills/pm-interview/references/saturation.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
- `- 사용자 종료(@S<m>) — 마지막 판정 아직`
~~~~

바꿀 글:

~~~~
- `- 사용자 종료(@S<m>) — 마지막 판정 아직`
- `- 모델 판단으로 건너뜀 — <범위 조사 | 맹점 조사 | 포화 판정 | 재비판 | codex | 읽어 보기>: <이유>`
~~~~

### T3 읽는 때 (과제 4)

- 파일: `plugins/spec-distill/skills/pm-interview/references/saturation.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
이 파일은 네 때에 읽는다: state 를 처음 만들 때(`### 상한 값` 만), 조사 호출 합이 `research_limit` 에 닿을 때,
~~~~

바꿀 글:

~~~~
이 파일은 다섯 때에 읽는다: state 를 처음 만들 때(`### 상한 값` 만), 조사나 판정을 모델 판단으로 건너뛸 때(`### 건너뜀`), 조사 호출 합이 `research_limit` 에 닿을 때,
~~~~

### R1 건너뜀 절 (과제 5)

- 파일: `plugins/spec-distill/skills/reviewing-brief/SKILL.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
## 진입 게이트 — 매 라운드, 번들보다 먼저
~~~~

바꿀 글:

~~~~
## 건너뜀 — 모델 판단

나누지 않은 작은 일의 brief 면 이 자리의 부품 셋 — 재비판 · codex · 읽어 보기(냉독) — 을 이유를 적고 건너뛸 수 있다. 탐지(첫 검토)는 건너뛰지 않는다 —
리뷰 전체를 건너뛰면 쓴 쪽이 스스로 통과시킨다(Law 2). brief §7 에 `분해됨 — ` 줄이 있으면(나눈 일) 아무것도 건너뛰지 않는다 — 구조 게이트가 그 규칙을 받친다.

- **기록.** 건너뛰는 그 라운드에 상태 파일(`$STATE`) 본문 `## audit §2 대기 줄` 에 `- 모델 판단으로 건너뜀 — <재비판 | codex | 읽어 보기>: <이유>` 한 줄을 더한다.
  줄은 자리마다 하나이고 마지막 라운드의 사실을 말한다 — 그 자리의 줄이 이미 있으면 이유만 바꿔 쓰고, 앞 라운드에서 건너뛴 부품을 이번 라운드에 돌렸으면 그 줄을 지운다.
  이 줄은 호출자(`finishing.md` B-A 끝)가 audit §2 를 다시 지어 구조 게이트에 닿게 하고 끝 질문 앞에서 사용자에게 보인다.
- **재비판** — 6단계 dispatch 를 하지 않고 7단계 라우팅을 `--recritic` 대신 `--recritic-skipped` 로 돌린다(엔진에 있는 길). 엔진이 재비판이 돌지 않았다는 경고를 낸다.
- **codex** — codex 펜스를 통째로 건너뛰지 않고 그대로 돌린다. 펜스 머리의 `DEVBREW_MODEL_SKIP_EOF` 두 줄 사이 빈 줄을 이유 한 줄로 바꿔 돌린다 — 따옴표로 감싸지 않고 글자 그대로, 그 밖의 줄은 고치지 않는다(이유에 그 구분 줄과 똑같은 줄을 쓰지 않는다).
  펜스가 직전 산출물을 지운 뒤 러너만 부르지 않는다. 펜스가 `(reason: model_skip)` 을 냈을 때만 건너뜀 줄을 더한다 — 다른 사유가 나왔으면 모델이 건너뛴 라운드가 아니다.
- **읽어 보기** — `## 냉독` 을 돌리지 않고 Step B 로 넘기는 둘째 항목에 「읽어 보기를 건너뛰었다 — <이유>」 를 싣는다.
- 끄기 스위치로 꺼진 부품에는 건너뜀 줄을 쓰지 않는다 — 스위치가 끈 것과 모델이 건너뛴 것은 다른 사실이고, 스위치 쪽은 지금의 degrade 기록이 말한다. 그 기록은 그대로 남긴다.
- 건너뛴 것을 나중에 돌리는 길은 호출자의 `#### B-S` 가 정한다.

## 진입 게이트 — 매 라운드, 번들보다 먼저
~~~~

### M1 흐름 그림 (과제 10)

- 파일: `plugins/spec-distill/README.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
④brief만 종료  (superpowers 있을 때만)
~~~~

바꿀 글:

~~~~
④brief만 종료  (superpowers 가 없으면 선택지 셋의 끝 질문 — 확정하고 끝낸다 · 확정 목록 수정 · brief만 종료)
~~~~

### M2 핸드오프 문구의 자리 (과제 10)

- 파일: `plugins/spec-distill/README.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
근거는 인터뷰 핸드오프 문구(`finishing.md` 의 다음 세션 줄, brief 템플릿 §7)
~~~~

바꿀 글:

~~~~
근거는 인터뷰 핸드오프 문구(`finishing.md` 의 다음 세션 줄이 가리키는 지시 파일 `references/brief-handoff.md`, brief 템플릿 §7)
~~~~

### M3 reference 목록 (과제 10)

- 파일: `plugins/spec-distill/README.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
- `references/conducting.md` — 지휘 순환 걸음 1~7
~~~~

바꿀 글:

~~~~
- `references/brief-handoff.md` — 인터뷰 끝의 다음 세션 줄이 가리키는 지시 파일. 절이 둘이다 — brainstorming 으로 가는 세션이 읽는 「brainstorming 지시」 와 다른 다음 단계로 가는 세션이 읽는 「공통 지시」.
- `references/conducting.md` — 지휘 순환 걸음 1~7
~~~~

### M4 Prerequisites superpowers (과제 10)

- 파일: `plugins/spec-distill/README.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
없으면 interview는 brief를 완료하고 loud advisory 후 정지 (단독 완결, AC13).
~~~~

바꿀 글:

~~~~
없으면 interview는 brief 를 완료하고 선택지 셋의 끝 질문(확정하고 끝낸다 · 확정 목록 수정 · brief만 종료)으로 확정 · 커밋까지 간 뒤 다음 단계로 넘기지 않고 끝낸다 (단독 완결).
~~~~

### M5 판정 없는 종료와 건너뜀 (과제 10)

- 파일: `plugins/spec-distill/README.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
구조 게이트(`check_brief.py` `saturation_failures`)가 판정 없는 종료를 거절한다.
~~~~

바꿀 글:

~~~~
구조 게이트(`check_brief.py` `saturation_failures`)가 판정 없는 종료를 거절한다 — 나누지 않은 작은 일에서 모델이 이유를 적고 건너뛴 경우만 받고(건너뜀 줄), 그 건너뜀은 끝 질문 앞에서 사용자에게 보인다.
~~~~

### D1 superpowers 없을 때 (과제 10)

- 파일: `plugins/spec-distill/dependencies.md`

찾을 글(파일에 정확히 한 번 있다):

~~~~
없으면 인터뷰는 brief 까지 만들고 알린 뒤 멈추고, 지휘자 · 로드맵 흐름은 진입에서 멈춘다
~~~~

바꿀 글:

~~~~
없으면 인터뷰는 brief 까지 만들고 끝 질문으로 확정 · 커밋한 뒤 다음 단계로 넘기지 않고 끝내며, 지휘자 · 로드맵 흐름은 진입에서 멈춘다
~~~~

## 4. 테스트 블록

### 블록 T3-a (과제 3) — 다음 세션 줄 · 지시 파일

- 파일: `plugins/spec-distill/tests/test_review_handoff_order.sh`
- 자리: `ONE="$(nsl "$FIN")"` 줄부터 `assert_file_absent "$FIN" '/compact interview brief at'` 줄 앞까지를 이 블록으로 통째로 바꾼다. 그리고 `# guards:` 줄 끝과 `--emit-scanned` 목록 끝(`exit 0` 앞)에 `plugins/spec-distill/references/brief-handoff.md` 를 더한다.

~~~~bash
BH="$ROOT/plugins/spec-distill/references/brief-handoff.md"
bh_sec() { awk -v h="## $2" '$0==h{f=1;next} f&&/^## /{exit} f' "$1"; }   # bh_sec <파일> <절 이름> → 그 절의 본문
bh_items() { bh_sec "$1" "$2" | sed -n 's/^- //p'; }                        # 그 절의 불릿 문장(불릿을 뗀 글)
POINT_BS='시작하기 전에 ${CLAUDE_PLUGIN_ROOT}/references/brief-handoff.md 의 ## brainstorming 지시 절을 읽고 그 지시를 따른다 — 그 파일의 플러그인 루트 변수는 ${CLAUDE_PLUGIN_ROOT} 로 읽는다. 읽지 못하면 추측하지 말고 멈춰 보고한다.'
POINT_CM='시작하기 전에 ${CLAUDE_PLUGIN_ROOT}/references/brief-handoff.md 의 ## 공통 지시 절을 읽고 그 지시를 따른다 — 그 파일의 플러그인 루트 변수는 ${CLAUDE_PLUGIN_ROOT} 로 읽는다. 읽지 못하면 추측하지 말고 멈춰 보고한다.'
# 옛 다음 세션 줄의 지시 문장 열여섯 — 그 순서 그 글자(「사용자 선호:」 라벨만 뗐다).
cat > "$TMP/want_bs.txt" <<'WANT'
brainstorming 을 불러온 직후 첫 메시지 전에 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_deps.py superpowers --plugin-root ${CLAUDE_PLUGIN_ROOT} --base 에 그 skill 을 불러올 때 보인 기준 폴더 경로를 넘겨 한 번 돌리고, 첫 줄이 「검증한 판과 같다」 가 아니면 그 줄을 첫 메시지에 한 줄로 보인다 — 판 확인 결과로는 멈추지 않는다.
confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.
brief 의 §2 확정 항목뿐 아니라 §3 열린 질문 · §4 조사 · §5 위험을 번호째 설계의 입력으로 읽는다 — /compact 요약에 기대지 말고 첨부한 brief 를 다시 읽는다.
설계문서에 ## 번호 대조 표(칸: 번호 · 반영/기각 · 자리 또는 이유)를 두어 brief 의 모든 번호와 brief frontmatter audit_file(같은 폴더) §6 의 S 번호를 싣고, 설계문서 frontmatter source_interview 에 이 brief 의 레포 루트 기준 상대경로를 적는다.
설계문서의 수용 기준은 ## Acceptance Criteria 아래 AC1 · AC2 … 처럼 번호를 단다.
설계의 규칙은 「기본은 X, 일의 모양이 다르면 모델이 판단하고 이유를 적는다」로 쓰고 정석 흐름(설계 → 계획 → 구현)의 의도는 지킨다.
설계문서에 ## 있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)과 ## 상류 · 하류 연계 절(이 일이 받는 곳 · 넘기는 곳 · 되돌아오는 길 · 같은 상태를 읽는 다른 표면)을 두고, 경로 · 테스트 명령 · 기본 브랜치 · 브랜치 이름 · 모델 같은 레포 전용 값은 박지 말고 도출하거나 레포 설정에서 읽게 설계한다.
이 brief 의 설계는 설계문서를 쓰는 크기다 — 질문을 건너뛰어도 설계문서를 쓰고 spec-review 를 거친다.
brief 의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다.
설계문서를 쓰고 커밋한 뒤, brainstorming 의 설계문서 점검(builder check)과 그 질문을 마치고 문서를 승인받는 자리에서 그 설계문서 경로 뒤에 --bundle 과 source_interview 에 적은 것과 같은 상대경로를 붙여 Skill spec-distill:spec-review 를 부른다.
superpowers:writing-plans 는 spec-review 의 승인 게이트에서 진행이 선택된 뒤에만 부른다.
spec-review 가 게이트 없이 끝나면 brainstorming 의 문서 승인 자리로 돌아간다.
writing-plans 가 계획을 쓴 뒤 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --plan 에 설계문서와 계획 경로를 넘겨 돌리고, 계획에 없는 AC 는 계획에 더한다.
고른 실행 방식의 마지막 전체 리뷰에 설계문서 ## Acceptance Criteria 의 AC 목록을 싣고, 리뷰가 AC 마다 한 줄씩 AC1: 구현됨 — 근거 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)로 보고하게 해 그 보고를 git 이 추적하지 않는 파일에 적는다.
미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 ## 미룸 표(항목 · 이유 · 받는 곳)에 올리고, PR 을 만들기 전에 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --impl 에 설계문서와 보고 파일 경로를 넘겨 돌려 경고를 사용자에게 보인다.
사람에게 쓰는 글의 낱말 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에)을 지키고, 메시지 모양(첫 메시지 · 질문 하나 · 되비춤)은 brainstorming 을 따른다.
WANT
# 「다른 다음 단계의 줄」 이 글자로 싣던 네 문장 + 판 확인 한 문장.
cat > "$TMP/want_cm.txt" <<'WANT'
confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.
brief 의 §2 확정 항목뿐 아니라 §3 열린 질문 · §4 조사 · §5 위험을 번호째 입력으로 읽는다 — /compact 요약에 기대지 말고 첨부한 brief 를 다시 읽는다.
brief 의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다.
사람에게 쓰는 글의 낱말 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에)을 지킨다.
부른 skill 이 `superpowers:` 로 시작하면 그 skill 을 불러온 직후 첫 메시지 전에 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_deps.py superpowers --plugin-root ${CLAUDE_PLUGIN_ROOT} --base 에 그 skill 을 불러올 때 보인 기준 폴더 경로를 넘겨 한 번 돌리고, 첫 줄이 「검증한 판과 같다」 가 아니면 그 줄을 첫 메시지에 한 줄로 보인다 — 판 확인 결과로는 멈추지 않는다.
WANT
ONE="$(nsl "$FIN")"
n1="$(grep -cE '^[[:space:]]*> `(@<[^<>]+> )+이 interview brief 로' "$FIN" || true)"
if nonempty "다음 세션 줄" "$ONE"; then
  assert_eq "$n1" "1" "다음 세션 줄 모양의 인용 줄이 finishing.md 에 정확히 하나 (①·② 가 따로 정의하지 않는다)"
  assert_eq "$(split_line "$ONE" first)" "@<brief-path>" "다음 세션 줄의 첫 토큰은 @<brief-path> (주 산출물)"
  # F4 AC1 — 줄은 brief 첨부 · 시작 문장 · 지시 파일을 가리키는 문장뿐이다(등호 — 문장 하나가 더 붙어도 실패한다)
  assert_eq "$(split_line "$ONE" rest)" "이 interview brief 로 Skill superpowers:brainstorming 을 시작하라. ${POINT_BS}" "F4 AC1: 다음 세션 줄은 시작 문장과 지시 파일을 가리키는 문장뿐이다"
  assert_eq "$(lead_only "$ONE")" "ok" "다음 세션 줄 안의 꺾쇠 자리표는 줄 앞 @<…> 토큰의 이름뿐이다"
  assert_eq "$(lead_only '@<a> x <a> y')" "ok" "꺾쇠 규칙: 줄 앞 토큰의 이름은 줄 안에 다시 쓸 수 있다"
  assert_eq "$(lead_only '@<a> x <b> y')" "no" "꺾쇠 규칙 양성 대조: 줄 앞 토큰에 없는 이름은 거부한다"
  # F4 AC2 — 지시 파일의 brainstorming 절이 옛 줄의 지시 문장을 그 순서 그 글자로 싣는다(등호 — 빠짐 · 순서 바뀜 · 더해짐 모두 실패)
  [ -f "$BH" ] && ok "지시 파일이 있다: references/brief-handoff.md" || no "지시 파일이 없다: references/brief-handoff.md"
  GOT_BS="$(bh_items "$BH" 'brainstorming 지시')"
  assert_eq "$(printf '%s\n' "$GOT_BS" | grep -c .)" "16" "F4 AC2(양성 대조): brainstorming 지시 절에서 문장 열여섯을 읽었다"
  assert_eq "$GOT_BS" "$(cat "$TMP/want_bs.txt")" "F4 AC2: brainstorming 지시 절이 옛 줄의 지시 문장을 순서대로 모두 싣는다"
  assert_not_contains "$(bh_sec "$BH" 'brainstorming 지시')" '사용자 선호:' "F4 AC2: 「사용자 선호:」 라벨이 없다(양성 짝: 라벨 뗀 그 문장은 위 등호가 본다)"
  # F4 AC1 — 옛 지시 문장은 줄에 하나도 없다(양성 짝: 같은 문장이 지시 파일에 있다 — 위 등호)
  k=0
  while IFS= read -r s; do
    k=$((k + 1))
    assert_not_contains "$ONE" "$s" "F4 AC1: 옛 지시 문장 ${k} 이 다음 세션 줄에 없다"
  done < "$TMP/want_bs.txt"
  assert_eq "$k" "16" "F4 AC1(양성 대조): 옛 지시 문장 열여섯을 줄과 대조했다"
  # AC8 · AC16 — 순서는 지시 절 안에서 잰다
  INS="$(printf '%s\n' "$GOT_BS" | tr '\n' ' ')"
  order "brainstorming 지시 절" "$INS" "check_deps.py" "spec-distill:spec-review"
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
    assert_contains "$OTHER" '판 확인도 그 절의 끝 문장이 맡는다' "F4 AC3: 판 확인은 그 절의 끝 문장이 맡는다"
    GOT_CM="$(bh_items "$BH" '공통 지시')"
    assert_eq "$GOT_CM" "$(cat "$TMP/want_cm.txt")" "F4 AC3: 공통 지시 절이 네 문장과 판 확인 문장을 싣는다"
    k=0
    while IFS= read -r s; do
      k=$((k + 1))
      assert_not_contains "$OTHER" "$s" "F4 AC3: 공통 지시 문장 ${k} 이 문단에 글자로 없다"
    done < "$TMP/want_cm.txt"
    assert_eq "$k" "5" "F4 AC3(양성 대조): 공통 지시 문장 다섯을 문단과 대조했다"
  fi
  sed 's/Skill superpowers:brainstorming 을 시작하라\./Skill superpowers:brainstorming 을 시작하라. brainstorming 의 「다음은 writing-plans 뿐」 지시보다 이 순서가 우선한다./' "$FIN" > "$TMP/fin_mut.md"
  case "$(nsl "$TMP/fin_mut.md")" in
    *"보다 이 순서가 우선한다"*) ok "변이(AC15): 덮어쓰기 문장을 되넣으면 같은 추출이 그것을 본다 — AC1 부재 단언에 이빨이 있다" ;;
    *) no "변이(AC15): 되넣은 덮어쓰기 문장을 추출이 못 본다 — 부재 단언이 공허하다" ;;
  esac
fi
~~~~

### 블록 T3-b (과제 3) — 「다른 다음 단계의 줄」 의 needle

- 파일: `plugins/spec-distill/tests/test_end_gates.sh`
- 그 밖에 셋: (1) `assert_contains "$BL" "$SHARED" "AC22: brief 줄의 원칙 문장이 에픽 넘김 줄과 글자가 같다"` 한 줄을 `assert_contains "$BSS" "$SHARED" "AC22: brief 지시 파일의 원칙 문장이 에픽 넘김 줄과 글자가 같다"` 와 `assert_not_contains "$BL" "$SHARED" "F4 AC1: 그 원칙 문장은 brief 줄에 글자로 없다(양성 짝: 위 단언)"` 두 줄로 바꾼다. (2) `--emit-scanned` 의 `echo "plugins/spec-distill/references/epic-handoff.md"` 줄 뒤에 `echo "plugins/spec-distill/references/brief-handoff.md"` 줄을 더한다. (3) `# guards:` 줄의 `…/references/epic-handoff.md` 뒤에 `plugins/spec-distill/references/brief-handoff.md` 를 더한다.

찾을 글(정확히 한 번):

~~~~bash
for lit in '`@<brief-path>` 를 원소로' 'confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.' \
           '§3 열린 질문 · §4 조사 · §5 위험을 번호째 입력으로 읽는다' \
           'brief 의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다.' \
           '사람에게 쓰는 글의 낱말 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에)을 지킨다.' \
           '`next_phase:` 를 고른 skill 의 완전명으로 바꾼다' '인용 줄로 두지 않는다'; do
  assert_contains "$NEWP" "$lit" "AC23: 「다른 다음 단계의 줄」 문단 «${lit}»"
done
~~~~

바꿀 글:

~~~~bash
for lit in '`@<brief-path>` 를 원소로' '줄에는 공통 지시를 글자로 싣지 않고' \
           '/references/brief-handoff.md 의 ## 공통 지시 절을 읽고 그 지시를 따른다' \
           '`next_phase:` 를 고른 skill 의 완전명으로 바꾼다' '인용 줄로 두지 않는다'; do
  assert_contains "$NEWP" "$lit" "AC23: 「다른 다음 단계의 줄」 문단 «${lit}»"
done
# F4 AC3 — 공통 지시 네 문장은 문단이 아니라 지시 파일의 `## 공통 지시` 절에 산다(양성 짝: 문단에는 없다)
BHF="$SD/references/brief-handoff.md"
bhsec() { awk -v h="## $1" '$0==h{f=1;next} f&&/^## /{exit} f' "$BHF" | tr '\n' ' ' | tr -s ' '; }
CMS="$(bhsec '공통 지시')"; BSS="$(bhsec 'brainstorming 지시')"
[ -n "$CMS" ] && [ -n "$BSS" ] && ok "F4(양성 대조): 지시 파일의 두 절을 떴다" || no "F4: 지시 파일의 절 부재"
for lit in 'confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.' \
           '§3 열린 질문 · §4 조사 · §5 위험을 번호째 입력으로 읽는다' \
           'brief 의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다.' \
           '사람에게 쓰는 글의 낱말 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에)을 지킨다.'; do
  assert_contains "$CMS" "$lit" "F4 AC3: 공통 지시 절 «${lit}»"
  assert_not_contains "$NEWP" "$lit" "F4 AC3: 「다른 다음 단계의 줄」 문단에는 글자로 없다 «${lit}»"
done
~~~~

### 블록 T3-c (과제 3) — 낱말 규칙 구절의 자리

- 파일: `plugins/spec-distill/tests/test_plain_gate_templates.sh`
- 자리: `# brainstorming 으로 넘기는 줄(finishing.md)은 낱말 규칙만 싣는다` 주석 줄부터 `# 꺾쇠 자리표는 줄 앞 \`@<…>\` 토큰에만 있다` 주석 줄 앞까지를 이 블록으로 통째로 바꾼다(그 위의 `nsl()` 정의 줄은 그대로 둔다).

~~~~bash
# brainstorming 으로 넘기는 줄(finishing.md)은 지시 파일을 가리키고, 낱말 규칙 문장은 그 파일의 두 절에 한 줄씩 산다(F4 AC1 · AC2).
BHF="$(dirname "$PG")/brief-handoff.md"
phrase='사람에게 쓰는 글의 낱말 규칙'
l="$(nsl "$FIN")"
[ -n "$l" ] && ok "AC7(양성): finishing.md 의 다음 세션 줄을 읽었다" || no "AC7(양성): finishing.md 에 다음 세션 줄 표지 블록이 없다 — 아래 단언이 공허하다"
assert_contains "$l" '/references/brief-handoff.md 의 ## brainstorming 지시 절을 읽고 그 지시를 따른다' "F4 AC1: finishing.md 의 다음 세션 줄이 지시 파일의 절을 가리킨다"
assert_eq "$(grep -c "${phrase}(번호·해시는" "$FIN" || true)" "0" "F4 AC1: finishing.md 는 낱말 규칙 문장을 글자로 싣지 않는다(양성 짝: 아래 지시 파일 단언)"
assert_eq "$(grep -c "^- ${phrase}(번호·해시는" "$BHF" || true)" "2" "F4 AC2: 지시 파일에서 그 구절이 든 줄은 정확히 2개다(두 절에 하나씩)"
for sec in 'brainstorming 지시' '공통 지시'; do
  n="$(awk -v h="## ${sec}" '$0==h{f=1;next} f&&/^## /{exit} f' "$BHF" | grep -c "^- ${phrase}(번호·해시는" || true)"
  assert_eq "$n" "1" "F4 AC2: 지시 파일의 「${sec}」 절이 규칙 유지 문장을 한 줄 싣는다"
done
f="$RS"; rphrase='사람에게 쓰는 글 규칙'
l="$(nsl "$f")"; who="${f#"$REPO_ROOT"/}"
[ -n "$l" ] && ok "AC7(양성): ${who} 의 다음 세션 줄을 읽었다" || no "AC7(양성): ${who} 에 다음 세션 줄 표지 블록이 없다 — 아래 단언이 공허하다"
assert_eq "$(printf '%s' "$l" | grep -oF "$rphrase" | wc -l | tr -d ' ')" "1" "AC7: ${who} 의 다음 세션 줄이 규칙 유지 문장을 싣는다"
assert_eq "$(grep -E '^> `' "$f" | grep -c "${rphrase}(번호·해시는" || true)" "1" "AC7: ${who} 에서 그 구절은 인용 줄(다음 세션 줄) 한 곳뿐이다"
assert_eq "$(grep -c "${rphrase}(번호·해시는" "$f" || true)" "1" "AC7: ${who} 에서 그 구절이 든 줄은 정확히 1개다"
OTHER="$(awk -v m='**다른 다음 단계의 줄 — 둘째 질문에서 제안을 골랐을 때.**' 'index($0,m)==1{print}' "$FIN")"
[ -n "$OTHER" ] && ok "AC7(양성): finishing.md 의 「다른 다음 단계의 줄」 문단을 읽었다" || no "AC7(양성): 「다른 다음 단계의 줄」 문단 부재"
assert_contains "$OTHER" '/references/brief-handoff.md 의 ## 공통 지시 절을 읽고 그 지시를 따른다' "F4 AC3: 「다른 다음 단계의 줄」 문단이 공통 지시 절을 가리킨다"
assert_not_contains "$(nsl "$FIN")" '첫 줄에 상태, 끝에 할 일 하나' "지휘자 수리 2: brainstorming 으로 넘기는 줄은 메시지 순서 규칙을 싣지 않는다(양성 짝: 지시 파일 단언)"
~~~~

### 블록 T3-d (과제 3) — C4 가 사는 자리

- 파일: `plugins/spec-distill/tests/test_conducting_interview_stage.sh`

찾을 글(정확히 한 번):

~~~~bash
grep -qF '보고 후 재결정' <<<"$nsl_b3" \
  && ok "AC3: C4 프로토콜이 ①·② 공통 다음 세션 줄에 실림" \
  || no "AC3: B-3 의 다음 세션 줄에 C4 프로토콜이 없다"
grep -qE '임의 변경.*금지' <<<"$nsl_b3" \
  && ok "AC3: 임의 변경 금지 절반이 다음 세션 줄에 있다" || no "AC3: 다음 세션 줄에 임의 변경 금지가 없다"
~~~~

바꿀 글:

~~~~bash
# F4 — C4 는 다음 세션 줄이 가리키는 지시 파일의 brainstorming 절에 산다(줄은 그 절을 가리킨다)
bh_bs="$(awk '$0=="## brainstorming 지시"{f=1;next} f&&/^## /{exit} f' "$REPO_ROOT/plugins/spec-distill/references/brief-handoff.md")"
grep -qF '/references/brief-handoff.md 의 ## brainstorming 지시 절을 읽고 그 지시를 따른다' <<<"$nsl_b3" \
  && ok "AC3: ①·② 공통 다음 세션 줄이 지시 파일의 brainstorming 절을 가리킨다" \
  || no "AC3: B-3 의 다음 세션 줄이 지시 파일을 가리키지 않는다"
grep -qF '보고 후 재결정' <<<"$bh_bs" \
  && ok "AC3: C4 프로토콜이 지시 파일의 brainstorming 절에 실림" \
  || no "AC3: 지시 파일의 brainstorming 절에 C4 프로토콜이 없다"
grep -qE '임의 변경.*금지' <<<"$bh_bs" \
  && ok "AC3: 임의 변경 금지 절반이 지시 파일의 brainstorming 절에 있다" || no "AC3: 지시 파일의 brainstorming 절에 임의 변경 금지가 없다"
~~~~

### 블록 T4-a (과제 4) — 건너뜀 규칙(조사 쪽)

- 파일: `plugins/spec-distill/tests/test_saturation_reference.sh`
- 자리: 마지막 `finish` 줄 바로 앞.

~~~~bash
# F4 AC9 · AC14 — 건너뜀 규칙(조사 쪽 셋): SKILL 이 한 번 정하고 네 곳이 그것을 가리킨다 · saturation.md 가 줄 모양과 때를 적는다
SKIP_FLAT="$(awk '/^### 건너뜀/{f=1;print;next} /^### /{f=0} f' "$SAT" | tr '\n' ' ' | tr -s ' ')"
[[ -n "$SKIP_FLAT" ]] && ok "F4: saturation.md 「### 건너뜀」 절을 떴다" || no "F4: saturation.md 「### 건너뜀」 절 부재 — 아래가 공허하다"
for lit in '`- 모델 판단으로 건너뜀 — 범위 조사: <이유>` — audit §2 의 mapper 줄은 `coverage-mapper 0` 으로 적는다.' \
           '`- 모델 판단으로 건너뜀 — 맹점 조사: <이유>` — 원장의 `floor:blind_spot` 은 `evidence` 를 `모델 판단으로 건너뜀 — <이유>` 로 적어 닫는다.' \
           '`- 모델 판단으로 건너뜀 — 포화 판정: <이유>` — floor 다섯이 닫힌 뒤 판정자를 부르지 않고 `finishing.md` 로 간다.' \
           '포화 판정 줄이 이미 있으면 이 줄을 쓰지 않는다' \
           '같은 자리의 줄을 둘 두지 않는다' \
           '`<이유>` 는 비우지 않는다.' \
           '나누기로 정하면(분해 판단) 건너뛴 조사를 그때 돌리고 그 줄을 지운다 — 나눈 일은 구조 게이트가 건너뜀 줄을 받지 않는다.' \
           '리뷰 쪽 셋(재비판 · codex · 읽어 보기)의 줄은 결과물 리뷰 skill 이 같은 블록에 같은 모양으로 더한다.'; do
  grep -qF -- "$lit" <<<"$SKIP_FLAT" && ok "F4 AC9: saturation.md 건너뜀 «${lit}»" || no "F4 AC9: saturation.md 건너뜀 «${lit}» 부재"
done
LINES_FLAT="$(awk '/^### audit §2 줄/{f=1;print;next} /^### /{f=0} f' "$SAT" | tr '\n' ' ' | tr -s ' ')"
grep -qF -- '- `- 모델 판단으로 건너뜀 — <범위 조사 | 맹점 조사 | 포화 판정 | 재비판 | codex | 읽어 보기>: <이유>`' <<<"$LINES_FLAT" \
  && ok "F4 AC9: audit §2 줄 목록에 건너뜀 줄 모양(자리 여섯)" || no "F4 AC9: audit §2 줄 목록에 건너뜀 줄 모양 부재"
grep -qF '조사나 판정을 모델 판단으로 건너뛸 때(`### 건너뜀`)' <<<"$(awk 'NR>2&&/^$/{exit} NR>2' "$SAT" | tr '\n' ' ' | tr -s ' ')" \
  && ok "F4: saturation.md 첫 문단의 읽는 때에 건너뛸 때" || no "F4: saturation.md 첫 문단에 건너뛸 때 부재 — 그 절이 읽히지 않는다"
for lit in '**건너뜀.** 나누지 않을 작은 일로 보이면 필수 자리 둘과 포화 판정을 이유를 적고 건너뛸 수 있다' \
           '`- 모델 판단으로 건너뜀 — <자리>: <이유>` 한 줄을 덧붙인다' \
           '나누기로 하면 건너뛴 조사를 그때 돌린다' \
           '건너뛴 것은 끝 질문 앞에서 사용자에게 보이고, 사용자가 하라고 하면 그때 돌린다.'; do
  grep -qF -- "$lit" <<<"$CAP_FLAT" && ok "F4 AC9 · AC14: SKILL 조사 상한 절 «${lit}»" || no "F4 AC9 · AC14: SKILL 조사 상한 절 «${lit}» 부재"
done
[[ "$(grep -oF '**건너뜀.**' "$SKILL" | grep -c .)" == "1" ]] && ok "F4 AC9: 건너뜀 규칙은 SKILL 에 한 번만 정한다" || no "F4 AC9: SKILL 의 「**건너뜀.**」 이 한 번이 아니다"
[[ "$(grep -oF '작은 일의 건너뜀은 `## 조사 상한 · 포화 판정` 의 「건너뜀」' "$SKILL" | grep -c .)" == "4" ]] \
  && ok "F4 AC9: 필수 자리를 말하는 네 곳이 그 규칙을 가리킨다" || no "F4 AC9: 건너뜀 규칙을 가리키는 줄이 넷이 아니다"
FIN_FLAT_F4="$(tr '\n' ' ' < "$FIN" | tr -s ' ')"
for lit in '**모델 판단으로 맹점 조사를 건너뛴 floor**' \
           '사용자-승인 박제와 같은 길로 간다 — 그 내용을 payload `## 3. Open Questions` 에 한 항목으로 옮겨 다음 단계가 열린 것으로 본다.' \
           '모델 판단으로 첫 범위 조사를 건너뛰었으면 `coverage-mapper 0` 으로 적는다' \
           '사용자 종료 · 모델 판단으로 건너뜀 줄이 사건 순간 거기 쌓였습니다.'; do
  grep -qF -- "$lit" <<<"$FIN_FLAT_F4" && ok "F4 AC9: finishing.md «${lit}»" || no "F4 AC9: finishing.md «${lit}» 부재"
done
~~~~

### 블록 T4-b (과제 4) — R2 의 가리킴

- 파일: `plugins/spec-distill/tests/test_open_research.sh`
- 자리: `"AC14: R2 — 필수 자리 둘을 이름으로 댄다"` 로 끝나는 줄 바로 뒤.

~~~~bash
assert_contains "$R2" '은 그대로이고, 작은 일의 건너뜀은 `## 조사 상한 · 포화 판정` 의 「건너뜀」 을 따른다' "F4 AC9: R2 — 필수 자리의 건너뜀은 조사 상한 절의 규칙을 가리킨다"
~~~~

### 블록 T5-a (과제 5) — 건너뜀 규칙(리뷰 부품)

- 파일: `plugins/spec-distill/tests/test_reviewing_brief_skill.sh`
- 자리: 마지막 `finish` 줄 바로 앞.

~~~~bash
# F4 AC9 · AC14 — 건너뜀 규칙(리뷰 부품 셋): 탐지는 건너뛰지 않는다 · 줄은 대기 줄 블록에 · 끄기 스위치와 다른 사실
W_SKIP="$(section '건너뜀 — 모델 판단' | tr '\n' ' ' | tr -s ' ')"
[ -n "$W_SKIP" ] && ok "F4: 「## 건너뜀 — 모델 판단」 절을 떴다" || no "F4: 「## 건너뜀 — 모델 판단」 절 부재 — 아래가 공허하다"
for lit in '이 자리의 부품 셋 — 재비판 · codex · 읽어 보기(냉독) — 을 이유를 적고 건너뛸 수 있다.' \
           '탐지(첫 검토)는 건너뛰지 않는다' \
           'brief §7 에 `분해됨 — ` 줄이 있으면(나눈 일) 아무것도 건너뛰지 않는다' \
           '`## audit §2 대기 줄` 에 `- 모델 판단으로 건너뜀 — <재비판 | codex | 읽어 보기>: <이유>` 한 줄을 더한다.' \
           '그 자리의 줄이 이미 있으면 이유만 바꿔 쓰고, 앞 라운드에서 건너뛴 부품을 이번 라운드에 돌렸으면 그 줄을 지운다.' \
           '6단계 dispatch 를 하지 않고 7단계 라우팅을 `--recritic` 대신 `--recritic-skipped` 로 돌린다' \
           'codex 펜스를 통째로 건너뛰지 않고 그대로 돌린다.' \
           '펜스 머리의 `DEVBREW_MODEL_SKIP_EOF` 두 줄 사이 빈 줄을 이유 한 줄로 바꿔 돌린다' \
           '따옴표로 감싸지 않고 글자 그대로, 그 밖의 줄은 고치지 않는다' \
           '펜스가 직전 산출물을 지운 뒤 러너만 부르지 않는다.' \
           '펜스가 `(reason: model_skip)` 을 냈을 때만 건너뜀 줄을 더한다' \
           '`## 냉독` 을 돌리지 않고 Step B 로 넘기는 둘째 항목에 「읽어 보기를 건너뛰었다 — <이유>」 를 싣는다.' \
           '끄기 스위치로 꺼진 부품에는 건너뜀 줄을 쓰지 않는다' \
           '그 기록은 그대로 남긴다.' \
           '건너뛴 것을 나중에 돌리는 길은 호출자의 `#### B-S` 가 정한다.'; do
  has "$W_SKIP" "$lit" && ok "F4 AC9 · AC14: 건너뜀 절 «${lit}»" || no "F4 AC9 · AC14: 건너뜀 절 «${lit}» 부재"
done
~~~~

### 블록 T6 (과제 6) — 건너뛴 것 보이기 · 다시 짓기 · B-S

- 파일: `plugins/spec-distill/tests/test_end_gates.sh`
- 자리: `# CHANGELOG · README — 사람에게 보이는 글은 내부 단계 이름 대신 쉬운 말로` 주석 줄 바로 앞.

~~~~bash
# F4 AC8 · AC14 — 건너뛴 것 보이기(B-2) · 리뷰 뒤 다시 짓기(B-A) · 건너뛴 것을 나중에 돌리는 길(B-S)
BSW="$(win "$FIN" '^#### B-S' '^#### ')"
[ -n "$BSW" ] && ok "F4(양성 대조): B-S 를 떴다" || no "F4: B-S 부재 — 아래가 공허하다"
for lit in '5. **건너뛴 것 <N>개** — `check_brief.py gate` 의 `advisories` 가운데 `건너뜀 — ` 으로 시작하는 줄을 `- <자리>: <이유>` 로 한 줄씩 쓴다.' \
           '이 줄들은 경고(목록 4)에 다시 쓰지 않되 질문의 「경고 N개」 에는 센다 — 건너뛴 것이 있으면 「이상 없음」 · 「경고 없음」 을 쓰지 않는다.' \
           '「(경고에도 있다)」 를 붙이며 경고 수에는 한 번만 센다.' \
           '항목 끝에 「하게 하려면 기타 칸에 적는다」 한 줄을 싣는다.' \
           '0개면 이 항목을 쓰지 않는다.' \
           '그 줄 끝에 「— 끄기 스위치가 아니라 모델 판단으로 건너뛰었다」 를 덧붙인다(엔진의 글자는 고치지 않는다).' \
           '**기타 칸 — 건너뛴 것을 하라는 말.** 사용자가 기타 칸에 건너뛴 것을 하라고 적으면 B-S 로 간다.' \
           '그 말이 「여기서 계속」 인지 건너뛴 것을 하라는 것인지 불분명하면 다시 묻는다.'; do
  assert_contains "$B2" "$lit" "F4 AC8: B-2 «${lit}»"
done
for lit in '적은 뒤 — 적을 참고 항목이 없어도 — audit §2 의 사건 줄을 상태 파일의 `## audit §2 대기 줄` 블록에서 다시 짓고 구조 게이트를 다시 돕니다.' \
           '리뷰가 그 블록에 더한 건너뜀 줄은 여기서 검사에 닿고, B-2 의 게이트 앞 글이 읽는 `advisories` 는 이 실행의 것입니다.' \
           '사유가 「나눈 일은 건너뛸 수 없다」 면 끝 질문을 띄우지 않고 아래 B-S 로 갑니다:'; do
  assert_contains "$BA" "$lit" "F4 AC8: B-A «${lit}»"
done
for lit in '줄은 그 블록에서 지우고 audit §2 를 그 블록에서 다시 짓는다' \
           '그 건너뜀 줄을 대기 줄 블록에서 지우고 Step A.5 의 「조사 계속」 갈래로 간다' \
           '맹점 조사를 건너뛴 차원은 다시 열려 지금 규칙대로 사용자 발화로 닫힌다.' \
           '`reviewing-brief` 를 한 라운드 더 돈다(탐지부터 — 재리뷰 상한에 든다).' \
           '줄만 지우고 audit 을 그대로 두면 그 skill 의 진입 게이트가 옛 audit 으로 구조 게이트를 돌려 나눈 일은 다시 막힌다.' \
           '`reviewing-brief` 의 `## 냉독` 만 돌리고 끝 질문으로 돌아간다.' \
           '리뷰 라운드를 다시 돌지 않고 재리뷰 상한을 쓰지 않는다.' \
           '리뷰 부품의 줄(재비판 · codex · 읽어 보기)을 전부 지우고 audit §2 를 다시 지은 뒤 리뷰 한 라운드를 돌고, 읽어 보기도 건너뛰었으면 그 라운드 뒤에 돌린다.' \
           '줄 하나만 지우면 남은 줄 때문에 진입 게이트가 다시 막는다.' \
           '「추가 라운드 1회 열기」 질문의 답으로만 연다' \
           '사용자가 열지 않으면 지운 줄을 대기 줄 블록에 그대로 되돌리고 audit §2 를 다시 지은 뒤 끝 질문으로 돌아간다' \
           '`[spec-distill] 나눈 일은 건너뛴 리뷰 부품을 돌려야 끝낼 수 있다 — 추가 라운드를 열거나, 나누지 않기로 하면 그렇게 말해 달라.` 를 보이고 턴을 끝낸다.' \
           '어느 쪽이든 brief 가 바뀌면 리뷰를 다시 지난다 — 바뀐 brief 가 리뷰 없이 끝 질문에 닿지 않는다.'; do
  assert_contains "$BSW" "$lit" "F4 AC14: B-S «${lit}»"
done
assert_contains "$SA" '사유가 「나눈 일은 건너뛸 수 없다」 면 건너뜀 줄만 지워 통과시키지 않는다 — B-S 대로 건너뛴 조사 · 리뷰를 돌린 뒤에 지운다.' "F4 AC14: Step A 의 게이트 걸음이 나눈 일 사유를 줄 지우기로 넘기지 않는다"
~~~~

### 블록 T7-a (과제 7) — B-1 의 끝 질문

- 파일: `plugins/spec-distill/tests/test_superpowers_presence.sh`
- 자리: `assert_contains "$absent" "brief를 완료하고"` 줄부터 `printf '%s\n' "$B1" > "$TMP/b1.md"` 줄 앞까지(옛 단언 넷)를 이 블록으로 바꾼다.

~~~~bash
assert_contains "$absent" "**선택지 셋의 따로 된 끝 질문**을 띄운다" "F4 AC10: superpowers 가 없으면 끝 질문을 띄운다"
assert_contains "$absent" "공통 계약(\`proceed-gate.md\` Step B)의 질문이 아니다" "F4 AC10: 그 질문은 공통 계약의 질문이 아니다"
assert_contains "$absent" "crash·spec-mode fallback **금지**" "finishing.md B-1: crash · spec-mode fallback 금지는 그대로다"
assert_eq "$(printf '%s\n' "$B1" | grep -c '^        {label: ')" "3" "F4 AC10: 끝 질문의 선택지는 셋이다"
for lit in '{label: "확정하고 끝낸다 (권장)", description: "확정 후보를 확정으로 바꿔 저장하고 커밋한 뒤 여기서 끝낸다. PR 은 열지 않는다."},' \
           '{label: "확정 목록 수정", description: "확정 후보와 함께 보인 공시를 고쳐 다시 보여 준다(두 번 고친 뒤에는 계속할지 묻는다). 아직 아무것도 확정되지 않는다."},' \
           '{label: "brief만 종료", description: "brief 를 여기서 끝낸다. 모든 항목이 잠정으로 남는다."}' \
           'B-2 의 게이트 앞 글 목록(리뷰 게이트 결과 · 읽어 보기 · 남은 항목 · 경고 · 건너뛴 것)을 같은 순서 · 같은 규칙으로 보인다.' \
           '질문의 상태 줄도 B-2 와 같은 꼴이다.' \
           '커밋 펜스(`interview-commit`) → 여기서 멈춘다. 분해된 일이어도 「PR 과 머지」 로 가지 않는다.' \
           '`[spec-distill] superpowers 가 없어 다음 단계를 열지 못했다 — 설치한 뒤 새 세션에서 아래 줄로 잇는다.`' \
           '분해된 일이면 그 앞에 지휘 세션을 이 커밋이 기본 브랜치에 머지된 뒤 열라고 한 줄로 알린다.' \
           '고친 뒤에는 B-2 가 아니라 이 끝 질문을 다시 띄운다' \
           '`[spec-distill] superpowers 가 없어 이어 갈 다음 단계가 없다.` 한 줄을 보이고 같은 질문을 다시 띄운다.' \
           '건너뛴 것을 하라는 말이면 B-S 로 간다.'; do
  assert_contains "$B1" "$lit" "F4 AC10: B-1 «${lit}»"
done
assert_not_contains "$(cat "$FIN")" 'superpowers 가 없어 여기서 멈춘다' "F4 AC10: 옛 멈춤 안내가 없다(양성 짝: 위 단언)"
~~~~

### 블록 T7-b (과제 7) — B-0 · B-3 · B-R · B-4

- 파일: `plugins/spec-distill/tests/test_end_gates.sh`
- 자리: 블록 T6 바로 뒤(같은 주석 줄 앞).

~~~~bash
# F4 AC10 — superpowers 가 없을 때의 끝 질문: B-0 · B-3 · B-R · B-4 가 새 동작에 맞는다
B0="$(win "$FIN" '^#### B-0' '^#### ')"; B4="$(win "$FIN" '^#### B-4' '^#### ')"
[ -n "$B0" ] && [ -n "$B4" ] && ok "F4(양성 대조): B-0 · B-4 를 떴다" || no "F4: B-0 · B-4 부재 — 아래가 공허하다"
assert_contains "$B0" '왔던 끝 질문을 다시 띄운다 — 어떻게 끝낼지는 그 질문에서 고른다.' "F4: 재제시 상한 질문의 「지금 목록으로 확정」 설명이 왔던 끝 질문으로 돌아간다고 말한다"
assert_contains "$B3" '왔던 끝 질문(B-2 게이트 — superpowers 가 없어 B-1 의 끝 질문에서 왔으면 그 끝 질문)을 다시 띄우며' "F4: 「지금 목록으로 확정」 이 돌아갈 자리"
assert_not_contains "$B0$B3" 'B-2 게이트를 다시 띄운다 — 다음 단계는 그 게이트에서 고른다' "F4: 옛 「B-2 게이트를 다시 띄운다」 가 없다(양성 짝: 위 두 단언)"
assert_contains "$BR" 'B-1 끝 질문의 「확정하고 끝낸다」 · 「brief만 종료」 — 「지금 목록으로 확정」은 왔던 끝 질문으로 돌아가 그 질문의 갈래에서 한 번 돈다' "F4 AC10: B-R 의 갈래 목록에 끝 질문의 두 갈래"
assert_contains "$BR" '(B-1 끝 질문의 「확정하고 끝낸다」 · 「brief만 종료」 도 같은 펜스로 커밋한다)' "F4 AC10: 끝 질문의 두 갈래도 커밋한다"
assert_not_contains "$BR" 'B-1 은 커밋하지 않고' "F4 AC10: 옛 「B-1 은 커밋하지 않고」 가 없다(양성 짝: 위 단언)"
assert_contains "$B4" '(b) superpowers 가 없을 때의 B-1 끝 질문 (선택지 셋)을 거친다 — 질문 없는 **silent 종료 금지**.' "F4 AC10: Step B 를 끝내는 경로는 proceed 게이트와 B-1 끝 질문 둘이다"
assert_not_contains "$B4" '게이트를 거치지 않는 예외' "F4 AC10: 옛 「게이트를 거치지 않는 예외」 가 없다(양성 짝: 위 단언)"
assert_contains "$B2" '선택지 넷의 개수 · 순서 · `(권장)` 은 어느 경우든 그대로' "F4 AC10: B-2 게이트의 선택지 넷 문장은 그대로다"
~~~~

### 블록 T7-c (과제 7) — 옛 문장을 단언하던 자리

### T7-c ① 미커밋 안내

- 파일: `plugins/spec-distill/tests/test_interview_state_flow.sh`

찾을 글(정확히 한 번):

~~~~bash
grep -qF 'brief · audit · 상태 파일은 커밋하지 않았다' "$FIN" && ok "B-1: superpowers 부재 안내가 세 파일을 커밋하지 않았다고 말한다" || no "B-1: 미커밋 안내가 없다"
~~~~

바꿀 글:

~~~~bash
grep -qF '확정 후보를 확정으로 바꿔 저장하고 커밋한 뒤 여기서 끝낸다. PR 은 열지 않는다.' "$FIN" && ok "B-1: superpowers 가 없는 끝 질문의 「확정하고 끝낸다」 가 커밋한다고 말한다" || no "B-1: 끝 질문의 커밋 설명이 없다"
grep -qF '브랜치에서 직접 커밋하라' "$FIN" && no "B-1: 옛 미커밋 안내가 남았다" || ok "B-1: 옛 미커밋 안내가 없다(양성 짝: 위 단언)"
~~~~

### T7-c ② 커밋 펜스 자리(파이썬 조각 안의 한 줄)

- 파일: `plugins/spec-distill/tests/test_interview_state_flow.sh`

찾을 글(정확히 한 번):

~~~~python
ok = (0 <= a < a5 < b3 < gate < c) and nocommit(t[a:b3]) and nocommit(t[three:four])
~~~~

바꿀 글:

~~~~python
b1, b2 = t.find("#### B-1"), t.find("#### B-2")
ok = (0 <= a < a5 < b1 < b2 < b3 < gate < c) and nocommit(t[a:b1]) and nocommit(t[b2:b3]) and nocommit(t[three:four])
# B-1 의 끝 질문은 커밋 펜스를 한 번 부른다(「확정하고 끝낸다」) — 펜스 자체는 B-3 에만 있다
ok = ok and t[b1:b2].count("interview-commit") == 1 and "git commit" not in t[b1:b2]
~~~~

### T7-c ③ 분해된 일의 안내

- 파일: `plugins/spec-distill/tests/test_decompose_surface.sh`

찾을 글(정확히 한 번):

~~~~bash
has "$B1" 'brief · audit · 상태 파일 · 로드맵 폴더(<Step A 8 의 --out 값>)는 커밋하지 않았다' "B-1: 분해된 일의 미커밋 안내에 로드맵 폴더"
~~~~

바꿀 글:

~~~~bash
has "$B1" '분해된 일이어도 「PR 과 머지」 로 가지 않는다' "B-1: 분해된 일이어도 끝 질문의 확정은 PR 을 열지 않는다"
has "$B1" '분해된 일이면 그 앞에 지휘 세션을 이 커밋이 기본 브랜치에 머지된 뒤 열라고 한 줄로 알린다' "B-1: 분해된 일의 끝 안내가 머지 뒤 지휘 세션을 말한다"
~~~~

### T7-c ④ B-1 블록의 정규식 — here-string 으로

- 파일: `plugins/spec-distill/tests/test_conducting_interview_stage.sh`
- `printf … | grep -q` 를 here-string 으로 바꾼다 — 이 파일은 `pipefail` 을 켜 두어, 블록이 커지면 `grep -q` 가 먼저 닫아 `printf` 가 SIGPIPE 로 죽고 맞는 글인데도 실패한다.

찾을 글(정확히 한 번):

~~~~bash
{ printf '%s' "$b1_block" | grep -qE 'superpowers.*(부재|없).*advisory|advisory.*superpowers' \
    && printf '%s' "$b1_block" | grep -qF 'crash·spec-mode fallback'; } \
  && ok "AC13: superpowers-absent loud advisory (B-1 블록 스코프)" \
~~~~

바꿀 글:

~~~~bash
{ grep -qE 'superpowers 부재 시.*끝 질문' <<<"$b1_block" \
    && grep -qF 'crash·spec-mode fallback' <<<"$b1_block"; } \
  && ok "AC13: superpowers 가 없으면 끝 질문으로 끝낸다 (B-1 블록 스코프)" \
~~~~

### T7-c ⑤ 재제시 상한 — 선택지 설명

- 파일: `plugins/spec-distill/tests/test_conducting_interview_stage.sh`

찾을 글(정확히 한 번):

~~~~bash
{ grep -qF 'B-2 게이트를 다시 띄운다 — 다음 단계는 그 게이트에서 고른다.' <<<"$cap_fence" \
~~~~

바꿀 글:

~~~~bash
{ grep -qF '왔던 끝 질문을 다시 띄운다 — 어떻게 끝낼지는 그 질문에서 고른다.' <<<"$cap_fence" \
~~~~

### T7-c ⑥ 재제시 상한 — 그 단언의 통과 글

- 파일: `plugins/spec-distill/tests/test_conducting_interview_stage.sh`

찾을 글(정확히 한 번):

~~~~bash
  && ok "AC12: 「지금 목록으로 확정」은 B-2 게이트를 다시 띄우고 상한 경로에 brainstorming handoff 가 없다" \
~~~~

바꿀 글:

~~~~bash
  && ok "AC12: 「지금 목록으로 확정」은 왔던 끝 질문을 다시 띄우고 상한 경로에 brainstorming handoff 가 없다" \
~~~~

### T7-c ⑦ 재제시 상한 — B-3 의 답 처리

- 파일: `plugins/spec-distill/tests/test_conducting_interview_stage.sh`

찾을 글(정확히 한 번):

~~~~bash
{ grep -qF '「지금 목록으로 확정」은 확정 반영 절차를 적용한 뒤 B-2 게이트를 다시 띄우며 스스로 멈추거나 넘기지 않는다' <<<"$b3_block" \
~~~~

바꿀 글:

~~~~bash
{ grep -qF '「지금 목록으로 확정」은 확정 반영 절차를 적용한 뒤 왔던 끝 질문(B-2 게이트 — superpowers 가 없어 B-1 의 끝 질문에서 왔으면 그 끝 질문)을 다시 띄우며 스스로 멈추거나 넘기지 않는다' <<<"$b3_block" \
~~~~

## 5. 시제품 패치

패치를 걸 때는 블록의 글을 git 이 추적하지 않는 파일(`.claude/tmp/f4/patch-<이름>.diff`)로 떠서 `git apply --check` 로 먼저 본다. 블록 안의 빈 줄 · 줄 끝 공백은 그대로 옮긴다(패치의 문맥 줄이다).

### 패치 A (과제 2) — 구조 검사의 건너뜀 줄

- 대상: `plugins/spec-distill/scripts/check_brief.py` · `plugins/spec-distill/templates/interview-audit-template.md` · `plugins/spec-distill/tests/test_check_brief.sh`
- 기준: 브랜치 끝 6b923b62(과제 2 는 코드를 고치는 첫 과제라 그대로 걸린다)

~~~~diff
diff --git a/plugins/spec-distill/scripts/check_brief.py b/plugins/spec-distill/scripts/check_brief.py
index 934f5b1d..f3de1ae6 100755
--- a/plugins/spec-distill/scripts/check_brief.py
+++ b/plugins/spec-distill/scripts/check_brief.py
@@ -992,7 +992,13 @@ def coverage_anchor_failures(audit_text: str, anchors: set) -> list[str]:
             continue
         key, evidence = m.group(1).strip(), m.group(3)
         cited = ANCHOR_RE.findall(evidence)
-        if not cited:
+        # 맹점 차원만 — 근거가 건너뜀으로 시작하면 §2 의 `맹점 조사` 건너뜀 줄이 앵커 요구를 대신한다.
+        # 다른 차원은 같은 근거를 써도 앵커를 요구한다. 인용한 앵커가 있으면 그것은 그대로 실재해야 한다.
+        if key == "floor:blind_spot" and evidence.strip().startswith(SKIP_PREFIX):
+            if "맹점 조사" not in skip_lines(audit_text)[0]:
+                fails.append(f"{key} 근거가 「{SKIP_PREFIX}」 인데 audit §2 에 `맹점 조사` 건너뜀 줄이 없다")
+                continue
+        elif not cited:
             fails.append(f"{key} evidence cites no S<N> anchor")
             continue
         for s in cited:
@@ -1529,7 +1535,76 @@ SAT_CONTINUE_RE = re.compile(r"^포화 판정 \d+: 판정 불가\([^)]*\) — 
 # mapper 첫 매치에서 건너뛰는 §2 의 R1 사건 줄 — 포화 판정 · 사용자 종료(`SAT_LINE_RE`)와 아래 접두.
 # 그 줄의 자유 글(판정 근거 · 사용자 선택 사유)에 `coverage-mapper <k>` 가 섞이면 mapper 줄이 빠져도
 # 그 줄이 하한 검사를 대신 진다(최종 리뷰 M1).
-SAT_EVENT_PREFIXES = ("상한 도달 ", "판정 상한 도달 ", "조사 호출 ")
+# 건너뜀 줄도 사건 줄이다 — 이유 글의 `coverage-mapper <k>` 가 mapper 줄을 대신 지지 않는다.
+SKIP_PREFIX = "모델 판단으로 건너뜀"
+SAT_EVENT_PREFIXES = ("상한 도달 ", "판정 상한 도달 ", "조사 호출 ", SKIP_PREFIX)
+
+# 건너뜀 줄 — audit §2 의 불릿 `모델 판단으로 건너뜀 — <자리>: <이유>`. 자리마다 한 줄이다.
+SKIP_SPOTS = ("범위 조사", "맹점 조사", "포화 판정", "재비판", "codex", "읽어 보기")
+SKIP_LINE_RE = re.compile(r"^모델 판단으로 건너뜀 — ([^:]+):(?:[ \t]+(\S.*))?$")
+SKIP_ADVISORY = "건너뜀 — {spot}: {reason} (모델 판단 — 사람이 확인할 것)"
+SPLIT_LINE_PREFIX = "분해됨 — "
+
+
+def _skip_bodies(audit_text: str) -> list[str]:
+    """audit §2 Budget 의 불릿 중 `모델 판단으로 건너뜀` 으로 시작하는 줄(불릿을 뗀 본문) — 문법이 맞든 아니든."""
+    sec = _section_text(audit_text, "2", "Budget")
+    return [b for b in (_strip_bullet(ln).strip() for ln in _entry_lines(sec)) if b.startswith(SKIP_PREFIX)]
+
+
+def skip_lines(audit_text: str) -> tuple[dict[str, str], list[str]]:
+    """audit §2 의 건너뜀 줄 -> (문법이 맞는 줄의 {자리: 이유} — §2 에 적힌 순서, 실패 사유).
+
+    실패: 형식 밖 · 모르는 자리 · 빈 이유 · 같은 자리 두 줄. 실패한 줄은 첫 반환값에 들지 않는다 — 그 줄은 아래 검사의
+    완화(범위 조사 0회 · 포화 판정 줄 없음 · 맹점 차원 앵커)를 열지 못한다. 같은 자리 두 줄이면 첫 줄만 든다.
+    **이 검사가 못 잡는 것**: 줄은 건너뛰는 쪽이 쓴다 — 이유가 타당한지는 보지 않고 advisory 로 사람에게 넘긴다."""
+    skips: dict[str, str] = {}
+    fails: list[str] = []
+    for body in _skip_bodies(audit_text):
+        m = SKIP_LINE_RE.match(body)
+        if not m:
+            fails.append(f"§2 Budget: 건너뜀 줄이 형식 밖이다 — `{SKIP_PREFIX} — <자리>: <이유>` 로 쓴다: {body[:80]}")
+            continue
+        spot, reason = m.group(1), (m.group(2) or "").strip()
+        if spot not in SKIP_SPOTS:
+            fails.append(f"§2 Budget: 건너뜀 줄의 자리 «{spot[:40]}» 를 모른다 — "
+                         f"건너뛸 수 있는 자리는 {' · '.join(SKIP_SPOTS)} 여섯이다")
+        elif not reason:
+            fails.append(f"§2 Budget: 건너뜀 줄 «{spot}» 의 이유가 비었다")
+        elif spot in skips:
+            dup = f"§2 Budget: 건너뜀 줄 «{spot}» 가 두 줄 이상이다 — 자리마다 한 줄만 쓴다"
+            if dup not in fails:
+                fails.append(dup)
+        else:
+            skips[spot] = reason
+    return skips, fails
+
+
+def payload_is_split(payload_text: str) -> bool:
+    """brief §7 에 `분해됨 — ` 줄이 있는가(나눈 일). 판독은 끝내기 커밋 펜스가 로드맵 폴더를 도출하는 awk 와 같다 —
+    `## 7.` 로 시작하는 줄 다음부터 다음 `## ` 줄 앞까지, 앞 공백 · `- ` · 백틱 하나를 뗀 줄이 `분해됨 — ` 로 시작하면 참.
+    두 판독이 갈라지면 한쪽은 나눈 일로 읽고 다른 쪽은 아닌 brief 가 생긴다."""
+    in7 = False
+    for ln in payload_text.split("\n"):
+        if ln.startswith("## 7."):
+            in7 = True
+            continue
+        if not in7:
+            continue
+        if ln.startswith("## "):
+            return False
+        if re.sub(r"^[ \t]*(?:- )?`?", "", ln, count=1).startswith(SPLIT_LINE_PREFIX):
+            return True
+    return False
+
+
+def skip_split_failures(payload_text: str, audit_text: str) -> list[str]:
+    """나눈 일은 건너뛸 수 없다 — brief §7 이 나눈 일인데 audit §2 에 건너뜀 줄이 하나라도 있으면 실패(문법이 틀린 줄도 센다)."""
+    bodies = _skip_bodies(audit_text)
+    if not bodies or not payload_is_split(payload_text):
+        return []
+    return [f"나눈 일은 건너뛸 수 없다 — brief §7 에 `{SPLIT_LINE_PREFIX}<로드맵 경로>` 줄이 있는데 audit §2 에 건너뜀 줄이 "
+            f"{len(bodies)}개 있다. 건너뛴 조사 · 리뷰를 돌리고 그 줄을 지운다"]
 
 
 # **불릿(데이터) 줄에 앵커한다.** 앵커가 없으면 §2 머리 «설명 산문»의 예시
@@ -1549,30 +1624,40 @@ MAPPER_RE = re.compile(
 
 
 def _is_sat_event(sec: str, pos: int) -> bool:
-    """`pos` 가 든 줄이 R1 사건 줄(포화 판정 · 사용자 종료 · 상한 도달 · 판정 상한 도달 · 조사 호출)인가."""
+    """`pos` 가 든 줄이 R1 사건 줄(포화 판정 · 사용자 종료 · 상한 도달 · 판정 상한 도달 · 조사 호출 · 건너뜀)인가."""
     start = sec.rfind("\n", 0, pos) + 1
     end = sec.find("\n", pos)
     body = _strip_bullet(sec[start:end if end != -1 else len(sec)].strip()).strip()
     return bool(SAT_LINE_RE.match(body)) or body.startswith(SAT_EVENT_PREFIXES)
 
 
+def _mapper_match(audit_text: str):
+    """audit §2 Budget 의 mapper 데이터 줄 — 사건 줄을 건너뛴 `MAPPER_RE` 첫 매치(없으면 None)."""
+    sec = _section_text(audit_text, "2", "Budget")
+    return next((c for c in MAPPER_RE.finditer(sec) if not _is_sat_event(sec, c.start(1))), None)
+
+
 def budget_mapper_failures(audit_text: str) -> tuple[list[str], list[str]]:
     """audit §2 Budget 의 `coverage-mapper <k>` (v0.57.0, spec §2.3·C4).
 
     k>=1 통과. `coverage-mapper 0 (unavailable: <이유>)` 는 advisory 통과 — 침묵과 0 을
-    가른다. 대상은 §2 의 **불릿 줄**이다(`MAPPER_RE` 주석) — 머리 설명 산문의 예시는
+    가른다. 괄호 안 이유가 비면 실패다. 사유 없는 0 은 `범위 조사` 건너뜀 줄(`skip_lines`)이 있을 때만 통과한다 —
+    mapper 줄 자체가 없으면 건너뜀 줄이 있어도 실패다. 대상은 §2 의 **불릿 줄**이다(`MAPPER_RE` 주석) — 머리 설명 산문의 예시는
     판정에 참여하지 않는다. **이 검사가 못 잡는 것**: sentinel 은 피검자가 쓰는 문구라,
     dispatch 를 건너뛴 턴이 같은 문구를 적으면 «도구 부재»와 구분하지 못한다. 그래서
     advisory 는 조용히 통과하지 않고 다음 단계 게이트 앞 글로 사람에게 간다."""
-    sec = _section_text(audit_text, "2", "Budget")
-    m = next((c for c in MAPPER_RE.finditer(sec) if not _is_sat_event(sec, c.start(1))), None)
+    m = _mapper_match(audit_text)
     if not m:
         return ["§2 Budget: coverage-mapper <k> line missing"], []
     k, reason = int(m.group(1)), m.group(2)
     if k >= 1:
         return [], []
-    if reason:
+    if reason is not None:
+        if not reason[len("unavailable:"):].strip():
+            return ["§2 Budget: coverage-mapper 0 (unavailable:) 의 사유가 비었다 — 부르지 못한 까닭을 괄호 안에 적는다"], []
         return [], [f"coverage-mapper 0 ({reason}) — 범위 조사 에이전트를 부르지 않고 통과했다 (사람이 확인할 것)"]
+    if "범위 조사" in skip_lines(audit_text)[0]:
+        return [], []   # advisory 는 건너뜀 줄마다 gate() 가 낸다
     return ["§2 Budget: coverage-mapper 0 without unavailable reason"], []
 
 
@@ -1586,11 +1671,14 @@ def saturation_failures(audit_text: str, anchors: set) -> tuple[list[str], list[
     """audit §2 의 마지막 포화 판정 줄 (설계 §5).
 
     통과: 판정자 `포화` · 사용자 종료(S 앵커 실재) · 사용자 판단 포화(S 앵커 실재, advisory).
+    판정 줄이 하나도 없으면 `포화 판정` 건너뜀 줄(`skip_lines`)이 있을 때만 통과한다.
     실패: 줄 없음 · 마지막이 `아직`(반복 빈 곳 재조사 포함) · 마지막이 `판정 불가 — 조사 계속` ·
     형식 밖. **이 검사가 못 잡는 것**: 줄은 본체가 쓴다 — 판정자를 부르지 않은 턴이 `포화` 줄을
     지어 적으면 구별하지 못한다. 그 축은 판정자 dispatch 의 처분 줄과 Step B 의 사람 확인이 진다."""
     hits = _sat_hits(audit_text)
     if not hits:
+        if "포화 판정" in skip_lines(audit_text)[0]:
+            return [], []   # 판정 줄이 하나라도 있으면 이 갈래에 오지 않는다 — 건너뜀 줄이 구해 주지 않는다
         return ["§2 Budget: 포화 판정 줄 없음 — floor 다섯이 닫힌 뒤 포화 판정자를 부르지 않았거나 "
                 "사용자 종료를 적지 않았다"], []
     last = hits[-1]
@@ -1612,6 +1700,34 @@ def saturation_failures(audit_text: str, anchors: set) -> tuple[list[str], list[
     return [f"§2 Budget: 포화 판정 줄이 형식 밖이다: {last[:80]}"], []
 
 
+def skip_conflict_failures(audit_text: str) -> list[str]:
+    """돌린 조사의 건너뜀 줄이 남았는가 — 남으면 실패다(돌린 조사가 사람에게 「건너뛴 것」 으로 보이지 않게).
+
+    조사 자리 셋만 본다: `범위 조사` 줄 + mapper 계수 1 이상 · `포화 판정` 줄 + 포화 판정 · 사용자 종료 줄 ·
+    `맹점 조사` 줄 + 건너뜀으로 시작하지 않는 `floor:blind_spot` 근거. 리뷰 부품 셋(재비판 · codex · 읽어 보기)은
+    보지 않는다 — 그 부품이 돌았는지는 이 검사가 읽는 글에 없다."""
+    skips = skip_lines(audit_text)[0]
+    fails: list[str] = []
+    if "범위 조사" in skips:
+        m = _mapper_match(audit_text)
+        if m and int(m.group(1)) >= 1:
+            fails.append(f"§2 Budget: `범위 조사` 건너뜀 줄이 있는데 mapper 줄이 coverage-mapper {int(m.group(1))} 이다 — "
+                         "범위 조사를 돌렸으면 그 건너뜀 줄을 지운다")
+    if "포화 판정" in skips:
+        hits = _sat_hits(audit_text)
+        if hits:
+            fails.append(f"§2 Budget: `포화 판정` 건너뜀 줄이 있는데 포화 판정 · 사용자 종료 줄이 {len(hits)}개 있다 — "
+                         "판정했거나 사용자가 끝냈으면 그 건너뜀 줄을 지운다")
+    if "맹점 조사" in skips:
+        for ln in _entry_lines(_section_text(audit_text, "1", "Coverage Ledger")):
+            m = LEDGER_ROW_RE.match(_strip_bullet(ln).strip())
+            if m and m.group(1).strip() == "floor:blind_spot" and not m.group(3).strip().startswith(SKIP_PREFIX):
+                fails.append(f"§2 Budget: `맹점 조사` 건너뜀 줄이 있는데 audit §1 의 floor:blind_spot 근거가 「{SKIP_PREFIX}」 으로 "
+                             "시작하지 않는다 — 맹점 조사를 돌렸으면 그 건너뜀 줄을 지운다")
+                break
+    return fails
+
+
 def closing_answer_anchors(payload_text: str, audit_text: str) -> list[tuple[str, str]]:
     """인터뷰를 사용자가 고른 답으로 닫은 자리의 `S<n>` — `(S, "irrelevant")` 는 §4 의 「외부 선례 무관(@S<n>)」 줄마다
     (같은 S 는 한 번), `(S, "saturation")` 은 audit §2 의 **마지막** 포화 판정 줄이 「사용자 판단 포화(@S<n>)」 일 때만.
@@ -1772,6 +1888,10 @@ def gate(path: Path) -> int:
                     audit_text, payload_verbatim_anchors(text) | verbatim_anchors(audit_text))
                 failures += [f"saturation: {x}" for x in sf]
                 advisories += sa
+                skips, kf = skip_lines(audit_text)
+                failures += [f"건너뜀 줄: {x}" for x in
+                             kf + skip_conflict_failures(audit_text) + skip_split_failures(text, audit_text)]
+                advisories += [SKIP_ADVISORY.format(spot=s, reason=r) for s, r in skips.items()]
 
     # N1b — payload §6 이 원문 전량인가. audit §6 앵커와 대조하므로 audit 을 읽은 뒤에 돈다.
     # 경계가 비유일하면 N1b·bijection C를 묻지 않는다 — 그 상태의 앵커 집합은 공집합이라
diff --git a/plugins/spec-distill/templates/interview-audit-template.md b/plugins/spec-distill/templates/interview-audit-template.md
index 606631f7..5cd5145c 100644
--- a/plugins/spec-distill/templates/interview-audit-template.md
+++ b/plugins/spec-distill/templates/interview-audit-template.md
@@ -37,17 +37,26 @@ source: spec-distill pm-interview
 (한 줄. 이 줄의 두 계수는 **다른 것을 센다**: `agent dispatch: <n>` 은 이 인터뷰의 subagent
  dispatch **총계**이고, `coverage-mapper <k>` 는 그중 coverage-mapper **하나만**의 횟수라
  언제나 `<k> ≤ <n>` 이다. 게이트가 보는 것은 후자뿐이며 k≥1이면 통과한다 — dispatch 를 못
- 했으면 `coverage-mapper 0 (unavailable: <사유>)`처럼 사유를 붙인다(advisory). 사유 없는 0은
+ 했으면 `coverage-mapper 0 (unavailable: <사유>)`처럼 사유를 붙인다(advisory) — 괄호 안 사유가
+ 비면 게이트 red 다. 사유 없는 0은 `범위 조사` 건너뜀 줄(아래)이 있을 때만 통과하고, 없으면
  게이트 red(AC4). 게이트가 읽는 것은 아래 **불릿 줄**뿐이고 이 설명 산문은 판정에 참여하지
  않는다. `<k>` 는 **반드시 실제 횟수로 치환한다** — 템플릿이 통과값을 미리 채워 두면
  dispatch 를 한 번도 안 한 턴이 그대로 옮겨 적어 게이트가 조용히 통과한다. 채우지 않은
  `<k>` 는 게이트 red 다(«coverage-mapper <k> line missing»): 침묵보다 red 가 낫다.)
 
 (포화 판정 줄 — 게이트는 아래 불릿 중 `포화 판정 <k>:` 또는 `사용자 종료(@S<n>)` 로 시작하는 **마지막** 줄을 본다.
-판정자 `포화` · 사용자 종료 · 사용자 판단 포화(advisory)면 통과, 줄이 없거나 마지막이 `아직` · `판정 불가 — 조사 계속` 이면
-red 다. 판정마다 한 줄, 사용자 선택마다 한 줄을 시간 순으로 덧붙인다 — 형식의 정본은 pm-interview 의 포화 판정 reference 다.
+판정자 `포화` · 사용자 종료 · 사용자 판단 포화(advisory)면 통과, 마지막이 `아직` · `판정 불가 — 조사 계속` 이면 red 다.
+판정 줄이 하나도 없으면 `포화 판정` 건너뜀 줄(아래)이 있을 때만 통과하고, 없으면 red 다 — 판정 줄이 있으면 건너뜀 줄은
+판정을 바꾸지 않는다. 판정마다 한 줄, 사용자 선택마다 한 줄을 시간 순으로 덧붙인다 — 형식의 정본은 pm-interview 의 포화 판정 reference 다.
 `<k>` 는 실제 차례로 치환한다 — 채우지 않은 자리표는 게이트 red 다.)
 
+(건너뜀 줄 — 모델이 작은 일이라 판단해 건너뛴 자리마다 불릿 한 줄을 덧붙인다. 꼴은 「모델 판단으로 건너뜀 — 자리: 이유」 이고,
+자리는 `범위 조사` · `맹점 조사` · `포화 판정` · `재비판` · `codex` · `읽어 보기` 가운데 하나, 이유는 빈칸이 아닌 글이다.
+모르는 자리 · 빈 이유 · 같은 자리 두 줄은 red 다. 건너뛰지 않았으면 이 줄을 쓰지 않는다 — 건너뛴 조사를 나중에 돌렸으면 그 줄을
+지운다. 범위 조사 · 포화 판정 · 맹점 조사는 돌린 흔적(mapper 계수 1 이상 · 판정 줄 · 건너뜀으로 시작하지 않는 맹점 근거)과
+건너뜀 줄이 함께 있으면 red 다.
+brief §7 이 나눈 일(`분해됨 — <로드맵 경로>`)이면 건너뜀 줄이 하나라도 있을 때 red 다. 게이트는 줄마다 사람이 확인하라는 참고 줄을 낸다.)
+
 - 질문 라운드: <n> · agent dispatch: <n> · coverage-mapper <k> · codex 실호출: <n> (성공 <n>)
 - 조사 호출 <n>/<limit> (장치별: 커버리지 <a> · 맹점 <b> · 반론 <c> · 레포 조사 <d> · 만든 조사 <o> · 본체 직접 <e>)
 - 포화 판정 <k>: <포화 — <basis 요지> | 아직 — 빈 곳 <g>개 | …>
diff --git a/plugins/spec-distill/tests/test_check_brief.sh b/plugins/spec-distill/tests/test_check_brief.sh
index 673d5ff4..0519a42d 100755
--- a/plugins/spec-distill/tests/test_check_brief.sh
+++ b/plugins/spec-distill/tests/test_check_brief.sh
@@ -2903,4 +2903,328 @@ out="$(irr_run fresh_after)"; rc=$?
 { [[ $rc -ne 0 ]] && grep -qF '결정 연결 없음' <<<"$out"; } \
   && ok "AC9 fresh_after(양성 대조): 확인 꼬리를 연결 뒤에 두면 red «결정 연결 없음»" \
   || { no "AC9 fresh_after: 연결 뒤 꼬리가 통과했거나 사유가 다르다 (rc=${rc})"; printf '    %s\n' "$out"; }
+# --- F4(설계 2026-11-15-front-stage-exit §2 · AC4–AC7): audit §2 의 건너뜀 줄 ------------------------
+# 줄 꼴은 `- 모델 판단으로 건너뜀 — <자리>: <이유>`, 자리는 여섯이다. 정상 쌍을 $TMPD 로 복사해 줄 하나씩만 바꾼다.
+# rc 만 보지 않는다 — 실패는 사유 글자를, 통과는 advisory 글자(JSON `advisories` 와 stderr 둘 다)와 그 개수를 함께 본다.
+SKP='모델 판단으로 건너뜀'
+SKROAD='분해됨 — docs/superpowers/roadmaps/2026-11-15-sample/roadmap.md'
+skip_adv() { printf '건너뜀 — %s: %s (모델 판단 — 사람이 확인할 것)' "$1" "$2"; }   # $1 = 자리, $2 = 이유
+skip_edit() {  # $1 = stem, $2… = 변형(순서대로). 하나라도 안 먹으면 no 를 센다 — 아래 단언이 원래 쌍을 다시 재지 않게.
+  python3 -I - "$TMPD/$1" "${@:2}" <<'PY' || no "F4/건너뜀: $1 변형이 적용되지 않았다 — 아래 단언이 공허하다"
+import re, sys
+stem, ops = sys.argv[1], sys.argv[2:]
+ap, pp = stem + ".audit.md", stem + ".md"
+a = open(ap, encoding="utf-8").read()
+p = open(pp, encoding="utf-8").read()
+MAP = r"^[-*] agent dispatch: coverage-mapper .*\n"
+
+
+def sub1(rx, rep, t):
+    t2, n = re.subn(rx, rep, t, count=1, flags=re.M)
+    if n != 1:
+        sys.exit("변형 실패: " + rx)
+    return t2
+
+
+def under(head, line, t):   # 절 머리 바로 아래(첫 줄)에 줄 하나를 넣는다
+    return sub1("^(" + head + r"\n\n?)", lambda m: m.group(1) + line + "\n", t)
+
+
+for op in ops:
+    k, _, v = op.partition("=")
+    if k == "add":          # audit §2 의 첫 줄로 넣는다(mapper 줄보다 앞)
+        a = under(r"## 2\. Budget", v, a)
+    elif k == "a5":         # audit §5 의 첫 줄로 넣는다(§2 밖)
+        a = under(r"## 5\. 프로세스 로그", v, a)
+    elif k == "del":        # 그 글자로 시작하는 불릿 줄 하나를 지운다
+        a = sub1(r"^[-*] " + re.escape(v) + r".*\n", "", a)
+    elif k == "mapper":     # mapper 데이터 줄의 계수 자리를 바꾼다
+        a = sub1(r"coverage-mapper 1$", lambda m: "coverage-mapper " + v, a)
+    elif k == "nomapper":
+        a = sub1(MAP, "", a)
+    elif k == "nosat":      # 포화 판정 · 사용자 종료 줄을 모두 지운다
+        a, n = re.subn(r"^[-*] (포화 판정 \d+:|사용자 종료\(@S\d+\)).*\n", "", a, flags=re.M)
+        if n < 1:
+            sys.exit("변형 실패: 포화 줄이 없다")
+    elif k == "sat":        # 포화 줄을 이 줄로 바꾼다
+        a = sub1(r"^[-*] 포화 판정 \d+:.*$", lambda m: v, a)
+    elif k == "row":        # row=<키>=<근거> — 원장의 닫힌 행 근거를 바꾼다
+        key, _, ev = v.partition("=")
+        a = sub1(r"^- " + re.escape(key) + r" — closed — .*$", lambda m: "- %s — closed — %s" % (key, ev), a)
+    elif k == "p7":         # payload §7 의 첫 줄로 넣는다
+        p = under(r"## 7\. Next Action", v + "\n", p)
+    elif k == "p7end":      # payload §7 의 마지막 줄로 덧붙인다(§7 이 마지막 절이다)
+        p = p.rstrip("\n") + "\n\n" + v + "\n"
+    elif k == "p0":         # payload §0 의 첫 줄로 넣는다(§7 밖)
+        p = under(r"## 0\. 한눈에", v + "\n", p)
+    else:
+        sys.exit("모르는 변형: " + op)
+open(ap, "w", encoding="utf-8").write(a)
+open(pp, "w", encoding="utf-8").write(p)
+PY
+}
+skip_json() {  # $1 = gate stdout(JSON), $2 = failures|advisories — 한 줄에 하나
+  python3 -I -c 'import json, sys
+for x in json.loads(sys.argv[1]).get(sys.argv[2], []):
+    print(x)' "$1" "$2"
+}
+skip_run() {  # $1 = stem → out · rc · fl(실패 줄) · adv(advisory 줄) · nadv(건너뜀 advisory 수). stderr 는 $TMPD/$1.err
+  out="$(python3 "$SCRIPT" gate "$TMPD/$1.md" 2>"$TMPD/$1.err")"; rc=$?
+  fl="$(skip_json "$out" failures)" || fl="(JSON 아님)"
+  adv="$(skip_json "$out" advisories)" || adv="(JSON 아님)"
+  nadv="$(grep -c '^건너뜀 — ' <<<"$adv")"
+}
+skip_pass() {  # $1 = stem, $2 = 라벨, $3… = 나와야 할 건너뜀 advisory 줄(글자 그대로 · 이것이 전부여야 한다)
+  local good=1 a
+  skip_run "$1"
+  [[ $rc -eq 0 && -z "$fl" && "$nadv" == "$(($# - 2))" ]] || good=0
+  for a in "${@:3}"; do
+    grep -qxF -- "$a" <<<"$adv" || good=0
+    grep -qxF -- "$a" "$TMPD/$1.err" || good=0
+  done
+  [[ $good -eq 1 ]] && ok "F4/건너뜀: $2 → 통과 · 건너뜀 advisory $(($# - 2))줄" \
+    || { no "F4/건너뜀: $2 가 red 이거나 advisory 가 다르다 (rc=${rc} · 건너뜀 advisory ${nadv}줄)"; printf '    %s\n' "$out"; }
+}
+skip_fail() {  # $1 = stem, $2 = 라벨, $3 = 건너뜀 advisory 수, $4… = 실패 사유에 있어야 할 글자(전부)
+  local good=1 w
+  skip_run "$1"
+  [[ $rc -ne 0 && "$nadv" == "$3" ]] || good=0
+  for w in "${@:4}"; do grep -qF -- "$w" <<<"$fl" || good=0; done
+  [[ $good -eq 1 ]] && ok "F4/건너뜀: $2 → red «${4}»" \
+    || { no "F4/건너뜀: $2 가 통과했거나 사유 · advisory 수가 다르다 (rc=${rc} · 건너뜀 advisory ${nadv}줄)"; printf '    %s\n' "$out"; }
+}
+
+SKEV="${SKP} — 고칠 파일이 하나뿐이라 맹점 조사를 돌리지 않았다"
+skip_base() {  # $1 = stem, $2 = 자리 — 그 조사를 실제로 건너뛴 audit 꼴로 맞춘다(조사 자리 셋. 리뷰 부품 셋은 그대로 둔다)
+  case "$2" in
+    "범위 조사") skip_edit "$1" "mapper=0" ;;
+    "포화 판정") skip_edit "$1" nosat ;;
+    "맹점 조사") skip_edit "$1" "row=floor:blind_spot=${SKEV}" ;;
+  esac
+}
+
+# 양성 대조 — 정상 쌍은 건너뜀 줄 없이 통과하고 건너뜀 advisory 가 0줄이다. 아래 칸은 모두 여기서 줄 하나씩 움직인다.
+ac3_pair sk_ctl
+skip_pass sk_ctl "양성 대조: 건너뜀 줄 없는 정상 쌍"
+
+# (1) 자리 여섯 × 문법 넷 + 나눈 일 — AC4 · AC6 · advisory
+skn=0
+for sp in "범위 조사" "맹점 조사" "포화 판정" "재비판" "codex" "읽어 보기"; do
+  skn=$((skn + 1)); st="sk${skn}"
+  ac3_pair "${st}_ok"; skip_base "${st}_ok" "${sp}"; skip_edit "${st}_ok" "add=- ${SKP} — ${sp}: 고칠 파일이 하나뿐인 작은 일"
+  skip_pass "${st}_ok" "「${sp}」 줄 하나" "$(skip_adv "${sp}" '고칠 파일이 하나뿐인 작은 일')"
+  # 나눈 일 — 같은 audit 에 payload §7 만 바꾼다. 통과하던 쌍이 실패로 갈린다.
+  sk_sum="$(cksum < "$TMPD/${st}_ok.audit.md")"
+  skip_edit "${st}_ok" "p7=${SKROAD}"
+  { [[ "$(cksum < "$TMPD/${st}_ok.audit.md")" == "$sk_sum" ]] && grep -qxF -- "${SKROAD}" "$TMPD/${st}_ok.md"; } \
+    && ok "F4/건너뜀(양성대조): 「${sp}」 — audit 은 그대로이고 payload §7 에만 분해됨 줄이 들어갔다" \
+    || no "F4/건너뜀(양성대조): 「${sp}」 — 나눈 일 변형이 적용되지 않았거나 audit 이 바뀌었다"
+  skip_fail "${st}_ok" "「${sp}」 줄 + 나눈 일" 1 '건너뜀 줄: 나눈 일은 건너뛸 수 없다'
+  ac3_pair "${st}_unk"; skip_base "${st}_unk" "${sp}"; skip_edit "${st}_unk" "add=- ${SKP} — ${sp} 둘째: 작은 일"
+  skip_fail "${st}_unk" "모르는 자리 「${sp} 둘째」" 0 "건너뜀 줄: §2 Budget: 건너뜀 줄의 자리 «${sp} 둘째» 를 모른다"
+  ac3_pair "${st}_empty"; skip_base "${st}_empty" "${sp}"; skip_edit "${st}_empty" "add=- ${SKP} — ${sp}:"
+  skip_fail "${st}_empty" "「${sp}」 빈 이유" 0 "건너뜀 줄: §2 Budget: 건너뜀 줄 «${sp}» 의 이유가 비었다"
+  ac3_pair "${st}_blank"; skip_base "${st}_blank" "${sp}"; skip_edit "${st}_blank" "add=- ${SKP} — ${sp}:   "
+  skip_fail "${st}_blank" "「${sp}」 공백뿐인 이유" 0 "건너뜀 줄: §2 Budget: 건너뜀 줄 «${sp}» 의 이유가 비었다"
+  ac3_pair "${st}_dup"; skip_base "${st}_dup" "${sp}"; skip_edit "${st}_dup" "add=- ${SKP} — ${sp}: 둘째 이유" "add=- ${SKP} — ${sp}: 첫 이유"
+  skip_fail "${st}_dup" "「${sp}」 두 줄" 1 "건너뜀 줄: §2 Budget: 건너뜀 줄 «${sp}» 가 두 줄 이상이다"
+done
+
+# (2) 문법 — 자리 집합 밖 · 형식 밖. 리뷰의 탐지는 건너뛸 수 있는 자리가 아니다.
+skn=0
+for bad in "탐지" "Codex" "범위조사"; do
+  skn=$((skn + 1)); ac3_pair "sk_unk${skn}"; skip_edit "sk_unk${skn}" "add=- ${SKP} — ${bad}: 작은 일"
+  skip_fail "sk_unk${skn}" "모르는 자리 「${bad}」" 0 "건너뜀 줄의 자리 «${bad}» 를 모른다"
+done
+skn=0
+for bad in "${SKP} - 범위 조사: 작은 일" "${SKP} — 범위 조사 작은 일" "${SKP} — 범위 조사:작은 일" "${SKP}" "${SKP} — : 작은 일"; do
+  skn=$((skn + 1)); ac3_pair "sk_form${skn}"; skip_edit "sk_form${skn}" "add=- ${bad}"
+  skip_fail "sk_form${skn}" "형식 밖 「${bad}」" 0 '건너뜀 줄: §2 Budget: 건너뜀 줄이 형식 밖이다'
+done
+# 불릿 어휘는 형제와 같은 `[-*]` 다.
+ac3_pair sk_star; skip_edit sk_star "add=* ${SKP} — codex: 작은 일"
+skip_pass sk_star "«*» 불릿 건너뜀 줄" "$(skip_adv codex '작은 일')"
+# 여러 줄 — 줄마다 advisory 한 줄, §2 에 적힌 순서대로.
+ac3_pair sk_multi
+skip_edit sk_multi "add=- ${SKP} — 읽어 보기: 셋째" "add=- ${SKP} — codex: 둘째" "add=- ${SKP} — 재비판: 첫째"
+skip_pass sk_multi "리뷰 부품 셋" "$(skip_adv 재비판 첫째)" "$(skip_adv codex 둘째)" "$(skip_adv '읽어 보기' 셋째)"
+assert_eq "$(grep '^건너뜀 — ' <<<"$adv")" "$(printf '%s\n%s\n%s' "$(skip_adv 재비판 첫째)" "$(skip_adv codex 둘째)" "$(skip_adv '읽어 보기' 셋째)")" \
+  "F4/건너뜀: advisory 는 §2 에 적힌 순서대로 나온다"
+
+# (3) 범위 조사 — `coverage-mapper 0` 은 `범위 조사` 줄이 있을 때만 통과한다(AC5). 줄만 지우면 실패한다.
+ac3_pair sk_map; skip_edit sk_map "mapper=0" "add=- ${SKP} — 범위 조사: 고칠 파일이 하나뿐"
+{ grep -qE '^- agent dispatch: coverage-mapper 0$' "$TMPD/sk_map.audit.md" && ! grep -q 'unavailable' "$TMPD/sk_map.audit.md"; } \
+  && ok "F4/건너뜀(양성대조): mapper 줄이 사유 없는 0 이다" || no "F4/건너뜀(양성대조): mapper 0 변형이 적용되지 않았다"
+skip_pass sk_map "coverage-mapper 0 + 「범위 조사」 줄" "$(skip_adv '범위 조사' '고칠 파일이 하나뿐')"
+grep -q 'coverage-mapper' <<<"$adv" \
+  && no "F4/건너뜀: 범위 조사 건너뜀이 unavailable advisory 로도 나왔다" || ok "F4/건너뜀: 범위 조사 건너뜀은 건너뜀 advisory 한 줄로만 나온다"
+skip_edit sk_map "del=${SKP} — 범위 조사"
+skip_fail sk_map "같은 쌍에서 「범위 조사」 줄만 지움" 0 'coverage-mapper budget: §2 Budget: coverage-mapper 0 without unavailable reason'
+ac3_pair sk_map_other; skip_edit sk_map_other "mapper=0" "add=- ${SKP} — 재비판: 작은 일"
+skip_fail sk_map_other "coverage-mapper 0 + 다른 자리(재비판) 줄" 1 'coverage-mapper 0 without unavailable reason'
+ac3_pair sk_map_bad; skip_edit sk_map_bad "mapper=0" "add=- ${SKP} — 범위 조사:"
+skip_fail sk_map_bad "coverage-mapper 0 + 이유가 빈 「범위 조사」 줄(문법 실패 줄은 완화를 열지 않는다)" 0 \
+  '건너뜀 줄 «범위 조사» 의 이유가 비었다' 'coverage-mapper 0 without unavailable reason'
+ac3_pair sk_map_mid; skip_edit sk_map_mid "mapper=0" "add=- 메모 — ${SKP} — 범위 조사: 작은 일"
+skip_fail sk_map_mid "coverage-mapper 0 + 줄 머리가 아닌 자리의 건너뜀 글" 0 'coverage-mapper 0 without unavailable reason'
+ac3_pair sk_map_s5; skip_edit sk_map_s5 "mapper=0" "a5=- ${SKP} — 범위 조사: 작은 일"
+skip_fail sk_map_s5 "coverage-mapper 0 + §2 밖(§5)의 건너뜀 줄" 0 'coverage-mapper 0 without unavailable reason'
+# mapper 줄 자체가 없으면 건너뜀 줄이 있어도 실패 — 그리고 건너뜀 줄 이유의 `coverage-mapper <k>` 가 mapper 줄을 대신 지지 않는다.
+skn=0
+for why in "작은 일" "coverage-mapper 3 번 부를 일이 아니다" "coverage-mapper 0 (unavailable: 도구 부재) 와 같다"; do
+  skn=$((skn + 1)); ac3_pair "sk_ev${skn}"; skip_edit "sk_ev${skn}" "add=- ${SKP} — 범위 조사: ${why}" nomapper
+  ! grep -q '^[-*] agent dispatch: coverage-mapper' "$TMPD/sk_ev${skn}.audit.md" \
+    && ok "F4/건너뜀(양성대조): mapper 데이터 줄이 없다(이유 「${why}」)" || no "F4/건너뜀(양성대조): mapper 줄 삭제가 적용되지 않았다"
+  skip_fail "sk_ev${skn}" "mapper 줄 없음 + 「범위 조사」 줄(이유 「${why}」)" 1 'coverage-mapper budget: §2 Budget: coverage-mapper <k> line missing'
+done
+# AC7 — `(unavailable:)` 의 빈 이유는 실패. 양의 짝: 이유가 있으면 지금처럼 advisory 통과.
+skn=0
+for un in "(unavailable:)" "(unavailable:   )" "(unavailable: )"; do
+  skn=$((skn + 1)); ac3_pair "sk_un${skn}"; skip_edit "sk_un${skn}" "mapper=0 ${un}"
+  skip_fail "sk_un${skn}" "coverage-mapper 0 ${un}" 0 'coverage-mapper budget: §2 Budget: coverage-mapper 0 (unavailable:) 의 사유가 비었다'
+done
+ac3_pair sk_un_ok; skip_edit sk_un_ok "mapper=0 (unavailable: Agent 도구 부재)"
+skip_pass sk_un_ok "coverage-mapper 0 (unavailable: Agent 도구 부재)"
+grep -qxF 'coverage-mapper 0 (unavailable: Agent 도구 부재) — 범위 조사 에이전트를 부르지 않고 통과했다 (사람이 확인할 것)' <<<"$adv" \
+  && ok "F4/건너뜀: 이유가 있는 unavailable 은 지금처럼 advisory 로 통과한다" \
+  || { no "F4/건너뜀: 이유가 있는 unavailable 의 advisory 가 없다"; printf '    %s\n' "$out"; }
+ac3_pair sk_un_skip; skip_edit sk_un_skip "mapper=0 (unavailable:)" "add=- ${SKP} — 범위 조사: 작은 일"
+skip_fail sk_un_skip "(unavailable:) 빈 이유 + 「범위 조사」 줄(건너뜀 줄이 빈 괄호를 구하지 않는다)" 1 'coverage-mapper 0 (unavailable:) 의 사유가 비었다'
+
+# (4) 포화 판정 — 판정 줄이 하나도 없을 때만 `포화 판정` 줄이 통과시킨다(AC5). 판정 줄이 있으면 지금 규칙 그대로다.
+ac3_pair sk_sat; skip_edit sk_sat nosat "add=- ${SKP} — 포화 판정: 조사 한 번으로 끝난 일"
+grep -qE '^[-*] (포화 판정 [0-9]+:|사용자 종료\(@S)' "$TMPD/sk_sat.audit.md" \
+  && no "F4/건너뜀(양성대조): 포화 판정 줄이 남아 있다 — 아래 통과 단언이 공허하다" || ok "F4/건너뜀(양성대조): 판정 줄이 하나도 없다"
+skip_pass sk_sat "판정 줄 없음 + 「포화 판정」 줄" "$(skip_adv '포화 판정' '조사 한 번으로 끝난 일')"
+skip_edit sk_sat "del=${SKP} — 포화 판정"
+skip_fail sk_sat "같은 쌍에서 「포화 판정」 줄만 지움" 0 'saturation: §2 Budget: 포화 판정 줄 없음'
+ac3_pair sk_sat_other; skip_edit sk_sat_other nosat "add=- ${SKP} — codex: 작은 일"
+skip_fail sk_sat_other "판정 줄 없음 + 다른 자리(codex) 줄" 1 'saturation: §2 Budget: 포화 판정 줄 없음'
+skn=0
+for spec in "- 포화 판정 1: 아직 — 빈 곳 2개|마지막 포화 판정이 «아직»" \
+            "- 포화 판정 1: 판정 불가(Agent 도구 부재) — 조사 계속(@S2)|판정 불가 뒤 사용자가 조사 계속을 골랐는데" \
+            "- 포화 판정 1: 대충 끝났다|포화 판정 줄이 형식 밖이다"; do
+  skn=$((skn + 1)); ac3_pair "sk_sat${skn}"
+  skip_edit "sk_sat${skn}" "sat=${spec%%|*}" "add=- ${SKP} — 포화 판정: 작은 일"
+  skip_fail "sk_sat${skn}" "판정 줄 「${spec%%|*}」 + 「포화 판정」 줄(건너뜀 줄이 구해 주지 않는다)" 1 "saturation: §2 Budget: ${spec##*|}"
+done
+
+# (5) 맹점 조사 — 맹점 차원만, 근거가 건너뜀으로 시작하고 `맹점 조사` 줄이 있을 때 앵커 요구를 면제한다(AC5).
+SKNOLINE='floor:blind_spot 근거가 「모델 판단으로 건너뜀」 인데 audit §2 에 `맹점 조사` 건너뜀 줄이 없다'
+ac3_pair sk_bs; skip_edit sk_bs "row=floor:blind_spot=${SKEV}" "add=- ${SKP} — 맹점 조사: 고칠 파일이 하나뿐"
+sk_row="$(grep -E '^- floor:blind_spot — closed — ' "$TMPD/sk_bs.audit.md")"
+{ [[ -z "$sk_row" ]] || grep -qE '(^|[^A-Za-z])S[0-9]' <<<"$sk_row"; } \
+  && no "F4/건너뜀(양성대조): 맹점 행에 S 앵커가 남아 있다 — 아래 통과 단언이 공허하다" || ok "F4/건너뜀(양성대조): 맹점 행 근거에 S 앵커가 없다"
+skip_pass sk_bs "앵커 없는 맹점 근거(건너뜀) + 「맹점 조사」 줄" "$(skip_adv '맹점 조사' '고칠 파일이 하나뿐')"
+skip_edit sk_bs "del=${SKP} — 맹점 조사"
+skip_fail sk_bs "같은 쌍에서 「맹점 조사」 줄만 지움" 0 "coverage anchors:" "${SKNOLINE}"
+ac3_pair sk_bs_other; skip_edit sk_bs_other "row=floor:blind_spot=${SKEV}" "add=- ${SKP} — 범위 조사: 작은 일"
+skip_fail sk_bs_other "맹점 근거(건너뜀) + 다른 자리(범위 조사) 줄" 1 "${SKNOLINE}"
+ac3_pair sk_bs_anch; skip_edit sk_bs_anch "row=floor:blind_spot=${SKEV} (@S1)"
+skip_fail sk_bs_anch "맹점 근거(건너뜀)가 실재 S 를 인용해도 「맹점 조사」 줄이 없으면 실패" 0 "${SKNOLINE}"
+ac3_pair sk_bs_plain; skip_edit sk_bs_plain "row=floor:blind_spot=§5 cold-start 위험" "add=- ${SKP} — 맹점 조사: 작은 일"
+skip_fail sk_bs_plain "근거가 건너뜀으로 시작하지 않으면 「맹점 조사」 줄이 있어도 앵커 요구" 1 'floor:blind_spot evidence cites no S<N> anchor'
+ac3_pair sk_bs_mid; skip_edit sk_bs_mid "row=floor:blind_spot=§5 위험 — ${SKP}" "add=- ${SKP} — 맹점 조사: 작은 일"
+skip_fail sk_bs_mid "근거 가운데의 건너뜀 글은 면제를 열지 않는다" 1 'floor:blind_spot evidence cites no S<N> anchor'
+ac3_pair sk_bs_dangle; skip_edit sk_bs_dangle "row=floor:blind_spot=${SKEV} (@S77)" "add=- ${SKP} — 맹점 조사: 작은 일"
+skip_fail sk_bs_dangle "면제된 맹점 근거가 없는 S 를 인용" 1 'floor:blind_spot evidence anchor S77 not found'
+# 다른 차원은 같은 근거를 써도 앵커를 요구한다(맹점 행은 면제된 꼴로 두어 그 차원의 사유만 남긴다).
+skn=0
+for key in "floor:landscape" "floor:root_problem" "derived:rendering-strategy"; do
+  skn=$((skn + 1)); ac3_pair "sk_fl${skn}"
+  skip_edit "sk_fl${skn}" "row=floor:blind_spot=${SKEV}" "row=${key}=${SKEV}" "add=- ${SKP} — 맹점 조사: 작은 일"
+  skip_fail "sk_fl${skn}" "${key} 근거(건너뜀) + 「맹점 조사」 줄" 1 "${key} evidence cites no S<N> anchor"
+done
+
+# (6) 나눈 일 — 판독은 끝내기 커밋 펜스의 awk 와 같다: `## 7.` 절 안에서 앞 공백 · `- ` · 백틱을 뗀 줄이 `분해됨 — ` 로 시작.
+# 양의 짝: 나눈 일이어도 건너뜀 줄이 없으면 통과한다.
+ac3_pair sk_split; skip_edit sk_split "p7=${SKROAD}"
+skip_pass sk_split "나눈 일 + 건너뜀 줄 없음"
+skn=0
+for op in "p7=- ${SKROAD}" "p7=\`${SKROAD}\`" "p7=  ${SKROAD}" "p7=- \`${SKROAD}\`" "p7end=${SKROAD}"; do
+  skn=$((skn + 1)); ac3_pair "sk_sp${skn}"; skip_edit "sk_sp${skn}" "$op" "add=- ${SKP} — 재비판: 작은 일"
+  skip_fail "sk_sp${skn}" "나눈 일(${op%%=*} 「${op#*=}」) + 건너뜀 줄" 1 '건너뜀 줄: 나눈 일은 건너뛸 수 없다'
+done
+# §7 밖의 같은 글자 · §7 안의 줄 머리가 아닌 글자는 나눈 일이 아니다.
+skn=0
+for op in "p0=${SKROAD}" "p7=(분해된 일이면 첫 줄은 \`분해됨 — <로드맵 경로>\` 이다.)"; do
+  skn=$((skn + 1)); ac3_pair "sk_nsp${skn}"; skip_edit "sk_nsp${skn}" "$op" "add=- ${SKP} — 재비판: 작은 일"
+  grep -qF -- '분해됨 — ' "$TMPD/sk_nsp${skn}.md" \
+    && ok "F4/건너뜀(양성대조): payload 에 「분해됨 — 」 글자가 있다(${op%%=*})" || no "F4/건너뜀(양성대조): 분해됨 글자 변형이 적용되지 않았다"
+  skip_pass "sk_nsp${skn}" "나눈 일이 아닌 「분해됨 — 」 글자(${op%%=*}) + 건너뜀 줄" "$(skip_adv 재비판 '작은 일')"
+done
+# 문법이 틀린 건너뜀 줄도 「하나라도」 에 든다 — 두 사유가 함께 나온다.
+ac3_pair sk_split_bad; skip_edit sk_split_bad "p7=${SKROAD}" "add=- ${SKP} — 탐지: 작은 일"
+skip_fail sk_split_bad "나눈 일 + 문법이 틀린 건너뜀 줄" 0 '건너뜀 줄: 나눈 일은 건너뛸 수 없다' '건너뜀 줄의 자리 «탐지» 를 모른다'
+
+# (8) 돌린 조사의 건너뜀 줄이 남으면 실패한다 — 그 줄만 지우면 통과한다. 리뷰 부품 셋에는 이 검사가 없다((1) 의 통과 칸).
+SKCF_MAP='건너뜀 줄: §2 Budget: `범위 조사` 건너뜀 줄이 있는데 mapper 줄이 coverage-mapper'
+SKCF_SAT='건너뜀 줄: §2 Budget: `포화 판정` 건너뜀 줄이 있는데 포화 판정 · 사용자 종료 줄이'
+SKCF_BS='건너뜀 줄: §2 Budget: `맹점 조사` 건너뜀 줄이 있는데 audit §1 의 floor:blind_spot 근거가 「모델 판단으로 건너뜀」 으로 시작하지 않는다 — 맹점 조사를 돌렸으면 그 건너뜀 줄을 지운다'
+ac3_pair sk_cf_map; skip_edit sk_cf_map "add=- ${SKP} — 범위 조사: 작은 일"
+skip_fail sk_cf_map "coverage-mapper 1 + 「범위 조사」 줄" 1 "${SKCF_MAP} 1 이다 — 범위 조사를 돌렸으면 그 건너뜀 줄을 지운다"
+skip_edit sk_cf_map "del=${SKP} — 범위 조사"
+skip_pass sk_cf_map "같은 쌍에서 남은 「범위 조사」 줄만 지움"
+ac3_pair sk_cf_map3; skip_edit sk_cf_map3 "mapper=3" "add=- ${SKP} — 범위 조사: 작은 일"
+skip_fail sk_cf_map3 "coverage-mapper 3 + 「범위 조사」 줄" 1 "${SKCF_MAP} 3 이다"
+ac3_pair sk_cf_sat; skip_edit sk_cf_sat "add=- ${SKP} — 포화 판정: 작은 일"
+skip_fail sk_cf_sat "통과 꼴 판정 줄(포화) + 「포화 판정」 줄" 1 "${SKCF_SAT} 1개 있다 — 판정했거나 사용자가 끝냈으면 그 건너뜀 줄을 지운다"
+grep -q '^saturation:' <<<"$fl" \
+  && no "F4/건너뜀: 통과 꼴 판정 줄인데 포화 검사도 실패했다 — 모순 사유만 나와야 한다" || ok "F4/건너뜀: 통과 꼴 판정 줄 + 「포화 판정」 줄의 실패는 모순 사유 하나다"
+skip_edit sk_cf_sat "del=${SKP} — 포화 판정"
+skip_pass sk_cf_sat "같은 쌍에서 남은 「포화 판정」 줄만 지움"
+ac3_pair sk_cf_stop; skip_edit sk_cf_stop "sat=- 사용자 종료(@S2) — 포화 판정 전" "add=- ${SKP} — 포화 판정: 작은 일"
+skip_fail sk_cf_stop "사용자 종료 줄 + 「포화 판정」 줄" 1 "${SKCF_SAT} 1개 있다"
+ac3_pair sk_cf_bs; skip_edit sk_cf_bs "add=- ${SKP} — 맹점 조사: 작은 일"
+skip_fail sk_cf_bs "실재 S 를 인용한 맹점 근거 + 「맹점 조사」 줄" 1 "${SKCF_BS}"
+skip_edit sk_cf_bs "del=${SKP} — 맹점 조사"
+skip_pass sk_cf_bs "같은 쌍에서 남은 「맹점 조사」 줄만 지움"
+ac3_pair sk_cf_frozen; skip_edit sk_cf_frozen "row=floor:blind_spot=사용자-승인 박제(@S1) — §Open Questions 참조" "add=- ${SKP} — 맹점 조사: 작은 일"
+skip_fail sk_cf_frozen "박제로 닫은 맹점 근거 + 「맹점 조사」 줄" 1 "${SKCF_BS}"
+
+# (9) 입력 꼴 — `*` 불릿과 들여 쓴 불릿은 `-` 불릿과 같은 판정을 받는다(mapper · 포화 판정 줄의 형제 관례).
+skn=0
+for form in "* " "  - " "  * "; do
+  skn=$((skn + 1)); st="sk_f${skn}"
+  ac3_pair "${st}_adv"; skip_edit "${st}_adv" "add=${form}${SKP} — 재비판: 작은 일"
+  grep -qxF -- "${form}${SKP} — 재비판: 작은 일" "$TMPD/${st}_adv.audit.md" \
+    && ok "F4/건너뜀(양성대조): 건너뜀 줄이 「${form}」 꼴로 들어갔다" || no "F4/건너뜀(양성대조): 「${form}」 꼴 변형이 적용되지 않았다"
+  skip_pass "${st}_adv" "「${form}」 꼴 건너뜀 줄" "$(skip_adv 재비판 '작은 일')"
+  ac3_pair "${st}_unk"; skip_edit "${st}_unk" "add=${form}${SKP} — 탐지: 작은 일"
+  skip_fail "${st}_unk" "「${form}」 꼴 모르는 자리" 0 '건너뜀 줄의 자리 «탐지» 를 모른다'
+  ac3_pair "${st}_empty"; skip_edit "${st}_empty" "add=${form}${SKP} — codex:"
+  skip_fail "${st}_empty" "「${form}」 꼴 빈 이유" 0 '건너뜀 줄 «codex» 의 이유가 비었다'
+  ac3_pair "${st}_dup"; skip_edit "${st}_dup" "add=${form}${SKP} — codex: 둘째" "add=- ${SKP} — codex: 첫째"
+  skip_fail "${st}_dup" "「- 」 꼴과 「${form}」 꼴이 같은 자리 두 줄" 1 '건너뜀 줄 «codex» 가 두 줄 이상이다'
+  ac3_pair "${st}_map"; skip_edit "${st}_map" "mapper=0" "add=${form}${SKP} — 범위 조사: 작은 일"
+  skip_pass "${st}_map" "「${form}」 꼴 「범위 조사」 줄 + coverage-mapper 0" "$(skip_adv '범위 조사' '작은 일')"
+  ac3_pair "${st}_sat"; skip_edit "${st}_sat" nosat "add=${form}${SKP} — 포화 판정: 작은 일"
+  skip_pass "${st}_sat" "「${form}」 꼴 「포화 판정」 줄 + 판정 줄 없음" "$(skip_adv '포화 판정' '작은 일')"
+  ac3_pair "${st}_bs"; skip_edit "${st}_bs" "row=floor:blind_spot=${SKEV}" "add=${form}${SKP} — 맹점 조사: 작은 일"
+  skip_pass "${st}_bs" "「${form}」 꼴 「맹점 조사」 줄 + 건너뜀 근거" "$(skip_adv '맹점 조사' '작은 일')"
+  ac3_pair "${st}_cf"; skip_edit "${st}_cf" "add=${form}${SKP} — 범위 조사: 작은 일"
+  skip_fail "${st}_cf" "「${form}」 꼴 「범위 조사」 줄 + coverage-mapper 1" 1 "${SKCF_MAP} 1 이다"
+  ac3_pair "${st}_split"; skip_edit "${st}_split" "p7=${SKROAD}" "add=${form}${SKP} — 읽어 보기: 작은 일"
+  skip_fail "${st}_split" "「${form}」 꼴 건너뜀 줄 + 나눈 일" 1 '건너뜀 줄: 나눈 일은 건너뛸 수 없다'
+done
+# 이유 글의 판정 줄 글자는 판정 줄을 대신 지지 않는다 — 진짜 판정 줄도 `포화 판정` 건너뜀 줄도 없으면 여전히 「줄 없음」 이다.
+skn=0
+for why in "포화 판정 1: 포화 — 조사가 새로 연 것이 없다" "사용자 종료(@S2) — 포화 판정 전"; do
+  skn=$((skn + 1)); ac3_pair "sk_why${skn}"; skip_edit "sk_why${skn}" nosat "add=- ${SKP} — 재비판: ${why}"
+  { ! grep -qE '^[-*] (포화 판정 [0-9]+:|사용자 종료\(@S)' "$TMPD/sk_why${skn}.audit.md" && grep -qF -- "${why}" "$TMPD/sk_why${skn}.audit.md"; } \
+    && ok "F4/건너뜀(양성대조): 판정 줄 글자는 건너뜀 줄의 이유에만 있다(「${why}」)" || no "F4/건너뜀(양성대조): 이유 글 변형이 적용되지 않았다"
+  skip_fail "sk_why${skn}" "판정 줄 없음 + 이유에 「${why}」 를 적은 재비판 줄" 1 'saturation: §2 Budget: 포화 판정 줄 없음'
+done
+# 자리와 이유는 첫 `: ` 에서만 가른다 — 이유 글의 `: ` · ` — ` 는 글자 그대로 advisory 에 나온다.
+SKLONG='한도: 남음 — 그래도 작은 일: 파일 하나 — 끝'
+ac3_pair sk_long; skip_edit sk_long "add=- ${SKP} — codex: ${SKLONG}"
+skip_pass sk_long "이유에 「: 」 와 「 — 」 가 여럿" "$(skip_adv codex "${SKLONG}")"
+
+# (7) 출하 템플릿 — §2 설명 산문이 건너뜀 줄 꼴을 가르치지만 그대로 옮긴 audit 은 건너뜀으로 읽히지 않는다.
+grep -qF -- "${SKP}" "$REPO_ROOT/plugins/spec-distill/templates/interview-audit-template.md" \
+  && ok "F4/건너뜀(양성대조): 출하 audit 템플릿이 건너뜀 줄 꼴을 적는다" || no "F4/건너뜀(양성대조): 출하 audit 템플릿에 건너뜀 줄 설명이 없다 — 아래 단언이 공허하다"
+skip_run tpl
+{ [[ $rc -eq 0 && "$nadv" == "0" ]]; } \
+  && ok "F4/건너뜀: 채운 출하 템플릿 쌍은 건너뜀 advisory 없이 통과한다(설명 산문은 판정에 참여하지 않는다)" \
+  || { no "F4/건너뜀: 출하 템플릿이 건너뜀으로 읽혔거나 red 다 (rc=${rc} · 건너뜀 advisory ${nadv}줄)"; printf '    %s\n' "$out"; }
 finish
~~~~

### 패치 C (과제 5) — codex 펜스의 건너뜀 입력

- 대상: `plugins/spec-distill/skills/reviewing-brief/SKILL.md` · `plugins/spec-distill/tests/test_reviewing_brief_residue.sh`
- 기준: 6b923b62 — 과제 2–4 를 건 트리에도 그대로 걸린다(모의 실행에서 확인). 편집 R1 은 이 패치와 다른 자리다.
- 입력 블록의 두 구분 줄 사이는 **빈 줄**이다.

~~~~diff
diff --git a/plugins/spec-distill/skills/reviewing-brief/SKILL.md b/plugins/spec-distill/skills/reviewing-brief/SKILL.md
index 594bd78a..f57ed8fe 100644
--- a/plugins/spec-distill/skills/reviewing-brief/SKILL.md
+++ b/plugins/spec-distill/skills/reviewing-brief/SKILL.md
@@ -365,6 +365,14 @@ kill switch 는 P21 보안 컨트롤이라 그 공백은 "껐다고 믿게만" 
 SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
 # `## 프로필` 과 같은 한 줄 — Bash 도구는 호출마다 새 셸이라 앞 펜스의 대입이 여기로 오지 않는다.
 PROFILE="${CLAUDE_PLUGIN_ROOT}/references/docreview-profiles/brief.md"
+# 모델 판단으로 이 라운드의 codex 를 건너뛸 때만 아래 두 구분 줄 사이의 빈 줄을 이유 한 줄로 바꾼다 — 따옴표로
+# 감싸지 않고 글자 그대로. 비워 두면 건너뛰지 않는다. 건너뛰는 라운드도 이 펜스를 끝까지 돌린다.
+model_skip_codex=""   # 아래 읽기가 실패해도(heredoc 임시 파일을 못 만드는 셸) 빈 값 — 환경의 같은 이름을 물려받지 않는다
+IFS= read -r -d '' model_skip_codex <<'DEVBREW_MODEL_SKIP_EOF' || true
+
+DEVBREW_MODEL_SKIP_EOF
+model_skip_codex="${model_skip_codex//$'\n'/ }"
+model_skip_codex="${model_skip_codex#"${model_skip_codex%%[![:space:]]*}"}"; model_skip_codex="${model_skip_codex%"${model_skip_codex##*[![:space:]]}"}"
 # 러너 인자 넷(프로필 · 번들 · 프로젝트 · 산출물)이 이 호출 안에서 선다. `$CODEX_YAML`·`$BUNDLE` 은
 # `$STATE_DIR`(payload 의 순수 함수) 안의 파일이라 `## 입력` 과 같은 도출로 어느 셸에서나
 # 같은 파일이다. `## 입력` 을 앞에 이어 붙여 한 호출로 도는 것이 정상 경로다.
@@ -414,6 +422,17 @@ if [[ "$residue_unclear" == "1" ]]; then
   echo "[spec-distill] codex 산출물 경로를 비우지 못했다 — 지우지도 절단하지도 못했다: ${residue_left}. 이 라운드의 codex 축은 없이 간다. 5단계의 --codex 에 이 경로를 넘기지 마라 — 이번 라운드의 1단계 begin-round 가 rc 0 으로 끝났다면 prepare-recritic 이 이 파일을 부재(codex_predates_round)로 읽지만, 그 전제가 없으면 직전 라운드의 codex finding 이 이번 라운드 판정으로 섭취된다. 해소: 그 파일을 직접 지우거나 상태 디렉토리의 쓰기 권한을 복구하라." >&2
   codex_avail=""; skip_reason="residue_unclearable"; CODEX_YAML=""
 fi
+# 모델 판단 건너뜀은 «돌 수 있던» codex 만 건너뛴다. 위에서 다른 사유(끄기 스위치 · 미설치 · 게이트 입력 부재 ·
+# 중화 실패)가 섰으면 그 사유가 남고, 적은 이유는 건너뜀 공시 끝에 함께 실린다.
+model_skip_note=""
+if [[ -n "$model_skip_codex" ]]; then
+  if [[ "$codex_avail" == "true" ]]; then
+    codex_avail=""; skip_reason="model_skip"
+    model_skip_note=" 모델 판단으로 건너뛰었다 — 이유: ${model_skip_codex}"
+  else
+    model_skip_note=" 모델 판단 건너뜀(이유: ${model_skip_codex})보다 위 사유가 앞선다 — 모델이 건너뛴 라운드가 아니다"
+  fi
+fi
 if [[ "$codex_avail" == "true" ]]; then
   runner_rc=0
   bash "$SD/scripts/run_docreview_codex_reviewer.sh" "$PROFILE" "$BUNDLE" "$(pwd)" "$CODEX_YAML" || runner_rc=$?
@@ -421,7 +440,7 @@ if [[ "$codex_avail" == "true" ]]; then
   # 원래 실패의 rc 를 단 채 남긴 이번 라운드의 정직한 기록을 지운다.
   if [[ "$runner_rc" -eq 3 ]]; then rm -f "$CODEX_YAML" || true; fi
 else
-  echo "[spec-distill] codex 리뷰를 건너뛰었다 (reason: ${skip_reason:-unknown}) — 이번 리뷰는 Claude 만 봤다. 다른 모델의 시각과 codex 쪽 웹 근거가 없다 (degraded)." >&2
+  printf '%s\n' "[spec-distill] codex 리뷰를 건너뛰었다 (reason: ${skip_reason:-unknown}) — 이번 리뷰는 Claude 만 봤다. 다른 모델의 시각과 codex 쪽 웹 근거가 없다 (degraded).${model_skip_note}" >&2
 fi
 ```
 <!-- codex-gate:end -->
diff --git a/plugins/spec-distill/tests/test_reviewing_brief_residue.sh b/plugins/spec-distill/tests/test_reviewing_brief_residue.sh
index 5829543b..fb43eadd 100755
--- a/plugins/spec-distill/tests/test_reviewing_brief_residue.sh
+++ b/plugins/spec-distill/tests/test_reviewing_brief_residue.sh
@@ -23,6 +23,10 @@
 #     `## 번들` 이 머리 없이 들어온 상대경로로도 조립되는가, 진입 게이트 실패가 직전 번들을 세 층으로
 #     치우는가(M2), 상태 디렉토리 부재의 사유를 가르는가, 따로 돈 degrade-append 의 record 가 원장 또는
 #     두 번째 채널에 닿는가(M3).
+#   · K 모델 판단 건너뜀 — fence 의 리터럴 입력에 이유를 적은 라운드가 직전 산출물을 중화하고 러너를 부르지
+#     않으며 사유(model_skip)와 이유를 공시하는가, 입력이 비면 러너가 불리는가(양의 짝), 다른 사유(kill switch ·
+#     번들 부재 · 중화 불가)와 겹치면 그 사유가 남는가, 이유 글이 셸로 새지 않는가. bash 와 zsh 로.
+#   · Q 재비판을 건너뛴 라운드(`finalize --recritic-skipped`)를 엔진이 게이트 첫 줄 경고로 내는가(brief 프로필).
 # 감지기와 kill switch 설정은 리포 정본을 복사해 쓰고 러너만 스텁이다. PATH 는 진짜 `$PATH` 를
 # 이어붙이지 않는다 — 실제 codex 로 새는 경로를 막는다. 리포의 배포 지점은 건드리지 않는다.
 set -u
@@ -155,7 +159,9 @@ stale_into() {   # stale_into <path> — 직전 라운드가 정상으로 끝낸
 SIDS="rb01kill rb02noin rb03nopl rb04nobd rb05rc3x rb06nodt rb07keep rb08trap rb09lock
       rb10down rb11ctlx rb12trnc rb13pred rb21kill rb22noin rb23nopl rb24nobd rb25rc3x
       rb26nodt rb27lock rb30plce rb31swep rb32swpe rb40bndl rb41bndf rb42bnde rb43bndk
-      rb50relx rb51relb rb52gtrm rb53gttr rb54gtst rb55gtre rb56bdst rb57nopl rb58apnd rb59nosd"
+      rb50relx rb51relb rb52gtrm rb53gttr rb54gtst rb55gtre rb56bdst rb57nopl rb58apnd rb59nosd
+      rb60mskp rb61mnsk rb62mwsp rb63mkil rb64mnbd rb65mlck rb66mhst rb67mhse rb68mtwo rb69mdwn
+      rb70mske rb71mzsk rb72mzno rb73mzhs rb74mzki rb75menv rb76mxpg rb77mztp"
 bad=""
 for s in $SIDS; do
   DEVBREW_SPEC_DISTILL_SESSION_ID="$s" python3 "$PR/scripts/state_path.py" session-id >/dev/null 2>&1 || bad="$bad $s"
@@ -178,7 +184,7 @@ fire() {
   ( cd "$home" && env -i PATH="$bin:$BASE" HOME="$home" CODEX_API_KEY=t PYTHONDONTWRITEBYTECODE=1 \
       CLAUDE_PLUGIN_ROOT="$PR" DEVBREW_SPEC_DISTILL_SESSION_ID="$sid" \
       STUB_WRITE="$sw" STUB_RC="$rc" STUB_ARGV_OUT="$SCRATCH/$sid.argv" \
-      "$@" bash "${WITH_FENCE:-$FENCE}" ) >/dev/null 2>"$SCRATCH/$sid.err"
+      "$@" "${WITH_SH:-bash}" "${WITH_FENCE:-$FENCE}" ) >/dev/null 2>"$SCRATCH/$sid.err"
   printf '%s' "$yml"
 }
 
@@ -643,4 +649,176 @@ chmod 644 "$SF_M3"
 { [ "$FB_M3" != /brief-degrade-fallback.txt ] && grep -q 'probe-fallback-q2' "$FB_M3" 2>/dev/null && ! grep -q 'probe-fallback-q2' "$SF_M3"; } \
   && ok "M3: 원장이 쓰기 불가면 따로 돈 블록의 record 가 머리가 다시 도출한 두 번째 채널 파일에 닿는다" \
   || no "M3: 원장 쓰기 실패의 record 가 두 번째 채널 파일($FB_M3)에 없다 — \`>> \"\"\` 로 사라졌다"
+
+# ── K) 모델 판단 건너뜀 — 펜스의 리터럴 입력에 이유를 적은 라운드 ─────────────────────────────
+# 모델이 하는 그대로 한다: 여는 줄과 닫는 줄 사이의 빈 줄을 이유로 바꾼다(따옴표 없이). 자리의 모양이
+# 다르면 fill_skip 이 rc 1 이고 아래 칸은 재지 않는다.
+#   K1 codex 를 «쓸 수 있는» 환경 + 직전 산출물 → 산출물 중화 · 러너 미호출 · 사유 줄(model_skip + 이유)
+#   K2 양의 짝 — 같은 환경에서 입력을 비워 두면(공백뿐이어도) 러너가 불리고 그 산출물이 남는다
+#   K3 끄기 스위치 · 번들 부재와 겹침 → 그 사유가 남는다 · K4 중화 실패와 겹침 → residue_unclearable 이 남는다
+#   K5 이유 글의 따옴표 · 명령 치환 · 역따옴표 · 역슬래시가 셸로 새지 않고 글자 그대로 실린다(계측기 양성 대조 포함)
+#   K6 여러 줄 이유는 한 줄로 실린다 · KD 하류가 codex 부재로 읽는다 · KE errexit · KZ zsh
+SKIP_OPEN="IFS= read -r -d '' model_skip_codex <<'DEVBREW_MODEL_SKIP_EOF' || true"
+fill_skip() {   # fill_skip <이유> <out> [원본 펜스] → 그 이유를 적은 펜스. 입력 자리의 모양이 다르면 rc 1
+  python3 -I - "${3:-$FENCE}" "$1" "$SKIP_OPEN" > "$2" <<'PY'
+import sys
+lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
+hits = [i for i, l in enumerate(lines) if l == sys.argv[3]]
+if len(hits) != 1 or lines[hits[0] + 1 : hits[0] + 3] != ["", "DEVBREW_MODEL_SKIP_EOF"]:
+    sys.exit(1)
+lines[hits[0] + 1] = sys.argv[2]
+sys.stdout.write("\n".join(lines))
+PY
+}
+skip_lines() { grep -F 'codex 리뷰를 건너뛰었다 (reason: ' "$SCRATCH/$1.err" 2>/dev/null || true; }   # skip_lines <sid>
+hostile() {   # hostile <표지 접두> → 따옴표 · 명령 치환 · 역따옴표 · 변수 · 역슬래시(\n · \c 글자)가 든 이유 한 줄
+  printf 'a"b"c '"'"'d'"'"' $(touch %s-1) `touch %s-2` $HOME 정규식 \\n\\d \\c 끝' "$1" "$1"
+}
+WHY='작은 일이다 — 문구 한 줄 수정'
+SKIPF="$SCRATCH/fence-skip.sh"; SKIPF_E="$SCRATCH/fence-skip-errexit.sh"; SKIPF_WS="$SCRATCH/fence-skip-blank.sh"
+SKIPF_H="$SCRATCH/fence-skip-hostile.sh"; SKIPF_HE="$SCRATCH/fence-skip-hostile-errexit.sh"; SKIPF_2="$SCRATCH/fence-skip-twoline.sh"
+if fill_skip "$WHY" "$SKIPF" && fill_skip "$(printf '  \t ')" "$SKIPF_WS" && fill_skip "$(hostile "$SCRATCH/pwned-k")" "$SKIPF_H" \
+   && fill_skip "$(printf '첫 줄\n둘째 줄')" "$SKIPF_2" && bash -n "$SKIPF" && bash -n "$SKIPF_H" && bash -n "$SKIPF_2" \
+   && [ "$(grep -cF "$WHY" "$SKIPF")" = "1" ] && ! cmp -s "$FENCE" "$SKIPF"; then
+  ok "K 추출: 건너뜀 입력(여는 줄 · 빈 줄 · 닫는 줄)이 펜스에 한 번 있고 빈 줄을 이유로 바꾼 펜스가 bash -n 을 통과한다"
+  { echo 'set -euo pipefail'; cat "$SKIPF"; } > "$SKIPF_E"; { echo 'set -euo pipefail'; cat "$SKIPF_H"; } > "$SKIPF_HE"
+
+  k_skipped() {   # k_skipped <라벨> <sid> <yml> <기대 사유> <사유 줄에 있어야 할 글> — 중화 · 러너 미호출 · 사유 줄 하나
+    local label="$1" sid="$2" yml="$3" why="$4" has="$5" lines
+    cleared "$yml" \
+      && ok "$label: 직전 라운드 codex 산출물이 중화됐다 ($(state_of "$yml"))" \
+      || no "$label: 산출물이 $(state_of "$yml") 로 남았다 — 건너뛴 라운드가 직전 판정(또는 불린 러너의 것)을 이번 것으로 남긴다"
+    [ ! -e "$SCRATCH/$sid.argv" ] \
+      && ok "$label: 러너가 불리지 않았다" || no "$label: 러너가 불렸다 ($(tr '\n' '|' < "$SCRATCH/$sid.argv"))"
+    lines="$(skip_lines "$sid")"
+    assert_eq "$(printf '%s\n' "$lines" | grep -c .)" "1" "$label: 건너뜀 공시가 한 줄이다"
+    assert_contains "$lines" "codex 리뷰를 건너뛰었다 (reason: ${why})" "$label: 사유가 ${why} 다"
+    assert_contains "$lines" "$has" "$label: 그 줄이 적은 이유를 글자 그대로 싣는다"
+  }
+  k_ran() {   # k_ran <라벨> <sid> <펜스> <셸> — 같은 환경에서 러너가 인자 넷으로 불리고 그 산출물이 남는다(건너뜀 공시 없음)
+    local label="$1" sid="$2" yml
+    yml="$(WITH_SH="$4" WITH_FENCE="$3" fire "$sid" "$BIN_OK" plant ok 0 PAYLOAD="$DOC_B")"
+    { [ "$(grep -c . "$SCRATCH/$sid.argv" 2>/dev/null || echo 0)" = "4" ] && grep -q "$NEW" "$yml" 2>/dev/null && [ -z "$(skip_lines "$sid")" ]; } \
+      && ok "$label: 같은 환경에서 러너가 인자 넷으로 불리고 이번 라운드 산출물이 남는다 — 건너뜀 칸의 미호출은 입력 때문이다" \
+      || no "$label: 러너가 불리지 않았거나($(state_of "$SCRATCH/$sid.argv") argv) 산출물이 없거나($(state_of "$yml")) 건너뜀 공시가 났다 — 건너뜀 칸이 공허하다"
+    assert_not_contains "$(cat "$SCRATCH/$sid.err" 2>/dev/null)" "모델 판단" "$label: 모델 판단 문구가 나오지 않는다"
+  }
+
+  # K1 — codex 가용 · 직전 산출물 있음 · 이유 있음. 러너 스텁은 불리면 이번 라운드 마커를 쓴다(STUB_WRITE=ok).
+  yml="$(WITH_FENCE="$SKIPF" fire rb60mskp "$BIN_OK" plant ok 0 PAYLOAD="$DOC_B")"
+  k_skipped "K1(모델 건너뜀)" rb60mskp "$yml" model_skip "모델 판단으로 건너뛰었다 — 이유: ${WHY}"
+  # K2 — 양의 짝: 같은 환경 · 입력 없음 → 러너가 불리고 그 산출물이 남는다. 공백뿐인 입력도 같다.
+  k_ran "K2(입력 없음)" rb61mnsk "$FENCE" bash
+  k_ran "K2(공백뿐인 입력)" rb62mwsp "$SKIPF_WS" bash
+  # 입력은 펜스의 리터럴뿐이다 — 같은 이름의 환경 변수가 건너뜀을 고르지 못한다.
+  yml="$(fire rb75menv "$BIN_OK" plant ok 0 PAYLOAD="$DOC_B" model_skip_codex="환경에서 온 값" MODEL_SKIP_CODEX="환경에서 온 값")"
+  { [ "$(grep -c . "$SCRATCH/rb75menv.argv" 2>/dev/null || echo 0)" = "4" ] && grep -q "$NEW" "$yml" 2>/dev/null && [ -z "$(skip_lines rb75menv)" ]; } \
+    && ok "K2(환경 변수): 같은 이름의 환경 변수가 있어도 펜스의 빈 입력이 이긴다 — 러너가 불린다" \
+    || no "K2(환경 변수): 환경 변수가 건너뜀을 골랐다 ($(skip_lines rb75menv))"
+  # 입력이 없는 건너뜀 공시는 덧붙는 글 없이 그 한 줄 그대로다(A 의 kill switch 셀이 남긴 stderr).
+  assert_eq "$(skip_lines rb01kill)" "[spec-distill] codex 리뷰를 건너뛰었다 (reason: kill_switch) — 이번 리뷰는 Claude 만 봤다. 다른 모델의 시각과 codex 쪽 웹 근거가 없다 (degraded)." \
+    "K2(입력 없음 · 끄기 스위치): 건너뜀 공시가 덧붙는 글 없이 한 줄 그대로다"
+  # K3 — 끄기 스위치와 겹침: 스위치 사유가 남고(보안 컨트롤이 가려지지 않는다) 적은 이유는 그 줄 끝에 실린다.
+  yml="$(WITH_FENCE="$SKIPF" fire rb63mkil "$BIN_OK" plant ok 0 PAYLOAD="$DOC_B" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1)"
+  k_skipped "K3(끄기 스위치 + 모델 건너뜀)" rb63mkil "$yml" kill_switch "모델 판단 건너뜀(이유: ${WHY})보다 위 사유가 앞선다"
+  assert_not_contains "$(skip_lines rb63mkil)" "reason: model_skip" "K3: 모델 건너뜀이 끄기 스위치 사유를 덮지 않는다"
+  assert_not_contains "$(skip_lines rb63mkil)" "모델 판단으로 건너뛰었다" "K3: 스위치가 끈 라운드를 모델이 건너뛴 라운드라고 하지 않는다"
+  # K3b — 게이트 입력 부재(번들)와 겹침: 그 사유가 남는다.
+  yml="$(NO_BUNDLE=1 WITH_FENCE="$SKIPF" fire rb64mnbd "$BIN_OK" plant ok 0 PAYLOAD="$DOC_B")"
+  k_skipped "K3b(번들 부재 + 모델 건너뜀)" rb64mnbd "$yml" gate_inputs_missing "모델 판단 건너뜀(이유: ${WHY})보다 위 사유가 앞선다"
+  # K4 — 진입 중화 실패와 겹침: codex 는 가용(스위치 없음)인데 잔존물을 못 치운다 → residue_unclearable 이 남는다.
+  at="$(where rb65mlck "$DOC_B")"; mkdir -p "$at"; yml="$at/docreview-codex.yaml"; printf 'b\n' > "$at/brief-bundle.md"
+  stale_into "$yml"; chmod 444 "$yml"; chmod 555 "$at"
+  ( cd "$SCRATCH/rb65mlck" && env -i PATH="$BIN_OK:$BASE" HOME="$SCRATCH/rb65mlck" CODEX_API_KEY=t PYTHONDONTWRITEBYTECODE=1 \
+      CLAUDE_PLUGIN_ROOT="$PR" DEVBREW_SPEC_DISTILL_SESSION_ID=rb65mlck PAYLOAD="$DOC_B" STUB_WRITE=ok STUB_ARGV_OUT="$SCRATCH/rb65mlck.argv" \
+      bash "$SKIPF" ) >/dev/null 2>"$SCRATCH/rb65mlck.err"
+  k_left="$(state_of "$yml")"; chmod 755 "$at"; chmod 644 "$yml"
+  if [ "$k_left" = "absent" ] || [ "$k_left" = "0byte" ]; then
+    no "K4 전제 붕괴: 잠금이 중화를 막지 못했다 ($k_left)"
+  else
+    lines="$(skip_lines rb65mlck)"
+    assert_contains "$lines" "codex 리뷰를 건너뛰었다 (reason: residue_unclearable)" "K4(중화 실패 + 모델 건너뜀): residue_unclearable 이 남는다 ($k_left 잔존)"
+    assert_not_contains "$lines" "reason: model_skip" "K4: 모델 건너뜀이 중화 실패를 덮지 않는다"
+    assert_contains "$lines" "모델 판단 건너뜀(이유: ${WHY})보다 위 사유가 앞선다" "K4: 적은 이유는 그 줄 끝에 실린다"
+    [ ! -e "$SCRATCH/rb65mlck.argv" ] && ok "K4: 러너가 불리지 않았다" || no "K4: 중화 실패 라운드에 러너가 불렸다"
+  fi
+  # K5 — 이유 글이 셸로 새지 않는다. 계측기 양성 대조: 같은 글을 큰따옴표 대입에 넣으면 명령이 돈다.
+  printf 'v="%s"\n' "$(hostile "$SCRATCH/pwned-ctl")" > "$SCRATCH/k5-control.sh"
+  ( cd "$SCRATCH" && env -i PATH="$BASE" HOME="$SCRATCH" bash "$SCRATCH/k5-control.sh" ) >/dev/null 2>&1
+  { [ -e "$SCRATCH/pwned-ctl-1" ] && [ -e "$SCRATCH/pwned-ctl-2" ]; } \
+    && ok "K5 양성 대조: 같은 이유 글을 큰따옴표 대입에 넣으면 안의 명령이 돈다 (표지 파일 생성 — 글이 살아 있다)" \
+    || no "K5 양성 대조 붕괴: 큰따옴표 대입에서도 표지 파일이 생기지 않는다 — 아래 부재 단언은 아무것도 재지 않는다"
+  yml="$(WITH_FENCE="$SKIPF_H" fire rb66mhst "$BIN_OK" plant ok 0 PAYLOAD="$DOC_B")"
+  k_skipped "K5(적대 이유)" rb66mhst "$yml" model_skip "이유: $(hostile "$SCRATCH/pwned-k")"
+  yml="$(WITH_FENCE="$SKIPF_HE" fire rb67mhse "$BIN_OK" plant ok 0 PAYLOAD="$DOC_B")"
+  k_skipped "K5(적대 이유 · errexit)" rb67mhse "$yml" model_skip "이유: $(hostile "$SCRATCH/pwned-k")"
+  # echo 가 역슬래시를 푸는 셸(zsh 기본 · bash 의 xpg_echo)에서도 이유의 `\n` · `\c` 가 공시 줄을 쪼개거나 자르지 않는다.
+  # zsh 가 없는 기계에서도 재도록 bash 에 xpg_echo 를 켠 셸로 돌린다.
+  printf '#!/bin/sh\nexec bash -O xpg_echo "$@"\n' > "$SCRATCH/bash-xpg"; chmod +x "$SCRATCH/bash-xpg"
+  [ "$("$SCRATCH/bash-xpg" -c 'echo "a\nb"' | grep -c .)" = "2" ] \
+    && ok "K5 전제: xpg_echo 를 켠 bash 의 echo 가 역슬래시를 푼다 (계측기가 살아 있다)" \
+    || no "K5 전제 붕괴: xpg_echo 셸의 echo 가 역슬래시를 풀지 않는다 — 아래 칸은 echo 회귀를 못 잡는다"
+  yml="$(WITH_SH="$SCRATCH/bash-xpg" WITH_FENCE="$SKIPF_H" fire rb76mxpg "$BIN_OK" plant ok 0 PAYLOAD="$DOC_B")"
+  k_skipped "K5(적대 이유 · xpg_echo)" rb76mxpg "$yml" model_skip "이유: $(hostile "$SCRATCH/pwned-k")"
+  assert_eq "$(ls "$SCRATCH" | grep -c '^pwned-k')" "0" "K5: 이유 글 안의 명령이 돌지 않았다 (표지 파일 없음)"
+  # K6 — 여러 줄로 적은 이유는 한 줄로 실린다(공시는 줄 단위로 옮겨 실린다).
+  yml="$(WITH_FENCE="$SKIPF_2" fire rb68mtwo "$BIN_OK" plant ok 0 PAYLOAD="$DOC_B")"
+  k_skipped "K6(두 줄 이유)" rb68mtwo "$yml" model_skip "이유: 첫 줄 둘째 줄"
+  # KD — 하류: 모델이 건너뛴 라운드의 codex 경로를 prepare-recritic 이 부재로 읽고 직전 마커를 섭취하지 않는다.
+  at="$(where rb69mdwn "$DOC_B")"; mkdir -p "$at"; open_round "$at"
+  yml="$(WITH_FENCE="$SKIPF" fire rb69mdwn "$BIN_OK" plant ok 0 PAYLOAD="$DOC_B")"
+  kd="$(ingest "$at" "$yml")"
+  case "$kd" in
+    True\|*\|0\|*) ok "KD: 모델이 건너뛴 라운드에서 하류가 codex 부재로 읽고 직전 마커를 섭취하지 않는다 ($kd)" ;;
+    *) no "KD: 모델이 건너뛴 라운드에서 하류가 codex 판정을 읽는다 ($kd)" ;;
+  esac
+  # KE — errexit 을 물려받아도 같다.
+  yml="$(WITH_FENCE="$SKIPF_E" fire rb70mske "$BIN_OK" plant ok 0 PAYLOAD="$DOC_B")"
+  k_skipped "KE(errexit)" rb70mske "$yml" model_skip "모델 판단으로 건너뛰었다 — 이유: ${WHY}"
+  # KZ — zsh(Bash 도구의 셸일 수 있다)로도 같다: 건너뜀 · 양의 짝 · 적대 이유 · 끄기 스위치 겹침.
+  ZSH_BIN="$(command -v zsh 2>/dev/null || true)"
+  if [ -n "$ZSH_BIN" ]; then
+    yml="$(WITH_SH="$ZSH_BIN" WITH_FENCE="$SKIPF" fire rb71mzsk "$BIN_OK" plant ok 0 PAYLOAD="$DOC_B")"
+    k_skipped "KZ(zsh · 모델 건너뜀)" rb71mzsk "$yml" model_skip "모델 판단으로 건너뛰었다 — 이유: ${WHY}"
+    k_ran "KZ(zsh · 입력 없음)" rb72mzno "$FENCE" "$ZSH_BIN"
+    yml="$(WITH_SH="$ZSH_BIN" WITH_FENCE="$SKIPF_H" fire rb73mzhs "$BIN_OK" plant ok 0 PAYLOAD="$DOC_B")"
+    k_skipped "KZ(zsh · 적대 이유)" rb73mzhs "$yml" model_skip "이유: $(hostile "$SCRATCH/pwned-k")"
+    yml="$(WITH_SH="$ZSH_BIN" WITH_FENCE="$SKIPF" fire rb74mzki "$BIN_OK" plant ok 0 PAYLOAD="$DOC_B" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1)"
+    k_skipped "KZ(zsh · 끄기 스위치 + 모델 건너뜀)" rb74mzki "$yml" kill_switch "모델 판단 건너뜀(이유: ${WHY})보다 위 사유가 앞선다"
+    assert_eq "$(ls "$SCRATCH" | grep -c '^pwned-k')" "0" "KZ(zsh): 이유 글 안의 명령이 돌지 않았다"
+    # zsh 가 heredoc 임시 파일을 못 만드는 환경(TMPPREFIX 쓰기 불가)이면 입력 읽기가 실패한다. 그래도 fence 는 errexit ·
+    # nounset 아래에서 죽지 않고, 환경의 같은 이름을 물려받지 않고, 빈 입력으로 간다 — 러너가 불린다.
+    mkdir -p "$SCRATCH/ro-tmp"; chmod 555 "$SCRATCH/ro-tmp"
+    yml="$(WITH_SH="$ZSH_BIN" WITH_FENCE="$FENCE_E" fire rb77mztp "$BIN_OK" plant ok 0 PAYLOAD="$DOC_B" TMPPREFIX="$SCRATCH/ro-tmp/zsh" model_skip_codex="환경에서 온 값")"
+    if grep -q 'here document' "$SCRATCH/rb77mztp.err" 2>/dev/null; then
+      { [ "$(grep -c . "$SCRATCH/rb77mztp.argv" 2>/dev/null || echo 0)" = "4" ] && grep -q "$NEW" "$yml" 2>/dev/null && [ -z "$(skip_lines rb77mztp)" ]; } \
+        && ok "KZ(zsh · 입력 읽기 실패): fence 가 죽지 않고 환경 값을 물려받지 않으며 러너가 불린다 (빈 입력으로 간다)" \
+        || no "KZ(zsh · 입력 읽기 실패): fence 가 죽었거나 환경 값이 건너뜀을 골랐다 — stderr 끝 줄: $(tail -n 1 "$SCRATCH/rb77mztp.err")"
+    else
+      echo "  - KZ(zsh · 입력 읽기 실패): 이 zsh 는 TMPPREFIX 가 쓰기 불가여도 heredoc 을 만든다 — 이 칸을 건너뛴다"
+    fi
+  else
+    echo "  - KZ(zsh): zsh 없음 — zsh 실행 확인을 건너뛴다"
+  fi
+else
+  no "K 추출: 건너뜀 입력 자리(여는 줄 · 빈 줄 · 닫는 줄)를 펜스에서 찾지 못했거나 채운 펜스의 문법이 깨졌다 — K 칸은 재지 않는다"
+fi
+
+# ── Q) 재비판을 건너뛴 라운드 — 엔진이 그 사실을 게이트 첫 줄의 경고로 낸다 (brief 프로필) ─────────
+# 이 자리는 재비판을 `finalize --recritic-skipped` 로 건너뛴다. 양의 짝: 재비판 블록이 온 라운드에는 그 경고가 없다.
+q_round() {   # q_round <dir> <finalize 인자…> → 게이트 렌더 첫 줄 (finalize rc 는 <dir>.rc)
+  local d="$1"; shift
+  mkdir -p "$d"; open_round "$d"; cp "$FX/critic-r1.txt" "$d/critic.txt"
+  python3 "$SDS/docreview_route.py" prepare-recritic --state-dir "$d" --critic "$d/critic.txt" > "$d/prep.json" 2>/dev/null
+  python3 "$SDS/docreview_route.py" finalize --state-dir "$d" "$@" --doc "$DOC_B" > "$d/fin.json" 2>/dev/null; echo "$?" > "$d.rc"
+  python3 "$SDS/docreview_state.py" gate --state-dir "$d" --render 2>/dev/null | sed -n 1p
+}
+Q_WARN='재비판이 돌지 않아 잘못된 지적을 걸러 내지 못했다 (doc-recritic: '
+q_skip="$(q_round "$SCRATCH/q-skip" --recritic-skipped)"
+q_ran="$(q_round "$SCRATCH/q-ran" --recritic "$FX/recritic-empty.txt")"
+assert_eq "$(cat "$SCRATCH/q-skip.rc" 2>/dev/null) $(cat "$SCRATCH/q-ran.rc" 2>/dev/null)" "0 0" "Q 전제: 두 라운드의 finalize 가 rc 0 이다 (brief 프로필)"
+assert_contains "$q_skip" "$Q_WARN" "Q: 재비판을 건너뛴 라운드의 게이트 첫 줄이 재비판이 돌지 않았다고 경고한다"
+assert_contains "$q_skip" "skipped)" "Q: 그 경고의 괄호가 건너뜀(skipped)을 싣는다"
+assert_contains "$q_ran" "라운드를 마쳤다" "Q 양의 짝 전제: 재비판이 돈 라운드의 첫 줄을 읽었다"
+assert_not_contains "$q_ran" "재비판이 돌지 않아" "Q 양의 짝: 재비판이 돈 라운드의 첫 줄에는 그 경고가 없다"
 finish
~~~~

### 패치 B1 (과제 8) — 머지 펜스 · 다시 확인 펜스

- 대상: `plugins/spec-distill/skills/pm-interview/references/finishing.md` · `plugins/spec-distill/tests/test_finish_pr_merge.sh`
- 기준: **과제 7 까지 건 트리**. 시제품의 원래 패치는 6b923b62 기준이라, 과제 7 이 「PR 과 머지」 절 바로 위 줄(B-R 의 커밋 문장)을 바꾼 뒤에는 첫 hunk 가 걸리지 않았다 — 아래는 그 트리에서 다시 뜬 것이다(`diff -ru`, `git apply -p1` 로 걸린다).
- 걸리지 않으면 첫 hunk 만 손으로 건다 — 「PR 과 머지 — 분해된 일 ①/② 만.」 문단에서 아래 구절을 바꾼다.

찾을 구절:

~~~~
두 펜스 모두 마지막 줄이 판결이고, 판결 줄 없이 끝나면(시간 초과 · 끊김 포함) `NONE` 으로 읽는다. 두 펜스는 gh 를 직접 찾거나 부르지 않고
~~~~

바꿀 구절:

~~~~
펜스는 모두 마지막 줄이 판결이고, 판결 줄 없이 끝나면(시간 초과 · 끊김 포함) `NONE` 으로 읽는다 — 하나만 다르다: 머지 펜스의 출력에 판결 줄이 없고 `interview-merge-requested:` 표시 줄이 있으면 `NONE` 으로 읽지 않고 3 의 다시 확인 펜스를 돌려 그 판결대로 잇는다. 이 절의 펜스는 gh 를 직접 찾거나 부르지 않고
~~~~

~~~~diff
diff -ru a/plugins/spec-distill/skills/pm-interview/references/finishing.md b/plugins/spec-distill/skills/pm-interview/references/finishing.md
--- a/plugins/spec-distill/skills/pm-interview/references/finishing.md	2026-11-15 13:28:15
+++ b/plugins/spec-distill/skills/pm-interview/references/finishing.md	2026-11-15 13:28:15
@@ -721,7 +721,7 @@
 
 커밋 전에 도는 단계라 이 결과가 커밋 대상이다 — 그 갈래의 커밋 펜스(`interview-commit`)가 brief §7 의 `분해됨 — <로드맵 경로>` 줄에서 로드맵 폴더를 도출해 세 파일과 한 커밋에 넣는다(B-1 끝 질문의 「확정하고 끝낸다」 · 「brief만 종료」 도 같은 펜스로 커밋한다). 분해된 일의 ①/② 는 커밋 뒤 아래 「PR 과 머지」 를 거쳐 두 줄로 간다.
 
-**PR 과 머지 — 분해된 일 ①/② 만.** 지휘자는 로드맵을 기본 브랜치에서 읽는다 — 브랜치에만 있는 로드맵은 상태를 셀 수 없고, 에픽 worktree 도 기본 브랜치에서 갈라져 묶음 파일이 없다. 그래서 인터뷰가 커밋 뒤 PR 을 열고 머지를 묻는다. 커밋 펜스가 「brief · audit · 상태 파일 · 로드맵 폴더를 커밋했다」 줄을 냈을 때만 돈다 — 그 줄이 아니면(커밋하지 않음 · 실패 · 로드맵 폴더를 빼고 커밋) 이 절을 건너뛰고 두 줄 앞에 지휘 세션을 이 커밋이 기본 브랜치에 머지된 뒤 열라고 한 줄로 알린다. ④ · B-1 은 PR 을 열지 않는다. 두 펜스 모두 마지막 줄이 판결이고, 판결 줄 없이 끝나면(시간 초과 · 끊김 포함) `NONE` 으로 읽는다. 두 펜스는 gh 를 직접 찾거나 부르지 않고 `gh_repo.py` 의 하위 명령으로만 부른다 — 그 모듈이 gh 를 찾고 origin 레포를 명시한다.
+**PR 과 머지 — 분해된 일 ①/② 만.** 지휘자는 로드맵을 기본 브랜치에서 읽는다 — 브랜치에만 있는 로드맵은 상태를 셀 수 없고, 에픽 worktree 도 기본 브랜치에서 갈라져 묶음 파일이 없다. 그래서 인터뷰가 커밋 뒤 PR 을 열고 머지를 묻는다. 커밋 펜스가 「brief · audit · 상태 파일 · 로드맵 폴더를 커밋했다」 줄을 냈을 때만 돈다 — 그 줄이 아니면(커밋하지 않음 · 실패 · 로드맵 폴더를 빼고 커밋) 이 절을 건너뛰고 두 줄 앞에 지휘 세션을 이 커밋이 기본 브랜치에 머지된 뒤 열라고 한 줄로 알린다. ④ · B-1 은 PR 을 열지 않는다. 펜스는 모두 마지막 줄이 판결이고, 판결 줄 없이 끝나면(시간 초과 · 끊김 포함) `NONE` 으로 읽는다 — 하나만 다르다: 머지 펜스의 출력에 판결 줄이 없고 `interview-merge-requested:` 표시 줄이 있으면 `NONE` 으로 읽지 않고 3 의 다시 확인 펜스를 돌려 그 판결대로 잇는다. 이 절의 펜스는 gh 를 직접 찾거나 부르지 않고 `gh_repo.py` 의 하위 명령으로만 부른다 — 그 모듈이 gh 를 찾고 origin 레포를 명시한다.
 
 **「여기서 계속」 으로 왔으면.** 게이트의 기타 칸 갈래(정본 `proceed-gate.md` 의 「기타 칸」 — 두 줄 없이 이 세션에서 다음 세션 줄을 따른다)에서는 `interview-merge: MERGED` 를 받은 턴에만 지휘자를 부른다. `MERGED` 여도 출력에 「머지 뒤 origin 을 받지 못했다」 줄이 있으면 부르지 않는다 — 그 줄과 아래 지휘자 줄을 보이고 턴을 끝낸다(받기 전에는 지휘자가 이 로드맵을 기본 브랜치에서 찾지 못한다). 그 밖(이 절을 건너뜀 · `interview-pr: NONE` · `interview-merge: NONE` · 「직접 머지」)에는 지휘자를 부르지 않는다 — PR 주소(있으면)와 아래 지휘자 줄을 보이고, 그 커밋이 기본 브랜치에 머지된 뒤 그 줄을 입력하라고 알린 뒤 턴을 끝낸다. 머지 전의 로드맵으로는 지휘자가 에픽을 세지 못한다.
 
@@ -791,7 +791,7 @@
 <!-- interview-pr:end -->
 
 2. **머지 묻기.** `AskUserQuestion` 하나 — 질문 「<주제> — 지휘자는 로드맵을 기본 브랜치에서 읽어, 이 PR(<PR 주소>)이 머지돼야 에픽을 시작할 수 있다. 지금 머지할까?」, 선택지 「머지 (권장)」(고르면 CI 검사가 끝나길 기다렸다가 PR 을 기본 브랜치에 합치고, 붙여 넣을 두 줄을 보인다) · 「직접 머지」(PR 주소만 보이고, 머지한 뒤 지휘자 줄을 입력하라고 알린다). 「(권장)」 꼬리는 1 의 펜스가 `interview-pr-files: ONLY` 를 냈을 때만 단다 — 그 두 폴더(인터뷰 폴더 바로 아래 · 로드맵 폴더)의 파일만 바꾸는 PR 이라 머지를 권한다. `MIXED` 나 `UNKNOWN` 이면 꼬리를 떼어 「머지」 로 내고, 질문 앞 글에 1 의 펜스가 보인 파일 목록(세지 못했으면 그 줄)을 다시 보인다 — 무엇이 함께 머지되는지 보고 고르게 한다. 답은 라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다.
-3. **머지.** 「머지」면 아래 펜스의 `BRIEF` 자리표를 1 과 같은 값으로, `URL` 자리표를 1 의 PR 주소로, `HEAD_SHA` 자리표를 1 의 `interview-pr-head:` 값으로 바꿔 Bash 도구의 백그라운드 실행으로 돌린다(CI 를 기다리는 동안 도구 시간 상한에 걸리지 않게 — 끝나면 알림이 온다). 띄운 턴에는 `[spec-distill] PR 머지를 기다린다 — CI 검사가 끝나면 머지하고 이어 간다(검사는 30분까지 기다린다): <PR 주소>` 한 줄을 보이고 턴을 끝낸다 — 두 줄은 아직 보이지 않는다. 알림이 온 턴에 출력의 `[spec-distill]` 줄을 그대로 보이고 판결대로 잇는다. 알림보다 먼저 사용자가 말을 걸면 그 턴에 백그라운드 출력을 읽어, 판결 줄이 있으면 판결대로 잇고 없으면 아직 기다리는 중이라고 답한다. 사용자가 그만두라고 하면 그 백그라운드 작업을 끝낸다(작업을 끝내면 펜스가 기다리던 gh 도 함께 끝나 머지로 가지 않는다) — 끝낸 출력에 판결 줄이 이미 있으면 그 판결대로, 없으면 `interview-merge: NONE` 으로 읽어 잇는다. 이 기다림은 polite stop 이 아니다 — ①/② 의 완료 동작(두 줄과 위치를 노출하고 턴을 끝낸다)은 판결을 받은 턴에 한다. 펜스는 PR 주소의 레포가 origin 인지 대조하고, 그 PR 이 열려 있고 이 레포 안의 지금 브랜치에서 기본 브랜치로 가는 PR 이며 끝 커밋이 1 에서 push 한 커밋 그대로인지 먼저 확인한다. 머지도 그 커밋에 묶어 요청한다 — 묻고 난 뒤(CI 를 기다리는 사이 포함) PR 에 다른 커밋이 올라오면 머지하지 않는다. 막 연 PR 은 CI 가 아직 붙지 않았을 수 있어 「검사 없음」을 1분 동안 다시 본 뒤에야 받아들이고, 검사가 있으면 끝나길 30분까지 기다린다 — 실패한 검사가 있거나 30분을 넘기면 머지하지 않는다. 머지 방식은 그 레포가 허용하는 것 가운데 merge commit → squash → rebase 순서로 시도하고, 하나가 거절되면(보호 규칙 등) 다음 것을 시도한다. gh 가 머지를 받아들이면 PR 상태를 다시 읽는다 — 머지 대기열이나 자동 머지를 쓰는 레포에서는 gh 가 요청만 걸어 두고 성공으로 끝나므로, 상태가 `MERGED` 가 아니면 판결은 `NONE` 이다. `MERGED` 면 origin 을 받아 지휘자가 읽는 로컬의 기본 브랜치 ref 를 맞춘다 — 받지 못하면 그 사실을 알리고 판결은 `MERGED` 그대로다. 마지막 줄이 `interview-merge: MERGED` 면 두 줄을 그대로 노출하고(머지 안내 없이), `interview-merge: NONE` 이거나 「직접 머지」면 두 줄 앞에 PR 주소와 함께 지휘 세션을 이 PR 이 기본 브랜치에 머지된 뒤 열라고 한 줄로 알린다.
+3. **머지.** 「머지」면 아래 펜스의 `BRIEF` 자리표를 1 과 같은 값으로, `URL` 자리표를 1 의 PR 주소로, `HEAD_SHA` 자리표를 1 의 `interview-pr-head:` 값으로 바꿔 Bash 도구의 백그라운드 실행으로 돌린다(CI 를 기다리는 동안 도구 시간 상한에 걸리지 않게 — 끝나면 알림이 온다). 띄운 턴에는 `[spec-distill] PR 머지를 기다린다 — CI 검사가 끝나면 머지하고 이어 간다(검사는 30분까지 기다린다): <PR 주소>` 한 줄을 보이고 턴을 끝낸다 — 두 줄은 아직 보이지 않는다. 알림이 온 턴에 출력의 `[spec-distill]` 줄을 그대로 보이고 판결대로 잇는다. 알림보다 먼저 사용자가 말을 걸면 그 턴에 백그라운드 출력을 읽어, 판결 줄이 있으면 판결대로 잇고 없으면 아직 기다리는 중이라고 답한다. 사용자가 그만두라고 하면 그 백그라운드 작업을 끝낸다(작업을 끝내면 펜스가 기다리던 gh 도 함께 끝나 머지로 가지 않는다) — 끝낸 출력에 판결 줄이 이미 있으면 그 판결대로 잇는다. 판결 줄이 없고 `interview-merge-requested:` 표시 줄이 있으면 머지 요청이 이미 나갔을 수 있다 — `NONE` 으로 읽지 않고 머지 펜스 아래의 다시 확인 펜스를 돌려 그 판결대로 잇는다. 표시 줄도 없으면 `interview-merge: NONE` 으로 읽어 잇는다. 이 기다림은 polite stop 이 아니다 — ①/② 의 완료 동작(두 줄과 위치를 노출하고 턴을 끝낸다)은 판결을 받은 턴에 한다. 펜스는 PR 주소의 레포가 origin 인지 대조하고, 그 PR 이 열려 있고 이 레포 안의 지금 브랜치에서 기본 브랜치로 가는 PR 이며 끝 커밋이 1 에서 push 한 커밋 그대로인지 먼저 확인한다. 그 PR 이 이미 머지돼 있으면(상태가 머지됨이고 이 레포 안의 지금 브랜치에서 기본 브랜치로 간 PR) 검사를 기다리지도 머지를 요청하지도 않고 머지됨으로 읽는다 — origin 을 받고 판결은 `MERGED` 다. 머지도 그 커밋에 묶어 요청한다 — 묻고 난 뒤(CI 를 기다리는 사이 포함) PR 에 다른 커밋이 올라오면 머지하지 않는다. 막 연 PR 은 CI 가 아직 붙지 않았을 수 있어 「검사 없음」을 1분 동안 다시 본 뒤에야 받아들이고, 검사가 있으면 끝나길 30분까지 기다린다 — 실패한 검사가 있거나 30분을 넘기면 머지하지 않는다. 머지 방식은 그 레포가 허용하는 것 가운데 merge commit → squash → rebase 순서로 시도하고, 하나가 거절되면(보호 규칙 등) 다음 것을 시도한다. 방식마다 요청을 보내기 직전에 표시 줄 `interview-merge-requested: <PR 번호>` 를 낸다. gh 의 머지 명령이 실패로 끝났어도 다시 읽은 PR 이 머지돼 있으면 다음 방식을 시도하지 않고 머지됨으로 읽는다. gh 가 머지를 받아들이면 PR 상태를 다시 읽는다 — 머지 대기열이나 자동 머지를 쓰는 레포에서는 gh 가 요청만 걸어 두고 성공으로 끝나므로, 상태가 `MERGED` 가 아니면 판결은 `NONE` 이다. `MERGED` 면 origin 을 받아 지휘자가 읽는 로컬의 기본 브랜치 ref 를 맞춘다 — 받지 못하면 그 사실을 알리고 판결은 `MERGED` 그대로다. 마지막 줄이 `interview-merge: MERGED` 면 두 줄을 그대로 노출하고(머지 안내 없이), `interview-merge: NONE` 이거나 「직접 머지」면 두 줄 앞에 PR 주소와 함께 지휘 세션을 이 PR 이 기본 브랜치에 머지된 뒤 열라고 한 줄로 알린다.
 
 <!-- interview-merge:begin -->
 ```bash
@@ -800,6 +800,7 @@
 URL="<interview-pr 이 낸 PR 주소>"
 HEAD_SHA="<interview-pr 이 낸 끝 커밋>"
 none() { echo "[spec-distill] 머지하지 않았다 — $1. 직접 머지한 뒤 지휘자를 부른다: ${URL}"; echo "interview-merge: NONE"; exit 0; }
+merged() { git -C "$top" fetch -q origin || echo "[spec-distill] 머지 뒤 origin 을 받지 못했다(위 사유) — 지휘자를 부르기 전에 git fetch origin 을 돌린다. 받기 전에는 지휘자가 이 로드맵을 기본 브랜치에서 찾지 못한다."; echo "interview-merge: MERGED"; exit 0; }
 case "$BRIEF" in ""|*"<"*) none "BRIEF 가 비었거나 자리표 그대로다" ;; esac
 case "$URL" in https://*/pull/[0-9]*) ;; *) none "PR 주소가 비었거나 자리표 그대로다" ;; esac
 case "$HEAD_SHA" in ""|*[!0-9a-f]*) none "끝 커밋이 비었거나 자리표 그대로다" ;; esac
@@ -810,6 +811,8 @@
 [ -n "$cur" ] && [ -n "$def" ] || none "지금 브랜치(${cur:-없음})나 기본 브랜치(${def:-없음})를 가르지 못했다"
 num="$(python3 "$SD/scripts/gh_repo.py" pr-number "$URL" --root "$top")" || none "PR 주소가 이 레포(origin)의 PR 이 아니다(위 사유)"
 pr="$(python3 "$SD/scripts/gh_repo.py" pr-identity "$num" --root "$top")" || none "PR 을 읽지 못했다(위 사유)"
+# 이미 머지된 PR — 상태가 머지됨이고 바탕 · 브랜치가 같은 이 레포의 PR 이면 머지됨으로 읽는다(끝 커밋은 대조하지 않는다).
+case "$pr" in "MERGED $def $cur false "*) echo "[spec-distill] PR 이 이미 머지돼 있다 — ${URL}"; merged ;; esac
 [ "$pr" = "OPEN $def $cur false $HEAD_SHA" ] || none "이 PR 은 열린, 이 레포의 ${cur} → ${def} PR 이 아니거나 끝 커밋이 물을 때(${HEAD_SHA})와 다르다(읽은 것: ${pr})"
 out="$(mktemp)" || none "검사 출력 임시 파일을 만들지 못했다"
 n=0
@@ -840,6 +843,8 @@
 how=""
 for how in --merge --squash --rebase; do
   case " $ways " in *" $how "*) ;; *) continue ;; esac
+  # 요청을 보내기 직전의 표시 줄 — 판결 줄 없이 끝난 출력에 이 줄이 있으면 다시 확인 펜스가 돈다.
+  echo "interview-merge-requested: $num"
   if python3 "$SD/scripts/gh_repo.py" pr-merge "$num" "$how" --match-head-commit "$HEAD_SHA" --root "$top"; then
     # gh 가 받아들였어도 머지 대기열 · 자동 머지면 아직 머지 전이다 — 상태를 다시 읽는다(15초까지).
     st=""
@@ -857,17 +862,61 @@
       exit 0
     fi
     echo "[spec-distill] PR 을 머지했다(${how#--}) — ${URL}"
-    git -C "$top" fetch -q origin || echo "[spec-distill] 머지 뒤 origin 을 받지 못했다(위 사유) — 지휘자를 부르기 전에 git fetch origin 을 돌린다. 받기 전에는 지휘자가 이 로드맵을 기본 브랜치에서 찾지 못한다."
-    echo "interview-merge: MERGED"
-    exit 0
+    merged
   fi
   pr="$(python3 "$SD/scripts/gh_repo.py" pr-identity "$num" --root "$top")" || pr=""
+  case "$pr" in "MERGED $def $cur false "*) echo "[spec-distill] gh 의 머지 명령은 실패로 끝났지만(위 사유) PR 은 머지돼 있다 — ${URL}"; merged ;; esac
   [ "$pr" = "OPEN $def $cur false $HEAD_SHA" ] || none "머지가 거절됐고(위 사유) PR 이 물을 때와 달라졌다 — 끝 커밋이 바뀌었거나 닫혔다(읽은 것: ${pr:-읽지 못함} · 물을 때의 끝 커밋: ${HEAD_SHA})"
   echo "[spec-distill] ${how#--} 머지가 거절됐다(위 사유) — 다음 방식을 시도한다."
 done
 none "허용된 머지 방식이 모두 거절됐다(위 사유 — 충돌 · 보호 규칙 · 권한)"
 ```
 <!-- interview-merge:end -->
+
+**다시 확인 — 판결 줄 없이 끝난 머지 펜스의 출력에 `interview-merge-requested:` 표시 줄이 있을 때만.** 아래 펜스의 `BRIEF` · `URL` 자리표를 3 과 같은 값으로 바꿔 돌리고(백그라운드로 띄우지 않는다 — 기다림은 15초까지다) 나온 `[spec-distill]` 줄을 그대로 보인 뒤 그 판결대로 잇는다. 펜스는 읽기만 한다 — 머지를 요청하지도 CI 검사를 기다리지도 않는다. PR 주소의 레포가 origin 인지 대조하고, PR 상태를 머지 펜스의 머지 뒤 상태 읽기와 같은 간격 · 횟수(5초 간격 네 번까지)로 읽는다. 상태가 머지됨이고 이 레포 안의 지금 브랜치에서 기본 브랜치로 간 PR 이면 origin 을 받고 `interview-merge: MERGED`, 끝까지 아니면 머지 요청이 나갔다는 사실과 PR 주소를 알리고 `interview-merge: NONE` 이다 — PR 상태를 끝까지 읽지 못했을 때(gh 인증 · 네트워크)도 머지됨으로 읽지 않고, 읽지 못했다는 사실을 따로 알린다.
+
+<!-- interview-merge-recheck:begin -->
+```bash
+SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
+BRIEF="<Step A.5 의 PAYLOAD 절대경로>"
+URL="<interview-pr 이 낸 PR 주소>"
+none() { echo "[spec-distill] 머지됐는지 다시 확인하지 못했다 — $1. 머지 요청은 나갔을 수 있다 — PR 에서 머지된 것을 확인한 뒤 지휘자를 부른다: ${URL}"; echo "interview-merge: NONE"; exit 0; }
+case "$BRIEF" in ""|*"<"*) none "BRIEF 가 비었거나 자리표 그대로다" ;; esac
+case "$URL" in https://*/pull/[0-9]*) ;; *) none "PR 주소가 비었거나 자리표 그대로다" ;; esac
+top="$(git -C "$(dirname -- "$BRIEF")" rev-parse --show-toplevel 2>/dev/null)" || top=""
+[ -n "$top" ] || none "git 저장소가 아니다"
+cur="$(git -C "$top" branch --show-current 2>/dev/null)" || cur=""
+def="$(python3 "$SD/scripts/repo_defaults.py" default-branch --check-remote --root "$top")" || def=""
+[ -n "$cur" ] && [ -n "$def" ] || none "지금 브랜치(${cur:-없음})나 기본 브랜치(${def:-없음})를 가르지 못했다"
+num="$(python3 "$SD/scripts/gh_repo.py" pr-number "$URL" --root "$top")" || none "PR 주소가 이 레포(origin)의 PR 이 아니다(위 사유)"
+# 요청 직후에는 아직 열림으로 보일 수 있다 — 머지 펜스의 머지 뒤 상태 읽기와 같은 간격 · 횟수로 읽는다(15초까지).
+pr=""
+n=0
+while :; do
+  pr="$(python3 "$SD/scripts/gh_repo.py" pr-identity "$num" --root "$top")" || pr=""
+  n=$((n + 1))
+  case "$pr" in "MERGED $def $cur false "*) break ;; esac
+  [ "$n" -lt 4 ] || break
+  sleep 5
+done
+case "$pr" in
+  "MERGED $def $cur false "*)
+    echo "[spec-distill] 다시 확인하니 PR 이 머지돼 있다 — ${URL}"
+    git -C "$top" fetch -q origin || echo "[spec-distill] 머지 뒤 origin 을 받지 못했다(위 사유) — 지휘자를 부르기 전에 git fetch origin 을 돌린다. 받기 전에는 지휘자가 이 로드맵을 기본 브랜치에서 찾지 못한다."
+    echo "interview-merge: MERGED" ;;
+  "MERGED "*)
+    echo "[spec-distill] 머지 요청은 나갔지만 읽은 PR 이 이 레포의 ${cur} → ${def} PR 이 아니다(읽은 것: ${pr}) — PR 에서 직접 확인한 뒤 지휘자를 부른다: ${URL}"
+    echo "interview-merge: NONE" ;;
+  "")
+    echo "[spec-distill] 머지 요청은 나갔지만 PR 상태를 읽지 못했다(위 사유) — 머지됐는지 확인한 뒤 지휘자를 부른다: ${URL}"
+    echo "interview-merge: NONE" ;;
+  *)
+    st="${pr%% *}"
+    echo "[spec-distill] 머지 요청은 나갔지만 PR 이 아직 머지되지 않았다(읽은 상태: ${st}) — 머지 대기열이나 자동 머지를 쓰는 레포면 조건이 채워진 뒤 머지된다. 머지된 것을 확인한 뒤 지휘자를 부른다: ${URL}"
+    echo "interview-merge: NONE" ;;
+esac
+```
+<!-- interview-merge-recheck:end -->
 
 **다음 세션 줄 — 분해된 일 ①/② 공통**
 
diff -ru a/plugins/spec-distill/tests/test_finish_pr_merge.sh b/plugins/spec-distill/tests/test_finish_pr_merge.sh
--- a/plugins/spec-distill/tests/test_finish_pr_merge.sh	2026-11-15 13:28:15
+++ b/plugins/spec-distill/tests/test_finish_pr_merge.sh	2026-11-15 13:28:15
@@ -1,5 +1,6 @@
 #!/usr/bin/env bash
-# 분해된 인터뷰 끝맺음의 PR 펜스(interview-pr) · 머지 펜스(interview-merge) — finishing.md 에서 뽑아 그대로 돌린다.
+# 분해된 인터뷰 끝맺음의 PR 펜스(interview-pr) · 머지 펜스(interview-merge) · 다시 확인 펜스(interview-merge-recheck)
+# — finishing.md 에서 뽑아 그대로 돌린다.
 # 펜스는 Bash 도구의 셸에서 돌므로 bash 와 zsh 둘 다에서 잰다(zsh 가 없으면 그 사실을 알리고 bash 만).
 # 픽스처: 임시 레포(origin 은 git@github.com:<owner>/r.git — 가짜 ssh 가 로컬 bare 레포로 잇는다) + PATH 앞의
 # 가짜 gh · 가짜 sleep. 실제 gh · 네트워크로 나가지 않는다.
@@ -26,12 +27,31 @@
 HPH='<interview-pr 이 낸 끝 커밋>'
 pf="$(fence "$FIN" interview-pr)"
 mf="$(fence "$FIN" interview-merge)"
+rf="$(fence "$FIN" interview-merge-recheck)"
 case "$pf" in *"BRIEF=\"$PH\""*'gh_repo.py" pr-open '*'gh_repo.py" pr-create '*) ok "전제: PR 펜스에 BRIEF 자리표와 gh_repo.py 호출 둘" ;; *) no "전제: PR 펜스를 못 뽑았다 — 아래 칸이 공허하다" ;; esac
 # 권장 꼬리의 조건은 본문이 정한다 — ONLY 일 때만 달고 MIXED · UNKNOWN 이면 뗀다
 ASK="$(grep -F '2. **머지 묻기.**' "$FIN")"
 assert_contains "$ASK" '「(권장)」 꼬리는 1 의 펜스가 `interview-pr-files: ONLY` 를 냈을 때만 단다' "본문: 권장 꼬리는 ONLY 일 때만"
 assert_contains "$ASK" '`MIXED` 나 `UNKNOWN` 이면 꼬리를 떼어 「머지」 로 내고' "본문: MIXED · UNKNOWN 이면 꼬리를 뗀다"
 case "$mf" in *"URL=\"$UPH\""*"HEAD_SHA=\"$HPH\""*'gh_repo.py" pr-number '*'gh_repo.py" pr-merge '*) ok "전제: 머지 펜스에 URL · 끝 커밋 자리표와 gh_repo.py 호출" ;; *) no "전제: 머지 펜스를 못 뽑았다 — 아래 칸이 공허하다" ;; esac
+case "$rf" in *"BRIEF=\"$PH\""*"URL=\"$UPH\""*'gh_repo.py" pr-number '*'gh_repo.py" pr-identity '*) ok "전제: 다시 확인 펜스에 BRIEF · URL 자리표와 gh_repo.py 호출" ;; *) no "전제: 다시 확인 펜스를 못 뽑았다 — 아래 칸이 공허하다" ;; esac
+case "$rf" in *"$HPH"*|*'gh_repo.py" pr-merge '*|*'gh_repo.py" pr-checks '*|*'gh_repo.py" pr-create '*|*" push "*) no "다시 확인 펜스는 읽기만 한다 — 끝 커밋 자리표 · 머지 · 검사 · 만들기 · push 가운데 하나가 있다" ;; *) ok "다시 확인 펜스는 읽기만 한다(머지 · 검사 · 만들기 · push 를 부르지 않는다)" ;; esac
+# 플러그인 루트 가드 줄은 세 펜스가 글자 그대로 같다
+g1="$(printf '%s\n' "$pf" | head -n 1)"
+case "$g1" in 'SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || {'*'exit 1; }') ok "전제: PR 펜스 첫 줄이 플러그인 루트 가드다" ;; *) no "전제: PR 펜스 첫 줄이 가드가 아니다" ;; esac
+for g in "$mf" "$rf"; do
+  assert_eq "$(printf '%s\n' "$g" | head -n 1)" "$g1" "펜스 첫 줄의 플러그인 루트 가드가 PR 펜스와 글자 그대로 같다"
+done
+# 판결 줄 없는 출력을 읽는 법은 본문이 정한다 — 표시 줄이 있으면 다시 확인, 없으면 NONE
+HEADP="$(grep -F '**PR 과 머지 — 분해된 일 ①/② 만.**' "$FIN")"
+assert_contains "$HEADP" '판결 줄 없이 끝나면(시간 초과 · 끊김 포함) `NONE` 으로 읽는다 — 하나만 다르다: 머지 펜스의 출력에 판결 줄이 없고 `interview-merge-requested:` 표시 줄이 있으면 `NONE` 으로 읽지 않고 3 의 다시 확인 펜스를 돌려 그 판결대로 잇는다.' "본문(절 머리): 표시 줄이 있으면 NONE 으로 읽지 않고 다시 확인"
+assert_not_contains "$HEADP" '판결 줄 없이 끝나면(시간 초과 · 끊김 포함) `NONE` 으로 읽는다. ' "본문(절 머리): 옛 문장(예외 없는 NONE)이 남지 않았다"
+STEP3="$(grep -F '3. **머지.**' "$FIN")"
+assert_contains "$STEP3" '판결 줄이 없고 `interview-merge-requested:` 표시 줄이 있으면 머지 요청이 이미 나갔을 수 있다 — `NONE` 으로 읽지 않고 머지 펜스 아래의 다시 확인 펜스를 돌려 그 판결대로 잇는다. 표시 줄도 없으면 `interview-merge: NONE` 으로 읽어 잇는다.' "본문(3 걸음): 그만둔 출력에 표시 줄이 있으면 다시 확인, 없으면 NONE"
+assert_not_contains "$STEP3" '판결 줄이 이미 있으면 그 판결대로, 없으면 `interview-merge: NONE` 으로 읽어 잇는다' "본문(3 걸음): 옛 문장(표시 줄을 보지 않는 NONE)이 남지 않았다"
+RECP="$(grep -F '**다시 확인 — ' "$FIN")"
+assert_contains "$RECP" '**다시 확인 — 판결 줄 없이 끝난 머지 펜스의 출력에 `interview-merge-requested:` 표시 줄이 있을 때만.**' "본문(다시 확인): 도는 조건"
+assert_contains "$RECP" '(5초 간격 네 번까지)' "본문(다시 확인): 읽는 간격 · 횟수"
 
 mkdir -p "$T/bin" "$T/remotes" || exit 1
 cat > "$T/bin/gh" <<'FAKE'
@@ -48,8 +68,13 @@
     echo "Creating pull request for feature/x into main in $FAKE_OWNER/r" >&2
     echo "https://github.com/$FAKE_OWNER/r/pull/7" ;;
   "pr view")
-    printf '{"number":%s,"state":"%s","headRefName":"%s","headRefOid":"%s","isCrossRepository":false,"baseRefName":"main","mergeCommit":null}\n' \
-      "$3" "$(cat "$st")" "${FAKE_HEAD:-feature/x}" "$(git --git-dir="$FAKE_REMOTE" rev-parse refs/heads/feature/x)" ;;
+    [ -z "${FAKE_VIEW_AUTH:-}" ] || { echo 'To get started with GitHub CLI, please run:  gh auth login' >&2; exit 4; }   # PR 읽기의 인증 실패
+    s="$(cat "$st")"; h="${FAKE_HEAD:-feature/x}"
+    v=$(( $(cat "$FAKE_GH_DIR/views" 2>/dev/null || echo 0) + 1 )); echo "$v" > "$FAKE_GH_DIR/views"   # 이 실행의 몇 번째 읽기인가
+    [ -z "${FAKE_VIEW_MERGED_AT:-}" ] || [ "$v" -lt "$FAKE_VIEW_MERGED_AT" ] || s=MERGED   # n 번째 읽기부터 MERGED(요청 직후의 늦은 반영)
+    [ -z "${FAKE_HEAD_FROM2:-}" ] || [ "$v" -lt 2 ] || h="$FAKE_HEAD_FROM2"                # 둘째 읽기부터 다른 브랜치
+    printf '{"number":%s,"state":"%s","headRefName":"%s","headRefOid":"%s","isCrossRepository":%s,"baseRefName":"%s","mergeCommit":null}\n' \
+      "$3" "$s" "$h" "$(git --git-dir="$FAKE_REMOTE" rev-parse refs/heads/feature/x)" "${FAKE_CROSS:-false}" "${FAKE_BASE:-main}" ;;
   "pr checks")
     case "${FAKE_CHECKS:-none}" in
       none) echo "no checks reported on the 'feature/x' branch" >&2; exit 1 ;;
@@ -72,11 +97,16 @@
     [ "$5" = "--match-head-commit" ] && [ "$6" = "$(git --git-dir="$FAKE_REMOTE" rev-parse refs/heads/feature/x)" ] \
       || { echo 'GraphQL: Head branch was modified. Review and try the merge again. (mergePullRequest)' >&2; exit 1; }
     git --git-dir="$FAKE_REMOTE" update-ref refs/heads/main refs/heads/feature/x || exit 1
-    printf 'MERGED\n' > "$st" ;;
+    printf 'MERGED\n' > "$st"
+    case "${FAKE_MERGE:-ok}" in
+      failmerged) echo 'failed to run git: fatal: unable to access the remote' >&2; exit 1 ;;   # 머지는 됐는데 gh 는 실패로 끝난다
+      cut) kill "$(cat "$FAKE_GH_DIR/fence.pid")"; exec /bin/sleep 0.3 ;;                       # 머지는 됐는데 펜스가 판결 전에 끊긴다
+    esac ;;
 esac
 FAKE
 cat > "$T/bin/sleep" <<'FAKE'
 #!/bin/sh
+[ -z "${FAKE_SLEEP_LOG:-}" ] || printf '%s\n' "$*" >> "$FAKE_SLEEP_LOG"
 exec /bin/sleep "${FAKE_SLEEP:-0.05}"
 FAKE
 cat > "$T/bin/fakessh" <<'FAKE'
@@ -118,11 +148,19 @@
   local c="$T/$1" body="${2//"$PH"/$T/$1/${BRIEF_REL:-$STEM.md}}"
   body="${body//"$UPH"/${3:-$UPH}}"
   body="${body//"$HPH"/${4:-$HPH}}"
-  : > "$T/gh-$1/log"
+  : > "$T/gh-$1/log"; : > "$T/gh-$1/sleeps"; rm -f "$T/gh-$1/views"
   ( cd "$c" && CLAUDE_PLUGIN_ROOT="$SD" PATH="$T/bin:$PATH" FAKE_GH_LOG="$T/gh-$1/log" FAKE_GH_DIR="$T/gh-$1" \
-      FAKE_OWNER="$1" FAKE_REMOTE="$T/remotes/$1/r.git" "${SHELL_ARGV[@]}" "$body" 2>&1 )
+      FAKE_SLEEP_LOG="$T/gh-$1/sleeps" FAKE_OWNER="$1" FAKE_REMOTE="$T/remotes/$1/r.git" "${SHELL_ARGV[@]}" "$body" 2>&1 )
 }
 ghlog() { cat "$T/gh-$1/log"; }
+sleeps() { tr '\n' ' ' < "$T/gh-$1/sleeps"; }   # 그 실행이 부른 sleep 의 인자들(간격)
+remote_merge() {   # remote_merge <owner> [nostate] → 원격의 main 을 feature/x 로(머지됨). nostate 가 아니면 가짜 gh 의 상태도 MERGED 로
+  git --git-dir="$T/remotes/$1/r.git" update-ref refs/heads/main refs/heads/feature/x || return 1
+  [ "${2:-}" = nostate ] || printf 'MERGED\n' > "$T/gh-$1/state"
+}
+omain() { git -C "$T/$1" rev-parse refs/remotes/origin/main; }   # 로컬이 아는 origin 기본 브랜치
+MARK='interview-merge-requested: 7'
+CUT='echo $$ > "$FAKE_GH_DIR/fence.pid"'   # 테스트만의 한 줄 — 가짜 gh 가 이 pid 를 죽여 「요청 뒤 끊김」을 만든다
 head_of() { printf '%s\n' "$1" | sed -n 's/^interview-pr-head: //p'; }   # PR 펜스 출력에서 끝 커밋
 remote_ref() { git --git-dir="$T/remotes/$1/r.git" rev-parse -q --verify "refs/heads/$2" 2>/dev/null || true; }
 
@@ -218,6 +256,7 @@
   o="$(run "$n" "$mf" "$URL" "$H")"
   assert_eq "$(last "$o")" "interview-merge: MERGED" "머지: 마지막 줄이 판결(MERGED)"
   assert_contains "$o" "[spec-distill] PR 을 머지했다(merge) — $URL" "머지: 방식과 주소를 보인다"
+  assert_eq "$(printf '%s\n' "$o" | grep -e "^interview-merge-requested: " -e 'PR 을 머지했다' | tr '\n' '|')" "${MARK}|[spec-distill] PR 을 머지했다(merge) — ${URL}|" "머지: 요청 표시 줄(PR 번호) 하나가 머지한 줄보다 먼저 나온다"
   L="$(ghlog "$n")"
   assert_eq "$(printf '%s\n' "$L" | grep -c "^pr checks 7 -R github.com/$n/r\$")" "6" "머지: 「검사 없음」을 여섯 번 본다"
   assert_not_contains "$L" "--watch" "머지: 검사가 없으면 기다리지 않는다"
@@ -252,6 +291,9 @@
   assert_not_contains "$o" "PR 을 머지했다" "대기열: 머지했다고 말하지 않는다"
   assert_eq "$(ghlog "$n" | grep -c "^pr merge ")" "1" "대기열: 다음 머지 방식을 시도하지 않는다"
   assert_eq "$(ghlog "$n" | grep -c "^pr view 7 ")" "5" "대기열: 상태를 네 번까지 다시 읽는다(신원 확인 한 번 더)"
+  Q_SLEEPS="$(sleeps "$n" | sed 's/^\(10 \)*//')"   # 앞의 10초들은 「검사 없음」 다시 보기다 — 그 뒤가 머지 뒤 상태 읽기의 간격
+  assert_eq "$Q_SLEEPS" "5 5 5 " "대기열: 머지 뒤 상태 읽기 사이를 5초씩 세 번 쉰다"
+  assert_eq "$(printf '%s\n' "$o" | grep -c "^${MARK}\$")" "1" "대기열: 요청 표시 줄은 하나다"
   assert_eq "$(git -C "$c" rev-parse refs/remotes/origin/main)" "$before" "대기열: 머지 전이라 origin 을 받지 않는다"
 
   # 8. 머지 뒤 origin 을 받지 못함 — 알리고 판결은 MERGED
@@ -272,8 +314,10 @@
   assert_eq "$(last "$o")" "interview-merge: NONE" "검사 실패: 판결 NONE"
   assert_contains "$o" "CI 검사가 통과하지 않았다(rc 1, 위 목록)" "검사 실패: 사유"
   assert_not_contains "$(ghlog "$n")" "pr merge" "검사 실패: 머지하지 않는다"
+  assert_not_contains "$o" "interview-merge-requested" "검사 실패: 요청을 보내지 않았으니 표시 줄도 없다"
   o="$(FAKE_CHECKS=hang FAKE_SLEEP=0.01 run "$n" "$mf" "$URL" "$H")"
   assert_contains "$o" "CI 검사를 30분 기다려도 끝나지 않았다" "검사가 끝나지 않음: 기다림 상한에서 멈춘다"
+  assert_not_contains "$o" "interview-merge-requested" "검사가 끝나지 않음: 기다리는 동안에는 표시 줄이 없다"
   wp="$(cat "$T/gh-$n/watch.pid" 2>/dev/null)" || wp=""
   [ -n "$wp" ] && ! kill -0 "$wp" 2>/dev/null && ok "검사가 끝나지 않음: 기다리던 gh 를 끝냈다" || nob "검사가 끝나지 않음: 기다리던 gh 가 남았다" "pid ${wp:-없음}"
   o="$(FAKE_WAYS='{"mergeCommitAllowed":false,"squashMergeAllowed":true,"rebaseMergeAllowed":true}' FAKE_CHECKS=pass run "$n" "$mf" "$URL" "$H")"
@@ -287,6 +331,7 @@
   o="$(FAKE_MERGE=second run "$n" "$mf" "$URL" "$H")"
   assert_contains "$o" "merge 머지가 거절됐다(위 사유) — 다음 방식을 시도한다." "방식 거절: 알리고 다음 방식으로"
   assert_contains "$o" "PR 을 머지했다(squash)" "방식 거절: 다음 방식으로 머지한다"
+  assert_eq "$(printf '%s\n' "$o" | grep -e "^interview-merge-requested: " -e '머지가 거절됐다' -e 'PR 을 머지했다' | sed 's/^\[spec-distill\] //;s/ — .*//;s/(위 사유)//' | tr '\n' '|')" "${MARK}|merge 머지가 거절됐다|${MARK}|PR 을 머지했다(squash)|" "방식 거절: 요청 표시 줄은 방식마다 요청 바로 앞에 낸다"
   o="$(run "$n" "$mf")"
   assert_contains "$o" "머지하지 않았다 — PR 주소가 비었거나 자리표 그대로다" "자리표 그대로: 머지하지 않는다"
   for bad in "" "${H}Z" "not-a-commit"; do
@@ -319,5 +364,165 @@
   assert_contains "$o" "물을 때의 끝 커밋: ${H}" "끝 커밋이 바뀜(기다리는 사이): 물을 때의 커밋을 보인다"
   assert_not_contains "$o" "PR 을 머지했다" "끝 커밋이 바뀜(기다리는 사이): 머지했다고 말하지 않는다"
   assert_eq "$(remote_ref "$n" main)" "$mainref" "끝 커밋이 바뀜(기다리는 사이): 기본 브랜치는 그대로다"
+
+  note "=== ${sh_name}: 이미 머지됨 · 실패 뒤 머지됨 ==="
+  # 11. 물을 때 이미 머지됨 — 「머지하지 않았다」 가 아니라 머지됨으로 읽고 origin 을 받는다. 검사를 기다리지도 머지를 요청하지도 않는다
+  n="${P}already"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
+  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
+  before="$(omain "$n")"; remote_merge "$n"
+  for kv in "FAKE_HEAD=other-branch" "FAKE_BASE=develop" "FAKE_CROSS=true"; do   # 양의 대조 — 같은 머지 상태인데 브랜치 · 바탕 · 레포가 다르면 머지됨으로 읽지 않는다
+    o="$(export "$kv"; run "$n" "$mf" "$URL" "$H")"
+    assert_eq "$(last "$o")" "interview-merge: NONE" "이미 머지됨(대조 ${kv}): 판결 NONE"
+    assert_contains "$o" "머지하지 않았다 — 이 PR 은 열린, 이 레포의 feature/x → main PR 이 아니거나" "이미 머지됨(대조 ${kv}): 신원 불일치로 멈춘다"
+    assert_contains "$o" "(읽은 것: MERGED " "이미 머지됨(대조 ${kv}): 읽은 상태는 머지됨이다(대조가 같은 상태에서 갈린다)"
+    assert_not_contains "$o" "이미 머지돼 있다" "이미 머지됨(대조 ${kv}): 머지돼 있다고 말하지 않는다"
+    assert_eq "$(omain "$n")" "$before" "이미 머지됨(대조 ${kv}): origin 을 받지 않는다"
+  done
+  o="$(run "$n" "$mf" "$URL" "$H")"
+  assert_eq "$(last "$o")" "interview-merge: MERGED" "이미 머지됨: 마지막 줄이 판결(MERGED)"
+  assert_contains "$o" "[spec-distill] PR 이 이미 머지돼 있다 — $URL" "이미 머지됨: 그 사실과 주소를 보인다"
+  assert_not_contains "$o" "머지하지 않았다" "이미 머지됨: 「머지하지 않았다」 고 말하지 않는다"
+  assert_not_contains "$o" "PR 을 머지했다" "이미 머지됨: 이 펜스가 머지했다고 말하지 않는다"
+  assert_not_contains "$o" "interview-merge-requested" "이미 머지됨: 요청을 보내지 않았으니 표시 줄도 없다"
+  L="$(ghlog "$n")"
+  assert_not_contains "$L" "pr merge" "이미 머지됨: 머지를 요청하지 않는다"
+  assert_not_contains "$L" "pr checks" "이미 머지됨: CI 검사를 기다리지 않는다"
+  assert_eq "$(printf '%s\n' "$L" | grep -c "^pr view 7 ")" "1" "이미 머지됨: PR 을 한 번 읽는다"
+  assert_eq "$(sleeps "$n")" "" "이미 머지됨: 기다리지 않는다(sleep 없음)"
+  after="$(omain "$n")"
+  [ "$before" != "$after" ] && [ "$after" = "$H" ] && ok "이미 머지됨: 로컬의 origin 기본 브랜치 ref 가 머지된 끝으로 왔다(fetch)" || nob "이미 머지됨: origin 을 받지 않았다" "$before → $after"
+  # 11b. 끝 커밋은 대조하지 않는다 — 물은 뒤 커밋이 더 올라온 채 머지됐어도 머지됨이다
+  o="$(run "$n" "$mf" "$URL" "0000000000000000000000000000000000000000")"
+  assert_eq "$(last "$o")" "interview-merge: MERGED" "이미 머지됨(끝 커밋이 물을 때와 다름): 그래도 MERGED"
+  # 11c. 이미 머지됐는데 origin 을 받지 못함 — 알리고 판결은 MERGED
+  o="$(FAKE_SSH_FAIL=1 run "$n" "$mf" "$URL" "$H")"
+  assert_eq "$(last "$o")" "interview-merge: MERGED" "이미 머지됨(fetch 실패): 판결은 MERGED 그대로"
+  assert_contains "$o" "머지 뒤 origin 을 받지 못했다(위 사유) — 지휘자를 부르기 전에 git fetch origin 을 돌린다." "이미 머지됨(fetch 실패): 알린다"
+
+  # 12. gh 의 머지 명령이 실패로 끝났는데 다시 읽으니 머지됨 — 머지됨으로 읽고 다음 방식을 시도하지 않는다
+  n="${P}failmerged"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
+  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
+  before="$(omain "$n")"
+  o="$(FAKE_MERGE=failmerged run "$n" "$mf" "$URL" "$H")"
+  assert_eq "$(last "$o")" "interview-merge: MERGED" "실패 뒤 머지됨: 마지막 줄이 판결(MERGED)"
+  assert_contains "$o" "[spec-distill] gh 의 머지 명령은 실패로 끝났지만(위 사유) PR 은 머지돼 있다 — $URL" "실패 뒤 머지됨: 그 사실과 주소를 보인다"
+  assert_contains "$o" "failed to run git: fatal: unable to access the remote" "실패 뒤 머지됨: gh 의 사유가 위에 보인다"
+  assert_not_contains "$o" "머지하지 않았다" "실패 뒤 머지됨: 「머지하지 않았다」 고 말하지 않는다"
+  assert_not_contains "$o" "다음 방식을 시도한다" "실패 뒤 머지됨: 다음 방식으로 간다고 말하지 않는다"
+  assert_not_contains "$o" "PR 을 머지했다(" "실패 뒤 머지됨: 정상 경로의 머지한 줄은 내지 않는다"
+  assert_eq "$(ghlog "$n" | grep -c "^pr merge ")" "1" "실패 뒤 머지됨: 머지 요청은 한 번이다(다음 방식을 시도하지 않는다)"
+  assert_eq "$(ghlog "$n" | grep -c "^pr view 7 ")" "2" "실패 뒤 머지됨: 신원 확인 한 번 · 실패 뒤 다시 읽기 한 번"
+  after="$(omain "$n")"
+  [ "$before" != "$after" ] && [ "$after" = "$H" ] && ok "실패 뒤 머지됨: 로컬의 origin 기본 브랜치 ref 가 머지된 끝으로 왔다(fetch)" || nob "실패 뒤 머지됨: origin 을 받지 않았다" "$before → $after"
+  # 12b. 양의 대조 — 실패 뒤 다시 읽은 것이 머지됨이어도 브랜치가 다르면 머지됨으로 읽지 않는다(둘째 읽기부터 다른 브랜치)
+  n="${P}failother"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
+  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
+  before="$(omain "$n")"
+  o="$(FAKE_MERGE=failmerged FAKE_HEAD_FROM2=other-branch run "$n" "$mf" "$URL" "$H")"
+  assert_eq "$(last "$o")" "interview-merge: NONE" "실패 뒤 머지됨(대조 — 다른 브랜치): 판결 NONE"
+  assert_contains "$o" "머지가 거절됐고(위 사유) PR 이 물을 때와 달라졌다 — 끝 커밋이 바뀌었거나 닫혔다(읽은 것: MERGED main other-branch false ${H}" "실패 뒤 머지됨(대조 — 다른 브랜치): 읽은 것을 보이고 멈춘다"
+  assert_eq "$(ghlog "$n" | grep -c "^pr merge ")" "1" "실패 뒤 머지됨(대조 — 다른 브랜치): 다음 방식을 시도하지 않는다"
+  assert_eq "$(omain "$n")" "$before" "실패 뒤 머지됨(대조 — 다른 브랜치): origin 을 받지 않는다"
+
+  note "=== ${sh_name}: 다시 확인 펜스 ==="
+  # 13. 요청 표시 뒤 끊김 — 머지 펜스는 판결 줄 없이 끝나고, 다시 확인 펜스가 머지됨으로 읽는다
+  n="${P}cut"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
+  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
+  before="$(omain "$n")"
+  o="$(FAKE_MERGE=cut run "$n" "$CUT
+$mf" "$URL" "$H" 2>/dev/null)"
+  assert_eq "$(printf '%s\n' "$o" | grep -c "^${MARK}\$")" "1" "끊김: 출력에 요청 표시 줄이 있다"
+  assert_not_grep "$o" "^interview-merge: " "끊김: 판결 줄이 없다"
+  assert_eq "$(last "$o")" "$MARK" "끊김: 마지막 줄이 표시 줄이다(요청 바로 앞에 낸다)"
+  assert_eq "$(ghlog "$n" | grep -c "^pr merge ")" "1" "끊김: 머지 요청은 나갔다"
+  assert_eq "$(remote_ref "$n" main)" "$H" "끊김: 원격은 머지됐다"
+  assert_eq "$(omain "$n")" "$before" "끊김: 머지 펜스는 origin 을 받지 못하고 끝났다"
+  o="$(run "$n" "$rf" "$URL")"
+  assert_eq "$(last "$o")" "interview-merge: MERGED" "다시 확인(머지됨): 마지막 줄이 판결(MERGED)"
+  assert_contains "$o" "[spec-distill] 다시 확인하니 PR 이 머지돼 있다 — $URL" "다시 확인(머지됨): 그 사실과 주소를 보인다"
+  assert_not_contains "$o" "머지 요청은 나갔지만" "다시 확인(머지됨): 머지되지 않았다고 말하지 않는다"
+  L="$(ghlog "$n")"
+  assert_not_contains "$L" "pr merge" "다시 확인(머지됨): 머지를 요청하지 않는다"
+  assert_not_contains "$L" "pr checks" "다시 확인(머지됨): 검사를 부르지 않는다"
+  assert_eq "$L" "pr view 7 --json number,state,headRefName,headRefOid,isCrossRepository,baseRefName,mergeCommit -R github.com/$n/r" "다시 확인(머지됨): gh 호출은 PR 읽기 한 번뿐이다(-R origin)"
+  assert_eq "$(sleeps "$n")" "" "다시 확인(머지됨): 첫 읽기에 머지됨이면 기다리지 않는다"
+  after="$(omain "$n")"
+  [ "$before" != "$after" ] && [ "$after" = "$H" ] && ok "다시 확인(머지됨): 로컬의 origin 기본 브랜치 ref 가 머지된 끝으로 왔다(fetch)" || nob "다시 확인(머지됨): origin 을 받지 않았다" "$before → $after"
+  o="$(FAKE_SSH_FAIL=1 run "$n" "$rf" "$URL")"
+  assert_eq "$(last "$o")" "interview-merge: MERGED" "다시 확인(fetch 실패): 판결은 MERGED 그대로"
+  assert_contains "$o" "머지 뒤 origin 을 받지 못했다(위 사유) — 지휘자를 부르기 전에 git fetch origin 을 돌린다." "다시 확인(fetch 실패): 알린다"
+
+  # 13b. 요청 직후에는 아직 열림 → 뒤 읽기에서 머지됨. 한 번 읽고 끝내지 않는다
+  n="${P}late"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
+  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
+  before="$(omain "$n")"; remote_merge "$n" nostate
+  for at in 2 4; do
+    git -C "$c" update-ref refs/remotes/origin/main "$before"
+    o="$(FAKE_VIEW_MERGED_AT=$at run "$n" "$rf" "$URL")"
+    assert_eq "$(last "$o")" "interview-merge: MERGED" "다시 확인(${at}번째 읽기에 머지됨): 판결 MERGED"
+    assert_eq "$(ghlog "$n" | grep -c "^pr view 7 ")" "$at" "다시 확인(${at}번째 읽기에 머지됨): PR 을 ${at}번 읽는다"
+    assert_eq "$(omain "$n")" "$H" "다시 확인(${at}번째 읽기에 머지됨): origin 을 받았다"
+  done
+  assert_eq "$(sleeps "$n")" "5 5 5 " "다시 확인(4번째 읽기에 머지됨): 읽기 사이를 5초씩 세 번 쉰다"
+  # 양의 대조 — 다섯째 읽기에야 머지됨이면 네 번에서 멈춰 NONE 이다(정해진 횟수만 읽는다)
+  git -C "$c" update-ref refs/remotes/origin/main "$before"
+  o="$(FAKE_VIEW_MERGED_AT=5 run "$n" "$rf" "$URL")"
+  assert_eq "$(last "$o")" "interview-merge: NONE" "다시 확인(다섯째 읽기에야 머지됨): 네 번에서 멈춰 NONE"
+  assert_eq "$(ghlog "$n" | grep -c "^pr view 7 ")" "4" "다시 확인(다섯째 읽기에야 머지됨): PR 을 네 번 읽는다"
+  assert_eq "$(omain "$n")" "$before" "다시 확인(다섯째 읽기에야 머지됨): origin 을 받지 않는다"
+
+  # 13c. 끝까지 열림 — NONE. 요청이 나갔다는 사실과 PR 주소를 함께 알린다
+  n="${P}stillopen"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
+  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
+  before="$(omain "$n")"
+  o="$(run "$n" "$rf" "$URL")"
+  assert_eq "$(last "$o")" "interview-merge: NONE" "다시 확인(끝까지 열림): 마지막 줄이 판결(NONE)"
+  assert_contains "$o" "[spec-distill] 머지 요청은 나갔지만 PR 이 아직 머지되지 않았다(읽은 상태: OPEN) — 머지 대기열이나 자동 머지를 쓰는 레포면 조건이 채워진 뒤 머지된다. 머지된 것을 확인한 뒤 지휘자를 부른다: $URL" "다시 확인(끝까지 열림): 요청이 나간 사실 · 읽은 상태 · PR 주소가 한 줄에"
+  assert_not_contains "$o" "머지돼 있다" "다시 확인(끝까지 열림): 머지돼 있다고 말하지 않는다"
+  L="$(ghlog "$n")"
+  assert_eq "$(printf '%s\n' "$L" | grep -c "^pr view 7 ")" "4" "다시 확인(끝까지 열림): PR 을 네 번 읽는다"
+  assert_eq "$(printf '%s\n' "$L" | grep -vc "^pr view 7 ")" "0" "다시 확인(끝까지 열림): PR 읽기 말고는 gh 를 부르지 않는다"
+  assert_eq "$(sleeps "$n")" "$Q_SLEEPS" "다시 확인(끝까지 열림): 머지 펜스의 머지 뒤 상태 읽기와 같은 간격 · 횟수로 쉰다(${Q_SLEEPS})"
+  assert_eq "$(omain "$n")" "$before" "다시 확인(끝까지 열림): origin 을 받지 않는다"
+  # 13d. 자리표 그대로 · 다른 레포 주소 — gh 를 부르지 않고 NONE
+  o="$(run "$n" "$rf")"
+  assert_eq "$(last "$o")" "interview-merge: NONE" "다시 확인(주소 자리표 그대로): 판결 NONE"
+  assert_contains "$o" "머지됐는지 다시 확인하지 못했다 — PR 주소가 비었거나 자리표 그대로다. 머지 요청은 나갔을 수 있다" "다시 확인(주소 자리표 그대로): 사람 줄"
+  assert_eq "$(ghlog "$n")" "" "다시 확인(주소 자리표 그대로): gh 를 부르지 않는다"
+  : > "$T/gh-$n/log"
+  o="$( cd "$c" && CLAUDE_PLUGIN_ROOT="$SD" PATH="$T/bin:$PATH" FAKE_GH_LOG="$T/gh-$n/log" "${SHELL_ARGV[@]}" "$rf" 2>&1 )"
+  assert_eq "$(last "$o")" "interview-merge: NONE" "다시 확인(BRIEF 자리표 그대로): 판결 NONE"
+  assert_contains "$o" "머지됐는지 다시 확인하지 못했다 — BRIEF 가 비었거나 자리표 그대로다" "다시 확인(BRIEF 자리표 그대로): 사람 줄"
+  assert_eq "$(ghlog "$n")" "" "다시 확인(BRIEF 자리표 그대로): gh 를 부르지 않는다"
+  o="$(run "$n" "$rf" "https://github.com/someone-else/r/pull/7")"
+  assert_eq "$(last "$o")" "interview-merge: NONE" "다시 확인(다른 레포 주소): 판결 NONE"
+  assert_contains "$o" "PR 주소의 레포(github.com/someone-else/r)가 origin(github.com/$n/r)이 아니다" "다시 확인(다른 레포 주소): gh_repo.py 의 사유"
+  assert_contains "$o" "머지됐는지 다시 확인하지 못했다 — PR 주소가 이 레포(origin)의 PR 이 아니다(위 사유). 머지 요청은 나갔을 수 있다 — PR 에서 머지된 것을 확인한 뒤 지휘자를 부른다: https://github.com/someone-else/r/pull/7" "다시 확인(다른 레포 주소): 사람 줄에 그 주소"
+  assert_eq "$(ghlog "$n")" "" "다시 확인(다른 레포 주소): gh 를 한 번도 부르지 않는다"
+  # 13e. PR 을 읽지 못함(gh 인증 실패) — 원격이 머지돼 있어도 머지됨으로 읽지 않는다. 「끝까지 열림」 과 다른 줄로 알린다
+  remote_merge "$n"
+  o="$(FAKE_VIEW_AUTH=1 run "$n" "$rf" "$URL")"
+  assert_eq "$(last "$o")" "interview-merge: NONE" "다시 확인(읽지 못함): 마지막 줄이 판결(NONE)"
+  assert_contains "$o" "[spec-distill] 머지 요청은 나갔지만 PR 상태를 읽지 못했다(위 사유) — 머지됐는지 확인한 뒤 지휘자를 부른다: $URL" "다시 확인(읽지 못함): 요청이 나간 사실 · 읽지 못한 사실 · PR 주소가 한 줄에"
+  assert_contains "$o" "gh 인증이 안 됐다 — gh auth login --hostname github.com 를 돈다" "다시 확인(읽지 못함): gh_repo.py 의 사유가 위에 보인다"
+  assert_not_contains "$o" "아직 머지되지 않았다" "다시 확인(읽지 못함): 「끝까지 열림」 의 줄을 내지 않는다(열림으로 읽은 것이 아니다)"
+  assert_not_contains "$o" "머지돼 있다" "다시 확인(읽지 못함): 머지돼 있다고 말하지 않는다"
+  L="$(ghlog "$n")"
+  assert_eq "$(printf '%s\n' "$L" | grep -c "^pr view 7 ")" "4" "다시 확인(읽지 못함): 정해진 횟수(네 번)만큼 읽는다"
+  assert_not_contains "$L" "pr merge" "다시 확인(읽지 못함): 머지를 요청하지 않는다"
+  assert_eq "$(omain "$n")" "$before" "다시 확인(읽지 못함): origin 을 받지 않는다"
+  o="$(run "$n" "$rf" "$URL")"   # 양의 짝 — 같은 픽스처에서 읽을 수 있으면 MERGED 다(위의 NONE 은 읽지 못해서다)
+  assert_eq "$(last "$o")" "interview-merge: MERGED" "다시 확인(읽지 못함의 짝): 읽을 수 있으면 MERGED"
+  git -C "$c" update-ref refs/remotes/origin/main "$before"
+  # 13f. 머지됨인데 브랜치 · 바탕 · 레포가 다르면 머지됨으로 읽지 않는다
+  for kv in "FAKE_HEAD=other-branch" "FAKE_BASE=develop" "FAKE_CROSS=true"; do
+    o="$(export "$kv"; run "$n" "$rf" "$URL")"
+    assert_eq "$(last "$o")" "interview-merge: NONE" "다시 확인(대조 ${kv}): 판결 NONE"
+    assert_contains "$o" "[spec-distill] 머지 요청은 나갔지만 읽은 PR 이 이 레포의 feature/x → main PR 이 아니다(읽은 것: MERGED " "다시 확인(대조 ${kv}): 읽은 것을 보인다"
+    assert_contains "$o" "PR 에서 직접 확인한 뒤 지휘자를 부른다: $URL" "다시 확인(대조 ${kv}): PR 주소를 싣는다"
+    assert_eq "$(omain "$n")" "$before" "다시 확인(대조 ${kv}): origin 을 받지 않는다"
+  done
+  o="$(run "$n" "$rf" "$URL")"
+  assert_eq "$(last "$o")" "interview-merge: MERGED" "다시 확인(대조의 짝): 같은 픽스처에서 브랜치 · 바탕 · 레포가 같으면 MERGED"
 done
 finish
~~~~

### 패치 B2 (과제 9) — PR 펜스의 「값의 출처」 줄

- 대상: 같은 두 파일
- 기준: 과제 8 까지 건 트리(패치 B1 의 줄에 기댄다)

~~~~diff
diff -ru b/plugins/spec-distill/skills/pm-interview/references/finishing.md c/plugins/spec-distill/skills/pm-interview/references/finishing.md
--- b/plugins/spec-distill/skills/pm-interview/references/finishing.md	2026-11-15 13:28:15
+++ c/plugins/spec-distill/skills/pm-interview/references/finishing.md	2026-11-15 13:28:15
@@ -757,8 +757,18 @@
   echo "[spec-distill] 이 브랜치의 열린 PR 을 쓴다 — $url"
 fi
 # 이 PR 이 바꾸는 파일 가운데 인터뷰 폴더 바로 아래도 brief §7 의 로드맵 폴더도 아닌 것. 두 폴더는 커밋 펜스와 같은 판정을 통과한 것만 뺀다.
+# 끝내기 커밋 펜스가 같은 키로 이미 보인 「값의 출처」 줄만 뺀다 — 그 호출의 사유 · 알림 · 경고 줄과 종료 코드는 그대로다.
+nosrc() {
+  nf="$(mktemp)" || nf=""
+  [ -n "$nf" ] || { "$@"; return; }
+  n_rc=0
+  "$@" 2> "$nf" || n_rc=$?
+  grep -v '^\[spec-distill\] 값의 출처: ' "$nf" >&2
+  rm -f "$nf"
+  return "$n_rc"
+}
 idir=""
-if python3 "$SD/scripts/repo_defaults.py" check-path interview_dir "$BRIEF" --root "$top"; then
+if nosrc python3 "$SD/scripts/repo_defaults.py" check-path interview_dir "$BRIEF" --root "$top"; then
   idir="$(dirname -- "$BRIEF")"
 else
   echo "[spec-distill] brief 가 정해진 인터뷰 폴더 바로 아래가 아니다(위 사유) — 그 폴더의 파일도 밖의 파일로 센다."
@@ -769,7 +779,7 @@
   case "$r7" in "$cwd_l"/*) r7="$(pwd -P)/${r7#"$cwd_l"/}" ;; esac
   case "$r7" in /*) ;; *) r7="${top}/${r7}" ;; esac
   rdir="$(dirname -- "$r7")"
-  python3 "$SD/scripts/repo_defaults.py" check-path roadmaps_dir "$rdir" --root "$top" || { echo "[spec-distill] brief §7 의 로드맵 폴더가 정해진 로드맵 폴더 바로 아래가 아니다(위 사유) — 그 폴더의 파일도 밖의 파일로 센다: ${rdir}"; rdir=""; }
+  nosrc python3 "$SD/scripts/repo_defaults.py" check-path roadmaps_dir "$rdir" --root "$top" || { echo "[spec-distill] brief §7 의 로드맵 폴더가 정해진 로드맵 폴더 바로 아래가 아니다(위 사유) — 그 폴더의 파일도 밖의 파일로 센다: ${rdir}"; rdir=""; }
 fi
 x_rc=0
 extra="$(git -C "$top" -c core.quotePath=false diff --name-only "refs/remotes/origin/${def}...${head_sha}" -- . ${idir:+":(exclude,glob)${idir}/*"} ${rdir:+":(exclude)${rdir}"})" || x_rc=$?
diff -ru b/plugins/spec-distill/tests/test_finish_pr_merge.sh c/plugins/spec-distill/tests/test_finish_pr_merge.sh
--- b/plugins/spec-distill/tests/test_finish_pr_merge.sh	2026-11-15 13:28:15
+++ c/plugins/spec-distill/tests/test_finish_pr_merge.sh	2026-11-15 13:28:15
@@ -1,6 +1,6 @@
 #!/usr/bin/env bash
 # 분해된 인터뷰 끝맺음의 PR 펜스(interview-pr) · 머지 펜스(interview-merge) · 다시 확인 펜스(interview-merge-recheck)
-# — finishing.md 에서 뽑아 그대로 돌린다.
+# — finishing.md 에서 뽑아 그대로 돌린다. 「값의 출처」 줄의 짝으로 끝내기 커밋 펜스(interview-commit)도 뽑아 돌린다.
 # 펜스는 Bash 도구의 셸에서 돌므로 bash 와 zsh 둘 다에서 잰다(zsh 가 없으면 그 사실을 알리고 bash 만).
 # 픽스처: 임시 레포(origin 은 git@github.com:<owner>/r.git — 가짜 ssh 가 로컬 bare 레포로 잇는다) + PATH 앞의
 # 가짜 gh · 가짜 sleep. 실제 gh · 네트워크로 나가지 않는다.
@@ -28,6 +28,7 @@
 pf="$(fence "$FIN" interview-pr)"
 mf="$(fence "$FIN" interview-merge)"
 rf="$(fence "$FIN" interview-merge-recheck)"
+cf="$(fence "$FIN" interview-commit)"
 case "$pf" in *"BRIEF=\"$PH\""*'gh_repo.py" pr-open '*'gh_repo.py" pr-create '*) ok "전제: PR 펜스에 BRIEF 자리표와 gh_repo.py 호출 둘" ;; *) no "전제: PR 펜스를 못 뽑았다 — 아래 칸이 공허하다" ;; esac
 # 권장 꼬리의 조건은 본문이 정한다 — ONLY 일 때만 달고 MIXED · UNKNOWN 이면 뗀다
 ASK="$(grep -F '2. **머지 묻기.**' "$FIN")"
@@ -36,10 +37,11 @@
 case "$mf" in *"URL=\"$UPH\""*"HEAD_SHA=\"$HPH\""*'gh_repo.py" pr-number '*'gh_repo.py" pr-merge '*) ok "전제: 머지 펜스에 URL · 끝 커밋 자리표와 gh_repo.py 호출" ;; *) no "전제: 머지 펜스를 못 뽑았다 — 아래 칸이 공허하다" ;; esac
 case "$rf" in *"BRIEF=\"$PH\""*"URL=\"$UPH\""*'gh_repo.py" pr-number '*'gh_repo.py" pr-identity '*) ok "전제: 다시 확인 펜스에 BRIEF · URL 자리표와 gh_repo.py 호출" ;; *) no "전제: 다시 확인 펜스를 못 뽑았다 — 아래 칸이 공허하다" ;; esac
 case "$rf" in *"$HPH"*|*'gh_repo.py" pr-merge '*|*'gh_repo.py" pr-checks '*|*'gh_repo.py" pr-create '*|*" push "*) no "다시 확인 펜스는 읽기만 한다 — 끝 커밋 자리표 · 머지 · 검사 · 만들기 · push 가운데 하나가 있다" ;; *) ok "다시 확인 펜스는 읽기만 한다(머지 · 검사 · 만들기 · push 를 부르지 않는다)" ;; esac
-# 플러그인 루트 가드 줄은 세 펜스가 글자 그대로 같다
+case "$cf" in *"BRIEF=\"$PH\""*'repo_defaults.py" check-path interview_dir '*'repo_defaults.py" check-path roadmaps_dir '*) ok "전제: 커밋 펜스에 BRIEF 자리표와 check-path 둘" ;; *) no "전제: 커밋 펜스를 못 뽑았다 — 「값의 출처」 짝이 공허하다" ;; esac
+# 플러그인 루트 가드 줄은 네 펜스가 글자 그대로 같다
 g1="$(printf '%s\n' "$pf" | head -n 1)"
 case "$g1" in 'SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || {'*'exit 1; }') ok "전제: PR 펜스 첫 줄이 플러그인 루트 가드다" ;; *) no "전제: PR 펜스 첫 줄이 가드가 아니다" ;; esac
-for g in "$mf" "$rf"; do
+for g in "$mf" "$rf" "$cf"; do
   assert_eq "$(printf '%s\n' "$g" | head -n 1)" "$g1" "펜스 첫 줄의 플러그인 루트 가드가 PR 펜스와 글자 그대로 같다"
 done
 # 판결 줄 없는 출력을 읽는 법은 본문이 정한다 — 표시 줄이 있으면 다시 확인, 없으면 NONE
@@ -116,7 +118,11 @@
 for a in "$@"; do c="$a"; done
 cd "$FAKE_REMOTES" && eval "exec git ${c#git-}"
 FAKE
-chmod +x "$T/bin/gh" "$T/bin/sleep" "$T/bin/fakessh" || exit 1
+REAL_MKTEMP="$(command -v mktemp)" || { echo "mktemp 없음"; exit 1; }
+# 가짜 mktemp — 실패 모드와, 만든 경로의 기록(펜스가 임시 파일을 지웠는지 본다. macOS 의 인자 없는 mktemp 는 TMPDIR 을 따르지 않는다)
+printf '%s\n' '#!/bin/sh' '[ -z "${FAKE_MKTEMP_FAIL:-}" ] || { echo "mktemp: mkstemp failed: No space left on device" >&2; exit 1; }' \
+  "f=\"\$(\"$REAL_MKTEMP\" \"\$@\")\" || exit 1" '[ -z "${FAKE_GH_DIR:-}" ] || printf "%s\n" "$f" >> "$FAKE_GH_DIR/mktemps"' 'printf "%s\n" "$f"' > "$T/bin/mktemp"
+chmod +x "$T/bin/gh" "$T/bin/sleep" "$T/bin/fakessh" "$T/bin/mktemp" || exit 1
 export GIT_SSH_COMMAND="$T/bin/fakessh" GIT_SSH_VARIANT=simple FAKE_REMOTES="$T/remotes"
 export FAKE_PR_LIST='[]'
 export FAKE_WAYS='{"mergeCommitAllowed":true,"squashMergeAllowed":true,"rebaseMergeAllowed":true}'
@@ -148,7 +154,7 @@
   local c="$T/$1" body="${2//"$PH"/$T/$1/${BRIEF_REL:-$STEM.md}}"
   body="${body//"$UPH"/${3:-$UPH}}"
   body="${body//"$HPH"/${4:-$HPH}}"
-  : > "$T/gh-$1/log"; : > "$T/gh-$1/sleeps"; rm -f "$T/gh-$1/views"
+  : > "$T/gh-$1/log"; : > "$T/gh-$1/sleeps"; : > "$T/gh-$1/mktemps"; rm -f "$T/gh-$1/views"
   ( cd "$c" && CLAUDE_PLUGIN_ROOT="$SD" PATH="$T/bin:$PATH" FAKE_GH_LOG="$T/gh-$1/log" FAKE_GH_DIR="$T/gh-$1" \
       FAKE_SLEEP_LOG="$T/gh-$1/sleeps" FAKE_OWNER="$1" FAKE_REMOTE="$T/remotes/$1/r.git" "${SHELL_ARGV[@]}" "$body" 2>&1 )
 }
@@ -160,7 +166,9 @@
 }
 omain() { git -C "$T/$1" rev-parse refs/remotes/origin/main; }   # 로컬이 아는 origin 기본 브랜치
 MARK='interview-merge-requested: 7'
+SRC='값의 출처'
 CUT='echo $$ > "$FAKE_GH_DIR/fence.pid"'   # 테스트만의 한 줄 — 가짜 gh 가 이 pid 를 죽여 「요청 뒤 끊김」을 만든다
+ERRF='exec 2> "$FAKE_GH_DIR/stderr"'       # 테스트만의 한 줄 — 펜스의 stderr 를 파일로 갈라 받는다(run 의 출력에는 stdout 만 남는다)
 head_of() { printf '%s\n' "$1" | sed -n 's/^interview-pr-head: //p'; }   # PR 펜스 출력에서 끝 커밋
 remote_ref() { git --git-dir="$T/remotes/$1/r.git" rev-parse -q --verify "refs/heads/$2" 2>/dev/null || true; }
 
@@ -182,6 +190,13 @@
   assert_contains "$o" "interview-pr-files: ONLY" "새 PR: seed · 세 파일 · 로드맵 폴더뿐이면 ONLY"
   assert_contains "$o" "이 PR 은 인터뷰 폴더와 로드맵 폴더의 파일만 담는다." "새 PR: ONLY 의 사람 줄"
   assert_eq "$(printf '%s\n' "$o" | tail -n 2 | head -n 1)" "interview-pr-head: $(git -C "$c" rev-parse HEAD)" "새 PR: 판결 바로 앞 줄이 push 한 끝 커밋"
+  # 14a. 「값의 출처」 — 끝내기 커밋 펜스가 보인 키의 줄을 PR 펜스는 다시 보이지 않는다
+  assert_not_contains "$o" "$SRC" "값의 출처: PR 펜스 출력에 없다"
+  for kp in "interview_dir $c/$STEM.md" "roadmaps_dir $c/$RREL"; do   # 짝 1 — 걸러서 없는 것이지 원래 없는 것이 아니다
+    d="$(python3 "$SD/scripts/repo_defaults.py" check-path "${kp%% *}" "${kp#* }" --root "$c" 2>&1)" && d_rc=0 || d_rc=$?
+    assert_eq "$d_rc" "0" "값의 출처(짝 1): 같은 픽스처에서 check-path ${kp%% *} 를 직접 부르면 통과한다"
+    assert_grep "$d" "^\[spec-distill\] ${SRC}: .+\(${kp%% *}\)\$" "값의 출처(짝 1): 그때 그 줄이 나온다 — 펜스가 걸러서 없는 것이다"
+  done
 
   # 2. 이 레포 안 브랜치의 열린 PR 이 있으면 그것을 쓴다 — 다른 레포의 브랜치에서 온 PR 은 세지 않는다
   n="${P}reuse"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
@@ -218,6 +233,8 @@
   assert_contains "$o" "  - src/app.py" "넓은 §7: 그 폴더의 코드를 목록에 보인다"
   assert_contains "$o" "brief §7 의 로드맵 폴더가 정해진 로드맵 폴더 바로 아래가 아니다(위 사유) — 그 폴더의 파일도 밖의 파일로 센다: $c/src" "넓은 §7: 빼지 않은 사실과 폴더를 보인다"
   assert_not_contains "$o" "interview-pr-files: ONLY" "넓은 §7: ONLY 를 내지 않는다"
+  assert_contains "$o" "[spec-distill] 부모 폴더가 다르다: src 의 부모는 / 인데 정해진 폴더는 docs/superpowers/roadmaps/ 다(roadmaps_dir) — 그 폴더 바로 아래 경로를 준다" "값의 출처(짝 2): 넓은 §7 — 해결자의 사유 줄은 그대로 보인다"
+  assert_not_contains "$o" "$SRC" "값의 출처: 넓은 §7 — 판정이 거부돼도 그 줄은 없다"
   # 3c. brief 가 정해진 인터뷰 폴더 바로 아래가 아니면 그 폴더도 빼지 않는다
   n="${P}stray"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
   mkdir -p "$c/notes"; cp "$c/$STEM.md" "$c/notes/b.md"; git -C "$c" add -- notes; git -C "$c" commit -q -m "docs: stray brief"
@@ -225,6 +242,24 @@
   assert_contains "$o" "interview-pr-files: MIXED" "인터뷰 폴더 밖의 brief: MIXED"
   assert_contains "$o" "  - notes/b.md" "인터뷰 폴더 밖의 brief: 그 폴더의 파일을 목록에 보인다"
   assert_contains "$o" "brief 가 정해진 인터뷰 폴더 바로 아래가 아니다(위 사유)" "인터뷰 폴더 밖의 brief: 빼지 않은 사실을 보인다"
+  assert_contains "$o" "[spec-distill] 부모 폴더가 다르다: notes/b.md 의 부모는 notes/ 인데 정해진 폴더는 docs/superpowers/interview/ 다(interview_dir) — 그 폴더 바로 아래 경로를 준다" "값의 출처(짝 2): 인터뷰 폴더 밖의 brief — 해결자의 사유 줄은 그대로 보인다"
+  assert_not_contains "$o" "$SRC" "값의 출처: 인터뷰 폴더 밖의 brief — 판정이 거부돼도 그 줄은 없다"
+  # 걸러 낸 뒤에도 해결자의 줄은 stderr 로, 펜스의 줄은 stdout 으로 간다
+  o="$(BRIEF_REL=notes/b.md run "$n" "$ERRF
+$pf")"; e="$(cat "$T/gh-$n/stderr")"
+  assert_contains "$e" "[spec-distill] 부모 폴더가 다르다: notes/b.md 의 부모는 notes/ 인데" "값의 출처(짝 2): 해결자의 사유 줄은 stderr 로 다시 나온다"
+  assert_not_contains "$o" "부모 폴더가 다르다" "값의 출처(짝 2): 해결자의 사유 줄이 stdout 으로 옮겨 가지 않았다"
+  assert_contains "$o" "brief 가 정해진 인터뷰 폴더 바로 아래가 아니다(위 사유)" "값의 출처(짝 2): 펜스의 줄은 stdout 그대로다"
+  assert_not_contains "$e$o" "$SRC" "값의 출처: stdout · stderr 어디에도 그 줄은 없다"
+  # 임시 파일을 못 만들면 거르지 않고 그대로 돈다 — 판정의 종료 코드(거부)와 사유 줄은 그대로이고, 그때는 「값의 출처」 줄도 보인다
+  o="$(FAKE_MKTEMP_FAIL=1 FAKE_PR_LIST='[{"url":"https://github.com/'"$n"'/r/pull/5","isCrossRepository":false}]' BRIEF_REL=notes/b.md run "$n" "$pf")"
+  assert_eq "$(last "$o")" "interview-pr: OPEN https://github.com/$n/r/pull/5" "임시 파일 실패(거부되는 판정): 판결은 그대로 OPEN"
+  assert_contains "$o" "mktemp: mkstemp failed" "임시 파일 실패(거부되는 판정): 전제 — mktemp 가 실패했다"
+  assert_contains "$o" "interview-pr-files: MIXED" "임시 파일 실패(거부되는 판정): MIXED"
+  assert_contains "$o" "  - notes/b.md" "임시 파일 실패(거부되는 판정): 판정의 거부가 그대로 읽힌다 — 그 폴더의 파일을 목록에 보인다"
+  assert_contains "$o" "brief 가 정해진 인터뷰 폴더 바로 아래가 아니다(위 사유)" "임시 파일 실패(거부되는 판정): 판정의 거부가 그대로 읽힌다 — 빼지 않은 사실을 보인다"
+  assert_contains "$o" "[spec-distill] 부모 폴더가 다르다: notes/b.md 의 부모는 notes/ 인데" "임시 파일 실패(거부되는 판정): 사유 줄이 보인다"
+  assert_eq "$(printf '%s\n' "$o" | grep -c "^\[spec-distill\] ${SRC}: ")" "2" "임시 파일 실패(거부되는 판정): 거르지 않아 「값의 출처」 줄이 판정마다 보인다"
   # 3d. 파일을 세지 못하면 UNKNOWN — ONLY 를 내지 않아 권장 꼬리가 붙지 않는 쪽으로 간다
   n="${P}unknown"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
   git -C "$c" checkout -q --orphan feature/y; git -C "$c" commit -q -m "기본 브랜치와 조상이 없는 브랜치"
@@ -524,5 +559,42 @@
   done
   o="$(run "$n" "$rf" "$URL")"
   assert_eq "$(last "$o")" "interview-merge: MERGED" "다시 확인(대조의 짝): 같은 픽스처에서 브랜치 · 바탕 · 레포가 같으면 MERGED"
+
+  note "=== ${sh_name}: 「값의 출처」 줄 ==="
+  # 14b. 끝내기 커밋 펜스는 두 키의 「값의 출처」 줄을 보이고, 이어 도는 PR 펜스는 그 줄을 다시 보이지 않는다
+  n="${P}src"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
+  printf 'y\n' >> "$c/$STEM.state.md"
+  o="$(run "$n" "$cf")"
+  assert_contains "$o" "brief · audit · 상태 파일 · 로드맵 폴더를 커밋했다" "값의 출처: 끝내기 커밋 펜스가 커밋했다(PR 단계가 도는 조건)"
+  assert_eq "$(printf '%s\n' "$o" | grep -c "^\[spec-distill\] ${SRC}: .*(interview_dir)\$")" "1" "값의 출처: 끝내기 커밋 펜스는 interview_dir 의 줄을 보인다"
+  assert_eq "$(printf '%s\n' "$o" | grep -c "^\[spec-distill\] ${SRC}: .*(roadmaps_dir)\$")" "1" "값의 출처: 끝내기 커밋 펜스는 roadmaps_dir 의 줄을 보인다"
+  o="$(run "$n" "$pf")"
+  made=0; left=""
+  while IFS= read -r f; do made=$((made + 1)); [ ! -e "$f" ] || left="${left} ${f}"; done < "$T/gh-$n/mktemps"
+  assert_eq "$made" "3" "값의 출처(전제): PR 펜스가 임시 파일을 셋 만들었다(PR 본문 · 판정 둘)"
+  assert_eq "$left" "" "값의 출처: PR 펜스가 임시 파일을 남기지 않는다"
+  assert_eq "$(last "$o")" "interview-pr: OPEN https://github.com/$n/r/pull/7" "값의 출처: 이어 돈 PR 펜스의 판결은 OPEN"
+  assert_contains "$o" "interview-pr-files: ONLY" "값의 출처: 걸러도 두 판정은 통과로 읽힌다(ONLY)"
+  assert_not_contains "$o" "$SRC" "값의 출처: 이어 돈 PR 펜스 출력에는 그 줄이 없다"
+  # 14c. 알림 줄은 남는다 — 작업 트리에만 있는 레포 설정 파일의 알림(판정마다 한 번, 두 번)
+  printf -- '---\n---\n' > "$c/.devbrew.md"
+  o="$(run "$n" "$pf")"
+  assert_eq "$(printf '%s\n' "$o" | grep -c "^\[spec-distill\] 레포 설정 파일(.devbrew.md)이 아직 기본 브랜치에 없다 — 기본값을 쓴다\$")" "2" "값의 출처: 해결자의 알림 줄은 그대로 보인다(판정 둘)"
+  assert_not_contains "$o" "$SRC" "값의 출처: 알림이 있어도 그 줄은 없다"
+  assert_contains "$o" "interview-pr-files: ONLY" "값의 출처: 알림이 있어도 판정은 통과로 읽힌다"
+  rm -f "$c/.devbrew.md"
+  # 임시 파일을 못 만들면 거르지 않고 그대로 돈다 — 통과하는 판정은 통과로 읽힌다
+  o="$(FAKE_MKTEMP_FAIL=1 FAKE_PR_LIST='[{"url":"https://github.com/'"$n"'/r/pull/5","isCrossRepository":false}]' run "$n" "$pf")"
+  assert_contains "$o" "mktemp: mkstemp failed" "임시 파일 실패(통과하는 판정): 전제 — mktemp 가 실패했다"
+  assert_contains "$o" "interview-pr-files: ONLY" "임시 파일 실패(통과하는 판정): 판정의 통과가 그대로 읽힌다(ONLY)"
+  assert_eq "$(printf '%s\n' "$o" | grep -c "^\[spec-distill\] ${SRC}: ")" "2" "임시 파일 실패(통과하는 판정): 거르지 않아 「값의 출처」 줄이 판정마다 보인다"
+  # 14d. 경고 줄은 남는다 — 기본 브랜치의 레포 설정이 깨진 값을 가질 때
+  n="${P}srcwarn"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
+  git -C "$c" switch -q main; printf -- '---\nparallel_default: x\n---\n' > "$c/.devbrew.md"
+  git -C "$c" add -- .devbrew.md; git -C "$c" commit -q -m "chore: settings"; git -C "$c" push -q origin main 2>/dev/null; git -C "$c" switch -q feature/x
+  o="$(run "$n" "$pf")"
+  assert_eq "$(printf '%s\n' "$o" | grep -c "동시 작업 권장 수는 1 이상의 정수다(parallel_default: 'x')")" "2" "값의 출처: 해결자의 경고 줄은 그대로 보인다(판정 둘)"
+  assert_not_contains "$o" "$SRC" "값의 출처: 경고가 있어도 그 줄은 없다"
+  assert_contains "$o" "interview-pr-files: ONLY" "값의 출처: 경고가 있어도 판정은 통과로 읽힌다"
 done
 finish
~~~~

## 6. 변이 표

계획 단계의 결과다 — 구현자가 다시 걸어 맞는지 보는 기대값이다. 살아남은 변이는 없다. 계측은 과제마다 달랐다: 과제 2 · 5 · 8 · 9 는 사본에서(작업 트리를 건드리지 않는다), 과제 3 · 4 · 6 · 7 은 제자리에서 백업 · 되돌림으로 쟀다.

### 변이 표 — 과제 3 (넘김 글)

~~~~
변이 없음: 실패 0
KILLED L1 넘김 줄에 옛 문장을 되붙임 — 새 실패 2: test_review_handoff_order.sh: ✗ F4 AC1: 다음 세션 줄은 시작 문장과 지시 파일을 가리키는 문장뿐이다 | test_review_handoff_order.sh: ✗ F4 AC1: 옛 지시 문장 2 이 다음 세션 줄에 없다
KILLED L2 넘김 줄에서 가리킴 문장을 뗌 — 새 실패 2: test_review_handoff_order.sh: ✗ F4 AC1: 다음 세션 줄은 시작 문장과 지시 파일을 가리키는 문장뿐이다 | test_plain_gate_templates.sh: ✗ F4 AC1: finishing.md 의 다음 세션 줄이 지시 파일의 절을 가리킨다
KILLED L3 넘김 줄이 공통 지시 절을 가리킴 — 새 실패 2: test_review_handoff_order.sh: ✗ F4 AC1: 다음 세션 줄은 시작 문장과 지시 파일을 가리키는 문장뿐이다 | test_plain_gate_templates.sh: ✗ F4 AC1: finishing.md 의 다음 세션 줄이 지시 파일의 절을 가리킨다
KILLED O1 다른 다음 단계의 줄이 brainstorming 절을 가리킴 — 새 실패 3: test_review_handoff_order.sh: ✗ F4 AC3: 다른 다음 단계의 줄이 공통 지시 절을 가리키는 문장을 싣는다 | test_end_gates.sh: ✗ AC23: 「다른 다음 단계의 줄」 문단 «/references/brief-handoff.md 의 ## 공통 지시 절을 읽고 | test_plain_gate_templates.sh: ✗ F4 AC3: 「다른 다음 단계의 줄」 문단이 공통 지시 절을 가리킨다
KILLED O2 다른 다음 단계의 줄에 공통 지시 문장을 되실음 — 새 실패 2: test_review_handoff_order.sh: ✗ F4 AC3: 공통 지시 문장 3 이 문단에 글자로 없다 | test_end_gates.sh: ✗ F4 AC3: 「다른 다음 단계의 줄」 문단에는 글자로 없다 «brief 의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다
KILLED B1 brainstorming 절의 문장 하나를 지움 — 새 실패 2: test_review_handoff_order.sh: ✗ F4 AC2(양성 대조): brainstorming 지시 절에서 문장 열여섯을 읽었다 | test_review_handoff_order.sh: ✗ F4 AC2: brainstorming 지시 절이 옛 줄의 지시 문장을 순서대로 모두 싣는다
KILLED B2 두 문장의 순서를 바꿈 — 새 실패 1: test_review_handoff_order.sh: ✗ F4 AC2: brainstorming 지시 절이 옛 줄의 지시 문장을 순서대로 모두 싣는다
KILLED B3 「사용자 선호:」 라벨을 되붙임 — 새 실패 2: test_review_handoff_order.sh: ✗ F4 AC2: brainstorming 지시 절이 옛 줄의 지시 문장을 순서대로 모두 싣는다 | test_review_handoff_order.sh: ✗ F4 AC2: 「사용자 선호:」 라벨이 없다(양성 짝: 라벨 뗀 그 문장은 위 등호가 본다)
KILLED B4 문장 하나를 더함 — 새 실패 2: test_review_handoff_order.sh: ✗ F4 AC2(양성 대조): brainstorming 지시 절에서 문장 열여섯을 읽었다 | test_review_handoff_order.sh: ✗ F4 AC2: brainstorming 지시 절이 옛 줄의 지시 문장을 순서대로 모두 싣는다
KILLED B5 한 문장의 글자를 바꿈 — 새 실패 1: test_review_handoff_order.sh: ✗ F4 AC2: brainstorming 지시 절이 옛 줄의 지시 문장을 순서대로 모두 싣는다
KILLED C1 공통 지시 절의 판 확인 문장을 지움 — 새 실패 1: test_review_handoff_order.sh: ✗ F4 AC3: 공통 지시 절이 네 문장과 판 확인 문장을 싣는다
KILLED C2 공통 지시 절이 brainstorming 절을 가리킴 — 새 실패 2: test_review_handoff_order.sh: ✗ F4: 공통 지시 절이 brainstorming 지시 절을 가리키지 않는다 | test_review_handoff_order.sh: ✗ F4 AC3: 공통 지시 절이 네 문장과 판 확인 문장을 싣는다
~~~~

### 변이 표 — 글 needle (과제 4 · 5 · 6 · 7)

테스트 블록의 작은따옴표 리터럴마다 대상 파일에서 그 글을 지우고 그 테스트를 돌렸다. 「지운 자리」 가 1곳이 아닌 needle 은 그 글이 여러 곳에 있다는 뜻이다(가리키는 구절은 일부러 넷이다). 「못 찾음」 넷은 부재를 단언하는 needle 이다(옛 문장 — 파일에 없어야 맞다).

~~~~
== test_saturation_reference.sh (tests-t4-saturation.sh) — 변이 없음: rc 0, 실패 0
KILLED (지운 자리 1곳 · saturation.md · 새 실패 1) `- 모델 판단으로 건너뜀 — 범위 조사: <이유>` — audit §2 의 mapper 줄은 `coverage-mapper 
KILLED (지운 자리 1곳 · saturation.md · 새 실패 1) `- 모델 판단으로 건너뜀 — 맹점 조사: <이유>` — 원장의 `floor:blind_spot` 은 `evidence` 를 
KILLED (지운 자리 1곳 · saturation.md · 새 실패 1) `- 모델 판단으로 건너뜀 — 포화 판정: <이유>` — floor 다섯이 닫힌 뒤 판정자를 부르지 않고 `finishing.
KILLED (지운 자리 1곳 · saturation.md · 새 실패 1) 포화 판정 줄이 이미 있으면 이 줄을 쓰지 않는다
KILLED (지운 자리 1곳 · saturation.md · 새 실패 1) 같은 자리의 줄을 둘 두지 않는다
KILLED (지운 자리 1곳 · saturation.md · 새 실패 1) `<이유>` 는 비우지 않는다.
KILLED (지운 자리 1곳 · saturation.md · 새 실패 1) 나누기로 정하면(분해 판단) 건너뛴 조사를 그때 돌리고 그 줄을 지운다 — 나눈 일은 구조 게이트가 건너뜀 줄을 받지 않는다.
KILLED (지운 자리 1곳 · saturation.md · 새 실패 1) 리뷰 쪽 셋(재비판 · codex · 읽어 보기)의 줄은 결과물 리뷰 skill 이 같은 블록에 같은 모양으로 더한다.
KILLED (지운 자리 1곳 · saturation.md · 새 실패 1) - `- 모델 판단으로 건너뜀 — <범위 조사 | 맹점 조사 | 포화 판정 | 재비판 | codex | 읽어 보기>: <이유>
KILLED (지운 자리 1곳 · saturation.md · 새 실패 1) 조사나 판정을 모델 판단으로 건너뛸 때(`### 건너뜀`)
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 2) **건너뜀.** 나누지 않을 작은 일로 보이면 필수 자리 둘과 포화 판정을 이유를 적고 건너뛸 수 있다
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 1) `- 모델 판단으로 건너뜀 — <자리>: <이유>` 한 줄을 덧붙인다
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 1) 나누기로 하면 건너뛴 조사를 그때 돌린다
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 1) 건너뛴 것은 끝 질문 앞에서 사용자에게 보이고, 사용자가 하라고 하면 그때 돌린다.
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 2) **건너뜀.**
KILLED (지운 자리 4곳 · SKILL.md · 새 실패 1) 작은 일의 건너뜀은 `## 조사 상한 · 포화 판정` 의 「건너뜀」
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) **모델 판단으로 맹점 조사를 건너뛴 floor**
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 사용자-승인 박제와 같은 길로 간다 — 그 내용을 payload `## 3. Open Questions` 에 한 항목으로 옮겨
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 모델 판단으로 첫 범위 조사를 건너뛰었으면 `coverage-mapper 0` 으로 적는다
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 사용자 종료 · 모델 판단으로 건너뜀 줄이 사건 순간 거기 쌓였습니다.
== test_open_research.sh (tests-t4-open-research.sh) — 변이 없음: rc 0, 실패 0
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 2) 은 그대로이고, 작은 일의 건너뜀은 `## 조사 상한 · 포화 판정` 의 「건너뜀」 을 따른다
== test_reviewing_brief_skill.sh (tests-t5-skill.sh) — 변이 없음: rc 0, 실패 0
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 16) 건너뜀 — 모델 판단
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 1) 이 자리의 부품 셋 — 재비판 · codex · 읽어 보기(냉독) — 을 이유를 적고 건너뛸 수 있다.
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 1) 탐지(첫 검토)는 건너뛰지 않는다
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 1) brief §7 에 `분해됨 — ` 줄이 있으면(나눈 일) 아무것도 건너뛰지 않는다
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 1) `## audit §2 대기 줄` 에 `- 모델 판단으로 건너뜀 — <재비판 | codex | 읽어 보기>: <이유>` 한 줄
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 1) 그 자리의 줄이 이미 있으면 이유만 바꿔 쓰고, 앞 라운드에서 건너뛴 부품을 이번 라운드에 돌렸으면 그 줄을 지운다.
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 1) 6단계 dispatch 를 하지 않고 7단계 라우팅을 `--recritic` 대신 `--recritic-skipped` 로 돌
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 1) codex 펜스를 통째로 건너뛰지 않고 그대로 돌린다.
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 1) 펜스 머리의 `DEVBREW_MODEL_SKIP_EOF` 두 줄 사이 빈 줄을 이유 한 줄로 바꿔 돌린다
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 1) 따옴표로 감싸지 않고 글자 그대로, 그 밖의 줄은 고치지 않는다
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 1) 펜스가 직전 산출물을 지운 뒤 러너만 부르지 않는다.
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 1) 펜스가 `(reason: model_skip)` 을 냈을 때만 건너뜀 줄을 더한다
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 1) `## 냉독` 을 돌리지 않고 Step B 로 넘기는 둘째 항목에 「읽어 보기를 건너뛰었다 — <이유>」 를 싣는다.
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 1) 끄기 스위치로 꺼진 부품에는 건너뜀 줄을 쓰지 않는다
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 1) 그 기록은 그대로 남긴다.
KILLED (지운 자리 1곳 · SKILL.md · 새 실패 1) 건너뛴 것을 나중에 돌리는 길은 호출자의 `#### B-S` 가 정한다.
== test_end_gates.sh (tests-t6-end-gates.sh) — 변이 없음: rc 0, 실패 0
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 5. **건너뛴 것 <N>개** — `check_brief.py gate` 의 `advisories` 가운데 `건너뜀 — ` 
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 이 줄들은 경고(목록 4)에 다시 쓰지 않되 질문의 「경고 N개」 에는 센다 — 건너뛴 것이 있으면 「이상 없음」 · 「경고 
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 「(경고에도 있다)」 를 붙이며 경고 수에는 한 번만 센다.
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 항목 끝에 「하게 하려면 기타 칸에 적는다」 한 줄을 싣는다.
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 0개면 이 항목을 쓰지 않는다.
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 그 줄 끝에 「— 끄기 스위치가 아니라 모델 판단으로 건너뛰었다」 를 덧붙인다(엔진의 글자는 고치지 않는다).
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) **기타 칸 — 건너뛴 것을 하라는 말.** 사용자가 기타 칸에 건너뛴 것을 하라고 적으면 B-S 로 간다.
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 그 말이 「여기서 계속」 인지 건너뛴 것을 하라는 것인지 불분명하면 다시 묻는다.
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 적은 뒤 — 적을 참고 항목이 없어도 — audit §2 의 사건 줄을 상태 파일의 `## audit §2 대기 줄` 블록에서
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 리뷰가 그 블록에 더한 건너뜀 줄은 여기서 검사에 닿고, B-2 의 게이트 앞 글이 읽는 `advisories` 는 이 실행의
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 사유가 「나눈 일은 건너뛸 수 없다」 면 끝 질문을 띄우지 않고 아래 B-S 로 갑니다:
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 줄은 그 블록에서 지우고 audit §2 를 그 블록에서 다시 짓는다
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 그 건너뜀 줄을 대기 줄 블록에서 지우고 Step A.5 의 「조사 계속」 갈래로 간다
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 맹점 조사를 건너뛴 차원은 다시 열려 지금 규칙대로 사용자 발화로 닫힌다.
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) `reviewing-brief` 를 한 라운드 더 돈다(탐지부터 — 재리뷰 상한에 든다).
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 줄만 지우고 audit 을 그대로 두면 그 skill 의 진입 게이트가 옛 audit 으로 구조 게이트를 돌려 나눈 일은 다시
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) `reviewing-brief` 의 `## 냉독` 만 돌리고 끝 질문으로 돌아간다.
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 리뷰 라운드를 다시 돌지 않고 재리뷰 상한을 쓰지 않는다.
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 리뷰 부품의 줄(재비판 · codex · 읽어 보기)을 전부 지우고 audit §2 를 다시 지은 뒤 리뷰 한 라운드를 돌고,
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 줄 하나만 지우면 남은 줄 때문에 진입 게이트가 다시 막는다.
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 「추가 라운드 1회 열기」 질문의 답으로만 연다
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 사용자가 열지 않으면 지운 줄을 대기 줄 블록에 그대로 되돌리고 audit §2 를 다시 지은 뒤 끝 질문으로 돌아간다
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) `[spec-distill] 나눈 일은 건너뛴 리뷰 부품을 돌려야 끝낼 수 있다 — 추가 라운드를 열거나, 나누지 않기로 하면
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 어느 쪽이든 brief 가 바뀌면 리뷰를 다시 지난다 — 바뀐 brief 가 리뷰 없이 끝 질문에 닿지 않는다.
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 사유가 「나눈 일은 건너뛸 수 없다」 면 건너뜀 줄만 지워 통과시키지 않는다 — B-S 대로 건너뛴 조사 · 리뷰를 돌린 뒤에
== test_end_gates.sh (tests-t7-end-gates.sh) — 변이 없음: rc 0, 실패 0
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 왔던 끝 질문을 다시 띄운다 — 어떻게 끝낼지는 그 질문에서 고른다.
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 왔던 끝 질문(B-2 게이트 — superpowers 가 없어 B-1 의 끝 질문에서 왔으면 그 끝 질문)을 다시 띄우며
?? 대상 파일에서 못 찾음: B-2 게이트를 다시 띄운다 — 다음 단계는 그 게이트에서 고른다
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) B-1 끝 질문의 「확정하고 끝낸다」 · 「brief만 종료」 — 「지금 목록으로 확정」은 왔던 끝 질문으로 돌아가 그 질문의
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) (B-1 끝 질문의 「확정하고 끝낸다」 · 「brief만 종료」 도 같은 펜스로 커밋한다)
?? 대상 파일에서 못 찾음: B-1 은 커밋하지 않고
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) (b) superpowers 가 없을 때의 B-1 끝 질문 (선택지 셋)을 거친다 — 질문 없는 **silent 종료 금지**
?? 대상 파일에서 못 찾음: 게이트를 거치지 않는 예외
KILLED (지운 자리 1곳 · finishing.md · 새 실패 2) 선택지 넷의 개수 · 순서 · `(권장)` 은 어느 경우든 그대로
== test_superpowers_presence.sh (tests-t7-presence.sh) — 변이 없음: rc 0, 실패 0
KILLED (지운 자리 1곳 · finishing.md · 새 실패 2) {label: "확정하고 끝낸다 (권장)", description: "확정 후보를 확정으로 바꿔 저장하고 커밋한 뒤 여기서 끝
KILLED (지운 자리 2곳 · finishing.md · 새 실패 2) {label: "확정 목록 수정", description: "확정 후보와 함께 보인 공시를 고쳐 다시 보여 준다(두 번 고친 
KILLED (지운 자리 1곳 · finishing.md · 새 실패 2) {label: "brief만 종료", description: "brief 를 여기서 끝낸다. 모든 항목이 잠정으로 남는다."}
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) B-2 의 게이트 앞 글 목록(리뷰 게이트 결과 · 읽어 보기 · 남은 항목 · 경고 · 건너뛴 것)을 같은 순서 · 같은 규
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 질문의 상태 줄도 B-2 와 같은 꼴이다.
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 커밋 펜스(`interview-commit`) → 여기서 멈춘다. 분해된 일이어도 「PR 과 머지」 로 가지 않는다.
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) `[spec-distill] superpowers 가 없어 다음 단계를 열지 못했다 — 설치한 뒤 새 세션에서 아래 줄로 잇는
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 분해된 일이면 그 앞에 지휘 세션을 이 커밋이 기본 브랜치에 머지된 뒤 열라고 한 줄로 알린다.
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 고친 뒤에는 B-2 가 아니라 이 끝 질문을 다시 띄운다
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) `[spec-distill] superpowers 가 없어 이어 갈 다음 단계가 없다.` 한 줄을 보이고 같은 질문을 다시 띄
KILLED (지운 자리 1곳 · finishing.md · 새 실패 1) 건너뛴 것을 하라는 말이면 B-S 로 간다.
?? 대상 파일에서 못 찾음: superpowers 가 없어 여기서 멈춘다
~~~~

### 변이 표 — 계수 · 모양 (과제 4 · 7)

~~~~
KILLED X1 「**건너뜀.**」 문단 머리를 한 번 더 적는다(2회) — test_saturation_reference.sh 새 실패 1: ✗ F4 AC9: SKILL 의 「**건너뜀.**」 이 한 번이 아니다
KILLED X2 가리키는 구절 하나를 지운다(3줄) — test_saturation_reference.sh 새 실패 1: ✗ F4 AC9: 건너뜀 규칙을 가리키는 줄이 넷이 아니다
KILLED X3 끝 질문에 넷째 선택지를 더한다 — test_superpowers_presence.sh 새 실패 1: ✗ F4 AC10: 끝 질문의 선택지는 셋이다
KILLED X4 B-1 에 커밋 펜스 이름을 한 번 더 적는다 — test_interview_state_flow.sh 새 실패 1: ✗ AC5: 커밋 펜스 자리
KILLED X5 질문 자리 목록에서 새 꼬리 행을 지운다 — test_ask_recommendation.sh 새 실패 1: ✗ ① plugins/spec-distill/skills/pm-interview/references/finishing.md:478 후보 줄이 어느 행에도 덮이지 않는다: AskUs
KILLED X6 끝 질문의 「(권장)」 꼬리를 뗀다 — test_ask_recommendation.sh 새 실패 1: ✗ ③ plugins/spec-distill/skills/pm-interview/references/finishing.md:474 꼬리 「**선택지 셋의 따로 된 끝 질문**을 띄
KILLED X7 끝 질문의 「꼬리를 뗀 이름으로 읽는다」 문장을 지운다 — test_ask_recommendation.sh 새 실패 1: ✗ ③ plugins/spec-distill/skills/pm-interview/references/finishing.md:492 떼기 「끝 질문의 답은 라벨 끝의」 (목록 L21
~~~~

### 변이 표 — 과제 2 (구조 검사)

변이 표 — f4-proto-a (건너뜀 줄 검사 시제품, check_brief.py 30ade287 기준)
재는 법: 변이마다 scripts 폴더 사본을 만들어 그 사본의 check_brief.py 에 변이 하나를 넣고, test_check_brief.sh 의
새 칸(F4/건너뜀 150 단언)만 뽑은 러너를 그 사본에 겨눠 돌렸다(PYTHONDONTWRITEBYTECODE=1 · bash 3.2.57).
변이마다 (1) 바꿀 글자가 정확히 한 번 있었는지 (2) 변이본이 파싱되는지 (3) 「건너뜀 줄 없는 정상 쌍」 대조가 살아 있는지를 먼저 봤다.
양성 대조: 변이 없는 사본으로 150/150 통과. 새 칸만 뽑은 러너의 150 줄은 테스트 파일 전체 실행의 F4 150 줄과 같다.
m1–m13 은 처음 지시의 변이, m14–m18 은 뒤에 온 지시의 변이, x* 는 삭제 밖의 축(추가 · 반전 · 형태 변경)으로 내가 더한 것.
요약: 변이 49개 · 죽음 49 · 살아남음 0  · 계측 불가 0 

| 변이 | 무엇을 바꿨나 | 판정 | 실패한 단언 수 |
| control | 변이 없음(양성 대조 — 사본 경로로 잰다) | 대조 | 0 |
| m1 | 문법: 자리 집합 검사를 뗌 | 죽음 | 13 |
| m2 | 문법: 빈 이유 검사를 뗌 | 죽음 | 16 |
| m3 | 문법: 중복 검사를 뗌(뒤 줄이 덮어쓴다) | 죽음 | 9 |
| m4 | 범위 조사 완화를 「항상 통과」 로 | 죽음 | 5 |
| m5 | 범위 조사 완화를 뗌 | 죽음 | 5 |
| m6 | 포화 판정 완화를 「판정 줄이 있어도 통과」 로 | 죽음 | 3 |
| m7 | 맹점 면제를 모든 차원으로 넓힘 | 죽음 | 3 |
| m8 | 맹점 면제가 §2 줄을 안 봄 | 죽음 | 3 |
| m9 | 나눈 일 검사를 뗌 | 죽음 | 15 |
| m10 | 나눈 일 검사가 §7 밖의 `분해됨 — ` 에도 걸림 | 죽음 | 1 |
| m11 | advisory 를 안 냄 | 죽음 | 77 |
| m12 | `(unavailable:)` 빈 이유를 다시 통과시킴 | 죽음 | 4 |
| m13 | 사건 줄 접두를 뗌 | 죽음 | 2 |
| m14 | 모순 검사 (a) 를 뗌 — `범위 조사` 줄 + mapper 계수 1 이상 | 죽음 | 5 |
| m15 | 모순 검사 (b) 를 뗌 — `포화 판정` 줄 + 판정 줄 | 죽음 | 2 |
| m16 | 모순 검사 (c) 를 뗌 — `맹점 조사` 줄 + 건너뜀으로 시작하지 않는 근거 | 죽음 | 2 |
| m17 | 건너뜀 줄 판독을 `-` 불릿으로만 좁힘 | 죽음 | 19 |
| m18 | 자리 · 이유 가르기를 마지막 `: ` 로 바꿈 | 죽음 | 3 |
| x1 | 형태: 건너뜀 줄을 §2 가 아니라 audit 전체 불릿에서 읽음 | 죽음 | 1 |
| x2 | 형태: 줄 머리가 아니라 줄 어디든 접두가 있으면 건너뜀 줄 | 죽음 | 1 |
| x3a | 형태: 구분자로 하이픈도 받음 | 죽음 | 1 |
| x3b | 형태: 콜론 뒤 공백 없이도 받음 | 죽음 | 1 |
| x3c | 형태: 빈 자리도 줄 문법으로 받음(형식 밖이 아니라 모르는 자리로 읽힘) | 죽음 | 1 |
| x3d | 형태: 콜론 없는 줄도 받음(자리만 적고 이유 없이) | 죽음 | 1 |
| x4 | 형태: 이유의 공백 다듬기를 뗌(공백뿐인 이유가 통과) | 죽음 | 28 |
| x5 | 형태: 나눈 일 판독이 줄 머리가 아니라 줄 어디든 | 죽음 | 1 |
| x6 | 형태: 맹점 면제가 근거 접두를 안 봄(줄만 있으면 면제) | 죽음 | 5 |
| x7 | 형태: 맹점 면제가 근거 가운데의 접두에도 열림 | 죽음 | 1 |
| x8 | 추가: 면제된 맹점 근거는 인용한 앵커의 실재도 안 봄 | 죽음 | 1 |
| x9 | 반전: 범위 조사 완화가 아무 건너뜀 줄에나 열림 | 죽음 | 1 |
| x10 | 반전: 포화 판정 완화가 아무 건너뜀 줄에나 열림 | 죽음 | 3 |
| x11 | 반전: 맹점 면제가 아무 건너뜀 줄에나 열림 | 죽음 | 1 |
| x12 | 형태: 나눈 일 검사가 문법이 맞는 줄만 셈 | 죽음 | 1 |
| x13 | 형태: 나눈 일 판독이 `- ` · 백틱을 안 뗌 | 죽음 | 3 |
| x14 | 형태: 나눈 일 판독이 §7 의 첫 줄만 봄 | 죽음 | 1 |
| x15 | 형태: 빈 괄호 검사가 `(unavailable:)` 만 잡음(공백뿐은 통과) | 죽음 | 2 |
| x16 | 추가: 건너뜀 줄이 빈 괄호 `(unavailable:)` 를 구함 | 죽음 | 1 |
| x17 | 형태: advisory 글자가 다름(꼬리 문구) | 죽음 | 27 |
| x18 | 형태: advisory 가 JSON 에만 나가고 stderr 로는 안 나감 | 죽음 | 26 |
| x19 | 형태: advisory 가 자리 순으로 정렬돼 나감(§2 순서 아님) | 죽음 | 1 |
| x20 | 추가: mapper 줄이 없어도 `범위 조사` 줄이 있으면 통과 | 죽음 | 3 |
| x21 | 반전: 나눈 일이 아닐 때 건너뜀 줄을 막음 | 죽음 | 41 |
| x22 | 형태: 이유 글의 판정 줄 글자를 판정 줄로 읽음(`_sat_hits` 가 줄 어디서든 찾음) | 죽음 | 2 |
| x23 | 반전: 모순 검사 (a) 의 경계를 2 이상으로 | 죽음 | 4 |
| x24 | 형태: 모순 검사 (b) 가 사용자 종료 줄은 세지 않음 | 죽음 | 1 |
| x25 | 형태: 모순 검사 (b) 가 통과 꼴 판정 줄(포화)은 봐줌 | 죽음 | 1 |
| x26 | 추가: 모순 검사를 리뷰 부품에도 건다(재비판 줄이 있으면 실패) | 죽음 | 7 |
| x27 | 형태: 모순 검사 (c) 가 박제 근거(사용자-승인 박제)는 봐줌 | 죽음 | 1 |
| x28 | 삭제: gate() 가 모순 검사를 부르지 않음 | 죽음 | 9 |

### 변이 표 — 과제 5 (codex 펜스)

칸: 변이 · 무엇을 바꿨나 · 판정 · `rc ✓수 ✗수`.

| 변이 | 무엇을 바꿨나 | 판정 | 결과 |
|---|---|---|---|
| control-pre-A | 변이 없음 @ 0e4de811 | CONTROL-GREEN | 0 153 0 |
| m1 | 삭제 — 건너뜀 갈래를 뗀다(입력은 읽되 쓰지 않는다) | KILLED | 1 108 45 [펜스 문법 ok] |
| m2a | 위치 — 건너뜀이면 중화를 하지 않는다(산출물이 남는다) | KILLED | 1 138 15 [펜스 문법 ok] |
| m2b | 위치 — 건너뜀 갈래를 중화 «앞»으로 옮겨 공시만 내고 끝낸다(펜스를 통째로 건너뛴 꼴) | KILLED | 1 130 23 [펜스 문법 ok] |
| m3 | 삭제 — 건너뜀이 가용성을 끄지 않아 러너를 그대로 부른다 | KILLED | 1 112 41 [펜스 문법 ok] |
| m4 | 형태 — 건너뜀이 끄기 스위치 · 미설치 사유를 덮는다(입력 부재 · 중화 실패만 남긴다) | KILLED | 1 147 6 [펜스 문법 ok] |
| control-post-A | 변이 없음 @ 0e4de811 | CONTROL-GREEN | 0 153 0 |
| control-pre-B | 변이 없음 @ 0e4de811 | CONTROL-GREEN | 0 153 0 |
| m5 | 형태 — 건너뜀이 중화 실패 · 입력 부재 사유를 덮는다(끄기 스위치만 남긴다) | KILLED | 1 148 5 [펜스 문법 ok] |
| m5b | 형태 — 건너뜀이 어느 사유든 덮는다(조건 없음) | KILLED | 1 142 11 [펜스 문법 ok] |
| m5c | 위치 — 건너뜀 갈래를 중화 실패 판정 «앞»으로 옮긴다(뒤 판정이 다시 덮는지) | KILLED | 1 152 1 [펜스 문법 ok] |
| m6 | 삭제 — 모델 건너뜀 공시에서 이유를 뺀다 | KILLED | 1 145 8 [펜스 문법 ok] |
| m6b | 삭제 — 다른 사유가 이긴 라운드의 공시에서 적은 이유를 뺀다 | KILLED | 1 149 4 [펜스 문법 ok] |
| control-post-B | 변이 없음 @ 0e4de811 | CONTROL-GREEN | 0 153 0 |
| control-pre-C | 변이 없음 @ 0e4de811 | CONTROL-GREEN | 0 153 0 |
| m6c | 삭제 — 공시 줄에서 덧붙는 글 전체를 뺀다 | KILLED | 1 141 12 [펜스 문법 ok] |
| m6d | 반전 — 두 공시 글을 맞바꾼다(스위치가 끈 라운드를 모델이 건너뛰었다고 한다) | KILLED | 1 145 8 [펜스 문법 ok] |
| m7 | 형태 — 빈 입력에서도 건너뛴다(입력 조건을 뗀다) | KILLED | 1 137 16 [펜스 문법 ok] |
| m7b | 삭제 — 앞뒤 공백 다듬기를 뗀다(공백뿐인 입력이 건너뜀이 된다) | KILLED | 1 134 19 [펜스 문법 ok] |
| m7c | 반전 — 입력 조건을 뒤집는다(-n → -z) | KILLED | 1 92 61 [펜스 문법 ok] |
| control-post-C | 변이 없음 @ 0e4de811 | CONTROL-GREEN | 0 153 0 |
| control-pre-D | 변이 없음 @ 0e4de811 | CONTROL-GREEN | 0 153 0 |
| m7d | 추가 — 입력의 기본값이 빈 줄이 아니라 글자다(기본이 건너뜀) | KILLED | 1 70 8 [펜스 문법 ok] |
| m8a | 형태 — heredoc 구분자의 따옴표를 뗀다(본문이 전개된다) | KILLED | 1 77 1 [펜스 문법 ok] |
| m8b | 추가 — 읽은 이유를 한 번 더 평가한다(eval) | KILLED | 1 147 6 [펜스 문법 ok] |
| m8c | 형태 — 입력을 큰따옴표 대입 한 줄로 바꾼다 | KILLED | 1 77 1 [펜스 문법 ok] |
| m8d | 추가 — 환경 변수가 펜스의 입력을 덮는다 | KILLED | 1 152 1 [펜스 문법 ok] |
| control-post-D | 변이 없음 @ 0e4de811 | CONTROL-GREEN | 0 153 0 |
| control-pre-E | 변이 없음 @ 0e4de811 | CONTROL-GREEN | 0 153 0 |
| m8e | 삭제 — 읽기 앞의 빈 값 대입을 뗀다(읽기가 실패하면 미정의 · 환경 값) | KILLED | 1 152 1 [펜스 문법 ok] |
| m9 | 형태 — 공시 줄을 printf 에서 echo 로 되돌린다(zsh 가 역슬래시를 푼다) | KILLED | 1 151 2 [펜스 문법 ok] |
| m10 | 삭제 — 줄바꿈을 한 줄로 펴는 줄을 뗀다 | KILLED | 1 152 1 [펜스 문법 ok] |
| m13a | 엔진 삭제 — --recritic-skipped 가 아무것도 남기지 않는다 | KILLED | 1 151 2 [펜스 문법 ok] |
| m13b | 엔진 삭제 — --recritic-skipped 가 degrade 값만 남기지 않는다 | KILLED | 1 152 1 [펜스 문법 ok] |
| control-post-E | 변이 없음 @ 0e4de811 | CONTROL-GREEN | 0 153 0 |
| control-pre-F | 변이 없음 @ c837968a | CONTROL-GREEN | 0 153 0 |
| m8e | 삭제 — 읽기 앞의 빈 값 대입을 뗀다(읽기가 실패하면 미정의 · 환경 값) | KILLED | 1 152 1 [펜스 문법 ok] |
| control-post-F | 변이 없음 @ c837968a | CONTROL-GREEN | 0 153 0 |

### 변이 표 — 과제 8 · 9 (머지 · PR 펜스)

칸: 변이 · 패치(b1 = 과제 8 · b2 = 과제 9) · 무엇을 바꿨나 · 축 · 판정. m12c · m12d 는 첫 실행에서 살아남아 단언을 보강한 뒤 다시 잰 값이다.

| 변이 | 패치 | 무엇을 바꿨나 | 축 | 판정 |
|---|---|---|---|---|
| m0 | — | 변이 없음(양성 대조) | — | GREEN(기대대로) |
| m1 | b1 | 가 갈래를 뗌 | 삭제 | RED |
| m2 | b1 | 가 갈래가 브랜치 · 레포를 대조하지 않음(상태 · 바탕만) | 형태 | RED |
| m2a | b1 | 가 갈래가 브랜치만 대조하지 않음 | 형태 | RED |
| m2b | b1 | 가 갈래가 바탕을 대조하지 않음 | 형태 | RED |
| m2c | b1 | 가 갈래가 다른 레포의 브랜치인지 보지 않음 | 형태 | RED |
| m2d | b1 | 가 갈래가 끝 커밋까지 대조함 | 추가 | RED |
| m2e | b1 | 가 갈래가 상태를 보지 않음(열린 PR 도 머지됨으로) | 반전 | RED |
| m3 | b1 | 가 갈래가 origin 을 받지 않음 | 삭제 | RED |
| m3a | b1 | 가 갈래가 CI 검사를 한 번 부름 | 추가 | RED |
| m3b | b1 | 가 갈래의 판결이 NONE | 반전 | RED |
| m3c | b1 | 가 갈래가 머지됨 줄을 내지 않음 | 삭제 | RED |
| m4 | b1 | 나 갈래를 뗌 | 삭제 | RED |
| m4a | b1 | 나 갈래가 브랜치 · 레포를 대조하지 않음 | 형태 | RED |
| m4b | b1 | 나 갈래가 origin 을 받지 않음 | 삭제 | RED |
| m4c | b1 | 나 갈래가 끝내지 않고 이어 감 | 형태 | RED |
| m4d | b1 | 나 갈래를 다음 방식 알림 뒤로 옮김 | 위치 | RED |
| m5 | b1 | 표시 줄을 뗌 | 삭제 | RED |
| m6 | b1 | 표시 줄을 pr-merge 뒤(성공 갈래 안)로 옮김 | 위치 | RED |
| m6a | b1 | 표시 줄을 CI 검사 기다림 앞으로 옮김 | 위치 | RED |
| m6b | b1 | 표시 줄이 번호 대신 주소를 실음 | 형태 | RED |
| m6c | b1 | 표시 줄을 방식 루프 앞에서 한 번만 냄 | 위치 | RED |
| m6d | b1 | 표시 줄을 pr-merge 뒤(실패 갈래 포함, if 문 뒤)로 옮김 | 위치 | RED |
| m7 | b1 | 다시 확인 펜스가 한 번만 읽음 | 형태 | RED |
| m7a | b1 | 다시 확인 펜스가 세 번까지만 읽음 | 형태 | RED |
| m7b | b1 | 다시 확인 펜스가 다섯 번까지 읽음 | 형태 | RED |
| m7c | b1 | 다시 확인 펜스의 간격이 1초 | 형태 | RED |
| m7d | b1 | 다시 확인 펜스가 머지됨을 읽고도 끝까지 읽음 | 삭제 | RED |
| m7e | b1 | 다시 확인 펜스가 쉬지 않고 읽음 | 삭제 | RED |
| m8 | b1 | 다시 확인 펜스가 머지 상태에서 origin 을 받지 않음 | 삭제 | RED |
| m9 | b1 | 다시 확인 펜스가 끝까지 열림일 때 PR 주소를 싣지 않음 | 삭제 | RED |
| m9a | b1 | 다시 확인 펜스가 끝까지 열림일 때 요청이 나갔다고 말하지 않음 | 삭제 | RED |
| m9b | b1 | 다시 확인 펜스가 끝까지 열림인데 MERGED 를 냄 | 반전 | RED |
| m9c | b1 | 다시 확인 펜스가 브랜치 · 바탕 · 레포를 대조하지 않음 | 형태 | RED |
| m9d | b1 | 다시 확인 펜스가 CI 검사를 부름 | 추가 | RED |
| m9e | b1 | 다시 확인 펜스가 주소의 레포를 origin 과 대조하지 않음 | 삭제 | RED |
| m9f | b1 | 다시 확인 펜스에서 「다른 PR」 갈래를 뗌 | 삭제 | RED |
| m9g | b1 | 다시 확인 펜스가 머지됨인데 NONE 을 냄 | 반전 | RED |
| m9h | b1 | 다시 확인 펜스가 머지를 요청함 | 추가 | RED |
| m9i | b1 | 다시 확인 펜스의 자리표 가드(주소)를 뗌 | 삭제 | RED |
| m9j | b1 | 다시 확인 펜스의 none() 이 주소를 싣지 않음 | 삭제 | RED |
| m13 | b1 | 다시 확인 펜스가 읽기 실패를 머지됨으로 읽음 | 반전 | RED |
| m13a | b1 | 다시 확인 펜스의 「읽지 못함」 갈래가 MERGED 를 냄 | 반전 | RED |
| m13b | b1 | 다시 확인 펜스에서 「읽지 못함」 갈래를 뗌(열림 줄로 떨어짐) | 삭제 | RED |
| m13c | b1 | 다시 확인 펜스가 읽기 실패에서 바로 멈춤 | 형태 | RED |
| m14 | b1 | 다시 확인 펜스가 읽기 실패 때 PR 주소를 싣지 않음 | 삭제 | RED |
| m14a | b1 | 다시 확인 펜스가 읽기 실패 때 요청이 나갔다고 말하지 않음 | 삭제 | RED |
| m10 | b2 | 「값의 출처」 거름을 뗌(두 호출 모두) | 삭제 | RED |
| m10a | b2 | interview_dir 호출만 거르지 않음 | 삭제 | RED |
| m10b | b2 | roadmaps_dir 호출만 거르지 않음 | 삭제 | RED |
| m11 | b2 | 거름이 stderr 전체를 버림 | 삭제 | RED |
| m11a | b2 | 거름이 [spec-distill] 줄을 모두 뺌 | 형태 | RED |
| m11b | b2 | 거름이 남은 줄을 stdout 으로 냄 | 형태 | RED |
| m11c | b2 | 거름이 뒤집힘(그 줄만 남김) | 반전 | RED |
| m12 | b2 | 거름이 종료 코드를 삼킴(늘 0) | 형태 | RED |
| m12a | b2 | 거름이 늘 실패로 돌려줌 | 반전 | RED |
| m12b | b2 | 임시 파일 실패 때 판정을 부르지 않고 통과 | 삭제 | RED |
| m12c | b2 | 임시 파일 실패 때 종료 코드를 삼킴 | 형태 | RED |
| m12d | b2 | 임시 파일을 지우지 않음 | 삭제 | RED |
| m12e | b2 | 임시 파일 실패 때 멈춤(그대로 돌지 않음) | 형태 | RED |
| t1 | b1 | 절 머리 문장을 옛 글로 | 반전 | RED |
| t2 | b1 | 3 걸음 문장을 옛 글로 | 반전 | RED |
| t3 | b1 | 다시 확인 문단을 뗌 | 삭제 | RED |
| t4 | b1 | 다시 확인 펜스의 가드 줄이 다름(cwd 로 물러남) | 형태 | RED |
