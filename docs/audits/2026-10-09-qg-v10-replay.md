# qg v10 재생 비교 — 컷오버 ② 의 AC8

설계 `docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md` AC8 · Verification Plan ② 「재생 비교」. 측정일 2026-10-09, 브랜치 `feature/qg-v10-review-diet` (HEAD `11424aef`).

## 목적

AC8: 사람이 고른 과거 결함 diff(옛 qg 가 막은 것) 전부에서 v10 리뷰가 각 결함을 **막는 지적**(재비판을 살아남은 CRITICAL·IMPORTANT)으로 내는가. 하나라도 놓치면 컷오버 ② 를 하지 않는다.

한 번 재는 측정이다. 락으로 남기지 않는다. 표본 밖의 놓침은 재지 않는다(설계 「알려진 한계」).

## 방법

결함마다(고친 커밋 F):

1. 트리 = `git archive F`(고친 뒤의 트리). 그 위에 `git diff F F^ -- <코드 파일>`(고침을 되돌린 diff)을 커밋하지 않은 변경으로 얹었다. 리뷰 대상 diff 는 그 트리의 `git diff`.
2. 리뷰어 자리 — v10 SKILL Step 3 그대로: `code-reviewer`·`security-reviewer` 는 항상, 조건부 자리는 v10 신호 규칙(SKILL 의 조건부 표)으로 골랐다. 모든 자리가 같은 기준 블록(`references/review-criteria.md`)과 같은 재생 지시문(입력 · 읽기 전용 · git 이력 금지 · YAML 출력)을 받았다.
3. codex — 브랜치의 `run_codex_reviewer.sh` 를 결함마다 한 번(8회), 전부 rc=0 · `codex_failed: false`.
4. 재비판 — 자리 출력을 `findings.yaml` 로 모아 `synthesize_findings.py prepare` 로 익명화한 뒤, `code-recritic` 이 여섯 슬롯(project_dir · scope · findings · diff · intent · profile)만 받고 판정했다.
5. 합성 — SKILL Step 4 펜스대로 `synthesize_findings.py --findings … --recritic … --recritic-map … --recritic-diff … --emit-verdict --angles …`. 각도 파일은 세 각도 모두 `filled`(모든 자리가 돌았다). 8건 전부 rc=0.

판정 — F 의 실제 고침(메시지 · 코드 diff)을 읽고, 살아남은 막는 지적 중 **같은 근본 원인 · 같은 동작 실패를 같은 코드 근처에서** 짚은 것이 하나라도 있으면 「잡음」. 다른 문제에 대한 막는 지적이나 SUGGESTION 으로만 살아남은 지적은 세지 않는다. F 가 여러 결함을 고쳤으면 diff 에 들어간 결함 **각각**을 대조했다.

### 계획과 다른 점

- **리뷰 층만 쟀다.** `/qg` 의 게이트(scope · trivia · Fix-loop)도, 차등 테스트(②)도 돌리지 않았다. 합성기에 `--differential` 을 싣지 않았다 — 판정 `defect` 는 리뷰 지적만으로 난 것이다.
- **옛판 열은 다시 돌리지 않았다.** 계획 2는 「설치된 main 판과 브랜치 판을 같은 diff 에」 돌리라 했다. 옛판 열은 고친 커밋이 남긴 기록(어느 리뷰가 무엇을 잡았는가)에서 옮겼다.
- **브랜치 persona 는 흉내 냈다.** 설치본에 아직 없는 브랜치 판 `security-reviewer` · `code-recritic` 은 그 persona 본문을 실은 general-purpose opus agent 로 돌렸다. tool 범위는 지시문으로만 묶였다(frontmatter allowlist 집행이 아님).
- **intent 는 비웠다.** 고친 커밋의 메시지가 답을 새므로 의도 출처는 빈 값이고, codex 도 `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE=1` 로 돌렸다.
- **조건부 리뷰어**는 v10 신호 규칙으로 정했다 — 조용한 실패 5건(`silent-failure-hunter`), 주석 1건(`comment-analyzer`), 없음 2건.
- 역매핑 파일 이름은 SKILL 의 `recritic-map.json` 대신 `recritic-map.yaml` 이다(내용은 `prepare` 가 쓴 JSON 그대로).

