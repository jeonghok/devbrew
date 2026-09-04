# -*- coding: utf-8 -*-
"""L3 판정기 — agent 가 «선언한» 입력과 dispatch 가 «전달하는» 것의 일치,
그리고 선언된 종류가 금지 어휘가 아닌지.

(a) 만으로는 「적으면 통과」다. (b) 가 무엇을 선언해도 되는가의 어휘를 준다.

(b) 의 한계 — 선언값 판정이므로 저자가 kind 를 거짓으로 적으면 빠져나간다.
변수명 휴리스틱이 보조 축이지만 이름과 kind 를 함께 속이면 통과한다. 이 락은
그 구멍을 없앴다고 주장하지 않고 어디에 있는지 밝힌다.
"""
import re
from pathlib import Path

import yaml

ALLOWED_KINDS = ("task", "artifact", "same_origin_history", "repo_context")
FORBIDDEN_KINDS = ("prior_verdict", "score", "orchestrator_framing")

# 앞 판정을 반박하는 것이 과업인 agent 는 prior_verdict 를 «받아야» 한다.
# 각 값은 C6 조건을 인용한다 — 인용 없는 항목은 호출자가 RED 로 만든다.
EXEMPT_SLOTS = {
    # ("quality-gates:adversarial", "verdicts"):
    #     "C6(1) 앞 판정을 반박하는 것이 이 agent 의 과업이다 — 대응물이 없다",
}

# 변수명이 판정·점수를 시사하면 kind 가 금지 셋 중 하나여야 한다.
# 그러면 면제 등재가 강제되고, 등재는 C6 인용을 요구한다.
_SUSPECT_VAR = re.compile(r'VERDICT|SCORE|RANK|SEVERITY|CONFIDENCE', re.I)

_FM_RE = re.compile(r'\A---\n(.*?)\n---\n', re.S)
_PAIR_RE = re.compile(
    r'<([a-zA-Z_][a-zA-Z0-9_]*)>\s*\$\{([A-Za-z_][A-Za-z0-9_]*)\}')
_SUBAGENT_RE = re.compile(r'subagent_type:\s*"([a-z0-9-]+:[a-z0-9-]+)"')


def agents(repo_root):
    """정의 집합(∀) — frontmatter 의 `name:` 에서. 선언 부재는 None 으로 «남긴다»."""
    repo = Path(repo_root)
    out = {}
    for f in sorted(repo.glob("plugins/*/agents/*.md")):
        text = f.read_text(encoding="utf-8")
        m = _FM_RE.match(text)
        if not m:
            continue
        try:
            fm = yaml.safe_load(m.group(1)) or {}
        except yaml.YAMLError:
            fm = {}
        name = str(fm.get("name", "")).split(":")[-1]
        if not name:
            continue
        plugin = f.parent.parent.name
        slots = fm.get("input_slots")
        out["%s:%s" % (plugin, name)] = {
            "path": str(f.relative_to(repo)),
            "slots": slots if isinstance(slots, list) else None,
        }
    return out


# dispatch 자리를 찾는 코퍼스 — skill·command 의 md 전부. 특정 SKILL 하나로
# 좁히지 않는다(좁히면 다른 파일의 dispatch 가 영원히 안 보인다). `scanned_paths()`
# 가 같은 튜플을 재사용한다 — `--emit-scanned` 가 이 함수와 다른 글롭을 내면
# 낸 것과 읽은 것이 갈린다.
_DISPATCH_GLOBS = ("plugins/*/skills/**/*.md", "plugins/*/commands/**/*.md")


