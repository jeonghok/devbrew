---
name: project-init-audit
type: interview-brief
created_at: 2026-07-12
session_id: 233b37ce-7f1e-4a04-b140-cc1d7ea33ea4
source: spec-distill conducting-interview v0.19.3
next_phase: superpowers:brainstorming
locked_directions:
  - id: LD1
    statement: "감사-우선 2단계 — 1차 Workflow는 읽기전용 감사 fan-out으로 우선순위 갭 목록만 산출하고, 구현 범위는 사용자가 그 목록에서 선택한다."
    source_path: b
    steelman: n/a
    defense: "감사 없이 범위를 못 박으면 shape parity 같은 미검증 가설 위에 큰 리팩터를 태우게 된다. steelman이 정확히 그 위험을 실증했다."
  - id: LD2
    statement: "감사 축 6개: ①정합·정직성 ②아키텍처·shape ③enforcement 능력 ④외부대비·정체성(내장 /init 포함) ⑤UX·디테일 ⑥보안."
    source_path: b
    steelman: n/a
    defense: "감사는 읽기전용이라 값싸고 범위는 어차피 사용자가 고른다(LD1). 정체성 축을 빼면 가장 비싼 발견을 구조적으로 못 한다."
  - id: LD3
    statement: "갭 목록 정렬은 3-키: (1) 사용자 피해 심각도 → (2) 비용 대비 효과 → (3) 최신 플러그인 레퍼런스(2026 공식 문서·생태계 표준) 대비 격차."
    source_path: b
    steelman: n/a
    defense: "사용자 프로젝트로 배포되는 거짓 안내가 최상위 피해. ROI와 레퍼런스 격차는 동순위 tie-breaker."
  - id: LD4
    statement: "감사자 구성 = 축별 Claude 서브에이전트 다중렌즈 + codex 독립 감사 1회(모델 다양성)."
    source_path: b
    steelman: n/a
    defense: "devbrew 이력상 codex가 Claude 리뷰어 전원이 놓친 fail-open을 단독 적발한 선례 다수(qg #85·#86·#90·#92)."
  - id: LD5
    statement: "감사 범위 = plugins/project-init/** + project-init이 생성한 devbrew 산출물(docs/git-workflow/**) + .claude-plugin/marketplace.json의 project-init 항목."
    source_path: b
    steelman: n/a
    defense: "유령 의존성 안내가 templates 경유로 생성물까지 샜다 — 플러그인 폴더만 보면 결함의 절반을 못 본다."
  - id: LD6
    statement: "아키텍처·shape 축(②)에서 '형제 플러그인과 다르다'는 논거는 무효. 구조 변경 권고는 재현 가능한 실패 모드 또는 steelman 조건 (a)~(d) 충족을 제시해야 한다 — 단, 판정 자체는 보류(OQ1)."
    source_path: b
    steelman: switched-to-this
    defense: "n/a — 사용자가 steelman 판정을 보류했으므로 결론은 미정. 다만 '입증책임' 규칙은 감사 방법론으로 확정(양쪽 증거 대칭 수집 의무)."
---

# project-init 감사 — Interview Brief (meta-prompt for brainstorming)

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming
> 해답공간으로 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다.

## 1. Reframed Problem

**받은 요청**: "project-init을 탐색하고 낡은 부분을 개선하고, 기능·디테일·외부 플러그인 대비 부족한 부분을 workflow로 채우고 싶다."

**재구성된 문제정의 (한 문장)**:
> project-init v1.7.2는 *구조가 얇다는 이유로* 낡은 게 아니라, **자기 문서가 코드에 대해 거짓말을 하고 그 거짓말을 사용자 프로젝트로 배포하고 있으며**, 2026년 Claude Code 플러그인 레퍼런스 대비 자기 위치(내장 `/init`과의 관계, hook 계층 선택)를 한 번도 재평가한 적이 없다 — 그래서 필요한 것은 리팩터가 아니라 **증거 기반 감사**다.

