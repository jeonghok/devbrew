# E4 설계 — 「뒤집히는 테스트」 목록에서 빠진 락 조사 (2026-11-27 · Explore · sonnet · 읽기 전용)

## 요약

목록(Verification Plan 418행~)에서 빠진 락을 더 찾았다. 아래 표의 단언은 모두 줄을 직접 읽었다. 이미 보고된 test_conductor_dispatch_reference.sh:142 와 test_team_review_entry.sh:31,33 은 뺐다. 경로의 `tests/` 는 `plugins/spec-distill/tests/` 다.

확신은 두 가지로 적었다.
- 확실: 설계대로 고치면 반드시 붉어진다.
- 아마: 구현 방식에 따라 갈린다. 달린 것을 적었다.

## 빠진 락

| 테스트 파일:줄 | 못 박은 것 (단언 원문) | 바꾸는 조각 · 설계문서 줄 | 확신 | 아마면 달린 것 |
|---|---|---|---|---|
| tests/test_team_write.sh:825, 848, 850, 930, 976, 1003 (헬퍼 823 `jobnew`, 943 `sqjob`) | `assert_eq "$(jobnew --name fix-typo --branch fix/typo --paths … )" "0" "AC7: job new rc 0"`. 레포는 main 에 서 있는데 `--branch` 는 `fix/typo`, `fix/no-not`, `fix/sq` 등 다른 이름이다. | b15 · §1.3 118행 (`job new` 는 지금 브랜치가 `--branch` 와 다르면 거절) | 확실 | |
| tests/test_team_write.sh:865-912 (`jfail`/`jin`, 모두 `--branch fix/x`) | 거절 행마다 rc 와 사유 문구를 단언한다 (예: 865 `"역할 이름"`). | b15 · 118행 | 아마 | 브랜치 불일치 검사가 이름 검사보다 앞서면 사유 문구가 달라진다. 뒤에 서면 그대로다. |
| tests/test_team_tasks.sh:58, 62, 66, 116 (`newjob` 의 3번째 인자) | `newjob wrong fix/wrong-name fix/absent`, `newjob stray fix/stray fix/typo`, `newjob moved fix/moved-a fix/moved-b`, `newjob hb fix/hb-a fix/hb-b`. 일부러 머리 `branch` 를 실제 브랜치와 다르게 만든다. `|| failed` 로 이어진다. | b15 · 118행 | 확실 | |
| tests/test_team_tasks.sh:311 | detached HEAD(`checkout "$(g rev-parse fix/broken~1)"`)에서 `job new … --branch fix/shal` | b15 · 118행 | 확실 | |
| tests/test_team_review_entry.sh:141-142 | main 에서 `job new … --branch fix/entry` 한 뒤 `ok "픽스처: 단순 작업 과제 fix-entry"`. 이 파일 뒤쪽 행이 모두 이 픽스처에 기댄다. | b15 · 118행 | 확실 | |
| tests/test_team_write.sh:1448 | `assert_eq "$(rzjob e7x)" "0" "job new --name e7x: rc 0(에픽 번호 꼴이 아니다)"` | b1 1f · §1.3 117행 | 아마 | 끝 소문자까지 대소문자 없이 보는 IGNORECASE 면 `e7x` 도 거절돼 붉어진다. 조사 제안 `fullmatch(name.upper())` 꼴이면 `E7a`(1446)가 먼저 깨진다. |
| tests/test_team_write.sh:186-187 | `marker_heads` 결과가 `'<!-- 출처: docs/iv/t-brief-interview.md · 사용자 원문 -->'` 와 `'…audit.md · 사용자 원문 -->'` 로 끝나는 줄과 같다. | b18 · §1.1 94행 (결과물 구간 출처 줄에 짝 표지 추가) | 확실 | |
| tests/test_team_write.sh:1305, 1324, 1330, 1372 | `marker_heads … sed -n 4,5p` 등이 brief·audit 구간 출처 줄의 정확한 문자열과 같다. 대상은 framing 짝이 붙은 pb, pc, pd, qc3 의 brief 구간이다. | b18 · 94행 | 아마 | 같은 원인이다. 표지를 `--framing-audit` 로 만든 사본에도 쓰는지, audit 구간에도 붙는지에 달렸다. |
| tests/test_team_write.sh:203 | `assert_eq "$(tail -n 3 "$O" \| head -n 1 \| sed 's/@[0-9a-f]*//')" "<!-- 출처: …audit.md · 사용자 원문 · 9–10행 · 2줄 -->"` | b18 · 94행 | 아마 | 표지가 audit 구간 줄 끝에도 붙는지. |
| tests/test_team_write.sh:338 | `assert_eq "$(tree_of "$W/${RD}t1")" "./RULES.md\n./intent/original.md\n./jobs/E1/INTENT.md\n…\n./roadmap.md"`. 팀 폴더 파일 목록을 통째로 대조한다. | b4 · §1.1 95행 (team 생성이 팀 폴더에 `.gitattributes` 를 깐다) | 아마 | 첫 과제가 넓은 범위를 고르면 붉어진다. 앞쪽 필터 대조만 하기로 좁히면 그대로다. |
| tests/test_team_write.sh:1586, 1606, 1611, 1624, 1667 | `"출처가 로드맵 source_brief(docs/iv/t-brief-interview.md) · 그 audit · framing audit 가운데 하나가 아니다"` 를 contains 로 문다. | b20 · §1.1 93행 (출처 어긋남 거절 문구가 「결과물은 옮기지 않는다」 를 말한다) | 아마 | 문구를 뒤에 덧붙이면 그대로다. 다시 쓰면 붉어진다. |
| tests/test_team_write.sh:1040-1042, 1073-1076 | 기준에 파일이 없을 때 `"에도 그 파일이 없다"`, 기준 자리가 폴더일 때 `"의 그 파일도 읽지 못했다"` 로 rc 3. 두 픽스처 모두 기준 이력에 같은 판이 있다. | b3 · §1.1 92행 | 아마 | 목록은 「같은 줄과도 다르다」 행만 적었다. 이력 거슬러 찾기를 「파일 없음 · 읽지 못함」 갈래에도 걸면 붉어진다. |
| tests/test_team_sync.sh:109 | `assert_contains "$(cat "$T/out.txt")" "바뀐 것 없음" "머리 인자: 끝 줄이 있는 파일은 바뀐 것 없음"`. 대상은 108 의 `sync … --bundle-at "$J0" --job-at "$J0"`. | b11 · §3.2 171행 (끝난 파일에 머리 인자를 주면 「바뀐 것 없음」 대신 알림) | 확실 | 목록에는 102·104 행(role)만 있다. 60·75 행은 머리 인자 없이 끝만 줘서 그대로다. |
| tests/test_start_bundle.sh:156-157 | `assert_eq "$(line 7)" "역할 문서 (${B}):"`, `sed -n '8,$p' … head -n <역할 문서 줄 수>` 가 역할 문서 글과 같다. 위치로 센다. | c7a·c7b · §3.3 176행 (`쓸 것` 아래 두 줄) | 확실 | |
| tests/test_start_bundle.sh:155, 166 | `assert_eq "$(line 6)" "맞추는 명령: python3 …/roadmap_write.py job sync …"`, `line 6` contains `--role writer` | c7a·c7b · 176행 | 아마 | 두 줄이 `쓸 것` 바로 아래(맞추는 명령 앞)면 붉어진다. 맞추는 명령 뒤에 두면 그대로다. |
| tests/test_start_bundle.sh:207 | `assert_eq "$(grep -c '^맞추는 명령: ' "$T/job.txt")" "0" "과제: review 에는 맞추는 명령이 없다"` | c2d · §3.3 177행 (검수 묶음도 쓸 것과 맞추는 명령을 낸다) | 확실 | 목록은 `쓸 것` 단언(206)만 적었다. 207 은 같은 절의 짝이다. |
| tests/test_team_review_entry.sh:43 | `assert_contains "$(tail -n 3 "$T/out.txt" \| head -n 1)" "[spec-distill] team 형식 — 리뷰어가 번호 항목" "빠진 번호: … 경고 수 바로 앞 줄은 알림이다"` | c2e · §4 192행 (알림을 걷는다) | 확실 | 보고된 31·33 행과 다른 단언이다. |
| tests/test_team_review_entry.sh:147 | `assert_eq "$(grep -c 'team 형식 — 리뷰어가 번호 항목' "$T/out.txt")" "1" "단순 작업: 알림 한 줄"` | c2e · 192행 | 확실 | |
| tests/test_team_review_entry.sh:29, 40, 66, 150 | `tail -n 1` 이 `bundle-entry: PROCEED $W/$I` 와 같다. 30·39·64·148 행은 `tail -n 2 \| head -n 1` 이 `번호 대조 경고 N개` 와 같다. | c2e · 192행 | 아마 | 진입이 과제 파일 · 번호 파일 · 원자료를 리뷰어에게 싣는 방식에 달렸다. PROCEED 줄의 꼴이나 맨 끝 줄을 바꾸면 붉어진다. |
| tests/test_team_docs.py:227 | `self.assertIn("merge 커밋 안에서 손으로 고친 것은 보지 못한다", s10)`. 형식 정본 §10 의 한계 문장이다. | b5 · §3.1 165행 (merge 안 손 고침을 본다) | 확실 | 설계는 이 문서 문장을 고친다고 적지 않았다. 문장을 고치지 않으면 거짓이 남는다. |
| tests/test_team_docs.py:270-273 | `"…기본 기준을 몰라 덧붙이기 검사를 건너뛴 때(그 알림 줄이 나온다)다. …"` 를 §3 에서 통째로 문다. | b21 A · §1.1 90행 (건너뜀을 검사 불가로) | 확실 | 목록의 「§3 공시 문장 락(b21)」 이 이 단언까지 가리키는지 모호하다. rows-b 755행은 263-268 행(b21 B)만 짚었다. |
| tests/test_team_docs.py:257-261 | §3 의 「그 밖에는 — 사본을 framing 없이 만든 뒤 ② 로 짝을 끝에 덧붙인 사본 · … — 다시 부를 때마다 같은 ② 를 준다. 이 판정은 틀려도 멈추는 쪽으로만 틀린다.」 전체를 문다. | b18 · 94행 | 아마 | 표지가 있는 사본은 인자 없이 불러도 된다는 문장을 새 문장으로 더하면 그대로고, 이 문장을 고치면 붉어진다. |
| tests/test_team_docs.py:107-108 | §3 에 `"덧붙이기 검사와 같은 기준(--base <ref>, 없으면 기본 브랜치 origin/HEAD)의 같은 파일 · 같은 줄과 견준다"` | b3 · 92행 | 아마 | 대체 대조 문장을 이력 거슬러 찾기에 맞춰 고쳐 쓰면 붉어진다. |
| tests/test_epic_handoff.sh:136 | `assert_eq "$TEAM_LINE" "$(team_expected)" "AC17: team 넘김 줄 전체가 …"`. 옛 줄에 치환 표를 적용한 글과 바이트로 견준다. | a1 · §4 190행 | 확실 | §4 본문에는 「치환 표에 한 행」 이라고만 있고 뒤집히는 목록에는 없다. |
| tests/test_conductor_ledger.py:2167, 2210-2211 · tests/test_team_status.sh:795 | `self.assertFalse(L._gate_on(self.w))`, `L._retry_of(L.HL.retry_name(2, 3))`, `Reader(…).gate_on()` 처럼 비공개 이름을 직접 부른다. | a4a·a4b · §2.3 152-153행 | 아마 | 한 곳으로 모으며 `_gate_on` · `_retry_of` 를 지우거나 옮기면 붉어진다. 이름을 남기면 그대로다. |
| tests/test_spec_review_bundle.sh:159 | DEG_SEC 에 `"번호 대조 경고가 있으면 셋이 비었어도 「이상 없음」·「경고 없음」은 쓰지 않는다"` 가 있다. | a5 · §2.3 155행 | 아마 | rows-a 안 A 는 `## degrade 채널` 끝 문장에 예외를 더한다. 그 문장을 고쳐 쓰면 붉어지고, 새 문장으로 덧붙이면 그대로다. |
| tests/test_team_tasks.sh:143, 381 · tests/test_start_bundle.sh:449 | 단순 작업 브랜치(`fix/typo`, `fix/e2e`, `chore/e2e`)에서 `job_results.py check … implement-1.md` 가 받음 줄을 낸다. 그 브랜치는 갈라진 뒤 `job new` 로 `INTENT.md` 를 처음 커밋한다. | §1.2 101-109행 | 아마 | 쓰인 그대로면 INTENT.md 통째 추가가 「결정 기록 밖 칸 고침」 으로 거절된다. qg 리뷰 101행 지적이 어떻게 처리되느냐에 달렸다. |
| tests/test_session_fixture.py:104 | `self.assertEqual(sorted(res["toolUseResult"]), ["answers", "questions"])` | c4c · §2.3 156행 | 아마 | rows-c:227 이 더할 칸으로 든 `toolUseResult.annotations` 를 answer.jsonl 의 toolUseResult 안에 넣으면 붉어진다. `dataFlowOn` 같은 최상위 칸만 더하면 그대로다. |
| tests/test_roadmap_model.py:375 | `self.assertEqual(sorted(entries), [self.DIR + "x/roadmap.md"])   # 역할 폴더의 글은 읽지도 않는다` | b14 · §1.3 116행 | 아마 | 알림을 `tree_entries` 에서 만들려면 역할 폴더의 `type: roadmap` 파일을 읽어야 해서 붉어진다. 다른 자리에서 읽으면 그대로다. |

