# dispatch 락 mutation 실행 기록 — 2026-08-23

대상: `shared/tests/test_dispatch_disposition.sh` (6축 — A①②③④·B·C). 매 실행
`PYTHONDONTWRITEBYTECODE=1`. 실행 셸: `GNU bash, version 3.2.57(1)-release
(arm64-apple-darwin25)`. locale: `LANG=C.UTF-8` / `LC_CTYPE=C.UTF-8`.

## 앵커 번호 부여

18개 앵커를 코퍼스 정렬 순서(`sorted(set(corpus))`, 파일 경로 알파벳순 → 파일 내 줄 오름차순)로
1~18 번호를 매겼다 — 계획 문서가 참조하는 `#N`이 이 순서와 정합함을 M1(#18 →
`reviewing-spec/SKILL.md`)·M10(#16 → axis B 6→5/C 12→13)·M14b(#12/#13의 정확한 dispatch
줄 `:254`/`:269`)로 교차 확인했다.

## 양성 대조 (Step 1) — 먼저 확인

```
git status --porcelain   # 비어 있음 확인
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_dispatch_disposition.sh; echo "rc=$?"
```

관측: `rc=0`, `Total: 17 | Pass: 17 | Fail: 0`. 계측기 자신이 정상 — 이후 RED 는 증거다.

## M1~M18(+M8b) 관측

