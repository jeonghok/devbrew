"""leader_fill.py 의 둘째 층 — 리더가 쓴 도구 인자와 「셸 — 그 밖」 을 더 가른다. 읽기만 한다."""
import json, re, sys
from collections import defaultdict

W = [("설계문서", r"/specs/"), ("계획", r"/plans/"), ("로드맵 · 묶음", r"/roadmaps/"),
     ("보내는 글 · 옮김 기록 · 보고(기계 상태 폴더)", r"/\.claude/spec-distill/"),
     ("인계 · 거울 글(sdd-mirror)", r"sdd-mirror"), ("메모리", r"/memory/"),
     ("임시 자리(scratchpad · tmp)", r"scratchpad|/tmp/"),
     ("플러그인 코드 · 테스트 · 문서", r"/plugins/|/shared/|/tools/|/tests/")]
B = [("스위트 대조 · 스위트", r"merge_check|suite_lock|run-all\.sh"), ("상태 계산 · 기계 상태 · 상태 브랜치", r"control_plane|conductor_"),
     ("리뷰 엔진 · 대조 스크립트", r"docreview|spec_review|check_bundle|check_brief|qg_|quality"), ("hc", r"(^|[\s;&|(])hc\s"),
     ("gh", r"(^|[\s;&|(])gh\s"), ("git", r"(^|[\s;&|(])git\s")]

def first_word(c):
    c = c.strip()
    for _ in range(6):
        m = re.match(r"(cd\s+\S+\s*(&&|;)\s*|[A-Za-z_][A-Za-z0-9_]*=(\"[^\"]*\"|'[^']*'|\S*)\s*;?\s*|\(\s*)", c)
        if not m or not m.group(0):
            break
        c = c[m.end():]
    w = re.split(r"[\s;|&<>(]", c, 1)[0]
    return w.rsplit("/", 1)[-1][:24] or "?"

arg = defaultdict(int); argn = defaultdict(int); oth = defaultdict(int); othn = defaultdict(int)
for p in sys.argv[1:]:
    pend = {}
    for line in open(p, encoding="utf-8", errors="replace"):
        try: d = json.loads(line)
        except ValueError: continue
        if d.get("isSidechain"): continue
        c = (d.get("message") or {}).get("content")
        if not isinstance(c, list): continue
        for part in c:
            if not isinstance(part, dict): continue
            if d.get("type") == "assistant" and part.get("type") == "tool_use":
                name, inp = part.get("name", ""), part.get("input") or {}
                n = len(json.dumps(inp, ensure_ascii=False))
                if name in ("Edit", "Write"):
                    fp = inp.get("file_path", "")
                    lab = next((l for l, rx in W if re.search(rx, fp)), "그 밖")
                    lab = "파일 쓰기 · 고치기 — " + lab
                elif name == "Bash":
                    cmd = inp.get("command", "")
                    lab = next((l for l, rx in B if re.search(rx, cmd)), None)
                    if lab is None:
                        pend[part.get("id")] = first_word(cmd)
                        lab = "그 밖"
                    lab = "셸 명령 — " + lab
                elif name in ("Agent", "Task"): lab = "하위 agent 에게 보내는 글"
                elif name == "SendMessage": lab = "하위 agent 이어 부르기"
                elif name == "AskUserQuestion": lab = "질문 창에 띄운 글"
                else: lab = "도구 — " + name
                arg[lab] += n; argn[lab] += 1
            elif d.get("type") == "user" and part.get("type") == "tool_result" and part.get("tool_use_id") in pend:
                cc = part.get("content")
                n = len(cc) if isinstance(cc, str) else sum(len(x.get("text") or "") for x in cc or [] if isinstance(x, dict))
                w = pend[part.get("tool_use_id")]
                oth[w] += n; othn[w] += 1
t = sum(arg.values()) or 1
print(f"리더가 쓴 도구 인자 합 {t/1000:.0f}k 글자")
for l, n in sorted(arg.items(), key=lambda kv: -kv[1])[:16]:
    print(f"{n/t*100:5.1f}%  {n/1000:7.0f}k  {argn[l]:5d}번  {l}")
t = sum(oth.values()) or 1
print(f"\n「셸 — 그 밖」 결과 합 {t/1000:.0f}k 글자 — 명령의 첫 낱말로")
for l, n in sorted(oth.items(), key=lambda kv: -kv[1])[:14]:
    print(f"{n/t*100:5.1f}%  {n/1000:7.0f}k  {othn[l]:5d}번  {l}")
