# 쉬운 말 출력 — 합친 /qg 막는 지적 9개 고치기 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 쉬운 말 출력 작업 네 PR(#188 · #193 · #195 · #198)을 합쳐 돌린 /qg 가 낸 막는 지적 9개를 고친다. 9개 모두 「확인하지 못한 것을 0 이나 「지적 없음」으로 말하는」 자리이거나, 그 약속을 재는 측정 · 시험의 빈틈이다.

**Architecture:** 렌더러 셋(qg 합성기 · codex 변환기 · docreview 게이트 렌더)과 측정 도구 하나, skill 한 곳의 절 순서를 고친다. 모델이 읽는 지시는 바꾸지 않는다. 예외는 사실과 어긋난 두 자리다(`reviewing-document.md` 의 참고 줄 설명 · critiquing-artifacts 의 절 순서). 기계가 읽는 토큰(`verdict:` · `**Findings:**` · `blocking:` · gate JSON · `advisory[]` 원문)은 그대로 둔다. 고칠 때마다 그 규칙을 재는 락과 변이 셀을 더한다.

**Tech Stack:** Python 3.9(macOS 시스템) · bash 3.2 · PyYAML · 리포 셸 락(`shared/tests/assert.sh`)

**Spec:** `docs/superpowers/specs/2026-10-08-plain-language-output-design.md`. 지적 원문과 고칠 방법은 `~/.claude/sdd-mirror/plain-language-output/qg-full/synth.out` 의 표와 `**고칠 방법:**` #1~#9 에 있다.

## Global Constraints

- 사람에게 보이는 글만 바꾼다. 모델이 읽는 지시는 성능 우선이라 고치지 않는다(설계 §1). 이 계획의 예외 두 자리는 Architecture 에 적었다.
- 프로그램이 읽는 글자는 남긴다: `verdict:` · `**Findings:**` · `blocking:` · `optional:` · `dropped as malformed` · gate JSON · `fin.json` 의 `advisory[]` 원문(설계 §3 표).
- 0 인 정상 집계는 내지 않는다. 판단에 필요한 0 은 쉬운 문장으로 낸다. 확인하지 못한 것은 0 과 섞지 않는다(설계 §3 원칙 3).
- 처분 회계 소비자 `plugins/quality-gates/scripts/synthesize_findings.py` 에 새 컴프리헨션 · `break` · `continue` 를 넣지 않는다(`shared/tests/test_adjudication_wiring.sh`).
- bash 3.2 에서 `$var` 바로 뒤에 한글이 오면 `${var}` 로 쓴다.
- 새 테스트 파일은 실행 권한(`chmod +x`)을 단다. 락이 새 파일을 읽으면 `# guards:` 머리를 넓힌다.
- 부재 단언마다 양성 짝을 둔다. 새 규칙 문장마다 변이 셀을 하나 둔다. 변이는 커밋한 뒤에 걸고 `git checkout HEAD -- <파일>` 로 되돌린 다음 `git diff HEAD` 가 빈 것을 확인한다.
- 버전: quality-gates 12.2.0 → 12.2.1, spec-distill 5.1.2 → 5.1.3(공유 `docreview_state.py` · `codex_findings_to_yaml.py` · `reviewing-document.md` 가 두 플러그인에 심볼릭 링크로 실린다). 머지 직전에 main 의 버전을 다시 본다 — qg v10 ⑤ 가 먼저 머지되면 그 위로 올린다.
- 커밋은 경로를 적어 한다(`git add <경로>` — `-A` 금지). 메시지는 `<type>(<scope>): <한국어 설명>`, 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- 작업 디렉토리는 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-fixes` 다. 모든 명령은 이 절대경로의 리포 루트에서 돈다.

## Review Focus

- 주 입력이 죽었는데 살아남은 지적이 있는 경우(표가 있는 갈래) — 첫 줄이 「남은 지적 N개」만 말하고 끝나면 안 된다. Task 1 의 `_status_line` 직접 호출 단언이 잰다.
- 두 지적의 요약이 공백 · 대소문자만 다른 경우 — 같은 지적이므로 plain 을 물려받아야 한다. Task 1 의 둘째 fixture 가 잰다.
- codex 가 plain 에 숫자를 넣은 경우 — 화면에 「5」 같은 글자가 나가면 안 되고 요약이 나와야 한다. Task 2 의 fixture 가 숫자 칸을 포함한다.
- 출처가 다른 두 codex 부재 원문 — 이번 수정(같은 글자 경고를 접지 않기) 뒤에도 한 줄로 합쳐져야 한다. 기존 `case_plain_warns_first_line` 과 변이 셀 `warns_same_fact_not_merged` 가 계속 잰다(Task 3 Step 6 에서 GREEN 확인).
- 사용자가 1라운드에 기각한 지적이 2라운드 화면에 나올 때 — 「이번 라운드」로 세면 안 된다. Task 3 의 2라운드 단언이 잰다.

---

### Task 1: qg 합성기 — plain 상속과 첫 줄(지적 #1 · #2)

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py` (`dedup` 302–332 · `_has_plain` 뒤에 `_same_claim` 추가 · `_status_line` 635–657 · `render` 660–669 · `main` 의 `render(...)` 호출 833–834)
- Test: `plugins/quality-gates/tests/test_plain_field_path.sh` (⑦ 끝, 150행 뒤)
- Test: `plugins/quality-gates/tests/test_plain_synth_output.sh` (④ 뒤, 82행 앞)

**Interfaces:**
- Produces: `_same_claim(a: dict, b: dict) -> bool` — 두 지적의 `summary` 가 공백을 하나로 접고 `casefold()` 한 뒤 같으면 참.
- Produces: `_status_line(counts, dropped_malformed, degraded, blocking, unconfirmed=False) -> str`
- Produces: `render(findings, dropped_malformed, report, held_classes, recritic_zero=False, *, blocking, unconfirmed=False) -> str`

- [ ] **Step 1: plain 상속 fixture 를 쓴다**

`plugins/quality-gates/tests/test_plain_field_path.sh` 에서 `assert_not_contains "$out" "셋째가 쓴 다른 문장" "Review Focus 5: 물려받는 것은 하나 — 먼저 온 쪽이다"` 줄(150행) 바로 뒤에 넣는다:

```bash
# 요약이 다른 지적은 같은 줄에 합쳐져도 plain 을 물려받지 않는다 — 다른 결함의 쉬운 문장이 엉뚱한 설명 옆에 붙는다(합친 /qg #1)
mkdir -p "$T/dupx"
printf -- '- {agent: code-reviewer, file: e.py, line: 7, severity: IMPORTANT, summary: "반복 경계가 하나 넘친다", proposed_fix: "< 로 바꾼다"}\n- {agent: security-reviewer, file: e.py, line: 7, severity: IMPORTANT, summary: "경로 탐색", plain: "사용자가 준 경로로 폴더 밖 파일을 읽을 수 있다", proposed_fix: "경로를 정규화한다"}\n' > "$T/dupx/findings.yaml"
rf_prep "$T/dupx"; rf_reply "$T/dupx" 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}'
out="$(rf_synth "$T/dupx")"
assert_eq "$(printf '%s\n' "$out" | grep -c '^| IMPORTANT | e\.py:7 |')" "1" "#1 전제: 같은 좌표의 두 지적이 한 행으로 합쳐졌다"
assert_not_contains "$out" "사용자가 준 경로로 폴더 밖 파일을 읽을 수 있다" "#1: 요약이 다른 지적의 plain 을 물려받지 않는다"
assert_grep "$out" '^\| IMPORTANT \| e\.py:7 \| 반복 경계가 하나 넘친다 \|' "#1(양의 짝): 남는 쪽은 자기 요약만 낸다"
# 요약이 공백 · 대소문자만 다르면 같은 지적이다 — plain 을 물려받는다(Review Focus)
mkdir -p "$T/dupw"
printf -- '- {agent: code-reviewer, file: f.py, line: 3, severity: IMPORTANT, summary: "Missing  Check", proposed_fix: p}\n- {agent: security-reviewer, file: f.py, line: 3, severity: IMPORTANT, summary: " missing check ", plain: "입력 검사가 빠졌다", proposed_fix: p}\n' > "$T/dupw/findings.yaml"
rf_prep "$T/dupw"; rf_reply "$T/dupw" 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}'
out="$(rf_synth "$T/dupw")"
assert_contains "$out" "입력 검사가 빠졌다 (Missing  Check)" "#1: 요약이 공백 · 대소문자만 다르면 같은 지적으로 보고 plain 을 물려받는다"
```

- [ ] **Step 2: 시험이 실패하는지 본다**

