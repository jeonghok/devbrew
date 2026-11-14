---
type: interview-seed-audit
payload: 2026-11-14-framing-interview-constraint-audit-interview.md
created_at: 2026-11-14
session_id: ee276545-0999-4e89-aeab-9cec39e6c504
source: spec-distill request-framing
---

# framing · interview 문서가 최근 방식에 제약이 되는지 조사 — Interview Seed Audit

> 순수 텔레메트리 — 다음 세션의 첫 턴 `/spec-distill:pm-interview @<seed 경로>` 가 가리키는 것은 payload(seed)
> 파일이고, 여기에는 확산·압축이 어떻게 진행됐는지의 과정 기록만 남는다. payload 의 `audit_file`
> 이 이 파일을 가리킨다.

## 1. 원문

### 첫 요청 (`/spec-distill:request-framing` 인자, 2026-11-14)

Framing request, interview 필로소피 레포내 컨텍스트나 글이 경우 최근 우리 방식에 제약이 되지 않는지 조사부터

### 조사 도중 사용자가 보낸 말 (2026-11-14, 조사 agent 다섯 중 둘이 끝난 시점)

내가 말한거 이외에도 잡아내서 제안해줄 수 있겠지?

### 조사 도중 사용자가 보낸 말 (2026-11-14, 조사 agent 다섯 중 넷이 끝난 시점)

플러그인 저술 가이드도 바꿔야 겠다

### 바로 이어 사용자가 보낸 말 (2026-11-14)

내가 말하는거는 우리 레포에 바이어스 되게 보다 표준에 맞게 가자는거였어

### 바로 이어 사용자가 보낸 말 (2026-11-14)

가능하면 추가보다는 푸는 쪽으로 가고

### 바로 이어 사용자가 보낸 말 (2026-11-14, 조사 agent 다섯이 모두 끝난 시점)

아 이거는 철학이야기야

### 다른 세션이 넘긴 입력 자료 (2026-11-14 — 사용자가 라운드 1 에서 「이번 일에 합침」으로 받음)

지휘 재설계 로드맵(`2026-11-14-conductor-context-economy-brief`)의 리더 세션이 보낸 글 전문이다. 사용자가 이 세션에 직접 친 글이 아니다 — 안의 「」 인용은 그 세션이 옮겨 적은 사용자 말이다. 제목 줄이 이 기록의 절 경계로 읽히지 않게 인용 표시로 감쌌다.

> # 넘김 — 「인터뷰」 → 「의도 싱크」 이름 바꾸기
>
> 보낸 곳: 로드맵 `docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md` 의 리더 세션(devbrew-90). 2026-11-14.
> 이 글은 framing 의 입력 자료다. 지시가 아니다 — 받을지 · 어떻게 다룰지는 사용자와 그 framing 이 정한다.
>
> ## 사용자 원문 (이 로드맵의 R1 설계 대화, 2026-11-14)
>
> - 「폴더명도 바꿀까 그리고 인터뷰라는 명칭도」
> - 「의도 싱크로 바꾸고 따로 에픽으로 두자」
> - 「내 의도가 interview지나면서 의역된거 같아서 그래」
> - 「의도 싱크 이름 바꾸기 에픽을 하는거는 다른 로드맵에 넘길 수 있을까 지금 framing 시작한 클로드 세션 하나 있거든」
>
> 이름의 출처는 사용자가 붙여 넣은 원자료다 — `docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.audit.md` 41행: 「과제가 리더 세션에 들어오면 대장은 바로 시작하지 않음 방향을 나에게 먼저 보여줌(의도 싱크)」.
>
> ## 지금 확인한 사실 (origin/main 8b7ddf4d 기준, 2026-11-14)
>
> - `plugins/` · `shared/` 에서 interview 를 언급하는 파일 369개. 그중 skill 호출 이름 `pm-interview` 87개, 설계문서 머리 키 `source_interview` 24개(상태 계산이 이 키로 설계문서를 에픽에 잇는다), 설정 키 `interview_dir` 21개.
> - `docs/superpowers/interview/` 아래 추적 파일 77개.
> - 레포 규칙(CLAUDE.md 「메타데이터 & 버전 관리」): 호출 이름(slash 명령 · skill 이름)의 변경은 alias 없이 즉시 하고 major bump 한다.
>
> ## 정하지 않은 것
>
> 새 skill 이름 · 설정 키 · 머리 키 · 파일 접미사(`-interview.md`)의 새 이름, 옛 기록(77개)을 옮길지, 범위(request-framing 까지인지).
>
> ## 이쪽 로드맵과 맞물리는 곳
>
> - R1(팀 파일 규약, 브랜치 `feature/team-file-contract`, 설계 중)이 새 구조를 세운다: `roadmaps/<로드맵>/intent/`(원자료 · 의도 싱크 결과) · `jobs/<과제>/INTENT.md`. 새로 생기는 파일에는 처음부터 새 이름을 쓴다. R1 이 예약한 파일: `plugins/spec-distill/scripts/roadmap_write.py` · `roadmap_render.py` · `roadmap_model.py` · `roadmap_status.py` · `check_bundle_coverage.py` · `spec_review_bundle.py` · `references/epic-handoff.md`.
> - R2 가 `plugins/spec-distill/scripts/repo_defaults.py`(설정 키) · `references/conducting.md` · `conductor-dispatch.md` · `skills/epic-conductor/SKILL.md` 를, R5 가 `docs/superpowers/specs/` · `docs/superpowers/roadmaps/` 이전을 예약했다.
> - 열린 PR #274 가 `plugins/spec-distill/skills/pm-interview/references/finishing.md` 를 고친다.
> - 그래서 같은 파일을 두 로드맵이 건드린다 — 머지 순서를 맞춰야 한다. 리더 사이 편지함은 아직 없다(R3 가 만든다). 그때까지는 이 세션(devbrew-90)에 세션 메시지로 알리거나 사용자를 거친다.

### seed 리뷰 도중 사용자가 보낸 말 (2026-11-14, 2라운드의 편집 덩어리 넷을 처분한 직후 · 3라운드 시작 뒤)

이거 덩어리 승인하는과정 내가 보기 어려우니까 개선하자

## 2. 질문 전체

### 라운드 0 (워크트리 — 기록 파일을 쓰기 전)

- 물은 것: `feature/framing-interview-constraint-audit` 워크트리를 만들고 거기서 시작할까요? 이 브랜치 하나에서 인터뷰·설계·계획·구현까지 갑니다. (origin/main 에 없는 커밋 0개) 거절하면 현재 디렉토리에서 진행합니다.
  - 선택지: 만들고 시작 (권장) / 현재 디렉토리에서
  - 당신이 답한 것: 만들고 시작 (권장)

### 라운드 1

- 물은 것: 「아 이거는 철학이야기야」의 「이거」는 무엇을 가리키나요? 바로 앞에 「우리 레포에 바이어스 되게 보다 표준에 맞게 가자」와 「가능하면 추가보다는 푸는 쪽으로」를 말씀하셨습니다.
  - 선택지: 두 말 다 철학 문서 얘기 / 표준 얘기만 철학 문서 / 이 일 전체의 원칙
  - 당신이 답한 것: 두 말 다 철학 문서 얘기
- 물은 것: 맞출 「표준」은 무엇인가요? 여럿을 고를 수 있습니다.
  - 선택지: Claude Code 공식 (권장) / 외부 작업 방식 관례 / 일반 개발 관례
  - 당신이 답한 것: Claude Code 공식 (권장), 참고내용으로 두는거야
- 물은 것: 지휘 재설계 로드맵의 리더 세션이 「인터뷰」 명칭을 「의도 싱크」로 바꾸는 일의 자료를 이 회의에 넘겨 왔습니다. 어떻게 받을까요?
  - 선택지: 별도 에픽 후보로 받음 (권장) / 이번 일에 합침 / 받지 않음
  - 당신이 답한 것: 2, 우리가 하는건 치우침 정리가 아니야 framing과 interview가 우리 새로운 코어와 맞지 않는 부분들이 있으니 그 앞단을 개선, 강화, 낡은 부분 수정 등을 하기 위한거야 옆 세션을 잘 이해해야겠지
- 확인 질문: 조사 도중 보낸 말 넷의 풀이 (질문 없이 보낸 말이라 「내가 물은 것」 자리는 「(묻지 않음 — 조사 도중 보내신 말)」 이었다)
  - 내가 읽은 것: 「이 일이 풀려는 것은 request-framing · 인터뷰 · 철학 · 레포 문서가 표준보다 devbrew 레포에 치우쳐 있다는 것이고, 방향은 표준에 맞추는 것이다.」 — 고름
  - 내가 읽은 것: 「고칠 때는 새 장치나 규칙을 더하기보다 있는 것을 풀거나 걷어내는 쪽을 먼저 고른다.」 — 고름
  - 내가 읽은 것: 「플러그인 저술 가이드도 이 일에서 고칠 대상이다.」 — 고름
  - 내가 읽은 것: 「사용자가 말한 것 밖의 문제도 찾아서 제안으로 올린다.」 — 고름

(첫째 풀이는 같은 호출의 다른 답 둘과 어긋난다 — 「두 말 다 철학 문서 얘기」, 「우리가 하는건 치우침 정리가 아니야」. 이 일의 정의로 쓰지 않고 라운드 2 에서 다시 묻는다.)

### 라운드 2

- 물은 것: 「우리 새로운 코어」는 어디까지를 가리키나요?
  - 선택지: 지휘 재설계의 팀 구조 (권장) / 팀 구조 + qg 의도 리뷰 / 다른 것
  - 당신이 답한 것: 지휘 재설계의 팀 구조 (권장)
- 물은 것: 플러그인 저술 가이드는 어느 방향으로 고칠까요?
  - 선택지: 철학 문서와 같은 방향 / 새 코어에 맞게 / 둘 다
  - 당신이 답한 것: 3, 그리고 plugin-authoring.md 이거도 낡았을거 같은데 확인해보자
- 물은 것: 말씀하신 것 밖에서 제가 잡은 제안 중 이 일의 방향으로 넣을 것을 고르세요. 고르지 않은 것은 seed 에 「다시 검증할 것」으로만 남깁니다.
  - 선택지: 원자료를 정식 산출물로 (권장) / 리더로 넘기고 글은 짧게 (권장) / 앞단 글 줄이기 (권장) / 작은 일의 가벼운 길
  - 당신이 답한 것: 원자료를 정식 산출물로 (권장), 리더로 넘기고 글은 짧게 (권장), 앞단 글 줄이기 (권장), 작은 일의 가벼운 길
- 확인 질문: 라운드 1 답의 풀이
  - 내가 읽은 것: 「이 일의 목적은 request-framing 과 인터뷰가 새 코어와 맞지 않는 부분을 개선하고 강화하고 낡은 부분을 고치는 것이다.」 — 고름
  - 내가 읽은 것: 「인터뷰를 의도 싱크로 바꾸는 이름 바꾸기는 이 일에 합친다.」 — 고름
  - 내가 읽은 것: 「표준에 맞게 가자는 말과 추가보다 푸는 쪽으로 가자는 말은 철학 문서를 두고 한 말이다.」 — 고름
  - 내가 읽은 것: 「Claude Code 공식 자료는 따라야 할 기준이 아니라 참고 내용으로 둔다.」 — 고름

### 라운드 3

