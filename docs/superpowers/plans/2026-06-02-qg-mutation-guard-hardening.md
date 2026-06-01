# quality-gates mutation-guard 강화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** v2.2.0 sandbox-executor의 Law 2 self-approval 차단 컨트롤 `mutation-guard`의 5개 우회(C-A info/exclude·C-B git-fail-open·C-C SKILL R4 무에러경로·C-D stash/reset·C-E assume-unchanged)와 7개 IMPORTANT를 봉쇄 — diff 기반 oracle을 snapshot + content-tree-hash + ignore/config-tamper + snapshot-delta(전부 fail-closed) oracle로 교체.

**Architecture:** `qg-worktree.sh create-sandbox`가 baseline commit `B` 봉인 직후 pre-verifier 기준 상태를 per-worktree gitdir의 사이드채널 snapshot 파일에 캡처(출력 계약 2줄 무변경). `mutation-guard`는 그 snapshot을 자동 발견해 4계층(0 fail-closed 토대 → 1 content tree-hash → 2 ignore/config tamper → 3 snapshot delta)으로 product mutation을 git ground-truth로 판정. orchestrator(SKILL)는 가드의 exit code/출력을 R0 수준 규율로 라우팅하고, sandbox 비활성 fallback에서는 verdict를 ≤SKIP_WITH_EVIDENCE로 cap한다. spec: `docs/superpowers/specs/2026-06-01-qg-mutation-guard-hardening-design.md` (원본 §6.7 supersede).

**Tech Stack:** bash 3.2-호환 (macOS/Linux), pure git (`hash-object`/`write-tree`/`diff --name-status`/`reflog`/`stash list`/`config --get`), Markdown SKILL/persona/docs, bash 단위 테스트(`tests/*.sh`) + 정적 protocol-shape grep(`tests/harness/test_skill_orchestration_behavior.sh`).

---

## File Structure

| 파일 | 책임 | 변경 |
|---|---|---|
| `plugins/quality-gates/scripts/qg-worktree.sh` | sandbox 생애주기 + 가드 oracle | `create-sandbox`에 snapshot 캡처 + `core.logAllRefUpdates true` + S-A/S-B `\|\| die`; `mutation-guard` 4계층 재작성 + `yq()` |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | Runtime gate orchestration | R4 fail-closed 라우팅(C-C); R0/R3/R6 fallback `runtime_project_dir` + SKIP cap(I-A/I-B); R3 `evidence_dir` thread(I-C); retry baseline 재캡처(I-G) |
| `plugins/quality-gates/agents/runtime-verifier.md` | sandbox executor persona (보안-민감) | evidence를 절대 `evidence_dir`에 기록하도록 입력+Step 3 분리 명시(I-C) |
| `plugins/quality-gates/scripts/detect-runtime.sh` | runtime manifest 산출 | `${HOME:-}`(I-F); `attempted_log_path` 절대경로(I-C) |
| `plugins/quality-gates/README.md` | kill-switch source-of-truth | Runtime gate 표에 `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX`(I-E) |
| `plugins/quality-gates/commands/qg.md` | env 레퍼런스 | 동 kill-switch 추가(I-E) |
| `plugins/quality-gates/CHANGELOG.md` | 변경 로그 | `[2.2.0]` Security/Fixed 보강(snapshot oracle + fail-closed + SKIP cap) |
| `plugins/quality-gates/tests/test_qg_mutation_guard.sh` | 가드 단위 테스트 | C-A(3채널)/C-B/C-D(3변종)/C-E(2)/snapshot fail-closed + .gitignore + 기존 8 happy-path 유지 |
| `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` | SKILL 정적 protocol-shape | R4 에러경로/fallback SKIP cap+`runtime_project_dir`/evidence_dir 절대경로/retry baseline 재캡처 assert |
| `plugins/quality-gates/tests/test_detect_runtime.sh` | detect-runtime 블랙박스 | `env -u HOME` non-empty manifest(I-F) |
| `plugins/quality-gates/.claude-plugin/plugin.json` | 메타데이터 | **변경 없음** — v2.2.0 유지(미머지 base 완성; spec §13) |

**Decomposition note:** `mutation-guard`는 4계층이 snapshot parse·`forced` OR-누적·공통 emit을 공유하는 **하나의 보안 컨트롤 단위**다. 부분 구현(예: Layer 1만 있고 Layer 0 fail-closed 없음)은 그 자체로 C-B에 취약하므로 **원자적으로 재작성**한다(Task 3) — 테스트는 우회별로 먼저 작성하고, 가드는 한 번에 교체. create-sandbox snapshot(Task 2)이 가드보다 먼저 와야 한다(Layer 0/2/3가 snapshot을 읽음).

---

## Pre-flight 주의사항 (실행 에이전트 필독)

- **테스트는 repo root에서 실행** (`/Users/jeonghokim/Downloads/devbrew`). qg cwd 계약 + worktree 시 main repo 기준. (memory: `project_qg_pre_existing_test_reds`)
- **qg는 CI 없음 + main에 8개 pre-existing stale red** (codex/consent/security/sandbox shell + pytest collection 3). **회귀 판정 = 신규/수정 테스트의 green만**; Task 1에서 baseline 캡처.
- **보안-민감 편집:** `qg-worktree.sh` 가드 + `runtime-verifier.md` persona는 test-suite 편집과 같은 신중함(CLAUDE.md). 약화 금지.
- **reflog/stash 해시는 snapshot 측과 가드 측이 byte-identical 입력으로 해시해야 한다** — 불일치 시 clean sandbox가 false `forced=yes`를 내 happy-path #1이 깨진다(아래 ⚠️ 표시 참조). 이 정합성은 Task 3 "clean → no" happy-path 테스트가 잡는 회귀 가드다.
- **plugin.json version bump 없음** — 이 변경은 미머지 v2.2.0의 완성(spec §13). 단 plan 작성·커밋은 `feature/qg-sandbox-executor` 브랜치에서 진행.

---

## Task 1: Pre-work 테스트 baseline 캡처

**Files:**
- (변경 없음 — 검증 setup. 결과는 작업 노트로만)

- [ ] **Step 1: 영향 받는 테스트의 현재 상태 기록**

Run (repo root에서):
```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in test_qg_mutation_guard.sh test_qg_runtime_sandbox.sh test_detect_runtime.sh \
         harness/test_skill_orchestration_behavior.sh; do
  echo "=== $t ==="
  bash "plugins/quality-gates/tests/$t" >/dev/null 2>&1 && echo "GREEN" || echo "RED (exit $?)"
done
```
Expected: 현 시점 모두 GREEN (이 4개는 main에서 통과). 만약 RED가 있으면 그 사유를 기록 — 이후 회귀 판정의 baseline.

- [ ] **Step 2: baseline 노트 작성 (commit 불필요)**

작업 메모에 "pre-work: 위 4개 테스트 GREEN 확인 (YYYY-MM-DD)" 기록. 이 plan의 모든 후속 Task는 이 4개가 GREEN을 유지해야 한다.

---

## Task 2: create-sandbox — snapshot 캡처 + logAllRefUpdates + S-A/S-B hardening

스펙 §6.1(snapshot) + §6.3(S-A/S-B). create-sandbox를 한 번 편집(한 커밋).

**Files:**
- Modify: `plugins/quality-gates/scripts/qg-worktree.sh:100-143` (create-sandbox 본문)
- Test: `plugins/quality-gates/tests/test_qg_mutation_guard.sh` (snapshot-존재 테스트 추가)

- [ ] **Step 1: snapshot-존재 failing 테스트 작성**

`test_qg_mutation_guard.sh`의 `field()` 정의(line 23) 다음, 첫 `echo "[mutation-guard: clean...`(line 25) **이전**에 추가:

