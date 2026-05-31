# Project Charter Surface (project-init v1.6.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Project Charter surface to the `project-init` plugin (v1.6.0) — a fact-routing lightweight interview step in `/project-init` that elicits the project's durable definition (vision · non-goals · tech-stack · conventions · optional glossary) and publishes it to `AGENTS.md ## Project Charter` (summary) + `docs/project/charter.md`·`conventions.md` (+ conditional `glossary.md`), with the existing `docs-lint.py` hook extended (no new hook) to validate it.

**Architecture:** Three coordinated changes shipped in one PR. (1) The deterministic, testable core is a `docs-lint.py` extension: an additive `is_charter_doc()` predicate that makes `docs/project/*.md` lint targets (existing 4-path exact-set untouched, C10) plus a new heading-bounded `## Project Charter` integrity rule on `AGENTS.md`. (2) Four static template skeletons under `templates/project/`. (3) The `/project-init` command markdown gains charter detection (Step 1), a Phase 0 fact-discovery + Phase 1 ≤4-question step (Step 3.5), charter publication with an idempotent state matrix (Step 4), and a confirmation update (Step 5). Per C11 the command is LLM-executed markdown with no command-flow unit tests, so TDD discipline targets the hook + templates; the command is verified by a numbered manual checklist.

**Tech Stack:** Python 3 stdlib only (`json`/`os`/`re`/`sys`/`pathlib` — C1, no external deps), `unittest` for hook tests, bash 3.2-compatible `smoke.sh`, Markdown for command/templates/docs.

---

## File Structure

**Create:**
- `plugins/project-init/templates/project/agents-md-section.md` — `## Project Charter` summary skeleton (the labels the hook greps for).
- `plugins/project-init/templates/project/charter.md` — charter detail skeleton (fixed `##` headings, AC5).
- `plugins/project-init/templates/project/conventions.md` — conventions detail skeleton (fixed `##` headings, AC6).
- `plugins/project-init/templates/project/glossary.md` — glossary skeleton (conditional publish, AC7).
- `plugins/project-init/hooks/tests/fixtures/charter_complete/` — smoke fixture (clean → `{}`).
- `plugins/project-init/hooks/tests/fixtures/charter_missing_subsection/` — smoke fixture (missing label → `systemMessage`).
- `plugins/project-init/hooks/tests/fixtures/charter_placeholder_residue/` — smoke fixture (`{{...}}` residue → `systemMessage`).
- `plugins/project-init/hooks/tests/fixtures/charter_doc_target/` — smoke fixture (oversized `docs/project/charter.md` → `systemMessage`, proves the new target is linted).

**Modify:**
- `plugins/project-init/hooks/docs-lint.py` — `is_charter_doc()` predicate, `resolve_target_path()` OR-extension, `check_r_charter()` rule, `main()` wiring, module docstring.
- `plugins/project-init/hooks/tests/test_docs_lint.py` — `TestCharterTarget` + `TestRCharter` + `TestTemplateConsistency` classes.
- `plugins/project-init/hooks/tests/smoke.sh` — `TARGETS` parallel array + 4 new fixtures.
- `plugins/project-init/commands/project-init.md` — Step 1 detection, Step 3.5 charter flow, Step 4 publish + matrix, Step 5 confirmation.
- `plugins/project-init/.claude-plugin/plugin.json` — version `1.5.0`→`1.6.0`, description.
- `plugins/project-init/CHANGELOG.md` — `[1.6.0] — 2026-05-31` Added.
- `plugins/project-init/README.md` — architecture tree, 동작 방식, 기능, Hooks, Principles Instantiated.

---

## Task 1: docs-lint.py — charter target predicate + `## Project Charter` integrity rule (TDD)

**Files:**
- Modify: `plugins/project-init/hooks/docs-lint.py`
- Test: `plugins/project-init/hooks/tests/test_docs_lint.py`

This is the deterministic core. Resolves deferred items: `is_charter_doc()` implementation (string prefix/suffix, not `Path` relationship) and the `## Project Charter` heading-bounded parsing regex.

- [ ] **Step 1: Write the failing tests**

Append these two classes to `plugins/project-init/hooks/tests/test_docs_lint.py` (before the trailing `if __name__ == "__main__":` block):

