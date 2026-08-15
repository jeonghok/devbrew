#!/usr/bin/env python3
"""A/B 판정 단계(AC29) — 러너가 만든 out/<RUN>/ 산출물을 읽어 게이트 7개를 판정한다.

**실행하지 않는다.** 워커를 부르지 않고 산출물만 읽는다. 판정자 호출만이
외부 모델을 부르는 지점이다.

Usage:
    python3 ab_judge.py <out/RUN 디렉토리>
Exit:
    0 = 일곱 게이트 모두 통과 · 1 = 하나 이상 실패(어느 게이트가 왜인지 출력)
"""
from __future__ import annotations

import glob
import json
import os
import re
import subprocess
import sys

QUESTIONS = ("Q1", "Q2", "Q3", "Q4")
PLUGIN_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# 판정자 호출 한도(초) — 없으면 hang 이 머지 게이트를 영원히 막는다. 만료도
# 파싱 실패와 같은 취급이다: fail-closed 로 그 표를 no 로 계산한다.
JUDGE_TIMEOUT_S = int(os.environ.get("AB_JUDGE_TIMEOUT_S", "600"))


def expected_runs():
    """분모를 **먼저** 고정한다. 3/3 의 분모는 언제나 3이다."""
    runs = [(cond, task, i)
            for i in (1, 2, 3) for task in ("a", "b", "c", "d") for cond in ("off", "on")]
    runs += [("on", "e", i) for i in (1, 2, 3)]
    return runs


def parse_index(text):
    """`<cond> <task> <i> <sid> worker_rc=<n>` 및 플래그 줄.

    `snapshot=ambiguous(N)` 줄은 예외적으로 **4 토큰**이다 (`<cond> <task>
    <i> snapshot=ambiguous(N)` — sid 자리가 아예 없다). 그 외 모든 형태는
    5 토큰이다 (sid 또는 `-` 자리표시자를 담는다). 최소폭 검사(`< 4`)를
    써야 이 더 짧은 형태가 버려지지 않는다 — `!= 5` 였다면 실제 러너가
    내는 ambiguous 줄이 통째로 무시됐을 것이다.
    """
    parsed = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 4:
            continue
        cond, task = parts[0], parts[1]
        try:
            index = int(parts[2])
        except ValueError:
            continue
        entry = {"sid": None, "worker_rc": None, "flag": None}
        for token in parts[3:]:
            if token.startswith("worker_rc="):
                try:
                    entry["worker_rc"] = int(token.split("=", 1)[1])
                except ValueError:
                    entry["worker_rc"] = None
            elif "=" in token:
                entry["flag"] = token
            elif token != "-":
                entry["sid"] = token
        prior = parsed.get((cond, task, index))
        if prior and prior.get("flag") and entry["flag"] is None:
            entry["flag"] = prior["flag"]
        parsed[(cond, task, index)] = entry
    return parsed


def is_failed(parsed, key):
    """대응 줄이 없거나 · worker_rc 가 0 이 아니거나 · 필드 자체가 없으면 fail."""
    entry = parsed.get(key)
    if entry is None:
        return True
    # `flag` 는 None 일 수 있다 — `.get("flag", "")` 는 **키가 있고 값이 None** 인
    # 경우 None 을 그대로 돌려주므로 `or ""` 가 필요하다.
    flag = entry.get("flag") or ""
    if flag in ("setup=failed", "setup=skipped"):
        return True
    if flag.startswith("snapshot=ambiguous"):
        return True
    return entry.get("worker_rc") != 0


def transcript_for(sid):
    """정확히 1개가 아니면 그 실행은 모든 게이트 fail 이다.

    한 세션이 두 슬러그 디렉토리에 걸리는 상황이 실측으로 확인됐으므로,
    규칙이 없으면 어느 파일에서 구간을 잘랐는지가 미정으로 남는다.
    """
    hits = glob.glob(os.path.expanduser("~/.claude/projects/*/%s.jsonl" % sid))
    return hits[0] if len(hits) == 1 else None


def read_records(path):
    records = []
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except ValueError:
                pass
    return records


def _items(record):
    message = record.get("message")
    content = message.get("content") if isinstance(message, dict) else None
    return content if isinstance(content, list) else []


