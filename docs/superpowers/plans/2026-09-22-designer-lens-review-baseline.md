# designer-lens-review 착수 baseline

측정: 2026-09-22 · HEAD `c685945a` · `PYTHONDONTWRITEBYTECODE=1` · 리포 루트에서 실행.
판정 기준은 rc 가 아니라 **Pass 수**다 — 이미 RED 인 파일 안의 새 실패는 rc 로 안 보인다.
「새 RED 0」(AC23)은 이 표의 Pass 수가 어느 줄에서도 **줄지 않았음**을 뜻한다.

| 파일 | rc | 결과 |
|---|---|---|
| `plugins/quality-gates/tests/test_adversarial_model_consistency.sh` | 0 | Total: 5 | Pass: 5 | Fail: 0 |
| `plugins/quality-gates/tests/test_adversarial_persona.sh` | 0 | Total: 16 | Pass: 16 | Fail: 0 |
| `plugins/quality-gates/tests/test_agent_color.sh` | 0 | (Total 줄 없음) |
| `plugins/quality-gates/tests/test_agent_frontmatter_keys.sh` | 0 | (Total 줄 없음) |
| `plugins/quality-gates/tests/test_agent_model_mutation.sh` | 0 | Total: 47 | Pass: 47 | Fail: 0 |
| `plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh` | 0 | Total: 2 | Pass: 2 | Fail: 0 |
| `plugins/quality-gates/tests/test_agent_tools_lock_differential.sh` | 0 | Total: 92 | Pass: 92 | Fail: 0 |
| `plugins/quality-gates/tests/test_agent_tools_lock_mutation.sh` | 0 | Total: 85 | Pass: 85 | Fail: 0 |
| `plugins/quality-gates/tests/test_artifact_adversarial_frontmatter.sh` | 0 | Total: 10 | Pass: 10 | Fail: 0 |
| `plugins/quality-gates/tests/test_artifact_bounds.sh` | 0 | Total: 16 | Pass: 16 | Fail: 0 |
| `plugins/quality-gates/tests/test_artifact_branch_guard.sh` | 0 | Total: 7 | Pass: 7 | Fail: 0 |
| `plugins/quality-gates/tests/test_artifact_codex_reviewer.sh` | 0 | Total: 15 | Pass: 15 | Fail: 0 |
| `plugins/quality-gates/tests/test_artifact_commit.sh` | 0 | Total: 12 | Pass: 12 | Fail: 0 |
| `plugins/quality-gates/tests/test_artifact_critic_frontmatter.sh` | 0 | Total: 9 | Pass: 9 | Fail: 0 |
| `plugins/quality-gates/tests/test_artifact_metadata.sh` | 0 | Total: 6 | Pass: 6 | Fail: 0 |
| `plugins/quality-gates/tests/test_artifact_path_auth.sh` | 0 | Total: 4, PASS=4, FAIL=0 |
| `plugins/quality-gates/tests/test_baseline_cache.sh` | 0 | Total: 25 | Pass: 25 | Fail: 0 |
| `plugins/quality-gates/tests/test_branch_worktree.sh` | 0 | Total: 19 | Pass: 19 | Fail: 0 |
| `plugins/quality-gates/tests/test_build_codex_prompt.sh` | 0 | Total: 8 | Pass: 8 | Fail: 0 |
| `plugins/quality-gates/tests/test_build_pr_context.sh` | 0 | Total: 7 | Pass: 7 | Fail: 0 |
| `plugins/quality-gates/tests/test_cancel_all_fence.sh` | 0 | Total: 7 | Pass: 7 | Fail: 0 |
| `plugins/quality-gates/tests/test_cancel_qg.sh` | 0 | (Total 줄 없음) |
| `plugins/quality-gates/tests/test_cancel_qg_med4.sh` | 0 | (Total 줄 없음) |
| `plugins/quality-gates/tests/test_check_allowed_tools_order.sh` | 0 | (Total 줄 없음) |
| `plugins/quality-gates/tests/test_check_review_scope.sh` | 0 | Total: 10 | Pass: 10 | Fail: 0 |
| `plugins/quality-gates/tests/test_check_trivia.sh` | 0 | Total: 6, PASS=6, FAIL=0 |
| `plugins/quality-gates/tests/test_classify_artifact_target.sh` | 0 | Total: 12 | Pass: 12 | Fail: 0 |
| `plugins/quality-gates/tests/test_codex_backward_compat.sh` | 1 | Total: 4, pass: 3, fail: 1 |
| `plugins/quality-gates/tests/test_codex_copies_agree.sh` | 0 | Total: 77 | Pass: 77 | Fail: 0 |
| `plugins/quality-gates/tests/test_codex_dispatch_invariant.sh` | 0 | Total: 5 | Pass: 5 | Fail: 0 |
| `plugins/quality-gates/tests/test_codex_extractor_positive_marker.sh` | 0 | (Total 줄 없음) |
| `plugins/quality-gates/tests/test_codex_gate_observation.sh` | 0 | Total: 27 | Pass: 27 | Fail: 0 |
| `plugins/quality-gates/tests/test_codex_invocation_contract.sh` | 0 | Total: 39 | Pass: 39 | Fail: 0 |
| `plugins/quality-gates/tests/test_codex_prompt_untrusted_clause.sh` | 0 | Total: 43 | Pass: 43 | Fail: 0 |
| `plugins/quality-gates/tests/test_codex_result_banner.sh` | 0 | Total: 5 | Pass: 5 | Fail: 0 |
| `plugins/quality-gates/tests/test_codex_reviewer_frontmatter.sh` | 0 | (Total 줄 없음) |
| `plugins/quality-gates/tests/test_codex_runner_degrade_contract.sh` | 0 | Total: 33 | Pass: 33 | Fail: 0 |
| `plugins/quality-gates/tests/test_codex_runner_no_effort_pin.sh` | 0 | Total: 11 | Pass: 11 | Fail: 0 |
| `plugins/quality-gates/tests/test_compute_test_scope_candidates.sh` | 0 | Total: 10 | Pass: 10 | Fail: 0 |
| `plugins/quality-gates/tests/test_cost_consent.sh` | 0 | Total: 2, pass: 2, fail: 0 |
| `plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh` | 0 | Total: 35 | Pass: 35 | Fail: 0 |
| `plugins/quality-gates/tests/test_detect_codex.sh` | 0 | Total: 17 | Pass: 17 | Fail: 0 |
| `plugins/quality-gates/tests/test_detect_runtime.sh` | 0 | Total: 46 | Pass: 46 | Fail: 0 |
| `plugins/quality-gates/tests/test_diagram_facts.sh` | 0 | Total: 5 | Pass: 5 | Fail: 0 |
| `plugins/quality-gates/tests/test_discover_plan.sh` | 0 | Total: 38 | Pass: 38 | Fail: 0 |
| `plugins/quality-gates/tests/test_discover_spec.sh` | 0 | Total: 26 | Pass: 26 | Fail: 0 |
| `plugins/quality-gates/tests/test_extract_codex_invocations.sh` | 0 | Total: 4 | Pass: 4 | Fail: 0 |
| `plugins/quality-gates/tests/test_failure_injection.sh` | 0 | Total: 5, pass: 5, fail: 0 |
| `plugins/quality-gates/tests/test_findings_parser.sh` | 0 | Total: 16 | Pass: 16 | Fail: 0 |
| `plugins/quality-gates/tests/test_gh_identity.sh` | 0 | Total: 3 | Pass: 3 | Fail: 0 |
| `plugins/quality-gates/tests/test_git_derived_scope.sh` | 0 | (Total 줄 없음) |
| `plugins/quality-gates/tests/test_governance_no_capability_caps.sh` | 0 | Total: 16 | Pass: 16 | Fail: 0 |
| `plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh` | 0 | Total: 250 | Pass: 250 | Fail: 0 |
| `plugins/quality-gates/tests/test_guards_declaration_mapping.sh` | 0 | Total: 8 | Pass: 8 | Fail: 0 |
| `plugins/quality-gates/tests/test_impact_runtime_docs.sh` | 0 | Total: 6 | Pass: 6 | Fail: 0 |
| `plugins/quality-gates/tests/test_isolation.sh` | 0 | Total: 11 | Pass: 11 | Fail: 0 |
| `plugins/quality-gates/tests/test_law2_prose.sh` | 0 | Total: 38 | Pass: 38 | Fail: 0 |
| `plugins/quality-gates/tests/test_no_write_matcher_hooks.sh` | 0 | (Total 줄 없음) |
| `plugins/quality-gates/tests/test_pr_create.sh` | 0 | Total: 6 | Pass: 6 | Fail: 0 |
| `plugins/quality-gates/tests/test_pr_detect.sh` | 0 | Total: 5 | Pass: 5 | Fail: 0 |
| `plugins/quality-gates/tests/test_pr_understanding_builder_frontmatter.sh` | 0 | Total: 24 | Pass: 24 | Fail: 0 |
| `plugins/quality-gates/tests/test_precheck_retired.sh` | 0 | (Total 줄 없음) |
| `plugins/quality-gates/tests/test_publish_degrade.sh` | 0 | Total: 3 | Pass: 3 | Fail: 0 |
| `plugins/quality-gates/tests/test_publish_dry_run_zero_network.sh` | 0 | Total: 1 | Pass: 1 | Fail: 0 |
| `plugins/quality-gates/tests/test_qa_ledger.sh` | 0 | Total: 25 | Pass: 25 | Fail: 0 |
| `plugins/quality-gates/tests/test_qg_critique_routing.sh` | 0 | Total: 5 | Pass: 5 | Fail: 0 |
| `plugins/quality-gates/tests/test_qg_false_clean_floor.sh` | 0 | Total: 4 | Pass: 4 | Fail: 0 |
| `plugins/quality-gates/tests/test_qg_mutation_guard.sh` | 0 | Total: 80 | Pass: 80 | Fail: 0 |
| `plugins/quality-gates/tests/test_qg_pipeline_no_gh.sh` | 0 | Total: 3 | Pass: 3 | Fail: 0 |
| `plugins/quality-gates/tests/test_qg_publish_command.sh` | 0 | Total: 4 | Pass: 4 | Fail: 0 |
| `plugins/quality-gates/tests/test_qg_publish_docs.sh` | 0 | Total: 11 | Pass: 11 | Fail: 0 |
| `plugins/quality-gates/tests/test_qg_publish_handoff.sh` | 0 | Total: 9 | Pass: 9 | Fail: 0 |
| `plugins/quality-gates/tests/test_qg_publish_skill_orchestration.sh` | 0 | Total: 6 | Pass: 6 | Fail: 0 |
| `plugins/quality-gates/tests/test_qg_runtime_sandbox.sh` | 0 | Total: 15 | Pass: 15 | Fail: 0 |
| `plugins/quality-gates/tests/test_qg_worktree_helper.sh` | 0 | Total: 18 | Pass: 18 | Fail: 0 |
| `plugins/quality-gates/tests/test_read_frontmatter.sh` | 0 | (Total 줄 없음) |
| `plugins/quality-gates/tests/test_readme_scope_reconcile.sh` | 0 | (Total 줄 없음) |
| `plugins/quality-gates/tests/test_readme_state_diagram_complete.sh` | 0 | (Total 줄 없음) |
| `plugins/quality-gates/tests/test_render_terminal.sh` | 0 | Total: 2 | Pass: 2 | Fail: 0 |
| `plugins/quality-gates/tests/test_resolve_baseline.sh` | 0 | Total: 13 | Pass: 13 | Fail: 0 |
| `plugins/quality-gates/tests/test_review_floor_lock.sh` | 0 | Total: 4 | Pass: 4 | Fail: 0 |
| `plugins/quality-gates/tests/test_review_scope_composition.sh` | 0 | (Total 줄 없음) |
| `plugins/quality-gates/tests/test_run_test_selection.sh` | 0 | Total: 55 | Pass: 55 | Fail: 0 |
| `plugins/quality-gates/tests/test_runner_adapters.sh` | 1 | Total: 53 | Pass: 52 | Fail: 1 |
| `plugins/quality-gates/tests/test_runtime_contract_invariance.sh` | 0 | Total: 28 | Pass: 28 | Fail: 0 |
| `plugins/quality-gates/tests/test_runtime_verdict_precedence.sh` | 0 | Total: 27 | Pass: 27 | Fail: 0 |
| `plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh` | 0 | Total: 22 | Pass: 22 | Fail: 0 |
| `plugins/quality-gates/tests/test_sandbox_enforced.sh` | 0 | Total: 15 | Pass: 15 | Fail: 0 |
| `plugins/quality-gates/tests/test_scout_codex_integration.sh` | 0 | Total: 9, pass: 9, fail: 0 |
| `plugins/quality-gates/tests/test_scout_script.sh` | 0 | Total: 11, PASS=11, FAIL=0 |
| `plugins/quality-gates/tests/test_security_reviewer_kill_switch.sh` | 0 | Total: 13 | Pass: 13 | Fail: 0 |
| `plugins/quality-gates/tests/test_security_reviewer_persona.sh` | 0 | Total: 23 | Pass: 23 | Fail: 0 |
| `plugins/quality-gates/tests/test_session_start_advisor_v2.sh` | 0 | (Total 줄 없음) |
| `plugins/quality-gates/tests/test_setup_qg.sh` | 0 | Total: 20 | Pass: 20 | Fail: 0 |
| `plugins/quality-gates/tests/test_skill_bash_allowlist_narrow.sh` | 0 | (Total 줄 없음) |
| `plugins/quality-gates/tests/test_skill_codex_skip_prose.sh` | 0 | (Total 줄 없음) |
| `plugins/quality-gates/tests/test_skill_drop_notice_consumed.sh` | 0 | Total: 14 | Pass: 14 | Fail: 0 |
| `plugins/quality-gates/tests/test_skill_orchestration.sh` | 0 | Total: 7 | Pass: 7 | Fail: 0 |
| `plugins/quality-gates/tests/test_synthesize_artifact_findings.sh` | 0 | Total: 36 | Pass: 36 | Fail: 0 |
| `plugins/quality-gates/tests/test_synthesize_disposition.sh` | 0 | Total: 11 | Pass: 11 | Fail: 0 |
| `plugins/quality-gates/tests/test_synthesize_findings.sh` | 0 | Total: 19, PASS=19, FAIL=0 |
| `plugins/quality-gates/tests/test_synthesize_promoted_findings.sh` | 0 | Total: 19 | Pass: 19 | Fail: 0 |
| `plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh` | 0 | Total: 17 | Pass: 17 | Fail: 0 |
| `plugins/quality-gates/tests/test_worktree.sh` | 0 | Total: 15 | Pass: 15 | Fail: 0 |
| `plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh` | 0 | Total: 15 | Pass: 15 | Fail: 0 |
| `plugins/spec-distill/tests/test_brainstorming_entry.sh` | 0 | (Total 줄 없음) |
| `plugins/spec-distill/tests/test_brief_agents.sh` | 0 | Total: 95 | Pass: 95 | Fail: 0 |
| `plugins/spec-distill/tests/test_brief_bundle.sh` | 0 | (Total 줄 없음) |
| `plugins/spec-distill/tests/test_brief_codex_axes.sh` | 0 | Total: 11 | Pass: 11 | Fail: 0 |
| `plugins/spec-distill/tests/test_brief_inline_blob.sh` | 0 | Total: 21 | Pass: 21 | Fail: 0 |
| `plugins/spec-distill/tests/test_brief_no_length_cap.sh` | 0 | Total: 21 | Pass: 21 | Fail: 0 |
| `plugins/spec-distill/tests/test_brief_no_statement_cap.sh` | 0 | (Total 줄 없음) |
| `plugins/spec-distill/tests/test_brief_review_entry.sh` | 0 | Total: 41 | Pass: 41 | Fail: 0 |
| `plugins/spec-distill/tests/test_brief_review_meta.sh` | 0 | Total: 40 | Pass: 40 | Fail: 0 |
| `plugins/spec-distill/tests/test_brief_review_ng3.sh` | 0 | Total: 21 | Pass: 21 | Fail: 0 |
| `plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh` | 0 | Total: 6 | Pass: 6 | Fail: 0 |
| `plugins/spec-distill/tests/test_check_brief.sh` | 0 | Total: 213 | Pass: 213 | Fail: 0 |
| `plugins/spec-distill/tests/test_check_seed.sh` | 0 | Total: 6 | Pass: 6 | Fail: 0 |
| `plugins/spec-distill/tests/test_check_verbatim_coverage.sh` | 0 | Total: 54 | Pass: 54 | Fail: 0 |
| `plugins/spec-distill/tests/test_compression_adopters.sh` | 0 | Total: 7 | Pass: 7 | Fail: 0 |
| `plugins/spec-distill/tests/test_conducting_interview_internal.sh` | 0 | Total: 6 | Pass: 6 | Fail: 0 |
| `plugins/spec-distill/tests/test_conducting_interview_stage.sh` | 0 | Total: 221 | Pass: 221 | Fail: 0 |
| `plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh` | 0 | Total: 16 | Pass: 16 | Fail: 0 |
| `plugins/spec-distill/tests/test_detect_codex.sh` | 0 | Total: 16 | Pass: 16 | Fail: 0 |
| `plugins/spec-distill/tests/test_dispatch_profile_inline.sh` | 0 | Total: 69 | Pass: 69 | Fail: 0 |
| `plugins/spec-distill/tests/test_framing_review_contract.sh` | 0 | Total: 174 | Pass: 174 | Fail: 0 |
| `plugins/spec-distill/tests/test_handoff_context_empty_subsections.sh` | 0 | Total: 3 | Pass: 3 | Fail: 0 |
| `plugins/spec-distill/tests/test_handoff_context_section_required.sh` | 0 | Total: 5 | Pass: 5 | Fail: 0 |
| `plugins/spec-distill/tests/test_handoff_conversation_reference.sh` | 0 | Total: 2 | Pass: 2 | Fail: 0 |
| `plugins/spec-distill/tests/test_handoff_design_mode.sh` | 0 | Total: 9 | Pass: 9 | Fail: 0 |
| `plugins/spec-distill/tests/test_handoff_kill_switch.sh` | 0 | Total: 5 | Pass: 5 | Fail: 0 |
| `plugins/spec-distill/tests/test_hooks.sh` | 0 | Total: 2 | Pass: 2 | Fail: 0 |
| `plugins/spec-distill/tests/test_kill_switches_v060.sh` | 0 | Total: 6 | Pass: 6 | Fail: 0 |
| `plugins/spec-distill/tests/test_no_wall_clock.sh` | 0 | Total: 34 | Pass: 34 | Fail: 0 |
| `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh` | 1 | (Total 줄 없음) |
| `plugins/spec-distill/tests/test_probe_sweep_residue.sh` | 0 | Total: 4 | Pass: 4 | Fail: 0 |
| `plugins/spec-distill/tests/test_proceed_gate_adopters.sh` | 0 | Total: 16 | Pass: 16 | Fail: 0 |
| `plugins/spec-distill/tests/test_readme_sync.sh` | 0 | Total: 38 | Pass: 38 | Fail: 0 |
| `plugins/spec-distill/tests/test_request_framing_command.sh` | 0 | Total: 41 | Pass: 41 | Fail: 0 |
| `plugins/spec-distill/tests/test_rereview_cap_consistency.sh` | 0 | Total: 6 | Pass: 6 | Fail: 0 |
| `plugins/spec-distill/tests/test_review_handoff_order.sh` | 0 | Total: 20 | Pass: 20 | Fail: 0 |
| `plugins/spec-distill/tests/test_reviewing_brief_critic_select.sh` | 0 | Total: 35 | Pass: 35 | Fail: 0 |
| `plugins/spec-distill/tests/test_reviewing_brief_residue.sh` | 0 | Total: 74 | Pass: 74 | Fail: 0 |
| `plugins/spec-distill/tests/test_reviewing_brief_skill.sh` | 0 | Total: 125 | Pass: 125 | Fail: 0 |
| `plugins/spec-distill/tests/test_reviewing_spec_design_only.sh` | 0 | Total: 16 | Pass: 16 | Fail: 0 |
| `plugins/spec-distill/tests/test_reviewing_spec_disclosure.sh` | 0 | Total: 10 | Pass: 10 | Fail: 0 |
| `plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh` | 0 | Total: 168 | Pass: 168 | Fail: 0 |
| `plugins/spec-distill/tests/test_reviewing_spec_residue.sh` | 0 | Total: 45 | Pass: 45 | Fail: 0 |
| `plugins/spec-distill/tests/test_reviewing_spec_state_keying.sh` | 0 | Total: 9 | Pass: 9 | Fail: 0 |
| `plugins/spec-distill/tests/test_seed_agents.sh` | 0 | Total: 8 | Pass: 8 | Fail: 0 |
| `plugins/spec-distill/tests/test_seed_at_path_handoff.sh` | 0 | Total: 77 | Pass: 77 | Fail: 0 |
| `plugins/spec-distill/tests/test_seed_codex_axes.sh` | 0 | Total: 12 | Pass: 12 | Fail: 0 |
| `plugins/spec-distill/tests/test_seed_edit_diff.sh` | 0 | Total: 63 | Pass: 63 | Fail: 0 |
| `plugins/spec-distill/tests/test_seed_gate_wiring.sh` | 0 | Total: 31 | Pass: 31 | Fail: 0 |
| `plugins/spec-distill/tests/test_seed_inline_blob.sh` | 0 | Total: 51 | Pass: 51 | Fail: 0 |
| `plugins/spec-distill/tests/test_seed_input_provenance.sh` | 0 | Total: 17 | Pass: 17 | Fail: 0 |
| `plugins/spec-distill/tests/test_seed_one_sentence.sh` | 0 | Total: 3 | Pass: 3 | Fail: 0 |
| `plugins/spec-distill/tests/test_seed_provenance.sh` | 0 | Total: 81 | Pass: 81 | Fail: 0 |
| `plugins/spec-distill/tests/test_seed_review_log.sh` | 0 | Total: 95 | Pass: 95 | Fail: 0 |
| `plugins/spec-distill/tests/test_seed_review_profile.sh` | 0 | Total: 4 | Pass: 4 | Fail: 0 |
| `plugins/spec-distill/tests/test_session_id_resolution.sh` | 0 | Total: 17 | Pass: 17 | Fail: 0 |
| `plugins/spec-distill/tests/test_skepticism_module.sh` | 0 | Total: 27 | Pass: 27 | Fail: 0 |
| `plugins/spec-distill/tests/test_stale_terms.sh` | 0 | Total: 75 | Pass: 75 | Fail: 0 |
| `plugins/spec-distill/tests/test_state_path.sh` | 0 | Total: 3 | Pass: 3 | Fail: 0 |
| `plugins/spec-distill/tests/test_steelman_builder_scope.sh` | 0 | Total: 56 | Pass: 56 | Fail: 0 |
| `plugins/spec-distill/tests/test_web_kill_switch.sh` | 0 | Total: 51 | Pass: 51 | Fail: 0 |
| `shared/tests/test_adjudication_behavior.sh` | 0 | Total: 24 | Pass: 24 | Fail: 0 |
| `shared/tests/test_adjudication_consumed.sh` | 0 | Total: 6 | Pass: 6 | Fail: 0 |
| `shared/tests/test_adjudication_wiring.sh` | 0 | Total: 17 | Pass: 17 | Fail: 0 |
| `shared/tests/test_agent_input_slots.sh` | 0 | Total: 14 | Pass: 14 | Fail: 0 |
| `shared/tests/test_assert_behavior.sh` | 0 | Total: 32 | Pass: 32 | Fail: 0 |
| `shared/tests/test_changelog_integrity.sh` | 0 | Total: 27 | Pass: 27 | Fail: 0 |
| `shared/tests/test_codex_runner_scratch_trap_order.sh` | 0 | Total: 17 | Pass: 17 | Fail: 0 |
| `shared/tests/test_copy_of_contract.sh` | 0 | Total: 188 | Pass: 188 | Fail: 0 |
| `shared/tests/test_dispatch_disposition.sh` | 0 | Total: 19 | Pass: 19 | Fail: 0 |
| `shared/tests/test_dispatch_name_defined.sh` | 0 | Total: 6 | Pass: 6 | Fail: 0 |
| `shared/tests/test_docreview_agents.sh` | 0 | Total: 36 | Pass: 36 | Fail: 0 |
| `shared/tests/test_docreview_anchor.sh` | 0 | Total: 18 | Pass: 18 | Fail: 0 |
| `shared/tests/test_docreview_codex.sh` | 0 | Total: 270 | Pass: 270 | Fail: 0 |
| `shared/tests/test_docreview_gate_visibility.sh` | 0 | Total: 46 | Pass: 46 | Fail: 0 |
| `shared/tests/test_docreview_golden.sh` | 0 | Total: 11 | Pass: 11 | Fail: 0 |
| `shared/tests/test_docreview_intent.sh` | 0 | Total: 26 | Pass: 26 | Fail: 0 |
| `shared/tests/test_docreview_mutations.sh` | 0 | Total: 65 | Pass: 65 | Fail: 0 |
| `shared/tests/test_docreview_procedure_paths.sh` | 0 | Total: 48 | Pass: 48 | Fail: 0 |
| `shared/tests/test_docreview_profile_schema.sh` | 0 | Total: 31 | Pass: 31 | Fail: 0 |
| `shared/tests/test_docreview_profiles.sh` | 0 | Total: 51 | Pass: 51 | Fail: 0 |
| `shared/tests/test_docreview_round_gate_split.sh` | 0 | Total: 10 | Pass: 10 | Fail: 0 |
| `shared/tests/test_docreview_route.sh` | 0 | Total: 149 | Pass: 149 | Fail: 0 |
| `shared/tests/test_docreview_state.sh` | 0 | Total: 172 | Pass: 172 | Fail: 0 |
| `shared/tests/test_no_new_duplication.sh` | 0 | Total: 3 | Pass: 3 | Fail: 0 |
| `shared/tests/test_plugin_root_no_cwd_fallback.sh` | 0 | Total: 27 | Pass: 27 | Fail: 0 |
| `shared/tests/test_presence_corpus_behavior.sh` | 0 | Total: 21 | Pass: 21 | Fail: 0 |
| `shared/tests/test_runner_disposition.sh` | 0 | Total: 27 | Pass: 27 | Fail: 0 |
| `shared/tests/test_skill_body_no_positional_tokens.sh` | 0 | Total: 6 | Pass: 6 | Fail: 0 |
| `shared/tests/test_skill_reference_pointers.sh` | 0 | Total: 38 | Pass: 38 | Fail: 0 |
| `shared/tests/test_variant_of_contract.sh` | 0 | Total: 87 | Pass: 87 | Fail: 0 |

