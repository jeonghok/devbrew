# Handoff — spec-distill v0.18.0 review-in-progress 락이 잘못된 session-id로 keyed됨 (Stop 재강제 루프)

> **One-line:** `reviewing-spec` 스킬이 review-in-progress 락을 **interview UUID** 세션에 쓰는데, Stop/PostToolUse/UserPromptSubmit 훅은 **harness session id**로 상태를 읽는다 → 락이 서로 다른 파일에 있어 훅이 못 봄 → 리뷰가 이미 진행 중인데도 `reviewing-spec`를 중복 재강제(re-force loop). 같은 split이 `suppressed_paths`/approve 억제도 무력화한다.

- **상태:** 이번 세션에서 **live 재현·확정**. 이 문서는 fix 세션용 handoff (여기서 고치지 말 것 — quality-gates PR-publish 브랜치와 무관한 spec-distill 플러그인 버그, scope creep 방지).
- **영향 버전:** spec-distill `0.18.0` (main `00415d9`, PR #91에서 락 도입).
- **Fix 브랜치:** main에서 새 `fix/spec-distill-review-lock-session-id` (feature/qg-pr-publish 위 아님).
- **연구 근거 파일:** 모든 인용은 아래 캐시 사본 기준. Fix는 **소스** `plugins/spec-distill/`에 적용 (cache 아님).
  - 캐시(읽기): `/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/0.18.0/…`
  - 소스(수정): `/Users/jeonghokim/Downloads/devbrew/plugins/spec-distill/…` (내용 byte-identical 확인함)

---

## 1. Symptom — Stop 재강제 루프 / reviewing-spec 중복 dispatch

`reviewing-spec` 스킬이 `spec-reviewer` 서브에이전트를 async dispatch하고 결과를 기다리려 턴을 멈추면, 그 턴 경계에서 메인 `Stop` 훅(`review-dispatch.py`)이 fire한다. 락이 제대로 걸렸다면 훅은 "이 문서 리뷰 진행 중"으로 판단해 no-op해야 하지만, 실제로는 아래 mandate를 **다시** 방출한다:

```
MANDATORY: 다음 turn 첫 액션으로 reviewing-spec skill 호출. spec path: <path>. mode: design. 호출 skill의 terminal handoff(writing-plans 등)는 review pass 이후로 보류.
```

(`review-dispatch.py:188-198`가 조립, `:208-212`에서 `{"decision":"block", …}`로 emit.)

**사용자 체감:** design 문서를 저장 → "Reviewer will be dispatched at turn end" advisory → 스킬이 리뷰어를 띄우고 대기 → 그런데도 Stop이 "MANDATORY: reviewing-spec 호출"을 다시 붙여 같은 리뷰를 **중복 강제**하거나 진행 중 흐름을 **절단**한다. 즉 v0.18.0 락이 봉쇄하려던 바로 그 오발(CHANGELOG [0.18.0] "subagent 경계 Stop 재발동")이 **interview-originated 플로우에서는 여전히 발생**한다. `pending_review`는 Stop 1회 dispatch 후 strip되므로 무한 루프는 아니지만, design 문서를 재편집할 때마다 재발한다.

---

## 2. Root cause — interview-UUID vs harness-sid keying split

두 개의 서로 다른 session-id 네임스페이스가 존재하고, **락을 쓰는 쪽(스킬)** 과 **락을 읽는 쪽(훅)** 이 서로 다른 id를 쓴다.

### 2a. 훅은 항상 harness sid로 상태 파일을 연다

세 훅이 전부 `state_path.resolve_session_id(payload)`를 쓴다:

- `hooks/state_path.py:23-48` — precedence: `DEVBREW_SPEC_DISTILL_SESSION_ID` → `CLAUDE_CODE_SESSION_ID` → `payload["session_id"]`. 즉 **harness session id**.
- `hooks/review-dispatch.py:38, 118, 121` — `resolve_session_id(payload)` → `state_file_for(session_id)` = `<state_root>/<harness-sid>/state.local.md` (`:63-64`).
- `hooks/spec-write-validator.py:271-273, 145-149` (PostToolUse, `pending_review` writer) — 동일하게 `resolve_session_id(payload)` → `write_state()`가 `_state_root()/<harness-sid>/state.local.md`에 `pending_review` block 기록.
- `hooks/pending-review-reminder.py:86-89` (UserPromptSubmit) — 동일.

→ `pending_review`, `last_dispatched_at`, 그리고 훅의 lock/suppress **조회**는 전부 `<harness-sid>/state.local.md`를 대상으로 한다.

### 2b. 스킬은 interview UUID로 락을 쓴다

- `skills/conducting-interview/SKILL.md:29, 33-36` — 인터뷰 state는 `.claude/spec-distill/<session-id>/state.local.md`이고 frontmatter `session_id: <uuid>`. 이 UUID는 harness가 아니라 **인터뷰가 자체 생성**한 값이다(플러그인 스크립트에 `uuidgen`/`uuid4` 호출 없음 — 모델이 인터뷰 시작 시 인라인 생성). `/interview` → `conducting-interview`는 harness sid를 **읽지 않는다**.
- `skills/reviewing-spec/SKILL.md:18` — Step 1이 "Load state.local.md — `session_id`, `rereview_count`, `issue_history` 읽기". 여기서 로드하는 state 파일은 인터뷰가 만든 `<interview-uuid>/state.local.md`(= `rereview_count`/`issue_history`가 실제로 사는 곳)이고, 스킬은 그 frontmatter의 `session_id`(= **interview UUID**)를 `$session_id`로 채택한다.
- `skills/reviewing-spec/SKILL.md:20-23` — Step 1 "리뷰 락 refresh"가 `review_lock.py set "$session_id" "$spec_path"` 호출. `$session_id` = interview UUID.
- `scripts/review_lock.py:225` — `main()`이 `state_file_for(sid)`로 `<state_root>/<interview-uuid>/state.local.md`에 `review_in_progress:` 기록(`suppress_state.state_file_for`, `suppress_state.py:96-102`).

### 2c. 조회는 harness sid 파일에서 → 락 미발견 → dispatch

- `review-dispatch.py:158-168` — Stop 훅이 `<harness-sid>/state.local.md`의 `body`로 `review_lock.is_review_active(body, pending_key, now, ttl)` 호출.
- `review_lock.py:199-210` — `is_review_active`는 넘겨받은 body의 `review_in_progress` 엔트리에서 `pending_key`를 찾는다. 하지만 그 body는 harness-sid 파일이고, 락은 interview-uuid 파일에 있으므로 엔트리 부재 → `False` 반환.
- `False` → 훅은 "fail-safe = 강제"로 정상 dispatch (`review-dispatch.py:153-157` 주석, `:208`). → **재강제**.

동일 split이 `suppressed_paths`에도 적용된다: `approve_handoff.sh`/`cancel_review.py`가 `$session_id`(interview UUID)로 suppress를 쓰지만(`approve_handoff.sh:50-52`, 66-71 lock clear 포함), Stop/PostToolUse의 `is_suppressed`는 harness-sid 파일을 읽는다(`review-dispatch.py:141`, `spec-write-validator.py:279-280`).

### Root-cause chain 요약

| # | 링크 | 파일:라인 | keyed by |
|---|---|---|---|
| 1 | 인터뷰가 자체 UUID로 state dir 생성 | `conducting-interview/SKILL.md:29,35` | interview UUID |
| 2 | reviewing-spec가 그 state에서 `$session_id` 채택 | `reviewing-spec/SKILL.md:18` | interview UUID |
| 3 | `review_lock.py set "$session_id"` | `reviewing-spec/SKILL.md:23` → `review_lock.py:225` | interview UUID |
| 4 | PostToolUse가 `pending_review` 기록 | `spec-write-validator.py:271-273,145-149` | **harness sid** |
| 5 | Stop이 harness-sid 파일로 `is_review_active` | `review-dispatch.py:118,121,158-168` | **harness sid** |
| 6 | 락 미발견 → `False` → 재강제 | `review_lock.py:199-210` → `review-dispatch.py:208` | — |

---

## 3. Evidence / 결정론적 repro

### 3a. 이번 세션 captured evidence (live)

- design 문서 Write가 PostToolUse 훅을 트리거("Reviewer will be dispatched at turn end").
- 락을 interview UUID `5e42358f-119f-4ca9-b2ca-74061bdb80b3`로 set → `review_lock.py set` OK 보고.
- `spec-reviewer` async dispatch(진행 중).
- 그런데도 Stop이 mandate 재방출: "MANDATORY: 다음 turn 첫 액션으로 reviewing-spec skill 호출 … mode: design".

### 3b. state 파일 스냅샷 (`state_root = /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill`)

이번 세션 실측 (`grep -c` per signal):

| dir | 종류 | `review_in_progress` | `pending_review` | `last_dispatched_at` | `suppressed_paths` |
|---|---|:-:|:-:|:-:|:-:|
| `5e42358f-…` | **interview UUID** | **1** (락 여기) | 0 | 0 | 0 |
| `76305ecd-…` | **harness sid (current)** | 0 | 0 | **1** | 0 |
| `56f2bbd4-…` | harness sid (prior) | 0 | 0 | **1** | 1 |
| `bcccf21f-…` | interview UUID (prior) | **1** (stranded 락) | 0 | 0 | 0 |

- 락(`review_in_progress`)은 **interview-UUID** dir에만, `last_dispatched_at`(훅이 dispatch 후 남김)은 **harness-sid** dir에만 → split 확정.
- `bcccf21f-…`의 stranded 락 = 이전에도 같은 split이 발생해 clear되지 못한 흔적(corroborating).

### 3c. 결정적 확증: `CLAUDE_CODE_SESSION_ID`가 현재 harness dir와 일치

```
CLAUDE_CODE_SESSION_ID = 76305ecd-3f03-471c-9745-e6153618ff4d
```

이 값이 `last_dispatched_at`을 가진 **current harness-sid dir**(`76305ecd-…`)와 정확히 일치한다 → 훅이 실제로 `CLAUDE_CODE_SESSION_ID`(env)로 상태 파일을 열었음을 증명. **또한 이 env 값이 스킬 런타임에서 읽을 수 있다는 뜻이므로, fix의 bridge 경로가 성립한다(§6).**

세션 도중 harness sid가 `56f2bbd4-…` → `76305ecd-…`로 **drift**했다(추정: `/compact`/resume 경계). interview UUID `5e42358f-…`는 그 사이 stable — 이 안정성이 인터뷰가 self-UUID를 쓰는 *이유*이며, fix 설계에서 반드시 보존해야 할 성질(§6 참조).

> **주의:** `state_root`의 `.current_interview_sid` 파일(interview UUID 담김)은 **플러그인 스크립트 어디에서도 참조되지 않는다**(전체 0.18.0 트리 grep 결과 0건). 이 세션의 ad-hoc 아티팩트로 보이며 load-bearing 메커니즘이 아니다 — fix가 여기에 의존하면 안 됨.

### 3d. 결정론적 repro (파일만으로, 훅 레벨)

```bash
ROOT=$(mktemp -d)
export DEVBREW_SPEC_DISTILL_SESSION_ID=hsid-aaaaaaaa      # 훅이 볼 harness sid
DOC='docs/superpowers/specs/2026-07-05-x-design.md'

# 1) harness-sid state에 pending_review 세팅 (PostToolUse가 하는 일)
mkdir -p "$ROOT/hsid-aaaaaaaa"
cat > "$ROOT/hsid-aaaaaaaa/state.local.md" <<EOF
---
session_id: hsid-aaaaaaaa
---

pending_review:
  path: $DOC
  mode: design
  triggered_at: 2000-01-01T00:00:00Z
EOF

# 2) 버그 재현: 락을 interview UUID에 set
python3 scripts/review_lock.py set iuuid-bbbbbbbb "$DOC"   # → $ROOT/iuuid-bbbbbbbb/…에 기록

# 3) Stop 훅 실행 (harness sid로 state 읽음) → 락 못 봄 → BLOCK emit (BUG)
echo '{"session_id":"hsid-aaaaaaaa"}' | python3 hooks/review-dispatch.py
#   기대(현행): {"decision":"block", …}  ← 재강제

# 4) fix 검증: 락을 harness sid에 set하면
python3 scripts/review_lock.py set hsid-aaaaaaaa "$DOC"
echo '{"session_id":"hsid-aaaaaaaa"}' | python3 hooks/review-dispatch.py
#   기대(fix 후): 빈 stdout, no decision:block  ← no-op
```

(state_root은 git-common-dir 기반이라 실제 실행 시 `state_path.py`의 라우팅을 감안해 `env -i` + 임시 git repo로 감싸거나, `state_file_for`를 monkeypatch하는 기존 `test_review_dispatch.sh` 패턴을 따를 것.)

---

## 4. Blast radius — split되는 신호와 사용자 영향

harness sid와 interview UUID가 다를 때(= 인터뷰를 이전 턴/‑compact 전에 시작한 모든 실사용 플로우) 아래가 전부 어긋난다:

| 신호 | writer | reader | 현재 keyed by | 결과 |
|---|---|---|---|---|
| `review_in_progress` (락) | 스킬 `review_lock.py set` | 훅 `is_review_active` | writer=interview, reader=harness | **Stop/reminder 재강제 루프** (확정) |
| `suppressed_paths` | 스킬 `approve_handoff.sh`/`cancel_review` | 훅 `is_suppressed` | writer=interview, reader=harness | **approve/cancel 억제 미존중** → 같은 문서 재편집 시 재-arm |
| lock clear (approve/cancel) | `approve_handoff.sh` `review_lock.py clear`, `cancel_review.py` | — | interview | interview dir의 락만 지움 → harness dir엔 애초에 없어 무의미, 그러나 stranded 락 누적(3b `bcccf21f`) |
| `pending_review`, `last_dispatched_at` | 훅 | 훅 | harness (일관) | 이 둘은 자기들끼리는 일관 — 그래서 재강제가 *작동*은 함 |

**핵심 불변식(fix가 확립해야 할 것):** 훅이 읽고/쓰는 모든 신호(`pending_review`, `last_dispatched_at`, `review_in_progress`, `suppressed_paths`)는 **동일한 harness sid** 아래 살아야 한다. 지금은 앞 둘만 그렇고 뒤 둘은 스킬이 interview UUID에 쓴다 — 그 비대칭이 버그.

사용자 관점 증상: (1) 리뷰 진행 중 중복 "MANDATORY" mandate, (2) approve 후에도 같은 design 재저장 시 리뷰가 다시 걸림(suppress 무력), (3) `/spec-distill:cancel-review`가 안 먹는 것처럼 보임.

---

## 5. Proposed fix

### Intended design (deeper question 답)

> **락/suppress 같은 "훅-facing" 신호는 harness sid로 keyed되어야 한다. interview-continuity 신호(`rereview_count`/`issue_history`/`pending_locked_decisions`/web budgets)만 stable interview UUID로 남긴다.**

두 후보:

**Strategy A — Bridge (권장).** 스킬이 훅-facing CLI(`review_lock.py set|pause`, `approve_handoff.sh`, `suppress_state.py`, `cancel_review.py`)를 호출할 때 interview `$session_id` 대신 **harness sid**를 넘긴다. harness sid는 스킬 런타임에서 `resolve_session_id(None)`의 env-precedence(즉 `CLAUDE_CODE_SESSION_ID`, §3c에서 set 확인)로 얻는다. 인터뷰 continuity state(rereview_count 등)는 interview UUID 파일에 그대로 둔다(훅이 읽지 않으므로 drift 무해).

- 장점: 최소 변경(스크립트 로직 무수정 — 이미 sid를 arg로 받음), harness drift에도 강함(스킬과 훅이 *같은 턴에 같은 env*를 읽으므로 항상 합의). §3b/3c가 실증하듯 훅은 이미 `CLAUDE_CODE_SESSION_ID`로 dispatch dir를 정한다 → 스킬이 같은 값을 쓰면 정확히 그 파일에 락이 걸린다.
- 단점: 스킬이 두 id를 구분해 다뤄야 함(interview_sid=continuity 읽기/쓰기, harness_sid=훅-facing). 문서화 필요.

**Strategy B — Unify at root (비권장).** `conducting-interview`가 self-UUID 대신 harness sid를 session_id로 채택 → 모든 state가 한 dir. 하지만 harness sid는 `/compact`/resume에서 **drift**한다(§3c 실측 `56f2bbd4`→`76305ecd`). 인터뷰 continuity state가 drift 시 orphan → 인터뷰↔리뷰 연속성이 깨진다. 즉 락 split을 고치려다 continuity-orphan이라는 다른 버그를 낳는다. interview UUID가 self-generated인 *이유*(턴 경계에서 안정)를 파괴하므로 채택하지 않음.

**→ 권장: Strategy A.**

### 최소·정확 변경 (Strategy A)

1. **`hooks/state_path.py`에 env-only 리졸버 CLI 추가** (DRY — precedence를 한 곳에 유지):
   ```python
   # main(): 기존 state-root 서브커맨드 옆에
   if sub == "session-id":
       sid = resolve_session_id(None)   # payload 없음 → env precedence만
       if sid is None:
           return 1                     # loud stderr는 resolve_session_id가 이미 냄
       print(sid)
       return 0
   ```
   왜: 스킬이 `CLAUDE_CODE_SESSION_ID`를 raw로 읽으면 훅의 precedence(`DEVBREW_SPEC_DISTILL_SESSION_ID` override 포함)와 어긋날 수 있다. 한 함수로 통일해야 훅/스킬이 *정의상* 같은 sid를 얻는다.

2. **`skills/reviewing-spec/SKILL.md` Step 1** — 훅-facing 호출에 harness sid 사용:
   ```bash
   harness_sid="$(python3 "${CLAUDE_PLUGIN_ROOT}/hooks/state_path.py" session-id)"
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/review_lock.py" set "$harness_sid" "$spec_path"
   ```
   그리고 Phase 5 ④ `pause`(`:118`)와 Approve handoff(`:136` `approve_handoff.sh`)도 `$harness_sid`로. 산문: "락/suppress는 harness sid, rereview_count/issue_history는 interview UUID" 불변식을 명시.
   왜: `review_lock.py set`이 harness-sid 파일(훅이 읽는 바로 그 파일)에 락을 upsert → `is_review_active`가 True → 재강제 봉쇄. `review_lock.set_lock`은 `_strip_lock` 후 재-append이라 그 파일의 기존 `pending_review`/`last_dispatched_at`을 보존(`review_lock.py:129-134`).

3. **`scripts/cancel_review.py`** (별도 읽기 필요 — 이번 조사 범위 밖이나 같은 split 대상): 취소 문서 suppress + lock clear를 harness sid로. `/spec-distill:cancel-review` command도 sid 전달 방식 점검.

4. (선택) **인터뷰 continuity를 안 건드림**: `conducting-interview`는 무변경. 이 fix는 훅-facing 신호만 harness sid로 이전한다.

**대안 고려:** "스킬이 `pending_review`가 실제 있는 dir를 스캔해서 그 sid를 쓰기"(memory note의 how-to)는 런타임 heuristic이라 취약(여러 dir에 `pending_review`가 있거나 없을 때 모호). `resolve_session_id(None)` env-precedence가 훅과 *정의상* 동일 → 더 견고. 권장은 (1)+(2)+(3).

**Assumption 명시:** 이 fix는 "harness가 `CLAUDE_CODE_SESSION_ID` env를 set하고, 그 값이 훅 payload `session_id`와 일치"에 의존한다. §3c에서 둘 다 `76305ecd`로 확정. 만약 어떤 환경에서 env가 unset이면 `state_path.py session-id`가 exit 1 → 스킬은 loud advisory 후 락 skip(리뷰 강제는 유지 = fail-safe 방향). 이 degradation 경로를 스킬에 명시할 것.

---

## 6. Regression test (teeth-proving)

두 층. **1번(behavioral)이 primary** — 헤더-satisfiable 함정에 안 걸리고 실제 동작을 증명한다.

### T1 — 훅 레벨 behavioral (primary, `tests/test_review_lock_session_id.sh` 신규)

`test_review_dispatch.sh` 패턴(임시 state_root + payload로 `review-dispatch.py` 구동) 재사용:

- **repro assert (RED-before-fix):** harness-sid state에 `pending_review`(doc X) 세팅, 락을 *interview UUID*에 set → `review-dispatch.py`(payload session_id=harness) 실행 → stdout에 `"decision":"block"` **존재** 확인. (버그 재현)
- **fix assert (GREEN-after-fix):** 락을 *harness sid*에 set → 동일 실행 → stdout **빈**(no `decision:block`) 확인. (락 존중)
- 두 assert가 함께 있어야 "락이 harness-sid 파일에 있을 때만 dispatch가 억제된다"는 계약이 teeth를 갖는다. fix 없이 스킬이 interview UUID로 set하면 T1의 fix assert가 red.

이 테스트는 훅 실동작을 구동하므로 문구 매칭이 아니라 **의미**를 잠근다.

### T2 — 스킬 문서 락 (`test_reviewing_spec_lock.sh` 확장, header-satisfiable 회피)

기존 `test_reviewing_spec_lock.sh`는 `review_lock.py set` *존재*만 본다 → sid가 interview냐 harness냐를 구분 못 함. 강화:

- Step 1 윈도우(`sed -n '/리뷰 락 refresh/,/Dispatch spec-reviewer/p'`) 안에서 `review_lock.py" set`가 **`$harness_sid`(또는 `state_path.py" session-id` 리터럴)** 와 같은 라인/블록에 있는지 body-unique grep.
- **teeth 증명(mutation, POS/NEG fixture — 기존 파일 patterns line 34-44 그대로):** POS = `set "$harness_sid"` 라인 → 매치, NEG = `set "$session_id"` 라인(= 현행 버그 코드) → **비매치**. 두 fixture가 갈려야 pass. 이렇게 하면 누군가 harness_sid를 다시 interview `$session_id`로 되돌리면 red.
- **함정 주의(memory `grep 회귀 락 헤더-satisfiable`):** `harness_sid` 문자열이 Step 1 헤더/산문에도 등장하면 body(명령 라인)를 지워도 GREEN이 될 수 있다. 반드시 **명령 라인 고유 토큰**(`review_lock.py" set "$harness_sid`)을 Step 1 윈도우 내에서 grep하고, "헤더만 남긴 mutation → red"로 teeth를 증명할 것.

### T3 — `state_path.py session-id` 유닛 (`test_session_id_resolution.sh` 케이스 추가)

`state-root`처럼 신규 서브커맨드에 케이스: env set → 그 값 print(exit 0); env unset → exit 1 + `<none>` 미출력. 기존 파일의 `env -i` clean-env 패턴 재사용.

---

## 7. Scope note

- 이건 **spec-distill 플러그인 버그**다. quality-gates PR-publish(`feature/qg-pr-publish`)와 무관 — 여기서 고치면 scope creep. **main에서 새 브랜치**(`fix/spec-distill-review-lock-session-id`)로 작업.
- devbrew 규약: 플러그인 건드리는 PR마다 **`plugin.json` SemVer bump**. 현재 `0.18.0` → `0.18.1`(fix; 버그 수정, surface 무추가) 권장. `plugins/spec-distill/.claude-plugin/plugin.json:4`.
- **CHANGELOG.md** `## [0.18.1] — YYYY-MM-DD`에 `### Fixed` 항목(락 session-id split → Stop 재강제 봉쇄; suppress 대칭 포함). `plugins/spec-distill/CHANGELOG.md`.
- 수정은 소스(`plugins/spec-distill/…`)에. 캐시(`~/.claude/plugins/cache/…/0.18.0/`)는 설치 산출물이라 건드리지 않음(다음 설치 시 새 버전으로 교체).
- 락은 **persona/보안-민감 코드는 아님**(리뷰 강제 계약을 *약화*하지 않고, fail-safe=강제 방향 유지). 단 Law 1(리뷰 강제) 계약을 만지므로 fix 후 "락 부재/stale/env-unset → 정상 dispatch"의 fail-safe 방향이 보존되는지 재확인 필수.
- 권장 실행 형태(repo 문화): subagent-driven, 각 task 2-단계 리뷰 + whole-branch 리뷰 + `/qg`(codex 모델-다양성 포함). 테스트는 **repo root에서 `-m unittest`/`bash tests/…`** (memory `spec-distill test runner`: 직접 실행 vacuous).

---

## 8. Cross-reference

- Memory: `reference_spec_distill_session_id_split.md` (`[spec-distill session-id split]`) — 이 트랩의 **클래스**를 이미 기록. 이 handoff는 그것을 v0.18.0 `reviewing-spec` 스킬의 **확정·actionable 버그**로 승격 + fix/테스트 설계를 첨부. (memory `originSessionId: 56f2bbd4-…` = §3b의 prior harness dir와 동일 — 그 세션에서 클래스를 처음 관찰.)
- Memory: `grep_lock_header_satisfiable` — §6 T2의 teeth 설계 근거.
- Memory: `feedback_review_subagent_baseline_checkout_detaches_head`, `evidence_before_approved` — fix 세션 리뷰 위생.
- CHANGELOG [0.18.0] "subagent 경계 Stop 재발동" Fixed 항목 — 이 handoff는 그 fix가 **interview-originated 플로우에서 미완**임을 보인다(락은 도입됐으나 keyed by 잘못된 sid).
