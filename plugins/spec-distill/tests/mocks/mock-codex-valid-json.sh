#!/usr/bin/env bash
# Emulates `codex exec --json`: a single item.completed agent_message whose
# text is a fenced JSON findings block using the spec-distill design vocab.
cat <<'JSONL'
{"type":"item.completed","item":{"type":"agent_message","text":"```json\n{\"findings\": [{\"category\": \"ambiguity\", \"target_section\": \"#2-goals\", \"severity\": \"high\", \"line\": 12, \"confidence\": 8, \"summary\": \"vague goal\", \"proposed_fix\": \"make measurable\"}]}\n```"}}
JSONL
exit 0