| # | 기대 | 관측 | 판정 |
|---|---|---|---|
| M1 | 축 A① RED, `reviewing-spec/SKILL.md` 가 메시지에 등장 | `✗ 축 A① 앵커 수(17) == dispatch 수(18)` (expected 18 / actual 17) **+** `✗ 축 A② … actual: plugins/spec-distill/skills/reviewing-spec/SKILL.md:64(spec-reviewer)->0개`. 파일명은 A①이 아니라 **A②** 메시지에 등장. rc=1, `Pass: 15 Fail: 2` | ✓ (관측 기준 자체는 충족 — 어느 축이 나르는지는 사실대로 기록) |
| M2 | 축 A④ RED, `서식 위반` | `✗ 축 A④ … actual: plugins/quality-gates/skills/quality-pipeline/SKILL.md:367 서식 위반`. rc=1, 16/17 | ✓ |
| M3 | 축 B RED, 교체한 경로가 메시지에 등장 | `✗ 축 B … actual: …/reviewing-brief/SKILL.md:288 -> plugins/spec-distill/scripts/state_path.py 가 adjudication 을 import 하지 않는다`. rc=1, 16/17 | ✓ |
| M4 | 축 B RED (동상) | `✗ 축 B … actual: …/reviewing-brief/SKILL.md:288 -> plugins/spec-distill/scripts/merge_brief_review.py 가 adjudication 을 import 하지 않는다`. rc=1, 16/17 | ✓ |
| M5 | 축 A① RED, `zz-probe` 가 메시지에 등장 | `✗ 축 A① 앵커 수(18) == dispatch 수(19)` (숫자만, 이름 없음) **+** `✗ 축 A② … actual: …/conducting-interview/SKILL.md:401(zz-probe)->0개` (이름 여기 등장). rc=1, 15/17 | ✓ (M1과 동형 — 이름은 A①이 아니라 A②가 나른다) |
| M6 | §5.1⑤ dispatch-0건 RED, `spec-reviewer-x` + `0건` | `✗ dispatch 0건인 에이전트가 없다 … actual: spec-reviewer-x` (라벨 자체에 "0건" 포함) **+** 축 A① 도 부수적으로 RED(18 vs 17, dispatch 가 17건으로 줄어서). rc=1, 15/17 | ✓ |
| M7 | 0건 RED 3개 이름, 총계는 15/15로 성립(vacuity 미발화) | `✓ 축 A① 앵커 수(15) == dispatch 수(15)` (그대로 GREEN) **+** `✗ dispatch 0건인 에이전트가 없다 … actual: audit-refuter,plugin-auditor,smoke-probe`. rc=1, 16/17 | ✓ — 계획이 예견한 "총계 등식은 깨지지 않는다"가 정확히 재현됨 |
| M8a | 락 자기 관측 RED, 「출력에 빈 문자열」(가설 A) | **셋째 결과**: assert_eq 호출 자체에 도달하지 못하고 스크립트가 죽었다 — `shared/tests/test_dispatch_disposition.sh: line 281: a1_anch<0xEA>: unbound variable` (마지막 통과 단언은 "인쇄 ④"). `set -u` 아래 `"...($a1_anch개) ..."` 를 bash 3.2 가 파싱할 때 `개`(UTF-8 3바이트 `EA B0 9C`)의 **첫 바이트(0xEA)만** 변수명의 일부로 먹고 `a1_anch<0xEA>` 라는, 한 번도 대입된 적 없는 변수를 참조해 즉시 크래시했다(hexdump로 확인: `61 31 5f 61 6e 63 68 ea 3a` = `a1_anch` + `0xEA` + `:`). rc=1 | ✗ — 예견된 두 가설(빈 문자열 vs 리터럴 `개`) 어느 쪽도 아니다. rc=1 자체(RED)는 맞지만 「빈 문자열」은 실제로 안 나왔다 |
| M8b | 락 자기 관측 RED, 비교값이 실제로 흔들리는지 | M8a 와 **바이트 단위로 동일한** 크래시 — 같은 파일:줄, 같은 `a1_anch<0xEA>: unbound variable`. 비교(`assert_eq` 인자)에 도달하기도 전에 죽어 축 A①이 실제로 흔들리는지는 **관측 불가**(스크립트가 그 지점 이전에 죽음). rc=1 | ✗ — 동일 사유. 「비교값 변형의 효과」를 측정하려던 목적이 셸 파싱 실패로 선점당함 |
| M9 | GREEN, `PRINT_2_dispatch 18` 유지 | `Total: 17 | Pass: 17 | Fail: 0`, rc=0. 별도 raw 실행으로 `PRINT_2_dispatch 18` 확인, `--emit-scanned` 38개 경로에 `reviewing-spec/SKILL.md` 그대로 존재 | ✓ |
| M10 | GREEN, `PRINT_5_axis B` 6→5, `C` 12→13 | `Total: 17 | Pass: 17 | Fail: 0`, rc=0. raw 실행: `PRINT_5_axis B 5` / `PRINT_5_axis C 13` (기준선은 `B 6` / `C 12`로 별도 확인), `PRINT_2_dispatch 18` 불변 | ✓ |
| M11 | 축 C RED, 리터럴이 메시지에 등장 | `✗ 축 C … actual: …/reviewing-brief/SKILL.md:197 disclosure='존재하지않는채널명' 가 앵커-제외 본문에 없다`. rc=1, 16/17 | ✓ |
| M12 | 축 A④ RED(서식/누락), 축 C 아님 | `✗ 축 A④ … actual: …/publishing-pr-understanding/SKILL.md:128 disclosure= 누락 (consumer=human)`. 축 C 는 GREEN 유지. rc=1, 16/17 | ✓ |
| M13 | 축 A③ RED, 두 이름 동시 귀속 | `✗ 축 A③ … actual: plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:195->adversarial+artifact-adversarial`(계획 문서는 `:194`를 지목했으나 실제 dispatch 줄은 195 — `Agent({`가 194, `subagent_type:` 이 195). **부수 효과**: 같은 줄이 두 이름으로 중복 계수되어 축 A①도 RED(18 vs 19). rc=1, 15/17 | ✓ (핵심 메커니즘 정확 재현, 줄 번호만 1 차이) |
| M14a | 축 A① RED, 17 ≠ 18 | `✗ 축 A① 앵커 수(17) == dispatch 수(18)`(expected 18 / actual 17). 부수로 축 A②도 RED(`:254(coverage-mapper)->0개`). rc=1, 15/17 | ✓ |
| M14b | 축 A② 단독 RED, `:254` 0개 · `:269` 2개 | `✓ 축 A① 앵커 수(18) == dispatch 수(18)`(GREEN 유지) **+** `✗ 축 A② … actual: …/conducting-interview/SKILL.md:254(coverage-mapper)->0개|…/conducting-interview/SKILL.md:269(blind-spot-prober)->2개` — 계획 문서의 줄 번호(254/269)와 **정확히 일치**. rc=1, 16/17 | ✓ |
| M15 | 축 A④ RED(경로 실재), 경로가 메시지에 등장 | `✗ 축 A④ … actual: plugins/plugin-audit/scripts/audit-workflow.js:19 경로 미실재 consumer=plugins/plugin-audit/scripts/없는파일.js`. rc=1, 16/17 | ✓ |
| M16 | 축 A④ RED(닫힌 어휘), 값이 메시지에 등장 | `✗ 축 A④ … actual: …/runtime-gate.md:260 닫힌 어휘 밖 consumer=maybe`. rc=1, 16/17 | ✓ |
| M17 | 인쇄⑤ 축 B·C RED | `✗ 인쇄 ⑤ 축 B 대상 수`(패턴 불검출) **+** `✗ 인쇄 ⑤ 축 C 대상 수`(동상). rc=1, 15/17 | ✓ |
| M18 | 인쇄④ RED | `✗ 인쇄 ④ 에이전트별 dispatch 수`(패턴 불검출, `PRINT_4_per_agent` 줄 자체가 출력에서 사라짐). rc=1, 16/17 | ✓ |

