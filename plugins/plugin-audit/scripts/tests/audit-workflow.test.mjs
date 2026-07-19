import { test } from 'node:test'
import assert from 'node:assert/strict'
import { runWorkflow, stubOneFinding, DEFAULT_PACK } from './_wf_harness.mjs'

const WF = 'plugins/plugin-audit/scripts/audit-workflow.js'

test('row 3 — d_verdicts.id enum is derived from pack candidate clues', async () => {
  // Generalized: the enum must reflect the seed-derived candidate_clues, not a static D1..D5.
  const args = {
    target: 'sample',
    evidencePack: {
      ...DEFAULT_PACK,
      candidate_clues: [
        { id: 'D1', axis: 1, claim: 'c1', file: 'a.md', line: 1 },
        { id: 'D2', axis: 1, claim: 'c2', file: 'b.md', line: 2 },
      ],
    },
    codexFindings: [],
  }
  const { captured } = await runWorkflow(WF, { args, stubAgent: stubOneFinding() })
  const enumIds = captured['감사'].properties.d_verdicts.items.properties.id.enum
  assert.deepEqual(enumIds, ['D1', 'D2'])
})

test('row 3b — empty candidate_clues omits the d_verdicts.id enum entirely (no enum:[])', async () => {
  const { captured } = await runWorkflow(WF, { stubAgent: stubOneFinding() })
  const idProp = captured['감사'].properties.d_verdicts.items.properties.id
  assert.equal(idProp.type, 'string')
  assert.ok(!('enum' in idProp), 'enum:[] matches nothing — the key must be omitted when no clues')
})

test('row 6 — findings.required includes reference_gap', async () => {
  const { captured } = await runWorkflow(WF, { stubAgent: stubOneFinding() })
  const required = captured['감사'].properties.findings.items.required
  assert.ok(required.includes('reference_gap'), 'reference_gap must be required')
})

test('row 14 — new_open_questions.axis is bounded 1..6', async () => {
  const { captured } = await runWorkflow(WF, { stubAgent: stubOneFinding() })
  const axis = captured['감사'].properties.new_open_questions.items.properties.axis
  assert.equal(axis.type, 'integer')
  assert.equal(axis.minimum, 1)
  assert.equal(axis.maximum, 6)
})

test('row 7 — REFUTE_SCHEMA does not require gate unconditionally', async () => {
  const { captured } = await runWorkflow(WF, { stubAgent: stubOneFinding() })
  const itemSchema = captured['검증'].properties.verdicts.items
  assert.ok(!itemSchema.required.includes('gate'),
    'gate must not be unconditionally required (survivors have no kill gate)')
  // 조건부 필수: verdict==refuted일 때만 gate 필수 (if/then)
  assert.ok(itemSchema.if && itemSchema.then,
    'gate should be conditionally required via if/then on verdict==refuted')
})

test('row 2 — AXIS① question renders the pack axis-1 candidate clues', async () => {
  // Generalized: axis-1 clues come from the pack (filtered by axis), not hardcoded D1·D2·D3·D4.
  const args = {
    target: 'sample',
    evidencePack: {
      ...DEFAULT_PACK,
      candidate_clues: [
        { id: 'D1', axis: 1, claim: 'AXIS1CLUEA', file: 'a.md', line: 1 },
        { id: 'D2', axis: 1, claim: 'AXIS1CLUEB', file: 'b.md', line: 2 },
        { id: 'D7', axis: 5, claim: 'AXIS5CLUE', file: 'c.md', line: 3 },
      ],
    },
    codexFindings: [],
  }
  const { calls } = await runWorkflow(WF, { args, stubAgent: stubOneFinding() })
  const axis1 = calls.find((c) => c.opts.phase === '감사' && /축: 1/.test(c.prompt))
  // Isolate the axis-1-specific region (after the axis header) from the shared CONTRACT block,
  // so the assertion tests the per-axis injection, not the global clue list.
  const region = axis1.prompt.split('너의 축: 1')[1]
  assert.ok(/AXIS1CLUEA/.test(region) && /AXIS1CLUEB/.test(region),
    'axis-1 candidate clues must render into the axis-1 question')
  assert.ok(!/AXIS5CLUE/.test(region),
    'clues bound to other axes must not render into the axis-1 question')
})

