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
4. 모든 게이트 질문(승인 · 리뷰 라운드 · request-framing 확정)은 결정 하나와 상태 한 줄만 담는다. 상태와 경고
   목록은 질문 앞 글에 있다.
5. qg 의 사람용 고정 문구와 질문이 한국어다.
6. 리뷰어 지적마다(codex 리뷰어 · 재비판 · 반대 검증 리뷰어가 낸 지적 포함) 사람에게 보일 쉬운 한 문장이 있고,
   화면 출력이 그것을 먼저 쓴다.
7. 네 README 와 소개 문구가 새 규칙대로 다듬어지고, `plugin.json` 과 마켓플레이스 소개 문구가 글자까지 같다.
8. 대표 사례 둘의 전·후가 기대 출력 파일로 남고, 양 측정 스크립트가 고정한 기록 목록에서 정식 기준선을 낸다.

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
이 절은 사용자에게 보이는 글(답변·보고·질문·선택지·경고·PR 본문·커밋)에만 적용한다. 지시문·subagent 프롬프트·state 파일에는 적용하지 않는다. 아래 절차가 출력 형식·원문 보존·분량을 따로 정한 자리에서는 그 절차를 따른다.
- 처음 보는 사람이 한 번에 이해하게 쓴다. 번호·해시·필드 이름·내부 용어는 가리키는 내용을 문장으로 먼저 쓰고 괄호 안에만 둔다. 지어낸 말은 쓰지 않거나 처음 쓸 때 풀어 쓴다.
- 순서: 첫 줄에 지금 상태(무엇을 했고 어디까지 왔나) 한 문장, 가운데에 이유·근거, 맨 끝에 사용자가 할 일 하나. 할 일이 없으면 없다고 쓴다.
- 질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로, 설명에는 고르면 무엇이 달라지는지만 쓴다. 본문에 없던 주제를 선택지에서 꺼내지 않는다. 추천은 「(권장)」으로 표시한다.
- 제목과 목록으로 나누되 표의 칸은 짧게 쓴다. 굵은 글씨는 꼭 필요한 곳에만 쓴다.
- 사용자가 알 필요 없는 글은 쓰지 않는다: 도구 호출 사이의 진행 설명, 전부 정상인 항목의 나열. 확인해서 남은 것도 경고도 없으면 「이상 없음」 한 줄로 쓴다. 확인하지 못한 것·빠진 검사·셀 수 없는 것은 따로 한 줄씩 쓴다 — 없는 것과 확인 못 한 것은 다르다.
- 판정·개수·공시 줄은 스크립트가 낸 쉬운 첫 줄을 그대로 쓰고, 자기 말로 다시 풀거나 덧붙이지 않는다. 스크립트·subagent 가 낸 원문은 고치지 않는다. 스크립트가 풀어 두지 않은 오류에만 쉬운 설명을 앞에 붙이되 통과·실패는 말하지 않는다.
- 사용자와 대화하는 언어로 쓴다. 코드·명령·고유명사·자연스러운 대응어가 없는 기술어는 영어 그대로 둔다. 커밋·PR은 그 레포의 규칙을 따르고, 없으면 대화 언어로 쓴다.
예) 전: `[미적용 fix] 3720b2b7#r1.1` → 후: 리뷰가 고치라고 한 곳 하나가 아직 안 고쳐졌다(3720b2b7#r1.1).
예) 전: (codex 정상 · 재비판 정상 · 저자 편집 없음 · ask_open 0건) → 후: 이상 없음.
<!-- plain-language:end -->
```

- 블록은 13줄이다. 같은 블록이 여러 파일에 들어가므로 「빈 줄을 뺀 연속 20줄이 같은 곳」을 막는 중복 락
  (`shared/tests/test_no_new_duplication.sh`)과의 관계가 중요하다.
  - 블록을 frontmatter 바로 뒤에 두면 앞의 닫는 줄 `---` 이 모든 파일에서 같아 창이 한 줄 늘어난다.
  - 그래서 블록은 **H1 제목 바로 다음**에 둔다(§2). H1 은 파일마다 달라 창이 블록 안에서 끝난다.
  - 블록은 19줄을 넘기지 않는다. 최종 판정은 줄 수가 아니라 중복 락이 GREEN 인가다.
- 「사람에게 쓰는 글」의 뜻 둘(1라운드 리뷰 D1.7):
  - 「아래 절차가 따로 정한 자리」의 예: steelman 질문의 「(권장)」 금지, qg 판정의 요약·재서술 금지, subagent
    출력의 verbatim 계약, 분량 상한을 두지 않는 저자 편집 공시. 그 자리에서는 블록보다 그 절차가 이긴다.
  - 「이상 없음」은 남은 것도 경고도 없을 때만 쓴다(1라운드 질문 답). 남은 것이 있는데 경고만 없으면 「경고 없음」이다.
- 블록에는 출처나 존재 이유를 적지 않는다(Self-narrating artifact 금지).
- 쉬운 말 규칙의 바탕 넷(C11)이 블록에 들어 있다.
  - 전·후 예시: 「예)」 두 줄
  - 쉬운 말은 화면에, 번호는 기록에: 첫 불릿
  - 간결 규칙은 사람 글에만: 적용 범위 문장
  - 중요한 것은 끝에: 「맨 끝에 할 일」

### 2. 배달과 동일성 (B5)

- **자리:** 아래 파일 전부의 H1 제목(frontmatter 뒤 첫 `# ` 줄) 바로 다음에 블록 복사본을 둔다. 15개 모두
  frontmatter 바로 뒤에 H1 이 있다(2026-10-08 확인).
  - `plugins/*/skills/*/SKILL.md` 8개
  - `plugins/*/commands/*.md` 7개

  압축 뒤에도 앞 5,000토큰 안에 남는 자리다. 설치본에서 권한 질문 없이 본문으로 읽힌다.
