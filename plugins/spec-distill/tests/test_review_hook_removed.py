#!/usr/bin/env python3
"""AC1 · AC2 · AC7 — 설계문서 리뷰 훅 제거의 부재 락.

AC2 의 검사 목록은 손으로 적지 않고 아래 `DELETED` 에서 **도출**한다(base 커밋 `BASE` 의 원본):
  S1 삭제 파일 이름 — 코어는 stem, 테스트·fixture 는 basename.
  S2 삭제 코어 .py 의 공개 함수·클래스·대문자 상수 + `hook_common.py` 에서 빠진 최상위 이름
     (base AST − 현재 AST). `_` 나 낙타 대문자를 가진 6자 이상만 — `main`·`discover` 같은
     일반어는 삭제 식별자가 될 수 없다.
  S3 그 대문자 상수의 문자열 값에 든 상태 키(`<snake>:`).
  S4 삭제 코어 .py 의 `DEVBREW_*` 문자열.
  S5 삭제 코어 .py 의 하이픈 소문자 문자열(CLI 하위 명령 등).
S2·S4·S5 에서는 **살아 있는 어휘**를 뺀다: base 에서 삭제도 수정도 하지 않은 파일
(`DELETED` ∪ `EDITED` ∪ 역사 밖)에 이미 나오는 이름은 이 변경의 인용이 아니다. S4 는 추가로
살아 있는 스위치를 뺀다 — 추적되는 비-테스트 .py 중 `EDITED` 밖 파일이 문자열로 쥔 이름이다.
은퇴 토큰(`RETIRED_LITERALS`)은 빼지 않는다: 그 리터럴은 (b) 자리에서만 가려진다.

「현재형」은 기계로 가르지 않고 면제 코퍼스로 정한다(설계 AC2):
  (a) 역사 — `*/CHANGELOG.md` · `docs/archive/**` · `docs/audits/README.md` ·
      `docs/superpowers/{specs,plans,interview}/**` · 날짜 붙은 `docs/audits/*.md`
  (b) 은퇴 토큰 리터럴 **만** — `scripts/review_entry.py` · `tests/test_review_entry.py` ·
      README 「은퇴한 스위치」 절(절 헤딩부터 다음 `## ` 까지). 그 안의 다른 삭제 식별자는 RED.
  (c) 이 파일 자신.
면제를 넓힐 때는 이 docstring 에 이유를 함께 적는다.

개념 별칭(`ALIASES`)은 일반어라 리포 전체에 걸면 무관한 파일이 걸린다 — spec-distill 배포 파일
(`tests/`·CHANGELOG 제외)과 설계 §5 의 공용 파일로 한정한다.

재지 못하는 것: 문장이 현재형인지(면제 코퍼스로 대신한다). `EDITED` 에서 빠진 인용 파일이 있으면
그 파일이 인용한 S2·S4·S5 이름은 살아 있는 어휘로 오인된다 — `test_report_live_vocabulary` 가
제외 목록과 그 사유 파일을 출력한다. 사람이 그 목록을 볼 것.

base 커밋 `c7b4f580` 이 reachable 해야 한다 — 얕은 클론·이력 재작성에서는 `test_base_commit_reachable`
이 이유를 대고 RED 다(도출 불가 = fail-closed).

Run:
    cd plugins/spec-distill/tests && python3 -m unittest -v test_review_hook_removed
"""
from __future__ import annotations

import ast
import functools
import json
import re
import subprocess
import sys
import unittest
import warnings
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SELF = "plugins/spec-distill/tests/test_review_hook_removed.py"
BASE = "c7b4f580"
SD = "plugins/spec-distill"

