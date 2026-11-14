# 로컬 결과 `result.md`

`.claude/quality-gates/<session-id>/result.md` 는 한 번의 `/quality-gates:quality-pipeline` 이 남기는 로컬 결과다. 게시
코멘트에 실리지 않는 것 — 지적 전부(SUGGESTION 포함) · 제외 패치 · 차등 요약 — 이 여기 남는다.

`<session-id>` 는 `$CLAUDE_CODE_SESSION_ID` 이고 `[A-Za-z0-9_-]{8,}` 를 통과해야 한다. 형제 폴더는
다른 세션의 것이다 — 건드리지 않는다.

## 형식

```markdown
---
session_id: "<sid>"
started_at: "<ISO-8601 UTC>"
---

# qg result

## 판정

<verdict.py 출력 원문 — verdict: · reason: · reasons: 줄과 판정 줄>

## 범위

<`range-scope.txt` 원문(mode · status · start · end · end_from · commits · files …) — 범위 모드일 때만>

## 문서 경로

<마지막 iteration 의 `review-i<N>.doc-paths` 요약 줄 — doc_paths_source · doc_paths · bad_patterns · excluded · kept_model —
 과 `self_state: <건너뛴 qg 상태 파일 수>`. 경로 목록(exclude · kept 줄)은 싣지 않는다>

## 지적

<합성기 표 원문 — 살아남은 지적 전부, SUGGESTION 포함>

## 낮춘 지적

<합성기 「낮춘 지적」 표 원문 — 번호 · 위치 · 원래 심각도 · 내용 · 낮춘 이유. 사용자가 되올린 행은 이유 칸 머리에 (사용자가 되올림) — 재비판이 낮춘 지적이 있을 때만>

## 제외 패치

<- iter <N> · #<k> · <file> · <사유> 줄들, 없으면 (없음)>

## 추가 반복

<- iter <N> 뒤 · 반복 하나 더 · <label|typed> · <원문> 줄들 — 반복 상한에서 사용자가 반복을 더 열었을 때만>

## 차등 테스트

<`differential.yaml` 의 attribution_status · degrade_causes · resolution_disclosure · per_adapter 원문과
 `differential-not-counted.md`(커버리지로 세지 않은 테스트), 없으면 (이번 실행에 차등 출력 없음)>

## e2e

<걷기마다 `### 걷기 <n>` 과 시나리오 · 증거표 · 판정안 · 게이트 선택 — e2e 를 걸었을 때만>

## 뒤집기

<- e2e: <판정안> → <결과> — <사람의 한 줄 사유> 줄들 — 사람이 걷기의 판정안을 뒤집었을 때만>

## 게시

<게시 펜스가 낸 줄 하나 — `posted: <url>` · `skipped: <사유>` · `skipped: aborted` · `게시 안 함 — …` ·
 `게시 결과 불명 — sink 출력 계약 위반(rc N)`. `게시 안 함 — …` 에는
 `게시 안 함 — 커밋 안 된 변경이 있다(판정이 PR 의 커밋과 다르다 — 커밋·푸시 뒤 다시 /quality-gates:quality-pipeline)` 와
 범위 모드의 `게시 안 함 — 범위 모드라 PR 코멘트를 달지 않는다(범위에는 열린 PR 이 없다)` 가 든다>

## intent-critic

intent-critic 은 의도대로 만들었는지가 아니라 의도 자체(사용자가 고른 방향 · 기능 · 동작)가 맞는지를 점검한다. 이 절은 판정에 들지 않는다.

<`intent_critic.py render` 가 쓰는 절 — 위 뜻 문장이 첫 줄이고, 그 아래 차례로:
 - 결과 줄 — `intent-critic — 근거 없음` · `intent-critic — 질문 없음` · `intent-critic — 리뷰어 출력을 읽지 못함(셀 수 없음)` ·
   `intent-critic — 질문 <k>개를 물었다 · 답 <n>개(잘못 골랐다 <w>개)`(답하지 않은 질문이 있으면 끝에 ` · 답하지 않음 <u>개`) · `intent-critic — 질문 <k>개 아직 묻지 않음(범위 모드)`
 - 공시 줄들 — `prepare` 의 공시(`원문 없음 — <이유>` · `로드맵 없음 — <이유>` · `첫 호출에 의심이 섞였다` · `한 번에 넣음 — …` · `차등 결과를 읽지 못함 — 근거로 세지 않았다` · `읽지 못한 답 파일 <n>` …), 그 뒤 `filter` · `record` 의 공시(`근거 없어 거름 <n>` · `이미 답한 질문이라 거름 <n>` · `상한 넘어 남김 <n>` · `답 기록 실패 <n>개 — <사유>` …). 근거 없음으로 끝난 실행에도 `prepare` 의 공시가 남는다
 - 커밋 줄 — `답 파일 <n>개를 커밋했다(<짧은 해시>)` · `답 파일을 커밋하지 못했다 — <사유>(파일은 남겼다)` — 답을 기록했을 때만
 - 표 `| 정체 | 상태 | 답 | 답 파일 | 질문 |` — 질문(답함 · 아직 묻지 않음 · 상한 넘어 남김)이 있을 때만. 범위 모드의 답 파일 칸은 `-`
 - 목록 `상한 넘어 남김:`(없으면 `- 없음`) · `이미 답한 질문이라 거른 질문:`(`- <정체> · <앞 답> · <답 파일>[ · 이 범위가 더한 답 파일 | · 범위 변경 여부를 확인하지 못함] — <질문>`) ·
   `이미 「잘못 골랐다」 답이 있어 거른 질문:` — 뒤 둘은 거른 질문이 있을 때만>