```bash
echo "[create-sandbox: snapshot captured with all 7 keys]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
SNAP="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
if [ -f "$SNAP" ]; then
  pass "snapshot file exists at per-worktree gitdir"
else
  fail "snapshot file missing: $SNAP"
fi
miss=0
for k in head_reflog_sha stash_sha excl_common_sha excl_wt_sha excludesfile excludesfile_sha logallrefupdates; do
  grep -q "^$k=" "$SNAP" 2>/dev/null || { miss=$((miss+1)); echo "    missing key: $k"; }
done
[ "$miss" -eq 0 ] && pass "snapshot has all 7 keys" || fail "snapshot missing $miss key(s)"
[ "$(sed -n 's/^logallrefupdates=//p' "$SNAP")" = "true" ] \
  && pass "logAllRefUpdates forced true at baseline" || fail "logAllRefUpdates not true"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null
```

- [ ] **Step 2: 테스트 실행 → FAIL 확인**

Run: `bash plugins/quality-gates/tests/test_qg_mutation_guard.sh 2>&1 | grep -A1 'snapshot captured'`
Expected: `✗ snapshot file missing: ...` (create-sandbox는 아직 snapshot을 안 씀).

- [ ] **Step 3: create-sandbox에 logAllRefUpdates 강제 + snapshot 캡처 구현**

`qg-worktree.sh`에서, baseline commit 블록(현 134-139) **직전**에 logAllRefUpdates 강제를 삽입하고, baseline SHA 읽기(현 140) **다음**에 snapshot 캡처를 삽입.

(a) 현재 134행:
```bash
    git -C "$sandbox" add -A >/dev/null 2>&1 || die "git add -A failed in sandbox"
```
**직전에** 삽입:
```bash
    # §6.1/NEW-05 — guarantee reflog logging BEFORE the baseline commit so the
    # baseline and any later HEAD move are logged (default is true, but a host
    # may have pre-set false). Layer 2 later compares this value vs the snapshot.
    # NOTE(side-effect): in a linked worktree this writes to the common .git/config
    # (main repo). 'true' is git's default so no practical harm; documented in §6.1.
    git -C "$sandbox" config core.logAllRefUpdates true || die "cannot set logAllRefUpdates"
```

(b) 현재 140행:
```bash
    base=$(git -C "$sandbox" rev-parse HEAD) || die "cannot read baseline SHA"
```
**직후, 출력 `printf`(현 143) 이전에** 삽입:
```bash
    # §6.1 — capture the pre-verifier baseline snapshot the mutation-guard
    # compares against. Side-channel: lives in the per-worktree gitdir, so the
    # 2-line output contract is unchanged and `git worktree remove` auto-cleans it.
    snap_gitdir=$(git -C "$sandbox" rev-parse --absolute-git-dir) || die "cannot resolve gitdir"
    snap_common=$(git -C "$sandbox" rev-parse --git-common-dir)   || die "cannot resolve common-dir"
    case "$snap_common" in /*) ;; *) snap_common="$sandbox/$snap_common" ;; esac
    snap="$snap_gitdir/qg-mutation-snapshot"

    snap_hash_file() { if [[ -f "$1" ]]; then git -C "$sandbox" hash-object "$1"; else printf 'absent'; fi; }
    # ⚠️ reflog/stash MUST be hashed with the IDENTICAL idiom the guard uses
    # (var-capture + `printf '%s'`), else a clean sandbox false-positives. See guard Layer 3.
    snap_rl=$(git -C "$sandbox" reflog show HEAD 2>/dev/null || true)
    if [[ -n "$snap_rl" ]]; then
      head_reflog_sha=$(printf '%s' "$snap_rl" | git -C "$sandbox" hash-object --stdin)
    else
      head_reflog_sha=empty
    fi
    snap_sl=$(git -C "$sandbox" stash list 2>/dev/null || true)
    stash_sha=$(printf '%s' "$snap_sl" | git -C "$sandbox" hash-object --stdin)
    excl_common_sha=$(snap_hash_file "$snap_common/info/exclude")
    excl_wt_sha=$(snap_hash_file "$snap_gitdir/info/exclude")
    excludesfile=$(git -C "$sandbox" config --get core.excludesFile 2>/dev/null || printf 'absent')
    if [[ "$excludesfile" != "absent" ]]; then
      ef_path="$excludesfile"; case "$ef_path" in "~/"*) ef_path="${HOME:-}/${ef_path#~/}" ;; esac
      excludesfile_sha=$(snap_hash_file "$ef_path")
    else
      excludesfile_sha=absent
    fi
    logallrefupdates=$(git -C "$sandbox" config --get core.logAllRefUpdates 2>/dev/null || printf 'unset')

    {
      printf 'head_reflog_sha=%s\n' "$head_reflog_sha"
      printf 'stash_sha=%s\n'        "$stash_sha"
      printf 'excl_common_sha=%s\n'  "$excl_common_sha"
      printf 'excl_wt_sha=%s\n'      "$excl_wt_sha"
      printf 'excludesfile=%s\n'     "$excludesfile"
      printf 'excludesfile_sha=%s\n' "$excludesfile_sha"
      printf 'logallrefupdates=%s\n' "$logallrefupdates"
    } > "$snap" || die "cannot write snapshot: $snap"
```

- [ ] **Step 4: S-A/S-B hardening (`|| die`) 적용**

S-A — overlay/deletion 루프의 unchecked 명령(현 119-121, 129):
- 119행 `mkdir -p "$sandbox/$(dirname "$rel")"` → `mkdir -p "$sandbox/$(dirname "$rel")" || die "mkdir failed: $rel"`
- 121행 `cp -a "$src" "$sandbox/$rel"` → `cp -a "$src" "$sandbox/$rel" || die "cp failed: $rel"`
- 129행 `rm -f "$sandbox/$rel" 2>/dev/null` → `rm -f "$sandbox/$rel" || die "rm (deletion-honor) failed: $rel"`

S-B — `cd ... && pwd -P` command-sub 4곳(현 62, 88, 207, 217). `$(cd "$x" && pwd -P)`가 cd 실패 시 빈/stale 경로를 내는 것 차단:
- 62행 `abs="$(cd "$parent" && pwd -P)/${sanitized}-${sid_short}"` → 앞줄에서 `base_abs=$(cd "$parent" && pwd -P) || die "cd failed: $parent"` 후 `abs="$base_abs/${sanitized}-${sid_short}"`
- 88행 `main_root=$(cd "$main_root" && pwd -P)` → `main_root=$(cd "$main_root" && pwd -P) || die "cd failed: $main_root"`
- 207행 `repo_root=$(cd "$repo_root" && pwd -P)` → `repo_root=$(cd "$repo_root" && pwd -P) || die "cd failed: $repo_root"`
- 217행 `t_path=$(cd "$t_path" && pwd -P)` → `t_path=$(cd "$t_path" && pwd -P) || die "cd failed: $t_path"`

(주의: 117행 `src="$main_root/$rel"`은 cd가 아니므로 대상 아님. 62/88/207/217만.)

- [ ] **Step 5: 테스트 실행 → snapshot 테스트 + 8 happy-path PASS 확인**

Run: `bash plugins/quality-gates/tests/test_qg_mutation_guard.sh`
Expected: `snapshot file exists` / `snapshot has all 7 keys` / `logAllRefUpdates forced true at baseline` PASS. 기존 8 happy-path도 PASS(가드는 아직 미변경이라 snapshot을 안 읽음 — 무영향). `Result: N passed, 0 failed`.

또한 create-sandbox 출력 계약 회귀 확인:
Run: `bash plugins/quality-gates/tests/test_qg_runtime_sandbox.sh`
Expected: GREEN (출력은 여전히 2줄; snapshot은 사이드채널).

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/scripts/qg-worktree.sh plugins/quality-gates/tests/test_qg_mutation_guard.sh
git commit -m "feat(quality-gates): create-sandbox captures mutation-guard snapshot + S-A/S-B hardening

§6.1 snapshot (7 keys, per-worktree gitdir side-channel, output contract unchanged)
+ force core.logAllRefUpdates=true before baseline (NEW-05) + §6.3 cp/cd || die.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: mutation-guard — 4계층 fail-closed oracle 재작성

스펙 §6.2 전체 + I-D(`yq`). **보안 컨트롤 원자적 재작성**: 우회별 테스트를 먼저 모두 작성→전부 FAIL 확인→가드를 한 번에 교체→전부 PASS + 8 happy-path 유지.