test('lockstep — CONTRACT gap-scope triad and Gate E scope triad both reference plugins/<target>', async () => {
  // A divergence between the two scope definitions (e.g. Gate E hardcoded to another plugin)
  // must be caught: both are built from the same target + extra_scope.
  const target = 'wibble'
  const args = {
    target,
    evidencePack: { ...DEFAULT_PACK, extra_scope: ['docs/wibble-extra/**'] },
    codexFindings: [],
  }
  const { calls } = await runWorkflow(WF, { args, stubAgent: stubOneFinding() })
  const contractPrompt = calls.find((c) => c.opts.phase === '감사').prompt
  const gateEPrompt = calls.find((c) => c.opts.phase === '검증').prompt
  assert.ok(contractPrompt.includes(`plugins/${target}`),
    'CONTRACT gap-scope triad must reference plugins/<target>')
  assert.ok(gateEPrompt.includes(`plugins/${target}`),
    'Gate E scope triad must reference plugins/<target> (lockstep with CONTRACT)')
  assert.ok(contractPrompt.includes('docs/wibble-extra/**'),
    'CONTRACT triad must include pack.extra_scope')
  assert.ok(gateEPrompt.includes('docs/wibble-extra/**'),
    'Gate E triad must include pack.extra_scope (lockstep with CONTRACT)')
})

test('row 4 — CONTRACT renders staleness facts, own-test result, precedent paths', async () => {
  const args = {
    target: 'sample',
    evidencePack: {
      ...DEFAULT_PACK,
      plugin_version: '1.7.2', file_count: 51, total_lines: 4879,
      staleness_facts: [
        { class: 'dangling doc-claim', quote: 'scripts/foo.sh', file: 'README.md', line: 12 },
      ],
      own_tests: { ran: true, total: 95, passed: 95, failed: 0 },
      precedent_paths: ['~/Downloads/reference/gstack/careful/bin/check-careful.sh'],
    },
    codexFindings: [],
  }
  const { calls } = await runWorkflow(WF, { args, stubAgent: stubOneFinding() })
  const p = calls.find((c) => c.opts.phase === '감사').prompt
  assert.ok(/staleness|결정론.*사실|dangling doc-claim/.test(p), 'staleness facts must render')
  assert.ok(/README\.md:12|scripts\/foo\.sh/.test(p), 'staleness fact quote+file:line must render')
  assert.ok(/95\/95/.test(p), 'own-test numeric line must render')
  assert.ok(/check-careful\.sh/.test(p), 'precedent path must render')
})

test('row 4b — CONTRACT degrades loudly when staleness/own-test absent', async () => {
  const { calls } = await runWorkflow(WF, { stubAgent: stubOneFinding() })
  const p = calls.find((c) => c.opts.phase === '감사').prompt
  // 기본 pack엔 staleness_facts/own_tests 없음 → "미실행/없음" 류 명시 (조용히 빠지지 않음).
  // 헤더는 무조건 방출되므로 body-unique fallback 리터럴로 assert (헤더-satisfiable 회피).
  assert.ok(/없음을 사실로 받는다/.test(p), 'empty staleness → loud fallback line')
  assert.ok(/자체 테스트 미실행/.test(p), 'absent own_tests → loud fallback line')
  assert.ok(/선례 코퍼스 부재/.test(p), 'absent precedent → loud fallback line')
})