def dispatch_pairs(repo_root):
    """dispatch 자리가 실제로 전달하는 (태그, 변수) 쌍.

    코퍼스는 skill·command 의 md 전부다. 특정 SKILL 하나로 좁히지 않는다 —
    좁히면 다른 파일의 dispatch 가 영원히 안 보인다.
    """
    repo = Path(repo_root)
    out = {}
    for pat in _DISPATCH_GLOBS:
        for f in sorted(repo.glob(pat)):
            if not f.is_file():
                continue
            rel = str(f.relative_to(repo))
            lines = f.read_text(encoding="utf-8").splitlines()
            # 펜스 단위로 자른다 — 펜스마다 독립 dispatch 다. 합치면 죽은
            # 펜스가 살아 있는 펜스의 결손을 가린다.
            buf, start, inside = [], 0, False
            for i, line in enumerate(lines, 1):
                if re.match(r'^```', line):
                    if inside:
                        _harvest("\n".join(buf), rel, start, out)
                        buf, inside = [], False
                    else:
                        inside, start = True, i
                    continue
                if inside:
                    buf.append(line)
    return out


def _harvest(block, rel, line, out):
    m = _SUBAGENT_RE.search(block)
    if not m:
        return
    key = m.group(1)
    out.setdefault(key, [])
    for p in _PAIR_RE.finditer(block):
        out[key].append((p.group(1), p.group(2), rel, line))


def check(repo_root):
    """(a) 일치 · (b) 금지 종류. 위반 목록을 낸다."""
    defs = agents(repo_root)
    pairs = dispatch_pairs(repo_root)
    problems = []

    for key, info in sorted(defs.items()):
        delivered = pairs.get(key, [])
        if info["slots"] is None:
            problems.append(("no_declaration", key, info["path"], ""))
            continue
        declared = {}
        for s in info["slots"]:
            if not isinstance(s, dict) or "tag" not in s:
                problems.append(("bad_slot", key, info["path"], repr(s)))
                continue
            declared[str(s["tag"])] = s

        # (a) 선언 ↔ 전달
        for (tag, var, path, ln) in delivered:
            if tag not in declared:
                problems.append(("undeclared", key, "%s:%d" % (path, ln),
                                 "<%s>${%s}" % (tag, var)))
            elif str(declared[tag].get("var", var)) != var:
                problems.append(("var_mismatch", key, "%s:%d" % (path, ln),
                                 "<%s> 선언=%s 전달=%s"
                                 % (tag, declared[tag].get("var"), var)))
        got = {t for (t, _v, _p, _l) in delivered}
        for tag, s in declared.items():
            if tag not in got and not s.get("optional"):
                problems.append(("undelivered", key, info["path"],
                                 "<%s> 를 선언했으나 전달하는 dispatch 가 없다" % tag))

        # (b) 금지 종류
        for tag, s in declared.items():
            kind = str(s.get("kind", ""))
            var = str(s.get("var", ""))
            if not kind:
                problems.append(("no_kind", key, info["path"], tag))
            elif kind in FORBIDDEN_KINDS:
                if (key, tag) not in EXEMPT_SLOTS:
                    problems.append(("forbidden_kind", key, info["path"],
                                     "<%s> kind=%s" % (tag, kind)))
            elif kind not in ALLOWED_KINDS:
                problems.append(("unknown_kind", key, info["path"],
                                 "<%s> kind=%s" % (tag, kind)))
            if _SUSPECT_VAR.search(var) and kind not in FORBIDDEN_KINDS:
                problems.append(("suspect_var", key, info["path"],
                                 "<%s> var=%s 인데 kind=%s — 판정·점수를 시사하는 "
                                 "이름은 금지 종류로 선언하고 면제에 등재하라"
                                 % (tag, var, kind)))
    return problems


def uncited_exemptions():
    return [k for k, v in EXEMPT_SLOTS.items() if "C6" not in str(v)]


def scanned_paths(repo_root):
    """`--emit-scanned` 코퍼스 — `agents()` 와 `dispatch_pairs()` 가 실제로
    도는 파일 전부의 합집합(참조가 0건이어도 글롭에 매칭돼 읽힌 파일은
    포함한다). 같은 글롭 소스를 재사용한다(재도출 아님)."""
    repo = Path(repo_root)
    out = set()
    for f in repo.glob("plugins/*/agents/*.md"):
        if f.is_file():
            out.add(str(f.relative_to(repo)))
    for pat in _DISPATCH_GLOBS:
        for f in repo.glob(pat):
            if f.is_file():
                out.add(str(f.relative_to(repo)))
    return sorted(out)
