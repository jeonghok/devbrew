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
- 플러그인 동작 변경. 교훈 가운데 플러그인 동작에 닿는 것은 지휘자 수리 PR(R5 후속) · R2a · R10 이 고친다.
- CHANGELOG 항목 정리 — 이력이라 그대로 둔다.
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

### §2 고르는 기준 (사용자 승인 「이 기준으로 (권장)」)

- 옮긴다: 사용자가 「앞으로도 · 원칙」이라 한 것, 또는 같은 실수가 다른 레포에서도 다시 날 교훈 — 둘 다 devbrew 가 어떻게 동작하는지에 닿을 때만.
- 옮기지 않는다: 그때 상황에만 맞던 지시 · 이 레포의 지난 일 기록 · Claude 가 원래 하는 일과 같은 것.
- 옮길 때는 그 동작을 내는 지시문 안에 한두 문장. 기계 검사는 보안 · 정확성에 꼭 필요할 때만.
- 다른 에픽이 잡은 파일 · 조항은 넘김으로 보내고 지휘자가 확인한다.

### §3 지울 낡은 개념

조사 기록(지휘 세션 `~/.claude/sdd-mirror/epic-decisions/r11/docs-recon.md` 의 표)에서 R11 몫만. 처분 종류는 넷이다 — 지금 장치가 없는 개념 · 이미 바뀐 사실 · 중복 · 이력 서사.

- **CLAUDE.md**: 훅 공존 줄의 signal tag 구절(`<{plugin}-signal>` 를 쓰는 곳 0) · Forbidden Patterns 머리의 「Full 카탈로그와 case study: … Structural Mechanisms 섹션」(철학 문서에 그 절 · case study 없음 — 「Anti-Pattern Anchors」로) · Polite handoff 줄을 `plugins/spec-distill/references/proceed-gate.md` 포인터와 금지 둘로 줄임(「spec-distill v0.11.0 AC19」 이력 · 옛 표현 지움) · 출처 · 실측 이력 괄호(`allowed-tools` 줄의 「2026-08-22 헤드리스 실측 5변형…」 · agent 줄의 「(`Monitor`가 … 그 실증)」 · Subagent spray 줄의 「(Opus 5 기본 시스템 프롬프트… 2026-08-22)」 · Korean-primary 줄의 「`*.ko.md` 동반 파일 모델은 폐기(…)」). Law 3 의 「인덱스를 자동 편집」 구절은 그 장치가 없으므로 §1 원칙 1 문장으로 바꿔 쓴다.
- **철학 문서**: Three Laws 절(CLAUDE.md 와 같은 글 — 포인터 한 줄로) · AP18 · AP19 스텁(인용 0, CLAUDE.md 와 같은 글) · P8 예시의 redirect(v2.7.0 에서 지워짐 — 현재 floor 예시로) · P11 의 「다중 모델은 opt-in 게이트」(지금 codex 는 감지되면 늘 돌고 끄는 길은 kill switch) · P11 · P8 의 사례 이력 문장 · P13 의 signal tag · P14 끝의 「README 3곳 인용의 anchor target」 문장 · AP 앵커 도입과 P5 의 「Filesystem-as-Memory」 절 언급(CLAUDE.md 에 없음 — §런타임 상태 & 훅으로).
- **spec-distill README**: `**vX.Y.Z**` 이력 문단 11개(CHANGELOG 에 있음) · 「문서 리뷰 엔진 기반(v0.56.0) — 아직 쓰는 쪽 없이…」 · 「엔진 결함 일곱(v0.58.0)…」 · 버전 꼬리표 괄호 · 중복(P14 네 번 · AP2 두 번 · Law 3 / P5) · 죽은 개념 `needs_interview` · 틀린 라벨(P11 에 steelman, P3 에 graceful degradation) · External source absorption 절의 출처 이력(사용자 판단 대신 지휘자 판정 — 출처는 CHANGELOG · PR 몫) · Hooks Installed 의 5.x 이력.
- **quality-gates · project-init · plugin-audit README**: R2a 가 바꾸는 동작 밖의 줄만(R2a 설계가 넘긴 몫) — qg 의 「dispatch builder」 · 없는 `codex-reviewer` agent 설명 · 「문서 리뷰 엔진 기반(v7.4.0)」 · 실측 이력 괄호 · v10.0.0 훅 삭제 이력 · `MAX_TOTAL_ITERATIONS` 이력, project-init 의 버전 꼬리표 · 「CLAUDE.md 는 짧은 anchor 만」(지금 생성물과 다름), plugin-audit 의 「즉시 제거 — 근거는 …」 정당화 서사 · 샌드박스 별칭 이력 · severity 통일 이력. 구성표 · 상한 수치 · 의도 출처 · artifact-critique · persona 모델 고정 같은 R2a 몫 줄은 손대지 않는다.
- 남긴다(지휘자 판정): 은퇴한 kill switch 공시 표(CLAUDE.md :37 요건) · `integrity` 필드 문장(쓰는 곳 0 이지만 규칙 선택지) · SessionStart 훅 규칙(앞으로의 훅에 걸림) · qg README 의 `baseline-cache/` 안내(남은 폴더가 있는 사용자 안내).