DELETED_CORE = (
    f"{SD}/hooks/review-dispatch.py",
    f"{SD}/scripts/arm_ledger.py",
    f"{SD}/scripts/discover_candidates.py",
    f"{SD}/scripts/parse_spec_structure.py",
    f"{SD}/scripts/resolve_mode.py",
    f"{SD}/scripts/ambiguity-blacklist.txt",
    f"{SD}/templates/spec-template.md",
)
DELETED_OTHER = tuple(f"{SD}/tests/{n}" for n in (
    "test_arm_ledger.py", "test_arm_ledger_timing.sh", "test_arm_once.sh", "arm_test_helpers.sh",
    "test_discover_candidates.py", "test_discovery_driven_dispatch.py",
    "test_parse_spec_structure.sh", "test_resolve_mode_scope.sh", "test_review_dispatch.sh",
    "test_review_dispatch_design_mandate.sh", "test_review_dispatch_disposition.sh",
    "test_stop_absorbs_validation.py", "test_write_path_behavior.sh",
)) + tuple(f"{SD}/tests/fixtures/{n}" for n in (
    "2026-05-17-test-design.md", "spec-valid.md", "spec-missing-goals.md",
    "spec-ambiguity-line12.md", "spec-ambiguity-escaped.md",
    "design-no-frontmatter.md", "design-tbd.md",
)) + (
    "shared/tests/fixtures/adjudication/block_disposition_decoy.py",
    "shared/tests/fixtures/adjudication/run_block_disposition_count.py",
)
DELETED = DELETED_CORE + DELETED_OTHER
HOOK_COMMON = f"{SD}/scripts/hook_common.py"

#: 이 변경이 인용을 고친 파일(새 파일 제외). base 에서 여기에만 나오는 이름은 살아 있는 어휘가 아니다.
EDITED = (
    f"{SD}/.claude-plugin/plugin.json", f"{SD}/hooks/hooks.json",
    f"{SD}/hooks/session-end-cleanup.py", HOOK_COMMON,
    f"{SD}/scripts/state_path.py", f"{SD}/scripts/check_brief.py",
    f"{SD}/scripts/codex_prompt_common.py",
    f"{SD}/skills/reviewing-spec/SKILL.md", f"{SD}/skills/reviewing-brief/SKILL.md",
    f"{SD}/skills/conducting-interview/references/finishing.md",
    f"{SD}/templates/interview-brief-template.md", f"{SD}/README.md",
    f"{SD}/tests/test_hook_output_schema.py", f"{SD}/tests/test_reviewing_spec_design_only.sh",
    f"{SD}/tests/test_session_end_cleanup.py", f"{SD}/tests/test_brainstorming_entry.sh",
    f"{SD}/tests/test_brief_review_meta.sh", f"{SD}/tests/test_stale_terms.sh",
    f"{SD}/tests/test_readme_sync.sh", f"{SD}/tests/test_probe_sweep_residue.sh",
    f"{SD}/tests/test_reviewing_spec_state_keying.sh",
    f"{SD}/tests/test_handoff_context_empty_subsections.sh",
    f"{SD}/tests/test_handoff_conversation_reference.sh",
    "plugins/quality-gates/.claude-plugin/plugin.json",
    "plugins/quality-gates/scripts/codex_prompt_common.py",
    "shared/codex/codex_prompt_common.py", "shared/docreview/scripts/docreview_state.py",
    "shared/tests/test_adjudication_consumed.sh",
    "shared/tests/test_adjudication_wiring.sh",
    "tools/adjudication/check_wiring.py", "tools/adjudication/check_names.py",
)

HISTORY = re.compile(
    r"(^|/)CHANGELOG\.md$|^docs/archive/|^docs/audits/README\.md$"
    r"|^docs/superpowers/(specs|plans|interview)/|^docs/audits/\d{4}-\d{2}-\d{2}-"
)
#: (b) 면제 — 긴 것부터 가린다. 가린 자리는 같은 길이의 공백이라 줄 번호가 보존된다.
RETIRED_LITERALS = (
    "DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW", "spec-distill:UserPromptSubmit",
    "spec-distill:review-dispatch", "spec-distill:PostToolUse", "spec-distill:validator",
    "spec-distill:reminder", "spec-distill:Stop", ":review-dispatch", ":validator", ":reminder",
)
LITERAL_EXEMPT_FILES = (f"{SD}/scripts/review_entry.py", f"{SD}/tests/test_review_entry.py")
README = f"{SD}/README.md"
README_RETIRED_HEADING = re.compile(r"^### 은퇴한 스위치")

