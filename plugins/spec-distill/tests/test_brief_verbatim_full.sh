#!/usr/bin/env bash
# R2 Task 5 — payload §6 은 S1~Sn 원문 전량이고 추가만 허용(설계 §3-2 · AC11).
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"; FX="$ROOT/plugins/spec-distill/tests/fixtures"
TMP="$(mktemp -d -t sd-v6-XXXXXX)" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
trap 'rm -rf "$TMP"' EXIT

# 기반: 스윕을 마친 정상 쌍(payload §6 이 S1~Sn 전량이다)
base() {
  cp "$FX/interview-brief-valid.md" "$TMP/p.md"; cp "$FX/interview-brief-valid.audit.md" "$TMP/p.audit.md"
  python3 -I -X utf8 - "$TMP/p.md" "$TMP/p.audit.md" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
p.write_text(re.sub(r"(?m)^audit_file:.*$", "audit_file: p.audit.md", t, count=1), encoding="utf-8")
a = pathlib.Path(sys.argv[2]); u = a.read_text(encoding="utf-8")
a.write_text(re.sub(r"(?m)^payload:.*$", "payload: p.md", u, count=1), encoding="utf-8")
PY
}
gate() { python3 "$S/check_brief.py" gate "$TMP/p.md" > "$TMP/out" 2>&1; }
# payload §6 에서 앵커 하나의 항목(머리 줄 + 이어지는 들여쓴 줄)을 지운다
drop_anchor() { python3 -I -X utf8 - "$TMP/p.md" "$1" <<'PY'
import re, sys, pathlib
p, sid = pathlib.Path(sys.argv[1]), sys.argv[2]
lines, out, skip = p.read_text(encoding="utf-8").split("\n"), [], False
for ln in lines:
    if re.match(r"^\s*[-*]\s+\*\*S\d+\*\*", ln):
        skip = bool(re.match(r"^\s*[-*]\s+\*\*%s\*\*" % re.escape(sid), ln))
    elif skip and not (ln.startswith(" ") or ln.strip() == ""):
        skip = False
    if not skip:
        out.append(ln)
p.write_text("\n".join(out), encoding="utf-8")
PY
}

base; gate; assert_eq "$?" "0" "full_ok: payload §6 이 S1~Sn 전량이면 통과한다 (양성 대조)"
base; drop_anchor S2; gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -q 'N1b' "$TMP/out"; } \
  && ok "n1b_missing_audit: audit §6 의 S2 가 payload §6 에 없으면 red (N1b)" || no "n1b_missing_audit: rc=$rc"
base; drop_anchor S1; gate; rc=$?
[ "$rc" -ne 0 ] && ok "n1b_no_s1: S1 이 없으면 red" || no "n1b_no_s1: S1 없이 통과했다"

# check_verbatim_coverage — 같은 앵커가 양쪽에 같은 글자면 통과, 다르면 구조 위반(rc 1)
CV="$S/check_verbatim_coverage.py"
cp "$FX/brief-verbatim-ok.md" "$TMP/v.md"; cp "$FX/brief-verbatim-ok.audit.md" "$TMP/v.audit.md"
STATE="$FX/state-verbatim-ok.md"
[ -f "$STATE" ] || { no "state fixture 부재: $STATE"; finish; }
python3 "$CV" "$TMP/v.md" "$STATE" "$TMP/v.audit.md" > "$TMP/cv" 2>&1; assert_eq "$?" "0" "dup_same: payload · audit 의 같은 앵커가 같은 글자면 통과한다"
python3 -I -X utf8 - "$TMP/v.md" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
# payload 쪽 S2 본문의 첫 인용 줄 끝에 글자를 덧붙인다 — 지적에 맞춰 payload 사본을 고친 모양
t2 = re.sub(r'(\*\*S2\*\*[^\n]*\n\s*>\s*"?[^\n]*?)("?\s*\n)', r"\1 (고침)\2", t, count=1)
assert t2 != t, "S2 항목을 찾지 못했다 — 픽스처를 확인하라"
p.write_text(t2, encoding="utf-8")
PY
python3 "$CV" "$TMP/v.md" "$STATE" "$TMP/v.audit.md" > "$TMP/cv" 2>&1; rc=$?
{ [ "$rc" -eq 1 ] && grep -q '글자가' "$TMP/cv"; } \
  && ok "dup_differs: 같은 앵커의 글자가 다르면 구조 위반(rc 1)" || no "dup_differs: rc=$rc $(head -c 300 "$TMP/cv")"
