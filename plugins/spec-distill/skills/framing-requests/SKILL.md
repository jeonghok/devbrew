---
name: framing-requests
description: >
  Phase 0 회의 skill. `/request-framing` 이 trivia escape 를 통과시킨 요청을 받아
  확산(원문 보존 → 레포 읽기 → 질문 라운드) 후 압축해, 새 세션 첫 턴의
  `/interview @<seed 경로>` 가 가리키는 `interview-seed` 파일을 만든다. 산출물은 문서가
  아니라 다음 세션의 첫 턴이다.
cost_class: variable
---

# Framing Requests — Phase 0

당신은 파이프라인 맨 앞의 **회의**를 진행 중입니다. 산출물은 문서가 아니라 **새 세션의 첫
턴 `/interview @<seed 경로>` 가 가리키는 파일**입니다. 그 첫 턴이 어떤 모양인지는 `## 확정 — proceed 게이트`
의 「호출 모양」 절 한 곳이 정합니다 — 다른 절은 그것을 다시 정하지 않고 가리킵니다.

**진입 선결조건** — `/request-framing` command 가 trivia escape 를 통과시킨 요청만 이
skill 에 옵니다. 5패턴 정의는 `${CLAUDE_PLUGIN_ROOT}/references/trivia-escape.md`.
**검사는 command 가 합니다** — 이 skill 은 그 정의를 인용할 뿐 다시 검사하지 않습니다.

## 무엇을 남기고 무엇을 깎는가

압축 규약 정본은 `${CLAUDE_PLUGIN_ROOT}/references/compression.md` 입니다.

**불변량은 넷** — **의도 · steering · 방향 · goal**, 그리고 그 넷을 지탱하는 사실 중
에이전트가 알 수 없는 것.

**방식은 확산 후 압축** — 긴 초안을 먼저 쓰고 **그 다음 깎습니다.** 처음부터 짧게 쓰지
않습니다. 크게 그린 다음 깎아낸 것이 처음부터 짧게 쓴 것보다 더 많은 것을 고려합니다.
긴 초안은 `$AUDIT` 의 `## 3. 긴 초안` 절에 남고, **seed 로 나가는 것은 깎은 것뿐**입니다
(`## 상태` 표에 그 행이 있습니다). 세션 state 에 두지 않는 이유는 TTL-GC 가 기본 24시간에
그 폴더를 통째로 걷기 때문입니다 — 압축이 무엇을 떨어뜨렸는지는 그보다 오래 남아야 합니다.

### 확정 표시와 «다시 검증할 것»

seed 는 태그를 쓰지 않습니다(`check_seed.py` 가 본문 태그를 금지하고, 슬롯 존재 검사 추가는
`tests/test_seed_one_sentence.sh` 가 막습니다). 대신 산문 규약 셋으로 Phase 1 이 무엇을 다시 물을지
가릅니다:

- **확정 표시는 «(사용자 확인)» 하나.** `## 확산` 의 확인 질문에서 사용자가 **고른** 풀이에만 붙고,
  그 풀이 문장이 압축을 지나 **글자 그대로**(공백만 다를 수 있다) seed 에 남았을 때만 따라갑니다 —
  압축이 그 문장을 손대면 표시는 떨어지고 문장은 미확인으로 돌아갑니다
  (`${CLAUDE_PLUGIN_ROOT}/references/compression.md`). 이 표시가 붙은 문장만 Phase 1 이 재확인 질문에서
  제외합니다. brief §2 로 옮겨질 때 `source: verbatim`, ✎ 에 «Phase 0 확인».
- **마지막 문단은 «다시 검증할 것 —»로 시작**해, Phase 0 이 추론·외부·열린 것으로 아는 항목을 산문으로
  나열합니다. 예: «다시 검증할 것 — 종료 술어가 이벤트 완료라는 것은 Phase 0 이 구현을 읽고 본 원인
  후보이지 확정이 아니다. …». Phase 1 은 이 문단을 R1 의 «지금 이해»·질문의 재료와 coverage-mapper 첫
  dispatch 의 입력으로 씁니다.
- **그 밖의 모든 문장은 미확인**입니다. 필요하면 Phase 1 이 질문으로 검증합니다.

문단이 없어도 깨지지 않습니다 — 지금과 같은, 태그를 쓰지 않는 산문으로 떨어질 뿐이고, 냉독
(seed-readback)이 **그 문단의 부재**를 사람에게 보입니다. **마커 오용**(추론 문장에
«(사용자 확인)» 을 잘못 붙이는 것 — 사용자 결정처럼 표현된 모델 자신의 추론)은 냉독의 몫이
아닙니다: `seed-readback` 은 `<seed>` 하나만 받고 원문·`CLAUDE.md` 와 대조할 근거가 없어
자기 정의에 «판정·점수·개선 무엇도 하지 마세요»가 못 박혀 있습니다. 그것을 잡는 것은 두 겹입니다 —
기계는 `seed_provenance.py marks` 가 확인 질문 기록과 대조해 `## 검증` 에서 근거 없는 표시를 떼고
`## 확정` 직전에 다시 검사하며, 리뷰 엔진의 탐지 리뷰어는 seed 프로필 층 1 의
`inference_as_decision`(«모델의 추론이 사용자의 결정처럼 쓰임»)으로 표시 없는 문장까지 봅니다.

## 워크트리 — 진입 직후

이 skill 에 들어온 **첫 행동**이다(빈 요청일 때만 아래 주제 질문 하나가 앞선다) — `## 확산` 1번(audit
첫 write) **전**에 묻는다. 그래야 audit 이 처음부터 워크트리 안에 쓰이고 «main 에 쓴 audit 을 옮기는»
절차가 필요 없다. 이름 파일(`interview-basename`)은 세션 디렉토리(main repo 의 state root)에 있어
cwd 이동과 무관하다.

**요청이 비어 있으면 이 질문보다 먼저** 「무엇을 맡기려 하시나요」로 주제부터 묻는다 — 워크트리
이름(`feature/<kebab-topic>`)도 audit 이름(`## 상태` 의 `TOPIC`)도 요청의 주제에서 나오는데 빈
요청에는 주제가 없다. 답으로도 주제를 못 대면 좁혀 다시 묻는다. 주제가 정해지면 아래로 간다.
워크트리 질문을 건너뛰는 경우도 같다 — audit 이름에 주제가 필요하다. 그 답들은 audit 보다 먼저 온
원문이므로 `## 확산` 1번에서 `## 1. 원문` 의 **첫 항목**부터 요약 없이 옮긴다.

`DEVBREW_SPEC_DISTILL_DISABLE_WORKTREE=1` 이거나 `EnterWorktree` 도구가 없으면 **묻지 않고** 현재
디렉토리에서 진행한다. 그 밖에는 **질문을 띄우기 전에** 로컬 전용 커밋 여부부터 확인한다 —
기본 base 가 origin 의 기본 브랜치라 push 안 한 로컬 커밋은 새 워크트리에 안 들어오는데, 그
사실을 질문 **뒤**에 적으면 사용자는 이미 고른 뒤에야 안다(사용자가 실제로 읽는 것은
질문·옵션 텍스트뿐이다):

**기준은 워크트리가 실제로 쓰는 base 다** — `EnterWorktree` 의 기본(`worktree.baseRef=fresh`)은
origin 의 **기본 브랜치**이므로, 재야 할 것은 「HEAD 에 있는데 `origin/<기본>` 에 없는 커밋」이다.
tracking branch(`@{u}`)를 재면 **자기 remote 를 추적하는 브랜치가 0 을 보고하면서 실제로는
`origin/main` 과 발산해 있을 수 있다** — push 를 마쳤어도 그 커밋들은 새 워크트리에 안 들어온다.
그러면 경고가 0 건으로 뜨고 워크트리가 조용히 커밋을 빠뜨린다. 그래서 base 를 도출해서 잰다:

```bash
base="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"
if [ -z "$base" ]; then
  for cand in origin/main origin/master; do
    if git rev-parse --verify --quiet "$cand" >/dev/null 2>&1; then base="$cand"; break; fi
  done
fi
if [ -n "$base" ]; then
  local_only_n="$(git rev-list --count "$base"..HEAD 2>/dev/null)"
else
  local_only_n=""
fi
if [ -z "$base" ] || ! [[ "$local_only_n" =~ ^[0-9]+$ ]]; then
  LOCAL_ONLY_NOTE="확인 못함 — origin 기본 브랜치를 못 찾았거나 git rev-list 실패(사유 불명)"
elif [ "$local_only_n" -gt 0 ]; then
  LOCAL_ONLY_NOTE="$base 에 없는 커밋 ${local_only_n}개 — 워크트리 기본 base 엔 안 들어온다"
else
  LOCAL_ONLY_NOTE="$base 에 없는 커밋 0개"
fi
echo "$LOCAL_ONLY_NOTE"
```

origin 의 기본 브랜치를 못 찾는 환경(원격 미설정 · `origin/HEAD` 미설정 + main/master 둘 다 부재)
에서도 이 블록은 죽지 않는다 — `rev-list` 를 아예 돌리지 않고 **«확인 못함»**으로 떨어진다.
**빈 값과 0 은 다른 사실이다** — 확인에 실패하거나 base 를 못 찾아서 못 잰 것을 0건으로 읽으면
이 풋건이 그대로 재현된다(명령 실패 시 `local_only_n` 은 빈 문자열이라 숫자 정규식에 걸리지
않고 «확인 못함» 으로만 떨어진다).

`origin/<기본>` 은 마지막 fetch 시점의 값이다 — 여기서 fetch 하지 않는다(네트워크는 이 절의
책임이 아니다). stale 하면 **더 많이** 세는 쪽으로 틀리므로 경고가 과해질 뿐 빠지지 않는다.
`worktree.baseRef=head` 로 바꾼 사용자에게는 이 경고가 무해한 과다 경고다 — 그 설정에서는
base 가 로컬 HEAD 라 아무것도 안 빠진다.

`${LOCAL_ONLY_NOTE}` 를 질문 본문과 «만들고 시작» 옵션 설명에 그대로 실어 단독
`AskUserQuestion` 하나를 띄운다:

```javascript
AskUserQuestion({ questions: [{
  header: "워크트리",
  question: "`feature/<kebab-topic>` 워크트리를 만들고 거기서 시작할까요? 이 브랜치 하나에서 인터뷰·설계·계획·구현까지 갑니다. (${LOCAL_ONLY_NOTE}) 거절하면 현재 디렉토리에서 진행합니다.",
  options: [
    {label: "만들고 시작 (권장)", description: "고르면 이 세션의 cwd 가 그 워크트리로 옮겨지고 audit·seed 가 그 안에 쓰인다. ${LOCAL_ONLY_NOTE}"},
    {label: "현재 디렉토리에서", description: "고르면 워크트리 없이 지금 위치에 쓴다 — 자료는 현재 브랜치에 남는다"}],
  multiSelect: false }] })
```

승낙 시 절차 — 순서 고정, **각 단계는 단순 명령 하나**(격리 세션의 git 가드가 복합 명령을 막는다):

1. `EnterWorktree(name=<kebab-topic>)` — native 도구 우선(superpowers `using-git-worktrees` 와 같은 원칙). 실측(v6): 요청한 이름 그대로가 아니라 `worktree-` 접두가 붙은 브랜치가 된다 — 그래서 2단계의 rename 이 항상 필요하다.
2. `git branch -m feature/<kebab-topic>` — project-init 검증기가 제안하는 바로 그 형태. 실측(v6): rename 은 거부되지 않았다.
3. audit·seed 를 그 워크트리 안의 `docs/superpowers/interview/` 에 쓴다(`## 상태` 의 경로 그대로).
4. proceed 게이트에서 ①/② 를 고르면 **handoff 직전** 커밋 1회(`## 확정 — proceed 게이트` 의 절차).
5. 게이트 텍스트의 «다음 세션 첫 턴» 안내에 워크트리 **절대경로**를 함께 낸다 — 다른 터미널에서 새 세션을
   열 때 그 디렉토리에서 열어야 `/interview @<seed 경로>` 가 그 파일을 찾는다.

거절·도구 부재·스위치 → 현재 디렉토리에서 진행하고, audit §5 에 «워크트리 없음 — <거절|EnterWorktree 부재|
DEVBREW_SPEC_DISTILL_DISABLE_WORKTREE>» 한 줄을 남기며, 어느 경우도 seed 작성을 막지 않는다.

