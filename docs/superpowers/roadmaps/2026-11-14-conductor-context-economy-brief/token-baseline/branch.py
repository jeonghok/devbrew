"""Token baseline - one session's responses grouped by the gitBranch of their lines. One JSON object.

  python3 -I branch.py --backup <backup folder> --session <label in sessions.json>
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import baseline_lib as lib  # noqa: E402

parser = lib.arg_parser(__doc__)
parser.add_argument('--session', required=True, help='session label from the config')
args = parser.parse_args()
backup, _, rel_of = lib.load(args)
if args.session not in rel_of:
    lib.die('unknown session label "%s"' % args.session)
guards = lib.Guards('jsonl_outside_subagents_layer', 'assistant_lines_without_usage',
                    'usage_without_message_id', 'message_id_in_two_files')
stats = collections.Counter()
responses = lib.Responses(guards)
body, subs = lib.session_files(backup, rel_of[args.session], guards)
for path in [body] + subs:
    for d in lib.records(path, guards):
        mu = lib.usage(d, stats, guards)
        if mu is None:
            continue
        m, u = mu
        r, state = responses.add(m['id'], lib.kinds(u), path)
        if state == 'new':
            r.update(part='body' if path == body else 'sub', branch=d.get('gitBranch') or '?')

agg = collections.defaultdict(collections.Counter)
for r in responses.rec.values():
    c = agg[(r['part'], r['branch'])]
    c['responses'] += 1
    for k in lib.K:
        c[k] += r[k]
rows = [dict(c, part=part, branch=branch) for (part, branch), c in
        sorted(agg.items(), key=lambda kv: -kv[1]['cache_read_input_tokens'])]
lib.emit(dict(session=args.session, branches=len(set(b for (_, b) in agg)), rows=rows), guards)