매 mutation 후 `git checkout -- <구체 경로>`(M5 는 추가로 `rm`)로 복원했고, 복원 직후
`git status --porcelain` + `git diff HEAD --stat` 둘 다로 잔존 0을 확인했다(로그 생략 —
전부 빈 출력). 전체 사이클 종료 후 최종 재확인: `git status --porcelain` 빈 값,
`PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_dispatch_disposition.sh` → `rc=0`,
`Total: 17 | Pass: 17 | Fail: 0`.

## M8a/M8b — 관찰: 현재 락은 정상, 계획서 서술의 정정

**현재 배포된(무변이) 락은 안전하다.** `shared/tests/test_dispatch_disposition.sh:281`은
`"축 A① 앵커 수(${a1_anch}) == dispatch 수(${a1_disp})"`로 이미 `${a1_anch}` 중괄호
표기를 쓴다 — 무변이 상태에서는 아래 크래시가 **발현하지 않는다.** M8a·M8b 는 이 락
소스 자체(계측기)에 인위적 편집(중괄호를 제거해 `$a1_anch개` 형태로 만드는 것)을 가해야만
성립하는 시나리오다 — M13(경계 규칙 자체를 변이)과 같은 「계측기 변이」 부류이지, 「지금
고쳐야 할 결함」이 아니다.

그럼에도 그 변이가 실제로 무엇을 내는지는 실측했다: 이 실행 환경(macOS 시스템 bash 3.2.57,
`LC_CTYPE=C.UTF-8`)에서 `set -u` 아래 `$a1_anch` 뒤에 공백 없이 멀티바이트 문자(`개`)가
오면, bash 의 바이트 단위 식별자 스캐너가 그 문자의 UTF-8 첫 바이트(`0xEA`)만 변수명의
일부로 편입해 `a1_anch<0xEA>` 라는 존재한 적 없는 변수를 참조하며 **스크립트 자체가
크래시한다.** M8a·M8b 는 같은 지점(281번째 줄)을 건드리므로 바이트 단위로 동일한 크래시를
낸다 — 비교값(`assert_eq` 1·2번째 인자)이 실제로 어떻게 흔들리는지는 이 환경에서 **한 번도
관측되지 않았다**(크래시가 먼저 일어나 그 지점에 도달하지 못했다).

**리포가 이미 알고 있었다.** 이 메커니즘은 새 발견이 아니라 기존 문서의 재확인이다 — 같은
footgun 이 이 리포에 이미 정확하게 적혀 있다:

- `plugins/quality-gates/tests/test_baseline_cache.sh:125-126`
  > `${strays}` 중괄호 필수 — `$strays개` 는 macOS bash 3.2 가 한글 `개` 의 선두 바이트를
  > 변수명에 포함시켜 이 분기가 실제로 발동하는 순간 unbound variable 로 죽는다.
- `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh:775-776`
  > `${n}` 중괄호 필수 — `$n회` 로 쓰면 macOS bash 3.2 가 한글 `회` 의 선두 바이트를
  > 변수명에 포함시켜 `set -u` 아래서 `"n?: unbound variable"` 로 죽는다 (실측).

M8 의 관측(선두 바이트만·`set -u`·unbound variable·크래시)은 이 두 주석과 정확히
일치한다. **정정이 필요한 쪽은 계획서의 Global Constraint 서술이었다** — 그것은 이
footgun 을 *"bash 가 `tot개` 를 변수명으로 읽어 조용히 빈 값을 낸다"* 로 적었는데 두
군데가 부정확하다: (a) 전체 이름이 아니라 **선두 바이트만** (b) 조용한 빈 값이 아니라
**크래시**. M8a·M8b 에게 제시됐던 두 가설(빈 문자열 / 리터럴 `개` 생존)은 이 부정확한
서술에서 파생된 것이라 **둘 다 틀렸다** — 위 테이블의 `✗` 판정은 이 어긋난 기대에 대한
정직한 기록으로 그대로 둔다.

