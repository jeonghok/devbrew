# qg 판정 어휘 세 값 + 해상도 공시 구현 계획 (PR2/5)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 판정값을 `clean` · `defect` · `not-certified`(+닫힌 열거 `reason`) 세 값으로 내는 **결정론 산출자**를 들여놓고, 차등 산출물이 그 산출자의 입력을 실제로 싣게 만든다. 소비자 배선은 PR4 다.

**Architecture:** 새 책임은 새 모듈로 간다 — `scripts/verdict.py` 하나가 닫힌 열거 · 우선순위 · 옛→새 매핑표(AC23)를 전부 갖는다. 그래야 PR4 가 매핑표를 **한 파일에서** 지울 수 있다. `synthesize_findings.py` 에는 **진입 한 줄**(`--emit-verdict`, 기본 off)만 들어가고, off 일 때 stdout 은 PR2 이전과 **바이트 동일**하다. `diff-test-results.py` 는 판정을 내지 않는다 — **판정의 입력**을 넓힌다: 오늘 `attribution_status: degraded` 한 값에 접혀 밖에서 보이지 않는 여섯 원인을 `degrade_causes:` 로 풀고, `pre_existing > 0` 일 때 해상도 공시 줄을 per-adapter 와 aggregate **양쪽에** 싣는다.

**Tech Stack:** Python 3.12+ (표준 라이브러리 + PyYAML) · bash 3.2 호환 회귀 락 · `shared/tests/assert.sh`

**Spec:** `docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md` — §6.4.2(해상도 공시) · §6.4.3(판정 어휘) · §11(AC) · §13(검증) · §16(분할)

---

## Global Constraints

이 절의 요구는 **모든 Task 의 요구에 묵시적으로 포함**된다.

- **Python 바닥은 3.12** (qg 8.0.0). 새 `.py` 는 3.12 에서 돌아야 한다.
- **`plugin.json` bump + `CHANGELOG.md` 항목**을 이 PR 안에서 한다. 버전 문자열은 **머지 직전에** 정한다 — 브랜치에서 박지 않는다(먼저 머지되는 쪽이 이긴다). 예정 등급은 **minor**(새 표면, breaking 없음).
- **`Spec:` 트레일러는 `docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr2`** 다. `#pr1` 을 쓰면 PR1 을 합집합으로 재리뷰한다(설계 §16).
  트레일러와 `Co-Authored-By:` 는 **마지막 `-m` 단락 하나에 함께** 넣는다 — 트레일러 파서는 마지막 단락만 읽는다.
- **커밋 attribution 은 실제로 그 커밋을 쓴 모델을 적는다**(PR1 Ruling 9).
- **셸 테스트는 리포 루트에서 돌린다.** 스크립트 경로를 상대로 쓰는 락이 있다.
- **mutation 은 `PYTHONDONTWRITEBYTECODE=1` 로 돌린다** — 같은 길이 변이가 stale `.pyc` 를 못 넘는다.
- **변이 전에 커밋한다.** 복원은 `checkout HEAD -- <path>` 이고 `diff HEAD` 로 확인한다.
- **`verdict.py` 는 실제 파일이다 — 심볼릭 링크가 아니다.** `shared/` 의 공유 모듈(`adjudication.py` · `render_disposition.py`)은 `ls-files -s` 에서 mode `120000` 인 링크이고, 판정 어휘는 qg 의 것이라 공유 대상이 아니다.
- **`shared/adjudication/` 은 건드리지 않는다.** `Ledger.blocks()` 가 필요하면 `main()` 에서 호출해 인자로 넘긴다 — `report()` 에 키를 더하면 spec-distill 쪽 소비자와 `shared/tests/test_adjudication_wiring.sh` 를 같은 PR 에서 함께 옮겨야 한다.
- **워크트리 격리** — 메인 체크아웃으로 이동하지 않는다. bare stash 금지(스택 공유). 최신화는 **merge**, rebase 금지.
- **문서는 한국어 primary.** 영어는 식별자 · 고유명사 · 코드 · 원문 인용에 한정.

## 이 PR 이 지는 AC

- **AC8** — 판정값이 `clean` · `defect` · `not-certified` 셋뿐이고, `not-certified` 는 **항상** 닫힌 열거의 `reason` 을 동반한다.
- **AC9** — kill switch 로 차등 테스트가 생략된 실행의 판정이 `not-certified (kill-switch)` 다.
- **AC13** — `counts.pre_existing > 0` 인 실행의 산출물에 해상도 공시 줄이 있다.
- **AC23** — 옛↔새 매핑표가 이 PR 에 **들어오고**, PR4 가 지울 수 있게 한 자리에 모여 있다.

**이 PR 이 지지 않는 것** — AC10/AC10a/AC11/AC12(각도 상태)는 **PR3**, AC1/AC2/AC15/AC16 의 배선과 §13 수동 e2e 는 **PR4**, AC19/AC20/AC22 는 **PR5**. AC7 의 산출자(`combine-tips.sh` 의 충돌 목록)는 **PR1 에서 이미 main 에 있다** — 이 PR 은 그 사유(`merge-conflict`)가 열거 안에 있고 우선순위를 통과한다는 것까지만 진다.

## 전제 — PR1 이 main 에 남긴 것 (#163)

이 PR 은 아래를 **이미 있는 것으로** 전제한다. 건드리지 않는다.

| 경로 | 계약 |
|---|---|
| `plugins/quality-gates/scripts/resolve-topic.sh` | `resolve <topic-key> [--seal <B>]` → 10키 `key: value` · `commits <topic-key>` → SHA 목록, 非-`ok` 상태면 **exit 3** |
| `plugins/quality-gates/scripts/seal-worktree.sh` | `seal <session-id>` → 봉인 커밋 SHA |
| `plugins/quality-gates/scripts/combine-tips.sh` | `tree` `status` `steps` `intermediates` `conflicts` `failed_at` — `status: merge-conflict` 이 AC7 의 산출자다 |
| `plugins/quality-gates/tests/test_topic_boundary.sh` | 93단언 |
| `plugins/quality-gates/tests/test_seal_no_side_effects.sh` | 22단언 |

**셋 다 호출자가 0 이다.** 이 PR 도 배선하지 않는다.

## PR1 에서 넘어온 이월 — 이 계획이 이름을 붙인다

- **`--sort=refname` 미고정** — `resolve-topic.sh` 의 로컬-이름 우선 dedupe 가 `for-each-ref` 의 «기본» 정렬에 의존한다. **이 PR 범위 밖**(그 파일을 건드리지 않는다). PR4 가 배선하며 닫거나 한 줄짜리 독립 fix 로 낸다.
- **`origin/HEAD` · base 원격 ref 전용 락 없음** — 기존 base_ref-조상 검사가 구조적으로만 막는다. 역시 이 PR 범위 밖 · PR4 의 빚.
- **§13 수동 e2e 는 PR4 의 빚이다** — 호출자가 0 인 동안에는 수행 불가다. 이 PR 에서도 못 한다.
- **PR1 계획문서(`2026-09-22-qg-scope-machine-pr1.md`) Task 2 산문의 「9키」는 동결된 이력**이다. 정본은 설계문서의 **10키**다. 그 문장을 고치지 않는다.
- **★ 가장 비싼 교훈 — 단언마다 「어떤 변이가 이것을 깨뜨려야 하는가」를 계획에 적는다.** PR1 의 지배적 결함이 「통과하지만 아무것도 재지 않는 락」 **아홉 건**이었고 그중 셋은 그것을 고치다 한 층 위에서 다시 만든 것이다. 이 계획의 **모든 테스트 스텝은 `깨뜨려야 하는 변이:` 줄을 갖는다.** 그 줄이 없는 단언은 이 계획의 결함이고, 구현자는 그것을 발견하면 ledger 에 적고 변이를 스스로 정해 채운다.

## 계획이 내린 판정 — 설계 문면을 넘어선 자리 셋

구현자는 이것을 **결정된 것으로** 받는다. 사용자가 뒤집으면 그때 바꾼다.

**R-A. `expected-empty` 와 `no-adapters` 는 `scope-empty` 로 간다.**
설계 §6.4.3 은 `degraded` 의 여섯 원인을 전부 받는다고 적었지만, `not expected`(영향분 0개)에 대응하는 `reason` 이 열거에 없다. 열거는 닫혀 있고(AC8) 12번째 값을 더하면 설계가 정하지 않은 어휘가 는다. `scope-empty` 의 실질은 「대조할 대상이 0 인데 변경은 있다」이고 영향분 0개가 정확히 그 상태다 — 그쪽으로 보낸다.
*틀렸을 때의 비용* — 사람이 「리뷰 스코프가 빈 것」과 「테스트 선택이 빈 것」을 사유로 구별하지 못한다. 대안은 12번째 값 `selection-empty` 이고, 고르면 `verdict.py` 의 `REASONS` 한 줄과 매핑 한 줄만 바뀐다.

**R-B. `defect` 는 「채택된 finding 이 하나라도 있으면」이다 — severity 를 묻지 않는다.**
설계는 「`NEW_REGRESSION` · `NEW_TEST_RED` · 채택된 finding」이라고만 적었다. severity 문턱을 두면 이 PR 이 조용히 게이트를 **약화**시킨다(오늘은 `SUGGESTION` 하나로도 iter 경계 결정이 뜬다).
*틀렸을 때의 비용* — `SUGGESTION` 만 남은 실행이 `defect` 가 되어 기계 소비자가 막는다. 뒤집으려면 `decide()` 호출 인자 하나만 바뀐다.

**R-C. `not-certified` 는 `reason:`(결정 하나)과 `reasons:`(전부) 둘을 낸다.**
AC8 은 단수 `reason` 만 요구한다. 그런데 한 실행에서 사유가 여럿 설 수 있고(`silent-drop` + `granularity-smear`), 하나만 내면 나머지가 소실된다 — 헌장의 「무엇이 degrade 든 언제나 드러낸다」와 충돌한다. `reason:` 은 열거 순서가 정하는 **결정적** 하나이고 `reasons:` 는 전부다.
*틀렸을 때의 비용* — PR4 의 소비자가 키 하나를 더 무시해야 한다. 락이 `reason ∈ reasons` 를 핀한다.

---

## 파일 구조

**신설**

| 경로 | 책임 |
|---|---|
| `plugins/quality-gates/scripts/verdict.py` | 세 값 · 닫힌 `reason` 열거 · 우선순위 · 옛→새 매핑표(AC23) · 차등 YAML 에서 사유 도출. 순수 함수 + CLI. **여기 밖에 판정 어휘를 두지 않는다** |
| `plugins/quality-gates/tests/test_verdict_vocabulary.sh` | AC8 · AC9 · AC23 · 우선순위 · fail-closed |
| `plugins/quality-gates/tests/test_resolution_disclosure.sh` | AC13 — per-adapter **와** aggregate 양쪽 |