## 살펴봤으나 걸리지 않는 것

- a2: test_spec_review_bundle.sh:154 는 `argument-hint` 에 `--bundle` 이 있는지만 본다. shared/tests 의 spec-review 락은 설명 글자를 못 박지 않는다.
- a6: test_human_judge.py 의 `test_a_gate_word_in_the_requestion_does_not_hide_it` 와 `test_skip_lines_compare_only_the_same_gate` 는 자기 관문 이름으로 다시 물은 경우라 그대로다.
- a7: `test_flow_lines_skip_gate_named_questions` 의 둘째 단언(설계 없이 가도 될까요 + 설계하고 간다 → MISMATCH)은 그대로다.
- a8: test_walk_next.sh 는 `line <이름>` 으로 키를 찾고 마지막 줄이나 줄 수를 세지 않는다. 걸음 보기 출력에 `보낼 인자:` 줄이 더해져도 붉어지지 않는다.
- a9~a11: test_walk_table.py:51 은 표 파일 줄 형태만 본다. test_walk_next.sh 줄 묶음 C 는 `흐름:` 줄을 단언하지 않는다.
- a12.3a: 걸음 보기를 다른 폴더에서 부르는 테스트가 없다.
- b5: test_job_results.sh:344, 347 은 clean merge 라 remerge 로 바꿔도 같다. test_team_status.sh:237-238 도 같다.
- b6: test_team_status.sh:372, 375, 376, 339 는 꼬리 `조상 관계를 잴 수 없다` 를 지키면 그대로다. test_merge_check.sh:375 는 `branch_tip._is_ancestor` 의 메시지만 본다.
- b7: test_job_results.sh 의 E1 은 `implement-plan-…`, E2 는 `implement-1.md` 로 흐름과 이미 맞다. 다른 `check` 호출들도 이름이 맞다.
- b8: test_team_sync.sh:198 의 「task 절이 없는 계획」 사유는 따로 있는 거절이라 번호 초과 문구와 가른다. 확신은 낮다.
- b10: 멈춤 문구를 못 박은 것은 rc 만이다 (test_start_bundle.sh:290). test_job_results.sh:228 은 `"계획 3"` contains 뿐이다. test_human_gate.sh:140 의 「아직 없다 … 만들거나 앞 계획을 먼저 머지한 뒤 다시 부른다」 는 다른 갈래(설계를 못 읽은 사유 힌트)다.
- b12: test_team_rules.sh 에는 RULES.md 가 없는 `candidates` 행이 없다.
- b13: test_conductor_ledger.py 의 `--reset` 호출들은 단계를 못 센 블록이 없는 장면이다. `test_refresh_fills_countable_blocks_first` 는 `--reset` 없는 호출이라 그대로다.
- b16: test_team_tasks.sh:189 는 job notes 만 본다. 507-509 는 solo 과제 하나뿐이라 겹침 0개 그대로다.
- b9·b1 1e: test_team_layout.py 의 거절 목록은 추가만 된다. 모든 `--paths` 는 파일이거나 `/` 로 끝난다.
- c2b·c7c·a12.9b: test_conductor_dispatch_reference.sh 는 `once '<절>' '<문장>'` 꼴이라 문장을 더하는 것은 통과한다. 142 행 외에 고칠 문장은 없다.
- c3a: relay-checker.md 를 문 것은 test_epic_conductor_skill.sh:68-73 의 몇 글귀뿐이다.
- c5: 「다른 세션 뒤 답은 막지 못한다」 를 못 박은 테스트가 없다.
- c6: 기계 줄 머리를 열거해 단언하는 곳이 없다. test_team_results.py:140 은 비기계 줄이 거절되지 않는지만 본다. test_merge_check.sh 는 줄 위치로 세지 않는다.
- c2e 프로필: test_design_profile_source.sh 의 단언은 부분 문자열이라 모드 문장을 더하는 것은 통과한다.
- b19, a12.12: `흐름을 고정하지 않는다` 제목 글을 못 박은 테스트는 못 찾았다.
- 판 올림: test_team_docs.py `version_problems` 는 「다섯 낱말(`--layout team`·`rules_budget`·`handbook_budget`·`job new`·`종료 코드 4`)을 모두 담은 CHANGELOG 절이 정확히 하나」 를 요구한다. 새 판 절에 다섯을 다 적으면 둘이 되어 붉어진다. 다섯을 다 적지 않으면 된다.

