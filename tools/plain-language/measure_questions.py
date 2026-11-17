#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""질문 도구 호출을 직전에 부른 skill 로 나눠, 질문 창 밖을 가리키는 문구 · 추천의 대가 · 리뷰 결정 질문의 전문 줄을 잰다.

정의:
- 폴더 아래 *.jsonl 을 재귀로 읽는다(하위 agent 기록 포함). 경로 정렬 순서로 읽고, 같은 uuid 는 처음 것만 센다.
- 질문의 skill 은 그 파일에서 질문 직전에 부른 Skill 도구의 input.skill 이다(없으면 "(없음)").
  요약에 세는 질문은 직전 skill 이 devbrew 플러그인의 것(measure_output.devbrew_plugin)인 질문이다.
- out_of_window: 질문 본문이나 어느 선택지 설명에 문구 목록의 문구가 하나라도 있다.
- recommended: 어느 라벨이 (권장) 또는 (Recommended) 를 가진다.
  recommended_all_tradeoff: 그 가운데 모든 선택지 설명에 「얻음:」과 「내줌:」이 있다.
- review_decision: 어느 라벨이 엔진의 상태어(고친다 · 그대로 둔다 · 나중에 정한다 · 채택 · 기각 · 보류 ·
  현재 변경 유지 · 이전 상태로 원복)로 시작한다.
  review_decision_with_fulltext: 그 가운데 본문에 「전문:」으로 시작하는 줄이 있다.
- 지적 id 는 [0-9a-f]{8}#r\\d+\\.\\d+ 다. 게이트 글 묶음은 도구 결과 글에서 「(<id>」 가 든 줄과 그 뒤
  들여쓴 줄들(다음 「- 」 줄 앞까지)이다. 질문과 묶음은 id 로 짝짓는다 — 가까운 묶음으로 짝짓지 않는다.