**자동으로 `worktree.baseRef=head` 로 바꾸지 않는 이유** — 위 확인이 이미 질문 시점에
로컬 전용 커밋 여부를 사용자에게 보였으므로(v6 실측: 기본 base 는 origin 의 기본
브랜치라 로컬에만 있는 커밋은 들어오지 않는다), 그 커밋이 이번 워크트리에 정말
필요한지는 사용자 판단으로 남긴다 — 무조건 `head` 로 바꾸면 반대 방향의 놀람(불필요한
커밋까지 딸려 온다)이 생긴다. 필요하면 사용자 설정 `worktree.baseRef=head` 로 로컬
HEAD 기준으로 바꾼다.

이 절은 **실측한 것**(브랜치명 접두 · rename 무거부 · base-ref 기본값)만 단정하고,
**실측 밖**(슬래시 포함 이름의 결과 · 사람의 정상 종료 후 워크트리 정리)은 단정하지
않는다 — 실측 결과는 CHANGELOG `[0.57.0]` 에 있다.

## 확산

1. **원문 보존** — 사용자가 준 원문(요청·생각·대화 로그·자료)을 **`$AUDIT` 파일의
   `## 1. 원문` 절**에 그대로 옮겨 적습니다(append-only — 이후 라운드의 원문도 요약하지
   않고 계속 덧붙입니다). `$AUDIT` 경로와 이 skill 이 **무엇을 만들고 무엇을 만들지
   않는지**는 `## 상태` 한 곳에 있습니다 — 여기서 다시 세지 않습니다. 지금 요약하지 않습니다 —
   압축은 나중 단계이고, 지금 요약하면 압축이 무엇을 떨어뜨렸는지 audit 이 못 남깁니다.
   `## 1. 원문` 이라는 헤딩은 장식이 아닙니다: `build_seed_inline_blob.py` 가 그 절을
   다음 audit 절 제목까지 잘라 리뷰 번들에 싣고, seed 프로필이 그 절을 정답 출처로 선언합니다.
2. **레포 읽기** — 관련 코드 · `CLAUDE.md` · `AGENTS.md` · 기존 설계 문서를 읽습니다.
   다음 세션이 이미 아는 것(상시 규칙)은 압축 단계에서 깎일 대상이므로 지금 확인해 둡니다.
3. **질문을 한꺼번에** — 라운드마다 질문 하나씩 흩뿌리지 않고, 그 라운드에 필요한
   질문을 모아서 한 번에 묻습니다.
4. **부분 답 → 새 질문** — 사용자가 부분적으로만 답하면 남은 공백을 다음 라운드 질문으로
   좁혀 다시 묻습니다.

매 라운드는 **세 블록**으로 사용자에게 보고합니다 — 지금 이해한 작업 / 아직 안 잡힌 것 / 질문.
앞 라운드의 답을 어떻게 읽었는지는 블록으로 공시하지 않고 **묻습니다**(아래 `### 확인 질문`) —
공시는 무응답으로 지나갈 수 있지만 질문은 그럴 수 없습니다.

**질문에도 라운드에도 분량에도 상한이 없습니다.** 질문 루프는 매 반복마다 사용자가
답해야 돌고 사용자가 그 루프의 시계입니다 — 자율이 없으므로 묶을 자율도 없습니다.

### 확인 질문 — 라운드마다 하나

앞 라운드의 답을 저자가 풀어 쓴 문장(이하 «풀이»)은 사용자가 **골라야** 확인이 됩니다. 그 라운드의
질문과 **같은 `AskUserQuestion` 호출**에 확인 질문을 하나 더 싣습니다 — 풀이마다 선택지 하나이고,
선택지 설명에 세 줄을 나란히 둡니다: 그 답을 끌어낸 질문 문구 · 사용자가 한 말 · 저자의 풀이.

```javascript
AskUserQuestion({ questions: [
  /* 이 라운드의 질문들 */
  { header: "풀이 확인",
    question: "제가 이렇게 읽었습니다. 맞는 것을 고르세요. (고르지 않은 것은 미확인으로 남습니다)",
    multiSelect: true,
    options: [
      {label: "풀이 1", description: "내가 물은 것 「<질문 문구>」 · 당신이 답한 것 「<사용자가 한 말>」 · 내가 읽은 것 「<풀이 문장>」"},
      {label: "풀이 2", description: "내가 물은 것 「…」 · 당신이 답한 것 「…」 · 내가 읽은 것 「…」"} ] } ] })
```

- **고른 풀이만 확인이다.** 고르지 않은 것 · «기타» 로 다른 말을 적은 것 · 답하지 않은 질문의 풀이는
  전부 미확인이다. «(사용자 확인)» 표시는 이 선택에서만 나온다.
- **풀이는 한 문장으로 쓴다.** 여러 문장이면 seed 에 남긴 문장마다 «(사용자 확인)» 을 따로 붙인다 —
  확인 대조는 문장 단위다.
- **한 질문의 선택지는 2~4개다**(도구 스키마). 풀이를 넷씩 나눠 확인 질문을 여럿 싣되(한 호출에 질문
  넷까지 — 넘치면 다음 호출), **선택지가 하나만 남는 질문은 만들지 않는다** — 넷씩 나누다 하나가
  남으면 마지막 두 질문을 둘 이상씩으로 나눈다(예: 5 → 3+2). **나뉜 질문 전부에 답해야** 그 라운드의
  확인이 끝난다.
- **한 질문에 풀이가 하나뿐이면** 단일 선택 「맞다 / 아니다」로 묻고, 세 줄(질문 문구 · 당신이 답한
  것 · 내가 읽은 것)은 **질문 텍스트**에 싣는다. 「맞다」는 audit `## 2` 에 `— 고름`, 「아니다」는
  `— 고르지 않음` 으로 적는다.
- 문장마다 질문을 만들지 않는다 — 라운드당 확인 질문은 하나(넘칠 때만 나뉜다)이고, 그 라운드의
  질문과 같은 호출에 가되 합쳐 넷을 넘으면 넘는 확인 질문은 다음 호출로 간다.
- **압축 전에** 아직 묻지 않은 풀이가 남았으면 그것만으로 확인 질문을 한 번 더 띄운다. 묻지 않은 풀이를
  안고 압축에 들어가지 않는다.
- 풀이가 없는 라운드는 확인 질문을 싣지 않는다.

**기록** — 질문 · 선택지 · 답 · 확인 결과를 `$AUDIT` 의 `## 2. 질문 전체` 에 라운드마다 템플릿의 줄 모양
그대로 남깁니다(`${CLAUDE_PLUGIN_ROOT}/templates/interview-seed-audit-template.md`). 줄 모양이 계약입니다 —
«당신이 답한 것» 줄은 리뷰의 정답 출처이고(seed 프로필 `ground_truth`), `- 내가 읽은 것: 「…」 — 고름`
줄은 `seed_provenance.py marks` 가 «(사용자 확인)» 의 근거로 읽습니다.

**남는 한계** — «내가 풀어 썼는가»의 판정은 여전히 저자가 합니다. 저자가 풀어 쓴 줄 모르는 문장은 확인
질문에 오르지 않습니다. 그 잔여는 리뷰 엔진의 탐지 리뷰어가 층 1 `inference_as_decision` 으로 봅니다 —
두 장치는 다른 실패를 막고, 하나가 다른 하나를 대신하지 않습니다.

### 탐색 경계 — 레포는 읽되 웹은 보지 않습니다

**이 단계는 레포는 읽되 웹은 보지 않습니다** (does not — cannot 이 아닙니다. skill 계층에는
도구를 막을 수단이 없고, `allowed-tools` 는 제한이 아닙니다. 이 경계를 지키는 것은 이 문장과
그것을 읽는 쪽입니다). framing 의 공백은 바깥에서 찾지 않고 **사용자에게 물어서** 메웁니다.

바깥에서 찾는 것은 다음 단계(interview)의 R&R 입니다 — landscape · steelman · blind-spot
premortem · coverage-mapper 넷이 거기 있는 장치이고, 이 skill 에는 그 넷 중 아무것도
없습니다. **질문 라우팅**: 답을 사용자만 알 수 있으면 여기서 묻고, 사용자 밖에서 찾아야
하면 다음 단계로 넘깁니다. 같은 주제도 이 기준으로 갈립니다.

이 경계는 소비자 쪽(`conducting-interview` 의 R2 「탐색 경계」)에도 같은 문장으로 적혀
있습니다. 두 곳에 있는 이유는 중복이 아니라 **제약당하는 쪽이 그 제약을 받은 적이 있어야**
하기 때문입니다 — 한 skill 이 다른 skill 에 대해서만 적어 두면, 제약당하는 쪽을 고치는
사람은 그것을 읽지 않습니다.

**언젠가 이 단계에 웹 탐색을 더한다면**, 그 자리에서 kill switch
`DEVBREW_SPEC_DISTILL_DISABLE_WEB` 를 **매 호출 직전에** 확인해야 합니다(세션 시작에
캐시하지 않습니다). 지금 이 skill 의 `## kill switch` 목록에 그 스위치가 없는 이유는
탐색이 없기 때문이지 면제받아서가 아닙니다 — 없는 스위치를 미리 적으면 죽은 스위치가
산 것으로 읽힙니다.

## 상태

**이 skill 이 만드는 것의 전부입니다** — 다른 절은 이 목록을 다시 세지 않습니다.

| 만드는 것 | 어디에 | 언제 |
|---|---|---|
| audit (`$AUDIT`) | `docs/superpowers/interview/` | `## 확산` 1번부터 — 덧붙이기(예외 둘: `## 1` 의 인용 감싸기 · `## 2` 의 어긋난 풀이 줄 제자리 수정) |
| 긴 초안 | `$AUDIT` 의 `## 3. 긴 초안` 절 | 압축 **직전** — 깎기 전에 여기 먼저 쓴다 |
| interview-seed (`$SEED`) | 〃 | 압축 직후 — **게이트 직전 구조 검사보다 먼저** |
| 두 문서의 이름을 붙드는 `interview-basename` | 아래 `$SEED_DIR` | 아래 블록에서 `TOPIC` 자리표가 실값으로 치환된 실행 — 자리표가 그대로면 만들지 않는다 |
| 세션 디렉토리 `$SEED_DIR` 자체 | `.claude/spec-distill/<session-id>/` | `sid` 가 실값이고 `mkdir` 이 성공했을 때만 — 실패하면 이름 파일을 아예 만들지 않는다 |
| 리뷰 엔진 자리 `$STATE_DIR` — 엔진 원장 · 번들 둘(`$BUNDLE` · `$BUNDLE_RC`) · 리뷰어 산출물(`critic.txt` · `recritic.txt` · `$CODEX_YAML`) · 저자 편집 기준 사본(`$SEED_BASE`) | `$SEED_DIR/docreview/<seed 이름>-<해시>/` | 리뷰 라운드마다 — 경로는 seed 의 절대경로와 세션의 순수 함수다 |

**audit 과 seed 는 시점이 다르지만, 둘 다 승인 «전»에 디스크에 있어야 합니다.** audit 은
확산 첫 항목부터, seed 는 압축 직후입니다 — 게이트 직전의 `check_seed.py` 가 둘 다
디스크에서 읽고, proceed 게이트 공통 계약의 Step A 도 대상 문서가 working-tree 에 없으면
게이트를 **띄우지 않습니다**. 승인 이후에 일어나는 것은 파일 쓰기가 아니라 **handoff**
입니다 — 다음 세션의 첫 턴이 `/interview @<seed 경로>` 로 seed 파일을 가리키는 것이고, 그 턴의 모양은
`## 확정 — proceed 게이트` 의 「호출 모양」 절이 정합니다.

