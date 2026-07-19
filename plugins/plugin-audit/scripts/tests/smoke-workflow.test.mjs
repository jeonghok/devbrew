import { test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { runWorkflow } from './_wf_harness.mjs'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const SMOKE_WORKFLOW = path.join(HERE, '..', 'smoke-workflow.js')

test('smoke-workflow dispatches exactly one smoke-probe and returns the three channels', async () => {
  const stub = async () => ({
    self_identity: 'You are **smoke-probe**, a capability probe.',
    available_tools: ['Glob', 'Grep', 'Read', 'WebSearch', 'WebFetch'],
    bash_present: false,
  })
  const args = { sentinelPath: '/tmp/does-not-matter-in-stub', evidencePack: {} }
  const { result, calls } = await runWorkflow('plugins/plugin-audit/scripts/smoke-workflow.js', { args, stubAgent: stub })
  const agentCalls = calls.filter((c) => c.opts && c.opts.agentType === 'plugin-audit:smoke-probe')
  assert.equal(agentCalls.length, 1, 'exactly one plugin-audit:smoke-probe dispatch')
  assert.ok('self_identity' in result && 'available_tools' in result && 'bash_present' in result)
})

// The runtime-dispatch test above cannot see spread ORDER: the workflow's only call site passes
// a hand-written opts literal ({label, phase, schema}) that never itself carries an `agentType`
// key, so `{...opts, agentType: X}` and `{agentType: X, ...opts}` are behaviorally identical at
// that call site — a reversed-order mutation would slip past a purely behavioral assertion. The
// source-text lock below is what actually distinguishes them, standing in for check-law2.py's
// CANONICAL_SMOKE pin (Task 10, not yet ported) until that gate exists.
test('probe helper spreads opts BEFORE pinning agentType (spread-order lock)', () => {
  const src = fs.readFileSync(SMOKE_WORKFLOW, 'utf8')
  assert.match(
    src,
    /agent\(prompt,\s*\{\s*\.\.\.opts,\s*agentType:\s*'plugin-audit:smoke-probe'\s*\}\)/,
    'probe must be `agent(prompt, {...opts, agentType: \'plugin-audit:smoke-probe\'})` — spread ' +
    'first, so a caller-supplied opts.agentType cannot override the pinned namespaced agentType',
  )
})
