---
name: qg-pr-publish
type: interview-brief
created_at: 2026-07-05
session_id: 5e42358f-119f-4ca9-b2ca-74061bdb80b3
source: spec-distill conducting-interview v0.18.0
next_phase: superpowers:brainstorming
worktree: /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+qg-pr-publish
branch: feature/qg-pr-publish
# locked_directions — (b)/(c) 명시 응답 + steelman 통과 방향. brainstorming 기정사실.
locked_directions:
  - id: LD1
    statement: "qg 산출물을 '결함 표'에서 분리해, 코드/diff를 안 읽는 사람이 PR의 아키텍처·구조·구현을 완전 이해하는 결정론적 PR-이해 본문을 별도 산출한다."
    source_path: b
    steelman: n/a
  - id: LD2
    statement: "생성과 게시 분리: qg Review gate는 순수 로컬 zero-side-effect 유지, 게시·PR생성은 별도 skill(quality-gates 내)이 담당."
    source_path: c
    steelman: switched-to-this
  - id: LD3
    statement: "게시=opt-in consent + 숨은 마커로 단일 top-level 코멘트 멱등 갱신(gh pr comment / gh api PATCH). gh pr review는 비멱등이라 제외."
    source_path: b
    steelman: n/a
  - id: LD4
    statement: "PR 부재 시 최종 단계 consent 후 gh pr create로 새 PR 생성, PR 본문(description)에 이해 본문 작성. unpushed는 auto-push 금지(2차 consent)."
    source_path: b
    steelman: n/a
  - id: LD5
    statement: "출력 포맷=결정론 고정 스키마(고정 헤딩·순서, 빈섹션 placeholder, 표 고정컬럼, <details>, 버전드 마커). 표·다이어그램 우선."
    source_path: b
    steelman: n/a
  - id: LD6
    statement: "관심사 분리: findings/fix 브리핑은 qg 터미널 귀속. 게시 본문에는 findings·'무엇을 고쳤나' 미포함 — 순수 PR-이해."
    source_path: b
    steelman: n/a
  - id: LD7
    statement: "콘텐츠 목표: 처음 보는 사람이 diff 없이 아키텍처·구조·구현 완전 이해. 정보밀도 최대·filler 금지·plain language·jargon 금지(길이 중립)."
    source_path: b
    steelman: n/a
  - id: LD8
    statement: "스코프 추가: (a) qg Final Summary 터미널 보고 UX + (b) 게시 터미널 보고 UX(구조·표·트리, dry-run 미리보기) 개선."
    source_path: b
    steelman: n/a
  - id: LD9
    statement: "보안 필수: 게시 전 시크릿 스캔 hard-block + raw diff 미인용 + 멱등 마커 author-scope 스푸핑 차단 + 전용 kill switch DEVBREW_QG_DISABLE_PUBLISH."
    source_path: b
    steelman: n/a
  - id: LD10
    statement: "process 권한: brainstorming에서 hard 결정마다 3-관점 비판적 subagent 리뷰 허용(단일관점 판단 리스크 방어)."
    source_path: b
    steelman: n/a
---

# qg PR-Publish — Interview Brief (meta-prompt for brainstorming)

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming
> 해답공간으로 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다.

## 1. Reframed Problem

**(d) ontological 도출 = ROOT_CAUSE.**

표면 요청: "qg 리뷰가 pr-review-toolkit 대비 PR에 남기는 내용이 부족하고, qg 이후 나온
리뷰로는 사람이 PR을 바로 이해하기 어렵다."

근본 원인(재구성): qg의 유일한 인간-대면 산출물은 `synthesize_findings.py`가 만드는
**결함 표**(`Sev | Path:Line | Conf | Summary | Source`) + suggested-fixes + 2줄 verdict다.
이것은 *기계가 찾은 버그의 목록*일 뿐, **"이 PR이 무엇을·왜 하며 구조상 어떻게 생겼는가"를
설명하는 서사가 아니다.** 그리고 사람은 브랜치의 diff/코드를 읽지 않으므로, 결함 목록만으로는
**아키텍처·구조·구현을 파악할 수단이 전혀 없다.** 게다가 qg는 애초에 GitHub PR에 아무것도
남기지 않는 순수 로컬 도구다.