def _text_of(record):
    if record.get("type") != "assistant":
        return ""
    parts = [i.get("text") or "" for i in _items(record)
             if isinstance(i, dict) and i.get("type") == "text"]
    return "\n".join(p for p in parts if p.strip())


def text_blocks(records):
    return [{"index": n, "text": _text_of(r)}
            for n, r in enumerate(records) if _text_of(r).strip()]


def span_after_tool(records, tool_name):
    """게이트 3 — 도구 결과 레코드 직후 첫 **텍스트 블록을 담은** 어시스턴트 메시지.

    어시스턴트 레코드는 text·thinking·tool_use 중 하나만 담는 경우가 많다 —
    "결과 직후 다음 레코드"는 3분의 2 확률로 텍스트 없는 레코드에 착지하므로
    텍스트를 담을 때까지 건너뛴다.
    """
    call_ids = set()
    for record in records:
        for item in _items(record):
            if isinstance(item, dict) and item.get("type") == "tool_use" \
                    and item.get("name") == tool_name:
                call_ids.add(item.get("id"))
    for n, record in enumerate(records):
        got_result = any(isinstance(i, dict) and i.get("type") == "tool_result"
                         and i.get("tool_use_id") in call_ids for i in _items(record))
        if not got_result:
            continue
        for later in records[n + 1:]:
            if _text_of(later).strip():
                return _text_of(later)
    return ""


def span_before_ask(records):
    """게이트 4 — AskUserQuestion 호출을 담은 메시지에서 그 호출보다 **앞의**
    텍스트 블록들 + 바로 직전의 텍스트 블록을 담은 어시스턴트 메시지."""
    for n, record in enumerate(records):
        items = _items(record)
        position = None
        for pos, item in enumerate(items):
            if isinstance(item, dict) and item.get("type") == "tool_use" \
                    and item.get("name") == "AskUserQuestion":
                position = pos
                break
        if position is None:
            continue
        head = "\n".join(i.get("text") or "" for i in items[:position]
                         if isinstance(i, dict) and i.get("type") == "text")
        previous = ""
        for earlier in reversed(records[:n]):
            if _text_of(earlier).strip():
                previous = _text_of(earlier)
                break
        return "\n".join(x for x in (previous, head) if x.strip())
    return ""


def span_after_command(records, needle):
    """게이트 5a·5b — 명령 호출 직후 첫 텍스트 블록을 담은 어시스턴트 메시지."""
    for n, record in enumerate(records):
        blob = json.dumps(record, ensure_ascii=False)
        if needle not in blob:
            continue
        for later in records[n + 1:]:
            if _text_of(later).strip():
                return _text_of(later)
    return ""


def span_all_text(records):
    """게이트 6 — 모든 텍스트 블록을 시간순으로 이은 것.

    결정이 어느 시점에 일어날지 미리 알 수 없다.
    """
    return "\n\n".join(b["text"] for b in text_blocks(records))


def final_response(records):
    """게이트 1 — 실행의 **최종 응답**: 마지막 텍스트 블록을 담은 어시스턴트 메시지.

    `span_all_text`(게이트 6, 전체 텍스트를 시간순으로 이어붙인 것)와 다르다 —
    판정 구간 표는 게이트 1을 **의도적으로 비워둔다**, 게이트 표 자체(*"최종
    응답이 존재하고 … 그 안에"*)가 유일한 정의이기 때문이다. 중간 메시지의
    표는 게이트 1과 무관하다 — 최종 응답 안에서만 본다.
    """
    blocks = text_blocks(records)
    return blocks[-1]["text"] if blocks else ""


def gate1_ok(records):
    """게이트 1 통과 조건 — 최종 응답이 존재하고 **그 안에** 표 행(`^\\|`)이 0개.

    "존재" 조건은 장식이 아니다 — 없으면 워커가 죽어 아무 응답도 안 낸 실행이
    `rows == 0` 이라는 이유만으로 통과한다.
    """
    response = final_response(records)
    if not response.strip():
        return False
    return len(re.findall(r"(?m)^\|", response)) == 0


