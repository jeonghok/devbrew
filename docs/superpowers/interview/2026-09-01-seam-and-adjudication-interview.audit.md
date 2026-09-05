---
type: framing-audit
date: 2026-09-01
seed: 2026-09-01-seam-and-adjudication-interview.md
---

# framing audit — 이음매 강제 · 판정 지형

압축이 무엇을 떨어뜨렸는지 남기는 파일. append-only.

## 1. 원문

### 라운드 1 — 사용자 요청 (verbatim)

```
/spec-distill:framing-requests /Users/jeonghokim/Downloads/devbrew/docs/audits/2026-08-27-cross-skill-seam-handoff.md <- 내 의도가 아닌 에이전트가 감사한 내용이다 바로 믿지 말고 같이 결정해나가자 그리고 대상 부분이 더 있는지 탐색이 필요, 워크트리에서 구현 진행할거야
```

**사용자가 지목한 자료** (사용자 저작이 아님 — 에이전트 감사 산출물, 사용자가 명시적으로
「바로 믿지 말라」고 지위를 낮춘 것):

- `docs/audits/2026-08-27-cross-skill-seam-handoff.md` (363줄, 미커밋)
- `docs/audits/2026-08-27-adjudication-topology-handoff.md` (형제 문서, 미커밋)

**원문에서 직접 읽히는 것 넷:**

1. 감사 결과는 **입력이지 전제가 아니다** — 검증 후 사용자와 함께 결정한다.
2. **범위 탐색이 필요하다** — 감사가 다룬 것 말고 더 있는지.
3. **워크트리에서 구현**한다.
4. **같이 결정해나간다** — framing 단계에서 사용자가 결정 주체.

### 라운드 2 — 사용자 추가 발화 (verbatim)

게이트 답변으로 온 것 (선택지 라벨이 아니라 사용자가 직접 쓴 문장):

```
4 가능하면 너무 문제되는건 억지로 관철하기 보다 기능을 걷어내자, 추가로 다음 내용도 추가 발생 brief 분리 리뷰 zero tool 격리 probe 자산이 이 레포에 없고(docs/audit 자제 부재), 에이전트 선언(tools)와 하네스 목록 (all tools)이 어긋납니다.
```

```
다른 세션에 형재 작업 하는 세션이 있어
```

```
반드시 필요한 부분은 소통해
```

```
둘다 워크트리로 작업할거야
```

**게이트 선택 (라벨)**:
- 범위 = ④ 「먼저 측정 — probe 3건」 + **삭제 우선 성향**(위 첫 발화)
- M1~M4 = 「확정 유지」
- 자동 발행 = 「아직 모르겠다 — 인터뷰에서」

### 라운드 3 — 게이트 선택 (라벨)

측정 착수 후 띄운 두 번째 게이트의 사용자 답:

- **세션 분업 = 「이음매(seam)만」** — 판정 지형은 다른 세션에 넘긴다
- **probe 순서 = 「세 건 전부 병렬로」**

〔이 절은 codex 억제 리뷰 1라운드가 **누락을 적발해서** 추가됐다. 그 라운드는 이 두 답을
못 본 상태로 돌았고, 그래서 「다루는 것은 이음매 강제 하나다」와 「두 세션의 사용자 게이트가
독립적으로 같은 경계를 냈다」를 **근거 없는 단정**으로 판정했다. 판정은 그 시점 재료에 대해
옳았다 — 재료가 불완전했다. **재실행은 조건이 바뀐 실행이므로 그 사실과 함께 읽어야 한다.**〕


## 2. 레포 확인 — 감사 주장 대조 (2026-09-01, HEAD `094ecbc`)

감사는 HEAD `983d7d7` · 설치본 spec-distill `0.35.3` 기준. **현재는 HEAD `094ecbc` ·
spec-distill `0.47.0` · quality-gates `5.1.0` · project-init `3.0.0`** 이다. 그 사이
PR #134(훅 쓰기-경로 우회) · #135(request-framing) · #136(brief 재구조화) 가 머지됐다.

### 2.1 여전히 참인 주장 (재확인됨)

| 감사 주장 | 현재 HEAD 확인 |
|---|---|
| B0 — zero-tool probe 파일이 플러그인 배포 단위 밖 | **참.** `find` 결과 `./docs/audits/2026-07-27-spec-distill-zero-tool-probe.md` 한 곳뿐, 설치본 `0.47.0` 캐시에 없음. `reviewing-brief/SKILL.md:107` 이 여전히 그 cwd-상대 경로를 fail-closed 선결조건으로 씀 (라인 번호까지 동일) |
| A1 — `blocks()` 프로덕션 호출 0 | **관측은 참, 감사의 결론은 거짓.** 히트는 `adjudication.py:101` + `merge_brief_review.py:295` 주석뿐이 맞다. 그러나 그 `:101` 은 **`_degraded()` 가 `blocks()` 를 첫 항으로 호출하는 자리**이고, `_degraded()` → `report()["degraded"]` → **프로덕션 호출자 3개**(`synthesize_findings.py:561` · `synthesize_artifact_findings.py:211` · `merge_review.py:558`). 즉 **`blocks()` 는 내부 하중을 지고 있고 「배선이 존재하지 않는다」는 감사 문면은 틀렸다.** 없는 것은 함수가 아니라 **「차단으로 행동하는 외부 소비자」**다. 그 docstring 이 이미 못 박았다 — *"무조건 True 로 만들면 … 화석이 아니라 계약이다."* 〔**경위**: 이 세션이 grep 0건에서 잘못 추론했고 세션 `d21082ae` 가 반증, 이 세션이 코드를 직접 읽어 수용〕 |
| A2 — `surfaced()` 호출 0 | **참.** 정의 `adjudication.py:136`, 호출처 전무 |
| A3 — `absorbed()`·`reject()` 호출 0 | **참, 그리고 감사가 말한 것보다 나쁘다.** 정의 `:55`·`:47` 만 존재. 문제는 「안 쓰인다」가 아니라 **`report()["counts"]` 가 `rejected`·`absorbed` 를 계속 렌더한다**는 것(`adjudication.py:124`·`:126`)이다 — 호출자가 없으니 **항상 0**이고, 읽는 쪽은 「기각된 항목이 없었다」는 **사실 주장**으로 읽는다. 이 리포 자신의 규칙(「침묵과 0 은 다른 사실이다」)이 회계 모듈 **안에서** 깨져 있다. 〔세션 `d21082ae` 발견, 이 세션이 `:121-133` 을 읽어 확인. **소유는 저쪽 범위**〕 |
| B2 — `conducting-interview/SKILL.md` 에 `reviewing-brief` 0회 | **참.** 히트는 `references/finishing.md` 3곳뿐 |
| B3 — 핸드오프 인자 3개가 셸 변수 | **참.** `finishing.md:95-97` 이 대입, `:101` 이 별개 블록에서 `$PAYLOAD $CODEX_DIR_YAML $CODEX_FID_YAML` 로 호출 |
| B5 — `check_brief.py` 에 리뷰 실행 여부 검사 없음 | **참.** `brief_review_stage`·`brief_critic_rounds` grep 0건 |
| §4.2 — `qg.md` 의 「제어가 돌아오면」 픽션 | **참.** `qg.md:75` 에 그대로 존재 |
| §4.4 — `quality-pipeline` `allowed-tools` 에 `Skill` 없음 | **참** (frontmatter `:12` 이하) |

