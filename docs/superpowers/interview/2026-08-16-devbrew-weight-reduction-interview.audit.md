---
type: interview-audit
payload: 2026-08-16-devbrew-weight-reduction-interview.md
created_at: 2026-08-16
session_id: 2f2a8aaf-c4ba-4fe7-82dc-7174e5c81305
source: spec-distill conducting-interview v0.26.0
---

# devbrew 무게 감축 (전역 리팩토링) — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — R1 v3 확정. 통증=무게, 세 층 동시(A 컨텍스트 6,783줄 / B 리포 66% 아카이브+테스트 / C 규약 24항목). 근거 T31 실측 + S12 통증진술 + S13 세 축 전부 선택. v1("갈라짐을 물을 실행 지점 부재")과 v2("동작 불변 리팩토링")는 각각 blind-spot 반증과 S11로 폐기
- floor:landscape — closed — L1~L8 전부 URL 인용. 마켓플레이스 symlink 역참조 / `--plugin-dir` 구멍 / 플러그인 의존성 부재 / 체크인 생성코드+`git diff --exit-code` / bats-core / blast radius / Sandi Metz. 2차 sweep에서 벤더 best-practices·Google SWE ch8·ch20·context rot·IFScale·skill 500줄 권고 추가
- floor:skepticism — closed — ST1 verdict=defended (통일 vs 검사만) · ST2 verdict=switched (전역 규약+강제 vs 사본제거+항목별 락). 둘 다 사용자 게이트 통과
- floor:blind_spot — closed — blind-spot-prober 정규 dispatch 완료(숨은가정 8 + 실패양식 11, 웹근거 18 URL, confidence 0.82). orchestrator가 5건 재검증: 4확인 / 1부분과장(CHANGELOG:391 선례는 실재하나 그 결정은 이후 철회됨). root_problem v1·v2 전제를 반증
- floor:open_questions — closed — **OQ1~OQ7** 박제(리뷰 라운드에서 재편). 잔여 락의 실행 시점 / Goal 2 범위·앵커 25 / T32 수정법 / 완료 측정 / PR 분할 / bump 순서 / `/compact` 경계·hook 가부. ✎ 초안의 OQ1(원장 지시대상)은 ⟨S18⟩로 **closed**, OQ8(kill switch rename 고지)은 ⟨S25⟩로 **closed**
- derived:modularization-semantics — closed — 요청 1·2행의 "모듈화"가 분할인가 병합인가; S9+S10이 직접 해소 — 배타 아님, 항목별 판단
- derived:done-oracle — open — 완료를 무엇으로 재는가; 후보 상충(사본 수 / 락 개수 / SKILL 줄 수 / 로드 토큰 / 총 줄 수). **OQ4**
- derived:sync-mechanism-allocation — open — 항목별 stale 방지 수단 배정; 18항목 중 13항목에 실효 장치 없음. C17(사본 제거 우선)로 방향은 정해졌으나 잔여 락의 실행 시점이 미결. **OQ1**
- derived:ledger-referent — **closed** — "원장"이 657회/82파일에 걸쳐 최소 3개 실재 대상을 가리켰고 orchestrator가 `docs/audits/`로 가정했으나, ⟨S15⟩ "audits는 원장이 아니야" + ⟨S18⟩ "아직 없다 — 향후 개발"로 확정. 요청 2행 뒷절은 별도 사이클(C11)
- derived:unification-target-boundary — in-progress — `/compact` 4장르 실측 완료 + Goal 5 신설(⟨S27⟩ 계기). hook 구현 가부는 **배제가 아니라 미결**로 되돌림(라운드3 critic: '사전 배제'는 측정이 아니라 해답공간을 닫는 결정). **OQ7**
- derived:context-load-economics — in-progress — 외부 근거 4종 확보(500줄 권고 / context rot / lost-in-middle / IFScale, 전부 **Goal 2 전용**으로 재배치 — IFScale을 Goal 3 근거로 쓴 것은 사실 오류라 정정). 범위·앵커 25개 처리는 **OQ2**
- derived:rollout-version-bump-ordering — open — 5플러그인 동시 bump인가 순차인가; 캐시에 qg 4버전·sd 5버전 공존. **OQ6**
- derived:request-decomposition-sequencing — open — 요청 4행이 1작업인가 4작업인가; 사용자가 분할 게이트를 물림. 4행 대응은 확정(1행→Goal 2·3 / 2행 앞절→Goal 2·3·뒷절→Non-goal / 3행→Goal 3 / 4행→Goal 5)이나 PR 분할 축은 미결. **OQ5**