**만들지 않는 것: `state.local.md`.** degrade 원장은 그 **기존** 파일 안에 살고, 없으면
없는 채로 갑니다(§`degrade 채널` 의 `no-state-in-phase-0`).

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
sid="$(python3 "$SD/scripts/state_path.py" session-id)" || sid=""
ROOT="$(python3 "$SD/scripts/state_path.py" state-root)"
STATE="$ROOT/$sid/state.local.md"
# 세션 디렉토리 — 이름 파일과 리뷰 엔진 자리가 그 아래 산다. 경로는 **세션의 순수 함수**여야 한다 —
# 어느 블록이 언제 재도출해도 같은 파일을 가리켜야 하기 때문이다. `mktemp` 은 `$$`(PID) 와 **같은
# 결함**이다: Bash 도구는 호출마다 새 셸이라 그 값이 소멸하고 **재발견이 불가능**하다.
# 세션 «디렉토리»는 만들어도 된다 — state.local.md 를 만드는 것과 다른 일이다.
#
# **가드가 하나인 것이 요점이다.** `sid` 가 실값이고 `mkdir` 이 성공한 경우에만 이름 파일 경로가
# 생긴다. `state_path.py` 는 GC 의 세션 이름 필터와 **같은 정규식**을 통과한 값만 stdout 으로
# 내주므로(안 통과하면 exit 1 + 빈 stdout), 이 한 조건이 «플러그인 네임스페이스 안»과 «TTL-GC
# 사정거리 안»을 동시에 보장한다. 네임스페이스 밖으로 나가는 fallback 을 두지 않는 이유가 그것이다:
# `/tmp` 로 새면 두 보장이 함께 깨지고, 그 파일들은 사용자의 원문을 담은 채 아무도 걷지 않는 자리에 남는다.
SEED_DIR=""
[ -n "$sid" ] && mkdir -p "$ROOT/$sid" 2>/dev/null && SEED_DIR="$ROOT/$sid"
NAME_FILE=""
if [ -n "$SEED_DIR" ]; then
  NAME_FILE="$SEED_DIR/interview-basename"
else
  echo "[spec-distill] 세션 디렉토리를 못 만들었다 (sid='${sid:-}' ROOT='$ROOT') — 이름 파일을 만들지 않는다. 플러그인 네임스페이스 밖에는 쓰지 않기 때문이다. 아래 가드들이 이름을 대고 멈춘다." >&2
fi
# 두 산출 문서. 이름은 **첫 라운드에 한 번** 정하고 이후 라운드는 되찾는다 — 그래서
# 이 블록을 다시 돌리면 같은 두 경로가 나온다. 이름을 기억에서 다시 대는 판본은
# `mktemp` 과 같은 결함이다: 다음 셸이 같은 값을 다시 만들 수 있어야 한다.
# `TOPIC` 을 요청의 주제(공백 없는 kebab-case)로 바꿔 쓴다 — 공백이 든 이름은 아래 가드가
# 거부한다(seed 경로가 한 토큰이어야 `/interview` 가 `@경로` 로 푼다). **바꾸기 전에는 이름을 고정하지
# 않는다** — 고정해 버리면 자리표가 파일명에 박히고, 그 뒤로는 「이 블록을 다시
# 돌려라」가 바로 그 박제를 되풀이하는 행동이 된다.
TOPIC="<kebab-topic>"
case "$TOPIC" in
  ""|*"<"*|*">"*|*/*|*[[:space:]]*) : ;;
  *) [ -n "$NAME_FILE" ] && { [ -s "$NAME_FILE" ] || printf '%s-%s-interview\n' "$(date +%F)" "$TOPIC" > "$NAME_FILE"; } ;;
esac
# 이름이 성하지 않으면 두 경로를 **만들지 않는다.** 반쯤 만들어진 경로
# (`docs/superpowers/interview/.audit.md`)는 아래 가드들의 `-z` 검사를 통과해 조용히
# 틀린 파일을 가리킨다 — 시끄럽게 틀리는 것보다 그쪽이 나쁘다. 비워 두면 가드가
# 이름을 대고 멈춘다.
AUDIT=""
SEED=""
IV_NAME=""
[ -n "$NAME_FILE" ] && IV_NAME="$(head -n 1 "$NAME_FILE" 2>/dev/null)"
case "$IV_NAME" in
  ""|*/*|*"<"*|*">"*|*[[:space:]]*)
    echo "[spec-distill] 인터뷰 문서 이름을 못 구했다 (IV_NAME='$IV_NAME' NAME_FILE='$NAME_FILE'). NAME_FILE 이 비었으면 원인은 위 세션 디렉토리이고 그쪽 advisory 를 보라. 비어 있지 않으면 이 블록의 TOPIC 을 요청 주제(공백 없는 kebab-case)로 바꿔 다시 돌려라. 자리표가 이미 이름에 박혔으면 rm -f '$NAME_FILE' 로 지운 뒤 다시 돌려라 — 그 파일이 이름의 유일한 출처이므로 지우면 되돌아간다." >&2 ;;
  *)
    AUDIT="docs/superpowers/interview/$IV_NAME.audit.md"
    SEED="docs/superpowers/interview/$IV_NAME.md" ;;
esac
# 리뷰 엔진 자리 — 전부 seed 의 **절대경로**와 세션의 순수 함수다(`state-dir-for`). 엔진은 상대
# `--doc` 을 거부한다(`doc_not_absolute`). seed 이름이 서기 전이면 전부 빈 값이고, 아래 펜스들이
# 그 사실을 이름으로 대고 멈춘다.
SEED_ABS=""; AUDIT_ABS=""; STATE_DIR=""
if [ -n "$SEED" ]; then
  SEED_ABS="$(pwd)/$SEED"; AUDIT_ABS="$(pwd)/$AUDIT"
  [ -z "$sid" ] || STATE_DIR="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$ROOT" --session "$sid" --doc "$SEED_ABS" || true)"
fi
PROFILE="${CLAUDE_PLUGIN_ROOT}/references/docreview-profiles/seed.md"
BUNDLE="${STATE_DIR:+$STATE_DIR/seed-bundle.md}"                 # 탐지 · codex 가 읽는 번들
BUNDLE_RC="${STATE_DIR:+$STATE_DIR/seed-bundle-recritic.md}"     # 재비판자가 읽는 번들 — 판정 이력 없음
CODEX_YAML="${STATE_DIR:+$STATE_DIR/docreview-codex.yaml}"       # 4단계 산출물
SEED_BASE="${STATE_DIR:+$STATE_DIR/seed-baseline.md}"            # 저자 편집 공시의 기준 사본
if [ -n "$sid" ] && [ -f "$STATE" ]; then
  python3 "$SD/scripts/brief_review_state.py" init "$STATE" --ledger-key framing_degradations; ledger_rc=$?
else
  ledger_rc=1
fi
```

**이 블록이 경로의 유일한 도출 지점입니다.** `$SD`·`$sid`·`$ROOT`·`$STATE`·`$SEED_DIR`·`$AUDIT`·`$SEED`·
`$SEED_ABS`·`$AUDIT_ABS`·`$STATE_DIR`·`$PROFILE`·`$BUNDLE`·`$BUNDLE_RC`·`$CODEX_YAML`·`$SEED_BASE` 는 전부
환경과 `$SEED_DIR` 의 순수 함수이므로, 셸이 바뀌었으면 **이 블록을 다시 돌려** 같은 값을 얻습니다. 아래 어느
블록도 이 값들을 새로 만들지 않습니다 — `mktemp` 으로 만들면 다음 `Bash` 호출이 그 파일을 다시 찾지 못합니다.

**실행 모양 — 아래 펜스들은 이 블록과 «같은 `Bash` 호출» 안에서 돕니다.** 이 블록을 그 펜스 **앞에 그대로
이어 붙여** 한 번에 넘깁니다. 펜스마다 따로 호출하는 것이 `Bash` 도구의 기본 동작이고, 그렇게 하면 이 블록이
대입한 값이 다음 호출에 **하나도 넘어가지 않습니다** — 넘어가는 것은 디스크의 파일뿐입니다. 값이 비면
`$STATE_DIR` · `$SEED` 가 빈 문자열이 되어 리뷰 라운드 전체와 냉독이 돌지 않습니다. 아래 가드들의 advisory 가
「먼저 돌려라」가 아니라 「앞에 이어 붙여라」라고 쓰는 이유가 그것입니다 — 별개 호출로 다시 돌리면 같은 빈
상태가 그대로 재생산됩니다.

`--ledger-key framing_degradations` 는 기본 원장 줄(`brief_review_degradations`)에 **더해** 이 원장 줄을 심습니다(치환이
아닙니다 — brief 파이프라인의 원장은 그대로 남습니다). 이 호출이 없으면 뒤의
`degrade-append` 가 「라인 부재」로 죽습니다 — 닫힌 열거에 이름이 있다는 것과 그 원장에
쓸 수 있다는 것은 다른 사실입니다.

`ledger_rc` 가 0 이 아니면 원장 없이 진행합니다. 그 처리는 `## degrade 채널` 에 있습니다.

## 검증

seed 는 공유 문서 리뷰 엔진으로 리뷰합니다. 한 라운드의 절차는 엔진 절차서가 갖고 있고, 여기 남는 것은
이 자리의 것 — 번들 · 프로필 · codex 게이트 · dispatch 둘 · 산출물 기록 · 게이트 · 냉독 — 뿐입니다. 경로는
전부 `## 상태` 블록이 도출하고, 아래 펜스는 전부 그 블록을 **앞에 이어 붙여 같은 `Bash` 호출 안에서** 돕니다.

엔진의 앵커 부류(`protected_headings` · `immutable`)는 seed 프로필에서 둘 다 비어 있습니다. seed 는 헤딩이
없어 앵커가 `#__doc__` 하나뿐이고 엔진의 보호는 앵커 단위라, 「이 자리는 막고 저 자리는 연다」가 성립하지
않습니다. 차단은 이 skill 이 집니다 — `### 게이트`.

### seed 를 쓴 직후 — 한 번, 첫 라운드 앞

압축이 seed 를 쓴 직후 두 가지를 합니다. 확인 질문에서 고른 풀이가 **글자 그대로** 남은 문장에만
«(사용자 확인)» 이 남도록 근거 없는 표시를 떼고, 저자 편집 공시의 기준 사본을 뜹니다.

```bash
if [ -z "${SEED_ABS:-}" ] || [ -z "${SEED_BASE:-}" ]; then
  echo "[spec-distill] seed 직후 검사 입력 부재 — SEED_ABS='${SEED_ABS:-}' SEED_BASE='${SEED_BASE:-}'. 「## 상태」 블록을 이 펜스 앞에 이어 붙여라. 리뷰 라운드를 시작하지 않는다." >&2
  exit 1
fi
mkdir -p "$STATE_DIR"
python3 "$SD/scripts/seed_provenance.py" marks "$SEED_ABS" "$AUDIT_ABS" --fix; marks_rc=$?
python3 "$SD/scripts/seed_edit_diff.py" init "$SEED_BASE" "$SEED_ABS"; base_rc=$?
echo "marks_rc=$marks_rc base_rc=$base_rc"
```

`marks` 의 출력이 뗀 표시를 문장째 댑니다 — 그 목록을 사용자에게 한 줄로 보입니다(「확인 뒤 압축이 고쳐
미확인으로 돌아간 문장」). `marks_rc` 가 0 이 아니거나 `base_rc` 가 0 이 아니면 `## degrade 채널` 의 해당 행을
남기고, 기준 사본이 없으면 저자 편집 공시가 rc 3 경로로 떨어진다는 사실을 게이트 텍스트에 싣습니다.

### 절차

```
Read ${CLAUDE_PLUGIN_ROOT}/references/reviewing-document.md
```

그 파일의 여덟 단계를 **한 턴 안에서** 돕니다. 절차를 여기 복사하지 않습니다. 이 자리의 슬롯:

- `--state-dir` = `$STATE_DIR` · `--profile` = `$PROFILE` · `--doc` = `$SEED_ABS`
- 탐지의 `<document>` = `$BUNDLE` 의 **내용** · codex 러너의 `<doc>` = `$BUNDLE` · 재비판의 `<document>` = `$BUNDLE_RC` 의 **내용**
- 탐지 출력은 `$STATE_DIR/critic.txt`, 재비판 출력은 `$STATE_DIR/recritic.txt` 로 요약 · 전사 없이 저장한다
- 결정 기록의 `--log-file` = `$AUDIT_ABS` — seed 프로필의 `decision_log` 이 audit 의 `## 6. 리뷰 결정` 을 가리킨다
- 추가 라운드를 여는 1단계는 사용자 문구를 `$STATE_DIR/said-extra-r<n>.txt` 에 쓰고
  `q="$(python3 "$SD/scripts/seed_review_log.py" one-line "$STATE_DIR/said-extra-r<n>.txt")"` 로 받아
  `begin-round … --extra-approval="$q"` 로 넘긴다 — 파일이 없으면 `q` 가 비고, 엔진은 빈 승인을 승인으로 치지
  않아 상한(rc 3)에서 멈춘다. 성공하면 그 파일을 지운다
