# 있는 테스트 정리 — PR 3(문서 리뷰 원장 도우미) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 문서 리뷰 원장 도우미(`r1`)가 같은 프로필 · 문서의 첫 라운드 원장을 한 번 지어 복사해 쓰게 하고(①), 변이 행렬이 프로필 사본을 한 번만 만들게 하며, spec-distill 잔존물 테스트 둘의 sid 전제 확인을 python 한 번으로 묶어(③) — 확인을 하나도 잃지 않고 — 대상 파일들의 시간을 줄인다.

**Architecture:** `shared/tests/fixtures/docreview/cases.sh` 의 `r1` 안에 켜야만 도는 템플릿 길을 둔다 — 환경 변수 `DOCREVIEW_R1_TEMPLATES` 가 가리키는 폴더에 키(엔진 폴더 · 프로필 · 문서의 경로와 내용)마다 처음 지은 원장을 두고, 다음 `r1` 은 새 `docreview-XXXXXX` 폴더에 복사한 뒤 원장의 문서 경로와 라운드 시작 표식을 그 폴더에 맞게 엔진(`$SCRIPTS`)으로 다시 적는다. 켜지 않으면 `r1` 은 지금과 같다. 잔존물 테스트 둘은 sid 마다 두 번 띄우던 python 을 한 번으로 묶고, 첫 sid 하나는 명령줄로 남겨 묶은 결과와 견준다.

**Tech Stack:** bash(macOS 3.2 호환) · Python 3.9(레포의 `python3`) · `shared/tests/assert.sh` · `cksum` · git.

**Spec:** `docs/superpowers/specs/2026-11-26-test-prune-design.md` — §1 의 PR 3 몫. 범위는 사용자가 승인한 판정 표(지휘 상태 폴더 `files/relay/E4/table-pr3-final.md`, 승인 2026-11-27 「승인 (권장)」)가 정한다. 근거 실측은 같은 폴더의 `table-pr3-a.md` · `table-pr3-b.md`. 값 읽기 묶기(§3 의 ④)는 사용자가 하지 않기로 했다 — 이 계획에 없다. `route_r1` 결과 캐시도 하지 않는다(표).

## AC 가르기

| AC | 과제 |
|---|---|
| AC1 · AC2 | 과제 10(PR 본문에 승인 표 · 승인 줄 · 읽은 담당자 A · 다시 읽은 담당자 B) |
| AC5 | 과제 2 · 3 · 4(①) · 과제 1 과 9(앞 · 뒤 초) · 과제 3 과 4(골든 · 변이 행렬) |
| AC7 | 과제 4(변이 행렬 셀별 대조 — 보안 셀 포함) · 과제 5(변이 넷 + 양성 대조) · 과제 6 |
| AC8 | 과제 9 — 사라진 확인이 없음을 확인한다(있으면 `docs/removed-tests.md` 에 줄) |
| AC9 | 과제 9(지운 파일 0) |
| AC10 | 과제 9(§5 점검 여덟 줄 · 테스트 다섯) |
| AC11 | 과제 7 · 8 |
| AC12 · AC14 | 과제 9 |
| AC13 | 과제 9(공유 잠금 아래 전체 스위트) |

대조 스크립트에 주는 목록: `AC1,AC2,AC5,AC7,AC9,AC10,AC11,AC12,AC13,AC14`.

## Global Constraints

- **표에 없는 테스트는 고치지 않는다**(설계 §2 걸음 3). 이 PR 이 고치는 파일은 `shared/tests/fixtures/docreview/cases.sh` · `shared/tests/test_docreview_{mutations,state,route,advice,ask,gate_plain,intent}.sh` · `plugins/spec-distill/tests/test_reviewing_{brief,spec}_residue.sh` 열 개뿐이다. 둠 행(`test_docreview_gate_visibility.sh` · `test_seed_edit_screen.sh` · `test_framing_review_contract.sh` · `test_interview_state_flow.sh` · `test_begin_round_snapshot.sh` · `test_seed_review_log.sh` · `cases_advice.sh` · `cases_ask.sh`)과 `test_docreview_gate_plain.sh :56–88` 은 건드리지 않는다. 구현 중 새 후보를 찾으면 고치지 않고 보고에 적는다(설계 §2 걸음 3 — 지휘자가 PR 6 표나 `## 미룸` 으로 넘긴다).
- **기본 길은 그대로.** `DOCREVIEW_R1_TEMPLATES` 가 비어 있으면 `r1` 의 동작 · 출력 · 종료 코드가 지금과 같다. `mk_state` 로 시작하는 케이스(`cases.sh:1677` 의 시각을 뒤로 미는 케이스 포함)와 `route_r1` 의 몸통은 바꾸지 않는다. `cases.sh` 의 `docreview_state.py begin-round` 호출 줄은 74개 밑으로 내려가지 않는다(`test_begin_round_snapshot.sh:242` 하한, 지금 79).
- **복사의 조건(표).** 복사본은 `mktemp -d -t docreview-XXXXXX` 로 만든다. 하드 링크 복사를 쓰지 않는다(`cp -R` — 엔진이 링크 수가 1 이 아닌 상태 파일을 거부한다). 원장의 문서 경로는 손 `sed` 가 아니라 `$SCRIPTS` 의 `docreview_state.load_state` / `save_state` 로 다시 적는다(손으로 고치면 원장 손상으로 읽힌다). `save_state` 에 `log_line` 을 주지 않는다(골든 `state.md` 가 깨진다). 템플릿 키에 `$SCRIPTS` 를 넣는다(빠지면 변이 셀 70개 — `sed_state` 67 · `sed_config` 3 — 가 깨끗한 엔진의 템플릿을 받아 이빨을 잃는다).
- **보안 확인의 판정 줄을 쓰지 않는다.** 보안 확인(표의 줄 범위)을 첫째 줄 · 넷째 줄로 지우거나 줄이지 않는다. 변이 행렬의 셀 정의(`test_docreview_mutations.sh` 의 `mut` · `mut_expect` 줄과 sed 프로그램)는 고치지 않는다.
- **bash 3.2.** 연관 배열 · `${var,,}` · `coproc` 없음. `$var` 바로 뒤에 한글 · 「」 같은 비ASCII 글자가 오면 `${var}` 로 감싼다. `$( )` 안에 here-doc 을 두지 않는다. 고친 셸은 `/bin/bash` 로도 한 번 돌린다. Bash 도구의 셸은 zsh 다 — 파이프의 종료 코드는 `bash -c` 안에서 잡는다.
- **레포 락.** 같은 블록 20줄(200자 이상)을 두 파일에 두지 않는다(`shared/tests/test_no_new_duplication.sh` — 잔존물 두 파일의 묶은 python 은 각자 20줄 밑으로). 새 파일을 만들지 않는다(새 픽스처는 `docreview_fixture_corpus.sh` 와 `# guards:` 선언에 저절로 들어간다). 판을 올리지 않는다 — 고치는 파일이 모두 `shared/tests/` · `plugins/spec-distill/tests/` 아래다(CLAUDE.md 「plugin.json — 필수 키와 판 올림」).
- **변이는 사본에서.** 변이는 커밋한 뒤 `git clone --no-local <이 worktree> <TMPDIR 아래 폴더>` 사본에서만 넣고 `PYTHONDONTWRITEBYTECODE=1` 로 돌린다. 변이마다 사본의 diff 줄 수를 적어 sed 가 실제로 맞았는지 보인다. 이 worktree 에서 `git stash` · `git checkout --` · HEAD 를 뒤로 옮기기를 쓰지 않는다. 커밋은 pathspec 으로 한다.
- **임시 자리.** 기준값 · 보고 · 변이 사본은 지휘자가 준 `TMPDIR` 아래 `e4-pr3/` 에 둔다(git 이 추적하지 않는다). 공유 임시 폴더를 글롭으로 지우지 않는다 — 자기가 만든 경로만 지운다.
- **전체 스위트는 공유 잠금 아래에서만.** 지휘자가 준 `suite_lock.py run --lock <잠금> --owner <이름> --wait 3600 -- bash -c 'bash tools/suite/run-all.sh'` 꼴로만 돈다. 대상 파일의 시간 재기도 같은 잠금 아래에서 돈다(과제 1 · 9).

