# 테스트 기준

이 레포에서 테스트를 쓰거나 고치거나 지울 때 따른다. 아래 원문은 맷 포콕의 tdd skill 본문이다(고지: [`testing.NOTICE.txt`](testing.NOTICE.txt)). 위쪽과 원문이 다르면 위쪽이 앞선다.

## 목차

- [적용 범위](#적용-범위) · [좋은 테스트](#좋은-테스트) · [테스트할 자리](#테스트할-자리) · [쓰는 차례](#쓰는-차례)
- [글을 무는 확인](#글을-무는-확인) · [글자 대조 말고 쓰는 확인](#글자-대조-말고-쓰는-확인) · [망가뜨려 보기](#망가뜨려-보기) · [보안 갈래](#보안-갈래)
- [값 대비 비용](#값-대비-비용) · [새 테스트가 하지 않는 것](#새-테스트가-하지-않는-것) · [지우기 · 합치기 · 줄이기의 승인과 기록](#지우기--합치기--줄이기의-승인과-기록)
- 원문: [Test-Driven Development](#test-driven-development) · [Good and Bad Tests](#good-and-bad-tests) · [When to Mock](#when-to-mock)

## 적용 범위

이 레포를 개발할 때 쓰고 돌리는 테스트다 — `plugins/*/tests/` · `shared/tests/` · `tools/` 의 테스트. 플러그인이 다른 레포에 시키는 방식은 대상이 아니다.

## 좋은 테스트

- 바깥 경계로 동작을 확인한다 — 경계는 아래 표다.
- 기대값은 검사 대상과 다른 출처에서 온다(아는 글자 값 · 손으로 푼 예 · 설계문서).
- 가짜는 시스템 경계에만 둔다.

아래 원문의 말은 이 레포에서 이렇게 읽는다.

| 원문의 말 | 이 레포에서 |
|---|---|
| public interface · seam | 스크립트의 명령줄 · 종료 코드 · 표준 출력의 판결 줄 · 만든 파일, 훅이 내는 JSON, 모델이 읽는 글 가운데 행동을 정하는 문장(「글을 무는 확인」 절) |
| 「seam 을 적어 사용자에게 확인받는다」 | 설계문서의 `## 테스트할 자리` 절과 설계 승인(「테스트할 자리」 절) |
| system boundary(가짜를 두는 곳) | codex · gh · 헤드리스 claude · git 원격 · 시간 · 네트워크. 이 레포의 스크립트와 함수는 가짜로 바꾸지 않는다 |
| One logical assertion per test | 한 케이스가 한 동작이다. 한 파일에 케이스 여럿은 그대로 두고 준비물은 한 번 세워 나눠 쓴다(「새 테스트가 하지 않는 것」 절) |
| Horizontal slicing | 계획이 테스트를 통째로 먼저 싣는 꼴. 「쓰는 차례」 절이 닿는 데까지 푼다 |

## 테스트할 자리

테스트를 쓰기 전에 자리를 정한다.

- 설계문서에 `## 테스트할 자리` 절을 둔다. 표의 칸은 넷이다 — 자리(바깥에서 부르는 경계) · 확인할 동작 · 잡는 것과 못 잡는 것(한 줄) · 테스트 파일. 표의 머리는 이렇다.

  ```
  | 자리 | 확인할 동작 | 잡는 것 · 못 잡는 것 | 테스트 파일 |
  |---|---|---|---|
  ```

- 승인은 설계 승인에 얹힌다. 따로 묻지 않는다.
- 설계문서 없이 가는 일(가벼운 꼴)은 같은 표를 PR 본문에 싣는다. 한 문장으로 설명되는 변경(trivia)에는 해당 없다.
- 표에 없는 자리에 테스트를 더하는 것이 맞으면 더하고 이유를 PR 본문에 적는다.
- 테스트를 더하거나 고치지 않는 설계는 그 절에 「해당 없음 — 이유」 한 줄을 적는다. 절을 빼지 않는다.
- 전부를 테스트할 수는 없다. 자리는 중요한 길과 복잡한 로직에 둔다.

## 쓰는 차례

하나씩 쓴다 — 자리 하나의 테스트 하나를 쓰고, 실패를 보고, 그것을 통과시키는 만큼만 구현하고, 다음으로 간다.

- 계획이 테스트 코드를 미리 실었어도 과제 안에서는 하나씩 쓰고 돌린다.
- 구현하며 알게 된 것으로 계획의 테스트를 고치는 것은 계획 이탈이 아니다 — 고친 이유를 커밋에 적는다.
- 다듬기는 이 차례 밖(리뷰)이다.

## 글을 무는 확인

글자를 그대로 대조하는 확인은 행동을 정하는 문장에 둔다 — 아래를 다 만족할 때만이다.

- **어느 글인가.** 모델이 읽고 따르는 글이다 — skill 본문 · agent 정의 · reference · 깔아 주는 템플릿 · 규칙 문서(`CLAUDE.md` 와 그것이 가리키는 문서). 사람만 읽는 글(README · CHANGELOG · 설계 · 계획 기록)은 대상이 아니다.
- **어느 문장인가.** 지우거나 뒤집으면 모델이 하는 일이 달라지는 문장이다. 금지 문장과 절차의 걸음 문장이 여기에 든다. 이유 · 설명 · 예시 문장, 질문 표의 한 줄 전체, 보고 글의 첫 줄과 끝 문단은 들지 않는다.
- **어떻게 무는가.** 문장 전체가 아니라 그 뜻을 싣는 가장 짧은 낱말을 문다. 말을 다듬어도 뜻이 같으면 깨지지 않아야 한다.
- **판별.** 「이 확인이 깨지면 누구에게 무엇이 잘못되나」 를 한 문장으로 댈 수 있다. 못 대면 두지 않는다.

스크립트가 글자로 읽는 자리(판결 줄 · 키 이름 · 구분 줄)는 글이 아니라 동작이다 — 「좋은 테스트」 절을 따른다. 보안 갈래의 확인은 「보안 갈래」 절이 먼저다. 모델이 그 문장을 실제로 따르는지 보는 확인과 글자 대조 말고 글을 지키는 장치는 「[글자 대조 말고 쓰는 확인](#글자-대조-말고-쓰는-확인)」 절이다.

## 글자 대조 말고 쓰는 확인

글자 확인 말고 글을 지키는 장치와, 장치마다 맡는 글이다.

| 글 | 지키는 것 | 도는 곳 |
|---|---|---|
| 행동을 정하는 문장(금지 · 절차의 걸음) | 글자 확인 — 「글을 무는 확인」 절 그대로 | 스위트 |
| 그 가운데 아래 「쓰는 조건」 에 드는 것 | 실제 모델 평가 케이스 — 글자 확인에 더한다 | 손으로(「누가 언제」) |
| 문서 안의 실행 블록(펜스) | 코드 조각 실행 — 블록을 표지로 뽑아 실제로 돌린다. 본: `plugins/spec-distill/tests/test_ledger_wiring.sh` | 스위트 |
| 문서가 보이는 예시와 틀(출력 꼴 · JSON 예 · 가리키는 경로) | 구조 확인 — 예시를 그것을 읽는 코드에 먹이거나, 가리키는 것이 있는지 본다. 본: `plugins/plugin-audit/tests/test_preamble_schema_parity.py` · `shared/tests/test_charter_citations.sh` | 스위트 |
| 이유 · 설명 · 예시 문장, 사람만 읽는 글 | 리뷰. 테스트를 두지 않는다 | — |

가짜 응답은 쓰지 않는다 — 가짜 응답 도우미는 고정된 글을 그대로 돌려줄 뿐이라 모델이 글을 따르는지 재지 못한다.

글자 확인을 평가 케이스로 바꾸지 않는다. 평가는 손으로 돌 때만 지키므로 늘 글자 확인에 더한다. 글자에 묶여 자주 고치게 되는 확인은 「값 대비 비용」 의 넷째 줄대로 줄인다.

**쓰는 조건.** 아래를 다 만족할 때만 쓴다. 조건에 든다고 꼭 쓰는 것은 아니다 — 돈이 드는 확인이라, 쓸지는 그 문장을 지키는 값을 보고 정한다.

1. 행동을 정하는 문장이다(「글을 무는 확인」 의 판별).
2. 글자 확인만으로는 모자라다 — 아래 가운데 하나다.
   - 지우거나 뒤집으면 모델이 위험한 일을 하는 문장이라, 모델이 실제로 따르는지를 봐야 한다(보안 갈래의 문장 등).
   - 동작이 같은데 그 글자 확인을 고친 일이 거듭됐거나(근거는 커밋), 가장 짧은 낱말로 줄일 수 없어 문장 전체를 물고 있다. 줄일 수 있는 확인은 먼저 줄이고, 줄인 뒤에도 이 줄에 들면 평가를 더한다.
3. 행동이 사람의 답 없이 한 번의 실행에서 드러난다 — 부른 도구 · 만든 파일 · 마지막 글.
4. 대상이 플러그인의 글이다 — 평가 실행은 플러그인만 싣는다.

**케이스의 꼴.**

- 자리: `plugins/<플러그인>/tests/evals/<케이스 이름>/` — `prompt.md` · `case.yaml` · `graders/*.md` · 필요하면 준비 스크립트(`case.yaml` 의 `scaffold_script`). 준비 스크립트의 이름은 `.sh` 로 끝내지 않는다 — `tests/` 아래 실행 비트가 있는 `.sh` 는 차등 테스트가 테스트로 잡아 리뷰 트리에서 돌린다.
- `case.yaml` 의 `description` 에 지키는 글을 적는다 — 파일 경로와 문장의 뜻 한 줄. 그 파일을 고치는 사람이 경로로 찾는다.
- 채점기는 행동을 본다 — 도구 사용(`tool_used` · `tool_order`) · 만든 파일(`file_exists`) · 루브릭(`llm`). 마지막 글의 글자를 정규식으로 무는 채점기는 쓰지 않는다 — 말만 바꿔도 깨진다.
- 루브릭은 통과와 실패를 한 줄씩 또렷하게 쓴다.
- 「부르지 않았다」 처럼 없어야 하는 것을 보는 채점기만으로 지키지 않는다 — skill 이 그 걸음에 닿기 전에 멈춘 실행도 통과로 찍힌다. 짝을 둔다: 같은 skill 을 받는 꼴의 입력으로 불러 「불렀다」 를 보는 케이스를 함께 두고, 거절 케이스에는 옳은 이유로 멈췄는지를 보는 루브릭을 함께 둔다.
- 결과 폴더(`tests/evals/results/`)는 커밋하지 않는다.
- 지키는 문장이 없으면 결과가 달라지는 케이스(거절 케이스 쪽)는 그 문장을 지운 사본에서 실패하는 것을 한 번 본다(「망가뜨려 보기」 의 「그 밖에 새로 쓰거나 고친 확인」 줄과 같다). 짝 케이스도 같은 사본에서 함께 돌려 통과하는 것을 본다 — 통과하면 사본이 멀쩡하고 거절 케이스의 실패가 그 문장 때문이다. 사본에서 둘 다 실패하면 사본이 망가진 것이라 증거로 쓰지 않는다.

**돌리는 법.**

```
python3 tools/plugin-evals/run_evals.py <플러그인 폴더> [--case <글롭>] [--runs <n>] [--model <모델>] [--max-cost-usd <달러>]
```

- 이 레포의 플러그인 폴더와 그 사본에만 쓴다 — 확인 질문 없이 그 폴더의 준비 스크립트를 돌린다.
- 플러그인 폴더는 그대로(`plugins/<플러그인>`) 주면 된다 — 스크립트가 링크를 풀어 복사한 사본을 임시 폴더에 만들어 거기서 돌리고, 끝나면 사본을 지운다.
- 끝에 요약 한 줄을 낸다 — `plugin-evals: <통과|실패|부분> · 케이스 <통과>/<전체> · 실행 <n>회 · $<값> · <모델>`. 돌지 못했으면 — 돈 실행이 없을 때와 세션이 시작되지 않았을 때(돈 실행이 모두 0턴)도 — `plugin-evals: 돌지 못함 — <이유>` 이고 종료 코드는 0 이 아니다.
- 문장을 지운 쪽을 재려면 플러그인 폴더를 레포 밖에 링크를 풀어 복사하고(`cp -RL`), 사본에서 그 문장을 지우고, 그 사본을 `<플러그인 폴더>` 자리에 준다.

**누가 언제.** 케이스가 지키는 파일을 고치는 PR 에서 돌린다.

- 플러그인의 skill · agent · reference 를 고치면 그 경로를 `plugins/<플러그인>/tests/evals` 에서 찾아본다. 나오면 그 케이스를 돌리고 요약 줄을 PR 본문에 싣는다.
- 돌리지 못했으면 「평가를 돌리지 못했다 — 이유」 를 싣는다. 싣지 않은 것과 돌리지 못한 것은 다르다.
- 격리된 세션에서는 평가 명령을 명령 줄에 직접 치면 막힌다 — `run_evals.py` 로 부른다. 그것도 막히면 다른 길로 돌려 넘기지 않고 「평가를 돌리지 못했다 — 이유」 를 싣는다. 지휘 흐름에서는 그때 지휘자가 돌린다.
- 돌렸는지를 기계가 확인하지 않는다 — PR 본문의 한 줄과 리뷰가 맡는다.

**못 지키는 글.**

- `CLAUDE.md` 와 그것이 가리키는 문서를 모델이 따르는지. 평가는 플러그인만 싣는다 — 글자 확인만 남는다.
- 사람의 답이 있어야 다음 걸음으로 가는 흐름(질문 창의 답을 기다리는 걸음). 한 번의 실행에서 드러나지 않는다.
- agent 여럿을 띄우는 긴 흐름. 한 번 도는 값이 짧은 흐름과 자릿수가 다르다 — 재지 않았다.
- 뜻이 덜 또렷한 문장. 흔들림을 재지 않았다 — 쓰려면 먼저 여러 번 돌려 본다.
- 이유 · 설명 · 예시 문장. 어느 장치도 맡지 않는다 — 리뷰가 본다.

## 망가뜨려 보기

갈래마다 다르다.

| 갈래 | 하는 것 |
|---|---|
| 보안 갈래의 확인(「보안 갈래」 절) — 새로 쓰든 고치든 옮기든 합치든 | 변이(삭제 · 추가 · 반전 · 형태 바꾸기)로 RED 를 보이고, 양성 대조로 계측기가 살아 있음을 확인한다 |
| 그 밖에 새로 쓰거나 고친 확인 | 그 확인이 실패하는 것을 한 번 본다. 「쓰는 차례」 대로 실패를 먼저 보고 구현했으면 이미 본 것이다 — 따로 걸음을 두지 않는다 |
| 보안 갈래가 아닌 확인을 옮기거나 합치기만 했을 때 | 전에 잡던 것 하나를 옮긴 뒤에도 잡는지 한 번 본다 |
| 「없어야 한다」 를 보는 확인 | 어느 갈래든 「있을 때 잡힌다」 짝을 둔다 |

## 보안 갈래

아래를 지키는 확인이다.

- 끄는 스위치가 읽히는가
- agent 의 `tools:` allowlist(Law 2)
- 경로와 링크의 울타리
- 비밀이 기록되지 않는가
- 리뷰어 정의의 규칙과 문턱
- 믿지 않는 입력의 검증

가르고 다루는 법:

- 가르는 단위는 파일이 아니라 확인(줄 범위)이다. 한 파일에 보안 확인이 섞여 있어도 나머지 확인은 보안 갈래가 아니다.
- 테스트 파일에 표시를 달지 않는다. 보안 갈래인지는 위 목록으로 그때 판정하고, 지우기 · 합치기 · 줄이기의 표(「지우기 · 합치기 · 줄이기의 승인과 기록」 절)에는 보안 확인의 줄 범위를 적는다.
- 보안 갈래의 확인에는 「글을 무는 확인」 의 「말을 다듬어도 깨지지 않는다」 는 조건과, 「값 대비 비용」 의 첫째 줄(못 대면 지운다) · 넷째 줄(글자에 묶였으면 줄인다) 판정을 쓰지 않는다. 글자 그대로 물어도 되고, 애매하면 둔다.
- 예외는 위 줄의 조건과 판정, 이 둘뿐이다. 「값 대비 비용」 의 둘째 줄(겹침 확인)과 셋째 줄(오래 걸리면 구조를 고친다)은 보안 갈래에도 그대로다.

## 값 대비 비용

있는 테스트를 가르는 차례다. 위에서부터 묻고 처음 맞는 데서 멈춘다.

1. 지키는 것을 한 문장으로 못 댄다 → 지운다. 그 테스트가 막던 실수가 다시 나올 수 있다는 것을 받아들인다.
2. 같은 것을 다른 테스트가 지킨다 → 합친다. 상대 테스트를 열어 본 것만 겹침이다 — 이름이 비슷한 것은 근거가 아니다.
3. 지키는 것은 있는데 오래 걸린다 → 구조를 고친다(준비물 함께 쓰기 · 나누기 · 더 싼 확인으로 내리기). 고치면 잃는 확인이 있으면 적는다.
4. 글자에 묶여 동작이 안 바뀐 변경에도 고치게 된다 → 줄인다(「글을 무는 확인」 의 꼴로). 근거는 그 테스트를 동작 변경 없이 고친 커밋이나, 문장 전체를 무는 확인 그 자체다.
5. 그 밖 → 둔다.

비용의 잣대는 둘이고 따로 본다 — 도는 시간(초)과 유지 비용(동작이 같은데 고친 횟수). 숫자 문턱은 두지 않는다. 보안 갈래의 확인은 첫째 줄과 넷째 줄을 건너뛴다.

## 새 테스트가 하지 않는 것

- 작업 트리와 사용자 파일(`~/.claude/…` · 고정된 `/tmp/…` 경로)을 건드리지 않는다.
- 케이스마다 레포를 새로 세우지 않는다 — 한 번 세워 나눠 쓴다.
- 확인마다 프로세스를 띄우지 않는다.
- 다른 테스트를 통째로 다시 돌리지 않는다.

일의 모양이 달라 이 가운데 하나가 맞으면 하고 이유를 테스트 머리에 한 줄로 적는다.

## 지우기 · 합치기 · 줄이기의 승인과 기록

PR 하나가 묶음 하나이고 승인도 한 번이다.

- 표를 먼저 만든다. 칸은 다섯이다 — 테스트(파일과 케이스) · 판정(「값 대비 비용」 의 어느 줄) · 지키던 것 · 겹침 상대를 열어 봤는가 · 보안 확인이 섞였는가(섞였으면 줄 범위).
- 그 표를 사용자에게 보여 승인받은 뒤에 지우는 커밋을 만든다. PR 본문에는 승인받은 표를 그대로 싣는다.
- 확인이 다른 테스트로 옮겨지지 않고 사라지면 판정이 어느 줄이든 [`docs/removed-tests.md`](removed-tests.md) 에 한 줄을 남긴다(줄의 꼴은 그 파일에 있다). 상대가 이미 다 지켜 옮길 것이 없던 것은 「지금 지키는 것」 에 그 경로를 적는다. 확인을 옮긴 합치기와 줄이기는 남기지 않는다 — 지키던 것이 남아 있다.
- 테스트를 빠져나간 실수를 고칠 때는 새 테스트를 쓰기 전에 [`docs/removed-tests.md`](removed-tests.md) 에서 그것을 지키던 테스트가 있었는지 먼저 본다.

---

# Test-Driven Development

TDD is the red → green loop. This skill is the reference that makes that loop produce tests worth keeping: what a good test is, where tests go, the anti-patterns, and the rules of the loop. Every section applies on every cycle: consult them before and during the loop, not after.


## What a good test is

Tests verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't. A good test reads like a specification: "user can checkout with valid cart" tells you exactly what capability exists, and it survives refactors because it doesn't care about internal structure.

See [tests.md](#good-and-bad-tests) for examples and [mocking.md](#when-to-mock) for mocking guidelines.

## Seams: where tests go

A **seam** is the public boundary you test at: the interface where you observe behavior without reaching inside. Tests live at seams, never against internals.

**Test only at pre-agreed seams.** Before writing any test, write down the seams under test and confirm them with the user. No test is written at an unconfirmed seam. You can't test everything, so agreeing the seams up front is how testing effort lands on the critical paths and complex logic instead of every edge case.

Ask: "What's the public interface, and which seams should we test?" Give each proposed seam a one-line note on what it catches and what it misses.


## Anti-patterns

- **Implementation-coupled**: mocks internal collaborators, tests private methods, or verifies through a side channel (querying the database instead of using the interface). The tell: the test breaks when you refactor but behavior hasn't changed.
- **Tautological**: the assertion recomputes the expected value the way the code does (`expect(add(a, b)).toBe(a + b)`, a snapshot derived by hand the same way, a constant asserted equal to itself), so it passes by construction and can never disagree with the code. Expected values must come from an independent source of truth: a known-good literal, a worked example, the spec.
- **Horizontal slicing**: writing all tests first, then all implementation. Bulk tests verify _imagined_ behavior: you test the _shape_ of things rather than user-facing behavior, the tests go insensitive to real changes, and you commit to test structure before understanding the implementation. Work in **vertical slices** instead: one test → one implementation → repeat, each test a **tracer bullet** that responds to what the last cycle taught you.

## Rules of the loop

- **Red before green.** Write the failing test first, then only enough code to pass it. Don't anticipate future tests or add speculative features.
- **One slice at a time.** One seam, one test, one minimal implementation per cycle.
- **Refactoring is not part of the loop.** It belongs to the review stage, not the red → green implementation cycle.

# Good and Bad Tests

## Good Tests

**Integration-style**: Test through real interfaces, not mocks of internal parts.

```typescript
// GOOD: Tests observable behavior
test("user can checkout with valid cart", async () => {
  const cart = createCart();
  cart.add(product);
  const result = await checkout(cart, paymentMethod);
  expect(result.status).toBe("confirmed");
});
```

Characteristics:

- Tests behavior users/callers care about
- Uses public API only
- Survives internal refactors
- Describes WHAT, not HOW
- One logical assertion per test

## Bad Tests

**Implementation-detail tests**: Coupled to internal structure.

```typescript
// BAD: Tests implementation details
test("checkout calls paymentService.process", async () => {
  const mockPayment = jest.mock(paymentService);
  await checkout(cart, payment);
  expect(mockPayment.process).toHaveBeenCalledWith(cart.total);
});
```

Red flags:

- Mocking internal collaborators
- Testing private methods
- Asserting on call counts/order
- Test breaks when refactoring without behavior change
- Test name describes HOW not WHAT
- Verifying through external means instead of interface

```typescript
// BAD: Bypasses interface to verify
test("createUser saves to database", async () => {
  await createUser({ name: "Alice" });
  const row = await db.query("SELECT * FROM users WHERE name = ?", ["Alice"]);
  expect(row).toBeDefined();
});

// GOOD: Verifies through interface
test("createUser makes user retrievable", async () => {
  const user = await createUser({ name: "Alice" });
  const retrieved = await getUser(user.id);
  expect(retrieved.name).toBe("Alice");
});
```

**Tautological tests**: Expected value restates the implementation, so the test passes by construction.

```typescript
// BAD: Expected value is recomputed the way the code computes it
test("calculateTotal sums line items", () => {
  const items = [{ price: 10 }, { price: 5 }];
  const expected = items.reduce((sum, i) => sum + i.price, 0);
  expect(calculateTotal(items)).toBe(expected);
});

// GOOD: Expected value is an independent, known literal
test("calculateTotal sums line items", () => {
  expect(calculateTotal([{ price: 10 }, { price: 5 }])).toBe(15);
});
```

# When to Mock

Mock at **system boundaries** only:

- External APIs (payment, email, etc.)
- Databases (sometimes - prefer test DB)
- Time/randomness
- File system (sometimes)

Don't mock:

- Your own classes/modules
- Internal collaborators
- Anything you control

## Designing for Mockability

At system boundaries, design interfaces that are easy to mock:

**1. Use dependency injection**

Pass external dependencies in rather than creating them internally:

```typescript
// Easy to mock
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}

// Hard to mock
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

**2. Prefer SDK-style interfaces over generic fetchers**

Create specific functions for each external operation instead of one generic function with conditional logic:

```typescript
// GOOD: Each function is independently mockable
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  getOrders: (userId) => fetch(`/users/${userId}/orders`),
  createOrder: (data) => fetch('/orders', { method: 'POST', body: data }),
};

// BAD: Mocking requires conditional logic inside the mock
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```

The SDK approach means:
- Each mock returns one specific shape
- No conditional logic in test setup
- Easier to see which endpoints a test exercises
- Type safety per endpoint
