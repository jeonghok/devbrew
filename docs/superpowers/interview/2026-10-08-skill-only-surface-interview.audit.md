---
type: interview-audit
payload: 2026-10-08-skill-only-surface-interview.md
created_at: 2026-10-08
session_id: 66d456cd-0cd7-4277-8466-2811dc3a60f9
source: spec-distill conducting-interview v0.57.0
---

# Skill-Only Command Surface — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — 재구성 동의 S2 와 그 실패 조건 확인 S3(명령이 skill 로 제대로 안 이어짐) (@S2)
- floor:landscape — closed — 외부 근거 처분: commands→skills 수렴 방향을 취함 (@S4)
- floor:skepticism — closed — steelman ST1 판정 보완 (@S5)
- floor:blind_spot — closed — premortem 위험 넷 전부 설계 필수로 처분 (@S6)
- floor:open_questions — closed — OQ9~OQ17 목록 확인 (@S9)
- derived:name_resolution — closed — bare 이름은 충돌에 지는 조건부 표면이고 사용자는 짧은 이름을 친다; 짧은 명령형 + 일반어 단독 금지 + 기계 안내는 완전명 (@S7)
- derived:entrypoint_preflight_ownership — closed — 사전 단계 소유가 플러그인마다 다름(RC1·RC2·RC3); 기능당 skill 하나, 사전 단계는 그 안 (@S4)
- derived:handoff_emitters_cwd — closed — 핸드오프 발신자에 hook·스크립트(RC10), /new 뒤 cwd 미측정(RC11); @ 대화형 재현과 전환 잔재를 설계 필수로 (@S6)
- derived:removal_blast_radius — closed — 테스트 핀 107곳(RC13)과 즉시 제거 선례의 조건(RC9); 범위·조건은 S5, 전환 잔재·qg 면제는 S6 (@S5)
- derived:silent_ignore_and_lock_target — closed — 인식 안 되는 frontmatter 키(RC6)와 공식 검사기의 몫; 표면 정합 락 (@S8)
- derived:internal_research — closed — 내부(레포) 조사 축; coverage-mapper·steelman·prober 의 레포 주장 28건 V1 확인 후 처분 (@S6)

## 2. Budget

- 질문 라운드: 8 · agent dispatch: 3 · coverage-mapper 1 · codex 실호출: 0 (성공 0)

## 3. Steelman 원문

#### ST1 — alias 없는 즉시 제거를 skill 단일화 개편 전체에 적용하는가

**dispatch 입력** — goal: S1(seed 첫 문장 «devbrew 가 사용자에게 내놓는 호출 표면 전체를 전수 점검해 한 체계로 통일하는 일을 맡기고 싶다 …») · 전제: P1 부르는 모양마다 도는 것이 달라 예측할 수 없다(S2·S3) · P2 기능당 skill 하나로 수렴, 사전 단계는 그 안, 명령 파일 제거(S4) · P3 짧은 이름으로 친다(S1) · P4 alias 없이 즉시 제거 + major(S1) · P5 실사용자는 저장소 주인 한 명, 제3자 설치 없음(orchestrator 도출) · P6 락으로 집행(S1) · P7 kill switch 이름은 이미 하나로 살아 있다(orchestrator 도출; RC9) · 제약: S1–S4 원문 전량 · trigger: clig.dev 와의 landscape 모순 · CLAUDE.md 창 규칙과 plugin-audit 선례 조건과의 충돌 · S4 로 인한 범위 증폭(kill switch 조용한 재활성 포함)

