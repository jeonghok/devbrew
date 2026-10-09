# -*- coding: utf-8 -*-
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import measure_output as mo  # noqa: E402

_n = [0]


def _uid():
    _n[0] += 1
    return "u%04d" % _n[0]


def human(text, **kw):
    o = {"type": "user", "uuid": _uid(), "origin": {"kind": "human"}, "message": {"role": "user", "content": text}}
    o.update(kw)
    return o


def user_raw(content, **kw):
    o = {"type": "user", "uuid": _uid(), "message": {"role": "user", "content": content}}
    o.update(kw)
    return o


def tool_result():
    return user_raw([{"type": "tool_result", "tool_use_id": "t", "content": "ok"}])


def asst(*blocks, **kw):
    o = {"type": "assistant", "uuid": _uid(), "message": {"role": "assistant", "model": "m", "content": list(blocks)}}
    o.update(kw)
    return o


def text(s):
    return {"type": "text", "text": s}


def tool(name, inp):
    return {"type": "tool_use", "id": "t", "name": name, "input": inp}


def auq(*questions):
    return tool("AskUserQuestion", {"questions": [{"question": q, "header": "h", "options": [], "multiSelect": False}
                                                  for q in questions]})


class Corpus:
    def __init__(self, tmp):
        self.dir = Path(tmp)
        self.rows = []

    def file(self, name, entries, listed=True):
        p = self.dir / name
        p.write_text("".join(json.dumps(e, ensure_ascii=False) + "\n" for e in entries), encoding="utf-8")
        if listed:
            st = os.stat(p)
            self.rows.append("%s\t%d\t%d" % (p, st.st_size, int(st.st_mtime)))
        return p

    def manifest(self):
        m = self.dir / "manifest.tsv"
        m.write_text("path\tsize\tmtime\n" + "\n".join(self.rows) + "\n", encoding="utf-8")
        return str(m)

    def measure(self):
        units, acct = mo.scan(mo.read_manifest(self.manifest()))
        return mo.summarize(units), mo.summarize([u for u in units if u.devbrew]), acct


class TurnDefinition(unittest.TestCase):
    def test_only_human_messages_open_turns(self):
        with tempfile.TemporaryDirectory() as tmp:
            c = Corpus(tmp)
            c.file("a.jsonl", [
                {"type": "attachment", "uuid": _uid()},
                human("첫 질문"),
                asst(text("가" * 10)),
                asst(tool("Bash", {"command": "ls"})),
                tool_result(),                                                     # 경계 아님
                user_raw("Base directory for this skill: x", isMeta=True),         # 경계 아님
                user_raw("handback", origin={"kind": "peer"}, promptSource="system"),  # 경계 아님
                user_raw("<task-notification>done</task-notification>",
                         origin={"kind": "task-notification"}),                    # 경계 아님
                asst(text("나" * 30)),
                asst(text("API Error"), isApiErrorMessage=True),                   # 보이는 글에서 뺀다
                asst(text("No response requested."), message={"model": "<synthetic>", "content": [text("x" * 99)]}),
                user_raw("<command-name>/model</command-name>"),                   # 사람(로컬 명령) — 응답 없음
                user_raw("<local-command-stdout>set</local-command-stdout>"),      # 기계
                user_raw("/compact 보존할 것"),                                      # origin 없는 사람 글
                user_raw("This session is being continued", isCompactSummary=True),
                human("둘째 질문"),
                asst(text("다" * 5)),
            ])
            all_, _, acct = c.measure()
        self.assertEqual(all_["turns"], 2)                     # 응답 없는 /model · /compact 턴은 분모 밖
        self.assertEqual(all_["v1_turn_text_total"], 45)
        self.assertEqual(all_["v1_turn_text_median"], 22.5)
        self.assertEqual(all_["v1_final_text_total"], 35)      # 턴의 마지막 text 블록 30 + 5

    def test_sdk_session_has_no_turns_and_dup_uuid_counted_once(self):
        with tempfile.TemporaryDirectory() as tmp:
            c = Corpus(tmp)
            c.file("sdk.jsonl", [user_raw("run", promptSource="sdk", entrypoint="sdk-py"), asst(text("z" * 50))])
            shared_h, shared_a = human("q"), asst(text("a" * 7))
            c.file("orig.jsonl", [shared_h, shared_a])
            c.file("resumed.jsonl", [shared_h, shared_a, asst(text("b" * 3)), human("q2"), asst(text("c"))])
            all_, _, acct = c.measure()
        self.assertEqual(all_["turns"], 2)                     # sdk 0 · 원본 1 · 이어진 파일의 q2 1
        self.assertEqual(acct["dup_entries_skipped"], 2)
        self.assertEqual(all_["v1_turn_text_total"], 8)        # 이어짐 단위의 "bbb" 는 턴이 아니다


