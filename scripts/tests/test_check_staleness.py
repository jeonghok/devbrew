import json, os, subprocess, sys, tempfile, unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts" / "check-staleness.py"


def run_sweep(plugin_dir, repo_root=None, env=None):
    cmd = [sys.executable, str(SCRIPT), str(plugin_dir)]
    if repo_root is not None:
        cmd += ["--repo-root", str(repo_root)]
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=str(REPO), env=env)
    assert r.returncode == 0, r.stderr
    return json.loads(r.stdout)["facts"]


def classes(facts):
    return sorted({f["class"] for f in facts})


class TestDanglingDocClaim(unittest.TestCase):
    def _plugin(self, tmp, readme):
        p = Path(tmp) / "myplugin"; p.mkdir()
        (p / "plugin.json").write_text('{"name":"myplugin","version":"1.0.0"}\n', encoding="utf-8")
        (p / "README.md").write_text(readme, encoding="utf-8")
        (p / "CHANGELOG.md").write_text("## [1.0.0] — 2026-01-01\n", encoding="utf-8")
        return p

    def test_dangling_backtick_path_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, "Run `scripts/nonexistent.sh` to start.\n")
            facts = run_sweep(p)
            self.assertIn("dangling doc-claim", classes(facts))
            self.assertTrue(any("nonexistent.sh" in f["quote"] for f in facts))

    def test_existing_path_not_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, "See `scripts/real.sh` for config.\n")
            (p / "scripts").mkdir()
            (p / "scripts" / "real.sh").write_text("#!/bin/sh\n", encoding="utf-8")
            facts = run_sweep(p)
            self.assertNotIn("dangling doc-claim", classes(facts),
                             "실재 경로를 dangling으로 오탐")

    def test_bare_root_script_flagged(self):
        # reviewer Important 2 (false-negative): 슬래시 없어도 알려진 확장자를 가진 바닥 파일은
        # 여전히 주장이다. README가 광고하는 root-level `setup.sh`가 부재하면 그건 정확히
        # sweep이 잡아야 할 flat-absence다 — 무조건 슬래시를 요구하면 통째로 흘린다.
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, "Run `setup.sh` to bootstrap.\n")
            facts = run_sweep(p)
            self.assertIn("dangling doc-claim", classes(facts),
                          "root-level 스크립트 주장(setup.sh 부재)을 흘림")
            self.assertTrue(any("setup.sh" in f["quote"] for f in facts))

    def test_bare_word_no_extension_not_flagged(self):
        # 반대 방향: 슬래시도 알려진 확장자도 없는 바닥 토큰(`helper`)은 경로 주장이 아니다.
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, "The `helper` handles retries.\n")
            facts = run_sweep(p)
            self.assertNotIn("dangling doc-claim", classes(facts),
                             "확장자 없는 산문 토큰을 경로 주장으로 오탐")

    def test_bare_name_exists_elsewhere_not_flagged(self):
        # reviewer Important 2 완성: 바닥 이름은 "이 파일이 존재한다"류 주장이라 트리 어디든 그
        # basename이 있으면 satisfied. `plugin.json`은 `.claude-plugin/plugin.json`에 실존하므로
        # dangling이 아니다 — 실존 파일을 dangling으로 라벨링하면 노이즈가 아니라 거짓 사실.
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "myplugin"; (p / ".claude-plugin").mkdir(parents=True)
            (p / ".claude-plugin" / "plugin.json").write_text(
                '{"name":"myplugin","version":"1.0.0"}\n', encoding="utf-8")
            (p / "README.md").write_text("설정은 `plugin.json`에서 본다.\n", encoding="utf-8")
            (p / "CHANGELOG.md").write_text("## [1.0.0] — 2026-01-01\n", encoding="utf-8")
            facts = run_sweep(p)
            self.assertNotIn("dangling doc-claim", classes(facts),
                             "트리에 실존하는 basename(plugin.json)을 dangling으로 거짓 라벨링")

    def test_branch_name_pattern_not_flagged(self):
        # 실측 FP: branch-strategy 템플릿의 `feature/foo-bar` 등은 브랜치명 예시지 파일 경로가
        # 아니다 (devbrew 자신의 git-workflow 컨벤션 어휘 feature/fix/hotfix/release).
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, "예: `feature/user-auth`, `fix/login-redirect`\n")
            facts = run_sweep(p)
            self.assertNotIn("dangling doc-claim", classes(facts),
                             "브랜치명 예시를 파일 경로 주장으로 오탐")

    def test_shell_command_not_flagged(self):
        # 실측 FP: 공백 포함 백틱 인용은 셸 커맨드/산문 조각이지 단일 경로 토큰이 아니다.
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, "Then run `git merge origin/main` to sync.\n")
            facts = run_sweep(p)
            self.assertNotIn("dangling doc-claim", classes(facts),
                             "공백 포함 셸 커맨드를 경로 주장으로 오탐")

    def test_directory_only_mention_not_flagged(self):
        # 실측 FP: `src/`처럼 특정 파일을 지목하지 않는 디렉터리 컨벤션 언급.
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, "타깃 프로젝트 구조 예시: `src/`, `docs/git-workflow/`\n")
            facts = run_sweep(p)
            self.assertNotIn("dangling doc-claim", classes(facts),
                             "디렉터리 전용 언급(trailing '/')을 파일 경로 주장으로 오탐")

    def test_line_number_suffix_resolves_to_real_file(self):
        # 실측 FP: `hooks/post-tool-use.py:19`처럼 줄-번호 인용 접미사가 붙으면 실존 파일도
        # 문자 그대로는 존재하지 않아 오탐한다 — 접미사를 벗겨야 한다.
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, "`hooks/real.py:19`의 패턴 참고.\n")
            (p / "hooks").mkdir()
            (p / "hooks" / "real.py").write_text("PATTERN = 1\n", encoding="utf-8")
            facts = run_sweep(p)
            self.assertNotIn("dangling doc-claim", classes(facts),
                             "줄-번호 인용 접미사 때문에 실존 파일을 dangling으로 오탐")

    def test_path_in_code_fence_not_flagged(self):
        # 펜스 내부에 백틱-인용 경로를 넣어야 mutation이 실제로 이빨을 문다:
        # 백틱이 없으면 BACKTICK_PATH_RE 자체가 매치하지 않아 펜스 스킵 여부와 무관하게 통과한다.
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, "Example:\n```\nRun `scripts/example.sh` to install.\n```\n")
            facts = run_sweep(p)
            self.assertFalse(any("example.sh" in f.get("quote", "") for f in facts),
                             "코드 펜스 내부 경로를 주장으로 오탐 (mention vs use)")

    def test_placeholder_not_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, "Create `<your-plugin>/scripts/x.sh`.\n")
            facts = run_sweep(p)
            self.assertFalse(any("x.sh" in f.get("quote", "") for f in facts),
                             "플레이스홀더 경로를 주장으로 오탐")

    def test_shell_var_placeholder_not_flagged(self):
        # 실측 FP: `${CLAUDE_PLUGIN_ROOT}/templates/...`는 런타임 치환 변수지 리터럴 경로가 아니다.
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, "설치 경로: `${CLAUDE_PLUGIN_ROOT}/templates/foo.md`\n")
            facts = run_sweep(p)
            self.assertFalse(any("foo.md" in f.get("quote", "") for f in facts),
                             "${VAR} 런타임 치환 경로를 리터럴 주장으로 오탐")

    def test_generation_target_md_not_flagged(self):
        # reviewer Important 1: 생성 동사가 있는 줄에서 생성물 확장자(.md) 경로는 이 플러그인이
        # 타깃 저장소에 *만들어낼* 산출물이지 자신이 담아야 할 파일이 아니다 — 부재가 정상.
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, "헌장 발행: `docs/project/charter.md`\n")
            facts = run_sweep(p)
            self.assertNotIn("dangling doc-claim", classes(facts),
                             "생성 대상 산출물(.md)을 dangling으로 오탐")

    def test_dangling_script_on_generate_line_still_flagged(self):
        # reviewer Important 1의 반대 방향(over-suppression 방지): 같은 "generate" 줄이라도
        # 스크립트(.sh)는 생성물이 아니라 생성기다 — 부재는 여전히 진짜 사실. 억제하면 안 된다.
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, "run `scripts/gen.sh` to generate output.\n")
            facts = run_sweep(p)
            self.assertIn("dangling doc-claim", classes(facts),
                          "생성기 스크립트(.sh) 주장을 생성물로 오인해 과잉 억제")
            self.assertTrue(any("gen.sh" in f["quote"] for f in facts))

    def test_repo_root_relative_path_resolves(self):
        # devbrew 자체 문서 컨벤션: repo-root 상대 마크다운 링크 (예: docs/philosophy/...).
        # plugin_dir 기준으로는 없어도 repo_root 기준으로 존재하면 dangling이 아니다.
        with tempfile.TemporaryDirectory() as d:
            repo = Path(d) / "repo"
            (repo / "docs" / "philosophy").mkdir(parents=True)
            (repo / "docs" / "philosophy" / "harness.md").write_text("# harness\n", encoding="utf-8")
            p = repo / "plugins" / "myplugin"; p.mkdir(parents=True)
            (p / "plugin.json").write_text('{"name":"myplugin","version":"1.0.0"}\n', encoding="utf-8")
            (p / "README.md").write_text(
                "See `docs/philosophy/harness.md` for background.\n", encoding="utf-8")
            (p / "CHANGELOG.md").write_text("## [1.0.0] — 2026-01-01\n", encoding="utf-8")
            facts = run_sweep(p, repo_root=repo)
            self.assertNotIn("dangling doc-claim", classes(facts),
                             "repo-root 상대 경로를 plugin-dir 상대로만 확인해 오탐")