```python
class TestCharterTarget(unittest.TestCase):
    """C10/AC11: docs/project/*.md become additive lint targets; the existing
    4-path exact-set membership is untouched (regression-free)."""

    def test_charter_doc_is_linted(self):
        """AC11: an oversized docs/project/charter.md now reaches the rule layer
        (proves it is a recognized target) and R1 fires."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "docs" / "project" / "charter.md"
            target.parent.mkdir(parents=True)
            target.write_text("\n".join(f"line {i}" for i in range(250)) + "\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("Anthropic recommends", out)
            self.assertEqual(rc, 0)

    def test_charter_doc_clean_passes(self):
        """A clean docs/project/conventions.md → {}."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "docs" / "project" / "conventions.md"
            target.parent.mkdir(parents=True)
            target.write_text("# Conventions\n\n## Naming\n\nkebab-case.\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)

    def test_non_charter_docs_path_not_targeted(self):
        """C10 boundary: docs/other.md (not under docs/project/) stays a non-target
        even when oversized → {}."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "docs" / "other.md"
            target.parent.mkdir(parents=True)
            target.write_text("\n".join(f"line {i}" for i in range(250)) + "\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)

    def test_lookalike_prefix_not_targeted(self):
        """C10 boundary: docs/projectile/x.md must NOT match the docs/project/ prefix."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "docs" / "projectile" / "x.md"
            target.parent.mkdir(parents=True)
            target.write_text("\n".join(f"line {i}" for i in range(250)) + "\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)


class TestRCharter(unittest.TestCase):
    """AC11: AGENTS.md '## Project Charter' required-subsection integrity
    (heading-bounded; Vision / Non-goals / Tech Stack)."""

    def _agents_with_charter(self, vision: str, nongoals: str, tech: str) -> str:
        return (
            "# Project AGENTS\n\n"
            "## Project Charter\n\n"
            f"**Vision:** {vision}\n\n"
            f"**Non-goals:** {nongoals}\n\n"
            f"**Tech Stack:** {tech}\n\n"
            "상세: [charter](docs/project/charter.md)\n\n"
            "## Git Workflow\n\nGitHub Flow.\n"
        )

    def test_complete_charter_passes(self):
        """All three labels filled → no charter advisory."""
        with tempfile.TemporaryDirectory() as td:
            # Make the docs/project pointer resolve so R6 stays quiet.
            cdir = Path(td) / "docs" / "project"
            cdir.mkdir(parents=True)
            (cdir / "charter.md").write_text("# Charter\n")
            target = Path(td) / "AGENTS.md"
            target.write_text(self._agents_with_charter(
                "Ship a fast static-site generator.",
                "No CMS, no plugins runtime.",
                "Go 1.22, Hugo.",
            ))
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("Project Charter' section is incomplete", out)
            self.assertEqual(rc, 0)

    def test_missing_label_warns(self):
        """A required label absent → charter advisory naming it."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# A\n\n## Project Charter\n\n"
                "**Vision:** Ship it.\n\n"
                "**Tech Stack:** Go.\n\n"  # Non-goals label missing
                "## Git Workflow\n\nx\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("section is incomplete", out)
            self.assertIn("Non-goals (label missing)", out)
            self.assertEqual(rc, 0)

    def test_empty_value_warns(self):
        """A label present but value empty → 'empty' advisory."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(self._agents_with_charter("Ship it.", "", "Go."))
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("section is incomplete", out)
            self.assertIn("Non-goals (empty)", out)
            self.assertEqual(rc, 0)

    def test_placeholder_residue_warns(self):
        """An unfilled {{...}} placeholder → 'placeholder' advisory (AC11 iii)."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(self._agents_with_charter("{{VISION}}", "No CMS.", "Go."))
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("section is incomplete", out)
            self.assertIn("Vision", out)
            self.assertIn("placeholder", out)
            self.assertEqual(rc, 0)

    def test_no_charter_section_no_op(self):
        """AGENTS.md without a '## Project Charter' section → rule no-ops (a
        git-workflow-only AGENTS.md must not be falsely flagged)."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text("# A\n\n## Git Workflow\n\nGitHub Flow.\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)

    def test_charter_rule_only_on_agents(self):
        """The charter rule fires only for AGENTS.md basename — a CLAUDE.md that
        happens to contain a '## Project Charter' heading is not charter-linted."""
        with tempfile.TemporaryDirectory() as td:
            # AGENTS.md present (pair) so R-pointer doesn't dominate the assertion.
            (Path(td) / "AGENTS.md").write_text("# canonical\n")
            target = Path(td) / "CLAUDE.md"
            target.write_text(
                "# C\n\n## Project Charter\n\n**Vision:**\n\n"  # empty, but not AGENTS.md
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("section is incomplete", out)
            self.assertEqual(rc, 0)

    def test_charter_doc_not_charter_linted(self):
        """docs/project/charter.md uses ## Vision etc. — it must NOT be subjected
        to the AGENTS.md '## Project Charter' subsection rule."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "docs" / "project" / "charter.md"
            target.parent.mkdir(parents=True)
            target.write_text("# Charter\n\n## Vision\n\nShip it.\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("section is incomplete", out)
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)

    def test_kill_switch_silences_charter(self):
        """AC12: DEVBREW_SKIP_HOOKS=project-init:docs-lint silences the charter rule
        with no new kill-switch token."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(self._agents_with_charter("{{VISION}}", "", "Go."))
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
                env_override={"DEVBREW_SKIP_HOOKS": "project-init:docs-lint"},
            )
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `python3 plugins/project-init/hooks/tests/test_docs_lint.py -v`
Expected: FAIL — `TestCharterTarget.test_charter_doc_is_linted` and `test_charter_doc_clean_passes` fail (docs/project paths currently return `{}` because they are not yet targets — so `test_charter_doc_is_linted` gets `{}` instead of the R1 message), and all `TestRCharter` charter-advisory assertions fail (rule does not exist yet). The boundary/no-op tests (`test_non_charter_docs_path_not_targeted`, `test_no_charter_section_no_op`, etc.) already pass.

- [ ] **Step 3: Implement the predicate, target extension, and rule**

In `plugins/project-init/hooks/docs-lint.py`, update the module docstring (lines 2–8) to reflect the extension:

```python
"""PostToolUse hook for project-init plugin — agent-readable docs convention validator.

Validates root context files (CLAUDE.md, AGENTS.md, .claude/CLAUDE.md, .claude/AGENTS.md)
and project charter detail docs (docs/project/*.md) against deterministic rules:
R1 size, R2 TOC, R5 fenced code language, R6 internal links resolve,
R-pointer CLAUDE/AGENTS drift, R-charter AGENTS.md '## Project Charter' integrity.

Non-blocking advisory pattern: outputs systemMessage on violation, {} on pass.
"""
```

Add the `is_charter_doc()` predicate immediately above `resolve_target_path()` (after the `safe_resolve` function, before line 59):

```python
def is_charter_doc(rel_posix: str) -> bool:
    """C10/AC11: charter detail docs under docs/project/ are additive lint targets.

    A pure string predicate (prefix + suffix), OR'd into resolve_target_path
    alongside the unchanged TARGET_RELPATHS exact-set. Using string membership
    rather than a Path relationship keeps the existing 4-path exact-match
    guarantee byte-identical (regression-free, C10).
    """
    return rel_posix.startswith("docs/project/") and rel_posix.endswith(".md")
```

In `resolve_target_path()`, replace the exact-set membership check (current lines 77–79):

```python
    if rel.as_posix() not in TARGET_RELPATHS:
        return None
    return abs_path
```

with the additive form:

```python
    rel_posix = rel.as_posix()
    if rel_posix not in TARGET_RELPATHS and not is_charter_doc(rel_posix):
        return None
    return abs_path
```

Add the charter rule constants + functions immediately after `check_r_pointer()` (after current line 364, before `def main()`):

```python
# R-charter — AGENTS.md '## Project Charter' required-subsection integrity (AC11).
# The section is heading-bounded: from the '## Project Charter' line up to (but
# not including) the next level-2 heading or EOF. Within it, three labels are
# required, each non-empty and free of unfilled {{...}} placeholders. The label
# strings MUST stay in sync with templates/project/agents-md-section.md
# (locked by TestTemplateConsistency).
CHARTER_SECTION_RE = re.compile(
    r"^##\s+Project Charter\s*$\n?(.*?)(?=^##\s|\Z)",
    re.MULTILINE | re.DOTALL,
)
CHARTER_PLACEHOLDER_RE = re.compile(r"\{\{.*?\}\}")
CHARTER_REQUIRED_LABELS = ("Vision", "Non-goals", "Tech Stack")


def _charter_field(section_body: str, label: str) -> Optional[str]:
    """Return the trimmed value after a ``**<label>:**`` line in the section body,
    or None if the label line is absent."""
    m = re.search(rf"^\*\*{re.escape(label)}:\*\*[ \t]*(.*)$", section_body, re.MULTILINE)
    if m is None:
        return None
    return m.group(1).strip()


