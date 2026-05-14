#!/usr/bin/env bash
cat <<'EOF'
{"type":"thought","text":"thinking..."}
{"type":"tool_call","name":"read","path":"x.py"}
EOF
exit 0