**진짜 goal:** quality-gates 파이프라인에 — 기존 결함 게이트는 그대로 두고 — **코드를 읽지
않는 사람이 PR을 완전히 이해**하도록 만드는 *결정론적·고밀도·구조화된* PR-이해 산출물을
추가하고, 그 산출물을 **PR과 터미널에 안전하게(멱등·consent·시크릿 가드) 게시**하는 별도
skill을 만든다. 성공 기준은 "글이 길고 짧고"가 아니라 **비독자가 그 산출물만으로 PR의 구조와
구현을 오해 없이 재구성할 수 있는가**이다.

## 2. Locked Directions

frontmatter `locked_directions`와 1:1. 재논쟁 금지(다운스트림 기정사실).

- **LD1 — 결함 게이트 ≠ PR-이해**: qg의 결함 표(기계용)와, 사람이 PR을 이해하는 서사는 서로
  다른 산출물이다. 후자를 새로 만든다.
- **LD2 — 생성·게시 분리 (steelman 전환)**: qg Review gate는 gh/network 없는 순수 로컬
  zero-side-effect 게이트로 유지. 리뷰-본문 *생성*과 GitHub *게시/PR생성*은 **별도 skill**이
  담당(quality-gates 플러그인 내). gh/network 도구는 그 skill의 `allowed-tools`에만 존재하고
  `quality-pipeline` SKILL에는 절대 추가하지 않는다.
- **LD3 — 게시 방식**: 단일 top-level 코멘트를 숨은 버전드 마커(`<!-- pr-understanding:v1 -->`
  계열)로 찾아 **멱등 갱신**(`gh pr comment --edit-last --create-if-none` 또는 `gh api`
  list→PATCH-by-marker). `gh pr review`(approve/request-changes)는 비멱등이라 제외.
- **LD4 — no-PR → 생성**: 브랜치에 PR이 없으면 **최종 단계에서 consent를 물은 뒤** `gh pr
  create --body-file`로 새 PR을 만들고 이해 본문을 **PR 본문(description)**에 넣는다. unpushed
  브랜치를 자동 push하지 않는다(push는 별도 2차 consent). gh/remote 부재·미동의 → artifact만
  출력하고 **loud degrade**.
- **LD5 — 결정론 포맷**: 고정 헤딩·고정 순서가 곧 스키마. 빈 섹션은 생략하지 말고 안정적
  placeholder(`_None._`), 표는 고정 컬럼 계약, 긴/보조 콘텐츠는 `<details>`, 버전드 HTML-comment
  마커로 sticky·멱등. 정정된 본문 스키마(참고, findings 섹션 없음):

  ```markdown
  <!-- pr-understanding:v1 -->
  ## <imperative one-line summary>        # = PR title
  **What & Why**                          # 2-3줄, diff 재진술 금지
  **Architecture & Changes**              # 컴포넌트/모듈 표 (Area·File | Change) + mermaid 구조/flow
  <details><summary>Walkthrough (reading order)</summary> … </details>   # 읽는 순서, 필요시 mermaid
  **Testing**                             # 어떻게 검증/재현
  **Risk & Rollout**                      # blast radius, 마이그레이션, 롤백
  **Review focus**                        # (opt) 어디를 먼저 볼지
  ```
- **LD6 — 관심사 분리**: findings·"qg가 무엇을 고쳤나" 브리핑은 **qg 터미널에 귀속**. 게시 본문은
  이를 **포함하지 않는다**(순수 PR-이해). → publish 본문은 qg findings를 소비하지 않는다.
- **LD7 — 콘텐츠 목표/품질 바**: 처음 보는 사람이 diff 없이 아키텍처·구조·구현을 완전 이해.
  정보밀도 최대, filler·diff 재진술·모호어·jargon 금지, plain language. **길이는 중립**(길어도
  영양가 있으면 OK).
- **LD8 — 스코프 추가(보고 UX)**: (a) qg **Final Summary**(마지막 진행결과 보고)와 (b) publish의
  **터미널 보고**(무엇을 어디에 게시했는지 / dry-run 미리보기)를 같은 원칙(표·트리·구조)으로 개선.
  렌더 차이: PR=mermaid(GitHub 렌더), 터미널=ASCII 표·트리.
