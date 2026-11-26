# 로컬 결과 `result.md`

`.claude/quality-gates/<session-id>/result.md` 는 한 번의 `/quality-gates:quality-pipeline` 이 남기는 로컬 결과다. 게시
코멘트에 실리지 않는 것 — 지적 전부(SUGGESTION 포함) · 고칠 목록 · 차등 요약 — 이 여기 남는다.

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

<`review-i1.doc-paths` 요약 줄 — doc_paths_source · doc_paths · bad_patterns · excluded · kept_model —
 과 `self_state: <건너뛴 qg 상태 파일 수>`. 경로 목록(exclude · kept 줄)은 싣지 않는다>

## 지적

<합성기 표 원문 — 살아남은 지적 전부, SUGGESTION 포함>

## 낮춘 지적

<합성기 「낮춘 지적」 표 원문 — 번호 · 위치 · 원래 심각도 · 내용 · 낮춘 이유. 사용자가 되올린 행은 이유 칸 머리에 (사용자가 되올림) — 재비판이 낮춘 지적이 있을 때만>

## 고칠 목록

<Step 4.5 의 고칠 목록 — `### 막는 지적` · `### 제안` · `### 차등 회귀` 세 절, 빈 절은 (없음)>

## 차등 테스트

<`differential.yaml` 의 attribution_status · degrade_causes · resolution_disclosure · per_adapter 원문과
 `differential-not-counted.md`(커버리지로 세지 않은 테스트), 없으면 (이번 실행에 차등 출력 없음)>

## e2e

<걷기마다 `### 걷기 <n>` 과 시나리오 · 증거표 · 판정안 · 게이트 선택 — e2e 를 걸었을 때만>

## 뒤집기

<- e2e: <판정안> → <결과> — <사람의 한 줄 사유> 줄들 — 사람이 걷기의 판정안을 뒤집었을 때만>

## 게시

<게시 펜스가 낸 줄 하나 — `posted: <url>` · `skipped: <사유>` · `게시 안 함 — …` ·
 `게시 결과 불명 — sink 출력 계약 위반(rc N)`. `게시 안 함 — …` 에는
 `게시 안 함 — 커밋 안 된 변경이 있다(판정이 PR 의 커밋과 다르다 — 커밋·푸시 뒤 다시 /quality-gates:quality-pipeline)` 와
 범위 모드의 `게시 안 함 — 범위 모드라 PR 코멘트를 달지 않는다(범위에는 열린 PR 이 없다)` 가 든다>

## intent-critic

intent-critic 은 의도대로 만들었는지가 아니라 의도 자체(사용자가 고른 방향 · 기능 · 동작)가 맞는지를 점검한다. 이 절은 판정에 들지 않는다.

