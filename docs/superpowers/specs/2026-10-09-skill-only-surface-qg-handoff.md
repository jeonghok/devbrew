# skill-only 호출 표면 — qg 핸드오프

> v10 이 따를 규칙과, 이 작업이 고치지 않은(C3) qg 위반의 목록.

- 규칙 정본: `docs/superpowers/specs/2026-10-09-skill-only-surface-design.md` (B1 — 이 작업이 규칙을 소유하고 v10 이 따른다)
- 대조 기준: v10 설계 `docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md` @ `5eccf37c82ee6f000baefb0e8e972733ba07eb38` (브랜치 `feature/qg-v10-cleanup`)
- 이 브랜치가 qg 에서 바꾼 것: B6 넷 — `tests/test_codex_gate_observation.sh` 라벨 `case` 줄과 그 주석, `plugin.json` 9.3.7, `CHANGELOG.md` 한 항목

## 1부 — v10 이 따를 변경

1. 진입은 `!` 사전 검사를 가진 skill 이다. 형태 — `allowed-tools` 한 항목 + 본문 사전 검사 줄 + `## 진입 단계`(감시줄 판독 표). 정본 스크립트 `shared/entry/entry_preflight.py` 를 `plugins/quality-gates/scripts/` 에 링크로 싣는다.
2. 새 `commands/` 는 만들지 않는다. `plugins/quality-gates/commands/` 가 사라지면 락 `shared/tests/test_invocation_surface.sh` 의 qg 보고 모드가 끝나고, 2부 행이 RED 가 된다.
3. CLAUDE.md 개정 문면(인용):
   > - **`allowed-tools` 는 제한이 아니다.** command 에서는 쓰지 않는다. skill 에서는 진입 사전 검사 한 줄의 사전 허용으로만 쓰고 다른 도구를 열거하지 않는다. 2026-08-22 헤드리스 실측 5변형(`--plugin-dir` 격리 플러그인)에서 `["Read"]`로 `Bash`를 빼놓아도 `Bash`가 실행됐고, 스코프 표기(`Bash(<pattern>:*)`)도 범위 밖 명령을 막지 못했다 — **이 계층은 제한이 아니다.** 바로 위 agent의 `tools:`와는 다르다 — 그것은 fail-closed이고 Law 2의 집행 지점이다. 막지 않는 것을 막는다고 믿게 만드는 선언은 없는 것보다 나쁘다.
   >
   > - **Progressive disclosure.** 사용자가 부르는 진입 skill 은 짧은 kebab 두 단어 이상(일반어 단독 금지 — `spec-review`, `plugin-audit`)이고 디렉토리 이름 = `name` 이다. 모델만 부르는 내부 skill(`user-invocable: false`)은 동명사(`reviewing-brief`). 기계가 내는 안내는 `/plugin:name` 완전명. 새 command 파일은 만들지 않는다 — 사전 단계는 진입 skill 의 `!` 로. 모호한 이름 (`helper`, `utils`, `"I can help you..."`) 없음. 집행: `shared/tests/test_invocation_surface.sh`.
   >
   > - **v1.0.0 이상이면 `CHANGELOG.md`.** `## [version] — YYYY-MM-DD` with Added/Changed/Deprecated/Removed/Fixed/Security. 제거 전 one-minor deprecation window. 예외 — 호출 이름(slash 명령 · skill 이름)의 변경·제거는 alias 없이 즉시 하고 major bump 한다. 이 예외는 제3자 설치가 확인되면(외부 이슈 · 설치 보고 · 마켓플레이스 공개 등록) 소멸한다. kill switch 이름은 이 예외에 들지 않는다 — 은퇴시키려면 CHANGELOG `Removed` 와 README 에 공시가 필수다.
4. B6 라벨 줄: `test_codex_gate_observation.sh` 의 `case "$label"` 는 skill 디렉토리 이름을 열거한다 — 디렉토리를 바꾸면 그 줄도 같은 커밋에서 바꾼다.

## 2부 — 락이 재는 축의 qg 위반

`python3 shared/entry/check_invocation_surface.py --report` 의 표(23행). 축 A = 진입 skill 이름, C = 진입 사전 검사 모양, H = `commands/` 층, I = 옛 이름. v10 칸은 v10 설계 원문을 파일 · 이름으로 grep 해 채웠다.