class ManifestPinning(unittest.TestCase):
    def test_unlisted_file_does_not_change_values_and_changed_file_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            c = Corpus(tmp)
            c.file("a.jsonl", [human("q"), asst(text("a" * 4))])
            before = c.measure()[0]
            c.file("extra.jsonl", [human("q"), asst(text("e" * 400))], listed=False)
            self.assertEqual(c.measure()[0], before)
            grown = c.file("b.jsonl", [human("q"), asst(text("b" * 9))])
            with open(grown, "a", encoding="utf-8") as f:
                f.write(json.dumps(asst(text("late"))) + "\n")
            c.rows.append("%s\t1\t1" % (Path(tmp) / "gone.jsonl"))
            all_, _, acct = c.measure()
        self.assertEqual(all_, before)
        self.assertEqual(acct["files_changed"], [str(grown)])
        self.assertEqual(acct["files_missing"], [str(Path(tmp) / "gone.jsonl")])


class QuestionValues(unittest.TestCase):
    def test_new_render_first_lines_count_as_status(self):
        with tempfile.TemporaryDirectory() as tmp:
            c = Corpus(tmp)
            c.file("a.jsonl", [
                human("q"),
                asst(auq("리뷰 2라운드를 마쳤다 — 정할 것 1개가 남았다. 경고 없음.\n무엇을 할까?",
                         "「미검증」 리뷰어(doc-critic)가 결과를 내지 못해 이 라운드는 리뷰되지 않았다. 리뷰 1라운드.",
                         "- §5 에 TBD 가 남아 있다 — 고치거나 버린다(drop) (9dea7cf3#r1.1)\n이것부터 고칠까?",
                         "이 절을 고칠까?")),
            ])
            all_, _, _ = c.measure()
        self.assertEqual(all_["v2_status_first_line"][:2], [3, 4])

    def test_status_multi_tokens_and_unparsed(self):
        raw = json.dumps({"questions": [{"question": "평범한 질문"}, {"question": "또 하나"}]})
        with tempfile.TemporaryDirectory() as tmp:
            c = Corpus(tmp)
            c.file("a.jsonl", [
                human("q"),
                asst(auq("degrade 없음 · 라운드 1 · 재리뷰 0/2\n무엇을 할까요?")),        # 상태 줄
                asst(auq("**[decide] 3720b2b7#r1.1 — 요약**", "이 설계로 갈까요?")),        # 상태 + 토큰, 2문항
                asst(auq("어느 쪽으로 할까요?\ndegrade 없음")),                             # 첫 줄이 아니면 아님
                asst(auq("`ask_open` 칸을 볼까요?")),                                      # 토큰만
                asst(tool("AskUserQuestion", {"__unparsedToolInput": {"raw": raw, "len": 9}})),
                asst(tool("AskUserQuestion", {"__unparsedToolInput": {"raw": "{\"questions\": [", "len": 9}})),
            ])
            all_, _, _ = c.measure()
        self.assertEqual(all_["v2_status_first_line"][:2], [2, 7])
        self.assertEqual(all_["v3_multi_question_calls"][:2], [2, 5])
        self.assertEqual(all_["v3_uncountable_calls"], 1)
        self.assertEqual(all_["v5_token_questions"][:2], [2, 7])
        self.assertEqual(all_["v5_token_by_class"]["hash"], 1)
        self.assertEqual(all_["v5_token_by_class"]["finding_id"], 1)


class FinalReportAndDevbrew(unittest.TestCase):
    def test_english_final_report_and_devbrew_signals(self):
        eng = "The review finished and all checks passed without any findings."
        kor = "리뷰가 끝났고 고칠 곳은 없습니다. `quality-gates` 의 결과를 그대로 씁니다."
        with tempfile.TemporaryDirectory() as tmp:
            c = Corpus(tmp)
            c.file("a.jsonl", [
                human("<command-message>quality-gates:qg</command-message>\n<command-name>/quality-gates:qg</command-name>"),
                asst(text(kor), text(eng)),                                  # 최종 = 마지막 블록 → 영어
                human("하나 더"),
                asst(tool("Skill", {"skill": "spec-distill:reviewing-spec"})),
                asst(text(kor)),
                human("또"),
                asst(text("ok"), attributionPlugin="project-init"),          # 글자 20 미만 → 영어 아님
                human("superpowers 만"),
                asst(tool("Skill", {"skill": "superpowers:brainstorming"}), attributionPlugin="superpowers"),
                asst(text(eng)),
            ])
            all_, dev, _ = c.measure()
        self.assertEqual(all_["v4_english_final_reports"][:2], [2, 4])
        self.assertEqual(dev["turns"], 3)                                    # 슬래시 명령 · Skill · attribution
        self.assertEqual(dev["v4_english_final_reports"][:2], [1, 3])


if __name__ == "__main__":
    unittest.main()