Run: `bash plugins/quality-gates/tests/test_plain_field_path.sh 2>&1 | grep -E '✗|FAIL' `
Expected: `✗ #1: 요약이 다른 지적의 plain 을 물려받지 않는다` 와 `✗ #1(양의 짝): 남는 쪽은 자기 요약만 낸다` 가 나온다. 지금 코드는 요약을 보지 않고 plain 을 물려받기 때문이다. 공백 · 대소문자 fixture 는 지금도 GREEN 이다.

- [ ] **Step 3: 같은 지적일 때만 물려받는다**

`plugins/quality-gates/scripts/synthesize_findings.py` 의 `dedup` 안에서 다음 일곱 줄을

```python
        # 남는 쪽(먼저 온 쪽)에 plain 이 없으면 합쳐진 다른 쪽 중 가장 먼저 온 쪽의 plain 을 물려받는다.
        # 뒤에서부터 덮어쓰므로 break 가 없다 — 이 파일은 처분 회계 소비자라 컴프리헨션 ·
        # 버리는 분기(break/continue)가 `shared/tests/test_adjudication_wiring.sh` 에 묶여 있다.
        if not _has_plain(merged):
            for g in reversed(group[1:]):
                if _has_plain(g):
                    merged["plain"] = g["plain"]
```

이렇게 바꾼다:

```python
        # 남는 쪽(먼저 온 쪽)에 plain 이 없으면 합쳐진 다른 쪽 중 요약이 같은 것의 plain 을 물려받는다 —
        # 좌표만 같은 다른 결함의 쉬운 문장이 이 행의 요약 옆에 붙으면 사람이 엉뚱한 문제를 고친다.
        # 뒤에서부터 덮어쓰므로 break 가 없다 — 이 파일은 처분 회계 소비자라 컴프리헨션 ·
        # 버리는 분기(break/continue)가 `shared/tests/test_adjudication_wiring.sh` 에 묶여 있다.
        if not _has_plain(merged):
            for g in reversed(group[1:]):
                if _has_plain(g) and _same_claim(g, merged):
                    merged["plain"] = g["plain"]
```

그리고 `_has_plain` 함수 바로 뒤에 더한다:

```python
def _same_claim(a, b):
    """두 지적의 요약이 공백 · 대소문자만 다른가 — 그래야 한쪽의 plain 이 다른 쪽을 말한다."""
    return (" ".join(str(a.get("summary", "")).split()).casefold()
            == " ".join(str(b.get("summary", "")).split()).casefold())
```

- [ ] **Step 4: 첫 줄 fixture 를 쓴다**

`plugins/quality-gates/tests/test_plain_synth_output.sh` 에서 `# ⑤ --emit-verdict:` 로 시작하는 줄 바로 앞에 넣는다:

```bash
# ④b 주 입력이 죽었다 — 아무도 확인하지 않은 것을 「지적 없음」이라고 말하지 않는다(설계 §3 원칙 3 · 합친 /qg #2)
mkdir -p "$T/dead"; printf '[]\n' > "$T/dead/findings.yaml"; rf_prep "$T/dead"; rf_reply "$T/dead" 'verdicts: []'
out="$(python3 "$SYNTH" --findings "$T/dead/없는.yaml" --recritic "$T/dead/reply.txt" --recritic-map "$T/dead/map.json" 2>/dev/null)"
assert_eq "$(first "$out")" "리뷰를 합쳤다 — 읽지 못한 입력이 있어 지적 수를 확정하지 못했다. 판정을 막는 경고가 있다 — 아래를 본다." "#2: 주 입력 사망의 첫 줄은 확정하지 못했다고 말한다"
assert_not_contains "$(first "$out")" "지적 없음" "#2: 주 입력 사망의 첫 줄에 「지적 없음」이 없다"
assert_grep "$out" '입력 실패\(주\)' "#2(양의 짝): 그 사실의 본문(degrade 공시)이 아래에 있다"
# 재비판자(판정 축의 주 판정자)가 죽었다 — 같은 규칙
mkdir -p "$T/dead2"; printf -- '- {agent: r, file: a.py, line: 1, severity: IMPORTANT, summary: a, proposed_fix: f}\n' > "$T/dead2/findings.yaml"; rf_prep "$T/dead2"
out="$(python3 "$SYNTH" --findings "$T/dead2/findings.yaml" --recritic "$T/dead2/없는.txt" --recritic-map "$T/dead2/map.json" 2>/dev/null)"
assert_grep "$(first "$out")" '^리뷰를 합쳤다 — (읽지 못한 입력이 있어 지적 수를 확정하지 못했다|남은 지적 [0-9]+개\(.*\)\. 읽지 못한 입력이 있어 지적이 더 있을 수 있다)\.' "#2: 재비판자가 죽은 첫 줄도 확정하지 못했다고 말한다"
mkdir -p "$T/dead3"; printf '[]\n' > "$T/dead3/findings.yaml"; rf_prep "$T/dead3"
out="$(python3 "$SYNTH" --findings "$T/dead3/findings.yaml" --recritic "$T/dead3/없는.txt" --recritic-map "$T/dead3/map.json" 2>/dev/null)"
assert_not_contains "$(first "$out")" "지적 없음" "#2: 재비판자가 죽고 남은 지적이 0 이어도 첫 줄에 「지적 없음」이 없다"
# 표가 있는 갈래 — 살아남은 지적이 있어도 「더 있을 수 있다」를 붙인다(Review Focus)
got="$(PYTHONPATH="$PLUGIN_ROOT/scripts" python3 -c 'import synthesize_findings as s; print(s._status_line({"CRITICAL": 0, "IMPORTANT": 1, "SUGGESTION": 0}, 0, True, True, True))')"
assert_eq "$got" "리뷰를 합쳤다 — 남은 지적 1개(중요 1). 읽지 못한 입력이 있어 지적이 더 있을 수 있다. 판정을 막는 경고가 있다 — 아래를 본다." "#2: 표가 있는 갈래도 확정하지 못한 사실을 붙인다"
got="$(PYTHONPATH="$PLUGIN_ROOT/scripts" python3 -c 'import synthesize_findings as s; print(s._status_line({"CRITICAL": 0, "IMPORTANT": 1, "SUGGESTION": 0}, 0, False, False))')"
assert_eq "$got" "리뷰를 합쳤다 — 남은 지적 1개(중요 1)." "#2(양의 짝): 입력을 다 읽었으면 붙이지 않는다"
```

- [ ] **Step 5: 시험이 실패하는지 본다**

Run: `bash plugins/quality-gates/tests/test_plain_synth_output.sh 2>&1 | grep -E '✗'`
Expected: 「#2: 주 입력 사망의 첫 줄은 …」 · 「#2: 주 입력 사망의 첫 줄에 「지적 없음」이 없다」 · 「#2: 재비판자가 죽은 첫 줄도 …」 · 「#2: 재비판자가 죽고 남은 지적이 0 이어도 …」 · 「#2: 표가 있는 갈래도 …」(이 줄은 `TypeError` 로 빈 값) 가 ✗ 다. 양성 짝 둘은 ✓ 다.

- [ ] **Step 6: 첫 줄이 확정하지 못한 사실을 말하게 한다**

`_status_line` 전체를 이렇게 바꾼다:

```python
def _status_line(counts, dropped_malformed, degraded, blocking, unconfirmed=False):
    """사람이 보는 첫 줄 — 스크립트가 계산한 상태 문장. 판정(verdict)과 무관하다:
    판정 없는 출력이 판정 있는 출력의 바이트 접두여야 한다(`--emit-verdict` 꼬리).
    버린 지적과 경고(degrade)는 여기에도 붙인다 — 첫 줄만 읽고 「지적 없음」으로 끝내지 않게.
    `unconfirmed` 는 주 입력이 죽었거나 셀 수 없는 것이 있다는 뜻이다 — 그때 센 수는 하한이라
    「지적 없음」이라고 쓰지 않는다(설계 §3 원칙 3: 확인하지 못한 것은 0 과 섞지 않는다)."""
    total = sum(counts.values())
    if total == 0 and unconfirmed:
        s = "리뷰를 합쳤다 — 읽지 못한 입력이 있어 지적 수를 확정하지 못했다."
    elif total == 0:
        s = "리뷰를 합쳤다 — 지적 없음."
    else:
        # for 문으로 쓴다 — 이 파일은 처분 회계 소비자라 컴프리헨션 수가 baseline 으로 묶여 있다
        # (`shared/tests/test_adjudication_wiring.sh`). 0 인 등급은 뺀다(설계 §3 원칙 3).
        parts = []
        for k, ko in _SEV_KO:
            if counts[k]:
                parts.append("%s %d" % (ko, counts[k]))
        s = "리뷰를 합쳤다 — 남은 지적 %d개(%s)." % (total, " · ".join(parts))
        if unconfirmed:
            s += " 읽지 못한 입력이 있어 지적이 더 있을 수 있다."
    if dropped_malformed > 0:
        s += " 형식이 깨져 버린 지적 %d개." % dropped_malformed
    if degraded:
        if blocking:
            s += " 판정을 막는 경고가 있다 — 아래를 본다."
        else:
            s += " 판정을 막지 않는 경고가 있다 — 아래를 본다."
    return s
```

