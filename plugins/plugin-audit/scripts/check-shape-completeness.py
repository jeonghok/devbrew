#!/usr/bin/env python3
"""F 결정론부 — canonical devbrew-플러그인 shape 대비 누락을 사실로 열거. 판정 없음(축⑤ 몫). C15: 단일 패스."""
import argparse, json, re, sys
from pathlib import Path

# 하드코딩 checklist — CLAUDE.md §Plugin Shape의 진리원천 반영 (회귀 락이 drift 감시)
CHECKLIST = [
    ("plugin_json_fields", "CLAUDE.md §메타데이터"),
    ("readme_principles", "CLAUDE.md §메타데이터"),
    ("changelog_if_v1", "CLAUDE.md §메타데이터"),
    ("agents_allowlist", "CLAUDE.md §컴포넌트 격리"),
    ("skills_cost_class", "CLAUDE.md §컴포넌트 격리"),
    ("hooks_killswitch", "CLAUDE.md §런타임 상태 & 훅"),
    ("deps_declared", "CLAUDE.md §컴포넌트 격리"),
]


def _read(p):
    try:
        return p.read_text(encoding="utf-8")
    except (FileNotFoundError, OSError, UnicodeDecodeError):
        return None


def check(plugin_dir):
    pd = Path(plugin_dir)
    gaps = []

    def add(req, present):
        src = dict(CHECKLIST)[req]
        gaps.append({"requirement": req, "present": bool(present), "source_doc": src})

    pj_text = _read(pd / ".claude-plugin" / "plugin.json")
    try:
        pj = json.loads(pj_text) if pj_text else {}
    except (ValueError, TypeError):
        # 존재하지만 malformed한 plugin.json은 감사를 중단시키는 크래시가 아니라 shape
        # gap(present=False)으로 기록한다 — F는 바로 이 malformation을 잡으라고 있다.
        pj = {}
    if not isinstance(pj, dict):
        # 문법상 유효하나 top-level이 object가 아닌 경우([], null, 문자열, 숫자) —
        # 뒤의 pj.get()/`k in pj`가 크래시하지 않게 dict로 강등(present=False로 기록).
        pj = {}
    add("plugin_json_fields", bool(pj_text) and all(k in pj for k in ("name", "version", "description")))

    readme = _read(pd / "README.md") or ""
    add("readme_principles", "Principles Instantiated" in readme)

    version = pj.get("version", "0.0.0")
    needs_changelog = _semver_ge(version, "1.0.0")
    add("changelog_if_v1", (not needs_changelog) or (pd / "CHANGELOG.md").exists())

    agents = list((pd / "agents").glob("*.md")) if (pd / "agents").exists() else []
    add("agents_allowlist", all(_has_tools_allowlist(_read(a) or "") for a in agents) if agents else True)

    skills = list((pd / "skills").glob("*/SKILL.md")) if (pd / "skills").exists() else []
    add("skills_cost_class", all(_has_cost_class(_read(s) or "") for s in skills) if skills else True)

    hooks = _hook_scripts(pd)
    add("hooks_killswitch", all(_has_killswitch(_read(h) or "") for h in hooks) if hooks else True)

    own_name = pj.get("name", "")
    cross_dispatch = _has_cross_plugin_dispatch(pd, own_name)
    add("deps_declared",
        (not cross_dispatch) or ("Prerequisites" in readme) or ("prerequisites" in readme.lower()))
    return {"shape_gaps": gaps}


_NS_REF_RE = re.compile(r"\b([a-z][a-z0-9-]+):([a-z][a-z0-9-]+)\b")


def _has_cross_plugin_dispatch(pd, own_name):
    """CLAUDE.md §컴포넌트 격리: cross-plugin(다른 plugin의) namespaced agent dispatch가
    있는지 단일 bounded pass로 스캔. self-reference(자기 자신 namespace)는 제외."""
    files = []
    if (pd / "agents").exists():
        files += sorted((pd / "agents").glob("*.md"))
    if (pd / "commands").exists():
        files += sorted((pd / "commands").glob("*.md"))
    if (pd / "skills").exists():
        files += sorted((pd / "skills").rglob("SKILL.md"))
    for f in files:
        text = _read(f) or ""
        for m in _NS_REF_RE.finditer(text):
            if m.group(1) != own_name:
                return True
    return False


def _semver_ge(a, b):
    pa = [int(x) for x in re.findall(r"\d+", a)[:3] or [0]]
    pb = [int(x) for x in re.findall(r"\d+", b)[:3] or [0]]
    return pa >= pb


def _has_tools_allowlist(text):
    fm = text.split("---")[1] if text.count("---") >= 2 else ""
    return bool(re.search(r"^tools:", fm, re.M)) and "disallowedTools" not in fm  # allowlist, denylist 단독 금지


def _has_cost_class(text):
    # frontmatter 안의 cost_class: 키만 인정한다 — 본문(prose)이 'cost_class'를 언급해도
    # frontmatter에 키가 없으면 gap이다 (whole-file grep은 header-satisfiable 함정).
    fm = text.split("---")[1] if text.count("---") >= 2 else ""
    return bool(re.search(r"^cost_class:", fm, re.M))


def _hook_scripts(pd):
    hj = pd / "hooks" / "hooks.json"
    if not hj.exists():
        return []
    return [p for p in (pd / "hooks").rglob("*.py")] + [p for p in (pd / "hooks").rglob("*.sh")]


def _has_killswitch(text):
    return "DEVBREW_DISABLE_" in text or "DEVBREW_SKIP_HOOKS" in text


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("plugin_dir")
    ap.add_argument("--repo-root", default=".")
    a = ap.parse_args(argv)
    print(json.dumps(check(a.plugin_dir), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