ALIAS_SCOPE_EXTRA = (
    "shared/codex/codex_prompt_common.py", "plugins/quality-gates/scripts/codex_prompt_common.py",
    "shared/docreview/scripts/docreview_state.py", "tools/adjudication/check_names.py",
)
#: (별칭 정규식, 그것이 실제로 매치하는 표본) — 표본은 계측기 확인용.
ALIASES = (
    (r"Stop ?(훅|hook)", "Stop 훅이"),
    (r"\[Stop:", "[Stop: 발견"),
    (r"(?<![\w-])mandate(?![\w-])", "the mandate says"),
    (r"arm 원장", "arm 원장을"),
    (r"arm-once", "arm-once 게이트"),
    (r"(?<![\w-])born(?![\w-])", "c.born 검사"),
    (r"in-flight 표시", "in-flight 표시를"),
    (r"구조 검증", "구조 검증을"),
    (r"REDISPATCH", "REDISPATCH_TTL"),
    (r"G6 상한", "G6 상한에"),
    (r"자동 dispatch", "자동 dispatch 가"),
    (r"훅이 읽는", "훅이 읽는 파일"),
    (r"발견의 한계", "### 발견의 한계"),
)

SPECIFIC = re.compile(r"_|[a-z][A-Z]")
KEY_RE = re.compile(r"(?<![A-Za-z0-9_])([a-z]+(?:_[a-z]+)+):")
ENV_RE = re.compile(r"^DEVBREW_[A-Z0-9_]+$")
HYPHEN_RE = re.compile(r"^[a-z]+(?:-[a-z]+)+$")


def git(*args: str, check: bool = True) -> str:
    cp = subprocess.run(["git", "-C", str(REPO), *args], capture_output=True, check=check)
    return cp.stdout.decode("utf-8", "replace")


def base_text(path: str) -> str:
    return git("show", f"{BASE}:{path}")


def head_files() -> list[str]:
    return git("ls-files", "--cached", "--others", "--exclude-standard").splitlines()


def parse_py(src: str) -> ast.Module:
    """다른 파일의 원문을 읽는다 — 그 원문이 내는 SyntaxWarning·DeprecationWarning 은 이 락의 출력이 아니다."""
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        return ast.parse(src)


def consts(tree: ast.Module):
    for n in tree.body:
        if isinstance(n, ast.Assign):
            for tg in n.targets:
                if isinstance(tg, ast.Name):
                    yield tg.id, n.value


def strings(node) -> list[str]:
    return [n.value for n in ast.walk(node)
            if isinstance(n, ast.Constant) and isinstance(n.value, str)]


def top_names(tree: ast.Module) -> set[str]:
    out = {n.name for n in tree.body if isinstance(n, (ast.FunctionDef, ast.ClassDef))}
    return out | {k for k, _ in consts(tree)}


def boundary(tok: str) -> str:
    return r"(?<![\w-])" + re.escape(tok) + r"(?![\w-])"


@functools.lru_cache(maxsize=None)
def derivation():
    s1 = {Path(p).stem for p in DELETED_CORE} | {Path(p).name for p in DELETED_OTHER}
    trees = [parse_py(base_text(p)) for p in DELETED_CORE if p.endswith(".py")]
    hc_base = parse_py(base_text(HOOK_COMMON))
    hc_head = parse_py((REPO / HOOK_COMMON).read_text(encoding="utf-8"))
    hc_removed = top_names(hc_base) - top_names(hc_head)

    s2 = set(hc_removed)
    for t in trees:
        s2 |= {n.name for n in t.body
               if isinstance(n, (ast.FunctionDef, ast.ClassDef)) and not n.name.startswith("_")}
        s2 |= {k for k, _ in consts(t) if k.isupper()}
    s2 = {n for n in s2 if len(n) >= 6 and SPECIFIC.search(n)}

    s3 = set()
    for t in trees:
        for k, v in consts(t):
            if k.isupper():
                for s in strings(v):
                    s3.update(KEY_RE.findall(s))
    for k, v in consts(hc_base):
        if k in hc_removed and k.isupper():
            for s in strings(v):
                s3.update(KEY_RE.findall(s))

    s4, s5 = set(), set()
    for t in trees:
        for s in strings(t):
            if ENV_RE.match(s):
                s4.add(s)
            if HYPHEN_RE.match(s):
                s5.add(s)

    skip = set(DELETED) | set(EDITED)
    stop = {}
    for tok in sorted(s2 | s4 | s5):
        rx = re.compile(boundary(tok))
        for line in git("grep", "-l", "-F", "-e", tok, BASE, "--", check=False).splitlines():
            path = line.split(":", 1)[1]
            if path in skip or HISTORY.search(path):
                continue
            if rx.search(base_text(path)):
                stop[tok] = path
                break

    # `EDITED` 파일은 뺀다 — 이 변경이 남긴 인용이 자기 토큰을 스스로 살려낼 수 있기
    # 때문이다. 추적 파일만 본다(`--others` 없이) — untracked 스크래치가 살려내면
    # 로컬 뿐인 흔적이 리포 공통 판정을 바꾼다. 은퇴 토큰은 여기서 다시 뺀다 —
    # 그 리터럴은 (b) 세 자리에서만 가려지는 것이지 「살아 있는 스위치」가 아니다.
    live_env = {}
    for f in git("ls-files").splitlines():
        if not f.endswith(".py") or "/tests/" in f or f in DELETED or f in EDITED:
            continue
        p = REPO / f
        if p.is_symlink() or not p.is_file():
            continue
        try:
            names = set(strings(parse_py(p.read_text(encoding="utf-8")))) & s4
        except (SyntaxError, UnicodeDecodeError):
            continue
        for name in names:
            live_env.setdefault(name, f)
    for lit in RETIRED_LITERALS:
        live_env.pop(lit, None)

    tokens = (s1 | s3 | ((s2 | s4 | s5) - set(stop))) - set(live_env)
    return {"S1": s1, "S2": s2, "S3": s3, "S4": s4, "S5": s5}, stop, live_env, frozenset(tokens)


