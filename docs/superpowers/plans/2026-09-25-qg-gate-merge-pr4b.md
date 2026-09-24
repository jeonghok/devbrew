# qg 한 파이프라인 구현 계획 (PR4b/7)

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development`(권장) 또는 `superpowers:executing-plans` 로 이 계획을 Task 단위로 실행한다. 단계는 체크박스(`- [ ]`) 표기다.

**Goal:** `runtime-verifier` 와 그 딸린 것(샌드박스 실행 경로 · Decision 1·2 · 해소 루프 · 옛 판정 어휘)을 지우고 두 게이트를 **한 파이프라인**으로 합친다. 차등 테스트는 매 실행 돌고, 판정은 합성기가 `--emit-verdict` · `--angles` 로 **항상** `clean` · `defect` · `not-certified (<사유>)` 셋 중 하나로 낸다. **breaking** — 공개 인자 넷(`both` · `review` · `runtime` · `--skip-runtime`)이 사라진다.

**Architecture:** 파이프라인 골격은 설계 §6.1 의 다섯 단계다 — ① 스코프 ② 차등 테스트 ③ 각도 + 리뷰어 ④ 출처-제거 재비판 ⑤ 합성 · 판정. 옛 Runtime gate 레퍼런스는 verifier 몫(R5a · R7 · R9)을 걷어낸 **차등 테스트 레퍼런스**(`references/differential-test.md`)가 되고, HEAD 축은 샌드박스 대신 `seal-worktree.sh` 의 봉인 커밋에서 선다. 판정 어휘는 여전히 `verdict.py` 한 곳에 살고, 오케스트레이터는 호출자만 아는 사유(`trivia` · `kill-switch` · `scope-empty` · `silent-drop` · `error-axis`)를 `--reason` 으로 싣는다. 토픽 스코프 배선(선언 → 커밋 집합 → 합친 트리)은 **PR4c** 다.

**Tech Stack:** Python 3.9+ (시스템 `python3` — 3.10+ 문법 금지. 표준 라이브러리 + PyYAML) · bash 3.2 호환 락 · `shared/tests/assert.sh` · git 2.54

**Spec:** `docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md` — §6.1(한 파이프라인) · §6.3.1(각도 셋) · §6.3.5(처분 — 보안·판정 fail-closed) · §6.4.1(봉인자 분리 · `create-head` assert) · §6.4.3(판정 어휘 · 사유) · §6.4.4(C2 제거 목록 일곱) · §6.5.1(breaking 전수 · 환경 스위치) · §6.5.2(친절한 오류) · §11(AC1 · AC2 · AC8 · AC9 · AC11 · AC12 · AC14 · AC21 · AC23) · §12 · §13 · §16(4b · 이 계획이 4c 를 떼어 낸다)

---

## Global Constraints

설계와 앞 PR 이 정한 것을 그대로 옮긴다. 모든 Task 의 요구사항에 암묵적으로 포함된다.

- **판정 어휘는 `scripts/verdict.py` 밖에 두지 않는다**(PR2). SKILL 과 레퍼런스는 판정값을 «정하지» 않는다 — 합성기가 낸 `verdict:` 줄을 읽을 뿐이다. `PASS` · `FAIL` · `SKIP_WITH_EVIDENCE` · `NEEDS_RESOLUTION` 는 `/qg critique`(`critiquing-artifacts`) 밖에서 **한 자리도 남지 않는다**.
- **공시와 차단은 다른 술어다**(헌장). 막는 것은 항목 소실 · 셀 수 없음 · 주 판정자 사망(`Ledger.blocks()`)뿐이다. 보조 입력 사망과 판정을 바꾼 강제는 **드러내되 막지 않는다**.
- **각도 ≠ 에이전트**(§6.3.1). `angles.py` 는 수행자 명단을 갖지 않는다. 오케스트레이터가 쓰는 각도 파일은 매 iteration 새로 쓴다.
- **차등 테스트는 trivia escape 와 kill switch 외에는 생략되지 않는다**(AC2). 게이트 범위를 고르는 인자·질문이 없다(AC1).
- **토픽 스코프는 이 PR 밖이다**(4c). `resolve-topic.sh` · `combine-tips.sh` 는 **호출하지 않는다**. `declaration-invalid` · `merge-conflict` 의 발화 지점은 4c 의 빚으로 남는다(`test_verdict_vocabulary.sh` 의 `debt` 리터럴).
- **공개 계약 문자열(`.claude-plugin/marketplace.json` · `plugins/quality-gates/.claude-plugin/plugin.json` 의 `description`) · 루트 `CLAUDE.md` 는 건드리지 않는다**(PR5). `plugin.json` 은 `version` 만 바꾼다.
- **`shared/docreview/**` · `shared/adjudication/**` · `plugins/spec-distill/**` · `plugins/plugin-audit/**` 는 한 바이트도 바뀌지 않는다.** (R-W 가 plugin-audit 를 건드리지 않게 만든다.)
- **fail4 계약은 원자적이다** — 실패 경로에서 stdout 에 아무것도 쓰지 않는다. **exit 코드 셋**: `0` 정상 · `2` 잘못된 **호출** · `4` 실패한 **판정**. 파이썬 traceback(exit 1)은 계약 위반이다.
- **리뷰어가 준 필드는 불신한다.** `agent` · `sources` · `f` · `to` 는 전부 비신뢰 입력이다. 비신뢰 입력에 거는 정규식은 `fullmatch` 를 쓴다(`$` 는 끝 개행 앞에서도 맞는다).
- **스윕은 `git grep -n -P -i` 로, 단어 경계 없이, 제외는 매치 단위로** 한다(`git grep -E` 의 `\b` 는 이 git 에서 조용히 0건이다). 파일 단위로 제외하지 않는다 — 한 파일 안에 남길 매치와 지울 매치가 섞여 있다.
- **규칙을 옮기는 편집은 삭제 쪽 락을 생성 쪽으로 따라가게 한다.** 락을 지우는 행마다 «그 규칙을 이제 무엇이 지키는가»를 인벤토리에 적는다. 「대상 소멸」이면 그렇다고 적는다.
- **회귀는 열거 목록이 아니라 도출 집합으로 돈다** — `run-suite.sh`(아래 Task 1)가 네 디렉토리의 셸 락 전부를 돈다. Task 안의 「돌릴 락」 목록은 최소 집합이지 전부가 아니다.
- **선재 RED 기준선은 «실패 파일 이름 + 실패 줄 수»**로 잡는다(`^[[:space:]]*✗|^FAIL:`). 이미 RED 인 파일 안의 새 실패는 rc 로 원리적으로 안 보인다.
- **`check_wiring.py` 의 `synthesize_findings.py` 면제 키는 줄번호다** — 합성기를 고치는 Task 마다 같은 커밋에서 실측으로 재앵커한다(`exempt_stale=0` 이 답한다). 주석에 델타를 적지 않는다.
- **버전은 브랜치에서 정하지 않는다** — 머지 직전에 `origin/main` 을 다시 보고 정한다(breaking → major).
- **최신화는 merge, rebase 금지.** 워크트리 격리 — 세션이 치는 명령에서 메인 체크아웃으로 `cd` 금지, `git -C` 금지(제품 스크립트 안의 `git -C` 는 이 규칙의 대상이 아니다), bare `git stash` 금지.
- **커밋 트레일러** — 마지막 `-m` 단락 **하나**에 `Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4b` 와 `Co-Authored-By: <그 커밋을 쓴 실제 모델>` 두 줄.
- **`PYTHONDONTWRITEBYTECODE=1`** 로 돌린다. 파이썬 편집마다 `python3 -m py_compile` 로 확인한다.
- **`plugins/quality-gates/tests/*.sh` 는 git 모드 100755** 여야 한다. 새 테스트 파일은 `chmod +x` 후 `git add`.
- **워크트리와 `$CLAUDE_JOB_DIR/tmp` 는 세션 재개에 사라진다.** git-ignored 산출물(기준선 · 인벤토리 · 변이 표 · SDD 원장)은 매 갱신마다 `~/.claude/sdd-mirror/qg-gate-merge-pr4b/` 로 복사한다.
- **계획 문면의 인라인 코드 안 `\``는 백틱 하나를 뜻한다** — 산문 · 표 칸의 인라인 코드에 백틱을 담으려고 쓴 표기다. 파일에 옮길 때 백슬래시를 쓰지 않는다. 펜스 블록(```` ``` ````) 안의 문면은 **글자 그대로** 옮긴다 — 단 bash 펜스 안의 `\`` 는 bash 문법이다(큰따옴표 안의 백틱 이스케이프). 옮기기 전에 목적지 파서로 검증한다(`bash -n` · `python3 -m py_compile`).
- **자기서사 금지.** SKILL · 레퍼런스 · persona 는 모델이 읽고 행동하는 산출물이다 — 새로 쓰는 문장에 「이 문단은 iter-N 에서…」 같은 이력을 넣지 않는다. 이력은 CHANGELOG · PR 본문에 둔다. 지우는 절이 이력만 담고 있으면 같이 지운다.

## Review Focus

스펙이 함의하지만 어느 Task 의 기본 테스트도 태우지 않는 입력 중, 쓰는 사람을 가장 먼저 물 다섯. 각 줄의 테스트는 소유 Task 에 들어가 있다.

1. **`.claude/` 를 무시하지 않는 사용자 리포**(흔하다 — `.claude/settings.json` 을 커밋하는 리포) → 오늘의 `seal-worktree.sh` 는 인덱스 자리가 무시되지 않는다며 **exit 2 로 죽는다.** 배선하면 그런 리포의 매 실행이 HEAD 축 미관측 → `not-certified` 가 된다. 기대: 봉인이 성공하고 봉인 트리에 임시 인덱스가 없다. — Task 4 `case_seal_succeeds_when_claude_dir_not_ignored`
2. **제거 인자와 존치 인자의 조합**(`/qg review --paths 'src/*'` · `/qg branch review`) → 제거 인자는 한 줄 공지 후 무시, 존치 인자는 그대로 선다. 오늘은 `--paths` 자체가 `setup-qg.sh` 에서 `Unknown argument` 로 죽는다(선재). — Task 5 `case_removed_arg_with_kept_paths`
3. **Retry 로 코드가 바뀐 뒤의 iteration** → 차등 테스트가 **새 트리로** 다시 돈다. 앞 iteration 의 `aggregate.yaml` 을 재사용하면 고치기 전 트리의 결과가 고친 뒤 판정이 된다. — Task 8 `case_differential_runs_inside_every_iteration`
4. **보조 입력(`recritic.diff`)만 죽은 실행** → 판정은 막히지 않는다. 공시 줄은 나오되 `**이 실행은 clean이 아니다**` 마커는 없다. 오늘은 마커가 서서 SKILL 이 not-clean 으로 읽는다(헌장 위반). — Task 3 `case_aux_death_discloses_without_not_clean_marker`
5. **보안 리뷰어 kill switch + 탐지 0 + 재비판 0** → 판정은 `not-certified (angle-absent)` 다. 절대 `clean` 이 아니다. 오늘은 배너 한 줄만 내고 verdict 표면에 `clean` 이 설 수 있다. — Task 8 `case_security_switch_is_not_certified_even_with_zero_findings`

---

## 이 PR 이 지는 것

| 항목 | 내용 | 집행 자리 |
|---|---|---|
| **AC1** | 게이트 범위를 묻지 않는다. 제거 인자는 §6.5.2 의 한 줄을 내고 정상 진행 | `setup-qg.sh`(Task 5) · SKILL Arguments(Task 7) |
| **AC2** | 차등 테스트는 trivia · kill switch 외에는 생략되지 않는다 | SKILL 파이프라인 절(Task 7) · 판정 배선 락(Task 8) |
| **AC8 · AC9** | 판정값은 셋, `not-certified` 는 사유 동반 · kill switch 실행은 `not-certified (kill-switch)` | 합성기 상시 `--emit-verdict`(Task 8) |
| **AC10 · AC11 · AC12** | 각도 상태가 항상 산출물에 있다 · 보안/판정 `absent` 면 clean 아님 · 다른 전제 `absent` 는 공시만 | 합성기 상시 `--angles` + 각도 파일 규칙(Task 8) |
| **AC14** | 봉인은 실제 인덱스 · HEAD · 워킹트리를 안 바꾸고, 봉인 트리에 인덱스 파일이 없다 | `seal-worktree.sh` 인덱스 자리 이동(Task 4) — 기존 락 유지 + 새 케이스 |
| **AC21** | 제거된 테스트가 어떤 `# guards:` 글롭의 유일 대상이 아니다 | Task 7 마지막 단계 — `test_guards_coverage_bidirectional.sh` |
| **AC23** | 옛↔새 매핑표가 산출자와 함께 사라진다 | Task 2 — `LEGACY_VERDICTS` · `--legacy-verdict` 제거 |
| **§6.4.1** | `create-sandbox` 대신 봉인자 · `create-head` 의 assert 가 「봉인 커밋의 트리가 기대 OID 와 일치」로 | Task 4 |
| **§6.4.4** | C2 제거 목록 일곱의 전수 처분 | Task 7(verifier · 브라우저 · spec AC 런타임 · 샌드박스 배관 · block policy · 런타임 스코프 · 해소 루프) — mutation guard 는 R-W |
| **§6.5.1** | breaking 전수 중 4b 몫 — 인자 넷 · 환경 스위치 넷 | Task 5 · 6 · 7 · 8 |
| **§6.3.5** | 보안 · 판정 각도 디스패치 처분 `fail-closed` · 다른 전제 `fail-open + disclosure` | Task 8 — `--angles` 배선과 **같은 커밋** |
| 부채 | 사유 둘(`trivia` · `kill-switch`)의 발화 지점 | Task 8 |
| 부채 | `--adversarial` 제거 · `author` 기본값 · `downgrade` 분기 · raise 가드의 접기 재구현 · 자기서사 주석 | Task 2 |
| 부채 | 보조 입력 사망이 not-clean 마커를 세운다(헌장 위반) | Task 3 |
| 부채 | codex 저자 토큰 둘(`codex` 대 `codex-reviewer`) | Task 8 — `codex-reviewer` 로 정한다(R-Z) |

**이 PR 이 지지 않는 것** — 부채 원장(맨 끝)에 이름이 있다: 토픽 스코프 배선 전부(4c) · `declaration-invalid` · `merge-conflict` 발화(4c) · PR1 이월 둘(4c) · 공개 계약 문자열 · 헌장 · 인용 락(PR5) · §13 수동 e2e(PR5).

---

## 전제 — PR4a 가 main 에 남긴 것 (#174, f8ef0555)

Task 1 이 코드로 확증하고, 없으면 **BLOCKED** 로 보고한다.

- `scripts/recritic_bridge.py` — `ADJUDICATOR = "doc-recritic"` · `prepare` CLI · `load_recritic(recritic_path, map_path, diff_path, ledger) -> (doc, dead)` · 보조 입력 사망은 `ledger.source_failed(..., primary=False)`
- `scripts/synthesize_findings.py` — 플래그 `--adversarial` · `--findings` · `--emit-verdict` · `--differential` · `--reason` · `--legacy-verdict` · `--angles` · `--recritic` · `--recritic-map` · `--recritic-diff` · `promote_new_findings(..., author="adversarial")` · `apply_verdicts(..., adjudicator_dead=False)` · `_degrade_block(degraded, degrade_reasons)` · `render(kept, suppressed_count, dropped_malformed, report, held_classes, recritic_zero=False)`
- `scripts/verdict.py` — `REASONS`(11) · `CAUSE_TO_REASON` · `LEGACY_VERDICTS`(`── AC23` 블록) · `decide(*, defect, review_blocked, angle_absent, differential_text, extra_reasons, legacy_verdict)`
- `scripts/angles.py` — `ANGLES` · `ABSENT_REASONS = ("not-installed", "not-derived", "source-failed")` · `parse()` · `render()` · `blocks()`
- `scripts/seal-worktree.sh` — `seal <sid>` → 봉인 커밋 SHA 한 줄 · 인덱스 자리 `.claude/quality-gates/seal-<sid8>.index` · `check-ignore` 이른 가드
- `scripts/qg-worktree.sh` — `create-head <sealed-sha> <sid>` 가 `rt-<sid8>` 샌드박스의 HEAD 와 대조
- `tools/adjudication/check_wiring.py` 의 `synthesize_findings.py` 면제 키 **467**
- 호출자 0 인 PR1 스크립트: `resolve-topic.sh` · `combine-tips.sh` (이 PR 에서도 0 으로 남는다)

---

## 이월 — 앞 PR 에서 넘어온 것 (PR4a 부채 원장 중 PR4b 소유)

| # | 이월 | 이 PR 에서 |
|---|---|---|
| **C1** | 오케스트레이터가 `--emit-verdict` · `--angles` 를 항상 싣기 · 재비판자가 돌면 `adjudication: filled` 로 선언 | **닫는다**(Task 8) |
| **C2** | codex 저자 토큰을 하나로 | **닫는다**(Task 8, R-Z) |
| **C3** | `security-reviewer` 처분 `fail-closed` — `--angles` 상시 배선과 같은 커밋 | **닫는다**(Task 8) |
| **C4** | `trivia` · `kill-switch` · `declaration-invalid` · `merge-conflict` 발화 | **둘을 닫고 둘은 4c 로**(Task 8 · R-U) |
| **C5** | AC23 매핑표 제거 | **닫는다**(Task 2) |
| **C6** | `--adversarial` 제거 · `author` 기본값 · `downgrade` 분기 · 가드의 `_norm_sev` 재구현 · 자기서사 주석 | **닫는다**(Task 2) |
| **C7** | 보조 입력 사망 → not-clean 마커(헌장 위반) | **닫는다**(Task 3) |
| **C8** | verifier 제거 · 게이트 합치기 · 공개 인자 · env 스위치 | **닫는다**(Task 5 · 6 · 7 · 8) |
| **C9** | 스코프 배선 · PR1 이월 둘(`--sort=refname` · base-remote-ref 전용 락) | **4c 로**(R-U) |
| **C10** | `check_wiring.py` 줄번호-키 면제 | 합성기를 고치는 Task 마다 재앵커(Task 2 · 3) |

---

## 계획이 내린 판정 — 설계 문면을 넘어선 자리

사용자가 뒤집을 수 있는 자리다. 각 항목은 **무엇을 정했는가 · 왜 · 틀리면 무엇을 치르는가**를 적는다.

### R-U — §16 재결정(P23): 4b 를 4b · 4c 로 나눈다

**정함.** 이 PR(4b)은 verifier 제거 · 한 파이프라인 · 판정 상시 배선 · 합성기 정리를 진다. 토픽 스코프 배선(`resolve-topic.sh` → 경계 · 끝점, `combine-tips.sh` → 합친 HEAD 트리, AC3–AC7 · AC15 · AC16 의 선언 쪽, `declaration-invalid` · `merge-conflict` 발화, PR1 이월 둘, 순차 합치기 중간 커밋의 GC)은 **PR4c** 다. 설계 §16 에 P23 항목으로 기록한다(Task 9). 사용자가 2026-09-25 에 동의했다.

**왜.** 실측한 4b 의 크기가 §16 이 분할한 이유를 다시 재현했다 — 삭제 에이전트 하나 · 스크립트 하나 · 락 여러 개 · 1017줄 SKILL 재작성 · 1218줄 레퍼런스 재작성 · 판정 배선 · 합성기 정리에 스코프 배선까지 더하면 4a(8 Task · 수정 12 라운드)의 한 배 반이다. 스코프 배선은 선언이 없으면 기존 세 모드로 내려가는 **새 능력**이라(§6.2.5) 떼어 내도 breaking 경계가 깨지지 않는다.

**틀리면.** 선언 조각이 `#pr4c` 하나 더 는다. 4b 와 4c 사이 한 릴리스 동안 `Spec:` 트레일러는 아무 효과가 없다(오늘과 같다).

### R-V — 차등 테스트의 kill switch 는 새 스위치 `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1`

**정함.** 이 스위치가 켜지면 ② 를 통째로 건너뛰고(레퍼런스를 읽지도 않는다) 합성기에 `--reason kill-switch` 를 싣는다. 판정은 `not-certified (kill-switch)` 다(AC9).

**왜.** 설계는 「kill switch 로 차등 테스트가 생략된 실행」(AC9)을 요구하지만 스위치 이름을 정하지 않았다. 오늘 차등 테스트를 끄던 유일한 스위치 `DISABLE_RUNTIME_SANDBOX` 는 §6.5.1 이 「대상 소멸」로 지운다. 전역 `DEVBREW_QUALITY_GATES_DISABLE=1` 은 판정 자체를 내지 않으므로 AC9 의 대상이 아니다. 차등 테스트는 리뷰 대상 저장소의 코드(`setup_cmd` · 테스트)를 호스트 권한으로 돌린다 — 그것을 끌 수단은 보안 컨트롤이다(헌장).

**틀리면.** 공개 표면에 스위치가 하나 는다(README · kill switch 색인).

### R-W — `qg-worktree.sh` 의 `create-sandbox` · `mutation-guard` 는 **남긴다** — 소비자가 plugin-audit 로 옮겨 갔다

**정함.** qg 파이프라인은 두 서브커맨드를 더 부르지 않는다. 그러나 코드와 그 락(`test_qg_runtime_sandbox.sh` · `test_qg_mutation_guard.sh`)은 남긴다. `plugins/plugin-audit/scripts/run-own-tests.sh` 가 자체 테스트 격리에 둘을 쓰기 때문이다. `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX` 도 그 소비자에게만 효력이 남는다 — qg 의 파이프라인 문서(SKILL · qg.md · kill switch 색인)에서는 빠지고, README 의 환경 표에는 「plugin-audit 자체 테스트 격리에만 영향」으로 남는다. `qg-worktree.sh` 헤더에 소비자를 적는다.

**왜.** 설계 §12 는 두 분기를 지우라고 적었지만, 그때 설계는 qg 밖 소비자를 몰랐다. 지우면 plugin-audit 의 축 ③(자체 테스트 실행)이 「sandbox 생성 실패 → skip」으로 조용히 꺼진다 — 그 플러그인의 README 는 qg 를 optional 로 선언했으므로 오류도 안 난다. 제거는 소비자 없는 코드에 대해서만 이득이다.

**틀리면.** qg 가 자기가 안 쓰는 코드 약 400줄과 락 둘을 계속 진다. 소유를 plugin-audit 로 옮기는 것은 부채 원장의 후속 항목이다.

### R-X — 봉인 인덱스는 `.git` 안에 둔다 · `create-head` 는 봉인을 **다시 떠서** 트리를 대조한다

**정함.**
1. `seal-worktree.sh` 의 임시 인덱스 자리를 `git rev-parse --git-path qg-seal-<sid8>.index` 로 옮긴다. 이른 `check-ignore` 가드는 지운다. 봉인 «후» 트리 검사(권위 가드)는 남긴다.
2. `create-head <sealed-sha> <sid>` 의 assert 를 「`rt-<sid8>` 샌드박스의 HEAD 와 같다」에서 「`<sealed-sha>` 의 트리가 **지금 다시 뜬 봉인**의 트리와 같다」로 바꾼다. `create-head` 가 `seal-worktree.sh seal <sid>` 를 스스로 한 번 더 부른다.

**왜.** (1) 오늘의 가드는 사용자 리포가 `.claude/` 를 무시하지 않으면 봉인을 거부한다(Review Focus 1). `.git` 안은 `git add -A` 가 원리적으로 집지 않는 자리다 — 설계 §6.4.1 이 못 박은 요건(「git 이 무시하는 자리」)을 리포 설정과 무관하게 만족한다. (2) 샌드박스가 사라지므로 대조 대상이 없다. 설계 §6.4.1 은 「봉인 커밋의 트리가 기대 OID 와 일치」를 요구한다 — 기대 OID 를 오케스트레이터가 따로 옮겨 적게 하면 대조 양쪽이 같은 전사에서 나온다. 다시 뜬 봉인은 워킹트리에서 도출되므로 전사가 없다. `$merge_base` 를 잘못 넘기면(형제 `create-baseline` 과 인자 모양이 같다) 트리가 달라 죽는다. 봉인 뒤 워킹트리가 바뀐 stale 값도 죽는다.

**틀리면.** `create-head` 가 봉인을 두 번 뜬다(수 ms). 다시 뜬 봉인 커밋은 unreachable 로 남는다 — 순차 합치기 중간 커밋과 같은 처지이고, 그 GC 는 4c 의 빚이다.

### R-Y — 차등 테스트 결과가 판정에 들어가는 길

**정함.** 오케스트레이터는 차등 테스트의 결과를 **판정하지 않고** 합성기에 싣는다:

| 조건 | 합성기에 싣는 것 |
|---|---|
| R6 집계가 exit 0 이고 `verdict_input` 3키 · `attribution_status` 를 다 읽었다 | `--differential "<aggregate.yaml 절대 경로>"` |
| R6 어댑터별 호출 또는 집계 호출이 non-zero, 또는 키를 못 읽었다 | `--differential` 을 **싣지 않고** `--reason error-axis` |
| `check_qa_ledger.py` 가 non-zero(원장 구조 · 전사 대조 · `unclaimed` 집행) | `--reason silent-drop` |
| `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` | `--reason kill-switch` (② 전체 생략) |
| 해소한 스코프 0 인데 `check-review-scope.sh` 가 `changes_exist: yes` (옛 「정직-verdict floor」) | `--reason scope-empty` |
| trivia escape | 합성기를 부르지 않고 `verdict.py --reason trivia` 로 판정을 낸다 |

**왜.** `diff-test-results.py` 의 `degrade_causes` 는 `verdict.py` 가 이미 사유로 옮긴다(`CAUSE_TO_REASON`). 남는 셋은 설계 §6.4.3 표가 이름을 주지 않은 자리다. R6 실패는 「어느 축이든 관측이 오류로 끝났다」라 `error-axis` 에 가장 가깝다. `check_qa_ledger.py` 의 non-zero 셋(구조 · 전사 · `unclaimed`)은 전부 「영향분으로 고른 것이 확인되지 않았다」라 `silent-drop` 에 가장 가깝다. 두 경우 모두 사유 열거를 늘리지 않는다(AC8 의 닫힌 열거 · `N:11` 락).

**틀리면.** 사유 라벨이 정확한 원인보다 넓다. 방향(clean 아님)은 맞다.

### R-Z — codex 저자 토큰은 `codex-reviewer`

**정함.** SKILL 의 저자 스탬프 문장을 `codex` 에서 `codex-reviewer` 로 바꾼다. `codex_findings_to_yaml.py` 는 이미 그 값을 찍는다.

**왜.** 변환기는 `shared/codex/` 와 qg 에 바이트 사본으로 산다(`test_copy_of_contract.sh`). 그 값을 바꾸면 `shared/` 가 움직이고 spec-distill 의 사본까지 따라 움직인다. SKILL 한 줄을 고치는 쪽이 경계를 안 넘는다. 두 값 모두 수행자 문법(`^[a-z0-9-]+$`) 안이라 AC10a 는 어느 쪽이든 선다.

**틀리면.** Source 칸에 `codex-reviewer` 가 찍힌다(오늘과 같다).

### R-AA — not-clean 마커는 **차단**에만 선다. SKILL 은 `verdict:` 줄을 판정으로 읽는다

**정함.** 합성기 본 보고서의 `**이 실행은 clean이 아니다**` 마커는 `Ledger.blocks()`(항목 소실 · 셀 수 없음 · 주 입력 사망) 또는 버려진 finding(`dropped_malformed > 0`)일 때만 선다. 그 밖의 degrade(보조 입력 사망 · 판정을 바꾼 강제)는 `판정 degrade — 공시(판정을 막지 않음)` 머리줄로 드러난다. SKILL 의 판정은 합성기 꼬리의 `verdict:` 줄 **하나**가 정한다 — 마커를 판정 키로 쓰던 「Not-clean notice override」 절은 마커를 **그대로 보이는** 규칙으로 줄어든다.

**왜.** 헌장 — 「공시와 차단은 다른 술어다」. `verdict.decide()` 는 이미 차단 술어만 받는다(`review_blocked` · `angle_absent`). 마커가 공시 술어(`report["degraded"]`)에 묶여 있으면 같은 실행에서 본 보고서는 「clean 이 아니다」, 꼬리는 `verdict: clean` 이 되는 자기모순이 난다.

**틀리면.** 판정을 바꾼 강제가 더는 SKILL 을 멈추지 않는다. 오늘 경로에서 그런 강제(근거 없는 기각 → confirm · 매핑 못 하는 `to` → confirm)는 전부 finding 을 **남기는** 방향이라 `defect` 가 그대로 선다.

### R-AB — 각도 파일은 오케스트레이터가 매 iteration 쓴다. 이 PR 은 `folded_into` 를 쓰지 않는다

**정함.** `$RV/angles.txt` 에 세 줄을 쓴다:

| 각도 | 값 | 조건 |
|---|---|---|
| `security` | `filled` | `security-reviewer` 를 디스패치했고 그 출력을 `findings.yaml` 에 넣었다(0건 포함) |
| | `absent` | `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1` |
| | `absent(source-failed)` | 디스패치가 실패했거나 출력을 읽을 수 없었다 |
| `adjudication` | `filled` | **항상**(AC17 — 재비판은 매 iteration 디스패치된다). 재비판자가 죽으면 합성기가 관측으로 `absent(source-failed)` 를 얹는다 |
| `different-premise` | `filled` | codex 러너가 돌았고 `meta.codex_failed: false` 를 읽었다 |
| | `absent(not-installed)` | `detect_codex.sh` 가 visible 표의 사유를 냈다 |
| | `absent` | `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1` · `inside_codex_sandbox` |
| | `absent(not-derived)` | 사용 가능한데 부르지 않았다 |
| | `absent(source-failed)` | 러너가 돌았으나 결과를 쓸 수 없다(산출물 부재 · 0바이트 · `codex_failed: true` · 키 부재) · 감지기 실행 실패 |

**왜.** 이 PR 은 수행자를 바꾸지 않는다 — 보안 각도는 `security-reviewer`, 판정 각도는 재비판자, 다른 전제는 codex 다. `folded_into` 는 수행자를 스코프로 도출할 때 쓰는 값이고, `adjudication: folded_into:doc-recritic` 은 승격 finding(`agent: doc-recritic`) 하나로 AC10a exit 4 를 낸다(PR4a 최종 리뷰 probe n).

**틀리면.** 각도 파일이 모델이 쓰는 산출물이라 모델이 틀리게 쓸 수 있다 — 설계 §15-4 가 이미 공시한 한계와 같다(락은 형식적 완전성만 잰다).

### R-AC — 차등 테스트는 **매 iteration** 돈다

**정함.** iteration 하나 = ① → ② → ③ → ④ → ⑤. iteration 2 이상은 Retry 가 코드를 고친 뒤에만 오므로 ② 를 다시 돈다. 기준선 축은 캐시가 상각한다.

**왜.** 한 번만 돌리면 고친 뒤의 판정이 고치기 전 트리의 차등 결과를 싣는다(Review Focus 3). 설계 §6.1 은 ② 가 ③ 앞이어야 하는 것을 load-bearing 으로 적었다 — 테스트 결과가 그 iteration 의 도출 입력이다.

**틀리면.** Retry 마다 HEAD 축 스위트가 다시 돈다.

### R-AD — `--adversarial` 을 쓰던 락은 재비판 경로로 옮긴다. `downgrade` 를 재던 케이스는 지운다

**정함.** `tests/lib/recritic_fixture.sh`(신설)의 세 함수(`rf_prep` · `rf_reply` · `rf_synth`)로 옮긴다. 옮기는 규칙은 Task 2 의 변환 표다. 케이스의 **의도**가 `--adversarial` 경로 자체이거나 `downgrade` 이면 지운다 — 대응물이 없다. `adjusted_confidence` 적용 분기도 지운다(재비판 경로는 그 칸을 내지 않는다).

**왜.** 판정자 문서의 옛 모양을 테스트에서만 살려 두면 제거한 표면이 테스트 입력으로 남는다. 재비판 경로는 합성기와 같은 원장 · 같은 프로세스라 합성기 의미론을 그대로 잰다.

**틀리면.** 몇 케이스의 기대값이 경로 차이 때문에 바뀐다(예: `RECRITIC_ZERO_LINE`). 그 차이는 구현 보고서에 케이스별로 적는다.

### R-AE — `setup-qg.sh` 의 `--paths` · `--gc` 를 받는다 (선재 결함)

**정함.** `--paths <glob>...`(다음 `--` 토큰 전까지 소비)과 `--gc`(무시 — `qg.md` 가 이미 처리했다)를 인자 루프에 더한다.

**왜.** 오늘 `/qg --paths 'src/*'` 은 SKILL Preflight P2 의 `setup-qg.sh --ensure $ARGUMENTS` 에서 `Unknown argument` → exit 1 → 파이프라인 중단이다. 설계 §6.5.1 은 `--paths` 를 존치로 선언했다 — 존치를 선언한 인자가 이미 죽어 있으면 그 선언이 거짓이다. 이 Task 가 같은 루프를 고치므로 같이 닫는다.

**틀리면.** 없다. `--show-low-confidence`(합성기 안내 문구가 가리키는 플래그)는 같은 부류지만 이 PR 밖이다(부채 원장).

### R-AF — Tier 어휘는 각도 어휘로 바꾼다

**정함.** SKILL 의 「Tier A · B · C」를 「보안 각도 · 판정 각도 · 다른 전제 각도 · 추가 리뷰어」로 바꾼다. 선택 규칙(보안 리뷰어는 매 iteration · codex 는 가능하면 · 추가 리뷰어는 스코프로)은 그대로다.

**왜.** 설계 D5 — 3단계 Tier 개념이 통째로 사라진다. 각도 파일을 쓰는 규칙(R-AB)이 Tier 이름으로 적혀 있으면 두 어휘가 한 절에 공존한다.

**틀리면.** 락 앵커 몇 개가 움직인다(인벤토리가 잡는다).

### R-AG — R8 원장 · `check_qa_ledger.py` · 파일 이름 `runtime-evidence.md` 는 남긴다

**정함.** 차등 테스트의 floor 5차원 원장과 그 구조 게이트는 verifier 가 아니라 오케스트레이터의 것이다 — 남긴다. 원장 파일 이름은 `qg-gc.py` 의 세션 표식이라 바꾸지 않는다. `evidence_dir` 정의는 지워지는 R5a² 에서 R8 로 옮긴다.

**왜.** `unclaimed` 집행(§11 ㉓)과 전사 대조(§11 ⑱)의 유일한 기계가 그 게이트다. 지우면 「테스트가 한 개도 안 돈 채 clean」이 되돌아온다.

**틀리면.** 파일 이름에 옛 게이트 이름이 남는다.

### R-AH — 버전은 **major**, qg 만

**정함.** qg 만 bump 한다. 번호는 머지 직전 `origin/main` 의 qg 버전에서 major 를 올린 값이다(오늘 관측값 8.5.0 → 9.0.0). spec-distill · plugin-audit 는 한 바이트도 안 바뀌므로 올리지 않는다.

---

## 파일 구조

**신설**

| 경로 | 책임 |
|---|---|
| `plugins/quality-gates/skills/quality-pipeline/references/differential-test.md` | 차등 테스트 절차 전문 — 옛 `runtime-gate.md` 의 R-init · R1a · R1b · R2 · R3 · R4 · R5b · R6 · R8. `git mv` 로 옮긴 뒤 고친다(이력 보존) |
| `plugins/quality-gates/tests/lib/recritic_fixture.sh` | 합성기를 재비판 경로로 부르는 테스트 헬퍼(R-AD) |
| `plugins/quality-gates/tests/test_one_pipeline_surface.sh` | 한 파이프라인의 표면 락 — 옛 게이트 토큰 부재 ∀ + 새 골격 존재(양의 짝) |
| `plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh` | 판정 상시 배선 락 — 합성기 호출 ∀ 에 `--emit-verdict` · `--angles` · 처분 · 사유 리터럴 ⊆ 열거 · 각도 파일 견본이 총 함수 · 행동 케이스 |

**수정**

| 경로 | 무엇이 |
|---|---|
| `scripts/synthesize_findings.py` | `--adversarial` · `--legacy-verdict` 제거 · `load_yaml_doc` 제거 · `_fold_sev` · `apply_verdicts` raise 전용 · `promote_new_findings(*, author)` · 마커 분리(R-AA) · 자기서사 주석 정리 |
| `scripts/verdict.py` | `LEGACY_VERDICTS` 블록 · `legacy_verdict` 인자 · `--legacy-verdict` 제거 |
| `scripts/recritic_bridge.py` | docstring 의 `load_yaml_doc` 인용 두 곳 |
| `scripts/seal-worktree.sh` | 인덱스 자리 → `git rev-parse --git-path`(R-X) |
| `scripts/qg-worktree.sh` | `create-head` assert(R-X) · 헤더에 `create-sandbox`/`mutation-guard` 소비자(R-W) |
| `scripts/setup-qg.sh` | 제거 인자 공지 · `--paths` · `--gc` · `RUNTIME_MAX_RESOLUTIONS` 제거 · help · 출력 |
| `scripts/check-allowed-tools-order.sh` | `EXPECTED_ORDER` 재편 |
| `skills/quality-pipeline/SKILL.md` | 한 파이프라인 재작성 · 판정 배선 |
| `skills/quality-pipeline/references/state-file-format.md` | `runtime_max_resolutions` 제거 |
| `agents/test-scope-validator.md` | `ac_coverage`(Step 3.5) 제거 · verifier · 게이트 언급 이주 |
| `commands/qg.md` | 인자 표 · Quick Reference · Gates 절 · argument-hint |
| `tests/lib/reconstruct-skill.sh` | 스플라이스 헤딩 · 참조 파일 이름 |
| `tests/…` (Task 1 인벤토리가 도출) | 락 이주 |
| `tools/adjudication/check_wiring.py` | 면제 키 재앵커 |
| `tools/adjudication/check_slots.py` | 주석의 `runtime-verifier.spec_acceptance_criteria` bullet 제거 |
| `plugins/quality-gates/README.md` · `docs/philosophy/devbrew-harness-philosophy.md`(코드 지도의 죽은 포인터만) · `docs/plugin-authoring.md`(죽은 인용만) · `tests/e2e-scenarios.md` | 문서 이주 |
| `docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md` | §16 P23 재결정(4b · 4c) |
| `plugins/quality-gates/CHANGELOG.md` · `.claude-plugin/plugin.json`(`version` 만) | bump |

**제거**

| 경로 | 왜 · 무엇이 규칙을 잇는가 |
|---|---|
| `agents/runtime-verifier.md` | §12 · C2. 대상 소멸 — 부팅 표면 검증의 **주장을 거둔다**(§6.5.3). SKILL/레퍼런스 dispatch 블록과 **같은 커밋** |
| `scripts/detect-runtime.sh` | 런타임 스코프 결정 제거(§6.4.4). 대상 소멸 |
| `skills/quality-pipeline/references/runtime-gate.md` | `differential-test.md` 로 `git mv` |
| `tests/test_runtime_verifier_frontmatter.sh` · `tests/test_runtime_verifier_behavior.py` · `tests/test_detect_runtime.sh` · `tests/test_runtime_verdict_precedence.sh` | 대상 소멸. **최종 목록은 Task 1 인벤토리가 도출한다** — 여기 적은 것은 시작점이다 |

**이 PR 밖(범위 불변식 — Task 11 이 대조한다):** `shared/**` · `plugins/spec-distill/**` · `plugins/plugin-audit/**` · `.claude-plugin/marketplace.json` · 루트 `CLAUDE.md` · `plugins/quality-gates/scripts/resolve-topic.sh` · `plugins/quality-gates/scripts/combine-tips.sh` · `plugins/quality-gates/scripts/diff-test-results.py` · `plugins/quality-gates/scripts/run-test-selection.sh` · `plugins/quality-gates/scripts/check_qa_ledger.py` · `plugins/quality-gates/agents/security-reviewer.md` · `plugins/quality-gates/agents/doc-recritic.md` · `plugins/quality-gates/references/recritic-code-profile.md` · `plugins/quality-gates/.claude-plugin/plugin.json` 의 `version` 밖 바이트.

---
### Task 1: 착수 — 전제 확증 · 선재 RED 기준선 · 인벤토리 두 장

**Files:**
- Create (추적 안 함): `$CLAUDE_JOB_DIR/tmp/run-suite.sh` · `$CLAUDE_JOB_DIR/tmp/pr4b-baseline.tsv` · `$CLAUDE_JOB_DIR/tmp/pr4b-baseline-harness-fails.txt` · `$CLAUDE_JOB_DIR/tmp/pr4b-sweep-inventory.tsv` · `$CLAUDE_JOB_DIR/tmp/pr4b-lock-inventory.tsv`
- Mirror: `~/.claude/sdd-mirror/qg-gate-merge-pr4b/` 에 위 다섯을 복사
- Modify: 없음

**Interfaces:**
- Consumes: 없음
- Produces:
  - `pr4b-baseline.tsv` — `<경로>\t<rc>\t<실패줄수>`. Task 11 이 같은 형식으로 다시 찍어 **행 단위로** 대조한다.
  - `pr4b-sweep-inventory.tsv` — `<경로:줄>\t<처분>\t<Task>\t<근거>`. 제거 · 이주 대상 **문면**의 전수.
  - `pr4b-lock-inventory.tsv` — `<경로:줄>\t<처분>\t<Task>\t<규칙을 잇는 자리>\t<근거>`. 제거 · 이주 대상을 **재는 단언**의 전수. Task 2–9 가 자기 Task 번호의 행을 한 줄도 빠짐없이 처리한다.

- [ ] **Step 1: PR4a 전제를 확증한다 — 이름만이 아니라 호출 가능성**

```bash
cd "$(git rev-parse --show-toplevel)"
git fetch origin --quiet
git merge-base --is-ancestor f8ef0555 HEAD && echo "OK PR4a in HEAD" || echo "MISSING PR4a"
PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import inspect, sys
sys.path.insert(0, "plugins/quality-gates/scripts")
sys.path.insert(0, "shared/adjudication")
import angles, verdict, recritic_bridge, synthesize_findings as s
print("ABSENT_REASONS:", angles.ABSENT_REASONS)
print("decide params:", sorted(inspect.signature(verdict.decide).parameters))
print("LEGACY:", sorted(verdict.LEGACY_VERDICTS))
print("ADJUDICATOR:", recritic_bridge.ADJUDICATOR)
print("promote author default:", inspect.signature(s.promote_new_findings).parameters["author"].default)
print("render params:", list(inspect.signature(s.render).parameters))
PY
grep -n '"plugins/quality-gates/scripts/synthesize_findings.py", [0-9]*' tools/adjudication/check_wiring.py
grep -n 'check-ignore\|seal-\${sid_short}.index' plugins/quality-gates/scripts/seal-worktree.sh
grep -n 'rt-\${ch_sid_short}' plugins/quality-gates/scripts/qg-worktree.sh
git grep -n -P 'resolve-topic\.sh|combine-tips\.sh' -- plugins/quality-gates/skills plugins/quality-gates/commands || echo "OK PR1 스크립트 호출자 0"
```

**기대** — `OK PR4a in HEAD` · `ABSENT_REASONS: ('not-installed', 'not-derived', 'source-failed')` · `decide params` 에 `legacy_verdict` 포함 · `LEGACY: ['FAIL', 'NEEDS_RESOLUTION', 'PASS', 'SKIP_WITH_EVIDENCE']` · `ADJUDICATOR: doc-recritic` · `promote author default: adversarial` · `render params` 끝이 `recritic_zero` · 면제 키 `467` · `check-ignore` 줄과 `seal-${sid_short}.index` 줄이 보인다 · `rt-${ch_sid_short}` 줄이 보인다 · `OK PR1 스크립트 호출자 0`. 하나라도 다르면 **BLOCKED**.

- [ ] **Step 2: base 이동량을 잰다**

```bash
cd "$(git rev-parse --show-toplevel)"
git rev-list --count HEAD..origin/main
git log --oneline HEAD..origin/main | head -20
git merge-tree --write-tree --name-only HEAD origin/main | tail -n +2 | head -40
```

**기대** — 0 이면 그대로 진행. 0 이 아니면 겹치는 파일 목록을 보고서에 적고 **지금 merge 하지 않는다**(리포 규약: 머지 직전 한 번만 동기화 — Task 11). **충돌이 «안» 나는 version 파일(`plugin.json` · `CHANGELOG.md`)이 목록에 있으면 그것을 따로 적는다** — 같은 버전 문자열은 충돌 없이 병합된다.

- [ ] **Step 3: 스위트 스크립트를 쓰고 선재 RED 기준선을 찍는다 — rc 와 «실패 줄 수» 둘 다**

`$CLAUDE_JOB_DIR/tmp/run-suite.sh` 를 **파일로** 쓴다(Bash 도구는 호출마다 새 셸이라 루프 누산기를 한 호출에 담아야 한다):

```bash
#!/usr/bin/env bash
# run-suite.sh <출력 TSV> — 리포 루트에서 네 디렉토리의 셸 락 전부를 돌린다.
set -u
OUT="$1"; : > "$OUT"
cd "$(git rev-parse --show-toplevel)" || exit 1
for f in plugins/quality-gates/tests/*.sh plugins/quality-gates/tests/harness/*.sh \
         shared/tests/*.sh plugins/spec-distill/tests/*.sh; do
  [ -f "$f" ] || continue
  o="$(PYTHONDONTWRITEBYTECODE=1 bash "$f" 2>&1)"; rc=$?
  # 실패 줄 앵커는 둘이다 — assert.sh 계열의 `✗` 와 하네스의 `FAIL:`.
  n="$(printf '%s\n' "$o" | grep -cE '^[[:space:]]*✗|^FAIL:' || true)"
  printf '%s\t%s\t%s\n' "$f" "$rc" "$n" >> "$OUT"
done
wc -l < "$OUT"
awk -F'\t' '$2 != 0 || $3 != 0 {print}' "$OUT"
```

```bash
chmod +x "$CLAUDE_JOB_DIR/tmp/run-suite.sh"
bash "$CLAUDE_JOB_DIR/tmp/run-suite.sh" "$CLAUDE_JOB_DIR/tmp/pr4b-baseline.tsv"
cd "$(git rev-parse --show-toplevel)"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p "test_*.py" 2>&1 | tail -3
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 \
  | grep '^FAIL:' > "$CLAUDE_JOB_DIR/tmp/pr4b-baseline-harness-fails.txt"
cat "$CLAUDE_JOB_DIR/tmp/pr4b-baseline-harness-fails.txt"
```

**보고서에 적는 것** — 총 행 수, rc≠0 또는 실패≠0 인 행 전부(경로 · rc · 줄 수), unittest 총수, 하네스 `FAIL:` 줄 **이름** 전부. 앞 PR 의 숫자를 베끼지 않는다 — 측정이다. (참고: PR4a 종료 시점은 210 파일 · 선재 RED 넷 — qg `test_codex_backward_compat.sh` 1/0 · qg `test_runner_adapters.sh` 1/1 · qg `harness/test_skill_orchestration_behavior.sh` 1/2 · spec-distill `test_no_write_matcher_hooks_repo.sh` 1/1 · unittest 193. 다르면 다르다고 적는다.)

- [ ] **Step 4: 제거 스윕 인벤토리 — 문면의 전수, 매치 단위 처분**

네 스윕을 **`git grep -n -P -i`** 로 돌린다(`-E` 금지 · 단어 경계 금지). 스윕 대상은 리포 전체의 추적 파일이고, 아래 경로는 **줄을 세기만** 하고 인벤토리에 적지 않는다: `docs/superpowers/**` · `docs/archive/**` · `*/CHANGELOG.md`.

```bash
cd "$(git rev-parse --show-toplevel)"
X=(':!docs/superpowers/**' ':!docs/archive/**' ':!**/CHANGELOG.md')
git grep -n -P -i 'SKIP_WITH_EVIDENCE|NEEDS_RESOLUTION|forced_downgrade|block_policy|approved_surfaces|effective_skip_runtime|LEGACY_VERDICTS|legacy.verdict|AC23' -- . "${X[@]}" > "$CLAUDE_JOB_DIR/tmp/sw1.txt"
git grep -n -P -i 'sandbox|mutation.guard|create-sandbox|runtime-verifier|runtime_verifier|detect-runtime|detect_runtime|RUNTIME_MAX_RESOLUTIONS|DISABLE_RUNTIME_SANDBOX|resolution_iter|evidence_dir' -- . "${X[@]}" > "$CLAUDE_JOB_DIR/tmp/sw2.txt"
git grep -n -P -i 'Runtime gate|Review gate|runtime-gate|skip-runtime|/qg both|/qg review|/qg runtime|2-gate|two gates|두 게이트|Decision [12]|Tier [ABC]|single-gate|gate scope|gate=' -- . "${X[@]}" > "$CLAUDE_JOB_DIR/tmp/sw3.txt"
git grep -n -P -i -- '--adversarial|adjudicator = "adversarial"|author="adversarial"|downgrade|ac_coverage|agent: codex\b|codex 는 `codex`|이 실행은 clean이 아니다' -- . "${X[@]}" > "$CLAUDE_JOB_DIR/tmp/sw4.txt"
wc -l "$CLAUDE_JOB_DIR"/tmp/sw[1-4].txt
for p in 'docs/superpowers/**' 'docs/archive/**' '**/CHANGELOG.md'; do
  printf '%s\t' "$p"; git grep -c -P -i 'SKIP_WITH_EVIDENCE|NEEDS_RESOLUTION|sandbox|runtime-verifier|Runtime gate|--adversarial' -- "$p" | awk -F: '{s+=$2} END {print s+0}'