## 2. Budget

- probe_count: 8 / cap 12 (인터뷰 본체). 리뷰 파이프라인은 별도 예산
- coverage-mapper dispatch: 1회 (probe 6 시점) — derived 8건 제안, orchestrator가 8건 전부 admit(기각 0)
- blind-spot-prober dispatch: 1회 (C8 인터뷰당 1회 준수)
- steelman-builder dispatch: 1회 (ST2). ST1은 에이전트 미승인 시점이라 orchestrator 자체 저술 — degrade 기록 §5 참조

## 3. Steelman 원문

#### ST1 — 통일하지 말고 자동 실행 지점부터 만들고 갈라지면 RED만 붙여라

> **degrade**: 이 항목은 `steelman-builder` 에이전트 출력이 아니다. 제기 시점에 이 세션은
> 에이전트 호출을 요청받지 않은 상태여서 orchestrator가 직접 저술했다. 독립 회의자가 아니며
> 인벤토리를 만든 주체가 그 반대도 세웠으므로 공유 전제가 양쪽에 들어갔다.

> **대안 명제:** "통일하지 마라. 24항목 중 물리적으로 합쳐도 되는 것은 거의 없다. 대신
> 자동 실행 지점(러너 + CI)부터 만들고, 각 사본에 '갈라지면 RED'만 붙여라."
>
> 근거 여섯:
> 1. 사본은 이 리포에서 blast radius를 나누는 안전장치다. 5플러그인이 독립 배포되는데 공유
>    원천은 "한 플러그인의 버그가 다섯을 동시에 깬다"는 뜻이다 — https://dev.to/david_whitney/notes-on-the-monorepo-pattern-5egc
> 2. 판정 헬퍼 109변형은 행동이 실제로 다르다(일부는 실패 시 `exit`, 일부는 계속). 합치면
>    지금 "계속 진행"인 테스트가 "첫 실패에 중단"이 되고, 뒤쪽 검사가 안 돈 채 초록으로 보인다.
> 3. `/compact` 두 게이트는 설계가 의도적 독립 저술이라고 명시했다 —
>    `spec-distill/skills/conducting-interview/SKILL.md:430`.
> 4. 환경변수 이름을 바꾸면 사용자가 설정해 둔 kill switch가 조용히 무효가 된다. kill switch는
>    CLAUDE.md가 보안 컨트롤로 규정한 것이고 "껐다고 믿는데 안 꺼진" 상태가 최악의 실패다.
> 5. 체크인 생성코드 패턴이 요구하는 자동 실행(CI)이 devbrew엔 없다. CI 없이 생성기만 두면
>    "생성기를 안 돌린 사본"이 새 실패 양식으로 추가돼 지금보다 나빠질 수 있다.
> 6. 성급한 추상화는 되돌리기가 중복보다 비싸다 — https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction
>
> 반대의 반대: 중복된 블록에 치명 버그가 있으면 수정을 모든 사본에 손으로 적용해야 하고
> (https://www.codewithjason.com/duplication-cheaper-wrong-abstraction/), 이 리포는 실제로
> 백포트를 잊은 전례를 스스로 기록했다(`quality-gates/CHANGELOG.md:738`).

**사용자 판정: `defended`** — 원안(통일) 유지. ST1이 든 위험 4건은 차단 사유가 아니라 설계 제약으로 이월.

#### ST2 — 전역 규약도 새 강제 계층도 만들지 말고 사본 자체를 제거해 갈라질 상태를 없애라

> **출처**: `spec-distill:steelman-builder` 정규 dispatch. 웹 근거 8건 + 리포 내부 실측 6건,
> confidence 0.78. 아래는 builder 출력 verbatim(발췌 없이 핵심 필드 그대로).

> **alternative_statement:** "전역 규약 문서도 새 강제 계층도 만들지 않는다 — 갈라진 13항목은
> **사본 자체를 제거**해(marketplace.json의 optional `description` 5개 삭제 → plugin.json 단일
> 출처, gc 스크립트·판정 헬퍼는 이미 리포에 있는 `tests/lib/` 공유 모듈로 흡수) 미래에 갈라질
> 상태 자체를 없애고, 사본이 구조적으로 불가피한 잔여에만 리포가 이미 갖고 있는
> `test_codex_copies_agree.sh`(행동-등가 + 양방향 ratchet) 패턴을 **항목별로** 복제하며, 벤더가
> 이미 제공하는 `claude plugin validate`를 기존 /qg·plugin-audit 게이트에 물린다. 사람이 읽어야
> 할 새 규칙은 0줄, CLAUDE.md 순증 0줄, 새 파일 0개."
>
> **strongest_case:** "원안의 강제 장치는 **돌 곳이 없다** — 이 리포엔 CI가 없고(`.github/` 부재
> 확인) main에 선재 red가 6~8건이라, 새 lint/test는 아무도 안 보는 red 풀에 합류해 즉시
> 중화된다. 반대로 '사본 삭제'는 러너를 0개 요구한다: 삭제된 중복은 어떤 미래 PR에서도 갈라질
> 수 없다. 그리고 원안의 규약 문서는 벤더 스스로 CLAUDE.md 지시를 'advisory'라 부르고 '과도하면
> Claude가 절반을 무시한다'고 경고하는 계층인데, 이 리포는 Law 2에서 이미 '분리는 프롬프트가
> 아니라 물리적'이라고 판결했다 — 원안은 자기 리포의 Law 2를 문서 계층에서 재범한다. 결정적으로
> 24항목은 **한 클래스가 아니다**: `test_codex_copies_agree.sh` 헤더가 '두 사본은 의도된 차이를
> 갖는다, diff로 재면 항상 RED거나 예외를 여는 순간 다른 차이도 함께 빠진다'고 실증한다. 하나의
> 전역 규약은 모호하거나(집행 불가) 대부분 항목에 대해 틀리다."
>
> 핵심 인용:
> - "Keep it concise. For each line, ask: Would removing this cause Claude to make mistakes? If
>   not, cut it. **Bloated CLAUDE.md files cause Claude to ignore your actual instructions!**" ·
>   "**If Claude already does something correctly without the instruction, delete it or convert it
>   to a hook.**" · "Unlike CLAUDE.md instructions **which are advisory**, hooks are deterministic"
>   — https://code.claude.com/docs/en/best-practices
> - "**If just one or two engineers are getting something wrong, adding to everyone's mental load
>   by creating new rules doesn't scale.**" — https://abseil.io/resources/swe-book/html/ch08.html
> - "**We either enable a compiler check as an error (and break the build) or don't show it in
>   compiler output.**" — https://abseil.io/resources/swe-book/html/ch20.html
> - "**teams will often stuff a laundry list of edge cases into a prompt… We do not recommend
>   this.**" — https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
> - SSOT: "implemented by the use of **pointers rather than duplicate** database tables" —
>   https://en.wikipedia.org/wiki/Single_source_of_truth
> - "Rather than relying on runtime checks, validation methods, **or documentation**" —
>   https://deviq.com/principles/make-illegal-states-unrepresentable/
> - ratchet 선례 — https://phenomnomnominal.github.io/betterer/
>
> **weakness_of_current:** "원안은 '미래 적용'을 **읽히기**에 걸지만, 이 리포에서 그 계층은 이미
> 두 번 실패했다 — marketplace 거짓 설명이 산문 규칙과 다중 리뷰를 10회 bump 동안 통과했고,
> codex 사본은 규약이 아니라 락이 생긴 뒤에야 멈췄다."
>
> **builder가 스스로 밝힌 미검증 2건:** (1) marketplace `description` 삭제 시 `/plugin` UI가
> plugin.json 것을 대신 보여주는지 미확인 — 비면 "삭제" 대신 "생성"으로 한 칸 후퇴하되 규약
> 0줄은 유지. (2) 판단 기준을 남기고 싶다면 always-loaded가 아니라 pull 표면(`docs/audits/` 또는
> on-demand skill)이 벤더 권고와 일치.

