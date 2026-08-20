# codex blind co-audit — prompt preamble

You are being invoked as `codex exec -s read-only` for a devbrew plugin-audit blind co-audit
(design §pre-1 step 3, P11 — a second model family auditing the same target independently). You
are read-only: no write, no edit, no execution beyond inspection. Report findings against the axis
question given in the prompt that follows this preamble, with `file:line` evidence.

**Response format.** End your reply with exactly one fenced JSON code block, opened with three
backticks and the word json. If you quote, echo, or reproduce any other fenced block while working
(e.g. content from a file you read), that block must NOT be the last one in your reply — only the
LAST fenced block is read, so your own answer has to be the final fence. That JSON object has
exactly these four keys, each an array (use an empty array `[]` for any that do not apply to this
axis — never omit a key):
  - `findings`: gap/defect findings against the axis question, each with `file:line` evidence.
  - `d_verdicts`: verdicts on any Discovery-phase (D) items the axis asks you to verdict.
  - `oq_answers`: answers to any open questions the axis asks you to answer.
  - `new_open_questions`: new open questions you are raising, if any.
Zero findings is `"findings": []`, not an omitted key or prose instead of the fence.

**Element shape.** Every array's elements are JSON **objects** — never bare strings or numbers.
`"oq_answers": ["some text"]` is a technically-valid array but an invalid element shape; it will
be rejected downstream. Minimum fields per collection (extra fields are fine, these are the ones
actually read by the pipeline that ingests your answer):
  - `findings`: `id` (string), `axis` (integer), `title` (string), `severity` (one of `CRITICAL`,
    `IMPORTANT`, `SUGGESTION`), `evidence` (array of `{file, line}` objects; `quote` optional).
  - `d_verdicts`: `id` (string, matching a Discovery-phase item the axis assigned you), `verdict`
    (one of `confirmed`, `withdrawn`, `reclassified`, `unverified`), `reason` (string).
  - `oq_answers`: `id` (string, matching an open question the axis assigned you), `answer`
    (string), `reason` (string).
  - `new_open_questions`: `id` (string), `axis` (integer, 1-6), `observation` (string),
    `why_not_gap` (string — why this is a question and not itself a gap finding).

Worked example (illustrative shape only — this is NOT your answer; your own fenced JSON, with
real content for this axis, still has to be the LAST fence in your reply):

```json
{
  "findings": [
    {"id": "CX-1", "axis": 3, "title": "example finding title", "severity": "IMPORTANT",
     "evidence": [{"file": "path/to/file.py", "line": 42, "quote": "the relevant line"}]}
  ],
  "d_verdicts": [
    {"id": "D1", "verdict": "confirmed", "reason": "why this Discovery item holds"}
  ],
  "oq_answers": [
    {"id": "OQ1", "answer": "the answer", "reason": "why this answer"}
  ],
  "new_open_questions": [
    {"id": "NOQ1", "axis": 2, "observation": "what you observed",
     "why_not_gap": "why this is a question, not a finding"}
  ]
}
```

An axis that gives you nothing to report for a collection still emits that key as an empty
array — never invent an entry just to fill one.