- 확인 질문: 라운드 2 답의 풀이 (새 질문 없이 확인만 — 여섯을 셋씩 두 질문으로 나눠 물었다)
  - 내가 읽은 것: 「새 코어는 지휘 재설계 로드맵이 세우는 팀 구조다.」 — 고름
  - 내가 읽은 것: 「플러그인 저술 가이드는 표준에 맞추는 방향과 새 코어에 맞추는 방향을 함께 적용해 고치고, 낡은 내용도 확인해 고친다.」 — 고름
  - 내가 읽은 것: 「붙여 넣은 글과 직접 쓴 말 같은 원자료를 파일로 그대로 두고, 사용자 원문 자리에는 seed 가 아니라 그 원자료가 가게 한다.」 — 고름
  - 내가 읽은 것: 「앞단의 끝은 작은 일도 리더로 넘기고, 넘김 글은 짧게 쓰고 자세한 지시는 파일 경로로 둔다.」 — 고름
  - 내가 읽은 것: 「앞단 skill 글에서 이유와 이력 설명, 낡은 서술, 옛 설계 번호를 걷어내 읽는 양을 줄인다.」 — 고름
  - 내가 읽은 것: 「작은 일에서는 필수 조사와 리뷰 일부를 모델이 이유를 적고 건너뛸 수 있게 한다.」 — 고름

## 3. 긴 초안

경로는 레포 루트 기준이다. `SD/` 는 `plugins/spec-distill/` 를 줄인 것이다. 「직접」은 이 세션이 파일을 열어 확인한 것, 「보고」는 조사 agent 가 보고했고 이 세션이 다시 열어 보지 않은 것이다.

### 가. 이 일이 무엇인가

- 목적: request-framing 과 인터뷰(앞단)가 새 코어와 맞지 않는 부분을 개선 · 강화하고 낡은 부분을 고친다. 치우침 정리가 아니다(라운드 1 답).
- 새 코어: 지휘 재설계 로드맵(`docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/`)이 세우는 팀 구조(라운드 2 답).
- 「인터뷰 → 의도 싱크」 이름 바꾸기를 이 일에 합친다(라운드 1 답 「2,」).
- 철학 문서: 레포에 치우치기보다 표준에 맞게, 더하기보다 푸는 쪽으로(라운드 1 답 「두 말 다 철학 문서 얘기」). Claude Code 공식 자료는 참고 내용이다.
- 플러그인 저술 가이드: 표준 방향과 새 코어 방향을 함께, 낡은 내용도 확인해 고친다(라운드 2 답 「3,」).
- 사용자가 말하지 않은 것도 잡아 제안한다. 제안 넷을 사용자가 방향으로 골랐다(라운드 2): 원자료를 정식 산출물로 · 리더로 넘기고 글은 짧게 · 앞단 글 줄이기 · 작은 일의 가벼운 길.
- 옆 세션(그 로드맵의 리더 세션)을 잘 이해해야 한다(라운드 1 답).

### 나. 새 코어 — 옆 세션에서 읽은 것

출처는 그 세션의 팀 파일 규약 설계문서(로컬 worktree `team-file-contract` 의 `docs/superpowers/specs/2026-11-14-team-file-contract-design.md`, 브랜치 `feature/team-file-contract`, origin 에 없음, spec 리뷰 · 사용자 승인 전)와 그 세션이 보낸 세션 메시지 셋이다. 그 세션은 문서가 정본이고 바뀌면 절 이름과 커밋만 알리겠다고 했다.

- 팀 폴더: `roadmaps/` 를 맨 밖에. 그 아래 `HANDBOOK.md`(팀 간 공유) · 역할 문서(`leader` · `designer` · `writer` · `worker` 의 CLAUDE.md, 팀 간 공통) · 로드맵마다 `roadmap.md` · `RULES.md` · `intent/` · `STATUS.md` · `inbox/` · `jobs/<과제>/`. 레포 맨 위에 `REVIEW.md`.
- 과제 폴더: 에픽이든 단순 작업이든 `INTENT.md` 와 `results/` 가 반드시 있다. INTENT.md 는 목표 · 지시 원문 · 하지 않을 것 · 결정 기록 네 칸.
- 「한 번만 짓는다」: 내용마다 집을 하나로 정하고 나머지는 경로로 가리킨다. 사용자 원자료의 집은 `intent/original.md` 이고 INTENT.md 지시 원문과 설계문서 원문 대조가 줄 범위로 가리킨다. 그 문서가 근거로 적은 사용자 말: 「오늘 brief 문서 구조랑 소통 구조 실패로 인해 드리프트 되는거처럼」.
- `intent/original.md` 는 framing 기록 파일의 원문 절과 질문 전체 절, 인터뷰의 사용자 발화를 글자 그대로 옮긴 한 벌이고 덧붙이기만 한다. 지금은 앞단 기록에서 옮겨 적는 사본이다.
- 그 문서의 미룸 표가 이 일(이름 바꾸기 로드맵)에 넘긴 것: 앞단이 brief · audit 을 `intent/` 에 바로 쓰기 · 설계문서 머리 키 `source_interview` 의 이름.
- 그 문서가 지휘 절차 에픽(R2)에 넘긴 것 중 인터뷰 끝맺음 파일에 닿는 것: 분해 승인 화면에 과제마다 지시 원문 범위의 글을 보이기 · 분해 전에 `original` 부르기 · 새 형식을 기본으로 켜기.
- 용어: 사용자에게 보이는 말은 「리더」. skill 이름 `epic-conductor` 는 그 설계가 바꾸지 않는다.
- 그 세션의 원자료 대조표(그 세션 임시 폴더의 `framing-ledger.md`, 로드맵 폴더에 올릴 예정이나 사용자 승인 전): 프레이밍 원문 243행 중 손실 · 뒤집힘으로 적힌 행 147(이 세션이 그 파일에서 센 값), 묶음에 실린 꼴이 「없음」인 행 43, 어느 에픽 범위도 덮지 않는 행 36. brief 의 기각 · 고르지 않음 줄 18개 중 묶음에 있는 것은 1줄. 이 수치는 그 세션의 측정이다.

### 다. 새 코어와 앞단이 안 맞는 자리 (이 세션의 대조)

1. 원자료가 정식 산출물이 아니다.
   - 인터뷰 결과물의 사용자 원문 첫 칸(S1)은 seed 전문이다 — `SD/skills/pm-interview/references/seed-input.md:9-10`(직접). 실제 사례: `docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md:541` 「S1 🗣 최초 요청(Phase 0 seed 전문)」(직접).
   - seed 문법은 목록 · 표 · 트리 · 펜스 · 대괄호를 받지 않는다 — `SD/scripts/seed_body.py:16-22`(직접). 붙여 넣은 폴더 트리는 문장으로 풀어 써야 한다.
   - 원자료는 seed 기록 파일의 원문 절에만 남고 템플릿은 그 파일을 「순수 텔레메트리」라 부른다 — `SD/templates/interview-seed-audit-template.md:11-13`(직접).
   - 분류기는 사용자가 쓴 문장을 출처 사용자 · 미확인으로, 모델 풀이를 사용자가 고른 것만 확인으로 가른다 — `SD/scripts/seed_provenance.py:257-272`(직접).
   - 실례: 「의도 싱크」는 그 로드맵의 seed 와 brief 에 없고 기록 파일에만 있다(직접, grep). 사용자 말 「1, 낡은 규칙과 철학으로 지래짐작 제약은 안되는거 알지?」가 brief 에서 「…두지 않는다 — 기존 규칙은 고칠 후보로 본다」로 바뀌었다(직접, 같은 brief 59 · 574행).
   - seed 리뷰 기준(`SD/references/docreview-profiles/seed.md`)에 뜻이 바뀐 풀어 쓰기를 잡는 범주가 없고, 덜어 낸 것 표에 한 줄 있으면 빠짐이 아니다(보고).
   - brief 리뷰의 정답 출처가 그 S1 이라 seed 단계의 의역이 원문으로 굳는다(보고 — `brief.md:3`).
2. 넘기는 곳과 넘김 글.
   - 하나짜리 일의 다음 세션 줄은 brainstorming 을 부르는 약 2천 자 한 줄이고, 설계문서 절 넷 · 「기본은 X…」 규칙 · 사용자가 하지 않은 「사용자 선호」가 들어 있다 — `SD/skills/pm-interview/references/finishing.md:551` · `SD/references/epic-handoff.md:7`(직접).
   - superpowers 가 없으면 끝 게이트가 통째로 없다 — `finishing.md:444`(직접, 그 줄만).
   - 분해된 일만 지휘자로 간다(보고 — `finishing.md:534, 668`).
3. 이름과 자리.
   - 이름 바꾸기 규모는 넘겨받은 자료에 있다(원문 절).
   - 산출물 폴더는 `interview_dir`(이 레포 기본 `docs/superpowers/interview/`)이고 새 코어의 `intent/` 가 아니다(직접 — 상태 블록 출력).
4. 맥락 비용.
   - 줄 수(직접, `wc -l`): request-framing SKILL.md 1373 · pm-interview SKILL.md 600 · finishing.md 685. reviewing-brief SKILL.md 742줄(보고).
   - 이유 · 이력 설명 비율 추정(보고): request-framing 펜스 밖 글의 약 5분의 1, pm-interview 쪽 전체의 6–8%, proceed-gate.md 약 35%.
   - 옛 설계 번호 라벨(C4 · C43 · G1 · AC19 · NG4 · §2.4 등)이 살아 있는 번호와 같은 글자로 약 45곳(보고).
5. 뒤집힌 경위가 하류로 안 간다(나. 의 대조표 수치).
6. 낡은 서술.
   - request-framing: 「실측(v6)」 · 「CHANGELOG `[0.57.0]`」 · 「헤드리스 실측(2026-09-10, 옛 interview 명령)」(직접 — skill 본문). 템플릿의 「세션 state 에서 그대로 옮긴다」 · 「`framing_degradations` 원장」은 skill 본문과 어긋난다(보고).
   - pm-interview: `finishing.md:71` 「audit 5-section」 대 템플릿 일곱 절(직접, 그 줄), `decompose_edits` 키가 스키마에 없음, 날짜 없는 「오늘부터」, `v0.24.0` 등(보고).
   - agent · README: `blind-spot-prober.md` 의 절 이름, README 의 「5섹션」 · 「횟수 제한」(보고).
7. 필수 조사 둘(coverage-mapper · blind-spot-prober)과 포화 판정을 모델이 건너뛸 칸이 없다 — `check_brief.py:1576` 은 mapper 0 을 도구 부재 사유로만 받는다(보고).
8. 레포 전용 값.
   - 커밋 메시지 리터럴: `SD/skills/request-framing/SKILL.md:1157` 영어, `finishing.md:640` 한국어(직접).
   - seed 리뷰 번들이 cwd 의 `CLAUDE.md` 리터럴을 받고 없으면 조립이 rc 2 — `SD/scripts/build_seed_inline_blob.py:141-146`(직접, 코드 줄만. 실행 안 함).
   - `SD/references/research-claims.md:38-41` 의 devbrew 아카이브 경로가 조사 agent 프롬프트마다 실린다(보고).
9. 레포 규칙이 정답 자리에 있다.
   - 압축 규약이 CLAUDE.md 에 이미 있으면 뺀다 — `SD/references/compression.md:46`(직접). 그 규칙이 낡았다고 올릴 길은 없다(보고).
   - brief 리뷰 기준이 「이미 리포에 있는 원칙으로 되나」 · 「Law 1·2·3」을 깎는 잣대로 쓴다(보고 — `brief.md:57-74`).

### 라. 철학 문서 · CLAUDE.md

- P8 문장의 정본은 `docs/philosophy/devbrew-harness-philosophy.md:82`, 사본은 `CLAUDE.md` Law 3 블록과 플러그인 여러 곳(보고 — 열 곳 남짓). 옆 로드맵의 지휘 절차 에픽이 두 파일을 P8 개정용으로 예약했다(직접 — 그 로드맵 `roadmap.md:44`).
- 철학 P8 「(흐름)」 줄이 「정석 흐름(brainstorming → 계획 → 구현)」으로 superpowers 를 이름으로 박는다(직접 — 철학 문서 84행).
- 리뷰어 규칙은 더하기가 기본이고 빼기는 보안 리뷰 대상이다 — `CLAUDE.md` 「Persona 파일은 보안-민감 코드」 · 「버그가 리뷰를 탈출하면」(직접).
- 철학 문서의 「코드:」 포인터는 대부분 실재한다. P3 포인터는 정본을 가리키고 실제로 불리는 것은 플러그인 사본이다(보고).
- 「KEEP-12」 머리 아래 엔트리가 13개, P14 「CLAUDE.md 에 부재」가 지금은 부분적으로 틀림(보고, 확신 낮음).
- 2026-10-17 흐름 고정 점검(`docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/flexibility-audit.md`)이 앞단을 짚은 열 가지는 모두 고쳐졌다(보고). 그 점검이 「유지」로 뺀 축은 본 적이 없다.

