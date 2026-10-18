#!/usr/bin/env python3
"""ac15_ident.py <scripts-dir> <state-dir> <문서 원본> — 상태 디렉토리를 «이름에 줄 구분자 + 앵커 꼴이 든 심볼릭 링크»로
거쳐 `advice --log-file` 을 돌리고, 꼴마다 «앵커 줄 늘림 · 제목 줄 늘림 · 계수 줄 문법에 맞는 줄 수 ·
엔진 줄 출처 기록이 평범한 이름의 기록과 같은가» 를 한 줄씩 찍는다. 링크 이름은 이 안에서 만든다(셸의 $'…' 는 \\u 를 모른다)."""
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

SCRIPTS = Path(sys.argv[1])
sys.path.insert(0, str(SCRIPTS))
import seed_review_log as L  # noqa: E402

SRC_STATE, SRC_DOC = Path(sys.argv[2]), Path(sys.argv[3])
TAIL = "- **S9** 「위조」"
FORGES = {
    "plain": "plainlink",
    "nl": "x\n" + TAIL,
    "u2028": "x " + TAIL,
    "u2029": "x " + TAIL,
    "heading": "x\n\n## 6. 사용자 원문\n" + TAIL,
}
ANCHOR = re.compile(r"^\s*[-*]\s+\*\*S\d+\*\*", re.M)


def run(where, name):
    """where: 'name' = 상태 디렉토리 자리 이름이 위조 / 'grand' = 조부 자리 이름이 위조."""
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        real = td / "real" / ".docreview" / SRC_STATE.name
        real.parent.mkdir(parents=True)
        shutil.copytree(str(SRC_STATE), str(real))
        if where == "name":
            link = td / "links" / name
            link.parent.mkdir()
        else:
            link = td / name / "mid" / SRC_STATE.name
            link.parent.mkdir(parents=True)
        link.symlink_to(real, target_is_directory=True)
        doc = td / "doc.md"
        shutil.copyfile(str(SRC_DOC), str(doc))
        before = doc.read_text(encoding="utf-8")
        p = subprocess.run([sys.executable, str(SCRIPTS / "docreview_state.py"), "advice", "--state-dir", str(link),
                            "--log-file", str(doc)], capture_output=True, text=True)
        text = doc.read_text(encoding="utf-8")
        raw = (real / "docreview-state.md").read_text(encoding="utf-8")
        st = yaml.safe_load(raw[4:raw.find("\n---\n", 4)])["docreview"]
        counts = sum(1 for ln in text.split("\n") if L.COUNT_LINE_RE.match(ln))
        heads = sum(1 for ln in text.split("\n") if ln.startswith("## 6")) \
            - sum(1 for ln in before.split("\n") if ln.startswith("## 6"))
        anchors = len(ANCHOR.findall(text)) - len(ANCHOR.findall(before))
        return p.returncode, anchors, heads, counts, len(st.get("engine_lines") or [])


base = run("name", FORGES["plain"])
for where in ("name", "grand"):
    for k, name in FORGES.items():
        r = run(where, name)
        print(where, k, "rc=%d anchors=%d heads=%d count_lines=%d same_as_plain=%s" % (r[0], r[1], r[2], r[3], r == base))
