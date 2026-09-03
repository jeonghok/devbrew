# 착수 시점 baseline (Task 1)

기준 커밋: `e2893f7ccdce0f1d721985f18518524e4c5610c6`
실행: `bash shared/tests/test_*.sh` · `bash plugins/*/tests/test_*.sh` (전 169개 — shared 8 · quality-gates 102 · spec-distill 59)

## 선재 RED

**0건.** 두 갈래로 실측했다 — ⑴ `bash "$t" 2>&1 | tail -3` 로 브리프의 명령을 그대로 돌려
`Fail: [1-9]` 를 grep(빈 결과), ⑵ 각 파일을 개별 실행해 실제 종료 코드를 캡처(169/169 전부
`rc=0`). 「이 리포는 main 에 선재 RED 가 있는 것으로 기록돼 있다」는 일반 가정(브리프 Step 1
의 서문)이 **이 커밋에는 적용되지 않는다** — 지금은 깨끗하다. 아래 「GREEN 인 락」 절이 169개
전량이다.

## GREEN 인 락 169개

(전량 목록 — M10 이 이것과 대조한다)

### shared/tests/ (8)

- `shared/tests/test_adjudication_behavior.sh`
- `shared/tests/test_assert_behavior.sh`
- `shared/tests/test_changelog_integrity.sh`
- `shared/tests/test_copy_of_contract.sh`
- `shared/tests/test_dispatch_disposition.sh`
- `shared/tests/test_no_new_duplication.sh`
- `shared/tests/test_presence_corpus_behavior.sh`
- `shared/tests/test_skill_reference_pointers.sh`

### plugins/quality-gates/tests/ (102)

- `test_adversarial_model_consistency.sh`
- `test_adversarial_persona.sh`
- `test_agent_color.sh`
- `test_agent_frontmatter_keys.sh`
- `test_agent_model_inherit_sweep.sh`
- `test_agent_tools_lock_differential.sh`
- `test_agent_tools_lock_mutation.sh`
- `test_artifact_adversarial_frontmatter.sh`
- `test_artifact_bounds.sh`
- `test_artifact_branch_guard.sh`
- `test_artifact_codex_reviewer.sh`
- `test_artifact_commit.sh`
- `test_artifact_critic_frontmatter.sh`
- `test_artifact_metadata.sh`
- `test_artifact_path_auth.sh`
- `test_baseline_cache.sh`
- `test_branch_worktree.sh`
- `test_build_codex_prompt.sh`
- `test_build_pr_context.sh`
- `test_cancel_qg.sh`
- `test_cancel_qg_med4.sh`
- `test_check_allowed_tools_order.sh`
- `test_check_review_scope.sh`
- `test_check_trivia.sh`
- `test_classify_artifact_target.sh`
- `test_codex_backward_compat.sh`
- `test_codex_copies_agree.sh`
- `test_codex_dispatch_invariant.sh`
- `test_codex_extractor_positive_marker.sh`
- `test_codex_gate_observation.sh`
- `test_codex_invocation_contract.sh`
- `test_codex_prompt_untrusted_clause.sh`
- `test_codex_result_banner.sh`
- `test_codex_reviewer_frontmatter.sh`
- `test_codex_runner_degrade_contract.sh`
- `test_codex_runner_no_effort_pin.sh`
- `test_compute_test_scope_candidates.sh`
- `test_cost_consent.sh`
- `test_critiquing_artifacts_skill.sh`
- `test_detect_codex.sh`
- `test_detect_runtime.sh`
- `test_diagram_facts.sh`
- `test_discover_plan.sh`
- `test_discover_spec.sh`
- `test_extract_codex_invocations.sh`
- `test_failure_injection.sh`
- `test_findings_parser.sh`
- `test_gh_identity.sh`
- `test_git_derived_scope.sh`
- `test_governance_no_capability_caps.sh`
- `test_guards_coverage_bidirectional.sh`
- `test_guards_declaration_mapping.sh`
- `test_impact_runtime_docs.sh`
- `test_isolation.sh`
- `test_law2_prose.sh`
- `test_no_write_matcher_hooks.sh`
- `test_pr_create.sh`
- `test_pr_detect.sh`
- `test_pr_understanding_builder_frontmatter.sh`
- `test_precheck_retired.sh`
- `test_publish_degrade.sh`
- `test_publish_dry_run_zero_network.sh`
- `test_qa_ledger.sh`
- `test_qg_critique_routing.sh`
- `test_qg_false_clean_floor.sh`
- `test_qg_mutation_guard.sh`
- `test_qg_pipeline_no_gh.sh`
- `test_qg_publish_command.sh`
- `test_qg_publish_docs.sh`
- `test_qg_publish_offer.sh`
- `test_qg_publish_skill_orchestration.sh`
- `test_qg_runtime_sandbox.sh`
- `test_qg_worktree_helper.sh`
- `test_read_frontmatter.sh`
- `test_readme_scope_reconcile.sh`
- `test_readme_state_diagram_complete.sh`
- `test_render_terminal.sh`
- `test_resolve_baseline.sh`
- `test_review_floor_lock.sh`
- `test_review_scope_composition.sh`
- `test_run_test_selection.sh`
- `test_runner_adapters.sh`
- `test_runtime_contract_invariance.sh`
- `test_runtime_verdict_precedence.sh`
- `test_runtime_verifier_frontmatter.sh`
- `test_sandbox_enforced.sh`
- `test_scout_codex_integration.sh`
- `test_scout_script.sh`
- `test_security_reviewer_kill_switch.sh`
- `test_security_reviewer_persona.sh`
- `test_session_start_advisor_v2.sh`
- `test_setup_qg.sh`
- `test_skill_bash_allowlist_narrow.sh`
- `test_skill_codex_skip_prose.sh`
- `test_skill_drop_notice_consumed.sh`
- `test_skill_orchestration.sh`
- `test_skill_plugin_root_fallback.sh`
- `test_synthesize_artifact_findings.sh`
- `test_synthesize_findings.sh`
- `test_synthesize_promoted_findings.sh`
- `test_test_scope_validator_frontmatter.sh`
- `test_worktree.sh`