**orchestrator 검증 — ST2의 한 근거를 약화시킴**: `claude plugin validate`는 실재하고
(`--strict` = "Use in CI to fail on … issues that the runtime tolerates") devbrew에서 호출 0회가
맞다. 그러나 실행 결과 `--strict`로도 exit 0 · "Validation passed" — description 4/5 drift가
실재하는데도 통과한다. 즉 그 CLI는 스키마·중복이름·경로순회·**version** 불일치는 잡지만
**description drift는 안 잡는다.** ST2의 "벤더 CLI를 기존 게이트에 물린다"는 이 항목에 대해
근거가 약하다. 나머지 논지(사본 제거·항목별 락·규약 0줄)는 영향 없음.

**사용자 판정: `switched`** — ST2 채택. 원안(전역 규약 문서화 + 강제 장치)은 기각되어 payload §5로.

## 4. 게이트 실행 기록

- check_brief.py gate — **총 8회 실행, 최종 pass** (2026-08-16). 첫 실행 pass(본문 92줄) → 방향성
  리뷰 반영 후 **bijection B fail**(C11·C14 statement가 작은따옴표로 시작해 YAML 스칼라 추출이 어긋남)
  → 따옴표 제거 후 pass → 이후 충실도 3라운드마다 재실행, 전부 pass. 최종 본문 190줄.
  **advisory 2회**: 본문 153줄·166줄이 예산 137/트립와이어 150 초과 — 게이트가 "분량은 목표이지
  정확성 조건이 아니므로 차단하지 않는다"로 통과. 충실도 수정이 ✎ 프로즈를 누적시킨 결과다.
