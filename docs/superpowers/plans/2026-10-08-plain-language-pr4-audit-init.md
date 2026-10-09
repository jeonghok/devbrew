# 쉬운 말 출력 PR 4 — plugin-audit · project-init Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** plugin-audit 보고서와 project-init 훅 경고가 쉬운 말이 되고, 감사자 지적에 `plain:` 칸이 생겨 보고서에 먼저 보이며, 네 플러그인의 `plugin.json` 과 마켓플레이스 소개 문구가 글자까지 같아진다(락으로). 착수 전 기준선과 비교해 새 실패는 0 이어야 한다.

**Architecture:** 보고서의 앞 20줄 경고 표지(`⚠` · `degraded`)와 훅의 정규식·모델 채널(additionalContext)은 형태가 그대로다. 사람이 보는 줄만 바꾼다. 「판단에 필요한 0」(좌·우 근거의 빈 쪽 · 발견 0건 배너)은 지우지 않고 쉬운 문장으로 낸다. 감사자 `plain:` 은 Workflow 출력 스키마(`AXIS_SCHEMA`)의 선택 속성으로 생기고, 넘기는 쪽은 이미 항목을 통째로 넘기므로 그리는 쪽(`render-audit-report.py`)만 고친다.

**Tech Stack:** Python 3.9+, node(`--test`), bash, git.

**Spec:** `docs/superpowers/specs/2026-10-08-plain-language-output-design.md` (brief: `docs/superpowers/interview/2026-10-03-plain-language-output-interview.md`). 선행: PR 1 · 2 · 3 머지.

## Global Constraints

- **재결정 규약** — confirmed 항목은 근거가 있으면 보고한 뒤 재결정할 수 있고, 임의 변경은 금지다. 설계 B1~B10 · D1.1~D2.10, PR 1~3 계획의 「계획이 정한 것」이 제약이다.
- **작업 위치** — `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice`, 브랜치 `feature/plain-language-voice`. subagent 에게 이 절대경로를 매번 못 박는다.
- **git** — merge(rebase 금지), 경로 지정 커밋, Conventional Commits 에 **한국어 설명**, 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. 스태시 금지.
- **Python** — `encoding="utf-8"`, `"python3"` 리터럴 금지, Python 3.9. plugin-audit 테스트는 `plugins/plugin-audit/tests` 에서 `python3 -m unittest -v <모듈>`, node 는 `node --test --test-reporter=tap <파일>`.
- **기계가 읽는 것은 그대로** — `validate-audit-data.py` 가 보는 앞 20줄의 `⚠`/`degraded`, project-init 의 정규식 넷(`CONVENTIONAL_COMMIT_PATTERN` · `BRANCH_CREATE_RE` · `COMMIT_MSG_RE` · `HEREDOC_COMMIT_RE`)과 `regex` 블록 읽기, 훅의 모델 채널(additionalContext — `Rename the branch: …` · `Allowed prefixes: … — use whichever fits this change.`), `audit-workflow.js` 의 `agent` 식별자 2회와 dispatch 두 줄(`check-law2.py` 가 센다).
- **리뷰어 지시는 보안 민감** — 감사자의 찾는 지시는 그대로, `tools:` 그대로. 칸만 더한다.
- **버전** — plugin-audit minor(`plain:` 칸 — 새 표면), project-init patch. 번호는 머지 직전에.
- **산출 보존** — `~/.claude/sdd-mirror/plain-language-output/pr4/`.
- **줄 번호** — 이 계획의 줄 번호는 2026-10-08(PR 1 이전) 기준이다. PR 1 이 모든 `plugins/*/skills/*/SKILL.md` · `plugins/*/commands/*.md` 의 H1 뒤에 14줄(빈 줄 + 블록 13줄)을 넣었으므로 그 파일들의 줄 번호는 +14 다. 다른 파일(references · scripts · tests)은 그대로다. 편집은 줄 번호가 아니라 「옛」 문구로 찾는다.

## 계획이 정한 것

| # | 정한 것 | 근거 |
|---|---|---|
| S1 | 보고서 둘째 줄(제목 다음)에 스크립트가 계산한 상태 문장을 둔다: 「감사를 마쳤다 — 발견 N개(심각 a · 중요 b · 제안 c).」(0 인 등급은 뺀다) 또는 「감사를 마쳤다 — 보고된 발견 없음.」. 그 아래 경고 배너는 지금처럼 앞 20줄 안이다. | 설계 §3 원칙 2 · 표 `0b618227#r2.1`. 첫 줄은 제목이라 테스트가 target 을 잰다(`test_render_audit_report.py:251`). |
| S2 | 「LD4」 같은 설명 없는 번호는 뜻을 문장으로 먼저 쓰고 괄호에 둔다. | 규칙 블록 첫 불릿. |
| S3 | 좌·우 근거의 빈 쪽은 「이 쪽을 받치는 근거는 보고되지 않았다(0건)」로 낸다 — 판단에 필요한 0. 「발견 0건」 배너도 남긴다. | 설계 §3 원칙 3 · D1.2 · AC3⑦. |
| S4 | 근거의 `claim` · `file` · `line` 이 없으면 `None` 을 찍지 않는다(`claim` 이 없으면 인용만, 위치가 없으면 「(위치 없음)」). | 조사가 AC6 fixture 렌더에서 `— None:` 과 `` `None:None` `` 을 실측했다 — 처음 보는 사람에게 뜻이 없는 글자다. |
| S5 | 종료 보고는 리포트(`audit.md`) 경로만 보인다. 데이터 · 원장 경로는 사용자가 물을 때만. | 설계 §4 「파일 경로는 사용자가 열어 볼 것만」. |
| S6 | project-init 의 사람 채널(systemMessage)만 한국어로 바꾸고, 사유 토큰(`fail-open` · `Conventional Commits` · 정규식 · 접두어 목록)은 그대로 싣는다. | 설계 §3 · 훅 테스트가 두 채널을 나눠 잰다. |
| S7 | 소개 문구 같음은 새 락 `shared/tests/test_plugin_description_parity.sh` 가 잰다 — 비교 술어는 `check-staleness.py:392-415` 와 같다(같은 `name` 의 `description.strip()` 등식). | AC10. 지금 테스트는 fixture 단위뿐이다. |
| S8 | project-init README 의 원칙 절 제목을 `## Principles Instantiated` 로 바꾼다(형식 유지). | `check-shape-completeness.py:49` 가 영어 제목만 받아 지금 project-init 이 그 검사에서 빠진다. `check-staleness.py` 는 둘 다 받는다. |