### 마. 플러그인 저술 가이드 (`docs/plugin-authoring.md`, 58줄 — 전부 직접)

- 22–25행: 예시 `quality-gates:doc-recritic` 는 없다. `plugins/quality-gates/agents/` 는 artifact-adversarial · artifact-critic · code-recritic · security-reviewer.
- 8–20행 트리: `references/` 와 `dependencies.md` 가 없다. 네 플러그인 모두 `dependencies.md` 가 있다.
- 17행: `scripts/` 를 「hook 에서 호출하는 헬퍼」로 적었다. plugin-audit 은 hook 없이 `scripts/` 가 있다.
- 45행: 구현 단계에 `command-development`. CLAUDE.md 는 새 command 파일을 만들지 않는다.
- 22행: `model` 키 금지 근거가 CLI 2.1.261 실측(2026-09-06). 지금도 맞는지 확인하지 않았다.
- 48행: 「devbrew 정책은 이 문서가 유일한 소스이며 충돌 시 우선한다」 — plugin-dev 는 문법으로만.
- 50–56행 「devbrew 를 고칠 때의 규칙」 다섯 줄은 쌓인 교훈이다.
- 새 코어(역할 문서 · `roadmaps/` · 리더)는 반영돼 있지 않다.

### 바. 함께 건드리는 것 · 순서

- `finishing.md`: 이 일 · 옆 로드맵 R2 · 열린 PR(브랜치 `feature/interview-pr-merge` — 분해된 인터뷰가 끝맺음에서 PR 을 열고 머지를 묻는다).
- `repo_defaults.py`(설정 키) · `epic-handoff.md`: 옆 로드맵 R2 · R1 예약.
- `docs/philosophy/` · `CLAUDE.md`: 옆 로드맵 R2 예약.
- 리더 사이 편지함은 아직 없다. 세션 메시지나 사용자를 거친다.
- 이름 바꾸기는 CLAUDE.md 규칙상 별칭 없이 즉시 · major bump 다.

### 사. 유지 근거가 있는 것 (조사 agent 셋이 발견으로 내지 않은 것)

Law 2 의 `tools:` allowlist · kill switch 와 진입 사전 검사 · 리뷰어 입력 격리(냉독에 seed 본문만, 재비판에 판정 이력 없음, `must_catch` 를 리뷰어에게 안 실음) · 사용자 문구를 셸 인자에 직접 쓰지 않기 · 글자 대조 게이트(확인 표시 · `check_verbatim_coverage.py`) · 처분 전 편집 금지와 추천 없는 저자 편집 질문 · 동시 리뷰 표지 · seed 문법의 보이지 않는 글자 · URL · HTML 거부.

### 아. 정하지 않은 것

- 새 이름: skill 호출 이름 · 설정 키 · 설계문서 머리 키 · 파일 접미사, 옛 기록 77개를 옮길지, request-framing 까지 바꿀지.
- 철학 문서 · CLAUDE.md 를 이 일과 옆 로드맵 R2 가 어떻게 나눌지.
- 「작은 일의 가벼운 길」과 「작은 일도 리더를 거친다」가 어떻게 함께 가는지.
- seed 문법을 풀지, seed 자체의 자리를 바꿀지(원자료 파일이 정본이 되면 seed 가 무엇을 하는가).
- 공식 자료와의 대조(하지 않았다).
- 조사에서 나왔으나 사용자에게 묻지 않은 것: 확인 표시가 사용자 원문 문장에 안 붙는 것, 넘김 글의 「사용자 선호」 라벨, 라운드 꼴 고정과 «지금 이해» 한두 문장, steelman 의 추천 봉쇄, 조사 호출 상한 60, plain-language 블록이 사용자 이름에 예외를 두지 않는 것.

### 자. 「최근 방식」의 부딪히는 말 (조사 agent 가 나란히 놓은 것, 판정 없음)

흐름 강제 대 스크립트 순서 · 상한 금지 대 숫자 멈춤 조건 · 이름 그대로 대 이름 바꾸기 · 걷어내기 대 있는 것에 맡기기 · 규칙 쌓는 장치 대 쌓인 규칙 경계 · 메시지 짧게 대 파일로만 보고 대 중간 소식 · 지휘자로 통일 대 작은 일은 가볍게 · compact 대 새 세션 · 모델이 알아서 대 모델 혼자 결정 안 함. 문맥은 조사 보고에 있고 이 기록에는 싣지 않았다(보고 전문은 이 세션 대화에만 있다).

### 재결정 (P23)

| 원래 | 재결정 | 근거 |
|---|---|---|
| 라운드 1 풀이 「이 일이 풀려는 것은 … 표준보다 devbrew 레포에 치우쳐 있다는 것이고, 방향은 표준에 맞추는 것이다.」(고름) | 이 일의 목적은 앞단이 새 코어와 맞지 않는 부분을 개선 · 강화 · 낡은 부분 수정하는 것이고, 표준 얘기는 철학 문서에 한정 | 같은 호출의 사용자 답 「우리가 하는건 치우침 정리가 아니야 …」 · 「두 말 다 철학 문서 얘기」, 라운드 2 확인 |
| 라운드 1 풀이 「고칠 때는 새 장치나 규칙을 더하기보다 있는 것을 풀거나 걷어내는 쪽을 먼저 고른다.」(고름) | 「푸는 쪽」은 철학 문서를 두고 한 말 | 사용자 답 「두 말 다 철학 문서 얘기」, 라운드 2 확인 |

### 이름 조회

없음

## seed 에서 덜어 낸 것

| 항목 | 기준 | 원문 위치 | 되살림 |
|---|---|---|---|
| 조사에서 찾은 자리 전체(파일 · 줄 번호 목록) | 읽으면 아는 것 · 과정 | `## 3` 다 · 라 · 마 | |
| 새 코어의 폴더 구조 세부(역할 문서 넷 · RULES.md · HANDBOOK.md · REVIEW.md · STATUS.md · inbox) | 읽으면 아는 것(옆 세션 설계문서가 정본) | `## 3` 나 | |
| 이름 바꾸기 규모 수치(파일 369 · 호출 이름 87 · 머리 키 24 · 설정 키 21 · 옛 기록 77) | 읽으면 아는 것 | `## 1` 넘겨받은 자료 | |
| 저술 가이드에서 낡은 곳 다섯의 세부 | 하류가 정할 것 · 읽으면 아는 것 | `## 3` 마 | |
| 유지 근거가 있는 것 목록(Law 2 · kill switch · 입력 격리 · 글자 대조 게이트) | 상시 규칙 | `## 3` 사 | |
| 풀이 「플러그인 저술 가이드도 이 일에서 고칠 대상이다.」 | 자명(라운드 3 의 저술 가이드 풀이가 덮는다) | `## 2` 라운드 1 | |
| 풀이 「사용자가 말한 것 밖의 문제도 찾아서 제안으로 올린다.」 가 낳은 제안 중 사용자에게 묻지 않은 여섯 | 하류가 정할 것 | `## 3` 아 | |
| 「최근 방식」의 부딪히는 말 아홉 쌍 | 과정 | `## 3` 자 | |
| 철학 P8 문장의 사본 자리 목록 · 철학 문서의 낡은 서술 후보 | 읽으면 아는 것 | `## 3` 라 | |
| 2026-10-17 흐름 고정 점검의 열 가지가 고쳐졌다는 사실 | 읽으면 아는 것 | `## 3` 라 | |
| 조사 방식(읽기 전용 agent 다섯 · 한 라운드) | 과정 | 이 세션 대화 | |
| 라운드 1 에서 고른 뒤 뒤집힌 풀이 둘 | 재결정으로 대체 | `## 3` 재결정 | |

## 4. 비평과 냉독

### 라운드 1 — 탐지 1 (doc-critic)

