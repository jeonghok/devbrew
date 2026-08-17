---
name: spec-distill-brief-handoff-redesign
type: interview-audit
created_at: 2026-07-25
session_id: fd4b96a9-264b-4e88-9eb1-f622686709f5
payload_file: 2026-07-25-spec-distill-brief-handoff-redesign-interview.md
---

# Interview Audit — spec-distill brief handoff 재설계

> **이 파일은 프로세스 텔레메트리다.** 다음 stage는 읽지 않아도 된다 — 행동 가치가 있는 내용은
> 전부 payload 파일에 있다. 여기 있는 것은 인터뷰가 제대로 굴러갔는지의 증거뿐이다.
> (분할선: *재논쟁 차단에 쓰이는 것은 payload / 순수 프로세스 텔레메트리만 audit* — R3 게이트에서 확정)

## Coverage Ledger

- floor:root_problem — closed — 사용자 redirect(probe 1)로 축이 "무엇을 지울까"에서 "컨텍스트 엔지니어링 재배치"로 교정됨. 증상(과거 brief 3건 LD 5~9건, 전부 해답공간 결정)과 원인(정보 문법·배치) 분리 완료.
- floor:landscape — closed — web sweep 4회 + 코드베이스 auto-confirm 5건. 인용 URL 10개 payload §3에 기록. 결정적 확인: superpowers 6.1.1에 interview/brief/locked_directions 언급 0건.
- floor:skepticism — closed — steelman-builder(conf 0.72)가 D1을 공격, 사용자 게이트 판정 **defended**(분할선 이동으로 흡수). 전문 아래 수록.
- floor:blind_spot — closed — blind-spot-prober(C8 1회, conf 0.75) 3 HA + 4 FM. 채택 5 / 부분반박 1. payload §4에 판정과 함께 기록.
- floor:open_questions — closed — OQ1~OQ7 payload §6에 박제. OQ1(권위 다이얼)은 인터뷰에서 묻지 못했음을 명시.
- derived:problem-solution boundary criterion — closed — 2축 판별식(출처 + 문법) 확정. probe 2가 probe 1의 주제기반 기준을 반증한 경위 포함.
- derived:downstream consumer contract — closed — brainstorming 6.1.1 grep 0건으로 silent coupling 부재 확인. locked_directions[] 제거는 소비자 파괴 없음.
- derived:brief-review agent contract (Law 2) — closed — D2(critic)/D3(readback) 2단 파이프라인 확정. cap·판정자·물리배치는 OQ2/OQ3/OQ6으로 이월.

## 예산 기록

- probe_count: 4 / effective_cap 12 (C1 escalation 미발화)
- web_search_count: 4 (session cap 8) / sweep reset 1회
- coverage-mapper dispatch: 1회 (probe 1) — 제안 4건 중 **admit 3 / decline 1**
- blind-spot-prober dispatch: 1회 (C8 준수)
- steelman-builder dispatch: 1회 (한 방향당 1회 규약 준수)
- non_user_streak 최대: 2 (threshold 3 미도달 — 강제 (b) 라우팅 미발화)

## coverage-mapper decline 사유 (G2 orchestrator 판정)

제안 "포맷 변경의 버전·마이그레이션 범위" **decline** — SemVer bump/CHANGELOG는 devbrew CLAUDE.md가
이미 강제하는 보편 규칙이라 주제-도출 차원이 아니고, 기존 brief 3건은 재소비되지 않는 역사적
산출물이라 마이그레이션 표면이 얇다. 잔여는 payload OQ5로 박제.

## Skepticism Log — steelman 전문 (verbatim, 약화·편집 금지)

**대상 방향:** brief를 2개 파일로 분리 (D1)
**trigger:** landscape 모순 — blind-spot-prober가 multi-document 정보 유실 + 하류 트리거 0건 실증
**verdict: defended** (원안 방어, 분할선 이동)

> **alternative_statement:** "brief는 단일 파일로 유지한다 — 분리 대신 한 파일 안에서 (i) 순서 재배치(권위 있는 결론을 앞/뒤에, 감사 흔적은 문서 끝 부록으로), (ii) 권위 문장→증거 문장으로 문법 교정, (iii) 분량 압축으로 '난잡함'을 해결한다. 두 번째 파일을 만드는 것은 정보를 지우지 않고 '읽힐지 불확실한 곳'으로 옮길 뿐이다."