**수정**

| 경로 | 무엇을 |
|---|---|
| `plugins/quality-gates/scripts/diff-test-results.py` | `degrade_causes:` 신설(두 모드) · `resolution_disclosure:` 신설(두 모드) · `parse_adapter_yaml` 이 둘을 읽음 |
| `plugins/quality-gates/scripts/synthesize_findings.py` | `--emit-verdict` · `--differential` · `--reason` · `--legacy-verdict` 진입 한 줄. 기본 off = stdout 바이트 동일 |
| `plugins/quality-gates/tests/test_diff_test_results.py` | `degrade_causes` 총 함수 · aggregate 전파 케이스 |
| `plugins/quality-gates/.claude-plugin/plugin.json` · `CHANGELOG.md` | bump + 항목 |

**건드리지 않는 것** — `shared/adjudication/*` · `resolve-topic.sh` · `seal-worktree.sh` · `combine-tips.sh` · `SKILL.md` · `runtime-gate.md` · `qg.md` · `runtime-verifier.md`. 이 PR 이 저 파일들을 diff 에 담으면 그 자체가 범위 위반이다.

---

### Task 1: 착수 — baseline 포착과 범위 불변식

**Files:**
- Create: `$CLAUDE_JOB_DIR/tmp/pr2-baseline.tsv` (리포 밖 · 커밋하지 않는다)
- Create: `$CLAUDE_JOB_DIR/tmp/pr2-baseline.sh`

**Interfaces:**
- Consumes: 없음 (첫 Task)
- Produces: `pr2-baseline.tsv` — `<파일>\t<rc>\t<실패 줄 수>` 3열. Task 8 의 회귀 대조가 이것을 1차 키(`rc`) · 2차 키(`실패 줄 수`)로 쓴다.

- [ ] **Step 1: baseline 스크립트를 리포 밖에 쓴다**

```bash
mkdir -p "${CLAUDE_JOB_DIR:-/tmp}/tmp"
cat > "${CLAUDE_JOB_DIR:-/tmp}/tmp/pr2-baseline.sh" <<'SH'
#!/usr/bin/env bash
# rc 만으로는 «이미 RED 인 파일 안의 새 실패»가 원리적으로 안 보인다 — 실패 «줄 수»를
# 2차 키로 함께 적는다(설계 §13 「선재 RED 기준선」).
set -u
OUT="$1"
: > "$OUT"
export PYTHONDONTWRITEBYTECODE=1
for f in plugins/quality-gates/tests/test_*.sh shared/tests/test_*.sh plugins/spec-distill/tests/test_*.sh; do
  [ -e "$f" ] || continue
  out=$(bash "$f" 2>&1); rc=$?
  fails=$(printf '%s\n' "$out" | grep -cE '(✗|^FAIL[: ]|^  FAIL)')
  printf '%s\t%s\t%s\n' "$f" "$rc" "$fails" >> "$OUT"
done
for f in plugins/quality-gates/tests/test_*.py shared/tests/test_*.py plugins/spec-distill/tests/test_*.py; do
  [ -e "$f" ] || continue
  out=$(python3 "$f" 2>&1); rc=$?
  fails=$(printf '%s\n' "$out" | grep -cE '^(FAIL|ERROR):')
  printf '%s\t%s\t%s\n' "$f" "$rc" "$fails" >> "$OUT"
done
sort -o "$OUT" "$OUT"
SH
```

- [ ] **Step 2: 리포 루트에서 돌려 baseline 을 잡는다**

Run: `bash "${CLAUDE_JOB_DIR:-/tmp}/tmp/pr2-baseline.sh" "${CLAUDE_JOB_DIR:-/tmp}/tmp/pr2-baseline.tsv"`
그다음: `awk -F'\t' '$2 != 0' "${CLAUDE_JOB_DIR:-/tmp}/tmp/pr2-baseline.tsv"`

Expected: 선재 RED 가 몇 건 나온다. PR1 머지 후 관측된 것은 `test_codex_backward_compat.sh` 와 `test_runner_adapters.sh` 둘이다.

- [ ] **Step 3: 선재 RED 마다 «왜 면제인가»를 ledger 에 적는다**

목록만 적으면 그 RED 는 풍경이 되어 질문이 영구히 닫힌다. 각 줄에 한 문장:

```
선재 RED: <파일> — rc=<n> fails=<m> — <이 PR 이 닿지 않는 이유 한 문장>
```

**`test_runner_adapters.sh` 는 주의해서 본다** — 이 파일은 `diff-test-results.py` 를 소비한다. 이미 RED 이므로 rc 로는 이 PR 이 만든 새 실패가 안 보인다. **실패 줄 수가 baseline 과 같아야 한다**는 것이 이 파일의 유일한 신호다.

- [ ] **Step 4: 이 PR 의 범위 불변식을 ledger 에 적는다**

```
범위 불변식 — 이 PR 의 diff 는 아래 여섯 경로 밖으로 나가지 않는다:
  plugins/quality-gates/scripts/verdict.py            (신설)
  plugins/quality-gates/scripts/diff-test-results.py
  plugins/quality-gates/scripts/synthesize_findings.py
  plugins/quality-gates/tests/test_verdict_vocabulary.sh      (신설)
  plugins/quality-gates/tests/test_resolution_disclosure.sh   (신설)
  plugins/quality-gates/tests/test_diff_test_results.py
  + plugin.json · CHANGELOG.md · 이 계획문서
```

Task 8 이 이것을 `diff --name-only` 로 대조한다.

- [ ] **Step 5: 커밋 없음**

이 Task 는 리포를 건드리지 않는다. 산출물은 전부 리포 밖이다.

---

### Task 2: `diff-test-results.py` — degrade 의 «원인» 을 밖으로 낸다

**왜 이것이 먼저인가.** 설계 §6.4.3 의 `reason` 닫힌 열거는 `degraded` 의 여섯 원인을 전부 받는다고 적었다. 그런데 오늘 이 스크립트가 **내보내는** 것은 `attribution_status: degraded` 한 값과 플래그 둘(`silent_drop` · `baseline_unrunnable`)뿐이다 — `error_axis_seen` · `not expected` · `bulk && pre_existing` · `smeared` 넷은 밖에서 **보이지 않는다**. 이것을 먼저 열지 않으면 Task 4 의 어휘 락은 입력이 존재하지 않는 함수를 재게 된다(= PR1 이 아홉 번 만든 「통과하지만 아무것도 재지 않는 락」의 한 층 위 변종).

**Files:**
- Modify: `plugins/quality-gates/scripts/diff-test-results.py` — 모듈 상수 1 · `per_adapter()` · `parse_adapter_yaml()` · `_aggregate()`
- Test: `plugins/quality-gates/tests/test_diff_test_results.py`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `DEGRADE_CAUSES: tuple[str, ...]` — 모듈 상수, 닫힌 열거 7값
  - per-adapter · aggregate stdout 에 `degrade_causes: [<c>, ...]` 한 줄 (**항상** 나간다 — 비면 `[]`)
  - `parse_adapter_yaml(path) -> (runner, status, flags, counts, causes)` — **5-튜플로 바뀐다**(기존 4-튜플 호출자는 이 파일 안의 `_aggregate` 하나뿐이다)

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `plugins/quality-gates/tests/test_diff_test_results.py` 끝(`if __name__` 앞)에 추가

```python
class DegradeCauses(unittest.TestCase):
    """degrade 의 «원인» 이 밖으로 나간다 (PR2 — 설계 §6.4.3 의 reason 열거 입력)."""

    def causes_of(self, out: str) -> list[str]:
        """`degrade_causes: [...]` 를 정확히 한 번 읽는다. 0회도 2회도 실패다."""
        hits = re.findall(r"^degrade_causes: \[(.*)\]$", out, re.M)
        self.assertEqual(len(hits), 1, f"degrade_causes 줄이 {len(hits)}회: {out}")
        return [c.strip() for c in hits[0].split(",") if c.strip()]

    def test_clean_run_emits_empty_list_not_absent_line(self):
        # 부재와 «빈 목록» 은 다른 사실이다. 줄 자체가 없으면 소비자는 이 스크립트가
        # 옛 판본인지 degrade 가 0인지 구별할 수 없다.
        rc, out, _ = run_diff(["u"], [("u", "pass", "0")], [("u", "pass", "0")])
        self.assertEqual(rc, 0, out)
        self.assertIn("degrade_causes: []", out)
        self.assertEqual(self.causes_of(out), [])

    def test_every_degraded_run_names_at_least_one_cause(self):
        # 총 함수 — `degraded == (causes != [])`. 한쪽만 참인 산출은 존재할 수 없다.
        cases = [
            ("expected-empty",     [],    [],                      []),
            ("baseline-unrunnable", ["u"], [("u", "unrun", "0")],  [("u", "pass", "0")]),
            ("silent-drop",        ["u"], [("u", "pass", "0")],    []),
            ("error-axis",         ["u"], [("u", "error", "1")],   [("u", "pass", "0")]),
        ]
        for name, exp, base, head in cases:
            with self.subTest(name):
                rc, out, _ = run_diff(exp, base, head)
                self.assertEqual(rc, 0, out)
                self.assertIn("attribution_status: degraded", out)
                self.assertIn(name, self.causes_of(out))

    def test_bulk_pre_existing_is_its_own_cause(self):
        rc, out, _ = run_diff(["u"], [("u", "fail", "1")], [("u", "fail", "1")],
                              granularity="bulk", runner="pytest")
        self.assertEqual(rc, 0, out)
        self.assertIn("bulk-pre-existing", self.causes_of(out))

    def test_aggregate_unions_causes_in_enum_order(self):
        # 집계의 목록은 **어댑터 순서와 무관**해야 한다 — 순서가 입력에 의존하면
        # 같은 사실이 두 문자열로 나가 하류의 대조가 깨진다.
        ...  # 두 어댑터 YAML 을 만들어 순서를 바꿔 두 번 집계하고 두 출력이 같은지 본다

    def test_aggregate_with_zero_adapters_names_no_adapters(self):
        # 어댑터 0개는 "결함 없음" 이 아니라 "아무것도 대조하지 않았음" 이다.
        ...  # --aggregate --expected-adapters 0, YAML 0개 → degraded + ["no-adapters"]

    def test_unknown_cause_in_input_is_exit_4(self):
        # 열거는 닫혀 있다 — 미지의 사유를 조용히 통과시키면 하류의 `reason` 이
        # 열거 밖 값을 받는다(AC8 위반).
        ...  # 손으로 만든 어댑터 YAML 에 degrade_causes: [made-up] → rc 4
```

