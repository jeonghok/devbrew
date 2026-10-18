# R2a 계획 2 — 공유 엔진 · R2 보안 잔여 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 공유 리뷰 엔진(`shared/docreview/`)의 고정값(탐지 리뷰어 1명 · 재리뷰 상한 2 · 조언 8줄 · 60자)을 공시하고 사용자가 여는 값으로 바꾸고, 게이트 글을 혼자 읽히게 하고(결정을 한 번에 반영 · 결정 반대 본문 · 추가 라운드 승인 · 쉬운 말), R2 가 넘긴 보안 잔여(결정 줄 위조 · 원장 쓰기 락 · brief 판독기 · 실제 파서 교차 확인 · 나머지 우회)를 허용 문법 방식으로 닫는다.

**Architecture:** 엔진 값은 라운드 시작(`begin-round`)에서 한 번 푼다 — 기본 < 프로필 < 진입 < 환경 순서로 이기고, 쓰인 값과 출처를 원장의 그 라운드(`rounds[n].config`)에 적어 게이트 머리 줄이 공시한다. 라우터는 탐지 출력 파일을 여럿 받아 파일마다 신선도를 가르고, 리뷰어마다 임시 번호를 나눠 합친다. 새 장치는 신고 명령(`declare-related`) 하나이고, 나머지는 permit · `exempt_scopes` · `observe_ledger` · `decision_log` 를 넓혀 쓴다. 보안 잔여는 꼴을 하나씩 막지 않는다 — 원장 쓰기 락은 읽기 전용 하위 명령(`advice-list`)으로 원인을 치우고, brief 판독은 허용 문법 모듈 하나(`brief_body.py`)로 모으고, 그 문법을 markdown-it-py 토큰과 테스트에서 교차 확인한다.

**Tech Stack:** Python 3.9.6(시스템 `python3`) + PyYAML(엔진이 이미 쓴다) · bash 3.2 호환 셸 · 레포 셸 테스트 하네스(`shared/tests/assert.sh`) · uv(개발 전용, `pyproject.toml` · `uv.lock`) · markdown-it-py(개발 의존 — 테스트만).

**Spec:** `docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md` (§3 · AC10~AC20 · AC38~AC41 · 공통 AC36 · AC37)

## Global Constraints

- 브랜치는 `feature/shared-review-engine-core`(로드맵 R2a 블록 `브랜치:` 칸에 등록됨). HEAD 를 뒤로 옮기지 않는다. 커밋은 pathspec 으로(`git commit -- <경로…>`). push · stash 금지(지휘자가 한다).
- 커밋 메시지: Conventional Commits, `type(scope)` 영어 · 설명과 본문 한국어. 끝에 `Co-Authored-By` · `Claude-Session` 두 줄(세션이 주는 값 그대로).
- 런타임은 시스템 `python3`(3.9.6) + 엔진이 이미 쓰는 PyYAML 뿐이다 — 새 런타임 의존을 더하지 않는다. 새 판독기(`brief_body.py`)는 표준 라이브러리만 쓴다. 3.10 이상 문법(`match` · `X | Y` 타입 · `zip(strict=)`)을 쓰지 않는다.
- markdown-it-py 는 **개발 의존으로만** `pyproject.toml` 의 `[dependency-groups] dev` 와 `uv.lock` 에 고정한다(설계 B2). 런타임 코드가 import 하지 않는다. 파서가 없으면 교차 확인 테스트는 통과가 아니라 「확인 못 함(markdown-it-py 없음)」을 내고 rc ≠ 0 이다.
- **persona · 리뷰어 지시 편집은 따로 보안 리뷰를 거친다** — `shared/docreview/agents/doc-critic.md` · `doc-critic-web.md` · `doc-recritic.md`(와 그 spec-distill 사본 셋), 프로필 넷의 리뷰어 지시 본문, codex 러너 프롬프트(`run_docreview_codex_reviewer.sh` 의 스키마 줄). 편집 diff 를 qg 보안 리뷰어(`quality-gates:security-reviewer`, `tools: Read, Grep, Glob` — 웹 도구 없음)에 한 번 따로 돌리고, 결과와 판단 근거(약화가 아니라 필드 · 규칙 추가)를 PR 본문 「보안 리뷰」 절에 적는다(Task 13). 보안 잔여 diff(Task 7~12)도 같은 리뷰를 함께 받는다(설계 §3 「경계 · 리뷰」 · AC20).
- 레포 전용 값을 박지 않는다 — 기본 브랜치 이름 · 절대 경로 · `main` · devbrew 경로를 코드와 테스트에 넣지 않는다. 테스트는 `mktemp -d` 안에서만 쓰고, 레포 루트는 `$(cd "$(dirname "$0")/../.." && pwd)` 로 도출한다.
- 플러그인 버전: spec-distill 은 minor(새 하위 명령 · 새 프로필 필드 — 새 표면), quality-gates 는 patch(엔진 링크로 같은 바이트를 싣는다). **번호는 머지 직전에 지휘자가 정한다** — 이 계획 안에서는 지금 버전(spec-distill 7.2.1 · quality-gates 14.0.0)에서 도출한 임시 번호(7.3.0 · 14.0.1)를 쓰고 인계에 「번호는 머지 직전에 다시 확인」을 적는다.
- 새 셸 테스트는 실행 비트 100755(`chmod +x` 후 `git ls-files -s` 로 확인). 스크립트의 파일 읽기는 `encoding="utf-8"` 명시. 플러그인 `.py` 에 `"python3"` 리터럴을 박지 않는다. 인라인 python 은 `python3 -I`(스크립트 파일 호출에는 `-I` 금지). 긴 한글 줄은 인접 문자열로 나눈다(CPython 토크나이저).
- bash 3.2: `$var` 뒤에 한글 글자가 붙으면 `${var}` 로 쓴다. `$( )` 안 heredoc 금지. Bash 도구 셸은 zsh 다 — `PIPESTATUS` 를 쓰는 검증은 `bash -c` 안에서.
- skill 본문(`SKILL.md`)에 `$1` · `$2` 같은 위치 토큰을 쓰지 않는다(Skill 인자로 치환된다) — 이름 있는 변수로.
- 사용자에게 보이는 새 문면(게이트 렌더 · 공시 줄 · 안내 · README · CHANGELOG)은 `shared/style/plain-language.md` 규칙: 첫 줄 상태, 지적 id · AC 번호 · `§` · 필드 이름은 괄호 안.
- agent 사본은 정본과 바이트가 같아야 한다(`# copy-of:` 줄만 다름 — `shared/tests/test_copy_of_contract.sh`). `doc-critic-web.md` 는 `doc-critic.md` 와 `## 웹 근거` 블록 하나만 다르다(`test_variant_of_contract.sh`). 고정 줄 `처음 보는 사람이 읽는다 — 내부 번호 없이 쉬운 말로 쓴다` 는 여섯 파일에 남는다(`test_docreview_agent_fields.sh:87-93`).
- 골든(`shared/tests/fixtures/docreview/golden/` 20파일)은 이 계획의 의도된 변경으로 바뀐다. 갱신은 `bash shared/tests/fixtures/docreview/capture_finalize_golden.sh`(인자 없이)로만 하고, 바뀐 줄마다 어느 Task 의 의도인지 커밋 본문에 적는다.
- 겹침은 정보다 — R5 계획 셋째(`feature/epic-conductor-loop`)가 `plugins/spec-distill/skills/spec-review/SKILL.md` 의 승인 게이트 줄을, R10 이 `request-framing` · `reviewing-brief` SKILL 을 예약해 두었다. 이 계획은 그 파일들의 **다른 줄**(탐지 dispatch · 추가 라운드 문구 · `advice` 펜스)만 고친다. 각 Task 끝에 `git fetch origin` 후 `git merge-tree --write-tree HEAD origin/HEAD` 로 충돌을 미리 본다(rebase 금지 — merge).

## 설계에 없던 결정

설계가 정하지 않았거나 레포 사실과 부딪혀 이 계획이 정한 것이다. 실행 전에 사용자 확인을 받는다(재결정 규약 — 근거를 대고 사용자가 정한다). 각 항목의 「계획의 선택」대로 Task 가 쓰여 있다.

1. **탐지 리뷰어 수를 진입이 선언하는 통로.** 설계 AC10 은 출처를 「기본 · 프로필 · 진입 · 환경」 넷으로 적었지만 진입이 어떻게 선언하는지는 없다(참고 769966da · 985b28d0 · 5bc589cd). 계획의 선택: `begin-round --detectors N` 이 진입 선언이고, 순서는 기본(1) < 프로필 `detectors` < 진입 `--detectors` < 환경 `DEVBREW_DOCREVIEW_DETECTORS`. 엔진이 푼 N 을 `begin-round` 출력 JSON 의 `config.detectors.value` 로 내고, 진입 skill 은 그 값만큼 dispatch 한다. 다른 길: 참고 5bc589cd 대로 진입 통로를 빼고 셋(기본 · 프로필 · 환경)만 둔다 — 그러면 AC10 의 출처 목록을 고쳐야 한다(재결정).
2. **설정 값이 잘못됐을 때.** 환경 변수가 정수가 아니거나 범위 밖(탐지 수 · 조언 줄 수 · 요약 폭은 1 이상, 재리뷰 상한은 0 이상)이면 계획의 선택은 **그 라운드를 시작하지 않는다**(`begin-round` rc 2 · 사유 `config_invalid` · 변수 이름과 값을 낸다). 다른 길: 기본값으로 돌아가고 공시만 한다 — 사용자가 연 값이 조용히 무시될 수 있다.
3. **여러 탐지 리뷰어의 임시 번호 충돌과 출처 이름.** 리뷰어마다 `c1` 부터 매기므로 번호가 겹친다(참고 90b57878). 계획의 선택: 라우터가 리뷰어 i(2 이상)의 임시 번호를 `<ref>@d<i>` 로 바꾸고 같은 리뷰어 안의 `blocks` 만 따라 바꾼다(질문은 자기 리뷰어의 항목을 막는다). 출처 리뷰어(`detector: d<i>`)는 원장 준비(`pending_recritic`)와 최종 지적에만 싣고, 재비판에게 보이는 목록에는 싣지 않는다(익명화 유지).
4. **결정 반대 지적이 보호 절에 있을 때.** 설계 문서 프로필은 수용 기준 · 목표 등 보호 절의 `fix` 를 `decide` 로 올린다(`_classify_items` 의 보호 승격). 계획의 선택: 원장에 실재하는 결정을 가리킨 지적(`contradicts`)은 **보호 승격을 건너뛰고 저자 고침으로 간다** — 그 결정이 이미 사용자 결정이라서다. 불변 절(brief `## 6` 사용자 원문)은 예외 없이 지금처럼 `decide` 로 오른다. 다른 길: 보호 승격을 유지한다 — 그러면 보호 절의 결정 반대 본문은 다시 사용자에게 묻는다(B10 「저자가 바로 고침」과 어긋남).
5. **결정 반대가 가리킬 수 있는 결정.** 설계 문면대로 원장 `decision_log` 의 결정 id(`D<r>.<n>` — 엔진이 쓴 결정)만 실재로 친다. 문서의 결정 기록 절에 사람이 쓴 줄(`B4` · `재결정 · …` · `계획 1 결정 · …`)은 원장에 없어 「없는 결정 id」로 참고에 남고 공시된다. 다른 길: 문서 결정 기록 절의 줄 머리 식별자도 실재로 친다 — 그러면 판독 규칙(줄 머리 문법)이 하나 더 생긴다.
6. **함께 고친 곳 신고를 받는 결정과 때.** 계획의 선택: 「고친다」로 정해져 아직 관측을 기다리는 `apply` permit 이 있는 결정만 받는다(그 밖은 이름 있는 거부: `unknown_decision` · `decision_not_adopted` · `permit_consumed`). 신고는 그 permit 라운드의 `finalize` 전까지 언제든 받고, 묶인 절은 그 permit 라운드의 얼림 면제에 든다. 재비판에게 싣는 「바뀐 절 목록」은 절 제목과 앵커만이고 결정 이유는 싣지 않는다(재비판의 프레이밍 차단 — 절차 6단계).
7. **추가 라운드 승인의 출처 플래그.** 계획의 선택: `begin-round --extra-approval <값> --extra-approval-source label|typed` — 둘은 함께여야 하고 하나만 오면 rc 2(`extra_approval_source_missing` · `extra_approval_missing`). 선택지를 고르면 `label`(값은 선택지 이름 그대로), 기타 칸에 쓰면 `typed`(값은 쓴 말 그대로).
8. **원장 쓰기 권한 경계(AC17 가).** 레포에는 Write · Edit · Bash 를 경로로 막는 장치가 없다(PreToolUse 훅 0개 · 추적되는 `.claude/settings.json` 없음 · spec-distill 훅은 6.0.0 에서 제거되고 `test_review_hook_removed.py` 가 부재를 잠근다). Write · Edit 를 막는 PreToolUse 훅을 새로 만들어도 Bash(`python3 -c …`)로 상태와 요약값을 함께 바꾸는 시도는 막지 못한다. 계획의 선택: Task 9 가 후보 셋(PreToolUse 훅 · 권한 설정 deny 규칙 · 파일 모드)을 버릴 레포에서 실측하고, 셋 다 Bash 경로를 못 막으면 이 축을 닫았다고 쓰지 않고 `## 미룸` 에 이유와 받는 곳을 적는다. **받는 곳은 사용자가 정한다** — 후보: R8(devbrew 밖 · 부재 강등) · R9(규칙 문서) · GitHub 이슈.
9. **게이트 렌더의 괄호 밖 지적 id 두 자리.** 지금 렌더가 「이 답을 기다리는 수정: <지적 id>」와 「이어받은 결정: <지적 id>」를 괄호 밖에 낸다(`docreview_state.py:1471` · `:1427`). AC41 테스트가 이를 잡으므로 계획의 선택: 「이 답을 기다리는 수정 N개 (<id>, …)」 · 「다른 결정이 이어받았다 (<id>)」로 괄호 안에 옮긴다. 골든 `gate.txt` 가 바뀐다.
10. **`check_verbatim_coverage` rc 3 의 「검사 없이 계속」 기록 자리.** 계획의 선택: reviewing-brief 의 진입 게이트가 rc 3 이면 `AskUserQuestion`(「멈춘다 (권장)」 · 「검사 없이 계속」)을 띄우고, 계속을 고르면 audit `## 5` 의 기존 `record` 줄(`verbatim_coverage` · `completeness`)에 `skipped_by_user` 와 고른 선택지 이름을 적는다.

## Review Focus

1. **환경 변수로 탐지 수를 3 으로 열었는데 리뷰어 하나가 죽는다.** 사람은 게이트 첫 줄에 「탐지 3 중 1 사망」과 남은 둘의 결과를 기대하고, 라운드가 「미검증」이 되지 않기를 기대한다. Task 3 `case_detectors_partial_death` 가 잠근다.
2. **같은 문서를 프로필 탐지 수 1 로 리뷰하던 원장에 환경 변수를 켜고 다음 라운드를 연다.** 라운드마다 값과 출처가 따로 적히고, 앞 라운드의 기록은 그대로다. Task 2 `case_config_changes_between_rounds` 가 잠근다.
3. **brief `## 6` 에 사용자 원문 한 줄을 덧붙이고, 같은 라운드에 기존 원문 한 글자를 바꾼다.** 덧붙인 줄은 통과하지만 바뀐 글자 때문에 `frozen_change` 가 하나 선다. Task 1 `case_append_only_plus_edit` 가 잠근다.
4. **저자가 「고친다」 결정 하나 때문에 수용 기준 절을 고치고 신고하지 않는다.** 그 절은 「허가 없이 바뀐 곳」으로 다시 사용자에게 간다 — 신고가 면제를 만드는 유일한 길이다. Task 5 `case_related_undeclared_still_frozen` 이 잠근다.
5. **리뷰어가 요약에 줄바꿈 + `- **S9**` 을 넣어 brief `## 6` 사용자 문구 줄을 위조하려 한다(요약 · 선택지 문구 · 버림 사유 · supersedes 칸 각각).** 결정 기록은 정확히 한 줄이고 새 앵커 줄이 생기지 않는다. Task 7 의 칸별 위조 케이스가 잠근다.

---

### Task 0: 기준선 스위트를 잰다

**Files:**
- Create: `$HOME/.claude/sdd-mirror/r2a-plan2/baseline.sh` (레포 밖)

- [ ] **Step 1: 기준 스위트 스크립트를 쓴다**

`$HOME/.claude/sdd-mirror/r2a-plan2/baseline.sh`:

