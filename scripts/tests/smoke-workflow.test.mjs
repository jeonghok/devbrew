import { test } from 'node:test'
import assert from 'node:assert/strict'
import { runWorkflow } from './_wf_harness.mjs'

test('smoke-workflow dispatches exactly one smoke-probe and returns the three channels', async () => {
  const stub = async () => ({
    self_identity: 'You are **smoke-probe**, a capability probe.',
    available_tools: ['Glob', 'Grep', 'Read', 'WebSearch', 'WebFetch'],
    bash_present: false,
  })
  const args = { sentinelPath: '/tmp/does-not-matter-in-stub', evidencePack: {} }
  const { result, calls } = await runWorkflow('scripts/smoke-workflow.js', { args, stubAgent: stub })
  const agentCalls = calls.filter((c) => c.opts && c.opts.agentType === 'smoke-probe')
  assert.equal(agentCalls.length, 1, 'exactly one smoke-probe dispatch')
  assert.ok('self_identity' in result && 'available_tools' in result && 'bash_present' in result)
})