> ⚠️ **2026-07-12 강등 — 위 재구성은 이제 *발견*이 아니라 *가설*이다.** "문서가 코드에 대해
> 거짓말한다"는 root cause는 D1–D4를 근거로 세워졌는데, 심층 검증 결과 **그 중 3건의 전제가
> 틀렸다**(§2). 명백한 "문서가 코드에 대해 거짓말"로 남은 것은 **D3 하나**다. 감사자는 이
> 재구성을 **전제로 깔지 않는다** — 전제하면 찾으려던 것만 찾게 된다. "낡지 않았다"도 정직한
> 결과다.

**진짜 goal**: "개선"의 대상을 추측이 아니라 증거로 확정하는 것. 1차 산출물은 코드가 아니라 **우선순위가 매겨진 갭 목록**이다. **갭이 적게 나오는 것은 실패가 아니다 — 없는 갭을 만들어내는 것이 실패다.**

**(d) ontological 도출 타입**: `ROOT_CAUSE` — "낡음"이라는 증상의 원인을 물었더니 두 개의 서로 다른 원인이 나왔다: (i) 검증 가능한 **정직성 결함**(문서-코드 불일치, 유령 의존성), (ii) 검증되지 않은 **구조 가설**(scripts/skills 부재 = 낡음). steelman이 (ii)를 무너뜨림으로써 (i)이 진짜 root cause임이 드러났고, (ii)는 감사가 판정할 열린 질문으로 강등됐다.

## 2. Locked Directions

frontmatter `locked_directions`와 1:1. 재논쟁 금지.

- **LD1 — 감사-우선 2단계.** 1차 Workflow = 읽기전용 감사 fan-out → 우선순위 갭 목록. 구현은 사용자가 목록에서 고른 것만, 별도 사이클.
- **LD2 — 감사 축 6개.** ①정합·정직성 ②아키텍처·shape ③enforcement 능력 ④외부대비·정체성 ⑤UX·디테일 ⑥보안.
- **LD3 — 3-키 정렬.** 사용자 피해 심각도 → 비용 대비 효과 → 최신 레퍼런스 대비 격차.
- **LD4 — 모델 다양성.** 축별 Claude 서브에이전트 + codex 독립 감사 1회.
- **LD5 — 범위 경계.** `plugins/project-init/**` + `docs/git-workflow/**`(project-init 생성물) + `.claude-plugin/marketplace.json`의 project-init 항목.
- **LD6 — 입증책임 규칙.** shape 축에서 "형제와 다르다"는 논거 무효. 구조 변경 권고는 **재현 가능한 실패 모드** 또는 steelman 명시 조건 (a)~(d) 충족 필요. (결론은 OQ1로 보류 — 감사자는 양쪽 증거를 대칭으로 수집해 제출한다.)

### 감사 시작 전 수집된 후보 단서 D1–D5 — **확정 사실이 아니다. 검증 필수.**

> ⚠️ **2026-07-12 전면 재분류.** 이 섹션은 원래 "이미 확정된 결함 (auto-confirmed, 목록 자동 진입,
> 재발견 금지)"이었다. **그 범주는 폐기됐다.** 심층 재검증 결과 **4건 중 3건의 전제가 틀렸고**,
> 전부 같은 실패 유형이었다 — **인덱스만 읽고 구현을 안 읽음**:
>
> | | 최초 주장 | 심층 검증 |
> |---|---|---|
> | D1 | "존재하지 않는 `commit-commands` 플러그인" | ❌ 실재하는 공식 플러그인 (`installed_plugins.json` 미확인) |
> | D2 | "qg PR 트리거 없음 → README는 거짓" | ❌ **README는 참** (`hooks.json` 이벤트 목록만 보고 훅 *본문* 미확인) |
> | D3 | marketplace description drift | ✅ 참 |
> | D4 | "templates 하위 = 배포 경로 → 유출 위험" | ⚠️ 파일 존재는 참, **유출 메커니즘은 거짓** (템플릿 *사용 코드* 미확인) |
>
> **왜 범주 자체를 폐기하는가**: "확정 사실 + 재발견 금지"는 그 항목들을 감사가 **구조적으로 검증할
> 수 없는 유일한 영역**으로 만든다 — 그리고 그것들이 다른 모든 판단의 전제다. 감사 코퍼스는
> ~1,600줄이라 재발견 비용은 **싸고**, 틀린 전제의 비용은 **한 사이클 전체**다. 균형이 맞지 않는다.