## Review Focus

1. **codex 를 돌렸지만 실패한 감사** — 사람은 「돌리지 않았다」와 「돌았지만 믿을 수 없다」를 다른 일로 읽기를 기대한다(할 일이 설치 vs 재실행). → Task 1 의 고정 단언 갱신: 실행-실패 문구에 「돌리지 않았다」가 없다.
2. **양쪽 다 근거가 있는 열린 질문** — 「보고되지 않았다」 문장이 나오면 거짓이다. → Task 1 의 대조 케이스.
3. **`plain:` 이 없는 감사자 지적** — 제목으로 지금처럼 나와야 한다. → Task 2 의 `test_plain_absent_uses_title`.
4. **커밋 메시지가 한국어인 레포** — 훅 정규식은 type 만 보므로 한국어 설명이 통과해야 한다(PR 1 의 `CLAUDE.md` 규칙과 맞물린다). → Task 3 의 단언 하나.
5. **마켓플레이스에만 남은 옛 기능 광고** — project-init 소개가 지금 없는 문서 검사를 광고한다. → Task 4 의 락이 등식으로 잡는다.

---

## Task 0: 착수 준비

- [ ] **Step 1: PR 3 머지를 받는다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice
mkdir -p ~/.claude/sdd-mirror/plain-language-output/pr4
git status --porcelain
git fetch origin main
git merge-base --is-ancestor "$(git log --format=%H -1 --grep='리뷰어 지적마다 사람이 읽을 한 문장')" origin/main && echo PR3-MERGED || echo PR3-NOT-MERGED
git merge-tree --write-tree HEAD origin/main >/dev/null && echo clean || echo CONFLICT
git merge --no-edit origin/main
```

- [ ] **Step 2: 옛 문구 실재 확인**

PR 2 Task 0 Step 2 와 같은 모양의 스크립트로 아래 옛 문구가 각 파일에 정확히 한 번 있는지 센다:

```text
plugins/plugin-audit/scripts/render-audit-report.py	        banners.append("⚠ **codex 독립 감사 미실행** — LD4 모델 다양성 결손")
plugins/plugin-audit/scripts/render-audit-report.py	                            lines.append(f"  - {side_label}: 0건")
plugins/plugin-audit/scripts/codex-prompt-preamble.md	    `IMPORTANT`, `SUGGESTION`), `evidence` (array of `{file, line}` objects; `quote` optional).
plugins/plugin-audit/scripts/audit-workflow.js	          steelman_condition: { type: 'string', enum: ['a', 'b', 'c', 'd', 'none', 'pending'] },
plugins/project-init/hooks/post-tool-use.py	        f"project-init: Commit message does not follow Conventional Commits format.\n"
plugins/project-init/commands/project-init.md	> **{strategy 이름}** 전략으로 git workflow 초기화 완료.
```

- [ ] **Step 3: 기준선**

```bash
bash ~/.claude/sdd-mirror/plain-language-output/run-suite.sh pr4/baseline
```

---

## Task 1: 감사 보고서를 쉬운 말로 (Goal 2 · AC3⑦ · S1~S4)

**Files:**
- Modify: `plugins/plugin-audit/scripts/render-audit-report.py:51-120`(상태 줄 · 배너 · 근거 줄 · 좌우 빈 쪽)
- Modify: `plugins/plugin-audit/scripts/assemble-audit-data.py:113, :119`(영어 결손 문구)
- Modify: `plugins/plugin-audit/scripts/check-integrity.sh`(영어 오류 · 요약 줄)
- Modify: `plugins/plugin-audit/skills/auditing-plugins/SKILL.md:148, :187-188, :226-230` · `commands/plugin-audit.md:14`
- Modify: `plugins/plugin-audit/tests/test_render_audit_report.py`(고정 단언 · 새 단언)

- [ ] **Step 1: 실패하는 테스트를 먼저 바꾸고 더한다**

`test_render_audit_report.py`:

| 자리 | 옛 | 새 | 지키는 뜻 |
|---|---|---|---|
| :74 · :283 | `"codex 독립 감사 미실행"` | `"codex 독립 감사를 돌리지 않았다"` | 미실행이 앞 20줄에 보인다 |
| :290 | `"codex 독립 감사 실행-실패"` | `"codex 독립 감사가 돌았지만"` | 실행-실패가 보인다 |
| :292 | `assertNotIn("미실행", out, …)` | `assertNotIn("돌리지 않았다", out, …)` | 두 상태가 뭉개지지 않는다 |
| :305 | `"codex d_verdicts 2건 폐기"` | `"codex d_verdicts 2건을 버렸다"` | 버린 컬렉션·개수가 한 줄에 보인다 |
| :173 | `self.assertIn("0건", md, "OQ1 우측이 비었으면 0건으로 명시돼야 (숨기면 안 됨, §9.5)")` | `self.assertIn("우: 이 쪽을 받치는 근거는 보고되지 않았다(0건)", md, "OQ1 우측이 비었으면 그 사실을 쉬운 문장으로 낸다 (숨기면 안 됨, §9.5 · AC3⑦)")` 와 `self.assertNotIn("좌: 이 쪽을 받치는 근거는 보고되지 않았다", md, "근거가 있는 쪽엔 그 문장이 없다 (대조)")` | 빈 쪽이 보이고, 근거 있는 쪽엔 거짓 문장이 없다 |

`:89` 의 `"/6"` 은 새 배너 「⚠ **축 5/6 완주** — …」 가 그대로 담는다.

같은 파일 끝에 새 테스트 클래스를 더한다(그 파일의 `render(data)` 헬퍼 — `rc, md, err, _` 를 돌려준다 — 를 쓴다. 최소 데이터 모양은 그 파일의 기존 fixture 를 복사해 `findings` 만 바꾼다):

```python
class PlainLanguageReport(unittest.TestCase):
    """쉬운 말 출력 PR 4 (S1 · S4) — 둘째 줄이 상태 문장이고, 빈 칸은 None 으로 찍히지 않는다."""

    def _data(self, findings):
        return {"meta": {"target": "zz", "date": "2026-10-08", "codex": {"ran": True, "failed": False}},
                "findings": findings, "d_verdicts": [], "oq_answers": [], "new_open_questions": [],
                "axis_failures": [], "degraded": []}

    def _f(self, fid, sev, **kw):
        f = {"id": fid, "axis": 1, "title": "제목 " + fid, "severity": sev, "status": "reported",
             "evidence": [{"file": "a.py", "line": 1, "quote": "q"}], "user_harm": "h",
             "recommendation": "r", "counter_argument": "c", "fix_cost": "S", "reference_gap": "none"}
        f.update(kw)
        return f

    def test_second_line_is_status_and_drops_zero_grades(self):
        rc, md, err, _ = render(self._data([self._f("A1-1", "CRITICAL"), self._f("A1-2", "IMPORTANT")]))
        self.assertEqual(rc, 0, err)
        self.assertEqual(md.split("\n")[1], "감사를 마쳤다 — 발견 2개(심각 1 · 중요 1).")

    def test_no_findings_status_keeps_judgment_banner(self):
        rc, md, err, _ = render(self._data([]))
        self.assertEqual(rc, 0, err)
        self.assertEqual(md.split("\n")[1], "감사를 마쳤다 — 보고된 발견 없음.")
        self.assertIn("⚠ **발견 0건**", md, "판단에 필요한 0 배너는 남는다(S3)")

    def test_missing_claim_and_location_are_not_none(self):
        data = self._data([self._f("A1-1", "CRITICAL", evidence=[{"quote": "Run /init"}])])
        data["oq_answers"] = [{"id": "OQ1", "source": "claude", "reason": "r",
                               "left_evidence": [{"file": "a.py", "line": 1, "quote": "q1"}], "right_evidence": []}]
        rc, md, err, _ = render(data)
        self.assertEqual(rc, 0, err)
        self.assertNotIn("None", md, "빈 칸이 None 으로 찍히지 않는다(S4)")
        self.assertIn("(위치 없음)", md)
