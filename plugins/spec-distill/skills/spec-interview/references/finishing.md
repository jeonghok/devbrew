## 종료 — brief 작성 + optional handoff

이 stage 전체가 **확산**이고(라운드 질문·landscape sweep·steelman·blind-spot premortem), Step A 는 그 결과를 **압축**해 payload 로 내보낸다 — 압축 규약 정본은 `${CLAUDE_PLUGIN_ROOT}/references/compression.md` 다. 남기는 불변량은 의도·steering·방향·goal 넷, 나머지 원자료(질문 라운드 전문·landscape 원문·steelman 중간 추론)는 audit 에 남는다.

오늘부터 `interview-brief` 도 이 규약을 **게이트로 집행**한다 — payload 외부 URL 금지(N1a) · §6 은 `S1` 만(N1b) · landscape 원자료는 audit 결속(N2). 집행 지점만 seed 와 다르다: seed 는 `check_seed.py`, brief 는 아래 Step A ⑦ 의 `check_brief.py`.

종료 driver는 **커버리지 원장의 floor 5차원이 전부 `closed`** 이고 마지막 포화 판정이 «포화» 이거나 사용자가 종료를 고른 것이다(고정 라운드 수 아님, G1 · 이중 종료).
다음을 모두 만족하면 brief를 작성합니다:

- floor `root_problem` closed — root_problem 이 사용자 원문 인용으로 닫힘(R1 계열).
- floor `landscape` closed — landscape가 인용과 함께 수집(R2 계열, web sweep 메커니즘 유지).
- floor `skepticism` closed — 의심 방향이 모두 steelman 통과(R3 계열, steelman-builder 게이트 유지).
- floor `blind_spot` closed — blind-spot-prober가 unknown-unknown을 표면화하고 payload §5의 `위험` 항목에 기록.
- floor `open_questions` closed — 미해결 명시(박제, "유추 금지").

각 차원의 status 전이(open→in-progress→closed)와 evidence 기록은 **orchestrator만** 수행하며
(coverage-mapper·blind-spot-prober는 read-only 제안자, Law 2), 상태 파일에 쓰는 동시에
audit §1 `## Coverage Ledger`에 직렬화합니다.

**사용자-승인 박제로 닫힌 floor** — `evidence` 가 `사용자-승인 박제` 로 시작하는 차원은
그 내용을 payload `## 3. Open Questions` 에 한 항목으로 옮긴다. 박제된 차원은 「닫혔다」가
아니라 「사용자가 지금은 안 하기로 했다」이므로, 다음 단계가 그것을 열린 질문으로 본다.

### 분해 판단 — Step A 직전

종료가 정해진 뒤 brief 를 쓰기 전에 이 일을 spec 하나로 할지 나눌지 사용자와 정한다. 나누지 않으면 아래 Step A 부터 지금 흐름 그대로다 — 로드맵을 만들지 않는다.

1. **신호 셋.** 인터뷰가 모은 것에서 세 숫자를 한 줄씩 보인다. 숫자마다 근거 번호를 괄호에 붙인다. 컷오프는 두지 않는다 — 숫자는 판단 재료이고 판정은 사용자가 한다.
   - 따로 승인할 수 있는 덩어리 수 — 확정 항목 · 열린 질문을 닿는 대상(고칠 자리 · 하류 단계)으로 묶은 결정 묶음의 수. 보기: `따로 승인할 수 있는 덩어리 3 (C1 · C4 / OQ2 · RC3 / D5)`.
   - 파일 영역 수 — 조사에서 나온 고칠 자리(`RC<n>` 의 경로)의 플러그인 · 디렉토리 수. 보기: `파일 영역 2 (plugins/a/ ← RC1 · RC2 / shared/ ← RC4)`.
   - 사용자 원문 갈래 수 — 최초 요청(S1)과 이후 발화가 말하는 일의 갈래 수. 보기: `사용자 원문 갈래 2 (S1 · S7 / S12)`.

   이어서 권고 한 줄 — 「하나로 충분해 보인다 — <이유>」 또는 「나누는 게 좋아 보인다 — <이유>」.
2. **판정.** `AskUserQuestion` 하나:
   ```javascript
   AskUserQuestion({
     questions: [{
       question: "신호 셋과 권고를 위에 적었다. 이 일을 어떻게 진행할까?",
       header: "분해 판단",
       options: [
         {label: "spec 하나로", description: "지금처럼 brief 하나를 brainstorming 하나로 넘긴다. 로드맵을 만들지 않는다."},
         {label: "나눈다 — 분해안 보기", description: "에픽 표를 제안받아 고치거나 승인한다. 승인하면 로드맵과 에픽 묶음을 만든다."}
       ],
       multiSelect: false
     }]
   })
   ```
   「spec 하나로」면 Step A 로 간다.
3. **분해안 표.** 에픽 표를 제안한다. 칸은 열하나다:

   | 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 |
   |---|---|---|---|---|---|---|---|---|---|---|

   - 번호는 `<대문자><숫자>`(보기: `R0` · `R1`, 먼저 확인할 일은 `P1`). 가능하면 첫 에픽은 걷는 뼈대 — 가장 얇게 끝에서 끝까지 도는 에픽이다.
   - 종류는 셋이다 — 「묶음」(에픽 묶음 파일을 만든다) · 「브랜치 <설계문서 경로>」(묶음 없이 이미 있는 설계문서를 가리킨다) · 「결정」(브랜치 없이 로드맵 결정 기록으로 끝난다). 「결정」이면 브랜치 칸은 「없음」이다.
   - 범위는 `한다 … / 안 한다 …`. 의존 · 경로 예약은 쉼표로 나열하고 없으면 「없음」. 빈 칸은 두지 않는다. 칸 안의 `|` 는 `\|` 로 쓴다.
   - 배정 번호 — brief 에 쓸 모든 번호(확정 C · D, 열린 질문 OQ, 레포 근거 RC, steelman ST, 웹 «key», 위험 K, 발화 S)를 하나 이상의 에픽에 배정한다. 모든 에픽이 받드는 공통 제약은 여러 에픽에 넣는다. 묶음 없는 두 종류에는 발화(S)와 그 밖의 번호가 하나 이상씩 있어야 한다. 위험 K 는 brief §5 의 번호 없는 위험 줄(숨은 가정 · 실패 양식 · 리뷰 참고 순)에 줄 순서대로 매길 번호다.
   - 받는 것 · 넘기는 것 — 에픽 사이 인터페이스다. 묶음 §7 에 이 두 칸이 글자 그대로 실린다.

   표 아래에 `미배정 번호 <n> · 고아 발화 <m>` 한 줄을 보이고, 0 이 아니면 그 번호를 나열한다. brief 를 쓰기 전이라 이 계산은 모델이 한다 — 인터뷰 state 의 번호 목록(위 일곱 종류)에서 표의 배정 번호 합집합을 뺀다. 확정 판정은 Step A 8 의 생성기 검증(`roadmap_status.py` 규칙)이 한다.
4. **고치기 · 승인.** `AskUserQuestion` 하나 — 옵션 셋: 「승인」(표를 확정하고 Step A 로) · 「고치기」(말로 받아 표를 고쳐 다시 보인다) · 「spec 하나로」(나누지 않고 Step A 로). 고친 횟수는 state `decompose_edits` 에 센다. 세 번 고칠 때마다 「계속 고칠까요」를 묻고(옵션: 「계속 고친다」 · 「지금 표로 승인」 · 「spec 하나로」) 자동으로 끝내지 않는다.
5. **기록.** 승인된 표를 state 파일(`$ROOT/<session-id>/state.local.md`) 본문의 `## 분해안` 절에 위 머리 그대로 적고, 표 아래에 `승인: 「<사용자가 고른 옵션 또는 말>」` 한 줄을 둔다. 로드맵 폴더는 `docs/superpowers/roadmaps/<YYYY-MM-DD>-<kebab-topic>/` 다(brief 와 같은 날짜 · 주제). Step A 는 brief §7 첫 줄에 `분해됨 — <로드맵 경로>` 를 쓴다.