def check_r_charter(target: Path, rel_display: str) -> Optional[str]:
    """AC11: validate the AGENTS.md '## Project Charter' summary section.

    Fires only for an AGENTS.md target that actually contains a
    '## Project Charter' section (so git-workflow-only AGENTS.md files and
    charter detail docs are unaffected). For each required label flags:
    (i) label absent, (ii) empty value, (iii) {{...}} placeholder residue.
    """
    if target.name != "AGENTS.md":
        return None
    try:
        content = target.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        print(f"[project-init:docs-lint] could not read {rel_display} — skipping R-charter", file=sys.stderr)
        return None
    sec = CHARTER_SECTION_RE.search(content)
    if sec is None:
        return None  # no charter section → nothing to validate
    body = sec.group(1)
    problems: list[str] = []
    for label in CHARTER_REQUIRED_LABELS:
        val = _charter_field(body, label)
        if val is None:
            problems.append(f"{label} (label missing)")
        elif not val:
            problems.append(f"{label} (empty)")
        elif CHARTER_PLACEHOLDER_RE.search(val):
            problems.append(f"{label} (unfilled {{{{...}}}} placeholder)")
    if not problems:
        return None
    return (
        f"project-init: {rel_display} '## Project Charter' section is incomplete — "
        f"{', '.join(problems)}. Fill these via `/project-init` (charter step) so the "
        f"project charter inherits cleanly each session."
    )
```

In `main()`, wire the rule in after the R-pointer block (after current lines 408–410):

```python
    msg_rp = check_r_pointer(target, project_dir_path)
    if msg_rp:
        messages.append(msg_rp)
    msg_rc = check_r_charter(target, rel_display)
    if msg_rc:
        messages.append(msg_rc)
```

- [ ] **Step 4: Run the new tests to verify they pass**

Run: `python3 plugins/project-init/hooks/tests/test_docs_lint.py -v`
Expected: PASS — all `TestCharterTarget` and `TestRCharter` tests green.

- [ ] **Step 5: Run the full suite to verify no regression (C10)**

Run: `python3 plugins/project-init/hooks/tests/test_docs_lint.py`
Expected: PASS — `OK`, all pre-existing tests (R1/R2/R5/R6/R-pointer/skeleton/robustness) still green, confirming the 4-path exact-set behavior is unchanged.

- [ ] **Step 6: Commit**

```bash
git add plugins/project-init/hooks/docs-lint.py plugins/project-init/hooks/tests/test_docs_lint.py
git commit -m "feat(project-init): docs-lint charter target + ## Project Charter rule (v1.6.0 AC11/C10)"
```

---

## Task 2: smoke fixtures + smoke.sh extension

**Files:**
- Create: `plugins/project-init/hooks/tests/fixtures/charter_complete/AGENTS.md`
- Create: `plugins/project-init/hooks/tests/fixtures/charter_complete/docs/project/charter.md`
- Create: `plugins/project-init/hooks/tests/fixtures/charter_missing_subsection/AGENTS.md`
- Create: `plugins/project-init/hooks/tests/fixtures/charter_missing_subsection/docs/project/charter.md`
- Create: `plugins/project-init/hooks/tests/fixtures/charter_placeholder_residue/AGENTS.md`
- Create: `plugins/project-init/hooks/tests/fixtures/charter_placeholder_residue/docs/project/charter.md`
- Create: `plugins/project-init/hooks/tests/fixtures/charter_doc_target/docs/project/charter.md`
- Modify: `plugins/project-init/hooks/tests/smoke.sh`

Resolves the smoke-fixture design (deferred item). Note: glossary *absence* (AC7) is a command-flow behavior verified manually in Task 6, not a docs-lint fixture — so there is no `glossary_absent` smoke fixture (it would have nothing to assert at the hook layer).

- [ ] **Step 1: Create the `charter_complete` fixture (expect `{}`)**

`plugins/project-init/hooks/tests/fixtures/charter_complete/AGENTS.md`:

```text
# Demo Project

## Project Charter

**Vision:** Ship a fast static-site generator for small teams.

**Non-goals:** No CMS, no runtime plugin system.

**Tech Stack:** Go 1.22, Hugo.

상세 정의: [`docs/project/charter.md`](docs/project/charter.md)

## Git Workflow

GitHub Flow.
```

`plugins/project-init/hooks/tests/fixtures/charter_complete/docs/project/charter.md` (must exist so the pointer link resolves under R6):

```text
# Project Charter

## Vision

Ship a fast static-site generator for small teams.
```

- [ ] **Step 2: Create the `charter_missing_subsection` fixture (expect `systemMessage`)**

`plugins/project-init/hooks/tests/fixtures/charter_missing_subsection/AGENTS.md` (no `**Non-goals:**` label):

```text
# Demo Project

## Project Charter

**Vision:** Ship a fast static-site generator.

**Tech Stack:** Go 1.22.

상세 정의: [`docs/project/charter.md`](docs/project/charter.md)

## Git Workflow

GitHub Flow.
```

`plugins/project-init/hooks/tests/fixtures/charter_missing_subsection/docs/project/charter.md`:

```text
# Project Charter

## Vision

Ship it.
```

- [ ] **Step 3: Create the `charter_placeholder_residue` fixture (expect `systemMessage`)**

`plugins/project-init/hooks/tests/fixtures/charter_placeholder_residue/AGENTS.md` (`{{VISION}}` left unfilled):

```text
# Demo Project

## Project Charter

**Vision:** {{VISION}}

**Non-goals:** No CMS.

**Tech Stack:** Go 1.22.

상세 정의: [`docs/project/charter.md`](docs/project/charter.md)

## Git Workflow

GitHub Flow.
```

`plugins/project-init/hooks/tests/fixtures/charter_placeholder_residue/docs/project/charter.md`:

```text
# Project Charter

## Vision

Ship it.
```

- [ ] **Step 4: Create the `charter_doc_target` fixture (expect `systemMessage` — proves docs/project/*.md is linted)**

Create `plugins/project-init/hooks/tests/fixtures/charter_doc_target/docs/project/charter.md` as an oversized (>200 line) file so R1 fires, proving the new target is reached. Generate it deterministically:

Run:
```bash
mkdir -p plugins/project-init/hooks/tests/fixtures/charter_doc_target/docs/project
{
  echo "# Project Charter"
  echo ""
  echo "## Vision"
  echo ""
  for i in $(seq 1 250); do echo "line $i"; done
} > plugins/project-init/hooks/tests/fixtures/charter_doc_target/docs/project/charter.md
```

- [ ] **Step 5: Extend smoke.sh with a `TARGETS` parallel array**

In `plugins/project-init/hooks/tests/smoke.sh`, add the 4 new fixtures to the `FIXTURES` and `EXPECTS` arrays and introduce a `TARGETS` parallel array (empty string = existing AGENTS.md→CLAUDE.md autodetect; non-empty = explicit relative path).

Replace the existing `FIXTURES=( ... )` and `EXPECTS=( ... )` blocks (current lines 16–37) with:

```bash
FIXTURES=(
  valid
  oversized
  strong_oversized
  missing_toc
  bare_fence
  broken_link
  drifted
  proper_pointer
  dangling_pointer
  charter_complete
  charter_missing_subsection
  charter_placeholder_residue
  charter_doc_target
)
EXPECTS=(
  "{}"
  "systemMessage"
  "systemMessage"
  "systemMessage"
  "systemMessage"
  "systemMessage"
  "systemMessage"
  "{}"
  "{}"
  "{}"
  "systemMessage"
  "systemMessage"
  "systemMessage"
)
# TARGETS[i] — relative path within the fixture dir to lint. Empty string keeps
# the legacy AGENTS.md→CLAUDE.md autodetect; non-empty overrides it (charter
# detail docs live at docs/project/*.md).
TARGETS=(
  ""
  ""
  ""
  ""
  ""
  ""
  ""
  ""
  ""
  ""
  ""
  ""
  "docs/project/charter.md"
)
```

Replace the target-resolution lines in the loop (current lines 43–44):

```bash
  target="$FIX/$d/AGENTS.md"
  [ -f "$target" ] || target="$FIX/$d/CLAUDE.md"
