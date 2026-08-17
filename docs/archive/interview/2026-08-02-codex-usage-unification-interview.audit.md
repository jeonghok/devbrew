---
type: interview-audit
payload: 2026-08-02-codex-usage-unification-interview.md
created_at: 2026-08-02
session_id: 0560cf3d-b44c-41ba-8b01-ed0204795e0d
source: spec-distill conducting-interview v0.24.4
---

# Codex 사용 방식 통일 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — 재구성: 값이 아니라 호출 규약의 단일 소유 지점 부재가 병목. 사용자가 A(전면 위임+회귀락) 선택으로 구조적 산출물 확정 — S3
- floor:landscape — closed — web sweep 2회(session 8/8): codex CLI 플래그 정본 + 모델 은퇴 스케줄(GPT-5.4 2026-08-31 Codex 은퇴) 인용 확보
- floor:skepticism — closed — 의심 방향='통일은 곧 코드 통합'. 수동 steelman(agent dispatch 금지 + web 세션캡 소진으로 degrade): 사본 차이가 규약(kill switch 네임스페이스)·emit 스키마 실제 분기·plugin-audit 재사용 명시금지(SKILL.md:94)·버전결합이 새 stale. 사용자 판정=switched(전면통합 기각, 하이브리드 채택) — S5
- floor:blind_spot — closed — inline premortem(agent dispatch 금지로 degrade) B1~B6 표면화 + 전부 codebase 실증. B1 락 자기함정(주석 매치)·B2 테스트/mock 고아화·B3 `-s read-only` 인자화 금지·B4 blind 파괴 재발·B5 실행값 불가시(→S6로 해소)·B6 known-bad regex stale. 가정 '5곳이 전부'는 반증 시도 후 확인됨
- floor:open_questions — closed — OQ1~OQ6 박제 — 실행값 수집 경로 실측 / 공용 web kill switch 네임스페이스 / 통합 detect 소유 플러그인 / known-bad regex 갱신 경로 / 테스트·mock 수렴 / 코드리뷰 웹의 P21 완화책
- derived: N/A

## 2. Budget

- probe_count: 4 / cap 12
- web_sweep_count: 0 / 4 (sweep 2회 실행 후 각각 reset)
- web_search_count: 8 / 8 (세션 상한 도달 — 이후 web 근거는 수집 불가, steelman·premortem·방향성 리뷰어가 codebase 근거로 degrade)
- brief_critic_rounds: 2 / cap 2 (도달 → forced escalate)
- 모델 호출 실사용: 에이전트 5 (direction 1 + critic 3 + readback 1) + codex 4 (direction 1 실패 + fidelity 3) = **상한 9 중 9**

## 3. Steelman 원문

> **degrade 고지** — 이 세션은 "사용자 요청 없이 Agent 도구 호출 금지" 지시가 걸려 있어
> `steelman-builder` subagent를 dispatch하지 않았다. 아래 ST1은 orchestrator가 codebase 근거로
> 직접 구성한 **수동 steelman**이며, 독립 에이전트 출력의 verbatim이 아니다. R3 게이트의 판정
> 단계(사용자가 defend/switch/defer 중 선택)는 정상 수행됐다.

#### ST1 — "통일하려면 사본을 합쳐야 한다"에 대한 반대 케이스 (수동 구성)