```

Run: `cd plugins/plugin-audit/tests && python3 -m unittest -v test_render_audit_report 2>&1 | tail -3; cd ../../..` → Expected: FAIL 여럿.

- [ ] **Step 2: 렌더를 고친다**

`render-audit-report.py` 의 `render()` 앞에 넣는다:

```python
_SEV_KO = (("CRITICAL", "심각"), ("IMPORTANT", "중요"), ("SUGGESTION", "제안"))


def status_line(findings: list) -> str:
    """제목 다음 줄 — 스크립트가 계산한 상태 문장(쉬운 말 출력 설계 §3). 0 인 등급은 뺀다."""
    if not findings:
        return "감사를 마쳤다 — 보고된 발견 없음."
    n = {k: sum(1 for f in findings if f.get("severity") == k) for k, _ in _SEV_KO}
    parts = " · ".join("%s %d" % (ko, n[k]) for k, ko in _SEV_KO if n[k])
    return "감사를 마쳤다 — 발견 %d개(%s)." % (len(findings), parts) if parts else "감사를 마쳤다 — 발견 %d개." % len(findings)


def where(ev: dict) -> str:
    """근거 위치 — 없으면 None 을 찍지 않는다(S4)."""
    if ev.get("file") is None:
        return "(위치 없음)"
    return "`%s:%s`" % (ev.get("file"), ev.get("line")) if ev.get("line") is not None else "`%s`" % ev.get("file")
```

`render()` 안 — 제목 줄(옛 61행) `lines = [f"# {target} 읽기전용 감사 — " + meta.get("date", "")]` 바로 뒤에 `lines.append(status_line(findings))` 를 넣는다.

배너 다섯(옛 64 · 69 · 71-72 · 74-75 · 77 · 79행)을 바꾼다:

```python
        banners.append(f"⚠ **축 {6 - len(axis_failures)}/6 완주** — {len(axis_failures)}개 축은 감사하지 못했다")
```
```python
        banners.append("⚠ **codex 독립 감사를 돌리지 않았다** — 다른 모델의 확인이 없다(LD4 모델 다양성 결손)")
```
```python
        banners.append("⚠ **codex 독립 감사가 돌았지만 결과를 믿을 수 없다** — 다른 모델의 확인이 없다"
                       "(LD4 모델 다양성 결손, degraded)")
```
```python
        banners.append(f"⚠ **codex {d.get('collection')} {d.get('count')}건을 버렸다** — 형식이 맞지 않았다"
                       f"({d.get('reason')}). 조용히 버리지 않는다")
```
```python
        banners.append(f"⚠ **빠지거나 약해진 검사 {len(degraded)}건**(degraded) — 아래 「결손」 목록을 보라")
```
```python
        banners.append("⚠ **발견 0건** — 문제가 없어서인지 감사가 실패해서인지는 축 완주 수와 기록(journal)으로 확인하라")