```

with:

```bash
  trel="${TARGETS[$i]}"
  if [ -n "$trel" ]; then
    target="$FIX/$d/$trel"
  else
    target="$FIX/$d/AGENTS.md"
    [ -f "$target" ] || target="$FIX/$d/CLAUDE.md"
  fi
```

- [ ] **Step 6: Run smoke.sh to verify it passes**

Run: `bash plugins/project-init/hooks/tests/smoke.sh`
Expected: `V2 PASS` (all 13 fixtures match — the 4 charter fixtures produce their expected `{}` / `systemMessage`).

- [ ] **Step 7: Commit**

```bash
git add plugins/project-init/hooks/tests/fixtures/charter_complete \
        plugins/project-init/hooks/tests/fixtures/charter_missing_subsection \
        plugins/project-init/hooks/tests/fixtures/charter_placeholder_residue \
        plugins/project-init/hooks/tests/fixtures/charter_doc_target \
        plugins/project-init/hooks/tests/smoke.sh
git commit -m "test(project-init): charter smoke fixtures + smoke.sh TARGETS array (v1.6.0 AC16)"
```

---

## Task 3: charter templates + template↔rule consistency test

**Files:**
- Create: `plugins/project-init/templates/project/agents-md-section.md`
- Create: `plugins/project-init/templates/project/charter.md`
- Create: `plugins/project-init/templates/project/conventions.md`
- Create: `plugins/project-init/templates/project/glossary.md`
- Test: `plugins/project-init/hooks/tests/test_docs_lint.py`

The templates are placeholder skeletons (C7 — no opinionated content, AC14). The consistency test locks the `agents-md-section.md` labels to the `CHARTER_REQUIRED_LABELS` the hook greps for, preventing silent label drift.

- [ ] **Step 1: Write the failing consistency test**

Append to `plugins/project-init/hooks/tests/test_docs_lint.py` (before the `if __name__ == "__main__":` block):

```python
class TestTemplateConsistency(unittest.TestCase):
    """Lock the agents-md-section.md template labels to the hook's
    CHARTER_REQUIRED_LABELS so a rename in one place can't silently drift."""

    TEMPLATES = HOOK.parent.parent / "templates" / "project"

    def test_agents_section_template_has_required_labels(self):
        """Each CHARTER_REQUIRED_LABELS entry appears as a bold label in the
        summary template (AC4 ↔ AC11 coupling)."""
        text = (self.TEMPLATES / "agents-md-section.md").read_text(encoding="utf-8")
        for label in ("Vision", "Non-goals", "Tech Stack"):
            self.assertIn(f"**{label}:**", text)

    def test_charter_template_has_fixed_headings(self):
        """AC5: charter.md fixed ## headings."""
        text = (self.TEMPLATES / "charter.md").read_text(encoding="utf-8")
        for h in ("## Vision", "## Goals", "## Non-goals",
                  "## Success Criteria / Definition of Done", "## Personas"):
            self.assertIn(h, text)

    def test_conventions_template_has_fixed_headings(self):
        """AC6: conventions.md fixed ## headings."""
        text = (self.TEMPLATES / "conventions.md").read_text(encoding="utf-8")
        for h in ("## Naming", "## Directory Structure", "## Error Handling",
                  "## Anti-patterns", "## Build & Test"):
            self.assertIn(h, text)
```

- [ ] **Step 2: Run the consistency test to verify it fails**

Run: `python3 plugins/project-init/hooks/tests/test_docs_lint.py -v 2>&1 | grep -i template`
Expected: FAIL with `FileNotFoundError` — `templates/project/agents-md-section.md` (and the others) do not exist yet.

- [ ] **Step 3: Create the four template files**

`plugins/project-init/templates/project/agents-md-section.md` (the `## Project Charter` summary — labels MUST match `CHARTER_REQUIRED_LABELS`; ≤25 lines, C5):

```text
## Project Charter

**Vision:** {{VISION}}

**Non-goals:** {{NON_GOALS}}

**Tech Stack:** {{TECH_STACK}}

상세 정의: [`docs/project/charter.md`](docs/project/charter.md) · [`docs/project/conventions.md`](docs/project/conventions.md)
```

`plugins/project-init/templates/project/charter.md` (AC5 fixed headings):

```text
# Project Charter

> 이 프로젝트의 거의 변하지 않는 정의. `/project-init` charter step이 생성·갱신한다.

## Vision

{{VISION}}

## Goals

{{GOALS}}

## Non-goals

{{NON_GOALS}}

## Success Criteria / Definition of Done

{{SUCCESS_CRITERIA}}

## Personas

{{PERSONAS}}
```

`plugins/project-init/templates/project/conventions.md` (AC6 fixed headings):

```text
# Conventions

> 프로젝트 코딩·구조 컨벤션. `/project-init` charter step이 생성·갱신한다.

## Naming

{{NAMING}}

## Directory Structure

{{DIRECTORY_STRUCTURE}}

## Error Handling

{{ERROR_HANDLING}}

## Anti-patterns

{{ANTI_PATTERNS}}

## Build & Test

{{BUILD_TEST}}
```

`plugins/project-init/templates/project/glossary.md` (AC7 conditional — published only when domain terms are elicited):

```text
# Glossary

> 프로젝트 고유 도메인 용어. Phase 1에서 용어가 elicit된 경우에만 생성된다.

{{GLOSSARY_TERMS}}
```

- [ ] **Step 4: Run the consistency test to verify it passes**

Run: `python3 plugins/project-init/hooks/tests/test_docs_lint.py -v 2>&1 | grep -i template`
Expected: PASS — all three `TestTemplateConsistency` tests green.

- [ ] **Step 5: Commit**

```bash
git add plugins/project-init/templates/project plugins/project-init/hooks/tests/test_docs_lint.py
git commit -m "feat(project-init): charter template skeletons + label consistency test (v1.6.0 AC4/AC5/AC6/AC14)"
```

