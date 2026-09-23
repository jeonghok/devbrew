# 설계자 시선 리뷰 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** devbrew 의 두 문서 리뷰 자리(brief · design-doc)에 과설계를 잡는 축 하나를 세우고(갈래 1), 리뷰 처분을 고르는 게이트 렌더에서 동어반복 두 줄을 없애 「그대로 두면 / 고치면」으로 바꾼다(갈래 2).

**Architecture:** 갈래 1 은 새 리뷰어 agent 없이 프로필 `layer_rubric.layer1` 에 축 `overdesign` 하나를 더하고 그 안에 술어 셋(과함 · 왜곡 · 층위 이탈)을 둔다. 판정 절차·어법은 ponytail 에서, 거기 없는 것은 리포 자신에게서 가져온다. 갈래 2 는 리뷰어 스키마에 칸 둘(`replacement`·`if_unfixed`)을 더해 `normalize()` → `PUBLIC_FIELDS` → 렌더까지 실어 나르고, 선택지 라벨을 `kind` 의 함수로 바꾼다. 선행 수선으로 `doc-critic` 본문의 리터럴 여덟 축을 프로필 참조로 전환한다.

**Tech Stack:** Python 3(표준 라이브러리 + PyYAML) · bash(테스트는 `shared/tests/assert.sh` 의 `ok`/`no`/`finish`) · git 심볼릭 링크 배포(`plugins/*/scripts/*.py` → `shared/`) · codex CLI(모델 다양성 축).

**Spec:** `docs/superpowers/specs/2026-09-21-designer-lens-review-design.md` (커밋 `c685945a`, 1134줄). 이 계획은 그 문서에서 논증을 끌어온다 — 실행자는 둘을 함께 읽는다. 그 문서의 정답 출처는 `docs/superpowers/interview/2026-09-21-designer-lens-review-interview.md` 다.

---

## Global Constraints

설계문서 §4 에서 그대로 옮긴다. **모든 Task 의 요구사항에 이 절이 암묵적으로 포함된다.**

- **C1** 새 리뷰어 agent 를 만들지 않는다. 탐지 리뷰어는 `doc-critic` 하나다.
- **C2** 갈래 1 의 새 축이 가는 자리는 **brief · design-doc 둘뿐**이다. seed 와 `/qg` generic 에는 **안 간다**(참조 전환 수선은 그 둘에도 가지만 축은 아니다).
- **C3** 설명 개선 넷(before/after · 「그대로 두면」 · 회계어 번역 · 우선순위·묶음)을 **모두** 범위에 둔다.
- **C18** 밀도 — 같은 길이에 **정보가 더 많은** 쪽. 글이 아니라 정보를 늘린다. (비구속 선호이지 기계 상한이 아니다.)
- **D21** `/qg` 의 회계 낱말(`수용`·`기각`·`억제`·`흡수`·`미판정`·`배관 손실`·`셀 수 없음`)은 **그대로 두고** 사람말 한 줄을 옆에 덧붙인다.
- **D24** 묶음은 **읽는 부담만** 줄인다 — `AskUserQuestion` 질문 수도 항목별 선택권도 그대로다.
- **엔진의 라운드·상한·처분 어휘는 불변** — `rereview_cap: 2` · `RANK` · `allowed_dispositions` 를 건드리지 않는다.
- **프로필 frontmatter 의 값은 한 줄에서 끝나야 한다.** codex 러너의 파서는 줄 단위(`run_docreview_codex_reviewer.sh:302` 의 `re.fullmatch(r"  ([a-z_][a-z0-9_]*): (.+)", line)`)라 이어진 줄을 rc 5 `profile_parse_ambiguous` 로 거부하고, T13 의 `lay_of` 는 `head -1` 이라 첫 줄만 읽는다. Python 게이트만 PyYAML 이라 통과하므로 **줄바꿈은 판정자 하나를 조용히 끈다.**
- **`PROFILE_FIELDS`(`shared/docreview/scripts/docreview_state.py:37-39`)는 닫힌 10-튜플이다.** 11번째 필드도 `layer_rubric` 의 셋째 키도 rc 2 거부다. 새 프로필 필드를 만들지 않는다.
- **agent 사본 넷은 락이 동기화를 강제한다.** `shared/docreview/agents/doc-critic.md` 를 고치면 `doc-critic-web.md`(variant-of) · `plugins/spec-distill/agents/doc-critic.md`(copy-of) · `plugins/spec-distill/agents/doc-critic-web.md`(copy-of + variant-of) 넷을 같은 커밋에서 같이 고친다. `doc-recritic` 은 사본 **둘**이다.
- **`plugins/*/scripts/*.py` 는 git 심볼릭 링크다**(mode 120000 실측) — `shared/` 쪽 한 파일만 고치면 두 플러그인에 함께 간다. 반면 **agent 와 프로필은 실파일**이라 각각 고친다.
- **모든 테스트는 리포 루트에서 돌린다.** `PYTHONDONTWRITEBYTECODE=1` 을 건다 — 같은 길이 변이는 stale `.pyc` 를 못 넘는다.
- **`AC24` — 건드린 플러그인마다 `plugin.json` version bump + `CHANGELOG.md` 항목을 같은 커밋에.** 매니페스트 경로는 `plugins/<name>/.claude-plugin/plugin.json` 이다(`plugins/<name>/plugin.json` 이 아니다). 현재값: `spec-distill 3.2.0` · `quality-gates 7.6.2`. **버전 숫자는 브랜치에서 정하지 말고 머지 직전에 확정한다** — 먼저 머지되는 쪽이 이기고 같은 버전 문자열은 충돌 없이 병합된다.
- **머지는 사용자가 한다.** 실행자는 `gh pr merge` 를 부르지 않는다 — PR 번호를 보이고 `! gh pr merge <n> --merge` 를 사용자에게 안내한다. `gh api` 우회 금지.
- **브랜치 최신화는 `merge` 로 한다. `rebase` 금지.**
- **P23 재결정 규약** — 설계문서의 `confirmed` 항목은 재논의 대상이 아니지만 **반증 대상**이다. 구현 중 근거가 나오면 사용자 동의를 받아 피벗하고 «원래 / 재결정 / 근거» 세 칸으로 남긴다. **임의 변경은 금지다.**

### 계획이 스스로 공시하는 것 (설계문서가 남긴 미검증)

1. **라운드 2 의 리뷰는 모델 다양성이 0 이었다** — codex 실호출 2회가 모두 `exit_nonzero` 였다(`codex_absent: true`). 그 라운드의 판정은 Claude 단독이다.
2. **라운드 3 의 재비판 블록은 오케스트레이터가 요약 보고에서 조립했다** — 전사가 아니다.
3. **라운드 3 의 결정 16건과 저자 fix 2건은 추가 라운드를 안 열어 리뷰를 안 거쳤다.** 이 계획이 그 16건 위에 선다.

이 셋은 막는 사유가 아니라 **읽는 사람이 알아야 하는 사실**이다. 구현 중 그 자리에서 모순이 나오면 P23 재결정 경로로 간다.

---

## 머지 순서 — 계약이다 (AC25)

```
PR 0  docs        ← 브리프 · 설계문서 · 이 계획
PR 1  참조 전환    ← doc-critic/codex 의 rubric 분기를 먼저 없앤다
PR 3  칸 둘 + 렌더  ← 축이 쓸 배관을 미리 깐다
PR 2  축 + 프로필   ← 배관이 준비된 위에 축이 선다
```

**순서가 뒤집히면 무슨 일이 일어나는가** (설계문서 §9 의 두 사고 표):

| 잘못된 순서 | 결과 |
|---|---|
| 2 가 1 보다 먼저 | Claude `doc-critic` 은 여전히 리터럴 여덟 축을 보므로 **새 축이 codex 쪽에서만 돈다** — 두 판정자가 다른 rubric 으로 돌고 「축이 무이빨」로 오진된다 |
| 2 가 3 보다 먼저 | 프로필이 「대체안은 같은 항목 안에 필수」를 심는데 그 대체안을 실어 나를 `replacement` 칸이 아직 없다 — `normalize()` 가 **조용히 버린다** |

**PR 3 이 PR 2 보다 앞서는 창의 성질** — 그 사이에는 칸이 있는데 채우라는 규약이 없다. 리뷰어가 안 채우면 렌더가 `(대체안 미작성)` 을 낸다 — 그것이 「강제할 수 없으면 보이게 한다」가 작동하는 모습이지 결함이 아니다. 반대 창에서는 규약이 요구한 값이 `normalize()` 에서 **조용히 사라진다.** 그 비대칭이 순서를 정한다.

**각 PR 본문은 선행 PR 번호를 명시한다**(AC25). PR 3 본문: 「선행 = PR 1 (#N)」. PR 2 본문: 「선행 = PR 1 (#N) · PR 3 (#M)」.

**브랜치**

| PR | 브랜치 | 기점 |
|---|---|---|
| 0 | `feature/designer-lens-review` (현재) | 이미 존재 — main `d24d3045` 병합 완료 |
| 1 | `feature/docreview-layer1-wiring` | PR 0 머지 후의 `main` |
| 3 | `feature/docreview-decision-render` | PR 1 머지 후의 `main` |
| 2 | `feature/docreview-overdesign-axis` | PR 3 머지 후의 `main` |

각 PR 은 선행 PR 이 **머지된 뒤** 그 `main` 에서 딴다. 스택으로 쌓지 않는다 — 리포 기록: 스택 PR 의 base 를 지우면 dependent PR 이 retarget 이 아니라 **CLOSE** 된다.

---

## File Structure

### 만드는 파일

| 파일 | 책임 | PR |
|---|---|---|
| `docs/superpowers/plans/2026-09-22-designer-lens-review-baseline.md` | 착수 시점 전량 baseline — 파일별 **통과 수**. 회귀 판정의 유일한 기준선 | 0 |
| `shared/tests/test_docreview_layer1_wiring.sh` | **agent 가 층 1 을 프로필에 위임했는가**와 **프로필 넷이 각자 자기 판정 관계를 소유하는가**의 관계를 잰다. 둘 중 한쪽만 재는 기존 락은 없다 | 1 |
| `plugins/spec-distill/tests/test_overdesign_rubric.sh` | 두 프로필 본문의 `overdesign` 절이 담아야 할 것(술어 · 태그 · 사다리 · 오탐 가드 · 0건 출구 · 상한)을 잰다 | 2 |

세 파일 다 **새 책임**이다 — 기존 락에 축을 얹지 않는 것이 이 리포의 관례다(「새 책임은 별도 모듈로, 기존 파일엔 진입 한 줄」).

### 고치는 파일 — PR 1

| 파일 | 무엇을 |
|---|---|
| `shared/docreview/agents/doc-critic.md` (`:47`) | 층 1 불릿 → `layer_rubric.layer1` 참조 · 판정 관계 리터럴 제거 |
| `shared/docreview/agents/doc-critic-web.md` (`:49`) | 동일 (variant-of 계약이 강제) |
| `plugins/spec-distill/agents/doc-critic.md` (`:48`) | 동일 (copy-of) |
| `plugins/spec-distill/agents/doc-critic-web.md` (`:50`) | 동일 (copy-of) |
| `plugins/spec-distill/references/docreview-profiles/brief.md` | 층 1 판정 관계 한 줄 |
| `plugins/spec-distill/references/docreview-profiles/design-doc.md` | 동일 |
| `plugins/spec-distill/references/docreview-profiles/seed.md` | 동일 |
| `plugins/quality-gates/references/docreview-profiles/generic.md` | 동일 |
| 두 플러그인의 `.claude-plugin/plugin.json` · `CHANGELOG.md` | bump + 항목 |

### 고치는 파일 — PR 3

| 파일 | 무엇을 |
|---|---|
| `shared/docreview/scripts/docreview_route.py` | `normalize()`(칸 둘) · `_decision_view()`(`change` 제거 · 침묵 공시 · category 사람말) · `_CHOICE_LABEL` import → `choice_label` |
| `shared/docreview/scripts/docreview_state.py` | `PUBLIC_FIELDS` 에 칸 둘 · `_CHOICE_LABEL` 을 kind 중첩 dict 로 + `choice_label()` · `CATEGORY_GLOSS` + `category_gloss()` · `_rg_decide()` 여섯 줄 · `_rg_expired()` · `render_gate()` 머리 한 줄 + anchor 묶음 |
| `shared/docreview/agents/doc-critic.md` + 사본 셋 | 출력 형식의 항목 키에 칸 둘 + 삭제 제안 규약 |
| `shared/docreview/agents/doc-recritic.md` + 사본 하나 | `added` 출력 예시에 칸 둘 |
| `shared/docreview/scripts/run_docreview_codex_reviewer.sh` (`:439-440`) | 출력 JSON 예시에 칸 둘 |
| `shared/docreview/references/reviewing-document.md` (8단계) | `AskUserQuestion` 라벨 조립 규약 |
| `shared/adjudication/render_disposition.py` | 풀이 줄 + 반환 4-튜플 + docstring |
| `plugins/quality-gates/scripts/synthesize_findings.py` (`:482`·`:532`) | 4-튜플 언패킹 |
| `plugins/quality-gates/scripts/synthesize_artifact_findings.py` (`:313`) | 4-튜플 언패킹 |
| `shared/tests/fixtures/docreview/cases.sh` (`:375`·`:490`·`:512`·`:1174`) | 라벨 리터럴 네 자리를 상태별 라벨로 |
| `shared/tests/test_docreview_mutations.sh` (`:572`·`:581`·`:612`) | sed 패턴 세 자리 |
| `shared/tests/test_docreview_round_gate_split.sh` | 라벨 규약 축 추가 |
| `shared/tests/fixtures/docreview/golden/*` (6개) | 렌더 변경에 따른 재캡처 |
| `tools/adjudication/check_wiring.py` (`EXEMPT` 9개 키) | 줄번호 재앵커 |
| `plugins/quality-gates/tests/test_synthesize_disposition.sh` | 풀이 줄 단언 |
| `plugins/quality-gates/tests/test_synthesize_artifact_findings.sh` (`:375`) | 머리말 「처분 두 줄」 → 세 줄 |
| 두 플러그인의 `.claude-plugin/plugin.json` · `CHANGELOG.md` | bump + 항목 |

### 고치는 파일 — PR 2

| 파일 | 무엇을 |
|---|---|
| `plugins/spec-distill/references/docreview-profiles/brief.md` | `layer1` 에 `overdesign` · 본문에 축 절(술어 ①③) |
| `plugins/spec-distill/references/docreview-profiles/design-doc.md` | 동일 (술어 ①②③ · `bent:` 포함) |
| `plugins/spec-distill/tests/test_brief_review_ng3.sh` | T13 단언 ④⑤ 신설 · `leak2` 제거 |
| `plugins/spec-distill/.claude-plugin/plugin.json` · `CHANGELOG.md` | bump + 항목 |

**AC13 — PR 2 의 `git diff` 에 `docreview_state.py` 가 0줄이다.** 그래서 새 축의 사람말 사상(`CATEGORY_GLOSS["overdesign"]`)은 **PR 3 이 미리 심는다**(Task 8 에서 사유와 함께). PR 2 가 엔진을 건드리면 「축만 단독 머지 가능」이 깨진다.

---

## Task 1: Baseline 전량 캡처 — rc 가 아니라 통과 수로

**Files:**
- Create: `docs/superpowers/plans/2026-09-22-designer-lens-review-baseline.md`
- Create: `.claude/plan-tmp/capture_baseline.sh` (git-ignored 작업 스크립트)

**Interfaces:**
- Produces: 파일별 `<경로> rc=<N> Total/Pass/Fail` 표. 뒤 Task 전부가 「새 RED 0」(AC23)을 이 표에 대고 판정한다.

**왜 열거가 아니라 도출인가.** 설계문서 §10 은 「아직 안 잰 것」을 **열 개**로 열거했다. 실제로 도출해 보면 그 목록에 **없는** 파일이 최소 둘 더 닿는다 — `shared/tests/test_docreview_golden.sh`(골든 셋이 `decision_view` 를 바이트로 고정한다)와 codex 러너를 읽는 스위트들(`test_docreview_codex.sh` 등, PR 3 이 러너 프롬프트를 고친다). 열거는 저자의 상상력을 물려받는다. 세 디렉토리 전량을 돌면 그 상상력 밖이 함께 잡힌다.

**rc 로만 잡으면 안 되는 이유** — 이미 RED 인 파일 **안의** 새 실패는 rc 로 원리적으로 안 보인다. 통과 수를 함께 기록해야 그 안의 회귀가 보인다.

- [ ] **Step 1: 캡처 스크립트를 쓴다**

```bash
mkdir -p .claude/plan-tmp
cat > .claude/plan-tmp/capture_baseline.sh <<'EOF'
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1
export PYTHONDONTWRITEBYTECODE=1
for t in shared/tests/test_*.sh plugins/spec-distill/tests/test_*.sh plugins/quality-gates/tests/test_*.sh; do
  [ -f "$t" ] || continue
  out="$(bash "$t" 2>&1)"; rc=$?
  line="$(printf '%s\n' "$out" | grep -E '^Total: ' | tail -1)"
  printf '| `%s` | %s | %s |\n' "$t" "$rc" "${line:-(Total 줄 없음)}"
done
EOF
```

- [ ] **Step 2: 돌린다 — 오래 걸린다**

Run: `bash .claude/plan-tmp/capture_baseline.sh > .claude/plan-tmp/baseline.txt 2>&1`
Expected: 196개 줄. `test_docreview_mutations.sh` 하나만 수 분이 걸린다.

- [ ] **Step 3: baseline 문서로 옮긴다**

`docs/superpowers/plans/2026-09-22-designer-lens-review-baseline.md` 를 만든다. 머리말은 이 네 줄이다(그 이상 쓰지 않는다 — 산출물은 표다):

```markdown
# designer-lens-review 착수 baseline

측정: <날짜> · HEAD `<sha>` · `PYTHONDONTWRITEBYTECODE=1` · 리포 루트에서 실행.
판정 기준은 rc 가 아니라 **Pass 수**다 — 이미 RED 인 파일 안의 새 실패는 rc 로 안 보인다.
「새 RED 0」(AC23)은 이 표의 Pass 수가 어느 줄에서도 **줄지 않았음**을 뜻한다.

| 파일 | rc | 결과 |
|---|---|---|
<Step 2 의 출력 붙여넣기>
```

- [ ] **Step 4: 선재 RED 가 있으면 이름과 이유를 적는다**

`rc != 0` 인 줄이 있으면 표 아래에 절을 하나 더 만든다:

```markdown
## 선재 RED — 이 변경의 것이 아니다

| 파일 | Fail | 왜 이미 RED 인가 (실행으로 확인한 사유) |
|---|---|---|
```

**「원래 그렇던 것」으로만 적지 않는다.** 이름을 올릴 때 이유도 적는다 — 이유 없는 면제 목록은 그 질문을 영구히 닫는다(리포 기록).

**2026-09-22 참고 실측** (이 계획을 쓰며 잰 것 — 착수 시점에 **다시 잰다**. 그 사이 `main` 이 움직이면 값이 바뀐다):

| 파일 | Pass |
|---|---|
| `shared/tests/test_docreview_state.sh` | 172/172 |
| `shared/tests/test_docreview_route.sh` | 149/149 |
| `shared/tests/test_docreview_intent.sh` | 26/26 |
| `shared/tests/test_docreview_anchor.sh` | 18/18 |
| `shared/tests/test_docreview_gate_visibility.sh` | 46/46 |
| `shared/tests/test_docreview_mutations.sh` | 65/65 |
| `shared/tests/test_docreview_golden.sh` | 11/11 ← **설계문서 §10 목록에 없던 파일** |
| `shared/tests/test_adjudication_wiring.sh` | 17/17 |
| `shared/tests/test_adjudication_consumed.sh` | 6/6 |
| `plugins/quality-gates/tests/test_synthesize_artifact_findings.sh` | 36/36 |
| `plugins/spec-distill/tests/test_brief_agents.sh` | 95/95 |

설계문서 §10 이 이미 잰 다섯(`test_docreview_agents.sh` 36 · `test_copy_of_contract.sh` 188 · `test_variant_of_contract.sh` 87 · `test_brief_review_ng3.sh` 21 · `test_synthesize_disposition.sh` 11)과 합쳐 **열여섯이 GREEN 이었다.**

- [ ] **Step 5: 커밋**

```bash
git add docs/superpowers/plans/2026-09-22-designer-lens-review.md \
        docs/superpowers/plans/2026-09-22-designer-lens-review-baseline.md
git commit -m "docs(plans): 설계자 시선 리뷰 구현 계획 + 착수 baseline

전량 도출(shared/tests · 두 플러그인 tests)로 파일별 통과 수를 잡는다. 설계문서
§10 의 열 개 열거에 없던 test_docreview_golden.sh 가 여기서 드러났다 — 골든 셋이
decision_view 를 바이트로 고정하므로 PR 3 의 렌더 변경이 직접 닿는다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 6: PR 0 을 연다**

```bash
git push -u origin feature/designer-lens-review
gh pr create --base main --title "docs: 설계자 시선 리뷰 — 브리프 · 설계문서 · 구현 계획" --body "$(cat <<'BODY'
## 무엇

`designer-lens-review` 의 문서 셋이다. 코드 변경 0 — `docs/superpowers/` 만 건드린다.

- 인터뷰 브리프 (`interview/2026-09-21-...`) — 27 제약 중 26 confirmed, D11 하나 provisional
- 설계문서 (`specs/2026-09-21-...-design.md`) — `spec-distill:reviewing-spec` 3라운드, 사용자 결정 34건 · 저자 fix 14건 반영
- 구현 계획 (`plans/2026-09-22-...`) + 착수 baseline

## 공시

- 리뷰 라운드 2 는 codex 실호출 2회가 모두 `exit_nonzero` 라 **모델 다양성 0** 이었다(`codex_absent: true`).
- 라운드 3 의 재비판 블록은 오케스트레이터가 요약 보고에서 조립했다(전사 아님).
- 라운드 3 의 결정 16건과 fix 2건은 추가 라운드를 안 열어 **리뷰를 안 거쳤다**.

## 뒤에 오는 것

머지 순서는 **1 → 3 → 2** 이고 계약이다(설계 AC25).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY
)"
```

그다음 **사용자에게** 머지를 부탁한다: `! gh pr merge <번호> --merge`. 실행자가 직접 머지하지 않는다.

---

# PR 1 — 참조 전환 (수선)

> 브랜치: `feature/docreview-layer1-wiring`, PR 0 이 머지된 `main` 에서 딴다.
> **이 PR 은 새 축을 어느 프로필에도 더하지 않는다**(AC4).

**왜 이것이 먼저인가.** `doc-critic` 본문(`:47`)이 층 1 축을 **리터럴 산문으로 쥐고** 있다 — 「목표·문제정의·범위·아키텍처·컴포넌트 관계·데이터 흐름·trade-off·구현 가능성」. 그 여덟은 **네 자리 중 하나(design-doc)에만** 맞다. 한편 codex 러너는 프로필의 `layer_rubric.layer1` 을 읽어 프롬프트에 싣는다(`run_docreview_codex_reviewer.sh:372`·`:427`). **같은 라운드의 두 판정자가 이미 다른 rubric 으로 돈다.** 그 리터럴 줄을 붙드는 락은 **하나도 없다**(테스트 전수 grep 0건).

---

## Task 2: agent 사본 넷의 층 1 불릿을 프로필 참조로 전환

**Files:**
- Create: `shared/tests/test_docreview_layer1_wiring.sh`
- Modify: `shared/docreview/agents/doc-critic.md:47`
- Modify: `shared/docreview/agents/doc-critic-web.md:49`
- Modify: `plugins/spec-distill/agents/doc-critic.md:48`
- Modify: `plugins/spec-distill/agents/doc-critic-web.md:50`

**Interfaces:**
- Produces: 마커 문자열 `**층 1 판정 관계** —`. Task 3 의 프로필 편집과 PR 2 의 축 절이 이 마커를 이어 쓴다.
- Consumes: 없음(첫 코드 Task).

**네 줄이 바이트로 같다**(실측) — 그래서 한 번의 치환으로 넷을 함께 고친다. 줄번호가 파일마다 다른 것은 위쪽 frontmatter 길이 차이일 뿐이다.

- [ ] **Step 1: 브랜치를 딴다**

```bash
git fetch origin
git checkout -b feature/docreview-layer1-wiring origin/main
git log --oneline -1
```

- [ ] **Step 2: 락을 먼저 쓴다 (실패할 테스트)**

Create `shared/tests/test_docreview_layer1_wiring.sh`:

```bash
#!/usr/bin/env bash
# guards: shared/docreview/agents/doc-critic*.md plugins/*/agents/doc-critic*.md plugins/*/references/docreview-profiles/*.md
#
# 층 1 의 «판정 관계»를 누가 소유하는가. 탐지 리뷰어 본문이 축 이름과 판정 관계를
# 리터럴로 쥐면 그 문장은 네 자리 중 하나에만 맞는다 — brief 는 ground_truth 를 안 쓰고,
# seed 는 정합이 아니라 뺄셈을 재며, generic 은 외부 정답이 없어 「문서와 문서가 정합한가」
# 로 공허해진다. 그래서 축 이름은 프로필 `layer_rubric.layer1` 이, 판정 관계는 각 프로필
# 본문의 「**층 1 판정 관계** —」 줄이 소유한다.
#
# 이 락이 두 축을 «함께» 재는 이유: 한쪽만 재면 다른 쪽이 조용히 빈다. agent 에서 리터럴을
# 걷어내고 프로필에 관계를 안 적으면 리뷰어는 무엇과 대조할지 어디서도 못 읽는다(부재 락
# 단독의 공허함 — 리포 기록: feedback_negative_locks_need_positive_pair).
#
# 프로필 코퍼스는 **열거가 아니라 글롭 도출**이다. 다섯째 자리가 생기면 그 자리도 자동으로
# 이 계약에 든다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  git ls-files -- 'shared/docreview/agents/doc-critic*.md' \
                  'plugins/*/agents/doc-critic*.md' \
                  'plugins/*/references/docreview-profiles/*.md'
  exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT" || exit 1
