# -*- coding: utf-8 -*-
"""T4-2 판정기 — 백틱으로 불린 `<plugin>:<name>` 이 실재 정의를 갖는지.

기존 dispatch 락의 표기 필터(subagent_type:|agentType:|Agent\\(|^\\s*agent:)를
«빼지 않는다». 그 필터는 산문 속 맨 영어 단어가 dispatch 로 잡히는 것을 막고
있고 그 필요는 실측으로 기록돼 있다(test_dispatch_disposition.sh:80-84).

여기서는 «백틱 + 콜론» 두 조건을 동시에 요구한다. 맨 단어는 둘 다 없으므로
그 필터와 겹치지 않는다 — 우회가 아니라 직교다.
"""
import re
from pathlib import Path

# 이력 문서는 과거 이름을 legitimately 담는다. 지운 이름을 CHANGELOG 가
# 말하지 못하게 되면 그것이야말로 이력의 소실이다.
EXEMPT_FILES = ("CHANGELOG.md",)

# 백틱 안, `<plugin>:<name>` 꼴. 양쪽 다 kebab-case 만.
_REF_RE = re.compile(r'`([a-z][a-z0-9-]*):([a-z][a-z0-9-]*)`')


def defined(repo_root):
    """실재하는 `<plugin>:<name>` 전부 — agent · skill · command."""
    repo = Path(repo_root)
    out = set()
    for pdir in sorted(repo.glob("plugins/*")):
        if not pdir.is_dir():
            continue
        plugin = pdir.name
        for f in sorted(pdir.glob("agents/*.md")):
            m = re.search(r'^name:\s*(\S+)\s*$', f.read_text(encoding="utf-8"),
                          re.M)
            if m:
                out.add("%s:%s" % (plugin, m.group(1).split(":")[-1]))
        for f in sorted(pdir.glob("skills/*/SKILL.md")):
            out.add("%s:%s" % (plugin, f.parent.name))
        for f in sorted(pdir.glob("commands/*.md")):
            out.add("%s:%s" % (plugin, f.stem))
    return out


def _plugins(repo_root):
    return {p.name for p in Path(repo_root).glob("plugins/*") if p.is_dir()}


def references(repo_root):
    """코퍼스에서 백틱으로 불린 참조 전부.

    plugin 부분이 실재 플러그인 디렉토리명일 때만 참조로 본다 — 그래야
    `key:value` 같은 무관한 백틱 문자열이 걸리지 않는다.
    """
    repo = Path(repo_root)
    plugins = _plugins(repo_root)
    out = []
    for pat in ("plugins/*/skills/**/*.md", "plugins/*/commands/**/*.md",
                "plugins/*/agents/*.md", "plugins/*/README.md"):
        for f in sorted(repo.glob(pat)):
            if not f.is_file() or f.name in EXEMPT_FILES:
                continue
            rel = str(f.relative_to(repo))
            for i, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
                for m in _REF_RE.finditer(line):
                    if m.group(1) in plugins:
                        out.append((rel, i, "%s:%s" % (m.group(1), m.group(2))))
    return out


def dangling(repo_root):
    known = defined(repo_root)
    return [r for r in references(repo_root) if r[2] not in known]