> ```yaml
> case_for_alternative:
>   statement: "명령·skill «이름»은 alias 없이 즉시 제거하고 major bump 한다. 단 이번 사이클의 적용 범위는 quality-gates 를 뺀 네 플러그인의 명령 4개(project-init · interview · request-framing · plugin-audit)로 한정한다. kill switch·환경변수·DEVBREW_SKIP_HOOKS 토큰은 S4 개편의 rename 대상에서 뺀다. 은퇴가 불가피하면 review_entry.py 식 loud 은퇴 공시를 남긴다(alias 는 아니다). CLAUDE.md 개정은 「즉시 제거 허용」을 조건 없이 쓰지 않고 조건부 규칙으로 쓴다: ① 호출 이름은 실패가 loud 하므로 허용한다 ② 끄는 스위치의 은퇴에는 공시가 필수다 ③ 제3자 설치가 확인되면 창을 복원한다."
>   strongest: "goal 은 표면을 «한 체계로 통일»하고 stale 참조를 정리하는 일이다. 그런데 사용자 제약 «quality-gates 파일은 이 작업에서 고치지 않는다»가 걸린다. 이 아래서 «전체에 한 번에»를 적용하면 qg 명령 3개를 지우거나(제약 위반) 남겨야 한다. 남기면 고칠 수 없는 qg 훅이 계속 `/cancel-qg`·`/qg --reset` 을 안내한다(RC25). 지우면 그 안내가 곧바로 stale 핸드오프가 되고, 이것은 바로 S3 증상이다. 그래서 범위는 qg 를 빼고 잘라야 정합이 맞는다. 실패 모양도 표면마다 다르다. slash 명령을 지우면 사용자가 친 순간 «Unknown slash command» 로 loud 하게 실패한다. 반면 kill switch 이름이 바뀌면 옛 이름으로 꺼 둔 기능이 아무 소리 없이 다시 켜진다. 헌장이 kill switch 를 보안 컨트롤로 규정하므로, 같은 «즉시 제거» 규칙을 두 표면에 똑같이 적용하는 것은 goal 의 «체계 통일»이 아니라 위험 등급을 뭉개는 일이다. CLAUDE.md 를 무조건 허용으로 바꾸면 선례 5건이 모두 붙여 둔 «제3자 설치가 생기면 창을 둔다» 조건이 규칙에서 사라진다(RC22·RC23)."
> case_for_current:
>   strongest: "S2 가 이름 붙인 병은 «한 기능에 진입 층이 둘»이다. alias 나 fallback 명령은 정의상 두 번째 진입 층이다. 그래서 alias 를 남기면 P1 이 고치려는 예측 불가능성이 그대로 재생산된다. 즉시 제거만이 «부르는 모양 하나 = 도는 것 하나»를 이번 브랜치 안에서 성립시킨다. 플랫폼도 같은 방향이다. Claude Code 는 commands 를 skills 로 병합했고, 자기 /vim 명령을 alias 없이 패치 릴리스에서 지웠다. 그때 관찰된 피해는 «문서가 옛 이름을 가리킨 것»이었고, 이것은 P6 의 락이 정면으로 잡는 종류다. 제거된 명령은 친 순간 loud 하게 실패하므로 조용한 오작동이 없다. 실사용자는 이 변경을 직접 결정한 한 명이다(GitHub 공개·star 0·fork 0·watcher 0, 2026-10-08 확인). 그러므로 deprecation 창이 보호할 대상이 없고, 창을 두면 두 릴리스와 중간 상태 테스트 비용만 생긴다(qg 설계가 같은 이유로 창을 기각했다, RC27). kill switch 이름은 이미 `DEVBREW_<PLUGIN>_…` 하나로 통일돼 있어(RC28) S4 가 그것을 바꿀 필요 자체가 없다."
> premise_refutation:
>   hits: []
> premise_list_challenge: "결함 셋이다. (1) 빠진 전제가 있다: «quality-gates 는 이번 사이클에서 편집하지 않는다»(S1 원문 제약). 이 제약 때문에 방향의 «명령 7개 전부를 한 번에»는 성립하지 않는다. 이번에 지울 수 있는 명령은 qg 밖의 4개뿐이다. qg 명령 3개(qg · qg-publish · cancel-qg)와 그것을 이름으로 안내하는 qg 훅(RC25)은 qg v10 후속 과제로 점검 보고에 올라가야 한다. P2 는 최종 상태 규칙으로는 반증되지 않는다. 다만 이 브랜치의 적용 범위를 제한하는 전제가 목록에 없다. (2) P5 는 단정형으로 쓰여 있다. 그런데 리포 자신의 기록(RC23)은 «이것은 설치가 없다는 증명이 아니다 — PUBLIC 리포는 누구든 마켓플레이스로 추가할 수 있다»라고 적는다. P5 는 «확인된 제3자 설치 없음(공개 리포라 부재 증명 불가)»으로 고쳐 써야 한다. 그리고 그 조건이 CLAUDE.md 개정 문안에 남아야 한다. 무조건 허용으로 바꾸면 선례들이 붙인 조건이 규칙에서 소실된다. (3) P7 자체는 참이다(RC28). 다만 빠진 짝이 있다. 일부 스위치 이름은 skill·모드 이름에 묶여 있다(`DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE` · `DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW` · `DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE` 등). S4 가 skill 을 합치거나 이름을 바꾸면 이 스위치들까지 «통일» 명목으로 끌려갈 수 있다. 그래서 «kill switch 이름은 이번 개편에서 바꾸지 않는다»가 명시 전제로 있어야 trigger (3)의 조용한 재활성 위험이 닫힌다. 그리고 deprecation 창을 유지하는 경로는 S1 이 이미 닫았으므로 대안으로 내지 않았다."
> recommendation: refined
> refined_takes: "명령·slash skill 이름에 대해서는 원안을 그대로 취한다. alias·fallback 명령 없이 즉시 제거하고 major bump 한다. 명령 파일을 없애고 기능당 skill 하나로 수렴한다(S4). stale 핸드오프·문서·테스트 핀은 P6 락으로 같은 브랜치에서 정리한다. CLAUDE.md 의 one-minor 창 규칙도 개정한다."
> refined_drops: "«devbrew 사용자 호출 표면 전체에 한 번에»를 버린다. 범위는 quality-gates 밖 명령 4개로 하고, qg 명령 3개와 qg 훅 안내는 후속 과제로 넘긴다. «kill switch 등 표면 이름»까지 즉시 제거 규칙에 묶는 것도 버린다. kill switch·환경변수·SKIP_HOOKS 토큰은 rename 대상에서 빼고, 은퇴가 불가피하면 review_entry.py 식 은퇴 공시를 필수로 둔다(alias 아님). CLAUDE.md 를 조건 없이 «즉시 제거 허용»으로 바꾸는 문안도 버린다. 대신 «제3자 설치가 확인되기 전까지·호출 이름에 한해·스위치 은퇴는 공시 필수» 조건을 규칙 문장 안에 남긴다."
> evidence:
>   - url: "https://semver.org/"
>     supports: alternative
>     claim: "SemVer FAQ: 공개 API 를 deprecate 할 때는 문서를 갱신하고 deprecation 을 담은 minor 릴리스를 낸다. 완전 제거하는 major 전에 그런 minor 가 최소 하나 있어야 한다(CLAUDE.md one-minor 창의 출처 관행)."
>     touches: [P4]
>     decides: [OQ4]
>   - url: "https://clig.dev/"
>     supports: alternative
>     claim: "«Warn before you make a non-additive change», «interfaces don't change without a lengthy and well-documented deprecation process». alias 는 «should be explicit and remain stable»(alias 를 만든다면 안정적이어야 한다는 것이지 alias 를 만들라는 요구는 아니다)."
>     touches: [P4]
>     decides: [OQ4]
>   - url: "https://code.claude.com/docs/en/skills"
>     supports: current
>     claim: "«Custom commands have been merged into skills» — commands 파일과 skill 은 같은 /name 을 만들고 동작이 같다. 같은 이름이면 skill 이 이긴다. 플러그인 skill 은 /plugin-name:skill-name 으로 네임스페이스된다. 즉 명령 파일 층은 플랫폼에서 이미 skill 의 중복 진입로다."
>     touches: [P2]
>     decides: [OQ4]
>   - url: "https://claudeissues.com/issue/43370-docs-vim-mode-docs-still-reference-removed-vim-command"
>     supports: current
>     claim: "Claude Code v2.1.92 가 /vim 명령을 alias 없이 제거했다(«Removed /vim command (toggle vim mode via /config → Editor mode)», 이슈가 인용한 changelog 문구). 관찰된 피해는 문서가 옛 명령을 가리킨 것이었다. 벤더가 slash 표면에 창 없는 제거를 쓰고, 남는 위험은 stale 문서라는 근거다(공식 changelog 직접 확인은 못 했다)."
>     touches: [P4, P6]
>     decides: [OQ4]
>   - url: "https://claudeissues.com/issue/9235-bug-unknown-slash-command-plugin"
>     supports: current
>     claim: "존재하지 않는 slash 명령을 치면 Claude Code 는 «Unknown slash command: <name>» 을 낸다. 제거된 명령의 실패는 사용자에게 loud 하게 보이고 조용히 다른 것이 돌지 않는다(이 이슈는 /plugin 사례이고, 메시지 형태의 근거로만 쓴다)."
>     touches: [P4]
>     decides: [OQ4]
>   - url: "https://github.com/jeonghok/devbrew"
>     supports: both
>     claim: "리포는 public 이고 star 0 · fork 0 · watcher 0 이다(2026-10-08 조회). 제3자 사용 신호가 없다는 것은 P5 와 부합한다. 그러나 public 이라 마켓플레이스 추가를 막지 못하므로 부재 증명은 아니다."
>     touches: [P5]
>     decides: [OQ4]
> repo_claims:
>   - id: RC21
>     path: "CLAUDE.md"
>     anchor: "제거 전 one-minor deprecation window."
>     line: 36
>     claim: "창 규칙은 «v1.0.0 이상이면 CHANGELOG.md» 항목 안에 있다. 대상 명령 중 spec-distill(4.5.3)·project-init(4.0.2)는 v1.0.0 이상이라 구속되고, plugin-audit(0.10.0)는 문턱 아래다. 개정이 실제로 필요한 플러그인은 앞의 둘(그리고 후속의 qg 9.3.6)이다."
>     touches: [P4]
>     decides: [OQ4]
>   - id: RC22
>     path: "plugins/plugin-audit/README.md"
>     anchor: "옛 이름은 **fallback 없이 즉시 제거**됐다"
>     line: 42
>     claim: "즉시 제거 선례의 근거는 «현재 제3자 설치가 없다» 하나다. «제3자 설치가 생기면 이 근거가 바뀐다 — 그때는 다음 rename에 fallback 창을 둔다»는 조건이 붙어 있다. 조건 없는 CLAUDE.md 개정은 이 조건을 규칙에서 지운다."
>     touches: [P4, P5]
>     decides: [OQ4]
>   - id: RC23
>     path: "plugins/spec-distill/CHANGELOG.md"
>     anchor: "**이것은 설치가 없다는 증명이 아니다** — PUBLIC 리포는 누구든 마켓플레이스로 추가할 수 있다."
>     line: 652
>     claim: "리포 자신이 «제3자 설치 없음»을 부재 증명이 아닌 조건부 판단으로 기록했다. P5 의 단정형 서술은 이 기록보다 강하다."
>     touches: [P5]
>     decides: [OQ4]
>   - id: RC24
>     path: "plugins/spec-distill/scripts/review_entry.py"
>     anchor: "def retired_advisories"
>     line: 53
>     claim: "은퇴한 SKIP_HOOKS 토큰과 환경변수를 alias 로 살리지 않는다. 대신 설정돼 있으면 «아무것도 끄지 않는다 / 대체 스위치는 X» 를 loud 하게 공시하는 패턴이 이미 있다. kill switch 은퇴의 조용한 재활성 위험을 alias 없이 닫는 리포 내 선례다."
>     touches: [P7]
>     decides: [OQ4]
>   - id: RC25
>     path: "plugins/quality-gates/hooks/session-start-advisor.py"
>     anchor: "Run `/cancel-qg` to clear before invoking"
>     line: 183
>     claim: "qg 의 SessionStart 훅이 `/cancel-qg`·`/qg --reset`·`/qg` 를 이름으로 안내한다. 사용자 제약상 quality-gates 파일은 이번에 고칠 수 없다. 따라서 qg 명령을 이 브랜치에서 지우면 고칠 수 없는 stale 핸드오프가 생긴다. «전체에 한 번에» 적용은 이 제약과 양립하지 않는다."
>     touches: [P2]
>     decides: [OQ4]
>   - id: RC26
>     path: "plugins/spec-distill/commands/interview.md"
>     anchor: "`DEVBREW_SPEC_DISTILL_DISABLE=1` — 모든 spec-distill 동작 abort."
>     line: 17
>     claim: "명령 파일이 kill switch 검사를 갖고 있다. 같은 검사가 plugins/spec-distill/skills/conducting-interview/SKILL.md:448 과 framing-requests/SKILL.md:1084 에도 있다. 그래서 interview 명령 파일을 지워도 이 스위치가 꺼지지 않는다. S4 의 «kill switch 를 skill 안으로»는 이 플러그인에서 이미 충족돼 있다."
>     touches: [P2, P7]
>     decides: [OQ4]
>   - id: RC27
>     path: "docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md"
>     anchor: "#### 6.5.2 deprecation — 친절한 오류로 바로 major"
>     line: 633
>     claim: "리포 선례: 별도 deprecation 릴리스 없이 major 로 제거한다. 다만 제거된 «인자»를 받으면 한 줄 공시 후 진행해 «조용히 무시» 경로를 막는다. 창을 기각한 이유는 «릴리스 둘 + 중간 상태 테스트 비용»이다."
>     touches: [P4]
>     decides: [OQ4]
>   - id: RC28
>     path: "plugins/plugin-audit/README.md"
>     anchor: "| `DEVBREW_DISABLE_PLUGIN_AUDIT` | `DEVBREW_PLUGIN_AUDIT_DISABLE` |"
>     line: 37
>     claim: "CHANGELOG 를 뺀 plugins/ 전체에서 옛 어순(`DEVBREW_DISABLE_*`·`DEVBREW_STALENESS_*`)이 남은 곳은 이 rename 표 4줄뿐이다. P7 의 서술과 일치한다."
>     touches: [P7]
>     decides: [OQ4]
> ```
>
> 결론: 근거 중 어느 것도 P1~P7 문장과 직접 충돌하지 않습니다(`hits: []`). 그래서 `switched` 는 내지 않았고 `refined` 를 추천합니다.
>
> - **원안에서 취하는 것:** 명령·skill 이름은 alias 없이 즉시 제거하고 major bump 합니다.
> - **원안에서 버리는 것:**
>   - «전체를 한 번에»는 버립니다. 바꿀 수 없는 qg 훅(RC25)과 qg 편집 금지 제약 때문에, 이번 범위는 qg 밖 명령 4개로 줄입니다.
>   - kill switch rename 은 이번 범위에서 뺍니다. 스위치를 은퇴시켜야 하면 RC24 식 공시를 남깁니다.
>   - CLAUDE.md 개정 문안에는 «제3자 설치가 확인되기 전까지» 조건을 남깁니다.
>
> RC 번호(RC21~RC28)는 임시값입니다. orchestrator 가 이미 쓴 RC9 와 겹치지 않도록 21번부터 매겼습니다.

