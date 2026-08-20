import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = path.dirname(fileURLToPath(import.meta.url))
// tests → plugin-audit → plugins → repo root. scriptRel is repo-root-relative
// (`plugins/plugin-audit/scripts/audit-workflow.js`) so it matches how the real Workflow
// tool references the script.
const REPO = path.resolve(HERE, '..', '..', '..')
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor

// Generic sample pack — target-agnostic. Real callers inject a seed-derived pack (§13).
// candidate_clues/open_questions default to [] so the schema enums are omitted (not enum:[]).
export const DEFAULT_PACK = {
  plugin_version: '0.0.0', file_count: 10, total_lines: 500,
  staleness_facts: [], own_tests: null, precedent_paths: [],
  extra_scope: [], open_questions: [], candidate_clues: [],
  structure_facts: [], shape_gaps: [], steelman_hints: [],
}

// Run a Workflow script (top-level await + return) by wrapping it in an AsyncFunction and
// injecting the harness globals as parameters. `export const meta` is stripped (the only ESM
// token; there are no `import`s). The stubs let us capture the schema passed to each agent()
// and control returns to exercise the merge/deep branches.
export async function runWorkflow(scriptRel, opts = {}) {
  const src = fs.readFileSync(path.join(REPO, scriptRel), 'utf8')
    .replace(/^export const meta/m, 'const meta')
  const captured = {}
  const calls = []
  const stubAgent = opts.stubAgent || (async () => ({ findings: [], verdicts: [] }))
  const agent = async (prompt, o = {}) => {
    if (o.phase) captured[o.phase] = o.schema
    calls.push({ prompt, opts: o })
    return stubAgent(prompt, o)
  }
  const pipeline = async (items, ...stages) => {
    const out = []
    for (let idx = 0; idx < items.length; idx++) {
      let v = items[idx]
      for (const s of stages) v = await s(v, items[idx], idx)
      out.push(v)
    }
    return out
  }
  const parallel = async (thunks) => Promise.all(thunks.map((t) => t()))
  const phase = () => {}
  const log = () => {}
  // Object-form args — the workflow normalizes (typeof args === 'string' ? JSON.parse : ...),
  // so an object here is a valid injection and exercises the same code path as a JSON string.
  const args = opts.args || { target: 'sample', evidencePack: DEFAULT_PACK, codexFindings: [] }
  const run = new AsyncFunction('agent', 'pipeline', 'parallel', 'phase', 'log', 'args', src)
  const result = await run(agent, pipeline, parallel, phase, log, args)
  return { result, captured, calls }
}

// A stub that returns one finding of the given severity for the audit phase, an empty
// (non-killing) refuter verdict, and a non-refuting deep vote. Callers override per test.
// The phase keys (감사/검증/병합/심층검증) are ENGINE phase names — target-independent.
export function stubOneFinding(severity = 'IMPORTANT', extra = {}) {
  return async (prompt, o) => {
    if (o.phase === '감사') {
      return {
        findings: [{
          id: 'A1-1', axis: 1, title: 't', user_harm: 'h', recommendation: 'r',
          counter_argument: 'c', evidence: [{ file: 'f', line: 1, quote: 'q' }],
          severity, fix_cost: 'S', fix_cost_rationale: 'x', ...extra,
        }],
        d_verdicts: [], oq_answers: [], new_open_questions: [],
      }
    }
    if (o.phase === '검증' || o.phase === '병합') return { verdicts: [] }
    if (o.phase === '심층검증') return { finding_id: 'A1-1', refuted: false, reason: 'ok' }
    return {}
  }
}