- 선결 `init` 앞에 `mkdir -p "$STATE_DIR"`. `$STATE_DIR` 이 비었거나 `init` 이 rc ≠ 0 이면 이 라운드를 시작하지 않고 `## degrade 채널` 의 record 를 남긴다

라운드 수의 상한은 절차서의 `## 상한` 한 줄이 정본입니다 — 이 skill 은 그 숫자를 다시 적지 않습니다. 상한
뒤의 라운드는 사용자가 승인 게이트에서 자기 문구로 열어야만 돕니다.

### 번들 — 라운드마다, 1단계 앞에서

```bash
# 이번 라운드 번들 둘 — 탐지 · codex 가 읽는 것(`$BUNDLE`)과 재비판자가 읽는 것(`$BUNDLE_RC`). 한 라운드의
# 소비자 셋이 한 번의 조립에서 나온 바이트를 보고, 저자 수정 뒤 다음 라운드는 새 번들을 본다. 직전 라운드의
# 리뷰어 산출물도 여기서 치운다 — 이번 라운드에 안 쓰였으면 없는 것으로 보여야 audit 에 이번 것으로 옮겨지지
# 않는다. 조립이 실패하면 번들도 남기지 않는다 — 남으면 codex 게이트가 그것을 이번 번들로 넘긴다.
if [ -z "${STATE_DIR:-}" ] || ! mkdir -p "$STATE_DIR" 2>/dev/null; then
  echo "[spec-distill] 리뷰 엔진 자리 없음 — STATE_DIR='${STATE_DIR:-}' sid='${sid:-}' SEED='${SEED:-}'. 「## 상태」 블록을 이 펜스 앞에 이어 붙여 같은 Bash 호출 안에서 함께 돌려라. 이 라운드를 시작하지 않는다." >&2
  bundle_rc=2
else
  rm -f "$STATE_DIR/critic.txt" "$STATE_DIR/recritic.txt" 2>/dev/null || true
  bundle_rc=0
  python3 "$SD/scripts/build_seed_inline_blob.py" "$SEED_ABS" "$AUDIT_ABS" CLAUDE.md --for detect > "$BUNDLE" || bundle_rc=1
  python3 "$SD/scripts/build_seed_inline_blob.py" "$SEED_ABS" "$AUDIT_ABS" CLAUDE.md --for recritic > "$BUNDLE_RC" || bundle_rc=1
  if [ "$bundle_rc" -ne 0 ]; then
    rm -f "$BUNDLE" "$BUNDLE_RC" 2>/dev/null || true
    for f in "$BUNDLE" "$BUNDLE_RC"; do [ ! -e "$f" ] || : > "$f" 2>/dev/null || true; done
    echo "[spec-distill] 번들 조립 실패 — 두 번들을 치웠다(못 지우면 비웠다). 이 라운드를 시작하지 않는다." >&2
  fi
fi
```

`bundle_rc` 가 0 이 아니면 이 라운드를 시작하지 않습니다(record 는 `## degrade 채널`). 원문 없이 억제를
물으면 「억제 없음」이 공허하게 나옵니다.

이 펜스가 stderr 로 낸 `[spec-distill]` 줄은 그 라운드 게이트 공시(첫 질문의 텍스트)에 글자 그대로 싣습니다 — `bundle_rc` 가 0 이 아니면 위 degrade 경로를 따릅니다.
`### codex` 펜스가 낸 `[spec-distill]` 줄도 같습니다 — 엔진은 codex 산출물이 없었다는 것만 알고(`yaml_missing_or_broken`), 왜 없었는지(스위치 · 미설치 · 감지기 · 입력 부재 · 잔존물 · 러너 산출물 기록 실패)는 그 줄만 압니다.

**audit 템플릿 절 제목이 중복되면** — stderr 가 템플릿 제목이 여러 번 나온다고 대면(조립기의 「… 가 N번(줄 …)
나온다」 · `marks` 의 `duplicate_heading`) 사용자가 붙여 넣은 원문에 그 제목과 같은 줄이 있는 것이고, 손대지
않으면 매 라운드 같은 자리에서 막힙니다. 단독 `AskUserQuestion` 으로 「멈춘다 / 그 줄만 인용 표시로 감싼다」를
묻습니다. 「감싼다」면 audit `## 1. 원문` 안의 그 줄(들) 맨 앞에 `> ` 만 붙이고 나머지 글자는 그대로 둡니다 —
`## 1` append-only 의 유일한 예외입니다. 그 선택과 사용자 문구를 audit `## 5. degrade` 에 한 줄로 남기고
`### 번들` 부터 다시 돕니다.

### 프로필 내용 — 탐지 dispatch 직전마다

```bash
# 리뷰어의 `<profile>` 슬롯에는 경로가 아니라 **내용**을 싣는다 — 플러그인 캐시는 사용자 프로젝트 밖이라
# 리뷰어의 Read 가 거부된다. rc 가 0 이 아니면 dispatch 하지 않는다 — critic 출력 파일을 비워 5단계가
# critic 사망(재dispatch 1회 → 「미검증」)으로 읽게 한다.
prof_rc=0; PROFILE_TEXT="$(cat "$PROFILE")" || prof_rc=$?
if [ "$prof_rc" -ne 0 ] || [ -z "$PROFILE_TEXT" ]; then
  echo "[spec-distill] seed 프로필을 읽지 못했다(cat rc $prof_rc): ${PROFILE:-} — 탐지 · 재비판을 dispatch 하지 않는다." >&2
  if [ -n "${STATE_DIR:-}" ] && [ -d "$STATE_DIR" ]; then : > "$STATE_DIR/critic.txt" 2>/dev/null || true; fi
  exit 1
fi
printf '%s\n' "$PROFILE_TEXT"
```

### codex — 4단계

러너는 `DEVBREW_SPEC_DISTILL_DISABLE_CODEX` 를 스스로 보지 않습니다 — 게이트는 호출자 책임이고, 그 조건을
산문이 아니라 아래 펜스로 적습니다(kill switch 는 P21 보안 컨트롤이라 산문 조건은 「껐다고 믿게만」
만듭니다). seed 프로필은 `web: false` 라 러너가 codex 웹 검색을 켜지 않습니다.

<!-- codex-gate:begin runner=run_docreview_codex_reviewer.sh -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
PROFILE="${CLAUDE_PLUGIN_ROOT}/references/docreview-profiles/seed.md"
# 러너 인자는 프로필 · 탐지 번들 · 프로젝트 · 산출물이다. 번들과 산출물 경로는 `## 상태` 블록이 엔진
# 자리 안에 도출한다 — 이 펜스는 그것을 새로 만들지 않는다.
#
# (1) 직전 라운드 산출물을 먼저 치운다 — 가용성 판정보다 앞이다. 이 경로는 seed 마다 라운드마다 같은
#     파일이라, 남은 것은 `codex_failed: false` 를 달고 이번 라운드 판정처럼 읽힌다. codex 를 건너뛰는
#     라운드(kill switch · 미설치 · 감지기 부재 · 입력 부재)가 전부 그 잔존물을 남기지 않게 여기서 한다.
#     지우지 못하면 0바이트로 절단한다(하류가 fail-closed 로 읽는다). 둘 다 못 하면 codex 축을 끈다.
seed_codex_residue=""
wipe_target=""   # 스킬 본문의 위치 인자는 호출 인자로 치환된다 — 대상은 이름 있는 변수로 넘긴다
wipe_or_truncate() {   # wipe_target 을 지운다 — 못 지우면 절단 — 둘 다 못 하면 rc 1
  rm -f "$wipe_target" 2>/dev/null || true
  [ -e "$wipe_target" ] || return 0
  : > "$wipe_target" 2>/dev/null || true
  if [ -s "$wipe_target" ]; then return 1; fi
  return 0
}
if [ -n "${CODEX_YAML:-}" ]; then
  wipe_target="$CODEX_YAML"; wipe_or_truncate || seed_codex_residue="$CODEX_YAML"
