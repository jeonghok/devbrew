"""Token baseline - the sums without rule 1, and skill attribution around the first call. One JSON object.

  python3 -I naive.py --backup <backup folder>

1. Line-by-line usage sums of the configured sessions (body + sub agents) with no message.id
   de-duplication: the size of the error rule 1 removes.
2. For the sessions in split_at_first_call: attributionSkill of the body responses before (pre)
   and after (cond) the first call of the skill.
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import baseline_lib as lib  # noqa: E402

args = lib.arg_parser(__doc__).parse_args()
backup, cfg, rel_of = lib.load(args)
guards = lib.Guards(*lib.USAGE_GUARDS, 'jsonl_outside_subagents_layer', 'session_without_skill_call',
                    'skill_call_without_timestamp')
stats = collections.Counter()
naive = collections.Counter()
attribution = {}
for s, rel in rel_of.items():
    body, subs = lib.session_files(backup, rel, guards)
    calls = []
    first_lines = {}
    for path in [body] + subs:
        for d in lib.records(path, guards):
            called_at = lib.call_time(d, cfg['skill'], guards) if path == body else None
            if called_at:
                calls.append(called_at)
            mu = lib.usage(d, stats, guards)
            if mu is None:
                continue
            m, u = mu
            naive['lines'] += 1
            for k, value in lib.kinds(u).items():
                naive[k] += value
            if path == body:
                first_lines.setdefault(m['id'], (d.get('timestamp') or '', d.get('attributionSkill') or '(none)'))
    if s in cfg['split_at_first_call']:
        if not calls:
            guards['session_without_skill_call'] += 1
            continue
        seg = dict(pre=collections.Counter(), cond=collections.Counter())
        for ts, name in first_lines.values():
            seg['pre' if ts < min(calls) else 'cond'][name] += 1
        attribution[s] = dict(calls=sorted(calls), pre=dict(seg['pre'].most_common()), cond=dict(seg['cond'].most_common()))

lib.emit(dict(naive=dict(naive), attribution=attribution), guards)
