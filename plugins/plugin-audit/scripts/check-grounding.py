#!/usr/bin/env python3
"""A grounding — 인용 실재성만 결정론 검증 (semantic entailment는 refuter Gate A 몫, C16)."""
import argparse, json, re, sys
from pathlib import Path

WS = re.compile(r"\s+")


def _norm(s):
    return WS.sub(" ", s).strip()


def ground_finding(f, repo_root):
    # **모든** evidence 인용을 검증한다 (evidence[0]만 보면 evidence[1]의 위조 인용이 통과).
    # 라인별 매칭에 더해 전체파일 정규화 검색을 병행해 **여러 줄에 걸친 인용**이 거짓 폐기되지
    # 않게 한다. 판정: 하나라도 인용 부재면 폐기(가장 강한 신호); 부재는 없고 판독불가만 있으면
    # null-degrade(보수적으로 reported 유지 — 판독불가 ≠ 위조 증명); 전부 실재하면 검증됨.
    f.setdefault("degraded_events", [])
    any_absent = False
    any_unreadable = False
    checked_any = False   # 실제로 검증한(비어있지 않은) 인용이 하나라도 있었는가
    root = Path(repo_root).resolve()
    for ev in (f.get("evidence") or []):
        # codex findings는 schema 미검증으로 병합되므로 quote/file이 str이 아닐 수 있다(null·정수·리스트·
        # dict). `.get(k, "")`는 키 부재시만 ""이고, `or ""`도 falsy만 강등해 truthy non-string(5·[...])이
        # 새어 _norm(5)=re.sub(5)·(root/[...])에서 크래시 → post-1 조립 전체 DoS. **str일 때만 사용**하고
        # 아니면 검증 불가(빈 문자열/판독불가 degrade)로 흐르게 한다.
        q = ev.get("quote")
        quote = _norm(q) if isinstance(q, str) else ""
        if not quote:
            continue
        checked_any = True
        # containment: 인용 경로가 repo_root 밖(절대경로/../ /symlink)이면 판독 불가로 처리한다 —
        # repo 밖 임의 파일을 grounding read로 열지 않는다 (read-oracle 차단, codex final-review).
        try:
            fp = ev.get("file")
            path = (root / (fp if isinstance(fp, str) else "")).resolve()   # non-string file → "" (root, read서 판독불가 degrade)
            path.relative_to(root)
        except (ValueError, OSError):
            any_unreadable = True
            f["degraded_events"].append({"id": f.get("id"), "kind": "citation_unreadable", "file": ev.get("file")})
            continue
        try:
            raw = path.read_text(encoding="utf-8")
        except (FileNotFoundError, OSError, UnicodeDecodeError):
            any_unreadable = True
            f["degraded_events"].append({"id": f.get("id"), "kind": "citation_unreadable", "file": ev.get("file")})
            continue
        norm_lines = [_norm(l) for l in raw.splitlines()]
        hit = next((i for i, l in enumerate(norm_lines, 1) if quote in l), None)
        if hit is None and quote in _norm(raw):
            # 여러 줄에 걸친 인용 — 전체 파일 정규화본엔 있으나 단일 라인엔 없다. 실재는
            # 확인됨(폐기 안 함). 단일 라인을 특정할 수 없어 line-drift 교정은 생략한다.
            continue
        if hit is None:
            any_absent = True
            f["degraded_events"].append({"id": f.get("id"), "kind": "citation_absent", "file": ev.get("file")})
            continue
        cited = ev.get("line", hit)
        if isinstance(cited, int) and abs(hit - cited) > 3:
            ev["line"] = hit
            f["degraded_events"].append({"id": f.get("id"), "kind": "line_drift", "from": cited, "to": hit})
    if any_absent or not checked_any:
        # 부재 인용(가장 강한 신호) OR 검증할 인용이 아예 없음(빈 evidence/전부 공백) → 폐기.
        # evidenceless finding을 grounded로 통과시키면 안 된다 (codex fix-review).
        if not checked_any:
            # 검증 가능한 인용이 0개여서 폐기 — AC-3 정직성 배너에 흔적을 남긴다 (조용한 증발 금지).
            f["degraded_events"].append({"id": f.get("id"), "kind": "evidence_missing"})
        f["grounding_verified"] = False
        f["status"] = "discarded"
    elif any_unreadable:
        f["grounding_verified"] = None
    else:
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