> 번들 전문을 읽었다(`/Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/.docreview/2026-11-14-framing-interview-constraint--199af10b31ba2c4c/seed-bundle.md`, 260줄). 층 1 finding 은 7건이고 모두 `fix` 다. 층 2 는 프로필이 비워 두어 `[]` 다.
>
> 「(사용자 확인)」이 붙은 열 문장은 모두 `## 2. 질문 전체` 의 「고름」 풀이와 글자가 같아서, 그 표시 자체에는 finding 이 없다. 아래 7건은 표시가 없는 문장과 빠진 줄에서 나왔다.
>
> ```docreview-layer1
> - ref: c1
>   layer: 1
>   category: unfounded_addition
>   anchor: "#__doc__"
>   disposition: fix
>   summary: >-
>     옆 세션 설계문서가 미뤄 둔 일(앞단이 로드맵 폴더에 바로 쓰게 하기 · 설계문서 머리 키 이름)을
>     「이 일로 넘겨 두었다」고 단정해 이 일의 범위에 넣었는데, 사용자가 받은 것은 이름 바꾸기 자료뿐이다.
>   edit_scope: "#__doc__"
>   evidence: >-
>     초안: 「앞단이 그 폴더에 바로 쓰게 하는 일과 설계문서 머리 키의 이름은 그 설계가 이 일로 넘겨 두었다.」
>     원문(넘겨받은 글)에는 이 넘김이 없다 — 「정하지 않은 것」은 「새 skill 이름 · 설정 키 · 머리 키 · 파일 접미사(`-interview.md`)의 새 이름,
>     옛 기록(77개)을 옮길지, 범위(request-framing 까지인지)」 뿐이고, 사용자가 답한 질문도
>     「「인터뷰」 명칭을 「의도 싱크」로 바꾸는 일의 자료를 … 어떻게 받을까요?」 → 「2, …」 이다.
>     읽어 확인한 출처 — 옆 세션 설계문서
>     `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md` 555행:
>     「| brief · audit 를 `intent/` 에 바로 쓰기 · `source_interview` 키 이름 | … | 이름 바꾸기 로드맵(§결정 기록 B13) · R5 |」
>     — 받는 곳이 이 일 하나가 아니라 「· R5」 와 함께 적혀 있고, 그 문서는 초안 스스로 「아직 리뷰와 승인 전」 이라 적은 문서다.
>   replacement: >-
>     이 문장을 「다시 검증할 것」 으로 옮기고 이렇게 쓴다 — 옆 세션 설계문서(승인 전)의 미룸 표가 이 두 가지를 이름 바꾸기 쪽과
>     그 로드맵의 이전 에픽 앞으로 적어 두었다. 사용자가 이 일에 받은 것은 이름 바꾸기이고, 앞단이 그 폴더에 바로 쓰게 하는 일을
>     이 일이 맡을지는 묻지 않았다.
>   if_unfixed: >-
>     인터뷰가 「앞단이 로드맵 폴더에 바로 쓰기」 를 이미 받은 범위로 읽고 설계에 넣는다. 사용자는 받은 적 없는 일이 범위에 들어온 것을
>     결과물에서야 보게 되고, 옆 로드맵의 이전 에픽과 같은 일을 둘이 맡게 될 수 있다.
> - ref: c2
>   layer: 1
>   category: inference_as_decision
>   anchor: "#__doc__"
>   disposition: fix
>   summary: >-
>     「계기는 그 로드맵에서 드러난 의역이다」 와 「그래서 옆 세션 설계는 …」 은 저자가 만든 인과 서술인데 사실처럼 쓰였고,
>     사용자가 이름 바꾸기 이유로 한 말이 이 일 전체의 계기로 자리를 옮겼다.
>   edit_scope: "#__doc__"
>   evidence: >-
>     초안: 「계기는 그 로드맵에서 드러난 의역이다. … 사용자는 「내 의도가 interview지나면서 의역된거 같아서 그래」 라고 했다.
>     그래서 옆 세션의 팀 파일 규약 설계는 내용마다 집을 하나로 정하고 …」.
>     원문에서 그 말은 넘겨받은 글의 이름 바꾸기 대화 줄이다 — 「의도 싱크로 바꾸고 따로 에픽으로 두자」 바로 다음 줄
>     「내 의도가 interview지나면서 의역된거 같아서 그래」.
>     이 세션에서 사용자가 말한 시작은 「Framing request, interview 필로소피 레포내 컨텍스트나 글이 경우 최근 우리 방식에 제약이 되지 않는지 조사부터」 이고,
>     목적은 「framing과 interview가 우리 새로운 코어와 맞지 않는 부분들이 있으니 그 앞단을 개선, 강화, 낡은 부분 수정 등을 하기 위한거야」 다.
>     기록 파일 `## 3` 나 는 옆 설계가 「한 번만 짓는다」 의 근거로 든 사용자 말을 다른 문장
>     (「오늘 brief 문서 구조랑 소통 구조 실패로 인해 드리프트 되는거처럼」)으로 적고 있다.
>     「폴더 구조와 행동양식이 … 줄고 바뀌었고」 의 바탕 수치는 초안 스스로 「옆 세션이 만든 원자료 대조표의 측정이고 Phase 0 이 다시 재지 않았다」 고 적었다.
>   replacement: >-
>     「계기는」 · 「그래서」 를 빼고 출처를 붙여 쓴다 — 사용자는 옆 세션의 이름 바꾸기 대화에서
>     「내 의도가 interview지나면서 의역된거 같아서 그래」 라고 했다(넘겨받은 글). 옆 세션의 대조표는 프레이밍 원문이 하류로 가며
>     줄고 바뀌었다고 적는다(그 세션의 측정). 이것이 이 일의 계기인지는 Phase 0 의 읽기이고 사용자에게 묻지 않았다.
>   if_unfixed: >-
>     인터뷰가 이 일을 「의역 손실 고치기」 로 읽고 시작한다. 사용자가 말한 목적(앞단을 새 코어에 맞게 개선 · 강화 · 낡은 부분 수정)과
>     첫 요청(제약이 되는지 조사)이 그 아래로 밀리고, 사용자 말이 본래 문맥과 다른 뜻으로 원문 자리에 굳는다.
> - ref: c3
>   layer: 1
>   category: omission
>   anchor: "#__doc__"
>   disposition: fix
>   summary: >-
>     넘겨받은 글이 적은 옆 로드맵의 예약 파일 목록과 「새로 생기는 파일에는 처음부터 새 이름을 쓴다」 는 줄이
>     초안에도 덜어 낸 것 표에도 없다.
>   edit_scope: "#__doc__"
>   evidence: >-
>     원문: 「새로 생기는 파일에는 처음부터 새 이름을 쓴다. R1 이 예약한 파일: `plugins/spec-distill/scripts/roadmap_write.py` · `roadmap_render.py` ·
>     `roadmap_model.py` · `roadmap_status.py` · `check_bundle_coverage.py` · `spec_review_bundle.py` · `references/epic-handoff.md`.」 ·
>     「R2 가 `plugins/spec-distill/scripts/repo_defaults.py`(설정 키) · `references/conducting.md` · `conductor-dispatch.md` ·
>     `skills/epic-conductor/SKILL.md` 를, R5 가 `docs/superpowers/specs/` · `docs/superpowers/roadmaps/` 이전을 예약했다.」
>     초안의 「같은 파일을 여럿이 건드린다」 문단은 끝맺음 절차 파일 · 철학 문서 · CLAUDE.md 만 든다.
>     덜어 낸 것 표에서 넘겨받은 자료를 가리키는 줄은 「이름 바꾸기 규모 수치」 하나다.
>     (예약 목록은 옆 로드맵 `roadmap.md` 32 · 44 · 79행에서 실재를 확인했다.)
>   replacement: >-
>     「같은 파일을 여럿이 건드린다」 문단에 한두 문장을 더한다 — 이름 바꾸기가 닿는 설정 키 파일과 로드맵 스크립트 · 넘김 글 파일은
>     옆 로드맵의 에픽들이 예약해 두었고(목록은 넘겨받은 글에 있다), 옆 세션은 새로 만드는 파일에 처음부터 새 이름을 쓰겠다고 했다.
>     싣지 않기로 하면 덜어 낸 것 표에 그 줄을 더한다.
>   if_unfixed: >-
>     인터뷰가 이름 바꾸기 범위를 잡을 때 설정 키 파일과 로드맵 스크립트가 남의 예약이라는 것을 모른다. 옆 세션이 새 이름을
>     먼저 쓰기 시작한다는 것도 몰라서, 「새 이름을 무엇으로 할지」 를 이 일이 늦게 정하면 두 곳의 이름이 갈린다.
> - ref: c4
>   layer: 1
>   category: omission
>   anchor: "#__doc__"
>   disposition: fix
>   summary: >-
>     사용자가 철학 문서를 두고 한 방향(레포에 치우치기보다 표준에, 더하기보다 풀기)이 「무엇을 두고 한 말인지」 로만 남고
>     할 일로는 빠졌으며, 「레포에 치우치기보다」 부분은 초안에 아예 없다.
>   edit_scope: "#__doc__"
>   evidence: >-
>     원문: 「내가 말하는거는 우리 레포에 바이어스 되게 보다 표준에 맞게 가자는거였어」 · 「가능하면 추가보다는 푸는 쪽으로 가고」 · 「아 이거는 철학이야기야」.
>     초안: 「표준에 맞게 가자는 말과 추가보다 푸는 쪽으로 가자는 말은 철학 문서를 두고 한 말이다. (사용자 확인)」 —
>     철학 문서를 그 방향으로 고친다는 문장도, 고칠지가 열려 있다는 문장도 없다. 초안에 치우침은
>     「사용자는 이 일이 치우침 정리가 아니라고 했고」 로만 나온다.
>     저자 자신의 긴 초안(기록 파일 `## 3` 가)은 이것을 방향으로 적었다 —
>     「철학 문서: 레포에 치우치기보다 표준에 맞게, 더하기보다 푸는 쪽으로」.
>     덜어 낸 것 표에는 해당 줄이 없다(「뒤집힌 풀이 둘」 은 이 일 전체의 정의로 읽었던 풀이를 가리킨다).
>   replacement: >-
>     확인받은 문장은 그대로 두고 한 문장을 잇는다 — 사용자가 철학 문서에 대해 말한 방향은 레포에 치우치기보다 표준에 맞추고,
>     더하기보다 푸는 쪽이다. 이 일이 철학 문서를 어디까지 고칠지는 묻지 않았다(다시 검증할 것).
>   if_unfixed: >-
>     인터뷰가 「치우침 정리가 아니다」 만 보고 철학 문서의 레포 치우침을 범위 밖으로 읽거나, 반대로 철학 문서를 이 일이 고치는 것을
>     전제로 옆 로드맵과의 나눔만 묻는다. 어느 쪽이든 사용자가 한 말의 절반이 질문 없이 정해진다.
> - ref: c5
>   layer: 1
>   category: premature_closure
>   anchor: "#__doc__"
>   disposition: fix
>   summary: >-
>     사용자는 새 코어를 「지휘 재설계 로드맵이 세우는 팀 구조」 라고 확인했는데, 초안은 그 기준을 승인 전인 설계문서 하나로 좁혔다.
>   edit_scope: "#__doc__"
>   evidence: >-
>     풀이(고름): 「새 코어는 지휘 재설계 로드맵이 세우는 팀 구조다.」 사용자 말: 「옆 세션을 잘 이해해야겠지」.
>     초안: 「새 코어의 기준은 옆 세션의 팀 파일 규약 설계문서인데, 그 문서는 아직 리뷰와 승인 전이고 …」.
>     초안이 기대는 「작은 일도 리더를 거친다는 새 코어의 결정」 은 그 설계문서가 아니라 로드맵의 지휘 절차 에픽 묶음에 있다 —
>     읽어 확인: `docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md` 42행
>     「설계문서 하나뿐인 작은 일도 지휘자를 거친다」.
>   replacement: >-
>     「새 코어의 기준은 …」 을 이렇게 바꾼다 — 새 코어를 지금 가장 자세히 적은 글은 옆 세션의 팀 파일 규약 설계문서이고(승인 전 ·
>     로컬 브랜치 · 회의 중 한 번 바뀜), 새 코어는 그 로드맵 전체가 세우는 팀 구조라 다른 에픽의 묶음과 로드맵 파일도 함께 읽어야 한다.
>   if_unfixed: >-
>     인터뷰와 설계가 설계문서 하나만 잣대로 삼는다. 지휘 절차 · 편지함 에픽이 정하는 부분(작은 일의 길, 리더 사이 소통)은 대조에서
>     빠지고, 그 문서가 승인 과정에서 바뀌면 잣대 전체가 흔들린다.
> - ref: c6
>   layer: 1
>   category: premature_closure
>   anchor: "#__doc__"
>   disposition: fix
>   summary: >-
>     첫 요청을 풀어 쓰면서 원문에서 갈리는 읽기 하나를 골랐고(프레이밍 · 인터뷰가 조사할 자리인지 조사 대상인지),
>     「최근 우리 방식」 의 「우리」 도 빠졌다.
>   edit_scope: "#__doc__"
>   evidence: >-
>     원문: 「Framing request, interview 필로소피 레포내 컨텍스트나 글이 경우 최근 우리 방식에 제약이 되지 않는지 조사부터」.
>     초안: 「사용자의 첫 요청은 프레이밍과 인터뷰에서 철학, 레포 안 컨텍스트, 글이 최근 방식에 제약이 되지 않는지 조사부터 하라는 것이었다.」
>     같은 문장을 라운드 1 풀이는 다르게 읽었다 — 「request-framing · 인터뷰 · 철학 · 레포 문서가 …」(나란한 대상).
>     어느 읽기가 맞는지 사용자에게 물은 질문은 없다.
>   replacement: >-
>     풀어 쓰지 말고 원문을 그대로 인용한다 — 사용자의 첫 요청은 「Framing request, interview 필로소피 레포내 컨텍스트나 글이 경우
>     최근 우리 방식에 제약이 되지 않는지 조사부터」 였다.
>   if_unfixed: >-
>     하류는 「프레이밍과 인터뷰 안에서만」 철학 · 레포 글의 제약을 보는 것으로 읽는다. 철학 문서나 레포 문서 자체가 조사 대상이었을
>     가능성이 질문 없이 닫힌다 — 이 일이 고치려는 바로 그 꼴의 의역이다.
> - ref: c7
>   layer: 1
>   category: omission
>   anchor: "#__doc__"
>   disposition: fix
>   summary: >-
>     넘겨받은 글에 옮겨진 사용자 말 「폴더명도 바꿀까」 가 초안의 「정하지 않았다」 목록에도 덜어 낸 것 표에도 없다.
>   edit_scope: "#__doc__"
>   evidence: >-
>     원문: 「폴더명도 바꿀까 그리고 인터뷰라는 명칭도」.
>     초안: 「새 이름을 무엇으로 할지, 옛 기록을 옮길지, request-framing 이라는 이름까지 바꿀지는 정하지 않았다.」 — 폴더 이름은 없다.
>     덜어 낸 것 표에도 없다.
>   replacement: >-
>     「정하지 않았다」 줄에 더한다 — 폴더 이름도 바꿀지(사용자가 옆 세션에서 물은 것이고, 어느 폴더를 가리키는지는 넘겨받은 글만으로는
>     알 수 없다).
>   if_unfixed: >-
>     이름 바꾸기 범위를 물을 때 폴더 이름이 질문에 오르지 않는다. 사용자가 먼저 꺼낸 것이 말없이 빠진 채 범위가 정해진다.
> ```
>
> ```docreview-layer2
> []
> ```
>
> 판단이 갈릴 수 있는 것은 c5 · c6 · c7 이다. 셋 다 닫힘이나 빠짐이 실재하지만 영향이 작아, 재비판에서 걸러질 수 있다.
>
> 참고로, 층 1 범위 밖이라 finding 으로 내지 않은 어긋남이 하나 있다. 초안은 「superpowers 가 없으면 끝 게이트가 없다」 를 조사 agent 보고로 분류했는데, 기록 파일 `## 3` 다.2 는 같은 사실을 「직접, 그 줄만」 으로 적었다.
>
> 읽어 확인한 파일:
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-interview.audit.md` (원문 · 질문 전체 · 긴 초안 · 덜어 낸 것 표)
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md` (32 · 44 · 79행 경로 예약)
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md` (42행)
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md` (555행 미룸 표 — grep 으로 해당 줄만 확인)