def _section(text, heading):
    """`## <heading>` 부터 다음 `## ` 까지 (레벨-2 헤딩 경계).

    `tests/test_ab_runner_contract.py` 의 동명 헬퍼와 같은 규약이다.
    REFERENCE.md 의 루브릭 절은 `###` 이 아니라 `##` — 셋이 아니라 정확히
    둘인 해시 뒤에 이름이 곧바로 오는 형태가 절 경계다(§ "판정 구간 표"
    윗절 "파싱 계약" 참고).
    """
    marker = "## " + heading
    start = text.index(marker)
    rest = text[start + 3:]
    end = rest.find("\n## ")
    return rest if end < 0 else rest[:end]


def load_rubric(reference_text, letter):
    """접두 JSON 지시 한 줄 + `## 루브릭 <letter>` 절의 **펜스 안** 본문만.

    접두 문장은 네 루브릭 절의 부모가 **아니라 형제** 절(`## 루브릭`)에만
    있다 — 상속을 가정하면 조용히 비게 되어 판정자가 JSON 을 낼 이유가
    없어지고, fail-closed 규칙에 따라 모든 표가 `no` 가 되어 게이트
    3·4·5b·6 이 구조적으로 통과 불가능해진다. 접두 문장은 REFERENCE.md 의
    코드펜스에서 직접 읽는다 — 여기 사본을 박으면 정본이 둘이 된다.

    각 루브릭 절 안에는 **사람용 산문**(왜 이 루브릭이 이렇게 생겼는지 설명)과
    **판정자용 블록**(그대로 프롬프트에 들어가는 지시문 + Q1–Q4)이 섞여 있을
    수 있다 — 절 전체를 본문으로 삼으면 그 산문(markdown 링크·"여기서는
    반복하지 않는다" 같은, 문서를 읽는 사람에게만 말이 되는 문장)이 판정자
    프롬프트에 새어 들어간다(루브릭 C 실측). 펜스(```)로 감싼 부분만 판정자용
    블록이라는 계약을 여기서 강제한다 — 펜스가 없으면 그 경계가 없다는
    뜻이므로 조용히 절 전체로 돌아가지 않고 **크게 실패한다**.
    """
    prefix_section = _section(reference_text, "루브릭")
    fences = re.findall(r"```\n(.*?)```", prefix_section, re.S)
    if not fences:
        raise SystemExit("공유 판정 접두 지시문(`## 루브릭` 절)을 찾지 못했다")
    prefix = fences[0].strip()

    rubric_section = _section(reference_text, "루브릭 %s" % letter)
    fences = re.findall(r"```\n(.*?)```", rubric_section, re.S)
    body = ""
    for fence in fences:
        if re.search(r"(?m)^Q1\.", fence):
            body = fence.strip()
            break
    if not body:
        raise SystemExit(
            "루브릭 %s 에 판정자용 펜스(```)가 없다 — 산문과 판정자 "
            "블록의 경계가 없으면 문서-내부 주석이 프롬프트로 샌다" % letter)
    return prefix + "\n" + body


def parse_vote(raw):
    """엄격 JSON 한 줄. 어긋나면 **그 표 전체를 no** 로 계산한다."""
    fallback = dict((q, "no") for q in QUESTIONS)
    text = (raw or "").strip()
    if not text:
        return fallback
    seen = []

    def hook(pairs):
        seen.extend(k for k, _ in pairs)
        return dict(pairs)

    try:
        data = json.loads(text, object_pairs_hook=hook)
    except ValueError:
        return fallback
    if not isinstance(data, dict):
        return fallback
    if len(seen) != len(set(seen)):          # 중복 키
        return fallback
    if set(data) != set(QUESTIONS):          # 누락 · 추가
        return fallback
    if any(data[q] not in ("yes", "no") for q in QUESTIONS):
        return fallback
    return dict((q, data[q]) for q in QUESTIONS)


def tally(votes):
    """문항별 다수결(2/3) 후 **모든 문항이 yes** 여야 통과."""
    if not votes:
        return False
    for question in QUESTIONS:
        yes = len([v for v in votes if v.get(question) == "yes"])
        if yes * 2 <= len(votes):
            return False
    return True


