# AC7 Baseline — Aspirational (Deferred)

## Status

AC7 (byte-identical synthesizer output between codex-disabled and pre-feature state) is **aspirational** for the qg-codex-reviewer feature. No baseline fixtures captured.

Verification relies instead on:

- **AC1 case 3** (`DEVBREW_QUALITY_GATES_DISABLE_CODEX=1` returns `skip_reason: kill_switch`)
- **AC2** (scout omits `codex-reviewer` from `phase1_agents` when `codex_available: false`)
- **Existing qg test suite** continues to pass unchanged (Task 10 structural regression + Task 11 final review)

## Rationale

The qg-codex-reviewer plan's Task 1 originally required capturing byte-identical synthesizer output across 3 representative diffs. Discovery during execution:

1. **No unattended `/qg` harness exists.** `tests/e2e-scenarios.md` explicitly states: *"Live `/qg` runs require an interactive Claude Code session against a real PR."* All current e2e verification is manual.

2. **Synthesizer output is inherently non-deterministic** (LLM-generated YAML). Byte-identity assertions would either fail constantly or require ignoring so many fields that the test becomes vacuous.

3. **The feature is purely additive + opt-in.** When `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1` or codex is not installed, no new code paths execute. The structural checks above provide sufficient regression evidence without the harness investment.

Spec §AC7 explicitly anticipated this case: *"baseline 부재 시 AC7는 'aspirational — baseline must be captured first'로 표기"*. This README documents the escape clause being exercised.

## Future: Manual Baseline Procedure

If a user wants stronger regression evidence in the future:

1. Check out a commit *before* `feature/qg-codex-reviewer` lands (e.g., `main` at the time of feature merge).
2. On 3 representative PRs (small/medium/large diff), run interactively:
   ```bash
   DEVBREW_QUALITY_GATES_DISABLE_CODEX=1 /qg
   ```
   Save the synthesizer YAML output from each session.
3. Write a small `normalize_qg_output.py` that strips non-deterministic fields (timestamps, session_ids, paths) via regex.
4. Save fixtures as `baseline_synthesizer_{small,medium,large}.yaml` next to this README.
5. After the feature lands, re-run `/qg` with `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1` on the same 3 PRs and diff against fixtures. Expect identity (modulo normalize).

## See Also

- Plan: `docs/superpowers/plans/2026-05-13-qg-codex-reviewer.md` Task 1 (revised) + Task 10 (revised)
- Spec: `docs/superpowers/specs/2026-05-13-qg-codex-reviewer-design.md` §AC7
- Pre-existing manual e2e doc: `plugins/quality-gates/tests/e2e-scenarios.md`
