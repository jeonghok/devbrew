"""Token baseline - the main measurement. Prints one JSON object.

  python3 -I measure.py --backup <backup folder> > <a file outside the repo>

Per configured session it sums the four token kinds for the conductor body, its sub agents and
the sdk sessions attached to it (rules 1-6), splits the sessions named in split_at_first_call at
the first call of the skill (rule 8), and reports direct vs nested agents, agent types, models,
versions, compactions and the input each agent re-read.
"""
import collections
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import baseline_lib as lib  # noqa: E402

args = lib.arg_parser(__doc__).parse_args()
backup, cfg, rel_of = lib.load(args)
skill = cfg['skill']
split = set(cfg['split_at_first_call'])
under_cfg = cfg['output_underreported_patch_range']
FIELDS = lib.K + ('cc_1h', 'cc_5m')

guards = lib.Guards(*lib.USAGE_GUARDS, 'jsonl_outside_subagents_layer', 'message_id_in_two_files',
                    'cache_write_not_1h_plus_5m', 'skill_call_without_timestamp',
                    'agent_worktree_session_not_sdk', 'session_without_skill_call', 'unlinked_agents')
stats = collections.Counter()
responses = lib.Responses(guards, FIELDS)
rec = responses.rec
call_ts = collections.defaultdict(list)
compacts = collections.Counter()
agent_type = {}
tool_type = {}
launched_from_main = collections.defaultdict(set)
launched_from_sub = collections.defaultdict(set)
query_sources = collections.defaultdict(collections.Counter)
sub_files = collections.Counter()
sub_files_nousage = collections.Counter()
sdk_files = collections.Counter()
iters = collections.Counter()


def under(version):
    """True for a version in the range whose sub-agent output is known to be under-recorded."""
    prefix = under_cfg['prefix']
    patch = version[len(prefix):]
    return version.startswith(prefix) and patch.isdigit() and under_cfg['from'] <= int(patch) <= under_cfg['to']


def scan(path, sess, part, agent=None):
    got = False
    entrypoint = None
    for d in lib.records(path, guards):
        entrypoint = entrypoint or d.get('entrypoint')
        t = d.get('type')
        called_at = lib.call_time(d, skill, guards) if part == 'body' else None
        if called_at:
            call_ts[sess].append(called_at)
        if t == 'system' and d.get('subtype') == 'compact_boundary':
            compacts[sess + '|' + part] += 1
        elif t == 'api-request' and part == 'sub':
            query_sources[agent][d.get('querySource')] += 1
        elif t == 'user' and part != 'sdk':
            tur = d.get('toolUseResult')
            if isinstance(tur, dict) and tur.get('agentId'):
                aid = tur['agentId']
                (launched_from_main if part == 'body' else launched_from_sub)[sess].add(aid)
                c = (d.get('message') or {}).get('content')
                for x in c if isinstance(c, list) else []:
                    if isinstance(x, dict) and x.get('type') == 'tool_result' and x.get('tool_use_id') in tool_type:
                        agent_type.setdefault(aid, tool_type[x['tool_use_id']])
        elif t == 'assistant':
            m = d.get('message') or {}
            for x in lib.tool_uses(m):
                if x.get('name') in ('Agent', 'Task'):
                    tool_type[x.get('id')] = (x.get('input') or {}).get('subagent_type') or '(default)'
            mu = lib.usage(d, stats, guards)
            if mu is None:
                continue
            m, u = mu
            got = True
            it = u.get('iterations') or []
            if len(it) > 1:
                iters['multi'] += 1
            for x in it:
                if x.get('type') != 'message':
                    iters['type_' + str(x.get('type'))] += 1
            vals = lib.kinds(u)
            cc = u.get('cache_creation') or {}
            vals['cc_1h'] = cc.get('ephemeral_1h_input_tokens') or 0
            vals['cc_5m'] = cc.get('ephemeral_5m_input_tokens') or 0
            if vals['cache_creation_input_tokens'] != vals['cc_1h'] + vals['cc_5m']:
                guards['cache_write_not_1h_plus_5m'] += 1
            r, state = responses.add(m['id'], vals, path)
            if state == 'new':
                r.update(ts=d.get('timestamp') or '', ver=d.get('version') or '', sess=sess, part=part,
                         agent=agent, model=m.get('model'))
            else:
                stats['repeat_same_file'] += 1
                if state == 'differs':
                    stats['repeat_disagree'] += 1
    if part == 'sdk' and entrypoint != 'sdk-py':
        guards['agent_worktree_session_not_sdk'] += 1
    return got


owner = {}
for s, rel in rel_of.items():
    body, subs = lib.session_files(backup, rel, guards)
    scan(body, s, 'body')
    for f in subs:
        aid = lib.agent_id(f)
        owner[aid] = s
        sub_files[s] += 1
        if not scan(f, s, 'sub', aid):
            sub_files_nousage[s] += 1