```

발견 근거 줄(옛 88행) `lines.append(f"- `{ev.get('file')}:{ev.get('line')}` — {ev.get('quote')}")` → `lines.append(f"- {where(ev)} — {ev.get('quote')}")`.

좌·우(옛 114-119행):

```python
                        if not side_ev:
                            lines.append(f"  - {side_label}: 이 쪽을 받치는 근거는 보고되지 않았다(0건)")
                        else:
                            lines.append(f"  - {side_label}:")
                            for e in side_ev:
                                claim = f"{e.get('claim')}: " if e.get("claim") else ""
                                lines.append(f"    - {where(e)} — {claim}{e.get('quote')}")
```

같은 파일의 나머지 `` f"`{…get('file')}:{…get('line')}`" `` 꼴 근거 줄(OQ 답 · D 판정 근거)도 `where(…)` 로 바꾼다 — `grep -n "get('file')}:{" plugins/plugin-audit/scripts/render-audit-report.py` 로 찾는다.

- [ ] **Step 3: 둘레 문구**

- `assemble-audit-data.py:113` 의 `"axis incomplete — backfilled"` → `"축 감사가 끝나지 않아 빈칸을 채웠다(backfilled)"`, `:119` 의 `"axis incomplete — backfilled (unverified)"` → `"축 감사가 끝나지 않아 빈칸을 채웠다(backfilled — 검증 안 됨)"`. 바꾸기 전에 `/usr/bin/grep -rn 'axis incomplete' plugins/plugin-audit` 로 이 글자를 읽는 코드·단언을 찾는다 — `validate-audit-data.py` 가 이 글자로 판정하면 바꾸지 않고 멈춰 보고한다(그때는 기계가 읽는 줄이다).
- `check-integrity.sh` 의 영어 사람용 줄(`FATAL: --target requires a value` · `--extra-path requires a value` · `unknown argument: $1` · `mode=ld5 requires --target <name>` · `FATAL: manifest is empty (mode=$MODE) — enumeration produced nothing.` · `mode=$MODE files=$COUNT -> $OUT`)을 같은 뜻의 한국어로 바꾼다(`[check-integrity]` 머리와 `FATAL` 토큰, 변수는 그대로). 예: `[check-integrity] FATAL: 목록이 비었다(mode=$MODE) — 열거한 파일이 하나도 없다.` · `[check-integrity] mode=$MODE 파일 $COUNT개 -> $OUT`. `test_check_integrity.py` 는 rc 만 본다.
- SKILL 148(옛) `echo "[plugin-audit] codex blind co-audit SKIPPED (reason: ${skip_reason:-unknown}) — 이 감사에는 모델 다양성이 없었다 (degraded)." >&2` → 새 `echo "[plugin-audit] codex 독립 감사를 건너뛰었다 (reason: ${skip_reason:-unknown}) — 이 감사에는 다른 모델의 확인이 없다. 모델 다양성 없음(degraded)." >&2`(`모델 다양성` · 사유 토큰이 남는다 — `test_skill_codex_gate.py:58` · `plugins/quality-gates/tests/test_codex_gate_observation.sh:314-319`).
- SKILL 187-188 의 인용 `"축 완주 수와 journal로 확인하라"` → `"축 완주 수와 기록(journal)으로 확인하라"`.
- `commands/plugin-audit.md:14` 의 `"감할 플러그인 이름이 필요합니다 — `/plugin-audit <target>`"` → `"감사할 플러그인 이름이 필요합니다 — `/plugin-audit <target>`"`(오타).

- [ ] **Step 4: 종료 보고 틀(S5)**

SKILL 226-230(옛):

```markdown
8. **종료 보고** — step 5 가 일치하고 step 7 이 GREEN 일 때만 이 종료 보고를 한다. 리포트
   (`$RUN_DIR/audit.md`) · 데이터(`$RUN_DIR/audit-data.json`) · 원장
   (`$RUN_DIR/audit-journal.jsonl`)의 절대경로를 사용자에게 보인다. 리포트는 한 번 읽는 작업 산출물이다 —
   실행 디렉토리는 git-ignore 되고 커밋하지 않는다. 이 감사의 compounding 은 감사가 낳은 수정 커밋과
   reviewer persona 편집이 맡는다.
```

새:

```markdown
8. **종료 보고** — step 5 가 일치하고 step 7 이 GREEN 일 때만 이 종료 보고를 한다. 첫 줄은 리포트 둘째 줄의
   상태 문장을 그대로 쓴다(예: 「감사를 마쳤다 — 발견 5개(심각 1 · 중요 3 · 제안 1).」). 리포트
   (`$RUN_DIR/audit.md`)의 절대경로를 보인다 — 사용자가 열어 볼 것은 이것이다. 데이터(`$RUN_DIR/audit-data.json`) ·
   원장(`$RUN_DIR/audit-journal.jsonl`) 경로는 사용자가 물을 때만 보인다. 맨 끝에 사용자가 할 일 하나를 쓴다
   (예: 「리포트의 심각 발견부터 고칠지 정해 주세요」). 리포트는 한 번 읽는 작업 산출물이다 — 실행 디렉토리는
   git-ignore 되고 커밋하지 않는다. 이 감사의 compounding 은 감사가 낳은 수정 커밋과 reviewer persona 편집이 맡는다.
