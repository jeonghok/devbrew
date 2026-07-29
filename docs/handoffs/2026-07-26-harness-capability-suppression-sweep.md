# 핸드오프 — 하니스가 모델 능력을 억제하는 지점 전수 조사·제거

> *"하네스를 결정론적으로 가는건 좋은데 너무 옥죄면 성능 저하가 될 수 있어. 하네스를 가능하다면 가볍게 가져가고 모델을 믿을수도 있어야해."*
> — 사용자, 2026-06-07

**한 문장**: devbrew 리포의 **모든 컨텍스트 표면**(플러그인 코드 · docs · 원장 · 메모리 · `CLAUDE.md`)에서 하니스가 모델(Claude·codex)의 능력을 정당한 이유 없이 깎는 지점을 전수 열거하고 제거한다.

> ## 절대 조항
>
> **하니스를 무겁게 만들어서 능력을 제한하는 것은 절대 안 된다.**
> — 사용자, 2026-07-26
>
> 이것은 트레이드오프가 아니다. "무게 대비 이득"을 계산해서 통과시키는 항목이 아니라, 능력 제한이 확인되면 제거가 default다. 유지하려면 §1의 load-bearing 사유가 **명시적으로** 성립해야 하고, 성립을 주장하는 쪽이 근거를 댄다.

**원칙은 이미 있다 — 실행이 어긋났다.** `docs/philosophy/devbrew-harness-philosophy.md:75`가 이미 *"결정론 장치는 모델 신뢰가 불충분하고 오류 비용이 높을 때, 즉 load-bearing일 때만 정당하다"* 고 쓴다. 그래서 이 작업은 **새 원칙 추가가 아니라 기존 원칙 위반 사례의 제거**다. 철학 doc에 새 P#를 추가하지 말 것(devbrew default = 기존 원칙 흡수).

**작성 맥락**: 2026-07-26 spec-distill Phase B 설계 세션에서 작성자(모델)가 codex의 웹 검색에 상한을 박고 이빨 없는 게이트 체크를 추가하려 했고, 사용자가 *"하네스로 억제하지 말라고 했는데 너가 말하는건 코덱스나 클로드를 억제하는 느낌"*으로 교정. 같은 클래스가 리포 전반에 이미 축적돼 있을 것이므로 별 세션으로 분리했다.

**이 핸드오프는 조사·제거 작업이다.** Phase B(brief 리뷰 파이프라인) 설계와 독립이며, 서로를 블록하지 않는다.

---

## 1. 판별 기준 — 이게 이 작업의 전부다

모든 후보를 두 통에 나눈다. **애매하면 유지하고 사용자에게 올린다.**

### 유지 (load-bearing — 절대 약화 금지)

- **Law 2 물리 분리** — 리뷰어의 `tools:` allowlist에서 `Write`/`Edit`/`Bash` 부재. 이것이 없으면 리뷰어가 아니다.
- **kill switch** — `DEVBREW_DISABLE_*`. 보안 컨트롤.
- **mutation guard / digest seal** — qg의 verdict cap. 자기승인 봉쇄.
- **정확성 게이트** — 틀린 결과가 조용히 통과하는 것을 막는 결정론. 예: `check_brief.py`의 bijection, fail-closed exit.
- **Unbounded-autonomy 가드** — 종료 조건 없는 루프의 상한. 단 *루프가 실재할 때만*. 단일 호출에 상한을 씌운 것은 이 항목이 아니다(아래 참조).
- **입력 격리** — 리뷰의 타당성이 입력 제한에 걸려 있는 경우. 예: brief-critic이 audit·transcript를 못 봐야 프레이밍 오염을 안 받는다. 이건 능력 억제가 아니라 **실험 설계**다.

### 제거 (능력 억제 — 값이 없다)

