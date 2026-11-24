"""리더 세션의 맥락을 무엇이 채웠나 — 본 대화에 들어온 글의 글자 수를 종류별로 센다.

읽기만 한다. 인자: 세션 기록(jsonl) 경로들. 글자 수는 토큰이 아니다 — 몫을 보려는 값이다.
"""
import json
import re
import sys
from collections import defaultdict

BASH_RULES = [
    ("스위트 대조(merge_check)", r"merge_check"),
    ("스위트 직접 돌림", r"suite_lock|run-all\.sh"),
    ("상태 계산(control_plane)", r"control_plane"),
    ("기계 상태(conductor_ledger)", r"conductor_ledger"),
    ("상태 브랜치(conductor_status · branch · mail)", r"conductor_(status|branch|mail)"),
    ("리뷰 엔진 · 대조 스크립트", r"docreview|spec_review|check_bundle|check_brief|qg_|quality"),
    ("담당자 세션(hc)", r"(^|[\s;&|(])hc\s"),
    ("GitHub(gh)", r"(^|[\s;&|(])gh\s"),
    ("git", r"(^|[\s;&|(])git\s"),
]
READ_RULES = [
    ("지휘 절차서(conducting.md)", r"references/conducting\.md$"),
    ("보내는 글 틀(conductor-dispatch.md)", r"conductor-dispatch\.md$"),
    ("상태 브랜치 절차(conductor-state-branch.md)", r"conductor-state-branch\.md$"),
    ("qg 절차(qg-review.md)", r"qg-review\.md$"),
    ("그 밖 플러그인 reference · skill", r"/(references|skills)/[^ ]*\.md$"),
    ("설계문서(specs)", r"/specs/"),
    ("계획(plans)", r"/plans/"),
    ("로드맵 · 묶음", r"/roadmaps/"),
    ("담당자 결과 · 물음 · 옮김 파일", r"/files/(report|relay|tmp)/"),
    ("잘려 저장된 도구 출력", r"/tool-results/"),
    ("인계 · 거울 글(sdd-mirror)", r"sdd-mirror"),
]


def size(content):
    if isinstance(content, str):
        return len(content)
    n = 0
    for part in content or []:
        if isinstance(part, dict):
            n += len(part.get("text") or "")
            if part.get("type") == "image":
                n += 1500
    return n


def classify(name, inp):
    if name == "Read":
        p = inp.get("file_path", "")
        for label, rx in READ_RULES:
            if re.search(rx, p):
                return "읽기 — " + label
        return "읽기 — 그 밖(코드 · 테스트 등)"
    if name == "Bash":
        c = inp.get("command", "")
        for label, rx in BASH_RULES:
            if re.search(rx, c):
                return "셸 — " + label
        return "셸 — 그 밖"
    if name in ("Agent", "Task"):
        return "하위 agent 가 돌려준 보고"
    if name == "Skill":
        return "skill 부름 결과"
    if name in ("Grep", "Glob"):
        return "찾기(Grep · Glob)"
    if name in ("Edit", "Write", "NotebookEdit"):
        return "고치기 결과"
    if name == "AskUserQuestion":
        return "질문 창 답"
    return "도구 — " + name


def scan(path, tot, cnt):
    names = {}
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if d.get("isSidechain"):
                continue
            typ = d.get("type")
            msg = d.get("message") or {}
            content = msg.get("content")
            if typ == "assistant" and isinstance(content, list):
                for part in content:
                    if not isinstance(part, dict):
                        continue
                    if part.get("type") == "tool_use":
                        names[part.get("id")] = classify(part.get("name", ""), part.get("input") or {})
                        n = len(json.dumps(part.get("input") or {}, ensure_ascii=False))
                        tot["리더가 쓴 글 — 도구 인자(고칠 글 · 명령 · 보내는 글)"] += n
                        cnt["리더가 쓴 글 — 도구 인자(고칠 글 · 명령 · 보내는 글)"] += 1
                    elif part.get("type") == "text":
                        tot["리더가 쓴 글 — 사용자에게"] += len(part.get("text") or "")
                        cnt["리더가 쓴 글 — 사용자에게"] += 1
            elif typ == "user":
                if isinstance(content, str):
                    parts = [{"type": "text", "text": content}]
                else:
                    parts = content or []
                for part in parts:
                    if not isinstance(part, dict):
                        continue
                    if part.get("type") == "tool_result":
                        label = names.get(part.get("tool_use_id"), "도구 — 알 수 없음")
                        tot[label] += size(part.get("content"))
                        cnt[label] += 1
                    elif part.get("type") == "text":
                        t = part.get("text") or ""
                        if d.get("isCompactSummary"):
                            label = "압축 요약"
                        elif t.startswith("Base directory for this skill"):
                            label = "skill 본문"
                        elif "<task-notification" in t[:200]:
                            label = "하위 agent 알림"
                        elif t.lstrip().startswith("<hc from="):
                            label = "담당자 세션 알림(hc)"
                        elif t.lstrip().startswith(("<system-reminder", "<local-command", "Caveat:", "<command-")):
                            label = "하니스가 넣은 글"
                        else:
                            label = "사용자 글"
                        tot[label] += len(t)
                        cnt[label] += 1


tot = defaultdict(int)
cnt = defaultdict(int)
for p in sys.argv[1:]:
    scan(p, tot, cnt)
total = sum(tot.values()) or 1
print(f"본 대화에 들어온 글 합 {total / 1e6:.1f}M 글자 · 세션 {len(sys.argv) - 1}개")
for label, n in sorted(tot.items(), key=lambda kv: -kv[1]):
    if n / total < 0.004:
        continue
    print(f"{n / total * 100:5.1f}%  {n / 1000:8.0f}k  {cnt[label]:5d}번  {label}")