`깨뜨려야 하는 변이:`
| 단언 | 이 변이가 RED 를 내야 한다 |
|---|---|
| `test_clean_run_emits_empty_list…` | `if causes:` 로 감싸 빈 목록일 때 줄을 빼기 (**삭제** 축) |
| `test_every_degraded_run_names…` | `causes` 목록에서 아무 한 절을 빼기 — 그 케이스만 RED, 나머지는 GREEN (**격리**) |
| `test_bulk_pre_existing…` | `bulk-pre-existing` 을 `smeared` 와 한 이름으로 합치기 (**변형**) |
| `test_aggregate_unions_causes_in_enum_order` | 집계의 `sorted(..., key=DEGRADE_CAUSES.index)` 를 그냥 `list(set(...))` 로 (**변형**) |
| `test_aggregate_with_zero_adapters…` | `if not adapters: degraded = True` 는 두고 `causes.append("no-adapters")` 만 빼기 (**삭제**) |
| `test_unknown_cause_in_input_is_exit_4` | `parse_adapter_yaml` 의 미지-사유 검사를 지우기 (**삭제**) |

**양성 대조** — 위 표의 마지막 두 행은 「없으면 GREEN 이 나야 정상」인 단언이다. 변이를 **적용하지 않은** 채 그대로 돌려 GREEN 임을 먼저 확인하고(양성 대조), 그다음 변이를 적용해 RED 를 본다. 양성 대조 없이 본 RED 는 계측기 자신의 고장과 구별되지 않는다.

- [ ] **Step 2: 테스트가 실패하는 것을 확인한다**

Run: `python3 plugins/quality-gates/tests/test_diff_test_results.py DegradeCauses -v`
Expected: 전부 FAIL — `degrade_causes 줄이 0회`.

- [ ] **Step 3: 모듈 상수와 `per_adapter()` 를 고친다**

`DEFECTS = {...}` 바로 아래에 상수를 둔다:

```python
# degrade 의 원인 — **닫힌 열거**. `per_adapter()` 의 `degraded` 식 여섯 절과 1:1 이고
# `no-adapters` 만 집계 전용이다(어댑터 0개는 per-adapter 에 존재할 수 없다).
# 튜플 «순서» 가 집계 목록의 정렬 키다 — 어댑터 입력 순서가 출력 문자열을 바꾸면
# 같은 사실이 두 표기로 나간다.
DEGRADE_CAUSES = (
    "expected-empty", "baseline-unrunnable", "silent-drop",
    "error-axis", "bulk-pre-existing", "smeared", "no-adapters",
)
```

`per_adapter()` 의 `degraded = (...)` 식 **바로 아래**:

```python
    # `degraded` 는 여섯 원인을 한 bool 로 접는다 — 밖에서는 어느 사유로 미판정인지
    # 알 수 없다. 설계 §6.4.3 의 `reason` 닫힌 열거가 그 사유를 요구하므로 여기서 편다.
    # **불변식: `degraded == (causes != [])`.** 아래 목록과 위 식은 같은 술어의 두 표기다.
    causes = []
    if not expected:
        causes.append("expected-empty")
    if counts["baseline_unrunnable"] > 0:
        causes.append("baseline-unrunnable")
    if counts["silent_drop"] > 0:
        causes.append("silent-drop")
    if error_axis_seen:
        causes.append("error-axis")
    if args.granularity == "bulk" and counts["pre_existing"] > 0:
        causes.append("bulk-pre-existing")
    if smeared:
        causes.append("smeared")
    if bool(causes) != bool(degraded):
        # 두 표기가 어긋나면 어느 쪽이 참인지 알 수 없다 — fail-closed.
        # `assert` 를 쓰지 않는다: `python3 -O` 가 그것을 통째로 지운다.
        fail4(f"내부 불일치: degraded={degraded} 인데 degrade_causes={causes}")
```

`out.append(f"attribution_status: ...")` **바로 다음 줄**에 emit:

```python
    out.append(f"degrade_causes: [{', '.join(causes)}]")
```

- [ ] **Step 4: `parse_adapter_yaml()` 이 그것을 읽게 한다**

docstring 아래, `status = _one(...)` 다음에:

```python
    causes_body = _one(r"^degrade_causes: \[(.*)\]$", text, path, "degrade_causes")
    causes = [c.strip() for c in causes_body.split(",") if c.strip()]
    unknown = [c for c in causes if c not in DEGRADE_CAUSES]
    if unknown:
        fail4(f"{path}: 미지의 degrade_cause {unknown} — 열거는 닫혀 있다")
    if bool(causes) != (status == "degraded"):
        fail4(f"{path}: attribution_status={status} 인데 degrade_causes={causes}")
```

반환을 5-튜플로 바꾸고(`return runner, status, flags, counts, causes`) 시그니처의 타입 주석도 함께 바꾼다.

- [ ] **Step 5: `_aggregate()` 가 합집합을 낸다**

```python
    causes: list[str] = []
    ...
    for path in args.yamls:
        runner, status, flags, counts, adapter_causes = parse_adapter_yaml(path)
        ...
        for c in adapter_causes:
            if c not in causes:
                causes.append(c)
    ...
    if not adapters:
        degraded = True
        causes.append("no-adapters")
```

emit 은 `attribution_status` 다음 줄, **열거 순서로 정렬**해서:

```python
    # 입력 어댑터 순서가 출력 문자열을 바꾸면 같은 사실이 두 표기로 나간다.
    out.append("degrade_causes: ["
               + ", ".join(sorted(causes, key=DEGRADE_CAUSES.index)) + "]")
    if bool(causes) != bool(degraded):
        fail4(f"내부 불일치: degraded={degraded} 인데 degrade_causes={causes}")
```

- [ ] **Step 6: 테스트가 통과하는 것을 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 plugins/quality-gates/tests/test_diff_test_results.py -v`
Expected: 새 클래스 전부 PASS + 기존 케이스 전부 PASS.

그다음 **이 스크립트의 다른 소비자**를 돌린다 — `degrade_causes` 한 줄이 늘어난 것이 줄-지향 파서를 깨뜨릴 수 있다:

Run: `bash plugins/quality-gates/tests/test_run_test_selection.sh`
Run: `bash plugins/quality-gates/tests/test_runner_adapters.sh`
Expected: 앞은 GREEN, 뒤는 **baseline 과 같은 rc·같은 실패 줄 수**(선재 RED).

- [ ] **Step 7: 커밋**

```
feat(qg): 차등 산출물이 degrade 의 원인을 닫힌 열거로 낸다

`attribution_status: degraded` 한 값에 접혀 있던 여섯 원인을 `degrade_causes:`
로 편다. 설계 §6.4.3 의 `reason` 닫힌 열거가 요구하는 입력이다. per-adapter 와
집계 양쪽에서 `degraded == (causes != [])` 를 fail-closed 로 검사한다.

Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr2
Co-Authored-By: <실제 작성 모델> <noreply@anthropic.com>
```

---

### Task 3: `diff-test-results.py` — 해상도 공시 (AC13)

**Files:**
- Modify: `plugins/quality-gates/scripts/diff-test-results.py` — `per_adapter()` · `_aggregate()`
- Create: `plugins/quality-gates/tests/test_resolution_disclosure.sh`

**Interfaces:**
- Consumes: Task 2 의 `DEGRADE_CAUSES` · 5-튜플 `parse_adapter_yaml`
- Produces: 두 모드 stdout 의 `resolution_disclosure: "<문구>"` 한 줄 — `pre_existing` 합이 0 보다 클 때만

**핵심 함정 (이 Task 가 존재하는 이유).** 어댑터가 여럿이면 오케스트레이터가 읽는 산출물은 **집계**다. 공시를 per-adapter 에만 넣으면 AC13 의 락은 GREEN 인데 실제 소비자는 그 줄을 **한 번도 보지 못한다**. 집계는 `counts` 를 `per_adapter:` 안에 flow-mapping 으로만 싣고 있어 오늘은 `pre_existing` 이 최상위에 없다.

**두 번째 함정.** 공시는 **기존 가드를 대체하지 않는다**(설계 §6.4.2). `granularity == bulk && pre_existing > 0` 은 여전히 `degraded` 이고 Task 2 의 `bulk-pre-existing` 사유를 낸다. 공시 줄은 그 «위에» 얹힌다.

- [ ] **Step 1: 실패하는 락을 쓴다** — `plugins/quality-gates/tests/test_resolution_disclosure.sh`

```bash
#!/usr/bin/env bash
# test_resolution_disclosure.sh — AC13 (설계 §6.4.2).
#
# 이 락이 반드시 **두 층** 을 재는 이유: 어댑터가 여럿이면 오케스트레이터가 읽는
# 산출물은 집계다. per-adapter 만 재는 락은 GREEN 인 채로 실제 소비자가 공시를
# 한 번도 못 보는 상태를 통과시킨다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
DIFF="$PLUGIN_ROOT/scripts/diff-test-results.py"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

T=""
cleanup() { cd / && rm -rf "$T"; }

# per-adapter 한 번 — <expected> <baseline TSV> <head TSV> <granularity> <runner>
adapter() {
  T=$(mktemp -d) || exit 1
  printf '%s\n' "$1" > "$T/e.txt"
  printf '%s\n' "$2" > "$T/b.tsv"
  printf '%s\n' "$3" > "$T/h.tsv"
  python3 "$DIFF" --expected "$T/e.txt" --baseline "$T/b.tsv" --head "$T/h.tsv" \
    --granularity "$4" --runner "$5" --baseline-mode per-unit --head-mode per-unit \
    --baseline-detected "$5"
}

DISCLOSURE='resolution_disclosure: "양측 빨강 unit'

case_per_adapter_present() {
  local out; out=$(adapter 'u1' "$(printf 'u1\tfail\t1')" "$(printf 'u1\tfail\t1')" file pytest)
  assert_grep "$out" '^resolution_disclosure: ' "pre_existing>0 이면 공시 줄이 있다"
  assert_grep "$out" 'unit 1개'                  "공시가 실제 개수를 싣는다"
  cleanup
}

case_per_adapter_absent_when_zero() {
  local out; out=$(adapter 'u1' "$(printf 'u1\tpass\t0')" "$(printf 'u1\tpass\t0')" file pytest)
  assert_not_grep "$out" '^resolution_disclosure: ' "pre_existing==0 이면 공시 줄이 없다"
  cleanup
}

case_disclosure_does_not_block() {
  # 공시는 «막지 않는다» — granularity:file + pre_existing 만으로는 degraded 가 아니다.
  local out; out=$(adapter 'u1' "$(printf 'u1\tfail\t1')" "$(printf 'u1\tfail\t1')" file pytest)
  assert_grep "$out" '^attribution_status: closed' "공시는 인증을 막지 않는다"
  cleanup
}

