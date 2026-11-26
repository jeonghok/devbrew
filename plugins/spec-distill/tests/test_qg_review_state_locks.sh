#!/usr/bin/env bash
# 머지 앞 qg 리뷰 상태 — 설계 §8 의 락 다섯(AC21). 락마다 한 쪽의 글자를 다른 쪽이 쓰는 이름과 견준다:
#   1 gate-call · 2 team-sentences · 3 reason-words · 4 qg-file-shape · 5 no-paths-to-reviewed.
# 스크립트 쪽 이름은 모듈을 import 하거나 그 코드를 ast 로 읽어 얻는다(이름이 바뀌면 락이 깨진다).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_qg_review_state_locks.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"

T="$(mktemp -d "${TMPDIR:-/tmp}/qg-review-locks.XXXXXX")" || { no "임시 폴더를 만들지 못했다"; finish; exit $?; }
[ -n "$T" ] && [ -d "$T" ] || { no "임시 폴더 경로가 비었다"; finish; exit $?; }
trap 'rm -rf "$T"' EXIT

cat > "$T/locks.py" <<'PY'
import ast
import re
import subprocess
import sys
import tempfile
import traceback
from pathlib import Path

ROOT = Path(sys.argv[1])
SD = ROOT / "plugins" / "spec-distill"
QG = ROOT / "plugins" / "quality-gates"
sys.path[:0] = [str(SD / "scripts"), str(QG / "scripts")]

CONDUCTING = SD / "references" / "conducting.md"
QG_REVIEW = SD / "skills" / "epic-conductor" / "references" / "qg-review.md"
STATE_FMT = QG / "skills" / "quality-pipeline" / "references" / "state-file-format.md"
ARCHIVE_PY = SD / "scripts" / "qg_review_archive.py"


def say(kind, msg):
    print("%s %s" % (kind, " ".join(str(msg).split())))


def check(cond, msg, detail=""):
    say("OK" if cond else "NO", msg if cond or not detail else "%s — %s" % (msg, detail))
    return cond


def read(path):
    with open(str(path), "r", encoding="utf-8") as fh:
        return fh.read()


def heading_body(text, head):
    """머리 줄 `head` 아래 줄들 — 같거나 높은 단계의 다음 머리까지. 펜스 안의 `#` 줄은 머리가 아니다."""
    level = len(head) - len(head.lstrip("#"))
    out, inside, fence = None, False, False
    for line in text.split("\n"):
        if line.startswith("```"):
            fence = not fence
        if not fence and line.startswith("#"):
            lv = len(line) - len(line.lstrip("#"))
            if inside and lv <= level and line[lv:lv + 1] == " ":
                break
            if line == head or (head.endswith("*") and line.startswith(head[:-1])):
                inside, out = True, []
                continue
        if inside:
            out.append(line)
    return out or []


def line_starting(lines, lead):
    got = [x for x in lines if x.startswith(lead)]
    return got[0] if got else ""


def fences(lines):
    """줄 목록의 펜스 본문들(펜스 줄 제외)."""
    out, body = [], None
    for line in lines:
        if line.startswith("```"):
            if body is None:
                body = []
            else:
                out.append(body)
                body = None
            continue
        if body is not None:
            body.append(line)
    return out


def ticks(text):
    """백틱으로 싼 글들."""
    return re.findall("`([^`\n]+)`", text)


# ---------------------------------------------------------------- 1 gate-call