- **크기는 토큰으로도 잰다(1라운드 리뷰 D1.5).** brief 는 배달 방식에 「기존 핵심 절차를 밀어내지 않게 짧게」를
  걸었다. 블록은 한국어 약 1,200자라 앞 5,000토큰의 적지 않은 부분을 차지한다.
  - PR 1 은 블록의 토큰 수를 잰다.
  - 스킬·명령 파일마다 블록을 넣기 전과 뒤에 앞 5,000토큰 경계가 어느 줄에 떨어지는지 재고, 경계 밖으로
    밀려나는 절의 목록을 PR 1 본문에 적는다.
  - kill switch · 진입 검사 · 게이트처럼 그 파일의 핵심 절차가 밀려나면 블록을 줄이거나 그 파일의 절 순서를
    바꾼다. 어느 쪽을 택했는지 PR 1 본문에 적는다.
- **동일성 락:** `shared/tests/test_plain_language_block.sh` 가 지킨다.
  - 대상은 두 글롭으로 **구조에서 도출**한다. 목록을 손으로 적지 않는다 — 새 SKILL.md 가 블록 없이 들어오면 RED.
  - 표시 줄 사이 바이트가 정본과 같아야 한다.
  - 시작 표시 줄이 H1 제목 다음의 첫 비어 있지 않은 줄이어야 한다(블록 자신의 `## ` 제목으로 만족되지 않는다).
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
3. **정상 집계의 0은 내지 않는다. 남은 것도 경고도 없으면 「이상 없음」 한 줄이다.**
   - 이 0은 스크립트가 실제로 센 값이다.
   - 확인하지 못한 것(「미검증」, codex 없음, 셀 수 없음)은 0과 섞지 않는다. 지금처럼 따로 한 줄로 쉬운 말로 낸다.
   - 「이상 없음」과 「경고 없음」은 다르다. 남은 것(정할 것·안 고친 곳)이 있는데 경고만 없으면 「경고 없음」이다.
   - **판단에 필요한 0은 남긴다(1라운드 리뷰 D1.2).** 상반된 두 주장의 근거를 대칭으로 보이는 자리(plugin-audit
     보고서의 좌·우 근거)처럼 「한쪽에 근거가 없다」는 사실이 판단 재료인 0은 지우지 않는다. 대신 「반대 주장을
     받치는 근거는 보고되지 않았다」처럼 쉬운 문장으로 낸다. 그 자리를 고정한 테스트는 이 정보가 남는지를 계속 잰다.

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
  - 첫 줄을 쉬운 상태 문장으로 바꾼다. 예: 「리뷰 2라운드를 마쳤다 — 정할 것 1개, 아직 안 고친 곳 1개가 남았다. 경고 없음.」
    남은 것도 경고도 없으면 「리뷰 2라운드를 마쳤다 — 이상 없음.」이다.
  - 첫 줄은 여전히 그 라운드의 경고(degrade) 공시를 담는다 — 「경고 없음」·「이상 없음」·경고 내용 중 하나가 반드시
    들어간다. 「미검증」·라운드 미완이면 그 공시가 맨 앞에 온다. 그래서 첫 줄을 경고 채널로 이름 붙여 읽는 계약
    (각 스킬의 degrade 채널 절)은 뜻이 그대로이고, 그 문서들의 문구만 새 첫 줄에 맞춘다(Files to Modify).
  - 항목 머리 `[decide]`·`[미적용 fix]` 등을 쉬운 말 앞, id 괄호로 바꾼다.
  - 「순서:」 설명 줄은 항목 묶음 제목으로 흡수한다.
  - 0인 집계는 뺀다.
  - `다음:` 줄의 모드 토큰(`rereview`, `extra_approval`, `round_reviewed=false`)을 쉬운 말로 바꾼다.

  상태 이름의 쉬운 말 짝은 렌더 코드 옆 표(`STATE_GLOSS`)에 둔다. 기존 `CATEGORY_GLOSS` 와 같은 방식이다.
- **qg:**
  - `setup-qg.sh` 시작 배너 — 과정 나열을 뺀다.
  - `synthesize_findings.py` 의 「No high-confidence findings」 등 영어 고정 문구.
  - 범위 경고(`scope check degraded …`).
  - 범위·각도 블록(`scope:` · `angles:` YAML — 어떤 커밋·경계를 봤는가)은 화면에 원문 그대로 둔다. 스크립트가 낸
    쉬운 한 줄을 그 앞에 더한다(1라운드 리뷰 D1.3). 그 블록을 그대로 보이라는 기존 계약과 그 락은 바꾸지 않는다.
  - `cancel-qg` 메시지와 세션 시작 훅 경고.
- **plugin-audit:**
  - `render-audit-report.py` 의 「LD4」 같은 설명 없는 번호. 「좌: 0건」·「우: 0건」 줄은 지우지 않고 원칙 3 의
    「판단에 필요한 0」으로 쉬운 문장으로 바꾼다.
  - 영어 무결성 경고.
- **project-init:** 훅의 영어 경고 문구(`post-tool-use.py`).
- **spec-distill 펜스의 고정 경고:** 예) 「기준 사본이 없다」. 모델에게 쓰는 실패 안내(「플러그인 루트 미해석 — …」)는
  모델용 지시라 그대로 둔다.

### 4. 스킬이 시키는 질문·보고 틀

아래 규칙은 **모든 게이트**에 적용한다(1라운드 리뷰 D1.1): 승인 게이트, 리뷰 라운드마다 뜨는 게이트, request-framing
의 확정 게이트(`framing-requests/SKILL.md` 의 「게이트 질문 텍스트에 degrade 를 하나도 빠뜨리지 않고」 자리).