def _all_no(error):
    """fail-closed 표 + **왜 no 인지**의 표시.

    `_error` 는 판정 키가 아니라 메타다 — `tally` 는 `QUESTIONS` 만 순회하므로
    집계에 끼어들지 않는다. 이 마커가 없으면 *"판정자가 안 돌았다"* 와
    *"산출물이 루브릭에 떨어졌다"* 가 같은 표로 보고되어, CLI 부재·인증 오류·
    rate limit 이 산출물 결함으로 읽힌다.
    """
    vote = dict((q, "no") for q in QUESTIONS)
    vote["_error"] = error
    # 강등이 사람에게 안 닿으면 그것은 강등이 아니라 통과다(설계 §7). 디스크에만
    # 남기면 실행 중에는 안 보이고, 게이트가 왜 떨어졌는지 사후에야 알게 된다.
    sys.stderr.write("[ab_judge] 판정자 호출 실패 — 표를 no 로 계산한다 (%s)\n" % error)
    return vote


def ask_judge(rubric, block, model, effort):
    prompt = "%s\n\n%s" % (rubric, block)
    try:
        proc = subprocess.run(
            ["claude", "-p", "--model", model, "--effort", effort, prompt],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            timeout=JUDGE_TIMEOUT_S)
    except (OSError, subprocess.TimeoutExpired) as exc:
        # hang 도 파싱 실패와 같은 취급 — 표를 통째로 no 로 계산한다(fail-closed).
        return _all_no(type(exc).__name__)
    if proc.returncode != 0:
        return _all_no("rc=%d" % proc.returncode)
    return parse_vote(proc.stdout.decode("utf-8", "replace"))


def wrap_two_blocks(inventory, answer):
    """게이트 5b 의 두-블록 구간. **어느 한쪽이라도 비면 빈 문자열**을 돌려준다.

    라벨을 먼저 붙이면 감싼 문자열이 절대 비지 않아 `judge_span` 의 빈-구간
    가드가 이 게이트에서는 영영 발동하지 못한다 — 인벤토리도 응답도 없는 실행이
    판정자에게 라벨만 주고 그 답이 판정이 된다(리뷰가 적발). 인벤토리가 없으면
    루브릭 C 의 Q2(*"총수 대비 몇 개를 읽었나"*)를 **근거 없이** 묻게 되는데,
    그것이 REFERENCE.md 가 일어나면 안 된다고 적은 바로 그 조건이다.
    """
    if not (inventory or "").strip() or not (answer or "").strip():
        return ""
    return "<인벤토리>\n%s\n\n<응답>\n%s" % (inventory, answer)


def judge_span(rubric, block, model, effort, artifacts=None, label=""):
    if not block.strip():
        return False                          # 구간이 비면 fail — 설명이 없었다는 뜻이다
    votes = [ask_judge(rubric, block, model, effort) for _ in range(3)]
    verdict = tally(votes)
    _preserve(artifacts, label, block, votes, verdict)
    return verdict


def _preserve(artifacts, label, block, votes, verdict):
    """판정 구간과 표를 디스크에 남긴다.

    REFERENCE.md 가 실패한 원자료 보존을 요구하는데 앞선 판은 구간도 표도
    버렸다 — fail 이 난 뒤 무엇을 보고 판정했는지 되짚을 방법이 없었다(리뷰가
    적발). 보존 실패가 판정을 막으면 안 되므로 조용히 넘어가되, 그때는
    판정 결과 자체는 이미 반환값으로 살아 있다.
    """
    if not artifacts:
        return
    try:
        os.makedirs(artifacts, exist_ok=True)
        safe = re.sub(r"[^A-Za-z0-9_.-]", "_", label) or "span"
        with open(os.path.join(artifacts, "%s.txt" % safe), "w",
                  encoding="utf-8") as fh:
            fh.write("verdict=%s\n\n--- 판정 구간 ---\n%s\n\n--- 표 ---\n%s\n"
                     % (verdict, block, json.dumps(votes, ensure_ascii=False, indent=2)))
    except OSError:
        pass