### 이 측정이 약한 자리 — 답의 누설

되돌린 diff 와 트리가 원래 결함 때보다 **쉬운 문제**를 냈다. 판정을 읽을 때 같이 읽어야 한다.

- **고침의 근거 주석이 삭제 줄로 보였다.** `git diff F F^` 는 고친 커밋이 더한 설명 주석·docstring 까지 지운다. 8건 모두 diff 의 `-` 줄에 그 근거가 실렸다(2f9dd0f8 은 삭제 37줄 중 36줄이 주석이고, 결함을 그대로 서술한다). 0f795b50 의 지적은 스스로 「drops the comment that explained why」라고 쓴다.
- **고친 커밋의 회귀 테스트가 트리에 있었다.** 트리는 F 시점이라 고침과 함께 들어온 테스트가 남아 있다. 지적 여럿이 그 테스트를 근거로 댄다(예: `tests/test_setup_qg.sh` Case 6, `test_codex_yaml_garbage_marker_failclosed`).

그래서 이 결과는 「v10 의 리뷰 층이 이 결함들을 **떨어뜨리지 않는다**」(기준 블록 · 관문 E · 합성이 막는 지적을 깎아내지 않는다)는 증거로는 쓸 수 있다. 「옛 qg 처럼 단서 없이 **찾아낸다**」의 증거로는 약하다. 후자를 재려면 고친 커밋이 더한 주석과 테스트를 뺀 트리 위에서 다시 돌려야 한다.

## 결과