### 라운드 1 — codex

> findings: []
> meta:
>   codex_failed: true
>   reason: exit_nonzero
>   exit_code: 1
>   stderr_kind: quota

### 라운드 1 — 재비판 (doc-recritic)

> 문서(번들)와 finding 7건을 모두 읽었다. 7건 모두 confirm 이고, 기각 · 상향 · 병합 · 추가는 없다. `<diff>` 를 받지 않아 「이 변경이 도입했는가」 축은 쓰지 않았다.
>
> ```docreview-recritic
> verdicts:
>   - f: f1
>     verdict: confirm
>   - f: f2
>     verdict: confirm
>   - f: f3
>     verdict: confirm
>   - f: f4
>     verdict: confirm
>   - f: f5
>     verdict: confirm
>   - f: f6
>     verdict: confirm
>   - f: f7
>     verdict: confirm
> added: []
> ```
>
> ## 판정 근거
>
> - **f1 (confirm)** — 「내 의도가 interview지나면서 의역된거 같아서 그래」 는 원문에서 넘겨받은 글의 이름 바꾸기 대화 줄(「의도 싱크로 바꾸고 따로 에픽으로 두자」 바로 다음)이다. 이 세션에서 사용자가 말한 시작은 「…제약이 되지 않는지 조사부터」 이고 목적은 「새로운 코어와 맞지 않는 부분들이 있으니 그 앞단을 개선, 강화, 낡은 부분 수정」 이다. 「계기는」 · 「그래서」 라는 인과는 원문 줄과 「고름」 풀이 어디에도 없다. finding 이 번들 밖에서 인용한 기록 파일 `## 3` 나 의 다른 사용자 말(150행)도 실재한다.
> - **f2 (confirm)** — 예약 파일 목록과 「새로 생기는 파일에는 처음부터 새 이름을 쓴다」 는 초안에 없다. 덜어 낸 것 표에서 넘겨받은 자료를 가리키는 줄은 규모 수치 하나뿐이다. 기록 파일 `## 3` 바 에 예약 줄이 있지만, 표 첫 줄이 덮는 범위는 `## 3` 다 · 라 · 마 라서 공시된 덜어 냄으로 볼 수 없다.
> - **f3 (confirm)** — 초안의 확인 문장은 「고름」 풀이 그대로라 틀리지 않았다. 다만 원문의 「우리 레포에 바이어스 되게 보다」 는 초안에 없고, 치우침은 「치우침 정리가 아니라고 했고」 로만 나온다. 표의 「뒤집힌 풀이 둘」 도 이 빠짐을 공시하지 않는다. 일곱 건 중 가장 약한 건이다 — 방향의 두 반쪽(「표준에 맞게」 · 「추가보다 푸는 쪽」)은 간접 화법으로 남아 있다.
> - **f4 (confirm)** — 「폴더명도 바꿀까 그리고 인터뷰라는 명칭도」 는 원문 줄인데, 초안의 「정하지 않았다」 목록(새 이름 · 옛 기록 · request-framing)과 표 어디에도 폴더 이름이 없다. 무효로 만들 문서 줄을 찾지 못했다.
> - **f5 (confirm)** — 사용자가 고른 것은 「지휘 재설계 로드맵이 세우는 팀 구조」 인데 초안은 「새 코어의 기준은 … 설계문서」 로 적었다. 넘겨받은 글의 「R1 … 이 새 구조를 세운다」 가 그 문서를 주된 읽을 자리로 삼을 근거는 되지만, 초안이 「새 코어의 결정」 이라 부른 「작은 일도 리더를 거친다」 는 그 설계문서에 없고 로드맵 묶음의 확인 줄(R1.md 43행 · R2.md 42행)에 있다. 초안이 스스로 설계문서 밖의 결정에 기대고 있어 좁힘이 맞다.
> - **f6 (confirm)** — 원문은 「Framing request, interview 필로소피 레포내 컨텍스트나 글이 …」 로 대상의 관계가 갈린다. 초안은 「프레이밍과 인터뷰에서 철학, …」 로 한 읽기를 골랐고, 이를 물은 질문은 `## 2` 에 없다. 원문 인용으로 바꾸는 수정은 범위 안이다.
> - **f7 (confirm, 절반만 성립)** — 「앞단이 그 폴더에 바로 쓰게 하는 일」 을 이 일로 넘겼다는 근거는 원문 줄에 없다. 옆 설계문서 555행도 받는 곳을 「이름 바꾸기 로드맵 · R5」 로 적어 이 일 하나가 아니다. 반면 「설계문서 머리 키의 이름」 은 넘겨받은 글의 「정하지 않은 것」(「머리 키 … 의 새 이름」)에 있고, 사용자가 받은 이름 바꾸기 범위에 든다.
>
> ## 수정할 때 볼 것
>
> - **f7 의 `replacement`** 는 두 가지를 모두 「다시 검증할 것」 으로 옮긴다. 머리 키 이름은 이미 받은 범위라, 옮길 것은 「바로 쓰기」 쪽만으로 좁히는 편이 맞다.
> - **f1 과 f7** 은 초안의 같은 문단(「계기는 …」)을 고친다. 결함은 서로 달라 `same_as` 로 묶지 않았지만 편집은 한 번에 맞춰야 한다.
>
> ## 읽은 파일
>
> - `/Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/.docreview/2026-11-14-framing-interview-constraint--199af10b31ba2c4c/seed-bundle-recritic.md`
> - `/private/tmp/claude-501/-Users-jeonghokim-Downloads-devbrew/ee276545-0999-4e89-aeab-9cec39e6c504/scratchpad/recritic-items.json`
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-interview.audit.md` (`## 3` 과 덜어 낸 것 표)
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R1.md` · `R2.md`
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md` (350 · 555행)

### 라운드 2 — 탐지 1 (doc-critic)

> 번들(`/Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/.docreview/2026-11-14-framing-interview-constraint--199af10b31ba2c4c/seed-bundle.md`)을 끝까지 읽었고, 층 1 에서 fix 2건을 낸다. 층 2 는 프로필이 비워 두어 빈 리스트다.
>
> ```docreview-layer1
> - ref: c1
>   layer: 1
>   category: omission
>   anchor: "#__doc__"
>   disposition: fix
>   summary: "「맞출 표준이 무엇이냐」 는 물음에 사용자가 Claude Code 공식을 골랐다는 답이 초안에 없어서, 「표준에 맞추고」 가 무엇에 맞춘다는 말인지 초안만으로는 알 수 없다."
>   edit_scope: "#__doc__"
>   evidence: "질문 전체 라운드 1 — 물은 것: 「맞출 「표준」은 무엇인가요? 여럿을 고를 수 있습니다.」 · 선택지: 「Claude Code 공식 (권장) / 외부 작업 방식 관례 / 일반 개발 관례」 · 당신이 답한 것: 「Claude Code 공식 (권장), 참고내용으로 두는거야」. 초안: 「사용자가 철학 문서에 대해 말한 방향은 레포에 치우치기보다 표준에 맞추고, 더하기보다 푸는 쪽이다. Claude Code 공식 자료는 따라야 할 기준이 아니라 참고 내용으로 둔다. (사용자 확인)」 — 두 문장이 나란히 있을 뿐, 사용자가 말한 표준이 Claude Code 공식이라는 것과 나머지 둘을 고르지 않았다는 것은 어디에도 없다. 덜어 낸 것 표에도 해당 줄이 없다."
>   replacement: "확인받은 문장은 그대로 두고 한 문장을 잇는다 — 맞출 표준이 무엇이냐는 물음에 사용자는 Claude Code 공식을 골랐고 「참고내용으로 두는거야」 라고 덧붙였다. 외부 작업 방식 관례와 일반 개발 관례는 고르지 않았다. 「표준에 맞게」 와 「참고 내용」 이 어떻게 함께 가는지는 묻지 않았다(다시 검증할 것)."
>   if_unfixed: "인터뷰가 「표준」 을 다시 묻거나, 「공식 자료는 기준이 아니다」 만 보고 사용자가 고르지 않은 일반 관례를 표준으로 잡는다. 사용자가 이미 답한 것이 질문 없이 바뀐다."
> - ref: c2
>   layer: 1
>   category: premature_closure
>   anchor: "#__doc__"
>   disposition: fix
>   summary: "사용자는 「가능하면」 추가보다 푸는 쪽이라고 했는데, 초안에는 그 단서가 빠져 「더하기보다 푸는 쪽이다」 로 굳어 있다."
>   edit_scope: "#__doc__"
>   evidence: "원문: 「가능하면 추가보다는 푸는 쪽으로 가고」. 초안: 「사용자가 철학 문서에 대해 말한 방향은 레포에 치우치기보다 표준에 맞추고, 더하기보다 푸는 쪽이다.」 — 초안 어디에도 「가능하면」 이나 사용자 말 원문이 없다. 같은 문단은 첫 요청은 원문 그대로 인용했다."
>   replacement: "그 문장에 사용자 말을 그대로 싣는다 — 사용자가 철학 문서에 대해 한 말은 「내가 말하는거는 우리 레포에 바이어스 되게 보다 표준에 맞게 가자는거였어」 와 「가능하면 추가보다는 푸는 쪽으로 가고」 다. 풀어 쓴 문장을 남긴다면 「가능하면」 을 넣는다."
>   if_unfixed: "인터뷰와 설계가 철학 문서에는 더하지 않는다는 것을 규칙으로 읽는다. 더하는 편이 맞는 자리에서도 선택지가 사용자에게 오르지 않고, 옆 로드맵이 예약한 원칙 개정과 나눌 때 이 일이 스스로 손을 묶는다."
> ```
>
> ```docreview-layer2
> []
> ```
>
> 참고 (finding 아님):
> - `supersedes` 는 달지 않았다. 원장(`/Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/.docreview/2026-11-14-framing-interview-constraint--199af10b31ba2c4c/docreview-state.md`)으로 이전 7건의 내용을 대조했고, 7건 모두 이번 초안에 반영돼 있어 같은 결함의 재발은 없다. c2 가 겨누는 문장은 `63982916#r1.2` 의 대체 문안을 넣으며 생긴 문장이지만 결함은 다르다(그때는 방향 누락, 이번은 단서 누락).
> - 「(사용자 확인)」 이 붙은 열 문장은 모두 질문 전체의 「고름」 풀이와 글자가 맞는다.
> - 초안이 단정한 옆 세션 설계의 세부(`intent/original.md` · 줄 범위로 가리킴 · 옮겨 적은 사본)는 원문 줄에 없다. 다만 audit `## 3` 나(150–151행)와 일치하고, 출처 표시와 「승인 전 · 다시 읽어야 한다」 단서가 붙어 있어 내지 않았다 — audit 경로: `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-interview.audit.md`.
> - 덜어 낸 것 표의 「사용자에게 묻지 않은 여섯」 은 사용자 원문 요구가 아니라 저자의 조사 결과이고 표에 공시돼 있어 빠짐으로 보지 않았다.

### 라운드 2 — codex

