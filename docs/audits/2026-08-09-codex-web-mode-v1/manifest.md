# V1 — codex 웹 모드 probe (3단계 §5.3② 게이트)

- 대상 커밋: `55d97e2dd7ddcb927c59788dde76bc8fd1535735`
- codex: `codex-cli 0.147.0`
- 실제 codex 호출: **총 3회**. 원래 설계 예산은 2회(조건 A·B 각 1회)였으나, 1차 시도가 실행자
  (에이전트)의 Bash 도구 타임아웃 설정 실수로 최종 답 없이 소진돼(아래 "실행 경위" 절) 조건
  (A)를 완결하는 데 2회가 다 쓰였다. 컨트롤러가 조건 (A) 결과를 독립 검증한 뒤 3번째 호출을
  명시 승인해 조건 (B)를 실행, 판정을 완성했다.

## 왜 브리프의 nonce 경로를 쓰지 않았는가 (컨트롤러 ruling R2)

브리프 Step 2는 nonce 파일을 커밋해 35커밋 미푸시 WIP 브랜치(`feature/codex-usage-unification`)를
`git push`하고 `raw.githubusercontent.com`으로 fetch하는 경로를 지시한다. 컨트롤러 ruling으로 이
경로는 쓰지 않았다 — 리포가 공개라 기술적으로는 작동하지만, probe 하나를 위해 WIP 브랜치를
공개 push하고 히스토리를 오염시킬 이유가 없다. 브리프 자신이 승인한 대안("이미 공개돼 있고
오늘 바뀐 사실")을 대신 썼다: `llvm/llvm-project`는 시간당 커밋이 랜딩되는 공개 리포이므로,
오늘 HEAD는 cached 인덱스가 가질 수 없는 사실이다. SHA와 TITLE을 함께 요구한 것은, 그럴듯한
16진수 문자열은 지어낼 수 있어도 그것과 정확히 짝이 맞는 커밋 제목은 지어낼 수 없기 때문이다.

## 왜 `web_search` item 출현으로 판별하지 않는가

`--json` 스트림의 `web_search` item은 **cached 인덱스 조회에서도 나타난다** — 모드 승격의 증거가
아니다. 그래서 이 probe는 item 출현이 아니라 "cached가 가질 수 없는 사실"(오늘자 HEAD)을 직접
물었다. 실측이 이 설계를 그대로 뒷받침한다 — 아래 "실측 결과" 참조: item은 24회 출현했지만
반환된 사실은 12일 stale이었다. item 출현만으로 판별했다면 "많이 검색했으니 live"로 오판했을
것이다.

## 실행 경위 — 총 3회 (1차 죽음 + 2차 조건 A 완결 + 3차 조건 B 완결)

**1차 호출 (조건 A, 1차 시도) — 죽은 시도, 데이터 폐기.**
`codex exec - -C "$PWD" -s read-only -c 'tools.web_search=true' --json < prompt.md`를
Bash 도구 타임아웃 180000ms(3분)로 실행했다. codex가 최종 답을 내기 전에 SIGTERM으로
죽었다(`rc=143`). 죽기 전 이미 **20개 이상의 item이 완료**돼 있었다 — 스킬 파일 로드(2건),
`web_search` 8건(다양한 URL/쿼리 시도: GitHub API, atom feed, jina.ai 리더 프록시,
`api.github.com/search/repositories` 등), 브라우저 연결 시도 1건(`mcp_tool_call` — "No browser
is available"로 실패), 그 외 다수. 최종 `agent_message`가 없어 SHA/TITLE을 얻지 못했다.
이 죽은 시도는 probe 설계의 결함이 아니라 **실행자(에이전트)의 타임아웃 설정 실수**다 —
그러나 죽기 전 이미 실제 API 턴(다수의 web_search·도구 호출)이 진행됐으므로 청구는 이미
발생했을 것으로 판단해, 이 시도를 실제 codex 호출 1회로 집계한다. 이 시도의 JSONL/응답
데이터는 판정에 쓰지 않는다(불완전).

**2차 호출 (조건 A, 재시도) — 완결.**
동일 커맨드를 타임아웃 580000ms(약 9분 40초)로 재실행. `rc=0`, `turn.completed` 관측(28줄
JSONL, `item.completed` 13건 — 대부분 `web_search`). 최종 `agent_message`:

```
SHA=b443896c13aded8b40d7bae4a5a9adbc96fd0d31
TITLE=[VPlan] Use pointee-range in blocksOnly (NFC) (#212441)
```

이 시점에서 원래 예산 2회가 전부 소진됐다 — 조건 (B)는 아직 실행 전이었다. 컨트롤러가 이
결과를 `gh api`로 독립 검증한 뒤(동일한 SHA·date·title), 3번째 실제 codex 호출을 명시
승인했다.

**3차 호출 (조건 B, `+ -c web_search="live"`) — 완결, 승인된 3번째 호출.**
동일 프롬프트(byte-identical — 재생성 후 재확인), 타임아웃 600000ms(10분)로 1회 실행.
`rc=0`, `b.err` 빈 파일(설정 키 거부 없음 — `web_search="live"`는 유효한 키였다). 26줄
JSONL, `turn.completed` 관측. 최종 `agent_message`(정확히 두 줄이라는 지시를 codex가
완전히 지키지는 않아 앞에 설명 문장 2줄이 붙었으나 `SHA=`/`TITLE=` 두 줄은 그대로 추출
가능):

```
SHA=1a08c406424935e6afeca30d47cd2c0c853f4a53
TITLE=[ORC] Remove CallViaEPC.h and CallSPSViaEPC.h (#215086)
```

## 검증 (`gh api`, 출력 verbatim)

**조건 (A):**
```
$ gh api "repos/llvm/llvm-project/commits/b443896c13aded8b40d7bae4a5a9adbc96fd0d31" \
    --jq '"\(.sha[0:12])  \(.commit.author.date)  \(.commit.message|split("\n")[0])"'
b443896c13ad  2026-07-28T10:18:20Z  [VPlan] Use pointee-range in blocksOnly (NFC) (#212441)
```

SHA는 실재하는 커밋으로 resolve됐고 TITLE도 codex의 답변과 정확히 일치한다. 그러나
author date(`2026-07-28T10:18:20Z`)는 오늘(`2026-08-09`)보다 **12일 전**이다 — 판정
기준 3항("resolves but the date is old") 그대로: stale index이지 live가 아니다.

**조건 (B):**
```
$ gh api "repos/llvm/llvm-project/commits/1a08c406424935e6afeca30d47cd2c0c853f4a53" \
    --jq '"\(.sha[0:12])  \(.commit.author.date)  \(.commit.message|split("\n")[0])"'
1a08c4064249  2026-08-09T12:02:43Z  [ORC] Remove CallViaEPC.h and CallSPSViaEPC.h (#215086)
```

SHA resolve, TITLE 정확히 일치, author date `2026-08-09T12:02:43Z` — **오늘**. 판정 기준
1항("resolves & dated today") 충족: **live 웹에 실제로 닿았다.**

## 측정된 수치 — cached-vs-live lag: 약 12일

조건 (A)가 돌아온 시점 커밋(`2026-07-28T10:18:20Z`)과 조건 (B)가 돌아온 실제 오늘자 HEAD
(`2026-08-09T12:02:43Z`) 사이의 간격은 **정확히 12일 1시간 44분**이다. 이것은 이 probe의
가장 날카로운 증거다 — (A)가 "검색을 못 했다"거나 "거부했다"가 아니라, **진짜로 존재하는
인덱스를 갖고 있되 그 인덱스가 약 12일 지연**돼 있다는 것을 직접 잰 것이다. SHA가 실재
커밋으로 resolve되고 TITLE까지 정확히 일치한 것 자체가 이미 "환각이 아니다"의 증거였고,
그 커밋이 정확히 얼마나 stale한지(12일)까지 이번에 (B)로 측정할 수 있었다. 공식 문서의
"OpenAI-maintained index without external web access"라는 서술과 정합적이다 — cached는
부재가 아니라 지연된 실재 인덱스다.

## `web_search` item 출현 횟수 (참고용 — 판별에 쓰지 않음)

| 조건 | item 출현 횟수 | 반환된 사실의 신선도 |
|---|---|---|
| (A) 단독 | 24회 (28줄 중) | 12일 stale |
| (B) `+live` | 12회 (26줄 중) | 오늘(정확) |

item 출현 횟수는 위에서 설명한 이유(cached 조회에서도 나타남)로 판별에 쓰지 않는다 — 이번
실측이 그 근거를 그대로 실증한다: (A)가 (B)보다 **item을 두 배 더 많이 냈지만** 반환한
사실은 더 stale했다. item 개수만으로 판별했다면 "더 많이 검색한 (A)가 더 live"라는
정반대의 오판을 했을 것이다. 판별력은 오직 "cached가 가질 수 없는 사실"(오늘자 HEAD)을
직접 물어 `gh api`로 기계적으로 검증하는 데서 나온다.

## 판정표

| 조건 | 실행 여부 | SHA 반환 | resolve (`gh api`) | author date | 판정 |
|---|---|---|---|---|---|
| (A) `tools.web_search=true` 단독 | 실행(원 예산 2회 중 2회 — 1차 죽음, 2차 완결) | ✅ | ✅ 실재 커밋 | `2026-07-28` (12일 전) | **stale — live 아님** |
| (B) `+ web_search="live"` | 실행(승인된 3차 호출) | ✅ | ✅ 실재 커밋 | `2026-08-09` (오늘) | **live 도달 확인** |

## 최종 판정: (A) 실패, (B) 성공 — 도구만으로는 cached에 머문다

컨트롤러 판정표의 두 번째 행이 확정됐다: **"(A) 실패, (B) 성공 → 도구만으로는 cached에
머문다."** `tools.web_search=true` 단독으로는 (진짜 인덱스를 갖고 있지만) 약 12일 지연된
cached 상태에 머물고, `web_search="live"`를 명시적으로 추가해야 실제 오늘자 웹에 닿는다.

**Task 18 분기**: 웹이 필요한 3개 호출부에 `web_search="live"`를 **추가**한다(기존
`tools.web_search=true`는 유지 — 도구 자체는 필요하다). 웹이 불필요한 3곳에는
`web_search="disabled"`를 명시한다.

## 보존하지 않는 것 (P21)

원시 프롬프트 전문·전체 JSONL은 남기지 않는다. 남기는 것은 실행한 플래그·최종 답변 두 줄·
`gh api` 검증 출력·item 카운트·rc/타임아웃 값뿐이다.
