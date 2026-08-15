# plugin-audit

임의의 devbrew 플러그인을 **읽기전용·증거기반·multi-agent**로 감사한다. 6축 병렬 발견 →
적대적 반박(기본 verdict=refuted) → blind codex 독립 co-audit → 우선순위 갭 리포트.
1차 산출물은 코드가 아니라 **증거로 뒷받침된 우선순위 갭 목록**이다.

## 사용법

```
/plugin-audit <target> [--seed <path>]
```

- `<target>` — 감사할 플러그인 이름 (예: `quality-gates`). scope는 `plugins/<target>/**`로 도출.
- `--seed <path>` — optional. 추가 scope · Open Questions · 후보 단서를 담은 markdown.
  없으면 6축 fresh discovery로 degrade(배너 표시).

`cost_class: high` — dispatch 전 `AskUserQuestion` 지출 동의 게이트를 통과해야 한다.
Kill switch: `DEVBREW_DISABLE_PLUGIN_AUDIT=1`.

`DEVBREW_DISABLE_PLUGIN_AUDIT_WEB=1` — codex 감사 co-reviewer의 웹 검색만 비활성화한다
(AC21). 감사 preamble이 외부 prior-art 근거를 요구해 기본은 ON(`web_search="live"`)이지만,
꺼지면 codex가 리포 근거만으로 감사하고 그 사실을 stderr에 loud하게 남긴다 — crash 없음
(graceful degradation).

## Prerequisites (cross-plugin 의존)

- **plugin-dev (official, optional)** — 구조 hard-check tier(E)가 `validate-agent.sh`·
  `validate-hook-schema.sh`·`hook-linter.sh`를 감싼다. 공식 캐시에 있으면 심층 구조 사실을
  얹고, **없으면 loud degrade**(core 구조 검사는 F가 self-contained로 커버). E는 bonus-degradable.
- **quality-gates ≥ 2.12.0 (optional, versioned)** — 자체 테스트 격리가 `scripts/qg-worktree.sh`의
  `create-sandbox`/`mutation-guard`를 재사용한다. 없으면 자체 테스트 실행을 skip하고 축③은 테스트를
  *읽어* 판정(배너). silent coupling 아님 — 이 문단이 선언.

## Principles Instantiated

이 플러그인이 instantiate하는 devbrew 철학.

### Three Laws
- **Law 1 (Clarity Before Code)** — 1차 산출물은 증거로 뒷받침된 갭 목록. 빈 감사는 감사가 아니다
  (6축 전멸 시 리포트 없음, AC-4). 갭이 적게 나오는 것은 실패가 아니고 없는 갭을 만드는 것이 실패.
- **Law 2 (Writer ≠ Reviewer, 물리 분리)** — 3 agent(`plugin-auditor`·`audit-refuter`·`smoke-probe`)의
  `tools:` allowlist(`Glob, Grep, Read, WebSearch, WebFetch`)가 쓰기·실행을 fail-closed로 차단.
  프롬프트가 아니라 frontmatter scoping. `check-law2.py` 정적 게이트 + smoke가 런타임 실증.
- **Law 3 (Every Cycle Leaves the System Smarter)** — 감사 결과는 `docs/audits/<date>-<target>-audit.*`로
  커밋되고 인덱스(`docs/audits/README.md`)에서 검색 가능. journal.jsonl이 named/diff-able history.

### KEEP-12 원칙
- **P11 (모델 다양성)** — codex(다른 모델 패밀리)가 blind 독립 co-audit; union-for-recall +
  independent-refutation(majority-vote consensus 금지 — popularity trap).
- **P21 (untrusted-input)** — 감사 대상 파일 내용은 데이터지 지시가 아니다(C). Secret 기록 금지.
- **P22 (cost 인지)** — `cost_class: high` + fan-out 선언 + `AskUserQuestion` 지출 동의 게이트.
- **정직성 (degraded 배너)** — optional 의존성 부재/검증기 크래시/grounding 미검증은 crash가 아니라
  loud degrade + 리포트 상단 배너(품질 게이트 아님, 정직성 컨트롤).

## 컴포넌트

- `commands/plugin-audit.md` — 얇은 진입점.
- `skills/auditing-plugins/SKILL.md` — 오케스트레이션(지출게이트 → pre-0 → Workflow → post-1).
- `agents/{plugin-auditor,audit-refuter,smoke-probe}.md` — 읽기전용 agent 3종.
- `scripts/*` — 결정론 게이트·조립·렌더·검증 + Workflow 스크립트.