> findings:
>   - agent: codex-reviewer
>     ref: x1
>     layer: 1
>     category: inference_as_decision
>     anchor: "#__doc__"
>     disposition: fix
>     summary: 사용자가 고른 네 가지 방향을 넘어서는 구체적인 실행 방식까지 사용자 확인을 받은 결정으로 적었습니다.
>     edit_scope: "#__doc__"
>     blocks: []
>     evidence: 붙여 넣은 글과 직접 쓴 말 같은 원자료를 파일로 그대로 두고, 사용자 원문 자리에는 seed 가 아니라 그 원자료가 가게 한다. (사용자 확인) 앞단의 끝은 작은 일도 리더로 넘기고, 넘김 글은 짧게 쓰고 자세한 지시는 파일 경로로 둔다. (사용자 확인) 앞단 skill 글에서 이유와 이력 설명, 낡은 서술, 옛 설계 번호를 걷어내 읽는 양을 줄인다. (사용자 확인) 작은 일에서는 필수 조사와 리뷰 일부를 모델이 이유를 적고 건너뛸 수 있게 한다. (사용자 확인)
>     replacement: 사용자가 고른 방향은 원자료를 정식 산출물로 두기, 리더로 넘기고 글을 짧게 쓰기, 앞단 글 줄이기, 작은 일의 가벼운 길이다. 사용자 원문 칸을 원자료로 바꾸는 방식, 작은 일까지 리더로 넘기는 범위, 자세한 지시를 파일 경로로 두는 방식, 걷어낼 글의 종류, 필수 조사와 리뷰를 모델 판단으로 건너뛰게 하는 방식은 저자의 풀이이며 사용자 확정으로 취급하지 않는다. 기록의 풀이에는 ‘고름’ 표시가 있지만, 이를 확인한 사용자의 말은 제시되어 있지 않다.
>     if_unfixed: 후속 작업이 넓은 방향 선택을 구체적인 변경 승인으로 받아들여, 사용자 확인 없이 원문 칸을 교체하거나 조사·리뷰 생략 권한과 글 삭제 범위를 확정할 수 있습니다.
> meta:
>   codex_failed: false
>   exit_code: 0

### 라운드 2 — 재비판 (doc-recritic)

> 번들과 finding 3건을 모두 읽고 판정했다. `<diff>` 는 받지 않아 「이 변경이 도입했는가」 축은 쓰지 않았다. 판정 근거는 번들 안의 줄뿐이고 audit 원본 파일은 열지 않았다.
>
> ```docreview-recritic
> verdicts:
>   - f: f1
>     verdict: reject
>     evidence: "질문 전체 라운드 3 확인 질문에 네 문장이 글자 그대로 있고 모두 사용자가 골랐다 — 「붙여 넣은 글과 직접 쓴 말 같은 원자료를 파일로 그대로 두고, 사용자 원문 자리에는 seed 가 아니라 그 원자료가 가게 한다.」 — 고름 / 「앞단의 끝은 작은 일도 리더로 넘기고, 넘김 글은 짧게 쓰고 자세한 지시는 파일 경로로 둔다.」 — 고름 / 「앞단 skill 글에서 이유와 이력 설명, 낡은 서술, 옛 설계 번호를 걷어내 읽는 양을 줄인다.」 — 고름 / 「작은 일에서는 필수 조사와 리뷰 일부를 모델이 이유를 적고 건너뛸 수 있게 한다.」 — 고름. 프로필의 inference_as_decision 기준은 «(사용자 확인)» 문장이 「고름」 풀이에 없을 때인데 넷 다 있다. 초안도 범위를 스스로 한정한다 — 「이 넷은 사용자가 먼저 말한 것이 아니라 Phase 0 이 조사에서 잡아 제안한 것을 사용자가 고른 것이다」, 「사용자가 고른 것은 방향 넷이고, 그 방향을 어느 파일의 어느 장치로 옮길지는 열려 있다」. 오탐."
>   - f: f2
>     verdict: confirm
>   - f: f3
>     verdict: confirm
> added: []
> ```
>
> 판정 메모(블록 밖 참고):
>
> - f1 기각 — finding 의 대체문은 사용자가 라운드 3 에서 고른 풀이 넷을 「저자의 풀이」로 내리자는 것인데, 이는 정답 줄(풀이 줄의 「고름」)과 반대다.
> - f2 확인 — 라운드 1 의 「맞출 「표준」은 무엇인가요?」 에 대한 답 「Claude Code 공식 (권장), 참고내용으로 두는거야」 에서 초안은 뒤 절반(참고 내용)만 실었다. 이 답이 「표준이 무엇이냐」 는 물음의 답이라는 것과 나머지 두 선택지를 고르지 않았다는 것은 초안에도 덜어 낸 것 표에도 없다. 초안의 「표준에 맞추고」 는 가리키는 대상이 비어 있다. 처분 `fix` 는 적절하다(정답 줄의 사실을 더하고 긴장은 「다시 검증할 것」 으로 여는 수정).
> - f3 확인 — 원문 「가능하면 추가보다는 푸는 쪽으로 가고」 의 「가능하면」 이 초안의 「더하기보다 푸는 쪽이다」 에서 빠졌다. 이 문장에는 «(사용자 확인)» 이 없어 저자의 재진술이고, 라운드 1 풀이의 「먼저 고른다」 같은 완화 표현도 남아 있지 않다. 경미하지만 실재하는 닫힘이고, 원문을 그대로 싣는 수정으로 풀린다.
> - 추가 finding 없음 — 원문 여섯 줄, 넘김 글, 라운드 0–3 답과 풀이 열 개를 초안과 덜어 낸 것 표에 대조했고, 세 건 밖에서 말없이 빠지거나 더해진 요구는 찾지 못했다.
>
> 읽은 파일:
> - /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/.docreview/2026-11-14-framing-interview-constraint--199af10b31ba2c4c/seed-bundle-recritic.md
> - /private/tmp/claude-501/-Users-jeonghokim-Downloads-devbrew/ee276545-0999-4e89-aeab-9cec39e6c504/scratchpad/recritic-items.json

### 라운드 3 — 탐지 1 (doc-critic)

> 번들을 끝까지 읽었고(266줄), 층 1 에서 fix 2건을 낸다. 층 2 는 프로필이 비워 두어 빈 리스트다.
>
> c1 은 받은 번들만으로는 보이지 않는다. 번들의 `## 사용자 원문` 절은 넘겨받은 글에서 끝나는데, 기록 파일의 `## 1. 원문` 에는 그 뒤에 사용자 말이 한 줄 더 있다(3라운드 시작 뒤에 더해진 줄). 재비판에 같은 번들을 넘기면 근거 줄이 없어 기각될 수 있으니, 번들을 다시 조립하거나 기록 파일 76–78행을 함께 넘겨야 한다.
>
> ```docreview-layer1
> - ref: c1
>   layer: 1
>   category: omission
>   anchor: "#__doc__"
>   disposition: fix
>   summary: >-
>     사용자가 seed 리뷰 도중에 한 말 「이거 덩어리 승인하는과정 내가 보기 어려우니까 개선하자」 가
>     기록 파일의 원문 절에는 올라 있는데 초안에도 덜어 낸 것 표에도 없다.
>   edit_scope: "#__doc__"
>   evidence: >-
>     기록 파일 `## 1. 원문` 76–78행(읽어 확인):
>     「### seed 리뷰 도중 사용자가 보낸 말 (2026-11-14, 2라운드의 편집 덩어리 넷을 처분한 직후 · 3라운드 시작 뒤)」 ·
>     「이거 덩어리 승인하는과정 내가 보기 어려우니까 개선하자」.
>     초안(seed 파일 7–21행, 번들의 초안 절과 글자가 같다)에는 덩어리 승인 과정을 가리키는 문장이 없다.
>     덜어 낸 것 표 열두 줄에도 이 말을 가리키는 줄이 없다.
>     받은 번들의 `## 사용자 원문` 절에는 이 줄이 없고, docreview 상태 폴더 전체에서도 이 문구는 0건이다 —
>     번들이 이 줄이 더해지기 전에 조립됐다.
>     이 말이 가리키는 것은 request-framing 의 seed 리뷰 화면이고, 초안이 적은 이 일의 목적은
>     「request-framing 과 인터뷰가 새 코어와 맞지 않는 부분을 개선하고 강화하고 낡은 부분을 고치는 것」 이다.
>   replacement: >-
>     초안에 사용자 말을 그대로 싣는다 — 사용자는 이 seed 를 리뷰하던 중 편집 덩어리 넷을 처분한 직후
>     「이거 덩어리 승인하는과정 내가 보기 어려우니까 개선하자」 라고 했다. 무엇이 보기 어려웠는지와
>     이 일에서 고칠지는 묻지 않았다(다시 검증할 것). 싣지 않기로 하면 덜어 낸 것 표에 그 줄과 기준을 적는다.
>   if_unfixed: >-
>     인터뷰는 seed 만 읽고 시작해서 이 요구를 모른다. 앞단을 고치는 일인데, 사용자가 앞단을 직접 쓰다가
>     꺼낸 불편이 질문에도 범위에도 오르지 않고 기록 파일에만 남는다.
> - ref: c2
>   layer: 1
>   category: unfounded_addition
>   anchor: "#__doc__"
>   disposition: fix
>   summary: >-
>     인터뷰 끝맺음 절차 파일을 옆 로드맵의 지휘 절차 에픽도 함께 고친다는 말이 사실처럼 적혀 있는데,
>     넘겨받은 글은 열린 PR 하나만 들었고 그 에픽의 경로 예약에도 이 파일이 없다.
>   edit_scope: "#__doc__"
>   evidence: >-
>     초안: 「인터뷰 끝맺음 절차 파일은 이 일, 옆 로드맵의 지휘 절차 에픽, 그리고 인터뷰 끝에서 PR 을 열고 머지를 묻게 하는 열린 PR 이 함께 고친다.」
>     원문(넘겨받은 글): 「열린 PR #274 가 `plugins/spec-distill/skills/pm-interview/references/finishing.md` 를 고친다.」 ·
>     「R2 가 `plugins/spec-distill/scripts/repo_defaults.py`(설정 키) · `references/conducting.md` · `conductor-dispatch.md` · `skills/epic-conductor/SKILL.md` 를 … 예약했다.」
>     — 지휘 절차 에픽 쪽 목록에 끝맺음 파일은 없다.
>     읽어 확인: 옆 로드맵 `roadmap.md` 44행의 그 에픽 경로 예약은 여섯 경로
>     (conducting.md · conductor-dispatch.md · epic-conductor/SKILL.md · repo_defaults.py · 철학 문서 · CLAUDE.md)이고,
>     로드맵 폴더 전체에서 「finishing」 · 「끝맺음」 은 0건이다.
>     이 말의 출처는 옆 세션 설계문서 552행의 미룸 표다 —
>     「| 분해 승인 화면에 과제마다 지시 원문 범위의 글을 보이기 · 분해 전에 `original` 을 부르기 |
>     인터뷰 끝맺음 절차 파일은 이 에픽의 예약 밖이고, 새 형식을 켤 때 함께 바꿔야 한다 | R2 |」.
>     그 문서는 초안 스스로 「아직 리뷰와 승인 전」 이라 적은 문서이고, 초안은 같은 표의 다른 줄에는
>     「옆 세션 설계문서의 미룸 표는 … 적어 두었다」 로 출처를 붙였다.
>     「이 일」 이 그 파일을 고친다는 것도 초안의 「그 방향을 어느 파일의 어느 장치로 옮길지는 열려 있다」 와 어긋난다.
>   replacement: >-
>     그 문장을 출처를 붙여 다시 쓴다 — 인터뷰 끝맺음 절차 파일은 인터뷰 끝에서 PR 을 열고 머지를 묻게 하는
>     열린 PR 이 고치고 있다(넘겨받은 글). 옆 세션 설계문서(승인 전)의 미룸 표는 분해 승인 화면을 바꾸는 일을
>     지휘 절차 에픽 앞으로 적어 두었고, 그 에픽의 경로 예약에는 이 파일이 없다. 앞단의 끝을 바꾸는 방향도
>     이 파일에 닿을 수 있다(Phase 0 의 읽기).
>   if_unfixed: >-
>     인터뷰가 세 곳이 이 파일을 고친다는 것을 확정된 사실로 놓고 머지 순서를 짠다. 옆 설계가 승인 과정에서
>     그 미룸을 바꾸면 순서 계획이 틀린 전제 위에 서고, 옆 로드맵의 예약 목록만 보는 쪽은 이 겹침을 알 수 없다.
> ```
>
> ```docreview-layer2
> []
> ```
>
> 참고 (finding 아님):
>
> - c2 는 영향이 작다. 겹침 경고 자체는 쓸모가 있고, 문제는 출처 표시가 빠진 것뿐이라 재비판에서 걸러질 수 있다.
> - `supersedes` 는 달지 않았다. 원장으로 이전 10건을 대조했고, 적용된 9건은 이번 초안에 반영돼 있으며 같은 결함의 재발은 없다. c2 는 `3720b2b7#r1.1` 과 출처(옆 설계문서 미룸 표)가 같지만 다른 문장, 다른 줄이다.
> - 「(사용자 확인)」 이 붙은 열 문장은 모두 질문 전체의 「고름」 풀이와 글자가 같다.
> - 덜어 낸 것 표의 「사용자에게 묻지 않은 여섯」 은 내지 않았다. 요구 자체(「내가 말한거 이외에도 잡아내서 제안해줄 수 있겠지?」)는 초안에 실려 있고, 여섯은 저자의 조사 결과로 표에 공시돼 있다. 다만 초안만 읽으면 제안이 넷뿐이었던 것으로 읽힐 수 있다.
> - `## 6. 리뷰 결정` 의 네 줄은 편집 덩어리 처분(「그대로 둔다」)이라 이번 finding 과 부딪히지 않는다. `contradicts` 는 없다.
>
> 읽은 파일:
> - `/Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/.docreview/2026-11-14-framing-interview-constraint--199af10b31ba2c4c/seed-bundle.md` (리뷰 대상 번들)
> - `/Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/.docreview/2026-11-14-framing-interview-constraint--199af10b31ba2c4c/docreview-state.md` (이전 finding 내용)
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-interview.audit.md` (전체 — c1 근거는 76–78행)
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-interview.md` (seed 본문)
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md` (26–85행 — c2 근거는 44행)
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md` (grep 으로 342 · 466 · 552행만)