`render` 의 서명과 첫 줄을 바꾼다:

```python
def render(findings, dropped_malformed, report, held_classes, recritic_zero=False, *, blocking, unconfirmed=False):
```

```python
    out = [_status_line(counts, dropped_malformed, report["degraded"], blocking, unconfirmed),
```

`main` 의 호출을 바꾼다:

```python
    sys.stdout.write(render(findings, dropped_malformed, report, ledger.held_by_class(),
                            recritic_zero=recritic_zero, blocking=blocking,
                            unconfirmed=ledger.primary_source_failed() or bool(report["unknown_counts"])))
```

`ledger.items_unaccounted()` 를 쓰지 않는 이유: 형식이 깨져 버린 지적도 `hold` 로 세어져 그 술어를 참으로 만든다. 그 경우는 버린 수가 첫 줄에 이미 나오고(「형식이 깨져 버린 지적 1개」) 남은 수는 확정된 값이다. 주 입력 사망과 셀 수 없음만 「확정하지 못했다」다.

- [ ] **Step 7: 시험이 통과하는지 본다**

Run: `bash plugins/quality-gates/tests/test_plain_field_path.sh 2>&1 | tail -2; bash plugins/quality-gates/tests/test_plain_synth_output.sh 2>&1 | tail -2; bash plugins/quality-gates/tests/test_synthesize_findings.sh 2>&1 | tail -1; (cd plugins/quality-gates/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_synthesize_findings_adjudication 2>&1 | tail -1); bash plugins/quality-gates/tests/test_synthesize_disposition.sh 2>&1 | tail -1; bash shared/tests/test_adjudication_wiring.sh 2>&1 | tail -1`
Expected: 모두 실패 0. 처분 회계 락이 GREEN 이다(새 컴프리헨션 · `break` · `continue` 가 없다).

- [ ] **Step 8: 커밋한다**

```bash
git add plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/tests/test_plain_field_path.sh plugins/quality-gates/tests/test_plain_synth_output.sh
git commit -m "fix(qg): 요약이 같은 지적만 plain 을 물려받고, 주 입력을 못 읽으면 첫 줄이 「지적 없음」 대신 확정하지 못했다고 말한다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 9: 변이 셋을 걸어 RED 를 본다**

각 변이 뒤 `git checkout HEAD -- plugins/quality-gates/scripts/synthesize_findings.py` 로 되돌리고 `git diff HEAD --stat` 가 빈 것을 확인한다. `PYTHONDONTWRITEBYTECODE=1` 을 켠다.

1. `sed -i '' 's/if _has_plain(g) and _same_claim(g, merged):/if _has_plain(g):/' plugins/quality-gates/scripts/synthesize_findings.py` → `test_plain_field_path.sh` 의 「#1: 요약이 다른 지적의 plain 을 물려받지 않는다」 ✗.
2. `sed -i '' 's/unconfirmed=ledger.primary_source_failed() or bool(report\["unknown_counts"\])))/unconfirmed=False))/' plugins/quality-gates/scripts/synthesize_findings.py` → `test_plain_synth_output.sh` 의 「#2: 주 입력 사망의 첫 줄은 …」 ✗.
3. `sed -i '' 's/^        if unconfirmed:$/        if False:/' plugins/quality-gates/scripts/synthesize_findings.py` → 「#2: 표가 있는 갈래도 확정하지 못한 사실을 붙인다」 ✗.

각 변이가 `grep -c` 로 정확히 한 줄을 바꿨는지 먼저 확인한다(`git diff HEAD --stat` 이 `1 insertion(+), 1 deletion(-)`).

---

### Task 2: codex plain 경로 — 변환기 정리와 비코드 추출기 fixture(지적 #5 · #4)

**Files:**
- Modify: `shared/codex/codex_findings_to_yaml.py` (`yaml_emit` 102–121 · 그 앞에 `_usable_plain` 추가)
- Test: `plugins/quality-gates/tests/test_plain_field_path.sh` (③ 끝 73행 뒤 · ⑤ 끝 95행 뒤 · 2행 `# guards:`)

**Interfaces:**
- Consumes: Task 1 이 바꾼 `test_plain_field_path.sh` (이 Task 는 다른 자리에 더한다).
- Produces: `_usable_plain(v) -> bool` (`codex_findings_to_yaml.py` 모듈 함수).

- [ ] **Step 1: 변환기 fixture 를 쓴다**

`test_plain_field_path.sh` 에서 `assert_grep "$out" '\| 길이를 확인하지 않아 범위를 넘어 읽는다 \(경계 검사 누락\) \|' "AC9: codex 지적의 plain 이 화면에 먼저 나온다"` 줄 바로 뒤에 넣는다:

```bash
# 쓸 수 없는 plain(목록 · 객체 · 숫자)은 변환기가 칸째 뺀다 — str() 로 옮기면 「['x', 'y']」 같은 글자가 화면에 나간다(합친 /qg #5)
python3 - "$T/codex-bad.jsonl" <<'PY'
import json, sys
fs = [{"file": "y.py", "line": 1, "severity": "IMPORTANT", "summary": "목록칸", "plain": ["x", "y"], "proposed_fix": "f"},
      {"file": "y.py", "line": 2, "severity": "IMPORTANT", "summary": "객체칸", "plain": {}, "proposed_fix": "f"},
      {"file": "y.py", "line": 3, "severity": "IMPORTANT", "summary": "숫자칸", "plain": 5, "proposed_fix": "f"},
      {"file": "y.py", "line": 4, "severity": "IMPORTANT", "summary": "문장칸", "plain": "쓸 수 있는 문장", "proposed_fix": "f"}]
text = "```json\n" + json.dumps({"findings": fs}, ensure_ascii=False) + "\n```"
open(sys.argv[1], "w", encoding="utf-8").write(json.dumps({"type": "item.completed", "item": {"type": "agent_message", "text": text}}, ensure_ascii=False) + "\n")
PY
python3 "$CONV" < "$T/codex-bad.jsonl" > "$T/codex-bad.yaml"
assert_eq "$(grep -c '^ *plain: ' "$T/codex-bad.yaml")" "1" "#5: 변환기는 문자열 plain 만 넘기고 목록 · 객체 · 숫자는 칸째 뺀다"
assert_eq "$(python3 -c 'import sys,yaml; print(len(yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["findings"]))' "$T/codex-bad.yaml")" "4" "#5(양의 짝): 지적 넷은 모두 남는다"
mkdir -p "$T/cxb"
python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1],encoding="utf-8")); fs=d["findings"]; [f.__setitem__("agent","codex-reviewer") for f in fs]; open(sys.argv[2],"w",encoding="utf-8").write(yaml.safe_dump(fs,allow_unicode=True))' "$T/codex-bad.yaml" "$T/cxb/findings.yaml"
rf_prep "$T/cxb"; rf_reply "$T/cxb" 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}
  - {f: f3, verdict: confirm}
  - {f: f4, verdict: confirm}'
out="$(rf_synth "$T/cxb")"
assert_not_contains "$out" "['x', 'y']" "#5: 목록 plain 의 파이썬 표기가 화면에 없다"
assert_grep "$out" '\| 목록칸 \| codex-reviewer \|$' "#5: 목록 plain 지적은 요약만 나온다"
assert_grep "$out" '\| 객체칸 \| codex-reviewer \|$' "#5: 객체 plain 지적은 요약만 나온다"
assert_grep "$out" '\| 숫자칸 \| codex-reviewer \|$' "#5: 숫자 plain 지적은 요약만 나온다(Review Focus)"
assert_grep "$out" '\| 쓸 수 있는 문장 \(문장칸\) \| codex-reviewer \|$' "#5(양의 짝): 문자열 plain 은 그대로 먼저 나온다"
```

- [ ] **Step 2: 시험이 실패하는지 본다**

Run: `bash plugins/quality-gates/tests/test_plain_field_path.sh 2>&1 | grep '✗'`
Expected: 「#5: 변환기는 문자열 plain 만 넘기고 …」(지금은 3 또는 4) · 「#5: 목록 plain 의 파이썬 표기가 화면에 없다」 · 「#5: 목록 plain 지적은 요약만 나온다」 · 「#5: 객체 plain 지적은 요약만 나온다」 가 ✗ 다. 숫자 칸은 `_yaml_scalar(5)` 가 YAML 정수 `5` 를 내고 합성기의 `_has_plain` 이 거르므로 지금도 ✓ 일 수 있다 — 그대로 둔다(Review Focus 를 고정하는 단언이다).