## Review Focus

설계와 표가 뜻하지만 어느 확인도 이름 대지 않는 입력이다. 줄마다 그 코드를 가진 과제에 확인이 있다.

1. **같은 경로의 문서가 r1 호출 사이에 바뀐다.** 두 번째 원장은 바뀐 내용을 싣는다 — 템플릿 키에 문서 · 프로필의 내용이 든다(과제 2 `case_r1_template_follows_doc_content`).
2. **r1 을 부르기 직전에 쓴 파일.** 복사본의 라운드 시작 표식은 그 파일보다 뒤다 — 새로 지은 원장과 같다. 템플릿이 오래돼도(변이 행렬은 한 바퀴가 수 분이다) 「라운드 시작 앞에 쓴 산출물은 부재」 판정이 바뀌지 않는다(과제 2 `case_r1_template_round_start_after_call`).
3. **템플릿 폴더를 쓸 수 없다**(그 경로가 파일이다 · 쓰기 권한이 없다). r1 은 새로 지은 1라운드 원장을 내고 알림 한 줄을 낸다(과제 2 `case_r1_template_unusable_falls_back`).
4. **변이된 엔진의 begin-round 가 실패한다.** 실패한 원장은 템플릿이 되지 않아 그 셀은 지금처럼 매번 새로 짓는다 — traceback 도 매번 나온다(과제 4 의 셀별 대조가 잡는다).
5. **테스트 파일이 끝난 뒤 남는 템플릿.** 그 파일이 켠 템플릿 폴더는 `finish` 가 지운다. 바깥에서 켜고 들어온 폴더는 지우지 않는다(과제 3 Step 4 의 셈).

---

## 계획의 판단

설계 · 표가 계획에 맡겼거나 정하지 않아 이 계획이 정한 것이다. ✎ 는 「설계 · 표에 없던 결정」 — 지휘자에게 돌려보내는 자리다.

| # | 자리 | 정한 것 | 이유 | 다른 길 |
|---|---|---|---|---|
| K1 ✎ | 템플릿 키 | 한 줄 — `$SCRIPTS` · 프로필 경로 · 문서 경로 · `cksum < 프로필` · `cksum < 문서` 를 탭으로 이은 글. 이름은 그 글의 `cksum` 으로 `r1-<crc>-<len>`. 같은 이름의 `.meta` 첫 줄이 키 글과 글자까지 같을 때만 그 템플릿을 쓴다 | 표의 키는 경로 셋이다. 같은 경로에 다른 내용을 쓰고 r1 을 다시 부르는 케이스가 생기면 낡은 원장을 받는다(Review Focus 1). `cksum` 은 python 을 띄우지 않는다 | 경로만(표 그대로) |
| K2 ✎ | 라운드 시작 표식 | 복사본에서 `rounds["1"]["started_mtime_ns"]` 가 정수면 `+ (복사본 상태 파일의 수정 시각 − 원본 상태 파일의 수정 시각)` 만큼 옮긴다. 정수가 아니거나 없으면 그대로 둔다 | 두 담당자는 「지금 케이스는 산출물을 r1 뒤에 쓴다」 로 안전하다고 봤다. 그 전제 밖(Review Focus 2)에서 조용히 판정이 바뀌지 않게 한다. 덮어쓰지 않고 옮기므로 표식을 망가뜨리는 변이(없앰 · 정수 아님)는 그대로 보인다 | 옮기지 않는다(표 그대로) |
| K3 | 템플릿이 되는 원장 | begin-round 가 종료 코드 0 으로 끝난 원장만. 템플릿 폴더를 다 옮긴 뒤 `.meta`(1행 키 글 · 2행 원본 원장 폴더 · 3행 원본 상태 파일 수정 시각 ns)를 마지막에 쓰고, `.meta` 가 없는 템플릿은 없는 것으로 친다 | 실패한 원장을 복사하면 begin-round 의 traceback 이 한 번만 나와 변이 셀의 판정이 흐려질 수 있다(Review Focus 4) | 결과와 무관하게 둔다 |
| K4 ✎ | 켜는 길 | 환경 변수 `DOCREVIEW_R1_TEMPLATES` + `cases.sh` 의 `r1_templates_on`(이미 켜져 있으면 그대로, 아니면 `mktemp -d -t docreview-r1tpl-XXXXXX` 를 만들어 켜고 이 셸이 만든 폴더로 적어 둔다). `cases.sh` 의 `finish` 가 이 셸이 만든 폴더만 지운다. 켜는 파일은 표의 셋째 행이 ① 을 고른 여섯(`state` · `route` · `advice` · `ask` · `gate_plain` · `intent`)과 `test_docreview_mutations.sh`(부모가 `$BASE_MUT/r1-templates` 를 직접 export — 그 파일의 trap 이 지운다) | 표의 「opt-in」 을 이 꼴로 정했다. `capture_finalize_golden.sh` 가 EXIT trap 을 덮어쓰므로 정리를 trap 에 기대지 않는다(B 실측). 대상 밖 사용자(`test_docreview_anchor.sh` · `test_writer_trust_notice.sh` · `test_docreview_golden.sh` · `test_docreview_gate_visibility.sh`)는 켜지 않는다 — 표에 없다 | 각 파일이 trap 을 둔다 |
| K5 | 알림 글 | 표준 오류 한 줄 `[cases.sh] r1 템플릿을 쓰지 못했다 — <까닭>. 새로 지은 원장을 쓴다`. 까닭은 `템플릿 폴더에 쓰지 못했다` · `복사하지 못했다` · `원장을 다시 적지 못했다` 가운데 하나. 다시 적기의 python 표준 오류는 버린다 | 변이 행렬의 `run_case` 는 출력의 traceback 유무로 「측정 불가」 를 가른다 — 다시 적기의 traceback 이 새면 판정이 바뀐다. 실패 뒤 새로 짓는 길에서 엔진의 traceback 은 지금처럼 나온다 | 알리지 않는다 |
| K6 ✎ | 도우미 케이스 | 표의 확인(복사본 A 에 쓴 것이 B 에 안 보임 · 복사본에 템플릿 경로 0건)을 `case_r1_template_isolated` 하나로 두고, Review Focus 1–3 의 케이스 셋을 더한다. 넷 다 `cases.sh` 에 두고 `test_docreview_state.sh` 가 부른다 — 그 파일의 Total 이 는다 | 「한 케이스가 한 동작」(`docs/testing.md`). 새 파일을 만들지 않는다(설계 「테스트할 자리」) | 한 케이스에 몰아넣는다 |
| K7 | 변이 행렬의 대비책 | 고친 뒤 셀별 판정 · RED 수 · 생존 수가 하나라도 고치기 전과 다르면, 먼저 그 셀을 사본에서 템플릿 끄고 돌려 원인이 템플릿인지 가른다. 템플릿이면 행렬에서 템플릿을 깨끗한 사본 실행(`clean_result`)에만 켜고 다시 잰다. 그래도 다르면 행렬에서 템플릿을 끄고(프로필 사본 한 번은 남긴다) 보고한다 | 설계 §3 「달라지면 그 파일은 묶기 전으로 되돌린다」 를 ① 에 같은 뜻으로 적용했다 | — |
| K8 | sid 묶기의 짝 | 묶은 python 이 sid 마다 `BAD <sid>`(세션 검사 실패) · `DIR <sid> <자리>` 를 낸다. 전제는 BAD 0 이고 DIR 줄 수가 sid 수와 같을 때 통과다. 짝은 `SIDS` 의 첫 sid 하나를 지금의 명령줄 두 호출(`state_path.py session-id` · `where`)로 돌려 `<sid>|<자리>` 가 묶은 결과와 글자까지 같은지 본다(새 확인 하나 — 두 파일의 Total 이 1 씩 는다) | 표 「sid 하나는 CLI 로 남겨 짝」. 묶은 쪽은 명령줄의 `main()` 을 지나지 않으므로 그 경계는 짝만 잰다 | 짝 없이 묶는다 |
| K9 | 변이 넷(과제 5) | M1 삭제 — `state_path.py` 의 session-id 갈래의 `print(sid)` 를 지운다(짝만 RED). M2 추가 — `SIDS` 에 7자 sid `rb99sht` 를 더한다(전제 RED). M3 반전 — `state_path.py:70` `if not SESSION_PATTERN.match(sid):` 의 `not` 을 뺀다(전제 RED). M4 형태 — `docreview_state.py:947` `print(state_dir_for(a.root, a.doc))` 를 `print(state_dir_for(a.root, a.doc), "x")` 로(짝 RED). 양성 대조는 변이 없는 사본에서 전제 · 짝 모두 통과와 Total/Pass 가 고친 뒤 이 worktree 의 값과 같음 | 보안 갈래(brief 의 `:160–493` 에 든다)의 「변이 넷 + 양성 대조」. 넷 가운데 둘은 묶은 쪽이 볼 수 없는 명령줄 경계를 겨눈다 | — |
| K10 | 과제 6 의 확인 | spec 쪽 전제(`:143–163`)는 표의 보안 범위 밖이라 M2(`rs99sht`)로 「전에 잡던 것을 옮긴 뒤에도 잡는다」 를, M1 로 새 짝이 실패하는 것을 한 번씩 본다 | `docs/testing.md` 「망가뜨려 보기」 의 둘째 · 셋째 줄 | 변이 넷 |
| K11 | 시간 재기 | 공유 잠금 아래에서 대상 파일 아홉을 차례로 `/usr/bin/time -p bash <파일>` 로 한 번씩 돌린다. 앞 · 뒤 같은 명령이고 `uptime` 의 부하를 함께 적는다. 잠금 밖의 다른 일과 겹쳤으면 그렇다고 적는다 | 설계 §3 「다른 스위트와 겹치지 않게」. 지휘자 대조와 같은 잠금이라 그 바퀴와 겹치지 않는다 | 잠금 없이 |
| K12 | 이력 주석 덜기의 확인 | 코드 고침과 다른 커밋으로 한다. 파일 전체를 함수 `__w` 의 몸통으로 `eval` 해 정의하고 `declare -f __w` 로 bash 가 다시 찍은 글이 덜기 전 커밋과 덜기 뒤에 글자까지 같으면 주석만 바뀐 것이다(Task 7 Step 4 의 `norm`) — bash 는 함수를 다시 찍을 때 주석을 버리고 here-doc · 문자열은 그대로 둔다 | here-doc 안의 `#` 줄은 주석이 아니라 자료다 — 줄 앞 `#` 로 거르는 비교는 그 줄을 지운 실수를 못 본다 | 줄 앞 `#` 거르기 |
| K13 | PR | 이 계획은 PR 본문 초안 파일까지 만든다. PR 을 여는 것은 지휘 흐름을 따른다 | 승인 표 · 앞뒤 초 · 구현 보고가 한 자리에 모여야 AC1 · AC2 · AC5 를 본다 | — |

