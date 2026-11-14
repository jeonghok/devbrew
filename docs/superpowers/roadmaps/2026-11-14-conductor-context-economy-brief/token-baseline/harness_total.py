"""Token baseline - the harness's own running total next to the assistant-line sums. One JSON object.

  python3 -I harness_total.py --backup <backup folder>

The body transcript of a session carries `cost-state` lines: the usage the harness itself has added
up for the session so far (modelUsage per model; sub agents are in it). For
every configured session this prints each distinct cost-state value in file order next to the
assistant-line sum (rules 1-3, body + sub agents) of the responses recorded up to that point, their
ratio, and the difference per tool call. `final` compares the last cost-state with all responses,
`all_sessions` adds the finals up. sdk sessions are separate sessions and are left out of the
assistant-line side; whether the harness total holds them was not checked.
"""
import collections
import datetime
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import baseline_lib as lib  # noqa: E402

args = lib.arg_parser(__doc__).parse_args()
backup, _, rel_of = lib.load(args)
guards = lib.Guards('jsonl_outside_subagents_layer', 'assistant_lines_without_usage',
                    'usage_without_message_id', 'message_id_in_two_files', 'session_without_cost_state')
stats = collections.Counter()
HARNESS = dict(input_tokens='inputTokens', cache_creation_input_tokens='cacheCreationInputTokens',
               cache_read_input_tokens='cacheReadInputTokens', output_tokens='outputTokens')


def harness_sum(usages):
    return {k: sum((u.get(name) or 0) for u in usages) for k, name in HARNESS.items()}


def compare(harness, recs):
    lines = collections.Counter()
    tool_calls = set()
    for r in recs:
        lines['responses'] += 1
        tool_calls |= r['tool_calls']
        for k in lib.K:
            lines[k] += r[k]
    out = dict(harness=harness, assistant_lines=dict(lines), tool_calls=len(tool_calls),
               ratio={k: round(harness[k] / lines[k], 3) if lines[k] else None for k in lib.K})
    if tool_calls:
        out['difference_per_tool_call'] = {k: round((harness[k] - lines[k]) / len(tool_calls), 1) for k in lib.K}
    return out


result = {}
all_recs = []
all_final = []
for s, rel in rel_of.items():
    body, subs = lib.session_files(backup, rel, guards)
    responses = lib.Responses(guards)
    request_lines = collections.Counter()
    states = []
    first_ts = last_ts = None
    for path in [body] + subs:
        part = 'body' if path == body else 'sub'
        for d in lib.records(path, guards):
            if path == body and d.get('timestamp'):
                first_ts = first_ts or d['timestamp']
                last_ts = d['timestamp']
            if d.get('type') == 'api-request':
                request_lines[part] += 1
            elif d.get('type') == 'cost-state' and path == body:
                states.append(dict(after=last_ts, start=d.get('startTime'), usage=d.get('modelUsage') or {}))
            mu = lib.usage(d, stats, guards)
            if mu is None:
                continue
            m, u = mu
            r, state = responses.add(m['id'], lib.kinds(u), path)
            if state == 'new':
                r.update(ts=d.get('timestamp') or '', part=part, model=m.get('model'), tool_calls=set())
            r['tool_calls'] |= set(x.get('id') for x in lib.tool_uses(m))
    if not states:
        guards['session_without_cost_state'] += 1
        continue
    recs = list(responses.rec.values())
    points = []
    for st in states:
        harness = harness_sum(st['usage'].values())
        if points and points[-1]['harness'] == harness:
            continue
        point = compare(harness, [r for r in recs if r['ts'] <= (st['after'] or '')])
        point['after_line_at'] = st['after']
        points.append(point)
    last = states[-1]
    final = compare(harness_sum(last['usage'].values()), recs)
    all_recs += recs
    all_final += last['usage'].values()
    final['by_model'] = {}
    for model, usage in sorted(last['usage'].items()):
        final['by_model'][model] = compare(harness_sum([usage]), [r for r in recs if r['model'] == model])
    start = last['start']
    result[s] = dict(
        cost_state_lines=len(states), points=points, final=final,
        harness_start=datetime.datetime.fromtimestamp(start / 1000, datetime.timezone.utc).isoformat() if start else None,
        first_line_at=first_ts,
        responses_after_last_cost_state=sum(1 for r in recs if r['ts'] > (last['after'] or '')),
        responses=dict(collections.Counter(r['part'] for r in recs)), request_lines=dict(request_lines))
lib.emit(dict(sessions=result, all_sessions=compare(harness_sum(all_final), all_recs)), guards)