> **strongest_case:**
> (1) lost-in-the-middle의 검증된 완화책은 파일을 쪼개는 것이 아니라 컨텍스트 내부 재배치(reordering/rerank)다 — U자형 attention 문제는 같은 컨텍스트 안에서 중요 정보를 양 끝에 배치하면 완화되며, 이는 정확히 (i)가 하려는 것이다.
> (2) context rot 연구는 증거가 '유리하게 배치돼도' 입력 길이 자체가 늘면 정확도가 떨어짐을 보인다(0.92→0.68) — 즉 실제 레버는 파일 개수가 아니라 총 볼륨이고, 이는 (iii) 압축이 (ii) 문법 교정과 함께 정확히 겨냥하는 지점이다.
> (3) 분리안의 read-path 리스크는 이미 trigger 자체가 실증했다 — brainstorming 6.1.1이 두 번째 파일명을 발견할 신호를 0건 가지므로, 분리는 이론적 위험이 아니라 이 구체적 파이프라인에서 '거의 확정적 유실'이다. 단일 파일은 이미 검증된 로드 경로 하나를 100% 상속하지만, 분리는 두 번째 경로를 처음부터 새로 만들어야 한다.

> **weakness_of_current:** "2-파일 분리(interview.md + audit.md)의 가장 약한 지점은 trigger 자체가 이미 제시한 (b)다 — brainstorming 6.1.1이 두 번째 파일을 열 명시적 트리거를 0건 가진다. 이는 '정보 유실 가능성'이 아니라 '설계상 거의 확정된 유실'이다. Tried & Discarded와 Skepticism Log를 audit로 보내는 것은 정확히 '다운스트림 재탐색 차단'이 목적인데, 그 파일이 열릴 것이라는 보장이 없다면 목적 자체가 구조적으로 성립하지 않는다 — sync 의무(두 파일을 갱신할 때마다 정합 유지)까지 추가로 진다는 점에서 이중으로 약하다. 분리가 정당화되려면 최소한 '1번 파일이 2번 파일 존재를 명시적으로 assert'하는 강한 상호참조 메커니즘이 필요한데, 그렇게 되면 사실상 단일 논리적 문서를 두 물리 파일로 나눈 것일 뿐 이점이 사라진다."

> **자기 약점 (steelman 본인 서술):** "'난잡함' 문제 자체는 아직 미해결로 남습니다 — 사용자가 애초에 분리를 택한 이유가 '감사 흔적이 읽기 동선을 오염시킨다'였는데, 단일 파일 내 재배치·압축이 그 체감 난잡함을 실제로 얼마나 줄이는지는 이 리포지토리의 spec-distill 자체 A/B 데이터가 아니라 일반 LLM-포지션-바이어스 문헌에서 유추한 것입니다."

**evidence:**
- https://arxiv.org/html/2510.10276v1 — lost-in-the-middle은 U자형 위치 편향이며 표준 완화책은 재배치(reordering)다.
- https://www.tmls.nyc/research/context-rot-mechanistic — 유리한 위치에서도 입력이 늘면 정확도 0.92→0.68.
- https://intuitionlabs.ai/articles/llm-position-bias-primacy-recency-effects — 완화 기법 목록에 파일 분리는 없다.
- https://www.getmaxim.ai/articles/solving-the-lost-in-the-middle-problem-advanced-rag-techniques-for-long-context-llms/ — 단일 문서 내 청크 경계 배치만으로도 완화 가능.

**orchestrator의 방어 논거 (사용자 판정 근거):** steelman이 공격한 것은 분리 자체가 아니라 orchestrator가
그은 **분할선**이었다. `Coverage Ledger`·예산 카운터는 어떤 독자에게도 행동가치가 없는 순수 텔레메트리이고,
`Tried & Discarded`와 skepticism **verdict**는 재탐색 차단 장치이므로 payload다. 이 둘을 같은 통에
담은 것이 orchestrator의 오류였다. 분할선을 이동하면 steelman (3)이 겨눈 지점이 사라지고,
skepticism을 *한 줄 verdict = payload / 원문 transcript = audit*으로 쪼개면 (2)의 볼륨 압축도 달성된다.

## codex 독립 리뷰 (D4·D5 dogfood, 2026-07-25)

`codex exec -s read-only -c model_reasoning_effort=high`, codex-cli 0.144.6. 프롬프트는 직접 저술 —
기존 `build_spec_codex_prompt.py`는 design-doc 전용 체크리스트라 미사용(재사용 시 AC 주입이 모델
다양성을 죽인다). audit 파일은 **의도적으로 미제공**(저술 세션의 자기 근거라 독립성 오염원).
두 축 요구: (A) 충실도 — §원문 verbatim 대비 왜곡·누락·삽입·오라벨·해답선점·내부모순.
(B) 방향성 — 사용자가 잡은 방향 자체가 틀렸을 가능성, 전체 조망.

### 결과 요약 — 12건, 실질 전부 유효

**Axis A (충실도) 5건, 전부 수용:**