def lock_gate_call():
    import qg_review_state as S
    helped = subprocess.run([sys.executable, str(SD / "scripts" / "qg_review_state.py"), "--help"],
                            capture_output=True, text=True)
    m = re.search("[{]([a-z,]+)[}]", helped.stdout)
    subs = set(m.group(1).split(",")) if m else set()
    check(len(subs) >= 2, "qg_review_state.py --help 가 하위 명령 목록을 낸다", helped.stdout[:200])
    for name in ("gate", "next"):
        check(name in subs, "하위 명령 `%s` 가 --help 에 있다" % name, sorted(subs))
    text = read(CONDUCTING)
    gate_before_suite = re.compile("스위트 대조[^.\n]{0,40}(?:앞|전)[^.\n]{0,40}qg_review_state[.]py gate`")
    step5 = "\n".join(heading_body(text, "### 5. 머지 전 확인"))
    team = heading_body(text, "## team 형식 로드맵")
    team_pr = line_starting(team, "- **PR 전 확인.**")
    manual = heading_body(text, "## 손으로 따르는 절차")
    manual8 = line_starting(manual, "   - **머지 앞 qg 리뷰.**")
    for where, body in (("지휘 순환 걸음 5(옛 형식)", step5), ("team 형식 「PR 전 확인」", team_pr),
                        ("손 절차 8 「머지 앞 qg 리뷰」", manual8)):
        check(body != "", "%s 문장을 읽었다" % where)
        check(bool(gate_before_suite.search(body)),
              "%s — 스위트 대조 앞에서 `qg_review_state.py gate` 를 부른다" % where)
    step1 = "\n".join(heading_body(text, "### 1. 맞추기"))
    manual1 = line_starting(manual, "1. **맞추기.**")
    for where, body in (("지휘 순환 걸음 1", step1), ("손 절차 1", manual1)):
        check(body != "", "%s 문장을 읽었다" % where)
        check("qg_review_state.py next`" in body, "%s — 다시 들어오면 `qg_review_state.py next` 를 부른다" % where)
    check(S.__name__ == "qg_review_state", "상태 스크립트를 import 했다")


# ---------------------------------------------------------------- 2 team-sentences

def lock_team_sentences():
    import qg_review_file as F
    import qg_review_state as S
    text = read(CONDUCTING)
    qr = read(QG_REVIEW)
    team_qg = line_starting(heading_body(text, "## team 형식 로드맵"), "- **검수 걸음의 qg.**")
    check(team_qg != "", "team 형식 「검수 걸음의 qg」 문장을 읽었다")
    m = re.search("「([^」]+)」 는 옛 형식과 같", team_qg)
    name = m.group(1) if m else ""
    check(name != "", "team 형식 — 「…」 는 옛 형식과 같다는 문장이 있다")
    check(name == S.ASK_TWO_MAX, "그 이름이 스크립트의 질문 종류(ASK_TWO_MAX)와 같다", "%r != %r" % (name, S.ASK_TWO_MAX))
    check(name in F.ASK_KINDS, "그 이름이 상태 파일의 질문 종류(ASK_KINDS)에 있다")
    check(any(x.startswith("- **%s.**" % name) for x in heading_body(qr, "## 되돌리기")),
          "qg-review.md 「되돌리기」 에 옛 형식의 「%s」 규칙이 있다" % name)
    check(bool(re.search("다시 보낸 시도가 돌아온 때에는[^.]{0,40}기본 브랜치 합치기를 하지 않는다", team_qg)),
          "team 형식 — 반려로 다시 보낸 시도가 돌아오면 기본 브랜치 합치기를 하지 않는다")
    m = re.search("대상은 `([^`]+)`", team_qg)
    target_shape = m.group(1) if m else ""
    m = re.search("자리 글자는 `([^`]+)` · `([^`]+)`", team_qg)
    tag_shapes = list(m.groups()) if m else []
    check(target_shape != "" and len(tag_shapes) == 2, "team 형식 — 대상 꼴과 자리 글자 꼴 둘을 읽었다")

    def fill(shape):
        return shape.replace("<과제>", "auth-fix").replace("<n>", "2")

    target = fill(target_shape)
    check(bool(F.TARGET_RE.fullmatch(target)), "문서의 대상 예(%s)를 스크립트의 대상 꼴이 받는다" % target)
    check(not S.OLD_TARGET_RE.fullmatch(target), "그 대상은 옛 형식(pr<번호>)이 아니라 team 형식으로 갈린다")
    check(not F.TARGET_RE.fullmatch(target.rsplit("-plan", 1)[0]),
          "계획 번호 없는 대상(%s)은 대상 꼴이 받지 않는다" % target.rsplit("-plan", 1)[0])
    for shape in tag_shapes:
        site = shape.split("-", 1)[0]
        check(site in F.SITES, "자리 글자 꼴 %s 의 자리(%s)가 스크립트의 자리에 있다" % (shape, site))
        check(S.site_tag(site, target) == fill(shape),
              "스크립트가 짓는 자리 글자가 문서의 꼴과 같다(%s)" % fill(shape),
              "%r != %r" % (S.site_tag(site, target), fill(shape)))
    team_para = line_starting(qr.split("\n"), "**team 형식 로드맵.**")
    check(team_para != "", "qg-review.md 의 team 형식 문단을 읽었다")
    for shape in tag_shapes + [target_shape]:
        check("`%s`" % shape in team_para, "qg-review.md 의 team 문단에도 `%s` 꼴이 있다" % shape)