### Step A — brief 작성 (terminal 산출물, 2파일)

1. `${CLAUDE_PLUGIN_ROOT}/templates/interview-brief-template.md`로 payload **8-section**
   구조(§0 한눈에 – §7 Next Action)를, `${CLAUDE_PLUGIN_ROOT}/templates/interview-audit-template.md`로
   audit **5-section** 구조를 확보합니다.
2. 경로 (둘 다 워크트리 안 → `Write` tool 사용): payload · audit 경로는 상태 파일 이름에서 `.state.md` 를 뗀
   `<줄기>` 에 `.md` · `.audit.md` 를 붙인 것이다(`state-file.md`). 날짜 · 주제로 다시 계산하지 않는다.
   - payload: `<줄기>.md` (`docs/superpowers/interview/<YYYY-MM-DD>-<kebab-topic>-interview.md`)
   - audit:   `<줄기>.audit.md`
   - payload frontmatter: `type: interview-brief`, `next_phase: superpowers:brainstorming`,
     `session_id`(기존 spec-distill 세션 재사용), `audit_file`(audit의 **basename만** —
     경로 구분자가 들어가면 게이트가 거부합니다), `user_sourced_items[]`.
3. **`user_sourced_items` 직렬화**: state의 `user_statements`를 훑어 제약으로 승격할 항목을
   고르고, 각각에 id·`source`·`statement`·`evidence`(그 발화의 `S<N>`)를 붙입니다.
   **이 시점의 `status`는 전부 `provisional`입니다** — `confirmed`는 Step B-0의 사용자 확인
   으로만 발생합니다. 모델 추론은 이 리스트에 넣지 말고 본문에 ✎ 프로즈로 씁니다.
   `S1`만 payload §6에 남고, `user_statements`의 나머지 발화 전량은 **audit §6**에
   **전문 보존**(append-only)하며 각각 `S<N>` 앵커를 답니다.
   **최초 요청 원문은 `S1`이다.** 「풀린 입력」(진입 단계 2 의 결과 — rough request 그대로이거나
   `@경로` 의 파일 전문)을 `user_statements`의 첫 항목과 **같은 형식**으로 §6 맨 앞에 넣습니다.
   상태 파일로 이어 간 인터뷰면 「풀린 입력」은 그 파일의 `## 풀린 입력` 블록이다(`state-file.md`).
   Phase 0 을 거친 세션에서는 `## 진입 단계` 2 가 `@경로` 를 풀었든 사용자가 전문을 붙여넣었든
   그 「풀린 입력」이 `interview-seed` 파일 전문이고, 그때도 같은 규칙이 그대로 적용됩니다:
   ```yaml
   - id: S1
     source: verbatim
     round: 0
     text: "<「풀린 입력」 원문 그대로>"    # P21 secret placeholder 치환 적용
   ```
   존재하면(인자 있음) `user_statements`의 id 번호도 이 예약을 반영해 `S1`이 아니라
   `S2`부터 시작합니다 — 최초 요청 원문 있으면 1, 없으면 0 을 더해 SKILL.md `사용자 발화
   기록`의 번호 공식과 합의합니다(그러지 않으면 §6에 `S1` 앵커가 원문과 첫 답변 둘로
   중복되거나, state의 `S1`과 payload의 `S1`이 서로 다른 텍스트를 가리켜
   `check_verbatim_coverage.py`의 앵커 중복·포함 검사가 red를 냅니다).
   비어 있으면(인자 없이 호출) `S1`을 만들지 않고 `S2`부터 시작하지 않습니다 — 번호는
   `user_statements`의 순서를 따르고, 최초 요청이 없으면 첫 사용자 답변이 `S1`입니다.
   원문 보존은 **관례가 아니라 요구**입니다 — `S1`은 N1b가 payload §6 앵커 집합(`{S1}`)으로
   못박지만, 나머지 발화 전량이 실제로 **audit §6**로 옮겨졌는가는 게이트 16항 어디에도
   없어서, 누락된 인터뷰가 나와도 지금까지 아무것도 red가 되지 않았습니다.
   구조상 이 시점의 `confirmed`는 **항상 0건**이므로, frontmatter에 sentinel 한 줄
   (`# confirmed 0건 — 사용자가 전부 잠정으로 판단`)을 **반드시** 함께 씁니다 — 템플릿이
   `user_sourced_items:` 블록 첫 줄로 상속시키는 그 줄입니다. 이 줄이 sentinel로 인정되려면
   **한 줄 전체**가 그 문구여야 합니다(다른 문장 안에 인용된 같은 문자열은 무효). 없으면
   게이트가 "확인 게이트 우회 신호"로 red를 냅니다 — sentinel은 *확인을 건너뛴 brief*와
   *사용자가 전부 잠정으로 판단한 brief*를 가르는 유일한 표식이라 생략할 수 없습니다.
   확정 반영 시에는 B-3 「확정 반영 절차」대로 같은 write에서 이 줄을 지웁니다.
4. **Coverage Ledger 직렬화**(게이트 *전*): state의 `coverage`를 **audit §1**에 한 줄당 한
   차원으로 직렬화(floor 5행 + derived 또는 `- derived: N/A`). floor 전부 `closed`가 아니면
   이 시점에 도달하면 안 됩니다(종료 driver 위반). steelman 원문은 audit §3에
   `#### ST<N> — <한 줄 요지>` 헤딩과 함께 verbatim으로 남기고, payload §5의 `verdict:` 항목이
   그 `ST<N>`을 참조합니다 — 양방향 일치가 게이트 대상입니다.

   **닫힌 행의 evidence 는 그 차원을 닫은 사용자 발화 `S<N>` 을 인용합니다**(게이트가 검사합니다 —
   `floor:<dim> evidence cites no S<N> anchor`). 어느 S 인지의 규약: root_problem = 사용자 원문 인용 S ·
   landscape = 외부 근거 처분 S · skepticism = steelman 판정 S · blind_spot = 숨은 가정·
   실패 양식 처분 S · open_questions = OQ 목록 확인 S. 사용자-승인 박제 행은 앵커가 접두 **뒤**에
   옵니다: `사용자-승인 박제(@S12) — §Open Questions 참조`. 재개방된 차원은 행 끝에
   `(재개방 <n>회 — <마지막 사유>)` 접미를 붙입니다(state `reopen_log` 의 마지막 항목).
   같은 시점에 **audit §2 Budget** 의 **불릿(데이터) 줄**에 `coverage-mapper <k>` 를 씁니다
   (state `orchestration.research_dispatches.coverage_mapper`) — 게이트는 `- ` 로 시작하는 줄만 읽으므로
   설명 산문에 적은 숫자는 세어지지 않습니다. dispatch 가 불가능했던 환경이면
   `coverage-mapper 0 (unavailable: <이유>)` — 게이트는 이를 advisory 로 통과시키고 Step B 가
   사람에게 보입니다.
   그 아래에 `${CLAUDE_PLUGIN_ROOT}/skills/spec-interview/references/saturation.md` 의 `### audit §2 줄` 형식으로 조사 호출 줄
   한 줄을 쓰고(state `research_dispatches` · `research_limit` · `research_log` 의 `device: orchestrator` 수), 이어서 state 본문
   `## audit §2 대기 줄` 블록을 글자 그대로 순서대로 옮겨 씁니다 — 상한 도달 · 판정 상한 도달 · 포화 판정 · 사용자 종료 줄이
   사건 순간 거기 쌓였습니다. 다시 짓거나 요약하지 않고, 블록에 없는 줄을 기억으로 보태지 않습니다.
   게이트는 `포화 판정 <k>:` · `사용자 종료(@S<n>)` 줄의 **마지막**을 봅니다.