| 지적 | 조치 |
|---|---|
| C3·"산출물만 명명"이 ☑로 표기됐으나 §원문의 ☑ 기록은 3건뿐 — **문서가 출처 세탁을 막겠다면서 스스로 세탁** | §원문에 누락 선택 5건 추가(총 8건) |
| 재구성한 문제(`ROOT_CAUSE`)·"인과 확정"이 ✎ 없이 확정 사실처럼 제시 | ✎ + "가설" 표기, OQ11로 연결 |
| **C1 위반** — "바로 이해되는 게 최상단"인데 원문 46줄을 지나야 문제정의 도달 | `0. 한눈에` 스냅샷 신설(13줄) |
| C5 위반 잔존("되묻기도 금지"·"비교할 것"·"반드시 생산"·"불변 영역") + 에이전트 파일을 필수 산출물로 넣고 바로 아래 "배치 미결" 모순 | 지시문 제거, 표를 *역할 목록*으로 재규정 |
| "정보량이 아니라 문법과 배치"(goal) vs "진짜 레버는 총 볼륨"(landscape) 내부 모순 | non-goal에서 삭제, 분량 감축을 유효 후보로 명시 |

**Axis B (방향성) 7건:**

| 지적 | 처리 |
|---|---|
| **출처와 결정상태를 한 축으로 묶어 새 LD가 될 위험.** "사용자가 말했다"≠"확정 제약이다". 대안: source × role × status 직교 | ☑ **수용 → C6**. source × status 2축 도입(role은 미채택 — 현 항목들이 전부 constraint/decision이라 3축은 과잉) |
| root cause가 배치보다 **producer–consumer 계약**. `SKILL.md` compact handoff가 "LD 보존"을 직접 주입하는데 미검토. 대안: adapter만 최소 변경 후 과거 brief로 회귀 측정 | ☑ **OQ11로 박제**, 방향 유지 |
| **D1 재도전** — 분할선 이동 후 audit엔 순수 텔레메트리만 남는데 영구 문서로 둘 이유가 약함. 대안: 단일 payload + session-local state | ☑ **OQ12로 박제**, D1 유지 |
| **D2(payload-only)와 D5(방향성)가 충돌** — (b)는 외부 근거 조사를 요구. codex 부재 시 축이 사라지는 fail-open | OQ8에 통합 |
| readback은 가독성 테스트이지 충실도 검증이 아님. hard verdict 부적합 | **OQ10 신설** |
| **verbatim 불변식이 `CLAUDE.md` P21과 충돌** — secret placeholder 치환을 막는다. 대안: "내용 불변"이 아니라 "provenance 보존" | 수용 — Next Action의 불변식 서술 교체 |
| "중간 30%p 하락"을 Anthropic 글 출처로 인용했으나 그 글엔 그 수치가 없음 | 수용 — 인용을 arXiv 2510.10276으로 교체하고 적용 한계 명시 |

### codex 총평 (verbatim)

> "현재 상태로 downstream에 넘기기에는 충분히 sound하지 않다. 가장 큰 위험은 '출처를 보존한다'는 좋은 목표가
> '사용자 출처이면 권위 있는 결정'이라는 새 문법으로 변하면서, 제거하려던 LD fixation을 🗣/☑ 아래에
> 재구축하는 것이다. 먼저 허위 ☑ 항목과 행동 규약을 제거하고, 출처·의미 역할·결정 상태를 분리해야 한다."

### 이 실행이 증명한 것

같은-계열 리뷰(blind-spot-prober·steelman-builder)와 실행 검증(게이트)이 **모두 통과시킨 문서**에서
codex가 12건을 냈고, 그중 C1 위반·출처 세탁·판별식 단일축 결함은 **설계의 뼈대를 건드리는 것**이었다.
D4(별-모델)와 D5(방향성 축)가 도입 즉시 값을 했다.

## 게이트 실행 결과 및 조항별 판정 (payload OQ5에서 이관, C5)

`python3 plugins/spec-distill/scripts/check_brief.py gate <payload>` — 2026-07-25 실행, **exit 1**, 8항목 실패.
각 실패에 대해 *게이트를 고칠 것 / brief를 고칠 것*을 판정했다.

| 게이트 실패 | 판정 | 근거 |
|---|---|---|
| `2. Locked Directions` 섹션 필수 | **게이트를 고친다** | 이 섹션이 해악의 원인이고 제거가 설계 목표다 |
| `locked_directions` frontmatter 키 필수 (`check_brief.py:214-215`) | **게이트를 고친다** | 소비자 0건(brainstorming 6.1.1·6.2.0 grep 확인). 형식 부채일 뿐 |
| `1. Reframed Problem` | **게이트를 고친다** | §0(원문 verbatim + 재구성) + §1(goal)로 분해됨. 원문 보존이 critic의 판정 근거라 되돌릴 수 없음 |
| `7. Tried & Discarded` | **게이트를 고친다** | "이미 검토·기각된 것"으로 의도적 rename(권위→증거 문법) |
| `8. Open Questions` / `9. Concrete Next Action` | **게이트를 고친다** (사소) | 번호 재배치 + `Concrete` 삭제 |
| `4. Skepticism Log` · `6. Coverage Ledger` | **게이트를 고치되 ⚠ fail-open 주의** | 아래 별항 1 |
| `## §N.` 헤딩의 `§` 접두사 | **brief를 고친다 (수정 완료)** | 게이트 정규식 `^##\s+\d+\.`을 깨는, 재설계와 무관한 불필요 비호환이었음 |
| `uncited landscape entries: 7` | **양쪽 다** | 아래 별항 2 |