<`intent_critic.py render` 가 쓰는 절 — 위 뜻 문장이 첫 줄이고, 그 아래 차례로:
 - 결과 줄 — `intent-critic — 근거 없음` · `intent-critic — 질문 없음` · `intent-critic — 리뷰어 출력을 읽지 못함(셀 수 없음)` ·
   `intent-critic — 질문 <k>개를 물었다 · 답 <n>개(잘못 골랐다 <w>개)`(답하지 않은 질문이 있으면 끝에 ` · 답하지 않음 <u>개`) · `intent-critic — 질문 <k>개 묻지 않음(범위 모드)` · `intent-critic — 질문 <k>개 묻지 않음(묻기 전에 끝남)` ·
   `intent-critic — 낸 후보 <n>개가 근거 확인에서 모두 걸러짐`(넓게 보는 리뷰에서만 — 좁은 리뷰는 같은 경우에 `intent-critic — 근거 없음`)
 - 공시 줄들 — `prepare` 의 공시(`원문 없음 — <이유>` · `로드맵 없음 — <이유>` · `첫 호출에 의심이 섞였다` · `한 번에 넣음 — …` · `차등 결과를 읽지 못함 — 근거로 세지 않았다` · `차등 결과의 꼴이 다르다 — 읽지 못한 부분은 근거로 세지 않았다` · `읽지 못한 답 파일 <n>` ·
   넓이의 `넓게 본다 — 범위 모드` · `넓게 본다 — 의도 문서가 바뀐 변경` · `바뀐 파일 목록이 없어 넓게 보지 않는다` · `의도 문서인지 확인 못 한 문서 <n> — 추적되지 않는다` ·
   다른 팀 읽기의 `다른 팀 읽기 실패 — <예외 이름>` · `상한 <c>바이트 — <m>개 중 <k>개만 실었다(뺀 것: …)` ·
   리뷰어를 부른 실행의 `입력 <a>바이트 · 다른 팀 기록 <b>바이트(상한 <c> — 나눠 부르기 판정에 넣지 않는다)` …), 그 뒤 `filter` · `record` 의 공시(`근거 없어 거름 <n>` ·
   `인용이 그 파일에 없어 거름 <n>` · `읽은 인용만 있어 거름 <n>` · `근거로 받지 않은 인용 <n>` · `이미 답한 질문이라 거름 <n>` · `상한 넘어 남김 <n>` · `머리 앞의 답 글을 읽지 못함 <n>줄` · `같은 질문 번호의 답 머리를 한 번만 받았다 — 더 나온 머리 <n>개` · `답 기록 실패 <n>개 — <사유>` 와 그 아래 질문마다의 `답 기록 실패 질문 — <정체> · 고른 답: <답> · 질문: <글>` …). 근거 없음으로 끝난 실행에도 `prepare` 의 공시가 남는다
 - 커밋 줄 — `답 파일 <n>개를 커밋했다(<짧은 해시>)` · `답 파일을 커밋하지 못했다 — <사유>(파일은 남겼다)` — 답을 기록했을 때만
 - 표 `| 정체 | 상태 | 근거 | 답 | 답 파일 | 질문 |` — 질문(상태 다섯 — 답함 · 답 기록 실패 · 답하지 않음 · 묻지 않음 · 상한 넘어 남김)이 있을 때만. 근거 칸은 그 질문이 선 근거의 종류
   (`돌려서 봄` · `다른 팀에서 봄` · `읽어서 봄` 을 ` · ` 로 이음 — 종류가 없는 앞 판 레코드는 `-`). 범위 모드의 답 파일 칸은 `-`
 - 다른 팀 목록 — 리뷰어를 부르지 않은 실행에도 늘 보인다. `other-teams.md` 가 있으면 `다른 팀과 겹치는 곳:`(그 기록의 `## 겹치는 곳` 줄 그대로 —
   `- <브랜치>[ · PR #<n> <제목> · …] — <겹치는 경로> · …` 줄들, 겹침을 봤는데 없으면 `- 겹침 없음`, 확인하지 못했으면 `- 겹침 확인 못 함`)과
   `다른 팀 확인 못 함:`(그 기록의 `## 확인 못 함` 줄 그대로). 기록에서 절이 비었으면 그 목록 아래 `- 기록에서 이 절을 읽지 못함`.
   목록 줄은 기록의 `## 팀 지도` 앞까지만 읽는다 — 다른 브랜치의 본문은 목록 줄이 되지 못한다. 기록이 없으면 두 목록 대신 `- 다른 팀 기록 없음`
 - 목록 `상한 넘어 남김:`(없으면 `- 없음`) · `이미 답한 질문이라 거른 질문:`(`- <정체> · <앞 답> · <답 파일>[ · 이 범위가 더한 답 파일 | · 범위 변경 여부를 확인하지 못함] — <질문>`, 넘겨받은 항목은 `- <정체> · <앞 답> · <넘겨받은 기록 파일> · 넘겨받은 답[ · 미뤄 둔 의심][ · 정체가 다름 — <그때> → <지금>] — <질문>`) ·
   `이미 「잘못 골랐다」 답이 있어 거른 질문:` — 뒤 둘은 거른 질문이 있을 때만>
```

## 생명주기

1. **만든다** — `scripts/setup-qg.sh` 가 매 실행 세션 폴더를 새로 만들고 frontmatter 와 `# qg result`
   제목만 쓴다.