- check_verbatim_coverage.py — **총 5회 실행, 최종 rc=0** (2026-08-16). 첫 실행 **rc=1 차단**
  (`not_contained: ["S13","S10"]`) — orchestrator의 state 원장이 S10의 줄바꿈을 ` / `로, S13의 선택
  라벨을 요약으로 적어 §6와 대조 불가였다. **§6(사용자 원문)는 손대지 않고 원장을 사용자의 실제
  발화·선택으로 되돌려** 통과시켰다(반대 방향이었으면 laundering). 이후 payload 수정마다 재실행,
  전부 rc=0, advisories 0.

## 5. 프로세스 로그

- round 0: path (a) — 원 요청 4행 수신, trivia escape 판정 통과(다중 파일 의미론적 변경)
- round 1: path (a) — 플러그인 표면 인벤토리 + basename 기준 중복 4쌍 + `/compact` 77회/21파일 + 원장 현황. 이어 web sweep L1~L4
- round 1: path (b) — 통합 성공 기준 4지선다 → 사용자 옵션 미선택, "shared 될만한게 더 있는지" 요구
- round 2: path (a) — 내용 기준 재조사. T1~T5 (거의 동일 3건 / 공통 골격 7 / 프로즈 3 / 테스트 헬퍼 / README 섹션명)
- round 2: path (b) — 범위 4지선다 → 미선택, "산재된 것을 가능하면 통일하고 싶어"
- round 3: path (a) — T6~T10 (교차 함수 26 / env 33개 4어순 / 테스트 보일러플레이트 / 러너 0 / 원장 드리프트)
- round 3: path (b) — 탐색 계속 여부 → ② 한 번 더 (6영역 지정)
- round 4: path (a) — T11~T15 (헬퍼 정밀 / python 규약 / 아카이브 96% / 번들 제외 / CHANGELOG 일치)
- round 4: path (b) — ② 한 번 더 (6축 지정: 상태 레이아웃·degrade·훅 payload·AskUserQuestion·SKILL 구조·severity)
- round 5: path (a) — T16~T20. 6축 중 3축이 이미 일치(훅 payload / cost_class·frontmatter / docs 활성문서). 오탐 2건 정정(project-init MAJOR/MINOR=SemVer, agent-transparency severity=CHANGELOG only)
- round 5: path (b) — ② 한 번 더 (측정 한계 5곳 지정)
- round 6: path (a) — T21~T24 + `/compact`(E) 실측. T11 정정(111 하한 → 130/150, 68이름, 109변형), T18 정정(구조 일치·언어 드리프트)
- round 6: path (b) — ① 탐색 종료 → 설계 결정으로
- round 7: path (a) — web sweep 2차(L5~L8) + R1 재구성 v1 + ST1 저술
- round 7: path (b) — ST1 게이트 → `defended`
- round 7: path (b) — 분할 게이트 제시 → **사용자가 게이트를 물림**, orchestrator가 "정해 놓고 안 물은 것" 6가지를 펼침. 그중 6번(모듈화=쪼개기 vs 합치기)이 미탐색 축임을 자기 발견
- round 7: path (b) — "서브에이전트 써" → 에이전트 제약 해제. coverage-mapper + blind-spot-prober 병렬 dispatch
- round 7: path (a) — 대기 중 T25~T27(분할 축 첫 실측: SKILL 4,185줄 중 quality-pipeline 2,048=49%, 그중 Runtime gate 1,189=58%, 분해 선례 1/8)
- round 8: path (c) — coverage-mapper 결과. orchestrator가 사실 주장 4건 재검증: `/compact` 34파일/157회 주장은 **틀림**(실측 21파일/77회), 나머지 3건 확인. T28(marketplace description 5개 중 4개 drift)·T29(compact 4장르)·T30(공유 착지점 부재) 신규
- round 8: path (c) — blind-spot-prober 결과. **root_problem v1 전제 반증**(장치는 있다 — `test_codex_copies_agree.sh`), **"전역 모듈화"의 사용자 정의가 이미 있고 방향이 분할**(memory 2026-07-26), orchestrator 측정 오류 정정(공유 lib 2개 → 7개)
- round 8: path (b) — 방향 재질문 → S9 "리펙토링 한다고 보면 될듯함, 앞으로 개발에서도 적용"
- round 8: path (b) — S10 "통합도 반드시 해야지 … 장치가 부재한곳도 많아" → orchestrator 과잉정정 철회. 장치 커버리지 전수(18항목 중 13항목 장치 없음). 1차 측정(문자열 grep)은 T28을 "있음"으로 내 **폐기**, "지금 갈라져 있으면 실효 장치 없음" 잣대로 재측정
- round 9: path (b) — S11 "리팩토링은 제약의 언급이 아니었다, 호환보다 통합" → orchestrator가 도출한 제약 C6·C7·C8 철회
- round 10: path (b) — S12 "지금 레포가 너무 무거워" → **root_problem 재개(v3)**. T31 무게 실측(143,771줄, 로드 4.7%, 아카이브 38%, 테스트 28%=프로덕션의 2.3배)
- round 10: path (b) — S13 무게의 정체 → A+B+C 세 축 전부
- round 10: path (a) — T32 발견: 아카이브가 `discover-plan.sh`를 오염(plan 15/15 미체크 박스 보유, 지금 실행하면 이미 머지된 plan 선택)
- round 11: path (c) — steelman-builder ST2 결과. orchestrator가 `claude plugin validate` 실행 검증 → `--strict`로도 통과(description drift 미검출), ST2의 한 근거 약화
- round 11: path (b) — ST2 게이트 → `switched`. floor 5/5 closed → brief 작성

