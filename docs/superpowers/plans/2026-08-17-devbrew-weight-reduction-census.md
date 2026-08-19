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

> **조치 열은 2026-08-17에 전수 재작성됐다.** 최초 판은 조치 열이 **비어 있지 않은지**만 검증했고 거기 적힌 태스크가 그 행의 일을 실제로 하는지는 검증하지 않았다 — 전수 재검토에서 오귀속(형태 ①)과 절반 커버(형태 ②)가 실재했고, 그중 둘은 Task 35의 20줄 락을 **첫 실행에서 RED 로 만들** 참이었다. 판정 열(진짜/부분/우연/템플릿-인스턴스)과 근거 열은 건드리지 않았다 — 바뀐 것은 **누가 그 일을 하는가**뿐이다. 배경·규칙·유예 목록은 아래 §미배정.

## 분류표

### 축 1 — 같은 basename 다중 존재 (census.py §1)

| # | 후보 | 분류 | 조치 (태스크) | 근거 |
|---|---|---|---|---|
| 1 | `__init__.py` ×2 (plugin-audit `scripts/tests/` · **project-init** `hooks/tests/`) | 우연 | 조치 없음 | 바이트 동일이지만 빈 파일 — Python 패키지 마커 컨벤션, 공유 로직 없음. **정정(2026-08-17 fix round 4)**: 이전 판이 두 번째를 `spec-distill` 이라 적었는데 고정 SHA 코퍼스에 spec-distill `__init__.py` 는 **없다** (`git ls-tree -r --name-only <SHA> \| grep __init__.py` → plugin-audit · project-init, 그리고 agent-transparency `fixtures/` 2개는 코퍼스 제외). `×2` 는 맞다 |
| 2 | `pr-process.md` ×2 (docs/git-workflow ↔ project-init/templates/shared) | 템플릿-인스턴스 | 재적용+동일성 검사 | 99.4% 유사, `{{...}}` 치환 없이 거의 그대로 복제된 canonical 문서의 템플릿 배포본 |
| 3 | `commit-conventions.md` ×2 (동일 쌍) | 템플릿-인스턴스 | 재적용+동일성 검사 | 91.0% 유사, 위와 같은 관계 |
| 4 | `detect_codex.sh` ×3 (plugin-audit/quality-gates/spec-distill) | 진짜 사본 | shared/ 정본 + 심볼릭 링크 (**Task 15**) | 〔seed〕 diff는 헤더 프로즈 3종 + kill switch 변수명 1줄 + 주석 1줄뿐 |
| 5 | `codex_findings_to_yaml.py` ×2 (quality-gates/spec-distill) | 진짜 사본 | shared/ 정본 + 심볼릭 링크 (**Task 17**) | 〔seed〕 유일한 행동 차이는 emit keyset(`category`·`target_section`) |
| 6 | `hooks.json` ×3 (project-init/quality-gates/spec-distill) | 우연 | 조치 없음 | `.claude-plugin` 매니페스트 파일명은 플랫폼 강제, 각 플러그인이 실제로 등록하는 훅 집합이 다름(27/45/50줄, description도 상이) — 실측 확인 |
| 7 | `session-end-cleanup.py` ×2 (quality-gates/spec-distill) | 부분 사본 | 공통 조각만 추출 (**Task 21**) | 〔seed〕 각자 kill switch 토큰 + `sys.path.insert`; qg는 worktree 정리까지 |
| 8 | `test_detect_codex.sh` ×2 (120 vs 54줄) | 부분 사본 | 판정 헬퍼(`ag`) 이관 = **Task 14** · 잔여(커버 범위 차이)는 **유예 E** — 120줄/54줄 두 스위트의 assertion 을 **어느 쪽도 지울 수 없어**(C10) 통합이 순증. §12.4 임계 미만 — 실측 | 〔seed〕 같은 대상을 재지만 커버 범위가 다름 |
| 9 | `branch-strategy.md`: `docs/git-workflow/` ↔ `project-init/templates/github-flow/` | 템플릿-인스턴스 | 재적용+동일성 검사 | 실측(diff) 확인: 63줄 vs 63줄, 유일한 차이는 63번째 줄 rebase 조항 프로즈뿐(94.6%) — 〔seed〕 "의도된 차이 — 통합하지 않는다" |
| 10 | `branch-strategy.md`: `docs/git-workflow/` ↔ `project-init/templates/{git-flow,trunk-based}/` | 우연 | 조치 없음 | 34.6%/38.4% — git-flow(99줄)·trunk-based(120줄)는 길이부터 다른 별개 전략 문서 |
| 11 | `branch-strategy.md`: project-init 템플릿 3종(`git-flow`↔`github-flow`↔`trunk-based`) 상호 | 우연 | 조치 없음 | 〔seed〕 git 전략별 변형 — 설계상 서로 달라야 함 (git-flow↔trunk-based 26.1%~40.2%) |
| 12 | `post-tool-use.py` ×2 (219 vs 103줄) | 우연 | 조치 없음 | 〔seed〕 하는 일이 다름 (project-init=문서 린트, qg=세션 추적) |
| 13 | `test_session_end_cleanup.py` ×2 | 부분 사본 | **유예 B** (python 테스트 헬퍼) — python 테스트 헬퍼의 **정본 자리를 이 사이클이 만들지 않는다**(설계 §9는 셸 판정 헬퍼 한정). §12.4 임계 미만 — 실측 | 〔seed〕 `session-end-cleanup.py`와 같은 이유 |
| 14 | `plugin.json` ×5 (전 플러그인) | 우연 | 조치 없음 | `.claude-plugin/plugin.json` 파일명은 플랫폼 강제; name/version/description은 플러그인마다 본질적으로 다름(유사도 7~27%) |
| 15 | `agents-md-section.md` ×4 (project-init 템플릿) | 우연 | 조치 없음 | 〔seed〕 git 전략별 변형 — 설계상 서로 달라야 함 |
| 16 | `observed.md` ×2 (docs/audits/*) | 우연 | 조치 없음 | 감사 리포트 컨벤션 파일명, 각 감사의 관측 내용은 고유 (유사도 3.7%) |
| 17 | `manifest.md` ×4 (docs/audits/*) | 우연 | 조치 없음 | 위와 같은 감사 리포트 컨벤션, 유사도 2.4~5.9% |
| 18 | `.gitignore` ×2 (root ↔ plugins/agent-transparency) | 우연 | 조치 없음 | 루트(228줄, 리포 전역) vs 플러그인 로컬(2줄, 상태파일 전용) — 스코프 자체가 다름 |
| 19 | `SKILL.md` ×8 (전 플러그인) | 우연 | 조치 없음 | 〔seed〕 플랫폼이 이름을 강제 |
| 20 | `README.md` ×7 | 우연 | 조치 없음 | 〔seed는 ×6으로 적었으나 실측 ×7 — **불일치**(원인 정정), 아래 §discrepancy 참조〕 README 컨벤션이 이름을 강제, 각 파일 유사도 0.6~6.8%로 내용은 독립적 |

### 축 2 — 다른 basename, 유사쌍 ≥60% (census.py §2)

| # | 후보 | 분류 | 조치 (태스크) | 근거 |
|---|---|---|---|---|
| 21 | `2026-07-16-law2-baseline.txt` ↔ `2026-07-16-law2-after-baseline.txt` (98.3%) | 우연 | 조치 없음 | 실측 확인: 과거 PR(law2-agent-tool-surface)의 테스트 실행 로그 before/after 스냅샷. 코드가 아니라 얼어붙은 이력 증거 — 유사도가 높은 것 자체가 의도(같은 스위트를 두 시점에 캡처) |
| 22 | `test_coverage_mapper_frontmatter.sh` ↔ `test_spec_reviewer_frontmatter.sh` (81.4%) | 부분 사본 | 공통 조각(`note`) 이관 = **Task 14** (설계 §6.1③ "frontmatter 검사군") | 서로 다른 agent의 frontmatter를 검증하는 같은 테스트 패턴 — 공유 가능한 골격 |
| 23 | `test_blind_spot_prober_frontmatter.sh` ↔ `test_coverage_mapper_frontmatter.sh` (76.4%) | 부분 사본 | 공통 조각(`note`) 이관 = **Task 14** (설계 §6.1③ "frontmatter 검사군") | 위와 같은 frontmatter 테스트 패밀리 |
| 24 | `run_brief_codex_reviewer.sh` ↔ `run_spec_codex_reviewer.sh` (74.0%) | 부분 사본 | 공통 조각만 추출 (**Task 20 Step 3b**) — `write_failclosed` 만. `emit_fallback` 은 #126 참조 | spec-distill 내 codex 리뷰 실행 스크립트, 대상 산출물(brief vs spec)만 다름 — `write_failclosed`·`emit_fallback` 함수가 두 파일에 그대로 복제(§3 #99–100 참조) |
| 25 | `test_artifact_adversarial_frontmatter.sh` ↔ `test_artifact_critic_frontmatter.sh` (72.6%) | 부분 사본 | 공통 조각(`ag`·`ng`) 이관 = **Task 14** (설계 §6.1③ "frontmatter 검사군"; 넓힌 도출이 잡는 11파일에 포함) | 위와 같은 frontmatter 테스트 패밀리(quality-gates 쪽) |
| 26 | `discover-plan.sh` ↔ `discover-spec.sh` (63.8%) | 부분 사본 | 공통 조각만 추출 (Task 22) | 〔seed〕 같은 플러그인 내, 파일 하나 source로 소멸 → Task 22 |

### 축 3 — 2곳 이상에서 정의된 함수 (funcs.py)

세 그룹으로 나눠 적는다: (A) seed에 이미 있는 것, (B) census가 새로 드러낸 실측 근거 있는 것(진짜/부분 사본으로 승격), (C) 나머지 범용 이름(우연, funcs.py 저자 주석의 기본 가정을 따름 — "이 축은 범용 이름이 지배한다"). 판정 열의 ✅/◐/⚠는 census 원본의 본문-동일성 표기(전부 동일/부분 동일/전부 다름)를 그대로 인용.

| # | 함수 (언어) | 정의수/변형 | 판정 | 위치(실측 확인) | 분류 | 조치 | 근거 |
|---|---|---|---|---|---|---|---|
| 27 | `setUp` (py) | 77/51 | ◐ | (다수; 무작위 표본 3건: `test_arm_ledger.py`·`test_qg_gc.py`·`test_hook_output_schema.py`; 최대 동일-본문 그룹 실측: `test_ab_runner_contract.py` 단일 파일 내 10회) | 우연 | 조치 없음 | 〔seed〕 unittest API 컨벤션 — **정정(fix round 2 자체 재검증)**: 이전 판이 부분 동일(27곳)을 "표준 boilerplate의 우연 중첩"이라 적었는데, 실제로 재측정하니 가장 큰 동일-본문 묶음(`self.judge = load_judge()`, 10곳)은 **전부 `test_ab_runner_contract.py` 한 파일 안**의 서로 다른 테스트 클래스들이다 — 크로스 파일 우연 수렴이 아니라 한 파일 내부의 반복(#44/#55/#56/#73과 같은 패턴). 무작위 표본 3건(다른 파일들)은 여전히 서로 다른 본문(repo fixture/tempdir/temp-repo 생성)이라 크로스 파일 쌍은 우연이 맞음 — 다만 27곳의 "왜 부분 동일한가"의 주된 원인은 단일 파일 반복이었다는 점을 정정 |
| 28 | `main` (py) | 58/57 | ◐ | (다수, 무작위 표본 2건 실측: `secret-scan.py`·`check_verbatim_coverage.py`) | 우연 | 조치 없음 | 〔seed〕 각 스크립트의 고유 entry point — 표본 2건 실측 확인: argparse 기반 vs sys.argv 기반, 완전히 다른 CLI 골격 |
| 29 | `note` (sh) | 55/13 | ◐ | — | 부분 사본 | Task 14 | 〔seed〕 판정 헬퍼 패밀리 |
| 30 | `fail` (sh) | 36/12 | ◐ | — | 부분 사본 | Task 14 | 〔seed〕 판정 헬퍼 패밀리 |
| 31 | `pass` (sh) | 34/6 | ◐ | — | 부분 사본 | Task 14 | 〔seed〕 판정 헬퍼 패밀리 |
| 32 | `ok` (sh) | 19/6 | ◐ | — | 부분 사본 | Task 14 | 〔seed〕 판정 헬퍼 패밀리 |
| 33 | `run` (py) | 15/15 | ⚠ | — | 우연 | 조치 없음 | 〔seed〕 범용 이름, 스크립트마다 다른 책임 |
| 34 | `tearDown` (py) | 15/10 | ◐ | (다수; 무작위 표본 3건: `test_session_end_cleanup.py`·`test_run_audit_codex_reviewer.py`·`test_arm_ledger.py`; 최대 동일-본문 그룹 실측: `test_arm_ledger.py` 단일 파일 내 5회) | 우연 | 조치 없음 | 〔seed〕 unittest 컨벤션, `setUp`과 동일 이유 — **정정(fix round 2 자체 재검증)**: `setUp`(#27)과 같은 문제를 발견 — 가장 큰 동일-본문 묶음(`os.chdir(self.cwd); shutil.rmtree(self.repo, ignore_errors=True)`, 5곳)은 **전부 `test_arm_ledger.py` 한 파일 안**이다. 크로스 파일 표본 3건은 여전히 서로 다른 본문이라 크로스 파일 쌍은 우연이 맞지만, 15/10의 부분 동일 원인은 단일 파일 반복이 주된 기여자였다는 점을 정정 |
| 35 | `no` (sh) | 15/5 | ◐ | — | 부분 사본 | Task 14 | 〔seed〕 판정 헬퍼 패밀리 |
| 36 | `run_hook` (py) | 7/7 | ⚠ | quality-gates test_session_end_cleanup.py 외 3 · project-init hooks/tests 2 · spec-distill 1 | 부분 사본 | **유예 B** (python 테스트 헬퍼) — python 테스트 헬퍼의 **정본 자리를 이 사이클이 만들지 않는다**(설계 §9는 셸 판정 헬퍼 한정). §12.4 임계 미만 — 실측 | 실측: 두 샘플 모두 `subprocess.run([sys.executable, HOOK], input=json.dumps(payload), env=...)` 골격 동일, env 처리만 상이 — 3개 플러그인에 흩어진 훅-실행 테스트 헬퍼 |
| 37 | `_disabled` (py) | 7/7 | ⚠ | qg post-tool-use.py·post-tool-use-session-tracker.py·session-start-advisor.py·session-end-cleanup.py·qg-gc.py, spec-distill session-end-cleanup.py·spec-distill-gc.py | **진짜 사본** | shared/ 정본 + copy-of (**Task 19** — `_disabled` 7곳을 이 태스크가 명시적으로 담는다) | 실측: 전부 `os.environ.get("DEVBREW_DISABLE_<PLUGIN>") == "1"` 반환 — `kill_switch_active`(#42)와 **동일 책임의 다른 이름**. CLAUDE.md가 보안 컨트롤로 규정한 kill switch 판정이 함수명 2종(kill_switch_active/​_disabled)·파일 12곳에 흩어져 있음 — census 함수축이 seed의 5곳 집계를 7곳 더 확장 |
| 38 | `emit` (py) | 6/6 | ⚠ | agent-transparency `prepare_standup.py`, plugin-audit `check-staleness.py`·`codex_audit_to_json.py`, project-init `docs-lint.py`, spec-distill `merge_review.py`·`merge_brief_review.py` — **6곳** | 우연 | 조치 없음 | 각 스크립트의 출력 포맷(구조화 finding/YAML/JSON)이 서로 다름 — "출력하다" 범용 동사 |
| 39 | `check` (sh) | 6/4 | ◐ | — | 부분 사본 | Task 14 (정본 이름은 Task 13 Interfaces 의 대응표) | 3곳이 바이트 동일한 하위집합 존재(◐ 표기 자체가 그 증거) — note/fail/pass류와 같은 판정-헬퍼 계열로 판단 |
| 40 | `field` (sh) | 6/4 | ◐ | — | 부분 사본 | Task 14 | 〔seed〕 구현이 awk 2종·sed 1종, 인자 순서까지 다름 |
| 41 | `_degrade_if_empty` (sh) | 5/5 | ⚠ | — | 부분 사본 | 공통 조각만 추출 (**Task 20 — 완료**) | 〔seed〕 5러너가 각자 다른 프롬프트 빌더를 부름. 출력 스키마 4종 중 **중첩 YAML 계열 셋만** `shared/codex/runner_common.sh` 로 통일됐다. 감사 러너(JSON 소비자)·아티팩트 러너(평면 YAML fail-closed 백스톱)는 소비자 계약이 달라 **의도적으로 제외** — 남은 작업이 아니다(설계 §6.2 정정) |
| 42 | `kill_switch_active` (py) | 5/5 | ⚠ | — | **진짜 사본** | shared/ 정본 + copy-of (**Task 19**) | 〔seed〕 같은 책임(kill switch 판정), 본문 5종 전부 다름 = drift. `_disabled`(#37)와 합쳐 12곳 |
| 43 | `run_case` (sh) | 5/5 | ⚠ | quality-gates test_synthesize_findings.sh·test_scout_script.sh·test_check_trivia.sh·test_read_frontmatter.sh·test_pr_detect.sh | 우연 | 조치 없음 | 실측: 파라미터 시그니처가 파일마다 근본적으로 다름(`name adv_yaml findings_yaml ...` vs `name setup_fn expected_exit ...`) — 이름만 "테스트케이스 실행"이라는 자연스러운 관례를 공유, 로직 추출 불가 |
| 44 | `_plugin` (py) | 5/4 | ◐ | plugin-audit test_check_staleness.py (단일 파일 내 5회) | 우연 | 조치 없음 | 실측: **같은 파일 안** 서로 다른 테스트 클래스의 fixture 빌더 메서드 — 파일간 중복 아님 |
| 45 | `_yaml_scalar` (py) | 5/4 | ◐ | qg codex_findings_to_yaml.py, spec-distill codex_findings_to_yaml.py·merge_brief_review.py·brief_review_state.py·merge_review.py | 부분 사본 | **Task 17**(codex_findings_to_yaml.py 2곳은 심볼릭 링크로 소멸) + **Task 22 Step 2c**(spec-distill 3곳 — 실측된 drift 를 합집합으로) | YAML 스칼라 이스케이프 유틸이 quality-gates 1곳 + spec-distill 4개 스크립트에 반복 구현, 5곳 중 2곳만 바이트 동일 |
| 46 | `ag` (sh) | 5/4 | ◐ | — | 부분 사본 | Task 14 (정본 이름은 Task 13 Interfaces 의 대응표) | 〔seed〕 판정 헬퍼 패밀리 명시 |
| 47 | `render` (py) | 4/4 | ⚠ | plugin-audit render-audit-report.py 외, quality-gates synthesize_findings.py | 우연 | 조치 없음 | 감사 리포트 렌더링 vs findings 렌더링 — 템플릿 대상이 근본적으로 다름 |
| 48 | `assert_grep` (sh) | 4/4 | ⚠ | — | 부분 사본 | Task 14 | 〔seed〕 assert_* 패밀리 |
| 49 | `mk_repo` (sh) | 4/4 | ⚠ | quality-gates `test_resolve_baseline.sh`·`test_diagram_facts.sh`·`test_qg_runtime_sandbox.sh`·`test_build_pr_context.sh` | 우연 | 조치 없음 | 실측(4개 본문 전부 판독): 각기 다른 커밋/파일 레이아웃(base+feature 1커밋 / src/db.py+other.py / tracked.txt+src_app.js / db.py+api.py)을 만듦 — fixture 리포 빌더, 시나리오마다 실제로 다른 git 상태 |
| 50 | `run_hook` (sh) | 4/4 | ⚠ | spec-distill test_spec_write_validator.sh·test_design_mode_validator.sh·test_reminder_hook.sh·test_review_dispatch.sh | 부분 사본 | **유예 A** (셸 하네스) — 설계 §9의 `shared/tests/` 는 **판정 헬퍼**의 자리이고 그 근거는 소유 관계(*"판정 헬퍼는 어느 한 플러그인의 것이 아니다"*)인데, 훅 실행 래퍼·ledger 하네스는 **그 플러그인 자신의 것**이라 근거가 옮겨가지 않는다. §12.4 임계 미만 — 실측 〔실측: 8줄/5줄, 본문 상이〕 | 실측: `env -i HOME=... PATH=... bash -c "echo PAYLOAD \| python3 HOOK"` 골격 동일, payload만 상이 — `run_hook`(py, #36)과 대칭되는 sh쪽 훅-실행 테스트 헬퍼 |
| 51 | `assert_contains` (sh) | 4/3 | ◐ | — | 부분 사본 | Task 14 | 〔seed〕 assert_* 패밀리 |
| 52 | `assert_eq` (sh) | 4/2 | ◐ | — | 부분 사본 | Task 14 | 〔seed〕 assert_* 패밀리, 3곳 이미 일치 |
| 53 | `_run` (py) | 3/3 | ⚠ | agent-transparency `scripts/prepare_standup.py`, plugin-audit `scripts/tests/test_run_audit_codex_reviewer.py`, spec-distill `tests/test_arm_ledger.py` | 우연 | 조치 없음 | 실측(3개 본문 전부 판독): 타임아웃 불변식 있는 스크립트-레벨 subprocess 래퍼 / PATH-mock 교체 테스트 헬퍼 / env 정리 테스트 헬퍼 — 시그니처·목적 전부 다름 |
| 54 | `cleanup` (sh) | 3/3 | ⚠ | agent-transparency `tests/ab_gate.sh`, quality-gates `test_resolve_baseline.sh`·`test_qa_ledger.sh` | 우연 | 조치 없음 | **정정(fix round 2 자체 재검증)**: 이전 판이 3곳 전부 "`cleanup() { rm -rf "$TARGET"; }` 형태의 1줄 관용구"라 적었는데 `$TARGET`은 실제 코드에 없는 가상의 변수명이었고, `ab_gate.sh`는 1줄이 아니다. 실측: `test_resolve_baseline.sh`는 `cleanup() { cd / && rm -rf "$REPO"; }`, `test_qa_ledger.sh`는 `cleanup() { rm -rf "$TMP"; }` — 이 둘만 1줄. `ab_gate.sh`는 `[ -n "$FX" ] && rm -rf "$FX"` 형태로 4개 변수를 조건부로 지우는 여러 줄짜리 함수라 나머지 둘과 구조 자체가 다름 — 3곳 모두 진짜로 다른 코드, 너무 사소해 추출 가치도 없음 |
| 55 | `assistant` (py) | 3/3 | ⚠ | **agent-transparency `tests/test_ab_runner_contract.py` 단일 파일 내 3회**(L903·L936·L1699) | 우연 | 조치 없음 | 실측: 같은 파일 안 서로 다른 테스트의 지역 헬퍼 함수 — 파일간 중복 아님(Minor 1 수정: #44/#75/#77처럼 단일 파일 내 공존 명시) |
| 56 | `boom` (py) | 3/3 | ⚠ | **agent-transparency `tests/test_prepare_standup.py` 단일 파일 내 3회**(L359·L1107·L1150) | 우연 | 조치 없음 | 실측: 같은 파일 안 서로 다른 테스트의 지역 예외-유발 스텁 — 파일간 중복 아님(Minor 1 수정) |
| 57 | `check` (py) | 3/3 | ⚠ | plugin-audit `scripts/check-shape-completeness.py`, quality-gates `scripts/check_qa_ledger.py`, spec-distill `scripts/probe_budget.py` | 우연 | 조치 없음 | 〔seed〕 범용 이름 — 실측(3개 본문 전부 판독): 플러그인 shape 갭 검사 / QA ledger attribution 검사 / budget-probe 상태 검사, 시그니처도 전부 다름 |
| 58 | `extract_last_agent_message` (py) | 3/3 | ⚠ | plugin-audit `codex_audit_to_json.py:34`, quality-gates `codex_findings_to_yaml.py:35`, spec-distill `codex_findings_to_yaml.py:34` | **진짜 사본** | shared/ 정본 + copy-of (**Task 17 Step 4b** — `shared/codex/codex_jsonl.py`, plugin-audit `codex_audit_to_json.py` 포함) | 실측(세 본문 전부 판독): JSONL을 줄 단위로 순회, 두 이벤트 shape(codex 0.130+의 `item.completed`/legacy `agent_message`)을 파싱해 마지막 `agent_message` 텍스트를 뽑고 `(text, any_parsed)`를 반환하는 **동일 알고리즘**. 변수명(`text`/`last_text`, `obj`/`ev`)과 docstring 언어(한국어/영어, Task 0 spike 각주 유무)만 다름 — plugin-audit판만 `candidate.strip()` 공백 가드가 하나 더 있으나 로직 골격은 동일. #62 `apply_overrides`/#86 `test_last_fenced_block_wins`/#87 `test_auth_error_in_stderr`와 같은 발견 — codex_findings_to_yaml.py 계열(#5)이 plugin-audit의 `codex_audit_to_json.py`까지 확장됨을 다시 확인 |
| 59 | `emit` (sh) | 3/3 | ⚠ | plugin-audit run-own-tests.sh, quality-gates test_codex_prompt_untrusted_clause.sh·detect-runtime.sh | 우연 | 조치 없음 | 각자 다른 출력 포맷의 "출력하다" 범용 동사 |
| 60 | `die` (sh) | 3/3 | ⚠ | quality-gates `baseline-cache.sh`·`run-test-selection.sh`·`qg-worktree.sh` | 우연 | 조치 없음 | 실측: 전부 `die() { echo "<script>: $*" >&2; exit 2; }` 1줄 관용구 — 스크립트 이름만 하드코딩돼 다름, 너무 사소해 추출 가치 없음 |
| 61 | `has` (sh) | 3/3 | ⚠ | quality-gates `test_review_scope_composition.sh`, spec-distill `test_conducting_interview_stage.sh`·`test_reviewing_brief_skill.sh` | 우연 | 조치 없음 | 실측(3개 본문 전부 판독): `grep -qF "$2" "$SKILL"`(파일 대상) / `grep -qiE "$1" "$SKILL" && note ...`(note 호출) / `grep -qF -- "$2" <<<"$1"`(변수 대상) — grep 플래그·대상·부수효과 전부 다름 |
| 62 | `apply_overrides` (py) | 3/2 | ◐ | plugin-audit codex_audit_to_json.py, quality-gates codex_findings_to_yaml.py, spec-distill codex_findings_to_yaml.py | 부분 사본 | **유예 D** (통합이 동작 변경) — **Task 17 Step 4b 가 같은 3파일을 다루지만 `apply_overrides` 는 옮기지 않는다.** 실측: plugin-audit 판은 `main()` 안 **중첩 함수**(`codex_audit_to_json.py:155`)이고 소비하는 meta 키가 다른 두 판과 다르다 — 시그니처만 같다. 합치려면 세 소비자의 meta 계약을 하나로 정해야 하므로 별개 결정이다(#126과 같은 부류). 결정 자체는 Task 17 Step 4b 에 기록된다. §12.4 임계 미만 — 실측(pa↔qg 최장 공유 7줄) | 실측: `def apply_overrides(meta: dict) -> dict:` 동일 시그니처가 3개 스크립트에 — `codex_findings_to_yaml.py` ×2 진짜 사본(#5) 패밀리가 plugin-audit의 `codex_audit_to_json.py`까지 확장됨을 보여주는 근거. **불일치 항목**(§discrepancy) |
| 63 | `ng` (sh) | 3/2 | ◐ | — | 부분 사본 | Task 14 (정본 이름은 Task 13 Interfaces 의 대응표) | 〔seed〕 판정 헬퍼 패밀리 |
| 64 | `emit_skip` (sh) | 3/1 | ✅ | detect_codex.sh ×3 | 진짜 사본 | `detect_codex.sh` 통합에 흡수 (**Task 15**) | 〔seed〕 detect_codex.sh 안에만 존재 — 파일 통합으로 소멸 |
| 65 | `_ver_lt` (sh) | 3/1 | ✅ | detect_codex.sh ×3 | 진짜 사본 | `detect_codex.sh` 통합에 흡수 (**Task 15**) | 〔seed〕 위와 같음 |
| 66 | `read_records` (py) | 2/2 | ⚠ | agent-transparency `tests/ab_judge.py`, `scripts/prepare_standup.py` | 부분 사본 | **유예 D** (통합이 동작 변경) — 두 본문의 **계약이 다르다**. 합치는 것은 소비자 동작을 바꾸는 별개 결정이다(§15.1). §12.4 임계 미만 — 실측 실측: `ab_judge.py` 의 docstring 이 `prepare_standup.py` 를 지칭하며 *"같은 형식에 대해 정반대 결정을 내린다"* 고 **명시**한다 — 의도된 분기다. | **정정(fix round 2)**: 이전 판이 "파싱 실패 줄 수를 함께 반환하는 같은 shape"이라 적었는데 반환 계약은 실제로 다르다 — `ab_judge.py`는 `records`(list)만 반환하고 손상 줄 수는 지역 변수 `broken`으로만 세어 stderr 경고 후 버림(OSError 가드 없음), `prepare_standup.py`는 `(records, unparsed, found)` 3-tuple을 반환하고 `except OSError: return [], 0, False` 가드가 있음. 실제로 같은 것은 **알고리즘 골격**(JSONL을 줄 단위로 순회, `json.loads` 실패를 카운트)과 `ab_judge.py`의 docstring이 `prepare_standup.py`를 명시적으로 지칭하며 "같은 형식에 대해 정반대 결정을 내린다"고 서술한 **문서화된 형제 관계**다 — 분류(부분 사본)는 이 문서화된 관계 때문에 유지, "같은 shape" 서술만 삭제 |
| 67 | `classify` (py) | 2/2 | ⚠ | agent-transparency `scripts/prepare_standup.py`, quality-gates `scripts/classify_artifact_target.py` | 우연 | 조치 없음 | 실측: standup 후보의 git-common-dir 채택 판정 vs artifact 경로의 디렉터리/파일 종류 판정 — 시그니처·목적 전부 다름 |
| 68 | `collect` (py) | 2/2 | ⚠ | agent-transparency `scripts/prepare_standup.py`, quality-gates `tests/lib/extract_codex_invocations.py` | 우연 | 조치 없음 | 실측: standup 인벤토리 원자료 수집 vs codex 호출 후보 파일 수집 — 시그니처·목적 전부 다름 |
| 69 | `digest` (py) | 2/2 | ⚠ | agent-transparency `tests/ab_seal.py`(모듈 함수) vs `tests/test_ab_runner_contract.py`(테스트 메서드) | 우연 | 조치 없음 | 실측: 전자는 `<파일수>:<sha256>` 계산하는 독립 해시 함수, 후자는 seal 스크립트를 실행해 그 출력을 검증만 하는 테스트 메서드 — 책임이 다름(하나는 구현, 하나는 그 구현의 소비자) |
| 70 | `section` (py) | 2/2 | ⚠ | project-init `hooks/tests/test_command_contract.py`, agent-transparency `tests/test_ab_runner_contract.py` | 우연 | 조치 없음 | 실측: project-init 쪽은 2-마커(start/end) 사이 본문 추출, agent-transparency 쪽은 단일 heading부터 다음 `## `까지 추출 — 이 쌍(project-init↔agent-transparency) 자체는 서로 다른 알고리즘. 단, agent-transparency의 이 본문은 #76 `section_of`와 사실상 동일 함수를 다른 이름으로 재구현한 것 — 크로스 이름 중복은 #76에서 처리 |
| 71 | `load_module` (py) | 2/2 | ⚠ | quality-gates `test_diff_test_results.py`, agent-transparency `test_ab_runner_contract.py` | 우연 | 조치 없음 | 실측: 둘 다 Python 표준 문서의 "파일 경로로 모듈 로드" 관용구(`importlib.util.spec_from_file_location`+`module_from_spec`+`exec_module`)를 쓰지만, 하나는 무인자(고정 전역 SCRIPT 사용)고 하나는 `(path, name)` 파라미터화 — 표준 관용구 수렴, 실질 로직 공유 없음 |
| 72 | `test_the_fixture_actually_separates_the_two_readings` (py) | 2/2 | ⚠ | agent-transparency test_ab_runner_contract.py·test_prepare_standup.py | 부분 사본 | **유예 B** (python 테스트 헬퍼) — python 테스트 헬퍼의 **정본 자리를 이 사이클이 만들지 않는다**(설계 §9는 셸 판정 헬퍼 한정). §12.4 임계 미만 — 실측 | 이례적으로 구체적인 테스트명이 서로 다른 두 파일에 재사용 — 우연으로 보기엔 이름이 너무 특수함, 같은 fixture-분리 불변식을 각각 재검증하는 것으로 판단 |
| 73 | `drive` (py) | 2/2 | ⚠ | **agent-transparency `tests/test_ab_runner_contract.py` 단일 파일 내 2회**(L1201 `drive(self, expect, *modules)`·L1392 `drive(self)`) | 우연 | 조치 없음 | 실측: 같은 파일 안 서로 다른 클래스/시그니처의 메서드 — 파일간 중복 아님(#44/#55/#56/#75/#77과 같은 단일 파일 패턴) |
| 74 | `read` (py) | 2/2 | ⚠ | agent-transparency `tests/test_plugin_contract.py`, plugin-audit `scripts/tests/test_agents_generic.py` | 진짜 사본 | **유예 C** (1~3줄 관용구) — 정본으로 빼면 소비 지점마다 import/source 1줄이 생겨 **순증**. §12.4 임계 미만 — 실측 실측: 양쪽 다 1줄(`(BASE / x).read_text(encoding="utf-8")`). | 실측: 양쪽 다 `(BASE_DIR / x).read_text(encoding="utf-8")` 한 줄짜리 — 파라미터명(`rel`/`name`)과 베이스 디렉터리 상수(`PLUGIN_DIR`/`AGENTS`)만 다르고 베이스 디렉터리를 인자로 빼면 바이트 동일. 〔seed는 범용 이름으로 우연 처리했으나 실측 결과 뒤집음〕 |
| 75 | `test_real_skill_has_no_problems` (py) | 2/2 | ⚠ | agent-transparency test_plugin_contract.py (단일 파일 내 2회) | 우연 | 조치 없음 | 실측: 같은 파일 안 서로 다른 클래스의 테스트 — 파일간 중복 아님 |
| 76 | `section_of` (py) | 2/2 | ⚠ | agent-transparency `tests/test_plugin_contract.py`, `tests/test_readability_parity.py` | 부분 사본 | **유예 B** (python 테스트 헬퍼) — python 테스트 헬퍼의 **정본 자리를 이 사이클이 만들지 않는다**(설계 §9는 셸 판정 헬퍼 한정). §12.4 임계 미만 — 실측 | 실측: 둘 다 "`## <heading>` 부터 다음 `## ` 까지" 같은 docstring, 같은 알고리즘. 게다가 **`test_plugin_contract.py`의 이 본문은 #70 `section`(agent-transparency `test_ab_runner_contract.py`)과 변수명까지 사실상 동일** — 이름 기반 그룹핑(funcs.py)이 놓친 3-way 교차이름 중복(§discrepancy 참조). `test_readability_parity.py` 쪽만 `.find()`+가드로 에러 처리가 다름 |
| 77 | `test_four_line_format` (py) | 2/2 | ⚠ | agent-transparency test_plugin_contract.py (단일 파일 내 2회) | 우연 | 조치 없음 | 실측: 같은 파일 안 서로 다른 클래스 — 파일간 중복 아님 |
| 78 | `git` (py) | 2/2 | ⚠ | agent-transparency `tests/test_prepare_standup.py`, plugin-audit `scripts/tests/test_check_integrity.py` | 부분 사본 | **유예 B** (python 테스트 헬퍼) — python 테스트 헬퍼의 **정본 자리를 이 사이클이 만들지 않는다**(설계 §9는 셸 판정 헬퍼 한정). §12.4 임계 미만 — 실측 | 실측: 둘 다 `subprocess.run(["git", ...], cwd=..., check=True, ...)` 얇은 래퍼 — 인자 순서(`git(cwd, *a)` vs `git(*args, cwd)`)와 출력 억제 방식(`capture_output=True` vs `stdout/stderr=DEVNULL`)만 다름. 판단 갈림, 무거운 쪽 |
| 79 | `line_for` (py) | 2/2 | ⚠ | — | 우연 | 조치 없음 | 범용 이름, 전부 다름 |
| 80 | `_norm` (py) | 2/2 | ⚠ | plugin-audit `scripts/check-grounding.py`, quality-gates `scripts/synthesize_artifact_findings.py` | 우연 | 조치 없음 | 실측: 전자는 공백만 정규화(`WS.sub(" ", s).strip()`), 후자는 공백+소문자화+None가드까지 하는 dedup-key용 정규화 — 정규화 강도·목적이 다름 |
| 81 | `resolve` (sh) | 2/2 | ⚠ | plugin-audit `scripts/check-plugin-structure.sh`, quality-gates `scripts/diagram-facts.sh` | 우연 | 조치 없음 | 실측: 전자는 스크립트 basename → 플러그인 캐시 경로 탐색, 후자는 import 토큰 → 후보 파일 확장자 추측 — 완전히 다른 알고리즘 |
| 82 | `_read` (py) | 2/2 | ⚠ | plugin-audit `scripts/check-shape-completeness.py`, spec-distill `scripts/brief_review_state.py` | 부분 사본 | **유예 D** (통합이 동작 변경) — 두 본문의 **계약이 다르다**. 합치는 것은 소비자 동작을 바꾸는 별개 결정이다(§15.1). §12.4 임계 미만 — 실측 실측: plugin-audit 는 3종 예외를 흡수해 `None` 반환(fail-soft), spec-distill 은 무가드(fail-loud). | 실측: 같은 목적(UTF-8 파일 읽기)이나 에러 계약이 다름 — plugin-audit는 3종 예외를 흡수해 `None` 반환(fail-soft), spec-distill은 무가드 1줄(fail-loud). 판단 갈림, 무거운 쪽 |
| 83 | `parse` (py) | 2/2 | ⚠ | plugin-audit `scripts/parse-seed.py`, spec-distill `scripts/brief_review_state.py` | 우연 | 조치 없음 | 〔seed〕 범용 이름 — 실측(2개 본문 전부 판독): seed 파일 파서(dict+warnings 반환) vs brief-review 상태 3키 파서(fail-closed ValueError 계약) — 대상 포맷·반환 계약 전부 다름 |
| 84 | `_load` (py) | 2/2 | ⚠ | plugin-audit `scripts/tests/test_check_grounding.py`, quality-gates `scripts/synthesize_artifact_findings.py` | 우연 | 조치 없음 | 실측: 전자는 동적 모듈 import 실행, 후자는 YAML 파일을 `yaml.safe_load`로 읽기 — 완전히 다른 목적 |
| 85 | `test_deterministic` (py) | 2/2 | ⚠ | plugin-audit test_check_integrity.py, spec-distill test_compute_issue_id.py | 우연 | 조치 없음 | 실측: 무결성 검사 vs issue-ID 계산 — 완전히 다른 대상, "결정론 테스트"라는 일반적 테스트명 관례가 겹친 것 |
| 86 | `test_last_fenced_block_wins` (py) | 2/2 | ⚠ | plugin-audit test_codex_audit_to_json.py, spec-distill test_codex_findings_to_yaml.py | 부분 사본 | **유예 B** (python 테스트 헬퍼) — python 테스트 헬퍼의 **정본 자리를 이 사이클이 만들지 않는다**(설계 §9는 셸 판정 헬퍼 한정). §12.4 임계 미만 — 실측 | `apply_overrides`(#62)와 같은 근거로 codex 출력 파싱 테스트 패밀리가 plugin-audit까지 확장됨을 보여줌. **불일치 항목** |
| 87 | `test_auth_error_in_stderr` (py) | 2/2 | ⚠ | plugin-audit test_codex_audit_to_json.py, spec-distill test_codex_findings_to_yaml.py | 부분 사본 | **유예 B** (python 테스트 헬퍼) — python 테스트 헬퍼의 **정본 자리를 이 사이클이 만들지 않는다**(설계 §9는 셸 판정 헬퍼 한정). §12.4 임계 미만 — 실측 | 위와 같음 |
| 88 | `_state_root` (py) | 2/2 | ⚠ | quality-gates hooks/session-start-advisor.py·session-end-cleanup.py | 부분 사본 | 공통 조각만 추출 (**Task 21 Step 2b** — `plugins/quality-gates/scripts/state_path.py`) | 같은 플러그인 내 두 훅이 상태 루트 경로 해석을 각자 구현 — seed가 지적한 "qg-gc.py ↔ spec-distill-gc.py state root 해석 방식이 다름"과 같은 패턴이 quality-gates 내부에도 존재 |
| 89 | `emit_degraded` (sh) | 2/2 | ⚠ | quality-gates resolve-baseline.sh·check-review-scope.sh | 부분 사본 | **유예 D** (통합이 동작 변경) — 두 본문의 **계약이 다르다**. 합치는 것은 소비자 동작을 바꾸는 별개 결정이다(§15.1). §12.4 임계 미만 — 실측 실측: 두 본문의 **키 집합이 다르다**(`base`·`base_ref`·`merge_base`·`same_as_head`·`ahead` vs `changes_exist`·`branch_ahead_count`·`worktree_dirty`) — 공통은 `degraded: yes`·`base: -`·`exit 0` 3줄뿐. | 같은 플러그인 내 두 스크립트가 degrade 신호 발신을 각자 구현 — codex 통일 project가 이미 "degrade 이름 5종" 문제로 기록한 계열의 일부 |
| 90 | `parse_fenced_json` (py) | 2/2 | ⚠ | qg/spec-distill `codex_findings_to_yaml.py` | 진짜 사본 | `codex_findings_to_yaml.py` 통합에 흡수 (**Task 17**) | #5 파일 진짜 사본의 구성 함수 — 파일 전체가 emit keyset 차이만 남기고 동일해지는 대상 |
| 91 | `yaml_emit` (py) | 2/2 | ⚠ | 동일 파일쌍 | 진짜 사본 | `codex_findings_to_yaml.py` 통합에 흡수 (**Task 17**) | 위와 같음 |
| 92 | `_one` (py) | 2/2 | ⚠ | quality-gates `scripts/diff-test-results.py`, spec-distill `scripts/check_brief.py` | 우연 | 조치 없음 | 실측: 전자는 정규식이 정확히 1회 매치하는지 fail-closed로 검사, 후자는 frontmatter 에러 메시지를 파일 컨텍스트로 재구성하는 지역 헬퍼 — 완전히 다른 목적 |
| 93 | `emit_json` (sh) | 2/2 | ⚠ | `discover-plan.sh`↔`discover-spec.sh` | 부분 사본 | `discover-plan.sh`/`discover-spec.sh` 통합에 흡수 (Task 22) | #26 파일 부분 사본의 구성 함수 |
| 94 | `pick_best` (sh) | 2/2 | ⚠ | `discover-plan.sh`↔`discover-spec.sh` | 부분 사본 | `discover-plan.sh`/`discover-spec.sh` 통합에 흡수 (Task 22) | 실측: #26 파일쌍(부분 사본)과 동일한 2파일 — 구성 함수 |
| 95 | `_ttl_ns` (py) | 2/2 | ⚠ | qg-gc.py↔spec-distill-gc.py | 부분 사본 | 공통 조각만 추출 (**Task 21**) | 〔seed〕 `qg-gc.py ↔ spec-distill-gc.py` 부분 사본의 구성 함수 |
| 96 | `_verbose` (py) | 2/2 | ⚠ | qg-gc.py↔spec-distill-gc.py | 부분 사본 | 공통 조각만 추출 (**Task 21**) | 실측: 〔seed〕 `qg-gc.py ↔ spec-distill-gc.py` 부분 사본의 구성 함수 — gc 패밀리(#95/97/98/99/116/136)와 동일 파일쌍 |
| 97 | `_within_grace` (py) | 2/2 | ⚠ | qg-gc.py↔spec-distill-gc.py | 부분 사본 | 공통 조각만 추출 (**Task 21**) | 위 #95와 같은 패밀리 |
| 98 | `_gc_one` (py) | 2/2 | ⚠ | qg-gc.py↔spec-distill-gc.py | 부분 사본 | 공통 조각만 추출 (**Task 21**) | 위와 같음 |
| 99 | `gc` (py) | 2/2 | ⚠ | qg-gc.py↔spec-distill-gc.py | 부분 사본 | 공통 조각만 추출 (**Task 21**) | 두 파일의 진입점 함수 자체 |
| 100 | `normalize` (py) | 2/2 | ⚠ | quality-gates `scripts/secret-scan.py`, spec-distill `scripts/check_verbatim_coverage.py` | 우연 | 조치 없음 | 실측: 전자는 마크다운 코드펜스만 벗겨 시크릿 패턴 매칭용으로, 후자는 인용부호·링크·강조마커를 벗겨 원문 대조용으로 — 정규화 규칙이 도메인별로 다름 |
| 101 | `_norm_sev` (py) | 2/2 | ⚠ | quality-gates `synthesize_findings.py:365`, `synthesize_artifact_findings.py:49` | 부분 사본 | **유예 D** (통합이 동작 변경) — 두 본문의 fallback **방향이 정반대**라 합치는 것은 머지 차단 동작을 바꾸는 별개 결정이다. **fallback 방향은 절대 통합하지 말 것.** §15.1 / Task 28 Step 7 이 이 divergence 를 기록한다. §12.4 임계 미만 — 실측 | **정정(fix round 2)**: 이전 판이 "같은 fail-closed 정책"이라 적었는데 코드와 반대다. 실측: `synthesize_findings.py:365`는 미지 severity를 **SUGGESTION**으로 강등(fail-open, 주석 "Normalize to SUGGESTION… so counts == rows"), `synthesize_artifact_findings.py:49`는 **CRITICAL**로 승격(fail-closed, 주석 "Treat anything off-vocab as CRITICAL"). 두 함수는 시그니처·어휘-셋 검사 구조는 근접하지만 **동일 시나리오에 정반대 fallback 방향**을 갖는, plan §15.1/Task 28 Step 7에 이미 "머지 차단 동작을 바꾸는 별개 결정"으로 out-of-scope 기록된 **의도적** 분기다. 누가 이 행을 집더라도 fallback 분기(CRITICAL/SUGGESTION)는 절대 통합하지 말 것 — 우연으로 낮추면 이 경고 자체가 표에서 사라져 무조건 조치-없음으로 스킵될 위험이 있어, 부분 사본으로 유지하되 조치란에 금지 문구를 명시하는 쪽을 택했다. **2026-08-17 재검토**: 조치란이 가리키던 "Task 20·21"은 이 두 파일을 Files 에 담은 적이 없다(형태 ① 오귀속) — 유예 D 로 바꾸고 금지 문구는 그대로 뒀다 |
| 102 | `assert_not_grep` (sh) | 2/2 | ⚠ | — | 부분 사본 | Task 14 (정본 이름은 Task 13 Interfaces 의 대응표) | 〔seed〕 assert_* 패밀리 |
| 103 | `write_agent` (sh) | 2/2 | ⚠ | quality-gates `test_agent_tools_lock_mutation.sh`, `test_agent_tools_lock_differential.sh` | 부분 사본 | **유예 A** (셸 하네스) — quality-gates 안의 mutation-lock 하네스. 설계 §9의 `shared/tests/` 는 **판정 헬퍼**의 자리이고 그 근거는 소유 관계인데 이 헬퍼는 **그 플러그인 자신의 것**이라 근거가 옮겨가지 않는다. 같은 플러그인 안이므로 §6.1③이 적용 가능하나 이 사이클 범위 밖. §12.4 임계 미만 — 실측 | 실측: 둘 다 `printf -- '---\nname: probe\ndescription: fixture\nmodel: inherit\n...\n---\n\nbody\n'`로 같은 probe-agent frontmatter를 씀 — 대상 경로와 printf 포맷(`%b`/`%s`)만 다름. `bad`/`expect`/`verdict`(#104/105/107)와 같은 mutation-lock 하네스 계열 |
| 104 | `bad` (sh) | 2/2 | ⚠ | quality-gates `test_agent_tools_lock_differential.sh:119` · `test_build_codex_prompt.sh:17` | 부분 사본 | **Task 14** — 판정 헬퍼다. 실측: 두 본문이 `bad() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }` 로 **공백 말고 다르지 않다**(`assert.sh` 의 `no()` 와 같은 책임). 두 파일 다 이미 도출 목록에 있고(`ok()` 를 정의한다), `bad` 를 Step 2 의 `HELPERS` 에 더한다 | **정정(2026-08-17 fix round 2)**: 이전 판의 위치란이 `test_agent_tools_lock_mutation.sh` 를 댔는데 **그 파일에는 `bad()` 가 없다**(`grep -rn '^bad()' plugins/` 로 확인 — 실제는 differential + build_codex_prompt). 위치가 틀렸으므로 그 위에 얹힌 '유예 A(mutation-lock 하네스)'도 틀렸다 — `bad` 는 하네스가 아니라 **판정 헬퍼**이고 설계 §9 범위 안이다 |
| 105 | `expect` (sh) | 2/2 | ⚠ | quality-gates `test_agent_tools_lock_mutation.sh:30` · `test_review_floor_lock.sh:26` | 부분 사본 | **Task 14** — 판정 헬퍼다. 실측: 두 본문 다 `got` 을 구한 뒤 `want` 와 비교해 PASS/FAIL 을 세고 찍는다. **`got` 을 구하는 방법만 다르다**(`bash "$LOCK" "$TMP"` vs `check_floor "$2"`) — 그 부분은 파일에 남기고 비교·집계·출력만 기존 `assert_eq "$got" "$want" "$msg"` 로 바꾼다(새 헬퍼 불필요). 두 파일은 **현재 도출 목록에 없다** — `expect` 를 `HELPERS` 에 더하면 들어온다 | **정정(2026-08-17 fix round 2)**: 이전 판이 위치를 "위와 같은 lock 테스트군"(=#104과 같은 쌍)이라 적었는데 **쌍 자체가 다르다** — #104는 differential+build_codex_prompt, 이 행은 mutation+review_floor_lock 이다. 파일명을 안 적어 기계적 대조를 빠져나갔다 |
| 106 | `mkrepo` (sh) | 2/2 | ⚠ | quality-gates `test_artifact_branch_guard.sh`, `test_artifact_commit.sh` | 우연 | 조치 없음 | 실측(2개 본문 전부 판독): 전자는 feature 브랜치 1개만 만드는 fixture, 후자는 doc.md+other.md 두 파일을 커밋하는 fixture — 공유 관용구(mktemp+git init)는 같지만 실제 레이아웃은 시나리오별로 다름(`mk_repo`#49와 별개 이름) |
| 107 | `verdict` (sh) | 2/2 | ⚠ | quality-gates `test_artifact_path_auth.sh:6` · `test_codex_copies_agree.sh:38` | 부분 사본 | **유예 D** (공유할 본문이 없다) — 실측: 두 본문은 무관한 **한 줄짜리 출력 추출기**다. `verdict() { python3 "$SCRIPT" "$1" "$2" \| sed -n 's/^auth: //p'; }` vs `verdict() { grep -E '^  (codex_failed\|reason\|...):' \|\| true; }` — **어느 쪽도 assertion 을 내거나 PASS/FAIL 을 세지 않아** 설계 §9의 판정 헬퍼 범위 밖이고, 추출할 공통 조각 자체가 없다. §12.4 임계 미만 — 실측 | **정정(2026-08-17 fix round 2)**: 이전 판이 위치를 "quality-gates lock 테스트군", 근거를 "#104/105와 같은 mutation-lock 하네스 계열"이라 적었는데 **둘 다 사실이 아니다** — 실제 두 파일은 lock 테스트가 아니고, #104·#105 와 파일이 겹치지도 않는다. 이름만 같은 서로 무관한 함수다 |
| 108 | `restore` (sh) | 2/2 | ⚠ | quality-gates test_cost_consent.sh·test_check_allowed_tools_order.sh | 부분 사본 | **유예 A** (셸 하네스) — quality-gates 안의 설정 복원 헬퍼. 설계 §9의 `shared/tests/` 는 **판정 헬퍼**의 자리이고 그 근거는 소유 관계인데 이 헬퍼는 **그 플러그인 자신의 것**이라 근거가 옮겨가지 않는다. 같은 플러그인 안이므로 §6.1③이 적용 가능하나 이 사이클 범위 밖. §12.4 임계 미만 — 실측 | 같은 플러그인 내 설정 복원 테스트 헬퍼 — 판단 갈림, 무거운 쪽으로 |
| 109 | `section_window` (sh) | 2/2 | ⚠ | quality-gates test_codex_result_banner.sh·test_runtime_verdict_precedence.sh | 부분 사본 | **유예 A** (셸 하네스) — quality-gates 안의 윈도우드-grep 헬퍼. 설계 §9의 `shared/tests/` 는 **판정 헬퍼**의 자리이고 그 근거는 소유 관계인데 이 헬퍼는 **그 플러그인 자신의 것**이라 근거가 옮겨가지 않는다. 같은 플러그인 안이므로 §6.1③이 적용 가능하나 이 사이클 범위 밖. §12.4 임계 미만 — 실측 | 윈도우드-grep 락 테스트 기법(§12.4 계열)의 quality-gates측 인스턴스 |
| 110 | `assert_not_contains` (sh) | 2/2 | ⚠ | — | 부분 사본 | Task 14 (정본 이름은 Task 13 Interfaces 의 대응표) | 〔seed〕 assert_* 패밀리 |
| 111 | `agf` (sh) | 2/2 | ⚠ | quality-gates test_qg_critique_routing.sh·test_critiquing_artifacts_skill.sh | 부분 사본 | Task 14 (정본 이름은 Task 13 Interfaces 의 대응표) | `ag`(#46, seed 명시)의 변형 — 같은 판정-헬퍼 계열 |
| 112 | `run_in_env` (sh) | 2/2 | ⚠ | `test_discover_spec.sh:34`↔`test_discover_plan.sh:33` (**제품 스크립트가 아니라 테스트 파일**) | 부분 사본 | **유예 A** (셸 하네스) — 설계 §9는 `shared/tests/` 를 **판정 헬퍼**의 자리로 정의했다(근거는 소유 관계: *"판정 헬퍼는 어느 한 플러그인의 것이 아니다"*). 픽스처 빌더·훅 실행 래퍼·윈도우 추출은 **그 플러그인 자신의 것**이라 그 근거가 옮겨가지 않는다. §12.4 임계 미만 — 실측 본문도 다르다 — 실측: plan 쪽만 `HOME="$proj/home"` 오버라이드를 갖는다(7줄/6줄). | **정정(2026-08-17 재검토)**: 이전 판이 이 행을 "`discover-plan.sh`/`discover-spec.sh` 통합에 흡수 (Task 22)"로 적었는데 **틀렸다.** `run_in_env()` 는 두 **테스트** 파일에 정의돼 있고(`grep -rn 'run_in_env()'` 로 확인 — 제품 스크립트 2개에는 0회), Task 22의 Files 는 그 테스트 파일들을 담지 않으며 Step 2는 제품에서 `discover_common.sh` 를 뽑고 Step 3은 테스트를 **실행만** 한다. **제품을 합쳐도 테스트 파일 두 곳의 중복 헬퍼는 사라지지 않는다** — #26의 "테스트측 반영"이라는 서술이 조치까지 따라간 형태 ① 오귀속이었다 |
| 113 | `_run_hook` (py) | 2/2 | ⚠ | quality-gates test_kill_switches.py, spec-distill test_hook_output_schema.py | 부분 사본 | **유예 B** (python 테스트 헬퍼) — python 테스트 헬퍼의 **정본 자리를 이 사이클이 만들지 않는다**(설계 §9는 셸 판정 헬퍼 한정). §12.4 임계 미만 — 실측 | `run_hook`(#36/#50)과 같은 계열의 별칭 — 훅 실행 테스트 헬퍼가 3번째 이름으로도 존재 |
| 114 | `run_ledger` (sh) | 2/2 | ⚠ | quality-gates test_qa_ledger.sh, spec-distill arm_test_helpers.sh | 부분 사본 | **유예 A** (셸 하네스) — 설계 §9의 `shared/tests/` 는 **판정 헬퍼**의 자리이고 그 근거는 소유 관계(*"판정 헬퍼는 어느 한 플러그인의 것이 아니다"*)인데, 훅 실행 래퍼·ledger 하네스는 **그 플러그인 자신의 것**이라 근거가 옮겨가지 않는다. §12.4 임계 미만 — 실측 〔실측: 6줄/3줄, 본문 상이〕 | 플러그인 경계를 넘는 ledger 테스트 하네스 |
| 115 | `rc_of` (sh) | 2/2 | ⚠ | quality-gates test_qa_ledger.sh, spec-distill test_check_verbatim_coverage.sh | 부분 사본 | **유예 A** (셸 하네스) — 설계 §9의 `shared/tests/` 는 **판정 헬퍼**의 자리이고 그 근거는 소유 관계(*"판정 헬퍼는 어느 한 플러그인의 것이 아니다"*)인데, 훅 실행 래퍼·ledger 하네스는 **그 플러그인 자신의 것**이라 근거가 옮겨가지 않는다. §12.4 임계 미만 — 실측 〔실측: 1줄/1줄, 본문 상이 — 크기로는 유예 C 에 가깝고 사유는 둘 다 성립한다〕 | 위와 같은 ledger 테스트 하네스 계열 |
| 116 | `run_gc` (py) | 2/2 | ⚠ | quality-gates `tests/test_qg_gc.py:14`, spec-distill `tests/test_gc.py:12` (**gc 스크립트가 아니라 테스트 파일**) | 부분 사본 | **유예 B** (python 테스트 헬퍼) — python 테스트 헬퍼의 **정본 자리를 이 사이클이 만들지 않는다**(설계 §9는 셸 판정 헬퍼 한정). §12.4 임계 미만 — 실측 두 본문의 시그니처도 다르다 — 실측: `run_gc(cwd, env_extra, args)` vs `run_gc(env_extra, cwd)`. | **정정(2026-08-17 재검토)**: 이전 판의 위치란이 "qg-gc.py↔spec-distill-gc.py"였는데 **사실이 아니다** — `grep -c run_gc` 로 확인한 결과 두 gc 스크립트에는 **0회**이고 정의는 두 **테스트** 파일에 있다. 위치가 틀렸으므로 그 위에 얹힌 조치(Task 21)도 틀렸다 — Task 21의 Files 는 테스트 파일을 담지 않는다. #95/97/98/99는 진짜로 gc 스크립트 쌍이라 Task 21이 맞고, 이 행만 테스트측이다 |
| 117 | `make_session_dir` (py) | 2/2 | ⚠ | quality-gates test_session_end_cleanup.py·test_qg_gc.py | 부분 사본 | **유예 B** (python 테스트 헬퍼) — python 테스트 헬퍼의 **정본 자리를 이 사이클이 만들지 않는다**(설계 §9는 셸 판정 헬퍼 한정). §12.4 임계 미만 — 실측 | 같은 플러그인 gc/cleanup 테스트군의 공유 fixture 헬퍼 |
| 118 | `test_kill_switch` (py) | 2/2 | ⚠ | quality-gates test_session_end_cleanup.py·test_qg_gc.py | 부분 사본 | **유예 B** (python 테스트 헬퍼) — python 테스트 헬퍼의 **정본 자리를 이 사이클이 만들지 않는다**(설계 §9는 셸 판정 헬퍼 한정). §12.4 임계 미만 — 실측 | `_disabled`/`kill_switch_active`(#37/#42) 소스 중복의 테스트측 반영 |
| 119 | `assert_body_grep` (sh) | 2/2 | ⚠ | — | 부분 사본 | Task 14 (정본 이름은 Task 13 Interfaces 의 대응표) | 〔seed〕 assert_* 패밀리 |
| 120 | `test_empty_session_id_silent_exit` (py) | 2/2 | ⚠ | quality-gates test_session_end_cleanup.py·test_session_tracker.py | 부분 사본 | **유예 B** (python 테스트 헬퍼) — python 테스트 헬퍼의 **정본 자리를 이 사이클이 만들지 않는다**(설계 §9는 셸 판정 헬퍼 한정). §12.4 임계 미만 — 실측 | 훅 계약(빈 session-id 무시)의 테스트가 두 훅에 각각 재구현 |
| 121 | `parse_iso` (py) | 2/2 | ⚠ | spec-distill `hooks/review-dispatch.py`, `hooks/pending-review-reminder.py` | 부분 사본 | **Task 22 Step 2b** (`plugins/spec-distill/scripts/hook_common.py`) | 실측: 축4 #149(블록축, 두 훅이 8개 블록 공유)와 동일 파일쌍의 구성 함수 |
| 122 | `state_file_for` (py) | 2/2 | ⚠ | spec-distill hooks/review-dispatch.py·scripts/arm_ledger.py | 부분 사본 | **Task 22 Step 2b** (`hook_common.py` — `arm_ledger.py:91` docstring 의 "이 한 곳만" 을 참으로 만든다) | 같은 플러그인 내부 상태 파일 경로 해석 중복 — seed에 없는 신규 발견 |
| 123 | `find_missing_sections` (py) | 2/2 | ⚠ | spec-distill scripts/check_brief.py·parse_spec_structure.py | 부분 사본 | **유예 D** (통합이 동작 변경) — 두 본문의 **계약이 다르다**. 합치는 것은 소비자 동작을 바꾸는 별개 결정이다(§15.1). §12.4 임계 미만 — 실측 실측: 섹션 모델이 다르다 — brief 는 번호 붙은 `## N. 제목`, spec 은 번호 없는 `## 제목`. 시그니처·반환 형식도 다름. | 같은 플러그인 내부 섹션-검증 유틸 중복 — 신규 발견 |
| 124 | `_frontmatter` (py) | 2/2 | ⚠ | spec-distill scripts/check_brief.py·check_verbatim_coverage.py | 부분 사본 | **유예 D** (통합이 동작 변경) — 두 본문의 **계약이 다르다**. 합치는 것은 소비자 동작을 바꾸는 별개 결정이다(§15.1). §12.4 임계 미만 — 실측 실측: `check_brief.py` 는 미스에 `""` 반환, `check_verbatim_coverage.py` 는 `ParseError` 발생 — #101 과 같은 부류. | 같은 플러그인 내부 frontmatter 파싱 유틸 중복 — 신규 발견 |
| 125 | `write_failclosed` (sh) | 2/2 | ⚠ | `run_brief_codex_reviewer.sh`↔`run_spec_codex_reviewer.sh` | 부분 사본 | 공통 조각만 추출 (**Task 20 Step 3b**) | #24 파일쌍 부분 사본의 구성 함수 |
| 126 | `emit_fallback` (sh) | 2/2 | ⚠ | 동일 파일쌍 | 부분 사본 | **유예 D** (통합이 동작 변경) — 두 본문의 **계약이 다르다**. 합치는 것은 소비자 동작을 바꾸는 별개 결정이다(§15.1). §12.4 임계 미만 — 실측 실측: 4줄 vs **47줄**. 긴 쪽이 spec 리뷰 전용 fallback 본문을 통째로 담아 §3의 판정 질문("차이를 파일 밖으로 빼면 바이트 동일이 되는가")에 **아니오**다. Task 20 Step 3b 가 이 판단을 기록한다. | 위와 같음 |
| 127 | `run_validator` (sh) | 2/2 | ⚠ | spec-distill arm_test_helpers.sh·test_stale_state_truncate.sh | 부분 사본 | **유예 A** (셸 하네스) — spec-distill 안의 arm-ledger 하네스. 설계 §9의 `shared/tests/` 는 **판정 헬퍼**의 자리이고 그 근거는 소유 관계인데 이 헬퍼는 **그 플러그인 자신의 것**이라 근거가 옮겨가지 않는다. 같은 플러그인 안이므로 §6.1③이 적용 가능하나 이 사이클 범위 밖. §12.4 임계 미만 — 실측 | 같은 플러그인 arm-ledger 테스트 하네스 계열 |
| 128 | `scoped_window` (sh) | 2/2 | ⚠ | spec-distill test_reviewing_brief_skill.sh·test_brief_review_entry.sh | 부분 사본 | **유예 A** (셸 하네스) — spec-distill 안의 3인조 헬퍼. 설계 §9의 `shared/tests/` 는 **판정 헬퍼**의 자리이고 그 근거는 소유 관계인데 이 헬퍼는 **그 플러그인 자신의 것**이라 근거가 옮겨가지 않는다. 같은 플러그인 안이므로 §6.1③이 적용 가능하나 이 사이클 범위 밖. §12.4 임계 미만 — 실측 | `window`/`fence`(#129/130)와 같은 두 파일에 공존하는 3인조 헬퍼 |
| 129 | `window` (sh) | 2/2 | ⚠ | 동일 파일쌍 | 부분 사본 | **유예 A** (셸 하네스) — spec-distill 안의 3인조 헬퍼. 설계 §9의 `shared/tests/` 는 **판정 헬퍼**의 자리이고 그 근거는 소유 관계인데 이 헬퍼는 **그 플러그인 자신의 것**이라 근거가 옮겨가지 않는다. 같은 플러그인 안이므로 §6.1③이 적용 가능하나 이 사이클 범위 밖. §12.4 임계 미만 — 실측 | 위와 같음 |
| 130 | `fence` (sh) | 2/2 | ⚠ | 동일 파일쌍 | 부분 사본 | **유예 A** (셸 하네스) — spec-distill 안의 3인조 헬퍼. 설계 §9의 `shared/tests/` 는 **판정 헬퍼**의 자리이고 그 근거는 소유 관계인데 이 헬퍼는 **그 플러그인 자신의 것**이라 근거가 옮겨가지 않는다. 같은 플러그인 안이므로 §6.1③이 적용 가능하나 이 사이클 범위 밖. §12.4 임계 미만 — 실측 | 위와 같음 |
| 131 | `test_7_global_killswitch` (py) | 2/2 | ⚠ | spec-distill test_gc.py·test_session_end_cleanup.py | 부분 사본 | **유예 B** (python 테스트 헬퍼) — python 테스트 헬퍼의 **정본 자리를 이 사이클이 만들지 않는다**(설계 §9는 셸 판정 헬퍼 한정). §12.4 임계 미만 — 실측 | `_disabled`(#37) spec-distill측 소스 중복의 테스트 반영 |
| 132 | `_exe` (py) | 2/1 | ✅ | plugin-audit test_check_plugin_structure.py·test_run_own_tests.py | 진짜 사본 | **유예 C** (1~3줄 관용구) — 정본으로 빼면 소비 지점마다 import/source 1줄이 생겨 **순증**. §12.4 임계 미만 — 실측 실측: 2줄. | 바이트 동일 |
| 133 | `parse_raw_json` (py) | 2/1 | ✅ | qg/spec-distill `codex_findings_to_yaml.py` | 진짜 사본 | #5 통합에 흡수 (**Task 17**) | 바이트 동일, #5 패밀리 |
| 134 | `has_auth_error` (py) | 2/1 | ✅ | 동일 파일쌍 | 진짜 사본 | #5 통합에 흡수 (**Task 17**) | 바이트 동일, #5 패밀리 |
| 135 | `get_mtime` (sh) | 2/1 | ✅ | `discover-plan.sh`↔`discover-spec.sh` | 진짜 사본 | #26 통합(Task 22)에 흡수 | 바이트 동일 — 파일 전체는 부분 사본이지만 이 함수 자체는 이미 완전 동일 |
| 136 | `_folder_mtime_ns` (py) | 2/1 | ✅ | qg-gc.py↔spec-distill-gc.py | 진짜 사본 | **Task 21** 의 공통 조각 추출에 즉시 흡수 (바이트 동일) | 바이트 동일 — gc 패밀리(#95/97/98/99/116) 중 유일하게 완전 동일 |
| 137 | `assert_absent` (sh) | 2/1 | ✅ | quality-gates test_adversarial_persona.sh·test_security_reviewer_persona.sh | 진짜 사본 | **Task 14 Step 4b** — persona 쌍. `assert_absent` → `shared/tests/assert.sh` 의 `assert_file_absent` | 바이트 동일 — 아래 블록축 #148과 같은 파일쌍 |
| 138 | `fm_of` (sh) | 2/1 | ✅ | quality-gates test_agent_frontmatter_keys.sh, spec-distill test_brief_agents.sh | 진짜 사본 | **유예 C** (1~3줄 관용구) — 정본으로 빼면 소비 지점마다 import/source 1줄이 생겨 **순증**. §12.4 임계 미만 — 실측 실측: 1줄. | 바이트 동일, 플러그인 경계를 넘음 |
| 139 | `mk_repo_feature_ahead` (sh) | 2/1 | ✅ | quality-gates test_check_review_scope.sh·test_qg_false_clean_floor.sh | 진짜 사본 | **유예 A** (셸 픽스처 빌더) — 설계 §9의 `shared/tests/` 는 **판정 헬퍼**의 자리이고 그 근거는 소유 관계(*"판정 헬퍼는 어느 한 플러그인의 것이 아니다"*)인데, git 픽스처 빌더는 **quality-gates 자신의 것**이라 그 근거가 옮겨가지 않는다. **같은 플러그인 안이므로 §6.1③(파일 하나 source)이 적용 가능한 행이다** — 이 사이클이 안 하는 이유는 '할 수 없어서'가 아니라 Task 14가 이미 120파일을 인자 순서 반전과 함께 고치는 PR 안에 픽스처 이관까지 넣지 않기 위해서다. §12.4 임계 미만 — 실측. 〔실측: 9줄, **바이트 동일**〕 | 바이트 동일 |
| 140 | `make_repo_with_worktree` (sh) | 2/1 | ✅ | quality-gates test_isolation.sh·test_worktree.sh | 진짜 사본 | **유예 A** (셸 픽스처 빌더) — #139와 같은 이유(같은 플러그인·소유 관계·PR3b 범위). §12.4 임계 미만 — 실측. 〔실측: 18줄, **바이트 동일**〕 | 바이트 동일 |
| 141 | `mkw` (sh) | 2/1 | ✅ | quality-gates test_run_test_selection.sh·test_runner_adapters.sh | 진짜 사본 | **유예 C** (1~3줄 관용구) — 정본으로 빼면 소비 지점마다 import/source 1줄이 생겨 **순증**. §12.4 임계 미만 — 실측 실측: 1줄. | 바이트 동일 |
| 142 | `rmw` (sh) | 2/1 | ✅ | 동일 파일쌍 | 진짜 사본 | **유예 C** (1~3줄 관용구) — 정본으로 빼면 소비 지점마다 import/source 1줄이 생겨 **순증**. §12.4 임계 미만 — 실측 실측: 1줄. | 바이트 동일 |
| 143 | `scan_ok` (py) | 2/1 | ✅ | quality-gates test_secret_scan.py·test_secret_scan_fp.py | 진짜 사본 | **유예 C** (1~3줄 관용구) — 정본으로 빼면 소비 지점마다 import/source 1줄이 생겨 **순증**. §12.4 임계 미만 — 실측 실측: 2줄. | 바이트 동일 |
| 144 | `blocked` (py) | 2/1 | ✅ | 동일 파일쌍 | 진짜 사본 | **유예 C** (1~3줄 관용구) — 정본으로 빼면 소비 지점마다 import/source 1줄이 생겨 **순증**. §12.4 임계 미만 — 실측 실측: 2줄. | 바이트 동일 |
| 145 | `test_script_exists` (py) | 2/1 | ✅ | spec-distill test_brief_review_state.py·test_merge_brief_review.py | 진짜 사본 | **유예 C** (1~3줄 관용구) — 정본으로 빼면 소비 지점마다 import/source 1줄이 생겨 **순증**. §12.4 임계 미만 — 실측 실측: 2줄. | 바이트 동일 |

### 축 4 — 동일 텍스트 블록 (blocks.py, 창 20줄/최소 200자)

| # | 후보 | 분류 | 조치 (태스크) | 근거 |
|---|---|---|---|---|
| 146 | `detect_codex.sh` ×3, 39개 블록 공유 | 진짜 사본 | shared/ 정본 + 심볼릭 링크 (**Task 15**) | 축1 #4와 동일 후보, 블록축이 재확인 |
| 147 | `detect_codex.sh` (plugin-audit↔quality-gates만), 20개 블록 | 진짜 사본 | #146 과 동일 흡수 (**Task 15**) | #146의 부분집합, 별도 조치 아님 |
| 148 | `codex_findings_to_yaml.py` ×2, 17개 블록 | 진짜 사본 | #5 와 동일 흡수 (**Task 17**) | 축1 #5와 동일 후보, 블록축이 재확인 |
| 149 | `pending-review-reminder.py` ↔ `review-dispatch.py` (spec-distill/hooks/), 8개 블록 | 부분 사본 | **Task 22 Step 2b** — 27줄 공유 구간을 `hook_common.py` 로. Task 35 집합 B 의 두 쌍 중 하나 | seed에 없는 신규 발견 — 표준입출력 UTF-8 고정 프리앰블 등 8개 블록(≥20줄/200자) 공유, 두 훅의 나머지 로직은 서로 다름 |
| 150 | `test_adversarial_persona.sh` ↔ `test_security_reviewer_persona.sh`, 7개 블록 | 부분 사본 | **Task 14 Step 4b** — 공유 26줄이 전부 스캐폴딩(assertion 0줄)이라 이관이 persona 검사를 줄이지 않는다. Task 35 집합 B 의 나머지 하나 | 신규 발견 — 두 페르소나 테스트 파일이 공유 하네스 7블록을 가짐(`assert_absent` 함수 자체는 #137에서 이미 진짜 사본으로 별도 처리) |

## 세드 판단과의 불일치 (discrepancy)

- **`README.md`**: seed는 ×6으로 적었으나 실측은 ×7 (`plugins/plugin-audit/scripts/tests/README.md`). **정정**: 이전 판에서 이 파일이 "seed 작성 시점 이후 추가된 것으로 추정"이라 적었는데 틀렸다 — `git log`로 확인한 결과 이 파일의 유일한 add 커밋은 `5582495`(2026-07-20)로, plan 문서 자체의 생성 커밋 `ee1d95f`(2026-08-17)보다 **한 달 가까이 앞선다**(`git merge-base --is-ancestor 5582495 ee1d95f`로 조상관계 확인). 즉 seed를 쓴 시점에 이 파일은 이미 존재했다 — 진짜 원인은 **seed 표의 수동 집계 오류**(누락)다. 분류(우연)는 바뀌지 않음 — 이유는 여전히 "README 컨벤션".
- **`branch-strategy.md`**: seed는 "×3"(우연 그룹)과 "템플릿-인스턴스" 행을 별도로 적어 사실상 4파일을 이미 3+1로 나눠 서술했다. 이 원장은 그 분할을 diff 실측으로 확정하고 파일 경로 단위로 명시했다(#9~11) — 분류 자체의 불일치는 아니고, seed 표기를 표 구조로 풀어낸 것.
- **`codex_findings_to_yaml.py` 계열의 확장**: seed는 quality-gates/spec-distill 2파일만 진짜 사본으로 적었다. 함수축이 `apply_overrides`(#62)·`test_last_fenced_block_wins`(#86)·`test_auth_error_in_stderr`(#87)에서 **plugin-audit의 `codex_audit_to_json.py`**가 같은 파싱 책임(override 적용, fenced-JSON 파싱, auth-error 검출)을 공유함을 드러냈다. 이 파일은 파일축 유사도 임계값(≥60%) 밑이라 축1/축2에는 잡히지 않았지만, 함수·테스트 수준에서는 실측 증거가 있다. **2026-08-17 재검토 — 권고를 조치로 승격**: "함께 검토할 것을 권고" 는 조치가 아니었다(어느 태스크의 스텝도 이 파일을 열지 않는다). 지금은 **Task 17 Step 4b** 가 `extract_last_agent_message`(#58, 실측 30/37/22줄 동일 알고리즘)를 `shared/codex/codex_jsonl.py` 정본으로 빼고 `codex_audit_to_json.py` 가 그것을 import 한다. `apply_overrides`(#62)는 pa 판이 `main()` 안 중첩 함수이고 소비하는 meta 키가 달라 **옮기지 않으며**, 그 판단을 같은 스텝이 기록한다. 테스트 쪽(#86·#87)은 두 파일이 서로 다른 모듈의 소비 계약을 각각 검증하므로 유예 B 다.
- **`kill_switch_active` 패밀리 확장**: seed는 5곳(py)만 적었다. 함수축은 `_disabled`(#37)라는 **다른 이름**으로 동일 책임(kill switch 판정)이 7곳 더 있음을 드러냈다 — 총 12곳. 이름이 다르다는 이유로 census 스크립트 자체는 이 둘을 연결하지 못했다(이름 기반 그룹핑의 구조적 한계); 이 원장에서 실측 grep으로 연결해 진짜 사본으로 통합 분류했다.
- **`extract_last_agent_message` (fix round 1 발견)**: 최초 판이 "이름은 구체적이나 census 본문이 전부 다름 — 파서 대상 포맷이 스크립트마다 다른 것으로 판단"이라고 적었으나, 세 본문을 실제로 읽지 않은 추측이었다. 실측 결과 `codex_findings_to_yaml.py` ×2 진짜 사본(#5) 패밀리와 완전히 같은 3파일 트리오(plugin-audit `codex_audit_to_json.py` 포함)에서 변수명·docstring만 다른 동일 알고리즘임을 확인 — #58을 우연에서 진짜 사본으로 정정. `apply_overrides`(#62)·`test_last_fenced_block_wins`(#86)·`test_auth_error_in_stderr`(#87)와 같은 계열의 네 번째 증거.
- **`section`/`section_of` 크로스 이름 중복 (fix round 1 발견)**: 함수축은 정확한 이름으로만 묶는다 — `section`(#70, agent-transparency `test_ab_runner_contract.py`)과 `section_of`(#76, `test_plugin_contract.py`)는 **이름이 달라 census가 서로 다른 행으로 셌지만**, 두 본문을 실측 판독한 결과 "`## <heading>` 부터 다음 `## ` 까지" docstring과 `text.index`/`rest`/`end` 알고리즘이 사실상 동일하다. `kill_switch_active`/`_disabled`와 같은 유형의 구조적 사각지대(이름 기반 그룹핑은 동의어를 못 봄) — #76을 부분 사본으로 정정, #70에 교차참조를 남겼다.

## 미배정

(진짜 사본·부분 사본 중 조치가 배정되지 않은 것.)

### 세는 법 — 정의는 여기 한 번만 둔다

다른 문서(plan §14 완료 측정 · plan Task 36 Step 3 · 설계 §15.1)는 이 정의를 **인용**하고 숫자를 다시 적지 않는다. 같은 수를 세 곳에 적으면 한 곳만 고쳐져 세 값이 갈린다 — 실제로 첫 판에서 41/42/43 세 값이 동시에 존재했다.

| 항 | 정의 | 값 |
|---|---|---|
| **모집단** | 분류표 150행 중 **진짜 사본 + 부분 사본** | **100** |
| **배정** | 조치란이 **태스크(필요하면 스텝까지)** 를 지목한 행 | **57** |
| **명시 유예** | 조치란이 **유예 묶음**(A–D)을 지목한 행 | **43** |
| **미배정** | 조치란이 비었거나 "조치 없음"인 행 | **0** |

**한 행은 정확히 한 번 센다.** #8은 판정 헬퍼 부분이 Task 14로 가고 커버 범위 잔여만 유예 사유 E로 같은 셀 안에 적혀 있다 — **배정으로 센다.** 잔여를 별도 행으로 세지 않으므로 A+B+C+D = 43 이고 E는 묶음이 아니라 #8 안의 각주다. 57 + 43 = 100.

> ### 2026-08-17 조치란 재검토 — 이 절이 왜 다시 쓰였나
>
> 이전 판은 여기서 *"없음 — 0건. 100행 전부가 조치 열에 … 중 하나를 명시하고 있다"* 라고 적고, 기계적 확인으로 **"조치 열에 `조치 없음` 문자열이 없다"** 를 grep 했다. 그 검사는 **조치란이 비어 있지 않은지**만 재고 **거기 적힌 태스크가 그 행의 일을 실제로 하는지**는 재지 않는다. 전수 재검토 결과 그 구멍이 실재했다 — 두 가지 형태로:
>
> - **형태 ① 무관한 태스크를 가리킨다.** 예: #137(`assert_absent`)·#150(persona 쌍)이 "Task 15·17·18·19" / "Task 20·21"을 가리켰는데, 그 태스크들의 Files 는 `detect_codex.sh` · `codex_findings_to_yaml.py` · `read_preamble.sh` · `kill_switch_active.py` · codex 러너 5종 · `session-end-cleanup.py`/GC 이고 **어느 것도 두 persona 테스트 파일을 담지 않았다.** **어느 태스크의 Files 블록에도, 어느 스텝 본문에도 두 파일명이 없었다** — 재검토 직전(`77be900`) plan 전문에는 두 이름이 **4회** 있었지만 넷 다 Task 35 콜아웃 안(집합 A 표 · 집합 B 측정 출력 · 행 6 불릿 · 샘플 `NO:` 줄)이라, 그 락이 *"이 쌍은 배정돼 있지 않다"* 고 **스스로 신고하는 자리**였을 뿐 그것을 고치는 태스크는 없었다. 〔이전 판이 이 자리에 "census 밖 0회"라고 적었는데 틀렸다 — 4회다. 실측 명령: `git show 77be900:<plan> | grep -n 'test_adversarial_persona\|test_security_reviewer_persona'`〕
> - **형태 ② 맞는 태스크를 가리키는데 그 태스크의 스텝이 절반만 덮는다.** 예: #149(훅 쌍)가 가리킨 Task 22 는 Files 에 "spec-distill 훅 두 개가 공유하는 블록"이 있고 Step 1 이 그것을 재기까지 했지만, **Step 2 이후는 `discover_common.sh` 쪽만 지정**해 훅을 손대지 않고도 완료할 수 있었다.
>
> **형태 ①은 "covered" 판정 안에서도 살아남았다** (재검토 2라운드에서 발견). 1라운드는 조치란이 지목한 태스크의 Files 를 봤지만, **행의 위치란이 틀렸으면 그 대조 자체가 틀린 것을 대조한다.** 정의 지점을 `grep -rn` 으로 직접 재서 두 건을 더 잡았다:
>
> - **#112 `run_in_env`** — "Task 22에 흡수"로 covered 였다. 실측: 정의는 `tests/test_discover_plan.sh:33`·`test_discover_spec.sh:34` 두 **테스트** 파일에 있고 제품 스크립트 2개에는 **0회**다. Task 22는 제품을 합칠 뿐이라 **테스트 파일의 중복 헬퍼는 그대로 남는다.** → 유예 A.
> - **#116 `run_gc`** — "Task 21"로 covered 였다. **위치란 자체가 사실이 아니었다**: `grep -c run_gc` 결과 `qg-gc.py`·`spec-distill-gc.py` 에 **0회**, 정의는 `tests/test_qg_gc.py:14`·`tests/test_gc.py:12` 다. → 유예 B.
>
> 그래서 2라운드는 **covered 33행 전량의 정의 지점을 `grep -rln` 으로 다시 뜬 뒤** 태스크 Files 와 대조했다. 예컨대 #134 `has_auth_error` 는 `^def` 로는 안 잡히지만 두 `codex_findings_to_yaml.py` 의 `main()` 안 중첩 함수라 Task 17의 심볼릭 링크가 그대로 흡수한다.
>
> **3라운드 — 재도출을 버킷이 아니라 모집단 전체로 넓혔다.** 2라운드는 covered 만 다시 떴고 **유예 버킷은 안 떴는데, 같은 결함이 거기 남아 있었다.** 축 3의 119행 전량을 함수 이름·언어로 다시 떠서 위치란과 대조한 결과:
>
> | | 수 | |
> |---|---|---|
> | 정확 | 84 | 위치란의 파일 = 실측 정의 지점 |
> | **거짓** | **3** | #104(유령 파일) · #105(쌍 오식별) · #107(서술이 실측과 다름) |
> | 불완전 | 1 | #38 — 6곳 중 5곳만 적음 |
> | 모호하나 참 | 12 | "동일 파일쌍"(7) · "(다수, 표본)"(3) · "외 N"(2) — 대조해 보니 전부 맞다 |
> | 빈칸(`—`) | 19 | seed 시점 행. 틀린 것이 아니라 **안 적힌 것** |
>
> 84+3+1+12+19 = 119. **거짓 3건 중 2건(#104·#105)은 파일명을 안 적어 기계적 대조를 빠져나갔고**, 그래서 3라운드는 "위치란이 대는 파일이 틀렸나"만이 아니라 **"위치란이 파일을 대기는 하나"** 도 함께 봤다. 세 건 다 유예 버킷에 있었다 — 2라운드가 멈춘 자리다.
>
> **축 1·2·4(31행)에는 위치란이 아예 없다** — 그 행들은 **5열**(`# · 후보 · 분류 · 조치 · 근거`)이고 축 3의 8열에만 위치란이 있다(행 모양 분포 실측: `{5: 31, 8: 119}`). 그래서 축 3과 같은 **위치란 재도출**은 대상 자체가 없다.
>
> **그러나 '틀릴 칸이 없다'는 것은 아니다** — 후보란이 위치 프로즈를 겸하고, 그것은 틀릴 수 있다. 앞 판이 여기서 *"틀릴 칸이 없으므로"* 라고 적은 것은 **측정하지 않은 것을 안전하다고 선언한 것**이다(이 태스크가 잡으려는 바로 그 형태). fix round 4 가 실제로 재서 고쳤다:
>
> | 잰 것 | 결과 |
> |---|---|
> | 후보란의 경로·플러그인 이름 (31행 전수) | **#1 하나가 거짓** — `spec-distill` 이라 적었으나 실제는 `project-init`. 나머지 30행 정확 |
> | `×N` 의 N (**31행 중 19행**만 `×N` 표기를 갖는다 — 나머지 12행은 쌍 형태) | 19행 전부 정확 |
> | 유예 행의 파일 존재 | 축 1·2·4 에서 **조치란 전체가 유예인 행은 #13 하나뿐**이고 두 파일 존재를 직접 확인. 〔정정(fix round 5): "유예는 #13 하나뿐"은 이 원장의 세는 법(조치란이 `**유예`로 **시작**하면 유예) 아래에서만 참이다 — **#8 도 유예를 담는다**: 조치가 *"판정 헬퍼(`ag`) 이관 = Task 14 · 잔여는 **유예 E**"* 인 혼합 행이라 배정으로 세어진다. 갭이 아니라 표현의 문제였고, #8 의 두 파일 존재도 함께 확인했다.〕 |
>
> #1은 우연·모집단 밖이라 처분에 영향이 없다. 기록하는 이유는 **틀린 칸이 실재했다**는 것이고, 그것이 *"배정된 행은 태스크 Files 대조가 한 겹 더 받는다"* 가 유예·우연 행에는 성립하지 않는다는 앞 라운드의 교훈과 같은 자리이기 때문이다.

### 유예 규칙 — 무엇이 유예될 수 있나

유예는 조치의 한 종류지 미배정이 아니다. 다만 유예가 "안 하기로 했다"의 완곡어가 되면 이 원장이 다시 자기 채점이 되므로, **셋을 모두 만족하는 행만** 유예로 간다:

1. **§12.4 락의 위반이 아님을 실측했다.** Task 35 Step 1의 스캐너를 그대로 돌려 나온 위반 쌍 목록(집합 A, 6쌍)에 그 행의 파일 쌍이 없다. 집합 A 가 이 트리의 위반 **전량**이므로 목록에 없다는 것은 20줄 임계 아래라는 뜻이다.
2. **유예 사유가 비용이 아니라 구조적 사실이다** — 설계가 그 범위를 정의하지 않았거나(A·B), 추출이 순증이거나(C), 통합이 소비자 동작을 바꾸는 별개 결정이거나(D).
3. **사유를 그 행에 적는다.** 아래 묶음 이름만으로 끝내지 않고 각 행에 실측치(줄 수·정의 지점·계약 차이)를 남긴다.

| 묶음 | 행 수 | 사유 |
|---|---|---|
| **A** 셸 하네스 | 13 | 설계 §9가 `shared/tests/` 를 판정 헬퍼의 자리로 삼은 **근거는 소유 관계**다 — *"판정 헬퍼는 어느 한 플러그인의 것이 아니다"*. 픽스처 빌더·훅 실행 래퍼·윈도우 추출은 **그 플러그인 자신의 것**이라 그 근거가 옮겨가지 않는다 |
| **B** python 테스트 헬퍼 | 13 | python 테스트 헬퍼의 **정본 자리를 이 사이클이 만들지 않는다** — 설계 §9는 셸 판정 헬퍼(`assert.sh`) 한정이다 |
| **C** 1~3줄 관용구 | 8 | 정본으로 빼면 소비 지점마다 import/source 1줄이 생겨 **순증** |
| **D** 통합이 동작 변경 | 9 | 두 본문의 계약·방향·소비 키가 다르다. 합치는 것은 별개 결정 (§15.1) |
| 합 | **43** | |

**E는 묶음이 아니다.** #8의 셀 안에만 있는 각주다 — 그 행은 판정 헬퍼 부분이 Task 14로 가므로 **배정으로 센다**(위 "세는 법"). 유예 행을 세는 곳에 E를 더하면 43·45가 갈린다.

유예 행 (43): 13 · 36 · 50 · 62 · 66 · 72 · 74 · 76 · 78 · 82 · 86 · 87 · 89 · 101 · 103 · 107 · 108 · 109 · 112 · 113 · 114 · 115 · 116 · 117 · 118 · 120 · 123 · 124 · 126 · 127 · 128 · 129 · 130 · 131 · 132 · 138 · 139 · 140 · 141 · 142 · 143 · 144 · 145.

이 목록은 설계 §15.1 표의 "이번 사이클" 행에 한 줄로 모아 다음 사이클이 찾을 수 있게 한다 — **새 원장을 만들지 않는다**(C11).

### 기계적 확인

이전 판의 "조치 없음 grep" 은 그대로 두되(여전히 **필요**조건이다) **그것만으로는 부족하다**는 것이 재검토의 결론이다. 세 검사를 함께 돌린다 — ③이 이번 2라운드에서 #112·#116을 잡았다.

```bash
cd /Users/jeonghokim/Downloads/devbrew

# ① 조치란이 비었거나 "조치 없음" 인 진짜/부분 사본 행 → 0건이어야 한다.
#    (필요조건일 뿐이다. 이 검사만 돌리고 "미배정 0"이라 적은 것이 최초 판의 결함이었다.)

# ② 배정 + 유예 = 모집단인가. 세 곳에 흩어진 수를 눈으로 맞추지 않고 여기서 한 번 센다.

# ③ **위치란이 사실인가** — 축 3 전량(119행)의 정의 지점을 (이름, 언어)로 직접 뜬다.
#    ②까지 통과해도 위치란이 틀리면 그 위에 얹힌 조치도 틀린다: #116은 위치란이
#    "qg-gc.py↔spec-distill-gc.py" 였는데 실제 정의는 두 테스트 파일에 있었고,
#    그래서 "Task 21" 이라는 조치가 covered 로 통과해 있었다.
#    ⚠ 이름만으로 `sort -u` 하면 119 → 116 이 된다(check·emit·run_hook 이 두 언어를 겹친다).
grep -oE '^\| [0-9]+ \| `[A-Za-z_][A-Za-z0-9_]*` \((py|sh)\)' "$CENSUS" \
  | sed -E 's/.*`(.*)` \((py|sh)\)/\1 \2/' | sort -u \
  | while read -r fn lang; do
      if [ "$lang" = py ]; then pat="^[[:space:]]*def ${fn}\("; ext='\.py$'
      else pat="^[[:space:]]*${fn}\(\)"; ext='\.sh$'; fi
      hits=$(grep -rlE "$pat" plugins/ shared/ 2>/dev/null \
               | grep -E "$ext" | grep -vE '/(fixtures|mocks|harness)/' | tr '\n' ' ')
      printf '%-28s %-3s %s\n' "$fn" "$lang" "${hits:-(정의 없음 — 위치란 재확인)}"
    done
#    출력의 파일 경로가 그 행의 위치란과 일치해야 한다. 불일치는 조치 재검토 신호다.
```

> **③은 축 3 전량에 대해 자동화된다.** 위치란은 행마다 프로즈 표기(`qg-gc.py↔spec-distill-gc.py` · `동일 파일쌍` · `위와 같은 …`)라 그쪽에서 출발하면 파서가 조용히 놓친다 — **그 놓침이 이 결함의 원인이었다.** 대신 **함수 이름과 언어는 1열에 기계적으로 있으므로** 이름에서 출발해 정의 지점을 뜨고, 그 결과를 위치란과 사람이 대조한다.
>
> 〔실측〕 위 `sort -u` 는 **116**개 이름을 낸다(축 3 행은 119개). 세 이름이 두 언어를 겹쳐 한 줄로 합쳐지기 때문이다 — **`check` · `emit` · `run_hook` 이 각각 (py)행과 (sh)행을 갖는다.** 그래서 이 셋은 언어를 붙여 따로 떠야 한다(`^def check(` 와 `^check()` 는 다른 집합이다). 116을 119로 읽으면 이 셋의 한쪽 언어가 검사되지 않은 채 지나간다.
>
> Task 2 Step 4b 가 이 검사를 원장 작성 시점에 돌리도록 바뀌었다.

(fix round 1: 최초 판은 진짜 사본 25 / 부분 사본 64 / 우연 58 / 템플릿-인스턴스 3이었다. 우연 rows 중 위치란이 "—"이거나 근거가 추측 어휘(판단/추정)였던 항목을 전수 재검증해 11건을 재분류했다(우연→진짜 사본 2건: #58·#74, 우연→부분 사본 9건: #66·#76·#78·#82·#94·#96·#101·#103·#121). 재검증한 우연 행은 약 40행이며 그중 11행이 바뀌고 나머지는 실측 본문 판독으로 우연 판정이 확인됐다 — 상세 근거는 각 행 및 위 §discrepancy 참조.)