2. **덧붙인다** — 파이프라인이 Final verdict 에서 위 순서로 절을 `>>` 로 덧붙인다. frontmatter 는
   고치지 않는다. `## 범위` 는 세션 폴더에 `range-scope.txt` 가 있을 때(범위 모드)만 쓴다. `## 문서 경로` 는 `review-i1.doc-paths` 가 비어 있지 않을 때만 쓴다(trivia 로 Step 1c 전에 끝난 실행 · 기준선을 풀지 못한 실행에는 없다). `## 낮춘 지적` 은 마지막 합성 출력에 「낮춘 지적」 표가 있을 때만 쓴다. `## e2e` · `## 뒤집기` 는 `## e2e` 절이 세션 폴더의 `e2e-record.md` · `e2e-flip.md` 에
   쌓아 둔 것을 옮기고, 비었으면 절을 쓰지 않는다. 그 뒤 `## Publish` 의 게시 펜스가 끝에 `## 게시` 를 덧붙인다. `## 게시` 는 하나뿐이다 — 다시 돌리면 펜스가 그 절을 그 실행의 결과로 바꿔 쓴다.
   바꿔 쓸 자리는 처음 덧붙일 때 `publish-at.txt` 에 적은 자리이고(결과 파일 안의 `## 게시` 글자로 찾지 않는다), 그 자리가 결과 파일과 맞지 않으면 덧붙이지도 바꿔 쓰지도 않고 알림 한 줄을 낸다.
   「이미 게시함」 은 GitHub 에서 정한다 — 게시 sink 가 이 PR 에 지금 gh 계정이 단 같은 본문의 댓글을 찾으면 `skipped: already-posted` 다. 결과 파일의 `## 게시` 절은 사람이 읽게 남기는 것이고 게시 여부를 정하지 않는다. 그 뒤 intent-critic 단계가 끝에 `## intent-critic` 을 덧붙인다(하나뿐 — 이미 있으면 덧붙이지 않는다).
   이미 덧붙였는지는 세션 폴더의 `intent-rendered.txt` 로 정하고, 그때는 `intent-critic — 이 실행은 이미 intent-critic 단계를 돌았다` 만 출력한다.
   단계를 건너뛴 실행(kill switch · 멈춘 실행 · trivia · 빈 diff · 리뷰 트리를 만들지 못함)에는 이 절이 없다 — 건너뜀 줄은 출력과 `intent-return.md` 에만 있다.
3. **지운다** — 세션 폴더는 같은 세션의 다음 qg 시작에 지워진다(`scripts/setup-qg.sh`). 그 세션이 qg 를 다시 부르지 않으면, 폴더가 정리 기한(기본 24시간)보다 오래된 뒤 어느 세션이든 qg 를 시작할 때 지워진다(`scripts/qg-gc.py`). `result.md` 가 세션 폴더의 표지다.

같은 폴더의 다른 파일 — `intent.md`(의도 출처 본문) ·
`differential.yaml`(차등 출력 사본) · `differential-not-counted.md`(커버리지로 세지 않은 테스트) ·
`verdict.out` · `topic-scope.txt` · `range-scope.txt`(P2b 가 얼린 범위 — 범위 모드일 때만) · `review-tree.txt`(범위 모드에서 리뷰어가 읽는 끝 커밋 임시 트리의 경로 — 범위 모드일 때만, 실행 끝에 트리와 함께 지운다) · `comment-head.md` · `comment.md` · `publish.out` · `publish.err` · `publish-at.txt`(게시 — 마지막 것은 게시 절 자리: 시작 바이트와 길이 바이트를 적은 한 줄) · `e2e-record.md` · `e2e-flip.md` ·
`e2e-evidence.tsv` · `e2e-cmd.txt` · `e2e-gate.txt` · `e2e-before.txt` · `e2e-after.txt` · `e2e-app.pgid` · `e2e-app.log`(e2e) ·
`review-i1.names` · `review-i1.full.diff` · `review-i1.diff` · `review-i1.doc-paths` · `review-i1.self-state` · `review-i1.mode`(Review Step 1c 의 리뷰 diff 와 그 실행이 쓴 범위 모드) ·
`other-teams.md`(intent-critic 단계의 다른 팀 기록 — 팀 지도 · 진행 중인 의도 문서 · 겹치는 diff · 확인 못 함) ·
`suite-overlap.txt`(차등 테스트의 겹침 기록 — 잠금 감싸개가 겹친 테스트 명령마다 탭으로 나눈 한 줄을 덧붙인다: 잡혀 있었으면 busy · 주인 · 잡은 시각, 쓸 수 없었으면 unusable · - · -) —
도 같은 생명주기를 따른다.

`suite-lock-path.txt`(공유 스위트 잠금 폴더의 절대경로 한 줄 — `--suite-lock` 이 있을 때만)는 쓰는 쪽이 `setup-qg.sh` 하나다 — 시작마다(`--ensure` 로 폴더를 그대로 둘 때도) 지우고 인자가 있으면 다시 쓴다. 그래서 Preflight P2 의 지우기 목록에는 들지 않는다. 읽는 쪽은 잠금 감싸개다.