# ---------------------------------------------------------------- 3 reason-words

def lock_reason_words():
    import intent_critic as ic
    words = {ic.REASK_CHANGED, ic.REASK_FIXED}
    qr = read(QG_REVIEW).split("\n")
    lead = line_starting(qr, "- 다시 묻는 질문(`asked_before`")
    check(lead != "", "qg-review.md 「질문 블록」 의 다시 묻는 질문 문장을 읽었다")
    doc_words = set(re.findall("`([^`]+)` 일 때", lead))
    check(doc_words == words, "그 문장의 까닭 낱말이 intent_critic.py 의 상수 둘과 같다",
          "문서 %s · 스크립트 %s" % (sorted(doc_words), sorted(words)))
    named = re.findall("넷째 칸이 [「`]([^」`]+)[」`]", "\n".join(qr))
    check(len(named) >= 2, "qg-review.md 가 「넷째 칸」 의 까닭 낱말을 이름으로 부른다(%d곳)" % len(named))
    for word in named:
        check(word in words, "「넷째 칸이 %s」 의 낱말이 intent_critic.py 의 상수에 있다" % word)


# ---------------------------------------------------------------- 4 qg-file-shape

def _gets(funcs, fn, recv):
    out = []
    for node in ast.walk(funcs[fn]):
        if (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "get"
                and isinstance(node.func.value, ast.Name) and node.func.value.id == recv and node.args
                and isinstance(node.args[0], ast.Constant) and isinstance(node.args[0].value, str)):
            out.append(node.args[0].value)
    return list(dict.fromkeys(out))


def _compared(funcs, fn, name):
    out = []
    for node in ast.walk(funcs[fn]):
        if (isinstance(node, ast.Compare) and isinstance(node.left, ast.Name) and node.left.id == name
                and len(node.ops) == 1 and isinstance(node.ops[0], ast.Eq)
                and isinstance(node.comparators[0], ast.Constant)):
            out.append(node.comparators[0].value)
    return out