**감사자에 대한 지시**: D1–D5는 **후보 단서**이지 사실이 아니다. 각 단서에 대해:

1. **전제를 직접 검증하라** — 인용된 `file:line`을 열고, **주장된 메커니즘이 실제 구현에 존재하는지**
   확인하라. 인덱스·레지스트리·목차·description 필드만 읽고 판정하지 말 것. **구현을 읽어라.**
2. 검증 결과를 `confirmed` / `withdrawn` / `reclassified` 중 하나로 리포트에 명시하고 근거를 붙여라.
3. `confirmed`인 것만 갭 목록에 올린다. 나머지는 **철회 사유**와 함께 별도 표에 기록한다.

| # | 결함 | 증거 |
|---|---|---|
| D1 | **미선언 외부 의존성 + 조건부 유령 안내** — ⚠ **2026-07-12 정정**: 최초 브리핑은 이를 *"존재하지 않는 `commit-commands` 플러그인"*으로 분류했으나 이는 **사실 오류**다. `commit-commands@claude-plugins-official`은 **실재하는 공식 Anthropic 플러그인**이며(`~/.claude/plugins/installed_plugins.json` + 캐시 디렉토리 확인), devbrew *자체* 마켓플레이스(3개)에 없을 뿐이다. 실제 결함은 두 겹: **(a) 미선언 의존성** — project-init README가 commit-commands 통합을 광고하면서 **prerequisites 섹션이 아예 없다**(README 섹션 전수: 아키텍처/동작 방식/기능/브랜치 전략/통합/설치된 Hook/인스턴스화한 원칙/사용). CLAUDE.md: *"Silent coupling은 버그."* **(b) 조건부 유령 안내** — `templates/shared/pr-process.md:77` 경유로 `/commit-push-pr` 권고가 **사용자 프로젝트로 복제**되는데, 그 사용자가 commit-commands를 설치하지 않았다면 존재하지 않는 명령을 안내받는다. → **수정 방향은 "삭제"가 아니라 "선언·설치 안내 추가 + 미설치 사용자를 위한 graceful 문구"다.** | 실재 증거: `~/.claude/plugins/installed_plugins.json` (`"commit-commands@claude-plugins-official"`), `~/.claude/plugins/cache/claude-plugins-official/commit-commands/`. 결함 증거: `README.md:77`(prerequisites 부재), `commands/project-init.md:231`, `templates/shared/pr-process.md:77`, `docs/git-workflow/pr-process.md:77` |
| ~~D2~~ | ❌ **철회 (WITHDRAWN — 최초 주장이 거짓이었다).** 최초 주장: *"거짓 통합 주장 — README의 'quality-gates: PR 생성 시 자동 트리거'는 거짓; qg 훅은 PostToolUse/SessionStart/SessionEnd뿐"*. **반증**: `plugins/quality-gates/hooks/post-tool-use.py`가 `PostToolUse(Bash)` 안에서 `gh\s+pr\s+create`를 정규식으로 잡고, stdout의 PR URL을 추출해 *"You MUST now initialize the quality-gates pipeline"* systemMessage를 주입한다. **README:79는 참이다.** `templates/shared/pr-process.md:78`은 `(설치 시)` 전제조건까지 이미 정확히 달아 놓았다. **기계적 원인**: `hooks.json`의 *이벤트 등록 목록*만 읽고 훅 **본문**을 안 읽음 — 그리고 `hooks.json` 자신의 description은 PR 트리거를 언급하지 않아 그 파일만 보면 오류가 *확증*된다. | 반증: `plugins/quality-gates/hooks/post-tool-use.py:2-7, 54, 78, 88-95`. 원 주장의 증거였던 `hooks.json`은 **불충분한 증거**였다. |
| D3 | **marketplace description drift** — `.claude-plugin/marketplace.json`의 project-init 설명이 v1.6.0 Project Charter·docs-lint·AGENTS.md를 전혀 반영 안 함(plugin.json description은 최신). 마켓플레이스 카드가 플러그인의 절반을 숨김. | `.claude-plugin/marketplace.json` vs `plugins/project-init/.claude-plugin/plugin.json` |
| D4 | **플러그인 폴더 오염** (사실은 참 — 단 **유출 메커니즘 주장은 철회**). git-ignored `.claude/quality-gates/<uuid>/files.md` 3개가 플러그인 디렉토리와 `templates/` 내부에 잔존하며, 내용은 이전 qg 세션의 **절대경로 목록**이다. ~~"templates 하위는 배포 경로라 잠재적 유출"~~ → **거짓**: `commands/project-init.md:139-143`은 템플릿을 **파일명으로 개별 지정해 읽지**(`templates/<strategy>/branch-strategy.md` 등) 디렉토리를 재귀 복사하지 않는다. 따라서 사용자 프로젝트로 새는 경로는 **없다.** 남는 것은 리포 위생 문제 + 플러그인 tarball 패키징 시 포함될 여지. **severity를 그에 맞게 낮춰 판정할 것.** | 존재: `plugins/project-init/.claude/quality-gates/*/files.md` (2), `templates/.claude/quality-gates/*/files.md` (1). 유출 부재 근거: `commands/project-init.md:136-143` |
| **D5** | **AGENTS.md-canonical 설계가 2026 기준 정답인가?** (구 C10 — **2026-07-12 강등**). 이전 rev는 §3의 *"Claude Code는 AGENTS.md를 네이티브로 읽지 않는다"*를 근거로 **"이 설계를 훼손하는 권고 금지"**라는 **재갈**을 물렸다. 그 금지는 **삭제됐다** — 근거가 블로그 1편 + gist 1개뿐이고, 같은 등급의 주장들이 이미 세 번 틀렸으며, 그 재갈은 축④(외부대비·정체성)가 *"낡음"의 가장 큰 후보*에 대해 구조적으로 눈멀게 했다. **축④는 2026-07 현재 Claude Code의 AGENTS.md 네이티브 지원 여부를 web으로 직접 확인**하고 판정하라. `withdrawn`이면 **갭을 올릴 수 있다.** | §3의 해당 항목 (블로그 + gist). **감사자가 공식 문서로 재확인할 것** |