- **모델 리터럴 핀** — `model: sonnet` / `model: opus` 하드코딩. 세션이 더 강한 모델일 때 downgrade가 되고, 리포가 반복 실증한 *"모델 강도·다양성이 fail-open 적발의 유일 backstop"* 과 정면으로 어긋난다. 옳은 값은 `model: inherit`.
- **조사 도구 결핍** — 근거를 찾는 것이 본질인 역할에서 `WebSearch`/`WebFetch` 부재, 또는 `WebFetch`만 있고 `WebSearch`가 없는 비대칭(URL은 열 수 있는데 찾을 수는 없음).
- **단일 호출에 씌운 횟수 상한** — 한 번의 subagent 턴 / 한 번의 `codex exec`는 이미 턴으로 경계가 있다. 그 안의 검색 횟수·읽기 횟수를 프롬프트로 묶는 것은 순수 손실.
- **이빨 없는 결정론 체크** — "기록이 존재하는가"만 보는 게이트. 기록을 쓰는 주체가 검사 대상 자신이면 무의미한 의례이고, 통과를 보장으로 오독시켜 오히려 해롭다.
- **NL 의도·라우팅·편의에 쌓은 가드** — 구조적 escape hatch가 이미 있는 영역. `/qg branch` 선례(그 위에 4층 결정론을 얹으려던 시도가 폐기됨).
- **탐색 폭을 좁히는 프롬프트 문구** — *"이것만 보고 더 찾지 마라"*, *"N개까지만 제시"* 류. 상한이 비용 통제 목적이면 사용자 승인 게이트로 옮기고 프롬프트에서 뺀다.

---

## 2. 스코프 — 모든 컨텍스트 표면

억제는 코드에만 있지 않다. **미래 세션이 규칙으로 읽는 모든 표면**이 대상이다.

| 대상 | 무엇을 보나 |
|---|---|
| `plugins/*/agents/*.md` | `model:` 리터럴 핀 · `tools:` 조사 도구 결핍 · 역할 프롬프트 안의 탐색 상한 문구 |
| `plugins/*/skills/*/SKILL.md` | 프롬프트 상한 · 이빨 없는 체크 · NL 라우팅에 쌓인 가드 · `cost_class` 승인 게이트의 실질 효과 |
| `plugins/*/scripts/*.py`·`*.sh` | 예산 카운터(`web_budget.py` 등) · fan-out 제한 · codex 호출 플래그 |
| `plugins/*/README.md`·`CHANGELOG.md` | 억제를 *원칙으로* 서술한 문장("Principles Instantiated"에 자랑처럼 적힌 상한) |
| `CLAUDE.md` | Plugin Shape·Forbidden Patterns 중 능력 제한을 규약화한 항목 |
| `docs/philosophy/devbrew-harness-philosophy.md` | 동일. **단 새 원칙 추가 금지** — 위반 제거만 |
| `docs/audits/*.md` · `*-journal.jsonl` · `*-data.json` | 과거 감사가 "상한을 추가하라"고 권고한 항목(§2.1 취급 규칙) |
| `docs/superpowers/specs/*-design.md` | 과거 설계가 억제를 확정 제약으로 박제한 곳(§2.1) |
| `docs/superpowers/interview/*.md` | 동일 |
| **메모리** `~/.claude/projects/-Users-jeonghokim-Downloads-devbrew/memory/` | 억제를 지시하는 `feedback`/`project` 메모리. `MEMORY.md` 인덱스 한 줄도 함께 |
| `.claude/` 하위 세션 state · plugin state | 상한 카운터가 규약으로 굳은 곳 |

**참조 구현**: `plugins/plugin-audit/agents/*.md` — 3개 전부 `model: inherit`. 가장 최근 플러그인이 이미 옳다. 이 패턴을 나머지로 전파한다.

### 2.1 기록(원장·과거 design doc) 취급 — 제거 전 확인 필요

활성 규칙과 과거 기록은 다르게 다룬다:

- **활성 규칙**(`CLAUDE.md` · philosophy · `SKILL.md` · agent frontmatter · 메모리 · README) → **제거·수정한다.** 미래 세션이 이것을 규칙으로 읽기 때문이다.
- **과거 기록**(`*-journal.jsonl` append-only 원장 · 머지된 `*-design.md` · `CHANGELOG.md`) → 지우면 *왜 그렇게 됐는지*의 이력이 사라진다. 기본은 **정정 항목 추가**(원장은 append, design doc은 사후 반증 문단 — Spec A가 이미 쓰는 방식)이고, 통째 제거는 **사용자에게 확인**한다.
- 판별 질문: *"이 파일을 미래 세션이 규칙으로 읽는가, 이력으로 읽는가?"* 규칙이면 고치고, 이력이면 정정을 얹는다.