def lock_qg_file_shape():
    import intent_critic as ic
    import qg_review_archive as A
    import synthesize_findings as sf
    import verdict as v
    import yaml
    tree = ast.parse(read(ARCHIVE_PY))
    funcs = {n.name: n for n in tree.body if isinstance(n, ast.FunctionDef)}
    doc = read(STATE_FMT)
    lines = doc.split("\n")
    fmt = next(iter(fences(heading_body(doc, "## 형식"))), [])
    check(len(fmt) > 10, "state-file-format.md 의 `## 형식` 펜스를 읽었다")

    def fmt_block(name):
        out, inside = [], False
        for line in fmt:
            if line.startswith("## "):
                inside = line == "## " + name
                continue
            if inside:
                out.append(line)
        return "\n".join(out)

    check(lines[0].endswith("`%s`" % A.RESULT_NAME), "문서가 결과 파일 `%s` 의 꼴이다" % A.RESULT_NAME)
    names = _gets(funcs, "read_archive", "parts")
    check(len(names) >= 3, "읽는 쪽이 결과 파일에서 읽는 절 이름을 뽑았다(%d개)" % len(names))
    for name in names:
        check("## " + name in fmt, "결과 파일 꼴에 읽는 절 `## %s` 가 있다" % name)
    fixes = fmt_block("고칠 목록")
    for sub in (A.FIX_BLOCKING, A.FIX_REGRESS):
        check("`### %s`" % sub in fixes, "`## 고칠 목록` 꼴에 읽는 하위 절 `### %s` 가 있다" % sub)
    verdict_block = fmt_block("판정")
    words = set(re.findall("[A-Za-z_-]+", verdict_block))
    for key in _gets(funcs, "_verdict", "got"):
        check(key in words, "`## 판정` 꼴에 읽는 칸 `%s` 가 있다" % key)
    range_words = set(re.findall("[A-Za-z_-]+", fmt_block("범위")))
    for key in _gets(funcs, "_range", "got"):
        check(key in range_words, "`## 범위` 꼴에 읽는 칸 `%s` 가 있다" % key)
    nothing = _compared(funcs, "read_archive", "verdict")
    check(len(nothing) == 1, "읽는 쪽이 「리뷰할 것 없음」 으로 보는 판정 값을 뽑았다(%r)" % nothing)
    for value in nothing:
        check(value in v.VALUES, "그 판정 값 `%s` 를 verdict.py 가 낸다" % value)
        check("`verdict: %s`" % value in verdict_block, "`## 판정` 꼴에 `verdict: %s` 가 있다" % value)
    for reason in A.NOTHING_REASONS:
        check(reason in v.REASONS, "리뷰할 것 없음의 사유 `%s` 를 verdict.py 가 낸다" % reason)
        check("`reason: %s`" % reason in verdict_block, "`## 판정` 꼴에 리뷰할 것 없음의 사유 `reason: %s` 가 있다" % reason)
    critic = fmt_block("intent-critic")
    rendered = ic._section("-", [], {"questions": [
        {"id": "q-wrong", "question": "그른 쪽", "state": "wrong-choice-filtered", "previous_answer": "잘못 골랐다",
         "answer_file": "a.md"},
        {"id": "q-done", "question": "답한 쪽", "state": "answered-filtered", "previous_answer": "의도다",
         "answer_file": "b.md"}]}, [])
    out_lines = rendered.split("\n")
    parts = A.sections("## 판정\n" + rendered)
    wrong, other = A._filtered(parts.get("intent-critic", []))
    for head in (A.FILTERED_HEAD, A.WRONG_HEAD):
        check("`%s`" % head in critic, "`## intent-critic` 꼴에 목록 머리 `%s` 가 있다" % head)
        check(head in out_lines, "intent_critic.py 가 목록 머리 `%s` 를 한 줄로 낸다" % head)
    check([x.id for x in wrong] == ["q-wrong"] and [x.id for x in other] == ["q-done"],
          "intent_critic.py 가 쓴 절을 읽는 쪽이 거른 목록 둘로 읽는다",
          "wrong=%r other=%r" % ([x.id for x in wrong], [x.id for x in other]))
    paras = [p for p in "\n".join(x for x in lines if not x.startswith("```")).split("\n\n")
             if "`%s`" % A.PRE_MERGE_NAME in p.split("\n")[0]]
    other_files = paras[0] if paras else ""
    other_ticks = set(ticks(other_files))
    check(other_files != "", "문서에 합치기 전 지적 목록 `%s` 를 첫 줄에 부르는 문단이 있다" % A.PRE_MERGE_NAME)
    top = _gets(funcs, "_pre_merge", "data")
    item_keys = list(dict.fromkeys(_gets(funcs, "_pre_merge", "x") + _gets(funcs, "_finding_text", "item")))
    check(len(top) == 1 and len(item_keys) >= 3, "읽는 쪽이 합치기 전 목록에서 읽는 키를 뽑았다(%r · %r)" % (top, item_keys))
    for key in top + item_keys:
        check(key in other_ticks, "그 문단에 읽는 키 `%s` 가 있다" % key)
    for sev in A.BLOCKING_SEVERITIES:
        check(sev in sf.SEVERITIES, "막는 등급 `%s` 를 합성기가 쓴다" % sev)
        check(sev in other_ticks, "그 문단에 막는 등급 `%s` 가 있다" % sev)
    with tempfile.TemporaryDirectory() as d:
        path = str(Path(d) / A.PRE_MERGE_NAME)
        sf._write_pre_merge(path, [{"severity": "IMPORTANT", "file": "a.py", "line": 1, "summary": "s",
                                    "proposed_fix": "f"}])
        with open(path, "r", encoding="utf-8") as fh:
            written = yaml.safe_load(fh.read())
    check(isinstance(written, dict) and set(top) <= set(written),
          "합성기가 쓴 합치기 전 목록의 머리 키가 읽는 쪽의 키(%r)다" % top, repr(written)[:200])
    ret = heading_body(doc, "## 돌려주는 꼴*")
    ret_text = "\n".join(ret)
    check(ret != [], "`## 돌려주는 꼴` 절을 읽었다")
    check(A.INTENT_NAME in line_starting(lines, "## 돌려주는 꼴") and "(%d판)" % A.INTENT_CONTRACT in
          line_starting(lines, "## 돌려주는 꼴"), "그 절이 `%s` 의 %d판이다" % (A.INTENT_NAME, A.INTENT_CONTRACT))
    check("`%s`" % A.INTENT_FENCE.lstrip("`") in ret_text, "그 절에 펜스 이름 `%s` 가 있다" % A.INTENT_FENCE.lstrip("`"))
    ret_ticks = set(ticks(ret_text))
    for key in _gets(funcs, "_intent", "data") + _gets(funcs, "_intent", "q"):
        check(key in ret_ticks, "돌려주는 꼴에 읽는 칸 `%s` 가 있다" % key)
    state_line = line_starting(ret, "- 질문 칸 `state` 의 값:")
    doc_states = set(ticks(state_line.partition(":")[2]))
    check(doc_states == set(ic.QUESTION_STATES), "질문 칸 `state` 의 값이 intent_critic.py 의 값과 같다",
          "문서 %s · 스크립트 %s" % (sorted(doc_states), sorted(ic.QUESTION_STATES)))
    check(A.UNASKED in ic.QUESTION_STATES and A.UNASKED in doc_states,
          "읽는 쪽이 옮기는 값 `%s` 가 문서와 intent_critic.py 에 있다" % A.UNASKED)