> **대안 진술:** codex 관련 중복 코드를 하나로 합치는 것(전면 DRY)은 이 리포에서 stale을 줄이지
> 않고 형태만 바꾼다. 사본을 유지하되 계약을 통일하고 drift를 락으로 잡는 편이 낫다.
>
> **근거 1 — 사본의 차이가 사고가 아니라 규약이다.** `detect_codex.sh` 두 사본의 실질 차이는
> kill switch 이름 하나(`DEVBREW_DISABLE_QG_CODEX` vs `DEVBREW_DISABLE_SPEC_DISTILL_CODEX`)다.
> CLAUDE.md §네이밍·보안은 kill switch를 `DEVBREW_DISABLE_<PLUGIN>` 네임스페이스로 규정하고
> "어떤 훅도 자신의 kill switch 존중을 거부할 수 없음 — kill switch는 보안 컨트롤"이라고 못박는다.
> 합치면 플러그인별 kill switch가 호출부 인자로 강등된다.
>
> **근거 2 — findings 변환기는 동작이 다르다.** `codex_findings_to_yaml.py`는 210 vs 208줄이고
> 차이가 주석이 아니다: spec-distill 사본은 emit keyset에 `category`·`target_section`(design-doc
> 리뷰 어휘)을 추가한다. 통합하려면 파라미터화해야 하고, 그 순간 두 소비자의 findings 스키마가
> 한 파일에서 결합된다.
>
> **근거 3 — 통합해도 다섯 번째 표면은 커버되지 않는다.** plugin-audit의 codex 호출은 스크립트가
> 아니라 SKILL.md 프로즈 지시다(`SKILL.md:92`). 나아가 `SKILL.md:94`는 qg 러너 재사용을 **명시적으로
> 금지**한다 — "그 스크립트는 diff-shaped이고 최신 spec의 AC를 자동 주입해서 blind를 깬다".
> 공유 모듈을 만들어도 이 표면은 신규 작성이지 통합이 아니다.
>
> **근거 4 — 버전 결합이 새 stale 표면이다.** 공유하면 quality-gates의 수정이 spec-distill을 조용히
> 깨뜨릴 수 있고, 이를 막으려 버전 하한 + degrade 경로를 다시 깔면 없애려던 복잡도가 형태만 바꿔
> 돌아온다. 선례(`plugin-audit/README.md:25-28`, quality-gates ≥ 2.12.0)가 그 비용을 보여준다.
>
> **반대편(통합)의 강한 근거:** 사용자가 실제로 겪은 병이 정확히 drift다 — `medium` 핀 제거 판단이
> 4개 러너 중 1개에만 반영됐고 그 상태가 남아 있었다. drift 락만 걸고 사본을 유지하면 "무엇이
> 정본인가"가 정해지지 않아 다음 drift 때 수렴 방향을 다시 판단해야 한다.
>
> **사용자 판정: switched** — 전면 통합(U)을 기각하고 하이브리드(H)를 채택. detect는 합치고,
> findings 변환기는 사본+drift 락, plugin-audit는 러너 신규 작성. ⟨S5⟩

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-08-02) — Step A 첫 실행 exit 0 (`payload_body_lines_excl_verbatim: 67`)
- check_verbatim_coverage.py — exit 0 (2026-08-02) — 리뷰 진입 첫 액션, `{"missing_ids": [], "not_contained": [], "advisories": []}`
- check_brief.py gate — pass (2026-08-02) — 방향성 C4 재결정 반영 후 재실행 exit 0 (`payload_body_lines_excl_verbatim: 74`)
- check_verbatim_coverage.py — exit 0 (2026-08-02) — S8~S11 append 후 재실행, 위반·advisory 0

## 5. 프로세스 로그