**Files:**
- Modify: `plugins/quality-gates/scripts/qg-worktree.sh:145-200` (`mutation-guard)` case 전체 교체)
- Test: `plugins/quality-gates/tests/test_qg_mutation_guard.sh` (우회 시나리오 추가)

- [ ] **Step 1: Layer-1 우회 테스트 작성 (C-E ×2 + .gitignore)**

`test_qg_mutation_guard.sh` 끝(현 `echo "Result..."` 직전, line 102 이후)에 추가:

```bash
echo "[C-E(a): assume-unchanged hides tracked mutation -> caught by content-hash]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'orig\nHACKED\n' > "$SANDBOX/tracked.txt"
git -C "$SANDBOX" update-index --assume-unchanged tracked.txt
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "assume-unchanged tracked mutation -> forced_downgrade: yes (H-AC2a)" || fail "C-E assume-unchanged EVADED"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[C-E(b): skip-worktree hides tracked mutation -> caught by content-hash]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'orig\nHACKED\n' > "$SANDBOX/tracked.txt"
git -C "$SANDBOX" update-index --skip-worktree tracked.txt
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "skip-worktree tracked mutation -> forced_downgrade: yes (H-AC2b)" || fail "C-E skip-worktree EVADED"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[C-A(iv): .gitignore tamper to hide a new file -> caught by content-hash on tracked .gitignore]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'node_modules/\n.env\nsecretfix.js\n' > "$SANDBOX/.gitignore"   # add ignore line
printf 'export const x=1\n' > "$SANDBOX/secretfix.js"                  # now "ignored"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass ".gitignore tamper -> forced_downgrade: yes (H-AC3iv)" || fail "C-A .gitignore EVADED"
printf '%s' "$G" | grep -q ".gitignore" \
  && pass ".gitignore change surfaced in tracked_diff" || fail ".gitignore not surfaced"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null
```

- [ ] **Step 2: Layer-0 우회 테스트 작성 (C-B + snapshot fail-closed + I-D)**

이어서 추가:

```bash
echo "[C-B: bad baseline sha -> guard_fail exit 4]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT")
G=$("$WT" mutation-guard "$SANDBOX" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" 2>/dev/null); RC=$?
[ "$RC" -eq 4 ] && pass "bad baseline -> exit 4 (H-AC1)" || fail "bad baseline exit was $RC (expected 4)"
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "bad baseline -> forced_downgrade: yes" || fail "bad baseline not forced"
printf '%s' "$G" | grep -q "guard_error:" \
  && pass "guard_error surfaced" || fail "guard_error missing"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[NEW-03(a): snapshot missing -> guard_fail exit 4]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
rm -f "$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null); RC=$?
[ "$RC" -eq 4 ] && pass "snapshot missing -> exit 4 (H-AC1)" || fail "snapshot-missing exit was $RC"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[NEW-03(b): snapshot malformed (key removed) -> guard_fail exit 4]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
SNAP="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
grep -v '^stash_sha=' "$SNAP" > "$SNAP.tmp" && mv "$SNAP.tmp" "$SNAP"   # truncate a required key
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null); RC=$?
[ "$RC" -eq 4 ] && pass "snapshot malformed -> exit 4 (H-AC1)" || fail "snapshot-malformed exit was $RC"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[I-D: single-quote filename stays valid YAML + forced]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'x\n' > "$SANDBOX/foo'bar.js"   # apostrophe in filename
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "single-quote new file -> forced_downgrade: yes (H-AC5)" || fail "single-quote file not caught"
if python3 -c "import yaml" 2>/dev/null; then
  printf '%s' "$G" | python3 -c "import yaml,sys; yaml.safe_load(sys.stdin.read())" 2>/dev/null \
    && pass "guard output valid YAML with single-quote filename" || fail "single-quote breaks YAML"
else
  pass "yaml parse check skipped (pyyaml unavailable)"
fi
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null
```

- [ ] **Step 3: Layer-2 우회 테스트 작성 (C-A 3채널 + C-D-c)**

이어서 추가:

```bash
echo "[C-A(i): common-dir info/exclude smuggle -> ignore_channel_tampered]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'export const fix=1\n' > "$SANDBOX/onlyhack.js"
echo 'onlyhack.js' >> "$(git -C "$SANDBOX" rev-parse --git-common-dir)/info/exclude"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "common info/exclude smuggle -> forced (H-AC3i)" || fail "C-A common EVADED"
printf '%s' "$G" | grep -q "ignore_channel_tampered" \
  && pass "ignore_channel_tampered flagged" || fail "tamper flag missing"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[C-A(ii): per-worktree gitdir info/exclude smuggle -> ignore_channel_tampered]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'export const fix=1\n' > "$SANDBOX/onlyhack.js"
WTDIR="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)"
mkdir -p "$WTDIR/info"; echo 'onlyhack.js' >> "$WTDIR/info/exclude"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "per-worktree info/exclude smuggle -> forced (H-AC3ii)" || fail "C-A per-worktree EVADED"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[C-A(iii): core.excludesFile smuggle -> ignore_channel_tampered]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'export const fix=1\n' > "$SANDBOX/onlyhack.js"
EXC=$(mktemp); echo 'onlyhack.js' > "$EXC"
git -C "$SANDBOX" config core.excludesFile "$EXC"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "core.excludesFile smuggle -> forced (H-AC3iii)" || fail "C-A excludesFile EVADED"
rm -f "$EXC"; rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[C-D-c (NEW-05): persistent logAllRefUpdates=false left set -> reflog_logging_tampered]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
git -C "$SANDBOX" config core.logAllRefUpdates false
printf 'orig\nHACK\n' > "$SANDBOX/tracked.txt"
git -C "$SANDBOX" add -A >/dev/null 2>&1
git -C "$SANDBOX" -c user.email=q@q -c user.name=q commit -q -m sneaky
git -C "$SANDBOX" reset --hard "$BASE" >/dev/null 2>&1   # tree restored; config left false
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "persistent logAllRefUpdates tamper -> forced (H-AC4c)" || fail "C-D-c EVADED"
printf '%s' "$G" | grep -q "reflog_logging_tampered" \
  && pass "reflog_logging_tampered flagged" || fail "logging-tamper flag missing"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null
```

- [ ] **Step 4: Layer-3 우회 테스트 작성 (C-D stash + reset)**

이어서 추가:

```bash
echo "[C-D-a: stash push reverts tree -> caught by stash snapshot-delta]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'orig\nHACK\n' > "$SANDBOX/tracked.txt"
git -C "$SANDBOX" stash push -u -q
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "stash-revert -> forced (H-AC4a)" || fail "C-D stash EVADED"
printf '%s' "$G" | grep -q "stash_added" \
  && pass "stash_added flagged" || fail "stash flag missing"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[C-D-b: commit + reset --hard B reverts tree -> caught by reflog snapshot-delta]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'orig\nHACK\n' > "$SANDBOX/tracked.txt"
git -C "$SANDBOX" add -A >/dev/null 2>&1
git -C "$SANDBOX" -c user.email=q@q -c user.name=q commit -q -m sneaky
git -C "$SANDBOX" reset --hard "$BASE" >/dev/null 2>&1
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "commit+reset-revert -> forced (H-AC4b)" || fail "C-D reset EVADED"
printf '%s' "$G" | grep -q "reflog_advanced" \
  && pass "reflog_advanced flagged" || fail "reflog flag missing"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null
```

- [ ] **Step 5: 신규 테스트 실행 → 전부 FAIL 확인 (old guard)**

Run: `bash plugins/quality-gates/tests/test_qg_mutation_guard.sh 2>&1 | grep '✗'`
Expected: C-E/C-A/C-D/C-B/snapshot 케이스 다수 `✗` (diff 기반 old guard가 우회됨). 8 happy-path + snapshot(Task 2) 케이스는 여전히 `✓`. (FAIL 목록이 있어야 정상 — TDD red.)

- [ ] **Step 6: mutation-guard case 전체를 4계층 가드로 교체**

