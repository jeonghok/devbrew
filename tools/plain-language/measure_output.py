#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""사람에게 보이는 글의 양을 고정한 세션 기록 목록에서 잰다 (쉬운 말 출력 설계 AC12).

입력은 목록 파일 하나다(TSV, 머리 `path\\tsize\\tmtime`). 목록에 적힌 파일만 읽는다.
디렉토리를 훑지 않으므로 목록 밖 파일은 값에 닿지 않는다. 크기(바이트)나 수정 시각(정수 초)이
목록과 다른 파일, 사라진 파일은 읽지 않고 개수와 경로를 따로 낸다.

집계 정의
- 기록 항목: 한 줄 = JSON 객체 하나. `type` 이 `user`·`assistant` 인 것만 본다.
  같은 `uuid` 가 여러 파일에 있으면(세션 이어가기가 앞 기록을 복사한다) 경로 정렬 순서로
  처음 본 것만 쓰고, 버린 수를 낸다.
- 사람 메시지: `type=user` 이고 `isMeta`·`isCompactSummary`·`isSidechain` 이 참이 아니며,
  내용이 `tool_result` 블록만으로 되어 있지 않은 것 중
  · `origin` 이 있으면 `origin.kind == "human"` 인 것,
  · `origin` 이 없으면 `promptSource` 가 `sdk`·`system` 이 아니고, 글이 기계 태그
    (MACHINE_PREFIXES)로 시작하지 않는 것. 사용자가 친 슬래시 명령(`<command-name>`·
    `<command-message>`)과 `!` 명령(`<bash-input>`)은 사람 메시지다.
- 턴: 한 파일 안에서 사람 메시지 하나부터 다음 사람 메시지 직전까지. 파일 첫 사람 메시지
  앞부분(남이 보낸 프롬프트로 시작한 세션 등)은 턴이 아니라 「앞부분」 단위다.
  복사돼 버린 사람 메시지 뒤에 이어진 항목도 턴이 아니라 「이어짐」 단위로 센다.
- 보이는 글: assistant 항목의 `content` 중 `type == "text"` 블록의 글자 수(코드 포인트).
  `isApiErrorMessage` 이거나 `message.model == "<synthetic>"` 인 항목은 뺀다.
- 값 1 — 턴당 보이는 글: assistant 항목이 하나라도 있는 턴만 분모. 중앙값은
  statistics.median, p90 은 nearest-rank(ceil(0.9n) 번째).
- 값 2 — 상태 줄로 시작하는 질문: `AskUserQuestion` 의 `questions[].question` 마다
  첫 비어 있지 않은 줄(앞뒤 `*`·공백 제거)이 STATUS_RE 와 맞으면 센다. 분모 = 질문 수.
- 값 3 — 여러 질문을 묶은 호출: `questions` 길이 > 1 인 호출 / 질문 수를 셀 수 있는 호출.
  입력이 `__unparsedToolInput.raw` 로만 남은 호출은 그 문자열을 JSON 으로 풀어 쓰고,
  못 풀면 「셀 수 없음」으로 따로 센다.
- 값 4 — 영어 위주 최종 보고: 최종 보고 = 턴의 마지막 보이는 글 블록. 코드 펜스·인라인
  코드·URL·경로·해시를 지운 뒤 한글 글자 H, 로마자 L 을 세어 L >= 20 이고
  H / (H + L) < 0.2 이면 영어 위주. 분모 = 보이는 글이 있는 턴 수.
- 값 5 — ID·해시·코드 토큰이 든 질문: 질문 글이 TOKEN_RES 중 하나와 맞으면 센다.
- devbrew 단위: 그 단위 안에서 ① assistant 항목의 `attributionPlugin` 이 DEVBREW_PLUGINS 중
  하나이거나 ② `Skill` 도구 호출의 `input.skill` 이 `<devbrew 플러그인>:` 로 시작하거나
  ③ 사람 메시지가 `<command-name>/<devbrew 플러그인>:` 슬래시 명령인 것.
  값 2·3·5 는 모든 단위(턴·앞부분·이어짐)의 질문을, 값 1·4 는 턴만 본다.