- round 0: (a) factual auto-confirm — `plugins/` 전수 grep으로 codex 표면 5곳 실측, `detect_codex.sh`·`codex_findings_to_yaml.py` 사본 diff, 로컬 codex 0.145.0 확인
- round 0: (a) web landscape sweep #1 — 공식 문서 308 이전(developers.openai.com → learn.chatgpt.com) 감지, 리다이렉트로 본문 미획득
- round 0: (a) web landscape sweep #2 — `codex exec` 플래그 정본 + 모델 은퇴 스케줄 확보. 세션 상한 8/8 도달
- round 1: (b) judgment — "항상 높은 모델로"의 축(모델 vs 강도) 질문. 사용자가 선택 대신 되물음(S2) → 로컬 `~/.codex/config.toml` 실측(`gpt-5.6-sol`/`xhigh`)으로 답하고 재제시 → A 선택(S3). teach-heavy(모델 은퇴 스케줄 인용) 발화
- round 2: (b) judgment — "codex 없으면" 해석 2갈래(확인 절차 통일 vs fail-closed). 게이트 결함 실측(sd brief 1줄검사 / plugin-audit 부재) 제시 → ㉠ 선택(S4). teach-heavy(detect가 실제로 잡는 실패는 미설치가 아니라 auth·버전·재귀) 발화
- round 3: (c→b) 수동 steelman + judgment — ST1 제시, cross-plugin 의존 선례(`plugin-audit/README.md:25-28`) 확인 → H 선택(S5)
- round 4: (b) judgment ×2 — inline premortem B1~B6 제시 후 실행값 가시성(S6) + 웹검색 통일(S7) 결정
- degrade: steelman-builder:agent-dispatch-금지 · blind-spot-prober:agent-dispatch-금지 · web:session-cap-8/8-소진
- round 5 (brief 리뷰 1단계 방향성): `brief-direction-reviewer` 6 findings(D1~D6) → orchestrator가 6건 전부를 리포 파일로 **직접 재검증**(액면 수용 안 함) → 전부 사실 확인 → D3·D6은 정정으로 채택, D1·D2·D4·D5는 사용자 C4 재결정(S8~S11) → payload 개정 → 게이트 2종 재실행 pass
- **★ 이 인터뷰의 최대 수확**: 방향성 리뷰가 brief의 **전제 3개를 반증**했다. (1) "5표면" 실측이 틀림 — `plugins/**/tests/` 필터 제외로 `qg/tests/spike/test_codex_json_extraction.sh:30`의 4번째 medium 핀을 놓침. (2) 근본원인 진술이 틀림 — 소유자는 있었고(2026-07-15 설계 `:175` 명시 지시 + OQ2 검토) 값이 틀렸으며 테스트(`test_run_spec_codex_reviewer.sh:35`)가 고정 중. (3) 같은 날 형제 문서(sweep 설계 + census)가 Goal 2를 이미 소유 — orchestrator 메모리에 해당 핸드오프가 있었으나 연결하지 못함.
- **★ 재발한 사각지대**: census `:204-205`가 *"plugins/*/tests/는 최초 10축에 없었다 — 축 설계 자체의 사각지대"* 로 이미 기록한 실패를 이 인터뷰가 그대로 재발시켰고, sweep 설계의 판별 질의(`:74`)도 같은 사각을 공유한다. 락 범위를 `plugins/**`의 모든 `codex exec` 실행 라인으로 넓히는 것이 이 사이클의 compounding 산출.
- round 6 (brief 리뷰 2단계 충실도 round-1): critic 8건 + codex 8건 → `fidelity_verdict: needs_revise` (critic·codex 둘 다 needs_revise, `codex_degraded: false`, `critic_verdict_unrecoverable: false`). **두 리뷰어가 독립적으로 수렴한 지점 5개**: C6 evidence_unsupported(high×2) · C6 provenance_mislabel · S5 omission(high×2) · C8 distortion · C4 약화.
- **★ 구조 게이트가 놓친 클래스**: `check_brief.py`는 evidence 앵커의 *존재*만 확인하므로, **실재하지만 그 statement를 뒷받침하지 않는 앵커**(C6 `evidence: S11`)를 잡지 못했다. 그 결과 S5·S6 두 개의 ☑ 사용자 선택이 어디에서도 인용되지 않는 **고아 앵커**가 됐고, S5의 내용은 §1 Non-goal에 살아남되 근거가 사용자가 아니라 2026-07-15 설계 문서로 귀속돼 **사용자 출처가 소실**됐다. 분리 리뷰가 없었으면 그대로 나갔을 결함.
- round 6 수정: C6 evidence를 S6으로 교정 · C9(S5 하이브리드 선택) 신설 · C10(S1 공식문서·모델지정 점검) 신설 · C11(S1 가용성 확인) 신설 · C4를 "공용 게이트 1개 + 게이트 결함 메우기"로 복원 · C8에서 "머지" 강화와 브랜치명을 제거하고 ✎로 분리 · §0 "확정"을 "잠정 결정(전부 provisional)"으로 · §1 Non-goal의 사본유지 근거를 사용자 선택(C5·C9)으로 재귀속 → 게이트 2종 재통과(`payload_body_lines_excl_verbatim: 78`) → `brief_critic_rounds: 1` bump → fresh critic + codex 재실행(수정된 바이트 대상)

- round 7 (충실도 round-2): critic 5건 + codex 1건 → `needs_revise`. `evidence_unsupported`·`authority_syntax` 클래스 **소멸**(C6 evidence 교정이 먹힘). 신규 적발 중 가장 무거운 것: **§1 Non-goal의 논리 반전** — *"codex를 필수 의존성으로(fail-closed) — C11의 두 독해 중 C4가 고른 쪽"* 이라 썼으나 C4(S4)에서 사용자가 고른 것은 그 **반대쪽**이었고, 같은 문서 §2 주석과 정면 자기모순이었다([[feedback_fix_introduces_regression]] 실증 — round-1 수정이 만든 새 결함). C8 확장 + C12·C13 신설 + xhigh provenance 교정 + Non-goal 반전 수정.
- round 8 (충실도 round-3, cap 도달): critic 6건 + codex 2건 → `needs_revise`, `can-redispatch` = `{"escalate": true}` → **Step B forced escalate**. 이 라운드가 적발한 것 중 둘은 *round-2 수정이 만든 새 결함*이다: (1) S2를 `"xhigh로 …"` 로 절단 인용해 **의문형을 가려** 사용자 증언처럼 읽히게 함, (2) C13에 `"(tests 포함)"` 이라는 모델 확장을 넣고 `source: verbatim`으로 표기. 나머지: D3·D6이 사용자 앵커 없는 모델 자기수정인데 D1/D2/D4/D5(사용자 재결정)와 같은 번호 계열 공유 · `sweep 설계 S1/AC2` 토큰이 §6의 `S1` 앵커 네임스페이스와 충돌 · S5/S7의 기각된 입장이 **사용자 선택이었다는 사실**이 §5에서 소실.
- round 8 후속: 위 5건을 반영(C13 축소 + ✎ 분리 · S2 전문 인용 · D3/D6 앵커 부재 명시 · `변경항목 ①`로 개명 · §5 기각 줄에 "사용자가 골랐던 입장" 명기). **cap 도달로 이 수정은 재검증되지 않았다** — Step B에 그대로 고지.
- **★ [[feedback_fix_introduces_regression]] 3라운드 연속 실증**: round-1 수정이 round-2 결함(Non-goal 반전)을, round-2 수정이 round-3 결함(S2 절단 인용, C13 verbatim 오표기)을 만들었다. 매 라운드 내 수정이 새 회귀를 낳았고, 그것을 잡은 것은 매번 **fresh 리뷰어**였다.

