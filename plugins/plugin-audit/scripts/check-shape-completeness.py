#!/usr/bin/env python3
"""F 결정론부 — canonical devbrew-플러그인 shape 대비 누락을 사실로 열거. 판정 없음(축⑤ 몫). C15: 단일 패스."""
import argparse, json, os, re, sys
from pathlib import Path

# 하드코딩 checklist — CLAUDE.md §Plugin Shape의 진리원천 반영 (회귀 락이 drift 감시)
CHECKLIST = [
    ("plugin_json_fields", "CLAUDE.md §메타데이터"),
    ("readme_principles", "CLAUDE.md §메타데이터"),
    ("changelog_if_v1", "CLAUDE.md §메타데이터"),
    ("agents_allowlist", "CLAUDE.md §컴포넌트 격리"),
    ("skills_cost_class", "CLAUDE.md §컴포넌트 격리"),
    ("deps_declared", "CLAUDE.md §컴포넌트 격리"),
    ("switches_have_readers", "CLAUDE.md §런타임 상태 & 훅"),
]


def _read(p):
    try:
        return p.read_text(encoding="utf-8")
    except (FileNotFoundError, OSError, UnicodeDecodeError):
        return None


def check(plugin_dir):
    pd = Path(plugin_dir)
    gaps = []

    def add(req, present, missing=None):
        src = dict(CHECKLIST)[req]
        gap = {"requirement": req, "present": bool(present), "source_doc": src}
        if missing:
            gap["missing"] = missing   # 빠진 이름 목록(G7)
        gaps.append(gap)

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
    # 필수는 name 하나(CLAUDE.md §메타데이터) — 빈 문자열 · 비문자열 name 은 없는 것과 같다.
    # version은 있으면 문자열이어야 한다 — non-string(null 등)이면 gap (codex)
    add("plugin_json_fields", bool(pj_text)
        and isinstance(pj.get("name"), str) and pj.get("name") != ""
        and ("version" not in pj or isinstance(pj.get("version"), str)))

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

    own_name = pj.get("name", "")
    cross_dispatch = _has_cross_plugin_dispatch(pd, own_name)
    add("deps_declared",
        (not cross_dispatch) or ("Prerequisites" in readme) or ("prerequisites" in readme.lower()))
    unread = _switch_readers_gaps(pd, own_name)
    add("switches_have_readers", not unread, unread)
    return {"shape_gaps": gaps}


_SWITCH_NAME_RE = re.compile(r"DEVBREW_[A-Z0-9_]*DISABLE[A-Z0-9_]*")
_NOT_READ_BASES = ("switches.md", "README.md", "CHANGELOG.md", "entry_preflight.py")


def _table_switch_names(pd):
    """switches.md 표의 이름 칸 이름들 — (은퇴가 아닌 행, 은퇴 행). 머리줄 · 상태 칸만 본다."""
    kept, retired, cols = set(), set(), None
    for line in (_read(pd / "switches.md") or "").splitlines():
        if not line.lstrip().startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if cols is None:
            if "이름" in cells and "상태" in cells:
                cols = (cells.index("이름"), cells.index("상태"))
            continue
        if len(cells) > max(cols):
            (retired if cells[cols[1]] == "은퇴" else kept).update(_SWITCH_NAME_RE.findall(cells[cols[0]]))
    return kept, retired


def _candidate_lines(pd):
    """읽는 곳 후보 — (파일 이름, 줄들). md 는 bash 펜스 안만, 나머지는 전부. 주석 · 출력 줄은 뺀다."""
    out = []
    for root, dirs, names in os.walk(str(pd)):
        dirs[:] = sorted(x for x in dirs if x != "tests")
        for n in sorted(names):
            text = None if n in _NOT_READ_BASES else _read(Path(root) / n)
            if text is None:
                continue
            lines, fenced = [], False
            for ln in text.split("\n"):
                s = ln.lstrip()
                if n.endswith(".md"):
                    if s.startswith("```"):
                        fenced = (not fenced) and s[3:].strip() == "bash"
                        continue
                    if not fenced:
                        continue
                if s.startswith(("#", "print(")) or (s.split(None, 1) or [""])[0] in ("echo", "printf"):
                    continue
                lines.append(ln)
            out.append((n, lines))
    return out


def _switch_readers_gaps(pd, own_name):
    """이름을 댄 끄기 변수 가운데 읽는 코드를 못 찾은 이름(정렬). `은퇴` 행의 이름은 센 대상이 아니다.
    플러그인의 끄기 변수는 `DEVBREW_<플러그인>_…` 꼴이다(설계 5 · CLAUDE.md 이름 규칙) — 글에서는 그 접두만
    모으고(다른 플러그인 이름 · 옛 꼴 이름은 빠진다), switches.md 의 은퇴 아닌 행은 접두와 무관하게 더한다."""
    prefix = "DEVBREW_" + str(own_name).upper().replace("-", "_") + "_"
    named = set()
    for f in sorted((pd / "skills").glob("*/SKILL.md")) + [pd / "README.md"]:
        named.update(x for x in _SWITCH_NAME_RE.findall(_read(f) or "") if x.startswith(prefix))
    kept, retired = _table_switch_names(pd)
    named = (named | kept) - retired
    files = _candidate_lines(pd)
    keys = {}   # .conf 의 `키=이름` — 스크립트가 키로 간접해서 읽는다
    for n, lines in files:
        for ln in (lines if n.endswith(".conf") else []):
            m = re.match(r"([A-Za-z_]\w*)=[\"']?(\w+)[\"']?\s*$", ln.strip())
            if m:
                keys.setdefault(m.group(2), []).append(m.group(1))
    missing = []
    for name in sorted(named):
        q = re.escape(name)
        pats = [r"\$\{?%s(?!\w)" % q, r"(?:environ\.get|getenv)\(\s*[\"']%s[\"']" % q,
                r"environ\[\s*[\"']%s[\"']" % q]
        pats += [r"\$\{!%s(?!\w)" % re.escape(k) for k in keys.get(name, [])]
        if not any(re.search(p, ln) for _, lines in files for ln in lines for p in pats):
            missing.append(name)
    return missing


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


def _metadata_cost_class(fm_block: str) -> bool:
    """frontmatter `metadata:` 블록의 직속 자식 `cost_class:` 에 값이 있으면 참."""
    in_meta, width = False, None
    for line in fm_block.splitlines():
        if not in_meta:
            in_meta = re.match(r"metadata:[ \t]*$", line) is not None
            continue
        if not line.strip() or line[0] == "#":
            continue
        if line[0] not in " \t":
            return False   # 들여쓰지 않은 줄이 블록을 닫는다
        indent = len(line) - len(line.lstrip(" \t"))
        width = indent if width is None else width
        if indent == width and re.match(r"cost_class:[ \t]*\S", line.lstrip(" \t")):
            return True
    return False


def _has_cost_class(text):
    # frontmatter `metadata` 아래의 cost_class 만 인정한다 — 맨 위 키와 본문 언급은 선언이 아니다
    # (whole-file grep은 header-satisfiable 함정).
    fm = text.split("---")[1] if text.count("---") >= 2 else ""
    return _metadata_cost_class(fm)


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("plugin_dir")
    ap.add_argument("--repo-root", default=".")
    a = ap.parse_args(argv)
    print(json.dumps(check(a.plugin_dir), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