. "$HERE/assert.sh"

MARKER='**층 1 판정 관계** —'

# ── 축 A : agent 사본 넷이 층 1 을 프로필에 위임한다 ─────────────────────────
AGENTS="$(git ls-files -- 'shared/docreview/agents/doc-critic*.md' 'plugins/*/agents/doc-critic*.md')"
n_agents="$(printf '%s\n' "$AGENTS" | grep -c . || true)"
if [ "$n_agents" -ge 4 ]; then
  ok "A0 양의 짝: doc-critic 사본 ${n_agents}개를 코퍼스에서 읽었다 (아래 부재 판정이 공허하지 않다)"
else
  no "A0: doc-critic 사본이 ${n_agents}개다 — 넷 이상이어야 한다. 아래 전부가 공허하다"
fi

for f in $AGENTS; do
  line="$(grep -n '^- \*\*층 1\*\* —' "$f" | head -1)"
  if [ -n "$line" ]; then
    ok "A1: $f 에 층 1 불릿이 하나 있다 (양의 짝)"
  else
    no "A1: $f 에 '- **층 1** —' 불릿이 없다 — 아래 판정이 잴 대상을 잃는다"
    continue
  fi
  body="${line#*:}"
  # A2 — 리터럴 여덟 축 열거 부재. 연쇄의 한 조각만 겨누면 나머지를 남긴 채 통과하므로
  #      가운뎃점 연쇄 자체를 겨눈다.
  case "$body" in
    *"목표·문제정의·범위"*) no "A2: $f 층 1 불릿이 리터럴 축 열거를 아직 쥐고 있다" ;;
    *) ok "A2: $f 층 1 불릿에 리터럴 여덟 축 열거가 없다" ;;
  esac
  # A3 — 프로필 참조 존재(양의 짝: A2 의 부재가 «줄 삭제»로 달성되지 않았다)
  case "$body" in
    *'layer_rubric.layer1'*) ok "A3: $f 층 1 불릿이 layer_rubric.layer1 을 참조한다" ;;
    *) no "A3: $f 층 1 불릿이 layer_rubric.layer1 을 참조하지 않는다" ;;
  esac
  # A4 (AC3) — 근거 요구가 «축 이름»에 안 묶였다. 조건절 자체는 살아 있어야 한다.
  case "$body" in
    *'구현 가능성 finding'*) no "A4: $f 의 근거 요구가 아직 축 이름(구현 가능성)에 묶여 있다" ;;
    *) ok "A4: $f 의 근거 요구가 축 이름에 안 묶여 있다" ;;
  esac
  case "$body" in
    *'리포 사실을 단정하는'*) ok "A4b: $f 에 근거 요구 조건절이 살아 있다 (A4 의 양의 짝 — 조건절 삭제가 아니다)" ;;
    *) no "A4b: $f 에 근거 요구 조건절이 없다 — A4 가 조건절 삭제로 통과한 것이다" ;;
  esac
  # A5 (AC3') — 판정 관계를 agent 본문이 단정하지 않는다.
  n_rel="$(grep -c 'ground_truth.*정합' "$f" || true)"
  if [ "${n_rel:-0}" -eq 0 ]; then
    ok "A5: $f 에 ground_truth 정합을 단정하는 문장이 0건"
  else
    no "A5: $f 에 ground_truth 정합 단정이 ${n_rel}건 남아 있다 (design-doc 자리의 관계이지 네 자리 공통이 아니다)"
  fi
done

# ── 축 B : 프로필 넷이 각자 자기 자리의 판정 관계를 소유한다 ─────────────────
PROFILES="$(git ls-files -- 'plugins/*/references/docreview-profiles/*.md')"
n_prof="$(printf '%s\n' "$PROFILES" | grep -c . || true)"
if [ "$n_prof" -ge 4 ]; then
  ok "B0 양의 짝: 프로필 ${n_prof}개를 글롭으로 도출했다 (열거가 아니다)"
else
  no "B0: 프로필이 ${n_prof}개다 — 넷 이상이어야 한다. 아래 전부가 공허하다"
fi

RELS=""
for p in $PROFILES; do
  n="$(grep -cF "$MARKER" "$p" || true)"
  if [ "${n:-0}" -eq 1 ]; then
    ok "B1: $p 가 자기 층 1 판정 관계를 한 줄로 소유한다"
    RELS="$RELS
$(grep -F "$MARKER" "$p" | head -1)"
  else
    no "B1: $p 의 마커 줄이 ${n}개다 (정확히 하나여야 한다)"
  fi
done

# B2 — 넷이 서로 «다른» 문장이다. 한쪽을 다른 쪽에 베껴 넣으면 자리 경계가 무너진다.
n_rel_lines="$(printf '%s' "$RELS" | grep -c . || true)"
n_uniq="$(printf '%s' "$RELS" | grep . | sort -u | grep -c . || true)"
if [ "${n_rel_lines:-0}" -ge 4 ] && [ "$n_uniq" -eq "$n_rel_lines" ]; then
  ok "B2: 판정 관계 ${n_rel_lines}줄이 전부 서로 다르다 (자리마다 다른 관계를 잰다)"
else
  no "B2: 판정 관계가 ${n_rel_lines}줄인데 서로 다른 것은 ${n_uniq}줄이다 — 자리 경계가 무너졌다"
fi

finish
```

- [ ] **Step 3: 실패를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_layer1_wiring.sh`
Expected: **FAIL.** A2·A3·A4·A5 가 사본 넷에서 각각 RED(리터럴 축 열거가 남아 있고 `layer_rubric.layer1` 참조가 없다), B1 이 프로필 넷에서 RED(마커 줄이 0개), B2 도 RED. A0·A1·A4b·B0 은 GREEN(양의 짝이 실제로 붙들고 있다는 증거).

- [ ] **Step 4: 사본 넷을 한 번에 고친다**

```python
# python3 - <<'PY' 로 돌린다
import pathlib
OLD = ("- **층 1** — `ground_truth` 와 문서가 하나의 그림으로 정합한가. "
       "목표·문제정의·범위·아키텍처·컴포넌트 관계·데이터 흐름·trade-off·구현 가능성. "
       "구현 가능성 finding 은 리포의 파일·심볼을 실제로 읽어 확인한 근거를 `evidence` 에 인용한다.")
NEW = ("- **층 1** — 프로필 `layer_rubric.layer1` 의 항목으로 본다. "
       "**무엇과 대조하는지는 그 프로필이 말한다** — 각 프로필 본문의 "
       "「**층 1 판정 관계** —」 줄이 그 자리의 관계를 소유한다. "
       "리포 사실을 단정하는 finding 은 파일·심볼을 실제로 읽어 확인한 근거를 `evidence` 에 인용한다.")
FILES = ["shared/docreview/agents/doc-critic.md",
         "shared/docreview/agents/doc-critic-web.md",
         "plugins/spec-distill/agents/doc-critic.md",
         "plugins/spec-distill/agents/doc-critic-web.md"]
for f in FILES:
    p = pathlib.Path(f)
    t = p.read_text(encoding="utf-8")
    if OLD not in t:
        raise SystemExit("옛 문장을 못 찾았다: %s — 손으로 확인하라" % f)
    p.write_text(t.replace(OLD, NEW, 1), encoding="utf-8")
    print("ok", f)
```

- [ ] **Step 5: 축 A 만 GREEN 이 됐는지 본다**

Run: `PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_layer1_wiring.sh`
Expected: **여전히 FAIL** — 하지만 A 축 전부 GREEN 이고 B1·B2 만 RED. Task 3 이 B 를 닫는다.

- [ ] **Step 6: 사본 계약 락 넷을 돌린다**

```bash
export PYTHONDONTWRITEBYTECODE=1
bash shared/tests/test_copy_of_contract.sh 2>&1 | tail -2
bash shared/tests/test_variant_of_contract.sh 2>&1 | tail -2
bash shared/tests/test_docreview_agents.sh 2>&1 | tail -2
bash plugins/spec-distill/tests/test_brief_agents.sh 2>&1 | tail -2
```
Expected: 넷 다 `Fail: 0`, Pass 수가 baseline(188 · 87 · 36 · 95)과 같거나 크다.

- [ ] **Step 7: 커밋**

커밋 대상은 새 락 하나 + agent 넷이다.

```
fix(docreview): doc-critic 층 1 을 프로필 layer_rubric 참조로 전환

리터럴 여덟 축은 네 자리 중 design-doc 하나에만 맞았고, codex 러너는 이미
layer_rubric.layer1 을 읽는다 — 같은 라운드의 두 판정자가 다른 rubric 으로 돌고
있었다. 그 줄을 붙드는 락은 하나도 없었다(전수 grep 0건).

근거 요구의 조건절은 남기되 축 이름에서 푼다: 「구현 가능성 finding 은」 →
「리포 사실을 단정하는 finding 은」. 문서 내부 모순처럼 리포를 볼 필요가 없는
finding 에까지 인용을 요구하면 그 판정이 갈 곳을 잃으므로 「예외 없이 전부」로는
넓히지 않는다.

새 락 test_docreview_layer1_wiring.sh 가 위임(축 A)과 소유(축 B)를 함께 잰다 —
한쪽만 재면 다른 쪽이 조용히 빈다. 축 B 는 다음 커밋이 닫는다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

---

## Task 3: 프로필 넷이 각자 자기 자리의 층 1 판정 관계를 소유한다

**Files:**
- Modify: `plugins/spec-distill/references/docreview-profiles/brief.md` (층 1 절)
- Modify: `plugins/spec-distill/references/docreview-profiles/design-doc.md` (층 1 절)
- Modify: `plugins/spec-distill/references/docreview-profiles/seed.md` (층 1 절)
- Modify: `plugins/quality-gates/references/docreview-profiles/generic.md` (층 1 절)

**Interfaces:**
- Consumes: Task 2 의 마커 `**층 1 판정 관계** —` 와 그 락의 축 B.
- Produces: 네 줄. PR 2 가 brief·design-doc 두 줄에 `overdesign` 절을 **이어 붙인다**(덮어쓰지 않는다).

**네 줄은 서로 달라야 한다** — 락의 B2 가 그것을 잰다. 같은 문장을 넷에 복사하면 「축 이름만 프로필로 넘기고 판정 관계는 리터럴로 두는」 원래 결함이 자리만 옮겨 재발한다.

- [ ] **Step 1: brief.md — 층 1 절 첫 문단 뒤에 한 줄**

`## 층 1 — 방향성` 의 문단(「사용자가 정한 방향이 **틀렸을 근거**를…」) **바로 뒤**, `` - `direction` `` 불릿 **앞**에 빈 줄과 함께:

```markdown
**층 1 판정 관계** — 이 층의 각 축이 무엇과 대조하는지는 **축마다 다르다**. `direction` 은 리포 실체와 웹 선례로 사용자가 정한 방향을 **반증**한다 — 이 축은 `ground_truth` 를 쓰지 않는다.
```

- [ ] **Step 2: design-doc.md — 층 1 절 첫 문단 뒤에 한 줄**

`## 층 1 — 큰 그림 정합` 의 문단(「정답의 출처는 인터뷰 브리프 §2 의 확정 항목이다…」) 뒤, `` - `goal_fit` `` 앞에:

```markdown
**층 1 판정 관계** — 문서가 `ground_truth`(브리프 §2 확정 항목)와 **하나의 그림으로 정합한가**. 어긋남은 문서 쪽의 결함이다.
```

- [ ] **Step 3: seed.md — 층 1 절 첫 문단 뒤에 한 줄**

`## 층 1 — 억제` 의 문단(「**뺄셈 검사**다…」) 뒤, `` - `unfounded_addition` `` 앞에:

```markdown
**층 1 판정 관계** — 초안이 `ground_truth`(원문 줄)에 **없는 것을 더했거나, 원문이 열어 둔 것을 닫았는가**. 정합이 아니라 뺄셈이다 — 「좋은 프롬프트냐」는 이 층의 물음이 아니다.
```

- [ ] **Step 4: generic.md — 층 1 절 머리에 한 줄**

`## 층 1 — 논리와 전제` 헤딩 바로 뒤, `` - `logic` `` 앞에 한 줄과 빈 줄:

```markdown
**층 1 판정 관계** — 문서가 **자기 주장을 스스로 지탱하는가**. 외부 정답이 없으므로 `ground_truth` 와의 대조는 이 자리에 **없다**.
```

- [ ] **Step 5: 락 전체가 GREEN 인지 본다**

Run: `PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_layer1_wiring.sh`
Expected: `Fail: 0`. A 축과 B 축이 전부 통과한다.

- [ ] **Step 6: 이빨을 확인한다 — 변이 셋 (수동, 커밋하지 않는다)**

세 변이를 **하나씩** 넣고 돌린 뒤 복원한다.

| 변이 | 어떻게 | 기대 |
|---|---|---|
| ① B1 이 공허하지 않은가 | `seed.md` 에서 마커 줄 하나를 지운다 | RED |
| ② B2 가 공허하지 않은가 | `design-doc.md` 의 마커 줄을 `seed.md` 에 통째로 베껴 넣는다 | RED |
| ③ A3 이 공허하지 않은가 | `shared/docreview/agents/doc-critic.md` 에서 `layer_rubric.layer1` → `layer_rubric.LAYER_MUT` | RED |

복원은 **`git checkout HEAD -- <경로>`** 로 한다(`git checkout -- <경로>` 가 아니다) — 후자는 index 로 되돌리므로 변이 전에 커밋하지 않았으면 복원이 안 된다(리포 기록). 복원 뒤 `git diff HEAD --stat` 이 비어 있는지 확인한다.

셋 다 GREEN 이 나오면 그 축은 이빨이 없는 것이다 — 락을 고치고 다시 잰다.

- [ ] **Step 7: 커밋**

커밋 대상은 프로필 넷이다.

```
fix(docreview): 프로필 넷이 각자 자기 자리의 층 1 판정 관계를 소유한다

축 이름만 프로필로 넘기고 판정 관계를 agent 리터럴로 두면 넷 중 하나에만 맞던
문장이 넷 중 둘에만 맞는 문장이 될 뿐이다 — brief 층 1 은 ground_truth 를 안 쓰고,
seed 는 정합이 아니라 뺄셈이며, generic 은 외부 정답이 없어 「문서와 문서가
정합한가」로 공허해진다.

네 줄은 서로 달라야 한다(락 축 B2) — 같은 문장을 복사하면 같은 결함이 자리만
옮겨 재발한다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

---

## Task 4: PR 1 마무리 — AC4 확인 · bump · 전량 · PR

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`
- Modify: `plugins/spec-distill/CHANGELOG.md`
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`
- Modify: `plugins/quality-gates/CHANGELOG.md`

**quality-gates 도 bump 하는 이유** — 이 플러그인은 `doc-critic*.md` 를 **배송하지 않는다**(사본 넷은 `shared/docreview/agents/` 와 `plugins/spec-distill/agents/` 뿐). 그러나 `references/docreview-profiles/generic.md` 는 이 플러그인의 배포 트리 안에 있고 Task 3 이 그 본문을 고쳤다. **배포 바이트가 바뀌면 bump 다** — 다만 그 자리는 아직 호출자가 0 이라(`plugins/quality-gates/CHANGELOG.md:115`·`:34`·`:36`·`:37`) 동작 변경이 아니라 장래 전환을 위한 선반영이다.

- [ ] **Step 1: AC4 — 새 축이 안 들어갔는지 기계로 확인한다**

Run: `git diff origin/main --unified=0 | grep -c overdesign`
Expected: `0`. 하나라도 나오면 PR 1 에 PR 2 의 내용이 샜다 — 그 hunk 를 빼고 다시 판정한다.

- [ ] **Step 2: 두 플러그인 bump**

`plugins/spec-distill/.claude-plugin/plugin.json` → `3.2.1`, `plugins/quality-gates/.claude-plugin/plugin.json` → `7.6.3`.

**patch 인 이유** — 새 surface 가 없다. agent 본문과 프로필 본문의 **같은 계약을 다른 자리로 옮기는** 수선이고, `/qg` generic 자리는 호출자가 0 이라 동작이 안 바뀐다. **머지 직전에 `origin/main` 의 값을 다시 읽어 확정한다** — 먼저 머지되는 쪽이 이긴다.

- [ ] **Step 3: 두 CHANGELOG 항목**

`plugins/spec-distill/CHANGELOG.md` 의 `# Changelog` 바로 아래:

```markdown
## [3.2.1] — <날짜>

### Fixed

- **`doc-critic` 층 1 이 축 이름과 판정 관계를 리터럴 산문으로 쥐고 있었다 — 네 자리 중 하나에만 맞는 문장이었다.** 본문(`shared/docreview/agents/doc-critic.md:47` + 사본 셋)이 「목표·문제정의·범위·아키텍처·컴포넌트 관계·데이터 흐름·trade-off·구현 가능성」을 열거했는데 그것은 design-doc 프로필의 `layer_rubric.layer1` 뿐이다. brief 는 `[direction]`, seed 는 `[unfounded_addition, …]`, `/qg` generic 은 `[logic, assumption]` 이다. 한편 codex 러너는 이미 프로필의 `layer_rubric.layer1` 을 읽어 프롬프트에 싣는다(`run_docreview_codex_reviewer.sh:372`·`:427`) — **같은 라운드의 두 판정자가 다른 rubric 으로 돌고 있었다.** 그 줄을 붙드는 락은 **하나도 없었다**(테스트 전수 grep 0건).
- **판정 관계를 프로필로 옮긴다.** agent 본문은 `layer_rubric.layer1` 을 참조하고, 「무엇과 대조하는가」는 각 프로필 본문의 「**층 1 판정 관계** —」 줄이 소유한다. 축 이름만 넘기고 관계를 리터럴로 두면 넷 중 하나에만 맞던 문장이 넷 중 둘에만 맞는 문장이 될 뿐이다.
- **근거 요구의 조건절은 남기되 축 이름에서 푼다.** 「**구현 가능성** finding 은 …」 → 「**리포 사실을 단정하는** finding 은 …」. 축이 사라져도 요구가 같이 사라지지 않는다. 「예외 없이 모든 층 1 finding」으로 넓히지 않는다 — 문서 내부 모순처럼 리포를 볼 필요가 없는 finding 에까지 인용을 요구하면 그 판정이 갈 곳을 잃는다.

### Added

- `shared/tests/test_docreview_layer1_wiring.sh` — 위임(agent 가 프로필을 참조하는가)과 소유(프로필 넷이 각자 관계를 갖는가)를 **함께** 잰다. 한쪽만 재면 다른 쪽이 조용히 빈다. 프로필 코퍼스는 글롭 도출이라 다섯째 자리가 생겨도 자동으로 계약에 든다. 판정 관계 네 줄이 서로 다름을 별도 축(B2)으로 재 복사-붙여넣기 재발을 막는다.
```

`plugins/quality-gates/CHANGELOG.md` 의 헤더 아래:

```markdown
## [7.6.3] — <날짜>

### Fixed

- **`references/docreview-profiles/generic.md` 가 자기 자리의 층 1 판정 관계를 갖는다.** 공유 `doc-critic` 본문이 「`ground_truth` 와 문서가 하나의 그림으로 정합한가」를 리터럴로 쥐고 있었는데, 이 자리의 `ground_truth` 는 「문서 자체 — 외부 정답이 없다」라 그 문장이 「문서와 문서가 정합한가」로 공허해진다. 프로필 본문이 「**층 1 판정 관계** — 문서가 자기 주장을 스스로 지탱하는가」를 소유한다. 이 플러그인은 `doc-critic*.md` 를 배송하지 않지만 이 프로필은 배포 트리 안이라 bump 대상이다. **`/qg` generic 자리는 아직 호출자가 0 이므로 동작 변경이 아니라 전환을 위한 선반영이다.**
```

- [ ] **Step 4: 닿은 코퍼스 전량을 돌린다**

Task 1 의 `capture_baseline.sh` 를 다시 돌려 baseline 표와 **줄 단위로 대조**한다.

```bash
bash .claude/plan-tmp/capture_baseline.sh > .claude/plan-tmp/after-pr1.txt 2>&1
```

Expected: **모든 줄의 Pass 수가 baseline 과 같거나 크다.** 새 락 하나가 추가됐으니 줄이 하나 늘어난다. 어느 줄이라도 Pass 가 **줄면** 그것이 회귀다 — rc 가 0 이어도 그렇다.

- [ ] **Step 5: 커밋 + PR**

bump 와 CHANGELOG 를 한 커밋으로:

```
chore(plugins): spec-distill 3.2.1 · quality-gates 7.6.3 — 층 1 참조 전환

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

PR 본문:

```markdown
**선행** — 없음. 이 PR 이 `1 → 3 → 2` 머지 순서의 첫째다(설계 AC25).

## 결함

`doc-critic` 본문이 층 1 축을 리터럴로 열거한다(`:47` + 사본 셋). 그 여덟은 **네 자리 중 design-doc 하나에만** 맞다. codex 러너는 이미 프로필 `layer_rubric.layer1` 을 읽으므로 **같은 라운드의 두 판정자가 다른 rubric 으로 돈다.** 지금 틀린 지시를 실제로 받는 자리는 **둘**(brief · seed)이고, `/qg` generic 은 호출자가 0 이라 장래의 자리다.

그 리터럴 줄을 붙드는 락은 **하나도 없었다**(전수 grep 0건).

## 고친 것

- agent 사본 넷 → `layer_rubric.layer1` 참조
- 프로필 넷 → 각자 「**층 1 판정 관계** —」 한 줄 소유 (네 줄이 서로 다르다)
- 근거 요구 조건절은 유지하되 축 이름에서 품 (AC3)
- 새 락 `test_docreview_layer1_wiring.sh` — 위임과 소유를 함께 잰다

## AC

AC1 ✓ · AC2 ✓ (사본 계약 락 넷 GREEN) · AC3 ✓ · AC3′ ✓ · AC4 ✓ (`git diff` 에 `overdesign` 0회) · AC23 ✓ · AC24 ✓

## 설계

`docs/superpowers/specs/2026-09-21-designer-lens-review-design.md` §5.5 · §9

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

**사용자에게** 머지를 부탁한다: `! gh pr merge <번호> --merge`. 실행자가 직접 머지하지 않는다.

