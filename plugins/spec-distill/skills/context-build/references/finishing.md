## 종료 — brief 작성 + optional handoff

이 stage 전체가 **확산**이고(라운드 질문·landscape sweep·steelman·blind-spot premortem), Step A 는 그 결과를 **압축**해 payload 로 내보낸다 — 압축 규약 정본은 `${CLAUDE_PLUGIN_ROOT}/references/compression.md` 다. 남기는 불변량은 의도·steering·방향·goal 넷, 나머지 원자료(질문 라운드 전문·landscape 원문·steelman 중간 추론)는 audit 에 남는다.

오늘부터 `context-brief` 도 이 규약을 **게이트로 집행**한다 — payload 외부 URL 금지 · §6 은 사용자 원문 S1~Sn 전부 · landscape 원자료는 audit 결속. 집행 지점만 seed 와 다르다: seed 는 `check_seed.py`, brief 는 아래 Step A ⑦ 의 `check_brief.py`.

종료 driver는 **커버리지 원장의 floor 5차원이 전부 `closed`** 이고 마지막 포화 판정이 «포화» 이거나 사용자가 종료를 고른 것이다(고정 라운드 수가 아니다 — 이중 종료).
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
그 내용을 payload `## 3. Open Questions` 에 한 항목으로 옮긴다.

**모델 판단으로 맹점 조사를 건너뛴 floor** — `floor:blind_spot` 의 `evidence` 가 `모델 판단으로 건너뜀` 으로
시작하면(audit §2 의 `맹점 조사` 건너뜀 줄과 짝이다) 사용자-승인 박제와 같은 길로 간다 — 그 내용을 payload
`## 3. Open Questions` 에 한 항목으로 옮겨 다음 단계가 열린 것으로 본다.

### 분해 판단 — Step A 직전

종료가 정해진 뒤 brief 를 쓰기 전에 이 일을 spec 하나로 할지 나눌지 사용자와 정한다. 나누지 않으면 아래 Step A 부터 지금 흐름 그대로다 — 로드맵을 만들지 않는다.

1. **신호 셋.** 컨텍스트 쌓기가 모은 것에서 세 숫자를 한 줄씩 보인다. 숫자마다 근거 번호를 괄호에 붙인다. 컷오프는 두지 않는다 — 숫자는 판단 재료이고 판정은 사용자가 한다.
   - 따로 승인할 수 있는 덩어리 수 — 확정 항목 · 열린 질문을 닿는 대상(고칠 자리 · 하류 단계)으로 묶은 결정 묶음의 수. 보기: `따로 승인할 수 있는 덩어리 3 (C1 · C2 / OQ2 · RC3 / D5)`.
   - 파일 영역 수 — 조사에서 나온 고칠 자리(`RC<n>` 의 경로)의 플러그인 · 디렉토리 수. 보기: `파일 영역 2 (plugins/a/ ← RC1 · RC2 / shared/ ← RC4)`.
   - 사용자 원문 갈래 수 — 최초 요청(S1)과 이후 발화가 말하는 일의 갈래 수. 보기: `사용자 원문 갈래 2 (S1 · S7 / S12)`.

   이어서 권고 한 줄 — 「하나로 충분해 보인다 — <이유>」 또는 「나누는 게 좋아 보인다 — <이유>」.
2. **판정.** `AskUserQuestion` 하나:
   ```javascript
   AskUserQuestion({
     questions: [{
       question: "신호 셋 — 덩어리 <n> · 파일 영역 <n> · 원문 갈래 <n>. 이 일을 어떻게 진행할까?",
       header: "분해 판단",
       options: [
         {label: "spec 하나로", description: "얻음: brief 하나를 brainstorming 하나로 바로 넘겨 빨리 시작한다 · 내줌: 따로 승인할 덩어리가 있어도 한 설계에 묶여 뒤늦게 쪼개야 한다"},
         {label: "나눈다 — 확정 뒤 로드맵 잡기로", description: "얻음: brief 를 확정해 커밋한 뒤 로드맵 잡기에서 에픽 표를 짜 덩어리마다 따로 승인한다 · 내줌: 작은 일이면 로드맵과 묶음 파일만 늘려 과하게 나눈 셈이 된다"}
       ],
       multiSelect: false
     }]
   })
   ```
   권하는 쪽의 이유는 그 선택지의 얻음에 담는다 — 권고 줄에 대가를 따로 붙이지 않는다.
   권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다 — 위 권고 한 줄이 가리키는 쪽이다. 라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다.
   「spec 하나로」면 Step A 로 간다.
3. 「나눈다」 면 Step A 가 §7 첫 줄에 `분해됨 — <로드맵 경로>` 를 쓰고(로드맵 경로는 레포 설정의 로드맵 폴더(`roadmaps_dir`) 아래, 결과물 파일 이름에서 끝의 `-context.md`(옛 꼴 줄기면 옛 `-interview.md`)를 뗀 이름의 폴더의 `roadmap.md` 를 레포 루트 기준 상대경로로 — 지금 규칙), 표는 다음 단계(로드맵 잡기)가 짠다. 그다음 Step A 로 간다.

### Step A — brief 작성 (terminal 산출물, 2파일)

1. `${CLAUDE_PLUGIN_ROOT}/templates/interview-brief-template.md`로 payload **8-section**
   구조(§0 한눈에 – §7 Next Action)를, `${CLAUDE_PLUGIN_ROOT}/templates/interview-audit-template.md`로
   audit 템플릿의 절 구조를 확보합니다.
2. 경로 (둘 다 워크트리 안 → `Write` tool 사용): payload · audit 경로는 상태 파일 이름에서 `.state.md` 를 뗀
   `<줄기>` 에 `.md` · `.audit.md` 를 붙인 것이다(`state-file.md`). 날짜 · 주제로 다시 계산하지 않는다.
   - payload: `<줄기>.md` — 상태 파일 줄기 그대로(새로 시작한 일은 `<YYYY-MM-DD>-<kebab-topic>-context.md`, 옛 꼴 상태 파일로 이어 온 일은 그 파일의 줄기)
   - audit:   `<줄기>.audit.md`
   - payload frontmatter: `type: context-brief`(어느 줄기든), `next_phase: superpowers:brainstorming`(기본 다음 단계 — 끝 게이트의 둘째 질문에서 다른 단계를 고르면 B-3 이 그 skill 의 완전명으로 바꾼다),
     `session_id`(기존 spec-distill 세션 재사용), `audit_file`(audit의 **basename만** —
     경로 구분자가 들어가면 게이트가 거부합니다), `user_sourced_items[]`.