case_existing_bulk_guard_survives() {
  # …그러나 기존 가드는 그대로다. 이 둘을 한 케이스로 합치면 「공시를 넣다가 가드를
  # 조용히 지웠다」가 보이지 않는다.
  local out; out=$(adapter 'u1' "$(printf 'u1\tfail\t1')" "$(printf 'u1\tfail\t1')" bulk pytest)
  assert_grep "$out" '^attribution_status: degraded' "bulk + pre_existing 은 여전히 degraded"
  assert_grep "$out" 'bulk-pre-existing'              "그 사유가 이름을 갖는다"
  assert_grep "$out" '^resolution_disclosure: '       "degraded 여도 공시는 나간다"
  cleanup
}

case_aggregate_carries_disclosure() {
  # ★ 이 케이스가 이 락의 존재 이유다.
  ...  # 어댑터 YAML 둘(하나는 pre_existing 2, 하나는 0)을 만들어 --aggregate 로 돌린다
  #    기대: 최상위 resolution_disclosure 가 있고 N == 2 (두 어댑터의 합)
}

case_aggregate_absent_when_all_zero() {
  ...  # 두 어댑터 모두 pre_existing 0 → 최상위 공시 줄 없음
}

case_per_adapter_present
case_per_adapter_absent_when_zero
case_disclosure_does_not_block
case_existing_bulk_guard_survives
case_aggregate_carries_disclosure
case_aggregate_absent_when_all_zero
finish "test_resolution_disclosure"
```

`깨뜨려야 하는 변이:`
| 단언 | 이 변이가 RED 를 내야 한다 |
|---|---|
| `case_per_adapter_present` | 공시 emit 줄을 통째로 삭제 (**삭제**) |
| `…'unit 1개'` | 개수를 `counts['pre_existing']` 대신 상수 `1` 로 (**변형** — 이것이 없으면 「줄이 있다」만 재고 내용은 안 잰다) |
| `case_per_adapter_absent_when_zero` | `if counts["pre_existing"] > 0:` 가드를 지워 **항상** 내보내기 (**추가**) |
| `case_disclosure_does_not_block` | 공시 조건을 `degraded` 식에 절로 추가 (**추가** — 공시가 막기 시작한다) |
| `case_existing_bulk_guard_survives` | `degraded` 식에서 `(granularity == "bulk" and pre_existing > 0)` 절을 삭제 (**삭제** — 공시를 넣다가 가드를 잃는 정확한 경로) |
| `case_aggregate_carries_disclosure` | 집계의 공시 emit 만 삭제하고 per-adapter 는 그대로 두기 (**격리** — per-adapter 케이스 넷은 GREEN 이어야 한다) |
| `…N == 2` | 집계의 N 을 어댑터 «개수» 로 (**변형**) |
| `case_aggregate_absent_when_all_zero` | 집계 공시를 무조건 내보내기 (**추가**) |

**양성 대조** — 여섯 케이스 전부를 변이 없이 먼저 돌려 GREEN 을 확인한다. 특히 `case_per_adapter_absent_when_zero` · `case_aggregate_absent_when_all_zero` 은 **부재를 재는 음의 락**이라 양의 짝(`case_per_adapter_present` · `case_aggregate_carries_disclosure`) 없이는 스크립트 전체를 지워도 통과한다.

- [ ] **Step 2: 락이 실패하는 것을 확인한다**

Run: `bash plugins/quality-gates/tests/test_resolution_disclosure.sh`
Expected: `case_per_adapter_present` · `case_existing_bulk_guard_survives` 의 공시 단언 · `case_aggregate_carries_disclosure` 가 RED. `case_*_absent_*` 는 **이 시점에 이미 GREEN** 이다(줄이 아예 없으니) — 그것이 음의 락이 혼자서는 이빨이 없다는 증거다.

- [ ] **Step 3: `per_adapter()` 에 공시를 넣는다**

Task 2 의 `degrade_causes` emit **다음 줄**:

```python
    # AC13 — (F,F) 구멍의 공시(설계 §6.4.2). **판정을 막지 않는다**: 이 줄은 기존
    # 가드 «위에» 얹힌다. `granularity == bulk && pre_existing > 0` 은 여전히
    # degraded 이고 `bulk-pre-existing` 사유를 낸다. 이 단서 없이 구현하면 가드가
    # 조용히 사라진다.
    if counts["pre_existing"] > 0:
        out.append("resolution_disclosure: " + yaml_str(
            f"양측 빨강 unit {counts['pre_existing']}개 — 그 안의 새 실패는 "
            "이 해상도(unit 당 종료 코드 하나)에서 보이지 않는다"))
```

- [ ] **Step 4: `_aggregate()` 에도 넣는다 — 수를 «다시 계산»한다**

`degrade_causes` emit 다음, `per_adapter:` 블록 **앞**:

```python
    # 집계는 per-adapter 의 공시 «문자열» 을 옮기지 않는다 — 같은 사실을 두 자리가
    # 따로 말하면 어긋날 수 있다. 수는 여기서 다시 센다.
    pre_existing_total = sum(c["pre_existing"] for c in per_adapter_counts.values())
    if pre_existing_total > 0:
        out.append("resolution_disclosure: " + yaml_str(
            f"양측 빨강 unit {pre_existing_total}개 — 그 안의 새 실패는 "
            "이 해상도(unit 당 종료 코드 하나)에서 보이지 않는다"))
```

- [ ] **Step 5: 락이 통과하는 것을 확인한다**

Run: `bash plugins/quality-gates/tests/test_resolution_disclosure.sh`
Expected: 여섯 케이스 전부 GREEN.

Run: `PYTHONDONTWRITEBYTECODE=1 python3 plugins/quality-gates/tests/test_diff_test_results.py`
Expected: 기존 + Task 2 케이스 전부 GREEN — 공시 줄이 `_one()` 정규식 어느 것에도 두 번 매치되지 않는다.

- [ ] **Step 6: 커밋**

```
feat(qg): 해상도 공시를 차등 산출물의 두 층에 싣는다 (AC13)

`pre_existing > 0` 인 실행이 「양측 빨강 unit N개 — 그 안의 새 실패는 이
해상도에서 보이지 않는다」를 per-adapter 와 집계 **양쪽에** 낸다. 집계의 N 은
per-adapter 문자열을 옮기지 않고 다시 센다. 공시는 판정을 막지 않고 기존
bulk 가드를 대체하지도 않는다.

Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr2
Co-Authored-By: <실제 작성 모델> <noreply@anthropic.com>
```

---

### Task 4: `verdict.py` — 세 값 · 닫힌 열거 · 우선순위 · 매핑표

**Files:**
- Create: `plugins/quality-gates/scripts/verdict.py`
- Create: `plugins/quality-gates/tests/test_verdict_vocabulary.sh`

**Interfaces:**
- Consumes: Task 2·3 의 차등 산출물 두 키(`degrade_causes:` · `verdict_input:`). **per-adapter 와 집계가 그 둘을 같은 표기로 갖는다** — 그래서 이 모듈은 두 모드를 구별하지 않는다.
- Produces (PR4 가 쓴다):
  - `VALUES: tuple[str, str, str]` = `("defect", "not-certified", "clean")` — **우선순위 순서**
  - `REASONS: tuple[str, ...]` — 11값, **튜플 순서가 곧 `reason:` 우선순위**
  - `LEGACY_VERDICTS: dict[str, str]` — AC23 의 매핑표. **PR4 가 지울 블록**
  - `decide(*, defect, review_blocked, differential_text=None, extra_reasons=(), legacy_verdict=None) -> dict`
  - `render(decision: dict) -> str`
  - CLI: `python3 verdict.py [--differential P] [--defect] [--review-blocked] [--reason R]... [--legacy-verdict V]` → stdout 2–3줄 · exit `0` 정상 / `2` usage / `4` fail-closed

- [ ] **Step 1: 실패하는 락을 쓴다** — `plugins/quality-gates/tests/test_verdict_vocabulary.sh`

```bash
#!/usr/bin/env bash
# test_verdict_vocabulary.sh — AC8 · AC9 · AC23 (설계 §6.4.3).
#
# 이 락이 재는 것은 «총 함수» 다: 세 값 밖의 값이 나오지 않고, `not-certified` 는
# 사유 없이 존재할 수 없으며, 사유는 닫힌 열거 밖으로 나갈 수 없다. 「어떤 입력에
# 어떤 값이 나온다」만 재는 락은 열거가 조용히 넓어져도 GREEN 이다 — 그래서
# 열거 자체를 **스크립트에서 도출해** 대조한다(∃ 가 아니라 ∀).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
V="$PLUGIN_ROOT/scripts/verdict.py"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

# 열거를 **스크립트 자신에게 물어** 가져온다. 여기에 리터럴 목록을 복사하면
# 두 자리가 어긋날 때 락이 자기 사본만 보고 GREEN 을 낸다.
REASONS=$(python3 -c "import sys; sys.path.insert(0, '$PLUGIN_ROOT/scripts'); import verdict; print('\n'.join(verdict.REASONS))")
VALUES=$(python3 -c "import sys; sys.path.insert(0, '$PLUGIN_ROOT/scripts'); import verdict; print('\n'.join(verdict.VALUES))")

case_three_values_only() {
  assert_eq "$(printf '%s\n' "$VALUES" | wc -l | tr -d ' ')" "3" "판정값은 정확히 셋이다"
  assert_grep "$VALUES" '^clean$';  assert_grep "$VALUES" '^defect$'
  assert_grep "$VALUES" '^not-certified$'
}

case_every_reason_is_reachable() {
  # ∀ — 열거의 **모든** 값이 실제로 `not-certified` 를 만들 수 있어야 한다.
  # 도달 불가한 사유는 열거를 넓히기만 하고 아무것도 뜻하지 않는다.
  local r out
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    out=$(python3 "$V" --reason "$r") || { no "사유 '$r' 가 exit != 0"; continue; }
    assert_grep "$out" '^verdict: not-certified$' "'$r' → not-certified"
    assert_grep "$out" "^reason: $r\$"            "'$r' 가 reason 으로 나온다"
  done <<< "$REASONS"
}

case_unknown_reason_is_fail_closed() {
  local rc=0; python3 "$V" --reason made-up-reason >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "열거 밖 사유는 exit 4"
}

case_not_certified_always_has_reason() {
  # AC8 후반 — 사유 없는 not-certified 는 **낼 수 없다**. 옛 SKIP_WITH_EVIDENCE 가
  # 정확히 그 형태(사유를 싣지 않는 미판정)라 매핑만으로는 AC8 을 어긴다.
  local rc=0; python3 "$V" --legacy-verdict SKIP_WITH_EVIDENCE >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "사유 없는 not-certified 는 exit 4"
  local out; out=$(python3 "$V" --legacy-verdict SKIP_WITH_EVIDENCE --reason kill-switch)
  assert_grep "$out" '^verdict: not-certified$' "사유를 주면 선다"
}