class TestFrontmatterTruncation(unittest.TestCase):
    def test_unquoted_hash_truncates_tools(self):
        # Law 2 위험: tools: 값이 ' #'로 조용히 잘린다
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "myplugin"; (p / ".claude" / "agents").mkdir(parents=True)
            (p / "plugin.json").write_text('{"name":"m","version":"1.0.0"}\n', encoding="utf-8")
            (p / ".claude" / "agents" / "a.md").write_text(
                "---\nname: a\ntools: Read, Grep # comment\n---\nbody\n", encoding="utf-8")
            facts = run_sweep(p)
            self.assertIn("frontmatter silent-truncation", classes(facts))

    def test_clean_frontmatter_ok(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "myplugin"; (p / ".claude" / "agents").mkdir(parents=True)
            (p / "plugin.json").write_text('{"name":"m","version":"1.0.0"}\n', encoding="utf-8")
            (p / ".claude" / "agents" / "a.md").write_text(
                "---\nname: a\ntools: Read, Grep\n---\nbody\n", encoding="utf-8")
            facts = run_sweep(p)
            self.assertNotIn("frontmatter silent-truncation", classes(facts))


class TestVersionIncoherence(unittest.TestCase):
    def test_changelog_ahead_of_plugin_json(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "myplugin"; p.mkdir()
            (p / "plugin.json").write_text('{"name":"m","version":"1.0.0"}\n', encoding="utf-8")
            (p / "CHANGELOG.md").write_text("## [1.2.0] — 2026-01-01\n", encoding="utf-8")
            facts = run_sweep(p)
            self.assertIn("version incoherence", classes(facts))

    def test_matching_versions_ok(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "myplugin"; p.mkdir()
            (p / "plugin.json").write_text('{"name":"m","version":"1.2.0"}\n', encoding="utf-8")
            (p / "CHANGELOG.md").write_text("## [1.2.0] — 2026-01-01\n", encoding="utf-8")
            facts = run_sweep(p)
            self.assertNotIn("version incoherence", classes(facts))

    def test_nested_claude_plugin_json_used(self):
        # 실제 devbrew 컨벤션: plugin.json은 plugin_dir 루트가 아니라 .claude-plugin/ 하위에 산다
        # (project-init·quality-gates·spec-distill 전부 이 컨벤션). 이 위치를 못 보면 실타깃에서
        # 모든 plugin.json 의존 클래스가 조용히 no-op된다 — 그 자체가 회귀 위험.
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "myplugin"; (p / ".claude-plugin").mkdir(parents=True)
            (p / ".claude-plugin" / "plugin.json").write_text(
                '{"name":"m","version":"1.0.0"}\n', encoding="utf-8")
            (p / "CHANGELOG.md").write_text("## [1.2.0] — 2026-01-01\n", encoding="utf-8")
            facts = run_sweep(p)
            self.assertIn("version incoherence", classes(facts),
                          ".claude-plugin/plugin.json 위치를 못 읽어 클래스가 조용히 skip됨")


class TestDraftResidue(unittest.TestCase):
    def _plugin(self, tmp):
        p = Path(tmp) / "myplugin"; p.mkdir()
        (p / "plugin.json").write_text('{"name":"m","version":"1.0.0"}\n', encoding="utf-8")
        return p

    def test_todo_in_readme_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d)
            (p / "README.md").write_text("Ship this feature.\nTODO: write docs.\n", encoding="utf-8")
            facts = run_sweep(p)
            self.assertIn("draft residue", classes(facts))

    def test_clean_readme_no_markers(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d)
            (p / "README.md").write_text("Ship this feature. Fully documented.\n", encoding="utf-8")
            facts = run_sweep(p)
            self.assertNotIn("draft residue", classes(facts))

    def test_marker_in_code_fence_not_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d)
            (p / "README.md").write_text("Example:\n```\n# TODO: fill in later\n```\n", encoding="utf-8")
            facts = run_sweep(p)
            self.assertNotIn("draft residue", classes(facts),
                             "코드 펜스 내부 TODO를 초안 잔재로 오탐")


class TestDanglingRefs(unittest.TestCase):
    """dangling command/plugin ref — 두 하위 패턴:
    (a) 자기 플러그인 `/command` 자기-주장이 commands/<name>.md로 뒷받침 안 됨
        (단, 같은 줄에 다른 플러그인 이름의 bold 귀속(`**other**:`)이 있으면 그건 외부 참조 언급이지
        자기 커맨드 주장이 아니므로 스킵 — 실측 project-init README FP, ledger 스타일).
    (b) `other-plugin:component` cross-plugin 참조가 (레지스트리 부재 또는 미설치) AND
        README Prerequisites 미선언이면 flag. 레지스트리 부재는 그 신호를 skip하고
        (prerequisites 단독 판단) `registry: "absent"`를 사실에 남긴다. 자기 이름 참조는 스킵.
    """

    def _plugin(self, tmp, name="myplugin", readme=""):
        p = Path(tmp) / name; p.mkdir()
        (p / "plugin.json").write_text(json.dumps({"name": name, "version": "1.0.0"}) + "\n",
                                        encoding="utf-8")
        (p / "README.md").write_text(readme, encoding="utf-8")
        return p

    def _no_registry_env(self, tmp):
        env = dict(os.environ)
        env["DEVBREW_STALENESS_REGISTRY"] = str(Path(tmp) / "no-such-registry.json")
        return env

    def test_dangling_self_command_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, readme="Run `/does-not-exist` to start.\n")
            facts = run_sweep(p, env=self._no_registry_env(d))
            self.assertIn("dangling command/plugin ref", classes(facts))

    def test_existing_self_command_not_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, readme="Run `/real-cmd` to start.\n")
            (p / "commands").mkdir()
            (p / "commands" / "real-cmd.md").write_text("---\nname: real-cmd\n---\nbody\n", encoding="utf-8")
            facts = run_sweep(p, env=self._no_registry_env(d))
            self.assertNotIn("dangling command/plugin ref", classes(facts))

    def test_externally_attributed_command_not_flagged(self):
        # 실측 project-init README 패턴: "- **commit-commands**: `/commit`..." — 이건 다른
        # 플러그인의 커맨드를 언급하는 통합 문서지 이 플러그인이 /commit을 소유한다는 주장이 아니다.
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, readme="- **commit-commands**: `/commit`과 `/commit-push-pr`이 동작.\n")
            facts = run_sweep(p, env=self._no_registry_env(d))
            self.assertNotIn("dangling command/plugin ref", classes(facts),
                             "다른 플러그인 귀속 커맨드 언급을 자기-커맨드 주장으로 오탐")

    def test_trailing_paren_attributed_command_not_flagged(self):
        # 실측 project-init commands/project-init.md 패턴: bold 선행이 아니라 괄호 후행 귀속.
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, readme="`/commit` 또는 `/commit-push-pr` (commit-commands 플러그인) 사용.\n")
            facts = run_sweep(p, env=self._no_registry_env(d))
            self.assertNotIn("dangling command/plugin ref", classes(facts),
                             "후행 괄호 귀속(다른 플러그인) 커맨드 언급을 자기-커맨드 주장으로 오탐")

    def test_command_in_code_fence_not_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, readme="Example:\n```\nRun `/fenced-cmd` now.\n```\n")
            facts = run_sweep(p, env=self._no_registry_env(d))
            self.assertNotIn("dangling command/plugin ref", classes(facts))

    def test_cross_plugin_ref_no_registry_no_prereq_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, readme="See `other-plugin:some-agent` for details.\n")
            facts = run_sweep(p, env=self._no_registry_env(d))
            self.assertIn("dangling command/plugin ref", classes(facts))
            hit = [f for f in facts if f["class"] == "dangling command/plugin ref"
                   and "other-plugin" in f["quote"]]
            self.assertTrue(hit)
            self.assertEqual(hit[0].get("registry"), "absent")

    def test_cross_plugin_ref_with_prerequisites_not_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, readme=(
                "See `other-plugin:some-agent` for details.\n\n"
                "## Prerequisites\n\n- **other-plugin** (external, optional)\n"))
            facts = run_sweep(p, env=self._no_registry_env(d))
            self.assertNotIn("dangling command/plugin ref", classes(facts),
                             "prerequisites 선언된 cross-plugin ref를 dangling으로 오탐")

    def test_cross_plugin_ref_installed_in_registry_not_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, readme="See `other-plugin:some-agent` for details.\n")
            registry = Path(d) / "registry.json"
            registry.write_text(json.dumps(
                {"version": 2, "plugins": {"other-plugin@some-marketplace": {"scope": "user"}}}),
                encoding="utf-8")
            env = dict(os.environ)
            env["DEVBREW_STALENESS_REGISTRY"] = str(registry)
            facts = run_sweep(p, env=env)
            self.assertNotIn("dangling command/plugin ref", classes(facts),
                             "레지스트리에 실제 설치된 plugin을 dangling으로 오탐")

    def test_self_referential_colon_not_flagged(self):
        # quality-gates README의 실측 패턴: 자기 플러그인 이름:컴포넌트 표 (self-reference).
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, name="myplugin",
                              readme="| `myplugin:some-component` | ... |\n")
            facts = run_sweep(p, env=self._no_registry_env(d))
            self.assertNotIn("dangling command/plugin ref", classes(facts),
                             "자기 플러그인 self-reference를 cross-plugin dangling으로 오탐")