elif [ -n "${sid:-}" ] && [ -n "${ROOT:-}" ]; then
  # seed 이름을 모르면 이 세션의 문서별 codex 산출물이 전부 후보다. 전제: 한 세션은 리뷰 라운드를
  # 동시에 둘 돌리지 않는다. 지우는 것은 codex 산출물 하나뿐 — 원장 · 번들은 그대로다.
  for y in "$ROOT/$sid"/docreview/*/docreview-codex.yaml; do
    [ -e "$y" ] || continue
    wipe_target="$y"; wipe_or_truncate || seed_codex_residue="${seed_codex_residue:+$seed_codex_residue }$y"
  done
fi
# (2) 가용성 — 감지기가 안 돈 것과 codex 가 없는 것을 가른다.
DETECT_OUT="$(bash "$SD/scripts/detect_codex.sh")" || true
codex_avail="$(printf '%s\n' "$DETECT_OUT" | sed -n 's/^codex_available: //p')"
skip_reason="$(printf '%s\n' "$DETECT_OUT" | sed -n 's/^skip_reason: //p')"
[ -n "$codex_avail" ] || skip_reason="detector_not_runnable"
# (3) 입력 — 산출물 경로가 비었거나 이번 라운드 탐지 번들이 없으면 러너를 부르지 않는다.
if [ -z "${CODEX_YAML:-}" ] || [ ! -s "${BUNDLE:-}" ]; then
  echo "[spec-distill] seed codex 게이트 입력 부재 — CODEX_YAML='${CODEX_YAML:-}' BUNDLE='${BUNDLE:-}'. 「## 상태」 블록을 이 펜스 앞에 이어 붙이고, 「### 번들」 이 이번 라운드 번들을 조립했는지 확인하라. 이 라운드의 codex 축은 없이 간다." >&2
  codex_avail=""; skip_reason="gate_inputs_missing"
fi
if [ -n "$seed_codex_residue" ]; then
  echo "[spec-distill] 직전 라운드 codex 산출물을 지우지도 비우지도 못했다: ${seed_codex_residue}. 이 라운드의 codex 축은 없이 간다 — 5단계의 --codex 에 이 경로를 넘기지 마라(이번 라운드 begin-round 가 rc 0 이었다면 prepare-recritic 이 그 파일을 codex_predates_round 로 읽지만, 그 전제가 없으면 직전 판정이 섭취된다)." >&2
  codex_avail=""; skip_reason="residue_unclearable"; CODEX_YAML=""
fi
# (4) 호출 — rc 3(러너가 산출물을 못 썼다)만 치운다. 다른 비0 rc 는 러너의 EXIT 트랩이 남긴 이번
#     라운드의 정직한 기록이라 남긴다.
if [ "$codex_avail" = "true" ]; then
  runner_rc=0
  bash "$SD/scripts/run_docreview_codex_reviewer.sh" "$PROFILE" "$BUNDLE" "$(pwd)" "$CODEX_YAML" || runner_rc=$?
  if [ "$runner_rc" -eq 3 ]; then
    rm -f "$CODEX_YAML" || true
    echo "[spec-distill] codex 러너가 산출물을 쓰지 못했다(runner_rc=3, 사유는 위 [docreview] 줄) — 이 라운드의 codex 축은 없이 간다." >&2
  fi
else
  echo "[spec-distill] codex co-review SKIPPED (reason: ${skip_reason:-unknown}) — seed 리뷰에 codex 쪽 모델 다양성이 없었다 (degraded)." >&2
fi
```
<!-- codex-gate:end -->

### dispatch 둘 — 3단계 탐지 · 6단계 재비판

`${PROFILE}` 에는 경로가 아니라 `### 프로필 내용` 펜스가 낸 **내용**을 싣습니다. 탐지의 `${DOCUMENT}` 는
이번 라운드 `$BUNDLE` 의 내용입니다. seed 프로필이 웹을 허용하지 않으므로 웹 사본을 고르는 펜스가 없습니다.

```
Agent({
  description: "Seed review detection (layer 1)",
  subagent_type: "spec-distill:doc-critic",
  // **처분** — consumer=plugins/spec-distill/scripts/docreview_route.py · fail-closed
  prompt: "<document>${DOCUMENT}</document>
    <profile>${PROFILE}</profile>
    <prior_finding_ids>${PRIOR_FINDING_IDS}</prior_finding_ids>"
})
```

재비판의 `${DOCUMENT}` 는 **`$BUNDLE_RC` 의 내용**입니다 — 탐지와 다른 번들입니다. 입력 슬롯은
넷이고 그중 `diff` 는 선택입니다(그 번들 · `prep.json` 의 `items` · 프로필 · `diff`(선택)) —
이 자리(문서 경로)는 `diff` 를 싣지 않습니다. 싣는 것은 코드 경로뿐이고, 재비판자는 `diff` 를
못 받으면 「이 변경이 도입했는가」 축을 쓰지 않습니다. dispatch 사유도 이전 대화도 어느 리뷰어가
냈는지도 넣지 않습니다.
`DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC=1` 이면 dispatch 하지 않고 7단계를 `--recritic-skipped` 로 돕니다.

```
Agent({
  description: "Framing-blind re-critique of the seed finding list",
  subagent_type: "spec-distill:doc-recritic",
  // **처분** — consumer=plugins/spec-distill/scripts/docreview_route.py · fail-open
  prompt: "<document>${DOCUMENT}</document>
    <findings>${FINDINGS}</findings>
    <profile>${PROFILE}</profile>"
})
```

### 산출물 기록 — 7단계 뒤, 게이트 앞

```bash
# 엔진 산출물 셋을 판정 없이 audit `## 4. 비평과 냉독` 에 옮긴다 — 엔진 자리는 세션 정리로 사라지고,
# 사람이 나중에 되짚을 자리는 audit 이다. 없는 산출물은 그 사실을 적는다(침묵과 0 은 다르다).
rnd="$(python3 "$SD/scripts/docreview_state.py" gate --state-dir "$STATE_DIR" | python3 -c 'import json,sys; print(json.load(sys.stdin)["round"])')" || rnd="?"
for pair in "탐지 (doc-critic)|critic.txt" "codex|docreview-codex.yaml" "재비판 (doc-recritic)|recritic.txt"; do
  title="${pair%%|*}"; src="$STATE_DIR/${pair#*|}"
  if [ ! -s "$src" ]; then
    src="$STATE_DIR/absent-note.txt"
    printf '(이 라운드에 산출물 없음 — %s)\n' "${pair#*|}" > "$src"
  fi
  python3 "$SD/scripts/seed_review_log.py" append-verbatim "$AUDIT_ABS" --section "## 4. 비평과 냉독" --title "라운드 $rnd — $title" "$src" \
    || echo "[spec-distill] audit ## 4 에 옮기지 못했다: $title" >&2
done
```

### 게이트 — 처분은 사용자가, 편집은 처분 뒤에

엔진 8단계의 `docreview_state.py gate --state-dir "$STATE_DIR" --render` 가 결정 묶음과 게이트 종류를
냅니다. 그 묶음은 **`AskUserQuestion` 최대 4개씩 연속 호출**로 나눠 띄우고, 매 호출 첫 질문의 첫 줄은 렌더
첫 줄(degrade 공시)과 같습니다. `approval_gate_open` 이면 승인 게이트입니다 — 1단계(열린 항목 · 「추가
라운드 1회 열기」)는 절차서 8단계 그대로이고, 2단계(진행 옵션)는 이 skill 의 `## 확정 — proceed 게이트`
입니다. 이 자리는 그 위에 규칙 넷을 더합니다 — seed 는 헤딩이 없어 엔진의 얼림 · 보호가 꺼지고, 엔진에서
승인을 막고 사용자 문구를 남기는 처분은 `decide` 하나뿐입니다.

1. **사용자가 처분하기 전에는 seed 파일을 편집하지 않는다.** 읽기는 막지 않는다 — 관측 수단(`### 저자 편집
   공시`)이 편집만 재므로 규칙도 편집이다. 라운드 1단계(스냅숏)부터 그 라운드 게이트의 처분이 끝날
   때까지 seed 를 고치지 않는다. 처분이 끝난 뒤에만 채택된 결정과 사용자가 적용을 고른 `fix` 를
   반영하고, 그 편집은 다음 공시에서 덩어리째 사용자 앞에 다시 온다.
2. **라운드 게이트는 엔진보다 넓다.** 아래 요약 펜스가 내는 넷(`open_decide` · `blocking_ask_open` ·
   `unapplied_fix` · `ask_open`)과 저자 편집 덩어리 중 하나라도 0 이 아니면 라운드 게이트를 띄운다 —
   엔진의 `round_gate_needed` 가 거짓이어도. **`fix` 도 적용 전에 묻는다** — 엔진은 `fix` 로 라운드
   게이트를 열지 않는다. `ask_open` 도 올린다 — 엔진이 처분 없이 온 항목과 재비판이 더한 항목을 스스로
   `ask` 로 만들고, 그 `ask` 는 아무것도 막지 않고 답도 기록하지 않는다.
   게이트 텍스트에 `ask_open` 개수를 처분과 무관하게 싣는다.
3. **`fix` 는 사용자가 고른 대로만 닫는다.** 질문은 「적용 / 적용하지 않음」 둘이다.
   - 적용 — `docreview_anchor.py check-intent <id> --intent '#__doc__' --state-dir "$STATE_DIR"` 를 부른다. 그 호출이
     결과를 스스로 원장에 적는다 — 통과면 `intent_passed` 이고 처분이 전부 끝난 뒤 편집한다. 범위 문제로 거부되면
     escalate 까지 적어 다음 라운드 `decide` 로 오고, 그 밖의 거부(`fix_not_pending` 등)는 사유를 게이트
     텍스트에 싣는다. 거부면 편집하지 않는다. 통과 · 거부 어느 쪽이든 엔진 `fix` 로 같은 결과를 다시 적지 않는다.
   - 적용하지 않음 — 저자가 판단해 `drop` 하지 않는다. 사용자의 문구로 엔진이 적게 한다 — 아래 처분 펜스를
     `EVENT=drop` 으로 돈다.
4. **`ask_open` 의 답은 이 skill 이 적는다.** 엔진의 `ask --answered` 는 답을 기록하지 않는다. 답을 받으면
   아래 답 기록 펜스를 돈다 — **기록이 먼저**이고, 기록이 성공했을 때만 ask 를 닫는다. 그 답이 seed 를
   바꿔야 하면 그것도 처분 뒤의 편집이다.

사용자 문구는 게이트에서 사용자가 고른 선택지 라벨(«기타» 면 적은 말) 그대로다. 엔진은 그 문구가 사용자의
말인지 검증하지 못한다 — 저자가 지어 넣지 않는다.

**사용자 문구 · 리뷰어 요약은 셸 인자에 직접 쓰지 않는다.** 큰따옴표 안의 백틱 · `$( )` 는 셸이 실행한다 —
사용자가 적은 말도, 비신뢰 원문을 읽은 리뷰어가 쓴 요약도 그런 글자를 담을 수 있다. 받은 문구는 **Write
도구로** 항목마다 따로 쓴다(셸의 `echo` · `printf` 로 쓰지 않는다) — 사용자 문구는 `$STATE_DIR/said-<id>.txt`,
항목 요약은 `$STATE_DIR/note-<id>.txt`, 저자 편집 덩어리의 문구는 `$STATE_DIR/said-hunk-<k>.txt`, 추가 라운드
승인은 `$STATE_DIR/said-extra-r<n>.txt` 다. 파일 이름이 항목을 담으므로 한 항목의 Write 를 빠뜨리면 다른
항목의 문구를 읽는 대신 «파일 없음»으로 멈춘다. 파일은 기록이 성공하면 펜스가 지우고, 덩어리 문구는 공시할
때마다 공시 펜스가 지운다. `seed_review_log.py log` 에는 `--quote-file` · `--note-file` 로, 엔진의 인자에는
아래 처분 펜스처럼 `q="$(python3 "$SD/scripts/seed_review_log.py" one-line <파일>)"` 로 먼저 받아 그 rc 를 본
뒤 `--quote="$q"` · `--reason="$q"` 로 넘긴다 — 명령 치환의 출력은 다시 전개되지 않고, `=` 꼴은 `-` 로 시작하는
문구를 옵션으로 읽지 않게 한다. 엔진 절차서와 게이트 렌더가 보이는 추가 라운드 승인 꼴(큰따옴표 안의
자리표)도 이 자리에서는 `### 절차` 의 꼴로 바꿔 쓴다. 여러 줄 문구는 한 줄로 이어진다(audit `## 6` 은 한 줄에 한 기록이다).

```bash
# 처분 — 엔진에 사용자 문구를 싣는 결정 하나. <id> 의 문구는 먼저 Write 도구로 "$STATE_DIR/said-<id>.txt" 에 쓴다.
# EVENT 는 이 처분 하나: drop(fix 적용하지 않음) · adopt · reject · hold(decide). 문구 파일이 없거나 비면 누르지 않는다.
EVENT="<drop | adopt | reject | hold>"
q_rc=0; q="$(python3 "$SD/scripts/seed_review_log.py" one-line "$STATE_DIR/said-<id>.txt")" || q_rc=$?
if [ "$q_rc" -ne 0 ]; then
  echo "[spec-distill] <id> 의 사용자 문구 파일을 읽지 못했다 — 처분을 누르지 않는다. 문구를 Write 도구로 쓴 뒤 이 펜스를 다시 돌려라." >&2
elif [ "$EVENT" = drop ]; then
  python3 "$SD/scripts/docreview_state.py" fix --state-dir "$STATE_DIR" --id "<id>" --event drop --reason="$q" --log-file "$AUDIT_ABS" || q_rc=$?
else
  python3 "$SD/scripts/docreview_state.py" decide --state-dir "$STATE_DIR" --id "<id>" --choice "$EVENT" --quote="$q" --log-file "$AUDIT_ABS" || q_rc=$?
fi
[ "$q_rc" -ne 0 ] || rm -f "$STATE_DIR/said-<id>.txt"
echo "q_rc=$q_rc"
```

```bash
# 답 기록 — ask_open 항목 하나. <n> · <id> 는 게이트의 값이다. 문구 · 요약은 먼저 Write 도구로
# "$STATE_DIR/said-<id>.txt" · "$STATE_DIR/note-<id>.txt" 에 쓴다. 통째로 다시 돌려도 같은 기록 줄은 다시 적지 않는다.
log_rc=0; ask_rc=0
python3 "$SD/scripts/seed_review_log.py" log "$AUDIT_ABS" --kind 답 --round "<n>" --target "<id>" --quote-file "$STATE_DIR/said-<id>.txt" --note-file "$STATE_DIR/note-<id>.txt" || log_rc=$?
if [ "$log_rc" -ne 0 ]; then
  echo "[spec-distill] 답 기록 실패(log_rc=$log_rc) — ask 를 닫지 않는다. 위 stderr 를 보고 파일을 고쳐 이 펜스를 다시 돌려라." >&2
else
  python3 "$SD/scripts/docreview_state.py" ask --state-dir "$STATE_DIR" --id "<id>" --answered || ask_rc=$?
  if [ "$ask_rc" -eq 0 ]; then
    rm -f "$STATE_DIR/said-<id>.txt" "$STATE_DIR/note-<id>.txt"
  else
    echo "[spec-distill] 답은 audit ## 6 에 적혔으나 ask 를 닫지 못했다(ask_rc=$ask_rc) — id 를 확인하고 이 펜스를 다시 돌려라(같은 기록 줄은 다시 적지 않는다)." >&2
  fi
fi
ans_rc=$log_rc; [ "$ans_rc" -ne 0 ] || ans_rc=$ask_rc
echo "ans_rc=$ans_rc"
```

게이트를 띄우기 **전에** 요약 펜스를 돕니다:

```bash
# 라운드 게이트에 올릴 것 — 엔진 요약에서 넷. 저자 편집 덩어리는 `### 저자 편집 공시` 가 센다.
gate_json="$STATE_DIR/gate-summary.json"
if ! python3 "$SD/scripts/docreview_state.py" gate --state-dir "$STATE_DIR" > "$gate_json"; then
  echo "[spec-distill] 엔진 게이트 요약을 읽지 못했다(STATE_DIR='${STATE_DIR:-}') — 게이트를 띄우지 않는다. 「## 상태」 블록을 앞에 이어 붙였는지 확인하라." >&2
else
  python3 -c '
import json, sys
g = json.load(open(sys.argv[1], encoding="utf-8"))
for k in ("open_decide", "blocking_ask_open", "unapplied_fix", "ask_open"):
    ids = g.get(k) or []
    print("%s=%d %s" % (k, len(ids), " ".join(ids)))
print("round_gate_needed=%s approval_gate_open=%s" % (g.get("round_gate_needed"), g.get("approval_gate_open")))
' "$gate_json"
fi
```

처분을 반영한 **뒤에** 문구 없는 `drop` 검사를 돕니다 — 엔진이 dropped 로 센 `fix` 마다 audit `## 6. 리뷰
결정` 에 문구 있는 drop 줄(또는 `거부` 줄)이 있어야 합니다. 승인 게이트가 열린 채 막힌 항목이 남는
라운드(상한 · 정체 · 「미검증」)에서 엔진 렌더가 「drop 하면 이 차단이 풀린다」를 안내해도, 그 drop 은
사용자의 문구로만 누릅니다. 막히면 그 항목을 사용자에게 다시 묻고 받은 문구를 `said-<id>.txt` 에 쓴 뒤
`seed_review_log.py log "$AUDIT_ABS" --kind 거부 --round <n> --target <id> --quote-file "$STATE_DIR/said-<id>.txt" && rm -f "$STATE_DIR/said-<id>.txt"`
를 적고 이 펜스를 다시 돕니다 — 되돌리는 기록은 `거부` 줄로 남기고 엔진에 drop 을 다시 누르지 않습니다.

```bash
# 문구 없는 drop 검사 — 엔진 공개 요약의 dropped 대 audit ## 6 의 기록.
drops_rc=0
if ! python3 "$SD/scripts/docreview_state.py" gate --state-dir "$STATE_DIR" > "$STATE_DIR/gate-drops.json"; then
  drops_rc=2
else
  python3 "$SD/scripts/seed_review_log.py" check-drops "$AUDIT_ABS" "$STATE_DIR/gate-drops.json" || drops_rc=$?
fi
case "$drops_rc" in
  0) : ;;
  1) echo "[spec-distill] 문구 없는 drop 검사 실패(drops_rc=1) — 진행하지 않는다. 위 violations 의 항목을 사용자에게 다시 묻고 그 문구로 거부 줄을 적은 뒤 이 펜스를 다시 돌려라." >&2 ;;
  *) echo "[spec-distill] drop 검사 불가(drops_rc=$drops_rc) — 엔진 요약이나 audit 을 읽지 못했다(위 stderr). 진행하지 않는다 — 거부 줄로 풀 수 있는 상태가 아니다." >&2 ;;
esac
echo "drops_rc=$drops_rc"
```

### 저자 편집 공시 — 라운드 게이트 앞 · 확정 게이트 앞

seed 는 헤딩이 없어 엔진의 얼림 검사가 모든 변경을 면제합니다. 저자 편집은 기준 사본과의 diff 로 **전부**
사용자 앞에 놓습니다 — 승인된 수정과 그 틈에 끼어든 수정을 가를 기계가 없으므로 가르지 않습니다.

```bash
# 공시할 때마다 덩어리 번호가 새로 매겨진다 — 지난 공시의 덩어리 문구 파일을 먼저 지운다.
find "$STATE_DIR" -maxdepth 1 -name 'said-hunk-*.txt' -exec rm -f {} + 2>/dev/null || true
hunks_rc=0
python3 "$SD/scripts/seed_edit_diff.py" hunks "$SEED_BASE" "$SEED_ABS" > "$STATE_DIR/hunks.json" || hunks_rc=$?
case "$hunks_rc" in
  0) python3 -c '
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
if not d["hunks"]:
    print("저자 편집 없음")
for h in d["hunks"]:
    print(h["render"])
    print()
' "$STATE_DIR/hunks.json" ;;
  3) echo "[spec-distill] 기준 사본이 없다(${SEED_BASE:-}) — 저자 편집을 비교할 수 없다. seed 전문을 보이고 「이대로 둔다 / 멈춘다」를 물어라." >&2 ;;
  *) echo "[spec-distill] 저자 편집 공시 실패(rc $hunks_rc) — 게이트를 띄우지 않는다." >&2 ;;
esac
```

- 덩어리가 0 이면 게이트 텍스트에 **«저자 편집 없음»** 한 줄을 싣는다 — 침묵과 구분한다.
- 덩어리가 있으면 **덩어리마다 질문 하나** — 「그대로 둔다 / 되돌린다」. **권장 표시를 달지 않는다** —
  어느 덩어리가 승인된 수정인지 가를 기계가 없고, 저자의 권장은 바로 그 가름을 저자가 하는 것이다.
  덩어리 본문(`render`)은 질문 텍스트에 줄임 없이 싣는다 — 분량 상한을 두지 않는다(줄이면 공시가 아니다).
- 처분 없이는 다음 단계로 가지 않는다.
- 기준 사본이 없으면(rc 3 — 세션 디렉토리가 정리됐다) 그 사실을 게이트 텍스트에 싣고 seed 전문을 한 질문으로
  보여 「이대로 둔다 / 멈춘다」를 묻는다. 「이대로 둔다」면 `seed_edit_diff.py init` 으로 새 기준 사본을 뜬다.

처분을 받은 뒤 순서가 계약입니다 — **되돌리기 → 기록 → 기준 사본 교체.** 교체는 맨 끝에서만 합니다. 공시
전에 교체하면 그 사이의 편집이 영영 안 보입니다.

```bash
# PAIRS 는 게이트의 답이다 — 덩어리마다 한 줄 「번호:처분」(처분은 「그대로 둔다」 또는 「되돌린다」). 덩어리 k 의
# 사용자 문구는 먼저 Write 도구로 "$STATE_DIR/said-hunk-<k>.txt" 에 쓴다(공시 펜스가 공시마다 지난 파일을 지운다).
# 문구 파일이 하나라도 없으면 아무것도 바꾸지 않는다. 기록이 전부 성공했을 때만 기준 사본을 교체한다.
# 부분 실패 뒤에는 원인을 고치고 이 펜스를 통째로 다시 돈다 — 되돌리기는 표지(`<기준 사본>.reverted`)가 막아 같은 판본에서 한 번만
# 일어난다. 편집 기록 줄은 그렇지 않다: 다시 돈 만큼 겹친다(덩어리 번호가 공시마다 1 부터 다시 시작해 다른 처분이 같은 줄이 되므로,
# 같은 줄을 건너뛰면 기록이 사라진다 — 겹치는 쪽을 고른다). **겹친 줄을 지우지 마라**: 어느 것이 재실행으로 겹친 줄이고 어느 것이
# 다른 공시의 다른 처분인지 글자로는 가를 수 없고, 겹침은 아무것도 상하게 하지 않는다 — `user-quotes` 는 문구로 묶고 `check-drops` 는
# `거부` 와 엔진 drop 줄만 읽는다.
PAIRS='<덩어리마다 한 줄 — 번호:처분>'
pre_rc=0; rev_rc=0; log_rc=0; n_pairs=0; REVERT_IDS=""
while IFS=: read -r k choice; do
  [ -n "$k" ] || continue
  n_pairs=$((n_pairs + 1))
  [ -s "$STATE_DIR/said-hunk-${k}.txt" ] || { echo "[spec-distill] 덩어리 ${k} 의 사용자 문구 파일이 없다(${STATE_DIR}/said-hunk-${k}.txt) — 아무것도 바꾸지 않는다." >&2; pre_rc=2; }
  case "$choice" in
    되돌린다) REVERT_IDS="${REVERT_IDS:+${REVERT_IDS},}${k}" ;;
    "그대로 둔다") : ;;
    *) echo "[spec-distill] 덩어리 ${k} 의 처분을 모르겠다: '${choice}' — 아무것도 바꾸지 않는다." >&2; pre_rc=2 ;;
  esac
done <<< "$PAIRS"
[ "$n_pairs" -gt 0 ] || { echo "[spec-distill] 처분 목록(PAIRS)이 비었다 — 아무것도 바꾸지 않는다." >&2; pre_rc=2; }
if [ "$pre_rc" -eq 0 ] && [ -n "$REVERT_IDS" ]; then
  python3 "$SD/scripts/seed_edit_diff.py" revert "$SEED_BASE" "$SEED_ABS" --ids "$REVERT_IDS" || rev_rc=$?
fi
if [ "$pre_rc" -eq 0 ] && [ "$rev_rc" -eq 0 ]; then
  while IFS=: read -r k choice; do
    [ -n "$k" ] || continue
    python3 "$SD/scripts/seed_review_log.py" log "$AUDIT_ABS" --kind 편집 --round "<n>" --target "덩어리 ${k} · ${choice}" --quote-file "$STATE_DIR/said-hunk-${k}.txt" || log_rc=$?
  done <<< "$PAIRS"
fi
if [ "$pre_rc" -eq 0 ] && [ "$rev_rc" -eq 0 ] && [ "$log_rc" -eq 0 ]; then
  accept_rc=0
  python3 "$SD/scripts/seed_edit_diff.py" accept "$SEED_BASE" "$SEED_ABS" || accept_rc=$?
  echo "accept_rc=$accept_rc"
  [ "$accept_rc" -ne 0 ] || find "$STATE_DIR" -maxdepth 1 -name 'said-hunk-*.txt' -exec rm -f {} + 2>/dev/null || true
elif [ "$rev_rc" -ne 0 ]; then
  echo "[spec-distill] revert 실패(rev_rc=$rev_rc) — 기준 사본을 교체하지 않는다. 위 공시 펜스를 다시 돌려 이 처분을 다시 받아라." >&2
elif [ "$log_rc" -ne 0 ]; then
  echo "[spec-distill] 편집 처분 기록 실패(log_rc=$log_rc) — 기준 사본을 교체하지 않는다. 위 stderr 가 댄 문구 파일을 고친 뒤 이 펜스를 그대로 다시 돌려라(되돌리기는 표지가 막아 한 번만 일어난다 · 먼저 성공한 편집 기록 줄은 겹쳐 적히지만 그대로 둔다)." >&2
fi
echo "pre_rc=$pre_rc rev_rc=$rev_rc log_rc=$log_rc"
```

`revert` · `accept` 가 rc 4 를 내면 공시(`hunks`) 뒤에 seed 가 또 바뀌었거나, 이 공시에서 이미 다른 번호를
되돌린 것입니다(되돌린 뒤에는 덩어리 번호가 다시 매겨진다) — 기준 사본을 그대로 두고
위 공시 펜스를 다시 돌려 다시 처분받습니다. `revert` 는 처분 하나에 한 번만 부릅니다 — 펜스가 `PAIRS` 의
「되돌린다」 번호를 전부 쉼표로 모아 `--ids` 에 한 번에 넘깁니다. `hunks` 는 그 출력을 사용자에게 보이는 자리에서만
부릅니다 — 부르면 매번 «공시됨»으로 기록되기 때문입니다.

### 냉독

마지막 라운드의 게이트가 닫힌 뒤 한 번 돕니다 — 문서가 더 바뀌지 않는 시점이어야 측정이 뜻을 가집니다.
경로는 `## 상태` 가 이미 도출했습니다. 아래 펜스는 그 블록이 대입한 `$SEED` 를 소비하므로 `## 상태` 블록을
**이 펜스 앞에 이어 붙여 같은 `Bash` 호출 안에서** 함께 돌립니다.

```bash
if [[ -z "${SEED:-}" ]]; then
  echo "[spec-distill] 냉독 입력 부재 — SEED='${SEED:-}'. 「## 상태」 블록을 이 펜스 앞에 이어 붙여 같은 Bash 호출 안에서 함께 돌려라. 이 라운드의 냉독 축은 돌지 않는다." >&2
  seed_text_rc=2
else
  cat "$SEED"; seed_text_rc=$?
fi
```

**이 `cat` 이 `${SEED_TEXT}` 의 출처입니다.** 블록의 출력에 seed 전문이 그대로 나오고, 아래 dispatch 는 그
출력을 인라인합니다. 경로를 넘기는 선택지는 없습니다 — `seed-readback` 은 `tools: []` 이라 파일을 열 도구가
물리적으로 없고, 파일명을 받으면 **아무 내용도 못 읽은 채로** 냉독이 도는 무의미한 실행이 됩니다. `$SEED` 는
이 skill 에서 **경로**이고 `${SEED_TEXT}` 가 **내용**입니다 — 번들의 `$BUNDLE`(경로) / `${DOCUMENT}`(내용) 과
같은 쌍이며, 두 이름을 섞지 않습니다.

`seed_text_rc` 가 0 이 아니면 냉독을 **돌리지 않고**, 그 사실을 `## degrade 채널` 의 냉독 행으로 남깁니다.

```javascript
Agent({ description: "Seed cold readback", subagent_type: "spec-distill:seed-readback",
        prompt: `아래 seed 만 읽고 «내가 이해한 것은 이것이다» 를 산문으로 말하라.
<seed>${SEED_TEXT}</seed>` })
// **처분** — consumer=human · fail-open · disclosure=proceed 게이트 질문 텍스트
```

**싱크됐는지는 사용자가 읽고 판정합니다.** 에이전트가 통과·미달을 내면 어긋남의 감각이 사용자에게 오지
않습니다. 냉독 출력은 판정 경로 밖이라 엔진 게이트를 거치지 않고 proceed 게이트 텍스트에 그대로 실리며,
audit `## 4. 비평과 냉독` 에도 옮깁니다 — 출력을 요약 없이 **Write 도구로** `$STATE_DIR/readback.txt` 에 쓰고 아래
펜스로 인용 블록째 붙입니다(인용 표시가 없으면 출력 안의 제목 모양 줄이 audit 절 경계로 읽힌다). degrade 가
있으면 그것은 `## degrade 채널` 로 나갑니다.

```bash
python3 "$SD/scripts/seed_review_log.py" append-verbatim "$AUDIT_ABS" --section "## 4. 비평과 냉독" --title "냉독 (seed-readback)" "$STATE_DIR/readback.txt" \
  || echo "[spec-distill] audit ## 4 에 냉독을 옮기지 못했다 — 게이트 텍스트에 그 사실을 싣는다" >&2
```

## degrade 채널

degrade 는 **채널 다섯**으로 나갑니다 — 엔진의 셋과 이 skill 의 둘.

- 엔진의 셋 — `fin.json` 의 `advisory[]`(codex 부재 · 재비판 부재 · 처분 회계의 degrade 사유) ·
  `fin.json` 의 `blocks`(critic 사망 · 항목 소실 · 셀 수 없음일 때만 참) · `gate --render` 의 **첫 줄**
  (그 라운드의 degrade 한 줄 — 「미검증」 라운드면 그 공시가 맨 앞이다).
- 이 skill 의 둘 — state 의 `framing_degradations` 원장(**`ledger_rc` 가 0 일 때만 존재**) ·
  proceed 게이트 질문 텍스트(**항상**). 원장이 없거나 개별 기록이 실패하면 게이트 텍스트가 유일한 채널이고,
  그때는 「원장에 기록하지 못했다」는 사실 자체를 한 줄로 함께 싣습니다.

엔진 밖의 사건은 이 skill 이 원장에 적습니다. 기록은 `brief_review_state.py degrade-append "$STATE"
--ledger-key framing_degradations --component <a> --axis <b> --status <c> --reason "<r>"` 이고 매 호출의
종료 코드를 그 자리에서 잡습니다. **위에서부터 먼저 맞는 행**을 씁니다:

| 관측 | `--component` · `--axis` | `--status` | `--reason` |
|---|---|---|---|
| `$STATE_DIR` 이 비었다 · 엔진 `init` 이 rc ≠ 0 | `pipeline` · `all` | `unavailable` | 비어 있던 변수, 또는 `init` 이 낸 사유 |
| `bundle_rc` 가 0 이 아니다 | `pipeline` · `suppression` | `unavailable` | 번들 조립 실패 — 조립기 stderr 마지막 줄 |
| `prof_rc` 가 0 이 아니다 | `critic` · `suppression` | `unavailable` | seed 프로필 판독 불가(cat rc) |
| `marks_rc` 가 2 다(표시 검사 불가) | `pipeline` · `suppression` | `degraded` | `seed_provenance.py marks` 의 stderr — 표시가 떼어지지 않았을 수 있다 |
| `base_rc` 가 0 이 아니다 · 공시 펜스가 rc 3 | `pipeline` · `all` | `degraded` | 기준 사본 부재 — 저자 편집을 비교할 수 없는 구간이 있다 |
| `seed_text_rc` 가 0 이 아니다 | `readback` · `readback` | `unavailable` | 냉독 입력 부재 — 관측한 `$SEED` 값과 `seed_text_rc` |

codex 부재 · 재비판 부재는 이 표에 없습니다 — 엔진이 `advisory[]` 와 게이트 첫 줄로 이미 공시합니다. 같은
사실을 두 채널에 다른 말로 적지 않습니다. codex 가 **왜** 없었는지는 엔진이 모릅니다 — 그 사유는 `### 번들` 의
옮겨 싣기 규칙대로 `### codex` 펜스의 `[spec-distill]` 줄이 게이트 텍스트로 가져갑니다.

**기록이 없는 것과 degrade 가 없는 것은 다른 사실입니다.** 게이트 텍스트에서 둘을 구별해 씁니다 — 원장이
없는 세션에 「degrade 없음」이라고 쓰지 않습니다.

**남은 갭 — `no-state-in-phase-0`.** `request-framing` 은 인터뷰 이전이라 state 파일이 아예 없는 세션이
**정상**입니다. 그 세션에서 원장은 구조적으로 부재하고 채널 2 만 남습니다. state 파일을 새로 만드는
설계(어디에 · 어떤 frontmatter 로 · 누가 지우나)는 이 skill 의 범위 밖이므로, 그 갭을 이 이름으로 부르고
게이트 텍스트가 그 사실을 말합니다.

**딸린 상호작용 하나** — `## 상태` 가 `$SEED_DIR` 과 그 아래 리뷰 엔진 자리 `$STATE_DIR` 을 만들므로, 원래
세션 디렉토리가 없었을 세션에도 디렉토리와 파일이 생깁니다. 그 파일들은 `gc_common.py` 의 TTL-GC 관할에
들어갑니다 — **관할 밖에 놓이는 분기가 없기 때문**입니다: 그 블록의 단일 가드가 `sid` 실값과 `mkdir`
성공을 함께 요구하고, `state_path.py` 가 GC 의 세션 이름 필터와 같은 정규식을 통과한 값만 내주므로, **이
파일들이 존재한다는 것 자체가 GC 가 걷는 자리에 있다는 뜻**입니다. 폴더 나이는 **폴더 자신과 그 아래 모든
항목의 최신 mtime**(링크는 따라가지 않는다)이고, TTL(기본 24시간, env override)을 넘기면 폴더가 통째로
걷힙니다 — 리뷰 원장도 함께입니다. 리뷰 도중 그렇게 걷히면 엔진 호출이 `state_missing` 으로 죽고, 저자 편집
공시는 기준 사본 부재(`### 저자 편집 공시` 의 rc 3 경로)로 떨어집니다. 사용자 결정은 audit `## 6. 리뷰 결정`
에 남아 있어 잃지 않고, 확정 직전 drop 검사는 엔진 원장 없이 그 기록으로 대조합니다(`### 게이트 직전` 검사 3).

**냉독 축도 죽을 수 있고, 죽으면 여기 보입니다.** 그 축의 입력은 `${SEED_TEXT}` 이고 그 출처는 `### 냉독` 의
`cat "$SEED"` 입니다 — `$SEED` 가 비면 냉독은 아무 내용도 없이 돌게 되므로 **돌리지 않습니다**. 리뷰 축은
codex 를 잃어도 탐지 리뷰어가 남지만 **냉독 축에는 남는 담당이 없습니다** — 담당이 하나뿐인 축이라 통째로
없어집니다. 그래서 그 행은 「모델 다양성 손실」이 아니라 **축 소실**이고, 게이트 질문 텍스트에도 그렇게
씁니다.

## 확정 — proceed 게이트

공통 계약의 정본은 `${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 입니다. 4옵션
게이트를 띄우고, 게이트 질문 텍스트에 degrade 를 **하나도 빠뜨리지 않고** 싣습니다.
seed 파일은 이 게이트 **이전에** 디스크에 있어야 합니다 — 아래 구조 검사도, 공통 계약의
Step A 도 그것을 읽습니다. 승인이 여는 것은 파일 쓰기가 아니라 handoff 입니다.

### 호출 모양 — 이 파이프라인에서 여기가 정본이다

**다음 세션의 첫 턴은 `/interview @<seed 경로>` 한 줄입니다.** `<seed 경로>` 는 `$SEED` 의 실제 값
(`docs/superpowers/interview/<날짜>-<topic>-interview.md` 모양의 상대경로)으로 치환한 뒤 노출합니다 —
치환하지 않은 자리표가 나가면 사용자가 깨진 명령을 실행하고, 그것을 잡는 자리가 없습니다.

`@경로` 는 서식 취향이 아닙니다 — **소비자 쪽 계약이 전부 `/interview` 가 넘기는 인자에 키잉돼 있습니다.**
커맨드 인자의 `@경로` 는 헤드리스 실측(2026-09-10)에서 파일로 풀리지 않았고 대화형은 재지 않았습니다 —
어느 쪽이든 `/interview` 가 그 파일을 읽어 전문으로 풀어 넘깁니다. 넘긴 값이 비거나 경로 문자열로 남으면
셋이 함께 조용히 실패합니다:

- `conducting-interview` 의 종료 절차가 「인자 없이 호출되면 `S1` 을 만들지 않는다」이므로
  **사용자가 방금 확정한 요청이 brief §6 에 보존되지 않습니다.**
- `conducting-interview` 의 seed 입력 규약(그 안의 재결정 P23 포함)이 발동할 입력을 못
  받습니다.
- `/interview` 가 방금 Phase 0 을 거친 사용자에게 「`/request-framing` 을 먼저 거치면…」
  조언을 내고, 인터뷰가 「어떤 것을 만들고 싶으신가요?」로 시작합니다.

**frontmatter 를 떼지 않는 이유**: `type: interview-seed` 줄이 소비자가 seed 를 알아보는
유일한 표지입니다. 본문은 라벨 없는 산문이라 그것만으로는 seed 인지 아닌지 구별되지
않습니다. `check_seed.py` 와 리뷰 번들 조립기가 **본문만** 보는 것은 별개 사실입니다 —
그 둘은 사람이 읽는 메시지를 재고, frontmatter 는 하니스용 메타데이터입니다.

게이트의 네 옵션은 이 모양을 그대로 씁니다 — ①/② 는 두 줄 명령을 노출하는 핸드오프입니다:

| # | 이 skill 의 옵션 |
|---|---|
| ① | `/new` 후 `/interview @<seed 경로>` (권장, 커밋 후) — 두 줄 명령을 노출하고 **턴 종료** |
| ② | `/compact` 후 `/interview @<seed 경로>` (커밋 후) — 두 줄 명령을 노출하고 **턴 종료** |
| ③ | 수정 필요 — 압축을 다시 깎고 이 게이트로 돌아옵니다 |
| ④ | 멈춤 — seed 와 audit 을 남기고 종료 |

노출 모양(① 의 예 — ② 는 첫 줄이 `/compact` 입니다):

```
/new
/interview @docs/superpowers/interview/<날짜>-<topic>-interview.md
```

`/new` 뒤 같은 줄에 텍스트를 붙이면 그 텍스트는 세션 이름이 됩니다 — 두 줄을 **따로** 입력하라는 안내를
명령과 함께 냅니다. `/compact` 뒤 텍스트도 요약 지시로만 쓰이고 다음 프롬프트로 가지 않으므로 ② 도 같습니다.

**handoff 직전 커밋(①/② 에서만).** 워크트리 안이면 ①/② 를 고른 직후 handoff 직전
커밋을 한 번 합니다 — 명령 노출(①/②) 바로 앞입니다.
③(수정)·④(멈춤)에서는 커밋하지 않습니다 — 수정마다 커밋이 늘고 멈춤에도 커밋이 남는
것을 막기 위해서입니다. 단순 명령 셋, 메시지는 파일로:

```bash
printf 'docs(interview): <topic> interview seed + audit\n' > "$SEED_DIR/commit-msg.txt"
git add "$AUDIT" "$SEED"
git commit -q -F "$SEED_DIR/commit-msg.txt"
```

워크트리가 아니면(거절·부재·스위치) 커밋하지 않고 «미커밋 — 현재 디렉토리» 를 게이트 텍스트에
적습니다. ①/② 의 «다음 세션 첫 턴» 안내에는 **워크트리 절대경로**(`pwd`)를 함께 냅니다 —
다른 터미널에서 새 세션을 열 때 그 디렉토리에서 열어야 `@<seed 경로>` 가 풀리기 때문입니다.

### 게이트 직전 — 넷, 이 순서로

마지막 라운드의 게이트가 닫힌 뒤, 그리고 ③ 「수정 필요」 로 돌아올 때마다 게이트를 띄우기 **직전에** 넷을
돕니다. 하나라도 막히면 게이트를 띄우지 않습니다 — 막힌 것을 풀고 1번부터 다시 돕니다.

**검사 1 — 표시** — 떼지 않고 검사만 합니다. 근거 없는 «(사용자 확인)» 이 있으면(`marks_rc` 1) 막힙니다 —
펜스의 stdout(`invalid` 목록)이 그 문장을 그대로 대므로 그 목록을 게이트 텍스트에 옮겨 싣습니다. 떼는
것도 편집이라 검사 2 에서 사용자 앞에 옵니다. audit 을 판단할 수 없어 표시 자체를 매길 수 없으면
(`marks_rc` 2, 위반이 아니다) **떼지 않고** 표시 검사 불가로 막히고, stderr 사유를 게이트 텍스트에
싣습니다. 그 사유가 `duplicate_heading` 이면 `### 번들` 뒤의 템플릿 절 제목 중복 절차로 풉니다. `no_reading_lines`
면 audit `## 2` 에 풀이 줄이 하나도 없다는 뜻입니다 — `### 확인 질문` 이 정한 줄 모양으로 적혔는지 보고, 확인
질문이 한 번도 없었다면 표시를 뗍니다(떼는 것도 편집이라 검사 2 로 옵니다). `malformed_reading_lines` 면
`- 내가 읽은 것:` 으로 시작하는데 줄 모양이 어긋난 줄이 있다는 뜻입니다 — stderr 가 `## 2` 안 몇 번째
줄인지를 번호로 댑니다(줄 내용은 싣지 않습니다. 그 글자는 요청문에서 온 것이고, 게이트 텍스트를 거쳐
셸 인자에 실리면 그 안의 `$( )` 가 실행됩니다). 번호는 **`## 2. 질문 전체` 제목 다음 줄부터 빈 줄을 포함해**
셉니다 — 고치기 전에 그 줄이 `- 내가 읽은 것:` 으로 시작하는지 확인하십시오. 그 줄을 `### 확인 질문` 의
모양(`- 내가 읽은 것: 「<문장>」 — 고름` 또는 `— 고르지 않음`)으로 **그 자리에서 고쳐 적고** 1번부터 다시 돕니다. 이것이 audit 에 덧붙이지
않고 고치는 자리입니다 — 그 줄은 내가 쓴 확인 질문의 기록이고, 모양이 어긋난 채로는 검사 1 이 계속
막습니다. 새 줄을 덧붙이는 것으로는 풀리지 않습니다. 템플릿이 예시로 남긴 자리표 줄(`「<풀이 문장>」 —
<고름 | 고르지 않음>`)은 이 사유로 막지 않습니다.

```bash
# 검사 2 · 3 이 엔진 자리에 파일을 쓴다 — 세션 정리로 디렉토리가 사라졌으면 다시 만든다.
if [ -n "${STATE_DIR:-}" ]; then mkdir -p "$STATE_DIR"; else echo "[spec-distill] 리뷰 엔진 자리 없음(STATE_DIR 빈 값) — 「## 상태」 블록을 이 펜스 앞에 이어 붙여라. 검사 2 · 3 은 «검사 불가»로 막힌다." >&2; fi
marks_rc=0
python3 "$SD/scripts/seed_provenance.py" marks "$SEED_ABS" "$AUDIT_ABS" || marks_rc=$?
case "$marks_rc" in
  0) : ;;
  1) echo "[spec-distill] 근거 없는 «(사용자 확인)» 표시(marks_rc=1) — 위 목록(stdout 의 invalid)의 표시를 떼고 이 절을 처음부터 다시 탄다. 게이트를 띄우지 않는다." >&2 ;;
  *) echo "[spec-distill] 표시 검사 불가(marks_rc=$marks_rc) — 사유는 위 stderr. 게이트를 띄우지 않는다." >&2 ;;
esac
echo "marks_rc=$marks_rc"
```

**검사 2 — 저자 편집 공시** — `### 저자 편집 공시` 의 처분 절차 그대로입니다. 마지막 라운드 뒤의 편집(채택 결정의
반영 · ③ 뒤에 다시 깎은 것)이 사용자 앞에 오는 유일한 자리입니다. 덩어리 하나라도 「되돌린다」를 받으면 검사 1 부터
다시 돕니다 — 되돌리기가 검사 1 뒤에 뗀 표시를 되살릴 수 있습니다.

```bash
final_hunks_rc=0
if [ -z "${STATE_DIR:-}" ] || [ -z "${SEED_BASE:-}" ] || ! mkdir -p "$STATE_DIR" 2>/dev/null; then
  final_hunks_rc=2
else
  find "$STATE_DIR" -maxdepth 1 -name 'said-hunk-*.txt' -exec rm -f {} + 2>/dev/null || true
  python3 "$SD/scripts/seed_edit_diff.py" hunks "$SEED_BASE" "$SEED_ABS" > "$STATE_DIR/hunks-final.json" || final_hunks_rc=$?
fi
case "$final_hunks_rc" in
  0) python3 -c '
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
if not d["hunks"]:
    print("저자 편집 없음")
for h in d["hunks"]:
    print(h["render"])
    print()
' "$STATE_DIR/hunks-final.json" ;;
  3) echo "[spec-distill] 기준 사본이 없다(${SEED_BASE:-}) — 저자 편집을 비교할 수 없다. seed 전문을 보이고 「이대로 둔다 / 멈춘다」를 물어라. 게이트를 띄우지 않는다." >&2 ;;
  *) echo "[spec-distill] 확정 직전 공시 검사 불가(rc $final_hunks_rc) — 엔진 자리가 없거나(STATE_DIR='${STATE_DIR:-}') 입력을 읽지 못했다. 게이트를 띄우지 않는다." >&2 ;;
esac
```

**검사 3 — 문구 없는 drop** — `### 게이트` 의 검사와 같습니다. 엔진 원장(`$STATE_DIR/docreview-state.md`)이
없으면 — 라운드가 시작되지 않았거나 세션 정리로 걷혔다 — `gate` 를 부르지 않고 audit `## 6. 리뷰 결정` 의 엔진
drop 줄로 대조하며, 펜스가 내는 «엔진 원장 없음» 줄을 게이트 텍스트에 싣습니다.

```bash
final_drops_rc=0
if [ -z "${STATE_DIR:-}" ] || ! mkdir -p "$STATE_DIR" 2>/dev/null; then
  final_drops_rc=2
elif [ -f "$STATE_DIR/docreview-state.md" ]; then
  python3 "$SD/scripts/docreview_state.py" gate --state-dir "$STATE_DIR" > "$STATE_DIR/gate-final.json" || final_drops_rc=2
else
  # 엔진 원장이 없다 — dropped 를 audit ## 6 의 엔진 drop 줄에서 만든다. 기록된 drop 마다 문구가 있는지는 그대로 잰다.
  python3 -c '
import json, sys
sys.path.insert(0, sys.argv[1])
from seed_review_log import parse_lines
text = open(sys.argv[2], encoding="utf-8").read()
ids = [i for e in parse_lines(text) if e["source"] == "engine" and e["choice"] == "drop" for i in e["ids"]]
json.dump({"dropped": ids}, open(sys.argv[3], "w", encoding="utf-8"), ensure_ascii=False)
' "$SD/scripts" "$AUDIT_ABS" "$STATE_DIR/gate-final.json" || final_drops_rc=2
  [ "$final_drops_rc" -ne 0 ] || echo '[spec-distill] 엔진 원장 없음 — audit `## 6` 기록으로 대조했다. 엔진이 audit 에 적지 않은 drop 은 이 대조에 보이지 않는다.' >&2
fi
[ "$final_drops_rc" -ne 0 ] || python3 "$SD/scripts/seed_review_log.py" check-drops "$AUDIT_ABS" "$STATE_DIR/gate-final.json" || final_drops_rc=$?
case "$final_drops_rc" in
  0) : ;;
  1) echo "[spec-distill] 문구 없는 drop(final_drops_rc=1) — 사용자에게 다시 묻고 거부 줄을 적은 뒤 이 절을 다시 탄다." >&2 ;;
  *) echo "[spec-distill] drop 검사 불가(final_drops_rc=$final_drops_rc) — 엔진 자리 · 엔진 요약 · audit 중 하나를 읽지 못했다(위 stderr). 게이트를 띄우지 않는다 — 거부 줄로 풀 수 있는 상태가 아니다." >&2 ;;
esac
echo "final_drops_rc=$final_drops_rc"
```

**검사 4 — 구조** — 아래 `check_seed.py`.

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
python3 "$SD/scripts/check_seed.py" \
  gate "$SEED" "$AUDIT"; seed_rc=$?
if [ "$seed_rc" -ne 0 ]; then
  echo "[spec-distill] seed 게이트 위반 — 위 항목을 고치고 다시 이 블록부터 탑니다. 게이트를 띄우지 않습니다." >&2
fi
```

`check_seed.py` 가 재는 다섯 중 셋(답-슬롯 헤딩·태그·URL)은 seed 본문 **슬롯** 부재
검사입니다. 나머지 둘은 존재 검사이되 범위가 다릅니다 — 하나(check 0)는 seed 본문
**전체**가 비어 있지 않은지만 보고, 다른 하나는 audit 쪽 `## 1. 원문` 절(유일한 슬롯
존재 검사)입니다. **seed 본문에 슬롯 존재 검사를 추가하지 마십시오** — 그것이 이
payload 를 양식으로 만드는 유일한 경로이고, `tests/test_seed_one_sentence.sh` 가 그
금지를 동작으로 잡습니다.

### 두 가드

- **polite stop 금지 (AP2)** — ①/② 는 둘 다 핸드오프입니다. 이 옵션에서 polite stop 은 두 줄 명령을
  노출하지 않고 설명만 하고 끝내는 것입니다 — 명령을 노출하고 턴을 끝내는 것이 이 옵션의 완료입니다.
  게이트를 거치지 않는 예외 경로(kill switch · 경로 부재)면 명시적 advisory 단락을 동반해야 합니다 —
  게이트-less silent 종료 금지.
- **cross-compact 조기 진행 금지** — ①/② 어느 쪽이든 두 줄 명령을 노출하면 **거기서 턴 종료(STOP)**
  합니다. 같은 턴에서 인터뷰를 시작하지 않습니다. 다음 단계는 사용자가 그 명령을 실제로 친 **다음 턴**의
  사용자 트리거로만 일어납니다.

### 재결정 규약 (P23)

확산에서 확정된 것은 재논의 대상이 아니지만 **반증 대상입니다.** 압축 중에 그 확정이
틀렸다는 근거가 나오면 근거를 제시하고 **사용자 동의를 받아** 피벗합니다 — 임의 변경은
금지, 보고 후 재결정은 허용. 뒤집은 항목은 audit 에 *원래 / 재결정 / 근거* 세 칸으로
남깁니다. 정본은 `${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 의 「재결정 규약」 절.

## kill switch

- `DEVBREW_SPEC_DISTILL_DISABLE=1` — 즉시 abort, state 보존.
- `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1` — 리뷰 엔진의 codex 축만 skip(탐지 · 재비판은 그대로). `### codex` 펜스가 집행하고 엔진이 게이트 첫 줄로 공시한다.
- `DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC=1` — 재비판만 skip(`doc-recritic` dispatch 없음 · 7단계 `--recritic-skipped`). 엔진이 `advisory[]` 로 공시한다.
- `DEVBREW_SPEC_DISTILL_DISABLE_WORKTREE=1` — 워크트리 질문·생성을 건너뛰고 현재 디렉토리에서 진행(audit §5 에 사유).
