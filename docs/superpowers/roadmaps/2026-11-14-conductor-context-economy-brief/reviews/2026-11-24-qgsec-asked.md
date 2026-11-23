---
type: roadmap-review
roadmap: docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md
epic: "-"
site: asked
reviewed_base: bb8c7a43efa94af194e3b27f5408b12e87efbb84
reviewed_head: 78570962ed24e10ea6a8519de1cbb4e2e7875de1
contract: 2
---

# 로드맵 밖(품질 게이트 보안 지적 고침) · asked(PR #330 · 머지 전) 리뷰 기록

- qg 판정: qg: defect · 막는 지적 2 · 선택 12 · 차등 새 실패 0 · e2e 안 함 · 제외 패치 0 · iter 1 · 78570962
- intent-critic: intent-critic — 질문 3개 묻지 않음(범위 모드)
- 보관 사본: /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-conductor-context-economy-brief/files/report/qg-qgsec-asked-2026-11-24-pr330

## 질문 1

- 정체: docs/superpowers/specs/2026-11-22-qg-security-findings-design.md#결정기록-자기승인#방향
- 의심하는 것: docs/superpowers/specs/2026-11-22-qg-security-findings-design.md 의 결정기록-자기승인(고른 라벨) 「「드러내기 (권장)」」
- 질문: 고친 문서에 따르면 일꾼이 `씀` 줄 대신 `확인` 줄을 직접 심으면 그 고침은 판정에도 목록에도 나오지 않습니다. 그러면 CRITICAL 지적인 「남의 고침을 확인 없이 통과시킨다」는 다른 문으로 그대로 열려 있는데, 드러내기로 고른 길이 이 지적을 닫은 것으로 봐도 되나요? 여기는 직접 확인해 보세요 — 시험용 로드맵의 기계 상태에 `확인` 줄을 손으로 하나 넣고 `conductor_status.py show` 와 표시 없는 `confirm` 의 출력을 보면 됩니다.
- 근거의 종류: 읽어서 봄
- 관찰:
  [읽음] plugins/spec-distill/references/conductor-state-branch.md:67 - `확인한 끝` 절의 줄(`씀` · `확인`)은 기계 상태 파일에 있어 이 기계에서 도는 누구나(담당자 세션 · 하위 agent 도) 쓸 수 있다 — 남의 고침을 `씀` 으로 적으면 위 판정은 그 고침을 세지 않는다. `씀` 줄은 막지 않고 드러낸다: `conductor_status.py show` 가 확인한 끝 뒤의 `씀` 커밋 가운데 규칙 사본 · `rules-base.md` · `pending.md` 를 바꾼 것을 「이 기계가 쓴 것으로 적힌 고침 n」 과 커밋마다 한 줄(`<8자> · <바꾼 경로들>`)로 내고, 머지 전 「승인 기록 다시 보이기」 가 그 목록을 싣는다. 그런 `씀` 커밋이 확인한 끝 뒤에 있으면 `sync` 는 `확인한 끝` 절을 한 줄로 접지 않고(버려진 `씀` 줄만 지운다), 목록을 사용자에게 보인 뒤 `confirm --confirmed <확인할 끝>` 으로만 접는다 — 예외는 `rules-reset` 하나다: 대기 줄을 바꾼 `씀` 커밋이 없을 때만 접는다(규칙 쪽 `씀` 고침은 그 명령이 사본을 지우며 되돌린다). 남의 고침을 재지 못하는 동안에는 이 목록도 나오지 않고, `confirm` 이 다시 센 보고에도 `씀` 커밋은 실리지 않는다 — 그때는 「남의 고침을 재지 못했다」 가 나온다. 직접 심은 `확인` 줄은 드러나지도 않는다 — 그 끝까지의 고침은 판정에도 목록에도 나오지 않는다. 아직 막는 장치는 없다.
  [읽음] docs/superpowers/specs/2026-11-22-qg-security-findings-design.md:125 - 2026-11-22 사용자(지휘자가 만든 질문 — 자기 승인 구멍을 어느 길로 고칠까): 「드러내기 (권장)」
- qg 가 돌려준 상태: 묻지 않음
- 같은 대상에 전에 물은 것: 없음
- 답: 의도다
- 답 원문: -
- 답한 때: 2026-11-24 05:14

## 질문 2