class TestDescriptionDrift(unittest.TestCase):
    def _setup(self, tmp, plugin_desc, marketplace_desc, marketplace_name="myplugin",
               write_marketplace=True):
        repo = Path(tmp) / "repo"
        p = repo / "plugins" / "myplugin"; p.mkdir(parents=True)
        (p / "plugin.json").write_text(
            json.dumps({"name": "myplugin", "version": "1.0.0", "description": plugin_desc}) + "\n",
            encoding="utf-8")
        if write_marketplace:
            mp = repo / ".claude-plugin"; mp.mkdir()
            (mp / "marketplace.json").write_text(json.dumps({
                "plugins": [{"name": marketplace_name, "description": marketplace_desc,
                             "source": "./plugins/myplugin"}]
            }), encoding="utf-8")
        return p, repo

    def test_mismatched_description_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p, repo = self._setup(d, "Does X.", "Does Y (drifted).")
            facts = run_sweep(p, repo_root=repo)
            self.assertIn("description drift", classes(facts))

    def test_matching_description_not_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p, repo = self._setup(d, "Does X.", "Does X.")
            facts = run_sweep(p, repo_root=repo)
            self.assertNotIn("description drift", classes(facts))

    def test_marketplace_absent_skipped(self):
        with tempfile.TemporaryDirectory() as d:
            p, repo = self._setup(d, "Does X.", "Does Y.", write_marketplace=False)
            facts = run_sweep(p, repo_root=repo)
            self.assertNotIn("description drift", classes(facts),
                             "marketplace.json 부재는 skip이지 사실이 아니다")

    def test_no_matching_entry_skipped(self):
        with tempfile.TemporaryDirectory() as d:
            p, repo = self._setup(d, "Does X.", "Does Y.", marketplace_name="other-plugin")
            facts = run_sweep(p, repo_root=repo)
            self.assertNotIn("description drift", classes(facts),
                             "이름이 다른 항목과 비교해 오탐")


