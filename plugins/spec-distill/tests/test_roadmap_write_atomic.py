#!/usr/bin/env python3
# guards: plugins/spec-distill/scripts/roadmap_write.py
"""roadmap_write._atomic — 짧은 쓰기(디스크가 거의 참)를 다 쓴 것으로 바꿔 놓지 않는다. 되돌리기도 같은 길이다.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_roadmap_write_atomic.py
"""
from __future__ import annotations

import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import roadmap_write as rw  # noqa: E402

ORIGINAL = "원래 로드맵 — 지우면 안 되는 글\n" * 50


class ShortWrite(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.path = self.dir / "roadmap.md"
        self.path.write_text(ORIGINAL, encoding="utf-8")
        self._write = os.write

    def tearDown(self):
        rw.os.write = self._write
        shutil.rmtree(str(self.dir))

    def short_disk(self, room: int):
        """앞의 room 바이트만 받고 그 뒤로는 0 을 돌려주는 디스크."""
        left = [room]

        def write(fd, data):
            n = min(len(data), left[0])
            left[0] -= n
            return self._write(fd, bytes(data[:n])) if n else 0
        rw.os.write = write

    def leftovers(self):
        return sorted(p.name for p in self.dir.iterdir() if p.name != "roadmap.md")

    def test_short_write_does_not_replace(self):
        self.short_disk(10)
        with self.assertRaises(OSError):
            rw._atomic(self.path, ("새 글\n" * 100).encode("utf-8"))
        self.assertEqual(self.path.read_text(encoding="utf-8"), ORIGINAL)
        self.assertEqual(self.leftovers(), [])

    def test_partial_writes_that_finish_are_whole(self):
        # 한 번에 다 못 받아도 계속 받으면 끝까지 쓴다
        calls = []

        def write(fd, data):
            n = min(len(data), 7)
            calls.append(n)
            return self._write(fd, bytes(data[:n]))
        rw.os.write = write
        data = ("새 글\n" * 30).encode("utf-8")
        rw._atomic(self.path, data)
        self.assertEqual(self.path.read_bytes(), data)
        self.assertGreater(len(calls), 1)

    def test_rollback_does_not_truncate_on_short_write(self):
        t = rw.Txn()
        t.write(self.path, "바뀐 글\n")
        self.short_disk(10)
        errs = t.rollback()
        rw.os.write = self._write
        self.assertTrue(errs, "짧은 쓰기로 되돌리지 못했는데 오류가 없다")
        self.assertNotEqual(self.path.read_text(encoding="utf-8"), ORIGINAL[:10])
        self.assertEqual(self.path.read_text(encoding="utf-8"), "바뀐 글\n")


if __name__ == "__main__":
    unittest.main()
