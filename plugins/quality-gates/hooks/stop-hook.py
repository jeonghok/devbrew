#!/usr/bin/env python3
"""Stop hook for quality-gates pipeline.

Manages pipeline progression by parsing <qg-signal> tags from the transcript,
computing state transitions, updating the state file, and injecting the next
gate's prompt. All file I/O happens in this script (not through Claude's Write
tool), so no permission prompts are triggered.

State machine (forward-only):
  gate1_running → gate2_running → gate3_running → completed

NEEDS_RESTART from Gate 2 or Gate 3 no longer auto-restarts to Gate 1.
Instead it terminates with a user-choice prompt (gate2_user_choice /
gate3_fail). The within-Gate-2 fix-loop (max_gate2_iterations) is preserved.

Kill switches (CLAUDE.md "kill switch는 보안 컨트롤"):
  DEVBREW_DISABLE_QUALITY_GATES=1                  - disables this hook entirely
  DEVBREW_SKIP_HOOKS=quality-gates:stop-hook       - skip just this one
"""

import json
import os
import re
import shutil
import sys
import tempfile
from datetime import datetime, timezone


# --- Constants ---

ROOT = ".claude/quality-gates"


def state_file_for(session_id: str) -> str:
    return f"{ROOT}/{session_id}/pipeline.md"


GATE_NAMES = {
    "1": "Plan Verification",
    "2": "PR Review",
    "3": "Runtime Verification",
}


# --- State File Parsing ---