| # | 축 | 위치 | 위반 | v10 설계 |
|---|---|---|---|---|
| 1 | A | `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:1` | 진입 skill 이름 'critiquing-artifacts' 의 첫 단어가 동명사다 — 동명사는 내부 skill 의 몫 | 다룸(L26·L66: 범위 밖 — qg 의 critique 관련 파일은 건드리지 않음) |
| 2 | A | `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md:1` | 진입 skill 이름 'publishing-pr-understanding' 의 첫 단어가 동명사다 — 동명사는 내부 skill 의 몫 | 다룸(L579: skill 디렉토리 삭제, L519 AC16) |
| 3 | C | `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:1` | `## 진입 단계` 절이 없다 | 다룸(L26·L66: 범위 밖 — qg 의 critique 관련 파일은 건드리지 않음) |
| 4 | C | `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:1` | allowed-tools 가 사전 검사 한 항목만이 아니다 — 기대: [Bash(python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" quality-gates critiquing-artifacts)] | 다룸(L26·L66: 범위 밖 — qg 의 critique 관련 파일은 건드리지 않음) |
| 5 | C | `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:1` | plugins/quality-gates/scripts/entry_preflight.py 가 없다 — 사전 검사 줄이 가리키는 스크립트 | 다룸(L26·L66: 범위 밖 — qg 의 critique 관련 파일은 건드리지 않음) |
| 6 | C | `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:31` | 사전 검사 줄이 정확히 하나가 아니다(실행형 0개 · 느낌표-백틱 0개) | 다룸(L26·L66: 범위 밖 — qg 의 critique 관련 파일은 건드리지 않음) |
| 7 | C | `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md:1` | `## 진입 단계` 절이 없다 | 다룸(L579: skill 디렉토리 삭제, L519 AC16) |
| 8 | C | `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md:1` | allowed-tools 가 사전 검사 한 항목만이 아니다 — 기대: [Bash(python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" quality-gates publishing-pr-understanding)] | 다룸(L579: skill 디렉토리 삭제, L519 AC16) |
| 9 | C | `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md:1` | plugins/quality-gates/scripts/entry_preflight.py 가 없다 — 사전 검사 줄이 가리키는 스크립트 | 다룸(L579: skill 디렉토리 삭제, L519 AC16) |
| 10 | C | `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md:28` | 사전 검사 줄이 정확히 하나가 아니다(실행형 0개 · 느낌표-백틱 0개) | 다룸(L579: skill 디렉토리 삭제, L519 AC16) |
| 11 | C | `plugins/quality-gates/skills/quality-pipeline/SKILL.md:1` | `## 진입 단계` 절이 없다 | 다룸(L342·L568: 제자리 재작성 — 사전 검사 줄·`## 진입 단계`는 언급 없음) |
| 12 | C | `plugins/quality-gates/skills/quality-pipeline/SKILL.md:1` | allowed-tools 가 사전 검사 한 항목만이 아니다 — 기대: [Bash(python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" quality-gates quality-pipeline)] | 다룸(L342·L568: 제자리 재작성 — 사전 검사 줄·`## 진입 단계`는 언급 없음) |
| 13 | C | `plugins/quality-gates/skills/quality-pipeline/SKILL.md:1` | plugins/quality-gates/scripts/entry_preflight.py 가 없다 — 사전 검사 줄이 가리키는 스크립트 | 다룸(L342·L568: 제자리 재작성 — 사전 검사 줄·`## 진입 단계`는 언급 없음) |
| 14 | C | `plugins/quality-gates/skills/quality-pipeline/SKILL.md:52` | 사전 검사 줄이 정확히 하나가 아니다(실행형 0개 · 느낌표-백틱 0개) | 다룸(L342·L568: 제자리 재작성 — 사전 검사 줄·`## 진입 단계`는 언급 없음) |
| 15 | H | `plugins/quality-gates/commands/cancel-qg.md:1` | commands/ 층은 qg 밖에 두지 않는다 — 사전 단계는 진입 skill 의 사전 검사 줄로 | 다룸(L548: 파일 삭제, L349·L394) |
| 16 | H | `plugins/quality-gates/commands/qg-publish.md:1` | commands/ 층은 qg 밖에 두지 않는다 — 사전 단계는 진입 skill 의 사전 검사 줄로 | 다룸(L579: 파일 삭제, L519 AC16) |
| 17 | H | `plugins/quality-gates/commands/qg.md:1` | commands/ 층은 qg 밖에 두지 않는다 — 사전 단계는 진입 skill 의 사전 검사 줄로 | 다룸(L345: commands/qg.md 를 «새로, 얇게» 유지 — `commands/` 층을 없애지 않음, L553 수정) |
| 18 | I | `plugins/quality-gates/scripts/run_codex_reviewer.sh:49` | 옛 이름 'reviewing-spec' | 다룸(L357·L566·L598: 유지·갱신 — 옛 이름 줄은 언급 없음) |
| 19 | I | `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:154` | 옛 이름 'reviewing-spec' | 다룸(L26·L66: 범위 밖 — qg 의 critique 관련 파일은 건드리지 않음) |
| 20 | I | `plugins/quality-gates/skills/quality-pipeline/SKILL.md:394` | 옛 이름 'reviewing-spec' | 다룸(L342·L568: 제자리 재작성 — 사전 검사 줄·`## 진입 단계`는 언급 없음) |
| 21 | I | `plugins/quality-gates/tests/lib/reconstruct-skill.sh:77` | 옛 이름 'conducting-interview' | 언급 없음 |
| 22 | I | `plugins/quality-gates/tests/lib/reconstruct-skill.sh:78` | 옛 이름 'reviewing-spec' | 언급 없음 |
| 23 | I | `plugins/quality-gates/tests/test_codex_gate_observation.sh:70` | 옛 이름 'reviewing-spec' | 언급 없음 |

## 3부 — 락이 재지 않는 qg 위반

| # | 출처 | 위반 | 위치 | v10 설계 |
|---|---|---|---|---|
| 1 | RC4 | `/qg --reset` 은 SID 가 비어 있지 않은지만 보고, 패턴 가드 · worktree 정리 · KEEP_WORKTREE 를 거치지 않는다 | `plugins/quality-gates/commands/qg.md` (Special argument `--reset`) | 다룸(L345·L373·L537: `--reset` 삭제, 제거 안내 한 줄) |
| 2 | RC5 | `/cancel-qg` 설명의 v1.32.0, quality-pipeline 제목의 v9.3.5 가 plugin.json 과 어긋난다 | `commands/cancel-qg.md:2` | 다룸(L548: `commands/cancel-qg.md` 삭제 · L342: quality-pipeline 제자리 재작성 — 제목 버전 표기는 언급 없음) |
| 3 | RC6 | `hide-from-slash-command-tool` 은 인식되지 않는 키라 오류 없이 무시된다 | `commands/cancel-qg.md:4` | 다룸(L548: 파일 삭제로 소멸) |
| 4 | RC8 | README 사용법 절의 이름 · 위치가 플러그인마다 다르고, qg README 사용 블록에 `/qg-publish` 가 없다 | `plugins/quality-gates/README.md` | 다룸(L363: README 다시 씀 — 사용 블록 · `/qg-publish` 는 언급 없음, L519·L579: `/qg-publish` 표면 삭제) |
| 5 | RC10 | 명령 이름을 안내하는 곳에 hook 과 스크립트도 있다(bare `/qg` · `/cancel-qg`) | `hooks/session-start-advisor.py:183,191-192` · `scripts/setup-qg.sh:98,121,142-143,185,322` · `scripts/synthesize_findings.py:699` | 다룸(L548: hooks/ 삭제 · L346: setup-qg.sh 새로 최소 · L195·L343: synthesize_findings.py 새로 — 안내 문구의 완전명은 언급 없음) |
| 6 | RC18 | 고칠 수 없는 qg SessionStart 훅이 `/cancel-qg` 를 bare 이름으로 안내한다 | `hooks/session-start-advisor.py:183` | 다룸(L548·L349·L394: 훅 삭제 ①, L386: SKIP_HOOKS 토큰 삭제) |
| 7 | P11 | `claude plugin validate --strict` 경고 — hooks 명령의 따옴표 없는 `${CLAUDE_PLUGIN_ROOT}` (spec-distill · project-init 도 같은 경고, 락 4부가 면제) | `hooks/hooks.json` (SessionStart · SessionEnd) | 다룸(L548: hooks/ 삭제로 소멸 — 경고 자체는 언급 없음) |

## 부록 — 미실행 seed 판별

규칙: ① `docs/superpowers/interview/*.md` 중 `.audit.md` 가 아니고 첫 줄이 `---` 인 frontmatter 에 정확히 `type: interview-seed` 가 있는 파일 ② 그 파일의 `audit_file:` 값 줄(`audit_file: <x>`)을 담은 다른 파일이 `docs/` 아래에 없음(brief §6 S1 은 seed 전문을 frontmatter 째 담는다). 결과(2026-10-09): 네 파일, 옛 호출 줄 0줄 — 갱신 0건. 규칙 ①② 를 글자 그대로 돌리면 셋(아래 첫째 · 둘째 · 넷째)이고, 셋째는 frontmatter 가 `interview-brief` 인 파일이 §6 S1 에 seed 를 frontmatter 째 담은 것이다 — 이 브랜치 설계(P10)가 센 대로 넷으로 싣는다.

- `2026-09-01-adjudication-topology-interview.md`
- `2026-09-01-seam-and-adjudication-interview.md`
- `2026-09-02-adjudication-topology-interview.md`
- `2026-09-05-spec-review-two-stage-redesign-interview.md`
