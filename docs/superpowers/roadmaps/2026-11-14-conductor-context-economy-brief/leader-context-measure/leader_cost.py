"""리더 본 대화의 API 호출마다 맥락 크기와 캐시 읽기 · 쓰기를 더한다. 읽기만 한다."""
import json, sys
from datetime import datetime, timedelta
def ts(s): return datetime.fromisoformat(s.replace("Z", "+00:00"))
R = W = WC = N = 0; bands = {"~15만": [0, 0], "15만~30만": [0, 0], "30만~50만": [0, 0], "50만~": [0, 0]}
for p in sys.argv[1:]:
    seen = set(); prev = None
    for line in open(p, encoding="utf-8", errors="replace"):
        if '"usage"' not in line: continue
        try: d = json.loads(line)
        except ValueError: continue
        if d.get("isSidechain") or d.get("type") != "assistant": continue
        m = d.get("message") or {}; u = m.get("usage") or {}
        if m.get("id") in seen or not u: continue
        seen.add(m.get("id"))
        cr = u.get("cache_read_input_tokens", 0) or 0; cw = u.get("cache_creation_input_tokens", 0) or 0
        ctx = cr + cw + (u.get("input_tokens", 0) or 0); t = ts(d["timestamp"])
        R += cr; W += cw; N += 1
        if prev and t - prev > timedelta(minutes=60): WC += cw
        prev = t
        b = "~15만" if ctx < 150e3 else "15만~30만" if ctx < 300e3 else "30만~50만" if ctx < 500e3 else "50만~"
        bands[b][0] += 1; bands[b][1] += cr
print(f"호출 {N}번 · 평균 맥락 {(R+W)/N/1000:.0f}k · 캐시 읽기 합 {R/1e6:.0f}M · 캐시 쓰기 합 {W/1e6:.1f}M(그중 1시간 넘게 쉰 뒤 첫 응답 {WC/1e6:.1f}M)")
for b, (n, r) in bands.items(): print(f"  맥락 {b}: 호출 {n}번({n/N*100:.0f}%) · 캐시 읽기 {r/1e6:.0f}M({r/R*100:.0f}%)")