# ---------------------------------------------------------------- 5 no-paths-to-reviewed

def lock_no_paths():
    import qg_review_file as F
    import qg_review_state as S
    qr_text = read(QG_REVIEW)
    qr = qr_text.split("\n")
    banned = ("보관 폴더", F.STATE_NAME, "--answered", "--suite-lock")
    back = heading_body(qr_text, "## 되돌리기")
    send = [b for b in fences(back) if any("worktree 밖이어도" in x for x in b)]
    send_text = "\n".join(send[0]) if send else ""
    check(send_text != "", "되돌리기에서 보내는 글 펜스(`worktree 밖이어도` 표지)를 읽었다")
    check("처리 파일의 절대경로" in send_text, "보내는 글이 처리 파일의 절대경로를 싣는다")
    lead = line_starting(back, "**되돌리기에서 보내는 글.**")
    check("처리 파일의 절대경로만 싣고, 리뷰 보관 폴더와 상태 파일의 경로는 싣지 않는다" in lead,
          "되돌리기 문단이 보관 폴더 · 상태 파일 경로를 싣지 않는다고 말한다")
    team_qg = line_starting(heading_body(read(CONDUCTING), "## team 형식 로드맵"), "- **검수 걸음의 qg.**")
    check(bool(re.search("처리 파일은 .{0,200}?절대경로", team_qg)), "team 형식 다음 시도 — 처리 파일의 절대경로 자리를 적는다")
    check("싣는 글에는 리뷰 보관 폴더 · 상태 파일의 경로를 싣지 않는다" in team_qg,
          "team 형식 — 시작 묶음 · 결정 기록에 보관 폴더 · 상태 파일 경로를 싣지 않는다고 말한다")
    m = re.search("과제 결정 기록의 한 줄[(]「([^」]+)」", team_qg)
    team_text = m.group(1) if m else ""
    check("## 지적마다의 처리" in team_text, "team 형식 다음 시도에 싣는 결정 기록 한 줄을 읽었다")
    pr_body = line_starting(back, "- **PR 본문.**")
    m = re.search("호출 줄은 `(- 호출 · [^`]+)` 꼴", pr_body)
    shape = m.group(1) if m else ""
    check(shape == "- 호출 · <자리 글자> · <범위>", "PR 본문 호출 줄 꼴이 `- 호출 · <자리 글자> · <범위>` 이다", repr(shape))
    rv = F.Review(site="premerge", site_tag=S.site_tag("premerge", "pr7"), target="pr7", order=1,
                  range_start="a" * 40, range_end="b" * 40)
    first = S.pr_body_lines([rv])[0]
    want = shape.replace("<자리 글자>", rv.site_tag).replace("<범위>", "%s..%s" % (rv.range_start, rv.range_end))
    check(first == want, "스크립트가 짓는 PR 본문 호출 줄이 문서의 꼴이다", "%r != %r" % (first, want))
    for where, body in (("되돌리기에서 보내는 글", send_text), ("team 다음 시도의 결정 기록 줄", team_text),
                        ("PR 본문 호출 줄 문장", pr_body)):
        for token in banned:
            check(token not in body, "%s에 `%s` 가 없다" % (where, token))
    live = [t for t in banned if t in qr_text or t in read(CONDUCTING)]
    check("보관 폴더" in live and "--answered" in live, "금지 낱말이 문서의 다른 자리에는 있다(살아 있는 낱말 %d개)" % len(live))