- **LD9 — 보안 필수**: 게시 전 시크릿 스캔 **hard-block**; 본문에 raw diff hunk 미인용(about-the-code
  서술); 멱등 마커 검색을 **author-scope**(인증 login + author_association)로 묶어 스푸핑 차단;
  PR 코멘트를 untrusted-input으로 취급; **전용 kill switch `DEVBREW_QG_DISABLE_PUBLISH=1`**;
  consent는 매 실행(정확한 게시 bytes + 대상 URL + identity 표시), cross-repo "always" 금지.
- **LD10 — process 권한**: brainstorming에서 hard/막히는 결정마다 **3-관점 비판적 subagent 리뷰**
  허용(사용자 명시 권한).

## 3. External Landscape

각 항목 출처 URL + [취함|피함|중립] + 이유. (각 entry는 게이트 요건상 한 줄 — URL·판정 inline.)

- CodeRabbit walkthrough(summary+목적별 그룹 파일표+다이어그램+collapsible+sticky 마커) — https://docs.coderabbit.ai/pr-reviews/walkthroughs — [취함] — 고정순서 서사+파일표+다이어그램+마커-멱등을 본문 스키마 뼈대로 채택.
- Sourcery Reviewer's Guide(File-Level Changes 표+mermaid+`<!-- -->` 마커 키) — https://docs.sourcery.ai/Code-Review/Code-Reviews-on-Pull-Requests/Interacting-with-Sourcery/ — [취함] — 파일수준 변경표+다이어그램 패턴 및 마커 sticky-comment 근거 보강.
- GitHub Copilot PR summary(prose overview+라인-링크 bullet) — https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/copilot-on-github/copilot-for-github-tasks/create-a-pr-summary — [중립] — 요약+링크는 참고하되 findings 비포함(LD6)과는 별개 축.
- Google eng-practices — CL descriptions(imperative 첫줄+why/context 우선) — https://google.github.io/eng-practices/review/developer/cl-descriptions.html — [취함] — summary=PR title 규칙 + "diff 재진술 말고 why"를 품질 바로 채택.
- `gh pr comment --edit-last --create-if-none` + `gh api` PATCH-by-marker(멱등 upsert; 단 `--edit-last`는 마커 아닌 "인증유저 마지막 코멘트"라 취약→마커+authorscope 래퍼 필요) — https://cli.github.com/manual/gh_pr_comment — [취함] — 단일 sticky 코멘트 멱등 원시명령.
- `gh pr create --body-file` + `gh pr view --json`(no-PR→exit1, state==OPEN 확인) — https://cli.github.com/manual/gh_pr_create — [취함] — PR 감지→없으면 생성 orchestration 원시명령.
- GitHub Security Lab pwn-requests(결과를 artifact로 생성 + 쓰기권한 별도 워크플로우가 게시) — https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/ — [취함] — "생성(무권한 로컬) vs 게시(권한 소비)" 물리분리 정석 근거(LD2 뒷받침).

## 4. Skepticism Log

의심 triggered 방향별 steelman 요지(verbatim) + 웹근거 + verdict. (게이트 요건상 entry는 한 줄 — URL·verdict inline.)

- 대안(verbatim): "qg는 GitHub에 절대 직접 포스팅하지 않는다 — PR-understanding 리뷰 본문은 로컬 Markdown artifact로만 생성하고, 그것을 실제 PR에 올리는 행위는 완전 분리된 명시적 opt-in 단계로 넘겨 qg의 로컬·zero-side-effect 게이트 정체성과 테스트 가능성을 지킨다." 근거 reviewdog(생성/게시 계층 분리) https://github.com/reviewdog/reviewdog + GitHub Security Lab(artifact→별도 권한 워크플로우 게시) https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/ — verdict: switched — 사용자가 "무조건 직접 게시"를 폐기하고 하이브리드(생성 항상+게시 opt-in 멱등)+별도 skill 분리로 전환, steelman의 decouple을 아키텍처(LD2)로 채택.

## 5. Tried & Discarded