### brief 리뷰 라운드 (reviewing-brief, v0.24.0)

(순수 텔레메트리 — **기록이며 게이트 통과 조건이 아니다.** 검사 대상이 통과 조건을 직접 쓰는
검사는 이빨이 없으므로, 리뷰 생략 방지는 Step B 게이트의 degrade 전파가 담당한다.)

- **방향성**: Claude **11건** / codex **0건**(부재) — 사용자 재결정 **9건**(S15~S23). 그중 넷이
  brief를 실질적으로 바꿨다: (1) 아카이브 감축은 2026-07-09에 이미 실행됐고 38일 만에 재성장
  (`pre-slim-archive-2026-07-09` 태그 + "재개 금지" 메모리) → 대상을 `docs/audits/`로 축소 ·
  (2) 삭제는 T32를 못 고친다(선택 규칙이 최신 mtime이고 대상 파일이 이미 완료 배너 보유) ·
  (3) 테스트는 실제로 실행된다(§0의 "로드도 실행도 안 되는 66%"가 절반 거짓) · (4) 요청 4행
  `/compact`에 Goal이 없었다. **⑴⑵는 orchestrator가 세션 시작부터 컨텍스트에 있던 사용자 기록을
  11라운드 동안 한 번도 참조하지 않아 생긴 갭이다.**