done
```

`sw4.txt` 의 `agent: codex\b` 는 `-P` 라 `\b` 가 정상 동작한다(문제는 `-E` 의 `\b` 다).

각 **매치**를 아래 처분 중 하나로 분류해 `pr4b-sweep-inventory.tsv` 에 쓴다. 한 파일 안에서 매치마다 처분이 다를 수 있다.

| 처분 | 뜻 | 예 |
|---|---|---|
| `delete-file` | 파일이 통째로 사라진다 | `agents/runtime-verifier.md` · `scripts/detect-runtime.sh` · 그 대상만 재는 테스트 |
| `move` | `git mv` 대상 | `references/runtime-gate.md` → `references/differential-test.md` |
| `edit` | 파일은 남고 그 매치가 바뀐다 | SKILL · qg.md · README · 락의 앵커 |
| `keep-critique` | `/qg critique` 표면 — 존치(§6.4.3 의 도출 규칙 ②) | `skills/critiquing-artifacts/**` · `scripts/artifact_*` · `synthesize_artifact_findings.py` · `agents/artifact-*` · 그것을 재는 락 |
| `keep-differential` | 차등 기계 — 존치(설계 C4 · Non-goal) | `run-test-selection.sh` · `diff-test-results.py` · `baseline-cache.sh` · `check_qa_ledger.py` · `compute-test-scope-candidates.sh` 와 그 락(`test_runner_adapters.sh` · `test_run_test_selection.sh` · `test_diff_test_results.py` · `test_baseline_cache.sh` · `test_qa_ledger.sh` …) |
| `keep-plugin-audit` | R-W — `create-sandbox` · `mutation-guard` 와 그 락 · `DISABLE_RUNTIME_SANDBOX` 의 스크립트 독자 | `qg-worktree.sh` 의 두 분기 · `test_qg_runtime_sandbox.sh` · `test_qg_mutation_guard.sh` · `plugins/plugin-audit/**` |
| `keep-codex-sandbox` | codex CLI 의 `-s`/`--sandbox` 격리 — 다른 기능 | `run_codex_reviewer.sh` · `test_sandbox_enforced.sh` · `detect_codex.sh` · `inside_codex_sandbox` |
| `keep-other` | 무관한 동음어 · 역사 기록(근거 필수) | spec-distill 의 proceed-gate 「두 게이트」 · `docs/audits/**` · `tests/e2e-scenarios.md` 의 Historical 표기 · 픽스처 |

**`Task` 칸**은 그 매치를 처리할 Task 번호다: 합성기 · 판정 어휘(`--adversarial` · legacy · `downgrade`) → 2, not-clean 마커 → 3, 봉인 · `create-head` → 4, `setup-qg.sh` · `state-file-format.md` → 5, `test-scope-validator.md` · `ac_coverage` → 6, SKILL · 레퍼런스 · qg.md · verifier · detect-runtime · Decision · Tier → 7, 판정 배선 · codex 토큰 · 보안 kill switch 의미 → 8, README · docs → 9.

**반드시 확인하는 것** — `tests/e2e-scenarios.md` 가 「Historical」 절을 가지면 그 절의 매치는 `keep-other`, 나머지는 `edit`. `tools/adjudication/check_slots.py` 의 `runtime-verifier.spec_acceptance_criteria` 주석 bullet 은 `edit`(Task 7). `docs/philosophy/devbrew-harness-philosophy.md` 는 **코드 지도의 파일 포인터**만 `edit`(Task 9)이고, Law 2 scoped exception **산문**은 `keep-other`(근거: PR5 가 `CLAUDE.md` 와 함께 옮긴다).

- [ ] **Step 5: 락 인벤토리 — 제거 · 이주 대상을 «재는» 단언의 전수**

락 집합 `L` 은 **도출한다**:

```bash
cd "$(git rev-parse --show-toplevel)"
git grep -l -P -i 'runtime-gate|reconstruct-skill|quality-pipeline/SKILL|quality-pipeline/references|setup-qg|commands/qg\.md|runtime-verifier|detect-runtime|create-sandbox|mutation.guard|Decision [12]|block_policy|approved_surfaces|effective_skip_runtime|skip-runtime|NEEDS_RESOLUTION|SKIP_WITH_EVIDENCE|Runtime gate|Review gate|Tier [ABC]|--adversarial|legacy.verdict|LEGACY_VERDICTS|ac_coverage|test-scope-validator|codex-reviewer|RUNTIME_MAX_RESOLUTIONS|DISABLE_RUNTIME_SANDBOX|이 실행은 clean이 아니다|seal-worktree|create-head' \
  -- 'plugins/*/tests/**' 'shared/tests/**' 'tools/**' > "$CLAUDE_JOB_DIR/tmp/pr4b-lockset.txt"
wc -l < "$CLAUDE_JOB_DIR/tmp/pr4b-lockset.txt"
cat "$CLAUDE_JOB_DIR/tmp/pr4b-lockset.txt"
```

`L` 의 파일마다 **단언 하나 = 한 행**으로 `pr4b-lock-inventory.tsv` 에 쓴다. 단언은 `assert_*` 호출 · `ok`/`no` 쌍 · `PASS:`/`FAIL:` echo 쌍 · `assert_call_in_window` 류 · unittest `assert*` 다. 그 파일의 단언 중 위 토큰 · 헤딩 · 파일 이름 · 스텝 이름(`Step R5a` · `R7` · `R9` · `Step 4.5` · `## Review gate` · `## Runtime gate`)에 **닿지 않는** 것은 행을 만들지 않는다.

| 처분 | 뜻 | 「규칙을 잇는 자리」 칸 |
|---|---|---|
| `delete` | 재는 대상이 사라진다(verifier · Decision 1·2 · `block_policy` · 해소 루프 · R5a · R7 · R9 · 게이트 인자 · 옛 어휘 매핑 · `--adversarial` 경로 자체 · `downgrade`) | **필수.** 그 규칙이 남아 있으면 그것을 이제 재는 락의 파일:케이스. 규칙도 사라지면 `대상 소멸: <무엇>` |
| `retarget` | 대상은 남고 앵커가 움직인다(헤딩 · 파일 이름 · 스텝 이름 · 변수 이름 · `$baseline_sha` → `$sealed`) | 새 앵커 문자열 |
| `invert` | 이 PR 이 **뒤집는** 동작을 재고 있었다(보조 입력 사망 → 마커 · `review` 인자 → 단일 게이트 · 보안 kill switch → 배너만 · codex 저자 `codex`) | 새 기대값 |
| `convert` | `--adversarial` 로 합성기를 부르되 의도는 판정자와 무관한 합성기 의미론이다 | `recritic_fixture.sh` 로 옮긴 모양(Task 2 의 변환 표) |
| `keep` | 토큰에 닿지만 이 PR 이 바꾸지 않는다(`keep-*` 스윕 처분과 짝) | `-` |

**이빨 보존 규칙** — `retarget` · `convert` 행은 옮긴 뒤에도 **같은 변이에 RED** 여야 한다. 행의 근거 칸에 「이 단언을 RED 로 만드는 변이」를 한 줄 적는다(Task 10 이 그 변이를 다시 태운다).

**특히 확인하는 자리**(모의 실행과 PR4a 가 밟은 곳):
- `tests/test_runtime_contract_invariance.sh` — **파일은 남는다**(`create-baseline` · `remove` · `create-head` 계약). `case_detect_runtime_frozen` · `case_sandbox_guard_frozen` · `case_no_new_surfaces` 의 verdict 토큰 부분은 `delete`/`retarget`, `case_create_head_asserts_sealed_commit` 은 Task 4 가 다시 쓴다.
- `tests/lib/reconstruct-skill.sh` 를 `source` 하는 락 전부(`git grep -l reconstruct_skill_md -- plugins`) — 스플라이스가 `## Differential test` 로 옮겨도 선다.
- `tests/harness/test_skill_orchestration_behavior.sh` — 가장 크다. 절 이름(`== 락 이전 검사` · `== 신규 스크립트 배선` · `== R5b·R6 의 HEAD 축 트리 인자` · `== R6→R8 집계 전달 사슬` · `== R1b→R8 unclaimed 집행 사슬` · `== R-init 중간 파일 custody` · `== 호출 주체 불변식` · `== 폴백 R5b 미실행` …)마다 적는다. 선재 `FAIL:` 둘(Step 3)이 어느 행인지 표시한다.
- `shared/tests/test_agent_input_slots.sh` · `shared/tests/test_dispatch_disposition.sh` · `shared/tests/test_skill_reference_pointers.sh` · `shared/tests/test_plugin_root_no_cwd_fallback.sh` — **파일은 한 바이트도 안 바뀐다**(Global Constraints). 이 넷은 `keep` 이어야 하고, 그러려면 Task 7 의 새 문면이 그 락의 코퍼스 규칙을 만족해야 한다 — 각 락이 SKILL/레퍼런스에서 **무엇을 어떻게 도출하는지**를 근거 칸에 적는다(Task 7 의 입력).
- `--adversarial` 호출 자리(Step 4 의 `sw4.txt`) 전부 — `convert` 또는 `delete`. `test_synthesize_artifact_findings.sh` · `synthesize_artifact_findings.py` 의 `--adversarial` 은 **다른 스크립트**(`/qg critique`)라 `keep`.

- [ ] **Step 6: 미러 · 커밋하지 않는다**

```bash
mkdir -p ~/.claude/sdd-mirror/qg-gate-merge-pr4b
cp "$CLAUDE_JOB_DIR"/tmp/run-suite.sh "$CLAUDE_JOB_DIR"/tmp/pr4b-*.t* ~/.claude/sdd-mirror/qg-gate-merge-pr4b/
ls ~/.claude/sdd-mirror/qg-gate-merge-pr4b/
```

이 Task 는 측정만 한다. 보고서에 다섯 파일의 **절대 경로**(job tmp 와 미러 둘 다)와 인벤토리 행 수를 Task 별로 적는다.

---

### Task 2: 합성기 · 판정 어휘 정리 — `--adversarial` · AC23 · `downgrade` · 접기 헬퍼 · 저자 필수

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py` · `plugins/quality-gates/scripts/verdict.py` · `plugins/quality-gates/scripts/recritic_bridge.py`(docstring 두 곳) · `tools/adjudication/check_wiring.py`(면제 키)
- Create: `plugins/quality-gates/tests/lib/recritic_fixture.sh`
- Test: `plugins/quality-gates/tests/test_verdict_vocabulary.sh` · `plugins/quality-gates/tests/test_recritic_bridge.sh` · `plugins/quality-gates/tests/test_synthesize_findings_adjudication.py` · Task 1 락 인벤토리의 `Task=2` 행 전부(주로 `test_angle_coverage.sh` · `test_synthesize_promoted_findings.sh` · `test_synthesize_disposition.sh` · `test_synthesize_findings.sh`)

**Interfaces:**
- Consumes: `recritic_bridge.load_recritic(recritic_path, map_path, diff_path, ledger) -> (doc, dead)` · `recritic_bridge.ADJUDICATOR`
- Produces:
  - `verdict.decide(*, defect=False, review_blocked=False, angle_absent=False, differential_text=None, extra_reasons=())` — `legacy_verdict` 없음
  - `synthesize_findings.promote_new_findings(raw_new, existing, *, author, ledger=None)` — `author` 필수 키워드
  - `synthesize_findings._fold_sev(value) -> value` — 문자열이면 `strip().upper()`, 아니면 그대로
  - 합성기 CLI: `--findings` · `--emit-verdict` · `--differential` · `--reason` · `--angles` · `--recritic` · `--recritic-map` · `--recritic-diff` (그 밖은 exit 2)
  - `tests/lib/recritic_fixture.sh`: `rf_prep <dir>` · `rf_reply <dir> <block>` · `rf_synth <dir> [args...]` (호출자가 `PLUGIN_ROOT` 를 정한다)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/quality-gates/tests/test_verdict_vocabulary.sh`:
1. 상단 변수에 `SYNTH="$PLUGIN_ROOT/scripts/synthesize_findings.py"` 를 더한다(없으면).
2. 옛 매핑표를 재던 네 케이스 — `case_not_certified_always_has_reason` 의 `--legacy-verdict` 부분 · `case_legacy_table_is_exactly_four` · `case_needs_resolution_requires_reason` · `case_legacy_table_marked_for_removal` — 를 지운다. `case_not_certified_always_has_reason` 는 legacy 줄을 빼고 「사유 없는 not-certified 는 낼 수 없다」를 `verdict.render({"verdict": "not-certified", "reason": None, "reasons": []})` 가 exit 4 인지로 다시 잰다:

```bash
case_not_certified_always_has_reason() {
  # AC8 후반 — 사유 없는 not-certified 는 **낼 수 없다**. 렌더러가 마지막 관문이다.
  local rc=0
  python3 -c "import sys; sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import verdict; verdict.render({'verdict':'not-certified','reason':None,'reasons':[]})" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "사유 없는 not-certified 는 exit 4"
  local out; out=$(python3 "$V" --reason kill-switch)
  assert_grep "$out" '^verdict: not-certified$' "사유를 주면 선다"
}
```

3. 새 케이스를 더하고 파일 끝 케이스 목록에 등록한다:

```bash
case_legacy_table_is_gone() {
  # AC23 — 옛 판정 어휘의 산출자(runtime-verifier)가 사라졌으므로 매핑표도 없다.
  local hits; hits=$(grep -cE 'LEGACY_VERDICTS|legacy_verdict|AC23' "$V" || true)
  assert_eq "$hits" "0" "verdict.py 에 옛 어휘 매핑의 흔적이 없다(정의·인자·표지)"
  local rc=0; python3 "$V" --legacy-verdict PASS >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "verdict.py 는 --legacy-verdict 를 모른다(exit 2)"
  rc=0; python3 "$SYNTH" --emit-verdict --legacy-verdict PASS >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "합성기도 --legacy-verdict 를 모른다(exit 2)"
  # 양의 짝 — 같은 CLI 가 살아 있는 인자는 받는다(「언제나 exit 2」 변이를 막는다).
  local out; out=$(python3 "$V" --reason kill-switch)
  assert_grep "$out" '^verdict: not-certified$' "살아 있는 인자는 그대로 선다"
}
```

4. `case_reason_enum_is_closed_and_accounted` 의 `AXES` 기대값을 바꾼다:

```bash
  assert_grep "$got" '^AXES:angle_absent,defect,differential_text,extra_reasons,review_blocked$' \
    "decide() 의 키워드 전용 파라미터 집합이 다섯이다 — 새 축마다 파라미터가 하나 는다(OVERLAP 이 못 잡는 헬퍼-추출 배선의 둘째 독립 증인)"
```

5. 파일 머리 주석의 `AC23` 을 지우고, 파일 안에서 `--legacy-verdict` 를 부르는 **다른** 케이스가 인벤토리에 있으면 그 행대로 처리한다.

`plugins/quality-gates/tests/test_recritic_bridge.sh` — 두 케이스를 더하고 등록한다(파일 안의 `one_finding` · `prep` · `reply` · `synth` 헬퍼를 쓴다):

```bash
case_adversarial_flag_is_gone() {
  local T; T=$(mktemp -d)
  one_finding "$T/findings.yaml"
  printf 'verdicts: []\n' > "$T/adv.yaml"
  local rc=0
  python3 "$SYNTH" --findings "$T/findings.yaml" --adversarial "$T/adv.yaml" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--adversarial 은 모르는 인자다(exit 2) — 판정자는 재비판 경로 하나다"
  # 양의 짝 — 같은 입력을 재비판 경로로 주면 선다.
  prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: confirm'
  local out; out=$(synth "$T" --emit-verdict)
  assert_grep "$out" '^verdict: defect$' "재비판 경로는 그대로 선다"
  rm -rf "$T"
}

case_downgrade_is_not_a_verb() {
  # 재비판자에게 하향은 없다. `downgrade` 는 모르는 verdict — confirm 으로 강제되고
  # 그 강제는 판정을 바꾼 것으로 공시된다. severity 는 그대로다.
  local T; T=$(mktemp -d)
  one_finding "$T/findings.yaml" security-reviewer app.py 10 CRITICAL
  prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: downgrade
    to: SUGGESTION'
  local out; out=$(synth "$T" --emit-verdict)
  assert_grep "$out" '^\| CRITICAL \| app\.py:10 \|' "CRITICAL 이 내려가지 않는다"
  assert_grep "$out" "강제\(게이트 변경\): verdict 'downgrade'" "모르는 verdict 는 게이트 강제로 공시된다"
  rm -rf "$T"
}
```

`plugins/quality-gates/tests/test_synthesize_findings_adjudication.py` — 클래스 하나를 더한다:

```python
class TestPromoteAuthorIsRequired(unittest.TestCase):

    def test_promote_new_findings_requires_author(self):
        """기본값이 있으면 판정자 자리가 사라진 뒤 유령 저자가 된다(PR3·PR4a 부채)."""
        with self.assertRaises(TypeError):
            mod.promote_new_findings([], [])
        promoted, dropped = mod.promote_new_findings(
            [{"file": "a.py", "line": 1, "severity": "IMPORTANT", "summary": "s"}], [],
            author="doc-recritic")
        self.assertEqual(dropped, 0)
        self.assertEqual(promoted[0]["agent"], "doc-recritic")

    def test_fold_sev_is_the_one_fold(self):
        """raise 가드와 _norm_sev 가 같은 접기를 쓴다 — 둘이 갈리면 소문자 raise 가 저지된다."""
        self.assertEqual(mod._fold_sev(" critical "), "CRITICAL")
        self.assertEqual(mod._fold_sev(["CRITICAL"]), ["CRITICAL"])
        self.assertEqual(mod._norm_sev({"severity": "Critical"}), "CRITICAL")
        self.assertEqual(mod._norm_sev({"severity": ["CRITICAL"]}), "SUGGESTION")
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd "$(git rev-parse --show-toplevel)"
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_verdict_vocabulary.sh 2>&1 | grep -E '✗' | head
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_recritic_bridge.sh 2>&1 | grep -E '✗' | head
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins.quality-gates.tests.test_synthesize_findings_adjudication 2>&1 | tail -3 \
  || PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p 'test_synthesize_findings_adjudication.py' 2>&1 | tail -3
```

**기대** — `legacy` · `AXES` · `--adversarial 은 모르는 인자다` · `promote_new_findings_requires_author` · `fold_sev` 가 RED. `downgrade` 케이스는 오늘도 GREEN 일 수 있다(오늘 `downgrade` 는 재비판 경로에서 이미 모르는 verdict 다) — **그것이 맞다**: 이 케이스는 제거 뒤에도 그 성질이 유지되는지를 잡는 **양의 짝**이다. 보고서에 오늘의 결과를 적는다.

- [ ] **Step 3: `verdict.py` 를 고친다**

1. 모듈 docstring 첫 줄을 `"""판정 어휘 — 세 값과 닫힌 사유 열거 (설계 §6.4.3, AC8 · AC9).` 로.
2. `# ── AC23 — 옛 판정 어휘 매핑표.` 로 시작하는 주석부터 `# ── AC23 블록 끝 ─…` 줄까지 **통째로** 지운다.
3. `decide` 를 이 모양으로(본문의 나머지는 그대로):

```python
def decide(*, defect=False, review_blocked=False, angle_absent=False,
           differential_text=None, extra_reasons=()):
```

그리고 본문의 `if legacy_verdict is not None:` 블록(다음 빈 줄까지)을 지운다.
4. `main()` 에서 `ap.add_argument("--legacy-verdict", default=None)` 줄, `if args.legacy_verdict is not None and args.legacy_verdict == "":` 블록, `legacy_verdict=args.legacy_verdict,` 인자를 지운다.

```bash
cd "$(git rev-parse --show-toplevel)"
python3 -m py_compile plugins/quality-gates/scripts/verdict.py
grep -nE 'LEGACY|legacy|AC23' plugins/quality-gates/scripts/verdict.py || echo "OK verdict.py 깨끗"
```

- [ ] **Step 4: `synthesize_findings.py` 를 고친다**

(a) **모듈 docstring 의 Inputs** 를 이것으로:

```text
Inputs (CLI args):
  --findings PATH      YAML file with list of raw findings
  --recritic PATH      재비판자(doc-recritic) 응답 원문 — `--recritic-map` 과 함께
  --recritic-map PATH  `recritic_bridge.py prepare` 가 쓴 역매핑 JSON
  --recritic-diff PATH 재비판자에게 준 diff (선택 — added 의 file 도출에만)
  --emit-verdict       본 보고서 뒤에 `angles:`(있으면) · `verdict:` 꼬리를 싣는다
  --differential PATH  diff-test-results.py 의 집계 YAML
  --reason R           호출자만 아는 사유(반복 가능, verdict.REASONS 안)
  --angles PATH        각도 상태 파일(`<각도>: <상태>` 세 줄)
```

(b) **`_fold_sev` 를 `_norm_sev` 바로 위에 더하고 `_norm_sev` 를 그것으로 다시 쓴다:**

```python
def _fold_sev(value):
    """severity 값 하나의 표기를 접는다(앞뒤 공백 · 대소문자). 문자열이 아니면 그대로.

    `_norm_sev` 와 `raise` 가드가 **같은 접기**를 쓴다 — 둘이 갈리면 소문자 `critical`
    이 한쪽에서만 SUGGESTION 랭크로 떨어진다.
    """
    return value.strip().upper() if isinstance(value, str) else value


def _norm_sev(f):
    """finding 의 severity 를 아는 버킷으로. 모르는 값(목록 · 해시 불가 포함)은 SUGGESTION.

    dedup · suppress · sort · render 네 곳이 부른다 — 총(total)이어야 한다. 모르는 값을
    버킷에 못 넣으면 표에는 행이 서는데 counts 줄에서 빠져 kept=0(clean)으로 읽힌다.
    """
    folded = _fold_sev(f.get("severity", "SUGGESTION"))
    if isinstance(folded, str) and folded in SEV_ORDER:
        return folded
    print(
        f"[synthesize_findings] unknown severity {f.get('severity')!r}; treating as SUGGESTION",
        file=sys.stderr,
    )
    return "SUGGESTION"
```

(c) **`promote_new_findings` 의 서명과 docstring 첫 단락:**

```python
def promote_new_findings(raw_new, existing, *, author, ledger=None):
    """판정자 문서의 `new_findings:` 항목을 진짜 finding으로 승격한다.

    Returns (promoted, dropped_malformed). `author` 는 판정자 문서를 «낸» 쪽이다 —
    기본값을 두지 않는다(판정자 자리가 바뀌면 기본값이 유령 저자가 된다).
```

docstring 의 나머지 단락(출처는 `agent` 에 쓴다 · id 합성 · `promoted: True`)은 **남긴다** — 행동 규칙이다. 본문의 `# 승격 저자는 판정자 문서를 «낸» 쪽이다 — …(PR3 부채).` 세 줄 주석은 지운다(docstring 이 말한다). 호출부는 `promote_new_findings(new_raw, findings, author=_bridge.ADJUDICATOR, ledger=ledger)` 가 된다(아래 (g)).

(d) **`apply_verdicts` 를 통째로 이것으로 바꾸고 `_apply_raise` 를 그 아래에 둔다:**

```python
def apply_verdicts(findings, verdicts, ledger=None, adjudicator_dead=False):
    """판정자 판정을 적용한다. Returns (out, dropped_malformed).

    - 매핑이 아닌 finding 은 버리되 **센다**(`dropped`) — 세지 않으면 버려진 CRITICAL 이
      clean 으로 렌더된다.
    - 판정 없는 finding 은 유지하고(다음 소비자가 사람이다) 원장에 `hold` 로 센다.
      판정자가 통째로 죽었으면(`adjudicator_dead`) 항목마다 세지 않는다 — 그 사망은
      원장에 이미 한 번 있고 `angle-absent` 로 나간다. 항목마다 세면 `findings-lost` 가
      사유 순서상 앞서 사유가 뒤바뀐다.
    - `raise` 는 severity 를 «올리기만» 한다(`_apply_raise`).
    """
    by_id = {v.get("finding_id"): v for v in verdicts if isinstance(v, dict)}
    out = []
    dropped = 0
    for f in findings:
        if not isinstance(f, dict):
            dropped += 1
            if ledger is not None:
                ledger.hold(repr(f)[:60], "항목 파손: not a mapping")
            print("[synthesize_findings] dropped malformed finding "
                  f"({type(f).__name__}, expected mapping): {str(f)[:80]!r}",
                  file=sys.stderr)
            continue
        # 수집 지점 정규화 — dedup 키 · sort · finding_id 가 모두 이 값을 만진다.
        f = _normalize_identity(dict(f), ledger=ledger)
        v = by_id.get(finding_id(f))
        if v is None:
            if ledger is not None and not adjudicator_dead:
                ledger.hold(finding_id(f), "판정자 부재: 판정자 판정 없음")
            out.append(f)
            continue
        verdict = v.get("verdict", "confirm")
        if verdict == "reject":
            if ledger is not None:
                ledger.reject(finding_id(f), "판정자 기각")
            continue
        if verdict == "raise" and "adjusted_severity" in v:
            f = _apply_raise(f, v["adjusted_severity"], ledger)
        if ledger is not None:
            ledger.accept(finding_id(f))
        out.append(f)
    return out, dropped


def _apply_raise(f, adjusted, ledger):
    """`raise` — 지금보다 «진짜로» 높을 때만 severity 를 바꾼다.

    판정자 쪽 매핑(`recritic-map.json`)이 낡아 이 finding 의 실제 severity 보다 낮은 값을
    가리키면, 그대로 적용하는 것은 CRITICAL 을 조용히 내리는 raise 다. 적용하지 않고
    원장에 강제로 남긴다 — 내렸을 것이면 판정을 바꾼 강제(`gate=True`), 같은 등급이면
    표기 강제(`gate=False`).
    """
    new_sev = _fold_sev(adjusted)
    cur_sev = _norm_sev(f)
    if isinstance(new_sev, str) and new_sev in SEV_ORDER:
        new_rank = SEV_ORDER[new_sev]
    else:
        new_rank = SEV_ORDER["SUGGESTION"]
    cur_rank = SEV_ORDER[cur_sev]
    if new_rank < cur_rank:
        f = dict(f)
        f["severity"] = new_sev
    elif ledger is not None:
        ledger.coerced("adjusted_severity", new_sev, cur_sev, gate=new_rank > cur_rank)
    return f
```

(`adjusted_confidence` 분기와 `downgrade` 분기는 이것으로 사라진다 — R-AD.)

(e) **`load_yaml_doc` 를 지운다**(호출자가 `--adversarial` 경로뿐이었다). 지우기 전에 확인:

```bash
cd "$(git rev-parse --show-toplevel)"
git grep -n 'load_yaml_doc' -- plugins shared tools ':!**/CHANGELOG.md'
```

**기대** — 합성기 정의 · 호출 한 자리와 `recritic_bridge.py` docstring 두 곳 · 테스트 주석뿐. 코드 호출이 그 밖에 있으면 **BLOCKED**. 브리지 docstring 두 곳은 이렇게 고친다: 137행 근처 「`load_yaml_doc`(옛 경로)의 doc 에는 이 두 키가 없다 — …」 문장은 통째로 지우고, 277행 근처 `Returns \`(doc, dead)\` — \`load_yaml_doc\` 과 같은 모양.` 은 `Returns \`(doc, dead)\`.` 로.