- **승인 게이트** — `conducting-interview/references/finishing.md`, `reviewing-spec/SKILL.md` 의 게이트, `proceed-gate.md`,
  `framing-requests/SKILL.md` 의 확정 게이트:
  - 경고 목록은 게이트 **앞 글**에 쉬운 말로 쓴다. 채널을 다 읽었는데 없으면 「이상 없음」 한 줄이다.
  - question 본문에는 결정 하나와 상태 한 줄(「경고 2개 — 위에 적었다」)만 둔다.
  - 「채널을 이름으로 밝히고, 읽은 뒤에만 없음을 쓴다」는 계약은 그대로다. 바뀌는 것은 보이는 자리다.
  - 머리글 「Proceed」는 「다음 단계」로 바꾼다.
  - 선택지 설명은 내부 동작(「status: confirmed로 반영 → 재저장 → 게이트 재실행」) 대신 고르면 무엇이 달라지는지를 쓴다.
- **리뷰 라운드 질문**(문서 리뷰 엔진 reference 와 각 호스트 SKILL):
  - 지금 규칙 「매 호출 첫 질문의 첫 줄은 렌더 첫 줄(degrade 공시)과 같다」(`reviewing-document.md`, 각 호스트
    SKILL)를 바꾼다. 렌더 첫 줄(상태·경고)은 호출 **앞 글**에 한 번만 쓴다. 질문 본문에는 결정 하나와, 경고가
    있으면 「경고 N개 — 위에 적었다」 한 줄만 둔다.
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

지적을 내는 쪽 **전부**가 대상이다(1라운드 리뷰 D1.4 — Goal 6 을 좁히지 않고 생산자를 넓혔다).

- **문서 리뷰 엔진의 리뷰어**(`shared/docreview/agents/doc-critic.md` · `doc-critic-web.md` · `doc-recritic.md` 와
  그 플러그인 사본, 그리고 문서 리뷰 codex 러너 `run_docreview_codex_reviewer.sh` 의 프롬프트):
  - 이미 사람용 칸(그대로 두면 · 고치면 · 근거)을 쓴다. 재비판자가 새로 더한 지적도 같은 칸을 쓴다.
  - 그 칸 설명에 「처음 보는 사람이 읽는다 — 내부 번호 없이 쉬운 말로」 한 줄을 더한다.
- **qg 보안 리뷰어 · artifact-critic · artifact-adversarial, plugin-audit 감사자, codex 리뷰어 셋**
  (qg 코드 리뷰 · qg 비코드 리뷰 · plugin-audit 감사의 codex 러너가 쓰는 프롬프트):
  - finding 형식에 `plain:` 칸(사람에게 보일 한 문장)을 더한다.
  - 화면 출력은 `plain:` 이 있으면 그것을 먼저 쓰고, 원래 요약을 뒤 괄호에 둔다.
  - `plain:` 이 없으면 지금처럼 낸다. 없는 칸 때문에 finding 을 버리지 않는다 — 버리면 처분 회계에서 소실이 된다.
- **qg 코드 리뷰의 나머지 생산자 둘(2라운드 리뷰 D2.8):**
  - 기본으로 붙는 외부 추가 리뷰어(`pr-review-toolkit:code-reviewer` 등): `quality-pipeline/SKILL.md` 가 그 리뷰어에게
    보내는 dispatch 프롬프트(devbrew 가 쓰는 글)에 `plain:` 한 줄을 더한다. 외부 agent 정의와 그 모델 고정은 건드리지
    않는다. 외부 리뷰어가 칸을 채우지 않으면 지금처럼 나간다.
  - 코드 재비판자가 새로 더한 지적(`added`): `references/recritic-code-profile.md` 의 added 형식에 `plain:` 을 더하고,
    `recritic_bridge.py` 가 그 칸을 합성기로 넘기게 한다.
  - 이 둘도 AC9 의 「§5 의 `plain:` 생산자 전부」에 든다.
- **칸이 화면까지 가는 길.** 리뷰어가 쓴 `plain:` 은 중간 변환·합성기를 지나며 허용 필드만 남기는 자리에서 지금은
  버려진다(예: `synthesize_artifact_findings.py` 의 `phase_key` · `kept` — 1라운드 리뷰가 실행으로 확인). 아래 각 단계가
  `plain:` 을 그대로 넘기게 고친다. AC9 가 이 길 전체를 잰다.
  - 형식을 정하는 곳: 각 agent 정의, codex 프롬프트 빌더(`build_codex_prompt.py` · `build_artifact_codex_prompt.py` 의
    `PROMPT_TEMPLATE` — 러너 셸이 아니다), plugin-audit Workflow 출력 스키마(`audit-workflow.js` 의 `AXIS_SCHEMA` —
    `plain` 은 선택 속성, required 에 넣지 않는다).
  - 넘기는 곳: `codex_findings_to_yaml.py`(qg · spec-distill), `codex_audit_to_json.py`(plugin-audit — 항목을 통째로
    넘겨 고칠 것이 없는지 확인만), `recritic_bridge.py`.
  - 그리는 곳: `synthesize_findings.py` · `synthesize_artifact_findings.py` · `render-audit-report.py`.
  - `shared/codex/prompt-preamble.md` 는 공통 리뷰·비신뢰 입력 규약이라 형식의 자리가 아니다.
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
    와 같다. 시작 표시 줄은 H1 제목(frontmatter 뒤 첫 `# ` 줄) 다음의 첫 비어 있지 않은 줄이다. 대상 수 0이면 RED.
  - **변이:**
    - 한 복사본의 글자 하나 바꾸기 → RED
    - 한 파일에서 블록 지우기 → RED
    - 블록 없는 새 SKILL.md 추가 → RED
    - 블록을 파일 끝으로 옮기기 → RED
    - 블록을 H1 앞(frontmatter 바로 뒤)으로 옮기기 → RED
    - 블록을 H1 과 블록 사이에 다른 문단이 끼게 옮기기 → RED
    - 정본만 바꾸기 → RED