### plugins/spec-distill/tests/ (59)

- `test_arm_ledger_timing.sh`
- `test_arm_once.sh`
- `test_blind_spot_prober_frontmatter.sh`
- `test_brainstorming_entry.sh`
- `test_brief_agents.sh`
- `test_brief_bundle.sh`
- `test_brief_codex_axes.sh`
- `test_brief_inline_blob.sh`
- `test_brief_no_length_cap.sh`
- `test_brief_no_statement_cap.sh`
- `test_brief_review_entry.sh`
- `test_brief_review_meta.sh`
- `test_brief_review_ng3.sh`
- `test_build_spec_codex_prompt.sh`
- `test_check_brief.sh`
- `test_check_seed.sh`
- `test_check_verbatim_coverage.sh`
- `test_compression_adopters.sh`
- `test_conducting_interview_internal.sh`
- `test_conducting_interview_stage.sh`
- `test_coverage_mapper_frontmatter.sh`
- `test_detect_codex.sh`
- `test_handoff_context_empty_subsections.sh`
- `test_handoff_context_section_required.sh`
- `test_handoff_conversation_reference.sh`
- `test_handoff_design_mode.sh`
- `test_handoff_kill_switch.sh`
- `test_hooks.sh`
- `test_kill_switches_v060.sh`
- `test_no_wall_clock.sh`
- `test_no_write_matcher_hooks_repo.sh`
- `test_parse_spec_structure.sh`
- `test_probe_sweep_residue.sh`
- `test_proceed_gate_adopters.sh`
- `test_readme_sync.sh`
- `test_request_framing_command.sh`
- `test_rereview_cap_consistency.sh`
- `test_resolve_mode_scope.sh`
- `test_review_dispatch.sh`
- `test_review_dispatch_design_mandate.sh`
- `test_reviewing_brief_skill.sh`
- `test_reviewing_spec_codex_merge.sh`
- `test_reviewing_spec_design_only.sh`
- `test_reviewing_spec_design_routing.sh`
- `test_reviewing_spec_state_keying.sh`
- `test_run_spec_codex_reviewer.sh`
- `test_seed_agents.sh`
- `test_seed_codex_axes.sh`
- `test_seed_gate_wiring.sh`
- `test_seed_inline_blob.sh`
- `test_seed_one_sentence.sh`
- `test_session_id_resolution.sh`
- `test_spec_reviewer_design_checklist.sh`
- `test_spec_reviewer_frontmatter.sh`
- `test_stale_terms.sh`
- `test_state_path.sh`
- `test_steelman_builder_scope.sh`
- `test_web_kill_switch.sh`
- `test_write_path_behavior.sh`