---

## 3. 씨앗 — 이미 확인된 후보

조사 시작점이다. **전수 조사를 대체하지 않는다** — 아래에 없는 것이 없다는 뜻이 아니다.

### 3.1 모델 리터럴 핀 (가장 확실)

`plugin-audit`(가장 최근 플러그인)은 3개 에이전트 전부 `model: inherit`이다. 구 플러그인이 뒤처져 있다.

| 파일 | 현재 | 의심 강도 | 근거 |
|---|---|---|---|
| `plugins/spec-distill/agents/spec-reviewer.md` | `model: sonnet` | **높음** | Law 2 물리 분리 리뷰어. 세션이 opus인데 리뷰어가 sonnet이면 리뷰가 writer보다 약하다 |
| `plugins/spec-distill/agents/blind-spot-prober.md` | `model: sonnet` | **높음** | 적대적 premortem — unknown-unknowns 발굴이 역할 |
| `plugins/spec-distill/agents/steelman-builder.md` | `model: sonnet` | **높음** | 가장 강한 반대 논거를 만드는 역할 |
| `plugins/spec-distill/agents/coverage-mapper.md` | `model: sonnet` | 중간 | advisory 제안자 — 약해도 orchestrator가 판정하므로 피해가 제한적 |
| `plugins/quality-gates/agents/adversarial.md` | `model: opus` | 중간 | 세션이 opus보다 강할 때 downgrade. `cost_class: low`인데 opus 핀이라 내부 모순도 있음 |
| `plugins/quality-gates/agents/pr-understanding-builder.md` | `model: opus` | 중간 | 동일 |
| `plugins/quality-gates/agents/test-scope-validator.md` | `model: sonnet` | 중간 | 분류 작업이라 경량이 정당할 수 있음 — 판단 필요 |

**주의 (혼동 금지)**: 메모리 *"Respect upstream model hardcoding"* 은 **다른 플러그인의** 에이전트를 dispatch할 때 그쪽 핀을 wrapper로 우회하지 말라는 규칙이다. 여기서 하는 일은 **자기 플러그인 소유 에이전트의 핀을 `inherit`으로 고치는 것**이므로 그 규칙과 충돌하지 않는다 — 오히려 그 규칙이 존중하라고 한 대상을 정상화하는 것이다.

### 3.2 조사 도구 결핍

| 파일 | 현재 `tools:` | 의심 |
|---|---|---|
| `plugins/spec-distill/agents/spec-reviewer.md` | `Read, Grep, Glob, WebFetch` | `WebSearch` 부재 — URL을 열 수는 있는데 찾을 수는 없는 비대칭 |
| `plugins/spec-distill/agents/coverage-mapper.md` | `Read, Grep, Glob` | 커버리지 차원을 제안하는데 landscape 근거를 못 찾음 |
| `plugins/quality-gates/agents/security-reviewer.md` | `Read, Grep, Glob` | 취약점 패턴·CVE를 못 찾음. 보안 리뷰어에게 웹 부재가 정당한지 검토 |
| `plugins/quality-gates/agents/adversarial.md` · `artifact-critic.md` · `artifact-adversarial.md` | `Read, Grep, Glob` | 동일 계열 |

**유지 예외**: `pr-understanding-builder`의 `tools: Read`(inert)는 억제가 아니라 설계다 — 읽지 않는 생성기라는 것이 그 컴포넌트의 정체.

### 3.3 상한·예산

| 위치 | 현재 | 판단 필요 |
|---|---|---|
| `plugins/spec-distill/scripts/web_budget.py` | `SWEEP_CAP = 4` · `SESSION_CAP = 8` | 인터뷰 조사 깊이의 천장. AP9/AP16 fan-out 가드로 정당화돼 있으나, landscape 품질이 인터뷰의 핵심 값이라 **상한이 값을 깎는 쪽일 수 있다.** 사용자 판단 필요 — 상향? 사용자 승인 게이트로 전환? |
| `plugins/spec-distill/skills/conducting-interview/SKILL.md` `probe_budget` | base cap 12 + `raise-cap` override | **유지 쪽** — 실재하는 루프의 상한이고 사용자가 ①계속으로 올릴 escape hatch가 있음 |
| `confirm_repost_count` 상한 2 | | **유지** — 실재 루프 + Unbounded-autonomy 가드 |
| `reviewing-spec` re-review cap 5 | | **유지** — 수렴 실패 감지 |