def masked(path: str, text: str) -> str:
    def blank(ln: str) -> str:
        for lit in RETIRED_LITERALS:
            ln = ln.replace(lit, " " * len(lit))
        return ln
    if path in LITERAL_EXEMPT_FILES:
        return blank(text)
    if path == README:
        out, inside = [], False
        for ln in text.split("\n"):
            if README_RETIRED_HEADING.match(ln):
                inside = True
            elif inside and ln.startswith("## "):
                inside = False
            out.append(blank(ln) if inside else ln)
        return "\n".join(out)
    return text


def scan_text(path: str, text: str, tokens) -> list[str]:
    rx = re.compile(r"(?<![\w-])(" + "|".join(
        re.escape(t) for t in sorted(tokens, key=len, reverse=True)) + r")(?![\w-])")
    return [f"{path}:{i}: {m.group(1)}"
            for i, ln in enumerate(masked(path, text).splitlines(), 1)
            for m in rx.finditer(ln)]


def read_head(path: str):
    p = REPO / path
    if p.is_symlink() or not p.is_file():
        return None
    try:
        return p.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return None


class TestHooksJson(unittest.TestCase):
    """AC1 — `Stop` 이 없고 `SessionEnd` 가 있다(부재 ↔ 존재 짝)."""

    def test_no_stop_and_session_end_present(self):
        d = json.loads((REPO / SD / "hooks" / "hooks.json").read_text(encoding="utf-8"))
        hooks = d.get("hooks", {})
        self.assertNotIn("Stop", hooks)
        cmds = [h.get("command", "") for blk in hooks.get("SessionEnd", [])
                for h in blk.get("hooks", [])]
        self.assertTrue(any("session-end-cleanup.py" in c for c in cmds), cmds)


class TestDeletedFiles(unittest.TestCase):
    """AC2 — 삭제 파일 부재 + 후계 파일 존재."""

    def test_deleted_paths_absent(self):
        self.assertEqual([p for p in DELETED if (REPO / p).exists()], [])

    def test_successors_present(self):
        for p in (f"{SD}/hooks/session-end-cleanup.py", f"{SD}/scripts/review_entry.py",
                  HOOK_COMMON):
            with self.subTest(p=p):
                self.assertTrue((REPO / p).is_file())