## 3. External Landscape

> ⚠️ **이 섹션의 주장들도 "확정 사실"이 아니다.** D1–D4 중 3건의 전제가 틀렸던 것과 같은 이유로
> (§2 참조), 아래 주장들도 **감사자의 검증 대상**이다. 특히 **C10("AGENTS.md-canonical 불가침")의
> 근거인 *"Claude Code는 AGENTS.md를 네이티브로 읽지 않는다"*는 2026년 7월 현재도 참인지 반드시
> 재확인**하라 — 틀렸다면 감사자는 잘못된 금지 조항을 받고 있는 것이다. 이미 발견된 오류: hook 타입은
> 4종이 아니라 5종이었다(아래).

- **command와 skill은 이미 통합됨** — `.claude/commands/x.md`와 `skills/x/SKILL.md`는 "work the same way"이며 **둘 다 description만 startup 로드 + 본문은 invoke 시 로드**. — https://code.claude.com/docs/en/slash-commands — **[피함]** — "231줄 command를 skill로 쪼개면 context가 가벼워진다"는 전제가 사실무근. shape 이관은 context 이득 0의 lateral move.
- **SKILL.md 권장 상한 500줄 / 결정론은 스크립트로** — https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices, https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview — **[중립]** — 231줄은 상한의 절반 이하라 "분해 필요" 근거 안 됨. 다만 "결정론은 스크립트로" 조항은 **의미 판단이 아닌** 순수 파일-상태 판정에 한해 감사 대상.
- **PostToolUse는 사후·비차단 (되돌릴 수 없음)** — https://claudefa.st/blog/tools/hooks/hooks-guide — **[중립]** — project-init의 브랜치·커밋 검증이 구조적으로 "이미 저지른 뒤의 경고"임을 확정. 승격 여부는 OQ2.
- **hook 계층 모델**: prose = advisory / permissions = static allow-deny / **PreToolUse = 보안급 "반드시 일어나면 안 되는 것"**. 스타일 컨벤션(브랜치 prefix, 커밋 포맷)은 PreToolUse 영역이 아님. — https://paddo.dev/blog/claude-code-hooks-guardrails/ — **[취함]** — devbrew의 "harness lightness — trust the model"과 독립적으로 수렴하는 외부 근거.
- **git blocking hook의 실패 모드**: 판단 여지 있는 스타일 규칙에 hard block → false positive로 사용자가 막힘, escape hatch 요구, 반발. — https://ai.sulat.com/claude-code-hooks-a-bookmarkable-guide-to-git-automation-11b4516adc5d — **[취함]**
- **hook 타입 5종** (command / HTTP / prompt / agent / `mcp_tool`) — project-init은 `command`만 사용. ⚠ 최초 브리핑은 "4종"이라 적었으나 `mcp_tool` 누락이었다 (2026-07-12 정정). — https://code.claude.com/docs/en/plugins-reference — **[중립]** — 도입 정당성은 LD6 입증책임 규칙 적용 대상. **감사자는 이 숫자도 직접 확인하라** — 이 brief의 사실 주장은 검증 대상이지 전제가 아니다.
- **Claude Code는 AGENTS.md를 네이티브로 읽지 않음** → `@AGENTS.md` import 또는 symlink가 유일한 정답. — https://agyn.io/blog/claude-md-agents-md-compatibility, https://gist.github.com/yurukusa/d36197848911f025add142abefcde685 — **[취함]** — **project-init의 현행 AGENTS.md-canonical + CLAUDE.md-thin-pointer 설계는 2026 기준 정답**. 이 축은 "낡음"이 아니라 오히려 앞서 있음. 감사자는 이를 훼손하는 권고를 하지 말 것.
- **내장 `/init` 존재** — 코드베이스를 스캔해 CLAUDE.md를 생성하며, AGENTS.md·.cursorrules·.windsurfrules를 읽어 반영. — https://www.marktechpost.com/2026/06/14/claude-code-guide-2026-25-features-with-examples-demo/ — **[중립]** — project-init Phase 0(manifest 스캔 tech-stack 감지)과 **기능 중복 의심**. 위임/차별화 판단은 OQ3.
- **생태계 플러그인 레퍼런스**: plugin-builder(컴포넌트별 빌더 스킬 + 대화형 생성), CI/CD·validation 포함 플러그인 템플릿이 표준화 중. devbrew는 CI 없음. — https://github.com/claude-market/marketplace/tree/HEAD/plugin-builder, https://github.com/ivan-magda/claude-code-plugin-template — **[중립]** — LD3의 3번째 정렬 키("최신 레퍼런스 대비 격차")의 기준선.