## 선재 RED — 이 변경의 것이 아니다

| 파일 | Fail | 왜 이미 RED 인가 (실행으로 확인한 사유) |
|---|---|---|
| `plugins/quality-gates/tests/test_runner_adapters.sh` | 1 | `case_qg_test_scripts_are_executable` 가 실패: `plugins/quality-gates/tests/test_cancel_all_fence.sh` 가 "비실행 커밋 모드"(git tree mode `100644`, 실행비트 없음)로 커밋돼 있어 셸 어댑터가 그 파일을 claim 할 수 없다 — unclaimed → PASS 불가. `origin/main` 에서 같은 blob(`18c581e9`)·같은 mode 를 재확인했다 — 이 브랜치가 만든 회귀가 아니다. |
| `plugins/quality-gates/tests/test_codex_backward_compat.sh` | 1 | 이 스위트가 내부에서 `test_runner_adapters.sh` 를 재실행해 "제외 목록에 없는 새 실패"를 감시한다. `test_runner_adapters.sh` 의 위 실패가 제외 목록에 미등재라 `FAIL: 예상 밖 실패 → test_runner_adapters.sh(미등재)` 로 전파된다 — 근본 원인은 위 행과 동일(같은 실행비트 문제), 독립된 결함이 아니다. |
| `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh` | 1 | `✗ 양성 대조 실패: Bash matcher 훅이 1개뿐` — 이 스위트의 양성 대조(positive control)가 리포 전체에서 matcher 붙은 `Bash` PostToolUse 훅을 최소 2개 기대하는데 현재 1개만 존재해서 대조 자체가 무너진다. 세 파일 중 유일하게 위 실행비트 문제와 무관한 별도의 선재 RED — 원인은 훅 인벤토리 쪽이며 이 계획의 착수 시점보다 앞서 존재한다(측정 스크립트가 새로 만든 것이 아니다).