5. **조사 주장의 인계 — 세 방향을 같은 id 로 맞물린다.** 하류는 brief 파일 경로를 받으므로
   §4·§5 를 포함한 전문을 읽을 수 있다. 하류에 **지시를 걸지 않고** 「읽을 이유」까지만 만든다.

   - **결정 연결(§4 · §5 → 결정)** — 조사 항목 줄 **끝**에 넷 중 하나: 레포 `[RC3 → OQ1]` ·
     `[RC3 → 없음]`(닿는 결정 없음), 웹 `[→ OQ1]` · `[→ 없음]`. **레포 주장은 연결 안에 항상
     `RC<n>` 을 싣는다**(웹 주장만 `[→ …]`) — `RC<n>` 이 줄에서 빠지면 아래 V2 대조와 게이트의
     확인 줄 · 내부 조사 차원 검사가 그 주장을 못 본다. 복수는 `[RC3 → OQ1 · OQ4]` 로 전부
     직렬화한다. **하위 불릿으로 쓰지 않는다** — 게이트가 들여쓴 불릿도 §4 항목으로 세므로
     즉시 red 다.
   - **역참조(§3 → 근거)** — 그 OQ 줄이 근거의 **id** 를 담는다: `- OQ1: <한 줄> → 근거 RC3`.
     §3 항목은 그 자체가 열린 결정이라 연결의 *대상*이고 출처가 아니다.
   - **요약 상호참조(§0 → 근거)** — §0 의 결정 목록도 같은 id 를 쓰고 **상태 토큰**을 단다:
     `- OQ1 [열림] — <한 줄> → 근거 RC3` / `- OQ1 [해결 ⟨S10⟩] — <한 줄> → 근거 RC3`.
     `[해결 …]` 이 붙은 결정은 §3 에서 빠지고 §0 에만 남는다 — **§3 은 미해결의 목록이다.**
     §0 은 상위집합이므로 state `orchestration.open_decisions[]` **전량**이 여기 직렬화되고,
     그중 `status: open` 인 것만 §3 으로 간다. 이 목록은 **불릿 줄**이어야 한다(게이트가
     `- `/`* ` 로 시작하는 줄만 항목으로 읽는다).

   해결된 결정을 §0 에서 지우지 않는 이유: 조사가 그 결정을 해결하는 데 기여했으면 그것이 성공
   사례인데, 목록에서 빠지면 게이트의 실재 검사가 그 조사를 red 로 만든다. 「열림」은 상태 토큰이
   말하고 목록에서의 부재가 말하지 않는다.

   **§2 는 대상이 아니다** — 근거가 사용자 발화(`evidence: S<N>`)이고 ✎ 블록은 bijection B(§2 본문
   ↔ frontmatter)의 대상 밖이라, 거기에 새 술어를 걸면 그 bijection 과 이음매가 생긴다.

6. **V2 검문소 — 무조건, 누락 대조만.** payload 의 모든 `RC<n>` 에 대응하는 확인 줄이 audit
   `## 5. 프로세스 로그` 에 있는지 대조한다. **확인 «행위» 는 V1 이 라운드 안에서 이미 했으므로
   여기서 다시 확인하지 않고 누락 대조만 한다.** 이 검문소는 웹 스위치와 steelman trigger 어느
   것에도 종속되지 않는다.

   ```bash
   # payload 조사 항목(§4 · §5 의 불릿 줄)의 RC<n> 전량 ↔ audit §5 불릿 줄의 확인 줄 — 차집합이 비어야 한다.
   # 불릿은 `-`·`*` 둘 다, 들여쓰기 허용 — 게이트의 항목 판독과 같은 관례다. §3·§0 의 역참조는 출처가 아니다.
   PL="docs/superpowers/interview/<file>"
   AD="${PL%.md}.audit.md"
   comm -23 <(awk '/^## [0-9]+\./{f=($2=="4."||$2=="5.")} f' "$PL" | grep -E '^[[:space:]]*[-*][[:space:]]' \
                | grep -oE '(^|[^A-Za-z])RC[0-9]+' | grep -oE 'RC[0-9]+' | sort -u) \
            <(awk '/^## [0-9]+\./{f=($2=="5.")} f' "$AD" | grep -oE '^[[:space:]]*[-*][[:space:]]+확인 RC[0-9]+' \
                | grep -oE 'RC[0-9]+' | sort -u)
   ```
   출력이 있으면 그 `RC<n>` 의 확인 줄이 없다 — V1 을 태우지 않은 주장이므로 payload 에서 빼거나
   확인해서 줄을 적는다. 게이트도 같은 것을 본다(형태 ∀).

   V1 판정이 `반증` 이었던 항목은 그 항목이 닿는 확정을 payload §5 에 *원래 / 재결정 / 근거* 세 칸으로
   남긴다. **재결정 자체는 사용자 동의로만 한다**(P23) — 이 규약은 기록 형식이고 판정 권한이 아니다.

7. **기계적 게이트 검증** — 직렬화 직후. payload 경로만 넘기면 게이트가 `audit_file`로
   audit을 해석합니다:
   ```bash
   SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
   python3 "$SD/scripts/check_brief.py" gate "docs/superpowers/interview/<file>"
   ```
   exit ≠ 0 이면 **brief를 finalize하지 말고** 보고된 미충족 항목을 보완(누락 섹션·무인용
   landscape·형식 미달 verdict 항목·`기각` 0건·floor open·bijection 불일치·**`confirmed`
   0건 sentinel 누락**·포화 판정 줄 없음 · 마지막 판정 «아직» · 판정 불가 뒤 조사 계속이 마지막 · 형식 밖). 통과(exit 0)할 때까지 반복합니다. 마지막 항목은 이 단계에서
   **매번** 발화할 수 있는 유일한 실패입니다 — Step A는 정의상 전부 `provisional`이므로,
   위 3의 sentinel을 빠뜨리면 첫 게이트 실행이 항상 red입니다.
8. **로드맵 · 묶음 생성 — 분해된 일만.** 분해 판단에서 표를 승인했으면 게이트를 통과한 직후 생성기를 돌린다:
   ```bash
   SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
   ROOT="$(python3 "$SD/scripts/state_path.py" state-root)"
   python3 "$SD/scripts/roadmap_write.py" create --brief "docs/superpowers/interview/<file>" \
     --audit "docs/superpowers/interview/<audit file>" --plan-table "$ROOT/<session-id>/state.local.md" \
     --out "docs/superpowers/roadmaps/<YYYY-MM-DD>-<kebab-topic>/" --title "<주제 한 줄>" \
     --date "<YYYY-MM-DD>" --approval "<승인 원문>"
   ```
   rc 0 이면 나온 `[spec-distill]` 줄을 그대로 보인다. rc 1 이면 사유 줄을 그대로 보이고 분해 판단 3(분해안 표)으로 돌아간다 — 생성기가 만든 파일은 이미 지워졌고 미리 있던 파일은 그대로다. 표를 고쳐 승인받은 뒤 다시 돈다. 생성기는 표 파일에 `## 생성 기록` 절을 남긴다 — Step B 의 다시 생성이 그 기록에 있는 파일만 덮어쓴다.

### Step A.5 — brief 리뷰 파이프라인 진입 (Law 2 분리 리뷰, v0.24.0)