**⚠ 별항 1 — 2파일 분리가 게이트에 fail-open 구멍을 낸다.** `check_brief.py`는 지금 `skepticism_malformed()`와
`coverage_ledger_failures()`로 §4·§6의 **형식을 실제로 검증**한다. 그 둘을 audit 파일로 옮기는데 게이트가
payload만 읽으면 **두 검증이 통째로 증발한다** — 커버리지 원장이 비어 있어도 통과한다. 따라서 2파일 분리는
**게이트 스코프를 두 파일로 넓히는 것과 한 몸**이며, 분리만 하고 게이트를 그대로 두면 조용한 회귀다.
(blind-spot·steelman 둘 다 놓친 지점 — 게이트를 **실제로 돌려서야** 나왔다. 이것이 이 인터뷰에서 게이트
실행이 값을 한 유일한 지점이자, 정적 리뷰가 실행 검증을 대체할 수 없다는 증거.)

**⚠ 별항 2 — 게이트가 "외부 인용"과 "코드베이스 근거"를 구분하지 못한다.** `landscape_uncited()`는 §3의
모든 `- ` 항목에 URL을 요구하는데, 새 포맷은 §3 안에 `### 코드베이스에서 확정한 사실` 하위절을 둔다.
코드베이스 근거에는 URL이 없으므로 7건이 uncited로 잡혔다. 둘은 **성격이 다른 증거**이므로 (a) 섹션을
분리하거나 (b) 게이트가 하위절을 스코프에서 제외하거나 — 어느 쪽이든 설계 결정이 필요하다.

## 출처 표기 규약 — 저술 규칙 및 도구 레시피 (payload에서 이관, C3)

payload에는 2줄 legend만 남기고 아래는 여기에 둔다. **저술 규칙**은 새 템플릿에,
**grep 레시피**는 brief-critic 프롬프트에 반영될 것(§7 산출물 목록 참조).

- **저술 규칙(→ 템플릿)**: 표기는 **줄 맨 앞**(또는 리스트 항목의 `- ` 직후)에만 온다.
  문장 중간에 기호를 쓰면 기계 추출이 깨진다.
- **추출 레시피(→ brief-critic)**:
  ```bash
  grep -nE '^(- )?(🗣|☑)' <brief>   # 사용자 출처 전부, 노이즈 0
  ```
- **무앵커 grep 금지 근거(실측)**: 규약을 표 형태로 두었던 판(§0 56줄 버전)에서
  `grep '🗣'` = 13건이었으나 실제 사용자 발화는 7건이었다. 나머지 6건은 규약 정의표와
  메타 언급. 앵커 적용 시 정확히 12건(발화 7 + 제약 5), 노이즈 0. 이 실측이 payload의
  주장을 앵커 형태로 정정하게 만들었고, 이후 규약 자체가 2줄로 압축되며 표는 사라졌다.

## 프로세스 사고 기록

- **state 경로 이탈 [원인 확인됨]**: canonical `.claude/spec-distill/<sid>/`가 세션 중간부터 EPERM(샌드박스
  해제해도 동일, 퍼미션은 정상 `drwxr-xr-x jeonghokim:staff`). 이후 `plugins/` 읽기까지 확산.
  **원인 = 실행 중 `~/Downloads` TCC 권한 회수** — `stat`은 성공하고 `open`/`listdir`만 EPERM이라
  퍼미션 비트를 봐서는 오진하기 쉽다. 인터뷰 state를 `$CLAUDE_JOB_DIR/tmp/spec-distill/`로 이전해 계속했고,
  영향은 SessionEnd cleanup 훅 미도달 + cross-session resume 불가에 그쳤다. brief 산출에는 무영향.
  **세션 재시작 후 접근 복구 → `check_brief.py` 정상 실행 완료**(exit 1, 실패 8항목 전부 판정 기록).
- **inline python 실패**: `python3 - <<PY` (stdin)가 cwd를 sys.path에 넣어 EPERM. `PYTHONSAFEPATH=1`로 우회.
- **web_budget 미전진 1회**: 상태 파일 접근 실패로 increment가 실패한 채 검색 1회가 나감. 다음 접근 가능
  시점에 사후 정산 시도했으나 경로 자체가 막혀 최종 재구성 시 session=4로 수동 반영.