`qg-worktree.sh`의 `mutation-guard)` ~ 그 case의 닫는 `;;`(현 145-200행 전체)를 아래로 **교체**:

```bash
  mutation-guard)
    # 4-layer fail-closed product-mutation oracle (spec §6.2). Inputs are ONLY
    # (sandbox, baseline B) + a snapshot create-sandbox wrote in the per-worktree
    # gitdir. No channel for a verifier self-claim → structural Law 2 defense.
    # Execution order locked: layer 0 → 1 → 2 → 3 → aggregate.
    [[ $# -eq 3 ]] || die "usage: mutation-guard <sandbox-abs> <baseline-sha>"
    sandbox="$2" base="$3"

    # YAML single-quoted scalar escaper (I-D): '' escapes an embedded quote.
    yq() { local s; s=$(printf '%s' "$1" | sed "s/'/''/g"); printf "'%s'" "$s"; }

    # ---- Layer 0: fail-closed foundation (C-B, NEW-03) ----
    # Any indeterminate result emits forced_downgrade: yes and exits 4 (locked;
    # distinct from die=2 and kill-switch=3). "indeterminate is never PASS."
    guard_fail() {
      echo "tracked_diff: []"
      echo "disallowed_new_files: []"
      echo "guard_flags: []"
      printf 'guard_error: %s\n' "$(yq "$1")"
      echo "forced_downgrade: yes"
      exit 4
    }

    [[ -d "$sandbox" ]] || guard_fail "sandbox not found: $sandbox"
    gitdir=$(git -C "$sandbox" rev-parse --absolute-git-dir 2>&1) \
      || guard_fail "cannot resolve gitdir: $gitdir"
    common=$(git -C "$sandbox" rev-parse --git-common-dir 2>&1) \
      || guard_fail "cannot resolve common-dir: $common"
    case "$common" in /*) ;; *) common="$sandbox/$common" ;; esac
    base_tree=$(git -C "$sandbox" rev-parse "${base}^{tree}" 2>&1) \
      || guard_fail "bad baseline sha: $base ($base_tree)"

    snap="$gitdir/qg-mutation-snapshot"
    [[ -f "$snap" ]] || guard_fail "snapshot missing: $snap"
    # Assert ALL §6.1 keys present — a missing key read as '' would yield a
    # false forced=no (NEW-03). §6.1 table is the key single-source-of-truth.
    for k in head_reflog_sha stash_sha excl_common_sha excl_wt_sha \
             excludesfile excludesfile_sha logallrefupdates; do
      grep -q "^$k=" "$snap" || guard_fail "snapshot missing key: $k"
    done
    snap_get() { sed -n "s/^$1=//p" "$snap" | head -1; }

    forced="no"
    guard_flags=()
    tracked_diff=()
    disallowed=()

    # ---- Layer 1: content tree-hash (C-E + honest mutation) ----
    # Fresh temp index → git re-stats every path, ignoring assume-unchanged /
    # skip-worktree index bits (verified). No -f → tracked .gitignore (part of B)
    # is honored, preserving the legit git-ignored .env setup-only PASS path.
    idx="$gitdir/qg-tmp-idx.$$"; rm -f "$idx"
    add_out=$(GIT_INDEX_FILE="$idx" git -C "$sandbox" add -A -- . 2>&1) \
      || { rm -f "$idx"; guard_fail "add -A failed: $add_out"; }
    cur_tree=$(GIT_INDEX_FILE="$idx" git -C "$sandbox" write-tree 2>&1) \
      || { rm -f "$idx"; guard_fail "write-tree failed: $cur_tree"; }
    rm -f "$idx"

    if [[ "$cur_tree" != "$base_tree" ]]; then
      forced="yes"
      ns=$(git -C "$sandbox" diff --name-status "$base_tree" "$cur_tree" 2>&1) \
        || guard_fail "diff name-status failed: $ns"
      while IFS=$'\t' read -r st p1 p2; do
        [[ -z "$st" ]] && continue
        case "$st" in
          A*)    disallowed+=("$p1") ;;          # new non-ignored file (staged by add -A)
          R*|C*) tracked_diff+=("$p1" "$p2") ;;  # rename/copy: both paths
          *)     tracked_diff+=("$p1") ;;         # M / D / T / U
        esac
      done <<< "$ns"
    fi

    # New symlinks are product-affecting regardless of ignore status (original
    # §6.7-2 rule). add -A skips ignored symlinks, so union them via ls-files.
    others=$(git -C "$sandbox" ls-files --others -z 2>&1) \
      || guard_fail "ls-files --others failed: $others"
    while IFS= read -r -d '' rel; do
      [[ -z "$rel" ]] && continue
      [[ -L "$sandbox/$rel" ]] || continue
      disallowed+=("$rel")
    done < <(printf '%s' "$others")
    [[ ${#disallowed[@]} -gt 0 ]] && forced="yes"

    # ---- Layer 2: ignore-channel + config tamper (C-A, NEW-05) ----
    ho() { if [[ -f "$1" ]]; then git -C "$sandbox" hash-object "$1" 2>/dev/null || printf 'absent'; else printf 'absent'; fi; }
    now_excl_c=$(ho "$common/info/exclude")
    now_excl_w=$(ho "$gitdir/info/exclude")
    now_ef=$(git -C "$sandbox" config --get core.excludesFile 2>/dev/null || printf 'absent')
    if [[ "$now_ef" != "absent" ]]; then
      ef_path="$now_ef"; case "$ef_path" in "~/"*) ef_path="${HOME:-}/${ef_path#~/}" ;; esac
      now_ef_sha=$(ho "$ef_path")
    else
      now_ef_sha="absent"
    fi
    now_lar=$(git -C "$sandbox" config --get core.logAllRefUpdates 2>/dev/null || printf 'unset')

    if [[ "$now_excl_c" != "$(snap_get excl_common_sha)" \
       || "$now_excl_w" != "$(snap_get excl_wt_sha)" \
       || "$now_ef"     != "$(snap_get excludesfile)" \
       || "$now_ef_sha" != "$(snap_get excludesfile_sha)" ]]; then
      forced="yes"; guard_flags+=("ignore_channel_tampered")
    fi
    if [[ "$now_lar" != "$(snap_get logallrefupdates)" ]]; then
      forced="yes"; guard_flags+=("reflog_logging_tampered")
    fi

    # ---- Layer 3: snapshot delta (C-D) ----
    # ⚠️ MUST hash with the IDENTICAL idiom create-sandbox used (var-capture +
    # `printf '%s'`), else a clean sandbox false-positives. absolute
    # rev-list --all --not is FORBIDDEN (sibling-branch false-positive, §10).
    g_rl=$(git -C "$sandbox" reflog show HEAD 2>/dev/null || true)
    if [[ -n "$g_rl" ]]; then
      now_reflog=$(printf '%s' "$g_rl" | git -C "$sandbox" hash-object --stdin)
    else
      now_reflog=empty
    fi
    g_sl=$(git -C "$sandbox" stash list 2>/dev/null || true)
    now_stash=$(printf '%s' "$g_sl" | git -C "$sandbox" hash-object --stdin)
    if [[ "$now_reflog" != "$(snap_get head_reflog_sha)" ]]; then
      forced="yes"; guard_flags+=("reflog_advanced")
    fi
    if [[ "$now_stash" != "$(snap_get stash_sha)" ]]; then
      forced="yes"; guard_flags+=("stash_added")
    fi

    # ---- Emit (two original fields preserved → 8 happy-path compat) ----
    if [[ ${#tracked_diff[@]} -gt 0 ]]; then
      echo "tracked_diff:"
      printf '%s\n' "${tracked_diff[@]}" | sort -u | while IFS= read -r f; do
        [[ -z "$f" ]] && continue; echo "  - $(yq "$f")"
      done
    else
      echo "tracked_diff: []"
    fi
    if [[ ${#disallowed[@]} -gt 0 ]]; then
      echo "disallowed_new_files:"
      printf '%s\n' "${disallowed[@]}" | sort -u | while IFS= read -r f; do
        [[ -z "$f" ]] && continue; echo "  - $(yq "$f")"
      done
    else
      echo "disallowed_new_files: []"
    fi
    if [[ ${#guard_flags[@]} -gt 0 ]]; then
      echo "guard_flags:"
      printf '%s\n' "${guard_flags[@]}" | sort -u | while IFS= read -r g; do
        echo "  - $g"
      done
    else
      echo "guard_flags: []"
    fi
    echo "forced_downgrade: $forced"
    ;;
```

