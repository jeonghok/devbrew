"""Render the tables and one-line figures of token-baseline.md from the measure output.

  python3 -I table.py measure.out.json
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import baseline_lib as lib  # noqa: E402

if len(sys.argv) != 2:
    lib.die('usage: table.py <measure output json>')
with open(sys.argv[1], encoding='utf-8') as fh:
    d = json.load(fh)
sys.stdout.reconfigure(encoding='utf-8')
a = d['agg']
sessions = list(d['config']['sessions'])
split = set(d['config']['split_at_first_call'])
HEAD = '| 묶음 | 응답 수 | 새 입력 | 캐시 쓰기 | 캐시 읽기 | 출력 | 캐시 읽기 비율 | 응답당 입력계 |\n|---|---|---|---|---|---|---|---|'


def n(x):
    return format(x, ',')


def pct(x, y, digits=1):
    return '%.*f%%' % (digits, x / y * 100) if y else '-'


def row(label, c):
    tin = lib.input_sum(c)
    per = n(round(tin / c['responses'])) if c['responses'] else '-'
    return '| %s | %s | %s | %s | %s |' % (label, n(c['responses']), ' | '.join(n(c[k]) for k in lib.K),
                                         pct(c['cache_read_input_tokens'], tin, 2), per)


def add(*cs):
    out = {}
    for c in cs:
        for k, v in c.items():
            out[k] = out.get(k, 0) + v
    return out


def part(prefix, name):
    """The aggregate of one part, or None when the session has no such part."""
    return a.get(prefix + '|' + name)


print('### 세션별 · 지휘 대 하위\n')
print(HEAD)
for s in sessions:
    spans = [(s + ' 전체', s), (s + ' 지휘 전', s + '-pre'), (s + ' 지휘 뒤', s + '-cond')] if s in split else [(s, s)]
    for label, prefix in spans:
        for word, name in (('지휘', 'body'), ('하위', 'sub')):
            if part(prefix, name):
                print(row('%s · %s' % (label, word), part(prefix, name)))

body, sub = a['ALL|body'], a.get('ALL|sub', {})
cond = [s + '-cond' if s in split else s for s in sessions]
cb = add(*[part(p, 'body') for p in cond if part(p, 'body')])
cs = add(*[part(p, 'sub') for p in cond if part(p, 'sub')])
print('\n### 로드맵 합\n')
print(HEAD)
print(row('로드맵 합 · 지휘', body))
print(row('로드맵 합 · 하위', sub))
print(row('로드맵 합 · 지휘+하위', add(body, sub)))
print(row('지휘자 skill 구간 · 지휘', cb))
print(row('지휘자 skill 구간 · 하위', cs))
print(row('지휘자 skill 구간 · 합', add(cb, cs)))

print('\n하위 몫:\n')
print('| 범위 | 입력계 | 캐시 쓰기 | 출력 |\n|---|---|---|---|')
shares = [('로드맵 합', body, sub), ('지휘자 skill 구간', cb, cs)]
shares += [(s, part(s, 'body'), part(s, 'sub')) for s in sessions if part(s, 'sub')]
for label, x, y in shares:
    print('| %s | %s | %s | %s |' % (
        label, pct(lib.input_sum(y), lib.input_sum(x) + lib.input_sum(y)),
        pct(y['cache_creation_input_tokens'], x['cache_creation_input_tokens'] + y['cache_creation_input_tokens']),
        pct(y['output_tokens'], x['output_tokens'] + y['output_tokens'])))

print('\n### sdk 세션\n')
print('| 묶음 | 파일 | 응답 수 | 새 입력 | 캐시 쓰기 | 캐시 읽기 | 출력 | 캐시 읽기 비율 |\n|---|---|---|---|---|---|---|---|')
for s in sessions:
    c = part(s, 'sdk')
    if c:
        print('| %s 에 붙은 sdk | %s | %s | %s | %s |' % (
            s, n(d['sdk_files'][s]), n(c['responses']), ' | '.join(n(c[k]) for k in lib.K),
            pct(c['cache_read_input_tokens'], lib.input_sum(c), 2)))

print('\n### 하위 agent 의 결\n')
for s in sessions:
    c = part(s, 'sub')
    if not c:
        continue
    direct, nested = d['sub_split'].get(s + '|direct'), d['sub_split'].get(s + '|nested')
    print('- %s 직접 %s · 중첩 %s · 연결 안 됨 %s — 중첩 캐시 읽기 %s (%s 하위의 %s)' % (
        s, n(direct['agents']) if direct else 0, n(nested['agents']) if nested else 0, d['unlinked_with_usage'][s],
        n(nested['cache_read_input_tokens']) if nested else 0, s,
        pct(nested['cache_read_input_tokens'], c['cache_read_input_tokens']) if nested else '-'))
    pa = d['per_agent_input'][s]
    print('- %s agent 하나당 입력계: 평균 %s · 중앙값 %s · 최대 %s (agent %s개, 응답 수 중앙값 %s · 최대 %s)' % (
        s, n(pa['mean']), n(pa['median']), n(pa['max']), n(pa['agents']), pa['responses_median'], pa['responses_max']))
for name, word in (('body', '지휘 본체'), ('sub', '하위'), ('sdk', 'sdk')):
    c = a.get('ALL|' + name)
    if c:
        print('- 캐시 쓰기 TTL · %s: 1시간 %s · 5분 %s (캐시 쓰기 합 %s)' % (
            word, n(c['cc_1h']), n(c['cc_5m']), n(c['cache_creation_input_tokens'])))
print('- 모델별 응답: ' + ' · '.join('%s %s' % (k, n(v)) for k, v in d['models'].items()))
print('- 압축(compact_boundary): ' + ' · '.join('%s %s' % kv for kv in sorted(d['compacts'].items())))
print('- 세션별 판: ' + ' / '.join('%s: %s' % (s, ' · '.join('%s %s' % (k, n(v)) for k, v in d['versions'][s].items()))
                                for s in sessions))
print('- 호출: ' + ' · '.join('%s %s번(첫 호출 %s)' % (s, d['call_count'][s], d['first_call'][s]) for s in sessions))
print('- 응답 시각 범위: ' + ' · '.join('%s %s – %s' % (k, v[0], v[1]) for k, v in sorted(d['span'].items())))
for s in sessions:
    c = part(s, 'sub')
    low = d['under_range'].get(s + '_responses')
    if c and low:
        print('- %s 하위 중 출력이 덜 적힌 판 범위의 응답: %s (%s 하위의 %s) · 그 출력 합 %s' % (
            s, n(low), s, pct(low, c['responses']), n(d['under_range'][s + '_output'])))

print('\n| subagent_type | agent 수 | 응답 수 | 캐시 쓰기 | 캐시 읽기 | 출력 |\n|---|---|---|---|---|---|')
types = list(d['per_type'].items())
types.sort(key=lambda kv: -kv[1]['cache_read_input_tokens'])
for name, c in types[:10]:
    print('| %s | %s | %s | %s | %s | %s |' % (
        '(지정 없음)' if name == '(default)' else name, n(c['agents']), n(c['responses']),
        n(c['cache_creation_input_tokens']), n(c['cache_read_input_tokens']), n(c['output_tokens'])))
rest = types[10:]
print('\n나머지 %d종의 캐시 읽기 합 %s · 종류를 모르는 agent %s' % (
    len(rest), n(sum(c['cache_read_input_tokens'] for _, c in rest)), d['per_type'].get('(unknown)', {}).get('agents', 0)))
ran = d['default_type_ran_as']
print('(지정 없음) 이 실제로 돈 종류(요청 줄의 querySource): ' + ' · '.join('%s %s' % kv for kv in sorted(ran.items())))
if list(ran) == ['agent:builtin:general-purpose'] and 'general-purpose' in d['per_type']:
    both = add(d['per_type']['general-purpose'], d['per_type']['(default)'])
    print('general-purpose + (지정 없음): agent %s · 응답 %s · 캐시 읽기 %s (하위의 %s)' % (
        n(both['agents']), n(both['responses']), n(both['cache_read_input_tokens']),
        pct(both['cache_read_input_tokens'], sub['cache_read_input_tokens'])))
