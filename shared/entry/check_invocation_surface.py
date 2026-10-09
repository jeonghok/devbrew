#!/usr/bin/env python3
"""devbrew 호출 표면 정합 락 — 설계 docs/superpowers/specs/2026-10-09-skill-only-surface-design.md §4.

축 A~I 를 git 이 아는 파일(추적 + 미추적 비무시)에서 도출해 잰다. quality-gates 파일의 위반은
`plugins/quality-gates/commands/` 가 있는 동안 보고 모드다 — RED 대신 `--report` 표의 행이 된다.

  check_invocation_surface.py [--root DIR]                 위반이 있으면 rc 1
  check_invocation_surface.py --report [--root DIR]        qg 보고 표(마크다운)
  check_invocation_surface.py --emit-scanned [--root DIR]  실제로 읽은 경로
  check_invocation_surface.py --print-head <plugin> <skill>
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys

QG = "plugins/quality-gates/"
QG_COMMANDS = "plugins/quality-gates/commands/"
SELF_FILES = frozenset({"shared/entry/check_invocation_surface.py", "shared/tests/test_invocation_surface.sh"})
SCOPE_ON = "qg 는 plugins/quality-gates/commands/ 가 있는 동안 보고만 된다(--report)"
SCOPE_OFF = "qg 보고 모드 종료 — plugins/quality-gates/commands/ 가 없어 qg 위반도 RED 다"

ENTRY_SKILLS = (
    ("spec-distill", "request-framing"),
    ("spec-distill", "spec-interview"),
    ("spec-distill", "spec-review"),
    ("plugin-audit", "plugin-audit"),
    ("project-init", "project-init"),
)
USER_ONLY = frozenset({("plugin-audit", "plugin-audit"), ("project-init", "project-init")})

# 축 E — 공식 skill frontmatter 키 20개 ∪ {cost_class}.
# 출처: https://code.claude.com/docs/en/skills frontmatter reference (확인 2026-10-09).
# `claude plugin validate --strict` 는 미지 키를 잡지 않는다(E0 실측 2026-10-09, CLI 2.1.294).
# 플랫폼이 키를 더하면 이 목록이 거짓 RED 를 낸다 — 출처를 다시 확인하고 갱신한다.
SKILL_KEYS = frozenset({
    "name", "description", "when_to_use", "argument-hint", "arguments",
    "disable-model-invocation", "user-invocable", "allowed-tools", "disallowed-tools",
    "model", "effort", "context", "agent", "background", "hooks", "paths", "shell",
    "metadata", "license", "compatibility", "cost_class",
})

_SCRIPT = '"${{CLAUDE_SKILL_DIR}}/../../scripts/entry_preflight.py" {plugin} {skill}'
BANG_TMPL = "!`python3 " + _SCRIPT + "`"
ALLOW_TMPL = "Bash(python3 " + _SCRIPT + ")"
ENTRY_HEADING = "## 진입 단계"
SENTINEL_ROWS = (
    "[devbrew-entry] ok",
    "[devbrew-entry] disabled",
    "[devbrew-entry] error",
    "[shell command execution disabled by policy]",
    "감시줄 없음 · 그 밖",
)

SKILL_PATH_RE = re.compile(r"^plugins/([^/]+)/skills/([^/]+)/SKILL\.md$")
COMMAND_PATH_RE = re.compile(r"^plugins/([^/]+)/commands/([^/]+)\.md$")      # 최상위 명령만 G 에서 풀린다
ANY_COMMAND_RE = re.compile(r"^plugins/([^/]+)/commands/.+\.md$")           # H 는 깊이를 가리지 않는다
# 기계 텍스트가 정당하게 이름 붙일 수 있는 다른 마켓플레이스의 플러그인. 지금은 비어 있다.
EXTERNAL_PLUGINS = frozenset()
KEBAB_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)+$")
BANG_RE = re.compile(r"(?:^|(?<=\s))!`([^`\n]+)`")       # 플랫폼 규칙: 줄 시작 또는 공백 뒤
FENCE_BANG_RE = re.compile(r"^\s*```!\s*$")
USER_ARG_RE = re.compile(r"\$(?:ARGUMENTS|\{ARGUMENTS|[0-9]|\{[0-9]|\[[0-9])")
_LEAD = r"(?:^|(?<=[\s`'\"(「]))"
_TRAIL = r"(?=$|[\s`'\"@)」])"
FULL_CALL_RE = re.compile(_LEAD + r"/([a-z0-9][a-z0-9-]*):([a-z0-9][a-z0-9-]*)" + _TRAIL)
OLD_NAME_RE = re.compile(
    r"conducting-interview|framing-requests|reviewing-spec|auditing-plugins"
    r"|commands/(?:interview|request-framing|plugin-audit|project-init)\.md")
OLD_CALL_RE = re.compile(_LEAD + r"/interview" + _TRAIL)
MACHINE_DIRS = frozenset({"skills", "hooks", "scripts", "templates", "references", "agents"})
LIVE_TOP = frozenset({"CLAUDE.md", "README.md", "docs/plugin-authoring.md"})
LIVE_PREFIX = ("plugins/", "shared/", "docs/philosophy/")


class Ledger:
    def __init__(self, report_mode):
        self.report_mode = report_mode
        self.red = []
        self.rep = []

    def add(self, axis, path, line, msg):
        row = (axis, path, line, msg)
        if self.report_mode and path.startswith(QG):
            self.rep.append(row)
        else:
            self.red.append(row)


def git_files(root):
    proc = subprocess.run(
        ["git", "-C", root, "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        capture_output=True, check=True)
    names = set(p for p in proc.stdout.decode("utf-8", "surrogateescape").split("\0") if p)
    return sorted(p for p in names if os.path.lexists(os.path.join(root, p)))


def frontmatter(text):
    """(최상위 키 → 값 줄 목록, 본문 첫 줄의 0-기반 인덱스). 없거나 안 닫히면 ({}, 0)."""
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return {}, 0
    keys, cur = {}, None
    for i in range(1, len(lines)):
        ln = lines[i]
        if ln.strip() == "---":
            return keys, i + 1
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_-]*):(.*)$", ln)
        if m:
            cur = m.group(1)
            val = m.group(2).strip()
            keys[cur] = [val] if val else []
        elif cur is not None and ln.strip():
            keys[cur].append(ln.strip())
    return {}, 0


def first(fm, key):
    vals = fm.get(key) or [""]
    return vals[0].strip().strip("\"'")


def list_items(vals):
    return [v[2:].strip() for v in vals if v.startswith("- ")]


def is_internal(fm):
    return first(fm, "user-invocable").lower() == "false"


class Scan:
    def __init__(self, root):
        self.root = root
        self.files = git_files(root)
        self.fset = frozenset(self.files)
        self.scanned = set()
        self.L = Ledger(any(f.startswith(QG_COMMANDS) for f in self.files))
        self.skills = {}
        for rel in self.files:
            m = SKILL_PATH_RE.match(rel)
            if not m:
                continue
            text = self.read(rel)
            if text is None:
                continue
            fm, body_at = frontmatter(text)
            self.skills[(m.group(1), m.group(2))] = (rel, text, fm, body_at)
        self.plugins = frozenset(f.split("/")[1] for f in self.files
                                 if f.startswith("plugins/") and f.count("/") >= 2)

    def read(self, rel):
        path = os.path.join(self.root, rel)
        if not os.path.isfile(path):
            return None
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        except OSError:
            return None
        self.scanned.add(rel)
        return text

    def run(self):
        self.axis_skills()
        self.axis_d()
        self.axis_g()
        self.axis_h()
        self.axis_i()
        return self.L

    # 축 A · B · C · E · F
    def axis_skills(self):
        L = self.L
        for (plugin, d), (rel, text, fm, body_at) in sorted(self.skills.items()):
            if not fm:
                L.add("A", rel, 1, "frontmatter 가 없거나 닫히지 않았다")
                continue
            for key in fm:
                if key not in SKILL_KEYS:
                    L.add("E", rel, 1, "frontmatter 키 '%s' 는 공식 키 ∪ {cost_class} 밖이다" % key)
            name = first(fm, "name")
            head_word = name.split("-")[0]
            if is_internal(fm):
                if not head_word.endswith("ing"):
                    L.add("B", rel, 1, "내부 skill(user-invocable: false) '%s' 의 첫 단어가 동명사가 아니다" % name)
                continue
            if name != d:
                L.add("A", rel, 1, "name '%s' 이 디렉토리 '%s' 와 다르다" % (name, d))
            if not KEBAB_RE.match(name):
                L.add("A", rel, 1, "진입 skill 이름 '%s' 이 kebab 두 단어 이상이 아니다" % name)
            elif head_word.endswith("ing"):
                L.add("A", rel, 1, "진입 skill 이름 '%s' 의 첫 단어가 동명사다 — 동명사는 내부 skill 의 몫" % name)
            self.check_head(plugin, d, rel, text, fm, body_at)
        dmi = set((p, d) for (p, d), (_r, _t, fm, _b) in self.skills.items()
                  if fm and not is_internal(fm) and first(fm, "disable-model-invocation").lower() == "true")
        for p, d in sorted(dmi - USER_ONLY):
            L.add("F", "plugins/%s/skills/%s/SKILL.md" % (p, d), 1,
                  "disable-model-invocation: true 는 {plugin-audit, project-init} 둘에만 둔다")
        for p, d in sorted(USER_ONLY - dmi):
            L.add("F", "plugins/%s/skills/%s/SKILL.md" % (p, d), 1,
                  "사용자 전용 진입 skill 에 disable-model-invocation: true 가 없다")

    def check_head(self, plugin, d, rel, text, fm, body_at):
        L = self.L
        lines = text.split("\n")
        body = lines[body_at:]
        want_bang = BANG_TMPL.format(plugin=plugin, skill=d)
        want_allow = ALLOW_TMPL.format(plugin=plugin, skill=d)
        raw = sum(ln.count("!`") for ln in body)
        bangs = [(body_at + i, m.group(0)) for i, ln in enumerate(body) for m in BANG_RE.finditer(ln)]
        if raw != 1 or len(bangs) != 1:
            L.add("C", rel, body_at + 1, "사전 검사 줄이 정확히 하나가 아니다(실행형 %d개 · 느낌표-백틱 %d개)" % (len(bangs), raw))
        elif bangs[0][1] != want_bang or lines[bangs[0][0]] != want_bang:
            L.add("C", rel, bangs[0][0] + 1, "사전 검사 줄이 기대 모양과 다르다(0열 · 줄 전체 일치) — 기대: %s" % want_bang)
        if list_items(fm.get("allowed-tools", [])) != [want_allow] or len(fm.get("allowed-tools", [])) != 1:
            L.add("C", rel, 1, "allowed-tools 가 사전 검사 한 항목만이 아니다 — 기대: [%s]" % want_allow)
        heading = next((body_at + i for i, ln in enumerate(body) if ln.strip() == ENTRY_HEADING), None)
        if heading is None:
            L.add("C", rel, 1, "`## 진입 단계` 절이 없다")
        else:
            if bangs and bangs[0][0] > heading:
                L.add("C", rel, bangs[0][0] + 1, "사전 검사 줄이 `## 진입 단계` 위에 있지 않다")
            elif bangs and any(ln.strip() for ln in lines[bangs[0][0] + 1:heading]):
                L.add("C", rel, bangs[0][0] + 1, "사전 검사 줄과 `## 진입 단계` 사이에 빈 줄 아닌 줄이 있다")
            end = next((j for j in range(heading + 1, len(lines)) if lines[j].startswith("## ")), len(lines))
            section = "\n".join(lines[heading + 1:end])
            for row in SENTINEL_ROWS:
                if row not in section:
                    L.add("C", rel, heading + 1, "진입 단계에 감시줄 판독 행 '%s' 이 없다" % row)
        script = "plugins/%s/scripts/entry_preflight.py" % plugin
        if script not in self.fset:
            L.add("C", rel, 1, "%s 가 없다 — 사전 검사 줄이 가리키는 스크립트" % script)

    # 축 D — skills · references 의 사전 검사 줄과 ```! 블록
    def axis_d(self):
        for rel in self.files:
            parts = rel.split("/")
            if len(parts) < 4 or parts[0] != "plugins" or parts[2] not in ("skills", "references"):
                continue
            if not rel.endswith(".md") or "/tests/" in rel:
                continue
            text = self.read(rel)
            if text is None:
                continue
            in_fence = False
            for n, ln in enumerate(text.split("\n"), 1):
                if in_fence:
                    if ln.strip().startswith("```"):
                        in_fence = False
                    elif USER_ARG_RE.search(ln):
                        self.L.add("D", rel, n, "```! 블록 안에 사용자 인자 토큰이 있다")
                    continue
                if FENCE_BANG_RE.match(ln):
                    in_fence = True
                    continue
                for m in BANG_RE.finditer(ln):
                    if USER_ARG_RE.search(m.group(1)):
                        self.L.add("D", rel, n, "사전 검사 줄에 사용자 인자 토큰이 있다")

    # 축 G — 기계 코퍼스의 안내
    def axis_g(self):
        invocable = set(k for k, (_r, _t, fm, _b) in self.skills.items() if fm and not is_internal(fm))
        commands = set()
        for rel in self.files:
            m = COMMAND_PATH_RE.match(rel)
            if m:
                commands.add((m.group(1), m.group(2)))
        short = sorted(set(s for _p, s in ENTRY_SKILLS))
        bare_re = re.compile(_LEAD + r"/(" + "|".join(re.escape(s) for s in short) + r")" + _TRAIL)
        for rel in self.files:
            parts = rel.split("/")
            if len(parts) < 4 or parts[0] != "plugins" or parts[2] not in MACHINE_DIRS:
                continue
            text = self.read(rel)
            if text is None:
                continue
            for n, ln in enumerate(text.split("\n"), 1):
                for m in FULL_CALL_RE.finditer(ln):
                    p, x = m.group(1), m.group(2)
                    if p not in EXTERNAL_PLUGINS and (p, x) not in invocable and (p, x) not in commands:
                        self.L.add("G", rel, n, "/%s:%s 는 사용자 호출 가능한 skill · 명령으로 풀리지 않는다" % (p, x))
                for m in bare_re.finditer(ln):
                    self.L.add("G", rel, n, "기계가 내는 안내의 bare /%s — 완전명 /<plugin>:%s 로" % (m.group(1), m.group(1)))

    # 축 H — 명령 층
    def axis_h(self):
        for rel in self.files:
            if ANY_COMMAND_RE.match(rel):
                self.L.add("H", rel, 1, "commands/ 층은 qg 밖에 두지 않는다 — 사전 단계는 진입 skill 의 사전 검사 줄로")

    # 축 I — 살아 있는 표면의 옛 이름 + 양성 짝
    def axis_i(self):
        for rel in self.files:
            if rel in SELF_FILES or os.path.basename(rel) == "CHANGELOG.md" or "/tests/fixtures/" in rel:
                continue
            if not (rel in LIVE_TOP or rel.startswith(LIVE_PREFIX)):
                continue
            text = self.read(rel)
            if text is None:
                continue
            for n, ln in enumerate(text.split("\n"), 1):
                for m in OLD_NAME_RE.finditer(ln):
                    self.L.add("I", rel, n, "옛 이름 '%s'" % m.group(0))
                for _m in OLD_CALL_RE.finditer(ln):
                    self.L.add("I", rel, n, "옛 호출 토큰 '/interview'")
        for p, s in ENTRY_SKILLS:
            v = self.skills.get((p, s))
            if v is None or first(v[2], "name") != s:
                self.L.add("I", "plugins/%s/skills/%s/SKILL.md" % (p, s), 1,
                           "새 이름 진입 skill '%s' 가 자기 자리에 없다(양성 짝)" % s)


def print_head(plugin, skill):
    sys.stdout.write("allowed-tools:\n  - %s\n---\n\n%s\n\n%s\n" % (
        ALLOW_TMPL.format(plugin=plugin, skill=skill), BANG_TMPL.format(plugin=plugin, skill=skill), ENTRY_HEADING))


def render_report(L):
    out = ["<!-- check_invocation_surface.py --report -->"]
    if not L.report_mode:
        out.append("> 보고 모드가 아니다 — %s." % SCOPE_OFF)
    else:
        out.append("> 이 표는 `plugins/quality-gates/commands/` 가 있는 동안 유지되는 보고 모드의 산출이다. "
                   "그 디렉토리가 사라지면 같은 행이 RED 가 된다.")
    out += ["", "| # | 축 | 위치 | 위반 | v10 설계 |", "|---|---|---|---|---|"]
    for i, (axis, path, line, msg) in enumerate(sorted(L.rep), 1):
        out.append("| %d | %s | `%s:%d` | %s | |" % (i, axis, path, line, msg.replace("|", "\\|")))
    return "\n".join(out) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--emit-scanned", action="store_true")
    ap.add_argument("--print-head", nargs=2, metavar=("PLUGIN", "SKILL"))
    a = ap.parse_args(argv)
    if a.print_head:
        print_head(*a.print_head)
        return 0
    try:
        scan = Scan(a.root)
        L = scan.run()
    except Exception as exc:  # noqa: BLE001 — 예기치 못한 예외는 RED(1)가 아니라 내부 오류(2)
        sys.stderr.write("[invocation-surface] 내부 오류: %s\n" % exc)
        return 2
    if a.emit_scanned:
        sys.stdout.write("".join(p + "\n" for p in sorted(scan.scanned)))
        return 0
    if a.report:
        sys.stdout.write(render_report(L))
        return 0
    for axis, path, line, msg in sorted(L.red):
        print("RED %s %s:%d %s" % (axis, path, line, msg))
    if L.red:
        print("[invocation-surface] RED %d건 — 축 A~I (설계 2026-10-09 §4). %s"
              % (len(L.red), SCOPE_ON if L.report_mode else SCOPE_OFF))
        return 1
    print("[invocation-surface] GREEN — qg 보고 행 %d건. %s" % (len(L.rep), SCOPE_ON if L.report_mode else SCOPE_OFF))
    return 0


if __name__ == "__main__":
    sys.exit(main())
