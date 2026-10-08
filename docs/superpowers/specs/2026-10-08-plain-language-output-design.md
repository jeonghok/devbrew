---
name: plain-language-output
type: design
created_at: 2026-10-08
source_interview: docs/superpowers/interview/2026-10-03-plain-language-output-interview.md
next_phase: superpowers:writing-plans
---

# 쉬운 말 출력 · Design

> 처음 보는 사람이 한 번에 읽고, 꼭 알아야 할 것만 남는 글.

## Handoff Context

**TL;DR** — devbrew 네 플러그인이 돌 때 사람에게 보이는 글을 쉽게, 짧게 바꾼다. 세 갈래로 한다.

1. 모델이 쓰는 글: 모든 SKILL.md·명령 파일 맨 앞에 같은 「사람에게 쓰는 글」 규칙 블록을 둔다.
2. 스크립트가 내는 글: 첫 줄을 스크립트가 계산한 쉬운 상태 문장으로 바꾸고, 0인 집계는 내지 않는다.
3. 스킬이 시키는 질문·보고 틀: 질문 하나에 결정 하나만 담고, 경고 목록은 질문 앞으로 옮긴다.

프로그램이 글자로 읽는 줄 13군데는 형태를 바꾸지 않는다. 한 브랜치에서 PR 네 개로 차례로 머지한다.

**Implicit context** —

(1) 문제공간은 interview brief(`source_interview`)가 확정했다. 그 brief 의 confirmed 항목(C1~C11 · D12~D22)이 이
설계의 제약이다. **재결정 규약: confirmed 항목은 근거가 있으면 보고한 뒤 재결정할 수 있고, 임의 변경은 금지다.**

