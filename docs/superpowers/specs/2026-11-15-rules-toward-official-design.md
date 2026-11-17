---
name: rules-toward-official
type: design
created_at: 2026-11-15
source_interview: docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/F6.md
roadmap: docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/roadmap.md
next_phase: superpowers:writing-plans
---

# 규칙 개정 — 설계

CLAUDE.md · 플러그인 저술 가이드 · 철학 문서의 규칙 가운데 사용자가 고른 여섯 자리를 Claude Code 공식 쪽으로 옮기고, 그 문장을 글자로 확인하는 테스트와 감사 검사를 함께 옮긴다. 새 쓰임은 짓지 않는다.

## 목차

- [Context / Why](#context--why) · [Goals](#goals) · [Non-goals](#non-goals) · [Anti-goals](#anti-goals) · [Constraints](#constraints) · [Approaches](#approaches)
- [설계](#설계)
  - [1. cost_class 를 metadata 아래로](#1-cost_class-를-metadata-아래로)
  - [2. integrity 규칙 걷어내기](#2-integrity-규칙-걷어내기)
  - [3. skill 의 disallowed-tools 를 규칙에 적기](#3-skill-의-disallowed-tools-를-규칙에-적기)
  - [4. plugin.json 은 name 만 필수](#4-pluginjson-은-name-만-필수)
  - [5. 판 올림 — 설치본이 바뀔 때, PR 에 한 번](#5-판-올림--설치본이-바뀔-때-pr-에-한-번)
  - [6. 저술 가이드의 낡은 자리](#6-저술-가이드의-낡은-자리)
- [있는 것 검토](#있는-것-검토) · [상류 · 하류 연계](#상류--하류-연계)
- [Acceptance Criteria](#acceptance-criteria) · [Files to Modify](#files-to-modify) · [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives) · [남는 한계](#남는-한계) · [미룸](#미룸)
- [번호 대조](#번호-대조) · [Metadata](#metadata) · [Handoff Context](#handoff-context) · [결정 기록](#결정-기록) · [지휘 기록](#지휘-기록)

## Context / Why

사용자는 이 레포의 규칙이 레포에만 맞춰져 있는 자리를 풀고 싶어 한다 — 「내가 말하는거는 우리 레포에 바이어스 되게 보다 표준에 맞게 가자는거였어」, 「가능하면 추가보다는 푸는 쪽으로 가고」. 맞출 표준으로는 Claude Code 공식을 골랐고 「참고내용으로 두는거야」 라고 했다. 그래서 공식과 다른 자리를 항목마다 물어 고른 것만 옮긴다(D14 · D34).

고른 자리의 지금 모습(공식 문서는 2026-11-15 에 조회했다. 레포 쪽 수는 조사 보고이고 계획의 첫 과제가 다시 확인한다):

1. **cost_class.** skill 10개가 frontmatter 맨 위에 `cost_class:` 를 둔다. 공식 skill frontmatter 에 그 키는 없다. 공식은 자기 키를 둘 자리로 `metadata`(자유 꼴의 map — Claude Code 는 내용을 읽지 않는다)를 준다. 모르는 맨 위 키는 Claude Code 가 조용히 무시하지만, 공식 문서는 패키징 · 업로드 길에서는 모르는 키가 오류로 멈춘다고 적는다.
2. **integrity.** CLAUDE.md 와 철학 문서 P21 이 plugin.json 의 `integrity` 필드로 의존을 고정하라고 적는다. 공식 plugin.json · 마켓플레이스 필드 표에 그 필드는 없고, 레포에서 그 필드를 쓰거나 읽는 곳도 0 이다.
3. **skill 의 disallowed-tools.** CLAUDE.md 는 skill 계층을 「이 계층은 제한이 아니다」 로 적는다. `allowed-tools` 는 지금도 그렇다(공식: 사전 허용일 뿐). 그런데 공식에는 skill 이 도는 동안 도구를 실제로 빼는 `disallowed-tools` 가 따로 있다. 규칙이 그 키를 말하지 않는다.
4. **plugin.json 필수 키.** CLAUDE.md 는 `name` · `description` · `version` 셋을 필수라고 적고 감사 검사가 셋을 요구한다. 공식은 `name` 하나만 필수이고, `version` · `description` · `author` 가 없으면 `claude plugin validate` 가 경고를 낸다.
5. **판 올림.** CLAUDE.md 는 「플러그인을 건드리는 모든 PR마다 bump」 라고 적는다. 이것을 지키게 하는 기계는 없다 — 문장 하나와 관행이다. `shared/` · `tools/` 가 바뀔 때 어느 플러그인을 올리는지는 어디에도 규칙으로 적혀 있지 않고, 옛 계획들이 서로 어긋나게 해 왔다(올린 기록 RC242 · 올리지 않은 기록 RC243 — 한 계획 문서 안에서도 어긋난다).
6. **저술 가이드의 낡은 자리.** 없는 agent 를 예시로 들고(`quality-gates:doc-recritic`), 금지된 command 문법 skill 을 안내하고, 스타터 트리에 지금 필수인 파일이 빠져 있다.

사용자가 인터뷰에서 「공식대로 가고 기존 판올림도 다시 다 검토해봐」 라고 한 재검토의 결과(바뀐 파일 기준 · PR 단위로 다시 셈): 판을 올린 사건 347건 가운데 30건(8.6%)은 그 플러그인의 실행 파일도 링크 대상도 바꾸지 않았다. CHANGELOG 헤딩 463개 가운데 139개는 한 PR 안에서 여러 번 올린 중간 판이라 기본 브랜치에 따로 있었던 적이 없다. 겹치는 것을 빼면 헤딩의 약 35% 가 새 규칙이면 없었을 것이다. 인터뷰 때의 근사(460 중 105)는 재현되지 않았다 — 이 수로 바꾼다.

## Goals

- 여섯 자리의 규칙 문장이 공식과 맞고, 그 문장을 확인하는 테스트 · 감사 검사가 새 문장으로 통과한다.
- 판을 올리는 때와 단위가 한 문단으로 정의돼, `shared/` 가 바뀔 때 무엇을 올리는지 문서에서 답이 나온다.
- 저술 가이드가 지금 레포의 실제 구조와 맞는다.

## Non-goals

- agent frontmatter 의 `model` 키 금지는 풀지 않는다 — 사용자가 설계 대화에서 다시 정했다(결정 기록). 그 금지 문장과 그것을 지키는 테스트는 그대로다.
- 저술 가이드를 새 코어(옆 로드맵이 세우는 팀 구조)에 맞추는 일은 이 에픽이 하지 않는다 — 새 코어를 정하는 옆 로드맵의 설계가 아직 머지 전이라 맞출 대상이 고정돼 있지 않다. 받는 곳은 F5(앞단 다시 짜기)다(미룸). 인터뷰가 정한 두 방향 가운데 이 에픽은 표준에 맞추는 쪽과 낡은 내용만 고친다.
- 철학 문서의 P8 밖을 훑어 앞단(request-framing · 인터뷰)에 닿는 문장과 낡은 서술을 고치는 일은 이 에픽이 하지 않는다 — 앞단의 이름과 단계가 F5 에서 바뀌므로 이름이 정해진 뒤 한 번에 훑는다. 받는 곳은 F5 다(결정 기록 D3.3 · 미룸). 이 에픽이 철학 문서에서 고치는 것은 고른 자리에 닿는 두 문장(P21 · P22)뿐이다.
- 원칙 P8 문장(철학 문서 78–88행)과 CLAUDE.md `## The Three Laws` 아래 글머리는 고치지 않는다 — 옆 로드맵 둘째 에픽의 몫이다(D29).
- 판 번호를 없애지 않는다(S18). 지금 네 플러그인의 plugin.json 은 키 넷(`name` · `version` · `description` · `author`)을 그대로 둔다.
- 새 쓰임을 짓지 않는다 — `disallowed-tools` 를 쓰는 skill, `version` 을 뺀 플러그인, 올림을 알리는 스크립트는 만들지 않는다.
- agent 24개의 맨 위 `cost_class:` 는 옮기지 않는다 — 공식 agent frontmatter 에는 `metadata` 같은 자유 칸이 없어 옮길 자리가 없고, 규칙 문장도 skill 만 말한다.
- 의존을 plugin.json 에 선언하지 않는다. kill switch 와 상태 자리는 F7 이다.
- 옛 CHANGELOG 헤딩과 옛 계획 · 설계문서는 고치지 않는다(역사 기록).
- project-init 이 사용자 레포에 까는 커밋 규칙 틀(`plugins/project-init/templates/shared/commit-conventions.md`)은 고치지 않는다 — 이 레포의 규칙이 아니라 사용자 레포용 틀이다.

## Anti-goals

- 규칙은 풀렸는데 테스트가 옛 문장을 계속 요구하거나, 테스트만 지워 규칙을 지키는 것이 없어지는 것.
- 푸는 일에 새 장치를 얹는 것 — 사용자는 「추가보다는 푸는 쪽」 을 골랐다.
- 옆 로드맵이 고칠 줄을 이 에픽이 먼저 고쳐 그쪽 설계를 묶는 것.

## Constraints

- 공식 자료는 따라야 할 기준이 아니라 참고다. 공식 쪽으로 옮기는 것은 사용자가 고른 여섯 자리와, 리뷰에서 따로 물어 고른 agent 문장 하나(설계 3 · 결정 기록 D1.2)에 한한다(D7 · D34).
- CLAUDE.md · 철학 문서는 옆 로드맵 둘째 에픽도 고친다. 이 에픽은 CLAUDE.md `### 메타데이터 & 버전 관리` · `### 컴포넌트 격리` 의 네 줄과 철학 문서 P21 · P22 의 두 문장만 고친다.
- 문장을 바이트까지 비교하는 테스트가 있다(`test_governance_no_capability_caps.sh` 의 CLAUDE.md cost 줄과 P22 첫 줄). 문장과 그 테스트는 같은 커밋에서 바꾼다.
- 감사 검사의 테스트(`plugins/plugin-audit/tests/test_check_shape_completeness.py` 의 `ANCHORS`)는 검사 항목마다 CLAUDE.md 의 구절 하나를 글자로 찾는다. 이 에픽이 바꾸는 구절은 둘이다 — 「필수: `name`, `description`, `version`」 과 「모든 skill에 `cost_class` 선언」. 설계 1 · 4 의 새 문장을 정하면 그 두 앵커를 같은 커밋에서 새 구절로 바꾼다. 앵커는 그 절 안에서 한 번만 나오는 구절이어야 한다.
- 락을 고치면 변이로 실패를 보이고 양성 대조를 둔다(저술 가이드 「devbrew 를 고칠 때의 규칙」).
- 판 번호를 순서 있는 값으로 읽는 코드(`conductor_state.py` 의 `own_version` · `check_deps.py`)와 CHANGELOG 정합 락은 그대로 돈다.

## Approaches

갈린 것은 판 올림 규칙을 어떻게 지키게 할지 하나다. 나머지 다섯은 문장과 검사를 함께 옮기는 한 길뿐이다.

- **길 1 — 문장만 고친다(고름).** 규칙 문장을 새 정의로 바꾸고 그 문장을 글자로 확인하는 검사만 맞춘다. 지키는 것은 지금처럼 사람과 리뷰다. 가장 작다. 빠뜨려도 기계가 잡지 않는 것은 지금과 같다.
- **길 2 — 문장 + 머지 전 알림.** 머지 전에 「올려야 하는데 번호가 그대로다」 를 알리는 스크립트를 둔다. 빠뜨림을 잡지만 새 스크립트 · 테스트가 생기고 링크 지도 계산을 계속 맞춰야 한다.
- **길 3 — 번호를 머지할 때 매긴다.** 병렬 PR 끼리 같은 번호를 두고 부딪히는 일이 사라진다. CHANGELOG 락 · 지휘 상태의 판 읽기 · 릴리스 흐름을 모두 바꿔야 해 규칙 문장을 고치는 이 에픽의 범위를 넘는다.

사용자가 길 1 을 골랐다 — 「길 1로 가자」. 이유(지휘자 권장 근거): 이 에픽의 일은 규칙을 공식 쪽으로 맞추는 것이고, 새 규칙은 지침 문장부터 두고 장치는 게이트일 때만 더한다. 길 2 는 빠뜨림이 실제로 문제가 될 때 얹을 수 있다(재료는 `test_copy_of_contract.sh` 의 링크 지도 도출에 이미 있다).

## 설계

아래 「새 문장」 은 뜻을 정한다. 낱말은 계획이 다듬을 수 있되, 바이트 비교 락이 걸린 두 문장(1 의 CLAUDE.md 줄 · 철학 P22 첫 줄)은 계획이 정한 최종 문장을 락의 고정값과 같은 커밋에서 맞춘다.

### 1. cost_class 를 metadata 아래로

- **skill 10개**(plugin-audit 1 · project-init 1 · quality-gates 2 · spec-distill 6)의 frontmatter 를 바꾼다. 값은 그대로다.

  ```yaml
  # 전
  cost_class: high
  # 후
  metadata:
    cost_class: high
  ```

- **규칙 문장 셋.**
  - CLAUDE.md `### 컴포넌트 격리`: 굵은 머리 「모든 skill에 `cost_class` 선언」 → 「모든 skill 은 frontmatter `metadata` 아래에 `cost_class` 를 선언한다」. 그 줄의 나머지(값 넷 · `high` 의 규모 알림 · 지출 승인을 묻지 않는다)는 한 글자도 바꾸지 않는다.
  - 철학 문서 P22 첫 문장: 「…를 frontmatter에 선언한다」 → 「…를 frontmatter `metadata` 아래에 선언한다」.
  - 저술 가이드 스타터 트리의 SKILL.md 주석.
- **감사 검사**(plugin-audit): `check-shape-completeness.py` 와 `check-staleness.py` 가 `metadata` 아래의 `cost_class` 를 선언으로 읽는다. 값 허용 집합은 그대로다. 맨 위에만 있는 skill 은 두 검사 모두 「선언 없음」 과 같게 낸다 — 옛 자리를 따로 알리는 갈래는 두지 않는다(리뷰 2라운드의 줄이자는 지적을 받았다 — skill 10개를 한 PR 에서 함께 옮겨 중간 상태가 없고, 맨 위에 남은 키는 호출 표면 검사가 잡는다).
  - `check-shape-completeness.py`: `skills_cost_class` 를 `present=false` 로 낸다. 출력 칸(`requirement` · `present` · `source_doc`)은 늘지 않는다.
  - `check-staleness.py`: 지금의 사실 하나를 그대로 쓰되 문장만 「`metadata` 아래에 cost_class 선언 없음」 이라는 뜻으로 고친다. 분류 칸(`category absence` · `norm` 은 `cost_class`)은 그대로다.
- **호출 표면 검사**(`shared/entry/check_invocation_surface.py`): skill 이 가질 수 있는 맨 위 키 목록(`SKILL_KEYS`)에서 `cost_class` 를 뺀다 — `metadata` 는 이미 들어 있다. 그 목록의 주석과 실패 메시지의 「공식 키 ∪ {cost_class}」 를 「공식 키」 로 고친다.
- **agent 는 그대로.** agent 의 맨 위 `cost_class:` 와 그 값을 확인하는 테스트는 건드리지 않는다.
- frontmatter 를 어떻게 읽을지(정규식 · 파서)는 계획이 정한다. 조건은 둘이다 — `metadata` 블록 밖의 들여쓴 `cost_class:` 를 선언으로 읽지 않고, 본문의 같은 글자를 frontmatter 로 읽지 않는다.

### 2. integrity 규칙 걷어내기

- CLAUDE.md `### 메타데이터 & 버전 관리` 첫 줄의 끝 문장 「보안-critical 의존성은 optional `integrity` field로 pin.」 을 지운다.
- 철학 문서 P21 의 floor 나열에서 「integrity-pin된 plugin-to-plugin trust」 를 지운다. 나머지(state secret hygiene · description prompt-injection 리뷰)는 그대로다.
- 고칠 검사는 없다(읽는 코드 · 락 0). `plugins/plugin-audit/scripts/check-integrity.sh` 는 이 필드와 무관하다(해시 목록을 만든다) — 건드리지 않는다.
- 보안 절의 문장을 지우는 변경이라 PR 본문에 근거(공식에 없는 필드 · 쓰는 곳 0)를 적는다.

### 3. skill 의 disallowed-tools 를 규칙에 적기

CLAUDE.md `### 컴포넌트 격리` 의 「`allowed-tools` 는 제한이 아니다」 줄을 고친다.

- 「**이 계층은 제한이 아니다.**」 → 「**이 키는 제한이 아니다.**」 — 틀린 것은 계층이 아니라 그 키에 대한 믿음이다.
- 뒤에 더한다: skill 이 도는 동안 도구를 실제로 빼는 키는 `disallowed-tools`(kebab)다. 그 skill 을 부른 턴에만 걸리고 사용자의 다음 메시지에서 풀린다. denylist 라 빠뜨린 도구와 내일 생길 도구는 막지 못한다 — Law 2 의 분리는 지금처럼 agent 의 `tools:` allowlist 로만 한다.
- 같은 절 agent 줄의 「agent frontmatter의 실재 필드는 `tools`(allowlist)와 `disallowedTools`(denylist) 둘뿐이다」 를 「agent frontmatter 에서 도구를 다루는 실재 필드는 … 둘뿐이다」 로 고치고, 헷갈리는 짝에 skill 의 `disallowed-tools`(kebab)를 더한다 — agent 에 kebab 으로 적으면 조용히 무시된다. 사용자가 고른 여섯 자리 밖의 문장이라 리뷰에서 따로 물었고, 함께 고치기로 했다(결정 기록 D1.2). 이유: 공식 agent frontmatter 에는 다른 필드가 많아 지금 문장이 글자 그대로는 틀리고, skill 의 kebab 키를 규칙에 올리면 헷갈릴 짝이 하나 더 생긴다.
- 고칠 검사 코드는 없다 — 호출 표면 검사가 skill 의 `disallowed-tools` 를 이미 허용하고, agent 의 kebab `disallowed-tools` 는 `test_agent_frontmatter_keys.sh` 가 이미 금지한다. 쓰는 skill 은 0 이고 이 에픽이 만들지 않는다.
- **request-framing 본문의 한 문장도 함께 고친다**(사용자 결정 — 결정 기록 B2). `plugins/spec-distill/skills/request-framing/SKILL.md` 의 「skill 계층에는 도구를 막을 수단이 없고, `allowed-tools` 는 제한이 아닙니다.」 를 「`allowed-tools` 는 제한이 아니고, 이 skill 은 도구를 빼는 키를 쓰지 않습니다」 는 뜻으로 고친다. 그 문장이 든 괄호의 나머지(does not — cannot 이 아니다)는 그대로다. 같은 뜻의 문장은 플러그인의 skill · reference · agent 에서 이 한 곳뿐이다(리뷰어 둘이 확인). 그 파일의 본문은 F3 도 고친다 — 고치는 것은 이 한 문장뿐이다.
- 다만 이 줄들의 낱말을 정할 때 지킬 글자 제약이 있다. `plugins/quality-gates/tests/test_law2_prose.sh` 가 두 가지를 금지한다 — 「실제 키」 라는 글자(CLAUDE.md · 저술 가이드 · 플러그인 README · 모든 SKILL.md · references 에서), 그리고 `allowed-tools` 와 `disallowed-tools` 를 빗금(`/`)으로 이은 짝(CLAUDE.md 에서). 새 문장은 「실재 키」 로 쓰고 두 키를 빗금으로 잇지 않는다. agent 줄을 글자로 확인하는 테스트(조사 보고: 이 파일과 `test_governance_no_capability_caps.sh`)는 고정값을 같은 커밋에서 맞춘다 — 계획의 첫 과제가 그 줄을 무는 자리를 다시 찾는다.

### 4. plugin.json 은 name 만 필수

- CLAUDE.md `### 메타데이터 & 버전 관리` 첫 줄: 「필수: `name`, `description`, `version`.」 → 필수 키는 `name` 하나다. `version` · `description` · `author` 를 빼면 `claude plugin validate` 가 경고를 낸다.
- 저술 가이드 스타터 트리의 plugin.json 주석과 끝 줄(「시작 버전 `0.1.0`」)을 같은 뜻으로 맞춘다 — `version` 을 적는 새 플러그인은 `0.1.0` 에서 시작한다.
- 감사 검사 `check-shape-completeness.py`: `name` 이 없을 때만 gap 이다. `version` · `description` 이 없는 것은 gap 이 아니다. `version` 이 있는데 문자열이 아니면 지금처럼 gap 이다.
- **그대로 두는 락 둘**(지휘자 판단): CHANGELOG 정합 락은 모든 플러그인에서 `version` 을 읽고, 소개 문구 짝 락은 `description` 을 읽는다. 지금 네 플러그인이 두 키를 그대로 두므로 두 락은 고치지 않는다. `version` 이나 `description` 을 빼는 플러그인이 처음 생기면 그 PR 이 두 락을 함께 고친다(남는 한계 · 미룸).

### 5. 판 올림 — 설치본이 바뀔 때, PR 에 한 번

CLAUDE.md `### 메타데이터 & 버전 관리` 첫 줄을 아래 뜻으로 다시 쓴다(굵은 머리 「모든 PR마다 SemVer bump가 붙는 `plugin.json`」 도 바뀐다).

> `version` 을 적은 플러그인은 설치본이 바뀌는 PR 에서 판을 올린다(major = breaking, minor = 새 surface, patch = fix) — 설치본은 판 문자열로 갱신을 알아채서, 올리지 않으면 사용자는 옛 사본에 머문다. 올림 단위는 기본 브랜치에 머지되는 PR 하나다 — PR 안에서 커밋마다 올리지 않는다. 플러그인 X 를 올리는 때는 그 PR 이 ① `plugins/X/` 아래 파일(그 폴더 바로 아래의 `tests/` 폴더 · `CHANGELOG.md` · `README.md` 는 제외)을 바꾸거나 ② X 가 심볼릭 링크로 싣는 `shared/` 파일을 바꿀 때다. 그 밖의 변경(`shared/tests/` · `tools/` · `docs/` 처럼 설치본에 실리지 않는 것)으로는 올리지 않는다. ① · ② 에 걸려도 동작에 닿지 않는 변경(주석 · 오탈자)만 있는 PR 은 이유를 PR 본문에 적고 올리지 않을 수 있다.

정의의 근거와 경계:

- **빼는 목록으로 쓴다.** 「scripts · skills · agents 가 바뀌면」 처럼 넣는 목록으로 쓰면 앞으로 생길 표면을 놓친다. `plugins/X/` 아래 전부에서 셋만 뺀다. 뺀 셋은 플러그인 폴더 바로 아래 것만이다 — 하위 폴더의 같은 이름(예: `skills/<이름>/README.md`)은 빼지 않는다. 그런 파일은 모델이 읽는 글일 수 있다.
- **`shared/` 가 설치본에 닿는 길은 셋**이다 — 심볼릭 링크 43개 · `copy-of` 글자 사본 16개 · SKILL.md 에 박힌 「사람에게 쓰는 글」 블록 10개. 사본과 블록은 바뀌면 반드시 `plugins/X/` 안의 diff 로 드러나 ① 에 든다. 플러그인 폴더 diff 없이 설치본이 바뀌는 길은 링크뿐이라 ② 가 그것을 받는다(K21 이 걱정한 「사본을 놓쳐 판이 그대로 남는다」 는 ① 이 막는다).
- **뺀 셋의 값.** `tests/` · `README.md` 는 설치본에 실리지만 실행 중에 읽는 코드가 없다(조사 보고). 그래서 같은 판의 설치본끼리 그 두 자리의 바이트가 다를 수 있다 — 동작은 같다.
- **기본은 올리는 쪽이고, 판단으로 뺄 수 있다**(사용자 결정 — 결정 기록 B1). 사용자가 고른 기준은 「설치본 동작이 바뀔 때만」 이다. 파일 기준인 ① · ② 는 그 기준을 기계 없이 따를 수 있게 한 기본값이라 주석만 바꿔도 걸린다. 그래서 동작에 닿지 않는 변경만 있는 PR 은 올리지 않을 수 있게 하되, 이유를 PR 본문에 적게 한다. 망설여지면 올린다 — 올리지 않아 생기는 잘못(사용자가 옛 사본에 머문다)이 올려서 생기는 잘못(헤딩 하나)보다 크다.
- **`shared/` 정본만 고치고 사본을 안 고친 PR** 은 정의대로 올리지 않는다. 사본이 정본과 갈라진 것은 `test_copy_of_contract.sh` 가 잡는다 — 판 규칙의 일이 아니다.
- **CHANGELOG 규칙은 그대로다.** 올릴 때마다 헤딩 하나를 쓴다. 정합 락(맨 위 헤딩 = plugin.json 판 · 건너뛴 번호 없음)은 고치지 않는다.
- **지키는 것은 사람과 리뷰다**(길 1). 새 스크립트 · 락을 두지 않는다.

이 에픽의 PR 자신에 정의를 적용한다 — skill 10개의 frontmatter 가 바뀌므로 네 플러그인이 모두 ① 에 걸린다. 플러그인마다 한 번씩만 올린다(plugin-audit 은 감사 기준이 바뀌어 minor, 나머지 셋은 patch — 번호는 머지 직전 기본 브랜치 위에서 정한다).

**문서 셋 밖의 두 자리도 함께 고친다**(사용자 결정 — 「함께 고치자」. 인터뷰가 「셋 밖이라 고칠지는 묻는다」 로 남긴 자리다).

- `docs/git-workflow/commit-conventions.md` 의 「자동 릴리스 도구 (`release-please`, `semantic-release`)가 이 매핑으로 version bump + CHANGELOG 생성.」 — 이 레포는 그런 도구를 쓰지 않고 손으로 올린다. 그 문장을 「이 레포는 자동 릴리스 도구를 쓰지 않는다 — 판은 CLAUDE.md 의 올림 규칙대로 PR 에 한 번 손으로 올린다」 는 뜻으로 고친다. 두 문서가 판 올림을 다르게 말하면 읽는 쪽이 아무 쪽이나 따른다.
- `shared/README.md` 의 낡은 수 둘(`entry/` 를 세 플러그인에 링크 → 넷 · `python/` 을 세 플러그인에 사본 → project-init 하나)을 고치고, 「여기 파일이 바뀔 때 어느 플러그인의 판을 올리는지는 CLAUDE.md 의 올림 규칙」 이라는 한 줄을 둔다. 그 파일 첫머리의 「설치본에 들어가지 않는다」 는 폴더를 두고 한 말이고, 링크로 실린 파일의 내용은 설치할 때 설치본에 들어간다 — 올림 안내 한 줄이 그 문장과 어긋나 보이지 않게 그 구분을 함께 적는다.
- 두 파일은 `shared/tests/test_invocation_surface.sh` 가 훑는 범위(`docs/git-workflow/**` · `shared/**`)에 든다 — 새 문장이 그 검사에 걸리지 않는지 본다.

### 6. 저술 가이드의 낡은 자리

`docs/plugin-authoring.md` 에서 고칠 곳(조사가 직접 읽은 것):

| 자리 | 지금 | 고침 |
|---|---|---|
| 트리의 `scripts/` 주석 | 「hook에서 호출하는 shell/python 헬퍼」 | 진입 skill 이 있으면 진입 사전 검사 스크립트(`entry_preflight.py`)가 여기 있다는 것과 그 밖의 헬퍼 |
| 트리 | `dependencies.md` · `references/` 가 없다 | 두 줄을 더한다(의존 표는 CLAUDE.md 가 요구한다) |
| 트리의 SKILL.md 주석 | 진입 단계 꼴 안내가 없다 | 진입 skill 의 꼴(`allowed-tools` 한 줄 · `!` 사전 검사 · `## 진입 단계`)을 한 줄로 가리킨다 — 본보기는 있는 진입 skill |
| model 문단의 예시 | `quality-gates:doc-recritic`(Phase 1.5 재비판) · 「이 플러그인의 사본」 | 실재하는 `spec-distill:doc-recritic` 으로 바꾸고 옛 용어 「Phase 1.5」 와 틀린 「이 플러그인의」 를 고친다. 그 문단의 규칙 문장(금지 · dispatch 인자의 재량)은 한 글자도 바꾸지 않는다 |
| 구현 단계의 skill 목록 | `command-development` 를 안내한다 | 뺀다 — CLAUDE.md 가 새 command 파일을 금지한다 |
| `plugin-dev` 의 `/create-plugin` | 옛 표기 | `plugin-dev:create-plugin` |
| 트리의 plugin.json · SKILL.md 주석, 끝 줄 | 1 · 4 의 옛 규칙 | 1 · 4 대로 |

Reference 구현 절의 「`agents/`, `references/`, `scripts/`, `skills/`를 shipping」 문장은 테스트가 글자로 확인하고 지금도 맞다 — 건드리지 않는다.

## 있는 것 검토

- 링크 지도를 도출하는 코드가 이미 있다(`shared/tests/test_copy_of_contract.sh` 의 배포 지점 도출). 길 1 은 이것을 쓰지 않는다 — 길 2 로 갈 때의 재료로 적어 둔다.
- 판 사이의 구조를 지키는 락이 이미 있다(`shared/tests/test_changelog_integrity.sh`). 올림 단위를 풀어도 그대로 돈다 — 고치지 않는다.
- 호출 표면 검사는 skill 의 `disallowed-tools` 를 이미 허용 키로 둔다. agent 의 kebab 키 금지도 이미 있다.
- 공식의 `claude plugin validate` 가 plugin.json 의 빠진 키를 경고한다 — 레포가 같은 검사를 다시 짓지 않는다.
- 레포 밖 것은 쓰지 않는다.

## 상류 · 하류 연계

- **받는 곳.** 없다(로드맵 의존 없음). 입력은 인터뷰의 결정과 공식 문서다.
- **넘기는 곳.** 고친 규칙과 올림 단위의 정의. 읽는 쪽은 넷이다 — 이 레포에서 일하는 모든 세션(CLAUDE.md), 플러그인을 감사하는 plugin-audit, 뒤 에픽 F7(CLAUDE.md `### 런타임 상태 & 훅` 을 고친다 — 이 에픽과 다른 줄), 옆 로드맵 둘째 에픽(CLAUDE.md `## The Three Laws` 아래 글머리와 철학 P8 — 다른 줄).
- **되돌아오는 길.** 길 1 로 빠뜨림이 실제 문제가 되면 길 2(알림)를 새 일로 연다.
- **같은 상태를 읽는 다른 표면.**
  - skill frontmatter: Claude Code(`metadata` 내용을 읽지 않는다) · plugin-audit 의 두 검사 · 호출 표면 검사 · skill 마다의 테스트. 넷 모두 이 에픽이 함께 옮긴다.
  - 설치된 옛 판의 plugin-audit 은 새 레포를 감사하면 skill 10개를 「선언 없음」 으로 센다 — 플러그인을 갱신하면 사라진다. 도는 세션은 시작 때의 판을 쓴다.
  - CLAUDE.md 의 줄을 글자로 확인하는 테스트 묶음(`test_governance_no_capability_caps.sh` 등)은 옆 로드맵이 고칠 줄도 확인한다. 줄 단위 고정이라 서로 다른 줄을 고치는 두 PR 은 글자로는 합쳐지지만, 둘째로 머지하는 쪽이 기본 브랜치를 합친 뒤 스위트를 다시 돌려야 한다(K19).
- **머지 순서.** 이 에픽은 진행 중인 다른 에픽이 고치는 SKILL.md 들의 맨 위 한 줄을 바꾼다(F3 · F4 · F5 · 옆 로드맵 둘째 에픽의 `epic-conductor/SKILL.md`). 본문과 다른 자리라 글자 충돌은 드물다. 이 에픽이 머지된 뒤 새 skill 을 더하는 브랜치가 옛 자리에 `cost_class` 를 두면 호출 표면 검사가 그 브랜치의 스위트 대조에서 잡는다 — `shared/tests/test_invocation_surface.sh` 가 레포의 실제 skill 을 훑고, 맨 위의 모르는 키를 실패로 낸다. 감사 검사의 테스트는 fixture 만 보고 skill 마다의 테스트는 이름이 박힌 기존 skill 만 봐서 이 일을 하지 못한다. request-framing 본문의 한 문장(설계 3)은 그 파일을 고칠 F3 와 한 줄이 겹칠 수 있다 — 먼저 머지된 쪽의 문장을 뒤 쪽이 기본 브랜치를 합칠 때 받는다. 이음매 담당은 지휘자다 — 이 PR 의 머지를 옆 세션에 알린다.

## Acceptance Criteria

- AC1 — skill 10개가 모두 frontmatter `metadata` 아래에 `cost_class` 를 갖고, 맨 위 `cost_class:` 줄은 skill 어디에도 없다. 값은 옮기기 전과 같다.
- AC2 — 두 감사 검사가 `metadata` 아래의 `cost_class` 를 선언으로 읽는다. 맨 위에만 있는 skill 과 어디에도 없는 skill 은 두 검사 모두 같은 「선언 없음」 으로 낸다. `check-staleness.py` 의 그 문장은 `metadata` 아래를 말한다. 두 검사의 출력 칸과 분류는 늘지 않는다.
- AC3 — 호출 표면 검사가 skill 의 맨 위 `metadata` 를 받고 맨 위 `cost_class` 를 모르는 키로 낸다. 그 메시지와 주석에 「∪ {cost_class}」 가 없다.
- AC4 — 규칙 문장 셋(CLAUDE.md cost 줄 · 철학 P22 첫 문장 · 저술 가이드 트리 주석)이 새 자리를 말하고, 그 줄의 나머지는 바뀌지 않았다. 그 문장을 확인하는 테스트(바이트 비교 포함)가 새 문장으로 통과하고 옛 문장으로 되돌리면 실패한다.
- AC5 — agent 파일의 `cost_class:` 줄과 그 값을 확인하는 테스트는 diff 가 없다.
- AC6 — CLAUDE.md 와 철학 문서에 plugin.json 의 `integrity` 필드를 말하는 문장이 없다.
- AC7 — CLAUDE.md 가 skill 의 `disallowed-tools` 를 도구를 빼는 실재 키로 적고, 그것이 Law 2 의 집행 지점이 아니라는 것과 agent 에서는 camelCase `disallowedTools` 라는 것을 함께 적는다. `disallowed-tools` 를 쓰는 skill 은 여전히 0 이다.
- AC8 — CLAUDE.md 와 저술 가이드가 plugin.json 의 필수 키를 `name` 하나로 적고, 빼면 공식 검증 명령이 경고하는 키 셋을 적는다.
- AC9 — 감사 검사가 `name` 만 있는 plugin.json 을 gap 으로 세지 않고, `name` 이 없으면 gap 으로 센다. `version` 이 있는데 문자열이 아니면 gap 이다.
- AC10 — 네 플러그인의 plugin.json 은 키 넷을 그대로 갖는다(`version` 값만 바뀐다). CHANGELOG 정합 락과 소개 문구 짝 락은 diff 가 없다.
- AC11 — CLAUDE.md 의 판 올림 문장이 올림 단위(머지되는 PR 하나 · PR 에 한 번)와 올리는 때(① · ②)와 올리지 않는 때를 적고, 동작에 닿지 않는 변경만 있는 PR 은 이유를 PR 본문에 적고 올리지 않을 수 있다는 판단 문장을 적는다. 「모든 PR마다」 는 없다.
- AC12 — 이 PR 이 네 플러그인의 판을 플러그인마다 정확히 한 번 올리고, 플러그인마다 CHANGELOG 헤딩이 하나만 늘었다.
- AC13 — 저술 가이드의 고칠 곳 표 일곱 행이 모두 고쳐졌고, 가이드가 예시로 드는 agent · skill 이름이 레포에 실재한다.
- AC14 — agent 의 `model` 키 금지 문장과 그것을 지키는 테스트는 diff 가 없다(저술 가이드 model 문단은 예시 구절만 바뀐다).
- AC15 — 철학 문서 P8 절과 CLAUDE.md `## The Three Laws` 절은 diff 가 없다.
- AC16 — 전체 스위트에서 이 브랜치에만 있는 실패가 0 이다.
- AC18 — request-framing 본문에 「skill 계층에는 도구를 막을 수단이 없다」 는 뜻의 문장이 없고, 그 자리에 「`allowed-tools` 는 제한이 아니다」 는 뜻과 「이 skill 은 도구를 빼는 키를 쓰지 않는다」 는 뜻이 있다. 그 파일의 다른 본문은 diff 가 없다.
- AC17 — `docs/git-workflow/commit-conventions.md` 가 자동 릴리스 도구가 판을 올린다고 말하지 않고 CLAUDE.md 의 올림 규칙을 가리킨다. `shared/README.md` 의 두 수가 실제와 같고, 판 올림 안내 한 줄과 「폴더는 설치본에 들어가지 않지만 링크로 실린 파일의 내용은 들어간다」 는 구분이 있다.

## Files to Modify

조사 보고의 목록이다. 계획의 첫 과제가 다시 찾아 빠진 자리를 올린다.

- 규칙: `CLAUDE.md`(네 줄) · `docs/philosophy/devbrew-harness-philosophy.md`(P21 · P22 의 두 문장) · `docs/plugin-authoring.md`
- skill 10개의 `SKILL.md` frontmatter: plugin-audit · project-init · quality-gates(artifact-critique · quality-pipeline) · spec-distill(epic-conductor · pm-interview · request-framing · reviewing-brief · roadmap-status · spec-review). request-framing 은 본문의 한 문장도 고친다(설계 3)
- 맨 위 `cost_class` 를 읽는 손 시나리오: `plugins/quality-gates/tests/e2e-scenarios.md`(리뷰가 찾은 자리 — 계획이 살아 있는 시나리오인지 확인해 고치거나 그대로 둔 이유를 적는다)
- 감사 · 검사: `plugins/plugin-audit/scripts/check-shape-completeness.py` · `check-staleness.py` · `shared/entry/check_invocation_surface.py`
- 테스트(문장 · 자리 · fixture): `plugins/quality-gates/tests/test_governance_no_capability_caps.sh` · `shared/tests/test_cost_disclosure.sh` · `shared/tests/test_invocation_surface.sh` · `plugins/plugin-audit/tests/test_check_shape_completeness.py` · `test_check_staleness.py` · `test_skill_orchestration.py` · `plugins/spec-distill/tests/test_epic_conductor_skill.sh` · `test_conducting_interview_stage.sh` · `test_pm_interview_entry.sh` · `test_reviewing_brief_skill.sh`
- 네 플러그인의 `.claude-plugin/plugin.json`(판) · `CHANGELOG.md`
- 문서 셋 밖의 두 자리: `docs/git-workflow/commit-conventions.md` · `shared/README.md`

고치지 않는 것: `shared/tests/test_changelog_integrity.sh`(로드맵의 경로 예약에 있으나 고칠 것이 없다) · agent 파일 전부 · model 키 테스트 14개 파일.

## Verification Plan

- 자리 옮기기: skill 10개를 훑어 `metadata` 아래 값이 있고 맨 위 줄이 없음을 함께 단언한다(부재만 단언하지 않는다). 감사 검사는 세 경우(새 자리 · 맨 위에만 · 없음)를 fixture 로 본다 — 뒤의 둘은 같은 「선언 없음」 이다. `metadata` 밖의 들여쓴 `cost_class:` 와 본문의 같은 글자는 선언으로 읽히지 않음을 본다.
- 문장 락: 새 문장으로 통과 · 옛 문장으로 되돌리면 실패. 바이트 비교 락은 줄의 나머지가 바뀌지 않았는지도 그대로 잡는다.
- plugin.json 검사: `name` 만 · 셋 다 · `name` 없음 · `version` 이 문자열 아님 네 경우. 지금 테스트의 「version 빠지면 gap」 단언은 방향을 뒤집는다 — 뒤집은 단언은 변이로 이빨을 확인한다.
- 부재(integrity · 「모든 PR마다」): 지운 문장이 없음을 단언할 때 같은 줄의 남은 구절이 있음을 양성 짝으로 둔다.
- 저술 가이드: 예시로 든 이름이 실재하는지는 파일 존재로 본다.
- request-framing 의 문장: 옛 문장이 없음을 단언할 때 새 뜻의 구절이 그 자리에 있음을 양성 짝으로 두고, 그 파일의 나머지 본문에 diff 가 없음을 PR 본문에 적는다.
- 손대지 않은 것: model 키 테스트 · agent 파일 · P8 절 · CHANGELOG 정합 락의 diff 가 0 임을 PR 본문에 적는다.
- 공식 검증 명령(`claude plugin validate`)은 돌릴 수 있으면 네 플러그인에 돌려 결과를 PR 본문에 적고, 못 돌리면 「재지 못함」 으로 적는다 — 경고 문장의 근거는 공식 문서 인용이다.
- 전체 스위트는 공유 스위트 잠금 아래에서 한 번 돈다.

## Rejected Alternatives

- **길 2 · 길 3** — Approaches.
- **넣는 목록으로 올림 단위를 정의하기** — 앞으로 생길 표면을 놓친다.
- **빼는 목록을 `CHANGELOG.md` 하나로 줄이기(설치 바이트 엄격형)** — 놓치는 길은 없지만 테스트만 · README 만 바꾼 PR 도 올린다. 사용자가 정한 것은 「설치본 동작이 바뀔 때만」 이다.
- **감사 검사가 맨 위와 `metadata` 아래를 둘 다 받기** — 옛 자리가 조용히 남는다. skill 10개를 한 PR 에서 함께 옮기므로 옮기는 동안의 중간 상태가 없다.
- **감사 검사가 「옛 자리」 를 따로 알리기** — 처음 설계에 있던 갈래다. 한 PR 에서 함께 옮겨 중간 상태가 없고 맨 위에 남은 키는 호출 표면 검사가 잡으므로 쓰일 자리가 드물다. 감사 결과에 옛 자리 skill 이 실제로 나오고 「선언 없음」 문장만으로 고칠 곳을 찾지 못했다는 보고가 생기면 그때 가른다.
- **agent 의 cost_class 도 옮기기** — 공식 agent frontmatter 에 자유 칸이 없다. 모르는 키를 또 하나 만드는 것이라 옮기는 뜻이 없다.
- **CHANGELOG 정합 락 · 소개 문구 짝 락을 `version` · `description` 없는 플러그인에 맞춰 풀기** — 그런 플러그인이 없다. 쓰임이 없는 갈래를 미리 짓지 않는다.
- **agent 의 model 키 허용(인터뷰의 원래 결정)** — 사용자가 다시 정했다(결정 기록).

## 남는 한계

- 판 올림을 지키는 것은 사람과 리뷰다. 빠뜨린 올림은 기계가 잡지 않는다 — 지금과 같다.
- 규칙은 `name` 만 필수로 풀렸지만, `version` 이나 `description` 을 실제로 빼면 락 둘(CHANGELOG 정합 · 소개 문구 짝)이 실패한다. 처음 빼는 PR 이 그 락을 고쳐야 한다.
- 같은 판의 설치본끼리 `tests/` · `README.md` 의 바이트가 다를 수 있다.
- 설치된 옛 판의 plugin-audit 은 갱신 전까지 새 레포의 skill 을 「선언 없음」 으로 센다.
- 레포 쪽 수(파일 · 테스트 자리)는 조사 보고다. 테스트는 조사에서 돌리지 않았다 — 「고치면 깨질 것」 은 읽고 내린 판단이다.

## 미룸

| 항목 | 이유 | 받는 곳 |
|---|---|---|
| 판 올림 빠뜨림을 머지 전에 알리기(길 2) | 사용자가 문장만 고치는 길을 골랐다. 빠뜨림이 실제 문제가 되면 연다 | 새 일(이 로드맵 밖) |
| 번호를 머지할 때 매기기(길 3) | 릴리스 흐름 전체를 바꾸는 크기다 | 새 일(이 로드맵 밖) |
| `version` · `description` 없는 플러그인을 락 둘이 받게 하기 | 그런 플러그인이 없다 | 처음 빼는 PR |
| agent frontmatter 의 `cost_class` 를 어디에 둘지 | 공식에 자유 칸이 없다. 규칙 문장도 skill 만 말한다 | 정해지지 않음 — 공식이 칸을 주면 다시 본다 |
| CLAUDE.md `### 런타임 상태 & 훅` 과 감사 검사의 「모든 훅에 kill switch」 앵커 | kill switch 와 상태 자리의 일이다 | F7 |
| 철학 문서의 P8 밖 — 앞단(request-framing · 인터뷰)에 닿는 문장과 낡은 서술 훑기 | 이 에픽은 훑지 않았다. 앞단의 이름과 단계가 F5 에서 바뀌므로 이름이 정해진 뒤 한 번에 훑는다(사용자 결정 D3.3) | F5 — 로드맵 수정으로 F5 의 범위와 경로 예약에 철학 문서를 더한다 |
| 저술 가이드를 새 코어(팀 구조)에 맞추기 | 옆 로드맵의 팀 구조 설계가 머지 전이라 맞출 대상이 고정돼 있지 않다 | F5 — 로드맵 수정으로 F5 의 범위와 경로 예약에 저술 가이드를 더한다 |
| 마지막 리뷰가 남긴 작은 지적 다섯 — 감사 검사 둘의 같은 함수 16줄 · 규칙 락의 `integrity` 부재 단언 범위 · 규칙 락의 링크 수 갈래 · 감사 파서의 작은 빈 곳(0열 주석이 `metadata` 블록을 닫는다 · 한 줄 꼴과 탭 들여쓰기 테스트 없음) · 부분 문자열 단언의 부정 꼬리 | 막는 지적이 아니다. F7 이 같은 감사 검사와 규칙 락을 고친다(사용자 결정 2026-11-17) — 할지는 F7 설계 대화에서 다시 묻는다 | F7 |

## 번호 대조

| 번호 | 반영/기각 | 자리 또는 이유 |
|---|---|---|
| C19 | 기각 | 사용자가 설계 대화에서 다시 정했다 — agent 의 model 키 금지를 남긴다(결정 기록 · Non-goals) |
| C20 | 반영 | 설계 5 · Context 의 재검토 결과 |
| C37 | 반영 | 상류 · 하류 연계 — 옆 로드맵 둘째 에픽의 범위와 줄을 읽어 갈랐다 |
| C38 | 반영 | 설계 3 의 agent 줄 고침 · 설계 5 의 문서 셋 밖 두 자리 · 설계 6 의 트리 |
| D7 · D14 · D34 | 반영 | Context / Why · Constraints |
| D8 | 반영 | 설계 6 — 표준에 맞추는 쪽과 낡은 내용. 새 코어에 맞추는 쪽은 F5 로 미룬다(Non-goals 의 그 줄 · 미룸 표) |
| D17 | 반영 | 설계 1 · 2 · 3 |
| D18 | 반영 | 설계 4 · 5. 「agent 의 model 키를 허용」 은 재결정으로 뺐다(결정 기록). kill switch 와 상태 자리는 F7 |
| D24 | 반영 | 설계 5 |
| D29 | 반영 | P8 을 옆 로드맵에 두는 것은 Non-goals · AC15. 그 밖의 공식과 다른 자리는 설계 1 · 2 의 철학 문서 두 문장(P21 · P22)이고, 철학 문서에서 판 올림 · 필수 키 · 도구 키를 말하는 다른 문장은 없었다(조사 보고 · 리뷰어 확인). 앞단에 닿는 문장과 그 밖의 낡은 서술을 훑는 일은 이 에픽이 하지 않고 F5 로 미룬다 — 사용자가 리뷰에서 그렇게 정했다(결정 기록 D3.3 · Non-goals 의 그 줄 · 미룸 표 · Handoff Context 의 로드맵 수정 ④) |
| D40 | 반영 | 설계 4 |
| OQ6 | 반영 | 설계 6 |
| OQ7 | 반영 | 설계 1 · 2 · 3. 의존 선언은 Non-goals |
| OQ9 · OQ11 | 반영 | 설계 4 · 5 — plugin.json 필수 키와 판 올림. OQ9 가 함께 물은 model 키는 재결정으로 뺐고(결정 기록), kill switch 와 상태 자리는 F7 이다(Non-goals) |
| OQ10 | 기각 | model 키 허용을 유지할지의 질문 — 재결정으로 금지를 남긴다 |
| OQ13 | 반영 | 설계 5 — 판 번호를 남기고 릴리스마다 올리는 길 |
| OQ21 | 반영 | Non-goals — P8 은 옆 로드맵 |
| OQ22 · OQ23 | 반영 | Context — 조사 보고와 직접 확인을 갈라 적었다 · 남는 한계 |
| OQ31 | 반영 | 상류 · 하류 연계의 머지 순서 |
| OQ33 | 기각 | model 키를 든 agent 가 생기지 않는다 — 알림 줄을 고칠 일이 없다 |
| OQ36 | 반영 | 설계 5 의 정의 |
| OQ39 | 반영 | Non-goals 의 「kill switch 와 상태 자리는 F7 이다」 줄 · 지휘 기록의 범위 줄 — 이 에픽은 규칙 문장과 검사만 맡고 레포 전역 이전은 F7 이 한다 |
| RC14 | 반영 | 설계 6 의 model 문단 예시 |
| RC23 · RC131 | 반영 | Non-goals · 상류 · 하류 연계 |
| RC65 | 기각 | 「허용으로 고친다」 — 재결정으로 금지 문장을 그대로 둔다 |
| RC71 · RC239 · RC241 | 반영 | 설계 5 — 올림 단위와 `shared/` 의 길을 규칙 문장에 적는다 |
| RC73 | 반영 | 설계 3 |
| RC75 · RC130 | 반영 | 설계 1 |
| RC84 | 기각 | model 키 재결정으로 「리뷰어 모델」 알림 줄을 맞출 일이 없다 |
| RC96 · RC100 | 반영 | Constraints · 설계 5 — 판을 읽는 코드와 정합 락은 그대로 |
| RC101 | 반영 | 설계 4 의 감사 검사 |
| RC138 | 반영 | Context — 다시 센 수로 바꿨다 |
| RC153 | 반영 | 설계 5 의 문서 셋 밖 두 자리 — 사용자에게 물었고 함께 고치기로 했다(결정 기록) |
| RC157 · RC235 · RC237 | 반영 | 설계 5 — 링크 · 사본 · 실리지 않는 것 |
| RC242 · RC243 | 반영 | Context — 어긋난 기록 |
| K9 | 반영 | Non-goals 의 「새 코어에 맞추는 일은 이 에픽이 하지 않는다」 줄 · 미룸 표 — 이 에픽은 규칙 문장과 검사만 맡는다 |
| K19 | 반영 | 상류 · 하류 연계 · Constraints 의 같은 커밋 |
| K21 | 반영 | 설계 5 — 사본은 ① 에 든다 |
| ST1 | 기각 | 「공식을 따라가」 로 물렸던 금지 유지 안을 사용자가 다시 골랐다(결정 기록) |
| ST2 | 반영 | 설계 4 · 5 |
| S1 · S6 · S9 · S18 · S23 · S32 · S34 | 반영 | Context / Why · Constraints · 설계 1–6 |
| S10 | 반영 | 설계 4 · 5(plugin.json 필수 · 판 올림 완화). 같은 답의 「agent 의 model 키 허용」 은 재결정으로 뺐고(결정 기록), 「kill switch · 상태 자리를 공식으로」 는 F7 이다(Non-goals) |
| S11 | 기각 | 「공식을 따라가」 — 같은 주제를 사용자가 다시 정했다(결정 기록) |
| S12 | 반영 | Context 의 재검토 결과 · 설계 5 |
| S24 · S25 · S29 | 반영 | Context · 남는 한계 — 미확인은 표시해 싣는다 · 올림 단위는 설계가 정한다 |
| S35 · S36 · S38 | 반영 | 설계가 답할 것 없음 — 인터뷰 절차의 선택이다(리뷰를 더 열지 않음 · 결과물에 싣는 양 · 한 로드맵에 둠). 그 결과인 이 에픽의 범위는 Non-goals 가 그대로 따른다 |
| «cc-host-marketplace» | 반영 | 설계 5 |
| «cc-memory» | 반영 | 설계 5 의 문서 셋 밖 두 자리 — 어긋난 두 규칙 |
| «cc-plugins-components» | 반영 | 설계 6. model 키 부분은 재결정으로 기각 |
| «cc-plugins-dependencies» | 기각 | 사용자가 고르지 않았다(Non-goals) |
| «cc-plugins-loading» | 반영 | 상류 · 하류 연계 — 도는 세션은 시작 때의 판 |
| «cc-plugins-reference» | 기각 | 설정 값의 길은 F7 의 일이다 |
| «cc-skills» | 반영 | 설계 1 · 3 |
| «cc-sub-agents» | 기각 | model 키 재결정 |
| «fowler-semantic-conflict» | 반영 | 상류 · 하류 연계의 머지 순서 |
| «google-small-cls» | 반영 | Non-goals — 새 쓰임을 짓지 않고 문장과 검사만 |

## Metadata

- 에픽: F6 「규칙 개정」 · 브랜치 `feature/rules-toward-official` · 계획 하나(PR 하나)
- 판: 네 플러그인 — plugin-audit minor · 나머지 셋 patch. 번호와 변경 기록 머리는 머지 직전 기본 브랜치 위에서 정한다
- 공식 문서를 읽은 날: 2026-11-15(skills · sub-agents · plugins 의 manifest-reference · loading · marketplace-reference · components)
- 기본 브랜치를 읽은 판: 6691b73d

## Handoff Context

- 로드맵의 F6 경로 예약은 파일 다섯이다. 이 설계의 Files to Modify 는 그보다 넓다(skill 10개의 머리 줄 · 테스트 열 개 안팎 · 감사 검사 둘 더). 로드맵 수정은 지휘자가 재분해 절차로 따로 하고, 넷을 함께 싣는다 — ① F6 범위 줄에서 「agent 의 model 키 허용」 을 빼고 로드맵의 결정 기록에 그 재결정을 적는다 ② F6 경로 예약을 이 설계의 Files to Modify 에 맞춘다 ③ F5 의 범위와 경로 예약에 「저술 가이드를 새 코어에 맞추기」 를 더한다(미룸 표) ④ F5 의 범위와 경로 예약에 「철학 문서의 P8 밖 — 앞단에 닿는 문장과 낡은 서술 훑기」 를 더한다(미룸 표). 로드맵이 고쳐지기 전에는 로드맵의 F6 범위 줄보다 이 문서의 Non-goals 와 결정 기록이 맞다 — 뒤 에픽(F7)과 다음 지휘 세션은 model 키가 허용된 것으로 읽지 않는다.
- 설계의 조사는 하위 agent 넷이 했다. 보고 원문은 지휘 자원 폴더(`relay/F6/research-*.md`)에 있다 — 계획 담당자에게는 내용으로 싣는다.
- 인터뷰의 원래 결정에서 달라진 것은 하나다 — agent 의 model 키(결정 기록의 원래 · 재결정 · 근거).
- 설계문서 점검(builder check)이 낸 질문은 둘이다. 하나는 사용자 몫이었고 사용자가 답했다(문서 셋 밖의 두 자리 — 결정 기록). 다른 하나(감사 검사가 「옛 자리」 를 어떤 꼴로 내는가)는 지휘자가 정해 설계 1 에 적었다가, 리뷰 2라운드에서 그 갈래를 뺐다(Rejected Alternatives). 점검이 짚은 사실 둘(호출 표면 검사에 `metadata` 가 이미 있다 · 감사 검사 테스트의 앵커 둘)도 설계 1 과 Constraints 에 반영했다.

## 결정 기록

- 2026-11-15 · agent frontmatter 의 `model` 키 금지를 풀지 남길지 → 「남길쪽이 맞네」
  - 원래: C19 「agent 의 model 키는 공식을 따라간다」(S11 「공식을 따라가」) · D18 의 「agent 의 model 키를 허용하고」
  - 재결정: 금지를 그대로 둔다. 이 에픽 범위에서 「agent 의 model 키 허용」 을 빼고 OQ33 을 닫는다. (「남길쪽이 맞네」 를 이렇게 읽은 것은 지휘자의 해석이다 — 무엇이 빠지고 남는지 되짚어 보였고 정정이 없었다.)
  - 근거: 같은 날 사용자가 하위 agent 의 모델을 정의에 박지 않고 띄울 때 지침으로 고르기로 했다(이 세션의 답 「보낼 때마다 판단 (권장)」).
- 2026-11-15 · 판 올림을 지키게 하는 길(길 1 문장만 · 길 2 문장 + 머지 전 알림 · 길 3 번호를 머지할 때 — 지휘자 추천 길 1) → 「길 1로 가자」
- 2026-11-15 · 문서 셋 밖의 두 자리(`docs/git-workflow/commit-conventions.md` 의 자동 릴리스 문장 · `shared/README.md` 의 낡은 수와 올림 안내)를 이 PR 에서 함께 고칠지 두고 갈지(지휘자 제안 함께 고친다) → 「함께 고치자」
- D1.1 · r1 · adopt · c43e2738#r1.1 · "고친다 — 미루고 받는 곳 적기 (권장)" — 저술 가이드를 새 팀 구조에 맞춰 고친다는 확정 방향의 절반이 설계 어디에도 없고 받는 곳도 적혀 있지 않은데, 대조 표는 반영으로 적는다 (D8 · K9).
- D1.2 · r1 · adopt · c7be5763#r1.1 · "고친다 — agent 문장도 함께 (권장)" — 사용자가 고른 여섯 자리 밖의 규칙 문장 하나(agent 의 도구 필드는 둘뿐이라는 문장)를 지휘자 제안만으로 고치는데, 사용자가 그 항목을 골랐다는 기록이 없다 (D34).
- B1 · 결정 · 2026-11-16 · 판 올림 정의의 경계 — 기본은 정의대로 올리되, 동작에 닿지 않는 변경(주석 · 오탈자)만 있는 PR 은 이유를 PR 본문에 적고 올리지 않을 수 있다는 판단 문장을 규칙에 더한다(리뷰 2라운드 참고 지적 · 설계 5 · AC11) — 「판단 문장을 더한다 (권장)」
- B2 · 결정 · 2026-11-16 · request-framing 본문의 「skill 계층에는 도구를 막을 수단이 없고」 문장을 이 PR 에서 한 문장만 고친다(리뷰 1 · 2라운드 참고 지적 · 설계 3 · AC18) — 「이 PR 에서 한 문장만 고친다 (권장)」
- D3.3 · r3 · adopt · 14a14507#r3.1 · "고친다 — F5 로 미루고 기록 (권장)" — 철학 문서에서 앞단에 닿는 문장을 고치는 일이 사용자 결정 기록 없이 다른 에픽으로 미뤄졌고, 받는 에픽의 범위와 경로 예약에 그 일을 더한다는 안내가 없다. 철학 문서의 낡은 서술을 살폈는지도 적혀 있지 않다 (D29).
- D3.4 · r3 · adopt · 1dfa0ba5#r3.1 · "모두 유지 (권장)" — finding 없이 바뀜: Verification Plan (modified)
- D3.5 · r3 · adopt · 3c0c80e8#r3.1 · "모두 유지 (권장)" — finding 없이 바뀜: 5. 판 올림 — 설치본이 바뀔 때, PR 에 한 번 (modified)
- D3.6 · r3 · adopt · 40fe4b15#r3.1 · "모두 유지 (권장)" — finding 없이 바뀜: 1. cost_class 를 metadata 아래로 (modified)
- D3.7 · r3 · adopt · 496041cc#r3.1 · "모두 유지 (권장)" — finding 없이 바뀜: Rejected Alternatives (modified)
- D3.8 · r3 · adopt · 6c8b9494#r3.1 · "모두 유지 (권장)" — finding 없이 바뀜: Files to Modify (modified)
- D3.9 · r3 · adopt · 93a5c0ad#r3.1 · "모두 유지 (권장)" — finding 없이 바뀜: Acceptance Criteria (modified)
- D3.10 · r3 · adopt · 96a0a3cc#r3.1 · "모두 유지 (권장)" — finding 없이 바뀜: 미룸 (modified)
- D3.11 · r3 · adopt · 9cb89df0#r3.1 · "모두 유지 (권장)" — finding 없이 바뀜: 목차 (added)
- D3.12 · r3 · adopt · c934ff7b#r3.1 · "모두 유지 (권장)" — finding 없이 바뀜: 상류 · 하류 연계 (modified)
- D3.13 · r3 · adopt · e3ff3375#r3.1 · "모두 유지 (권장)" — finding 없이 바뀜: Handoff Context (modified)
- D3.14 · r3 · adopt · efa7eaef#r3.1 · "모두 유지 (권장)" — finding 없이 바뀜: 3. skill 의 disallowed-tools 를 규칙에 적기 (modified)
- docreview 계수 — spec-distill-59ec298a/2026-11-15-rules-toward-official-design-75db0ee9fe392a94 r1: advice_new=1 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-11-15-rules-toward-official-design-75db0ee9fe392a94 r2: advice_new=3 · advice_repeat=1 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-11-15-rules-toward-official-design-75db0ee9fe392a94 r3: advice_new=2 · advice_repeat=1 · mc_preexisting_new=0

## 지휘 기록

- 범위 · 2026-11-15 · 설계 첫 메시지의 질문(이 규칙들 때문에 못 하고 있는 일이 있는가)은 model 키 항목 때문에 물은 것이었다. 그 항목이 빠져, 남은 여섯은 규칙 문장과 그것을 지키는 테스트 · 감사 검사까지만 설계한다고 지휘자가 정해 사용자에게 보였다(「새 쓰임을 지어 넣지는 않습니다」).
- 조사 · 2026-11-15 · 설계 전 조사 넷(규칙 자리 · 올림 단위 · 옆 로드맵과의 겹침 · 공식 문서)을 하위 agent 로 돌렸다. 테스트는 돌리지 않았다.

### Deferred to plan

| 2e6610eb#r2.1 | 새로 쓰는 문장들(skill 의 disallowed-tools 줄 · name 만 필수 줄 · 판 올림 문단의 올리는 때 · 문서 셋 밖 두 자리)을 무엇으로 확인하는지의 절차가 검증 계획에 없다 — 통과 기준은 수용 기준에 있으니 명령과 순서는 계획이 정한다 (AC7 · AC8 · AC11 · AC17). |

| # | 항목 |
|---|---|
| e98b4a3a#r1.1 | 참고(component_relations) #3-skill-의-disallowed-tools-를-규칙에-적기 — skill 에는 도구를 막을 수단이 없다는 같은 믿음이 request-framing 의 본문에도 글자로 있는데, 설계는 CLAUDE.md 만 고치고 그 문장을 다루지 않는다. — 고치면: 그 문장을 「`allowed-tools` 는 제한이 아니고 이 skill 은 도구를 빼는 키를 쓰지 않는다」 는 뜻으로 함께 고치고, 고칠 파일 목록과 머지 순서 절에 올린다(그 파일 본문은 다른 에픽도 고친다). 또는 두기로 하고 미룸 표에 받는 곳을 적는다. |
| 933e20af#r2.1 | 참고(overdesign) #1-cost_class-를-metadata-아래로 — shrink: 감사의 낡음 검사가 맨 위에만 있는 cost_class 를 「옛 자리」 사실로 따로 가르는 갈래와 그 문장 · 분류 칸 · 세 경우 fixture 는, 열 개를 한 PR 에서 함께 옮겨 중간 상태가 없고 스위트에서는 호출 표면 검사가 맨 위 키를 이미 잡는 이 설계에서 쓰일 자리가 거의 없다. — 고치면: 지금의 「선언 없음」 사실 하나를 「`metadata` 아래에 cost_class 선언 없음」 으로 문장만 고쳐 두 경우를 함께 낸다 — 갈래 · 「옛 자리」 구절 · 셋째 fixture 를 두지 않는다 └ 천장: 감사 결과에 옛 자리 skill 이 실제로 나오고 그 문장만으로는 고칠 곳을 찾지 못했다는 보고가 생기면 그때 가른다 |
| 805d643b#r2.1 | 참고(tradeoffs) #5-판-올림--설치본이-바뀔-때-pr-에-한-번 — 사용자가 고른 기준은 「설치본 동작이 바뀔 때만 올린다」 인데 규칙 문장은 「플러그인 폴더의 파일이 바뀌면 올린다」 로 정의돼 주석만 고쳐도 올리게 되고, 더 엄격한 대안은 바로 그 사용자 기준을 들어 기각했다 — 이 차이를 사용자가 골랐다는 기록이 없다 (D24 · S18). — 고치면: 둘 가운데 하나를 고른다 — (가) 정의는 그대로 두고 「동작에 닿지 않는 변경도 플러그인 폴더의 파일이 바뀌면 올린다」 를 사용자 결정으로 결정 기록에 남긴다 (나) 기본은 지금 정의대로 하되 주석 · 오탈자처럼 동작에 닿지 않는 변경만 있는 PR 은 이유를 PR 본문에 적고 올리지 않을 수 있다는 판단 문장을 규칙에 더한다. |
| 0dc75b00#r2.1 | 참고(data_flow) #상류--하류-연계 — 이 PR 이 머지된 뒤 다른 브랜치가 옛 자리에 cost_class 를 둔 새 skill 을 더했을 때 잡는 장치를 「감사 검사와 skill 테스트」 로 적었는데, 그 브랜치의 스위트에서 실제로 잡는 것은 호출 표면 검사다. |
| 89061cfa#r3.1 | 참고(feasibility) #5-판-올림--설치본이-바뀔-때-pr-에-한-번 — 판 올림 규칙의 새 문장을 설계에 적힌 글자대로 CLAUDE.md 에 넣으면 헌장 인용 락이 실패하는데, 설계가 든 글자 제약 목록에 이 락이 없다. — 고치면: 설계 5 에 글자 제약 한 줄을 더한다 — CLAUDE.md 와 철학 문서에 새로 쓰는 문장의 빗금 든 백틱 토큰은 실재 경로이거나 꺾쇠 자리표시(`plugins/<X>/` · `plugins/<X>/tests/`)나 글롭이어야 한다(`shared/tests/test_charter_citations.sh`). 인용문의 `plugins/X/` 와 `tests/` 표기를 그 꼴로 바꾼다. |
| a231cc98#r3.1 | 참고(ambiguity) #files-to-modify — model 키 금지를 지키는 테스트는 diff 가 없다는 수용 기준이 파일 단위로 읽히면, 이 에픽이 고치기로 한 테스트 파일과 부딪힌다 — 그 금지를 확인하는 단언과 cost 줄의 바이트 비교가 같은 파일에 있다 (AC14). — 고치면: Files to Modify 의 「고치지 않는 것」 줄에, `test_governance_no_capability_caps.sh` 는 cost 줄 · P22 고정값만 고치고 같은 파일의 model 규약 블록은 건드리지 않는다는 것과, 「model 키 테스트 14개 파일」 에 이 파일이 드는지 여부를 적는다. |
- spec 승인 · 2026-11-16 · 「승인 — 계획 담당자에게 (권장)」
- 병렬 답 · 2026-11-16 01:04 · 「병렬 (권장)」 · 준비 에픽 F3
- 리뷰 · 2026-11-16 · 세 라운드를 돌았다(재리뷰 상한 2). codex 는 세 라운드 모두 정상 종료 · 지적 0건. 상한 뒤 추가 라운드는 사용자가 열지 않았다 — 「열지 않음 (권장)」. 열린 지적 1개(D3.3 — 철학 문서 훑기를 F5 로 미룬 기록 네 자리)는 리뷰어의 재확인 없이 승인됐다. 참고 6건은 Deferred to plan 표에 있다 — 넷은 본문에 반영했고 계획이 받을 것은 셋이다: 규칙 문장의 빗금 든 백틱 토큰이 헌장 인용 락(shared/tests/test_charter_citations.sh)에 걸리지 않게 실재 경로 · 꺾쇠 자리표시 · 글롭으로 쓴다 · AC14 의 「diff 없음」 은 단언 단위다(test_governance_no_capability_caps.sh 는 cost 줄 고정값만 고치고 model 규약 블록은 건드리지 않는다) · shared/tests/test_invocation_surface.sh 는 F5 의 예약 파일이고 이 에픽은 fixture 의 cost_class 줄만 고친다
- 게이트 묶음 · 2026-11-16 · 승인 게이트 1단계의 「허가 없이 바뀐 곳」 11개(절 열한 곳)를 항목마다 묻지 않고 한 질문으로 묶어 물었다 — 모두 이 대화에서 사용자에게 말한 편집(사용자 답 둘과 지휘자가 정한 셋)이라 같은 성격이고, 「하나씩 본다」 선택지를 함께 두었다. 답은 「모두 유지 (권장)」 이고 열한 결정에 그 글 그대로 기록됐다
- 참고를 질문으로 · 2026-11-16 · 2라운드의 참고 지적 가운데 사용자 말과 범위에 닿는 둘(판 올림 정의의 경계 · request-framing 본문의 한 문장)을 승인 게이트를 기다리지 않고 따로 물었다(결정 기록 B1 · B2). 하나(감사 검사의 옛 자리 갈래)는 지휘자가 줄이는 쪽으로 받아 사용자에게 알렸다
- 재비판 입력 · 2026-11-16 · 2 · 3라운드의 재비판과 3라운드의 탐지에는 지적 목록과 프로필을 글자로 싣지 않고 작업 폴더 안 파일 경로(.claude/tmp/f6-review/)로 넘겨 읽게 했다 — 옮겨 적다 글자가 바뀌는 것을 피하려는 지휘자 판단이다. 내용은 엔진이 낸 목록과 프로필 펜스 출력 그대로다
- 계획 검토 · 2026-11-16 01:25 · 계획 담당자가 「설계에 없던 결정」 으로 올린 열하나를 지휘자가 갈랐다. 아홉은 설계가 계획에 맡긴 일이거나 테스트 안의 배치라 묻지 않고 계획대로 간다(새 테스트 파일 shared/tests/test_skill_cost_class_place.sh · F6 단언 블록의 자리 · 규칙 문장의 최종 글자와 CLAUDE.md 첫 줄의 새 굵은 머리 · 앵커 유일 단언 · metadata 를 읽는 함수를 두 감사 스크립트에 따로 두기 · 값 표 · 손 시나리오 e2e-scenarios.md 는 역사 기록이라 그대로 · 판 번호 · 테스트 주석). 둘은 감사 검사가 내는 결과를 설계 글자보다 넓히거나 좁혀 사용자에게 물었다 — 한 줄 꼴(metadata: {cost_class: high})을 선언으로 읽을지: 「여러 줄 꼴만 읽는다 (권장)」 · name 이 빈 글자이거나 글자가 아닐 때 빠진 것으로 셀지: 「빠진 것으로 센다 (권장)」. 두 답 모두 계획 그대로다. 이 질문 둘은 지휘자가 만든 질문이다(relay/F6/relay-1.md)
- 실행 방식 · 2026-11-16 01:25 · writing-plans 가 권한 Subagent-driven 을 구현 담당자의 미리 받은 답으로 실었다. 계획 담당자의 마지막 보고 원문은 지휘 자원 폴더 relay/F6/plan-report-received.md 에 있다
- 판 번호 · 2026-11-17 21:51 · 기본 브랜치가 두 번 앞서 갔다 — 먼저 8.18.0(PR #291)이 머지돼 8.18.1 로 옮겼고, 이어 8.19.0 · 8.19.1 과 quality-gates 15.0.0(PR #293 · #294 · #292)이 머지돼 spec-distill 8.19.2 · quality-gates 15.0.1 로 다시 잡았다(커밋 65645a79). 충돌은 판 줄과 변경 기록 머리뿐이었다. plugin-audit 1.8.0 · project-init 5.4.2 는 그대로다
- 구현 뒤 · 2026-11-17 21:51 · AC16 은 구현 담당자가 미룸으로 보고했고 지휘자의 스위트 대조(65645a79 대 948c37d2)가 새 실패 없음으로 닫았다. 구현 담당자의 끝 전체 스위트(2cff292a)의 실패 일곱은 모두 기본 브랜치 사본에도 있다. 마지막 리뷰가 남긴 작은 지적(감사 검사 둘의 같은 함수 16줄, 규칙 락의 integrity 부재 범위와 링크 수 갈래, 감사 파서의 작은 빈 곳, 부분 문자열 단언)은 PR 본문에 싣고 받는 곳은 사용자에게 묻는다
- 재분해 · 2026-11-17 · 로드맵의 F6 칸을 이 설계에 맞췄다(범위에서 agent 의 model 키 허용을 빼고, F5 로 넘긴 둘을 안 한다로, 경로 예약 열여덟) — 로드맵 수정 PR #295, 사용자 승인 「이대로 다시 나눈다 (권장)」
- 머지 전 확인 · 2026-11-17 22:05 · 스위트 대조(65645a79 대 948c37d2) 새 실패 없음 — 이 브랜치에만 있는 실패 0개, 양쪽 다 있는 실패 11개. 통합 리뷰는 막는 결함을 찾지 못했고 지적 여섯을 냈다(이 PR 이 고침 하나 — 테스트 파일의 낡은 주석 두 줄, 커밋 9c865ed9 · 뒤 에픽이 고침 다섯 — F3 둘, 로드맵 수정 PR #295, F7, F5). 인계는 PR #296 본문에 있다. 스위트 대조 뒤에 설계문서 기록 커밋 둘과 주석 커밋 하나를 더했고 전체 대조를 다시 돌지 않았다
- 남은 작은 지적 · 2026-11-17 22:05 · 마지막 리뷰가 남긴 작은 지적 다섯의 받는 곳을 사용자가 정했다 — 「F7 로 넘긴다 (권장)」. 미룸 표에 한 행으로 올렸다

## 판정

### docs/superpowers/plans/2026-11-16-rules-toward-official.md

- ## 판정 전체 (원장의 Ruling: 줄, 내린 순서대로)
- Ruling: `git switch --ignore-other-worktrees` 를 하네스가 막아(worktree 격리) 그냥 `git switch feature/rules-toward-official` 로 섰다. 그 브랜치를 쥔 worktree 가 없어 효과는 같다 — 틀려도 드는 값: 없음(85854676 에 섰다).
- Ruling: Task 1(읽기만 하는 재확인 — diff 없음)은 컨트롤러가 직접 돌렸고 구현 · 리뷰 agent 를 띄우지 않았다 — 리뷰할 것이 없다 — 틀려도 드는 값: 놓친 확인 각도 하나. 파일마다 과제 리뷰가 덮는다.
- Ruling: Task 7 Step 5(설계 `## 미룸` 표에 행 추가)는 지휘자 지시로 하지 않는다. 미룸 · 빠짐 · 리뷰 후속은 이 보고에 목록으로 싣는다 — 틀려도 드는 값: 나중에 docs 커밋 하나.
- Ruling: Task 6 — origin/main 이 움직였으므로 Task 6 시작 때 합치고 그 위의 다음 번호(1.8.0 · 5.4.2 · 14.10.1 · 8.17.1)로 정한다 — 지휘자 지시 — 틀려도 드는 값: 번호 다시 매기기.
- Ruling: 스위트 주인 이름은 f6-impl. 전체 스위트는 끝에 suite_lock 으로만 돌리고 과제 agent 는 돌리지 않는다.
- Ruling: 리뷰어는 `feature-dev:code-reviewer`(Write · Edit · Bash 없음 — Law 2)로 띄운다. 파일을 못 쓰니 보고를 글로 돌려준다 — 틀려도 드는 값: 리뷰 글이 컨트롤러 맥락에 들어온다.
- Ruling: Task 2 Step 2 는 「대조 넷」 이라 적었지만 테스트의 대조 단언은 다섯이다. 다섯 모두 옮기기 전에도 통과해야 한다 — 계획 글자 실수.
- Ruling: Task 5 의 저술 가이드 줄 번호는 이 브랜치에서 45 · 48 이다(계획은 47 · 50). 글자로 찾아 고친다 — 틀려도 드는 값: 없음.
- Ruling: Task 2 가 `shared/tests/test_variant_of_contract.sh` 를 고친 것을 받는다. V3 가 실제 spec-review SKILL.md 를 복제하고 variant_of.py 는 중첩 frontmatter 를 거절하기 때문이다. 두면 스위트가 RED 가 되고 variant_of.py 는 그대로다 — 틀려도 드는 값: 계획 목록 밖 테스트 파일 하나. (마지막 리뷰 결론: variant-of 마커는 agent 전용이라 실제 한계가 아니다.)
- Ruling: `_metadata_cost_class` 16줄이 두 감사 스크립트에 그대로 겹치지만 고치지 않는다. 계획과 지휘자 계획 검토가 self-contained 사본 둘을 골랐고, 20줄 중복 락 밑이다. 몸통 비교 락은 계획 밖 새 테스트다 — 틀려도 드는 값: 한 사본만 고치는 미래 수정이 다른 쪽을 놓친다. 다음 일 후보로 올린다.
- Ruling: Task 5 가 파이썬 사본 수 grep 에 `--exclude-dir=tests` 를 더한 것을 받는다. 테스트 파일 자신이 그 글자를 품어 2 를 셌다(계획 글자 결함). 뜻은 같다 — 틀려도 드는 값: tests/ 아래 둔 미래 사본은 세지 않는다.
- Ruling: SDD 의 「마지막 리뷰 뒤 작업 폴더 삭제」 는 지휘자 지시로 하지 않는다 — 틀려도 드는 값: 디스크만.
- Ruling: 고침 묶음은 Important 하나와 Minor 둘(place 깊이 · staleness 사본 테스트)이다. Minor 둘은 남긴다 — governance :293 의 `integrity` 부재 범위는 좁히면 CLAUDE.md 전체를 거는 AC6 이 약해진다(틀려도 드는 값: 무관한 integrity 문장이 생기면 거짓 RED). governance :333 의 case 3/4/5 는 꾸밈 문제다(틀려도 드는 값: 링크가 6개가 되면 헷갈리는 메시지).
- Ruling: 줄 서 있던 내 스위트를 멈추고 고침 묶음을 먼저 넣었다. 잠금은 'merge_check feature/front-stage-exit'(01:40:23)이 쥐고 있었고 내 실행은 시작 전이었다 — 틀려도 드는 값: 없음.

## 구현 대조 — docs/superpowers/plans/2026-11-16-rules-toward-official.md

- 구현 대조: 경고 6개 — 보고에 없는 AC 0개 · 미룸 표에 없는 미룸/빠짐 0개 · 받는 곳 없는 미룸 6개 · 받는 곳 검사 불가 0개 · 빠짐 0개
- 보고: AC 18개 중 구현됨 18 · 미룸 0 · 빠짐 0