case_kill_switch_is_not_certified() {      # AC9
  local out; out=$(python3 "$V" --reason kill-switch)
  assert_grep "$out"     '^verdict: not-certified$' "kill switch 실행은 not-certified"
  assert_not_grep "$out" '^verdict: clean$'          "clean 이 아니다"
  assert_not_grep "$out" '^verdict: defect$'         "실패도 아니다"
}

case_precedence_defect_wins() {
  local out; out=$(python3 "$V" --defect --reason silent-drop)
  assert_grep "$out" '^verdict: defect$'  "defect > not-certified"
  assert_grep "$out" 'silent-drop'        "그래도 사유는 드러난다"
}

case_precedence_not_certified_beats_clean() {
  local out; out=$(python3 "$V" --reason granularity-smear)
  assert_grep "$out" '^verdict: not-certified$' "not-certified > clean"
}

case_reason_is_first_in_enum_order() {
  # `reason:` 은 임의의 하나가 아니라 **열거 순서에서 가장 앞선** 것이다.
  # 인자 순서를 뒤집어도 같은 값이 나와야 한다.
  local a b
  a=$(python3 "$V" --reason granularity-smear --reason kill-switch | sed -n 's/^reason: //p')
  b=$(python3 "$V" --reason kill-switch --reason granularity-smear | sed -n 's/^reason: //p')
  assert_eq "$a" "kill-switch" "열거 앞선 사유가 reason 이 된다"
  assert_eq "$a" "$b"          "인자 순서가 reason 을 바꾸지 않는다"
}

case_reason_is_member_of_reasons() {
  local out; out=$(python3 "$V" --reason granularity-smear --reason kill-switch)
  local one; one=$(printf '%s\n' "$out" | sed -n 's/^reason: //p')
  local all; all=$(printf '%s\n' "$out" | sed -n 's/^reasons: //p')
  assert_grep "$all" "$one" "reason 은 reasons 의 원소다"
  assert_grep "$all" 'granularity-smear' "나머지 사유가 소실되지 않는다"
}

case_clean_carries_no_reason() {
  local out; out=$(python3 "$V")
  assert_grep "$out"     '^verdict: clean$' "아무 신호도 없으면 clean"
  assert_not_grep "$out" '^reason: '        "clean 에는 reason 이 없다"
}

case_legacy_table_is_exactly_four() {      # AC23
  # PR4 가 **지울 블록** 이다. 넷보다 적으면 산출자 하나가 매핑 없이 남고,
  # 많으면 이 PR 이 설계가 지운 어휘를 되살린 것이다.
  local n; n=$(python3 -c "import sys; sys.path.insert(0, '$PLUGIN_ROOT/scripts'); import verdict; print(len(verdict.LEGACY_VERDICTS))")
  assert_eq "$n" "4" "옛 어휘 매핑표는 정확히 네 값"
  local out
  out=$(python3 "$V" --legacy-verdict PASS); assert_grep "$out" '^verdict: clean$'  "PASS → clean"
  out=$(python3 "$V" --legacy-verdict FAIL); assert_grep "$out" '^verdict: defect$' "FAIL → defect"
  local rc=0; python3 "$V" --legacy-verdict MADE_UP >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "미지의 옛 값은 exit 4"
}

case_legacy_table_marked_for_removal() {
  # PR4 가 찾을 수 있어야 한다. 주석 문구가 아니라 **표 자체**가 한 자리에 있는지 본다.
  local hits; hits=$(grep -c 'LEGACY_VERDICTS' "$V")
  assert_eq "$hits" "2" "매핑표는 정의 1 + 사용 1, 두 자리뿐이다"
  assert_file_grep "$V" 'AC23' "PR4 가 지울 블록임이 파일에 적혀 있다"
}

case_differential_causes_become_reasons() {
  # Task 2 가 연 `degrade_causes` 가 실제로 사유가 되는지 — 두 모듈의 이음매다.
  local T; T=$(mktemp -d)
  printf 'attribution_status: degraded\ndegrade_causes: [silent-drop, smeared]\nverdict_input:\n  confirmed_product_defect: false\n  silent_drop: true\n  baseline_unrunnable: false\n' > "$T/d.yaml"
  local out; out=$(python3 "$V" --differential "$T/d.yaml")
  assert_grep "$out" '^verdict: not-certified$'  "degrade 원인이 미판정을 만든다"
  assert_grep "$out" 'silent-drop'                "원인이 사유로 옮겨온다"
  assert_grep "$out" 'granularity-smear'          "smeared → granularity-smear 로 번역된다"
  rm -rf "$T"
}

case_differential_defect_flag_wins() {
  local T; T=$(mktemp -d)
  printf 'attribution_status: degraded\ndegrade_causes: [silent-drop]\nverdict_input:\n  confirmed_product_defect: true\n  silent_drop: true\n  baseline_unrunnable: false\n' > "$T/d.yaml"
  local out; out=$(python3 "$V" --differential "$T/d.yaml")
  assert_grep "$out" '^verdict: defect$' "확증 결함이 미판정을 이긴다"
  rm -rf "$T"
}

case_unreadable_differential_is_fail_closed() {
  local rc=0; python3 "$V" --differential /nonexistent/d.yaml >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "차등 산출물을 못 읽으면 exit 4 — clean 으로 새지 않는다"
}

case_three_values_only
case_every_reason_is_reachable
case_unknown_reason_is_fail_closed
case_not_certified_always_has_reason
case_kill_switch_is_not_certified
case_precedence_defect_wins
case_precedence_not_certified_beats_clean
case_reason_is_first_in_enum_order
case_reason_is_member_of_reasons
case_clean_carries_no_reason
case_legacy_table_is_exactly_four
case_legacy_table_marked_for_removal
case_differential_causes_become_reasons
case_differential_defect_flag_wins
case_unreadable_differential_is_fail_closed
finish "test_verdict_vocabulary"
```

`깨뜨려야 하는 변이:`
| 단언 | 이 변이가 RED 를 내야 한다 |
|---|---|
| `case_three_values_only` | `VALUES` 에 네 번째 값 추가 (**추가**) |
| `case_every_reason_is_reachable` | `REASONS` 에 아무 값이나 하나 더 넣되 `decide()` 는 안 고치기 (**추가** — 도달 불가 사유) |
| `case_unknown_reason_is_fail_closed` | 미지 사유 검사를 지워 그대로 통과 (**삭제**) |
| `case_not_certified_always_has_reason` | 사유 없는 `not-certified` 를 허용 (**삭제** — AC8 후반이 죽는 정확한 경로) |
| `case_kill_switch_is_not_certified` | `kill-switch` 를 `clean` 으로 매핑 (**변형** — kill switch 가 「무조건 통과 버튼」이 된다) |
| `case_precedence_defect_wins` | 우선순위를 `not-certified > defect` 로 (**변형** — 오늘 결함으로 잡히던 실행이 내일 미판정으로 내려앉는다) |
| `case_reason_is_first_in_enum_order` | `REASONS` 튜플을 뒤집기 (**변형**) / `min(..., key=REASONS.index)` 를 `reasons[0]` 으로 (**변형**) |
| `case_reason_is_member_of_reasons` | `reasons:` 를 `reason` 하나만 담게 (**변형** — 나머지 사유 소실) |
| `case_clean_carries_no_reason` | `clean` 에도 `reason:` 을 내보내기 (**추가**) |
| `case_legacy_table_is_exactly_four` | 매핑표에서 `NEEDS_RESOLUTION` 빼기 (**삭제**) / 다섯 번째 넣기 (**추가**) |
| `case_legacy_table_marked_for_removal` | 매핑표를 두 자리로 쪼개기 (**추가** — PR4 가 한쪽만 지운다) |
| `case_differential_causes_become_reasons` | `CAUSE_TO_REASON` 에서 `smeared` 행 삭제 (**삭제**) |
| `case_differential_defect_flag_wins` | `confirmed_product_defect` 를 안 읽기 (**삭제**) |
| `case_unreadable_differential_is_fail_closed` | 읽기 실패를 `except: pass` 로 삼키기 (**변형** — fail-open) |

**양성 대조** — `case_clean_carries_no_reason` · `case_unknown_reason_is_fail_closed` 는 부재·거부를 재는 음의 락이다. 각각의 양의 짝(`case_every_reason_is_reachable` · `case_kill_switch_is_not_certified`)이 **같은 실행에서 GREEN** 임을 먼저 확인한다. 스크립트가 통째로 죽으면 양의 짝이 먼저 RED 가 되어 「전부 통과」로 오독되지 않는다.

- [ ] **Step 2: 락이 실패하는 것을 확인한다**

Run: `bash plugins/quality-gates/tests/test_verdict_vocabulary.sh`
Expected: `ModuleNotFoundError: No module named 'verdict'` 로 전부 RED.

- [ ] **Step 3: `verdict.py` 를 쓴다**

```python
#!/usr/bin/env python3
"""판정 어휘 — 세 값과 닫힌 사유 열거 (설계 §6.4.3, AC8 · AC9 · AC23).

**판정 어휘를 이 파일 밖에 두지 않는다.** 산출자가 여럿이면 우선순위
(`defect > not-certified > clean`)를 적용할 자리가 없어진다.

입력은 셋이다 — 리뷰 축(합성기의 원장), 차등 축(`diff-test-results.py` 의
`degrade_causes` · `verdict_input`), 그리고 호출자만 아는 사유(kill switch ·
trivia · 합치기 충돌 · 선언 무효 · 스코프 0 · 각도 부재).
"""
import argparse
import re
import sys

# 우선순위 순서 — 앞이 이긴다. 확증 결함과 미판정이 같은 실행에서 나면 `defect` 다
# (설계 §6.4.3). 이 순서를 뒤집으면 오늘 결함으로 잡히던 실행이 내일 미판정으로
# 내려앉는다.
VALUES = ("defect", "not-certified", "clean")

# 닫힌 열거. **튜플 순서가 곧 `reason:` 우선순위**다 — 앞쪽일수록 「그 뒤 전부를
# 설명한다」: 파이프라인이 아예 안 돈 것 → 대상 자체가 서지 않은 것 → 대조 대상이
# 없는 것 → 리뷰 축 → 차등 축의 해상도 문제.
REASONS = (
    "trivia",               # 파이프라인 전체가 생략됨 (C4 의 두 탈출구 중 하나)
    "kill-switch",          # 차등 테스트가 kill switch 로 생략됨 (나머지 하나)
    "declaration-invalid",  # 트레일러가 있으나 경로 부재 · 한 브랜치에 다른 토픽 키
    "merge-conflict",       # 끝점 합치기가 rc 1 (§6.2.4 · AC7)
    "scope-empty",          # 대조할 대상이 0 인데 변경은 있다
    "findings-lost",        # 리뷰 항목이 소실됐거나 셀 수 없다
    "angle-absent",         # 보안 또는 판정 각도가 absent (§6.3.1 — PR3 가 배선한다)
    "baseline-unrunnable",  # 기준선 축이 안 돌아 귀속의 한쪽이 없음
    "silent-drop",          # 영향분으로 고른 unit 이 HEAD 에서 미확인
    "error-axis",           # 어느 축이든 error 상태가 닿음
    "granularity-smear",    # bulk 도말 또는 smeared
)