---

# PR 3 — 갈래 2 (칸 둘 + 렌더)

> 브랜치: `feature/docreview-decision-render`, PR 1 이 머지된 `main` 에서 딴다.
> PR 본문에 **「선행 = PR 1 (#N)」** 을 명시한다(AC25).

**이 PR 이 고치는 결함.** 게이트는 `decide` finding 마다 헤더 + 네 줄을 내는데 그중 **둘이 정보를 안 나른다**:

| 줄 | 지금 | 왜 정보 0 |
|---|---|---|
| `변경` | `it["summary"]` | **헤더와 같은 문자열**이다 |
| `대안` | 고정 라벨 셋 | 대개 모든 항목에서 같다 |
| `영향` | `anchor` + 인용 수 | 영향이 아니라 **위치**다 |
| — | `category` | 렌더에 **한 번도 안 나온다** |

**칸을 더하는 것만으로는 안 고쳐진다.** `normalize()`(`docreview_route.py:52-78`)가 리뷰어 YAML 을 받아 **고정 10키 dict 를 처음부터 새로 짓고** 모르는 키를 조용히 버린다. 설령 칸이 비어도 `change` 가 `summary` 로 채워져 **비어 보이지 않는다** — 그래서 **칸 + fallback 수정**을 한 PR 로 묶는다.

**닫힌 열거가 셋이다.** `PROFILE_FIELDS`(프로필 → 엔진) · `normalize()` 반환 10키(리뷰어 → 라우터) · `PUBLIC_FIELDS`(라우터 → 원장). 앞의 둘만 보고 칸을 더하면 렌더까지는 도달하지만 **상태 파일에 안 남아** 다음 라운드가 그 값을 못 본다.

**픽스처 규율** — 기존 `critic-r1.txt` 를 건드리지 않는다. 그 파일은 여러 케이스와 **골든 셋 셋**의 입력이라 한 글자만 바꿔도 골든 여섯이 함께 움직인다. 새 칸을 태우는 케이스는 **새 픽스처**(`critic-fields.txt`)를 쓴다.

---

## Task 5: 칸 둘의 배관 — `normalize()` → `PUBLIC_FIELDS` 왕복

**Files:**
- Modify: `shared/docreview/scripts/docreview_route.py` (`normalize()`, `:52-78`)
- Modify: `shared/docreview/scripts/docreview_state.py` (`PUBLIC_FIELDS`, `:516-518`)
- Create: `shared/tests/fixtures/docreview/critic-fields.txt`
- Modify: `shared/tests/fixtures/docreview/cases.sh` (새 케이스 둘)
- Modify: `shared/tests/test_docreview_route.sh` (케이스 등록)

**Interfaces:**
- Produces: `normalize()` 반환 dict 에 `replacement`·`if_unfixed` 두 키(부재면 `None`). `st["findings"][fid]` 에도 같은 두 키가 top-level 로 산다.
- Consumes: 없음.
- 뒤 Task 가 쓰는 이름: `it["replacement"]` · `it["if_unfixed"]`(route 쪽) · `f.get("replacement")`(state 쪽).

**왜 `PUBLIC_FIELDS` 에 top-level 로 넣는가**(설계 결정 13). `decision_view` 통로는 `docreview_route.py:640-641` 이 `if it["disposition"] == "decide":` 일 때만 여므로, **`fix`·`defer`·`ask` 로 난 finding 의 두 칸은 원장에 한 글자도 안 남는다.** 그런데 설계 §5.2 는 「대체안은 같은 항목 안에 필수」를 **처분과 무관하게** 요구한다. 미루면 아무것도 안 하는 쪽이 기본값이고 그것이 곧 소실이다.

**`_auto_decides` 가 손으로 짓는 항목에는 이 칸이 없다** — 그래도 안전하다. `record_findings` 가 `{k: it.get(k) for k in PUBLIC_FIELDS}`(`docreview_state.py:625`)라 `KeyError` 가 아니라 `None` 이 된다(코드로 확인).

- [ ] **Step 1: 브랜치**

```bash
git fetch origin
git checkout -b feature/docreview-decision-render origin/main
```

- [ ] **Step 2: 실패할 케이스 둘을 쓴다**

새 픽스처 `shared/tests/fixtures/docreview/critic-fields.txt`:

````
층 1·2 를 봤다.

```docreview-layer1
- ref: c1
  layer: 1
  category: goal_fit
  anchor: "#2-goals"
  disposition: decide
  summary: "Goals 가 브리프의 goal 과 다른 것을 겨눈다"
  evidence: "브리프 §1 vs 문서 §2"
  replacement: "§2 를 브리프 §1 의 goal 한 문장으로 되돌린다"
  if_unfixed: "설계 전체가 다른 문제를 잘 푸는 쪽으로 굳는다"
```

```docreview-layer2
- ref: c2
  layer: 2
  category: placeholder
  anchor: "#5-architecture"
  disposition: fix
  summary: "§5 에 TBD 가 남아 있다"
  edit_scope: "#5-architecture"
  replacement: "TBD 를 실제 컴포넌트 이름으로 채운다"
  if_unfixed: "plan 이 그 자리를 스스로 지어낸다"
```
````

`cases.sh` 끝에 케이스 둘을 더한다:

```bash
# ── 칸 둘(replacement·if_unfixed)의 왕복 — 리뷰어 → normalize → 원장 ──────────
# 닫힌 열거가 셋이라(PROFILE_FIELDS · normalize 반환 · PUBLIC_FIELDS) 앞의 둘만 고치면
# 렌더까지는 도달하고 «원장에는 안 남는다». 그러면 다음 라운드가 그 값을 못 본다.
case_fields_roundtrip_decide() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-failed.yaml" --skip)" || { no "칸 왕복: route_r1 실패"; return; }
  assert_eq "$(fsum "$d" '다른 것을 겨눈다' '["replacement"]')" \
    "§2 를 브리프 §1 의 goal 한 문장으로 되돌린다" "칸 왕복: normalize 가 replacement 를 실어 나른다"
  assert_eq "$(fsum "$d" '다른 것을 겨눈다' '["if_unfixed"]')" \
    "설계 전체가 다른 문제를 잘 푸는 쪽으로 굳는다" "칸 왕복: normalize 가 if_unfixed 를 실어 나른다"
  assert_eq "$(st_yaml "$d" 'bool([f for f in st["findings"].values() if f.get("replacement") == "§2 를 브리프 §1 의 goal 한 문장으로 되돌린다"])')" \
    "True" "칸 왕복: PUBLIC_FIELDS 를 지나 원장에 top-level 로 남는다"
  rm -rf "$d"
}
# AC21' — decide «가 아닌» 처분에서도 남는가. decision_view 통로는 decide 에만 열리므로
# 이 케이스가 없으면 fix 로 난 과설계 지적이 대체안 없이 저자에게 간다.
case_fields_survive_non_decide() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-failed.yaml" --skip)" || { no "칸 비-decide: route_r1 실패"; return; }
  local fid; fid="$(jget "$d/fin.json" '[x["id"] for x in d["findings"] if x["disposition"]=="fix" and "TBD" in x["summary"]][0]')"
  assert_eq "$(st_yaml "$d" 'st["findings"]["'"$fid"'"].get("decision_view")')" "None" \
    "칸 비-decide: 선결조건 — 이 항목에는 decision_view 통로가 «없다»(공허하지 않음의 증거)"
  assert_eq "$(st_yaml "$d" 'st["findings"]["'"$fid"'"].get("replacement")')" \
    "TBD 를 실제 컴포넌트 이름으로 채운다" "AC21': fix 처분의 replacement 도 원장에 남는다"
  assert_eq "$(st_yaml "$d" 'st["findings"]["'"$fid"'"].get("if_unfixed")')" \
    "plan 이 그 자리를 스스로 지어낸다" "AC21': fix 처분의 if_unfixed 도 원장에 남는다"
  rm -rf "$d"
}
```

`shared/tests/test_docreview_route.sh` 의 케이스 목록 끝에 두 줄을 더한다:

```bash
case_fields_roundtrip_decide
case_fields_survive_non_decide
```

- [ ] **Step 3: 실패를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_route.sh 2>&1 | tail -20`
Expected: **FAIL** — 다섯 단언이 RED 다. `replacement`/`if_unfixed` 키가 `fin.json` 에 없어 `jget` 이 `KeyError` 로 죽고, 원장 조회는 `None` 이다. 「선결조건 — decision_view 가 None」 하나만 GREEN 이다.

- [ ] **Step 4: `normalize()` 에 두 키를 더한다**

`shared/docreview/scripts/docreview_route.py` 의 `normalize()` 반환 dict 마지막 두 항목 뒤:

```python
        "evidence": (str(item["evidence"]) if item.get("evidence") else None),
        # 갈래 2 의 칸 둘. 여기 없으면 리뷰어가 무엇을 적든 «조용히» 버려진다 —
        # 이 dict 는 입력을 갱신하는 것이 아니라 처음부터 새로 짓는다.
        "replacement": (str(item["replacement"]) if item.get("replacement") else None),
        "if_unfixed": (str(item["if_unfixed"]) if item.get("if_unfixed") else None),
    }
```

**`added` finding 도 같은 함수를 지난다**(`docreview_route.py:315` 의 `normalize(ad, 2, "a", i, L)`) — 재비판이 낸 항목도 자동으로 칸을 싣는다. 그것을 **내라고 적는 자리**는 agent 본문뿐이고 Task 10 이 그 자리를 고친다.

- [ ] **Step 5: `PUBLIC_FIELDS` 에 두 키를 더한다**

`shared/docreview/scripts/docreview_state.py:516-518`:

```python
PUBLIC_FIELDS = ("id", "lineage", "bucket", "supersedes", "origin", "layer", "category", "anchor",
                 "disposition", "summary", "edit_scope", "blocks", "evidence",
                 # 갈래 2 — top-level 이다. `decision_view` 통로는 disposition == "decide"
                 # 에만 열리므로(docreview_route.py:640-641) 그쪽에만 실으면 fix·defer·ask
                 # 로 난 항목의 대체안이 원장에 한 글자도 안 남는다.
                 "replacement", "if_unfixed",
                 "decision_view", "state", "promotion", "promoted_from", "immutable", "kind")
```

- [ ] **Step 6: GREEN 을 확인한다**

```bash
export PYTHONDONTWRITEBYTECODE=1
bash shared/tests/test_docreview_route.sh 2>&1 | tail -3
bash shared/tests/test_docreview_state.sh 2>&1 | tail -3
```
Expected: 둘 다 `Fail: 0`. route 의 Pass 수가 baseline 149 에서 **+5** 이상이다.

- [ ] **Step 7: 변이로 이빨을 확인한다 (커밋하지 않는다)**

| 변이 | 기대 |
|---|---|
| `normalize()` 에서 `"replacement": …` 줄을 지운다 | `test_docreview_route.sh` RED |
| `PUBLIC_FIELDS` 에서 `"replacement"` 만 뺀다 | `test_docreview_route.sh` RED (원장 단언 둘) |
| 양의 짝 — 아무것도 안 바꾸고 돌린다 | GREEN |

복원은 `git checkout HEAD -- <경로>`.

두 변이가 **다른 단언**을 깨야 한다. 같은 단언만 깨면 두 열거 중 하나가 안 잡히는 것이다 — 그 경우 원장 쪽 단언을 보강한다.

- [ ] **Step 8: 커밋**

```
feat(docreview): 리뷰어 finding 에 replacement·if_unfixed 두 칸을 잇는다

닫힌 열거가 셋이다 — PROFILE_FIELDS · normalize() 반환 · PUBLIC_FIELDS. 앞의 둘만
고치면 새 칸이 렌더까지는 가지만 원장에 안 남아 다음 라운드가 못 본다.

PUBLIC_FIELDS 에 top-level 로 넣는다. decision_view 통로는 disposition=="decide"
에만 열리므로(docreview_route.py:640-641) 그쪽에만 실으면 fix 로 난 과설계 지적이
대체안 없이 저자에게 간다 — 「대체안은 같은 항목 안에 필수」는 처분과 무관한
요구다.

기존 critic-r1.txt 는 안 건드린다(골든 셋 셋의 입력이다). 새 픽스처
critic-fields.txt 로 두 케이스를 태운다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

---

## Task 6: `_decision_view()` — 동어반복을 지우고 침묵을 공시한다

**Files:**
- Modify: `shared/docreview/scripts/docreview_route.py` (`_decision_view()`, `:213-238`)
- Modify: `shared/tests/fixtures/docreview/cases.sh` (새 케이스 하나)
- Modify: `shared/tests/test_docreview_route.sh` (케이스 등록)

**Interfaces:**
- Consumes: Task 5 의 `it["replacement"]`·`it["if_unfixed"]`.
- Produces: `decision_view` dict 에서 `change` 가 **사라지고** `if_unfixed`·`replacement` 가 생긴다. `basis`·`alternatives`·`impact`·`auto` 는 그대로.

**침묵과 판정을 가른다**(AC15 · 설계 D1.6). 이전 판은 두 경우에 같은 글자를 냈고, 그러면 **아무도 제안하지 않은 삭제**가 사용자에게 제안으로 전달된다. 이 경로는 리뷰어 실수에 한정되지 않는다 — `_auto_decides` 가 내는 `frozen_change` 는 애초에 `replacement` 가 없다.

| 상황 | 「그대로 두면」 | 「고치면」 |
|---|---|---|
| 리뷰어가 칸을 안 채웠다 | `(리뷰어가 안 적음)` | `(대체안 미작성)` |
| 리뷰어가 「그냥 빼라」고 판정했다 | (리뷰어가 쓴 문장) | `대체안 없음 — 그냥 뺀다` ← **리뷰어가 그 문자열을 실제로 낸 경우에만** |

- [ ] **Step 1: 실패할 케이스를 쓴다**

`cases.sh` 에:

```bash
# ── 동어반복 제거 + 침묵 공시 (AC15) ────────────────────────────────────────
# 「변경」이 헤더의 복사였다. 칸을 더해도 fallback 이 summary 를 되풀이하면 그 실패는
# «필드가 비어 있지 않아» 관측되지 않는다 — 그래서 부재는 리터럴로 말한다.
case_decision_view_no_tautology() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-failed.yaml" --skip)" || { no "동어반복: route_r1 실패"; return; }
  assert_eq "$(fsum "$d" '다른 것을 겨눈다' '["decision_view"].get("change", "<없음>")')" "<없음>" \
    "AC15: decision_view 에 change 키가 없다 (헤더 복사 제거)"
  assert_eq "$(fsum "$d" '다른 것을 겨눈다' '["decision_view"]["replacement"]')" \
    "§2 를 브리프 §1 의 goal 한 문장으로 되돌린다" "AC15 양의 짝: 채워진 replacement 는 그대로 난다"
  assert_eq "$(fsum "$d" '다른 것을 겨눈다' '["decision_view"]["if_unfixed"]')" \
    "설계 전체가 다른 문제를 잘 푸는 쪽으로 굳는다" "AC15 양의 짝: 채워진 if_unfixed 는 그대로 난다"
  rm -rf "$d"
}
# 부재가 summary 로 메워지지 않는다. frozen_change 는 애초에 두 칸이 없는 «실재하는»
# 경로라 리뷰어 실수를 지어내지 않고도 이 갈래를 태울 수 있다.
case_decision_view_absence_is_literal() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "침묵 공시: r1 실패"; return; }
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample-r2.md" > "$d/fin.json"
  local dv; dv="$(jget "$d/fin.json" '[x["decision_view"] for x in d["findings"] if x["category"]=="frozen_change"][0]')"
  assert_grep "$dv" '리뷰어가 안 적음' "AC15: if_unfixed 부재는 「(리뷰어가 안 적음)」으로 난다"
  assert_grep "$dv" '대체안 미작성' "AC15: replacement 부재는 「(대체안 미작성)」으로 난다"
  case "$dv" in
    *'그냥 뺀다'*) no "AC15: 부재가 「대체안 없음 — 그냥 뺀다」로 났다 — 아무도 제안하지 않은 삭제를 만들어 낸다" ;;
    *) ok "AC15: 부재가 삭제 제안으로 승격되지 않았다" ;;
  esac
  rm -rf "$d"
}
```

두 케이스를 `test_docreview_route.sh` 목록에 등록한다.

- [ ] **Step 2: 실패를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_route.sh 2>&1 | tail -20`
Expected: **FAIL** — `change` 가 아직 있고 `replacement`/`if_unfixed` 키가 `decision_view` 에 없다.

- [ ] **Step 3: `_decision_view()` 를 고친다**

`docreview_route.py` 의 반환문(현행 `:235-238`)을 바꾼다. 함수 머리의 긴 정정 주석은 **그대로 둔다** — 그 주석은 `_decide_choices_for` 결선의 근거이고 이 변경과 무관하다.

```python
    basis = it.get("evidence")
    if not basis:
        basis = "finding 없이 바뀜" if it["category"] == "frozen_change" else "(근거 없음)"
    # [갈래 2] `change` 를 «내지 않는다» — 그 값은 it["summary"] 였고 헤더가 이미 그
    # 문자열을 낸다(동어반복). 대신 두 칸을 낸다. **부재를 summary 로 메우지 않는다**:
    # 메우면 「리뷰어가 안 적었다」는 사실이 필드가 비어 있지 않다는 이유로 관측되지
    # 않는다. 그리고 두 부재 리터럴은 서로 다르다 — 침묵(`(대체안 미작성)`)과 판정
    # (`대체안 없음 — 그냥 뺀다`, 리뷰어가 그 문자열을 실제로 냈을 때만)은 다른
    # 사실이다. 같은 글자를 내면 아무도 제안하지 않은 삭제가 제안으로 전달된다.
    return {"if_unfixed": it.get("if_unfixed") or "(리뷰어가 안 적음)",
            "replacement": it.get("replacement") or "(대체안 미작성)",
            "basis": basis,
            "alternatives": [_CHOICE_LABEL[c] for c in choices],
            "impact": "%s · 인용 %s 섹션" % (it["anchor"], nref if nref is not None else "?"),
            "auto": it.get("origin") == "auto"}
```

`alternatives` 의 `_CHOICE_LABEL[c]` 는 **Task 7 이** `choice_label(c, kind)` 로 바꾼다. 여기서는 손대지 않는다 — 한 Task 가 한 축만 흔들어야 변이가 무엇을 잡는지 갈린다.

- [ ] **Step 4: GREEN 을 확인한다**

```bash
export PYTHONDONTWRITEBYTECODE=1
bash shared/tests/test_docreview_route.sh 2>&1 | tail -3
```
Expected: `Fail: 0`.

- [ ] **Step 5: `_rg_decide` 가 아직 옛 키를 읽는다는 것을 확인한다 (의도된 중간 상태)**

Run: `PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_state.sh 2>&1 | tail -3`
Expected: `Fail: 0` **이어야 한다.** `_rg_decide` 는 `dv.get("change", f.get("summary"))` 로 **fallback 이 있어** `change` 가 없어져도 죽지 않고 `summary` 를 낸다 — 즉 **이 시점의 렌더는 여전히 동어반복이다.** Task 8 이 그 줄을 바꾼다. 여기서 RED 가 나면 그 fallback 이 사라진 것이니 Task 8 을 앞당긴다.

이 중간 상태를 **커밋 메시지에 적는다** — 「지금 렌더는 여전히 동어반복이고 Task 8 이 닫는다」.

- [ ] **Step 6: 변이로 이빨을 확인한다**

| 변이 | 기대 |
|---|---|
| `"replacement": it.get("replacement") or "(대체안 미작성)"` → `or it["summary"]` | RED (fallback 이 summary 로 되돌아감 — 설계 §10 의 AC15 변이) |
| 부재 리터럴 둘을 같은 글자로 통일 | RED (`case_decision_view_absence_is_literal` 의 셋째 단언) |
| 양의 짝 — 정상 입력에서 `replacement` == 리뷰어가 쓴 값 | **먼저 GREEN 이어야** 위 변이가 유효하다 |

- [ ] **Step 7: 커밋**

```
feat(docreview): decision_view 가 동어반복 대신 「그대로 두면 / 고치면」을 낸다

change 는 it["summary"] 였고 헤더가 이미 그 문자열을 낸다 — 정보량 0 인 줄이었다.
칸을 더하는 것만으로는 안 고쳐진다: fallback 이 summary 를 되풀이하면 그 실패는
필드가 비어 있지 않다는 이유로 관측되지 않는다.

부재 리터럴 둘을 «다르게» 둔다. 침묵(「(대체안 미작성)」)과 판정(「대체안 없음 —
그냥 뺀다」)은 다른 사실이다 — 같은 글자를 내면 아무도 제안하지 않은 삭제가
사용자에게 제안으로 전달된다. frozen_change 가 애초에 replacement 없이 오는
실재 경로라 이 갈래는 지어낸 것이 아니다.

중간 상태 — _rg_decide 는 아직 dv.get("change", summary) 로 fallback 해 렌더는
여전히 동어반복이다. 다음 Task 가 그 줄을 바꾼다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

---