**게이트-전 확인** — repo_claims(임시 번호 → 인터뷰 번호): CLAUDE.md#제거 전 one-minor deprecation window.(→RC14) 확인 · plugins/plugin-audit/README.md#옛 이름은 fallback 없이 즉시 제거(→RC15) 확인 · plugins/spec-distill/CHANGELOG.md#이것은 설치가 없다는 증명이 아니다(→RC16) 확인 · plugins/spec-distill/scripts/review_entry.py#def retired_advisories(→RC17) 확인 · plugins/quality-gates/hooks/session-start-advisor.py#Run `/cancel-qg` to clear before invoking(→RC18) 확인 · plugins/spec-distill/commands/interview.md#DEVBREW_SPEC_DISTILL_DISABLE=1(→RC19) 확인 · docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#6.5.2 deprecation(→RC20) 확인 · plugins/plugin-audit/README.md#rename 표(→RC21) 확인 · 부착 주장: semver → P4 확인 · clig → P4 확인 · cc-skills → P2 확인 · vim-removal → P4·P6 확인 · unknown-slash → P4 확인 · github-devbrew → P5 확인 · 재검토 자격: 사유 없음(확인된 전제 충돌 0건)

**사용자 선택** — 보완 (S5)

## 4. 게이트 실행 기록