# `diff-test-results.py` 의 `degrade_causes` → 이 어휘.
# `expected-empty`(영향분 0개)와 `no-adapters`(어댑터 0개)에는 설계가 이름을 주지
# 않았다 — 둘 다 「대조할 대상이 0 이다」라서 `scope-empty` 로 보낸다(계획 R-A).
CAUSE_TO_REASON = {
    "expected-empty": "scope-empty",
    "no-adapters": "scope-empty",
    "baseline-unrunnable": "baseline-unrunnable",
    "silent-drop": "silent-drop",
    "error-axis": "error-axis",
    "bulk-pre-existing": "granularity-smear",
    "smeared": "granularity-smear",
}

# ── AC23 — 옛 판정 어휘 매핑표. **PR4 가 산출자(runtime-verifier)와 함께 이 블록을
#    통째로 지운다.** PR5 시점에 남아 있으면 그 자체가 결함이다.
#    값만 옮긴다 — 사유는 옮기지 않는다. `SKIP_WITH_EVIDENCE` 는 여러 원인을 한 값에
#    접은 것이라 사유를 복원할 수 없고, 사유 없는 `not-certified` 는 AC8 위반이라
#    낼 수 없다. 그래서 호출자가 `--reason` 을 함께 주지 않으면 fail-closed 다.
LEGACY_VERDICTS = {
    "PASS": "clean",
    "FAIL": "defect",
    "SKIP_WITH_EVIDENCE": "not-certified",
    "NEEDS_RESOLUTION": "not-certified",
}
# ── AC23 블록 끝 ──────────────────────────────────────────────────────────


def fail4(msg):
    print(f"verdict: {msg}", file=sys.stderr)
    raise SystemExit(4)


def read_or_none(path):
    """경로가 없으면 `None`(이 실행이 그 축을 안 쓴다) — 있는데 못 읽으면 exit 4.

    둘을 합치면 파일이 사라진 실행이 조용히 `clean` 으로 샌다.
    """
    if not path:
        return None
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except OSError as exc:
        fail4(f"차등 산출물을 읽지 못했다: {path} ({exc})")


def causes_of(differential_text):
    """`degrade_causes: [...]` 를 정확히 한 번 읽는다. per-adapter 와 집계가 같은 표기다."""
    hits = re.findall(r"^degrade_causes: \[(.*)\]$", differential_text, re.M)
    if len(hits) != 1:
        fail4(f"degrade_causes 줄이 {len(hits)}회 (정확히 1회여야 함)")
    return [c.strip() for c in hits[0].split(",") if c.strip()]


def defect_flag_of(differential_text):
    hits = re.findall(r"^  confirmed_product_defect: (true|false)$",
                      differential_text, re.M)
    if len(hits) != 1:
        fail4(f"confirmed_product_defect 줄이 {len(hits)}회 (정확히 1회여야 함)")
    return hits[0] == "true"


def decide(*, defect=False, review_blocked=False, differential_text=None,
           extra_reasons=(), legacy_verdict=None):
    reasons = []

    def add(r):
        if r not in REASONS:
            fail4(f"열거 밖 사유 '{r}' — 어휘는 닫혀 있다")
        if r not in reasons:
            reasons.append(r)

    for r in extra_reasons:
        add(r)

    if differential_text is not None:
        for c in causes_of(differential_text):
            if c not in CAUSE_TO_REASON:
                fail4(f"미지의 degrade_cause '{c}'")
            add(CAUSE_TO_REASON[c])
        defect = defect or defect_flag_of(differential_text)

    # 헌장 — 막는 것은 「항목이 소실됐거나 셀 수 없거나 주 판정자가 죽었을 때」다.
    # 모델 다양성 손실 같은 나머지 degrade 는 공시만 한다. 그래서 원장의
    # `degraded`(공시)가 아니라 `blocks()`(차단)를 받는다.
    if review_blocked:
        add("findings-lost")

    if legacy_verdict is not None:
        if legacy_verdict not in LEGACY_VERDICTS:
            fail4(f"미지의 옛 판정값 '{legacy_verdict}'")
        mapped = LEGACY_VERDICTS[legacy_verdict]
        if mapped == "defect":
            defect = True
        elif mapped == "not-certified" and not reasons:
            fail4(f"'{legacy_verdict}' 는 사유를 싣지 않는다 — "
                  "사유 없는 not-certified 는 AC8 위반이다. --reason 을 함께 줘라")

    reasons.sort(key=REASONS.index)
    if defect:
        return {"verdict": "defect", "reason": None, "reasons": reasons}
    if reasons:
        return {"verdict": "not-certified", "reason": reasons[0], "reasons": reasons}
    return {"verdict": "clean", "reason": None, "reasons": []}


def render(decision):
    out = [f"verdict: {decision['verdict']}"]
    if decision["verdict"] == "not-certified":
        if not decision["reason"]:
            fail4("사유 없는 not-certified (AC8)")
        out.append(f"reason: {decision['reason']}")
    if decision["reasons"]:
        out.append("reasons: [" + ", ".join(decision["reasons"]) + "]")
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--differential", default="")
    ap.add_argument("--defect", action="store_true")
    ap.add_argument("--review-blocked", action="store_true")
    ap.add_argument("--reason", action="append", default=[])
    ap.add_argument("--legacy-verdict", default="")
    args = ap.parse_args()
    sys.stdout.write(render(decide(
        defect=args.defect,
        review_blocked=args.review_blocked,
        differential_text=read_or_none(args.differential),
        extra_reasons=args.reason,
        legacy_verdict=args.legacy_verdict or None,
    )))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: 락이 통과하는 것을 확인한다**

Run: `bash plugins/quality-gates/tests/test_verdict_vocabulary.sh`
Expected: 15 케이스 전부 GREEN.

- [ ] **Step 5: 이 파일이 심볼릭 링크가 아닌지 확인한다**

Run: `ls-files -s plugins/quality-gates/scripts/verdict.py`
Expected: mode `100644`. `120000` 이면 `shared/` 의 공유 모듈로 잘못 들어간 것이다.

- [ ] **Step 6: 커밋**

```
feat(qg): 판정 어휘 세 값과 닫힌 사유 열거 (AC8 · AC9 · AC23)

`scripts/verdict.py` 가 `clean` · `defect` · `not-certified` 와 11값 닫힌
사유 열거, 우선순위(defect > not-certified > clean), 옛 네 값 매핑표를 갖는다.
`REASONS` 튜플 순서가 곧 `reason:` 우선순위다. 사유 없는 not-certified 와
열거 밖 사유는 exit 4 로 막는다. 매핑표는 PR4 가 지울 한 블록이다.

호출자는 아직 0 이다.

Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr2
Co-Authored-By: <실제 작성 모델> <noreply@anthropic.com>
```

---

### Task 5: `synthesize_findings.py` — 진입 한 줄, 기본 off

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py` — import 1줄 · `main()` 의 argparse 4줄 · 출력 1블록
- Modify: `plugins/quality-gates/tests/test_verdict_vocabulary.sh` — 차등 케이스 둘 추가

**Interfaces:**
- Consumes: Task 4 의 `verdict.decide` · `verdict.render` · `verdict.read_or_none`
- Produces: `--emit-verdict` 가 켜졌을 때만 stdout **끝에** 판정 블록. 꺼지면 이전과 **바이트 동일**

**왜 기본 off 인가.** 이 PR 의 합격 기준은 「어휘를 들여놓되 오늘의 `/qg` 를 바꾸지 않는다」이다. 합성기 stdout 은 SKILL 이 읽고 기존 락 다섯이 문면을 핀하고 있다(`test_synthesize_findings.sh` · `test_synthesize_findings_adjudication.py` · `test_synthesize_disposition.sh` · `test_synthesize_promoted_findings.sh` · `test_skill_drop_notice_consumed.sh`). 무조건 emit 하면 이 PR 이 소비자 이주까지 떠안는다 — 그것은 PR4 다.

- [ ] **Step 1: 실패하는 차등 락을 쓴다** — `test_verdict_vocabulary.sh` 에 추가

```bash
SYNTH="$PLUGIN_ROOT/scripts/synthesize_findings.py"

case_synth_off_is_byte_prefix_of_on() {
  # 차등 — 같은 입력으로 두 번 돌려 **off 출력이 on 출력의 접두** 인지 본다.
  # 「off 에 verdict 줄이 없다」만 재면 on 이 앞부분을 바꿔도 안 보인다.
  local T; T=$(mktemp -d)
  printf 'verdicts: []\n' > "$T/adv.yaml"
  printf -- '- {agent: r, file: a.py, line: 1, severity: IMPORTANT, confidence: 8, summary: s, proposed_fix: f}\n' > "$T/f.yaml"
  local off on
  off=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml")
  on=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" --emit-verdict)
  assert_not_grep "$off" '^verdict: '  "기본값에서는 판정 줄이 없다"
  assert_grep     "$on"  '^verdict: '  "--emit-verdict 가 판정 줄을 켠다"
  assert_eq "${on:0:${#off}}" "$off"   "off 출력은 on 출력의 바이트 접두다"
  rm -rf "$T"
}

case_synth_kept_finding_is_defect() {
  local T; T=$(mktemp -d)
  printf 'verdicts: []\n' > "$T/adv.yaml"
  printf -- '- {agent: r, file: a.py, line: 1, severity: SUGGESTION, confidence: 8, summary: s, proposed_fix: f}\n' > "$T/f.yaml"
  local out; out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" --emit-verdict)
  # 계획 R-B — severity 를 묻지 않는다. SUGGESTION 하나도 채택된 finding 이다.
  assert_grep "$out" '^verdict: defect$' "채택된 finding 이 있으면 defect"
  rm -rf "$T"
}

case_synth_lost_findings_is_not_certified() {
  # 원장의 blocks() — 항목이 소실되면 막는다. 공시(degraded)가 아니라 차단이다.
  local T; T=$(mktemp -d)
  printf 'verdicts: []\n' > "$T/adv.yaml"
  printf -- '- not-a-mapping\n' > "$T/f.yaml"
  local out; out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" --emit-verdict)
  assert_grep "$out" '^verdict: not-certified$' "소실된 항목이 있으면 미판정"
  assert_grep "$out" '^reason: findings-lost$'  "사유가 findings-lost 다"
  rm -rf "$T"
}