(2) 작업 위치: 브랜치 `feature/plain-language-voice`, 워크트리
`/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice`, base `77371d41`(#186 머지).

(3) brief 가 열어 둔 질문(OQ10~OQ20)은 이 설계의 brainstorming 에서 사용자가 고르거나 근거로 정했다 —
「결정 기록」 B1~B9.

(4) 이 문서 자체도 새 규칙의 대상이다 — 번호는 내용 뒤 괄호에 둔다.

## 목차

- [Goal](#goal) · [Context / Why](#context--why) · [Goals](#goals) · [Non-goals](#non-goals) ·
  [Constraints](#constraints) · [설계](#설계) · [Acceptance Criteria](#acceptance-criteria) ·
  [Files to Modify](#files-to-modify) · [Verification Plan](#verification-plan) ·
  [Rejected Alternatives](#rejected-alternatives) · [알려진 한계](#알려진-한계) · [결정 기록](#결정-기록) ·
  [Metadata](#metadata)

## Goal

devbrew 가 돌 때 사람에게 보이는 글을 처음 보는 사람이 한 번에 이해하고, 터미널에 나오는 글의 양이 꼭 필요한
만큼으로 준다. 판정을 스크립트가 정하는 장치, 실패와 「셀 수 없음」을 드러내는 장치, 원문을 보존하는 장치는
약해지지 않는다.

## Context / Why

사용자가 지난 세션들에서 「이거는 뭐를 하자는거야 쉽게 설명해」「한국어로 이야기해줘」를 실제로 말했다. 대표 사례는
「[미적용 fix] 3720b2b7#r1.1」(내부 상태 이름 + 알아볼 수 없는 기록 번호)과 「(codex 정상 · 재비판 정상 · 저자 편집
없음 · ask_open 0건)」(보고할 필요 없는 정상 나열)이다.

### 사용자가 말한 것 밖의 원인 (brief C10 이 요구한 조사)

2026-10-08 에 지난 세션 기록 776개(질문 966개)를 읽었다. 사용자가 한 답에서 직접 고른 진단 넷 — 「무엇을 결정하는지가
안 보인다, 용어·내부 식별자가 많다, 기술 사실의 설명이 없다, 선택의 결과가 안 보인다」 — 과 맞는 새 원인이 나왔다.

| 원인 | 크기 | 출처 |
|---|---|---|
| 보이는 글의 대부분이 도구 호출 사이의 진행 설명이다 | 약 70% (230만 자 대 최종 보고 99만 자) | 모델 글 |
| 질문이 엔진 상태 줄로 시작한다(「degrade 없음」「[decide] 해시」) | 질문 966개 중 206개(21%) | 스킬 틀 — 「모든 degrade 를 question 본문에 한 줄씩」 |
| 한 번에 여러 결정을 묻는다 | 호출 560번 중 185번(33%) | 모델 글 · 리뷰 라운드 틀 |
| 선택지 설명이 본문에 없던 새 주제를 꺼낸다 | 「2번은 무슨 이야기야?」 등 | 모델 글 |
| 지금 어디이고 무엇을 하면 되는지 안 말한다 | 사람 메시지의 9%가 「다 끝났어?」류 | 모델 글 |
| 보고·머리글이 영어로 바뀐다 | 영어 위주 최종 보고 147건, 영어 머리글 150개 | 모델 글 · 스킬 틀(「Proceed」) |
| 굵은 글씨·표 과다, 칸마다 문단과 `파일:줄` | 최종 글 1,000자당 굵은 글씨 6.8개 | 모델 글 |
| 판정 스크립트의 고정 문구가 영어이거나 0건 집계를 늘어놓는다 | qg 사람용 고정 문구 대부분 영어 | 스크립트 |

글의 양을 키우는 가장 큰 출처는 진행 설명이다. 질문이 어려워지는 가장 큰 출처는 스킬 틀이다. 스크립트 출력을 그대로
붙여 넣는 경우는 3% 뿐이다. 그보다 스크립트 어휘(「critic:fidelity:degraded」)를 문장에 섞어 쓰는 경우가 많다.
그래서 모델 글·스킬 틀·스크립트 셋을 함께 고친다.

### 배달 자리에 관한 사실

- 압축 뒤 스킬은 앞 5,000토큰만 다시 붙는다(스킬 여럿이면 합계 25,000) — 공식 문서 `skills` 절.
- 설치본에서 플러그인 캐시는 작업 디렉토리 밖이라, 경로로 알려 준 reference 를 읽으면 권한 질문이 뜬다. subagent 는
  거부된다(brief §5 · 메모리 `reference_plugin_cache_read_outside_cwd`).
- `plugin.json` 에 지시문을 싣는 필드는 없다. 플러그인 출력 스타일은 강제하면 사용자가 고른 스타일을 덮어쓰고,
  플러그인 여럿이면 하나만 이긴다.
- 선택지 칸 한도(머리글·이름 길이)는 공식 문서에 없다(OQ17). 그래서 이름은 짧게, 번호·설명은 설명칸에 둔다.

## Goals

1. 네 플러그인의 SKILL.md 와 명령 파일 전부가 같은 규칙 블록으로 시작하고, 정본과 다르면 테스트가 RED 를 낸다.
2. 스크립트가 내는 사람용 출력의 첫 줄이 쉬운 상태 문장이다. 0인 집계 줄은 나가지 않는다.
3. 프로그램이 글자로 읽는 줄은 형태가 그대로이고, 그 소비자 테스트가 전부 GREEN 이다.
4. 승인 게이트 질문은 결정 하나와 상태 한 줄만 담는다. 경고 목록은 질문 앞 글에 있다.
5. qg 의 사람용 고정 문구와 질문이 한국어다.
6. 리뷰어 지적마다 사람에게 보일 쉬운 한 문장이 있고, 화면 출력이 그것을 먼저 쓴다.
7. 네 README 와 소개 문구가 새 규칙대로 다듬어지고, `plugin.json` 과 마켓플레이스 소개 문구가 글자까지 같다.
8. 대표 사례 둘의 전·후가 기대 출력 파일로 남고, 양 측정 스크립트가 기준선을 재현한다.

## Non-goals

- 홍보 문구를 새로 쓰기(B3 로 좁힘 — 소개 문구·README 다듬기는 범위 안).
- 압축 뒤 영어 전환, 사용자 설정의 Insight 상자, 철학 문서 전반의 현대화(다음 작업).
- 모델이 읽는 지시문을 쉬운 말로 다시 쓰기 — 성능이 우선이다(C17 · D18). 지시문 안의 **출력 예시 문구**만 고친다.
- 영어를 막거나 글을 검사하는 장치(C7 · C8). 규칙 블록의 동일성 테스트는 「글을 검사」하지 않는다 — 규칙이 제자리에
  있는지만 본다.
- 설명 정본·용어집 문서(D22 — B8).
- 메모리 문체 손보기. 메모리 색인은 25KB 아래로 이미 정리했다(B4, 2026-10-08, 24,255바이트).

## Constraints

- brief 의 confirmed 22건(C1~C11 · D12~D22). 특히:
  - 사람용 글만 쉬운 말로 고친다. 모델용 글은 성능 기준을 따른다(D18).
  - 판정·개수·공시 줄의 쉬운 첫 줄은 스크립트가 낸다(D15).
  - 한 브랜치에서 단계별로 머지한다(D19).
  - 문구를 고정한 테스트는 뜻을 지키며 함께 고친다(C8).
- 쉬운 설명과 원문이 어긋나면 원문이 이긴다. 쉬운 말은 정직성 장치 위에 얹히고 그것을 대신하지 않는다(brief §2 ✎).
- `CLAUDE.md` 의 처분 규칙: 판정기가 버린 항목은 세고, 셀 수 없으면 「셀 수 없음」을 낸다. 침묵과 0 은 다른 사실이다.
  「이상 없음」은 채널을 실제로 읽은 뒤에만 쓴다.
- 리뷰어 지시 파일은 보안 민감이다 — 규칙을 지우거나 약하게 하지 않는다. 칸만 더한다.
- 플러그인을 건드리는 PR 마다 SemVer 를 올리고 CHANGELOG 에 적는다. 번호는 머지 직전에 정한다.

## 설계

### 1. 규칙 블록 (B6 — 사용자 승인 문장)

정본은 `shared/style/plain-language.md` 다. 표시 줄을 포함한 블록 전체가 다음과 같다.

```markdown
<!-- plain-language:begin -->
## 사람에게 쓰는 글
이 절은 사용자에게 보이는 글(답변·보고·질문·선택지·경고·PR 본문·커밋)에만 적용한다. 지시문·subagent 프롬프트·state 파일에는 적용하지 않는다.
- 처음 보는 사람이 한 번에 이해하게 쓴다. 번호·해시·필드 이름·내부 용어는 가리키는 내용을 문장으로 먼저 쓰고 괄호 안에만 둔다. 지어낸 말은 쓰지 않거나 처음 쓸 때 풀어 쓴다.
- 순서: 첫 줄에 지금 상태(무엇을 했고 어디까지 왔나) 한 문장, 가운데에 이유·근거, 맨 끝에 사용자가 할 일 하나. 할 일이 없으면 없다고 쓴다.
- 질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로, 설명에는 고르면 무엇이 달라지는지만 쓴다. 본문에 없던 주제를 선택지에서 꺼내지 않는다. 추천은 「(권장)」으로 표시한다.
- 제목과 목록으로 나누되 표의 칸은 짧게 쓴다. 굵은 글씨는 꼭 필요한 곳에만 쓴다.
- 사용자가 알 필요 없는 글은 쓰지 않는다: 도구 호출 사이의 진행 설명, 전부 정상인 항목의 나열. 확인해서 이상이 없으면 「이상 없음」 한 줄로 쓴다. 확인하지 못한 것·빠진 검사·셀 수 없는 것은 따로 한 줄씩 쓴다 — 없는 것과 확인 못 한 것은 다르다.
- 스크립트가 낸 판정·오류 원문은 고치지 않는다. 사용자가 판단해야 하는 자리에서는 쉬운 설명을 앞에, 원문을 뒤에 둔다. 판정을 자기 말로 다시 풀어 쓰지 않는다.
- 사용자와 대화하는 언어로 쓴다. 코드·명령·고유명사·자연스러운 대응어가 없는 기술어는 영어 그대로 둔다. 커밋·PR은 그 레포의 규칙을 따르고, 없으면 대화 언어로 쓴다.
예) 전: `[미적용 fix] 3720b2b7#r1.1` → 후: 리뷰가 고치라고 한 곳 하나가 아직 안 고쳐졌다(3720b2b7#r1.1).
예) 전: (codex 정상 · 재비판 정상 · 저자 편집 없음 · ask_open 0건) → 후: 이상 없음.
<!-- plain-language:end -->
```

- 블록은 13줄이다. 같은 블록이 여러 파일에 들어가도 「20줄 이상 같은 블록」을 막는 중복 락
  (`shared/tests/test_no_new_duplication.sh`)에 걸리지 않는다. 블록은 19줄을 넘기지 않는다.
- 블록에는 출처나 존재 이유를 적지 않는다(Self-narrating artifact 금지).
- 쉬운 말 규칙의 바탕 넷(C11)이 블록에 들어 있다.
  - 전·후 예시: 「예)」 두 줄
  - 쉬운 말은 화면에, 번호는 기록에: 첫 불릿
  - 간결 규칙은 사람 글에만: 적용 범위 문장
  - 중요한 것은 끝에: 「맨 끝에 할 일」

### 2. 배달과 동일성 (B5)

- **자리:** 아래 파일 전부의 frontmatter 바로 뒤, 첫 제목 앞에 블록 복사본을 둔다.
  - `plugins/*/skills/*/SKILL.md` 8개
  - `plugins/*/commands/*.md` 7개

  압축 뒤에도 앞 5,000토큰 안에 남는 자리다. 설치본에서 권한 질문 없이 본문으로 읽힌다.
- **동일성 락:** `shared/tests/test_plain_language_block.sh` 가 지킨다.
  - 대상은 두 글롭으로 **구조에서 도출**한다. 목록을 손으로 적지 않는다 — 새 SKILL.md 가 블록 없이 들어오면 RED.
  - 표시 줄 사이 바이트가 정본과 같아야 한다.
  - 블록이 첫 `## ` 제목보다 앞에 있어야 한다.
  - 표시 줄이 파일마다 정확히 한 쌍이어야 한다.
  - 대상 수가 0이면 RED 다(공허한 통과 방지).
- **subagent 정의에는 블록을 넣지 않는다.** 리뷰어 출력은 §5 의 칸 하나로 다룬다.
- **블록을 고치는 절차:** 정본을 고친 뒤 복사본을 다시 쓰는 스크립트(`shared/style/sync_plain_language.py`)를
  돌린다. 이 스크립트는 고치기만 하고 판정하지 않는다. 판정은 락이 한다.

### 3. 스크립트가 내는 글 (B7)

**원칙 셋**

1. **사람이 보는 출력과 프로그램이 읽는 출력을 가른다.**
   - 프로그램이 읽는 줄은 형태를 그대로 둔다(아래 표). 쉬운 줄은 그 옆에 따로 한 줄로 더한다.
   - 사람만 보는 출력은 자유롭게 고친다.
2. **사람용 출력의 첫 줄은 스크립트가 계산한 쉬운 상태 문장이다.** 모델은 판정을 다시 풀어 쓰지 않는다(D15).
3. **0인 집계는 내지 않는다. 전부 정상이면 「이상 없음」 한 줄이다.**
   - 이 0은 스크립트가 실제로 센 값이다.
   - 확인하지 못한 것(「미검증」, codex 없음, 셀 수 없음)은 0과 섞지 않는다. 지금처럼 따로 한 줄로 쉬운 말로 낸다.

**프로그램이 글자로 읽는 줄 — 형태를 바꾸지 않는다** (OQ12)

| 줄 | 만드는 곳 | 읽는 곳 |
|---|---|---|
| `verdict: <clean\|defect\|not-certified>` | qg `verdict.py` | qg SKILL(정확히 한 번) · `test_verdict_vocabulary.sh` |
| `**Findings:** N CRITICAL / …` | `synthesize_findings.py` | fix-loop 요약 · History 줄 · 테스트 |
| `판정 degrade` 표지 | `synthesize_findings.py` | 테스트 |
| 「되돌린다」·「그대로 둔다」 선택지 | framing-requests SKILL | bash `case`(되돌릴 id 목록) |
| `review-entry: PROCEED\|DISABLED:*` | reviewing-spec 펜스 | 같은 SKILL 의 `case` |
| `codex_available:` · `skip_reason:` | `detect_codex.sh` | 네 SKILL 의 `sed` |
| `scan_ok: yes` · `action: …` | `secret-scan.py` · `pr-create.sh` | 게시 게이트 |
| 커밋 type 정규식 · 브랜치 `regex` 블록 | project-init 훅 · 템플릿 | 같은 훅 |
| `plugin.json` ↔ 마켓플레이스 소개 문구 | 두 파일 | `check-staleness.py` 글자 비교 |
| 감사 보고서 앞 20줄의 `⚠`/`degraded` | `render-audit-report.py` | `validate-audit-data.py` |
| `docreview gate` JSON(렌더 없는 출력) | `docreview_state.py` | 호출하는 스킬들 |

- 「쉬운 줄은 따로 더한다」의 경계: 더하는 줄은 읽는 쪽의 패턴(예: `^verdict:`)과 겹치는 글자를 담지 않는다.
- 선택지 라벨은 상태에서 계산한다(`_CHOICE_LABEL` 의 기존 원칙). 「동작을 반대로 설명하는 라벨」을 막기 위해서다.

**고칠 자리** (Files to Modify 에 전부)

- **문서 리뷰 엔진 게이트 렌더**(`render_gate`, `_rg_*`):
  - 첫 줄을 쉬운 상태 문장으로 바꾼다. 예: 「리뷰 2라운드를 마쳤다 — 정할 것 1개, 아직 안 고친 곳 1개가 남았다. 이상 없음(경고 없음).」
  - 항목 머리 `[decide]`·`[미적용 fix]` 등을 쉬운 말 앞, id 괄호로 바꾼다.
  - 「순서:」 설명 줄은 항목 묶음 제목으로 흡수한다.
  - 0인 집계는 뺀다.
  - `다음:` 줄의 모드 토큰(`rereview`, `extra_approval`, `round_reviewed=false`)을 쉬운 말로 바꾼다.

  상태 이름의 쉬운 말 짝은 렌더 코드 옆 표(`STATE_GLOSS`)에 둔다. 기존 `CATEGORY_GLOSS` 와 같은 방식이다.
- **qg:**
  - `setup-qg.sh` 시작 배너 — 과정 나열을 뺀다.
  - `synthesize_findings.py` 의 「No high-confidence findings」 등 영어 고정 문구.
  - 범위 경고(`scope check degraded …`).
  - 범위·각도 YAML 은 그대로 보이던 자리에서 쉬운 한 줄로 바꾸고, YAML 은 기록에만 둔다.
  - `cancel-qg` 메시지와 세션 시작 훅 경고.
- **plugin-audit:**
  - `render-audit-report.py` 의 「LD4」 같은 설명 없는 번호와 「좌: 0건」 줄.
  - 영어 무결성 경고.
- **project-init:** 훅의 영어 경고 문구(`post-tool-use.py`).
- **spec-distill 펜스의 고정 경고:** 예) 「기준 사본이 없다」. 모델에게 쓰는 실패 안내(「플러그인 루트 미해석 — …」)는
  모델용 지시라 그대로 둔다.

### 4. 스킬이 시키는 질문·보고 틀

- **승인 게이트** — `conducting-interview/references/finishing.md`, `reviewing-spec/SKILL.md` 의 게이트, `proceed-gate.md`:
  - 경고 목록은 게이트 **앞 글**에 쉬운 말로 쓴다. 채널을 다 읽었는데 없으면 「이상 없음」 한 줄이다.
  - question 본문에는 결정 하나와 상태 한 줄(「경고 2개 — 위에 적었다」)만 둔다.
  - 「채널을 이름으로 밝히고, 읽은 뒤에만 없음을 쓴다」는 계약은 그대로다. 바뀌는 것은 보이는 자리다.
  - 머리글 「Proceed」는 「다음 단계」로 바꾼다.
  - 선택지 설명은 내부 동작(「status: confirmed로 반영 → 재저장 → 게이트 재실행」) 대신 고르면 무엇이 달라지는지를 쓴다.
- **리뷰 라운드 질문**(문서 리뷰 엔진 reference 와 각 호스트 SKILL):
  - 결정마다 질문 하나라는 지금 방식을 유지한다.
  - 한 호출에 서로 무관한 결정을 묶지 않는다.
  - 선택지 라벨 규약(상태별 라벨 + 1~5 낱말)은 쉬운 말 짝을 쓴다.
- **qg 질문 셋과 완료 표**(`quality-pipeline/SKILL.md`): 한국어로 바꾼다. 고정 테스트(`findings remain`,
  `Accept and finish`)는 뜻을 지키며 새 문구로 고친다.
- **최종 보고 틀**(plugin-audit · project-init · qg 완료):
  - 첫 줄에 끝났는지와 결과를 쓴다.
  - 맨 끝에 할 일 하나를 쓴다.
  - 파일 경로는 사용자가 열어 볼 것만 남긴다.
- **「(Recommended)」** 를 쓰는 devbrew 틀은 「(권장)」으로 바꾼다.

### 5. 리뷰어 출력 (B9)

- **문서 리뷰 엔진의 탐지 리뷰어**(`shared/docreview/agents/doc-critic*.md` 와 그 사본들):
  - 이미 사람용 칸(그대로 두면 · 고치면 · 근거)을 쓴다.
  - 그 칸 설명에 「처음 보는 사람이 읽는다 — 내부 번호 없이 쉬운 말로」 한 줄을 더한다.
- **qg 보안 리뷰어·artifact-critic, plugin-audit 감사자:**
  - finding 형식에 `plain:` 칸(사람에게 보일 한 문장)을 더한다.
  - 화면 출력은 `plain:` 이 있으면 그것을 먼저 쓰고, 원래 요약을 뒤 괄호에 둔다.
  - `plain:` 이 없으면 지금처럼 낸다. 없는 칸 때문에 finding 을 버리지 않는다 — 버리면 처분 회계에서 소실이 된다.
- 찾는 지시(무엇을 어떻게 찾는가)는 한 글자도 바꾸지 않는다. 짧게 쓰라고도 하지 않는다. 「짧게」가 발견 수와 정확도를
  깎는다는 근거(«phare» · «anthropic-opus5», brief §4)가 있어서다.
- `tools:` 허용 목록은 바꾸지 않는다(Law 2).

### 6. 모델이 읽는 지시문 (D18)

- 지시문 문장은 그대로 둔다.
- 지시문 안에서 **사용자에게 그대로 내라고 적힌 문구**는 §1 규칙대로 고친다. 출력 예시, 따옴표 속 보고 문장,
  `> [플러그인] …` 형태의 경고 틀이 여기 든다. 말투가 출력으로 옮는 통로가 이것이다.

### 7. `CLAUDE.md` 와 철학 문서 (D13)

- `CLAUDE.md` `## Git Workflow` 에 「커밋 메시지 설명·PR 본문은 한국어. type·scope 는 영어」를 적는다(B2).
- `CLAUDE.md` `## Doc Conventions` 에 범위 문장을 더한다. 영어 범위와 「원문 인용에 풀이 금지」는 **레포 문서**의
  규칙이다. 플러그인이 실행 중 내는 글은 `shared/style/plain-language.md` 를 따른다.
- 철학 문서에는 새 규칙과 부딪히는 조항이 없다(2026-10-08 전문 확인). 손대지 않는다.
- project-init 의 커밋·PR 템플릿(영어 명령형)은 그대로다. 다른 레포의 규칙을 만드는 틀이라 「그 레포 규칙을 따른다」(B2)와 맞는다.

### 8. 소개 문구와 README (B3 · D20)

- 네 `plugin.json` 의 `description` 과 `.claude-plugin/marketplace.json` 의 각 항목을 같은 영어 문장으로 맞춘다.
  - 처음 보는 사람이 「무엇을 해 주는가」를 한 문장으로 알게 다듬는다.
  - 화살표 나열과 내부 용어는 뺀다.
  - project-init 의 두 문구 불일치도 이때 맞춘다.
- 네 README 를 새 규칙대로 다시 쓴다.
  - 「Principles Instantiated」 절과 그 형식은 유지한다(`CLAUDE.md` 필수 절).
  - README 를 고정한 테스트는 뜻을 지키며 함께 고친다.
- CHANGELOG 의 지난 항목은 기록이라 그대로 둔다. 이번에 더하는 항목만 새 규칙대로 쓴다.

### 9. 머지 순서 (D19 · B10)

한 브랜치에서 PR 을 차례로 낸다. 하나가 머지되면 main 을 merge 로 받고(rebase 하지 않는다) 다음 PR 을 낸다.

| PR | 내용 | 버전 올림 |
|---|---|---|
| 1. 공통 | §1 정본 · §2 블록 15곳과 락·동기 스크립트 · §3 문서 리뷰 엔진 렌더 · §5 탐지 리뷰어 한 줄 · §7 `CLAUDE.md` · 양 측정 스크립트 | 네 플러그인 모두(블록이 네 플러그인에 들어간다) |
| 2. spec-distill | §4 승인 게이트 · 펜스 고정 경고 · 출력 예시 문구 · README · 소개 문구 | spec-distill |
| 3. quality-gates | 한국어 질문과 완료 표 · 합성기·배너·범위 표시 · `plain:` 칸 · README · 소개 문구 | quality-gates |
| 4. plugin-audit · project-init | 감사 보고서 · 훅 경고 · 명령 보고 틀 · `plain:` 칸 · README · 소개 문구와 불일치 | 둘 다 |

- 규칙 블록은 「규칙과 공통 부분」이므로 PR 1 에서 15곳 모두에 넣는다. 그래서 동일성 락은 PR 1 부터 전체를 집행한다.
- 모델이 쓰는 글은 PR 1 머지 직후부터 바뀐다. 스크립트 출력과 틀은 PR 2~4 에서 플러그인별로 바뀐다.

## Acceptance Criteria

변이 = 그 AC 의 락이 실제로 잡는지 보려고 일부러 망가뜨리기. 커밋한 뒤 변이하고, RED 를 확인한 다음
`git checkout HEAD --` 로 되돌린다.

- **AC1 — 블록 동일성.**
  - **조건:** 두 글롭의 대상 전부(지금 15개)에 표시 줄 한 쌍이 있고, 그 사이 바이트가 `shared/style/plain-language.md`
    와 같다. 블록은 첫 `## ` 제목보다 앞에 있다. 대상 수 0이면 RED.
  - **변이:**
    - 한 복사본의 글자 하나 바꾸기 → RED
    - 한 파일에서 블록 지우기 → RED
    - 블록 없는 새 SKILL.md 추가 → RED
    - 블록을 파일 끝으로 옮기기 → RED
    - 정본만 바꾸기 → RED
- **AC2 — 블록 크기.**
  - **조건:** 블록이 19줄 이하이고, `test_no_new_duplication.sh` 가 GREEN 이다.
  - **변이:** 블록을 20줄로 늘리기 → 크기 락 RED.
- **AC3 — 문서 리뷰 게이트 렌더.**
  - **조건 ①** 첫 줄이 쉬운 상태 문장이다.
  - **조건 ②** 0인 집계 항목이 출력에 없다. 0이 아닌 항목만 쉬운 말로 나온다.
  - **조건 ③** 항목 줄이 쉬운 말로 시작하고 id 는 괄호 안에 있다.
  - **조건 ④** 「미검증」·codex 없음·라운드 미완은 「이상 없음」과 같은 줄에 나오지 않고 따로 나온다.
  - **조건 ⑤** 대표 사례 둘의 전·후가 기대 출력 파일(golden)에 있다.
  - **변이:**
    - 0인 집계 줄 되살리기 → RED
    - codex 없음 상태에서 「이상 없음」 내기 → RED
    - id 를 앞으로 되돌리기 → RED
- **AC4 — 기계 경로 불변.**
  - **조건:** `docreview_state.py gate`(렌더 없음)의 JSON 키와 값이 같은 fixture 에서 고치기 전과 같다.
    §3 표의 각 소비자 테스트가 GREEN 이다.
  - **변이:** JSON 키 하나 이름 바꾸기 → RED.
- **AC5 — qg 판정 줄.**
  - **조건:** `^verdict:` 줄이 정확히 한 번, 형태가 그대로다. 새로 더한 쉬운 첫 줄은 `verdict:` 글자를 담지 않는다.
    `test_verdict_vocabulary.sh` 가 수정 없이 GREEN 이다.
  - **변이:** 쉬운 줄에 `verdict: clean` 넣기 → RED.
- **AC6 — qg 한국어.**
  - **조건:** `quality-pipeline/SKILL.md` 의 질문 셋과 완료 표, `synthesize_findings.py`·`setup-qg.sh`·`cancel-qg`
    의 사람용 고정 문구가 한국어다(코드·명령·식별자 제외).
  - **변이:** 질문 하나를 영어로 되돌리기 → 그 문구를 고정한 테스트 RED.
- **AC7 — 승인 게이트.**
  - **조건:** finishing.md 와 reviewing-spec 의 게이트 틀에서 question 본문이 degrade 줄 목록을 싣지 않는다.
    목록은 게이트 앞 글로 지시된다. 머리글이 「Proceed」가 아니다. 「채널을 읽은 뒤에만 이상 없음」 문장이 남아 있다.
  - **변이:** 그 문장 지우기 → RED.
- **AC8 — 선택지 라벨 동작 일치.**
  - **조건:** 「되돌린다」·「그대로 둔다」 `case` 와 그 테스트가 GREEN 이다. `_CHOICE_LABEL` 이 상태(pre·post)에서
    계산된다.
  - **변이:** post 라벨을 pre 와 같게 바꾸기 → 기존 테스트 RED.
- **AC9 — 리뷰어 칸.**
  - **조건:** 세 리뷰어 형식에 `plain:` 이 있다. 렌더가 그것을 먼저 쓴다. `plain:` 없는 finding 이 버려지지 않고
    지금처럼 나온다.
  - **변이:** 렌더가 `plain:` 없는 finding 을 건너뛰게 바꾸기 → RED.
  - **조건:** 리뷰어 `tools:` 는 바뀌지 않았다(Law 2 락 GREEN).
- **AC10 — 소개 문구.**
  - **조건:** 네 플러그인에서 `check-staleness.py` 의 소개 문구 불일치가 0 이다.
  - **변이:** 한 쪽 글자 하나 바꾸기 → RED.
- **AC11 — `CLAUDE.md`.**
  - **조건:** 한국어 커밋·PR 문장과 Doc Conventions 범위 문장이 있다.
- **AC12 — 양 측정 기준선.**
  - **조건:** 측정 스크립트가 2026-10-08 의 같은 기록 묶음에서 기준선(아래 Verification Plan)을 ±5% 안에서 재현한다.
- **AC13 — 회귀 없음.**
  - **조건:** 각 PR 착수 전 기준선과 비교해 새 실패 항목이 0 이다. 실패 테스트의 식별자·메시지로 대조하고, 파일별
    rc 와 실패 줄 수는 보조로 본다. 문구를 바꿔 고친 테스트는 PR 본문 표에 「옛 문구 → 새 문구 · 지키는 뜻」으로
    모두 적혀 있다.

## Files to Modify

- **새 파일:**
  - `shared/style/plain-language.md` · `shared/style/sync_plain_language.py`
  - `shared/tests/test_plain_language_block.sh`
  - 양 측정 스크립트(자리는 plan 에서 정한다)
  - `shared/README.md` 의 디렉토리 표에 `style/` 한 줄
- **블록 대상:**
  - `plugins/*/skills/*/SKILL.md` 8개
  - `plugins/*/commands/*.md` 7개
- **shared 엔진:**
  - `shared/docreview/scripts/docreview_state.py` (렌더, `STATE_GLOSS`)
  - `shared/docreview/references/reviewing-document.md` (라벨 규약 문구)
  - `shared/docreview/agents/doc-critic.md` · `doc-critic-web.md` 와 그 플러그인 사본
  - `shared/tests/fixtures/docreview/` 의 golden 과 `cases.sh`
- **spec-distill:**
  - `skills/conducting-interview/references/finishing.md` · `references/proceed-gate.md`
  - `skills/reviewing-spec/SKILL.md` · `skills/reviewing-brief/SKILL.md` · `skills/framing-requests/SKILL.md`
    (펜스 고정 경고, 출력 예시)
  - `scripts/seed_review_log.py` (사람용 줄)
  - README · CHANGELOG · `plugin.json`
  - 해당 테스트들
- **quality-gates:**
  - `skills/quality-pipeline/SKILL.md` · `skills/critiquing-artifacts/SKILL.md` · `skills/publishing-pr-understanding/SKILL.md`
  - `commands/cancel-qg.md` · `scripts/setup-qg.sh` · `scripts/synthesize_findings.py` · `scripts/cancel-qg-core.sh`
  - `hooks/session-start-advisor.py`
  - `agents/security-reviewer.md` · `agents/artifact-critic.md`
  - README · CHANGELOG · `plugin.json`
  - 해당 테스트들
- **plugin-audit:**
  - `scripts/render-audit-report.py` · `agents/plugin-auditor.md` · `skills/auditing-plugins/SKILL.md`
  - README · CHANGELOG · `plugin.json`
  - 해당 테스트들
- **project-init:**
  - `hooks/post-tool-use.py` (사람용 경고만, 정규식 불변) · `commands/project-init.md`
  - README · CHANGELOG · `plugin.json`
  - `tests/test_post_tool_use.py`
- **루트:** `CLAUDE.md` · `.claude-plugin/marketplace.json`

## Verification Plan

1. **각 PR 착수 전 기준선.** 네 플러그인과 shared 의 테스트를 전부 돌려 실패 항목을 식별자·메시지로 기록한다
   (rc 만으로 잡지 않는다). qg 는 main 에 선재 RED 가 있다.
2. **AC 락과 변이.** 커밋한 뒤 변이하고 RED 를 확인한 다음 되돌린다. 변이 전에 양성 대조(락이 실제로 그 파일을
   읽는지)를 확인한다.
3. **양 측정** — 2026-10-08 기준선:
   - 턴당 보이는 글 중앙값 1,075자(p90 5,770)
   - 질문이 상태 줄로 시작하는 비율 21%
   - 한 호출에 여러 결정을 묶은 비율 33%
   - 영어 위주 최종 보고 147건 / 2,239건
   - 질문의 55%에 ID·해시·코드 토큰

   PR 4 머지 뒤 실제로 쓴 세션이 쌓이면 같은 스크립트로 다시 잰다. 이것은 머지 조건이 아니라 사후 확인이다.
4. **사용자가 직접 돌려 읽기.** PR 본문의 할 일에 「이 플러그인의 주 흐름을 한 번 돌려 보기」를 적는다.
   - PR 2: `/request-framing` → `/interview`
   - PR 3: `/qg`
   - PR 4: `/plugin-audit` · `/project-init`
5. **/qg 리뷰.** 각 PR 을 /qg 로 리뷰한다. 리뷰어에게 「문구를 고정한 테스트의 뜻이 유지됐는가」를 명시해 묻는다.

## Rejected Alternatives

- **세션 시작 훅으로 규칙 주입** — devbrew 를 안 쓰는 대화에도 걸린다. 훅이 qg 에만 있다. 압축 뒤 재주입 여부가
  미확인이다(B5).
- **플러그인 출력 스타일 강제** — 사용자가 고른 스타일을 덮어쓰고, 플러그인 여럿이면 하나만 이긴다(B5).
- **shared reference 를 경로로 알려 주기** — 설치본에서 권한 질문이 뜨고 subagent 는 못 읽는다(RC3 · RC4).
- **스크립트 출력에 원문을 항상 뒤에 붙이기** — 더 안전하지만 양이 는다. 원문 병기는 사용자가 판단하는 자리에만
  한다(C5 · B7).
- **리뷰어 지시 파일을 손대지 않고 화면 쪽에서만 풀기** — 지적 내용 자체가 어려우면 풀 수 없다(B9).
- **리뷰어에게 「짧고 쉽게 써라」** — 발견 수·정확도를 깎는다는 근거가 있다. 칸만 더한다.
- **용어집 문서** — 규칙보다 먼저 만들지 않는다(D22). 쉬운 말 짝은 렌더 코드 옆 표로 충분하다(B8).
- **어디서나 한국어 커밋 / devbrew 레포에서만(플러그인은 침묵)** — 다른 레포의 영어 협업을 깨거나, 다른 레포에서
  커밋 언어 기준이 없어진다(B2).
- **문구 고정 테스트 일괄 재고정** — 지키던 뜻이 바뀌어도 통과한다(RC20). 하나씩 「옛 → 새 · 뜻」으로 고친다.

## 알려진 한계

- **블록 밖 규칙 준수는 검사하지 않는다(C8).** 락은 블록이 제자리에 있는지만 본다. 모델이 블록을 읽고도 진행 설명을
  쓰는지는 양 측정으로 사후에만 보인다.
- **스킬을 쓰지 않는 대화에는 규칙이 닿지 않는다.** 범위(C1)가 devbrew 가 돌 때의 글이라 의도한 것이다.
- **스킬을 여럿 쓴 긴 세션의 압축.** 압축 뒤에는 최근 스킬부터 합계 25,000토큰만 다시 붙는다. 오래된 스킬의 블록은
  빠질 수 있다. 블록이 모든 스킬에 있으므로 가장 최근 스킬의 블록이 남는다.
- **Insight 상자는 범위 밖이다(C9).** 사용자 설정의 explanatory 스타일이 내는 상자는 이번에 줄지 않는다. 양 측정에서
  따로 센다.
- **이 설계의 쉬운 말 짝(`STATE_GLOSS`)도 글쓴이가 정한다.** 처음 보는 사람 시험은 요구사항이 아니다(brief S8).
  사용자가 직접 돌려 읽는 것이 그 확인이다.

## 결정 기록

brief 의 confirmed 결정(C1~C11 · D12~D22)은 brief 가 정본이다. 아래는 이 설계의 brainstorming(2026-10-08)에서 정한 것이다.

- **B1 — OQ14 「구조적으로」 = 정해진 순서 + 한 번에 하나 + 항목 나누기.**
  - 정해진 순서: 첫 줄에 상태, 끝에 할 일.
  - 한 번에 하나: 질문 하나에 결정 하나, 새 주제 금지.
  - 항목 나누기: 사용자가 「항목 나누기도 해줘」로 더함. 표 칸은 짧게.
  - 「작업 중 설명 줄이기」는 이 뜻으로 고르지 않았다. 그래서 C6(양 줄이기)으로 블록에 넣었다.
- **B2 — OQ18 커밋 언어 = 그 레포 규칙을 따른다.** devbrew 는 `CLAUDE.md` 에 한국어로 적는다.
  기각: 어디서나 한국어 · devbrew 에서만.
- **B3 — OQ16 README 도 고친다.** 그에 따라 OQ20 은 Non-goal 을 「홍보 문구 신규 작성」으로 좁히고 D20 을 유지한다.
  OQ20 은 사용자의 README 선택에서 모델이 정했고, 보고했다.
- **B4 — OQ19 메모리는 지금 따로 정리.** 2026-10-08 에 완료했다(24,255바이트).
  - 완료 11줄 → `project_archive_merged.md`
  - 내부 스크립트 함정 14줄 → `reference_devbrew_internals_index.md`
- **B5 — OQ10 배달 = SKILL.md·명령 파일 앞 규칙 블록.** 기각: 세션 시작 훅 · 블록 + 훅.
- **B6 — 규칙 블록 문장 승인**(§1 그대로).
- **B7 — 스크립트 출력 세 원칙과 게이트 렌더 예시 승인.** 기각: 원문을 항상 뒤에.
- **B8 — D22 용어집 문서는 이번에 만들지 않는다.** 쉬운 말 짝은 렌더 코드 옆 표에 둔다(모델 판단, 보고함).
- **B9 — OQ13 리뷰어는 찾는 지시 불변 + 사람용 칸.** OQ15 qg 고정 문구는 한국어로(기계 토큰 제외 — 모델 판단, 보고함).
  질문·보고 틀 절 승인. 기각: 리뷰어 제외.
- **B10 — PR 넷 순서와 성공 확인 승인.** 기각: 측정 스크립트 없이 숫자만.
- OQ11(쓰는 쪽별 고칠 목록)은 §3~§6 이, OQ12(기계가 읽는 줄의 경계)는 §3 표가, OQ17(선택지 칸 한도)은 「이름은 짧게,
  설명은 설명칸에」가 닫는다.

## Metadata

- 관련: interview brief `docs/superpowers/interview/2026-10-03-plain-language-output-interview.md`(+ `.audit.md`) ·
  seed `docs/superpowers/interview/2026-10-03-plain-language-voice-interview.md` · base `77371d41`(#186).
- 영향 플러그인: plugin-audit · project-init · quality-gates · spec-distill. shared(docreview · 새 style). 루트 `CLAUDE.md`
  · `marketplace.json`.
- 조사 자료: 2026-10-08 세션 기록 분석(776개 기록), 글 출처 목록, 배달 장치 조사. 이 설계의 Context 절과 §3 표가 그 요약이다.

### Deferred to plan

1. 양 측정 스크립트의 자리와 입력(세션 기록 디렉토리 선택 규칙, 「devbrew 스킬이 돈 턴」 판별).
2. 문구 고정 테스트 전수 목록 — PR 마다 그 PR 이 바꾸는 문구를 리터럴로 기대하는 자리를 리포 전체에서 grep 한다
   (숨김 디렉토리·심볼릭 링크 포함).
3. `STATE_GLOSS` 의 짝 전부 — `GATE_ROWS` 의 상태 이름에서 도출하고, 사상 없는 상태는 `CATEGORY_GLOSS` 처럼 원래
   이름으로 내되 그 사실을 한 줄로 공시한다.
4. doc-critic 사본들(spec-distill · quality-gates)의 동기 방식 — 지금의 `copy-of` 계약을 따른다.