LOCKS = (("gate-call", lock_gate_call), ("team-sentences", lock_team_sentences),
         ("reason-words", lock_reason_words), ("qg-file-shape", lock_qg_file_shape),
         ("no-paths-to-reviewed", lock_no_paths))
for name, fn in LOCKS:
    print("LOCK %s" % name)
    try:
        fn()
    except Exception as exc:
        say("NO", "%s — 락이 끝까지 돌지 못했다: %s: %s" % (name, type(exc).__name__, exc))
        for row in traceback.format_exc().splitlines()[-4:]:
            print("  " + row)
print("DONE")
PY

PYTHONDONTWRITEBYTECODE=1 python3 "$T/locks.py" "$ROOT" > "$T/out" 2>&1
rc=$?
assert_eq "$rc" "0" "락 스크립트가 종료 코드 0 으로 끝났다"
locks=0; done_seen=0; current=""
while IFS= read -r line; do
  case "$line" in
    "LOCK "*) locks=$((locks+1)); current="${line#LOCK }"; note "[${current}]" ;;
    "OK "*) ok "${line#OK }" ;;
    "NO "*) no "${current}: ${line#NO }" ;;
    "DONE") done_seen=1 ;;
    *) note "$line" ;;
  esac
done < "$T/out"
assert_eq "$locks" "5" "락 다섯이 모두 돌았다"
assert_eq "$done_seen" "1" "락 스크립트가 끝 줄까지 갔다"
finish