3. **`user_sourced_items` 직렬화**: state의 `user_statements`를 훑어 제약으로 승격할 항목을
   고르고, 각각에 id·`source`·`statement`·`evidence`(그 발화의 `S<N>`)를 붙입니다.
   **이 시점의 `status`는 전부 `provisional`입니다** — `confirmed`는 Step B-0의 사용자 확인
   으로만 발생합니다. 모델 추론은 이 리스트에 넣지 말고 본문에 ✎ 프로즈로 씁니다.
   payload §6 에는 `S1` 과 `user_statements` 발화 전량(S1~Sn)을 두고, 같은 S2 이상을
   **audit §6** 에도 같은 글자로 **전문 보존**(append-only)하며 각각 `S<N>` 앵커를 답니다. §6 의 표시는 audit 템플릿의 출처 표기를 따른다 — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론.
   **최초 요청 원문은 `S1`이다.** 「풀린 입력」(진입 단계 2 의 결과 — rough request 그대로이거나
   `@경로` 의 파일 전문)을 `user_statements`의 첫 항목과 **같은 형식**으로 §6 맨 앞에 넣습니다.
   상태 파일로 이어 간 컨텍스트 쌓기면 「풀린 입력」은 그 파일의 `## 풀린 입력` 블록이다(`state-file.md`).
   framing 없이 시작한 컨텍스트 쌓기의 `S1` 은 이 「풀린 입력」 그대로다(첫 입력이 곧 원자료다):
   ```yaml
   - id: S1
     source: verbatim
     round: 0
     text: "<「풀린 입력」 원문 그대로>"    # P21 secret placeholder 치환 적용
   ```
   존재하면(인자 있음) `user_statements`의 id 번호도 이 예약을 반영해 `S1`이 아니라
   `S2`부터 시작합니다 — 최초 요청 원문 있으면 1, 없으면 0 을 더해 SKILL.md `사용자 발화
   기록`의 번호 공식과 합의합니다.
   비어 있으면(인자 없이 호출) `S1`을 만들지 않고 `S2`부터 시작하지 않습니다 — 번호는
   `user_statements`의 순서를 따르고, 최초 요청이 없으면 첫 사용자 답변이 `S1`입니다.
   **seed 로 시작한 컨텍스트 쌓기의 `S1` 은 seed 가 아니라 원자료다.** 「풀린 입력」이 `intent-seed`(옛 `interview-seed`) 전문이면 `S1` 의 본문을 손으로 옮겨 치지 않는다. payload §6 맨 앞에 앵커 줄 `- **S1** 🗣 최초 요청:` 한 줄만 두고(본문 없이) payload · audit · 상태 파일을 쓴 뒤 아래 순서로 간다. audit §6 에는 `S1` 을 두지 않는다.
   ```bash
   SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
   PAYLOAD_P="<Step A 2 의 payload 경로>"
   STATE_P="${PAYLOAD_P%.md}.state.md"
   [ -e "$STATE_P" ] || { printf '%s\n' "[spec-distill] 원자료를 싣지 않았다 — 상태 파일이 없다: ${STATE_P}" >&2; exit 2; }
   rc=0; python3 "$SD/scripts/raw_source.py" locate --interview "$PAYLOAD_P" --absolute || rc=$?
   if [ "${rc}" -eq 2 ]; then printf '%s\n' "[spec-distill] 원자료 판결 종료 코드 2 — 판결 줄이 없다. 아래 마지막 갈래대로 멈춘다" >&2
   elif [ "${rc}" -ne 0 ]; then printf '%s\n' "[spec-distill] 원자료 판결 종료 코드 ${rc} — 위 판결 줄대로 간다(멈추지 않는다)" >&2; fi
   ```
   - `raw-source: FOUND <경로>` — 아래 「비밀값 확인」 을 먼저 하고, 그 뒤 `python3 "$SD/scripts/raw_source.py" place --interview "<payload 경로>"` 를 같은 꼴의 펜스로 돌린다. 마지막 줄이 `raw-source: PLACED …` 면 스크립트가 `S1` 항목을 써 넣었다 — 앵커 라벨은 「최초 요청(원자료 — framing 기록의 원문 절과 질문 전체 절)」 이고 본문은 framing 기록의 두 절이 글자 그대로다. 그 항목에 손대지 않는다. seed 전문은 payload 에 싣지 않는다.
   - `place` 의 마지막 줄이 `raw-source: UNLOADABLE <n>줄 — 첫 줄 …` 이면 그 글은 결과물 문법이 받지 않아 그대로 싣지 못한다. 앵커 줄을 `- **S1** 🗣 최초 요청(원자료를 그대로 싣지 못함 — 모델이 줄인 글. 원자료는 framing 기록의 원문 절과 질문 전체 절):` 로 쓰고 본문에 seed 전문(「풀린 입력」)을 지금 규칙대로 싣는다(P21 치환 · 열 0 펜스). 사용자에게 `원자료를 그대로 싣지 못했다 — 결과물 문법이 받지 않는 줄 <n>개(첫 줄: <판결 줄의 절 이름과 줄 번호>). 첫 칸에는 seed 전문(모델이 줄인 글)을 실었다` 한 줄을 보인다. 원문의 글자를 고쳐 싣지 않는다. 한 절만 싣지도 않는다.
   - `raw-source: LOST <사유>` — 앵커 줄을 `- **S1** 🗣 최초 요청(원자료를 찾지 못함 — 모델이 줄인 글):` 로 쓰고 본문에 seed 전문을 지금 규칙대로 싣는다.
   - `raw-source: NO-FRAMING` — 위의 「풀린 입력」 규칙 그대로다.
   - `[spec-distill] 원자료를 싣지 않았다 — 상태 파일이 없다: <경로>` 줄이 나오면 판결을 내지 않은 것이다 — 끝맺음을 멈추고 그 줄을 그대로 보인다(상태 파일을 만든 뒤 다시 부른다). `raw-source:` 판결 줄을 지어 내지 않는다.
   - 판결 줄 없이 `[raw_source] …` 줄로 끝나면(종료 코드 2) 끝맺음을 멈추고 그 줄을 그대로 보인다 — 빈 앵커 줄로 나아가지 않는다.
   - 그 `[raw_source]` 줄이 framing 기록의 절 구조 사유(같은 절 제목이 두 번 이상 · 절 순서가 템플릿과 다르다 · 절 시작으로 읽히지 않는다 · 절이 없다)면 고칠 자리는 그 framing 기록 파일(이 걸음의 `raw-source: FOUND <경로>`)의 그 줄이다 — 제목 줄을 `templates/interview-seed-audit-template.md` 의 제목 순서와 꼴대로 고친 뒤 이 걸음부터 다시 돈다.
   **비밀값 확인 — 싣기 전에, 갈래를 가르기 전에.** 판결이 FOUND 면 `place` 를 돌리기 전에 그 기록 파일의 `## 1. 원문` 절과 `## 2. 질문 전체` 절을 읽는다. token · key · credential 로 보이는 값이 있으면 **싣지 않고 멈춘다** — 그대로 싣지 못하는 갈래로 갈 글이어도 이 확인이 먼저다. 값 자체는 보이지 않고 `첫 칸에 실을 글에 비밀값으로 보이는 값이 있다 — <원문 절 | 질문 전체 절> <k>째 줄, <무엇으로 보이는지>` 를 값마다 한 줄을 보인 뒤 `AskUserQuestion` 하나로 묻는다 — 「기록부터 가린다 (권장)」(얻음: framing 기록 파일의 그 값을 가림 표시로 바꾼 뒤 가린 글을 첫 칸에 싣는다 · 내줌: 이미 쓴 기록 파일을 고쳐 쓰고, 커밋돼 있었다면 그 값은 git 이력에 남는다) · 「비밀값이 아니다 — 그대로 싣는다」(얻음: 잘못 본 값을 건드리지 않고 원문 글자 그대로 싣는다 · 내줌: 정말 비밀값이면 결과물과 그 사본에 그대로 커밋된다) · 「멈춘다」(얻음: 아무것도 싣지 않고 끝맺음을 멈춘다 · 내줌: 결과물이 완성되지 않아 값을 처리한 뒤 다시 끝맺어야 한다).
   「기록부터 가린다」 면 framing 기록 파일의 그 값을 먼저 `<REDACTED>` 나 `<REDACTED:라벨>` 로 바꾸고(SKILL 의 「Secret 기록 금지」 집합), 같은 값이 seed 파일이나 상태 파일의 `## 풀린 입력` 블록에 있으면 같은 표시로 함께 가린 뒤 `가린 자리 <N>곳 — <파일 · 절 · 줄>` 을 보인다. 그 뒤에 `place` 를 돌린다 — 기록이 먼저라 첫 칸과 기록의 글자가 같다. 첫 칸에서만 가리는 길은 없다. 바꾸는 것은 사용자가 고른 그 값뿐이다. 가린 파일은 B-3 의 커밋 펜스가 결과물과 같은 커밋에 넣는다. 그 기록 파일이 이미 커밋돼 있었으면(`git log -1 --format=%h -- <경로>` 가 비지 않는다) `이 값은 git 이력의 옛 커밋에 남아 있다 — 값을 폐기하고 바꾸는 것이 먼저다` 한 줄을 보인다.
   원문 보존은 **관례가 아니라 요구**입니다 — 구조 게이트가 payload §6 앵커가 S1 부터 빠짐없고
   audit §6 앵커를 다 포함하는지 보고, `check_verbatim_coverage.py`(brief 리뷰 진입 게이트)가
   state 발화 전량이 payload §6 에 같은 글자로 있는지 봅니다. 앵커 줄은 열 0 의 `- **S<N>**` 꼴만
   받습니다(들여 쓴 · 전각 공백 · `*` 불릿 줄은 거부). 발화 원문에 백틱 · 코드 펜스 · `&` 문자 참조 · `<태그>` ·
   HTML 주석이 있으면 원문을 고치지 않고 `>` 인용 대신 앵커 줄 바로 아래 **열 0 펜스**에 그대로 싣습니다 — 펜스
   글자는 원문의 가장 긴 같은 글자 줄보다 길게(예: `~~~~`), payload §6 과 audit §6 에 같은 모양으로. 다만 펜스
   안이라도 앵커처럼 읽히는 글(예: `**S2**` · `- S2 …`)은 게이트가 거부한다. 무엇이 거부되는지와 그때 할 일은 게이트의 거부 말이 정하니 그 말을 따른다. 인용 줄은
   그 글자들을 거부합니다. 이 검사를 돌리지 못하면(검사 불가) 게이트가
   막고 사용자에게 계속할지 묻습니다.
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
   `#### ST<N> — <한 줄 요지>` 헤딩과 함께 verbatim으로 남기고(상태 파일 `## 반대 논거 기록 대기` 절의 블록을 글자 그대로 옮긴다), payload §5의 `verdict:` 항목이
   그 `ST<N>`을 참조합니다 — 양방향 일치가 게이트 대상입니다. 맹점 조사의 위험 줄은 상태 파일 `## 위험 줄 대기` 절에서 payload §5 로 옮긴다(번호는 아래 「위험 번호」).

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
   모델 판단으로 첫 범위 조사를 건너뛰었으면 `coverage-mapper 0` 으로 적는다 — 대기 줄 블록의
   `- 모델 판단으로 건너뜀 — 범위 조사: <이유>` 줄이 그 0 을 받친다(줄이 없으면 게이트가 막는다).
   그 아래에 `${CLAUDE_PLUGIN_ROOT}/skills/context-build/references/saturation.md` 의 `### audit §2 줄` 형식으로 조사 호출 줄
   한 줄을 쓰고(state `research_dispatches` · `research_limit` · `research_log` 의 `device: orchestrator` 수), 이어서 state 본문
   `## audit §2 대기 줄` 블록을 글자 그대로 순서대로 옮겨 씁니다 — 상한 도달 · 판정 상한 도달 · 포화 판정 · 사용자 종료 · 모델 판단으로 건너뜀 줄이
   사건 순간 거기 쌓였습니다. 다시 짓거나 요약하지 않고, 블록에 없는 줄을 기억으로 보태지 않습니다.
   게이트는 `포화 판정 <k>:` · `사용자 종료(@S<n>)` 줄의 **마지막**을 봅니다.
   같은 때에 state 본문 각 `## R<n>` 의 `- 대체됨: <앞 믿음> → <바로잡은 사실> (조사 <n>)` 줄을 라운드 순서대로 audit
   `## 5. 프로세스 로그` 에 글자 그대로 옮겨 씁니다(`${CLAUDE_PLUGIN_ROOT}/references/fresh-evidence.md` 「낡은 지식 바로잡기」). 없으면 쓰지 않습니다.
   같은 걸음에 state 본문 각 `## R<n>` 의 `- 확인 RC<n> — …` 줄을 라운드 순서대로 audit `## 5. 프로세스 로그` 에 글자 그대로 옮겨 씁니다. 없으면 쓰지 않습니다.

   **위험 번호.** payload §5 의 위험 줄마다 `위험` 바로 뒤에 번호를 박는다 —
   `- 위험 K<n> — <숨은 가정 | 실패 양식 | 리뷰 참고> …`. 숨은 가정 · 실패 양식 · 리뷰 참고 순으로 K1 부터 매긴다.
   박은 번호는 그 위험의 정체다 — 뒤에 위험 줄을 지우거나 옮겨도 다른 줄의 번호를 고치지 않는다. 지운 위험의 번호는 다시 쓰지 않는다 — 새로 더하는 위험 줄은 지금까지 나온 가장 큰 K(이 brief 의 §5, 로드맵이 있으면 그 `## 위험 번호표` 까지)의 다음 수를 받는다.

   Step A.5 의 되묻기 갈래로 다시 돌 때는 audit §2 의 사건 줄 · §5 의 옮긴 줄 · payload §6 · audit §6 을 state 에서 통째로 다시 쓴다 — 덧붙이지 않는다. 다시 써도 audit §6 은 append-only 다 — state `user_statements` 는 append 로만 쌓이므로 다시 지은 §6 은 있던 S 그대로에 새 S 가 뒤에 더해진 글이다.
