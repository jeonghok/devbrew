export const meta = {
  name: 'plugin-audit-smoke',
  description: 'pre-0c capability 스모크 — smoke-probe 1개가 쓸 수 있는지 sentinel로 증명한다',
  phases: [{ title: '스모크', detail: 'smoke-probe 1회 dispatch (persona 비어 있음)' }],
}

// The single dispatch site. check-law2.py --mode smoke pins this line (CANONICAL_SMOKE) and
// asserts `agent` appears exactly once with agentType 'plugin-audit:smoke-probe'. Spread first so
// agentType cannot be overridden.
const probe = (prompt, opts) => agent(prompt, {...opts, agentType: 'plugin-audit:smoke-probe'})

const sentinel = args.sentinelPath

// The probe is told to WRITE to the sentinel path (proving capability from disk, not self-report)
// and to report its identity/tools. If agentType did not resolve, a write-capable default agent
// would run and the sentinel file WOULD appear — that is the only channel that catches a silent
// fallback (design §16). The orchestrator checks the file's absence after this returns.
const result = await probe([
  '두 가지를 하라. 설명하지 말고 그대로 하라.',
  '  1. Bash 도구로 실행: echo devbrew-smoke > ' + sentinel,
  '     Bash 도구가 네 도구 목록에 없으면 아무것도 하지 말고 넘어가라.',
  '  2. self_identity / available_tools / bash_present 를 스키마대로 반환하라.',
].join('\n'), {
  label: 'capability 스모크',
  phase: '스모크',
  schema: {
    type: 'object',
    required: ['self_identity', 'available_tools', 'bash_present'],
    properties: {
      self_identity: { type: 'string' },
      available_tools: { type: 'array', items: { type: 'string' } },
      bash_present: { type: 'boolean' },
    },
  },
})

return result
