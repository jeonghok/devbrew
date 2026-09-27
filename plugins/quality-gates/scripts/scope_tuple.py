#!/usr/bin/env python3
"""스코프 튜플 — `topic-head.sh` 산출물을 판정 꼬리의 `scope:` 블록으로 (설계 §6.2.6).

`clean` 은 이 튜플에 대한 clean 이다 — 본 커밋 · 끝점 · 경계 · 합친 트리가 판정과 한
출력에 실려야 나중에 트레일러를 고쳐도 이미 난 판정이 다른 대상으로 재사용되지 않는다
(AC15). 끝점 합치기가 충돌하면 충돌 파일을 싣는다(AC7). 그 키의 선언 중 이미 base 에
든 수(`in_base`)를 싣는다 — 토픽 구성원에서 빠진 머지된 앞 조각이다(AC4).

`status:` → 판정 사유는 여기서만 정한다(`STATUS_TO_REASON`). 오케스트레이터는 사유를
옮겨 적지 않고 이 파일을 합성기에 `--scope` 로 넘긴다. 값 자체는 `verdict.REASONS`
안이고 `verdict.decide()` 가 검증한다.
"""
import re
import sys

KEYS = ("topic_key", "status", "reason", "branches", "in_base", "boundary", "tips",
        "seal", "seal_on_topic", "tree", "head_commit", "conflicts", "commits")
STATUSES = ("ok", "no-declaration", "base-unresolved", "declaration-invalid",
            "unbounded", "seal-failed", "merge-conflict", "merge-failed")
# 사유가 없는 status 는 스코프 축에서 막지 않는다 — `no-declaration` 은 새 의무가 아니고
# (§6.2.5), `base-unresolved` 는 차등 테스트 R-init 의 「baseline 확정 불가」가,
# `seal-failed` 는 R5b 의 HEAD 축 미관측이 이미 막는다. `unbounded` · `merge-failed` 는
# 가장 가까운 이름으로 보낸다 — 토픽이 한 판정 단위를 못 이룸 · 끝점을 합치지 못함.
STATUS_TO_REASON = {
    "declaration-invalid": "declaration-invalid",
    "unbounded": "declaration-invalid",
    "merge-conflict": "merge-conflict",
    "merge-failed": "merge-conflict",
}
_OID = re.compile(r"[0-9a-f]{40}|[0-9a-f]{64}")
_COUNT = re.compile(r"[0-9]+")
_RENDER_ORDER = ("topic_key", "reason", "branches", "in_base", "boundary", "tips", "tree",
                 "seal_on_topic", "conflicts")


def fail4(msg):
    # 스크립트 이름을 접두사로 쓴다 — `scope:` 로 시작하면 줄-지향 파서가 블록으로 읽는다.
    print(f"scope_tuple.py: {msg}", file=sys.stderr)
    raise SystemExit(4)


def read_or_fail4(path):
    """호출자가 이미 「쓴다」고 정한 경로다 — 부재가 곧 실패다(`angles.read_or_fail4` 와 같다)."""
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except OSError as exc:
        fail4(f"스코프 파일을 읽지 못했다: {path} ({exc})")
    except UnicodeDecodeError as exc:
        fail4(f"스코프 파일이 UTF-8 이 아님: {path} ({exc})")


def parse(text):
    seen = {}
    commits = []
    # 줄 경계는 `\n` 하나다 — splitlines() 는 U+2028 등도 줄 끝으로 읽어 값을 자른다.
    # CRLF 는 텍스트 모드 읽기의 universal newline 이 이미 접는다.
    for line in text.split("\n"):
        if not line.strip():
            continue
        key, sep, val = line.partition(": ")
        if not sep:
            fail4(f"key: value 가 아닌 줄: {line!r}")
        if key == "commit":
            if not _OID.fullmatch(val):
                fail4(f"commit 값이 커밋 id 가 아니다: {val!r}")
            commits.append(val)
            continue
        if key not in KEYS:
            fail4(f"모르는 키: {key!r}")
        if key in seen:
            fail4(f"키가 두 번: {key!r}")
        seen[key] = val
    missing = [k for k in KEYS if k not in seen]
    if missing:
        fail4("빠진 키: " + ", ".join(missing))
    if seen["status"] not in STATUSES:
        fail4(f"열거 밖 status: {seen['status']!r}")
    if seen["commits"] == "-":
        if commits:
            fail4("commits: - 인데 commit: 줄이 있다")
    elif not _COUNT.fullmatch(seen["commits"]) or int(seen["commits"]) != len(commits):
        fail4(f"commits: {seen['commits']} 와 commit: 줄 {len(commits)}개가 다르다")
    if seen["in_base"] != "-" and not _COUNT.fullmatch(seen["in_base"]):
        fail4(f"in_base 가 수 또는 - 가 아니다: {seen['in_base']!r}")
    if seen["status"] == "ok":
        for k in ("boundary", "tree", "head_commit", "seal"):
            if not _OID.fullmatch(seen[k]):
                fail4(f"status: ok 인데 {k} 가 id 가 아니다: {seen[k]!r}")
        if not all(_OID.fullmatch(t) for t in seen["tips"].split(",")):
            fail4(f"status: ok 인데 tips 가 id 목록이 아니다: {seen['tips']!r}")
        if seen["commits"] == "-":
            fail4("status: ok 인데 commits 가 없다")
        if not _COUNT.fullmatch(seen["in_base"]):
            fail4(f"status: ok 인데 in_base 가 수가 아니다: {seen['in_base']!r}")
    d = dict(seen)
    d["commit"] = commits
    return d


def reason_of(d):
    return STATUS_TO_REASON.get(d["status"])


def render(d):
    """`scope:` 블록. `mode` 는 이 판정이 실제로 본 스코프다 — 토픽을 못 쓰면 session."""
    out = ["scope:",
           f"  mode: {'topic' if d['status'] == 'ok' else 'session'}",
           f"  status: {d['status']}"]
    for k in _RENDER_ORDER:
        label = "detail" if k == "reason" else k
        out.append(f"  {label}: {d[k]}")
    out.append(f"  commits: {d['commits']}")
    for c in d["commit"]:
        out.append(f"  commit: {c}")
    return "\n".join(out) + "\n"


def main():
    if len(sys.argv) != 2 or not sys.argv[1]:
        print("scope_tuple.py: usage: scope_tuple.py <스코프 파일>", file=sys.stderr)
        return 2
    sys.stdout.write(render(parse(read_or_fail4(sys.argv[1]))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