- [ ] **Step 7: 신규 우회 테스트 전부 PASS 확인**

Run: `bash plugins/quality-gates/tests/test_qg_mutation_guard.sh`
Expected: C-E(2)/C-A(4: common·per-worktree·excludesFile·.gitignore)/C-D(3: stash·reset·logging)/C-B/snapshot(2)/I-D 전부 `✓`. `Result: N passed, 0 failed`.

- [ ] **Step 8: 8 happy-path 회귀 확인 (clean → no가 핵심)**

같은 실행 출력에서 다음 8개가 `✓`인지 확인: clean→no / tracked change→yes / independence re-run→yes / ignored .env→no / non-ignored new→yes / new symlink→yes / tracked deletion→yes / YAML-metachar→yes. 특히 **"clean sandbox -> forced_downgrade: no"** 는 reflog/stash 해시 정합성(snapshot↔guard byte-identical)의 회귀 가드 — 여기가 깨지면 Step 6의 Layer 3 해시 idiom이 create-sandbox(Task 2)와 다른 것.

- [ ] **Step 9: Commit**

```bash
git add plugins/quality-gates/scripts/qg-worktree.sh plugins/quality-gates/tests/test_qg_mutation_guard.sh
git commit -m "feat(quality-gates): rewrite mutation-guard as 4-layer fail-closed oracle

Closes C-A/C-B/C-D/C-E (§6.2): content tree-hash (fresh index defeats
assume-unchanged/skip-worktree) + ignore/config tamper vs snapshot +
snapshot-delta (reflog/stash) + fail-closed exit 4. yq() fixes I-D.
8 happy-path tests preserved.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: SKILL R4 fail-closed 에러경로 (C-C)

스펙 §6.4. 가드가 errored/garbled일 때 PASS로 읽히는 경로 차단.

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md:441-447` (Step R4)
- Test: `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`

- [ ] **Step 1: failing 정적 테스트 작성**

`test_skill_orchestration_behavior.sh`의 `# --- v2.2.0 sandbox-executor protocol-shape ---` 블록 끝(현 `assert_line "v2.2.0 in SKILL"` 다음, line 151) 뒤에 추가:

```bash
# --- v2.2.0 mutation-guard hardening protocol-shape ---

# C-C: R4 must route an errored/garbled guard as ≤FAIL, never PASS.
assert_line "R4 routes guard exit 4 as FAIL"        "$(first_line 'exit 4')"
assert_line "R4 surfaces guard_error"               "$(first_line 'guard_error')"
assert_line "R4 surfaces guard stderr verbatim"     "$(first_line 'stderr.*verbatim|verbatim')"
assert_line "R4 'never PASS' for indeterminate guard" "$(first_line 'never.*PASS|indeterminate')"
```