(f) **`extract_verdicts` 의 라벨** — `"adversarial document"` 를 `"판정자 문서"` 로.

(g) **`main()`:**
- `ap.add_argument("--adversarial", default="")` · `ap.add_argument("--legacy-verdict", default=None)` 를 지운다.
- `args.legacy_verdict` 빈 문자열 검사 블록, `--recritic` 과 `--adversarial` 배타 검사 블록, `if not args.emit_verdict:` 안의 `--legacy-verdict` 검사 블록을 지운다.
- 「I1 (리뷰 라운드 2) — 위 두 검사는…」 로 시작하는 긴 주석은 두 줄로 줄인다:

```python
    # 판정 입력 플래그는 `--emit-verdict` 없이는 의미가 없다 — 조용히 버리면 판정축이
    # 빠진 실행이 완전해 보이는 보고서 + rc 0 을 낸다. exit 2(잘못된 호출)로 막는다.
```

- 판정자 로드를 이것으로:

```python
    ledger = Ledger(items="open")

    if args.recritic is not None:
        doc, adjudicator_dead = _bridge.load_recritic(
            args.recritic, args.recritic_map, args.recritic_diff, ledger)
    else:
        doc, adjudicator_dead = None, False
```

- 승격 호출: `promote_new_findings(new_raw, findings, author=_bridge.ADJUDICATOR, ledger=ledger)`.
- `_verdict.decide(...)` 호출에서 `legacy_verdict=args.legacy_verdict,` 줄을 지운다.
- `--emit-verdict` 블록 안의 긴 주석 셋(「Ruling T5-b」 · 「재비판 Important(경)」 · 「재비판 라운드 2 — 이전 가드…」)은 **규칙만** 남긴다 — 각각 한두 줄:

```python
    # 판정 «계산»은 본 보고서를 쓰기 «전»에 한다 — fail4 가 터지면 stdout 이 비어 있어야
    # 한다(원자적 실패 계약).
```

```python
                    # `agent: null` 은 agent 없음과 같은 사건이다(YAML 의 null · ~ · 빈 값).
```

```python
                        # dedup() 이 `agent: null` 에서 파생시킨 None 만 건너뛴다 — 리뷰어가
                        # 적은 `sources: [null]` 은 문법 밖 저자로 흘려 검사한다(비신뢰 필드).
```

- 「fix round 1 Important 1 — 변환 «후» 길이…」 주석은 한 줄로: `# 「재비판 0」은 변환 «전» 원문 길이가 둘 다 0 일 때만 참이다(파손된 원문이 0 으로 접히지 않게).`

(h) **남은 자기서사 주석 스윕** — 이 파일에서 `fix round` · `라운드 [0-9]` · `Task [0-9]` · `20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] 재현` · `PR[0-9]` 를 grep 해, 각 주석이 **행동 규칙**(왜 이 코드가 이 모양이어야 하나)을 담으면 이력 부분만 지우고, 이력**만** 담으면 통째로 지운다. docstring 도 같다. **규칙 문장은 지우지 않는다** — 지우면 다음 편집자가 그 코드를 「고친다」.

```bash
cd "$(git rev-parse --show-toplevel)"
python3 -m py_compile plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/recritic_bridge.py
grep -nE -- '--adversarial|legacy|downgrade|adjusted_confidence|load_yaml_doc|"adversarial"' plugins/quality-gates/scripts/synthesize_findings.py || echo "OK 합성기 깨끗"
grep -cE 'fix round|라운드 [0-9]|Task [0-9]' plugins/quality-gates/scripts/synthesize_findings.py
```

**기대** — `OK 합성기 깨끗` · 마지막 수는 보고서에 적는다(0 이 목표지만, 남긴 것이 있으면 줄마다 이유를 적는다).

- [ ] **Step 5: 테스트 헬퍼를 만든다 — `tests/lib/recritic_fixture.sh`**

```bash
# shellcheck shell=bash
# recritic_fixture.sh — 합성기를 재비판 경로(`--recritic`)로 부르는 테스트 헬퍼.
# `source` 해서 쓴다. 호출자가 PLUGIN_ROOT 를 정해 둬야 한다.
#
#   rf_prep  <dir>           <dir>/findings.yaml → <dir>/rf.yaml · <dir>/map.json
#   rf_reply <dir> <block>   <dir>/reply.txt — 재비판자 응답 원문(산문 + 펜스 하나)
#   rf_synth <dir> [인자...] 합성기를 재비판 경로로 부른다(stdout · rc 그대로)
#
# 판정은 `f<n>` 으로 적는다 — n 은 findings.yaml 안 «매핑 항목»의 1-기반 순번이다
# (recritic_bridge.anonymize 가 그 순서로 번호를 준다).
rf_prep() {
  python3 "$PLUGIN_ROOT/scripts/recritic_bridge.py" prepare --findings "$1/findings.yaml" \
    --out-findings "$1/rf.yaml" --out-map "$1/map.json"
}
rf_reply() {
  { printf '재비판을 마쳤습니다.\n\n```docreview-recritic\n'; printf '%s\n' "$2"; printf '```\n'; } > "$1/reply.txt"
}
rf_synth() {
  local d="$1"; shift
  python3 "$PLUGIN_ROOT/scripts/synthesize_findings.py" --findings "$d/findings.yaml" \
    --recritic "$d/reply.txt" --recritic-map "$d/map.json" "$@"
}
```

`plugins/quality-gates/tests/lib/` 는 `.gitignore` 에서 `!` 로 풀려 있다 — 확인: `git check-ignore -v plugins/quality-gates/tests/lib/recritic_fixture.sh || echo "OK 추적 가능"`.

- [ ] **Step 6: `--adversarial` 호출 자리를 옮긴다 — 인벤토리의 `Task=2` 행**

`convert` 행은 아래 표대로 옮긴다. **케이스의 의도(주석 · 단언 메시지)를 먼저 읽고**, 옮긴 뒤 같은 단언이 같은 이유로 GREEN 인지 본다.

| 옛 판정자 문서 | 재비판 응답 블록(`rf_reply` 의 둘째 인자) |
|---|---|
| `verdicts:` 의 `- finding_id: <id>` | `- f: f<n>` — n 은 findings.yaml 에서 그 finding 의 순번 |
| `verdict: confirm` | `verdict: confirm` |
| `verdict: reject` (+ `reason: R`) | `verdict: reject` + `evidence: "R"` — **근거 필수**(없으면 confirm 으로 강제된다) |
| `verdict: raise` + `adjusted_severity: S` | `verdict: raise` + `to: S` |
| `verdict: downgrade` | **대응 없음** — 케이스 의도가 하향이면 `delete`, 아니면 `confirm` 으로 |
| `new_findings: [...]` | `added: [...]`(필드 `file` · `line` · `severity` · `summary` · `proposed_fix` 그대로). 승격 저자는 `doc-recritic` 이 된다 — `adversarial` 을 기대하던 단언은 `doc-recritic` 으로 |
| 빈 문서 · 파일 부재 · 스칼라 문서(판정자 사망) | 응답 파일 없음 · 빈 응답 · 펜스 없는 응답 · 매핑 아닌 블록. `test_recritic_bridge.sh` 가 이미 다섯 사망 모양을 재므로, 같은 모양이 거기 있으면 `delete`(규칙을 잇는 자리 칸에 그 케이스 이름) |
| `verdicts: []` (판정자는 있고 판정 0) | `verdicts: []` + `added: []` |

`delete` 행은 인벤토리의 「규칙을 잇는 자리」 칸을 채운 채로 지운다. **경로 차이로 기대값이 바뀌는 케이스**(예: 재비판 경로만 `탐지 0 · 재비판 0` 줄을 낸다)는 새 기대값으로 고치고 보고서에 케이스별로 적는다.

- [ ] **Step 7: 면제 키를 재앵커하고 통과를 확인한다**

```bash
cd "$(git rev-parse --show-toplevel)"
grep -n "if f.get('promoted')" plugins/quality-gates/scripts/synthesize_findings.py
grep -n 'continue' plugins/quality-gates/scripts/synthesize_findings.py | head
```

`dedup()` 안 `if f.get("promoted"):` 다음 줄 `continue` 의 **줄번호**를 `tools/adjudication/check_wiring.py` 의 `("plugins/quality-gates/scripts/synthesize_findings.py", 467,` 에 넣는다. 그 위 재앵커 이력 주석(「PR4a Task 4 — …」 · 「Task 7 row 31 — …」)은 **지우고** 한 줄만 남긴다: `# 줄번호 키 — 합성기를 고치는 PR 마다 실측으로 재앵커한다(exempt_stale=0 이 답한다).`

```bash
cd "$(git rev-parse --show-toplevel)"
export PYTHONDONTWRITEBYTECODE=1
for t in plugins/quality-gates/tests/test_verdict_vocabulary.sh plugins/quality-gates/tests/test_recritic_bridge.sh \
         plugins/quality-gates/tests/test_angle_coverage.sh plugins/quality-gates/tests/test_synthesize_promoted_findings.sh \
         plugins/quality-gates/tests/test_synthesize_disposition.sh plugins/quality-gates/tests/test_synthesize_findings.sh \
         shared/tests/test_adjudication_wiring.sh shared/tests/test_adjudication_consumed.sh; do
  printf '%s ' "$t"; bash "$t" 2>&1 | grep -cE '^[[:space:]]*✗|^FAIL:'
done
python3 tools/adjudication/check_wiring.py 2>&1 | grep -E 'exempt_stale|FAIL' | head
python3 -m unittest discover -s plugins/quality-gates/tests -p 'test_synthesize*.py' 2>&1 | tail -3
bash "$CLAUDE_JOB_DIR/tmp/run-suite.sh" "$CLAUDE_JOB_DIR/tmp/t2.tsv"
```

**기대** — 위 락들의 실패 줄 0 · `exempt_stale=0` · unittest OK · `run-suite` 의 rc≠0/실패≠0 행이 **기준선 넷 그대로**(행 단위로 `pr4b-baseline.tsv` 와 대조한다 — `diff <(cut -f1-3 pr4b-baseline.tsv) <(cut -f1-3 t2.tsv)` 의 차이가 이 Task 가 바꾼 파일뿐인지 본다).

- [ ] **Step 8: 커밋**

```bash
cd "$(git rev-parse --show-toplevel)"
git add plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/verdict.py \
        plugins/quality-gates/scripts/recritic_bridge.py tools/adjudication/check_wiring.py \
        plugins/quality-gates/tests/lib/recritic_fixture.sh
git add -u plugins/quality-gates/tests
git status --short
git commit -m "refactor(qg): 합성기 판정자 경로를 재비판 하나로 — --adversarial · AC23 매핑표 · downgrade 제거" \
  -m "옛 판정자 경로(--adversarial)와 옛↔새 판정 어휘 매핑표(LEGACY_VERDICTS · --legacy-verdict)를 지운다. raise 가드는 _fold_sev 로 _norm_sev 와 같은 접기를 쓰고, 승격 저자는 필수 키워드다. 옛 경로로 합성기를 부르던 락은 tests/lib/recritic_fixture.sh 로 옮겼다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4b
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

`git status --short` 에 이 Task 가 만들지 않은 파일이 보이면 커밋하지 않고 멈춘다(워크트리 공유 중 쓸어담기 방지).

---

### Task 3: 보조 입력 사망은 공시다 — not-clean 마커는 차단에만 선다 (R-AA)

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py`(`_degrade_block` · `render` · `main`) · `tools/adjudication/check_wiring.py`(면제 키)
- Test: `plugins/quality-gates/tests/test_recritic_bridge.sh` · 인벤토리의 `Task=3` 행(`invert` — 보조 사망 · 게이트 강제에 마커를 기대하던 단언)

**Interfaces:**
- Consumes: `Ledger.blocks()` · `Ledger.report()["degraded"]` · `["reasons"]`
- Produces: `render(kept, suppressed_count, dropped_malformed, report, held_classes, recritic_zero=False, blocking=False)` · `_degrade_block(report, blocking)`. **본 보고서의 두 머리줄 문자열**(Task 7 SKILL 이 인용한다):
  - 차단: `판정 degrade — **이 실행은 clean이 아니다**: 판정 경로가 온전하지 않았다.`
  - 공시: `판정 degrade — 공시(판정을 막지 않음): 보조 경로가 온전하지 않았다.`

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `test_recritic_bridge.sh` 에 셋을 더하고 등록한다:

```bash
case_aux_death_discloses_without_not_clean_marker() {
  # Review Focus 4 · 헌장 — 보조 입력(diff) 사망은 공시하되 막지 않는다.
  local T; T=$(mktemp -d)
  one_finding "$T/findings.yaml"
  prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: reject
    evidence: "app.py:10 은 이미 파라미터 바인딩을 쓴다"'
  local out; out=$(synth "$T" --recritic-diff "$T/gone.diff" --emit-verdict)
  assert_grep     "$out" '공시\(판정을 막지 않음\)'            "보조 사망은 공시 머리줄로 드러난다"
  assert_grep     "$out" '입력 실패\(보조\)'                    "무엇이 죽었는지 사유 줄이 선다"
  assert_not_grep "$out" '이 실행은 clean이 아니다'             "not-clean 마커는 서지 않는다"
  assert_grep     "$out" '^verdict: clean$'                     "판정은 막히지 않는다"
  rm -rf "$T"
}

case_primary_death_keeps_not_clean_marker() {
  # 양의 짝 — 주 판정자 사망은 여전히 차단이고 마커가 선다. 탐지 0 으로 둔다 —
  # finding 이 남으면 defect 가 우선이라 reason 줄이 안 선다(§6.4.3 우선순위).
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"
  prep "$T"
  local out; out=$(synth "$T" --emit-verdict)      # reply.txt 없음 = 재비판자 사망
  assert_grep "$out" '이 실행은 clean이 아니다' "주 입력 사망은 not-clean 마커를 세운다"
  assert_grep "$out" '^reason: angle-absent$'   "판정은 angle-absent"
  rm -rf "$T"
}

case_gate_coercion_is_disclosure_not_block() {
  # 근거 없는 reject 는 confirm 으로 강제된다(게이트 변경). finding 은 남아 defect —
  # 강제 자체는 공시이지 not-clean 마커가 아니다.
  local T; T=$(mktemp -d)
  one_finding "$T/findings.yaml"
  prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: reject'
  local out; out=$(synth "$T" --emit-verdict)
  assert_grep     "$out" '강제\(게이트 변경\)'          "강제는 공시된다"
  assert_not_grep "$out" '이 실행은 clean이 아니다'     "강제만으로는 not-clean 마커가 서지 않는다"
  assert_grep     "$out" '^verdict: defect$'            "finding 이 남아 defect"
  rm -rf "$T"
}
```

- [ ] **Step 2: 실패를 확인한다** — `bash plugins/quality-gates/tests/test_recritic_bridge.sh 2>&1 | grep -E '✗'` 에서 첫째 · 셋째 케이스의 마커 단언이 RED, 둘째는 GREEN(양의 짝 — 오늘도 참이어야 한다).

- [ ] **Step 3: 구현**

`_degrade_block` 을 통째로:

```python
def _degrade_block(report, blocking):
    """degrade 공시 줄들. 막는 사건이면 not-clean 마커, 아니면 공시 머리줄.

    공시와 차단은 다른 술어다(헌장). 막는 것은 항목 소실 · 셀 수 없음 · 주 판정자
    사망(`Ledger.blocks()`)뿐이다 — 보조 입력 사망 · 판정을 바꾼 강제는 드러내되
    막지 않는다. 마커가 공시 술어에 묶이면 본 보고서는 「clean 이 아니다」, 꼬리는
    `verdict: clean` 인 자기모순이 난다.

    사유 문자열 안의 item 이름은 리뷰어 저작 YAML 에서 온다 — 표 셀과 같은 문을
    통과시킨다(개행이 raw 로 나가면 이 블록 아래에 가짜 머리줄을 심을 수 있다).
    """
    if not report["degraded"]:
        return []
    if blocking:
        head = (f"{DEGRADE_MARKER} — **이 실행은 clean이 아니다**: "
                "판정 경로가 온전하지 않았다.")
    else:
        head = f"{DEGRADE_MARKER} — 공시(판정을 막지 않음): 보조 경로가 온전하지 않았다."
    out = [head]
    out.extend(f"- {_cell(r)}" for r in report["reasons"])
    return out
```

`render` 서명에 `blocking=False` 를 더하고, 안의 두 호출 `_degrade_block(report["degraded"], report["reasons"])` 를 `_degrade_block(report, blocking)` 으로 바꾼다. `main()` 의 `render(...)` 호출에 `blocking=ledger.blocks()` 를 더한다. `DEGRADE_MARKER` 위 주석(「degrade 공시의 고정 마커. 소실(`dropped as malformed`)과 **다른 사건**이다…」)은 규칙이라 남기되, 「판정 «경로» 자체가 온전하지 않았던 것 (주 입력 사망·셀 수 없음·게이트를 바꾼 강제)」의 괄호를 「(차단이면 not-clean 마커, 아니면 공시 머리줄 — `_degrade_block`)」으로 바꾼다.

**`dropped_malformed > 0` 의 마커는 그대로 둔다** — 버려진 finding 은 항목 소실이고, 원장에서도 `hold` 로 `items_unaccounted()` → 차단이다.

- [ ] **Step 4: `invert` 행을 처리한다** — 인벤토리의 `Task=3` 행(보조 입력 사망 · 게이트 강제에 `이 실행은 clean이 아니다` 를 기대하던 단언)을 새 기대값(공시 머리줄 · 마커 부재)으로 뒤집는다. 뒤집은 행마다 **양의 짝이 같은 파일 안에 있는지** 본다(주 입력 사망 → 마커) — 없으면 Step 1 의 둘째 케이스가 그 짝이다.

- [ ] **Step 5: 면제 키 재앵커 · 통과 확인** — Task 2 Step 7 과 같은 명령으로 줄번호를 다시 재고 `check_wiring.py` 를 고친다. 같은 락 묶음과 `run-suite.sh` 를 돌려 기준선과 행 단위로 대조한다.

- [ ] **Step 6: 커밋**

```bash
cd "$(git rev-parse --show-toplevel)"
git add plugins/quality-gates/scripts/synthesize_findings.py tools/adjudication/check_wiring.py
git add -u plugins/quality-gates/tests
git status --short
git commit -m "fix(qg): not-clean 마커는 차단에만 — 보조 입력 사망 · 게이트 강제는 공시" \
  -m "공시와 차단은 다른 술어다(헌장). 보조 입력(recritic.diff) 사망이 본 보고서의 not-clean 마커를 세워 SKILL 이 막고 있었다. 마커는 Ledger.blocks() 와 버려진 finding 에만 서고, 나머지 degrade 는 공시 머리줄로 드러난다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4b
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 4: 봉인 배선 — 인덱스는 `.git` 안 · `create-head` 는 다시 뜬 봉인과 대조 (R-X)

**Files:**
- Modify: `plugins/quality-gates/scripts/seal-worktree.sh` · `plugins/quality-gates/scripts/qg-worktree.sh`(`create-head` 분기 · 헤더)
- Test: `plugins/quality-gates/tests/test_seal_no_side_effects.sh` · `plugins/quality-gates/tests/test_runtime_contract_invariance.sh`(`case_create_head_asserts_sealed_commit`) · 인벤토리의 `Task=4` 행

**Interfaces:**
- Consumes: 없음
- Produces:
  - `seal-worktree.sh seal <sid>` → 봉인 커밋 SHA 한 줄(계약 불변). 임시 인덱스 자리 = `git rev-parse --git-path qg-seal-<sid8>.index`
  - `qg-worktree.sh create-head <sealed-sha> <sid>` → HEAD 축 트리 경로 한 줄(계약 불변). **샌드박스가 필요 없다.** `<sealed-sha>` 의 트리 ≠ 지금 다시 뜬 봉인의 트리 → die(exit 2)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_seal_no_side_effects.sh`:
