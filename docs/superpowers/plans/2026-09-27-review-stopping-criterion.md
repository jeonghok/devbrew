# 리뷰 멈춤 기준 — must-catch 축과 참고 축 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 공유 문서 리뷰 엔진이 프로필의 `must_catch` 축만으로 승인을 막고, 나머지 rubric 축은 `advice` 원장으로 보내 끝에서 한 번 보인다. 한 번 보일 때 하류가 읽는 자리에 박제하고, 라운드별 계수를 커밋되는 문서에 남긴다.

**Architecture:** 판정 코드는 새 leaf 모듈 `shared/docreview/scripts/docreview_advice.py` 에 둔다. 이 모듈은 순수 함수만 갖고 I/O 도 형제 import 도 없다. `docreview_route.py` 는 두 걸음 표지를 호출만 한다. 1 걸음은 `_classify_items` 끝, 2 걸음은 `_resolve_ids_and_lineage` 뒤다. `docreview_state.py` 는 네 가지를 맡는다: `advice` 원장 기록, 게이트 참고 줄, `advice` 서브커맨드(모듈을 지연 import), 프로필 스키마. 승인 술어(`approval_ready`·`GATE_ROWS`)는 한 글자도 바꾸지 않는다. 필드 없는 프로필(qg `generic`)의 출력은 바이트 단위로 현행이고, 골든 12파일이 이를 잰다.

**Tech Stack:** Python 3.9(시스템 python — `from __future__ import annotations`), PyYAML, bash 3.2 셸 락(`shared/tests/assert.sh`), 변이 매트릭스(`shared/tests/test_docreview_mutations.sh`).

**Spec:** `docs/superpowers/specs/2026-09-27-review-stopping-criterion-design.md` (브랜치 `feature/review-stopping-criterion`, 설계 커밋 5d46bf0f). 실행자는 이 계획과 설계문서를 함께 읽는다.

## 목차