def main(argv):
    if len(argv) != 2:
        raise SystemExit("usage: ab_judge.py <out/RUN>")
    out = argv[1]
    manifest = dict(
        line.split("=", 1) for line in
        open(os.path.join(out, "manifest.txt"), encoding="utf-8").read().splitlines()
        if "=" in line)
    model, effort = manifest["judge_model"], manifest["judge_effort"]
    reference = open(os.path.join(PLUGIN_DIR, "REFERENCE.md"), encoding="utf-8").read()
    rubrics = dict((letter, load_rubric(reference, letter)) for letter in "ABCD")

    index_path = os.path.join(out, "index.txt")
    parsed = parse_index(open(index_path, encoding="utf-8").read()
                         if os.path.exists(index_path) else "")
    tests_text = ""
    tests_path = os.path.join(out, "tests.txt")
    if os.path.exists(tests_path):
        tests_text = open(tests_path, encoding="utf-8").read()

    artifacts = os.path.join(out, "judge")
    results, reasons = {}, []

    def note(gate, ok, why):
        results[gate] = results.get(gate, True) and ok
        if not ok:
            reasons.append("게이트 %s: %s" % (gate, why))

    for cond, task, i in expected_runs():
        key = (cond, task, i)
        failed = is_failed(parsed, key)
        sid = (parsed.get(key) or {}).get("sid")
        path = transcript_for(sid) if (sid and not failed) else None
        if sid and not failed and path is None:
            failed = True
            reasons.append("lookup=ambiguous: %s" % (key,))
        records = read_records(path) if path else []

        if task == "a" and cond == "on":
            rows = len(re.findall(r"(?m)^\|", final_response(records)))
            note(1, (not failed) and gate1_ok(records),
                 "%s — 최종 응답 부재 또는 표 행 %d개" % (key, rows))
        if task == "b":
            visible = "%s %d visible=0" % (cond, i) in tests_text
            oracle = "%s %d oracle=0" % (cond, i) in tests_text
            intact = "%s %d hash=ok" % (cond, i) in tests_text
            note(2, (not failed) and visible and oracle and intact,
                 "%s — visible=%s oracle=%s hash=%s" % (key, visible, oracle, intact))
        if task == "c" and cond == "on":
            note(3, (not failed) and judge_span(
                rubrics["A"], span_after_tool(records, "Agent"), model, effort,
                artifacts, "3-%s" % i), str(key))
        if task == "d" and cond == "on":
            note(4, (not failed) and judge_span(
                rubrics["B"], span_before_ask(records), model, effort,
                artifacts, "4-%s" % i), str(key))
        if task == "b" and cond == "on":
            note(6, (not failed) and judge_span(
                rubrics["D"], span_all_text(records), model, effort,
                artifacts, "6-%s-%s" % (cond, i)), str(key))
        if task == "e":
            answer = span_after_command(records, "agent-transparency:standup")
            snapshot = os.path.join(out, "pre-standup-%d.jsonl" % i)
            questions = []
            if os.path.exists(snapshot):
                for record in read_records(snapshot):
                    for item in _items(record):
                        if isinstance(item, dict) and item.get("type") == "tool_use" \
                                and item.get("name") == "AskUserQuestion":
                            for q in (item.get("input") or {}).get("questions") or []:
                                if isinstance(q, dict) and q.get("question"):
                                    questions.append(q["question"])
            quoted = [q for q in questions if q and q in answer]
            note("5a", (not failed) and len(quoted) >= 1,
                 "%s — 인용된 결정 질문 %d건" % (key, len(quoted)))
            inventory = ""
            for record in records:
                blob = json.dumps(record, ensure_ascii=False)
                if "scope:   repo=" in blob:
                    inventory = blob
                    break
            two_blocks = wrap_two_blocks(inventory, answer)
            note("5b", (not failed) and judge_span(
                     rubrics["C"], two_blocks, model, effort, artifacts, "5b-%s" % i),
                 "%s — 인벤토리 %s · 응답 %s"
                 % (key, "있음" if inventory.strip() else "**없음**",
                    "있음" if answer.strip() else "**없음**"))

    for gate in (1, 2, 3, 4, "5a", "5b", 6):
        results.setdefault(gate, False)
        print("gate %s: %s" % (gate, "PASS" if results[gate] else "FAIL"))
    for reason in reasons:
        print("  - %s" % reason)
    return 0 if all(results.values()) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