1. `case_fails_closed_when_not_ignored` 를 지우고 이것으로 바꾼다(Review Focus 1):

```bash
case_seal_succeeds_when_claude_dir_not_ignored() {
  # 흔한 사용자 리포 — .claude/ 를 무시하지 않는다(.claude/settings.json 을 커밋한다).
  # 봉인은 성공해야 하고, 봉인 트리에 임시 인덱스가 없어야 한다(AC14).
  local R; R=$(mktemp -d); cd "$R" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  mkdir -p .claude; echo '{}' > .claude/settings.json
  echo tracked > a.txt; git add -A; git commit -qm base    # .gitignore 없음
  echo changed > a.txt
  local B rc=0; B=$(bash "$SEAL" seal "sess0001xyz") || rc=$?
  assert_eq "$rc" "0" "무시 설정이 없어도 봉인이 성공한다"
  local names; names=$(git ls-tree -r --name-only "$B" 2>/dev/null)
  assert_not_grep "$names" 'seal-.*\.index' "봉인 트리에 임시 인덱스(와 .lock)가 없다"
  assert_grep     "$names" '^\.claude/settings\.json$' "추적 파일은 그대로 봉인된다(양의 짝)"
  assert_eq "$(git show "$B:a.txt")" "changed" "워킹트리 수정이 봉인에 반영된다"
  cd / && rm -rf "$R"
}
```

2. `case_lock_leak_dies_closed` 는 전제(인덱스가 추적 자리에 있다)가 사라진다 — `delete`. 인벤토리의 「규칙을 잇는 자리」 = `case_seal_succeeds_when_claude_dir_not_ignored` 의 트리 검사 + Task 10 변이(인덱스를 워킹트리 자리로 되돌리면 권위 가드가 die).
3. `case_index_file_cleaned_up` 가 `find .claude -name 'seal-*'` 로 잔여를 세면 `.git` 쪽으로 바꾼다: `find "$(git rev-parse --git-dir)" -name 'qg-seal-*'`.

`test_runtime_contract_invariance.sh` 의 `case_create_head_asserts_sealed_commit` 을 통째로:

```bash
# create-head 의 sha 는 **선언된 자유 변수가 아니다** — 지금 다시 뜬 봉인의 트리와
# 대조되고 다르면 죽는다(설계 §6.4.1 — 「봉인 커밋의 트리가 기대 OID 와 일치」).
# `$merge_base` 를 넘기는 실수(형제 create-baseline 과 인자 모양이 같다)면 HEAD 축이
# 기준선의 바이트 복사본이 되어 전 unit 이 STILL_GREEN 으로 접힌다. 세 축 + 양의 짝.
case_create_head_asserts_sealed_commit() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main; echo v1 > a.txt; git add a.txt; git commit -qm v1
  local mb; mb=$(git rev-parse HEAD)
  git checkout -q -b feature; echo v2 > a.txt; git commit -qam v2
  echo v3 > a.txt                                   # 미커밋 변경 — 봉인이 담아야 한다
  local SEAL="$PLUGIN_ROOT/scripts/seal-worktree.sh"
  local sealed; sealed=$(bash "$SEAL" seal "sess7777") || { no "봉인 실패"; cd / && rm -rf "$REPO"; return; }

  # 양의 짝: 방금 뜬 봉인은 받아들인다
  local h
  if h=$(bash "$WT" create-head "$sealed" "sess7777" 2>/dev/null) && [[ "$(cat "$h/a.txt")" == "v3" ]]; then
    ok "봉인 커밋 → create-head 수락 · 트리에 미커밋 변경이 있다 (양의 짝)"
    bash "$WT" remove "$h" >/dev/null 2>&1
  else
    no "봉인 커밋인데 create-head 가 거부했거나 트리가 봉인과 다르다"
  fi

  # 음 ①: merge_base — 형제 호출과 인자 모양이 같아 가장 현실적인 오값
  if bash "$WT" create-head "$mb" "sess7777" >/dev/null 2>&1; then
    no "merge_base 가 통과함 — HEAD 축이 기준선 복사본이 된다"
  else
    ok "merge_base → create-head 거부"
  fi

  # 음 ②: 봉인 뒤 워킹트리가 바뀐 stale 봉인
  echo v4 > a.txt
  if bash "$WT" create-head "$sealed" "sess7777" >/dev/null 2>&1; then
    no "봉인 뒤 워킹트리가 바뀌었는데 옛 봉인이 통과함"
  else
    ok "stale 봉인 → create-head 거부"
  fi

  # 음 ③: 커밋이 아닌 값
  if bash "$WT" create-head "not-a-commit" "sess7777" >/dev/null 2>&1; then
    no "커밋이 아닌 값이 통과함"
  else
    ok "커밋 아닌 값 → create-head 거부"
  fi
  cd / && rm -rf "$REPO"
}
```

이 케이스의 테스트 리포는 `.gitignore` 가 없다 — R-X 이후 봉인은 그 상태에서 서야 한다(Review Focus 1 의 둘째 증인).

- [ ] **Step 2: 실패를 확인한다** — `test_seal_no_side_effects.sh` 의 새 케이스가 `rc=2`(오늘의 check-ignore 가드), `test_runtime_contract_invariance.sh` 의 양의 짝이 RED(오늘은 샌드박스가 없어 거부).

- [ ] **Step 3: `seal-worktree.sh` 를 고친다**

헤더 주석의 「**요건은 「리포 밖」이 아니라 「git 이 무시하는 자리」다.** … 뒤의 것이 권위다: 위치가 아니라 결과를 잰다.」 단락을 이것으로:

```bash
# **요건은 「git 이 집지 않는 자리」다.** 임시 인덱스를 `.git` 안(`git rev-parse
# --git-path`)에 둔다 — `git add -A` 가 원리적으로 집지 않고, 사용자 리포의 무시 설정에
# 의존하지 않는다. 봉인 «후» 트리 검사가 권위 가드다: 위치가 아니라 결과를 잰다.
```

`main_root=…` 두 줄 다음의 인덱스 자리 · mkdir · check-ignore 블록(`rel=` 부터 `|| die "seal index path is not git-ignored…"` 까지)을 이것으로:

```bash
SEAL_INDEX=$(git -C "$main_root" rev-parse --git-path "qg-seal-${sid_short}.index" 2>/dev/null) \
  || die "cannot resolve git dir for the seal index"