`review-i1-slot-<리뷰어>-b<B>-t<T>-<칸>.txt`(Review Step 3 · 3.5 가 리뷰어에게 경로로 넘기는 칸 사본 — 원본 끝에 `qg-slot-end: <값>` 줄을 붙였다. 리뷰어는 `security` · `ext-<짧은 이름>` · `recritic`, 칸은 `intent` · `diff` · `findings` · `scope`)도 같은 생명주기를 따른다 — Preflight P2 의 `review-i*` 지우기가 지운다. 리뷰어 응답 사본은 세션 폴더가 아니라 실행 임시 폴더 `RV` 에 있다.

`artifact-critique/`(문서 비평 `/quality-gates:artifact-critique` 의 몫 폴더 — 대상 `T` · 라운드 `R` 마다 병합된 지적 원본 `merged-t<T>-r<R>.yaml`, 반박자에게 경로로 넘기는 끝 값 사본 `merged-t<T>-r<R>-slot.txt`, 반박자 응답 전체 `adversarial-t<T>-r<R>.txt`)는 문서 비평이 `setup-qg.sh --ensure` 로 얻은 세션 폴더 아래에 산다 — 세션 마커 `result.md` 가 선 폴더라 정리(`qg-gc.py`) · 같은 세션의 다음 qg 시작이 폴더째 지운다. Preflight P2 의 지우기 목록에는 들지 않는다.

`intent-*`(intent-critic 단계의 실행 파일 — 예: 리뷰어의 넓이 칸 `intent-scope.md`, 리뷰어에게 경로로 넘기는 칸 사본 `intent-slot-<k>-<칸>.md`(`slots` 가 원본 끝에 `qg-slot-end: <값>` 줄을 붙인다 — `k` 는 `1` 첫째 호출 · `2` 둘째 · 한 번에 넣은 호출). 이름과 내용은 `scripts/intent_critic.py` 와 [intent-critic 절차](intent-critic.md)가 정한다)와
`other-teams.md` 는 판정 · 게시 뒤에만 생기고 다음 실행의 Preflight P2 가 지운다. 답 파일은 세션 폴더가 아니라 docs 답 자리에 산다(레포 설정 `DEVBREW_QUALITY_GATES_INTENT_ANSWERS_DIR`, 기본
`docs/qg-intent-answers` — `record` 가 쓰고 그 파일만 커밋한다).

## 돌려주는 꼴 — `intent-return.md` (3판)

쓰는 쪽은 `intent_critic.py` 의 `gate`(건너뜀 줄) · `prepare`(꺼짐 줄 · 건너뜀) · `render`(실행 끝) 이다. 파일은 펜스 `qg-intent-return` 하나로 이루어진다. 읽는 쪽은 `contract` 가 모르는 판이면 읽지 않고 그 사실을 알린다. `contract` 칸이 없는 파일은 1판이다. 글 칸은 한 줄로 접혀 따옴표에 싸이고, 닫힌 어휘 칸은 따옴표 없이 쓴다. 펜스 안은 YAML 이다 — 없음 표지 `-` 는 따옴표에 싸여 나간다(`reason: "-"`).

부르는 쪽은 이 파일에서 시작해 `session_dir` 로, 거기서 `other_teams` 로 내려간다. 내부 파일(`intent-questions.yaml`)은 읽지 않는다. 나중에 쓸 부르는 쪽이 가져갈 것은 이 파일과(다른 팀 기록이 필요하면) `session_dir` 아래 `other_teams` 값의 파일 둘이다.

- 머리 칸(차례대로): `contract` · `status` · `reason` · `reason_text` · `outcome` · `result_line` · `none_reason` · `mode` · `reviewed_head` · `reviewed_base` · `session_dir` · `answers_dir` · `answers_dir_source` · `commit` · `breadth` · `other_teams` · `overlaps` · `answered_filtered` · `questions`
- 질문 칸(차례대로): `n` · `id` · `state` · `answer` · `answer_text` · `wrong_choice` · `failure` · `file` · `evidence` · `question` · `target_source` · `target_id` · `label` · `quote` · `observation` · `why` · `asked_before` · `changed_observation`
- 칸 `status` 의 값: `ran` · `uncountable` · `skipped` · `failed`
- 칸 `reason` 의 값(skipped): `kill-switch` · `halted` · `trivia` · `empty-diff` · `no-evidence`
- 칸 `reason` 의 값(failed): `tree-failed`
- 칸 `outcome` 의 값(ran): `questions` · `none` · `no-evidence` · `all-filtered`
- 질문 칸 `state` 의 값: `답함` · `답 기록 실패` · `답하지 않음` · `묻지 않음` · `상한 넘어 남김`