```

- [ ] **Step 5: 테스트**

Run:
```bash
( cd plugins/plugin-audit/tests && for m in test_render_audit_report test_validate_audit_data test_run_dir_pipeline test_ac6_regression test_skill_codex_gate test_skill_orchestration test_assemble_audit_data test_check_integrity; do printf '%s ' "$m"; python3 -m unittest "$m" 2>&1 | tail -1; done )
bash plugins/quality-gates/tests/test_codex_gate_observation.sh | tail -1
```
Expected: 전부 `OK` / `Fail: 0`. `test_skill_orchestration` 의 INVARIANTS(`"$RUN_DIR/audit.md"` · `audit-journal.jsonl` 앵커 1회 등)가 GREEN 인지 특히 본다.

변이(커밋 뒤, AC3⑦):
1. 좌·우 빈 쪽 문장 줄을 `pass` 로 → `test_render_audit_report` 의 :173 갱신 단언 RED.
2. `status_line` 의 `if n[k]` 를 지운다 → `test_second_line_is_status_and_drops_zero_grades` RED.
3. `where` 를 쓰지 않고 옛 f-string 으로 되돌린다 → `test_missing_claim_and_location_are_not_none` RED.

- [ ] **Step 6: 커밋**

```bash
git add plugins/plugin-audit/scripts/render-audit-report.py plugins/plugin-audit/scripts/assemble-audit-data.py plugins/plugin-audit/scripts/check-integrity.sh plugins/plugin-audit/skills/auditing-plugins/SKILL.md plugins/plugin-audit/commands/plugin-audit.md plugins/plugin-audit/tests/test_render_audit_report.py
git commit -m "feat(plugin-audit): 감사 보고서를 쉬운 말로 — 상태 문장, 번호 풀이, 빈 쪽 근거 문장

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 2: 감사자 지적의 `plain:` 칸 (§5 · AC9 · 표 `0caa2c01#r2.1` · Deferred 7)

**Files:**
- Modify: `plugins/plugin-audit/scripts/audit-workflow.js:84`(`AXIS_SCHEMA` findings 속성에 `plain` — required 에 넣지 않는다)
- Modify: `plugins/plugin-audit/scripts/codex-prompt-preamble.md:24-25, :39-40`(최소 필드 문장 · 예시)
- Modify: `plugins/plugin-audit/scripts/render-audit-report.py:86`(발견 머리)
- Modify: `plugins/plugin-audit/tests/test_render_audit_report.py` · `tests/test_codex_audit_to_json.py` · `tests/audit-workflow.test.mjs`

**Interfaces:**
- 발견 머리: `### [<sev>] <plain> (<title> · <id>)<badge><deep>` — `plain` 이 있을 때. 없으면 지금처럼 `### [<sev>] <title> (<id>)<badge><deep>`.
- `codex_audit_to_json.py` 는 dict 원소를 통째로 넘긴다(89행) — 고치지 않고 테스트로 확인만 한다.

- [ ] **Step 1: 실패하는 테스트**

`test_render_audit_report.py` 의 `PlainLanguageReport` 에 더한다:

```python
    def test_plain_first_then_title(self):
        rc, md, err, _ = render(self._data([self._f("A1-1", "CRITICAL", plain="설치본에서 이 파일을 읽을 수 없다")]))
        self.assertEqual(rc, 0, err)
        self.assertIn("### [CRITICAL] 설치본에서 이 파일을 읽을 수 없다 (제목 A1-1 · A1-1)", md)

    def test_plain_absent_uses_title(self):
        rc, md, err, _ = render(self._data([self._f("A1-1", "CRITICAL")]))
        self.assertEqual(rc, 0, err)
        self.assertIn("### [CRITICAL] 제목 A1-1 (A1-1)", md, "plain 없는 지적은 지금처럼 나온다(버리지 않는다)")
```

`test_codex_audit_to_json.py` 의 `TestCodexAuditToJson` 클래스에 더한다(그 파일의 `run(stdin_text)` · `event(text)` · `fenced(payload)` 헬퍼를 쓴다):

```python
    def test_plain_passes_through(self):
        payload = {"findings": [{"id": "CX-1", "axis": 3, "title": "t", "severity": "IMPORTANT",
                                 "evidence": [{"file": "a.py", "line": 1}], "plain": "쉬운 한 문장"}],
                   "d_verdicts": [], "oq_answers": [], "new_open_questions": []}
        rc, out, _ = run(event(fenced(payload)))
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(out)["findings"][0]["plain"], "쉬운 한 문장")
```

`audit-workflow.test.mjs` 에 더한다(그 파일의 `runWorkflow(WF, …)` 가 감사 단계에 넘긴 스키마를 `captured['감사']` 로 잡는다 — 33-34행의 기존 테스트와 같은 방식):

```js
test('AXIS_SCHEMA findings 에 plain 이 선택 속성으로 있다', async () => {
  const { captured } = await runWorkflow(WF, { stubAgent: stubOneFinding() })
  const items = captured['감사'].properties.findings.items
  assert.equal(items.properties.plain.type, 'string')
  assert.ok(!items.required.includes('plain'))
})
```

Run: 세 테스트 → Expected: FAIL.

- [ ] **Step 2: 형식 둘**

`audit-workflow.js` 84행(옛) `          steelman_condition: { type: 'string', enum: ['a', 'b', 'c', 'd', 'none', 'pending'] },` 바로 뒤에:

```js
          plain: { type: 'string', description: 'Optional. The same finding in one plain sentence a first-time reader understands — no internal IDs.' },
```

`codex-prompt-preamble.md` 24-25(옛):

```markdown
  - `findings`: `id` (string), `axis` (integer), `title` (string), `severity` (one of `CRITICAL`,
    `IMPORTANT`, `SUGGESTION`), `evidence` (array of `{file, line}` objects; `quote` optional).
```

새:

```markdown
  - `findings`: `id` (string), `axis` (integer), `title` (string), `severity` (one of `CRITICAL`,
    `IMPORTANT`, `SUGGESTION`), `evidence` (array of `{file, line}` objects; `quote` optional).
    Optional `plain` (string): the same finding in one plain sentence a first-time reader understands, no internal IDs.
```

예시 39-40(옛) `    {"id": "CX-1", "axis": 3, "title": "example finding title", "severity": "IMPORTANT",` 줄을 `    {"id": "CX-1", "axis": 3, "title": "example finding title", "plain": "one plain sentence for a first-time reader", "severity": "IMPORTANT",` 로 바꾼다(`test_preamble_schema_parity.py` 는 예시를 추출기에 넣어 `codex_failed: False` 를 잰다 — 모르는 키는 통과한다).