class TestDerivationInstrument(unittest.TestCase):
    """계측기 — 도출이 비지 않았고 스캐너가 실제 잔존을 잡는다."""

    def test_base_commit_reachable(self):
        cp = subprocess.run(["git", "-C", str(REPO), "cat-file", "-e", f"{BASE}^{{commit}}"],
                            capture_output=True)
        self.assertEqual(cp.returncode, 0,
                         f"base 커밋 {BASE} 가 없다(얕은 클론?) — 도출 불가, 이 락은 fail-closed")

    def test_derived_sets_not_vacuous(self):
        d, _, _, tokens = derivation()
        self.assertEqual(len(d["S1"]), len(DELETED))
        self.assertGreaterEqual(len(d["S2"]), 30)
        self.assertGreaterEqual(len(d["S3"]), 7)
        self.assertGreaterEqual(len(tokens), 80)

    def test_scanner_finds_residue_in_base_readme(self):
        """양성 대조 — base 의 README(이 변경 전)에는 인용이 가득했다. 못 잡으면 스캐너가 죽었다."""
        hits = scan_text(README, base_text(README), derivation()[3])
        self.assertGreaterEqual(len(hits), 10, hits)

    def test_report_live_vocabulary(self):
        _, stop, live_env, _ = derivation()
        sys.stderr.write("\n[살아 있는 어휘로 제외] " + ", ".join(
            f"{k} ← {v}" for k, v in sorted(stop.items())) + "\n")
        sys.stderr.write("[살아 있는 스위치로 제외] " + ", ".join(
            f"{k} ← {v}" for k, v in sorted(live_env.items())) + "\n")

    def test_alias_canaries(self):
        for pat, sample in ALIASES:
            with self.subTest(pat=pat):
                self.assertRegex(sample, pat)


class TestResidue(unittest.TestCase):
    """AC2 — 삭제 식별자(리포 전체)와 개념 별칭(한정 범위)의 잔존."""

    def test_no_identifier_residue(self):
        tokens = derivation()[3]
        scanned = []
        hits = []
        for f in head_files():
            if f == SELF or HISTORY.search(f):
                continue
            text = read_head(f)
            if text is not None:
                scanned.append(f)
                hits += scan_text(f, text, tokens)
        for must in (f"{SD}/README.md", f"{SD}/skills/reviewing-spec/SKILL.md",
                     f"{SD}/scripts/review_entry.py"):
            with self.subTest(must=must):
                self.assertIn(must, scanned, "스캔 대상에서 빠졌다 — HISTORY/면제가 넓어졌다")
        self.assertEqual(hits, [], "\n".join(hits[:60]))

    def _alias_scope(self) -> list[str]:
        files = [f for f in head_files() if f.startswith(SD + "/")
                 and "/tests/" not in f and not f.endswith("CHANGELOG.md")]
        return files + list(ALIAS_SCOPE_EXTRA)

    def test_alias_scope_not_vacuous(self):
        scope = self._alias_scope()
        self.assertGreaterEqual(len(scope), 30)
        for must in (README, f"{SD}/skills/reviewing-spec/SKILL.md", *ALIAS_SCOPE_EXTRA):
            with self.subTest(must=must):
                self.assertIn(must, scope)
                self.assertIsNotNone(read_head(must))

    def test_no_alias_residue_in_scope(self):
        rx = re.compile("|".join(f"(?:{p})" for p, _ in ALIASES))
        hits = []
        for f in self._alias_scope():
            text = read_head(f)
            if text is None:
                continue
            for i, ln in enumerate(text.splitlines(), 1):
                m = rx.search(ln)
                if m:
                    hits.append(f"{f}:{i}: [{m.group(0)}] {ln.strip()[:100]}")
        self.assertEqual(hits, [], "\n".join(hits[:60]))


class TestReviewingSpecContract(unittest.TestCase):
    """AC7 — 옛 입력 계약의 부재 + 새 입력 계약의 존재."""

    SKILL = REPO / SD / "skills" / "reviewing-spec" / "SKILL.md"

    def test_old_input_contract_absent(self):
        t = self.SKILL.read_text(encoding="utf-8")
        for pat in (r"\$mode\b", r"mode: (design|spec)", r"\$STATE(?![_A-Za-z0-9])",
                    r"arm_ledger", r"## 원장", r"clear-inflight", r"mark-reviewed",
                    r"check-born", r"mandate"):
            with self.subTest(pat=pat):
                self.assertIsNone(re.search(pat, t), pat)

    def test_new_input_contract_present(self):
        t = self.SKILL.read_text(encoding="utf-8")
        self.assertIn('STATE_DIR="$ROOT/$harness_sid"', t)
        self.assertIn("<!-- review-entry:begin -->", t)
        self.assertIn("<!-- uncommitted-check:begin -->", t)
        m = re.search(r"^## 입력\n(.*?)^## ", t, re.S | re.M)
        self.assertIsNotNone(m, "## 입력 절을 못 찾았다")
        self.assertIn("호출 인자", m.group(1))


if __name__ == "__main__":
    unittest.main()
