"""Token baseline - cache writes after a wait longer than the cache lifetime. One JSON object.

  python3 -I gap.py --backup <backup folder> [--threshold 300 --threshold 3600]

Unit: one transcript file (the body, or one sub agent). Its responses are put in time order by the
time of their first line. A response is "after a wait" when its first line is more than the
threshold (seconds) later than the first line of the response before it in the same file; the
first response of a file has no response before it and is never one. For such responses the script
sums the cache write and gives its share of all cache writes of that part of the session.

Also printed: the same share measured from the last line of the response before (a check on the
choice of clock), how many of those responses read less from the cache than they wrote, and the
first responses of the files (an agent starting cold).
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import baseline_lib as lib  # noqa: E402

parser = lib.arg_parser(__doc__)
parser.add_argument('--threshold', type=int, action='append', help='seconds; repeatable (default 300 and 3600)')
args = parser.parse_args()
thresholds = args.threshold or [300, 3600]
backup, _, rel_of = lib.load(args)
guards = lib.Guards(*lib.USAGE_GUARDS, 'jsonl_outside_subagents_layer', 'message_id_in_two_files')
stats = collections.Counter()
responses = lib.Responses(guards)
CW, CR = 'cache_creation_input_tokens', 'cache_read_input_tokens'


def share(x, total):
    return round(x / total * 100, 1) if total else None


def measure(paths):
    tot = collections.Counter()
    first = collections.Counter()
    over = {th: collections.Counter() for th in thresholds}
    for path in paths:
        prev = None
        for r in lib.timed_responses(path, responses, stats, guards):
            tot['responses'] += 1
            tot[CW] += r[CW]
            tot[CR] += r[CR]
            if prev is None:
                first['files'] += 1
                first[CW] += r[CW]
                first[CR] += r[CR]
                first['read_nothing'] += r[CR] == 0
            else:
                for th, c in over.items():
                    if r['t0'] - prev['t0'] > th:
                        c['responses'] += 1
                        c[CW] += r[CW]
                        c[CR] += r[CR]
                        if r[CR] < r[CW]:
                            c['read_less_than_written'] += 1
                            c['cache_write_of_those'] += r[CW]
                    if r['t0'] - prev['t1'] > th:
                        c['responses_from_last_line'] += 1
                        c['cache_write_from_last_line'] += r[CW]
            prev = r
    out = dict(responses=tot['responses'], cache_write=tot[CW], cache_read=tot[CR], after_wait={},
               first_response_of_file=dict(files=first['files'], cache_write=first[CW], cache_read=first[CR],
                                           share_of_cache_write=share(first[CW], tot[CW]),
                                           read_nothing=first['read_nothing']))
    for th, c in over.items():
        out['after_wait'][str(th)] = dict(
            responses=c['responses'], share_of_responses=round(c['responses'] / tot['responses'] * 100, 2),
            cache_write=c[CW], share_of_cache_write=share(c[CW], tot[CW]), cache_read=c[CR],
            read_less_than_written=c['read_less_than_written'], cache_write_of_those=c['cache_write_of_those'],
            from_last_line=dict(responses=c['responses_from_last_line'], cache_write=c['cache_write_from_last_line'],
                                share_of_cache_write=share(c['cache_write_from_last_line'], tot[CW])))
    return out


result = {}
for s, rel in rel_of.items():
    body, subs = lib.session_files(backup, rel, guards)
    result[s] = dict(body=measure([body]))
    if subs:
        result[s]['sub'] = measure(subs)
lib.emit(dict(thresholds_seconds=thresholds, sessions=result), guards)