- 정체: docs/superpowers/specs/2026-11-22-qg-security-findings-design.md#Context-Why#방향
- 의심하는 것: docs/superpowers/specs/2026-11-22-qg-security-findings-design.md 의 Context-Why(확정) 「team 형식을 쓰는 로드맵은 아직 없다 — 켜는 일은 E4 다.」
- 질문: 고친 세 길 가운데 두 길은 아직 아무 로드맵도 쓰지 않는 team 형식 위에 있는데, 이 PR 에서 확인 기록 접기 · `rules-reset` · `confirm` 의 종료 코드가 바뀌었고 후속 PR 로 넘긴 일도 네 줄 더 남았습니다. 「보안 넷 먼저」를 고를 때 기대한 만큼 얻는 것이 있었나요, 아니면 E4 에서 team 형식을 켤 때 한꺼번에 정하는 편이 나았나요?
- 근거의 종류: 읽어서 봄
- 관찰:
  [읽음] docs/superpowers/specs/2026-11-22-qg-security-findings-design.md:18 셋 다 team 형식 로드맵의 길이거나 테스트 픽스처다. team 형식을 쓰는 로드맵은 아직 없다 — 켜는 일은 E4 다.
  [읽음] docs/superpowers/specs/2026-11-22-qg-security-findings-design.md:119 | 단언 셋 — 낡은 끝을 명령줄로 불러 1 · `confirm` 출력과 `--confirmed` 사이에 들어온 새 `씀` · 대기 줄에 남의 고침과 내 고침이 함께 있을 때의 `rules-reset` | 동작은 둘째 리뷰가 실험으로 확인했고 함수 쪽 단언은 있다. 새 단언은 변이 확인까지 한 라운드가 더 든다 | 로드맵 끝의 후속 PR |
- qg 가 돌려준 상태: 묻지 않음
- 같은 대상에 전에 물은 것: 없음
- 답: 의도다
- 답 원문: -
- 답한 때: 2026-11-24 05:14

## 질문 3