```

## 생명주기

1. **만든다** — `scripts/setup-qg.sh` 가 매 실행 세션 폴더를 새로 만들고 frontmatter 와 `# qg result`
   제목만 쓴다.
2. **덧붙인다** — 파이프라인이 Final verdict 에서 위 순서로 절을 `>>` 로 덧붙인다. frontmatter 는
   고치지 않는다. `## 범위` 는 세션 폴더에 `range-scope.txt` 가 있을 때(범위 모드)만 쓴다. `## 문서 경로` 는 마지막 반복의 `review-i<N>.doc-paths` 가 비어 있지 않을 때만 쓴다(trivia 로 Step 1c 전에 끝난 실행 · 기준선을 풀지 못한 실행에는 없다). `## 낮춘 지적` 은 마지막 합성 출력에 「낮춘 지적」 표가 있을 때만 쓴다. `## 추가 반복` 은 `extra-iterations.md` 가 비어 있지 않을 때만 쓴다. `## e2e` · `## 뒤집기` 는 `## e2e` 절이 세션 폴더의 `e2e-record.md` · `e2e-flip.md` 에
   쌓아 둔 것을 옮기고, 비었으면 절을 쓰지 않는다. 그 뒤 `## Publish` 의 게시 펜스가 끝에 `## 게시` 를 덧붙인다. `## 게시` 는 하나뿐이다 —
   이미 있으면 펜스는 덧붙이지 않고 `게시 안 함 — 이 실행은 이미 게시 단계를 돌았다` 만 출력한다. 그 뒤 intent-critic 단계가 끝에 `## intent-critic` 을 덧붙인다(하나뿐 — 이미 있으면 덧붙이지 않는다).
   이미 덧붙였는지는 세션 폴더의 `intent-rendered.txt` 로 정하고, 그때는 `intent-critic — 이 실행은 이미 intent-critic 단계를 돌았다` 만 출력한다.
   단계를 건너뛴 실행(kill switch · 멈춘 실행 · trivia · 빈 diff · 리뷰 트리를 만들지 못함)에는 이 절이 없다 — 건너뜀 줄은 출력과 `intent-return.md` 에만 있다.
3. **지운다** — `scripts/qg-gc.py` 가 TTL(기본 24시간)이 지난 세션 폴더를 지운다. `result.md` 가
   세션 폴더의 표지다.

같은 폴더의 다른 파일 — `intent.md`(의도 출처 본문) · `excluded.md`(제외 패치 누적) ·
`extra-iterations.md`(Max-iter decision 에서 사용자가 연 반복 — 승인 출처(label · typed)와 원문, 줄 수가 상한을 늘린다) ·
`differential.yaml`(마지막 iteration 의 차등 출력 사본) · `differential-not-counted.md`(커버리지로 세지 않은 테스트) ·
`verdict.out` · `topic-scope.txt` · `range-scope.txt`(P2b 가 얼린 범위 — 범위 모드일 때만) · `review-tree.txt`(범위 모드에서 리뷰어가 읽는 끝 커밋 임시 트리의 경로 — 범위 모드일 때만, 실행 끝에 트리와 함께 지운다) · `comment-head.md` · `comment.md` · `publish.out` · `publish.err`(게시) · `e2e-record.md` · `e2e-flip.md` ·
`e2e-evidence.tsv` · `e2e-cmd.txt` · `e2e-gate.txt` · `e2e-before.txt` · `e2e-after.txt` · `e2e-app.pgid` · `e2e-app.log`(e2e) ·
`review-i<N>.names` · `review-i<N>.full.diff` · `review-i<N>.diff` · `review-i<N>.doc-paths` · `review-i<N>.self-state`(Review Step 1c 의 리뷰 diff — iteration 마다) —
도 같은 생명주기를 따른다.

`intent-*`(intent-critic 단계의 실행 파일 — 이름과 내용은 `scripts/intent_critic.py` 와 [intent-critic 절차](intent-critic.md)가 정한다)는
판정 · 게시 뒤에만 생기고 다음 실행의 Preflight P2 가 지운다. 답 파일은 세션 폴더가 아니라 docs 답 자리에 산다(레포 설정 `DEVBREW_QUALITY_GATES_INTENT_ANSWERS_DIR`, 기본
`docs/qg-intent-answers` — `record` 가 쓰고 그 파일만 커밋한다).