"""
import argparse
import json
import math
import os
import re
import statistics
import sys
import time

DEVBREW_PLUGINS = ("spec-distill", "quality-gates", "plugin-audit", "project-init")

MACHINE_PREFIXES = (
    "<local-command-stdout>", "<local-command-stderr>", "<local-command-caveat>",
    "<bash-stdout>", "<bash-stderr>", "<task-notification>", "<system-reminder>",
    "[Request interrupted",
)

# 엔진·스킬 틀이 내는 상태 줄의 머리. 출처: docreview_state.py render_gate 첫 줄·둘째 줄,
# 항목 렌더러의 [..] 머리표, quality-pipeline SKILL 의 fix-loop 질문 틀.
STATUS_RE = re.compile(
    r"^(?:"
    r"degrade\b"
    r"|codex 없음"
    r"|「미검증」"
    r"|리뷰 완료 아님"
    r"|리뷰 \d+라운드(?:를 마쳤다)? — "
    r"|리뷰를 마치지 못했다 — "
    r"|- .+ \([0-9a-f]{7,}#r\d+\.\d+(?: · 자동)?\)$"
    r"|라운드 \d+ · 재리뷰"
    r"|(?:qg|Review gate) (?:iter|reached)\b"
    r"|\[(?:decide|ask|fix|미적용|채택|만료|결정)\b"
    r"|\[[0-9a-f]{7,}#r"
    r"|\[\d+/\d+ · "
    r")"
)

TOKEN_RES = (
    ("hash", re.compile(r"(?<![0-9A-Za-z])(?=[0-9a-f]*\d)(?=[0-9a-f]*[a-f])[0-9a-f]{7,40}(?![0-9A-Za-z])")),
    ("finding_id", re.compile(r"#r\d")),
    ("backtick", re.compile(r"`[^`\n]+`")),
    ("label_id", re.compile(r"(?<![A-Za-z0-9])(?:AC|OQ|AP|RC|PR|[A-Z])\d{1,3}(?:\.\d+)?(?![A-Za-z0-9])")),
    ("path", re.compile(r"[\w.-]*[A-Za-z][\w.-]*/[\w./-]*[A-Za-z]|\b\w+\.(?:md|py|sh|js|json|jsonl|ya?ml|tsv)\b")),
    ("snake_ident", re.compile(r"(?<!\w)[a-z][a-z0-9]*_[a-z0-9_]+(?!\w)")),
    ("cli_flag", re.compile(r"(?<![\w-])--[a-z][\w-]+")),
)

_STRIP_RE = re.compile(
    r"```.*?```|`[^`\n]*`|https?://\S+|[\w.~-]*/[\w./-]+|\b[0-9a-f]{7,40}\b", re.S)
_HANGUL_RE = re.compile("[가-힣ᄀ-ᇿ㄰-㆏]")
_LATIN_RE = re.compile("[A-Za-z]")
ENGLISH_MIN_LETTERS = 20
ENGLISH_MAX_HANGUL_SHARE = 0.2


def read_manifest(path):
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()
    if not lines or lines[0].split("\t") != ["path", "size", "mtime"]:
        raise SystemExit("목록 머리가 path\\tsize\\tmtime 이 아니다: %s" % path)
    rows = []
    for n, line in enumerate(lines[1:], 2):
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) != 3:
            raise SystemExit("목록 %d번째 줄의 칸 수가 3이 아니다" % n)
        rows.append((parts[0], int(parts[1]), int(parts[2])))
    return sorted(set(rows))


def text_of_user(content):
    if isinstance(content, str):
        return content
    return "".join(b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text")


def is_tool_result_only(content):
    return (isinstance(content, list) and len(content) > 0
            and all(isinstance(b, dict) and b.get("type") == "tool_result" for b in content))


def is_human(o):
    if o.get("isMeta") or o.get("isCompactSummary") or o.get("isSidechain"):
        return False
    content = (o.get("message") or {}).get("content")
    if content is None or is_tool_result_only(content):
        return False
    origin = o.get("origin")
    if isinstance(origin, dict) and "kind" in origin:
        return origin["kind"] == "human"
    if o.get("promptSource") in ("sdk", "system"):
        return False
    return not text_of_user(content).lstrip().startswith(MACHINE_PREFIXES)


def is_prompt(o):
    """사람이든 아니든 모델에게 새 일을 건넨 user 항목인가(앞부분 단위의 존재 판별용)."""
    content = (o.get("message") or {}).get("content")
    return not (o.get("isMeta") or o.get("isCompactSummary") or content is None
                or is_tool_result_only(content))


_CMD_RE = re.compile(r"<command-name>/?([\w-]+):")


def devbrew_plugin(name):
    return isinstance(name, str) and name.split(":", 1)[0] in DEVBREW_PLUGINS


def parse_auq(inp):
    """질문 목록 또는 None(셀 수 없음)."""
    if not isinstance(inp, dict):
        return None
    if "questions" not in inp and isinstance(inp.get("__unparsedToolInput"), dict):
        try:
            inp = json.loads(inp["__unparsedToolInput"].get("raw"))
        except (TypeError, ValueError):
            return None
    qs = inp.get("questions") if isinstance(inp, dict) else None
    if not isinstance(qs, list):
        return None
    return [q.get("question") if isinstance(q, dict) and isinstance(q.get("question"), str) else "" for q in qs]


def first_line(s):
    for line in s.splitlines():
        line = line.strip().strip("*").strip()
        if line:
            return line
    return ""


def english_dominant(text):
    t = _STRIP_RE.sub(" ", text)
    h = len(_HANGUL_RE.findall(t))
    l = len(_LATIN_RE.findall(t))
    return l >= ENGLISH_MIN_LETTERS and h / (h + l) < ENGLISH_MAX_HANGUL_SHARE


class Unit:
    __slots__ = ("kind", "devbrew", "has_assistant", "texts", "questions")

    def __init__(self, kind):
        self.kind = kind            # turn | prefix | continued
        self.devbrew = False
        self.has_assistant = False
        self.texts = []
        self.questions = []         # list of per-call question lists (None = 셀 수 없음)


def scan(rows):
    seen = set()
    units = []
    acct = {"files_listed": len(rows), "files_read": 0, "files_changed": [], "files_missing": [],
            "bad_json_lines": 0, "dup_entries_skipped": 0}
    for path, size, mtime in rows:
        try:
            st = os.stat(path)
        except FileNotFoundError:
            acct["files_missing"].append(path)
            continue
        if st.st_size != size or int(st.st_mtime) != mtime:
            acct["files_changed"].append(path)
            continue
        acct["files_read"] += 1
        cur = None
        with open(path, encoding="utf-8") as f:
            for line in f:
                try:
                    o = json.loads(line)
                except ValueError:
                    acct["bad_json_lines"] += 1
                    continue
                if not isinstance(o, dict) or o.get("type") not in ("user", "assistant"):
                    continue
                uid = o.get("uuid")
                dup = uid in seen
                if uid is not None:
                    seen.add(uid)
                if o["type"] == "user":
                    human = is_human(o)
                    if dup:
                        acct["dup_entries_skipped"] += 1
                        if human:
                            cur = Unit("continued")
                            units.append(cur)
                        continue
                    if human:
                        cur = Unit("turn")
                        units.append(cur)
                        m = _CMD_RE.search(text_of_user(o["message"]["content"]))
                        if m and m.group(1) in DEVBREW_PLUGINS:
                            cur.devbrew = True
                    elif cur is None and is_prompt(o):
                        cur = Unit("prefix")
                        units.append(cur)
                    continue
                if dup:
                    acct["dup_entries_skipped"] += 1
                    continue
                if cur is None:
                    cur = Unit("prefix")
                    units.append(cur)
                msg = o.get("message") or {}
                if devbrew_plugin(o.get("attributionPlugin")):
                    cur.devbrew = True
                if o.get("isApiErrorMessage") or msg.get("model") == "<synthetic>":
                    continue
                cur.has_assistant = True
                for b in msg.get("content") or []:
                    if not isinstance(b, dict):
                        continue
                    if b.get("type") == "text":
                        cur.texts.append(b.get("text") or "")
                    elif b.get("type") == "tool_use":
                        if b.get("name") == "Skill" and devbrew_plugin((b.get("input") or {}).get("skill")):
                            cur.devbrew = True
                        elif b.get("name") == "AskUserQuestion":
                            cur.questions.append(parse_auq(b.get("input")))
    return units, acct


def pct(a, b):
    return None if b == 0 else round(100.0 * a / b, 1)


def summarize(units):
    turns = [u for u in units if u.kind == "turn" and u.has_assistant]
    lengths = sorted(sum(len(t) for t in u.texts) for u in turns)
    with_text = [u for u in turns if u.texts]
    finals = [u.texts[-1] for u in with_text]
    eng = sum(1 for t in finals if english_dominant(t))
    calls = [c for u in units for c in u.questions]
    countable = [c for c in calls if c is not None]
    qs = [q for c in countable for q in c]
    status = sum(1 for q in qs if STATUS_RE.match(first_line(q)))
    tok_any = 0
    tok_by = {name: 0 for name, _ in TOKEN_RES}
    for q in qs:
        hit = False
        for name, rx in TOKEN_RES:
            if rx.search(q):
                tok_by[name] += 1
                hit = True
        tok_any += hit
    n = len(lengths)
    return {
        "turns": n,
        "turns_zero_text": n - len(with_text),
        "v1_turn_text_median": statistics.median(lengths) if n else None,
        "v1_turn_text_p90": lengths[math.ceil(0.9 * n) - 1] if n else None,
        "v1_turn_text_total": sum(lengths),
        "v1_final_text_total": sum(len(t) for t in finals),
        "v2_status_first_line": [status, len(qs), pct(status, len(qs))],
        "v3_multi_question_calls": [sum(1 for c in countable if len(c) > 1), len(countable),
                                    pct(sum(1 for c in countable if len(c) > 1), len(countable))],
        "v3_uncountable_calls": len(calls) - len(countable),
        "v4_english_final_reports": [eng, len(finals), pct(eng, len(finals))],
        "v5_token_questions": [tok_any, len(qs), pct(tok_any, len(qs))],
        "v5_token_by_class": tok_by,
    }


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("manifest")
    args = ap.parse_args(argv)
    t0 = time.monotonic()
    units, acct = scan(read_manifest(args.manifest))
    out = {
        "accounting": dict(acct, units={k: sum(1 for u in units if u.kind == k)
                                        for k in ("turn", "prefix", "continued")}),
        "all": summarize(units),
        "devbrew": summarize([u for u in units if u.devbrew]),
    }
    ch, gone = len(acct["files_changed"]), len(acct["files_missing"])
    if ch or gone:
        print("목록 %d개 중 %d개를 읽었다. 크기·시각이 바뀐 %d개와 사라진 %d개는 읽지 않았다."
              % (acct["files_listed"], acct["files_read"], ch, gone))
    else:
        print("목록 %d개를 모두 읽었다." % acct["files_listed"])
    print(json.dumps(out, ensure_ascii=False, sort_keys=True, indent=1))
    print("걸린 시간 %.1f초" % (time.monotonic() - t0), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