- (B) 원안 = qg가 opt-in/게이트 없이 **무조건 PR에 직접 post** → 폐기. 이유: §4 steelman(생성/게시
  분리 정석, 테스트 가능성, PR-부재와 충돌, pr-review-toolkit 책임 중복) → 하이브리드+별도 skill 전환.
- (탐색 Agent B 제안) 게시 본문에 **qg findings 표 fold-in** → 폐기. 이유: 사용자 관심사분리
  (findings=qg 터미널 귀속, LD6) + 시크릿 노출면 축소(코드 인용 findings가 게시 안 됨) +
  publish의 qg-findings 결합 제거.
- **`gh pr review`**(approve/request-changes)로 게시 → 폐기. 이유: 비멱등(매 호출 새 리뷰 append)
  + 자기 PR approve 불가. `gh pr comment` 멱등 upsert가 맞음.
- **inline 라인 코멘트**(v1) → 폐기(연기). 이유: plain gh CLI inline이 취약(cli/cli#12396 미해결,
  서드파티 확장 필요). v1은 단일 top-level 코멘트로 한정.

## 6. Open Questions

미해결 명시(유추 금지 — 해답공간으로 이월).

- OQ1 (identity): 게시를 사용자 `gh` 토큰(기본)으로 vs 전용 bot/PAT? 귀속·토큰 스코프 blast radius 영향.
- OQ2 (self-trigger): publish가 `gh pr create` 시 quality-gates `post-tool-use.py`가 `/qg`를
  재유도 — 의도된 재리뷰인가, 억제해야 하는 루프인가.
- OQ3 (machine-readable verdict): 코멘트에 CI가 key로 삼을 파싱가능 verdict 블록을 넣을지(마커
  설계에 영향). 잠정 "v1 제외" 제안, 미확정.
- OQ4 (consent 기억 입도): per-invocation only vs per-repo remember. (cross-repo "always" 금지는 확정.)
- OQ5 (다이어그램 결정론): mermaid를 어떤 입력(diff의 심볼/모듈 그래프?)으로 *결정론적으로* 생성?
  터미널은 mermaid 렌더 불가 → ASCII 표/트리 대체 형태 설계.
- OQ6 (보고 UX 구체안): (a) qg Final Summary, (b) publish 터미널 보고의 실제 레이아웃 — brainstorming
  설계 대상.
- OQ7 (배치 재검토): 본문이 findings를 비소비하게 됐으므로(LD6) "in-plugin=tight coupling" 근거가
  약해짐. 그래도 (가) quality-gates 내 skill 유지(사용자 확정 + 플러그인이 이미 `gh pr create`
  경계에 있음). standalone 요구가 재등장하면 own plugin(`pr-publish`) 재고.
- OQ8 (base 결정): PR 생성 시 base를 repo 기본(`gh repo view --json defaultBranchRef`) vs tracking
  base 중 무엇으로? ambiguity → ask.

## 7. Concrete Next Action

- **superpowers 있음** → 이 brief를 context로 `superpowers:brainstorming` 호출 →
  `docs/superpowers/specs/…-design.md` 산출 → `spec-distill:spec-reviewer`(Law 2 분리) 검증 →
  `superpowers:writing-plans` → `subagent-driven-development`.
- **워크트리 준비됨**: `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+qg-pr-publish`
  (branch `feature/qg-pr-publish`, base `00415d9`=origin/main). 모든 구현은 이 워크트리 절대경로로.
- **process 권한(LD10)**: brainstorming에서 hard 결정마다 **3-관점 비판적 subagent 리뷰**를 돌려
  단일관점 판단 리스크를 방어한다.
- **devbrew 필수 체크리스트**(구현 시): quality-gates `plugin.json` SemVer minor bump + CHANGELOG
  `Added`; README "Principles Instantiated" + plugin.json description 정직하게 갱신(로컬 게이트
  **+** 별도 consent-gated publish); cost_class 선언(publish); 전용 kill switch; 마커/보안 로직은
  pure 함수로 추출해 gh-stub·dry-run으로 테스트; publish는 runtime 샌드박스 밖에서, `/qg` 뒤
  auto-chain 금지.