## Task 7: 선택지 라벨을 `kind` 의 함수로 — 가장 위험한 변경

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py` (`_CHOICE_LABEL` `:1091` · 새 `choice_label()` · `_rg_decide` `:1114` · `_rg_expired` `:1137`)
- Modify: `shared/docreview/scripts/docreview_route.py` (import `:24` · `_decision_view` `:236`)
- Modify: `shared/tests/fixtures/docreview/cases.sh` (`:375` · `:490` · `:512` · `:1174`)
- Modify: `shared/tests/test_docreview_mutations.sh` (`:572` · `:581` · `:612`)

**Interfaces:**
- Produces: `choice_label(choice, kind) -> str`. `docreview_route.py` 가 이것을 import 한다(`_CHOICE_LABEL` 직접 참조를 그만둔다).
- Consumes: `st["decides"][fid]["kind"]`(렌더 쪽) · `it.get("kind")`(라우팅 쪽).

**왜 상태의 함수여야 하는가** (codex 가 단독으로 잡은 결함 — D1.9). `cmd_decide`(`docreview_state.py:739-750`)는 `kind=post` 에서 `reject` 를 고르면 **revert permit 을 만들고**, `adopt` 는 현재 변경을 유지한 채 닫는다. **그 자리에서 「그대로 둔다」는 실제로 원복이다.** 상태를 모르는 고정 라벨을 사람말로 바꾸면 **동작을 반대로 설명**하게 되고, 그것은 이 PR 이 고치려는 결함을 새로 만드는 셈이다.

**`kind` 는 렌더 시점에 확실히 있다** — `record_findings`(`:625` 아래)가 `st["decides"][fid] = {"state": "open", "kind": it.get("kind") or "pre", …}` 로 **기록 시점에 강제**한다(코드로 확인). 라우팅 시점에도 있다 — `_classify_items`(`:410`)가 `pre`, `_auto_decides`(`:447`)가 `post` 를 `_decision_view` 호출(`:641`) **전에** 찍는다.

**리터럴이 일곱 자리에 복제돼 있다** — 이 Task 가 가장 위험한 이유다:

| 자리 | 무엇 | 바뀌는가 |
|---|---|---|
| `cases.sh:375` | 재상승 후속의 `alternatives` | `kind` 가 원본(`pre`)에서 승계되므로 **pre 라벨**로 |
| `cases.sh:490` | `choices_match()` 의 `LABEL` dict | **kind 를 받아야** 한다 |
| `cases.sh:512` | `choices_match_expired()` 의 `LABEL` dict | 〃 |
| `cases.sh:1174` | `frozen_change` 의 `alternatives` | `kind=post` → **post 라벨**로 기댓값 자체가 바뀐다 |
| `test_docreview_mutations.sh:572` | `_rg_decide` 결선 변이 | sed 패턴 갱신 |
| `test_docreview_mutations.sh:581` | `_decision_view` 결선 변이 | 〃 |
| `test_docreview_mutations.sh:612` | `_rg_expired` 결선 변이 | 〃 |

**셋을 다 갱신하지 않으면 빠진 셀이 「안 잡힘」이 아니라 「못 잼」으로 조용히 통과한다** — 같은 파일 `:196-199` 가 그 함정을 이미 기록해 두었다(치환 여럿 중 일부만 죽으면 판정이 unmeasurable 로 떨어진다).

- [ ] **Step 1: 실패할 케이스를 쓴다 (AC17′)**

`cases.sh` 에:

```bash
# ── 라벨은 kind 의 함수다 (AC17 · AC17') ───────────────────────────────────
# cmd_decide 는 kind=post 에서 reject 에 revert permit 을 만든다 — 그 자리에서
# 「그대로 둔다」는 실제로 원복이다. 고정 라벨을 사람말로 바꾸면 동작을 반대로
# 설명하게 된다. 이 케이스는 얼림 diff 가 만드는 «실재하는» post 항목 위에서 돈다.
case_labels_are_kind_dependent() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "라벨 kind: r1 실패"; return; }
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample-r2.md" > "$d/fin.json"
  local render; render="$(py docreview_state.py gate --state-dir "$d" --render)"
  local fid; fid="$(jget "$d/fin.json" '[x["id"] for x in d["findings"] if x["category"]=="frozen_change"][0]')"
  assert_eq "$(st_yaml "$d" 'st["decides"]["'"$fid"'"]["kind"]')" "post" \
    "라벨 kind: 선결조건 — 이 항목은 kind=post 다(공허하지 않음의 증거)"
  local blk; blk="$(printf '%s\n' "$render" | grep -F -A6 -- "] $fid —")"
  assert_grep "$blk" '현재 변경 유지\(채택\)' "AC17: post 의 adopt 라벨은 「현재 변경 유지(채택)」"
  assert_grep "$blk" '이전 상태로 원복\(기각\)' "AC17: post 의 reject 라벨은 「이전 상태로 원복(기각)」"
  case "$blk" in
    *'그대로 둔다'*) no "AC17': post 자리에 「그대로 둔다」로 읽히는 라벨이 있다 — reject 가 revert permit 을 만드는데 동작을 반대로 설명한다" ;;
    *) ok "AC17': post 자리에 「그대로 둔다」로 읽히는 라벨이 하나도 없다" ;;
  esac
  rm -rf "$d"
}
# pre 자리의 양의 짝 — 위 부재 단언이 「라벨이 통째로 사라져서」 통과하는 것을 막는다.
case_labels_pre_site() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-failed.yaml" --skip)" || { no "라벨 pre: route_r1 실패"; return; }
  local render; render="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_grep "$render" '고친다\(채택\)'       "AC17: pre 의 adopt 라벨은 「고친다(채택)」"
  assert_grep "$render" '그대로 둔다\(기각\)'  "AC17: pre 의 reject 라벨은 「그대로 둔다(기각)」"
  assert_grep "$render" '나중에 정한다\(보류\)' "AC17: hold 라벨은 양쪽에서 「나중에 정한다(보류)」"
  rm -rf "$d"
}
```

두 케이스를 `test_docreview_route.sh` 목록에 등록한다. **`test_docreview_state.sh` 에는 등록하지 않는다** — 두 케이스가 route 의 `finalize` 를 지나므로 route 쪽이 자연스러운 집이다.

- [ ] **Step 2: 실패를 확인한다**

Expected: **FAIL** — 고정 라벨 `채택(적용)` 이 양쪽에서 나온다.

- [ ] **Step 3: `_CHOICE_LABEL` 을 kind 중첩 dict 로 바꾸고 접근자를 만든다**

`docreview_state.py:1091` 을 통째로 바꾼다:

```python
# 선택지 라벨은 **상태의 함수**다. `cmd_decide` 가 kind=post 에서 reject 에 revert
# permit 을 만들므로(아래 `cmd_decide` 의 post 분기) 고정 라벨을 사람말로 바꾸면
# 그 자리에서 «동작을 반대로 설명»하게 된다. 회계어(채택·기각·보류)는 괄호 안에
# 그대로 보존한다 — 낱말을 바꾸는 것이 아니라 사람말을 앞에 두는 것이다.
_CHOICE_LABEL = {
    "pre":  {"adopt": "고친다(채택)",        "reject": "그대로 둔다(기각)",      "hold": "나중에 정한다(보류)"},
    "post": {"adopt": "현재 변경 유지(채택)", "reject": "이전 상태로 원복(기각)", "hold": "나중에 정한다(보류)"},
}


def choice_label(choice, kind) -> str:
    """선택지 라벨 — 리터럴이 사는 유일한 자리. `kind` 가 없으면 `pre` 로 읽는다
    (`record_findings` 가 기록 시점에 `it.get("kind") or "pre"` 로 강제하므로
    원장에서 온 값은 항상 둘 중 하나다 — None 은 원장 밖 호출부에서만 온다)."""
    return _CHOICE_LABEL.get(kind or "pre", _CHOICE_LABEL["pre"])[choice]
```

- [ ] **Step 4: 세 소비자를 잇는다**

`docreview_state.py` 의 `_rg_decide`:

```python
    alternatives = [choice_label(c, d.get("kind")) for c in decide_choices(st, fid)]
```
— `d = st["decides"].get(fid) or {}` 가 **이 줄보다 앞으로** 와야 한다. 현행 순서는 `alternatives` 가 먼저이므로 두 줄을 맞바꾼다.

`docreview_state.py` 의 `_rg_expired`:

```python
    alt = " / ".join(choice_label(c, d.get("kind")) for c in decide_choices(st, fid))
```
— 여기는 `d` 가 이미 위에 있다.

`docreview_route.py:24` 의 import 목록에서 `_CHOICE_LABEL` 을 빼고 `choice_label` 을 넣는다. `_decision_view` 의 반환:

```python
            "alternatives": [choice_label(c, it.get("kind")) for c in choices],
```

- [ ] **Step 5: `cases.sh` 의 라벨 리터럴 네 자리를 고친다**

| 줄 | 지금 | 바꾼 뒤 |
|---|---|---|
| `:375` | `"['채택(적용)', '기각(원복)']"` | `"['고친다(채택)', '그대로 둔다(기각)']"` — 이 후속은 `kind` 를 원본(critic 이 낸 `pre` decide)에서 승계한다 |
| `:1174` | `"['채택(적용)', '기각(원복)', '보류']"` | `"['현재 변경 유지(채택)', '이전 상태로 원복(기각)', '나중에 정한다(보류)']"` — `frozen_change` 는 `kind=post` 다 |

`:490` 의 `choices_match()` 와 `:512` 의 `choices_match_expired()` 는 **인라인 `LABEL` dict 를 엔진에서 import 한다.** 리터럴을 두 벌 유지하면 그 둘이 갈리는 날 락이 조용히 낡는다 — 이 파일이 이미 그 실패를 한 번 기록했다(`:502-505` 의 I4 정정).

```python
LABEL = {"adopt": "채택(적용)", "reject": "기각(원복)", "hold": "보류"}
```
↓
```python
from docreview_state import load_state, decide_choices, choice_label
...
kind = (st["decides"].get(fid) or {}).get("kind")
expected = {choice_label(c, kind) for c in choices}
```

두 함수 모두 이미 `sys.path.insert(0, sys.argv[1])` 로 `$SCRIPTS` 를 물고 `load_state`·`decide_choices` 를 import 하므로 **같은 줄에 이름 하나만 더한다.**

- [ ] **Step 6: `test_docreview_mutations.sh` 의 sed 패턴 셋을 고친다**

| 줄 | 새 sed |
|---|---|
| `:572` `rg_decide_alternatives_hardcoded` | `s/alternatives = \[choice_label(c, d.get("kind")) for c in decide_choices(st, fid)\]/alternatives = ["채택(적용)", "기각(원복)", "보류"]/` |
| `:581` `decision_view_unwired` | `s/"alternatives": \[choice_label(c, it.get("kind")) for c in choices\],/"alternatives": ["채택(적용)", "기각(원복)", "보류"],/` |
| `:612` `rg_expired_unwired_and_offers_hold` | `s/alt = " \/ "\.join(choice_label(c, d.get("kind")) for c in decide_choices(st, fid))/alt = "채택 \/ 기각 \/ 보류"/` |

세 셀의 **주석도 함께 갱신한다** — 「`_CHOICE_LABEL` 상수 목록으로 되돌린다」가 아니라 「`choice_label` 결선을 끊고 kind 를 모르는 고정 셋으로 되돌린다」다.

- [ ] **Step 7: 매치 0건이 아닌지 확인한다 — 이 Task 의 가장 흔한 실패**

```bash
export PYTHONDONTWRITEBYTECODE=1
bash shared/tests/test_docreview_mutations.sh 2>&1 | grep -E 'rg_decide_alternatives|decision_view_unwired|rg_expired_unwired'
```
Expected: 세 줄 다 `RED(...) 생존(...)` + `[churn 1/1]`. **`churn 0/1` 이나 `unmeasurable` 이 보이면 sed 가 아무 데도 안 맞은 것이다** — 「안 잡힘」이 아니라 「못 잼」이고, 통과로 읽히므로 반드시 눈으로 확인한다.

- [ ] **Step 8: 전체 GREEN**

```bash
export PYTHONDONTWRITEBYTECODE=1
bash shared/tests/test_docreview_route.sh 2>&1 | tail -3
bash shared/tests/test_docreview_state.sh 2>&1 | tail -3
bash shared/tests/test_docreview_gate_visibility.sh 2>&1 | tail -3
bash shared/tests/test_docreview_intent.sh 2>&1 | tail -3
bash shared/tests/test_docreview_anchor.sh 2>&1 | tail -3
bash shared/tests/test_docreview_mutations.sh 2>&1 | tail -3
```
Expected: 여섯 다 `Fail: 0`. `test_docreview_golden.sh` 는 **아직 RED 여도 된다** — 골든은 Task 14 에서 한 번에 다시 뜬다. 그 RED 를 여기서 확인해 두고 커밋 메시지에 적는다.

- [ ] **Step 9: 커밋**

```
fix(docreview): 선택지 라벨을 kind 의 함수로 — 고정 라벨이 동작을 반대로 설명했다

cmd_decide 는 kind=post 에서 reject 에 revert permit 을 만든다. 그 자리에서
「그대로 둔다」는 실제로 원복이다 — 고정 라벨을 사람말로 바꾸는 순간 동작을 반대로
설명하게 되고, 그것이 이 PR 이 고치려는 결함을 새로 만드는 길이었다. 라벨 리터럴은
choice_label() 한 곳에만 산다.

회계어(채택·기각·보류)는 괄호 안에 그대로 보존한다 — 낱말을 바꾸는 것이 아니라
사람말을 앞에 두는 것이다.

리터럴이 일곱 자리에 복제돼 있었다. cases.sh 의 두 헬퍼(choices_match ·
choices_match_expired)는 인라인 LABEL dict 대신 엔진의 choice_label 을 import
한다 — 리터럴 두 벌은 갈리는 날 조용히 낡는다(이 파일이 이미 I4 로 그 실패를
기록해 두었다). frozen_change 의 기댓값은 post 라벨로 «값 자체가» 바뀐다.

test_docreview_mutations.sh 의 sed 셋을 갱신했다. 셋을 다 갱신하지 않으면 빠진
셀이 매치 0건으로 「못 잼」이 되는데 그것이 통과로 읽힌다(같은 파일 :196-199 가
기록한 함정) — churn 1/1 을 눈으로 확인했다.

test_docreview_golden.sh 는 이 커밋에서 RED 다. 골든은 렌더가 다 선 뒤 한 번에
다시 뜬다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

---

## Task 8: 게이트 렌더 여섯 줄 + `category` 사람말 사상

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py` (새 `CATEGORY_GLOSS`/`category_gloss()` · `_rg_decide()` `:1106-1120`)
- Modify: `shared/docreview/scripts/docreview_route.py` (`_decision_view()` 의 `impact`)
- Modify: `shared/tests/test_docreview_profile_schema.sh` (사상 커버리지 축)
- Modify: `shared/tests/fixtures/docreview/cases.sh` (렌더 케이스)

**Interfaces:**
- Consumes: Task 6 의 `decision_view["if_unfixed"]`·`["replacement"]`, Task 7 의 `choice_label`.
- Produces: `category_gloss(cat) -> str | None`. Task 9 의 게이트 머리와 PR 2 의 새 축이 같은 표를 쓴다.

**바꾼 뒤의 여섯 줄** (설계 §5.8 의 밀도 표 — **줄 수를 말하는 자리는 그 표 하나다**):

```
[decide] f3 — <summary>
  그대로 두면: <if_unfixed>
  고치면: <replacement>
  근거: <evidence>
  자리: <anchor> (<category 사람말>) · 인용 N 섹션
  대안: <kind 에 맞는 라벨 셋>
```

- **「영향」 → 「자리」** — anchor + 인용수는 영향이 아니라 위치다. 이름을 정직하게 바꾸고 `category` 를 함께 싣는다(지금 렌더에 한 번도 안 나오는 값이다).
- **「대안」 줄은 항상 낸다.** 조건부로 내지 않는다 — 그 줄이 `cases.sh:558` 「제안 = 수용」 락의 **발동 조건**이다. 줄이 사라지면 `offered` 가 빈 집합이라 RED 이고, 그 단언을 지우면 평범한 항목에 대한 렌더-측 채널이 통째로 사라진다. `_rg_expired` 가 **똑같은 실패를 이미 한 번 고쳤다**(`:1128-1138` 의 I4 정정 — 「우연히 일치했을 뿐 그 함수를 쓰지 않았다」). 밀도는 줄을 지워서가 아니라 상태별 라벨로 정보량을 채워서 얻는다.

**사상 코퍼스는 네 프로필 + 엔진 category 다**(AC19′ · 설계 결정 15). **렌더는 프로필별이 아니라 엔진 하나**라, 두 프로필로 좁히면 **가장 흔한 항목**(`frozen_change` — 얼림 검사가 잡은 변경)이 상시 advisory 경로가 되어 D13-③ 이 거기서 안 닫힌다.

**`overdesign` 을 지금 심는 이유.** PR 2 는 `docreview_state.py` 를 **0줄** 건드려야 한다(AC13) — 그래야 축이 단독으로 머지 가능하다. 그래서 이 표가 PR 2 의 축 이름을 **미리** 담는다. 락은 「프로필에서 도출한 이름 전부가 사상에 있다」(∀, fail-closed)를 재므로 **여분 항목은 무해**하고, 새 축이 사상 없이 들어오는 날은 RED 다.

- [ ] **Step 1: 사상 커버리지 축을 먼저 쓴다**

`shared/tests/test_docreview_profile_schema.sh` 끝(`finish` 앞)에:

```bash
# ── category 사람말 사상 커버리지 (AC19') ──────────────────────────────────
# 렌더는 프로필별이 아니라 «엔진 하나»다. 그래서 사상 코퍼스는 네 프로필의 층 1·2 축
# 전부 + 엔진이 직접 만드는 category(frozen_change 등)다. 두 프로필로 좁히면 가장 흔한
# 항목(얼림 검사가 잡은 변경)이 상시 advisory 경로가 된다.
#
# 방향은 ∀ 다: 도출한 이름 «전부»가 사상에 있어야 한다. 여분 사상은 무해하다(PR 2 가
# 더할 축 이름을 이 표가 미리 담는다 — PR 2 는 이 파일을 0줄 건드려야 하므로).
note "── category 사람말 사상 — 코퍼스는 열거가 아니라 프로필에서 도출한다"
MISSING="$(python3 - "$REPO_ROOT" <<'PY'
import pathlib, sys, yaml
root = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(root / "plugins" / "spec-distill" / "scripts"))
from docreview_state import category_gloss
names = set()
profs = sorted(root.glob("plugins/*/references/docreview-profiles/*.md"))
for p in profs:
    fm = p.read_text(encoding="utf-8").split("---")[1]
    lr = yaml.safe_load(fm)["layer_rubric"]
    names |= set(lr.get("layer1") or []) | set(lr.get("layer2") or [])
# 엔진이 직접 만드는 category — docreview_route.py 가 손으로 짓는 자리에서 온다.
names |= {"frozen_change", "other"}
print(len(profs), len(names))
for n in sorted(names):
    if category_gloss(n) is None:
        print("MISSING", n)
PY
)"
head_line="$(printf '%s\n' "$MISSING" | head -1)"
n_prof_seen="$(printf '%s' "$head_line" | cut -d' ' -f1)"
n_names="$(printf '%s' "$head_line" | cut -d' ' -f2)"
if [ "${n_prof_seen:-0}" -ge 4 ] && [ "${n_names:-0}" -ge 25 ]; then
  ok "사상: 프로필 ${n_prof_seen}개에서 category ${n_names}개를 도출했다 (양의 짝 — 아래 판정이 공허하지 않다)"
else
  no "사상: 프로필 ${n_prof_seen}개 · category ${n_names}개 — 도출이 무너졌다. 아래 판정이 공허하다"
fi
miss="$(printf '%s\n' "$MISSING" | grep -c '^MISSING ' || true)"
if [ "${miss:-0}" -eq 0 ]; then
  ok "사상: 도출한 category 전부에 사람말이 있다"
else
  no "사상: 사람말 없는 category ${miss}개 — $(printf '%s\n' "$MISSING" | sed -n 's/^MISSING //p' | tr '\n' ' ')"
fi
```

- [ ] **Step 2: 렌더 케이스를 쓴다 (AC16 · AC19′)**

`cases.sh` 에:

```bash
# ── 게이트 렌더 여섯 줄 (AC16 · AC19') ─────────────────────────────────────
case_gate_render_six_lines() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-failed.yaml" --skip)" || { no "렌더: route_r1 실패"; return; }
  local fid; fid="$(jget "$d/fin.json" '[x["id"] for x in d["findings"] if x["disposition"]=="decide" and "다른 것을 겨눈다" in x["summary"]][0]')"
  local render blk
  render="$(py docreview_state.py gate --state-dir "$d" --render)"
  blk="$(printf '%s\n' "$render" | grep -F -A5 -- "] $fid —")"
  assert_grep "$blk" '^  그대로 두면: 설계 전체가' "AC16: 「그대로 두면」 줄이 if_unfixed 를 낸다"
  assert_grep "$blk" '^  고치면: §2 를 브리프'      "AC16: 「고치면」 줄이 replacement 를 낸다"
  assert_grep "$blk" '^  근거: '                     "AC16: 「근거」 줄이 있다"
  assert_grep "$blk" '^  자리: #2-goals \(목표가 다른 것을 겨눔\) · 인용 ' \
    "AC16·AC19': 「자리」 줄이 anchor · category 사람말 · 인용 수를 함께 낸다"
  assert_grep "$blk" '^  대안: '                     "AC16: 「대안」 줄은 항상 난다"
  case "$blk" in
    *'  변경: '*) no "AC16: 「변경」 줄이 아직 난다 — 헤더 복사(동어반복)" ;;
    *) ok "AC16: 「변경」 줄이 사라졌다" ;;
  esac
  case "$blk" in
    *'  영향: '*) no "AC16: 「영향」 줄이 아직 난다 — 위치를 영향이라 부른다" ;;
    *) ok "AC16: 「영향」이 「자리」로 바뀌었다" ;;
  esac
  rm -rf "$d"
}
```

`test_docreview_route.sh` 에 등록한다.

- [ ] **Step 3: 실패를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_profile_schema.sh 2>&1 | tail -5`
Expected: **FAIL** — `category_gloss` 가 아직 없어 `ImportError` 로 `$MISSING` 이 비고 양의 짝이 RED.

Run: `PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_route.sh 2>&1 | tail -10`
Expected: **FAIL** — 렌더가 아직 `변경`·`영향` 을 낸다.

- [ ] **Step 4: 사상 표와 접근자를 만든다**

`docreview_state.py` 의 `_CHOICE_LABEL` 바로 위에:

```python
# category 의 사람말 — 렌더가 쓰는 유일한 자리. 코퍼스는 네 프로필(brief · design-doc ·
# seed · generic)의 층 1·2 축 전부 + 엔진이 직접 만드는 category 다. 렌더는 프로필별이
# 아니라 엔진 하나이므로 두 프로필로 좁히면 가장 흔한 항목(frozen_change)이 상시
# advisory 경로가 된다. `shared/tests/test_docreview_profile_schema.sh` 가 «프로필에서
# 도출한 이름 전부에 사상이 있는가»를 ∀ 로 재므로, 새 축이 사상 없이 들어오면 RED 다.
# 여분 항목은 무해하다 — `overdesign` 은 프로필보다 먼저 들어와 있다(그 축을 더하는 PR 이
# 이 파일을 0줄 건드려야 단독 머지가 가능하기 때문이다).
CATEGORY_GLOSS = {
    # brief 층 1·2
    "direction": "방향의 반증", "distortion": "원문의 뜻이 바뀜",
    "omission": "원문에 있는 것이 빠짐", "invention": "원문에 없는 것이 들어옴",
    "provenance_mislabel": "출처 표기가 틀림", "authority_syntax": "열린 것을 확정으로 못박음",
    "evidence_unsupported": "근거가 요약을 안 받침",
    # design-doc 층 1·2
    "goal_fit": "목표가 다른 것을 겨눔", "problem_definition": "문제 정의가 어긋남",
    "scope": "범위가 넓어지거나 좁아짐", "architecture": "확정 제약 위반",
    "component_relations": "의존 방향이 안 닫힘", "data_flow": "데이터가 끊김",
    "tradeoffs": "기각 사유가 확정과 모순", "feasibility": "단정한 리포 사실이 없음",
    "placeholder": "TBD·빈 절", "ambiguity": "두 가지로 읽힘",
    "scope_creep": "분해 안 되는 묶음", "approaches_comparison": "대안 비교 없는 단정",
    "isolation": "컴포넌트 경계가 흐림", "testing": "검증 전략 부재",
    "handoff_incomplete": "이어갈 컨텍스트 부족",
    # seed 층 1
    "unfounded_addition": "원문에 없는 요구가 더해짐", "example_as_requirement": "예시가 요구로 승격됨",
    "premature_closure": "열어 둔 선택이 닫힘", "inference_as_decision": "추론이 결정처럼 쓰임",
    # generic 층 1·2
    "logic": "결론이 전제에서 안 따라 나옴", "assumption": "말해지지 않은 전제",
    "completeness": "약속하고 안 채운 자리", "evidence": "근거 없는 단정",
    "actionability": "무엇을 할지 알 수 없음", "structure": "목차와 본문의 불일치",
    # 엔진이 직접 만드는 것
    "frozen_change": "얼림 검사가 잡은 변경", "other": "분류 없음",
    # 갈래 1 이 더할 축 — 프로필보다 먼저 여기 선다(위 문단)
    "overdesign": "goal 대비 과함",
}


def category_gloss(cat):
    """사람말 또는 None. **없으면 조용히 빈칸으로 두지 않는다** — 부르는 쪽이
    원래 이름을 그대로 내고 그 사실을 렌더에 한 줄로 공시한다."""
    return CATEGORY_GLOSS.get(cat)
```

- [ ] **Step 5: `_decision_view` 가 사람말을 싣게 한다**

`docreview_route.py:24` 의 import 에 `category_gloss` 를 더하고, `_decision_view` 의 `impact` 를:

```python
    gloss = category_gloss(it["category"])
    ...
            "impact": "%s (%s) · 인용 %s 섹션" % (it["anchor"], gloss or it["category"],
                                                nref if nref is not None else "?"),
            "category_unglossed": None if gloss else it["category"],
```

**`cases.sh:1173` 이 `impact` 에 `인용 1 섹션` 이 있는지 `assert_grep` 으로 잰다**(실측) — 사람말을 `인용` **앞**에 넣으므로 그 단언은 그대로 GREEN 이다. 순서를 뒤집지 않는다.

- [ ] **Step 6: `_rg_decide` 를 여섯 줄로 바꾼다**