---

## 파일 표

| 파일 | 맡는 일 | 과제 |
|---|---|---|
| `shared/tests/fixtures/docreview/cases.sh` | `r1` 의 템플릿 길 · `r1_templates_on` · `finish` 의 정리 · 케이스 넷 · 이력 주석 | 2 · 7 |
| `shared/tests/test_docreview_state.sh` | 켜기 · 케이스 넷 부르기 · 이력 주석 | 2 · 8 |
| `shared/tests/test_docreview_{route,advice,ask,gate_plain,intent}.sh` | 켜기 한 줄 · 이력 주석 | 3 · 8 |
| `shared/tests/test_docreview_mutations.sh` | 프로필 사본 한 번 · 템플릿 폴더 · 이력 주석 | 4 · 8 |
| `plugins/spec-distill/tests/test_reviewing_brief_residue.sh` | sid 전제 묶기 · 짝 · 이력 주석 | 5 · 8 |
| `plugins/spec-distill/tests/test_reviewing_spec_residue.sh` | 같은 꼴 · 이력 주석 | 6 · 8 |

---

### Task 1: 다시 확인과 고치기 전 기준값

**Files:** 없음(`$TMPDIR/e4-pr3/` 아래 기준값 파일)

- [ ] **Step 1: 근거 자리가 그대로인지 본다** — 아래가 하나라도 다르면 멈추고 보고한다(어긋난 자리 · 지금 값).
  - `grep -n '^r1()\|^route_r1()\|^mk_state()' shared/tests/fixtures/docreview/cases.sh` → `r1` 215 · `route_r1` 1781 · `mk_state` 26. `sed -n 215,218p` 가 `mk_state` → `snap` → `begin-round` 네 줄이다.
  - `grep -c 'docreview_state\.py"\{0,1\} begin-round' shared/tests/fixtures/docreview/cases.sh` → 79. `plugins/spec-distill/tests/test_begin_round_snapshot.sh` 233–241 이 코퍼스 양의 짝 목록, 242 가 하한 74.
  - `cases.sh:1676–1680` 의 시각을 뒤로 미는 케이스가 `mk_state` 로 시작한다.
  - `test_reviewing_brief_residue.sh:160–175` 가 sid 57개의 전제 반복(sid 마다 python 둘 — 114번. 표는 116 이라 적었고, 그 파일은 2026-11-24 뒤로 바뀌지 않았다 — 계획을 쓸 때 확인), `test_reviewing_spec_residue.sh:143–163` 이 sid 21개의 같은 반복이다.
  - `test_docreview_mutations.sh` 의 표 보안 범위 `:265–274` · `:430–434` · `:775–790` · `:864–866` 이 셀 정의다. `grep -c '^mut\(_expect\)\? ' shared/tests/test_docreview_mutations.sh` → 119.
  - `git log --since=2026-11-25 --oneline -- <이 PR 이 고치는 파일 열 개>` 가 비었다(있으면 그 diff 를 읽고 표의 근거가 서는지 보고).
- [ ] **Step 2: 끄기 변수 은퇴 브랜치와의 겹침을 읽는다** — `git fetch -q origin feature/switch-retirement` 뒤 `git diff origin/main...origin/feature/switch-retirement -- <고치는 파일 열 개>`. 계획을 쓸 때는 `cases.sh` 의 단언 글 두 줄(2241 · 3621)과 `test_reviewing_brief_residue.sh` 끝 단언 두 줄이었다 — 준비물 줄 밖이다. 그 브랜치가 지우는 확인은 옮기지 않는다(설계 §8). 이미 기본 브랜치에 머지됐으면 이 브랜치에 기본 브랜치를 합친 뒤 Step 1 부터 다시 본다.
- [ ] **Step 3: 고치기 전 시간을 잰다** — K11 의 꼴로 대상 아홉(`shared/tests/test_docreview_{mutations,state,route,advice,ask,gate_plain,intent}.sh` · `plugins/spec-distill/tests/test_reviewing_{brief,spec}_residue.sh`)의 `real` 초와 시작 · 끝의 `uptime` 을 `before-times.tsv` 에 적는다. 각 파일의 표준 출력은 `before/<이름>.out` 에 둔다.
- [ ] **Step 4: 고치기 전 기준값을 남긴다** — `before/<이름>.out` 마다 마지막 `Total: … | Pass: … | Fail: …` 줄을 `before-totals.tsv` 에. 대상 밖 사용자 다섯(`shared/tests/test_docreview_anchor.sh` · `test_writer_trust_notice.sh` · `test_docreview_golden.sh` · `test_docreview_gate_visibility.sh` · `plugins/spec-distill/tests/test_begin_round_snapshot.sh`)도 한 번씩 돌려 같은 줄을 더한다. `before/test_docreview_mutations.out` 에서 `  ✓ ` · `  ✗ ` 로 시작하는 줄을 그대로 `matrix-before.txt` 에(셀별 판정 · `RED(n) 생존(m)` · `[churn …]` · 양성 대조 일곱 · 계측기 탐침이 든다). 기준값에 실패가 있으면 그 이름을 적는다 — 이 PR 이 만든 실패와 가를 때 쓴다.

