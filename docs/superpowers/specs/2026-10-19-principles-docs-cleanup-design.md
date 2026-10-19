---
name: principles-docs-cleanup
type: design
created_at: 2026-10-19
source_interview: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R11.md
roadmap: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md
next_phase: superpowers:writing-plans
---

# R11 — 원칙 문서 정리 · Design

> 사용자가 세션에서 세운 상시 원칙이 devbrew 를 다른 레포에 설치해 써도 지켜지게, 원칙을 devbrew 의 추적 문서로 옮기고 낡은 개념은 지워 문서를 줄인다.

## Context / Why

사용자의 상시 원칙 상당수가 이 기기의 auto-memory 에만 있다. 메모리는 이 기기 · 이 레포 경로에만 붙으므로, devbrew 를 다른 레포에서 쓰거나 메모리 없는 세션에서는 그 원칙이 사라진다. 사용자 원문:

- 「내가 말하는 내용같은거 이번세션이나 저번 세션에서 메모리에 넣었자나 claude md나 devbrew철학 원장?  중요 docs들에 넣고 지금은 낡은 개념들은 과감히 지워서 크기를 줄이자」(재분해 #221)
- 「메모리에만 적는게 아니라 메모리가 없는 레포에서도 실수하지 않도록 devbrew에 개선 해야해 이건 앞으로도 원칙이야」(2026-10-18)
- 성공 장면: 「내가 말한게 다른 레포에서 사용해도 지켜지면」(2026-10-18)
- 한계: 「모든걸 다 지키란말은 또 아니야 알지?」(2026-10-18)

계기가 된 실패(2026-10-18): 지휘자가 하위 agent 를 다른 worktree 로 두 번 헛보냈다. 「세션이 worktree 격리 중이면 agent 도 그 격리를 물려받는다」는 사실이 메모리에만 있고 지휘 절차에는 없었다.

## Goals

- 원칙 여섯(아래 §1)이 devbrew 개발 세션이 매번 읽는 CLAUDE.md 에 한 줄씩 있고, 이유 · 배경은 철학 문서에 있다.
- 지금 없는 장치를 가리키는 글 · 이미 바뀐 사실 · 중복 · 버전 이력 서사를 CLAUDE.md · 철학 문서 · 플러그인 README 넷에서 지워 문서를 줄인다.
- devbrew 개발 규칙이 된 교훈 몇 줄을 `docs/plugin-authoring.md` 에 둔다.
- 다른 에픽 몫(파일 · 조항)은 고치지 않고 넘김으로 보내고, 지휘자가 처리됐는지 확인한다.
- 머지 뒤 지휘 세션이 메모리를 Claude 의 원래 메모리 규칙대로 정리한다.

## Non-goals

- 메모리 232개를 전부 옮기는 것 — 고르는 기준(§2)을 넘는 것은 옮기지 않는다.
- 새 결정론 검사(원칙 준수를 재는 lint 등)를 더하는 것.
- 다른 열린 에픽이 잡은 조항 · 파일을 직접 고치는 것(§5 넘김).
- 플러그인 동작 변경. 교훈 가운데 플러그인 동작에 닿는 것은 R5 후속(R5 설계 `## 미룸`) · R2a · R10 이 고친다.
- CHANGELOG 의 지난 버전 항목 고치기 — 이력이라 그대로 둔다. 플러그인 CHANGELOG 넷에서 이력이 아닌 낡은 글(아직 내지 않은 머리 항목 · 지금 동작을 설명하는 안내 문단)만 이 에픽이 정리하고, 찾아보아 없으면 PR 본문에 「없음」을 적는다(D1.1).
- 짧아진 계획(superpowers 7.0.0 writing-plans)의 영향을 보완하는 장치 — 사용자 「짧아진 계획의 영향을 신경쓰진 일단 말아봐 그걸 근거로 과한 구현 안했음 좋겠으니」.

## Anti-goals

- 옮긴 원칙이 「언제나 X」 꼴의 고정 규칙이 되어 모델 판단을 옥죄는 것(흐름 고정 금지 원칙 자신을 어긴다).
- 문서가 정리 전보다 커지는 것.
- devbrew 가 superpowers 를 부르고 다루는 것을 「덮기」로 오판하게 만드는 문면.

## Constraints

- 레포 문서 규칙: Korean-primary, 영어는 식별자 · 고유명사 · 원문 인용 · 대응어 없는 기술어만(CLAUDE.md Doc Conventions). 원문 인용에 풀이를 붙이지 않는다.
- Self-narrating artifact 금지 — 출처 · 정당화 · 이력은 CHANGELOG · PR 에 두고 문서에는 행동에 필요한 것만.
- 헌장(CLAUDE.md · 철학 문서)을 읽는 락이 그대로 GREEN 이어야 한다(§Verification Plan 목록). 새로 옮겨 넣는 글도 `test_governance_no_capability_caps.sh` 의 금지(fan-out 을 숫자에 묶는 문장 · `≥5` · 「single-agent 를 default」 · `wall-clock`)와 `test_charter_citations.sh` 의 옛 이름 금지에 걸리지 않게 쓴다.
- 플러그인 README 를 고치면 그 플러그인 `plugin.json` patch bump 와 CHANGELOG 한 항목(번호는 머지 직전에 확정).
- 레포 전용 값을 박지 않는다 — 원칙 문면은 devbrew 밖 레포에도 맞게 쓴다.
- 외부 플러그인(superpowers) 파일 · 동작은 건드리지 않는다(C25 · C35 · D26).

## 설계

### §1 옮길 원칙 여섯 — CLAUDE.md 한 줄 + 철학 문서 이유

CLAUDE.md 의 알맞은 기존 절 안에 한 줄씩 둔다(새 큰 절을 만들지 않는다 — 크기). 한 줄은 「무엇을 한다」만 쓰고, 이유 · 배경 · 예외는 철학 문서의 해당 원칙으로 가리킨다. 철학 문서는 새 P# 를 만들기 전에 기존 P# 에 흡수할 수 있는지 먼저 보고(가벼움 기본값), 새 P# 가 필요하면 그 이유를 같은 절에 한 문장으로 적는다.

| # | 원칙 | 사용자 원문(근거) | CLAUDE.md 한 줄의 뜻 |
|---|---|---|---|
| 1 | 교훈은 devbrew 를 고쳐서 | 「메모리에만 적는게 아니라 메모리가 없는 레포에서도 실수하지 않도록 devbrew에 개선 해야해 이건 앞으로도 원칙이야」 | Law 3 의 「다음 세션」은 메모리 없는 레포의 다음 세션도 뜻한다 — 교훈은 그 동작을 내는 skill · reference · 스크립트 · 락을 고친다 |
| 2 | 흐름을 고정하지 않는다 | 「좋아 이게 앞으로의 원칙이야」 · 「다만 정석 파이프라인 흐름은 있긴 하겠지 … 의도를 무시하진 말아야 겠지」 | 규칙은 「기본은 X, 일의 모양이 다르면 모델이 판단하고 이유를 적는다」로 쓴다 · 결정론은 보안 · 정확성 게이트에만 · 정석 흐름의 의도는 지킨다 |
| 3 | 레포 전용 값을 박지 않는다 | 「하드코딩 부분은 다 변경하고(이건 devbrew에서 앞으로도 지켜야하는 부분이야)」 | 경로 · 테스트 명령 · 기본 브랜치 · 브랜치 접두 · 모델 · `gh` 같은 값은 도출하거나 레포마다 정하게 한다 |
| 4 | 상류 · 하류 연계 | 「devbrew에서는 이 연계성도 매우 중요한 파트니까 앞으로도 지키고」 | 설계마다 받는 곳 · 넘기는 곳 · 되돌아오는 길 · 같은 상태를 읽는 표면과 이음매를 고치는 쪽을 보인다 |
| 5 | 계층 · 온톨로지 · 컨트롤 플레인 진입점 | 「앞으로도 devbrew내에서는 적절한 곳에는 그래야하고」 | 여러 산출물 · 상태가 얽히면 객체 · 링크 · 속성 · 주인을 명시하고 진입점에서 따라 내려가게 한다(작은 일엔 과하게 만들지 않는다) |
| 6 | 있는 것 먼저 | 「기존에 있던거를 사용할 수 있는지 검토하는 성향이면 좋겠어 레포 내부든 외부든 … 다만 외부는 나한테 검토 받고 사용하는거로」 | 만들기 전에 레포 안 · 밖의 있는 것을 먼저 검토한다 · 외부 것은 사용자 검토 뒤에만 쓴다 |

이미 플러그인 동작으로 들어가 있어 CLAUDE.md 에 다시 적지 않는 원칙: 머지 전 확인 규약 · 하위는 단일 세션과 같은 skill 흐름 · 게이트 전달은 혼자 읽혀야 · 지휘 세션이 에픽을 직접 진행(모두 `plugins/spec-distill/references/conducting.md` · `conductor-dispatch.md`). 원칙 1 의 뜻대로 그 자리가 정본이다.

**두 갈래의 「다른 레포」.** CLAUDE.md · 철학 문서는 devbrew 를 개발하는 세션(메모리 없는 다른 기기 · 새 clone 포함)만 읽는다. devbrew 플러그인을 남의 레포에 설치해 쓰는 세션에서는 그 원칙이 플러그인의 동작 자리(skill · reference · 설계 틀 · 넘김 글)에 실려 있어야 지켜진다. 그래서 원칙 2~6 마다 플러그인 동작 자리를 표로 대조한다 — 계획의 첫 과제가 이 설계문서의 새 절 `## 플러그인 동작 자리 대조`(`## 미룸` 바로 앞)에 표를 만들어 커밋한다. 이미 실려 있으면 그 파일:줄을 적고, 빈 곳은 그 파일을 잡은 에픽(또는 R5 후속(R5 설계 `## 미룸`))으로 §5 넘김 행과 `## 미룸` 행을 더한다. 지휘 세션이 그 행을 받는 쪽의 설계 입력으로 넘기고, 받는 쪽이 머지되면 처리됐는지 확인한다. 이 에픽은 플러그인 동작 자리를 직접 고치지 않는다(Non-goals). 원칙 1 은 devbrew 개발 규칙이라 대조 대상이 아니다.

### §2 고르는 기준 (사용자 승인 「이 기준으로 (권장)」)

- 옮긴다: 사용자가 「앞으로도 · 원칙」이라 한 것, 또는 같은 실수가 다른 레포에서도 다시 날 교훈 — 둘 다 devbrew 가 어떻게 동작하는지에 닿을 때만.
- 옮기지 않는다: 그때 상황에만 맞던 지시 · 이 레포의 지난 일 기록 · Claude 가 원래 하는 일과 같은 것.
- 옮길 때는 그 동작을 내는 지시문 안에 한두 문장. 기계 검사는 보안 · 정확성에 꼭 필요할 때만.
- 다른 에픽이 잡은 파일 · 조항은 넘김으로 보내고 지휘자가 확인한다.

### §3 지울 낡은 개념

조사 기록(지휘 세션 `~/.claude/sdd-mirror/epic-decisions/r11/docs-recon.md` 의 표)에서 R11 몫만. 처분 종류는 넷이다 — 지금 장치가 없는 개념 · 이미 바뀐 사실 · 중복 · 이력 서사.

- **CLAUDE.md**: 훅 공존 줄의 signal tag 구절(`<{plugin}-signal>` 를 쓰는 곳 0) · Forbidden Patterns 머리의 「Full 카탈로그와 case study」(철학 문서에 case study 는 없다 — 가리키는 절 이름은 철학 문서의 실제 절에 맞춘다) · Polite handoff 줄을 `plugins/spec-distill/references/proceed-gate.md` 포인터와 금지 둘로 줄임(「spec-distill v0.11.0 AC19」 이력 · 옛 표현 지움) · 출처 · 실측 이력 괄호(`allowed-tools` 줄의 「2026-08-22 헤드리스 실측 5변형…」 · agent 줄의 「(`Monitor`가 … 그 실증)」 · Subagent spray 줄의 「(Opus 5 기본 시스템 프롬프트… 2026-08-22)」 · Korean-primary 줄의 「`*.ko.md` 동반 파일 모델은 폐기(…)」). Law 3 의 「인덱스를 자동 편집」 구절은 그 장치가 없으므로 §1 원칙 1 문장으로 바꿔 쓴다.
- **철학 문서**: Three Laws 절에서 CLAUDE.md 와 겹치는 문장만 줄이고, CLAUDE.md 에 없는 설명(명세 작성은 일급 단계 · 하드 규칙 · N+1 번째 작업이 더 쉬워야 · low-tech 메커니즘)은 남긴다 · AP18 · AP19 스텁(인용 0, CLAUDE.md 와 같은 글) · P8 예시의 redirect(v2.7.0 에서 지워짐 — 현재 floor 예시로) · P11 의 「다중 모델은 opt-in 게이트」(지금 codex 는 감지되면 늘 돌고 끄는 길은 kill switch) · P11 · P8 의 사례 이력 문장 · P13 의 signal tag · P14 끝의 「README 3곳 인용의 anchor target」 문장 · AP 앵커 도입과 P5 의 「Filesystem-as-Memory」 절 언급(CLAUDE.md 에 없음 — §런타임 상태 & 훅으로).
- **spec-distill README**: 줄머리 `**vX.Y.Z**` 이력 문단(`test_readme_sync.sh` 와 같은 패턴으로 지금 9줄)과 줄머리가 아닌 자리의 버전 이력 서사(CHANGELOG 에 있음) · 「문서 리뷰 엔진 기반(v0.56.0) — 아직 쓰는 쪽 없이…」 · 「엔진 결함 일곱(v0.58.0)…」 · 버전 꼬리표 괄호 · 중복(P14 네 번 · AP2 두 번 · Law 3 / P5) · 죽은 개념 `needs_interview` · 틀린 라벨(P11 에 steelman, P3 에 graceful degradation) · External source absorption 절의 출처 이력(사용자 판단 대신 지휘자 판정 — 출처는 CHANGELOG · PR 몫) · Hooks Installed 의 5.x 이력.
- **quality-gates · project-init · plugin-audit README**: R2a 가 바꾸는 동작 밖의 줄만(R2a 설계가 넘긴 몫) — qg 의 「dispatch builder」 · 없는 `codex-reviewer` agent 설명 · 「문서 리뷰 엔진 기반(v7.4.0)」 · 실측 이력 괄호 · v10.0.0 훅 삭제 이력 · `MAX_TOTAL_ITERATIONS` 이력, project-init 의 버전 꼬리표 · 「CLAUDE.md 는 짧은 anchor 만」(지금 생성물과 다름), plugin-audit 의 「즉시 제거 — 근거는 …」 정당화 서사 · 샌드박스 별칭 이력 · severity 통일 이력. 구성표 · 상한 수치 · 의도 출처 · artifact-critique · persona 모델 고정 같은 R2a 몫 줄은 손대지 않는다.
- 남긴다(지휘자 판정): 은퇴한 kill switch 공시 표(CLAUDE.md :37 요건) · `integrity` 필드 문장(쓰는 곳 0 이지만 규칙 선택지) · SessionStart 훅 규칙(앞으로의 훅에 걸림) · qg README 의 `baseline-cache/` 안내(남은 폴더가 있는 사용자 안내).

크기 목표: 정리 대상 문서(CLAUDE.md · 철학 문서 · 플러그인 README 넷)마다 정리 전보다 작다. `docs/plugin-authoring.md`(§4 더하기) · CHANGELOG · 테스트 파일은 대상이 아니다. CLAUDE.md 는 원칙 여섯을 넣고도 지금(약 15.2KB) 이하 — 넘치면 먼저 원칙 줄을 철학 문서를 가리키는 짧은 꼴로 줄이고, §3 목록 밖의 줄과 §5 넘김 조항(R9 · R8 몫)은 줄이지 않는다.

### §4 개발 규칙 — `docs/plugin-authoring.md`

devbrew 를 만들 때만 쓰는 교훈 몇 줄. 어느 열린 에픽도 이 파일을 예약하지 않았다.
- 새 책임은 별도 모듈로, 기존 파일엔 진입 한 줄(사용자 「스크립트, 스킬 등 모듈화 하는게 devbrew전역에서 진행되어야 하는 부분이야」).
- 락을 쓰거나 고치면 변이(삭제 · 추가 · 반전 · 형태)로 RED 와 양성 대조를 확인하고, 부재 락에는 양성 짝을 둔다.
- 새 파일 · 문면을 쓰기 전에 그 경로를 코퍼스로 삼는 락을 찾는다.
- 새 셸 테스트는 실행 비트(100755).
- 플러그인 파일은 subagent 에 경로가 아니라 내용으로 싣는다(설치본 캐시는 작업 폴더 밖).

### §5 넘김 — 다른 에픽 몫

| 항목 | 받는 곳 | 이유 |
|---|---|---|
| Law 1 필수 섹션 게이트(구현 0) 문면 · 지출 승인 조항 · P22 · P12 trivia · CLAUDE.md 「새 플러그인 — plugin-structure 먼저」 · 「버그가 새면 persona 편집」 | R9 | R9 범위(규칙 · 문서 정리 · 흐름 고정 점검 R9 행) |
| CLAUDE.md 의존 최소 버전 줄 · spec-distill README 의 superpowers · qg · gh 부재 동작 | R8 | R8 범위(의존 선언 · 부재 시 강등) |
| 「사용자 리뷰 게이트」 용어(spec-distill README · skill · 템플릿 · 테스트) · worktree 격리 상속 · 스택 PR base 삭제 · SDD 과제 사이 이음매를 구현 틀에 | #227 (지휘자 수리 — 머지됨) | superpowers 7.0.0 이음매와 함께 skill · README 를 같은 PR 에서 맞춰야 어긋나지 않는다 |
| qg README 원칙 절 머리(「인스턴스화한 원칙」 vs 「Principles Instantiated」) · qg 판정 id 충돌 · kill switch 정규식(plugin-audit shape 검사) · docreview 엔진 결함 셋(finalize 두 번 · 복수 앵커 · § 앵커) · 설계문서 프로필의 대안 비교 축 | R2a | 그 파일 · 테스트가 R2a 예약 · 진행 중 |
| 철학 P3 의 「문서 리뷰 자리 넷(design doc·brief·seed·generic)을 통일하는 엔진은 `shared/docreview/`」가 지금 사실과 어긋남 — qg 의 `generic` 프로필은 엔진 테스트만 읽고(qg README 의 문서 리뷰 엔진 줄), 엔진 자리는 셋이다(spec-distill README 의 문서 리뷰 엔진 줄) | R2a | artifact-critique 를 엔진에 붙이면 그 문장이 참이 되고, 붙이지 않으면 R2a 가 그 문장을 고친다 |
| brief §4 의 «» 키 · brief 묶음 rc 3 오탐 · spec-interview 개명에 따른 README 줄 | R10 | R10 예약(spec-interview · 템플릿) |
| 하나짜리 brief 의 다음 세션 줄(`finishing.md`)에 원칙 2 · 3 · 4 · 6 이 없음(원칙 5 는 작은 일엔 만들지 않으니 필요 여부를 R10 이 판단) | R10 | R10 이 그 줄 문면을 맡음(`## 플러그인 동작 자리 대조`) |
| 에픽 넘김 줄(`epic-handoff.md`)에 원칙 5(계층 · 온톨로지)를 쓰라는 문장이 없음 | R5 (지휘자 수리 2 — R5 블록 브랜치로 등록) | R5 가 그 파일을 예약(`## 플러그인 동작 자리 대조`) |

### §6 메모리 정리 — 지휘 세션 몫, 레포 밖

메모리는 레포 파일이 아니라 계획 · 구현 agent 가 다루지 않는다. 지휘 세션이 Claude 의 원래 메모리 규칙(레포가 이미 기록한 것은 두지 않음 · 틀린 것 지움 · 중복 합침 · 목록 25KB 아래)으로 한다 — 사용자 「메모리 경우는 정리만 잘해둬 원래 클로드 원칙 잇자나」.
- 지금 할 수 있는 것: 이미 devbrew 에 있거나 끝난 일 · 틀린 내용인 메모리 지움 · 비슷한 교훈 묶음 합침 · 목록 손질.
- 이 PR 머지 뒤: §1 로 옮긴 원칙의 메모리를 지우거나 가리키는 한 줄로 줄인다(머지 전까지는 다리로 둔다 — K9).

## 있는 것 검토

- 쓴다: CLAUDE.md 의 기존 절(새 큰 절 없이) · 철학 문서의 기존 P# (흡수 먼저) · `docs/plugin-authoring.md` · `plugins/spec-distill/references/roadmap-ontology.md`(계층 · 온톨로지의 실례 — 원칙 5 가 가리킨다) · `references/epic-handoff.md` 와 설계 틀의 「있는 것 검토」 · 「상류 · 하류 연계」 절(원칙 4 · 6 의 실례) · `shared/style/plain-language.md`.
- 안 쓴다: 외부 패키지 · 도구 없음(문서 정리라 필요 없음).

## 상류 · 하류 연계

- 받는 곳: R5 설계 `## 미룸` 의 사용자 원칙 행 · 로드맵 재분해 이력의 R11 원문 · 흐름 고정 점검 문서(`docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/flexibility-audit.md` — 원칙 2 의 사용자 원문 출처) · auto-memory · 문서 조사 표.
- 넘기는 곳: 원칙이 실린 CLAUDE.md · 철학 문서 — R9 · R8 · R10 이 그 위에서 고친다(R9 의존에 R11). §5 넘김은 각 에픽의 설계 입력으로 간다.
- 되돌아오는 길: 이 설계를 다시 나눌 근거가 보이면 재분해 신호로 지휘 세션에 보고(`plugins/spec-distill/references/redecompose.md`).
- 같은 상태를 읽는 다른 표면: CLAUDE.md 를 읽는 락 · `plugin-audit` 의 shape 회귀 테스트(`plugins/plugin-audit/tests/test_check_shape_completeness.py` 의 `test_checklist_synced_with_claude_md` 가 CLAUDE.md §Plugin Shape 의 앵커를 읽는다 — 검사 스크립트는 고정 목록) · 철학 문서 인용 락(`test_charter_citations.sh`) · README 를 읽는 테스트(`test_readme_sync.sh` 등). 이음매 담당은 이 에픽.

## 위험

- K9(압축 뒤 지도 · 결정 내력 소실): 원칙을 추적 파일로 옮기는 것 자체가 답이다. 메모리는 머지 뒤에만 지워 그 사이 소실이 없다.
- 락이 문구를 핀한 곳을 지우면 RED — 지우기 전에 핀 락을 찾고, 락의 뜻을 바꾸는 수정(예: `test_readme_sync.sh` 의 「이력 문단 1~20줄」 단언)은 변이로 이빨을 다시 보인다.
- 다른 에픽과 같은 파일(qg · project-init · plugin-audit README 는 R2a 예약) — 고치는 줄을 R11 몫으로 한정하고 겹침은 통합 리뷰가 본다.
- D21(숨은 가정 · 실패 양식) 가운데 이 에픽에 닿는 것은 「한 곳」 소실(K9) 하나다.

## Acceptance Criteria

- AC1 CLAUDE.md 에 §1 원칙 여섯이 각각 한 줄로 있고, 각 줄이 철학 문서의 해당 원칙을 가리킨다. 새 큰 절이 없다.
- AC1a 원칙 2~6 마다 플러그인 동작 자리 대조표(실린 파일:줄 또는 §5 넘김 행)가 이 설계문서 `## 미룸` 앞 절에 있다.
- AC2 철학 문서가 원칙 여섯의 이유 · 배경을 담고, 새 P# 가 있으면 기존 P# 에 흡수하지 못한 이유가 같은 절에 한 문장으로 있다.
- AC3 §3 의 CLAUDE.md · 철학 문서 항목이 지워지거나 고쳐졌다(목록 항목마다 대조).
- AC4 §3 의 플러그인 README 넷 항목이 지워지거나 고쳐졌고, R2a 몫 줄은 그대로다.
- AC5 정리 대상 문서(CLAUDE.md · 철학 문서 · 플러그인 README 넷)마다 정리 전보다 작고, CLAUDE.md 는 정리 전 크기 이하다 — PR 본문에 파일별 전후 크기.
- AC6 `docs/plugin-authoring.md` 에 §4 다섯 줄이 있다.
- AC7 §5 넘김이 이 설계 `## 미룸` 표에 받는 곳과 함께 있다.
- AC8 헌장 · README 를 읽는 락이 GREEN 이고, 뜻을 바꾼 락은 변이로 RED 를 보인다.
- AC9 README 를 고친 플러그인마다 `plugin.json` patch bump 와 CHANGELOG 항목이 있다.
- AC10 새 결정론 검사(원칙 준수 lint 등)를 더하지 않았다.

## Files to Modify

- `CLAUDE.md` · `docs/philosophy/devbrew-harness-philosophy.md` · `docs/plugin-authoring.md`
- `plugins/spec-distill/README.md` · `.claude-plugin/plugin.json` · `CHANGELOG.md`
- `plugins/quality-gates/README.md` · `.claude-plugin/plugin.json` · `CHANGELOG.md`
- `plugins/project-init/README.md` · `.claude-plugin/plugin.json` · `CHANGELOG.md`
- `plugins/plugin-audit/README.md` · `.claude-plugin/plugin.json` · `CHANGELOG.md`
- `plugins/spec-distill/tests/test_readme_sync.sh`(이력 문단 단언 — 이력 면제를 없애 모든 줄을 살아 있는 줄로 본다. 이력 문단이 다시 생기는지 재는 새 검사는 더하지 않는다(AC10)) · 그 밖에 지운 문구를 핀한 락이 있으면 그 락
- 이 설계문서(`## 미룸` · 이후 `## 판정` · `## 구현 대조`)

## Verification Plan

- 고치기 전에 지울 줄마다 핀 락을 찾는다(조사 표의 「핀하는 락」 칸 + grep).
- 락: `plugins/plugin-audit/tests/test_check_shape_completeness.py` · `plugins/quality-gates/tests/test_law2_prose.sh` · `plugins/quality-gates/tests/test_governance_no_capability_caps.sh` · `plugins/spec-distill/tests/test_epic_conductor_skill.sh` · `shared/tests/test_charter_citations.sh` · `plugins/quality-gates/tests/test_e2e_docs.sh` · `plugins/spec-distill/tests/test_rereview_cap_consistency.sh` · `shared/tests/test_invocation_surface.sh` · `plugins/quality-gates/tests/test_publish_surface_removed.sh` · `plugins/spec-distill/tests/test_readme_sync.sh` · `shared/tests/test_changelog_integrity.sh` · README 를 읽는 qg 테스트.
- 전체 스위트(로드맵 frontmatter `test_command`)를 기준선과 실패 이름으로 대조.
- 크기: 고친 파일마다 `wc -c` 전후.
- 끝에서 끝(사용자 성공 장면 「내가 말한게 다른 레포에서 사용해도 지켜지면」): (가) devbrew 개발 — 메모리를 쓰지 않는 devbrew 새 clone 세션에서 그 clone 의 CLAUDE.md · 철학 문서만으로 원칙 여섯을 찾아 따라갈 수 있는지 읽어 본다. (나) 플러그인 사용 — AC1a 대조표의 자리마다 원칙이 실렸는지(또는 넘김이 받는 에픽에 있는지) 본다.

## Rejected Alternatives

- 원칙 본문을 전부 CLAUDE.md 에 — 매 세션 읽히지만 「크기를 줄이자」와 부딪힌다. 사용자 「ok」 로 한 줄 + 철학 이유를 골랐다.
- 철학 문서에만 — 가리켜야만 읽혀서 개발 세션이 놓친다.
- 메모리 전부 옮기기 — 사용자 「모든걸 다 지키란말은 또 아니야」.
- 원칙 준수 lint — 가벼움 원칙(결정론은 보안 · 정확성에만).
- 원칙 7 · 8 을 CLAUDE.md 에 — 사용자 「여덟째는 넣지마 그리고 일곱째도 넣는건 좀 그러네」(B7).
- R11 이 다른 에픽 파일까지 직접 고치기 — 사용자 「이 기준으로 (권장)」(넘김 + 지휘자 확인).

## 결정 기록

- B1 · 결정 · 2026-10-18 · 옮길 범위 — 「2, 잘 조율하도록 해」(원칙 + 동작 교훈)
- B2 · 결정 · 2026-10-18 · 고르는 기준 · 조율 — 「이 기준으로 (권장)」 · 사용자 「모든걸 다 지키란말은 또 아니야 알지?」
- B3 · 결정 · 2026-10-18 · 자료 읽기 — 「읽고 표로 (권장)」
- B4 · 결정 · 2026-10-19 · 원칙 자리 — 「ok」(규칙은 CLAUDE.md 한 줄, 이유는 철학 문서)
- B5 · 결정 · 2026-10-19 · 원칙 8 문면 — 「몫만 이란거 보단 자기 몫을 이라고 하자」 · 「superpowers를 지휘자가 다루자나 그부분이 앞에 말한 덮지 말라는 원칙과 충돌한다고 뒤에서 판단할수도 있는데 그건 아니란 말이었어」
- B6 · 결정 · 2026-10-19 · 계획 길이 보완 장치 없음 — 「짧아진 계획의 영향을 신경쓰진 일단 말아봐 그걸 근거로 과한 구현 안했음 좋겠으니」
- B7 · 결정 · 2026-10-19 · 원칙 7(kill switch 개명 별칭) · 8(superpowers 를 덮지 않고 자기 몫을) 을 CLAUDE.md 에 넣지 않음 — 「여덟째는 넣지마 그리고 일곱째도 넣는건 좀 그러네」(B5 는 이로써 문면 없음)
- 메모리 — 「메모리 경우는 정리만 잘해둬 원래 클로드 원칙 잇자나」
- D1.1 · r1 · adopt · c43e2738#r1.1 · "고친다 — 이력 아닌 글만 정리 (권장)" — 에픽 묶음은 플러그인 README 와 CHANGELOG 의 낡은 개념 정리를 이 에픽의 일로 넘겼는데, 설계는 CHANGELOG 정리를 사용자 결정 기록 없이 범위 밖으로 뺐다.
- docreview 계수 — spec-distill/2026-10-19-principles-docs-cleanup-desig-24d551eddb1c50c0 r1: advice_new=1 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — spec-distill/2026-10-19-principles-docs-cleanup-desig-24d551eddb1c50c0 r2: advice_new=5 · advice_repeat=1 · mc_preexisting_new=0

## 번호 대조

| 번호 | 반영/기각 | 자리 또는 이유 |
|---|---|---|
| C25 | 반영 | Constraints(외부 플러그인 파일 · 동작을 고치지 않는다) — 원칙 줄로는 넣지 않음(B7) |
| C30 | 반영 | §1 원칙 1 · 3(devbrew 밖 레포) · Verification Plan 끝에서 끝 |
| C32 | 반영 | §1 원칙 6 · 있는 것 검토 |
| C35 | 반영 | Constraints(외부 플러그인 파일 · 동작을 고치지 않는다) — 원칙 줄로는 넣지 않음(B7) |
| C44 | 반영 | Non-goals — 교훈을 따로 다루는 장치 없이 그 동작 자리를 고친다(§1 원칙 1) |
| D21 | 반영 | 위험 |
| D26 | 반영 | Constraints(외부 플러그인 파일 · 동작을 고치지 않는다) — 원칙 줄로는 넣지 않음(B7) |
| D33 | 반영 | §1 원칙 6 · 있는 것 검토 |
| K9 | 반영 | 위험 · §6 |
| S1 | 반영 | Context / Why |
| S13 | 반영 | 위험 |
| S17 | 반영 | Constraints(외부 플러그인 파일 · 동작을 고치지 않는다) — 원칙 줄로는 넣지 않음(B7) |
| S18 | 반영 | Constraints(외부 플러그인 파일 · 동작을 고치지 않는다) — 원칙 줄로는 넣지 않음(B7) |
| S27 | 반영 | §1 원칙 1 · 3 |
| S30 | 반영 | §1 원칙 6 |
| S31 | 반영 | §1 원칙 6(실험 기능은 기반으로 쓰지 않음 — 이 설계는 새 장치 없음) |
| S34 | 반영 | Constraints(외부 플러그인 파일 · 동작을 고치지 않는다) — 원칙 줄로는 넣지 않음(B7) |
| S44 | 반영 | Non-goals · §1 원칙 1 |
| S49 | 반영 | §5 — 줄이지 않고 넘긴다 |

## 플러그인 동작 자리 대조

원칙 1 은 devbrew 개발 규칙이라 대상이 아니다. 줄 번호는 2026-10-19 에 grep 으로 잰 것이다.

| 원칙 | 실린 자리(파일:줄) | 빈 곳 | 받는 곳 |
|---|---|---|---|
| 2 흐름 고정 금지 | `plugins/spec-distill/references/conducting.md:5` · `:78` · `plugins/spec-distill/references/epic-handoff.md:7` | `plugins/spec-distill/skills/spec-interview/references/finishing.md:478`(하나짜리 brief 다음 세션 줄) | R10 |
| 3 레포 전용 값 | `plugins/spec-distill/references/conducting.md:86` · `plugins/spec-distill/references/epic-handoff.md:7` | `finishing.md:478` | R10 |
| 4 상류 · 하류 연계 | `plugins/spec-distill/references/conducting.md:86` · `plugins/spec-distill/references/epic-handoff.md:7` | `finishing.md:478` | R10 |
| 5 계층 · 온톨로지 | `plugins/spec-distill/references/roadmap-ontology.md:3` · `plugins/spec-distill/references/conducting.md:9` · `:82` | `plugins/spec-distill/references/epic-handoff.md:7`(쓰라는 문장 없음) · `finishing.md:478` | `epic-handoff.md` 는 R5 후속(R5 설계 `## 미룸`) · `finishing.md` 는 작은 일엔 만들지 않으니 필요 여부를 R10 이 판단 |
| 6 있는 것 먼저 | `plugins/spec-distill/references/conducting.md:86` · `plugins/spec-distill/references/epic-handoff.md:7` | `finishing.md:478` | R10 |

## 미룸

| 항목 | 이유 | 받는 곳 |
|---|---|---|
| §5 의 R9 행 | R9 범위 | R9 |
| §5 의 R8 행 | R8 범위 | R8 |
| §5 의 R5 후속 행 | superpowers 7.0.0 이음매와 같은 PR — 지휘자 수리가 처리 | #227 |
| §5 의 R2a 행 | R2a 예약 · 진행 중 | R2a |
| §5 의 철학 P3 「문서 리뷰 자리 넷」 행 | artifact-critique 를 엔진에 붙일지에 따라 문장이 참이 되거나 고쳐야 함 | R2a |
| §5 의 R10 행 | R10 예약 | R10 |
| §5 의 `finishing.md` 행(원칙 2 · 3 · 4 · 6, 원칙 5 는 R10 이 필요 여부 판단) | R10 이 그 줄 문면을 맡음 | R10 |
| §5 의 `epic-handoff.md` 행(원칙 5) | R5 예약 파일 — 지휘자 수리 2 가 맡는다 | R5 |

## 지휘 기록

- 2026-10-19 · 지휘자 판정: `## 미룸` 의 받는 곳 셋을 상태 계산이 따라갈 수 있게 고쳤다 — §5 지휘자 수리 행은 #227(머지됨)로, 원칙 5 넘김 행은 R5(지휘자 수리 2 브랜치를 R5 블록에 등록해 R5 가 열린 채 추적), §6 머지 뒤 메모리 정리는 레포 밖 지휘 세션 일이라 미룸 표에서 빼고 이 기록으로 둔다(R11 머지 뒤 지휘 세션이 메모리 원칙 다리 정리).

- 설계문서 점검(builder check) 질문 셋은 대화 · 레포에서 답이 나오거나 계획이 정해도 되는 것이라 지휘 세션이 정했다(지휘자 판정): ① 「다른 레포」는 두 갈래 모두 — §1 두 갈래 문단 · AC1a ② 크기 규칙은 정리 대상 문서에만, 넘치면 원칙 줄을 짧은 꼴로 ③ `test_readme_sync.sh` 는 이력 면제만 없앤다(새 검사 없음). 사실 고침: 철학 문서에 Structural Mechanisms 절은 있다 — case study 만 없다.

- 2026-10-19 · 승인 게이트에서 ① 을 고른 뒤 사용자가 「지금 보냄 (권장)」(「여기서 계속」 갈래) — 압축을 기다리지 않고 같은 턴에 계획 agent 를 보냈다. 사용자 제안 「plan부터는 담당자가 하는건 맞는가지?그렇다면 이제 스펙 리뷰 후에 게이트가 나오지 않아도 될거같아」 는 지휘자 수리에서 다룬다.
- 흐름: 설계 흐름(brainstorming → spec-review → 계획 → 구현). brainstorming 은 superpowers 7.0.0 — 설계문서 점검(builder check) 뒤 문서 승인 자리에서 spec-review 를 부른다.
- spec 승인 · 2026-10-19 · 「① /compact 후 계획으로 (권장)」

## Metadata

- 에픽: R11 · 브랜치 `feature/principles-docs-cleanup`
- 묶음: `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R11.md`
- 조사 기록(레포 밖): `~/.claude/sdd-mirror/epic-decisions/r11/docs-recon.md` · `memory-recon.md`

### Deferred to plan

| # | 항목 |
|---|---|
| fccf272b#r1.1 | 참고(ambiguity) #acceptance-criteria — 크기 기준이 CLAUDE.md 를 두고 '정리 전보다 작다'와 '정리 전 크기 이하'로 둘로 갈려, 같은 크기면 통과인지 실패인지 정할 수 없다. |
| daa1d4a8#r2.1 | 참고(data_flow) #5-넘김--다른-에픽-몫 — 넘김 행 하나와 앞으로 생길 대조표 빈칸이 받는 곳을 「지휘자 수리 PR(R5 후속)」으로 적었는데, 이 받는 곳은 로드맵에도 R5 설계문서에도 없고 이 설계문서에만 있습니다. 그래서 받았는지 확인할 기록이 없습니다. — 고치면: 받는 곳을 리포에 기록이 있는 자리로 바꿉니다. (가) 지휘자 수리를 재분해 절차(redecompose.md)로 로드맵 에픽에 등록해 묶음과 설계문서를 갖게 하거나, (나) 넘길 항목을 이미 열린 에픽(R8 · R10 등) 가운데 그 파일을 맡을 곳으로 보냅니다. 어느 쪽이든 §5 · `## 미룸` · §1 두 갈래 문단의 받는 곳 표기를 같이 맞춥니다. |
| 88c5c9a0#r2.1 | 참고(feasibility) #상류--하류-연계 — 헌장 문구를 읽는 파일이 잘못 적혀 있습니다. 실제로는 회귀 테스트가 헌장을 읽고, 검사 스크립트는 코드에 고정된 목록을 사용합니다. — 고치면: `plugin-audit`의 검사 목록은 `check-shape-completeness.py`에 고정되어 있고, `tests/test_check_shape_completeness.py`의 `test_checklist_synced_with_claude_md`가 CLAUDE.md의 대응 문구를 읽어 확인한다. |
| a52f1c68#r2.1 | 참고(ambiguity) #3-지울-낡은-개념 — 크기 목표는 정리 대상 문서마다 정리 전보다 작아야 한다고 합니다(AC5). 그런데 철학 문서는 원칙 여섯의 이유 · 배경을 새로 받아야 하고(AC2), 넘칠 때 무엇부터 줄일지는 CLAUDE.md 에만 적혀 있고 철학 문서에는 없습니다. — 고치면: §3 크기 목표에 철학 문서가 넘칠 때의 순서를 한 줄 더합니다. 예: 원칙마다 이유를 기존 P# 안 한 문장으로 줄이고, 그래도 넘치면 그 사실과 전후 크기를 PR 본문에 적어 사용자에게 보입니다. |
| 0b618227#r2.1 | 참고(testing) #acceptance-criteria — 이번에 사용자가 고른 CHANGELOG 정리(이력이 아닌 낡은 글만 정리, 없으면 「없음」)를 확인할 수용 기준이 없고, Goals 에도 빠져 있습니다. — 고치면: Goals 둘째 줄에 CHANGELOG 의 이력이 아닌 글을 더하고, AC 하나를 둡니다: 「플러그인 CHANGELOG 넷마다 이력이 아닌 낡은 글을 정리했거나, PR 본문에 그 CHANGELOG 는 「없음」이라고 적혀 있다」. |
| 70cfa8df#r2.1 | 참고(handoff_incomplete) #verification-plan — 지울 줄을 고정하는 테스트(핀 락)를 찾을 때 리포 밖 조사 기록(~/.claude/sdd-mirror/...)의 표를 쓰라고 합니다. 그런데 계획 · 구현 agent 는 작업 폴더 밖 파일을 못 읽을 수 있고, §3 목록이 그 표 대신 범위 전체인지도 적혀 있지 않습니다. — 고치면: §3 머리에 「아래 목록이 이 에픽 범위의 전부다 — 조사 표는 참고용이고, 핀 락은 grep 으로 찾는다」를 적고, Verification Plan 의 괄호를 grep 기준으로 고칩니다. |

## 판정

### docs/superpowers/plans/2026-10-19-principles-docs-cleanup.md

- Ruling: 전체 스위트 실행(T1 Step 1 · T8 Step 2)은 지휘(나)가 공유 잠금 ~/.claude/sdd-mirror/suite-lock.d 아래에서 직접 돌리고 결과 파일을 계획이 정한 자리에 둔다 — 지휘 지시(잠금 · owner R11 · codex 픽스처 복원 · codex 호출 셈)를 하위 agent 에 옮기면 잠금 처리 실수 위험 — 틀리면: 구현자가 기준선 생성 단계를 직접 보지 못함(파일은 같은 자리에 있어 영향 작음).
- Ruling: 옛 표기 「지휘자 수리 PR(R5 후속)」 1건이 `### Deferred to plan` 의 리뷰 참고 daa1d4a8#r2.1 인용에 남아 계획 Step 5 기대(0)와 다르다 — 그 줄은 지난 리뷰 원장의 인용 기록이라 고치지 않는다(기록 위조 방지 · 지휘 세션 소유 절) — 틀리면: grep 0 기대를 맞추려 인용 한 단어를 고치는 후속 편집.
- Ruling: Task 1 커밋의 Co-Authored-By 가 실행 모델 이름(Sonnet 5.5)으로 적혔다 — HEAD 를 뒤로 옮기는 수정(amend) 금지라 그대로 두고, 이후 커밋은 지시된 트레일러를 쓰게 한다 — 틀리면: 커밋 트레일러 한 줄이 지시와 다름(내용 영향 없음).
- Task 1: review — spec ✅ 대부분, Important 1(원칙 5 finishing 빈 곳에 §5 · 미룸 행 없음), Minor 4. Ruling: Minor 1(`roadmap-ontology.md:1` 은 제목 줄 — 인용 줄 사실 오류)과 Minor 3(미룸 행 이름)은 Task 8 끝에서 끝 (나) 가 그 줄을 열어 보므로 이번 고침에 함께 넣는다 — 값싼 사실 고침 — 틀리면: 루프에 Minor 를 넣은 작은 범위 확장.
- Ruling: 원칙 2 · 4 의 뜻을 되살리고, 넘치는 바이트는 §3 목록 안의 줄(Polite handoff · Forbidden 머리 등)을 뜻을 지키며 더 줄여 마련한다 — 설계 §1 이 원칙 줄의 뜻을 정하고 계획 GC 는 §3 밖 · §5 조항만 줄이지 말라 함(§3 줄의 계획 문면은 논거이지 구속 아님) — 틀리면: 계획이 준 Polite handoff 문면과 몇 낱말 다름.
- Ruling: 되살릴 바이트는 이 과제가 새로 쓴 글에서 마련한다(P8 이식성 괄호의 값 목록 — CLAUDE.md:35 가 같은 목록을 「무엇」으로 가짐; 모자라면 Law 3 「· 새 clone」) — 철학 문서는 이유 자리이고 GC 가 §3 밖 원문 삭제를 막음 — 틀리면: 철학 P8 에서 레포 전용 값의 예 목록이 빠져 CLAUDE.md 줄로만 남음.
- Ruling: Task 6 계획 문면 「artifact-critique 의 non-code 리뷰 자리를 `generic` 프로필로 선언하고 공용 엔진 `shared/docreview/` 를 쓴다」는 Task 5 리뷰어 실측(artifact-critique SKILL 이 엔진을 배선하지 않음, generic.md 데이터만)과 어긋날 수 있다 — 구현자가 실제 배선을 재고 지금 참인 사실만 쓰게 한다(설계 §3 「지금 사실로」가 구속, 계획 문면은 논거) — 틀리면: qg README 줄이 계획 문면과 다름.
- Ruling: Task 8 을 셋으로 나눈다 — Step 1 · 3 · 4(나)는 구현자, Step 2 전체 스위트는 지휘가 잠금 아래(Ruling 1), Step 4(가) 메모리 없는 읽기는 지휘가 두 파일 내용만 인라인으로 실은 별도 agent 로(구현자는 하위 agent 를 못 보냄 · 계획이 「subagent 에게 맡길 때는 내용을 인라인」이라 함) — 틀리면: e2e 기록 파일이 두 손에서 나와 합쳐 적어야 함.
- Ruling: Step 4(가) 냉독자에게 두 파일 내용을 인라인하지 않고 두 경로만 주며 「그 두 파일만 · 메모리 쓰지 말 것」을 지시했다 — 하위 agent 시스템 맥락의 auto-memory 주입은 인라인이든 경로든 막을 수 없어 차이가 작고, 지휘 맥락 30KB 를 아낀다 — 틀리면: 냉독자가 다른 파일을 열어 「두 파일만으로」 측정이 흐려짐(보고서에서 확인).
- Ruling: Important 1(받는 곳 기계 추적)은 고치지 않고 지휘에 올린다 — 고치는 길(GitHub 이슈 `#<n>` 열기 · redecompose 로 로드맵 에픽 등록)이 worktree 밖 부작용이자 지휘 결정이고, 지휘가 이미 「R5 후속(지휘자 수리 2)」로 받는 곳을 확정함 — 틀리면: 머지 뒤 roadmap-status · `check_bundle_coverage.py --impl` 이 그 행들을 「받는 곳 없음」으로 계속 경고.
- Ruling: 최종 고침 한 번에 넣는 것 — (1) CLAUDE.md 원칙 다섯 줄 블록을 `## Plugin Shape` 머리 아래에서 Law 3 문단 바로 뒤(`## The Three Laws` 안)로 옮김(0바이트; 「모든 플러그인은 … 아래를 모두 만족」 이 「기본은 X」를 감싸 고정 규칙으로 읽히는 냉독 지적 · 원칙 2 자기모순 해소; 기존 절 안이라 설계 §1 「새 큰 절 없이」 충족) (2) 철학 P5 「주인 하나라야」→「주인이 하나라야」 (3) 철학 P8 (재사용)에 원칙 6 의 이유 한 구절(AC2 · 냉독 「이유 없음」), 바이트는 이번 브랜치가 새로 쓴 글에서 (4) 철학 P3 「문서 리뷰 자리 넷」 어긋남을 설계 §5 · `## 미룸` 에 R2a 행으로 올림. 나머지 Minor 는 미룸 — 바이트 예산 · 범위 밖 · 정본 파일이 있음 — 틀리면: 남긴 Minor 가 후속 에픽까지 그대로 남음.
- Ruling: merge 충돌 풀기는 구현 agent 에 맡기고(지휘가 직접 고치지 않음), 판 번호는 기본 브랜치 다음 — spec-distill 7.4.1 · qg 14.0.2 · plugin-audit 1.1.5 · project-init 5.0.5 — 지휘 인계 그대로 · plugin.json 은 같은 글자면 조용히 합쳐지니 넷 모두 직접 고침 — 틀리면: 머지 직전 지휘가 번호를 다시 정해야 함.
- Ruling: SDD 작업 폴더(.superpowers/sdd/2026-10-19-principles-docs-cleanup)를 지우지 않고 남긴다 — 지휘가 구현 대조 · PR 본문에 보고서 · 원장을 쓰고, 거울(~/.claude/sdd-mirror/r11/)도 함께 둔다 — 틀리면: git-ignored 폴더 하나가 worktree 에 남음(지휘가 PR 뒤 지움).
- Ruling: 기본 브랜치에 그 PR 이 먼저 들어가 R11 이 기본 브랜치를 merge 할 때 spec-distill README `## External source absorption` 절에서 충돌하면 절 삭제를 택하고, 그 PR 의 CHANGELOG 7.4.0 줄(그 절 superpowers 줄 수정)은 R11 CHANGELOG 항목에 「그 절은 이번에 지웠다」로 맞춘다 — 지휘 지시 · R11 설계 §3 이 그 절 통째 삭제를 정함 — 틀리면: 그 PR 의 superpowers 줄 수정이 README 에서 사라짐(정본은 CHANGELOG · skill).
- Ruling: 버전 번호는 머지 직전에 그 PR(spec-distill 7.4.0 · qg 14.0.1 · plugin-audit 1.1.4 · project-init 5.0.4) 다음으로 다시 정하고, plugin.json 은 같은 글자면 충돌 없이 합쳐지므로 merge 뒤 직접 확인한다 — 지휘 지시 · 계획 GC 「번호는 잠정 · 머지 직전 확정」 — 틀리면: 두 PR 이 같은 버전을 써 cache key 가 갱신 안 됨. 지금 브랜치 번호(7.3.1 · 14.0.1 · 5.0.4 · 1.1.4)는 잠정이며 그 PR 과 셋이 겹친다.
- Ruling: R11 대조표에서 「epic-handoff.md 원칙 5 문장」의 받는 곳은 R5 후속(지휘자 수리 2)으로 확정 — 지휘 확정 · 설계문서의 표기 「R5 후속(R5 설계 `## 미룸`)」 과 같은 갈래라 설계문서는 고치지 않는다 — 틀리면: 받는 쪽 이름이 「지휘자 수리 2」로 더 구체화되어야 했음(지휘 세션이 `## 판정` 에 옮길 수 있음).
- Ruling: (Task 1 리뷰) Minor 1(`roadmap-ontology.md:1` 은 제목 줄 — 인용 줄 사실 오류)과 Minor 3(미룸 행 이름)은 Task 8 끝에서 끝 (나) 가 그 줄을 열어 보므로 이번 고침에 함께 넣는다 — 값싼 사실 고침 — 틀리면: 루프에 Minor 를 넣은 작은 범위 확장.
- Ruling: Task 6 계획 문면 「artifact-critique 의 non-code 리뷰 자리를 `generic` 프로필로 선언하고 공용 엔진 `shared/docreview/` 를 쓴다」는 Task 5 리뷰어 실측과 어긋날 수 있다 — 구현자가 실제 배선을 재고 지금 참인 사실만 쓰게 한다(설계 §3 「지금 사실로」가 구속) — 틀리면: qg README 줄이 계획 문면과 다름. (실측: qg 안에서 generic.md 를 읽는 실행 경로가 0이라 그 사실만 적었다.)
- Ruling: Task 8 을 셋으로 나눈다 — Step 1 · 3 · 4(나)는 구현자, Step 2 전체 스위트는 지휘가 잠금 아래, Step 4(가) 메모리 없는 읽기는 지휘가 별도 agent 로 — 틀리면: e2e 기록 파일이 두 손에서 나와 합쳐 적어야 함.
- Ruling: Step 4(가) 냉독자에게 두 파일 경로만 주며 「그 두 파일만 · 메모리 쓰지 말 것」을 지시했다 — auto-memory 주입은 인라인이든 경로든 막을 수 없어 차이가 작음 — 틀리면: 냉독자가 다른 파일을 열어 측정이 흐려짐. (냉독자는 두 파일만 읽었다고 보고.)
- Ruling: 기본 브랜치 merge 때 spec-distill README `## External source absorption` 충돌은 절 삭제를 택하고 #227 의 CHANGELOG 7.4.0 줄은 R11 CHANGELOG 항목에 「그 절은 이번에 지웠다」로 맞춘다 — 지휘 지시 · 설계 §3 — 틀리면: #227 의 superpowers 줄 수정이 README 에서 사라짐(정본은 CHANGELOG · skill).
- Ruling: 버전 번호는 머지 직전에 #227 다음으로 다시 정하고 plugin.json 은 merge 뒤 직접 확인한다 — 틀리면: 두 PR 이 같은 버전을 써 cache key 가 갱신 안 됨.
- Ruling: R11 대조표에서 「epic-handoff.md 원칙 5 문장」의 받는 곳은 R5 후속(지휘자 수리 2)으로 확정 — 지휘 확정 — 틀리면: 받는 쪽 이름이 더 구체화되어야 했음.
- Ruling: Important 1(받는 곳 기계 추적)은 고치지 않고 지휘에 올린다 — 이슈 · 재분해는 worktree 밖 부작용이자 지휘 결정 — 틀리면: 머지 뒤 경고 지속. (지휘 처리: 받는 곳을 #227 · R5 로 고치고 메모리 정리 행은 지휘 기록으로 옮김 — 구현 대조 경고 없음.)
- Ruling: 최종 고침 한 번에 — (1) CLAUDE.md 원칙 다섯 줄 블록을 `## The Three Laws` 의 Law 3 문단 바로 뒤로 옮김(0바이트; 냉독 지적 · 원칙 2 자기모순 해소) (2) 철학 P5 맞춤법 (3) 철학 P8 (재사용)에 원칙 6 이유 한 구절 (4) 철학 P3 「문서 리뷰 자리 넷」 어긋남을 R2a 행으로. 나머지 Minor 는 미룸 — 틀리면: 남긴 Minor 가 후속까지 남음.
- Ruling: merge 충돌 풀기는 구현 agent 에 맡기고 판 번호는 기본 브랜치 다음 — spec-distill 7.4.1 · qg 14.0.2 · plugin-audit 1.1.5 · project-init 5.0.5 — 틀리면: 머지 직전 다시 정함.
- Ruling: SDD 작업 폴더를 지우지 않고 남긴다 — 지휘가 구현 대조 · PR 본문에 쓴다, 거울도 있다 — 틀리면: git-ignored 폴더 하나가 남음.

## 구현 대조 — docs/superpowers/plans/2026-10-19-principles-docs-cleanup.md

- 구현 대조: 구현 대조: 경고 없음 (AC 10개 · 구현됨 10개 · 미룸 0개) (받는 곳 규칙: 로드맵의 에픽 또는 PR 번호(#숫자) — 작업 트리의 로드맵으로 쟀다)
- 보고: AC 10개 중 구현됨 10 · 미룸 0 · 빠짐 0 (AC1a 구현됨 · D1.1 「없음」)