- [ ] **Step 3: 그리기**

`render-audit-report.py` 의 발견 머리(옛 86행):

```python
        lines.append(f"### [{f.get('severity')}] {f.get('title')} ({f.get('id')}){badge}{deep_label(f)}")
```

새:

```python
        plain = f.get("plain")
        if isinstance(plain, str) and plain.strip():
            head = f"{' '.join(plain.split())} ({f.get('title')} · {f.get('id')})"
        else:
            head = f"{f.get('title')} ({f.get('id')})"
        lines.append(f"### [{f.get('severity')}] {head}{badge}{deep_label(f)}")
```

- [ ] **Step 4: 테스트와 변이**

```bash
( cd plugins/plugin-audit/tests && for m in test_render_audit_report test_codex_audit_to_json test_preamble_schema_parity test_severity_mapping test_check_law2 test_run_audit_codex_reviewer test_validate_audit_data test_run_dir_pipeline; do printf '%s ' "$m"; python3 -m unittest "$m" 2>&1 | tail -1; done )
node --test --test-reporter=tap plugins/plugin-audit/tests/audit-workflow.test.mjs 2>&1 | grep -E '^# (pass|fail)'
```
Expected: 전부 OK, node `# fail 0`.

변이: 발견 머리에서 `plain` 이 없으면 `continue` 하게 → `test_plain_absent_uses_title` RED. 복원.

- [ ] **Step 5: 커밋**

```bash
git add plugins/plugin-audit/scripts/audit-workflow.js plugins/plugin-audit/scripts/codex-prompt-preamble.md plugins/plugin-audit/scripts/render-audit-report.py plugins/plugin-audit/tests
git commit -m "feat(plugin-audit): 감사자 지적에 사람이 읽을 한 문장(plain) 칸, 보고서에 먼저

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 3: project-init 훅 경고와 명령 보고 틀 (S6)

**Files:**
- Modify: `plugins/project-init/hooks/post-tool-use.py:130-134, :143, :149, :153-154, :192-195`
- Modify: `plugins/project-init/commands/project-init.md:215, :229-230`
- Modify: `plugins/project-init/tests/test_post_tool_use.py`(사람 채널 단언)

- [ ] **Step 1: 사람 채널 단언을 새 문구로(실패 확인용)**

| 자리 | 옛 | 새 | 지키는 뜻 |
|---|---|---|---|
| :89-90 등 `"skipping"` | `"skipping"` | `"건너뛴다"` | 패턴이 없으면 검사를 건너뛴다고 알린다(fail-open 은 그대로 `"fail-open"` 으로 잰다) |
| :170 · :370 | `"does not follow naming convention"` | `"이름 규칙에 맞지 않는다"` | 브랜치 이름 위반을 알린다 |
| :371 | `"Expected pattern:"` | `"기대하는 형식:"` | 패턴을 보인다 |
| :263 · :372(사람 채널) | `"Allowed prefixes: feature, fix, release, hotfix"` | `"허용 접두어: feature, fix, release, hotfix"` | 허용 접두어를 보인다 |
| :390 | `"Suggested: feat: add thing"` | `"제안: feat: add thing"` | 고친 메시지를 제안한다 |
| :276 | `"docs/git-workflow/branch-strategy.md"` | 그대로(새 문구도 이 경로를 담는다) | 규칙 문서를 가리킨다 |

모델 채널 단언(:266 · :267 · :354 · :355 의 `"git branch -m"` · `"Allowed prefixes: …"`, :268-269 · :357-359 의 부재 단언, :392 의 `NotIn("Conventional Commits")`)은 그대로 둔다 — 모델 채널은 바꾸지 않는다. `"Conventional Commits"`(:144 · :196 · :296 · :314 · :389) · `"fail-open"`(:89 …) 은 새 문구가 그대로 담는다.

그리고 Review Focus 4 의 단언 하나를 더한다 — 그 파일은 훅 모듈을 `_hook` 으로 싣고 191행처럼 `_hook.validate_commit(...)` 을 부른다. 커밋 케이스가 있는 클래스(191행이 든 클래스)에 넣는다:

```python
    def test_korean_description_passes(self):
        """PR 1 의 CLAUDE.md 규칙(설명은 한국어)과 맞물린다 — 정규식은 type 만 본다."""
        self.assertIsNone(_hook.validate_commit('git commit -m "fix(qg): 범위 경고를 쉬운 말로"'))
```

Run: `cd plugins/project-init/tests && python3 -m unittest -v test_post_tool_use 2>&1 | tail -3; cd ../../..` → Expected: FAIL 여럿(한국어 설명 단언은 처음부터 PASS 일 수 있다 — 그것은 양의 짝이다).

- [ ] **Step 2: 사람 채널 문구**

```python
        return (
            "project-init: docs/git-workflow/branch-strategy.md 에서 쓸 수 있는 브랜치 이름 규칙을 찾지 못했다 — "
            "브랜치 이름 검사를 건너뛴다(fail-open).",
            None,  # 모델이 할 일이 없다 — 수정할 대상 자체가 없는 경고다
        )
```

```python
        hint = f"허용 접두어: {', '.join(prefixes)}"
```

```python
        hint = "허용 접두어는 docs/git-workflow/branch-strategy.md 에 있다."
```

```python
    lines = [
        f'project-init: 브랜치 이름 "{branch_name}" 이 이름 규칙에 맞지 않는다.',
        f"기대하는 형식: {pattern.pattern}",
        hint,
    ]
```

```python
    return (
        f"project-init: 커밋 메시지가 Conventional Commits 형식이 아니다.\n"
        f"형식: <type>(<scope>): <설명>\n"
        f"type: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert\n"
        f"제안: {suggested_type}: {first_line}",
        None,
    )