```python
def _rg_decide(st, g, fid):
    # [Task 4 — §6.4 한계 (a)] 「대안:」 줄은 `dv.get("alternatives")` 가 아니라
    # `decide_choices` 로 낸다 — 그쪽은 라우팅 시점에 이 id 를 못 보므로 여기가
    # «제안 = 수용» 이 실제로 성립하는 유일한 자리다. `dv` 는 항목별 서술 네 필드에
    # 여전히 쓴다.
    # [갈래 2] 「변경」이 사라지고 「그대로 두면 / 고치면」 둘로 갈린다 — 헤더가 이미
    # 「무엇이 문제인가」를 내므로 동어반복이 원리적으로 불가능해진다. 「영향」은
    # 「자리」다(anchor + 인용수는 영향이 아니라 위치다). **「대안」 줄은 조건부로
    # 내지 않는다** — 그 줄이 `cases.sh` 의 「제안 = 수용」 락의 발동 조건이고,
    # 형제 `_rg_expired` 가 똑같은 실패를 이미 한 번 고쳤다.
    f = st["findings"][fid]
    dv = f.get("decision_view") or {}
    d = st["decides"].get(fid) or {}
    alternatives = [choice_label(c, d.get("kind")) for c in decide_choices(st, fid)]
    lines = ["[decide%s] %s — %s%s" % (" auto" if dv.get("auto") else "", fid, f.get("summary"), _post_kind_notice(d)),
             "  그대로 두면: %s" % dv.get("if_unfixed", "(리뷰어가 안 적음)"),
             "  고치면: %s" % dv.get("replacement", "(대체안 미작성)"),
             "  근거: %s" % dv.get("basis", f.get("evidence") or "—"),
             "  자리: %s" % dv.get("impact", f.get("anchor")),
             "  대안: %s" % " / ".join(alternatives)]
    # 사람말이 없는 category 는 원래 이름으로 나가되 그 사실을 «말한다». 조용히
    # 빈칸으로 두면 사상이 낡았다는 것이 아무 데도 안 남는다(D13-③ 이 안 닫힌다).
    if dv.get("category_unglossed"):
        lines.append("  ↳ 사람말 사상 없음: %s — 원래 이름 그대로 낸다" % dv["category_unglossed"])
    return lines
```

- [ ] **Step 7: GREEN 확인**

```bash
export PYTHONDONTWRITEBYTECODE=1
bash shared/tests/test_docreview_profile_schema.sh 2>&1 | tail -3
bash shared/tests/test_docreview_route.sh 2>&1 | tail -3
bash shared/tests/test_docreview_state.sh 2>&1 | tail -3
bash shared/tests/test_docreview_gate_visibility.sh 2>&1 | tail -3
```
Expected: 넷 다 `Fail: 0`. `test_docreview_golden.sh` 는 여전히 RED(Task 14 가 닫는다).

- [ ] **Step 8: 「제안 = 수용」 락이 살아 있는지 눈으로 본다**

Run: `PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_route.sh 2>&1 | grep '제안=수용'`
Expected: 세 줄 다 `✓`. **AC16 의 증거가 이것이다** — 「대안」 줄을 지웠으면 여기가 RED 다.

- [ ] **Step 9: 변이로 이빨을 확인한다**

| 변이 | 기대 |
|---|---|
| `"  고치면: %s" % dv.get("replacement", …)` → `% f.get("summary")` | RED (동어반복 복귀) |
| `CATEGORY_GLOSS` 에서 `"frozen_change"` 항목을 지운다 | `test_docreview_profile_schema.sh` RED |
| `lines` 에서 「대안」 줄을 조건부로 만든다 | `제안=수용` 세 단언 RED |

- [ ] **Step 10: 커밋**

```
feat(docreview): 게이트 렌더가 「그대로 두면 / 고치면」과 category 사람말을 낸다

다섯 줄 중 실효 정보는 셋이었다 — 「변경」은 헤더의 복사(정보 0), 「대안」은 전
항목 동일(정보 0), 「영향」은 영향이 아니라 위치. category 는 렌더에 한 번도 안
나왔다.

여섯 줄 중 정보 0 인 줄은 없다. 줄이 하나 늘지만 늘어난 줄은 기존 락의 발동
조건이고 사라진 것은 동어반복 한 줄이다 — 글이 아니라 정보를 늘린다.

「대안」 줄은 조건부로 내지 않는다. 그 줄이 cases.sh 의 「제안 = 수용」 락의 발동
조건이라 사라지면 offered 가 빈 집합이고, 그 단언을 지우면 평범한 항목에 대한
렌더-측 채널이 통째로 사라진다 — _rg_expired 가 똑같은 실패를 이미 한 번 고쳤다.

사상 코퍼스는 네 프로필 + 엔진 category 다. 렌더가 프로필별이 아니라 엔진
하나이므로 두 프로필로 좁히면 가장 흔한 항목(frozen_change)이 상시 advisory
경로가 된다. 사상에 없는 이름은 원래 이름으로 내되 그 사실을 한 줄로 공시한다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

---

## Task 9: 게이트 머리의 순서 뜻 한 줄 + 같은 anchor 묶음

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py` (`render_gate()`)
- Modify: `shared/tests/fixtures/docreview/cases.sh` (케이스 하나)

**Interfaces:**
- Consumes: `GATE_ROWS`(`:537-553`) 의 순서 — **바꾸지 않는다**.
- Produces: 렌더 머리 셋째 줄 + anchor 묶음 표시.

**순위를 새로 매기지 않는다**(ⓓ · 설계 §5.7). `GATE_ROWS` 10행의 순서는 이미 결정론이지만 **상태 범주** 순이다. 문제는 「순위가 없다」가 아니라 「있는 순서의 뜻이 안 보인다」였다. 오케스트레이터가 순위를 매기면 **그 순위 자체가 판단**이고 사용자가 그 위험을 받아들인다고 말한 적이 없다.

**묶음은 표시일 뿐이다**(D24) — `AskUserQuestion` 질문 수도 항목별 선택권도 그대로다. 그래서 AC18′ 는 「묶기 전후로 질문 수가 같다」를 **함께** 잰다.

- [ ] **Step 1: 케이스를 쓴다**

```bash
# ── 게이트 머리의 순서 뜻 + anchor 묶음 (AC18 · AC18') ──────────────────────
case_gate_head_and_grouping() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "게이트 머리: route_r1 실패"; return; }
  local render; render="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_grep "$render" '열린 결정 먼저' "AC18: 머리에 GATE_ROWS 순서의 뜻이 난다"
  # AC18' — 묶음은 «표시»다. 묶기 전후로 게이트가 세는 항목 수(= AskUserQuestion 질문 수)가
  # 같다. gate_summary 의 버킷을 세면 그 수가 나온다 — 렌더와 독립인 채널이라 순환이 아니다.
  local n_items; n_items="$(py docreview_state.py gate --state-dir "$d" | jgets 'len(d["open_decide"]) + len(d["unapplied_fix"]) + len(d["blocking_ask_open"])')"
  local n_headers; n_headers="$(printf '%s\n' "$render" | grep -cE '^\[(decide|미적용 fix|ask 비차단)' || true)"
  [ "${n_items:-0}" -gt 0 ] \
    && ok "AC18' 양의 짝: 이 케이스에 열린 항목이 ${n_items}개 있다 (아래 등식이 0 == 0 으로 통과하지 않는다)" \
    || no "AC18': 열린 항목이 0개다 — 아래 등식이 공허하다. 항목을 만드는 픽스처로 바꿔라"
  assert_eq "$n_headers" "$n_items" "AC18': 묶음이 항목 수를 바꾸지 않는다(질문 수 불변)"
  rm -rf "$d"
}
```

세 접두사는 **실측값**이다 — `_rg_decide` 가 `[decide` / `[decide auto`, `_rg_unapplied_fix` 가 `[미적용 fix]`, `_rg_blocking_ask` 가 `[ask 비차단]` 을 낸다(마지막 것은 이름과 리터럴이 어긋나 보이지만 그것이 그 함수의 문자열이다). `n_items > 0` 양의 짝이 **없으면 `0 == 0` 이 조용히 통과한다** — 그래서 먼저 세운다.

- [ ] **Step 2: 실패 확인 → 머리 줄을 더한다**

`render_gate()` 의 두 번째 `out.append(...)`(「라운드 %d · 재리뷰 …」) 바로 뒤에:

```python
    # [갈래 2 ⓓ] GATE_ROWS 의 순서는 이미 결정론이지만 «상태 범주» 순이라 그 뜻이
    # 안 보였다. 순위를 새로 매기지 않는다 — 오케스트레이터가 순위를 매기면 그 순위
    # 자체가 판단이고 사용자가 그 위험을 받아들인다고 말한 적이 없다. 있는 순서의
    # 뜻만 낸다. 이 한 줄의 내용은 GATE_ROWS 의 순서에서 읽는다.
    out.append("순서: 열린 결정 먼저 · 그다음 관측 대기 · 막힌 것 · 미적용 수정 · 질문")
```

- [ ] **Step 3: 같은 anchor 묶음 표시**

`render_gate()` 의 렌더 루프에서, `open_decide` 행을 돌 때 **직전 항목과 anchor 가 같으면** 헤더 앞에 이음 표시를 낸다:

```python
    prev_anchor = None
    for row in GATE_ROWS:
        fn = GATE_RENDERERS.get(row.render) if row.render else None
        if fn is None:
            continue
        for fid in g[row.name]:
            # [갈래 2 ⓓ] 묶음은 «표시»다 — 질문 수도 항목별 선택권도 안 바꾼다(D24).
            # 같은 자리를 건드리는 항목이 연달아 오면 그 사실만 한 줄로 보인다.
            anchor = (st["findings"].get(fid) or {}).get("anchor")
            if anchor and anchor == prev_anchor:
                out.append("  ┆ 같은 자리(%s)" % anchor)
            prev_anchor = anchor
            out.extend(fn(st, g, fid))
```

- [ ] **Step 4: 실제 렌더를 눈으로 보고 케이스의 정규식을 확정한다**

```bash
export PYTHONDONTWRITEBYTECODE=1
bash shared/tests/test_docreview_route.sh 2>&1 | grep -A3 'AC18'
```
정규식이 매치 0건이면 고친다. **`grep -c` 가 0 을 내고 기댓값도 0 이면 단언이 공허하다** — `n_items` 가 0 이 아닌 케이스에서 재는지 확인한다.

- [ ] **Step 5: GREEN + 커밋**

```bash
export PYTHONDONTWRITEBYTECODE=1
bash shared/tests/test_docreview_route.sh 2>&1 | tail -3
bash shared/tests/test_docreview_state.sh 2>&1 | tail -3
bash shared/tests/test_docreview_gate_visibility.sh 2>&1 | tail -3
bash shared/tests/test_docreview_round_gate_split.sh 2>&1 | tail -3
```

```
feat(docreview): 게이트 머리에 순서의 뜻을, 같은 자리 항목에 묶음 표시를

문제는 「순위가 없다」가 아니라 「있는 순서의 뜻이 안 보인다」였다 — GATE_ROWS 10행은
이미 결정론이지만 상태 범주 순이다. 순위를 새로 매기지 않는다: 오케스트레이터가
순위를 매기면 그 순위 자체가 판단이고 사용자가 그 위험을 받아들인다고 말한 적이
없다.

묶음은 표시일 뿐이다 — 질문 수도 항목별 선택권도 그대로다. AC18' 이 그것을 게이트
버킷 수로 직접 잰다(렌더와 독립인 채널이라 순환이 아니다).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

---

## Task 10: agent 출력 스키마 — critic 사본 넷 · recritic 사본 둘

**Files:**
- Modify: `shared/docreview/agents/doc-critic.md` (출력 형식)
- Modify: `shared/docreview/agents/doc-critic-web.md`
- Modify: `plugins/spec-distill/agents/doc-critic.md`
- Modify: `plugins/spec-distill/agents/doc-critic-web.md`
- Modify: `shared/docreview/agents/doc-recritic.md` (`added` 예시)
- Modify: `plugins/spec-distill/agents/doc-recritic.md`

**Interfaces:**
- Consumes: Task 5 의 두 칸.
- Produces: 리뷰어가 실제로 그 칸을 낼 근거. **배관이 있어도 내라고 적는 자리는 agent 본문뿐이다.**

**`added` 도 같은 `normalize()` 를 지난다**(`docreview_route.py:315`) — 그래서 칸을 실을 수 **있지만**, 내라고 적혀 있지 않으면 재비판의 `added` 가 대체안 없이 렌더로 간다(AC19″).

- [ ] **Step 1: critic 사본 넷의 항목 키 문장에 칸 둘을 더한다**

네 파일의 `## 출력 형식` 아래 「항목 키:」 문장 끝(`evidence(...)` 뒤)에 이어 붙인다. **네 문장은 바이트로 같다**(실측) — 한 번의 치환으로 넷을 고친다.

```
 · `replacement`(**`decide` 에는 필수** — 「고치면 무엇이 되는가」. **삭제를 제안할 때는 「대체안 없음 — 그냥 뺀다」를 명시적으로 쓴다.** 칸을 비우는 것은 삭제 제안이 **아니다**) · `if_unfixed`(「그대로 두면 무엇이 남는가」 — 문제의 재진술이 아니라 **결과**).
```

그리고 층 1 예시 블록에 두 줄을 더한다:

```yaml
  evidence: "..."
  replacement: "..."
  if_unfixed: "..."
```

- [ ] **Step 2: recritic 사본 둘의 `added` 예시에 두 줄을 더한다**

```yaml
added:
  - category: data_flow
    anchor: "#5-architecture"
    layer: 1
    disposition: ask
    summary: "..."
    replacement: "..."
    if_unfixed: "..."
```

그리고 `놓친 결함이 있으면 `added` 에 새 finding 을 낸다(형식은 `f` 없이 critic 항목과 같다).` 문장 뒤에 한 문장:

```
critic 항목과 **같은 칸을 싣는다** — `replacement`·`if_unfixed` 도 그렇다. 같은 정규화를 지나므로 안 적으면 그 자리가 빈 채로 렌더까지 간다.
```

- [ ] **Step 3: `added` 의 왕복을 실제로 잰다 (AC19″ — 설계가 plan 에 맡긴 절차)**

agent 본문에 적는 것만으로는 「그 칸이 `added` 경로로 실제로 살아 나오는가」가 안 잡힌다. `recritic-r1.txt.tmpl` **옆에** 새 픽스처 `recritic-added-fields.txt.tmpl` 을 만들어 `added` 항목 하나에 두 칸을 싣고, 케이스로 왕복을 잰다.

```bash
# ── added finding 의 두 칸 왕복 (AC19″) ────────────────────────────────────
# added 는 critic 항목과 «같은» normalize() 를 지난다(docreview_route.py:315) — 그래서
# 칸을 실을 수 «있다». 그것을 내라고 적는 자리는 agent 본문뿐이고, 본문에 적는 것만
# 으로는 배관이 실제로 사는지가 안 잡힌다. 이 케이스가 그 왕복을 잰다.
case_recritic_added_carries_fields() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-failed.yaml" "$FX/recritic-added-fields.txt.tmpl")" \
    || { no "added 왕복: route_r1 실패"; return; }
  local n_added; n_added="$(jget "$d/fin.json" 'len([x for x in d["findings"] if "재비판이 찾은" in (x["summary"] or "")])')"
  [ "${n_added:-0}" -ge 1 ] \
    && ok "AC19″ 양의 짝: added 항목이 ${n_added}개 살아남았다 (아래 판정이 공허하지 않다)" \
    || { no "AC19″: added 항목이 0개다 — 재비판 픽스처가 안 먹었다"; rm -rf "$d"; return; }
  assert_eq "$(fsum "$d" '재비판이 찾은' '["replacement"]')" \
    "그 절을 빼고 §5.1 한 줄로 대신한다" "AC19″: added 의 replacement 가 같은 normalize() 를 지나 산다"
  assert_eq "$(fsum "$d" '재비판이 찾은' '["if_unfixed"]')" \
    "plan 이 그 구조를 실재로 믿고 Task 를 짠다" "AC19″: added 의 if_unfixed 도 산다"
  rm -rf "$d"
}
```

픽스처 `shared/tests/fixtures/docreview/recritic-added-fields.txt.tmpl` 의 전문:

````
```docreview-recritic
verdicts: []
added:
  - category: data_flow
    anchor: "#5-architecture"
    layer: 1
    disposition: decide
    summary: "재비판이 찾은 소비자 없는 산출물 — §5 의 층 하나"
    evidence: "§5 의 그 층은 호출자가 하나다"
    replacement: "그 절을 빼고 §5.1 한 줄로 대신한다"
    if_unfixed: "plan 이 그 구조를 실재로 믿고 Task 를 짠다"
```
````

`verdicts` 는 빈 목록이다 — `critic-fields.txt` 의 두 항목은 이미 처분을 갖고 있어 확인이 필요 없고, 이 케이스가 재는 것은 `added` 경로 하나다. **`{{F:…}}` 치환자를 쓰지 않는다**(그 치환자는 `verdicts` 의 `f` 를 실제 fN 으로 바꾸는 장치이고 여기엔 `verdicts` 가 없다). 케이스를 `test_docreview_route.sh` 에 등록한다.

Run: 먼저 **두 칸을 뺀 픽스처**로 돌려 RED 를 본다 — `None` 이 나와야 이 케이스가 무언가를 재고 있다는 증거다.

- [ ] **Step 4: 사본 계약 락 넷 + agent 락**

```bash
export PYTHONDONTWRITEBYTECODE=1
bash shared/tests/test_copy_of_contract.sh 2>&1 | tail -2
bash shared/tests/test_variant_of_contract.sh 2>&1 | tail -2
bash shared/tests/test_docreview_agents.sh 2>&1 | tail -2
bash shared/tests/test_docreview_layer1_wiring.sh 2>&1 | tail -2
bash plugins/spec-distill/tests/test_brief_agents.sh 2>&1 | tail -2
```
Expected: 다섯 다 `Fail: 0`. **하나라도 RED 면 사본 하나를 빠뜨린 것이다** — 어느 파일인지 그 락이 말해 준다.

- [ ] **Step 5: 커밋**

```
docs(agents): doc-critic·doc-recritic 출력 스키마에 replacement·if_unfixed

배관은 섰지만 내라고 적는 자리는 agent 본문뿐이다. added finding 도 같은
normalize() 를 지나므로(docreview_route.py:315) 칸을 실을 수 있는데, 재비판
본문에 안 적으면 그 경로가 대체안 없이 렌더로 간다.

삭제 제안은 「대체안 없음 — 그냥 뺀다」를 «명시적으로» 쓴다. 칸을 비우는 것은
삭제 제안이 아니다 — 렌더가 그 둘을 다른 글자로 가른다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

---

## Task 11: codex 러너 프롬프트에 칸 둘 (AC20)

**Files:**
- Modify: `shared/docreview/scripts/run_docreview_codex_reviewer.sh` (`:439-440`)

**Interfaces:**
- Consumes: 없음(프롬프트 산문).
- Produces: codex 쪽 finding 도 같은 두 칸을 낸다. 그 항목은 `normalize(it, 2, "x", i, L)` 로 **같은 정규화**를 지난다.

**프로필 본문은 이미 통째로 실린다** — `<review_profile>` 태그 안에 `body` 가 들어간다(`:432-433` 실측). 그래서 PR 2 가 프로필에 축 절을 쓰면 codex 도 자동으로 읽는다. **여기서 고칠 것은 출력 형식 예시 한 곳뿐이다.**

- [ ] **Step 1: 출력 JSON 예시를 고친다**

현행(`:439-440`):

```python
print('\nEmit ONE fenced JSON block. `disposition` is required unless you cannot judge it.')
print('```json\n{"findings":[{"ref":"x1","layer":1,"category":"...","anchor":"#slug",'
      '"disposition":"...","summary":"...","edit_scope":"#slug","blocks":[],"evidence":"..."}]}\n```')
```

바꾼 뒤:

```python
print('\nEmit ONE fenced JSON block. `disposition` is required unless you cannot judge it.')
print('`replacement` is required for `decide` — what the document becomes if fixed. '
      'To propose deletion, write the literal `대체안 없음 — 그냥 뺀다`; leaving the field '
      'empty is NOT a deletion proposal. `if_unfixed` states what remains if nothing changes '
      '(the consequence, not a restatement of the problem).')
print('```json\n{"findings":[{"ref":"x1","layer":1,"category":"...","anchor":"#slug",'
      '"disposition":"...","summary":"...","edit_scope":"#slug","blocks":[],"evidence":"...",'
      '"replacement":"...","if_unfixed":"..."}]}\n```')
```

- [ ] **Step 2: 러너를 읽는 락 전부를 돌린다**

```bash
export PYTHONDONTWRITEBYTECODE=1
for t in shared/tests/test_docreview_codex.sh shared/tests/test_docreview_procedure_paths.sh \
         shared/tests/test_codex_runner_scratch_trap_order.sh shared/tests/test_runner_disposition.sh \
         plugins/quality-gates/tests/test_codex_runner_degrade_contract.sh \
         plugins/quality-gates/tests/test_codex_invocation_contract.sh \
         plugins/quality-gates/tests/test_codex_copies_agree.sh \
         plugins/quality-gates/tests/test_codex_gate_observation.sh \
         plugins/spec-distill/tests/test_brief_codex_axes.sh \
         plugins/spec-distill/tests/test_seed_codex_axes.sh; do
  printf '%-64s %s\n' "$t" "$(bash "$t" 2>&1 | grep -E '^Total: ' | tail -1)"
done
```
Expected: 전부 `Fail: 0`. **러너를 읽는 스위트가 설계문서 §10 목록보다 많다** — Task 1 의 baseline 표에서 이 줄들의 Pass 수를 찾아 대조한다.

- [ ] **Step 3: 실제 프롬프트를 눈으로 본다**

`test_docreview_codex.sh` 가 프롬프트를 `$CAP` 에 캡처한다. 그 파일에서 출력 형식 줄을 직접 읽어 두 칸이 실제로 실렸는지 확인한다 — 문자열 조립이 조용히 깨지는 자리다.

- [ ] **Step 4: 커밋**

```
feat(docreview): codex 러너 프롬프트가 replacement·if_unfixed 를 요구한다

codex finding 은 normalize(it, 2, "x", i, L) 로 Claude 쪽과 같은 정규화를 지나므로
같은 두 칸을 낼 수 있다 — 러너 프롬프트에 그 두 칸을 적어야 실제로 난다.

프로필 본문은 이미 <review_profile> 태그로 통째 실리므로 축 규약은 프로필만 고치면
codex 에 닿는다. 여기서 고치는 것은 출력 형식 예시 한 곳이다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

---

## Task 12: `/qg` 의 회계어 풀이 줄 — `disposition_lines()` 를 4-튜플로

**Files:**
- Modify: `shared/adjudication/render_disposition.py` (`disposition_lines()` + 모듈 docstring)
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py` (`:482`·`:532`)
- Modify: `plugins/quality-gates/scripts/synthesize_artifact_findings.py` (`:313`)
- Modify: `plugins/quality-gates/tests/test_synthesize_disposition.sh`
- Modify: `plugins/quality-gates/tests/test_synthesize_artifact_findings.sh` (`:375` 머리말)

**Interfaces:**
- Produces: `disposition_lines(report, held_classes) -> (처분줄, 배관줄, 풀이줄, advisory목록)` — **4-튜플**.
- Consumes: 없음. 이 Task 는 docreview 엔진과 독립이다 — 먼저 해도 나중에 해도 된다.

**왜 4-튜플인가**(AC21). 풀이 줄은 **처분 줄과 배관 줄 둘 다의** 낱말을 푼다. 어느 한쪽 문자열 안에 개행으로 욱여넣으면 그 줄이 다른 줄의 낱말을 설명하는 꼴이 된다. **기존 위치 언패킹은 `ValueError` 로 소리 내며 깨진다** — 조용히 넘어가지 않는 것이 이 선택의 핵심이다.

**소비자는 정확히 셋이다** — 이 계획을 쓰며 전수 확인했다(`disposition_lines` 리포 전수 grep): `synthesize_findings.py:482`·`:532` · `synthesize_artifact_findings.py:313`. CHANGELOG 가 말하는 네 번째·다섯 번째 소비자(spec-distill 의 `merge_review.py`·`merge_brief_review.py`, 설계문서 리뷰 훅)는 **이미 삭제됐다.** AC22 의 「전수 확인」이 이것이다.

`plugins/spec-distill/scripts/render_disposition.py` 는 mode 120000 심볼릭 링크로 남아 있으나 spec-distill 안에서 그것을 import 하는 코드가 **0** 이다(OQ-H) — 이 변경이 그 링크를 통해 새지 않는다.

**「읽히기」 기준 셋 중 둘은 이미 만족돼 있다**(설계 §5.9) — `(차단: 예/아니오)` 리터럴과 `미판정`·`셀 수 없음` 두 칸. 그래서 `/qg` 에 필요한 실제 변경은 **한 줄**이다.

- [ ] **Step 1: 풀이 줄 단언을 먼저 쓴다**

`plugins/quality-gates/tests/test_synthesize_disposition.sh` 의 기존 여섯 `assert_grep` 뒤에:

```bash
# ── 회계어 풀이 줄 (AC21) ──────────────────────────────────────────────────
# 회계 낱말은 «그대로 둔다»(D21) — 낱말을 바꾸는 것이 아니라 사람말을 옆에 붙인다.
# 그래서 위 여섯 단언(수용·기각·억제·흡수·미판정·배관 손실)이 전부 GREEN 인 채로
# 이 줄이 더해진다. 그 여섯이 이 단언의 양의 짝이다.
assert_grep "$OUT" '억제=규칙이 자른 것'            "AC21: 풀이 줄이 「억제」를 푼다"
assert_grep "$OUT" '흡수=같은 것끼리 합친 것'        "AC21: 풀이 줄이 「흡수」를 푼다"
assert_grep "$OUT" '미판정=볼 사람이 없던 것'        "AC21: 풀이 줄이 「미판정」을 푼다"
assert_grep "$OUT" '배관 손실=입력이 죽었거나 항목이 깨졌거나 값을 보정한 것' \
  "AC21: 풀이 줄이 「배관 손실」을 실제 집계대로 푼다(입력 실패 + 항목 파손 + 기타 + coerced)"