class TestDeclaredSurface(unittest.TestCase):
    """README의 'Hooks Installed'/'N skills' 류 선언 개수 ↔ 디스크 실제 개수.
    실측 컨벤션(project-init: '## 설치된 Hook')은 영어 표준 헤딩과 나란히 지원한다."""

    def _plugin(self, tmp):
        p = Path(tmp) / "myplugin"; p.mkdir()
        (p / "plugin.json").write_text('{"name":"m","version":"1.0.0"}\n', encoding="utf-8")
        return p

    def _hooks_json(self, n):
        return json.dumps({"hooks": {"PostToolUse": [{"matcher": "Bash", "hooks": [{}]}] * n}})

    def test_hooks_count_mismatch_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d)
            (p / "README.md").write_text(
                "## Hooks Installed\n\n- **HookA**: does a thing\n- **HookB**: does another\n",
                encoding="utf-8")
            (p / "hooks").mkdir()
            (p / "hooks" / "hooks.json").write_text(self._hooks_json(1), encoding="utf-8")
            facts = run_sweep(p)
            self.assertIn("declared-vs-actual surface", classes(facts))

    def test_hooks_count_match_not_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d)
            (p / "README.md").write_text(
                "## 설치된 Hook\n\n- **HookA**: does a thing\n- **HookB**: does another\n",
                encoding="utf-8")
            (p / "hooks").mkdir()
            (p / "hooks" / "hooks.json").write_text(self._hooks_json(2), encoding="utf-8")
            facts = run_sweep(p)
            self.assertNotIn("declared-vs-actual surface", classes(facts))

    def test_no_hooks_claim_no_fact(self):
        # hooks.json은 있지만 README에 'Hooks Installed'류 선언 섹션 자체가 없음 — 비교 대상이
        # 없으니 스킵 (이건 category absence의 몫이지 이 클래스가 아니다).
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d)
            (p / "README.md").write_text("Just a plain readme.\n", encoding="utf-8")
            (p / "hooks").mkdir()
            (p / "hooks" / "hooks.json").write_text(self._hooks_json(1), encoding="utf-8")
            facts = run_sweep(p)
            self.assertNotIn("declared-vs-actual surface", classes(facts))

    def test_skills_count_mismatch_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d)
            (p / "README.md").write_text("This plugin ships 3 skills for automation.\n",
                                          encoding="utf-8")
            (p / "skills" / "only-one").mkdir(parents=True)
            (p / "skills" / "only-one" / "SKILL.md").write_text("# only-one\n", encoding="utf-8")
            facts = run_sweep(p)
            self.assertIn("declared-vs-actual surface", classes(facts))

    def test_skills_count_match_not_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d)
            (p / "README.md").write_text("This plugin ships 1 skill for automation.\n",
                                          encoding="utf-8")
            (p / "skills" / "only-one").mkdir(parents=True)
            (p / "skills" / "only-one" / "SKILL.md").write_text("# only-one\n", encoding="utf-8")
            facts = run_sweep(p)
            self.assertNotIn("declared-vs-actual surface", classes(facts))