## 4. Skepticism Log

- **S1 — 대안 statement (steelman-builder verbatim, confidence 0.78)**: *"project-init(v1.7.2)의 231줄 command 산문 + PostToolUse advisory + scripts/agents 부재는 결함이 아니라 이미 세 번(v1.6.0, v1.7.0, v1.7.2) 의식적으로 재확인된 적합 설계이며, '형제 플러그인과 shape parity'를 이유로 스크립트 추출·skill 분해·PreToolUse 게이트·신규 hook 타입을 도입하는 것은 devbrew 자신의 CLAUDE.md가 금지하는 ceremony·복잡도 부채다."* — 근거 https://code.claude.com/docs/en/slash-commands (command≡skill, progressive disclosure 공유 → 이관 이득 0) · https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview (500줄 상한, 231줄은 절반 이하) · https://paddo.dev/blog/claude-code-hooks-guardrails/ (스타일 규칙 ≠ PreToolUse 영역) · https://ai.sulat.com/claude-code-hooks-a-bookmarkable-guide-to-git-automation-11b4516adc5d (스타일 규칙 hard block의 실패 모드) — **verdict: deferred** (사용자 보류 → OQ1로 이월; 방법론적 귀결 LD6만 확정)

**weakness_of_current (verbatim)**:

> "원안은 project-init의 실패 모드를 하나도 제시하지 않는다 — 유일한 역사적 버그(v1.7.2 H1 재제목)는 스크립트 부재가 아니라 규칙 자체의 좁은 exception 누락이었고 prose 판단 정제로 고쳐졌다. 원안의 근거는 '형제 플러그인과 다르다'는 구조적 비대칭 관찰뿐이며, 이는 CLAUDE.md Plugin Shape 섹션이 요구하지 않는 규범(shape parity)을 새로 도입하는 것과 같다."

