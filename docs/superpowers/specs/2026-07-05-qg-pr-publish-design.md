# quality-gates v2.9.0 — PR-understanding 생성·게시 (design)

> **코드를 읽지 않는 사람이 diff 없이 PR의 아키텍처·구조·구현을 완전히 이해하도록,
> 결정론 envelope + 모델 저술 content로 PR-이해 본문을 생성하고, consent·시크릿 가드
> 하에 GitHub PR에 멱등 게시한다.**

- **type:** brainstorming design doc (spec-distill 흐름: interview brief → 이 문서 → spec-reviewer → writing-plans)
- **source interview brief:** `docs/superpowers/interview/2026-07-05-qg-pr-publish-interview.md`
- **worktree:** `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+qg-pr-publish` (branch `feature/qg-pr-publish`, base `00415d9`=origin/main)
- **session_id:** 5e42358f-119f-4ca9-b2ca-74061bdb80b3

## 목차

- [1. Context / Why](#1-context--why)
- [2. Goals / Non-goals](#2-goals--non-goals)
- [3. 확정 결정 (인터뷰 + 3-관점 리뷰 + 사용자)](#3-확정-결정)
- [4. 아키텍처 (컴포넌트 격리)](#4-아키텍처)
- [5. 데이터 흐름 (파이프라인)](#5-데이터-흐름)
- [6. 콘텐츠 스키마 + Tier + 다이어그램 결정론](#6-콘텐츠-스키마)
- [7. 보안 모델 (경량화)](#7-보안-모델)
- [8. lightness 원리 — hard-block 2개, 나머지 페르소나+preview](#8-lightness-원리)
- [9. 보고 UX (두 표면)](#9-보고-ux)
- [10. 에러 처리 / graceful degradation](#10-에러-처리)
- [11. 테스트 전략](#11-테스트-전략)
- [12. Files to Modify](#12-files-to-modify)
- [13. Verification Plan](#13-verification-plan)
- [14. devbrew 체크리스트 + 버전](#14-devbrew-체크리스트)
- [15. Acceptance Criteria](#15-acceptance-criteria)
- [16. Rejected Alternatives](#16-rejected-alternatives)
- [17. Open Questions (잔여)](#17-open-questions)
- [Handoff Context](#handoff-context)
- [18. Metadata](#18-metadata)

## 1. Context / Why

**(ROOT_CAUSE)** qg의 유일한 인간-대면 산출물은 `synthesize_findings.py`가 만드는 **결함 표**(`Sev | Path:Line | Conf | Summary | Source`) + suggested-fixes + 2줄 verdict다. 이것은 *기계가 찾은 버그의 목록*일 뿐 **"이 PR이 무엇을·왜 하며 구조상 어떻게 생겼는가"를 설명하는 서사가 아니다.** 사용자는 브랜치 diff/코드를 읽지 않으므로 결함 목록만으로는 아키텍처·구조·구현을 파악할 수단이 전혀 없다. qg는 애초에 GitHub PR에 아무것도 남기지 않는 순수 로컬 도구다.

**진짜 goal:** quality-gates 파이프라인에 — 기존 결함 게이트는 그대로 두고 — 코드를 읽지 않는 사람이 PR을 완전히 이해하도록 만드는 **결정론 envelope + 모델 저술 content**의 PR-이해 산출물을 추가하고, 그것을 **PR과 터미널에 안전하게(멱등·consent·시크릿 가드) 게시**하는 별도 skill을 만든다. 성공 기준은 길이가 아니라 **비독자가 그 산출물만으로 PR의 구조와 구현을 오해 없이 재구성할 수 있는가**이다.

## 2. Goals / Non-goals

**Goals**
- G1. 비독자-완결 PR-이해 본문을 생성 — Before→After 행동차분 + "지금 어떻게 동작하나"(대표 trace) + 구조·계약 표 + 조건부 다이어그램. **findings 미포함**(순수 이해).
- G2. GitHub PR에 **멱등**(단일 sticky 코멘트 upsert) 게시. PR 부재 시 consent 후 생성.
- G3. 생성(무권한 read-only)과 게시(권한 소비)의 **물리 분리** — gh/network는 새 publish skill에만.
- G4. 비가역 유출·오해를 구조적으로 방어하되 **기능을 억제하지 않는** 경량 규칙.
- G5. 두 터미널 보고 표면 개선: qg Final Summary + publish 보고(스캔가능 표·트리, dry-run 미리보기).

**Non-goals**
- NG1. inline 라인 코멘트(v1 제외 — plain gh CLI 취약, cli/cli#12396).
- NG2. `gh pr review`(approve/request-changes) 게시(비멱등, 자기 PR approve 불가).
- NG3. 게시 본문에 qg findings/"무엇을 고쳤나" 포함(관심사 분리 — qg 터미널 귀속).
- NG4. 기계-파싱 verdict 블록(v1 제외).
- NG5. `/qg` 뒤 publish auto-chain(명시 opt-in 커맨드만).
- NG6. 전용 bot/PAT identity(v1은 사용자 gh 토큰; 문서화된 opt-in으로 연기).
- NG7. OS-수준 egress 격리(qg와 동일 — 명시적 non-goal).

## 3. 확정 결정

인터뷰(brief LD1–LD10) + 3-관점 비판적 subagent 리뷰(LD10 authorization) + 사용자 판단으로 확정:

| # | 결정 | 근거 |
|---|---|---|
| D1 | **배치 = quality-gates 내**(gh는 publish skill에만; quality-pipeline·`/qg`엔 절대 없음) | 사용자 선택. Review gate의 no-gh 순수성 보존 |
| D2 | **콘텐츠 스키마 = 메커니즘-중심** | 사용자 선택. C 리뷰: 델타-중심 LD5는 "글 많은데 구현 이해 안 됨" 재생산. LD7>LD5 |
| D3 | **identity = 사용자 gh 토큰** | 사용자 선택. 토큰값 절대 echo 금지, 매 consent에 identity 표시 |
| D4 | **모델 = 빌더 `model: opus` 고정** | 사용자 지시. adversarial 선례(판단 병목에 capability) |
| D5 | **lightness = hard-block 2개(secret-scan·marker 모호)만, 나머지 페르소나+preview 경고** | 사용자 감사 요청 결과. §8 |
| D6 | base = repo 기본 브랜치(`gh repo view --json defaultBranchRef`), consent 표시 | OQ8, abort 가능 |

## 4. 아키텍처

qg의 기존 Law-2 패턴(read-only reviewer 에이전트 ↔ gh 가진 orchestrator) 재사용.

```
/qg-publish [--dry-run]              command (short imperative → skill dispatch)
        │
        ▼
publishing-pr-understanding          SKILL (gh를 가진 유일 orchestrator; cost_class: variable)
  allowed-tools: Read, Grep, Glob, Agent, AskUserQuestion,
                 Bash(build-pr-context.sh, diagram-facts.sh, secret-scan.py,
                      pr-detect.sh, comment-upsert.py, render-terminal.py),
                 Bash(gh auth status:*, gh pr create:*,
                      git rev-parse:*, git symbolic-ref:*, git push:*)
  INVARIANTS:
    - artifact = opaque bytes → gh 게시는 --body-file / -F body=@file, 절대 문자열 보간 금지
    - raw diff 재수집 금지 (git은 metadata 전용: rev-parse/symbolic-ref/push)
    - gh api list/PATCH/POST는 comment-upsert.py 내부에 캡슐화 (orchestrator는 스크립트만 호출)
        │ context blob (inlined, read-only)            │ artifact file (opaque)
        ▼                                              ▼
build-pr-context.sh + diagram-facts.sh          secret-scan.py / pr-detect.sh /
  (pure read-only git → 고정 blob + nodes/edges)   comment-upsert.py / render-terminal.py
        │                                           (pure decision; gh는 thin 실행; stub-testable)
        ▼
pr-understanding-builder             AGENT (de-privileged 생성기; model: opus)
  allowedTools: (없음 — 파일시스템 tool 0개)  ← Read/Grep/Glob/Bash/git/gh/network 전부 0개
  disallowedTools: Write, Edit, MultiEdit, NotebookEdit, Read, Grep, Glob, Bash
  유일 입력 = 프롬프트에 inlined된 build-pr-context.sh blob (단일 통제 채널;
             빌더는 .env·리포 밖 파일을 물리적으로 못 읽음 — boundary가 frontmatter 사실)
  persona: v2.8.0 untrusted-input norm + 서술 중립성 + 비독자 audience + tier
  emits: tier별 고정-스키마 artifact (findings 없음)
```

**컴포넌트 경계 (각 유닛: 무엇을·어떻게 쓰나·의존):**
- `build-pr-context.sh` — base..HEAD의 name-status + **변경 파일 전체 내용(스코프 내)** + import된 **이웃 시그니처**(def/class/export grep) + 커밋메시지 + 브랜치명 + changed test 파일을 고정 blob으로. **이 blob이 빌더의 유일 입력**(빌더는 FS tool 0개 — R1 filter 경계 우회 차단). 의존: git(read-only). 빌더가 git·FS를 못 갖게 하는 핵심(A 교정 — `Bash(git)`엔 push/config/alias-exec 표면; Read/Grep/Glob은 filter 우회).
- `diagram-facts.sh` — nodes = changed files **+ 그 파일들이 import하는 이웃 모듈**(변경 안 됐어도 포함 — 이해 context; **repo root 내 상대 import만**, node_modules/vendor/stdlib 제외 — blob·corpus 팽창 방지), edges = 변경 파일에 **추가된** import 라인. 의존: git+grep. 출력은 빌더의 다이어그램 grounding + render의 ASCII 진실원.
- `pr-understanding-builder` — blob+Read만 의존. tier별 artifact 저술. 유일한 모델 판단 지점(opus).
- `secret-scan.py` — payload → `{scan_ok, findings[]}`. 의존: source corpus(파일). 유일한 콘텐츠 hard-block.
- `pr-detect.sh` — `{has_pr, number, url, state, head_pushed}`. 의존: gh pr view + git rev-parse.
- `comment-upsert.py` — 입력 `(pr#, marker, body-file, my_id, [--comments-json for tests])` → 결정 POST/PATCH/REFUSE + (비 dry-run 시) gh 실행. 의존: gh api(내부) 또는 stub JSON.
- `render-terminal.py` — artifact + facts + status → 스캔가능 터미널 보고. publish 보고 **와** qg Final Summary 공용.

PR title은 artifact prose 파싱이 아니라 브랜치/커밋 subject에서 결정론 도출(스키마 변경이 publish를 조용히 깨뜨리지 않게).

## 5. 데이터 흐름

```
preflight  → kill switch(DEVBREW_QG_DISABLE_PUBLISH: 켜져도 로컬 gen+dry-run은 허용, network만 차단)
             gh auth status(부재→artifact-only loud degrade)
             pr-detect.sh, tier 판정(check-trivia.sh 재사용 + 변경파일수)
build      → build-pr-context.sh + diagram-facts.sh → 고정 context blob
             (Deep/large tier면 opus 빌더 dispatch 전 1회 cost 고지 — qg Deep 패턴)
generate   → Agent(pr-understanding-builder, blob inlined, model:opus) → artifact.md
             → .claude/quality-gates/<sid>/pr-understanding.md (git-ignored)
scan       → secret-scan.py (전체 payload, FAIL CLOSED) → hit이면 HARD-BLOCK(중단, artifact 보존)
preview    → render-terminal.py: STATUS 표 + 트리 + ASCII diagram + 본문(<details>펼침, mermaid→ASCII)
             + 정확성 경고(다이어그램/구조표/Testing grounding — §8) surface
             --dry-run이면 여기서 STOP
consent    → AskUserQuestion(매 실행): exact bytes 요약 + target URL + identity(login) + 비가역성 경고
             no-PR: 단일 informed consent(push N commits + 히스토리 노출 + PR 생성 base 고지)
publish    → PR있음: comment-upsert.py(id-scope, --paginate, 0→POST/1→PATCH/≥2→REFUSE)
             PR없음: publish-active sentinel 기록 → (동의시 git push) → gh pr create --body-file --base <default> --head <branch>
report     → render-terminal.py 최종 보고(무엇을 어디에·created/updated·bytes·scan PASS)
```

## 6. 콘텐츠 스키마

**결정론 envelope + 모델 저술 content** — 결정론은 헤딩·순서·placeholder·마커·transport에만. 콘텐츠·다이어그램·walkthrough는 모델(opus) 저술.

**메커니즘-중심 스키마(tier 2 기준):**

```markdown
<!-- pr-understanding:v1 tier=2 -->
## <imperative 한 줄 요약>                 # = PR title (Google CL 규칙)

**In one breath** — 2~3문장, 능력/변화 + 지금 왜. 파일명·diff 용어 금지.

**Before → After** — 행동 차분(비독자-대면):
| 축 | Before | After |
|---|---|---|
| 동작 | … | … |     # 실제 델타 있는 행만(성능/데이터모양/실패모드 등)

**지금 어떻게 동작하나** — [PRIMARY · 항상 펼침 · payload]
대표 연산 1개를 처음~끝까지, 주체를 이름으로 부르며 번호 단계로. 코드 0줄로 성립.

**구조 — 조각 & 계약:**
| 조각(파일) | 지금 역할 | 변경 | 계약(in→out / 불변식) |
|---|---|---|---|

<diagram — ≥2 노드 & ≥1 엣지일 때만, diagram-facts grounding>
```mermaid … ```                          # 터미널: 같은 facts에서 ASCII 파생
<details><summary>보조 경로 & 엣지케이스</summary> … </details>

**Testing** — 어떤 동작을 무엇으로 고정 / 사람이 재현하는 법. (실제 changed test 없으면 `_No tests in this PR._`)
**Risk & Rollout** — blast radius, 마이그레이션, 롤백, 지켜볼 것.
**Review focus** *(opt)* — 이해가 가장 load-bearing한 지점.
<details><summary>Glossary</summary> 살아남은 용어 풀이 — 있을 때만 </details>
```

**Tier — 문법 고정, 산출은 최소 floor(상한 아님; 영양가 있으면 모델이 확장):**

| Tier | 결정론 트리거 | 최소 렌더 |
|---|---|---|
| 0 trivia | check-trivia.sh = trivia | 한 줄 요약만 |
| 1 small | 변경 1 컴포넌트 | 요약 + Before→After + "어떻게 동작" 1문단 + Testing. diagram 없음 |
| 2 multi | ≥2 상호작용 컴포넌트 | 전체 스키마 + grounded diagram + trace 1개 |
| 3 large | ≥3 area (tuning knob) | 전체 + area당 trace + area index(`<details>` per area) |

**다이어그램 결정론(OQ5):** diagram-facts.sh가 nodes(changed files + 이웃)·edges(추가 import)를 의미이해 없이 추출 → 빌더는 **그 노드/엣지 어휘 안에서** 타입 선택(sequence/flow/component)+라벨. 렌더 타입은 PR 성격이 결정(런타임 경로→sequence, 재구조화→component graph, 데이터모양→before/after 표). 터미널 ASCII는 같은 facts에서 파생(단일 진실원 → drift 불가). **v1은 정적 import 그래프 한계를 loud 한 줄 고지**(동적 dispatch/DI/reflection 누락 가능), understand-anything 승격은 v2.

**plain-language(D5 lightness):** 주 lever는 강한 audience 페르소나("코드를 **안 보는** 유능한 동료에게 설명; 모든 문장이 코드 0줄로 성립; 미확장 acronym·jargon·filler 금지; raw diff hunk 붙이지 마"). **블로킹 linter 없음** — style은 모델 신뢰, 사람이 preview에서 확인.

## 7. 보안 모델

경량화되었지만 비가역 유출은 hard-block 유지. **secret-scan은 식별자가 아니라 값을 겨냥하게 retarget**(§8 감사 반영):

**secret-scan.py — 유일한 콘텐츠 hard-block, FAIL CLOSED:**
- (a) 알려진 **패턴** — AWS(`AKIA/ASIA`)·GitHub(`ghp_/gho_/ghs_/ghu_/github_pat_`)·Slack(`xox[baprs]-`)·Google(`AIza`)·Stripe(`sk_live/rk_live`)·PEM(`BEGIN … PRIVATE KEY`)·JWT(`eyJ`)·basic-auth-URL(`https://user:pass@`). generic 키워드 룰(`password|secret|token|api[_-]?key` + `:`/`=`)은 **독립 차단자가 아니라 RHS가 값-형태일 때만 발동** — 값-형태 = known-pattern OR 고엔트로피(b) OR 소스 quoted-value(c). 키워드는 context refinement이며, RHS가 저엔트로피 dictionary(타입명·식별자: `token: string`, `token: RequestHandler` 등)면 **길이 무관 미차단**(denylist enumeration은 타입명을 다 못 담으므로 폐기 — 값-형태 게이트가 load-bearing, R4). markdown 언랩·whitespace 정규화 선행.
- (b) **고엔트로피** — len≥16 & **Shannon ≥ 4.0(정확 상수, 근거 주석)** & source corpus substring(복사된 진짜 시크릿 포착; 지어낸 해시·저엔트로피 식별자는 미포착).
- (c) **따옴표 문자열 값** — 소스의 quoted value를 verbatim 재현 시.
- **식별자·경로·타입명·계약 시그니처는 명시 허용**(저엔트로피 vocabulary — 구조표·계약의 영양분).
- **source corpus 정의 = build-pr-context.sh blob**(diff + 변경파일 내용 + 커밋메시지 — 빌더가 본 바로 그 material; untracked/gitignored/HEAD 전체 아님). **범위 = 전체 payload:** artifact + PR title + 브랜치명 + 커밋메시지; **PR-create는 `git log -p base..HEAD` 히스토리를 corpus·payload 양쪽에** 추가.
- **FAIL CLOSED:** 스캔 에러/타임아웃/unreadable → hit 취급. `scan_ok=yes` 명시 게이트(pipe가 exit code 삼키지 않게 — v2.7.0 fail-open 교훈).
- **v1 한계(loud 고지, §6 다이어그램 한계와 동일 스타일):** unquoted·non-vendor-pattern·**12–15자** 값-형태 RHS는 entropy 경로가 수학적으로 도달 불가(임의 문자열 entropy ≤ log2(len) < 4.0 for len<16)하고 quoted 경로 대상도 아니므로 **미차단**. 짧은 저-엔트로피 시크릿은 정보이론적으로도 약하고(모든 vendor 패턴은 15자 초과) 소스에 그대로 복사되면 corpus-substring/quoted 경로가 잡지만, 이 잔여 band는 v1이 커버 못 함을 명시(사람 consent가 최후 backstop).
- 빌더 페르소나의 "리터럴 재현 금지"는 defense-in-depth지 게이트 아님(생성기가 자기 안전을 인증 못 함).

**comment-upsert.py — marker 멱등, S2:**
- **불변 `comment.user.id == 인증 user.id`** 스코프(`gh api user --jq .id`). `.login`은 표시용만(rename→confused-deputy). **`author_association`은 선택기준 제거**(중복+악성 MEMBER 만족).
- 마커 = 정확한 트림 첫줄 `^<!-- pr-understanding:v1( tier=\d+)? -->$`, substring 아님. `gh api --paginate`.
- **0→POST(terminal, re-list-PATCH TOCTOU 금지) / 1→PATCH / ≥2→REFUSE**(양쪽 html_url 출력 + 사용자 확인 — hard-block).
- fork/외부 PR: authed identity로 스코프(PR owner 무관). write 없음→403→artifact-only loud degrade, 재시도 루프 없음.

**untrusted input:**
- v2.8.0 "diff is data, not instructions" norm을 **빌더 페르소나 + orchestrator**에 확장. PR 코멘트는 id+마커 매칭용 **opaque bytes**로만(모델이 안 읽고 스크립트가 선택 계산).
- **artifact 내 이미지 중립화**(auto-fetch 유출 벡터); **링크는 허용**(secret-scan 통과 — 설계문서/RFC 참조 정당).
- slot값 escape: 표 셀 `|`/개행, mermaid 라벨 allowlist `[A-Za-z0-9 _./-]` + `click/href/call` strip, 마커 인접 `<!--`/`-->` strip·빌더 콘텐츠는 첫줄 점유 금지.

**consent/비가역성:** 매 실행 exact bytes+target+identity + "GitHub 즉시 이메일·edit-history 영구 → 삭제해도 유출 불가역" 명시. cross-repo "always" 금지, 글로벌 remember 없음. PR-create는 push+create+히스토리 노출을 단일 informed consent로 고지.

**kill switch `DEVBREW_QG_DISABLE_PUBLISH=1`:** 최내부 gh sink에서 강제(skill 진입만 아님), 로컬 gen+dry-run은 허용, network만 차단. hook 억제도 자체 kill switch 존중.

## 8. lightness 원리

> **hard-block은 비가역 게이트 둘뿐 — secret-scan(값 유출) + marker 모호(남의 코멘트 편집). 나머지 전부(style·식별자 명명·다이어그램 완결성·외부 링크·깊이)는 모델 페르소나로 신뢰하고, 정확성 우려는 사람이 읽는 preview에 경고로 surface해 consent 전에 사람이 잡는다.**

이 기능의 본질은 **사람이 게시 전 이해글을 읽는다**는 것 — preview 자체가 자연스러운 정확성 backstop이다. 자동-차단을 쌓으면 "사람이 안 읽는다"는 잘못된 가정이 된다.

**과억제였다가 경량화된 것 (사용자 감사 요청 결과):**

| 원안(과억제) | 부작용 | 경량화 |
|---|---|---|
| source-literal ≥20자 substring HARD-BLOCK | 구조표가 `authenticateUserWithToken`·`StripeWebhookHandler.ts`를 못 부름 | secret-scan을 **값만** 겨냥(§7); 식별자·경로 허용 |
| acronym 미확장→RED, prose내 code-fence→RED | "API"·1줄 시그니처로 게시 차단; "코드적 이해" 억제 | **블로킹 linter 삭제** → 페르소나 |
| diagram/structure teeth = publish 차단, ⊆changed-set | 이웃 노드(`db.py`) 차단; 노드 하나로 전체 publish 폭파 | diagram-facts가 이웃 포함; teeth 위반→**preview 경고**; "diff에 없는 NEW 파일 날조"만 플래그 |
| 임의 URL/이미지 금지 | 참조 링크 차단 | **이미지만** 중립화, **링크 허용** |
| Tier = 상한 | 작지만 풍부한 PR cram | tier = **최소 floor**, 모델 확장 |
| PR-create 2단계 consent | 이중 나그 | 단일 informed consent |

**preview에 surface되는 정확성 경고(차단 아님 — 사람이 consent에서 판단):**
- 다이어그램: mermaid 노드가 diagram-facts(이웃 포함)에 없음 → "possible hallucinated node: X".
- 구조표: NEW/changed로 표기된 파일이 changed-set에 없음 → "possible hallucinated file: X".
- Testing: 테스트 있다고 주장하나 changed test 파일 0 → "unverified testing claim".

## 9. 보고 UX

단일 진실원(artifact) → PR은 그대로(mermaid/`<details>` 네이티브), 터미널은 결정론 파생 렌더(mermaid→ASCII from facts, `<details>`→들여쓰기 펼침). 발산점 정확히 둘, 둘 다 같은 소스 변환 → 손으로 두 본문 안 씀.

**스캔가능 터미널 보고(render-terminal.py 공용):** 상단 고정폭 STATUS 표(정렬 컬럼, 산문 아님) + 트리(무엇을 어디에) + ≤~100 col + verdict 텍스트 토큰(PASS/FAIL/SKIP, color-only 금지) + progressive disclosure(요약=표, 세부는 `── heading ──` 아래).

예(publish dry-run):
```
── PR Understanding — dry-run ─────────────────────────
target   PR #123  origin/feature/qg-pr-publish → main
action   upsert sticky comment (marker pr-understanding:v1)
identity octocat (id 583231)
secret   scan PASS   (0 findings)
size     tier 2 · 4 files · diagram 4 nodes / 3 edges
notes    (accuracy) 0 warnings
────────────────────────────────────────────────────────
(미게시 — consent 대기)
```

**개선 표면 2개:** (a) qg Final Summary(현 얇은 2-bullet → STATUS 표+트리, render-terminal.py 재사용), (b) publish 터미널 보고(위, dry-run 미리보기 포함).

## 10. 에러 처리

- gh 부재/미인증 → **artifact-only loud degrade**(로컬 파일 작성+출력, 게시 skip). crash 금지.
- secret-scan hit / 스캔 에러 → **HARD-BLOCK**, finding 출력, artifact 보존(디버깅).
- marker ≥2 매치 → **REFUSE**, 양쪽 URL 출력, 사용자 disambiguate 요청. (0→POST는 terminal decision이라 같은 사용자가 빠르게 2회 트리거 시 duplicate marker 가능 → 다음 실행에서 REFUSE로 graceful degrade; race window 최소·인지된 트레이드오프.)
- fork write 없음 403 → artifact-only degrade, 재시도 루프 없음.
- diagram-facts 정적 import 한계 → loud 한 줄 고지(누락 가능), 계속.
- kill switch → 로컬 gen+dry-run 유지(loud "publish disabled — artifact-only"), network만 차단.
- 성공 시 artifact auto-delete, 실패 시 보존(§4.8 state 관례).

## 11. 테스트 전략

**결정론 tier(단위, repo root에서 실행):**
- `test_secret_scan` — **차단 teeth**(시크릿 fixture로 BLOCK 증명, header-satisfiable 함정 회피) + 패턴/엔트로피/따옴표값 catch + **식별자·경로 미차단**(회귀: 함수명/파일경로 통과) + FAIL CLOSED(에러→hit).
- `test_comment_upsert` — 0→POST / 1→PATCH / ≥2→REFUSE / id-scope(attacker 마커 미선택) / `--paginate` / `--dry-run` 무네트워크.
- `test_diagram_facts` — nodes(changed+이웃)·edges(추가 import) 추출; 이웃 노드 포함 확인.
- `test_build_pr_context` — 결정론 blob(git 없이 빌더가 받는 입력 재현).
- `test_render_terminal` — mermaid→ASCII parity(같은 facts) + STATUS 표 컬럼 정렬.
- `test_accuracy_warnings` — §8 안전망 3종 fixture 검증: 다이어그램 노드-불일치→"possible hallucinated node", 구조표 파일-불일치→"possible hallucinated file", 테스트 주장 미검증→"unverified testing claim". (hard-block 제거의 유일 안전망 — 반드시 이름 붙여 회귀.)
- `test_publish_degrade` — AC14: gh 부재 / fork-403 → artifact-only, retry loop 없음.
- `test_secret_scan_fp` — 오탐 금지 PASS: `token: string`(짧음) **AND ≥12자 타입명 `token: RequestHandler`** + 함수명/파일경로 — 길이 floor가 아니라 **값-형태(엔트로피) 게이트**가 통과시킴을 증명(mutation: 값-형태 게이트 제거 시 `token: RequestHandler` RED = teeth). 실제 값(`token = "ghp_…"` / 고엔트로피)은 BLOCK.
- `test_publish_dry_run_zero_network` — `--dry-run`에서 POST/PATCH/create 미발생.
- `test_publish_kill_switch` — `DEVBREW_QG_DISABLE_PUBLISH`가 network 차단·dry-run 허용.
- `test_qg_publish_skill_orchestration` — preflight→scan→preview→consent 경계 순서.
- `test_hook_publish_suppression` — post-tool-use.py가 publish sentinel 존재 시 `/qg` 재유도 억제.
- `test_pr_detect` — pr-detect.sh: OPEN / MERGED / CLOSED state + no-PR + head_pushed 판정 fixture(publish vs create 분기 입력).

**manual tier(V, e2e):** 서사 품질(비독자 이해), mermaid 정확성, 실제 test PR upsert/재-upsert 멱등, PR-create.

## 12. Files to Modify

**신규:**
- `plugins/quality-gates/commands/qg-publish.md`
- `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md`
- `plugins/quality-gates/agents/pr-understanding-builder.md` (`model: opus`)
- `plugins/quality-gates/scripts/build-pr-context.sh`
- `plugins/quality-gates/scripts/diagram-facts.sh`
- `plugins/quality-gates/scripts/secret-scan.py`
- `plugins/quality-gates/scripts/pr-detect.sh`
- `plugins/quality-gates/scripts/comment-upsert.py`
- `plugins/quality-gates/scripts/render-terminal.py`
- `plugins/quality-gates/tests/test_secret_scan.*`, `test_secret_scan_fp.*`, `test_comment_upsert.py`, `test_diagram_facts.sh`, `test_build_pr_context.sh`, `test_render_terminal.sh`, `test_accuracy_warnings.*`, `test_publish_dry_run_zero_network.sh`, `test_publish_kill_switch.py`, `test_publish_degrade.*`, `test_pr_detect.sh`, `test_qg_publish_skill_orchestration.sh`, `test_hook_publish_suppression.py`

**수정:**
- `plugins/quality-gates/.claude-plugin/plugin.json` — 2.8.0 → **2.9.0**, description 정직 갱신(로컬 게이트 **+** consent-gated publish surface).
- `plugins/quality-gates/CHANGELOG.md` — `## [2.9.0] — 2026-07-05` Added.
- `plugins/quality-gates/README.md` — Principles Instantiated(P21·untrusted-input·P17 consent·P18 bounded idempotency·pwn-request Law-2형 생성/게시 분리 — **"gate 아님" 명시**), Hooks Installed(hook 변경 + why), kill switch 인벤토리(`DEVBREW_QG_DISABLE_PUBLISH`), cost(skill variable + 빌더 opus), 구조 트리, **"deterministic envelope + model-authored content" 정직 문구**.
- `plugins/quality-gates/hooks/post-tool-use.py` — publish sentinel 확인해 `/qg` 재유도 억제(자체 kill switch 존중).
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — Final Summary(~L699)를 render-terminal.py 공용 STATUS 표+트리로. **allowed-tools Group 3에 `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/render-terminal.py:*)` 추가**(순수 렌더 스크립트, gh/network 없음 — AC2 불변식 무영향).
- `plugins/quality-gates/commands/qg.md` — Quick Reference에 `/qg-publish` cross-ref(선택).

## 13. Verification Plan

1. 신규/수정 결정론 테스트 전부 green(repo root에서 실행 — reference note). baseline 캡처 후 회귀 0 확인.
2. secret-scan·comment-upsert·diagram teeth는 **mutation으로 teeth 증명**(차단 문구 헤더-satisfiable 회피).
3. `/qg` self-dogfood로 이 브랜치 전체를 리뷰(security-reviewer + codex model-diversity 포함) — 보안 컨트롤이라 codex 독립리뷰 필수.
4. manual e2e: 실제 브랜치에 dry-run preview → test PR upsert → 재-upsert 멱등 → (PR 없는 브랜치) create.

## 14. devbrew 체크리스트

- [x] SemVer minor 2.8.0→2.9.0 + CHANGELOG `## [2.9.0]` Added.
- [x] README "Principles Instantiated" + plugin.json description 정직(로컬 게이트 + publish surface; "gate 아님"; "deterministic envelope").
- [x] cost_class: skill `variable`; 빌더 **매 tier opus 고정**(D4) — Deep-tier만 upfront cost 고지, small-tier는 diff가 작아 비용 bounded + `/qg-publish`가 manual·non-auto-chained(NG5)라 명시적 실행 자체가 수용(의도적, oversight 아님).
- [x] 전용 kill switch `DEVBREW_QG_DISABLE_PUBLISH`(최내부 sink 강제, fail-closed, README 인벤토리) — 기존 `DEVBREW_QG_DISABLE_*` family(RUNTIME_SANDBOX/BRANCH_WORKTREE/SPEC_CONFORMANCE)와 정합.
- [x] scoped agent(빌더 allowedTools/disallowedTools 명시) + command 짧은 명령형 + skill 동명사(`publishing-pr-understanding`).
- [x] 마커/보안 로직 pure 함수 추출 → gh-stub·dry-run 테스트.
- [x] publish는 runtime 샌드박스 밖; `/qg` 뒤 auto-chain 금지.
- [x] hook 공존: publish의 `gh pr create`가 qg hook 재유도 안 하게 sentinel; "왜 hook인가" 문서화.

## 15. Acceptance Criteria

- **AC1** — 빌더는 **파일시스템 tool 0개**(Read/Grep/Glob/Bash/git/gh/network 전부 부재; disallowedTools 명시) — 유일 입력은 inlined build-pr-context.sh blob(단일 통제 채널; .env·리포 밖 접근 물리 불가). `model: opus` 고정. **defense-in-depth(구현 리뷰 반영):** `allowedTools: []`가 런타임에서 inherit-all로 오독될 최악의 경우에도 봉쇄되도록 disallowedTools에 FS/exec 8종 + 네트워크(WebFetch/WebSearch) + 서브에이전트 spawn(Agent)까지 명시. 회귀: 빌더 frontmatter에 11종 deny + `allowedTools: []` + `model: opus` 부재 grep 락(18 assertions).
- **AC2** — **`quality-pipeline/SKILL.md` allowed-tools에 gh/network 도구 부재**(grep 회귀 락 — 이 불변식만 정확히 좁혀 주장). gh는 publish skill에만. (주의: `commands/qg.md`의 기존 unscoped `"Bash"`는 이 설계 이전부터 존재 — `/qg` command 자체의 gh 부재는 주장하지 않음; qg.md Bash 협소화는 out-of-scope 후속.)
- **AC3** — 게시 본문에 qg findings/"무엇을 고쳤나" 미포함(순수 이해).
- **AC4** — 스키마 = 메커니즘-중심(In one breath / Before→After / 지금 어떻게 동작하나[펼침] / 구조·계약표 / 조건부 diagram / Testing / Risk&Rollout / Review focus). tier=floor.
- **AC5** — diagram은 ≥2 노드 & ≥1 엣지일 때만; diagram-facts(이웃 포함) grounding. §8 안전망 3종(노드-불일치·구조표 파일-불일치·미검증 Testing 주장)은 **preview 경고**(publish 차단 아님)이며 각각 이름 붙은 fixture 테스트로 회귀(§11 `test_accuracy_warnings`).
- **AC6** — secret-scan: 값(known-pattern / 고엔트로피≥4.0-in-corpus / 소스 quoted-value) HARD-BLOCK; generic 키워드 룰은 RHS가 값-형태일 때만 발동. **식별자·경로·계약 시그니처·타입명(`token: string` 및 ≥12자 `token: RequestHandler`) 미차단**(저엔트로피 dictionary RHS는 길이 무관 통과 — 값-형태 게이트가 load-bearing); corpus=build-pr-context.sh blob; 범위=전체 payload(+PR-create 히스토리); FAIL CLOSED(`scan_ok=yes` 게이트).
- **AC7** — marker upsert: `comment.user.id` 스코프, author_association 미사용, `--paginate`, 0→POST/1→PATCH/≥2→REFUSE.
- **AC8** — consent 매 실행 exact bytes+target+identity+비가역성; 글로벌 remember/always 없음; PR-create는 push+create 단일 informed consent.
- **AC9** — `--dry-run`에서 네트워크 mutation 0(POST/PATCH/create/push 미발생).
- **AC10** — `DEVBREW_QG_DISABLE_PUBLISH=1`: network 차단, 로컬 gen+dry-run 허용, 최내부 sink 강제; hook 억제도 존중.
- **AC11** — post-tool-use.py: publish sentinel 존재 시 `/qg` 재유도 억제.
- **AC12** — 블로킹 style linter 없음(plain-language는 페르소나); artifact 이미지 중립화·링크 허용.
- **AC13** — 터미널 보고 = STATUS 표+트리+ASCII diagram; qg Final Summary도 render-terminal.py 공용.
- **AC14** — gh 부재/fork-403 → artifact-only loud degrade(crash 금지).
- **AC15** — plugin.json 2.9.0 + CHANGELOG + README(정직 문구·kill switch 인벤토리·"gate 아님").

## 16. Rejected Alternatives

- 무조건 직접 게시(게이트/opt-in 없음) → §4 steelman(생성/게시 분리, 테스트가능성, PR-부재 충돌) → 하이브리드+별도 skill.
- 게시 본문에 findings fold-in → 관심사분리(LD6) + 시크릿 노출면 축소.
- `gh pr review` 게시 → 비멱등, 자기 PR approve 불가.
- inline 라인 코멘트 v1 → plain gh CLI 취약(cli/cli#12396).
- **별도 pr-publish 플러그인**(A 권장) → 고려했으나 사용자가 quality-gates 내 선택(gh 격리+README 정직으로 Review gate 순수성 보존).
- **패턴-only secret scan** → 비가역 sink엔 불충분 → source-literal(값) + 엔트로피 belt.
- **source-literal ≥20자 광역 차단 / acronym·code-fence 블로킹 linter / diagram teeth publish-차단 / 임의 URL 금지** → 기능 억제(§8) → 값-겨냥 스캔 + 페르소나 + preview 경고로 경량화.
- **author_association 마커 스코프** → 중복+위험 → `comment.user.id`.
- 전용 bot/PAT identity → v1 복잡도 → 사용자 gh 토큰(문서화 opt-in PAT).

## 17. Open Questions

- OQ-A (v2): understand-anything 심볼/모듈 그래프로 diagram-facts 승격(정적 import 한계 해소). v1은 grep + loud 고지.
- OQ-B (v2): 기계-파싱 verdict 블록(CI key). v1 제외 확정.
- OQ-C: `/qg-publish` 커맨드명 — 사용자 조정 여지(대안 `/pr-publish`). 잠정 `/qg-publish`(qg family).

## Handoff Context

writing-plans가 이 문서 밖 대화를 재구성하지 않도록, 인터뷰·리뷰에서 확정된 맥락을 패키징한다.

**TL;DR** — quality-gates에 PR-이해 본문 생성(read-only opus 빌더, blob-only) + consent·시크릿-가드 멱등 게시(별도 skill, gh 격리) 추가. 결정론은 비가역 게이트 2개(secret-scan 값-차단 / marker 모호-REFUSE)에만; 나머지는 페르소나+preview 경고.

**인터뷰 이후 바뀐 결정(재논쟁 금지):**
- 배치: 별도 플러그인 재고(리뷰 A) → **quality-gates 내 확정**(gh는 publish skill에만).
- 스키마: brief LD5 델타-중심 → **메커니즘-중심**(리뷰 C; LD7>LD5).
- marker 스코프: `author_association` → **불변 `comment.user.id`**(리뷰 B; association은 악성 MEMBER도 만족).
- 시크릿 belt: source-literal 광역(≥20자) → **값-겨냥**(식별자·경로·계약 시그니처 허용; 광역은 구조표를 gut).
- 게이트: acronym/code-fence/diagram-teeth-block 등 → **경량화**(hard-block 2개만, §8).
- 빌더 입력: Read/Grep/Glob → **blob-only**(FS tool 0개; filter 경계 우회 차단, 리뷰 round-1).

**Deferred to plan(writing-plans가 정할 것):**
- 2단계 task 분할 권장: **① 생성(build~scan~preview)** 먼저 구현+리뷰+머지 → **② 게시(consent~publish~report)**. 게시(권한 소비) 전 시크릿-스캔·diagram grounding 안전 로직을 독립 리뷰.
- secret-scan 정확 상수(entropy 4.0), corpus=blob, generic 패턴 값-형태+denylist — §7 정의대로.
- render-terminal.py를 Final Summary와 publish 보고가 공유(§9/§12) — quality-pipeline allowed-tools에 배선. **주의: Final Summary 리팩터는 always-on `/qg` 출력 변경이므로, publish opt-in과 분리해 이른 독립-리뷰 micro-task로 시퀀싱**(publish 롤아웃에 core `/qg` 변경을 묶지 말 것).
- `/qg-publish` 커맨드명 미확정(OQ-C, `/pr-publish` 대안).

**Implicit context:** qg 기존 reviewer는 read-only agent + orchestrator-holds-capability 패턴(README Law-2). 이 설계는 그 위에 publish=pwn-request 물리분리를 더함. (무관 메모: spec-distill review-lock의 session-id-split 버그는 별도 handoff로 분리 — 이 작업과 무관.)

## 18. Metadata

- **author:** brainstorming (spec-distill 흐름), 3-관점 비판적 subagent 리뷰(devbrew 아키텍처 / 보안 위협모델 / 이해충분성) 종합.
- **reviews consumed:** A(builder git 구멍·injection-laundering·별도플러그인·orchestrator 캡슐화), B(source-literal belt·id-scope marker·untrusted input·push-consent), C(메커니즘-중심 스키마·tier·diagram grounding+teeth·plain-language·report UX).
- **다음 단계:** `spec-distill:spec-reviewer`(Law 2 분리 리뷰) → `superpowers:writing-plans` → `subagent-driven-development`(worktree `feature/qg-pr-publish`).
- **구현 규율:** 매 Edit는 워크트리 절대경로 명시; subagent-driven 엄격 순차(투기 dispatch 금지); "approved"는 리뷰 verdict 후에만 기록.