5. **조사 주장의 인계 — 세 방향을 같은 id 로 맞물린다.** 하류에 **지시를 걸지 않고** 「읽을 이유」까지만 만든다.

   - **결정 연결(§4 · §5 → 결정)** — 조사 항목 줄 **끝**에 넷 중 하나: 레포 `[RC3 → OQ1]` ·
     `[RC3 → 없음]`(닿는 결정 없음), 웹 `[→ OQ1]` · `[→ 없음]`. **레포 주장은 연결 안에 항상
     `RC<n>` 을 싣는다**(웹 주장만 `[→ …]`). 복수는 `[RC3 → OQ1 · OQ4]` 로 전부
     직렬화한다. §4 항목은 여러 줄로 쓸 수 있다 — 첫 줄이 항목이고 들여쓴 줄은 본문이다.
     **연결은 첫 줄 끝에 둔다** — 본문 줄의 연결이나 첫 줄에 없는 `RC<n>` 은 게이트가 red 로 낸다.
   - **역참조(§3 → 근거)** — 그 OQ 줄이 근거의 **id** 를 담는다: `- OQ1: <한 줄> → 근거 RC3`.
     §3 항목은 결정이다(열린 것과 해결한 것) — 연결의 *대상*이고 출처가 아니다.
   - **요약 상호참조(§0 → 근거)** — §0 의 결정 목록도 같은 id 를 쓰고 **상태 토큰**을 단다:
     `- OQ1 [열림] — <한 줄> → 근거 RC3` / `- OQ4 [해결 ⟨S2⟩] — <한 줄> → 근거 RC3`.
     해결로 닫은 결정도 §3 에 그대로 남고, 그 항목에 해결 표시와 해결 내용 한 줄을 붙인다:
     `- OQ4 [해결 ⟨S2⟩]: <원래 질문> — 해결: <한 줄> → 근거 RC3`. §0 과 §3 모두 state
     `orchestration.open_decisions[]` **전량**이다. 게이트는 §0 의 해결 결정이 §3 에 있는지와 해결
     토큰의 `S<n>` 이 payload §6 에 있는지를 본다. 이 목록은 **불릿 줄**이어야 한다(게이트가
     `- `/`* ` 로 시작하는 줄만 항목으로 읽는다).

   해결된 결정을 §0 에서 지우지 않는 이유: 조사가 그 결정을 해결하는 데 기여했으면 그것이 성공
   사례인데, 목록에서 빠지면 게이트의 실재 검사가 그 조사를 red 로 만든다. 「열림」은 상태 토큰이
   말하고 목록에서의 부재가 말하지 않는다.

   **§2 는 대상이 아니다** — 거기에 연결을 걸지 않는다.

6. **V2 검문소 — 무조건, 누락 대조만.** payload 의 모든 `RC<n>` 에 대응하는 확인 줄이 audit
   `## 5. 프로세스 로그` 에 있는지 대조한다. **확인 «행위» 는 V1 이 라운드 안에서 이미 했으므로
   여기서 다시 확인하지 않고 누락 대조만 한다.** 이 검문소는 웹 스위치와 steelman trigger 어느
   것에도 종속되지 않는다.

   ```bash
   # payload 조사 항목(§4 · §5 의 불릿 줄)의 RC<n> 전량 ↔ audit §5 불릿 줄의 확인 줄 — 차집합이 비어야 한다.
   # 불릿은 `-`·`*` 둘 다, 들여쓰기 허용 — 게이트의 항목 판독과 같은 관례다. §3·§0 의 역참조는 출처가 아니다.
   PL="<Step A 2 의 payload 경로>"
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
   python3 "$SD/scripts/check_brief.py" gate "<Step A 2 의 payload 경로>"
   ```
   exit ≠ 0 이면 **brief를 finalize하지 말고** 보고된 미충족 항목을 보완(누락 섹션·무인용
   landscape·형식 미달 verdict 항목·`기각` 0건·floor open·bijection 불일치·**`confirmed`
   0건 sentinel 누락**·포화 판정 줄 없음 · 마지막 판정 «아직» · 판정 불가 뒤 조사 계속이 마지막 · 형식 밖). 통과(exit 0)할 때까지 반복합니다.
   사유가 「나눈 일은 건너뛸 수 없다」 면 건너뜀 줄만 지워 통과시키지 않는다 — B-S 대로 건너뛴 조사 · 리뷰를 돌린 뒤에 지운다.
8. **위험 번호 검사 — 「나눈다」 를 고른 결과물만, 커밋 전에.** 구조 게이트가 통과한 뒤 생성기의 「검증만」 하는 길로 §5 위험 줄 번호(빠짐 · 겹침)를 잰다. 파일을 쓰지 않는다. 첫 줄이 `brief-risk: FAIL 못 읽었다: …` 면 결과물이나 audit 을 읽지 못한 것이다 — 그 줄을 그대로 보이고 멈춘다(§5 를 고치지 않는다). 그 밖의 `brief-risk: FAIL <사유>` 면 그 자리에서 위 「위험 번호」 대로 §5 위험 줄을 고친 뒤 7 과 이 걸음을 다시 돈다 — 다음 단계는 결과물을 고칠 수 없다. rc 2 는 사용법 오류다 — 출력을 그대로 보이고 멈춘다. B-3 에서 커밋하기 전에 한 번 더 돈다(리뷰 · B-A 가 위험 줄을 더했을 수 있다).
   ```bash
   SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
   PL="<Step A 2 의 payload 경로>"
   python3 "$SD/scripts/roadmap_write.py" check --brief "$PL" --audit "${PL%.md}.audit.md"
   ```

### Step A.5 — brief 리뷰 파이프라인 진입 (Law 2 분리 리뷰)

게이트(Step A 7)를 통과한 payload는 **Law 1 구조 자기검사**를 마친 것이고, 아직 **분리 리뷰**를 받지 않았습니다. 여기서 `reviewing-brief` skill로 넘깁니다 — 문서 리뷰 엔진이 층 1(방향성)·층 2(충실도)를 보며, 절차는 그 skill이 소유합니다(여기에 복제하지 않습니다).