- [Global Constraints](#global-constraints)
- [Review Focus](#review-focus)
- [설계 대비 이 계획이 정한 것](#설계-대비-이-계획이-정한-것)
- [File Structure](#file-structure)
- [Task 0: 착수 전 baseline](#task-0-착수-전-baseline)
- [Task 1: 테스트 하네스 — 필드 없는 사본 프로필과 골든 12파일](#task-1-테스트-하네스--필드-없는-사본-프로필과-골든-12파일)
- [Task 2: 프로필 스키마 — `must_catch` 선택 필드 (AC4)](#task-2-프로필-스키마--must_catch-선택-필드-ac4)
- [Task 3: 세 프로필 값 · 펜스의 `must_catch` 벗기기 (AC16)](#task-3-세-프로필-값--펜스의-must_catch-벗기기-ac16)
- [Task 4: `docreview_advice.py` 모듈 · 배포 링크 (§A)](#task-4-docreview_advicepy-모듈--배포-링크-a)
- [Task 5: 1 걸음 표지 · advice 원장 · 계수 · 참고 줄 (AC1·AC3·AC5·AC9·AC13·AC19)](#task-5-1-걸음-표지--advice-원장--계수--참고-줄-ac1ac3ac5ac9ac13ac19)
- [Task 6: 병합 생존자 · 2 걸음 표지 (AC2·AC8·AC13·AC14·AC15·AC18)](#task-6-병합-생존자--2-걸음-표지-ac2ac8ac13ac14ac15ac18)
- [Task 7: `advice` 서브커맨드 — 한 번 표시 · 박제 · 계수 줄 (AC6·AC7·AC17)](#task-7-advice-서브커맨드--한-번-표시--박제--계수-줄-ac6ac7ac17)
- [Task 8: 번들 위생 regex 를 자기 audit 으로 (AC10)](#task-8-번들-위생-regex-를-자기-audit-으로-ac10)
- [Task 9: 절차서 · 진입 skill 문면 (AC11)](#task-9-절차서--진입-skill-문면-ac11)
- [Task 10: 버전 · CHANGELOG · README · 최종 재측정 (AC12)](#task-10-버전--changelog--readme--최종-재측정-ac12)
- [Self-Review 기록](#self-review-기록)

## Global Constraints

- **Korean-primary.** 산문 · 주석 · 테스트 메시지는 한국어로 쓴다. 영어는 식별자 · 고유명사 · 원문 인용만 쓴다.
- **커밋.** Conventional Commits `<type>(<scope>): <description>` 형식을 쓰고, 메시지 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` 를 붙인다. `git add` 는 **pathspec** 으로만 한다(`git add -A` 금지). 커밋 직후 `git status --porcelain` 이 이 태스크 밖의 변경을 담지 않았는지 확인한다.
- **Python 3.9.** 새 `.py` 는 `from __future__ import annotations` 로 시작한다. `match` 문과 런타임 `X | None` 을 쓰지 않는다. 파일 I/O 는 전부 `encoding="utf-8"` 을 명시한다(`plugins/quality-gates/tests/test_utf8_explicit.py` 가 `plugins/*/scripts/*.py` 를 잰다).
- **bash 3.2.**
  - `mapfile` 을 쓰지 않는다.
  - `set -u` 아래 빈 배열 확장을 쓰지 않는다.
  - `$var` 바로 뒤에 한글이 오면 `${var}` 로 감싼다.
  - 셸 테스트는 리포 루트에서 `bash <경로>` 로 돌린다. Bash 도구 셸은 zsh 라 `PIPESTATUS` 가 비고 `echo ===` 가 깨진다 — 파이프 rc 가 필요하면 `bash -c` 안에서 잡는다.
- **변이 · 캐시.** 변이 실행에는 `PYTHONDONTWRITEBYTECODE=1` 을 준다. 손 변이는 **먼저 커밋한 뒤** 하고, 복원은 `git checkout HEAD -- <파일>` 로 한 뒤 `git diff HEAD` 가 비었는지 확인한다.
- **qg 바이트 동일(G5·AC3).** `must_catch` 가 없는 프로필의 finalize 보고서 · 원장 파일 · `gate` JSON · `gate --render` 는 바이트 단위로 현행이다. 새 키 · 새 원장 키(`advice`) · 새 렌더 줄은 **필드를 지목한 프로필에서만** 생긴다 — `_empty()` 에 `advice` 를 넣지 않는다.
- **처분 회계 락(`tools/adjudication/check_wiring.py`).**
  - `docreview_route.py` 는 이 락의 모집단이다.
  - 그 파일에 **컴프리헨션을 하나도 더하지 않는다** — 현재 `comprehensions=40` 이고 baseline 도 40 이다. 필요한 컴프리헨션은 `docreview_advice.py` 에 둔다. 이 모듈은 `adjudication` 을 import 하지 않아 모집단 밖이다.
  - route.py 의 `for` 문 안에 `continue`·`break`·`return` 을 새로 두지 않는다.
  - route.py 에 줄을 더하면 `EXEMPT` 키의 **줄번호만** 재앵커한다. 가드 텍스트와 사유는 무변경이다.
- **변이 앵커 보존.** `test_docreview_mutations.sh` 의 기존 셀이 sed 로 쥔 줄은 글자를 바꾸지 않는다. 확인된 것은 `keep = max(live, key=lambda m: (RANK[items[m]["disposition"]], m))` 하나다. 줄을 더하는 것은 괜찮다.
- **SKILL.md 본문의 `$0`~`$9`.** Skill 인자로 치환되므로 skill 펜스에서 awk 필드(`$0`·`$1`)를 쓰지 않는다. sed 를 쓴다.
- **버전.** spec-distill `4.4.0 → 4.5.0`(minor — 새 표면 `advice`)이고 quality-gates `9.2.0 → 9.2.1`(patch — 공유 스크립트 배포분)이다. 번호는 **머지 직전에** `origin/main` 을 다시 보고 확정한다.
- **모델.** subagent 에 `fable` 을 쓰지 않는다(최종 리뷰 포함 opus).

## Review Focus

설계가 함의하지만 어떤 AC 의 테스트도 걸지 않는 입력 다섯 가지다. 각 줄의 테스트는 해당 태스크에 넣었다.

1. **업그레이드 전 원장**(`advice` 키 없음 · `route_report` 에 계수 키 없음)에서 `gate --render` · `advice --render` · `advice --log-file` 를 부른다. 기대: 죽지 않는다 — `참고(advisory) 0건`, 계수 줄 0, 참고 줄 없음. → Task 7 `case_advice_pre_upgrade_ledger`.
2. **요약 · 대체안에 `|` · 개행 · 60자 넘는 문장이 든 항목.** 기대: 렌더 항목 줄은 한 줄이고 `…` 로 끝나며, 박제 표 행도 한 줄이고 `|` 가 `\|` 로 이스케이프된다. → Task 7 `case_advice_odd_text_one_line`.
3. **같은 흐름을 다시 돈다**(③ 수정 뒤 재진입 · 2단계 재표시). 기대: 두 번째 `--render` 는 `0건`이고 새 항목만 낸다. → Task 7 `case_advice_render_once`.
4. **`blocks` 가 없는 f(오타 · 기각된 항목)를 가리키는 `ask`.** 기대: advisory ask 는 advice 로 가고, must-catch ask 는 asks 에 남으며, 강제 계수가 늘지 않고, 죽지 않는다. → Task 6 `case_advice_dangling_blocks`.
5. **frontmatter 에 `audit_file` 이 없는 brief payload 를 readback 블롭으로 만든다.** 기대: 넓은 판정(`*.audit.md` 전부)으로 닫힌다(fail-closed, rc 3). → Task 8 T24c.

## 설계 대비 이 계획이 정한 것

설계의 `### Deferred to plan` 세 항목과, 구현하면서 드러난 문면 모호 둘을 여기서 정한다. 사용자 보고 대상이다.

| 항목 | 정한 것 | 근거 |
|---|---|---|
| 렌더 항목 줄의 폭 · 절단(Deferred) | 공백을 한 칸으로 접고, 요약이 60 코드포인트를 넘으면 59자 + `…` | 한 줄 유지(≤10줄 ⟨D9⟩) |
| brief §3 / §5 판단 문면(Deferred) | 「이 brief 를 넘기기 전에 사용자가 고를 것이 있는가 — 있으면 §3 OQ(+§0 결정 목록), 없으면 §5 위험」. 줄 모양은 Task 9 에 적는다 | `check_brief.py` 는 §0↔§3 을 선두 `OQ<n>` 로 읽고, §5 위험 줄의 종류 어휘는 검사하지 않는다(실측) |
| 회계 모듈에서 advice 를 세는 자리(Deferred) | 새 카운터를 두지 않는다. advice 항목도 `L.accept` 를 지나고, AC8 등식은 보고서 키(`advice_new`+`advice_repeat`)와 `by_disposition` 으로 선다 | Ledger 어휘를 늘리면 `check_consumed` L2 가 새 소비 자리를 요구한다 |
| 리뷰 정체의 모양(§E 문면 모호) | `<세션>/<문서 키>`(`state_dir` 의 조부 이름 `/` 자기 이름) | 설계는 「세션 + 문서 해시 — `state-dir-for` 의 마지막 경로 조각」이라 쓰지만 마지막 조각(`<이름표>-<해시>`)에는 세션이 없다. D3.18 의 의도(다른 세션의 재리뷰를 가른다)를 따른다 |
| `advice` 서브커맨드 표면 | 설계의 `--render --cap --sink --log-file` 에 더해 **플래그 없음 = JSON 읽기**(brief Step B 가 §3/§5 를 쓸 원료)와 `--where <박제처 라벨>`(brief 의 접는 줄이 「§3 · §5」를 가리키게)을 둔다. 필드 없는 프로필은 `profile_has_no_must_catch` rc 1 이다 | brief 는 `defer_target: none` 이라 엔진이 박제처 이름을 모른다 |

## File Structure

| 파일 | 책임 | 태스크 |
|---|---|---|
| `shared/docreview/scripts/docreview_advice.py` (신규) | advisory 축 · 두 걸음 표지 · 병합 소속 · 관측 계수 · 렌더 · 박제 행 · 계수 줄 — 순수 함수 | 4·5·6·7 |
| `plugins/{spec-distill,quality-gates}/scripts/docreview_advice.py` (신규 심볼릭 링크) | 배포 지점. qg 의 `recritic_bridge.py` 가 route.py 를 import 하므로 qg 에도 있어야 한다 | 4 |
| `shared/docreview/scripts/docreview_state.py` | `OPTIONAL_PROFILE_FIELDS` · `must_catch` 스키마 · `_record_advice` · 게이트 참고 줄 · `cmd_advice` | 2·5·7 |
| `shared/docreview/scripts/docreview_route.py` | 표지 두 걸음 호출 · 병합 소속 한 줄 · 보고서 키 | 5·6 |
| `tools/adjudication/check_wiring.py` | `EXEMPT` 줄번호 재앵커(route.py 줄 이동분) | 5·6 |
| `plugins/spec-distill/references/docreview-profiles/{brief,design-doc,seed}.md` | frontmatter `must_catch:` 한 줄씩 | 3 |
| `plugins/spec-distill/skills/{reviewing-brief,reviewing-spec,framing-requests}/SKILL.md` | profile-content 펜스가 `must_catch:` 를 벗긴다. framing-requests 에 마커를 더한다 | 3 |
| `plugins/spec-distill/skills/reviewing-spec/SKILL.md` | 승인 게이트 2단계 앞 `advice` 표시 · 박제 · 계수 | 9 |
| `plugins/spec-distill/skills/reviewing-brief/SKILL.md` | 「참고 목록은 Step B 가 보인다」 한 줄 | 9 |
| `plugins/spec-distill/skills/framing-requests/SKILL.md` | 게이트 직전 계수 기록(`advice --log-file`) | 9 |
| `plugins/spec-distill/skills/conducting-interview/references/finishing.md` | Step B `#### B-A` 참고 목록 · §3/§5 박제, B-2 문장 정정 | 9 |
| `shared/docreview/references/reviewing-document.md` | 7·8단계 advice 분기와 `advice` 계약 | 9 |
| `plugins/spec-distill/scripts/build_brief_bundle.py` · `build_brief_inline_blob.py` | 위생 판정을 자기 audit basename 으로 | 8 |
| `shared/tests/fixtures/docreview/nofield_profiles.sh` · `strip_must_catch.py` (신규) | 필드 없는 사본 프로필 디렉토리(내용 해시 캐시) | 1 |
| `shared/tests/fixtures/docreview/cases.sh` | `PROF_SD` 를 사본으로 | 1 |
| `shared/tests/fixtures/docreview/capture_finalize_golden.sh` · `golden/*` | 사본 경로 정규화 · `gate.json`·`gate.txt` 캡처 · 골든 12파일 | 1 |
| `shared/tests/test_docreview_golden.sh` | 네 산출물 × 세 케이스 · 하한 12 | 1 |
| `shared/tests/fixtures/docreview/cases_advice.sh` (신규) | 참고 라우팅 케이스(실제 프로필) | 4~7 |
| `shared/tests/test_docreview_advice.sh` (신규) | 위 케이스를 부르는 행동 락 | 4~7 |
| `shared/tests/fixtures/docreview/{mk_advice_critic.py,ac8_terms.py}` · critic/recritic 픽스처 11개 · `design-sample-child.md` (신규) | 입력 | 5~7 |
| `shared/tests/test_docreview_mutations.sh` | `run_case` 가 `cases_advice.sh` 도 source · 셀 (61)~(73) | 5·6·7 |
| `shared/tests/test_docreview_profile_schema.sh` | ⑤ must_catch 스키마 | 2 |
| `shared/tests/test_docreview_codex.sh` | 코퍼스 루프에 「프롬프트에 must_catch 없음」 | 3 |
| `plugins/spec-distill/tests/test_dispatch_profile_inline.sh` | S 셀 — 세 자리 벗기기(AC16) | 3 |
| `plugins/spec-distill/tests/test_brief_bundle.sh` · `test_brief_inline_blob.sh` | AC10 | 8 |
| `shared/tests/test_docreview_advice_procedure.sh` (신규) | AC11 — 문면이 부르는 플래그가 실재 | 9 |
| `plugins/{spec-distill,quality-gates}/.claude-plugin/plugin.json` · `CHANGELOG.md` · spec-distill `README.md` | 버전 · 기록 · Principles Instantiated 한 줄 | 10 |

---

### Task 0: 착수 전 baseline

**Files:**
- Create(git 밖): `.superpowers/sdd/2026-09-27-review-stopping-criterion/{run_suite.sh,compare_suite.sh,baseline.tsv}` — `.superpowers/sdd/` 는 ignore 된다. 세션 재개에 사라질 수 있으므로 `~/.claude/sdd-mirror/2026-09-27-review-stopping-criterion/` 로 사본을 둔다.

**Interfaces:**
- Produces: `baseline.tsv` — 행마다 `<테스트 경로>\t<rc>\t<실패 줄 수>`. Task 10 이 같은 스크립트로 head 를 재고 `compare_suite.sh` 로 비교한다.

- [ ] **Step 1: 브랜치 · base 이동량 확인**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git status --porcelain            # 비어 있어야 한다
git rev-parse --abbrev-ref HEAD   # feature/review-stopping-criterion
git fetch -q origin && git log --oneline HEAD..origin/main | wc -l
```
Expected: 깨끗한 트리. `HEAD..origin/main` 이 0 이 아니면 `git merge-tree $(git merge-base HEAD origin/main) HEAD origin/main | grep -c '^<<<<<<<'` 로 충돌을 먼저 본다. 충돌이 있으면 멈추고 보고한다(merge 로 최신화하고 rebase 는 쓰지 않는다).

- [ ] **Step 2: 스위트 러너 두 개를 쓴다**

`.superpowers/sdd/2026-09-27-review-stopping-criterion/run_suite.sh`:

```bash
#!/usr/bin/env bash
# run_suite.sh <out.tsv> — 이 변경이 닿는 스위트 전부를 리포 루트에서 돌려 파일마다 rc 와 실패 줄 수를 적는다.
# rc 만 적으면 이미 RED 인 파일 안의 새 실패가 안 보인다 — 실패 줄 수를 함께 적는다.
set -u
out="$1"; : > "$out"
root="$(git rev-parse --show-toplevel)" || exit 1
cd "$root" || exit 1
export PYTHONDONTWRITEBYTECODE=1
list="$(mktemp)"
{ git ls-files -- 'shared/tests/test_*.sh' 'plugins/spec-distill/tests/test_*.sh'
  git ls-files -- 'plugins/quality-gates/tests/*test_*.sh' | grep -v -e '/spike/' -e '/fixtures/'
} | sort -u > "$list"
while IFS= read -r t; do
  log="$(mktemp)"
  bash "$t" > "$log" 2>&1; rc=$?
  nf="$(grep -cE '✗|^FAIL|FAIL:' "$log" || true)"
  printf '%s\t%s\t%s\n' "$t" "$rc" "$nf" >> "$out"
  rm -f "$log"
done < "$list"
rm -f "$list"
log="$(mktemp)"; ( cd plugins/spec-distill/tests && python3 -m unittest discover -p 'test_*.py' ) > "$log" 2>&1; rc=$?
printf '%s\t%s\t%s\n' "py:spec-distill/unittest" "$rc" "$(grep -cE '^(FAIL|ERROR):' "$log" || true)" >> "$out"; rm -f "$log"
log="$(mktemp)"; python3 plugins/quality-gates/tests/test_utf8_explicit.py > "$log" 2>&1; rc=$?
printf '%s\t%s\t%s\n' "py:quality-gates/test_utf8_explicit" "$rc" "$(grep -cE '^(FAIL|ERROR):' "$log" || true)" >> "$out"; rm -f "$log"
git status --porcelain
```

`.superpowers/sdd/2026-09-27-review-stopping-criterion/compare_suite.sh`:

```bash
#!/usr/bin/env bash
# compare_suite.sh <base.tsv> <head.tsv> — rc 가 0 에서 벗어났거나 실패 줄이 는 파일 · head 에 없는 파일 ·
# head 에만 있는데 GREEN 이 아닌 파일을 낸다. 없으면 "no regression" 과 rc 0.
set -u
python3 - "$1" "$2" <<'PY'
import sys
def load(p):
    out = {}
    for ln in open(p, encoding="utf-8"):
        f, rc, nf = ln.rstrip("\n").split("\t")
        out[f] = (int(rc), int(nf))
    return out
base, head = load(sys.argv[1]), load(sys.argv[2])
bad = []
for f, (rc, nf) in sorted(base.items()):
    if f not in head:
        bad.append("MISSING %s" % f)
    elif (rc == 0 and head[f][0] != 0) or head[f][1] > nf:
        bad.append("REGRESS %s base=%s head=%s" % (f, (rc, nf), head[f]))
for f in sorted(set(head) - set(base)):
    if head[f] != (0, 0):
        bad.append("NEW-RED %s head=%s" % (f, head[f]))
print("\n".join(bad) or "no regression")
sys.exit(1 if bad else 0)
PY
```

- [ ] **Step 3: baseline 을 돌린다(백그라운드 — 수 분)**

```bash
D=.superpowers/sdd/2026-09-27-review-stopping-criterion
bash "$D/run_suite.sh" "$D/baseline.tsv" > "$D/baseline.porcelain" 2>&1
awk -F'\t' '$2!=0 || $3!=0' "$D/baseline.tsv"      # 선재 RED 목록 — 이름과 실패 줄 수를 보고에 싣는다
cat "$D/baseline.porcelain"                          # 비어 있어야 한다(스위트가 추적 파일을 바꾸지 않았다)
PYTHONDONTWRITEBYTECODE=1 python3 shared/tests/fixtures/adjudication/run_wiring_scan.py "$(pwd)" | grep -E '^(unwired|exempt_stale|comprehensions)='
mkdir -p ~/.claude/sdd-mirror/2026-09-27-review-stopping-criterion && cp "$D"/* ~/.claude/sdd-mirror/2026-09-27-review-stopping-criterion/
```
Expected: 계측 시점 값은 `unwired=0` · `exempt_stale=0` · `comprehensions=40` 이다. porcelain 이 비어 있지 않으면 `git checkout HEAD -- <그 파일>` 로 되돌리고, 어떤 테스트가 바꿨는지 보고한다.

- [ ] **Step 4: 커밋 없음** — baseline 은 git 밖 산출물이다. 선재 RED 목록을 다음 태스크 보고의 머리에 싣는다.

---

### Task 1: 테스트 하네스 — 필드 없는 사본 프로필과 골든 12파일

변경 **전** 엔진으로 할 일이 둘이다. (1) 기존 케이스 70여 개를 필드 없는 사본 프로필로 옮긴다 — 그래야 Task 3 이 실제 프로필에 `must_catch` 를 넣어도 기존 락이 재는 동작(라우팅 현행)이 그대로다. (2) 골든에 `gate` JSON · `gate --render` 를 더해, AC3 이 요구하는 「변경 전 캡처」를 이 커밋이 고정한다.

**Files:**
- Create: `shared/tests/fixtures/docreview/strip_must_catch.py`, `shared/tests/fixtures/docreview/nofield_profiles.sh`
- Modify: `shared/tests/fixtures/docreview/cases.sh:5` (`PROF_SD=`), `shared/tests/fixtures/docreview/capture_finalize_golden.sh` (`norm_copy` · `capture_and_run`), `shared/tests/test_docreview_golden.sh` (네 산출물 · 하한 12)
- Create(캡처): `shared/tests/fixtures/docreview/golden/{case_T11_permit_keeps_disposition,case_T22_reraise_appears_in_next_round,case_T05_T06_reject}.{gate.json,gate.txt}`

**Interfaces:**
- Produces: `bash shared/tests/fixtures/docreview/nofield_profiles.sh` 는 `brief.md`·`design-doc.md`·`seed.md` 사본(frontmatter 의 `must_catch:` 줄만 뺀 것)이 든 디렉토리 경로 한 줄을 낸다. `cases.sh` 의 `$PROF_SD` 가 그 경로다(`DOCREVIEW_PROF_SD` 로 덮을 수 있다). `strip_must_catch.py <src> <dst>` 는 Task 3 이후에도 쓰인다.

- [ ] **Step 1: 실패하는 골든 락부터** — `shared/tests/test_docreview_golden.sh` 를 고친다.

`CASES=` 아래 두 곳을 바꾼다. 하한 블록은 이렇게 된다:

```bash
n_golden=0
for f in "$GOLDEN"/*.fin.json "$GOLDEN"/*.state.md "$GOLDEN"/*.gate.json "$GOLDEN"/*.gate.txt; do
  [ -f "$f" ] && n_golden=$((n_golden+1))
done
if [ "$n_golden" -lt 12 ]; then
  no "골든 파일이 ${n_golden}개 — 케이스 셋 × 산출물 넷(fin.json · state.md · gate.json · gate.txt)이면 12개여야 한다. 하한 미달이면 이 락은 공허하다"
  finish; exit
fi
ok "골든 코퍼스 ${n_golden}개 (하한 12 충족 — 공허하지 않다)"
```

이식성 검사의 `grep -q -- "$REPO_ROOT"` 대상에 `"$GOLDEN"/*.gate.json "$GOLDEN"/*.gate.txt` 를 더한다. 재캡처 루프는 `for k in fin.json state.md gate.json gate.txt; do` 로 바꾼다. 헤더 주석 첫 문단 끝에 한 줄을 더한다:

```bash
# `gate` JSON · `gate --render` 도 고정한다 — must_catch 가 없는 프로필의 finalize 보고서와 게이트 렌더가
# 변경 전과 바이트 동일하다(설계 2026-09-27-review-stopping-criterion AC3). 케이스는 must_catch 를 뺀 사본
# 프로필로 돈다(`nofield_profiles.sh`) — 원장의 `profile:` 줄은 캡처가 정본 경로로 되돌린다.
```

- [ ] **Step 2: 실패 확인**

Run: `bash shared/tests/test_docreview_golden.sh`
Expected: `✗ 골든 파일이 6개 — … 12개여야 한다` 로 FAIL.

- [ ] **Step 3: 사본 헬퍼 둘을 쓴다**

`shared/tests/fixtures/docreview/strip_must_catch.py`:

```python
#!/usr/bin/env python3
"""strip_must_catch.py <src> <dst> — 프로필 frontmatter 의 `must_catch:` 줄만 빼고 나머지를 바이트 그대로 옮긴다.
본문(frontmatter 밖)의 같은 모양 줄은 건드리지 않는다."""
from __future__ import annotations

import io
import sys

lines = io.open(sys.argv[1], encoding="utf-8").read().split("\n")
out, fences = [], 0
for i, ln in enumerate(lines):
    if ln == "---":
        fences += 1
    if not (fences == 1 and i > 0 and ln.startswith("must_catch:")):
        out.append(ln)
io.open(sys.argv[2], "w", encoding="utf-8").write("\n".join(out))
```

`shared/tests/fixtures/docreview/nofield_profiles.sh`:

```bash
#!/usr/bin/env bash
# nofield_profiles.sh — spec-distill 프로필 셋(brief · design-doc · seed)에서 frontmatter 의 `must_catch:` 줄만 뺀
# 사본 디렉토리를 만들고 그 경로 한 줄을 낸다. cases.sh 의 케이스와 골든은 필드 없는 프로필의 동작(라우팅
# 현행)을 재므로 이 사본으로 돌고, 필드를 지목한 동작은 cases_advice.sh 가 실제 프로필로 잰다.
# 경로는 세 원본 내용의 해시다 — 같은 내용이면 다시 만들지 않고, 원본이 바뀌면 새 자리를 만든다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$(cd "$HERE/../../../.." && pwd)/plugins/spec-distill/references/docreview-profiles"
base="${TMPDIR:-/tmp}"; base="${base%/}"
h="$(cat "$SRC/brief.md" "$SRC/design-doc.md" "$SRC/seed.md" \
  | python3 -c 'import hashlib, sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest()[:12])')" || exit 1
dst="$base/docreview-nofield-$h"
if [ ! -f "$dst/seed.md" ]; then
  tmp="$(mktemp -d "$base/docreview-nofield-tmp.XXXXXX")" || exit 1
  for p in brief design-doc seed; do
    python3 "$HERE/strip_must_catch.py" "$SRC/$p.md" "$tmp/$p.md" || exit 1
  done
  # 동시 실행이 같은 자리를 먼저 만들었으면 rename 이 실패한다 — 그쪽 것을 쓰고 내 사본은 치운다.
  python3 -c 'import os, shutil, sys
try:
    os.rename(sys.argv[1], sys.argv[2])
except OSError:
    shutil.rmtree(sys.argv[1], ignore_errors=True)' "$tmp" "$dst"
fi
printf '%s\n' "$dst"
```

`chmod +x` 는 하지 않는다 — qg shell 어댑터가 실행비트로 테스트를 claim 하고, 두 파일은 테스트가 아니다.

- [ ] **Step 4: `cases.sh` 가 사본을 쓴다** — 5행 `PROF_SD="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles"` 를 바꾼다:

```bash
# 필드 없는 사본 — 이 파일의 케이스는 must_catch 를 지목하지 않은 프로필의 동작(라우팅 현행)을 잰다.
# must_catch 를 지목한 동작은 cases_advice.sh 가 실제 프로필($PROF_MC)로 잰다.
PROF_SD="${DOCREVIEW_PROF_SD:-$(bash "$FX/nofield_profiles.sh")}"
```

- [ ] **Step 5: 캡처 스크립트** — `capture_finalize_golden.sh` 의 `norm_copy` 를 바꾼다(사본 경로를 정본 경로로 먼저 되돌린 뒤 REPO_ROOT 를 자리표로):

```bash
norm_copy() {   # norm_copy <src> <dst> — 사본 프로필 경로 · REPO_ROOT 절대경로 · 라운드 시작 표식을 안정 자리표로
  python3 -c 'import io, re, sys
src, dst, root, ph, prof, canon = sys.argv[1:7]
t = io.open(src, encoding="utf-8").read().replace(prof + "/", canon + "/").replace(root + "/", ph + "/")
t = re.sub(r"(?m)^(\s*started_mtime_ns: )[0-9]+$", r"\g<1><MTIME_NS>", t)
io.open(dst, "w", encoding="utf-8").write(t)' \
    "$1" "$2" "$REPO_ROOT" "$GOLDEN_PLACEHOLDER" "$PROF_SD" "$REPO_ROOT/plugins/spec-distill/references/docreview-profiles"
}
```

`capture_and_run` 안의 `if [ -d "$arg" ] && [ -f "$arg/docreview-state.md" ]; then` 블록 끝(`norm_copy "$arg/docreview-state.md" …` 다음)에 넣는다:

```bash
        py docreview_state.py gate --state-dir "$arg" > "$arg/golden-gate.json" 2>/dev/null \
          && norm_copy "$arg/golden-gate.json" "$OUT/$casefn.gate.json"
        py docreview_state.py gate --state-dir "$arg" --render > "$arg/golden-gate.txt" 2>/dev/null \
          && norm_copy "$arg/golden-gate.txt" "$OUT/$casefn.gate.txt"
```

헤더 주석의 「왜 assert … 이 둘인가」 문단 끝에 `gate` 두 산출물도 같은 이유로 고정한다는 한 줄을 더한다(AC3 — 렌더도 바이트 동일).

- [ ] **Step 6: 변경 전 엔진으로 재캡처하고 기존 여섯이 그대로인지 본다**

```bash
bash shared/tests/fixtures/docreview/capture_finalize_golden.sh
git diff --exit-code -- 'shared/tests/fixtures/docreview/golden/*.fin.json' 'shared/tests/fixtures/docreview/golden/*.state.md' && echo SAME
ls shared/tests/fixtures/docreview/golden | wc -l
grep -c . shared/tests/fixtures/docreview/golden/*.gate.txt
```
Expected: `SAME`(사본 경로 정규화가 옛 골든을 바이트 그대로 재현한다), 12, 각 `gate.txt` 가 4줄 이상. `SAME` 이 아니면 정규화가 틀린 것이다 — 골든을 갱신하지 말고 `norm_copy` 를 고친다.

- [ ] **Step 7: 통과 확인 — 사본 전환이 기존 락을 흔들지 않았다**

```bash
bash shared/tests/test_docreview_golden.sh | tail -3
for t in route state anchor intent gate_visibility; do bash shared/tests/test_docreview_$t.sh | tail -1; done
bash shared/tests/test_docreview_mutations.sh | tail -1
```
Expected: 전부 `Fail: 0`(또는 Task 0 baseline 과 같은 실패 줄 수).

- [ ] **Step 8: 커밋**

```bash
git add shared/tests/fixtures/docreview/strip_must_catch.py shared/tests/fixtures/docreview/nofield_profiles.sh \
  shared/tests/fixtures/docreview/cases.sh shared/tests/fixtures/docreview/capture_finalize_golden.sh \
  shared/tests/test_docreview_golden.sh shared/tests/fixtures/docreview/golden/
git commit -m "$(printf 'test(docreview): 필드 없는 사본 프로필 · 게이트 골든 — 변경 전 캡처\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>')"
git status --porcelain
```

---

### Task 2: 프로필 스키마 — `must_catch` 선택 필드 (AC4)

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py:37-39` (상수) · `load_profile` (`extra` · 층 검증 뒤)
- Test: `shared/tests/test_docreview_profile_schema.sh` (⑤ 절)

**Interfaces:**
- Produces: `load_profile()` 결과 dict 에 `must_catch`(문자열 목록)가 **있을 때만** 키가 있다. 거부 사유는 `must_catch_unknown_axis:<축,…>` · `must_catch_empty` · `field_not_str_list:must_catch` 셋이다.

- [ ] **Step 1: 실패하는 테스트** — `test_docreview_profile_schema.sh` 의 `finish` 바로 앞에 넣는다:

```bash
# ⑤ must_catch (설계 2026-09-27-review-stopping-criterion AC4) — 선택 필드. 지목한 축은 layer_rubric 안에
# 있어야 하고(rubric 밖 → must_catch_unknown_axis), 빈 목록은 「무엇으로도 멈춘다」라 거부한다(must_catch_empty).
# 목록이 아니면 field_not_str_list. 필드 부재는 통과한다(③ 의 generic 이 양의 짝). init(라운드 진입 실경로)도 거부한다.
mc_variant() {   # mc_variant <이름> <must_catch 줄|-> → design-doc 의 must_catch 줄을 그 줄로 바꾼(- 면 뺀) 사본 경로
  awk -v L="$2" '/^must_catch:/ {next} {print} /^  layer2:/ && !done {if (L != "-") print L; done = 1}' "$DD" > "$TMPD/mc-$1.md"
  echo "$TMPD/mc-$1.md"
}
mc_rc() {   # mc_rc <프로필> → "rc|stderr 한 줄"
  python3 "$SCRIPTS/docreview_state.py" profile-check "$1" >/dev/null 2>"$TMPD/mc.err"; echo "$?|$(tr -d '\n' < "$TMPD/mc.err")"
}
r="$(mc_rc "$(mc_variant ok 'must_catch: [goal_fit, scope]')")"
assert_eq "${r%%|*}" "0" "must_catch: rubric 안 축 둘이면 통과한다"
assert_eq "$(python3 "$SCRIPTS/docreview_state.py" profile-check "$TMPD/mc-ok.md" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("must_catch"))')" \
  "['goal_fit', 'scope']" "must_catch: profile-check 가 지목한 축을 그대로 낸다"
r="$(mc_rc "$(mc_variant unknown 'must_catch: [goal_fit, bogus_axis]')")"
assert_eq "${r%%|*}" "2" "must_catch: rubric 밖 축 → rc 2"
assert_contains "${r#*|}" "must_catch_unknown_axis:bogus_axis" "must_catch: 사유가 must_catch_unknown_axis 와 그 축 이름이다"
r="$(mc_rc "$(mc_variant empty 'must_catch: []')")"
assert_eq "${r%%|*}" "2" "must_catch: 빈 목록 → rc 2"
assert_contains "${r#*|}" "must_catch_empty" "must_catch: 사유가 must_catch_empty 다"
r="$(mc_rc "$(mc_variant scalar 'must_catch: goal_fit')")"
assert_contains "${r#*|}" "field_not_str_list:must_catch" "must_catch: 목록이 아니면 field_not_str_list"
r="$(mc_rc "$(mc_variant absent -)")"
assert_eq "${r%%|*}" "0" "must_catch: 부재는 통과한다(선택 필드 — fields_missing 이 아니다)"
for v in unknown empty; do
  mkdir -p "$TMPD/mc-init-$v"
  python3 "$SCRIPTS/docreview_state.py" init --state-dir "$TMPD/mc-init-$v" --doc "$DOCFAKE" --profile "$TMPD/mc-$v.md" >/dev/null 2>"$TMPD/mc-init.err"
  rc=$?
  assert_eq "$rc" "1" "must_catch($v): init 도 거부한다(rc 1 — 라운드 진입 실경로)"
  assert_contains "$(cat "$TMPD/mc-init.err")" "must_catch_" "must_catch($v): init 의 사유가 must_catch_* 다"
done
```

`$DOCFAKE` 는 ④ 절이 이미 정의한다 — ⑤ 는 반드시 ④ 뒤에 둔다.

- [ ] **Step 2: 실패 확인**

Run: `bash shared/tests/test_docreview_profile_schema.sh`
Expected: `must_catch: rubric 안 축 둘이면 통과한다` 가 ✗ 다(`fields_unknown:must_catch`).

- [ ] **Step 3: 구현** — `docreview_state.py`.

`PROFILE_FIELDS = (…)` 튜플 바로 다음 줄에 넣는다:

```python
# 선택 필드 — 필수 목록에 넣으면 qg `generic`(이 필드 없음)이 `fields_missing` 으로 죽는다. 부재면 advisory 축이
# 공집합이라 라우팅이 현행과 같다(docreview_advice.advisory_axes).
OPTIONAL_PROFILE_FIELDS = ("must_catch",)
```

`load_profile` 의 `extra = [k for k in data if k not in PROFILE_FIELDS]` 를 바꾼다:

```python
    extra = [k for k in data if k not in PROFILE_FIELDS and k not in OPTIONAL_PROFILE_FIELDS]
```

`_str_list(lr["layer2"], "layer_rubric.layer2", regex=False)` 바로 다음에 넣는다:

```python
    # must_catch — 승인을 막는 축. 그 밖의 rubric 축이 advisory 다(정의상 fail-closed: rubric 밖 category ·
    # `other` · 엔진이 만든 것은 전부 막는다). 지목은 rubric 안이어야 하고, 빈 목록은 막는 축 0 이라 거부한다.
    if "must_catch" in data:
        mc = _str_list(data["must_catch"], "must_catch", regex=False)
        if not mc:
            raise ProfileError("must_catch_empty")
        rubric = set(lr["layer1"]) | set(lr["layer2"])
        unknown = [x for x in mc if x not in rubric]
        if unknown:
            raise ProfileError("must_catch_unknown_axis:%s" % ",".join(unknown))
```

- [ ] **Step 4: 통과 확인**

```bash
bash shared/tests/test_docreview_profile_schema.sh | tail -1
bash shared/tests/test_docreview_codex.sh | tail -1     # 러너 · 게이트 등식 — must_catch 는 PROFILE_FIELDS 밖이라 대조 대상이 아니다
```
Expected: 둘 다 `Fail: 0`(또는 baseline 과 같은 실패 줄 수).

- [ ] **Step 5: 커밋**

```bash
git add shared/docreview/scripts/docreview_state.py shared/tests/test_docreview_profile_schema.sh
git commit -m "$(printf 'feat(docreview): 프로필 선택 필드 must_catch — rubric 안 · 비지 않음\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>')"
```

---

### Task 3: 세 프로필 값 · 펜스의 `must_catch` 벗기기 (AC16)

프로필 값과 펜스의 벗기기는 **한 커밋**이다. 값만 넣으면 `test_dispatch_profile_inline.sh` 의 「stdout 이 프로필 파일 그대로」가 깨지고, 그 사이 리뷰어는 막는 축을 본다.

**Files:**
- Modify: `plugins/spec-distill/references/docreview-profiles/{brief,design-doc,seed}.md` (frontmatter `  layer2:` 줄 다음)
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md:341`, `plugins/spec-distill/skills/reviewing-spec/SKILL.md:318`, `plugins/spec-distill/skills/framing-requests/SKILL.md:441-454` (마커 + 벗기기)
- Test: `plugins/spec-distill/tests/test_dispatch_profile_inline.sh`, `shared/tests/test_docreview_codex.sh`

**Interfaces:**
- Consumes: Task 2 의 스키마(값이 rubric 안이어야 한다).
- Produces: 세 진입 skill 의 profile-content 펜스 stdout = 프로필 파일에서 frontmatter `must_catch:` 줄만 뺀 것.

- [ ] **Step 1: 실패하는 테스트** — `test_dispatch_profile_inline.sh`.

`# guards:` 줄 끝과 `--emit-scanned` 목록에 `plugins/spec-distill/skills/framing-requests/SKILL.md` · `plugins/spec-distill/references/docreview-profiles/seed.md` 두 경로를 더한다. 헤더 목록에 줄을 더한다:

```bash
#   S  (설계 2026-09-27-review-stopping-criterion AC16) 세 진입 skill(reviewing-brief · reviewing-spec ·
#      framing-requests)의 profile-content 펜스 출력에 `must_catch:` 줄이 없고, 그 줄을 뺀 나머지는 프로필 파일과
#      바이트 동일하다 — 막는 축을 아는 리뷰어는 category 라벨로 차단 여부를 조종할 수 있다.
```

`fail_branch()` 정의 다음에 기대값 계산기를 둔다(펜스와 독립인 python):

```bash
expect_stripped() {   # expect_stripped <프로필> → frontmatter 의 must_catch 줄만 뺀 내용(펜스와 독립 계산)
  python3 -c 'import io, sys
lines = io.open(sys.argv[1], encoding="utf-8").read().split("\n")
out, fences = [], 0
for i, ln in enumerate(lines):
    if ln == "---":
        fences += 1
    if not (fences == 1 and i > 0 and ln.startswith("must_catch:")):
        out.append(ln)
sys.stdout.write("\n".join(out))' "$1"
}
```

X 루프 안 `assert_eq "$(cat "$SCRATCH/ok-$sk-$mode.out")" "$(cat "$PROF")" …` 한 줄을 셋으로 바꾼다:

```bash
      assert_eq "$(cat "$SCRATCH/ok-$sk-$mode.out")" "$(expect_stripped "$PROF")" "$sk X($mode): stdout 이 프로필 파일에서 must_catch 줄만 뺀 것과 같다 ($prof)"
      assert_eq "$(grep -c '^must_catch:' "$SCRATCH/ok-$sk-$mode.out" || true)" "0" "$sk S($mode): 펜스 출력에 must_catch 줄이 없다"
      assert_eq "$(grep -c '^must_catch:' "$PROF" || true)" "1" "$sk S 전제: 프로필 파일에는 must_catch 줄이 있다(벗기기 단언이 공허하지 않다)"
```

`for spec in …` 루프가 끝난 뒤(brief degrade 원장 검사 앞)에 framing-requests 셀을 넣는다:

```bash
# S — framing-requests. 이 펜스는 `$PROFILE` 을 앞 블록(「## 상태」)에서 받으므로 그 값만 env 로 준다.
FR_FENCE="$SCRATCH/framing-requests.fence.sh"; cut_marked "$SD/skills/framing-requests/SKILL.md" > "$FR_FENCE"
n_fr="$(grep -c . "$FR_FENCE" || true)"
if [ "${n_fr:-0}" -ge 4 ] && bash -n "$FR_FENCE" 2>/dev/null; then
  ok "framing-requests S: profile-content 마커 펜스 ${n_fr}줄 · bash -n 통과"
else
  no "framing-requests S: profile-content 마커 펜스가 없거나 깨졌다 (${n_fr:-0}줄)"
fi
SEED_PROF="$SD/references/docreview-profiles/seed.md"
( cd "$SCRATCH" && env -i PATH="$BASE" HOME="$SCRATCH" PROFILE="$SEED_PROF" bash "$FR_FENCE" ) \
  > "$SCRATCH/fr.out" 2>"$SCRATCH/fr.err"; fr_rc=$?
assert_eq "$fr_rc" "0" "framing-requests S: 펜스 rc 0"
assert_eq "$(cat "$SCRATCH/fr.out")" "$(expect_stripped "$SEED_PROF")" "framing-requests S: stdout 이 seed 프로필에서 must_catch 줄만 뺀 것과 같다"
assert_eq "$(grep -c '^must_catch:' "$SCRATCH/fr.out" || true)" "0" "framing-requests S: 펜스 출력에 must_catch 줄이 없다"
assert_eq "$(grep -c '^must_catch:' "$SEED_PROF" || true)" "1" "framing-requests S 전제: seed 프로필에는 must_catch 줄이 있다"
```

`shared/tests/test_docreview_codex.sh` 의 코퍼스 루프에서 `assert_file_absent "$CCAP" 'disposition from:[ ]*$' …` 다음에 넣는다:

```bash
  # 라우팅 키는 리뷰어 밖이다(설계 2026-09-27-review-stopping-criterion Non-goals) — 러너는 자기가 읽는 필드만 싣는다.
  assert_file_absent "$CCAP" 'must_catch' \
    "러너: 프로필 코퍼스 — $cbase 의 프롬프트에 must_catch 가 실리지 않는다"
```

- [ ] **Step 2: 실패 확인**

Run: `bash plugins/spec-distill/tests/test_dispatch_profile_inline.sh | grep -E '✗' | head`
Expected: `S 전제: 프로필 파일에는 must_catch 줄이 있다` 와 `framing-requests S: profile-content 마커 펜스가 없거나 깨졌다` 가 ✗ 다.

- [ ] **Step 3: 프로필 값** — 세 파일의 frontmatter 에서 `  layer2: …` 줄 바로 다음에 넣는다(컬럼 0, 러너 줄 문법의 flow 목록):

`brief.md`:
```yaml
must_catch: [distortion, omission, invention, provenance_mislabel, authority_syntax, evidence_unsupported]
```
`design-doc.md`:
```yaml
must_catch: [goal_fit, problem_definition, scope, architecture]
```
`seed.md`:
```yaml
must_catch: [unfounded_addition, example_as_requirement, premature_closure, inference_as_decision]
```

- [ ] **Step 4: 세 펜스의 벗기기** — reviewing-brief · reviewing-spec 의 profile-content 펜스 마지막 줄 `printf '%s\n' "$PROFILE_TEXT"` 를 둘로 바꾼다:

```bash
# frontmatter 의 `must_catch:` 줄(엔진 라우팅 키)은 리뷰어에게 싣지 않는다 — 막는 축을 아는 리뷰어는 category 로 차단 여부를 조종할 수 있다.
printf '%s\n' "$PROFILE_TEXT" | sed -e '2,/^---$/{' -e '/^must_catch:/d' -e '}'
```

framing-requests 의 `### 프로필 내용 — 탐지 dispatch 직전마다` 절은 그 bash 펜스를 마커로 감싸고 같은 두 줄로 바꾼다:

````markdown
### 프로필 내용 — 탐지 dispatch 직전마다

<!-- profile-content:begin -->
```bash
# 리뷰어의 `<profile>` 슬롯에는 경로가 아니라 **내용**을 싣는다 — (기존 주석 세 줄 그대로)
prof_rc=0; PROFILE_TEXT="$(cat "$PROFILE")" || prof_rc=$?
if [ "$prof_rc" -ne 0 ] || [ -z "$PROFILE_TEXT" ]; then
  (기존 실패 분기 그대로)
fi
# frontmatter 의 `must_catch:` 줄(엔진 라우팅 키)은 리뷰어에게 싣지 않는다 — 막는 축을 아는 리뷰어는 category 로 차단 여부를 조종할 수 있다.
printf '%s\n' "$PROFILE_TEXT" | sed -e '2,/^---$/{' -e '/^must_catch:/d' -e '}'
```
<!-- profile-content:end -->
````

(「그대로」 라고 적은 줄은 현 파일의 줄을 한 글자도 바꾸지 않는다. SKILL.md 에는 awk `$0` 을 쓰지 않는다 — Skill 인자로 치환된다.)

- [ ] **Step 5: 통과 확인**

```bash
bash plugins/spec-distill/tests/test_dispatch_profile_inline.sh | tail -1
bash shared/tests/test_docreview_codex.sh | tail -1
bash shared/tests/test_docreview_profiles.sh | tail -1
bash shared/tests/test_docreview_profile_schema.sh | tail -1
for t in plugins/spec-distill/tests/test_*.sh; do printf '%s ' "$t"; bash "$t" 2>&1 | tail -1; done | grep -v 'Fail: 0'
```
Expected: 앞 넷은 `Fail: 0` 이다. 마지막 줄의 목록은 Task 0 의 선재 RED 와 같아야 한다 — framing-requests 편집이 절 · 펜스 개수를 재는 락을 흔들었으면 여기서 보인다. 락 메시지대로 고친다. 락이 쥔 것이 옳으면 펜스 위치를 바꾸고, 셈이 낡았으면 그 락의 기대값을 이 편집에 맞춘다(이유를 커밋 메시지에 적는다).

- [ ] **Step 6: 변이 확인(손 — 커밋 뒤)** — 먼저 Step 7 커밋을 하고, 한 펜스(reviewing-spec)의 `| sed -e …` 꼬리를 지운 뒤 락을 돌린다.

```bash
python3 - <<'PY'
import io
p = "plugins/spec-distill/skills/reviewing-spec/SKILL.md"
t = io.open(p, encoding="utf-8").read()
old = "printf '%s\\n' \"$PROFILE_TEXT\" | sed -e '2,/^---$/{' -e '/^must_catch:/d' -e '}'"
assert t.count(old) == 1, t.count(old)
io.open(p, "w", encoding="utf-8").write(t.replace(old, "printf '%s\\n' \"$PROFILE_TEXT\""))
PY
bash plugins/spec-distill/tests/test_dispatch_profile_inline.sh | grep -c '✗'
git checkout HEAD -- plugins/spec-distill/skills/reviewing-spec/SKILL.md && git diff HEAD --stat
```
Expected: ✗ 가 1 이상이다(변이가 잡힌다). 복원 뒤 `git diff HEAD --stat` 이 비어 있다.

- [ ] **Step 7: 커밋**(Step 6 앞에)

```bash
git add plugins/spec-distill/references/docreview-profiles/brief.md plugins/spec-distill/references/docreview-profiles/design-doc.md \
  plugins/spec-distill/references/docreview-profiles/seed.md plugins/spec-distill/skills/reviewing-brief/SKILL.md \
  plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/skills/framing-requests/SKILL.md \
  plugins/spec-distill/tests/test_dispatch_profile_inline.sh shared/tests/test_docreview_codex.sh
git commit -m "$(printf 'feat(spec-distill): 세 프로필 must_catch 값 · 리뷰어 슬롯에서 벗기기\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>')"
```

---

### Task 4: `docreview_advice.py` 모듈 · 배포 링크 (§A)

**Files:**
- Create: `shared/docreview/scripts/docreview_advice.py`
- Create(심볼릭 링크): `plugins/spec-distill/scripts/docreview_advice.py`, `plugins/quality-gates/scripts/docreview_advice.py` → `../../../shared/docreview/scripts/docreview_advice.py`
- Create: `shared/tests/fixtures/docreview/cases_advice.sh`, `shared/tests/test_docreview_advice.sh`

**Interfaces:**
- Produces(이 태스크):
  - `ENGINE_SOURCES: frozenset`
  - `ROUTE_ADVICE = "advice"`
  - `has_must_catch(prof) -> bool`
  - `advisory_axes(prof) -> frozenset`
  - `is_advisory(it: dict, axes: frozenset) -> bool`
  - `member_categories(items: dict, live: list) -> list`
  - `advice_ids(final: list) -> list`
- 뒤 태스크가 이 모듈에 더한다:
  - Task 5: `route_step1` · `mc_preexisting_new`
  - Task 6: `route_step2`
  - Task 7: `RENDER_CAP` · `SUMMARY_WIDTH` · `COUNT_PREFIX` · `clip` · `render_lines` · `sink_row` · `review_identity` · `count_key` · `count_line`

- [ ] **Step 1: 실패하는 테스트** — `shared/tests/fixtures/docreview/cases_advice.sh`:

```bash
# docreview 참고(advisory) 라우팅 케이스 — 설계 2026-09-27-review-stopping-criterion. 행동 락
# (test_docreview_advice.sh)과 변이 매트릭스(test_docreview_mutations.sh)가 공유한다.
# 계약: cases.sh 를 먼저 source 한다(헬퍼 r1 · route_r1 · next_round · critic_now · codex_now · st_yaml · gsum · jget · fsum ·
#       $PROF_QG). cases.sh 의 케이스는 must_catch 를 뺀 사본($PROF_SD)으로 돌고, 여기 케이스는 실제 프로필($PROF_MC)로 돈다.
PROF_MC="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles"

adv_py() {   # adv_py <프로필> <식> — docreview_advice 를 a, 적재한 프로필을 p 로 놓고 식을 평가해 찍는다
  python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import docreview_advice as a, docreview_state as s
p = s.load_profile(sys.argv[2]); print(eval(sys.argv[3]))' "$SCRIPTS" "$1" "$2"
}

# ── §A advisory 축 = (layer1 ∪ layer2) − must_catch ────────────────────────
case_advice_axes_per_profile() {
  assert_eq "$(adv_py "$PROF_MC/brief.md" 'sorted(a.advisory_axes(p))')" "['direction', 'overdesign']" \
    "§A: brief 의 advisory 축은 direction · overdesign"
  assert_eq "$(adv_py "$PROF_MC/design-doc.md" 'sorted(a.advisory_axes(p))')" \
    "['ambiguity', 'approaches_comparison', 'component_relations', 'data_flow', 'feasibility', 'handoff_incomplete', 'isolation', 'overdesign', 'placeholder', 'scope_creep', 'testing', 'tradeoffs']" \
    "§A: design-doc 의 advisory 축은 층 1 나머지 다섯 + 층 2 일곱"
  assert_eq "$(adv_py "$PROF_MC/seed.md" 'sorted(a.advisory_axes(p)), a.has_must_catch(p)')" "([], True)" \
    "§A: seed 는 advisory 축이 없고 지목은 있다(참고 줄 · 계수 키는 선다)"
  assert_eq "$(adv_py "$PROF_QG/generic.md" 'sorted(a.advisory_axes(p)), a.has_must_catch(p)')" "([], False)" \
    "§A: 필드 없는 프로필(qg generic)은 advisory 축이 공집합 — 라우팅 현행"
}
case_advice_engine_items_mustcatch() {
  assert_eq "$(adv_py "$PROF_MC/design-doc.md" '[a.is_advisory({"category": "ambiguity", "_source": s}, a.advisory_axes(p)) for s in ("critic", "codex", "recritic", "diff", "reraise", "escalated")]')" \
    "[True, True, True, False, False, False]" \
    "§A: 엔진 자동 생성 항목(diff · reraise · escalated)은 category 와 무관하게 must-catch — 호출 순서에 기대지 않는다"
  assert_eq "$(adv_py "$PROF_MC/design-doc.md" '[a.is_advisory(it, a.advisory_axes(p)) for it in ({"category": "other"}, {"category": "frozen_change"}, {"category": "made_up_axis"}, {"category": "goal_fit"}, {"category": "ambiguity", "_member_categories": ["ambiguity", "architecture"]}, {"category": "ambiguity", "_member_categories": ["ambiguity", "testing"]})]')" \
    "[False, False, False, False, False, True]" \
    "§A·§B: rubric 밖 · other · frozen_change · must-catch 축 · must-catch 구성원이 낀 병합 생존자는 must-catch, 전부 advisory 인 병합은 advisory"
}
```

`shared/tests/test_docreview_advice.sh`:

```bash
#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_advice.py shared/docreview/scripts/docreview_route.py shared/docreview/scripts/docreview_state.py plugins/*/references/docreview-profiles/*.md shared/tests/fixtures/docreview/**
#
# must-catch 축 / 참고(advisory) 축 라우팅의 행동 — 설계 2026-09-27-review-stopping-criterion.
# 케이스 본문은 fixtures/docreview/cases_advice.sh 에 있다(변이 매트릭스와 공유). 실제 프로필(must_catch 지목)로 돈다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/docreview_advice.py"; echo "shared/docreview/scripts/docreview_route.py"
  echo "shared/docreview/scripts/docreview_state.py"
  git ls-files -- 'plugins/*/references/docreview-profiles/*.md'
  bash "$(dirname "$0")/docreview_fixture_corpus.sh"; exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPTS="${SCRIPTS:-$REPO_ROOT/plugins/spec-distill/scripts}"
. "$HERE/fixtures/docreview/cases.sh"
. "$HERE/fixtures/docreview/cases_advice.sh"
case_advice_axes_per_profile
case_advice_engine_items_mustcatch
finish
```

- [ ] **Step 2: 실패 확인**

Run: `bash shared/tests/test_docreview_advice.sh`
Expected: `ModuleNotFoundError: No module named 'docreview_advice'` 와 함께 ✗ 둘.

- [ ] **Step 3: 모듈 구현** — `shared/docreview/scripts/docreview_advice.py`:

```python
"""docreview_advice.py — must-catch 축과 참고(advisory) 축을 가르는 순수 함수 (leaf 모듈).

라우터(`docreview_route.py`)의 두 걸음 표지 · 병합 생존자의 축 소속 · 관측 계수와, 원장의 `advice` 서브커맨드
(`docreview_state.py` 의 `cmd_advice`)가 쓰는 렌더 · 박제 행 · 계수 줄을 담는다. 파일 I/O 도 형제 import 도
없다 — 항목 dict · 프로필 dict · 스냅숏 dict 만 받는다. `adjudication` 을 import 하지 않는다: 강제 계수는 호출자가
넘긴 원장(`L`)에 적는다.

advisory 축 = (`layer_rubric.layer1` ∪ `layer2`) − `must_catch`. 그 밖(rubric 밖 category · `other` ·
`frozen_change`)과 엔진 자동 생성 항목(`_source` ∈ diff · reraise · escalated)은 전부 must-catch 다. 프로필이
`must_catch` 를 지목하지 않으면 advisory 축은 공집합이고 라우팅은 현행과 같다.
"""
from __future__ import annotations

ENGINE_SOURCES = frozenset(("diff", "reraise", "escalated"))
ROUTE_ADVICE = "advice"


def has_must_catch(prof) -> bool:
    return prof.get("must_catch") is not None


def advisory_axes(prof) -> frozenset:
    mc = prof.get("must_catch")
    if mc is None:
        return frozenset()
    lr = prof["layer_rubric"]
    return (frozenset(lr["layer1"]) | frozenset(lr["layer2"])) - frozenset(mc)


def is_advisory(it, axes) -> bool:
    """advisory 축 소속인가 — 엔진 자동 생성 항목은 category 와 무관하게 아니다(재상승 · 상향 후속은 원본의
    category 를 물려받으므로 category 로는 못 가른다). same_as 병합 생존자는 기각되지 않은 구성원
    (`_member_categories`) 전부가 advisory 일 때만 advisory 다."""
    if it.get("_source") in ENGINE_SOURCES:
        return False
    cats = it.get("_member_categories") or [it["category"]]
    return all(c in axes for c in cats)


def member_categories(items, live) -> list:
    """병합 그룹의 기각되지 않은 구성원 category — 생존자의 축 소속 판정 재료(`_absorb_same_as` 가 남긴다)."""
    return sorted({items[m]["category"] for m in live})


def advice_ids(final) -> list:
    return [it["id"] for it in final if it.get("route") == ROUTE_ADVICE]
```

- [ ] **Step 4: 배포 링크**

```bash
ln -s ../../../shared/docreview/scripts/docreview_advice.py plugins/spec-distill/scripts/docreview_advice.py
ln -s ../../../shared/docreview/scripts/docreview_advice.py plugins/quality-gates/scripts/docreview_advice.py
git add shared/docreview/scripts/docreview_advice.py plugins/spec-distill/scripts/docreview_advice.py plugins/quality-gates/scripts/docreview_advice.py
git ls-files -s -- plugins/*/scripts/docreview_advice.py      # 둘 다 mode 120000
```

- [ ] **Step 5: 통과 확인 — 모듈과 배포 계약**

```bash
bash shared/tests/test_docreview_advice.sh | tail -1
bash shared/tests/test_copy_of_contract.sh | tail -1                 # 축 1a(링크) · 1c(import 형제) — 스테이징 뒤에만 보인다
PYTHONDONTWRITEBYTECODE=1 python3 plugins/quality-gates/tests/test_utf8_explicit.py 2>&1 | tail -1
```
Expected: `Fail: 0` · `Fail: 0` · `OK`. copy-of 락이 `docreview_advice.py` 를 import-only 정본으로 세지 못하면(아직 소비자 import 가 없다 — Task 5 가 route.py 에서 import 한다) 그 사실만 적어 두고 Task 5 Step 7 에서 다시 돌린다.

- [ ] **Step 6: 커밋**

```bash
git add shared/tests/fixtures/docreview/cases_advice.sh shared/tests/test_docreview_advice.sh
git commit -m "$(printf 'feat(docreview): docreview_advice 모듈 — advisory 축 · 엔진 항목은 must-catch\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>')"
```

---

### Task 5: 1 걸음 표지 · advice 원장 · 계수 · 참고 줄 (AC1·AC3·AC5·AC9·AC13·AC19)

이 태스크는 병합 생존자 규칙과 2 걸음(`blocks` · 라운드 ≥2 새 fix)을 **아직 하지 않는다**. 그래서 이 태스크의 테스트는 두 가지를 단언하지 않는다: `blocks` 가 있는 ask 와 병합 생존자(`AD3`). Task 6 이 그 둘을 더한다.

**Files:**
- Modify: `shared/docreview/scripts/docreview_advice.py` (`route_step1` · `_subtree` · `mc_preexisting_new`)
- Modify: `shared/docreview/scripts/docreview_route.py` (import · `_classify_items` 끝 · `cmd_finalize` · `_build_report`)
- Modify: `shared/docreview/scripts/docreview_state.py` (`record_findings` · `_record_advice` · `gate_summary` · `render_gate`)
- Modify: `tools/adjudication/check_wiring.py` (`EXEMPT` 줄번호)
- Create(픽스처): `shared/tests/fixtures/docreview/{critic-brief-direction.txt,critic-brief-direction-distortion.txt,recritic-empty.txt,critic-mc-empty.txt,critic-mc-r1.txt,recritic-mc-r1.txt.tmpl,critic-mc-promoted.txt,critic-mc-r2.txt,critic-mc-child.txt,design-sample-child.md}`
- Test: `cases_advice.sh` · `test_docreview_advice.sh` · `test_docreview_mutations.sh`

**Interfaces:**
- Consumes: Task 4 의 `advisory_axes` · `has_must_catch` · `is_advisory` · `advice_ids`.
- Produces:
  - `route_step1(final: list, axes: frozenset) -> None` — `it["route"] = "advice"` 를 단다.
  - `mc_preexisting_new(final, snapshots: dict, n: int, axes) -> int`.
  - `record_findings(st, findings, n) -> {"listed": int, "repeat": int}` — 반환값이 새로 생긴다. 기존 호출부는 무시해도 된다.
  - 원장 `st["advice"][<bucket>] = {"id","round","layer","category","anchor","summary","replacement","shown","sunk"}` — 키가 필요할 때만 생긴다.
  - `st["findings"][id]["route"] = "advice"`.
  - `fin.json` 새 키 `advice`(id 목록) · `advice_new` · `advice_repeat` · `mc_preexisting_new` — `escalated_unconsumed` 뒤, `adjudication_*` 앞에 필드 지목 프로필만.
  - `route_report` 에도 같은 세 계수가 실린다.
  - `gate` JSON 새 키 `advice = {"total","new","repeat","mc_preexisting_new"}` — 보고서에 계수가 있을 때만.
  - 렌더 줄은 `참고 N건(이번 라운드 새 k · 반복 r) — 끝에서 한 목록으로 · 선재 절의 새 must-catch m` 이다.

- [ ] **Step 1: 픽스처를 쓴다**

`critic-brief-direction.txt`:
````text
```docreview-layer1
- ref: b1
  category: direction
  anchor: "#2-제약"
  disposition: decide
  summary: "BD1: 제약 C1 의 방향이 반증된다"
```

```docreview-layer2
[]
```
````

`critic-brief-direction-distortion.txt` — 위와 같되 layer2 블록을 다음으로:
````text
```docreview-layer2
- ref: b2
  category: distortion
  anchor: "#2-제약"
  disposition: fix
  summary: "BD2: 제약 C1 이 원문의 뜻을 바꿨다"
```
````

`recritic-empty.txt`:
````text
```docreview-recritic
verdicts: []
added: []
```
````

`critic-mc-empty.txt`:
````text
```docreview-layer1
[]
```

```docreview-layer2
[]
```
````

`critic-mc-promoted.txt` — AC19 단독(보호 헤딩 안 advisory fix 하나):
````text
```docreview-layer1
[]
```

```docreview-layer2
- ref: m8
  category: ambiguity
  anchor: "#2-goals"
  disposition: fix
  summary: "AD8: 목표 B 가 두 가지로 읽힌다"
```
````

`critic-mc-r1.txt` — design-doc 라운드 1 의 스물한 항목이다. `MC*` 는 must-catch, `AD*` 는 advisory 이고, 요약 머리는 전부 유일하다:
````text
탐지 리뷰를 마쳤다.

```docreview-layer1
- ref: m1
  category: scope
  anchor: "#3-non-goals"
  disposition: decide
  summary: "MC1: Non-goals 가 브리프의 범위 항목을 뺐다"
- ref: m2
  category: architecture
  anchor: "#12-files-to-modify"
  disposition: fix
  summary: "MC2: 파일 목록이 확정 제약을 어긴다"
- ref: m3
  category: component_relations
  anchor: "#12-files-to-modify"
  disposition: decide
  summary: "AD3: 파일 사이 의존 방향이 안 닫힌다"
- ref: m4
  category: overdesign
  anchor: "#1-context"
  disposition: decide
  summary: "AD4: 맥락 절이 goal 대비 과하다"
- ref: m5
  category: data_flow
  anchor: "#1-context"
  disposition: ask
  summary: "AD5: 맥락 절의 데이터 흐름이 끊겼나?"
- ref: m17
  category: made_up_axis
  anchor: "#1-context"
  disposition: decide
  summary: "MC17: 루브릭 밖 축의 결함"
```

```docreview-layer2
- ref: m6
  category: ambiguity
  anchor: "#12-files-to-modify"
  disposition: fix
  summary: "AD6: 파일 목록이 두 가지로 읽힌다"
- ref: m7
  category: ambiguity
  anchor: "#12-files-to-modify"
  disposition: ask
  summary: "AD7: b.py 를 남기나?"
  blocks: [m6]
- ref: m8
  category: ambiguity
  anchor: "#2-goals"
  disposition: fix
  summary: "AD8: 목표 B 가 두 가지로 읽힌다"
- ref: m9
  category: scope
  anchor: "#2-goals"
  disposition: fix
  summary: "MC9: 목표 절이 범위를 좁혔다"
- ref: m10
  category: placeholder
  anchor: "#handoff-context"
  disposition: drop
  summary: "AD10: 인계 절에 빈 칸이 있다"
- ref: m11
  category: testing
  anchor: "#12-files-to-modify"
  disposition: defer
  summary: "AD11: 자동 검증 절차는 plan 이 정한다"
- ref: m12
  category: placeholder
  anchor: "#1-context"
  disposition: fix
  summary: "AD12: 맥락 절의 TBD"
- ref: m13
  category: tradeoffs
  anchor: "#1-context"
  disposition: ask
  summary: "AD13: 목표 어긋남 수정을 먼저 하나?"
  blocks: [m14]
- ref: m14
  category: goal_fit
  anchor: "#12-files-to-modify"
  disposition: fix
  summary: "MC14: 파일 목록이 목표를 덮지 않는다"
- ref: m15
  category: problem_definition
  anchor: "#1-context"
  disposition: ask
  summary: "MC15: 맥락 절의 과함을 먼저 정리하나?"
  blocks: [m4]
- ref: m16
  category: other
  anchor: "#1-context"
  disposition: fix
  summary: "MC16: 분류 없는 결함"
- ref: m18
  category: testing
  anchor: "#handoff-context"
  disposition: fix
  summary: "AD18: 인계 절에 검증 전략이 없다"
- ref: m19
  category: isolation
  anchor: "#handoff-context"
  disposition: fix
  summary: "AD19: 인계 절의 부품 경계가 흐리다"
- ref: m20
  category: ambiguity
  anchor: "#1-context"
  disposition: decide
  summary: "AD20: 맥락 절 문장이 두 가지로 읽힌다"
- ref: m21
  category: ambiguity
  anchor: "#handoff-context"
  disposition: ask
  summary: "AD21: 인계 절을 누가 읽나?"
```
````

`recritic-mc-r1.txt.tmpl`:
````text
```docreview-recritic
verdicts:
  - f: "{{F:MC2: 파일 목록이}}"
    verdict: confirm
    same_as: ["{{F:AD3: 파일 사이}}"]
  - f: "{{F:AD18: 인계 절에}}"
    verdict: confirm
    same_as: ["{{F:AD19: 인계 절의}}"]
  - f: "{{F:AD12: 맥락 절의 TBD}}"
    verdict: reject
    evidence: "맥락 절 본문에 TBD 가 없다 — 오탐"
added:
  - category: isolation
    anchor: "#12-files-to-modify"
    layer: 2
    disposition: fix
    summary: "AA1: 부품 경계가 파일 목록에서 흐리다"
```
````

`critic-mc-r2.txt` — 라운드 2(`design-sample-r2.md` — `#2-goals` · `#12` 가 바뀐다):
````text
```docreview-layer1
- ref: r2c
  category: overdesign
  anchor: "#1-context"
  disposition: decide
  summary: "R2C: 맥락 절이 여전히 과하다"
- ref: r2g
  category: tradeoffs
  anchor: "#1-context"
  disposition: decide
  summary: "R2G: 맥락 절의 기각 사유가 확정과 어긋난다"
- ref: r2d
  category: goal_fit
  anchor: "#1-context"
  disposition: decide
  summary: "R2D: 안 바뀐 맥락 절이 목표를 비껴간다"
- ref: r2e
  category: goal_fit
  anchor: "#2-goals"
  disposition: decide
  summary: "R2E: 바뀐 목표 절이 목표를 비껴간다"
- ref: r2f
  category: scope
  anchor: "#3-non-goals"
  disposition: decide
  summary: "R2F: Non-goals 가 여전히 범위를 뺐다"
```

```docreview-layer2
[]
```
````

`critic-mc-child.txt`:
````text
```docreview-layer1
- ref: p1
  category: architecture
  anchor: "#5-architecture"
  disposition: decide
  summary: "MCP: 상위 절이 확정 제약을 어긴다"
- ref: p2
  category: goal_fit
  anchor: "#1-context"
  disposition: decide
  summary: "MCC: 맥락 절이 목표를 비껴간다"
```

```docreview-layer2
[]
```
````

`design-sample-child.md` — 하위 절(`### 5.1 Parts`) 본문만 바뀐 사본:
```bash
sed 's/^부품 설명\.$/부품 설명 (바뀜)./' shared/tests/fixtures/docreview/design-sample.md > shared/tests/fixtures/docreview/design-sample-child.md
diff shared/tests/fixtures/docreview/design-sample.md shared/tests/fixtures/docreview/design-sample-child.md   # 한 줄만
```

- [ ] **Step 2: 실패하는 케이스** — `cases_advice.sh` 끝에 더한다:

```bash
# ── 라우팅 헬퍼 ───────────────────────────────────────────────────────────
adv_has()  { st_yaml "$1" "'$2' in [v['id'] for v in (st.get('advice') or {}).values()]"; }   # adv_has <dir> <id>
adv_cats() { st_yaml "$1" 'sorted(v["category"] for v in (st.get("advice") or {}).values())'; }
id_of()    { jget "$1" "[x['id'] for x in d['findings'] if '$2' in x['summary']][0]"; }       # id_of <fin.json> <요약 조각>
mc_r1() {   # design-doc(must_catch) 라운드 1 — critic-mc-r1 · codex 부재 · recritic-mc-r1 → 상태 디렉토리($d/fin.json)
  route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md" "$FX/critic-mc-r1.txt" "$FX/codex-failed.yaml" "$FX/recritic-mc-r1.txt.tmpl"
}
mc_round() {   # mc_round <dir> <doc> <critic> <out-fin> — 다음 라운드를 codex 부재 · 빈 재비판으로 finalize
  next_round "$1" "$2" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$1" --critic "$(critic_now "$1" "$3")" \
    --codex "$(codex_now "$1" "$FX/codex-failed.yaml")" > "$1/prep-next.json"
  py docreview_route.py finalize --state-dir "$1" --recritic "$FX/recritic-empty.txt" --doc "$2" > "$4"
}

# ── AC1 — brief 프로필 fixture 둘 ──────────────────────────────────────────
case_AC1_brief_direction_only() {
  local d; d="$(route_r1 "$PROF_MC/brief.md" "$FX/brief-sample.md" "$FX/critic-brief-direction.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  assert_eq "$(gsum "$d" 'd["approval_ready"], d["round_gate_needed"]')" "(True, False)" \
    "AC1(i): direction decide 만 나온 라운드 1 — 승인 가능 · 라운드 게이트 없음"
  assert_eq "$(adv_cats "$d")" "['direction']" "AC1(i): direction 은 advice 원장에 있다"
  assert_eq "$(st_yaml "$d" 'len(st["decides"]), len(st["fixes"]), len(st["asks"])')" "(0, 0, 0)" "AC1(i): 차단 원장 셋이 비었다"
  rm -rf "$d"
}
case_AC1_brief_direction_distortion() {
  local d; d="$(route_r1 "$PROF_MC/brief.md" "$FX/brief-sample.md" "$FX/critic-brief-direction-distortion.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  assert_eq "$(st_yaml "$d" 'sorted(st["findings"][i]["category"] for i in list(st["decides"]) + list(st["fixes"]))')" "['distortion']" \
    "AC1(ii): distortion 은 차단 원장(fixes)에 있다"
  assert_eq "$(gsum "$d" 'd["approval_ready"]')" "False" "AC1(ii): 승인이 막힌다"
  assert_eq "$(adv_cats "$d")" "['direction']" "AC1(ii): direction 은 advice 원장에 있다"
  rm -rf "$d"
}

# ── AC3 양의 짝 — 지목하면 참고 키 · 참고 줄이 선다(음은 골든 12파일이 잰다) ─────
case_AC3_reference_line_positive() {
  local d e; d="$(route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md")"; e="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(jget "$d/fin.json" '"advice" in d and "advice_new" in d and "mc_preexisting_new" in d')" "True" \
    "AC3(양의 짝): must_catch 를 지목한 프로필의 보고서에 참고 키가 선다"
  assert_grep "$(py docreview_state.py gate --state-dir "$d" --render)" \
    '^참고 [0-9]+건\(이번 라운드 새 [0-9]+ · 반복 [0-9]+\) — 끝에서 한 목록으로' "AC3(양의 짝): 게이트 렌더에 참고 줄이 선다"
  assert_eq "$(jget "$e/fin.json" '"advice" in d or "advice_new" in d')" "False" "AC3(음): 필드 없는 사본 프로필의 보고서에는 참고 키가 없다"
  assert_not_contains "$(py docreview_state.py gate --state-dir "$e" --render)" "끝에서 한 목록으로" "AC3(음): 필드 없는 사본 프로필의 렌더에는 참고 줄이 없다"
  assert_eq "$(st_yaml "$e" '"advice" in st')" "False" "AC3(음): 필드 없는 사본 프로필의 원장에는 advice 키가 없다"
  rm -rf "$d" "$e"
}

# ── AC13(1 걸음 몫) — 라운드 1 advisory fix 는 fixes, 같은 축 decide · (blocks 없는) ask 는 advice ────
case_AC13_advisory_decide_ask_to_advice() {
  local d f6 f20 f21; d="$(mc_r1)"
  f6="$(fsum "$d" 'AD6:' '["id"]')"; f20="$(fsum "$d" 'AD20:' '["id"]')"; f21="$(fsum "$d" 'AD21:' '["id"]')"
  assert_eq "$(st_yaml "$d" "'$f6' in st['fixes']") $(adv_has "$d" "$f6")" "True False" \
    "AC13: 보호 헤딩 밖 ambiguity fix 는 fixes 원장에 있고 advice 에 없다"
  assert_eq "$(adv_has "$d" "$f20") $(adv_has "$d" "$f21")" "True True" "AC13: 같은 축의 decide · ask 는 advice 에 있다"
  assert_eq "$(st_yaml "$d" "st['findings']['$f20']['route'], '$f20' in st['decides'], '$f21' in st['asks']")" "('advice', False, False)" \
    "AC13: advice 항목은 decides · asks 에 없고 finding 에 route: advice 표지가 있다"
  rm -rf "$d"
}

# ── AC19 — 보호 헤딩 승격분 ──────────────────────────────────────────────────
case_AC19_promoted_advisory_fix() {
  local d f8 f9; d="$(route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md" "$FX/critic-mc-promoted.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  f8="$(fsum "$d" 'AD8:' '["id"]')"
  assert_eq "$(fsum "$d" 'AD8:' '["promoted_from"]') $(adv_has "$d" "$f8")" "fix True" \
    "AC19: 보호 헤딩(Goals) 안 advisory fix 는 decide 로 승격된 뒤 advice 에 있다"
  assert_eq "$(gsum "$d" 'd["round_gate_needed"], d["approval_ready"]')" "(False, True)" "AC19: 승격분은 라운드 게이트를 켜지 않는다"
  rm -rf "$d"; d="$(mc_r1)"; f9="$(fsum "$d" 'MC9:' '["id"]')"
  assert_eq "$(st_yaml "$d" "'$f9' in st['decides'], st['findings']['$f9']['promoted_from']")" "(True, 'fix')" \
    "AC19: 같은 자리의 must-catch fix 는 현행대로 decides 로 승격된다"
  rm -rf "$d"
}

# ── AC5 · AC9 — 라운드 2 의 1회 규칙 · 선재 절의 새 must-catch ─────────────────────
case_AC5_AC9_round2() {
  local d rc_ rg rd; d="$(mc_r1)"
  mc_round "$d" "$FX/design-sample-r2.md" "$FX/critic-mc-r2.txt" "$d/fin2.json"
  rc_="$(id_of "$d/fin2.json" 'R2C:')"; rg="$(id_of "$d/fin2.json" 'R2G:')"; rd="$(id_of "$d/fin2.json" 'R2D:')"
  assert_eq "$(jget "$d/fin2.json" 'd["advice_new"], d["advice_repeat"]')" "(1, 1)" \
    "AC5: 라운드 2 — 새 버킷 1(listed) · 라운드 1 에 오른 버킷 1(repeat)"
  assert_eq "$(adv_has "$d" "$rg") $(adv_has "$d" "$rc_") $(st_yaml "$d" "st['findings']['$rc_']['route']")" "True False advice" \
    "AC5: 새 버킷(R2G)은 목록에 오르고, 반복 버킷(R2C)은 목록에 없고 advice 표지만 단다"
  assert_eq "$(jget "$d/fin2.json" 'd["mc_preexisting_new"]')" "1" \
    "AC9: 해시 불변 절(#1-context)의 새 계보 must-catch(R2D)만 센다 — 바뀐 절(R2E) · 계보 후속(R2F)은 세지 않는다"
  assert_eq "$(st_yaml "$d" "'$rd' in st['decides']")" "True" "AC9: 관측은 동작을 바꾸지 않는다 — R2D 는 decides 에 있다"
  rm -rf "$d"
}
case_AC9_child_section_changed() {
  local d; d="$(route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md" "$FX/critic-mc-empty.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  mc_round "$d" "$FX/design-sample-child.md" "$FX/critic-mc-child.txt" "$d/fin2.json"
  assert_eq "$(jget "$d/fin2.json" 'd["mc_preexisting_new"]')" "1" \
    "AC9: 하위 절(5.1)이 바뀐 상위 앵커(#5-architecture)의 새 must-catch 는 선재로 세지 않는다 — 안 바뀐 #1-context 것만 센다"
  rm -rf "$d"
}
```

`test_docreview_advice.sh` 의 `finish` 앞에 케이스 이름 일곱 줄을 더한다 — `case_AC1_brief_direction_only` 부터 `case_AC9_child_section_changed` 까지 정의 순서대로.

- [ ] **Step 3: 실패 확인**

Run: `bash shared/tests/test_docreview_advice.sh | grep -c '✗'`
Expected: 1 이상. 예: `AC1(i)` 에서 `approval_ready` 가 False 이고 `advice` 원장이 비었다.

- [ ] **Step 4: `docreview_advice.py` 에 더한다**(파일 끝):

```python
def route_step1(final, axes) -> None:
    """1 걸음 — `_classify_items` 의 처분 강제 · 보호 헤딩 승격 뒤. 축과 처분만 보면 정해지는 것:
    advisory 축의 `decide`(보호 헤딩 승격분 포함 — 승격된 항목의 처분은 이미 `decide` 다)와 `blocks` 없는
    `ask`. `blocks` 가 있는 `ask` 는 대상의 적용 경로를 알아야 해서 2 걸음(`route_step2`)이 정한다."""
    for it in final:
        d = it["disposition"]
        if is_advisory(it, axes) and (d == "decide" or (d == "ask" and not it.get("blocks"))):
            it["route"] = ROUTE_ADVICE


def _subtree(snap, anchor) -> dict:
    """앵커 절과 그 하위 절(`parents` 로 도출)의 {앵커: 해시}. 스냅숏 해시는 다음 헤딩(레벨 무관)에서 끊기므로
    자기 절만 보면 상위 앵커의 finding 이 하위 절 변경에도 선재로 세어진다."""
    return {s["anchor"]: s["hash"] for s in snap.get("sections") or []
            if s["anchor"] == anchor or anchor in (s.get("parents") or [])}


def mc_preexisting_new(final, snapshots, n, axes) -> int:
    """라운드 n ≥ 2 에서 must-catch 로 분류된 리뷰어 finding 중 새 계보(`lineage == id`)이고 앵커 절과 그 하위 절
    전부의 해시가 스냅숏 n−1 과 n 에서 같은 것의 수. 동작을 바꾸지 않는 관측값이다 — 전문 재대조에서 재샘플링이
    잦아든다는 가정(RC31)을 다음 사이클이 센다. drop · 엔진 자동 생성 · advisory 는 세지 않는다."""
    if n < 2:
        return 0
    prev, cur = (snapshots or {}).get(str(n - 1)), (snapshots or {}).get(str(n))
    if not prev or not cur:
        return 0
    count = 0
    for it in final:
        if (it.get("route") != ROUTE_ADVICE and it.get("_source") not in ENGINE_SOURCES
                and not is_advisory(it, axes) and it["disposition"] != "drop"
                and it.get("lineage") == it.get("id")):
            before, after = _subtree(prev, it["anchor"]), _subtree(cur, it["anchor"])
            if after and before == after:
                count += 1
    return count
```

- [ ] **Step 5: `docreview_state.py`**

`record_findings` 를 바꾼다 — 기존 줄의 글자는 그대로 두고 두 줄을 끼우며, 반환값을 더한다:

```python
def record_findings(st, findings, n) -> dict:
    """라우팅이 끝난 finding 목록을 원장에 적는다 (route.finalize 와 record-findings CLI 가 부른다).

    `route: advice` 표지를 단 항목은 decides · fixes · asks 대신 `advice` 원장에 간다(`_record_advice`). 낸 값은
    그 계수 {"listed", "repeat"} — 표지 없는 항목만 온 라운드는 둘 다 0 이다."""
    counts = {"listed": 0, "repeat": 0}
    for it in findings:
        fid = it["id"]
        st["findings"][fid] = {k: it.get(k) for k in PUBLIC_FIELDS}
        if it.get("state") == "rejected":
            continue
        if it.get("route") == "advice":
            _record_advice(st, it, n, counts)
            continue
        d = it.get("disposition")
        # … (이하 기존 decide/fix/ask 분기 · held 루프 · _refresh_open_lineages 그대로)
    …
    _refresh_open_lineages(st, n)
    return counts
```

`record_findings` 바로 위에 넣는다:

```python
def _record_advice(st, it, n, counts) -> None:
    """참고(advisory) 항목 — `advice` 원장에 버킷(층|축|앵커) 키로 적는다. 이전 라운드(또는 같은 라운드 앞 항목)가
    올린 버킷은 목록에 다시 올리지 않고 `repeat` 로만 센다(1회 규칙). 원장 키는 필요할 때만 생긴다 — 표지가
    없는 프로필의 원장 파일은 바이트 단위로 현행이다(골든)."""
    st["findings"][it["id"]]["route"] = "advice"
    ledger = st.setdefault("advice", {})
    b = it.get("bucket") or it["id"]
    if b in ledger:
        counts["repeat"] += 1
    else:
        ledger[b] = {"id": it["id"], "round": n, "layer": it.get("layer"), "category": it.get("category"),
                     "anchor": it.get("anchor"), "summary": it.get("summary"),
                     "replacement": it.get("replacement"), "shown": False, "sunk": False}
        counts["listed"] += 1
```

`gate_summary` 의 `return g` 바로 앞에 넣는다:

```python
    # 참고(advisory) — 이번 라운드 보고서에 계수가 있을 때만(= must_catch 를 지목한 프로필). 승인 술어와 무관하다.
    if "advice_new" in rep:
        g["advice"] = {"total": len(st.get("advice") or {}), "new": rep["advice_new"],
                       "repeat": rep["advice_repeat"], "mc_preexisting_new": rep["mc_preexisting_new"]}
```

`render_gate` 의 `out.append("기각 %d건(재비판) · …" % (…))` 문장 바로 다음에 넣는다:

```python
    if g.get("advice") is not None:   # 게이트 질문이 아니다 — 목록은 끝에서 한 번(`advice --render`)
        adv_g = g["advice"]
        out.append("참고 %d건(이번 라운드 새 %d · 반복 %d) — 끝에서 한 목록으로 · 선재 절의 새 must-catch %d"
                   % (adv_g["total"], adv_g["new"], adv_g["repeat"], adv_g["mc_preexisting_new"]))
```

- [ ] **Step 6: `docreview_route.py`**

import 블록(`from docreview_state import (…)` 닫는 괄호) 다음에 넣는다:

```python
from docreview_advice import (  # noqa: E402
    advice_ids, advisory_axes, has_must_catch, mc_preexisting_new, route_step1,
)
```

`_classify_items` 의 `return final, rejected_items` 바로 앞에 넣는다:

```python
    # 참고(advisory) 표지 1 걸음 — 축과 처분만 보면 정해지는 것(docreview_advice.route_step1)
    route_step1(final, advisory_axes(prof))
```

`cmd_finalize` 의 `record_findings(st, final + rejected_items, n)` 부터 `_build_report(…)` 호출까지를 바꾼다:

```python
    advice_counts = record_findings(st, final + rejected_items, n)
    advice_stats = None
    if has_must_catch(prof):   # 새 보고서 키는 must_catch 를 지목한 프로필에서만 — 필드 없는 프로필은 바이트 단위로 현행
        advice_stats = {"advice_new": advice_counts["listed"], "advice_repeat": advice_counts["repeat"],
                        "mc_preexisting_new": mc_preexisting_new(final, st["snapshots"], n, advisory_axes(prof))}
    out = _build_report(L, st, n, final, rejected_items, degrade,
                        {"bucket_conflicts": bucket_conflicts, "lineage_mismatch": lineage_mismatch,
                         "revived": revived, "reraise_unconsumed": reraise_unconsumed,
                         "escalated_unconsumed": escalated_unconsumed}, advice_stats)
```

`_build_report` 는 네 곳을 바꾼다.

- 시그니처를 `def _build_report(L, st, n, final, rejected_items, degrade, stats, advice_stats=None):` 로 바꾼다.
- docstring 끝에 「`advice_stats` 는 must_catch 를 지목한 프로필만 넘긴다 — 없으면 보고서가 현행과 같다」 한 줄을 더한다.
- `"by_disposition"` 줄을 아래로 바꾼다(컴프리헨션 수는 그대로이고 조건만 는다):

```python
        "by_disposition": {d: [it["id"] for it in final if it["disposition"] == d and it.get("route") != "advice"]
                           for d in DISPOSITIONS},
```

- `out = {…}` 닫힌 직후(`for k in ("accepted", …` 루프 앞)에 넣는다:

```python
    if advice_stats is not None:
        out["advice"] = advice_ids(final)
        out.update(advice_stats)
```

그리고 `st["rounds"][str(n)]["route_report"] = {…}` 블록 뒤, `return out` 앞에 넣는다:

```python
    if advice_stats is not None:
        st["rounds"][str(n)]["route_report"].update(advice_stats)
```

- [ ] **Step 7: 통과 확인 · 재앵커**

```bash
bash shared/tests/test_docreview_advice.sh | tail -1
bash shared/tests/test_docreview_golden.sh | tail -1       # AC3 음 — 12파일 바이트 동일
for t in route state anchor intent gate_visibility profiles; do bash shared/tests/test_docreview_$t.sh | tail -1; done
PYTHONDONTWRITEBYTECODE=1 python3 shared/tests/fixtures/adjudication/run_wiring_scan.py "$(pwd)" | grep -E '^(unwired|exempt_stale|comprehensions)=|UNWIRED'
bash shared/tests/test_copy_of_contract.sh | tail -1
bash plugins/quality-gates/tests/test_recritic_bridge.sh | tail -1
```
Expected:
- advice · golden · 여섯 락은 전부 `Fail: 0`.
- 배선 스캔은 `comprehensions=40` 이다. route.py 에 줄이 늘었으므로 `exempt_stale` 은 0 이 아닐 수 있고, 그때는 `UNWIRED` 줄이 새 줄번호를 댄다. `tools/adjudication/check_wiring.py` 의 `EXEMPT` 키에서 **줄번호만** 그 값으로 바꾸고(가드 텍스트 · 사유 · 주석 무변경) 스캔을 다시 돌린다. `unwired=0 exempt_stale=0` 이 될 때까지 반복한다.
- copy-of · recritic_bridge 는 `Fail: 0` 이다(qg 가 route.py 를 import 할 때 형제 `docreview_advice.py` 링크가 잡힌다).

- [ ] **Step 8: 변이 셀** — `test_docreview_mutations.sh` 를 바꾼다.

`run_case` 의 `. "$REPO_ROOT/shared/tests/fixtures/docreview/cases.sh"` 바로 뒤에 `. "$REPO_ROOT/shared/tests/fixtures/docreview/cases_advice.sh"` 를 더한다. 한 줄 안이면 `;` 로 잇는다. `sed_state()` 정의 다음 줄에 `sed_advice()` 를 두고, `finish` 앞에 셀 다섯을 넣는다:

```bash
sed_advice() { sed -i.bak "$1" "$2/docreview_advice.py" && rm -f "$2/docreview_advice.py.bak"; }
```

```bash
# ── 참고(advisory) 라우팅 (설계 2026-09-27-review-stopping-criterion) ─────────────────────
# (61) advisory 여집합을 뒤집는다(advisory = must_catch) — direction 이 must-catch 가 되어 AC1 이 RED.
mut 1/1 advisory_axes_flipped case_AC1_brief_direction_only sed_advice \
  's/    return (frozenset(lr\["layer1"\]) | frozenset(lr\["layer2"\])) - frozenset(mc)/    return frozenset(mc)/'
# (62) 1 걸음 호출을 지운다 — advisory decide 가 decides 에 남아 승인을 막는다.
mut 1/1 route_step1_removed case_AC1_brief_direction_only sed_route \
  's/^    route_step1(final, advisory_axes(prof))$/    pass/'
# (63) 1회 규칙을 지운다 — 라운드 1 에 오른 버킷이 라운드 2 에 다시 listed 된다.
mut 1/1 advice_repeat_rule_removed case_AC5_AC9_round2 sed_state \
  's/^    if b in ledger:$/    if False:/'
# (64) 해시 비교를 지운다 — 바뀐 절의 새 must-catch 까지 선재로 센다.
mut 1/1 mc_hash_compare_removed case_AC5_AC9_round2 sed_advice \
  's/^            if after and before == after:$/            if after:/'
# (65) 하위 절을 빼고 자기 절만 본다 — 하위 절이 바뀐 상위 앵커의 finding 이 선재로 세어진다.
mut 1/1 mc_subtree_dropped case_AC9_child_section_changed sed_advice \
  's/            if s\["anchor"\] == anchor or anchor in (s.get("parents") or \[\])}/            if s["anchor"] == anchor}/'
```

Run: `bash shared/tests/test_docreview_mutations.sh | grep -E '\((6[1-5])\)|advisory_axes_flipped|route_step1_removed|advice_repeat_rule_removed|mc_hash_compare_removed|mc_subtree_dropped'`
Expected: 다섯 셀 전부 `✓ 변이 '<이름>' → <케이스> RED(n) … [churn 1/1]`. `치환 앵커 소실` 이 나오면 sed 문자열과 Step 4~6 의 줄이 한 글자라도 다른 것이다 — 코드가 아니라 셀을 고친다(코드 줄은 이 계획이 정본).

- [ ] **Step 9: 커밋**

```bash
git add shared/docreview/scripts/docreview_advice.py shared/docreview/scripts/docreview_route.py shared/docreview/scripts/docreview_state.py \
  tools/adjudication/check_wiring.py shared/tests/fixtures/docreview/ shared/tests/test_docreview_advice.sh shared/tests/test_docreview_mutations.sh
git commit -m "$(printf 'feat(docreview): 참고 축 1 걸음 표지 · advice 원장(1회 규칙) · 계수 · 게이트 참고 줄\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>')"
git status --porcelain
```

---

### Task 6: 병합 생존자 · 2 걸음 표지 (AC2·AC8·AC13·AC14·AC15·AC18)

**Files:**
- Modify: `shared/docreview/scripts/docreview_advice.py` (`route_step2` · `_judge_blocking_ask`)
- Modify: `shared/docreview/scripts/docreview_route.py` (`_absorb_same_as` 한 줄 · `cmd_finalize` 2 걸음 호출 · import)
- Modify: `tools/adjudication/check_wiring.py` (`EXEMPT` 줄번호)
- Create(픽스처): `shared/tests/fixtures/docreview/{critic-mc-r2-fix.txt,critic-mc-dangling.txt,ac8_terms.py}`
- Test: `cases_advice.sh` · `test_docreview_advice.sh` · `test_docreview_mutations.sh`

**Interfaces:**
- Consumes: Task 4 의 `is_advisory` · `member_categories`, Task 5 의 `route_step1` · 원장 · 보고서.
- Produces: `route_step2(final: list, keep_of: dict, axes: frozenset, n: int, L) -> None`. 병합 생존자에는 `items[keep]["_member_categories"]` 가 붙는다. 이 키는 비공개(`_` 접두)라 `fin.json` · 원장에 안 실린다.

- [ ] **Step 1: 픽스처**

`critic-mc-r2-fix.txt`:
````text
```docreview-layer1
[]
```

```docreview-layer2
- ref: r2a
  category: handoff_incomplete
  anchor: "#1-context"
  disposition: fix
  summary: "R2A: 맥락 절의 인계 정보가 모자란다"
- ref: r2b
  category: ambiguity
  anchor: "#12-files-to-modify"
  disposition: fix
  summary: "R2B: 파일 목록이 여전히 두 가지로 읽힌다"
```
````

`critic-mc-dangling.txt`:
````text
```docreview-layer1
- ref: g1
  category: data_flow
  anchor: "#1-context"
  disposition: ask
  summary: "DG1: 없는 항목을 막는다는 참고 질문"
  blocks: [zz9]
- ref: g2
  category: problem_definition
  anchor: "#1-context"
  disposition: ask
  summary: "DG2: 없는 항목을 막는다는 must-catch 질문"
  blocks: [zz8]
```

```docreview-layer2
[]
```
````

`ac8_terms.py`:
```python
#!/usr/bin/env python3
"""ac8_terms.py <prep.json> <fin.json> <added> — AC8 단계별 등식의 항을 JSON 목록으로 낸다.
[입력(critic+codex 정규화), 재비판 added, same_as 흡수, 재비판 기각, drop, 차단 원장 생존자(decide+fix+ask+defer, 축 무관), advice(listed+repeat)]
그리고 둘째 줄에 좌변 == 우변 여부. 엔진 자동 생성분은 별도 유입이다 — 호출자는 라운드 1(유입 0)에서 부른다."""
from __future__ import annotations

import io
import json
import sys

prep = json.load(io.open(sys.argv[1], encoding="utf-8"))
fin = json.load(io.open(sys.argv[2], encoding="utf-8"))
added = int(sys.argv[3])
bd = fin["by_disposition"]
terms = [len(prep["items"]), added, fin["adjudication_absorbed"], len(fin["rejected"]), len(bd["drop"]),
         sum(len(bd[k]) for k in ("decide", "fix", "ask", "defer")), fin["advice_new"] + fin["advice_repeat"]]
print(json.dumps(terms))
print(terms[0] + terms[1] == sum(terms[2:]))
```

- [ ] **Step 2: 실패하는 케이스** — `cases_advice.sh` 끝에 더한다:

```bash
# ── AC2 — 정의가 fail-closed ─────────────────────────────────────────────────
case_AC2_mustcatch_fail_closed() {
  local d d2 f6 esc; d="$(mc_r1)"
  assert_eq "$(st_yaml "$d" '[st["findings"][i]["category"] for i in st["decides"] if st["findings"][i]["category"] == "made_up_axis"]')" \
    "['made_up_axis']" "AC2: rubric 밖 category 는 must_catch 가 있는 프로필에서도 decides 에 있다"
  assert_eq "$(st_yaml "$d" '[st["findings"][i]["category"] for i in st["fixes"] if st["findings"][i]["category"] == "other"]')" \
    "['other']" "AC2: other 는 fixes 에 있다"
  assert_eq "$(adv_has "$d" "$(fsum "$d" 'AD4:' '["id"]')")" "True" "AC2 대조: advisory 축(overdesign) decide 는 advice 에 있다(여집합이 뒤집히면 RED)"
  mc_round "$d" "$FX/design-sample-r2.md" "$FX/critic-mc-empty.txt" "$d/fin2.json"
  assert_eq "$(st_yaml "$d" 'sorted({st["findings"][i]["category"] for i in st["decides"] if st["findings"][i]["category"] == "frozen_change"}), [v for v in (st.get("advice") or {}).values() if v["category"] == "frozen_change"]')" \
    "(['frozen_change'], [])" "AC2: frozen_change 는 decides 에 있고 advice 에 없다"
  rm -rf "$d"
  d2="$(mc_r1)"; f6="$(fsum "$d2" 'AD6:' '["id"]')"
  py docreview_state.py fix --state-dir "$d2" --id "$f6" --event escalate --reason 'anchor_protected' >/dev/null
  mc_round "$d2" "$FX/design-sample.md" "$FX/critic-mc-empty.txt" "$d2/fin2.json"
  esc="$(id_of "$d2/fin2.json" '상향: AD6')"
  assert_eq "$(st_yaml "$d2" "'$esc' in st['decides'], st['findings']['$esc']['category']") $(adv_has "$d2" "$esc")" "(True, 'ambiguity') False" \
    "AC2: advisory 축 fix 의 check-intent 거부 상향 후속(_source: escalated)은 decides 에 있고 advice 에 없다"
  rm -rf "$d2"
}

# ── AC13 예외 · AC15 — blocks 판정은 대상의 적용 경로로 ─────────────────────────────
case_AC13_blocking_ask_stays() {
  local d f6 f7; d="$(mc_r1)"; f6="$(fsum "$d" 'AD6:' '["id"]')"; f7="$(fsum "$d" 'AD7:' '["id"]')"
  assert_eq "$(st_yaml "$d" "'$f7' in st['asks'], st['asks'].get('$f7', {}).get('blocks')") $(adv_has "$d" "$f7")" "(True, ['$f6']) False" \
    "AC13: fixes 원장 항목을 blocks 로 가리키는 advisory ask 는 asks 에 있다"
  rm -rf "$d"
}
case_AC15_blocks_by_application_path() {
  local d f6 f7 f13 f14 f15; d="$(mc_r1)"
  f6="$(fsum "$d" 'AD6:' '["id"]')"; f7="$(fsum "$d" 'AD7:' '["id"]')"; f13="$(fsum "$d" 'AD13:' '["id"]')"
  f14="$(fsum "$d" 'MC14:' '["id"]')"; f15="$(fsum "$d" 'MC15:' '["id"]')"
  assert_eq "$(gsum "$d" "sorted(d['blocking_ask_open']) == sorted(['$f7', '$f13'])")" "True" \
    "AC15: advisory ask 가 fixes 에 남는 fix 를 막으면 — must-catch fix(①)든 advisory fix(②)든 — 차단 ask 다"
  assert_eq "$(st_yaml "$d" "st['fixes']['$f14']['state'], st['fixes']['$f6']['state']")" "('held', 'held')" \
    "AC15: 그 fix 둘은 held 다 — 질문이 막는 fix 가 답 없이 적용되지 않는다"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_coerced"]') $(st_yaml "$d" "st['asks']['$f15']['blocks']")" "1 []" \
    "AC15: 차단 ask 의 blocks 중 advice 로 간 ref 는 조용히 버려지지 않고 coerced 로 1 세어진다"
  rm -rf "$d"
}

# ── AC14 — 병합 생존자 ───────────────────────────────────────────────────────
case_AC14_merge_survivor() {
  local d s s2; d="$(mc_r1)"; s="$(fsum "$d" 'AD3:' '["id"]')"
  assert_eq "$(st_yaml "$d" "'$s' in st['decides']") $(adv_has "$d" "$s") $(jget "$d/fin.json" 'any("MC2:" in x["summary"] for x in d["findings"])')" "True False False" \
    "AC14: architecture(must-catch · fix) + component_relations(advisory · decide) 병합 생존자는 처분 순위와 무관하게 must-catch 원장(decides)에 있다"
  s2="$(jget "$d/fin.json" '[x["id"] for x in d["findings"] if x["summary"].startswith(("AD18:", "AD19:"))][0]')"
  assert_eq "$(st_yaml "$d" "'$s2' in st['fixes']") $(adv_has "$d" "$s2")" "True False" \
    "AC14: 구성원이 전부 advisory 인 라운드 1 fix 끼리의 병합 생존자는 fixes 에 있다"
  rm -rf "$d"
}

# ── AC18 — 라운드 2 의 새 계보 advisory fix ─────────────────────────────────────
case_AC18_round2_new_advisory_fix() {
  local d ra rb; d="$(mc_r1)"
  mc_round "$d" "$FX/design-sample-r2.md" "$FX/critic-mc-r2-fix.txt" "$d/fin2.json"
  ra="$(id_of "$d/fin2.json" 'R2A:')"; rb="$(id_of "$d/fin2.json" 'R2B:')"
  assert_eq "$(adv_has "$d" "$ra") $(st_yaml "$d" "'$ra' in st['fixes']") $(gsum "$d" "'$ra' in d['unapplied_fix']")" "True False False" \
    "AC18: 라운드 2 에서 새 계보의 advisory fix 는 advice 에 있고 승인을 막지 않는다"
  assert_eq "$(st_yaml "$d" "'$rb' in st['fixes'], st['findings']['$rb']['lineage'] != '$rb'") $(gsum "$d" "'$rb' in d['unapplied_fix']")" "(True, True) True" \
    "AC18: 라운드 1 에서 온 계보의 advisory fix(미적용)는 fixes 에 남아 막는다"
  rm -rf "$d"
}

# ── AC8 — 단계별 등식 ─────────────────────────────────────────────────────────
case_AC8_staged_equation() {
  local d out; d="$(mc_r1)"
  out="$(python3 "$FX/ac8_terms.py" "$d/prep.json" "$d/fin.json" 1)"
  assert_eq "$(printf '%s\n' "$out" | head -1)" "[21, 1, 2, 1, 1, 13, 5]" \
    "AC8: 입력 21 · added 1 · 흡수 2 · 기각 1 · drop 1 · 차단 원장 생존자 13 · advice 5 — 각 항이 0 이 아니다"
  assert_eq "$(printf '%s\n' "$out" | tail -1)" "True" "AC8: 입력 + added = 흡수 + 기각 + drop + 생존자 + advice (합계 하한이 아니라 등식)"
  assert_eq "$(jget "$d/fin.json" '[x["f"] for x in d["findings"] if x["summary"].startswith("AA1:")]')" "['a1']" "AC8 전제: 재비판 added 한 건이 finding 에 있다"
  rm -rf "$d"
}

# ── Review Focus 4 — 없는 f 를 막는 ask ─────────────────────────────────────────
case_advice_dangling_blocks() {
  local d g1 g2; d="$(route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md" "$FX/critic-mc-dangling.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  g1="$(fsum "$d" 'DG1:' '["id"]')"; g2="$(fsum "$d" 'DG2:' '["id"]')"
  assert_eq "$(adv_has "$d" "$g1") $(st_yaml "$d" "'$g2' in st['asks'], st['asks']['$g2']['blocks']")" "True (True, [])" \
    "Review Focus: 대상을 찾을 수 없는 advisory ask 는 advice, must-catch ask 는 asks 에 남는다(없는 ref 는 현행대로 blocks 에서 빠진다)"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_coerced"]')" "0" "Review Focus: 없는 ref 는 advice 대상이 아니라 강제 계수가 늘지 않는다"
  rm -rf "$d"
}
```

`test_docreview_advice.sh` 의 `finish` 앞에 이 일곱 케이스 이름을 정의 순서대로 더한다.

- [ ] **Step 3: 실패 확인**

Run: `bash shared/tests/test_docreview_advice.sh | grep '✗'`
Expected: 다음이 ✗ 다 — AC13 예외(`f7` 은 asks 에 있지만 blocks 는 그대로), AC14(`AD3` 이 advice), AC15(coerced 0), AC18(`R2A` 가 fixes), AC8(값이 다르다).

- [ ] **Step 4: `docreview_advice.py` 에 더한다**(`route_step1` 다음):

```python
def route_step2(final, keep_of, axes, n, L) -> None:
    """2 걸음 — `_resolve_ids_and_lineage` 뒤 · `_remap_blocks` 직전. 계보를 알아야 정해지는 것.

    ① 라운드 n ≥ 2 에서 새 계보(`lineage == id` — 계보 연결 · 재상승 후속이 아님)로 나온 advisory `fix` → advice.
       계보를 잇는 fix 는 fixes 에 남아 막는다(라운드 1 에서 온 미적용 의무).
    ② `blocks` 가 있는 `ask` — 판정은 축이 아니라 대상의 적용 경로다(`_judge_blocking_ask`)."""
    if n >= 2:
        for it in final:
            if it["disposition"] == "fix" and is_advisory(it, axes) and it.get("lineage") == it.get("id"):
                it["route"] = ROUTE_ADVICE
    by_f = {it["f"]: it for it in final if it.get("f")}
    for it in final:
        if it["disposition"] == "ask" and it.get("blocks"):
            _judge_blocking_ask(it, by_f, keep_of, axes, L)


def _judge_blocking_ask(it, by_f, keep_of, axes, L) -> None:
    """advice 가 아닌 대상이 하나라도 있으면 asks 에 남는다(축 무관 — 답 전까지 그 fix 는 held). advisory ask 는
    대상이 전부 advice 거나 찾을 수 없으면 advice 다. asks 에 남는 ask 의 `blocks` 중 advice 대상 ref 는 조용히
    버리지 않고 `coerced("blocks", ref, None)` 로 센다 — 없는 ref 는 현행대로 `_remap_blocks` 가 거른다."""
    targets = [by_f.get(keep_of.get(r, r)) for r in it["blocks"]]
    live = [t for t in targets if t is not None]
    if is_advisory(it, axes) and all(t.get("route") == ROUTE_ADVICE for t in live):
        it["route"] = ROUTE_ADVICE
    else:
        kept = []
        for r, t in zip(it["blocks"], targets):
            if t is not None and t.get("route") == ROUTE_ADVICE:
                L.coerced("blocks", r, None)
            else:
                kept.append(r)
        it["blocks"] = kept
```

- [ ] **Step 5: `docreview_route.py`**

import 블록의 이름 목록에 `member_categories` 와 `route_step2` 를 더한다(알파벳 순). `_absorb_same_as` 의 `keep = max(live, key=lambda m: (RANK[items[m]["disposition"]], m))` 줄은 **그대로** 둔다(변이 셀 앵커). 그 바로 다음 줄에 넣는다:

```python
        # 병합 생존자의 축 소속 — 기각되지 않은 구성원 하나라도 must-catch 축이면 생존자가 must-catch 다
        # (docreview_advice.is_advisory). 분류는 흡수 «뒤»에 돌므로 구성원의 축을 여기서 남긴다.
        items[keep]["_member_categories"] = member_categories(items, live)
```

`cmd_finalize` 의 `bucket_conflicts, lineage_mismatch, revived = _resolve_ids_and_lineage(…)` 와 `_remap_blocks(final, keep_of, a.doc, st)` 사이에 넣는다:

```python
    # 참고(advisory) 표지 2 걸음 — 계보를 알아야 정해지는 것(라운드 ≥2 새 계보 fix · `blocks` 의 적용 경로)
    route_step2(final, keep_of, advisory_axes(prof), n, L)
```

- [ ] **Step 6: 통과 확인 · 재앵커** — Task 5 Step 7 과 같은 명령을 돈다(`EXEMPT` 줄번호 재앵커 포함). Expected 도 같다.

- [ ] **Step 7: 변이 셀** — `test_docreview_mutations.sh` 의 (65) 뒤에 넣는다:

```bash
# (66) 여집합 반전 — AC2 의 대조 단언(advisory decide 가 advice)이 RED.
mut 1/1 advisory_axes_flipped_ac2 case_AC2_mustcatch_fail_closed sed_advice \
  's/    return (frozenset(lr\["layer1"\]) | frozenset(lr\["layer2"\])) - frozenset(mc)/    return frozenset(mc)/'
# (67) 엔진 자동 생성 항목을 건너뛰지 않는다 — escalated 후속이 category(ambiguity)로 advisory 가 된다.
mut 1/1 engine_source_skip_removed case_advice_engine_items_mustcatch sed_advice \
  's/^    if it.get("_source") in ENGINE_SOURCES:$/    if False:/'
# (68) 병합 구성원의 축을 보지 않는다 — must-catch 가 advisory 생존자에 흡수돼 차단에서 빠진다.
mut 1/1 member_categories_ignored case_AC14_merge_survivor sed_advice \
  's/^    cats = it.get("_member_categories") or \[it\["category"\]\]$/    cats = [it["category"]]/'
# (69) blocks 판정을 축으로 되돌린다 — fixes 를 막는 advisory ask 가 advice 로 빠지고 fix 가 held 가 안 된다.
mut 1/1 blocks_by_axis case_AC15_blocks_by_application_path sed_advice \
  's/^    if is_advisory(it, axes) and all(t.get("route") == ROUTE_ADVICE for t in live):$/    if is_advisory(it, axes):/'
# (70) advice 로 간 ref 를 세지 않고 버린다.
mut 1/1 blocks_ref_uncounted case_AC15_blocks_by_application_path sed_advice \
  's/^                L.coerced("blocks", r, None)$/                pass/'
# (71) 라운드 ≥2 새 계보 advisory fix 규칙을 지운다 — 적용 관측 때문에 라운드가 는다.
mut 1/1 round2_new_fix_rule_removed case_AC18_round2_new_advisory_fix sed_advice \
  's/^    if n >= 2:$/    if False:/'
# (72) 2 걸음 호출을 지운다.
mut 1/1 route_step2_removed case_AC15_blocks_by_application_path sed_route \
  's/^    route_step2(final, keep_of, advisory_axes(prof), n, L)$/    pass/'
```

(67)의 케이스가 단위 케이스인 이유가 있다. escalated 후속은 1 걸음(`_classify_items`) **뒤**에 붙어 두 걸음 어디에서도 판정 대상이 아니다. 그래서 끝에서 끝 경로로는 이 가드에 이빨이 없다. 이 가드는 「호출 순서에 기대지 않는다」(§A)의 방어선이라 단위로 잰다.

Run: `bash shared/tests/test_docreview_mutations.sh | grep -E 'advisory_axes_flipped_ac2|engine_source_skip_removed|member_categories_ignored|blocks_by_axis|blocks_ref_uncounted|round2_new_fix_rule_removed|route_step2_removed'`
Expected: 일곱 셀 전부 ✓ · `churn 1/1`.

- [ ] **Step 8: 커밋**

```bash
git add shared/docreview/scripts/docreview_advice.py shared/docreview/scripts/docreview_route.py tools/adjudication/check_wiring.py \
  shared/tests/fixtures/docreview/ shared/tests/test_docreview_advice.sh shared/tests/test_docreview_mutations.sh
git commit -m "$(printf 'feat(docreview): 병합 생존자의 축 소속 · 2 걸음 표지(blocks 적용 경로 · r>=2 새 fix)\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>')"
```

---

### Task 7: `advice` 서브커맨드 — 한 번 표시 · 박제 · 계수 줄 (AC6·AC7·AC17)

**Files:**
- Modify: `shared/docreview/scripts/docreview_advice.py` (상수 셋 · `clip` · `render_lines` · `sink_row` · `review_identity` · `count_key` · `count_line`)
- Modify: `shared/docreview/scripts/docreview_state.py` (`cmd_advice` · `build_parser` · 모듈 docstring 의 서브커맨드 목록)
- Create(픽스처): `shared/tests/fixtures/docreview/{mk_advice_critic.py,critic-mc-odd.txt}`
- Test: `cases_advice.sh` · `test_docreview_advice.sh` · `test_docreview_mutations.sh`

**Interfaces:**
- Consumes: Task 5 의 `st["advice"]` · `route_report` 계수.
- Produces(CLI): `docreview_state.py advice --state-dir D [--render] [--cap N] [--where LABEL] [--sink DOC] [--log-file FILE]`.
  - 한 호출 안의 순서는 sink → log-file → render 다.
  - `--render` 면 stdout 은 렌더 텍스트다. 아니면 JSON `{"ok": true, "items": [...], "sunk": k, "logged_rounds": [n...]}` 이다.
  - 실패 사유(rc 1): `profile_has_no_must_catch` · `profile_has_no_defer_target`(`--sink`) · `profile_decision_log_is_state_only`(`--log-file`) · `cap_invalid`.
  - 계수 줄의 모양은 `- docreview 계수 — <세션>/<문서 키> r<n>: advice_new=k · advice_repeat=r · mc_preexisting_new=m` 이다.

- [ ] **Step 1: 픽스처**

`mk_advice_critic.py`:
```python
#!/usr/bin/env python3
"""mk_advice_critic.py <n> <out> — design-doc advisory 축 decide n 개(서로 다른 버킷, 전부 #1-context)를 담은 critic
출력을 쓴다(1 ≤ n ≤ 12). 요약은 「참고 항목 k — <축>」, 대체안은 「고칠 방법 k」."""
from __future__ import annotations

import io
import sys

AXES = ["component_relations", "data_flow", "tradeoffs", "feasibility", "overdesign", "placeholder",
        "ambiguity", "scope_creep", "approaches_comparison", "isolation", "testing", "handoff_incomplete"]
n = int(sys.argv[1])
if not 0 < n <= len(AXES):
    sys.exit("n 은 1..%d" % len(AXES))
rows = ["```docreview-layer1"]
for k, cat in enumerate(AXES[:n], 1):
    rows += ["- ref: p%d" % k, "  category: %s" % cat, '  anchor: "#1-context"', "  disposition: decide",
             '  summary: "참고 항목 %d — %s"' % (k, cat), '  replacement: "고칠 방법 %d"' % k]
rows += ["```", "", "```docreview-layer2", "[]", "```", ""]
io.open(sys.argv[2], "w", encoding="utf-8").write("\n".join(rows))
```

`critic-mc-odd.txt` — 파이프 · 개행 · 긴 요약:
````text
```docreview-layer1
- ref: o1
  category: tradeoffs
  anchor: "#1-context"
  disposition: decide
  summary: "파이프 | 가 든 요약이고\n둘째 줄로 이어지며 한 줄 폭 예순 자를 넘기도록 길게 늘인 문장이다 — 끝에서 잘려야 하고 그 뒤로도 계속 이어진다"
  replacement: "고치면 A | B 로 나눈다"
```

```docreview-layer2
[]
```
````

- [ ] **Step 2: 실패하는 케이스** — `cases_advice.sh` 끝에 더한다:

```bash
# ── advice 서브커맨드 ───────────────────────────────────────────────────────
adv_state() {   # adv_state <n> → 참고 항목 n 개를 가진 design-doc 라운드 1 상태 디렉토리
  local c; c="$(mktemp -t advcritic-XXXXXX)"; python3 "$FX/mk_advice_critic.py" "$1" "$c"
  route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md" "$c" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt"
  rm -f "$c"
}
adv_ident() { python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import docreview_advice as a; print(a.review_identity(sys.argv[2]))' "$SCRIPTS" "$1"; }

case_AC6_render_cap() {
  local d out; d="$(adv_state 11)"
  out="$(py docreview_state.py advice --state-dir "$d" --render --cap 8)"
  assert_eq "$(printf '%s\n' "$out" | grep -c '^- \[') $(printf '%s\n' "$out" | grep -c '외 3건') $(printf '%s\n' "$out" | grep -c .)" "8 1 10" \
    "AC6: 11건 → 항목 8줄 + 「외 3건」 한 줄 · 머리 포함 10줄(≤10)"
  rm -rf "$d"; d="$(adv_state 8)"
  out="$(py docreview_state.py advice --state-dir "$d" --render --cap 8)"
  assert_eq "$(printf '%s\n' "$out" | grep -c '^- \[') $(printf '%s\n' "$out" | grep -c '외 ')" "8 0" "AC6: 8건이면 접는 줄이 없다"
  rm -rf "$d"; d="$(adv_state 11)"
  out="$(py docreview_state.py advice --state-dir "$d" --render)"
  assert_eq "$(printf '%s\n' "$out" | grep -c '^- \[') $(printf '%s\n' "$out" | grep -c '외 3건')" "8 1" "AC6: 기본 cap 이 8 이다"
  rm -rf "$d"
}
case_AC7_sink_idempotent() {
  local d b doc before rc; d="$(adv_state 3)"; doc="$(mktemp -t sinkdoc-XXXXXX)"; cp "$FX/design-sample.md" "$doc"
  py docreview_state.py advice --state-dir "$d" --sink "$doc" >/dev/null
  assert_eq "$(awk '/^### Deferred to plan$/{f=1;next} /^#/{f=0} f' "$doc" | grep -c '^| .* | 참고(')" "3" \
    "AC7: --sink 가 ### Deferred to plan 아래에 미박제 항목 3건을 표 행으로 적는다"
  before="$(cksum < "$doc")"; py docreview_state.py advice --state-dir "$d" --sink "$doc" >/dev/null
  assert_eq "$(cksum < "$doc")" "$before" "AC7: 두 번째 --sink 는 아무것도 더 적지 않는다(멱등)"
  b="$(route_r1 "$PROF_MC/brief.md" "$FX/brief-sample.md" "$FX/critic-brief-direction.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  py docreview_state.py advice --state-dir "$b" --sink "$doc" >/dev/null 2>"$b/err"; rc=$?
  assert_eq "$rc $(grep -c profile_has_no_defer_target "$b/err")" "1 1" "AC7: brief 프로필(defer_target none)은 profile_has_no_defer_target rc 1"
  rm -rf "$d" "$b" "$doc"
}
case_AC17_count_line_carrier() {
  local d e doc id_d; d="$(adv_state 2)"; e="$(adv_state 2)"; doc="$(mktemp -t logdoc-XXXXXX)"; cp "$FX/design-sample.md" "$doc"
  id_d="$(adv_ident "$d")"
  py docreview_state.py advice --state-dir "$d" --log-file "$doc" >/dev/null
  py docreview_state.py advice --state-dir "$d" --log-file "$doc" >/dev/null
  assert_eq "$(grep -cF -- "- docreview 계수 — $id_d r1: advice_new=2 · advice_repeat=0 · mc_preexisting_new=0" "$doc")" "1" \
    "AC17: 계수 줄이 decision_log 절에 한 번 — 두 번째 호출은 같은 (리뷰 정체, 라운드) 줄을 다시 적지 않는다"
  py docreview_state.py advice --state-dir "$e" --log-file "$doc" >/dev/null
  assert_eq "$(grep -c '^- docreview 계수 — .* r1: ' "$doc")" "2" "AC17: 다른 리뷰 정체의 같은 라운드 줄은 적는다"
  rm -rf "$d" "$e"
  assert_eq "$(grep -cF "docreview 계수 — $id_d r1:" "$doc") $(grep -c '^## 결정 기록$' "$doc")" "1 1" \
    "AC17: 엔진 상태 디렉토리를 지워도 줄이 목적지 파일의 ## 결정 기록 절에 남는다"
  rm -f "$doc"
}
case_advice_render_once() {
  local d; d="$(adv_state 3)"
  py docreview_state.py advice --state-dir "$d" --render >/dev/null
  assert_eq "$(py docreview_state.py advice --state-dir "$d" --render | head -1 | grep -c '^참고(advisory) 0건')" "1" \
    "Review Focus: 두 번째 --render 는 이미 보인 항목을 다시 내지 않는다(shown 표지 — 멱등)"
  assert_eq "$(py docreview_state.py advice --state-dir "$d" | jgets '[it["shown"] for it in d["items"]]')" "[True, True, True]" \
    "Review Focus: 플래그 없는 호출은 읽기 전용 JSON 이고 shown 표지를 싣는다"
  rm -rf "$d"
}
case_advice_pre_upgrade_ledger() {
  local d n rc; d="$(route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md" "$FX/critic-mc-empty.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import docreview_state as s
st = s.load_state(sys.argv[2]); st.pop("advice", None)
for r in st["rounds"].values():
    for k in ("advice_new", "advice_repeat", "mc_preexisting_new"):
        (r.get("route_report") or {}).pop(k, None)
s.save_state(sys.argv[2], st)' "$SCRIPTS" "$d"
  assert_not_contains "$(py docreview_state.py gate --state-dir "$d" --render)" "끝에서 한 목록으로" "Review Focus: 업그레이드 전 원장 — 게이트 렌더에 참고 줄이 없고 죽지 않는다"
  assert_eq "$(py docreview_state.py advice --state-dir "$d" --render | head -1 | grep -c '^참고(advisory) 0건')" "1" "Review Focus: 업그레이드 전 원장 — --render 는 0건"
  n="$(mktemp -t pre-XXXXXX)"; cp "$FX/design-sample.md" "$n"
  py docreview_state.py advice --state-dir "$d" --log-file "$n" >/dev/null; rc=$?
  assert_eq "$rc $(grep -c 'docreview 계수' "$n")" "0 0" "Review Focus: 업그레이드 전 원장 — --log-file 은 계수 줄 0 · rc 0"
  rm -rf "$d" "$n"
  d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  py docreview_state.py advice --state-dir "$d" >/dev/null 2>"$d/err"; rc=$?
  assert_eq "$rc $(grep -c profile_has_no_must_catch "$d/err")" "1 1" "Review Focus: must_catch 없는 프로필의 advice 는 profile_has_no_must_catch rc 1"
  rm -rf "$d"
}
case_advice_odd_text_one_line() {
  local d doc out row; d="$(route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md" "$FX/critic-mc-odd.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  doc="$(mktemp -t odd-XXXXXX)"; cp "$FX/design-sample.md" "$doc"
  out="$(py docreview_state.py advice --state-dir "$d" --sink "$doc" --render)"
  assert_eq "$(printf '%s\n' "$out" | grep -c .) $(printf '%s\n' "$out" | grep -c '^- \[tradeoffs\] #1-context — 파이프 | 가 든 요약이고 둘째 줄로.*…$')" "2 1" \
    "Review Focus: 개행이 든 긴 요약도 렌더 항목은 한 줄이고 60자에서 「…」로 잘린다"
  row="$(awk '/^### Deferred to plan$/{f=1;next} /^#/{f=0} f' "$doc" | grep '참고(tradeoffs)')"
  assert_eq "$(printf '%s\n' "$row" | grep -c .) $(printf '%s\n' "$row" | grep -o '\\|' | wc -l | tr -d ' ')" "1 2" \
    "Review Focus: 박제 행은 한 줄이고 요약 · 대체안의 | 가 \\| 로 이스케이프된다"
  rm -rf "$d" "$doc"
}
```

`test_docreview_advice.sh` 의 `finish` 앞에 이 여섯 케이스 이름을 더한다.

- [ ] **Step 3: 실패 확인**

Run: `bash shared/tests/test_docreview_advice.sh | grep -c '✗'`
Expected: 1 이상(`invalid choice: 'advice'` — argparse rc 2).

- [ ] **Step 4: `docreview_advice.py`**

`ROUTE_ADVICE = "advice"` 다음에 상수를 더한다:

```python
RENDER_CAP = 8          # 끝의 한 번 표시 — 머리 1 + 항목 8 + 접는 줄 1 = 10줄(⟨D9⟩)
SUMMARY_WIDTH = 60      # 렌더 항목 줄의 요약 폭(코드포인트) — 넘치면 59 + 「…」
COUNT_PREFIX = "docreview 계수 — "
```

파일 맨 위 `from __future__ import annotations` 다음에 `import re` 와 `from pathlib import Path` 를 더한다. 파일 끝에 더한다:

```python
def _one_line(s) -> str:
    return re.sub(r"\s+", " ", str(s or "")).strip()


def clip(s, width=SUMMARY_WIDTH) -> str:
    s = _one_line(s)
    return s if len(s) <= width else s[:width - 1] + "…"


def render_lines(items, cap, where) -> list:
    """끝의 한 번 표시 — 머리 한 줄 + 항목 한 줄씩(최대 cap) + 넘치면 접는 줄 한 줄. 합계 ≤ cap + 2."""
    out = ["참고(advisory) %d건 — 게이트 질문이 아니고 승인을 막지 않는다 · 전문: %s" % (len(items), where)]
    for it in items[:cap]:
        out.append("- [%s] %s — %s" % (it.get("category"), it.get("anchor"), clip(it.get("summary"))))
    if len(items) > cap:
        out.append("  … 외 %d건 — %s 에 전부" % (len(items) - cap, where))
    return out


def sink_row(it) -> str:
    """박제처 절(`defer_target`)의 표 행 한 줄 — 요약(+ 대체안)을 접고 `|` 를 이스케이프한다."""
    text = _one_line(it.get("summary"))
    if it.get("replacement"):
        text += " — 고치면: " + _one_line(it["replacement"])
    return "| %s | 참고(%s) %s — %s |" % (it.get("id"), it.get("category"), it.get("anchor"), text.replace("|", "\\|"))


def review_identity(state_dir) -> str:
    """영속 계수 줄의 리뷰 정체 — `<세션>/<문서 키>`. 문서별 상태 디렉토리가 `<root>/<세션>/docreview/<이름표>-<해시>`
    이므로 마지막 조각(문서 키)만으로는 세션이 빠져 같은 문서의 다른 세션 리뷰가 한 키로 겹친다."""
    p = Path(state_dir)
    return "%s/%s" % (p.parent.parent.name, p.name)


def count_key(identity, rnd) -> str:
    return "%s%s r%d:" % (COUNT_PREFIX, identity, rnd)


def count_line(identity, rnd, rep) -> str:
    return "- %s advice_new=%d · advice_repeat=%d · mc_preexisting_new=%d" % (
        count_key(identity, rnd), rep["advice_new"], rep["advice_repeat"], rep["mc_preexisting_new"])
```

- [ ] **Step 5: `docreview_state.py`**

모듈 docstring 의 `서브커맨드: state-dir-for · init · … · observe-diff · gate` 끝에 ` · advice` 를 더한다. `cmd_gate_rows` 앞에 `cmd_advice` 를 넣는다:

```python
def cmd_advice(a) -> int:
    """참고(advisory) 목록 — 끝에서 한 번 표시(`--render`) · 박제(`--sink`) · 라운드별 계수 줄(`--log-file`).

    플래그가 없으면 원장의 목록을 JSON 으로 낸다(읽기 전용). 한 호출 안의 순서는 박제 → 계수 → 표시다. 이미 보인
    항목(`shown`) · 박제한 항목(`sunk`)은 다시 내지 않고, 계수 줄의 멱등 키는 (리뷰 정체, 라운드)를 목적지 파일의
    글자로 판정한다 — 원장이 TTL 로 걷혀도 두 번 적지 않는다. 부르는 자리는 진입 skill 셋이다(절차서는 계약만)."""
    import docreview_advice as adv   # 이 서브커맨드만 쓰는 형제 — 원장 스크립트만 복사한 설치본의 다른 서브커맨드를 막지 않는다
    st = load_state(a.state_dir)
    prof = load_profile(st["profile"])
    if not adv.has_must_catch(prof):
        return fail("profile_has_no_must_catch", profile=st["profile"])
    cap = adv.RENDER_CAP if a.cap is None else a.cap
    if cap < 1:
        return fail("cap_invalid", cap=cap)
    dt = prof["defer_target"]
    if a.sink and dt.get("kind") != "doc_section":
        return fail("profile_has_no_defer_target")
    heading = prof["decision_log"].get("heading")
    if a.log_file and not heading:
        return fail("profile_decision_log_is_state_only")
    items = list((st.get("advice") or {}).values())
    sunk = [it for it in items if not it.get("sunk")] if a.sink else []
    for it in sunk:
        append_under_heading(Path(a.sink), dt["heading"], adv.sink_row(it))
        it["sunk"] = True
    logged = []
    if a.log_file:
        path, ident = Path(a.log_file), adv.review_identity(a.state_dir)
        for k in sorted(st["rounds"], key=int):
            rep = st["rounds"][k].get("route_report") or {}
            have = path.read_text(encoding="utf-8") if path.is_file() else ""
            if "advice_new" in rep and adv.count_key(ident, int(k)) not in have:
                append_under_heading(path, heading, adv.count_line(ident, int(k), rep))
                logged.append(int(k))
    shown = [it for it in items if not it.get("shown")] if a.render else []
    if a.render:
        where = a.where or (dt["heading"] if dt.get("kind") == "doc_section" else "advice 목록(JSON)")
        print("\n".join(adv.render_lines(shown, cap, where)))
    for it in shown:
        it["shown"] = True
    if sunk or shown:
        save_state(a.state_dir, st, "advice shown=%d sunk=%d" % (len(shown), len(sunk)))
    if not a.render:
        _emit({"ok": True, "items": items, "sunk": len(sunk), "logged_rounds": logged})
    return 0
```

`build_parser` 의 `gate` 줄 다음에 넣는다:

```python
    x = sd(sp.add_parser("advice")); x.add_argument("--render", action="store_true")
    x.add_argument("--cap", type=int, default=None); x.add_argument("--where", default=None)
    x.add_argument("--sink", default=None); x.add_argument("--log-file", default=None)
    x.set_defaults(fn=cmd_advice)
```

- [ ] **Step 6: 통과 확인**

```bash
bash shared/tests/test_docreview_advice.sh | tail -1
bash shared/tests/test_docreview_golden.sh | tail -1
PYTHONDONTWRITEBYTECODE=1 python3 plugins/quality-gates/tests/test_utf8_explicit.py 2>&1 | tail -1
bash plugins/spec-distill/tests/test_reviewing_spec_residue.sh | tail -1     # 원장 스크립트만 복사한 설치본 — 지연 import 가 다른 서브커맨드를 막지 않는다
bash plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh | tail -1
```
Expected: 전부 `Fail: 0` / `OK`.

- [ ] **Step 7: 변이 셀** — (72) 뒤에 넣는다:

```bash
# (73) cap 상수를 바꾼다 — 기본 호출이 9줄을 내고 「외 2건」이 된다.
mut 1/1 render_cap_changed case_AC6_render_cap sed_advice 's/^RENDER_CAP = 8 /RENDER_CAP = 9 /'
```

Run: `bash shared/tests/test_docreview_mutations.sh | grep render_cap_changed`
Expected: ✓ · `churn 1/1`.

- [ ] **Step 8: 커밋**

```bash
git add shared/docreview/scripts/docreview_advice.py shared/docreview/scripts/docreview_state.py \
  shared/tests/fixtures/docreview/ shared/tests/test_docreview_advice.sh shared/tests/test_docreview_mutations.sh
git commit -m "$(printf 'feat(docreview): advice 서브커맨드 — 한 번 표시(cap 8) · 박제 · 라운드별 계수 줄\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>')"
```

---

### Task 8: 번들 위생 regex 를 자기 audit 으로 (AC10)

**Files:**
- Modify: `plugins/spec-distill/scripts/build_brief_bundle.py:44,144`, `plugins/spec-distill/scripts/build_brief_inline_blob.py:37,89`
- Test: `plugins/spec-distill/tests/test_brief_bundle.sh`, `plugins/spec-distill/tests/test_brief_inline_blob.sh`

**Interfaces:**
- Produces: 두 빌더의 rc 3 은 「payload(블롭)에 **자기** `audit_file` basename 이 남았다」이다. 블롭 빌더는 `audit_file` 을 모르면 예전의 넓은 판정으로 닫는다.

- [ ] **Step 1: 실패하는 테스트**

`test_brief_inline_blob.sh` 의 기존 「본문이 audit 파일명을 언급하는 경우」 블록에서 치환 문자열 `2026-07-27-x-interview.audit.md` 를 두 군데 모두 **자기 이름** `2026-07-27-verbatim-ok-interview.audit.md` 로 바꾼다(python 치환 한 곳, 뒤따르는 `grep -qF` 한 곳). 그리고 블록 뒤에 넣는다:

```bash
# AC10 (설계 2026-09-27-review-stopping-criterion §F) — 위생이 가리는 것은 이 brief 자신의 audit 이다.
# 다른 인터뷰의 audit 을 근거로 인용하는 것은 정상이다(최근 6회 중 3회의 rc 3 이 그 오탐이었다).
tmp_o="$(mktemp)" || exit 1
python3 - "$PAYLOAD" "$tmp_o" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
t = t.replace('  > "브리프에 리뷰를 붙이고 싶다"',
              '  > "브리프에 리뷰를 붙이고 싶다 (docs/superpowers/interview/2026-01-01-other-interview.audit.md#S3 참고)"')
open(sys.argv[2], "w", encoding="utf-8").write(t)
PY
grep -qF 'other-interview.audit.md' "$tmp_o" || no "T24b 전제: 치환이 적용되지 않았다"
python3 "$SCRIPT" "$tmp_o" >/dev/null 2>&1; rc_o=$?
[[ "$rc_o" == "0" ]] && ok "T24b: 다른 인터뷰의 audit 인용만 있으면 exit 0" || no "T24b: 다른 audit 인용이 exit $rc_o"
# T24c — audit_file 을 모르면 넓은 판정(모든 *.audit.md)으로 닫는다(fail-closed).
sed '/^audit_file:/d' "$tmp_o" > "$tmp_o.noaf"
python3 "$SCRIPT" "$tmp_o.noaf" >/dev/null 2>&1; rc_n=$?
[[ "$rc_n" == "3" ]] && ok "T24c: audit_file 이 없으면 다른 audit 인용도 exit 3 (넓은 판정)" || no "T24c: audit_file 없는 payload 가 exit $rc_n"
rm -f "$tmp_o" "$tmp_o.noaf"
```

`test_brief_bundle.sh` 의 T9 블록 뒤에 넣는다:

```bash
# T17/T18 — AC10 (설계 2026-09-27-review-stopping-criterion §F). 위생 판정은 자기 audit_file basename 만 본다.
T17D="$(mktemp -d)" || exit 1
cp "$FX/interview-brief-valid.md" "$FX/interview-brief-valid.audit.md" "$T17D/"
printf '\n근거: docs/superpowers/interview/2026-01-01-other-interview.audit.md#S3\n' >> "$T17D/interview-brief-valid.md"
python3 "$B" "$T17D/interview-brief-valid.md" "$T17D/interview-brief-valid.audit.md" >/dev/null 2>&1; rc17=$?
[[ $rc17 -eq 0 ]] && ok "T17: payload 에 다른 *.audit.md 경로만 있으면 rc 0" || no "T17: 다른 audit 인용이 rc $rc17"
printf '\n자기 원문은 interview-brief-valid.audit.md 에 있다\n' >> "$T17D/interview-brief-valid.md"
python3 "$B" "$T17D/interview-brief-valid.md" "$T17D/interview-brief-valid.audit.md" >/dev/null 2>&1; rc18=$?
[[ $rc18 -eq 3 ]] && ok "T18: payload 에 자기 audit_file basename 이 있으면 rc 3" || no "T18: 자기 audit 이름이 rc $rc18"
rm -rf "$T17D"
```

- [ ] **Step 2: 실패 확인**

Run: `bash plugins/spec-distill/tests/test_brief_bundle.sh | grep T17; bash plugins/spec-distill/tests/test_brief_inline_blob.sh | grep T24b`
Expected: 둘 다 ✗(rc 3).

- [ ] **Step 3: 구현**

`build_brief_bundle.py` 에서 `AUDIT_NAME_RE = re.compile(r"\S*\.audit\.md\b")` 를 지우고 그 자리에 둔다:

```python
def own_audit_re(audit_name: str):
    """이 brief 자신의 audit 파일명(앞에 이름 조각이 붙지 않은 것). 위생이 가리는 것은 자기 audit 이다 — 다른
    인터뷰의 audit 을 §5 근거로 인용하는 것은 정상이고, 그것까지 막으면 인용마다 degrade 가 켜진다."""
    return re.compile(r"(?<![\w.-])" + re.escape(audit_name) + r"\b")
```

`main` 의 `if AUDIT_NAME_RE.search(redacted_payload):` 를 `if own_audit_re(blessed.name).search(redacted_payload):` 로 바꾼다. 모듈 docstring 의 `exit: … 3 번들 payload 부분에 audit 파일명 잔존` 을 `3 번들 payload 부분에 자기 audit 파일명 잔존` 으로 고친다.

`build_brief_inline_blob.py` 의 `AUDIT_SUFFIX_RE = …` 다음에 넣는다:

```python
AUDIT_FILE_RE = re.compile(r"(?m)^audit_file[ \t]*:[ \t]*(.*)$")


def own_audit_name(text: str):
    """frontmatter `audit_file` 값의 basename — 없거나 비면 None(호출자가 넓은 판정으로 닫는다)."""
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    m = AUDIT_FILE_RE.search(text[:end])
    name = Path(m.group(1).strip().strip("\"'")).name if m else ""
    return name or None
```

`main` 의 `if AUDIT_SUFFIX_RE.search(blob):` 를 바꾼다(`text` 는 redaction 전 원문이다 — 블롭의 frontmatter 는 이미 `<redacted>` 다):

```python
    own = own_audit_name(text)
    leak = (re.search(r"(?<![\w.-])" + re.escape(own) + r"\b", blob) if own else AUDIT_SUFFIX_RE.search(blob))
    if leak:
```

모듈 docstring 의 「본문이 audit 파일명을 언급하면」을 「본문이 **자기** audit 파일명을 언급하면(`audit_file` 을 모르면 모든 `*.audit.md`)」으로 고친다.

- [ ] **Step 4: 통과 확인**

```bash
bash plugins/spec-distill/tests/test_brief_bundle.sh | tail -1
bash plugins/spec-distill/tests/test_brief_inline_blob.sh | tail -1
PYTHONDONTWRITEBYTECODE=1 python3 plugins/quality-gates/tests/test_utf8_explicit.py 2>&1 | tail -1
```
Expected: `Fail: 0` · `Fail: 0` · `OK`.

- [ ] **Step 5: 커밋 · 손 변이**

```bash
git add plugins/spec-distill/scripts/build_brief_bundle.py plugins/spec-distill/scripts/build_brief_inline_blob.py \
  plugins/spec-distill/tests/test_brief_bundle.sh plugins/spec-distill/tests/test_brief_inline_blob.sh
git commit -m "$(printf 'fix(spec-distill): 번들 위생 판정을 자기 audit basename 으로 — 다른 audit 인용 오탐 제거\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>')"
sed -i.bak 's/if own_audit_re(blessed.name).search(redacted_payload):/if re.search(r"\\S*\\.audit\\.md\\b", redacted_payload):/' plugins/spec-distill/scripts/build_brief_bundle.py && rm -f plugins/spec-distill/scripts/build_brief_bundle.py.bak
bash plugins/spec-distill/tests/test_brief_bundle.sh | grep -c '✗'
git checkout HEAD -- plugins/spec-distill/scripts/build_brief_bundle.py && git diff HEAD --stat
```
Expected: regex 를 원복한 변이에서 ✗ 1(T17). 복원 뒤 diff 가 비어 있다.

---

### Task 9: 절차서 · 진입 skill 문면 (AC11)

**Files:**
- Modify: `shared/docreview/references/reviewing-document.md` (8단계 뒤 한 문단 · `## 배달` 한 줄)
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md` (`## 게이트` — 「미검증」 문단 뒤)
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md` (`## Step B 로 돌아간다` 한 줄)
- Modify: `plugins/spec-distill/skills/framing-requests/SKILL.md` (`### 게이트 직전 — 넷, 이 순서로` — 검사 1 앞)
- Modify: `plugins/spec-distill/skills/conducting-interview/references/finishing.md` (`#### B-0` 뒤 `#### B-A` · B-2 1번 문장)
- Create: `shared/tests/test_docreview_advice_procedure.sh`

**Interfaces:**
- Consumes: Task 7 의 CLI 표면(`advice --render --cap --where --sink --log-file`, 플래그 없음 = JSON).

- [ ] **Step 1: 실패하는 락** — `shared/tests/test_docreview_advice_procedure.sh`:

```bash
#!/usr/bin/env bash
# guards: shared/docreview/references/reviewing-document.md plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/skills/framing-requests/SKILL.md plugins/spec-distill/skills/conducting-interview/references/finishing.md shared/docreview/scripts/docreview_state.py
#
# 설계 2026-09-27-review-stopping-criterion AC11 — 절차서와 진입 자리의 문면이 참고(advisory) 목록의 한 번 표시 ·
# 박제 절차를 싣고, 그 문면이 부르는 `advice` 서브커맨드의 플래그가 실재한다(`advice --help` 로 도출 — 손 목록 없음).
# 자리별 필수 플래그: 절차서(계약) · reviewing-spec = render · sink · log-file / finishing(brief Step B) = render ·
# log-file / framing-requests(seed) = log-file. reviewing-brief 는 부르지 않는다(brief 의 한 번 표시는 Step B 한 곳).
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/references/reviewing-document.md"
  echo "plugins/spec-distill/skills/reviewing-spec/SKILL.md"
  echo "plugins/spec-distill/skills/reviewing-brief/SKILL.md"
  echo "plugins/spec-distill/skills/framing-requests/SKILL.md"
  echo "plugins/spec-distill/skills/conducting-interview/references/finishing.md"
  echo "shared/docreview/scripts/docreview_state.py"
  exit 0
fi
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
HELP="$(python3 "$REPO_ROOT/plugins/spec-distill/scripts/docreview_state.py" advice --help 2>&1)"
assert_contains "$HELP" "--render" "전제: advice 서브커맨드가 실재한다(--help)"
CALL_RE='docreview_state\.py"? advice( |$)'
check_site() {   # check_site <파일> <필수 플래그…>
  local f="$1"; shift
  local calls flag
  calls="$(grep -E "$CALL_RE" "$REPO_ROOT/$f")"
  if [ -z "$calls" ]; then no "$f: advice 호출 줄이 없다"; return; fi
  ok "$f: advice 호출 줄 $(printf '%s\n' "$calls" | grep -c .)개"
  for flag in $(printf '%s\n' "$calls" | grep -oE -- '--[a-z][a-z-]*' | sort -u); do
    if printf '%s\n' "$HELP" | grep -qE -- "(^|[[ ])${flag}([] ,=]|$)"; then ok "$f: ${flag} 는 advice 가 받는다"
    else no "$f: ${flag} 는 advice --help 에 없다"; fi
  done
  for flag in "$@"; do
    if printf '%s\n' "$calls" | grep -qE -- "${flag}( |$)"; then ok "$f: ${flag} 호출이 있다"; else no "$f: ${flag} 호출이 없다"; fi
  done
}
check_site shared/docreview/references/reviewing-document.md --render --sink --log-file
check_site plugins/spec-distill/skills/reviewing-spec/SKILL.md --render --sink --log-file
check_site plugins/spec-distill/skills/conducting-interview/references/finishing.md --render --log-file
check_site plugins/spec-distill/skills/framing-requests/SKILL.md --log-file
RB="$(cat "$REPO_ROOT/plugins/spec-distill/skills/reviewing-brief/SKILL.md")"
assert_not_grep "$RB" "$CALL_RE" "reviewing-brief: advice 를 부르지 않는다 — brief 의 한 번 표시는 호출자 Step B 한 곳"
assert_contains "$RB" "참고(advisory) 목록은 이 skill 이 보이지 않는다" "reviewing-brief: 참고 목록은 Step B 가 보인다고 말한다"
RS="$(cat "$REPO_ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md")"
assert_contains "$RS" "1단계가 있었으면 그것이 진행 쪽으로 닫힌 뒤" "reviewing-spec: 표시 시점이 1단계가 진행 쪽으로 닫힌 뒤 · 2단계 앞이다"
assert_contains "$RS" "「추가 라운드 1회 열기」를 고른 흐름에서는 돌리지 않는다" "reviewing-spec: 추가 라운드를 열면 표시가 미뤄진다"
FIN="$(cat "$REPO_ROOT/plugins/spec-distill/skills/conducting-interview/references/finishing.md")"
assert_contains "$FIN" "사용자가 고를 것이 있는가" "finishing: §3 / §5 를 가르는 판단 문면이 있다"
assert_contains "$FIN" 'check_brief.py" gate "$PAYLOAD"' "finishing: 박제 뒤 구조 게이트를 다시 돈다"
assert_not_contains "$FIN" "층 1(방향성) 결정은 라운드 게이트에서 이미 사용자가 판정했습니다" "finishing: B-2 의 낡은 문장(방향이 라운드 게이트에 온다)이 없다"
RD="$(cat "$REPO_ROOT/shared/docreview/references/reviewing-document.md")"
assert_contains "$RD" "끝에서 한 번" "절차서: 참고 목록은 끝에서 한 번이다"
finish
```

- [ ] **Step 2: 실패 확인**

Run: `bash shared/tests/test_docreview_advice_procedure.sh | grep -c '✗'`
Expected: 1 이상(호출 줄 없음).

- [ ] **Step 3: 절차서** — `reviewing-document.md` 의 8단계 문단(「… 「다음:」 줄에 리뷰 완료가 아니라는 꼬리가 붙는다.」) 뒤, `## 배달` 앞에 넣는다:

```markdown
**참고(advisory) — 프로필이 `must_catch` 를 지목한 자리.** 7단계는 advisory 축 항목 일부를 `advice` 원장으로
보낸다. advisory 축은 `layer_rubric` 의 축 중 `must_catch` 밖이다. 보내는 것은 셋이다: `decide` · `blocks` 없는
`ask` · 보호 헤딩 승격분, `fix` 를 막지 않는 `ask`, 라운드 2 이상의 새 계보 `fix`. 이것들은 게이트 질문이 아니고
승인을 막지 않는다. 라운드 1 의 advisory `fix` 는 fixes 에 남아 저자가 적용한다. fixes 에 남는 항목을 막는
`ask` 는 축과 무관하게 asks 에 남는다. 엔진 자동 생성 항목(얼림 · 재상승 · 상향)은 언제나 must-catch 다.
`fin.json` 은 `advice`(id 목록) · `advice_new` · `advice_repeat` · `mc_preexisting_new` 를 싣고, 8단계 렌더는
`참고 N건(…) — 끝에서 한 목록으로` 한 줄만 싣는다. 목록은 **끝에서 한 번** 보인다. 이 절차서가 부르지 않고
진입 자리가 부른다:

- design doc — `reviewing-spec` 승인 게이트 2단계 앞
- brief — 호출자 Step B
- seed — 계수만

    docreview_state.py advice --state-dir D [--render [--cap 8] [--where <박제처>]] [--sink <doc>] [--log-file <decision_log 목적지>]

- `--render` 는 아직 안 보인 항목을 머리 한 줄 + 항목 한 줄씩(최대 cap) + `외 K건` 한 줄로 낸다(≤10줄).
- `--sink` 는 프로필 `defer_target` 절에 아직 박제하지 않은 항목을 표 행으로 적는다. `defer_target` 이 없으면
  rc 1 `profile_has_no_defer_target` 이다.
- `--log-file` 은 라운드별 계수 줄(`docreview 계수 — <리뷰 정체> r<n>: …`)을 프로필 `decision_log` 절에 한 번씩
  적는다.
- 플래그가 없으면 목록 JSON 을 낸다(읽기 전용).

셋 다 멱등이다. 「추가 라운드 1회 열기」를 고르면 부르지 않는다 — 다음 라운드 끝으로 미뤄진다.
```

`## 배달` 목록 끝에 더한다:

```markdown
- 참고(advisory) → 라운드 게이트에 오지 않는다. 끝에서 한 번 `advice`(진입 자리)로 보이고 박제된다.
```

- [ ] **Step 4: reviewing-spec** — `## 게이트` 의 「미검증」 라운드 문단 뒤, 「승인 게이트를 띄우기 직전에 `$spec_path` 가 working-tree 에 있는지 다시 본다」 앞에 넣는다(첫 줄 `SD=` 가드는 이 파일의 다른 펜스와 **같은 한 줄**을 그대로 복사한다):

````markdown
**참고(advisory) 목록 — 2단계 앞에서 한 번.** 승인 게이트 2단계(진행 옵션)를 띄우기 직전에 아래 펜스를 한 번 돌리고
출력을 그대로 보인다. 1단계가 있었으면 그것이 진행 쪽으로 닫힌 뒤다. 「추가 라운드 1회 열기」를 고른 흐름에서는
돌리지 않는다(다음 라운드 끝으로 미뤄진다). 펜스는 세 가지를 한다:

- advisory 항목을 설계문서의 `### Deferred to plan` 에 표 행으로 박제한다(`writing-plans` 가 그 절을 읽는다).
- 라운드별 계수 줄을 `## 결정 기록` 에 적는다.
- 목록을 낸다.

셋 다 멱등이라 ③ 수정 뒤 다시 와도 두 번 적지 않는다. 문서가 바뀌므로 ①/② 의 미커밋 확인이 그 변경을
알리고, 그때 커밋한다. 펜스 앞에 `spec_path='<「## 입력」에서 절대 경로로 바꾼 설계문서 경로>'` 한 줄을 붙여
같은 Bash 호출로 돌린다.

<!-- advice-display:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라 — 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)." >&2; exit 1; }
harness_sid="$(python3 "$SD/scripts/state_path.py" session-id || true)"
ROOT="$(python3 "$SD/scripts/state_path.py" state-root || true)"
STATE_DIR="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$ROOT" --session "$harness_sid" --doc "${spec_path:-}" || true)"
if [ -z "${STATE_DIR:-}" ] || [ ! -f "$STATE_DIR/docreview-state.md" ]; then
  echo "[spec-distill] 참고(advisory) 목록 없음 — 엔진 원장을 찾지 못했다(spec_path='${spec_path:-}' · STATE_DIR='${STATE_DIR:-}'). 2단계 질문 텍스트에 싣는다."
else
  adv_rc=0
  python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" --sink "$spec_path" --log-file "$spec_path" --render --cap 8 || adv_rc=$?
  [ "$adv_rc" -eq 0 ] || echo "[spec-distill] 참고 목록 표시 · 박제 실패(rc $adv_rc) — 위 stderr 의 사유를 2단계 질문 텍스트에 싣는다. 진행은 막지 않는다."
fi
```
<!-- advice-display:end -->
````

- [ ] **Step 5: reviewing-brief** — `## Step B 로 돌아간다` 절 끝에 한 문단을 더한다:

```markdown
참고(advisory) 목록은 이 skill 이 보이지 않는다 — 엔진 `advice` 원장에 쌓인 방향 · overdesign 항목은 호출자
Step B(`conducting-interview` `finishing.md` 의 `#### B-A`)가 끝에서 한 번 보이고 brief §3 · §5 에 박제한다.
```

- [ ] **Step 6: framing-requests** — `### 게이트 직전 — 넷, 이 순서로` 의 첫 문단(「… 1번부터 다시 돕니다.」) 뒤, `**검사 1 — 표시**` 앞에 넣는다:

````markdown
**계수 기록 — 검사 1 앞에서, 막지 않습니다.** 엔진의 라운드별 계수 줄(`docreview 계수 — …`)을 audit `## 6. 리뷰
결정` 에 적습니다. seed 프로필은 advisory 축이 없어 참고 목록이 늘 0건이라 보이지 않고 계수만 남깁니다. 같은
(리뷰 정체, 라운드) 줄은 다시 적지 않으므로 ③ 뒤에 다시 돌아도 됩니다. 「## 상태」 블록을 앞에 이어 붙여 돌립니다.

```bash
cnt_rc=0
if [ -n "${STATE_DIR:-}" ] && [ -f "$STATE_DIR/docreview-state.md" ]; then
  python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" --log-file "$AUDIT_ABS" >/dev/null || cnt_rc=$?
else
  cnt_rc=2
fi
[ "$cnt_rc" -eq 0 ] || echo "[spec-distill] 리뷰 계수 줄을 audit ## 6 에 적지 못했다(cnt_rc=$cnt_rc — 엔진 원장이 없거나 advice 가 실패했다). 게이트 텍스트에 싣는다 — 막지 않는다." >&2
echo "cnt_rc=$cnt_rc"
```
````

- [ ] **Step 7: finishing.md**

`#### B-1 — superpowers 가용성 분기` 바로 앞(= `#### B-0` 절 끝)에 새 절을 넣는다. 제목을 `B-0a` 로 하지 않는다 — `/^#### B-0/` 윈도우를 쓰는 락이 둘을 한 절로 읽는다:

````markdown
#### B-A — 참고(advisory) 목록 — 한 번 보이고 §3 · §5 에 박제

B-1 분기보다 먼저 돕니다(superpowers 가 없어도 brief 는 완결돼야 합니다). 엔진 `advice` 원장의 방향 · overdesign
항목은 라운드 게이트에 오지 않았습니다 — 여기서 한 번 보이고 brief 에 박제합니다. `PAYLOAD` 는 Step A.5 의 그 절대경로입니다.

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
PAYLOAD="<Step A.5 의 PAYLOAD 절대경로>"; AUDIT="${PAYLOAD%.md}.audit.md"
harness_sid="$(python3 "$SD/scripts/state_path.py" session-id || true)"; ROOT="$(python3 "$SD/scripts/state_path.py" state-root || true)"
STATE_DIR="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$ROOT" --session "$harness_sid" --doc "$PAYLOAD" || true)"
if [ -z "${STATE_DIR:-}" ] || [ ! -f "$STATE_DIR/docreview-state.md" ]; then
  echo "[spec-distill] 참고(advisory) 목록 없음 — brief 리뷰 원장이 없다(STATE_DIR='${STATE_DIR:-}'): 리뷰가 skip 됐거나 세션 정리로 걷혔다. 게이트 텍스트에 싣는다."
else
  adv_rc=0
  python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" > "$STATE_DIR/advice-list.json" || adv_rc=$?
  [ "$adv_rc" -ne 0 ] || python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" --log-file "$AUDIT" --render --cap 8 --where "brief §3 · §5" || adv_rc=$?
  [ "$adv_rc" -eq 0 ] || echo "[spec-distill] 참고 목록 판독 · 표시 실패(rc $adv_rc) — 위 stderr 사유를 게이트 텍스트에 싣는다."
fi
```

펜스 출력(머리 한 줄 + 최대 8줄 + `외 K건`)을 그대로 보입니다. 이어 `advice-list.json` 의 `items` 중 `shown` 이
거짓이던 항목(방금 보인 것)을 payload 에 박제합니다. 가르는 판단은 한 줄입니다(이 문장은 한 줄로 둡니다 — AC11 락이 부분문자열로 잽니다):

**이 brief 를 넘기기 전에 사용자가 고를 것이 있는가.**

- **있으면 §3.** `- OQ<n>: [참고 · <category>] <summary> (리뷰 <id>)` 로 적고, §0 결정 목록에
  `- OQ<n> [열림] — [참고 · <category>] <summary>` 를 함께 적습니다. `<n>` 은 §3 · §0 의 가장 큰 OQ 번호 다음입니다.
- **없으면(알고 있으면 되는 위험) §5.** `- 위험 — 리뷰 참고 | [<category>] <anchor> — <summary> (리뷰 <id>)` 로 적습니다.

적은 뒤 구조 게이트를 다시 돕니다. failures 가 있으면 고치고 다시 돕니다:

```bash
python3 "$SD/scripts/check_brief.py" gate "$PAYLOAD"
```
````

`#### B-2` 의 프로즈 목록 1번에서 「층 1(방향성) 결정은 라운드 게이트에서 이미 사용자가 판정했습니다.」 한 문장을 다음으로 바꾼다:

```markdown
방향 · overdesign(참고 축)은 라운드 게이트에 오지 않았고 B-A 의 참고 목록으로 한 번 왔습니다 — 그 목록은 §3 · §5 에 박제됐습니다.
```

- [ ] **Step 8: 통과 확인**

```bash
bash shared/tests/test_docreview_advice_procedure.sh | tail -1
bash shared/tests/test_docreview_procedure_paths.sh | tail -1
for t in plugins/spec-distill/tests/test_*.sh; do printf '%s ' "$t"; bash "$t" 2>&1 | tail -1; done | grep -v 'Fail: 0'
```
Expected: 앞 둘은 `Fail: 0` 이고, 마지막 목록은 Task 0 의 선재 RED 와 같다. 절 · 펜스 개수를 재는 락(`test_conducting_interview_stage.sh` · `test_brief_review_entry.sh` · `test_seed_*` · `test_framing_review_contract.sh` 등)이 흔들렸으면 메시지대로 고친다. 기대값을 옮길 때는 그 이유를 커밋 메시지에 적는다.

- [ ] **Step 9: 커밋**

```bash
git add shared/docreview/references/reviewing-document.md plugins/spec-distill/skills/reviewing-spec/SKILL.md \
  plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/skills/framing-requests/SKILL.md \
  plugins/spec-distill/skills/conducting-interview/references/finishing.md shared/tests/test_docreview_advice_procedure.sh
git commit -m "$(printf 'docs(spec-distill): 참고 목록 한 번 표시 · 박제 · 계수 — 절차서와 세 진입 자리\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>')"
```

---

### Task 10: 버전 · CHANGELOG · README · 최종 재측정 (AC12)

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` (`4.4.0` → `4.5.0`), `plugins/quality-gates/.claude-plugin/plugin.json` (`9.2.0` → `9.2.1`)
- Modify: `plugins/spec-distill/CHANGELOG.md`, `plugins/quality-gates/CHANGELOG.md`, `plugins/spec-distill/README.md` (Principles Instantiated 한 줄)

- [ ] **Step 1: base 재확인** — `git fetch -q origin && git log --oneline HEAD..origin/main`. 그 사이 두 플러그인 버전이 main 에서 올랐으면 그 위의 다음 번호를 쓴다(같은 버전 문자열은 충돌 없이 병합되므로 눈으로 본다). 버전 핀 락이 있으면(`grep -rn '"4\.4\.0"\|9\.2\.0' plugins/*/tests shared/tests`) 그 규칙대로 같이 옮긴다.

- [ ] **Step 2: 버전 · CHANGELOG** — `plugin.json` 두 개의 `version` 을 올린다. spec-distill `CHANGELOG.md` 의 `# Changelog` 다음에 넣는다:

```markdown
## [4.5.0] — 2026-09-27

minor 인 이유 — 새 표면이 넷이다.

- 프로필 선택 필드 `must_catch`
- 엔진 서브커맨드 `docreview_state.py advice`
- `advice` 원장
- 보고서 키 넷(`advice` · `advice_new` · `advice_repeat` · `mc_preexisting_new`)

호출 계약은 줄지 않는다. 설계 `docs/superpowers/specs/2026-09-27-review-stopping-criterion-design.md`.

### Added
- **리뷰가 문서 상태로 멈춘다.** 프로필이 `must_catch` 로 막는 축을 지목하면, 그 밖의 rubric 축(advisory)의 결정 ·
  질문 · 보호 헤딩 승격분 · 라운드 2 이상의 새 fix 는 `advice` 원장으로 간다. 이것들은 게이트 질문이 아니고 승인을
  막지 않는다. 세 프로필의 값:
  - brief = 층 2 충실도 여섯
  - design doc = `goal_fit · problem_definition · scope · architecture`
  - seed = 층 1 넷
  rubric 밖 category · `other` · 엔진 자동 생성 항목은 언제나 막는다(fail-closed).
- **끝에서 한 번.** 참고 목록은 진입 자리가 한 번 보인다(≤10줄, 넘치면 `외 K건`). 자리마다 박제처가 다르다:
  - design doc — `### Deferred to plan`
  - brief — Step B 가 §3 · §5
- **다음 사이클이 수렴을 잰다.** 라운드별 계수 줄 `docreview 계수 — <리뷰 정체> r<n>: advice_new · advice_repeat ·
  mc_preexisting_new` 가 결정 기록 절에 남는다(Law 3).

### Changed
- 세 진입 skill 의 profile-content 펜스가 `must_catch:` 줄을 리뷰어 슬롯에서 벗긴다. framing-requests 펜스에
  `profile-content` 마커가 생겼다.
- `finishing.md` Step B 에 `#### B-A`(참고 목록 · §3/§5 박제)가 생겼다. B-2 의 「방향 결정은 라운드 게이트에서
  판정했다」 문장을 고쳤다.

### Fixed
- `build_brief_bundle.py` · `build_brief_inline_blob.py` 의 rc 3(위생) 판정을 자기 `audit_file` basename 으로 좁혔다.
  다른 인터뷰의 audit 을 근거로 인용하던 brief 가 라운드마다 degrade 를 켰다(최근 6회 중 3회).
```

quality-gates `CHANGELOG.md` 의 머리 설명 다음(`## [9.2.0]` 앞)에 넣는다:

```markdown
## [9.2.1] — 2026-09-27

### Changed
- 공유 문서 리뷰 엔진(`shared/docreview/scripts/`)이 프로필 선택 필드 `must_catch` · `advice` 서브커맨드 · 형제 모듈
  `docreview_advice.py`(이 플러그인 `scripts/` 에 심볼릭 링크)를 얻었다. qg `generic` 프로필은 필드가 없어 라우팅 ·
  보고서 · 게이트 렌더가 바이트 단위로 같다(골든 12파일).
```

- [ ] **Step 3: README** — spec-distill `README.md` 의 Principles Instantiated 목록에서 P18 줄 다음에 넣는다:

```markdown
- **P18 보강 — must-catch 멈춤 기준** (v4.5.0) — 프로필이 `must_catch` 로 막는 축을 지목하면 그 밖의 rubric 축 finding 은 참고(advisory)로 라우팅돼 승인을 막지 않고 끝에서 한 번 보인다(`shared/docreview/scripts/docreview_advice.py`). 라운드별 계수 줄이 결정 기록 절에 남아 다음 사이클이 must-catch 축의 수렴 가정을 잰다(Law 3).
```

- [ ] **Step 4: 최종 재측정(AC12)**

```bash
D=.superpowers/sdd/2026-09-27-review-stopping-criterion
bash "$D/run_suite.sh" "$D/head.tsv" > "$D/head.porcelain" 2>&1
bash "$D/compare_suite.sh" "$D/baseline.tsv" "$D/head.tsv"
cat "$D/head.porcelain"
PYTHONDONTWRITEBYTECODE=1 python3 shared/tests/fixtures/adjudication/run_wiring_scan.py "$(pwd)" | grep -E '^(unwired|exempt_stale|comprehensions)='
bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh | tail -1
git diff 5d46bf0f -- plugins/quality-gates/references/ | wc -l
```
Expected:
- `no regression` 이다. 새 테스트 두 파일은 head 에만 있고 `(0, 0)` 이다.
- porcelain 이 비어 있다.
- 배선 스캔은 `unwired=0 exempt_stale=0 comprehensions=40` 이다.
- guards 락은 `Fail: 0` 이다.
- qg 프로필 diff 는 0 줄이다(qg 동작 무변경 — Non-goals).

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/quality-gates/.claude-plugin/plugin.json \
  plugins/spec-distill/CHANGELOG.md plugins/quality-gates/CHANGELOG.md plugins/spec-distill/README.md
git commit -m "$(printf 'chore(release): spec-distill 4.5.0 · quality-gates 9.2.1 — 리뷰 멈춤 기준\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>')"
git status --porcelain
```

- [ ] **Step 6: 최종 리뷰에 물을 것(SDD 최종 리뷰어 프롬프트에 그대로 싣는다)**

각 태스크의 테스트는 **이 계획이 쓴 코드**다(plan-mandated) — 구현과 같은 전제를 공유하므로 따로 의심하라. 아래 넷을 끝에서 끝으로 추적하라.

1. brief 한 사이클 — 라운드 1 · 2 → 상한 → Step B B-A → §3/§5 박제 → `check_brief.py gate` 재실행. 이 흐름에서 advisory 항목이 사라지거나 두 번 박제되는 자리가 있는가.
2. design doc — 2단계 앞 펜스의 `--sink`/`--log-file` 이 같은 파일(`$spec_path`)을 두 번 연다. 두 번째 쓰기가 첫 쓰기를 덮지 않는가(`append_under_heading` 은 매번 파일을 다시 읽는다).
3. qg 경로 — `recritic_bridge.py` → `docreview_route` import → `docreview_advice` 형제가 설치본에서도 풀리는가. `generic` 프로필의 모든 산출물이 현행과 같은가.
4. 각 rc(`advice` 의 rc 1 넷)를 진입 자리 펜스가 소비하는가 — 조용히 삼키지 않는가.

---

## Self-Review 기록

1. **Spec coverage.** AC 와 설계 절이 어느 태스크에 가는지 적는다.

   | AC · 설계 절 | 태스크 |
   |---|---|
   | AC1 | 5 |
   | AC2 | 6(끝에서 끝) · 4(엔진 항목 단위) |
   | AC3 | 1(음 — 골든 12) · 5(양의 짝) |
   | AC4 | 2 |
   | AC5 | 5 |
   | AC6 | 7 |
   | AC7 | 7 |
   | AC8 | 6 |
   | AC9 | 5(해시 · 하위 절) |
   | AC10 | 8 |
   | AC11 | 9 |
   | AC12 | 0 · 10 |
   | AC13 | 5(decide · ask · fix) · 6(막는 ask) |
   | AC14 | 6 |
   | AC15 | 6 |
   | AC16 | 3 |
   | AC17 | 7 |
   | AC18 | 6 |
   | AC19 | 5 |
   | §A 표 | 4 |
   | §C 1회 규칙 | 5 |
   | §D 자리별 표시 | 9 |
   | §E 운반체 | 7 · 9 |
   | §F | 8 |

   Verification Plan 항목은 이렇게 간다.

   | 변이 | 셀 · 태스크 |
   |---|---|
   | 여집합 반전 | (61) · (66) |
   | 1회 규칙 | (63) |
   | cap | (73) |
   | 해시 | (64) · (65) |
   | regex 원복 | Task 8 손 변이 |
   | AC16 벗기기 | Task 3 손 변이 |

2. **Placeholder scan.** `TBD` · 「적절히」 류는 없다. 「기존 … 그대로」는 현 파일의 줄을 바꾸지 말라는 지시이고, 그 줄은 이 계획이 인용한 위치에 실재한다.
3. **Type consistency.** 이름과 모양이 태스크를 넘어 같다.
   - `route_step1(final, axes)` · `route_step2(final, keep_of, axes, n, L)` · `mc_preexisting_new(final, snapshots, n, axes)` · `record_findings → {"listed","repeat"}`.
   - 보고서 키 `advice_new`/`advice_repeat`/`mc_preexisting_new` 는 route(생산) → `gate_summary`(`rep`) → `cmd_advice`(`rep`) → `count_line`(`rep[...]`) 에서 같은 이름이다.
   - 원장 항목 키 `id/round/layer/category/anchor/summary/replacement/shown/sunk` 는 `_record_advice`(쓰기)와 `render_lines`/`sink_row`/`cmd_advice`(읽기)가 같다.
4. **Review Focus.** 다섯 줄 모두 소유 태스크에 테스트가 있다(7 · 7 · 7 · 6 · 8).