- [ ] **Step 3: 변환기가 쓸 수 있는 plain 만 넘긴다**

`shared/codex/codex_findings_to_yaml.py` 에서 `def yaml_emit(` 바로 앞에 더한다:

```python
def _usable_plain(v) -> bool:
    """쉬운 한 문장(`plain`)으로 쓸 수 있는 값인가 — 문자열이고 공백뿐이 아니어야 한다.
    목록 · 객체를 `_yaml_scalar(str(v))` 로 옮기면 「['x', 'y']」 같은 글자가 화면에 나간다 — 그런 값은 칸째 뺀다."""
    return isinstance(v, str) and bool(v.strip())
```

`yaml_emit` 의 키 루프 첫 줄을

```python
            for k in keys:
                if k in f:
```

이렇게 바꾼다:

```python
            for k in keys:
                if k in f and (k != "plain" or _usable_plain(f[k])):
```

- [ ] **Step 4: 비코드 추출기 fixture 를 쓴다**

`test_plain_field_path.sh` 2행의 `# guards:` 줄 끝에 ` plugins/quality-gates/scripts/extract_codex_artifact_yaml.py` 를 더한다. 그리고 `assert_contains "$out" "이 절은 앞 절과 반대로 말한다" "AC9: artifact synth 의 kept 에 plain 이 남는다"` 줄 바로 뒤에 넣는다:

```bash
# ⑤c 비코드 codex 경로 — codex JSONL → extract_codex_artifact_yaml → key → synth. 중간 변환을 실제로 지난다(AC9 · 합친 /qg #4)
python3 - "$T/acx.jsonl" <<'PY'
import json, sys
text = "```yaml\nfindings:\n  - {category: logic, target_anchor: \"#x\", severity: IMPORTANT, summary: \"x 절이 비었다\", plain: \"이 절에는 내용이 없다\", proposed_fix: \"채운다\"}\n```"
open(sys.argv[1], "w", encoding="utf-8").write(json.dumps({"type": "item.completed", "item": {"type": "agent_message", "text": text}}, ensure_ascii=False) + "\n")
PY
python3 "$PLUGIN_ROOT/scripts/extract_codex_artifact_yaml.py" < "$T/acx.jsonl" > "$T/acx.yaml"
assert_file_grep "$T/acx.yaml" '^ *plain: ' "#4: 비코드 codex 추출기가 plain 을 넘긴다"
python3 "$ART" --phase key --findings "$T/acx.yaml" > "$T/acx-merged.yaml" 2>/dev/null
K="$(python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["findings"][0]["dedup_key"])' "$T/acx-merged.yaml")"
printf 'verdicts:\n  - {finding_key: "%s", verdict: confirm, evidence: real}\n' "$K" > "$T/acx-adv.yaml"
out="$(python3 "$ART" --phase synth --findings "$T/acx-merged.yaml" --adversarial "$T/acx-adv.yaml" 2>/dev/null)"
assert_contains "$out" "이 절에는 내용이 없다" "#4: 비코드 codex 의 plain 이 추출 · key · synth 를 지나 kept 에 남는다"
assert_contains "$out" "x 절이 비었다" "#4(양의 짝): 그 지적의 요약도 kept 에 있다"
```

- [ ] **Step 5: 시험이 통과하는지 본다**

Run: `bash plugins/quality-gates/tests/test_plain_field_path.sh 2>&1 | tail -2; bash plugins/quality-gates/tests/test_codex_backward_compat.sh 2>&1 | tail -1; PYTHONDONTWRITEBYTECODE=1 python3 plugins/spec-distill/tests/test_codex_findings_to_yaml.py 2>&1 | tail -1; bash shared/tests/test_docreview_codex.sh 2>&1 | tail -1; bash plugins/quality-gates/tests/test_codex_copies_agree.sh 2>&1 | tail -1`
Expected: 실패 0(모의 실행: 21 tests OK · 280/280 · 77/77). `test_codex_backward_compat.sh` 가 시간 때문에 흔들리면 그 파일만 한 번 더 돌린다. spec-distill 이 쓰는 design · docreview 칸 묶음에는 `plain` 이 없어 바이트가 그대로다.

- [ ] **Step 6: 커밋한다**

```bash
git add shared/codex/codex_findings_to_yaml.py plugins/quality-gates/tests/test_plain_field_path.sh
git commit -m "fix(codex): 변환기가 문자열이 아닌 plain 을 칸째 빼고, 비코드 codex 의 plain 이 추출기를 지나는지 잠근다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 7: 변이 둘을 걸어 RED 를 본다**

각 변이 뒤 `git checkout HEAD -- <파일>` 과 `git diff HEAD --stat` 빈 것 확인.

1. `sed -i '' 's/if k in f and (k != "plain" or _usable_plain(f\[k\])):/if k in f:/' shared/codex/codex_findings_to_yaml.py` → 「#5: 변환기는 문자열 plain 만 넘기고 …」 ✗.
2. 추출기가 plain 을 버리게 한다(이 파일은 심볼릭 링크가 아닌 실제 파일이다). 줄을 하나 넣는 변이라 `git diff HEAD --stat` 은 `1 insertion(+)` 이다:

   ```bash
   python3 - plugins/quality-gates/scripts/extract_codex_artifact_yaml.py <<'PY'
   import sys
   p = sys.argv[1]; s = open(p, encoding="utf-8").read()
   old = '            f["agent"] = "codex-reviewer"\n'
   assert s.count(old) == 1, s.count(old)
   open(p, "w", encoding="utf-8").write(s.replace(old, old + '            f.pop("plain", None)\n'))
   PY
   ```

   → 「#4: 비코드 codex 추출기가 plain 을 넘긴다」 · 「#4: 비코드 codex 의 plain 이 추출 · key · synth 를 지나 kept 에 남는다」 ✗, 양성 짝(요약) ✓.

---

### Task 3: docreview 게이트 렌더 — 집계 줄 · 경고 개수 · 참고 줄(지적 #6 · #7 · #8)

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py` (`COUNT_GLOSS` 1281–1290 · `_plain_warns` 1320–1347 · `render_gate` 1527–1533)
- Modify: `shared/docreview/references/reviewing-document.md` (62행 — 참고 줄 설명)
- Test: `shared/tests/fixtures/docreview/cases.sh` (새 케이스 둘 · `case_plain_render_nothing_left` 의 예외 제거)
- Test: `shared/tests/fixtures/docreview/cases_advice.sh` (새 케이스 하나 · 참고 줄 단언 다섯 자리)
- Test: `shared/tests/test_docreview_route.sh` (등록) · `shared/tests/test_docreview_advice.sh` (등록) · `shared/tests/test_docreview_mutations.sh` (셀 하나 고침 · 셋 추가)

**Interfaces:**
- Produces: `COUNT_GLOSS` 의 원소가 `(key, 문장틀, scope)` 셋이 된다. `scope` 는 `"round"` 또는 `"total"`.
- Produces: 게이트 렌더에 「지금까지 집계: …」 줄이 「이번 라운드 집계: …」 줄 다음에 설 수 있다.
- Produces: advisory 축이 있고 참고 항목이 0 이면 참고 줄은 `참고 항목은 없다 — 이번 라운드에도 세어 봤다.` 다.

- [ ] **Step 1: 집계 줄 케이스를 쓴다**

`shared/tests/fixtures/docreview/cases.sh` 에서 `case_gate_marker_stays_in_group() {` 줄 바로 앞에 넣는다:

```bash
# 집계 줄 — 사용자 기각 · 버린 지적은 원장 전체의 누계다. 「이번 라운드」로 세지 않고 「지금까지」로 낸다(합친 /qg #6).
case_count_line_scope() {
  local d gr; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]" \
    || { no "집계 줄 범위: seed 실패"; rm -rf "$d"; return; }
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice reject --quote '기각한다' >/dev/null
  gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_grep "$gr" '^지금까지 집계: 사용자가 기각한 지적 1건$' "집계 줄 범위: 사용자 기각은 「지금까지 집계」 줄에 선다"
  assert_not_grep "$gr" '^이번 라운드 집계: .*사용자가 기각' "집계 줄 범위: 사용자 기각을 「이번 라운드」로 세지 않는다"
  next_round "$d" "$FX/design-sample.md" >/dev/null
  gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_grep "$gr" '^지금까지 집계: 사용자가 기각한 지적 1건$' "집계 줄 범위: 2라운드에도 1라운드의 사용자 기각은 「지금까지」에 남는다"
  assert_not_grep "$gr" '^이번 라운드 집계: .*사용자가 기각' "집계 줄 범위: 2라운드 화면이 1라운드의 기각을 「이번 라운드」로 세지 않는다(Review Focus)"
  rm -rf "$d"
}
# 같은 글자의 경고 둘은 둘로 센다 — 같은 사실을 두 출처가 말한 행(괄호 이름이 있는 행)만 한 줄로 합친다(합친 /qg #7).
case_plain_warns_same_text_counted() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
from docreview_state import _plain_warns
print(len(_plain_warns(["보류: recritic-verdict — 항목 파손: not a mapping", "보류: recritic-verdict — 항목 파손: not a mapping", "표에 없는 경고", "표에 없는 경고"])))')"
  assert_eq "$got" "4" "같은 글자 경고: 같은 모양의 사건 둘은 각각 한 줄이다(괄호 이름 없는 행 · 표에 없는 원문)"
  got="$(PYTHONPATH="$SCRIPTS" python3 -c '
from docreview_state import _first_line, GATE_ROWS
g = {r.name: [] for r in GATE_ROWS}
g.update(round=1, advisory=["보류: recritic-verdict — 항목 파손: not a mapping", "보류: recritic-verdict — 항목 파손: not a mapping"], degrade={})
print(_first_line(g))')"
  assert_grep "$got" ' 경고 2개: ' "같은 글자 경고: 첫 줄의 경고 개수가 사건 수와 같다"
  got="$(PYTHONPATH="$SCRIPTS" python3 -c '
from docreview_state import _plain_warns
print(len(_plain_warns(["codex 없음 — 모델 다양성 0 (not_installed)", "입력 실패(보조): codex — not_installed"])))')"
  assert_eq "$got" "1" "같은 글자 경고(양의 짝): 같은 사실을 두 출처가 말한 codex 행은 한 줄로 합친다"
}
```

`shared/tests/test_docreview_route.sh` 에서 `case_first_line_codex_reason_none` 줄 바로 뒤에 두 줄을 더한다:

```bash
case_count_line_scope
case_plain_warns_same_text_counted
```

- [ ] **Step 2: 참고 줄 케이스를 쓰고 기존 단언을 고친다**

`shared/tests/fixtures/docreview/cases_advice.sh` 에서 `case_advice_seed_gate_profile_yaml_broken() {` 줄 바로 앞에 넣는다:

```bash
# 배포 프로필(must_catch 지목)의 다 정상인 라운드 — 「이상 없음」 밑에 0 만 늘어선 참고 줄이 서지 않는다.
# 참고 축을 셌다는 사실은 쉬운 한 문장으로 남긴다(설계 §3 원칙 3 · AC3② · 합친 /qg #8).
case_advice_plain_render_nothing_left_mc() {
  local d gr; d="$(route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md" "$FX/critic-mc-empty.txt" "$FX/codex-empty-ok.yaml" "$FX/recritic-empty.txt")" \
    || { no "배포 프로필 쉬운 렌더 ②: route_r1 실패"; return; }
  gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_eq "$(printf '%s\n' "$gr" | grep -c '^참고 항목은 없다 — 이번 라운드에도 세어 봤다\.$')" "1" \
    "AC3②(배포 프로필): 참고 항목이 0 이면 참고 줄은 쉬운 한 문장이다"
  assert_eq "$(printf '%s\n' "$gr" | grep -cE ' 0(건|개)( |$|·|\(|\))' || true)" "0" \
    "AC3②(배포 프로필): 0 인 집계 항목이 어디에도 없다 — 참고 줄도 예외가 아니다"
  rm -rf "$d"
}
```

그리고 같은 파일의 기존 단언 다섯 자리를 고친다. 바꾸는 이유: 참고 줄이 0 일 때 「끝에 한 목록으로 보인다」 글자를 더는 쓰지 않으므로, 그 글자로 「참고 줄이 없다」를 재던 부재 단언이 공허해진다. 줄 머리 `^참고 ` 로 잰다.

- 73행 `assert_not_contains "$(py docreview_state.py gate --state-dir "$e" --render)" "끝에 한 목록으로 보인다" "AC3(음): 필드 없는 사본 프로필의 렌더에는 참고 줄이 없다"` →
  `assert_not_grep "$(py docreview_state.py gate --state-dir "$e" --render)" '^참고 ' "AC3(음): 필드 없는 사본 프로필의 렌더에는 참고 줄이 없다"`
- 395행 `assert_not_contains "$out" "끝에 한 목록으로 보인다" "Review Focus: 업그레이드 전 원장 — 게이트 렌더에 참고 줄이 없다"` →
  `assert_not_grep "$out" '^참고 ' "Review Focus: 업그레이드 전 원장 — 게이트 렌더에 참고 줄이 없다"`
- 569행의 `grep -c '끝에 한 목록으로 보인다'` → `grep -c '^참고 '`
- 573행의 `grep -c '^참고 0건(이번 라운드 새 0 · 반복 0) — 끝에 한 목록으로 보인다'` → `grep -c '^참고 항목은 없다 — 이번 라운드에도 세어 봤다\.$'`
- 582행의 `grep -c '^참고 0건(이번 라운드 새 0 · 반복 0) — 끝에 한 목록으로 보인다'` → `grep -c '^참고 항목은 없다 — 이번 라운드에도 세어 봤다\.$'`

`shared/tests/test_docreview_advice.sh` 에서 `case_advice_seed_gate_profile_yaml_broken` 이 불리는 줄 바로 앞에 `case_advice_plain_render_nothing_left_mc` 한 줄을 더한다.

`shared/tests/fixtures/docreview/cases.sh` 의 `case_plain_render_nothing_left` 에서

```bash
  assert_eq "$(printf '%s\n' "$gr" | grep -v '^참고 ' | grep -cE ' 0(건|개)( |$|·)' || true)" "0" \
    "AC3②: 0 인 정상 집계 항목이 어디에도 없다(참고 줄은 판단에 필요한 0 — 계획 P8)"
