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

test('row 4 — CONTRACT renders staleness facts, own-test result, precedent paths', async () => {
  const args = {
    evidencePack: {
      plugin_version: '1.7.2', file_count: 51, total_lines: 4879,
      untracked_or_ignored: [], git_history_ld5: [],
      staleness_facts: [
        { class: 'dangling doc-claim', quote: 'scripts/foo.sh', file: 'README.md', line: 12 },
      ],
      own_tests: { ran: true, total: 95, passed: 95, failed: 0 },
      precedent_paths: ['~/Downloads/reference/gstack/careful/bin/check-careful.sh'],
      reference_paths: ['~/.claude/plugins/cache/claude-plugins-official/plugin-dev'],
    },
    codexFindings: [],
  }
  const { calls } = await runWorkflow('scripts/audit-workflow.js', { args, stubAgent: stubOneFinding() })
  const p = calls.find((c) => c.opts.phase === '감사').prompt
  assert.ok(/staleness|결정론.*사실|dangling doc-claim/.test(p), 'staleness facts must render')
  assert.ok(/README\.md:12|scripts\/foo\.sh/.test(p), 'staleness fact quote+file:line must render')
  assert.ok(/95\/95/.test(p), 'own-test numeric line must render')
  assert.ok(/check-careful\.sh/.test(p), 'precedent path must render')
})

test('row 4 — CONTRACT degrades loudly when staleness/own-test absent', async () => {
  const { calls } = await runWorkflow('scripts/audit-workflow.js', { stubAgent: stubOneFinding() })
  const p = calls.find((c) => c.opts.phase === '감사').prompt
  // 기본 pack엔 staleness_facts/own_tests 없음 → "미실행/없음" 류 명시 (조용히 빠지지 않음).
  // 헤더는 무조건 방출되므로 body-unique fallback 리터럴로 assert (헤더-satisfiable 회피).
  assert.ok(/없음을 사실로 받는다/.test(p), 'empty staleness → loud fallback line')
  assert.ok(/자체 테스트 미실행/.test(p), 'absent own_tests → loud fallback line')
  assert.ok(/선례 코퍼스 부재/.test(p), 'absent precedent → loud fallback line')
})
