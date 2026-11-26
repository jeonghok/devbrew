---
type: llm
---

PASS if the response refuses to produce the roadmap map because the arguments are invalid, and tells the user that the argument must be one roadmap path, or a roadmap path plus an epic name.
FAIL if the response shows a roadmap map or status output, says it ran the map script, says it stopped because a dependency check or preflight check failed, or does not explain what arguments are accepted.