```

를 이렇게 바꾼다(필드 없는 사본 프로필이라 참고 줄은 원래 없다 — 예외가 필요 없다):

```bash
  assert_eq "$(printf '%s\n' "$gr" | grep -cE ' 0(건|개)( |$|·|\(|\))' || true)" "0" \
    "AC3②: 0 인 정상 집계 항목이 어디에도 없다"
  assert_not_grep "$gr" '^지금까지 집계' "AC3②: 전부 0 인 누계 줄이 나가지 않는다"
```

- [ ] **Step 3: 시험이 실패하는지 본다**

Run: `bash shared/tests/test_docreview_route.sh 2>&1 | grep '✗'; bash shared/tests/test_docreview_advice.sh 2>&1 | grep '✗'`
Expected: route 쪽 ✗ 여섯 — `case_count_line_scope` 의 단언 넷 전부(지금 출력이 `이번 라운드 집계: 사용자가 기각한 지적 1건` 이라 부재 단언 둘도 ✗) · 「같은 글자 경고: 같은 모양의 사건 둘은 …」 · 「같은 글자 경고: 첫 줄의 경고 개수가 …」. advice 쪽 「AC3②(배포 프로필): 참고 항목이 0 이면 …」 · 「AC3②(배포 프로필): 0 인 집계 항목이 …」(옛 줄 `참고 0건(…` 의 `0건(` 이 걸린다) · 573 · 582 자리 ✗. 양성 짝(codex 두 출처 합치기)은 ✓.

- [ ] **Step 4: 렌더를 고친다**

`shared/docreview/scripts/docreview_state.py` 의 `COUNT_GLOSS` 를 바꾼다:

```python
# 집계 줄의 사람말 — 0 은 내지 않는다(쉬운 말 출력 설계 §3 원칙 3). 순서는 옛 집계 줄과 같다.
# 셋째 칸이 범위다: "round" 는 이번 라운드의 라우팅 보고에서 오고, "total" 은 원장 전체의 누계다
# (`rejected_lineages` · 버린 fix 는 `init` 에서만 비워진다) — 누계를 「이번 라운드」로 내면 거짓이다.
COUNT_GLOSS = (
    ("rejected", "재비판이 기각한 지적 %d건", "round"),
    ("user_rejected", "사용자가 기각한 지적 %d건", "total"),
    ("dropped", "버린 지적(drop) %d건", "total"),
    ("bucket_conflicts", "같은 자리·같은 종류로 겹친 묶음 %d개", "round"),
    ("lineage_mismatch", "없는 이전 지적을 가리킨 것 %d건", "round"),
    ("revived", "기각했던 지적이 다시 나온 것 %d건", "round"),
    ("reraise_unconsumed", "다시 올릴 대상이 없는 예약 %d건", "round"),
    ("escalated_unconsumed", "결정으로 올릴 대상이 없는 예약 %d건", "round"),
)
```

`render_gate` 의 집계 두 줄

```python
    parts = [t % c[k] for k, t in COUNT_GLOSS if c[k]]
    if parts:
        out.append("이번 라운드 집계: " + " · ".join(parts))
```

을 이렇게 바꾼다:

```python
    parts = [t % c[k] for k, t, scope in COUNT_GLOSS if c[k] and scope == "round"]
    if parts:
        out.append("이번 라운드 집계: " + " · ".join(parts))
    totals = [t % c[k] for k, t, scope in COUNT_GLOSS if c[k] and scope == "total"]
    if totals:
        out.append("지금까지 집계: " + " · ".join(totals))
```

참고 줄

```python
        adv_g = g["advice"]
        out.append("참고 %d건(이번 라운드 새 %d · 반복 %d) — 끝에 한 목록으로 보인다 · 전부터 있던 절에서 새로 나온 필수 지적 %d"
                   % (adv_g["total"], adv_g["new"], adv_g["repeat"], adv_g["mc_preexisting_new"]))
```

을 이렇게 바꾼다:

```python
        adv_g = g["advice"]
        # 참고 축을 셌다는 공시는 남긴다 — 0 이면 0 을 늘어놓지 않고 쉬운 한 문장으로(설계 §3 원칙 3 · AC3②).
        if adv_g["total"] == 0 and adv_g["mc_preexisting_new"] == 0:
            out.append("참고 항목은 없다 — 이번 라운드에도 세어 봤다.")
        else:
            out.append("참고 %d건(이번 라운드 새 %d · 반복 %d) — 끝에 한 목록으로 보인다 · 전부터 있던 절에서 새로 나온 필수 지적 %d"
                       % (adv_g["total"], adv_g["new"], adv_g["repeat"], adv_g["mc_preexisting_new"]))
```

`_plain_warns` 에서 한 줄을 바꾼다:

```python
        if k not in why_of:
```

→

```python
        if k not in why_of or not isinstance(k, tuple):
```

그리고 그 함수 docstring 을 이렇게 바꾼다:

```python
    """advisory 원문 목록 → 첫 줄에 싣는 쉬운 경고 줄 목록(WARN_GLOSS). 순서는 원문이 처음 나온 순서다.
    한 줄로 합치는 것은 괄호 이름이 있는 행 — 같은 사실을 두 출처가 말한 것 — 뿐이다. 괄호 이름이 없는 행과
    표에 없는 원문은 글자가 같아도 사건마다 한 줄이다(같은 모양의 깨진 항목 둘을 하나로 세면 경고 수가 준다)."""
```

`_first_line` docstring 의 「같은 사실을 두 출처가 말한 원문은 한 줄로 합친다(계획 Q9)」는 그대로 맞다 — 고치지 않는다.

`shared/docreview/references/reviewing-document.md` 62행의 `` `참고 N건(…) — 끝에 한 목록으로 보인다` 한 줄만 싣는다 `` 를 `` `참고 N건(…) — 끝에 한 목록으로 보인다` 한 줄(참고 항목이 0 이면 `참고 항목은 없다 — 이번 라운드에도 세어 봤다.`)만 싣는다 `` 로 바꾼다. 그 줄의 나머지는 그대로 둔다.

- [ ] **Step 5: 변이 셀을 고치고 더한다**

`shared/tests/test_docreview_mutations.sh` 의 `zero_counts_revived` 셀(702–703행)을 새 줄에 맞춘다:

```bash
mut 1/1 zero_counts_revived case_plain_render_nothing_left sed_state \
  's/^    parts = \[t % c\[k\] for k, t, scope in COUNT_GLOSS if c\[k\] and scope == "round"\]$/    parts = [t % c[k] for k, t, scope in COUNT_GLOSS if scope == "round"]/'
```

`warns_unknown_dropped` 셀(739–740행) 바로 뒤에 둘을 더한다:

```bash
# 누계를 「이번 라운드」로 되돌리기 — 1라운드의 사용자 기각이 3라운드 화면에서 그 라운드 일로 읽힌다.
mut 1/1 total_counts_labelled_round case_count_line_scope sed_state \
  's/^        out\.append("지금까지 집계: " + " · "\.join(totals))$/        out.append("이번 라운드 집계: " + " · ".join(totals))/'
# 같은 글자의 경고를 다시 접기 — 같은 모양의 사건 둘이 경고 하나로 세어진다.
mut 1/1 same_text_warns_folded case_plain_warns_same_text_counted sed_state \
  's/^        if k not in why_of or not isinstance(k, tuple):$/        if k not in why_of:/'
```

같은 파일 맨 끝의 `finish` 줄 바로 앞(마지막 셀 뒤)에 더한다:

```bash
# 참고 0 의 쉬운 문장을 끄기 — 「이상 없음」 밑에 0 만 늘어선 참고 줄이 되살아난다.
mut 1/1 advice_zero_listing_revived case_advice_plain_render_nothing_left_mc sed_state \
  's/^        if adv_g\["total"\] == 0 and adv_g\["mc_preexisting_new"\] == 0:$/        if False:/'
```

- [ ] **Step 6: 시험이 통과하는지 본다**

Run: `bash shared/tests/test_docreview_route.sh 2>&1 | tail -2; bash shared/tests/test_docreview_advice.sh 2>&1 | tail -2; bash shared/tests/test_docreview_state.sh 2>&1 | tail -1; bash shared/tests/test_docreview_golden.sh 2>&1 | tail -1; bash shared/tests/test_docreview_round_gate_split.sh 2>&1 | tail -1; bash shared/tests/test_docreview_procedure_paths.sh 2>&1 | tail -1; bash shared/tests/test_docreview_mutations.sh 2>&1 | tail -3`
Expected: 모두 실패 0. 변이 스위트에서 새 셀 셋과 고친 셀 하나가 「규칙에 이빨이 있다」이다 — 모의 실행 값: `zero_counts_revived` RED(2) · `total_counts_labelled_round` RED(4) · `same_text_warns_folded` RED(2) · `advice_zero_listing_revived` RED(2) 생존(0). 그리고 기존 `warns_same_fact_not_merged` · `warns_reason_dropped` · `warns_unknown_dropped` 셀도 그대로 caught 다(그 sed 가 맞추는 줄 `            k = (row[1], row[2])` · `        if why and why not in why_of[k]:` · `            k = w` 은 바뀌지 않았다). 골든 다섯 파일은 바뀌지 않는다(사용자 기각 · 버린 지적 · 참고 줄이 그 케이스들에 없다 — `git diff --stat shared/tests/fixtures/docreview/golden` 가 빈다).

- [ ] **Step 7: 커밋한다**

```bash
git add shared/docreview/scripts/docreview_state.py shared/docreview/references/reviewing-document.md shared/tests/fixtures/docreview/cases.sh shared/tests/fixtures/docreview/cases_advice.sh shared/tests/test_docreview_route.sh shared/tests/test_docreview_advice.sh shared/tests/test_docreview_mutations.sh
git commit -m "fix(docreview): 누계를 「지금까지 집계」로 따로 내고, 같은 글자 경고를 사건마다 세며, 참고 0 을 쉬운 한 문장으로 낸다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: critiquing-artifacts 의 kill switch 절 자리와 블록 락 실행 권한(지적 #3)

**Files:**
- Modify: `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md` (`## kill switch` 절 299–305 를 `## 진입 게이트` 56행 앞으로)
- Test: `plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh` (`finish` 앞 · 20–26행 주석)
- Modify (mode only): `shared/tests/test_plain_language_block.sh` (100644 → 100755)

**Interfaces:**
- Consumes: `tools/plain-language/token_boundary.py` 의 `boundary(lines, prof, body) -> int | None` · `heads(lines)`.

- [ ] **Step 1: 자리 락을 쓴다**

`plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh` 의 마지막 `finish` 줄 바로 앞에 넣는다:

```bash
# AC2(쉬운 말 출력 설계 §2) — 규칙 블록을 넣은 뒤에도 kill switch 목록 절이 압축 뒤 다시 붙는 앞 5,000토큰 안에서 시작한다.
# 근사는 보수(cons) 쪽으로 잰다 — tools/plain-language/token_boundary.py 의 같은 함수다.
ks_lines="$(grep -n '^## kill switch$' "$S" | cut -d: -f1)"
gate_line="$(grep -n '^## 진입 게이트' "$S" | head -1 | cut -d: -f1)"
assert_eq "$(printf '%s\n' "$ks_lines" | grep -c .)" "1" "AC2: kill switch 목록 절은 하나다"
bound="$(PYTHONDONTWRITEBYTECODE=1 python3 -c 'import io,sys; sys.path.insert(0,"tools/plain-language"); import token_boundary as tb; L=io.open(sys.argv[1],encoding="utf-8").read().split("\n"); b=tb.boundary(L,"cons",True); print(len(L)+1 if b is None else b+1)' "$S")"
if [ -n "$ks_lines" ] && [ -n "$gate_line" ] && [ "$ks_lines" -lt "$gate_line" ]; then
  ok "AC2: kill switch 목록 절이 진입 게이트보다 앞이다"
else
  no "AC2: kill switch 목록 절(L${ks_lines:-?})이 진입 게이트(L${gate_line:-?})보다 앞이 아니다"
fi
if [ -n "$ks_lines" ] && [ -n "$bound" ] && [ "$ks_lines" -lt "$bound" ]; then
  ok "AC2: kill switch 목록 절이 앞 5,000토큰 안에서 시작한다(경계 L${bound})"
else
  no "AC2: kill switch 목록 절(L${ks_lines:-?})이 앞 5,000토큰 경계(L${bound:-?}) 밖이다"
fi
assert_contains "$(sed -n "${ks_lines:-1},\$p" "$S" | sed -n '1,/^## [^k]/p')" 'DEVBREW_QUALITY_GATES_DISABLE_CODEX=1' "AC2(양의 짝): 옮긴 절에 codex 스위치 줄이 그대로 있다"
```

같은 파일 20–23행 주석이 절을 「맨 끝」이라고 부르는 두 자리를 고친다(절이 더는 맨 끝에 있지 않다). 둘째 자리는 22–23행에 걸쳐 있어 글자 하나로 찾을 수 없으므로 줄 번호로 고친다:

```bash
sed -i '' -e '20s/the bottom kill-switch inventory/the kill-switch inventory section/' -e '23s/ inventory at the SKILL foot,/ inventory section,/' plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh
git diff --stat plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh
```

단언 두 줄(27–28행)은 그대로다.

- [ ] **Step 2: 시험이 실패하는지 본다**

Run: `bash plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh 2>&1 | grep '✗'`
Expected: 「AC2: kill switch 목록 절이 진입 게이트보다 앞이 아니다」 · 「AC2: kill switch 목록 절(L299)이 앞 5,000토큰 경계(L227) 밖이다」(줄 번호는 근사) ✗. 「AC2: kill switch 목록 절은 하나다」 · 양의 짝은 ✓.

- [ ] **Step 3: 절을 옮긴다**

`plugins/quality-gates/skills/critiquing-artifacts/SKILL.md` 끝의 이 여덟 줄(앞의 빈 줄 하나 포함)을 지운다:

```markdown

## kill switch

**보안 컨트롤** — 아래 스위치는 취향 설정이 아니다; 약화하는 PR은 보안 리뷰 대상이다.

- `DEVBREW_QUALITY_GATES_DISABLE=1` — 전역 즉시 종료(E0).
- `DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE=1` — 이 모드만 종료(E0).
- `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1` — codex co-review만 skip(`detect_codex.sh` 존중), tier-unpinned 단독으로 degrade.
```

그리고 `모든 스크립트는 \`${CLAUDE_PLUGIN_ROOT}/scripts/\` 하위다` 로 시작하는 문단 바로 앞에 같은 내용을 넣는다(뒤에 빈 줄 하나). 그 문단은 「아래 단계를 **순서대로** 실행한다.」로 끝나고 바로 다음이 첫 단계(`## 진입 게이트`)여야 하므로, 절을 `## 진입 게이트` 바로 앞이 아니라 그 문단 앞에 둔다:

```markdown
## kill switch

**보안 컨트롤** — 아래 스위치는 취향 설정이 아니다; 약화하는 PR은 보안 리뷰 대상이다.

- `DEVBREW_QUALITY_GATES_DISABLE=1` — 전역 즉시 종료(E0).
- `DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE=1` — 이 모드만 종료(E0).
- `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1` — codex co-review만 skip(`detect_codex.sh` 존중), tier-unpinned 단독으로 degrade.

```

파일 끝이 `## Law 2 보증` 절의 마지막 줄과 개행 하나로 끝나는지 `tail -c 1 … | od -c` 로 확인한다.

- [ ] **Step 4: 블록 락에 실행 권한을 단다**

```bash
chmod +x shared/tests/test_plain_language_block.sh
git update-index --chmod=+x shared/tests/test_plain_language_block.sh
git ls-files -s shared/tests/test_plain_language_block.sh
```

Expected: 첫 칸이 `100755`. 이 파일이 실행 권한 없이 들어가 qg 차등 테스트의 셸 러너가 그것을 맡지 못했다(합친 /qg 의 부수 발견).

- [ ] **Step 5: 시험이 통과하는지 본다**

Run: `bash plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh 2>&1 | tail -2; bash shared/tests/test_plain_language_block.sh 2>&1 | tail -1; bash plugins/quality-gates/tests/test_plain_qg_templates.sh 2>&1 | tail -1; bash plugins/quality-gates/tests/test_codex_gate_observation.sh 2>&1 | tail -1; bash plugins/quality-gates/tests/test_gate_era_prose_absent.sh 2>&1 | tail -1; bash shared/tests/test_dispatch_disposition.sh 2>&1 | tail -1; bash shared/tests/test_no_new_duplication.sh 2>&1 | tail -1`
Expected: 모두 실패 0.

- [ ] **Step 6: 커밋한다**

```bash
git add plugins/quality-gates/skills/critiquing-artifacts/SKILL.md plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh shared/tests/test_plain_language_block.sh
git commit -m "fix(qg): 비평 모드의 kill switch 절을 진입 게이트 앞으로 옮겨 압축 경계 안에 두고, 블록 락에 실행 권한을 단다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 7: 변이를 걸어 RED 를 본다**

`git show HEAD~1:plugins/quality-gates/skills/critiquing-artifacts/SKILL.md > plugins/quality-gates/skills/critiquing-artifacts/SKILL.md` (절이 맨 끝인 옛 판) → ✗ 줄 「AC2: kill switch 목록 절(L299)이 진입 게이트(L56)보다 앞이 아니다」 · 「AC2: kill switch 목록 절(L299)이 앞 5,000토큰 경계(L227) 밖이다」. `git checkout HEAD -- plugins/quality-gates/skills/critiquing-artifacts/SKILL.md` 로 되돌리고 `git diff HEAD --stat` 이 빈 것을 확인한다.

---

### Task 5: 측정 도구가 새 qg 질문을 센다(지적 #9)

**Files:**
- Modify: `tools/plain-language/measure_output.py` (주석 56–57 · `STATUS_RE` 58–72)
- Test: `tools/plain-language/test_measure_output.py` (`QuestionValues` 에 메서드 하나)

**Interfaces:**
- Consumes: 테스트 헬퍼 `Corpus` · `human` · `asst` · `auq` (같은 파일 안).

- [ ] **Step 1: 시험을 쓴다**

`tools/plain-language/test_measure_output.py` 의 `QuestionValues` 클래스에서 `def test_status_multi_tokens_and_unparsed(self):` 바로 앞에 넣는다:

```python
    def test_qg_question_templates_count_as_status_in_both_forms(self):
        # 바뀌기 전 영어 틀과 바뀐 뒤 한국어 틀을 똑같이 센다 — 한쪽만 세면 전후 비교가 문구 바뀜을 개선으로 읽는다.
        with tempfile.TemporaryDirectory() as tmp:
            c = Corpus(tmp)
            c.file("a.jsonl", [
                human("q"),
                asst(auq("qg iter 2: findings remain (x). How should we proceed?",
                         "qg 반복 2: 남은 지적이 있다(x). 어떻게 할까?",
                         "qg 가 최대 5번 반복했다. 마지막 지적: x. 지금 판정으로 끝낼까, 멈출까?",
                         "이 절을 고칠까?")),
            ])
            all_, _, _ = c.measure()
        self.assertEqual(all_["v2_status_first_line"][:2], [3, 4])
```

- [ ] **Step 2: 시험이 실패하는지 본다**

Run: `cd tools/plain-language && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_measure_output.QuestionValues.test_qg_question_templates_count_as_status_in_both_forms; cd ../..`
Expected: FAIL — `[1, 4] != [3, 4]`.

- [ ] **Step 3: 정규식과 주석을 고친다**

`STATUS_RE` 위 주석 두 줄을 바꾼다:

```python
# 엔진·스킬 틀이 내는 상태 줄의 머리. 출처: docreview_state.py render_gate 첫 줄·둘째 줄,
# 항목 렌더러의 [..] 머리표, quality-pipeline SKILL 의 fix-loop · 최대 반복 질문 틀(바뀌기 전 영어 틀과
# 바뀐 뒤 한국어 틀 둘 다 — 전후 비교가 문구 바뀜을 개선으로 읽지 않게).
```

`STATUS_RE` 의 `r"|(?:qg|Review gate) (?:iter|reached)\b"` 줄 바로 뒤에 두 줄을 더한다:

```python
    r"|qg 반복 \d+: "
    r"|qg 가 최대 \d+번 반복했다"
```

- [ ] **Step 4: 시험이 통과하는지 본다**

Run: `cd tools/plain-language && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_measure_output 2>&1 | tail -3; cd ../..`
Expected: `OK`.

- [ ] **Step 5: 커밋한다**

```bash
git add tools/plain-language/measure_output.py tools/plain-language/test_measure_output.py
git commit -m "fix(tools): 측정 도구가 바뀐 뒤의 한국어 qg 질문 틀도 상태 줄로 센다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 6: 변이 둘을 걸어 RED 를 본다**

각 변이 뒤 `git checkout HEAD -- tools/plain-language/measure_output.py` · `git diff HEAD --stat` 빈 것 확인.

1. `sed -i '' '/^    r"|qg 반복 \\d+: "$/d' tools/plain-language/measure_output.py` → 새 시험 FAIL(`[2, 4]`).
2. `sed -i '' '/^    r"|qg 가 최대 \\d+번 반복했다"$/d' tools/plain-language/measure_output.py` → 새 시험 FAIL(`[2, 4]`).

---

### Task 6: 버전 · CHANGELOG · 전체 스위트

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` (`"version": "12.2.1"`)
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` (`"version": "5.1.3"`)
- Modify: `plugins/quality-gates/CHANGELOG.md` · `plugins/spec-distill/CHANGELOG.md` (맨 위 항목)
- Modify (선택): `plugins/quality-gates/skills/quality-pipeline/SKILL.md` · `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md` 의 제목 버전 — 제목에 버전을 적는 파일만(Step 1 의 grep 결과)

- [ ] **Step 1: 버전 자리를 찾는다**

Run: `git grep -n -E '12\.2\.0|5\.1\.2' -- plugins/quality-gates plugins/spec-distill ':!*/CHANGELOG.md'`
Expected: `plugin.json` 둘과 quality-pipeline SKILL 제목 `(v12.2.0)` 이 나온다. 그 밖의 자리(테스트의 버전 핀)가 나오면 그 자리는 바꾸지 않고 「미룬 것」에 적는다 — 버전 리터럴 핀은 patch 자리를 잡지 않아야 한다.

- [ ] **Step 2: 버전을 올린다**

`plugin.json` 두 곳과 quality-pipeline SKILL 제목의 `12.2.0` → `12.2.1`, spec-distill `5.1.2` → `5.1.3`.

- [ ] **Step 3: CHANGELOG 를 쓴다**

두 블록 모두 끝에 빈 줄 하나를 두고 넣는다 — 다음 `## [` 머리가 새 항목 마지막 줄에 붙지 않게.

`plugins/quality-gates/CHANGELOG.md` 의 `## [12.2.0] — 2026-10-11` 바로 앞에:

```markdown
## [12.2.1] — 2026-10-11

### Fixed
- 합성기의 같은 줄 합치기가 요약이 같은 지적에서만 쉬운 문장(`plain`)을 물려받는다. 좌표만 같은 다른 결함의 쉬운 문장이 그 행의 요약 옆에 붙지 않는다.
- 주 입력(리뷰 결과 파일 · 재비판)을 읽지 못했거나 셀 수 없는 것이 있으면 합성기 첫 줄이 「지적 없음」 대신 「읽지 못한 입력이 있어 지적 수를 확정하지 못했다」(살아남은 지적이 있으면 「지적이 더 있을 수 있다」)를 말한다.
- 공유 codex 변환기가 문자열이 아닌 `plain`(목록 · 객체 · 숫자)을 칸째 뺀다. 화면에 `['x', 'y']` 같은 글자가 나가지 않고 요약이 나온다.
- 비평 모드(critiquing-artifacts)의 `## kill switch` 절을 진입 게이트 앞으로 옮겼다. 압축 뒤 다시 붙는 앞부분 안에 있다(쉬운 말 출력 설계 AC2).
- 문서 리뷰 게이트 렌더(공유 `docreview_state.py`): 원장 누계(사용자 기각 · 버린 지적)를 「이번 라운드 집계」가 아니라 「지금까지 집계」 줄로 낸다. 같은 글자의 경고를 사건마다 센다. 참고 항목이 0 이면 0 을 늘어놓지 않고 「참고 항목은 없다 — 이번 라운드에도 세어 봤다.」 한 문장을 낸다.
```

`plugins/spec-distill/CHANGELOG.md` 의 `## [5.1.2] — 2026-10-11` 바로 앞에:

```markdown
## [5.1.3] — 2026-10-11

### Fixed
- 문서 리뷰 게이트 렌더(공유 `docreview_state.py` — 이 플러그인에 링크로 실린다): 원장 누계(사용자 기각 · 버린 지적)를 「이번 라운드 집계」가 아니라 「지금까지 집계」 줄로 낸다. 같은 글자의 경고를 사건마다 센다 — 같은 모양의 깨진 항목 둘이 경고 하나로 줄지 않는다. 참고 항목이 0 이면 「참고 항목은 없다 — 이번 라운드에도 세어 봤다.」 한 문장을 낸다(절차서 `reviewing-document.md` 의 설명도 맞췄다).
- 공유 codex 변환기가 문자열이 아닌 `plain` 을 칸째 뺀다. spec-distill 이 쓰는 칸 묶음(design · docreview)의 출력은 그대로다.
```

- [ ] **Step 4: 변경 기록 · 소개 문구 락을 돌린다**

Run: `bash shared/tests/test_changelog_integrity.sh 2>&1 | tail -1; bash shared/tests/test_plugin_description_parity.sh 2>&1 | tail -1; bash shared/tests/test_invocation_surface.sh 2>&1 | tail -1`
Expected: 실패 0.

- [ ] **Step 5: 커밋한다**

```bash
git add plugins/quality-gates/.claude-plugin/plugin.json plugins/spec-distill/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md plugins/spec-distill/CHANGELOG.md plugins/quality-gates/skills/quality-pipeline/SKILL.md
git commit -m "chore(release): quality-gates 12.2.1 · spec-distill 5.1.3

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(Step 1 에서 quality-pipeline SKILL 제목에 버전이 없었으면 그 경로를 `git add` 에서 뺀다.)

- [ ] **Step 6: 전체 스위트를 기준선과 대조한다**

기준선은 이 브랜치의 출발점 `68a12a0b` 다. `~/.claude/sdd-mirror/plain-language-output/run-suite.sh` 는 REPO 가 지워진 워크트리로 박혀 있으므로, 그 스크립트를 복사해 REPO 를 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-fixes` 로 바꾼 사본을 `~/.claude/sdd-mirror/plain-language-fixes/run-suite.sh` 로 두고 쓴다. 기준선은 `git clone --no-local` 사본을 `68a12a0b` 에 체크아웃해서 돌린다(그 사본의 origin/main 은 쓰지 않는다).

Expected: 이 브랜치가 새로 깨뜨린 파일 0. 알려진 잡음은 셋이다 — `test_hook_output_schema.py`(워크트리 안에서만 실패) · `test_codex_runner_degrade_contract.sh` · `test_codex_backward_compat.sh`(시간에 흔들림 — 혼자 다시 돌린다). 기준선부터 실패하는 qg 하니스 `test_skill_orchestration_behavior.sh` 는 FAIL 이름이 `R1b→R8` 하나 그대로인지 본다. 실패 파일은 이름 집합으로 대조하고(`comm`), 이미 빨간 파일은 FAIL 이름 집합까지 대조한다.

---

## 미룬 것 (이 계획 범위 밖)

- 합친 /qg 의 제안 24개(SUGGESTION). 원문은 `~/.claude/sdd-mirror/plain-language-output/qg-full/synth.out` #10~#33.
- 압축 경계 밖의 kill switch · 게이트 절 중 규칙 블록 전부터 밖이던 것(plugin-audit · quality-pipeline · request-framing · reviewing-brief · spec-interview · spec-review). AC2 는 블록이 새로 밀어낸 절만 다룬다. 실측 줄은 계획 작성 때 잰 값이다(cons 경계 L167~L227).
- 실행 권한이 없는 기존 셸 테스트 둘(`plugins/spec-distill/tests/test_reviewing_brief_residue.sh` · `shared/tests/test_invocation_surface.sh`) — 쉬운 말 작업 전부터 그랬다.
- codex 리뷰는 합친 /qg 때 사용 한도로 돌지 못했다. 이 브랜치의 /qg 에서 다시 시도한다.