머리 칸의 뜻:

- `contract` — 꼴의 판(`3`).
- `status` · `reason` · `reason_text` — 실행의 갈래와, 건너뛰었거나 실패한 까닭의 닫힌 부호 · 사람이 읽는 글. 그 밖의 갈래는 `reason` 이 `-` 다(`uncountable` 의 `reason_text` 는 공시 줄의 첫 줄).
- `outcome` — `ran` 일 때 질문이 왜 있고 없는지. 그 밖은 `-`. `none` 은 리뷰어가 질문을 내지 않은 실행과 낸 질문이 모두 이미 답한 질문이라 걸러진 실행을 함께 뜻한다. 걸러진 질문의 목록은 이 파일에 없고 `result.md` 의 `## intent-critic` 절에만 있다.
- `result_line` · `none_reason` — 사람에게 보인 결과 줄 그대로 · 리뷰어가 질문이 없다고 낸 이유(없으면 `-`).
- `mode` · `reviewed_head` · `reviewed_base` — 범위 모드 여부(`pr` · `range`, 모르면 `-`)와, `prepare` 때 커밋 해시로 풀어 둔 리뷰 커밋 · 기준 rev(풀지 못하면 `-`).
- `session_dir` · `other_teams` — 세션 폴더의 절대경로 · 그 아래 다른 팀 기록 파일의 이름(없으면 `-`).
- `answers_dir` · `answers_dir_source` · `commit` — docs 답 자리와 그 값의 출처 · 답 커밋(없으면 `-`, 못 했으면 `failed — …`).
- `breadth` · `overlaps` — 리뷰의 넓이(`narrow` · `range` · `intent-docs`) · 다른 팀과 겹치는 곳의 수(모르면 `-`).
- `answered_filtered` — 이미 답해 거른 질문의 수(정수). 건너뜀 · 셀 수 없음은 `-`. 질문이 모두 걸러진 실행도 그 수다. 걸러진 질문의 목록은 이 파일에 없고 `result.md` 의 `## intent-critic` 에만 있다.
- `questions` — 질문 목록.

질문 칸의 뜻:

- `n` · `id` — 한 실행 안에서 유일한 질문 번호(1부터) · 질문의 정체(한 실행 안에서 겹칠 수 있다).
- `state` — 위 다섯 값. `답함` 은 답 파일이 기록됐다 · `답 기록 실패` 는 입력에 답이 있었는데 기록하지 못했다 · `답하지 않음` 은 물었고 답 기록이 돌았는데 그 질문의 답이 없었다 · `묻지 않음` 은 범위 모드이거나 묻기 전에 끝났다 · `상한 넘어 남김` 은 상한 때문에 묻지 못했다.
- `answer` · `answer_text` — 고른 답(기록에 실패한 답도 싣는다) · 직접 쓴 답의 원문 줄 목록(선택지를 골랐으면 `-`).
- `wrong_choice` — 고른 답이 「잘못 골랐다」 면 `true`, 아니면 `false`. 기록에 실패했어도 같다.
- `failure` · `file` — 답 기록 실패의 사유 · 답 파일 경로(없으면 `-`).
- `evidence` — 그 질문이 선 근거의 종류.
- `question` · `target_source` · `target_id` · `label` · `quote` · `observation` — 질문 기록의 같은 칸. `observation` 은 관찰 줄 전부의 목록이다.
- `why` — 리뷰어가 쓴 「왜 묻나」 한 줄 그대로(적지 않았거나 한 줄이 아니면 `-`).
- `asked_before` — 리뷰어가 이미 답한 의심과 같다고 가리켰는데 다시 묻는 질문이면 `<전 답> · <답한 때> · <열쇠 또는 정체> · <근거가 달라짐 | 고친 뒤에도 보임>`, 그 밖은 `-`. 둘째 칸은 저장된 `answered_at` 그대로(날짜가 앞이다)이고, 셋째 칸은 넘겨받은 항목이면 그 열쇠 · 답 폴더에서 읽은 답이면 그 답의 정체다.
- `changed_observation` — `근거가 달라짐` 인 질문은 목록이고 그 첫 항목이 화면에 싣는 한 구절(지금의 근거 첫 항목을 한 줄로 접어 자른 것)이다. 그 뒤로 이전 관찰(`이전 관찰: …`) · 지금의 근거 줄 · 읽은 인용이 온다. 그 밖은 `-`.
