# Spec: quality-gates v2.2.0 — mutation-guard 강화 (5개 우회 봉쇄)

> v2.2.0 sandbox-executor의 Law 2 self-approval 차단 컨트롤인 `mutation-guard`가
> **5가지로 우회 가능**(대부분 throwaway repo에서 재현)함이 qg self-review에서 드러났다.
> diff 기반 oracle을 **snapshot + content-tree-hash + ignore-channel-tamper + snapshot-delta,
> 전부 fail-closed** oracle로 교체해 "verifier가 product를 몰래 고쳐 PASS를 self-emit"하는
> 경로를 *구조적으로* 닫는다. 부수적으로 7개 IMPORTANT + 2개 SUGGESTION을 함께 수정.

요청자: 사용자 (2026-06-01). 발단: `/quality-gates:quality-pipeline` Review gate iter 1
(branch `feature/qg-sandbox-executor`, diff `main...HEAD`, merge-base `13cb41d`). reviewer
5종(security-reviewer / pr-review-toolkit:code-reviewer / silent-failure-hunter /
feature-dev:code-reviewer / codex) + adversarial(Phase 1.5) 검증. 원본 findings:
`.claude/qg-review-findings-sandbox-executor.md` (이 spec이 흡수하면 삭제 가능).

**이 spec은 원본 design**
(`docs/superpowers/specs/2026-05-31-qg-runtime-verifier-sandbox-executor-design.md`)
**의 §6.7(Verdict 분류 + 구조적 self-approval 가드)을 supersede**한다. 원본의 나머지
설계(샌드박스 생애주기·blast-radius·upfront plan 등)와 round 1-3 리뷰 이력은 유지.
버전은 **2.2.0 그대로**(아직 main 미머지 — 이 fix는 2.2.0을 올바르게 ship하기 위한 완성).

## 목차

