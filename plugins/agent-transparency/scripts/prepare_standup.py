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
    """
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
    """인벤토리 원자료. 렌더는 하지 않는다."""
    started = time.time()
    ours = git_common_dir(root)
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