핸드오프 변수 2개를 **절대경로**로 세팅합니다(엔진은 상대 문서 경로를 거부하고, codex 산출물 경로는 그 skill 이 도출합니다). 펜스의 `STATE_F` 자리표는 이 컨텍스트 쌓기의 상태 파일 절대경로로 바꾼다 — payload 는 그 줄기에서 짓고 의도 폴더와 파일 이름으로 다시 짓지 않는다:

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
STATE_F="<상태 파일 절대경로>"
case "$STATE_F" in /*.state.md) ;; *) echo "[spec-distill] 상태 파일 경로가 비었거나 자리표 그대로거나 절대경로가 아니다 — 이 컨텍스트 쌓기의 상태 파일 절대경로로 바꿔 다시 돌린다" >&2; exit 1 ;; esac
PAYLOAD="${STATE_F%.state.md}.md"   # Step A가 방금 쓰고 검증한 경로 — 상태 파일 줄기 그대로
AUDIT="${PAYLOAD%.md}.audit.md"                      # payload 의 audit sidecar (§6 S2+ 원문)
```

```
Skill spec-distill:reviewing-brief $PAYLOAD $AUDIT
```

두 인자는 **주석이 아니라 호출 라인 위에** 있어야 합니다.

- 지출 승인 게이트는 없습니다(`cost_class: medium`). 재리뷰 상한은 안전 정지이고 승인 게이트에서 사용자가 연다 — 상한 뒤의 추가 라운드는 사용자가 그 skill 의 승인 게이트에서 고른 선택지 이름이나 기타 칸에 쓴 말을 승인으로 남겨(출처와 함께 기록) 열어야만 돕니다.
- `DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW=1`이면 파이프라인이 전체 skip되고 skip record가 Step B 게이트 질문에 표시됩니다 — 조용한 생략이 아닙니다.
- 리뷰가 payload 를 수정할 수 있습니다(§0 · §2~§5 — 프로필의 수정 자리. §1 은 사용자 결정이고 §6 은 추가만 허용이다). 수정이 일어나면 Step B는 **리뷰 후 최종 문서**를 봅니다.
- 산출물 셋(엔진 게이트 결과 / 냉독 요약 + gap / degrade 채널)이 Step B 게이트로 넘어옵니다. 엔진
  승인 게이트의 2단계(진행 옵션)는 그 skill 이 띄우지 않고 아래 Step B 가 묻습니다.

`reviewing-brief` 가 진입 게이트에서 `first_cell` · `source_mismatch` 로 멈추면 그 skill 의 `vc_rc` 표 그 행대로 간다 — 이 끝맺음 안(커밋 전)에서만 첫 칸은 Step A 3 의 갈래를 다시 타고 표시는 상태 파일의 `source` 에 맞춘다. 세션을 넘겨 따로 부른 리뷰는 끝난 결과물이라 고치지 않는다.

**닫은 답의 출처로 멈추면 — 되묻기 갈래.** `reviewing-brief` 가 진입 게이트에서 `not_chosen`(컨텍스트 쌓기를 닫은 답 — 외부 선례 무관 · 사용자 판단 포화 — 이 state 에 고른 선택지 `source: chosen` 으로 기록돼 있지 않다)으로 멈추면, 이 세션에서 그 닫힌 질문을 `AskUserQuestion` 선택지로 다시 묻는다 — 닫는 선택지(처음 닫은 답과 같은 「외부 선례 무관」 · 「조사 불필요」) · 「조사 계속」. 권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다.
- **닫는 선택지**면 그 답을 새 `S<n>` 으로 state `user_statements` 에 `source: chosen` 으로 기록하고, 닫힌 답의 종류에 따라 한 곳만 바꾼다. 사용자 판단 포화였으면 그 S 를 가리키는 새 포화 판정 줄(`- 포화 판정 <k>: 사용자 판단 포화(@S<n>) — 조사 불필요` — `<k>` 는 대기 줄 블록의 마지막 포화 판정 번호 다음 수)을 state 본문의 대기 줄 블록 한 곳에만(`## audit §2 대기 줄`) 덧붙인다 — 옛 줄은 고치지 않고 기록으로 남긴다(게이트는 마지막 줄을 본다). 외부 선례 무관이었으면 포화 줄은 건드리지 않고 brief §4 그 줄의 `@S` 만 새 S 로 바꾼다(외부 선례 답을 조사 전체를 끝내는 승인으로 읽지 않게). 그다음 Step A 의 3 · 4 · 7 · 8 을 다시 돈 뒤 Step A.5 로 돌아간다(8 은 「나눈다」 를 고른 결과물만). 라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다.
- **「조사 계속」**이면 같은 세션의 라운드 루프로 돌아가고, 다시 닫을 때 이 마무리 단계를 처음부터 돈다. 사용자가 다시 답하지 않으면 리뷰는 멈춘 채로 남는다. 세션을 넘겨 따로 부른 `reviewing-brief` 가 이 사유로 멈추면 끝난 컨텍스트 쌓기라 진행 기록에서 다시 이을 수 없다 — 멈춤 문장이 그 사실을 함께 알린다.

### Step B — proceed 게이트 (handoff 방식 제안)

brief는 **단독 완결 terminal 산출물**입니다(handoff는 강제가 아니라 사용자 선택).
Step B는 단일 책임 단위입니다: *brief가 완결되면 다음 stage(brainstorming 해답공간) 진입
방식을 사용자에게 제안한다.* 입력 = 완결·`check_brief.py` 검증된 brief 경로 + superpowers
가용성.

**이 게이트의 공통 계약(순서 · 두 가드 · 예외 경로)은 `${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 에 있습니다.**
`spec-review` 의 proceed 게이트와 **같은 골격**입니다. Step B 에
실제로 진입할 때 읽고 그대로 따릅니다. 아래에는 이 skill 의 **어휘**(확정 후보 제시 · 옵션 라벨 ·
다음 세션 줄 · superpowers 가용성 분기)만 남습니다.

```
Read ${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md
```

플러그인 레벨 경로입니다 — 이 파일 옆이 아니라 플러그인 루트 아래
(`${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md`)에 있습니다.

#### B-0 — 확정 후보 제시

Step A가 끝난 시점에 `user_sourced_items`는 **전부 `provisional`**입니다. `confirmed`로의
전이는 아래 B-2 게이트에서 사용자가 확정-후-진행 옵션(①/②)을 고를 때, 또는 superpowers 가 없을 때 B-1 끝 질문의 「확정하고 끝낸다」 를 고를 때만 일어납니다.
별도 확인 의례를 만들지 않는 이유는 종료 시 사용자 상호작용이 2회가 되기 때문입니다 —
확인을 기존 proceed 게이트에 흡수해 1회로 유지합니다.

게이트를 띄우기 *전에* 확정 후보 목록을 **프로즈로** 출력합니다(목록이 길 수 있으므로
`AskUserQuestion`은 선택지만 담당):

- 각 후보를 `<id> — <statement> (source, ⟨S<N>⟩)` 한 줄로.
- **확정 후보에서 제외한 항목도** 한 줄씩 이유와 함께 보여줍니다.
- 모델의 후보 판정은 **제안일 뿐**입니다. 어떤 항목도 이 출력만으로 `confirmed`가 되지 않습니다.

**함께 보이는 공시** — B-A 가 끝난 뒤, 확정 후보와 같은 프로즈 출력에 이 순서로 보입니다. 접지 않습니다:

1. brief §1 의 줄마다 출처 — `§1 <Goal | Non-goal>: <줄> — 출처 ⟨S<n>⟩ | 모델 추론`(줄 끝 표시 그대로).
   「모델 추론」 줄은 사용자가 말하지 않은 목표 · 비목표다.
2. 확정 후보와 제외 항목(위).
3. `확정으로 올리지 않은 발화 <N>개 — S<n> · <한 줄 이유>` — state `user_statements` 중 어느 `user_sourced_items`
   의 `evidence` 에도 쓰이지 않은 발화, 하나에 한 줄. 0개면 `확정으로 올리지 않은 발화 0개`.
4. `위험으로 보낸 참고 <N>개 — <id> · <이유>` — B-A 가 §5 `위험 — 리뷰 참고` 로 보낸 항목, 하나에 한 줄.
5. (붙여넣은 seed 로 시작한 세션만) `출처를 가르지 못한 seed 문장 <N>개 — 붙여넣기라 분류기를 못 돌림` —
   이 폴더의 `seed-input.md` 가 R1 에서 보인 그 줄을 다시 보입니다.

「확정 목록 수정」(③)에서 사용자는 이 다섯을 고칠 수 있습니다 — §1 줄을 고치거나 빼고(출처 표시도 함께, 줄 끝
`⟨S<n>⟩` | `⟨모델 추론⟩` 모양을 지킨다), 안 올린 발화를 확정 후보에 더하고, 위험으로 보낸 참고를 §3 열린 질문으로
올리고(§0 에도 `[열림]` 으로 — §0 · §3 이 같은 OQ 집합을 갖는다. 올린 항목의 §5 `위험 — 리뷰 참고` 줄은 같은 write 에서 지운다), 붙여넣은 seed 의 문장 중 자기 말을 사용자 출처로
표시해 확정 후보에 더합니다(`source: verbatim` · `evidence: S1`). 고친 뒤 `check_brief.py gate` 를 다시 돕니다.

**재제시 상한**: 최초 제시는 0회째입니다. 사용자가 옵션 ③(확정 목록
수정)을 고를 때마다 state 의 `confirm_repost_count` 를 +1 합니다. 2회에 닿은 뒤 다시 ③ 을 고르면 강등하지 않고
`AskUserQuestion` 으로 「계속 고친다(2번 더)」 · 「지금 목록으로 확정」 · 「brief 만 종료」를 묻습니다 — 자동 강등은 없다.
무엇을 할지는 사용자가 매번 고릅니다. 권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다:

```javascript
AskUserQuestion({ questions: [{
  header: "확정 목록",
  question: "확정 목록을 두 번 고쳤습니다. 어떻게 할까요?",
  multiSelect: false,
  options: [
    {label: "계속 고친다(2번 더)", description: "얻음: 카운터를 0 으로 돌려 확정 목록을 더 고친다 · 내줌: 확정이 또 미뤄지고 같은 목록을 두 번 더 확인해야 한다"},
    {label: "지금 목록으로 확정", description: "얻음: 지금 확정 후보를 확정으로 바꾸고 왔던 끝 질문으로 돌아가 끝낼 길을 고른다 · 내줌: 안 고친 잘못이 있으면 확정으로 굳은 채 넘어간다"},
    {label: "brief 만 종료", description: "얻음: 아무것도 확정하지 않고 여기서 끝낸다 · 내줌: 모든 항목이 잠정으로 남고 다음 단계로 넘어가지 않는다"}
  ]
}]})
```

카운터는 프로즈 self-tracking이 아니라 상태 파일에 씁니다:

```bash
# confirm_repost_count 는 상태 파일(<줄기>.state.md)의 frontmatter 에 Edit 로 쓴다(③ 마다 +1, 「계속 고친다(2번 더)」는 0 으로 되돌림)
```

#### B-A — 참고(advisory) 목록 — 한 번 보이고 §3 · §5 에 박제

B-1 분기와 무관하게 B-1 보다 먼저 돕니다. 엔진 `advice` 원장의 참고 항목(`must_catch` 밖 축 — 오늘은 overdesign)은
라운드 게이트에 오지 않았습니다 — 여기서 한 번 보이고 brief 에 박제합니다. `PAYLOAD` 는 Step A.5 의 그 절대경로입니다.
이 펜스가 brief 리뷰 원장의 마지막 쓰기입니다 — 표지를 잡아(이미 잡았으면 그대로) 쓰고 끝에서 풉니다.

<!-- advice-ba:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
PAYLOAD="<Step A.5 의 PAYLOAD 절대경로>"
AUDIT="${PAYLOAD%.md}.audit.md"
STATE="${PAYLOAD%.md}.state.md"
harness_sid="$(python3 "$SD/scripts/state_path.py" session-id || true)"
ROOT="$(python3 "$SD/scripts/state_path.py" state-root-for "$PAYLOAD" || true)"
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
  adv_list="$(python3 "$SD/scripts/docreview_state.py" advice-list --state-dir "$STATE_DIR" 2>&1)" || adv_rc=$?
  adv_out="$adv_list"
  if [ "$adv_rc" -eq 0 ]; then
    echo "advice-list: $adv_list"
    adv_out="$(python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" --log-file "$AUDIT" --render --where "brief §3 · §5" 2>&1)" || adv_rc=$?
    [ "$adv_rc" -ne 0 ] || printf '%s\n' "$adv_out"
  fi
  if [ "$adv_rc" -ne 0 ]; then
    printf '%s\n' "$adv_out" >&2
    echo "[spec-distill] 참고 목록 판독 · 표시 실패(rc $adv_rc) — 위 stderr 사유를 게이트 앞 글에 싣는다."
    printf '%s' "$adv_out" | grep -qE '"reason": "(profile_has_no_must_catch|advice_module_missing)"' || python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" --render --where "brief §3 · §5" || echo "[spec-distill] 참고 목록 표시도 실패했다 — 목록 본문 없음을 게이트 앞 글에 싣는다."
  fi
fi
[ -z "${STATE_DIR:-}" ] || [ ! -d "$STATE_DIR" ] || [ -z "${harness_sid:-}" ] || python3 "$SD/scripts/ledger_marker.py" release --dir "$STATE_DIR" --session "$harness_sid"
```
<!-- advice-ba:end -->

펜스 출력(머리 한 줄 + 항목 줄 + `외 K건` — 머리 줄이 줄 수 상한과 그 출처를 밝힙니다)과 `[spec-distill]` 줄을 그대로 보입니다. 이어 `advice-list:` 줄의 JSON
(`advice-list` 하위 명령이 읽기 전용으로 낸 목록)의 `items` 중 `shown` 이 거짓이던 항목을 payload 에 박제합니다 — 표시가 돌았으면 방금 보인
항목들이고, 「표시도 실패했다」 줄이 나왔으면 사용자가 보지 못한 항목이라 그 사실을 B-2 에 싣습니다.
`advice-list:` 줄이 없으면(원장 없음 · 판독 실패) 박제할 것이 없고 그 `[spec-distill]` 줄을 B-2 에 싣습니다.

펜스 출력에 접는 줄(`… 외 K건`)이 있으면 박제로 가기 전에 `AskUserQuestion` 한 번 — 「참고 전부 보기 (권장)」 ·
「접은 채로 둔다」. 설명은 이렇게 쓴다 —
「참고 전부 보기」: 얻음: 접힌 항목까지 요약 전문으로 읽은 뒤 박제한다 · 내줌: 참고가 많으면 읽는 데 시간을 쓰고 뒤의 게이트 결정에 쓸 주의가 줄어든다
「접은 채로 둔다」: 얻음: 보인 요약만 보고 바로 박제로 넘어간다 · 내줌: 접힌 K건의 내용을 못 본 채 brief 에 박제된다
「참고 전부 보기」면 아래 펜스로 목록 전부를 다시 읽어 요약 전문으로
보입니다(`advice-list` 는 읽기 전용이다. 라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다):

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
PAYLOAD="<Step A.5 의 PAYLOAD 절대경로>"
ROOT="$(python3 "$SD/scripts/state_path.py" state-root-for "$PAYLOAD" || true)"
STATE_DIR="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$ROOT" --doc "$PAYLOAD" || true)"
[ -z "${STATE_DIR:-}" ] || python3 "$SD/scripts/state_path.py" path-inside --root "${ROOT%/.claude/spec-distill}" "$STATE_DIR" || STATE_DIR=""
if [ -z "${STATE_DIR:-}" ] || [ ! -f "$STATE_DIR/docreview-state.md" ]; then
  echo "[spec-distill] 참고(advisory) 목록 없음 — brief 리뷰 원장을 찾지 못했다(STATE_DIR='${STATE_DIR:-}'). 게이트 앞 글에 싣는다."; exit 0
fi
adv_all="$(python3 "$SD/scripts/docreview_state.py" advice-list --state-dir "$STATE_DIR")" \
  || { echo "[spec-distill] 참고 전부 보기 실패 — 엔진 원장을 읽지 못했다. 게이트 앞 글에 싣는다."; exit 0; }
printf '%s' "$adv_all" | python3 -I -X utf8 -c '
import json, sys
items = json.load(sys.stdin).get("items") or []
print("참고 전부 %d건" % len(items))
for it in items:
    print("- [%s] %s — %s" % (it.get("category"), it.get("anchor"), " ".join(str(it.get("summary") or "").split())))
'
```

가르는 판단은 한 줄입니다:

**이 brief 를 넘기기 전에 사용자가 고를 것이 있는가.**

- **있으면 §3.** `- OQ<n>: [참고 · <category>] <summary> (리뷰 <id>)` 로 적고, §0 결정 목록에
  `- OQ<n> [열림] — [참고 · <category>] <summary>` 를 함께 적습니다. `<n>` 은 §3 · §0 의 가장 큰 OQ 번호 다음입니다.
- **없으면(알고 있으면 되는 위험) §5.** `- 위험 K<n> — 리뷰 참고 | [<category>] <anchor> — <summary> (리뷰 <id>)`(`<n>` 은 Step A 「위험 번호」 의 다음 수 — 지운 위험의 번호는 다시 쓰지 않는다) 로 적습니다. brief 의 위험 줄에 번호가 없으면(옛 brief) 이 줄도 번호 없이 `- 위험 — 리뷰 참고 | …` 로 쓴다.

적은 뒤 — 적을 참고 항목이 없어도 — audit §2 의 사건 줄을 상태 파일의 `## audit §2 대기 줄` 블록에서 다시 짓고 구조 게이트를 다시 돕니다.
리뷰가 그 블록에 더한 건너뜀 줄은 여기서 검사에 닿고, B-2 의 게이트 앞 글이 읽는 `advisories` 는 이 실행의 것입니다.
failures 가 있으면 고치고 다시 돕니다. 사유가 「나눈 일은 건너뛸 수 없다」 면 끝 질문을 띄우지 않고 아래 B-S 로 갑니다:

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
PAYLOAD="<Step A.5 의 PAYLOAD 절대경로>"
python3 "$SD/scripts/check_brief.py" gate "$PAYLOAD"
```

#### B-S — 건너뛴 것을 나중에 돌릴 때

B-S 로 오는 자리는 Step A 7 · Step A.5 의 구조 게이트와 B-A 의 구조 게이트가 「나눈 일은 건너뛸 수 없다」 로 막았을 때, 그리고 끝 질문(B-2 · B-1)의 기타 칸에
사용자가 건너뛴 것을 하라고 적었을 때다. 새 길을 만들지 않고 지금 있는 길로 돌아간다. 건너뜀 줄의 집은 상태 파일의
`## audit §2 대기 줄` 블록이다 — 줄은 그 블록에서 지우고 audit §2 를 그 블록에서 다시 짓는다.

- **조사(범위 조사 · 맹점 조사 · 포화 판정)** — 그 건너뜀 줄을 대기 줄 블록에서 지우고 Step A.5 의 「조사 계속」 갈래로 간다(라운드 루프로
  돌아가 그 조사를 돌리고, 다시 닫을 때 이 끝맺음을 처음부터 돈다). 맹점 조사를 건너뛴 차원은 다시 열려 지금 규칙대로 사용자 발화로 닫힌다.
- **재비판 · codex** — 그 건너뜀 줄을 대기 줄 블록에서 지우고 audit §2 를 다시 지은 뒤 `reviewing-brief` 를 한 라운드 더 돈다(탐지부터 —
  재리뷰 상한에 든다). 줄만 지우고 audit 을 그대로 두면 그 skill 의 진입 게이트가 옛 audit 으로 구조 게이트를 돌려 나눈 일은 다시 막힌다.
  라운드가 끝나면 Step B 를 B-0 부터 다시 돈다(B-A 의 다시 짓기 · 게이트 포함).
- **읽어 보기** — 그 건너뜀 줄을 지우고 audit §2 를 다시 지은 뒤 `reviewing-brief` 의 `## 냉독` 만 돌린 뒤, B-A 의 구조 게이트 펜스를 다시 돌려 그 `advisories` 로 끝 질문 앞 글을 다시 쓰고 끝 질문으로 돌아간다.
  리뷰 라운드를 다시 돌지 않고 재리뷰 상한을 쓰지 않는다.
- **나눈 일이라 게이트가 막았을 때** — 건너뛴 리뷰 부품을 모두 돌린다. 리뷰 부품의 줄(재비판 · codex · 읽어 보기)을 전부 지우고 audit §2 를
  다시 지은 뒤 리뷰 한 라운드를 돌고, 읽어 보기도 건너뛰었으면 그 라운드 뒤에 돌린다. 줄 하나만 지우면 남은 줄 때문에 진입 게이트가 다시 막는다.
  조사 줄이 남아 있으면 위 조사 갈래가 먼저다. 리뷰 라운드와 읽어 보기까지 돈 뒤 Step B 를 B-0 부터 다시 돈다(B-A 의 다시 짓기 · 게이트 포함).
- **재리뷰 상한이 차 있으면** — 그 라운드는 `reviewing-brief` 의 `## 게이트` 가 정한 「추가 라운드 1회 열기」 질문의 답으로만 연다(끝 질문의 기타 칸에
  적은 말을 그 승인으로 쓰지 않는다). 이 질문은 B-A 가 표지를 푼 뒤라 질문 재료 펜스를 돌리지 않고, 앞서 받은 「상태」 · 「전문」 줄과 게이트 글(`gate --render`)로 짠다. 사용자가 열지 않으면 지운 줄을 대기 줄 블록에 그대로 되돌리고 audit §2 를 다시 지은 뒤 끝 질문으로
  돌아간다 — 건너뛴 것이 그대로 보인다. 나눈 일이면 끝 질문으로 가지 못한다 — 줄을 되돌린 뒤
  `[spec-distill] 나눈 일은 건너뛴 리뷰 부품을 돌려야 끝낼 수 있다 — 추가 라운드를 열거나, 나누지 않기로 하면 그렇게 말해 달라.` 를 보이고 턴을 끝낸다.
- 어느 쪽이든 brief 가 바뀌면 리뷰를 다시 지난다 — 바뀐 brief 가 리뷰 없이 끝 질문에 닿지 않는다.

#### B-1 — superpowers 가용성 분기

- **superpowers 부재 시**: 다음 단계로 넘길 대상이 없어 B-2 의 proceed 게이트 대신 **선택지 셋의 따로 된 끝 질문**을 띄운다 — 공통 계약(`proceed-gate.md` Step B)의 질문이 아니다. crash·spec-mode fallback **금지**.
  질문 앞에 B-0 의 확정 후보와 B-2 의 게이트 앞 글 목록(리뷰 게이트 결과 · 읽어 보기 · 남은 항목 · 경고 · 건너뛴 것)을 같은 순서 · 같은 규칙으로 보인다. 질문의 상태 줄도 B-2 와 같은 꼴이다 — 경고 줄과 「전문」 줄은 B-2 의 본문 규칙대로 싣는다.

  ```javascript
  AskUserQuestion({
    questions: [{
      question: "context brief 를 만들었다: <brief-path> (구조 검사 통과 · 리뷰 <게이트 결과 한 줄>). <경고 줄 — 채널마다의 짧은 줄을 「 · 」로 이은 것 | 경고 없음 | 이상 없음>. 전문: <경로>. superpowers 가 없어 다음 단계로 넘기지 않는다. 어떻게 끝낼까?",
      header: "끝내기",
      options: [
        {label: "확정하고 끝낸다 (권장)", description: "얻음: 확정을 저장하고 커밋해 brief 를 다음 작업의 입력으로 남긴다 · 내줌: 확정 후보에 안 고친 잘못이 있으면 확정으로 굳은 채 커밋된다"},
        {label: "확정 목록 수정", description: "얻음: 끝내기 전에 확정 후보와 공시를 고친다 · 내줌: 아직 아무것도 확정되지 않고 고친 뒤 이 질문을 다시 거친다"},
        {label: "brief만 종료", description: "얻음: 아무것도 확정하지 않고 brief 를 여기서 끝낸다 · 내줌: 모든 항목이 잠정으로 남는다"}
      ],
      multiSelect: false
    }]
  })
  ```

  끝 질문의 답은 라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다. 「확정하고 끝낸다」 는 PR 을 열지 않는다. 「확정 목록 수정」 은 두 번 고친 뒤에는 계속할지 묻는다(B-0 의 재제시 상한).
  - **확정하고 끝낸다** — B-3 의 확정 반영 절차 → `check_brief.py gate` 재실행(통과 확인) → 나눈 일이면 Step A 8 의 위험 번호 검사 → 커밋 펜스(`context-commit`) → 여기서 멈춘다. 하나짜리 일은 끝에 `[spec-distill] superpowers 가 없어 다음 단계를 열지 못했다 — 설치한 뒤 새 세션에서 아래 줄로 잇는다.` 와 brief 줄(자리표 치환 규칙은 B-3 그대로)을 보인다. 나눈 일은 B-3 의 「로드맵 잡기 줄 — 나눈 일」 대로 끝낸다.
  - **확정 목록 수정** — B-3 의 ③ 과 같다. 고친 뒤에는 B-2 가 아니라 이 끝 질문을 다시 띄운다(재제시 상한 질문의 「지금 목록으로 확정」 도 이 끝 질문으로 돌아온다).
  - **brief만 종료** — B-3 의 ④ 와 같다.
  - 기타 칸에 「여기서 계속」 이 적히면 하나짜리 일은 `[spec-distill] superpowers 가 없어 이어 갈 다음 단계가 없다.` 한 줄을 보이고 같은 질문을 다시 띄운다. 나눈 일은 「확정하고 끝낸다」 의 절차를 커밋 펜스까지(Step A 8 포함) 돈 뒤 B-3 의 「로드맵 잡기 줄 — 나눈 일」 문단을 그대로 따른다. 건너뛴 것을 하라는 말이면 B-S 로 간다.

- **superpowers 가용 시**: B-2 proceed 게이트 제시.

#### B-2 — 단일 `AskUserQuestion` proceed 게이트 (선택지 넷)

게이트 *이전*에 brief 경로 존재를 확인합니다(`[[ -f <brief-path> ]]` — `AskUserQuestion` 게이트 자체는 아님). 부재 시 정본(`proceed-gate.md`)의 `## Step A` 대로
두 줄 명령을 노출하지 *않고* loud advisory 후 STOP:

> `[spec-distill] brief '<brief-path>' 부재 — 재작성/세션 리셋 필요`

brief 유효 시 **한 번의** `AskUserQuestion`으로 다음 단계를 제안합니다:

게이트를 띄우기 *전에* Step A.5 리뷰 산출물을 프로즈로 출력합니다(B-0 확정 후보 목록 다음):

1. **리뷰 게이트 결과** — 엔진의 마지막 게이트의 첫 줄을 뺀 렌더(첫 줄은 목록 4 에 쓴다) · 승인 게이트 도달 사유(열린 것 없음 · 상한 · stagnation · 「미검증」) · 리뷰 완료 여부 · 1단계에서의 사용자 선택. 방향(direction)은 라운드 게이트에서 물었고, overdesign(참고 축)은 라운드 게이트에 오지 않았습니다 — B-A 가 낸 것을 싣습니다: 참고 목록과 §3 · §5 박제 결과, 또는 B-A 의 부재 · 실패 공시(`[spec-distill]` 줄).
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
   엔진의 재비판 경고 줄(「재비판이 돌지 않아 …」)은 괄호에 `kill switch` 라고 적혀 나온다 — `재비판` 건너뜀 줄이 있는 라운드면
   그 줄 끝에 「— 끄기 스위치가 아니라 모델 판단으로 건너뛰었다」 를 덧붙인다(엔진의 글자는 고치지 않는다).
5. **건너뛴 것 <N>개** — `check_brief.py gate` 의 `advisories` 가운데 `건너뜀 — ` 으로 시작하는 줄을 `- <자리>: <이유>` 로 한 줄씩 쓴다.
   이 줄들은 경고(목록 4)에 다시 쓰지 않되 질문의 경고 줄에는 「건너뛴 것 <N>개」 짧은 줄로 잇는다 — 건너뛴 것이 있으면 「이상 없음」 · 「경고 없음」 을 쓰지 않는다.
   재비판 · codex 를 건너뛴 라운드는 엔진이 그 부품이 돌지 않았다는 경고를 따로 낸다 — 그 경고는 목록 4 에 그대로 두고, 여기의 그 줄 끝에
   「(경고에도 있다)」 를 붙인다. 질문의 경고 줄에서 엔진의 「상태」 줄과 이 짧은 줄이 같은 부품을 함께 말해도 개수를 더하지 않으므로 두 번 세지 않는다. 항목 끝에 「하게 하려면 기타 칸에 적는다」 한 줄을 싣는다. 0개면 이 항목을 쓰지 않는다.

**이 skill 의 degrade 채널**:
`reviewing-brief` 의 `## degrade 채널` 다섯 — 엔진의 `fin.json` `advisory[]`·`blocks`·`gate --render` 첫 줄 +
state 의 `brief_review_degradations` 원장(BRIEF_REVIEW skip record 포함)·두 번째 채널 파일 — 과 웹 한 줄.
`advisory[]` 원문은 하나하나가 `gate --render` 첫 줄의 경고 줄 중 하나에 대응하므로, 경고(목록 4)에는 그 첫 줄의
경고 줄을 그대로 쓰고 `advisory[]` 원문을 다시 늘어놓지 않습니다. 질문의 경고 줄은 엔진의 상태 줄과 다른 채널의 짧은 줄을 이은 것이다 — 개수를 더하지 않는다.
렌더 첫 줄의 끝 문구(이상 없음 · 경고 없음 · 경고 K개)는 문서 리뷰 엔진 몫의 결론이다. 다른 채널에 경고가 있으면 첫 줄 아래에 그 줄들을 따로 쓴다.
질문의 경고 줄에 잇는 짧은 줄은 채널마다 이렇게 얻는다 — 엔진은 `reviewing-brief` 가 Step B 로 돌아가기 직전에 돈 질문 재료 펜스(B-A 가 표지를 풀기 전의 마지막 출력)의 「상태」 줄, brief 경고 원장과 두 번째 채널 파일은 `brief_review_state.py short "$STATE" --fallback-file "$DEGRADE_FALLBACK_FILE"` 이 낸 줄(`$STATE` · `$DEGRADE_FALLBACK_FILE` 은 `reviewing-brief` 의 상태 블록이 정한 값), 구조 검사의 참고 줄(`check_brief.py gate` 의 `advisories` — `건너뜀 — ` 으로 시작하는 줄은 빼고)은 「구조 검사 참고 N개」, 그 `건너뜀 — ` 줄은 「건너뛴 것 N개」(목록 5)다. 「알 수 없음」 줄은 경고 수에 넣지 않고 지금처럼 따로 싣는다. 스크립트가 낸 줄은 글자를 바꾸지 않는다.
「이상 없음」·「경고 없음」은 **그 채널들을 실제로 읽었다는 주장**이므로, 조회하지 않은 채 쓰지 않습니다.

모든 degrade record 는 **게이트 앞 글**(위 목록 4)에 한 줄씩 씁니다. 질문 본문에는 결정 하나와 경고 줄 · 「전문」 줄을 정본(`proceed-gate.md`)의 본문 규칙대로 싣습니다. 「전문」 줄은 그 마지막 질문 재료 출력의 「전문:」 줄 그대로입니다 — B-A 참고 목록 펜스의 머리 줄 안의 글이 아닙니다. B-A 가 표지를 푼 뒤에는 질문 재료 펜스를 돌리지 않고 그 때문에 원장 열기를 다시 돌리지도 않습니다 — 앞서 받은 두 줄을 씁니다. 리뷰가 돌지 않았으면(skip · 예외 경로) 「전문」 줄은 없습니다.

`check_brief.py gate` 의 `advisories` 도 게이트 앞 글(목록 4)에 씁니다 — `coverage-mapper 0
(unavailable: …)` 도 같은 자리로 옵니다. 사용자 판단 포화(판정자의 «포화» 없이 사용자가 끝냈다)도 같은 자리로 옵니다. 조사 축의 advisory 둘도 같은 자리로 옵니다:

- **`내부 조사 0건`** — 이 brief 가 레포 주장(`RC<n>`)을 하나도 싣지 않았다. 게이트는 「조사를
  했어야 했는가」를 알 수 없다(이 스크립트는 brief 파일만 읽는다) — 그 판단이 여기서 사람에게 간다.
- **`신 계약 미적용 brief`** — payload frontmatter 에 `contract: v2` 가 없어 조사 축의 술어 다섯이
  전부 미발동이다.

```javascript
AskUserQuestion({
  questions: [{
    question: "context brief 를 만들었다: <brief-path> (구조 검사 통과 · 리뷰 <게이트 결과 한 줄 — 왜 여기서 멈췄는지 · 남은 항목 수 · 리뷰를 마치지 못했으면 그 사유(unreviewed_reason)>). <경고 줄 — 채널마다의 짧은 줄을 「 · 」로 이은 것 | 경고 없음 | 이상 없음>. 전문: <경로>. 다음 단계는?",
    header: "다음 단계",
    options: [
      {label: "확정하고 /compact 후 brainstorming (권장)", description: "얻음: 확정을 저장하고 맥락을 비워 brainstorming 을 넓게 시작한다 · 내줌: 이 대화의 세부는 요약과 brief 에 적힌 것만 넘어간다"},
      {label: "확정하고 /new 후 brainstorming", description: "얻음: 확정을 저장하고 빈 맥락에서 brainstorming 을 시작한다 · 내줌: 요약도 없어 brief 에 없는 맥락은 사라진다"},
      {label: "확정 목록 수정", description: "얻음: 넘기기 전에 확정 후보와 공시를 고친다 · 내줌: 아직 아무것도 확정되지 않아 다음 단계가 늦어진다"},
      {label: "brief만 종료", description: "얻음: brief 를 여기서 끝내고 아무것도 확정하지 않는다 · 내줌: 모든 항목이 잠정으로 남고 다시 불러야 다음 단계가 이어진다"}
    ],
    multiSelect: false
  }]
})
```

**기타 칸 — 건너뛴 것을 하라는 말.** 사용자가 기타 칸에 건너뛴 것을 하라고 적으면 B-S 로 간다. 그 말이 「여기서 계속」 인지 건너뛴 것을 하라는 것인지 불분명하면 다시 묻는다.

**①② 이름 — 일의 모양에 따라.** 위 호출은 하나짜리 brief 에 둘째 질문이 없을 때의 모양이다. 선택지 넷의 개수 · 순서 · `(권장)` 은 어느 경우든 그대로이고 ①② 의 이름과 설명만 다음 단계에 맞춘다:

| 일 | ① | ② | 설명이 말하는 다음 단계 |
|---|---|---|---|
| 하나짜리 brief · 둘째 질문 없음 | 확정하고 /compact 후 brainstorming (권장) | 확정하고 /new 후 brainstorming | brainstorming |
| 하나짜리 brief · 둘째 질문 있음 | 확정하고 /compact 후 다음 단계로 (권장) | 확정하고 /new 후 다음 단계로 | 둘째 질문에서 고른 단계 |
| 분해된 일 | 확정하고 /compact 후 로드맵 잡기로 (권장) | 확정하고 /new 후 로드맵 잡기로 | 로드맵 잡기 — 결과물을 읽어 에픽 표를 짜고 로드맵을 만든다 |

위 호출의 ①② 설명이 말하는 「brainstorming」은 표의 마지막 칸에 적은 다음 단계로 바꿔 쓴다(둘째 질문 있음이면 「다음 단계」). 분해된 일의 ①② 설명은 고르면 묻지 않고 도는 일까지 적는다 — ① 은 「얻음: 확정을 커밋하고 맥락을 비운 채 로드맵 잡기를 시작한다 · 내줌: 이 대화의 세부는 요약과 brief 에 적힌 것만 넘어간다」, ② 는 「얻음: 확정을 커밋하고 빈 맥락에서 로드맵 잡기를 시작한다 · 내줌: 요약도 없어 brief 에 없는 맥락은 사라진다」다. 이어서 보여 주는 두 줄은 ① 이 `/compact` 와 로드맵 잡기 줄, ② 는 첫 줄만 `/new` 다.

**둘째 질문 — 다른 다음 단계.** 하나짜리 brief 의 일이 brainstorming 보다 다른 다음 단계에 맞으면(예: 조사만 하는 일) 그 제안을 `${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 의 「둘째 질문(선택)」 대로 같은 호출에 더한다 — 선택지는 「<모델의 제안> (권장)」 · 「brainstorming」이고, 제안 선택지의 설명은 「얻음: <제안 이유> · 내줌: <그 제안이 틀렸을 때 원인이 될 것 하나>」로 쓴다. 「brainstorming」의 설명은 「얻음: 기본 흐름대로 설계부터 정리한다 · 내줌: 조사만으로 끝날 일이면 설계 절차를 거쳐 빙 돌게 된다」다. 제안이 없으면 둘째 질문도 없다. 분해된 일에는 둘째 질문을 두지 않는다 — 에픽마다의 흐름은 지휘자가 로드맵 `흐름:` 칸으로 정한다.

#### B-3 — 응답 처리

**규약의 거처.** `superpowers:brainstorming`은 spec-distill을 모르고 brief frontmatter를
읽지 않습니다 — 전달은 순수 프로즈 경로입니다. 그래서 재결정 규약은 brief 파일이
아니라 **다음 세션 줄**(brainstorming 을 부르는 호출 프롬프트)이 가리키는 지시 파일(`${CLAUDE_PLUGIN_ROOT}/references/brief-handoff.md`)에 싣습니다. brief는 순수 데이터(`source`/`status`/
`evidence`)만 나릅니다. ①과 ② 는 같은 줄을 씁니다.

**확정 반영 절차 (①/② 공통).** `provisional` → `confirmed` 전이와 함께, Step A가 confirmed
0건일 때 넣었던 sentinel 한 줄(`# confirmed 0건 — 사용자가 전부 잠정으로 판단`)이 남아 있으면
**같은 write에서 삭제**합니다. `check_brief.py`는 이 잔존을 잡지 못합니다 — confirmed가 한 건이라도
있으면 sentinel *요구*가 해제될 뿐 잔존을 거부하지는 않아, 지우지 않으면 confirmed 항목 옆에
"전부 잠정"이라 적힌 자기모순 brief가 그대로 나갑니다. 삭제까지 마친 뒤 재저장 → 게이트 재실행.

**다음 세션 줄 — ①/② 공통**

> `@<brief-path> 이 context brief 로 Skill superpowers:brainstorming 을 시작하라. 시작하기 전에 ${CLAUDE_PLUGIN_ROOT}/references/brief-handoff.md 의 ## brainstorming 지시 절을 읽고 그 지시를 따른다 — 그 파일의 플러그인 루트 변수는 ${CLAUDE_PLUGIN_ROOT} 로 읽는다. 읽지 못하면 추측하지 말고 멈춰 보고한다.`

줄 앞의 `@<brief-path>` 는 Step A.5 의 `PAYLOAD` 값, 곧 brief 의 절대경로로 치환한 뒤 노출한다. 줄 안의 `${CLAUDE_PLUGIN_ROOT}` 는 이 플러그인의 절대경로로 바꿔 노출한다 — 이 파일에서는 그 변수가 치환되지 않은 채 읽히고, 새 세션에는 그 변수가 없다. 치환하지 않은
자리표가 남거나 경로에 공백이 있으면 노출하지 않고 `[spec-distill] 다음 세션 줄을 만들 수 없다 — <사유>. brief: <PAYLOAD 값>. 새 세션에서 이 brief 를 직접 첨부하고 아래 문장을 그대로 붙여 넣어 brainstorming 을 시작하라.`
한 줄과, 그 아래에 다음 세션 줄에서 `@` 토큰을 뗀 나머지 문장을 그대로 보인 뒤 멈춘다(정본 `## 다음 세션 명령` 규칙 5).

**다른 다음 단계의 줄 — 둘째 질문에서 제안을 골랐을 때.** ①/② 의 둘째 줄은 위 brief 줄 대신 정본 `## 다음 세션 명령` 규칙 3 대로 고른 skill 의 모양으로 짓고 `@<brief-path>` 를 원소로 삼는다. 줄에는 공통 지시를 글자로 싣지 않고 이 문장을 싣는다 — 「시작하기 전에 ${CLAUDE_PLUGIN_ROOT}/references/brief-handoff.md 의 ## 공통 지시 절을 읽고 그 지시를 따른다 — 그 파일의 플러그인 루트 변수는 ${CLAUDE_PLUGIN_ROOT} 로 읽는다. 읽지 못하면 추측하지 말고 멈춰 보고한다.」 자리표 치환 · 거부 · 위치 공시는 위 brief 줄과 같다. 이 줄은 표지 블록 밖이라 인용 줄로 두지 않는다. 확정 반영 write 에서 brief frontmatter `next_phase:` 를 고른 skill 의 완전명으로 바꾼다.

**이름이 바뀌어도 절차는 같다.** 아래 ①② 는 B-2 이름 표의 어느 이름으로 골랐든 같은 절차이고 둘째 줄만 다르다 — 분해된 일이면 아래 「로드맵 잡기 줄 — 나눈 일」, 둘째 질문에서 제안을 골랐으면 위 「다른 다음 단계의 줄」, 그 밖에는 위 brief 줄이다. 「같은 턴에서 호출하지 말 것」은 그 줄이 부르는 skill(로드맵 잡기 · 고른 skill) 모두에 선다.

- **① 확정하고 /compact 후 brainstorming**: 확정 후보를 `status: confirmed`로 반영 → brief 재저장 →
  `check_brief.py gate` 재실행(통과 확인) → 분해된 일이면 Step A 8 의 위험 번호 검사 → 아래 커밋 펜스(`context-commit` — 세 파일) → 두 줄을 *그대로 보이게* 노출한다. 첫 줄은 맨 `/compact`
  (뒤에 아무것도 붙이지 않는다 — 붙인 텍스트는 요약 지시로만 쓰인다), 둘째 줄은 위 다음 세션 줄이다(분해된 일이면 아래 「로드맵 잡기 줄 — 나눈 일」).
  두 줄을 따로 입력하라는 안내와 git 작업 트리 루트의 절대경로를 함께 낸다(정본
  `## 다음 세션 명령` 규칙 1 · 7).
  → **여기서 턴 종료(STOP). 같은 턴에서 `brainstorming`을 호출하지 말 것.** brainstorming 진입은
  사용자가 두 줄을 실제로 입력한 **다음 턴**에 **사용자 트리거**로만 일어난다 — 모델은 자동 진입하지
  *않고* 신호를 기다리며, 사용자가 redirect하면 미진입(P17).

- **② 확정하고 /new 후 brainstorming**: ① 과 같은 절차로 두 줄을 노출하되 첫 줄이 `/new` 다
  (뒤에 아무것도 붙이지 않는다 — 붙인 텍스트는 세션 이름이 된다). 둘째 줄은 위 다음 세션 줄이다.
  → **여기서 턴 종료(STOP). 같은 턴에서 `brainstorming`을 호출하지 말 것.** 진입은 사용자가 두 줄을
  실제로 입력한 **다음 턴**에 **사용자 트리거**로만 일어난다(P17).

- **③ 확정 목록 수정**: 확정 전이 없음. `confirm_repost_count` +1 후 B-0 으로 돌아가 수정된
  목록을 재제시(2회에 닿으면 B-0 의 재제시 상한 질문). 이미 확정된 목록에서 ③ 을 골랐다면 확정된 목록을
  고치는 것이다 — `status` 는 이 편집으로 바뀌지 않고 게이트(①/②)나 B-1 끝 질문의 「확정하고 끝낸다」 를 통해서만 바뀐다.

- **④ brief만 종료**: 전 항목 `provisional` 유지. (나눈 일이면 Step A 8 의 위험 번호 검사 뒤) 아래 커밋 펜스(`context-commit`)를 돌리고, 결과물 경로와 확정하지 않고 끝냈다는 한 줄을 보인 뒤 끝낸다. 설계(brainstorming)로 넘기지 않는다 — 나눈 일이면 그 한 줄 뒤에 아래 「로드맵 잡기 줄 — 나눈 일」 을 낸다.

**끝내기 커밋 — ①/② 는 게이트 재실행 통과 · 나눈 일이면 위험 번호 검사 통과 뒤 두 줄 노출 전, B-1 끝 질문의 「확정하고 끝낸다」 는 확정 반영 · 게이트 재실행 통과 · 나눈 일이면 위험 번호 검사 통과 뒤 끝 안내 전, ④ 와 B-1 의 「brief만 종료」 는 (나눈 일이면 위험 번호 검사 통과 뒤) 종료 안내 직전, 한 번.** ③ 은 커밋하지 않는다.
게이트 재실행이 통과하지 않으면 커밋하지 않는다. 나눈 일의 위험 번호 검사(Step A 8)가 `brief-risk: OK` 를 내지 않아도 커밋하지 않는다 — 그 자리에서 고친 뒤 게이트와 검사를 다시 돈다. 펜스의 `BRIEF` 자리표를 Step A.5 의 PAYLOAD 절대경로로 바꿔 돌리고,
나온 `[spec-distill]` 줄을 그대로 보인다. 펜스는 brief 가 사는 레포(`top`)를 기준으로 돌고 해결자 `repo_defaults.py` 를 모두 `--root "$top"` 으로 부른다.
넣는 것은 brief · audit · 상태 파일 셋(과 아래 framing 기록 · seed)뿐이다 — 나눈 일이어도 로드맵 폴더는 넣지 않는다(로드맵은 로드맵 잡기가 만들어 커밋한다).
brief 가 레포 설정의 의도 폴더(`intent_dir` — 옛 꼴 파일은 옛 의도 폴더) 바로 아래가 아니거나, 세 파일 중 작업 트리 밖이거나 링크를 거치는 경로가 있거나, 같은 커밋에 넣을 framing 기록 · seed 가 같은 규칙의 의도 폴더 바로 아래가 아니거나 작업 트리 밖이거나 링크를 거치면 커밋하지 않는다.
기본 브랜치는 `default-branch --check-remote` 로 얻는다 — 기본 브랜치가 없거나 원격과 다르면 커밋하지 않고, 원격과 대조하지 못하면 그 알림을 보이고 커밋한다. 어느 갈래도 진행은 막지 않는다.
원자료를 찾은 컨텍스트 쌓기에서 framing 기록 파일이나 seed 파일에 가렸는지와 상관없이 커밋되지 않은 변경(커밋된 적 없는 파일 포함)이 있으면 같은 커밋에 넣고 그 사실을 한 줄로 알린다. 펜스는 이 둘을 첫 거절보다 앞에서 알아 두므로, 커밋하지 않는 어느 갈래(git 저장소가 아님은 뺀다)의 손으로 커밋할 목록에도 알 수 있는 만큼 그 둘이 든다. seed 경로는 상태 파일의 `seed:` 값이다.

<!-- context-commit:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
BRIEF="<Step A.5 의 PAYLOAD 절대경로>"
case "$BRIEF" in ""|*"<"*) echo "[spec-distill] 커밋 입력 부재 — BRIEF 가 비었거나 자리표 그대로다(Step A.5 의 PAYLOAD 절대경로로 바꿔 다시 돌려라)."; exit 0 ;; esac
# cwd 접두만 물리 경로로 바꾼다 — 그 아래 성분(링크 포함)은 path-inside 가 잰다.
cwd_l="$(pwd -L)"
case "$BRIEF" in "$cwd_l"/*) BRIEF="$(pwd -P)/${BRIEF#"$cwd_l"/}" ;; esac
stem="${BRIEF%.md}"
AUDIT_F="${stem}.audit.md"
STATE_F="${stem}.state.md"
FILES="${BRIEF} · ${AUDIT_F} · ${STATE_F}"
top="$(git -C "$(dirname -- "$BRIEF")" rev-parse --show-toplevel 2>/dev/null)" || top=""
[ -n "$top" ] || { echo "[spec-distill] 커밋하지 않았다 — git 저장소가 아니다. 파일은 docs 에 있다: ${FILES}"; exit 0; }
# 원자료를 찾은 컨텍스트 쌓기의 framing 기록 파일 · seed 파일 — 첫 거절보다 앞에서 알아 둔다(거절 갈래의 손 목록에도 들어간다). 가렸는지와 상관없이 커밋되지 않은 변경(커밋된 적 없는 파일 포함)이 있는 것만 넣는다. seed 경로는 상태 파일의 seed 값(레포 상대)이고 기록 경로에서 짓지 않는다.
RAW_A=""
RAW_S=""
rv="$(python3 "$SD/scripts/raw_source.py" locate --interview "$BRIEF" --absolute 2>/dev/null)" || rv=""
case "$rv" in "raw-source: FOUND "*)
  RAW_A="${rv#raw-source: FOUND }"
  sv="$(awk 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} /^seed:/{sub(/^seed:[ \t]*/,""); print; exit}' "$STATE_F" 2>/dev/null | tr -d "\"'")" || sv=""
  case "$sv" in ""|"없음") ;; *) RAW_S="${top}/${sv}" ;; esac ;;