---

## Task 4: command project-init.md — charter integration (Step 1 / 3.5 / 4 / 5)

**Files:**
- Modify: `plugins/project-init/commands/project-init.md`

Per C11 this is LLM-executed markdown with no command-flow unit tests — verification is the manual checklist in Task 6. This task resolves the deferred command-prose items: Phase 0 manifest detection matrix + fallback (C6), glossary trigger criterion (AC7), the AC5 `## Personas` fill mechanism, and the C-S3 file-vs-item branch (§6 matrix).

- [ ] **Step 1: Extend Step 1 detection with charter state**

In `plugins/project-init/commands/project-init.md`, after the existing Step 1 block (after current line 29, the AC21 abort sentence) and before `### Step 2`, insert:

```text
#### Step 1 (charter 상태 감지 — 파일 레벨, Phase 0보다 선행)

charter state를 **파일 레벨**로 판정한다 (§6 matrix 입력):

- (a) `AGENTS.md`에 `## Project Charter` 섹션이 존재하는가.
- (b) 그 섹션의 `**Vision:**`·`**Non-goals:**`·`**Tech Stack:**` 값이 모두 비어있지 않고 `{{...}}` placeholder가 아닌가 (= `charter_section_complete`).
- (c) `docs/project/charter.md` **와** `docs/project/conventions.md`가 모두 존재하는가 (= `docs_complete`; `glossary.md`는 조건부라 completeness 판정에서 제외).

이 판정으로 C-S1 / C-S2 / C-S3 중 하나를 결정한다 (Step 4의 matrix에서 사용). 이 판정은 git-workflow 감지와 독립이며, 두 matrix는 같은 run에서 동시에 평가되어도 서로 간섭하지 않는다.
```

- [ ] **Step 2: Add Step 3.5 (charter flow — Phase 0 + Phase 1)**

In `plugins/project-init/commands/project-init.md`, after the end of `### Step 3` (after current line 64, the Git Flow release-branch question) and before `### Step 4: 파일 생성`, insert:

```text
### Step 3.5: Project Charter (신규)

**직렬 순서**: Step 3.5는 Step 3(release-branch 질문 포함)이 *모두 끝난 뒤* 시작한다. branching 질문과 charter 질문을 교차하지 않는다. Phase 1의 "≤4개" 한도는 charter 질문에만 적용되며 git step 질문 수와 합산하지 않는다 (독립 카운트).

C-S2(완전 헌장 존재)면 먼저 "헌장을 업데이트할까요?"를 묻고, **거절 시 Step 3.5를 건너뛴다**(unchanged — NG7 경계상 합법, Law 1 게이트 비적용). 승인 또는 C-S1/C-S3(a)면 아래 Phase 0+1을 진행한다. C-S3(b)(docs 파일만 누락)는 질문 없이 Step 4에서 기존 섹션 값으로 누락 파일만 생성한다.

#### Phase 0 — 사실 발견 (질문 0개)

`Glob`/`Read`로 repo를 스캔해 tech-stack 후보를 자동 생성한다. manifest → stack 라벨 매핑:

| 감지 파일 | stack 라벨 (+ 추가 추론) |
|---|---|
| `package.json` | Node.js/JavaScript. `tsconfig.json` 또는 `devDependencies.typescript` → TypeScript. `dependencies`의 react/next/vue/svelte/express/nest → 프레임워크 라벨. `scripts.test`/`scripts.build` → build·test 명령. |
| `pyproject.toml` / `requirements.txt` / `setup.py` / `Pipfile` | Python. `pyproject.toml`의 `requires-python` → 버전. deps의 django/flask/fastapi → 프레임워크. `[tool.pytest]`/`pytest` dep → test 명령. |
| `go.mod` | Go. `go` directive → 버전. |
| `Cargo.toml` | Rust. `[package].edition` → edition. |
| `pom.xml` / `build.gradle` / `build.gradle.kts` | Java/Kotlin (Maven 또는 Gradle). |
| `Gemfile` | Ruby. |
| `composer.json` | PHP. |

감지된 각 항목에 **`[감지됨]`** 라벨을 붙여 Phase 1 ④에서 확인만 받는다.

**Fallback (C6 — graceful degradation, loud logging)**: 위 manifest를 하나도 못 찾으면 crash하지 않고 직접 질문 모드로 downgrade하되 fallback이 돌았음을 명시한다:

> `[project-init] manifest 미발견 — tech-stack 자동 감지 fallback: 직접 입력으로 진행합니다.`

이 경우 Phase 1 ④는 `[감지됨]` 확인 대신 open-ended tech-stack 질문이 된다.

#### Phase 1 — 판단 질문 (AskUserQuestion, ≤4개)

`AskUserQuestion`으로 다음 4개만 묻는다 (자동 감지된 사실은 open-ended 재질문 금지 — AC3):

1. **Vision** (필수, 1문장) — "이 프로젝트의 한 문장 vision은?"
2. **Non-goals** (필수) — "명시적으로 하지 *않을* 것 (non-goals)은?"
3. **핵심 conventions** (필수, 1–3개) — "지켜야 할 핵심 코딩/구조 컨벤션 1–3개는?"
4. **Tech-stack 확인** (필수) — Phase 0 후보를 보여주고 "감지된 tech-stack이 맞나요? 수정·추가할 것은?" (fallback 시 open-ended 입력).

**Glossary 트리거 (AC7, 별도 질문 아님)**: 위 4개 답변 안에서 사용자가 *프로젝트 고유 도메인 용어*(일반 SW 어휘가 아닌, 이 프로젝트에서 특정 의미로 정의해 쓰는 명사 — 예: "ledger", "tenant", "rollup")를 명시적으로 정의·언급한 경우에만 glossary 후보로 수집한다. 용어를 **추측해 만들지 않는다**. 모호하면 수집하지 않는다(보수적). 수집된 용어가 0개면 `glossary.md`를 생성하지 않는다(빈 파일 금지).

#### Law 1 구조적 게이트 (bounded — AC10/C9)

C-S1 및 C-S3(a)에서 **vision·non-goals·conventions·tech-stack**가 채워질 때까지 진행을 막는다. 각 필수 항목에 대해 빈/무의미 응답이면 AskUserQuestion 재질문을 **최대 3회**까지 한다. 3회 후에도 비면 charter step을 *loud advisory와 함께 abort*한다:

> `[project-init] charter 미완료: <항목> 비어 abort. git-workflow 산출물은 정상 생성되며, docs-lint이 ## Project Charter 미완을 사후 플래그합니다.`

