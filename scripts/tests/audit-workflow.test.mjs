import { test } from 'node:test'
import assert from 'node:assert/strict'
import { runWorkflow, stubOneFinding } from './_wf_harness.mjs'

test('row 3 — d_verdicts.id enum includes D2', async () => {
  const { captured } = await runWorkflow('scripts/audit-workflow.js', { stubAgent: stubOneFinding() })
  const enumIds = captured['감사'].properties.d_verdicts.items.properties.id.enum
  assert.deepEqual(enumIds, ['D1', 'D2', 'D3', 'D4', 'D5'])
})

test('row 6 — findings.required includes reference_gap', async () => {
  const { captured } = await runWorkflow('scripts/audit-workflow.js', { stubAgent: stubOneFinding() })
  const required = captured['감사'].properties.findings.items.required
  assert.ok(required.includes('reference_gap'), 'reference_gap must be required')
})

test('row 14 — new_open_questions.axis is bounded 1..6', async () => {
  const { captured } = await runWorkflow('scripts/audit-workflow.js', { stubAgent: stubOneFinding() })
  const axis = captured['감사'].properties.new_open_questions.items.properties.axis
  assert.equal(axis.type, 'integer')
  assert.equal(axis.minimum, 1)
  assert.equal(axis.maximum, 6)
})

test('row 7 — REFUTE_SCHEMA does not require gate unconditionally', async () => {
  const { captured } = await runWorkflow('scripts/audit-workflow.js', { stubAgent: stubOneFinding() })
  const itemSchema = captured['검증'].properties.verdicts.items
  assert.ok(!itemSchema.required.includes('gate'),
    'gate must not be unconditionally required (survivors have no kill gate)')
  // 조건부 필수: verdict==refuted일 때만 gate 필수 (if/then)
  assert.ok(itemSchema.if && itemSchema.then,
    'gate should be conditionally required via if/then on verdict==refuted')
})

test('row 2 — AXIS① question requires D1·D2·D3·D4', async () => {
  const { calls } = await runWorkflow('scripts/audit-workflow.js', { stubAgent: stubOneFinding() })
  const axis1 = calls.find((c) => c.opts.phase === '감사' && /축: 1/.test(c.prompt))
  assert.ok(/D1·D2·D3·D4/.test(axis1.prompt), 'AXIS① must ask for D1·D2·D3·D4')
})