### 3.4 `CLAUDE.md` · philosophy — 규약화된 억제 (사용자판단 비중 높음)

| 위치 | 문구 | 왜 의심스러운가 |
|---|---|---|
| `CLAUDE.md:43` · philosophy `:63` | *"`cost_class: high`는 지출 전 `AskUserQuestion` 승인 게이트 필수. Fan-out factor N ≥ 5는 hard review 게이트"* | 비용 동의(P17)라는 정당한 목적이 있으나, **실질 효과는 6개 이상이 필요한 작업을 억제**한다. 승인 게이트로 남길지 / 상한 프레임을 뺄지 판단 필요 |
| `CLAUDE.md:68` · philosophy `:96` | *"Subagent spray — 선언 없는 fan-out ≥ 5; **single-agent를 default로**"* | 앞부분("선언 없는")은 정당하지만 뒷부분은 병렬 탐색에 대한 편향을 규약으로 못 박는다 |
| philosophy `:55` · `:99` | *"max-iter cap + repeat 감지 + escape hatch와 함께 shipping"* | 실재 루프에는 정당(유지). 다만 **단일 호출을 루프로 오분류**해 상한을 씌운 파생 사례가 있는지 확인 |
| philosophy `:11` | *"모델 신뢰만으로는 부족하다"* | Law 1 문맥에선 정당(구조 게이트). 다른 영역으로 확대 인용된 곳이 있는지 확인 |

**철학 doc은 자기모순 상태다** — `:75`가 *"load-bearing일 때만 정당"* 이라 쓰면서 `:63`·`:96`은 load-bearing 판정 없는 일반 상한을 규약화한다. 이 긴장을 `:75` 쪽으로 정렬한다.

### 3.5 메모리

`grep -rl "상한\|cap\|sonnet\|opus\|하드코딩\|억제\|결정론"` 로 20개 파일이 걸린다. 대부분은 *사실 기록*(무엇을 만들었나)이라 무해하다. 실제 대상은 **지시형 메모리**:

- 억제를 *하라고* 지시하는 `feedback` 메모리 → 제거 또는 수정.
- 억제를 *기록한* `project` 메모리 → 이력이므로 유지. 단 그 상한이 이번 사이클에 제거되면 해당 메모리에 한 줄 정정.
- `MEMORY.md` 인덱스 한 줄도 같은 커밋에서 동기화.
- **반드시 보존할 메모리**: `harness-lightness-trust-the-model-over-over-determinism` · `devbrew designs default to lightness` · `feedback_harness_is_means_not_end` — 이 작업의 근거다.
- 메모리 지침대로 *틀린 것으로 판명된 메모리는 삭제*한다. 중복 생성 말고 기존 파일을 수정한다.

### 3.6 이빨 없는 체크

전수 조사 대상. 판별법: **"이 검사를 통과시키는 데 필요한 것이 검사 대상 자신이 쓰는 한 줄인가?"** 그렇다면 이빨이 없다. 이미 알려진 사례 — `check_brief.py`의 `evidence: S<N>`은 앵커의 *존재*만 보고 요약이 그 원문을 실제로 뒷받침하는지는 검증하지 않는다(Spec A가 이 한계를 명시하고 V9 수동 검증으로 분리했다 — **이건 올바른 처리의 선례**). 같은 클래스인데 한계를 명시하지 않은 곳을 찾는다.

---

## 4. 하지 말 것