- check_brief.py gate — fail (2026-10-08) — web: enabled — §4 인용 괄호 «…» 가 출처키로 읽힘 → 「…」 로 교체
- check_brief.py gate — pass (2026-10-08) — web: enabled
- check_verbatim_coverage.py — exit 3 (2026-10-08) — state user_statements flow 형식 판독 불가 → block 형식으로 교체
- check_verbatim_coverage.py — exit 0 (2026-10-08)
- V2 누락 대조 — 차집합 없음 (2026-10-08)

## 5. 프로세스 로그

- R1 전: coverage-mapper #1 dispatch — derived 6 제안 중 5 admit(«--reset vs /cancel-qg 의미 동형성»은 qg 보고 전용이라 결정 차원에서 제외하고 OQ17 로 흡수) · internal_research admit · repo_claims RC1~RC13 V1
- seed provenance 분류: user_confirmed 14 · user_unconfirmed 0 · author 32 (audit ok)
- round 1: (a)+(d) — 레포 확인 사실 13건과 외부 근거를 싣고 진짜 문제 재구성을 물음 → S2
- round 2: (b) — 이유 없는 추천 수락이라 되묻기(실제 사례) → S3 · root_problem closed
- round 3: (b) — landscape 처분(commands→skills 수렴) → S4 · landscape closed
- round 4: steelman ST1 게이트 → S5 · skepticism closed
- round 5: (b) — blind-spot-prober premortem 처분 → S6 · blind_spot closed
- round 6: (b) — 이름 규칙 → S7
- round 7: (b) — 락 범위(seed 가 다시 묻기로 한 질문) → S8
- round 8: (b) — Open Questions 확인 → S9 · open_questions closed
- landscape sweep: code.claude.com/docs/en/skills WebFetch(orchestrator) + coverage-mapper·steelman·prober 의 웹 근거
- 확인 RC1 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#Step P2 — Setup state. — 주장과 일치 (P1 kill switch · P2 setup-qg --ensure · ## Trivia escape 의 check-trivia.sh 를 skill 이 자체 수행)
- 확인 RC2 — 확인 — plugins/spec-distill/skills/framing-requests/SKILL.md#진입 선결조건 — 주장과 일치 (검사는 command 가 한다 · user-invocable:false 없음)
- 확인 RC3 — 확인 — plugins/spec-distill/skills/conducting-interview/SKILL.md#user-invocable: false — 주장과 일치 (reviewing-brief 도 같음)
- 확인 RC4 — 확인 — plugins/quality-gates/commands/qg.md#Special argument: `--reset` — 주장과 일치 (-n SID 만; cancel-qg-core.sh 45행 패턴 가드 · 62행 KEEP_WORKTREE 미경유)
- 확인 RC5 — 확인 — plugins/quality-gates/commands/cancel-qg.md#description — 주장과 일치 (v1.32.0 vs plugin.json 9.3.6; quality-pipeline 제목 v9.3.5)
- 확인 RC6 — 확인 — plugins/quality-gates/commands/cancel-qg.md#hide-from-slash-command-tool — 주장과 일치 (plugins/ 내 유일 사용처)
- 확인 RC7 — 확인 — plugins/project-init/commands/project-init.md#description — 주장과 일치 (argument-hint 없음 · 230줄 · skills/ 없음 · 끝줄 /commit 안내)
- 확인 RC8 — 확인 — plugins/quality-gates/README.md#사용 — 주장과 일치 (사용법 / Quick start / 사용 / 사용 · 사용 블록에 /qg-publish 없음)
- 확인 RC9 — 확인 — plugins/plugin-audit/README.md#옛 이름은 fallback 없이 즉시 제거 — 주장과 일치 (옛 어순은 CHANGELOG · rename 표 · 옛 plan/spec 에만; plugins · shared 코드·테스트엔 0)
- 확인 RC10 — 확인 — plugins/quality-gates/hooks/session-start-advisor.py#/cancel-qg guidance — 주장과 일치 (setup-qg.sh 121 · 185 · 322 도 /cancel-qg 안내)
- 확인 RC11 — 확인 — plugins/spec-distill/skills/framing-requests/SKILL.md#그 디렉토리에서 열어야 — 주장과 일치 (890행 대화형 미측정)
- 확인 RC12 — 확인 — plugins/spec-distill/skills/reviewing-spec/SKILL.md#/spec-distill:reviewing-spec <경로> — 주장과 일치 (commands/ 는 interview · request-framing 뿐)
- 확인 RC13 — 확인 — plugins/spec-distill/tests/test_seed_at_path_handoff.sh#seed @경로 핸드오프 — 주장과 일치 (25 files 107 hits 재현)
- 확인 RC14 — 확인 — CLAUDE.md#제거 전 one-minor deprecation window. — 주장과 일치 (v1.0.0 이상 CHANGELOG 항목 안)
- 확인 RC15 — 확인 — plugins/plugin-audit/README.md#옛 이름은 fallback 없이 즉시 제거 — 주장과 일치 (RC9 와 같은 자리)
- 확인 RC16 — 확인 — plugins/spec-distill/CHANGELOG.md#이것은 설치가 없다는 증명이 아니다 — 주장과 일치 (652행)
- 확인 RC17 — 확인 — plugins/spec-distill/scripts/review_entry.py#def retired_advisories — 주장과 일치
- 확인 RC18 — 확인 — plugins/quality-gates/hooks/session-start-advisor.py#Run `/cancel-qg` to clear before invoking — 주장과 일치 (183행)
- 확인 RC19 — 확인 — plugins/spec-distill/commands/interview.md#DEVBREW_SPEC_DISTILL_DISABLE=1 — 주장과 일치 (conducting-interview 448 · framing-requests 1084 에도)
- 확인 RC20 — 확인 — docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#6.5.2 deprecation — 친절한 오류로 바로 major — 주장과 일치
- 확인 RC21 — 확인 — plugins/plugin-audit/README.md#| `DEVBREW_DISABLE_PLUGIN_AUDIT` | — 주장과 일치
- 확인 RC22 — 확인 — plugins/spec-distill/skills/conducting-interview/SKILL.md#user-invocable: false — 주장과 일치 (plugins 전체에 disable-model-invocation 0건)
- 확인 RC23 — 확인 — plugins/spec-distill/skills/conducting-interview/references/finishing.md#Skill spec-distill:reviewing-brief $PAYLOAD $AUDIT — 주장과 일치 (157행)
- 확인 RC24 — 확인 — plugins/spec-distill/CHANGELOG.md#one-minor deprecation window 를 두지 않고 한 번에 제거한다(사용자 결정 D3) — 주장과 일치 (652행, RC16 과 같은 자리)
- 확인 RC25 — 확인 — plugins/spec-distill/skills/framing-requests/SKILL.md#호출 모양 — 이 파이프라인에서 여기가 정본이다 — 주장과 일치 (883행; /interview · /request-framing 40파일 358회 재현)
- 확인 RC26 — 확인 — plugins/spec-distill/commands/interview.md#Step 1.5: `@경로` 인자 풀기 — 주장과 일치 (21행 · 32행 문구)
- 확인 RC27 — 확인 — plugins/spec-distill/skills/framing-requests/SKILL.md#검사는 command 가 합니다 — 주장과 일치 (handoff 직전 git commit 925~934행)
- 확인 RC28 — 확인 — plugins/quality-gates/hooks/session-start-advisor.py#Run `/cancel-qg` to clear before invoking — 주장과 일치 (183행, RC18 과 같은 자리)