# Rule 4, sdk part: a top-level session of an agent worktree belongs to the session owning that agent.
for proj in sorted(os.listdir(backup)):
    if lib.AGENT_WORKTREE_MARK not in proj or not os.path.isdir(os.path.join(backup, proj)):
        continue
    aid = proj.split(lib.AGENT_WORKTREE_MARK, 1)[1]
    s = owner.get(aid)
    if not s:
        stats['agent_wt_unowned_dirs'] += 1
        continue
    for name in sorted(os.listdir(os.path.join(backup, proj))):
        if name.endswith('.jsonl'):
            sdk_files[s] += 1
            scan(os.path.join(backup, proj, name), s, 'sdk', aid)

first_call = {s: min(v) for s, v in call_ts.items()}
for s in rel_of:
    if s not in first_call:
        guards['session_without_skill_call'] += 1


def seg(r):
    if r['sess'] not in split:
        return r['sess']
    return r['sess'] + ('-pre' if r['ts'] < first_call.get(r['sess'], '') else '-cond')


agg = collections.defaultdict(collections.Counter)
und = collections.Counter()
per_agent = collections.defaultdict(collections.Counter)
per_type = collections.defaultdict(collections.Counter)
span = {}
models = collections.Counter()
for r in rec.values():
    for key in {(r['sess'], r['part']), (seg(r), r['part']), ('ALL', r['part'])}:
        c = agg[key]
        c['responses'] += 1
        for k in FIELDS:
            c[k] += r[k]
    models[(r['part'], r['model'])] += 1
    if r['part'] == 'sub':
        if under(r['ver']):
            und[r['sess'] + '_responses'] += 1
            und[r['sess'] + '_output'] += r['output_tokens']
        for c in (per_agent[(r['sess'], r['agent'])], per_type[agent_type.get(r['agent'], '(unknown)')]):
            c['responses'] += 1
            for k in lib.K:
                c[k] += r[k]
    if r['part'] == 'body' and under(r['ver']):
        und[r['sess'] + '_body_responses'] += 1
    sp = span.setdefault(r['sess'] + '|' + r['part'], [r['ts'], r['ts']])
    sp[0] = min(sp[0], r['ts'])
    sp[1] = max(sp[1], r['ts'])
type_agents = collections.Counter(agent_type.get(a, '(unknown)') for (s, a) in per_agent)


def link(s, a):
    if a in launched_from_main[s]:
        return 'direct'
    return 'nested' if a in launched_from_sub[s] else 'unlinked'


sub_split = collections.defaultdict(collections.Counter)
agent_inputs = collections.defaultdict(list)
agent_responses = collections.defaultdict(list)
for (s, a), c in per_agent.items():
    kind = link(s, a)
    if kind == 'unlinked':
        guards['unlinked_agents'] += 1
    sub_split[s + '|' + kind]['agents'] += 1
    sub_split[s + '|' + kind].update(c)
    agent_inputs[s].append(lib.input_sum(c))
    agent_responses[s].append(c['responses'])

# What the agents launched without a subagent_type actually ran as (querySource of their request lines).
default_ran_as = collections.Counter()
for (s, a) in per_agent:
    if agent_type.get(a) == '(default)':
        default_ran_as['+'.join(sorted(str(q) for q in query_sources[a])) or '(no request lines)'] += 1

lib.emit(dict(
    config=dict(skill=skill, sessions=cfg['sessions'], split_at_first_call=sorted(split)),
    first_call=first_call, call_count={s: len(v) for s, v in call_ts.items()}, span=span,
    agg={'%s|%s' % k: dict(v) for k, v in sorted(agg.items())},
    stats=dict(stats), compacts=dict(compacts),
    sub_files=dict(sub_files), sub_files_without_usage=dict(sub_files_nousage), sdk_files=dict(sdk_files),
    launched_from_main={s: len(v) for s, v in launched_from_main.items()},
    launched_from_sub={s: len(v) for s, v in launched_from_sub.items()},
    sub_agents_with_usage={s: len(agent_inputs[s]) for s in rel_of},
    nested_with_usage={s: sub_split[s + '|nested']['agents'] for s in rel_of},
    unlinked_with_usage={s: sub_split[s + '|unlinked']['agents'] for s in rel_of},
    sub_split={k: dict(v) for k, v in sorted(sub_split.items()) if v['agents']},
    per_agent_input={s: dict(agents=len(v), mean=round(statistics.mean(v)), median=round(statistics.median(v)),
                             max=max(v), responses_median=statistics.median(agent_responses[s]),
                             responses_max=max(agent_responses[s]))
                     for s, v in agent_inputs.items() if v},
    under_range=dict(und), iterations=dict(iters),
    models={'%s|%s' % k: v for k, v in models.most_common()},
    per_type={k: dict(v, agents=type_agents[k]) for k, v in sorted(
        per_type.items(), key=lambda kv: -(kv[1]['cache_read_input_tokens'] + kv[1]['cache_creation_input_tokens']))},
    default_type_ran_as=dict(default_ran_as),
    versions={s: {'%s|%s' % k: v for k, v in collections.Counter(
        (r['part'], r['ver']) for r in rec.values() if r['sess'] == s).most_common()} for s in rel_of},
), guards)
