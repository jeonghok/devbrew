"""Token baseline - checks over the whole backup. Prints one JSON object.

  python3 -I extra.py --backup <backup folder>

1. Which usage fields differ among the repeats of one message.id, and whether the larger value is
   always the value of the last line (the observation next to rule 2).
2. Files and token totals of every backup file by class, so that what was left out carries numbers:
   <session>:body / :sub / :sdk for the configured sessions, other:main:<entrypoint> for the other
   top-level sessions, other:sub for their sub agents.
3. The worktrees the left-out sdk sessions ran in.
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import baseline_lib as lib  # noqa: E402

args = lib.arg_parser(__doc__).parse_args()
backup, _, rel_of = lib.load(args)
guards = lib.Guards(*lib.USAGE_GUARDS, 'jsonl_in_unknown_layout', 'message_id_in_two_files')
stats = collections.Counter()
files = lib.backup_files(backup, guards)
owner = {}
for path, kind in files:
    rel = os.path.relpath(path, backup)
    for s, r in rel_of.items():
        if kind == 'sub' and rel.startswith(r + os.sep):
            owner[lib.agent_id(path)] = s


def classify(path, kind):
    rel = os.path.relpath(path, backup)
    for s, r in rel_of.items():
        if rel == r + '.jsonl':
            return s + ':body'
        if kind == 'sub' and rel.startswith(r + os.sep):
            return s + ':sub'
    if kind == 'sub':
        return 'other:sub'
    proj = rel.split(os.sep)[0]
    if lib.AGENT_WORKTREE_MARK in proj and proj.split(lib.AGENT_WORKTREE_MARK, 1)[1] in owner:
        return owner[proj.split(lib.AGENT_WORKTREE_MARK, 1)[1]] + ':sdk'
    return 'other:main'


responses = lib.Responses(guards)
differs_from_previous_line = collections.Counter()
file_count = collections.Counter()
left_out_sdk_worktrees = collections.Counter()
for path, kind in files:
    info = dict(cls=classify(path, kind))
    entrypoint = None
    for d in lib.records(path, guards):
        entrypoint = entrypoint or d.get('entrypoint')
        mu = lib.usage(d, stats, guards)
        if mu is None:
            continue
        m, u = mu
        vals = lib.kinds(u)
        r, state = responses.add(m['id'], vals, path)
        if state == 'new':
            r['info'] = info
        else:
            for k in lib.K:
                differs_from_previous_line[k] += vals[k] != r['last'][k]
        r['last'] = vals
    if info['cls'] == 'other:main':
        info['cls'] += ':' + (entrypoint or '?')
        if entrypoint == 'sdk-py':
            left_out_sdk_worktrees[lib.worktree_name(os.path.relpath(path, backup).split(os.sep)[0])] += 1
    file_count[info['cls']] += 1

totals = collections.defaultdict(collections.Counter)
larger_is_not_last = collections.Counter()
for r in responses.rec.values():
    c = totals[r['info']['cls']]
    c['responses'] += 1
    for k in lib.K:
        c[k] += r[k]
        larger_is_not_last[k] += r[k] != r['last'][k]

lib.emit(dict(
    repeat_lines_differing_from_previous_line={k: v for k, v in differs_from_previous_line.items() if v},
    responses_whose_larger_value_is_not_the_last_line={k: v for k, v in larger_is_not_last.items() if v},
    files=dict(sorted(file_count.items())),
    totals={k: dict(v) for k, v in sorted(totals.items())},
    left_out_sdk_worktrees=dict(left_out_sdk_worktrees.most_common()),
    synthetic_excluded=stats['synthetic_excluded'],
), guards)