case_synth_clean_is_clean() {
  local T; T=$(mktemp -d)
  printf 'verdicts: []\n' > "$T/adv.yaml"; printf '[]\n' > "$T/f.yaml"
  local out; out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" --emit-verdict)
  assert_grep "$out" '^verdict: clean$' "발견 0 · 소실 0 이면 clean"
  rm -rf "$T"
}
```

`깨뜨려야 하는 변이:`
| 단언 | 이 변이가 RED 를 내야 한다 |
|---|---|
| `…off_is_byte_prefix…` (앞 두 단언) | `if args.emit_verdict:` 가드를 지워 **항상** emit (**추가**) |
| `…off_is_byte_prefix…` (접두 단언) | 판정 블록을 stdout **앞**에 붙이기 (**변형** — 「줄이 있다/없다」만 재는 단언은 이것을 못 잡는다) |
| `case_synth_kept_finding_is_defect` | `defect=bool(kept)` 를 severity 필터로 좁히기 (**변형** — R-B 를 뒤집는 정확한 편집) |
| `case_synth_lost_findings_is_not_certified` | `ledger.blocks()` 를 `report["degraded"]` 로 바꾸기 (**변형** — 모델 다양성 손실까지 막게 된다) / `review_blocked` 인자를 안 넘기기 (**삭제**) |
| `case_synth_clean_is_clean` | `defect=True` 를 고정 (**변형**) — 양의 대조: 이것이 없으면 위 세 케이스는 전부 GREEN 인 채로 「항상 defect」가 통과한다 |

- [ ] **Step 2: 락이 실패하는 것을 확인한다**

Run: `bash plugins/quality-gates/tests/test_verdict_vocabulary.sh`
Expected: 새 케이스 넷이 RED (`unrecognized arguments: --emit-verdict`).

- [ ] **Step 3: 진입 한 줄을 넣는다**

import 블록(`from render_disposition import disposition_lines` 아래):

```python
import verdict as _verdict          # 새 책임은 새 모듈 — 여기는 진입점일 뿐이다
```

`main()` 의 argparse:

```python
    # 판정 어휘는 `verdict.py` 가 갖는다. 여기서는 입력을 모아 넘기기만 한다.
    # 기본 off — 켜지 않으면 stdout 이 이 PR 이전과 바이트 동일하다(소비자 이주는 PR4).
    ap.add_argument("--emit-verdict", action="store_true")
    ap.add_argument("--differential", default="")
    ap.add_argument("--reason", action="append", default=[])
    ap.add_argument("--legacy-verdict", default="")
```

`sys.stdout.write(render(...))` **다음**:

```python
    if args.emit_verdict:
        # `report["degraded"]`(공시)가 아니라 `blocks()`(차단)다 — 헌장은 모델 다양성
        # 손실 같은 degrade 를 공시만 하고 막지 않는다. 여기서 둘을 섞으면 이 PR 이
        # 조용히 게이트를 넓힌다.
        sys.stdout.write(_verdict.render(_verdict.decide(
            defect=bool(kept),                    # 계획 R-B — severity 를 묻지 않는다
            review_blocked=ledger.blocks(),
            differential_text=_verdict.read_or_none(args.differential),
            extra_reasons=args.reason,
            legacy_verdict=args.legacy_verdict or None,
        )))
```

- [ ] **Step 4: 락과 기존 소비자를 함께 돌린다**

Run: `bash plugins/quality-gates/tests/test_verdict_vocabulary.sh`
Expected: 19 케이스 전부 GREEN.

Run(전부 GREEN 이어야 한다 — 하나라도 붉으면 기본 off 가 새고 있다는 뜻이다):
```
bash plugins/quality-gates/tests/test_synthesize_findings.sh
bash plugins/quality-gates/tests/test_synthesize_disposition.sh
bash plugins/quality-gates/tests/test_synthesize_promoted_findings.sh
bash plugins/quality-gates/tests/test_skill_drop_notice_consumed.sh
python3 plugins/quality-gates/tests/test_synthesize_findings_adjudication.py
bash shared/tests/test_adjudication_wiring.sh
```

- [ ] **Step 5: 커밋**

```
feat(qg): 합성기에 판정 산출 진입점을 단다 (--emit-verdict, 기본 off)

합성기가 리뷰 축의 입력(채택된 finding 유무 · 원장의 blocks())과 차등 축의
산출물을 모아 `verdict.py` 에 넘긴다. 플래그를 켜지 않으면 stdout 은 이전과
바이트 동일하다 — 소비자 이주는 PR4 다. 차단 판정에는 공시용 `degraded` 가
아니라 `blocks()` 를 쓴다(헌장: 모델 다양성 손실은 공시하고 막지 않는다).

Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr2
Co-Authored-By: <실제 작성 모델> <noreply@anthropic.com>
```

---

### Task 6: mutation — 네 축 × 양성 대조

**Files:**
- Create: `$CLAUDE_JOB_DIR/tmp/pr2-mutations.md` (전사 — 리포 밖)
- Create: `.superpowers/sdd/<이 계획>/pr2-mutations.md` (요약표 — git-ignored, PR 본문이 참조)

**Interfaces:**
- Consumes: Task 2·3·4·5 의 `깨뜨려야 하는 변이` 표 **전부**
- Produces: 변이 하나당 `축 · 변이 · 기대 · 관측 · 폭발 반경` 다섯 열. **기대와 관측이 어긋난 줄이 이 PR 의 남은 일이다**

**이 Task 가 PR1 에서 가장 비쌌다.** 아홉 건의 「통과하지만 아무것도 재지 않는 락」 중 셋은 그것을 고치다 한 층 위에서 다시 만든 것이다. 아래 넷을 순서대로 지킨다.

- [ ] **Step 1: 계측기 자신을 먼저 검증한다 (양성 대조)**

변이를 적용하기 **전에** 대상 락을 돌려 GREEN 을 확인하고, 그 GREEN 을 전사에 적는다. 양성 대조 없이 본 RED 는 「변이가 잡혔다」와 「락이 고장 났다」를 구별하지 못한다.

`sed` 로 파이썬 파일을 고칠 때는 **변이 후 `python3 -m py_compile` 을 먼저 돌린다.** 구문 오류로 죽은 스크립트는 모든 케이스를 RED 로 만들어 「변이가 잡혔다」처럼 보인다 — 셸 본문 추출기가 조용히 깨지는 것과 같은 고장이다.

```bash
python3 -m py_compile plugins/quality-gates/scripts/verdict.py || echo "변이가 파일을 깨뜨렸다 — 이 RED 는 증거가 아니다"
```

- [ ] **Step 2: 폭발 반경을 축으로 본다**

변이 하나가 **여러 케이스를 함께** 무너뜨리면 그것은 락의 이빨이 아니라 **변이 선택의 결함**이다(`all([])` 공허참이 무관한 단언까지 무너뜨리는 것과 같은 형태). 그때는 변이를 더 좁혀 다시 고른다. 전사의 `폭발 반경` 열에 「RED 난 케이스 이름들」을 적고, 기대한 케이스 **하나만** 붉은지 본다.

Task 2 의 `test_every_degraded_run_names_at_least_one_cause` 처럼 `subTest` 로 여러 사유를 도는 단언은 **그 사유의 `subTest` 하나만** 붉어야 한다.

- [ ] **Step 3: 네 축을 전부 흔든다 — 삭제만 흔들지 않는다**

| 축 | 뜻 | 이 PR 에서 |
|---|---|---|
| **삭제** | 코드를 지운다 | emit 줄 · 가드 · 검사 제거 |
| **변형** | 값·표기·위치를 바꾼다 | 우선순위 뒤집기 · 열거 순서 뒤집기 · 블록을 stdout 앞으로 · `blocks()` → `degraded` |
| **추가** | 없던 것을 넣는다 | `VALUES`·`REASONS` 에 값 추가 · 가드 없이 항상 emit · `clean` 에 `reason` 붙이기 |
| **불일치** | 두 자리가 어긋나게 한다 | `degraded` 식에 절을 더하되 `causes` 에는 안 더하기 · 매핑표를 두 자리로 쪼개기 · per-adapter 만 공시하고 집계는 안 하기 |

**변이가 락의 전제를 공유하지 않게 한다.** 락이 `^verdict: not-certified$` 를 본다고 해서 변이도 그 문자열만 건드리면, 같은 전제 위에서 흔드는 것이라 아무것도 증명하지 못한다. **제약의 부정형**으로 축을 세운다 — 「사유 없는 not-certified 는 나올 수 없다」의 부정은 「사유 없이 내보낸다」이고, 그것이 Task 4 의 `case_not_certified_always_has_reason` 변이다.

- [ ] **Step 4: 기대가 GREEN 인 변이도 돌린다**

「이것은 깨지면 안 된다」쪽도 축이다. 최소 셋:

| 변이 | 기대 | 왜 |
|---|---|---|
| `degrade_causes` 목록의 **원소 순서**만 바꾸기(per-adapter) | GREEN | 집계가 열거 순서로 정렬하므로 per-adapter 순서는 관측 가능한 사실이 아니다 |
| `--reason` 을 같은 값으로 두 번 주기 | GREEN | `add()` 가 중복을 흡수한다 — 흡수는 소실이 아니다 |
| 공시 문구의 **한국어 조사**만 바꾸기 | RED | 락이 문구가 아니라 수(`unit N개`)를 재는지 확인한다 — GREEN 이면 락이 문구를 안 보고 있다 |

세 번째 줄이 GREEN 이면 그것이 발견이다. 락을 고쳐 다시 돈다.

- [ ] **Step 5: 전사를 쓰고 어긋난 줄을 닫는다**

전사 형식:

```
| 축 | 대상 | 변이 | 기대 | 관측 | 폭발 반경 |
```

**기대 ≠ 관측인 줄은 전부 닫는다.** 닫히지 않은 줄이 남으면 그 줄이 이 PR 의 알려진 한계이고 PR 본문에 그대로 올라간다.

- [ ] **Step 6: 변이가 하나도 안 남았는지 확인하고 커밋**

Run: `diff HEAD --stat`
Expected: **빈 출력**. 하나라도 남으면 변이가 제품에 섞여 들어간다.

Run: `bash plugins/quality-gates/tests/test_verdict_vocabulary.sh` · `bash plugins/quality-gates/tests/test_resolution_disclosure.sh` · `python3 plugins/quality-gates/tests/test_diff_test_results.py`
Expected: 전부 GREEN.

커밋은 mutation 에서 락을 고쳤을 때만 낸다:

```
test(qg): 변이가 드러낸 락의 구멍을 닫는다

Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr2
Co-Authored-By: <실제 작성 모델> <noreply@anthropic.com>
```

---

### Task 7: 회귀 · 범위 불변식 · bump · PR

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`
- Modify: `plugins/quality-gates/CHANGELOG.md`
- Create: `.superpowers/sdd/<이 계획>/PR-BODY.md` (git-ignored)