### 라운드 3 — codex

> findings:
>   - agent: codex-reviewer
>     ref: x1
>     layer: 1
>     category: premature_closure
>     anchor: "#__doc__"
>     disposition: fix
>     summary: 리더에게 넘긴다는 방향을 작은 일에도 예외 없이 적용하는 것으로 확정했습니다.
>     edit_scope: "#__doc__"
>     blocks: []
>     evidence: 앞단의 끝은 작은 일도 리더로 넘기고, 넘김 글은 짧게 쓰고 자세한 지시는 파일 경로로 둔다. (사용자 확인)
>     replacement: 사용자는 「리더로 넘기고 글은 짧게」와 「작은 일의 가벼운 길」을 골랐다. 작은 일에도 리더를 반드시 거치게 할지는 열어 둔다.
>     if_unfixed: 작은 일의 처리 경로를 검토할 때 리더를 거치지 않는 선택이 사용자 결정에 어긋난다는 이유로 제외될 수 있다.
>   - agent: codex-reviewer
>     ref: x2
>     layer: 1
>     category: unfounded_addition
>     anchor: "#__doc__"
>     disposition: fix
>     summary: 작은 일을 가볍게 처리하겠다는 선택에 필수 조사와 리뷰를 모델 판단으로 생략하는 권한을 추가했습니다.
>     edit_scope: "#__doc__"
>     blocks: []
>     evidence: 작은 일에서는 필수 조사와 리뷰 일부를 모델이 이유를 적고 건너뛸 수 있게 한다. (사용자 확인)
>     replacement: 사용자는 「작은 일의 가벼운 길」을 골랐다. 어떤 절차를 줄일지, 필수 조사나 리뷰를 생략할 수 있게 할지, 그 판단을 누가 맡을지는 정하지 않았다.
>     if_unfixed: 사용자가 직접 정하지 않은 생략 권한이 확정 요구로 전달되어 필수 조사와 리뷰를 건너뛰는 장치가 구현될 수 있다.
> meta:
>   codex_failed: false
>   exit_code: 0

### 라운드 3 — 재비판 (doc-recritic)

> 문서(번들)와 finding 4건을 모두 읽고 판정했다. `<diff>` 는 받지 않아 「이 변경이 도입했는가」 축은 쓰지 않았다. 놓친 결함은 찾지 못했다(`added: []`).
>
> ```docreview-recritic
> verdicts:
>   - f: f1
>     verdict: confirm
>   - f: f2
>     verdict: reject
>     evidence: "번들 `## 질문 전체` 라운드 3 확인 질문의 풀이 줄(134행): 「내가 읽은 것: 「앞단의 끝은 작은 일도 리더로 넘기고, 넘김 글은 짧게 쓰고 자세한 지시는 파일 경로로 둔다.」 — 고름」. 초안 문장은 사용자가 고른 풀이와 글자가 같다 — 프로필 기준으로 «(사용자 확인)» 은 「고름」 풀이에 있으면 성립한다. 또 초안은 이 지점을 닫지 않았다: 「작은 일의 가벼운 길이 작은 일도 리더를 거친다는 새 코어의 결정과 어떻게 함께 가는지는 Phase 0 이 본 긴장이다.」 · 「사용자가 고른 것은 방향 넷이고, 그 방향을 어느 파일의 어느 장치로 옮길지는 열려 있다.」 · 「이 넷은 사용자가 먼저 말한 것이 아니라 Phase 0 이 조사에서 잡아 제안한 것을 사용자가 고른 것이다.」"
>   - f: f3
>     verdict: reject
>     evidence: "번들 `## 질문 전체` 라운드 3 확인 질문의 풀이 줄(136행): 「내가 읽은 것: 「작은 일에서는 필수 조사와 리뷰 일부를 모델이 이유를 적고 건너뛸 수 있게 한다.」 — 고름」. 초안 문장은 사용자가 고른 풀이와 글자가 같아 근거 없는 추가가 아니다. 라운드 2 에서도 사용자는 「작은 일의 가벼운 길」 을 직접 골랐다(121행). 초안은 출처도 밝혔다: 「이 넷은 사용자가 먼저 말한 것이 아니라 Phase 0 이 조사에서 잡아 제안한 것을 사용자가 고른 것이다.」 · 「그 방향을 어느 파일의 어느 장치로 옮길지는 열려 있다.」"
>   - f: f4
>     verdict: confirm
> added: []
> ```
>
> 판정 근거 요약:
>
> - **f1 confirm** — 번들 `## 사용자 원문` 80–82행에 「이거 덩어리 승인하는과정 내가 보기 어려우니까 개선하자」 가 실려 있다(finding 의 evidence 는 「받은 번들에 이 줄이 없다」고 적었으나 내가 받은 번들에는 있다 — 그 한 구절만 낡았고 결론에는 영향이 없다). 초안 본문 어디에도 덩어리 승인 과정을 가리키는 문장이 없고, `## 덜어 낸 것` 표 열두 줄에도 없다. 프로필의 `omission` 정의에 그대로 맞는다. 제안된 대체문은 사용자 말을 그대로 싣고 범위는 「묻지 않았다」로 열어 두므로 `fix` 처분이 맞다.
> - **f2 · f3 reject** — 둘 다 «(사용자 확인)» 이 붙은 문장이 라운드 3 「고름」 풀이와 글자 단위로 같다. 프로필이 정한 `inference_as_decision` · `unfounded_addition` 판별 기준(「고름」 풀이에 있는가)을 통과하고, 초안이 두 방향 사이의 긴장과 구현 자리를 「다시 검증할 것」에 열어 두었다.
> - **f4 confirm** — 초안 「인터뷰 끝맺음 절차 파일은 이 일, 옆 로드맵의 지휘 절차 에픽, 그리고 … 열린 PR 이 함께 고친다」 는 넘겨받은 글과 맞지 않는다. 넘겨받은 글은 그 파일에 대해 「열린 PR #274 가 … finishing.md 를 고친다」 만 적고, R2 예약 목록(`repo_defaults.py` · `conducting.md` · `conductor-dispatch.md` · `epic-conductor/SKILL.md`)에 끝맺음 파일이 없다. 1차 자료로도 확인했다: `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md` 44행의 경로 예약은 여섯 경로이고 끝맺음 파일이 없으며, 그 로드맵 폴더에서 「finishing」 · 「끝맺음」 은 0건이다. 「이 일」이 그 파일을 고친다는 단정도 초안 자신의 「어느 파일의 어느 장치로 옮길지는 열려 있다」 와 어긋난다. 옆 세션 설계문서 552행(미룸 표)이 출처라는 주장은 그 문서가 다른 세션의 로컬 브랜치에만 있어 확인하지 못했다 — 확정에는 필요하지 않았다.
>
> 확인하지 않은 것: 번들 `## 사용자 결정 문구` 의 "그대로 둔다" 가 어느 지적에 대한 결정인지는 번들에 없어 어느 finding 과도 대조하지 않았다(`contradicts` 를 달 근거 없음).

### 냉독 (seed-readback)