---

### Task 2: `r1` 의 템플릿 길과 도우미 케이스

**Files:**
- Modify: `shared/tests/fixtures/docreview/cases.sh:215-218`(`r1`) · `:51-54`(`finish`)
- Modify: `shared/tests/test_docreview_state.sh`(케이스 목록 끝 · source 다음 줄)

**Interfaces:**
- Produces: `r1 <profile> <doc>` — 계약 그대로(1라운드를 연 상태 폴더를 표준 출력에 · `mk_state` 가 실패하면 종료 코드 1). `DOCREVIEW_R1_TEMPLATES` 가 비지 않았을 때만 템플릿 길. `r1_templates_on`(인자 없음, 종료 코드 늘 0). 템플릿 폴더의 꼴 — `<T>/r1-<crc>-<len>/`(원장 폴더 사본)와 `<T>/r1-<crc>-<len>.meta`(K3 의 세 줄).
- 기본 길(변수가 빈 때)의 `r1` 네 줄은 글자 그대로 둔다. 템플릿 길은 그 앞에서 갈라지는 별도 함수(`_r1_templated <profile> <doc>` — `r1` 과 같은 계약)다.

케이스 넷은 아래 차례로 하나씩 쓴다 — 쓰고, 실패를 보고, 그만큼 구현하고, 다음으로(`docs/testing.md` 「쓰는 차례」). 넷 다 `local DOCREVIEW_R1_TEMPLATES` 로 자기 폴더를 쓰고 끝에 자기가 만든 경로를 지운다.

- [ ] **Step 1: `case_r1_template_isolated` 를 쓰고 `test_docreview_state.sh` 목록 끝(`finish` 앞)에 더한다**

```bash
case_r1_template_isolated() {   # r1 템플릿: 두 번째 r1 은 템플릿을 복사하고, 복사본은 서로 · 템플릿과 상태를 나누지 않는다
  local DOCREVIEW_R1_TEMPLATES t a b o
  t="$(mktemp -d -t docreview-r1tpl-XXXXXX)" || { no "r1 템플릿: 폴더를 만들지 못했다"; return; }
  DOCREVIEW_R1_TEMPLATES="$t"
  a="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  b="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(ls "$t" | grep -c '\.meta$')" "1" "r1 템플릿: 같은 프로필 · 문서의 r1 두 번에 템플릿이 하나다"
  next_round "$a" "$FX/design-sample.md" >/dev/null
  printf '\nA_ONLY_q4\n' >> "$a/src/design-sample.md"
  assert_eq "$(st_yaml "$a" 'st["round"]') $(st_yaml "$b" 'st["round"]')" "2 1" "r1 템플릿: A 의 라운드를 넘겨도 B 는 1라운드다"
  assert_eq "$(grep -c A_ONLY_q4 "$b/src/design-sample.md")" "0" "r1 템플릿: A 의 문서 사본에 쓴 것이 B 에 없다"
  assert_eq "$(ledger_doc "$b")" "$b/src/design-sample.md" "r1 템플릿: B 의 원장 문서는 B 안의 사본이다"
  o="$(sed -n 2p "$t"/*.meta 2>/dev/null)"
  assert_eq "$(grep -rlF "$t" "$b" | wc -l | tr -d ' ') $(grep -rlF "${o:-NO_ORIGIN}" "$b" | wc -l | tr -d ' ')" "0 0" \
    "r1 템플릿: B 의 어느 파일에도 템플릿 폴더 · 원본 원장 폴더 경로가 없다"
  rm -rf "$a" "$b" "$t"
}
```

- [ ] **Step 2: 실패를 본다** — `bash shared/tests/test_docreview_state.sh 2>&1 | grep 'r1 템플릿'`. 기대: 첫 단언 ✗(`expected: 1 actual: 0` — 아직 템플릿을 만들지 않는다).
- [ ] **Step 3: 템플릿 길을 구현한다** — `cases.sh` 에 `_r1_templated` 와 그 도우미(키 · 복사)를 `r1` 바로 위에 둔다.
  - 키: K1 의 한 줄 글과 이름. 이 단계에서는 경로 셋과 `$SCRIPTS` 만으로 시작해도 된다(내용은 Step 5).
  - 없음(`.meta` 없음 또는 첫 줄이 키와 다름): 지금 `r1` 과 같은 세 걸음으로 짓고 begin-round 의 종료 코드를 받는다. 0 이면 `<이름>.tmp.$$` 로 `cp -R` 한 뒤 `mv`, 원본 상태 파일의 수정 시각(ns)을 python 한 줄로 재 `.meta` 를 마지막에 쓴다. 지은 폴더를 낸다.
  - 있음: `mktemp -d -t docreview-XXXXXX` 에 `cp -R "<템플릿>/." "<새 폴더>/"` 하고, `$SCRIPTS` 를 `sys.path` 앞에 둔 python 한 번이 `load_state` → `st["doc"]` 가 `<원본 폴더>/` 로 시작하는 글이면 그 앞부분만 새 폴더로 바꾼다(아니면 종료 코드 0 아님) → `save_state(새 폴더, st)`(log_line 없이). 표준 오류는 버린다. 새 폴더를 낸다.
  - 출력은 성공한 끝에서 한 번만 낸다(`d="$(r1 …)"` 로 받는다).
- [ ] **Step 4: 통과를 본다** — 같은 명령. 기대: `r1 템플릿` 다섯 줄 모두 ✓, 그 파일의 나머지 줄은 `before/test_docreview_state.out` 과 같다.
- [ ] **Step 5: `case_r1_template_follows_doc_content` 를 쓰고 목록에 더한 뒤 실패를 본다**

```bash
case_r1_template_follows_doc_content() {   # r1 템플릿: 같은 경로의 문서가 바뀌면 새 내용으로 짓는다
  local DOCREVIEW_R1_TEMPLATES w a b
  w="$(mktemp -d -t docreview-r1tpl-XXXXXX)" || { no "r1 템플릿(내용): 폴더를 만들지 못했다"; return; }
  DOCREVIEW_R1_TEMPLATES="$w/t"; mkdir -p "$w/t"
  cp "$FX/design-sample.md" "$w/doc.md"; a="$(r1 "$PROF_SD/design-doc.md" "$w/doc.md")"
  printf '\n덧붙인 문장 k2.\n' >> "$w/doc.md"; b="$(r1 "$PROF_SD/design-doc.md" "$w/doc.md")"
  cmp -s "$b/src/doc.md" "$w/doc.md" && ok "r1 템플릿(내용): 문서가 바뀐 뒤의 원장은 바뀐 내용을 싣는다" \
    || no "r1 템플릿(내용): 같은 경로의 문서가 바뀌었는데 낡은 템플릿을 받았다"
  assert_eq "$(ls "$w/t" | grep -c '\.meta$')" "2" "r1 템플릿(내용): 내용이 다르면 템플릿도 따로다"
  rm -rf "$a" "$b" "$w"
}
```
  기대(키에 내용이 없을 때): 두 단언 ✗. 그다음 K1 대로 키에 `cksum < 프로필` · `cksum < 문서` 를 넣고 통과를 본다.