test('row 5a — MEDIUM survivor outside deepPool has deep_verified === null (not undefined)', async () => {
  // stubOneFinding()의 기본 '검증' 응답({ verdicts: [] })은 "판정 누락" 병합-분기(!v, 이미
  // deep_verified:null을 세움)를 타 버려 이 테스트가 겨냥해야 할 "plain else"(축 refuter가
  // 살아서 명시적으로 안 죽인 생존자) 분기를 exercise하지 못한다 — 커스텀 stub으로
  // 명시적 non-refuted verdict('survives')를 줘서 정확한 분기를 겨냥한다.
  const stub = async (prompt, o) => {
    if (o.phase === '감사') {
      return {
        findings: [{
          id: 'A1-1', axis: 1, title: 't', user_harm: 'h', recommendation: 'r',
          counter_argument: 'c', evidence: [{ file: 'f', line: 1, quote: 'q' }],
          severity: 'MEDIUM', fix_cost: 'S', fix_cost_rationale: 'x', reference_gap: 'none',
        }],
        d_verdicts: [], oq_answers: [], new_open_questions: [],
      }
    }
    if (o.phase === '검증') return { verdicts: [{ finding_id: 'A1-1', verdict: 'survives', reason: 'ok' }] }
    return { verdicts: [] }
  }
  const { result } = await runWorkflow(WF, { stubAgent: stub })
  const f = result.findings.find((x) => x.id === 'A1-1')
  assert.equal(f.status, 'reported')
  assert.notEqual(f.unverified, true, 'genuinely axis-verified survivor must not be unverified')
  assert.strictEqual(f.deep_verified, null, 'must be explicit null, not undefined')
})

test('row 5b — refuter-dead-axis HIGH is not labeled deep_verified:true by lenses alone', async () => {
  // 축 refuter가 죽는다 (검증 phase에서 null 반환). HIGH finding은 unverified가 되고,
  // 심층 2렌즈가 refute하지 않아도 true 라벨을 받으면 안 된다.
  const stub = async (prompt, o) => {
    if (o.phase === '감사') {
      return {
        findings: [{
          id: 'A1-1', axis: 1, title: 't', user_harm: 'h', recommendation: 'r',
          counter_argument: 'c', evidence: [{ file: 'f', line: 1, quote: 'q' }],
          severity: 'HIGH', fix_cost: 'S', fix_cost_rationale: 'x', reference_gap: 'none',
        }],
        d_verdicts: [], oq_answers: [], new_open_questions: [],
      }
    }
    if (o.phase === '검증') return null           // ← refuter dies
    if (o.phase === '심층검증') return { finding_id: 'A1-1', refuted: false, reason: 'ok' }
    return { verdicts: [] }
  }
  const { result } = await runWorkflow(WF, { stubAgent: stub })
  const f = result.findings.find((x) => x.id === 'A1-1')
  assert.equal(f.status, 'reported')
  assert.equal(f.unverified, true, 'refuter death → unverified')
  assert.notEqual(f.deep_verified, true, 'must NOT be labeled true from deep lenses alone')
})

test('row 5 regression — normal surviving HIGH still gets deep_verified:true', async () => {
  // stubOneFinding('HIGH')를 문자로 그대로 쓰면 그 기본 '검증' 응답({ verdicts: [] })이 "판정
  // 누락"(!v) 분기를 타 unverified:true를 세워버려 — 가드가 진짜 "정상 생존"과 "축 검증
  // 누락"을 구분하는지가 아니라 우연히 같은 필드에 걸려 통과하는 위장 그린이 된다. 커스텀
  // stub으로 축 refuter가 명시적으로 생존시킨('survives') 진짜 정상 케이스를 만든다.
  const stub = async (prompt, o) => {
    if (o.phase === '감사') {
      return {
        findings: [{
          id: 'A1-1', axis: 1, title: 't', user_harm: 'h', recommendation: 'r',
          counter_argument: 'c', evidence: [{ file: 'f', line: 1, quote: 'q' }],
          severity: 'HIGH', fix_cost: 'S', fix_cost_rationale: 'x', reference_gap: 'none',
        }],
        d_verdicts: [], oq_answers: [], new_open_questions: [],
      }
    }
    if (o.phase === '검증') return { verdicts: [{ finding_id: 'A1-1', verdict: 'survives', reason: 'ok' }] }
    if (o.phase === '심층검증') return { finding_id: 'A1-1', refuted: false, reason: 'ok' }
    return { verdicts: [] }
  }
  const { result } = await runWorkflow(WF, { stubAgent: stub })
  const f = result.findings.find((x) => x.id === 'A1-1')
  assert.notEqual(f.unverified, true, 'genuinely axis-verified survivor must not be unverified')
  assert.equal(f.deep_verified, true)
})