> seed 본문만 읽었고 파일은 하나도 열지 않았다. seed 가 가리키는 기록 파일(audit)의 「긴 초안 절」도 읽지 않았다. 아래는 그 상태에서 내가 이해한 것이다.
>
> ## 무엇을 맡기려는 것으로 읽었는가
>
> 다음 단계(pm-interview)에게, request-framing 과 인터뷰라는 두 앞단 skill 을 「새 코어」에 맞게 고치는 일을 넘기는 글로 읽었다. 새 코어는 옆 세션(지휘 재설계 로드맵을 이끄는 리더 세션)이 세우는 팀 구조다. 고친다는 말은 안 맞는 곳을 개선하고 강화하고 낡은 곳을 손보는 것 셋을 함께 뜻하는 것으로 읽었다.
>
> 다만 읽어 내려가면서 일의 범위가 첫 문장보다 넓어졌다. 내가 이 일에 든다고 읽은 것은 넷이다.
>
> - **앞단 고치기** — request-framing 과 인터뷰를 새 코어에 맞춘다.
> - **이름 바꾸기** — 인터뷰를 「의도 싱크」로 바꾼다. 옆 세션이 자기 로드맵에 넣지 않고 이 일로 넘겼다. 호출 이름이라 별칭 없이 한 번에 바꾸고 major 판을 올린다.
> - **철학 문서** — 레포에 치우친 쪽보다 표준에 맞는 쪽으로, 더하기보다 푸는 쪽으로 고친다.
> - **플러그인 저술 가이드** — 표준과 새 코어 두 방향을 함께 적용하고 낡은 내용을 고친다.
>
> seed 리뷰 중의 덩어리 승인 과정을 보기 쉽게 고치자는 말도 이 일 근처에 놓여 있다고 읽었다.
>
> 다음 단계가 실제로 할 일은 구현이 아니라고 읽었다. 사용자가 고른 방향을 어느 파일의 어느 장치로 옮길지 정하고, 마지막 문단에 쌓인 「묻지 않았다 · 정하지 않았다」 항목을 사용자와 풀어 가는 것으로 읽었다.
>
> ## 방향이 무엇으로 읽혔는가
>
> 사용자가 고른 방향 넷은 이렇게 읽었다.
>
> 1. 사용자가 붙여 넣은 글과 직접 쓴 말을 파일로 그대로 보존한다. 「사용자 원문」 자리에는 seed 가 아니라 그 원자료가 들어간다.
> 2. 앞단이 끝나면 작은 일도 리더로 넘긴다. 넘김 글은 짧게 쓰고 자세한 지시는 파일 경로로 가리킨다.
> 3. 앞단 skill 글에서 이유와 이력 설명, 낡은 서술, 옛 설계 번호를 걷어내 읽는 양을 줄인다.
> 4. 작은 일에서는 필수 조사와 리뷰 일부를 모델이 이유를 적고 건너뛸 수 있게 한다.
>
> 이 넷은 사용자가 먼저 꺼낸 것이 아니라 Phase 0 이 조사해서 제안한 것을 사용자가 고른 것이라고 읽었다. 사용자는 자기가 말하지 않은 문제도 잡아내 제안해 달라고 했다.
>
> 전체의 결은 「더하지 말고 풀어라, 줄여라, 원문을 건드리지 마라」로 읽혔다. Claude Code 공식 자료는 따라야 할 기준이 아니라 참고 내용으로 둔다. 외부 작업 방식 관례와 일반 개발 관례는 사용자가 고르지 않았다.
>
> 일하는 방식에 대한 지시는 셋으로 읽었다.
>
> - 다시 조사하기 전에 기록 파일의 긴 초안 절부터 읽는다.
> - 옆 세션의 설계문서는 메시지 요약을 믿지 말고 문서를 다시 읽는다. 다른 에픽의 묶음과 로드맵 파일도 함께 읽는다.
> - 옆 세션의 원자료 대조표는 로드맵 폴더에 올라오기 전에는 경로로 가리키지 않는다.
>
> ## 보낸 사람이 무엇을 신경 쓰는 것으로 읽혔는가
>
> **사용자의 말이 단계를 지나며 바뀌는 것.** 가장 강하게 읽혔다. 사용자의 「내 의도가 interview지나면서 의역된거 같아서 그래」 가 그대로 인용돼 있고, 방향 1 이 바로 그 문제를 겨눈다. seed 스스로도 사용자 말은 낫표로 그대로 옮기고 풀이는 따로 적었다.
>
> **무엇이 누구의 말인지 가르는 것.** 문장마다 출처를 구분하려 했다. 내가 읽어 낸 구분은 여섯이다.
>
> - 사용자 확인
> - Phase 0 의 읽기
> - Phase 0 이 파일을 열어 확인한 것
> - 조사 agent 의 보고만 받은 것
> - 옆 세션이 측정했고 Phase 0 이 다시 재지 않은 것
> - 코드를 읽었으나 돌려 보지 않은 것
>
> 묻지 않은 것은 묻지 않았다고 적었다. 다음 단계가 Phase 0 의 읽기를 사용자 확정으로 받아들이지 않기를 바라는 것으로 읽혔다.
>
> **옆 세션과의 충돌.** 같은 파일을 여럿이 건드린다는 점을 신경 쓴다. 내가 읽은 겹침은 넷이다.
>
> - 인터뷰 끝맺음 절차 파일은 열린 PR 이 고치고 있다.
> - 철학 문서와 CLAUDE.md 는 옆 로드맵의 지휘 절차 에픽이 P8 을 고치려고 예약했다.
> - 이름 바꾸기가 닿는 설정 키 파일, 로드맵 스크립트, 넘김 글 파일은 옆 로드맵의 에픽들이 예약했다.
> - 리더 사이 편지함이 아직 없어 순서 조율은 세션 메시지나 사용자를 거친다.
>
> **새 코어가 아직 움직이는 표적이라는 것.** 새 코어를 가장 자세히 적은 설계문서는 리뷰와 승인 전이고, 로컬 브랜치에만 있고, 회의 중에도 한 번 바뀌었다.
>
> **사용자가 직접 그은 선 둘.** 이 일은 치우침 정리가 아니라는 것, 옆 세션을 잘 이해해야 한다는 것.
>
> ## 읽으면서 «이건 모르겠다» 싶었던 곳
>
> **용어와 지칭**
>
> - 「새 코어」가 구체적으로 어떤 구조인지 모른다. 리더, 팀 파일 규약, 과제 파일, 의도 폴더, 편지함 같은 낱말에서 윤곽만 짐작했다. 그래서 앞단이 그것과 「안 맞는다」가 어떤 모양인지도 스스로 그리지 못했다.
> - 「앞단」은 request-framing 과 인터뷰를 묶은 말로, 「Phase 0」은 이 seed 를 쓴 request-framing 단계로 읽었다. 둘 다 내 짐작이다.
> - 「이 회의」가 어느 회의인지 모른다.
> - 「그 로드맵의 이전 에픽」에서 「이전」이 앞선 에픽인지 옮기는(移轉) 에픽인지 모른다.
> - 「그 에픽의 경로 예약에는 이 파일이 없다」의 「이 파일」은 인터뷰 끝맺음 절차 파일로 읽었다. 「분해 승인 화면」이 그 파일에 사는 것인지는 문장만으로 확신하지 못했다.
> - 설정 키 파일, 넘김 글 파일, 설계문서 머리 키가 각각 어느 파일과 어느 키인지 모른다. major 판을 올리는 플러그인이 어느 것인지도 모른다.
>
> **범위**
>
> - 첫 문장의 목적은 request-framing 과 인터뷰 둘뿐이다. 철학 문서와 저술 가이드는 뒤에서 들어온다. 이 둘이 같은 일의 정식 범위인지, 사용자의 첫 요청(「조사부터」)에서 딸려 온 것인지 모른다.
> - 사용자의 첫 요청은 「조사부터」였다. 지금은 조사가 끝나 고치는 단계로 넘어간 것인지 모른다.
> - 사용자는 「치우침 정리가 아니다」라고 했는데, 철학 문서에 대해서는 「레포에 바이어스 되게 보다 표준에 맞게」라고 했다. 「치우침 정리」가 무엇을 가리키는 이름인지 몰라서 두 말이 서로 어떤 관계인지 모른다.
> - 「덩어리 승인하는과정 … 개선하자」가 다섯째 방향인지, 이 일의 범위인지, 별개의 메모인지 모른다. 방향 넷 문단 끝에 놓여 있고 「(사용자 확인)」이 붙지 않았다. 「편집 덩어리 넷을 처분」이 어떤 화면에서 어떤 일을 한 것인지도 그려지지 않았다.
> - 앞단이 의도 폴더에 바로 쓰게 하는 일을 이 일이 맡는지 모른다. seed 도 묻지 않았다고 적었다.
>
> **문장 뜻**
>
> - 「지금은 그 파일을 앞단의 기록에서 옮겨 적은 사본으로 만든다」의 뜻을 모른다. 옆 세션이 지금 그렇게 하고 있다는 현황인지, 이 일이 그렇게 하겠다는 것인지, 고쳐야 할 문제로 든 것인지 가르지 못했다. 방향 1(원자료를 파일로 그대로 둠)과 같은 것인지 다른 것인지도 모른다.
> - 「넘김 글 한 줄에 레포 원칙과 사용자가 하지 않은 사용자 선호 라벨이 들어 있다」는 사용자가 하지 않은 말에 「사용자 선호」 딱지가 붙어 있다는 뜻으로 읽었다. 확신은 없다.
> - 「인터뷰 결과물 리뷰 기준이 레포 원칙을 깎는 잣대로 쓴다」는 레포 원칙을 잣대 삼아 무언가를 깎는다는 것인지, 레포 원칙 자체를 깎는다는 것인지 모른다.
> - 「superpowers 가 없으면 끝 게이트가 없다」의 끝 게이트가 무엇인지 모른다.
> - 「작은 일」을 무엇으로 가르는지 모른다.
>
> **표기**
>
> - 「(사용자 확인)」은 바로 앞 문장에 붙는 것으로 읽었다. 그러면 사용자의 말을 전하면서 표시가 없는 문장이 남는다. 「치우침 정리가 아니라고 했고」, 「제안해 달라고 했다」가 그렇다. 이 문장들이 확인된 것인지 급이 다른 것인지 모른다.
>
> **seed 가 스스로 열어 둔 것**
>
> 아래는 seed 가 열려 있다고 적은 것이고, 나도 답을 모른다.
>
> - 원자료 파일이 정본이 되면 seed 는 무슨 일을 맡는가.
> - seed 문법을 풀 것인가.
> - 표준에 맞춘다는 말과 공식 자료를 참고로만 둔다는 말은 어떻게 함께 가는가.
> - 철학 문서를 어디까지 고치는가.
> - 철학 문서와 CLAUDE.md 를 옆 로드맵의 지휘 절차 에픽과 어떻게 나누는가.
> - 작은 일의 가벼운 길과 「작은 일도 리더를 거친다」는 어떻게 함께 가는가.
> - 새 이름은 무엇인가.
> - 옛 기록을 옮기는가.
> - request-framing 이라는 이름도 바꾸는가.
> - 사용자가 물은 「폴더 이름」은 어느 폴더인가.
> - 「의역된 것 같다」는 말이 이 일의 계기인가.

## 5. degrade

이 단계에는 degrade 원장이 없다(no-state-in-phase-0) — 아래는 게이트 앞 글에 실은 것을 같은 내용으로 남긴 것이다.

- codex · suppression · degraded — 1라운드는 codex 없이 돌았다. codex 계정의 사용량 한도(16시 38분 이후 다시 가능)로 호출 2번이 실패했다. 2 · 3라운드는 codex 가 돌았다. codex 호출은 모두 4번이다.
- pipeline · suppression · degraded — 탐지 · 재비판 리뷰어에게 리뷰 묶음을 내용이 아니라 파일 경로로 넘겼다(세 라운드 모두). 절차는 내용을 싣게 돼 있다. 묶음이 3만 6천 글자 남짓이라 옮겨 적다 글자가 틀어질 위험을 피했다. 리뷰어는 매번 파일을 끝까지 읽었다고 보고했다.
- pipeline · suppression · degraded — 3라운드의 재비판 묶음을 라운드 도중 다시 조립했다. 라운드 시작 뒤 사용자 말 한 줄이 원문 절에 더해졌기 때문이다. seed 본문은 그대로였다.
- pipeline · all · degraded — 리뷰 엔진은 3라운드의 지적 2건(63982916#r3.1 · 3720b2b7#r3.2)을 「아직 안 고친 곳」으로 센 채 끝났다. 사용자가 추가 라운드를 열지 않기로 해서 엔진이 반영을 관측하지 못했다. 두 건은 seed 에 반영했고, 반영한 문장은 확정 직전 덩어리 셋으로 사용자에게 보여 「그대로 둔다」를 받았다.
- pipeline · all · degraded — 편집 덩어리를 2라운드 뒤에는 절차대로 문단 전체로, 그 뒤로는 달라진 문장만 뽑아 보였다. 사용자가 「이거 덩어리 승인하는과정 내가 보기 어려우니까 개선하자」고 해서다. 절차는 덩어리 본문을 줄이지 말고 싣게 돼 있다.
- 워크트리 — 만들었다(`feature/framing-interview-constraint-audit`).

## 6. 리뷰 결정

- 편집 · r2 · 덩어리 1 · 그대로 둔다 · "그대로 둔다" —

- 편집 · r2 · 덩어리 2 · 그대로 둔다 · "그대로 둔다" —

- 편집 · r2 · 덩어리 3 · 그대로 둔다 · "그대로 둔다" —

- 편집 · r2 · 덩어리 4 · 그대로 둔다 · "그대로 둔다" —

- 편집 · r3 · 덩어리 1 · 그대로 둔다 · "그대로 둔다" —

- 편집 · r3 · 덩어리 2 · 그대로 둔다 · "그대로 둔다" —
- docreview 계수 — spec-distill-59ec298a/2026-11-14-framing-interview-constraint--199af10b31ba2c4c r1: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-11-14-framing-interview-constraint--199af10b31ba2c4c r2: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-11-14-framing-interview-constraint--199af10b31ba2c4c r3: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0

- 편집 · r3 · 확정 직전 덩어리 1 · 그대로 둔다 · "그대로 둔다" —

- 편집 · r3 · 확정 직전 덩어리 2 · 그대로 둔다 · "그대로 둔다" —

- 편집 · r3 · 확정 직전 덩어리 3 · 그대로 둔다 · "그대로 둔다" —