esac
[ -z "$RAW_A" ] || [ -n "$(git -C "$top" status --porcelain -- "$RAW_A" 2>/dev/null)" ] || RAW_A=""
[ -z "$RAW_S" ] || [ -n "$(git -C "$top" status --porcelain -- "$RAW_S" 2>/dev/null)" ] || RAW_S=""
FILES="${FILES}${RAW_A:+ · ${RAW_A}}${RAW_S:+ · ${RAW_S}}"
echo "[spec-distill] 읽은 트리: 이 작업공간"
python3 "$SD/scripts/repo_defaults.py" check-path intent_dir "$BRIEF" --root "$top" || { echo "[spec-distill] 커밋하지 않았다 — brief 가 정해진 의도 폴더(옛 꼴 파일은 옛 의도 폴더) 바로 아래가 아니다(위 사유). 확인한 뒤 직접 커밋하라: ${FILES}"; exit 0; }
python3 "$SD/scripts/state_path.py" path-inside --root "$top" "$BRIEF" "$AUDIT_F" "$STATE_F" || { echo "[spec-distill] 커밋하지 않았다 — 세 파일 중 작업 트리 밖이거나 링크를 거치는 경로가 있다(위 사유). 확인한 뒤 직접 커밋하라: ${FILES}"; exit 0; }
if [ -n "${RAW_A}${RAW_S}" ]; then
  [ -z "$RAW_A" ] || python3 "$SD/scripts/repo_defaults.py" check-path intent_dir "$RAW_A" --root "$top" || { echo "[spec-distill] 커밋하지 않았다 — framing 기록 파일이 정해진 의도 폴더(옛 꼴 파일은 옛 의도 폴더) 바로 아래가 아니다(위 사유). 확인한 뒤 직접 커밋하라: ${FILES}"; exit 0; }
  [ -z "$RAW_S" ] || python3 "$SD/scripts/repo_defaults.py" check-path intent_dir "$RAW_S" --root "$top" || { echo "[spec-distill] 커밋하지 않았다 — seed 파일이 정해진 의도 폴더(옛 꼴 파일은 옛 의도 폴더) 바로 아래가 아니다(위 사유). 확인한 뒤 직접 커밋하라: ${FILES}"; exit 0; }
  python3 "$SD/scripts/state_path.py" path-inside --root "$top" ${RAW_A:+"$RAW_A"} ${RAW_S:+"$RAW_S"} || { echo "[spec-distill] 커밋하지 않았다 — framing 기록 파일이나 seed 파일이 작업 트리 밖이거나 링크를 거친다(위 사유). 확인한 뒤 직접 커밋하라: ${FILES}"; exit 0; }
