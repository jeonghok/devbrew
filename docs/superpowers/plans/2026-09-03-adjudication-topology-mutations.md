# M6 락별 귀속 변이 + M9 seam 락 이빨 — Task 15 실행 기록

## 목차
- [착수 상태](#착수-상태)
- [변이표 (μ1~μ12)](#변이표-μ1μ12)
- [μ2 — L1 의 경계 (Step 5)](#μ2--l1-의-경계-step-5)
- [기대와 어긋난 항목 — 원인 분석](#기대와-어긋난-항목--원인-분석)
- [M9 seam 락 이빨 생존 (Step 6)](#m9-seam-락-이빨-생존-step-6)

## 착수 상태

- HEAD: `bc6fa6bb670bd82a4f0e928e82146b8001887ff5`, 트리 깨끗.
- 양성 대조 (변이 전, 전부 Fail: 0): `test_adjudication_wiring.sh`(15) ·
  `test_adjudication_consumed.sh`(6) · `test_agent_input_slots.sh`(12) ·
  `test_runner_disposition.sh`(34) · `test_dispatch_name_defined.sh`(6) ·
  `test_skill_drop_notice_consumed.sh`(14) ·
  `test_review_dispatch_disposition.sh`(11, μ11 의 훅 테스트).
- 각 변이마다 건드린 파일을 `# guards:` 선언 전수 스윕(fnmatch)으로 매칭해
  나온 락 전부를 돌렸다 — 지정된 락 하나만 돌리지 않았다.
- 매 변이 후 `git checkout -- <파일>` + `git status --short` 빈 출력을 확인했다
  (아래 표의 "원복" 열은 전부 확인됨).

## 변이표 (μ1~μ12)

| # | 무엇을 바꿨나 | 축 | 기대 락 | 실제 RED 락 | 그 하나만? | 메시지가 자리를 이름으로 대는가 | 원복 |
|---|---|---|---|---|---|---|---|
| μ1 | `synthesize_findings.py:333` `ledger.reject(finding_id(f), "adversarial 기각")` → `pass` (같은 `if` 본문, `continue` 는 유지) | 삭제 | L1 | **L1** RED(14/15) + `test_synthesize_disposition.sh` RED(5/6, "기각이 세어진다") | 아니오 — 둘. 다만 브리프 규칙("다른 락도 함께 RED 는 정상")대로 지정 락(L1)이 RED 라 통과 | 예 — `미배선: plugins/quality-gates/scripts/synthesize_findings.py:334 continue in apply_verdicts` (파일:줄:함수) | 확인 |
| μ2 | 같은 자리를 `ledger.accept(finding_id(f))` 로 교체(reject→accept, 인자 시그니처도 accept(item) 에 맞춤) | 형태 | 없음(L1 경계 확인용) | **없음** — L1 15/15 GREEN 유지. `test_synthesize_disposition.sh` 만 RED(5/6, "기각이 세어진다") | 해당 없음(기대가 "GREEN") | 해당 없음 | 확인 |
| μ3 | `render_disposition.py` `disposition_lines()` 의 `plumbing = (...)` + `line2 = ("**배관 손실:**...)` 2문장을 `line2 = ""` 로 교체 | 삭제 | L2 | **없음** — L2 6/6 GREEN 유지(`test_adjudication_behavior.sh`·`test_no_new_duplication.sh`·`test_guards_coverage_bidirectional.sh` 도 GREEN) | — (기대와 다름, 아래 원인 분석 참조) | — | 확인 |
| μ4 | `adjudication.py` `Ledger.report()["counts"]` 에 `"foo": 0` 추가 | 추가 | L2 | **L2** RED(2/6) | 예 — `test_adjudication_behavior.sh`·`test_no_new_duplication.sh` 는 GREEN 유지 | 예 — `UNCONSUMED plugins/quality-gates/scripts/synthesize_findings.py: foo` 등 소비자별·키별로 명명 | 확인 |
| μ5 | `tools/adjudication/check_wiring.py` `EXEMPT` 에 `("plugins/fake/scripts/nope.py", 1): "인용 없는 임의 면제 ..."` (C6 리터럴 없음) 추가 | 추가 | L1 | **L1** RED(13/15) | 예 | 예 — `낡은 면제: plugins/fake/scripts/nope.py:1` (면제 크기 18 로 증가도 함께 보고) | 확인 |
| μ6 | `plugins/agent-transparency/agents/transcript-reader.md` 의 `input_slots:` 블록 전체 삭제 | 삭제 | L3 | **L3** RED(11/12, `no_declaration=1`) | 예 — `test_dispatch_name_defined.sh`·`test_dispatch_disposition.sh`·`test_no_new_duplication.sh` GREEN | **아니오** — `no_declaration` 카운트만 오르고 어떤 agent 인지 이름을 대는 출력이 없다(아래 원인 분석) | 확인 |
| μ7 | `security-reviewer.md` 의 `diff_scope` 슬롯 `kind: task` → `kind: prior_verdict` | 반전 | L3 | **L3** RED(11/12) | 예 — T4-2 GREEN | 예 — `PROBLEM forbidden_kind quality-gates:security-reviewer @ plugins/quality-gates/agents/security-reviewer.md <diff_scope> kind=prior_verdict` | 확인 |
| μ8 | 같은 파일 `project_dir` 슬롯 `var: PROJECT_DIR` → `var: PRIOR_VERDICT` (kind 는 `task` 유지) | 형태 | L3 (`suspect_var`) | **L3** RED(11/12) — 단 `suspect_var` 와 `var_mismatch` **둘 다** 발화 (아래 참고) | 예(락 파일 단위로는 L3 하나) — T4-2 GREEN | 예 — `PROBLEM suspect_var … var=PRIOR_VERDICT 인데 kind=task …` + `PROBLEM var_mismatch … 선언=PRIOR_VERDICT 전달=PROJECT_DIR` | 확인 |
| μ9 | `run_codex_reviewer.sh` 의 `**처분** — consumer=orchestrator · fail-open · disclosure=banner` 에서 `· disclosure=banner` 삭제 | 삭제 | L4 | **L4** RED(33/34) | 예 — `test_dispatch_disposition.sh`·`test_codex_backward_compat.sh`(117개 qg 스위트 포함, 무거운 형제) 전부 GREEN | 예 — `run_codex_reviewer.sh: 앵커가 disclosure= 를 밝힌다` | 확인 |
| μ10 | `quality-pipeline/SKILL.md` 끝에 `` `quality-gates:no-such` `` 를 백틱+콜론 형태로 추가 | 추가 | T4-2 | **T4-2** RED(5/6) | 예 — `test_skill_reference_pointers.sh`·`test_agent_input_slots.sh`·`test_dispatch_disposition.sh` GREEN | 예 — `DANGLING plugins/quality-gates/skills/quality-pipeline/SKILL.md:956 quality-gates:no-such` | 확인 |
| μ11 | `review-dispatch.py:804` `L.hold(str(cand.path), "판정자 부재: ...")` 삭제(그 자리 `decision:"block"` 은 그대로 유지) | 삭제 | L1 + 훅 테스트(`test_review_dispatch_disposition.sh`) | **없음** — L1 15/15, L2 6/6, `test_review_dispatch_disposition.sh` 11/11 전부 GREEN | — (기대와 다름, 중대 — 아래 원인 분석 참조) | — | 확인 |
| μ12 (M9) | `quality-pipeline/SKILL.md` 의 "**Not-clean notice override**" 지시 문단(556~571줄) 전체 삭제 | 삭제 | `test_skill_drop_notice_consumed.sh` (그 락 자신) | **그 락 자신** RED(Total 14, Fail 4: b2·d0·d3·d5) | 예(파일 단위로는 그 락 하나) | 부분적 — b1(정확히 겨눈 단언)은 decoy 로 인해 GREEN, 대신 b2/d3/d5 가 잡음(아래 원인 분석) | 확인 |

## μ2 — L1 의 경계 (Step 5)

μ2 가 예측대로 어느 락도 RED 로 만들지 않아 `shared/tests/test_adjudication_wiring.sh`
상단에 아래 한 줄 주석을 추가했다(코드/판정 로직 변경 없음, 문서화만):

```
# 이 락은 처분의 «유무»를 재고 «종류」는 재지 않는다. reject 를 accept 로
# 바꾸면 통과한다 — 종류의 정합은 처분 행렬 테스트
# (quality-gates/tests/test_synthesize_disposition.sh) 가 잰다.
```

추가 후 재실행해 15/15 GREEN 유지를 확인했다(주석만 추가했으므로 판정에 영향 없음).

## 기대와 어긋난 항목 — 원인 분석

### μ3 — L2 가 `render_disposition.py` 안의 「본문 삭제」를 못 본다

`disposition_lines()` 에서 `plumbing`/`line2` 문장을 전부 지워도
`test_adjudication_consumed.sh` 는 GREEN 을 유지했다. 원인은 이 락의 폐포가
**파일 단위**라고 스스로 명시한 설계(주석: "폐포는 «파일 단위»다 — 호출 그래프를
안 본다")의 실제 귀결이다:

- 요구 키(`accepted`/`rejected`/`held`/`absorbed`/`coerced`/`sources_failed`/
  `suppressed`/`unknown_counts`) 전부가 **같은 파일의 다른 함수**
  `disposition_report()`(51~71줄)에도 독립적으로 첨자로 나타난다.
- `_consumed_names()` 는 파일 전체를 `ast.walk` 해서 첨자 리터럴을 모으므로,
  `disposition_lines()` 안에서 무엇을 지우든 `disposition_report()` 가 같은
  키를 계속 대면 그 파일을 closure 에 포함하는 **모든** 소비자가 "다 읽었다"로
  판정된다.
- 즉 이 축(«한 함수 안에서 실제 표시되는 문구가 지워졌는가»)은 이 락의
  설계가 스스로 인정한 사각지대("이 락이 못 보는 것: 키 이름이 렌더 코드에
  «적혀 있다»는 것이지 그 값이 사용자 화면까지 «간다»는 것이 아니다") 바로
  그것이다 — 다만 그 사각지대가 "화면 도달"뿐 아니라 "같은 파일 안 다른
  함수가 대신 키를 대면 폐포 전체가 통과한다"는 더 넓은 형태로 실제로
  확인됐다.
- 대안으로 `render()`(synthesize_findings.py:473, `disp_line, plumb_line,
  advisories = disposition_lines(...)` 를 받아 `out` 리스트에서 `plumb_line`
  을 빼는 변이)도 시도했으면 같은 결과였을 것이다 — 이 락의 문서 자신이
  "값이 화면까지 가는지는 M11/M12 가 잰다"고 명시했으므로 별도로 실행하지
  않았다.
- **락을 고치지 않았다** — 브리프 지시대로 원인만 특정해 보고한다.

**수정 라운드 2 정정 (C1) — 위 "시도했으면 같은 결과였을 것이다"는 예측이지
측정이 아니었다, 그리고 그 예측의 실제 뜻은 "볼 것 없다"가 아니라 "여기가
열려 있다"였다.** 코디네이터가 직접 재현: `render()` 에는 `disposition_lines()`
호출이 정확히 둘뿐이다(:482 findings 가 빈 clean 분기, :532 kept>0 분기 —
`main()` 은 `render()` 를 한 번만 부르므로 제3의 자리는 없다, 도출로 확인).
`test_synthesize_disposition.sh` 의 여섯 assert_grep 은 findings.yaml 이
실채택 항목을 남겨 **:532 분기만** 태웠다 — :482(clean) 분기에서 `plumb_line`
을 지우면 이 파일을 코퍼스로 갖는 락 8개 전부 GREEN, 같은 제거를 :532 에서
하면 5/6 RED(양성 대조). 즉 두 렌더 분기 중 하나만 잠겨 있었고, 잠기지 않은
쪽이 하필 "배관 손실이 사라져도 화면은 clean 으로 읽히는" 가장 위험한
자리였다. `test_synthesize_disposition.sh` 에 :482 분기 전용 fixture(malformed
+ 미판정 + 억제 + 기각을 함께 내는 kept=0 시나리오)와 값 검사 넷을 추가해
닫았다 — 두 분기 각각을 지우는 양성 대조로 확인(각각 RED, 원복 후 GREEN).
상세: `plugins/quality-gates/tests/test_synthesize_disposition.sh` 의
"clean(kept=0) 렌더 분기" 절.

### μ11 — 가장 중대한 발견: `review-dispatch.py` 의 mandate-block 경로에서 처분 호출을 지워도 어떤 락도 못 잡는다

`L.hold(str(cand.path), ...)` (T5-2, dispatch 강제 block 직전 처분 호출)를
지웠는데 L1·L2·지정된 훅 테스트(`test_review_dispatch_disposition.sh`) 전부
GREEN 을 유지했다. 실제 훅을 실행해 확인한 원인은 **두 가지 독립된 구멍의
중첩**이다:

1. **정적 카운트 검사(훅 테스트 44~51줄)가 프로즈 오검출로 상쇄된다.**
   `nblock=$(grep -c '"decision": "block"')`, `ndisp=$(grep -cE '\.(hold|reject|
   source_failed|uncountable)\(')` 를 세어 `ndisp >= nblock` 만 확인하는데,
   이 파일 222번째 줄의 **설명 주석**("...누가 `L.reject(...)` 하나만 더해도
   공시가...")이 정규식 `\.reject\(` 를 우연히 만족시켜 실제 호출 하나가
   사라져도 `ndisp` 가 줄지 않는다(2→2). 이 파일의 헤더 주석이 스스로
   "「구현이 바뀐 뒤에도 «이 파일 자신의 설명 주석»이 우연히 그 문자열을
   담고 있어 단언이 계속 GREEN 이었다」"고 적어 둔 바로 그 종류의 결함이
   **다른 축(`reasons()` 문자열이 아니라 `ndisp`/`nblock` 카운트)에도** 그대로
   있다.
2. **실행 절(63~91줄)이 «라벨의 존재»만 재고 «값의 정확성»은 안 잰다.**
   `disposition_lines()` 는 `Ledger` 가 비어 있어도 `**처분:**`/`**배관 손실:**`
   라벨 두 줄을 무조건 렌더한다(포맷 문자열이 항상 실행되므로). 실제로 훅을
   실행해 확인한 출력:
   ```
   **처분:** 수용 0 · 기각 0 · 억제 0 · 흡수 0 · 미판정 0     (차단 아님)
   **배관 손실:** 0 · 셀 수 없음 0     (차단: 아니오)
   ```
   `L.hold()` 를 지웠으니 "미판정" 이 1 이어야 정상인데 0 으로 나온다 —
   `assert_grep "$REASON" '\*\*처분:\*\*'` 는 라벨 문자열만 보므로 값이
   틀려도 통과한다.
- 두 구멍이 겹쳐 L1(이 호출은 for-loop discard node 에 안 묶여 있어 애초에
  대상 밖)·L2(이 값도 render_disposition.py 파일 안 다른 곳에서 커버됨)·
  지정된 훅 테스트(위 두 구멍) 모두가 이 결손을 놓친다.
- **락을 고치지 않았다.** 두 파일(`test_review_dispatch_disposition.sh` 의
  정적 카운트 검사, 실행 절의 값 검증) 모두 조율자(나를 호출한 쪽)의 판단이
  필요한 강화 대상으로 보고한다.

### μ8 — suspect_var 를 단독으로 걸 수 없다(관측)

`var` 를 바꾸면 그 값이 실제로 dispatch 되는 자리(SKILL.md 의 heredoc 변수
치환)와도 어긋나 `var_mismatch` 가 함께 발화한다. 이것은 결함이 아니라 두
축(「이름이 판정을 시사하는가」와 「선언 var 와 실제 전달 var 가 일치하는가」)이
근본적으로 같은 필드(`var`)를 재는 데서 오는 자연스러운 결합이다 — 파일
단위 귀속(L3 하나)은 유지되므로 브리프의 "하나만인가" 기준은 통과했다.

## M9 seam 락 이빨 생존 (Step 6)

`test_skill_drop_notice_consumed.sh` 의 소비자 분기("Not-clean notice
override" 지시 문단, `quality-pipeline/SKILL.md:556-571`)를 통째로 지운 결과:

```
Total: 14 | Pass: 10 | Fail: 4   (b2 · d0 · d3 · d5 RED)
```

**기대(RED)를 만족한다** — Task 12 Step 4 의 갱신이 이빨을 잃지 않았다. 다만
세부적으로 하나 더 발견했다: 이 삭제를 "정확히 겨눈" 단언 `b1`("step 4.5가
drop 공지 문구를 소비한다")은 **GREEN 으로 남았다** — 지시 문단 뒤에 남아있는
"Why the key is the marker…" 근거 단락이 `dropped as malformed` 문구를
예시로 다시 인용하기 때문에, `b1` 이 검사하는 윈도우(Step 4.5 전체)에서 그
decoy 인용이 b1 을 만족시킨다. 락 전체는 **다른** 단언들(b2 — "not clean"
지시 사라짐, d0/d3 — 지시부 앵커 자체가 사라짐, d5 — 마커 불일치)이 잡아서
Total 결과는 정확히 RED 다. 즉 "이빨이 있다"는 결론은 유지되지만, 그 이빨의
정확한 위치가 문서 저자의 의도(b1)와 실제 집행(b2/d0/d3/d5)이 어긋나 있다는
점은 기록해 둔다. **락을 고치지 않았다.**

## 원복 위생

12건(μ1~μ12) 전부 개별 `git checkout -- <파일>` 후 `git status --short` 빈
출력을 확인했다. μ11 검증을 위해 `/tmp/adjtopo/verify_work` 에 별도 git
스크래치 저장소를 만들어 훅을 실제 실행했고, 확인 후 삭제했다 — 이 리포
트리에는 어떤 흔적도 남지 않았다(같은 확인 절차 적용).