**Interfaces:**
- Consumes: Task 1 의 `pr2-baseline.tsv` · Task 1 의 범위 불변식 · Task 6 의 전사
- Produces: PR

- [ ] **Step 1: 회귀 스위트를 baseline 과 대조한다**

Run: `bash "${CLAUDE_JOB_DIR:-/tmp}/tmp/pr2-baseline.sh" "${CLAUDE_JOB_DIR:-/tmp}/tmp/pr2-after.tsv"`
Run: `diff "${CLAUDE_JOB_DIR:-/tmp}/tmp/pr2-baseline.tsv" "${CLAUDE_JOB_DIR:-/tmp}/tmp/pr2-after.tsv"`

Expected: **신설 파일 두 줄만 추가**되고 나머지 줄은 전부 동일하다.

```
> plugins/quality-gates/tests/test_resolution_disclosure.sh	0	0
> plugins/quality-gates/tests/test_verdict_vocabulary.sh	0	0
```

`rc` 가 같아도 **실패 줄 수가 다르면 회귀다** — 이미 RED 인 파일(`test_runner_adapters.sh`) 안의 새 실패는 rc 로는 원리적으로 안 보인다.

- [ ] **Step 2: 범위 불변식을 대조한다**

Run: `diff --name-only origin/main...HEAD`
Expected: Task 1 Step 4 가 적은 목록과 **정확히 일치**. `SKILL.md` · `runtime-gate.md` · `qg.md` · `shared/` 가 한 줄이라도 나오면 범위 위반이다.

- [ ] **Step 3: 호출자 0 을 확인한다**

`--emit-verdict` 는 이 PR 에서 **아무도 켜지 않는다**(배선은 PR4).

Run: `grep -rn 'emit-verdict\|verdict\.py\|import verdict' plugins/ shared/ --include='*.md' --include='*.sh' --include='*.py' --include='*.json'`
Expected 히트: `scripts/verdict.py` 자신 · `scripts/synthesize_findings.py` 의 import 한 줄 · `tests/test_verdict_vocabulary.sh` · CHANGELOG · 이 계획문서. **그 밖에 `SKILL.md` 나 `runtime-gate.md` 히트가 있으면 배선이 샜다.**

- [ ] **Step 4: bump 와 CHANGELOG**

`plugin.json` 의 `version` 을 **minor** 올린다. 값은 **이 스텝에서 정하지 않는다** — PR 을 열기 직전에 `origin/main` 의 현재 값을 다시 보고 그 자리에서 정한다(먼저 머지되는 쪽이 이긴다. 같은 문자열은 충돌 없이 병합되므로 git 이 경고해 주지 않는다).

Run: `fetch origin` → `show origin/main:plugins/quality-gates/.claude-plugin/plugin.json` 의 `version` 확인 → 그 값의 minor +1.

CHANGELOG 항목(최신 항목 **위**에):

```markdown
## [<정한 버전>] — 2026-09-22

### Added

- **판정 어휘 세 값과 닫힌 사유 열거.** `scripts/verdict.py` 가 `clean` · `defect` · `not-certified` 와 11값 사유 열거, 우선순위(`defect > not-certified > clean`), 옛 네 값 매핑표를 한 자리에 갖는다. 사유 없는 `not-certified` 와 열거 밖 사유는 exit 4 로 막는다.
- **차등 산출물이 degrade 의 원인을 낸다.** `degrade_causes:` 가 `attribution_status: degraded` 한 값에 접혀 있던 여섯 원인을 편다. per-adapter 와 집계 양쪽에서 `degraded == (causes != [])` 를 fail-closed 로 검사한다.
- **해상도 공시(AC13).** `pre_existing > 0` 인 실행이 「양측 빨강 unit N개 — 그 안의 새 실패는 이 해상도에서 보이지 않는다」를 **per-adapter 와 집계 양쪽에** 낸다. 공시는 판정을 막지 않고 기존 bulk 가드를 대체하지도 않는다.
- `tests/test_verdict_vocabulary.sh` · `tests/test_resolution_disclosure.sh`.

**`/qg` 의 동작은 바뀌지 않는다.** 합성기의 판정 산출은 `--emit-verdict` 뒤에 있고 기본 off 이며, 켜지 않으면 stdout 이 이전과 바이트 동일하다 — 소비자 이주는 뒤 릴리스다.
```

- [ ] **Step 5: 커밋**

```
chore(qg): <버전> — 판정 어휘 · 해상도 공시

Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr2
Co-Authored-By: <실제 작성 모델> <noreply@anthropic.com>
```

- [ ] **Step 6: base 이동을 «서버에» 묻는다**

로컬 `origin/main` 은 마지막 fetch 시점의 스냅샷이다. 「이동 0」은 **그 fetch 까지** 이동이 없었다는 뜻이지 지금 없다는 뜻이 아니다. PR1 이 정확히 이 자리에서 버전 충돌을 만났다(측정 시점엔 이동 0, 몇 분 뒤 `CONFLICTING`).

Run: `fetch origin` → `merge-base --is-ancestor origin/main HEAD` 로 이동 여부 확인
PR 을 연 뒤: `gh pr view <n> --json mergeable,mergeStateStatus`
Expected: `MERGEABLE`. `CONFLICTING` 이면 **merge** 로(rebase 아님) `origin/main` 을 브랜치에 들이고 충돌을 푼 뒤 스위트를 **다시** 돌린다 — 리뷰는 움직인 base 를 못 본다.

- [ ] **Step 7: PR 본문을 쓰고 PR 을 연다**

본문에 반드시 들어갈 것:
- 합격 기준 — **`/qg` 동작 무변경** + 회귀 대조 결과(baseline 대비 차이 0 · 신설 둘)
- 신설·수정 표
- 이 PR 이 지는 AC (AC8 · AC9 · AC13 · AC23)
- **계획이 내린 판정 셋(R-A · R-B · R-C)** — 사용자가 뒤집을 수 있는 자리다
- 변이 표 요약(축 · 변이 · 기대 · 관측)
- 알려진 한계 · 이월 — PR1 에서 넘어온 넷 + 이 PR 이 만든 것

**머지는 사용자가 한다** — `! gh pr merge <n> --merge`. `gh pr merge` 는 auto-mode 판정기가 막고 `gh api` 우회는 금지다. `MERGED` 는 직접 확인한다(성공 시 무출력이라 차단과 구별되지 않는다).

---

## Self-Review

**1. Spec coverage.** §6.4.2(해상도 공시) → Task 3. §6.4.3(세 값 · 닫힌 열거 · 우선순위 · 옛↔새) → Task 4·5. AC8 → Task 4. AC9 → Task 4. AC13 → Task 3. AC23 → Task 4(표) + PR4(제거). §13 의 「새 락 5종」 중 이 PR 몫 둘(`test_verdict_vocabulary.sh` · `test_resolution_disclosure.sh`) → Task 4·3. §13 의 mutation 네 축 + 양성 대조 → Task 6. §13 의 선재 RED 기준선 → Task 1. **남는 것:** `test_angle_coverage.sh` · `test_topic_boundary.sh`(PR1 완료) · `shared/tests/test_charter_citations.sh` 는 이 PR 밖이다.

**2. Placeholder scan.** Task 2 Step 1 의 세 케이스(`test_aggregate_unions_causes_in_enum_order` · `test_aggregate_with_zero_adapters_names_no_adapters` · `test_unknown_cause_in_input_is_exit_4`)와 Task 3 Step 1 의 두 aggregate 케이스는 본문에 `...` 로 **의도를 적고 코드를 비워 두었다** — 픽스처가 `run_diff` 헬퍼의 확장을 요구하고 그 형상은 구현자가 그 자리에서 보는 것이 정확하기 때문이다. **각 자리에 무엇을 만들고 무엇을 기대하는지는 주석으로 전부 적혀 있고, `깨뜨려야 하는 변이` 표에 그 케이스의 변이가 이름으로 올라 있다.** 구현자는 그 두 줄을 요구사항으로 받는다.

**3. Type consistency.** `parse_adapter_yaml` 의 반환이 4-튜플 → **5-튜플**로 바뀐다(Task 2 Step 4). 호출자는 이 파일 안의 `_aggregate` 하나뿐이고 Task 2 Step 5 가 같은 커밋에서 함께 바꾼다. `DEGRADE_CAUSES`(Task 2) 의 7값과 `CAUSE_TO_REASON`(Task 4) 의 키 7개가 **1:1** 이다 — 한쪽만 늘면 Task 4 의 `미지의 degrade_cause` 가 exit 4 로 잡는다. `verdict.decide` 의 키워드 인자 다섯이 Task 5 의 호출과 이름까지 일치한다.

**4. 이 계획이 스스로 아는 약점.**
- `verdict.py` 의 사유 중 `angle-absent` 는 **PR3 가 배선한다** — 이 PR 에서는 열거에만 있고 산출자가 없다. Task 4 의 `case_every_reason_is_reachable` 이 「CLI 로 주면 선다」까지만 재고 「실제로 그 상태에서 발화한다」는 못 잰다. 같은 말이 `merge-conflict`(PR4) · `declaration-invalid`(PR4) · `trivia`(PR4) · `scope-empty`(PR4) 에도 해당한다. **다섯 사유의 발화 지점은 PR4 의 빚이다.**
- `test_verdict_vocabulary.sh` 가 열거를 스크립트에서 도출하므로 **스크립트와 락이 함께 틀리면** 둘 다 GREEN 이다. 그 자리의 backstop 은 리뷰와 Task 6 Step 4 의 GREEN-기대 변이뿐이다.
- 합성기 stdout 의 「바이트 접두」 단언은 **on 이 off 뒤에 붙는다**는 것만 잰다. off 자체가 PR2 이전과 같은지는 기존 락 다섯이 문면을 핀하는 것에 기댄다 — 그 락들이 안 보는 부분이 바뀌면 이 PR 은 그것을 못 잡는다.

---

## Execution Handoff

계획이 `docs/superpowers/plans/2026-09-22-qg-verdict-vocabulary-pr2.md` 에 저장됐다. 실행 방식 둘:

**1. Subagent-Driven (권장)** — Task 마다 새 subagent, Task 사이에 리뷰, 빠른 반복. `superpowers:subagent-driven-development`.

**2. Inline Execution** — 이 세션에서 체크포인트를 두고 배치 실행. `superpowers:executing-plans`.