- **AC2 — 블록 크기.**
  - **조건:** 블록이 19줄 이하이고, 블록을 15곳에 넣은 상태에서 `test_no_new_duplication.sh` 가 GREEN 이다.
    PR 1 본문에 블록의 토큰 수와, 파일마다 앞 5,000토큰 경계 밖으로 밀려난 절의 목록이 있다. 밀려난 절에 그
    파일의 kill switch · 진입 검사 · 게이트 절이 없다.
  - **변이:** 블록을 20줄로 늘리기 → 크기 락 RED. 블록을 frontmatter 바로 뒤로 옮기고 19줄로 늘리기 → 중복 락 RED.
- **AC3 — 문서 리뷰 게이트 렌더.**
  - **조건 ①** 첫 줄이 쉬운 상태 문장이다.
  - **조건 ②** 0인 정상 집계 항목이 출력에 없다. 0이 아닌 항목만 쉬운 말로 나온다.
  - **조건 ③** 항목 줄이 쉬운 말로 시작하고 id 는 괄호 안에 있다.
  - **조건 ④** 「미검증」·codex 없음·라운드 미완은 「이상 없음」과 같은 줄에 나오지 않고 따로 나온다.
  - **조건 ⑤** 대표 사례 둘의 전·후가 기대 출력 파일(golden)에 있다.
  - **조건 ⑥** 남은 항목이 있는 라운드의 첫 줄은 「이상 없음」이 아니라 「경고 없음」(또는 경고 내용)을 담는다.
  - **조건 ⑦** plugin-audit 보고서에서 한쪽 근거가 없는 입력은 그 사실을 쉬운 문장으로 낸다(기존 「숨기면 안 됨」
    테스트가 계속 GREEN).
  - **변이:**
    - 0인 집계 줄 되살리기 → RED
    - codex 없음 상태에서 「이상 없음」 내기 → RED
    - 남은 항목이 있는데 「이상 없음」 내기 → RED
    - plugin-audit 의 빈 쪽 문장 지우기 → RED
    - id 를 앞으로 되돌리기 → RED
- **AC4 — 기계 경로 불변.**
  - **조건:** `docreview_state.py gate`(렌더 없음)의 JSON 키와 값이 같은 fixture 에서 고치기 전과 같다.
    §3 표의 각 소비자 테스트가 GREEN 이다.
  - **변이:** JSON 키 하나 이름 바꾸기 → RED.
- **AC5 — qg 판정 줄.**
  - **조건:** `^verdict:` 줄이 정확히 한 번, 형태가 그대로다. 새로 더한 쉬운 첫 줄은 `verdict:` 글자를 담지 않는다.
    `test_verdict_vocabulary.sh` 가 수정 없이 GREEN 이다. `scope:` · `angles:` 블록이 화면에 원문 그대로 남고
    (`test_topic_scope_wiring.sh` 의 해당 단언이 수정 없이 GREEN), 그 앞에 쉬운 한 줄이 있다.
  - **변이:** 쉬운 줄에 `verdict: clean` 넣기 → RED.
- **AC6 — qg 한국어.**
  - **조건:** `quality-pipeline/SKILL.md` 의 질문 셋과 완료 표, `synthesize_findings.py`·`setup-qg.sh`·`cancel-qg`
    의 사람용 고정 문구가 한국어다(코드·명령·식별자 제외).
  - **변이:** 질문 하나를 영어로 되돌리기 → 그 문구를 고정한 테스트 RED.
- **AC7 — 승인 게이트.**
  - **조건:** 모든 게이트 틀 — finishing.md · reviewing-spec 의 승인 게이트, framing-requests 의 확정 게이트,
    `reviewing-document.md` 와 각 호스트 SKILL 의 리뷰 라운드 게이트 — 에서 question 본문이 degrade 줄 목록과
    렌더 첫 줄을 싣지 않는다. 목록은 게이트 앞 글로 지시된다. 머리글이 「Proceed」가 아니다. 「채널을 읽은 뒤에만
    이상 없음」 문장이 남아 있다. spec-distill 이 보이는 핸드오프 `/compact` 명령에 규칙 유지 한 줄이 있다.
  - **변이:** 그 문장 지우기 → RED.
- **AC8 — 선택지 라벨 동작 일치.**
  - **조건:** 「되돌린다」·「그대로 둔다」 `case` 와 그 테스트가 GREEN 이다. `_CHOICE_LABEL` 이 상태(pre·post)에서
    계산된다.
  - **변이:** post 라벨을 pre 와 같게 바꾸기 → 기존 테스트 RED.
- **AC9 — 리뷰어 칸.**
  - **조건:** §5 의 `plain:` 생산자 전부(보안 리뷰어 · artifact-critic · artifact-adversarial · 감사자 · codex 러너 셋의
    프롬프트) 형식에 `plain:` 이 있다. 생산자마다 리뷰어 출력 fixture 하나가 변환·합성을 지나 화면 출력까지 가고,
    그 출력에 `plain:` 문장이 먼저 나온다. `plain:` 없는 finding 이 버려지지 않고 지금처럼 나온다.
  - **변이:**
    - 렌더가 `plain:` 없는 finding 을 건너뛰게 바꾸기 → RED
    - `synthesize_artifact_findings.py` 의 허용 필드에서 `plain` 빼기 → RED
    - `codex_findings_to_yaml.py` 가 `plain` 을 버리게 바꾸기 → RED
  - **조건:** 리뷰어 `tools:` 는 바뀌지 않았다(Law 2 락 GREEN).
- **AC10 — 소개 문구.**
  - **조건:** 네 플러그인에서 `check-staleness.py` 의 소개 문구 불일치가 0 이다.
  - **변이:** 한 쪽 글자 하나 바꾸기 → RED.
- **AC11 — `CLAUDE.md`.**
  - **조건:** 한국어 커밋·PR 문장과 Doc Conventions 범위 문장이 있다.
