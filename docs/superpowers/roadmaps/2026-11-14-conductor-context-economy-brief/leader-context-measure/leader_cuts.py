"""리더 세션 기록에서 «끊긴 자리» 를 센다 — 압축 · 오래 쉰 뒤 다시 시작 · 세션 바뀜.

읽기만 한다. 인자: 세션 기록(jsonl) 경로들.
"""
import json
import sys
from datetime import datetime, timedelta, timezone

KST = timezone(timedelta(hours=9))
GAP_MIN = 60  # 본 세션 캐시 수명(1시간)을 넘긴 쉼


def ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00")).astimezone(KST)


def user_text(msg):
    c = msg.get("content")
    if isinstance(c, str):
        return c
    out = []
    for part in c or []:
        if isinstance(part, dict) and part.get("type") == "text":
            out.append(part.get("text", ""))
        elif isinstance(part, dict) and part.get("type") == "tool_result":
            return None
    return "\n".join(out) if out else None


def clean(t, n=110):
    t = " ".join(t.split())
    return t[:n] + ("…" if len(t) > n else "")


def scan(path):
    first = last = None
    compacts = []
    gaps = []
    last_user = ""
    prev_asst = None  # (time, ctx)
    peak = 0
    seen_ids = set()
    turns = 0
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if '"timestamp"' not in line:
                continue
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if d.get("isSidechain"):
                continue
            t = d.get("timestamp")
            if not t:
                continue
            t = ts(t)
            first = first or t
            last = t
            typ = d.get("type")
            if typ == "system" and d.get("subtype") == "compact_boundary":
                meta = d.get("compactMetadata") or {}
                compacts.append((t, meta.get("trigger"), meta.get("preTokens"), last_user))
                prev_asst = None
                continue
            if typ == "user" and not d.get("isMeta") and not d.get("isCompactSummary"):
                txt = user_text(d.get("message") or {})
                if txt and not txt.lstrip().startswith(("<task-notification", "<system-reminder", "<local-command", "Caveat:")):
                    last_user = clean(txt)
                    turns += 1
                continue
            if typ == "assistant":
                m = d.get("message") or {}
                mid = m.get("id")
                u = m.get("usage") or {}
                if not u or mid in seen_ids:
                    continue
                seen_ids.add(mid)
                cw = u.get("cache_creation_input_tokens", 0) or 0
                cr = u.get("cache_read_input_tokens", 0) or 0
                ctx = cw + cr + (u.get("input_tokens", 0) or 0)
                peak = max(peak, ctx)
                if prev_asst and (t - prev_asst[0]) > timedelta(minutes=GAP_MIN):
                    gaps.append((prev_asst[0], t, ctx, cw, last_user))
                prev_asst = (t, ctx)
    return first, last, compacts, gaps, peak, turns


def k(n):
    return "?" if n is None else f"{n / 1000:.0f}k"


for p in sys.argv[1:]:
    first, last, compacts, gaps, peak, turns = scan(p)
    sid = p.rsplit("/", 1)[-1][:8]
    if not first:
        print(f"## {sid} — 읽을 줄 없음")
        continue
    print(f"## {sid} — {first:%m-%d %H:%M} ~ {last:%m-%d %H:%M} · 사용자 글 {turns} · 가장 컸던 맥락 {k(peak)}")
    print(f"압축 {len(compacts)}번")
    for t, trig, pre, lu in compacts:
        print(f"  - {t:%m-%d %H:%M} · {trig} · 압축 전 {k(pre)} · 직전 사용자 글: {lu}")
    cold = sum(g[3] for g in gaps)
    print(f"{GAP_MIN}분 넘게 쉰 뒤 이어 간 자리 {len(gaps)}번 · 그 첫 응답의 캐시 다시 쓰기 합 {k(cold)}")
    for a, b, ctx, cw, lu in gaps:
        mins = int((b - a).total_seconds() // 60)
        print(f"  - {a:%m-%d %H:%M} → {b:%m-%d %H:%M} ({mins // 60}시간 {mins % 60}분) · 맥락 {k(ctx)} · 다시 쓰기 {k(cw)} · 이어 준 글: {lu}")
    print()