> **누설된 측정 — 기록으로만 남긴다.** 1차의 리뷰 대상 트리는 F 에 고침을 되돌려 얹은 것이라, 고침의 설명 주석 · 회귀 테스트 · CHANGELOG 가 리뷰어에게 그대로 보였다. 답이 새어 나간 측정이다. AC8 판단은 아래 [2차 — 단서 제거](#2차--단서-제거)로 한다.

| 결함(F · 요지) | 옛판(기록) | 새판 verdict · blocking/optional | 잡았나 | 새판 지적 원문 한 줄 |
|---|---|---|---|---|
| `a4b94ccb` · `setup-qg.sh` 가 `both` 를 거부해 `/qg both` 가 preflight 에서 죽음(C3) + `gate=runtime` 우선순위 배너 삭제(F6) | 막음 — self-/qg dogfood(codex 독립 리뷰 + pr-review-toolkit) | `defect` · 3/1 | yes | IMPORTANT `setup-qg.sh:37` (codex): "Removing the `both` parser breaks the still-supported `/qg both` command: setup exits 1 with `Unknown argument: both`, causing preflight to abort before either gate runs." — 같은 결함이 code-reviewer 의 CRITICAL `:33` 으로도 살아남았고, F6 은 재비판자 추가 IMPORTANT `:309` "The diff also deletes the single-gate precedence notice (…)" |
| `5b601c3e` · 표 셀 escape 누락 + 미지 severity 가 개수 줄에서 빠짐 | 막음 — self-qg iter-1 (R4) | `defect` · 7/0 | yes | CRITICAL `synthesize_findings.py:120`: "Removing _norm_sev brings back a silent skip." · IMPORTANT `:141` (security): "Removing the _cell escaping lets reviewer-supplied file, summary and sources values that contain `\|` or CR/LF go into the pipe table unescaped." |
| `67ba7995` · plugin-audit 계약 결함 8건(diff 범위) — backfill 이 codex 로 죽은 축을 가림 · gate-E NOQ 거짓 RED · degraded 미정규화 크래시 · grounding 이 `evidence[0]` 만 · 여러 줄 인용 거짓 폐기 · malformed `plugin.json` 크래시 · `cost_class` 헤더 만족 · render 크래시 | 막음 — /qg 브랜치 보안 리뷰(4-way + codex + adversarial) 12건 | `defect` · 14/1 | yes (8/8) | CRITICAL `assemble-audit-data.py:65`: "gate-E scope-out NOQ no longer carries reason_code "gate_e_scope_out" and its why_not_gap ("scope-out (gate E)") no longer contains "범위 밖", so validate-audit-data.py (lines 83-88) counts zero scope-out NOQs and fails every audit that has a gate-E refuted finding (false RED)." — 나머지 7건도 각각 막는 지적으로 살아남음 |
| `0f795b50` · `CHARTER_PLACEHOLDER_RE` 가 `\{\{.*?\}\}` 로 O(n²) 백트래킹(ReDoS) | 막음 — Review gate iter 1, F1 (security, IMPORTANT) | `defect` · 1/0 | yes | IMPORTANT `docs-lint.py:390`: "The change swaps the linear `\{\{[^{}]*\}\}` for the non-greedy `\{\{.*?\}\}` and drops the comment that explained why. On a long single-line value made of `{` characters with no closing `}}`, the new pattern backtracks in O(n^2)." |
| `782ffb67` · codex 러너 두 곳이 guarded truncate 앞에서 산출물에 써 쓰기 실패 시 stale YAML 이 clean 으로 읽힘(B2 · B3) | 막음 — /qg whole-branch 리뷰 | `defect` · 6/2 | yes (2/2) | CRITICAL `run_artifact_codex_reviewer.sh:29`: "The combined `[ -z "$PROJECT_DIR" ] \|\| [ -z "$OUT" ]` check calls emit_fail and then `exit 0` before the guarded truncate (line 65)." · CRITICAL `run_spec_codex_reviewer.sh:39`: "The missing_project_dir, project_dir_unreachable and scratch_dir_uncreatable branches (lines 39-58) now write OUTPUT_PATH with a bare `>` before the guarded truncate (line 86) and before the EXIT trap is set." |
| `bef38834` · `parse_codex_yaml` 이 `codex_failed` 키 존재만 보고 garbage 값을 성공으로 읽음 + `open()` 무가드 | 막음 — /qg iter-2 재리뷰(codex + silent-failure-hunter) | `defect` · 4/0 | yes (2/2) | CRITICAL `merge_review.py:148`: "The changed marker check sets saw_failed_key on any codex_failed value and treats every value other than "true" as success." · IMPORTANT `:116`: "The change removed the try/except OSError around open/readlines." |
| `c4846c39` · probe 백스톱이 `probe_budget.py increment` 의 fail-closed exit 를 버림 | 막음 — /qg branch self-dogfood(6/6 독립 수렴) | `defect` · 3/0 | yes | CRITICAL `conducting-interview/SKILL.md:180`: "The `\|\| { ... }` guard on `probe_budget.py increment "$STATE"` is removed, so increment's fail-closed exit 1 is now discarded with no message." |
| `2f9dd0f8` · 종료 코드 표 확장이 import·수집 실패(pytest 2 등)를 `unrun` 으로 보내 비대칭 회귀가 비차단 SKIP 이 됨(C1) + bulk 순서 의존 판정(C2) | 막음 — /qg Review gate iter 2 | `defect` · 5/4 | yes (2/2) | CRITICAL `run-test-selection.sh:642`: "pytest exit 2 is not only "interrupted": it is also what pytest returns for collection and import errors." · IMPORTANT `:636`: "There is a second effect. In bulk mode the shell and unittest loops assign `rc=$?` in last-writer-wins order (lines 671-684), and `fail` and `unrun` are now on different axes." (C2) |

새판 판정 줄은 8건 모두 `verdict: defect`, 각도 `security · adjudication · different-premise` 모두 `filled`, `미판정 0`, `실행 차단: 아니오`. 재비판자는 8건 어디서도 reject · lower 를 내지 않았다(confirm 76 · raise 5 · 추가 1). 그래서 기준 블록과 관문 E 가 이 표본에서 막는 지적을 깎은 일은 없다. `배관 손실` 칸(1 · 7 · 21 · 2 · 8 · 6 · 4 · 5)은 전부 재비판자의 `same_as` 를 합성기가 강제로 지운 수(`gate=False`)와 같다 — 공시이고 판정을 바꾸지 않는다.

## 결론

8건 중 8건을 잡았다. diff 에 들어간 하위 결함까지 따지면 20건 중 20건이다. **AC8 의 ② 조건은 이 측정 방법 아래서 충족된다.**

단 위 「답의 누설」 때문에, 이 결과가 보여 주는 것은 v10 리뷰 층이 결함을 떨어뜨리지 않는다는 데까지다. 컷오버 판단에 「단서 없이 찾아낸다」까지 필요하면, 고친 커밋의 주석·테스트를 뺀 트리로 다시 재야 한다.

## 비용

| 항목 | 수 |
|---|---|
| 리뷰어 자리(Claude agent) | 22 — `code-reviewer` 8 · `security-reviewer` 8 · `silent-failure-hunter` 5 · `comment-analyzer` 1 |
| 재비판자(`code-recritic`) | 8 |
| codex 호출 | 8 (전부 rc=0) |
| 합성기 실행 | 8 (전부 rc=0) |

재현 입력(diff · 트리 · 자리별 YAML · 재비판 원문 · `synth.out`)은 리포에 남기지 않는다(job tmp `replay/`).

## 2차 — 단서 제거

1차의 누설(위 「답의 누설」)을 걷어 내고 같은 리뷰 층을 다시 돌렸다. 측정일 2026-10-09.

### 방법

결함마다(고친 커밋 F):

1. **트리 = F^.** `git archive F^`(결함이 있던 트리)를 풀고, 그 위에 기준선 커밋을 하나 만들었다 — F^ 에 **F 의 코드 변경 중 주석이 아닌 것만** 얹은 상태다. 리뷰 대상 변경은 기준선 → F^(고침을 걷어 내는 diff)이고, 적용하면 F^ 와 바이트 단위로 같다(8건 모두 확인).
2. **F 의 테스트 · CHANGELOG · 문서는 없다.** 트리가 F^ 이므로 F 가 더한 회귀 테스트와 CHANGELOG 항목, F 가 고친 SKILL · 문서는 F^ 내용 그대로다. F 가 더한 주석 · docstring 줄은 기준선에서 뺐다(삭제 줄에 근거 주석이 보이지 않는다).
3. **intent 는 비웠다.** codex 는 `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE=1` 로 돌렸다.
4. **리뷰 층은 1차와 같다.** `code-reviewer` ×8 · `security-reviewer` persona ×8(general-purpose opus) · 조건부 자리는 v10 신호 규칙대로 `silent-failure-hunter` ×5(`5b601c3e` · `67ba7995` · `782ffb67` · `bef38834` · `c4846c39`) · codex ×8(브랜치 러너) · `code-recritic` persona ×8 · `synthesize_findings.py`(8건 모두 rc=0, `verdict: defect`).

판정 기준은 1차보다 좁혔다. 살아남은 막는 지적(재비판 뒤 CRITICAL · IMPORTANT) 가운데 **같은 파일에서 같은 실패 기제**를 짚은 것이 있어야 「잡음」이다. 같은 파일의 다른 결함, 기제를 대지 않은 「실패할 수 있다」는 세지 않는다. F 가 여러 결함을 고쳤으면 하위 결함마다 따로 대조했다. F 의 판정은 주 결함(제목 · 주된 코드 변경)으로 정했다. 매니페스트가 남은 단서로 적은 것(삭제 줄의 설명형 문자열 리터럴 등)에 기댄 잡음은 「단서 도움」으로 표시했다.

### 결과

| F | 결함 요지 | verdict | blocking | 잡았나 | 잡은 자리 | 재비판 | 단서 도움 |
|---|---|---|---|---|---|---|---|
| `a4b94ccb` | `setup-qg.sh` 가 `both` 를 거부해 `/qg both` 가 preflight 에서 exit 1(C3) · 부: `gate=runtime` 우선순위 배너 삭제(F6) | `defect` | 2 | **잡음** (C3) · F6 놓침 | C3: `code-reviewer` IMPORTANT `:33` · codex IMPORTANT `:37`(`branch both` 오소비까지) | C3 둘 다 confirm(codex 는 `same_as`). F6 은 `code-reviewer` 가 SUGGESTION `:309` 로만 냈고 재비판이 reject(SKILL.md:169 의 advisory 가 정본이라는 근거) | 아니오 — 근거가 된 SKILL · README 의 `both` 는 F^ 자체 문면 |
| `5b601c3e` | 표 셀 escape 제거(`\|` · 개행이 행을 깸) + 미지 severity 가 개수 줄에서 조용히 빠짐 | `defect` | 5 | **잡음** (2/2) | 두 결함 모두 `code-reviewer` · `security-reviewer` · `silent-failure-hunter` · codex 넷 | confirm 10 · raise 1(SFH `:157` SUGGESTION→IMPORTANT) | 아니오 |
| `67ba7995` | plugin-audit 계약 결함 8건 — gate-E NOQ 거짓 RED(문자열 · axis int) · degraded 미정규화 → render 크래시 · backfill 이 codex 로 죽은 축을 가림 · grounding `evidence[0]` 만 · 여러 줄 인용 거짓 폐기 · malformed `plugin.json` 크래시 · `cost_class` 헤더 만족 | `defect` | 12 | **잡음** (8/8) | 주 결함 둘: gate-E 거짓 RED `code-reviewer` CRITICAL `:67`(+codex · SFH) · render 크래시 `code-reviewer` CRITICAL `render:146`(+SFH · codex). 나머지 6건도 각각 IMPORTANT(2~4 자리) | confirm 28 · raise 2(axis int `:66` · `isinstance(cited, int)` `:32`) | gate-E 거짓 RED 만 — 삭제 줄의 `"scope-out (gate E) — 범위 밖"` 리터럴. render 크래시 등 나머지는 아니오 |
| `0f795b50` | `CHARTER_PLACEHOLDER_RE` 가 `\{\{.*?\}\}` 로 O(n²) 백트래킹(ReDoS) | `defect` | 2 | **잡음** | codex 단독 IMPORTANT `:390`(70K `{` 에 10.9 s, hook 10 s 타임아웃 초과 실측). `code-reviewer` 는 같은 기제를 SUGGESTION 으로, `security-reviewer` 는 0건 | confirm(`code-reviewer` 것을 `same_as` 로 묶음) | 아니오 |
| `782ffb67` | codex 러너 두 곳이 guarded truncate 앞에서 산출물에 써 쓰기 실패 시 rc 0/1 + stale YAML 잔존(B2 · B3) | `defect` | 5 | **잡음** (2/2) | B2 `run_artifact…:25/29/30`: `security-reviewer` · `code-reviewer` · SFH · codex. B3 `run_spec…:39/40`: `code-reviewer` · `security-reviewer` · SFH · codex | confirm 12 | 아니오 — 삭제 줄의 `echo "…기록 실패…"` 리터럴이 보이지만, 지적은 F^ 의 헤더 계약(rc 3)과 호출자의 `rc==3` 삭제 규칙에서 기제를 끌어냈다 |
| `bef38834` | `parse_codex_yaml` 이 `codex_failed` 키 존재만 보고 garbage 값을 성공으로 읽음 + `open()` 무가드 | `defect` | 5 | **잡음** (2/2) | 두 결함 모두 넷 자리(SFH 는 CRITICAL `:147`) | confirm 8 | 아니오 |
| `c4846c39` | probe 백스톱이 `probe_budget.py increment` 의 fail-closed exit 를 버림 | `defect` | 1 | **잡음** | 넷 자리 수렴, IMPORTANT `SKILL.md:180` | confirm 4 | **예** — diff 전체가 `"…백스톱 무력화 위험(카운터 부재/malformed/state unwritable)…"` 메시지를 품은 가드의 삭제다. 단 `security-reviewer` · SFH 는 `probe_budget.py`(`_read_counter` 가 부재를 0 으로 · `_bump_line` 이 raise)를 따라가 기제를 따로 확인했다 |
| `2f9dd0f8` | 종료 코드 표 확장이 수집 · import 실패(pytest 2 등) · head 쪽 124/137 · go 2 를 `unrun` 으로 보내 비대칭 회귀가 SKIP 이 됨(C1) + bulk last-writer-wins `rc` 로 순서 의존 판정(C2) | `defect` | 3 | **잡음** (2/2) | C1: `code-reviewer` · `security-reviewer` IMPORTANT `:642`(pytest 2 = collection error → SILENT_DROP), `code-reviewer` IMPORTANT `:645`(go 2). C2: `code-reviewer` `:636` | C1 confirm. C2 는 SUGGESTION 으로 나왔다가 재비판이 **raise** 해서 막는 지적이 됐다. codex 의 다른 지적(go 는 빌드 실패도 exit 1)은 lower | 아니오 — 남은 주석은 F^ 의 것이고 오히려 결함 쪽 매핑을 옹호한다 |

재비판자 판정은 8건 합계 confirm 73 · raise 5 · reject 1 · lower 1 · 추가 0 이다.

### 합계

**8건 중 8건을 잡았다(8/8).** 하위 결함으로는 `a4b94ccb` 의 F6(우선순위 배너) 하나를 놓쳐 20건 중 19건이다. 다만 둘은 끝이 얇다.

- `0f795b50` 은 codex 한 자리가 실측으로 잡았다. Claude 자리 둘 가운데 `code-reviewer` 는 같은 기제를 SUGGESTION 으로 냈고 `security-reviewer` 는 놓쳤다. codex 가 죽은 실행이었다면 이 결함은 막는 지적 없이 지나갔다.
- `2f9dd0f8` 의 C2 는 재비판자의 raise 가 없었다면 SUGGESTION 으로 남았다.

단서 도움은 `c4846c39`(주 결함) 와 `67ba7995` 의 gate-E 하위 결함 둘이다. `c4846c39` 를 빼도 7/8 이다.

### 한계

1. **남은 문자열 단서.** 실행 코드 안의 설명형 문자열 리터럴은 지울 수 없어 삭제 줄에 남았다(매니페스트의 residual clues): `67ba7995` 의 `"— 범위 밖"`, `782ffb67` 의 stderr 메시지 셋, `c4846c39` 의 백스톱 경고. 위 표의 「단서 도움」 칸이 그 영향을 적는다.
2. **codex 첫 실행은 8건 모두 실패했다.** 트리에 `.git` 이 없어 codex 가 `Not inside a trusted directory` 로 거부했다. 트리에 기준선 커밋을 준 뒤 다시 돌렸다 — codex 호출은 **16회**(실패 8 · 성공 8, 성공분은 전부 rc=0 · `codex_failed: false`). `code-reviewer` 자리는 트리에 `.git` 이 없던 때 돌았다.
3. **persona 자리는 흉내다.** `security-reviewer` · `code-recritic` 은 브랜치 persona 본문을 실은 general-purpose opus agent 로 돌렸다. tool 범위는 지시문으로만 묶였다(frontmatter allowlist 집행이 아님).
4. **옛판 열은 다시 돌리지 않았다** (1차와 같음).
5. **자리 사이 격리는 지시문뿐이었다.** 재생 지시문은 `<F>/` 안의 파일 읽기를 허용했는데, 그 폴더에는 조건부 자리를 고른 한 줄 근거(`conditional.txt`, 예: 「`failed = (v == "true")` treats any other value as success」)가 모든 자리보다 먼저 있었고, 늦게 돈 자리 때는 먼저 끝난 자리의 YAML 도 있었다. 자리가 그것을 읽었는지는 이 기록만으로는 확인할 수 없어서, 리뷰어 21자리의 대화 기록에서 도구 호출을 따로 훑었다. `conditional.txt` 를 읽은 자리도, 다른 자리의 YAML · `codex.yaml` 을 읽은 자리도 없었다. 걸린 것은 자기 출력 파일을 쓴 호출 하나뿐이다. 다만 디렉토리 목록(파일 이름)이 보였는지는 이 훑기로 가르지 못한다.

### 비용

| 항목 | 수 |
|---|---|
| 리뷰어 자리(Claude agent) | 21 — `code-reviewer` 8 · `security-reviewer` 8 · `silent-failure-hunter` 5 |
| 재비판자(`code-recritic`) | 8 |
| codex 호출 | 16 (실패 8 · 성공 8) |
| 합성기 실행 | 8 (전부 rc=0) |

재현 입력은 리포에 남기지 않는다(job tmp `replay2/`).