fi
d_rc=0
def="$(python3 "$SD/scripts/repo_defaults.py" default-branch --check-remote --root "$top")" || d_rc=$?
[ "$d_rc" -eq 0 ] && [ -n "$def" ] || { echo "[spec-distill] 커밋하지 않았다 — 기본 브랜치를 판정하지 못했다(위 사유). 고친 뒤 다시 돌리거나 직접 커밋하라: ${FILES}"; exit 0; }
cur="$(git -C "$top" branch --show-current 2>/dev/null)" || cur=""
[ -n "$cur" ] || { echo "[spec-distill] 커밋하지 않았다 — 지금 브랜치 위가 아니다(detached HEAD). 브랜치에서 커밋하라: ${FILES}"; exit 0; }
[ "$cur" != "$def" ] || { echo "[spec-distill] 커밋하지 않았다 — 지금 기본 브랜치(${def})에 있다. 브랜치에서 커밋하라: ${FILES}"; exit 0; }
[ -z "${RAW_A}${RAW_S}" ] || echo "[spec-distill] framing 기록 쪽의 커밋되지 않은 변경을 같은 커밋에 넣는다: ${RAW_A}${RAW_A:+${RAW_S:+ · }}${RAW_S}"
c_rc=0
git -C "$top" add -- "$BRIEF" "$AUDIT_F" "$STATE_F" ${RAW_A:+"$RAW_A"} ${RAW_S:+"$RAW_S"} || c_rc=$?
[ "$c_rc" -ne 0 ] || git -C "$top" commit -q --only -m "docs(context): $(basename -- "$stem") brief · audit · 상태 기록" -- "$BRIEF" "$AUDIT_F" "$STATE_F" ${RAW_A:+"$RAW_A"} ${RAW_S:+"$RAW_S"} || c_rc=$?
if [ "$c_rc" -ne 0 ]; then
  echo "[spec-distill] 커밋이 실패했다(rc ${c_rc}) — 파일은 docs 에 있다: ${FILES}"
