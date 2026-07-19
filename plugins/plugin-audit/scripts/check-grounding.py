#!/usr/bin/env python3
"""A grounding — 인용 실재성만 결정론 검증 (semantic entailment는 refuter Gate A 몫, C16)."""
import argparse, json, re, sys
from pathlib import Path

WS = re.compile(r"\s+")


def _norm(s):
    return WS.sub(" ", s).strip()


def ground_finding(f, repo_root):
    f.setdefault("degraded_events", [])
    ev = (f.get("evidence") or [{}])[0]
    quote = _norm(ev.get("quote", ""))
    path = Path(repo_root) / ev.get("file", "")
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (FileNotFoundError, OSError, UnicodeDecodeError):
        f["grounding_verified"] = None
        f["degraded_events"].append({"id": f.get("id"), "kind": "citation_unreadable", "file": ev.get("file")})
        return f
    norm_lines = [_norm(l) for l in lines]
    hit = next((i for i, l in enumerate(norm_lines, 1) if quote and quote in l), None)
    if hit is None:
        f["grounding_verified"] = False
        f["status"] = "discarded"
        f["degraded_events"].append({"id": f.get("id"), "kind": "citation_absent", "file": ev.get("file")})
        return f
    cited = ev.get("line", hit)
    if abs(hit - cited) > 3:
        ev["line"] = hit
        f["degraded_events"].append({"id": f.get("id"), "kind": "line_drift", "from": cited, "to": hit})
    f["grounding_verified"] = True
    return f


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("audit_data")
    ap.add_argument("--repo-root", default=".")
    a = ap.parse_args(argv)
    data = json.loads(Path(a.audit_data).read_text(encoding="utf-8"))
    for f in data.get("findings", []):
        if f.get("status") in ("reported", None):
            ground_finding(f, Path(a.repo_root))
    Path(a.audit_data).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
