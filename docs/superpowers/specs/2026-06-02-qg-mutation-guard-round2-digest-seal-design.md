# Spec: quality-gates v2.2.0 — mutation-guard round-2 (digest-seal custody)

> round-1.5 hardening이 5개 우회를 닫았으나, **그 hardening 자체에서 6번째 CRITICAL 우회**가
> qg self-review(Law 3 closure)로 발견됐다: snapshot이 verifier-writable gitdir에 살아
> **피검증자가 신뢰 기준을 위조**할 수 있다(master-key, Layer 2·3 무력화, 3중 재현).
> round-2는 신뢰 기준을 **orchestrator-held digest로 봉인**(verifier-unreachable)하고,
> snapshot-독립 baseline-anchored detector(b-precise)를 defense-in-depth로 추가하며,
> empty-index false-positive(I-NEW-2)와 *이 우회를 놓친 review 메커니즘*(persona + vacuous test)을
> 함께 고친다.

요청자: 사용자 (2026-06-02). 발단: `/quality-gates:quality-pipeline` self-review를
`feature/qg-sandbox-executor`(HEAD `3bbd16c`, v2.2.0) 대상으로 재실행(Law 3 closure 목적).
Review gate deep roster(security-reviewer + silent-failure-hunter + pr-review-toolkit:code-reviewer +
pr-test-analyzer + codex + adversarial)가 **mutation-guard hardening 자체에서 CRITICAL 우회 1건
+ IMPORTANT 오탐 1건**을 발견. 직전 whole-branch opus 리뷰의 "Ready to merge"를 뒤집음.
원본 findings: `.claude/qg-mutation-guard-round2-findings.md` (이 spec이 흡수하면 삭제 가능).

**이 spec은 round-1.5 hardening spec**
(`docs/superpowers/specs/2026-06-01-qg-mutation-guard-hardening-design.md`)
**의 §5 "snapshot 저장=per-worktree gitdir" 결정과 §10 "snapshot을 출력 3번째 줄로" 기각을
supersede**한다. 그 두 결정("출력 계약 무변경"의 편의)이 정확히 C-NEW-1의 근본 원인이다.
나머지 round-1.5 설계(4계층 oracle 골격·fail-closed·fallback SKIP cap·evidence durability 등)는
유지·확장. 버전은 **2.2.0 그대로**(아직 main 미머지 — 이 fix는 2.2.0을 올바르게 ship하기 위한 완성).

## 목차