case "$SEAL_INDEX" in /*) ;; *) SEAL_INDEX="$main_root/$SEAL_INDEX" ;; esac
```

권위 가드의 패턴을 `grep -qE "seal-${sid_short}\.index(\.lock)?$"` 에서 `grep -qE "qg-seal-${sid_short}\.index(\.lock)?$|seal-${sid_short}\.index(\.lock)?$"` 로 넓히고 die 문구의 `($rel)` 를 `($SEAL_INDEX)` 로 바꾼다. 나머지(서브셸의 `export GIT_INDEX_FILE` · `trap` · commit-tree 설정)는 그대로다.

- [ ] **Step 4: `qg-worktree.sh` 의 `create-head` 를 고친다**

`create-head)` 분기의 주석과 본문을 이것으로(분기 끝 `;;` 까지):

```bash
  create-head)
    # HEAD 축(봉인 커밋). **봉인 확인 (assert-equality)** — 인자가 선언된 자유 변수가
    # 되면 형제 `create-baseline "$merge_base" <sid>` 와 인자 모양이 같아, `$merge_base`
    # 를 넘기는 실수 하나로 HEAD 축이 기준선의 바이트 복사본이 되고 전 unit 이 STILL_GREEN
    # 으로 접힌다. 그래서 지금 봉인을 **다시 떠서** 트리를 대조한다 — 기대 OID 를
    # 오케스트레이터가 따로 옮겨 적지 않으므로 대조 양쪽이 같은 전사에서 나오지 않는다.
    # 대조는 거부만 할 수 있고 선택은 못 한다: 값의 출처는 여전히 호출자다.
    [[ $# -eq 3 ]] || die "usage: create-head <sealed-sha> <session-id>"
    git rev-parse --verify --quiet "$2^{commit}" >/dev/null \
      || die "not a commit: $2"
    ch_expected=$(bash "$(dirname "${BASH_SOURCE[0]}")/seal-worktree.sh" seal "$3") \
      || die "cannot re-seal the working tree to verify the HEAD axis"
    [[ "$(git rev-parse "$2^{tree}")" == "$(git rev-parse "$ch_expected^{tree}")" ]] \
      || die "sealed-sha mismatch: tree of '$2' is not the tree of the working tree sealed now — the HEAD axis must be built from the seal, not from merge_base or a stale seal"

    make_detached_worktree "$2" "$3" head
    ;;
```

파일 헤더의 서브커맨드 목록에서 `create-sandbox` · `mutation-guard` 줄 옆에 소비자를 적는다(R-W):

```bash
#   create-sandbox · mutation-guard — qg 파이프라인은 더 부르지 않는다. 소비자는
#     plugins/plugin-audit/scripts/run-own-tests.sh(자체 테스트 격리)다.
```

헤더에 `create-head` 설명이 있으면 「create-sandbox 가 봉인한 커밋 B」를 「seal-worktree.sh 가 봉인한 커밋」으로.

- [ ] **Step 5: 통과 확인**

```bash
cd "$(git rev-parse --show-toplevel)"
export PYTHONDONTWRITEBYTECODE=1
bash -n plugins/quality-gates/scripts/seal-worktree.sh && bash -n plugins/quality-gates/scripts/qg-worktree.sh && echo "OK 구문"
for t in plugins/quality-gates/tests/test_seal_no_side_effects.sh plugins/quality-gates/tests/test_runtime_contract_invariance.sh \
         plugins/quality-gates/tests/test_topic_boundary.sh plugins/quality-gates/tests/test_qg_runtime_sandbox.sh \
         plugins/quality-gates/tests/test_qg_mutation_guard.sh plugins/quality-gates/tests/test_worktree.sh \
         plugins/quality-gates/tests/test_qg_worktree_helper.sh; do
  printf '%s ' "$t"; bash "$t" 2>&1 | grep -cE '^[[:space:]]*✗|^FAIL:'
done
bash "$CLAUDE_JOB_DIR/tmp/run-suite.sh" "$CLAUDE_JOB_DIR/tmp/t4.tsv"
```

**기대** — 전부 0(단 `test_runtime_contract_invariance.sh` 의 인벤토리 `Task=7` 행 — verdict 토큰 · detect-runtime — 은 Task 7 이 처리하므로 여기서 그 단언이 오늘 GREEN 이면 그대로 둔다). `test_topic_boundary.sh` 는 봉인을 쓰므로 인덱스 자리 변경에 GREEN 이어야 한다 — RED 면 그 락이 옛 자리(`.claude/quality-gates/seal-*`)를 앵커로 쓰는지 보고, 그렇다면 인벤토리에 `retarget` 행으로 더해 여기서 고친다. `run-suite` 는 기준선과 행 단위로 대조한다.

- [ ] **Step 6: 커밋**

```bash
cd "$(git rev-parse --show-toplevel)"
git add plugins/quality-gates/scripts/seal-worktree.sh plugins/quality-gates/scripts/qg-worktree.sh
git add -u plugins/quality-gates/tests
git status --short
git commit -m "feat(qg): 봉인 인덱스를 .git 안으로 · create-head 는 다시 뜬 봉인과 트리를 대조" \
  -m ".claude/ 를 무시하지 않는 리포에서 봉인이 exit 2 로 죽던 것을 닫는다. create-head 는 샌드박스 없이 서고, 인자의 트리가 지금 봉인한 워킹트리의 트리와 다르면(merge_base · stale 봉인) 죽는다. create-sandbox · mutation-guard 는 plugin-audit 가 쓰므로 남긴다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4b
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---
### Task 5: 공개 인자 — 제거 인자는 한 줄 공지 후 진행 · `--paths` · `--gc` (AC1 · §6.5.2 · R-AE)

**Files:**
- Modify: `plugins/quality-gates/scripts/setup-qg.sh` · `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md`
- Test: `plugins/quality-gates/tests/test_setup_qg.sh` · 인벤토리의 `Task=5` 행

**Interfaces:**
- Consumes: 없음
- Produces:
  - 제거 인자 공지 한 줄(인자마다, stdout): ``> [quality-gates] `<인자>` 인자는 제거됐다 — 이제 한 파이프라인이라 게이트 범위를 고르지 않는다. 그대로 진행한다.`` — Task 7 SKILL 이 이 문장을 인용한다
  - 상태 파일 frontmatter 에서 `runtime_max_resolutions` 가 사라진다

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `test_setup_qg.sh`:

1. Case 1 의 `assert "state contains runtime_max_resolutions default 3" …` 줄을 이것으로:

```bash
assert "state has no runtime_max_resolutions (해소 루프 제거)" "! grep -q 'runtime_max_resolutions' '$STATE_FILE'"
```

2. Case 3 · 3b(클램프 · 비숫자)를 지우고 이것으로 바꾼다 — 스위치가 사라졌으면 읽는 자리도 없다:

```bash
# --- Case 3: DEVBREW_QUALITY_GATES_RUNTIME_MAX_RESOLUTIONS 는 더 읽히지 않는다 (대상 소멸) ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="test-maxres-$$"
unset CLAUDE_CODE_SESSION_ID
DEVBREW_QUALITY_GATES_RUNTIME_MAX_RESOLUTIONS=99 "$SCRIPT" --session-id "$SID" >/dev/null 2>err
STATE_FILE=".claude/quality-gates/$SID/pipeline.md"
assert "옛 해소 루프 스위치는 상태에 흔적이 없다" "! grep -q 'runtime_max_resolutions' '$STATE_FILE'"
assert "옛 해소 루프 스위치에 경고도 없다(읽는 자리가 없다)" "! grep -q 'RUNTIME_MAX_RESOLUTIONS' err"
cd / && rm -rf "$TMPDIR"
```

3. Case 6 을 통째로 지우고 둘을 더한다:

```bash
# --- Case 6: 제거된 인자 넷 — 한 줄 공지 후 정상 진행 (AC1 · 설계 §6.5.2) ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
unset CLAUDE_CODE_SESSION_ID
for a in review runtime both --skip-runtime; do
  "$SCRIPT" "$a" --session-id "test-rm-${a#--}-$$" >out 2>err
  RC=$?
  assert "'$a' exits 0 (정상 진행)" "test '$RC' -eq 0"
  assert "'$a' 는 제거 공지를 정확히 한 줄 낸다" "test \"\$(grep -c '인자는 제거됐다' out)\" -eq 1"
  assert "'$a' 의 공지가 그 인자를 이름으로 댄다" "grep -qF -- '\`$a\`' out"
  assert "'$a' 는 Unknown argument 가 아니다" "! grep -qi 'Unknown argument' err out"
done
# 양의 짝 — 제거 인자가 없으면 공지도 없다(「언제나 공지」 변이를 막는다)
"$SCRIPT" --session-id "test-plain-$$" >out 2>err
assert "제거 인자가 없으면 공지가 없다" "! grep -q '인자는 제거됐다' out"
cd / && rm -rf "$TMPDIR"

# --- Case 7: 제거 인자 + 존치 인자 (Review Focus 2) · --paths · --gc (R-AE, 선재 결함) ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
unset CLAUDE_CODE_SESSION_ID
"$SCRIPT" review --paths 'src/*' 'lib/*' --session-id "test-rp-$$" >out 2>err
RC=$?
assert "'review --paths …' exits 0" "test '$RC' -eq 0"
assert "'review --paths …' 의 공지는 review 하나뿐이다" "test \"\$(grep -c '인자는 제거됐다' out)\" -eq 1"
"$SCRIPT" --paths 'src/*' --session-id "test-p-$$" >/dev/null 2>err
RC=$?
assert "'--paths' 단독이 Unknown argument 로 죽지 않는다" "test '$RC' -eq 0 && ! grep -qi 'Unknown argument' err"
"$SCRIPT" --paths --session-id "test-pe-$$" >/dev/null 2>err
RC=$?
assert "'--paths' 뒤에 glob 이 없으면 exit 1" "test '$RC' -eq 1"
"$SCRIPT" branch review --session-id "test-br-$$" >out 2>&1
RC=$?
assert "'branch review' 는 review 를 브랜치 이름으로 삼키지 않고 공지한다" "test '$RC' -eq 0 && grep -qF -- '\`review\` 인자는 제거됐다' out"
"$SCRIPT" --gc --session-id "test-gc-$$" >/dev/null 2>err
RC=$?
assert "'--gc' 가 setup 에 와도 죽지 않는다(qg.md 가 GC 후 setup 을 부른다)" "test '$RC' -eq 0"
cd / && rm -rf "$TMPDIR"
```

- [ ] **Step 2: 실패를 확인한다** — `bash plugins/quality-gates/tests/test_setup_qg.sh 2>&1 | grep -E '✗'` — Case 1 · 3 · 6 · 7 이 RED.

- [ ] **Step 3: `setup-qg.sh` 를 고친다**

(a) 인자 변수 블록을 이것으로(`SINGLE_GATE` · `SKIP_RUNTIME` · `GATE_BOTH` 가 사라진다):

```bash
REMOVED_ARGS=""
PLAN_FILE="auto"
PR_URL=""
ENSURE_MODE="false"
SESSION_ID=""
BRANCH_MODE="false"
TARGET_BRANCH=""
```

(b) 루프의 `review|runtime)` · `both)` · `--skip-runtime)` 세 arm 을 하나로 합치고, `--paths` · `--gc` arm 을 더한다:

```bash
    review|runtime|both|--skip-runtime)
      # 제거된 인자 — 한 파이프라인이라 고를 게이트가 없다. 조용히 무시하지 않고
      # 아래 출력에서 한 줄씩 알린 뒤 정상 진행한다(설계 §6.5.2).
      REMOVED_ARGS="$REMOVED_ARGS $1"
      shift
      ;;
    --paths)
      # 스코프 override 는 SKILL 이 $ARGUMENTS 에서 직접 읽는다 — 여기서는 소비만 한다.
      shift
      if [[ $# -eq 0 ]] || [[ "$1" =~ ^-- ]]; then
        echo "❌ Error: --paths requires at least one glob" >&2
        exit 1
      fi
      while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]] && [[ ! "$1" =~ ^(review|runtime|both|branch)$ ]]; do
        shift
      done
      ;;
    --gc)
      # qg.md 가 GC 를 이미 돌렸다 — setup 은 무시한다.
      shift
      ;;
```

`branch)` arm 의 peek 정규식 `^(review|runtime|both)$` 는 **그대로 둔다** — `branch review` 에서 `review` 가 브랜치 이름으로 삼켜지지 않고 제거 인자 공지로 간다.

(c) help 텍스트를 이것으로:

```text
Quality Gates Pipeline Setup

USAGE:
  /qg [branch [<name>]] [OPTIONS]

ARGUMENTS:
  branch [<name>]      Review the full branch diff (with <name>: in an isolated worktree)
  (none)               Review git-derived changes (branch + worktree)

OPTIONS:
  --paths <glob>...    Scope override — review only the matched paths
  --plan <path>        Specify plan file path (default: auto-detect)
  --pr-url <url>       Specify PR URL
  --session-id <id>    Override session ID (defaults to CLAUDE_CODE_SESSION_ID)
  --ensure             Idempotent mode: no-op if state from this session
                       already exists (used by skill preflight, not /qg).
  -h, --help           Show this help message

REMOVED (v9): review · runtime · both · --skip-runtime — one pipeline, no gate
  scope to choose. Passing one prints a one-line notice and the run proceeds.

PIPELINE:
  scope → differential test → reviewers → re-critique → verdict
  (clean · defect · not-certified (<reason>))

STOPPING:
  Use /cancel-qg to cancel an active pipeline
```

(`REMOVED (v9)` 의 `v9` 는 사람이 읽는 안내다 — 락은 이 숫자를 재지 않는다. Task 11 이 머지 직전 번호를 정하면 그 major 로 맞춘다.)

(d) `# --- Validate DEVBREW_QUALITY_GATES_RUNTIME_MAX_RESOLUTIONS …` 블록 전체(주석 두 줄 + `runtime_max=` 부터 `fi` 까지)를 지우고, 상태 파일 heredoc 의 `runtime_max_resolutions: $runtime_max` 줄을 지운다.

(e) `# --- Output Setup Message ---` 의 `if [[ -n "$SINGLE_GATE" ]]; then … fi` 블록 전체를 이것으로:

```bash
echo "🔄 Quality Gates Pipeline"
echo ""
echo "Pipeline: scope → differential test → reviewers → re-critique → verdict"
for a in $REMOVED_ARGS; do
  echo "> [quality-gates] \`${a}\` 인자는 제거됐다 — 이제 한 파이프라인이라 게이트 범위를 고르지 않는다. 그대로 진행한다."
done
```

(`${a}` 는 중괄호로 쓴다 — bash 3.2 는 `$a` 바로 뒤의 비ASCII 글자 바이트를 변수 이름으로 먹는다.)

(f) `state-file-format.md` 에서 `runtime_max_resolutions` 를 설명하는 줄(과 그 표 행)을 지운다. `## History` 줄 형식이 `Review gate iter N:` 를 쓰면 `qg iter N:` 로 바꾼다(Task 7 SKILL Step 5 가 같은 형식을 쓴다).

- [ ] **Step 4: 통과 확인**

```bash
cd "$(git rev-parse --show-toplevel)"
bash -n plugins/quality-gates/scripts/setup-qg.sh && echo "OK 구문"
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_setup_qg.sh 2>&1 | tail -3
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p 'test_kill_switches.py' 2>&1 | tail -2
bash "$CLAUDE_JOB_DIR/tmp/run-suite.sh" "$CLAUDE_JOB_DIR/tmp/t5.tsv"
```

**기대** — `test_setup_qg.sh` 실패 0 · `test_kill_switches.py` OK · `run-suite` 는 기준선과 행 단위로 대조. 인벤토리의 `Task=5` 행 중 다른 락(`test_qg_publish_handoff.sh` · `test_cancel_qg*.sh` 등이 setup 출력의 `Full Pipeline` · `Single Gate Mode` 문자열을 재면)은 여기서 새 출력으로 `retarget` 한다.

- [ ] **Step 5: 커밋**

```bash
cd "$(git rev-parse --show-toplevel)"
git add plugins/quality-gates/scripts/setup-qg.sh plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md
git add -u plugins/quality-gates/tests
git status --short
git commit -m "feat(qg)!: 게이트 범위 인자 넷 제거 — 한 줄 공지 후 그대로 진행" \
  -m "review · runtime · both · --skip-runtime 은 이제 고를 것이 없다. 조용히 무시하지 않고 인자마다 한 줄을 낸 뒤 정상 진행한다. 해소 루프가 사라져 RUNTIME_MAX_RESOLUTIONS 도 읽지 않는다. 존치를 선언한 --paths 가 setup 에서 Unknown argument 로 죽던 선재 결함과 --gc 도 함께 닫는다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4b
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 6: `test-scope-validator` — `ac_coverage` 제거 · verifier 언급 이주 (§6.5.1 7행 「축소」)

> **persona 편집이다 — 보안-민감.** 이 Task 는 규칙을 약화하지 않는다: 출력 블록 하나(`ac_coverage`, advisory)를 빼고 이미 사라지는 agent 의 이름을 고친다. 분류 축(spec AC 가 1차 · plan 이 보조)은 그대로다. PR 본문의 보안 리뷰 요청 절에 이 Task 를 적는다(Task 11).

**Files:**
- Modify: `plugins/quality-gates/agents/test-scope-validator.md`
- Test: `plugins/quality-gates/tests/test_test_scope_validator_behavior.py` · `plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh` · 인벤토리의 `Task=6` 행

**Interfaces:**
- Consumes: 없음
- Produces: 출력 = `test_scope_verdicts` + `summary` (+ spec 부재 시 진단 한 줄). `ac_coverage` 없음. dispatch 슬롯(`project_dir` · `spec_path` · `plan_path` · `candidate_test_files` · diff)은 **그대로**다.

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `test_test_scope_validator_behavior.py`:
  - `test_ac_coverage_schema_when_spec_present` 를 지우고, 이것으로 바꾼다(스텁 fixture 이름 · 헬퍼는 파일 안의 것을 쓴다 — `required_keys=[…]` 를 쓰는 기존 헬퍼가 있다):

```python
    def test_persona_no_longer_emits_ac_coverage(self):
        """§6.5.1 7행 — spec AC 런타임 검증이 사라지며 ac_coverage 출력도 사라진다.
        분류 축(spec AC 1차)은 그대로다."""
        text = PERSONA.read_text(encoding="utf-8")
        self.assertNotIn("ac_coverage", text)
        self.assertIn("spec_path", text, "spec 은 여전히 1차 분류 축이다(양의 짝)")
```

  (`PERSONA` 가 파일에 없으면 상단에 `PERSONA = Path(__file__).resolve().parents[1] / "agents" / "test-scope-validator.md"` 를 더한다.)
  - `test_fallback_omits_ac_coverage_when_no_spec` 는 전제가 보편이 됐다 — `delete`(규칙을 잇는 자리 = 위 케이스).
  - `test_test_scope_validator_frontmatter.sh` 가 description 의 `Runtime gate Step 2.5` · `ac_coverage` 를 재면 인벤토리 행대로 `retarget`.

- [ ] **Step 2: 실패를 확인한다** — `python3 -m unittest discover -s plugins/quality-gates/tests -p 'test_test_scope_validator_behavior.py'` 에서 새 케이스가 RED.

- [ ] **Step 3: persona 를 고친다** — `agents/test-scope-validator.md`:

| 자리 | 옛 | 새 |
|---|---|---|
| frontmatter description 첫 문장 | `Light-weight pre-execution check (Runtime gate Step 2.5 of the quality-gates` … | `Light-weight pre-execution check (differential test Step R1b of the quality-gates` … |
| description 의 `<example>` | `Context: Runtime gate Step 2.5 — …` · `… YAML block (plus an advisory ac_coverage block when a spec is found)."` | `Context: differential test Step R1b — …` · `… YAML block."` |
| 제목 | `# Test Scope Validator Agent (Runtime gate Step 2.5)` | `# Test Scope Validator Agent (differential test Step R1b)` |
| 역할 문단 | `…runs *before* \`runtime-verifier\` executes test suites.` · `…never blocks the Runtime gate.` | `…runs *before* the orchestrator runs the selected tests on the baseline and HEAD trees.` · `…never blocks the pipeline.` |
| NOT responsible 문단 | `Test execution is \`runtime-verifier\`'s job (Step 3); … quality and security judgment is the Review gate's territory.` | `Test execution is the orchestrator's (differential test R4 · R5b); … quality and security judgment is the reviewers' territory.` |
| 입력 `spec_path` 설명 | `… When present, you also emit an \`ac_coverage\` block (Step 3.5).` | 그 문장 삭제 |
| `## Step 3.5: Spec AC coverage …` 절 | `ac_coverage` 블록 스키마 · 설명 | 절을 이것으로 바꾼다(아래) |
| 끝 문단 | `…after the Runtime gate completes.` | `…after the pipeline completes.` |

`## Step 3.5` 절의 새 본문:

```markdown
## Step 3.5: No-spec fallback (loud)

If `spec_path` is absent or the literal `none`, classify against the plan items
and the diff only, and emit exactly one diagnostic line as prose BEFORE your YAML
block:

> `[test-scope-validator] no spec found (spec_path absent) — per-file scope is plan-based only.`

Emit nothing else about the spec — there is no per-AC coverage output.
```

(옛 진단 문장의 `— AC coverage skipped;` 와 `(v2.0.0 behavior)` 는 사라진다 — 가리키던 출력이 없다. 이 문장을 재는 락이 있으면 인벤토리 행대로 `retarget`.)

```bash
cd "$(git rev-parse --show-toplevel)"
grep -nE 'ac_coverage|runtime-verifier|Runtime gate|Review gate|Step 2\.5' plugins/quality-gates/agents/test-scope-validator.md || echo "OK persona 깨끗"
```

- [ ] **Step 4: 통과 확인**

```bash
cd "$(git rev-parse --show-toplevel)"
export PYTHONDONTWRITEBYTECODE=1
python3 -m unittest discover -s plugins/quality-gates/tests -p 'test_test_scope_validator*.py' 2>&1 | tail -2
for t in plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh plugins/quality-gates/tests/test_agent_frontmatter_keys.sh \
         plugins/quality-gates/tests/test_agent_tools_lock_differential.sh shared/tests/test_agent_input_slots.sh; do
  printf '%s ' "$t"; bash "$t" 2>&1 | grep -cE '^[[:space:]]*✗|^FAIL:'
done
```

**기대** — 전부 0. `shared/tests/test_agent_input_slots.sh` 는 슬롯이 그대로라 GREEN 이어야 한다(바뀌면 이 Task 가 슬롯을 건드린 것이다 — 되돌린다).

- [ ] **Step 5: 커밋**

```bash
cd "$(git rev-parse --show-toplevel)"
git add plugins/quality-gates/agents/test-scope-validator.md
git add -u plugins/quality-gates/tests
git status --short
git commit -m "refactor(qg): test-scope-validator 의 ac_coverage 출력 제거 · verifier 언급 이주" \
  -m "spec AC 런타임 검증이 사라지며 advisory ac_coverage 블록도 사라진다(설계 §6.5.1 7행 축소). spec AC 가 1차 분류 축인 것은 그대로다. persona 편집 — 보안 리뷰 대상." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4b
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 7: 한 파이프라인 — SKILL 재작성 · 차등 테스트 레퍼런스 · verifier 제거 (한 커밋)

> 이 Task 는 **한 커밋**이다. `runtime-verifier` 의 dispatch 블록(레퍼런스)과 그 agent 정의는 같은 커밋에서 사라져야 한다 — 따로 가면 `shared/tests/test_dispatch_disposition.sh` 가 「어디서도 dispatch 되지 않는 agent」로 RED 다(§12). 판정 배선(`--emit-verdict` · `--angles`)은 **Task 8** 이다 — 이 Task 의 Step 4.5 는 오늘의 판정 논리(counts 줄 · not-clean 마커 · 정직-verdict floor)를 이름만 바꿔 유지한다.

**Files:**
- Move: `plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md` → `references/differential-test.md` (`git mv`)
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` · `references/differential-test.md` · `plugins/quality-gates/commands/qg.md` · `plugins/quality-gates/tests/lib/reconstruct-skill.sh` · `plugins/quality-gates/scripts/check-allowed-tools-order.sh` · `tools/adjudication/check_slots.py`(주석 bullet)
- Delete: `plugins/quality-gates/agents/runtime-verifier.md` · `plugins/quality-gates/scripts/detect-runtime.sh` · 인벤토리의 `Task=7` · `delete-file` 테스트
- Create: `plugins/quality-gates/tests/test_one_pipeline_surface.sh`
- Test: 인벤토리의 `Task=7` 행 전부(하네스 · `test_runtime_contract_invariance.sh` 의 남은 행 · reconstruct 소비자 · `test_check_allowed_tools_order.sh` …)

**Interfaces:**
- Consumes: Task 3 의 두 머리줄 문자열 · Task 4 의 `seal-worktree.sh seal <sid>` · `create-head <sealed-sha> <sid>` · Task 5 의 제거 인자 공지 문장
- Produces (Task 8 이 쓴다):
  - SKILL 절 이름: `## Pipeline` · `## Trivia escape` · `## Review`(Step 1 · 1b · **1c** · 2 · 3 · Phase 1.5 · 4 · 4.5 · 5) · `## Angles and reviewers (scope-driven)` · `## Differential test` · `## Final Summary` · `## kill switch` · `## Rules`
  - 레퍼런스 스텝 집합 = `R-init R1a R1b R2 R3 R4 R5b R6 R8` · 머리 헤딩 `## Differential test`
  - R8 끝 문장: 「판정은 여기서 내지 않는다」(Task 8 이 그 아래에 판정 입력 표를 단다)

- [ ] **Step 1: 실패하는 표면 락을 쓴다** — `plugins/quality-gates/tests/test_one_pipeline_surface.sh` (`chmod +x`):

```bash
#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/quality-pipeline/references/differential-test.md plugins/quality-gates/commands/qg.md
# test_one_pipeline_surface.sh — 한 파이프라인의 표면 (설계 §6.1 · §6.4.4 · §6.5.1, AC1 · AC2).
#
# 음의 락(옛 게이트 · verifier 토큰 부재)은 대상을 통째로 지워도 GREEN 이다 — 그래서 양의
# 짝(새 골격의 존재 · 스텝 집합 · 순서)을 함께 둔다. 코퍼스는 오케스트레이터가 읽는 세 파일이다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
REF="$PLUGIN_ROOT/skills/quality-pipeline/references/differential-test.md"
QGMD="$PLUGIN_ROOT/commands/qg.md"

case_old_surface_absent() {
  # 파일 단위 제외 없이 — 이 세 파일에 이 토큰이 설 자리는 없다(설계 §6.4.4 일곱 · §6.5.1).
  local tok f
  for tok in 'runtime-verifier' 'detect-runtime' 'create-sandbox' 'mutation-guard' \
             'effective_skip_runtime' 'block_policy' 'approved_surfaces' 'resolution_iter' \
             'NEEDS_RESOLUTION' 'SKIP_WITH_EVIDENCE' 'Decision [12]' \
             'RUNTIME_MAX_RESOLUTIONS' 'DISABLE_RUNTIME_SANDBOX' 'Runtime gate' \
             'Review gate' 'runtime-gate\.md' 'Tier [ABC]' 'ac_coverage' \
             '(^|[^A-Za-z_])PASS([^A-Za-z_]|$)' '(^|[^A-Za-z_-])FAIL([^A-Za-z_:]|$)'; do
    for f in "$SKILL" "$REF" "$QGMD"; do
      assert_file_absent "$f" "$tok" "$(basename "$f") 에 '$tok' 이 없다"
    done
  done
}

case_new_skeleton_present() {
  assert_file_grep "$SKILL" '^## Pipeline$'                         "SKILL 에 파이프라인 절이 있다"
  assert_file_grep "$SKILL" '^## Differential test$'                "SKILL 에 차등 테스트 포인터 절이 있다"
  assert_file_grep "$SKILL" 'references/differential-test\.md'      "포인터가 새 레퍼런스를 가리킨다"
  assert_file_grep "$SKILL" '^\*\*Step 1c '                         "Review 절에 ② 의 자리(Step 1c)가 있다"
  assert_file_grep "$REF"   '^## Differential test$'                "레퍼런스 머리 헤딩(스플라이스 앵커)"
  assert_file_grep "$REF"   'scripts/seal-worktree\.sh" seal'       "HEAD 축은 봉인에서 선다"
  assert_file_grep "$REF"   'scripts/qg-worktree\.sh" create-head'  "HEAD 축 트리를 만든다"
  assert_file_grep "$REF"   'scripts/qg-worktree\.sh" create-baseline' "기준선 축 트리를 만든다"
  assert_file_grep "$REF"   'scripts/diff-test-results\.py" --aggregate' "어댑터 집계가 남아 있다"
  assert_file_grep "$REF"   'scripts/check_qa_ledger\.py"'          "원장 구조 게이트가 남아 있다(R-AG)"
}

case_reference_step_set() {
  # 살아남는 스텝 전부 · 지워진 스텝 없음 — 헤딩에서 도출해 핀과 대조한다(∀).
  local got
  got=$(grep -oE '^\*\*Step R[-0-9a-z]+' "$REF" | sed 's/^\*\*Step //' | LC_ALL=C sort -u | tr '\n' ' ')
  assert_eq "$got" "R-init R1a R1b R2 R3 R4 R5b R6 R8 " "레퍼런스의 스텝 집합(R5a · R7 · R9 없음)"
}

case_pipeline_order() {
  # 설계 §6.1 — ② 가 ③ 보다 앞(load-bearing). 파이프라인 절 안에서 ①→⑤ 가 이 순서로 처음 나온다.
  local body prev=0 n m good=1
  body=$(awk '/^## Pipeline$/{f=1;next} f&&/^## /{exit} f' "$SKILL")
  for m in ① ② ③ ④ ⑤; do
    n=$(printf '%s\n' "$body" | grep -n "$m" | head -1 | cut -d: -f1)
    if [ -z "$n" ] || [ "$n" -le "$prev" ]; then good=0; fi
    prev=${n:-0}
  done
  assert_eq "$good" "1" "파이프라인 절이 ①→②→③→④→⑤ 순서로 적혀 있다"
}

case_no_gate_scope_question() {
  # AC1 — 게이트 범위를 묻는 결정 도구가 없다. 결정 도구 리터럴의 header 전수에서 도출한다.
  local headers
  headers=$(grep -oE 'header: "[^"]*"' "$SKILL" "$REF" | sed 's/.*header: //' | LC_ALL=C sort -u | tr '\n' ' ')
  assert_not_grep "$headers" 'Gate scope|Runtime scope|Runtime resolve' "게이트 · 런타임 범위 질문이 없다"
  assert_grep     "$headers" 'qg iter N'                              "fix-loop 결정 도구는 남아 있다(양의 짝)"
}

for c in case_old_surface_absent case_new_skeleton_present case_reference_step_set \
         case_pipeline_order case_no_gate_scope_question; do
  "$c"
done
finish
```

`assert_not_grep` · `assert_file_absent` · `finish` 가 `shared/tests/assert.sh` 에 있는지 먼저 확인한다(`grep -n '^assert_not_grep\|^assert_file_absent\|^finish' shared/tests/assert.sh`). 없으면 **BLOCKED** — `shared/` 는 이 PR 에서 바뀌지 않는다.

- [ ] **Step 2: 실패를 확인한다** — `bash plugins/quality-gates/tests/test_one_pipeline_surface.sh 2>&1 | grep -cE '✗'` 가 0 보다 크다(레퍼런스 파일이 아직 없어 `assert_file_grep` 이 「파일 없음」으로 RED).

- [ ] **Step 3: 레퍼런스를 옮기고 고친다**

```bash
cd "$(git rev-parse --show-toplevel)"
git mv plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md \
       plugins/quality-gates/skills/quality-pipeline/references/differential-test.md
```

`differential-test.md` 를 아래 순서로 고친다. **각 편집 뒤 그 자리를 재는 인벤토리 행을 같이 처리한다.**

**(a) 머리 — 첫 줄 `## Runtime gate` 부터 `**Step R-init` 직전까지**를 이것으로:

```markdown
## Differential test

이 절차는 **이번 변경의 영향분**을 골라 기준선 대비로 돌린다. 모델이 *무엇을 돌릴지*
한 번 고르고, 그 선택을 결정론이 기준선 · HEAD 양쪽에서 두 번 실행해 짝짓는다 —
귀속(이 fail 은 내 탓인가)과 백스톱(결과가 조용히 비었나)이 같은 메커니즘에 얹힌다.

> **호출 주체 불변식 (load-bearing).** `run-test-selection.sh` 는 기준선 측(R4)과
> HEAD 측(R5b) **둘 다 오케스트레이터가 직접** 호출한다. 어떤 subagent 도 테스트를
> 돌려 결과를 보고하지 않는다 — 판정 입력은 이 스크립트의 오케스트레이터 호출 결과뿐이다.
>
> **두 호출은 각자의 트리에서 돈다.** 기준선 측은 `create-baseline` 이 기준선 커밋에,
> HEAD 측은 `create-head` 가 봉인 커밋(`seal-worktree.sh`)에 detached 로 만든 일회용
> 트리다. 두 축 모두에서 실행되는 것은 어댑터의 `setup_cmd` 뿐이다 — 대칭이 구조적이다.
```

**(b) 판정값 어휘를 문서 전체에서 옮긴다** — 이 레퍼런스는 판정을 **내지 않는다**(판정은 Task 8 이 합성기로 넘긴다). 아래 표는 문구 치환이지 의미 변경이 아니다:

| 옛 문구(판정값으로 쓰인 자리) | 새 문구 |
|---|---|
| `verdict 는 PASS 불가` · `PASS 불가` · `verdict 를 PASS 로 올리지 않는다` · `PASS 로 올리지 않는다` | `clean 불가` |
| `PASS 가능` · `PASS 적격` | `clean 가능` |
| 귀속 사슬 서술의 `→ **PASS**` · `→ PASS` · `PASS 행` | `→ **clean**` · `clean` |
| `(≤\`SKIP_WITH_EVIDENCE\`)` · `≤SKIP_WITH_EVIDENCE` | 지운다 |
| 판정값으로 쓰인 `FAIL` · `terminal FAIL` · `거짓 terminal FAIL` | `defect` · (verifier 서술이면 문장째 지운다) |
| 판정값으로 쓰인 `SKIP` · `SKIP_WITH_EVIDENCE` | `not-certified` |
| `Runtime 게이트` · `이 게이트` · `the Runtime gate` | `차등 테스트` |

테스트 상태값 소문자(`pass` · `fail` · `error` · `unrun` · `absent`)와 귀속 카테고리(`NEW_REGRESSION` · `PRE_EXISTING` · …)는 **바꾸지 않는다** — 차등 기계의 어휘다.

**(c) verifier · 샌드박스 서술을 지운다** — 규칙:
1. `runtime-verifier` · `verifier` · `샌드박스` · `sandbox` · `R5a` · `R7` · `R9` · `mutation-guard` · `폴백(샌드박스 비활성)` · `DISABLE_RUNTIME_SANDBOX` 를 담은 **문장**은 지우거나, 규칙이 남으면 주어를 「저장소가 통제하는 코드(`setup_cmd` · `run` · flaky 재실행)」로 바꾼다.
2. **이력만** 담은 문단(「앞 버전은…」 · 「세 판본은…」 · 「(/qg iter-N …)」 괄호 · 「앞선 판본은…」)은 지운다. 행동 규칙이 섞여 있으면 규칙 문장만 남긴다.
3. 락 인벤토리가 그 문단의 리터럴을 재면 그 행의 처분을 따른다(`delete` 면 「규칙을 잇는 자리」가 남아 있는지 확인한다).

구체적으로 확정된 자리:

- **R-init 펜스의 오류 문장 다섯** — `verdict 는 PASS 불가` → `clean 불가`. TMPDIR 담김 문장의 `중간 파일이 커밋 B 로 봉인되거나 피검자에게 노출됩니다` → `중간 파일이 봉인(HEAD 축)에 들어갑니다`.
- **R-init 의 「기준은 `$project_dir` 이 아니라 저장소 최상위다」 문단** — `create-sandbox` 를 `seal-worktree.sh` 로 바꾼다: `seal-worktree.sh 는 main_root=$(git rev-parse --show-toplevel) 를 독립적으로 구해 거기서 git add -A 로 봉인한다 — 가드가 재는 집합과 실제로 봉인되는 집합이 같아야 한다.` 줄번호 인용(`qg-worktree.sh:148-150` 등)은 지운다.
- **R-init 의 custody 표** — 이것으로 바꾼다:

```markdown
| | 파일 | 기록 → 소비 사이에 저장소 코드가 도는가 |
|---|---|---|
| **창 있음** | `$qg_run_tmp/assign-rows.tsv` | R1b 기록 → R8 소비. 창은 R4 에서 열린다 |
| | `$qg_run_tmp/expected-$runner.txt` | R5b 기록 → R6 소비. **`SILENT_DROP` 백스톱의 원본** |
| | `$qg_run_tmp/baseline-$runner.tsv` | R4 기록 → R6 소비. **가장 나쁘다** — 행을 `pass`→`fail` 로 뒤집으면 모든 `NEW_REGRESSION` 이 `PRE_EXISTING` 으로 접힌다 |
| | `$qg_run_tmp/head-$runner.tsv` | R5b 기록 → R6 소비. 사이에 R6 의 flaky 재실행이 `$head_tree_dir` 에서 저장소 코드를 돌리고 같은 파일에 행을 다시 쓴다 |
| | `$qg_run_tmp/per-adapter-$runner.yaml` | R6 어댑터별 기록 → R6 말미 `--aggregate` 소비. 사이에 같은 flaky 재실행 |
| **창 없음** | `$qg_run_tmp/aggregate.yaml` | R6 말미 기록 → R8 소비. 사이에 저장소 코드가 돌지 않는다 |
```

  그 표 위아래의 「`runtime-verifier` 의 쓰기 범위 안에 있다」 · 「시계를 바로잡는다 — 창의 단위는 "verifier 턴"이 아니다」 · 「`aggregate.yaml` 의 "창 없음" 은 조건부다 … R7 …」 문단은 지운다. 「이 축은 §6.7 S1(잔여 결함)이며 **열려 있다**」 문단은 **남긴다**(열린 잔여의 공시다).
- **R-init 의 「`$evidence_dir` 은 별도 금지가 아니다」 문단** — 지운다(`$evidence_dir` 은 이제 R8 이 정의한다).
- **R4 의 「폴백(샌드박스 비활성)에서도 이 스텝 전체를 건너뛴다」 문단** — 통째로 지운다.
- **R4 의 「판별자를 여기서 직접 구한다」 문단과 그 펜스** — 이것으로: `판별자는 Review Step 1b 가 캐시한 \`worktree_dirty\` · \`degraded\` 다(② 는 매 iteration Step 1b 뒤에 돈다).` 그 아래 판별 표는 남긴다.
- **R4 ① 캐시 문단** — `runtime-verifier 는 무제한 Bash 로 그 형제 디렉토리에 쓰라고 지시받는다. 게다가` 를 지우고 문장을 `run 은 저장소가 통제하는 코드를 호스트 권한으로 돌리므로 리뷰 대상 저장소의 평범한 테스트가 캐시 경로를 계산해 쓸 수 있다.` 로 시작한다. 「봉인(digest)을 쓰지 않는 이유」의 `파일에 둔 비밀은 verifier 의 Bash 가 읽는다` → `파일에 둔 비밀은 저장소 코드가 읽는다`.
- **R4 ② 문단들의 `verifier 의 Bash 와`** — 지운다.
- **「R4 가 R5 보다 먼저인 이유」 문단** — 이것으로: `**R4 가 R5b 보다 먼저인 이유** — 기준선 실행이 HEAD 축과 **다른 트리에서** 끝나야 한다. 같은 트리에서 코드를 되감았다 복원하면 두 축이 같은 환경이라는 전제가 흐려진다.`

**(d) `**Step R5a⁰` 부터 R5a³ 의 `Agent({…})` 블록 끝(`})` 다음 빈 줄)까지 통째로 지운다.**

**(e) R5b 를 다시 쓴다** — `**Step R5b —` 줄부터 「그다음 어댑터마다」 직전까지를 이것으로:

````markdown
**Step R5b — HEAD 측 테스트 실행 (오케스트레이터가 직접).**

먼저 워킹트리를 **봉인**하고(한 번, 어댑터 공통) 그 봉인 커밋에서 **HEAD 축 전용 트리**를
만든다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
sealed=$("$QG/scripts/seal-worktree.sh" seal "<session-id>") || sealed=""
head_tree_dir=""
if [ -n "$sealed" ]; then
  head_tree_dir=$("$QG/scripts/qg-worktree.sh" create-head "$sealed" "<session-id>") || head_tree_dir=""
fi
printf 'sealed=%s\nhead_tree_dir=%s\n' "$sealed" "$head_tree_dir"
```

`$sealed` 와 `$head_tree_dir` 를 오케스트레이터 변수로 붙잡아 R6 까지 들고 간다. `create-head`
는 인자의 트리가 **지금 다시 뜬 봉인의 트리**와 같은지 대조하고 다르면 죽는다 — `$merge_base`
나 앞 iteration 의 봉인을 넘기면 거부된다. 봉인과 `create-head` 사이에 워킹트리를 바꾸지
않는다.

**봉인은 워킹트리 전체다** — 수정 · 삭제 · untracked(무시되지 않은 것)가 전부 HEAD 축에
든다. 임시 인덱스는 `.git` 안이라 봉인 트리에 들어가지 않는다(AC14).
````

  그다음 「그다음 어댑터마다 (샌드박스가 있을 때만):」 의 `(샌드박스가 있을 때만)` 을 지운다. 「폴백(샌드박스 비활성)에서도 이 두 파일은 쓴다」 문단 · 「이 호출은 R5a³ 의 `Agent({…})` 블록 **밖**에 있어야 한다」 문단을 지운다. 「HEAD 축 트리는 여기서 폐기하지 않는다 — R6 끝까지 살려 둔다」 문단은 첫 두 문장(R6 의 flaky 재실행이 `$head_tree_dir` 에서 돈다)만 남긴다.

**(f) R5b 실패 라우팅 표** — 첫 행을 이것으로 바꾸고, 표 아래 「이 표가 없던 판본에서는…」 문단은 **한 문장만** 남긴다(나머지는 이력 · verifier):

```markdown
| `seal-worktree.sh` 가 non-zero(`$sealed` 빈 값) · 또는 `create-head` 가 non-zero(`$head_tree_dir` 빈 값) | **HEAD 축을 관측하지 못했다.** stderr 를 verbatim 노출하고, 선택한 unit 마다 `<unit>\tunrun\t-` 로 HEAD 행을 채운 뒤 `verification` 을 **`degraded`** 로 두고 R6 으로 간다. 실제 워킹트리(`$project_dir`)로 **폴백하지 않는다** — 두 축의 환경 대칭이 깨진다. |
```

  남기는 한 문장: `행 부재의 귀속 카테고리 이름을 이 창에 리터럴로 적지 않는다 — 이 창에 그 토큰이 0회여야 한다는 회귀 락이 있다.`

**(g) R6** — 「R7 은 `sandbox_dir` 만 검사하므로…」 문단을 지운다. flaky 문단의 「**어느 트리인지가 이 문장의 load-bearing 부분이다.** …」 를 이것으로: `**재실행은 \`$head_tree_dir\` 에서만 한다** — 실제 워킹트리에서 돌리면 두 축의 환경 대칭이 깨지고, 그 결과가 authoritative 라 진짜 회귀가 강등된다. \`$project_dir\` 는 이 자리에 오지 않는다.` R6 exit-code 표의 둘째 행 조치 칸 끝을 `… 원장의 \`attribution\` 을 **\`degraded\`** 로 적는다. 캡처 실패를 "결함 없음"으로 읽지 않는다.` 로(판정 문구는 (b) 규칙).

**(h) `**Step R7 —` 줄부터 R8 직전까지 통째로 지운다**(Fallback working-tree guard 포함).

**(i) R8 을 다시 쓴다** — 헤딩과 첫 문단을 이것으로:

```markdown
**Step R8 — 원장 + 판정 입력.**

`evidence_dir = "$project_dir/.claude/quality-gates/$CLAUDE_CODE_SESSION_ID/"` 다. 그 아래
`runtime-evidence.md` 에 floor 5차원 원장을 이어 쓴다(없으면 새로 만든다 · spec-distill
커버리지 원장과 같은 줄 모양):
```

  원장 줄 견본 · `degraded` 라우팅 표(「PASS」 칸 → 「clean」 칸) · `unclaimed` 인용 블록 · 구조 게이트 펜스와 그 아래 세 문단(`--aggregate` 필수 · `--assign-rows` 필수 · 개수가 아니라 경로) · 「닫히지 않은 이웃」 문단 · bulk 공시 문단은 **남긴다**((b) 규칙만 적용). **지우는 것**: `verdict 결정:` 표 · 「동시 성립 시 총 순서」 펜스와 그 아래 목록 · 「Outcome routing」 목록 전체. R8 을 이 문단으로 끝낸다:

```markdown
**판정은 여기서 내지 않는다.** R6 의 `$aggregate_yaml` 과 두 호출의 exit code,
`check_qa_ledger.py` 의 exit code 를 들고 SKILL 의 Review Step 4 로 간다 — 판정값은
합성기(`verdict.py`)가 정한다.
```

**(j) `**Step R9 —` 줄부터 파일 끝까지 지운다.**

**(k) R1b · R2** — test-scope-validator dispatch 의 `description: "Classify scope-relevant test files (Runtime gate)"` → `(differential test)`. R2 의 투명성 앵커 `> Runtime scope: 영향 테스트 …` → `> Differential scope: 영향 테스트 …`. dispatch 블록의 `**처분**` 줄은 **그대로**(`consumer=orchestrator · fail-open · disclosure=R2 산문`) — `disclosure=` 값 「R2 산문」이 본문에 남아 있는지 본다(`shared/tests/test_dispatch_disposition.sh` 축 C).

```bash
cd "$(git rev-parse --show-toplevel)"
R=plugins/quality-gates/skills/quality-pipeline/references/differential-test.md
git grep -n -P -i 'verifier|sandbox|샌드박스|R5a|\bR7\b|\bR9\b|mutation.guard|SKIP_WITH_EVIDENCE|NEEDS_RESOLUTION|Runtime gate|Runtime 게이트|폴백' -- "$R" || echo "OK 레퍼런스 깨끗"
git grep -n -P '(?<![A-Za-z_])(PASS|FAIL)(?![A-Za-z_:])' -- "$R" || echo "OK 판정값 없음"
```

`-P` 의 `\b` 는 정상 동작한다. 남은 매치는 줄마다 이유를 보고서에 적는다(예: 인용된 스크립트 출력 키).

- [ ] **Step 4: SKILL.md 를 고친다** — 절 단위로.

**(a) frontmatter** — `description:` 을 이것으로:

```yaml
description: >
  Runs the quality-gates pipeline in a single assistant turn. Triggered by
  `/qg`, "run quality gates", "verify my implementation", "check code quality",
  or "is my PR ready to merge". One pipeline, one verdict — scope, a differential
  test against the baseline (always), reviewers per angle, a framing-blind
  re-critique, and synthesis. Fix-loop decisions surface via AskUserQuestion.
  Publishing a PR-understanding comment is a separate explicit step
  (`/qg-publish`) — not part of the pipeline, and not an automatic continuation.
```

`allowed-tools:` 를 이것으로(25 항목 · `verdict.py` 는 Task 8 이 더한다):

```yaml
allowed-tools:
  # Group 1 — Preflight scripts (실행 순서: setup → trivia → 스코프 신호)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-trivia.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-review-scope.sh:*)
  # Group 2 — Differential test scripts (references/differential-test.md)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/resolve-baseline.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/compute-test-scope-candidates.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/baseline-cache.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/seal-worktree.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/diff-test-results.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check_qa_ledger.py:*)
  # 비-플러그인 명령 중 **항목을 가진 유일한 것**. R-init 이 오케스트레이터 소유 중간 파일의
  # 집을 만든다(AC69). 레포 안에 두면 봉인(`seal-worktree.sh` 의 `git add -A`)이 그 파일들을
  # HEAD 축에 넣으므로 반드시 트리 밖이어야 하고, 그러려면 이 한 명령이 필요하다. fenced
  # 블록의 맨 셸 유틸리티(`pwd` · `printf` · `git` …)가 항목을 필요로 하는지는 미측정이다 —
  # 넓은 grant 를 사지 않는다.
  - Bash(mktemp:*)
  # Group 3 — Review scripts (각도 · 재비판 · 합성)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/scout.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/detect_codex.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/run_codex_reviewer.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/recritic_bridge.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/synthesize_findings.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/render-terminal.py:*)
  # Group 4 — Meta (orchestration primitives)
  - Agent
  - AskUserQuestion
  # Group 5 — File operations
  - Read
  - Glob
  - Grep
  - Edit
  - Write
```

`scripts/check-allowed-tools-order.sh` 의 `EXPECTED_ORDER` 를 **같은 순서**로 바꾼다(그룹 주석도 맞춘다 · `mktemp` 위 주석은 이 SKILL 주석의 요지 한 줄로).

**(b) 제목 · 머리 문단 · Law 2 문단 · Contents** — `# Quality Gates — In-Turn Orchestrator (v8.0.0)` 의 **버전은 그대로 둔다**(Task 11 이 bump 와 함께 바꾼다 — 하네스가 제목 major 를 `plugin.json` 과 대조한다). 머리 문단과 Law 2 문단을 이것으로:

```markdown
You are running the **quality-gates pipeline** in a single assistant turn. There is
**one pipeline and one verdict** — no gate scope to choose. At the fix-loop boundary
you call `AskUserQuestion` and branch on the user's response — the response arrives
as a tool result in the same turn, so no Stop hook and no continuation sentinel are
needed.

**Law 2 (Writer ≠ Reviewer):** you are the orchestrator (writer). `security-reviewer`, 재비판(`doc-recritic`), and `test-scope-validator` are read-only reviewers (`tools: Read, Grep, Glob` — fail-closed allowlist). No agent with write access is dispatched. You run the tests yourself — both axes of the differential test, on trees you create — and you may apply user-approved fixes ("Retry" path) via Edit/Write; those are user-consented.
```

`## Contents` 를 이것으로:

```markdown
## Contents

이 SKILL은 단일 어시스턴트 턴 안에서 전체 파이프라인을 실행. 섹션 그룹:

1. **Workflow (top-to-bottom on invocation):**
   - [Preflight](#preflight) — kill switch / setup-qg
   - [Arguments](#arguments) — `/qg` flags 파싱
   - [Pipeline](#pipeline) — ① 스코프 → ② 차등 테스트 → ③ 각도 + 리뷰어 → ④ 재비판 → ⑤ 합성 · 판정, iteration 마다
2. **Steps:**
   - [Trivia escape](#trivia-escape) — one-sentence diff → pipeline skipped
   - [Review](#review) — Step 1 스코프 · 1b 신호 · 1c 차등 테스트 · 2 scout · 3 디스패치 · Phase 1.5 재비판 · 4 합성 · 4.5 판정 표면 · 5 결정
   - [Angles and reviewers (scope-driven)](#angles-and-reviewers-scope-driven) — 각도 셋 + 추가 리뷰어 rubric
   - [Differential test](#differential-test) — 기준선 대비 차등 실행(절차 전문은 레퍼런스)
3. **Decision points (AskUserQuestion templates):**
   - [Fix-loop decision](#fix-loop-decision)
   - [Max-iter decision](#max-iter-decision)
4. **Output templates** — [Final Summary](#final-summary) · [kill switch](#kill-switch) · [Rules](#rules)
```

**(c) `## Arguments` 를 통째로:**

```markdown
## Arguments

Parse from `/qg` invocation:
- `plan_path` (optional): defaults to "auto" (`scripts/discover-plan.sh`).
  A secondary scope hint for `test-scope-validator` (differential test R1b) and
  for the `security-reviewer` / 재비판(doc-recritic) dispatches — not verified,
  only hinted.
- `spec_path` (optional): defaults to "auto" (`scripts/discover-spec.sh`).
  The project spec is the Acceptance Criteria truth — `test-scope-validator`
  classifies test files against it, and the codex path injects its AC into
  `<spec_context>` (script-internal in `run_codex_reviewer.sh`). If
  `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE=1`, pass `spec_path: none` to
  the `test-scope-validator` dispatch. All spec behavior is advisory; it never
  blocks the pipeline.
- `pr_url` (optional).
- `branch [<name>]` (optional): scope override — the full branch diff (with
  `<name>`, in an isolated worktree created by `setup-qg.sh`).
- `paths` (optional, repeatable): scope override — `--paths <glob>...`.

**제거된 인자** — `both` · `review` · `runtime` · `--skip-runtime`. 한 파이프라인이라
고를 게이트 범위가 없다. `setup-qg.sh` 가 인자마다 한 줄
(``> [quality-gates] `<인자>` 인자는 제거됐다 — …``)을 내고 실행은 그대로 진행한다.
그 인자 때문에 질문을 띄우거나 어느 단계를 건너뛰지 않는다.
```

**(d) `## Upfront Execution Plan` 절 전체(Decision 1 · Decision 2 · Cost heads-up 포함)와 `## Dispatch Loop` 절을 지우고 그 자리에:**

```markdown
## Pipeline

한 파이프라인, 한 판정(설계 §6.1):

1. [Trivia escape](#trivia-escape). trivia 면 나머지 전부를 건너뛴다.
2. iteration N = 1..5 — 각 iteration 은 다섯 단계를 이 순서로 돈다:
   - ① **스코프** — [Review](#review) Step 1 · 1b
   - ② **차등 테스트** — Step 1c → [Differential test](#differential-test). **매 iteration 돈다** — iteration 2 이상은 Retry 가 코드를 고친 뒤라, 앞 iteration 의 결과는 다른 트리의 것이다.
   - ③ **각도 + 리뷰어** — Step 2 · 3
   - ④ **재비판** — Phase 1.5
   - ⑤ **합성 · 판정** — Step 4 · 4.5 · 5
3. [Final Summary](#final-summary).

**② 가 ③ 보다 앞인 것이 load-bearing 이다** — 테스트 결과는 실행이 내고, 그 결과가 ③ 에서
누구를 부를지의 입력이 된다(diff 는 피검자가 쓰지만 테스트 결과는 실행이 낸다).
```

**(e) `## Trivia escape`** — 본문을 이것으로(판정 산출은 Task 8):

```markdown
Run `scripts/check-trivia.sh` (plugin root per Step P0b). Exit code:
- 0 = trivia detected → skip the whole pipeline. Print:
  > `Trivia diff — pipeline skipped (one-sentence diff per CLAUDE.md trivia escape).`
- 1 = non-trivia → proceed to iteration 1.
- any other non-zero (script crash / environment failure) → print stderr
  verbatim and abort the pipeline. Do NOT silently treat as non-trivia.
```

**(f) `## Review gate` → `## Review`** — 절 안에서:
- `Iterative fix-loop, \`max_review_iterations = 5\`` 문장은 그대로.
- **Step 1b 다음에** 이 스텝을 더한다:

```markdown
**Step 1c — 차등 테스트 (②).** [Differential test](#differential-test) 절을 따른다 —
매 iteration 돈다. 결과(`$aggregate_yaml` 경로와 R6 두 호출의 exit code ·
`check_qa_ledger.py` 의 exit code)를 Step 4 로 들고 간다. 그 결과를 Step 3 의 추가
리뷰어 선택에 입력으로 쓴다 — 예: `NEW_REGRESSION` 이 난 unit 의 파일을 건드린 diff 에는
`pr-review-toolkit:silent-failure-hunter` 를 더 무겁게 본다.
```

- Step 3 의 Tier 어휘를 각도 어휘로(R-AF): `**Tier A — Floor (스코프 무관, 항상 디스패치; 모델이 스코프 판단으로 뺄 수 없음).**` 문단을 이것으로:

```markdown
   **보안 각도 — `quality-gates:security-reviewer`, 매 iteration.** 스코프 판단으로 빼지
   않는다. 판정 각도(재비판, 아래 Phase 1.5)도 매 iteration 돈다. `tools:` posture
   (`Read, Grep, Glob`, #104 lock) is unchanged. `security-reviewer` MUST include
   `project_dir: "$project_dir"`:
```

  Step 3 첫 문단(「You (orchestrator) select which reviewers to dispatch this iteration from three tiers. …」)을 이것으로:

```markdown
3. **Compose and dispatch the reviewers — per angle (scope-driven).** 세 각도(보안 ·
   판정 · 다른 전제 — [Angles and reviewers](#angles-and-reviewers-scope-driven))마다
   수행자가 정해져 있고, 그 밖의 추가 리뷰어를 스코프로 고른다. 선택은 **model-owned
   routing** 이다(P8 lightness). Re-select every iteration. **No qg-own tool posture
   changes here (#104 lock kept).**
```

  kill switch 문단 안: `Phase 1.5 재비판과 Tier B(codex)·Tier C 는 **그대로 fire 한다**` → `재비판 · codex · 추가 리뷰어는 **그대로 fire 한다**`; 재비판 `findings` 슬롯 문장의 `(Tier C + codex)` → `(codex + 추가 리뷰어)`; 배너 `… (Tier A floor 결손).` → `… (보안 각도 부재).`; 「왜 codex kill switch 와 달리 loud 인가」 문단의 둘째 문장부터를 이것으로: `codex 는 다른 전제 각도라 부재를 공시만 하고 막지 않는다. \`security-reviewer\` 는 보안 각도라 부재가 판정을 막는다 — 사용자의 의도적 opt-out 이더라도 **판정을 읽는 사람**에게 결손이 보여야 한다. 두 스위치를 "일관성" 명목으로 같은 취급으로 합치지 말 것.`
  `**Tier B — codex (availability-floor: 있으면 무조건, 스코프 무관).**` → `**다른 전제 각도 — codex (사용 가능하면 부른다).**` 이고 그 문단의 `regardless of scope — model-family diversity is load-bearing` 은 그대로.
  `**Tier C — Dynamic specialists (모델이 diff 스코프로 선택; 외부 advisory agent).**` → `**추가 리뷰어 — 스코프 도출(외부 advisory agent).**`, 그 문단의 `(Tier C, NOT floor)` → `(각도 수행자가 아니다)`, `Tier C agents are advisory` → `추가 리뷰어는 advisory 다 —`.
  투명성 줄 `> [quality-gates] Review iter N — 선택: …` → `> [quality-gates] iter N — 선택: …`. Graceful degradation 의 `continue with floor(A) + codex(B) + whatever is installed` → `continue with the angle performers + whatever is installed`, `Floor and codex are **not** affected` → `The angle performers are **not** affected`.
  Phase 1.5 첫 문장의 `탐지(Tier A 의 \`security-reviewer\` · Tier B codex · Tier C)` → `탐지(\`security-reviewer\` · codex · 추가 리뷰어)`.
- Step 4.5 의 모든 `## Review gate iter N` → `## qg iter N`. `exit the loop → [Dispatch Loop](#dispatch-loop) step 4 (which skips the Runtime gate …)` 류 두 곳 → `exit the loop → [Final Summary](#final-summary)`. 「This mirrors the Runtime gate's `indeterminate ≠ clean` rule at [Step R4](#runtime-gate).」 → 「This mirrors the differential test's `indeterminate ≠ clean` rule (reference R6).」 Security-review-absent advisory 의 `Tier A floor is \`security-reviewer\` + 재비판(\`doc-recritic\`); with one of the two removed, a bare \`clean\` over-claims.` → `보안 각도와 판정 각도는 부재가 판정을 막는 두 각도다; with one of them missing, a bare \`clean\` over-claims.`
- Step 5 의 `## History` 줄 형식 `Review gate iter N: …` → `qg iter N: …`.

**(g) 결정 템플릿 두 개** — `## Review iter boundary decision` → `## Fix-loop decision`, 리터럴을 이것으로(AC6 앵커 `findings remain` 은 **그대로**):

```
AskUserQuestion({
  questions: [
    {
      question: "qg iter N: findings remain (<summary>). What next?",
      header: "qg iter N",
      options: [
        {label: "Retry",             description: "Apply the suggested fixes (I will Edit the files in this turn), then re-run the pipeline for the next iteration — differential test included."},
        {label: "Accept and finish", description: "Accept current findings as-is and go to the final summary with the current verdict."},
        {label: "Stop",              description: "Abort the pipeline at this iteration. Address findings and re-run /qg."}
      ],
      multiSelect: false
    }
  ]
})
```

  그 아래 「**Gate-scope conditional (review-only):**」 문단을 지우고, Branch 목록을 이것으로:

```markdown
Branch on answer:
- **Retry** → apply user-consented fixes by calling Edit/Write directly
  with the synthesizer's suggested patches; increment iteration counter;
  loop back to [Pipeline](#pipeline) step 2 (① 부터 — ② 차등 테스트 포함). See
  [Retry: file-write safety](#retry-file-write-safety) for the
  canonicalization requirement on reviewer-supplied paths, and
  [Retry: error handling](#retry-error-handling) for the AskUserQuestion
  surface that fires on Edit failures.
- **Accept and finish** → exit the loop and emit the final summary with the
  findings recorded.
- **Stop** → emit final summary marked aborted at this iteration.
```

  `## Review max-iter decision` → `## Max-iter decision`, 리터럴:

```
AskUserQuestion({
  questions: [
    {
      question: "qg reached max 5 iterations. Last findings: <summary>. Finish with the current verdict or stop?",
      header: "qg max-iter",
      options: [
        {label: "Accept and finish", description: "Accept residual findings and go to the final summary."},
        {label: "Stop",              description: "Abort the pipeline. Address findings and re-run /qg."}
      ],
      multiSelect: false
    }
  ]
})
```

  그 아래 「**Gate-scope conditional (review-only):**」 문단을 지운다. SKILL 안의 `[Review iter boundary decision](#review-iter-boundary-decision)` · `[Review max-iter decision](#review-max-iter-decision)` 링크를 새 앵커로 바꾼다.

**(h) `## Reviewer composition (scope-driven)` → `## Angles and reviewers (scope-driven)`** — 첫 목록을 이것으로(rubric 표 · depth 가이드 · 팔레트 · 예시 표는 남기고 그 안의 `Tier C` 를 `추가 리뷰어` 로):

```markdown
The reviewer set is composed per angle (설계 §6.3.1). Selection is **model-owned**
(lightness) — there is no deterministic selector schema; scout is a hint, not an
authority. 각도의 의무는 결정론이 지키고(⑤ 의 각도 상태), 누가 채우는지는 여기서 정한다:

- **보안 각도** — `quality-gates:security-reviewer`: 매 iteration. `tools: Read, Grep, Glob` (#104 락, 무변경). 모델이 못 뺀다.
- **판정 각도** — 재비판 `quality-gates:doc-recritic`: 매 iteration(탐지 0 이어도 — AC17).
- **다른 전제 각도** — codex: `detect_codex.sh` 가 참이면 부른다. 모델 다양성 손실은 공시하고 막지 않는다.
- **추가 리뷰어** (아래 rubric으로 diff 스코프에 맞춰 가감; 최대 6 후보):
```

**(i) `## Reviewer dispatch contract`** — 목록에서 `- \`quality-gates:runtime-verifier\`` 줄을 지우고 「The following three reviewer subagents」 → 「The following two reviewer subagents」.

**(j) `## Runtime gate` 절을 이것으로 바꾼다:**

````markdown
## Differential test

**절차 전문은 `references/differential-test.md` 에 있다.** 매 iteration 의 ②(Review
Step 1c)에서 그 파일을 Read 로 읽어 그대로 따른다. trivia escape 로 파이프라인이
통째로 생략된 실행만 읽지 않는다.

```
Read ${CLAUDE_PLUGIN_ROOT}/skills/quality-pipeline/references/differential-test.md
```

그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는 치환되지 않은 채로 온다 — 읽거나 실행할 때 `${CLAUDE_PLUGIN_ROOT}` 로 바꿔 넣는다. 위 `Read` 줄의 경로가 절대 경로로 보이지 않으면 reference 를 cwd 에서 찾지 말고 멈춰 보고한다.
````

**(k) `## Blocked-path routing` 절 · 그 뒤 `---` 와 두 문단 · `## Runtime NEEDS_RESOLUTION decision` 절을 통째로 지운다.**

**(l) `## Final Summary`** — 펜스와 그 앞 문단을 이것으로(판정 행은 Task 8 이 바꾼다):

````markdown
Build the status rows and render them (deterministic, scannable) — one
`key<TAB>value` line per row:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
printf 'Review\t<clean iter N | no scope reviewed (branch <M> ahead) | accepted-with-findings iter N | aborted iter N>\nDifferential test\t<attribution_status · 원장 게이트 rc>\n' \
  | $QG/scripts/render-terminal.py table --title "Quality Gates — Complete"
```
````

**(m) `## kill switch`** — `DISABLE_RUNTIME_SANDBOX` 항목을 지운다. `DISABLE_CODEX` 항목의 `Review gate의 codex co-review만` → `다른 전제 각도(codex)만`, `Review gate의 "Codex skip 안내"` → `Review Step 3 의 "Codex skip 안내"`. `DISABLE_SECURITY_REVIEWER` 항목의 `Review gate Tier A floor의` → `보안 각도의`, `Review gate의 "Tier A — Floor" 절` → `Review Step 3 의 "보안 각도" 절`. `DISABLE_SPEC_CONFORMANCE` 항목을 이것으로: `- \`DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE=1\` — 차등 테스트 R1b 의 test-scope-validator dispatch 에 \`spec_path: none\` 을 강제하고 codex \`<spec_context>\` 를 비운다(plan 기반 분류만 남는다). Arguments 절.`

**(n) `## Rules`** — R4 의 마지막 문장(「For Runtime gate missing-credential resolution, …」)을 지운다. R5 의 `Do not re-dispatch the same Review gate reviewer` → `Do not re-dispatch the same reviewer`. R1 의 `user-consented Review gate fixes only` → `user-consented fixes only`.

**(o) 나머지 스윕** — SKILL 전체에서:

```bash
cd "$(git rev-parse --show-toplevel)"
S=plugins/quality-gates/skills/quality-pipeline/SKILL.md
git grep -n -P -i 'Runtime gate|Review gate|runtime-verifier|detect-runtime|Decision [12]|block_policy|approved_surfaces|effective_skip_runtime|skip_runtime|NEEDS_RESOLUTION|SKIP_WITH_EVIDENCE|Tier [ABC]|single-gate|gate scope|both gates|RUNTIME_MAX_RESOLUTIONS|DISABLE_RUNTIME_SANDBOX|mutation.guard|create-sandbox|sandbox|ac_coverage|runtime-gate' -- "$S" || echo "OK SKILL 깨끗"
```

남은 매치를 줄마다 고친다. `codex` 의 `-s`/`sandbox` 는 이 SKILL 에 나오지 않는다 — 나오면 보고한다.

- [ ] **Step 5: `commands/qg.md` 를 고친다**

| 자리 | 새 문면 |
|---|---|
| frontmatter `description` | `"Run the quality gates pipeline (scope → differential test → review → verdict)"` |
| `argument-hint` | `"[critique <path>] [branch [<name>]\|--paths <glob>...\|--reset\|--gc] [--plan <path>] [--pr-url <url>]"` |
| 머리 문장 `Run the 2-gate quality verification pipeline …` | `Run the quality pipeline — one pipeline, one verdict (\`clean\` · \`defect\` · \`not-certified (<사유>)\`).` |
| critique 절 `코드 2게이트 파이프라인이 아니라` | `코드 파이프라인이 아니라` |
| critique 절 `**코드 파이프라인 인자**(bare \`/qg\`, \`both\|review\|runtime\|branch\|--paths ...\`)` | `**코드 파이프라인 인자**(bare \`/qg\`, \`branch\|--paths ...\`)` |
| Instructions 의 `after the gate-scope question it runs the Review gate (with internal fix-loop) and, when both gates are selected, the Runtime gate — surfacing decision points` | `runs the pipeline — differential test, reviewers, re-critique, synthesis — with its internal fix-loop, surfacing decision points` |
| Quick Reference | `/qg` 행 → `Run the pipeline; git-derived diff (branch + worktree)` · `/qg branch` 행 → `Run on the full-branch diff (vs \`main\`)` · `/qg branch <name>` 행 → `Run against branch \`<name>\` in isolated worktree` · `/qg --paths` 행 → `Scope to matched paths` · `/qg both` · `/qg review` · `/qg runtime` · `/qg --skip-runtime` · `DISABLE_RUNTIME_SANDBOX` 행 **삭제** · 새 행 `\| \`both\` · \`review\` · \`runtime\` · \`--skip-runtime\` \| 제거됨 — 한 줄 공지 후 그대로 진행 \|` |
| Scope 절의 `Review gate의 **정직-verdict floor**` | `파이프라인의 **정직-verdict floor**` |
| `### Gates` 절 | `### Pipeline` 으로 바꾸고 본문을 다섯 줄로: `① 스코프 → ② 차등 테스트(기준선 대비, 매 iteration) → ③ 각도 + 리뷰어 → ④ 출처-제거 재비판 → ⑤ 합성 · 판정` 과 fix-loop 한 줄 |
| Pipeline Rules | `with \`Retry\` / \`Proceed to Runtime gate\` / \`Stop\`` → `with \`Retry\` / \`Accept and finish\` / \`Stop\`` · `AskUserQuestion also fires on Review gate max-iter and Runtime gate NEEDS_RESOLUTION.` → `AskUserQuestion also fires on max-iter, and on the differential test's gap gate (R3) when something was left out.` · 제목 `### Pipeline Rules (v2.0.0)` → `### Pipeline Rules` |

- [ ] **Step 6: `reconstruct-skill.sh` 를 옮긴다** — 스플라이스 헤딩 `/^## Runtime gate$/` → `/^## Differential test$/`, 참조 파일 `"/references/runtime-gate.md"` → `"/references/differential-test.md"`, 오류 문장 두 곳의 파일 이름 · 헤딩 이름을 같이. 머리 주석의 `## Runtime gate` · `runtime-gate.md` · `Step R-init..R9` 도 새 이름으로(`Step R-init..R8`). 소비자 락들의 `FAIL: SKILL.md ↔ references/runtime-gate.md 재구성 실패` 문구는 인벤토리 `retarget` 행으로 처리한다.

- [ ] **Step 7: 제거한다**

```bash
cd "$(git rev-parse --show-toplevel)"
git rm plugins/quality-gates/agents/runtime-verifier.md plugins/quality-gates/scripts/detect-runtime.sh
```

그리고 인벤토리의 `delete-file`(Task=7) 테스트를 `git rm` 한다 — 행마다 「규칙을 잇는 자리」가 채워져 있는지 본다. `tools/adjudication/check_slots.py` 의 주석 bullet `#   · \`runtime-verifier.spec_acceptance_criteria\` — spec 에서 뽑은 {ac_id,text} → ⓑ.` 를 지운다(그 슬롯의 agent 가 사라졌다 — `EXEMPT_SLOTS` 항목이 아니라 주석이라 기준선 수는 안 움직인다).

- [ ] **Step 8: 락 인벤토리의 `Task=7` 행을 처리한다**

`delete` · `retarget` · `invert` 를 행대로. **이빨 보존** — `retarget` 행마다 근거 칸의 변이를 새 앵커에 한 번 태워 RED 를 본 뒤 되돌린다(커밋 전이므로 `git stash` 금지 — 변이는 파일 사본으로 한다: `cp X /tmp/…` 후 편집 → 락 → `cp` 로 복원 → `git diff --stat` 으로 복원 확인). 하네스의 큰 절들(`== 신규 스크립트 배선` · `== R5b·R6 의 HEAD 축 트리 인자` · `== 호출 주체 불변식` · `== 폴백 R5b 미실행` 등)은 인벤토리가 정한 대로 — 예: `create-head` 인자 검사는 `$baseline_sha` → `$sealed` 로 `retarget`, `== 폴백 R5b 미실행` 은 `delete`(대상 소멸: 샌드박스 폴백), `== 호출 주체 불변식` 은 verifier dispatch 블록 대신 「어느 `Agent({…})` 블록 안에도 `run-test-selection.sh` 가 없다」로 `retarget`.

하네스의 `# guards:` 줄에서 `plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md` 를 `…/differential-test.md` 로 바꾼다.

- [ ] **Step 9: 공유 락 · AC21 · 표면 락을 확인한다**

```bash
cd "$(git rev-parse --show-toplevel)"
export PYTHONDONTWRITEBYTECODE=1
for t in plugins/quality-gates/tests/test_one_pipeline_surface.sh \
         plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh \
         plugins/quality-gates/tests/test_check_allowed_tools_order.sh \
         plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh \
         plugins/quality-gates/tests/test_guards_declaration_mapping.sh \
         shared/tests/test_dispatch_disposition.sh shared/tests/test_agent_input_slots.sh \
         shared/tests/test_skill_reference_pointers.sh shared/tests/test_plugin_root_no_cwd_fallback.sh \
         shared/tests/test_docreview_copy_set.sh shared/tests/test_dispatch_name_defined.sh; do
  printf '%s ' "$t"; bash "$t" 2>&1 | grep -cE '^[[:space:]]*✗|^FAIL:'
done
bash plugins/quality-gates/scripts/check-allowed-tools-order.sh && echo "OK allowed-tools 순서"
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | grep '^FAIL:' > "$CLAUDE_JOB_DIR/tmp/t7-harness-fails.txt"
comm -13 <(sort "$CLAUDE_JOB_DIR/tmp/pr4b-baseline-harness-fails.txt") <(sort "$CLAUDE_JOB_DIR/tmp/t7-harness-fails.txt")
bash "$CLAUDE_JOB_DIR/tmp/run-suite.sh" "$CLAUDE_JOB_DIR/tmp/t7.tsv"
```

**기대** — 표면 락 0 · 하네스의 `FAIL:` 는 **기준선 이름 집합의 부분집합**(`comm -13` 출력 없음 — 새 이름 0. 기준선의 둘이 사라졌으면 어느 행 처리로 사라졌는지 적는다) · 나머지 0 · `OK allowed-tools 순서` · `run-suite` 는 기준선과 행 단위로 대조해 **추가 · 삭제된 행이 이 Task 의 파일뿐**인지 본다. `shared/tests/*` 넷은 파일이 한 바이트도 안 바뀐 채 GREEN 이어야 한다(`git diff --stat origin/main -- shared` 가 빈 출력).

**AC21** — `test_guards_coverage_bidirectional.sh` 가 GREEN 이면 지운 테스트가 어떤 `# guards:` 글롭의 유일 대상이 아니다. RED 면 그 글롭을 가진 락을 보고 `delete` 행의 「규칙을 잇는 자리」를 다시 본다.

- [ ] **Step 10: 커밋(한 커밋)**

```bash
cd "$(git rev-parse --show-toplevel)"
chmod +x plugins/quality-gates/tests/test_one_pipeline_surface.sh
git add plugins/quality-gates/tests/test_one_pipeline_surface.sh \
        plugins/quality-gates/skills/quality-pipeline/SKILL.md \
        plugins/quality-gates/skills/quality-pipeline/references/differential-test.md \
        plugins/quality-gates/commands/qg.md plugins/quality-gates/tests/lib/reconstruct-skill.sh \
        plugins/quality-gates/scripts/check-allowed-tools-order.sh tools/adjudication/check_slots.py
git add -u plugins/quality-gates
git status --short
git commit -m "feat(qg)!: 한 파이프라인 — runtime-verifier 제거 · 차등 테스트 레퍼런스 · 게이트 범위 질문 제거" \
  -m "두 게이트를 ① 스코프 → ② 차등 테스트 → ③ 각도 + 리뷰어 → ④ 재비판 → ⑤ 합성의 한 파이프라인으로 합친다. runtime-verifier · detect-runtime.sh · Decision 1·2 · block policy · 해소 루프가 사라지고, runtime-gate.md 는 verifier 몫(R5a · R7 · R9)을 걷어낸 differential-test.md 가 된다. HEAD 축은 seal-worktree.sh 의 봉인에서 선다. 부팅되는 앱의 런타임 행위 검증은 대체하지 않고 주장을 거둔다(설계 §6.5.3)." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4b
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 8: 판정 상시 배선 — `--emit-verdict` · `--angles` · 사유 · 보안 fail-closed (한 커밋)

> `security-reviewer` 처분 `fail-closed` 와 `--angles` 상시 배선은 **같은 커밋**이어야 참이 된다(PR4a R-R) — 처분만 바꾸면 부재가 판정을 막는다는 선언이 락 밖에서 거짓이다.

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` · `references/differential-test.md`(R8 판정 입력 표) · `plugins/quality-gates/commands/qg.md`(Quick Reference · Scope 절) · `plugins/quality-gates/scripts/check-allowed-tools-order.sh`(`verdict.py`) · `plugins/quality-gates/tests/test_verdict_vocabulary.sh`(산출자 도출) · `plugins/quality-gates/tests/test_angle_coverage.sh`(머리 주석)
- Create: `plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh`
- Test: 인벤토리의 `Task=8` 행(`test_security_reviewer_kill_switch.sh` · `test_skill_drop_notice_consumed.sh` · `test_qg_false_clean_floor.sh` · 하네스의 Step 4.5 행 …)

**Interfaces:**
- Consumes: Task 2 의 합성기 CLI · Task 3 의 두 머리줄 · Task 7 의 SKILL 절 이름 · `angles.parse` · `verdict.REASONS`
- Produces: SKILL 이 싣는 `--reason` 리터럴 집합 = `{trivia, kill-switch, scope-empty, silent-drop, error-axis}` · 각도 파일 `$RV/angles.txt` · 판정 표면 `## qg iter N — <verdict>`

- [ ] **Step 1: 실패하는 배선 락을 쓴다** — `plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh` (`chmod +x`):

```bash
#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/quality-pipeline/references/differential-test.md plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/verdict.py plugins/quality-gates/scripts/angles.py
# test_pipeline_verdict_wiring.sh — 판정 상시 배선 (설계 §6.1 ⑤ · §6.3.5 · §6.4.3, AC2 · AC8–AC12).
#
# 합성기 쪽 총 함수는 test_verdict_vocabulary.sh · test_angle_coverage.sh 가 잰다. 이 락은
# 오케스트레이터가 그것을 «실제로 부르는가»를 잰다 — 부르지 않으면 두 락의 GREEN 은 락
# 안에서만 참이다.
#
# 잴 수 없는 것: 모델이 각도 파일을 «참되게» 쓰는가(설계 §15-4). 이 락은 모양과 합성기의
# 행동만 잰다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"
. "$SCRIPT_DIR/lib/recritic_fixture.sh"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
REF="$PLUGIN_ROOT/skills/quality-pipeline/references/differential-test.md"
V="$PLUGIN_ROOT/scripts/verdict.py"
export PYTHONDONTWRITEBYTECODE=1

case_every_synth_call_emits_verdict_and_angles() {
  local got
  got=$(python3 - "$SKILL" "$REF" <<'PY'
import re, sys
calls = bad = 0
for path in sys.argv[1:]:
    text = open(path, encoding="utf-8").read()
    for body in re.findall(r"^[ \t]*```bash\n(.*?)^[ \t]*```[ \t]*$", text, re.M | re.S):
        if "synthesize_findings.py" not in body:
            continue
        calls += 1
        if "--emit-verdict" not in body or "--angles" not in body:
            bad += 1
print(f"CALLS:{calls}")
print(f"BAD:{bad}")
PY
)
  assert_grep "$got" '^CALLS:[1-9]' "합성기를 부르는 펜스가 하나 이상 있다(0 이면 아래가 공허하다)"
  assert_grep "$got" '^BAD:0$'      "합성기를 부르는 펜스 ∀ 가 --emit-verdict 와 --angles 를 싣는다"
}

case_blocking_angle_dispatches_are_fail_closed() {
  # §6.3.5 — 보안 · 판정 각도 디스패치는 fail-closed. 처분 줄은 dispatch 블록 바로 안에 있다.
  local got
  got=$(python3 - "$SKILL" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
for agent in ("quality-gates:security-reviewer", "quality-gates:doc-recritic"):
    m = re.search(r'subagent_type:\s*"' + re.escape(agent)
                  + r'",?\s*\n\s*//\s*\*\*처분\*\*\s*—\s*consumer=\S+\s*·\s*fail-(open|closed)', text)
    print(f"{agent}:{m.group(1) if m else 'MISSING'}")