class TestCategoryAbsence(unittest.TestCase):
    """category absence — 유일하게 규범을 전제하는 클래스. 조건이 안 걸리면 아무것도 emit
    안 한다 (해당 없음도 사실이 아니다). 4개 조건부 게이트: CHANGELOG(version>=1.0.0일 때만),
    cost_class(skill 있을 때만), kill switch(hook 있을 때만), Principles Instantiated
    (README 있을 때만)."""

    def _plugin(self, tmp, version="1.0.0"):
        p = Path(tmp) / "myplugin"; p.mkdir()
        (p / "plugin.json").write_text(
            json.dumps({"name": "myplugin", "version": version}) + "\n", encoding="utf-8")
        return p

    # --- CHANGELOG ---
    def test_changelog_absent_v1_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, version="1.0.0")
            facts = run_sweep(p)
            hits = [f for f in facts if f["class"] == "category absence" and f.get("norm") == "CHANGELOG.md"]
            self.assertTrue(hits, "1.0.0+ 플러그인의 CHANGELOG 부재를 못 잡음")

    def test_changelog_absent_v0_not_flagged(self):
        # 핵심 가드: 0.9.0 플러그인은 CHANGELOG 부재를 규범 위반으로 요구하지 않는다.
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, version="0.9.0")
            facts = run_sweep(p)
            hits = [f for f in facts if f["class"] == "category absence" and f.get("norm") == "CHANGELOG.md"]
            self.assertFalse(hits, "0.9.0 플러그인에 CHANGELOG 부재를 사실로 위장 배달함 (조건부 게이팅 실패)")

    def test_changelog_present_not_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, version="1.0.0")
            (p / "CHANGELOG.md").write_text("## [1.0.0] — 2026-01-01\n", encoding="utf-8")
            facts = run_sweep(p)
            hits = [f for f in facts if f["class"] == "category absence" and f.get("norm") == "CHANGELOG.md"]
            self.assertFalse(hits)

    # --- cost_class ---
    def test_cost_class_absent_with_skill_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d)
            (p / "skills" / "doing-thing").mkdir(parents=True)
            (p / "skills" / "doing-thing" / "SKILL.md").write_text(
                "---\nname: doing-thing\ndescription: does a thing\n---\nbody\n", encoding="utf-8")
            facts = run_sweep(p)
            hits = [f for f in facts if f["class"] == "category absence" and f.get("norm") == "cost_class"]
            self.assertTrue(hits)

    def test_no_skill_no_cost_class_fact(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d)  # no skills/ dir at all
            facts = run_sweep(p)
            hits = [f for f in facts if f["class"] == "category absence" and f.get("norm") == "cost_class"]
            self.assertFalse(hits, "skill이 없는데 cost_class 부재를 사실로 위장 배달함")

    def test_cost_class_present_not_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d)
            (p / "skills" / "doing-thing").mkdir(parents=True)
            (p / "skills" / "doing-thing" / "SKILL.md").write_text(
                "---\nname: doing-thing\ncost_class: low\n---\nbody\n", encoding="utf-8")
            facts = run_sweep(p)
            hits = [f for f in facts if f["class"] == "category absence" and f.get("norm") == "cost_class"]
            self.assertFalse(hits)

    # --- kill switch ---
    def test_kill_switch_absent_with_hook_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d)
            (p / "hooks").mkdir()
            (p / "hooks" / "hooks.json").write_text(
                json.dumps({"hooks": {"PostToolUse": [{"matcher": "Bash", "hooks": [{}]}]}}),
                encoding="utf-8")
            (p / "README.md").write_text("This plugin has a hook. No env var mentioned.\n",
                                          encoding="utf-8")
            facts = run_sweep(p)
            hits = [f for f in facts if f["class"] == "category absence" and f.get("norm") == "kill switch"]
            self.assertTrue(hits)

    def test_no_hook_no_kill_switch_fact(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d)  # no hooks/ dir
            facts = run_sweep(p)
            hits = [f for f in facts if f["class"] == "category absence" and f.get("norm") == "kill switch"]
            self.assertFalse(hits, "hook이 없는데 kill switch 부재를 사실로 위장 배달함")

    def test_kill_switch_present_not_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d)
            (p / "hooks").mkdir()
            (p / "hooks" / "hooks.json").write_text(
                json.dumps({"hooks": {"PostToolUse": [{"matcher": "Bash", "hooks": [{}]}]}}),
                encoding="utf-8")
            (p / "README.md").write_text(
                "Kill switch: `DEVBREW_DISABLE_MYPLUGIN=1`\n", encoding="utf-8")
            facts = run_sweep(p)
            hits = [f for f in facts if f["class"] == "category absence" and f.get("norm") == "kill switch"]
            self.assertFalse(hits)

    # --- Principles Instantiated ---
    def test_principles_absent_with_readme_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d)
            (p / "README.md").write_text("# myplugin\n\nJust a plain readme.\n", encoding="utf-8")
            facts = run_sweep(p)
            hits = [f for f in facts if f["class"] == "category absence" and f.get("norm") == "Principles Instantiated"]
            self.assertTrue(hits)

    def test_no_readme_no_principles_fact(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d)  # no README.md at all
            facts = run_sweep(p)
            hits = [f for f in facts if f["class"] == "category absence" and f.get("norm") == "Principles Instantiated"]
            self.assertFalse(hits, "README이 없는데 Principles Instantiated 부재를 사실로 위장 배달함")

    def test_principles_present_english_not_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d)
            (p / "README.md").write_text("# myplugin\n\n## Principles Instantiated\n\n- Law 1\n",
                                          encoding="utf-8")
            facts = run_sweep(p)
            hits = [f for f in facts if f["class"] == "category absence" and f.get("norm") == "Principles Instantiated"]
            self.assertFalse(hits)

    def test_principles_present_korean_not_flagged(self):
        # 실측 project-init README 컨벤션: Korean-primary 헤딩.
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d)
            (p / "README.md").write_text("# myplugin\n\n## 인스턴스화한 원칙\n\n- Law 1\n",
                                          encoding="utf-8")
            facts = run_sweep(p)
            hits = [f for f in facts if f["class"] == "category absence" and f.get("norm") == "Principles Instantiated"]
            self.assertFalse(hits)