- **AC12 — 양 측정 기준선.**
  - **조건:** 측정 스크립트가 고정한 기록 목록(Verification Plan 3)의 파일만 읽어 다섯 값을 내고, 같은 목록에서
    두 번 돌리면 같은 값을 낸다. 그 값과 집계 정의가 PR 1 본문과 스크립트 머리에 있다. 목록에 없는 파일을 하나
    더해도 값이 바뀌지 않는다.
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
  - `shared/docreview/references/reviewing-document.md` (라벨 규약 문구, 「매 호출 첫 질문의 첫 줄은 렌더 첫 줄」 규칙,
    렌더 첫 줄을 degrade 채널로 부르는 문구)
  - `shared/docreview/agents/doc-critic.md` · `doc-critic-web.md` · `doc-recritic.md` 와 그 플러그인 사본
    (spec-distill 의 `doc-critic.md` · `doc-critic-web.md` · `doc-recritic.md`, quality-gates 의 `doc-recritic.md`)
  - `shared/docreview/scripts/run_docreview_codex_reviewer.sh` (프롬프트 한 줄)
  - `shared/codex/codex_findings_to_yaml.py` · `shared/codex/prompt-preamble.md` (`plain:` 칸을 넘긴다)
  - `shared/tests/fixtures/docreview/` 의 golden 과 `cases.sh`(「degrade 없음」 단언 포함)
- **spec-distill:**
  - `skills/conducting-interview/references/finishing.md` · `references/proceed-gate.md`
  - `skills/reviewing-spec/SKILL.md` · `skills/reviewing-brief/SKILL.md` · `skills/framing-requests/SKILL.md`
    (펜스 고정 경고, 출력 예시, 게이트 질문 틀, 렌더 첫 줄을 degrade 채널로 부르는 `## degrade 채널` 절,
    핸드오프 `/compact` 명령의 규칙 유지 한 줄)
  - `skills/conducting-interview/references/finishing.md` 의 degrade 채널 문구와 핸드오프 `/compact` 명령
  - `scripts/seed_review_log.py` (사람용 줄)
  - README(렌더 첫 줄 `degrade 없음` 을 말하는 줄 포함) · CHANGELOG · `plugin.json`
  - 해당 테스트들
- **quality-gates:**
  - `skills/quality-pipeline/SKILL.md` · `skills/critiquing-artifacts/SKILL.md` · `skills/publishing-pr-understanding/SKILL.md`
  - `commands/cancel-qg.md` · `scripts/setup-qg.sh` · `scripts/synthesize_findings.py` · `scripts/cancel-qg-core.sh`
  - `scripts/synthesize_artifact_findings.py` (`phase_key` · `kept` 가 `plain:` 을 넘기게)
  - `scripts/run_codex_reviewer.sh` · `scripts/run_artifact_codex_reviewer.sh` (프롬프트의 `plain:` 칸)
  - `hooks/session-start-advisor.py`
  - `agents/security-reviewer.md` · `agents/artifact-critic.md` · `agents/artifact-adversarial.md`
  - README · CHANGELOG · `plugin.json`
  - 해당 테스트들
- **plugin-audit:**
  - `scripts/render-audit-report.py` · `scripts/assemble-audit-data.py` · `agents/plugin-auditor.md` ·
    `skills/auditing-plugins/SKILL.md`
  - `scripts/run_audit_codex_reviewer.sh` · `scripts/codex-prompt-preamble.md` (프롬프트의 `plain:` 칸)
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
3. **양 측정.**
   - **측정 대상 고정(2026-10-08).** 세션 기록 목록을 경로·크기·수정 시각으로 고정해 두었다:
     `~/.claude/sdd-mirror/plain-language-output/transcript-manifest-2026-10-08.tsv`(594개 —
     `~/.claude/projects/-Users-jeonghokim-Downloads-devbrew*/` 바로 아래 `*.jsonl`). 조사 중간 자료
     (`complaints.txt` · `c3.txt` · `research-notes.md`)도 같은 폴더에 있다. 기록 본문은 사용자 폴더에 그대로 있고
     리포에 넣지 않는다.
   - **아래 숫자는 참고값이다.** 2026-10-08 조사 에이전트가 즉석 코드로 낸 값이고 그 코드는 남지 않았다. 에이전트가
     말한 「776개」는 위 목록의 어느 범위로도 다시 나오지 않는다(바로 아래 594 · 두 단계 아래까지 601 · 전체 1,757).
     - 턴당 보이는 글 중앙값 1,075자(p90 5,770)
     - 질문이 상태 줄로 시작하는 비율 21%
     - 한 호출에 여러 결정을 묶은 비율 33%
     - 영어 위주 최종 보고 147건 / 2,239건
     - 질문의 55%에 ID·해시·코드 토큰
   - **정식 기준선은 PR 1 이 만든다.** PR 1 의 측정 스크립트가 위 목록의 파일만 읽어 다섯 값을 낸다. 그 값과 집계
     정의(「턴」= 사람 메시지 사이 구간, 「보이는 글」= assistant `text` 블록, 각 비율의 분모)를 PR 1 본문과
     스크립트 머리에 적는다. 참고값과 크게 다르면 그 차이를 PR 1 본문에 적는다.
   - PR 4 머지 뒤 실제로 쓴 세션이 쌓이면 같은 스크립트로 새 기록을 잰다. 이것은 머지 조건이 아니라 사후 확인이다.
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
- **외부 스킬(superpowers)의 내부 번호(brief C9).** 규칙 블록은 devbrew 스킬·명령 파일에만 있다. 그래서 이렇게
  덮는다(1라운드 리뷰 D1.6):
  - 같은 세션에 devbrew 스킬이 돌았으면 그 블록이 맥락에 있어 superpowers 단계의 보고에도 닿는다.
  - spec-distill 이 다음 단계로 넘길 때 보이는 `/compact` 명령(`finishing.md` · `reviewing-spec/SKILL.md` 의 핸드오프)에
    「사람에게 쓰는 글 규칙(번호는 내용 뒤 괄호에)을 유지」를 한 줄 더한다. 압축 뒤 계획·구현 단계에도 규칙이 남는다.
  - **덮지 못하는 경우:** devbrew 스킬 없이 시작한 세션, 그리고 `/new` 로 새로 연 세션. 이때 superpowers 가 끌어오는
    번호는 풀어 쓰이지 않을 수 있다.
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
- **B6 — 규칙 블록 문장 승인**(§1 그대로). 1라운드 리뷰 D1.7 과 질문 답(「이상 없음」=전부 정상일 때만)을 반영해
  세 줄(적용 범위 끝 우선 문장 · 「이상 없음」 줄 · 판정 줄)을 바꾼 문장을 2026-10-08 에 다시 승인했다(「승인한다 (권장)」).