- [1. Context / Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals / Out-of-Scope](#3-non-goals--out-of-scope)
- [4. Constraints (헌장 정합)](#4-constraints-헌장-정합)
- [5. 핵심 결정 요약](#5-핵심-결정-요약)
- [6. 설계 상세](#6-설계-상세)
  - [6.1 create-sandbox: snapshot 캡처](#61-create-sandbox-snapshot-캡처)
  - [6.2 mutation-guard 재작성 (4계층, fail-closed)](#62-mutation-guard-재작성-4계층-fail-closed)
  - [6.3 create-sandbox 스크립트 hardening (S-A, S-B)](#63-create-sandbox-스크립트-hardening-s-a-s-b)
  - [6.4 SKILL R4 fail-closed 에러경로 (C-C)](#64-skill-r4-fail-closed-에러경로-c-c)
  - [6.5 fallback 정책 — SKIP_WITH_EVIDENCE cap (I-A, I-B)](#65-fallback-정책--skip_with_evidence-cap-i-a-i-b)
  - [6.6 evidence durability (I-C)](#66-evidence-durability-i-c)
  - [6.7 NEEDS_RESOLUTION retry baseline 재캡처 (I-G)](#67-needs_resolution-retry-baseline-재캡처-i-g)
  - [6.8 작은 수정 (I-F, I-E, I-D)](#68-작은-수정-i-f-i-e-i-d)
- [7. Acceptance Criteria](#7-acceptance-criteria)
- [8. Files to Modify](#8-files-to-modify)
- [9. Verification Plan](#9-verification-plan)
- [10. Rejected Alternatives](#10-rejected-alternatives)
- [11. Open Questions (plan 단계 세부)](#11-open-questions-plan-단계-세부)
- [12. Handoff Context](#12-handoff-context)
- [13. Metadata](#13-metadata)
- [14. Review revisions](#14-review-revisions)

## 1. Context / Why

원본 §6.7은 self-approval 방지를 **orchestrator의 git-diff ground-truth**로 보장한다고
선언한다 — verifier가 product를 고치면 `git -C <sandbox> diff --name-only B`가 잡아
verdict를 ≤FAIL로 강제. 그러나 qg self-review가 이 oracle을 우회하는 **5가지** 방법을
찾았고(대부분 재현), 전부 동일한 최종 피해로 귀결된다: **샌드박스는 항상 폐기(R5)되므로,
verifier가 product를 몰래 패치해 runtime check를 통과시키고 PASS를 self-emit하면, *여전히
깨진* product가 green Runtime gate를 달고 ship된다.** 이것이 가드가 막아야 할 바로 그
self-approval이다.

**5개 CRITICAL 우회:**

- **C-A `.git/info/exclude` 밀반입.** verifier(샌드박스 안에서 Bash+Write 보유)가 신규
  product 파일을 쓰고 그 이름을 `$(git rev-parse --git-common-dir)/info/exclude`(공유,
  untracked, verifier-writable)에 append → 가드의 `git check-ignore`가 honor → 파일이
  "ignored=non-product"로 분류 → `forced=no`. 재현(`onlyhack.js`).
  - 검증된 제약: `core.excludesFile=/dev/null`로는 **무력화 불가** — config는
    `info/exclude`를 override 못 함. *tamper 자체*를 탐지해야 함.
- **C-B git-failure fail-OPEN.** 가드의 모든 `git diff`/`ls-files`/`check-ignore`가
  `2>/dev/null` + `set -u`(no `-e`, no `pipefail`). git 에러(corrupt/locked index, IO,
  gitdir 상실)는 non-zero + empty stdout → "clean"과 구분 불가 → `tracked_all` 빈 값 →
  `forced=no`, exit 0. 재현(index 손상 rc=128, 실제 mutation 존재).
- **C-C SKILL R4 가드 에러경로 부재.** R4는 리터럴 `forced_downgrade: yes`에만 반응; 가드
  non-zero exit/empty/malformed에 라우팅 없음(R0는 exit code를 꼼꼼히 처리하는 것과 대조).
  errored 가드가 "not a downgrade"로 읽혀 PASS. C-B를 user-visible false green으로 증폭.
- **C-D stash / reset revert.** verifier가 product를 고친 뒤 `git stash push` (또는 `commit`
  + `git reset --hard B`) → working tree가 baseline 내용으로 복원 → `git diff B` empty,
  `ls-files --others` empty(refs/stash는 ref) → `forced=no`. 양 변종 재현.
- **C-E `assume-unchanged` / `skip-worktree` index 비트 (reviewer 5종 모두 놓침; adversarial
  발견).** `git update-index --assume-unchanged <f>` 후 tracked 파일을 고치면
  `git diff --name-only B`가 변경을 무시 → `forced=no`인데 **mutated 내용이 working tree에
  live**. C-D보다 위험(해킹 내용이 app이 실제로 구동한 tree에 잔존). 재현.

**경험적으로 확정된 fix 메커니즘 (이 spec 작성 중 throwaway repo 검증):**

1. `git diff --name-only B`는 `assume-unchanged`에 **EVADED**(빈 출력).
2. *fresh* `GIT_INDEX_FILE`로 `git add -A` 후 `git write-tree` → `assume-unchanged`·
   `skip-worktree` 둘 다 **CAUGHT**. index 비트는 repo의 *실제* index에 사는데 빈 임시
   index로 add하면 git이 전부 새로 stat → 비트 무시. → content-tree-hash가 C-E·honest
   mutation을 잡는 canonical 메커니즘.
3. 단, **C-D는 content-hash로 못 잡는다** — stash/reset이 working tree를 baseline으로
   *되돌리므로* tree-hash가 baseline과 같아짐. C-D는 오직 **snapshot delta**(stash-list /
   HEAD reflog가 create 시점 대비 변했는가)로만 잡힌다.

**위협 모델 (원본 §6.2에서 상속).** verifier는 Write+Bash를 가진 LLM agent로, (오작동/
주입으로) AC를 통과시키려 product를 고칠 수 있다. 가드는 product mutation을 **git
ground-truth로 structural하게** 잡아야 한다. 5개 우회는 모두 그 git ground-truth *계산
자체*를 깨므로 in-scope. 완전한 OS-수준 sandbox(verifier가 `rm` guard script, host
egress)는 원본 §3/§6.2가 명시적 non-goal로 인정 — 이 spec도 그 경계를 확장하지 않는다.

**부수 IMPORTANT/SUGGESTION** (같은 변경 surface라 함께 수정): I-A~I-G, S-A, S-B (§6.4–6.8).

## 2. Goals

- **5개 우회를 구조적으로 모두 봉쇄.** 각 우회에 회귀 테스트 동반(Law 3 compounding —
  가드를 탈출한 버그는 가드+테스트를 고치는 게 fix).
- **기존 8개 happy-path 가드 테스트 무손상.** 특히 git-ignored `.env` setup-only PASS 경로
  보존(`add -A`를 `-f` 없이 → tracked `.gitignore` 존중).
- **출력 계약 무변경.** 기존 2-arg `mutation-guard <sandbox> <base>` 호출이 무수정 동작 +
  보호 획득 (snapshot은 per-worktree gitdir 사이드채널).
- **fail-closed 전환.** indeterminate 가드 결과(git 실패·snapshot 부재·malformed)는 절대
  PASS가 아니라 ≤FAIL.
- **fallback 안전.** sandbox 끈 상태에서 Write verifier가 real tree에서 green을 만들 수
  없게 — verdict ≤SKIP_WITH_EVIDENCE cap.
- **evidence 생존성.** evidence-log/스크린샷이 sandbox 폐기에도 살아남아 Law 1 evidence-
  required를 실제 충족.

## 3. Non-goals / Out-of-Scope

- **완전한 OS-수준 sandbox.** verifier가 Bash로 guard script 삭제·host egress·메인 repo
  working tree 직접 변조하는 것까지 막지 않음(원본 §3/§6.2 경계 유지). 이 spec은 git
  ground-truth 계산의 무결성만 복원.
- **reflog logging flip-and-restore 변종(round 3 b7f3a219).** verifier가
  `core.logAllRefUpdates=false`로 끄고 → commit + `reset --hard B` → `true`로 *복원*하는
  경로는 git ground-truth에 흔적을 남기지 않아(logging off 동안의 commit은 reflog에 미기록,
  reset로 tree 복원, config 복원) 구조적으로 닫을 수 없다 — 위 OS-sandbox non-goal의 한 사례로
  명시적으로 수용. 단 이 변종도 working tree는 baseline으로 복원되어 *shipping product ==
  baseline*이고 다단계 config 조작을 요구한다. (config를 *끈 채 남기는* 단순 변종은 §6.2
  layer 2가 잡음 — non-goal은 복원 변종에 한정.)
- **F12 force-push regex 확장.** REFUTED — `git push` 토큰이 이미 모든 force-push 변종을
  `requires_decision`로 escalate. 비-git `tool --force-push`만 미커버이나 in-scope
  destructive surface 없음. 수정 안 함(원하면 향후 defense-in-depth).
- **fallback에서 content-hash 가드.** §6.5 결정(SKIP cap)으로 불필요 — fallback은 애초에
  PASS를 안 내므로 real tree에 PASS-보장 가드가 필요 없음.
- **runtime-verifier 능력/identity 변경.** 원본 v2.2.0 설계(executor 전환, model inherit,
  blast-radius, upfront plan)는 그대로. 이 spec은 가드 oracle + 그 주변 배선만.

## 4. Constraints (헌장 정합)

- **Law 1 (evidence-required).** §6.6 evidence durability가 이를 실제 보장(현재는 폐기로
  dangling). 가드 출력은 `forced_downgrade`·`guard_flags`·`guard_error`로 *왜* downgrade인지
  근거 surface.
- **Law 2 (Writer ≠ Reviewer, structural).** 이 spec의 본질. self-approval 차단은
  verifier 판단이 아니라 orchestrator의 git ground-truth — oracle을 *우회 불가능하게* 만들어
  원본 §6.7의 의도를 실현. `test-scope-validator`는 read-only reviewer로 불변.
- **Law 3 (compounding).** 5개 우회 각각에 회귀 테스트. 가드를 탈출시킨 원인(에러경로
  없는 보안 컨트롤 + 우회 테스트 부재)을 테스트로 봉인하는 게 compounding 이벤트.
- **P18 (bounded).** 새 루프 없음. 가드는 단발 결정론적 스크립트.
- **P21 (secret 미노출).** 가드는 파일 *내용*을 해싱하지만 해시만 비교·기록하고 내용은
  emit 안 함. snapshot 파일은 해시·config 값만 저장(secret 값 미기록).
- **보안-민감 코드.** persona(`runtime-verifier.md`) + 가드 스크립트 편집은 test-suite
  편집과 같은 신중함(CLAUDE.md). 이 spec 구현 PR은 보안 리뷰 대상.
- **lightness.** 새 P# 추가 없음 — 기존 Law 2 메커니즘의 *무결성 복구*. fail-closed·
  snapshot은 신규 원칙이 아니라 기존 가드의 올바른 구현.

## 5. 핵심 결정 요약

| 축 | 결정 | 근거 |
|---|---|---|
| oracle 메커니즘 | diff 기반 → **snapshot + content-tree-hash + ignore-tamper + snapshot-delta** | 5개 우회 각각이 diff oracle의 다른 약점을 침 |
| content 비교 | fresh `GIT_INDEX_FILE` + `add -A`(no `-f`) + `write-tree` vs `B^{tree}` | 경험적 검증: index 비트(assume-unchanged/skip-worktree) 우회 + `.gitignore` 존중 |
| C-D 처리 | content-hash 불가 → **snapshot delta**(HEAD reflog + stash list) | stash/reset이 tree를 baseline으로 복원 |
| ignore-tamper | "non-comment 라인 존재" 아닌 **create 시점 대비 변경** | 합법 pre-existing exclude false-positive 회피; config로 무력화 불가 |
| snapshot 저장 | ~~**per-worktree gitdir**, 출력 계약 무변경~~ → **SUPERSEDED by round-2** (`2026-06-02-qg-mutation-guard-round2-digest-seal-design.md` §6.1): snapshot은 여전히 gitdir에 살되 verifier-writable이므로 **orchestrator-held digest로 봉인**(출력 line 3 + guard 3-arg). 무봉인 gitdir 저장이 C-NEW-1 master-key의 근본 원인이었다. | (round-2 정정) |
| 에러 정책 | **fail-closed** — git 실패·snapshot 부재·malformed → `forced=yes` + non-zero exit | C-B; 보안 컨트롤은 fail-closed |
| R4 라우팅 | R0 미러링 — 가드 non-zero/무효 → ≤FAIL + stderr surface | C-C; "indeterminate ≠ PASS" |
| fallback | sandbox disabled → verdict **≤SKIP_WITH_EVIDENCE** (never PASS) + real-tree 변경 loud 경고 | I-A/I-B; "보장 없음 = 인증 없음" |
| evidence | 메인 repo 절대 `evidence_dir` (sandbox 밖) | I-C; R5 폐기 생존 |
| version | **2.2.0 유지** + CHANGELOG `[2.2.0]` 보강 | 미머지 base 완성 |

## 6. 설계 상세

### 6.1 create-sandbox: snapshot 캡처

baseline commit `B` 봉인 직후, 가드가 비교할 **pre-verifier 기준 상태**를 snapshot 파일에
기록. 저장 위치:

```
SNAP="$(git -C "$sandbox" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
```

`B`(working-tree 내용)가 *못 잡는* 채널만 캡처. 해싱은 포터블하게 `git hash-object --stdin`:

| 필드 | 캡처 | 닫는 우회 |
|---|---|---|
| `head_reflog_sha` | `git -C "$sandbox" reflog show HEAD` 출력 해시 (detached HEAD reflog는 per-worktree `logs/HEAD`로 격리) | C-D commit+reset |
| `stash_sha` | `git -C "$sandbox" stash list` 출력 해시 | C-D stash |
| `excl_common_sha` | common-dir `info/exclude` 내용 해시 (없으면 `absent`) | C-A |
| `excl_wt_sha` | per-worktree gitdir `info/exclude` 내용 해시 (없으면 `absent`) | C-A |
| `excludesfile` / `excludesfile_sha` | `git config --get core.excludesFile` 값 + 가리키는 파일 내용 해시 | C-A 변종 |
| `logallrefupdates` | `git config --get core.logAllRefUpdates` 값 | C-D commit+reset의 reflog-억제 우회 차단 (NEW-05) |

- snapshot은 사이드채널 → **출력 계약 2줄(sandbox, base) 그대로**. `git worktree remove`가
  gitdir째 삭제하므로 auto-clean.
- pre-existing exclude/stash가 있어도 snapshot이 그 상태를 캡처하므로 가드는 *변경*만 본다
  → false-positive 없음.
- **reflog 가용성 확정(경험적, review round 1):** `git worktree add --detach` + baseline
  commit 직후 `git reflog show HEAD`는 비어있지 않다(HEAD@{0}=baseline commit). C-D
  commit+reset 후 reflog 해시가 변함을 재현 확인. → reflog 가용성은 *closed*(open-question
  아님). 만일의 빈-reflog 환경 대비: snapshot 캡처 시 reflog가 비면 `head_reflog_sha=empty`로
  기록하고 가드는 동일 비교 규칙(불일치=`forced=yes`) 적용 — 빈 값도 정합 비교됨.
- **reflog 억제 우회 차단(NEW-05, review round 2):** verifier(Bash+Write)가
  `core.logAllRefUpdates=false`로 reflog를 끈 뒤 commit+`reset --hard B`하면 reflog가 안 자라
  layer 3가 무력화될 수 있다(reset이 tree를 복원해 layer 1도 무력). 이중 방어: (a)
  create-sandbox가 baseline commit *이전에* `git -C "$sandbox" config core.logAllRefUpdates
  true`로 로깅을 보장(default값이지만 host pre-set=false 대비) → 정직한 baseline·이후 HEAD
  이동이 모두 로깅됨; (b) snapshot이 `logallrefupdates` 값을 캡처하고 **layer 2가 이를 비교**
  — verifier가 끈 채로 남기면(또는 `always` 등 다른 값으로 바꾸면) config tamper로 `forced=yes`.
  - **side-effect(round 3 advisory):** linked worktree에서 `git -C "$sandbox" config`는
    common-dir `.git/config`(메인 repo local config)에 기록 → `core.logAllRefUpdates=true`가
    메인 repo에 영구 남음. `true`가 git default라 실무 harm은 없으나 명세상 명시. (오염
    회피가 필요하면 plan에서 `extensions.worktreeConfig` + `config --worktree`로 sandbox에
    scope하는 옵션 — 구현 세부.)
  - **잔여 gap — 명시적 non-goal(round 3 b7f3a219):** verifier가 `false`로 끄고 → commit +
    `reset --hard B` → **`true`로 복원**하는 변종은 어떤 계층도 못 잡는다(layer 2: now==snapshot
    `true` → 통과; layer 3: off 구간 commit이 reflog에 흔적 없음 → 통과; layer 1: reset로 tree
    복원 → 통과). logging이 off였던 commit은 **git ground-truth에 흔적이 없어** OS-level 통제
    없이는 구조적으로 닫을 수 없다 → 원본 §3 OS-sandbox non-goal 상속(§3에 명시). 단 이 변종도
    working tree는 baseline으로 복원되므로 *shipping product == baseline*이며, 다단계 git config
    조작을 요구하는 sophisticated 경로다.
- **common-dir ≠ per-worktree gitdir(중복 아님):** 샌드박스는 항상 *linked* worktree
  (`git worktree add`)라 common-dir(메인 `.git`)과 per-worktree gitdir
  (`.git/worktrees/rt-<sid>`)이 항상 구별됨 → `excl_common_sha`/`excl_wt_sha`는 서로 다른
  파일을 캡처. (main worktree=`.git` 단일 케이스는 발생하지 않음 — 샌드박스는 main worktree가
  아님.) 둘 다 검사하므로 어느 채널의 tamper든 잡힘.

### 6.2 mutation-guard 재작성 (4계층, fail-closed)

계약 동일: `mutation-guard <sandbox> <base>`. snapshot은 gitdir에서 자동 발견.

**실행 순서 (locked):** 계층 0 토대 검증 → 계층 1 content-hash → 계층 2 ignore-tamper →
계층 3 snapshot-delta → `forced_downgrade` 집계. `forced`는 계층 1–3의 **OR 누적**이라
결과는 순서 무관이지만, 계층 0의 git 실패는 *즉시* fail-closed(이후 계층 미실행). 구현은 이
순서를 고정한다(보고 일관성).

**계층 0 — fail-closed 토대 (C-B).** `guard_fail(reason)` 헬퍼: 임의 git 명령 rc≠0이면
`tracked_diff: []` / `disallowed_new_files: []` / `forced_downgrade: yes` /
`guard_error: '<reason>'` emit 후 **non-zero exit `=4` (locked; die=2·kill-switch=3과
구별)**. 회귀 테스트는 exit code가 정확히 4인지 assert(H-AC1).
detection 명령의 `2>/dev/null` 폐기 → stderr 캡처해 reason에. snapshot 파일 부재 **또는
필수 key 누락/truncated**(예: create-sandbox 중 kill·디스크 포화)도 `guard_fail`(snapshot이
안 떴거나 손상된 sandbox는 indeterminate, NEW-03). 구현: §6.1 표의 **모든 캡처 key**
(`head_reflog_sha`·`stash_sha`·`excl_common_sha`·`excl_wt_sha`·`excludesfile`·
`excludesfile_sha`·`logallrefupdates` — §6.1 표와 1:1 일치)의 *존재*를 파싱 시 assert —
누락 key를 빈 문자열로 읽어 `""==""` 비교로 `forced=no`가 되는 경로를 봉쇄. (key 목록은 §6.1
표가 single source of truth; 구현·테스트는 그 표를 기준으로 — round 3 d4c8e031.) baseline
`B` 존재 확인(`cat-file -e`)도 `guard_fail`로.

**계층 1 — content tree-hash (C-E + honest mutation).** fresh 임시 index로 working tree
재독:
```
idx="$(git -C "$sandbox" rev-parse --absolute-git-dir)/qg-tmp-idx.$$"; rm -f "$idx"
GIT_INDEX_FILE="$idx" git -C "$sandbox" add -A -- .   # rc 명시 검사 → 실패 시 guard_fail
cur_tree=$(GIT_INDEX_FILE="$idx" git -C "$sandbox" write-tree)   # rc 검사
base_tree=$(git -C "$sandbox" rev-parse "${base}^{tree}")        # rc 검사
rm -f "$idx"   # 사용 후 즉시 제거
```
`cur_tree != base_tree` → content 변경(`forced=yes`). fresh index가 index 비트를 무시
(§1 검증). `-f` 없음 → tracked `.gitignore`(B의 일부) 존중 → 합법 `.env` PASS 경로 보존.
`add` 실패를 tree mismatch로 추론하지 말고 **rc로 직접** 판정(빈 index의 empty-tree가 그냥
"다름"으로 읽히는 함정 회피 — adversarial 지적).
- **index 경로(locked):** `mktemp; rm`(TOCTOU 창) 대신 **per-worktree gitdir 하위의
  pid-unique 경로**(`$gitdir/qg-tmp-idx.$$`, 존재하지 않는 파일)를 `GIT_INDEX_FILE`로 →
  git이 fresh index를 생성. gitdir 내라 동시 다른 프로세스 침투 창이 없고, 사용 후 `rm -f`.
- **`.gitignore` tamper 닫힘(경험적, review round 1):** verifier가 tracked `.gitignore`를
  수정해 신규 product 파일을 ignore로 숨겨도, `.gitignore`는 *tracked*라 그 수정 자체가
  `cur_tree`에 반영돼 `tracked_diff`의 `M .gitignore`로 잡힘 → `forced=yes`. 숨긴 파일이
  `add -A`(no `-f`)에서 빠져도 `.gitignore` 변경이 이미 downgrade를 유발(재현 확인). 즉
  계층 2는 `info/exclude`/`core.excludesFile`(untracked 채널)을 보고, tracked `.gitignore`는
  계층 1이 커버 — 두 채널 분담으로 ignore 우회 전부 닫힘.

**계층 2 — ignore-channel + config tamper (C-A, NEW-05).** §6.1의 exclude/excludesFile 해시
**및 `core.logAllRefUpdates` 값**을 *지금* 재계산해 snapshot과 비교. 불일치 → `forced=yes` +
`guard_flags`에 `ignore_channel_tampered`(exclude/excludesFile 변경) 또는
`reflog_logging_tampered`(logAllRefUpdates 변경 — verifier가 reflog를 꺼 C-D를 숨기려는 시도).
(info/exclude로 숨긴 파일은 `add -A`가 못 보지만 *tamper 자체*를 잡아 ≤FAIL.)

**계층 3 — snapshot delta (C-D).** `head_reflog_sha`·`stash_sha`를 지금 재계산해 비교.
불일치 → `forced=yes` + `guard_flags`에 `reflog_advanced` / `stash_added`. absolute
`rev-list --all --not $base`는 **금지**(공유 object store의 sibling 브랜치 false-positive
— adversarial 검증).

**보고 필드 (surfacing; 기존 두 필드 유지 → 8 happy-path 호환):**
- `tracked_diff`: `git diff --name-status "$base_tree" "$cur_tree"`의 `M/D/T/R/C` 경로
  (tracked 변경/삭제/typechange).
- `disallowed_new_files`: 같은 diff의 `A`(=`.gitignore` 통과한 신규 파일) **∪**
  `ls-files --others`의 신규 **symlink**(ignored여도 — "symlink는 타겟 무관 product" 규칙
  보존, 원본 §6.7-2).
- 모든 파일명은 **`yq()` 헬퍼**(`s=$(printf '%s' "$f" | sed "s/'/''/g"); printf "'%s'" "$s"`)
  로 YAML 단일인용 escape (**I-D** — single-quote 파일명이 invalid YAML을 만들던 것 수정).

`forced_downgrade` = (계층1 content 변경) ∨ (신규 product 파일/symlink) ∨ (계층2 tamper)
∨ (계층3 delta). 하나라도 → `yes`.

**우회 × 계층 coverage matrix (검증용 — §9가 이 표의 각 셀을 테스트):**

| 우회 | 잡는 계층 | 메커니즘 |
|---|---|---|
| honest mutation (tracked) | 1 | `cur_tree != base_tree` |
| C-E assume-unchanged | 1 | fresh index가 비트 무시 → content 차이 (§1 검증) |
| C-E skip-worktree | 1 | 동상 (독립 테스트) |
| 신규 non-ignored 파일 | 1 (보고: `disallowed_new_files`의 `A`) | `add -A`가 staging |
| 신규 symlink (ignored 포함) | 보조 — `ls-files --others` symlink 합집합 | "symlink=항상 product" |
| C-A `info/exclude`(common) | 2 | `excl_common_sha` 불일치 |
| C-A `info/exclude`(per-worktree) | 2 | `excl_wt_sha` 불일치 |
| C-A `core.excludesFile` | 2 | `excludesfile`/`_sha` 불일치 |
| C-A `.gitignore` 수정 | **1** | tracked `.gitignore` 변경이 content-hash에 반영 |
| C-D stash push | 3 | `stash_sha` 불일치 |
| C-D commit + `reset --hard B` | 3 | `head_reflog_sha` 불일치 (working tree는 복원되어 계층 1엔 안 잡힘) |
| C-D + reflog 억제, config를 *끈 채 남김* | 2 | config tamper 비교 → `reflog_logging_tampered` (NEW-05) |
| C-D + reflog 억제, config *flip-and-restore* | — (non-goal) | git 흔적 없음 → §3 OS-sandbox non-goal 명시 수용 (b7f3a219) |
| C-B git 실패 | 0 | rc≠0 → `guard_fail` exit 4 |
| snapshot 부재 / 필수 key 누락·손상 | 0 | fail-closed (NEW-03) |

**matrix scope:** 위 표는 **guard-script 계층(0–3)** 범위다. **C-C(SKILL R4 fail-closed
에러경로)는 guard script가 아니라 SKILL orchestration 계층(§6.4)에서 처리** — H-AC6 + §9
정적 테스트가 별도로 커버. 따라서 *5개 우회 전부 닫힘 = 이 matrix(C-A·C-B·C-D·C-E) + §6.4
(C-C)의 합산*이며, matrix 자체에 빈 셀은 없다(guard-script 범위 내 gap 없음). C-C를 guard
script 테스트에 넣지 말 것(SKILL 계층 테스트가 담당, NEW-01/02).

### 6.3 create-sandbox 스크립트 hardening (S-A, S-B)

- **S-A**: overlay 루프의 `mkdir -p`/`cp -a` 및 deletion 루프에 `|| die` — per-file 실패가
  불완전 baseline `B`를 silent 봉인(가드 ground-truth 오염)하는 것 차단. silently-partial
  보다 abort 우선.
- **S-B**: `cd "$x" && pwd -P` command-sub 4곳(현 `:62,88,207,217`)에 `|| die` — 특히
  `remove`의 namespace 안전검사가 stale path로 약화되는 것 방지.

### 6.4 SKILL R4 fail-closed 에러경로 (C-C)

R0의 exit-code 규율을 R4에 미러링:

| 가드 결과 | R4 라우팅 |
|---|---|
| exit 0 + `forced_downgrade: no` (유효 key) | downgrade 없음 → 정상 진행 |
| exit 0 + `forced_downgrade: yes` | verdict ≤FAIL + `tracked_diff`/`disallowed_new_files`/`guard_flags` surface |
| **non-zero exit** ∨ `forced_downgrade` key 누락·무효 ∨ `guard_error` 존재 | **`forced=yes` 간주(≤FAIL)** + 가드 stderr verbatim surface + Runtime gate failed |

원칙: **indeterminate 가드 결과는 절대 PASS가 아니다.** 정직한 가드는 exit 0 + 유효 key라
happy-path 무영향.

### 6.5 fallback 정책 — SKIP_WITH_EVIDENCE cap (I-A, I-B)

`DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1` → sandbox 없음, Write verifier가 real working tree
에서 구동.
- **I-B**: dispatch가 `project_dir: "$sandbox_dir"`(exit-3 시 unset) 하드코딩 → 단일
  **`runtime_project_dir`** 변수(sandbox 성공=sandbox_dir / fallback=메인 project_dir).
  R4/R5를 `sandbox_dir`·`baseline_sha` 존재 여부로 조건화(fallback은 가드/제거 skip).
- **I-A**: fallback verdict를 **≤SKIP_WITH_EVIDENCE로 cap — 절대 PASS 아님**. "sandbox
  없음 = 구조적 Law 2 보장 없음 = 인증 안 함." smoke evidence·FAIL 탐지는 제공.
- 추가 안전: fallback에서 SKILL이 real tree를 pre/post(`git status --porcelain` +
  tracked content tree-hash) 비교해 *변경됐으면* **loud 경고**. 경고 계약(locked): SKILL이
  **사용자-visible stdout**에 `[quality-gates] WARNING: runtime fallback에서 working tree가
  변경됨 — <변경 파일 목록>. sandbox 미사용으로 구조적 보호 없음; 검토 요망.` 한 줄을 출력
  **AND** evidence_dir(§6.6)에 기록. verdict 영향 없음(이미 ≤SKIP cap) — 순수 안전 신호이며
  무시해도 gate는 진행(P18: 추가 차단 루프 없음).

### 6.6 evidence durability (I-C)

evidence-log + 스크린샷이 상대 `.claude/...`로 기록 → verifier project_dir=sandbox라 sandbox
내부 → R5 `remove` 삭제 → Evidence Log dangling.
- SKILL이 R3 dispatch에 **절대 `evidence_dir`**를 명시 파라미터로 thread. 정의:
  `<project_dir>/.claude/quality-gates/<sid>/` (preflight `project_dir` = 메인 repo,
  sandbox_dir 아님). `<sid>` = **`CLAUDE_CODE_SESSION_ID`** — pipeline state 파일
  `.claude/quality-gates/<sid>/pipeline.md`와 동일 값(이미 SKILL이 보유). evidence_dir는
  절대 경로로 R3 prompt에 주입; H-AC8 정적 assert가 `.claude/quality-gates/.*/`(절대) 패턴을
  확인.
- `runtime-verifier.md`: product/서비스 파일은 sandbox(project_dir)에, **evidence는 절대
  `evidence_dir`에** 기록하도록 분리 명시.
- `detect-runtime.sh`의 `attempted_log_path`도 절대 경로 emit.
- evidence_dir는 sandbox 밖 메인 repo라 R5 생존. evidence는 product 아님(git-ignored
  `.claude/`)이라 가드 트리거 안 함.

### 6.7 NEEDS_RESOLUTION retry baseline 재캡처 (I-G)

retry가 "re-create sandbox (R0)"만 말하고 `baseline_sha` 재캡처 미명시 → 옛 sha 재사용 시
가드 `guard_fail "bad baseline sha"` → false FAIL. 수정 문구: **"R0 재실행 후 새 출력의
`sandbox_dir`(line 1) + `baseline_sha`(line 2)를 *둘 다* 재캡처해 orchestrator 변수 갱신 후
R3 re-dispatch. 새 snapshot은 새 gitdir에 자동 기록됨."**

**snapshot 충돌 없음:** `create-sandbox`(R0)는 idempotent — stale sandbox가 남아 있으면
`git worktree remove --force` + `git worktree prune`로 *그 gitdir의 옛 snapshot까지* 함께
제거한 뒤 새로 생성(현 qg-worktree.sh L93–99 동작). 따라서 retry 시 동일 base에 두 snapshot이
공존하지 않음. (이전 sandbox가 R5로 이미 폐기됐든, retry 직전까지 남아 있든 R0가 정리.)

### 6.8 작은 수정 (I-F, I-E, I-D)

- **I-F** `detect-runtime.sh:196` — bare `$HOME` → `${HOME:-}` + 루프 빈 엔트리 skip. unset
  `$HOME`이 manifest emit 전체를 abort(blast-radius 게이트 미발동)시키던 것 차단.
- **I-E** kill-switch 문서화 — `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1`을 README "Runtime
  gate 단위 disable" **source-of-truth 표** + `qg.md` env 표에 추가(CLAUDE.md kill-switch
  문서화 의무; v2.2.0 헤드라인 스위치 누락).
- **I-D** — §6.2 `yq()` 헬퍼로 해결(single-quote 파일명 YAML escape).

## 7. Acceptance Criteria

1. **H-AC1 (fail-closed)**: 가드의 임의 git 명령 실패 시 `forced_downgrade: yes` +
   non-zero exit **`=4`**; snapshot 부재 **또는 필수 key 누락/손상**도 fail-closed(exit 4).
   (C-B, NEW-03)
2. **H-AC2 (content-hash, C-E)** — 독립 2케이스: **H-AC2a** `git update-index
   --assume-unchanged <f>` 후 tracked mutation → `forced=yes`; **H-AC2b** `--skip-worktree
   <f>` 후 tracked mutation → `forced=yes`. (둘은 git 내부 처리가 달라 각각 assert.)
3. **H-AC3 (ignore-tamper, C-A)** — 4채널 각각 신규 product 파일과 함께: **(i)** common-dir
   `info/exclude` append → `forced=yes` + `ignore_channel_tampered`; **(ii)** per-worktree
   gitdir `info/exclude` → 동일; **(iii)** `core.excludesFile` 설정 → 동일; **(iv)** tracked
   `.gitignore` 수정으로 신규 파일 은닉 시도 → `tracked_diff`의 `.gitignore` 변경으로
   `forced=yes`(계층 1 커버).
4. **H-AC4 (snapshot-delta, C-D)**: (a) product 변경 + `git stash push -u`, (b) product
   변경 + `commit` + `git reset --hard B` → 둘 다 `forced=yes`; **(c)** `git config
   core.logAllRefUpdates false`로 *끈 채* (b) 반복(persistent 억제) → `forced=yes` +
   `reflog_logging_tampered` (NEW-05). *flip-and-restore 변종(끄고→작업→복원)은 §3 명시적
   non-goal이라 closure assert 대상이 아님(b7f3a219).*
5. **H-AC5 (YAML)**: single-quote 포함 파일명 → 가드 출력이 유효 YAML + `forced=yes`. (I-D)
6. **H-AC6 (R4 라우팅)**: SKILL R4가 가드 non-zero exit·무효 출력을 ≤FAIL로 라우팅(정적
   grep으로 R4 에러경로 절 존재 + stderr surface 문구 assert). (C-C)
7. **H-AC7 (fallback)**: sandbox disabled → Runtime gate verdict ≤SKIP_WITH_EVIDENCE(PASS
   불가) + real-tree 변경 시 loud 경고; dispatch가 `runtime_project_dir` 사용(정적 assert:
   fallback 블록에 `sandbox_dir` 하드코딩 부재). (I-A, I-B)
8. **H-AC8 (evidence durability)**: `evidence_dir`이 메인 repo 절대경로로 thread되고 R5
   `remove` 후 evidence-log 생존(정적: SKILL R3 dispatch에 절대 evidence_dir; persona가
   evidence_dir에 기록). (I-C)
9. **H-AC9 (retry)**: NEEDS_RESOLUTION retry 문구가 `baseline_sha` + `sandbox_dir` 둘 다
   재캡처 명시(정적 grep). (I-G)
10. **H-AC10 (회귀 무손상)**: 기존 8개 happy-path 가드 테스트 + `env -u HOME` manifest
    비어있지 않음 + README/qg.md kill-switch 문서 존재 — 전부 green.

## 8. Files to Modify

- **`plugins/quality-gates/scripts/qg-worktree.sh`** — create-sandbox snapshot 캡처(§6.1)
  + S-A/S-B hardening(§6.3) + mutation-guard 4계층 재작성(§6.2) + `yq()` 헬퍼.
- **`plugins/quality-gates/skills/quality-pipeline/SKILL.md`** — R4 fail-closed
  에러경로(§6.4) + fallback `runtime_project_dir` & SKIP cap & real-tree 경고(§6.5) +
  evidence_dir thread(§6.6) + retry baseline 재캡처 문구(§6.7).
- **`plugins/quality-gates/scripts/detect-runtime.sh`** — `${HOME:-}`(§6.8 I-F) +
  `attempted_log_path` 절대경로(§6.6).
- **`plugins/quality-gates/agents/runtime-verifier.md`** — evidence를 절대 `evidence_dir`에
  기록하도록 분리 명시(§6.6). (보안-민감 persona 편집)
- **`plugins/quality-gates/README.md`** — Runtime gate 단위 disable 표에
  `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX` 추가(§6.8 I-E).
- **`plugins/quality-gates/commands/qg.md`** — env 표에 동 kill-switch 추가(§6.8 I-E).
- **`plugins/quality-gates/CHANGELOG.md`** — `[2.2.0]` Security/Fixed에 snapshot 기반
  hardened oracle + fail-closed + fallback SKIP cap 반영.
- **테스트:**
  - `tests/test_qg_mutation_guard.sh` 확장 — C-A(4채널)/C-B/C-D(3변종: stash·reset·reflog-
    억제)/C-E(2)/I-D + snapshot-missing·malformed fail-closed. 기존 8 케이스 green 유지.
  - `tests/harness/test_skill_orchestration_behavior.sh` 확장 — R4 에러경로(C-C),
    fallback SKIP-cap & `runtime_project_dir`(H-AC7), retry baseline 재캡처(I-G),
    evidence_dir 절대경로 thread(H-AC8) 정적 assert.
  - `tests/test_detect_runtime.sh` 확장 — `env -u HOME`에서 manifest emit 비어있지 않음(I-F).
- **`plugin.json`** — version 2.2.0 유지(변경 없음 — 명시).

## 9. Verification Plan

- **실행 위치:** 모든 bash/py 테스트는 **repo root에서** 실행(qg cwd 계약). qg는 CI 없음 +
  main에 기존 stale red 8개(codex/consent/security/sandbox) + pytest collection error 3개 →
  작업 전 baseline 캡처 후 **신규/수정 테스트의 green만** 회귀 판정.
- **우회 봉쇄 positive 테스트** (H-AC1–5): 각 우회를 throwaway repo에서 *재현*하는 fixture로
  `forced_downgrade: yes`(+ 해당 `guard_flags`) assert. 특히:
  - C-E (2케이스): (a) `git update-index --assume-unchanged <f>` 후 mutation → `forced=yes`;
    (b) `--skip-worktree <f>` 후 mutation → `forced=yes`. 각각 독립 assert(H-AC2a/2b).
  - C-A (4채널): (i) 신규 파일 + `$(git rev-parse --git-common-dir)/info/exclude` append;
    (ii) 신규 파일 + per-worktree gitdir(`rev-parse --absolute-git-dir`)/info/exclude append;
    (iii) 신규 파일 + `git config core.excludesFile <tmp>` 설정; (iv) tracked `.gitignore`에
    신규 파일명 추가 후 그 파일 생성 → (i)–(iii)는 `forced=yes` + `ignore_channel_tampered`,
    (iv)는 `forced=yes` + `tracked_diff`에 `.gitignore`. (H-AC3)
  - C-D-a: mutation + `git stash push -u` → `forced=yes` + `stash_added`.
  - C-D-b: mutation + `commit` + `reset --hard B` → `forced=yes` + `reflog_advanced`.
  - C-D-c (NEW-05): `git config core.logAllRefUpdates false`로 *끈 채* mutation + `commit` +
    `reset --hard B` → `forced=yes` + `reflog_logging_tampered`(config를 끈 채 남기면 layer 2
    값 비교에 잡힘). flip-and-restore(복원) 변종은 §3 non-goal — closure 테스트 없음(b7f3a219).
  - C-B: 임시 index 파일을 garbage로 덮거나 baseline SHA를 손상 → `guard_fail` 경로(
    `forced=yes` + non-zero exit `=4` + `guard_error`).
  - I-D: `foo'bar.js` 신규 파일 → 출력이 `python3 -c "import yaml; yaml.safe_load(...)"`로
    파싱되고 `forced=yes`.
  - snapshot-missing / malformed (NEW-03): (a) gitdir의 snapshot 파일을 지운 뒤 가드,
    (b) snapshot에서 필수 key 한 줄 제거(truncate) 후 가드 → 둘 다 fail-closed(exit 4).
- **happy-path 무손상** (H-AC10): 기존 8 케이스(clean / tracked change / 독립성 re-run /
  ignored `.env` PASS / non-ignored 신규 / 신규 symlink / tracked 삭제 / YAML-metachar)
  전부 green 재확인.
- **정적 검증** (H-AC6,7,8,9): orchestration behavior 테스트가 SKILL.md의 R4 에러경로 절·
  fallback SKIP cap·`runtime_project_dir`·evidence_dir 절대경로·retry baseline 재캡처
  문구를 grep으로 assert.
- **문서**: README/qg.md에 `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX` 존재 grep(I-E).
- **I-F**: `env -u HOME bash detect-runtime.sh`가 non-empty manifest emit + rc 0.

## 10. Rejected Alternatives

- **최소 fail-closed + content-hash만 (C-A·C-D residual 수용)** — 5개 중 2개 우회를 열어두면
  "우회 불가능한 구조적 가드" 전제가 무너짐. 보안 컨트롤 절반 수정은 lightness가 아니라
  구멍. → 기각, 통합 oracle 채택.
- **verifier git surface 제한(sandbox git hook으로 assume-unchanged/stash 차단 or persona
  금지)** — Bash 쥔 agent가 hook·persona를 우회 가능. 원본 §6.2가 가드는 structural이어야
  한다고 요구. → 주 방어로 기각(persona 금지 문구는 보조 레이어로만).
- **content-hash로 C-D 처리** — stash/reset이 working tree를 baseline으로 복원하므로
  tree-hash가 baseline과 같아져 못 잡음(검증). → snapshot delta 필수.
- **`core.excludesFile=/dev/null`로 info/exclude 무력화** — config는 info/exclude를
  override 못 함(검증). → tamper 직접 탐지.
- **absolute `rev-list --all --not $base`로 새 commit 탐지** — 공유 object store의 sibling
  브랜치에 false-positive(adversarial 검증). → bounded pre/post snapshot delta.
- **snapshot을 create-sandbox 출력 3번째 줄로** — (당시 기각: 출력 계약 변경 → 2-arg 호출/테스트
  깨짐.) **REVERSED by round-2** (`2026-06-02-qg-mutation-guard-round2-digest-seal-design.md` §6.1):
  snapshot *내용*은 gitdir에 두되 그 *digest*를 출력 line 3로 emit해 orchestrator가 보유 →
  3-arg guard로 봉인. "계약 무변경"의 편의가 정확히 master-key(C-NEW-1)를 만들었으므로 계약 변경
  비용을 수용한다.
- **fallback content-hash 가드로 PASS 허용** — Write verifier가 real tree를 변조하는
  transient window + crash 시 dirty 잔존 + C-D blind. → SKIP_WITH_EVIDENCE cap(사용자 선택).
- **fallback에서 verifier read-only로 dispatch** — frontmatter Write를 per-dispatch
  revoke 불가(adversarial). → SKIP cap으로 verdict 차단.
- **F12 force-push regex 확장** — REFUTED(`git push` 토큰이 이미 escalate). → 미수정.

## 11. Open Questions (plan 단계 세부)

설계 결정은 모두 closed. 구현 세부만 writing-plans에서:

- **포터블 해싱 커맨드 확정** — `git hash-object --stdin` vs `shasum -a 256`/`sha256sum`
  (macOS/Linux 차이). 메커니즘은 "내용 해시 비교"로 locked, 커맨드만 plan. (`git hash-object`
  권장 — git 컨텍스트 내라 항상 가용.)
- **회귀 fixture 작성 형태** — C-A~C-E 재현을 `test_qg_mutation_guard.sh`의 `mk_sandbox`
  헬퍼 확장으로 할지 별도 헬퍼로 할지.

> **review round 1에서 closed (구현 세부에서 격상·확정):** detached HEAD reflog 가용성
> (경험적 확인 — §6.1) / `guard_fail` exit code(=4 locked — §6.2) / 4계층 실행 순서(§6.2) /
> `.gitignore` tamper 봉쇄(§6.2) — 모두 보안-관련이라 plan defer 대신 spec에서 확정.

## 12. Handoff Context

**TL;DR (3줄).**
1. v2.2.0 mutation-guard가 5가지로 우회됨(info/exclude·git-fail·R4-부재·stash/reset·
   assume-unchanged) → diff oracle을 snapshot+content-hash+ignore-tamper+snapshot-delta
   fail-closed oracle로 교체.
2. 경험적 검증: fresh-index `add -A`가 index 비트 우회 / content-hash는 C-D 못 잡음(snapshot
   delta 필수) / info/exclude는 config로 무력화 불가(tamper 직접 탐지).
3. snapshot은 per-worktree gitdir에 → 출력 계약 무변경. fallback은 SKIP cap(never PASS).
   버전 2.2.0 유지.

**Implicit context (대화에서 결정).**
- 사용자가 Retry(즉시 적용)에서 **spec 먼저**로 전환 — 보안-민감 scope-growth는 명세 먼저
  (CLAUDE.md "스코프 커지면 spec 먼저").
- spec 형태: 원본 §6.7을 supersede하는 **새 hardening spec**(사용자 선택), 버전 2.2.0 유지.
- fallback: **SKIP_WITH_EVIDENCE cap**(사용자 선택) — content-hash PASS 대안 기각.
- 5개 우회 중 C-E는 reviewer 5종 모두 놓치고 adversarial이 발견 — content-hash가 핵심.

**원본 spec과의 관계.** 이 spec은 원본의 §6.7만 supersede. 원본 §6.1–6.6, §6.8, §6.9
(샌드박스 생애주기·AC 단언·upfront plan·운영 안전·Law 2 docs)는 유효. 원본 §9의 가드
테스트 항목은 이 spec §9가 확장.

**Deferred to plan (§11).** 포터블 해싱 커맨드 선택 / 회귀 fixture 작성 형태 — 구현 세부만.
(reflog 가용성·`guard_fail` exit code·4계층 순서·`.gitignore` tamper 봉쇄는 review에서 spec
내 확정됨 — §6.1/§6.2, §11 footer 참조. plan에 재논의 거리 아님.)

## 13. Metadata

- **Plugin:** quality-gates
- **Version:** v2.2.0 유지 (미머지 base 완성 — bump 없음; CHANGELOG `[2.2.0]` 보강)
- **요청자:** 사용자 (2026-06-01)
- **발단:** qg self-review (`feature/qg-sandbox-executor`), reviewer 5종 + adversarial.
- **supersedes:** 원본 design `2026-05-31-...-sandbox-executor-design.md` **§6.7**.
- **헌장 영향:** 없음(신규 P# 없음) — 기존 Law 2 가드 메커니즘의 무결성 복구.
- **보안-민감:** mutation-guard(보안 컨트롤) + persona(`runtime-verifier.md`) 편집 — 신중
  리뷰 대상. 구현 PR은 qg self-review 재실행 권장(이번엔 green이어야 함).

## 14. Review revisions

- **round 1 (spec-reviewer, 2026-06-01):** needs_revise 14건(전부 `ambiguity`/`isolation`/
  `testing`/`handoff`, `affects_locked` 없음 — design mode). 보안-관련 2건은 경험적으로
  확정 후 반영, 나머지는 명확성 보강.
  - C-D commit+reset reflog 가용성을 plan으로 defer(8a3e0c17, b2c47e8f) → **§6.1에서
    경험적 확정**(detached worktree reflog 비어있지 않음, commit+reset 후 해시 변함) +
    빈-reflog fallback 규칙. open-question에서 제거.
  - `.gitignore` 수정으로 신규 파일 은닉 가능성(d5e83f7a, 총평#2) → **§6.2에서 경험적
    확정**(tracked `.gitignore` 변경이 content-hash에 잡힘) + §6.2 coverage matrix에 명시.
  - 4계층 실행 순서 미명시(e3f2a1c4) → §6.2 순서 locked(0→1→2→3→집계).
  - `mktemp; rm` TOCTOU + GIT_INDEX_FILE 경로(7a4b9d21) → §6.2 pid-unique gitdir 경로.
  - `guard_fail` exit code 미확정(9c6d7e2f) → §6.2 **=4 locked**, H-AC1이 assert.
  - C-E skip-worktree AC 미분리(e1a4d8b9) → §7 H-AC2a/2b 분리 + §9.
  - C-A 3채널 중 2채널 untested(f3c2a9e0) → §7 H-AC3 4채널(+`.gitignore`) + §9.
  - 우회×계층 coverage matrix 부재(f7d109c3) → §6.2 matrix 추가(검증 가능성).
  - common-dir/per-worktree gitdir 중복 우려(c9f01e5b) → §6.1 "linked worktree라 항상 구별".
  - fallback "loud 경고" 형태 미정(a08e2b14) → §6.5 stdout+evidence_dir 계약.
  - evidence_dir `<sid>` 미정의(c7b1f4d5) → §6.6 = `CLAUDE_CODE_SESSION_ID`.
  - retry snapshot 충돌(3b5f8c01) → §6.7 R0 idempotent(stale gitdir+snapshot force-remove).
  - 원본 §6.7 supersede 후 forward-ref(handoff-01) → 원본 §6.7 상단에 supersede 포인터 추가.
- **round 2 (spec-reviewer, 2026-06-01):** round-1 13건 전부 RESOLVED 확인. 신규 5건 반영
  (모두 revision이 추가한 내용을 더 파고든 것; `affects_locked` 없음).
  - **NEW-05 (보안 — reflog 억제 우회):** verifier가 `core.logAllRefUpdates=false`로 reflog를
    꺼 C-D commit+reset을 숨기면 layer 3 무력(layer 1도 reset로 무력) → **§6.1 logallrefupdates
    snapshot 캡처 + create-sandbox 강제 true + §6.2 layer 2가 config 변경을 tamper로 탐지**
    (`reflog_logging_tampered`). matrix·H-AC4(c)·§9 C-D-c 반영.
  - **NEW-03 (보안 — malformed snapshot):** snapshot 존재하나 필수 key 누락/truncated 시 빈
    문자열 비교로 `forced=no`가 되던 경로 → §6.2 layer 0에 key-존재 assert → `guard_fail`.
    H-AC1·§9 반영.
  - NEW-01/02 (matrix scope): coverage matrix가 C-C(SKILL 계층)를 포함하지 않은 채 "gap
    없음" 주장 → §6.2 matrix footer를 "guard-script 0–3 범위 + C-C는 §6.4/H-AC6" 로 scope 명시.
  - NEW-04 (문서 모순): §12 "Deferred to plan"이 §11과 달리 reflog/exit-code를 여전히 deferred로
    열거 → §12에서 제거(spec 내 확정 명시).
- **round 3 (spec-reviewer, 2026-06-01):** round-2 5건 전부 RESOLVED 확인. 신규 2건 반영
  (수렴: 14→5→2, 재-raise 0, signal=false).
  - **b7f3a219 (보안 claim 정확성):** NEW-05의 logAllRefUpdates 비교는 config를 *끈 채 남기는*
    경우만 잡고, *flip-and-restore*(끄고→commit+reset→복원) 변종은 git 흔적이 없어 어떤 계층도
    못 잡음 → matrix가 "닫힘"으로 과장. **§3에 명시적 non-goal로 수용** + §6.1/§6.2 matrix/
    H-AC4(c)/§9를 "persistent=closed, restore=non-goal"로 정정. (메커니즘 추가 대신 정직한
    범위 선언 — OS-sandbox 없이는 구조적 불가.) 부수: §6.1에 shared-config side-effect note.
  - **d4c8e031 (completeness):** `excludesfile_sha`가 §6.1 캡처엔 있으나 §6.2 layer-0 assert
    목록에서 누락 → NEW-03의 `""==""` false-no 경로 잔류 → §6.2를 "§6.1 표가 key SSoT,
    모든 캡처 key를 assert"로 정정.