```

`cmd`(모델 채널, 144-147) 는 그대로다.

- [ ] **Step 3: 명령 보고 틀**

`project-init.md` 215(옛) `> **{strategy 이름}** 전략으로 git workflow 초기화 완료.` → 새 `> **{strategy 이름}** 전략으로 git workflow 를 초기화했다.`

229-230(옛 두 줄 — 벤더 문장 · `/commit` 안내)을 한 줄로 바꾼다:

```markdown
> 다음 할 일: 새 브랜치를 하나 만들어 보라 — `git checkout -b feature/<이름>` 이면 훅이 이름을 바로 확인한다.
```

바꾸기 전에 `grep -n '16+\|/commit-push-pr\|commit-commands' plugins/project-init/tests/*.py` 로 그 두 줄을 잡는 단언을 찾는다. 있으면 그 줄은 지우지 않고 할 일 줄만 맨 끝에 더한다. `test_command_contract.py` 의 규칙(「생성/업데이트된 파일:」 줄 정확히 하나 · 주장 줄 = 「hook/훅」과 「검증」을 함께 담은 줄은 1개 이하 · 부인 문장 둘)은 새 줄이 「검증」을 담지 않아 영향이 없다.

- [ ] **Step 4: 테스트**

```bash
( cd plugins/project-init/tests && python3 -m unittest -v test_post_tool_use test_command_contract 2>&1 | tail -3 )
bash plugins/project-init/tests/test_branch_strategy_rebase_clause.sh | tail -1
bash plugins/project-init/tests/test_no_write_matcher_hooks.sh | tail -1
git diff plugins/project-init/hooks/post-tool-use.py | grep -E '^[-+].*re\.compile|^[-+].*```regex' || echo "정규식 불변"
```
Expected: OK, `Fail: 0`, `정규식 불변`.

- [ ] **Step 5: 커밋**

```bash
git add plugins/project-init/hooks/post-tool-use.py plugins/project-init/commands/project-init.md plugins/project-init/tests/test_post_tool_use.py
git commit -m "feat(project-init): 훅 경고와 초기화 보고를 쉬운 한국어로

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 4: 소개 문구 같음 락 · README · 버전 (§8 · AC10 · S7 · S8)

**Files:**
- Create: `shared/tests/test_plugin_description_parity.sh`
- Modify: `plugins/plugin-audit/.claude-plugin/plugin.json` · `plugins/project-init/.claude-plugin/plugin.json` · `.claude-plugin/marketplace.json`
- Modify: `plugins/plugin-audit/README.md` · `plugins/project-init/README.md`
- Modify: 두 CHANGELOG

- [ ] **Step 1: 실패하는 락**

`shared/tests/test_plugin_description_parity.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/*/.claude-plugin/plugin.json .claude-plugin/marketplace.json
#
# 쉬운 말 출력 설계 AC10 — 플러그인마다 plugin.json 과 마켓플레이스의 소개 문구가 글자까지 같다.
# 술어는 plugins/plugin-audit/scripts/check-staleness.py:392-415 와 같다(같은 name 의 description.strip() 등식).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  git -C "$ROOT" ls-files -- 'plugins/*/.claude-plugin/plugin.json' .claude-plugin/marketplace.json
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
RES="$(mktemp -t desc-parity-XXXXXX)" || exit 1
trap 'rm -f "$RES"' EXIT
python3 - "$ROOT" > "$RES" <<'PY'
import io, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
mp = json.load(io.open(str(root / ".claude-plugin/marketplace.json"), encoding="utf-8"))
by_name = {p.get("name"): p for p in mp.get("plugins", [])}
pjs = sorted(root.glob("plugins/*/.claude-plugin/plugin.json"))
print("count %d" % len(pjs))
for pj in pjs:
    d = json.load(io.open(str(pj), encoding="utf-8"))
    name = d.get("name")
    m = by_name.get(name)
    if m is None:
        print("no %s: 마켓플레이스에 항목이 없다" % name)
    elif d.get("description", "").strip() != m.get("description", "").strip():
        print("no %s: plugin.json 과 마켓플레이스 소개 문구가 다르다" % name)
    else:
        print("ok %s: 소개 문구가 글자까지 같다" % name)
PY
n="$(sed -n 's/^count //p' "$RES")"
[ "${n:-0}" -ge 1 ] && ok "대상 plugin.json ${n}개를 구조에서 도출했다" || no "대상 plugin.json 이 0개다 — 공허한 통과"
while IFS= read -r line; do
  case "$line" in
    "ok "*) ok "${line#ok }" ;;
    "no "*) no "${line#no }" ;;
  esac
done < "$RES"
finish
```

Run: `bash shared/tests/test_plugin_description_parity.sh | tail -2` → Expected: `✗ project-init: … 다르다`, Fail 1.

- [ ] **Step 2: 소개 문구 둘을 새로 쓰고 맞춘다**

plugin-audit(두 파일 같은 글자):

```text
Audits one devbrew plugin without changing it: six read-only reviewers look for gaps, a second pass tries to disprove each one, an optional codex audit adds another model's view, and you get a ranked report. Run /plugin-audit <name>.
```

project-init(두 파일 같은 글자 — 마켓플레이스의 옛 「doc conventions, and charter integrity」 광고를 없앤다):

```text
Sets up git workflow rules and a project charter through a short interview, writes them as AGENTS.md/CLAUDE.md docs that agents read, and adds a hook that checks branch names and commit messages.
```

```bash
bash shared/tests/test_plugin_description_parity.sh | tail -1
bash shared/tests/test_charter_citations.sh | tail -1
for p in plugin-audit project-init quality-gates spec-distill; do python3 plugins/plugin-audit/scripts/check-staleness.py "plugins/$p" --repo-root . 2>/dev/null | grep -c 'description drift' ; done
```
Expected: `Fail: 0` 둘, 마지막 넷이 모두 `0`.

변이: project-init 마켓플레이스 문구의 글자 하나를 바꾼다 → 락 RED → 복원.

- [ ] **Step 3: README 둘**

plugin-audit README:
- 첫 문단 세 문장 안에 무엇을 해 주는지.
- `:23` 의 「감사가 끝나면 세 파일의 절대경로를 보고한다」 → 「감사가 끝나면 상태 한 줄과 리포트 경로를 보고한다(데이터·원장 경로는 물으면 보인다)」.
- `:42-44` 의 거짓 서술(「이 플러그인은 `CHANGELOG.md` 가 없다」)을 고친다 — CHANGELOG 가 있다.
- `## Principles Instantiated` 와 `### Three Laws` · `### KEEP-12 원칙` · `- **Law N (이름)** — 설명` 형식은 그대로, 설명만 쉬운 문장.
- 지우면 안 되는 것: `.claude/plugin-audit/`(`test_skill_orchestration.py:96-99`), `docs/audits` 는 없어야 한다, `Python 3.12+` 는 없어야 한다(`shared/tests/test_python_floor.sh:931`).

