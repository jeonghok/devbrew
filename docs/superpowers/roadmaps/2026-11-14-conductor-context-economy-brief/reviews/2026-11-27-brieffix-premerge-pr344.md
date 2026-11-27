---
type: roadmap-review
roadmap: docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md
epic: "-"
site: premerge
reviewed_base: 35a232e125c56b639728ec5cd114c16ec7e5c23f
reviewed_head: 1af420949c91ca102bc3d40f70d6aab3bba9e219
contract: 3
---

# 로드맵 밖(로드맵 생성기 번호 줄 고침) · premerge-pr344 리뷰 기록

- qg 판정: qg: clean · 막는 지적 0 · 선택 9 · 차등 새 실패 0 · e2e 안 함 · 1af42094
- intent-critic: intent-critic — 질문 2개 묻지 않음(범위 모드)
- 보관 사본: qg-brieffix-premerge-pr344-2026-11-27

## 질문 1

- 정체: diff#plugins/spec-distill/scripts/roadmap_render.py#마찰
- 의심하는 것: diff 의 plugins/spec-distill/scripts/roadmap_render.py(없음) 「return [line for t in ids if t.startswith(prefix) for line in ([idx.lines[t]] if t in idx.lines else []) + idx.s5.get(t, [])]」
- 질문: 번호 하나(RC · ST)를 배정하면 brief §5 에서 그 번호가 끝 연결이나 인용으로 스치기만 한 줄까지 모두 묶음에 실리게 바뀌었는데, 그래서 그 에픽에 배정하지 않은 위험 줄이 딸려 오고 같은 위험이 두 꼴로 두 번 실리는 것도 뜻하신 바인가요? 여기는 직접 확인해 보세요 — 테스트 방식 로드맵 brief 의 §5 에서 RC36 을 찾으면 기각 줄 · 위험 K6 줄 · 근거 줄 셋이 나옵니다. RC36 과 K6 을 함께 받은 E4 묶음을 임시 폴더에서 다시 만들어 「기각 · 위험」 칸에 K6 위험이 두 번 나오는지, RC38 만 받은 E1 묶음에 받지 않은 K2 위험 줄이 실리는지 보세요.
- 왜 묻나: 뜻이 아니면 번호를 정의한 줄만 싣거나 겹친 위험 줄을 걸러야 하고, 뜻이면 도는 로드맵의 묶음이 다음에 다시 나눌 때 말없이 길어진다.
- 근거의 종류: 다른 팀에서 봄 · 읽어서 봄
- 관찰:
  613 [다른 팀] ### 2026-11-26 · E4 의 경로 예약에 E2 가 만든 지운 것 기록(docs/removed-tests.md)과 기준 문서(docs/testing.md)를 더한다 — E4 가 테스트를 지우며 고칠 자리다
  624 [다른 팀] - K2 — 위험 — 숨은 가정: 지워서 생기는 손실은 드러난다 — 스위트와 머지 전 대조가 지운 테스트를 보지 못한다(조사 7) · 대응: 지운 것 기록(C7) [RC38 → OQ15]
  628 [다른 팀] - K6 — 위험 — 실패 양식: 보안 락이 문구 확인으로 분류돼 지워지거나 느슨해진다 — 판정 단위가 파일이고 한 파일에 문구 단언과 보안 단언이 섞여 있을 때(조사 7) · 대응: 보안 갈래 예외(C6) [RC36 → OQ14]
  [읽음] plugins/spec-distill/scripts/roadmap_render.py:416 return [line for t in ids if t.startswith(prefix) for line in ([idx.lines[t]] if t in idx.lines else []) + idx.s5.get(t, [])]
  [읽음] docs/superpowers/interview/2026-11-20-test-method-rework-brief-interview.md:292 - 위험 K2 — 숨은 가정: 지워서 생기는 손실은 드러난다 — 스위트와 머지 전 대조가 지운 테스트를 보지 못한다(조사 7) · 대응: 지운 것 기록(C7) [RC38 → OQ15]
  [읽음] docs/superpowers/roadmaps/2026-11-20-test-method-rework-brief/E1.md:6 ids: [C2, C9, C11, C14, C16, C17, OQ2, OQ5, OQ11, OQ17, OQ23, RC1, RC2, RC3, RC4, RC5, RC6, RC7, RC8, RC9, RC17, RC18, RC19, RC38, RC39, RC41, RC44, RC45, RC46, RC47, K8, K12, K13, S1, S3, S11, S14, S17, S21, S22, S27, S28, S30, «arko-delete-tests», «google-taming-ci»]
  [읽음] docs/superpowers/interview/2026-11-20-test-method-rework-brief-interview.md:296 - 위험 K6 — 실패 양식: 보안 락이 문구 확인으로 분류돼 지워지거나 느슨해진다 — 판정 단위가 파일이고 한 파일에 문구 단언과 보안 단언이 섞여 있을 때(조사 7) · 대응: 보안 갈래 예외(C6) [RC36 → OQ14]
  [읽음] docs/superpowers/roadmaps/2026-11-20-test-method-rework-brief/E4.md:91 - K6 — 위험 — 실패 양식: 보안 락이 문구 확인으로 분류돼 지워지거나 느슨해진다 — 판정 단위가 파일이고 한 파일에 문구 단언과 보안 단언이 섞여 있을 때(조사 7) · 대응: 보안 갈래 예외(C6) [RC36 → OQ14]
