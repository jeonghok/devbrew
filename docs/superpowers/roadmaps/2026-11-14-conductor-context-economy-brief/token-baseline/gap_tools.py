"""Token baseline - what a sub agent was doing before a wait longer than the cache lifetime. One JSON object.

  python3 -I gap_tools.py --backup <backup folder> [--threshold 300]

Same unit, order and wait as gap.py, sub agents only. The responses after a wait are grouped by the
tools the response before them called ("(no tool)" = that response ended the agent's turn), with the
count, the cache write of the responses after the wait, its share of all sub-agent cache writes of
the session and the mean wait in minutes.
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import baseline_lib as lib  # noqa: E402

parser = lib.arg_parser(__doc__)
parser.add_argument('--threshold', type=int, default=300, help='seconds (default 300)')
args = parser.parse_args()
backup, _, rel_of = lib.load(args)
guards = lib.Guards(*lib.USAGE_GUARDS, 'jsonl_outside_subagents_layer', 'message_id_in_two_files')
stats = collections.Counter()
responses = lib.Responses(guards)
CW = 'cache_creation_input_tokens'

result = {}
for s, rel in rel_of.items():
    _, subs = lib.session_files(backup, rel, guards)
    if not subs:
        continue
    total = 0
    by = collections.defaultdict(collections.Counter)
    for path in subs:
        prev = None
        for r in lib.timed_responses(path, responses, stats, guards):
            total += r[CW]
            if prev is not None and r['t0'] - prev['t0'] > args.threshold:
                c = by['+'.join(sorted(prev['tools'])) or '(no tool)']
                c['responses'] += 1
                c[CW] += r[CW]
                c['wait_seconds'] += r['t0'] - prev['t0']
            prev = r
    rows = [dict(previous_tools=key, responses=c['responses'], cache_write=c[CW],
                 share_of_cache_write=round(c[CW] / total * 100, 1) if total else None,
                 mean_wait_minutes=round(c['wait_seconds'] / c['responses'] / 60))
            for key, c in sorted(by.items(), key=lambda kv: -kv[1][CW])]
    result[s] = dict(sub_cache_write=total, after_wait_responses=sum(r['responses'] for r in rows),
                     after_wait_cache_write=sum(r['cache_write'] for r in rows), by_previous_tools=rows)
lib.emit(dict(threshold_seconds=args.threshold, sessions=result), guards)