assert_grep "$OUT_CLEAN" '억제=규칙이 자른 것' \
  "AC21: clean(kept=0) 분기에서도 풀이 줄이 난다 (:482 자리 — 이 락이 한 번 통째로 놓쳤던 분기)"
```

`plugins/quality-gates/tests/test_synthesize_artifact_findings.sh:375` 의 머리말 서술을 **「처분 두 줄」 → 「처분 세 줄」** 로 고치고, 그 절의 단언에 풀이 줄 하나를 더한다.

- [ ] **Step 2: 실패 확인**

Run: `PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_synthesize_disposition.sh 2>&1 | tail -5`
Expected: **FAIL** — 다섯 단언이 RED.

- [ ] **Step 3: `disposition_lines()` 를 4-튜플로**

모듈 docstring 첫 줄 `"""처분 두 줄 — 네 소비자가 공유하는 렌더.` 를 **「처분 세 줄 — 세 소비자가 공유하는 렌더.」** 로 고친다(소비자 수도 실측값이다 — 둘은 이미 삭제됐다).

```python
def disposition_lines(report, held_classes):
    """`Ledger.report()` 와 `held_by_class()` 로 세 줄을 만든다.

    반환은 `(처분줄, 배관줄, 풀이줄, advisory목록)` **4-튜플**. 풀이 줄은 앞 두 줄
    «둘 다»의 낱말을 푸므로 어느 한쪽 문자열 안에 개행으로 넣지 않는다 — 그러면 그
    줄이 다른 줄의 낱말을 설명하는 꼴이 된다. 기존 3-튜플 언패킹은 `ValueError` 로
    소리 내며 깨진다(조용히 넘어가지 않는 것이 이 선택의 핵심이다).

    회계 낱말은 **그대로 둔다** — 바꾸는 것이 아니라 사람말을 옆에 붙인다.
    advisory 는 미지 접두가 있을 때만 비어 있지 않다.
    """
    c = report["counts"]
    unknown = report["unknown_counts"]

    line1 = ("**처분:** 수용 %d · 기각 %d · 억제 %d · 흡수 %d · 미판정 %d"
             "     (차단 아님)"
             % (c["accepted"], c["rejected"], c["suppressed"], c["absorbed"],
                held_classes["판정자 부재"]))

    plumbing = (c["sources_failed"] + held_classes["항목 파손"]
                + held_classes["기타"] + c["coerced"])
    line2 = ("**배관 손실:** %d · 셀 수 없음 %d     (차단: %s)"
             % (plumbing, len(unknown), "예" if report["degraded"] else "아니오"))

    # 「배관 손실」의 풀이는 **바로 위 `plumbing` 의 실제 합**을 따라 적는다 —
    # sources_failed(입력이 죽었다) + 항목 파손 + 기타 + coerced(값을 보정했다).
    # 「판정에 못 들어간 것」으로 적으면 그 칸이 세는 것과 다른 말이 된다.
    line3 = ("↳ 억제=규칙이 자른 것 · 흡수=같은 것끼리 합친 것 · 미판정=볼 사람이 없던 것"
             " · 배관 손실=입력이 죽었거나 항목이 깨졌거나 값을 보정한 것")

    advisories = []
    if sum(held_classes.values()) != c["held"]:
        advisories.append(
            "[adjudication] hold 분류 합 %d ≠ held 총계 %d — 렌더가 항목을 잃는다."
            % (sum(held_classes.values()), c["held"]))
    if held_classes["기타"] > 0:
        advisories.append(
            "[adjudication] hold 사유 %d건이 알려진 접두(「판정자 부재: 」·"
            "「항목 파손: 」)에 안 걸린다 — 배관 칸에 실었으나 분류되지 않았다."
            % held_classes["기타"])
    return line1, line2, line3, advisories
```

- [ ] **Step 4: 소비자 셋을 고친다**

`synthesize_findings.py:482` 갈래:

```python
        disp_line, plumb_line, gloss_line, advisories = disposition_lines(report, held_classes)
        for a in advisories:
            print(a, file=sys.stderr)
        out = [
            "## Review Findings (Synthesized)",
            "",
            f"No high-confidence findings. {suppressed_count} low-confidence "
            "findings suppressed.",
            disp_line, plumb_line, gloss_line,
        ]
```

`synthesize_findings.py:532` 갈래:

```python
    disp_line, plumb_line, gloss_line, advisories = disposition_lines(report, held_classes)
    for a in advisories:
        print(a, file=sys.stderr)

    out = ["## Review Findings (Synthesized)", "", counts_line,
           disp_line, plumb_line, gloss_line, ""]
```

`synthesize_artifact_findings.py:313`:

```python
        disp_line, plumb_line, gloss_line, advisories = disposition_lines(
            L.report(), L.held_by_class())
        for line in (disp_line, plumb_line, gloss_line, *advisories):
            sys.stderr.write(line + "\n")
```

- [ ] **Step 5: 제3의 호출부가 없음을 전수 확인한다 (AC22)**

Run: `grep -rn "disposition_lines(" . --exclude-dir=.git --exclude-dir=docs`
Expected: 정의 하나(`shared/adjudication/render_disposition.py`) + 호출 셋 + 테스트·CHANGELOG 의 언급. **호출이 셋을 넘으면** 그 자리도 같은 커밋에서 고친다 — 3-튜플 언패킹이 남아 있으면 `ValueError` 로 죽는다.

- [ ] **Step 6: GREEN**

```bash
export PYTHONDONTWRITEBYTECODE=1
bash plugins/quality-gates/tests/test_synthesize_disposition.sh 2>&1 | tail -3
bash plugins/quality-gates/tests/test_synthesize_artifact_findings.sh 2>&1 | tail -3
bash shared/tests/test_adjudication_consumed.sh 2>&1 | tail -3
bash shared/tests/test_adjudication_wiring.sh 2>&1 | tail -3
```
Expected: 넷 다 `Fail: 0`.

- [ ] **Step 7: 변이 — 풀이 줄에서 「억제」 항목을 뺀다**

Expected: `test_synthesize_disposition.sh` RED. GREEN 이면 그 단언이 공허하다.

- [ ] **Step 8: 커밋**

```
feat(adjudication): 처분 출력에 회계어 풀이 줄 — 반환이 4-튜플이 된다

회계 낱말은 그대로 둔다(D21) — 바꾸는 것이 아니라 사람말을 옆에 붙인다. 위 여섯
단언(수용·기각·억제·흡수·미판정·배관 손실)이 전부 GREEN 인 채로 줄이 하나 는다.

풀이 줄은 앞 두 줄 둘 다의 낱말을 풀므로 별도 반환값이다. 어느 한쪽 문자열 안에
개행으로 넣으면 그 줄이 다른 줄의 낱말을 설명하는 꼴이 된다. 기존 3-튜플 위치
언패킹은 ValueError 로 소리 내며 깨진다 — 조용히 넘어가지 않는 것이 이 선택의
핵심이다.

「배관 손실」의 풀이는 그 칸의 실제 합(sources_failed + 항목 파손 + 기타 +
coerced)을 따라 적는다 — 「판정에 못 들어간 것」은 그 칸이 세는 것과 다른 말이다.

소비자는 셋이다(전수 grep). CHANGELOG 가 말하는 네·다섯 번째(merge_review.py ·
merge_brief_review.py)는 이미 삭제됐다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

---

## Task 13: `AskUserQuestion` 라벨 조립 규약 (AC17″)

**Files:**
- Modify: `shared/docreview/references/reviewing-document.md` (8단계)
- Modify: `shared/tests/test_docreview_round_gate_split.sh` (축 추가)

**Interfaces:**
- Consumes: Task 8 의 렌더 여섯 줄, Task 7 의 상태별 라벨.
- Produces: 오케스트레이터가 따르는 산문 규약. **이것은 코드가 아니라 규약이므로 락도 산문 락이다.**

**왜 산문인가 — 그리고 그 한계를 공시한다.** 라벨 압축은 오케스트레이터가 런타임에 한다(설계 §6 의 흐름도: `label ← replacement 를 1–5 낱말로 압축`). 엔진이 그 라벨을 짓지 않으므로 **기계로 잴 수 있는 것은 「규약이 적혀 있는가」뿐**이다. `test_docreview_round_gate_split.sh` 가 이미 같은 종류의 산문 락이고 같은 파일을 guards 에 담는다 — 그래서 축을 거기 더한다.

**한계:** 이 락은 규약의 **실재**를 재고 오케스트레이터의 **준수**는 못 잰다. Task 15 의 e2e 가 실제 라벨을 눈으로 보는 자리다.

- [ ] **Step 1: 축을 먼저 더한다**

`shared/tests/test_docreview_round_gate_split.sh` 의 기존 네 축 뒤에 다섯째:

```bash
note "── 축 5 — AskUserQuestion 라벨의 항목별 내용 (AC17″)"
# body-unique 로 잰다(헤더 줄 제외) — 헤더나 목차가 문구를 만족시키면 본문을 지워도
# GREEN 이 되는 함정이 이 리포에 기록돼 있다(feedback_grep_lock_header_satisfiable).
for f in "$PROC" "$SKILL"; do
  body="$(grep -v '^#' "$f")"
  case "$body" in
    *'replacement 를 1–5 낱말로 압축'*) ok "축 5: $(basename "$f") 에 라벨 압축 규약이 있다" ;;
    *) no "축 5: $(basename "$f") 에 라벨 압축 규약이 없다 — 라벨이 상태 라벨만 담으면 「라벨만 읽고 고른다」가 원리적으로 안 닫힌다" ;;
  esac
  case "$body" in
    *'같은 라벨을 갖지 않는다'*) ok "축 5: $(basename "$f") 에 라벨 중복 금지가 있다" ;;
    *) no "축 5: $(basename "$f") 에 라벨 중복 금지가 없다" ;;
  esac
  case "$body" in
    *'부재 건수를 함께 공시'*) ok "축 5: $(basename "$f") 에 부재 공시 규약이 있다 (중복 금지가 공허해지는 유일한 경우를 막는다)" ;;
    *) no "축 5: $(basename "$f") 에 부재 공시 규약이 없다" ;;
  esac
done
```

`$PROC`·`$SKILL` 은 그 파일이 이미 정의해 둔 두 경로다 — 이름을 실제 변수명에 맞춘다.

- [ ] **Step 2: 실패 확인 → 규약을 쓴다**

`shared/docreview/references/reviewing-document.md` 의 8단계 끝(「…`proceed-gate.md`.」 문장 뒤)에 한 문단:

```markdown
**`AskUserQuestion` 라벨의 항목별 내용** — 각 선택지 `label` 은 **상태별 라벨 + `— <replacement 를 1–5 낱말로 압축>`** 이다. 상태별 라벨만 담으면 같은 라운드의 여러 항목이 전부 같은 글자가 되어 「라벨만 읽고 고른다」가 원리적으로 안 닫힌다. 같은 라운드의 두 항목이 **같은 `label` 을 갖지 않는다.** 단 `replacement` 가 둘 다 부재면 그 부재 표기(`(대체안 미작성)`)가 같을 수 있고, 그때는 이 규약이 공허해지지 않도록 **부재 건수를 함께 공시한다**(「대체안 미작성 N건」). `label` 예산은 1–5 낱말이므로 압축은 필수다 — 렌더의 「고치면」 줄이 전문을 이미 내므로 라벨은 그 줄을 가리키는 손잡이다.
```

같은 문단을 `plugins/spec-distill/skills/reviewing-spec/SKILL.md` 의 `## 게이트` 절에도 넣는다 — 그 파일이 8단계 규약의 첫 사이트이고 기존 네 축이 이미 두 파일을 함께 잰다.

- [ ] **Step 3: GREEN + 사본 락**

```bash
export PYTHONDONTWRITEBYTECODE=1
bash shared/tests/test_docreview_round_gate_split.sh 2>&1 | tail -3
bash shared/tests/test_docreview_procedure_paths.sh 2>&1 | tail -3
bash shared/tests/test_copy_of_contract.sh 2>&1 | tail -3
bash plugins/spec-distill/tests/test_rereview_cap_consistency.sh 2>&1 | tail -3
bash plugins/spec-distill/tests/test_reviewing_brief_skill.sh 2>&1 | tail -3
```

- [ ] **Step 4: 커밋**

```
docs(docreview): AskUserQuestion 라벨의 항목별 내용을 규약으로 못 박는다

상태별 라벨만 담으면 같은 라운드의 여러 항목이 전부 같은 글자가 되어 「라벨만 읽고
고른다」가 원리적으로 안 닫힌다. 라벨은 상태별 라벨 + replacement 압축이고, 같은
라운드의 두 항목은 같은 라벨을 갖지 않는다.

둘 다 부재면 부재 표기가 같을 수 있다 — 그때는 부재 건수를 공시해 이 규약이
공허해지지 않게 한다.

한계 공시 — 이 락은 규약의 실재를 재고 오케스트레이터의 준수는 못 잰다. 라벨을
짓는 것은 엔진이 아니라 런타임의 오케스트레이터다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

---

## Task 14: PR 3 마무리 — EXEMPT 재앵커 · 골든 · bump · 전량 · PR

**Files:**
- Modify: `tools/adjudication/check_wiring.py` (`EXEMPT` 의 `docreview_route.py` 키 아홉)
- Modify: `shared/tests/fixtures/docreview/golden/*` (6개, 재캡처)
- Modify: 두 플러그인의 `.claude-plugin/plugin.json` · `CHANGELOG.md`

**Interfaces:**
- Consumes: Task 5~13 의 모든 변경.

**줄번호 앵커의 연쇄** — `check_wiring.py` 의 `EXEMPT` 가 **(경로, 줄번호, 분기 설명)** 3-튜플을 키로 쓴다. PR 3 이 고친 `normalize()`(`:52-78`)와 `_decision_view()`(`:213-238`)가 그 키들(`:97`·`:372`·`:391`·`:396`·`:462`·`:467`·`:478`·`:503`·`:514`·`:566`)보다 **위**라 **아홉 전부가 밀린다.** 같은 파일 `:164-168` 이 「줄번호는 매 재앵커마다 실측으로 갱신한다」와 「I1 정정이 이 파일 앞부분 줄 수를 늘렸다」로 **같은 일이 이미 한 번 일어났음**을 기록해 두었다 — 예측이 아니라 **재발**이다.

**재앵커를 빠뜨리면 무관해 보이는 락이 RED 로 나고, 그 RED 를 「원래 그렇던 것」으로 오해하면 회귀가 그 뒤에 숨는다.**

- [ ] **Step 1: 스캔으로 낡은 키를 읽는다**

```bash
export PYTHONDONTWRITEBYTECODE=1
bash shared/tests/test_adjudication_wiring.sh 2>&1 | grep -E 'STALE_EXEMPT|낡은 면제|exempt_stale'
```
Expected: `exempt_stale` 이 0 이 아니고 낡은 키가 열거된다.

- [ ] **Step 2: 새 줄번호를 실측한다**

```bash
grep -n 'continue$\|continue \|return ' shared/docreview/scripts/docreview_route.py | grep -nE '_permit_covers|_absorb_same_as|_classify_items|_auto_decides|_resolve_ids_and_lineage'
```
더 확실한 방법: 스캔 러너를 직접 돌려 현재 트리의 discard 자리 목록을 받는다.

```bash
PYTHONDONTWRITEBYTECODE=1 python3 shared/tests/fixtures/adjudication/run_wiring_scan.py 2>&1 | head -40
```

- [ ] **Step 3: `EXEMPT` 의 아홉 키를 갱신한다**

**줄번호만 고친다** — 분기 설명 문자열(`"continue in _auto_decides @ if …"`)과 사유(`_DR_*` 상수)는 **한 글자도 안 바꾼다.** 그것을 바꾸면 이 락이 재는 「같은 정체의 버리는 분기를 가리키는가」가 무너진다.

`:164-168` 의 주석에 **이번 재앵커의 사유 한 줄**을 더한다. **과거 델타를 숫자로 다시 적지 않는다** — 그 델타 자체가 다음 삽입에서 또 stale 해지는 함정이다(그 주석이 이미 그렇게 경고한다). 적을 것은 「무엇이 위에서 늘었는가」다:

```python
    # [designer-lens-review PR 3] `normalize()` 가 칸 둘을, `_decision_view()` 가
    # 두 칸 · category 사람말 · category_unglossed 를 더하면서 이 파일 앞부분 줄 수가
    # 늘었다. 아래 아홉 자리를 실측으로 다시 앵커했다 — 가드 텍스트와 사유는 무변경.
```

- [ ] **Step 4: `EXEMPT` 크기와 컴프리헨션 baseline 을 확인한다**

```bash
export PYTHONDONTWRITEBYTECODE=1
bash shared/tests/test_adjudication_wiring.sh 2>&1 | grep -E '면제 목록|컴프리헨션'
```
Expected: 둘 다 `✓`. `EXEMPT_BASELINE = 11` 과 `COMP_BASELINE=40` 은 **안 바뀌어야 한다** — 이 PR 은 면제를 늘리지 않고, 새로 더한 컴프리헨션도 기존 자리를 대체할 뿐이다(`[choice_label(c, kind) for c in choices]` 는 `[_CHOICE_LABEL[c] for c in choices]` 를 대신한다). **어느 쪽이든 늘었으면 그 수를 올리고 이유를 적는다** — 조용히 올리지 않는다.

- [ ] **Step 5: 골든을 다시 뜬다**

```bash
export PYTHONDONTWRITEBYTECODE=1
bash shared/tests/fixtures/docreview/capture_finalize_golden.sh
git status --short shared/tests/fixtures/docreview/golden/
```
Expected: 여섯 파일이 전부 수정된다(`fin.json` 셋 + `state.md` 셋). **`git diff` 를 눈으로 읽는다** — `change` 가 사라지고 `if_unfixed`/`replacement` 가 생겼는지, `alternatives` 가 상태별 라벨인지, `impact` 에 사람말이 들어갔는지. **이 diff 가 PR 3 의 가장 좋은 요약이다.**

```bash
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_golden.sh 2>&1 | tail -3
```
Expected: `Fail: 0` (baseline 11).

- [ ] **Step 6: bump + CHANGELOG**

`spec-distill` → **minor**(`3.3.0`), `quality-gates` → **minor**(`7.7.0`).

**minor 인 이유** — 새 surface 가 둘이다: 리뷰어 출력 스키마의 칸 둘(`replacement`·`if_unfixed`)과 `disposition_lines()` 의 4-튜플 반환. 후자는 **호출 계약이 바뀐다** — 다만 breaking 이 아니라 additive 로 볼 수 있는가? **아니다, 위치 언패킹이 깨진다.** 그러나 소비자가 **같은 리포 안의 셋뿐**이고 같은 PR 에서 다 고치므로 외부 계약은 안 깨진다. 외부 플러그인이 이 함수를 부를 수 있는 표면이 아니다(`shared/adjudication/` 은 배포 심볼릭 링크로만 간다) — **minor 로 두되 CHANGELOG 에 「기존 3-튜플 언패킹은 ValueError 로 깨진다」를 명시한다.**

**머지 직전에 `origin/main` 의 값을 다시 읽어 확정한다.**

CHANGELOG 항목에 담을 것(두 플러그인 각각, 그 플러그인에 해당하는 것만):

- 동어반복 두 줄의 실측 근거(`change` = `it["summary"]`, `_CHOICE_LABEL` 고정 셋)
- 닫힌 열거 셋과 `PUBLIC_FIELDS` 를 왜 top-level 로 고쳤는가
- `kind=post` 에서 `reject` 가 revert permit 을 만든다는 사실과 그래서 라벨이 상태의 함수가 된 것
- 「대안」 줄을 항상 내는 이유(`cases.sh` 「제안 = 수용」 락의 발동 조건)
- 4-튜플 반환과 `ValueError` 로 깨진다는 사실
- 사상 코퍼스가 네 프로필 + 엔진 category 인 이유
- **`overdesign` 사상이 프로필보다 먼저 들어와 있다는 사실과 그 이유**(AC13)
- **한계 공시** — AC17″ 의 락은 규약의 실재를 재고 오케스트레이터의 준수는 못 잰다

- [ ] **Step 7: 전량**

```bash
bash .claude/plan-tmp/capture_baseline.sh > .claude/plan-tmp/after-pr3.txt 2>&1
```
그다음 baseline 과 **줄 단위로 대조한다.** Pass 수가 줄어든 줄이 하나도 없어야 한다(AC23). 새 케이스가 늘어 여러 줄의 Pass 가 **커진다** — 그것은 정상이다.

`diff` 로 대조할 때 **파일 이름이 같은 줄끼리** 비교한다. 줄 순서가 바뀌면 `diff` 가 무관한 줄을 짝지어 오해를 만든다.

- [ ] **Step 8: 커밋 + PR**

```
chore(plugins): spec-distill 3.3.0 · quality-gates 7.7.0 — 갈래 2

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

PR 본문:

```markdown
**선행** — PR 1 (#N). `1 → 3 → 2` 머지 순서의 둘째다(설계 AC25).

## 결함

게이트의 `decide` 항목은 헤더 + 네 줄인데 그중 **둘이 정보를 안 나른다** — 「변경」은 `it["summary"]`(**헤더와 같은 문자열**), 「대안」은 고정 라벨 셋(대개 전 항목 동일). 「영향」은 영향이 아니라 위치이고, `category` 는 렌더에 **한 번도 안 나온다.**

칸을 더하는 것만으로는 안 고쳐진다 — `normalize()` 가 고정 10키 dict 를 새로 짓고 모르는 키를 조용히 버리며, 칸이 비어도 `change` 가 `summary` 로 채워져 **비어 보이지 않는다.**

## 고친 것

- **칸 둘** `replacement`·`if_unfixed` — `normalize()` → `PUBLIC_FIELDS`(top-level) → 렌더. 닫힌 열거가 **셋**이라 둘만 고치면 원장에 안 남는다.
- **동어반복 제거** — 「변경」이 사라지고 「그대로 두면 / 고치면」 둘로 갈린다. 부재는 `summary` 로 안 메우고 리터럴로 말한다. **침묵과 삭제 제안을 다른 글자로 가른다.**
- **라벨이 `kind` 의 함수** — `cmd_decide` 가 `post` 의 `reject` 에 revert permit 을 만들므로 고정 라벨은 동작을 **반대로** 설명한다(codex 단독 적발).
- **「자리」 줄에 `category` 사람말** — 사상 코퍼스는 네 프로필 + 엔진 category. 사상에 없으면 원래 이름 + 공시 한 줄.
- **`/qg` 풀이 줄** — `disposition_lines()` 가 4-튜플을 낸다. 회계 낱말은 그대로 두고 사람말을 옆에 붙인다.

## 줄 수

여섯 줄 중 정보 0 인 줄은 **없다.** 줄이 하나 늘지만 늘어난 줄은 기존 락의 **발동 조건**이고 사라진 것은 동어반복 한 줄이다.

## AC

AC14 ✓ · AC15 ✓ · AC16 ✓ · AC17 ✓ · AC17′ ✓ · AC17″ ✓(규약 락) · AC18 ✓ · AC18′ ✓ · AC19 ✓ · AC19′ ✓ · AC19″ ✓ · AC20 ✓ · AC21 ✓ · AC21′ ✓ · AC22 ✓(전수 grep — 소비자 셋) · AC23 ✓ · AC24 ✓ · AC25 ✓

## 공시

- **AC17″ 의 락은 규약의 실재를 재고 오케스트레이터의 준수는 못 잰다.** 라벨을 짓는 것은 엔진이 아니라 런타임이다.
- `CATEGORY_GLOSS` 에 `overdesign` 이 **프로필보다 먼저** 들어 있다. PR 2 가 `docreview_state.py` 를 0줄 건드려야 축이 단독 머지 가능하기 때문이다(AC13). 락은 ∀(도출한 이름 전부에 사상이 있는가)라 여분 항목은 무해하다.

## 설계

`docs/superpowers/specs/2026-09-21-designer-lens-review-design.md` §5.7 · §5.8 · §5.9 · §6

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

**사용자에게** 머지를 부탁한다: `! gh pr merge <번호> --merge`.

---

# PR 2 — 갈래 1 (새 축 `overdesign`)

> 브랜치: `feature/docreview-overdesign-axis`, PR 3 이 머지된 `main` 에서 딴다.
> PR 본문에 **「선행 = PR 1 (#N) · PR 3 (#M)」** 을 명시한다(AC25).
> **AC13 — 이 PR 의 `git diff` 에 `docreview_state.py` 가 0줄이다.**

**기존 축은 전부 「맞는가」를 묻는다. 이 축만 「과한가」를 묻는다.** design-doc 프로필의 층 1 여덟 축은 방향이 전부 정렬·정합·준수·폐쇄·존재다(프로필 본문 실측). 절차를 얹어도 「같은 것을 겨누는가」에서 「goal 에 비해 과한가」는 안 나온다 — 다른 질문이기 때문이다. 겹치는 자리는 정확히 둘, 그것도 좁다: `data_flow` 의 「소비자 없는 산출물」과 층 2 `scope_creep`.

**정확한 문구는 이 계획이 쓴다** — 설계문서가 담을 **내용과 출처**를 정했고 리뷰어가 읽을 최종 산문은 plan 의 일이다(「Deferred to plan」 첫 항목).

---

## Task 15: 새 축 `overdesign` 과 술어 불릿

**Files:**
- Create: `plugins/spec-distill/tests/test_overdesign_rubric.sh`
- Modify: `plugins/spec-distill/references/docreview-profiles/brief.md`
- Modify: `plugins/spec-distill/references/docreview-profiles/design-doc.md`

**Interfaces:**
- Consumes: PR 1 의 마커 `**층 1 판정 관계** —`(두 줄에 한 절을 **이어 붙인다**), PR 3 의 `CATEGORY_GLOSS["overdesign"]`.
- Produces: 축 이름 `overdesign`. Task 18 의 T13 ④ 가 `SHARED = {overdesign}` 으로 이것을 열거한다.

**⚠ `layer1:` 은 반드시 한 줄이다.** codex 러너의 프로필 파서는 줄 단위이고(`run_docreview_codex_reviewer.sh:302`) 이어진 줄은 rc 5 `profile_parse_ambiguous` 다. T13 의 `lay_of` 도 `sed … | head -1` 이라 첫 줄만 읽어 **축을 덜 잰다.** 반면 Python 게이트는 PyYAML 이라 **통과한다** — 즉 줄바꿈 하나로 **codex 축만 죽고 락은 조용히 덜 재며 Python 쪽은 GREEN** 이고, 그 죽음이 「축이 무이빨」 오진으로 읽힌다. 현행 네 프로필은 전부 한 줄이다(design-doc 은 151자, 아홉 축이면 약 165자).

- [ ] **Step 1: 브랜치 + 새 락 골격**

```bash
git fetch origin
git checkout -b feature/docreview-overdesign-axis origin/main
```

Create `plugins/spec-distill/tests/test_overdesign_rubric.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/references/docreview-profiles/brief.md plugins/spec-distill/references/docreview-profiles/design-doc.md
#
# 설계자 시선 축(`overdesign`)이 두 문서 자리의 프로필 본문에 실제로 서 있는가.
# 축 «이름»만 layer1 에 넣으면 리뷰어는 그 축이 무엇을 묻는지 어디서도 못 읽는다 —
# 이름은 rubric 목록이, 내용은 본문 절이 진다.
#
# 이 락이 재는 것은 «문구의 실재»다. 리뷰어의 실제 판정이 그 절차를 따랐는지는 못 잰다
# (설계 §7 「상한의 무이빨」과 같은 종류의 한계 — 공시하고 닫지 않는다).
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  git ls-files -- 'plugins/spec-distill/references/docreview-profiles/brief.md' \
                  'plugins/spec-distill/references/docreview-profiles/design-doc.md'
  exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"
B="plugins/spec-distill/references/docreview-profiles/brief.md"
D="plugins/spec-distill/references/docreview-profiles/design-doc.md"

# 본문만 본다 — frontmatter 가 문구를 만족시키면 본문을 지워도 GREEN 이 되는 함정을 막는다.
body_of() { awk 'BEGIN{n=0} /^---$/{n++; next} n>=2' "$1"; }
BB="$(body_of "$B")"; DB="$(body_of "$D")"
[ -n "$BB" ] && [ -n "$DB" ] \
  && ok "양의 짝: 두 프로필 본문을 읽었다 (아래 전부가 공허하지 않다)" \
  || { no "프로필 본문 추출 실패 — 아래 전부가 공허하다"; finish; exit; }

has() {   # has <본문> <문구> <설명>
  case "$1" in *"$2"*) ok "$3" ;; *) no "$3 — 문구 부재: $2" ;; esac
}
hasnt() { # hasnt <본문> <문구> <설명>
  case "$1" in *"$2"*) no "$3 — 있으면 안 되는 문구: $2" ;; *) ok "$3" ;; esac
}

# ── AC5 : layer1 에 축이 있고 한 줄이다 ───────────────────────────────────
for f in "$B" "$D"; do
  n="$(grep -c '^  layer1: .*overdesign' "$f" || true)"
  [ "${n:-0}" -eq 1 ] \
    && ok "AC5: $f 의 layer1 «한 줄»에 overdesign 이 있다" \
    || no "AC5: $f 의 layer1 한 줄에 overdesign 이 없다 (줄바꿈이면 codex 축이 죽고 lay_of 가 덜 잰다)"
done
grep -q '^  layer1: \[direction, overdesign\]$' "$B" \
  && ok "AC5: brief layer1 == [direction, overdesign]" \
  || no "AC5: brief layer1 이 [direction, overdesign] 이 아니다"
for a in goal_fit problem_definition scope architecture component_relations data_flow tradeoffs feasibility; do
  grep -q "^  layer1: .*\b$a\b" "$D" && ok "AC5: design layer1 에 기존 축 $a 가 남아 있다" \
                                     || no "AC5: design layer1 에서 기존 축 $a 가 사라졌다"
done

# ── AC6 : 두 불릿이 서로 다르고 각자 자기 술어를 담는다 ───────────────────
BL="$(printf '%s\n' "$BB" | grep '^- `overdesign`' | head -1)"
DL="$(printf '%s\n' "$DB" | grep '^- `overdesign`' | head -1)"
[ -n "$BL" ] && [ -n "$DL" ] && [ "$BL" != "$DL" ] \
  && ok "AC6: 두 자리의 overdesign 불릿이 실재하고 서로 다르다" \
  || no "AC6: overdesign 불릿이 없거나 두 자리가 같다 (brief='$BL' design='$DL')"
has "$BL" '사용자 원문'   "AC6: brief 불릿이 자기 상류(사용자 원문)를 기준어로 담는다"
has "$DL" '브리프 §1 Goal' "AC6: design 불릿이 자기 상류(브리프 §1 Goal)를 기준어로 담는다"
hasnt "$BL" '왜곡'        "AC6: brief 불릿에 술어 ②(왜곡)가 없다 (그 대상이 구조·구현이라 brief 에 없다)"
has "$DL" '왜곡'          "AC6: design 불릿에 술어 ②(왜곡)가 있다"

finish
```

- [ ] **Step 2: 실패 확인**

Run: `PYTHONDONTWRITEBYTECODE=1 bash plugins/spec-distill/tests/test_overdesign_rubric.sh`
Expected: **FAIL** — 양의 짝만 GREEN 이고 AC5·AC6 이 전부 RED.

- [ ] **Step 3: `brief.md` 를 고친다**

frontmatter — **한 줄로**:

```yaml
  layer1: [direction, overdesign]
```

PR 1 이 쓴 「**층 1 판정 관계** —」 줄 **끝에 이어 붙인다**(새 줄로 만들지 않는다 — 락 B1 이 마커 줄을 정확히 하나로 센다):

```
 `overdesign` 은 그 `ground_truth` 의 **두 원문**(payload `## 6. 사용자 원문` 의 S1 · `<<<AUDIT-VERBATIM>>>` 뒤 블록의 S2 이상)이 말한 goal 을 기준으로 **과함**을 잰다 — 한 층 안에 정답 출처가 둘이다.
```

`` - `direction` `` 불릿 다음에 새 불릿:

```markdown
- `overdesign` — **사용자 원문**의 goal 에 비해 과한가. 술어 둘(① 과함 · ③ 층위 이탈)이고 처분은 둘 다 `decide` 다. 상세는 아래 「층 1 `overdesign` — 설계자 시선」 절.
```

- [ ] **Step 4: `design-doc.md` 를 고친다**

frontmatter — **한 줄로**:

```yaml
  layer1: [goal_fit, problem_definition, scope, architecture, component_relations, data_flow, tradeoffs, feasibility, overdesign]
```

**기존 여덟 축의 이름도 불릿 문구도 한 글자도 안 바꾼다**(AC5).

PR 1 의 마커 줄 끝에 이어 붙인다:

```
 단 `overdesign` 은 정합이 아니라 **과함**을 잰다 — 기준은 `ground_truth` 의 **§1 Goal** 이다.
```

`` - `feasibility` `` 불릿 다음에 새 불릿:

```markdown
- `overdesign` — **브리프 §1 Goal** 에 비해 과한가, 제약을 지키려다 구조가 **왜곡**됐나, 이 문서의 층이 아닌 것이 **들어왔나**. 술어 셋(① 과함 · ② 왜곡 · ③ 층위 이탈)이고 처분은 전부 `decide` 다. 기존 `architecture`(§2 확정 제약 준수)와 다르다 — 그래야 「§2 가 확정한 것 **자체가** §1 의 goal 에 비해 과하다」를 말할 수 있다. 상세는 아래 「층 1 `overdesign` — 설계자 시선」 절.
```

- [ ] **Step 5: 한 줄 제약을 기계로 확인한다**

```bash
export PYTHONDONTWRITEBYTECODE=1
bash plugins/spec-distill/tests/test_overdesign_rubric.sh 2>&1 | tail -3
bash shared/tests/test_docreview_profile_schema.sh 2>&1 | tail -3
bash shared/tests/test_docreview_codex.sh 2>&1 | tail -3
```
Expected: 셋 다 `Fail: 0`. **`test_docreview_codex.sh` 가 RED 면 `layer1:` 이 줄바꿈된 것이다** — 그 락이 `profile_parse_ambiguous` 를 직접 잰다.

프로필이 실제로 codex 프롬프트에 어떻게 실리는지도 눈으로 본다:

```bash
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_codex.sh 2>&1 | grep -i 'layer 1'
```
Expected: `Layer 1 (big-picture coherence) — categories: goal_fit, …, overdesign`.

- [ ] **Step 6: 커밋**

```
feat(docreview): 두 문서 자리의 층 1 에 설계자 시선 축 overdesign 을 세운다

기존 축은 전부 「맞는가」를 묻는다(정렬·정합·준수·폐쇄·존재 — 프로필 본문 실측).
이 축만 「과한가」를 묻는다. 절차를 얹어도 「같은 것을 겨누는가」에서 「goal 에 비해
과한가」는 안 나온다 — 다른 질문이다.

기준은 두 자리에서 모양이 같다: 「상류가 말한 goal 대비 과한가」. brief 의 상류는
사용자 원문(두 원문 — payload §6 의 S1 과 audit 블록의 S2 이상)이고 design-doc 의
상류는 브리프 §1 Goal 이다. 같은 이름의 축이 자리마다 다른 것을 재는 것이 아니라
같은 관계를 각자의 상류에 대해 잰다.

술어 ②(왜곡)는 design-doc 에만 간다 — 그 대상이 구조·구현이고 brief 에는 그것이
없다. 기존 여덟 축의 이름과 불릿 문구는 한 글자도 안 바꾼다.

layer1: 은 한 줄이다. 줄바꿈이면 codex 러너가 rc 5 로 죽고 T13 의 lay_of(head -1)가
축을 덜 재는데 Python 게이트는 PyYAML 이라 GREEN 이다 — 판정자 하나를 조용히 끈다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

---

## Task 16: 판정 한 줄의 형식 — 태그 다섯 · 대체안 · 천장 · 금지 어법 (AC7 · AC7′)

**Files:**
- Modify: `plugins/spec-distill/tests/test_overdesign_rubric.sh` (축 추가)
- Modify: 두 프로필 (새 절 `## 층 1 \`overdesign\` — 설계자 시선` 의 앞부분)

**태그 다섯** — ponytail 원문 다섯 중 코드 전용 둘(`stdlib:`·`native:`)을 버리고 셋을 그대로 쓰며, 원문에 없는 둘을 **리포 자신에게서** 만든다(P23 재결정 — 설계 결정 기록 C26 행).

| 태그 | 출처 |
|---|---|
| `delete:` · `yagni:` · `shrink:` | ponytail `skills/ponytail-review/SKILL.md:23`·`:26`·`:27` |
| `bent:` | 리포 — D22 · CLAUDE.md Forbidden Patterns |
| `altitude:` | 리포 — design-doc 층 2 `testing` 의 반대 방향 |

**`ponytail ` 접두 규약** — 이 계획과 설계문서는 devbrew 파일과 **ponytail 저장소** 파일을 둘 다 인용한다. ponytail 쪽 경로는 이 워크트리에 **없다.** 프로필 본문에는 **출처를 적지 않는다**(자기 출처를 담는 것은 self-narrating artifact 다 — CLAUDE.md Forbidden Patterns). 출처는 CHANGELOG 와 PR 에만 남긴다.

- [ ] **Step 1: 축을 먼저 더한다**

`test_overdesign_rubric.sh` 의 AC6 블록 뒤:

```bash
# ── AC7 : 판정 한 줄의 형식 · 태그 · 대체안 · 천장 · 금지 어법 ────────────
for tag in 'delete:' 'yagni:' 'shrink:' 'altitude:'; do
  has "$BB" "\`$tag\`" "AC7: brief 본문에 태그 $tag 가 있다"
  has "$DB" "\`$tag\`" "AC7: design 본문에 태그 $tag 가 있다"
done
has   "$DB" '`bent:`' "AC7: design 본문에 태그 bent: 가 있다 (술어 ②)"
hasnt "$BB" '`bent:`' "AC7: brief 본문에 태그 bent: 가 «없다» (술어 ② 는 design 자리의 것)"
has "$BB" '대체안 없음 — 그냥 뺀다' "AC7: brief 본문에 삭제 제안의 명시 문구가 있다"
has "$DB" '대체안 없음 — 그냥 뺀다' "AC7: design 본문에 삭제 제안의 명시 문구가 있다"
has "$BB" '└ 천장' "AC7: brief 본문에 천장 규약이 있다"
has "$DB" '└ 천장' "AC7: design 본문에 천장 규약이 있다"
has "$BB" 'no-trigger' "AC7: brief 본문에 되돌릴 길 없음의 공시가 있다"
has "$DB" 'no-trigger' "AC7: design 본문에 되돌릴 길 없음의 공시가 있다"
has "$BB" '헤지형' "AC7: brief 본문에 금지 어법이 있다"
has "$DB" '헤지형' "AC7: design 본문에 금지 어법이 있다"
# AC7' — brief 자리에만 있는 어법 공존 규약
has   "$BB" '사용자가 고를 두 상태를 사실로 제시해서 세워라' \
  "AC7': brief 본문에 두 어법 계약의 공존 규약이 있다"
```

- [ ] **Step 2: 실패 확인 → 두 프로필에 절을 만든다**

두 프로필의 층 2 절 **앞**(층 1 불릿 목록 다음)에 새 `##` 절을 연다. 아래 블록은 **두 프로필에 같은 문구로** 넣되 **표에서 `bent:` 행을 brief 에서는 뺀다**(AC7):

````markdown
## 층 1 `overdesign` — 설계자 시선

기존 축은 「맞는가」를 묻는다. 이 축은 「**과한가**」를 묻는다. 두 물음은 다르므로 다른 finding 으로 낸다 — 기존 축의 판정을 이 축 이름으로 다시 내지 않는다.

### 판정 한 줄

```
<앵커>: <태그> <무엇이 과한가>. <더 단순한 대안>.
        └ 천장: <이 판정이 틀릴 조건>
```

| 태그 | 언제 |
|---|---|
| `delete:` | 죽은 절 · 안 쓰는 유연성 · 투기적 기능 |
| `yagni:` | 구현체 하나뿐인 추상 · 아무도 안 쓰는 설정 · 호출자 하나뿐인 층 |
| `shrink:` | 같은 결론, 더 적은 구조 |
| `bent:` | 제약 X 를 지키려 구조 Y 가 들어왔는데 X 를 만족하는 더 곧은 길 Z 가 있다 (술어 ②) |
| `altitude:` | 이 문서의 층이 아닌 것이 들어와 있다 (술어 ③) |

**대체안은 같은 항목 안에 필수다.** 없으면 빈칸이 아니라 `대체안 없음 — 그냥 뺀다` 로 **명시**한다. 칸을 비우는 것은 삭제 제안이 **아니다** — 렌더가 침묵(`(대체안 미작성)`)과 판정을 다른 글자로 가른다. 대체안은 `replacement` 에, 「그대로 두면 무엇이 남는가」는 `if_unfixed` 에 싣는다.

**`└ 천장`** — 줄이자는 판정에는 그 줄임의 **천장**과 **올라갈 조건**을 함께 적는다. 조건을 못 적으면 `천장: (없음) · no-trigger` 로 남긴다 — 되돌릴 길이 없다는 공시다.

**금지 어법** — ❌ 「…가 과할 수도 있는데 고려해 보셨나요?」 같은 **헤지형** 질문. ✅ 사실 서술 + 대체안.
````

**`brief.md` 에만** 그 절 끝에 한 문단을 더한다(AC7′):

```markdown
이 자리의 층 1 은 finding 마다 사용자가 결정할 질문 하나를 요구한다. 그 요구와 위 금지 어법은 **양립한다** — 대체안을 제시하는 것이 곧 결정 질문을 세우는 것이기 때문이다. 규약은 이것이다: **결정 질문을 의문문으로 쓰지 말고, 사용자가 고를 두 상태를 사실로 제시해서 세워라.** 「yagni: §5 의 플러그인 레이어, 구현체 하나. 직접 호출로 인라인.」 은 사실 + 대체안이고 「인라인할까」가 그 자체로 결정 질문이다.
```

- [ ] **Step 3: GREEN + 커밋**

```bash
PYTHONDONTWRITEBYTECODE=1 bash plugins/spec-distill/tests/test_overdesign_rubric.sh 2>&1 | tail -3
```

```
feat(docreview): overdesign 축의 판정 한 줄 형식 — 태그 다섯 · 대체안 · 천장

태그 다섯 중 셋(delete:·yagni:·shrink:)은 외부 레퍼런스에서 그대로 오고 둘
(bent:·altitude:)은 리포 자신에게서 온다 — 외부 자료에 아키텍처 층위의 판정 기준이
한 글자도 없음을 전수 조사로 확인했고, 「그러면 리포에서 만든다」는 측정이 아니라
결정이라 P23 재결정으로 기록했다.

대체안은 같은 항목 안에 필수다. 칸을 비우는 것은 삭제 제안이 아니다 — 렌더가
침묵과 판정을 다른 글자로 가르므로 삭제를 제안할 때는 그렇게 쓴다.

천장 + 올라갈 조건이 한 방향 압력의 유일한 균형 장치다. 조건을 못 적으면
no-trigger 로 공시한다 — 되돌릴 길이 없다는 사실을 숨기지 않는다.

brief 자리에는 두 어법 계약의 공존 규약을 함께 둔다. 그 자리의 층 1 은 finding
마다 결정 질문 하나를 요구하고 이 축의 어법은 헤지형 질문을 금지하는데, 둘은
양립한다 — 안 적으면 리뷰어가 런타임에 모순을 스스로 푼다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

---

## Task 17: 사다리 · 자르지 않는 것 · 0건 출구 · 상한 (AC8 ~ AC11)

**Files:**
- Modify: `plugins/spec-distill/tests/test_overdesign_rubric.sh` (축 추가)
- Modify: 두 프로필 (`## 층 1 \`overdesign\`` 절의 뒷부분)

**사다리의 「higher rung」을 이 설계가 정의했다** — 원문에 방향이 정의돼 있지 않다(ponytail 저장소 전수 grep 확인). **번호가 작은 쪽**을 채택한다: `Stop at the first rung that holds` 와 일관되기 때문이다. ⚠ **그 선택의 대가**를 프로필 본문에도 적는다 — 작은 쪽은 **언제나 더 많이 자르는** 해석이라 「한 방향 압력」을 증폭한다.

**0건 출구는 부분 이식이다** — 원문의 `and stop.` 은 **가져오지 않는다**(AC10). `doc-critic` 은 `docreview-layer1`·`docreview-layer2` 두 블록을 **항상** 내야 하고, 층 1 블록이 없으면 엔진이 `critic_dead`(주 판정자 사망)로 읽어 라운드가 「미검증」으로 닫힌다(`docreview_route.py:156-168`).

**상한 N=3 은 총량을 약속하지 않는다**(AC11). 상한은 **판정자별**이라 라운드 총량은 **2N+α** 다. 「한 호출을 통째로 먹지 않는다」는 문구는 **없다** — 2N+α 로 반증되기 때문이다.

- [ ] **Step 1: 축을 먼저 더한다**

```bash
# ── AC8~AC11 : 두 본문을 같은 축으로 함께 돈다 ─────────────────────────────
for v in b d; do
  if [ "$v" = "b" ]; then T="$BB"; N="brief"; else T="$DB"; N="design"; fi
  has "$T" '성립하는 첫 단에서 멈춘다' "AC8: $N 본문에 「첫 단에서 멈춘다」가 있다"
  has "$T" '번호가 작은 쪽'           "AC8: $N 본문에 「두 단이 성립하면 번호가 작은 쪽」이 있다"
  has "$T" '한 방향 압력'             "AC8: $N 본문에 그 선택의 대가가 적혀 있다"
  for rung in '이 구조가 있어야 하나' '이미 리포에 있는' '이미 있는 하니스 표면' '한 줄 규약으로 되나' '그제서야 새 메커니즘'; do
    has "$T" "$rung" "AC8: $N 본문의 사다리에 「$rung」 단이 있다"
  done
  # ── AC9 : 자르지 않는 것 ────────────────────────────────────────────────
  for g in 'trust boundary' '데이터 손실' '보안' '접근성' '명시로 요청한' \
           '새 근거 없이 재논쟁' '읽기를 줄이지 않는다' '과함만' 'kill switch'; do
    has "$T" "$g" "AC9: $N 본문의 오탐 가드에 「$g」가 있다"
  done
  has "$T" 'Law 1·2·3' "AC9: $N 본문에 devbrew 자리의 가드가 있다"
  # ── AC10 : 0건 출구 ─────────────────────────────────────────────────────
  has   "$T" '이 문서는 이미 최소다' "AC10: $N 본문에 0건 출구 문구가 있다"
  has   "$T" '정당화'                "AC10: $N 본문에 「정당화를 붙이지 않는다」가 있다"
  has   "$T" '두 sentinel 블록'      "AC10: $N 본문에 「두 블록은 그래도 낸다」가 있다"
  has   "$T" '이 축에만'             "AC10: $N 본문에 「overdesign 축에만 걸린다」가 있다"
  hasnt "$T" 'and stop'              "AC10: $N 본문에 and stop 에 해당하는 문구가 «없다»"
  # ── AC11 : 상한 ─────────────────────────────────────────────────────────
  has   "$T" '한 판정자가 한 라운드에' "AC11: $N 본문의 상한이 «판정자별»임을 밝힌다"
  has   "$T" '2N+α'                   "AC11: $N 본문이 라운드 총량 2N+α 를 밝힌다"
  has   "$T" '무엇을 잘랐는지'        "AC11: $N 본문에 초과분 공시 규약이 있다"
  has   "$T" '강제하는 기계는 없다'    "AC11: $N 본문이 이 상한이 강제되지 않음을 밝힌다"
  hasnt "$T" '한 호출을 통째로 먹지 않는다' "AC11: $N 본문에 2N+α 로 반증되는 문구가 «없다»"
done
```

- [ ] **Step 2: 실패 확인 → 두 프로필에 이어 쓴다**

Task 16 의 절 끝에 **두 프로필 같은 문구로** 이어 붙인다:

````markdown
### 판정 절차 — 사다리

문제를 이해한 **뒤에** 돈다. 문서를 끝까지 읽고 흐름을 따라간 뒤에 오른다. **성립하는 첫 단에서 멈춘다.** 두 단이 성립하면 **번호가 작은 쪽**을 고른다.

1. 이 구조가 있어야 하나 — 투기적 필요면 한 줄로 그렇게 적고 뺀다
2. 이미 리포에 있는 원칙·메커니즘으로 되나
3. 이미 있는 하니스 표면(프로필 필드 · 처분 · 락 · 훅)으로 되나
4. 한 줄 규약으로 되나
5. 그제서야 새 메커니즘

⚠ 작은 쪽은 **언제나 더 많이 자르는** 해석이라 동점마다 판정이 절감 쪽으로 기운다 — 이 축의 **한 방향 압력**을 증폭한다. 균형 장치는 `└ 천장` 하나뿐이고 그것은 줄임을 되돌릴 조건을 적게 할 뿐 줄임 자체를 막지 않는다.

### 자르지 않는 것

- trust boundary 검증 · 데이터 손실 처리 · 보안 · 접근성 · 사용자가 **명시로 요청한** 동작
- 사용자가 완전판을 고집하면 짓는다 — **새 근거 없이 재논쟁하지 않는다.** 같은 판정을 새 근거 없이 다음 라운드에 다시 내는 것은 규약 위반이다.
- 사다리는 **해답**을 줄이지 **읽기를 줄이지 않는다.**
- 이 축은 **과함만** 본다. 충실도·방향의 결함은 다른 축이 낸다.
- Law 1·2·3 과 kill switch 는 어떤 모드에서도 안 자른다.

### 0건 출구 — 이 축에만 걸린다

`overdesign` finding 이 하나도 없으면 「**이 문서는 이미 최소다.**」 한 줄만 적는다. **정당화**도 「찾아봤으나 없음」 서술도 붙이지 않는다. **두 sentinel 블록(`docreview-layer1`·`docreview-layer2`)은 그대로 낸다** — 다른 축의 검토도, 리뷰도 끝내지 않는다.

### 상한

이 축의 finding 은 **한 판정자가 한 라운드에 3건**까지. 근거 — 게이트가 `AskUserQuestion` 을 4개씩 부르므로 3 이면 판정자 하나가 한 호출을 혼자 채우지 못한다. **라운드 총량은 약속하지 않는다:** 상한은 판정자별이라 총량은 **2N+α** 다. 초과분은 한 묶음으로 남기고 **무엇을 잘랐는지** 한 줄로 적는다. 이 상한을 **강제하는 기계는 없다.**
````

- [ ] **Step 3: GREEN + 커밋**

```
feat(docreview): overdesign 축의 절차 · 오탐 가드 · 0건 출구 · 상한

「higher rung」의 방향은 외부 원문에 정의돼 있지 않다(전수 grep 확인). 번호가 작은
쪽으로 정한다 — 「성립하는 첫 단에서 멈춘다」와 일관되기 때문이다. 그 대가를
프로필 본문에도 적는다: 작은 쪽은 언제나 더 많이 자르는 해석이라 이 축의 한 방향
압력을 증폭한다. 균형 장치는 천장 하나뿐이고 그것은 줄임을 막지 않는다.

오탐 가드는 외부 원문 다섯 + 조사가 찾아낸 셋(재논쟁 금지 · 읽기는 안 줄인다 ·
스코프 배제) + devbrew 자리의 것(Law 1·2·3 · kill switch)이다. 브리프는 원문
네 문단 중 첫 문장만 가져왔었다.

0건 출구는 «부분» 이식이다. 원문의 and stop. 은 가져오지 않는다 — doc-critic 은
두 sentinel 블록을 항상 내야 하고 층 1 블록이 없으면 엔진이 critic_dead 로 읽어
라운드가 「미검증」으로 닫힌다.

상한 N=3 은 판정자별이라 라운드 총량은 2N+α 다. 「한 호출을 통째로 먹지 않는다」는
문구를 쓰지 않는다 — 2N+α 로 반증된다. 이 상한을 강제하는 기계가 없다는 사실도
함께 적는다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

---

## Task 18: T13 을 부재 열거에서 허용 목록으로 (AC12)

**Files:**
- Modify: `plugins/spec-distill/tests/test_brief_review_ng3.sh` (T13 단언 ④⑤ 신설, `leak2` 제거)

**Interfaces:**
- Consumes: Task 15 의 축 이름.
- Produces: `SHARED` 명시 열거.

**지금 무엇을 못 잡는가** — 현행 T13 은 세 이름만 본다:

```bash
for _did in goal_fit architecture tradeoffs; do grep -qF "$_did" <brief layer1>; done
```

`problem_definition` · `scope` · `component_relations` · `data_flow` · `feasibility` **다섯 축이 brief 에 들어가도 무언**이다 — **fail-open** 이다. ④ 가 그것을 **허용 목록**으로 뒤집는다: 목록 밖 공유는 전부 걸린다.

**단언 ③ 은 「층 2」로 둔다** — 현행 락이 대조하는 것이 `L2_D` 하나이고(`L1_D` 는 그 루프에 안 들어간다), 「층 1·2」로 넓히는 것은 기존 유지가 아니라 **신설**이다. 이 Task 의 범위 밖이다.

**⑤ 의 한계 공시** — ⑤ 는 리터럴 핀이고 **바이트를 잰다.** 두 불릿을 무의미하게 다르게 써도 통과한다. 잡는 것은 **한쪽을 다른 쪽에 통째로 베껴 넣는 것**뿐이다. 의미는 못 잰다. 이 문장을 락 파일 주석에 그대로 적는다.

- [ ] **Step 1: `leak2` 블록을 ④⑤ 로 바꾼다**

현행 `leak2` 루프(세 이름 부재 검사)를 **지우고** 그 자리에:

```bash
# ── T13 ④ : 층 1 의 공유는 «허용 목록»이다 (부재 열거 → 허용 목록) ──────────
# 옛 판정은 금지 셋(goal_fit·architecture·tradeoffs)이라 그 밖은 전부 통과했다 —
# problem_definition·scope·component_relations·data_flow·feasibility 다섯이 brief 에
# 들어가도 무언이었다(fail-open). 허용 목록으로 뒤집으면 목록 밖 공유가 전부 걸린다.
#
# SHARED 는 «의도적으로 두 자리가 함께 쓰는» 축이다. 여기 이름을 더하는 것은 자리
# 경계를 한 칸 여는 결정이라 diff 에 한 줄로 드러나야 한다.
SHARED="overdesign"
shared_leak=""
n_l1b=0
for _bid in $(printf '%s' "$L1_B" | tr -d '[]' | tr ',' ' '); do
  n_l1b=$((n_l1b+1))
  printf '%s' "$L1_D" | grep -qF "$_bid" || continue
  printf '%s\n' $SHARED | grep -qxF "$_bid" || shared_leak="$shared_leak $_bid"
done
[[ "$n_l1b" -ge 2 ]] \
  && ok "T13④: brief 층 1 에서 축 ${n_l1b}개를 읽었다 (아래 판정의 양의 짝)" \
  || no "T13④: brief 층 1 에서 축을 ${n_l1b}개만 읽었다 — 아래 판정이 공허하다"
[[ -n "$SHARED" ]] \
  && ok "T13④ 양성 대조: SHARED 가 비어 있지 않다 ($SHARED)" \
  || no "T13④: SHARED 가 빈 집합이다 — 허용 목록 판정이 「전부 금지」로 퇴행했다"
[[ -z "$shared_leak" ]] \
  && ok "T13④: brief 층 1 ∩ design 층 1 ⊆ SHARED {$SHARED}" \
  || no "T13④: 목록 밖 공유가 있다:$shared_leak (자리 경계가 무너졌다 — SHARED 를 늘리려면 같은 커밋에서 이 줄을 고쳐라)"

# ── T13 ⑤ : SHARED 의 각 축이 두 자리에서 «다른 문장»으로 정의된다 ──────────
# 한계 공시 — 이것은 리터럴 핀이고 «바이트»를 잰다. 두 불릿을 무의미하게 다르게
# 써도 통과한다. 잡는 것은 한쪽을 다른 쪽에 «통째로 베껴 넣는 것»뿐이고, 의미는 못
# 잰다. 그래서 기준어 축(각자 자기 상류를 담는가)을 함께 둔다.
bullet_of() { grep "^- \`$2\`" "$1" | head -1; }   # bullet_of <프로필> <축>
for _ax in $SHARED; do
  b_line="$(bullet_of "$PROF_BRIEF" "$_ax")"; d_line="$(bullet_of "$PROF_DESIGN" "$_ax")"
  if [[ -n "$b_line" && -n "$d_line" ]]; then
    ok "T13⑤ 양의 짝: 두 프로필에 $_ax 불릿이 실재한다"
  else
    no "T13⑤: $_ax 불릿이 없다 (brief='$b_line' design='$d_line') — 아래 판정이 공허하다"
    continue
  fi
  [[ "$b_line" != "$d_line" ]] \
    && ok "T13⑤: $_ax 가 두 자리에서 다른 문장으로 정의된다" \
    || no "T13⑤: $_ax 불릿이 두 자리에서 바이트로 같다 — 한쪽을 통째로 베꼈다"
  printf '%s' "$b_line" | grep -qF '사용자 원문' \
    && ok "T13⑤: brief 의 $_ax 가 자기 상류(사용자 원문)를 기준어로 담는다" \
    || no "T13⑤: brief 의 $_ax 에 자기 상류 기준어가 없다"
  printf '%s' "$d_line" | grep -qF '브리프 §1 Goal' \
    && ok "T13⑤: design 의 $_ax 가 자기 상류(브리프 §1 Goal)를 기준어로 담는다" \
    || no "T13⑤: design 의 $_ax 에 자기 상류 기준어가 없다"
done
```

- [ ] **Step 2: GREEN 을 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 bash plugins/spec-distill/tests/test_brief_review_ng3.sh 2>&1 | tail -3`
Expected: `Fail: 0`. Pass 수가 baseline 21 에서 늘어난다.

- [ ] **Step 3: 다섯 변이로 이빨을 확인한다 (설계 §10)**

**하나씩** 넣고 돌린 뒤 `git checkout HEAD -- <경로>` 로 복원한다.

| # | 변이 | 기대 | 왜 이 변이인가 |
|---|---|---|---|
| ① | brief `layer1` 에 `scope` 를 더한다 | **RED** | **지금은 GREEN 인 자리** — 옛 금지 셋에 없던 이름이다. ④ 의 실질이 여기서 증명된다 |
| ② | brief `layer1` 에 `goal_fit` 을 더한다 | RED | 기존과 동등(퇴행 방지) |
| ③ | `SHARED=""` 로 비운다 | RED | ④ 가 「전부 금지」로 퇴행하지 않았다는 양성 대조 |
| ④ | design 의 `overdesign` 불릿을 brief 것으로 통째 교체 | RED | ⑤ 가 베끼기를 잡는다 |
| ⑤ | brief `layer1` 에서 `overdesign` 을 뺀다 | RED | ⑤ 가 공허하지 않다(불릿 실재 양의 짝) |

**①②⑤ 는 `layer1:` 한 줄을 고치는 변이다** — 그 줄을 **두 줄로 쪼개지 않는다.** 쪼개면 `lay_of`(`head -1`)가 첫 줄만 읽어 변이가 **못 잼**으로 떨어진다(「안 잡힘」이 아니다).

다섯이 전부 RED 여야 한다. 하나라도 GREEN 이면 그 축은 이빨이 없다.

- [ ] **Step 4: 커밋**

```
test(spec-distill): T13 의 층 1 경계를 부재 열거에서 허용 목록으로

옛 판정은 금지 셋(goal_fit·architecture·tradeoffs)이라 그 밖은 전부 통과했다 —
problem_definition·scope·component_relations·data_flow·feasibility 다섯이 brief 에
들어가도 무언이었다(fail-open). 허용 목록(SHARED = {overdesign})으로 뒤집으면 목록
밖 공유가 전부 걸리고, SHARED 를 늘리는 것은 diff 에 한 줄로 드러난다.

⑤ 는 같은 이름이되 재는 대상이 다르다는 것을 붙든다 — 두 불릿이 둘 다 실재하고
문자열이 다르며 각자 자기 상류를 기준어로 담는가. 한계 공시: 이것은 리터럴 핀이고
바이트를 잰다. 두 불릿을 무의미하게 다르게 써도 통과한다 — 잡는 것은 한쪽을 다른
쪽에 통째로 베껴 넣는 것뿐이다.

단언 ③ 은 층 2 범위로 둔다. 현행 락이 대조하는 것은 L2_D 하나이고(L1_D 는 그 루프에
안 들어간다) 「층 1·2」로 넓히는 것은 기존 유지가 아니라 신설이다.

다섯 변이 전부 RED 확인. ①(brief layer1 에 scope) 이 지금은 GREEN 인 자리였다 —
그것이 이 교체의 실질이다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

---

## Task 19: PR 2 마무리 — AC13 확인 · bump · 전량 · PR

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`
- Modify: `plugins/spec-distill/CHANGELOG.md`

- [ ] **Step 1: AC13 — 엔진을 0줄 건드렸는지 기계로 확인한다**

```bash
git diff origin/main --stat -- shared/docreview/scripts/docreview_state.py
```
Expected: **빈 출력.** 한 줄이라도 나오면 PR 2 의 단독 머지 가능성이 깨진 것이다 — 그 hunk 를 PR 3 쪽으로 옮기거나 별도 PR 로 뺀다.

`docreview_route.py` 도 같이 본다(설계는 `docreview_state.py` 만 못 박았지만 같은 논리다).

- [ ] **Step 2: bump — `spec-distill` minor (`3.4.0`)**

**minor 인 이유** — 새 surface 가 하나다: 두 문서 자리의 층 1 rubric 에 축 `overdesign`. 리뷰어가 받는 계약이 바뀐다. **머지 직전에 `origin/main` 값을 다시 읽어 확정한다.**

- [ ] **Step 3: CHANGELOG 항목**

담을 것:

- 기존 축 여덟이 전부 「맞는가」 방향이라는 **실측**과, 겹치는 자리가 둘뿐이라는 것
- 두 자리에서 기준이 **같은 모양**(상류가 말한 goal 대비)이고 상류만 다르다는 것
- 술어 ② 가 brief 에 없는 이유
- **`layer1:` 한 줄 제약**과 줄바꿈이 무엇을 조용히 끄는가
- 태그 다섯의 출처 — 셋은 ponytail(`DietrichGebert/ponytail` HEAD `e3ba2aa`), 둘은 리포. **「외부에 없더라」는 측정이고 「그러면 리포에서 만든다」는 결정이라 P23 재결정으로 기록했다**는 사실
- 「higher rung」을 작은 쪽으로 정한 것과 **그 대가**(한 방향 압력 증폭)
- 0건 출구가 **부분** 이식이고 `and stop.` 을 안 가져온 이유
- 상한이 **판정자별**이고 총량은 2N+α 이며 **강제하는 기계가 없다**는 것
- T13 의 fail-open → fail-closed 전환과 ⑤ 의 **바이트 판정 한계**
- **열린 위험 셋** — 수용률 역설(OQ-F) · 한 방향 압력(OQ-E) · rubric 항목 수 증가(OQ-G). 계측기가 없어 이 변경이 무엇을 바꿨는지 **원리적으로 못 잰다**(OQ-A)

- [ ] **Step 4: 전량**

```bash
bash .claude/plan-tmp/capture_baseline.sh > .claude/plan-tmp/after-pr2.txt 2>&1
```
baseline 과 줄 단위 대조. Pass 가 줄어든 줄이 없어야 한다.

- [ ] **Step 5: 커밋 + PR**

PR 본문:

```markdown
**선행** — PR 1 (#N) · PR 3 (#M). `1 → 3 → 2` 머지 순서의 셋째다(설계 AC25).

## 결함

**brief 자리의 층 1 은 `[direction]` 하나**이고 그 축이 묻는 것은 「사용자가 정한 방향이 틀렸을 근거가 있는가」다. 「그 방향이 goal 에 비해 과한가」는 어디에도 없다.

**design-doc 자리에는 층 1 여덟 축이 있지만 전부 한 방향**이다 — 정렬·정합·준수·폐쇄·존재(프로필 본문 실측). 절차를 얹어도 「같은 것을 겨누는가」에서 「goal 에 비해 과한가」는 안 나온다. 겹치는 자리는 정확히 둘, 그것도 좁다.

## 더한 것

- 두 자리의 `layer_rubric.layer1` 에 축 `overdesign` **하나**. 기존 여덟 축의 이름과 불릿 문구는 **한 글자도 안 바뀐다.**
- 술어 셋 — ① 과함(goal 대비) · ② 왜곡(design-doc 만) · ③ 층위 이탈. 처분은 전부 `decide` 다(보호 헤딩의 캐스케이드로 non-`decide` 가 승격되므로 `defer` 배관은 이 축에서 도달 불가다 — 이 리뷰에서 **실제로 여섯 번 발동했다**).
- 판정 한 줄의 형식 · 태그 다섯 · 대체안 필수 · `└ 천장` · 금지 어법
- 사다리 5단 · 오탐 가드 여덟 · 0건 출구 · 상한 N=3
- T13 을 **fail-open → fail-closed** 로 (`SHARED = {overdesign}`)

## 공시 — 이 PR 이 닫지 않는 것

- **수용률 역설**(OQ-F) — 설명이 좋아지면 정확도가 아니라 **수용률**이 오른다. 두 goal 이 독립이라는 전제가 여기서 깨진다.
- **한 방향 압력**(OQ-E) — 사다리는 「쓰인 것」에만 적용되어 판정이 항상 「줄여라」로 나고 과소설계는 원리적으로 못 잡는다. 외부 원문도 한 방향이고 균형을 리뷰어 **밖**에서 잡는다. 이 설계는 천장 장치로 리뷰어 **안**에 일부를 들이는데 **검증된 선례가 없다.**
- **계측기 부재**(OQ-A) — 게이트 회계에 「열린 `decide` 수」도 「카테고리별 수」도 없다. 이 변경이 무엇을 바꿨는지 **원리적으로 못 잰다.**
- **상한의 무이빨** — 프로필에 담을 필드가 없어 강제 없는 산문이다.
- **T13 ⑤ 의 바이트 판정** — 두 불릿을 무의미하게 다르게 써도 통과한다.

## AC

AC5 ✓ · AC6 ✓ · AC7 ✓ · AC7′ ✓ · AC8 ✓ · AC9 ✓ · AC10 ✓ · AC11 ✓ · AC12 ✓(다섯 변이 전부 RED) · AC13 ✓(`docreview_state.py` 0줄) · AC23 ✓ · AC24 ✓ · AC25 ✓

## 설계

`docs/superpowers/specs/2026-09-21-designer-lens-review-design.md` §5.1 ~ §5.6

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

**사용자에게** 머지를 부탁한다: `! gh pr merge <번호> --merge`.

---

## Task 20: e2e — 설치 캐시를 먼저 확인한다

**Files:** 없음(측정만). 결과는 보고로 낸다.

**왜 캐시 확인이 선행인가** — 실행 시 agent 정의는 리포가 아니라 **설치 캐시**에서 온다(`~/.claude/plugins/cache/devbrew/spec-distill/<버전>/`). 리포만 고친 e2e 는 **옛 리터럴 축**으로 돌고, **0건 출구가 그 오진을 감춘다**(「이 문서는 이미 최소다」가 「축이 안 돈다」와 같은 글자로 나온다).

- [ ] **Step 1: 설치 캐시가 리포와 같은지 확인한다**

```bash
CACHE="$HOME/.claude/plugins/cache/devbrew/spec-distill"
ls "$CACHE"
```
그다음 최신 버전 디렉토리에 대해:

```bash
diff -r "$CACHE/<버전>/agents" plugins/spec-distill/agents
diff "$CACHE/<버전>/references/docreview-profiles/design-doc.md" plugins/spec-distill/references/docreview-profiles/design-doc.md
diff "$CACHE/<버전>/references/docreview-profiles/brief.md" plugins/spec-distill/references/docreview-profiles/brief.md
```

Expected: 차이 없음. **차이가 있으면 여기서 멈춘다** — 그 e2e 결과를 「축이 무이빨」의 근거로 **쓰지 않는다.** 캐시를 갱신(플러그인 재설치)한 뒤 다시 잰다.

- [ ] **Step 2: 과설계가 심어진 설계문서 하나로 한 라운드를 돌린다**

임시 설계문서를 만든다 — 구현체 하나뿐인 추상 층, 아무도 안 쓰는 설정 필드, 구현 절차(명령·순서)가 §5 에 들어간 자리 셋을 심는다. 그다음 `Skill spec-distill:reviewing-spec <그 경로>`.

- [ ] **Step 3: 셋을 눈으로 본다**

| 무엇 | 기대 |
|---|---|
| `overdesign` finding 의 형식 | `<앵커>: <태그> <무엇이 과한가>. <대체안>.` + `└ 천장:` |
| 게이트 렌더 | §5.8 의 여섯 줄 — 「그대로 두면 / 고치면 / 근거 / 자리(사람말) / 대안(상태별)」 |
| `AskUserQuestion` 라벨 | 항목마다 다르고 각각 `— <replacement 압축>` 을 담는다 |

- [ ] **Step 4: 보고한다**

세 가지를 **관측한 그대로** 적는다 — 나오지 않은 것은 「나오지 않았다」로 적고 추정하지 않는다. `overdesign` 이 0건이면 **그것이 「축이 안 돈다」인지 「정말 최소다」인지 이 e2e 로는 못 가른다**(0건 출구의 구조적 한계) — 그때는 과설계를 **더 크게** 심어 다시 돌린다.

---

## 실행 선택

계획이 `docs/superpowers/plans/2026-09-22-designer-lens-review.md` 에 저장됐다. 실행 방식 둘:

1. **Subagent-Driven (권장)** — Task 마다 새 subagent 를 dispatch 하고 그 사이에 리뷰한다. 이 계획에는 특히 잘 맞는다: Task 7(라벨의 `kind` 함수화)은 리터럴이 일곱 자리에 복제돼 있어 **같은 전제를 공유하지 않는 눈**이 필요하고, Task 14(EXEMPT 재앵커 · 골든)는 실측을 그대로 옮기는 기계적 작업이라 격리가 싸다.
2. **Inline Execution** — 이 세션에서 `superpowers:executing-plans` 로 체크포인트를 두고 일괄 실행한다.

어느 쪽으로 갈까요?
