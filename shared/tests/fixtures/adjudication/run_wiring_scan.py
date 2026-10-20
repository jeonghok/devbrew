import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools" / "adjudication"))
from check_wiring import (  # noqa: E402
    EXEMPT, EXEMPT_BASELINE, TERMINAL_CONSUMERS, _DR_ESCALATED_TARGET_GONE,
    _DR_RERAISE_TARGET_GONE, comprehension_count, derive_consumers,
    duplicate_identities, exempt_key, scan, stale_exempt, stale_terminal,
    uncited_exemptions)
# 인용 실질 판정은 `cite.py` 가 원천이다 — check_wiring 을 경유해 «재수출»
# 받으면 그 파일에서 쓰이지 않는 별칭이 남아 죽은 import 처럼 보인다.
from cite import cited  # noqa: E402

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
    # 면제 키는 (경로, 정체)다. 정체는 `<kind> in <func> @ <guard> ~ <loop>` 이고
    # 줄 번호는 넣지 않는다 — 조건이 바뀐 분기는 면제를 상속하지 못하고 미배선으로
    # 다시 나온다(stale_exempt 의 양의 짝).
    if exempt_key(rel, r) in EXEMPT:
        continue
    unwired.append((rel, r["line"], r["kind"], r["func"], r["guard"]))
print("unwired=%d" % len(unwired))
for (rel, line, kind, func, guard) in unwired:
    print("  UNWIRED %s:%d %s in %s @ %s" % (rel, line, kind, func, guard))

print("exempt_total=%d" % len(EXEMPT))
print("exempt_baseline=%d" % EXEMPT_BASELINE)
print("exempt_uncited=%d" % len(uncited_exemptions()))
print("terminal_total=%d" % len(TERMINAL_CONSUMERS))
# Task 11b Step 4b — EXEMPT 와 같은 규율로 맞췄다. 이전엔 빈 문자열만
# 아니면 통과해 그럴듯한 비-C6 변명도 조용히 통과했다. 최종 리뷰(A/m1) —
# 리터럴 "C6" 두 글자면 만족하던 것을 `cite.cited()` 로 조인다.
print("terminal_uncited=%d"
      % len([v for v in TERMINAL_CONSUMERS.values() if not cited(v)]))
print("comprehensions=%d" % comprehension_count(abs_paths))

# Task 12b Step 4d — 낡은 면제 키가 조용히 다른 버리는 분기를 가리는 구멍을
# 소리 나게 만든다(Task 11b 실증). 최종 리뷰(K1) — 키가 «정체»까지 쥐므로
# 줄 수를 보존한 채 조건만 바꾼 분기도 여기서 어긋난다.
stale = stale_exempt(str(root))
print("exempt_stale=%d" % len(stale))
for (rel, ident) in stale:
    print("  STALE_EXEMPT %s %s" % (rel, ident))

# 키가 자리를 가르지 못하면(정체가 같은 행 둘 이상) 면제 여부와 무관하게 RED 다.
dups = duplicate_identities(rows, str(root))
print("duplicate_identity=%d" % len(dups))
for (rel, ident) in dups:
    print("  DUPLICATE_IDENTITY %s %s" % (rel, ident))

# 면제 키의 꼴 — (경로, 정체) 2-튜플, 정체에 둘러싼 for 의 글자.
bad_shape = 0
for k in EXEMPT:
    if not (isinstance(k, tuple) and len(k) == 2 and " ~ for " in str(k[1])):
        bad_shape += 1
print("exempt_key_bad_shape=%d" % bad_shape)
# 형제 둘(escalated · reraise 예약의 `if not f0`) — 사유와 키가 내용으로 짝지어지는가.
for name, reason in (("escalated", _DR_ESCALATED_TARGET_GONE),
                     ("reraise", _DR_RERAISE_TARGET_GONE)):
    keys = [k for k, v in EXEMPT.items() if v == reason]
    print("exempt_sibling_%s=%s" % (name, keys[0][-1] if len(keys) == 1 else ""))
sib = set()
for r in rows:
    if r["func"] == "_auto_decides" and r["guard"] == "if not f0":
        sib.add(exempt_key(str(Path(r["file"]).relative_to(root)), r))
print("sibling_live_keys=%d" % len(sib))

# F-2 재리뷰가 지적한 비대칭의 절반(신선도) — EXEMPT 처럼 TERMINAL_CONSUMERS
# 도 자기 등재가 여전히 유효한지(파일 존재 + 앵커 없음) 잰다.
tstale = stale_terminal(str(root))
print("terminal_stale=%d" % len(tstale))
for (p, why) in tstale:
    print("  STALE_TERMINAL %s %s" % (p, why))