cp "$FX/brief-verbatim-ok.md" "$TMP/v.md"
python3 -I -X utf8 - "$TMP/v.md" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
lines, out, skip = t.split("\n"), [], False
for ln in lines:
    if re.match(r"^\s*[-*]\s+\*\*S\d+\*\*", ln):
        skip = bool(re.match(r"^\s*[-*]\s+\*\*S2\*\*", ln))
    elif skip and not (ln.startswith(" ") or ln.strip() == ""):
        skip = False
    if not skip:
        out.append(ln)
p.write_text("\n".join(out), encoding="utf-8")
PY
python3 "$CV" "$TMP/v.md" "$STATE" "$TMP/v.audit.md" > "$TMP/cv" 2>&1; rc=$?
{ [ "$rc" -eq 1 ] && grep -q 'S2' "$TMP/cv"; } \
  && ok "payload_missing: state · audit 에 있는 S2 가 payload §6 에 없으면 위반(rc 1)" || no "payload_missing: rc=$rc"

# 추가만 허용 — 결정 발화를 payload §6 · audit §6 · state 에 같은 write 로 더하면 다음 원문 검사가 통과한다
cp "$FX/brief-verbatim-ok.md" "$TMP/v.md"; cp "$FX/brief-verbatim-ok.audit.md" "$TMP/v.audit.md"; cp "$STATE" "$TMP/st.md"
python3 -I -X utf8 - "$TMP/v.md" "$TMP/v.audit.md" "$TMP/st.md" <<'PY'
import re, sys, pathlib
pay, aud, st = (pathlib.Path(x) for x in sys.argv[1:4])
ids = [int(x) for x in re.findall(r"\*\*S(\d+)\*\*", pay.read_text(encoding="utf-8"))]
n = max(ids) + 1
item = '\n- **S%d** 🗣 brief 리뷰 결정:\n  > "방향은 그대로 두고 범위만 줄인다"\n' % n
for f in (pay, aud):
    t = f.read_text(encoding="utf-8")
    m = re.search(r"(?m)^## 6\..*$", t)
    nxt = re.search(r"(?m)^## \d+\.", t[m.end():])
    cut = m.end() + nxt.start() if nxt else len(t)
    f.write_text(t[:cut].rstrip("\n") + "\n" + item + "\n" + t[cut:], encoding="utf-8")
s = st.read_text(encoding="utf-8")
entry = '  - id: S%d\n    source: verbatim\n    round: 99\n    text: "방향은 그대로 두고 범위만 줄인다"\n' % n
s = re.sub(r"(?m)^(user_statements:\s*\n)", lambda m: m.group(1) + entry, s, count=1)
st.write_text(s, encoding="utf-8")
PY
python3 "$CV" "$TMP/v.md" "$TMP/st.md" "$TMP/v.audit.md" > "$TMP/cv" 2>&1
assert_eq "$?" "0" "append_only: 결정 발화를 세 자리에 같은 write 로 더한 뒤 원문 검사가 통과한다"