게이트(Step A 7)를 통과한 payload는 **Law 1 구조 자기검사**를 마친 것이고, 아직 **분리 리뷰**를
받지 않았습니다. 여기서 `reviewing-brief` skill로 넘깁니다 — 문서 리뷰 엔진이 층 1(방향성)·층 2(충실도)를
보며, 절차는 그 skill이 소유합니다(여기에 복제하지 않습니다).

핸드오프 변수 2개를 **절대경로**로 세팅합니다(엔진은 상대 문서 경로를 거부하고, codex 산출물 경로는 그 skill 이 도출합니다):

```bash
PAYLOAD="$(pwd)/docs/superpowers/interview/<file>"   # Step A가 방금 쓰고 검증한 경로
AUDIT="${PAYLOAD%.md}.audit.md"                      # payload 의 audit sidecar (§6 S2+ 원문)
```

```
Skill spec-distill:reviewing-brief $PAYLOAD $AUDIT
```

두 인자는 **주석이 아니라 호출 라인 위에** 있어야 합니다 — `reviewing-brief`는 이 값들을 스스로 정의하지 않는다고 명시하므로, `#` 뒤에만 적혀 있으면 호출은 인자 없이 나가고 callee는 정의되지 않은 변수를 쥡니다.

- 지출 승인 게이트는 없습니다(`cost_class: medium`) — 지출 통제는 엔진의 재리뷰 상한이 합니다: 상한 뒤의
  추가 라운드는 사용자가 그 skill 의 승인 게이트에서 자기 문구로 열어야만 돕니다.
- `DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW=1`이면 파이프라인이 전체 skip되고 skip record가
  Step B 게이트 질문에 표시됩니다 — 조용한 생략이 아닙니다.
- 리뷰가 payload를 수정할 수 있습니다(§0·§2 — 프로필의 수정 자리). 수정이 일어나면 Step B는 **리뷰 후
  최종 문서**를 봅니다.
- 산출물 셋(엔진 게이트 결과 / 냉독 요약 + gap / degrade 채널)이 Step B 게이트로 넘어옵니다. 엔진
  승인 게이트의 2단계(진행 옵션)는 그 skill 이 띄우지 않고 아래 Step B 가 묻습니다.

### Step B — proceed 게이트 (handoff 방식 제안)

brief는 **단독 완결 terminal 산출물**입니다(NG7 — handoff는 강제가 아니라 사용자 선택).
Step B는 단일 책임 단위입니다: *brief가 완결되면 다음 stage(brainstorming 해답공간) 진입
방식을 사용자에게 제안한다.* 입력 = 완결·`check_brief.py` 검증된 brief 경로 + superpowers
가용성.