project-init README:
- 첫 문단 세 문장 안에.
- 원칙 절 제목 `## 인스턴스화한 원칙` → `## Principles Instantiated`(S8), 불릿 형식 그대로.
- 지우면 안 되는 것(`shared/tests/test_python_floor.sh:909-927`): `2026-10 이후에도 패치를 받는 버전 중 최빈` · 바닥 `3.12` · `EOL` · ERE `Python 3\.12\+`.

```bash
bash shared/tests/test_python_floor.sh | tail -1
( cd plugins/plugin-audit/tests && python3 -m unittest test_skill_orchestration test_check_shape_completeness test_check_staleness 2>&1 | tail -1 )
python3 plugins/plugin-audit/scripts/check-shape-completeness.py plugins/project-init --repo-root . 2>/dev/null | grep -i 'readme_principles' || echo "readme_principles 누락 없음"
```
Expected: `Fail: 0`, `OK`, 마지막이 `readme_principles 누락 없음` 이거나 그 항목이 충족으로 나온다.

- [ ] **Step 4: 버전 · CHANGELOG**

plugin-audit minor, project-init patch.

plugin-audit:

```markdown
## [<새 버전>] — <YYYY-MM-DD>

### Added
- 감사자 지적의 `plain:` 칸(선택) — 처음 보는 사람이 읽을 쉬운 한 문장. Workflow 출력 스키마와 codex 프롬프트에 형식이 있고, 보고서가 그것을 발견 머리에 먼저 쓴다. 칸이 없으면 지금처럼 제목이 나온다.

### Changed
- 보고서 둘째 줄이 상태 문장이다(「감사를 마쳤다 — 발견 5개(심각 1 · 중요 3 · 제안 1).」). 경고 배너가 번호(LD4)를 풀어 쓴다. 열린 질문의 빈 쪽 근거는 「이 쪽을 받치는 근거는 보고되지 않았다(0건)」로 낸다. 근거 위치·주장이 없으면 `None` 대신 「(위치 없음)」을 쓴다.
- 종료 보고가 리포트 경로만 보인다(데이터·원장은 물으면).
- 소개 문구를 쉬운 말로 바꾸고 마켓플레이스와 글자까지 맞췄다(`shared/tests/test_plugin_description_parity.sh`).
```

project-init:

```markdown
## [<새 버전>] — <YYYY-MM-DD>

### Changed
- 훅의 사람용 경고(브랜치 이름 · 커밋 메시지 · 규칙 문서 부재)가 한국어다. 정규식과 모델에게 가는 안내는 그대로다.
- 초기화 보고가 맨 끝에 할 일 하나를 말한다.
- 마켓플레이스 소개 문구가 plugin.json 과 같아졌다 — 지금 없는 문서 검사 광고를 뺐다.
- README 의 원칙 절 제목이 `## Principles Instantiated` 다.
```

- [ ] **Step 5: 최종 스위트 · 사후 측정 안내 · /qg · PR**

```bash
bash ~/.claude/sdd-mirror/plain-language-output/run-suite.sh pr4/final
comm -13 ~/.claude/sdd-mirror/plain-language-output/pr4/baseline/failures.txt ~/.claude/sdd-mirror/plain-language-output/pr4/final/failures.txt
```
Expected: 빈 출력.

```bash
git add shared/tests/test_plugin_description_parity.sh plugins/plugin-audit/.claude-plugin/plugin.json plugins/project-init/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/plugin-audit/README.md plugins/project-init/README.md plugins/plugin-audit/CHANGELOG.md plugins/project-init/CHANGELOG.md
git commit -m "docs: plugin-audit · project-init README 와 소개 문구, 소개 문구 같음 락

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

`/qg branch` — 묻는다: 「`validate-audit-data.py` 가 읽는 앞 20줄 표지가 그대로인가 · 훅의 정규식과 모델 채널이 그대로인가 · 감사자 찾는 지시가 바뀌지 않았는가」.

PR 본문(한국어): 첫 줄 한 문장 · 「계획이 정한 것」 S1~S8 · 문구 고정 테스트 표(Task 1 Step 1, Task 3 Step 1) · 변이 결과 · 할 일 하나: 「`/plugin-audit project-init` 과 빈 테스트 레포의 `/project-init` 을 한 번씩 돌려, 보고서 둘째 줄과 훅 경고가 읽히는지 봐 주세요」(Verification Plan 4). 그리고 사후 확인 안내 한 줄: 「며칠 쓴 뒤 새 세션 기록 목록을 만들어 `python3 tools/plain-language/measure_output.py <목록>` 으로 PR 1 기준선과 비교한다 — 머지 조건이 아니다(Verification Plan 3)」. 맨 끝 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

머지는 사용자가 `! gh pr merge <n> --merge`.