- [ ] **Step 6: `case_r1_template_round_start_after_call` 을 쓰고 목록에 더한 뒤 실패를 본다**

```bash
case_r1_template_round_start_after_call() {   # r1 템플릿: 복사본의 라운드 시작은 r1 을 부르기 전에 쓴 파일보다 뒤다
  local DOCREVIEW_R1_TEMPLATES w a b
  w="$(mktemp -d -t docreview-r1tpl-XXXXXX)" || { no "r1 템플릿(시작): 폴더를 만들지 못했다"; return; }
  DOCREVIEW_R1_TEMPLATES="$w/t"; mkdir -p "$w/t"
  a="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; rm -rf "$a"
  : > "$w/before"
  b="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(python3 -c 'import os, sys; print(int(sys.argv[1]) > os.stat(sys.argv[2]).st_mtime_ns)' \
      "$(st_yaml "$b" 'st["rounds"]["1"]["started_mtime_ns"]')" "$w/before")" "True" \
    "r1 템플릿(시작): 복사본의 라운드 시작 표식이 r1 을 부르기 전에 쓴 파일보다 뒤다(새로 지은 원장과 같다)"
  rm -rf "$b" "$w"
}
```
  기대(옮기기 전): ✗(`actual: False`). 그다음 K2 대로 다시 적기 python 에서 표식을 옮기고(원본 수정 시각은 `.meta` 3행) 통과를 본다.

- [ ] **Step 7: `case_r1_template_unusable_falls_back` 을 쓰고 목록에 더한 뒤 실패를 본다**

```bash
case_r1_template_unusable_falls_back() {   # r1 템플릿: 템플릿 폴더를 쓸 수 없으면 새로 짓고 한 줄 알린다
  local DOCREVIEW_R1_TEMPLATES w b
  w="$(mktemp -d -t docreview-r1tpl-XXXXXX)" || { no "r1 템플릿(대체): 폴더를 만들지 못했다"; return; }
  : > "$w/not-a-dir"; DOCREVIEW_R1_TEMPLATES="$w/not-a-dir"
  b="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" 2>"$w/err")"
  assert_eq "$(st_yaml "$b" 'st["round"]' 2>/dev/null)" "1" "r1 템플릿(대체): 템플릿을 못 써도 1라운드 원장을 낸다"
  assert_eq "$(grep -c '^\[cases\.sh\] r1 템플릿을 쓰지 못했다 — ' "$w/err")" "1" "r1 템플릿(대체): 알림이 정확히 한 줄이다"
  rm -rf "$b" "$w"
}
```
  기대(알림 전): 둘째 단언 ✗. 그다음 K5 의 알림을 템플릿 저장 · 복사 · 다시 적기의 실패마다 넣고(복사 · 다시 적기가 실패하면 만든 새 폴더를 지우고 새로 짓는다) 통과를 본다.

- [ ] **Step 8: 켜는 길을 넣는다** — `r1_templates_on` 을 `cases.sh` 에(K4), `finish` 에 「이 셸이 만든 템플릿 폴더면 지운다」 를 `carry_fold` 와 같은 조건(`$BASH_SUBSHELL -eq $_CASES_SUB0`) 안에 더한다. `test_docreview_state.sh` 의 `. "$HERE/fixtures/docreview/cases.sh"` 다음 줄에 `r1_templates_on`.
- [ ] **Step 9: 돌린다** — `bash shared/tests/test_docreview_state.sh` 와 `/bin/bash shared/tests/test_docreview_state.sh`. 기대: Fail 0, Total 은 기준값 + 새 케이스 넷의 단언 수. `r1 템플릿` 으로 시작하지 않는 줄은 `before/test_docreview_state.out` 과 같다. `grep -c 'docreview_state\.py"\{0,1\} begin-round' shared/tests/fixtures/docreview/cases.sh` ≥ 79.
- [ ] **Step 10: 커밋**

```bash
git add shared/tests/fixtures/docreview/cases.sh shared/tests/test_docreview_state.sh
git commit -m "test(docreview): r1 이 첫 라운드 원장을 한 번 지어 복사해 쓰게 한다" -m "Spec: docs/superpowers/specs/2026-11-26-test-prune-design.md"
```
  (커밋 메시지 끝에 `Co-Authored-By` 줄을 단다 — 이하 모든 커밋 같다.)

---

### Task 3: 나머지 다섯 파일 켜기와 대상 밖 사용자

**Files:**
- Modify: `shared/tests/test_docreview_{route,advice,ask,gate_plain,intent}.sh`(각 파일의 `cases.sh` source 다음 줄)

**Interfaces:**
- Consumes: Task 2 의 `r1_templates_on`.

- [ ] **Step 1: 다섯 파일에 `r1_templates_on` 한 줄을 넣는다** — `cases.sh` 를 source 한 바로 다음 줄(`cases_advice.sh` · `cases_ask.sh` 를 함께 source 하는 파일은 그 뒤).
- [ ] **Step 2: 다섯 파일을 돌려 기준값과 견준다** — 각각 Total/Pass 가 `before-totals.tsv` 와 같고 ✓ · ✗ 줄이 `before/<이름>.out` 과 같다. 다르면 고치기 전에 그 줄을 보고에 적고 원인을 찾는다(템플릿을 끈 실행과 견준다).
- [ ] **Step 3: 대상 밖 사용자를 돈다** — `test_docreview_anchor.sh` · `test_writer_trust_notice.sh` · `test_docreview_gate_visibility.sh` · `test_docreview_golden.sh` · `plugins/spec-distill/tests/test_begin_round_snapshot.sh` 가 켜지 않은 채 기준값과 같다. 그다음 골든을 템플릿을 켠 채 한 번 — `T="$(mktemp -d -t docreview-r1tpl-XXXXXX)"; DOCREVIEW_R1_TEMPLATES="$T" bash shared/tests/test_docreview_golden.sh` → 기준값과 같은 Total/Pass(바이트 등가). 그 뒤 `ls "$T" | grep -c '\.meta$'` ≥ 1 을 적고(템플릿 길을 실제로 탔다) `rm -rf "$T"`.
- [ ] **Step 4: ① 의 증거와 정리를 본다** — 여섯 파일(Task 2 의 `state` 포함)을 바깥에서 만든 폴더로 켜고 돌린다: `T="$(mktemp -d -t docreview-r1tpl-XXXXXX)"; DOCREVIEW_R1_TEMPLATES="$T" bash <파일> 2>"$T.err"`. 파일마다 `.meta` 수(= 새로 지은 r1 수)와 `grep -c '^\[cases\.sh\] r1 템플릿을 쓰지 못했다' "$T.err"`(기대 0)을 보고에 적는다. 바깥 폴더는 그대로 남는다(지우지 않는다 — Review Focus 5). 이어 `ls -d "$TMPDIR"/docreview-r1tpl-* 2>/dev/null | wc -l` 을 켜지 않은 실행(`bash <파일>`) 앞뒤로 재 늘지 않음을 본다. 자기가 만든 `$T` · `$T.err` 를 지운다.
- [ ] **Step 5: 커밋**

```bash
git add shared/tests/test_docreview_route.sh shared/tests/test_docreview_advice.sh shared/tests/test_docreview_ask.sh shared/tests/test_docreview_gate_plain.sh shared/tests/test_docreview_intent.sh
git commit -m "test(docreview): 원장 도우미를 쓰는 다섯 파일이 r1 템플릿을 켠다" -m "Spec: docs/superpowers/specs/2026-11-26-test-prune-design.md"
```

---

