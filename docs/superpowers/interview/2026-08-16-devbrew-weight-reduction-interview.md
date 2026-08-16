---
name: devbrew-weight-reduction
type: interview-brief
created_at: 2026-08-16
session_id: 2f2a8aaf-c4ba-4fe7-82dc-7174e5c81305
source: spec-distill conducting-interview v0.26.0
next_phase: superpowers:brainstorming
audit_file: 2026-08-16-devbrew-weight-reduction-interview.audit.md
user_sourced_items:
  - id: C1
    source: verbatim
    status: confirmed
    statement: "산재되어 있는 것들을 가능하면 통일하고 싶다"
    evidence: S2
  - id: C2
    source: chosen
    status: confirmed
    statement: "ST1 기각 — '통일하지 말고 검사만 붙여라'를 받아들이지 않고 통일 원안을 유지한다"
    evidence: S7
  - id: C3
    source: verbatim
    status: confirmed
    statement: "이번 작업의 방식이 앞으로의 개발에도 적용되어야 한다"
    evidence: S9
  - id: C4
    source: verbatim
    status: confirmed
    statement: "통합도 반드시 한다 — 논리적으로 갈라지는 게 맞으면 갈라진 채로, 통합할 것은 통합. 장치가 부재한 곳도 많다"
    evidence: S10
  - id: C5
    source: verbatim
    status: confirmed
    statement: "가능하면 갈아엎어서 호환을 염두하기보다 통합을 염두한다. 리팩토링이라 한 것은 제약의 언급이 아니었다"
    evidence: S11
  - id: C6
    source: verbatim
    status: confirmed
    statement: "지금 레포가 너무 무겁다"
    evidence: S12
  - id: C7
    source: chosen
    status: confirmed
    statement: "무게는 세 축 전부 — 리포 무게(아카이브·테스트 66%, 권장 선행)·컨텍스트 무게(모델이 읽는 6,783줄)·규약 무게(지켜야 할 것의 가짓수)"
    evidence: S13
  - id: C8
    source: chosen
    status: confirmed
    statement: "ST2 채택 — 새 규약 문서 0줄·CLAUDE.md 순증 0줄·새 파일 0개. 사본 제거 + 불가피한 잔여에만 항목별 행동 락. 기록은 pull 표면"
    evidence: S14
  - id: C9
    source: chosen
    status: confirmed
    statement: "docs/audits/ 만 대상으로 한다. 정본이 아니니 꼭 필요한지 따지고, 필요하면 여기 두지 말고 아카이브 폴더로 옮긴다. 이거 관련된 것은 compound 내용이라 향후 개발할 것이다"
    evidence: S15
  - id: C10
    source: chosen
    status: confirmed
    statement: "테스트는 대상에 남기되 어떤 변경도 락의 순감을 만들지 않는다"
    evidence: S16
  - id: C11
    source: chosen
    status: confirmed
    statement: "원장은 아직 없다 — 향후 개발. 요청 2행은 이번 범위에서 연기"
    evidence: S18
  - id: C12
    source: verbatim
    status: confirmed
    statement: "docs/audits/ 만 아카이브 행이고, 결국 이것도 해결 후 제거할 것이다"
    evidence: S19
  - id: C13
    source: chosen
    status: confirmed
    statement: "docs/audits/ 를 통째로 옮기고 참조 3종을 같은 범위에서 함께 수정한다"
    evidence: S20
  - id: C14
    source: chosen
    status: confirmed
    statement: "새 파일 0개는 규약·강제 문서에만 적용한다. references/ 분할과 공유 lib는 허용"
    evidence: S21
  - id: C15
    source: verbatim
    status: confirmed
    statement: "LD8 경계를 파기하고 '재논쟁 금지' 표시도 해제한다"
    evidence: S22
  - id: C16
    source: chosen
    status: confirmed
    statement: "실행 지점을 신설하지 않는다 — .github/·pre-commit·새 러너 전부"
    evidence: S23
  - id: C17
    source: chosen
    status: confirmed
    statement: "사본 제거가 우선이고 락은 구조적으로 불가피한 잔여에만 단다"
    evidence: S24
  - id: C21
    source: verbatim
    status: confirmed
    statement: "중복된 공통 부분은 stale되지 않도록 통합 관리한다"
    evidence: S0
  - id: C19
    source: chosen
    status: provisional
    statement: "원장을 확정하고 Goal을 채운다"
    evidence: S17
  - id: C20
    source: verbatim
    status: confirmed
    statement: "문제는 중복도 포함이다"
    evidence: S26
  - id: C18
    source: chosen
    status: confirmed
    statement: "kill switch 이름 고지 방식은 옵션 ③을 고른다 — 근거는 아직 개인적으로 사용하는 플러그인이라는 것"
    evidence: S25
---

# devbrew 무게 감축 (전역 리팩토링) — Interview Brief

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming 해답공간으로
> 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다. 텔레메트리는 `audit_file`에 있다.

## 0. 한눈에

