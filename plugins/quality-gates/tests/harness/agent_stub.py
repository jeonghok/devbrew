"""Stub harness for agent behavioral tests (T3-4 prerequisite).

Provides two helpers:

  run_agent_stub(agent_name, prompt, frozen_output) -> ParsedYAML
    Short-circuits an Agent dispatch by returning frozen_output verbatim
    and parsing it as YAML. Used to freeze agent output for deterministic
    behavioral assertions.

  assert_yaml_schema(parsed, required_keys, enum)
    Validates that parsed has all required_keys and that fields named in
    `enum` (dict[key, list[values]]) have values inside their enum.
    Raises AssertionError with explicit message on failure (no silent skip).

Used by tests/test_*_behavior.py to verify per-agent output contracts
without dispatching the real LLM (deterministic, hermetic).
"""
from __future__ import annotations

import yaml
from typing import Any


def run_agent_stub(agent_name: str, prompt: str, frozen_output: str) -> Any:
    """Parse frozen_output as YAML and return the parsed structure.

    agent_name and prompt are accepted for signature parity with future
    dispatch wrappers; they are not used by the stub itself.

    Raises AssertionError when YAML is malformed OR when YAML is valid but
    parses to None (empty / whitespace / literal 'null'). A None result
    indicates fixture authoring error — never a valid frozen agent output.
    """
    try:
        parsed = yaml.safe_load(frozen_output)
    except yaml.YAMLError as e:
        raise AssertionError(
            f"agent_stub[{agent_name}]: frozen_output not valid YAML: {e}\n"
            f"---\n{frozen_output[:500]}\n---"
        )
    if parsed is None:
        raise AssertionError(
            f"agent_stub[{agent_name}]: frozen_output parsed to None "
            f"(empty, whitespace-only, or literal 'null'). "
            f"Provide a non-empty YAML mapping as the frozen fixture.\n"
            f"---\n{frozen_output[:500]}\n---"
        )
    return parsed


def assert_yaml_schema(parsed: Any,
                       required_keys: list,
                       enum: dict = None) -> None:
    """Assert parsed dict has required_keys and enum values match.

    Raises AssertionError on missing key OR out-of-enum value.
    """
    if not isinstance(parsed, dict):
        raise AssertionError(
            f"parsed is not a dict (got {type(parsed).__name__})"
        )
    for k in required_keys:
        if k not in parsed:
            raise AssertionError(
                f"required key missing: {k!r}. "
                f"Keys present: {list(parsed.keys())}"
            )
    # Use `is not None` (not truthy check) so that an empty dict — possible
    # from a programmatic enum builder that produced zero entries — is treated
    # as "validate against zero constraints" (no-op loop) rather than as
    # "skip validation entirely" (silent green). Only an explicit None skips.
    if enum is not None:
        for key, allowed in enum.items():
            if key not in parsed:
                continue
            val = parsed[key]
            if isinstance(val, list):
                for v in val:
                    if v not in allowed:
                        raise AssertionError(
                            f"{key}[]={v!r} not in enum {allowed}"
                        )
            else:
                if val not in allowed:
                    raise AssertionError(
                        f"{key}={val!r} not in enum {allowed}"
                    )