- [ ] **Step 2: 테스트 실행 → FAIL 확인**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | grep -E 'R4|exit 4|guard_error'`
Expected: `FAIL: R4 routes guard exit 4 ...` 등 (SKILL R4에 아직 에러경로 없음).

- [ ] **Step 3: SKILL R4 에러경로 라우팅 테이블 추가**

`SKILL.md` Step R4의 마지막 문단(현 447행, `...this git result is authoritative.`로 끝나는 단락) **다음에** 추가:

```markdown
**R4 exit-code routing (C-C — mirror R0's discipline; an indeterminate guard is never a PASS).** Capture BOTH the guard's stdout YAML AND its exit code:

| Guard result | R4 routing |
|---|---|
| exit 0 + `forced_downgrade: no` (all §6.1 snapshot keys valid) | no product mutation → proceed to R5/R6 normally |
| exit 0 + `forced_downgrade: yes` | cap verdict at FAIL; surface `tracked_diff` / `disallowed_new_files` / `guard_flags` as evidence |
| **exit 4** (`guard_fail`), OR any other non-zero exit, OR a missing/invalid `forced_downgrade` key, OR a `guard_error:` line present | treat as `forced_downgrade: yes` → cap verdict at FAIL; surface the guard's `guard_error` + **stderr verbatim**; mark the Runtime gate failed. **Never read an errored or garbled guard as PASS** (indeterminate ≠ clean). |

An errored guard (corrupt index, lost gitdir, missing/truncated snapshot, bad baseline) must not present as "not a downgrade." This is the orchestration-layer half of the bypass closure — the guard script's layers 0–3 (§6.2) cover C-A/C-B/C-D/C-E; this table covers C-C.
```

- [ ] **Step 4: 테스트 실행 → PASS + 전체 harness GREEN**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: `all protocol-shape assertions PASS`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
git commit -m "fix(quality-gates): R4 fail-closed routing for errored mutation-guard (C-C)

Indeterminate guard (exit 4 / garbled / guard_error) caps verdict at FAIL
and surfaces stderr verbatim — never reads as PASS. Mirrors R0 exit discipline.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: SKILL fallback — SKIP_WITH_EVIDENCE cap + runtime_project_dir (I-A, I-B)

스펙 §6.5. sandbox 비활성 fallback에서 Write verifier가 real tree로 PASS를 못 만들게.

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — R0(406), R3(432), R4 fallback(449), R6(459-463)
- Test: `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`

- [ ] **Step 1: failing 정적 테스트 작성**

Task 4 테스트 블록에 이어서 추가:

```bash
# I-A/I-B: fallback caps at SKIP_WITH_EVIDENCE (never PASS) + single runtime_project_dir.
assert_line "runtime_project_dir variable used"      "$(first_line 'runtime_project_dir')"
assert_line "fallback caps at SKIP_WITH_EVIDENCE"    "$(first_line 'SKIP_WITH_EVIDENCE.*never PASS|never PASS.*SKIP_WITH_EVIDENCE|cap.*SKIP_WITH_EVIDENCE')"
# I-B: the R3 dispatch project_dir must NOT hardcode sandbox_dir (use runtime_project_dir).
if grep -qE 'project_dir:[[:space:]]*\\?"\$runtime_project_dir' "$SKILL_MD"; then
  echo "PASS: R3 dispatch uses runtime_project_dir"
else
  echo "FAIL: R3 dispatch does not use runtime_project_dir"
  fail=$((fail + 1))
fi
```

- [ ] **Step 2: 테스트 실행 → FAIL 확인**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | grep -iE 'runtime_project_dir|SKIP_WITH_EVIDENCE'`
Expected: `FAIL: runtime_project_dir variable used` 등.

- [ ] **Step 3: R0 — runtime_project_dir 도입 + fallback 문구 갱신**

`SKILL.md` Step R0의 Exit 0 / Exit 3 불릿(현 405-406)을 교체:

405행 (Exit 0):
```markdown
- Exit 0 → capture **line 1 = `sandbox_dir`**, **line 2 = `baseline_sha`**. Set `runtime_project_dir = sandbox_dir` (the verifier's `project_dir` for this gate, frozen — overrides the preflight `project_dir` for the Runtime gate only).
```
406행 (Exit 3):
```markdown
- **Exit 3** (kill switch `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1`) → graceful fallback (no sandbox): set `runtime_project_dir = project_dir` (the preflight main-repo dir; `sandbox_dir`/`baseline_sha` stay UNSET). The verifier runs in read-only smoke mode against the real tree. Because the verifier still holds Write tools (frontmatter cannot be revoked per-dispatch), the fallback verdict is **capped at SKIP_WITH_EVIDENCE — never PASS** (no sandbox = no structural Law-2 guarantee = no certification; I-A). BEFORE the R3 dispatch, capture `fallback_pre` = `git -C "$project_dir" status --porcelain --untracked-files=all` plus a tracked content tree-hash baseline (`GIT_INDEX_FILE=<tmp> git -C "$project_dir" add -A -- . && git write-tree`). Print: `> [quality-gates] runtime sandbox disabled — read-only smoke mode on the real tree; verdict capped at SKIP_WITH_EVIDENCE (DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1).`
```

- [ ] **Step 4: R3 — project_dir를 runtime_project_dir로**

R3 dispatch 프롬프트(현 432행) `project_dir: \"$sandbox_dir\"` → `project_dir: \"$runtime_project_dir\"`.

- [ ] **Step 5: R4 fallback guard — SKIP cap + loud 경고 계약**

R4의 fallback 단락(현 449행 `**Fallback working-tree guard ...**`)을 교체:

```markdown
**Fallback working-tree guard (read-only mode only — I-A/I-B).** When the sandbox was disabled (Exit 3), do NOT run the sandbox `mutation-guard`. The verdict is already capped at SKIP_WITH_EVIDENCE (R0); this guard is a pure SAFETY SIGNAL, not a verdict input. After the R3 dispatch, recompute `fallback_post` (porcelain + tracked content tree-hash, same as `fallback_pre`). If anything changed (a porcelain entry in `fallback_post` not in `fallback_pre`, or a differing tree-hash), emit a loud warning **to user-visible stdout** AND record it in `evidence_dir` (§6.6): `> [quality-gates] WARNING: runtime fallback에서 working tree가 변경됨 — <changed files>. sandbox 미사용으로 구조적 보호 없음; 검토 요망 (git diff 후 revert 권장).` git-ignored files do not appear in `--porcelain`, so a setup-only `.env` fix is correctly NOT flagged. The warning does not change the verdict (already ≤SKIP cap) and does not block the gate (P18 — no extra loop).
```

- [ ] **Step 6: R6 — fallback verdict cap 반영**

R6 routing(현 459-463) 상단에 추가 불릿:

```markdown
- **Fallback mode (sandbox disabled)** → the verifier's verdict is capped: a `PASS` becomes **SKIP_WITH_EVIDENCE** (no structural guarantee), `FAIL`/`NEEDS_RESOLUTION` pass through unchanged. The R4 fallback warning (if any) is printed but does not alter the verdict.
```

- [ ] **Step 7: 테스트 실행 → PASS + 전체 harness GREEN**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: 모든 assertion PASS, exit 0.

- [ ] **Step 8: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
git commit -m "fix(quality-gates): fallback caps at SKIP_WITH_EVIDENCE + runtime_project_dir (I-A/I-B)

Sandbox-disabled fallback never yields PASS (no structural Law-2 guarantee);
single runtime_project_dir replaces unset-on-fallback sandbox_dir hardcode;
real-tree change emits a loud safety warning (verdict-independent).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: evidence durability — evidence_dir thread + persona + detect-runtime (I-C)

스펙 §6.6. evidence-log/스크린샷이 sandbox 폐기(R5)에도 생존.

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — R2/R3 (evidence_dir 정의+thread)
- Modify: `plugins/quality-gates/agents/runtime-verifier.md` — Input + Step 3 (보안-민감 persona)
- Modify: `plugins/quality-gates/scripts/detect-runtime.sh:285` (attempted_log_path 절대경로)
- Test: `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`

- [ ] **Step 1: failing 정적 테스트 작성**

Task 5 테스트 블록에 이어서 추가:

```bash
# I-C: evidence_dir threaded to R3 as a main-repo absolute path that survives R5 discard.
assert_line "evidence_dir threaded to verifier"  "$(first_line 'evidence_dir')"
if grep -qE 'evidence_dir.*\.claude/quality-gates/' "$SKILL_MD"; then
  echo "PASS: evidence_dir uses .claude/quality-gates/ path"
else
  echo "FAIL: evidence_dir path not .claude/quality-gates/"
  fail=$((fail + 1))
fi
assert_line "evidence_dir uses CLAUDE_CODE_SESSION_ID" "$(first_line 'CLAUDE_CODE_SESSION_ID')"
```

- [ ] **Step 2: 테스트 실행 → FAIL 확인**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | grep -i evidence_dir`
Expected: `FAIL: evidence_dir threaded to verifier`.

- [ ] **Step 3: SKILL — evidence_dir 정의 + R3 thread**

R2(현 423행 `**Step R2 — gather spec ...`) 끝에 evidence_dir 정의 문장 추가:
```markdown
Also derive `evidence_dir = "$project_dir/.claude/quality-gates/$CLAUDE_CODE_SESSION_ID/"` (the preflight main-repo `project_dir`, NOT the sandbox — so it survives the R5 sandbox discard; `$CLAUDE_CODE_SESSION_ID` is the same value used for the pipeline state file). This absolute path is threaded to the verifier so its evidence-log + screenshots land in the main repo, not inside the disposable sandbox.
```

R3 dispatch 프롬프트(현 431-437)에 `evidence_dir` 라인을 `project_dir` 다음에 추가:
```
    project_dir: \"$runtime_project_dir\"
    evidence_dir: \"$evidence_dir\"
```

- [ ] **Step 4: runtime-verifier.md — evidence_dir 입력 + Step 3 분리 명시 (보안-민감)**

(a) `## Input` 섹션(현 70-79)의 `project_dir` 불릿 다음에 추가:
```markdown
- `evidence_dir`: **absolute path in the MAIN repo** (`<main>/.claude/quality-gates/<sid>/`), OUTSIDE the sandbox. Write your evidence-log and screenshots HERE — the sandbox is discarded after the gate, so anything written under `project_dir` (the sandbox) is destroyed. Product/service files you touch during boot go in `project_dir` (sandbox); evidence goes in `evidence_dir`.
```

(b) `## Step 3: Write the evidence-log`(현 116-117)의 첫 문장을 교체:
```markdown
Write the evidence-log to `<evidence_dir>/runtime-evidence.md` and screenshots to `<evidence_dir>/screenshots/<surface>.png` — **always the absolute `evidence_dir`, never a sandbox-relative `.claude/...` path** (the sandbox is git-ignored and discarded; a relative write would be destroyed by R5, dangling the Evidence Log reference — I-C). `manifest.attempted_log_path` is already this absolute path. Include these sections:
```

(c) Step 2 web flow 스크린샷 경로(현 109행 `Capture screenshot to .claude/quality-gates/<sid>/screenshots/...`)를:
```markdown
For **web** flows (per `mcp_browser`): navigate → interact (`click`/`fill`/`fill_form`/`type_text`/`hover`/`press_key`) → assert the expected DOM/network result. Capture a screenshot to `<evidence_dir>/screenshots/<surface>.png` (absolute, main repo), a DOM snapshot, and the network status.
```

- [ ] **Step 5: detect-runtime.sh — attempted_log_path 절대경로**

`detect-runtime.sh:285`:
```bash
emit "attempted_log_path: .claude/quality-gates/${CLAUDE_CODE_SESSION_ID:-unknown}/runtime-evidence.md"
```
→
```bash
emit "attempted_log_path: $PWD/.claude/quality-gates/${CLAUDE_CODE_SESSION_ID:-unknown}/runtime-evidence.md"
```
(detect-runtime는 preflight에서 main repo cwd로 실행되므로 `$PWD` = main repo 절대경로.) 헤더 주석(현 24행)도 `.claude/...` → `$PWD/.claude/...`로 동기화.

- [ ] **Step 6: 테스트 실행 → PASS (harness + persona frontmatter + detect-runtime)**

Run:
```bash
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
bash plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh
bash plugins/quality-gates/tests/test_detect_runtime.sh
```
Expected: 셋 다 GREEN. (persona body만 바뀌고 frontmatter는 무변경이라 frontmatter 테스트 무영향; detect-runtime는 attempted_log_path 미assert이므로 무영향.)

- [ ] **Step 7: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/agents/runtime-verifier.md plugins/quality-gates/scripts/detect-runtime.sh plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
git commit -m "fix(quality-gates): durable evidence_dir survives sandbox discard (I-C)

Evidence-log + screenshots written to absolute main-repo
.claude/quality-gates/<sid>/, not the discarded sandbox. persona + SKILL R3
thread evidence_dir; detect-runtime attempted_log_path now absolute.
(security-sensitive persona edit)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: SKILL NEEDS_RESOLUTION retry — baseline 재캡처 (I-G)

스펙 §6.7. retry가 옛 `baseline_sha`를 재사용해 false FAIL을 내던 것 수정.

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md:512` (Yes, retry 분기)
- Test: `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`

- [ ] **Step 1: failing 정적 테스트 작성**

Task 6 테스트 블록에 이어서 추가:

```bash
# I-G: retry must re-capture BOTH sandbox_dir AND baseline_sha (new snapshot auto-recorded).
retry_recap_line=$(first_line 're-capture')
assert_line "retry re-capture phrase present" "$retry_recap_line"
if grep -E 're-capture' "$SKILL_MD" | grep -q 'baseline_sha' && \
   grep -E 're-capture' "$SKILL_MD" | grep -q 'sandbox_dir'; then
  echo "PASS: retry re-captures both sandbox_dir and baseline_sha"
else
  echo "FAIL: retry does not re-capture both sandbox_dir + baseline_sha"
  fail=$((fail + 1))
fi
```

- [ ] **Step 2: 테스트 실행 → FAIL 확인**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | grep -i 're-capture'`
Expected: `FAIL: retry re-capture phrase present`.

- [ ] **Step 3: retry 분기 문구 교체**

`SKILL.md:512` (Yes, retry 불릿):
```markdown
- **Yes, retry** → increment resolution counter; if exceeds env limit, fall through to Skip with evidence. Otherwise re-create the sandbox (Step R0) so retries start from a clean baseline, then re-dispatch runtime-verifier.
```
→
```markdown
- **Yes, retry** → increment resolution counter; if exceeds env limit, fall through to Skip with evidence. Otherwise re-create the sandbox (Step R0) and **re-capture BOTH `sandbox_dir` (line 1) AND `baseline_sha` (line 2)** from the new output, refreshing the orchestrator variables — create-sandbox emits a NEW commit `B` each call, so reusing the old `baseline_sha` makes the guard `guard_fail "bad baseline sha"` (a false FAIL). The new snapshot is auto-recorded in the new gitdir; the stale sandbox + its old snapshot are force-removed by R0's idempotent cleanup. Then re-dispatch runtime-verifier with the refreshed `sandbox_dir`.
```

- [ ] **Step 4: 테스트 실행 → PASS + 전체 harness GREEN**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: 모든 assertion PASS, exit 0.

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
git commit -m "fix(quality-gates): retry re-captures baseline_sha + sandbox_dir (I-G)

create-sandbox emits a fresh commit B each call; retry must refresh BOTH
output lines or the guard false-FAILs on a stale baseline sha.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: detect-runtime.sh — $HOME unbound 방어 (I-F)

스펙 §6.8. unset `$HOME`이 manifest emit 전체를 abort시키던 것 차단.

**Files:**
- Modify: `plugins/quality-gates/scripts/detect-runtime.sh:196`
- Test: `plugins/quality-gates/tests/test_detect_runtime.sh`

- [ ] **Step 1: failing 테스트 작성**

`test_detect_runtime.sh`의 Test 12(현 끝, line 216) 다음, `echo ""` (line 218) 이전에 추가:

```bash
# --- Test 13: $HOME unset must NOT abort the manifest (I-F) ---
echo "== Test 13: env -u HOME non-empty manifest =="
OUT=$(cd "$FIXTURES/web-compose" && env -u HOME bash "$SCRIPT" 2>/dev/null)
RC=$?
assert_eq "$RC" "0" "T13: exit 0 with HOME unset"
assert_contains "$OUT" "project_type: web" "T13: emits project_type with HOME unset"
assert_contains "$OUT" "runnable_surfaces:" "T13: emits runnable_surfaces (not aborted before emit)"
assert_contains "$OUT" "mcp_browser:" "T13: emits mcp_browser line"
```

- [ ] **Step 2: 테스트 실행 → FAIL 확인**

Run: `bash plugins/quality-gates/tests/test_detect_runtime.sh 2>&1 | grep -i 'T13'`
Expected: `✗ FAIL: T13: ...` (bare `$HOME` under `set -u` → unbound → abort, empty output).

- [ ] **Step 3: $HOME 방어 구현**

`detect-runtime.sh:196`:
```bash
SETTINGS_FILES=("$HOME/.claude/settings.json" ".claude/settings.json" ".mcp.json")
```
→
```bash
SETTINGS_FILES=("${HOME:-}/.claude/settings.json" ".claude/settings.json" ".mcp.json")
```
그리고 루프(현 197-208)에서 빈/루트 경로 엔트리 skip — `for sf in ...` 본문 첫 줄에 가드 추가:
```bash
for sf in "${SETTINGS_FILES[@]}"; do
  [[ "$sf" == "/.claude/settings.json" ]] && continue   # HOME unset → skip the ~ entry
  if [[ -f "$sf" ]]; then
```

- [ ] **Step 4: 테스트 실행 → PASS + 전체 detect-runtime GREEN**

Run: `bash plugins/quality-gates/tests/test_detect_runtime.sh`
Expected: T13 PASS + 기존 T1–T12 PASS. `Tests passed: N, failed: 0`.

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/scripts/detect-runtime.sh plugins/quality-gates/tests/test_detect_runtime.sh
git commit -m "fix(quality-gates): detect-runtime survives unset HOME (I-F)

\${HOME:-} + skip empty settings entry — unset HOME no longer aborts the
manifest before emit (which silently disabled the blast-radius gate).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: 문서 — kill-switch (I-E) + CHANGELOG 보강

스펙 §6.8 I-E + §13. `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX`를 source-of-truth에 등재.

**Files:**
- Modify: `plugins/quality-gates/README.md:336-342` (Runtime gate 단위 disable 표)
- Modify: `plugins/quality-gates/commands/qg.md:71-72` (env 표)
- Modify: `plugins/quality-gates/CHANGELOG.md:43-52` (`[2.2.0]` Security/Fixed)
- Test: `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` (이미 kill switch grep 존재 — 추가 doc grep)

- [ ] **Step 1: README kill-switch 표에 추가**

`README.md`의 "Runtime gate 단위 disable" 표(현 338-342)에 행 추가 (현 342행 `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE` 다음):
```markdown
| `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1` | Runtime gate의 git-worktree 샌드박스 executor를 끄고 read-only smoke fallback. verdict는 SKIP_WITH_EVIDENCE로 cap(절대 PASS 아님), real-tree 변경 시 loud 경고. `qg-worktree.sh create-sandbox`가 exit 3. |
```

- [ ] **Step 2: qg.md env 표에 추가**

`qg.md`의 표(현 71-72) `DEVBREW_QG_KEEP_WORKTREE` 다음에 추가:
```markdown
| `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1` | Disable the Runtime gate sandbox executor (read-only smoke fallback; verdict capped at SKIP_WITH_EVIDENCE) |
```

- [ ] **Step 3: CHANGELOG [2.2.0] Security/Fixed 보강**

`CHANGELOG.md`의 `[2.2.0]` 섹션, 현 `### Security` 블록(43-52) **다음, `## [2.1.0]`(54) 이전**에 `### Fixed` 블록 추가:
```markdown
### Fixed
- **mutation-guard 5개 우회 봉쇄 (보안).** diff 기반 oracle을 **snapshot + content
  tree-hash + ignore/config-tamper + snapshot-delta**(전부 fail-closed) 4계층으로 재작성.
  닫힌 우회: C-A `info/exclude`/`core.excludesFile`/`.gitignore` 밀반입,
  C-B git-failure fail-open(rc 캡처 → exit 4), C-D `stash`/`commit+reset --hard`
  (reflog/stash snapshot-delta) + 영구 `logAllRefUpdates=false` 억제(config tamper),
  C-E `assume-unchanged`/`skip-worktree` index 비트(fresh-index content-hash).
  snapshot은 per-worktree gitdir 사이드채널(출력 계약 2줄 무변경). 우회별 회귀 테스트 동반.
- **C-C SKILL R4 fail-closed 라우팅.** errored/garbled 가드(exit 4 / `guard_error` /
  무효 key)를 PASS가 아니라 ≤FAIL로 라우팅 + stderr verbatim surface.
- **I-A/I-B fallback SKIP cap.** `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1` fallback verdict를
  SKIP_WITH_EVIDENCE로 cap(절대 PASS 아님) + 단일 `runtime_project_dir`(unset `sandbox_dir`
  하드코딩 제거) + real-tree 변경 loud 경고.
- **I-C evidence durability.** evidence-log/스크린샷을 메인 repo 절대 `evidence_dir`
  (`.claude/quality-gates/<sid>/`)에 기록 → 샌드박스 폐기(R5) 생존.
- **I-D YAML escape.** single-quote 파일명을 `yq()`로 escape → 유효 YAML.
- **I-E kill-switch 문서화.** `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX`를 README source-of-truth
  표 + qg.md env 표에 등재.
- **I-F detect-runtime `${HOME:-}`.** unset `$HOME`이 manifest emit을 abort시키던 것 차단.
- **I-G retry baseline 재캡처.** NEEDS_RESOLUTION retry가 새 `sandbox_dir` + `baseline_sha`를
  둘 다 재캡처(옛 sha 재사용 false-FAIL 제거).
- **S-A/S-B create-sandbox 견고화.** overlay `cp`/`mkdir`/deletion + `cd` command-sub에 `|| die`.

> non-goal(한계 인정): `logAllRefUpdates` *flip-and-restore* 변종(끄고→commit+reset→복원)은
> git ground-truth에 흔적이 없어 OS-수준 통제 없이는 구조적으로 닫을 수 없다(spec §3).
> 단 이 변종도 shipping product == baseline.
```

- [ ] **Step 4: doc grep 회귀 + Korean-primary 린터 확인**

Run:
```bash
grep -q 'DEVBREW_QG_DISABLE_RUNTIME_SANDBOX' plugins/quality-gates/README.md && echo "README OK"
grep -q 'DEVBREW_QG_DISABLE_RUNTIME_SANDBOX' plugins/quality-gates/commands/qg.md && echo "qg.md OK"
python3 plugins/quality-gates/scripts/check-changelog-korean-primary.py 2>&1 | tail -3 || true
bash plugins/quality-gates/tests/test_readme_state_diagram_complete.sh
```
Expected: `README OK` / `qg.md OK`; CHANGELOG Korean-primary 린터 통과(있다면); README state-diagram 테스트 GREEN.

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/README.md plugins/quality-gates/commands/qg.md plugins/quality-gates/CHANGELOG.md
git commit -m "docs(quality-gates): document RUNTIME_SANDBOX kill switch + [2.2.0] Fixed (I-E)

source-of-truth table + qg.md env ref + CHANGELOG Fixed block covering the
5-bypass closure and I-A..I-G/S-A/S-B fixes.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: 최종 회귀 + AC 커버리지 + qg self-review 재실행

스펙 §9 검증 계획 + §7 AC 전부 충족 확인.

**Files:**
- (변경 없음 — 검증. 발견 시 해당 Task로 회귀)

- [ ] **Step 1: 전체 영향 테스트 GREEN 확인 (repo root)**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in test_qg_mutation_guard.sh test_qg_runtime_sandbox.sh test_qg_worktree_helper.sh \
         test_detect_runtime.sh test_runtime_verifier_frontmatter.sh \
         test_runtime_verifier_behavior.py test_no_secret_prompts.py \
         harness/test_skill_orchestration_behavior.sh test_check_allowed_tools_order.sh; do
  echo "=== $t ==="
  case "$t" in
    *.py) python3 "plugins/quality-gates/tests/$t" >/dev/null 2>&1 && echo GREEN || echo "RED ($?)";;
    *)    bash "plugins/quality-gates/tests/$t" >/dev/null 2>&1 && echo GREEN || echo "RED ($?)";;
  esac