- 정체: docs/superpowers/specs/2026-11-22-qg-security-findings-design.md#Constraints#갈라짐
- 의심하는 것: docs/superpowers/specs/2026-11-22-qg-security-findings-design.md 의 Constraints(없음) 「다른 열린 PR(#323 · #324)이 `references/conducting.md` 를 고치고 있다 — 고치는 문장을 한 자리로 좁힌다.」
- 질문: 설계에는 conducting.md 를 함께 고치는 열린 PR 로 #323 · #324 가 적혀 있습니다. 그런데 지금 그 파일을 고치는 열린 PR 은 #326 입니다. #326 은 「고칠 일은 지휘 흐름이 머지 앞에서 돌려보낸다」고 머지 앞 단계를 바꾸고, 이 PR 은 같은 단계에 「리더가 쓰지 않은 고침이 있으면 머지 명령 줄을 내지 않는다」를 더합니다(74행). 두 PR 이 정한 머지 앞 단계의 흐름이 서로 맞는지 정해 두셨나요? 여기는 직접 확인해 보세요 — PR #326 의 conducting.md 변경에서 머지 앞 단계를 찾아 이 PR 의 74행과 견줘 보면 됩니다.
- 근거의 종류: 다른 팀에서 봄 · 읽어서 봄
- 관찰:
  166 [다른 팀] - feature/qg-review-only · PR #326 feat(qg)!: qg 는 한 번 보고 끝내고, 고칠 일은 지휘 흐름이 머지 앞에서 돌려보낸다 (R4) — plugins/spec-distill/.claude-plugin/plugin.json · plugins/spec-distill/CHANGELOG.md · plugins/spec-distill/README.md · plugins/spec-distill/references/conducting.md · plugins/spec-distill/tests/test_conducting_loop.sh · plugins/spec-distill/tests/test_roadmap_draft_skill.sh
  [읽음] docs/superpowers/specs/2026-11-22-qg-security-findings-design.md:42 - 다른 열린 PR(#323 · #324)이 `references/conducting.md` 를 고치고 있다 — 고치는 문장을 한 자리로 좁힌다.
- qg 가 돌려준 상태: 묻지 않음
- 같은 대상에 전에 물은 것: 없음
- 답: 의도다
- 답 원문: -
- 답한 때: 2026-11-24 05:14

## 질문 4

- 정체: diff#plugins/spec-distill/.claude-plugin/plugin.json#갈라짐
- 의심하는 것: diff 의 plugins/spec-distill/.claude-plugin/plugin.json(없음) 「"version": "9.0.1",」
- 질문: 열려 있는 PR #327 도 spec-distill 을 같은 9.0.1 로 올립니다. 둘 다 머지되면 나중 쪽도 판이 9.0.1 그대로라 이미 설치한 사람이 갱신을 받지 못할 수 있는데, 이 판 번호를 지금 정해도 되나요?
- 근거의 종류: 다른 팀에서 봄 · 읽어서 봄
- 관찰:
  168 [다른 팀] - fix/standing-suite-failures · PR #327 fix(tests): 늘 실패하던 테스트 아홉을 뿌리에서 고치고 대조의 임시 자리 고르기를 단단히 한다 — spec-distill 9.0.1 · quality-gates 15.3.3 · plugin-audit 1.10.2 — plugins/spec-distill/.claude-plugin/plugin.json · plugins/spec-distill/CHANGELOG.md · plugins/spec-distill/tests/test_roadmap_draft_skill.sh
  172 [다른 팀] - fix/qg-security-findings · PR #330 fix(spec-distill): 품질 게이트 리뷰의 보안 · 자기 승인 지적 셋을 고친다 — spec-distill 9.0.1 — docs/superpowers/specs/2026-11-22-qg-security-findings-design.md
  [읽음] plugins/spec-distill/.claude-plugin/plugin.json:4 "version": "9.0.1",
- qg 가 돌려준 상태: 상한 넘어 남김
- 같은 대상에 전에 물은 것: origin/feature/roadmap-2026-11-14-conductor-context-economy-brief-reviews:docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/reviews/2026-11-22-E1-merged-pr322.md
- 답: 묻지 않음(상한 넘어 남김)
- 답 원문: -
- 답한 때: -

## 질문 5

- 정체: diff#plugins/spec-distill/tests/test_roadmap_draft_skill.sh#중복
- 의심하는 것: diff 의 plugins/spec-distill/tests/test_roadmap_draft_skill.sh(없음) 「# major 만 잰다 — 호출 이름을 바꾼 판이 9 다. patch · minor 자리까지 묶으면 다음 PR 의 판 올림마다 빨개진다.」
- 질문: PR #327 은 「늘 실패하던 테스트 아홉을 뿌리에서 고친다」면서 이 테스트 파일을 고치고 판도 9.0.1 로 올립니다. 그러면 같은 판 번호 검사(AC19)를 그쪽도 따로 고쳤을 수 있는데, 두 PR 이 이 자리를 서로 다르게 고쳐도 괜찮은가요? 여기는 직접 확인해 보세요 — PR #327 의 diff 에서 test_roadmap_draft_skill.sh 의 AC19 줄을 이 PR 의 214행과 견주면 됩니다.
- 근거의 종류: 다른 팀에서 봄 · 읽어서 봄
- 관찰:
  168 [다른 팀] - fix/standing-suite-failures · PR #327 fix(tests): 늘 실패하던 테스트 아홉을 뿌리에서 고치고 대조의 임시 자리 고르기를 단단히 한다 — spec-distill 9.0.1 · quality-gates 15.3.3 · plugin-audit 1.10.2 — plugins/spec-distill/.claude-plugin/plugin.json · plugins/spec-distill/CHANGELOG.md · plugins/spec-distill/tests/test_roadmap_draft_skill.sh
  [읽음] plugins/spec-distill/tests/test_roadmap_draft_skill.sh:214 # major 만 잰다 — 호출 이름을 바꾼 판이 9 다. patch · minor 자리까지 묶으면 다음 PR 의 판 올림마다 빨개진다.
- qg 가 돌려준 상태: 상한 넘어 남김
- 같은 대상에 전에 물은 것: 없음
- 답: 묻지 않음(상한 넘어 남김)
- 답 원문: -
- 답한 때: -

## 질문 6

- 정체: docs/superpowers/specs/2026-11-22-qg-security-findings-design.md#설계2-개인정보잠금#범위 축소
- 의심하는 것: docs/superpowers/specs/2026-11-22-qg-security-findings-design.md 의 설계2-개인정보잠금(없음) 「열쇠는 자리표시 글이거나 영문 식별자 꼴이어야 한다」
- 질문: 목표 G2 는 「어느 사전 열쇠에도 실제 글이 들어오면 잠금이 빨개진다」고 약속합니다. 그런데 잠금은 영문 식별자 꼴의 열쇠(밑줄을 쓴 사용자 이름 · 토큰 id 같은 것)를 그대로 통과시킵니다. 이 차이는 사용자가 고른 것이 아니라 작성자가 제안해 알리기만 한 것입니다. G2 의 약속 글을 그대로 둬도 될까요, 아니면 「한글 글 · 경로 · 메일 주소」로 좁혀 적어야 할까요?
- 근거의 종류: 읽어서 봄
- 관찰:
  [읽음] docs/superpowers/specs/2026-11-22-qg-security-findings-design.md:29 - G2. 세션 기록 픽스처의 어느 사전 열쇠에도 실제 글이 들어오면 잠금이 빨개진다.
  [읽음] plugins/spec-distill/tests/test_session_fixture.py:36 IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
  [읽음] docs/superpowers/specs/2026-11-22-qg-security-findings-design.md:139 작성자 제안(사용자가 줄마다 확인하지 않은 것): 열쇠에 영문 식별자 꼴을 받는 것(사용자 이름 · 토큰 id 같은 식별자 꼴의 실제 값은 열쇠로 지나간다 — 사용자에게 알렸다) · 목록을 있는 `show` 에 두는 것 · patch 판 올림 · 접는 길을 `confirm --confirmed` 하나로 두는 것(사용자에게 앞 글로 보였다) · `rules-reset` 의 새 알림 글자(구현 담당자가 낸 예 그대로 — 사용자는 질문 창의 선택지 설명에서 봤다). (「HEAD 의 조상인 출처 커밋도 받는 것」 은 위 사용자 답으로 바뀌었다 — 조상이 아니면 대체 대조로 간다.)
- qg 가 돌려준 상태: 상한 넘어 남김
- 같은 대상에 전에 물은 것: 없음
- 답: 묻지 않음(상한 넘어 남김)
- 답 원문: -
- 답한 때: -
