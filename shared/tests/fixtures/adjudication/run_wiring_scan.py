import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools" / "adjudication"))
from check_wiring import (  # noqa: E402
    EXEMPT, TERMINAL_CONSUMERS, comprehension_count, derive_consumers, scan,
    stale_exempt)

union, by_import, by_anchor = derive_consumers(str(root))
print("union=%d" % len(union))
print("import=%d" % len(by_import))
print("anchor=%d" % len(by_anchor))
for p in union:
    print("  CONSUMER %s" % p)
# 개수(import=/anchor=)만으로는 대리지표다 — 집합 자체를 낸다. 한쪽에서
# 빠지고 무관한 다른 경로가 반대쪽에 들어오면 개수는 같아 그대로 통과한다.
for p in by_import:
    print("  IMPORT %s" % p)
for p in by_anchor:
    print("  ANCHOR %s" % p)
for p in sorted(TERMINAL_CONSUMERS):
    print("  TERMINAL %s" % p)

abs_paths = [str(root / p) for p in union]
rows = scan(abs_paths)
unwired = []
for r in rows:
    rel = str(Path(r["file"]).relative_to(root))
    if r["guarded"]:
        continue
    if (rel, r["line"]) in EXEMPT:
        continue
    unwired.append((rel, r["line"], r["kind"], r["func"]))
print("unwired=%d" % len(unwired))
for (rel, line, kind, func) in unwired:
    print("  UNWIRED %s:%d %s in %s" % (rel, line, kind, func))

print("exempt_total=%d" % len(EXEMPT))
print("exempt_uncited=%d" % len([v for v in EXEMPT.values()
                                 if "C6" not in str(v)]))
print("terminal_total=%d" % len(TERMINAL_CONSUMERS))
# Task 11b Step 4b — EXEMPT 와 같은 규율(값에 리터럴 "C6" 요구)로 맞췄다.
# 이전엔 빈 문자열만 아니면 통과해 그럴듯한 비-C6 변명도 조용히 통과했다.
print("terminal_uncited=%d" % len([v for v in TERMINAL_CONSUMERS.values()
                                   if "C6" not in str(v)]))
print("comprehensions=%d" % comprehension_count(abs_paths))

# Task 12b Step 4d — 낡은 (경로, 줄번호) 면제 키가 조용히 다른 버리는 분기를
# 가리는 구멍을 소리 나게 만든다(Task 11b 실증).
stale = stale_exempt(str(root))
print("exempt_stale=%d" % len(stale))
for (rel, line) in stale:
    print("  STALE_EXEMPT %s:%d" % (rel, line))
