# 중복 인구조사 원장

모집단 고정 SHA: `66b8c6a8d0beeb8ad012964e9da8704cd42fd426` — 재현: `git ls-tree -r --name-only 66b8c6a8d0beeb8ad012964e9da8704cd42fd426`

**이 SHA가 영구 고정임을 명시한다.** brief Step 1은 "PR1 머지 SHA, 진행 중이면 현재 브랜치 HEAD를 잠정으로"라고 적었지만, 이번 실행에서는 PR1 머지가 발생하지 않았다 — 머지는 실행을 멈추고 사람에게 넘기는 액션이라 이 태스크 안에서 일어날 수 없다. 따라서 잠정 핀이 곧 영구 핀이 된다. 이 방향이 더 안전하다: 지금 고정하면 PR2의 아카이브 이동이 모집단을 줄이기 *전에* 모집단이 확정되고, 이 시점 이후 PR1이 추가하는 유일한 파일(락 테스트 2개)은 이 사이클 자신이 만드는 것이라 애초에 "기존 중복"이 아니다. **뒤에 오는 리더는 이 SHA를 stale placeholder로 보고 갱신하려 하지 말 것 — 이미 최종값이다.**

파일 수: `git ls-tree -r --name-only <SHA> | wc -l` = **720**

경계 파라미터: 유사도 ≥ 0.60 (주석·공백 제거 후 SequenceMatcher) · 블록 창 20줄 / 최소 200자
제외: */fixtures/* · */mocks/* · */harness/* · CHANGELOG.md

세 축 실행 결과 (부록 A 스크립트, `$SCRATCH`에서 실행 — 커밋 안 함):
- `census.py` (파일축): 대상 463개 파일. §1 같은 basename 2곳 이상 = **18종**, §2 다른 basename 유사쌍(≥60%) = **6쌍**. 세 스크립트 모두 rc=0, stderr 없음.
- `funcs.py` (함수축): 305개 스크립트(.sh/.py) 스캔, 2곳 이상 정의된 이름 **119종 · 정의 609개**.
- `blocks.py` (블록축): 396개 파일 스캔, 다중 출현 블록 91개 → 파일 그룹 **5개**.

population 총합 = 18 + 6 + 119 + 5 = 148 raw 후보. 아래 분류표는 축 1(같은 basename)의 `branch-strategy.md` 1건을 근거 diff에 따라 3개 하위 관계로 쪼갰다 (§1 표 #9~11) — seed가 이미 "×3"과 "템플릿-인스턴스"를 별도 행으로 나눠 적어 둔 것과 동일한 판단을 파일 경로 단위로 명시한 것뿐이며, population 자체를 늘리거나 줄이지 않는다(같은 4파일 그룹을 재서술). 총 표 행수 = **150**.

## 분류표

### 축 1 — 같은 basename 다중 존재 (census.py §1)

| # | 후보 | 분류 | 조치 (태스크) | 근거 |
|---|---|---|---|---|
| 1 | `__init__.py` ×2 (plugin-audit/spec-distill test dirs) | 우연 | 조치 없음 | 바이트 동일이지만 빈 파일 — Python 패키지 마커 컨벤션, 공유 로직 없음 |
| 2 | `pr-process.md` ×2 (docs/git-workflow ↔ project-init/templates/shared) | 템플릿-인스턴스 | 재적용+동일성 검사 | 99.4% 유사, `{{...}}` 치환 없이 거의 그대로 복제된 canonical 문서의 템플릿 배포본 |
| 3 | `commit-conventions.md` ×2 (동일 쌍) | 템플릿-인스턴스 | 재적용+동일성 검사 | 91.0% 유사, 위와 같은 관계 |
| 4 | `detect_codex.sh` ×3 (plugin-audit/quality-gates/spec-distill) | 진짜 사본 | shared/ 정본 + copy-of (Task 15·17·18·19) | 〔seed〕 diff는 헤더 프로즈 3종 + kill switch 변수명 1줄 + 주석 1줄뿐 |
| 5 | `codex_findings_to_yaml.py` ×2 (quality-gates/spec-distill) | 진짜 사본 | shared/ 정본 + copy-of (Task 15·17·18·19) | 〔seed〕 유일한 행동 차이는 emit keyset(`category`·`target_section`) |
| 6 | `hooks.json` ×3 (project-init/quality-gates/spec-distill) | 우연 | 조치 없음 | `.claude-plugin` 매니페스트 파일명은 플랫폼 강제, 각 플러그인이 실제로 등록하는 훅 집합이 다름(27/45/50줄, description도 상이) — 실측 확인 |
| 7 | `session-end-cleanup.py` ×2 (quality-gates/spec-distill) | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 〔seed〕 각자 kill switch 토큰 + `sys.path.insert`; qg는 worktree 정리까지 |
| 8 | `test_detect_codex.sh` ×2 (120 vs 54줄) | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 〔seed〕 같은 대상을 재지만 커버 범위가 다름 |
| 9 | `branch-strategy.md`: `docs/git-workflow/` ↔ `project-init/templates/github-flow/` | 템플릿-인스턴스 | 재적용+동일성 검사 | 실측(diff) 확인: 63줄 vs 63줄, 유일한 차이는 63번째 줄 rebase 조항 프로즈뿐(94.6%) — 〔seed〕 "의도된 차이 — 통합하지 않는다" |
| 10 | `branch-strategy.md`: `docs/git-workflow/` ↔ `project-init/templates/{git-flow,trunk-based}/` | 우연 | 조치 없음 | 34.6%/38.4% — git-flow(99줄)·trunk-based(120줄)는 길이부터 다른 별개 전략 문서 |
| 11 | `branch-strategy.md`: project-init 템플릿 3종(`git-flow`↔`github-flow`↔`trunk-based`) 상호 | 우연 | 조치 없음 | 〔seed〕 git 전략별 변형 — 설계상 서로 달라야 함 (git-flow↔trunk-based 26.1%~40.2%) |
| 12 | `post-tool-use.py` ×2 (219 vs 103줄) | 우연 | 조치 없음 | 〔seed〕 하는 일이 다름 (project-init=문서 린트, qg=세션 추적) |
| 13 | `test_session_end_cleanup.py` ×2 | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 〔seed〕 `session-end-cleanup.py`와 같은 이유 |
| 14 | `plugin.json` ×5 (전 플러그인) | 우연 | 조치 없음 | `.claude-plugin/plugin.json` 파일명은 플랫폼 강제; name/version/description은 플러그인마다 본질적으로 다름(유사도 7~27%) |
| 15 | `agents-md-section.md` ×4 (project-init 템플릿) | 우연 | 조치 없음 | 〔seed〕 git 전략별 변형 — 설계상 서로 달라야 함 |
| 16 | `observed.md` ×2 (docs/audits/*) | 우연 | 조치 없음 | 감사 리포트 컨벤션 파일명, 각 감사의 관측 내용은 고유 (유사도 3.7%) |
| 17 | `manifest.md` ×4 (docs/audits/*) | 우연 | 조치 없음 | 위와 같은 감사 리포트 컨벤션, 유사도 2.4~5.9% |
| 18 | `.gitignore` ×2 (root ↔ plugins/agent-transparency) | 우연 | 조치 없음 | 루트(228줄, 리포 전역) vs 플러그인 로컬(2줄, 상태파일 전용) — 스코프 자체가 다름 |
| 19 | `SKILL.md` ×8 (전 플러그인) | 우연 | 조치 없음 | 〔seed〕 플랫폼이 이름을 강제 |
| 20 | `README.md` ×7 | 우연 | 조치 없음 | 〔seed는 ×6으로 적었으나 실측 ×7 — **불일치**, 아래 §discrepancy 참조〕 README 컨벤션이 이름을 강제, 각 파일 유사도 0.6~6.8%로 내용은 독립적 |

### 축 2 — 다른 basename, 유사쌍 ≥60% (census.py §2)

| # | 후보 | 분류 | 조치 (태스크) | 근거 |
|---|---|---|---|---|
| 21 | `2026-07-16-law2-baseline.txt` ↔ `2026-07-16-law2-after-baseline.txt` (98.3%) | 우연 | 조치 없음 | 실측 확인: 과거 PR(law2-agent-tool-surface)의 테스트 실행 로그 before/after 스냅샷. 코드가 아니라 얼어붙은 이력 증거 — 유사도가 높은 것 자체가 의도(같은 스위트를 두 시점에 캡처) |
| 22 | `test_coverage_mapper_frontmatter.sh` ↔ `test_spec_reviewer_frontmatter.sh` (81.4%) | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 서로 다른 agent의 frontmatter를 검증하는 같은 테스트 패턴 — 공유 가능한 골격 |
| 23 | `test_blind_spot_prober_frontmatter.sh` ↔ `test_coverage_mapper_frontmatter.sh` (76.4%) | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 위와 같은 frontmatter 테스트 패밀리 |
| 24 | `run_brief_codex_reviewer.sh` ↔ `run_spec_codex_reviewer.sh` (74.0%) | 부분 사본 | 공통 조각만 추출 (Task 20·21) | spec-distill 내 codex 리뷰 실행 스크립트, 대상 산출물(brief vs spec)만 다름 — `write_failclosed`·`emit_fallback` 함수가 두 파일에 그대로 복제(§3 #99–100 참조) |
| 25 | `test_artifact_adversarial_frontmatter.sh` ↔ `test_artifact_critic_frontmatter.sh` (72.6%) | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 위와 같은 frontmatter 테스트 패밀리(quality-gates 쪽) |
| 26 | `discover-plan.sh` ↔ `discover-spec.sh` (63.8%) | 부분 사본 | 공통 조각만 추출 (Task 22) | 〔seed〕 같은 플러그인 내, 파일 하나 source로 소멸 → Task 22 |

### 축 3 — 2곳 이상에서 정의된 함수 (funcs.py)

세 그룹으로 나눠 적는다: (A) seed에 이미 있는 것, (B) census가 새로 드러낸 실측 근거 있는 것(진짜/부분 사본으로 승격), (C) 나머지 범용 이름(우연, funcs.py 저자 주석의 기본 가정을 따름 — "이 축은 범용 이름이 지배한다"). 판정 열의 ✅/◐/⚠는 census 원본의 본문-동일성 표기(전부 동일/부분 동일/전부 다름)를 그대로 인용.

| # | 함수 (언어) | 정의수/변형 | 판정 | 위치(실측 확인) | 분류 | 조치 | 근거 |
|---|---|---|---|---|---|---|---|
| 27 | `setUp` (py) | 77/51 | ◐ | — | 우연 | 조치 없음 | 〔seed〕 unittest API 컨벤션 — 부분 동일은 표준 boilerplate(`tempfile.mkdtemp()` 등)의 우연 중첩, 책임 공유 아님 |
| 28 | `main` (py) | 58/57 | ◐ | — | 우연 | 조치 없음 | 〔seed〕 각 스크립트의 고유 entry point |
| 29 | `note` (sh) | 55/13 | ◐ | — | 부분 사본 | Task 14 | 〔seed〕 판정 헬퍼 패밀리 |
| 30 | `fail` (sh) | 36/12 | ◐ | — | 부분 사본 | Task 14 | 〔seed〕 판정 헬퍼 패밀리 |
| 31 | `pass` (sh) | 34/6 | ◐ | — | 부분 사본 | Task 14 | 〔seed〕 판정 헬퍼 패밀리 |
| 32 | `ok` (sh) | 19/6 | ◐ | — | 부분 사본 | Task 14 | 〔seed〕 판정 헬퍼 패밀리 |
| 33 | `run` (py) | 15/15 | ⚠ | — | 우연 | 조치 없음 | 〔seed〕 범용 이름, 스크립트마다 다른 책임 |
| 34 | `tearDown` (py) | 15/10 | ◐ | — | 우연 | 조치 없음 | 〔seed〕 unittest 컨벤션, `setUp`과 동일 이유 |
| 35 | `no` (sh) | 15/5 | ◐ | — | 부분 사본 | Task 14 | 〔seed〕 판정 헬퍼 패밀리 |
| 36 | `run_hook` (py) | 7/7 | ⚠ | quality-gates test_session_end_cleanup.py 외 3 · project-init hooks/tests 2 · spec-distill 1 | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 실측: 두 샘플 모두 `subprocess.run([sys.executable, HOOK], input=json.dumps(payload), env=...)` 골격 동일, env 처리만 상이 — 3개 플러그인에 흩어진 훅-실행 테스트 헬퍼 |
| 37 | `_disabled` (py) | 7/7 | ⚠ | qg post-tool-use.py·post-tool-use-session-tracker.py·session-start-advisor.py·session-end-cleanup.py·qg-gc.py, spec-distill session-end-cleanup.py·spec-distill-gc.py | **진짜 사본** | shared/ 정본 + copy-of (Task 15·17·18·19) | 실측: 전부 `os.environ.get("DEVBREW_DISABLE_<PLUGIN>") == "1"` 반환 — `kill_switch_active`(#42)와 **동일 책임의 다른 이름**. CLAUDE.md가 보안 컨트롤로 규정한 kill switch 판정이 함수명 2종(kill_switch_active/​_disabled)·파일 12곳에 흩어져 있음 — census 함수축이 seed의 5곳 집계를 7곳 더 확장 |
| 38 | `emit` (py) | 6/6 | ⚠ | plugin-audit check-staleness.py·codex_audit_to_json.py, project-init docs-lint.py, spec-distill merge_review.py·merge_brief_review.py | 우연 | 조치 없음 | 각 스크립트의 출력 포맷(구조화 finding/YAML/JSON)이 서로 다름 — "출력하다" 범용 동사 |
| 39 | `check` (sh) | 6/4 | ◐ | — | 부분 사본 | Task 14 | 3곳이 바이트 동일한 하위집합 존재(◐ 표기 자체가 그 증거) — note/fail/pass류와 같은 판정-헬퍼 계열로 판단 |
| 40 | `field` (sh) | 6/4 | ◐ | — | 부분 사본 | Task 14 | 〔seed〕 구현이 awk 2종·sed 1종, 인자 순서까지 다름 |
| 41 | `_degrade_if_empty` (sh) | 5/5 | ⚠ | — | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 〔seed〕 5러너가 각자 다른 프롬프트 빌더를 부름, 출력 스키마 4종은 §6.2 통일 대상 |
| 42 | `kill_switch_active` (py) | 5/5 | ⚠ | — | **진짜 사본** | shared/ 정본 + copy-of (Task 15·17·18·19) | 〔seed〕 같은 책임(kill switch 판정), 본문 5종 전부 다름 = drift. `_disabled`(#37)와 합쳐 12곳 |
| 43 | `run_case` (sh) | 5/5 | ⚠ | quality-gates test_synthesize_findings.sh·test_scout_script.sh·test_check_trivia.sh·test_read_frontmatter.sh·test_pr_detect.sh | 우연 | 조치 없음 | 실측: 파라미터 시그니처가 파일마다 근본적으로 다름(`name adv_yaml findings_yaml ...` vs `name setup_fn expected_exit ...`) — 이름만 "테스트케이스 실행"이라는 자연스러운 관례를 공유, 로직 추출 불가 |
| 44 | `_plugin` (py) | 5/4 | ◐ | plugin-audit test_check_staleness.py (단일 파일 내 5회) | 우연 | 조치 없음 | 실측: **같은 파일 안** 서로 다른 테스트 클래스의 fixture 빌더 메서드 — 파일간 중복 아님 |
| 45 | `_yaml_scalar` (py) | 5/4 | ◐ | qg codex_findings_to_yaml.py, spec-distill codex_findings_to_yaml.py·merge_brief_review.py·brief_review_state.py·merge_review.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | YAML 스칼라 이스케이프 유틸이 quality-gates 1곳 + spec-distill 4개 스크립트에 반복 구현, 5곳 중 2곳만 바이트 동일 |
| 46 | `ag` (sh) | 5/4 | ◐ | — | 부분 사본 | Task 14 | 〔seed〕 판정 헬퍼 패밀리 명시 |
| 47 | `render` (py) | 4/4 | ⚠ | plugin-audit render-audit-report.py 외, quality-gates synthesize_findings.py | 우연 | 조치 없음 | 감사 리포트 렌더링 vs findings 렌더링 — 템플릿 대상이 근본적으로 다름 |
| 48 | `assert_grep` (sh) | 4/4 | ⚠ | — | 부분 사본 | Task 14 | 〔seed〕 assert_* 패밀리 |
| 49 | `mk_repo` (sh) | 4/4 | ⚠ | — | 우연 | 조치 없음 | fixture 리포 빌더, 시나리오마다 다른 상태로 커스터마이즈 — 전부 다름 자체가 "공유 로직 없음"의 증거 |
| 50 | `run_hook` (sh) | 4/4 | ⚠ | spec-distill test_spec_write_validator.sh·test_design_mode_validator.sh·test_reminder_hook.sh·test_review_dispatch.sh | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 실측: `env -i HOME=... PATH=... bash -c "echo PAYLOAD \| python3 HOOK"` 골격 동일, payload만 상이 — `run_hook`(py, #36)과 대칭되는 sh쪽 훅-실행 테스트 헬퍼 |
| 51 | `assert_contains` (sh) | 4/3 | ◐ | — | 부분 사본 | Task 14 | 〔seed〕 assert_* 패밀리 |
| 52 | `assert_eq` (sh) | 4/2 | ◐ | — | 부분 사본 | Task 14 | 〔seed〕 assert_* 패밀리, 3곳 이미 일치 |
| 53 | `_run` (py) | 3/3 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 54 | `cleanup` (sh) | 3/3 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 55 | `assistant` (py) | 3/3 | ⚠ | — | 우연 | 조치 없음 | 범용 이름(대화 role 헬퍼 추정), 전부 다름 |
| 56 | `boom` (py) | 3/3 | ⚠ | — | 우연 | 조치 없음 | 테스트용 예외 유발 헬퍼, 시나리오마다 다름 |
| 57 | `check` (py) | 3/3 | ⚠ | — | 우연 | 조치 없음 | 〔seed〕 범용 이름 |
| 58 | `extract_last_agent_message` (py) | 3/3 | ⚠ | — | 우연 | 조치 없음 | 이름은 구체적이나 census 본문이 전부 다름 — 파서 대상 포맷이 스크립트마다 다른 것으로 판단 |
| 59 | `emit` (sh) | 3/3 | ⚠ | plugin-audit run-own-tests.sh, quality-gates test_codex_prompt_untrusted_clause.sh·detect-runtime.sh | 우연 | 조치 없음 | 각자 다른 출력 포맷의 "출력하다" 범용 동사 |
| 60 | `die` (sh) | 3/3 | ⚠ | — | 우연 | 조치 없음 | 범용 에러 종료 헬퍼, 전부 다름 |
| 61 | `has` (sh) | 3/3 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 62 | `apply_overrides` (py) | 3/2 | ◐ | plugin-audit codex_audit_to_json.py, quality-gates codex_findings_to_yaml.py, spec-distill codex_findings_to_yaml.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 실측: `def apply_overrides(meta: dict) -> dict:` 동일 시그니처가 3개 스크립트에 — `codex_findings_to_yaml.py` ×2 진짜 사본(#5) 패밀리가 plugin-audit의 `codex_audit_to_json.py`까지 확장됨을 보여주는 근거. **불일치 항목**(§discrepancy) |
| 63 | `ng` (sh) | 3/2 | ◐ | — | 부분 사본 | Task 14 | 〔seed〕 판정 헬퍼 패밀리 |
| 64 | `emit_skip` (sh) | 3/1 | ✅ | detect_codex.sh ×3 | 진짜 사본 | detect_codex.sh 통합에 흡수 (Task 15·17·18·19) | 〔seed〕 detect_codex.sh 안에만 존재 — 파일 통합으로 소멸 |
| 65 | `_ver_lt` (sh) | 3/1 | ✅ | detect_codex.sh ×3 | 진짜 사본 | detect_codex.sh 통합에 흡수 (Task 15·17·18·19) | 〔seed〕 위와 같음 |
| 66 | `read_records` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 67 | `classify` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 68 | `collect` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 69 | `digest` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 70 | `section` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 71 | `load_module` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 동적 import 경로가 테스트마다 다름 |
| 72 | `test_the_fixture_actually_separates_the_two_readings` (py) | 2/2 | ⚠ | agent-transparency test_ab_runner_contract.py·test_prepare_standup.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 이례적으로 구체적인 테스트명이 서로 다른 두 파일에 재사용 — 우연으로 보기엔 이름이 너무 특수함, 같은 fixture-분리 불변식을 각각 재검증하는 것으로 판단 |
| 73 | `drive` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 74 | `read` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 〔seed〕 범용 이름 |
| 75 | `test_real_skill_has_no_problems` (py) | 2/2 | ⚠ | agent-transparency test_plugin_contract.py (단일 파일 내 2회) | 우연 | 조치 없음 | 실측: 같은 파일 안 서로 다른 클래스의 테스트 — 파일간 중복 아님 |
| 76 | `section_of` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 77 | `test_four_line_format` (py) | 2/2 | ⚠ | agent-transparency test_plugin_contract.py (단일 파일 내 2회) | 우연 | 조치 없음 | 실측: 같은 파일 안 서로 다른 클래스 — 파일간 중복 아님 |
| 78 | `git` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | git subprocess 래퍼, 스크립트마다 다른 인터페이스 |
| 79 | `line_for` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 80 | `_norm` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 범용 정규화 헬퍼, 전부 다름 |
| 81 | `resolve` (sh) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 82 | `_read` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 83 | `parse` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 〔seed〕 범용 이름 |
| 84 | `_load` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 85 | `test_deterministic` (py) | 2/2 | ⚠ | plugin-audit test_check_integrity.py, spec-distill test_compute_issue_id.py | 우연 | 조치 없음 | 실측: 무결성 검사 vs issue-ID 계산 — 완전히 다른 대상, "결정론 테스트"라는 일반적 테스트명 관례가 겹친 것 |
| 86 | `test_last_fenced_block_wins` (py) | 2/2 | ⚠ | plugin-audit test_codex_audit_to_json.py, spec-distill test_codex_findings_to_yaml.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | `apply_overrides`(#62)와 같은 근거로 codex 출력 파싱 테스트 패밀리가 plugin-audit까지 확장됨을 보여줌. **불일치 항목** |
| 87 | `test_auth_error_in_stderr` (py) | 2/2 | ⚠ | plugin-audit test_codex_audit_to_json.py, spec-distill test_codex_findings_to_yaml.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 위와 같음 |
| 88 | `_state_root` (py) | 2/2 | ⚠ | quality-gates hooks/session-start-advisor.py·session-end-cleanup.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 같은 플러그인 내 두 훅이 상태 루트 경로 해석을 각자 구현 — seed가 지적한 "qg-gc.py ↔ spec-distill-gc.py state root 해석 방식이 다름"과 같은 패턴이 quality-gates 내부에도 존재 |
| 89 | `emit_degraded` (sh) | 2/2 | ⚠ | quality-gates resolve-baseline.sh·check-review-scope.sh | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 같은 플러그인 내 두 스크립트가 degrade 신호 발신을 각자 구현 — codex 통일 project가 이미 "degrade 이름 5종" 문제로 기록한 계열의 일부 |
| 90 | `parse_fenced_json` (py) | 2/2 | ⚠ | qg/spec-distill `codex_findings_to_yaml.py` | 진짜 사본 | `codex_findings_to_yaml.py` 통합에 흡수 (Task 15·17·18·19) | #5 파일 진짜 사본의 구성 함수 — 파일 전체가 emit keyset 차이만 남기고 동일해지는 대상 |
| 91 | `yaml_emit` (py) | 2/2 | ⚠ | 동일 파일쌍 | 진짜 사본 | 위와 동일 흡수 | 위와 같음 |
| 92 | `_one` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 93 | `emit_json` (sh) | 2/2 | ⚠ | `discover-plan.sh`↔`discover-spec.sh` | 부분 사본 | `discover-plan.sh`/`discover-spec.sh` 통합에 흡수 (Task 22) | #26 파일 부분 사본의 구성 함수 |
| 94 | `pick_best` (sh) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 95 | `_ttl_ns` (py) | 2/2 | ⚠ | qg-gc.py↔spec-distill-gc.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 〔seed〕 `qg-gc.py ↔ spec-distill-gc.py` 부분 사본의 구성 함수 |
| 96 | `_verbose` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 범용 플래그 getter, 전부 다름 |
| 97 | `_within_grace` (py) | 2/2 | ⚠ | qg-gc.py↔spec-distill-gc.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 위 #95와 같은 패밀리 |
| 98 | `_gc_one` (py) | 2/2 | ⚠ | qg-gc.py↔spec-distill-gc.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 위와 같음 |
| 99 | `gc` (py) | 2/2 | ⚠ | qg-gc.py↔spec-distill-gc.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 두 파일의 진입점 함수 자체 |
| 100 | `normalize` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 101 | `_norm_sev` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | severity 정규화, 스키마별로 다름 |
| 102 | `assert_not_grep` (sh) | 2/2 | ⚠ | — | 부분 사본 | Task 14 | 〔seed〕 assert_* 패밀리 |
| 103 | `write_agent` (sh) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 104 | `bad` (sh) | 2/2 | ⚠ | quality-gates lock 테스트군(test_agent_tools_lock_mutation.sh 등) | 부분 사본 | 공통 조각만 추출 (Task 20·21) | mutation-lock 테스트 하네스 계열(verdict/expect/bad) — MEMORY의 "grep 회귀 락" 패턴과 일치 |
| 105 | `expect` (sh) | 2/2 | ⚠ | 위와 같은 lock 테스트군 | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 위와 같음 |
| 106 | `mkrepo` (sh) | 2/2 | ⚠ | — | 우연 | 조치 없음 | fixture 빌더, 전부 다름(`mk_repo`#49와 별개 이름) |
| 107 | `verdict` (sh) | 2/2 | ⚠ | quality-gates lock 테스트군 | 부분 사본 | 공통 조각만 추출 (Task 20·21) | #104/105와 같은 mutation-lock 하네스 계열 |
| 108 | `restore` (sh) | 2/2 | ⚠ | quality-gates test_cost_consent.sh·test_check_allowed_tools_order.sh | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 같은 플러그인 내 설정 복원 테스트 헬퍼 — 판단 갈림, 무거운 쪽으로 |
| 109 | `section_window` (sh) | 2/2 | ⚠ | quality-gates test_codex_result_banner.sh·test_runtime_verdict_precedence.sh | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 윈도우드-grep 락 테스트 기법(§12.4 계열)의 quality-gates측 인스턴스 |
| 110 | `assert_not_contains` (sh) | 2/2 | ⚠ | — | 부분 사본 | Task 14 | 〔seed〕 assert_* 패밀리 |
| 111 | `agf` (sh) | 2/2 | ⚠ | quality-gates test_qg_critique_routing.sh·test_critiquing_artifacts_skill.sh | 부분 사본 | Task 14 | `ag`(#46, seed 명시)의 변형 — 같은 판정-헬퍼 계열 |
| 112 | `run_in_env` (sh) | 2/2 | ⚠ | `test_discover_spec.sh`↔`test_discover_plan.sh` | 부분 사본 | `discover-plan.sh`/`discover-spec.sh` 통합에 흡수 (Task 22) | #26 파일 부분 사본의 테스트측 반영 |
| 113 | `_run_hook` (py) | 2/2 | ⚠ | quality-gates test_kill_switches.py, spec-distill test_hook_output_schema.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | `run_hook`(#36/#50)과 같은 계열의 별칭 — 훅 실행 테스트 헬퍼가 3번째 이름으로도 존재 |
| 114 | `run_ledger` (sh) | 2/2 | ⚠ | quality-gates test_qa_ledger.sh, spec-distill arm_test_helpers.sh | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 플러그인 경계를 넘는 ledger 테스트 하네스 |
| 115 | `rc_of` (sh) | 2/2 | ⚠ | quality-gates test_qa_ledger.sh, spec-distill test_check_verbatim_coverage.sh | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 위와 같은 ledger 테스트 하네스 계열 |
| 116 | `run_gc` (py) | 2/2 | ⚠ | qg-gc.py↔spec-distill-gc.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | #95/97/98/99와 같은 gc 패밀리 |
| 117 | `make_session_dir` (py) | 2/2 | ⚠ | quality-gates test_session_end_cleanup.py·test_qg_gc.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 같은 플러그인 gc/cleanup 테스트군의 공유 fixture 헬퍼 |
| 118 | `test_kill_switch` (py) | 2/2 | ⚠ | quality-gates test_session_end_cleanup.py·test_qg_gc.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | `_disabled`/`kill_switch_active`(#37/#42) 소스 중복의 테스트측 반영 |
| 119 | `assert_body_grep` (sh) | 2/2 | ⚠ | — | 부분 사본 | Task 14 | 〔seed〕 assert_* 패밀리 |
| 120 | `test_empty_session_id_silent_exit` (py) | 2/2 | ⚠ | quality-gates test_session_end_cleanup.py·test_session_tracker.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 훅 계약(빈 session-id 무시)의 테스트가 두 훅에 각각 재구현 |
| 121 | `parse_iso` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | ISO 날짜 파싱, 전부 다름 |
| 122 | `state_file_for` (py) | 2/2 | ⚠ | spec-distill hooks/review-dispatch.py·scripts/arm_ledger.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 같은 플러그인 내부 상태 파일 경로 해석 중복 — seed에 없는 신규 발견 |
| 123 | `find_missing_sections` (py) | 2/2 | ⚠ | spec-distill scripts/check_brief.py·parse_spec_structure.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 같은 플러그인 내부 섹션-검증 유틸 중복 — 신규 발견 |
| 124 | `_frontmatter` (py) | 2/2 | ⚠ | spec-distill scripts/check_brief.py·check_verbatim_coverage.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 같은 플러그인 내부 frontmatter 파싱 유틸 중복 — 신규 발견 |
| 125 | `write_failclosed` (sh) | 2/2 | ⚠ | `run_brief_codex_reviewer.sh`↔`run_spec_codex_reviewer.sh` | 부분 사본 | 공통 조각만 추출 (Task 20·21) | #24 파일쌍 부분 사본의 구성 함수 |
| 126 | `emit_fallback` (sh) | 2/2 | ⚠ | 동일 파일쌍 | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 위와 같음 |
| 127 | `run_validator` (sh) | 2/2 | ⚠ | spec-distill arm_test_helpers.sh·test_stale_state_truncate.sh | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 같은 플러그인 arm-ledger 테스트 하네스 계열 |
| 128 | `scoped_window` (sh) | 2/2 | ⚠ | spec-distill test_reviewing_brief_skill.sh·test_brief_review_entry.sh | 부분 사본 | 공통 조각만 추출 (Task 20·21) | `window`/`fence`(#129/130)와 같은 두 파일에 공존하는 3인조 헬퍼 |
| 129 | `window` (sh) | 2/2 | ⚠ | 동일 파일쌍 | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 위와 같음 |
| 130 | `fence` (sh) | 2/2 | ⚠ | 동일 파일쌍 | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 위와 같음 |
| 131 | `test_7_global_killswitch` (py) | 2/2 | ⚠ | spec-distill test_gc.py·test_session_end_cleanup.py | 부분 사본 | 공통 조각만 추출 (Task 20·21) | `_disabled`(#37) spec-distill측 소스 중복의 테스트 반영 |
| 132 | `_exe` (py) | 2/1 | ✅ | plugin-audit test_check_plugin_structure.py·test_run_own_tests.py | 진짜 사본 | shared/ 정본 + copy-of (Task 15·17·18·19) | 바이트 동일 |
| 133 | `parse_raw_json` (py) | 2/1 | ✅ | qg/spec-distill `codex_findings_to_yaml.py` | 진짜 사본 | #5 통합에 흡수 | 바이트 동일, #5 패밀리 |
| 134 | `has_auth_error` (py) | 2/1 | ✅ | 동일 파일쌍 | 진짜 사본 | #5 통합에 흡수 | 바이트 동일, #5 패밀리 |
| 135 | `get_mtime` (sh) | 2/1 | ✅ | `discover-plan.sh`↔`discover-spec.sh` | 진짜 사본 | #26 통합(Task 22)에 흡수 | 바이트 동일 — 파일 전체는 부분 사본이지만 이 함수 자체는 이미 완전 동일 |
| 136 | `_folder_mtime_ns` (py) | 2/1 | ✅ | qg-gc.py↔spec-distill-gc.py | 진짜 사본 | 공통 조각만 추출(Task 20·21) 중 즉시 흡수 | 바이트 동일 — gc 패밀리(#95/97/98/99/116) 중 유일하게 완전 동일 |
| 137 | `assert_absent` (sh) | 2/1 | ✅ | quality-gates test_adversarial_persona.sh·test_security_reviewer_persona.sh | 진짜 사본 | shared/ 정본 + copy-of (Task 15·17·18·19) | 바이트 동일 — 아래 블록축 #148과 같은 파일쌍 |
| 138 | `fm_of` (sh) | 2/1 | ✅ | quality-gates test_agent_frontmatter_keys.sh, spec-distill test_brief_agents.sh | 진짜 사본 | shared/ 정본 + copy-of (Task 15·17·18·19) | 바이트 동일, 플러그인 경계를 넘음 |
| 139 | `mk_repo_feature_ahead` (sh) | 2/1 | ✅ | quality-gates test_check_review_scope.sh·test_qg_false_clean_floor.sh | 진짜 사본 | shared/ 정본 + copy-of (Task 15·17·18·19) | 바이트 동일 |
| 140 | `make_repo_with_worktree` (sh) | 2/1 | ✅ | quality-gates test_isolation.sh·test_worktree.sh | 진짜 사본 | shared/ 정본 + copy-of (Task 15·17·18·19) | 바이트 동일 |
| 141 | `mkw` (sh) | 2/1 | ✅ | quality-gates test_run_test_selection.sh·test_runner_adapters.sh | 진짜 사본 | shared/ 정본 + copy-of (Task 15·17·18·19) | 바이트 동일 |
| 142 | `rmw` (sh) | 2/1 | ✅ | 동일 파일쌍 | 진짜 사본 | shared/ 정본 + copy-of (Task 15·17·18·19) | 바이트 동일 |
| 143 | `scan_ok` (py) | 2/1 | ✅ | quality-gates test_secret_scan.py·test_secret_scan_fp.py | 진짜 사본 | shared/ 정본 + copy-of (Task 15·17·18·19) | 바이트 동일 |
| 144 | `blocked` (py) | 2/1 | ✅ | 동일 파일쌍 | 진짜 사본 | shared/ 정본 + copy-of (Task 15·17·18·19) | 바이트 동일 |
| 145 | `test_script_exists` (py) | 2/1 | ✅ | spec-distill test_brief_review_state.py·test_merge_brief_review.py | 진짜 사본 | shared/ 정본 + copy-of (Task 15·17·18·19) | 바이트 동일 |

### 축 4 — 동일 텍스트 블록 (blocks.py, 창 20줄/최소 200자)

| # | 후보 | 분류 | 조치 (태스크) | 근거 |
|---|---|---|---|---|
| 146 | `detect_codex.sh` ×3, 39개 블록 공유 | 진짜 사본 | shared/ 정본 + copy-of (Task 15·17·18·19) | 축1 #4와 동일 후보, 블록축이 재확인 |
| 147 | `detect_codex.sh` (plugin-audit↔quality-gates만), 20개 블록 | 진짜 사본 | 위와 동일 흡수 | #146의 부분집합, 별도 조치 아님 |
| 148 | `codex_findings_to_yaml.py` ×2, 17개 블록 | 진짜 사본 | 위와 동일 흡수 | 축1 #5와 동일 후보, 블록축이 재확인 |
| 149 | `pending-review-reminder.py` ↔ `review-dispatch.py` (spec-distill/hooks/), 8개 블록 | 부분 사본 | 공통 조각만 추출 (Task 20·21) | seed에 없는 신규 발견 — 표준입출력 UTF-8 고정 프리앰블 등 8개 블록(≥20줄/200자) 공유, 두 훅의 나머지 로직은 서로 다름 |
| 150 | `test_adversarial_persona.sh` ↔ `test_security_reviewer_persona.sh`, 7개 블록 | 부분 사본 | 공통 조각만 추출 (Task 20·21) | 신규 발견 — 두 페르소나 테스트 파일이 공유 하네스 7블록을 가짐(`assert_absent` 함수 자체는 #137에서 이미 진짜 사본으로 별도 처리) |

## 세드 판단과의 불일치 (discrepancy)

- **`README.md`**: seed는 ×6으로 적었으나 실측은 ×7 (`plugins/plugin-audit/scripts/tests/README.md`가 seed 작성 시점 이후 추가됐거나 누락된 것으로 추정). 분류(우연)는 바뀌지 않음 — 이유는 여전히 "README 컨벤션".
- **`branch-strategy.md`**: seed는 "×3"(우연 그룹)과 "템플릿-인스턴스" 행을 별도로 적어 사실상 4파일을 이미 3+1로 나눠 서술했다. 이 원장은 그 분할을 diff 실측으로 확정하고 파일 경로 단위로 명시했다(#9~11) — 분류 자체의 불일치는 아니고, seed 표기를 표 구조로 풀어낸 것.
- **`codex_findings_to_yaml.py` 계열의 확장**: seed는 quality-gates/spec-distill 2파일만 진짜 사본으로 적었다. 함수축이 `apply_overrides`(#62)·`test_last_fenced_block_wins`(#86)·`test_auth_error_in_stderr`(#87)에서 **plugin-audit의 `codex_audit_to_json.py`**가 같은 파싱 책임(override 적용, fenced-JSON 파싱, auth-error 검출)을 공유함을 드러냈다. 이 파일은 파일축 유사도 임계값(≥60%) 밑이라 축1/축2에는 잡히지 않았지만, 함수·테스트 수준에서는 실측 증거가 있다 — Task 15·17·18·19 착수 시 이 세 함수를 함께 검토할 것을 권고(새 태스크 신설이 아니라 기존 범위의 스코프 확장 후보로 플래그).
- **`kill_switch_active` 패밀리 확장**: seed는 5곳(py)만 적었다. 함수축은 `_disabled`(#37)라는 **다른 이름**으로 동일 책임(kill switch 판정)이 7곳 더 있음을 드러냈다 — 총 12곳. 이름이 다르다는 이유로 census 스크립트 자체는 이 둘을 연결하지 못했다(이름 기반 그룹핑의 구조적 한계); 이 원장에서 실측 grep으로 연결해 진짜 사본으로 통합 분류했다.

## 미배정

(진짜 사본·부분 사본 중 조치가 배정되지 않은 것.)

**없음 — 0건.** 분류표 150행 중 진짜 사본 25행 + 부분 사본 64행 = 89행 전부가 조치 열에 shared/ 통합(Task 15·17·18·19) · 공통 조각 추출(Task 20·21) · Task 14 · Task 22 · 기존 통합에 흡수 중 하나를 명시하고 있다 — "조치 없음"이 찍힌 행은 전부 우연(58행)·템플릿-인스턴스(3행, 재적용+동일성 검사가 조치)뿐이다. 기계적 확인: `grep -E '^\| [0-9]+ \|' census.md`로 진짜/부분 사본 행을 뽑아 조치 열에 "조치 없음"이 하나도 없음을 grep으로 검증(위 실행 로그 참조).