## P2 — ㉯ 도출 재실행 (Step 3)

`extract_codex_invocations.py plugins` → **7**(러너 6 + `tests/spike/test_codex_json_extraction.sh`).
`/scripts/` 후처리 후 → **6**:

```
plugins/plugin-audit/scripts/run_audit_codex_reviewer.sh
plugins/quality-gates/scripts/run_artifact_codex_reviewer.sh
plugins/quality-gates/scripts/run_codex_reviewer.sh
plugins/spec-distill/scripts/run_brief_codex_reviewer.sh
plugins/spec-distill/scripts/run_seed_codex_reviewer.sh
plugins/spec-distill/scripts/run_spec_codex_reviewer.sh
```

기대치(7 → 6)와 정확히 일치. `extract_codex_invocations.py` 자체는 건드리지 않았다 —
`collect()` 의 확장자 필터 제거가 `test_sandbox_enforced.sh:51-62` 의 standing assertion 에
묶여 있어서다.

## P3 — L1 정밀 판정기 census (Step 5)

`shared/adjudication/check_wiring.py` 를 초안대로 작성(브리프 원문 그대로, 자체 수정 없음)하고
㉮ 네 파일에 `scan()`·`comprehension_count()` 를 돌렸다.

```
파일                                줄     kind     func                          guarded
synthesize_artifact_findings.py    105    continue phase_key                    False
synthesize_artifact_findings.py    109    continue phase_key                    False   (첫 루프 귀속)
synthesize_artifact_findings.py    109    continue phase_key                    False   (안쪽 루프 귀속 — 같은 문장이 두 for 문에 이중 계상)
synthesize_artifact_findings.py    200    continue phase_synth                  True
synthesize_artifact_findings.py    203    continue phase_synth                  False
synthesize_artifact_findings.py    216    continue phase_synth                  False
synthesize_artifact_findings.py    221    continue phase_synth                  False
synthesize_findings.py             233    continue promote_new_findings         False
synthesize_findings.py             239    continue promote_new_findings         False
synthesize_findings.py             295    continue apply_verdicts               False
synthesize_findings.py             307    continue apply_verdicts               True
synthesize_findings.py             310    continue apply_verdicts               False
synthesize_findings.py             333    continue dedup                        False
merge_brief_review.py              182    continue extract_critic_issues        True
merge_review.py                    97     continue extract_claude_issues        True
merge_review.py                    153    continue parse_codex_yaml             False
merge_review.py                    158    continue parse_codex_yaml             False
merge_review.py                    227    return   derive_codex_verdict         False
merge_review.py                    268    continue build_codex_findings_display False
merge_review.py                    322    continue load_history                 True
merge_review.py                    371    continue build_ledger                 True
---
버리는 분기 21 (continue 20 · break 0 · return 1) 중 미배선 15
ast.For/AsyncFor 문 39
컴프리헨션 내포 28
```

**계획(F5) 대비 정합성 확인.** 계획의 F5 는 인접-휴리스미틱으로 「미배선 약 13자리」를
추정했고 스스로 「오라클이 아니다」라고 적었다. 이 정밀 스캔(guarded 판정을 `_enclosing_branch`
로 계산)은 **15**를 낸다 — 차이 2는 ⑴ `synthesize_artifact_findings.py:109` 가 중첩 루프 둘에
각각 귀속돼 이중 계상되는 것 하나, ⑵ `merge_review.py:227` 의 루프 내 `return` (휴리스틱은
`continue` 만 셌다) 하나다. `for`문 39·컴프리헨션 28·`continue` 20·`break` 0·루프 내 `return`
1·파일별 `continue` 줄번호(`synthesize_findings` 233 239 295 307 310 333 ·
`synthesize_artifact_findings` 105 109 109 200 203 216 221 · `merge_review` 97 153 158 268
322 371 · `merge_brief_review` 182) 는 착수 전 별도로 실측된 값과 **완전히 일치** — 구현이
맞다는 교차 확증이다.