- **B7 — 스크립트 출력 세 원칙과 게이트 렌더 예시 승인.** 기각: 원문을 항상 뒤에.
- **B8 — D22 용어집 문서는 이번에 만들지 않는다.** 쉬운 말 짝은 렌더 코드 옆 표에 둔다(모델 판단, 보고함).
- **B9 — OQ13 리뷰어는 찾는 지시 불변 + 사람용 칸.** OQ15 qg 고정 문구는 한국어로(기계 토큰 제외 — 모델 판단, 보고함).
  질문·보고 틀 절 승인. 기각: 리뷰어 제외.
- **B10 — PR 넷 순서와 성공 확인 승인.** 기각: 측정 스크립트 없이 숫자만.
- **리뷰 끝 공시(2026-10-08).** 설계 리뷰 3라운드(재리뷰 상한 2/2)에서 열린 결정 0, 경고 0 으로 끝났다. 결정은
  D1.1~D1.7 · D2.8~D2.10 이 아래 엔진 줄에 있다.
  - 2라운드 재비판에는 리뷰 기준(프로필)을 줄여 넘겼다 — 「과함」 축의 판정 형식·태그 표·0건 출구 문장이 빠졌고
    축 이름·사다리·처분 규칙은 실었다. 그 라운드 재비판 판정은 9건 전부 확인이었다.
  - 참고 11건과 미룸 1건은 `### Deferred to plan` 표에 엔진이 박제했다. 3라운드 참고 중 계보로 묶여 문장이 표에
    남지 않은 셋은 그 절의 번호 목록 5~7 에 손으로 적었다 — 리뷰가 끝난 뒤의 편집이라 다시 리뷰받지 않았다.
- OQ11(쓰는 쪽별 고칠 목록)은 §3~§6 이, OQ12(기계가 읽는 줄의 경계)는 §3 표가, OQ17(선택지 칸 한도)은 「이름은 짧게,
  설명은 설명칸에」가 닫는다.
- D1.1 · r1 · adopt · 05bd2eac#r1.1 · "고친다(채택) — 모든 게이트로 (권장)" — Context 가 꼽은 두 번째 원인(질문이 엔진 상태 줄로 시작함, 21%)을 §4 는 승인 게이트에서만 고치고, 라운드 게이트와 framing-requests 확정 게이트에는 그 틀이 그대로 남는다.
- D1.2 · r1 · adopt · 3f7f5fc6#r1.1 · "고친다(채택) — 쉬운 문장으로 남김 (권장)" — 0건을 숨기는 원칙이 판단에 필요한 ‘반대쪽 근거 없음’까지 지운다.
- D1.3 · r1 · adopt · 3f7f5fc6#r1.2 · "고친다(채택) — 원문 유지+앞에 한 줄 (권장)" — qg 판정 옆에 그대로 보이던 범위·각도 블록을 쉬운 한 줄로 바꾸고 원문을 「기록에만」 두면, 이전 스펙이 락으로 고정한 공시를 지우는 것이다. 그런데 설계는 이를 근거 있는 재결정으로 다루지 않는다.
- D1.4 · r1 · adopt · 51c91d3d#r1.1 · "고친다(채택) — codex까지 칸 추가 (권장)" — Goal 6 은 「리뷰어 지적마다」 쉬운 한 문장이 있다고 약속하는데, §5 는 리뷰어 넷만 다루고 codex 리뷰어와 그 밖의 발견 생산자는 빠져 있다.
- D1.5 · r1 · adopt · 71be4b6e#r1.1 · "고친다(채택) — 토큰으로 잼 (권장)" — brief 가 배달 방식에 건 제약 셋 가운데 「기존 핵심 절차를 밀어내지 않게 짧게」를 설계가 재지 않는다. 블록 크기는 중복 락의 줄 수로만 정해졌다.
- D1.6 · r1 · adopt · ab3c1921#r1.1 · "고친다(채택) — 핸드오프에 한 줄 (권장)" — brief C9 의 「외부 스킬(superpowers)이 끌어오는 내부 번호도 보고할 때는 풀어 쓴다」를 담당하는 장치도, 한계로 적은 문장도 설계에 없다.
- D1.7 · r1 · adopt · de73c13e#r1.1 · "고친다(채택) — 따로 정한 곳 우선 (권장)" — 규칙 블록이 모든 SKILL.md 맨 앞에서 전역 규칙으로 읽히는데, 그 자리의 기존 출력 규약과 부딪히는 문장이 있고 어느 쪽이 이기는지 정한 문장이 없다.
- D2.8 · r2 · adopt · 10cccc05#r2.1 · "고친다(채택) — 둘도 칸 추가 (권장)" · supersedes D1.4 — §5 는 「지적을 내는 쪽 전부가 대상」이라고 하지만, /qg 코드 리뷰에서 지적을 가장 많이 내는 리뷰어 둘이 빠져 있다. 하나는 기본으로 붙는 외부 추가 리뷰어(pr-review-toolkit:code-reviewer 등)이고, 다른 하나는 코드 경로 재비판자가 새로 더한 지적(added)이다. 이 지적들에는 `plain:` 칸이 없어서 Goal 6 이 이 경로에서는 지켜지지 않는다.
- D2.9 · r2 · adopt · 93a5c0ad#r2.1 · "현재 변경 유지(채택) — AC (권장)" — finding 없이 바뀜: Acceptance Criteria (modified)
- D2.10 · r2 · adopt · e09185f8#r2.1 · "현재 변경 유지(채택) — Goals (권장)" — finding 없이 바뀜: Goals (modified)
- docreview 계수 — cca5d8c5-e0c9-4962-9d60-335d15c66846/2026-10-08-plain-language-output-design-c35758e8fe18be00 r1: advice_new=1 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — cca5d8c5-e0c9-4962-9d60-335d15c66846/2026-10-08-plain-language-output-design-c35758e8fe18be00 r2: advice_new=7 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — cca5d8c5-e0c9-4962-9d60-335d15c66846/2026-10-08-plain-language-output-design-c35758e8fe18be00 r3: advice_new=3 · advice_repeat=4 · mc_preexisting_new=0

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
4. 문서 리뷰 엔진 agent 사본들의 동기 방식 — spec-distill 의 `doc-critic.md` · `doc-critic-web.md` · `doc-recritic.md`
   와 quality-gates 의 `doc-recritic.md`(quality-gates 는 doc-critic 을 배포하지 않는다). 지금의 `copy-of` 계약을 따른다.