- round 9 (Step B 이후 사용자 재개, S12): 사용자가 *"codex detect 말고 다른 것은 구현 진행 내용을 적었냐"* 고 물어 층별 커버리지를 세어 보니 **② 프롬프트 빌더와 ⑤ 병합/수집이 파일 이름만 있고 문제가 미실측**이었다(③ 러너 최다, ① detect 그다음, ④ 추출 부분 공백). 사용자가 "지금 실측"을 선택 → 두 층을 직접 읽어 §2 표·§3·§5 갱신, **OQ7 재정의 + OQ8·OQ9 신설**.
  - **② 실측**: Python 빌더 4개 전부 *"경로만 받고 argv/stdin inline 금지 → `read_text` + `str.replace`"* 를 지키나 **네 곳에 각자 재서술**(정의 1곳 없음). 갈라지는 것 2개 — severity vocab(qg `CRITICAL/IMPORTANT/SUGGESTION` vs sd `block/high/medium`, 2026-07-15 설계가 의도적 분기로 규정) · **P21 untrusted-data preamble은 `plugin-audit` 하나만 보유**.
  - **★ 두 위협 모델의 단어 충돌**: 네 빌더가 주석에 적은 "injection 안전"은 *argv/stdin → 셸* 주입이고, `codex-prompt-preamble.md`가 막는 것은 *읽는 내용 → 모델 지시* 주입이다. 같은 단어라 **방어가 있는 것처럼 읽힌다** — qg 코드 diff·qg artifact·sd design·sd brief 네 경로가 미신뢰 콘텐츠를 codex에 먹이면서 후자의 방어가 없다(OQ9). C7이 문서/brief 경로에 웹을 켜므로 노출이 겹친다.
  - **⑤ 실측**: 파일 수가 아니라 **이름이 문제**. 같은 사실("codex가 이번에 못 돌았다")을 `codex_failed`(30) · `sources_failed`(20) · `codex_degraded`(4) · `codex.ran`(4) · `codex_yaml_missing`(1) 다섯 이름으로 부른다. C6의 "실행값이 배너까지 닿는다"는 이 경계를 전부 지나야 성립(OQ8).
  - **④ 부가**: last-fenced-block 안티인젝션은 추출기 3/3 보유 — 이 층은 규약이 이미 성립. 단 `extract_codex_artifact_yaml.py`는 C9 범위 밖.
  - **이 round 9 추가분은 리뷰되지 않았다** — 충실도 cap(2)이 이미 소진된 뒤의 저술이다. Step A 구조 게이트와 원문 완전성만 통과했다(gate pass, `payload_body_lines_excl_verbatim: 86`).
  - round 9 중 자기 적발: state의 S12를 라벨+설명 합성으로 적어 `check_verbatim_coverage.py`가 `not_contained: ["S12"]`로 차단 → 사용자가 실제로 고른 **라벨**로 교정. 원문 대조 게이트가 저자의 과잉 합성을 잡은 실례.