PY
)
  assert_grep "$got" '^quality-gates:security-reviewer:closed$' "보안 각도 디스패치는 fail-closed"
  assert_grep "$got" '^quality-gates:doc-recritic:closed$'      "판정 각도 디스패치는 fail-closed"
}

case_reason_literals_are_closed_and_pinned() {
  # SKILL · 레퍼런스가 싣는 `--reason <사유>` 리터럴 ∀ ⊆ verdict.REASONS, 그리고 그 집합은
  # 파일 밖 핀과 같다 — 재도출만 하면 오타(`killswitch`)가 새 이름으로 샌다.
  local got
  got=$(python3 - "$SKILL" "$REF" "$PLUGIN_ROOT/scripts" <<'PY'
import re, sys
sys.path.insert(0, sys.argv[3]); import verdict
found = set()
for path in sys.argv[1:3]:
    found |= set(re.findall(r"--reason ([a-z][a-z-]*)", open(path, encoding="utf-8").read()))
print("OUTSIDE:" + ",".join(sorted(found - set(verdict.REASONS))))
print("SET:" + " ".join(sorted(found)))
PY
)
  assert_grep "$got" '^OUTSIDE:$' "SKILL 이 싣는 사유는 전부 닫힌 열거 안이다"
  assert_grep "$got" '^SET:error-axis kill-switch scope-empty silent-drop trivia$' \
    "SKILL 이 싣는 사유 집합(핀) — declaration-invalid · merge-conflict 는 4c"
}

case_angle_template_is_total() {
  # SKILL 의 각도 파일 견본이 angles.parse 를 통과한다. 견본이 셋 중 하나를 빠뜨리거나 문법
  # 밖 상태를 적으면 모델이 그대로 베껴 쓰는 파일이 exit 4 가 된다.
  local got
  got=$(python3 - "$SKILL" "$PLUGIN_ROOT/scripts" <<'PY' 2>/dev/null
import re, sys
sys.path.insert(0, sys.argv[2]); import angles
text = open(sys.argv[1], encoding="utf-8").read()
blocks = re.findall(r"^[ \t]*```text\n(.*?)^[ \t]*```[ \t]*$", text, re.M | re.S)
cands = [b for b in blocks if re.search(r"^\s*security:", b, re.M)]
print(f"N:{len(cands)}")
for b in cands:
    angles.parse("\n".join(l.strip() for l in b.splitlines()))
print("PARSED")
PY
) || true
  assert_grep "$got" '^N:1$'    "각도 파일 견본이 정확히 하나 있다"
  assert_grep "$got" '^PARSED$' "견본이 angles.parse 를 통과한다(세 각도 · 문법 안)"
}

case_differential_runs_inside_every_iteration() {
  # Review Focus 3 · R-AC — ② 는 iteration 루프 «안»이다.
  local body it d fin
  body=$(awk '/^## Pipeline$/{f=1;next} f&&/^## /{exit} f' "$SKILL")
  it=$(printf '%s\n' "$body" | grep -n 'iteration N = 1\.\.5' | head -1 | cut -d: -f1)
  d=$(printf '%s\n' "$body" | grep -n '②' | head -1 | cut -d: -f1)
  fin=$(printf '%s\n' "$body" | grep -n 'Final Summary' | head -1 | cut -d: -f1)
  local inside=0
  if [ -n "$it" ] && [ -n "$d" ] && [ -n "$fin" ] && [ "$it" -lt "$d" ] && [ "$d" -lt "$fin" ]; then inside=1; fi
  assert_eq "$inside" "1" "② 가 iteration 항목과 Final Summary 사이(루프 안)에 있다"
  assert_grep "$body" '매 iteration 돈다' "② 가 매 iteration 돈다고 적혀 있다"
}

case_security_switch_is_not_certified_even_with_zero_findings() {
  # Review Focus 5 · §6.5.1 9행 — 보안 kill switch 의 새 뜻: 배너가 아니라 판정이다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []
added: []'
  printf 'security: absent\nadjudication: filled\ndifferent-premise: filled\n' > "$T/angles.txt"
  local out; out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt")
  assert_grep "$out" '^verdict: not-certified$' "보안 각도 부재는 탐지 0 이어도 clean 이 아니다"
  assert_grep "$out" '^reason: angle-absent$'   "사유는 angle-absent"
  printf 'security: filled\nadjudication: filled\ndifferent-premise: filled\n' > "$T/angles.txt"
  out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt")
  assert_grep "$out" '^verdict: clean$' "같은 실행에서 보안 각도가 채워지면 clean(양의 짝)"
  rm -rf "$T"
}

case_different_premise_absent_is_disclosed_not_blocked() {
  # AC12 — 다른 전제(codex) 부재는 공시만 한다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []
added: []'
  printf 'security: filled\nadjudication: filled\ndifferent-premise: absent(not-installed)\n' > "$T/angles.txt"
  local out; out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt")
  assert_grep "$out" '^verdict: clean$'                                 "다른 전제 부재는 막지 않는다"
  assert_grep "$out" '^  different-premise: absent\(not-installed\)$'  "부재가 각도 블록에 공시된다"
  rm -rf "$T"
}

case_caller_reasons_reach_the_verdict() {
  # AC9 · R-Y — 호출자 사유가 판정에 닿는다. 탐지 0 · 각도 전부 filled 인 «깨끗한» 실행에
  # 사유 하나씩을 얹는다.
  local T r out; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []
added: []'
  printf 'security: filled\nadjudication: filled\ndifferent-premise: filled\n' > "$T/angles.txt"
  for r in kill-switch scope-empty silent-drop error-axis; do
    out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --reason "$r")
    assert_grep "$out" '^verdict: not-certified$' "--reason $r → not-certified"
    assert_grep "$out" "^reason: $r\$"            "사유는 $r"
  done
  out=$(python3 "$V" --reason trivia)
  assert_grep "$out" '^reason: trivia$' "trivia 는 verdict.py 가 직접 낸다"
  rm -rf "$T"
}

for c in case_every_synth_call_emits_verdict_and_angles case_blocking_angle_dispatches_are_fail_closed \
         case_reason_literals_are_closed_and_pinned case_angle_template_is_total \
         case_differential_runs_inside_every_iteration \
         case_security_switch_is_not_certified_even_with_zero_findings \
         case_different_premise_absent_is_disclosed_not_blocked case_caller_reasons_reach_the_verdict; do
  "$c"