**이 게이트의 공통 계약(순서 · 두 가드 · 예외 경로)은 `${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 에 있습니다.**
`spec-review` 의 proceed 게이트와 **같은 골격**이며, 두 벌을 독립 저술하던
것을 그 파일로 모았습니다 — 한쪽만 고치면 다른 쪽이 조용히 갈라지기 때문입니다. Step B 에
실제로 진입할 때 읽고 그대로 따릅니다. 아래에는 이 skill 의 **어휘**(확정 후보 제시 · 옵션 라벨 ·
다음 세션 줄 · superpowers 가용성 분기)만 남습니다.

```
Read ${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md
```

플러그인 레벨 경로입니다 — 이 파일 옆이 아니라 플러그인 루트 아래
(`plugins/spec-distill/references/proceed-gate.md`)에 있습니다. 두 skill 이 공유하므로 어느
skill 밑에도 두지 않았습니다.

#### B-0 — 확정 후보 제시 (게이트에 흡수, AC2)

Step A가 끝난 시점에 `user_sourced_items`는 **전부 `provisional`**입니다. `confirmed`로의
전이는 아래 B-2 게이트에서 사용자가 확정-후-진행 옵션(①/②)을 고를 때만 일어납니다.
별도 확인 의례를 만들지 않는 이유는 종료 시 사용자 상호작용이 2회가 되기 때문입니다 —
확인을 기존 proceed 게이트에 흡수해 1회로 유지합니다.

게이트를 띄우기 *전에* 확정 후보 목록을 **프로즈로** 출력합니다(목록이 길 수 있으므로
`AskUserQuestion`은 선택지만 담당):

- 각 후보를 `<id> — <statement> (source, ⟨S<N>⟩)` 한 줄로.
- **확정 후보에서 제외한 항목도** 한 줄씩 이유와 함께 보여줍니다 — 제외 항목을 감추면
  사용자가 누락을 잡을 수 없습니다.
- 모델의 후보 판정은 **제안일 뿐**입니다. 어떤 항목도 이 출력만으로 `confirmed`가 되지 않습니다.

**재제시 상한** (금지 패턴 *Unbounded autonomy* 가드): 최초 제시는 0회째입니다. 사용자가
옵션 ③(확정 목록 수정)을 고를 때마다 state의 `confirm_repost_count`를 +1 하고 **2회까지**
허용합니다. 3번째 ③ 요구 시 전 항목을 `provisional`로 강등하고 아래 **고정 문자열**을 출력한
뒤 게이트를 재제시하지 않고 **④와 동일한 terminal 경로로 종료합니다**(handoff 안 함 —
사용자가 ③을 골랐지 ①/②를 고른 적이 없으므로, 게이트 없이 brainstorming으로 자동 진행하는
것은 B-4의 P17/AP2 금지 대상이다). 종료 방향인 이유는 확정이 덜 되는 쪽이 안전한 방향이기
때문입니다:

```
[spec-distill] 확정 목록을 두 번 다시 보여 줬는데도 정하지 못했다 — 모든 항목을 잠정(provisional)으로 둔다
```

카운터는 프로즈 self-tracking이 아니라 상태 파일에 씁니다:

```bash
# confirm_repost_count 는 상태 파일(<줄기>-interview.state.md)의 frontmatter 에 Edit 로 쓴다
```

#### B-A — 참고(advisory) 목록 — 한 번 보이고 §3 · §5 에 박제

B-1 분기와 무관하게 B-1 보다 먼저 돕니다. 엔진 `advice` 원장의 방향 · overdesign
항목은 라운드 게이트에 오지 않았습니다 — 여기서 한 번 보이고 brief 에 박제합니다. `PAYLOAD` 는 Step A.5 의 그 절대경로입니다.
이 펜스가 brief 리뷰 원장의 마지막 쓰기입니다 — 표지를 잡아(이미 잡았으면 그대로) 쓰고 끝에서 풉니다.

<!-- advice-ba:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
PAYLOAD="<Step A.5 의 PAYLOAD 절대경로>"
AUDIT="${PAYLOAD%.md}.audit.md"
STATE="${PAYLOAD%.md}.state.md"
harness_sid="$(python3 "$SD/scripts/state_path.py" session-id || true)"
ROOT="$(python3 "$SD/scripts/state_path.py" state-root || true)"
STATE_DIR="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$ROOT" --doc "$PAYLOAD" || true)"
[ -z "${STATE_DIR:-}" ] || python3 "$SD/scripts/state_path.py" path-inside --root "${ROOT%/.claude/spec-distill}" "$STATE_DIR" || STATE_DIR=""
wt_top="$(python3 "$SD/scripts/state_path.py" payload-root "$PAYLOAD")" || wt_top=""
paths_ok=0; [ -n "$wt_top" ] && python3 "$SD/scripts/state_path.py" path-inside --root "$wt_top" "$PAYLOAD" "$AUDIT" "$STATE" && paths_ok=1
lm_rc=0
if [ "$paths_ok" -eq 1 ] && [ -n "${STATE_DIR:-}" ] && [ -d "$STATE_DIR" ] && [ -n "${harness_sid:-}" ]; then
  python3 "$SD/scripts/ledger_marker.py" acquire --dir "$STATE_DIR" --session "$harness_sid" >/dev/null || lm_rc=$?
fi
if [ "$paths_ok" -ne 1 ]; then
  echo "[spec-distill] 참고(advisory) 목록 건너뜀 — brief · audit · 상태 파일 중 링크를 거치거나 작업 트리 밖인 경로가 있다(위 사유 · PAYLOAD='${PAYLOAD}'). audit 에 쓰지 않는다. 게이트 앞 글에 싣는다."
elif [ -z "${STATE_DIR:-}" ] || [ ! -f "$STATE_DIR/docreview-state.md" ]; then
  echo "[spec-distill] 참고(advisory) 목록 없음 — brief 리뷰 원장이 없다(STATE_DIR='${STATE_DIR:-}'): 리뷰가 skip 됐거나 원장이 정리됐다. 게이트 앞 글에 싣는다."
elif [ "$lm_rc" -eq 3 ]; then
  echo "[spec-distill] 참고(advisory) 목록 건너뜀 — 이 원장의 표지가 다른 세션 것이다(rc ${lm_rc}). 박제 · 계수 · 표시를 하지 않는다. 게이트 앞 글에 싣는다."
elif [ "$lm_rc" -ne 0 ]; then
  echo "[spec-distill] 참고(advisory) 목록 건너뜀 — 표지를 확인하지 못했다(rc ${lm_rc}) — 원장 쓰기를 하지 않는다. 박제 · 계수 · 표시를 하지 않는다. 게이트 앞 글에 싣는다."
else
  g_out="$(python3 "$SD/scripts/ledger_marker.py" check --dir "$STATE_DIR" --session "$harness_sid" 2>&1)" || { printf '%s\n' "$g_out"; case "$g_out" in *"표지 없음"*) echo "[spec-distill] 원장 쓰기를 멈췄다 — 이 문서의 리뷰 표지가 없다(끝맺음 펜스가 풀었다). 원장 열기 펜스(ledger-open)를 먼저 다시 돌려라.";; *"다른 세션"*) echo "[spec-distill] 원장 쓰기를 멈췄다 — 이 문서의 리뷰 표지가 이 세션 것이 아니다(위 사유). 이어 가려면 원장 열기의 표지 질문에서 「이어 씀」을 고른다.";; *) echo "[spec-distill] 원장 쓰기를 멈췄다 — 리뷰 표지를 확인하지 못했다(위 사유). 원장 열기 펜스(ledger-open)를 먼저 다시 돌려라.";; esac; exit 3; }
  adv_rc=0
  adv_err="$STATE_DIR/advice-err.json"
  python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" > "$STATE_DIR/advice-list.json" 2>"$adv_err" || adv_rc=$?
  if [ "$adv_rc" -eq 0 ]; then
    echo "advice-list: $STATE_DIR/advice-list.json"
    python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" --log-file "$AUDIT" --render --cap 8 --where "brief §3 · §5" 2>"$adv_err" || adv_rc=$?
  fi
  if [ "$adv_rc" -ne 0 ]; then
    cat "$adv_err" >&2
    echo "[spec-distill] 참고 목록 판독 · 표시 실패(rc $adv_rc) — 위 stderr 사유를 게이트 앞 글에 싣는다."
    grep -qE '"reason": "(profile_has_no_must_catch|advice_module_missing)"' "$adv_err" || python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" --render --cap 8 --where "brief §3 · §5" || echo "[spec-distill] 참고 목록 표시도 실패했다 — 목록 본문 없음을 게이트 앞 글에 싣는다."
  fi
fi
[ -z "${STATE_DIR:-}" ] || [ ! -d "$STATE_DIR" ] || [ -z "${harness_sid:-}" ] || python3 "$SD/scripts/ledger_marker.py" release --dir "$STATE_DIR" --session "$harness_sid"
```
<!-- advice-ba:end -->

펜스 출력(머리 한 줄 + 최대 8줄 + `외 K건`)과 `[spec-distill]` 줄을 그대로 보입니다. 이어 `advice-list:` 줄이 가리킨
파일을 Read 하고, 그 `items` 중 `shown` 이 거짓이던 항목을 payload 에 박제합니다 — 표시가 돌았으면 방금 보인
항목들이고, 「표시도 실패했다」 줄이 나왔으면 사용자가 보지 못한 항목이라 그 사실을 B-2 에 싣습니다.
`advice-list:` 줄이 없으면(원장 없음 · 판독 실패) 박제할 것이 없고 그 `[spec-distill]` 줄을 B-2 에 싣습니다.
가르는 판단은 한 줄입니다:

**이 brief 를 넘기기 전에 사용자가 고를 것이 있는가.**

- **있으면 §3.** `- OQ<n>: [참고 · <category>] <summary> (리뷰 <id>)` 로 적고, §0 결정 목록에
  `- OQ<n> [열림] — [참고 · <category>] <summary>` 를 함께 적습니다. `<n>` 은 §3 · §0 의 가장 큰 OQ 번호 다음입니다.
- **없으면(알고 있으면 되는 위험) §5.** `- 위험 — 리뷰 참고 | [<category>] <anchor> — <summary> (리뷰 <id>)` 로 적습니다.

적은 뒤 구조 게이트를 다시 돕니다. failures 가 있으면 고치고 다시 돕니다:

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
PAYLOAD="<Step A.5 의 PAYLOAD 절대경로>"
python3 "$SD/scripts/check_brief.py" gate "$PAYLOAD"
```

#### B-1 — superpowers 가용성 분기

- **superpowers 부재 시**: 현행 graceful degradation 그대로 — brief를 완료하고 **loud advisory**를 낸 뒤 **정지(STOP)**. 게이트 없음(다음 세션에 넘길 대상 자체가 없음). crash·spec-mode fallback **금지**(단독 완결, graceful degrade):

  > `[spec-distill] interview brief 를 만들었다: docs/superpowers/interview/<file>. superpowers 가 없어 여기서 멈춘다. 이 brief 를 다음 작업의 입력으로 쓰세요. brief · audit · 상태 파일은 커밋하지 않았다 — 브랜치에서 직접 커밋하라.`

- **superpowers 가용 시**: B-2 proceed 게이트 제시.

#### B-2 — 단일 `AskUserQuestion` proceed 게이트 (4옵션, AC2)

게이트 *이전*에 brief 경로 존재를 확인합니다(`[[ -f <brief-path> ]]` — race 방어 경량 가드,
`AskUserQuestion` 게이트 자체는 아님). 부재 시 정본(`proceed-gate.md`)의 `## Step A` 대로
두 줄 명령을 노출하지 *않고* loud advisory 후 STOP(brief 는 막 검증됐다 — 설계 §5.3):

> `[spec-distill] brief '<brief-path>' 부재 — 재작성/세션 리셋 필요`

(Step A의 작성 + `check_brief.py` 검증 직후라 정상 경로에선 발생하지 않습니다.)

brief 유효 시 **한 번의** `AskUserQuestion`으로 다음 단계를 제안합니다:

게이트를 띄우기 *전에* Step A.5 리뷰 산출물을 프로즈로 출력합니다(B-0 확정 후보 목록 다음):

1. **리뷰 게이트 결과** — 엔진의 마지막 게이트의 첫 줄을 뺀 렌더(첫 줄은 목록 4 에 쓴다) · 승인 게이트 도달 사유(열린 것 없음 · 상한 · stagnation · 「미검증」) · 리뷰 완료 여부 · 1단계에서의 사용자 선택. 방향 · overdesign(참고 축)은 라운드 게이트에 오지 않았습니다 — B-A 가 낸 것을 싣습니다: 참고 목록과 §3 · §5 박제 결과, 또는 B-A 의 부재 · 실패 공시(`[spec-distill]` 줄).
   「미검증」 라벨과 리뷰 완료 여부의 출처는 **엔진 게이트 요약**입니다 — `reviewing-brief` 가 넘기는 마지막 요약의 `approval_label` · `round_reviewed` · `unreviewed_reason` 을 그대로 싣고, critic 사망 횟수나 `finalize` 결과를 기억해 라벨을 붙이지 않습니다. `round_reviewed` 가 거짓이면 그 라운드는 리뷰 완료가 아니고, 사유(`unreviewed_reason`)는 다음 중 하나입니다:
   - 「미검증」 — critic 사망(`critic_dead`) · `finalize` 실패(`finalize_incomplete`). `approval_label` 이 「미검증」이고 승인 게이트를 그 라벨로 연 라운드입니다.
   - 라운드 미완(`unrouted`) — 이번 라운드의 라우팅 보고서가 없다(`finalize` 를 거치지 않았다). 라벨도 승인 게이트 강제도 없지만 리뷰 완료가 아니므로, 이 사유를 도달 사유와 함께 싣습니다.
2. **readback 요약 전문** + gap 목록(*어느 클래스 / 요약의 어느 문장 / payload의 어느 절*).
3. **열린 채 남은 항목과 미반영 findings** — 있으면 각각 이유와 함께. 저자가 임의로 기각한 것이 아니라 사용자 판정
   대상입니다.
4. **경고** — 아래 「이 skill 의 degrade 채널」을 읽고 경고를 한 줄씩 쉬운 말로 쓴다(원문 사유 토큰은 괄호에).
   `check_brief.py gate` 의 `advisories` 도 여기 쓴다. 채널을 다 읽었는데 경고가 없으면, 남은 항목(위 3)도
   없을 때만 「이상 없음」, 남은 항목이 있으면 「경고 없음」 한 줄이다. 읽지 못한 채널은 「알 수 없음 — <사유>」
   로 따로 한 줄 쓴다.

**이 skill 의 degrade 채널** (정본 Step B 가 각 skill 에 이름을 대라고 요구하는 그것):
`reviewing-brief` 의 `## degrade 채널` 다섯 — 엔진의 `fin.json` `advisory[]`·`blocks`·`gate --render` 첫 줄 +
state 의 `brief_review_degradations` 원장(BRIEF_REVIEW skip record 포함)·두 번째 채널 파일 — 과 웹 한 줄.
`advisory[]` 원문은 하나하나가 `gate --render` 첫 줄의 경고 줄 중 하나에 대응하므로, 경고(목록 4)에는 그 첫 줄의
경고 줄을 그대로 쓰고 `advisory[]` 원문을 다시 늘어놓지 않습니다. 질문의 「경고 N개」에서 엔진 몫은 렌더 첫 줄의 N 이고,
다른 채널의 경고 줄은 그 위에 더합니다. 렌더 첫 줄의 끝 문구(이상 없음 · 경고 없음 · 경고 K개)는 문서 리뷰 엔진 몫의 결론이다. 다른 채널에 경고가 있으면 첫 줄 아래에 「그 밖의 경고 M개:」 줄로 쓰고, 전체 결론은 질문의 상태 줄이 정한다(엔진 K + 그 밖의 M).
「이상 없음」·「경고 없음」은 **그 채널들을 실제로 읽었다는 주장**이므로, 조회하지 않은 채 쓰지 않습니다.

모든 degrade record 는 **게이트 앞 글**(위 목록 4)에 한 줄씩 씁니다 — 옵션 description 에 싣지 않습니다.
사용자가 옵션을 고르기 *전에* 읽도록 질문 바로 앞에 둡니다. 질문 본문에는 결정 하나와 그 개수 한 줄
(「경고 N개 — 위에 적었다」 또는 「경고 없음」·「이상 없음」)만 둡니다.

`check_brief.py gate` 의 `advisories` 도 게이트 앞 글(목록 4)에 씁니다 — `coverage-mapper 0
(unavailable: …)` 은 게이트가 관측할 수 없는 사실(실제 dispatch 여부)을 사람에게 넘기는
유일한 자리입니다. 사용자 판단 포화(판정자의 «포화» 없이 사용자가 끝냈다)도 같은 자리로 옵니다. 조사 축의 advisory 둘도 같은 자리로 옵니다:

- **`내부 조사 0건`** — 이 brief 가 레포 주장(`RC<n>`)을 하나도 싣지 않았다. 게이트는 「조사를
  했어야 했는가」를 알 수 없다(이 스크립트는 brief 파일만 읽는다) — 그 판단이 여기서 사람에게 간다.
- **`신 계약 미적용 brief`** — payload frontmatter 에 `contract: v2` 가 없어 조사 축의 술어 다섯이
  전부 미발동이다. 옵트인의 fail-open 방향을 이 줄이 공시한다.

```javascript
AskUserQuestion({
  questions: [{
    question: "interview brief 를 만들었다: <brief-path> (구조 검사 통과 · 리뷰 <게이트 결과 한 줄 — 왜 여기서 멈췄는지 · 남은 항목 수 · 리뷰를 마치지 못했으면 그 사유(unreviewed_reason)>). 경고 <N>개 — 위에 적었다 | 경고 없음 | 이상 없음. 다음 단계는?",
    header: "다음 단계",
    options: [
      {label: "확정하고 /compact 후 brainstorming (권장)", description: "확정 후보를 확정으로 바꿔 저장하고, 붙여 넣을 두 줄(/compact 와 다음 세션 줄)을 보여 준다. 인터뷰 기록을 요약해 둔 채 brief 를 붙여 읽고 brainstorming 을 시작한다."},
      {label: "확정하고 /new 후 brainstorming", description: "확정 후보를 확정으로 바꿔 저장하고, 같은 두 줄을 첫 줄만 /new 로 보여 준다. 새 세션이 brief 만 붙여 읽고 brainstorming 을 시작한다."},
      {label: "확정 목록 수정", description: "확정 후보를 고쳐 다시 보여 준다(최대 2번). 아직 아무것도 확정되지 않는다."},
      {label: "brief만 종료", description: "brief 를 여기서 끝낸다. 모든 항목이 잠정으로 남고 다음 단계로 넘기지 않는다."}
    ],
    multiSelect: false
  }]
})
```

#### B-3 — 응답 처리

**규약의 거처 (C5).** `superpowers:brainstorming`은 spec-distill을 모르고 brief frontmatter를
읽지 않습니다 — 전달은 순수 프로즈 경로입니다. 그래서 C4 재결정 프로토콜은 brief 파일이
아니라 **다음 세션 줄**(brainstorming 을 부르는 호출 프롬프트)에 싣습니다. brief는 순수 데이터(`source`/`status`/
`evidence`)만 나릅니다. ①과 ② 는 같은 줄을 씁니다.

**확정 반영 절차 (①/② 공통).** `provisional` → `confirmed` 전이와 함께, Step A가 confirmed
0건일 때 넣었던 sentinel 한 줄(`# confirmed 0건 — 사용자가 전부 잠정으로 판단`)이 남아 있으면
**같은 write에서 삭제**합니다. `check_brief.py`는 이 잔존을 잡지 못합니다 — confirmed가 한 건이라도
있으면 sentinel *요구*가 해제될 뿐 잔존을 거부하지는 않아, 지우지 않으면 confirmed 항목 옆에
"전부 잠정"이라 적힌 자기모순 brief가 그대로 나갑니다. 삭제까지 마친 뒤 재저장 → 게이트 재실행.

**다음 세션 줄 — ①/② 공통**

> `@<brief-path> 이 interview brief 로 Skill superpowers:brainstorming 을 시작하라. confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지. brief 의 §2 확정 항목뿐 아니라 §3 열린 질문 · §4 조사 · §5 위험을 번호째 설계의 입력으로 읽는다 — /compact 요약에 기대지 말고 첨부한 brief 를 다시 읽는다. 설계문서에 ## 번호 대조 표(칸: 번호 · 반영/기각 · 자리 또는 이유)를 두어 brief 의 모든 번호와 brief frontmatter audit_file(같은 폴더) §6 의 S 번호를 싣고, 설계문서 frontmatter source_interview 에 이 brief 의 레포 루트 기준 상대경로를 적는다. 설계문서의 수용 기준은 ## Acceptance Criteria 아래 AC1 · AC2 … 처럼 번호를 단다. 설계문서를 쓰고 커밋한 뒤, brainstorming 의 사용자 리뷰 게이트 자리에서 그 설계문서 경로 뒤에 --bundle 과 source_interview 에 적은 것과 같은 상대경로를 붙여 Skill spec-distill:spec-review 를 부른다. superpowers:writing-plans 는 spec-review 의 승인 게이트에서 진행이 선택된 뒤에만 부른다. spec-review 가 게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다. writing-plans 가 계획을 쓴 뒤 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --plan 에 설계문서와 계획 경로를 넘겨 돌리고, 계획에 없는 AC 는 계획에 더한다. SDD 의 마지막 전체 리뷰에 설계문서 ## Acceptance Criteria 의 AC 목록을 싣고, 리뷰가 AC 마다 한 줄씩 AC1: 구현됨 — 근거 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)로 보고하게 해 그 보고를 git 이 추적하지 않는 파일에 적는다. 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 ## 미룸 표(항목 · 이유 · 받는 곳)에 올리고, PR 을 만들기 전에 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --impl 에 설계문서와 보고 파일 경로를 넘겨 돌려 경고를 사용자에게 보인다. 사람에게 쓰는 글 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 첫 줄에 상태, 끝에 할 일 하나)을 지킨다.`

줄 앞의 `@<brief-path>` 는 Step A.5 의 `PAYLOAD` 값, 곧 brief 의 절대경로로 치환한 뒤 노출한다. 줄 안의 `${CLAUDE_PLUGIN_ROOT}` 는 이 플러그인의 절대경로로 바꿔 노출한다 — 이 파일에서는 그 변수가 치환되지 않은 채 읽히고, 새 세션에는 그 변수가 없다. 치환하지 않은
자리표가 남거나 경로에 공백이 있으면 노출하지 않고 `[spec-distill] 다음 세션 줄을 만들 수 없다 — <사유>. brief: <PAYLOAD 값>. 새 세션에서 이 brief 를 직접 첨부하고 아래 문장을 그대로 붙여 넣어 brainstorming 을 시작하라.`
한 줄과, 그 아래에 다음 세션 줄에서 `@` 토큰을 뗀 나머지 문장을 그대로 보인 뒤 멈춘다(정본 `## 다음 세션 명령` 규칙 5). 사람이 이 줄의 유일한 운반자다 — 자동으로 이어지지 않는다.
로드맵 에픽의 설계를 여는 줄은 이 줄이 아니라 `${CLAUDE_PLUGIN_ROOT}/references/epic-handoff.md` 의 에픽 넘김 줄이다 — 지휘 세션이 쓴다.

- **① 확정하고 /compact 후 brainstorming**: 확정 후보를 `status: confirmed`로 반영 → brief 재저장 →
  `check_brief.py gate` 재실행(통과 확인) → 아래 세 파일 커밋 펜스(`interview-commit`) → 두 줄을 *그대로 보이게* 노출한다. 첫 줄은 맨 `/compact`
  (뒤에 아무것도 붙이지 않는다 — 붙인 텍스트는 요약 지시로만 쓰인다), 둘째 줄은 위 다음 세션 줄이다.
  두 줄을 따로 입력하라는 안내와 git 작업 트리 루트의 절대경로를 함께 낸다(정본
  `## 다음 세션 명령` 규칙 1 · 7).
  → **여기서 턴 종료(STOP). 같은 턴에서 `brainstorming`을 호출하지 말 것.** brainstorming 진입은
  사용자가 두 줄을 실제로 입력한 **다음 턴**에 **사용자 트리거**로만 일어난다 — 모델은 자동 진입하지
  *않고* 신호를 기다리며, 사용자가 redirect하면 미진입(NG4·P17).

- **② 확정하고 /new 후 brainstorming**: ① 과 같은 절차로 두 줄을 노출하되 첫 줄이 `/new` 다
  (뒤에 아무것도 붙이지 않는다 — 붙인 텍스트는 세션 이름이 된다). 둘째 줄은 위 다음 세션 줄이다.
  → **여기서 턴 종료(STOP). 같은 턴에서 `brainstorming`을 호출하지 말 것.** 진입은 사용자가 두 줄을
  실제로 입력한 **다음 턴**에 **사용자 트리거**로만 일어난다(NG4·P17).

- **③ 확정 목록 수정**: 확정 전이 없음. `confirm_repost_count` +1 후 B-0으로 돌아가 수정된
  목록을 재제시(상한 2회 — 초과 시 B-0의 강등 경로).

- **④ brief만 종료**: 전 항목 `provisional` 유지. 아래 세 파일 커밋 펜스(`interview-commit`)를 돌린 뒤 brief terminal
  advisory(B-1 부재 advisory와 같은 톤)를 내고 종료. handoff 안 함.

**세 파일 커밋 — ①/② 는 게이트 재실행 통과 뒤 두 줄 노출 전, ④ 는 종료 안내 직전, 한 번.** ③ 은 커밋하지 않는다.
게이트 재실행이 통과하지 않으면 커밋하지 않는다. 펜스의 `BRIEF` 자리표를 Step A.5 의 PAYLOAD 절대경로로 바꿔 돌리고,
나온 `[spec-distill]` 줄을 그대로 보인다. 진행은 막지 않는다.

<!-- interview-commit:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
BRIEF="<Step A.5 의 PAYLOAD 절대경로>"
case "$BRIEF" in
  ""|*"<"*) echo "[spec-distill] 커밋 입력 부재 — BRIEF 가 비었거나 자리표 그대로다(Step A.5 의 PAYLOAD 절대경로로 바꿔 다시 돌려라)." ;;
  *)
  # cwd 접두만 물리 경로로 바꾼다 — 그 아래 성분(링크 포함)은 path-inside 가 잰다.
  cwd_l="$(pwd -L)"
  case "$BRIEF" in "$cwd_l"/*) BRIEF="$(pwd -P)/${BRIEF#"$cwd_l"/}" ;; esac
  stem="${BRIEF%.md}"
  AUDIT_F="${stem}.audit.md"
  STATE_F="${stem}.state.md"
  top="$(git -C "$(dirname -- "$BRIEF")" rev-parse --show-toplevel 2>/dev/null)" || top=""
  def="$(git -C "${top:-.}" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)" || def=""
  def="${def#origin/}"
  cur="$(git -C "${top:-.}" branch --show-current 2>/dev/null)" || cur=""
  if [ -z "$top" ]; then
    echo "[spec-distill] 커밋하지 않았다 — git 저장소가 아니다. 파일은 docs 에 있다: $BRIEF · $AUDIT_F · $STATE_F"
  elif ! python3 "$SD/scripts/state_path.py" path-inside --root "$top" "$BRIEF" "$AUDIT_F" "$STATE_F"; then
    echo "[spec-distill] 커밋하지 않았다 — 세 파일 중 작업 트리 밖이거나 링크를 거치는 경로가 있다(위 사유). 확인한 뒤 직접 커밋하라: $BRIEF · $AUDIT_F · $STATE_F"
  elif [ -z "$def" ]; then
    echo "[spec-distill] 커밋하지 않았다 — 기본 브랜치를 판정하지 못했다(origin/HEAD 없음). 직접 커밋하라: $BRIEF · $AUDIT_F · $STATE_F"
  elif [ -z "$cur" ]; then
    echo "[spec-distill] 커밋하지 않았다 — 지금 브랜치 위가 아니다(detached HEAD). 브랜치에서 커밋하라: $BRIEF · $AUDIT_F · $STATE_F"
  elif [ "$cur" = "$def" ]; then
    echo "[spec-distill] 커밋하지 않았다 — 지금 기본 브랜치(${def})에 있다. 브랜치에서 커밋하라: $BRIEF · $AUDIT_F · $STATE_F"
  else
    c_rc=0
    git -C "$top" add -- "$BRIEF" "$AUDIT_F" "$STATE_F" || c_rc=$?
    [ "$c_rc" -ne 0 ] || git -C "$top" commit -q --only -m "docs(interview): $(basename -- "$stem") brief · audit · 상태 기록" -- "$BRIEF" "$AUDIT_F" "$STATE_F" || c_rc=$?
    if [ "$c_rc" -eq 0 ]; then
      echo "[spec-distill] brief · audit · 상태 파일을 커밋했다 — $(git -C "$top" rev-parse --short HEAD) (${cur})"
    else
      echo "[spec-distill] 커밋이 실패했다(rc ${c_rc}) — 파일은 docs 에 있다: $BRIEF · $AUDIT_F · $STATE_F"
    fi
  fi
  ;;
esac
```
<!-- interview-commit:end -->

#### B-R — 로드맵 다시 생성 (분해된 일만)

분해된 일이면 Step B 를 끝내는 모든 갈래(① · ② · ④ · 확정 목록 재제시 상한의 종료 · B-1 superpowers 부재 정지)에서, 그 갈래가 brief 를 마지막으로 쓴 직후 · 두 줄이나 정지 문구를 보이기 전에 Step A 8 의 명령을 그대로 언제나 한 번 더 돌린다. 항목이 바뀌었는지와 상관없다 — 확정 반영은 brief 줄을 늘 바꾸고, 리뷰 · B-A 박제도 항목을 더한다. 두 번째 실행은 첫 실행이 표 파일에 적은 `## 생성 기록` 에 있는 파일만 덮어쓰고 기록 밖의 파일은 건드리지 않는다. rc 1 이면 사유를 보이고 갈래를 사유로 가른다.

- 사유가 `unassigned` 또는 `orphans` 면 — 보통 B-A 가 brief 에 `OQ<n>` 줄이나 `위험 — 리뷰 참고` 줄을 더해 새 번호가 생긴 것이다 — 새 번호를 보이고 분해 판단 3–5(표 고치기 · 승인)로 그 번호를 배정한다. 승인되면 Step A 8 의 명령**만** 다시 돌린 뒤, 같은 Step B 갈래를 이어 간다(커밋 줄, 그다음 두 줄이나 정지 문구). Step A.5 리뷰를 다시 돌리지 않고 Step B 게이트도 다시 띄우지 않는다 — 사용자는 이미 ①/② 를 골랐다. 그 되돌아온 길에서 사용자가 「spec 하나로」 를 고르면: 이미 성공한 생성이 있으니 상태 파일 `## 생성 기록` 에 적힌 파일(생성된 로드맵 폴더의 파일)을 지우고 brief §7 의 `분해됨 — <로드맵 경로>` 줄을 뺀 뒤, 나누지 않은 일의 다음 세션 줄로 이어 간다.
- 표로 고칠 수 없는 사유(생성기가 만들지 않은 파일의 덮어쓰기 거부 · 못 읽는 파일 · 빈 ROOT 나 상태 파일 경로)면 사유를 그대로 보이고 멈춘다. 표로 돌아가 반복하지 않고, 멈춤에는 로드맵이 최신이 아니라는 advisory 를 붙인다.

커밋 전에 도는 단계라 이 결과가 커밋 대상이다.

**커밋 — 분해된 일만.** 이 파일에 경로 지정 커밋 단계가 아직 없으면 다시 생성 직후, 두 줄이나 정지 문구 **앞에** 이 한 줄을 보인다. 그런 단계가 있으면 그 경로 지정에 로드맵 폴더를 더한다:

> `[spec-distill] brief · audit · 상태 파일 · 로드맵 폴더를 함께 커밋하라 — <brief 경로> · <audit 경로> · <상태 파일 경로> · <로드맵 폴더>. 지휘 세션은 이 파일들이 기본 브랜치에 머지된 뒤 연다.`

상태 파일이 git 이 무시하는 자리(또는 작업 트리 밖)에 있으면 그것은 빼고 커밋한다 — 무시되는 경로를 `git add` 하면 rc 1, 작업 트리 밖 경로는 rc 128 로 끝나 나머지 커밋까지 막는다.

**다음 세션 줄 — 분해된 일 ①/② 공통**

`@<roadmap-path> 이 로드맵의 지휘 절차대로 진행하라. 에픽마다 ${CLAUDE_PLUGIN_ROOT}/references/epic-handoff.md 의 에픽 넘김 줄을 자리표를 채워 새 세션의 첫 줄로 써서 그 에픽 묶음으로 brainstorming 을 시작하고, 설계문서를 커밋한 뒤 그 설계문서 경로 뒤에 --bundle 과 그 묶음의 레포 루트 기준 상대경로를 붙여 spec-distill:spec-review 를 부른다. confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지. 사람에게 쓰는 글 규칙(번호나 해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 첫 줄에 상태, 끝에 할 일 하나)을 지킨다.`

분해된 일이면 ①/② 의 둘째 줄은 위 brief 줄 대신 이 줄이다. `<roadmap-path>` 는 로드맵의 절대경로로, 줄 안의 `${CLAUDE_PLUGIN_ROOT}` 는 이 플러그인의 절대경로로 치환한다 — 치환하지 못하거나 경로에 공백이 있으면 줄을 노출하지 않고 `[spec-distill] 다음 세션 줄을 만들 수 없다 — <사유>. 로드맵: <로드맵 경로>. 새 세션에서 이 로드맵을 직접 첨부하고 아래 문장을 그대로 붙여 넣어 지휘 절차대로 진행하라.` 한 줄과, 그 아래에 위 줄에서 `@` 토큰을 뗀 나머지 문장을 그대로 보인 뒤 멈춘다. 나누지 않은 일의 둘째 줄은 위 brief 줄 그대로다.

#### B-4 — 두 가드 (load-bearing)

두 가드의 **전문은 `proceed-gate.md` 의 `## Step C`** 입니다(Step B 머리의 포인터).
여기 남는 것은 이 skill 의 어휘로만 성립하는 두 문장입니다:

- **AP2 polite-stop 금지**: ①/② 선택 후 "brief 완결!"만 narrate 하고 두 줄 명령을 노출하지 않고
  끝내는 것은 **polite stop** — 금지(①/② 의 완료는 B-3 대로 두 줄과 위치를 노출하고 턴을 끝내는 것이다). Step B 를 *종료*하는
  모든 경로는 (a) 위 proceed 게이트를 거치거나(①/②/③/④), (b) 게이트를 거치지 않는 예외
  (superpowers 부재 — B-1)면 명시적 advisory 단락을 동반해야 한다 — 게이트-less **silent 종료
  금지**.
- **cross-compact 조기진행 금지**: ①·② 의 정지 요건과 다음 턴 진입 조건은 B-3 ①·② 에 인라인으로
  있습니다(그것이 이 skill 의 실행형이자 기계적 검증 앵커입니다). 예외는 없습니다.

이 stage는 brief까지로 종료됩니다. handoff를 *강제하지 않습니다*(NG7).