- round 10 (S13 — brainstorming 지시 못 박기): 사용자가 5개 층 전부 조사·최적화 / codex 표준·레퍼런스 기반 성능·토큰 최적화 / **마켓플레이스 통합 모듈 가능성 외부검색 조사** / 서브에이전트 활용을 지시하고 brief에 "반드시 하게끔" 남기라고 요구 → **C14~C17 신설 + OQ10·OQ11 신설 + §7 Next Action을 "brainstorming이 반드시 수행할 것" 4항목으로 재작성**.
  - **★ Non-goal이 조건부로 전환됨**: §1의 *"`detect_codex.sh`·`codex_findings_to_yaml.py` 물리 통합 금지"* 는 이제 **조건부**다. 2026-07-15 §14가 기각한 것은 *"spec-distill이 qg를 prerequisite로 선언하고 **경로로 직접 호출**"* 이라는 한 가지 메커니즘이고, **마켓플레이스에 발행되는 공유 모듈**은 그때 검토 대상이 아니었다. OQ10이 그 제3의 형태를 판정하며, "가능"으로 나오면 C5·C9가 사용자 재결정 대상이 된다. 승인된 기각을 존중하면서 그 기각의 **적용 범위를 정확히 좁힌** 사례.
  - OQ11 신설(토큰 구성 미실측) — 빌더 5개가 codex에 보내는 토큰량이 한 번도 측정된 적 없고, `--output-schema`가 현행 fenced-JSON 3단 fallback을 대체 가능한지도 미확인.
  - **round 10 추가분도 리뷰되지 않았다** — 충실도 cap 소진 후 저술. 구조 게이트 pass(`payload_body_lines_excl_verbatim: 96`), 원문 완전성 pass. 제약 17건 / OQ 11건 / `confirmed` 0건.
  - 근거 원칙 연결: C15는 [[feedback_prefer_mature_references_over_scratch]]의 인스턴스 — *"새로 만들기 전 외부 성숙 레퍼런스를 딥서치해 가져와라"*.

### 미반영 finding (저자 임의 기각 아님 — Step B 사용자 판정 대상)

- **critic `insertion` / frontmatter 주석** — *"`# confirmed 0건 — 사용자가 전부 잠정으로 판단`은 사용자가 하지 않은 판단을 사용자에게 귀속한다"*. **정당한 지적이나 이 brief에서 고칠 수 없다**: 이 문구는 `templates/interview-brief-template.md`가 상속시키고 `check_brief.py`가 **한 줄 전체 일치**로 요구하는 sentinel이라, 지우거나 바꾸면 구조 게이트가 red를 낸다(`conducting-interview` Step A 3 — sentinel은 *확인을 건너뛴 brief*와 *사용자가 전부 잠정으로 판단한 brief*를 가르는 유일한 표식). 즉 **하니스 문구의 결함**이지 이 문서의 결함이 아니다.
- **compounding 후보 (Law 3)** — sentinel 문구를 사용자 귀속이 아닌 harness 귀속으로 바꾸는 것(예: `# confirmed 0건 — 확정은 Step B 사용자 확인으로만`). 템플릿·`check_brief.py`·`conducting-interview` SKILL 세 곳을 같은 커밋에서 고쳐야 한다.

### brief 리뷰 라운드 (reviewing-brief, v0.24.0)

(순수 텔레메트리 — **기록이며 게이트 통과 조건이 아니다.**)

- 방향성: Claude 6건 / codex 0건(런타임 실패) — 사용자 재결정 4건(S8·S9·S10·S11), 모델 자기수정 2건(D3·D6)
- 충실도 기록(게이트 아님, 마지막 관측 verdict만 기재): `needs_revise` — critic 6건 / codex 2건 — 재라운드 2/2 (cap 도달 → forced escalate)
- 냉독: gap 2건 — **G3 ×1 확정**(C10 "codex 공식 문서를 보고 점검 + 모델 지정·설정 점검"이 요약에 전혀 등장하지 않음) + **G3 ×1 경계**(C2의 "항상 높은 모델로"가 목적이 아니라 수단인 "전면 위임"으로만 재현). G1·G2·G4·G5 해당 없음.
- 냉독 부가 관측(5 클래스 밖 — 가독성 장애물): ① §5의 `ST1` 앵커를 payload만 읽는 독자가 해소할 수 없음(ST1은 audit §3에 있음 — **payload/audit 분리의 구조적 귀결**) ② "Step B"가 문서 안에서 미정의 ③ C6의 "배너"가 어느 표면인지 불명 ④ C12가 제약이 아니라 승인 도장처럼 읽힘 ⑤ "sweep 설계의 변경항목 ①/AC2"를 외부 문서 없이 검증 불가
- degrade: `direction_reviewer:웹 예산 소진(session 8/8)` · `codex:방향성 co-review 10분 타임아웃 kill` · `critic:재리뷰 상한 2 초과, 이후 수정 미검증`. fallback 채널 비어 있음(원장 기록 전부 성공).
- 격리: zero-tool probe `ZERO_TOOL_OK` — `codex_isolated: false`(codex는 repo를 읽으므로 프레이밍 격리 미보장, verdict 입력 아님 · 저자용 라벨)