**무엇** — devbrew(143,771줄 / 716파일)를 가볍게 만든다. 무게는 상위 진술이고 그 아래에
**중복(사본)·모듈화(분할)·규약 가짓수**가 함께 들어간다 — 셋 다 이번 범위다.
원 요청 4행 대응: 1행 모듈화→Goal 2·3 · 2행은 앞절(기존부분 모듈화)→Goal 2·3, 뒷절(원장에 추가)→Non-goal(별도 사이클, ⟨S18⟩) ·
3행 중복 통합→Goal 3 · 4행 `/compact` 통일→Goal 5.
**왜** — 사용자 통증 진술 "지금 레포가 너무 무거워"(⟨S12⟩) + "문제는 중복도 포함"(⟨S26⟩).
**무엇이 확정** — 대상은 `docs/audits/`만이고 삭제가 아니라 조건부 이동(C9·C12) · 통째 이동 +
참조 동반 수정(C13) · 테스트는 남기되 락 순감 금지(C10) · 원장은 별도 사이클(C11) · '새 파일
0개'는 규약 문서에만(C14) · LD8 파기(C15) · 실행 지점 신설 없음(C16) · 사본 제거 우선, 락은
잔여에만(C17) · kill switch 고지는 옵션 ③(C18). **20건은 Step B에서 `confirmed` 확정**(2026-08-16). C19만 provisional.
**무엇이 열려 있음** — 잔여 락을 무엇이 돌리는가 · SKILL 분할의 앵커 25개 처리 · T32 수정법 ·
완료 측정 · PR 분할 · bump 순서(§3).
**다음** — brainstorming 해답공간(§7).

## 0.5 용어 (냉독 지적 반영 — 이 문서 밖 맥락을 쓰지 않고 읽히도록)

- **ST1 · ST2** — steelman. 이 인터뷰가 자기 방향을 깨보려고 세운 반대 명제 둘. 원문은 audit §3,
  판정(defended/switched)은 §5. ST1="통일하지 말고 검사만", ST2="전역 규약 대신 사본 제거".
- **LD8** — 2026-07-09 context-slimming 사이클이 남긴 경계 조항. "구조 게이트·kill switch는 절대
  strip 금지 + context-rot은 모델 컨텍스트 창을 재는 것이지 하니스 집행이 아님"이었고 "재논쟁 금지"
  표시가 붙어 있었다. C15가 그 조항과 표시를 함께 파기했다.
- **Step B** — 이 인터뷰의 종료 게이트. 여기서 사용자가 제약을 `provisional`→`confirmed`로 확정하고
  다음 단계 진입 방식을 고른다. 그 전까지 이 문서의 모든 제약은 잠정이다.
- **pull 표면** — 필요할 때 찾아 읽는 곳(`docs/audits/`, on-demand skill). 매 세션 자동 로드되는
  push 표면(CLAUDE.md)의 반대. C8이 기록 위치로 이쪽을 택했다.
- **66%** — 전체 143,771줄 중 아카이브(54,237, 38%) + 테스트(40,732, 28%)의 비중.
- **18항목** — 조사에서 "실효 장치가 있는가"를 판정한 중복 항목 수. 있음 5(codex 계열: `detect_codex.sh`
  ×3 · `codex_findings_to_yaml.py` ×2 · degrade 술어 · degrade 계약(부분) · P21 프리앰블(부분)),
  없음 13(gc 2사본 · marketplace description · agent `tools:` 순서 · env 어순 · kill switch 검사 함수 ·
  판정 헬퍼 · state 루트 · SKILL kill switch 섹션명 · severity · README 섹션명 · commands
  `allowed-tools` · 원장 형식 · `/compact` 게이트).
- **T32** — 이 인터뷰가 매긴 실측 항목 번호. `discover-plan.sh`가 이미 머지된 plan을 이번 작업의
  계획으로 고르는 현상. OQ3이 그 수정법을 다룬다.
- **kill switch 옵션 ③** — kill switch 이름 변경 고지 방식 4지선다 중 셋째. ①이름 안 바꿈 /
  ②옛 이름 fallback + 경고 1릴리스 / **③fallback 없이 즉시 rename + CHANGELOG Deprecated 기재** /
  ④`CLAUDE.md:36` 규정 자체를 삭제. C18이 ③을 택했다.

## 1. Goal · Non-goal

- **Goal 1** — `docs/audits/`(936KB / 11항목)를 아카이브 폴더로 옮기고, 그 경로를 하드코딩한 참조를
  같은 범위에서 함께 고친다. 열린 backlog가 해소되면 최종 제거한다(C9·C12·C13).
  ✎ 앵커 ⟨S20⟩은 "참조 3종"이라 했고, orchestrator 실측으로 그 3종이 걸린 파일은 8곳이다 —
  `reviewing-brief/SKILL.md:104` · `auditing-plugins/SKILL.md`(7개소) · `render-audit-report.py:178` ·
  `validate-audit-data.py:145-148` · `test_ac6_regression.py:7` · `fixtures/ac6_build.py:16` ·
  `test_brief_agents.sh:9` · `CLAUDE.md:81`. 숫자 8은 사용자 발화가 아니라 실측이다.
- **Goal 2** — 모델이 읽는 표면을 줄인다. `quality-pipeline/SKILL.md` 2,048줄(권고 500줄의 4배),
  그중 `## Runtime gate` 한 섹션이 1,189줄. `references/` 분할이 허용된다(C14).