**원안이 여전히 이기는 조건 (steelman 자인, verbatim)**:

> "(a) command가 실제로 500줄에 근접하거나 넘어서서 skill 500줄 가이드라인을 위반하기 시작할 때, (b) 파일-상태 판정에서 v1.7.2류의 버그가 '판단 정제'가 아니라 반복적인 규칙-부재/누락 패턴으로 재발할 때, (c) project-init이 다루는 무언가가 '되돌릴 수 없는 파괴'(예: 사용자 헌장 파일 silent overwrite) 등급의 위험으로 격상되어 PreToolUse급 보안 게이트가 필요한 사례가 발생할 때, (d) 이 판정 로직을 project-init 외 다른 소비자(다른 플러그인)가 재사용해야 해서 스크립트화의 재사용 가치가 실제로 생길 때."

**deferred의 운영 의미**: 감사자는 "형제와 다르다"를 논거로 쓸 수 없고(LD6), OQ1의 좌·우 증거를 **대칭으로** 제출해야 한다. 조건 (a)~(d) 중 무엇이 충족되는지 명시하는 것이 shape 축 보고의 필수 필드다.

## 5. Tried & Discarded

- **감사+구현 원샷 Workflow** (하나의 workflow가 감사하고 그 자리에서 다 구현) → 버림. 범위 결정권이 모델에게 넘어가고, 미검증 가설(shape parity) 위에 큰 리팩터를 태울 위험. LD1로 대체.
- **아키텍처 재정비 우선** (231줄 command → skills/agents 분해부터) → 버림. steelman이 공식 문서로 반증 — command와 skill은 이미 동일한 progressive disclosure를 공유하므로 이관의 context 이득이 0.
- **감사 리포트만 (구현 없음)** → 버림. 사용자는 실제 개선까지 원함 ("개선하고 채우는 작업").
- **감사 축 4개 (정체성 재검토 제외)** → 버림. 정체성 축을 빼면 "Phase 0을 내장 `/init`에 위임" 같은 가장 비싼 발견을 구조적으로 못 함.
- **단일 에이전트 얕은 감사 (top-N만)** → 버림. 저커버리지.
- **Claude 전용 감사자** → 버림. devbrew 이력상 codex 모델 다양성이 Claude 전원이 놓친 fail-open을 반복 단독 적발(qg #85·#86·#90·#92).
- **shape parity를 개선 목표로 lock** → 버림(→ deferred). §4 참조.

## 6. Open Questions

유추 금지. 감사가 증거를 가져오면 사용자가 판정한다.

- **OQ1 (steelman deferred)**: project-init의 "얇음"(command 산문 + PostToolUse advisory + scripts/skills/agents 0)은 적합 설계인가, 개선 대상인가? → 감사자는 **양쪽 증거를 대칭으로** 제출: (좌) 실증된 실패 모드 = 재현 시나리오·과거 버그 패턴·사용자 파일 파괴 위험 / (우) 변경 비용 = ceremony 위험·유지보수 drift·devbrew Forbidden Patterns 저촉. steelman 조건 (a)~(d) 중 무엇이 충족되는지 명시.
- **OQ2**: 브랜치·커밋 검증을 PostToolUse(사후 advisory) → PreToolUse(사전 차단)로 승격할 것인가? 외부 근거는 "스타일 규칙에 hard block은 과잉"이라고 하고, devbrew 원칙도 같은 방향. 그러나 *현행이 사후라 이미 만들어진 브랜치를 못 되돌린다*는 사실은 남는다. 중간지대(예: `git checkout -b` 직전 PreToolUse **경고만**, 차단 없음)가 존재하는가?
- **OQ3**: Phase 0(manifest·디렉토리 스캔 tech-stack 감지)이 내장 `/init`과 중복인가? project-init은 `/init`에 위임하고 charter+enforcement에 집중해야 하는가, 아니면 charter elicitation에 특화된 스캔이라 독립 가치가 있는가?
- **OQ4**: project-init이 사용자의 `CLAUDE.md`를 `@AGENTS.md` 한 줄로 **덮어쓰는** 경로(4c S2a/S4)에 되돌릴 수 없는 파괴 위험이 있는가? (백업 없음? 승인 프롬프트가 실제로 모든 파괴 경로를 덮는가?) — steelman 조건 (c)의 직접 후보이므로 **보안 축이 최우선으로 판정**.
- **OQ5**: devbrew에 CI가 없다(플러그인 테스트가 수동 실행). 최신 플러그인 레퍼런스는 CI/validation을 표준으로 포함한다. 이번 사이클 범위인가, 별건인가?
- **OQ6**: 3개 branching strategy 템플릿의 *내용* 품질(예: trunk-based Pattern B)은 감사 대상인가, 아니면 구조·정직성만 볼 것인가?

## 7. Concrete Next Action

superpowers 가용 → 이 brief를 context로 `superpowers:brainstorming` 호출.
해답공간에서 설계할 대상은 **project-init의 개선안이 아니라 "감사 Workflow의 설계"**다:

- Workflow 스크립트 구조: 6축(LD2) fan-out → codex 독립 감사(LD4) → 발견 병합·중복 제거 → LD3 3-키 정렬 → 갭 목록 산출.
- 각 감사 에이전트의 프롬프트 계약: 읽기전용, **갭 범위=LD5 / 읽기 범위=무제한(검증 필수 파일은 반드시 읽을 것)**, **LD6 입증책임 규칙**(shape 축에서 "형제와 다르다" 논거 무효, 양쪽 증거 대칭 제출), **D1–D5는 후보 단서이지 사실이 아니다 — 감사자가 직접 검증해 confirmed/withdrawn/reclassified 판정**(⚠ 최초 브리핑의 "재발견 금지"는 폐기됐다: 4건 중 3건의 전제가 틀렸고, 그 범주가 감사의 사각지대를 만들었다), **인덱스가 아니라 구현을 읽을 것**.
- 산출물 스키마: 각 갭 = {증거(file:line), 심각도, 수정 비용, 레퍼런스 격차, 권고안, 반대근거}.
- 종료 조건과 비용 상한(fan-out ≥5는 devbrew hard review 게이트 — 6축은 이 선을 넘으므로 brainstorming에서 명시 선언 필요).