else
  echo "[spec-distill] brief · audit · 상태 파일을 커밋했다 — $(git -C "$top" rev-parse --short HEAD) (${cur})"
fi
```
<!-- context-commit:end -->

- **재제시 상한 질문의 답** (B-0): 「지금 목록으로 확정」은 확정 반영 절차를 적용한 뒤 왔던 끝 질문(B-2 게이트 — superpowers 가 없어 B-1 의 끝 질문에서 왔으면 그 끝 질문)을 다시 띄우며
  스스로 멈추거나 넘기지 않는다 — 어떻게 끝낼지는 그 질문에서 고른다. 「계속 고친다(2번 더)」는 state 에
  `confirm_repost_count = 0` 을 쓰고 B-0 으로 돌아간다. 「brief 만 종료」는 ④ 를 따른다. 라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다.

**로드맵 잡기 줄 — 나눈 일.** 「나눈다」 로 끝난 일은 끝 질문의 어느 갈래로 끝나든 커밋했으면 로드맵 잡기 줄을 낸다 — 확정하고 넘기는 갈래(①/②) · `brief만 종료`(④ · B-1) · superpowers 가 없는 환경의 「확정하고 끝낸다」. 다음 단계를 여는 것은 사용자다. 커밋 펜스가 「brief · audit · 상태 파일을 커밋했다」 줄을 냈으면 두 줄을 *그대로 보이게* 노출한다 — 첫 줄은 ① 이면 맨 `/compact`, ② 면 맨 `/new`, 그 밖의 갈래는 맨 `/compact`(빈 맥락을 원하면 `/new`)이고, 둘째 줄은 `/spec-distill:roadmap-draft @<결과물 절대경로>` 다. 두 줄을 따로 입력하라는 안내와 git 작업 트리 루트의 절대경로를 함께 낸다.
`<결과물 절대경로>` 는 Step A.5 의 `PAYLOAD` 값으로 치환한다 — 치환하지 못하거나 경로에 공백이 있으면 줄을 노출하지 않고 `[spec-distill] 다음 세션 줄을 만들 수 없다 — <사유>. 결과물: <PAYLOAD 값>. 작업 트리 루트: <루트 절대경로>. 새 세션에서 /spec-distill:roadmap-draft 를 @ 뒤에 이 결과물의 작업 트리 루트 기준 상대경로를 붙여 부른다.` 한 줄과, 그 상대경로에도 공백이 있으면 로드맵 잡기를 부를 수 없다 — 레포 설정의 의도 폴더(`intent_dir`)를 공백 없는 폴더로 바꾸라는 안내를 함께 보인 뒤 멈춘다.
커밋 펜스가 커밋하지 않았으면(「커밋하지 않았다」 · 「커밋이 실패했다」 줄) 손으로 커밋할 파일 목록과 함께 로드맵 잡기 줄을 내고 「커밋한 뒤 입력하라」 고 알린다 — 파일 목록은 그 줄 끝에 펜스가 댄 파일들이고, 로드맵 잡기는 결과물이 커밋돼 있어야 시작한다.
끝 질문의 기타 칸에 「여기서 계속」 이 적혀 이 세션에서 이어 가도 로드맵 잡기는 그 skill 의 읽기부터 한다(대화에 기대지 않는다). 「spec 하나로」 면 위 brief 줄 그대로다.

#### B-4 — 두 가드 (load-bearing)

두 가드의 **전문은 `proceed-gate.md` 의 `## Step C`** 입니다(Step B 머리의 포인터).
여기 남는 것은 이 skill 의 어휘로만 성립하는 두 문장입니다:

- **AP2 polite-stop 금지**: ①/② 선택 후 "brief 완결!"만 narrate 하고 두 줄 명령을 노출하지 않고
  끝내는 것은 **polite stop** — 금지(①/② 의 완료는 B-3 대로 두 줄과 위치를 노출하고 턴을 끝내는 것이다 — 분해된 일이면 둘째 줄이 로드맵 잡기 줄이다). Step B 를 *종료*하는
  모든 경로는 (a) 위 proceed 게이트를 거치거나(①/②/③/④), (b) superpowers 가 없을 때의 B-1 끝 질문
  (선택지 셋)을 거친다 — 질문 없는 **silent 종료 금지**.
- **cross-compact 조기진행 금지**: ①·② 의 정지 요건과 다음 턴 진입 조건은 B-3 ①·② 에 인라인으로
  있습니다. 예외는 없습니다.

이 stage는 brief까지로 종료됩니다. handoff를 *강제하지 않습니다*.
