# before-census (2026-07-17) — 교정 regex '"name":"[A-Za-z0-9_-]*"'

| agent | transcript | 관측된 도구 호출 |
|---|---|---|
| `security-reviewer` | a5866cd4b23146708 | mcp__claude_ai_tavily__tavily_search×1 WebFetch×1 ToolSearch×1 Bash×1 Agent×1  |
| `adversarial` | a52326ff5bb62f0b8 | Bash×4 ToolSearch×2 mcp__claude_ai_Context7__resolve-library-id×1 WebFetch×1 Agent×1  |
| `breadth-keeper` | aaea2ed839675c0df | (호출 0) |
| `steelman-builder` | a7f570d0b6c85bcec | WebSearch×2 WebFetch×2 ToolSearch×2 Bash×2 mcp__claude_ai_Context7__resolve-library-id×1 Agent×1  |
| `pr-understanding-builder` | abb1be2c3d48e0097 | ToolSearch×2  |
| `test-scope-validator` | a4db4cb6f38e4b327 | Read×3 Bash×2 Agent×1  |
| `spec-reviewer` | a4baa87/ab24a2e/a2d9287 (실제 리뷰 3회) | Bash×45 Read×7 WebFetch×2 ToolSearch×2 **Grep×0 Glob×0** |
| `runtime-verifier` | — | **미측정 (의도적)**: Write·Bash 보유 실행자라 dispatch 위험 > census 가치. 목록은 파일의 죽은 allowedTools 22개에 열거됨 |
