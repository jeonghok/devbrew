#!/usr/bin/env python3
"""check-staleness.py — 결정론 staleness sweep (design §5.4a).

모델은 '있는 것'만 본다. 'README가 광고하는 scripts/foo.sh가 없다' 같은 flat한 부재는 전수 열거를
요구하며, 모델은 놓쳐도 놓친 줄을 모른다 (거짓 결과). 이 sweep은 사실을 열거하고, 갭인지는 감사자가
판정한다 — **verdict/점수/PASS-FAIL을 내지 않는다** (그게 원장 31이 실증한 함정).

대상 플러그인 디렉토리를 인자로 받는 범용 검사기 → plugin-audit으로 이관. 에이전트 0개, 순수 FS.

함정 (원장 17·32): 거짓 dangling은 감사자를 없는 갭으로 보낸다. 알려진 FP 클래스(코드 펜스 내부·
생성물 경로·플레이스홀더·URL)를 제외한다 — '언급(mention)'과 '주장(use)'을 구별한다.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

# 결정론: 파일 목록은 항상 정렬해서 순회한다 (매니페스트 비결정 = 감사자가 실행마다 다른 사실).
DOC_GLOBS = ("README.md", "CHANGELOG.md", "commands/**/*.md", "templates/**/*",
             "docs/git-workflow/**/*.md")

# 초안 잔재 마커 — 스크립트가 소유한다 (주입 표면에 넣지 않는다, 원장 36 자기매치 방지).
DRAFT_MARKERS = (r"\bTODO\b", r"\bTBD\b", r"\bFIXME\b", r"<!--\s*draft", r"XXX")
PLACEHOLDER_RE = re.compile(r"\{\{[^}]*\}\}|<[a-z][a-z0-9_-]*>|\.\.\.")
URL_RE = re.compile(r"https?://|`?~?/?\.?claude")  # URL·홈경로류는 주장이 아니다


def iter_lines_outside_fences(text: str):
    """(lineno, line)를 내되 코드 펜스(``` ... ```) 내부는 건너뛴다.

    게이트가 '언급 vs 사용'을 구별하는 핵심: 코드 펜스·인용문 안의 경로는 *주장*이 아니다
    (실측 FP, 원장 36 — placeholder 검사기가 자기 설명문에 걸렸다)."""
    in_fence = False
    for i, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        yield i, line


def is_fp_claim(quote: str) -> bool:
    """알려진 FP 클래스: 플레이스홀더·URL·생성물 경로. True면 사실로 emit하지 않는다."""
    return bool(PLACEHOLDER_RE.search(quote) or URL_RE.search(quote))


def emit(facts, cls, file, line, quote, **extra):
    facts.append({"class": cls, "file": file, "line": line, "quote": quote, **extra})


# ---------------------------------------------------------------------------
# Class 1: dangling doc-claim (2-way lookup: worktree + HEAD)
# ---------------------------------------------------------------------------

# 백틱 인용 경로 후보: `path/like/this` 중 슬래시 또는 확장자를 포함하는 것.
BACKTICK_PATH_RE = re.compile(r"`([^`]+)`")
PATHISH_RE = re.compile(r"[/.]")

# "경로 주장" 자격 확장자 — 슬래시가 없어도 이 확장자로 끝나면 바닥-레벨 파일 주장으로 본다.
# (root-level `setup.sh`/`run.py`가 부재하면 그건 정확히 sweep이 잡아야 할 flat-absence다;
# 슬래시를 무조건 요구하면 그 사실을 통째로 흘린다 — reviewer Important 2.)
KNOWN_CLAIM_EXTENSIONS = (".sh", ".py", ".js", ".mjs", ".ts", ".md", ".json", ".yml", ".yaml")

# "생성물(generated-artifact)" 확장자 + bare config 이름 — 생성 동사가 있는 줄에서 이 부류를
# 가리키면 그 경로는 *이 플러그인이 타깃 저장소에 만들어낼 산출물*이지 플러그인 자신이 담아야
# 하는 파일이 아니다 (정확히 부재하는 게 맞음). 스크립트 확장자(.sh/.py/.js/...)는 여기에 없다 —
# 생성기(generator)는 플러그인에 실존해야 하므로 부재는 여전히 진짜 사실 (reviewer Important 1).
GENERATED_ARTIFACT_EXTENSIONS = (".md", ".json", ".txt", ".yml", ".yaml")
BARE_CONFIG_NAMES = {"CLAUDE.md", "AGENTS.md"}
GENERATION_VERB_RE = re.compile(
    r"생성|발행|만든|만들|생성물|스캐폴|출력|작성|"
    r"generate[sd]?|create[sd]?|produce[sd]?|scaffold|emit[s]?", re.IGNORECASE)

# devbrew 자신의 git-workflow 컨벤션이 정의하는 브랜치 타입 어휘 (최상위 CLAUDE.md: "main에서
# feature/* 또는 fix/*"). 이 prefix로 시작하는 슬래시-포함 문자열은 파일 경로가 아니라 브랜치명
# 예시다 — 실측 FP (project-init의 branch-strategy 문서가 `feature/foo-bar` 등을 예시로 인용).
BRANCH_PREFIXES = {"feature", "fix", "hotfix", "release", "bugfix", "chore"}
LINE_NUM_SUFFIX_RE = re.compile(r":\d+$")


def _is_generation_target(cand: str, line: str) -> bool:
    """narrow, high-precision 생성물-경로 제외 (reviewer Important 1). 참이면 dangling으로
    보지 않는다. 조건: (a) 줄에 생성 동사가 있고, (b) 경로가 생성물 확장자(.md/.json/.txt/
    .yml/.yaml)로 끝나거나 bare config 이름(CLAUDE.md/AGENTS.md)이다.

    `scripts/gen.sh` 같은 스크립트가 "generate" 줄에 있어도 .sh는 생성물 확장자가 아니라
    KEEP된다 — 생성기이지 생성물이 아니므로 부재는 진짜 사실. 이 규칙을 넓히지 않는 이유:
    생성 동사 없는 평범한 참조까지 삼키면 진짜 script 주장을 과잉 억제한다 (over-suppression은
    거짓 dangling보다 나쁘지 않지만, 진짜 사실을 흘리는 건 sweep의 존재 이유를 무너뜨린다)."""
    if not GENERATION_VERB_RE.search(line):
        return False
    base = cand.rsplit("/", 1)[-1]
    if base in BARE_CONFIG_NAMES:
        return True
    return cand.endswith(GENERATED_ARTIFACT_EXTENSIONS)


def _looks_like_path_claim(cand: str) -> bool:
    """백틱 인용이 실제 '파일 경로 주장'인지 판별 — mention과 use를 구별하는 두 번째 방어선.
    실측(project-init 전체 스윕, ledger급 FP)에서 드러난 네 부류를 걷어낸다:
      (1) 공백 포함 → 셸 커맨드/산문 조각 인용 (`git merge origin/main`), 경로 아님.
      (2) 디렉터리만 가리키는 trailing '/' 또는 '/*' → 스캐폴딩 컨벤션 예시(`src/`, `docs/`),
          특정 파일을 주장하지 않는다.
      (3) 단일 세그먼트 슬래시-커맨드(`/commit`, 확장자 없음) → Class 5(dangling command/plugin
          ref)의 몫이지 파일 경로 주장이 아니다 — 여기서 다시 잡으면 이중 오탐.
      (4) 첫 세그먼트가 브랜치 타입 어휘(feature/fix/hotfix/release/...)면 브랜치명 예시.
      (5) 정규식 메타문자(`(`·`|`·`)`·`^`·`$`) 포함 → 정규식 패턴 설명이지 리터럴 경로 아님.
    """
    if not cand or re.search(r"\s", cand):
        return False
    if cand.endswith("/") or cand.endswith("/*"):
        return False
    if re.match(r"^/[\w-]+$", cand):
        return False
    if re.search(r"[(|)^$]", cand):
        return False
    first_seg = cand.split("/", 1)[0]
    if "/" in cand and first_seg in BRANCH_PREFIXES:
        return False
    return True


def _iter_docs(plugin_dir: Path):
    seen = []
    for pat in DOC_GLOBS:
        for p in sorted(plugin_dir.glob(pat)):
            if p.is_file():
                seen.append(p.relative_to(plugin_dir))
    return sorted(set(seen))


def _repo_rel(plugin_dir, cand, repo_root):
    try:
        return str((plugin_dir / cand).resolve().relative_to(repo_root.resolve()))
    except ValueError:
        return cand


def scan_dangling_doc_claims(plugin_dir: Path, repo_root: Path, facts):
    """문서가 백틱으로 인용한 경로가 워킹트리에도 HEAD에도 없으면 flag — 2-way lookup
    (worktree + `git cat-file -e HEAD:...`).

    워킹트리엔 없지만 HEAD엔 있던 것(`in_head=True`)과 애초에 없던 것은 다른 사실이므로 둘 다
    담아 감사자에게 넘긴다. **upstream/삭제-이력 lookup은 아직 하지 않는다** — `git log
    --diff-filter=D`로 "언젠가 존재했다 삭제됨"을 3-way로 확인하는 건 후속 enhancement로 유보
    (지금은 worktree + HEAD 두 지점만; 정직하게 2-way).

    후보 자격: 슬래시를 포함하거나(트리 내 구체 경로) 알려진 확장자로 끝난다(root-level
    `setup.sh` 같은 바닥 파일 주장). 슬래시 없고 확장자도 없으면 산문 토큰이라 skip.

    존재성 판정은 후보 형태에 따라 다르다: **슬래시 있는 경로**는 그 정확한 위치에 파일이 있어야
    satisfied(`scripts/foo.sh`가 그 경로에 없으면 dangling). **바닥 이름**(슬래시 없음)은 "이
    파일이 존재한다"류 주장이라 트리 어디든 그 basename이 있으면 satisfied — 실존 파일을 dangling
    으로 라벨링하는 건 거짓 사실이기 때문(reviewer Important 2)."""
    import subprocess
    for rel in _iter_docs(plugin_dir):
        text = (plugin_dir / rel).read_text(encoding="utf-8", errors="replace")
        for lineno, line in iter_lines_outside_fences(text):
            for m in BACKTICK_PATH_RE.finditer(line):
                cand = m.group(1).strip()
                if "/" not in cand and not cand.endswith(KNOWN_CLAIM_EXTENSIONS):
                    continue  # 슬래시도 확장자도 없음 — 경로 주장 아님 (산문 토큰)
                if not PATHISH_RE.search(cand) or is_fp_claim(cand):
                    continue
                if not _looks_like_path_claim(cand):
                    continue
                if _is_generation_target(cand, line):
                    continue  # 타깃 저장소에 생성될 산출물 — 부재가 정상 (reviewer Important 1)
                stripped = LINE_NUM_SUFFIX_RE.sub("", cand)  # `file.py:19` 줄-인용 접미사 제거
                target = (plugin_dir / stripped)
                if target.exists():
                    continue
                # 바닥 이름(슬래시 없음)은 "이 파일이 존재한다"류 주장 — 트리 어디에든 그 basename이
                # 있으면 satisfied (reviewer Important 2 완성). 존재하는 파일을 "dangling"으로 라벨링하는
                # 것은 노이즈가 아니라 거짓 사실이다(예: `plugin.json`은 `.claude-plugin/plugin.json`에
                # 실존). 슬래시 있는 경로는 "이 정확한 위치"라는 구체 주장이므로 정확 경로 체크 그대로 유지.
                if "/" not in stripped and any(plugin_dir.rglob(stripped)):
                    continue
                if (repo_root / stripped).exists():
                    continue  # repo-root 상대 마크다운 링크 컨벤션 (devbrew 자체 문서 관행)
                # HEAD lookup (git-tracked였는지)
                head = subprocess.run(
                    ["git", "-C", str(repo_root), "cat-file", "-e",
                     f"HEAD:{_repo_rel(plugin_dir, stripped, repo_root)}"],
                    capture_output=True)
                in_head = head.returncode == 0
                emit(facts, "dangling doc-claim", str(rel), lineno, cand,
                     in_worktree=False, in_head=in_head)


# ---------------------------------------------------------------------------
# Class 2: frontmatter silent-truncation
# ---------------------------------------------------------------------------

# 모든 .md의 frontmatter top-level scalar에 unquoted ' #' (주석 잘림) 또는 값 안의 ': '
# (중첩 매핑 오인)이 있는가 — YAML이 파서 에러 없이 값을 조용히 잘라먹는다 (CE validate-frontmatter).
UNQUOTED_HASH_RE = re.compile(r"^\s*[\w-]+:\s*[^'\"#\n]*\s#")


def scan_frontmatter_truncation(plugin_dir: Path, facts):
    for md in sorted(plugin_dir.rglob("*.md")):
        if md.is_dir():
            continue
        text = md.read_text(encoding="utf-8", errors="replace")
        fm = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
        if not fm:
            continue
        for offset, line in enumerate(fm.group(1).splitlines(), 2):  # +1 for `---`, +1 to 1-index
            if UNQUOTED_HASH_RE.search(line):
                emit(facts, "frontmatter silent-truncation",
                     str(md.relative_to(plugin_dir)), offset, line.strip())


# ---------------------------------------------------------------------------
# Class 3: version incoherence
# ---------------------------------------------------------------------------


def _load_plugin_json(plugin_dir: Path):
    """plugin.json을 찾아 (path, data)를 반환한다. 없거나 파싱 불가면 (None, None).

    실제 devbrew 컨벤션은 `.claude-plugin/plugin.json` (공식 Claude Code 플러그인 레이아웃 —
    project-init·quality-gates·spec-distill 전부 이 경로). 브리프 fixture는 편의상 plugin_dir
    루트에 둔다 — 두 위치 다 지원해야 실타깃(plugins/project-init)에서 이 클래스가 조용히
    no-op되지 않는다."""
    for cand in (plugin_dir / ".claude-plugin" / "plugin.json", plugin_dir / "plugin.json"):
        if cand.is_file():
            try:
                return cand, json.loads(cand.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                return cand, None
    return None, None


def scan_version_incoherence(plugin_dir: Path, facts):
    pj, data = _load_plugin_json(plugin_dir)
    ch = plugin_dir / "CHANGELOG.md"
    if not pj or not data:
        return
    pjv = data.get("version")
    if ch.is_file() and pjv:
        m = re.search(r"^##\s*\[?(\d+\.\d+\.\d+)\]?", ch.read_text(encoding="utf-8"), re.MULTILINE)
        if m and m.group(1) != pjv:
            emit(facts, "version incoherence", "CHANGELOG.md", 1,
                 f"CHANGELOG 최신 [{m.group(1)}] ≠ plugin.json version {pjv}",
                 plugin_json=pjv, changelog=m.group(1))


# ---------------------------------------------------------------------------
# Class 4: draft residue
# ---------------------------------------------------------------------------

DRAFT_MARKER_RE = re.compile("|".join(DRAFT_MARKERS))


def scan_draft_residue(plugin_dir: Path, facts):
    """출하 문서(README·CHANGELOG·commands·templates)에 초안 잔재 마커가 남아있는지.

    DRAFT_MARKERS는 스크립트가 소유 — 감사 프롬프트 표면에 노출하지 않는다 (자기매치 방지)."""
    for rel in _iter_docs(plugin_dir):
        text = (plugin_dir / rel).read_text(encoding="utf-8", errors="replace")
        for lineno, line in iter_lines_outside_fences(text):
            m = DRAFT_MARKER_RE.search(line)
            if not m:
                continue
            quote = line.strip()
            if is_fp_claim(quote):
                continue
            emit(facts, "draft residue", str(rel), lineno, quote, marker=m.group(0))


# ---------------------------------------------------------------------------
# Class 5: dangling command/plugin ref
# ---------------------------------------------------------------------------

SLASH_CMD_RE = re.compile(r"`/([a-z][a-z0-9_-]*)`")
COLON_REF_RE = re.compile(r"`([a-z][a-z0-9_-]*):([a-z][a-z0-9_-]+)`")
# 같은 줄에 다른 플러그인 귀속이 있는가 — 두 실측 문체 모두 지원:
#   (a) 선행 bold: "- **commit-commands**: `/commit`..." (project-init README 통합 섹션)
#   (b) 후행 괄호: "`/commit` 또는 `/commit-push-pr` (commit-commands 플러그인) 사용"
#       (project-init commands/project-init.md)
# 어느 형태든 자기 이름이 아닌 다른 플러그인이 같은 줄에 언급되면 그 플러그인 커맨드에 대한
# 통합 문서 언급이지 자기-주장이 아니다.
BOLD_ATTR_RE = re.compile(r"\*\*([a-z][a-z0-9_-]*)\*\*\s*[:：]")
PAREN_ATTR_RE = re.compile(r"\(([a-z][a-z0-9_-]*)\s*(?:플러그인|plugin)\)", re.IGNORECASE)

_REGISTRY_ENV = "DEVBREW_STALENESS_REGISTRY"


def _registry_path() -> Path:
    """설치 레지스트리 경로. 테스트 격리를 위해 env override 지원(실제 홈 디렉토리를 읽으면
    머신마다 다른 사실이 나와 결정론 테스트가 host-dependent해진다)."""
    override = os.environ.get(_REGISTRY_ENV)
    if override:
        return Path(override)
    return Path.home() / ".claude" / "plugins" / "installed_plugins.json"


def _load_registry():
    """installed_plugins.json을 읽는다. 부재/파싱실패면 None (= registry: absent 신호)."""
    path = _registry_path()
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


def _registry_has_plugin(registry, name: str) -> bool:
    plugins = (registry or {}).get("plugins", {})
    if not isinstance(plugins, dict):
        return False
    return any(k.split("@", 1)[0] == name for k in plugins)


def _own_plugin_name(plugin_dir: Path) -> str:
    _, data = _load_plugin_json(plugin_dir)
    if data and data.get("name"):
        return data["name"]
    return plugin_dir.name


def _prerequisites_declares(readme_text: str, plugin_name: str) -> bool:
    """README의 '## Prerequisites' 섹션 본문에 plugin_name이 언급되는가."""
    m = re.search(r"^##\s*Prerequisites\s*$(.*?)(?=^##\s|\Z)", readme_text,
                  re.MULTILINE | re.DOTALL)
    if not m:
        return False
    return plugin_name in m.group(1)


def scan_dangling_refs(plugin_dir: Path, facts):
    """두 하위 패턴:
    (a) 자기 `/command` 자기-주장 — `commands/<name>.md`가 없고, 같은 줄에 다른 플러그인
        귀속(선행 bold 또는 후행 괄호)이 없으면 flag (있으면 그 플러그인 커맨드에 대한 통합
        문서 언급이므로 스킵 — 실측 project-init README "- **commit-commands**: `/commit`..."
        + commands/project-init.md "`/commit` ... (commit-commands 플러그인) 사용" FP 둘 다).
    (b) `other-plugin:component` cross-plugin 참조 — 레지스트리에 설치돼 있지 않고(또는
        레지스트리 자체가 부재) **동시에** README `## Prerequisites`에 미선언이면 flag.
        레지스트리 부재는 그 신호만 skip하고(설치 여부를 알 수 없으므로 prerequisites 단독
        판단으로 넘어간다) 사실에 `registry: "absent"`를 남긴다. 자기 이름 참조는 스킵
        (self-reference 표 관용구, 실측 quality-gates/spec-distill README).
    """
    own_name = _own_plugin_name(plugin_dir)
    registry = _load_registry()
    registry_absent = registry is None

    readme = plugin_dir / "README.md"
    readme_text = readme.read_text(encoding="utf-8", errors="replace") if readme.is_file() else ""
    commands_dir = plugin_dir / "commands"

    for rel in _iter_docs(plugin_dir):
        text = (plugin_dir / rel).read_text(encoding="utf-8", errors="replace")
        for lineno, line in iter_lines_outside_fences(text):
            for m in SLASH_CMD_RE.finditer(line):
                quote = m.group(0)
                if is_fp_claim(quote):
                    continue
                attrs = [a.group(1) for a in BOLD_ATTR_RE.finditer(line) if a.start() < m.start()]
                attrs += [a.group(1) for a in PAREN_ATTR_RE.finditer(line)]
                if any(a != own_name for a in attrs):
                    continue  # 외부 플러그인에 귀속된 언급 — 자기-주장 아님
                if (commands_dir / f"{m.group(1)}.md").is_file():
                    continue
                emit(facts, "dangling command/plugin ref", str(rel), lineno, quote, kind="command")

            for m in COLON_REF_RE.finditer(line):
                other = m.group(1)
                quote = m.group(0)
                if is_fp_claim(quote) or other == own_name:
                    continue
                if (not registry_absent) and _registry_has_plugin(registry, other):
                    continue  # 레지스트리가 설치를 확인 — dangling 아님
                if _prerequisites_declares(readme_text, other):
                    continue  # 문서화된 soft-dependency — dangling 아님
                extra = {"kind": "plugin",
                         "registry": "absent" if registry_absent else "not-installed"}
                emit(facts, "dangling command/plugin ref", str(rel), lineno, quote, **extra)


# ---------------------------------------------------------------------------
# Class 6: description drift
# ---------------------------------------------------------------------------


def scan_description_drift(plugin_dir: Path, repo_root: Path, facts):
    """plugin.json description ↔ repo_root/.claude-plugin/marketplace.json 같은 이름 항목의
    description 불일치 (D3 기계화). marketplace.json 부재 또는 매칭 항목 부재면 skip."""
    _, data = _load_plugin_json(plugin_dir)
    if not data or not data.get("name") or not data.get("description"):
        return
    mp_path = repo_root / ".claude-plugin" / "marketplace.json"
    if not mp_path.is_file():
        return
    try:
        mp = json.loads(mp_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return
    entries = mp.get("plugins", [])
    if not isinstance(entries, list):
        return
    match = next((e for e in entries if isinstance(e, dict) and e.get("name") == data["name"]), None)
    if not match or not match.get("description"):
        return
    pj_desc, mp_desc = data["description"].strip(), match["description"].strip()
    if pj_desc != mp_desc:
        emit(facts, "description drift", ".claude-plugin/marketplace.json", 1,
             f"plugin.json 「{pj_desc}」 ≠ marketplace.json 「{mp_desc}」",
             plugin_json=pj_desc, marketplace=mp_desc)


# ---------------------------------------------------------------------------
# Class 7: declared-vs-actual surface
# ---------------------------------------------------------------------------

HOOKS_HEADING_RE = re.compile(r"^##\s*(?:Hooks Installed|.*설치된\s*Hook.*)\s*$", re.MULTILINE)
BULLET_RE = re.compile(r"^\s*-\s+\*\*")
SKILLS_COUNT_RE = re.compile(r"(\d+)\s*(?:개\s*)?(?:skills?|스킬)\b", re.IGNORECASE)


def _actual_hook_count(plugin_dir: Path) -> int:
    hj = plugin_dir / "hooks" / "hooks.json"
    if not hj.is_file():
        return 0
    try:
        data = json.loads(hj.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return 0
    hooks = data.get("hooks", {})
    if not isinstance(hooks, dict):
        return 0
    return sum(len(v) for v in hooks.values() if isinstance(v, list))


def _declared_hook_count(readme_text: str):
    """'## Hooks Installed'(또는 실측 한국어 '## 설치된 Hook') 섹션의 bold 불릿 개수.
    섹션 자체가 없으면 None (= 선언 없음, 비교 대상 없음)."""
    m = HOOKS_HEADING_RE.search(readme_text)
    if not m:
        return None
    rest = readme_text[m.end():]
    next_heading = re.search(r"^##\s", rest, re.MULTILINE)
    section = rest[:next_heading.start()] if next_heading else rest
    return sum(1 for line in section.splitlines() if BULLET_RE.match(line))


def _actual_skill_count(plugin_dir: Path) -> int:
    skills_dir = plugin_dir / "skills"
    if not skills_dir.is_dir():
        return 0
    return sum(1 for d in skills_dir.iterdir() if d.is_dir() and (d / "SKILL.md").is_file())


def scan_declared_surface(plugin_dir: Path, facts):
    """README의 'Hooks Installed'/'N skills' 류 선언 개수 ↔ 디스크 실제 개수 불일치.
    선언 자체가 없으면(섹션 부재·숫자 언급 부재) 비교 대상이 없으므로 스킵 — 이는 category
    absence의 몫이지 이 클래스가 판단할 일이 아니다."""
    readme = plugin_dir / "README.md"
    if not readme.is_file():
        return
    text = readme.read_text(encoding="utf-8", errors="replace")

    declared_hooks = _declared_hook_count(text)
    if declared_hooks is not None:
        actual_hooks = _actual_hook_count(plugin_dir)
        if declared_hooks != actual_hooks:
            emit(facts, "declared-vs-actual surface", "README.md", 1,
                 f"Hooks Installed 선언 {declared_hooks}개 ≠ 실제 hooks.json {actual_hooks}개",
                 kind="hooks", declared=declared_hooks, actual=actual_hooks)

    for lineno, line in iter_lines_outside_fences(text):
        m = SKILLS_COUNT_RE.search(line)
        if not m or is_fp_claim(line):
            continue
        declared_skills = int(m.group(1))
        actual_skills = _actual_skill_count(plugin_dir)
        if declared_skills != actual_skills:
            emit(facts, "declared-vs-actual surface", "README.md", lineno,
                 line.strip(), kind="skills", declared=declared_skills, actual=actual_skills)
        break  # 첫 언급만 (문서 전체에서 반복 선언은 같은 사실의 중복이라 1건으로 충분)


# ---------------------------------------------------------------------------
# Class 8: category absence — 유일하게 규범을 전제하는 클래스. 조건 미충족이면 아무것도
# emit하지 않는다 ("해당 없음"도 사실이 아니다 — facts는 관측된 것만 담는다).
# ---------------------------------------------------------------------------

KILL_SWITCH_RE = re.compile(r"DEVBREW_DISABLE_|DEVBREW_SKIP_HOOKS|[Kk]ill switch|kill\s*switch")
PRINCIPLES_HEADING_RE = re.compile(
    r"^##\s*(?:Principles Instantiated|인스턴스화한\s*원칙)\s*$", re.MULTILINE)


def _semver_at_least_1_0_0(version: str) -> bool:
    m = re.match(r"^(\d+)\.(\d+)\.(\d+)", version or "")
    if not m:
        return False
    major, minor, patch = (int(x) for x in m.groups())
    return (major, minor, patch) >= (1, 0, 0)


def scan_category_absence(plugin_dir: Path, facts):
    """4개 조건부 게이트. 각 사실은 `norm` extra 필드로 어떤 규범이 부재한지 표시한다."""
    _, data = _load_plugin_json(plugin_dir)
    version = (data or {}).get("version", "")

    # (1) CHANGELOG.md ← plugin.json version >= 1.0.0일 때만 규범이 적용된다.
    if _semver_at_least_1_0_0(version) and not (plugin_dir / "CHANGELOG.md").is_file():
        emit(facts, "category absence", ".", 0,
             f"plugin.json version {version} ≥ 1.0.0인데 CHANGELOG.md 없음",
             norm="CHANGELOG.md")

    # (2) cost_class ← skill 컴포넌트가 있을 때만. 없으면 순회 자체가 비어 자연히 게이팅된다.
    skills_dir = plugin_dir / "skills"
    if skills_dir.is_dir():
        for skill_dir in sorted(d for d in skills_dir.iterdir() if d.is_dir()):
            skill_md = skill_dir / "SKILL.md"
            if not skill_md.is_file():
                continue
            text = skill_md.read_text(encoding="utf-8", errors="replace")
            fm = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
            block = fm.group(1) if fm else ""
            if not re.search(r"^cost_class:", block, re.MULTILINE):
                emit(facts, "category absence", str(skill_md.relative_to(plugin_dir)), 1,
                     f"skill '{skill_dir.name}'에 cost_class 선언 없음", norm="cost_class")

    # (3) kill switch ← hook이 있을 때만.
    hook_count = _actual_hook_count(plugin_dir)
    if hook_count > 0:
        readme = plugin_dir / "README.md"
        readme_text = readme.read_text(encoding="utf-8", errors="replace") if readme.is_file() else ""
        if not KILL_SWITCH_RE.search(readme_text):
            emit(facts, "category absence", "README.md", 0,
                 "hook이 있는데 kill switch(DEVBREW_DISABLE_*/DEVBREW_SKIP_HOOKS) 미문서화",
                 norm="kill switch")

    # (4) Principles Instantiated ← README가 있을 때만.
    readme = plugin_dir / "README.md"
    if readme.is_file():
        readme_text = readme.read_text(encoding="utf-8", errors="replace")
        if not PRINCIPLES_HEADING_RE.search(readme_text):
            emit(facts, "category absence", "README.md", 0,
                 "README는 있는데 Principles Instantiated(또는 '인스턴스화한 원칙') 섹션 없음",
                 norm="Principles Instantiated")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("plugin_dir", type=Path)
    ap.add_argument("--repo-root", type=Path, default=None)
    args = ap.parse_args()
    plugin_dir = args.plugin_dir
    if not plugin_dir.is_dir():
        print(f"[check-staleness] plugin dir not found: {plugin_dir}", file=sys.stderr)
        return 1
    repo_root = args.repo_root or _find_git_root(plugin_dir)
    facts: list = []
    scan_dangling_doc_claims(plugin_dir, repo_root, facts)   # Class 1
    scan_frontmatter_truncation(plugin_dir, facts)           # Class 2
    scan_version_incoherence(plugin_dir, facts)              # Class 3
    scan_draft_residue(plugin_dir, facts)                    # Class 4
    scan_dangling_refs(plugin_dir, facts)                    # Class 5
    scan_description_drift(plugin_dir, repo_root, facts)     # Class 6
    scan_declared_surface(plugin_dir, facts)                 # Class 7
    scan_category_absence(plugin_dir, facts)                 # Class 8
    facts.sort(key=lambda f: (f["class"], f["file"], f["line"]))  # 결정론
    print(json.dumps({"facts": facts}, ensure_ascii=False, indent=2))
    return 0


def _find_git_root(start: Path) -> Path:
    import subprocess
    r = subprocess.run(["git", "-C", str(start), "rev-parse", "--show-toplevel"],
                       capture_output=True, text=True)
    return Path(r.stdout.strip()) if r.returncode == 0 else start.parent


if __name__ == "__main__":
    sys.exit(main())
