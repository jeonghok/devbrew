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

test('WB1 — CONTRACT renders structure_facts/shape_gaps OBJECTS, not [object Object]', async () => {
  // 실제 producer는 OBJECT를 낸다 (check-plugin-structure.sh / check-shape-completeness.py).
  // 예전 bare `'  - ' + f` concat은 `[object Object]`를 배달했다 — REAL 오브젝트 shape를 주입해 봉쇄.
  const args = {
    target: 'sample',
    evidencePack: {
      ...DEFAULT_PACK,
      structure_facts: [{ validator: 'hook-linter.sh', target: 'x', fact: 'clean', verifier_ok: true }],
      shape_gaps: [{ requirement: 'plugin_json_fields', present: false, source_doc: 'CLAUDE.md' }],
    },
    codexFindings: [],
  }
  const { calls } = await runWorkflow(WF, { args, stubAgent: stubOneFinding() })
  const p = calls.find((c) => c.opts.phase === '감사').prompt
  assert.ok(/hook-linter\.sh/.test(p), 'structure_fact.validator must render')
  assert.ok(/plugin_json_fields/.test(p), 'shape_gap.requirement must render')
  assert.ok(!/\[object Object\]/.test(p),
    'objects must be field-formatted, not stringified to [object Object]')
})

test('WB3 — own_tests consumer reads the REAL contract shape (no undefined / null/null)', async () => {
  // producer(run-own-tests.sh)의 실제 shape: {ran, passed, total, forced_downgrade, why}.
  // passed/total은 현재 항상 null이고 .failed/.framework는 존재하지 않는다. 예전 소비자는
  // `null/null 통과, 실패 undefined건`을 렌더했다 — REAL shape로 graceful-null 소비를 봉쇄.
  const args = {
    target: 'sample',
    evidencePack: {
      ...DEFAULT_PACK,
      own_tests: { ran: true, passed: null, total: null, forced_downgrade: false, why: null },
    },
    codexFindings: [],
  }
  const { calls } = await runWorkflow(WF, { args, stubAgent: stubOneFinding() })
  const p = calls.find((c) => c.opts.phase === '감사').prompt
  assert.ok(!/undefined/.test(p), 'no undefined from never-produced own_tests fields')
  assert.ok(!/null\/null/.test(p), 'no null/null numeric render when passed/total are null')
  assert.ok(/자체 테스트: 샌드박스에서 실행됨/.test(p),
    'ran-but-uncounted own_tests must still render a signal line')
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

test('row 5a — SUGGESTION survivor outside deepPool has deep_verified === null (not undefined)', async () => {
  // stubOneFinding()의 기본 '검증' 응답({ verdicts: [] })은 "판정 누락" 병합-분기(!v, 이미
  // deep_verified:null을 세움)를 타 버려 이 테스트가 겨냥해야 할 "plain else"(축 refuter가
  // 살아서 명시적으로 안 죽인 생존자) 분기를 exercise하지 못한다 — 커스텀 stub으로
  // 명시적 non-refuted verdict('survives')를 줘서 정확한 분기를 겨냥한다.
  // (Task 28: 옛 MEDIUM → SUGGESTION — deepPool 밖이라는 의미는 그대로 보존)
  const stub = async (prompt, o) => {
    if (o.phase === '감사') {
      return {
        findings: [{
          id: 'A1-1', axis: 1, title: 't', user_harm: 'h', recommendation: 'r',
          counter_argument: 'c', evidence: [{ file: 'f', line: 1, quote: 'q' }],
          severity: 'SUGGESTION', fix_cost: 'S', fix_cost_rationale: 'x', reference_gap: 'none',
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

test('row 5b — refuter-dead-axis IMPORTANT is not labeled deep_verified:true by lenses alone', async () => {
  // 축 refuter가 죽는다 (검증 phase에서 null 반환). IMPORTANT finding은 unverified가 되고,
  // 심층 2렌즈가 refute하지 않아도 true 라벨을 받으면 안 된다.
  // (Task 28: 옛 HIGH → IMPORTANT — deepPool 안이라는 의미는 그대로 보존)
  const stub = async (prompt, o) => {
    if (o.phase === '감사') {
      return {
        findings: [{
          id: 'A1-1', axis: 1, title: 't', user_harm: 'h', recommendation: 'r',
          counter_argument: 'c', evidence: [{ file: 'f', line: 1, quote: 'q' }],
          severity: 'IMPORTANT', fix_cost: 'S', fix_cost_rationale: 'x', reference_gap: 'none',
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

test('row 5 regression — normal surviving IMPORTANT still gets deep_verified:true', async () => {
  // stubOneFinding('IMPORTANT')를 문자로 그대로 쓰면 그 기본 '검증' 응답({ verdicts: [] })이 "판정
  // 누락"(!v) 분기를 타 unverified:true를 세워버려 — 가드가 진짜 "정상 생존"과 "축 검증
  // 누락"을 구분하는지가 아니라 우연히 같은 필드에 걸려 통과하는 위장 그린이 된다. 커스텀
  // stub으로 축 refuter가 명시적으로 생존시킨('survives') 진짜 정상 케이스를 만든다.
  const stub = async (prompt, o) => {
    if (o.phase === '감사') {
      return {
        findings: [{
          id: 'A1-1', axis: 1, title: 't', user_harm: 'h', recommendation: 'r',
          counter_argument: 'c', evidence: [{ file: 'f', line: 1, quote: 'q' }],
          severity: 'IMPORTANT', fix_cost: 'S', fix_cost_rationale: 'x', reference_gap: 'none',
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

// codex 갈래의 «판정 누락» 회계. claude 갈래(:558)와 구조가 같은 두 갈래 중 하나만
// 침묵했던 것이 원 결함이므로, 한쪽만 잠그면 정확히 같은 방식으로 재발한다.
const CODEX_FINDING = {
  id: 'CX-1', axis: 2, title: 'ct', user_harm: 'ch', recommendation: 'cr',
  counter_argument: 'cc', evidence: [{ file: 'cf', line: 9, quote: 'cq' }],
  severity: 'IMPORTANT', fix_cost: 'S', fix_cost_rationale: 'x', reference_gap: 'none',
}

// codex 갈래만 살리는 stub — 감사 축은 발견 0건이라 축 refuter 가 아예 호출되지
// 않는다(:509 조기 반환). 그래서 degraded_events 에 남는 것은 codex 갈래의 것뿐이다.
const codexOnlyStub = (mergeVerdicts) => async (prompt, o) => {
  if (o.phase === '감사') return { findings: [], d_verdicts: [], oq_answers: [], new_open_questions: [] }
  if (o.phase === '병합') return { verdicts: mergeVerdicts }
  if (o.phase === '심층검증') return { finding_id: 'CX-1', refuted: false, reason: 'ok' }
  return { verdicts: [] }
}

const missedVerdictEvents = (result) =>
  result.degraded_events.filter((e) => /CX-1/.test(e.what) && /판정을 누락/.test(e.what))

// 축(claude) 갈래의 같은 사건. codex 쪽과 «구조가 같은 두 갈래»라, 한쪽만 잠그면
// 원 결함이 정확히 같은 방식으로 다른 갈래에서 재발한다.
const axisMissedVerdictEvents = (result) =>
  result.degraded_events.filter((e) => /A1-1/.test(e.what) && /판정을 누락/.test(e.what))

test('결함 #9 — codex 갈래에서 refuter 가 판정을 누락하면 degradedEvents 에 쌓인다', async () => {
  const args = { target: 'sample', evidencePack: DEFAULT_PACK, codexFindings: [CODEX_FINDING] }
  // refuter 는 응답했지만 CX-1 에 대한 verdict 가 없다. 침묵은 판정이 아니다.
  const { result } = await runWorkflow(WF, { args, stubAgent: codexOnlyStub([]) })

  const f = result.findings.find((x) => x.id === 'CX-1')
  assert.equal(f.source, 'codex')
  assert.equal(f.unverified, true, '판정 누락 → unverified')
  assert.equal(missedVerdictEvents(result).length, 1,
    'codex 갈래의 판정 누락이 degraded_events 로 공시돼야 한다 — ' +
    '세지 않고 버리면 미검증 발견이 검증된 것으로 읽힌다')
})

test('결함 #9 양성 짝 — refuter 가 판정하면 그 공시는 나오지 않는다', async () => {
  // 항상 켜지는 공시는 공시가 아니다. 위 단언이 «판정 누락»을 재는지, 아니면
  // codexFindings 가 있기만 하면 켜지는지를 이 짝이 가른다.
  const args = { target: 'sample', evidencePack: DEFAULT_PACK, codexFindings: [CODEX_FINDING] }
  const verdicts = [{ finding_id: 'CX-1', verdict: 'survives', reason: 'ok' }]
  const { result } = await runWorkflow(WF, { args, stubAgent: codexOnlyStub(verdicts) })

  const f = result.findings.find((x) => x.id === 'CX-1')
  assert.notEqual(f.unverified, true, '판정을 받은 finding 은 unverified 가 아니다')
  assert.equal(missedVerdictEvents(result).length, 0)
})

test('결함 #9 대칭 절반 — 축 갈래에서 refuter 가 판정을 누락하면 degradedEvents 에 쌓인다', async () => {
  // stubOneFinding() 의 '검증' 응답은 { verdicts: [] } 라 A1-1 에 대한 판정이 없다 —
  // 그것이 축 갈래의 «판정 누락» 분기다. codex 쪽과 대칭인 자리이고, 이 단언이
  // 없으면 그 push 를 지워도 스위트가 조용하다(실측).
  const { result } = await runWorkflow(WF, { stubAgent: stubOneFinding() })

  // 축 수를 리터럴로 박지 않는다 — 스텁이 축마다 같은 finding 을 내므로 그 수는
  // 축 개수를 따라 움직인다. 계약은 «미검증 finding 마다 정확히 하나의 공시» 다.
  const unverified = result.findings.filter((x) => x.id === 'A1-1' && x.unverified === true)
  assert.ok(unverified.length > 0, '판정 누락 케이스가 실제로 만들어졌다 — 전제 확인')
  assert.equal(axisMissedVerdictEvents(result).length, unverified.length,
    '축 갈래의 판정 누락도 degraded_events 로 공시돼야 한다 — ' +
    '한쪽 갈래만 잠그면 원 결함이 다른 갈래에서 그대로 재발한다')
})

test('결함 #9 대칭 절반 양성 짝 — 축 refuter 가 판정하면 그 공시는 나오지 않는다', async () => {
  // 항상 켜지는 공시는 공시가 아니다. 위 단언이 «판정 누락»을 재는지, 아니면
  // 축 finding 이 있기만 하면 켜지는지를 이 짝이 가른다.
  const stub = async (prompt, o) => {
    if (o.phase === '감사') {
      return {
        findings: [{
          id: 'A1-1', axis: 1, title: 't', user_harm: 'h', recommendation: 'r',
          counter_argument: 'c', evidence: [{ file: 'f', line: 1, quote: 'q' }],
          severity: 'IMPORTANT', fix_cost: 'S', fix_cost_rationale: 'x', reference_gap: 'none',
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
  assert.notEqual(f.unverified, true, '판정을 받은 finding 은 unverified 가 아니다')
  assert.equal(axisMissedVerdictEvents(result).length, 0)
})