- **충실도 기록**(게이트 아님, 마지막 관측 verdict만): **needs_revise** — critic 3라운드
  (13 → 10 → **3**건), 재라운드 **2/2**(상한 도달 → forced escalate). codex 0건.
  라운드3에서 여섯 축 중 넷이 clean(distortion·provenance·authority·§4 생략), 앵커 21개 전부
  §6 표기와 일치 확인. **남은 3건은 orchestrator가 수정했으나 독립 재검증 없음.**
- **냉독**: `brief-readback` 1회. **G1~G5 gap 0건 — pass.** 미결을 확정으로도, 확정을 미결로도
  읽지 않았고 Goal↔Non-goal 반전도 다음 행동 오독도 없었다. 문서의 의도(OQ1 우선순위 · 요청 한 행을
  뺀 근거 · 🗣/☑/✎ 표기 규약)가 전달됐다.
- ★ **Law 3 compounding — 여섯 번째 gap 클래스 관측**: `G6 — 문서 밖 맥락을 전제한 미정의 참조`.
  냉독이 닫힌 5클래스 밖에서 실질적 결함을 냈다. 관측된 사례: `ST1`·`ST2`(steelman의 약어인지
  정체 불명) · `LD8`(아무 설명 없음) · `pull 표면` · `66%`(무엇에 대한 비율인지) · `18항목`(전체
  목록 부재) · `T32`(번호 출처 불명) · `Step B`(어느 문서의 어느 단계인지) · `옵션 ③`(세 옵션 미나열).
  핸드오프 문서에서 이 클래스는 치명적이다 — **다음 stage가 정확히 그렇게 냉독한다.**
  → payload에 `§0.5 용어` 블록(8항목) 신설로 대응. `reviewing-brief` SKILL의 3-b gap 표에 G6를
  추가하는 것이 이 사이클의 compounding 산출물 후보다(별도 작업).
- **냉독 측정 한계(degrade)**: orchestrator가 냉독 프롬프트에서 §2 ✎ 7블록·§4·§6을 요약으로
  대체해 **축약본을 읽혔다.** 지적된 미정의 용어들은 전문에도 없음을 확인했으나, 다른 지적은
  축약 탓일 수 있다.
- **degrade (5건, Step B 게이트 question 텍스트로 전달)**:
  1. `codex` / all / **skipped** — 사용자 요청, 이 세션에서 codex 사용 불가. **모델 다양성 backstop 부재**
  2. `pipeline` / all / degraded — 본문 153줄, 예산 137·트립와이어 150 초과
  3. `pipeline` / all / degraded — 본문 166줄(최종 190줄), 충실도 수정이 ✎ 프로즈를 누적
  4. `critic` / fidelity / degraded — 라운드3 프롬프트를 blob 파일이 아니라 orchestrator가 손으로
     조립해 파일과 3곳 불일치. 사후 파일을 리뷰본에 동기화했으나 **리뷰 대상과 산출물이 갈렸던 창**이 있었다
  5. `critic` / fidelity / degraded — 재리뷰 상한 2 도달, 라운드3 findings 3건을 수정했으나 미검증
  (+ fallback 채널에 1번의 중복 기록 1건 — 첫 호출이 셸 변수 분할로 실패해 이중 기록)
- **ST1/ST2 degrade**: ST1은 에이전트 호출 미승인 시점이라 orchestrator 자체 저술(독립성 없음).
  ST2는 `steelman-builder` 정규 dispatch. blind-spot도 inline premortem으로 1회 대체 후 정규 재실행.
- **격리**: zero-tool probe **ZERO_TOOL_OK** (`docs/audits/2026-07-27-spec-distill-zero-tool-probe.md:121`)
  → critic·readback이 `tools: []`이라 격리 성립, 충실도 verdict는 hard gate. `codex_isolated: false`(codex 부재).
- **모델 호출 실측**: 에이전트 **8회**(coverage-mapper 1 · blind-spot-prober 1 · steelman-builder 1 ·
  direction-reviewer 1 · critic 3 · readback 1) / codex **0회**. 진입 승인 시 고지한 상한은 에이전트 5 —
  **초과분 3회는 방향성 리뷰 이전 단계(인터뷰 본체)의 dispatch로, 리뷰 파이프라인 예산 밖이다.**
- 이관 (2026-09-06): ST1 verdict: defended → refined (이관 2026-09-06 — 원안 유지 + 위험 4건을 설계 제약으로 이월한 것은 보완이다)