### brief 리뷰 (reviewing-brief — 문서 리뷰 엔진)

- 라운드: 3 · 재리뷰 카운트 2 · 추가 라운드 0 — 승인 게이트 도달 사유: 상한 · 리뷰 완료: 예(r3 round_reviewed 참) — 단 상한 뒤 1단계에서 고른 채택 4·fix 3 의 적용은 다시 리뷰되지 않았다
- 결정: `## 8. 리뷰 결정` 13건 · 열린 채 남은 항목 0건 — 채택 permit 3건(D3.6·D3.8·D3.9)은 라운드 4 관측 예정이라 엔진상 「채택」으로 남고, fix 1건(54d639fc#r3.1)은 permit 통과 후 적용·미관측, fix 2건(eb353eb4#r3.1·#r3.2)은 앵커 미해석으로 상향된 채 사용자 선택으로 적용
- codex: 없음 — exit_nonzero(사용량 한도, r1~r3 + 원인 확인 1 = 호출 4회 전부 실패) · 웹: Claude doc-critic-web · codex 켜짐(실행 실패)
- 냉독: gap 0건 — 단 OQ18~OQ24 박제 직전 판본을 읽었다. 잘 안 읽힌 곳 4(ST1·부착 표기, OQ11 문장, 「스위치 은퇴 공시」가 겨냥하는 경우, RC21·RC24 본문 부재)
- degrade: codex:unavailable(사용량 한도) · pipeline:재비판 입력 축약(r1·r3) · pipeline:check-intent 조작 실수로 상향 4건·관측 실패 2건 · pipeline:상한 뒤 적용 미검증 · 두 번째 채널 1줄(r1 재비판 축약 — component 열거 밖 이름으로 기록 실패)
- 참고(advisory): 엔진 목록 2건(같은 앵커 계보로 접힘) — 세 라운드의 방향·overdesign 지적 7갈래를 payload §3 OQ18~OQ24 로 박제

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S2** ☑ 선택 (R1 — 이 작업 뒤의 진짜 문제를 한 문장으로):
  > "부르는 모양마다 도는 게 다름 (권장)"
- **S3** ☑ 선택 (R2 — «명령보다 skill 이 확실히 돈다»는 어떤 일에서 왔나):
  > "명령이 제대로 안 이어짐 (권장)"
- **S4** ☑ 선택 (R3 — 공식 문서 방향을 진입 구조로 받아들이나 · 외부 근거 처분):
  > "받아들인다 — skill 하나로 (권장)"
- **S5** ☑ 선택 (R4 — ST1 판정):
  > "보완 (builder·orchestrator 추천)"
- **S6** ☑ 선택 (R5 — premortem 위험 중 설계 필수로 올릴 것):
  > "진입의 확실성 (권장), 짧은 이름 충돌 (권장), @ 재현은 대화형에서 (권장), 전환 잔재와 qg 면제 (권장)"
- **S7** ☑ 선택 (R6 — 사용자가 치는 skill 이름 규칙):
  > "짧게 + 일반어 단독 금지 + 안내는 완전명 (권장)"
- **S8** ☑ 선택 (R7 — 통일 규칙 락이 무엇을 재나):
  > "표면 정합 (권장)"
- **S9** ☑ 선택 (R8 — Open Questions 목록 확인):
  > "맞다 (권장)"

## 7. 확산 원자료

- «cc-skills» — https://code.claude.com/docs/en/skills — 플러그인 skill 네임스페이스와 bare /name 조건, $ARGUMENTS 원문 전달, user-invocable·disable-model-invocation, argument-hint, 압축 뒤 5,000 토큰 재부착, !`cmd` 사전 치환과 정책 비활성
- «cc-components» — https://code.claude.com/docs/en/plugins/components — commands 는 older format, skills supersede
- «cc-loading» — https://code.claude.com/docs/en/plugins/loading — 실행 중 세션은 로드한 버전 유지, auto-update 기본 off
- «cc-plugins-ref» — https://code.claude.com/docs/en/plugins-reference — claude plugin validate(--strict)
- «clig» — https://clig.dev/ — non-additive 변경 전 경고, alias 안정성
- «semver-faq» — https://semver.org/ — deprecation minor 뒤 major 제거
- «vim-removal» — https://claudeissues.com/issue/43370-docs-vim-mode-docs-still-reference-removed-vim-command — /vim 무alias 제거와 stale 문서
- «unknown-slash» — https://claudeissues.com/issue/9235-bug-unknown-slash-command-plugin — Unknown slash command 메시지
- «collision-builtin» — https://claudeissues.com/issue/62409-bug-slash-command-name-collision-plugin-skill-shadows-built-in-release-notes — 플러그인 skill 이 내장 명령을 가림
- «collision-cross-plugin» — https://claudeissues.com/issue/45818-skill-name-collision-across-plugins-fully-qualified-name-resolves-to-wrong-plugi — 같은 이름 skill 의 완전명 오해석
- «dmi-refusal» — https://github.com/anthropics/claude-code/issues/26251 — disable-model-invocation skill 의 /name 실행 거부
- «slash-skill-regression» — https://claudeissues.com/issue/32865-bug-claude-code-no-longer-load-skills-invoked-by-slash-commands — slash 로 부른 skill 미로드 회귀
- «at-in-args» — https://claudeissues.com/issue/52618-docs-slash-commands-docs-omit-file-references-in-arguments-including-absolute-pa — slash 인자 속 @ 지원과 절대경로 자동완성 변경
- «at-not-pulled» — https://claudeissues.com/issue/11244-bug — slash 명령 안 @ 가 파일을 끌어오지 않음
- «github-devbrew» — https://github.com/jeonghok/devbrew — public, star·fork·watcher 0 (2026-10-08)

## 8. 리뷰 결정

- D2.1 · r2 · adopt · 194dffbb#r2.2 · "채택 — «명령형» 삭제 (권장)" — check-intent 거부 후 상향: D5 와 §0 은 사용자가 치는 이름을 「짧은 명령형」으로 적었는데, S7 은 「짧게」만 골랐다. 「명령형」이라는 형태 규칙은 원문에 없다(CLAUDE.md 의 기존 command 규칙 문구를 옮겨 온 것으로 보인다).
- D2.2 · r2 · adopt · e99bfa50#r2.1 · "채택 — «증상» 문구 분리 (권장)" — check-intent 거부 후 상향: D1 의 「이름·문서 불일치는 증상이다」와 §0 의 「이름 혼재와 문서 불일치는 그 증상이다」는 근거로 든 S2(「부르는 모양마다 도는 게 다름」)에 없다. 게다가 S1 에서 사용자가 「문서와 실제의 불일치」를 독립된 불편으로 확인한 것을 부수적인 것으로 낮춘다. 이 절을 빼거나 ✎ 추론으로 분리해야 한다.
- D2.3 · r2 · drop · 194dffbb#r1.1 · "r2 decide 194dffbb#r2.2 채택으로 대체" — D5 와 §0 은 사용자가 치는 이름을 「짧은 명령형」으로 적었는데, S7 은 「짧게」만 골랐다. 「명령형」이라는 형태 규칙은 원문에 없다(CLAUDE.md 의 기존 command 규칙 문구를 옮겨 온 것으로 보인다).
- D2.4 · r2 · drop · e99bfa50#r1.2 · "r2 decide e99bfa50#r2.1 채택으로 대체" — D1 의 「이름·문서 불일치는 증상이다」와 §0 의 「이름 혼재와 문서 불일치는 그 증상이다」는 근거로 든 S2(「부르는 모양마다 도는 게 다름」)에 없다. 게다가 S1 에서 사용자가 「문서와 실제의 불일치」를 독립된 불편으로 확인한 것을 부수적인 것으로 낮춘다. 이 절을 빼거나 ✎ 추론으로 분리해야 한다.
- D2.5 · r2 · drop · 194dffbb#r2.1 · "D2.1(194dffbb#r2.2) 채택 적용과 같은 내용 — 중복" — S7 은 '짧게'라고만 골랐는데, D5 와 §0 은 이것을 '짧은 명령형'으로 옮겨 문법 제약(명령형)을 확정 사항처럼 더했다. 지금 사용자가 치는 이름 interview · request-framing · plugin-audit · project-init 은 모두 명사형이라, 이 추가 제약은 사용자가 고르지 않은 rename 을 강제하게 된다.
- D3.6 · r3 · adopt · 194dffbb#r3.1 · "채택 — «짧게» 유지 (권장)" · supersedes D2.3 — 채택 후 미적용(expired): check-intent 거부 후 상향: D5 와 §0 은 사용자가 치는 이름을 「짧은 명령형」으로 적었는데, S7 은 「짧게」만 골랐다. 「명령형」이라는 형태 규칙은 원문에 없다(CLAUDE.md 의 기존 command 규칙 문구를 옮겨 온 것으로 보인다).
- D3.7 · r3 · adopt · 5443440e#r3.1 · "채택 — §0 변경 유지 (권장)" — finding 없이 바뀜: 0. 한눈에 (modified)
- D3.8 · r3 · adopt · e99bfa50#r3.1 · "채택 — «증상» 분리 유지 (권장)" · supersedes D2.4 — 채택 후 미적용(expired): check-intent 거부 후 상향: D1 의 「이름·문서 불일치는 증상이다」와 §0 의 「이름 혼재와 문서 불일치는 그 증상이다」는 근거로 든 S2(「부르는 모양마다 도는 게 다름」)에 없다. 게다가 S1 에서 사용자가 「문서와 실제의 불일치」를 독립된 불편으로 확인한 것을 부수적인 것으로 낮춘다. 이 절을 빼거나 ✎ 추론으로 분리해야 한다.
- D3.9 · r3 · adopt · f0f95e2d#r3.1 · "채택 — bare 실측 ✎ 추가 (권장)" — check-intent 거부 후 상향: S1 은 대화형 터미널에서 재야 할 것으로 'bare 이름 · @ 자동완성 · 선행 슬래시' 셋을 들었고, 헤드리스에서는 'bare 이름은 Unknown command 였다'는 관측도 함께 적었다. 그런데 brief 는 @ 와 선행 슬래시만 OQ9 와 D4 로 옮겼고, 맨 이름의 대화형 실측과 헤드리스 Unknown command 관측은 §6 밖 어디에도 없다.
- D3.10 · r3 · drop · f0f95e2d#r2.1 · "drop — 4번이 대체 (권장): f0f95e2d#r3.1 채택" — S1 은 대화형 터미널에서 재야 할 것으로 'bare 이름 · @ 자동완성 · 선행 슬래시' 셋을 들었고, 헤드리스에서는 'bare 이름은 Unknown command 였다'는 관측도 함께 적었다. 그런데 brief 는 @ 와 선행 슬래시만 OQ9 와 D4 로 옮겼고, 맨 이름의 대화형 실측과 헤드리스 Unknown command 관측은 §6 밖 어디에도 없다.
- docreview 계수 — 66d456cd-0cd7-4277-8466-2811dc3a60f9/2026-10-08-skill-only-surface-interview-9480e7bacc0ccb2e r1: advice_new=2 · advice_repeat=2 · mc_preexisting_new=0
- docreview 계수 — 66d456cd-0cd7-4277-8466-2811dc3a60f9/2026-10-08-skill-only-surface-interview-9480e7bacc0ccb2e r2: advice_new=0 · advice_repeat=3 · mc_preexisting_new=0
- docreview 계수 — 66d456cd-0cd7-4277-8466-2811dc3a60f9/2026-10-08-skill-only-surface-interview-9480e7bacc0ccb2e r3: advice_new=0 · advice_repeat=2 · mc_preexisting_new=0
