#!/usr/bin/env python3
"""플러그인 계약 테스트 — AC16① · AC25–AC27 · AC32 · AC33 · AC35 · AC39 · AC43 · AC51.

Run:
    python3 -m unittest plugins/agent-transparency/tests/test_plugin_contract.py
"""
from __future__ import annotations

import json
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
PLUGIN_DIR = REPO_ROOT / "plugins" / "agent-transparency"


def read(rel: str) -> str:
    return (PLUGIN_DIR / rel).read_text(encoding="utf-8")


class TestManifest(unittest.TestCase):
    """AC26 — plugin.json 에 name · description · version 이 있다."""

    def setUp(self) -> None:
        self.manifest = json.loads(read(".claude-plugin/plugin.json"))

    def test_required_keys_present(self) -> None:
        for key in ("name", "description", "version"):
            self.assertIn(key, self.manifest)
            self.assertTrue(str(self.manifest[key]).strip(), key)

    def test_name_matches_directory(self) -> None:
        self.assertEqual(self.manifest["name"], "agent-transparency")

    def test_version_is_semver(self) -> None:
        parts = str(self.manifest["version"]).split(".")
        self.assertEqual(len(parts), 3)
        for part in parts:
            self.assertTrue(part.isdigit(), self.manifest["version"])

    def test_description_matches_output_style(self) -> None:
        """AC26 — plugin.json 의 description 이 output style frontmatter 와 같은 문구.

        output style 의 description 은 YAML 접힘(두 줄)이라 편다 — 이어지는 줄은
        들여쓰기로만 식별한다(다음 키는 열 0에서 시작한다).
        """
        body = read("output-styles/agent-transparency.md").split("---", 2)[1]
        head, tail = body.split("description:", 1)[1].split("\n", 1)
        folded = [head.strip()]
        for line in tail.splitlines():
            if not line.startswith("  "):
                break
            folded.append(line.strip())
        self.assertEqual(self.manifest["description"], " ".join(folded))


class TestMarketplaceEntry(unittest.TestCase):
    """D12 — marketplace 에 등록되지 않으면 설치가 안 된다."""

    def test_entry_exists_and_points_at_plugin(self) -> None:
        market = json.loads(
            (REPO_ROOT / ".claude-plugin" / "marketplace.json").read_text(encoding="utf-8")
        )
        hits = [p for p in market["plugins"] if p.get("name") == "agent-transparency"]
        self.assertEqual(len(hits), 1)
        self.assertEqual(hits[0]["source"], "./plugins/agent-transparency")


class TestGitignore(unittest.TestCase):
    """§8 — tests/out/ 은 커밋되지 않는다(러너 산출물에 실제 트랜스크립트 사본이 있다)."""

    def test_out_dir_ignored(self) -> None:
        self.assertIn("tests/out/", read(".gitignore"))


if __name__ == "__main__":
    unittest.main()