done
finish
```

`test_verdict_vocabulary.sh` 의 `case_reason_enum_is_closed_and_accounted` 를 고친다 — 산출자에 SKILL · 레퍼런스의 `--reason` 리터럴을 더하고 부채를 둘로:

```bash
  local debt="declaration-invalid merge-conflict"
  local SKILL_MD="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
  local REF_MD="$PLUGIN_ROOT/skills/quality-pipeline/references/differential-test.md"
  local got; got=$(python3 -c "
import re, inspect, sys
sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import verdict
debt = set('''$debt'''.split())
flag_produced = set(re.findall(r'add\(\"([a-z-]+)\"\)', inspect.getsource(verdict.decide)))
caller_produced = set()
for p in ('$SKILL_MD', '$REF_MD'):
    caller_produced |= set(re.findall(r'--reason ([a-z][a-z-]*)', open(p, encoding='utf-8').read()))
produced = set(verdict.CAUSE_TO_REASON.values()) | flag_produced | caller_produced
print('MISSING:' + ','.join(sorted(set(verdict.REASONS) - (produced | debt))))
print('STALE:'   + ','.join(sorted((produced | debt) - set(verdict.REASONS))))
print('OVERLAP:' + ','.join(sorted(debt & produced)))
print('N:%d' % len(verdict.REASONS))
print('AXES:' + ','.join(sorted(inspect.signature(verdict.decide).parameters)))")
```

그 위 주석의 「실측 3분할」 블록을 이것으로:

```bash
  # 산출자 셋:
  #   차등 축(CAUSE_TO_REASON.values()): scope-empty · baseline-unrunnable · silent-drop ·
  #                                     error-axis · granularity-smear
  #   decide() 자신의 플래그: findings-lost · angle-absent
  #   오케스트레이터(SKILL · 레퍼런스의 `--reason` 리터럴): trivia · kill-switch · (차등
  #                                     축과 겹치는) scope-empty · silent-drop · error-axis
  #   부채 — 산출자 없음(PR4c): declaration-invalid · merge-conflict
```

파일 머리 주석의 부채 서술(있으면)도 「PR4c」로. `test_angle_coverage.sh` 의 머리 주석 「**오늘 배선이 안 된 것** — `--angles` 는 기본 off 다(계획 R-E). 오케스트레이터가 그것을 «항상» 싣게 만드는 것은 PR4 의 빚이고, 이 락은 그 빚을 재지 못한다.」를 이것으로: `오케스트레이터가 매 실행 \`--angles\` 를 싣는지는 \`test_pipeline_verdict_wiring.sh\` 가 잰다. 이 락은 합성기 쪽 총 함수만 잰다.`

- [ ] **Step 2: 실패를 확인한다** — 배선 락에서 `BAD:0` · `security-reviewer:closed` · `SET:` · `N:1` · `매 iteration`(Task 7 이 이미 적었으면 GREEN) 이 RED. 행동 케이스 셋은 오늘도 GREEN 이어야 한다(합성기는 이미 할 줄 안다 — 이 락이 재는 것은 **배선**이다. 보고서에 적는다). `test_verdict_vocabulary.sh` 는 `OVERLAP`/`MISSING` 이 RED(SKILL 에 아직 `--reason trivia` 가 없다).

- [ ] **Step 3: SKILL 을 배선한다**

**(a) `## Trivia escape`** — exit 0 분기를 이것으로:

````markdown
- 0 = trivia detected → skip the whole pipeline. 판정을 낸다 — trivia 실행은 `clean` 이
  아니다(「테스트 없는 clean 은 나오지 않는다」, 설계 C4):

  ```bash
  QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
  python3 "$QG/scripts/verdict.py" --reason trivia
  ```

  Print `Trivia diff — pipeline skipped (one-sentence diff per CLAUDE.md trivia escape).`
  and the script's stdout verbatim, then go to [Final Summary](#final-summary) with
  Iterations `0`.
````

**(b) Step 1c 머리에 kill switch 를 더한다**(Step 1c 문단 앞):

```markdown
**Kill switch — `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1`.** 켜져 있으면 레퍼런스를
읽지 않고 ② 를 통째로 건너뛴다. 이 줄을 그대로 보인다:
`> [quality-gates] 차등 테스트가 DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 로 꺼져 있다 — 이 실행은 not-certified (kill-switch) 다.`
그리고 Step 4 에 `--reason kill-switch` 를 싣는다. 차등 테스트는 리뷰 대상 저장소의 코드를
호스트 권한으로 돌린다 — 이 스위치는 그것을 끄는 보안 컨트롤이다.
```

**(c) 보안 kill switch 의 의미를 바꾼다** — IF 블록의 3·4번을 이것으로:

```markdown
   3. **loud advisory** — 이 줄을 사용자에게 그대로 보인다:
      > `> [quality-gates] security-reviewer disabled via DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1 — 이 iteration 에는 보안 리뷰가 없었다 (보안 각도 부재).`
   4. 이 iteration 의 각도 파일(Step 4)에 `security: absent` 를 쓴다. 판정은
      `not-certified (angle-absent)` 가 된다 — 탐지가 0 이어도. 배너만으로 끝내지 않는다:
      판정만 읽는 사람에게도 결손이 보여야 한다.
```

  ELSE 줄 `\`$security_review_absent = no\` — …` 를 `ELSE: 아래 리터럴을 평소대로 발행한다.` 로. **Step 4.5 의 「Security-review-absent advisory」 절 전체를 지운다**(판정이 그 일을 한다 — 인벤토리 `invert` 행).

**(d) 보안 각도 dispatch 의 처분** — `// **처분** — consumer=plugins/quality-gates/scripts/synthesize_findings.py · fail-open` → `· fail-closed`. 그 블록 바로 아래에 한 문단:

```markdown
   **fail-closed 의 뜻** — 디스패치가 실패했거나 출력을 읽을 수 없으면 그 iteration 의
   각도 파일에 `security: absent(source-failed)` 를 쓴다. 판정은 `not-certified
   (angle-absent)` 다. 다른 리뷰어의 finding 이 있다고 보안 각도가 채워진 것이 아니다.
```

**(e) 저자 스탬프(R-Z)** — Phase 1.5 의 1번 문장 `(\`security-reviewer\` · \`code-reviewer\` …; codex 는 \`codex\`)` → `(\`security-reviewer\` · \`code-reviewer\` …; codex 는 \`codex-reviewer\` — 변환기 \`codex_findings_to_yaml.py\` 가 찍는 값)`.

**(f) Step 4 를 다시 쓴다** — `4. Run \`synthesize_findings.py\` to consolidate findings:` 부터 「**rc 를 소비하라.**」 문단 앞까지를 이것으로:

````markdown
4. **각도 파일을 쓰고 합성한다.**

   **각도 파일** — `$RV/angles.txt` 에 세 줄을 쓴다. 형식은 `<각도>: <상태>` 이고 상태는
   공백 없는 한 토큰이다(설계 §6.3.1 — 각도 ≠ 에이전트, 상태는 총 함수):

   ```text
   security: filled
   adjudication: filled
   different-premise: absent(not-installed)
   ```

   | 각도 | 값 | 조건 |
   |---|---|---|
   | `security` | `filled` | `security-reviewer` 를 디스패치했고 그 출력을 `findings.yaml` 에 넣었다(0건 포함) |
   | | `absent` | `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1` |
   | | `absent(source-failed)` | 디스패치가 실패했거나 출력을 읽을 수 없었다 |
   | `adjudication` | `filled` | **항상** — 재비판은 매 iteration 디스패치된다. 재비판자가 죽으면 합성기가 관측으로 `absent(source-failed)` 를 얹는다. `folded_into:doc-recritic` 으로 쓰지 않는다(승격 finding 하나로 AC10a 가 exit 4) |
   | `different-premise` | `filled` | codex 러너가 돌았고 `meta.codex_failed: false` 를 읽었다 |
   | | `absent(not-installed)` | `detect_codex.sh` 가 visible 표의 사유를 냈다 |
   | | `absent` | `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1` · `inside_codex_sandbox` |
   | | `absent(not-derived)` | 사용 가능한데 부르지 않았다 |
   | | `absent(source-failed)` | 러너가 돌았으나 결과를 쓸 수 없다(산출물 부재 · 0바이트 · `codex_failed: true` · 키 부재) · 감지기 실행 실패(`detector_not_runnable`) |

   **판정 입력** — 이 iteration 에 해당하는 것만 싣는다:

   | 조건 | 합성기에 싣는 것 |
   |---|---|
   | ② 가 돌았고 R6 집계가 exit 0 · `verdict_input` 3키와 `attribution_status` 를 다 읽었다 | `--differential "<$aggregate_yaml 절대 경로>"` |
   | ② 의 R6 어댑터별 호출 또는 집계 호출이 non-zero, 또는 키를 못 읽었다 | `--differential` 을 싣지 않고 `--reason error-axis` |
   | ② 의 `check_qa_ledger.py` 가 non-zero | `--reason silent-drop` |
   | ② 가 kill switch 로 생략됐다(Step 1c) | `--reason kill-switch` |
   | `$resolved_scope_file_count == 0` 이고 캐시한 `$changes_exist == yes` (정직-verdict floor) | `--reason scope-empty` |

   ```bash
   QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
   RV="<Phase 1.5 의 절대 경로>"
   python3 "$QG/scripts/synthesize_findings.py" --findings "$RV/findings.yaml" \
     --recritic "$RV/recritic.txt" --recritic-map "$RV/recritic-map.json" \
     --recritic-diff "$RV/recritic.diff" \
     --emit-verdict --angles "$RV/angles.txt" \
     <위 표의 판정 입력>
   ```
````

**(g) Step 4.5 를 다시 쓴다** — 「**Step 4.5 — Surface findings.**」 문단부터 「**Honest-verdict floor (deterministic — both clean sub-cases).**」 목록 끝까지를 이것으로(「**Resolved-scope file count …**」 문단은 **남긴다** — 판정 입력 표의 floor 조건이 그 값을 쓴다. 그 문단은 이 새 본문 뒤로 옮긴다):

```markdown
   **Step 4.5 — Surface the verdict.** 판정은 합성기 stdout 꼬리의 `verdict:` 줄 **하나**가
   정한다(`angles:` 블록 · `reason:` · `reasons:` 가 함께 온다). 네가 판정을 고르거나
   고치지 않는다.

   - stdout 을 **그대로** 사용자에게 보인다(요약 · 재서술 금지). 앞에 한 줄:
     `## qg iter N — <verdict>` (`not-certified` 면 `## qg iter N — not-certified (<reason>)`).
   - `verdict:` 줄이 정확히 한 번 나오지 않으면 이 iteration 은 clean 이 아니다 — rc 와
     stderr 를 그대로 보고하고 멈춘다.
   - 본 보고서의 `판정 degrade` 줄은 **그대로 보인다** — 차단이면
     `**이 실행은 clean이 아니다**`, 아니면 `공시(판정을 막지 않음)`. 판정은 바꾸지
     않는다(그 사실은 이미 `verdict:` 에 반영돼 있다). `dropped as malformed` 줄도 같다.
   - 캐시한 `$degraded == yes` 이고 `$resolved_scope_file_count == 0` 이면 advisory 한 줄:
     `> [quality-gates] scope check degraded (detached HEAD / no base branch / unrelated history / shallow) — empty-scope detection skipped (fail-open; verdict not floor-protected this run).`
   - ② 에 `granularity: bulk` 어댑터가 있었으면 `커버리지 미보장(러너가 선택을 무시함)` 을
     함께 보인다(레퍼런스 R8).

   그다음:
   - `verdict: clean` → 루프를 나가 [Final Summary](#final-summary).
   - `defect` 또는 `not-certified` 이고 **kept > 0**(`**Findings:**` counts 줄의 세
     severity 합 ≥ 1) → Step 5 의 결정 도구.
   - `defect` 또는 `not-certified` 이고 kept = 0 → 고칠 제안이 없다. 루프를 나가
     Final Summary(판정 그대로).
```

  「**Not-clean notice override …**」 · 「Why this clause exists …」 · 「Why the key is the marker …」 세 문단을 지운다(인벤토리 `invert`/`delete` 행 — 「규칙을 잇는 자리」 = 위 새 본문의 셋째 항목 + `verdict.decide` 의 차단 술어).

**(h) `## Final Summary`** — 펜스를 이것으로:

````markdown
```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
printf 'Verdict\t<마지막 verdict: 값 — not-certified 면 (<reason>) 포함>\nIterations\t<N>\nOutcome\t<finished | accepted with findings iter N | aborted iter N>\n' \
  | $QG/scripts/render-terminal.py table --title "Quality Gates — Complete"
```

Then print the last synthesizer output's `angles:` block verbatim, and the appended
`## History` lines from the state file as an indented tree beneath.
````

**(i) `## kill switch`** — 두 항목:

```markdown
- `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` — ② 차등 테스트를 통째로 건너뛴다.
  판정은 `not-certified (kill-switch)` 다. Review Step 1c.
- `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1` — 보안 각도의 `security-reviewer` 만
  skip 한다. 각도 파일에 `security: absent` → 판정 `not-certified (angle-absent)`.
  Review Step 3 의 "보안 각도" 절(dispatch 직전 게이트 + loud advisory).
```

  (옛 `DISABLE_SECURITY_REVIEWER` 항목을 위 둘째로 **바꾼다**.)

**(j) `allowed-tools`** — Group 1 의 `check-trivia.sh` 다음에 `  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verdict.py:*)` 를 더하고, `check-allowed-tools-order.sh` 의 `EXPECTED_ORDER` 에도 같은 자리에 더한다(26 항목).

- [ ] **Step 4: 레퍼런스 R8 · qg.md**

`differential-test.md` 의 R8 끝 문단(「**판정은 여기서 내지 않는다.** …」) 아래에:

```markdown
SKILL Step 4 가 싣는 판정 입력:

| 이 스텝의 결과 | 합성기에 |
|---|---|
| R6 집계 exit 0 · 3키와 `attribution_status` 를 다 읽음 | `--differential "$aggregate_yaml"` — `degrade_causes` 는 `verdict.py` 가 사유로 옮긴다 |
| R6 어느 호출이든 non-zero · 키 판독 실패 | `--reason error-axis` (`--differential` 없음) |
| `check_qa_ledger.py` non-zero | `--reason silent-drop` |
```

`commands/qg.md` — Quick Reference 에 `\| \`DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1\` \| 차등 테스트를 건너뛴다 — 판정은 \`not-certified (kill-switch)\` \|` 행을 더한다. Scope 절의 floor 문장 「verdict를 `no scope reviewed … NOT certified clean`으로 교체한다」 → 「판정이 `not-certified (scope-empty)` 가 된다」.

- [ ] **Step 5: 인벤토리의 `Task=8` 행을 처리한다** — 주로 `invert`: 보안 kill switch(배너 → 판정), Step 4.5 의 not-clean override(마커 → `verdict:` 줄), 정직-verdict floor(`no scope reviewed` 문구 → `--reason scope-empty`), codex 저자(`codex` → `codex-reviewer`). 각 `invert` 행의 양의 짝이 남는지 본다.

- [ ] **Step 6: 통과 확인**

```bash
cd "$(git rev-parse --show-toplevel)"
export PYTHONDONTWRITEBYTECODE=1
chmod +x plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh
for t in plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh plugins/quality-gates/tests/test_verdict_vocabulary.sh \
         plugins/quality-gates/tests/test_angle_coverage.sh plugins/quality-gates/tests/test_one_pipeline_surface.sh \
         plugins/quality-gates/tests/test_security_reviewer_kill_switch.sh plugins/quality-gates/tests/test_qg_false_clean_floor.sh \
         plugins/quality-gates/tests/test_skill_drop_notice_consumed.sh plugins/quality-gates/tests/test_check_allowed_tools_order.sh \
         plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh \
         shared/tests/test_dispatch_disposition.sh shared/tests/test_agent_input_slots.sh; do
  printf '%s ' "$t"; bash "$t" 2>&1 | grep -cE '^[[:space:]]*✗|^FAIL:'
done
bash plugins/quality-gates/scripts/check-allowed-tools-order.sh && echo "OK allowed-tools 순서"
bash "$CLAUDE_JOB_DIR/tmp/run-suite.sh" "$CLAUDE_JOB_DIR/tmp/t8.tsv"
```

**기대** — 하네스는 기준선 `FAIL:` 이름 집합의 부분집합, 나머지 0. `run-suite` 는 기준선과 행 단위로 대조.

- [ ] **Step 7: 커밋(한 커밋)**

```bash
cd "$(git rev-parse --show-toplevel)"
git add plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh \
        plugins/quality-gates/skills/quality-pipeline/SKILL.md \
        plugins/quality-gates/skills/quality-pipeline/references/differential-test.md \
        plugins/quality-gates/commands/qg.md plugins/quality-gates/scripts/check-allowed-tools-order.sh
git add -u plugins/quality-gates
git status --short
git commit -m "feat(qg)!: 판정 상시 배선 — 매 실행 --emit-verdict · --angles · 보안 각도 fail-closed" \
  -m "오케스트레이터가 합성기에 각도 파일과 판정 입력(차등 집계 · 호출자 사유)을 항상 싣고, 판정은 verdict: 줄 하나가 정한다. 보안 리뷰어 kill switch 는 배너가 아니라 not-certified (angle-absent) 가 되고, 차등 테스트 kill switch 는 not-certified (kill-switch), trivia 는 not-certified (trivia) 다. 보안 각도 디스패치 처분은 이 배선과 같은 커밋에서 fail-closed 가 된다. codex 저자 토큰은 codex-reviewer 로 정한다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4b
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---
### Task 9: 문서 — README · 코드 지도 · e2e 시나리오 · 설계 §16 재결정

**Files:**
- Modify: `plugins/quality-gates/README.md` · `plugins/quality-gates/tests/test_readme_state_diagram_complete.sh`(마커) · `docs/philosophy/devbrew-harness-philosophy.md`(코드 지도의 파일 포인터만) · `docs/plugin-authoring.md`(죽은 인용만) · `plugins/quality-gates/tests/e2e-scenarios.md` · `docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md`(§16)
- Test: `test_readme_state_diagram_complete.sh` · `test_readme_scope_reconcile.sh` · `test_impact_runtime_docs.sh` · 인벤토리의 `Task=9` 행

**Interfaces:**
- Consumes: Task 5 · 7 · 8 이 확정한 문면(인자 · 절 이름 · kill switch · 사유)
- Produces: 없음(문서)

- [ ] **Step 1: README 다이어그램 락의 마커를 먼저 옮긴다(실패하는 테스트)** — `test_readme_state_diagram_complete.sh` 의 `EXPECTED_MARKERS` 를 이것으로:

```bash
EXPECTED_MARKERS=(
  "setup-qg.sh"
  "SKILL preflight"
  "trivia escape"
  "qg iter loop"
  "② differential test"
  "⑤ synthesize → verdict"
  "AskUserQuestion"
  "findings remain"
  "Final summary"
)
```

  그리고 `missing` 검사 뒤, `PASS:` 앞에 옛 게이트 마커의 부재를 더한다(음의 락 — 위 양의 마커가 짝이다):

```bash
for gone in "Runtime gate dispatch" "Review gate iter loop" "gate scope?" "NEEDS_RESOLUTION"; do
  if grep -qF "$gone" "$README"; then
    echo "FAIL: README still carries the two-gate diagram marker: $gone"
    exit 1
  fi
done
```

  `bash plugins/quality-gates/tests/test_readme_state_diagram_complete.sh` → RED(새 마커 부재).

- [ ] **Step 2: README 를 고친다**

**(a) 첫 설명 줄** — `Claude Code용 2-게이트 품질 검증 파이프라인. 멀티 플러그인 리뷰 위임 구조.` → `Claude Code용 품질 검증 파이프라인 — 한 파이프라인, 한 판정(\`clean\` · \`defect\` · \`not-certified (<사유>)\`). 기준선 대비 차등 테스트는 매 실행 돈다.`

**(b) `## 인스턴스화한 원칙`** — 다음 bullet 을 **지운다**(대상 소멸): `Law 2 (Writer ≠ Reviewer, git-diff 구조적 가드) (v2.2.0 …)` · `Law 1 (Verification Plan) (v1.8.0) — Runtime gate가 evidence-required SKIP을 강제 …` · `Law 1 (Clarity / evidence-required) — 기능 단언 (v2.2.0)` · `운영-안전 게이트 (blast-radius) (v2.2.0)` · `P18 — Upfront 1-회 결정 + 폐기 (v2.2.0 …)` · `P18 anti-corollary … 회피 — Runtime gate (v1.8.0)`. 다음 bullet 을 **고친다**:
- `Law 2 (입력 오염 차단) — input_slots` — `agent 일곱(… · \`test-scope-validator\` · \`runtime-verifier\` · \`pr-understanding-builder\`)` → `agent 여섯(… · \`test-scope-validator\` · \`pr-understanding-builder\`)`.
- `Law 2 (Writer ≠ Reviewer) — 순수 read-only reviewer agent …` — 끝 문장(`\`runtime-verifier\`(sandbox-executor)는 예외로 …`)을 `쓰기 권한을 가진 agent 는 디스패치되지 않는다 — 테스트는 오케스트레이터가 자기가 만든 트리에서 직접 돌린다.` 로.
- `Law 3 (Compounding) — cross-plugin reader contract` — `Runtime gate의 test-scope-validator` → `차등 테스트의 test-scope-validator`.
- `P8 determinism-economy — self-honest verdict floor` — `verdict를 \`no scope reviewed … NOT certified clean\`으로 교체` → `판정이 \`not-certified (scope-empty)\` 가 된다`. `Review gate가` → `파이프라인이`.
- `P21 (Secret이 prompt context에 들어가지 않음) (v1.8.0) — Runtime gate의 AskUserQuestion은 …` → `P21 (Secret이 prompt context에 들어가지 않음) — 결정 도구는 결정과 포인터만 묻고 secret 값은 받지 않는다(SKILL Rules R4). regression test: \`tests/test_no_secret_prompts.py\`.`
- `Law 2 (Writer ≠ Reviewer, 3-way 분리) (v1.9.0)` — 이것으로: `**Law 2 (Writer ≠ Reviewer, 분리)** — writer(originating turn) ≠ \`test-scope-validator\`(차등 테스트 R1b 의 사전 분류 리뷰어) ≠ 테스트 실행(오케스트레이터 · 결정론 스크립트). \`test-scope-validator\` 는 \`tools: Read, Grep, Glob\` fail-closed allowlist.`
- 나머지 bullet 의 `Review gate` · `Runtime gate` 는 「파이프라인」 · 「차등 테스트」로.

  **더하는 bullet 둘**(목록 끝):

```markdown
- **Law 1 · G3 — 「검증하지 못했다」는 일급 판정값** (v9) — 판정은 `clean` · `defect` · `not-certified (<사유>)` 셋이고 사유는 닫힌 열거다(`scripts/verdict.py` 한 곳). kill switch · trivia · 각도 부재 · 차등 축의 해상도 문제는 `clean` 도 실패도 아닌 `not-certified` 로 드러난다. regression: `tests/test_verdict_vocabulary.sh` · `tests/test_pipeline_verdict_wiring.sh`.
- **C4 — 차등 테스트는 항상** (v9) — 기준선 축(`create-baseline`)과 봉인된 HEAD 축(`seal-worktree.sh` → `create-head`)에서 오케스트레이터가 직접 돌린다. 빠지는 길은 trivia escape 와 `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 둘뿐이고 둘 다 `not-certified` 다. 부팅되는 앱의 런타임 행위 검증은 **대체하지 않고 주장을 거둔다**.
```

**(c) `## 게이트` 절** — 이름을 `## 파이프라인` 으로 바꾸고, 표와 「아키텍처 메모」를 이것으로(비-코드 비평 모드 인용 블록 · `/qg-publish` 문단은 남기고 그 안의 `2게이트` · `두 게이트` · `Review/Runtime gate` 를 「코드 파이프라인」으로):

```markdown
| 단계 | 주체 | 무엇 |
|---|---|---|
| ① 스코프 | 오케스트레이터 + `check-review-scope.sh` | session(기본) · `branch` · `--paths` |
| ② 차등 테스트 | 오케스트레이터 + 결정론 스크립트 | 영향분 테스트를 기준선 축과 봉인된 HEAD 축에서 돌려 귀속(`references/differential-test.md`) |
| ③ 각도 + 리뷰어 | `security-reviewer`(보안) · codex(다른 전제) · 추가 리뷰어(스코프) | 각도 셋은 고정, 수행자는 스코프가 정한다 |
| ④ 재비판 | `doc-recritic`(판정 각도) | 출처를 못 보는 재비판 — 탐지 0 이어도 돈다 |
| ⑤ 합성 · 판정 | `synthesize_findings.py` → `verdict.py` | `clean` · `defect` · `not-certified (<사유>)` |

**아키텍처 메모 — 왜 오케스트레이션이 skill 에 있는가**: Claude Code는 skill만 `Agent()`의
`subagent_type`을 쓸 수 있다. 파이프라인은 여러 리뷰어를 디스패치해야 하므로 orchestration
로직이 `skills/quality-pipeline/SKILL.md`에 있다. 테스트 실행은 어떤 agent 에도 위임하지
않는다 — 오케스트레이터가 `run-test-selection.sh` 를 직접 부른다. 결정론 백스톱이 모델
주장과 독립이라는 전제가 거기서 선다.
```

**(d) `## Review gate 리뷰 단계 (v2.13.0 스코프-구동 구성)`** → `## 리뷰어 구성 — 각도 셋 + 추가 리뷰어`. 코드 블록을 이것으로:

```
보안 각도 — 매 iteration (모델이 못 뺌)
  └── quality-gates:security-reviewer   tools: Read, Grep, Glob (#104 락) · 처분 fail-closed
판정 각도 — 매 iteration (탐지 0 이어도)
  └── quality-gates:doc-recritic         tools: Read, Grep, Glob (#104 락) · 처분 fail-closed
다른 전제 각도 — detect_codex 참이면
  └── codex-reviewer (별도 프로세스/모델 패밀리, OS read-only 샌드박스) · 부재는 공시만
추가 리뷰어 — 모델이 스코프로 선택, advisory 외부 에이전트; 최대 6 후보
  ├── pr-review-toolkit:code-reviewer        ← 강한 default(비-trivial diff), quick-depth만 drop
  ├── pr-review-toolkit:silent-failure-hunter → 에러핸들링 변경
  ├── pr-review-toolkit:type-design-analyzer  → 신규/변경 타입
  ├── pr-review-toolkit:pr-test-analyzer      → 테스트 변경
  ├── pr-review-toolkit:comment-analyzer      → docs/주석 변경
  └── feature-dev:code-architect             → 대형 구조/아키텍처 변경
합성 — synthesize_findings.py (결정론) → verdict.py
```

  그 아래 산문의 `Tier C` → `추가 리뷰어`, `floor(A) + codex(B)` → `각도 수행자`, `## Reviewer composition (scope-driven)` → `## Angles and reviewers (scope-driven)`, `Review gate는 fan-out consent 게이트를` → `파이프라인은 fan-out consent 게이트를`, `security-reviewer + codex + Tier C 최대 6` → `security-reviewer + codex + 추가 리뷰어 최대 6`.

**(e) `## 파이프라인 흐름 …`** — 제목을 `## 파이프라인 흐름 (single-turn)` 으로, 머리 문단의 `Inter-gate progression과 Review gate fix-loop iteration은` → `fix-loop iteration은`, 다이어그램을 이것으로 바꾸고 「**v1.32.0 변경 요약**」 문단을 지운다:

```
┌─ single assistant turn ──────────────────────────────────────────────┐
│                                                                       │
│   user: /qg                                                           │
│       │                                                               │
│       ▼                                                               │
│   setup-qg.sh --ensure  (creates .claude/quality-gates/<sid>/...)     │
│       │                                                               │
│       ▼                                                               │
│   SKILL preflight  (kill switch)                                      │
│       │                                                               │
│       ▼                                                               │
│   trivia escape? ─── yes ──▶ verdict: not-certified (trivia)          │
│       │ no                                                            │
│       ▼                                                               │
│   qg iter loop (≤5)                                                   │
│     ① scope (session | branch | --paths)                              │
│     ② differential test (baseline vs sealed HEAD — every iteration)   │
│     ③ angles + reviewers (security · codex · specialists)             │
│     ④ framing-blind re-critique (doc-recritic)                        │
│     ⑤ synthesize → verdict: clean | defect | not-certified (<reason>) │
│       │                                                               │
│       ├── clean ──────────────────────────────────┐                   │
│       │                                           │                   │
│       └── findings remain ──▶ AskUserQuestion     │                   │
│                              ("findings remain..." │                  │
│                               Retry / Accept and   │                  │
│                               finish / Stop)       │                  │
│                                  │ Retry → next iteration             │
│       ▼                          ▼                                    │
│   Final summary  (Verdict · Iterations · Outcome · angles)            │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

**(f) `## Plan Discovery Sources (Runtime gate test-scope-validator)`** → `## Plan Discovery Sources (차등 테스트의 test-scope-validator)`, 본문 첫 문장의 `Runtime gate의` → `차등 테스트의`. `## Spec Discovery Sources (Runtime gate test-scope-validator + Review gate codex)` → `## Spec Discovery Sources (test-scope-validator + codex)`, 본문의 「**advisory only.** …」 문단을 이것으로:

```markdown
**advisory only.** spec이 발견되면 test-scope-validator가 그것을 1차 축으로 테스트 파일을
분류하고, codex 경로(`run_codex_reviewer.sh`)가 spec의 AC 섹션을 `<spec_context>`에
script-internal로 주입합니다. 어느 경우에도 판정을 **막지 않습니다.** spec이 없으면 loud
log를 출력하고 plan-기반 분류로 fallback합니다. (v9 에서 AC별 `ac_coverage` 출력은
사라졌다 — spec AC 런타임 검증이 사라지며 함께 거둔 주장이다.)
```

  **kill switch:** 줄의 `(ac_coverage 생략, codex …)` → `(codex \`<spec_context>\` 비움; validator는 plan-기반 분류)`.

**(g) `## 사전 요건`** — 표의 `Review gate` → `리뷰어`, `chrome-devtools-mcp / playwright … Runtime gate … 브라우저 자동화` 행을 지운다.

**(h) `### Tuning knobs`** — `MAX_REVIEW_ITERATIONS: 5 (Review gate 내부 …)` → `(파이프라인 fix-loop iteration 수)`, `DEVBREW_QUALITY_GATES_RUNTIME_MAX_RESOLUTIONS` 줄을 지운다.

**(i) `### Kill switches (보안 컨트롤)`** — 「**Reviewer 단위 disable (Review gate):**」 → 「**각도 · 리뷰어 단위 disable:**」, 그 표의 `DISABLE_SECURITY_REVIEWER` 행을 이것으로:

```markdown
| `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1` | 보안 각도의 `security-reviewer`만 skip. 재비판 · codex · 추가 리뷰어는 여전히 fire. **판정이 `not-certified (angle-absent)` 가 된다** — 탐지 0 이어도(v9 에서 의미가 바뀌었다: 전에는 배너와 advisory 한 줄이었다). 형제 `DISABLE_CODEX` 는 다른 전제 각도라 부재를 공시만 한다. |
```

  「**Runtime gate 단위 disable:**」 → 「**차등 테스트 · 스코프 단위 disable:**」, 그 표에서 `DISABLE_RUNTIME_SANDBOX` 행을 지우고 두 행을 더한다:

```markdown
| `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` | ② 차등 테스트를 통째로 건너뛴다(리뷰 대상 저장소의 코드를 호스트 권한으로 돌리지 않는다). 판정은 `not-certified (kill-switch)` 다 — `clean` 도 실패도 아니다. |
```

  그리고 표 **밖**(아래)에 한 문단:

```markdown
**`DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX`** 는 qg 파이프라인에서 더 읽히지 않는다(v9 —
샌드박스 executor 가 사라졌다). `scripts/qg-worktree.sh create-sandbox` 는 남아 있고 그 소비자는
`plugins/plugin-audit` 의 자체 테스트 격리다 — 이 스위치는 그 소비자에게만 효력이 있다.
```

  `DISABLE_SPEC_CONFORMANCE` 행의 `(ac_coverage 생략, codex …)` → `(codex \`<spec_context>\` 비움; validator는 plan-기반 분류)`.

**(j) `## 파이프라인 state`** — `pipeline.md` 설명 `(status, current_gate, iteration counters) + body (Gate Results, History)` → `(session_id · started_at · 선택적 worktree_path) + body (History)`.

**(k) 나머지 스윕** —

```bash
cd "$(git rev-parse --show-toplevel)"
git grep -n -P -i 'Runtime gate|Review gate|runtime-verifier|detect-runtime|2-게이트|2게이트|두 게이트|Decision [12]|block_policy|NEEDS_RESOLUTION|SKIP_WITH_EVIDENCE|RUNTIME_MAX_RESOLUTIONS|Tier [ABC]|ac_coverage|mutation.guard' -- plugins/quality-gates/README.md
```

  남은 매치는 인벤토리 처분대로 — 역사 서술(「vX.Y.Z 에서 …」 bullet 의 옛 이름)은 그 bullet 자체가 (b) 에서 지워졌는지 먼저 본다. 남기는 매치는 줄마다 이유를 보고서에 적는다.

- [ ] **Step 3: 코드 지도 · 인용 · e2e**
- `docs/philosophy/devbrew-harness-philosophy.md` — **코드 지도(파일 포인터)의 행만**: `runtime-gate.md` → `differential-test.md`, `runtime-verifier.md` 를 가리키는 행은 지운다(그 행이 가리키는 메커니즘이 다른 파일에도 있으면 그 파일로). **Law 2 scoped exception 산문은 건드리지 않는다**(PR5 가 `CLAUDE.md` 와 함께 옮긴다 — 부채 원장). 파일이 ~300줄 이상이면 목차 동기화가 필요한지 본다(절 이름을 바꾸지 않으면 불필요).
- `docs/plugin-authoring.md` — `2-gate` 류 인용과 `runtime-verifier` · `runtime-gate.md` 포인터를 새 이름으로.
- `plugins/quality-gates/tests/e2e-scenarios.md` — Runtime gate · verifier · Decision 시나리오는 지우지 않고 절 머리에 `> **v9 에서 제거된 표면** — 역사 기록으로 남긴다. 오늘의 파이프라인에는 대응 경로가 없다.` 를 단다(「Historical」 표기가 이미 있는 절과 같은 규칙). 살아 있는 시나리오 안의 옛 이름은 새 이름으로.

- [ ] **Step 4: 설계 §16 에 재결정을 기록한다** — `docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md` §16:
1. PR 표의 `**4b**` 행 「내용」 칸을 `verifier 제거 + 파이프라인 합치기 — SKILL · runtime-gate.md → differential-test.md · qg.md · 공개 인자 · 판정 어휘 상시 배선` 으로, 그 아래 새 행:
   `| **4c** | 토픽 스코프 배선 — resolve-topic.sh · combine-tips.sh → 선언 경로 · AC3–AC7 · AC15 · AC16 선언 쪽 · declaration-invalid · merge-conflict 발화 · PR1 이월 둘 · 중간 커밋 GC | 없음(선언이 없으면 기존 세 모드) |`
2. **순서 제약** 문장을 `1 → 2 → 3 → 4a → 4b → 4c → 5` 로. `PR 4b 가 PR 1 의 스크립트를 배선하고` → `PR 4b 가 봉인자를, PR 4c 가 나머지 PR 1 스크립트를 배선하고`.
3. 4a · 4b 재결정 블록 **아래**에 새 블록:

```markdown
**재결정 (P23, 2026-09-25) — PR4b 를 4b · 4c 로 나눈다.**
- **원래** — 4b 가 verifier 제거 · 게이트 합치기 · 스코프 배선을 함께 진다.
- **재결정** — 스코프 배선(토픽 선언 → 커밋 집합 → 합친 HEAD 트리)을 4c 로 뗀다. 4b 는
  breaking 부분(verifier 제거 · 한 파이프라인 · 판정 상시 배선)만 진다.
- **근거** — 실측한 4b 가 이 절이 분할한 이유를 다시 재현했다(1017줄 SKILL · 1218줄
  레퍼런스 재작성 · 판정 배선 · 합성기 정리 · 스코프 배선). 스코프 배선은 선언이 없으면 기존
  세 모드로 내려가는 **새 능력**이라(§6.2.5) 떼어 내도 breaking 경계가 깨지지 않는다.
  사람(사용자)이 이 재결정에 동의했다.
- **남는 것** — 선언 조각이 `#pr4c` 하나 더 는다. 4b 와 4c 사이 한 릴리스 동안 `Spec:`
  트레일러는 효과가 없다. HEAD 축의 봉인은 4b 가 먼저 배선한다 — 샌드박스가 사라지면
  `create-head` 가 붙을 커밋이 봉인뿐이기 때문이다.
```

4. 「**계획 단위는 PR 하나에 계획 하나다.**」 문장의 `(4a·4b 분할 뒤 여섯)` → `(4a·4b·4c 분할 뒤 일곱)`.
5. 「**각 PR 은 자기 `Spec:` 조각을 선언한다**」 의 `…-design.md#pr1\` … \`#pr5\`` 는 그대로(범위 표기).

설계 문서는 300줄 이상이다 — 새 헤딩을 더하지 않았으므로 목차는 그대로다.

- [ ] **Step 5: 통과 확인**

```bash
cd "$(git rev-parse --show-toplevel)"
export PYTHONDONTWRITEBYTECODE=1
for t in plugins/quality-gates/tests/test_readme_state_diagram_complete.sh plugins/quality-gates/tests/test_readme_scope_reconcile.sh \
         plugins/quality-gates/tests/test_impact_runtime_docs.sh plugins/quality-gates/tests/test_one_pipeline_surface.sh; do
  printf '%s ' "$t"; bash "$t" 2>&1 | grep -cE '^[[:space:]]*✗|^FAIL:'
done
bash "$CLAUDE_JOB_DIR/tmp/run-suite.sh" "$CLAUDE_JOB_DIR/tmp/t9.tsv"
```

- [ ] **Step 6: 커밋**

```bash
cd "$(git rev-parse --show-toplevel)"
git add plugins/quality-gates/README.md plugins/quality-gates/tests/test_readme_state_diagram_complete.sh \
        docs/philosophy/devbrew-harness-philosophy.md docs/plugin-authoring.md \
        plugins/quality-gates/tests/e2e-scenarios.md docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md
git add -u plugins/quality-gates/tests
git status --short
git commit -m "docs(qg): 한 파이프라인 문서화 · 설계 §16 에 4b/4c 분할 재결정" \
  -m "README 의 두 게이트 서술 · 다이어그램 · 환경 표를 한 파이프라인으로 옮기고, 부팅 앱 런타임 검증은 대체하지 않고 주장을 거둔다고 적는다. 설계 §16 에 스코프 배선을 4c 로 뗀 재결정(P23)을 기록한다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4b
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 10: mutation — 네 축 × 양성 대조

**Files:**
- Create (추적 안 함): `$CLAUDE_JOB_DIR/tmp/pr4b-mutations.md` → 미러
- Modify: 없음(변이는 커밋 뒤 사본에서 · 매번 되돌린다). 변이가 드러낸 구멍을 닫는 커밋만 만든다.

**Interfaces:**
- Consumes: Task 2–9 의 커밋 · 락 인벤토리의 근거 칸(「이 단언을 RED 로 만드는 변이」)
- Produces: 변이 표(PR 본문에 싣는다)

**규율** — (1) **커밋 후** 변이한다. 복원은 `git checkout HEAD -- <파일>` 이고 `git diff HEAD --stat` 이 빈 출력인지 확인한다(`git checkout --` 는 index 로 되돌린다). (2) `PYTHONDONTWRITEBYTECODE=1`(같은 길이 변이가 stale `.pyc` 를 못 넘는다). (3) 각 행에 **양성 대조** — 변이 전 GREEN, 변이 후 RED, 복원 후 GREEN 셋을 다 적는다. (4) **blast radius** — 변이 하나에 RED 가 되는 락 **전부**를 적는다(`run-suite.sh` 로). 기대한 락 밖이 RED 면 그것도 적는다 — 셸 본문 추출기 파손의 신호일 수 있다. (5) `any`→`all` 같은 변이는 공허참이 무관한 단언까지 무너뜨린다 — 쓰지 않는다.

- [ ] **Step 1: 변이 표를 채운다** — 축(삭제 · 추가 · 반전 · 형태 변경)을 먼저 적고 행을 채운다:

| # | 축 | 대상 | 변이 | RED 기대 락:케이스 |
|---|---|---|---|---|
| 1 | 추가 | `verdict.py` | `LEGACY_VERDICTS = {"PASS": "clean"}` 한 줄을 되살린다 | `test_verdict_vocabulary.sh:case_legacy_table_is_gone` |
| 2 | 추가 | `synthesize_findings.py` | `ap.add_argument("--adversarial", default="")` 를 되살린다 | `test_recritic_bridge.sh:case_adversarial_flag_is_gone` |
| 3 | 반전 | `synthesize_findings.py:_apply_raise` | `if new_rank < cur_rank:` → `if new_rank > cur_rank:` | 옮긴 raise 가드 케이스(인벤토리의 `convert` 행) |
| 4 | 형태 | `synthesize_findings.py:_fold_sev` | `.upper()` 를 뺀다 | `test_synthesize_findings_adjudication.py:test_fold_sev_is_the_one_fold` + 소문자 raise 케이스 |
| 5 | 반전 | `synthesize_findings.py:_degrade_block` | `if blocking:` → `if True:` | `test_recritic_bridge.sh:case_aux_death_discloses_without_not_clean_marker` · `case_gate_coercion_is_disclosure_not_block` (양성: `case_primary_death_keeps_not_clean_marker` GREEN 유지) |
| 6 | 삭제 | `synthesize_findings.py:main` | `blocking=ledger.blocks()` 인자를 뺀다(기본 False) | `case_primary_death_keeps_not_clean_marker` |
| 7 | 형태 | `seal-worktree.sh` | 인덱스 자리를 `"$main_root/.claude/quality-gates/seal-${sid_short}.index"` 로 되돌린다(`mkdir -p` 포함) | `test_seal_no_side_effects.sh:case_seal_succeeds_when_claude_dir_not_ignored`(권위 가드가 die → rc 2) |
| 7b | 삭제 | `seal-worktree.sh` | 7 에 더해 권위 가드(봉인 후 트리 검사)를 지운다 | 같은 케이스의 `봉인 트리에 임시 인덱스(와 .lock)가 없다` |
| 8 | 삭제 | `qg-worktree.sh:create-head` | 트리 대조 `[[ … ]] || die …` 두 줄을 지운다 | `test_runtime_contract_invariance.sh:case_create_head_asserts_sealed_commit` 의 merge_base · stale 음 (양성 짝은 GREEN 유지) |
| 9 | 형태 | `qg-worktree.sh:create-head` | 트리 대조를 `$2` 와 `git rev-parse HEAD` 의 커밋 대조로 바꾼다 | 같은 케이스의 양의 짝(봉인 커밋 ≠ HEAD) |
| 10 | 반전 | `setup-qg.sh` | 제거 인자 arm 의 `shift` 뒤에 `echo "Unknown argument: $1" >&2; exit 1` | `test_setup_qg.sh` Case 6 |
| 11 | 삭제 | `setup-qg.sh` | 제거 인자 공지 `echo` 줄을 지운다 | Case 6 의 공지 단언 · Case 7 |
| 12 | 삭제 | `setup-qg.sh` | `--paths)` arm 을 지운다 | Case 7 의 `--paths` 단언 |
| 13 | 삭제 | SKILL Step 4 펜스 | `--angles "$RV/angles.txt"` 를 지운다 | `test_pipeline_verdict_wiring.sh:case_every_synth_call_emits_verdict_and_angles` |
| 14 | 추가 | SKILL | 판정 인자 없는 합성기 호출 펜스를 하나 더한다 | 같은 케이스(`BAD:1`) |
| 15 | 반전 | SKILL 보안 dispatch | `fail-closed` → `fail-open` | `case_blocking_angle_dispatches_are_fail_closed` |
| 16 | 형태 | SKILL | `--reason kill-switch` → `--reason killswitch` | `case_reason_literals_are_closed_and_pinned`(`OUTSIDE:killswitch`) + `test_verdict_vocabulary.sh`(`MISSING:kill-switch`) |
| 17 | 삭제 | SKILL 각도 견본 | `different-premise:` 줄을 지운다 | `case_angle_template_is_total`(`PARSED` 부재) |
| 18 | 형태 | SKILL 파이프라인 절 | ② 항목을 ③ 뒤로 옮긴다 | `test_one_pipeline_surface.sh:case_pipeline_order` |
| 19 | 형태 | SKILL 파이프라인 절 | ② 항목을 `3. [Final Summary]` 뒤로 옮긴다(루프 밖) | `test_pipeline_verdict_wiring.sh:case_differential_runs_inside_every_iteration` |
| 20 | 추가 | 레퍼런스 | `**Step R7 — Mutation guard**` 헤딩 한 줄을 되살린다 | `test_one_pipeline_surface.sh:case_reference_step_set` |
| 21 | 추가 | SKILL | 아무 절에 `runtime-verifier` 한 단어를 더한다 | `case_old_surface_absent` |
| 22 | 추가 | SKILL | `header: "Gate scope"` 인 결정 도구 리터럴을 되살린다 | `case_no_gate_scope_question` |
| 23 | 추가 | `test_verdict_vocabulary.sh` 의 `debt` | `kill-switch` 를 되돌려 적는다 | 같은 락의 `OVERLAP:` |
| 24 | 삭제 | SKILL | Trivia escape 의 `--reason trivia` 펜스를 지운다 | `test_verdict_vocabulary.sh`(`MISSING:trivia`) + `case_reason_literals_are_closed_and_pinned`(`SET:`) |
| 25 | 삭제 | README | 새 다이어그램의 `② differential test` 줄을 지운다 | `test_readme_state_diagram_complete.sh` |
| 26 | 추가 | README | `Runtime gate dispatch` 한 줄을 되살린다 | 같은 락의 부재 검사 |

  **GREEN 기대 변이(과적합 점검)** — 이것들은 **GREEN 이어야** 한다:

| # | 변이 | 왜 GREEN 이어야 하나 |
|---|---|---|
| G1 | SKILL 각도 견본의 세 줄 순서를 바꾼다 | `angles.parse` 는 순서에 무관한 총 함수다 — 락이 순서에 묶였으면 과적합 |
| G2 | SKILL 파이프라인 절의 설명 문장을 뜻을 두고 표현만 바꾼다(①–⑤ 표지 유지) | 순서 락은 표지를 재지 산문 리터럴을 재지 않는다 |
| G3 | 레퍼런스의 R6 flaky 문단 표현만 바꾼다 | 스텝 집합 락은 헤딩만 잰다 |

- [ ] **Step 2: 락 인벤토리의 `retarget` · `convert` 행을 다시 태운다** — 각 행의 근거 칸 변이를 새 앵커에 걸어 RED 를 확인한다(Task 7 Step 8 에서 한 것을 **커밋 뒤** 한 번 더 — 그 사이 Task 8 · 9 가 같은 파일을 고쳤다).

- [ ] **Step 3: 구멍을 닫는다** — 기대한 RED 가 안 난 행(생존 변이)마다: 락에 케이스를 더하거나 단언을 좁혀 그 변이를 RED 로 만든 뒤, **다시 같은 변이를 태워** RED 를 확인하고 커밋한다. 닫지 않기로 한 생존은 이유와 함께 표에 남긴다(부채 원장 후보).

```bash
cd "$(git rev-parse --show-toplevel)"
git status --short          # 비어 있어야 한다(변이는 전부 복원됐다)
git diff HEAD --stat        # 비어 있어야 한다
mkdir -p ~/.claude/sdd-mirror/qg-gate-merge-pr4b
cp "$CLAUDE_JOB_DIR/tmp/pr4b-mutations.md" ~/.claude/sdd-mirror/qg-gate-merge-pr4b/
```

  구멍을 닫는 커밋이 있으면:

```bash
git add -u plugins/quality-gates/tests
git commit -m "test(qg): mutation 이 드러낸 구멍을 닫는다" \
  -m "<어느 변이가 생존했고 무엇을 더했는지 행 번호로>" \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4b
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 11: 회귀 · 범위 불변식 · bump · CHANGELOG · PR

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`(`version` 만) · `plugins/quality-gates/CHANGELOG.md` · `plugins/quality-gates/skills/quality-pipeline/SKILL.md`(제목 버전) · `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md`(제목 버전만) · `plugins/quality-gates/scripts/setup-qg.sh`(help 의 `REMOVED (vN)` 한 자리)
- Create (추적 안 함): `$CLAUDE_JOB_DIR/tmp/pr4b-final.tsv` · `$CLAUDE_JOB_DIR/tmp/pr4b-body.md` → 미러

**Interfaces:**
- Consumes: 전부
- Produces: PR

- [ ] **Step 1: 도출 집합 회귀 — 기준선과 행 단위로**

```bash
cd "$(git rev-parse --show-toplevel)"
bash "$CLAUDE_JOB_DIR/tmp/run-suite.sh" "$CLAUDE_JOB_DIR/tmp/pr4b-final.tsv"
join -t $'\t' -a1 -a2 -e MISSING -o 0,1.2,1.3,2.2,2.3 \
  <(sort "$CLAUDE_JOB_DIR/tmp/pr4b-baseline.tsv") <(sort "$CLAUDE_JOB_DIR/tmp/pr4b-final.tsv") \
  | awk -F'\t' '$2 != $4 || $3 != $5'
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p "test_*.py" 2>&1 | tail -3
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | grep '^FAIL:' | sort > "$CLAUDE_JOB_DIR/tmp/pr4b-final-harness-fails.txt"
comm -13 <(sort "$CLAUDE_JOB_DIR/tmp/pr4b-baseline-harness-fails.txt") "$CLAUDE_JOB_DIR/tmp/pr4b-final-harness-fails.txt"
```

  **기대** — `join` 출력의 모든 행이 설명 가능하다: (a) 이 PR 이 **더한** 락(`MISSING` → `0 0`), (b) 이 PR 이 **지운** 락(`… → MISSING`, 락 인벤토리의 `delete-file` 행과 1:1), (c) 선재 RED 가 **사라진** 행(어느 Task 의 어느 행이 사라지게 했는지). **rc 나 실패 줄 수가 늘어난 행은 0** 이다. 하네스의 `comm -13` 출력은 비어 있다(새 `FAIL:` 이름 0). unittest 총수의 변화를 지운 · 더한 케이스로 설명한다.

- [ ] **Step 2: 범위 불변식**

```bash
cd "$(git rev-parse --show-toplevel)"
git diff --stat origin/main...HEAD -- shared plugins/spec-distill plugins/plugin-audit \
  .claude-plugin/marketplace.json CLAUDE.md \
  plugins/quality-gates/scripts/resolve-topic.sh plugins/quality-gates/scripts/combine-tips.sh \
  plugins/quality-gates/scripts/diff-test-results.py plugins/quality-gates/scripts/run-test-selection.sh \
  plugins/quality-gates/scripts/check_qa_ledger.py plugins/quality-gates/agents/security-reviewer.md \
  plugins/quality-gates/agents/doc-recritic.md plugins/quality-gates/references/recritic-code-profile.md
git diff origin/main...HEAD -- plugins/quality-gates/.claude-plugin/plugin.json
git diff origin/main...HEAD -- plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md
git grep -n -P 'resolve-topic\.sh|combine-tips\.sh' -- plugins/quality-gates/skills plugins/quality-gates/commands || echo "OK 4c 스크립트 호출자 0"
```

  **기대** — 첫 명령 빈 출력. `plugin.json` 은 `version` 한 줄만(Step 3 뒤). publishing SKILL 은 제목 한 줄만(Step 3 뒤). `OK 4c 스크립트 호출자 0`.

- [ ] **Step 3: 머지 직전 동기화 · 버전을 정한다**

```bash
cd "$(git rev-parse --show-toplevel)"
git fetch origin --quiet
git rev-list --count HEAD..origin/main
git show origin/main:plugins/quality-gates/.claude-plugin/plugin.json | grep '"version"'
```

  `origin/main` 이 움직였으면 **merge 한다**(rebase 금지): `git merge --no-edit origin/main`. 충돌이 없어도 `plugin.json` · `CHANGELOG.md` · SKILL 을 눈으로 본다(같은 버전 문자열은 충돌 없이 병합된다). 머지 뒤 Step 1 을 다시 돈다.

  버전 = `origin/main` 의 qg major + 1 `.0.0`(오늘 관측값 8.5.0 → **9.0.0**). 세 자리를 같은 값으로:
  - `plugins/quality-gates/.claude-plugin/plugin.json` 의 `"version"`
  - `skills/quality-pipeline/SKILL.md` · `skills/publishing-pr-understanding/SKILL.md` 제목의 `(vX.Y.Z)` — 하네스가 제목 major 를 `plugin.json` major 와 대조한다
  - `setup-qg.sh` help 의 `REMOVED (vN)`

- [ ] **Step 4: CHANGELOG** — `plugins/quality-gates/CHANGELOG.md` 맨 위(기존 형식을 본다)에 Korean-primary 로(`check-changelog-korean-primary.py` 가 잰다):

```markdown
## [<정한 버전>] — <오늘 날짜>

**breaking** — 두 게이트가 한 파이프라인이 된다. 판정은 `clean` · `defect` · `not-certified (<사유>)` 셋이다.

### Removed
- **`runtime-verifier` agent** — 부팅되는 앱의 런타임 행위 검증을 **대체하지 않고 주장을 거둔다**(설계 §6.5.3). 이 설치본이 잃는 것: **브라우저 플로우**(chrome-devtools-mcp / playwright 구동) · **spec Acceptance Criteria 런타임 검증** · **mutation guard**(verifier 의 쓰기를 잡던 git-diff 가드 — 쓰기 권한 agent 가 사라져 가드할 대상이 없다).
- `scripts/detect-runtime.sh` · Decision 1(게이트 범위 질문) · Decision 2(런타임 범위 + block policy) · NEEDS_RESOLUTION 해소 루프.
- 공개 인자 `both` · `review` · `runtime` · `--skip-runtime` — 받으면 한 줄 공지 후 그대로 진행한다(하드 오류가 아니다).
- 환경 스위치 `DEVBREW_QUALITY_GATES_RUNTIME_MAX_RESOLUTIONS` — **대상 소멸**(해소 루프가 사라졌다). 통제를 없앤 것이 아니라 통제할 대상이 사라진 것이다.
- `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX` 의 qg 파이프라인 효력 — **대상 소멸**(샌드박스 executor). 스위치 자체는 `qg-worktree.sh create-sandbox` 의 소비자인 plugin-audit 에 남는다.
- `test-scope-validator` 의 advisory `ac_coverage` 출력 — `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE` 는 그만큼 **축소**된다(codex `<spec_context>` 와 validator 의 spec 축은 그대로).
- 합성기 `--adversarial` · `--legacy-verdict` · 옛↔새 판정 어휘 매핑표(AC23) · `downgrade` 판정.

### Changed
- `/qg` 는 ① 스코프 → ② 차등 테스트(매 iteration, 기준선 대비) → ③ 각도 + 리뷰어 → ④ 재비판 → ⑤ 합성 · 판정의 한 파이프라인이다. `references/runtime-gate.md` 는 `references/differential-test.md` 가 됐다.
- 합성기는 매 실행 `--emit-verdict` · `--angles` 로 판정을 낸다. SKILL 은 `verdict:` 줄 하나를 판정으로 읽는다.
- **`DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER` 의 의미** — loud advisory → 보안 각도 `absent` → 판정 `not-certified (angle-absent)`.
- `security-reviewer` 디스패치 처분 `fail-open` → `fail-closed`(판정 각도와 같다).
- HEAD 축은 샌드박스 대신 `seal-worktree.sh` 의 봉인에서 선다. 봉인 인덱스는 `.git` 안에 둔다 — `.claude/` 를 무시하지 않는 리포에서도 봉인된다. `create-head` 는 인자의 트리를 지금 다시 뜬 봉인과 대조한다.
- 본 보고서의 `**이 실행은 clean이 아니다**` 마커는 차단(항목 소실 · 셀 수 없음 · 주 판정자 사망)에만 선다. 보조 입력 사망 · 판정을 바꾼 강제는 `공시(판정을 막지 않음)` 로 드러난다.
- codex finding 의 저자 토큰은 `codex-reviewer` 로 정한다.

### Added
- `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` — 차등 테스트를 건너뛴다. 판정은 `not-certified (kill-switch)`.
- 락: `tests/test_one_pipeline_surface.sh` · `tests/test_pipeline_verdict_wiring.sh` · `tests/lib/recritic_fixture.sh`.

### Fixed
- `/qg --paths <glob>` 가 `setup-qg.sh` 에서 `Unknown argument` 로 죽던 것 · `--gc` 를 다른 인자와 함께 줄 때 죽던 것.

### Security
- persona 편집: `runtime-verifier.md` 제거 · `test-scope-validator.md` 의 `ac_coverage` 절 제거. 보안 각도 처분 fail-closed.
```

- [ ] **Step 5: 커밋 · 미러 · push · PR**

```bash
cd "$(git rev-parse --show-toplevel)"
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | grep -E 'major' | head -3
python3 plugins/quality-gates/scripts/check-changelog-korean-primary.py 2>&1 | tail -2
git add plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md \
        plugins/quality-gates/skills/quality-pipeline/SKILL.md \
        plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md plugins/quality-gates/scripts/setup-qg.sh
git status --short
git commit -m "chore(qg)!: quality-gates <정한 버전> — 한 파이프라인" \
  -m "breaking — 두 게이트를 한 파이프라인으로 합치고 runtime-verifier 를 지운다. 판정은 clean · defect · not-certified 셋이다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4b
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
bash "$CLAUDE_JOB_DIR/tmp/run-suite.sh" "$CLAUDE_JOB_DIR/tmp/pr4b-final.tsv"
cp "$CLAUDE_JOB_DIR"/tmp/pr4b-final* ~/.claude/sdd-mirror/qg-gate-merge-pr4b/
git push -u origin feature/qg-gate-merge-pr4b
```

  PR 본문(`$CLAUDE_JOB_DIR/tmp/pr4b-body.md`, 미러에도)의 절:
  1. **요약** — 한 문단 + 버전.
  2. **🔒 보안 리뷰 요청** — ① `runtime-verifier.md` persona 제거(무엇을 잃는가 = CHANGELOG Removed 첫 행) ② `test-scope-validator.md` 편집(`ac_coverage` 절 제거 · 분류 축 불변) ③ `security-reviewer` 처분 fail-closed ④ 보안 kill switch 의미 변경. 「리뷰어께 부탁」 한 줄.
  3. **이 PR 이 지는 것** — 계획의 표.
  4. **§16 재결정(P23) — 4b 를 4b · 4c 로** — R-U.
  5. **판정 — 사용자가 뒤집을 수 있는 자리** — R-U … R-AH 한 줄씩(무엇 · 틀리면) + 실행 중 컨트롤러가 정한 것(SDD 원장의 `Ruling:` 전부).
  6. **선재 RED — 착수와 종료** — `join` 결과 표.
  7. **변이 표** — Task 10.
  8. **부채 원장** — 아래 표 그대로 + 실행 중 더해진 행.
  9. **검증 과정** — SDD 모델 · 수정 라운드 수 · 리뷰가 실측으로 찾은 결함.
  10. 마지막 줄 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

```bash
gh pr create --base main --head feature/qg-gate-merge-pr4b \
  --title "feat(qg)!: 한 파이프라인 — runtime-verifier 제거 · 판정 상시 배선 (PR4b)" \
  --body-file "$CLAUDE_JOB_DIR/tmp/pr4b-body.md"
```

  **머지는 사용자가 한다** — `! gh pr merge <n> --merge`. `gh api` 로 우회하지 않는다. 머지 뒤 `gh pr view <n> --json state` 가 `MERGED` 인지 직접 확인한다.

---

## 부채 원장 — 미룬 것은 전부 여기 이름이 있다

| 부채 | 소유자 | 무엇이 붙잡고 있는가 |
|---|---|---|
| 토픽 스코프 배선 — `resolve-topic.sh` → 경계 · 끝점, `combine-tips.sh` → 합친 HEAD 트리, AC3–AC7 · AC15 · AC16 의 선언 쪽 | **PR4c** | 설계 §16 의 4c 행(Task 9) |
| `declaration-invalid` · `merge-conflict` 의 발화 지점 | **PR4c** | `test_verdict_vocabulary.sh` 의 `debt` 리터럴 · `test_pipeline_verdict_wiring.sh` 의 사유 핀 |
| PR1 이월 둘 — `--sort=refname` 미고정 · `origin/HEAD`/base-remote-ref 전용 락 | **PR4c** | PR1 · PR2 본문 + 이 표 |
| 순차 합치기 중간 커밋 · `create-head` 재봉인 커밋의 GC(unreachable) | **PR4c** | 이 표 · `combine-tips.sh` 헤더 |
| `create-sandbox` · `mutation-guard` 의 소유를 plugin-audit 로 옮기기 | 후속 | R-W · `qg-worktree.sh` 헤더 |
| `CLAUDE.md` Law 2 *Scoped exception (qg v2.2.0)* 이 한 릴리스 동안 사라진 agent 를 이름으로 박는다 · `plugin.json`/`marketplace.json` 의 「2-gate」 · 철학 문서의 같은 산문 | **PR5** | 설계 §16 의 5 행 · AC19 · AC20 |
| §13 수동 e2e | **PR5** | 설계 §13 |
| `--show-low-confidence` — 합성기 안내 문구가 가리키는데 `setup-qg.sh` 가 모른다(선재) | 후속 | 이 표 |
| 동률 raise 의 `gate=False` 공시에 락이 없다(`<=` 변이 생존 — PR4a 이월) | 후속 | 이 표 |
| RV 중간 파일이 `mktemp -d` — 플러그인 네임스페이스 밖(PR4a 이월) | 후속 | 이 표 |
| raw `agent: [목록]` 이 `dedup()` 에서 TypeError(선재, PR3 이월) | 후속 | 이 표 |
| 원장 파일 이름 `runtime-evidence.md` 에 옛 게이트 이름 | **해소하지 않는다** | R-AG — `qg-gc.py` 세션 표식 |
| 각도 파일은 모델이 쓴다 — 락은 형식만 잰다 | **해소하지 않는다** | 설계 §15-4 · `test_pipeline_verdict_wiring.sh` 머리 주석 |
| `check_wiring.py` 의 줄번호-키 면제 | **해소하지 않는다(구조적)** | 매 PR 재앵커 |

---

## Self-Review

**1. 스펙 커버리지** — §16 의 4b 행(R-U 로 좁힌 뒤)과 PR4a 부채 원장의 PR4b 행을 하나씩 대조했다:
- verifier 제거(§12 제거 목록) → Task 7 · 샌드박스 배관 → Task 4(봉인자) + R-W · 게이트 합치기 → Task 7 · 공개 인자(§6.5.1 1–4) → Task 5 · 7 · env 스위치(5–9) → Task 5(6) · 6(7) · 8(9) · 9(5 문서) · 판정 어휘 상시 배선 → Task 8 · AC23 → Task 2 · AC21 → Task 7 Step 9 · AC14(봉인) → Task 4 · §6.4.1 `create-head` assert → Task 4 · §6.3.5 처분 → Task 8 · CHANGELOG 의 잃는 것 이름 → Task 11.
- PR4a 부채: 상시 배선 · `adjudication: filled` · codex 토큰 → Task 8 · security fail-closed → Task 8 · 사유 넷 → Task 8(둘) + 4c(둘) · AC23 → Task 2 · `--adversarial` 과 딸린 것 → Task 2 · 보조 입력 사망 → Task 3 · verifier 등 → Task 5–8 · PR1 이월 → 4c.
- 설계 §6.5.1 8행(`DISABLE_RUNTIME_TEST_VALIDATION`)은 살아 있는 독자가 0 이다 — 할 일이 없다(설계 문서 스스로 그렇게 적었다).

**2. 플레이스홀더 스캔** — `<정한 버전>` · `<오늘 날짜>` · `<이 커밋을 쓴 실제 모델>` 은 실행 시점에 정해지는 값이고 정하는 규칙이 적혀 있다. 「인벤토리가 도출한다」는 자리는 도출 명령과 처분 규칙이 Task 1 에 있다 — 목록을 계획에 박지 않는 것이 lesson 2(열거가 아니라 도출)다.

**3. 타입 · 이름 일관성** — `promote_new_findings(raw_new, existing, *, author, ledger=None)` · `_fold_sev` · `_apply_raise` · `render(..., blocking=False)` · `_degrade_block(report, blocking)` · `rf_prep`/`rf_reply`/`rf_synth` · 절 이름 `## Pipeline`/`## Review`/`## Differential test`/`## Angles and reviewers (scope-driven)`/`## Fix-loop decision`/`## Max-iter decision` · 레퍼런스 스텝 집합 · 사유 핀 `error-axis kill-switch scope-empty silent-drop trivia` · 머리줄 두 문자열 — Task 2·3·7·8·10 에서 같은 철자다.

**4. Review Focus** — 다섯 줄 각각의 테스트가 소유 Task 에 있다: 1 → Task 4 · 2 → Task 5 · 3 → Task 8 · 4 → Task 3 · 5 → Task 8.

---

## Execution Handoff

계획은 `docs/superpowers/plans/2026-09-25-qg-gate-merge-pr4b.md` 에 있다. SDD 로 돌리면 구현 sonnet · Task 리뷰 opus · 최종 리뷰 fable 이고, 원장은 매 갱신마다 `~/.claude/sdd-mirror/qg-gate-merge-pr4b/` 로 복사한다. Task 7 은 한 커밋에 SKILL · 레퍼런스 · 삭제 · 락 이주가 모이는 가장 큰 Task 다 — 구현자는 sonnet 으로 시작하되 수정 라운드 4 이상이면 한 단계 위 모델로 올린다.