### Task 4: 변이 행렬 — 프로필 사본 한 번과 템플릿

**Files:**
- Modify: `shared/tests/test_docreview_mutations.sh:47-50`(`BASE_MUT` 를 만든 다음)

**Interfaces:**
- Consumes: Task 2 의 `DOCREVIEW_R1_TEMPLATES` 계약. `cases.sh:7` 의 `PROF_SD="${DOCREVIEW_PROF_SD:-…}"`.

- [ ] **Step 1: 부모에서 두 변수를 export 한다** — `DOCREVIEW_PROF_SD="$(bash "$HERE/fixtures/docreview/nofield_profiles.sh")"` 를 한 번 재고, 비었거나 폴더가 아니면 `no` 한 줄을 내고 `exit 1`(지금은 `run_case` 마다 그 자리에서 죽는다 — 같은 실패를 한 번에 낸다). `DOCREVIEW_R1_TEMPLATES="$BASE_MUT/r1-templates"` 를 만들고 export 한다. 셀 정의 · `run_case` · `clean_result` · `classify_result` 는 바꾸지 않는다.
- [ ] **Step 2: 돌려 셀별로 견준다** — `bash shared/tests/test_docreview_mutations.sh > $TMPDIR/e4-pr3/after/test_docreview_mutations.out`, 그 `  ✓ ` · `  ✗ ` 줄을 `matrix-after.txt` 로 뽑아 `diff matrix-before.txt matrix-after.txt`. 기대: 차이 0줄 — 셀 119개의 판정 · `RED(n)` · `생존(m)` · churn, 양성 대조 일곱, 계측기 탐침, 카나리아가 모두 같다. Total/Pass 도 기준값과 같다. 차이가 있으면 K7 의 차례로 간다.
- [ ] **Step 3: 보안 셀을 따로 적는다** — 표의 보안 범위(`:265–274` · `:430–434` · `:775–790` · `:864–866`)에 든 셀 이름마다 앞 · 뒤 줄을 보고에 나란히 싣는다(AC7 — 고친 것은 셀의 준비물이고 셀은 그대로다). 양성 대조 일곱 줄도 싣는다.
- [ ] **Step 4: 커밋**

```bash
git add shared/tests/test_docreview_mutations.sh
git commit -m "test(docreview): 변이 행렬이 프로필 사본을 한 번 만들고 r1 템플릿을 나눠 쓴다" -m "Spec: docs/superpowers/specs/2026-11-26-test-prune-design.md"
```

---

### Task 5: brief 잔존물 — sid 전제 묶기

**Files:**
- Modify: `plugins/spec-distill/tests/test_reviewing_brief_residue.sh:167-174`(전제 반복과 판정 두 줄)

**Interfaces:**
- Consumes: 그 파일 안의 `$PR/scripts`(사본 `state_path.py` · `docreview_state.py`) · `$SCRATCH` · `$DOC_B` · `where`.
- `SIDS` 목록 글자는 바꾸지 않는다.

- [ ] **Step 1: 짝 확인을 먼저 쓴다** — 지금 반복 바로 뒤에 K8 의 짝을 더한다. 이 단계의 기대값은 지금의 명령줄 결과가 아니라 손으로 적은 꼴이다: `state_path.py session-id` 의 출력은 sid 그 자체이고, 자리는 `$SCRATCH/<sid>/.claude/spec-distill/.docreview/brief-sample-<16자>` 꼴이다(`assert_grep` 로 그 꼴을 문다). 돌려 통과를 본 뒤, 사본에서 M1 을 넣어 이 짝이 실패하는 것을 본다.
- [ ] **Step 2: 반복을 묶은 python 한 번으로 바꾼다** — K8 대로. python 은 `$PR/scripts` 를 `sys.path` 앞에 두고 `state_path.resolve_session_id(None)` 와 `docreview_state.state_dir_for(<$SCRATCH/sid/.claude/spec-distill>, $DOC_B)` 를 sid 마다 부른다. 표준 오류는 버린다(거부된 sid 마다 엔진이 한 줄씩 낸다). 판정: `BAD` 줄 0 이고 `DIR` 줄 수 = sid 수면 지금의 `ok` 글, 아니면 지금의 `no` 글에 빠진 sid 를 싣는다(python 이 죽어 출력이 비면 모든 sid 가 빠진 것으로 센다). 짝은 묶은 출력의 첫 sid `DIR` 과 명령줄 결과를 글자까지 견준다(Step 1 의 꼴 단언은 둔다).
- [ ] **Step 3: 돌린다** — `bash plugins/spec-distill/tests/test_reviewing_brief_residue.sh`. 기대: Fail 0, Total = 기준값 + 짝의 단언 수, 나머지 ✓ 줄이 `before/` 와 같다.
- [ ] **Step 4: 커밋**

```bash
git add plugins/spec-distill/tests/test_reviewing_brief_residue.sh
git commit -m "test(spec-distill): brief 잔존물 테스트의 sid 전제 확인을 python 한 번으로 묶는다" -m "Spec: docs/superpowers/specs/2026-11-26-test-prune-design.md"
```
- [ ] **Step 5: 변이 넷과 양성 대조** — 커밋 뒤 `git clone -q --no-local <이 worktree> $TMPDIR/e4-pr3/mut-brief-<n>` 사본 다섯(M1–M4 · 양성)에서 K9 의 변이를 하나씩 넣고(사본의 `git diff --stat` 줄 수를 적는다 — 0 이면 앵커를 못 찾은 것이라 증거가 아니다) `PYTHONDONTWRITEBYTECODE=1 bash <사본>/plugins/spec-distill/tests/test_reviewing_brief_residue.sh` 를 돌려 `전제` 가 든 줄을 모은다. 기대: M2 · M3 은 전제 ✗, M1 · M4 는 짝 ✗(전제는 ✓ — 묶은 쪽이 볼 수 없는 경계다), 양성은 전제 · 짝 ✓ 이고 Total/Pass 가 Step 3 과 같다. 표(변이 · 바꾼 줄 · diff 줄 수 · 전제 · 짝 · Total/Pass)를 보고에 싣는다. 사본을 지운다.

---

### Task 6: spec 잔존물 — sid 전제 묶기

**Files:**
- Modify: `plugins/spec-distill/tests/test_reviewing_spec_residue.sh:152-163`

**Interfaces:**
- Consumes: 그 파일의 `$PR/scripts` · `$SCRATCH` · `$SPEC_DOC` · `dir_of`. Task 5 와 같은 꼴(두 하니스는 합치지 않는다 — 표).

- [ ] **Step 1: 짝을 먼저 쓴다** — Task 5 Step 1 과 같은 꼴(자리 꼴은 `…/.docreview/<SPEC_DOC 의 stem>-<16자>`). 통과를 보고, 사본에서 M1 로 실패를 본다.
- [ ] **Step 2: 반복을 묶는다** — Task 5 Step 2 와 같은 판정 · 같은 글(이 파일의 지금 `ok` · `no` 글 그대로). 묶은 python 은 20줄 밑으로 두고 Task 5 와 블록이 글자까지 같아지지 않게 이 파일의 이름(`dir_of` · `$SPEC_DOC` · `bad_sid`)을 쓴다.
- [ ] **Step 3: 돌린다** — 기대: Fail 0, Total = 기준값 + 짝의 단언 수.
- [ ] **Step 4: 커밋**

```bash
git add plugins/spec-distill/tests/test_reviewing_spec_residue.sh
git commit -m "test(spec-distill): spec 잔존물 테스트의 sid 전제 확인을 python 한 번으로 묶는다" -m "Spec: docs/superpowers/specs/2026-11-26-test-prune-design.md"
```
- [ ] **Step 5: 잡는지 본다** — Task 5 Step 5 의 꼴로 사본 셋: M2(`rs99sht`) → 전제 ✗, M1 → 짝 ✗, 양성 → 둘 다 ✓ · Total/Pass 같음. 보고에 싣는다.

