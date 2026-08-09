# V1 — codex 웹 모드 probe (3단계 §5.3② 게이트)

- 대상 커밋: `55d97e2dd7ddcb927c59788dde76bc8fd1535735`
- codex: `codex-cli 0.147.0`
- 실제 codex 호출: **2회** — 예산(2회) 전량 소진, **둘 다 조건 (A)를 얻는 데 쓰였다**. 조건 (B)는
  한 번도 실행하지 않았다. 사유는 아래 "실행 경위" 절.

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

## 실행 경위 — 예산 2회가 조건 (A) 하나에 전부 쓰였다

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

이 시점에서 예산 2회가 전부 소진됐다. **조건 (B)(`+ web_search="live"`)는 한 번도 실행하지
않았다.**

## 검증 (`gh api`, 출력 verbatim)

```
$ gh api "repos/llvm/llvm-project/commits/b443896c13aded8b40d7bae4a5a9adbc96fd0d31" \
    --jq '"\(.sha[0:12])  \(.commit.author.date)  \(.commit.message|split("\n")[0])"'
b443896c13ad  2026-07-28T10:18:20Z  [VPlan] Use pointee-range in blocksOnly (NFC) (#212441)
```

SHA는 실재하는 커밋으로 resolve됐고 TITLE도 codex의 답변과 정확히 일치한다. 그러나
author date(`2026-07-28`)는 오늘(`2026-08-09`)보다 **12일 전**이다 — 판정 기준 3항
("resolves but the date is old") 그대로: stale index이지 live가 아니다. `llvm/llvm-project`는
시간당 커밋이 랜딩되므로, 12일 전 커밋은 "가장 최근 커밋"일 수 없다.

## `web_search` item 출현 횟수 (참고용 — 판별에 쓰지 않음)

2차(완결) 실행 JSONL: `"web_search"` 문자열 **24회** 출현 (전체 28줄 중). 이 숫자는 위에서
설명한 이유로 판별에 쓰지 않는다 — 이번 실측이 그 이유를 실증한다(item 24회 vs 반환 사실
12일 stale).

## 판정표

| 조건 | 실행 여부 | SHA 반환 | resolve (`gh api`) | author date | 판정 |
|---|---|---|---|---|---|
| (A) `tools.web_search=true` 단독 | 실행(예산 2회 중 2회가 다 여기 쓰임 — 1차 죽음, 2차 완결) | ✅ | ✅ 실재 커밋 | `2026-07-28` (12일 전) | **stale — live 아님** |
| (B) `+ web_search="live"` | **미실행** (예산 소진) | — | — | — | — |

## 최종 판정: 판정 불가 (예산 소진, Task 18 분기 미확정)

컨트롤러 판정표는 세 갈래다: (A) 성공 dated-today / (A) 실패 + (B) 성공 dated-today / 둘 다
실패. 이번 실측은 **(A)가 확실히 실패**(resolve는 됐으나 stale)했다는 것까지는 기계적으로
확정했다. 그러나 (B)를 한 번도 태우지 못했으므로 "(A) 실패, (B) 성공 → Task 18이
`web_search="live"` 추가" 행과 "둘 다 실패 → 판정하지 않는다" 행을 구별할 수 없다.
**Task 18의 분기를 이 문서가 확정할 수 없다.** "판정 불가"는 그 자체로 정당한 결과이며,
연화해서 결론으로 포장하지 않는다.

**다음 단계**: 조건 (B) 1회(`+ web_search="live"`, 동일 프롬프트 — llvm/llvm-project 최신
커밋)를 추가로 태우면 판정이 완성된다. 이것은 원래 설계된 예산(2회) 밖의 **3번째 실제 codex
호출**이므로, 사용자 승인 없이 진행하지 않았다.

## 보존하지 않는 것 (P21)

원시 프롬프트 전문·전체 JSONL은 남기지 않는다. 남기는 것은 실행한 플래그·최종 답변 두 줄·
`gh api` 검증 출력·item 카운트·rc/타임아웃 값뿐이다.
