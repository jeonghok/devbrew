# 이음매 진단 — advisory 통합 회계 · brief 리뷰 · 스킬 간 호출

> **읽기 전용 진단.** 코드·플러그인 수정 없음. 구현은 이후 사이클.
> 조사일 2026-08-27 · HEAD `983d7d7` · 설치본 `gitCommitSha 983d7d76…` (리포와 동기)

세 갈래 질문 — (1) advisory 통합 관리 패치가 잘 됐는가, (2) brief 리뷰가 왜 잘 안 불리는가,
(3) 스킬 간 호출(PR 발행 등)이 왜 파이프라인에서 이어지지 않는가 — 에 대한 증거 기반 답이다.
**세 현상은 서로 다른 버그가 아니라 같은 구조의 세 얼굴이다** (§5).

## 목차

- [§0 한 줄 결론](#0-한-줄-결론)
- [§1 조사 범위 · 방법 · 보지 않은 것](#1-조사-범위--방법--보지-않은-것)
- [§2 축 1 — advisory 통합 회계(adjudication) 점검](#2-축-1--advisory-통합-회계adjudication-점검)
- [§3 축 2 — brief 리뷰가 안 불리는 이유](#3-축-2--brief-리뷰가-안-불리는-이유)
- [§4 축 3 — 스킬 간 호출 · PR 발행 연속 단계](#4-축-3--스킬-간-호출--pr-발행-연속-단계)
- [§5 공통 근본 원인](#5-공통-근본-원인)
- [§6 구현 시 결정해야 할 것](#6-구현-시-결정해야-할-것)
- [§7 측정되지 않은 것 — 다음 세션이 먼저 할 probe](#7-측정되지-않은-것--다음-세션이-먼저-할-probe)

---

## §0 한 줄 결론

**devbrew 전체에서 「턴 경계를 넘어 다음 단계를 강제」할 수 있는 메커니즘은 단 하나** —
Stop 훅이 `decision:"block"` 을 내는 것 — **이고, 그것은 `reviewing-spec` 한 곳에만 배선돼 있다.**
전수 조사된 19개 이음매 중 18개는 산문 지시이거나 텍스트 주입이다.

세 질문의 답:

| 질문 | 답 |
|---|---|
| advisory 통합 회계는 잘 됐나 | **절반.** 기록(record)과 공시(disclose)는 실제로 배선됐다. **차단(block)은 배선이 0이다** — `blocks()` 의 프로덕션 호출처가 없다 |
| brief 리뷰가 왜 안 불리나 | 원인 6개가 겹쳐 있다. **최우선 원인은 설계 결함이 아니라 배포 결함** — 선결조건 파일이 플러그인 배포 단위 밖에 있어 devbrew 리포 밖에서는 fail-closed 로 즉시 중단된다 (§3.1) |
| PR 발행이 왜 안 이어지나 | 「파이프라인 스킬이 끝나면 제어가 커맨드로 돌아온다」는 전제 위에 절차가 얹혀 있는데, **그 「제어 반환」이 존재하지 않는 층이다** (§4.2) |

---

## §1 조사 범위 · 방법 · 보지 않은 것

**방법.** 5개 플러그인의 훅 설정 전수 파싱 · 스킬/커맨드 frontmatter 전수 · `adjudication` 호출처
전수 grep · 락(테스트) 정독 · 설치본 캐시와 리포 대조. 병렬 읽기전용 에이전트 3(각 축 1)이 수집하고,
가장 강한 주장 4건은 이 문서 저자가 독립 재확인했다.

**확인된 negative (원인 후보에서 제외).**

- **설치 캐시 stale 아님** — 설치본 `spec-distill 0.35.3` / `quality-gates 4.3.5` = 리포 버전. `autoUpdate: true`.
- **kill switch 안 켜져 있음** — `DEVBREW_*` 환경변수 0건, `settings.json` 의 `env: {}`.
- **전역 Stop 훅 간섭 없음** — 사용자 `settings.json` 의 Stop/SubagentStop 훅은 `.orca/agent` 텔레메트리이고 stdin 을 버린다.
- **brief 리뷰가 한 번도 안 돈 것은 아님** — `docs/superpowers/interview/2026-08-22-…audit.md:76-102` 에 실제 리뷰 라운드 기록이 있다(단, codex 3/3 런타임 실패 · degrade 5건 · 재라운드 상한 도달 · verdict `needs_revise`).

**보지 않은 것 (결과의 약점).**

- **실전 호출률의 실측치가 없다.** 리포에 텔레메트리·로그가 없고, 리뷰 라운드 기록은 `reviewing-brief/SKILL.md:498` 이 "게이트 통과 조건이 아니라 **기록**"이라 명시하므로 집계 근거가 못 된다. 이 문서의 모든 결론은 **구조 증거**이지 빈도 측정이 아니다.
- **skill 계층 `allowed-tools:` 가 런타임에 실제로 집행되는지 미측정.** 리포의 유일한 실측(`CLAUDE.md:42`, 2026-08-22 헤드리스 5변형)은 **커맨드 계층**만 다뤘고 "이 계층은 제한이 아니다"로 결론냈다. §4.3 의 "파이프라인이 `Skill` 을 못 부른다"는 **선언된 제약**이며 집행 여부는 미확인이다.
- **훅의 `systemMessage` 채널이 모델 컨텍스트에 도달하는지 미측정** (`additionalContext` 와 구분).
- **`shared/tests/test_dispatch_disposition.sh` 를 실행하지 않았다** (`mktemp -d` 를 하므로). 파이썬 도출부만 동일 로직으로 재현해 `agents 18 / dispatch 18 / anchors 18` 등식 성립을 확인했다.

---

## §2 축 1 — advisory 통합 회계(adjudication) 점검

`shared/adjudication/adjudication.py` (2026-08-23 도입, PR #132/#133 로 2026-08-25 머지).
「에이전트가 낸 판정을 그대로 믿지 않고, 무엇이 수용·기각·보류·소실됐는지를 세어서 공시한다」는 회계 모듈.

### 2.1 무엇이 실제로 작동하는가

**기록(record) — 작동한다.** 4개 프로덕션 스크립트에 18개 호출 자리가 실재한다:
`synthesize_findings.py` · `synthesize_artifact_findings.py` · `merge_review.py` · `merge_brief_review.py`.
`hold()`(소실) · `source_failed()`(입력 사망) · `coerced()`(값 강제) · `uncountable()`(셀 수 없음)이 실제로 불린다.

**공시(disclose) — 대체로 작동한다.** 가장 완전한 배선은 `synthesize_findings.py:561-564` →
stdout `판정 degrade` / `**이 실행은 clean이 아니다**` 마커 → `quality-pipeline/SKILL.md:560-591`
이 그 마커를 키로 잡아 **verbatim 출력 + bare `clean` 금지**를 강제한다. 이건 제대로 됐다.

### 2.2 무엇이 안 됐는가 — 끊긴 배선

| # | 끊긴 것 | 근거 | 결과 |
|---|---|---|---|
| A1 | **`blocks()` 프로덕션 호출처 0** | `adjudication.py:89`. 전수 grep 결과 히트는 모듈 자신의 `_degraded()`, 테스트 1건, 주석 1건뿐 | **차단 술어의 배선이 존재하지 않는다.** 회계는 공시만 한다 |
| A2 | **`surfaced()` 프로덕션 호출처 0** | `adjudication.py:136` | 생성자 인자 `items="open"\|"closed"` 와 앵커의 `fail-open/fail-closed` 필드가 **양쪽 다 런타임 행동을 바꾸지 않는다** |
| A3 | **`absorbed()` · `reject()` 호출처 0 (테스트 포함)** | 전수 grep 0건 | 모든 소비자의 `counts.absorbed` · `counts.rejected` 가 **항상 0**. 모듈 docstring 이 세우는 네 처분 중 둘이 사문 |
| A4 | `synthesize_artifact_findings.py` 가 원장을 반쪽만 쓴다 | `:211` 이 `counts.held` **하나만** 꺼내고, 같은 `report()` 의 `degraded`·`reasons`·`unknown_counts` 는 버려진다. `:235` 가 degrade 를 **원장과 무관하게 독립 계산** | 축 B(import) 는 GREEN 인데 공시는 모듈이 아니라 자체 로직이 낸다 |
| A5 | 같은 파일에서 `source_failed()` 미호출 | `:100-108`, `:150` 이 `sources_failed` 를 자체 정수로 센다 | `_has_primary_source_failure()` 가 이 경로에서 **영원히 False**. 원장의 `degraded` 가 실제 입력 사망을 모른다 |
| A6 | 축 C 가 이미 vacuous 한 실배포 사례 1건 | `plugin-audit/scripts/smoke-workflow.js:11` 의 `disclosure=sentinelPath` — 그 리터럴은 `:14/:16/:18` 에 있으나 **CLI 인자명**이지 공시 채널이 아니다 | 설계 §12 R2 가 예고한 실패 모드가 배포본에 실재 |
| A7 | `report()["counts"]` 에 `unknown` 수가 없다 | `adjudication.py` — `unknown_counts` 리스트로만 나간다 | counts 만 읽는 소비자는 「셀 수 없음」을 못 본다. 「침묵과 0 은 다른 사실」이라는 규정이 자기 스키마에서 새는 자리 |

### 2.3 락이 못 잡는 것 (계획 문서가 자인한 것 + 실측)

`docs/superpowers/plans/2026-08-23-subagent-adjudication-contract.md` 「이 계획이 남기는 것」이
이미 적어 둔 것을 그대로 옮긴다 — **새로 발견한 갭이 아니라, 알고 남긴 갭이다**:

> **R1** — 축 B 가 재는 것은 「모듈을 쓰는가」도 아니고 **「import 처럼 생긴 줄이 raw 텍스트에 있는가」**다 … docstring 안의 한 줄로도 만족된다 〔실측: 실제 import 를 지우고 docstring 에 넣으면 락 전건 GREEN 인데 런타임 NameError〕

> **축 C** — 리터럴이 파일 본문에 있다는 것은 그 채널이 실제로 읽힌다는 증거가 아니고 … **한 글자짜리 리터럴로도 만족된다**

> 배포 소비자 4개 중 **아무도 `blocks()` 도 `surfaced()` 도 호출하지 않는다** … §9.1 의 두 술어 중 공시만 배선돼 있고 **차단은 배선이 0**

### 2.4 판정

**부분 성공.** 「에이전트 말을 바로 믿지 않는다」의 절반 — *무엇이 버려졌는지 세어서 사용자에게 보인다* — 은
실제로 동작한다. 나머지 절반 — *셀 수 없거나 주 판정자가 죽었으면 막는다* — 은 **술어만 있고 호출자가 없다.**

이건 결함이라기보다 **미완의 2단계**로 읽는 게 정확하다: 계약과 계측기를 먼저 세우고 집행을 나중에
붙이는 순서였고, 계획 문서가 그 사실을 정직하게 적어 뒀다. 다만 **A3(호출조차 없는 처분 2종)과
A4/A5(원장을 쥐고도 자체 계산하는 소비자)는 계획이 예고하지 않은 실제 배선 결함**이다.

> **후속 — 지형 질문은 형제 문서로 갈라졌다.** 이 절이 답한 것은 「배선됐나」다.
> 「그러면 지형을 바꿀까」(받는 곳을 오케스트레이터로 통일 · 오케스트레이터가 1차 재비판 ·
> 재비판 서브에이전트 제거)는 사용자 결정이 실린 별도 문서에 있다 —
> [`2026-08-27-adjudication-topology-handoff.md`](2026-08-27-adjudication-topology-handoff.md).
> 그 문서 §1 이 서브에이전트 18개의 처분 지형을 전수로 싣고, §2 가 **codex 단독 의존 재비판
> 2건이 현재 죽어 있음**을 실측한다.

---

## §3 축 2 — brief 리뷰가 안 불리는 이유

원인이 6개 겹쳐 있다. **B0 이 압도적으로 중요하다** — 나머지는 확률을 낮추지만, B0 은 조건이 맞으면 100% 차단한다.

### 3.1 B0 — 선결조건 파일이 플러그인 배포 단위 밖에 있다 〔최우선〕

`plugins/spec-distill/skills/reviewing-brief/SKILL.md:107`:

> 판정은 `docs/audits/2026-07-27-spec-distill-zero-tool-probe.md` 의 `**분기 판정:**` 한 줄입니다.
> 그 파일이 없거나 판정을 읽을 수 없으면 **파이프라인을 시작하지 않습니다**

이 경로에는 `${CLAUDE_PLUGIN_ROOT}` 가 없다 → **사용자 cwd 기준으로 resolve** 된다. 그리고 실측:

- `plugins/spec-distill/` 안에 **없다**
- 설치본 `~/.claude/plugins/cache/devbrew/spec-distill/0.35.3/` 안에 **없다**
- devbrew 리포 루트 `docs/audits/` 에만 **있다**

**결과: devbrew 리포 밖의 어떤 프로젝트에서든 `reviewing-brief` 는 자기 규정에 따라 시작하지 않는다.**
이건 모델의 재량 문제가 아니라 문서가 지시한 fail-closed 중단이다. 같은 패턴을 리포 전체에서 훑은 결과,
**fail-closed 선결조건으로 cwd 상대 리포 경로를 쓰는 곳은 이 한 곳뿐**이다(`plugin-audit` 의 `docs/audits/` 참조는 전부 *출력* 경로).

### 3.2 B1 — 훅 커버리지 비대칭 (설계된 것)

| | design/spec (`docs/superpowers/specs/`) | interview brief (`docs/superpowers/interview/`) |
|---|---|---|
| PostToolUse 구조 검증 | ✅ `spec-write-validator.py` → 실패 시 `decision:"block"` | ❌ out-of-scope, exit 0 무출력 |
| `pending_review:` arm | ✅ | ❌ |
| **Stop 훅 강제 dispatch** | ✅ `decision:"block"` | ❌ |
| UserPromptSubmit 재알림 | ✅ | ❌ |
| **리뷰 미실행 감지** | 재편집 시 재arm | **없음** |

근거: `spec-write-validator.py:53` `PATH_PREFIX = "docs/superpowers/specs/"` · `arm_ledger.py:42` 동일 PREFIX ·
`canonical_key('docs/superpowers/interview/…') → None` 실측. 그리고 **두 훅의 mandate 문자열이
`reviewing-spec` 으로 하드코딩**돼 있다(`review-dispatch.py:216`, `pending-review-reminder.py:124`).
`plugins/spec-distill/hooks/` 전체에서 `reviewing-brief` 문자열은 **0회** 등장한다.

CHANGELOG `[0.24.0]` 이 이를 명시한다: *"**훅 0개 추가** — `hooks/` 파일 집합과 `hooks.json` 이 무변경이다."*

### 3.3 B2 — 호출 지시가 두 홉 안쪽, 산문 한 줄

`conducting-interview/SKILL.md` 에 `reviewing-brief` 문자열이 **0회** 등장한다. frontmatter `description`
에도 리뷰 언급이 없다. 유일한 경로는 `SKILL.md:346` → `references/finishing.md` (조건부 Read) → `:72` 의 산문 한 줄.

그 포인터의 어휘가 약하다 — *"그 파일을 Read 로 읽어 그대로 따른다"*. 같은 파일의 다른 지시는
저자가 강한 어휘를 쓸 줄 안다는 걸 보여준다(`:287` *"하나라도 미충족이면 종료 차단"*). **이 자리에만 안 썼다.**

결정적으로 그 절의 **제목이 「종료 — brief 작성 + optional handoff」** 다. 제목에 리뷰가 없고,
남은 단계는 "optional" 로 표시된다. 제목만 훑는 독자에게 이 파이프라인의 종료 모델은
**「brief 쓰면 끝, 나머지는 선택」**이다. `/interview` 커맨드의 「다음 단계」 절도 흐름을
brief 생성에서 끝내고 리뷰를 언급하지 않는다.

### 3.4 B3 — 핸드오프 인자 3개가 호출 시점에 소멸한다

`finishing.md:63-69` 이 ```` ```bash ```` 펜스 안에서 `PAYLOAD` / `CODEX_DIR_YAML` / `CODEX_FID_YAML` 을
셸 변수로 세팅하고, `:72` 의 **별개 펜스**에서 `Skill spec-distill:reviewing-brief $PAYLOAD …` 를 호출한다.

**같은 플러그인이 이 사실을 스스로 반증한다** — `reviewing-brief/SKILL.md:97-99`:
> **셸 변수가 아니라 파일인 이유**: `Bash` 도구는 호출마다 **새 셸**입니다 — 유지되는 것은 cwd 뿐이고 변수·`export` 는 소멸합니다(실측).

즉 세 인자가 전달되려면 모델이 값을 **리터럴로 직접 치환**해야 한다. `finishing.md:75` 는 주석-vs-인자
함정만 경고하고 셸 변수 소멸은 다루지 않는다. 그리고 락(`test_brief_review_entry.sh:171-176`)은
`grep -qF '$PAYLOAD'` 로 **리터럴 달러 문자열의 실재**만 확인하므로, **깨진 상태를 GREEN 으로 고정한다.**

### 3.5 B4 — 진입 게이트에 1클릭 opt-out

`cost_class: high` → 진입 승인 `AskUserQuestion`. `reviewing-brief/SKILL.md:51` 의 선택지:
> `{label: "건너뛰고 Step B로", description: "리뷰 없이 진행. skip record가 Step B 게이트 질문에 표시됩니다."}`

그리고 `:42` 는 승인 질문에 **하한이 아니라 상한**(에이전트 5 + codex 4회)을 싣는다고 명시한다.
이건 P17(사용자 주권)의 올바른 구현이지, 결함이 아니다. **다만 비용 회피 유인이 구조적으로 크다는
사실은 기록해 둘 값어치가 있다.**

### 3.6 B5 — 「안 돌린 것」과 「깨끗했던 것」이 구분되지 않는다

`check_brief.py` 의 `gate()` 는 섹션·frontmatter·bijection·coverage ledger 를 검사하지만
**리뷰 실행 여부에 대한 검사가 전무하다.** 그리고 이건 고칠 수 없다 — 같은 파일 `:25-26` 의 불변식:

> **이 스크립트는 brief 파일만 읽는다** … conducting-interview 의 세션 상태 파일에 대한 의존을 여기에 절대 넣지 않는다

더해서 `brief_review_state.py:201-203` 의 `parse()` 는 키 부재를 `brief_review_degradations: []` + `migrated`
로 **default 승격**한다. 원장 레벨에서 「리뷰를 안 돌렸다」와 「리뷰가 clean 했다」가 같은 값이 된다.

`brief_review_stage` / `brief_critic_rounds` 를 읽는 소비자를 전수 grep 한 결과 **자기 유닛 테스트 하나뿐**이다.

### 3.7 스킬 자신이 백스톱의 전제를 잘못 잡고 있다

`reviewing-brief/SKILL.md:492`:
> **리뷰 생략 방지의 실제 메커니즘이 이 전파입니다.** 결정론 체크가 아닙니다 — … 사람이 더 강한 백스톱이며,
> 그래서 *"리뷰 라운드 기록이 있는가"* 같은 이빨 없는 검사를 넣지 않습니다

이 문장은 **진입이 이미 일어난 뒤의 중도 이탈**을 전제한다. 애초에 진입하지 않으면 전파할 것도,
사람에게 보일 것도 없다 — 백스톱이 기대는 조건 자체가 성립하지 않는다.

---

## §4 축 3 — 스킬 간 호출 · PR 발행 연속 단계

### 4.1 이음매 전수 — 19개 중 강제력을 가진 것은 1개

| 강제력 | 개수 | 대표 |
|---|---|---|
| **① 훅 block (`decision:"block"`)** | **1** | `review-dispatch.py:263-267` → `reviewing-spec` |
| 훅 텍스트 주입 | 2 | `pending-review-reminder.py:123`(additionalContext) · `post-tool-use.py:82-95`(systemMessage, "You MUST now…") |
| ③ 산문 MUST (+AP2 가드) | 3 | `finishing.md:219` · `reviewing-spec/SKILL.md:222` — **spec-distill 전용** |
| ④ 산문 권고 (Read 지시) | 3 | `conducting-interview/SKILL.md:346` → finishing.md 등 |
| **⑤ 없음 (평서문 절차)** | **10** | `/qg`→pipeline · **pipeline→publish** · `/interview`→interview · A.5→reviewing-brief · `/plugin-audit`·`/standup` 등 |

### 4.2 PR 발행 — 「제어 반환」이라는 픽션

`plugins/quality-gates/commands/qg.md:75`:
> 파이프라인 스킬(`Skill("quality-gates:quality-pipeline")`)이 **종료해 제어가 이 커맨드로 돌아오면**, 아래를 **순서대로** 수행한다.

**Claude Code 에는 커맨드→스킬→커맨드의 프로그램적 return 이 없다.** 슬래시 커맨드는 호출 시점에
프롬프트 텍스트로 전개되고, `Skill` 결과는 SKILL.md 본문(**990줄**)을 컨텍스트에 얹는다.
「돌아온다」를 담당하는 것은 **모델이 990줄과 다수의 subagent 라운드 뒤에도 `qg.md:73-118` 을
기억하고 실행하는 것**뿐이다.

그리고 그 뒤를 받쳐 줄 것이 없다 — 명시적으로 그렇게 설계됐다:

- `plugins/quality-gates/hooks/hooks.json` 에 **Stop 훅 없음** (PostToolUse×2 · SessionStart · SessionEnd)
- 같은 파일 description: *"Pipeline progression managed in-turn by the quality-pipeline SKILL."*
- `quality-pipeline/SKILL.md:987`: *"v1.32.0 has no Stop hook continuation, no emission tag, and no continuation sentinel."*
- `qg.md:187-189`: *"Pipeline runs in a single assistant turn."*

**즉 이 이음매는 턴을 넘길 수 없고, 넘어가면 다시 띄우는 주체가 존재하지 않는다.** 복구 경로는
사용자가 손으로 `/qg-publish` 를 치는 것뿐이다.

### 4.3 sentinel 은 트리거가 아니라 브레이크다

`publish-eligible.md` 의 전 생산자/소비자:

| 역할 | 위치 |
|---|---|
| 생산 (Write) | `quality-pipeline/SKILL.md` Final Summary + Runtime R8 |
| 삭제 | `setup-qg.sh:37`, `:179` (다음 `/qg` 실행 시 stale 정리) |
| GC 마커 | `qg-gc.py:49` |
| **소비 (읽기)** | **`qg.md:93-94` — 오직 여기 한 곳. 그것도 산문** |

sentinel 은 `test -f` + 마커 1행으로 **offer 를 억제**하는 fail-safe 이지 **발동시키는 트리거가 아니다.**
모델이 절차를 실행하지 않으면 sentinel 은 디스크에 남았다가 다음 `/qg` 의 stale 정리에 조용히 사라진다.
**「발행이 밀려 있다」는 증거가 아무 소리 없이 GC 된다.**

### 4.4 파이프라인 스킬은 publish 를 부를 수 없다 (선언상)

`quality-pipeline/SKILL.md` 의 `allowed-tools` 25항목: `Agent` · `AskUserQuestion` · `Read` · `Glob` ·
`Grep` · `Edit` · `Write` + 스코프된 Bash 18. **`Skill` 이 없다.** 이건 실수가 아니라 명시적 설계다 —
`quality-gates/CHANGELOG.md:2697`: *"파이프라인 tool-set 무변경(`Skill` 미추가, NG6) — … sentinel 만
Write 하고 커맨드가 그걸 보고 offer 한다."*

⚠️ **단, 이 선언이 런타임에 집행되는지는 미확인이다** (§1). 커맨드 계층의 `allowed-tools` 는 실측 결과
아무것도 집행하지 않았다. 설계 의도는 어느 쪽이든 커맨드 계층 경유이므로 결론은 바뀌지 않는다.

### 4.5 락도 문서도 이 이음매를 지키지 않는다

- `test_qg_publish_offer.sh` 는 헤더에서 스스로 **"Static doc-lock"** 이라 선언한다. 7개 단언 전부가
  `qg.md` 의 offer 창을 `grep -qF` 한다. **전이가 실제로 일어나는지 재는 테스트는 리포에 없다.**
- `quality-gates/README.md` 의 정본 상태 다이어그램은 **`Final summary` 에서 끝나고 publish offer 가
  그려져 있지 않다.** 그것을 요구하는 락(`test_readme_state_diagram_complete.sh:39`)의 종점도 `Final summary` 다.
- **AP2(polite stop) 가드가 quality-gates 표면에 0건이다.** `CLAUDE.md` 의 "Polite handoff" 금지 항목은
  **spec-distill 을 명시적으로 지목**한다. 구조가 동일한 qg 이음매는 **리포의 금지 패턴 카탈로그에 이름이 없다.**
- `qg.md:114-117` 의 graceful floor 는 *"post-pipeline 단계가 **실행은 됐으나** … 에러하면"* 만 다룬다.
  저자는 「실행되지 않는 경우」를 구분해 인지했으면서 그 경우의 처리를 적지 않았다. **관측 불가능한
  미실행 — 지금 일어나는 현상 — 에는 어떤 floor 도 없다.**

---

## §5 공통 근본 원인

철학 P13 이 이미 규정하고 있다: **hook = 집행 레이어 · skill = capability 표면 · agent = scoped persona.**

세 현상은 전부 **집행을 capability 표면(스킬/커맨드 산문)에 기대한 것**이다:

- **축 1** — 회계 모듈의 *차단* 술어를 만들어 두고 호출자를 산문 규정에 맡겼다 → 호출자 0
- **축 2** — brief 리뷰 진입을 산문 한 줄에 맡겼다 → 훅 0, 게이트 0, 감지 0
- **축 3** — 파이프라인→발행 전이를 "제어 반환" 픽션에 맡겼다 → 재기동 주체 0

그리고 셋 다 **같은 방식으로 잠겨 있다** — 문구가 문서에 있는지 grep 하는 정적 doc-lock.
이 락들은 전부 GREEN 이고, **GREEN 인 채로 세 현상이 전부 일어나고 있다.**
「락의 PASS 는 이빨의 증거가 아니다」의 세 번째 실증이다.

**대조군(양성 대조).** 유일하게 하드 배선된 이음매 — Stop 훅 → `reviewing-spec` — 는 **너무 잘 작동해서
반대 방향의 문제를 냈다**: 과잉 dispatch 를 막으려고 arm-once 원장(v0.25.0, 순감 589줄)을 따로 만들어야 했다.
**메커니즘이 없어서 안 되는 것이지, 메커니즘이 약해서 안 되는 것이 아니다.**

---

## §6 구현 시 결정해야 할 것

구현하지 않았다. 다음 사이클이 **먼저 골라야 하는 것**만 적는다.

### 6.1 즉시 고칠 수 있는 것 (설계 결정 불요)

| # | 대상 | 성격 |
|---|---|---|
| **F1** | `reviewing-brief/SKILL.md:107` 의 zero-tool probe 경로 (§3.1) | 배포 결함. probe 판정을 플러그인 안으로 옮기거나 경로를 `${CLAUDE_PLUGIN_ROOT}` 기준으로. **devbrew 밖에서 100% 차단 중** |
| **F2** | `finishing.md:63-72` 의 셸 변수 인자 (§3.4) | 리터럴 치환 또는 파일 경유. 같은 플러그인이 이미 "파일로" 라고 적어 뒀다 |
| **F3** | `synthesize_artifact_findings.py:211/:235` (§2.2 A4·A5) | 원장을 쥐고도 자체 계산 중. 형제 `synthesize_findings.py` 가 올바른 형태 |

### 6.2 설계 결정이 필요한 것

**D1 — 이음매 강제를 어디까지 할 것인가.** 선택지와 대가:

- ① **Stop 훅을 확장** (brief · publish 에도 `decision:"block"`). 유일하게 검증된 메커니즘.
  대가: arm-once 급 재발동 가드를 이음매마다 새로 만들어야 한다(선례가 589줄이었다).
- ② **sentinel 을 SessionStart/UserPromptSubmit advisor 가 읽게** 한다. 훨씬 가볍고, qg 에 이미
  `session-start-advisor.py` 가 있다. 대가: 강제가 아니라 알림 — 턴 안에서는 여전히 안 걸린다.
- ③ **아무것도 안 한다** — 이음매를 사용자 트리거로 공식화하고(`/qg-publish` 를 정본 경로로),
  `qg.md` 의 "제어가 돌아오면" 문장과 README 다이어그램을 사실에 맞게 고친다.
  대가: 자동화 포기. **이득: 지금 문서가 하는 거짓 약속이 사라진다.**

**기록해 둘 판단** — ③이 가장 devbrew 답다(「하니스 가볍게」·「막지 않는 것을 막는다고 믿게 만드는
선언은 없는 것보다 나쁘다」). 다만 이건 **사용자가 고를 문제**다: 자동 발행을 원하는지가 전제다.

**D2 — 회계의 차단 술어를 살릴 것인가 (§2.2 A1·A2).** `blocks()`/`surfaced()` 에 호출자를 붙일지,
아니면 **차단 술어를 삭제하고 회계를 공시 전용으로 정직하게 축소**할지. 후자면 앵커의 `fail-open/closed`
필드와 `items=` 인자도 함께 정리 대상이다 — 지금 둘 다 아무 행동도 바꾸지 않는다.

**⚠ 이 선택은 더 이상 중립이 아니다.** 형제 문서의 결정 M2(「오케스트레이터가 항상 1차로
재비판」)가 이 항목을 한쪽으로 기울인다 — 재비판이 항상 돈다면 「막는다」의 의미가 「사람에게
올린다」로 바뀌고, `blocks()` 는 삭제가 아니라 **재정의** 대상이 된다.
`2026-08-27-adjudication-topology-handoff.md` §4 T5 참조.

**D3 — 리뷰 미실행을 감지할 것인가 (§3.6).** `check_brief.py` 의 불변식(brief 파일만 읽는다)이
이 감지를 구조적으로 금지한다. 감지를 원하면 **다른 층**이어야 한다. 층을 안 옮기고 같은 자리에서
반복 시도하면 whack-a-mole 이 된다.

---

## §7 측정되지 않은 것 — 다음 세션이 먼저 할 probe

구현 전에 이것부터. **셋 다 지금 추측으로 남아 있고, 추측 위에 설계하면 §6 의 선택이 틀린다.**

1. **skill→skill 전이 headless probe.** `Skill` 산문 지시가 실제 Skill 도구 호출로 변환되는가?
   `user-invocable: false` 스킬을 다른 스킬이 부를 수 있는가? 선례가 있다 —
   `docs/audits/2026-07-27-spec-distill-zero-tool-probe.md` 가 agent `tools: []` 에 대해 정확히 이 방법을 썼다.
   **같은 방법이 이 이음매에는 적용된 적이 없다.**
2. **skill 계층 `allowed-tools` 집행 여부.** 커맨드 계층은 2026-08-22 에 "집행 안 함"으로 실측됐다.
   스킬 계층은 미측정 — §4.4 의 결론이 여기 달려 있다.
3. **훅 `systemMessage` vs `additionalContext` 배달지.** 기억에 이미 「이벤트마다 다르다」는 실측이 있다.
   `post-tool-use.py:87` 의 "You MUST now…" 가 모델에 닿는지 확정되지 않았다.

---

## 인용 색인

| 주장 | 근거 |
|---|---|
| Stop 훅이 리포 전체에 1개 | `plugins/*/hooks/hooks.json` 전수 파싱 |
| 그 훅의 목적지가 `reviewing-spec` 하드코딩 | `review-dispatch.py:216`, `:266` |
| `hooks/` 에 `reviewing-brief` 0회 | `grep -rn reviewing-brief plugins/spec-distill/hooks/` |
| brief 는 arm 대상 아님 | `spec-write-validator.py:53`, `arm_ledger.py:42` |
| zero-tool probe 파일이 설치본에 없음 | `find ~/.claude/plugins/cache/devbrew/spec-distill/0.35.3 -name '*zero-tool*'` → 0건 |
| `blocks()`/`surfaced()` 프로덕션 호출 0 | `grep -rn '\.blocks()\|\.surfaced()' --include='*.py'` |
| `absorbed()`/`reject()` 호출 0 | `grep -rn '\.absorbed(\|\.reject(' --include='*.py'` |
| 파이프라인 `allowed-tools` 에 `Skill` 없음 | `quality-pipeline/SKILL.md` frontmatter 25항목 |
| sentinel 소비자가 `qg.md` 산문 1곳 | `grep -rn publish-eligible plugins/quality-gates/` |
| publish 락이 doc-lock | `test_qg_publish_offer.sh` 헤더 자기 선언 |
| README 다이어그램 종점 = Final summary | `quality-gates/README.md:248-286`, `test_readme_state_diagram_complete.sh:39` |
| 설치본과 리포 동기 | `installed_plugins.json` `gitCommitSha 983d7d76…` |
