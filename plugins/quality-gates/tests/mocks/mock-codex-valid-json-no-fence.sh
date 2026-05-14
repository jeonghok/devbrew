#!/usr/bin/env bash
cat <<'EOF'
{"type":"item.completed","item":{"type":"agent_message","text":"{\"findings\":[{\"file\":\"x.py\",\"line\":1,\"severity\":\"SUGGESTION\",\"confidence\":5,\"summary\":\"nothing wrong\",\"proposed_fix\":\"n/a\"}]}"}}
EOF
exit 0