---

### Task 7: 이력 주석 — `cases.sh`

**Files:**
- Modify: `shared/tests/fixtures/docreview/cases.sh`(주석만)

- [ ] **Step 1: 덜기 전 커밋을 적는다** — `B7=$(git rev-parse HEAD)`.
- [ ] **Step 2: 이 파일의 글을 읽는 락을 찾는다** — `git grep -l -F 'fixtures/docreview/cases.sh' -- 'plugins/*/tests' 'shared/tests'` 와 `git grep -l -F 'cases.sh' -- 'plugins/*/tests' 'shared/tests'` 에서 그 파일을 실행만 하지 않고 글자로 읽는 테스트(예: `test_begin_round_snapshot.sh` 의 begin-round 줄 수 · `test_writer_trust_notice.sh` 의 옛 꼴 셈)를 목록으로 적는다. 덜 주석이 그 락이 세는 글을 담고 있으면 그 주석은 덜지 않는다.
- [ ] **Step 3: 덜어 낸다(AC11)** — 설계 §7 대로: 언제 · 어느 과제 · 어느 리뷰 · 누가 고쳤는지(예: `[Task 8b 재앵커]` · `R19 이전엔` · `fix round` · `리뷰어가 잡은` · `실측` 꼬리표 · 옛 판의 줄 인용)는 지운다. 확인이 무엇을 지키는지 · 왜 그 꼴인지 말하는 문장은 남긴다. 실제 우회 기록처럼 판정의 근거인 주석은 지키는 것 한 문장으로 줄여 남긴다. `# guards:` 줄과 줄 끝 주석이 붙은 코드 줄의 코드 쪽은 건드리지 않는다. here-doc · 따옴표 안의 `#` 줄은 주석이 아니다.
- [ ] **Step 4: 주석만 바뀌었는지 본다** — K12. 아래 함수를 `$TMPDIR/e4-pr3/norm.sh` 에 두고, `git show "$B7":shared/tests/fixtures/docreview/cases.sh > $TMPDIR/e4-pr3/a.sh` 와 지금 파일에 각각 돌려 `cmp` 한다 → 같다(몸통 끝 줄이 주석이어도 `}` 가 다음 줄에 오도록 줄바꿈을 둔다). `bash -n` 통과. begin-round 줄 수 ≥ 79.

```bash
norm() { bash -c 'body="$(cat "$1")"; eval "__w() {
$body
}" && declare -f __w' _ "$1"; }
```
- [ ] **Step 5: 돌린다** — 이 파일을 쓰는 열한 파일(`shared/tests/test_docreview_{state,route,advice,ask,gate_plain,intent,anchor,gate_visibility,golden,mutations}.sh` · `test_writer_trust_notice.sh`)과 `test_begin_round_snapshot.sh` 를 돌린다. 기대: 모두 Task 2–4 뒤의 값과 같은 Total/Pass, 변이 행렬은 `matrix-after.txt` 와 같다.
- [ ] **Step 6: 커밋**

```bash
git add shared/tests/fixtures/docreview/cases.sh
git commit -m "test(docreview): 원장 케이스 모음에서 이력 주석을 덜어 낸다" -m "Spec: docs/superpowers/specs/2026-11-26-test-prune-design.md"
```

---

### Task 8: 이력 주석 — 나머지 아홉 파일

**Files:**
- Modify: `shared/tests/test_docreview_{mutations,state,route,advice,ask,gate_plain,intent}.sh` · `plugins/spec-distill/tests/test_reviewing_{brief,spec}_residue.sh`(주석만)

- [ ] **Step 1: 덜기 전 커밋을 적고 글을 읽는 락을 찾는다** — `B8=$(git rev-parse HEAD)`. Task 7 Step 2 와 같은 꼴로 아홉 파일 이름마다.
- [ ] **Step 2: 덜어 낸다(AC11)** — Task 7 Step 3 의 규칙. `test_docreview_mutations.sh` 는 셀마다 붙은 재앵커 · 정정 이력이 길다 — 셀이 겨누는 규칙과 그 sed 가 왜 그 꼴인지(예: 엄격 인덱싱은 이빨을 숨긴다 · 순수 삽입의 churn 은 실제 diff 로 센다 · 들여쓰기가 유일한 변별기다)는 한 문장씩 남긴다. sed 프로그램 · `mut` 줄 · churn 값은 글자 그대로다.
- [ ] **Step 3: 주석만 바뀌었는지 본다** — 아홉 파일마다 Task 7 Step 4 의 비교(`$B8` 대 지금) → 같다. `bash -n` 통과.
- [ ] **Step 4: 돌린다** — 아홉 파일. 기대: Task 2–6 뒤의 Total/Pass 와 같고 변이 행렬은 `matrix-after.txt` 와 같다.
- [ ] **Step 5: 커밋**

```bash
git add shared/tests/test_docreview_mutations.sh shared/tests/test_docreview_state.sh shared/tests/test_docreview_route.sh shared/tests/test_docreview_advice.sh shared/tests/test_docreview_ask.sh shared/tests/test_docreview_gate_plain.sh shared/tests/test_docreview_intent.sh plugins/spec-distill/tests/test_reviewing_brief_residue.sh plugins/spec-distill/tests/test_reviewing_spec_residue.sh
git commit -m "test: 원장 도우미 테스트 아홉에서 이력 주석을 덜어 낸다" -m "Spec: docs/superpowers/specs/2026-11-26-test-prune-design.md"
```

---

### Task 9: 뒤 시간 · 교차 참조 · 전체 스위트

**Files:** 없음(`$TMPDIR/e4-pr3/`)

- [ ] **Step 1: 고친 뒤 시간을 잰다** — Task 1 Step 3 과 같은 명령으로 `after-times.tsv`. 파일마다 앞 · 뒤 초와 차이를 표로. 뒤가 앞보다 작지 않은 파일은 까닭(부하 · 재는 흔들림 · 그 파일의 r1 수)을 적는다 — AC5 는 그 파일에 사용자 승인을 요구하므로 보고에 「승인 필요」 로 표시한다.
- [ ] **Step 2: §5 점검을 기대는 꼴마다 한다** — 결과를 여덟 줄로 보고에 싣는다.
  1. 지움을 막는 문서: `git diff --name-status --diff-filter=DR origin/main...HEAD` 가 비었다 — 지우거나 옮긴 파일이 없어 해당 없음(AC9).
  2. 다른 테스트가 실행 · 목록 요구: 고친 파일 열 개의 이름마다 `git grep -l -F <이름> -- 'plugins/*/tests' 'shared/tests'` 로 모은 테스트를 돈다.
  3. python import: 고친 `.py` 가 없어 해당 없음.
  4. 테스트를 시험하는 테스트: 2 의 목록 가운데 고친 파일을 겨누는 것.
  5. `# guards:` 선언: `bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh`.
  6. 이빨이 기대는 쪽: 2 의 목록에서 머리 주석이 고친 파일의 통과에 기댄다고 적은 것을 읽어 함께 돈다.
  7. 실패 원장: `git grep -n -F -e test_docreview_ -e test_reviewing_ -e cases.sh -- '*codex-blessed-red.txt'` 가 비었다.
  8. 부재 락의 코퍼스: `test_begin_round_snapshot.sh`(cases.sh 를 코퍼스로 쥔다) · `test_writer_trust_notice.sh` 통과.