크기 목표: 고친 문서마다 정리 전보다 작다. CLAUDE.md 는 원칙 여섯을 넣고도 지금(약 15.2KB) 이하.

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
| 「사용자 리뷰 게이트」 용어(spec-distill README · skill · 템플릿 · 테스트) · worktree 격리 상속 · 스택 PR base 삭제 · SDD 과제 사이 이음매를 구현 틀에 | 지휘자 수리 PR(R5 후속) | superpowers 7.0.0 이음매와 함께 skill · README 를 같은 PR 에서 맞춰야 어긋나지 않는다 |
| qg README 원칙 절 머리(「인스턴스화한 원칙」 vs 「Principles Instantiated」) · qg 판정 id 충돌 · kill switch 정규식(plugin-audit shape 검사) · docreview 엔진 결함 셋(finalize 두 번 · 복수 앵커 · § 앵커) · 설계문서 프로필의 대안 비교 축 | R2a | 그 파일 · 테스트가 R2a 예약 · 진행 중 |
| brief §4 의 «» 키 · brief 묶음 rc 3 오탐 · spec-interview 개명에 따른 README 줄 | R10 | R10 예약(spec-interview · 템플릿) |

### §6 메모리 정리 — 지휘 세션 몫, 레포 밖

메모리는 레포 파일이 아니라 계획 · 구현 agent 가 다루지 않는다. 지휘 세션이 Claude 의 원래 메모리 규칙(레포가 이미 기록한 것은 두지 않음 · 틀린 것 지움 · 중복 합침 · 목록 25KB 아래)으로 한다 — 사용자 「메모리 경우는 정리만 잘해둬 원래 클로드 원칙 잇자나」.
- 지금 할 수 있는 것: 이미 devbrew 에 있거나 끝난 일 · 틀린 내용인 메모리 지움 · 비슷한 교훈 묶음 합침 · 목록 손질.
- 이 PR 머지 뒤: §1 로 옮긴 원칙의 메모리를 지우거나 가리키는 한 줄로 줄인다(머지 전까지는 다리로 둔다 — K9).

## 있는 것 검토

- 쓴다: CLAUDE.md 의 기존 절(새 큰 절 없이) · 철학 문서의 기존 P# (흡수 먼저) · `docs/plugin-authoring.md` · `plugins/spec-distill/references/roadmap-ontology.md`(계층 · 온톨로지의 실례 — 원칙 5 가 가리킨다) · `references/epic-handoff.md` 와 설계 틀의 「있는 것 검토」 · 「상류 · 하류 연계」 절(원칙 4 · 6 의 실례) · `shared/style/plain-language.md`.
- 안 쓴다: 외부 패키지 · 도구 없음(문서 정리라 필요 없음).

## 상류 · 하류 연계

- 받는 곳: R5 설계 `## 미룸` 의 사용자 원칙 행 · 로드맵 재분해 이력의 R11 원문 · auto-memory · 문서 조사 표.
- 넘기는 곳: 원칙이 실린 CLAUDE.md · 철학 문서 — R9 · R8 · R10 이 그 위에서 고친다(R9 의존에 R11). §5 넘김은 각 에픽의 설계 입력으로 간다.
- 되돌아오는 길: 이 설계를 다시 나눌 근거가 보이면 재분해 신호로 지휘 세션에 보고(`plugins/spec-distill/references/redecompose.md`).
- 같은 상태를 읽는 다른 표면: CLAUDE.md 를 읽는 락 · `plugin-audit` 의 shape 검사(`check-shape-completeness.py` 가 CLAUDE.md 앵커를 읽음) · 철학 문서 인용 락(`test_charter_citations.sh`) · README 를 읽는 테스트(`test_readme_sync.sh` 등). 이음매 담당은 이 에픽.

## 위험