````bash
#!/usr/bin/env bash
# 스위트 전체를 돌려 테스트별 rc · 실패 줄 수와 실패 줄 이름을 남긴다. 리포 루트에서: bash baseline.sh <출력 접두>
set -u
out="$1"; : > "$out.tsv"; : > "$out.names"
run_capped() { perl -e 'alarm shift; exec @ARGV' 900 "$@"; }
for t in plugins/*/tests/test_*.sh plugins/*/tests/*/test_*.sh shared/tests/test_*.sh; do
  [ -f "$t" ] || continue
  log="$(PYTHONDONTWRITEBYTECODE=1 run_capped bash "$t" 2>&1)"; rc=$?
  nf="$(printf '%s\n' "$log" | grep -c -E '✗|^FAIL|^not ok' || true)"
  printf '%s\t%s\t%s\n' "$t" "$rc" "$nf" >> "$out.tsv"
  printf '%s\n' "$log" | grep -E '✗|^FAIL|^not ok' | awk -v t="$t" '{print t "\t" $0}' >> "$out.names"
done
for t in plugins/*/tests/test_*.py tools/*/tests/test_*.py; do
  [ -f "$t" ] || continue
  log="$(cd "$(dirname "$t")" && PYTHONDONTWRITEBYTECODE=1 run_capped python3 -m unittest -q "$(basename "$t" .py)" 2>&1)"; rc=$?
  nf="$(printf '%s\n' "$log" | grep -c -E '^(FAIL|ERROR):' || true)"
  printf '%s\t%s\t%s\n' "$t" "$rc" "$nf" >> "$out.tsv"
  printf '%s\n' "$log" | grep -E '^(FAIL|ERROR):' | awk -v t="$t" '{print t "\t" $0}' >> "$out.names"
done
````

- [ ] **Step 2: 기준을 잰다(백그라운드 · 다른 스위트와 동시에 돌리지 않는다)**

Run (리포 루트에서): `bash "$HOME/.claude/sdd-mirror/r2a-plan2/baseline.sh" "$HOME/.claude/sdd-mirror/r2a-plan2/before"`
Expected: `before.tsv` 에 테스트마다 한 줄, `before.names` 에 실패 줄. 비교는 rc 가 아니라 실패 줄 «이름» 집합으로 한다(이미 RED 인 파일 안의 새 실패는 rc 로 안 보인다). 기준 커밋 해시를 `before.base` 에 적는다(`git rev-parse HEAD`).

- [ ] **Step 3: 엔진 렌더의 지금 모양을 남긴다**

Run: `bash shared/tests/fixtures/docreview/capture_finalize_golden.sh "$HOME/.claude/sdd-mirror/r2a-plan2/golden-before"`
Expected: 20파일. Task 2 · 4 · 6 의 골든 갱신 diff 를 이것과 대조한다.

---

### Task 1: 인자 파서의 줄인 플래그 거부 · brief `## 6` 은 덧붙이기만 허용 (AC14)

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py` (`build_parser` :1642-1680 · `cmd_begin_round` :497-526 · `diff_snapshots` :299-331)
- Modify: `shared/docreview/scripts/docreview_route.py` (`build_parser` :941-951)
- Modify: `shared/docreview/scripts/docreview_anchor.py` (`parse_sections` :40-91 — 줄 해시)
- Test: `shared/tests/fixtures/docreview/cases.sh` (새 케이스 넷) · `shared/tests/test_docreview_state.sh` (등록)
- Create: `shared/tests/fixtures/docreview/brief-append-r1.md` · `brief-append-r2.md` · `brief-append-r2-edit.md`

**Interfaces:**
- Produces: 스냅숏 절의 새 키 `line_hashes: [str]`(줄마다 sha1 앞 12자, 절 끝 빈 줄 제외). 원장 스냅숏은 **불변 절에만** 이 키를 남긴다. `diff_snapshots` 의 `exempt_applied` 항목에 `scope: "append-only"` 가 생긴다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

픽스처 셋(brief 모양의 작은 문서). `brief-append-r1.md`:

```markdown
# brief

## 2. 확정

- C1 하나

## 6. 사용자 원문

- **S1** 「첫 말」
- **S2** 「둘째 말」
```

`brief-append-r2.md` 는 r1 의 끝에 `- **S3** 「셋째 말」` 한 줄만 덧붙인 것. `brief-append-r2-edit.md` 는 r2 에서 `「둘째 말」` 을 `「둘째 말!」` 로 바꾼 것.

`cases.sh` 끝에 더한다:

```bash
# ── AC14 — 파서는 줄인 플래그를 거부한다 ─────────────────────────────────
case_AC14_no_abbrev_flags() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC14: r1 실패"; return; }
  py docreview_state.py advice --state-dir "$d" --rend >/dev/null 2>&1; local rc=$?
  assert_eq "$rc" "2" "AC14: advice --rend(줄인 --render)는 사용법 오류 rc 2"
  py docreview_state.py gate --state-dir "$d" --rend >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "AC14: gate --rend 도 rc 2"
  py docreview_route.py finalize --state-dir "$d" --recritic-s >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "AC14: 라우터 finalize --recritic-s(줄인 --recritic-skipped)도 rc 2"
  py docreview_state.py gate --state-dir "$d" --render >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "0" "AC14 양성 짝: 온전한 플래그는 그대로 rc 0"
  rm -rf "$d"
}
# ── AC14 — brief 「## 6」 은 끝에 덧붙인 줄만이면 통과 ─────────────────────
case_AC14_append_only_passes() {
  local d s1 s2; d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC14: init 실패"; return; }
  s1="$d/s1.json"; snap "$FX/brief-append-r1.md" "$s1"
  py docreview_state.py begin-round --state-dir "$d" --snapshot "$s1" >/dev/null
  s2="$d/s2.json"; snap "$FX/brief-append-r2.md" "$s2"
  py docreview_state.py begin-round --state-dir "$d" --snapshot "$s2" >/dev/null
  py docreview_state.py exempt-anchors --state-dir "$d" > "$d/ex2.json"
  local out; out="$(python3 -I -c 'import sys,json; sys.path.insert(0,sys.argv[1]); import docreview_state as S, yaml; t=open(sys.argv[2],encoding="utf-8").read(); st=yaml.safe_load(t[4:t.find("\n---\n",4)])["docreview"]; p=S.load_profile(st["profile"]); d=S.round_diff(st,p,2); print([c["anchor"] for c in d["changed"]], [e.get("scope") for e in d["exempt_applied"]])' "$SCRIPTS" "$d/docreview-state.md")"
  assert_eq "$out" "[] ['append-only']" "AC14: 「## 6」 끝에 덧붙인 줄만이면 changed 가 없고 append-only 면제로 보인다"
  rm -rf "$d"
}
case_AC14_append_only_plus_edit() {
  local d s1 s2; d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC14: init 실패"; return; }
  s1="$d/s1.json"; snap "$FX/brief-append-r1.md" "$s1"
  py docreview_state.py begin-round --state-dir "$d" --snapshot "$s1" >/dev/null
  s2="$d/s2.json"; snap "$FX/brief-append-r2-edit.md" "$s2"
  py docreview_state.py begin-round --state-dir "$d" --snapshot "$s2" >/dev/null
  local out; out="$(python3 -I -c 'import sys; sys.path.insert(0,sys.argv[1]); import docreview_state as S, yaml; t=open(sys.argv[2],encoding="utf-8").read(); st=yaml.safe_load(t[4:t.find("\n---\n",4)])["docreview"]; p=S.load_profile(st["profile"]); d=S.round_diff(st,p,2); print([c["anchor"] for c in d["changed"]])' "$SCRIPTS" "$d/docreview-state.md")"
  assert_eq "$out" "['#6-사용자-원문']" "AC14: 이미 있는 원문 줄이 바뀌면 덧붙인 줄이 함께 있어도 frozen_change 대상이다"
  rm -rf "$d"
}
case_AC14_line_hashes_only_immutable() {
  local d s1; d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC14: init 실패"; return; }
  s1="$d/s1.json"; snap "$FX/brief-append-r1.md" "$s1"
  py docreview_state.py begin-round --state-dir "$d" --snapshot "$s1" >/dev/null
  assert_eq "$(st_yaml "$d" 'sorted(s["anchor"] for s in st["snapshots"]["1"]["sections"] if "line_hashes" in s)')" "['#6-사용자-원문']" "AC14: 원장 스냅숏은 불변 절에만 줄 해시를 남긴다(원장 크기)"
  rm -rf "$d"
}
```

`test_docreview_state.sh` 의 케이스 목록 끝(`finish` 앞)에 넷을 등록한다.

- [ ] **Step 2: 테스트가 실패하는지 본다**

Run: `bash shared/tests/test_docreview_state.sh 2>&1 | grep -E 'AC14|Total'`
Expected: AC14 줄 다섯 중 양성 짝만 ✓, 나머지 ✗(줄인 플래그가 받아들여짐 · `changed` 에 `#6-사용자-원문` · `line_hashes` 없음).

- [ ] **Step 3: 구현한다**

`docreview_anchor.py` `parse_sections` 의 `add` 안:

```python
    def add(anchor, title, level, a, b, parents):
        rows = [x.rstrip() for x in lines[a:b]]
        while rows and rows[-1] == "":
            rows.pop()
        body = "\n".join(rows).strip("\n")
        item = {"anchor": anchor, "title": title, "level": level, "line": a + 1,
                "hash": hashlib.sha1(body.encode("utf-8")).hexdigest()[:12],
                "line_hashes": [hashlib.sha1(r.encode("utf-8")).hexdigest()[:12] for r in rows],
                "parents": list(parents)}
```

(`body` 의 해시 값은 지금과 같다 — `"\n".join(...).strip("\n")` 은 끝 빈 줄을 원래도 버렸다. 이 사실을 Step 4 의 골든 무변경으로 확인한다.)

`docreview_state.py` `cmd_begin_round` 의 스냅숏 저장:

```python
    prof = load_profile(st["profile"])
    imm = set(anchors_matching(prof["immutable"], snap.get("sections", []))) if prof["immutable"] else set()
    keep = ("anchor", "title", "level", "hash", "parents")
    secs = []
    for s in snap.get("sections", []):
        row = {k: s.get(k) for k in keep}
        if s.get("anchor") in imm and isinstance(s.get("line_hashes"), list):
            row["line_hashes"] = list(s["line_hashes"])
        secs.append(row)
    st["snapshots"][str(n)] = {"headingless": bool(snap.get("headingless")), "sections": secs}
```

`diff_snapshots` 의 `modified` 분기:

```python
    for a, s in nm.items():
        if a not in om:
            rec(a, "added", s["title"], None, s["hash"])
        elif om[a]["hash"] != s["hash"]:
            if _appended_only(om[a], s):
                exempt_applied.append({"anchor": a, "kind": "appended", "title": s["title"],
                                       "old_hash": om[a]["hash"], "new_hash": s["hash"], "scope": "append-only",
                                       "evidence": "섹션 '%s' (%s) 끝에 줄만 더해짐" % (s["title"], a)})
            else:
                rec(a, "modified", s["title"], om[a]["hash"], s["hash"])
```

그 위에:

```python
def _appended_only(old_sec, new_sec) -> bool:
    """불변 절의 「추가만 허용」 — 옛 줄 해시 목록이 새 목록의 앞부분과 같고 새 줄이 더 많을 때만 참.
    줄 해시가 없는 절(불변이 아닌 절 · 옛 원장)은 거짓 — 지금처럼 바뀜으로 본다."""
    o, n = old_sec.get("line_hashes"), new_sec.get("line_hashes")
    if not isinstance(o, list) or not isinstance(n, list):
        return False
    return len(n) > len(o) and n[:len(o)] == o
```

두 파서의 `allow_abbrev`: `docreview_state.py`

```python
def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="docreview_state.py", allow_abbrev=False)
    sp = p.add_subparsers(dest="cmd", required=True)

    def P(name):   # 하위 명령마다 줄인 플래그를 거부한다 — 줄인 플래그가 쓰기 플래그로 읽히지 않게(R2 인계)
        return sp.add_parser(name, allow_abbrev=False)
```

그리고 파일 안의 모든 `sp.add_parser(` 를 `P(` 로 바꾼다. `docreview_route.py` 도 같은 모양(`prog="docreview_route.py"`). `docreview_anchor.py` 의 파서도 같은 꼴로 바꾼다(같은 계열 · `check-intent` 가 쓰기 경로다).

- [ ] **Step 4: 통과와 골든 무변경을 본다**

Run: `bash shared/tests/test_docreview_state.sh 2>&1 | tail -3; bash shared/tests/test_docreview_golden.sh 2>&1 | tail -3; bash shared/tests/test_docreview_anchor.sh 2>&1 | tail -3`
Expected: 셋 다 Fail 0. 골든이 깨지면 원장 스냅숏에 `line_hashes` 가 불변 절이 아닌 곳에 실린 것이다(골든 케이스는 design-doc 프로필 · 불변 절 없음).

- [ ] **Step 5: 변이로 이빨을 본다**

`_appended_only` 의 `n[:len(o)] == o` 를 `True` 로 바꾸고(커밋 뒤 작업 트리에서) `case_AC14_append_only_plus_edit` 가 RED 인지, `allow_abbrev=False` 를 지우고 `case_AC14_no_abbrev_flags` 가 RED 인지 본다. `git checkout HEAD -- <파일>` 후 `git diff HEAD` 가 비었는지 확인한다.

- [ ] **Step 6: 커밋**

```bash
git add shared/tests/fixtures/docreview/brief-append-r1.md shared/tests/fixtures/docreview/brief-append-r2.md shared/tests/fixtures/docreview/brief-append-r2-edit.md
git commit -m "feat(docreview): 줄인 플래그 거부 · brief 원문 절은 덧붙이기만 허용" -- shared/docreview/scripts/docreview_state.py shared/docreview/scripts/docreview_route.py shared/docreview/scripts/docreview_anchor.py shared/tests/fixtures/docreview/cases.sh shared/tests/test_docreview_state.sh shared/tests/fixtures/docreview/brief-append-r1.md shared/tests/fixtures/docreview/brief-append-r2.md shared/tests/fixtures/docreview/brief-append-r2-edit.md
```

---

### Task 2: 엔진 값 — 재리뷰 상한 · 조언 줄 수 · 요약 폭 · 탐지 수를 라운드마다 풀고 공시 (AC12 · AC10 의 값 부분)

**Files:**
- Create: `shared/docreview/scripts/docreview_config.py` (값 해석 — leaf 모듈, 표준 라이브러리만)
- Modify: `shared/docreview/scripts/docreview_state.py` (`PROFILE_FIELDS`/`OPTIONAL_PROFILE_FIELDS` :42-48 · `load_profile` 의 `detectors` 검사 :144-145 · `cmd_begin_round` · `gate_summary` · `render_gate` 두째 줄 :1503 · `cmd_advice` :1589)
- Modify: `shared/docreview/scripts/docreview_advice.py` (`render_lines` · `clip` 이 폭을 인자로)
- Modify: `shared/docreview/references/reviewing-document.md` (`## 상한` :3-5)
- Modify: `plugins/spec-distill/tests/test_rereview_cap_consistency.sh` · `shared/tests/fixtures/docreview/cases_advice.sh` (`case_AC6_render_cap` · `case_advice_odd_text_one_line`) · `shared/tests/test_docreview_mutations.sh` (:277 · :844 · :846 의 변이 대상 줄) · `shared/tests/test_docreview_profiles.sh` (:203-206 — 탐지 2 거부를 0 거부로)
- Create: 심볼릭 링크 `plugins/spec-distill/scripts/docreview_config.py` · `plugins/quality-gates/scripts/docreview_config.py` → `../../../shared/docreview/scripts/docreview_config.py`
- Modify: `shared/tests/test_docreview_copy_set.sh` (링크 집합 기대값에 새 이름)
- Test: `shared/tests/fixtures/docreview/cases.sh` (새 케이스) · `shared/tests/test_docreview_state.sh`

**Interfaces:**
- Produces: `docreview_config.resolve(prof: dict, entry: dict, env: Mapping[str,str]) -> dict` — 키 `detectors` · `rereview_cap` · `render_cap` · `summary_width` 마다 `{"value": int, "source": "기본"|"프로필"|"진입"|"환경"}`. 잘못된 값이면 `ConfigInvalid(name, raw)` 를 던진다. 상수 `DEFAULTS = {"detectors": 1, "rereview_cap": 2, "render_cap": 8, "summary_width": 60}` · `ENV = {"detectors": "DEVBREW_DOCREVIEW_DETECTORS", "rereview_cap": "DEVBREW_DOCREVIEW_REREVIEW_CAP", "render_cap": "DEVBREW_DOCREVIEW_RENDER_CAP", "summary_width": "DEVBREW_DOCREVIEW_SUMMARY_WIDTH"}` · `MINIMUM = {"detectors": 1, "rereview_cap": 0, "render_cap": 1, "summary_width": 1}` · `config_line(cfg) -> str`(게이트 둘째 줄 꼬리).
- Produces: 원장 `rounds[n].config`(위 dict) · `begin-round` 출력 JSON 의 `config` 키 · `begin-round --detectors N`(진입 선언) · `gate` JSON 의 `config` 키.
- Consumes: Task 1 의 `P(name)` 파서 꼴.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`cases.sh` 에 더한다:

```bash
# ── AC12 · AC10 — 엔진 값: 기본 < 프로필 < 진입 < 환경, 라운드마다 공시 ─────────────
case_config_defaults_disclosed() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "config: r1 실패"; return; }
  assert_eq "$(st_yaml "$d" 'tuple((k, v["value"], v["source"]) for k, v in sorted(st["rounds"]["1"]["config"].items()))')" \
    "(('detectors', 1, '프로필'), ('render_cap', 8, '기본'), ('rereview_cap', 2, '기본'), ('summary_width', 60, '기본'))" \
    "config: 프로필 탐지 1 · 나머지 기본값과 출처가 라운드 1 에 적힌다"
  assert_contains "$(py docreview_state.py gate --state-dir "$d" --render | sed -n 2p)" "재리뷰 0/2회 썼다(상한 2 — 기본)" "config: 게이트 둘째 줄이 상한과 출처를 공시한다"
  assert_contains "$(py docreview_state.py gate --state-dir "$d" --render | sed -n 2p)" "탐지 리뷰어 1명(프로필)" "config: 탐지 수와 출처도 같은 줄에"
  rm -rf "$d"
}
case_config_env_wins() {
  local d s; d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "config: init 실패"; return; }
  s="$d/s1.json"; snap "$FX/design-sample.md" "$s"
  local out; out="$(DEVBREW_DOCREVIEW_DETECTORS=3 DEVBREW_DOCREVIEW_REREVIEW_CAP=0 py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" --detectors 2)"
  assert_eq "$(printf '%s' "$out" | jgets 'd["config"]["detectors"]["value"], d["config"]["detectors"]["source"], d["config"]["rereview_cap"]["value"]')" "(3, '환경', 0)" "config: 환경이 진입(--detectors 2)과 프로필을 이긴다"
  DEVBREW_DOCREVIEW_REREVIEW_CAP=0 py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" >/dev/null 2>&1; local rc=$?
  assert_eq "$rc" "3" "config: 상한 0 이면 라운드 2 는 승인 없이 rc 3"
  rm -rf "$d"
}
case_config_entry_beats_profile() {
  local d s; d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "config: init 실패"; return; }
  s="$d/s1.json"; snap "$FX/design-sample.md" "$s"
  assert_eq "$(env -u DEVBREW_DOCREVIEW_DETECTORS python3 "$SCRIPTS/docreview_state.py" begin-round --state-dir "$d" --snapshot "$s" --detectors 2 | jgets 'd["config"]["detectors"]["value"], d["config"]["detectors"]["source"]')" "(2, '진입')" "config: 진입 선언이 프로필(1)을 이긴다"
  rm -rf "$d"
}
case_config_invalid_refused() {
  local d s; d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "config: init 실패"; return; }
  s="$d/s1.json"; snap "$FX/design-sample.md" "$s"
  local err rc; err="$(DEVBREW_DOCREVIEW_DETECTORS=two py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc" "2" "config: 정수가 아닌 환경 값은 라운드를 시작하지 않는다(rc 2)"
  assert_contains "$err" '"reason": "config_invalid"' "config: 사유 이름"
  assert_contains "$err" "DEVBREW_DOCREVIEW_DETECTORS" "config: 변수 이름을 낸다"
  assert_eq "$(st_yaml "$d" 'st["round"]')" "0" "config: 거부는 원장을 바꾸지 않는다"
  DEVBREW_DOCREVIEW_RENDER_CAP=0 py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "config: 조언 줄 수 0 은 범위 밖"
  rm -rf "$d"
}
case_config_changes_between_rounds() {
  local d s; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "config: r1 실패"; return; }
  s="$d/s2.json"; snap "$FX/design-sample.md" "$s"
  DEVBREW_DOCREVIEW_DETECTORS=2 py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" >/dev/null
  assert_eq "$(st_yaml "$d" 'st["rounds"]["1"]["config"]["detectors"]["value"], st["rounds"]["2"]["config"]["detectors"]["value"], st["rounds"]["2"]["config"]["detectors"]["source"]')" "(1, 2, '환경')" "config: 라운드마다 따로 적히고 앞 라운드 기록은 그대로다"
  rm -rf "$d"
}
case_config_profile_fields() {
  local p; p="$(mktemp -d -t prof-XXXXXX)"
  python3 -I -c 'import sys; t=open(sys.argv[1],encoding="utf-8").read(); t=t.replace("detectors: 1\n","detectors: 2\nrereview_cap: 4\nrender_cap: 12\nsummary_width: 80\n",1); open(sys.argv[2],"w",encoding="utf-8").write(t)' "$PROF_SD/design-doc.md" "$p/design-doc.md"
  local d s; d="$(mk_state "$FX/design-sample.md" "$p/design-doc.md")" || { no "config: init 실패"; rm -rf "$p"; return; }
  s="$d/s1.json"; snap "$FX/design-sample.md" "$s"
  assert_eq "$(env -u DEVBREW_DOCREVIEW_DETECTORS -u DEVBREW_DOCREVIEW_REREVIEW_CAP -u DEVBREW_DOCREVIEW_RENDER_CAP -u DEVBREW_DOCREVIEW_SUMMARY_WIDTH python3 "$SCRIPTS/docreview_state.py" begin-round --state-dir "$d" --snapshot "$s" | jgets 'tuple((k, v["value"], v["source"]) for k, v in sorted(d["config"].items()))')" \
    "(('detectors', 2, '프로필'), ('render_cap', 12, '프로필'), ('rereview_cap', 4, '프로필'), ('summary_width', 80, '프로필'))" "config: 프로필 필드 넷이 먹는다"
  rm -rf "$d" "$p"
}
```

`cases_advice.sh` 의 `case_AC6_render_cap` 끝에 덧붙인다(같은 원장에서):

```bash
  local envout; envout="$(DEVBREW_DOCREVIEW_RENDER_CAP=3 py docreview_state.py advice --state-dir "$d" --render | wc -l | tr -d ' ')"
  assert_eq "$envout" "5" "AC6: 환경 변수 조언 줄 수 3 이면 머리 1 + 항목 3 + 접는 줄 1"
```

(`--cap` 을 넘기면 그 값이 이긴다 — 진입의 명시 값이다. `--cap` 이 없을 때 환경 > 프로필 > 기본.)

`case_advice_odd_text_one_line` 끝에: `DEVBREW_DOCREVIEW_SUMMARY_WIDTH=20` 일 때 항목 줄의 요약이 19자 + 「…」 인지 단언한다(같은 픽스처).

AC12 의 「접힌 조언 줄은 전문이 있는 곳을 적는다」는 지금 `render_lines` 의 접는 줄(`… 외 %d건 — %s 에 전부`)이 이미 한다 — 위 `DEVBREW_DOCREVIEW_RENDER_CAP=3` 단언 뒤에 `assert_contains` 로 마지막 줄에 「에 전부」와 박제처 이름이 있는지를 더해, 값을 바꿔도 그 줄이 남는지 잰다.

- [ ] **Step 2: 테스트가 실패하는지 본다**

Run: `bash shared/tests/test_docreview_state.sh 2>&1 | grep -E 'config|Total'; bash shared/tests/test_docreview_advice.sh 2>&1 | grep -E 'AC6|Total'`
Expected: config 케이스 전부 ✗(`config` 키 없음 · `--detectors` 모름 · 프로필 필드 `fields_unknown`).

- [ ] **Step 3: 값 모듈을 쓴다**

`shared/docreview/scripts/docreview_config.py`:

```python
"""docreview_config.py — 엔진 값(탐지 수 · 재리뷰 상한 · 조언 줄 수 · 요약 폭)을 한 곳에서 푼다 (leaf 모듈).

순서는 기본 < 프로필 < 진입 < 환경 — 뒤가 이긴다. 진입 선언은 탐지 수에만 있다(`begin-round --detectors`).
값이 정수가 아니거나 최솟값보다 작으면 `ConfigInvalid` — 부르는 쪽이 라운드를 시작하지 않는다.
표준 라이브러리만 쓴다. 파일 · 환경을 직접 읽지 않고 인자로 받는다(테스트가 주입한다).
"""
from __future__ import annotations

DEFAULTS = {"detectors": 1, "rereview_cap": 2, "render_cap": 8, "summary_width": 60}
ENV = {"detectors": "DEVBREW_DOCREVIEW_DETECTORS", "rereview_cap": "DEVBREW_DOCREVIEW_REREVIEW_CAP",
       "render_cap": "DEVBREW_DOCREVIEW_RENDER_CAP", "summary_width": "DEVBREW_DOCREVIEW_SUMMARY_WIDTH"}
MINIMUM = {"detectors": 1, "rereview_cap": 0, "render_cap": 1, "summary_width": 1}
PROFILE_KEYS = ("rereview_cap", "render_cap", "summary_width")   # `detectors` 는 필수 필드라 따로 있다


class ConfigInvalid(Exception):
    def __init__(self, name, raw, where):
        super().__init__("%s=%r" % (name, raw))
        self.name, self.raw, self.where = name, raw, where


def _int(name, raw, where):
    if isinstance(raw, bool):
        raise ConfigInvalid(name, raw, where)
    try:
        v = int(str(raw).strip(), 10)
    except (TypeError, ValueError):
        raise ConfigInvalid(name, raw, where)
    if v < MINIMUM[name]:
        raise ConfigInvalid(name, raw, where)
    return v


def resolve(prof, entry, env) -> dict:
    out = {}
    for k, dv in DEFAULTS.items():
        val, src = dv, "기본"
        if k in prof and prof[k] is not None:
            val, src = _int(k, prof[k], "프로필"), "프로필"
        if k in (entry or {}) and entry[k] is not None:
            val, src = _int(k, entry[k], "진입"), "진입"
        raw = env.get(ENV[k])
        if raw is not None and raw != "":
            val, src = _int(k, raw, "환경 " + ENV[k]), "환경"
        out[k] = {"value": val, "source": src}
    return out


def config_line(cfg) -> str:
    """게이트 둘째 줄의 꼬리 — 탐지 수와 그 출처. 재리뷰 상한은 앞 마디가 직접 낸다."""
    d = cfg.get("detectors") or {"value": DEFAULTS["detectors"], "source": "기본"}
    return "탐지 리뷰어 %d명(%s)" % (d["value"], d["source"])
```

(오류 출력은 `where` 로 출처와 변수 이름을 낸다 — 환경이면 `환경 DEVBREW_DOCREVIEW_DETECTORS`.)

- [ ] **Step 4: 엔진에 꽂는다**

`docreview_state.py`:
- 맨 위 import 블록에 `import docreview_config as _cfg`(형제 · leaf — `docreview_advice` 처럼 `try` 로 감싸지 않는다: 값 해석은 모든 라운드의 필수 경로다).
- `OPTIONAL_PROFILE_FIELDS = ("must_catch", "rereview_cap", "render_cap", "summary_width")`.
- `load_profile` 의 `if data["detectors"] != 1:` 를 다음으로 바꾼다:

```python
    try:
        for k in ("detectors",) + _cfg.PROFILE_KEYS:
            if k in data:
                _cfg._int(k, data[k], "프로필")
    except _cfg.ConfigInvalid as e:
        raise ProfileError("config_invalid:%s=%r" % (e.name, e.raw))
```

- `REREVIEW_CAP = 2` 상수는 남긴다(기본값의 정본은 `_cfg.DEFAULTS` 이고 이 줄은 `REREVIEW_CAP = _cfg.DEFAULTS["rereview_cap"]` 로 바꾼다 — `test_rereview_cap_consistency.sh` 의 엔진 줄 대조는 Step 6 에서 새 정본을 읽게 고친다).
- `cmd_begin_round` 머리:

```python
def cmd_begin_round(a) -> int:
    st = load_state(a.state_dir)
    prof = load_profile(st["profile"])
    try:
        cfg = _cfg.resolve(prof, {"detectors": a.detectors}, os.environ)
    except _cfg.ConfigInvalid as e:
        fail("config_invalid", name=e.name, value=str(e.raw), where=e.where)
        return 2
    cap = cfg["rereview_cap"]["value"]
    snap = json.loads(Path(a.snapshot).read_text(encoding="utf-8"))
    n = int(st["round"]) + 1
    if n <= 1 + cap:
        rr = n - 1
    else:
        ...  # 지금 코드에서 REREVIEW_CAP → cap
```

  라운드 레코드에 `st["rounds"][str(n)]["config"] = cfg` 를 넣고(`setdefault` 뒤), 출력 `_emit` 에 `"config": cfg` 를 더한다. 파서: `x = P("begin-round"); …; x.add_argument("--detectors", type=int, default=None)`.
- `gate_summary`: `cfg = (st["rounds"].get(str(n)) or {}).get("config") or {}` · `cap = (cfg.get("rereview_cap") or {}).get("value", REREVIEW_CAP)` · `"cap_reached": rr >= cap` · `g["config"] = cfg`. (config 가 없는 옛 원장은 기본값으로 읽는다 — 원장은 세션을 넘어 남는다.)
- `render_gate` 둘째 줄:

```python
    cfg = g.get("config") or {}
    capv = cfg.get("rereview_cap") or {"value": REREVIEW_CAP, "source": "기본"}
    sub = "재리뷰 %d/%d회 썼다(상한 %d — %s) · %s" % (g["rereview_count"], capv["value"], capv["value"],
                                                   capv["source"], _cfg.config_line(cfg))
```

- `cmd_advice`: `--cap` 이 없으면 `cfg = _cfg.resolve(prof, {}, os.environ)` 의 `render_cap` 값을, 요약 폭은 `summary_width` 값을 `adv.render_lines(shown, cap, where, width)` 에 넘긴다. 잘못된 환경 값이면 rc 2 `config_invalid`.

`docreview_advice.py`: `clip(text, width=SUMMARY_WIDTH)` · `render_lines(items, cap, where, width=SUMMARY_WIDTH)` 로 폭을 인자로 받는다(기본값은 지금 상수 — 상수 두 줄 `RENDER_CAP = 8 ` · `SUMMARY_WIDTH = 60 ` 은 모양 그대로 남긴다: 변이 락 :844 · :846 이 그 줄을 겨눈다).

- [ ] **Step 5: 링크 · 복사 집합**

```bash
ln -s ../../../shared/docreview/scripts/docreview_config.py plugins/spec-distill/scripts/docreview_config.py
ln -s ../../../shared/docreview/scripts/docreview_config.py plugins/quality-gates/scripts/docreview_config.py
git ls-files -s plugins/spec-distill/scripts/docreview_config.py   # 커밋 뒤 모드 120000
```

`test_docreview_copy_set.sh` 가 링크 집합을 열거하면 기대값에 `docreview_config.py` 를 더한다(파일을 열어 실제 열거 자리를 확인하고 고친다).

- [ ] **Step 6: 값을 잠근 락을 「기본값 + 덮어쓰기가 먹는다」로 고친다**

- `test_rereview_cap_consistency.sh`: 엔진 대조 줄을 `^REREVIEW_CAP = ${CAP}$` 대신 `"rereview_cap": ${CAP}` 가 `shared/docreview/scripts/docreview_config.py` 의 `DEFAULTS` 줄에 있는지로 바꾼다. 산문 정본(`reviewing-document.md` `## 상한`)의 `` `rereview_cap: 2` `` 줄은 남기고 그 뒤에 「기본값이다 — 프로필 필드 `rereview_cap` 과 환경 변수 `DEVBREW_DOCREVIEW_REREVIEW_CAP` 로 바꿀 수 있고(환경이 이긴다) 쓰인 값과 출처는 게이트 둘째 줄이 낸다.」를 더한다.
- `test_docreview_mutations.sh:277` 의 변이(`REREVIEW_CAP = 2` → 3)를 `docreview_config.py` 의 `"rereview_cap": 2` → `3` 으로 옮긴다(대상 케이스 `case_T37_cap_and_extra` 는 그대로).
- `test_docreview_profiles.sh:203-206`: 「detectors 2 → rc 2」를 「detectors 0 → rc 2(`config_invalid`)」와 「detectors 2 → rc 0」 짝으로 바꾼다.

- [ ] **Step 7: 통과 · 골든 갱신**

Run: `bash shared/tests/test_docreview_state.sh 2>&1 | tail -2; bash shared/tests/test_docreview_advice.sh 2>&1 | tail -2; bash plugins/spec-distill/tests/test_rereview_cap_consistency.sh 2>&1 | tail -2; bash shared/tests/test_docreview_profiles.sh 2>&1 | tail -2`
Expected: Fail 0.
골든: `bash shared/tests/fixtures/docreview/capture_finalize_golden.sh` 후 `git diff --stat shared/tests/fixtures/docreview/golden` — `gate.txt` 다섯의 둘째 줄과 `gate.json` · `state.md` 의 `config` 키만 바뀌어야 한다. 그 밖의 줄이 바뀌면 멈추고 원인을 찾는다.

- [ ] **Step 8: 커밋**

```bash
git add shared/docreview/scripts/docreview_config.py plugins/spec-distill/scripts/docreview_config.py plugins/quality-gates/scripts/docreview_config.py
git commit -m "feat(docreview): 엔진 값을 기본·프로필·진입·환경으로 풀고 라운드마다 공시" -- shared/docreview/scripts/docreview_config.py plugins/spec-distill/scripts/docreview_config.py plugins/quality-gates/scripts/docreview_config.py shared/docreview/scripts/docreview_state.py shared/docreview/scripts/docreview_advice.py shared/docreview/references/reviewing-document.md plugins/spec-distill/tests/test_rereview_cap_consistency.sh shared/tests/fixtures/docreview/cases.sh shared/tests/fixtures/docreview/cases_advice.sh shared/tests/test_docreview_mutations.sh shared/tests/test_docreview_profiles.sh shared/tests/test_docreview_copy_set.sh shared/tests/test_docreview_state.sh shared/tests/fixtures/docreview/golden
```

---

### Task 3: 여러 탐지 리뷰어 — 라우터 합침 · 부분 사망 공시 · 진입 dispatch (AC10 · AC11)

**Files:**
- Modify: `shared/docreview/scripts/docreview_route.py` (`cmd_prepare` :208-309 · `build_parser` · `_build_report` :805-866)
- Modify: `shared/docreview/scripts/docreview_state.py` (`WARN_GLOSS` :1295-1310 · `PUBLIC_FIELDS` 에 `detector`)
- Modify: `shared/docreview/references/reviewing-document.md` (3단계 · 5단계)
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md` (:469-481 탐지 dispatch · :442-467 비움 펜스) · `plugins/spec-distill/skills/reviewing-brief/SKILL.md` (:499-527) · `plugins/spec-distill/skills/request-framing/SKILL.md` (:412 · :613-622 · :505 · :540)
- Create: `shared/tests/fixtures/docreview/critic-d2.txt` (둘째 리뷰어 출력 — `c1` 을 다시 쓰고 자기 `c1` 을 막는 ask 하나)
- Test: `shared/tests/fixtures/docreview/cases.sh` · `shared/tests/test_docreview_route.sh` · `plugins/spec-distill/tests/test_reviewing_brief_skill.sh` (:180-183 dispatch 개수)

**Interfaces:**
- Consumes: Task 2 의 `rounds[n].config.detectors.value`.
- Produces: `prepare-recritic --critic <파일>` 을 여러 번 받는다(`action="append"`). `degrade["detectors"] = {"expected": N, "dead": [i…], "dead_reasons": {i: 사유}}`. 지적 공개 필드 `detector`(`"d1"`…). 라우팅 보고 advisory 원문 `탐지 N 중 k 사망 (d<i>: 사유 …)`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`critic-d2.txt`(둘째 리뷰어 — 첫째 픽스처 `critic-r1.txt` 와 다른 자리 지적 하나 + 자기 `c1` 을 막는 ask):

````text
```docreview-layer1
[]
```
```docreview-layer2
- ref: c1
  layer: 2
  category: placeholder
  anchor: "#handoff-context"
  disposition: fix
  summary: "넘김 절에 이어 갈 사람이 볼 경로가 없다"
  edit_scope: "#handoff-context"
- ref: c2
  layer: 2
  category: ambiguity
  anchor: "#handoff-context"
  disposition: ask
  summary: "넘김 절의 경로를 어디로 둘지 정해야 한다"
  blocks: [c1]
```
````

`cases.sh`:

```bash
# ── AC10 · AC11 — 탐지 리뷰어 여럿 ───────────────────────────────────────
r1_detectors() {   # r1_detectors <N> <profile> <doc> → round 1 begun with N detectors (환경으로)
  local d s; d="$(mk_state "$3" "$2")" || return 1; s="$d/s1.json"; snap "$3" "$s"
  DEVBREW_DOCREVIEW_DETECTORS="$1" py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" >/dev/null; echo "$d"
}
case_detectors_merge_and_source() {
  local d; d="$(r1_detectors 2 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC10: r1 실패"; return; }
  local c1 c2; c1="$(critic_now "$d" "$FX/critic-r1.txt")"; cp "$FX/critic-d2.txt" "$d/critic-2.txt"; c2="$d/critic-2.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$c1" --critic "$c2" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'any("detector" in i for i in d["items"])')" "False" "AC10: 재비판 입력에는 출처 리뷰어가 없다(익명화)"
  assert_eq "$(st_yaml "$d" 'sorted({p["finding"].get("detector") for p in st["pending_recritic"]["items"] if p["source"]=="critic"})')" "['d1', 'd2']" "AC10: 원장 준비에는 리뷰어마다 출처가 있다"
  assert_eq "$(st_yaml "$d" '[p["finding"]["blocks"] for p in st["pending_recritic"]["items"] if p["finding"]["summary"].startswith("넘김 절의 경로")][0] == [[p["f"] for p in st["pending_recritic"]["items"] if p["finding"]["summary"].startswith("넘김 절에 이어")][0]]')" "True" "AC10: 둘째 리뷰어의 질문은 자기 c1 을 막는다(번호 충돌 없음)"
  rm -rf "$d"
}
case_detectors_partial_death() {
  local d; d="$(r1_detectors 3 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC11: r1 실패"; return; }
  local c1 c2; c1="$(critic_now "$d" "$FX/critic-r1.txt")"; cp "$FX/critic-d2.txt" "$d/critic-2.txt"; c2="$d/critic-2.txt"
  cp "$FX/critic-broken.txt" "$d/critic-3.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$c1" --critic "$c2" --critic "$d/critic-3.txt" > "$d/prep.json"; local rc=$?
  assert_eq "$rc" "0" "AC11: 일부 사망은 라운드를 죽이지 않는다(rc 0)"
  assert_eq "$(jget "$d/prep.json" 'd["degrade"]["detectors"]["expected"], d["degrade"]["detectors"]["dead"], d["degrade"]["critic_dead"]')" "(3, [3], False)" "AC11: 탐지 3 중 셋째 사망 · 주 판정자 사망 아님"
  py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_contains "$(jget "$d/fin.json" '" | ".join(d["advisory"])')" "탐지 3 중 1 사망" "AC11: 라우팅 보고가 degrade 로 공시한다"
  assert_contains "$(py docreview_state.py gate --state-dir "$d" --render | head -1)" "탐지 리뷰어 3명 중 1명이 결과를 내지 못했다" "AC11: 게이트 첫 줄 경고가 쉬운 말로 말한다"
  rm -rf "$d"
}
case_detectors_all_dead() {
  local d; d="$(r1_detectors 2 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC11: r1 실패"; return; }
  cp "$FX/critic-broken.txt" "$d/critic-1.txt"; cp "$FX/critic-broken.txt" "$d/critic-2.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$d/critic-1.txt" --critic "$d/critic-2.txt" > "$d/prep.json"; local rc=$?
  assert_eq "$rc" "4" "AC11: 전부 죽으면 지금처럼 critic 사망 rc 4"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["unverified"]')" "critic_dead" "AC11: 게이트는 「미검증」"
  rm -rf "$d"
}
case_detectors_count_mismatch() {
  local d; d="$(r1_detectors 2 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC10: r1 실패"; return; }
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'd["degrade"]["detectors"]["expected"], d["degrade"]["detectors"]["dead"]')" "(2, [2])" "AC10: 기대 2 인데 파일 1 이면 빠진 둘째를 사망으로 센다(조용히 1 로 줄이지 않는다)"
  rm -rf "$d"
}
case_detectors_stale_file_per_file() {
  local d; d="$(r1_detectors 2 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC10: r1 실패"; return; }
  cp "$FX/critic-d2.txt" "$d/critic-2.txt"; touch -t 200001010000 "$d/critic-2.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --critic "$d/critic-2.txt" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'd["degrade"]["detectors"]["dead_reasons"].get("2")')" "critic_predates_round" "AC10: 신선도는 파일마다 — 라운드 시작보다 오래된 둘째만 사망"
  rm -rf "$d"
}
```

`test_docreview_route.sh` 에 다섯을 등록한다.

- [ ] **Step 2: 실패를 본다**

Run: `bash shared/tests/test_docreview_route.sh 2>&1 | grep -E 'AC10|AC11|Total'`
Expected: ✗(`--critic` 둘째가 첫째를 덮음 · `detectors` 키 없음).

- [ ] **Step 3: 라우터를 고친다**

`build_parser`: `x.add_argument("--critic", required=True, action="append")`.

`cmd_prepare` 의 critic 읽기 부분을 리뷰어마다 도는 함수로 뺀다:

```python
def _read_one_critic(st, path, i, ev, rec, prof):
    """리뷰어 i 의 출력 — (항목 [(src, it)], 사망 사유 또는 None, layer2_missing, merged 개수 dict)."""
    critic = Path(path)
    why, text, l2_missing, merged = None, "", False, {}
    if not critic.is_file():
        return [], "missing", False, merged
    stale = _round_staleness(st, critic, "critic_predates_round")
    if stale == "critic_predates_round":
        return [], stale, False, merged
    try:
        text = critic.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return [], "undecodable", False, merged
    items = []
    l1s, e1 = extract_blocks(text, "docreview-layer1")
    l1, e1m = (merge_list_blocks(l1s, "docreview-layer1", ev) if l1s is not None else (None, None))
    why = e1 or e1m
    if l1s is not None and len(l1s) > 1:
        merged["docreview-layer1"] = len(l1s)
    if why or not isinstance(l1, list):
        return [], why or "not a list", False, merged
    tag = "" if i == 1 else "@d%d" % i
    for k, it in enumerate(l1, 1):
        n1 = normalize(it, 1, "c", k, rec)
        if n1:
            items.append(n1)
    l2s, e2 = extract_blocks(text, "docreview-layer2")
    l2, e2m = (merge_list_blocks(l2s, "docreview-layer2", ev) if l2s is not None else (None, None))
    e2 = e2 or e2m
    if l2s is not None and len(l2s) > 1:
        merged["docreview-layer2"] = len(l2s)
    if e2 == "broken":
        return [], "layer2 block broken", False, merged
    if e2 or not isinstance(l2, list):
        l2_missing = bool(prof["layer_rubric"].get("layer2"))
    else:
        for k, it in enumerate(l2, 1):
            n2 = normalize(it, 2, "c", 100 + k, rec)
            if n2:
                items.append(n2)
    for it in items:
        it["detector"] = "d%d" % i
        if tag:   # 리뷰어 i ≥ 2 의 임시 번호와 자기 blocks 를 바꾼다 — 질문은 자기 리뷰어의 항목을 막는다
            it["ref"] = it["ref"] + tag
            it["blocks"] = [r + tag for r in it["blocks"]]
    return [("critic", it) for it in items], None, l2_missing, merged
```

`cmd_prepare` 본문에서 단일 critic 처리를 이것으로 바꾼다:

```python
    expected = int(((st["rounds"].get(str(st["round"])) or {}).get("config") or {})
                   .get("detectors", {}).get("value", 1))
    paths = list(a.critic or [])
    dead, dead_reasons, freshness = [], {}, None
    for i in range(1, max(expected, len(paths)) + 1):
        path = paths[i - 1] if i <= len(paths) else None
        if path is None:
            got, why, l2m, merged = [], "missing", False, {}
        else:
            if freshness is None:
                fs = _round_staleness(st, Path(path), "critic_predates_round") if Path(path).is_file() else None
                if fs in ("round_start_unrecorded", "round_start_unreadable"):
                    freshness = fs
            got, why, l2m, merged = _read_one_critic(st, path, i, ev, rec, prof)
        if why:
            dead.append(i)
            dead_reasons[str(i)] = why
            ev("source_failed", "doc-critic#%d" % i, "detector %d %s" % (i, why), False)
            continue
        items.extend(got)
        if l2m:
            degrade["layer2_missing"] = True
            ev("uncountable", "layer2", "detector %d block missing" % i)
        for k, v in merged.items():
            degrade.setdefault("blocks_merged", {})[k] = degrade.get("blocks_merged", {}).get(k, 0) + v
    if freshness:
        degrade["critic_freshness_unknown"] = freshness
    n_total = max(expected, len(paths))
    if n_total > 1:
        degrade["detectors"] = {"expected": n_total, "dead": dead, "dead_reasons": dead_reasons}
    if len(dead) == n_total:
        degrade["critic_dead"] = True
        ev("source_failed", "doc-critic", "all detectors dead (%s)" % ",".join(sorted(set(dead_reasons.values()))), True)
```

익명화 직전 `pub` 만들 때 `pub.pop("detector", None)` 을 더한다(원장 `pending_recritic.items[].finding` 에는 남겨야 하므로 **`pending` 의 `finding` 에는 원본 `it` 의 detector 를 따로 싣는다**: `pending.append({"f": pub["f"], "source": src, "detector": it.get("detector"), "finding": dict(pub, detector=it.get("detector"))})` 그리고 stdout `items` 는 `detector` 를 뺀 사본으로 낸다).

`_build_report` 에 공시 원문을 더한다(`blocks_merged` 줄 앞):

```python
    det = degrade.get("detectors")
    if det and det.get("dead") and not degrade.get("critic_dead"):
        adv.append("탐지 %d 중 %d 사망 (%s)" % (det["expected"], len(det["dead"]),
                   ", ".join("d%s: %s" % (k, v) for k, v in sorted(det["dead_reasons"].items()))))
```

`docreview_state.py` 의 `WARN_GLOSS` 에 행 하나(위쪽, `입력 실패(주)` 앞):

```python
    (r"탐지 (?P<n>\d+) 중 (?P<k>\d+) 사망 \((?P<why>.*)\)", "탐지", "탐지 리뷰어 일부가 결과를 내지 못했다 — 남은 리뷰어 결과로 갔다"),
```

그리고 `_plain_warns` 가 이 행에서 「탐지 리뷰어 N명 중 k명이 결과를 내지 못했다」로 숫자를 싣도록, 이 행만 `row[2] % ...` 대신 `"탐지 리뷰어 %s명 중 %s명이 결과를 내지 못했다 — 남은 리뷰어 결과로 갔다" % (m.group("n"), m.group("k"))` 로 만든다(괄호 이름 `탐지` · 사유는 괄호 안). `PUBLIC_FIELDS` 끝에 `"detector"` 를 더한다(골든의 `state.md` 에 `detector: d1` 줄이 생긴다 — Step 6).

- [ ] **Step 4: 진입 skill 셋의 dispatch 를 N 으로**

`reviewing-document.md` 3단계 첫 문장을 다음으로 바꾼다: 「**탐지** — 1단계 `begin-round` 출력의 `config.detectors.value`(N)만큼 진입 skill 이 고른 탐지 리뷰어를 dispatch 한다. 리뷰어 i 의 출력은 문서별 상태 디렉토리의 `critic-<i>.txt`(i = 1…N, N = 1 이면 `critic.txt` 도 받는다) verbatim 파일로 저장한다. N 과 그 출처는 게이트 둘째 줄이 공시한다.」 5단계 명령을 `prepare-recritic --state-dir D --critic critic-1.txt [--critic critic-2.txt …] --codex codex.yaml` 로, 사망 문장에 「일부만 죽으면 그 리뷰어만 재dispatch 1회, 또 실패면 「탐지 N 중 k 사망」으로 공시하고 남은 결과로 간다 — 전부 죽어야 「미검증」이다」를 더한다.

spec-review SKILL.md `3단계 탐지` 문단(:469-470)을 「1단계 출력의 `config.detectors.value` 만큼 아래 블록을 dispatch 한다(한 메시지에 여러 Agent 호출 — 병렬). 리뷰어 i 의 출력을 `$STATE_DIR/critic-<i>.txt` 로 저장한다. 규모(N명)는 게이트 둘째 줄이 공시한다 — 선언된 fan-out 이다.」로 바꾸고, 프로필 펜스의 비움 대상(:454-457)을 `critic-*.txt` 전부로(`for f in "$STATE_DIR"/critic.txt "$STATE_DIR"/critic-[0-9]*.txt; do [ -e "$f" ] && : > "$f"; done` — glob 은 상태 디렉토리 안의 자기 이름 꼴에만). reviewing-brief(:499-527) · request-framing(:412 · :505 · :540 · :613-622)도 같은 문면으로 고친다. `test_reviewing_brief_skill.sh:180-183` 의 「dispatch 블록 정확히 하나」는 블록 수 그대로(블록은 하나 · 호출이 N)라 바뀌지 않는다 — 돌려서 확인한다.

- [ ] **Step 5: 통과를 본다**

Run: `bash shared/tests/test_docreview_route.sh 2>&1 | tail -3; for t in plugins/spec-distill/tests/test_reviewing_brief_skill.sh plugins/spec-distill/tests/test_framing_review_contract.sh plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh shared/tests/test_dispatch_disposition.sh shared/tests/test_agent_input_slots.sh; do bash "$t" 2>&1 | tail -1; done`
Expected: 모두 Fail 0.

- [ ] **Step 6: 골든 갱신 · 커밋**

`capture_finalize_golden.sh` 후 diff 가 `state.md` 의 `detector: d1` 줄(지적마다)과 `pending_recritic` 의 `detector` 키뿐인지 본다.

```bash
git add shared/tests/fixtures/docreview/critic-d2.txt
git commit -m "feat(docreview): 탐지 리뷰어 여럿을 합치고 일부 사망을 공시" -- shared/docreview/scripts/docreview_route.py shared/docreview/scripts/docreview_state.py shared/docreview/references/reviewing-document.md plugins/spec-distill/skills/spec-review/SKILL.md plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/skills/request-framing/SKILL.md shared/tests/fixtures/docreview/critic-d2.txt shared/tests/fixtures/docreview/cases.sh shared/tests/test_docreview_route.sh shared/tests/fixtures/docreview/golden
```

---

### Task 4: 게이트 글 — 열린 지적 수 · 승인 선택지 · 추가 라운드 승인 · 괄호 밖 내부 기호 (AC13 · AC40 · AC41 의 엔진 · 규칙 부분)

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py` (`cmd_begin_round` 의 extra 분기 · `_first_line` :1349-1378 · `render_gate` :1544-1558 · `_rg_blocking_ask` :1470 · `_rg_superseded` :1425 · 파서)
- Modify: `shared/docreview/references/reviewing-document.md` (8단계 :27-43)
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md` (`## 게이트` :514-522) · `plugins/spec-distill/skills/reviewing-brief/SKILL.md` (:571-576) · `plugins/spec-distill/skills/request-framing/SKILL.md` (:414-417 · :690-703)
- Modify: `shared/tests/test_docreview_round_gate_split.sh` (새 문구 축) · `plugins/spec-distill/tests/test_framing_review_contract.sh:90` (`--extra-approval="$q"` 뒤 출처 플래그)
- Create: `shared/tests/test_docreview_gate_plain.sh` (100755)
- Test: `shared/tests/fixtures/docreview/cases.sh` (`case_T37_cap_and_extra` · `case_cap_zero_open_two_stage` 갱신 · 새 케이스)

**Interfaces:**
- Produces: `begin-round --extra-approval <값> --extra-approval-source label|typed`. 원장 `extra_rounds[]` 항목 `{"round", "quote", "source"}`. `gate` JSON `open_total`(열린 지적 수 — `GATE_ROWS` 의 `blocks` 행 항목 수 합). 렌더 상수 `APPROVE_WITH_OPEN = "열린 지적 %d개를 두고 진행"`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`cases.sh` 의 `case_T37_cap_and_extra` 에서 `--extra-approval '사용자: 한 라운드 더'` 를 `--extra-approval '추가 라운드 1회 열기' --extra-approval-source label` 로 바꾸고, 기대값을 `(1, 4, 2)` → 원장 식을 `len(st["extra_rounds"]), st["extra_rounds"][0]["round"], st["rereview_count"], st["extra_rounds"][0]["source"]` 로, 기대를 `(1, 4, 2, 'label')` 로 바꾼다. 새 케이스:

```bash
case_AC40_extra_source_required() {
  local d s; d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC40: init 실패"; return; }
  s="$d/s.json"; snap "$FX/design-sample.md" "$s"
  local i; for i in 1 2 3; do py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" >/dev/null; done
  py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" --extra-approval '한 번 더 봐 줘' >/dev/null 2>&1; local rc=$?
  assert_eq "$rc" "2" "AC40: 출처 없이 승인 값만 오면 rc 2"
  py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" --extra-approval-source typed >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "AC40: 출처만 오면 rc 2"
  py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" --extra-approval '한 번 더 봐 줘' --extra-approval-source typed >/dev/null
  assert_eq "$(st_yaml "$d" 'st["extra_rounds"][-1]["quote"], st["extra_rounds"][-1]["source"]')" "('한 번 더 봐 줘', 'typed')" "AC40: 기타 칸 원문은 typed 로 적힌다"
  rm -rf "$d"
}
case_AC13_open_count_and_label() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC,$F_FIX]"
  local s="$d/s.json"; snap "$FX/design-sample.md" "$s"
  py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" >/dev/null; py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" >/dev/null
  local g; g="$(py docreview_state.py gate --state-dir "$d")"
  assert_eq "$(printf '%s' "$g" | jgets 'd["cap_reached"], d["open_total"]')" "(True, 2)" "AC13: 상한에서 열린 지적 수를 센다"
  local r; r="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_contains "$(printf '%s\n' "$r" | head -1)" "열린 지적 2개" "AC13: 게이트 첫 줄에 열린 지적 수"
  assert_contains "$r" "「열린 지적 2개를 두고 진행」" "AC13: 승인 선택지 이름에 열린 지적 수"
  assert_not_contains "$r" "사용자가 직접 쓴 말로" "AC40: 옛 문구가 없다"
  rm -rf "$d"
}
```

`shared/tests/test_docreview_gate_plain.sh`(100755) — AC41 의 엔진 렌더 축:

```bash
#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_state.py shared/docreview/references/reviewing-document.md
# AC41 — 기호 없는 요약을 가진 픽스처로 돌린 게이트 렌더의 모든 줄에 괄호 밖 내부 기호(지적 id · AC 번호 · §)가 없다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/docreview_state.py"; echo "shared/docreview/references/reviewing-document.md"; exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPTS="${SCRIPTS:-$REPO_ROOT/plugins/spec-distill/scripts}"
. "$HERE/fixtures/docreview/cases.sh"

# 괄호 밖 글자만 남긴다 — 짝이 맞는 ( … ) 와 「…」 안은 지운다(선택지 이름 인용은 사람 말이다).
outside_parens() { python3 -I -c '
import re, sys
for line in sys.stdin.read().split("\n"):
    prev = None
    while prev != line:
        prev = line
        line = re.sub(r"\([^()]*\)", "", line)
    print(line)
'; }
SYM_RE='[0-9a-f]{8}#r[0-9]+\.[0-9]+|(^|[^A-Za-z])AC[0-9]+|§'

render_all_rows() {   # 모든 렌더러 행이 한 번씩 서는 원장을 만든다(정할 것 · 막힌 질문 · 미적용 fix · 만료 · 상한)
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || return 1
  seed_findings "$d" "[$F_DEC,$F_FIX,$F_ASK]"
  local s="$d/s.json"; snap "$FX/design-sample.md" "$s"
  py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" >/dev/null
  py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" >/dev/null
  echo "$d"
}
d="$(render_all_rows)" || { no "AC41: 원장을 만들지 못했다"; finish; }
out="$(py docreview_state.py gate --state-dir "$d" --render)"
leak="$(printf '%s\n' "$out" | outside_parens | grep -nE "$SYM_RE" || true)"
assert_eq "$leak" "" "AC41: 게이트 렌더의 괄호 밖에 지적 id · AC 번호 · § 가 없다"
# 양성 대조 — 렌더 안에 지적 id 가 «있기는» 하다(괄호 안). 없으면 이 락은 공허하다.
assert_contains "$out" "aaaa0001#r1.1" "AC41 양성 짝: 지적 id 는 괄호 안에 있다"
# 계측기 양성 대조 — 괄호 밖 id 한 줄을 넣으면 잡는다.
probe="$(printf '%s\n' "- 이 답을 기다리는 수정: bbbb0001#r1.1" | outside_parens | grep -cE "$SYM_RE")"
assert_eq "$probe" "1" "AC41 계측기: 괄호 밖 id 는 잡힌다"
rm -rf "$d"

REF="$REPO_ROOT/shared/docreview/references/reviewing-document.md"
body="$(grep -vE '^#' "$REF")"
assert_contains "$body" "질문 · 선택지 이름에 AC 번호 · 지적 id · § 를 쓰지 않고 설명 괄호에만 쓴다" "AC41: 게이트 절 규칙 문장이 절차서 본문에 있다"
assert_contains "$body" "--extra-approval-source" "AC40: 절차서가 출처 플래그를 가르친다"
assert_not_contains "$body" "사용자 자신의 문구" "AC40: 옛 승인 문면이 절차서에 없다"
finish
```

- [ ] **Step 2: 실패를 본다**

Run: `chmod +x shared/tests/test_docreview_gate_plain.sh; bash shared/tests/test_docreview_gate_plain.sh 2>&1 | tail -8; bash shared/tests/test_docreview_state.sh 2>&1 | grep -E 'AC13|AC40|T37|Total'`
Expected: ✗ — 괄호 밖 `bbbb0001#r1.1`(막힌 질문 줄) · `open_total` 없음 · 출처 플래그 모름 · 규칙 문장 없음.

- [ ] **Step 3: 엔진을 고친다**

파서: `x.add_argument("--extra-approval-source", default=None, choices=("label", "typed"))`, `FREE_TEXT_ARGS` 는 그대로(값 자체가 `extra_approval` 이다). `cmd_begin_round` 의 상한 위 분기:

```python
        if bool(a.extra_approval) != bool(a.extra_approval_source):
            fail("extra_approval_source_missing" if a.extra_approval else "extra_approval_missing")
            return 2
        if not a.extra_approval:
            _emit({"ok": False, "reason": "cap_reached", "round": n - 1, "rereview_count": st["rereview_count"]})
            return 3
        rr = cap
        st["extra_rounds"].append({"round": n, "quote": a.extra_approval, "source": a.extra_approval_source})
```

(출처 짝 검사는 상한 아래 라운드에서도 한다 — 이 두 줄을 `if n <= 1 + cap:` 분기 **앞**으로 올린다. 상한 아래에서 승인 값을 넘기는 것은 지금처럼 무시하되 그 라운드 로그에 「추가 승인 값이 왔지만 상한 아래라 쓰지 않았다」를 남긴다.)

`gate_summary` 에 `g["open_total"] = sum(len(g[row.name]) for row in GATE_ROWS if row.blocks)`.

`_first_line`: `left` 를 만든 뒤 `if g.get("cap_reached") or g.get("stagnation"): head += " — 열린 지적 %d개" % g["open_total"]` 를 문장 머리 바로 뒤에 넣는다(형식: 「리뷰 3라운드를 마쳤다 — 열린 지적 2개 — 정할 것 1개 · 아직 안 고친 곳 1개가 남았다. 경고 없음.」).

`render_gate` 의 「다음:」 갈래 두 줄:

```python
APPROVE_WITH_OPEN = "열린 지적 %d개를 두고 진행"
...
    if g["two_stage"] and g["next_round_mode"] == "extra_approval":
        if g["approval_ready"]:
            out.append("다음: " + ag + " 1단계 — 「추가 라운드 1회 열기」(고른 선택지나 기타 칸에 쓴 말이 승인으로 남는다) 또는 「진행 옵션으로」")
        else:
            out.append("다음: " + ag + " 1단계 — 남은 항목을 처리하거나 「%s」, 또는 「추가 라운드 1회 열기」(고른 선택지나 기타 칸에 쓴 말이 승인으로 남는다)" % (APPROVE_WITH_OPEN % g["open_total"]))
    ...
    elif g["two_stage"]:
        out.append("다음: " + ag + " 1단계 — 남은 항목을 처리하거나 「%s」 (다음 라운드: %s)" % (APPROVE_WITH_OPEN % g["open_total"], mode))
```

괄호 밖 지적 id 두 자리(설계에 없던 결정 9):

```python
def _rg_superseded(st, g, fid):
    d = st["decides"].get(fid) or {}
    return ["- %s — 다른 결정이 이어받았다 (%s · 이어받은 것 %s)" % (_one(st["findings"][fid].get("summary")), fid, d.get("superseded_by"))]


def _rg_blocking_ask(st, g, fid):
    f = st["findings"][fid]
    bl = f.get("blocks") or []
    return ["- %s — 이 답을 기다리는 수정 %d개 (%s · 기다리는 것 %s)" % (_one(f.get("summary")), len(bl), fid, ", ".join(bl))]
```

- [ ] **Step 4: 절차서 · skill 셋의 문면**

`reviewing-document.md` 8단계: 「`begin-round --extra-approval "<사용자 자신의 문구>"` 로 돈다(그 문구가 `extra_rounds` 에 개별 기록된다)」를 「`begin-round --extra-approval "<고른 선택지 이름 또는 기타 칸에 쓴 말 그대로>" --extra-approval-source label|typed` 로 돈다 — 선택지를 골랐으면 `label`, 기타 칸에 썼으면 `typed`. 둘이 `extra_rounds` 에 함께 기록된다」로 바꾼다. 1단계(:16)의 `--extra-approval "<사용자 문구>"` 도 같은 꼴로. 라벨 규약 문단(:43) 끝에 두 문장을 더한다: 「질문 · 선택지 이름에 AC 번호 · 지적 id · § 를 쓰지 않고 설명 괄호에만 쓴다 — 선택지 이름만 보고 무엇을 고르는지 알 수 있어야 한다. 상한 · 정체로 열린 승인 게이트의 승인 선택지 이름은 엔진 렌더의 「열린 지적 N개를 두고 진행」을 그대로 쓴다.」(첫 문장이 Step 1 락의 고정 문구다.)

spec-review SKILL.md `## 게이트` :514-520 의 마지막 문장, reviewing-brief SKILL.md :571-576 의 같은 문장을 절차서와 같은 새 꼴로 바꾸고, spec-review :522 라벨 규약 문단에도 같은 두 문장을 더한다(`test_docreview_round_gate_split.sh` 가 두 파일을 함께 잰다 — 그 락에 「질문 · 선택지 이름에 AC 번호 · 지적 id · § 를 쓰지 않고」 body-unique 축 하나를 더한다). request-framing :414-417 은 `--extra-approval="$q"` 뒤에 `--extra-approval-source "$src"` 를 붙이고, `$src` 는 사용자가 기타 칸에 썼으면 `typed`, 선택지를 골랐으면 `label` 로 펜스 앞에서 대입한다고 적는다(`said-extra-r<n>.txt` 파일 경로는 그대로). `test_framing_review_contract.sh:90` 의 문자열을 `--extra-approval="$q" --extra-approval-source "$src"` 로 고친다.

- [ ] **Step 5: 통과 · 골든 · 커밋**

Run: `bash shared/tests/test_docreview_gate_plain.sh 2>&1 | tail -2; bash shared/tests/test_docreview_state.sh 2>&1 | tail -2; bash shared/tests/test_docreview_round_gate_split.sh 2>&1 | tail -2; bash plugins/spec-distill/tests/test_framing_review_contract.sh 2>&1 | tail -2; bash plugins/spec-distill/tests/test_reviewing_brief_skill.sh 2>&1 | tail -2`
Expected: Fail 0. 골든 갱신 diff 는 `gate.txt` 의 막힌 질문 줄 · `gate.json` 의 `open_total` 키뿐이어야 한다.

변이: `_rg_blocking_ask` 를 옛 꼴로 되돌린 작업 트리에서 `test_docreview_gate_plain.sh` 가 RED 인지 본다.

```bash
git add shared/tests/test_docreview_gate_plain.sh
git commit -m "feat(docreview): 게이트에 열린 지적 수 · 고른 선택지 승인 · 괄호 밖 기호 없는 렌더" -- shared/docreview/scripts/docreview_state.py shared/docreview/references/reviewing-document.md plugins/spec-distill/skills/spec-review/SKILL.md plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/skills/request-framing/SKILL.md shared/tests/test_docreview_round_gate_split.sh plugins/spec-distill/tests/test_framing_review_contract.sh shared/tests/test_docreview_gate_plain.sh shared/tests/fixtures/docreview/cases.sh shared/tests/test_docreview_state.sh shared/tests/fixtures/docreview/golden
```

---

### Task 5: 함께 고친 곳 신고 — `declare-related` (AC38)

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py` (새 `cmd_declare_related` · `exempt_scopes` :372-397 · `observe_ledger` :959-1050 · `render_gate` · `gate_summary` · 파서)
- Modify: `shared/docreview/references/reviewing-document.md` (`## 배달` · 3단계 · 6단계 입력 슬롯)
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md` · `reviewing-brief/SKILL.md` · `request-framing/SKILL.md` (탐지 · 재비판 dispatch 블록에 `<related_changes>` 슬롯)
- Test: `shared/tests/fixtures/docreview/cases.sh` · `shared/tests/test_docreview_state.sh`

**Interfaces:**
- Produces: `docreview_state.py declare-related --state-dir D --decision <D id> --anchors <앵커> [<앵커> …]` → `{"ok": true, "decision_id", "related": [앵커…]}`. 거부 사유: `unknown_decision` · `decision_not_adopted` · `permit_consumed` · `anchor_not_in_snapshot`(현재 라운드 스냅숏에 없는 앵커 — `insert-after:#x` 꼴은 받는다). permit 새 키 `related_anchors: [str]`. `exempt_scopes` 가 permit 라운드에서 그 앵커를 면제한다(`scope` 값 `related:<D id>`). `gate` JSON 새 키 `related_changes: [{"decision_id", "anchors": [...], "changed": [...], "unchanged": [...]}]`(이번 라운드 permit 의 것). 새 명령 `docreview_state.py related-changes --state-dir D` → 이번 라운드의 바뀐 신고 절 목록 `[{"anchor", "title"}]`(읽기 전용 — 진입이 탐지 · 재비판의 `<related_changes>` 슬롯에 싣는다).
- Consumes: Task 4 의 렌더 꼴 · Task 1 의 `P()`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

픽스처: `design-sample-r2.md` 는 `#2-goals` 와 `#12-files-to-modify` 가 바뀐 문서다(`case_T21_permit_applied` 의 기대값 근거). `F_DEC`(앵커 `#12-files-to-modify`)를 채택하면 `#2-goals` 변경은 지금 `frozen_change` 다.

```bash
case_AC38_related_declared_exempt_and_shown() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  local did; did="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' | jgets 'd["decision_id"]')"
  py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors '#2-goals' > "$d/rel.json"
  assert_eq "$(jget "$d/rel.json" 'd["ok"], d["related"]')" "(True, ['#2-goals'])" "AC38: 고친다 결정에 절을 묶는다"
  local df; df="$(next_round "$d" "$FX/design-sample-r2.md")"
  assert_eq "$(jget "$df" '[c["anchor"] for c in d["changed"]]')" "[]" "AC38: 묶인 절의 변경은 frozen_change 로 오르지 않는다"
  assert_eq "$did" "D1.1" "AC38: 라운드 1 의 첫 결정 id"
  assert_eq "$(jget "$df" 'sorted(e["scope"] for e in d["exempt_applied"])')" "['#12-files-to-modify', 'related:D1.1']" "AC38: 면제 사유가 신고로 보인다"
  local r; r="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_contains "$r" "이 결정 때문에 함께 바뀐 곳" "AC38: 게이트에 목록 제목"
  assert_contains "$r" "2. Goals" "AC38: 게이트에 절 제목"
  assert_eq "$(py docreview_state.py related-changes --state-dir "$d" | jgets '[x["anchor"] for x in d]')" "['#2-goals']" "AC38: 탐지 · 재비판 입력용 목록"
  rm -rf "$d"
}
case_AC38_related_undeclared_still_frozen() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' >/dev/null
  local df; df="$(next_round "$d" "$FX/design-sample-r2.md")"
  assert_eq "$(jget "$df" '[c["anchor"] for c in d["changed"]]')" "['#2-goals']" "AC38: 신고하지 않은 절은 여전히 frozen_change"
  rm -rf "$d"
}
case_AC38_related_refusals() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  local err
  err="$(py docreview_state.py declare-related --state-dir "$d" --decision D9.9 --anchors '#2-goals' 2>&1 >/dev/null)"
  assert_contains "$err" '"reason": "unknown_decision"' "AC38: 원장에 없는 결정 id 는 거부"
  local did; did="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice reject --quote '그대로' | jgets 'd["decision_id"]')"
  err="$(py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors '#2-goals' 2>&1 >/dev/null)"
  assert_contains "$err" '"reason": "decision_not_adopted"' "AC38: 고친다가 아닌 결정은 거부"
  rm -rf "$d"
}
case_AC38_related_declared_but_unchanged_disclosed() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  local did; did="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' | jgets 'd["decision_id"]')"
  py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors '#3-non-goals' >/dev/null
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  assert_contains "$(py docreview_state.py gate --state-dir "$d" --render)" "신고했지만 바뀌지 않은 곳" "AC38: 신고했는데 안 바뀐 절도 공시한다"
  rm -rf "$d"
}
```

(앵커 이름과 제목은 `case_anchor_snapshot_shape` 의 기대값 — `#2-goals` 제목 `2. Goals` — 에서 왔다. 실제 픽스처 제목이 다르면 그 케이스의 앵커 목록을 보고 맞춘다.)

- [ ] **Step 2: 실패를 본다**

Run: `bash shared/tests/test_docreview_state.sh 2>&1 | grep -E 'AC38|Total'`
Expected: ✗(`declare-related` 없음).

- [ ] **Step 3: 구현한다**

```python
def cmd_declare_related(a) -> int:
    """「고친다」 결정 때문에 함께 고친 절을 그 결정의 permit 에 묶는다(B9). 묶인 절은 permit 라운드의 얼림 면제에
    들되 게이트 · 다음 리뷰어 입력에 보인다 — 숨기는 면제가 아니다."""
    st = load_state(a.state_dir)
    did = a.decision
    entry = next((e for e in st["decision_log"] if e.get("decision_id") == did), None)
    if entry is None:
        return fail("unknown_decision", decision_id=did)
    p = (st.get("permits") or {}).get(did)
    if entry.get("choice") != "adopt" or not p or p.get("kind") != "apply":
        return fail("decision_not_adopted", decision_id=did, choice=entry.get("choice"))
    if p.get("consumed"):
        return fail("permit_consumed", decision_id=did, round=p.get("round"))
    known = {s["anchor"] for s in snapshot_at(st, int(st["round"]))["sections"]}
    bad = [x for x in a.anchors if not x.startswith("insert-after:") and x not in known]
    if bad:
        return fail("anchor_not_in_snapshot", anchors=bad)
    rel = list(p.get("related_anchors") or [])
    for x in a.anchors:
        if x not in rel and x not in p["apply_anchors"]:
            rel.append(x)
    p["related_anchors"] = rel
    save_state(a.state_dir, st, "declare-related %s %s" % (did, " ".join(a.anchors)))
    _emit({"ok": True, "decision_id": did, "related": rel})
    return 0
```

`exempt_scopes` 의 permit 순회에 더한다(앵커를 「related:<D id>」 사유로 남기기 위해 `diff_snapshots` 가 받는 집합은 `(scope, anchor)` 쌍이어야 한다 — 지금 `ex[a] = sc` 는 scope 문자열이 곧 앵커다). 그래서 `exempt_scopes` 의 결과 항목을 문자열 또는 `"related:<D>=<앵커>"` 꼴로 내고 `resolve_scope` 가 그 꼴을 푼다:

```python
def resolve_scope(scope: str, old_secs, new_secs) -> set:
    if scope.startswith("related:") and "=" in scope:
        return {scope.split("=", 1)[1]}
    ...
```

그리고 `diff_snapshots` 의 `ex[a] = sc` 에서 related 꼴이면 `sc.split("=", 1)[0]` 을 `scope` 로 남긴다(Step 1 기대값 `related:D1.1`). `exempt_scopes` 의 permit 루프:

```python
        if k == r:
            out.extend(anchors)
            for x in p.get("related_anchors") or []:
                out.append("related:%s=%s" % (did, x))
```

`_permit_fields` 는 바꾸지 않는다(`related_anchors` 는 선택 키). `observe_ledger` 는 apply 판정에 related 앵커를 쓰지 않는다(결정 적용은 결정 앵커로만 본다). 대신 `gate_summary` 에:

```python
    rel = []
    for did, p in (st.get("permits") or {}).items():
        if int(p.get("round", -1)) != n or not p.get("related_anchors"):
            continue
        try:
            d = round_diff(st, load_profile(st["profile"]), n)
            touched = {e["anchor"] for e in d["exempt_applied"]} | {c["anchor"] for c in d["changed"]}
        except (LedgerCorrupt, ProfileError, OSError):
            touched = set()
        anchors = list(p["related_anchors"])
        rel.append({"decision_id": did, "anchors": anchors,
                    "changed": [x for x in anchors if x in touched], "unchanged": [x for x in anchors if x not in touched]})
    g["related_changes"] = rel
```

`render_gate` 의 행 묶음 뒤 · 집계 앞에:

```python
    titles = {s["anchor"]: s.get("title") for s in (st["snapshots"].get(str(g["round"])) or {}).get("sections", [])}
    for rc in g.get("related_changes") or []:
        if rc["changed"]:
            out.append("이 결정 때문에 함께 바뀐 곳 %d개 (%s)" % (len(rc["changed"]), rc["decision_id"]))
            out.extend("- %s (%s)" % (_one(titles.get(x) or x), x) for x in rc["changed"])
        if rc["unchanged"]:
            out.append("신고했지만 바뀌지 않은 곳 %d개 (%s)" % (len(rc["unchanged"]), rc["decision_id"]))
            out.extend("- %s (%s)" % (_one(titles.get(x) or x), x) for x in rc["unchanged"])
```

`cmd_related_changes`(읽기 전용, 원장 쓰기 없음): 이번 라운드 `gate_summary` 의 `related_changes` 에서 `changed` 앵커를 `[{"anchor", "title"}]` 로 낸다. 파서: `x = P("declare-related"); sd(x); x.add_argument("--decision", required=True); x.add_argument("--anchors", required=True, nargs="+")` · `x = P("related-changes"); sd(x)`.

- [ ] **Step 4: 절차서 · 진입 문면 · 리뷰어 슬롯**

`reviewing-document.md` `## 배달` 의 채택 줄 뒤에: 「채택한 결정 때문에 다른 절(수용 기준 · 처분표 등)도 고쳤으면 `docreview_state.py declare-related --state-dir D --decision <D#> --anchors <앵커…>` 로 그 절을 결정에 묶는다 — 묶은 절은 다음 라운드 얼림 검사에서 빠지되 게이트에 「이 결정 때문에 함께 바뀐 곳」으로 보이고 다음 라운드 리뷰어가 다시 본다. 묶지 않고 고친 절은 「허가 없이 바뀐 곳」으로 다시 사용자에게 간다.」 3단계 · 6단계 입력 슬롯에 「(있으면) `related-changes` 출력 — 이 라운드에 결정 때문에 함께 바뀐 절의 제목과 앵커만. 결정 이유는 싣지 않는다(재비판의 프레이밍 차단)」을 더한다.

진입 skill 셋의 탐지 · 재비판 dispatch 블록 prompt 에 `<related_changes>${RELATED_CHANGES}</related_changes>` 를 더한다 — **이 슬롯은 persona `input_slots` 와 함께 바뀌어야 한다**(`test_agent_input_slots.sh`). persona 쪽 슬롯 추가는 Task 6 이 보안 리뷰 대상과 함께 한다 — 그래서 이 Step 의 dispatch 블록 편집은 Task 6 Step 4 로 옮겨 한 커밋에 둔다(여기서는 절차서 문면과 엔진만).

- [ ] **Step 5: 통과 · 커밋**

Run: `bash shared/tests/test_docreview_state.sh 2>&1 | tail -2; bash shared/tests/test_docreview_golden.sh 2>&1 | tail -2; bash shared/tests/test_docreview_mutations.sh 2>&1 | tail -2`
Expected: Fail 0. 골든은 바뀌지 않아야 한다(골든 케이스에 신고가 없다 — `related_changes: []` 키가 `gate.json` 에 생기면 그것만 갱신).

```bash
git commit -m "feat(docreview): 결정 때문에 함께 고친 절을 신고해 보이고 다시 본다" -- shared/docreview/scripts/docreview_state.py shared/docreview/references/reviewing-document.md shared/tests/fixtures/docreview/cases.sh shared/tests/test_docreview_state.sh shared/tests/fixtures/docreview/golden
```

---

### Task 6: 결정 반대 본문은 저자 고침 · 리뷰어 지시 (AC39 · AC41 의 persona 부분) — 보안 리뷰 대상

**Files:**
- Modify: `shared/docreview/scripts/docreview_route.py` (`normalize` :130-162 · `_classify_items` :514-572 · `_absorb_same_as` :501 · `_build_report`)
- Modify: `shared/docreview/scripts/docreview_advice.py` (`is_advisory`)
- Modify: `shared/docreview/scripts/docreview_state.py` (`PUBLIC_FIELDS` 에 `contradicts` · `WARN_GLOSS` 한 행)
- Modify (persona — 보안 리뷰): `shared/docreview/agents/doc-critic.md` · `doc-critic-web.md` · `doc-recritic.md` 와 `plugins/spec-distill/agents/` 의 같은 이름 사본 셋
- Modify (리뷰어 지시 — 보안 리뷰): `shared/docreview/scripts/run_docreview_codex_reviewer.sh` (:439-447 스키마 줄)
- Modify: 진입 skill 셋의 탐지 · 재비판 dispatch 블록(Task 5 Step 4 에서 옮겨 온 `<related_changes>` 슬롯)
- Create: `shared/tests/fixtures/docreview/critic-contradicts.txt`
- Test: `shared/tests/fixtures/docreview/cases.sh` · `shared/tests/test_docreview_route.sh` · `shared/tests/test_docreview_agent_fields.sh`

**Interfaces:**
- Consumes: 원장 `decision_log[].decision_id`(`D<r>.<n>`).
- Produces: 지적 필드 `contradicts: <D id>`(선택). 라우팅: 실재하면 `disposition = "fix"` · `_decision_backed = True`(advisory 아님 · 보호 승격 건너뜀 · 불변 절은 지금처럼 decide). 실재하지 않으면 `contradicts` 를 `None` 으로 강제(`L.coerced("contradicts", id, None)`)하고 advisory 원문 `없는 결정 id <id> — 참고로 둠` 을 더한다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`critic-contradicts.txt`:

````text
```docreview-layer1
[]
```
```docreview-layer2
- ref: c1
  layer: 2
  category: ambiguity
  anchor: "#12-files-to-modify"
  disposition: decide
  contradicts: "D1.1"
  summary: "파일 목록이 이미 고친다로 정한 결정과 반대로 적혀 있다"
  evidence: "12행"
- ref: c2
  layer: 2
  category: ambiguity
  anchor: "#handoff-context"
  disposition: decide
  contradicts: "D7.7"
  summary: "넘김 절이 없는 결정을 가리키며 반대라고 한다"
  evidence: "넘김 절"
```
````

`cases_advice.sh`(advisory 축이 있는 실제 프로필 `$PROF_MC` 를 쓴다 — design-doc 실제 프로필에서 `ambiguity` 는 참고 축이다. 이 파일은 `cases.sh` 의 헬퍼 `r1` · `seed_findings` · `next_round` · `critic_now` 를 함께 쓴다):

```bash
case_AC39_contradicts_routes_fix() {
  local d; d="$(r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' >/dev/null   # → D1.1
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-contradicts.txt")" > "$d/prep.json"
  py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample-r2.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" '[ (i["contradicts"], i["disposition"], i.get("route")) for i in d["findings"] if i.get("contradicts") ]')" "[('D1.1', 'fix', None)]" "AC39: 실재하는 결정 id 를 단 지적은 참고가 아니라 저자 고침"
  assert_eq "$(jget "$d/fin.json" '[i["summary"] for i in d["findings"] if i["anchor"]=="#handoff-context" and i.get("route")=="advice"]')" "['넘김 절이 없는 결정을 가리키며 반대라고 한다']" "AC39: 없는 id 는 참고로 남는다"
  assert_contains "$(jget "$d/fin.json" '" | ".join(d["advisory"])')" "없는 결정 id D7.7" "AC39: 없는 id 를 공시한다"
  rm -rf "$d"
}
case_AC39_contradicts_skips_protected_promotion() {
  # 보호 절(수용 기준)의 결정 반대 지적은 decide 로 오르지 않는다(설계에 없던 결정 4)
  local d; d="$(r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' >/dev/null
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  sed 's/#12-files-to-modify/#11-acceptance-criteria/' "$FX/critic-contradicts.txt" > "$d/critic-ac.src"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$d/critic-ac.src")" > "$d/prep.json"
  py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample-r2.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" '[ (i["contradicts"], i["disposition"], i.get("promotion")) for i in d["findings"] if i.get("contradicts") ]')" "[('D1.1', 'fix', None)]" "AC39: 보호 절이어도 실재 결정을 가리킨 지적은 저자 고침(보호 승격 없음)"
  # 양성 짝 — contradicts 없는 같은 자리 fix 는 지금처럼 보호 승격으로 decide 가 된다
  rm -rf "$d"
}
```

`test_docreview_agent_fields.sh` 에 축을 더한다 — 여섯 파일(정본 셋 + 사본 셋) 모두에:
- `contradicts` 키가 출력 형식 문단에 있다(doc-critic · doc-critic-web: 지적 키 목록, doc-recritic: `added` 항목 설명).
- 문장 `항목 첫 줄(summary)은 지적 id · AC 번호 · § 같은 내부 기호 없이 무엇이 문제인지 문장으로 쓴다` 가 본문에 있다.
- `input_slots` 에 `tag: related_changes` 가 `optional: true` 로 있다(doc-critic 계열 · doc-recritic).

- [ ] **Step 2: 실패를 본다**

Run: `bash shared/tests/test_docreview_advice.sh 2>&1 | grep -E 'AC39|Total'; bash shared/tests/test_docreview_agent_fields.sh 2>&1 | tail -4`
Expected: ✗(`contradicts` 가 `normalize` 에서 버려짐 · persona 문장 없음).

- [ ] **Step 3: 라우터를 고친다**

`normalize` 반환 dict 에 `"contradicts": (str(item["contradicts"]).strip() if item.get("contradicts") else None),` 를 더한다. `_absorb_same_as` :501 의 물려받는 칸 목록에 `"contradicts"` 를 더한다. `PUBLIC_FIELDS` 끝에 `"contradicts"`.

`_classify_items` 의 허용 처분 강제 직후 · 앵커 분류 전에:

```python
        cid = it.get("contradicts")
        if cid:
            if cid in decision_ids:
                if d != "fix" and "fix" in allowed:
                    L.coerced("disposition", d, "fix")
                    it["disposition"] = d = "fix"
                it["_decision_backed"] = True
            else:
                L.coerced("contradicts", cid, None)
                unknown_decisions.append(cid)
                it["contradicts"] = None
```

(`decision_ids = {e.get("decision_id") for e in st.get("decision_log") or []}` 와 `unknown_decisions = []` 를 함수 머리에서 만들고, 반환값을 `(final, rejected_items, unknown_decisions)` 로 넓혀 `cmd_finalize` 가 `degrade["unknown_decisions"] = unknown_decisions` 로 넘긴다.) 보호 승격 분기의 조건에 `and not it.get("_decision_backed")` 를 더한다(불변 분기는 그대로 — 불변이면 decide).

`_build_report`: `if degrade.get("unknown_decisions"): adv.append("없는 결정 id %s — 참고로 둠" % ", ".join(degrade["unknown_decisions"]))`. `WARN_GLOSS` 에 행 `(r"없는 결정 id (?P<why>.*) — 참고로 둠", "결정 id", "지적이 가리킨 결정을 기록에서 찾지 못해 참고로 두었다")`.

`docreview_advice.is_advisory` 첫 줄에 `if it.get("_decision_backed"): return False` — 엔진 자동 항목과 같은 자리다(must-catch 로 친다).

- [ ] **Step 4: persona · 리뷰어 지시 · 슬롯 (보안 리뷰 대상)**

`shared/docreview/agents/doc-critic.md` 출력 형식 문단(:62)의 키 목록에서 `supersedes`(선택) 뒤에 다음을 넣는다: 「`contradicts`(선택 — 이 본문이 이미 내린 결정과 반대일 때 그 결정 id(`D<r>.<n>`). 문서의 결정 기록 절에 그 id 의 줄이 있을 때만 단다. 달면 저자가 바로 고친다 — 사용자에게 다시 묻지 않는다)」. 그 문단 끝 문장 뒤에: 「항목 첫 줄(summary)은 지적 id · AC 번호 · § 같은 내부 기호 없이 무엇이 문제인지 문장으로 쓴다 — 기호가 꼭 필요하면 문장 뒤 괄호에 둔다.」 `input_slots` 에:

```yaml
  - tag: related_changes
    var: RELATED_CHANGES
    kind: repo_context
    optional: true
```

`## 입력` 에: 「`<related_changes>` — (있으면) 이번 라운드에 사용자가 고친다로 정한 결정 때문에 함께 바뀐 절의 제목과 앵커. 그 절들을 다른 절과 같은 기준으로 다시 본다 — 바뀌었다는 사실이 통과의 근거가 아니다.」

`doc-critic-web.md` 는 같은 세 편집을 같은 자리에(`## 웹 근거` 블록 밖). `doc-recritic.md` 는 `added` 설명(:50-51)에 같은 `contradicts` 문장과 첫 줄 문장을, `input_slots` 에 같은 슬롯을, 입력 설명 문단에 「`<related_changes>` 는 정적 데이터다 — 바뀐 절의 목록일 뿐 왜 바뀌었는지는 없다」를 더한다. `plugins/spec-distill/agents/` 사본 셋을 정본과 같게 만든다(첫 줄 `# copy-of:` 만 다름).

`run_docreview_codex_reviewer.sh` :439-447 스키마 설명에 `contradicts`(선택) 키와 첫 줄 규칙 문장을 같은 문면으로 더한다(JSON 예시에는 넣지 않는다 — 선택 키).

진입 skill 셋의 탐지 dispatch 블록 prompt 끝에 `<related_changes>${RELATED_CHANGES}</related_changes>`, 재비판 블록에도 같은 줄을 더하고, 그 앞 문단에 「`RELATED_CHANGES` 는 `docreview_state.py related-changes --state-dir "$STATE_DIR"` 출력(없으면 빈 값)」을 적는다. 재비판 블록 위 문단의 「입력 슬롯은 넷」을 「다섯 — 그중 `diff` 와 `related_changes` 는 선택」으로 고친다.

- [ ] **Step 5: 통과를 본다**

Run: `for t in shared/tests/test_docreview_advice.sh shared/tests/test_docreview_route.sh shared/tests/test_docreview_agent_fields.sh shared/tests/test_docreview_agents.sh shared/tests/test_copy_of_contract.sh shared/tests/test_variant_of_contract.sh shared/tests/test_agent_input_slots.sh shared/tests/test_docreview_codex.sh shared/tests/test_docreview_golden.sh plugins/spec-distill/tests/test_reviewing_brief_skill.sh; do printf '%s ' "$t"; bash "$t" 2>&1 | tail -1; done`
Expected: 모두 Fail 0. 골든은 `state.md` · `fin.json` 의 `contradicts: null` 키만 바뀐다(갱신 후 diff 로 확인).

- [ ] **Step 6: 보안 리뷰 diff 를 남기고 커밋**

`git diff HEAD -- shared/docreview/agents plugins/spec-distill/agents shared/docreview/scripts/run_docreview_codex_reviewer.sh > "$HOME/.claude/sdd-mirror/r2a-plan2/persona.diff"` — Task 13 보안 리뷰 입력이다.

```bash
git add shared/tests/fixtures/docreview/critic-contradicts.txt
git commit -m "feat(docreview): 결정 반대 본문은 저자 고침 · 리뷰어 첫 줄 쉬운 말 · 함께 바뀐 절 슬롯" -- shared/docreview/scripts/docreview_route.py shared/docreview/scripts/docreview_advice.py shared/docreview/scripts/docreview_state.py shared/docreview/agents plugins/spec-distill/agents shared/docreview/scripts/run_docreview_codex_reviewer.sh plugins/spec-distill/skills/spec-review/SKILL.md plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/skills/request-framing/SKILL.md shared/tests/fixtures/docreview/critic-contradicts.txt shared/tests/fixtures/docreview/cases.sh shared/tests/fixtures/docreview/cases_advice.sh shared/tests/test_docreview_advice.sh shared/tests/test_docreview_route.sh shared/tests/test_docreview_agent_fields.sh shared/tests/fixtures/docreview/golden
```

---

### Task 7: 결정 기록 줄 위조 — `_log_line` 줄 전체를 한 줄 문법으로 (AC15)

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py` (`_log_line` :767-772)
- Test: `shared/tests/fixtures/docreview/cases.sh` · `shared/tests/test_docreview_state.sh` · `plugins/spec-distill/tests/test_seed_grammar_crosscheck.py` (엔진 줄 문법 `ENGINE_LINE_RE` 와 맞는지)

**Interfaces:**
- Produces: `one_line_field(s) -> str` — 줄바꿈 · CR · 제어 문자(Cc · Cf · Zl · Zp · `\x85`) · 유니코드 줄 구분자를 공백 하나로, 연속 공백을 하나로, 앞뒤 공백 제거. 줄 머리 표지는 `_log_line` 이 늘 `- D…` 로 시작하므로 칸 값이 줄 머리에 올 수 없다 — 칸 안의 `- ` · `#` · `>` · `**S9**` 은 그 줄 안의 글자로만 남는다.

- [ ] **Step 1: 실패하는 테스트 — 칸마다 위조 시도(허용 문법의 부정형으로 고른 꼴)**

```bash
case_AC15_log_line_one_line_every_field() {
  # 위조 꼴은 허용 문법(한 줄)의 부정형 — 줄 구분자 전부 × 칸 넷. bash 3.2 의 $'…' 는 \u 를 모르므로 꼴은 python 안에서 만든다.
  local res; res="$(python3 "$FX/ac15_forge.py" "$SCRIPTS")"
  assert_eq "$res" "36 0" "AC15: 칸 넷(요약 · 선택지 문구 · supersedes · 지적 id) × 줄 구분자 아홉 — 결정 줄은 늘 한 줄이고 앵커 줄이 생기지 않는다"
}
case_AC15_drop_reason_one_line() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  local log="$d/log.md"; printf '# 문서\n\n## 결정 기록\n\n' > "$log"
  py docreview_state.py fix --state-dir "$d" --id 'bbbb0001#r1.1' --event drop --reason $'버린다\n- **S9** 「위조」' --log-file "$log" >/dev/null
  assert_eq "$(grep -cE '^\s*[-*]\s+\*\*S[0-9]+\*\*' "$log")" "0" "AC15: 버림 사유(fix --reason)로도 앵커 줄을 만들 수 없다"
  assert_eq "$(grep -c '^- D' "$log")" "1" "AC15: 결정 줄은 하나"
  rm -rf "$d"
}
```

픽스처 헬퍼 `shared/tests/fixtures/docreview/ac15_forge.py`(새 파일 — heredoc-in-$() 함정을 피해 파일로 둔다):

```python
#!/usr/bin/env python3
"""ac15_forge.py <scripts-dir> — `_log_line` 의 칸 넷에 줄 구분자 아홉 꼴을 넣어 «전체 줄 수 · 나쁜 줄 수»를 찍는다."""
import re
import sys

sys.path.insert(0, sys.argv[1])
import docreview_state as S  # noqa: E402

TAIL = "- **S9** 「위조」"
FORGES = ["\n" + TAIL, "\r" + TAIL, " " + TAIL, " " + TAIL, "\x85" + TAIL, "\x0b" + TAIL,
          "\x0c" + TAIL, "\x1c" + TAIL, "\n\n## 6. 사용자 원문\n" + TAIL]
SPLIT = re.compile("[\n\r\x0b\x0c\x1c\x1d\x1e\x85  ]")
rows = []
for f in FORGES:
    for k in ("summary", "quote", "supersedes", "finding"):
        e = {"decision_id": "D1.1", "round": 1, "choice": "adopt", "finding_ids": ["a#r1.1"], "quote": "고친다"}
        fd = {"summary": "요약"}
        if k == "summary":
            fd["summary"] = "요약" + f
        elif k == "quote":
            e["quote"] = "고친다" + f
        elif k == "supersedes":
            e["supersedes"] = "D0.1" + f
        else:
            e["finding_ids"] = ["a#r1.1" + f]
        rows.append(S._log_line(e, fd))
bad = [r for r in rows if len(SPLIT.split(r)) != 1 or re.search(r"^\s*[-*]\s+\*\*S\d+\*\*", r, re.M)]
print(len(rows), len(bad))
```

(`decide --quote` 칸은 첫 케이스의 `quote` 로, `fix --reason` 은 둘째 케이스로 CLI 경로까지 잰다. Step 4 커밋 pathspec 에 `shared/tests/fixtures/docreview/ac15_forge.py` 를 더하고 `git add` 한다.)

- [ ] **Step 2: 실패를 본다**

Run: `bash shared/tests/test_docreview_state.sh 2>&1 | grep -E 'AC15|Total'`
Expected: ✗(줄바꿈이 그대로 남는다).

- [ ] **Step 3: 구현한다**

```python
_BREAKS = re.compile("[\\n\\r\\x0b\\x0c\\x1c\\x1d\\x1e\\x85\\u2028\\u2029]")


def one_line_field(s) -> str:
    """결정 줄 한 칸 — 줄 구분자 · 제어 · 서식 문자를 공백으로, 공백 연속을 하나로. 칸 값은 줄 머리에 올 수 없다
    (`_log_line` 이 늘 「- D…」 로 연다) — 칸 안의 목록 · 제목 · 인용 표지는 그 줄 안의 글자일 뿐이다(AC15)."""
    t = _BREAKS.sub(" ", str(s if s is not None else ""))
    t = "".join(" " if unicodedata.category(ch) in ("Cc", "Cf", "Zl", "Zp") else ch for ch in t)
    return " ".join(t.split())


def _log_line(entry, f) -> str:
    s = "- %s · r%d · %s · %s · \"%s\"" % (one_line_field(entry["decision_id"]), int(entry["round"]),
                                           one_line_field(entry["choice"]),
                                           ", ".join(one_line_field(x) for x in entry["finding_ids"]),
                                           one_line_field(entry["quote"]).replace('"', "”"))
    if entry.get("supersedes"):
        s += " · supersedes %s" % one_line_field(entry["supersedes"])
    return s + " — " + one_line_field(f.get("summary") or "")
```

(`import unicodedata` 를 머리에. 선택지 문구 안의 `"` 는 `”` 로 — `seed_review_log.ENGINE_LINE_RE` 의 `"(?P<quote>.*?)"` 가 첫 `"` 에서 끊겨 뒤 칸을 위조할 수 있다. 이 치환을 `test_seed_grammar_crosscheck.py` 의 엔진 줄 생성 쪽과 맞춘다.)

- [ ] **Step 4: 통과 · 변이 · 커밋**

Run: `bash shared/tests/test_docreview_state.sh 2>&1 | tail -2; (cd plugins/spec-distill/tests && python3 -m unittest -q test_seed_grammar_crosscheck 2>&1 | tail -2); bash shared/tests/test_docreview_golden.sh 2>&1 | tail -2`
Expected: Fail 0. 변이: `one_line_field` 를 `str` 로 바꾸면 AC15 가 RED.

```bash
git add shared/tests/fixtures/docreview/ac15_forge.py
git commit -m "fix(docreview): 결정 기록 줄의 모든 칸을 한 줄 문법으로 — 사용자 문구 줄 위조 차단" -- shared/docreview/scripts/docreview_state.py shared/tests/fixtures/docreview/ac15_forge.py shared/tests/fixtures/docreview/cases.sh shared/tests/test_docreview_state.sh plugins/spec-distill/tests/test_seed_grammar_crosscheck.py
```

---

### Task 8: 원장 쓰기 락 — 읽기 전용 `advice-list` 로 원인 치우기 (AC16)

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py` (새 `cmd_advice_list` · 파서 — `advice` 의 플래그 없는 JSON 출력은 `advice-list` 로 옮기고 `advice` 는 쓰기 플래그 하나 이상을 요구)
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md` (`advice-all` 펜스 :587-609) · `plugins/spec-distill/skills/spec-interview/references/finishing.md` (`advice-ba` 펜스 :340)
- Modify: `shared/docreview/references/reviewing-document.md` (:54-79 advice 절)
- Rewrite: `plugins/spec-distill/tests/test_ledger_wiring.sh` 의 정적 락(:82-158)
- Test: `shared/tests/fixtures/docreview/cases_advice.sh`

**Interfaces:**
- Produces: `docreview_state.py advice-list --state-dir D` — 플래그 없음, 원장을 쓰지 않음, stdout JSON `{"ok", "items"}`. `advice` 를 쓰기 플래그(`--render` · `--sink` · `--log-file`) 없이 부르면 rc 2 `advice_needs_flag`(목록은 `advice-list` 로).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`cases_advice.sh`:

```bash
case_AC16_advice_list_read_only() {
  local d; d="$(route_mc_r1)" || { no "AC16: 원장 실패"; return; }   # 이 파일의 기존 must_catch 라운드 헬퍼
  local before after; before="$(shasum "$d/docreview-state.md" | cut -d' ' -f1)"
  py docreview_state.py advice-list --state-dir "$d" > "$d/list.json"; local rc=$?
  after="$(shasum "$d/docreview-state.md" | cut -d' ' -f1)"
  assert_eq "$rc $before" "0 $after" "AC16: advice-list 는 원장을 쓰지 않는다"
  assert_eq "$(jget "$d/list.json" 'd["ok"], isinstance(d["items"], list)')" "(True, True)" "AC16: 목록 JSON"
  py docreview_state.py advice-list --state-dir "$d" --render >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "AC16: advice-list 는 쓰기 플래그를 모른다"
  py docreview_state.py advice --state-dir "$d" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "AC16: 플래그 없는 advice 는 rc 2 — 목록은 advice-list 로"
  rm -rf "$d"
}
```

(`route_mc_r1` 이 없으면 이 파일의 `case_AC6_render_cap` 머리에서 원장을 만드는 줄을 그대로 헬퍼로 뺀다.)

`test_ledger_wiring.sh` 정적 락 재작성 — 새 규칙:

```bash
# AC8(이 테스트의 번호) — 엔진 쓰기 하위 명령 앞에 같은 펜스의 표지 확인이 있다. 판정은 하위 명령 «이름»으로만 한다.
# 읽기 전용은 `advice-list` · `gate` · `related-changes` · `state-dir-for` · `profile-check` · `gate-rows` · `exempt-anchors` 뿐이고
# 그 밖의 엔진 하위 명령은 전부 쓰기다(허용 목록 — 새 하위 명령은 기본이 쓰기다). 엔진을 부르는 줄에 넘기기(`>`)가 있으면
# 읽기 · 쓰기와 무관하게 거부한다 — 결과는 `$(…)` 로 받는다. mktemp · 재대입 · `||` 갈래를 파싱하지 않는다.
ac8_scan() {
  python3 -I - "$1" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
READ_ONLY = {"advice-list", "gate", "related-changes", "state-dir-for", "profile-check", "gate-rows", "exempt-anchors"}
ENGINE = re.compile(r'(docreview_state|docreview_route|docreview_anchor)\.py"?\s+([a-z][a-z-]*)')
GUARD = 'ledger_marker.py" check --dir "$STATE_DIR"'
bad = []
for body in re.findall(r"^```bash\n(.*?)^```$", text, re.S | re.M):
    lines = body.split("\n")
    joined = []
    for ln in lines:                      # 줄 잇기만 한다 — 셸 문법을 흉내 내지 않는다
        if joined and joined[-1].endswith("\\"):
            joined[-1] = joined[-1][:-1] + " " + ln
        else:
            joined.append(ln)
    for i, ln in enumerate(joined):
        for m in ENGINE.finditer(ln):
            if ">" in ln.replace("2>&1", "").replace("&>", ">"):
                bad.append("넘기기: " + ln.strip()[:120])
            if m.group(2) not in READ_ONLY and GUARD not in "\n".join(joined[:i]):
                bad.append("표지 확인 없는 쓰기: " + ln.strip()[:120])
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
}
```

(넘기기 판정은 「엔진을 부르는 줄에 `>` 가 있다」 하나다 — `2>"$err"` 도 거부한다. 오류는 `err="$(… 2>&1)"` 로 받는다. 표지 확인이 있는 펜스의 쓰기 명령도 넘기기는 거부된다: 원장 폴더 안 파일로 넘기던 finishing.md :340 은 `adv_list="$(python3 … advice-list --state-dir "$STATE_DIR")"` 로 바꾼다.)

음성 프로브(각각 RED 여야 한다 — 기존 17개 중 하위 명령 이름 축에 남는 것 + R2 잔여 다섯):
- `advice --state-dir "$STATE_DIR" --render`(표지 없음) · `decide …`(표지 없음) · `advice-list … > "$x"` · `x="$(mktemp "$STATE_DIR/a.XXXX")"; advice-list … > "$x"`(mktemp 인자 — 넘기기로 거부) · `x="$(mktemp)"; x="$STATE_DIR/y"; advice-list … > "$x"`(재대입 — 넘기기로 거부) · `advice-list … || advice … --render`(`||` 갈래 — 둘째 명령이 표지 없는 쓰기) · `> "$x"/y advice-list …`(명령 앞 넘기기 — 넘기기로 거부) · `advice --rend …`(줄인 플래그 — 하위 명령 `advice` 는 쓰기라 표지 없으면 거부).
- 다섯째 잔여(엔진 밖 원장 쓰기 — `cp` · `echo >`)는 이 락의 대상이 아니다(AC17 가 · Task 9).
양성 대조: `adv="$(python3 "$SD/scripts/docreview_state.py" advice-list --state-dir "$STATE_DIR")" || { echo "실패"; exit 0; }` 는 GREEN. 표지 확인 뒤의 `advice … --render --cap 8` 도 GREEN.

- [ ] **Step 2: 실패를 본다**

Run: `bash shared/tests/test_docreview_advice.sh 2>&1 | grep -E 'AC16|Total'; bash plugins/spec-distill/tests/test_ledger_wiring.sh 2>&1 | tail -6`
Expected: AC16 ✗ · 락은 지금 펜스(`advice … > "$adv_all"`)에서 「넘기기」로 RED.

- [ ] **Step 3: 구현 · 펜스 고치기**

```python
def cmd_advice_list(a) -> int:
    """참고(advisory) 목록 — 읽기 전용. 쓰기 플래그가 없는 하위 명령이라 펜스의 원장 쓰기 락이 이름만으로 가른다."""
    st = load_state(a.state_dir)
    _emit({"ok": True, "items": (_adv.scrub(list((st.get("advice") or {}).values())) if _adv else [])})
    return 0
```

`cmd_advice` 머리에:

```python
    if not (a.render or a.sink or a.log_file):
        fail("advice_needs_flag", hint="목록은 advice-list")
        return 2
``` 파서: `x = P("advice-list"); sd(x); x.set_defaults(fn=cmd_advice_list)`.

spec-review SKILL.md `advice-all` 펜스(:596-599)를:

```bash
adv_all="$(python3 "$SD/scripts/docreview_state.py" advice-list --state-dir "$STATE_DIR")" \
  || { echo "[spec-distill] 참고 전부 보기 실패 — 엔진이 목록을 내지 못했다. 게이트 앞 글에 싣는다."; exit 0; }
printf '%s\n' "$adv_all"
```

finishing.md :340 도 같은 꼴(`$(…)` 로 받고 파일로 넘기지 않는다). `advice-display` 펜스(:571)의 `2>"$adv_err"` 는 `adv_out="$(python3 … advice … --render --cap 8 2>&1)" || adv_rc=$?` 로 바꾸고, 사유 판별(:575 의 `grep -qE … "$adv_err"`)은 `printf '%s' "$adv_out" | grep -qE …` 로. request-framing :1084 의 `>/dev/null` 는 `cnt_out="$(… 2>&1)" || cnt_rc=$?` 로. `reviewing-document.md` advice 절의 「플래그가 없으면 목록 JSON 을 낸다(읽기 전용)」를 「목록은 `advice-list`(쓰기 플래그 없음 · 원장을 쓰지 않음)로 받는다 — `$(…)` 로 받고 파일로 넘기지 않는다. `advice` 는 쓰기 플래그 하나 이상이 있어야 돈다」로.

- [ ] **Step 4: 통과 · 변이 · 커밋**

Run: `bash shared/tests/test_docreview_advice.sh 2>&1 | tail -2; bash plugins/spec-distill/tests/test_ledger_wiring.sh 2>&1 | tail -3; bash shared/tests/test_docreview_advice_procedure.sh 2>&1 | tail -2; bash shared/tests/test_inline_python_isolated.sh 2>&1 | tail -2`
Expected: Fail 0. 변이: `READ_ONLY` 에 `"advice"` 를 넣으면 「표지 없는 advice --render」 프로브가 GREEN 으로 새는 것을 확인하고(이빨) 되돌린다.

```bash
git commit -m "fix(spec-distill): 원장 쓰기 락을 하위 명령 이름으로 — 읽기 전용 advice-list 로 원인 치우기" -- shared/docreview/scripts/docreview_state.py shared/docreview/references/reviewing-document.md plugins/spec-distill/skills/spec-review/SKILL.md plugins/spec-distill/skills/spec-interview/references/finishing.md plugins/spec-distill/skills/request-framing/SKILL.md plugins/spec-distill/tests/test_ledger_wiring.sh shared/tests/fixtures/docreview/cases_advice.sh shared/tests/test_docreview_advice.sh
```

---

### Task 9: 원장 요약값 · 엔진 밖 쓰기의 권한 경계 측정 (AC17)

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py` (`save_state` :262-271 · `load_state` :242-259 · `LedgerCorrupt` 를 `load_state` 에서 · `main` 의 예외 처리)
- Modify: `docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md` (`## 미룸` — 경계를 마련하지 못하면)
- Create: `$HOME/.claude/sdd-mirror/r2a-plan2/boundary-measure.md` (측정 기록, 레포 밖)
- Test: `shared/tests/fixtures/docreview/cases.sh` · `shared/tests/test_docreview_state.sh`

**Interfaces:**
- Produces: 원장 frontmatter 의 `docreview:` 트리 옆 최상위 키 `docreview_digest: <sha256 hex>` — `yaml.safe_dump({"docreview": st})` 문자열 + 본문의 sha256. `load_state` 가 대조해 다르면 `LedgerCorrupt("ledger_digest_mismatch")` → CLI rc 1, 사유 `ledger_corrupt` · `path` · `recover: ["엔진이 쓴 내용으로 되돌린다", "상태 폴더를 지우고 1라운드부터 다시 리뷰한다 — 라운드 · 재리뷰 횟수 · 지적 이력을 잃는다"]`. 요약값이 없는 원장은 통과하고 다음 `save_state` 가 채우며 `st["rounds"][n]["digest_backfilled"] = True` 로 그 라운드 머리 줄에 한 번 공시한다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```bash
case_AC17_digest_mismatch_stops() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_contains "$(head -3 "$d/docreview-state.md")" "docreview_digest:" "AC17: 엔진이 저장할 때 요약값을 쓴다"
  python3 -I -c 'import sys; p=sys.argv[1]; t=open(p,encoding="utf-8").read(); open(p,"w",encoding="utf-8").write(t.replace("round: 1","round: 7",1))' "$d/docreview-state.md"
  local err rc; err="$(py docreview_state.py gate --state-dir "$d" 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc" "1" "AC17: 상태만 바꾼 원장은 멈춘다"
  assert_contains "$err" '"reason": "ledger_corrupt"' "AC17: 사유 이름"
  assert_contains "$err" "1라운드부터 다시 리뷰" "AC17: 복구 길을 함께 낸다"
  assert_contains "$err" "$d/docreview-state.md" "AC17: 원장 경로를 낸다"
  rm -rf "$d"
}
case_AC17_digest_backfill_disclosed_once() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  python3 -I -c 'import sys,re; p=sys.argv[1]; t=open(p,encoding="utf-8").read(); open(p,"w",encoding="utf-8").write(re.sub(r"^docreview_digest: .*\n","",t,count=1,flags=re.M))' "$d/docreview-state.md"
  py docreview_state.py gate --state-dir "$d" >/dev/null; local rc=$?
  assert_eq "$rc" "0" "AC17: 요약값 없는 기존 원장은 손상으로 보지 않는다"
  local s="$d/s2.json"; snap "$FX/design-sample.md" "$s"; py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" >/dev/null
  assert_contains "$(py docreview_state.py gate --state-dir "$d" --render | sed -n 2p)" "원장 확인값을 이번에 채웠다" "AC17: 채운 라운드 머리에 한 번 공시"
  local s3="$d/s3.json"; snap "$FX/design-sample.md" "$s3"; py docreview_state.py begin-round --state-dir "$d" --snapshot "$s3" >/dev/null
  assert_not_contains "$(py docreview_state.py gate --state-dir "$d" --render | sed -n 2p)" "원장 확인값을 이번에 채웠다" "AC17: 다음 라운드엔 다시 말하지 않는다"
  rm -rf "$d"
}
```

- [ ] **Step 2: 실패를 본다**

Run: `bash shared/tests/test_docreview_state.sh 2>&1 | grep -E 'AC17|Total'`
Expected: ✗.

- [ ] **Step 3: 구현한다**

```python
DIGEST_KEY = "docreview_digest"
RECOVER = ["엔진이 쓴 내용으로 되돌린다(이 파일을 손으로 고쳤다면 그 편집을 되돌린다)",
           "그 문서의 상태 폴더를 지우고 1라운드부터 다시 리뷰한다 — 라운드 · 재리뷰 횟수 · 지적 이력을 잃는다"]


def _digest(fm_tree_text: str, body: str) -> str:
    return hashlib.sha256((fm_tree_text + "\x00" + body).encode("utf-8")).hexdigest()


def save_state(state_dir, st, log_line=None) -> None:
    if yaml is None:
        raise RuntimeError("pyyaml_missing")
    body = st.pop("_body", "# docreview 원장\n")
    if log_line:
        body = body.rstrip("\n") + "\n- r%s: %s\n" % (st.get("round"), log_line)
    tree = yaml.safe_dump({"docreview": st}, allow_unicode=True, sort_keys=False, default_flow_style=False)
    fm = "%s: %s\n%s" % (DIGEST_KEY, _digest(tree, body), tree)
    _write_atomic(state_path(state_dir), "---\n" + fm + "---\n" + body)
    st["_body"] = body
```

`load_state`: frontmatter 텍스트에서 첫 줄이 `docreview_digest: <hex>` 이면 떼어 내고 나머지(트리 텍스트)와 본문으로 `_digest` 를 다시 계산해 대조한다. 다르면 `raise LedgerCorrupt("ledger_corrupt", path=str(p), recover=RECOVER)`. 없으면 `st["_digest_missing"] = True` 를 달고 통과한다. `save_state` 는 `_digest_missing` 이 있으면 키를 지우고(직렬화 전) `st["rounds"].setdefault(str(st["round"]), {...})["digest_backfilled"] = True` 를 남긴다. `render_gate` 둘째 줄: 그 라운드에 `digest_backfilled` 면 ` · 원장 확인값을 이번에 채웠다(이전 버전이 쓴 원장)`. `main` 에 `except LedgerCorrupt as e: return fail(e.reason, **e.extra)` 를 `FileNotFoundError` 앞에. (라우터 `docreview_route.main` 도 같은 처리.)

`LedgerCorrupt` 정의를 `load_state` 보다 위로 옮긴다(지금 :334 — 라운드 diff 절). 골든 `state.md` 다섯에 `docreview_digest:` 줄이 생긴다 — 갱신 후 diff 가 그 한 줄씩인지 본다(캡처 스크립트는 경로를 `<REPO_ROOT>` 로 바꾸므로 요약값이 체크아웃마다 다르다: 캡처의 정규화에 `docreview_digest: <hex>` → `docreview_digest: <DIGEST>` 치환을 더한다).

- [ ] **Step 4: 권한 경계 측정(AC17 가)**

버릴 레포(`mktemp -d` 안 `git init`)에서 세 후보를 잰다. 각 후보마다 「Write 도구로 원장 쓰기」 · 「Edit 도구로 원장 고치기」 · 「Bash `python3 -c` 로 상태와 요약값을 함께 다시 계산해 쓰기」 세 시도를 하고 거부되는지 기록한다(헤드리스 `claude -p` 는 rc 0 으로 조용히 실패하는 일이 있으니 결과 파일의 바이트로 판정한다).

1. spec-distill PreToolUse 훅(matcher `Write|Edit|MultiEdit`, 경로가 `*/.docreview/*/docreview-state.md` 이면 deny) — 훅 파일은 측정용 사본에만 만든다(레포에 커밋하지 않는다).
2. 권한 설정 deny 규칙(`permissions.deny: ["Edit(**/.docreview/**)", "Write(**/.docreview/**)"]`) — 버릴 레포의 `.claude/settings.json` 에만.
3. 파일 모드(`chmod a-w`) — 엔진 자신도 `_write_atomic` 의 `os.replace` 로 쓰므로 디렉토리 권한까지 본다.

기록: `$HOME/.claude/sdd-mirror/r2a-plan2/boundary-measure.md` 에 표(후보 × 시도 → 거부/통과 · 증거). **세 후보 모두 Bash 시도를 막지 못하면**(예상) 이 축을 닫았다고 쓰지 않는다 — 설계문서 `## 미룸` 표에 한 행: 항목 「엔진이 아닌 명령이 원장을 쓰는 축(AC17 가) — Write · Edit 는 훅 · 권한 설정으로 막을 수 있으나 Bash 로 상태와 요약값을 함께 다시 쓰는 시도는 레포 안 장치로 막지 못한다(측정: <파일 요약>)」 · 이유 「권한 경계가 레포 밖(하니스 권한 · 샌드박스)에 있다」 · 받는 곳 「<사용자가 정한 곳 — 설계에 없던 결정 8>」. Write · Edit 만 막는 훅을 레포에 더할지는 사용자가 정한다(부분 경계를 「닫았다」로 읽히게 하지 않는다 — 더한다면 README 「Hooks Installed」 · kill switch `DEVBREW_SPEC_DISTILL_DISABLE` · `test_review_hook_removed.py` 의 부재 락 재결정이 함께 필요하다).

- [ ] **Step 5: 통과 · 커밋**

Run: `bash shared/tests/test_docreview_state.sh 2>&1 | tail -2; bash shared/tests/test_docreview_golden.sh 2>&1 | tail -2; bash shared/tests/test_docreview_route.sh 2>&1 | tail -2; bash shared/tests/test_docreview_mutations.sh 2>&1 | tail -2`
Expected: Fail 0.

```bash
git commit -m "feat(docreview): 원장 확인값 대조 — 엔진이 쓴 것과 다르면 복구 길과 함께 멈춘다" -- shared/docreview/scripts/docreview_state.py shared/docreview/scripts/docreview_route.py shared/tests/fixtures/docreview/cases.sh shared/tests/test_docreview_state.sh shared/tests/fixtures/docreview/capture_finalize_golden.sh shared/tests/fixtures/docreview/golden docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md
```

---

### Task 10: brief 판독기 하나 — `brief_body.py` · rc 3 은 게이트를 막는다 · 로드맵 쪽 §4 규칙 (AC18 · §3 R2 엔진 몫의 `brief_universe`)

**Files:**
- Create: `plugins/spec-distill/scripts/brief_body.py` (표준 라이브러리만)
- Modify: `plugins/spec-distill/scripts/check_brief.py` (`S_ANCHOR_RE` :553 · `S_ANCHOR_NESTED_RE` :585 · `payload_verbatim_n1b_failures` :588-613 · `_entry_lines` :209 · `section4_items` :230-253 · `_decision_line` :1263-1298 · `gate()` :1524)
- Modify: `plugins/spec-distill/scripts/check_verbatim_coverage.py` (`ITEM_RE` :76 · `parse_section6` :224-266)
- Modify: `plugins/spec-distill/scripts/roadmap_model.py` (`brief_universe` :423-447 · `S_ANCHOR_RE` :146)
- Modify: `plugins/spec-distill/scripts/roadmap_render.py` (`_section4_index` 의 대체 경로 :250-264 — 규칙이 같아지면 지운다)
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md` (진입 게이트 펜스 :195-228 · rc 표 :230-238)
- Create: `plugins/spec-distill/tests/test_brief_body.py`
- Test: `plugins/spec-distill/tests/test_check_brief*.py` 기존 · `test_roadmap_model.py` · `test_roadmap_render.py` · `test_reviewing_brief_skill.sh`

**Interfaces:**
- Produces (`brief_body.py`):
  - `ANCHOR_LINE_RE = re.compile(r"^- \*\*(S\d+)\*\*(?: (.*))?$")` — §6 앵커 줄의 허용 문법: 열 0 의 `- ` 하나 + `**S<n>**` + (공백 하나 + 본문). 그 밖은 앵커가 아니다.
  - `anchor_lines(section_text) -> (list[(n:int, sid:str, rest:str)], list[(n:int, reason:str)])` — 문법 안 앵커와 거부 줄. 거부 사유: `anchor_indented`(열 0 이 아닌 공백 · 탭) · `anchor_unicode_space`(줄 머리가 `[^\S\n]` 중 공백 · 탭이 아닌 글자 — NBSP · U+3000 등) · `anchor_star_bullet`(`* `) · `anchor_shape`(`**S<n>**` 를 담았지만 문법 밖).
  - `decision_line_problem(line) -> Optional[str]` — 결정 줄 머리 판독: `^\s*\d+[.)]\s` → `decision_numbered`, `^\s*>` → `decision_quoted`.
  - `open_line_s_refs(section3_text) -> list[str]` — §3 산문 전체에서 `⟨S<n>⟩` 를 위치와 무관하게 전부 뽑는다.
  - `section4_items(section_text) -> list[(head, [cont])]` — `check_brief.section4_items` 의 규칙을 이리 옮긴다(펜스 제외 · 열 0 목록 머리 · 들여 쓴 이음 줄).
- Consumes: `section6.py`(§6 경계 — 그대로).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/spec-distill/tests/test_brief_body.py`:

```python
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import brief_body as B  # noqa: E402


class AnchorGrammar(unittest.TestCase):
    def test_accepts_column0(self):
        ok, bad = B.anchor_lines("- **S1** 「첫 말」\n- **S2** 「둘째」")
        self.assertEqual([s for _n, s, _r in ok], ["S1", "S2"])
        self.assertEqual(bad, [])

    def test_rejects_each_shape(self):
        cases = {
            "  - **S3** 「들임」": "anchor_indented",
            "\t- **S3** 「탭」": "anchor_indented",
            " - **S3** 「NBSP」": "anchor_unicode_space",
            "　- **S3** 「전각」": "anchor_unicode_space",
            "* **S3** 「별표」": "anchor_star_bullet",
            "-  **S3** 「공백 둘」": "anchor_shape",
            "1. **S3** 「번호」": "anchor_shape",
            "> - **S3** 「인용」": "anchor_shape",
        }
        for line, why in cases.items():
            ok, bad = B.anchor_lines(line)
            self.assertEqual(ok, [], line)
            self.assertEqual([r for _n, r in bad], [why], line)


class DecisionLines(unittest.TestCase):
    def test_numbered_and_quoted(self):
        self.assertEqual(B.decision_line_problem("1. [해결 ⟨S2⟩] — 정함"), "decision_numbered")
        self.assertEqual(B.decision_line_problem("> [해결 ⟨S2⟩] — 정함"), "decision_quoted")
        self.assertIsNone(B.decision_line_problem("- OQ1: 열림"))


class OpenLineRefs(unittest.TestCase):
    def test_all_refs_anywhere(self):
        self.assertEqual(B.open_line_s_refs("- OQ1: 가 ⟨S2⟩ 나\n  이어서 ⟨S5⟩ 끝 ⟨S2⟩"), ["S2", "S5", "S2"])


class Section4(unittest.TestCase):
    def test_fence_and_prose_not_items(self):
        txt = "- «a» 항목\n  이음\n산문 «b»\n```\n- «c»\n```\n- «d» 둘째"
        heads = [h for h, _c in B.section4_items(txt)]
        self.assertEqual(heads, ["- «a» 항목", "- «d» 둘째"])


if __name__ == "__main__":
    unittest.main()
```

기존 `check_brief` · `check_verbatim_coverage` 테스트 파일에 R2 잔여 넷의 회귀를 더한다(파일 이름은 `ls plugins/spec-distill/tests/ | grep -E 'check_brief|verbatim'` 로 찾는다):
- NBSP · U+3000 으로 들인 §6 앵커가 있는 payload → `check_brief gate` rc ≠ 0 이고 사유에 `anchor_unicode_space` · `check_verbatim_coverage` 도 같은 판독으로 rc 1.
- 열 0 이 아닌 `* **S3**` 앵커 → 둘 다 같은 사유.
- 번호 목록 · 인용 꼴 결정 줄이 §0 · §3 에 있는 brief → `check_brief gate` 가 `decision_numbered` · `decision_quoted` 로 rc ≠ 0.
- §3 열린 줄 산문 속 `⟨S99⟩`(§6 에 없는 id) → `check_brief gate` rc ≠ 0(`open_line_unknown_ref`).
- 두 판독기가 같은 모듈을 쓰는지: `test_brief_body.py` 에 `check_brief.ANCHOR_LINE_RE is brief_body.ANCHOR_LINE_RE` · `check_verbatim_coverage` 도 같은 객체인지 단언.

`test_roadmap_model.py` 에: §4 펜스 안 · 항목 밖 산문 줄의 `«key»` 를 `brief_universe` 가 세지 않는다.

`test_reviewing_brief_skill.sh` 에: 진입 게이트 펜스가 `vc_rc` 3(와 4 · 기타 non-zero)에서 `exit` 하고 「검사 없이 계속」 선택지를 안내하는 문장을 갖는다 · rc 표 :236 의 「record … 후 계속」 문면이 없다.

- [ ] **Step 2: 실패를 본다**

Run: `(cd plugins/spec-distill/tests && python3 -m unittest -q test_brief_body 2>&1 | tail -3)`
Expected: `ModuleNotFoundError: brief_body`.

- [ ] **Step 3: 모듈을 쓴다**

`plugins/spec-distill/scripts/brief_body.py`:

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""brief_body.py — brief 의 §6 앵커 줄 · 결정 줄 머리 · §3 열린 줄 참조 · §4 항목을 읽는 허용 문법 하나.

`check_brief` · `check_verbatim_coverage` · `roadmap_model` 이 함께 쓴다 — 판독기 셋이 같은 줄을 다르게 읽는 틈을
없앤다(`seed_body.py` 방식). 문법 밖 줄은 사유 이름과 함께 거부한다. 표준 라이브러리만 쓰고 파일을 읽지 않는다.
"""
from __future__ import annotations

import re

ANCHOR_LINE_RE = re.compile(r"^- \*\*(S\d+)\*\*(?: (.*))?$")
_ANCHOR_SHAPED = re.compile(r"\*\*S\d+\*\*")
_FENCE_RE = re.compile(r"^\s{0,3}(`{3,}|~{3,})")
S_REF_RE = re.compile(r"⟨(S\d+)⟩")


def _lead_ws_reason(line: str):
    i = 0
    while i < len(line) and line[i].isspace():
        i += 1
    if i == 0:
        return None
    return "anchor_indented" if set(line[:i]) <= {" ", "\t"} else "anchor_unicode_space"


def anchor_lines(section_text: str):
    ok, bad = [], []
    for n, line in enumerate(section_text.split("\n"), 1):
        if not _ANCHOR_SHAPED.search(line):
            continue
        m = ANCHOR_LINE_RE.match(line)
        if m:
            ok.append((n, m.group(1), m.group(2) or ""))
            continue
        why = _lead_ws_reason(line)
        if why is None:
            why = "anchor_star_bullet" if line.startswith("* **S") else "anchor_shape"
        bad.append((n, why))
    return ok, bad


def decision_line_problem(line: str):
    if re.match(r"^\s*\d{1,9}[.)]\s", line):
        return "decision_numbered"
    if re.match(r"^\s*>", line):
        return "decision_quoted"
    return None


def open_line_s_refs(section3_text: str):
    return S_REF_RE.findall(section3_text)


def section4_items(section_text: str):
    out, cur, fence = [], None, None
    for ln in section_text.split("\n"):
        fm = _FENCE_RE.match(ln)
        if fm:
            tok = fm.group(1)[0]
            fence = None if fence == tok else (fence or tok)
            cur = None
            continue
        if fence:
            continue
        if re.match(r"^[-*]\s", ln) and ln.strip() not in ("-", "*"):
            cur = (ln.strip(), [])
            out.append(cur)
        elif ln[:1].isspace():
            if cur is None:
                if re.match(r"^\s*[-*]\s", ln) and ln.strip() not in ("-", "*"):
                    cur = (ln.strip(), [])
                    out.append(cur)
            elif ln.strip():
                cur[1].append(ln.strip())
        else:
            cur = None
    return out
```

(이 함수는 `check_brief.py:241-252` 의 규칙을 옮긴 것이다 — `cur is None` 갈래의 조건은 원본 `ENTRY_BULLET_RE.match(ln) and …` 의 `…` 부분을 원본 파일에서 그대로 옮겨 맞춘다. 옮기기 전 · 후 결과가 레포의 실제 brief 전부에서 같은지 Step 4 에서 대조한다.)

- [ ] **Step 4: 세 판독기를 옮긴다**

- `check_brief.py`: `S_ANCHOR_RE` · `S_ANCHOR_NESTED_RE` 대신 `brief_body.anchor_lines` 를 쓴다 — `verbatim_anchors` · `payload_verbatim_anchors` 는 `ok` 의 sid 목록, `payload_verbatim_n1b_failures` 는 `bad` 를 사유와 함께 실패로 낸다. `section4_items` 는 `brief_body.section4_items(_section_text(...))` 로 위임(함수 이름은 남겨 바깥 호출부를 그대로 둔다). `_decision_line` 앞에서 `brief_body.decision_line_problem` 을 §0 · §3 의 모든 줄에 돌려 실패로 싣는다. `gate()` 에 §3 열린 줄 참조 검사를 더한다: `open_line_s_refs(§3)` 중 §6 앵커(payload ∪ audit)에 없는 id → `open_line_unknown_ref:<id>`. `ANCHOR_LINE_RE = brief_body.ANCHOR_LINE_RE` 로 이름을 다시 내보낸다(동일 객체 단언용).
- `check_verbatim_coverage.py`: `ITEM_RE` 를 `brief_body.ANCHOR_LINE_RE` 기반으로 바꾸고, `parse_section6` 가 `anchor_lines` 의 `bad` 를 `StructuralViolation`(rc 1)로 낸다.
- `roadmap_model.py`: `brief_universe` 의 `KEY_RE.findall(s4)` 를 `section4_items(s4)` 의 머리 · 이음 줄에서만 `KEY_RE` 로 센다(`from brief_body import section4_items` — 같은 scripts 폴더). `S_ANCHOR_RE`(:146)도 `ANCHOR_LINE_RE` 로.
- `roadmap_render._section4_index` 의 셋째 루프(한 줄 대체 경로)를 지운다 — 두 규칙이 같아졌으므로. 지운 뒤 `test_roadmap_render.py` 가 GREEN 인지 본다(RED 면 대체 경로가 아직 필요한 brief 가 있다는 뜻이다 — 지우지 말고 그 brief 와 사유를 계획 인계에 적는다).

대조(옮기기 전후 판독 결과가 같다): `git ls-files 'docs/superpowers/interview/*-interview.md'` 의 실제 brief 전부에 대해 옛 `check_brief` 의 앵커 목록 · §4 항목과 새 판독 결과를 비교하는 일회용 스크립트를 `$HOME/.claude/sdd-mirror/r2a-plan2/` 에 두고 돌린다. 다른 brief 가 있으면 그 줄이 「문법 밖이 맞다」(실제 우회 꼴)인지 「새 문법이 너무 좁다」인지 손으로 판정해 기록한다.

- [ ] **Step 5: rc 3 은 게이트를 막는다**

reviewing-brief SKILL.md :222-227 을:

```bash
vc_rc=0; python3 "$PR/scripts/check_verbatim_coverage.py" "$PAYLOAD" "$STATE" "$AUDIT" || vc_rc=$?
if [ "$vc_rc" -ne 0 ]; then
  drop_bundle || true
  if [ "$vc_rc" -eq 1 ]; then
    echo "[spec-distill] §6 원문 완전성 위반 — 이 라운드를 시작하지 않는다. …" >&2
  else
    echo "[spec-distill] 원문 완전성을 확인하지 못했다(check_verbatim_coverage rc $vc_rc) — 이 라운드를 시작하지 않는다. 사용자에게 「멈춘다 (권장)」 · 「검사 없이 계속」을 묻는다." >&2
  fi
  exit 1
fi
```

로 바꾸고, 펜스 뒤 문단에 「rc 가 1 이 아닌 non-zero 면 `AskUserQuestion` 하나 — 질문 「원문이 빠짐없이 옮겨졌는지 확인하지 못했다. 어떻게 할까?」, 선택지 「멈춘다 (권장)」(라운드를 시작하지 않고 끝낸다) · 「검사 없이 계속」(이 검사만 건너뛰고 리뷰를 시작한다). 계속을 고르면 audit `## 5` 의 `verbatim_coverage` · `completeness` 줄에 `skipped_by_user` 와 고른 선택지 이름을 적고 같은 펜스를 `SKIP_VC=1` 로 다시 돈다(펜스는 `SKIP_VC=1` 이면 이 검사만 건너뛴다)」를 더한다. rc 표 :236-238 을 「막는다 — 사용자가 고르면 계속」으로 고친다. finishing.md :97 · :101 · spec-interview SKILL.md :160 의 「공시하고 계속」 문면도 같은 사실로 고친다(R10 예약 파일 — 문면 한 줄만).

- [ ] **Step 6: 통과 · 커밋**

Run: `(cd plugins/spec-distill/tests && for m in test_brief_body $(ls test_check_brief*.py test_*verbatim*.py test_roadmap_model.py test_roadmap_render.py 2>/dev/null | sed 's/\.py$//'); do python3 -m unittest -q "$m" 2>&1 | tail -1; done); bash plugins/spec-distill/tests/test_reviewing_brief_skill.sh 2>&1 | tail -2; bash plugins/spec-distill/tests/test_roadmap_status.sh 2>&1 | tail -2`
Expected: 모두 OK · Fail 0.

```bash
git add plugins/spec-distill/scripts/brief_body.py plugins/spec-distill/tests/test_brief_body.py
git commit -m "fix(spec-distill): brief 판독기를 허용 문법 하나로 — 원문 확인 실패는 게이트를 막는다" -- plugins/spec-distill/scripts/brief_body.py plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/scripts/check_verbatim_coverage.py plugins/spec-distill/scripts/roadmap_model.py plugins/spec-distill/scripts/roadmap_render.py plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/skills/spec-interview/references/finishing.md plugins/spec-distill/skills/spec-interview/SKILL.md plugins/spec-distill/tests
```

---

### Task 11: 실제 파서 교차 확인 — markdown-it-py (AC19)

**Files:**
- Modify: `pyproject.toml` (`[dependency-groups] dev` 에 `markdown-it-py`) · `uv.lock`
- Create: `plugins/spec-distill/tests/test_grammar_vs_markdown_it.py`
- Create: `plugins/spec-distill/tests/test_grammar_vs_markdown_it.sh` (100755 — uv 가 있으면 `uv run`, 없으면 `python3`)

**Interfaces:**
- Consumes: Task 10 `brief_body.anchor_lines` · `decision_line_problem` · `section4_items`, `seed_body.parse_seed`.

- [ ] **Step 1: 의존을 고정한다(사용자 검토 뒤 — 설계 B2 승인)**

`pyproject.toml`:

```toml
[dependency-groups]
dev = ["pyyaml", "markdown-it-py==4.2.0"]
```

Run: `uv lock` 후 `git diff --stat uv.lock` — `markdown-it-py 4.2.0` 과 `mdurl` 이 더해졌는지 본다. 네트워크가 없으면 멈추고 그 사실을 인계에 적는다(손으로 `uv.lock` 을 쓰지 않는다).

- [ ] **Step 2: 교차 확인 테스트를 쓴다**

`test_grammar_vs_markdown_it.py`:

```python
"""우리 허용 문법이 앵커 · 결정 줄 · 목록이라고 본 줄과 markdown-it-py 토큰이 같은지 잰다(AC19).
파서가 없으면 통과가 아니라 「확인 못 함」 — rc 3."""
import subprocess
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "scripts"))
try:
    from markdown_it import MarkdownIt
except ImportError:  # pragma: no cover
    print("확인 못 함(markdown-it-py 없음) — uv sync 로 개발 의존을 받은 뒤 다시 돌린다")
    sys.exit(3)
import brief_body as B  # noqa: E402

MD = MarkdownIt("commonmark")
REPO = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], cwd=HERE, text=True).strip())


def top_level_list_item_lines(text):
    """최상위(중첩 0) 글머리 목록 항목이 시작하는 줄 번호(1부터) — 코드 · 인용 · 들인 블록 안은 빠진다."""
    out, depth = set(), 0
    for t in MD.parse(text):
        if t.type in ("bullet_list_open", "ordered_list_open", "blockquote_open"):
            depth += 1
        elif t.type in ("bullet_list_close", "ordered_list_close", "blockquote_close"):
            depth -= 1
        elif t.type == "list_item_open" and depth == 1 and t.markup == "-" and t.map:
            out.add(t.map[0] + 1)
    return out


BYPASSES = [   # R2 「알려진 우회」 꼴 — 우리 문법이 거부하는 줄은 파서도 최상위 «-» 항목으로 보지 않아야 한다
    "  - **S3** 「들임」", " - **S3** 「NBSP」", "　- **S3** 「전각」", "* **S3** 「별표」",
    "1. **S3** 「번호」", "> - **S3** 「인용」", "    - **S3** 「코드 블록」",
]


class CrossCheck(unittest.TestCase):
    def test_bypass_cases(self):
        for line in BYPASSES:
            ok, bad = B.anchor_lines(line)
            items = top_level_list_item_lines(line + "\n")
            self.assertEqual(ok, [], line)
            self.assertNotIn(1, items, "파서는 최상위 «-» 항목으로 보는데 우리는 거부했다 — 문법이 너무 좁다: %r" % line)

    def test_real_briefs(self):
        paths = subprocess.check_output(["git", "ls-files", "docs/superpowers/interview/*-interview.md"],
                                        cwd=REPO, text=True).split()
        self.assertGreater(len(paths), 0, "실제 brief 가 하나도 없다 — 코퍼스가 비면 이 락은 공허하다")
        for p in paths:
            text = (REPO / p).read_text(encoding="utf-8")
            ok, _bad = B.anchor_lines(text)
            ours = {n for n, _s, _r in ok}
            items = top_level_list_item_lines(text)
            self.assertTrue(ours <= items, "%s: 우리가 앵커라 본 줄 %s 를 파서는 최상위 목록 항목으로 보지 않는다" % (p, sorted(ours - items)))


if __name__ == "__main__":
    unittest.main()
```

(같은 꼴로 seed 코퍼스 — `git ls-files 'docs/superpowers/interview/*-seed.md'` — 에 `seed_body.parse_seed` 의 `rejected` 줄 중 파서가 목록 · 코드 · 인용으로 보는 줄이 있는지 · 없는지를 잰다. 우리 문법은 seed 를 산문만 허용하므로 「파서가 목록 · 제목 · 코드라고 본 줄 ⊆ 우리가 거부한 줄」이 통과 조건이다.)

`test_grammar_vs_markdown_it.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/brief_body.py plugins/spec-distill/scripts/seed_body.py pyproject.toml uv.lock
# AC19 — 허용 문법과 markdown-it-py 토큰의 교차 확인. 파서가 없으면 「확인 못 함」 rc 3.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
if command -v uv >/dev/null 2>&1; then
  ( cd "$HERE" && uv run --frozen --group dev python -m unittest -q test_grammar_vs_markdown_it )
else
  ( cd "$HERE" && python3 -m unittest -q test_grammar_vs_markdown_it )
fi
```

- [ ] **Step 3: 돌려 본다**

Run: `chmod +x plugins/spec-distill/tests/test_grammar_vs_markdown_it.sh; bash plugins/spec-distill/tests/test_grammar_vs_markdown_it.sh; echo rc=$?`
Expected: uv 가 있으면 OK rc 0. 시스템 `python3` 만으로 돌리면 「확인 못 함(markdown-it-py 없음)」 rc 3(양성 대조 — 파서가 없을 때 통과로 새지 않는다).

- [ ] **Step 4: 커밋**

```bash
git add plugins/spec-distill/tests/test_grammar_vs_markdown_it.py plugins/spec-distill/tests/test_grammar_vs_markdown_it.sh
git commit -m "test(spec-distill): 허용 문법을 markdown-it-py 토큰과 교차 확인(개발 의존)" -- pyproject.toml uv.lock plugins/spec-distill/tests/test_grammar_vs_markdown_it.py plugins/spec-distill/tests/test_grammar_vs_markdown_it.sh
```

---

### Task 12: R2 「알려진 우회」 나머지 — 재현 · 닫음 · 변이 표 (AC20)

**Files:**
- Modify: `plugins/spec-distill/scripts/check_seed.py` (frontmatter 문법) · `seed_provenance.py` (`## 2` 줄 허용 목록 · `verbatim_units` 의 `## 1`) · `seed_body.py` (인라인 코드 안 `##` · 확인 표시 변형 · 문자 참조 · `mailto:` · 맨 도메인) · `seed_review_log.py` (`append-verbatim --section` 검사) · `check_brief.py` (audit H1~H3)
- Create: `plugins/spec-distill/tests/test_r2_bypass_residue.py`
- Create: `$HOME/.claude/sdd-mirror/r2a-plan2/bypass-table.md` (PR 본문에 옮길 표)
- Modify: 설계문서 `## 미룸` (닫지 못한 것)

**Interfaces:**
- Consumes: `seed_body.line_problem` · `parse_seed` 의 허용 문법 방식.

- [ ] **Step 1: 우회마다 재현 테스트를 쓴다(RED 여야 한다)**

`test_r2_bypass_residue.py` — 우회 하나에 테스트 하나, 이름은 우회 이름. 각 테스트는 **허용 문법의 부정형**으로 꼴을 고른다(추가 · 반전 · 형태 변경 — 한 꼴만 막고 이웃 꼴이 새지 않게):

| 테스트 | 우회(PR #217 원문) | 재현 입력 | 닫는 규칙(허용 문법) |
|---|---|---|---|
| `test_seed_frontmatter_grammar` | seed frontmatter 는 문법 밖이다. URL · `##` · 앵커 모양 줄이 `check_seed` 를 통과한다 | frontmatter 에 `note: https://x.y` · `## 3` · `- **S1**` 줄 | frontmatter 는 `키: 값` 줄만 — 키 `[a-z_]+`, 값은 `seed_body.line_problem` 을 지나는 한 줄. 그 밖은 `frontmatter_line` |
| `test_seed_section2_line_allowlist` | `## 2` 에 줄 단위 허용 목록이 없다. 여러 줄 사용자 답이나 lone CR 로 「고름」 풀이 줄을 위조 | `## 2` 에 `\r- 고름: …` · 두 줄 답 | `## 2` 줄은 `- 내가 읽은 것: 「…」 …` · `- 고름: …` · 빈 줄만. CR 등 줄 구분자는 `seed_review_log.to_newlines` 로 먼저 쪼개 판정 |
| `test_inline_code_heading` | 인라인 코드 안의 `##` 는 막지 않는다 | 산문 줄 `` `## 6` `` | `seed_body.line_problem` 이 백틱 안도 같은 규칙으로 본다(인라인 코드 면제 없음 — 이미 docstring) — 재현이 GREEN 이면 「이미 닫힘」으로 표에 적는다 |
| `test_append_verbatim_section_checked` | `append-verbatim --section` 값을 검사하지 않는다 | `--section '## 9. 없음'` | `--section` 은 `AUDIT_HEADINGS` 중 하나여야 한다 — 아니면 rc 2 `section_unknown` |
| `test_audit_template_h1_h3` | 실제 템플릿 제목이 빠진 audit 의 H1~H3 | 제목 셋이 빠진 audit | `check_brief` 가 audit 의 H1~H3 을 템플릿 제목 목록과 대조 — 빠지면 `audit_heading_missing` |
| `test_confirmation_mark_variants` | 문구가 다른 확인 표시 변형 | `(사용자 확인 완료)` · `(사용자확인)` | 확인 표시와 닮은 괄호(`사용자` + `확인` 을 담은 괄호)는 정확히 `(사용자 확인)` 이 아니면 `mark_variant` 로 거부 |
| `test_char_refs_mailto_bare_domain` | 문자 참조(`&#91;`), `mailto:`, 맨 도메인 | `&#91;S1&#93;` · `mailto:a@b.c` · `example.com/x` | `&#…;` · `&[a-z]+;` 거부, URL 스킴 목록에 `mailto:`, 맨 도메인 `\b[a-z0-9-]+(\.[a-z0-9-]+)+/` 거부 |
| `test_quote_file_written_by_model` | `--quote-file` 은 모델이 쓴다 | — | 판독기 방식으로 닫을 수 없다(파일 출처의 문제) → `## 미룸` |
| `test_verbatim_units_section1` | `verbatim_units` 가 audit `## 1` 을 따로 나눈다 | `## 1` 단락 | `verbatim_units` 가 seed `## 1` 과 같은 나눔 규칙(문단)만 쓴다 — 라벨 차이를 없앤다 |

(Task 10 이 닫은 brief 쪽 넷 · Task 7 의 `_log_line` · Task 8 의 AC8 꼴 다섯은 이 표에 「Task N 에서 닫힘」 행으로 함께 적는다 — 표는 PR #217 목록 전부를 덮는다.)

- [ ] **Step 2: 하나씩 닫는다(테스트 하나 → 규칙 하나 → 그 테스트 GREEN → 나머지 스위트 GREEN)**

각 규칙은 위 표의 「닫는 규칙」 칸 그대로 구현한다. 새 거부 사유 이름은 고정 문자열이고 사용자 원문을 출력에 싣지 않는다(`seed_body.rejected_lines_message` 처럼 줄 번호만).

- [ ] **Step 3: 변이로 잰다**

닫은 규칙마다 그 규칙 줄을 지운 작업 트리에서 해당 테스트가 RED 인지 확인하고, `bypass-table.md` 에 「재현(RED) · 닫음(GREEN) · 변이(RED)」 세 칸을 채운다. 양성 대조: 각 테스트 파일에 「문법 안의 정상 seed · brief 는 통과」 케이스 하나씩.

- [ ] **Step 4: 닫지 못한 것을 `## 미룸` 에**

`--quote-file` 출처 행: 이유 「모델이 쓰는 파일의 출처는 판독기 방식으로 가를 수 없다 — 내용이 아니라 작성 주체의 문제다(AC17 가 와 같은 권한 경계 축)」 · 받는 곳은 설계에 없던 결정 8 과 같은 곳.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/tests/test_r2_bypass_residue.py
git commit -m "fix(spec-distill): R2 가 넘긴 seed · audit 우회를 허용 문법으로 닫음" -- plugins/spec-distill/scripts/check_seed.py plugins/spec-distill/scripts/seed_provenance.py plugins/spec-distill/scripts/seed_body.py plugins/spec-distill/scripts/seed_review_log.py plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/tests/test_r2_bypass_residue.py docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md
```

---

### Task 13: 버전 · CHANGELOG · README · 보안 리뷰 · 끝 검증 (AC20 · AC41 의 보안 리뷰 · AC36 · AC37)

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` (7.2.1 → 7.3.0 임시) · `plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/README.md`
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` (14.0.0 → 14.0.1 임시) · `plugins/quality-gates/CHANGELOG.md`
- Modify: 설계문서 `## 미룸` 의 계획 1 넘김 행 둘(라우터 합침의 남은 빈틈 · 같은 이름 블록 락 보강 — 이 계획이 같은 경로를 고쳤으면 「끝냄: <커밋>」, 아니면 그대로)

- [ ] **Step 1: CHANGELOG · README**

spec-distill `## [7.3.0] — <머지 날짜>`: Added(`declare-related` · `related-changes` · `advice-list` · `brief_body.py` · 엔진 값 넷과 환경 변수 넷 · `begin-round --detectors` · `--extra-approval-source` · 지적 필드 `contradicts` · 원장 확인값) · Changed(탐지 리뷰어 여럿 · 게이트 첫 줄 열린 지적 수 · 승인 선택지 이름 · 추가 라운드 승인 출처 · `advice` 는 쓰기 플래그 필수 · 원문 확인 실패는 게이트를 막음) · Security(결정 줄 한 줄 문법 · 원장 쓰기 락 원인 치우기 · brief 판독기 하나 · seed 우회 닫음 · 줄인 플래그 거부) · Fixed(브리프 §6 덧붙이기 허용). README 에 환경 변수 넷과 기본값 · 출처 공시를 「설정」 절로, `Principles Instantiated` 에 「Law 1 — 허용 문법 판독기(brief_body)」 한 줄. quality-gates `## [14.0.1]` Changed: 공유 엔진 링크(같은 바이트)가 위 변경을 싣는다.

- [ ] **Step 2: 보안 리뷰(따로 한 번)**

입력: `git diff <기준 커밋>..HEAD -- shared/docreview/agents plugins/spec-distill/agents shared/docreview/scripts/run_docreview_codex_reviewer.sh plugins/spec-distill/references/docreview-profiles shared/docreview/scripts/docreview_state.py shared/docreview/scripts/docreview_route.py plugins/spec-distill/scripts plugins/spec-distill/tests/test_ledger_wiring.sh`. `quality-gates:security-reviewer` 를 그 diff 와 「약화가 아니라 필드 · 규칙 추가 — 판단 근거: (1) persona 에 `contradicts` 필드와 첫 줄 쉬운 말 규칙 · `related_changes` 선택 슬롯만 더했고 `tools:` · 데이터/지시 경계 문장은 그대로 (2) 원장 쓰기 락은 꼴 판별을 지우고 이름 허용 목록 + 넘기기 전면 거부로 좁혔다 (3) brief · seed 판독은 문법 밖을 거부하는 쪽으로만 바뀌었다」를 함께 넘겨 dispatch 한다:

```
Agent({
  description: "Security review of R2a plan 2 persona and residue diff",
  subagent_type: "quality-gates:security-reviewer",
  // **처분** — consumer=orchestrator · fail-closed · disclosure=PR 본문 「보안 리뷰」 절
  prompt: "<diff>${DIFF}</diff> <rationale>${RATIONALE}</rationale>"
})
```

결과를 `$HOME/.claude/sdd-mirror/r2a-plan2/security-review.md` 에 원문 그대로 두고, 차단 지적이 있으면 그 Task 로 돌아가 고친 뒤 **다시 리뷰한다**(락 · 보안 · persona 수정은 매번 재리뷰). PR 본문 「보안 리뷰」 절(지휘자가 쓴다)에 옮길 요약과 판단 근거를 인계에 적는다.

- [ ] **Step 3: 끝 스위트 대조(AC36)**

Task 0 의 스크립트로 `after` 를 재고 `comm -13 <(cut -f1,2 before.names | sort -u) <(cut -f1,2 after.names | sort -u)` 가 빈지 본다(새 실패 «이름» 0). 기준선 이후 origin 기본 브랜치가 움직였으면 버릴 clone 에서 새 base 기준선을 다시 재고 그것과 비교한다. 동시에 두 스위트를 돌리지 않는다.

- [ ] **Step 4: 끝 대조 보고**

`python3 plugins/spec-distill/scripts/check_bundle_coverage.py --plan docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md docs/superpowers/plans/2026-10-18-r2a-plan2-shared-engine-security.md --acs "AC10~AC20 · AC38~AC41"` 이 「빠진 AC 없음」이고, AC 보고 파일(`AC<n>: 구현됨|미룸|빠짐 — <근거>`)을 `$HOME/.claude/sdd-mirror/r2a-plan2/ac-report.md` 에 쓴다(지휘자의 `--impl` 대조 입력). §1 처분표에서 계획 2 행(재리뷰 상한 · 게이트 · 조언 접기 · 탐지 1명 · 라벨 압축)이 각각 어느 AC 로 닫혔는지 보고에 적는다(AC37).

- [ ] **Step 5: 커밋**

```bash
git commit -m "chore(spec-distill): R2a 계획 2 — 버전 · CHANGELOG · README" -- plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md
```

인계에 적는다: 버전 번호는 머지 직전에 다시 확인 · R10 담당(지휘자)에게 brief 판독기 허용 문법(`brief_body.ANCHOR_LINE_RE` — 열 0 `- **S<n>**`)을 알린다(설계 §7) · 보안 리뷰 결과 · `## 미룸` 에 더한 행.