5. 문서 리뷰 화면의 항목 줄은 리뷰어의 `summary` 칸을 맨 먼저 보인다(`docreview_state.py` 의 `_rg_*` 렌더러 전부).
   §5 의 「처음 보는 사람이 읽는다」 한 줄을 그대로 두면·고치면·근거 칸만이 아니라 `summary` 칸에도 건다
   (3라운드 참고 — 아래 표의 `0caa2c01#r2.1` 계보로 묶여 문장이 표에 따로 남지 않았다).
6. 리뷰 라운드 게이트를 `AskUserQuestion` 4개씩 연속 호출로 나누는 지금 방식을 유지할지, 「서로 무관한 결정」의 기준이
   무엇인지(3라운드 참고 — 아래 표의 `7874b3bb#r2.1` 계보로 묶임). 사용자에게 묻고 정한다.
7. Files to Modify 를 §5 의 「형식을 정하는 곳 · 넘기는 곳 · 그리는 곳」과 맞춘다 — 러너 셸·공통 preamble 대신 빌더 둘,
   `audit-workflow.js` · `recritic-code-profile.md` · `recritic_bridge.py` 를 넣고, plugin-audit 의 형식 자리
   `codex-prompt-preamble.md` 를 §5 에도 적는다(3라운드 참고 — 아래 표 `1cdda836#r2.1` 과 같은 결함).