## 면제 후보 — 형태 셋 (Step 6)

| 후보 형태 | C6 | 인용 |
|---|---|---|
| 제자리 변형 루프 — 출력 컬렉션이 없고 원소를 수정만 한다 (`synthesize_artifact_findings.py:146` 의 `for f in findings: f.setdefault(...)`) | ⑴ | 버려지는 항목이 없으므로 처분할 대상이 없다 |
| 순수 집계 루프 — `continue` 가 「이 원소는 이 집계에 안 들어간다」이지 항목 소실이 아님 | ⑴ | 같음 |
| **선택 루프** — 출력이 컬렉션이 아니라 «단일 선택»(`for c in cands: … return c`)이거나, 걸러진 원소가 «별도 컬렉션에 수집»된다 | ⑴ | 버려지는 항목이 없다. 후보는 다음 호출에 다시 평가되거나 다른 리스트에 살아 있다 |

**세 번째 형태(선택 루프)는 착수 전 pre-flight(R1)가 실측으로 찾았다** — `plugins/spec-distill/hooks/review-dispatch.py`
는 아직 ㉮ 밖(Task 11 이 훅을 넣기 전)이라 이 Task 의 `scan()` 대상에 없지만, Task 11 이 훅을
배선하면 그 파일의 버리는 분기 **10자리**(`continue` 9 — `:305`·`:307`·`:309`·`:311`·`:313`·
`:315`·`:508`·`:511`·`:567` + 루프 내 `return` 1 — `:316`)가 L1 의 대상이 된다. Task 11 이
배선하는 것은 두 `decision:"block"` 분기뿐이고 그 둘은 이 세 루프 안에 있지도 않다. 세 루프를
읽은 결과(`:303-317` 선택 루프 · `:506-513` 자격 분류 루프 · `:564-570` 검증 루프) 열 자리
모두 항목이 소실되지 않는다 — 근거는 `.superpowers/sdd/2026-09-03-adjudication-topology/progress.md`
의 R1. **그 열 중 둘(`:308`·`:310` 의 상한 도달 분기)은 다툼의 여지가 있다** — 규칙 억제
(`suppressed()`)로 볼 수도 있다. Task 11 이 착수할 때 이 문서를 다시 확인해 결정한다.

## 면제 후보 — 오늘 ㉮ 네 파일의 미배선 15자리 중 T1 이 안 덮는 자리 (Step 6)

**분류 근거.** 설계 §3 의 T1 표(이 계획의 Task 8·9)가 배선을 약속하는 자리를 뺐다.
`synthesize_artifact_findings.py` 의 6자리는 전부 T1 이 덮는다 — `105`·`109`·`109` 는 T1-11
(`source_failed`, `phase_key` 의 `sources_failed` 카운터가 그 자리), `203`은 T1-5(`reject`),
`216`은 T1-6(`hold`), `221`은 T1-7(`absorbed`). `synthesize_findings.py` 의 `233`·`239`는
T1-4(`dropped_promoted`), `295`는 T1-2, `310`은 T1-1이 덮는다. 남는 것은 아래 다섯.

