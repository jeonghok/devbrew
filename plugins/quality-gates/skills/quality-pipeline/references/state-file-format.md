# 로컬 결과 `result.md`

`.claude/quality-gates/<session-id>/result.md` 는 한 번의 `/qg` 가 남기는 로컬 결과다. 게시
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

## 지적

<합성기 표 원문 — 살아남은 지적 전부, SUGGESTION 포함>

## 제외 패치

<- iter <N> · #<k> · <file> · <사유> 줄들, 없으면 (없음)>

## 차등 테스트

<집계의 attribution_status · degrade_causes · resolution_disclosure · per_adapter 원문,
 없으면 (이번 실행에 차등 집계 없음)>

## 게시

<게시 펜스가 낸 줄 하나 — `posted: <url>` · `skipped: <사유>` · `skipped: aborted` · `게시 안 함 — …` ·
 `게시 결과 불명 — sink 출력 계약 위반(rc N)`>
```

## 생명주기

1. **만든다** — `scripts/setup-qg.sh` 가 매 실행 세션 폴더를 새로 만들고 frontmatter 와 `# qg result`
   제목만 쓴다.
2. **덧붙인다** — 파이프라인이 Final verdict 에서 위 순서로 절을 `>>` 로 덧붙인다. frontmatter 는
   고치지 않는다. 그 뒤 `## Publish` 의 게시 펜스가 끝에 `## 게시` 를 덧붙인다.
3. **지운다** — `scripts/qg-gc.py` 가 TTL(기본 24시간)이 지난 세션 폴더를 지운다. `result.md` 가
   세션 폴더의 표지다.

같은 폴더의 다른 파일 — `intent.md`(의도 출처 본문) · `excluded.md`(제외 패치 누적) ·
`aggregate.yaml`(마지막 차등 집계) · `verdict.out` · `topic-scope.txt` · `runtime-evidence.md`
(차등 테스트 원장) · `comment-head.md` · `comment.md` · `publish.out` · `publish.err`(게시) — 도 같은 생명주기를 따른다.