- qg 가 돌려준 상태: 묻지 않음
- 전에 한 답: 없음
- 답: 의도다
- 답 원문: -
- 답한 때: 2026-11-27 19:35

## 질문 2

- 정체: diff#plugins/spec-distill/tests/test_roadmap_render.py#앞 결정 뒤집힘
- 의심하는 것: diff 의 plugins/spec-distill/tests/test_roadmap_render.py(없음) 「self.assertEqual(rest, [head, idx.s5["RC9"][0]]) # 전에는 §5 줄만 실렸다 — 같은 번호가 실린 줄이 더 실린다」
- 질문: 같은 번호가 brief §4 항목 머리와 §5 줄에 함께 있을 때 전에는 §5 줄만 실었는데(앞 계획의 「§5 줄이 이긴다」), 이제 §4 항목까지 「기각 · 위험」 칸에 함께 싣게 바꾼 것이 뜻하신 바인가요? 여기는 직접 확인해 보세요 — §4 항목 머리와 §5 줄에 같은 RC 번호가 있는 brief 로, 그 번호와 그 항목의 «key» 를 한 에픽에 배정해 묶음을 만들고 그 §4 항목이 「웹 근거」 와 「기각 · 위험」 두 칸에 다 나오는지 보세요.
- 왜 묻나: 뜻이 아니면 §5 줄이 있을 때는 §4 항목을 「기각 · 위험」 칸에서 빼야 하고, 뜻이면 그 항목의 «key» 도 배정된 에픽에서 같은 §4 항목이 묶음 두 칸에 실린다.
- 근거의 종류: 읽어서 봄
- 관찰:
  [읽음] docs/superpowers/plans/2026-10-19-r10-plan2-end-gates.md:426 - Produces: `brief_universe` 의 번호 집합에 §4 항목 **첫 줄**의 `RC<n>` 이 든다. `index_brief().lines["RC<n>"]` 은 그 §4 항목(첫 줄 + 들여 쓴 본문 줄) — 같은 RC 가 §5 에도 있으면 §5 줄이 이긴다(지금 순서 그대로).
  [읽음] plugins/spec-distill/tests/test_roadmap_render.py:259 self.assertEqual(rest, [head, idx.s5["RC9"][0]]) # 전에는 §5 줄만 실렸다 — 같은 번호가 실린 줄이 더 실린다
- qg 가 돌려준 상태: 묻지 않음
- 전에 한 답: 없음
- 답: 의도다
- 답 원문: -
- 답한 때: 2026-11-27 19:35