- K9(압축 뒤 지도 · 결정 내력 소실): 원칙을 추적 파일로 옮기는 것 자체가 답이다. 메모리는 머지 뒤에만 지워 그 사이 소실이 없다.
- 락이 문구를 핀한 곳을 지우면 RED — 지우기 전에 핀 락을 찾고, 락의 뜻을 바꾸는 수정(예: `test_readme_sync.sh` 의 「이력 문단 1~20줄」 단언)은 변이로 이빨을 다시 보인다.
- 다른 에픽과 같은 파일(qg · project-init · plugin-audit README 는 R2a 예약) — 고치는 줄을 R11 몫으로 한정하고 겹침은 통합 리뷰가 본다.
- D21(숨은 가정 · 실패 양식) 가운데 이 에픽에 닿는 것은 「한 곳」 소실(K9) 하나다.

## Acceptance Criteria

- AC1 CLAUDE.md 에 §1 원칙 여섯이 각각 한 줄로 있고, 각 줄이 철학 문서의 해당 원칙을 가리킨다. 새 큰 절이 없다.
- AC2 철학 문서가 원칙 여섯의 이유 · 배경을 담고, 새 P# 가 있으면 기존 P# 에 흡수하지 못한 이유가 같은 절에 한 문장으로 있다.
- AC3 §3 의 CLAUDE.md · 철학 문서 항목이 지워지거나 고쳐졌다(목록 항목마다 대조).
- AC4 §3 의 플러그인 README 넷 항목이 지워지거나 고쳐졌고, R2a 몫 줄은 그대로다.
- AC5 고친 문서마다 정리 전보다 작고, CLAUDE.md 는 정리 전 크기 이하다 — PR 본문에 파일별 전후 크기.
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
- `plugins/spec-distill/tests/test_readme_sync.sh`(이력 문단 단언) · 그 밖에 지운 문구를 핀한 락이 있으면 그 락
- 이 설계문서(`## 미룸` · 이후 `## 판정` · `## 구현 대조`)

## Verification Plan

- 고치기 전에 지울 줄마다 핀 락을 찾는다(조사 표의 「핀하는 락」 칸 + grep).
- 락: `plugins/plugin-audit/tests/test_check_shape_completeness.py` · `plugins/quality-gates/tests/test_law2_prose.sh` · `plugins/quality-gates/tests/test_governance_no_capability_caps.sh` · `plugins/spec-distill/tests/test_epic_conductor_skill.sh` · `shared/tests/test_charter_citations.sh` · `plugins/quality-gates/tests/test_e2e_docs.sh` · `plugins/spec-distill/tests/test_rereview_cap_consistency.sh` · `shared/tests/test_invocation_surface.sh` · `plugins/quality-gates/tests/test_publish_surface_removed.sh` · `plugins/spec-distill/tests/test_readme_sync.sh` · `shared/tests/test_changelog_integrity.sh` · README 를 읽는 qg 테스트.
- 전체 스위트(로드맵 frontmatter `test_command`)를 기준선과 실패 이름으로 대조.
- 크기: 고친 파일마다 `wc -c` 전후.
- 끝에서 끝: 메모리를 쓰지 않는 버릴 레포 세션에서 CLAUDE.md · 철학 문서만으로 원칙 여섯을 찾아 따라갈 수 있는지 읽어 본다(사용자 성공 장면 「내가 말한게 다른 레포에서 사용해도 지켜지면」 — devbrew 개발 규칙은 devbrew 에서, 플러그인 동작 원칙은 넘김을 받은 에픽 · 지휘자 수리가 그 동작 자리에 넣었는지 함께 본다).

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

## 미룸

| 항목 | 이유 | 받는 곳 |
|---|---|---|
| §5 의 R9 행 | R9 범위 | R9 |
| §5 의 R8 행 | R8 범위 | R8 |
| §5 의 지휘자 수리 행 | superpowers 7.0.0 이음매와 같은 PR | 지휘자 수리 PR(R5 후속) |
| §5 의 R2a 행 | R2a 예약 · 진행 중 | R2a |
| §5 의 R10 행 | R10 예약 | R10 |
| §6 머지 뒤 메모리 정리 | 레포 밖 · 머지 뒤에만 | 지휘 세션 |

## 지휘 기록

- 흐름: 설계 흐름(brainstorming → spec-review → 계획 → 구현). brainstorming 은 superpowers 7.0.0 — 설계문서 점검(builder check) 뒤 문서 승인 자리에서 spec-review 를 부른다.

## Metadata

- 에픽: R11 · 브랜치 `feature/principles-docs-cleanup`
- 묶음: `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R11.md`
- 조사 기록(레포 밖): `~/.claude/sdd-mirror/epic-decisions/r11/docs-recon.md` · `memory-recon.md`