| 자리 | C6 | 근거 |
|---|---|---|
| `synthesize_findings.py:333`(`dedup`, `if f.get("promoted"): continue`) | ⑴ | 승격 항목은 `:329` 의 `passthrough = [f for f in findings if f.get("promoted")]` 로 **이미 별도 컬렉션에 수집**돼 있다 — 이 `continue`는 「dedup 그룹핑에 다시 안 넣는다」는 뜻이지 항목 소실이 아니다(선택 루프 형태). Task 8 Step 6(A6)이 건드리는 자리는 그룹 병합 루프(설계 T1-8, `:336-342` 근방)이지 이 줄이 아니다 — 계획 본문이 그 경계를 명시한다 |
| `merge_review.py:153`(`parse_codex_yaml`, `if line.startswith("findings:"): … continue`) | ⑴ | 이 루프의 원소는 finding 이 아니라 파일의 텍스트 줄이다(`for raw in lines:`). 스킵되는 것은 섹션 헤더 줄이고, 헤더 줄은 애초에 판정 대상 항목이 아니다 — 대응물이 원리적으로 없다 |
| `merge_review.py:158`(`parse_codex_yaml`, `if line.startswith("meta:"): … continue`) | ⑴ | 같음 — `meta:` 섹션 헤더 줄도 finding 이 아니다 |
| `merge_review.py:227`(`derive_codex_verdict`, 루프 내 `return "needs_revise"`) | ⑴ | `findings` 리스트 자체가 이 함수 밖에서 온전히 살아있다 — 함수는 항목을 컨테이너에서 제거하는 것이 아니라 ∃(escalating finding) 술어를 계산해 조기 반환할 뿐이다. 두 반환 경로(조기 `needs_revise` / 루프 완주 `approved`) 모두 같은 `findings` 를 관찰만 하고 아무것도 버리지 않는다 |
| `merge_review.py:268`(`build_codex_findings_display`, `if not isinstance(f, dict): continue`) | ⑵ | 이 함수의 유일한 호출부(`:553`)가 넘기는 `codex_findings` 는 `parse_codex_yaml()` 의 반환값(`:487`)이고, 그 함수는 `- ` 접두 줄마다 `cur = {}` 로만 finding 을 만든다(`:162-163`) — 이 리포의 실제 콜그래프 안에서는 `f` 가 dict 가 아닌 경우가 구조적으로 발생하지 않는다. 방어적 분기이지 실제로 항목이 버려지는 경로가 아니다 |

**남는 후보 없음 — `merge_brief_review.py`.** 유일한 미배선 후보였던 `:182`(`extract_critic_issues`)
는 이미 `guarded=True`(`accept()` 가 붙어 있다) 이므로 이 표에 오르지 않는다.

## P5 — 훅 import 도달성 (Step 7, 하드 게이트)

```
reachable: True
```

`plugins/spec-distill/scripts/adjudication.py` 는 `../../../shared/adjudication/adjudication.py`
로의 심볼릭 링크(git mode 120000)로 실재한다. `plugins/spec-distill/hooks/review-dispatch.py:52-53`:

```python
SCRIPTS_DIR = SCRIPT_DIR.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))
```

**게이트 통과 — Task 11(T5) 재설계 불필요.**

## P1 — L3 와 기존 seed 락의 충돌 (Step 8)

```
plugins/spec-distill/tests/test_seed_agents.sh   → Total: 15 | Pass: 15 | Fail: 0
plugins/spec-distill/tests/test_seed_one_sentence.sh → Total: 3 | Pass: 3 | Fail: 0
```

`PAIR_RE`/`PAIR_SED`(`test_seed_agents.sh:119-120`)가 frontmatter description 의 `<tag>
${var}` 쌍을 이미 정규화하고 있고, `check_seed.py` 는 `plugins/spec-distill/scripts/` 에 실재
한다. **오늘 충돌 없음** — 이 baseline 시점에서는 §8 추가 후보에 넣을 자리가 없다. U2(L3 슬롯
문법)를 구현하는 Task 7·13 착수 직전에 다시 돌려 확인한다.

## P6 — 형제 세션과 `review-dispatch.py` 동시 편집 조율 (Step 9)

```
git fetch origin  → 성공(read-only)
origin/main HEAD  → 094ecbc (Merge pull request #136)
```

이 커밋은 `review-dispatch.py` 를 건드리지 않는다(최근 이력의 마지막 터치는 `d099e71`). 형제는
그 훅을 걷어내지 않고 **목적지 리터럴만** 고친다(입력 인터뷰 `:190-193` 의 OQ3). 실제 제약은
같은 파일을 두 사이클이 동시에 고치는 것이다.

- **내가 만질 자리** — `:598-602`·`:751-755` 의 두 `decision:"block"` 분기 (Task 11)
- **형제가 만질 자리** — 목적지 리터럴

**Task 11 착수 직전에 다시 확인한다** — 확인과 편집 사이가 창이다. push·merge·PR 은 이 Task
에서 하지 않았다(read-only `git fetch` 만).