읽기만 하고 결과는 화면에만 낸다.
"""
import argparse
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from measure_output import devbrew_plugin, parse_auq  # noqa: E402

NO_SKILL = "(없음)"
RECOMMEND_MARKS = ("(권장)", "(Recommended)")
STATE_WORDS = ("고친다", "그대로 둔다", "나중에 정한다", "채택", "기각", "보류",
               "현재 변경 유지", "이전 상태로 원복")
FINDING_ID_RE = re.compile(r"[0-9a-f]{8}#r\d+\.\d+")
DEFAULT_PHRASES = Path(__file__).resolve().parent / "window_phrases.txt"


class Question:
    __slots__ = ("skill", "text", "options", "file", "gate_blocks")

    def __init__(self, skill, text, options, file, gate_blocks):
        self.skill = skill
        self.text = text
        self.options = options          # list of (label, description)
        self.file = file
        self.gate_blocks = gate_blocks  # finding id -> gate text block


def load_phrases(path):
    with open(path, encoding="utf-8") as f:
        lines = [ln.strip() for ln in f.read().splitlines()]
    return [ln for ln in lines if ln and not ln.startswith("#")]


def _jsonl_files(folders):
    found = set()
    for folder in folders:
        for root, _dirs, names in os.walk(folder):
            for n in names:
                if n.endswith(".jsonl"):
                    found.add(os.path.join(root, n))
    return sorted(found)


def _result_text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(b.get("text", "") for b in content
                         if isinstance(b, dict) and isinstance(b.get("text"), str))
    return ""


def gate_blocks_in(text, into):
    """text 에서 지적 id 마다 그 줄과 뒤따르는 들여쓴 줄들을 into[id] 로 모은다."""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        ids = [m for m in FINDING_ID_RE.findall(line) if ("(" + m) in line]
        if not ids:
            continue
        block = [line]
        for nxt in lines[i + 1:]:
            if nxt[:1] in (" ", "\t") and not nxt.lstrip().startswith("- "):
                block.append(nxt)
            else:
                break
        for fid in ids:
            into[fid] = "\n".join(block)


def _parse_questions(inp):
    """(본문, [(라벨, 설명)…]) 목록. 셀 수 없으면 빈 목록."""
    if not isinstance(inp, dict):
        return []
    if "questions" not in inp and isinstance(inp.get("__unparsedToolInput"), dict):
        try:
            inp = json.loads(inp["__unparsedToolInput"].get("raw"))
        except (TypeError, ValueError):
            return []
    if parse_auq(inp) is None:
        return []
    out = []
    for q in inp["questions"]:
        if not isinstance(q, dict):
            continue
        opts = []
        for o in q.get("options") or []:
            if isinstance(o, dict):
                lb, ds = o.get("label"), o.get("description")
                opts.append((lb if isinstance(lb, str) else "", ds if isinstance(ds, str) else ""))
        text = q.get("question")
        out.append((text if isinstance(text, str) else "", opts))
    return out


def scan(folders):
    seen = set()
    questions = []
    for path in _jsonl_files(folders):
        skill = NO_SKILL
        blocks = {}
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    o = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(o, dict):
                    continue
                uid = o.get("uuid")
                if isinstance(uid, str):
                    if uid in seen:
                        continue
                    seen.add(uid)
                content = (o.get("message") or {}).get("content")
                if not isinstance(content, list):
                    continue
                for b in content:
                    if not isinstance(b, dict):
                        continue
                    kind = b.get("type")
                    if kind == "tool_result":
                        gate_blocks_in(_result_text(b.get("content")), blocks)
                    elif kind == "tool_use" and b.get("name") == "Skill":
                        inp = b.get("input")
                        name = inp.get("skill") if isinstance(inp, dict) else None
                        if isinstance(name, str):
                            skill = name
                    elif kind == "tool_use" and b.get("name") == "AskUserQuestion":
                        for text, opts in _parse_questions(b.get("input")):
                            questions.append(Question(skill, text, opts, path, dict(blocks)))
    return questions


def _has_fulltext_line(text):
    return any(ln.startswith("전문:") for ln in text.splitlines())


def summarize(questions, phrases):
    s = dict.fromkeys(("questions", "out_of_window", "recommended", "recommended_all_tradeoff",
                       "review_decision", "review_decision_with_fulltext"), 0)
    for q in questions:
        if not devbrew_plugin(q.skill):
            continue
        s["questions"] += 1
        everything = [q.text] + [lb + "\n" + ds for lb, ds in q.options]
        if any(p in t for p in phrases for t in everything):
            s["out_of_window"] += 1
        if any(m in lb for lb, _ in q.options for m in RECOMMEND_MARKS):
            s["recommended"] += 1
            if all("얻음:" in ds and "내줌:" in ds for _, ds in q.options):
                s["recommended_all_tradeoff"] += 1
        if any(lb.startswith(STATE_WORDS) for lb, _ in q.options):
            s["review_decision"] += 1
            if _has_fulltext_line(q.text):
                s["review_decision_with_fulltext"] += 1
    return s


def _is_review_decision(q):
    return any(lb.startswith(STATE_WORDS) for lb, _ in q.options)


def _paired_blocks(q):
    text = "\n".join([q.text] + [lb + "\n" + ds for lb, ds in q.options])
    ids = []
    for m in FINDING_ID_RE.findall(text):
        if m not in ids:
            ids.append(m)
    return [q.gate_blocks[i] for i in ids if i in q.gate_blocks]


def print_pairs(questions, n):
    shown = 0
    for q in questions:
        if shown >= n:
            break
        if not devbrew_plugin(q.skill) or not _is_review_decision(q):
            continue
        shown += 1
        print("--- 리뷰 결정 질문 %d (%s)" % (shown, q.skill))
        print("질문: " + q.text)
        for lb, ds in q.options:
            print("선택지: %s | %s" % (lb, ds))
        paired = _paired_blocks(q)
        print("게이트 묶음:")
        print("\n".join(paired) if paired else "짝 없음")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("folders", nargs="+")
    ap.add_argument("--phrases", default=str(DEFAULT_PHRASES))
    ap.add_argument("--pairs", type=int, default=0)
    args = ap.parse_args(argv)
    phrases = load_phrases(args.phrases)
    qs = scan(args.folders)
    total = summarize(qs, phrases)
    by_skill = {}
    for name in sorted({q.skill for q in qs if devbrew_plugin(q.skill)}):
        by_skill[name] = summarize([q for q in qs if q.skill == name], phrases)
    t = total
    print("질문 %d개 가운데 창 밖을 가리키는 문구가 든 것 %d · 추천이 있는 것 %d(모든 설명에 얻음 · 내줌이 있는 것 %d)"
          " · 리뷰 결정 질문 %d(전문 줄이 있는 것 %d)"
          % (t["questions"], t["out_of_window"], t["recommended"], t["recommended_all_tradeoff"],
             t["review_decision"], t["review_decision_with_fulltext"]))
    print(json.dumps({"all": total, "by_skill": by_skill}, ensure_ascii=False, sort_keys=True, indent=1))
    if args.pairs > 0:
        print_pairs(qs, args.pairs)
    return 0


if __name__ == "__main__":
    sys.exit(main())
