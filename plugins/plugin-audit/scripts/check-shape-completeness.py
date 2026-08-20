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
    add("plugin_json_fields", bool(pj_text)
        and all(k in pj for k in ("name", "version", "description"))
        and isinstance(pj.get("version"), str))   # version이 non-string(null 등)이면 gap (codex)

    readme = _read(pd / "README.md") or ""
    add("readme_principles", "Principles Instantiated" in readme)

    version = pj.get("version", "0.0.0")
    if not isinstance(version, str):
        version = "0.0.0"   # non-string version은 _semver_ge(re.findall) 크래시 유발 → 안전 기본값
    needs_changelog = _semver_ge(version, "1.0.0")
    add("changelog_if_v1", (not needs_changelog) or (pd / "CHANGELOG.md").exists())

    agents = list((pd / "agents").glob("*.md")) if (pd / "agents").exists() else []
    add("agents_allowlist", all(_has_tools_allowlist(_read(a) or "") for a in agents) if agents else True)

    skills = list((pd / "skills").glob("*/SKILL.md")) if (pd / "skills").exists() else []
    add("skills_cost_class", all(_has_cost_class(_read(s) or "") for s in skills) if skills else True)

    add("hooks_killswitch", _hooks_killswitch_present(pd))

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


# hook command 문자열에서 참조 스크립트 경로 추출 (`${CLAUDE_PLUGIN_ROOT}/hooks/foo.py` 등).
# 접두 `${CLAUDE_PLUGIN_ROOT}/`(또는 중괄호 없는 `$CLAUDE_PLUGIN_ROOT/`)는 optional로 소비하고
# .py/.sh로 끝나는 상대 경로를 캡처한다.
_CMD_SCRIPT_RE = re.compile(r"(?:\$\{?CLAUDE_PLUGIN_ROOT\}?/)?([\w./-]+\.(?:py|sh))")


def _walk_hook_commands(data):
    """이미 파싱된 hooks.json 데이터에서 command 문자열을 재귀 수집."""
    cmds = []

    def walk(o):
        if isinstance(o, dict):
            for k, v in o.items():
                if k == "command" and isinstance(v, str):
                    cmds.append(v)
                else:
                    walk(v)
        elif isinstance(o, list):
            for x in o:
                walk(x)

    walk(data)
    return cmds


def _hooks_killswitch_present(pd):
    # CLAUDE.md §런타임 "모든 훅에 kill switch" — 여기서 "훅"은 hooks.json이 **등록한** 스크립트다.
    # hooks/ 아래를 통째 rglob하면 tests/·__init__.py·비-등록 공유 헬퍼까지 훅으로 오인해
    # 정상 플러그인에 거짓 "kill switch 부재"를 낸다 (/qg 2026-07-20 codex, over-glob)
    # → hooks.json의 command가 가리키는 스크립트만 검증한다.
    # 당시의 실측 사례는 spec-distill 의 `state_path.py` 였다. 그 파일은 이후 그 플러그인의
    # `scripts/` 로 옮겨졌고, 지금은 어느 플러그인의 hooks/ 에도 비-등록 `.py` 가 없다 —
    # 그래도 이 가드는 남는다. 사례가 없다는 것이 규칙이 없어도 된다는 뜻은 아니다.
    # 단, **판정 불가**는 fail-closed로 gap이어야 한다 (codex re-verify R2): malformed hooks.json /
    # 해석 불가 command / 등록됐으나 디스크에 부재한 스크립트를 빈 리스트→all([])로 조용히 통과시키면
    # fail-open이다. 판정할 수 있을 때만 True/False, 판정 불가면 False.
    hj = pd / "hooks" / "hooks.json"
    if not hj.exists():
        return True   # 훅 없음 → kill switch 요건 없음
    try:
        text = _read(hj)
        data = json.loads(text) if text else None
    except (ValueError, TypeError):
        return False  # malformed hooks.json → 판정 불가 → gap (fail-closed)
    if not isinstance(data, (dict, list)):
        return False
    root = pd.resolve()
    scripts, seen = [], set()
    for cmd in _walk_hook_commands(data):
        for m in _CMD_SCRIPT_RE.finditer(cmd):
            cand = (pd / m.group(1).lstrip("/")).resolve()
            # containment: command가 `../`/symlink로 plugin root 밖을 가리키면(악성 hooks.json) 무관한
            # 외부 파일로 kill-switch 검사를 만족시키는 read-oracle/traversal이 된다 → 판독 전에 거부(gap,
            # fail-closed). grounding의 containment와 같은 패턴 (codex re-verify round-2, security).
            try:
                cand.relative_to(root)
            except ValueError:
                return False
            if cand not in seen:
                seen.add(cand)
                scripts.append(cand)
    if any(not c.is_file() for c in scripts):
        return False  # 등록된 hook 스크립트가 디스크에 부재(dangling) → 검증 불가 → gap
    return all(_has_killswitch(_read(c) or "") for c in scripts)


_KILLSWITCH_RE = re.compile(r"DEVBREW_[A-Z0-9_]*_DISABLE")


def _has_killswitch(text):
    return bool(_KILLSWITCH_RE.search(text)) or "DEVBREW_SKIP_HOOKS" in text


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("plugin_dir")
    ap.add_argument("--repo-root", default=".")
    a = ap.parse_args(argv)
    print(json.dumps(check(a.plugin_dir), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
