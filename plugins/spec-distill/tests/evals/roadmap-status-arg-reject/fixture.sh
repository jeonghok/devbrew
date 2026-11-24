#!/bin/bash
git init -q . && mkdir -p docs && printf '# roadmap\n' > docs/roadmap.md && git add -A && git -c user.name=t -c user.email=t@example.invalid commit -qm init