class TestSweepInvariants(unittest.TestCase):
    def test_deterministic_two_runs(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "myplugin"; p.mkdir()
            (p / "plugin.json").write_text('{"name":"m","version":"1.0.0"}\n', encoding="utf-8")
            (p / "README.md").write_text("Run `scripts/a.sh` and `scripts/b.sh`.\n", encoding="utf-8")
            (p / "CHANGELOG.md").write_text("## [1.0.0] — 2026-01-01\n", encoding="utf-8")
            f1 = json.dumps(run_sweep(p), ensure_ascii=False)
            f2 = json.dumps(run_sweep(p), ensure_ascii=False)
            self.assertEqual(f1, f2, "sweep이 비결정론 (감사자가 실행마다 다른 사실을 받는다)")

    def test_empty_plugin_no_crash_zero_facts(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "empty"; p.mkdir()
            (p / "plugin.json").write_text('{"name":"empty","version":"0.1.0"}\n', encoding="utf-8")
            facts = run_sweep(p)  # 크래시 없이 exit 0
            self.assertIsInstance(facts, list)

    def test_nonexistent_plugin_dir_nonzero_exit(self):
        with tempfile.TemporaryDirectory() as d:
            r = subprocess.run([sys.executable, str(SCRIPT), str(Path(d) / "does-not-exist")],
                               capture_output=True, text=True, cwd=str(REPO))
            self.assertNotEqual(r.returncode, 0)

    def test_non_git_tempdir_no_crash(self):
        # brief의 _find_git_root는 git repo가 아니면 부모 디렉토리로 fallback한다 — crash 금지.
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "myplugin"; p.mkdir()
            (p / "plugin.json").write_text('{"name":"m","version":"1.0.0"}\n', encoding="utf-8")
            (p / "README.md").write_text("See `scripts/missing.sh`.\n", encoding="utf-8")
            facts = run_sweep(p)  # repo_root 미지정 — non-git tempdir에서 _find_git_root 발동
            self.assertIsInstance(facts, list)

    def test_output_shape_is_facts_only_no_verdict_keys(self):
        # §5.4a 핵심 계약: verdict/점수/PASS-FAIL 키가 전혀 없어야 한다.
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "myplugin"; p.mkdir()
            (p / "plugin.json").write_text('{"name":"m","version":"0.1.0"}\n', encoding="utf-8")
            (p / "README.md").write_text("Run `scripts/nonexistent.sh`.\n", encoding="utf-8")
            r = subprocess.run([sys.executable, str(SCRIPT), str(p)],
                               capture_output=True, text=True, cwd=str(REPO))
            self.assertEqual(r.returncode, 0)
            payload = json.loads(r.stdout)
            self.assertEqual(set(payload.keys()), {"facts"})
            forbidden = {"verdict", "score", "pass", "fail", "status"}
            for f in payload["facts"]:
                self.assertFalse(forbidden & set(k.lower() for k in f.keys()),
                                 f"fact에 verdict성 키가 섞임: {f}")


if __name__ == "__main__":
    unittest.main()