### 2.2 감사 이후 변한 것 — 감사가 낡은 자리

| 감사 서술 | 현재 사실 | 영향 |
|---|---|---|
| §3.2 B1 표가 `spec-write-validator.py`(PostToolUse) · `pending-review-reminder.py`(UserPromptSubmit) 를 근거로 「훅 커버리지 비대칭」을 세움 | **두 훅 모두 삭제됨** (`e3f62d6`). `plugins/spec-distill/hooks/` 에 남은 것은 `hooks.json` · `review-dispatch.py` · `session-end-cleanup.py` 셋. `hooks.json` 이벤트는 **Stop · SessionEnd 둘뿐** | B1 표의 5행 중 4행이 근거를 잃음. 「Stop 훅이 발견·구조검증을 흡수」(`cda4355`) 했으므로 비대칭의 **모양이 달라짐** — 없어진 게 아니라 자리가 옮겨짐. 재작성 필요 |
| §4.1 「이음매 19개」 중 ②훅 텍스트 주입 2건에 `pending-review-reminder.py:123`(additionalContext) 포함 | 그 파일 없음 | 이음매 전수표의 계수가 틀림 |
| §1 「설치본 `spec-distill 0.35.3` = 리포 버전」 | 리포 `0.47.0` | 감사가 읽은 설치본은 12개 마이너 뒤 |
| 형제 문서 §1 「서브에이전트 18개 / 처분 앵커 18줄」 | **20개.** raw grep 25줄 = 20 dispatch 앵커 + CHANGELOG 4 + 테스트 락 1(`test_seed_agents.sh:29`). 감사 인용 색인이 「CHANGELOG 4줄 제외」를 명시했으므로 비교 대상은 20 | 누락은 **2자리**(`seed-critic`·`seed-readback`, PR #135). 파생 수치도 바뀐다 — 회계 밖 직행 12/18 → **14/20**(새 둘 다 `consumer=human · fail-open`). 〔**정정 경위**: 이 세션이 처음 「25줄 → 7자리 누락」이라 적었다. 세션 `d21082ae` 가 독립 계수로 반증했고 이 세션이 재확인해 수용했다. 원래 수치를 남기는 이유는 하류가 존재하지 않는 5자리를 찾지 않게 하기 위해서다〕 |
| quality-gates 버전 `4.3.5` | `5.1.0` (5.0.0 BREAKING — `files.md` scope 폐기, PostToolUse 세션 트래커 삭제) | §4 의 qg 훅 목록이 낡음 |

### 2.3 아직 확인하지 않은 감사 주장

- §2.2 A4·A5 (`synthesize_artifact_findings.py` 반쪽 회계) — 라인 대조 미실시
- §2.2 A6 (`smoke-workflow.js:11` 의 `disclosure=sentinelPath` 가 CLI 인자명) — 미확인
- §2.2 A7 (`report()["counts"]` 에 `unknown` 없음) — 미확인
- 형제 문서 §2 (codex 단독 의존 재비판 2건 사망) — `merge_review.py:508` 미대조
- §7 probe 3건 — 전부 미측정 상태 그대로


## 3. 측정 — zero-tool 격리 (2026-09-01, HEAD `094ecbc`)

**발단**: 사용자가 「에이전트 선언(tools)와 하네스 목록(all tools)이 어긋난다」고 직접 관찰.

**관측된 어긋남**: 이 세션의 하니스 agent 목록이 `tools: []` 로 선언된 넷
(`seed-critic`·`seed-readback`·`brief-critic`·`brief-readback`)을 `(Tools: All tools)` 로 표시한다.
`tools: Read, Grep, Glob, WebSearch, WebFetch` 인 형제들(`spec-reviewer`·`brief-direction-reviewer`)은
정확히 그대로 표시된다.

**측정 방법**: 두 에이전트를 실제 dispatch 해서 ① 도구 열거 ② Write 시도 ③ Read 시도를 시켰다.
양성 대조를 붙였다 — 계측기 자체가 고장 났는지 판별하기 위해.

| | 선언 | 하니스 표시 | 실측 도구 | Write | Read |
|---|---|---|---|---|---|
| `spec-reviewer` (**양성 대조**) | `Read, Grep, Glob, WebSearch, WebFetch` | 같음 | 정확히 그 5개 | 부재 (시도 안 함) | **성공** — `# CLAUDE.md` 회수 |
| `seed-critic` (**피검체**) | `tools: []` | **All tools** | **0개** | 없음 | 없음 |

피검체 관측 원문: *"호출할 도구가 하나도 주어지지 않았다 … 도구 호출 0회, 거부 메시지 0건,
사용 가능 도구 0개."* 첫 응답이 "Read 를 시도해 보겠습니다"에서 끊긴 것은 거부가 아니라
**호출 블록을 생성하지 못한 채 턴이 끝난 것**이라고 재질문에서 확정했다.

**판정 — `tools: []` 는 fail-closed 로 실제 집행된다.** probe 문서
(`docs/audits/2026-07-27-spec-distill-zero-tool-probe.md:121`)의 `**분기 판정:** ZERO_TOOL_OK` 는
**참이고, 그 위에 세운 「충실도 hard gate」의 전제는 무너지지 않았다.**

**틀린 것은 하니스 agent 목록의 표시다.** 빈 allowlist 가 「제한 없음」으로 렌더된다.

**조사하지 않은 것**:
- 나머지 셋(`seed-readback`·`brief-critic`·`brief-readback`)은 같은 선언이지만 **개별 측정하지 않았다.**
- 표시 오류의 **원인**(하니스 렌더 버그인지, 빈 배열의 다른 의미인지)은 재지 않았다.
- 이 결과가 **다른 하니스 버전·다른 실행 경로**에서도 같은지 재지 않았다. 측정은 이 세션 1회.

**부수 관측 (별개 결함 후보)**: 피검체가 *"지금 상태로 비평을 생산하면 전부 날조가 된다"* 고 적었다.
`seed-critic` 은 도구가 없으므로 `${BLOB}` 인라인이 실패하면 **아무 근거 없이 비평을 지어낼 수 있다.**
`framing-requests` 의 조립 블록은 `blob_rc != 0` 이면 dispatch 자체를 막지만, **인라인이 부분적으로
비는 경우**(변수는 있는데 내용이 잘림)에 대한 가드는 확인하지 않았다.

## 4. 동시 세션 — 분업

세션 `d21082ae` 가 형제 문서(`2026-08-27-adjudication-topology-handoff.md`)로 **같은 요청 문장의
같은 skill** 을 돌리고 있다(`docs/superpowers/interview/2026-09-01-adjudication-topology-interview.audit.md`).
사용자가 「반드시 필요한 부분은 소통해」·「둘 다 워크트리로 작업할거야」라고 지시.

그쪽이 독립 도달한 것 중 이 세션에 없는 것:
- **V3 — 「재비판자」가 두 역할을 한 이름에 묶고 있다.** Type A(findings 판정: `adversarial`·
  `artifact-adversarial`·`audit-refuter` — 1차 산출을 입력받아 confirm/downgrade/reject) 대
  Type B(독립 병렬 + 보수 병합: codex — 프롬프트 빌더 어디에도 Claude findings 주입이 없음, grep 0건).
  **M4 「재비판 서브에이전트 제거」의 대상 정의가 이 구분에 달려 있다.**

## 5. 경계 확정 — 두 세션의 분업 (라운드 3)

두 세션의 사용자 게이트가 **독립적으로 같은 경계를 냈다.** 이 세션 게이트 = 「이음매(seam)만」,
세션 `d21082ae` 게이트 = 「판정 지형만 — 형제는 참조만」. 협상이 아니라 양쪽 사용자 답이 일치했다.

| | 이 세션 (`31c16418`) — **이음매 강제** | 세션 `d21082ae` — **판정 지형** |
|---|---|---|
| 워크트리 | `.claude/worktrees/seam-enforcement` | `.claude/worktrees/adjudication-topology` |
| 항목 | D1 (이음매 강제를 어디까지) · D3 (리뷰 미실행 감지) · F1 (zero-tool probe 배포 결함) · F2 (`finishing.md:95-101` 셸 변수 인자 + `$AUDIT` 누락) · `qg.md:75` 「제어가 돌아오면」 픽션 · 훅 커버리지 비대칭 재작성 | M1~M4 재도출 · `shared/adjudication/` 전체 · `blocks()`/`surfaced()`/`reject()`/`absorbed()` 죽은 표면 (=D2/T5) · F3 (`synthesize_artifact_findings.py:211/:235`) · 처분 앵커 계약 · dispatch 20자리 · codex 종속 |

**충돌 지점 하나 — `review-dispatch.py`.** 그 훅의 `decision:"block"` 두 자리(`:599`·`:752`)는
이 세션의 D1 이 「유일하게 검증된 메커니즘」이라 부른 바로 그것이고, 저쪽은 그 자리의 **회계**만
건드린다(강제 범위·발동 조건은 안 건드림). **이 세션이 D1 에서 그 훅을 확장하기로 하면 즉시
통지**하기로 했다. 머지 순서는 먼저 머지되는 쪽에 다른 쪽이 **merge 로** 따라간다(이 리포는 rebase 를 쓰지 않는다).

**D2/T5 의 소유권은 저쪽이다.** 이 세션의 D1 결정이 `blocks()` 술어의 *의미*에 영향을 주면
결정만 넘긴다 — 파일은 안 만진다.

## 6. probe 3건 착수 (라운드 3)

사용자 게이트 = 「세 건 전부 병렬로」. 감사 §7 이 미측정으로 남긴 셋이고, **§3 의 zero-tool
측정은 이 셋 중 어느 것도 아니다** — 그것은 *agent frontmatter* 층이었고 이 셋은 *skill 층·훅 층*이다.

| # | 재는 것 | 걸려 있는 결정 |
|---|---|---|
| P1 | skill→skill 전이가 실제 `Skill` 도구 호출로 변환되는가 (+ `user-invocable: false` 호출 가능성, 네임스페이스 없는 호출 resolve) | 감사 §4.4 의 결론이 「구조적 불가능」인지 「모델 재량」인지 |
| P2 | skill 계층 `allowed-tools` 가 집행되는가 | 같은 항목. 인접 사실 둘은 확정: **커맨드 계층은 집행 0**(2026-08-22 실측, `CLAUDE.md:42`), **agent 계층은 집행됨**(이 세션 §3) |
| P3 | 훅 `systemMessage` 가 모델 컨텍스트에 닿는가 (vs `additionalContext`, 이벤트별 차이) | **가장 많은 결정.** `project-init` 의 전 강제력 + qg 의 유일한 「다음 스킬 지목」 채널(`post-tool-use.py:85-92`)이 여기 걸림. 리포가 자기모순 상태 — `spec-distill/CHANGELOG.md:3253` 은 「닿지 않는다」, 현재 코드 8자리는 그 채널만 씀 |

셋 다 **양성 대조 의무**를 걸었다. 이 리포의 기록: *"양성 대조 없이는 RED 도 증거가 아니다."*

## 7. 이 세션 범위의 근거 확정 (라운드 3, probe 대기 중)

### 7.1 D3 — 근거 파일이 바뀌었다 (결론은 그대로 참)

감사 §3.2 는 「brief 는 arm 대상이 아니다」의 근거로 `spec-write-validator.py:53` 을 들었다.
**그 파일은 삭제됐다**(`e3f62d6`). 같은 사실이 지금은 다른 자리에 있다:

- `plugins/spec-distill/scripts/arm_ledger.py:41` — `PREFIX = "docs/superpowers/specs/"`
- `:64-71` `canonical_key(raw_path)` = `raw_path.find(PREFIX)` **substring 판정** — 스코프 밖이면 `None`
- `plugins/spec-distill/scripts/discover_candidates.py:22`·`:94` 가 그 `canonical_key` 로 판정

**따라서 `docs/superpowers/interview/` 는 Stop 훅의 발견 스코프에 원천적으로 못 들어간다.**
훅이 재편(`cda4355` 발견·구조검증 흡수)된 뒤에도 비대칭은 남아 있고, **자리만 옮겼다.**

이것이 D3(리뷰 미실행 감지)의 층 문제를 정한다: `check_brief.py` 는 자기 불변식
(`:25-26` "brief 파일만 읽는다")으로 감지를 금지하고, 훅 층은 PREFIX 로 brief 를 배제한다.
**두 층 다 닫혀 있다** — 감지를 원하면 세 번째 층이거나, 둘 중 하나의 불변식을 바꿔야 한다.

### 7.2 F2 — 결함이 감사가 안 것보다 하나 더 많다 (셋)

| # | 결함 | 근거 |
|---|---|---|
| 1 | 셸 변수가 **별개 펜스**에서 소멸 | `finishing.md:92-98`(bash 펜스) → `:100-102`(언어태그 없는 별개 펜스). 자기 반증: `reviewing-brief/SKILL.md:97-99` *"Bash 도구는 호출마다 새 셸 … 변수·export 는 소멸합니다(실측)"* |
| 2 | `PAYLOAD` 에 **자리표 박제** | `finishing.md:95` — `PAYLOAD="docs/superpowers/interview/<file>"`. `framing-requests` 가 자기 블록에서 경고하는 것과 같은 클래스 |
| 3 | **인자 개수 불일치** — 호출자 3, 수신자 4 | `finishing.md:101` = `$PAYLOAD $CODEX_DIR_YAML $CODEX_FID_YAML`. `reviewing-brief/SKILL.md:62` = 넷(**`$AUDIT` 포함**)을 "호출자가 진입 시점에 이미 쥐고 넘기는 값"이라 명시 |

3번은 v0.47.0 이 **빌더 쪽에서** 고쳤다 — `build_brief_bundle.py` 가 조립 전에
`check_brief.resolve_audit(payload)` 로 sidecar 를 스스로 구해 인자와 대조하고 다르면 rc 2.
**그런데 `SKILL.md:62` 의 산문은 여전히 「호출자가 넘긴다」고 적는다** — 코드와 문서가 갈렸다.
F2 를 고칠 때 이 산문도 같이 봐야 한다(안 그러면 다음 사람이 없는 계약을 복원한다).

## 8. P3 실측 완료 — 훅 채널 배달지 (2026-09-01, `claude 2.1.252`)

**판정: `systemMessage` 는 모델 컨텍스트에 도달하지 않는다.** 8회 실행 · 4개 이벤트 ·
**서로 다른 랜덤 카나리 14개 중 0개** 도달. 같은 실행 안에서 `hookSpecificOutput.additionalContext`
는 **8/8**, Stop 의 `decision:"block" + reason` 은 **7/7** 도달 — 계측기가 살아 있는 상태의 음성이다.

| 이벤트 | `systemMessage` | `additionalContext` | `decision:block+reason` | stderr+`exit 0` |
|---|---|---|---|---|
| `SessionStart` | **0/4** | **3/3 닿음** | 해당 없음 | **0/1** |
| `UserPromptSubmit` | **0/3** | **2/2 닿음** | 해당 없음 | **0/1** |
| `PostToolUse`(Read) | **0/2** | **1/1 닿음** | 해당 없음 | **0/1** |
| `PostToolUse`(Bash) | **0/1** | **1/1 닿음** | 해당 없음 | 미측정 |
| `Stop` | **0/4** | 1/1 닿음 — **단 폭주(§8.2)** | **7/7 닿음** | 미측정 |

**메커니즘도 관측됐다** — `systemMessage` 는 `{"type":"system","subtype":"informational"}` 라는
**클라이언트 렌더 이벤트**로 나가고 어떤 `user`/`assistant` 메시지에도 안 들어간다.
`decision:block+reason` 은 진짜 `user` 메시지(`"Stop hook feedback:\n<reason>"`)로 등장한다.

`plugins/spec-distill/CHANGELOG.md:3253` 의 과거 정정(*"systemMessage 는 user transcript 표시
전용"*)이 **2.1.252 에서 그대로 참이고, 그때 도입했던 `additionalContext` 배선을 전부 삭제한 것은 회귀다.**

### 8.1 리포에 대한 귀결

| 자리 | 채널 | 판정 |
|---|---|---|
| `quality-gates/hooks/post-tool-use.py:85-92` | PostToolUse(Bash), systemMessage 단독 | **모델에 안 닿는다.** *"You MUST now … `Skill("quality-gates:quality-pipeline")`"* 는 모델에게 장식. 사람은 transcript 에서 본다 |
| `project-init/hooks/post-tool-use.py:212` | PostToolUse(Bash), systemMessage **유일 출력** | **모델에 안 닿는다.** 이 플러그인의 훅 강제력은 사람이 읽는 경고가 전부 |
| `quality-gates/hooks/session-start-advisor.py:149-161` | SessionStart, **stderr + rc 0** | **모델에 안 닿는다** |
| `spec-distill/hooks/review-dispatch.py:598-601`·`751-754` | Stop, `decision:block+reason` **+** systemMessage | **정상.** reason 이 강제력을 지고 systemMessage 는 transcript 흔적 |
| `review-dispatch.py:337`·`381`·`463`·`647` | Stop, systemMessage 단독 (degrade advisory) | **모델에 안 닿는다** — 코드 주석이 「사용자가 알게 되는 것이 목적」이라 밝히므로 **의도대로**. 다만 그 경로에서 모델 쪽으로는 완전히 침묵한다 |

**감사 §0 의 결론은 실측으로 강화된다** — 턴 경계를 넘는 강제는 Stop 훅 `decision:"block"` 하나뿐이고,
나머지 훅 텍스트 채널은 **모델 컨텍스트에 존재하지 않는다.**

### 8.2 D1 이 바뀐다 — 옵션 ②가 되살아나되 형태가 다르다

감사 §6.2 D1 옵션 ②는 *"sentinel 을 SessionStart advisor 가 읽게 한다"* 였고, 그 advisor 가
stderr 로만 말한다는 사실이 그 옵션을 죽이는 것처럼 보였다. **실측은 그 반대를 보인다** —
`SessionStart` 의 `additionalContext` 는 **3/3 닿는다.** 즉 옵션 ②는 죽은 게 아니라
**채널을 바꾸면 산다**(stderr → `hookSpecificOutput.additionalContext`).

**단, 「Stop 을 additionalContext 로 바꾸면 된다」는 해법은 안전하지 않다.** 실측 `r7`:
`decision` 없이 `additionalContext` 만 낸 Stop 훅이 **9회 발화 / assistant 텍스트 10개**를
만들고 플랫폼 상한에서야 멎었다. 리포가 `SubagentStop` 에 대해 기록한 폭주의 **`Stop` 판 재현**이다.

### 8.3 측정하지 않은 것 (부재 증명 아님)

- **대화형 TUI 미측정.** 헤드리스 `-p` 만 쟀다. 구조상 같을 가능성이 높지만 재지 않았다.
- `SubagentStop`·`PreToolUse`·`PreCompact`·`SessionEnd`·`PostToolBatch`·`Notification` 미측정.
- `PostToolUse`(Bash)+`exit 2`, `Stop`+`exit 2` 미측정 (Read 경로에서만 `exit 2` 도달 확인).
- opus-5[1m] 단일 모델 · **2.1.252 단일 버전.** `MEASUREMENT.md` M2 가 버전 간 뒤집힘 전례를
  남겼으므로 **버전 고정 사실로만 인용할 것.**
- `SessionStart` 의 `additionalContext` 가 `/compact`·`--resume` 을 넘어 생존하는지 미측정 —
  **옵션 ②를 채택하면 이것이 선결 측정이다.**

### 8.4 격리 방법 정정 (`MEASUREMENT.md` 에 추가할 값어치)

- **`CLAUDE_CONFIG_DIR=<빈 dir>` 격리는 이 머신에서 불가능하다** — 인증이 그 dir 안에 있어
  `Not logged in` 으로 즉사한다. 대체재는 **`--setting-sources ''`** 이고, 격리 증명은
  `init.plugins == ['<probe>']` + `hook_started` 집계로 한다.
- **작업 디렉토리를 `~/.claude/` 아래 두면 `Write` 가 `safetyCheck` 로 거부된다** —
  `--permission-mode acceptEdits` 로도 안 뚫리고, 그러면 `PostToolUse` 가 발화하지 않아
  **「훅이 안 돈다」로 오판한다.**
- **`--include-hook-events`** 가 이 측정의 핵심 계측기다.

## 9. P1 실측 완료 — skill→skill 전이 (2026-09-01, `claude 2.1.252`)

**판정: 산문 `Skill(...)` 지시는 실제 Skill 도구 호출로 변환된다. 셋 다 참이다.**

| # | 명제 | 판정 | 증거 |
|---|---|---|---|
| 1 | 스킬 본문의 산문 `Skill(...)` 이 실제 도구 호출이 된다 | **참** | `TOOL_USE[1] Skill{entry-alpha}` → `TOOL_USE[2] Skill{target-alpha}` → Write. **토큰 분리 설계** — target 본문에만 있는 고유 토큰이 파일에 나타나야 통과(entry 본문엔 없음) |
| 2 | `user-invocable: false` 스킬을 다른 스킬이 부를 수 있다 | **참** | `tool_result: "Launching skill: probeplugin:target-beta"` — 에러 아님 |
| 2b | 같은 플래그가 **최상위 직접 호출**도 막지 않는다 | **참** | 별도 런 |
| 3 | 네임스페이스 없는 bare 이름이 resolve 된다 | **참** | 본문이 「접두어 붙이면 FAILURE」라 못 박은 변형에서 `{"skill":"target-gamma"}` 가 에러 없이 통과 |
| 4 | 큰 스킬(802줄) 종료 후 continuation 이 발화한다 | **참(1회)** | `Skill{bulk-work}` → Bash×2 → `Skill{target-alpha}` |

**`user-invocable: false` 가 실제로 하는 일은 슬래시 메뉴에서 숨기는 것뿐이다.** 플래그가
파싱돼 살아 있다는 것은 별도로 확증됐다 — 디스크의 스킬 11개 중 `system/init` 의 slash 목록에
**그 하나만 빠져 있고**(49 빌트인 + 가시 10 = 59 산술 일치), 그런데도 Skill 도구 주소지정은
막지 못했다. `spec-distill/CHANGELOG.md:3130` 이 인용한 CC 문서 원문이 2.1.252 에서 실측 확인됐다.

**양성·음성 대조 둘 다 있다.** 양성: `control-delta` 직접 호출 → 파일 생성. 음성: 존재하지 않는
스킬 → `<tool_use_error>Unknown skill</tool_use_error>` + 파일 0건. 계측기가 GREEN 도 RED 도 낸다.

### 9.1 D1 이 또 바뀐다 — 「불가능」이 아니라 「신뢰도」

감사 §4.2 는 이 이음매를 *"「제어 반환」이라는 픽션"* 이라 불렀고, 「그 층이 존재하지 않는다」는
읽기를 세웠다. **그 읽기는 이 층에서 성립하지 않는다** — 전이는 실제로 일어난다.

**남는 것은 능력 문제가 아니라 빈도 문제다.** 그리고 **probe 는 빈도를 재지 않았다** — 각 변형
1회, 총 15회 호출. 감사의 진짜 주장(*"모델이 990줄과 다수 subagent 라운드 뒤에도 기억하는가"*)에서
continuation 실측은 802줄 + Bash 2회짜리 **축소 모형**이고 **subagent 라운드·`AskUserQuestion`
게이트·사용자 개입이 전혀 없다.** 실전 qg 이음매의 신뢰도는 여전히 미측정이다.

### 9.2 측정하지 않은 것 (부재 증명 아님)

- **빈도 미측정** (위). 「할 수 있다」를 쟀지 「매번 한다」를 재지 않았다.
- **이름 충돌 시 bare-name resolve 미측정** — 여러 플러그인이 같은 스킬명을 가질 때 무엇이 이기나.
- **skill 계층 `allowed-tools` 는 이 probe 가 안 쟀다** (P2 소관). probe 플러그인은 그 키를 아예 선언하지 않았다.
- **격리가 요구한 형태가 아니다** — `CLAUDE_CONFIG_DIR` 빈-dir 증명은 auth 때문에 실패(§9.3).
  `--setting-sources ''` + 런별 `system/init` census 로 대체. 사용자 auth·전역 정책은 로드된 채였다.
- **2.1.252 단일 버전.** 이 리포는 2.1.220↔2.1.228↔2.1.239 사이에서 결론이 뒤집힌 전례가 있다.

### 9.3 내가 지시한 작업 경로가 틀렸다 — 함정 둘 (내 오류)

이 세션이 세 probe 에 모두 `/Users/jeonghokim/.claude/jobs/31c16418/tmp` 를 작업 디렉토리로
지시했다. **둘 다 틀렸다.**

1. **`~/.claude/**` 아래에서는 `--permission-mode acceptEdits` 가 무력하다.** Write 가
   `decision_reason_type:"safetyCheck"` · *"sensitive file"* 로 거부되는데 **rc=0 · `is_error=false`**
   다. `ls` 로 파일을 확인하지 않으면 「전이 실패」로 오판한다. P3 도 같은 함정을 밟았고(`r1`)
   트리거를 `Read`/`Bash` 로 바꿔 우회했다.
2. **그 경로는 동시 세션과 공유된다.** P1 의 격리 플러그인이 측정 도중 **통째로 사라지고**
   낯선 파일이 나타났다 — 같은 dir 을 쓰는 병렬 세션. 런 두 개가 `Unknown skill` 로 나와
   하마터면 「`--plugin-dir` 이 skill 을 안 싣는다」로 결론낼 뻔했다. 판별은 `claude --debug` 의
   `[WARN] Plugin path does not exist: … (ENOENT), skipping` 한 줄.

**두 함정 다 「조용히 틀린 결과」를 낸다.** P2 에게 전달했다.

## 10. P2 실측 완료 — skill 계층 `allowed-tools` (2026-09-01, `claude 2.1.252`)

**판정: 도구를 제한하지 않는다. 대신 「스킬 실행 자체」를 권한 게이트 대상으로 만든다.** 헤드리스 33회.

| 축 | 결과 |
|---|---|
| **A — 제한하는가** | **아니다.** `allowed-tools: - Read` 만 선언한 스킬 안에서 Write·Bash 가 실행돼 파일 둘을 만들었다. `denials=0`. 모델 관측: *"Neither tool was unavailable, despite the skill declaring `allowed-tools: Read`."* |
| **B — 스코프 표기가 범위 밖을 막는가** | **아니다.** `Bash(echo:*)` 선언인데 `printf ... > b_out.txt` 실행됨 — **커맨드 계층과 동일** |
| **C — 넓히는가(pre-approval)** | **관측 안 됨** (sensitive-file 분류기 1케이스만 시험, 약한 증거) |
| **D — 실제로 하는 일** | **권한 게이트.** 키가 있으면 `Skill` 호출이 `{"is_error":true,"content":"Execute skill: …"}` 로 거부되고 `result.permission_denials` 에 기록된다. **본문 바이트 동일**(sha 일치)한 키-없는 짝은 `Launching skill: …` 로 정상 실행 |

**계측기 검증** — 음성 대조로 「집행의 모습」을 따로 찍었다: `--disallowedTools Bash Write` 를 주면
`n_tools` 36→34, `bash_present=False`. **skill `allowed-tools` 런에서는 이 모습이 한 번도 안 나왔다.**

### 10.1 감사 §4.4 는 수정돼야 한다

*"`quality-pipeline` 의 `allowed-tools` 에 `Skill` 이 없다 → 파이프라인은 publish 스킬을 부를 수 없다"*
는 **「구조적 불가능」이 아니라 「모델 재량」**이다. 동형 fixture(`allowed-tools` 존재 · `Skill`
미포함)가 `Skill` 도구를 호출해 다른 스킬을 실제로 로드·실행했다. §4.1 의 「강제력 ⑤ 없음」
분류가 이 이음매에도 그대로 적용된다.

### 10.2 새 발견 — 두 감사 문서 어디에도 없는 것

**`CLAUDE.md` 의 규칙에 구멍이 있다.** `:41` 은 *"command/**skill** 계층의 `allowed-tools`
(kebab, **실재 키**)"* 라며 skill 계층을 실재로 인정하는데, `:42` 의 금지는 **command 계층만**
다룬다. 그리고 skill 계층에 그 키를 선언한 곳이 정확히 셋이다:

| 파일 | 항목 수 |
|---|---|
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | 59 |
| `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md` | 61 |
| `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md` | 43 |

**합계 163개 항목이 아무것도 제한하지 않으면서, 그 세 스킬을 헤드리스/자동화에서 못 뜨게 만든다.**
커맨드 계층은 규칙대로 **0건**(전부 제거됨)이다.

`CLAUDE.md:42` 자신의 문장이 이 자리에 그대로 적용된다 — *"막지 않는 것을 막는다고 믿게 만드는
선언은 없는 것보다 나쁘다."* 여기서는 **한 걸음 더 나쁘다**: 막지 않으면서 **다른 것을 막는다.**

### 10.3 측정하지 않은 것 (부재 증명 아님)

- **대화형 모드 미측정.** 게이트가 실제 프롬프트로 뜨는지, 사용자가 승인한 뒤 도구 집합이
  좁아지는지 안 쟀다. 게이트를 통과한 경로는 `--allowedTools Skill`/`bypassPermissions` 둘뿐이고
  **그 둘에서는 안 좁아졌다.**
- **설치본 실 스킬 미측정** — `quality-gates:quality-pipeline` 자체를 태우지 않았다(동형 fixture 만).
- **user/project 레벨 스킬**(`~/.claude/skills/`, `.claude/skills/`) 미측정. 플러그인 스킬만.
- 2.1.252 단일 버전.

## 11. probe 3건 종합 — 감사 §0 은 절반만 산다

| | 판정 |
|---|---|
| P1 skill→skill 전이 | **된다.** 산문 `Skill(...)` → 실제 도구 호출. `user-invocable: false` 는 메뉴 은닉일 뿐. bare 이름도 resolve |
| P2 skill `allowed-tools` | **제한 안 함.** 대신 실행 게이트 (§10) |
| P3 훅 채널 | **`systemMessage` 안 닿음 (0/14).** `additionalContext` 8/8, `decision:block+reason` 7/7 |

- **살아남은 절반**: 「턴 **경계를 넘는** 강제는 Stop 훅 `decision:"block"` 하나뿐」 — P3 가 **강화**했다.
  나머지 훅 텍스트 채널은 모델 컨텍스트에 존재하지 않는다.
- **죽은 절반**: 「전이가 물리적으로 불가능한 층이 있다」 — **거짓**(P1·P2). 전이는 되고,
  남는 것은 능력이 아니라 **신뢰도**다.
- **아무 probe 도 신뢰도(빈도)를 재지 않았다.** 각 변형 1회. 이것이 이 세 측정 전체의 공통 한계다.

## 12. 긴 초안

> skill `## 상태` 표의 「긴 초안」 항목. **확산을 다 담은 판**이고, seed 로 나가는 것은
> 여기서 깎은 것뿐이다. 무엇이 떨어졌는지는 이 절과 seed 를 대조하면 보인다.

### 12.1 goal — 무엇을 만드는가

devbrew 의 **이음매**(한 단계가 끝나고 다음 단계로 넘어가야 하는 자리)에 실제로 작동하는
강제·연결을 놓거나, 작동하지 않는 것을 **걷어낸다**. 대상은 감사 두 문서가 지목한 세 현상 중
**둘** — brief 리뷰가 안 불리는 것, qg 파이프라인이 PR 발행으로 안 이어지는 것. 세 번째(판정
회계)는 세션 `d21082ae` 범위다.

산출은 코드 변경이고, 구현은 워크트리 `.claude/worktrees/seam-enforcement` 에서 한다.

### 12.2 의도 — 왜 지금 이것을

사용자가 겪은 것은 「brief 리뷰가 잘 안 불린다」·「PR 발행이 파이프라인에서 안 이어진다」이고,
그 원인을 물어 나온 것이 감사 두 문서다. **그 문서들은 사용자의 의도가 아니라 에이전트 산출물**
이며 사용자가 명시적으로 「바로 믿지 말라」고 지위를 낮췄다. 실제로 검증에서 여러 곳이 낡았거나
틀렸음이 드러났다(§2.2·§9.1·§10.1·§2.1 A1).

### 12.3 방향 — 측정이 좁혀 준 것

**사용자가 준 방향**: *"가능하면 너무 문제되는건 억지로 관철하기 보다 기능을 걷어내자."*

측정 4건(§3 zero-tool, §8 P3, §9 P1, §10 P2)이 선택지를 이렇게 좁혔다:

| 사실 | 귀결 |
|---|---|
| 턴 경계를 넘는 강제는 Stop 훅 `decision:"block"` 하나뿐 (P3 가 강화) | 새 강제를 원하면 그 메커니즘밖에 없다. 선례(arm-once)가 순감 589줄이었다 |
| `systemMessage` 는 모델에 안 닿는다 (0/14) | 그 채널에 기댄 강제는 **전부 장식**. qg·project-init 의 훅 강제력이 여기 해당 |
| `additionalContext` 는 닿는다 (8/8), `SessionStart` 도 3/3 | D1 옵션 ②가 **되살아난다** — 채널만 바꾸면 |
| **단** Stop + `additionalContext` (decision 없이)는 **폭주한다** (9회 발화) | 「Stop 을 additionalContext 로」는 안전하지 않다 |
| skill→skill 전이는 **된다** (P1) | 「구조적 불가능」이라는 읽기는 거짓. 남는 건 **신뢰도** |
| skill `allowed-tools` 는 제한 안 하고 **실행 게이트만 만든다** (P2) | 163개 항목이 무용하면서 헤드리스를 막는다 → **걷어낼 것** |
| `tools: []` 는 실제로 집행된다 (§3) | probe 판정이 참 → F1 은 순수 배포 문제 |

**아무 probe 도 신뢰도(빈도)를 재지 않았다.** 각 변형 1회. 이것이 D1 의 남은 불확실성 전부다.

### 12.4 확정된 수정 대상 — 설계 결정이 필요 없는 것

| # | 대상 | 성격 | 가장 가벼운 해법(제안) |
|---|---|---|---|
| **F1** | `reviewing-brief/SKILL.md:107` 의 cwd-상대 fail-closed 선결조건 | 배포 결함. **devbrew 밖에서 100% 차단 중**. 설치본 `0.47.0` 에도 그 파일 없음 | **선결조건 삭제.** `tools: []` 집행이 실측됐으므로 매 실행마다 답이 나온 질문을 다시 묻는 것이다. probe 문서는 감사 기록으로 남기고 런타임 의존만 끊는다. 두 번째 소비자(`test_brief_agents.sh:9`)도 같이 본다 |
| **F2** | `finishing.md:92-102` 핸드오프 | 결함 셋 — 셸 변수 소멸 · 자리표 `<file>` 박제 · 인자 3 vs 요구 4 | 리터럴 치환 또는 파일 경유. `SKILL.md:62` 의 산문도 v0.47.0 코드(빌더가 `resolve_audit` 로 자체 도출)에 맞게 정정 |
| **N1** | skill 계층 `allowed-tools` 163항목 (qg 3파일) | **무용 + 유해.** 제한 안 하면서 헤드리스 실행을 막는다 | **제거.** `CLAUDE.md:42` 의 금지를 skill 계층까지 확장 |
| **N2** | 훅 커버리지 비대칭 서술 | 근거 파일이 통째로 바뀜 (`spec-write-validator.py` 삭제 → `arm_ledger.py:41`) | 감사가 아니라 **현재 코드** 기준으로 재작성 |

### 12.5 설계 결정이 필요한 것

**D1 — 이음매 강제를 어디까지.** 선택지가 측정 후 이렇게 바뀌었다:

- ① **Stop 훅 확장** — 유일하게 검증된 턴-넘김 강제. 대가: arm-once 급 재발동 가드가 이음매마다.
  그리고 `review-dispatch.py` 는 저쪽 세션도 만지므로 **선택 시 즉시 통지 약속**이 걸려 있다.
- ② **SessionStart `additionalContext` advisor** — P3 로 **되살아났다**(3/3 닿음). 지금 그 자리의
  advisor 는 stderr 라 아무 데도 안 닿는다. 대가: 강제가 아니라 알림 · **`/compact`·`--resume`
  생존 미측정**(채택 시 선결 측정).
- ③ **아무것도 안 함 + 거짓 약속 삭제** — `/qg-publish` 를 정본 경로로 공식화하고, `qg.md:75` 의
  「제어가 돌아오면」과 README 다이어그램을 사실에 맞게 고친다. **사용자 방향과 가장 가깝다.**

**전제: 자동 발행을 원하는가.** 사용자가 「인터뷰에서」로 미뤘다. 이것이 정해지기 전에는 D1 이
정해지지 않는다.

**D3 — 리뷰 미실행 감지.** **두 층이 다 닫혀 있다**: `check_brief.py:25-26` 은 자기 불변식
(「brief 파일만 읽는다」)으로 금지하고, 훅 층은 `arm_ledger.py:41` 의 `PREFIX =
"docs/superpowers/specs/"` 로 interview 를 배제한다. 세 번째 층이거나, 둘 중 하나의 불변식을
바꿔야 한다. **층을 안 옮기고 같은 자리에서 반복 시도하면 whack-a-mole 이 된다.**

### 12.6 steering — 하지 말아야 할 것

- **감사를 전제로 쓰지 말 것.** §2.2·§9.1·§10.1·§2.1 이 틀린 지점 목록이다. 인용할 때 HEAD 를 밝힌다.
- **측정 안 된 것을 측정된 것처럼 쓰지 말 것.** 특히 **빈도**. 「전이가 된다」는 「매번 된다」가 아니다.
- **버전 고정.** 측정은 전부 `claude 2.1.252` 단일 버전. 이 리포는 2.1.220↔228↔239 에서 결론이 뒤집힌 전례가 있다.
- **저쪽 세션 범위를 침범하지 말 것.** `shared/adjudication/` · `synthesize_artifact_findings.py` ·
  처분 앵커 계약 · codex 종속은 `d21082ae` 소유. `review-dispatch.py` 는 공유 — 확장 시 통지.
- **새 강제를 만들 때 폭주 가드를 먼저 설계할 것.** Stop + `additionalContext` 가 9회 발화한 실측이 있다.

### 12.7 열린 질문 — 인터뷰가 답할 것

1. **자동 발행을 원하는가** (D1 의 전제).
2. **D1 ③(걷어내기)이 사용자 방향과 맞는데, 그러면 qg publish 는 영원히 손으로 치는 것인가** —
   그것이 받아들일 만한가.
3. **D3 에서 어느 층을 열 것인가** — `check_brief.py` 불변식을 깰 것인가, 훅 PREFIX 를 넓힐 것인가,
   세 번째 층을 만들 것인가. **아니면 감지 자체를 포기할 것인가**(걷어내기 방향).
4. **N1(skill `allowed-tools` 제거)이 무언가를 깨뜨리는가** — 대화형에서 그 게이트가 의도된
   승인 지점이었을 가능성. **대화형 미측정**이 여기 걸린다.
5. **F1 에서 선결조건을 삭제할 것인가, 판정을 플러그인 안으로 옮길 것인가.**
6. **신뢰도를 측정할 것인가** — 「전이가 매번 되는가」는 반복 실행으로만 알 수 있다. 그 비용을 낼 것인가.

## 13. 검증 라운드 1 — 세 축 결과와 반영

**멈출 조건을 시작 전에 정했다**: 최대 3라운드 · findings 중 「직전 라운드에 내가 새로 쓴 문장」이
절반 이상이면 정지 · 같은 범주 반복이면 정지. **findings 0 을 기다리지 않는다.**
(형제 세션이 codex 3회차에서 「6건 중 3건이 그 라운드에 새로 쓴 문장」을 이유로 멈춘 경험을 받았다.)

| 축 | 담당 | 결과 | degrade |
|---|---|---|---|
| 억제 | codex (실호출 1회) | **6건**, `codex_status: ok` | 없음 |
| 억제 | 격리 critic (`tools: []`) | **13건** | 없음 — 도구 부재를 스스로 밝히고 날조하지 않음 |
| 냉독 | seed-readback (`tools: []`) | 「모르겠다」 **9건** | 없음 |

**라운드 1 판정 — findings 중 「직전 라운드에 새로 쓴 문장」 0건.** 첫 라운드이므로 정지 조건 미해당.

### 13.1 세 축을 관통한 병 — 에이전트가 만든 것을 사용자 것으로 표시했다

| 지적 | 실제 |
|---|---|
| critic 1 — 「발단은 **내가 겪은** 두 가지」 | **사용자 원문에 없다.** 사용자가 쓴 것은 「brief 분리 리뷰 zero tool 격리 probe **자산이 이 레포에 없고**」 — 자산 부재 지적이지 호출 실패 체험이 아니다. 사용자가 「바로 믿지 말라」고 지위를 낮춘 감사의 프레이밍이 **사용자 체험담으로 승격**되면 그 뒤로 반증 대상이 아니게 된다 |
| critic 2 — 형제 문서가 「사용자가 지목한 자료」에 | 사용자는 `cross-skill-seam-handoff.md` **하나만** 지목. 형제 문서는 에이전트가 함께 읽은 것이고, 그것이 **범위 배제의 근거로 쓰여 load-bearing** |
| critic 3 · codex 2·3·4 — 세션 경계·합의가 사용자 결정으로 | 사용자 발화는 세 문장 + 게이트 「이음매만」. 「저쪽이 무엇을 안 건드리는지」는 이쪽에서 관찰 불가 |
| critic 4 — 조건절이 지워짐 | 원문은 「**가능하면** **너무 문제되는건** 억지로 관철하기 보다」 — 조건절 둘 |
| critic 5 — 형제 세션 사건이 「하지 말아 달라」 절에 | 그 절은 사용자 목소리로 읽힌다 |
| critic 9 — **사용자가 제기한 항목이 주의 한 줄로 격하** | 「tools 선언과 하니스 목록 어긋남」이 손볼 자리에도 정할 것에도 없었다 — *"사용자 항목이 에이전트 항목으로 교체된 모양"* |
| critic 11 · codex 1 — 워크트리 경로 확정 | 사용자는 경로·이름을 말한 적 없다 |

### 13.2 갈래가 빠졌다 — critic 10

사용자가 말한 것은 **「자산이 없다」**인데 seed 의 갈래는 「삭제 vs 판정 이전」 둘뿐이었다.
**「probe 자산 자체를 배포 단위 안에 넣는다」가 사용자 말에 가장 가까운 세 번째 갈래**인데 없었다.

### 13.3 냉독의 최대 지적 — 증상과 처방이 어긋난다

*"선결조건을 걷어내면 「못 시작함」은 풀리지만 「잘 안 불림」이 풀리는지는 별개로 보였다."*
*"「문서가 이어진다고 거짓말한다」만 고치면 원래 증상은 정직하게 서술만 될 뿐 해소되지 않는데,
그 결과를 받아들일 수 있는지가 seed 에 없다."*

**맞다.** 감사는 brief 미호출의 원인을 여섯으로 나열했고 선결조건은 그중 하나다. seed 는 그것만
확정 항목으로 올리면서 그것을 고치면 증상이 풀리는 것처럼 읽히게 썼다. 냉독이 판정 기준도 스키마도
없이 문면만 읽는 조건에서 이것을 잡았다.

### 13.4 조기 폐쇄 — critic 6·7·8

- 「**다시 재지 말 것**」 헤더가 CLAUDE.md 의 **Sealed decision** 금지와 충돌하고, 같은 절 안의
  「빈도는 안 쟀다」·「버전 간 뒤집힘 전례」와도 충돌한다 → 「이미 잰 것 — 반증은 열려 있다」로.
- 이음매 정의가 **닫힌 4종 열거**라 사용자의 「더 있는지 탐색」에 상한을 씌운다 → 「예컨대 … 이 넷이
  전부인지가 탐색 대상」으로.
- 「**확정된** 넷」의 주체가 지워졌다(확정한 것은 에이전트) → 「에이전트가 현재 코드에서 확인한 넷 —
  각각이 손볼 자리인지는 미정」으로. 넷째는 「다시 쓰거나, 인용을 그만두거나」 두 갈래로.

### 13.5 반영하지 않고 남긴 것

없다. 28건(중복 포함) 전부 반영했다. 다만 **반영의 성격이 둘로 갈린다** — 대부분은 귀속·조건절·
갈래를 되살린 것이고, codex 2·3(세션 경계에 근거 없음)은 **재료 보강**으로 해소했다(`## 1. 원문` 에
라운드 3 게이트 답 추가). 후자는 codex 가 그 시점 재료에 대해 옳았던 판정이므로, **재실행하면
조건이 바뀐 실행**이다.

### 13.6 이 라운드의 degrade

**degrade 는 하나뿐이고 구조적이다** — `no-state-in-phase-0`. `request-framing` 은 인터뷰 이전
단계라 세션 state 파일이 없는 것이 정상 경로이고(`ledger_rc=1`), 따라서 `framing_degradations`
원장이 존재하지 않는다. **기록이 없는 것과 degrade 가 없는 것은 다른 사실**이므로 여기 적어 둔다.
세 축 자체는 전부 정상 완주했다 — codex `ok`, 격리 critic 정상, 냉독 정상.