- [ ] **Step 3: 테스트 다섯과 레포 락을 돈다** — `plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh` · `shared/tests/test_charter_citations.sh` · `plugins/spec-distill/tests/test_epic_conductor_skill.sh` · `plugins/spec-distill/tests/test_begin_round_snapshot.sh` · `shared/tests/test_presence_corpus_behavior.sh`(AC10), 그리고 `shared/tests/test_no_new_duplication.sh` · `shared/tests/test_shell_tests_executable.sh`. 실패가 있으면 Task 1 HEAD 의 사본에서도 같은지 견주어 「이 브랜치가 만든 실패」 와 「원래 있던 실패」 로 가른다.
- [ ] **Step 4: 바뀌지 않아야 할 것을 본다** — `git diff --name-only origin/main...HEAD -- 'plugins/*/.claude-plugin/plugin.json'` 비었다(AC12). `git diff --name-only origin/main...HEAD -- plugins/spec-distill/tests/test_stage_prose_trim.sh` 비었다(AC14). `git diff --name-only origin/main...HEAD` 가 이 계획의 파일 표 열 개와 설계문서 · 이 계획 파일뿐이다. `git ls-files -s` 로 고친 셸 테스트의 모드가 기준과 같다(100755). 사라진 확인이 없음을 적는다 — 있으면 `docs/removed-tests.md` 머리의 줄 꼴로 한 줄씩 더하고 AC8 을 몫에 더한다.
- [ ] **Step 5: 전체 스위트를 공유 잠금 아래 돈다** — 지휘자가 준 `suite_lock.py run … -- bash -c 'bash tools/suite/run-all.sh'` 로. 실패마다 기본 브랜치에도 있는지 가른 표를 보고에 싣는다(AC13). 이 브랜치만의 새 실패가 있으면 고친다.

---

### Task 10: 구현 보고와 PR 본문 초안

**Files:** 없음(`$TMPDIR/e4-pr3/impl-report.md` · `$TMPDIR/e4-pr3/pr-body.md`)

- [ ] **Step 1: 구현 보고를 쓴다** — 과제 1 의 다시 확인 결과 · 기준값 · 앞뒤 초 표 · Task 3 Step 4 의 파일별 `.meta` 수와 알림 0 · 골든을 켠 채의 결과 · 변이 행렬 셀별 대조(보안 셀과 양성 대조 따로) · Task 5 · 6 의 변이 표 · §5 여덟 줄 · 테스트 다섯 · 전체 스위트 표 · 이 계획의 판단 가운데 ✎ 줄이 실제로 어떻게 들어갔는지 · 구현 중 찾은 새 후보(고치지 않았다).
- [ ] **Step 2: PR 본문을 쓴다** — 한국어, 첫 줄에 상태, 끝에 할 일. 담을 것:
  - 승인받은 판정 표를 그대로(`table-pr3-final.md` 의 표와 아래 「확인」 · 「합계」 · 「§5 · §8」 줄)와 승인 줄 「판정 표 승인 · 2026-11-27 · PR 3(문서 리뷰 원장 도우미) 「승인 (권장)」」(AC1).
  - 표를 읽은 담당자 A 와 다시 읽은 담당자 B — 서로 다른 하위 agent 실행 — 와 갈린 행(`test_docreview_gate_plain.sh :56–88` 합침: A 합침 / B 둠 → 지휘자가 둠으로)(AC2).
  - 고친 파일마다 고치기 전 · 뒤 초(잰 조건 · 부하 · 겹침 여부), 뒤가 작지 않은 파일의 까닭(AC5).
  - 값 읽기 묶기(④)는 사용자가 하지 않기로 했다는 것 · `route_r1` 결과 캐시를 하지 않았다는 것.
  - 보안 확인: 변이 행렬 셀별 대조 결과 요약과 Task 5 · 6 의 변이 표(AC7). 지운 확인 없음(AC8 해당 없음).
  - §5 점검 결과와 테스트 다섯(AC10). 판 올림 없음(AC12).
  - 계획의 판단 가운데 사람에게 보이는 것 — K1 · K2 · K4 · K6.
- [ ] **Step 3: 보고에 싣는다** — 두 파일의 경로와, 지휘자에게: 뒤 초가 앞보다 작지 않은 파일이 있으면 그 목록(사용자 승인이 필요하다).

---

## 실행 방식의 마지막 전체 리뷰

고른 실행 방식의 마지막 전체 리뷰(subagent-driven 의 브랜치 전체 리뷰 · native 의 마지막 리뷰)의 리뷰어에게 아래를 그대로 싣는다.

- 설계문서 `## Acceptance Criteria` 의 AC 목록 원문, 승인 판정 표(`table-pr3-final.md`) 원문, 이 계획의 `## AC 가르기` · `## 계획의 판단` 표.
- 요청: 이 계획 몫 AC(`AC1,AC2,AC5,AC7,AC9,AC10,AC11,AC12,AC13,AC14`)마다 한 줄씩 `AC<n>: <구현됨|미룸|빠짐> — <근거(파일:줄 · 테스트 이름 · 명령 결과)>` 꼴로 보고하라. AC1 · AC2 는 PR 본문 초안(`pr-body.md`)으로 본다. 사라진 확인이 있었으면 AC8 도 같은 꼴로.
- 요청: 설계문서 `## 있는 것 검토` 가 고른 것을 실제로 썼는지, 같은 것을 다시 만들지 않았는지 답하라 — 원장 도우미 `cases.sh` 위에 「한 번 지어 복사」 를 얹었는가(새 도우미 파일을 만들지 않았는가) · `docs/testing.md` 의 차례 · 보안 갈래 · 망가뜨려 보기를 따랐는가 · `test_guards_coverage_bidirectional.sh` · `test_charter_citations.sh` 를 점검에 썼는가 · 시간 재기에 있는 잠금과 `tools/suite/` 를 썼는가 · 평가 케이스 장치를 쓰지 않았는가 · 원장을 다시 적을 때 엔진의 `load_state` / `save_state` 를 썼는가(손 고침 없음).
- 끝에서 끝 흐름 둘을 따로 물어라 — 이음매마다 종료 코드 소비와 상태 가정: ① 테스트 파일 → `cases.sh` source → `r1_templates_on` → 케이스의 `r1`(없음: 짓기 → begin-round 종료 코드 → 템플릿 저장 → `.meta` / 있음: 복사 → 다시 적기 → 실패면 지우고 새로 짓기) → 케이스 끝의 `rm -rf` → `finish` 의 정리 ② 변이 행렬의 부모 export → `run_case` 서브셸의 source(`PROF_SD` 가드 · `exit`) → 변이 사본마다 다른 키 → traceback 검출이 다시 적기의 표준 오류를 보지 않는가.
- 이 계획이 쓴 테스트 코드(Task 2 의 케이스 넷 · Task 5 · 6 의 짝)와 계획이 정한 판정(K1 · K2 · K3 · K7 · K8 · K9)은 계획이 정한 것이라는 표시를 붙여, 덜 보지 말고 같은 눈으로 보라고 적는다. 고친 기존 확인에서 단언이 지워지거나 느슨해지지 않았는지 `git diff <Task 1 HEAD> -- shared/tests plugins/spec-distill/tests` 로 보라고 적는다 — 이력 주석 덜기(Task 7 · 8)는 주석만이어야 한다.

리뷰 보고는 git 이 추적하지 않는 파일에 적는다 — 지휘자가 준 TMPDIR 의 `e4-pr3/ac-report.md`(쓸 수 없으면 이 worktree 의 `.claude/tmp/<담당자 이름>/e4-pr3-ac-report.md` — `git check-ignore -q` 로 확인). 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린다 — 올릴 행을 보고에 적고 지휘자가 올린다. PR 을 만들기 전에

`python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/9.3.0/scripts/check_bundle_coverage.py --impl <이 worktree>/docs/superpowers/specs/2026-11-26-test-prune-design.md <보고 파일 경로> --acs "AC1,AC2,AC5,AC7,AC9,AC10,AC11,AC12,AC13,AC14"`

를 돌려 경고를 사용자에게 보인다.
