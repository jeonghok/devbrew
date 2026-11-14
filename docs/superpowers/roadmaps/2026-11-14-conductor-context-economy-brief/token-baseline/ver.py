"""Token baseline - output per response by harness version. One JSON object.

  python3 -I ver.py --backup <backup folder>

For the configured sessions, body and sub agents apart, per version: responses, output tokens per
response, share of responses with output <= 5, share of responses none of whose lines carries a
stop_reason. This is how under-recorded sub-agent output shows up.
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import baseline_lib as lib  # noqa: E402

args = lib.arg_parser(__doc__).parse_args()
backup, _, rel_of = lib.load(args)
guards = lib.Guards(*lib.USAGE_GUARDS, 'jsonl_outside_subagents_layer', 'message_id_in_two_files')
stats = collections.Counter()
responses = lib.Responses(guards)
for rel in rel_of.values():
    body, subs = lib.session_files(backup, rel, guards)
    for path in [body] + subs:
        for d in lib.records(path, guards):
            mu = lib.usage(d, stats, guards)
            if mu is None:
                continue
            m, u = mu
            r, state = responses.add(m['id'], lib.kinds(u), path)
            if state == 'new':
                r.update(part='body' if path == body else 'sub', ver=d.get('version'), stop=None)
            r['stop'] = r['stop'] or m.get('stop_reason')

agg = collections.defaultdict(collections.Counter)
for r in responses.rec.values():
    c = agg['%s|%s' % (r['part'], r['ver'])]
    c['n'] += 1
    c['out'] += r['output_tokens']
    c['tiny'] += r['output_tokens'] <= 5
    c['no_stop'] += r['stop'] is None
by_part_and_version = dict()
for key, c in sorted(agg.items()):
    by_part_and_version[key] = dict(n=c['n'], out_per_resp=round(c['out'] / c['n'], 1),
                                    tiny_share=round(c['tiny'] / c['n'], 3),
                                    stop_none_share=round(c['no_stop'] / c['n'], 3))
lib.emit(dict(by_part_and_version=by_part_and_version), guards)
