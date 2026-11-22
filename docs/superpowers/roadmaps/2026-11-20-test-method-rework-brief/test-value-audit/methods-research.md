## 1. 한 줄 답
방법은 있다. 다만 "기존 스위트를 시간 대비 가치로 감사하는 단일 방법론"은 없고, 부분 방법이 흩어져 있다. 즉 (a) 스위트 축소 연구(커버리지·mutation 기반), (b) 테스트 한 건의 속성 목록(Khorikov, Desiderata), (c) 냄새 카탈로그와 느린 테스트 리팩터링 패턴, (d) 피라미드의 "아래로 내리기" 규칙이다. 진단 표의 칸은 이것들에서 뽑을 수 있다. 문서 락(prose-lock)을 다룬 자료는 이번에 찾지 못했다.

표기: [열람] = 이번 세션에 페이지를 열어 확인함. [검색] = 검색 결과 요약만 봄. [기억] = 배경지식이고 이번에 확인하지 않음.

## 2. 후보 방법

| 이름 | 무엇을 재나 | 필요한 것 | 우리 상황 적합도 | 알려진 한계 | 출처 / 확인 |
|---|---|---|---|---|---|
| Khorikov 4 pillars | 테스트 한 건의 protection against regressions, resistance to refactoring, fast feedback, maintainability | 사람의 판단. 도구는 필요 없음 | 높음. 칸 구조로 바로 쓴다. "락"은 resistance to refactoring이 낮을 가능성이 크다는 점을 따질 수 있다. | 정량 기준이 없다. 아래 근거로 본 pillars 정의는 2차 요약 기준이다. | [ajguerrer 요약](https://ajguerrer.github.io/blog/unit-testing/2-making-tests-work) [열람, 2차]. 책 4장 원문은 403으로 못 열었다. |
| Test Desiderata (Beck) | 12가지 속성(Isolated, Fast, Behavioral, Structure-insensitive, Specific, Predictive 등)과 속성 간 상충 | 판단 | 중간. 점검표로는 좋지만 삭제 기준은 주지 않는다. | 상충할 때 무엇을 버릴지는 말하지 않는다. | [testdesiderata.com](https://testdesiderata.com/) [열람] |
| Test pyramid의 "아래로 내리기" (Fowler) | 높은 수준 테스트가 낮은 수준 테스트와 겹치는지 | 테스트마다 층위 분류 | 높음. "moving a check to a cheaper level"에 해당한다. | 정성 규칙이다. | [practical-test-pyramid](https://martinfowler.com/articles/practical-test-pyramid.html) [열람]. "Push your tests as far down the test pyramid as you can"와 "모든 테스트는 additional baggage"가 있고, 중복되는 상위 테스트는 지우라는 취지다. |
| Google 테스트 크기(small/medium/large)와 유지보수 지침 | 프로세스·네트워크 같은 자원 제약으로 크기를 가른다. 느리거나 깨지는 테스트를 리팩터링 대상으로 본다. | 분류 기준 | 중간. 비용 분류 어휘로 쓸 만하다. | 챕터에는 숫자 시간 제한이 없고 삭제도 다루지 않는다. 블로그 원문 표는 못 열었다. | [SWE at Google ch.11](https://abseil.io/resources/swe-book/html/ch11.html) [열람] |
| Test-suite reduction (커버리지·mutation 기반) | 요구(문장·분기·killed mutant)를 같은 만큼 덮는 최소 부분집합 | 테스트별 커버리지 또는 mutant 킬 행렬 | 낮음~중간. 커버리지 도구가 없다. 우리 테스트는 문서나 스크립트를 grep하는 것이라 "커버리지"가 의미가 약하다. | 결과가 엇갈린다. 한 연구는 fault detection 손실이 크지 않다고, 다른 연구는 심하다고 했고, 대형 프로젝트 연구에서는 평균 약 12.5% 손실이 보고됐다. 알고리즘보다 커버리지 기준과 테스트 단위가 결과를 더 좌우한다. | [Yoo&Harman 서베이 등 검색 결과](https://www.cse.chalmers.se/~feldt/advice/yoo_2010_regression_testing_survey.pdf) [검색]. [Shi 외 FSE14 "Balancing Trade-offs in Test-Suite Reduction"](https://mir.cs.illinois.edu/gyori/pubs/fse14reduction.pdf) [검색, PDF 본문은 못 읽음] |
| coverage.py dynamic contexts | 줄마다 어느 테스트가 실행했는지, 즉 테스트별 고유 커버리지 | `coverage run -m unittest` 같은 실행, `dynamic_context = test_function` | 중간. Python 쪽만 된다. 단독으로 덮는 줄이 없는 테스트가 "겹침 후보"다. 7개 python 폴더 중 로직 테스트에는 쓸 수 있고, 스크립트를 subprocess로 도는 테스트는 안 보일 수 있다(기억). | 실행 비용이 든다. 파이썬 버전 요구는 그 페이지에 없었다. | [contexts 문서](https://coverage.readthedocs.io/en/latest/contexts.html) [열람]. `test_function`은 이름이 test로 시작하는 함수마다 컨텍스트를 만들고, `.coverage`는 SQLite다. |
| Mutation testing (mutmut 등) | 어느 테스트가 어느 mutant를 죽이나. 한 건만 죽이는 테스트는 고유 가치가 있다. | mutmut 같은 도구와 시간 | 낮음~중간. 우리는 이미 손으로 쓴 mutation 행렬이 있다. 그 행렬이 이 방법의 기성 방식이다. Python 3.9 지원은 확인하지 못했다. | 전체 코드베이스에 돌리면 비싸다. Google은 변경분에만 돌리고 mutant 수를 제한한다. bash용 성숙한 도구는 이번에 찾지 못했다. | [Google Practical Mutation Testing](https://research.google/pubs/practical-mutation-testing-at-scale-a-view-from-google/) [열람, 초록]. [mutmut](https://www.Github.com/boxed/mutmut) [검색]. |
| 테스트 냄새 카탈로그 (xUnit Patterns, tsDetect) | Slow Tests, Fragile Test, Obscure Test, Assertion Roulette, Test Code Duplication 같은 냄새 | 판단. tsDetect는 Java용 | 중간. 리팩터링 어휘로 쓴다. 자동 탐지 도구는 bash와 Python unittest에 맞는 것을 못 찾았다. | 냄새 정의가 너무 엄격하고 실제 유지보수 결함과 잘 맞지 않는다는 평가가 있다. 중복·불필요 테스트는 다루지 않는다. | [Panichella 외 2022](https://link.springer.com/article/10.1007/s10664-022-10207-5), [도구 매핑 연구](https://arxiv.org/pdf/2104.14640) [검색]. xunitpatterns.com은 연결이 거부됐다 [기억]. |
| 실패 이력·flaky 비율·유지 churn | 이 테스트가 진짜 버그를 잡은 적이 있나, 얼마나 자주 거짓으로 실패하나, 얼마나 자주 고쳐지나 | git log, 실행 이력 | 높음, 단 이력이 있어야 한다. 이번 세션에서는 데이터를 보지 않았다. | Google은 flaky가 1%에 가까워지면 테스트가 가치를 잃기 시작한다고 한다. 이력은 "한 번도 못 잡음"과 "필요 없음"을 구분하지 못한다. | [SWE at Google ch.11](https://abseil.io/resources/swe-book/html/ch11.html) [열람]. 이력 기반 지표 자체는 [기억]. |

## 3. 진단 표 칸으로 옮길 수 있는 것
- 비용(초): Khorikov의 fast feedback, Desiderata의 Fast. 보강으로 "필요 자원 수준"(프로세스 안인지, 파일/외부 호출이 필요한지)을 Google 크기 분류로 단다.
- 지키는 것: protection against regressions (Khorikov). Desiderata의 Behavioral("동작이 바뀌면 결과가 바뀐다")과 Predictive.
- 거짓 실패 위험: resistance to refactoring, Structure-insensitive. 구현 문구에 묶인 락이 여기에 걸린다.
- 겹침: Fowler의 "더 낮은 층이 이미 잡는가", coverage.py contexts의 고유 커버리지, mutation 킬 행렬의 고유 킬.
- 읽기 쉬움·유지: maintainability (Khorikov), Readable과 Specific (Desiderata), 냄새 카탈로그.
- 판정 후보 중 restructure는 "낮은 층으로 이동"(Fowler), "공유 fixture·보일러플레이트"(Google의 brittle 항목), Slow Tests 원인 목록(xunitpatterns, 못 열어 [기억])에서 나온다.
- 삭제 근거: Fowler가 삭제를 명시한다. Google 챕터는 삭제를 다루지 않는다. Khorikov 정의 중 "곱하면 0"이라는 주장은 열어 본 요약에 없었다 [미확인].

## 4. 우리 상황에 맞는 것이 없는 빈 곳
- 산문(skill·reference 문서)을 grep으로 검사하는 테스트의 가치와 필요성을 다룬 방법은 찾지 못했다. snapshot/approval/contract test 문헌은 이번에 검색하지 않았고, 린트와 테스트의 구분 기준도 확인하지 못했다.
- bash 스크립트의 커버리지와 mutation 도구 중 macOS bash 3.2에서 쓸 만하다고 확인된 것이 없다. kcov는 Bash를 지원한다고만 확인했고 bash 3.2나 macOS 세부는 페이지에 없었다 [열람]. bashrs의 mutation 모듈은 존재만 확인했고 성숙도는 모른다 [검색].
- 문서 테스트에서 "고유하게 지키는 것"을 재는 측정 단위가 없다. 커버리지 줄도, 코드 mutant도 문서 내용에는 대응하지 않는다. 직접 정해야 한다.
- 테스트별 시간 대비 가치를 곱해 한 점수로 만드는 확립된 공식은 찾지 못했다.

## 5. 확인하지 못한 것
- Khorikov 책 원문(O'Reilly 403). 4개 속성 정의는 2차 요약 기준이다.
- Shi 외 FSE14와 Google ICSE 2021 논문의 본문(PDF가 읽히지 않음). 수치는 검색 요약 기준이다.
- xunitpatterns.com의 Test Smells와 Slow Tests 페이지(연결 거부), Google 테스트 크기 블로그의 시간 제한 표.
- mutmut·cosmic-ray의 Python 3.9 지원, 현재 유지 상태.
- coverage.py가 subprocess로 도는 스크립트 테스트를 컨텍스트별로 추적하는지.
- bats, ShellCheck 등 bash 테스트 도구는 검색하지 않았다.
- repo는 읽지 않았다. 적합도 판단은 질문에 적힌 상황에만 근거한다.
