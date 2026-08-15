#!/usr/bin/env python3
"""/standup 의 인벤토리 · 코드 상태 준비 스크립트.

**판단은 하지 않는다.** 범위 결정 · 계수 · git 조회만 한다. 대화 본문은 출력에
넣지 않는다 — 본문은 fork 안의 에이전트가 직접 읽는다.
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import subprocess
import sys
import time

SLUG_RE = re.compile(r"[/.+]")
OUT_OF_SCOPE_LIST_CAP = 20
REJECT_REASONS = ("other-repo", "cwd-gone", "cwd-missing")


def _run(cmd, cwd=None):
    """(rc, stdout). 실패해도 예외를 올리지 않는다."""
    try:
        proc = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE,
                              stderr=subprocess.DEVNULL)
    except OSError:
        return 127, ""
    return proc.returncode, proc.stdout.decode("utf-8", "replace").strip()


def git_common_dir(cwd):
    """정규화된 절대 git-common-dir. 실패면 None.

    `git rev-parse --git-common-dir` 는 **메인 리포에서 상대 경로('.git')** 를
    돌려주고 워크트리에서는 절대 경로를 돌려준다(실측). 두 호출의 결과를
    문자열로 비교하려면 cwd 기준으로 절대화한 뒤 realpath 로 심볼릭 링크까지
    풀어야 한다 — 이 정규화가 없으면 후보 검증이 전부 other-repo 로 떨어진다.
    """
    rc, out = _run(["git", "rev-parse", "--git-common-dir"], cwd=cwd)
    if rc != 0 or not out:
        return None
    return os.path.realpath(os.path.join(cwd, out))


def repo_root(cwd):
    """메인 리포 루트 = git-common-dir 의 부모."""
    common = git_common_dir(cwd)
    return os.path.dirname(common) if common else None


def current_branch(cwd):
    rc, out = _run(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=cwd)
    return out if rc == 0 and out else None


def slug(path):
    """작업 경로 → 프로젝트 디렉토리 이름. 규칙은 문서화돼 있지 않아 실측이다."""
    return SLUG_RE.sub("-", path)


def candidate_paths(root):
    """접두사 글롭. 디렉토리 **바로 아래**만 본다 — `*/subagents/*.jsonl` 은
    이 패턴에 걸리지 않으므로 인벤토리 분모에 들어오지 않는다(AC49).

    접두사를 쓰는 이유: 디렉토리 이름이 작업 경로에서 만들어지고 문서화되지
    않았다. 정확한 이름을 재현하는 대신 접두사로 시작하는 디렉토리를 전부
    대상으로 삼으면 워크트리가 몇 개든 함께 잡힌다.
    """
    pattern = os.path.join(os.path.expanduser("~/.claude/projects"),
                           slug(root) + "*", "*.jsonl")
    return sorted(glob.glob(pattern))


def read_records(path):
    """(레코드 목록, 파싱 실패 줄 수). 파일을 **한 번만** 읽는다."""
    records, unparsed = [], 0
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    records.append(json.loads(line))
                except ValueError:
                    unparsed += 1
    except OSError:
        return [], 0
    return records, unparsed


def classify(records, our_common_dir, cache):
    """후보 검증 — (채택, 사유).

    파일에 등장하는 **cwd 값 전체 집합** 중 **하나라도** 우리와 같은
    git-common-dir 를 주면 채택한다. 단수 술어를 쓰면 한 세션이 두 cwd 에
    걸치는 실제 상황(메인 리포 → 워크트리 이동)을 못 다룬다.

    **경로 포함 관계로 판정하지 않는다** — 워크트리는 리포 밖 어디에나 놓인다.

    `our_common_dir` 가 `None` 이면 **거절이 아니라 예외다.** 우리 쪽과 후보 쪽이
    같은 `None` 을 "판정 불가" 센티널로 쓰므로 `None == None` 이 참이 되어,
    해석 불가능한 남의 트랜스크립트가 **전부** 채택된다 — 전 범위 상실이 다른
    프로젝트에 대한 건강한 standup 으로 렌더된다. 판정 불가는 일치가 아니다.
    `collect` 가 먼저 막으므로 이 경로는 실행되지 않아야 하며, 실행된다면 그
    가드가 사라졌다는 뜻이라 조용히 거절하지 않고 올린다.
    """
    if our_common_dir is None:
        raise ValueError("our_common_dir 가 미해결 — 후보 검증을 수행할 수 없다")
    seen = []
    for record in records:
        value = record.get("cwd")
        if isinstance(value, str) and value and value not in seen:
            seen.append(value)
    if not seen:
        return False, "cwd-missing"
    any_present = False
    for cwd in seen:
        if cwd not in cache:
            cache[cwd] = git_common_dir(cwd) if os.path.isdir(cwd) else None
        if cache[cwd] == our_common_dir:
            return True, ""
        if os.path.isdir(cwd):
            any_present = True
    # 하나도 남아 있지 않으면 삭제·이동된 워크트리다 — 남의 리포와 합산하면
    # 정당한 과거 세션이 조용히 사라진다.
    return False, ("other-repo" if any_present else "cwd-gone")


def _fmt_stamp(value):
    """ISO8601 UTC 를 그대로 자른다. 시간대 변환을 하지 않는다 — 원문의 그 지점을
    찾아가는 것이 목적이라 기록된 값과 같아야 한다."""
    if not isinstance(value, str) or len(value) < 16:
        return None
    return value[:16].replace("T", " ")


def in_scope(path, records, branch, session_id):
    """범위 = 레코드의 gitBranch 일치 **OR** 파일명이 현재 세션 id (합집합).

    둘 다 단독으로는 샌다 — 브랜치만 보면 워크트리 이동 전 기록이 빠지고,
    세션만 보면 어제 한 것이 빠진다.
    """
    stem = os.path.basename(path)
    if stem.endswith(".jsonl"):
        stem = stem[: -len(".jsonl")]
    if session_id and stem == session_id:
        return list(records)
    return [r for r in records if r.get("gitBranch") == branch]


def count(records):
    """AC34 의 술어. blocks 는 **레코드가 아니라 블록**을 센다."""
    blocks = nbytes = decisions = 0
    calls, results, stamps = set(), set(), []
    for record in records:
        stamp = _fmt_stamp(record.get("timestamp"))
        if stamp:
            stamps.append(stamp)
        message = record.get("message")
        content = message.get("content") if isinstance(message, dict) else None
        if not isinstance(content, list):
            continue
        is_assistant = record.get("type") == "assistant"
        for item in content:
            if not isinstance(item, dict):
                continue
            kind = item.get("type")
            if is_assistant and kind == "text":
                text = item.get("text") or ""
                if text.strip():
                    blocks += 1
                    nbytes += len(text.encode("utf-8"))
            elif kind == "tool_use" and item.get("name") == "AskUserQuestion":
                decisions += 1
                calls.add(item.get("id"))
            elif kind == "tool_result":
                results.add(item.get("tool_use_id"))
    return {
        "blocks": blocks,
        "bytes": nbytes,
        "decisions": decisions,
        # 짝이 없는 호출도 센다(비대화형 실행에는 답변 채널이 없어 실제로 생긴다).
        "unpaired": len([c for c in calls if c not in results]),
        "span_min": min(stamps) if stamps else None,
        "span_max": max(stamps) if stamps else None,
    }


def collect(root, branch, session_id):
    """인벤토리 원자료. 렌더는 하지 않는다.

    우리 리포의 git-common-dir 를 못 구하면 **`None` 을 돌려준다** — 그 상태로는
    어떤 후보도 우리 것인지 판정할 수 없고(`classify` 의 센티널 주석 참조),
    부분 답변은 다른 프로젝트의 답변이 된다. bare 리포가 실물 진입로다:
    `git rev-parse --git-common-dir` 가 `.` 을 주어 `repo_root` 가 부모로
    올라가고, 그 부모는 리포가 아니다.
    """
    started = time.time()
    ours = git_common_dir(root)
    if ours is None:
        return None
    cache = {}
    rejected = dict((reason, 0) for reason in REJECT_REASONS)
    entries, unparsed, candidates = [], 0, 0
    totals = {"blocks": 0, "bytes": 0, "decisions": 0, "unpaired": 0}
    stamps = []

    for path in candidate_paths(root):
        records, bad = read_records(path)
        accepted, reason = classify(records, ours, cache)
        if not accepted:
            rejected[reason] = rejected.get(reason, 0) + 1
            continue
        candidates += 1
        unparsed += bad
        mine = in_scope(path, records, branch, session_id)
        stats = count(mine)
        whole = count(records)
        for key in totals:
            totals[key] += stats[key]
        for value in (stats["span_min"], stats["span_max"]):
            if value:
                stamps.append(value)
        entries.append({
            "path": path,
            "in_scope": len(mine),
            "total": len(records),
            # in-scope 블록은 in-scope 기간, out-of-scope 블록은 파일 전체 기간을 보여준다.
            "span_min": stats["span_min"] if mine else whole["span_min"],
            "span_max": stats["span_max"] if mine else whole["span_max"],
            "label": "in-scope" if mine else "out-of-scope",
        })

    data = dict(totals)
    data.update({
        "files": len([e for e in entries if e["label"] == "in-scope"]),
        "candidates": candidates,
        "rejected": rejected,
        "entries": entries,
        "unparsed": unparsed,
        "span_min": min(stamps) if stamps else None,
        "span_max": max(stamps) if stamps else None,
        "scan": time.time() - started,
        "git_calls": len(cache),
    })
    return data


def _kb(nbytes):
    return "%.1f KB" % (nbytes / 1024.0)


def _span(low, high):
    if not low or not high:
        return "(기간 없음)"
    return "%s ~ %s" % (low, high)


def render_inventory(root, branch, session_id, data):
    """scope 줄 + 인벤토리 2줄 + 파일 목록 세 블록.

    `scope:` 줄은 장식이 아니다 — SKILL.md 가 범위 대조에도(branch·+session)
    가용성 센티널에도(그 줄이 없으면 답하지 않는다) 쓴다.
    """
    in_scope_entries = [e for e in data["entries"] if e["label"] == "in-scope"]
    others = sorted([e for e in data["entries"] if e["label"] == "out-of-scope"],
                    key=lambda e: (e["span_max"] or "", e["path"]), reverse=True)
    shown, folded = others[:OUT_OF_SCOPE_LIST_CAP], others[OUT_OF_SCOPE_LIST_CAP:]
    listed = len(in_scope_entries) + len(shown)

    rejected_total = sum(data["rejected"].values())
    breakdown = ", ".join("%s: %d" % (r, data["rejected"].get(r, 0))
                          for r in REJECT_REASONS)
    lines = [
        "scope:   repo=%s  branch=%s  +session=%s" % (root, branch, session_id or "-"),
        "files:   %d (candidates: %d  rejected: %d (%s)  listed: %d)   "
        "blocks: %d (%s)   decisions: %d (unpaired: %d)"
        % (data["files"], data["candidates"], rejected_total, breakdown, listed,
           data["blocks"], _kb(data["bytes"]), data["decisions"], data["unpaired"]),
        "span:    %s   commits: %d   scan: %.1fs   unparsed: %d"
        % (_span(data["span_min"], data["span_max"]), data.get("commits", 0),
           data["scan"], data["unparsed"]),
        "",
        # 세 라벨은 **비어 있어도** 낸다 — 데이터에 따라 계약이 갈리면 안 된다.
        "in-scope — %d개 전량:" % len(in_scope_entries),
    ]
    for entry in in_scope_entries:
        lines.append("  %s   %d건  %s"
                     % (entry["path"], entry["in_scope"],
                        _span(entry["span_min"], entry["span_max"])))
    lines.append("out-of-scope — %d개 중 최근 %d개:" % (len(others), len(shown)))
    for entry in shown:
        lines.append("  %s   [%d건]  %s"
                     % (entry["path"], entry["total"],
                        _span(entry["span_min"], entry["span_max"])))

    rollup = {}
    for entry in folded:
        directory = os.path.dirname(entry["path"])
        bucket = rollup.setdefault(directory, {"n": 0, "low": None, "high": None})
        bucket["n"] += 1
        for key, value in (("low", entry["span_min"]), ("high", entry["span_max"])):
            if value and (bucket[key] is None
                          or (value < bucket[key] if key == "low" else value > bucket[key])):
                bucket[key] = value
    lines.append("out-of-scope 디렉토리 집계 — %d개 (위 %d개를 뺀 나머지 %d개):"
                 % (len(rollup), len(shown), len(folded)))
    for directory in sorted(rollup):
        bucket = rollup[directory]
        lines.append("  %s   %d개  %s"
                     % (directory, bucket["n"],
                        _span((bucket["low"] or "")[:10], (bucket["high"] or "")[:10])))
    return "\n".join(lines)


def base_ref(cwd):
    """origin/main 우선, 없으면 main. 둘 다 실패면 None."""
    for ref in ("origin/main", "main"):
        rc, out = _run(["git", "merge-base", "HEAD", ref], cwd=cwd)
        if rc == 0 and out:
            return out
    return None


def commit_lines(cwd):
    """base..HEAD 커밋 로그. base 가 없으면 최근 20개로 강등. (base, command, rc, out).

    `render_code_state()` 와 `main()` 이 이 하나로 범위 결정과 실제 git 호출을
    공유한다 — 각자 재구현하면 드리프트한다. 실사례: `main()` 은 한때
    `base_ref(cwd) or "HEAD"` 로 대입해 base 가 없을 때
    `git log --oneline HEAD..HEAD`(늘 빈 범위)가 됐는데, `render_code_state()`
    는 같은 조건에서 `-20` 으로 정확히 강등했다 — 그 결과 `commits: 0` 이
    바로 아래 `## 코드 상태` 커밋 목록과 모순되는 버그였다.
    """
    base = base_ref(cwd)
    command = (["git", "log", "--oneline", "%s..HEAD" % base] if base
              else ["git", "log", "--oneline", "-20"])
    rc, out = _run(command, cwd=cwd)
    return base, command, rc, out


def render_code_state(cwd):
    """한 재료가 죽어도 나머지는 산다. 빈 절을 조용히 두지 않는다."""
    lines = ["## 코드 상태", ""]
    base, log_command, log_rc, log_out = commit_lines(cwd)
    if not base:
        lines.append("(base-ref 를 구하지 못해 최근 20개 커밋으로 강등)")
    remaining = [["git", "diff", "--stat", "%s..HEAD" % base]] if base else []
    remaining += [["git", "status", "--short"],
                 ["git", "diff", "--stat"],
                 ["git", "diff", "--cached", "--stat"]]

    def emit(command, rc, out):
        label = " ".join(command)
        if rc != 0:
            lines.append("(git 조회 실패: %s, %d)" % (label, rc))
            return
        lines.append("$ %s" % label)
        lines.append(out if out else "(없음)")
        lines.append("")

    emit(log_command, log_rc, log_out)
    for command in remaining:
        rc, out = _run(command, cwd=cwd)
        emit(command, rc, out)
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(add_help=False)
    # 사용자 유래 인자는 받지 않는다 — 범위 조정은 「범위 라벨」로 에이전트가 수행한다.
    parser.add_argument("--session-id", default=os.environ.get("CLAUDE_CODE_SESSION_ID"))
    args = parser.parse_args(argv)
    try:
        cwd = os.getcwd()
        root = repo_root(cwd)
        if not root:
            sys.stdout.write("STANDUP-UNAVAILABLE: not a git repository (%s)\n" % cwd)
            return 3
        branch = current_branch(cwd) or "(unknown)"
        data = collect(root, branch, args.session_id)
        if data is None:
            # 파일 부재로 강등하면 사용자는 원인을 파일 쪽에서 찾는다. 원인은
            # 리포 미해결이고, 그 상태에서 낸 답은 남의 프로젝트 답일 수 있다.
            sys.stdout.write(
                "STANDUP-UNAVAILABLE: repository could not be resolved (%s)\n" % root)
            return 3
        if not data["entries"]:
            sys.stdout.write(
                "STANDUP-UNAVAILABLE: session file not found "
                "(~/.claude/projects/%s*/*.jsonl)\n" % slug(root))
            return 3
        _, _, commits_rc, commits_out = commit_lines(cwd)
        data["commits"] = (len([ln for ln in commits_out.splitlines() if ln.strip()])
                           if commits_rc == 0 else 0)
        sys.stdout.write(render_inventory(root, branch, args.session_id, data))
        sys.stdout.write("\n\n")
        sys.stdout.write(render_code_state(cwd))
        sys.stdout.write("\n")
        return 0
    except Exception as exc:
        # 실패 계약은 "STANDUP-UNAVAILABLE 한 줄, 절대 죽지 않는다" — 그 계약을
        # 지키는 코드 자체가 죽으면 안 된다. 메시지를 UTF-8 로 왕복시켜
        # 인코딩 불가 문자(예: 홑 서로게이트)를 무해화하고, 그 write 자체도
        # 감싼다 — 무해화가 놓친 두 번째 실패도 새어나가지 못하게.
        # (2026-08-13 이전에는 훅의 _degraded() 가 같은 모양을 공유했다. 훅이
        #  제거되어 이 파일이 그 양식의 유일한 보유자다.)
        try:
            try:
                message = str(exc)
            except Exception:
                message = repr(exc)
            safe = message.encode("utf-8", "replace").decode("utf-8")
            sys.stdout.write("STANDUP-UNAVAILABLE: internal error (%s)\n" % safe)
        except Exception:
            try:
                sys.stdout.write("STANDUP-UNAVAILABLE: internal error\n")
            except Exception:
                pass
        return 4


if __name__ == "__main__":
    sys.exit(main())