def parse_state_file(path):
    """Parse YAML frontmatter and body from state file."""
    try:
        with open(path, "r") as f:
            content = f.read()
    except (IOError, OSError) as e:
        print(f"⚠️  Quality Gates: Cannot read state file: {e}", file=sys.stderr)
        return None, None

    # Extract frontmatter between --- markers
    match = re.match(r"^---\n(.*?)\n---\n(.*)", content, re.DOTALL)
    if not match:
        print("⚠️  Quality Gates: State file has invalid format", file=sys.stderr)
        return None, None

    frontmatter_text = match.group(1)
    body = match.group(2)

    # Parse YAML-like frontmatter (simple key: value pairs)
    state = {}
    for line in frontmatter_text.split("\n"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if ":" in line:
            key, _, value = line.partition(":")
            value = value.strip().strip('"')
            state[key.strip()] = value

    # Convert numeric fields (forward-only: total_iterations / max_total_iterations
    # are no longer written by setup-qg.sh; tolerate their absence on read).
    required_numeric = ("current_gate", "gate2_iteration", "max_gate2_iterations")
    optional_numeric = ("total_iterations", "max_total_iterations",
                        "gate3_resolution_iter", "max_gate3_resolutions")
    for field in required_numeric:
        val = state.get(field, "0")
        if not val.isdigit():
            print(f"⚠️  Quality Gates: Invalid numeric field '{field}': {val}",
                  file=sys.stderr)
            return None, None
        state[field] = int(val)
    for field in optional_numeric:
        val = state.get(field)
        if val is None:
            continue
        if val.isdigit():
            state[field] = int(val)
        # else: leave as-is; nothing reads it after forward-only refactor

    # Backward compatibility for v1.7.0 → v1.8.0:
    # - gate3_resolution_iter / max_gate3_resolutions added in v1.8.0.
    # - last_gate3_needed_hash added in v1.8.0 (string field, no conversion).
    # If absent from the state file (legacy session), default to safe values
    # so the pipeline continues rather than silently corrupting state.
    if "gate3_resolution_iter" not in state or not isinstance(state.get("gate3_resolution_iter"), int):
        state["gate3_resolution_iter"] = 0
        print("⚠️  Quality Gates: state file lacks gate3_resolution_iter (v1.7.0 schema?); defaulting to 0",
              file=sys.stderr)
    if "max_gate3_resolutions" not in state or not isinstance(state.get("max_gate3_resolutions"), int):
        state["max_gate3_resolutions"] = 3
        print("⚠️  Quality Gates: state file lacks max_gate3_resolutions; defaulting to 3",
              file=sys.stderr)
    if "last_gate3_needed_hash" not in state:
        state["last_gate3_needed_hash"] = ""

    # Convert boolean fields
    for field in ("skip_runtime",):
        state[field] = state.get(field, "false").lower() == "true"

    # Normalize null
    if state.get("single_gate") == "null":
        state["single_gate"] = None

    return state, body


def extract_gate_results(body):
    """Extract previous gate results from the state file body."""
    if not body:
        return ""
    results_match = re.search(
        r"## Gate Results\n(.*?)(?=\n## Pipeline History|\Z)", body, re.DOTALL
    )
    return results_match.group(1).strip() if results_match else ""


# --- Signal Extraction ---

def extract_signal_from_hook_input(hook_input):
    """Extract <qg-signal> from last_assistant_message in hook input.

    The Stop hook API provides 'last_assistant_message' containing the
    complete last assistant message text. This is more reliable than
    transcript parsing because it's guaranteed to include the current turn.
    """
    last_msg = hook_input.get("last_assistant_message", "")
    if not last_msg:
        return None

    # last_assistant_message may be a string or a structured object
    if isinstance(last_msg, dict):
        # Try to extract text from content blocks
        content = last_msg.get("content", [])
        if isinstance(content, list):
            texts = [b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"]
            last_msg = "\n".join(texts)
        elif isinstance(content, str):
            last_msg = content
        else:
            last_msg = str(last_msg)

    matches = re.findall(r"<qg-signal\s+(.*?)\s*/>", last_msg)
    if not matches:
        return None

    attrs = dict(re.findall(r'(\w+)="([^"]*)"', matches[-1]))
    return attrs


def extract_last_signal(transcript_path):
    """Extract the last <qg-signal> tag from the transcript.

    Reads the transcript as JSONL, extracts the last 100 assistant text blocks,
    and searches for <qg-signal .../> tags.
    """
    if not transcript_path or not os.path.exists(transcript_path):
        return None

    try:
        with open(transcript_path, "r") as f:
            lines = f.readlines()
    except (IOError, OSError):
        return None

    # Filter assistant lines (last 100 for bounded processing)
    assistant_lines = [
        line for line in lines
        if '"role":"assistant"' in line or '"role": "assistant"' in line
    ]
    assistant_lines = assistant_lines[-100:]

    if not assistant_lines:
        return None

    # Extract text content from assistant messages
    all_text = []
    for line in assistant_lines:
        try:
            msg = json.loads(line.strip())
            content = msg.get("message", {}).get("content", [])
            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "text":
                        all_text.append(block.get("text", ""))
        except (json.JSONDecodeError, AttributeError):
            continue

    if not all_text:
        return None

    # Search for <qg-signal> tags in all text (use last match)
    combined_text = "\n".join(all_text)
    matches = re.findall(r"<qg-signal\s+(.*?)\s*/>", combined_text)

    if not matches:
        return None

    # Parse attributes from the last match
    last_attrs_str = matches[-1]
    attrs = dict(re.findall(r'(\w+)="([^"]*)"', last_attrs_str))
    return attrs


# --- State Transitions ---

def compute_transition(state, signal):
    """Compute the next state based on current state and signal.

    Pure function: no I/O, no globals.  Returns a dict with at least a
    "type" key.  All verdict-to-transition mappings are centralised here.

    Transition types:
      next_gate | retry_gate | complete | abort | extend |
      gate2_user_choice | max_gate2_exceeded | gate3_fail | continue
    """
    action = signal.get("action")
    gate = signal.get("gate")
    verdict = signal.get("verdict", "")

    # --- Pipeline control signals (action= overrides verdict) ---
    if action == "complete":
        return {"type": "complete"}
    if action == "abort":
        return {"type": "abort"}
    if action == "extend":
        additional = int(signal.get("additional", "3"))
        return {"type": "extend", "additional": additional}

    # --- Cross-cutting new verdicts (handled before gate-specific logic) ---

    # Trivial diff: pipeline completes immediately without dispatch
    if verdict == "trivia-skipped":
        return {"type": "complete", "reason": signal.get("reason", "trivia")}

    # Scout agent failed; pipeline continues with rule-based gating (informational)
    if verdict == "scout-fallback":
        return {"type": "continue", "note": "scout-fallback"}

    # Gate 2 inner loop saw two identical iterations — no progress; user choice
    if verdict == "repeat-detected":
        return {"type": "gate2_user_choice", "prompt_key": "gate2_repeat_detected"}

    # --- Single-gate mode: done after one gate completes ---
    if state.get("single_gate"):
        return {"type": "complete"}

    # --- Gate 1 transitions ---
    if gate == "1":
        if verdict in ("PASS", "SKIP", "PASS_WITH_WARNINGS"):
            return {"type": "next_gate", "next_gate": 2, "gate2_iteration": 1}
        if verdict == "RETRY":
            return {"type": "retry_gate", "gate": 1}
        # FAIL = user chose to abort
        return {"type": "abort"}

    # --- Gate 2 transitions ---
    if gate == "2":
        if verdict in ("PASS", "PASS_WITH_WARNINGS"):
            if state.get("skip_runtime"):
                return {"type": "complete"}
            return {"type": "next_gate", "next_gate": 3}
        if verdict == "NEEDS_RESTART":
            # Forward-only: no cross-gate restart to Gate 1.
            # Present user choice: apply changes then re-run /qg.
            return {
                "type": "gate2_user_choice",
                "prompt_key": "gate2_needs_restart",
            }
        if verdict == "FAIL":
            if state["gate2_iteration"] < state["max_gate2_iterations"]:
                return {
                    "type": "retry_gate",
                    "gate": 2,
                    "gate2_iteration": state["gate2_iteration"] + 1,
                }
            return {"type": "max_gate2_exceeded"}

    # --- Gate 3 transitions ---
    if gate == "3":
        if verdict in ("PASS", "SKIP", "SKIP_WITH_EVIDENCE", "PASS_WITH_WARNINGS"):
            return {"type": "complete"}
        if verdict == "NEEDS_RESOLUTION":
            iter_now = state.get("gate3_resolution_iter", 0)
            max_now = state.get("max_gate3_resolutions", 3)
            # Repeat detection: same needed_hash from prior iteration → not converging
            current_hash = signal.get("needed_hash", "")
            prior_hash = state.get("last_gate3_needed_hash", "")
            if iter_now > 0 and current_hash and current_hash == prior_hash:
                return {"type": "gate3_repeat_detected"}
            if iter_now < max_now:
                return {"type": "gate3_needs_resolution"}
            # max reached → escalate to gate3_fail (existing prompt)
            return {"type": "gate3_fail"}
        if verdict in ("NEEDS_RESTART", "FAIL"):
            # Forward-only: Gate 3 issues require user attention; no auto-restart.
            # build_special_prompt("gate3_fail") covers both paths uniformly.
            return {"type": "gate3_fail"}

    # Unknown state — abort safely
    return {"type": "abort"}


# --- State File Update ---

def update_state_file(path, state, signal, transition):
    """Update the state file with new state and history entry."""
    try:
        with open(path, "r") as f:
            content = f.read()
    except (IOError, OSError):
        return

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    gate = signal.get("gate", "?")
    verdict = signal.get("verdict", signal.get("action", "?"))
    summary = signal.get("summary", "")
    iteration = signal.get("iteration", "")
    files_changed = signal.get("files_changed", "")

    # --- Update frontmatter fields ---

    new_status = state.get("status", "gate1_running")
    new_gate = state.get("current_gate", 1)
    new_total = state.get("total_iterations", 1)
    new_gate2_iter = state.get("gate2_iteration", 0)
    new_max_total = state.get("max_total_iterations", 5)
    new_gate3_resolution_iter = state.get("gate3_resolution_iter", 0)

    t_type = transition["type"]
    if t_type == "next_gate":
        new_gate = transition["next_gate"]
        new_status = f"gate{new_gate}_running"
        if new_gate == 2:
            new_gate2_iter = transition.get("gate2_iteration", 1)
    elif t_type == "retry_gate":
        retry_gate = transition.get("gate", new_gate)
        new_status = f"gate{retry_gate}_running"
        if retry_gate == 2:
            new_gate2_iter = transition.get("gate2_iteration", new_gate2_iter)
    elif t_type == "extend":
        new_max_total += transition.get("additional", 3)
    elif t_type in ("complete", "abort"):
        new_status = "completed" if t_type == "complete" else "aborted"

    # Track gate3 resolution iteration (forward-only count).
    if transition.get("type") == "gate3_needs_resolution":
        new_gate3_resolution_iter = state.get("gate3_resolution_iter", 0) + 1
        state["gate3_resolution_iter"] = new_gate3_resolution_iter
        # Remember this iteration's needed_hash so the next iteration can
        # detect a repeat (same needed set twice in a row → not converging).
        state["last_gate3_needed_hash"] = signal.get("needed_hash", "")

    # Apply frontmatter updates via string replacement.
    # Forward-only: total_iterations / max_total_iterations are no longer
    # persisted (setup-qg.sh stopped writing them in v1.5.0). Stale fields
    # in old state files are tolerated on read but not refreshed.
    replacements = {
        "status": new_status,
        "current_gate": str(new_gate),
        "gate2_iteration": str(new_gate2_iter),
        "gate3_resolution_iter": str(new_gate3_resolution_iter),
        "last_gate3_needed_hash": state.get("last_gate3_needed_hash", ""),
    }
    for key, val in replacements.items():
        content = re.sub(
            rf"^{key}:.*$", f"{key}: {val}", content, count=1, flags=re.MULTILINE
        )

    # --- Append gate result ---

    iter_suffix = f" Iteration {iteration}" if iteration else ""
    result_entry = f"\n### Gate {gate}{iter_suffix}\n"
    result_entry += f"**Verdict:** {verdict}\n"
    if summary:
        result_entry += f"**Summary:** {summary}\n"
    if files_changed:
        result_entry += f"**Files Changed:** {files_changed}\n"

    content = content.replace(
        "## Pipeline History",
        f"{result_entry}\n## Pipeline History",
        1,
    )

    # --- Append history entry ---

    iter_label = f" iter {iteration}" if iteration else ""
    history_line = f"- [{now}] Gate {gate}{iter_label}: {verdict}"

    content = content.replace(
        "## Pipeline History\n",
        f"## Pipeline History\n{history_line}\n",
        1,
    )

    # --- Atomic write ---

    dir_name = os.path.dirname(path)
    fd, temp_path = tempfile.mkstemp(dir=dir_name, prefix=".qg-state-")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(content)
        os.replace(temp_path, path)
    except Exception:
        try:
            os.unlink(temp_path)
        except OSError:
            pass
        raise


# --- Prompt Construction ---

def build_gate_prompt(gate_num, state, gate_results):
    """Build the prompt for the next gate execution."""
    plan_file = state.get("plan_file", "auto")
    pr_url = state.get("pr_url", "")
    available_plugins = state.get("available_plugins", "")
    gate2_iteration = state.get("gate2_iteration", 1)
    max_gate2 = state.get("max_gate2_iterations", 5)

    prompt_parts = ["# QG-STOP-HOOK-CONTINUATION\n"]

    if gate_num == 1:
        prompt_parts.append(
            "Execute Quality Gates - Gate 1 (Plan Verification).\n\n"
            "Parameters:\n"
            f"  gate: 1\n"
            f"  plan_path: {plan_file}\n"
            f"  available_plugins: {available_plugins}\n"
        )
    elif gate_num == 2:
        # Extract previous Gate 2 findings if available
        prev_findings = "none"
        g2_matches = re.findall(
            r"### Gate 2.*?\n\*\*Summary:\*\* (.*?)(?:\n|$)",
            gate_results,
        )
        if g2_matches:
            prev_findings = g2_matches[-1]

        prompt_parts.append(
            f"Execute Quality Gates - Gate 2 (PR Review), "
            f"iteration {gate2_iteration}/{max_gate2}.\n\n"
            "Parameters:\n"
            f"  gate: 2\n"
            f"  pr_url: {pr_url}\n"
            f"  iteration: {gate2_iteration}\n"
            f"  max_iterations: {max_gate2}\n"
            f"  previous_findings: {prev_findings}\n"
            f"  available_plugins: {available_plugins}\n"
            f"  plan_path: {plan_file}\n"
        )
    elif gate_num == 3:
        prompt_parts.append(
            "Execute Quality Gates - Gate 3 (Runtime Verification).\n\n"
            "Parameters:\n"
            f"  gate: 3\n"
            f"  plan_path: {plan_file}\n"
            f"  project_type: auto\n"
            f"  app_start_command: auto\n"
            f"  app_url: auto\n"
        )

    # Add previous gate results context
    if gate_results.strip():
        prompt_parts.append(
            f"\nPrevious gate results:\n{gate_results}\n"
        )

    prompt_parts.append(
        '\nInvoke Skill("quality-gates:quality-pipeline") with the above parameters.\n'
        "After the gate completes, emit a <qg-signal> tag with your verdict."
    )

    return "".join(prompt_parts)


def build_special_prompt(transition_type, state, gate_results, prompt_key=None):
    """Build prompts for special situations (user choices, gate failures).

    transition_type: the transition["type"] value.
    prompt_key: optional sub-key for gate2_user_choice (gate2_needs_restart,
                gate2_repeat_detected).
    """
    if transition_type == "max_gate2_exceeded":
        return (
            "GATE2_MAX_EXCEEDED\n\n"
            f"Gate 2 (PR Review) exceeded maximum iterations "
            f"({state['max_gate2_iterations']}).\n\n"
            "Report remaining issues to the user and present options:\n"
            "1. Proceed to Gate 3 anyway\n"
            "2. Abort pipeline\n\n"
            "Based on user choice:\n"
            '- Proceed: emit <qg-signal gate="2" verdict="PASS_WITH_WARNINGS" '
            'summary="Proceeding with remaining issues" files_changed="" />\n'
            '- Abort: emit <qg-signal action="abort" reason="User chose to abort" />\n'
            f"\nPipeline context:\n{gate_results}"
        )

    if transition_type == "gate3_needs_resolution":
        iter_now = state.get("gate3_resolution_iter", 0)
        max_now = state.get("max_gate3_resolutions", 3)
        return (
            "GATE3_NEEDS_RESOLUTION\n\n"
            "Gate 3 (Runtime Verification) found resolvable missing resources "
            f"(resolution iteration {iter_now}/{max_now}).\n\n"
            "The skill (mother) must present the agent's `needed` items to the user "
            "as **decision-only** options (retry / skip this surface / abort). "
            "DO NOT ask the user for secret values (API keys, DB URLs, tokens, "
            "passwords). If a secret is required, the only valid options are: "
            "user sets the secret in .env on disk and chooses retry, OR skip the "
            "affected surface, OR abort.\n\n"
            "Present options to the user via AskUserQuestion:\n"
            "1. Retry — user has resolved the missing resource (e.g., started "
            "Docker daemon, added env var to .env). Re-dispatch runtime-verifier.\n"
            "2. Skip this surface — record the surface as unresolved in evidence-log "
            "and continue with remaining surfaces.\n"
            "3. Abort — stop the pipeline.\n\n"
            "Based on user choice:\n"
            "- Retry: re-dispatch runtime-verifier with updated manifest "
            '(skill increments gate3_resolution_iter). Then emit '
            '<qg-signal gate="3" verdict="..." iteration="N" /> with the new verdict.\n'
            '- Skip surface: emit <qg-signal gate="3" verdict="SKIP_WITH_EVIDENCE" '
            'summary="user opted to skip <surface>" files_changed="" />\n'
            '- Abort: emit <qg-signal action="abort" reason="User chose to abort '
            'during gate3_needs_resolution" />\n'
            f"\nPipeline context:\n{gate_results}"
        )

    if transition_type == "gate3_repeat_detected":
        return (
            "GATE3_REPEAT_DETECTED\n\n"
            "Gate 3 (Runtime Verification) is not converging — "
            "the same `needed` resources appeared 2 iterations in a row.\n\n"
            "Present options to the user via AskUserQuestion:\n"
            "1. Proceed — accept the current state with warnings and continue\n"
            "2. Abort — stop the pipeline\n\n"
            "Based on user choice:\n"
            '- Proceed: emit <qg-signal gate="3" verdict="PASS_WITH_WARNINGS" '
            'summary="Repeat detected; user accepted" files_changed="" />\n'
            '- Abort: emit <qg-signal action="abort" reason="User chose to abort" />\n'
            f"\nPipeline context:\n{gate_results}"
        )

    if transition_type == "gate3_fail":
        return (
            "GATE3_FAIL\n\n"
            "Gate 3 (Runtime Verification) failed.\n\n"
            "Present options to the user:\n"
            "1. Fix the issues and re-run `/qg` (pipeline does not auto-restart)\n"
            "2. Skip runtime verification and accept\n"
            "3. Abort pipeline\n\n"
            "Based on user choice:\n"
            '- Fix: inform the user to apply fixes and re-run /qg. '
            'Then emit <qg-signal action="abort" reason="User will re-run /qg after fixes" />\n'
            '- Skip: emit <qg-signal gate="3" verdict="SKIP" '
            'summary="User chose to skip runtime verification" files_changed="" />\n'
            '- Abort: emit <qg-signal action="abort" reason="User chose to abort" />\n'
            f"\nPipeline context:\n{gate_results}"
        )

    if transition_type == "gate2_user_choice":
        if prompt_key == "gate2_needs_restart":
            return (
                "GATE2_NEEDS_RESTART\n\n"
                "Gate 2 (PR Review) found that code-level changes are needed.\n\n"
                "The pipeline is forward-only and cannot automatically re-enter Gate 1.\n\n"
                "Present options to the user:\n"
                "1. Proceed — accept the Gate 2 findings as-is and continue\n"
                "2. Apply changes and re-run — apply the suggested changes, "
                "then re-run `/qg` manually\n"
                "3. Abort — stop the pipeline\n\n"
                "Based on user choice:\n"
                '- Proceed: emit <qg-signal gate="2" verdict="PASS_WITH_WARNINGS" '
                'summary="Accepted Gate 2 findings as-is" files_changed="" />\n'
                '- Apply + re-run: emit <qg-signal action="abort" '
                'reason="User will apply changes and re-run /qg" />\n'
                '- Abort: emit <qg-signal action="abort" reason="User chose to abort" />\n'
                f"\nPipeline context:\n{gate_results}"
            )
        if prompt_key == "gate2_repeat_detected":
            return (
                "GATE2_REPEAT_DETECTED\n\n"
                "Gate 2 (PR Review) is not converging — "
                "the same findings appeared 2 iterations in a row.\n\n"
                "Present options to the user:\n"
                "1. Proceed — accept the current Gate 2 findings and continue\n"
                "2. Abort — stop the pipeline\n\n"
                "Based on user choice:\n"
                '- Proceed: emit <qg-signal gate="2" verdict="PASS_WITH_WARNINGS" '
                'summary="Proceeding despite repeated findings" files_changed="" />\n'
                '- Abort: emit <qg-signal action="abort" reason="User chose to abort" />\n'
                f"\nPipeline context:\n{gate_results}"
            )
        # Generic gate2_user_choice fallback
        return (
            "GATE2_USER_CHOICE\n\n"
            "Gate 2 (PR Review) requires user input.\n\n"
            "Present options to the user:\n"
            "1. Proceed — accept findings as-is\n"
            "2. Abort — stop the pipeline\n\n"
            "Based on user choice:\n"
            '- Proceed: emit <qg-signal gate="2" verdict="PASS_WITH_WARNINGS" '
            'summary="User accepted findings" files_changed="" />\n'
            '- Abort: emit <qg-signal action="abort" reason="User chose to abort" />\n'
            f"\nPipeline context:\n{gate_results}"
        )

    return ""


def build_system_message(state, transition):
    """Build the system message shown to the user."""
    t_type = transition["type"]
    gate = state.get("current_gate", 1)
    gate2_iter = state.get("gate2_iteration", 0)
    max_gate2 = state.get("max_gate2_iterations", 5)

    if t_type == "next_gate":
        gate = transition["next_gate"]

    gate_name = GATE_NAMES.get(str(gate), f"Gate {gate}")

    if t_type in ("max_gate2_exceeded", "gate3_fail", "gate2_user_choice",
                  "gate3_needs_resolution", "gate3_repeat_detected"):
        return "⚠️ Quality Gates: Action required | /cancel-qg to stop"

    # Forward-only: show within-Gate-2 iteration progress when applicable;
    # otherwise just the gate name. (Cross-gate restart counter removed.)
    if gate == 2 and gate2_iter > 0:
        return (
            f"🔄 Quality Gates: Gate 2 ({gate_name}) | "
            f"iter {gate2_iter}/{max_gate2} | /cancel-qg to stop"
        )
    return (
        f"🔄 Quality Gates: Gate {gate} ({gate_name}) | /cancel-qg to stop"
    )


# --- Main ---

def _disabled() -> bool:
    """Honor devbrew kill switches before any side effect.

    Uses whole-token match against comma-separated DEVBREW_SKIP_HOOKS so
    substrings cannot prefix-match an unintended hook key.
    """
    if os.environ.get("DEVBREW_DISABLE_QUALITY_GATES") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    tokens = {t.strip() for t in skip.split(",") if t.strip()}
    return "quality-gates:stop-hook" in tokens


def main():
    if _disabled():
        sys.exit(0)
    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    session_id = hook_input.get("session_id", "")
    if not session_id:
        sys.exit(0)
    state_file = state_file_for(session_id)

    # 1. Check state file exists
    if not os.path.exists(state_file):
        sys.exit(0)

    # 2. Parse state file
    state, body = parse_state_file(state_file)
    if state is None:
        # Corrupted state file — delete and allow exit
        try:
            os.unlink(state_file)
        except OSError:
            pass
        sys.exit(0)

    # 3. Session isolation defense-in-depth (path already encodes session)
    state_session = state.get("session_id", "")
    if state_session and state_session != session_id:
        sys.exit(0)

    # 4. Extract signal from hook input or transcript
    signal = extract_signal_from_hook_input(hook_input)
    if not signal:
        transcript_path = hook_input.get("transcript_path", "")
        signal = extract_last_signal(transcript_path)

    # 5. Get gate results from state file body
    gate_results = extract_gate_results(body)

    # 6. If no signal found, re-inject current gate prompt (ralph-loop pattern)
    if not signal:
        current_gate = state["current_gate"]
        prompt = build_gate_prompt(current_gate, state, gate_results)
        sys_msg = build_system_message(state, {"type": "retry_gate"})
        print(json.dumps({
            "decision": "block",
            "reason": prompt,
            "systemMessage": sys_msg,
        }))
        sys.exit(0)

    # 7. Compute state transition
    transition = compute_transition(state, signal)

    # 8. Update state file with signal results
    try:
        update_state_file(state_file, state, signal, transition)
    except Exception as e:
        print(f"⚠️  Quality Gates: Failed to update state file: {e}",
              file=sys.stderr)

    # 9. Handle completion/abort — remove session folder entirely and allow exit
    if transition["type"] in ("complete", "abort"):
        folder = os.path.dirname(state_file)
        shutil.rmtree(folder, ignore_errors=True)
        sys.exit(0)

    # 10. Handle user-choice prompts (gate2_user_choice, max_gate2_exceeded,
    #     gate3_fail, gate3_needs_resolution, gate3_repeat_detected).
    #     These block and present options; the pipeline resumes only after
    #     the user emits a new signal.
    if transition["type"] in ("gate2_user_choice", "max_gate2_exceeded",
                              "gate3_fail", "gate3_needs_resolution",
                              "gate3_repeat_detected"):
        prompt_key = transition.get("prompt_key")
        prompt = build_special_prompt(transition["type"], state, gate_results,
                                      prompt_key=prompt_key)
        sys_msg = build_system_message(state, transition)
        print(json.dumps({
            "decision": "block",
            "reason": prompt,
            "systemMessage": sys_msg,
        }))
        sys.exit(0)

    # 11. Handle extend — update max and re-inject current gate prompt
    if transition["type"] == "extend":
        current_gate = state["current_gate"]
        # State file already updated with new max
        updated_state, updated_body = parse_state_file(state_file)
        if updated_state:
            updated_results = extract_gate_results(updated_body)
            prompt = build_gate_prompt(current_gate, updated_state, updated_results)
            sys_msg = build_system_message(updated_state, {"type": "retry_gate"})
            print(json.dumps({
                "decision": "block",
                "reason": prompt,
                "systemMessage": sys_msg,
            }))
        sys.exit(0)

    # 12. Handle scout-fallback (continue) — informational; re-inject current gate
    if transition["type"] == "continue":
        current_gate = state["current_gate"]
        prompt = build_gate_prompt(current_gate, state, gate_results)
        sys_msg = build_system_message(state, {"type": "retry_gate"})
        print(json.dumps({
            "decision": "block",
            "reason": prompt,
            "systemMessage": sys_msg,
        }))
        sys.exit(0)

    # 13. Build next gate prompt
    if transition["type"] == "next_gate":
        next_gate = transition["next_gate"]
        # Re-read state file to get updated gate results
        updated_state, updated_body = parse_state_file(state_file)
        if updated_state:
            updated_results = extract_gate_results(updated_body)
            prompt = build_gate_prompt(next_gate, updated_state, updated_results)
        else:
            prompt = build_gate_prompt(next_gate, state, gate_results)
    elif transition["type"] == "retry_gate":
        retry_gate = transition.get("gate", state["current_gate"])
        updated_state, updated_body = parse_state_file(state_file)
        if updated_state:
            updated_results = extract_gate_results(updated_body)
            prompt = build_gate_prompt(retry_gate, updated_state, updated_results)
        else:
            prompt = build_gate_prompt(retry_gate, state, gate_results)
    else:
        # Fallback: re-inject current gate
        prompt = build_gate_prompt(state["current_gate"], state, gate_results)

    sys_msg = build_system_message(state, transition)

    print(json.dumps({
        "decision": "block",
        "reason": prompt,
        "systemMessage": sys_msg,
    }))
    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        # Safety net: if anything goes wrong, allow session to exit
        print(f"⚠️  Quality Gates stop hook error: {e}", file=sys.stderr)
        sys.exit(0)