## 끝까지 보지 못한 자리

- c4b: 네 출력(시작 묶음의 관문 · 결과 대조 · 걸음 보기 · 상태 보기)에 `알림:` 줄이 더해질 때 붉어질 테스트를 확정하지 못했다.
  - 알림이 나오는 경우는 갈라진 형제 브랜치와 INTENT 를 읽지 못한 끝이다.
  - 갈라짐 픽스처가 있는 test_start_bundle.sh:322-324, test_walk_next.sh:200-203, test_human_record.sh:387-391 은 대상 끝 자체가 갈라져 stdout 이 비거나 `record` 라 걸리지 않는 것으로 읽었다.
  - 출력 전체를 줄 위치로 센 단언은 test_human_gate.sh 쪽을 끝까지 읽지 못했다 (`sed -n 2p` 가 119, 145, 363 행에 있다).
- test_control_plane.py/.sh 와 test_roadmap_status.sh(1992줄), test_conductor_status.py 의 출력 줄 단언은 b14 알림 줄과 b16 겹침 줄 기준으로 훑지 못했다. grep 으로 걸리는 줄만 봤다.
- tools/ 는 조각과 관련 없어 보고 grep 하지 않았다. shared/tests 는 spec-review · docreview 프로필 관련 부분만 봤다.
- test_team_status.sh 869줄과 test_team_tasks.sh 는 b5, b6, b10, c4b 관련 줄만 읽었다.
- 심볼릭 링크로 걸린 테스트가 있는지는 확인했다. `ls -la` 에서 링크가 없고 숨김 폴더도 없다.