- [1. Context / Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals / Out-of-Scope](#3-non-goals--out-of-scope)
- [4. Constraints (헌장 정합)](#4-constraints-헌장-정합)
- [5. 핵심 결정 요약](#5-핵심-결정-요약)
- [6. 설계 상세](#6-설계-상세)
  - [6.1 digest-seal (C-NEW-1 근본 fix)](#61-digest-seal-c-new-1-근본-fix)
  - [6.2 b-precise (fix b — baseline-anchored Layer 1b)](#62-b-precise-fix-b--baseline-anchored-layer-1b)
  - [6.3 read-tree 시드 (I-NEW-2 가용성 fix)](#63-read-tree-시드-i-new-2-가용성-fix)
  - [6.4 SKILL 배선 (3-line 계약 + guard 3-arg)](#64-skill-배선-3-line-계약--guard-3-arg)
  - [6.5 Law-3 review-mechanism hardening](#65-law-3-review-mechanism-hardening)
- [7. Acceptance Criteria](#7-acceptance-criteria)
- [8. Files to Modify](#8-files-to-modify)
- [9. Verification Plan](#9-verification-plan)
- [10. Rejected Alternatives](#10-rejected-alternatives)
- [11. Open Questions (plan 단계 세부)](#11-open-questions-plan-단계-세부)
- [12. Handoff Context](#12-handoff-context)
- [13. Metadata](#13-metadata)
- [14. Review revisions](#14-review-revisions)

## 1. Context / Why

round-1.5는 mutation-guard를 4계층 fail-closed oracle로 재작성했다: 계층 0(fail-closed 토대),
계층 1(content tree-hash vs `B^{tree}`), 계층 2(ignore-channel + config tamper vs snapshot),
계층 3(snapshot-delta: reflog/stash vs snapshot). 계층 2·3은 **create-sandbox가 봉인한
pre-verifier snapshot**(`$gitdir/qg-mutation-snapshot`)을 *유일한 신뢰 기준(reference)*으로 삼아
"지금 상태 vs snapshot"을 비교한다.

**C-NEW-1 (CRITICAL, 3중 재현) — verifier-writable snapshot = master key.** snapshot 파일은
verifier가 **경로를 계산**(`git -C "$sandbox" rev-parse --absolute-git-dir`)하고 **덮어쓸 수
있는**(runtime-verifier가 Bash+Write 보유, `agents/runtime-verifier.md:73`이 절대경로 write를
명시 허용) **무인증 평문**이다. orchestrator가 create-sandbox로 snapshot을 쓰고 → verifier가
샌드박스에서 임의 실행(중간) → orchestrator가 mutation-guard로 snapshot을 읽는 구조라, **중간의
verifier가 snapshot을 위조**할 수 있다. 계층 2·3은 "지금 vs snapshot" 비교인데 verifier가
snapshot을 통제하면 *양변이 모두 피검증자 통제*가 되어 무의미해진다. round-1.5 §6.1 주석
("No channel for a verifier self-claim → structural Law 2 defense")이 주장한 격리는 **존재하지
않는다**.

**불변 baseline commit `B^{tree}`만 verifier가 못 바꾼다**(바꾸면 orchestrator가 들고 있는 SHA와
불일치 → 계층 0 baseline 검증 실패). 따라서 snapshot을 안 읽는 계층 1만 버틴다. 그러나 계층 1의
`add -A`(no `-f`)는 ignore를 존중하므로, **신규 product 파일을 common `info/exclude`에 추가**하면
계층 1이 staging을 skip → 회피된다. exploit(throwaway repo 3중 재현):

```
1. echo 'BACKDOOR()' > "$SANDBOX/onlyhack.js"                          # 신규 product 파일
2. echo 'onlyhack.js' >> "$common/info/exclude"                        # 계층 1 add -A 회피
3. snapshot의 excl_common_sha= 라인을 hash-object(새 info/exclude)로 위조   # 계층 2 회피
4. 계층 1b는 symlink만 플래그(:273) → 일반 파일 onlyhack.js 회피
5. 계층 3 무변경
→ forced_downgrade: no, exit 0 → SKILL R4가 PASS로 라우팅 → 백도어 LIVE
```

같은 primitive(snapshot 위조)로 `core.excludesFile` 변종(LIVE 백도어), stash/reset revert 변종도
재현된다. 샌드박스는 항상 폐기(R5)되므로, verifier가 product를 몰래 패치해 PASS를 self-emit하면
*여전히 깨진* product가 green Runtime gate를 달고 ship된다 — 가드가 막아야 할 바로 그 self-approval.

**부수 발견:**
- **I-NEW-1 (IMPORTANT):** 계층 1b가 symlink-only(`:271-275`)라 ignore로 숨긴 신규 *일반* 파일을
  어느 content 계층도 안 봄. C-NEW-1 live-backdoor 절반의 구조적 enabler.
- **I-NEW-2 / codex-244 (IMPORTANT, 가용성):** 계층 1의 fresh **empty** index `add -A`(no `-f`)가
  repo가 의도적으로 tracked하는 ignore-매칭 파일(`git add -f debug.log`, committed `dist/` 등)을
  "새 ignored 파일"로 오인해 미staging → `cur_tree`에서 누락 → **무변경 깨끗한 샌드박스가
  `forced_downgrade: yes`로 오탐**(보안 아님, 가용성 버그). 재현됨.

**Law 3 escape (review 메커니즘 자체의 결함).** 이 우회는 whole-branch opus 리뷰 + Phase-1
reviewer 3종("Ready to merge")을 **탈출**했다. 원인: 각 계층을 *고립적으로* 분석하고 snapshot을
신뢰(스크립트 주석의 가정 그대로). security-reviewer + adversarial만 snapshot 신뢰 모델 자체를
공격해 잡았다. devbrew Law 3 canonical: *"버그가 리뷰를 탈출하면 해결책은 잡았어야 할 reviewer
persona 파일을 편집하는 것."* → round-2는 코드뿐 아니라 review 메커니즘도 강화한다(§6.5).

**위협 모델 (round-1.5에서 상속).** verifier는 Write+Bash를 가진 LLM agent로, (오작동/주입으로)
AC를 통과시키려 product를 고칠 수 있다. 가드는 product mutation을 git ground-truth로 *구조적으로*
잡아야 한다. C-NEW-1은 그 ground-truth의 *신뢰 기준 자체*를 피검증자가 통제하게 둔 결함이므로
in-scope. 완전한 OS-수준 sandbox(verifier가 guard script 삭제, host egress)는 round-1.5 §3가
명시적 non-goal로 인정 — 이 spec도 그 경계를 확장하지 않는다.

## 2. Goals

- **C-NEW-1 구조적 봉쇄.** 신뢰 기준(snapshot)을 verifier-unreachable 채널(orchestrator-held
  digest)로 봉인 — 피검증자가 위조하면 fail-closed(`guard_fail` exit 4), 위조 안 하면 계층 2·3가
  실변경을 잡음. 어느 쪽이든 self-approval 불가.
- **defense-in-depth (b-precise).** snapshot/digest와 *독립*인 baseline-anchored detector를 계층
  1b에 추가 — digest seal이나 계층 2에 버그가 나도 planted 파일을 불변 `B` 기준으로 독립 탐지.
  I-NEW-1(symlink-only)을 흡수.
- **가용성 fix (I-NEW-2).** empty-index false-positive 제거 — 무변경 샌드박스는 `forced=no`.
- **review 메커니즘 강화 (Law 3).** 이 우회를 놓친 security-reviewer/adversarial persona에 명시
  체크 추가 + vacuous H-AC3(ii) 테스트를 격리 검증으로 수정.
- **회귀 무손상.** round-1.5 H-AC1–10 + 8개 happy-path 가드 테스트 + 합법 `.env` setup-only PASS
  경로 + C-E(assume-unchanged/skip-worktree) catch + C-D(stash/reset) 보호 전부 유지.
- **계약 정직성.** 출력 2줄 → 3줄(snapshot_digest 추가)로 변경 — round-1.5의 "계약 무변경" 편의가
  master-key를 만들었으므로 그 비용을 받아들이는 re-consensus.

## 3. Non-goals / Out-of-Scope

- **완전한 OS-수준 sandbox.** verifier가 Bash로 guard script 삭제·host egress·메인 repo working
  tree 직접 변조하는 것까지 막지 않음(round-1.5 §3 경계 유지). 이 spec은 git ground-truth
  *신뢰 기준의 무결성*만 복원.
- **baseline `.gitignore` 매칭 신규 파일.** verifier가 띄운 서비스의 합법 runtime 산출물
  (`node_modules/`, `*.log`, `.next/`)과 *구조적으로 구분 불가*한 위협(예: baseline `.gitignore`에
  매칭되는 경로에 심은 파일을 app이 로드)은 OS-sandbox 영역으로 명시 수용. b-precise는 baseline
  `.gitignore`를 신뢰 ignore 소스로 인정하므로 이 부류는 플래그하지 않는다(usability 보존).
  **경계 안전성 논증:** 이 면제는 *pre-existing* baseline `.gitignore` 패턴에 매칭되는 신규 파일에
  한정된다. 공격자가 *새* 패턴을 tracked `.gitignore`에 추가해 파일을 숨기려 하면 그 `.gitignore`
  수정 자체가 tracked change → 계층 1이 `cur_tree != base_tree`로 잡는다(round-1.5 §6.2 검증).
  C-NEW-1 exploit(`onlyhack.js`)은 baseline `.gitignore`에 없어 b-precise/계층 2가 닫는다. 따라서
  실 gap은 "환경이 *이미* 무시하던 패턴에 매칭되고 app이 *로드*하는 신규 파일"로 좁고, 이는
  OS-sandbox 없이는 합법 runtime 산출물과 구분 불가 → 정직한 non-goal.
- **reflog logging flip-and-restore 변종.** round-1.5 §3의 non-goal 유지(끄고→commit+reset→복원은
  git 흔적 없음, 단 product==baseline).
- **runtime-verifier 능력/identity 변경.** executor 전환·model inherit·blast-radius·upfront plan은
  round-1.5 그대로. 이 spec은 가드 oracle의 신뢰 기준 + 그 배선 + review 메커니즘만.
- **신규 P# (philosophy 원칙).** "보안 oracle reference는 피검증자 손 밖"은 신규 원칙이 아니라
  기존 Law 2의 instantiation — §6.5 persona 체크로 흡수(lightness). philosophy doc 무편집.

## 4. Constraints (헌장 정합)

- **Law 2 (Writer ≠ Reviewer, structural).** 이 spec의 본질. self-approval 차단은 verifier 판단이
  아니라 orchestrator의 git ground-truth이며, 그 ground-truth의 *신뢰 기준*이 피검증자 손 밖에
  있어야 비로소 우회 불가능하다. C-NEW-1은 그 조건이 깨진 것 — round-2가 복원. `test-scope-validator`는
  read-only reviewer로 불변.
- **Law 3 (compounding).** C-NEW-1·I-NEW-1·I-NEW-2 각각에 회귀 테스트. 추가로 *이 우회를 놓친
  review 메커니즘*(persona + vacuous test)을 고치는 게 이번 cycle의 핵심 compounding 이벤트(§6.5).
- **Law 1 (evidence-required).** 가드 출력은 `forced_downgrade`·`guard_flags`·`guard_error`로 *왜*
  downgrade인지 근거 surface(round-1.5 계승). digest 불일치 시 `guard_error`에 명시.
- **P18 (bounded).** 새 루프 없음. 가드는 단발 결정론적 스크립트. b-precise는 2차 pass 한 번.
- **P21 (secret 미노출).** 가드는 파일 *내용*을 해싱하지만 해시만 비교·기록(내용 미emit). snapshot
  digest도 해시값. info/exclude 일시 비움→복원은 내용을 stdout/evidence에 노출하지 않음.
- **보안-민감 코드.** mutation-guard(보안 컨트롤) + persona(`security-reviewer.md`·`adversarial.md`)
  편집은 test-suite 편집과 같은 신중함(CLAUDE.md). 구현 PR은 qg self-review 재실행 권장.
- **lightness.** 신규 P# 없음 — 기존 Law 2 메커니즘의 *신뢰 기준 무결성 복구*. digest-seal·
  baseline-anchor는 신규 원칙이 아니라 기존 가드의 올바른 구현.

## 5. 핵심 결정 요약

| 축 | 결정 | 근거 |
|---|---|---|
| C-NEW-1 custody | **orchestrator-held digest seal** — create-sandbox가 snapshot digest를 emit, guard가 신뢰 전 검증 | verifier가 못 닿는 유일 채널 = orchestrator context. HMAC은 key 탈취로 약함 |
| digest 전달 | create-sandbox **출력 line 3** + mutation-guard **3번째 인자** | snapshot 위조→digest 불일치→fail-closed. 단일 hex 문자열이라 orchestrator capture·재전달 시 다필드 blob 대비 transcription 오류 없음 |
| 2-arg 호출 | **제거** — digest 없는 guard는 indeterminate → `guard_fail` | "신뢰 기준 없는 비교 = 인증 없음" |
| fix b 형태 | **b-precise** — baseline `.gitignore`만 신뢰 ignore 소스; info/exclude·excludesFile로만 숨겨진 신규 파일 플래그 | crude("모든 new path")는 runtime 산출물 false-FAIL. independence = 불변 B 기준 |
| b-precise 위치 | 계층 1b 확장(symlink-only → 신규 일반 파일도), **snapshot-독립** | digest/계층 2에 버그 나도 독립 탐지(defense-in-depth) |
| I-NEW-2 fix | 계층 1 임시 index를 **`read-tree $base_tree` 후 `add -A`**로 시드 | tracked-but-ignored 재-제외 안 됨; C-E catch·`.env` PASS 보존 |
| Law 3 review | security-reviewer + adversarial **persona 체크** + **vacuous H-AC3(ii) 격리 수정** | 우회를 놓친 메커니즘을 고치는 게 compounding |
| philosophy | **신규 P# 없음** — persona 체크로 흡수 | lightness |
| version | **2.2.0 유지** + CHANGELOG `[2.2.0]` 보강 | 미머지 base 완성(round-1.5 선례) |

## 6. 설계 상세

### 6.1 digest-seal (C-NEW-1 근본 fix)

**데이터 흐름.** orchestrator(SKILL turn의 Bash)가 create-sandbox·mutation-guard를 실행하고, 그
사이에 runtime-verifier subagent가 샌드박스에서 서비스를 띄운다. verifier가 *구조적으로* 못
건드리는 채널은 둘뿐: (i) orchestrator의 turn context / tool-call 인자, (ii) 불변 commit `B`의 SHA.
digest는 (i)를 통해 흐른다.

**create-sandbox 변경.** snapshot 7필드 기록(round-1.5 §6.1 그대로) 직후, snapshot 파일 내용의
digest를 계산해 출력 line 3로 추가:

```bash
snapshot_digest=$(git -C "$sandbox" hash-object "$snap") || die "cannot digest snapshot: $snap"
# 출력 계약: line1=sandbox, line2=base, line3=snapshot_digest  (round-1.5 2줄 → 3줄)
printf '%s\n%s\n%s\n' "$sandbox" "$base" "$snapshot_digest"
```

- `git hash-object`는 git 컨텍스트 내라 항상 가용·포터블(round-1.5 §11이 권장한 해싱 커맨드와 동일
  계열). snapshot 파일 내용 전체(7필드)를 해싱하므로 **어느 한 필드라도 위조되면 digest가 바뀐다**.
- create-sandbox는 verifier dispatch *이전에* 실행되므로, digest는 pre-verifier snapshot에 대해
  계산된다.

**mutation-guard 변경.** 3-arg 계약 + 계층 0에 digest 검증 추가:

```bash
# usage: mutation-guard <sandbox-abs> <baseline-sha> <snapshot-digest>  (3-arg 계약)
# $1=subcommand "mutation-guard"를 포함하므로 3-arg는 $#==4 (현행 round-1.5 2-arg는 $#==3).
[[ $# -eq 4 ]] || die "usage: mutation-guard <sandbox-abs> <baseline-sha> <snapshot-digest>"
sandbox="$2" base="$3" expected_digest="$4"
[[ -n "$expected_digest" ]] || guard_fail "missing snapshot digest (seal absent → indeterminate)"
# ... (round-1.5 계층 0: snapshot 존재 + 7키 존재 assert) ...
recomputed=$(git -C "$sandbox" hash-object "$snap" 2>&1) \
  || guard_fail "cannot recompute snapshot digest: $recomputed"
[[ "$recomputed" == "$expected_digest" ]] \
  || guard_fail "snapshot integrity check failed (digest mismatch — possible verifier tamper)"
# ... 이후 계층 1/2/3은 검증된 snapshot을 신뢰 ...
```

**verifier 막다른 골목 (증명).**
- snapshot 위조(예: `excl_common_sha`를 새 info/exclude에 맞게 재작성) → recomputed ≠ expected →
  `guard_fail` exit 4. ✓
- snapshot 무수정 + info/exclude만 변경 → digest 통과하나 계층 2가 `now_excl_c != snap excl_common_sha`
  로 `ignore_channel_tampered` → forced=yes. ✓
- verifier가 pre-verifier digest를 *읽을* 순 있어도 orchestrator-held `expected_digest`를 *바꿀* 순
  없음 → 어느 경로든 잡힘. snapshot의 7필드 전체가 봉인되어 계층 2·3의 모든 신뢰 입력 보호.

**봉쇄가 의존하는 구조적 가정 (명시 — round-1.5가 주석으로만 주장하다 깨진 실수 회피).** digest는
(i) orchestrator(SKILL turn)가 create-sandbox stdout line 3에서 캡처해 자신의 turn context /
tool-call 인자로 보유하고, (ii) runtime-verifier는 **별도 Agent subagent turn**으로 dispatch되어
자체 context만 가지므로 orchestrator의 대화 상태나 이후 guard Bash 호출의 리터럴 인자를 읽거나 바꿀
수 없다 — 이 *turn 분리*가 봉쇄의 load-bearing 전제다. SKILL이 `Write`/`Edit`를 보유하는 것
(user-consented Review-gate fix용)은 *orchestrator 자신의* 도구이지 verifier가 닿는 채널이 아니다.
**가정 재검토 트리거(아키텍처 불변식, §11 plan 항목 아님):** 미래에 verifier를 subagent 격리 없이
orchestrator turn에 inline 실행하는 아키텍처로 바뀌면 이 전제가 깨지므로 digest 봉쇄를 재설계해야 한다.

**계약 변경 (re-consensus).** round-1.5 §5 "snapshot 저장=gitdir(출력 계약 2줄 무변경)" + §10
"snapshot을 출력 3번째 줄로" 기각을 **뒤집는다**. 그 두 결정의 "편의"(snapshot을 verifier가 사는
gitdir에 둠 + 계약 보존)가 정확히 master-key를 만들었다. 2-arg 호출은 제거 — 모든 caller(SKILL R4)
와 테스트가 3-arg로 갱신. snapshot 파일은 여전히 gitdir에 살되, **이제 "orchestrator-held digest로
봉인된 untrusted scratch"**다.

### 6.2 b-precise (fix b — baseline-anchored Layer 1b)

**원칙.** 신뢰 ignore 소스는 **baseline `.gitignore`뿐**(워킹트리 `.gitignore`; tracked라 그 tamper는
계층 1이 `cur_tree`에서 잡음 — round-1.5 §6.2 검증). `info/exclude`·`core.excludesFile`는 untrusted
(둘 다 verifier-writable, `B`에 없음).

**탐지 GOAL.** 워킹트리에 존재하고 `B^{tree}`에 없으며 **baseline `.gitignore`로 설명되지 않는데
non-baseline 소스로만 숨겨진** 신규 파일(일반 파일 + symlink)을 `disallowed_new_files`에 플래그 +
`forced=yes`. 계층 1b를 symlink-only → 일반 파일 포함으로 확장(I-NEW-1 흡수).

**권장 메커니즘 (정확한 incantation은 §11 plan defer).** non-baseline 소스를 neutralize한 2차
baseline-anchored pass — 계층 1과 동일 machinery(read-tree + add -A) 재사용:

```text
1. info/exclude(common + per-worktree) **둘 다** non-baseline 소스라 neutralize 대상. 각 파일을
   **atomic rename으로 백업**(`mv exclude exclude.qgbak`) 후 빈 파일 생성 → 작업 → 복원.
   **순서·복원 계약(고정):** (a) **가드 시작 시** 두 파일 각각에 idempotent 선복원 —
   `for f in {common,wt}: [[ -f $f.qgbak ]] && mv -f $f.qgbak $f` (이전 SIGKILL 잔존을 본 작업 전에
   정리); (b) common 먼저, per-worktree 다음 순으로 백업; (c) trap(EXIT/INT/TERM)이 역순 복원. trap이
   SIGKILL/OOM으로 안 돌아도 원본은 `.qgbak`로 보존되어 다음 가드 실행의 (a)가 복원(rename은 atomic →
   "빈 채로 영구 손실" 창 없음). **오염 위험 비대칭:** per-worktree info/exclude는 샌드박스 gitdir이라
   R5로 폐기 → 빈 잔존 무해; **common info/exclude만 메인 repo 공유**라 (a)/(c)가 실질 보호 대상.
   한쪽 `.qgbak`만 잔존하는 부분복구도 (a)가 파일별 독립 처리하므로 안전. 가드는 verifier 종료 후 단일
   스레드라 race 없음.
2. idx2 = fresh temp index; GIT_INDEX_FILE=idx2 git -c core.excludesFile=/dev/null \
     read-tree "$base_tree" 후 add -A   → cur_tree_neutralized
3. **순수 git-diff 집합차로 산출(계층 1의 bash 배열 미참조 — 결합 회피):**
   set_neutralized = `diff --name-status base_tree cur_tree_neutralized`의 'A' 경로;
   set_layer1 = `diff --name-status base_tree cur_tree`의 'A' 경로 →
   b_precise = set_neutralized \ set_layer1 = non-baseline 소스로만 숨겨졌던 신규 파일 →
   disallowed_new_files에 추가 + forced=yes. (두 tree 모두 git이 산출하므로 계층 1의 누적 배열
   상태 변화에 의존하지 않음 — 배열을 직접 읽다 잘못된 차집합이 나오는 결합 위험 제거.)
4. **symlink 커버 (set-difference와 가산적 — 현행 커버의 상위집합 ⊇ 보장):** Layer 1b =
   **(a)** 기존 `ls-files --others -z` symlink 루프 유지(현 ignore 규칙에 안 걸리는 신규 symlink)
   **+ (b)** 신규 set-difference의 'A' 엔트리 — git tree는 symlink를 mode 120000 엔트리로 표현하므로
   neutralized pass의 `add -A`가 non-baseline 소스로 숨긴 symlink도 tree에 staging → set_neutralized에
   포함되어 포착. 둘의 합집합이라 현행 symlink 커버보다 크거나 같음. baseline `.gitignore`로 ignore된
   symlink는 §3 non-goal(regular 파일과 동일 경계 — neutralized pass도 baseline `.gitignore`는 존중).
   §9가 "info/exclude로만 숨긴 신규 symlink → forced=yes" 테스트로 (b) 경로 검증.
```

**독립성 (defense-in-depth).** cur_tree_neutralized는 불변 `B^{tree}` + 워킹트리 `.gitignore`(tamper는
계층 1이 독립 포착)만 기준 — **snapshot/digest를 읽지 않는다**. 따라서 digest seal(§6.1)이나 계층 2에
구현 버그가 나도 planted 파일을 독립적으로 탐지. ①(digest seal)만으론 남던 잔여(*pre-existing*
non-baseline ignore rule에 매칭되는 신규 파일 — 예: 환경의 `core.excludesFile=~/.gitignore_global`)도
닫는다.

**usability 보존.** `node_modules/`·`*.log` 등 baseline `.gitignore`가 ignore하는 합법 runtime
산출물은 2차 neutralized pass에서도 `.gitignore`가 여전히 적용되어 staging 안 됨 → 플래그 안 됨. ✓

### 6.3 read-tree 시드 (I-NEW-2 가용성 fix)

계층 1의 임시 index를 empty가 아니라 **baseline tree로 시드**:

```bash
idx="$gitdir/qg-tmp-idx.$$"; rm -f "$idx"
GIT_INDEX_FILE="$idx" git -C "$sandbox" read-tree "$base_tree" 2>&1 || { rm -f "$idx"; guard_fail ...; }
GIT_INDEX_FILE="$idx" git -C "$sandbox" add -A -- . 2>&1 || { rm -f "$idx"; guard_fail ...; }
cur_tree=$(GIT_INDEX_FILE="$idx" git -C "$sandbox" write-tree 2>&1) || { rm -f "$idx"; guard_fail ...; }
rm -f "$idx"
```

**보존 검증 (설계가 보장, §9가 테스트):**
- **C-E catch 유지** — `read-tree`는 *tree*에서 채우므로 index에 assume-unchanged/skip-worktree
  비트가 없음(이 비트는 index-only flag, tree에 없음) → `add -A`가 전부 re-stat → mutation 잡음.
- **`.env` PASS 유지** — `add -A`(no `-f`)가 `.gitignore` 존중, `.env`는 `B`에 없어(overlay 제외)
  미staging → base_tree와 일치.
- **false-positive fix** — force-tracked ignored 파일(`git add -f debug.log`)이 read-tree로 이미
  index에 있어 재-제외 안 됨 → spurious `tracked_diff` 사라짐 → 무변경 샌드박스 `forced=no`.

(b-precise 2차 pass도 `read-tree "$base_tree"`를 동일 시드로 사용 — §6.2.)

### 6.4 SKILL 배선 (3-line 계약 + guard 3-arg)

- **R0 create-sandbox capture:** 출력 3줄을 파싱 — `sandbox_dir`=line1, `baseline_sha`=line2,
  **`snapshot_digest`=line3**. 셋 다 orchestrator 변수로 보유. **파싱 계약(고정):** 3연속
  `IFS= read -r`(sandbox_dir → baseline_sha → snapshot_digest)로 정확히 줄 단위 취득하고, digest는
  trailing 공백/CR을 strip(`tr -d '[:space:]'` 또는 동등) — hex에 개행/공백이 섞이면 상시 guard_fail
  오탐. line 1/2 의미는 round-1.5와 동일.
- **R4 guard call:** `qg-worktree.sh mutation-guard "$sandbox_dir" "$baseline_sha" "$snapshot_digest"`.
- **I-G retry:** NEEDS_RESOLUTION retry는 R0 재실행 후 **세 값 모두**(`sandbox_dir`·`baseline_sha`·
  `snapshot_digest`) 재캡처(새 snapshot→새 digest). **갱신 대상 섹션 명시:** 현행 SKILL.md의
  *Runtime NEEDS_RESOLUTION decision* 섹션(2-line 재캡처만 기술된 곳)이 line-3 재캡처를 포함하도록
  편집 — 미갱신 시 옛 digest 재사용 → 새 sandbox snapshot과 불일치 → 상시 guard_fail. round-1.5
  §6.7 문구를 digest 포함으로 확장. **갱신 후 retry prose(verbatim, 구현이 그대로 사용):** *"R0
  재실행 후 새 출력의 `sandbox_dir`(line 1)·`baseline_sha`(line 2)·`snapshot_digest`(line 3)를
  R0와 동일한 `IFS= read -r`×3 + digest strip idiom으로 **셋 다** 재캡처해 orchestrator 변수 갱신 후
  R4 guard를 3-arg로 re-dispatch. 새 snapshot은 새 gitdir에 자동 기록됨."* (parse 순서 고정 →
  digest를 line 2로 잘못 캡처하는 implementer-trap 차단.)
- R4 fail-closed 에러경로(round-1.5 §6.4)는 그대로 — guard non-zero exit(=4 포함)·무효 출력 →
  verdict ≤FAIL + stderr surface. digest mismatch는 exit 4로 이 경로를 탄다.
- 3-line 계약·guard 3-arg·retry 재캡처는 `test_skill_orchestration_behavior.sh` 정적 assert로 봉인.

### 6.5 Law-3 review-mechanism hardening

devbrew Law 3: 버그가 리뷰를 탈출하면 *잡았어야 할 reviewer persona*를 고치는 게 fix. 이 우회는
각 계층을 고립 분석하고 snapshot을 신뢰해 탈출했다.

1. **persona 체크 (primary, load-bearing).** `agents/security-reviewer.md` + `agents/adversarial.md`에
   명시 체크 추가: *"guard/oracle가 신뢰하는 모든 artifact(snapshot·baseline·config·임시 파일)에
   대해 — 피검증자(Write 보유 subagent, 또는 샌드박스 내 Bash)가 그것을 쓰거나 경로를 계산할 수
   있는가? 가능하면 그 비교는 무의미하다. 신뢰 기준은 피검증자 손 밖(orchestrator context / 불변
   commit)에 있어야 한다."* persona = 보안-민감 편집(test-suite급 신중).
2. **vacuous H-AC3(ii) 격리 수정 (test-side).** round-1.5 H-AC3(ii)(per-worktree info/exclude)는
   Layer 2가 아니라 Layer 1로 통과하던 vacuous 의심. **신규 파일 없이 per-worktree info/exclude rule만
   변경**하는 격리 케이스로 재작성 → Layer 1b는 플래그할 파일 없음, **오직 계층 2의 `excl_wt_sha`
   경로만** forced=yes + `ignore_channel_tampered` 산출 → 계층 2가 실제로 동작함을 격리 검증.
   mutation-test로 계층 2 `excl_wt_sha` 비교를 비활성한 mutant에서 EVADE(forced=no) 확인.
3. **philosophy.** 위 원칙은 신규 P# 아님 — persona 체크가 기존 Law 2의 instantiation. philosophy
   doc 무편집(lightness; 사용자 결정 2026-06-02).

## 7. Acceptance Criteria

1. **R2-AC1 (digest seal, C-NEW-1 closure):**
   - **(a)** master-key exploit 재현(신규 파일 + common info/exclude append + gitdir snapshot
     `excl_common_sha` **위조**) → orchestrator-held 원본 digest로 guard → `guard_fail` exit 4 +
     `guard_error`에 digest mismatch.
   - **(b)** no-forge 변종(신규 파일 + info/exclude 변경, snapshot 무수정) → 올바른 digest로 digest
     통과하되 계층 2 `ignore_channel_tampered` → forced=yes.
   - **(c)** digest 인자 누락/빈값 → `guard_fail` exit 4.
   - **(d)** clean sandbox + 올바른 digest + 무tamper → forced=no.
   - **(e)** honest mutation(tracked 파일 수정) + 올바른(무위조) digest → forced=yes — Layer 1이 잡고
     digest 검증이 Layer 1을 short-circuit하지 않음을 확인(digest seal + Layer 1 상호작용 명시 검증;
     digest가 happy-path를 깨지 않고 실 mutation 포착도 보존).
2. **R2-AC2 (b-precise, fix b — 독립성 증명 = de-vacuum):**
   - **(i)/(ii)/(iii)** 신규 *일반* 파일을 common info/exclude · per-worktree info/exclude ·
     core.excludesFile로 각각 숨김 → **계층 0·2·3가 모두 통과하도록 snapshot 매칭 위조 + 매칭
     digest 제공**(계층 2 무fire) → 그래도 forced=yes + `disallowed_new_files`에 파일 → 계층 1b
     단독 포착 증명.
   - **(iv) usability:** baseline `.gitignore`가 ignore하는 신규 파일(`.gitignore`에 `node_modules/`,
     `node_modules/x.js` 생성) + 무tamper → forced=no (runtime 산출물 false-FAIL 안 함).
3. **R2-AC3 (I-NEW-2 + C-E 보존):**
   - **(a)** `*.log` ignore + `git add -f debug.log` repo, 무mutation 샌드박스 → forced=no.
   - **(b)/(c)** C-E assume-unchanged·skip-worktree + mutation → 각각 forced=yes(read-tree 시드 후 유지).
   - **(d)** git-ignored `.env` 무product변경 → forced=no.
4. **R2-AC4 (Law-3 vacuous H-AC3(ii) 격리 수정):** per-worktree info/exclude **rule만 변경(신규 파일
   없음)** → forced=yes + `ignore_channel_tampered`가 **계층 2에서** 산출됨을 격리 검증 + 계층 2
   비활성 mutant EVADE 확인.
5. **R2-AC5 (persona hardening, 정적):** `security-reviewer.md` + `adversarial.md`에 "guard 신뢰
   artifact를 피검증자가 쓸/경로계산할 수 있나" 체크 문구 존재(정적 grep).
6. **R2-AC6 (회귀 무손상):** round-1.5 H-AC1–10 + 8 happy-path + (3-arg 전환 후) 전부 green.

## 8. Files to Modify

- **`plugins/quality-gates/scripts/qg-worktree.sh`** — create-sandbox digest emit(line 3, §6.1) +
  mutation-guard 3-arg & digest 검증(계층 0, §6.1) + 계층 1 read-tree 시드(§6.3) + 계층 1b b-precise
  확장 & neutralization cleanup trap(§6.2).
- **`plugins/quality-gates/skills/quality-pipeline/SKILL.md`** — R0 line-3 digest capture + R4 guard
  3-arg thread + I-G retry 3값 재캡처 + 3-line 계약 문서화(§6.4).
- **`plugins/quality-gates/agents/security-reviewer.md`** — persona 체크(§6.5, 보안-민감).
- **`plugins/quality-gates/agents/adversarial.md`** — persona 체크(§6.5, 보안-민감).
- **`plugins/quality-gates/tests/test_qg_mutation_guard.sh`** — R2-AC1/2/3/4 + de-vacuum; 8 happy-path
  + H-AC1–10 회귀(3-arg 시그니처로 갱신).
- **`plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`** — line-3 digest
  capture·guard 3-arg thread·retry 재캡처 정적 assert + R2-AC5 persona grep.
- **`plugins/quality-gates/CHANGELOG.md`** — `[2.2.0]` 보강: digest-seal custody + b-precise +
  read-tree + persona hardening.
- **`docs/superpowers/specs/2026-06-01-qg-mutation-guard-hardening-design.md`** — §5 "snapshot
  저장=gitdir" row + §10 "3번째 출력 줄" 기각에 **round-2 supersede 포인터**(round-1.5가 원본
  §6.7에 한 것과 동형).
- **`plugins/quality-gates/plugin.json`** — version **2.2.0 유지**(미머지 base 완성; 브랜치 전체가
  2.1.0→2.2.0 한 번 bump). 변경 없음 — 명시.
- **runtime-verifier.md 변경 없음** — digest는 orchestrator-side, persona 무관(보안-민감 편집 최소화).

## 9. Verification Plan

- **실행 위치:** 모든 bash/py 테스트는 **repo root에서** `/bin/bash`로 실행(qg cwd 계약 + macOS
  /bin/bash 3.2.57 NUL 동작 민감 — 참조 메모리). qg는 CI 없음 + main에 기존 stale red 8개 + pytest
  collection error 3개 → 작업 전 baseline 캡처 후 **신규/수정 테스트의 green만** 회귀 판정.
- **C-NEW-1 봉쇄 (R2-AC1):** **throwaway repo(임시 디렉토리에 `git init` + commit, 메인 repo 미접촉)
  안에서 실제 `create-sandbox`/`mutation-guard`를 호출**해 통합 경로를 검증(기존 `mk_sandbox` 헬퍼
  패턴 확장; 메인 repo git 트리 side-effect 없음). 테스트가 **orchestrator 역할을 수행** —
  create-sandbox 출력 line 3(digest)를 캡처해 guard 3번째 인자로 전달. master-key exploit 재현:
  digest 위조 시 exit 4 / no-forge(snapshot 무수정) 시 계층 2 `ignore_channel_tampered` / digest
  인자 누락 시 exit 4 / clean 시 forced=no / **honest mutation(tracked 수정) + 무위조 digest →
  forced=yes**(R2-AC1e: digest 검증이 Layer 1을 short-circuit 안 함).
- **b-precise (R2-AC2):** (i)-(iii) 독립성/de-vacuum isolation — 테스트가 **orchestrator 역할로**
  snapshot을 *현재(post-attack) ignore 상태에 매칭되게 구성*하고 `git hash-object`로 그 snapshot의
  digest를 산출해 guard 3번째 인자로 전달 → 계층 0(digest 일치)·계층 2(snapshot==현재)·계층 3 모두
  무fire → forced=yes가 나오면 *오직 계층 1b만* 산출한 것 → b-precise 독립 동작 증명(단순 "Layer 1b가
  파일 잡음"이 아니라 "Layer 2 무력 조건에서도 독립 포착"을 검증). **snapshot 구성 패턴(N-5):**
  create-sandbox 호출 후 결과 snapshot을 `sed`로 patch(post-attack ignore 상태에 매칭)하고 patched
  snapshot의 `git hash-object`를 digest 인자로 전달 — 실 통합 경로를 타되 Layer 0(digest=patched
  해시)·Layer 2(snapshot==현재)를 구성으로 통과시켜 b-precise만 격리. **(iii) core.excludesFile은
  `git config --local core.excludesFile <throwaway 내부 경로>`로 설정(N-4: host `~/.gitconfig` 미오염).**
  (iv) baseline `.gitignore` 매칭 신규 파일(`.gitignore`에 `node_modules/`, `node_modules/x.js` 생성)
  → forced=no(usability). **(v) info/exclude로만 숨긴 신규 symlink → forced=yes**(N-2: set-difference가
  mode 120000 tree 엔트리로 symlink 포착; 기존 ls-files symlink 루프와 가산 합집합 확인).
- **I-NEW-2 + C-E (R2-AC3):** force-tracked ignored 무mutation → forced=no; C-E 2케이스 read-tree
  시드 후 forced=yes; `.env` PASS forced=no.
- **vacuous 수정 (R2-AC4):** per-worktree info/exclude rule-only 변경(신규 파일 없음) → 계층 2
  `ignore_channel_tampered` + forced=yes. **mutation-test(자동 assertion):** 테스트가 `qg-worktree.sh`를
  tempfile로 복사하고 `sed`로 계층 2의 `excl_wt_sha` 비교 라인을 무력화(항상 일치)한 mutant 스크립트를
  생성·호출 → 같은 입력에서 forced=no(EVADE)임을 bash assert로 확인(원본은 forced=yes). 이로써 통과가
  계층 2 경로를 실제로 거침을 증명(Layer 1로 통과하던 vacuous 제거).
- **정적 (R2-AC5 + §6.4):** orchestration behavior 테스트가 SKILL line-3 capture·guard 3-arg·retry
  재캡처·persona 체크 문구를 grep assert.
- **회귀 (R2-AC6):** round-1.5 happy-path 8 + H-AC1–10(3-arg 갱신) 전부 green.
- **YAML 유효성:** 가드 출력은 `python3 -c "import yaml; yaml.safe_load(...)"`로 파싱 확인(I-D 계승).

## 10. Rejected Alternatives

- **접근 ② baseline re-anchor (snapshot 제거).** 보안 verdict를 불변 `B`에만 의존, 계층 2·3 제거,
  C-D-revert를 non-goal로 수용. → **기각**: C-D(stash/reset) 탐지를 잃고(digest-seal은 유지),
  info/exclude neutralization이 *모든* 비교의 hot path가 되어 plumbing 부담↑. digest-seal은 계층 2·3를
  최소 변경으로 보존하면서 동일 보안을 달성.
- **접근 ③ HMAC-sealed snapshot.** Bash 쥔 verifier가 orchestrator env/process에서 HMAC key 탈취
  가능 → rewritable 파일 HMAC은 key가 진짜 도달 불가일 때만 의미. → 기각.
- **fix b crude("`B^{tree}`에 없는 모든 new path 플래그").** create-sandbox가 baseline 봉인 시
  git-ignored 파일을 제외하므로, verifier 서비스의 합법 runtime 산출물(node_modules 등)이 전부 "new
  path" → 실서비스마다 false-FAIL. → 기각, b-precise(baseline `.gitignore` 신뢰) 채택.
- **digest를 orchestrator가 직접 계산(create-sandbox 2줄 유지).** create-sandbox 후 SKILL이
  `git hash-object <snap>`로 digest 산출(verifier dispatch 전). → 출력 계약은 보존하나 SKILL에 추가
  Bash 단계 + 경로 재계산 필요. create-sandbox-emits가 atomic·single-source라 채택; 이 변종은 plan
  대안으로만 기록.
- **snapshot을 gitdir에 둔 채 seal 없이 유지(round-1.5 결정).** = C-NEW-1 결함 자체. → 기각.
- **신규 P# "보안 oracle reference는 피검증자 손 밖".** → 기각, §6.5 persona 체크로 흡수(lightness).
- **runtime-verifier persona로 git surface 금지(assume-unchanged/stash/snapshot write 금지).** Bash
  쥔 agent가 persona 우회 가능 → 주 방어로 기각(보조 레이어로만, round-1.5 §10 계승).

## 11. Open Questions (plan 단계 세부)

설계 결정은 모두 closed. 구현 세부만 writing-plans에서:

- **b-precise info/exclude neutralization 기법** — (1) info/exclude(common + per-worktree) 일시
  비움 + cleanup trap 복원 vs (2) scratch checkout. *원칙*(baseline `.gitignore`만 신뢰)·*GOAL*(non-
  baseline 소스로만 숨긴 신규 파일 플래그)·*usability*(baseline-ignored 미플래그)는 locked; 기법만
  plan. 단일 스레드 실행(verifier 종료 후)이라 (1)이 race 없음 — 권장.
- **b-precise 정확한 열거 formulation** — 2차 read-tree+neutralized add-A 후 `A` 엔트리 diff vs
  계층 1 disallowed 차집합(권장) vs `ls-files` 기반. symlink 규칙(신규 symlink는 ignore 무관)을 현행
  이상으로 보존할 것.
- **digest 커맨드** — `git hash-object`(권장, git 컨텍스트 항상 가용) 확정 여부.

## 12. Handoff Context

**TL;DR (3줄).**
1. round-1.5 hardening의 snapshot이 verifier-writable gitdir에 살아 피검증자가 신뢰 기준을 위조
   가능(C-NEW-1, master-key, 3중 재현) → snapshot을 **orchestrator-held digest로 봉인**(line 3 emit +
   guard 3-arg + 신뢰 전 검증).
2. **b-precise**(baseline `.gitignore`만 신뢰 ignore 소스)를 계층 1b에 추가 — snapshot-독립 defense-
   in-depth, I-NEW-1 흡수, usability 보존(node_modules 미플래그).
3. **I-NEW-2** read-tree 시드로 empty-index false-positive 제거(C-E·`.env` 보존). **Law 3**: 우회를
   놓친 security-reviewer/adversarial persona 체크 + vacuous H-AC3(ii) 격리 수정. 버전 2.2.0 유지.

**Implicit context (대화에서 결정, 2026-06-02).**
- 범위 = 세 가지 모두(C-NEW-1 + I-NEW-2 + Law-3 review-hardening) — findings가 묶은 그대로.
- custody = 접근 ① digest-seal(②/③ 기각). fix b = 포함, 정밀형(b-precise).
- philosophy note = persona만(신규 P# 없음, philosophy doc 무편집) — lightness.
- 발단: qg self-review가 hardening 자체에서 6번째 우회 발견 → 직전 "Ready to merge" 정정 → Stop→spec.

**round-1.5와의 관계.** 이 spec은 round-1.5의 §5 "snapshot 저장=gitdir" + §10 "3번째 출력 줄 기각"만
supersede. round-1.5의 4계층 골격·fail-closed·fallback SKIP cap·evidence durability·C-A~C-E coverage는
유효·확장(계층 2·3는 이제 digest-sealed snapshot을 신뢰; 계층 1은 read-tree 시드; 계층 1b는 b-precise).

**Deferred to plan (§11).** info/exclude neutralization 기법 / b-precise 열거 formulation / digest
커맨드 확정 — 구현 세부만. 보안 핵심(digest seal·b-precise 원칙·read-tree 보존·persona 체크)은 spec 확정.

## 13. Metadata

- **Plugin:** quality-gates
- **Version:** v2.2.0 유지 (미머지 base 완성 — bump 없음; CHANGELOG `[2.2.0]` 보강)
- **요청자:** 사용자 (2026-06-02)
- **발단:** qg self-review (`feature/qg-sandbox-executor` HEAD `3bbd16c`), Law 3 closure 재실행 —
  reviewer 6종 + adversarial이 hardening 자체에서 C-NEW-1 + I-NEW-2 발견.
- **supersedes:** round-1.5 design `2026-06-01-qg-mutation-guard-hardening-design.md` **§5(snapshot
  저장 row) + §10(3번째 출력 줄 기각)**.
- **헌장 영향:** 없음(신규 P# 없음) — 기존 Law 2 가드 메커니즘의 *신뢰 기준 무결성* 복구.
- **보안-민감:** mutation-guard(보안 컨트롤) + persona(`security-reviewer.md`·`adversarial.md`) 편집 —
  신중 리뷰 대상. 구현 PR은 qg self-review 재실행 권장(이번엔 green이어야 함).

## 14. Review revisions

- **round 1 (spec-reviewer, 2026-06-02):** needs_revise 10건(전부 `ambiguity`/`isolation`/
  `untestable_AC`/`scope_creep`, `affects_locked` 없음 — design mode, Stagnation_signal=false). 전부 반영:
  - [b3c4d5e6] digest 봉쇄가 의존하는 **turn 분리 가정** 미명시 → §6.1에 명시 + 아키텍처 불변식
    재검토 트리거(inline 실행 전환 시 재설계) 추가.
  - [c5d6e7f8] cleanup trap의 SIGKILL 한계 → §6.2 step 1을 **atomic rename(`.qgbak`) 백업**으로
    변경(trap 미실행 시에도 복원 가능) + 위험 범위(common gitdir info/exclude) 명시.
  - [f1a2b3c4] b-precise가 계층 1 bash 배열 참조 시 결합 → §6.2 step 3을 **순수 git-diff 집합차**
    (set_neutralized \ set_layer1)로 변경, 배열 미참조.
  - [a1b2c3d4] digest 파싱 계약 미명시 → §6.4에 3연속 `IFS= read -r` + trailing-whitespace strip 고정.
  - [a3b4c5d6] I-G line-3 재캡처가 SKILL의 특정 섹션 갱신 필요 → §6.4에 *Runtime NEEDS_RESOLUTION
    decision* 섹션을 갱신 대상으로 명시.
  - [e9f0a1b2] `$# -eq 4` off-by-one 모호 → §6.1에 "$1=subcommand 포함, 3-arg=$#==4(현행 2-arg=3)" 주석.
  - [d7e8f9a0]/[d9e0f1a2] R2-AC1·AC2 fixture 형태 미명시 → §9에 "throwaway repo 안에서 실제
    create-sandbox/guard 호출 + 테스트가 orchestrator 역할로 digest 캡처·전달" 명시.
  - [b5c6d7e8] R2-AC4 mutation-test 기법 미명시 → §9에 "sed로 계층 2 비교 라인 무력화한 mutant
    tempfile 생성·호출 후 EVADE를 bash assert" 고정.
  - [c7d8e9f0] baseline-`.gitignore` non-goal 경계 안전성 논증 부재 → §3에 "새 패턴 추가는 계층 1이
    잡고, pre-existing 패턴 매칭만 면제"라는 경계 논증 추가.
- **round 2 (spec-reviewer, 2026-06-02):** round-1 10건 전부 RESOLVED 확인(words-only 아님, re-raise 0).
  신규 6건 반영(전부 revision이 도입한 갭; `affects_locked` 없음, Stagnation_signal=false). reviewer
  총평: "security core sound — six gaps resolvable by spec text additions."
  - [e2f3a4b5] (CRITICAL) `.qgbak` 2-파일 복구 순서/부분복구 미명시 → §6.2 step 1에 idempotent 선복원
    (파일별 독립)·common-first 순서·역순 trap·오염 비대칭 명시.
  - [f4a5b6c7] (CRITICAL) set-difference의 symlink 커버 동등성 미검증 → §6.2 step 4를 "(a) 기존
    ls-files symlink 루프 유지 + (b) neutralized pass가 mode 120000 tree 엔트리로 symlink 포착"의
    가산 합집합(현행 ⊇)으로 명시 + §9 (v) 테스트 추가.
  - [a6b7c8d9] retry prose verbatim 부재 → §6.4에 3-capture verbatim prose(parse 순서 고정) 추가.
  - [b8c9d0e1] core.excludesFile 테스트 host config 오염 위험 → §9에 `git config --local` 명시.
  - [c0d1e2f3] AC2 isolation snapshot 구성법 모호 → §9에 create-sandbox-then-`sed`-patch 패턴 명시.
  - [d2e3f4a5] honest-mutation+correct-digest AC 부재 → §7 R2-AC1(e) + §9 테스트 추가.
