"""Token baseline - which sessions rule 7 picks. One JSON object.

  python3 -I select_sessions.py --backup <backup folder> [--needle <text>]

Reads every top-level session of the backup and lists the ones that show a conductor sign: calls of
the skill (slash command lines, Skill tool calls), assistant lines attributed to the skill, Bash
calls of the marker scripts. `selected` is rule 7 itself: the sessions with at least one call.
With --needle it also counts, per listed session, the lines containing that text (for example a
roadmap folder name) and the calls whose arguments contain it.

What the user typed is never printed: command arguments appear only as lengths, and of the slash
commands only the names of plugin skills (/plugin:skill) are listed.
"""
import collections
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import baseline_lib as lib  # noqa: E402

parser = lib.arg_parser(__doc__)
parser.add_argument('--needle', help='text to count in the listed sessions (the count is printed, not the lines)')
args = parser.parse_args()
backup, cfg, _ = lib.load(args)
skill = cfg['skill']
guards = lib.Guards('jsonl_in_unknown_layout', 'configured_session_not_selected')
COMMAND = re.compile(r'<command-name>(/[A-Za-z0-9_-]+:[A-Za-z0-9:_-]+)</command-name>')
ARGS = re.compile(r'<command-args>(.*?)</command-args>', re.S)

rows = []
entrypoints = collections.Counter()
for path, kind in lib.backup_files(backup, guards):
    if kind != 'main':
        continue
    c = collections.Counter()
    markers = collections.Counter()
    commands = collections.Counter()
    arg_lengths = []
    versions = set()
    entrypoint = first = last = None
    for d, text in lib.records(path, guards, with_text=True):
        entrypoint = entrypoint or d.get('entrypoint')
        ts = d.get('timestamp')
        if ts:
            first = min(first or ts, ts)
            last = max(last or ts, ts)
        if d.get('version'):
            versions.add(d['version'])
        if args.needle and args.needle in text:
            c['needle_lines'] += 1
            c['needle_occurrences'] += text.count(args.needle)
        call = lib.skill_call(d, skill)
        if call:
            c[call] += 1
        if d.get('type') == 'user':
            content = lib.user_text(d)
            commands.update(COMMAND.findall(content))
            if call:
                typed = ARGS.search(content)
                arg_lengths.append(len(typed.group(1).strip()) if typed else 0)
                c['calls_with_needle_in_args'] += bool(args.needle and typed and args.needle in typed.group(1))
        elif d.get('type') == 'assistant':
            c['lines_attributed_to_skill'] += d.get('attributionSkill') == skill
            for x in lib.tool_uses(d.get('message') or {}):
                if x.get('name') == 'Bash':
                    command = str((x.get('input') or {}).get('command') or '')
                    for name in cfg['marker_scripts']:
                        markers[name] += name in command
    entrypoints[entrypoint or '?'] += 1
    markers = {k: v for k, v in markers.items() if v}
    if c['slash'] or c['skill_tool'] or c['lines_attributed_to_skill'] or markers:
        rel = os.path.relpath(path, backup)
        sub_dir = os.path.join(backup, rel[:-len('.jsonl')], 'subagents')
        row = dict(session=os.path.basename(rel)[:-len('.jsonl')], worktree=lib.worktree_name(rel.split(os.sep)[0]),
                   entrypoint=entrypoint, slash=c['slash'], skill_tool=c['skill_tool'],
                   lines_attributed_to_skill=c['lines_attributed_to_skill'], marker_bash_calls=markers,
                   plugin_slash_commands=dict(commands.most_common()), call_argument_lengths=arg_lengths,
                   first=first, last=last, versions=sorted(versions),
                   sub_agent_files=len(os.listdir(sub_dir)) if os.path.isdir(sub_dir) else 0)
        if args.needle:
            row.update(needle_lines=c['needle_lines'], needle_occurrences=c['needle_occurrences'],
                       calls_with_needle_in_args=c['calls_with_needle_in_args'])
        rows.append(row)

selected = sorted(r['session'] for r in rows if r['slash'] or r['skill_tool'])
configured = set(cfg['sessions'].values())
guards['configured_session_not_selected'] += len(configured - set(selected))
lib.emit(dict(skill=skill, top_level_sessions_by_entrypoint=dict(entrypoints.most_common()), sessions=rows,
              selected=selected, selected_but_not_configured=sorted(set(selected) - configured)), guards)