**전수 스윕 결과 — 지금 고칠 대상이 리포에 없다.** `plugins/`·`shared/`의 모든 `*.sh`를
`\$[A-Za-z_][A-Za-z0-9_]*[가-힣]` 패턴으로 전수 grep한 결과 13건이 나왔고 **전부 주석**
이며, 이 footgun 패턴을 실행 코드로 갖는 인스턴스는 **0건**이다(위 두 인용도 이미 주석 —
경고문이지 살아있는 버그가 아니다).

**남기는 관찰 (사실·유용, 판정 아님).** 이 크래시 경로에서는 281행 이후의 단언들
(A②③④·B·C)과 `finish`의 `Total:` 요약 줄이 **실행되지 않는다** — `assert.sh`의 계약
(*"실패를 세고 계속 진행, 종료는 finish 가"*)이 이 경로에서만 깨진다. `rc=1`이라
fail-closed 자체는 유지되므로 실질 위험은 낮지만, 출력만 훑는 사람에게는 「일부만 통과
했다」로 오독될 여지가 있다.

## 앵커 수 정정 (판정 없이 실측만)

계획 문서는 CHANGELOG Added 문면에 반영할 플러그인별 앵커 수를 `at 1 · pa 3 · qg 6 · sd 8`
로 제시했다. `grep -rEn '\*\*처분\*\*[[:space:]]+—'`로 각 플러그인 디렉토리를 직접 센 결과:

| 플러그인 | 계획 문서 제시값 | 실측값 |
|---|---|---|
| `agent-transparency` | 1 | **1** (일치) |
| `plugin-audit` | 3 | **3** (일치) |
| `quality-gates` | 6 | **7** (불일치) |
| `spec-distill` | 8 | **7** (불일치) |

합계는 양쪽 다 18로 같다 — quality-gates 와 spec-distill 사이에서 앵커 하나가 잘못
분배되어 있었을 뿐이다(quality-gates 실제 7곳: `critiquing-artifacts/SKILL.md:137,196` ·
`publishing-pr-understanding/SKILL.md:128` · `quality-pipeline/SKILL.md:367,379` ·
`quality-pipeline/references/runtime-gate.md:260,707`; spec-distill 실제 7곳:
`conducting-interview/SKILL.md:256,272,324` · `reviewing-brief/SKILL.md:197,288,442` ·
`reviewing-spec/SKILL.md:65`). CHANGELOG 에는 실측값(qg 7 · sd 7)을 반영했다.

## PR3 버전 (실측 확인 후 bump)

계획 문서는 `spec-distill 0.34.1 → 0.34.2`를 제시했으나 실제 PR2 이후 값은 `0.35.0`이었다
(중간에 다른 PR이 minor bump를 이미 반영). 아래는 실측 「현재」 확인 후의 bump:

| 플러그인 | 실측 현재 | PR3 후 |
|---|---|---|
| `agent-transparency` | 0.2.3 | 0.2.4 |
| `plugin-audit` | 0.6.1 | 0.6.2 |
| `quality-gates` | 4.3.1 | 4.3.2 |
| `spec-distill` | 0.35.0 | 0.35.1 |

전부 patch bump(앵커는 새 surface 가 아님).

## 회귀 확인 (커밋 전)

- `shared/tests/test_adjudication_behavior.sh`: 16/16
- `shared/tests/test_assert_behavior.sh`: 32/32
- `shared/tests/test_changelog_integrity.sh`: 33/33 (신규 항목 4개 추가 후에도 단언 수는 33 유지 — "33 또는 그 이상" 충족)
- `shared/tests/test_copy_of_contract.sh`: 163/163
- `shared/tests/test_no_new_duplication.sh`: 3/3
- `shared/tests/test_presence_corpus_behavior.sh`: 14/14
- `shared/tests/test_skill_reference_pointers.sh`: 16/16
- 락 자신 `test_dispatch_disposition.sh`: 17/17, `bash -n` rc=0
- 커밋 직전 `git status --porcelain`: mutation 잔존 0 (버전 bump 8파일만 diff)