# 원장 밖 앵커 — 남의 항목 본문 안에 심은 `- **S<N>**` 줄은 사용자 발화가 아니다
# plant <파일> <S1 인용 줄>: S1 본문 안(들여 쓴 자리)에 S3 항목을 심는다
plant() { python3 -I -X utf8 - "$1" "$2" <<'PY'
import sys, pathlib
p, q = pathlib.Path(sys.argv[1]), sys.argv[2]
t = p.read_text(encoding="utf-8")
t2 = t.replace(q + "\n", q + '\n  - **S3** 🗣 R4 답:\n  > "캐시는 안 한다"\n', 1)
assert t2 != t, "S1 인용 줄을 찾지 못했다 — 픽스처를 확인하라"
p.write_text(t2, encoding="utf-8")
PY
}
base; plant "$TMP/p.md" '  > "대시보드가 너무 느려요. 서버에서 그려주면 안 되나요?"'
python3 -I -X utf8 - "$TMP/p.md" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
t2 = t.replace("- OQ1 [열림] — 인증 뷰의 캐시 전략 — 해답공간으로 이월.", "- OQ1 [해결 ⟨S3⟩] — 인증 뷰의 캐시 전략 — 해답공간으로 이월.", 1)
t2 = t2.replace("- OQ1: 인증 뷰의 캐시 전략 — 해답공간으로 이월.", "- OQ1 [해결 ⟨S3⟩]: 인증 뷰의 캐시 전략 — 해결: 안 한다.", 1)
assert t2.count("⟨S3⟩") == 2, "OQ1 줄을 찾지 못했다 — 픽스처를 확인하라"
p.write_text(t2, encoding="utf-8")
PY
gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -q 'N1b' "$TMP/out" && grep -q '들여' "$TMP/out"; } \
  && ok "n1b_nested: S1 본문 안에 들여 쓴 S3 앵커로 OQ 를 해결하면 red (N1b)" || no "n1b_nested: rc=$rc $(head -c 300 "$TMP/out")"
cp "$FX/brief-verbatim-ok.md" "$TMP/v.md"; cp "$FX/brief-verbatim-ok.audit.md" "$TMP/v.audit.md"
plant "$TMP/v.md" '  > "브리프에 리뷰를 붙이고 싶다"'
python3 "$CV" "$TMP/v.md" "$STATE" "$TMP/v.audit.md" > "$TMP/cv" 2>&1; rc=$?
{ [ "$rc" -eq 1 ] && grep -q 'anchor_indented' "$TMP/cv"; } \
  && ok "phantom_nested: 들여 쓴 S3 앵커 줄은 payload §6 의 문법 밖이라 사유 이름(anchor_indented)과 함께 위반(rc 1)" || no "phantom_nested: rc=$rc $(head -c 300 "$TMP/cv")"
# payload · audit 에만 더하고 state 에는 안 더한 append — 두 게이트를 다 통과하던 길
cp "$FX/brief-verbatim-ok.md" "$TMP/v.md"; cp "$FX/brief-verbatim-ok.audit.md" "$TMP/v.audit.md"
python3 -I -X utf8 - "$TMP/v.md" "$TMP/v.audit.md" <<'PY'
import re, sys, pathlib
item = '\n- **S3** 🗣 brief 리뷰 결정:\n  > "범위를 줄인다"\n'
for f in (pathlib.Path(x) for x in sys.argv[1:3]):
    t = f.read_text(encoding="utf-8")
    m = re.search(r"(?m)^## 6\..*$", t)
    nxt = re.search(r"(?m)^## \d+\.", t[m.end():])
    cut = m.end() + nxt.start() if nxt else len(t)
    f.write_text(t[:cut].rstrip("\n") + "\n" + item + "\n" + t[cut:], encoding="utf-8")
PY
python3 "$CV" "$TMP/v.md" "$STATE" "$TMP/v.audit.md" > "$TMP/cv" 2>&1; rc=$?
{ [ "$rc" -eq 1 ] && grep -q '"unknown_ids": \["S3"\]' "$TMP/cv"; } \
  && ok "payload_only_append: state 에 없이 payload · audit 에만 더한 S3 는 위반(rc 1 · unknown_ids)" || no "payload_only_append: rc=$rc $(head -c 300 "$TMP/cv")"
# S1 관례 — 최초 요청 원문 S1 은 state 원장(S2 부터)에 없어도 payload §6 에 산다
python3 "$CV" "$FX/brief-verbatim-original-request.md" "$FX/state-verbatim-original-request.md" "$FX/brief-verbatim-original-request.audit.md" > "$TMP/cv" 2>&1
assert_eq "$?" "0" "s1_convention: state 가 S2 부터여도 payload §6 의 S1 은 원장 밖 앵커가 아니다"
grep -qF '| `1` + `unknown_ids` |' "$ROOT/plugins/spec-distill/skills/reviewing-brief/SKILL.md" \
  && ok "rc_table: reviewing-brief rc 표가 unknown_ids 행을 갖는다" || no "rc_table: rc 표에 unknown_ids 행이 없다"

finish