- **`tools:` allowlist를 denylist로 바꾸지 말 것** — allowlist는 공간에, denylist는 *시간*에 fail-open이다(내일 추가될 도구를 오늘 열거할 수 없다). 웹 도구를 *추가*하는 것과 allowlist 자체를 포기하는 것은 다르다.
- **리뷰어에게 `Write`/`Edit`/`Bash`를 주지 말 것** — 능력 확장으로 보이지만 Law 2 위반이다.
- **`Monitor`를 추가하지 말 것** — 이름만 다른 셸 + `wss://` egress다.
- **격리를 억제로 오분류하지 말 것** — brief-critic의 payload-only, readback의 기준 무제공, pr-understanding-builder의 inert `Read`는 전부 실험 설계다.
- **한 번에 다 고치지 말 것** — 모델 핀 → 도구 표면 → 상한 순으로 갈라서 각각 리뷰받는다. 특히 `web_budget.py` 상한은 사용자 결정 사항이므로 코드 변경 전에 물어본다.

---

## 5. 산출물

1. **전수 열거 표** — 후보 / 파일:줄 / 분류(유지·제거·사용자판단) / 근거 한 줄. 애매한 것은 반드시 *사용자판단*으로.
2. **제거 커밋** — 분류가 명확한 것만. 플러그인을 건드리면 같은 커밋에 `plugin.json` SemVer bump + `CHANGELOG.md`(필수 — devbrew 규약).
3. **사용자 결정 대기 목록** — 특히 `web_budget.py` 상한.
4. **회귀 락** — `model: sonnet`/`model: opus` 리터럴이 다시 들어오는 것을 막는 테스트. 단 **버전 리터럴 핀 함정 주의**: `model: inherit`을 assert하는 락은 body-unique 문구로 걸고 mutation으로 이빨을 증명한다(헤더·주석에만 있어도 통과하는 락은 가짜).
5. **철학 doc 반영 여부 판단** — 이 판별 기준(유지 vs 제거)이 기존 원칙에 흡수되는지, 아니면 새 항목이 필요한지. devbrew의 default는 **기존 원칙 흡수**다.

---

## 6. 검증

- **제거의 효과가 실재하는지**: `model: inherit`으로 바꾼 뒤 실제로 세션 모델을 상속하는지 dispatch로 확인(자기보고 신뢰 금지 — 트랜스크립트에서 확인).
- **도구 추가의 효과**: 추가한 `WebSearch`를 에이전트가 실제로 호출할 수 있는지 1회 dispatch로 실측. 프론트매터에 적혔다는 것이 런타임 반영의 증거는 아니다(레지스트리 스냅샷 함정 — 세션 재시작 필요할 수 있음).
- **Law 2 무손상**: 변경 후 전 리뷰어 에이전트의 `tools:`에 쓰기·실행 도구가 없음을 기계 검증.
- **기존 스위트 green**: `plugins/*/tests/`. baseline을 먼저 캡처할 것 — main에 stale red가 있다.

---

## 7. 자매 축 — 함께 또는 뒤이어

**devbrew 전역 모듈화** (사용자, 2026-07-26: *"스크립트, 스킬 등 모듈화 하는게 devbrew전역에서 진행되어야 하는 부분"*). 큰 `SKILL.md`·다책임 스크립트를 책임 단위로 가르고 기존 파일엔 진입 한 줄만 남기는 작업. **이 sweep과 다른 축이다** — 억제 제거는 *규칙의 양*을 줄이고, 모듈화는 *책임의 배치*를 고친다. 서로 블록하지 않으므로 병행 가능. 메모리 `devbrew-modularize-scripts-and-skills-globally` 참조.

---

## 8. 참고 (읽을 것)

- 메모리 `harness-lightness-trust-the-model-over-over-determinism` — 이 작업의 근거 원칙과 case study
- 메모리 `devbrew designs default to lightness` — 자매 원칙(철학 doc에 새 P# 자제)
- 메모리 `Respect upstream model hardcoding` — §3.1의 혼동 금지 항목
- 메모리 `Workflow의 agent()엔 tool scoping이 없다` — allowlist가 시간에 대해 갖는 성질, 도구 목록 census 방법
- 메모리 `락의 PASS는 이빨의 증거가 아니다` / `green-expected 락은 mutation 필수` — §5의 회귀 락 작성법
- `docs/philosophy/devbrew-harness-philosophy.md` — Structural Mechanisms
- `plugins/plugin-audit/agents/*.md` — 올바른 패턴의 참조 구현