abort 후에도 Step 4의 git-workflow 파일 생성은 정상 진행한다(부분 산출물 금지 아님 — git-workflow는 charter와 독립). C-S2(완전 헌장 갱신)는 이 게이트 면제.
```

- [ ] **Step 3: Extend Step 4 with charter publication + state matrix**

In `plugins/project-init/commands/project-init.md`, after the `#### 4d: docs/git-workflow/ 파일 쓰기` block (after current line 110) and before `### Step 5: 확인`, insert:

```text
#### 4e: Project Charter 발행 (§6 state matrix)

charter step이 abort되지 않았다면, Step 1에서 판정한 charter state에 따라 발행한다. template은 `${CLAUDE_PLUGIN_ROOT}/templates/project/`에서 읽어 placeholder를 elicit된 값으로 치환한다 (C7 — 의견 콘텐츠 주입 금지, AC14).

읽을 template:
- `${CLAUDE_PLUGIN_ROOT}/templates/project/agents-md-section.md` → `AGENTS.md`의 `## Project Charter` 섹션
- `${CLAUDE_PLUGIN_ROOT}/templates/project/charter.md` → `docs/project/charter.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/project/conventions.md` → `docs/project/conventions.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/project/glossary.md` → `docs/project/glossary.md` (조건부)

placeholder 치환 매핑:

| Placeholder | 값 출처 |
|---|---|
| `{{VISION}}` | Phase 1 ① |
| `{{NON_GOALS}}` | Phase 1 ② |
| `{{TECH_STACK}}` | Phase 1 ④ (확정 tech-stack) |
| `{{GOALS}}` | vision에서 파생한 1–3개 목표 (사용자 답변 기반) |
| `{{SUCCESS_CRITERIA}}` | 사용자가 success/DoD를 언급했으면 그 값, 아니면 `_명시되지 않음 — 추후 보강._` |
| `{{PERSONAS}}` | vision·non-goals 답변에 audience/사용자가 언급됐으면 그로부터 파생; 없으면 `_명시되지 않음 — 추후 보강._` (canned persona 주입 금지, AC14). **personas는 Law 1 게이트 항목이 아니므로**(AC10은 vision·non-goals·conventions·tech-stack만) 비어 있어도 abort하지 않는다. |
| `{{NAMING}}`·`{{DIRECTORY_STRUCTURE}}`·`{{ERROR_HANDLING}}`·`{{ANTI_PATTERNS}}` | Phase 1 ③ conventions 답변을 항목별로 분배; 해당 답변이 없으면 `_명시되지 않음._` |
| `{{BUILD_TEST}}` | Phase 0에서 감지한 build·test 명령; 없으면 `_명시되지 않음._` |
| `{{GLOSSARY_TERMS}}` | 수집된 도메인 용어를 `- **<용어>**: <정의>` 목록으로 (용어 0개면 glossary.md 미생성) |

**State별 action (§6):**

| State | Action |
|---|---|
| **C-S1 (clean)** | `AGENTS.md`에 `## Project Charter` 섹션 신규 추가(`agents-md-section.md` 치환본) + `docs/project/charter.md`·`conventions.md` 생성 (+용어 있으면 `glossary.md`). |
| **C-S2 (complete)** | 업데이트 승인 시: `## Project Charter` 섹션 in-place 교체 + `docs/project/` 파일 in-place 갱신. 거절 시: 전부 unchanged, 중복 `## Project Charter` 섹션 생성 안 함. |
| **C-S3 (a) 섹션 항목 누락** | Phase 1 보충 질문으로 채운 뒤 C-S1과 동일하게 발행(in-place 교체). |
| **C-S3 (b) docs 파일만 누락** | 질문 없이, 기존 `## Project Charter` 섹션 값을 source로 누락된 `docs/project/*.md`만 생성. AGENTS.md 섹션은 unchanged. |

`docs/project/` 디렉토리가 없으면 생성한다. 비-관리 콘텐츠(다른 헤딩·단락·코드 블록)는 모든 state에서 보존한다(기존 4c matrix 정신). `## Project Charter` 요약은 ≤약 25줄로 유지하고 상세는 전부 `docs/project/`로 내린다(C5 — 기존 R1 size 룰 자기 준수).
```

- [ ] **Step 4: Update Step 5 confirmation**

In `plugins/project-init/commands/project-init.md`, in the Step 5 confirmation block, add charter files to the reported output. After the `docs/git-workflow/pr-process.md` bullet (current line 123), insert:

```text
> - `AGENTS.md` — `## Project Charter` 요약 섹션 (vision·non-goals·tech-stack + docs/project/ 포인터)
> - `docs/project/charter.md` — vision·goals·non-goals·success criteria·personas
> - `docs/project/conventions.md` — naming·구조·error handling·anti-patterns·build & test
> - (도메인 용어가 있으면) `docs/project/glossary.md`
```

And update the trailing hook description line (current line 125) to mention charter validation:

```text
> `project-init` 플러그인 hook이 브랜치·commit 메시지 + agent-readable docs convention (size, TOC, fenced lang, links, drift) + `## Project Charter` 필수 항목(vision·non-goals·tech-stack)을 자동 검증합니다.
```

- [ ] **Step 5: Commit**

```bash
git add plugins/project-init/commands/project-init.md
git commit -m "feat(project-init): /project-init charter step — Phase 0/1, state matrix, gate (v1.6.0 AC1/AC2/AC3/AC5/AC6/AC7/AC9/AC10)"
```

---

## Task 5: plugin shape — plugin.json, CHANGELOG, README

**Files:**
- Modify: `plugins/project-init/.claude-plugin/plugin.json`
- Modify: `plugins/project-init/CHANGELOG.md`
- Modify: `plugins/project-init/README.md`

Resolves AC15 and AC17. The version bump is mandatory (touching `plugins/project-init/` without it leaves the cache key stale).

- [ ] **Step 1: Bump plugin.json (1.5.0 → 1.6.0) and update description**

In `plugins/project-init/.claude-plugin/plugin.json`, change `"version": "1.5.0"` to `"version": "1.6.0"` and replace the `description` value with:

```text
Initialize git workflow rules and a project charter for any project. Select a branching strategy (GitHub Flow, Git Flow, Trunk-based) and elicit a project charter (vision, non-goals, tech-stack, conventions) via a fact-routing interview, then generate AGENTS.md (canonical: Git Workflow + Project Charter) + CLAUDE.md (@AGENTS.md thin pointer) and docs/ details. Auto-validates branch/commit, agent-readable docs conventions, and charter integrity via hooks.
```

- [ ] **Step 2: Add the CHANGELOG entry**

In `plugins/project-init/CHANGELOG.md`, insert a new entry immediately after the format-preamble (after current line 6, before `## [1.5.0] — 2026-05-26`):