- **Goal 3** — **같은 책임의 사본을 통합한다**(요청 3행 "중복된 공통 부분은 stale되지 않도록 통합
  관리해"). 실측 대상: `detect_codex.sh` 3사본(공통라인 97.4%) · `codex_findings_to_yaml.py` 2사본
  (84.2%) · `qg-gc.py`↔`spec-distill-gc.py`(65.3%, 이름이 달라 1차 조사서 누락) · codex 러너 5개의
  `_degrade_if_empty` 구현 5종(계약은 같고 본문은 전부 다름) · P21 프리앰블 15파일 산재 ·
  `marketplace.json` description 5개(**4개가 이미 drift**, `/plugin` 화면에 틀린 설명 노출).
  **사본 제거가 우선이고 락은 구조적으로 불가피한 잔여에만**(C17). 18항목 중 **13항목에 실효
  장치가 없다**(C4). **stale 방지가 이 Goal의 요구다**(C21) — 요청 3행이 통합만이 아니라
  "stale되지 않도록"까지 요구했고, 그 요구를 무엇이 지키는지는 OQ1이다.
- **Goal 4** — 지켜야 할 **규약의 가짓수**를 줄인다. env 33개·4어순 · `.claude/` state 루트 7모양 ·
  severity 3척도 · agent `tools:` 3순서 · SKILL `kill switch` 섹션 4이름 · 판정 헬퍼 68이름·109변형 ·
  python 테스트 규약(pytest 5개가 문서화된 `-m unittest` 러너 밖, `encoding="utf-8"` 40/58) ·
  AskUserQuestion 라벨 언어(구조는 10/10 일치, 언어는 영/한 혼재) · commands `allowed-tools`
  (3/7 부재, 표기 2종). ✎ 뒤의 셋은 사용자가 ⟨S3⟩⟨S4⟩⟨S5⟩에서 지정한 축의 조사 결과다.
- **Goal 5** — **`/compact` 방식을 일관된 형태로 통일한다**(요청 4행). live 표면은 셋: `/compact`
  proceed 게이트 2벌(`conducting-interview` Step B · `reviewing-spec` Phase 5)이 같은 골격
  (`/compact <종류> at <경로> 보존 — <유지목록> 유지하고 <drop목록> drop. 다음 단계: Skill <스킬>`)을
  **독립 저술**한 것 — `conducting-interview/SKILL.md:430`이 "대칭 … 독립 저술"이라 스스로 명시 —
  + `publishing-pr-understanding/SKILL.md:207`의 post-compact session_id 주의 1줄. `PreCompact` 훅은
  리포 전체에 0개다. 대상 경계는 OQ7. hook 구현안의 가부도 OQ7에 속한다(구조 제약 (a) — 폐기 선례는 실측이나 '배제'는 orchestrator 추론).
- **Goal 6** — 테스트 하니스의 **공유 lib**를 쓴다(⟨S7⟩ 원안 C축). 셸 테스트 150개 중 130개가
  판정 헬퍼를 자체 정의하고(이름 68종·본문 109변형) 공유 lib를 source하는 것은 7개뿐인데,
  `quality-gates/tests/lib/`(`codex_observation.sh`·`extract_codex_invocations.py`)가 **이미
  크로스-플러그인으로 소비되고 있다** — 새로 만드는 것이 아니라 있는 것을 넓히는 일이다(C14 허용).
  단 헬퍼는 행동이 서로 다르므로(일부는 실패 시 `exit`, 일부는 계속) 통일이 곧 의미 변경이다 —
  C10(락 순감 금지)이 여기 걸린다.
- **Goal 7** — 다시 무거워지지 않게 한다. 새 규약 문서나 강제 계층이 아니라 **구조로**(C8·C14).
- **Non-goal** — 하위 호환을 **목표로 두지 않는다**(C5·C18). ✎ 앵커 ⟨S11⟩은 "**가능하면** 갈아
  엎어서 호환을 염두하기**보다는** 통합을 염두하도록"이라는 선호 비교이지 절대 금지가 아니다 —
  호환이 싸게 얻어지는 자리에서까지 버리라는 뜻으로 읽지 말 것.
- **Non-goal** — 새 전역 규약 문서 · CLAUDE.md 순증 · 새 강제 계층(C8·C14).
- **Non-goal** — **실행 지점 신설**(C16). `.github/`·pre-commit·새 러너를 만들지 않는다.
- **Non-goal** — **원장 구축**(요청 2행). ⟨S7⟩ 원안의 D축은 "원장→형식 하나"였으나, 이후 ⟨S17⟩에서
  "원장을 확정하고 Goal을 채운다"를 고른 뒤 ⟨S18⟩이 그 확정으로 **"원장은 아직 없다 — 향후 개발"**
  을 냈다. 즉 D축은 폐기가 아니라 **대상이 아직 존재하지 않아 별도 사이클로 이월**된 것이다(C11·C19).
- **Non-goal** — `docs/superpowers/{plans,specs,interview}` 감축(C9). 이 축은 2026-07-09에 한 번
  실행됐고 38일 만에 재성장했다(§5 위험 참조).
- **Non-goal** — 락 순감(C10). 어떤 변경도 검증 표면을 줄이지 않는다.

## 2. 제약

- 🗣 confirmed **C1** — 산재되어 있는 것들을 가능하면 통일하고 싶다 ⟨S2⟩
- ☑ confirmed **C2** — ST1 기각 — '통일하지 말고 검사만 붙여라'를 받아들이지 않고 통일 원안을 유지한다 ⟨S7⟩
- 🗣 confirmed **C3** — 이번 작업의 방식이 앞으로의 개발에도 적용되어야 한다 ⟨S9⟩
- 🗣 confirmed **C4** — 통합도 반드시 한다 — 논리적으로 갈라지는 게 맞으면 갈라진 채로, 통합할 것은 통합. 장치가 부재한 곳도 많다 ⟨S10⟩
- 🗣 confirmed **C5** — 가능하면 갈아엎어서 호환을 염두하기보다 통합을 염두한다. 리팩토링이라 한 것은 제약의 언급이 아니었다 ⟨S11⟩
- 🗣 confirmed **C6** — 지금 레포가 너무 무겁다 ⟨S12⟩
- ☑ confirmed **C7** — 무게는 세 축 전부 — 리포 무게(아카이브·테스트 66%, 권장 선행)·컨텍스트 무게(모델이 읽는 6,783줄)·규약 무게(지켜야 할 것의 가짓수) ⟨S13⟩
- ☑ confirmed **C8** — ST2 채택 — 새 규약 문서 0줄·CLAUDE.md 순증 0줄·새 파일 0개. 사본 제거 + 불가피한 잔여에만 항목별 행동 락. 기록은 pull 표면 ⟨S14⟩
- ☑ confirmed **C9** — docs/audits/ 만 대상으로 한다. 정본이 아니니 꼭 필요한지 따지고, 필요하면 여기 두지 말고 아카이브 폴더로 옮긴다. 이거 관련된 것은 compound 내용이라 향후 개발할 것이다 ⟨S15⟩
- ☑ confirmed **C10** — 테스트는 대상에 남기되 어떤 변경도 락의 순감을 만들지 않는다 ⟨S16⟩
- ☑ confirmed **C11** — 원장은 아직 없다 — 향후 개발. 요청 2행은 이번 범위에서 연기 ⟨S18⟩
- 🗣 confirmed **C12** — docs/audits/ 만 아카이브 행이고, 결국 이것도 해결 후 제거할 것이다 ⟨S19⟩
- ☑ confirmed **C13** — docs/audits/ 를 통째로 옮기고 참조 3종을 같은 범위에서 함께 수정한다 ⟨S20⟩
- ☑ confirmed **C14** — 새 파일 0개는 규약·강제 문서에만 적용한다. references/ 분할과 공유 lib는 허용 ⟨S21⟩
- 🗣 confirmed **C15** — LD8 경계를 파기하고 '재논쟁 금지' 표시도 해제한다 ⟨S22⟩
- ☑ confirmed **C16** — 실행 지점을 신설하지 않는다 — .github/·pre-commit·새 러너 전부 ⟨S23⟩
- ☑ confirmed **C17** — 사본 제거가 우선이고 락은 구조적으로 불가피한 잔여에만 단다 ⟨S24⟩
- 🗣 confirmed **C21** — 중복된 공통 부분은 stale되지 않도록 통합 관리한다 ⟨S0⟩
- ☑ provisional **C19** — 원장을 확정하고 Goal을 채운다 ⟨S17⟩
- 🗣 confirmed **C20** — 문제는 중복도 포함이다 ⟨S26⟩
- ☑ confirmed **C18** — kill switch 이름 고지 방식은 옵션 ③을 고른다 — 근거는 아직 개인적으로 사용하는 플러그인이라는 것 ⟨S25⟩

✎ **확정 상태.** Step B 게이트에서 사용자가 **20건을 `confirmed`로 확정**했다(2026-08-16).
   `C19`만 `provisional`로 남는다 — 이미 수행된 절차 지시라 앞으로 지킬 제약이 아니기 때문이며,
   그 판단이 틀렸다면 되돌릴 수 있다. 초안 시점의 `confirmed 0건` sentinel은 확정 반영과 함께
   삭제됐다.
✎ **orchestrator가 쓴 문구와 사용자 발화의 구분.** C16의 열거(`.github/`·pre-commit·새 러너)와
   C18의 옵션 ③ 내용은 **orchestrator가 제시한 선택지 문구**이며 사용자 발화 ⟨S23⟩⟨S25⟩가 담은
   것은 옵션 번호(와 C18의 경우 근거)뿐이다. C9의 ☑ 표기도 같은 성격이다 — ⟨S15⟩ 인용문에는
   옵션 번호가 없고 자유 발화만 있으나, 그 발화는 옵션 ③ 선택에 붙인 메모였다.
✎ **C11의 "2행 연기"가 2행 전체인가 뒷절인가.** 앵커 ⟨S18⟩은 절을 나누지 않고 "요청 2행은 이번
   범위에서 연기"라고만 했다. 앞절(기존부분 모듈화)이 살아 있다는 근거는 ⟨S18⟩이 아니라 더 뒤의
   ⟨S27⟩ "우리가 진행한다고 했던 **통합과 모듈화** 안하는거 아니지?"와 그에 대한 확인이다.
   즉 2행 앞절→Goal 2·3, 뒷절→연기는 **⟨S18⟩+⟨S27⟩의 합**이지 ⟨S18⟩ 단독이 아니다.
✎ **C19와 C11은 모순이 아니라 순서다.** ⟨S17⟩에서 "원장을 확정하고 Goal을 채운다"를 고른 결과가
   ⟨S18⟩의 확정("원장은 아직 없다")이고, 그 확정 때문에 2행 뒷절이 Non-goal이 됐다. C19는
   *지시*이고 C11은 그 지시를 수행한 *결과*다.
✎ **C18은 조건부다.** 근거가 "현재 개인 사용"이므로 제3자 설치가 생기면 근거가 바뀐다.
   `CLAUDE.md:36`(제거 전 one-minor deprecation window)과 `CLAUDE.md:48`(kill switch = 보안 컨트롤)은
   그대로 서 있으며, 이 결정은 그 조항들과의 충돌을 그 조건 아래 수용한 것이다.
✎ **제약으로 올리지 않은 사용자 발화와 그 이유:** ⟨S1⟩⟨S3⟩⟨S4⟩⟨S5⟩는 "더 찾아봐라"라는 **인터뷰
   진행 지시**이고 ⟨S6⟩은 탐색 종료, ⟨S8⟩ "서브에이전트 써"는 이 세션의 도구 사용 지시라, 설계가
   지켜야 할 제약이 아니라고 판단했다. ⟨S27⟩은 범위 점검이며 그 답이 Goal 5·6 신설로 반영됐다.
   **이 판단 자체가 틀렸다면 Step B에서 되돌릴 수 있다.**
✎ **지정하신 탐색 축별 결과 — 조사했으나 드리프트가 없어 Goal이 없는 것과, 드리프트가 있는데
   Goal이 없는 것을 구분한다.**
   *드리프트 없음(그래서 Goal 없음)*: CHANGELOG 형식(4개 전부 `## [x.y.z] — YYYY-MM-DD` 일치,
   plugin-audit는 v1.0.0 미만이라 면제) · 훅 payload 읽기(훅 10/10이 `json.load(sys.stdin)`, 키
   이름도 일치) · `cost_class`/skill frontmatter(8/8 선언·키 일치) · agent `tools:` 선언(18/18,
   `disallowedTools` 0) · docs 활성문서 중복(18개 문서 동일 문장 0).
   *통일 대상 아님*: `.superpowers`(255파일)·`.understand-anything`(5파일) — git 추적 0인 외부 번들.
   *드리프트 있으나 Goal에 아직 없음 → Goal 4가 받아야 할 것*: python 테스트 규약(pytest 5개가
   문서화된 `-m unittest` 러너로 안 돎, `encoding="utf-8"` 40/58) · AskUserQuestion 라벨 언어
   (구조는 10/10 일치하나 quality-gates SKILL은 영어, 같은 플러그인 command는 한국어) ·
   commands `allowed-tools`(3/7 부재, 표기 2종).
   *이미 Goal에 있음*: agent `tools:` 순서 3종(Goal 4) · state 루트 7모양(Goal 4) · severity 3척도
   (Goal 4) · degrade 구현 5종(Goal 3) · 판정 헬퍼(Goal 4·6).
✎ **구조 제약(사용자 발화 아님, 실측):** (a) **실측**: `spec-distill/CHANGELOG.md` v0.11.0이
   `hooks/compact-induction.py`(marker 기반 Stop-hook `/compact` 재주입)를 **폐기**했고 사유는
   "hook은 AskUserQuestion을 띄울 수 없음"이다. `PreCompact` 훅은 리포 전체에 0개.
   ✎ *여기서 orchestrator는 "그러므로 hook 구현안은 배제"라고 추론했으나 이는 측정이 아니라
   해답공간을 닫는 결정이고 사용자 발화 근거가 없다 — brainstorming이 뒤집을 수 있으며,
   OQ7이 그 판단을 열어 둔다.*
   (b) 크로스-플러그인 심볼릭 링크는 마켓플레이스 설치에서만 역참조되고 `--plugin-dir`에서는 skip.
   (c) 리포 루트에 `scripts/`·`lib/`·`shared/`가 없다. (d) CI 없음, 테스트 러너 1개, main에 선재
   red 6~8건. (e) `docs/audits/` 이동은 파일 이동이 아니라 3플러그인 계약 변경이다.

## 3. Open Questions

- **OQ1** — **잔여 락을 무엇이 돌리는가.** C16(실행 지점 신설 없음) + C17(잔여에 락) + C10(락 순감
  금지) + C21(stale 방지)이 겹치면 락은 늘어나는데 자동 실행 시점이 없다. 기존 게이트(`/qg`·`plugin-audit`)에 업는
  안은 제시됐으나 선택되지 않았다. 유추 금지.
- **OQ2** — **Goal 2의 범위와 순서.** `quality-pipeline/SKILL.md`를 앵커로 잡는 테스트가 **25개**이고,
  같은 조작이 같은 파일에서 이미 락 하나의 이빨을 없앤 선례가 있다(`test_skill_codex_skip_prose.sh` —
  프로즈가 사라져 AC19~AC21 무력화). 앵커 재작성을 같은 범위에 넣을지 선행 PR로 뺄지 미결.
- **OQ3** — **T32(plan 오선택) 수정법.** `discover-plan.sh`가 "미체크 `- [ ]` 중 최신 mtime"을 고르고
  현재 이미 머지된 plan을 선택한다. 그 파일은 완료 배너를 이미 달고 있으므로 결함은 스크립트가
  배너를 안 읽는 것. 완료분 하위디렉토리 이동(`find -maxdepth 1`이라 삭제 0줄·스크립트 0줄) vs
  `status:` 필드를 읽게 수정 — 미결.
- **OQ4** — **완료를 무엇으로 재는가.** 요청 4행의 동사가 전부 무한형이고 종료 조건이 정의되지 않았다.
- **OQ5** — **PR/작업 분할 축.** 종류별 / 위험도순 / 시범 1건 선행 — 미결.
- **OQ6** — **버전 bump·재설치 순서.** 5플러그인 동시인가 순차인가. 캐시에 qg 4버전·sd 5버전 공존.
- **OQ7** — **`/compact` 통일의 대상 경계**(요청 4행). 4장르(proceed 게이트 2벌 / compact 넘어 상태
  생존 키잉 / 문서 self-containedness 기준 / 폐기된 hook) 중 어디까지인가. **그리고 hook 구현안을
  되살릴지** — v0.11.0 폐기 사유("hook은 AskUserQuestion을 띄울 수 없음")는 실측이지만 그것이
  모든 hook 설계를 막는지는 검증되지 않았다. 유추 금지.

## 4. External Landscape

- 마켓플레이스 내부 심볼릭 링크는 설치 시 역참조된다 — https://code.claude.com/docs/en/plugins-reference — [중립] — 크로스-플러그인 물리 공유의 유일한 공식 경로
- 단 `--plugin-dir`/local-path 설치에서는 skip된다 — https://code.claude.com/docs/en/plugins-reference — [피함] — devbrew 자기 검증 경로가 그 모드
- 심볼릭 링크 silent skip 실사례(설치 후 skill 0개) — https://github.com/anthropics/claude-code/issues/53948 — [피함] — 무음 실패 실증
- CLAUDE.md는 매 세션 로드되며 비대하면 지시가 무시된다 — https://code.claude.com/docs/en/best-practices — [취함] — C8·C14 근거
- 규칙을 늘리면 전원의 인지 부하가 는다 — https://abseil.io/resources/swe-book/html/ch08.html — [취함] — C8 근거
- 검사는 에러로 강제하거나 아예 안 보이거나 — 중간 상태 거부 — https://abseil.io/resources/swe-book/html/ch20.html — [중립] — C16이 실행 지점을 안 만들기로 했으므로 이 인용은 양방향
- skill 문서 권고는 500줄 / 5,000토큰이며 상세 참조는 별도 파일로 — https://code.claude.com/docs/en/skills — [취함] — Goal 2 + C14 근거
- 컨텍스트 예산은 유한하고 토큰마다 소진된다 — https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents — [취함] — **Goal 2 전용** 근거
- 입력이 길어질수록 회수 정확도가 떨어진다 — https://www.trychroma.com/research/context-rot — [취함] — **Goal 2 전용** 근거
- 긴 컨텍스트에서 중간 위치 정보 접근이 열화된다 — https://arxiv.org/abs/2307.03172 — [취함] — **Goal 2 전용** 근거
- 지시 밀도가 오르면 최상위 모델도 500지시에서 68%로 떨어진다 — https://arxiv.org/pdf/2507.11538 — [취함] — **Goal 2 전용**. ✎ 초안은 이것을 Goal 3 근거로도 썼으나 IFScale이 재는 것은 한 프롬프트 안의 지시 수이고 Goal 3의 24항목은 어떤 프롬프트에도 들어가지 않는다 — 사실 오류라 정정했다(LD8 파기와 무관한 별개 정정)
- SSOT의 처방은 사본 일치 검사가 아니라 포인터 대체 — https://en.wikipedia.org/wiki/Single_source_of_truth — [취함] — C17 수단
- 문서·런타임 검사가 아니라 구조 자체를 집행 수단으로 — https://deviq.com/principles/make-illegal-states-unrepresentable/ — [취함] — C17 수단
- 결정 기록은 삭제하지 않고 supersede 상태만 바꾼다 — https://asdlc.io/patterns/the-adr/ — [피함] — C9·C12가 이 관행을 이 범위에서 뒤집었다
- 테스트:코드 1:1~1:3이 건강 대역이며 성숙할수록 테스트가 빨리 자란다 — https://bitdive.io/blog/test-to-code-ratio-standards-2026/ — [취함] — C10 근거. 2.3배는 이상치가 아니다
- 테스트는 DRY보다 가독성이 우선이고 약간의 중복은 허용된다 — https://abseil.io/resources/swe-book/html/ch12.html — [취함] — C10 근거
- 환경변수 rename은 새 이름 우선 + 옛 이름 fallback + 경고가 관행 — https://developer.hashicorp.com/terraform/plugin/framework/deprecations — [피함] — C18이 '현재 개인 사용'을 근거로 이 관행을 뒤집었다
- 공유는 결합이고 blast radius를 키운다 — https://dev.to/david_whitney/notes-on-the-monorepo-pattern-5egc — [피함] — 5플러그인 독립 배포 비용
- 성급한 추상화는 중복보다 비싸다 — https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction — [피함] — 항목별 판정 근거

## 5. 기각 · Blind Spots

- 기각 — 판단 기준을 새 전역 규약으로 문서화하고 강제 장치를 붙인다 → 무게 진술과 역방향이고, marketplace 거짓 설명이 산문 규칙 + 다중 리뷰를 약 10회 bump 동안 통과한 실측이 그 계층의 무력함을 증명 — https://code.claude.com/docs/en/best-practices — verdict: switched — ST2
- 기각 — 통일하지 말고 자동 실행 지점만 만들고 갈라지면 RED만 붙인다 → 사용자가 통일 원안을 유지 — https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction — verdict: defended — ST1
- 기각 — `docs/superpowers/{plans,specs,interview}` 감축 → C9가 대상을 `docs/audits/`로 한정
- 기각 — `docs/audits/`에서 살아있는 인프라 3개만 남기고 나머지만 이동 → C13이 통째 이동 + 참조 동반 수정을 택함
- 기각 — kill switch 이름에 옛 이름 fallback + 경고 1릴리스 → C18이 옵션 ③을 택함. ✎ 그 옵션 ③의 내용은 **fallback 없이 즉시 rename + CHANGELOG Deprecated 기재**이며, 사용자 발화 ⟨S25⟩가 담은 것은 옵션 번호와 근거('아직 개인적으로 사용하는 플러그인')뿐이라 이 문구는 orchestrator가 제시한 선택지 문구다
- 기각 — CI 또는 pre-commit 도입으로 락 실행 지점 확보 → C16이 실행 지점 신설 없음을 확정 제약으로
- 기각 — LD8 경계 승계 → C15가 파기 + '재논쟁 금지' 해제
- 위험 — **선행 사이클의 재성장 실측**: 아카이브 감축은 2026-07-09에 이미 실행됐다(태그 `pre-slim-archive-2026-07-09` 봉인 후 113파일/약 79,946줄 삭제, 메모리에 "재개 금지"). 현재 `docs/superpowers/` 54,237줄은 그 이후 38일간의 재성장분(약 1,400줄/일)이며, 생산 파이프라인(사이클당 plan+spec+interview+audit 4산출물)에는 아무 제동이 없다 — C9가 그 축을 이번 범위에서 뺐으므로 이 위험은 **미해소로 남는다**
- 위험 — 숨은 가정: 통일의 편익이 측정되지 않았다. 갈라짐이 실제 해를 끼친 증거는 2건뿐 — `quality-gates/CHANGELOG.md:738`(쌍둥이 러너 백포트 누락으로 이전 iteration YAML이 이번 판정으로 읽힘) + qg 사본이 실행 못 한 검사를 `codex_failed: false`로 기록
- 위험 — 숨은 가정: 리포 = 사용자가 쓰는 것. 설치 캐시에 qg 4버전·sd 5버전이 공존하고 orphan은 약 14일 뒤 정리된다 — https://code.claude.com/docs/en/plugins-reference
- 위험 — 실패 양식: 계측기와 피검체를 같은 사이클에 바꾼다. 코드 통합과 테스트 하니스 통합이 한 브랜치에 들어가면 회귀를 잡을 유일한 그물이 동시에 다시 짜인다 — C10이 락 순감을 금지해 일부만 완화된다
- 위험 — 실패 양식: SKILL 분할이 앵커 25개를 흔든다. 같은 조작이 같은 파일에서 이미 락 하나의 이빨을 없앤 선례가 있다 — OQ2로 이월
- 위험 — 실패 양식: severity 3척도 통일이 무손실 rename이 아니라 **머지 차단 임계 이동**이 된다
- 위험 — 실측된 live 오작동: 아카이브가 `discover-plan.sh`를 오염시킨다(plan 15/15가 미체크 `- [ ]` 보유, 14/15는 체크 0개). C9가 plans를 범위에서 뺐으므로 **삭제로는 안 닫히고** OQ3로 이월
- 위험 — `docs/audits/` 이동이 즉시 깨뜨리는 것: spec-distill 리뷰 파이프라인 시작 선결 조건(`reviewing-brief/SKILL.md:104`) · plugin-audit 산출 경로 계약(7곳 + `validate-audit-data.py`의 CLAUDE.md 포인터 검사) · AC6 테스트 baseline(170KB) · `test_brief_agents.sh:9`. C13이 동반 수정을 택했으므로 범위 안이지만 **누락 시 동작하는 게이트 둘이 죽는다**

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S0** 🗣 최초 요청:
  > "- devbrew 전역 모듈화를 진행해줘.
  >     - 이번 작업을 기존부분에 모듈화 진행, 원장에 추가해.
  >     - 중복된 공통 부분은 stale되지 않도록 통합 관리해.
  >     - 저장소 전반의 `/compact` 방식을 점검하고 일관된 형태로 통일해."

- **S1** 🗣 (통합 기준 질문에 대한 응답):
  > "shared 될만한게 더 있는지 한번 더 찾아봐줘"

- **S2** 🗣 (범위 질문에 대한 응답):
  > "더 있는지 찾아볼래? 산재되어 있는거들을 가능하면 통일하고 싶어"

- **S3** ☑ 선택 (탐색 계속 여부):
  > "② 한 번 더 찾는다 — 미탐색 6영역(docs 아카이브 42개 / .claude/ / .superpowers·.understand-anything 번들 / python 테스트 213개 보일러플레이트 / ok()·no() 28종 행동등가 / CHANGELOG 5개 형식)을 마저 훑으라"

- **S4** ☑ 선택 (탐색 계속 여부):
  > "② 한 번 더 — 내가 안 떠올린 축으로. 지정 축 6개: 상태파일 레이아웃 규약 / 오류·degrade 처리 패턴(fail-open|closed) / 훅 payload 읽기 방식 / AskUserQuestion 게이트 구조 / SKILL.md 공통 섹션 구조 / verdict·severity 어휘"

- **S5** ☑ 선택 (탐색 계속 여부):
  > "② 한 번 더 — 측정 한계로 남긴 곳: AskUserQuestion 옵션 구조·라벨 규약 / 판정 헬퍼 정확한 수 / T2 공통 골격 행동 등가 / agents 18개 tools 허용목록 규약 / commands 7개 allowed-tools 규약"

- **S6** ☑ 선택 (탐색 종료 여부):
  > "① 닫는다 — 설계 결정으로 (탐색 종료)"

- **S7** ☑ 선택 (ST1 의심 게이트):
  > "① 방어 — 원안 유지 (ST1 기각). A 사본→통합 / B 이름→통일 / C 테스트→공유 lib / D 원장→형식 하나 / E compact→통합"

- **S8** 🗣 (에이전트 사용):
  > "서브에이전트 써"

- **S9** 🗣 (모듈화 방향 질문에 대한 응답):
  > "리펙토링 한다고 보면 될듯함, 그리고 이러한 방식은 앞으로 개발에서도 적용되어야 하고."

- **S10** 🗣 (같은 맥락, 이어서):
  > "갈라지는걸 통합하는거도 반드시 해야지, 논리적으로 갈라지는게 맞다면 통합할 부분을 통합하고 갈라지게 하는게 맞고
  > 장치가 부재한곳도 많아"

- **S11** 🗣 (리팩토링 제약 해석 정정):
  > "리펙토링이라고 이야기하긴 했지만 이건 제약의 언급으로 이야기한게 아니었어, 가능하면 이번에 갈아 엎어서 호환을 염두하기 보다는 통합을 염두하도록 하자 앞으로를 위해서"

- **S12** 🗣 (통증 진술):
  > "지금 레포가 너무 무거워"

- **S13** ☑ 선택 (무게의 정체 — 복수 선택):
  > "B. 리포 무게 — 아카이브·테스트 66% (권장 선행), A. 컨텍스트 무게 — 모델이 읽는 6,783줄, C. 규약 무게 — 지켜야 할 것의 가짓수"

- **S14** ☑ 선택 (ST2 의심 게이트):
  > "② 전환 — ST2 채택. 새 규약 문서 0줄·CLAUDE.md 순증 0줄·새 파일 0개. 사본 제거 + 불가피한 잔여에만 항목별 행동 락. 기록은 pull 표면."

- **S15** ☑ 선택 (D1+D4 아카이브 축, 옵션 ③ + 메모):
  > "docs/audits 폴더만 대상으로 하자 이건 정본이 아닌데 꼭 필요한건가? 필요한거면 일단 여기 두는게 아니라 아카이브 폴더에 둬줘 이거 관련된거는 compound 내용일텐데 향후 개발할거야"

- **S16** ☑ 선택 (D5+D9 테스트 축):
  > "② 남기되 '락 순감 금지' 제약"

- **S17** ☑ 선택 (D11 요청 정합):
  > "① '원장' 확정 + Goal 채운다"

- **S18** ☑ 선택 (원장의 정체):
  > "① 아직 없다 — 향후 개발. 원장 메커니즘 자체가 아직 없고 앞으로 만든다. 요청 2행은 이번 범위에서 연기"

- **S19** 🗣 (docs/audits 처분):
  > "이거만 아카이브 행, 결국 이거도 해결 후 제거할거임"

- **S20** ☑ 선택 (T33 audits 이동 방식):
  > "② 통째 이동 + 참조 3종 같이 수정"

- **S21** ☑ 선택 (D6 새 파일 0개):
  > "① 규약·강제 문서에만 적용 — references/ 분할과 공유 lib는 허용"

- **S22** 🗣 (D2 LD8 경계):
  > "파기가 맞다는거야 / 재논쟁 금지 아닌거로 하자, 그리고 더 논의할거 있으면 이야기 해줘"

- **S23** ☑ 선택 (D10 실행 지점):
  > "① '실행 지점 신설 없음'을 확정 제약으로"

- **S24** ☑ 선택 (락과 실행 정합):
  > "① 사본 제거 우선 — 락은 잔여에만"

- **S25** ☑ 선택 (kill switch 이름 고지 방식, 옵션 ③ + 근거):
  > "3번 이거는 아직은 내가 게인적으로 사용하는 플러그인들임"

- **S26** 🗣 (프레이밍 정정):
  > "문제는 중복도 포함이야"

- **S27** 🗣 (범위 점검):
  > "우리가 진행한다고 했던 통합과 모듈화 안하는거 아니지?"

## 7. Next Action

superpowers가 설치돼 있으면 이 brief를 context로 `superpowers:brainstorming`을 호출해
해답공간(`-design.md`)으로 넘어간다. 설계가 먼저 답해야 할 것은 §3의 OQ1~OQ7이며,
그중 **OQ1(잔여 락을 무엇이 돌리는가)**이 Goal 3·4·7의 실효성을 결정한다 —
C16이 실행 지점 신설을 막았고 C17이 락을 잔여로 한정했으므로, 그 잔여가 언제 검사되는지가
정해지지 않으면 Goal 7(다시 무거워지지 않게)이 이름만 남는다. C21(stale 방지)이 걸린 곳도 여기다.
설치돼 있지 않으면 이 brief가 완결 산출물이며 다음 작업의 입력으로 직접 쓴다.