| # | 항목 |
|---|---|
| fccf272b#r1.1 | 참고(ambiguity) #acceptance-criteria — 블록 위치의 기준이 §2 에서는 「첫 제목 앞」, AC1 에서는 「첫 `## ` 제목보다 앞」이다. 게다가 블록 자신이 `## 사람에게 쓰는 글` 을 담고 있어, 순진하게 구현하면 이 검사는 블록 스스로 만족시킨다. 또 H1 뒤에 블록을 두어도 AC1 은 통과한다. |
| 3733b467#r2.1 | 참고(overdesign) #2-배달과-동일성-b5 — yagni: 블록 복사본을 다시 쓰는 동기 스크립트(`shared/style/sync_plain_language.py`)는 사용자가 두 번 승인한 13줄 블록 하나를 고칠 때만 쓰인다. 어긋남은 동일성 락이 이미 파일 이름으로 짚는다. — 고치면: 스크립트를 두지 않는다. 정본을 고치면 같은 커밋에서 15곳을 함께 고치고, 동일성 락이 어긋난 파일을 이름으로 댄다는 규약 한 줄을 §2 에 둔다. Files to Modify 에서도 그 파일을 뺀다. └ 천장: 블록 수정이 한 사이클에서 두 번 이상 되풀이되거나 대상이 30곳을 넘으면 그때 동기 스크립트를 더한다 |
| 0caa2c01#r2.1 | 참고(data_flow) #5-리뷰어-출력-b9 — plugin-audit 감사자가 지적을 내보내는 형식은 agent 파일만으로 정해지지 않는다. 실제로는 `audit-workflow.js` 의 출력 스키마(AXIS_SCHEMA)가 정한다. 그런데 §5 의 「칸이 화면까지 가는 길」과 Files to Modify 에 이 단계가 없다. 그래서 감사자 쪽 `plain:` 이 만들어지지 않거나 스키마에서 빠질 수 있다. — 고치면: §5 의 길에 「Workflow 출력 스키마(`audit-workflow.js` 의 AXIS_SCHEMA — findings 의 선택 속성 `plain`, required 에는 넣지 않는다)」를 더하고, plugin-audit 의 변환 단계를 `codex_audit_to_json.py`(통째로 넘김)로 바로잡는다. 같은 고침을 Files to Modify 의 plugin-audit 항목에도 반영한다(`scripts/audit-workflow.js`). |
| 7874b3bb#r2.1 | 참고(ambiguity) #4-스킬이-시키는-질문보고-틀 — 승인 게이트 절은 경고 채널이 비었다는 이유만으로 ‘이상 없음’을 허용해, 남은 항목도 없어야 한다는 확정된 조건과 충돌한다. — 고치면: 승인 게이트에서도 경고 채널만 비었으면 ‘경고 없음’을 쓰고, 남은 항목과 경고가 모두 없음을 확인했을 때만 ‘이상 없음’을 쓰도록 문장을 맞춘다. |
| 0b618227#r2.1 | 참고(testing) #acceptance-criteria — Goal 2(스크립트 출력의 첫 줄이 쉬운 상태 문장이고, 0인 집계 줄은 나가지 않는다)를 확인하는 기준이 문서 리뷰 게이트 렌더(AC3)에만 있다. qg 의 `synthesize_findings.py`·`setup-qg.sh` 배너·범위 경고, plugin-audit 보고서, project-init 훅, spec-distill 펜스 경고에는 「무엇이 보이면 통과인가」가 없다. AC6 이 이 자리들에서 재는 것은 한국어인지 하나뿐이다. — 고치면: AC6 을 넓히거나 새 AC 를 둔다. `synthesize_findings.py`(발견 0건과 1건 이상)·`render-audit-report.py`·`setup-qg.sh` 마다 fixture 를 두고, 출력의 첫 줄이 상태 문장이며 0인 정상 집계 줄이 없음을 기대 출력 파일(golden)로 고정한다. 변이: 0인 집계 줄 되살리기 → RED. 아니면 Goal 2 의 범위를 문서 리뷰 엔진 렌더로 좁히고, 나머지는 「사용자가 직접 돌려 읽기」(Verification 4)로만 본다고 명시한다. |
| 64366fc7#r2.1 | 참고(ambiguity) #context--why — Context 는 「지난 세션 기록 776개(질문 966개)를 읽었다」와 70%·21%·33% 를 사실로 단정한다. 그런데 Verification Plan 3 은 이 값들이 즉석 코드로 낸 참고값이고 776 은 고정 목록(594)에서 다시 나오지 않는다고 적는다. Context 의 표와 Metadata 의 「776개 기록」에 「참고값 — 정식 기준선은 PR 1」이라는 단서를 붙여야 한다. |
| 1cdda836#r2.1 | 참고(handoff_incomplete) #files-to-modify — qg codex 출력 형식을 고칠 파일이 실제 프롬프트 생성 파일과 다르게 적혀 있다. — 고치면: 수정 목록에 두 build_*_codex_prompt.py를 추가해 출력 형식의 소유자로 적는다. 공통 preamble, 러너, codex_findings_to_yaml.py의 역할을 각각 공통 지시·실행·필드 전달로 구분한다. |
| e365974e#r2.1 | 참고(ambiguity) #handoff-context — Handoff Context 의 숫자 둘이 본문과 맞지 않는다. 「프로그램이 글자로 읽는 줄 13군데」라고 했지만 §3 표는 11행이고, 「결정 기록 B1~B9」라고 했지만 결정 기록에는 B10 까지 있다(§9 도 B10 을 인용한다). |
| 3b4b8396#r3.1 | 참고(data_flow) #4-스킬이-시키는-질문보고-틀 — §4 는 확정 게이트의 degrade 목록을 question 본문에서 「앞 글」로 옮긴다. 그런데 framing-requests 에는 이 목록을 「게이트 질문 텍스트」라는 채널 이름으로 묶어 둔 계약이 있고, 같은 자리에 싣던 다른 내용도 있다. 설계는 이것들의 새 자리를 정하지 않았다. — 고치면: §4 의 framing-requests 확정 게이트 항목에 세 가지를 적는다. ① degrade 채널 이름을 「게이트 질문 텍스트」에서 「게이트 앞 글」로 바꾸고, 그 이름을 쓰는 세 자리(L810 처분 앵커, `## degrade 채널` 의 다섯째 채널, test_framing_review_contract.sh:535 리터럴)를 함께 고친다. ② 냉독 출력 전문은 앞 글로 옮긴다. ③ 저자 편집 덩어리 본문은 §1 의 「따로 정한 자리」라 질문 텍스트에 그대로 둔다(Goal 4 의 예외로 명시한다). Files to Modify 의 framing-requests 줄에도 같은 내용을 더한다. |
| 20bd0c10#r3.1 | 참고(overdesign) #acceptance-criteria — delete: AC2 의 「블록 19줄 이하 · 20줄로 늘리면 크기 락 RED」는 §2 가 스스로 최종 판정자로 둔 중복 락과 같은 경계를 한 번 더 재는 락이다. 그 크기 락이 어느 파일에 사는지도 §2 동일성 락 목록과 Files to Modify 어디에도 없다. — 고치면: AC2 조건에서 「19줄 이하」와 크기 락 변이를 빼고, 경계는 「블록을 20줄로 늘리기 → 중복 락 RED」 하나로 잰다. §2 의 「19줄을 넘기지 않는다」 문장도 「중복 락이 GREEN」으로 바꾼다. └ 천장: 중복 락의 창(WINDOW=20)이 바뀌거나 블록 자리가 H1 바로 다음이 아니게 되면 그때 줄 수 상한을 따로 둔다. |
| aabdbfc0#r3.1 | 참고(ambiguity) #3-스크립트가-내는-글-b7 — Goal 8·AC3⑤ 는 대표 사례 둘의 전·후를 문서 리뷰 렌더의 기대 출력 파일(golden)로 남긴다고 한다. 그런데 둘째 사례 「(codex 정상 · 재비판 정상 · 저자 편집 없음 · ask_open 0건)」은 `render_gate` 가 내는 줄이 아니라 모델이 쓴 게이트 글이다. 그래서 그 「전」이 어느 출력의 기대 파일인지 정해지지 않았다. §3 에 사례마다 전·후의 출처(옛 렌더 출력인지, 모델 글 인용인지)와 새 렌더가 대응하는 줄을 적는다. |
| 1cdda836#r1.1 | §3 은 「고칠 자리 (Files to Modify 에 전부)」라고 하지만, 사람에게 보이는 고정 문구의 전수 목록이 없다. 예를 들어 게이트 질문에 실리는 check_brief.py 의 advisories(finishing.md:317)는 빠져 있다. C3 「전부 고친다」를 채울 목록은 plan 이 grep 으로 도출해야 하는데, Deferred 에는 테스트 쪽 전수(2번)만 있다. |