done
```
Expected: 신규/수정 테스트 + Task 1 baseline GREEN 항목 모두 GREEN. RED가 있으면 Task 1 baseline과 대조(pre-existing red인지 신규 회귀인지) — 신규 회귀면 해당 Task로 돌아가 수정.

- [ ] **Step 2: AC → Task 커버리지 매핑 검증 (체크리스트)**

spec §7의 H-AC1..10이 각 테스트로 커버되는지 대조:

```
H-AC1 fail-closed exit 4      → Task 3 C-B/snapshot-missing/snapshot-malformed (exit 4 assert)
H-AC2a assume-unchanged       → Task 3 C-E(a)
H-AC2b skip-worktree          → Task 3 C-E(b)
H-AC3 i/ii/iii ignore-tamper  → Task 3 C-A common/per-worktree/excludesFile
H-AC3 iv .gitignore           → Task 3 C-A(iv)
H-AC4 a/b/c snapshot-delta    → Task 3 C-D stash/reset/logging
H-AC5 YAML single-quote       → Task 3 I-D
H-AC6 R4 routing              → Task 4 정적 grep
H-AC7 fallback SKIP+runtime_project_dir → Task 5 정적 grep
H-AC8 evidence durability     → Task 6 정적 grep
H-AC9 retry baseline          → Task 7 정적 grep
H-AC10 회귀 무손상            → Task 1 baseline + 8 happy-path + T13 + I-E doc grep
```
모든 행에 대응 테스트가 GREEN인지 확인. 빈 셀이 있으면 누락 — 해당 Task에 테스트 추가.

- [ ] **Step 3: qg self-review 재실행 (이번엔 green이어야 — spec §13)**

이 plan을 구현한 브랜치(`feature/qg-sandbox-executor`)에 대해 다시:
```
/quality-gates:quality-pipeline review
```
Expected: Review gate가 이전에 찾은 5개 우회 + 7 IMPORTANT를 더 이상 발견하지 않음. 새 CRITICAL이 나오면 그것이 다음 compounding 사이클(Law 3) — persona/가드/테스트를 고친다. (이 plan의 변경 자체가 "보안 컨트롤을 에러경로·우회 테스트 없이 ship한" 원인을 테스트로 봉인하는 Law 3 compounding 이벤트.)

- [ ] **Step 4: findings 파일 정리 (Law 3 — 흡수 완료)**

spec이 problem statement를 흡수했으므로 임시 findings 파일 제거:
```bash
git rm --cached .claude/qg-review-findings-sandbox-executor.md 2>/dev/null || rm -f .claude/qg-review-findings-sandbox-executor.md
```
(`.claude/`는 git-ignored이므로 tracked가 아닐 가능성 높음 — `rm -f`로 충분.)

- [ ] **Step 5: 최종 상태 확인 (커밋 불필요 — 검증 종료)**

Run: `git -C /Users/jeonghokim/Downloads/devbrew log --oneline -10`
Expected: Task 2–9의 8개 신규 커밋 + 기존 sandbox-executor 커밋. plugin.json version은 2.2.0 유지(bump 없음 — spec §13).

---

## 부록: spec 매핑 요약

| spec § | Task | 핵심 |
|---|---|---|
| §6.1 snapshot 캡처 | 2 | 7-key snapshot + logAllRefUpdates true + per-worktree gitdir |
| §6.2 4계층 가드 | 3 | Layer 0 fail-closed(exit 4) / 1 content-hash / 2 tamper / 3 delta + yq |
| §6.3 S-A/S-B | 2 | cp/mkdir/cd `\|\| die` |
| §6.4 R4 라우팅 (C-C) | 4 | indeterminate → ≤FAIL + stderr verbatim |
| §6.5 fallback (I-A/I-B) | 5 | SKIP cap + runtime_project_dir + loud 경고 |
| §6.6 evidence (I-C) | 6 | 절대 evidence_dir + persona + detect-runtime |
| §6.7 retry (I-G) | 7 | baseline_sha + sandbox_dir 재캡처 |
| §6.8 I-F/I-E/I-D | 8, 9, 3 | $HOME / kill-switch doc / yq |
| §13 version | 9 | 2.2.0 유지 (bump 없음) |
