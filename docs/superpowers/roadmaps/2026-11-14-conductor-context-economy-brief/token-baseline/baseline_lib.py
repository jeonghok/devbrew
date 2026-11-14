"""Reading rules shared by the token-baseline scripts (rules 1-8 of ../token-baseline.md).

Every script opens the backup for reading only. A condition under which a sum would be
silently wrong is counted in Guards; a non-zero count stops the run with exit code 3
and no result on stdout.
"""
import argparse
import collections
import datetime
import glob
import json
import os
import sys

K = ('input_tokens', 'cache_creation_input_tokens', 'cache_read_input_tokens', 'output_tokens')
GUARD_RC = 3
USAGE_RC = 2
HERE = os.path.dirname(os.path.abspath(__file__))
WORKTREE_MARK = '--claude-worktrees-'
AGENT_WORKTREE_MARK = WORKTREE_MARK + 'agent-'


def die(message):
    print('error: ' + message, file=sys.stderr)
    sys.exit(USAGE_RC)


def arg_parser(doc):
    p = argparse.ArgumentParser(description=doc, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--backup', required=True, help='transcript backup folder (read only)')
    p.add_argument('--config', default=os.path.join(HERE, 'sessions.json'),
                   help='session table (default: sessions.json next to the scripts)')
    return p


def load(args):
    """Return (backup, config, {label: session path relative to the backup, without .jsonl})."""
    backup = os.path.abspath(os.path.expanduser(args.backup))
    if not os.path.isdir(backup):
        die('backup folder not found')
    with open(args.config, encoding='utf-8') as fh:
        cfg = json.load(fh)
    for key in ('skill', 'sessions', 'split_at_first_call', 'output_underreported_patch_range', 'marker_scripts'):
        if key not in cfg:
            die('config has no "%s"' % key)
    rel = {}
    for label, sid in cfg['sessions'].items():
        hits = glob.glob(os.path.join(glob.escape(backup), '*', sid + '.jsonl'))
        if len(hits) != 1:
            die('session %s (%s): %d files in the backup, expected 1' % (label, sid, len(hits)))
        rel[label] = os.path.relpath(hits[0], backup)[:-len('.jsonl')]
    for label in cfg['split_at_first_call']:
        if label not in rel:
            die('split_at_first_call names an unknown session "%s"' % label)
    return backup, cfg, rel


class Guards(collections.Counter):
    """Counts that must all be zero for the result to be usable."""

    def __init__(self, *names):
        super().__init__()
        for name in ('unparsable_lines', 'files_not_utf8') + names:
            self[name] = 0

    def stop_if_any(self):
        bad = sorted((k, v) for k, v in self.items() if v)
        if bad:
            for k, v in bad:
                print('guard: %s = %d' % (k, v), file=sys.stderr)
            print('stopped: the counts above must be 0 - no result was written', file=sys.stderr)
            sys.exit(GUARD_RC)


def emit(out, guards):
    """Print the result as JSON, unless a guard fired."""
    guards.stop_if_any()
    out['guards_checked_zero'] = sorted(guards)
    json.dump(out, sys.stdout, ensure_ascii=True, indent=1)
    sys.stdout.write('\n')


def records(path, guards, with_text=False):
    """Yield every line of a transcript file as a dict (with_text: as (dict, raw line)).

    A line that is not a JSON object, and a file that is not UTF-8, is counted, never skipped silently.
    """
    try:
        with open(path, encoding='utf-8') as fh:
            for line in fh:
                if not line.strip():
                    continue
                try:
                    d = json.loads(line)
                except ValueError:
                    d = None
                if not isinstance(d, dict):
                    guards['unparsable_lines'] += 1
                    continue
                yield (d, line) if with_text else d
    except UnicodeDecodeError:
        guards['files_not_utf8'] += 1


def session_files(backup, rel, guards):
    """(body path, sorted sub-agent paths) of one session.

    Rule 4 assumes sub agents live at <session>/subagents/agent-*.jsonl. Any other .jsonl
    under the session folder is counted instead of being left out or guessed at.
    """
    top = os.path.join(backup, rel)
    subs = []
    for root, dirs, files in os.walk(top):
        dirs.sort()
        for name in sorted(files):
            if not name.endswith('.jsonl'):
                continue
            if os.path.relpath(root, top) == 'subagents' and name.startswith('agent-'):
                subs.append(os.path.join(root, name))
            else:
                guards['jsonl_outside_subagents_layer'] += 1
    return os.path.join(backup, rel + '.jsonl'), subs


def agent_id(path):
    return os.path.basename(path)[len('agent-'):-len('.jsonl')]


def backup_files(backup, guards):
    """Every .jsonl of the backup as (path, 'main' | 'sub'). Unknown layouts are counted."""
    out = []
    for root, dirs, files in os.walk(backup):
        dirs.sort()
        for name in sorted(files):
            if not name.endswith('.jsonl'):
                continue
            parts = os.path.relpath(os.path.join(root, name), backup).split(os.sep)
            if len(parts) == 2:
                out.append((os.path.join(root, name), 'main'))
            elif len(parts) == 4 and parts[2] == 'subagents' and name.startswith('agent-'):
                out.append((os.path.join(root, name), 'sub'))
            else:
                guards['jsonl_in_unknown_layout'] += 1
    return out


def worktree_name(project_dir):
    """Name of the worktree a project folder stands for ('(repo root)' when it is not a worktree)."""
    if WORKTREE_MARK in project_dir:
        return project_dir.split(WORKTREE_MARK, 1)[1]
    return '(repo root)'


def usage(d, stats, guards):
    """(message, usage) when the line is an assistant line that counts under rules 1 and 5, else None."""
    if d.get('type') != 'assistant':
        return None
    m = d.get('message') or {}
    u = m.get('usage')
    if not u:
        guards['assistant_lines_without_usage'] += 1
        return None
    if m.get('model') == '<synthetic>':
        stats['synthetic_excluded'] += 1
        stats['synthetic_tokens'] += sum((u.get(k) or 0) for k in K)
        return None
    if not m.get('id'):
        guards['usage_without_message_id'] += 1
        return None
    return m, u


class Responses:
    """message.id -> record. Rule 1: an id counts once. Rule 2: repeats keep the larger value per field."""

    def __init__(self, guards, fields=K):
        self.rec = {}
        self.guards = guards
        self.fields = fields

    def add(self, mid, vals, where):
        """Merge one line. Returns (record, 'new' | 'same' | 'differs'); `where` is the file it is in."""
        r = self.rec.get(mid)
        if r is None:
            r = self.rec[mid] = dict(vals, where=where)
            return r, 'new'
        if r['where'] != where:
            self.guards['message_id_in_two_files'] += 1
        state = 'differs' if any(r[k] != vals[k] for k in K) else 'same'
        for k in self.fields:
            r[k] = max(r[k], vals[k])
        return r, state


def kinds(u):
    return {k: (u.get(k) or 0) for k in K}


def skill_call(d, skill):
    """Rule 7: 'slash' for a user line carrying the slash command, 'skill_tool' for a Skill tool call, else None."""
    t = d.get('type')
    c = (d.get('message') or {}).get('content')
    if t == 'user':
        if isinstance(c, list):
            c = ' '.join((x.get('text') or '') for x in c if isinstance(x, dict) and x.get('type') == 'text')
        if isinstance(c, str) and ('<command-name>/%s</command-name>' % skill) in c:
            return 'slash'
    elif t == 'assistant' and isinstance(c, list):
        for x in c:
            if isinstance(x, dict) and x.get('type') == 'tool_use' and x.get('name') == 'Skill' \
                    and (x.get('input') or {}).get('skill') == skill:
                return 'skill_tool'
    return None


def tool_uses(m):
    """tool_use blocks of an assistant message."""
    return [x for x in (m.get('content') or []) if isinstance(x, dict) and x.get('type') == 'tool_use']


def input_sum(c):
    return c['input_tokens'] + c['cache_creation_input_tokens'] + c['cache_read_input_tokens']


def epoch(timestamp):
    return datetime.datetime.fromisoformat(timestamp.replace('Z', '+00:00')).timestamp()


def timed_responses(path, responses, stats, guards):
    """Responses of one file in time order (ties: the one recorded first).

    Each record gets t0 / t1 (time of its first / last line, epoch seconds) and the names of the tools it called.
    """
    out = []
    for d in records(path, guards):
        mu = usage(d, stats, guards)
        if mu is None:
            continue
        m, u = mu
        if not d.get('timestamp'):
            guards['response_line_without_timestamp'] += 1
            continue
        t = epoch(d['timestamp'])
        tools = set(x.get('name') for x in tool_uses(m))
        r, state = responses.add(m['id'], kinds(u), path)
        if state == 'new':
            r.update(t0=t, t1=t, tools=tools, order=len(out))
            out.append(r)
        else:
            r['t0'] = min(r['t0'], t)
            r['t1'] = max(r['t1'], t)
            r['tools'] |= tools
    out.sort(key=lambda r: (r['t0'], r['order']))
    return out
