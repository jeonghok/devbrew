#!/usr/bin/env bash
# test_publish_gh_two_files.sh — AC15: gh 를 부르는 qg 파일은 둘뿐이다 — `scripts/publish-comment.sh`(코멘트 쓰기와
# 그 앞의 인증 · PR 확인)와 `scripts/discover-spec.sh`(읽기 전용 `gh pr view`). gh 쓰기는 publish-comment.sh 에만 있다.
#
# 코퍼스는 qg 의 추적 파일 중 실행되거나 모델이 읽는 것 전부다(scripts · skills · commands · agents · references ·
# .claude-plugin). 주석 · 산문 · 펜스 밖 줄도 본다 — 실행 지시는 펜스 밖에도 있다. tests/ · CHANGELOG · README 는
# 실행되지도 모델에 로드되지도 않아 뺀다.
# (qg v10 ③ plan 이 쓴 테스트 코드다 — 리뷰는 이 파일도 검사 대상으로 본다.)
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
OUT="$(mktemp)" || exit 1
trap 'rm -f "$OUT"' EXIT
PYTHONDONTWRITEBYTECODE=1 python3 - "$ROOT" > "$OUT" <<'PY'
import re, subprocess, sys
sys.stdout.reconfigure(encoding="utf-8")
root = sys.argv[1]
def out(k, m): print(k + "\t" + m)

SUB = (r"(?:pr|api|auth|repo|issue|release|run|workflow|gist|secret|variable|label|search|browse|"
       r"codespace|ssh-key|gpg-key|org|project|cache|ruleset|attestation|extension|alias|config|status)")
INVOKE = re.compile(r"(?<![A-Za-z0-9_./-])gh[ \t]+(" + SUB + r")(?:[ \t]+([a-z][a-z-]*))?")
WRITE = re.compile(r"(?<![A-Za-z0-9_./-])gh[ \t]+(?:api\b|pr[ \t]+(?:comment|create|edit|merge|close|reopen|review|ready|lock|unlock)\b"
                   r"|issue[ \t]+(?:comment|create|edit|close|delete)\b|release[ \t]+(?:create|edit|upload|delete)\b"
                   r"|repo[ \t]+(?:create|edit|delete|fork|rename)\b)")

# argv 목록 표기(`["gh", "api", …]` — Python · JS 의 subprocess)는 따옴표 · 쉼표를 걷어 셸 표기로 펴서 함께 잰다.
ARGSEP = re.compile(r"""["']\s*,\s*["']""")
def views(line):
    return (line, ARGSEP.sub(" ", line))
def hits(rx, line):
    return [m for v in views(line) for m in rx.finditer(v)]

# 매처 대조 — 정규식이 부러지면 0건으로 조용히 GREEN 이 된다.
probe = {"gh pr comment 1 --body-file x": (True, True), "run: gh pr view --json n": (True, False),
         "`gh api user`": (True, True), "gh 는 쓰지 않는다": (False, False), "ghost pr comment": (False, False),
         "x/gh pr view": (False, False), 'subprocess.run(["gh", "api", "x"])': (True, True),
         "['gh', 'pr', 'view', '--json']": (True, False)}
bad = [s for s, (inv, wr) in probe.items() if bool(hits(INVOKE, s)) != inv or bool(hits(WRITE, s)) != wr]
out("NO" if bad else "OK", f"매처 대조 {len(probe)}건 " + ("실패: " + " | ".join(bad) if bad else "통과"))

r = subprocess.run(["git", "-C", root, "ls-files", "--", "plugins/quality-gates"], capture_output=True, text=True)
if r.returncode != 0 or not r.stdout.strip():
    out("NO", f"git ls-files 실패(rc={r.returncode}) — 코퍼스 없이 판정하지 않는다"); sys.exit(0)
KEEP = re.compile(r"plugins/quality-gates/(scripts|skills|commands|agents|references|\.claude-plugin)/")
files = [p for p in r.stdout.splitlines() if KEEP.match(p)]
out("OK" if len(files) >= 30 else "NO", f"코퍼스 {len(files)}개(하한 30)")

callers, writers, subs = {}, {}, {}
for p in files:
    try:
        text = open(f"{root}/{p}", encoding="utf-8").read()
    except (OSError, UnicodeDecodeError):
        continue   # 바이너리 · 비 UTF-8 은 셸 · 프롬프트 코퍼스가 아니다
    for i, line in enumerate(text.splitlines(), 1):
        for m in hits(INVOKE, line):
            callers.setdefault(p, []).append(i)
            subs.setdefault(p, set()).add((m.group(1) + " " + (m.group(2) or "")).strip())
        if hits(WRITE, line):
            writers.setdefault(p, []).append(i)

SINK = "plugins/quality-gates/scripts/publish-comment.sh"
DISC = "plugins/quality-gates/scripts/discover-spec.sh"
extra = sorted(set(callers) - {SINK, DISC})
out("NO" if extra else "OK", "gh 를 부르는 파일은 sink · discover-spec 둘뿐" + (": 밖 " + ", ".join(f"{p}:{callers[p][0]}" for p in extra) if extra else ""))
w_extra = sorted(set(writers) - {SINK})
out("NO" if w_extra else "OK", "gh 쓰기는 sink 에만" + (": 밖 " + ", ".join(f"{p}:{writers[p][0]}" for p in w_extra) if w_extra else ""))
# 양의 짝 — 두 파일이 실제로 gh 를 부른다(부재 단언이 공허하지 않다).
out("OK" if SINK in writers else "NO", "sink 가 gh 쓰기를 한다(양의 짝)")
disc = subs.get(DISC, set())
out("OK" if disc == {"pr view"} else "NO", f"discover-spec 의 gh 는 읽기 전용 pr view 하나({sorted(disc) or '없음'})")
PY
rc=$?
[ "$rc" -eq 0 ] || no "판정 코어가 죽었다(rc=$rc)"
TAB="$(printf '\t')"
n=0
while IFS="$TAB" read -r kind msg; do
  n=$((n+1))
  case "$kind" in OK) ok "$msg" ;; NO) no "$msg" ;; *) no "모르는 줄: $kind $msg" ;; esac
done < "$OUT"
[ "$n" -gt 0 ] || no "판정 코어가 아무 줄도 내지 않았다"
finish