```text
## [1.6.0] — 2026-05-31

### Added

- **Project Charter surface** — `/project-init`에 charter step(Step 3.5) 추가. **Phase 0** (fact-routing): `package.json`/`pyproject.toml`/`go.mod`/`Cargo.toml`/`pom.xml`/`build.gradle`/`Gemfile`/`composer.json` 등 manifest와 디렉토리 구조를 스캔해 tech-stack을 `[감지됨]` 라벨로 자동 후보 생성. **Phase 1**: AskUserQuestion ≤4개(vision·non-goals·핵심 conventions·tech-stack 확인)만 사용자에게 묻는다. manifest 부재 시 loud fallback으로 직접 질문 downgrade (C6).
- 헌장 발행: `AGENTS.md`에 `## Project Charter` 요약 섹션(≤약 25줄) + `docs/project/charter.md`·`docs/project/conventions.md`(+ 조건부 `docs/project/glossary.md`) 상세 파일. `CLAUDE.md`는 `@AGENTS.md` thin pointer 유지.
- `templates/project/` — 4개 skeleton(`agents-md-section.md`, `charter.md`, `conventions.md`, `glossary.md`). placeholder만 있는 빈 골격이며 의견 콘텐츠를 주입하지 않는다 (charter 콘텐츠 100% 사용자 elicited).
- `hooks/docs-lint.py` — additive 확장. `is_charter_doc()` predicate로 `docs/project/*.md`를 lint 대상에 추가(기존 4-path exact-set 불변, regression-free) + R-charter 룰: `AGENTS.md`의 `## Project Charter` 섹션(heading-bounded)에서 vision·non-goals·tech-stack 레이블의 존재·비어있지 않음·`{{...}}` placeholder 잔존 없음을 advisory로 검출. **새 hook 파일·새 `hooks.json` entry·새 kill-switch 토큰 0개** — 기존 `DEVBREW_DISABLE_PROJECT_INIT=1` / `DEVBREW_SKIP_HOOKS=project-init:docs-lint`가 헌장 검증까지 커버.
- `hooks/tests/` — charter target / R-charter / template-consistency 테스트 + smoke fixtures(`charter_complete`, `charter_missing_subsection`, `charter_placeholder_residue`, `charter_doc_target`). `smoke.sh`에 `TARGETS` parallel array 추가(docs/project/*.md 타겟 지원).

### Changed

- `commands/project-init.md` — Step 1 charter 상태 감지(파일 레벨 C-S1/C-S2/C-S3), Step 3.5 charter 흐름, Step 4e 헌장 발행 + 멱등 state matrix, Step 5 확인 메시지에 헌장 파일 추가.

### Rationale

- spec-distill(per-feature `spec.md`)·quality-gates(review) 위에 비어 있던 **프로젝트 수준 durable 정의** 레이어를 채운다. 헌장이 AGENTS.md 계층에 거주하므로 매 세션·모든 spec-distill 인터뷰가 passive 상속(추가 런타임 비용 0). v1.5.0이 제거한 canned `## LLM Coding Guidelines`와 정반대 방향 — devbrew 의견이 아니라 사용자가 elicit한 정의만 캡처한다.
```

- [ ] **Step 3: Sync the README**

In `plugins/project-init/README.md`, make four edits:

(a) Architecture tree — after the `docs-lint.py` line in the `hooks/` block, the tree already lists hooks; add the `templates/project/` block. Replace the templates portion of the tree (current lines 22–35) with:

```text
└── templates/
    ├── shared/
    │   ├── commit-conventions.md
    │   ├── pr-process.md
    │   └── claude-md-pointer.md     # @AGENTS.md 한 줄 thin pointer
    ├── github-flow/
    │   ├── agents-md-section.md
    │   └── branch-strategy.md
    ├── git-flow/
    │   ├── agents-md-section.md
    │   └── branch-strategy.md
    ├── trunk-based/
    │   ├── agents-md-section.md
    │   └── branch-strategy.md
    └── project/                     # v1.6.0 — Project Charter skeletons
        ├── agents-md-section.md     # ## Project Charter 요약
        ├── charter.md               # vision·goals·non-goals·success·personas
        ├── conventions.md           # naming·구조·error·anti-patterns·build&test
        └── glossary.md              # 조건부 도메인 용어집
```

(b) 동작 방식 — after the existing numbered list (current lines 40–48), add a charter note:

```text
4. (v1.6.0) charter step — Phase 0가 manifest를 스캔해 tech-stack을 자동 감지하고, Phase 1이 vision·non-goals·conventions·tech-stack 확인을 ≤4개 질문으로 elicit. 결과를 `AGENTS.md ## Project Charter` 요약 + `docs/project/charter.md`·`conventions.md`(+ 조건부 `glossary.md`)로 발행.
```

(c) 설치된 Hook — update the `docs-lint.py` bullet (current line 78) to append the charter rule and target:

```text
- **`PostToolUse` (Write|Edit|MultiEdit matcher) — `docs-lint.py`**: root context 파일 (CLAUDE.md, AGENTS.md, .claude/CLAUDE.md, .claude/AGENTS.md) **및 `docs/project/*.md` (v1.6.0)**의 agent-readable convention (size ≤200, TOC if >300, fenced code language, internal links resolve, CLAUDE/AGENTS drift) + `AGENTS.md`의 `## Project Charter` 필수 하위항목(vision·non-goals·tech-stack: 존재·비어있지 않음·placeholder 잔존 없음, v1.6.0) 검증. **왜 hook인가?**: Write/Edit이 일어날 때마다 deterministic하게 발화해야 함, advisory only (non-blocking).
  - Kill switch: `DEVBREW_DISABLE_PROJECT_INIT=1` (전체) 또는 `DEVBREW_SKIP_HOOKS=project-init:docs-lint` (이 hook만). 새 토큰 없음 — 헌장 검증도 동일 스위치가 커버.
```

(d) 인스턴스화한 원칙 — add Law 1 and Law 3 charter lines (AC17). After the existing Law 1 (v1.4.0) bullet (current line 89), add:

```text
- **Law 1 (Clarity Before Code) — v1.6.0** — Project Charter가 project-init에 *처음으로* 생기는 clarity 구조 게이트. 최초 실행에서 vision·non-goals·tech-stack·conventions가 채워질 때까지 진행을 막되, 각 항목 최대 3회 재질문 후 loud abort (bounded — Unbounded-autonomy anti-pattern 회피).
- **Law 3 (Compounding) — v1.6.0** — 헌장이 AGENTS.md 계층에 거주해 매 세션·모든 spec-distill 인터뷰가 자동 상속하는 compounding substrate. 한 번 정의한 프로젝트 불변이 미래 모든 사이클에 discoverable하게 흐른다.
```

- [ ] **Step 4: Verify plugin-shape sync**

Run:
```bash
grep '"version": "1.6.0"' plugins/project-init/.claude-plugin/plugin.json && \
grep -q '## \[1.6.0\] — 2026-05-31' plugins/project-init/CHANGELOG.md && \
grep -q 'templates/project/' plugins/project-init/README.md && \
grep -q 'Law 1 (Clarity Before Code) — v1.6.0' plugins/project-init/README.md && \
echo "PLUGIN SHAPE OK"
```
Expected: prints the version line then `PLUGIN SHAPE OK`.

- [ ] **Step 5: Commit**

```bash
git add plugins/project-init/.claude-plugin/plugin.json plugins/project-init/CHANGELOG.md plugins/project-init/README.md
git commit -m "docs(project-init): v1.6.0 plugin shape — version bump, CHANGELOG, README (AC15/AC17)"
```

---

## Task 6: full verification + manual command checklist + final review

**Files:** none (verification only)

- [ ] **Step 1: Run the full unit suite from repo root**

Run: `python3 plugins/project-init/hooks/tests/test_docs_lint.py`
Expected: `OK` — every test (pre-existing + `TestCharterTarget` + `TestRCharter` + `TestTemplateConsistency`) green.

- [ ] **Step 2: Run the smoke suite**

Run: `bash plugins/project-init/hooks/tests/smoke.sh`
Expected: `V2 PASS`.

- [ ] **Step 3: Manual — clean run (C-S1, AC1/AC4/AC5/AC6/AC7/AC8)**

In a scratch empty directory, run `/project-init`, pick a strategy, and complete the charter step. Verify:
1. `AGENTS.md` has a `## Project Charter` section (vision·non-goals·tech-stack + `docs/project/` pointer), ≤~25 lines.
2. `docs/project/charter.md` exists with the fixed `## Vision`/`## Goals`/`## Non-goals`/`## Success Criteria / Definition of Done`/`## Personas` headings.
3. `docs/project/conventions.md` exists with the fixed `## Naming`/`## Directory Structure`/`## Error Handling`/`## Anti-patterns`/`## Build & Test` headings.
4. `CLAUDE.md` is the `@AGENTS.md` thin pointer.
5. If no domain term was elicited, `docs/project/glossary.md` is **absent** (AC7 — no empty file).

- [ ] **Step 4: Manual — fact-routing (AC2/AC3, C6)**

1. Run in a directory with `package.json` → tech-stack auto-detected with `[감지됨]` label, no open-ended re-ask for it.
2. Run in a directory with no manifest → the loud fallback line prints and tech-stack is asked directly.

- [ ] **Step 5: Manual — idempotent re-run (C-S2/C-S3, AC9)**

1. Re-run on a complete charter → "헌장을 업데이트할까요?" prompt; decline → files unchanged, no duplicate `## Project Charter` section.
2. Delete `docs/project/charter.md` only (C-S3(b)) and re-run → the file is regenerated from the existing section values **without** re-asking questions; `AGENTS.md` section stays unchanged.

- [ ] **Step 6: Manual — Law 1 bounded gate (AC10/C9)**

1. In a clean directory, run `/project-init` to the charter Phase 1.
2. At the **Non-goals** question, give an empty/blank answer.
3. Confirm it re-asks; give empty answers a 2nd and 3rd time.
4. On the 3rd empty answer, confirm the step aborts with the loud advisory: `[project-init] charter 미완료: non-goals 비어 abort. ...`.
5. Confirm the git-workflow files (`docs/git-workflow/*.md`, `## Git Workflow` in AGENTS.md) **were still generated** (no infinite loop, no partial-charter section written).

- [ ] **Step 7: Manual — docs-lint charter advisory live (AC11/AC12)**

1. Edit the generated `AGENTS.md` to blank the `**Vision:**` value (or set it to `{{VISION}}`) and save → the hook prints the `## Project Charter` incomplete advisory.
2. Re-fill it → saving produces `{}` (no advisory).
3. Set `DEVBREW_SKIP_HOOKS=project-init:docs-lint`, repeat step 1 → no advisory (kill-switch covers charter with no new token).

- [ ] **Step 8: Spec self-review (fresh-eyes pass)**

Re-read the spec (`docs/superpowers/specs/2026-05-31-project-init-project-charter-design.md`) §7 Acceptance Criteria and confirm each AC1–AC17 maps to a completed task above. Confirm AC13 (no new hook file, no new `hooks.json` entry, `post-tool-use.py` unchanged) holds:

Run:
```bash
git diff --name-only main...HEAD | grep -E 'hooks/(hooks\.json|post-tool-use\.py)$' && echo "AC13 VIOLATION" || echo "AC13 OK (no hook infra touched)"
```
Expected: `AC13 OK (no hook infra touched)`.

- [ ] **Step 9: (Optional, when the user asks) open the PR**

The branch `feature/project-init-charter` already carries the spec commits plus the implementation commits. When the user requests it, push and open a PR with `gh` per `docs/git-workflow/pr-process.md` (merge commit). Do not push or open the PR without the user's go-ahead.

---

## Self-Review

**1. Spec coverage** — AC1→Task4·Step2; AC2→Task4·Step2 (Phase 0 table + fallback); AC3→Task4·Step2 (≤4 questions); AC4→Task3 (template) + Task4·Step3 (publish); AC5→Task3 + TestTemplateConsistency; AC6→Task3 + TestTemplateConsistency; AC7→Task4·Step2 (glossary trigger criterion) + Task6·Step3.5 (absence verify); AC8→Task4 (reuses existing pointer) + Task6·Step3.4; AC9→Task4·Step3 (matrix) + Task6·Step5; AC10→Task4·Step2 (bounded gate) + Task6·Step6 (procedure); AC11→Task1 (rule) + Task1 tests + Task2 fixtures; AC12→Task1 `test_kill_switch_silences_charter`; AC13→Task6·Step8 grep; AC14→Task3 (skeleton, no canned) + Task4 persona/canned guard; AC15→Task5; AC16→Task1 + Task2 + Task3 tests; AC17→Task5·Step3(d). All covered.

**2. Placeholder scan** — Code steps contain full code (docs-lint functions, test classes, template bodies, command markdown, CHANGELOG/README text). The `{{...}}` strings in templates are intentional skeleton placeholders (C7), not plan placeholders. The `_명시되지 않음_` fills are deliberate honesty markers (not "add appropriate content"). No TBD/TODO.

**3. Type/name consistency** — The hook greps `CHARTER_REQUIRED_LABELS = ("Vision", "Non-goals", "Tech Stack")` via `**<label>:**`; the `agents-md-section.md` template emits exactly `**Vision:**`/`**Non-goals:**`/`**Tech Stack:**`; `TestTemplateConsistency.test_agents_section_template_has_required_labels` asserts the coupling. `is_charter_doc()` is defined in Task1·Step3 and referenced only in the same `resolve_target_path()` edit. `check_r_charter(target, rel_display)` signature matches its `main()` call site. Smoke `TARGETS` array length (13) matches `FIXTURES`/`EXPECTS` (13). Fixture names match between Task 2 creation steps, the smoke arrays, and the CHANGELOG/README references.
