#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/*.md plugins/quality-gates/skills/*/references/*.md plugins/quality-gates/references/*.md
# test_heredoc_nonce.sh — qg 본문 · reference 의 here-doc 끝 표지는 스크립트가 낸 값을 쓴다(설계 §3 · AC9).
#
# 코퍼스는 열거하지 않고 git ls-files 로 도출한다. 케이스:
#   fixed_terminator_absent  — here-doc 시작마다 끝 표지가 `<<'<이름>_<8 hex>'` 꼴이다(따옴표 없음 · 큰따옴표 ·
#                              `<<-` · 고정 이름은 그 파일:줄을 내고 실패). 끝 줄이 같은 표지인지도 본다.
#   new_form_present         — 새 꼴 here-doc 이 1개 이상(위 부재 락의 양의 짝).
#   value_line_before_each   — 새 꼴 here-doc 마다 바로 앞 펜스 끝과 그 펜스 시작 사이에
#                              `qg_nonce.py" hex` 를 담은 줄이 있다.
#   model_picks_phrase_absent — 코퍼스에 「고른 16진수」 가 없다.
#   mutations                — 믿지 않는 입력의 갈래라 변이 넷(반전 · 삭제 · 추가 · 형태)이 각각 RED,
#                              손대지 않은 사본(양성 대조)이 GREEN 인지 임시 사본으로 잰다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
. "$REPO/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

CORPUS="$(git -C "$REPO" ls-files 'plugins/quality-gates/skills/*.md' \
  'plugins/quality-gates/skills/*/references/*.md' 'plugins/quality-gates/references/*.md')"

cat > "$T/check.py" <<'PY'
"""here-doc 끝 표지 검사기. 사용: check.py <루트> <상대 경로>...
위반마다 한 줄: fixed|form|end|noval|phrase 「|」 <파일>:<줄> 「|」 <글>. 끝에 new|<새 꼴 수>."""
import re
import sys

START = re.compile(r"(?<!<)<<(?!<)(-?)([ \t]*)(['\"]?)([A-Za-z_][A-Za-z0-9_]*)(['\"]?)")
NEW_NAME = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*_<8 hex>$")
FENCE = re.compile(r"^[ \t]*```")
VALUE = 'qg_nonce.py" hex'
PHRASE = "고른 16진수"


def tokens(line):
    """줄 안의 here-doc 시작마다 (dash, space, q1, word_with_suffix, q2)."""
    out = []
    i = 0
    while True:
        m = START.search(line, i)
        if not m:
            return out
        dash, sp, q1, word = m.group(1), m.group(2), m.group(3), m.group(4)
        end = m.end(4)
        # `<이름>_<8 hex>` — `<` 는 단어 문자가 아니라 정규식이 `_` 뒤에서 끊는다. 이어 붙여 읽는다.
        if word.endswith("_") and line.startswith("<8 hex>", end):
            word += "<8 hex>"
            end += len("<8 hex>")
        q2 = line[end] if end < len(line) and line[end] in "'\"" else ""
        out.append((dash, sp, q1, word, q2))
        i = end + (1 if q2 else 0)


def scan(root, rel):
    viol, new = [], 0
    with open(root + "/" + rel, encoding="utf-8") as f:
        lines = f.read().split("\n")
    in_fence, opener, last_close = False, None, -1
    for n, line in enumerate(lines):
        if PHRASE in line:
            viol.append(("phrase", n, line))
        if FENCE.match(line):
            if in_fence:
                in_fence, last_close = False, n
            else:
                in_fence, opener = True, n
            continue
        for dash, sp, q1, word, q2 in tokens(line):
            if not NEW_NAME.match(word):
                viol.append(("fixed", n, line))
                continue
            if dash or sp or q1 != "'" or q2 != "'":
                viol.append(("form", n, line))
                continue
            new += 1
            top = opener if in_fence else n
            if not any(VALUE in lines[k] for k in range(last_close + 1, top)):
                viol.append(("noval", n, line))
            close = len(lines)
            if in_fence:
                close = next((k for k in range(n + 1, len(lines)) if FENCE.match(lines[k])), len(lines))
            if not any(lines[k].strip() == word for k in range(n + 1, close)):
                viol.append(("end", n, line))
    return viol, new


def main(argv):
    root, rels = argv[1], argv[2:]
    if not rels:
        print("empty|-|-")
        return 0
    total = 0
    for rel in rels:
        viol, new = scan(root, rel)
        total += new
        for kind, n, line in viol:
            print("%s|%s:%d|%s" % (kind, rel, n + 1, line.strip()))
    print("new|%d" % total)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
PY

# check <루트> — 코퍼스 전체를 검사한 출력.
check() { python3 -I "$T/check.py" "$1" $CORPUS; }
kind_lines() { grep -E "^$2[|]" <<< "$1"; }
new_count() { sed -n 's/^new|//p' <<< "$1"; }

case_corpus_derived() {
  local n
  n="$(printf '%s\n' "$CORPUS" | grep -c .)"
  [ "$n" -gt 0 ] && ok "코퍼스를 git ls-files 로 도출했다(${n}개 파일)" || no "코퍼스가 비었다 — 공허하게 통과하지 않는다"
  assert_contains "$CORPUS" "plugins/quality-gates/skills/quality-pipeline/SKILL.md" "코퍼스에 quality-pipeline 본문이 있다"
  assert_contains "$CORPUS" "plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md" \
    "코퍼스에 intent-critic reference 가 있다"
}

OUT_REAL="$(check "$REPO")"

case_fixed_terminator_absent() {
  local bad
  bad="$(grep -E '^(fixed|form|end)[|]' <<< "$OUT_REAL")"
  if [ -z "$bad" ]; then ok "fixed_terminator_absent — 모든 here-doc 끝 표지가 <<'<이름>_<8 hex>' 꼴이고 끝 줄이 같다"
  else no "fixed_terminator_absent — 고정 · 다른 꼴의 끝 표지가 $(grep -c . <<< "$bad")곳 있다"
    sed 's/^/      /' <<< "$bad" | head -40
  fi
}

case_new_form_present() {
  local n
  n="$(new_count "$OUT_REAL")"
  [ -n "$n" ] && [ "$n" -gt 0 ] && ok "new_form_present — 새 꼴 here-doc 이 ${n}곳 있다" \
    || no "new_form_present — 새 꼴 here-doc 이 없다(n=${n:-?})"
}

case_value_line_before_each() {
  local bad
  bad="$(kind_lines "$OUT_REAL" noval)"
  if [ -z "$bad" ]; then ok "value_line_before_each — 새 꼴 here-doc 마다 펜스 앞에 qg_nonce.py hex 줄이 있다"
  else no "value_line_before_each — 값 받는 줄이 없는 here-doc 이 $(grep -c . <<< "$bad")곳 있다"
    sed 's/^/      /' <<< "$bad" | head -40
  fi
}

case_model_picks_phrase_absent() {
  local bad
  bad="$(kind_lines "$OUT_REAL" phrase)"
  if [ -z "$bad" ]; then ok "model_picks_phrase_absent — 「고른 16진수」 문장이 없다"
  else no "model_picks_phrase_absent — 「고른 16진수」 가 $(grep -c . <<< "$bad")곳 남았다"
    sed 's/^/      /' <<< "$bad"
  fi
}

# ── 변이: 임시 사본에서 검사기가 각 변이를 잡는지 본다(손대지 않은 사본이 양성 대조).
copy_corpus() {   # copy_corpus <대상 루트>
  local f
  for f in $CORPUS; do mkdir -p "$1/$(dirname "$f")"; cp "$REPO/$f" "$1/$f"; done
}
SK="plugins/quality-gates/skills/quality-pipeline/SKILL.md"
DT="plugins/quality-gates/skills/quality-pipeline/references/differential-test.md"
IC="plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md"

cat > "$T/mutate.py" <<'PY'
"""사용: mutate.py <파일> <변이 이름>. 글이 바뀌지 않으면 exit 3."""
import sys

OPEN, END = "<<'QG_FIX_LIST_<8 hex>'", "\nQG_FIX_LIST_<8 hex>\n"
PICK = "\n구분자의 `<8 hex>` 는 쓸 때마다 새로 고른 16진수 8자로 바꾼다.\n"


def mutate(s, name):
    if name == "invert":
        return s.replace(OPEN, "<<'QG_FIX_LIST'").replace(END, "\nQG_FIX_LIST\n")
    if name == "delete":
        return "\n".join(l for l in s.split("\n") if 'qg_nonce.py" hex' not in l)
    if name == "add":
        return s + PICK
    if name == "reshape":
        return s.replace(OPEN, '<<"QG_FIX_LIST"').replace(END, "\nQG_FIX_LIST\n")
    if name == "reshape2":
        return s.replace(OPEN, '<<"QG_FIX_LIST_<8 hex>"')
    if name == "reshape3":
        return s.replace(OPEN, "<<QG_FIX_LIST_<8 hex>")
    if name == "endline":
        return s.replace(END, "\nQG_FIX_LIST\n")
    raise SystemExit("unknown mutation: " + name)


p, name = sys.argv[1], sys.argv[2]
with open(p, encoding="utf-8") as f:
    s = f.read()
t = mutate(s, name)
if t == s:
    sys.exit(3)
with open(p, "w", encoding="utf-8") as f:
    f.write(t)
PY

# mutate <변이 이름> <파일> — 사본을 만들고 바꾸고, 바뀌었는지 확인한 뒤 검사 출력을 낸다.
mutate() {
  local d="$T/m-$1"
  rm -rf "$d"; mkdir -p "$d"; copy_corpus "$d"
  python3 -I "$T/mutate.py" "$d/$2" "$1" || { echo "nochange"; return; }
  check "$d"
}

expect_red() {   # expect_red <변이 출력> <종류> <라벨>
  if [ "$1" = nochange ]; then no "$3 — 변이가 적용되지 않았다(계측기 고장)"; return; fi
  if grep -qE "^$2[|]" <<< "$1"; then ok "$3 — RED($2)"; else no "$3 — 잡히지 않았다(GREEN)"; fi
}

case_mutations() {
  local d="$T/control" out
  mkdir -p "$d"; copy_corpus "$d"
  out="$(check "$d")"
  assert_eq "$(grep -cvE '^new[|]' <<< "$out")" "0" "양성 대조 — 손대지 않은 사본에 위반이 없다(GREEN)"
  [ "$(new_count "$out")" -gt 0 ] 2>/dev/null && ok "양성 대조 — 사본에도 새 꼴이 있다" || no "양성 대조 — 사본에 새 꼴이 없다"
  # 반전 — 끝 표지 하나를 고정 이름으로(시작 · 끝 두 자리)
  expect_red "$(mutate invert "$SK")" fixed "변이(반전) — QG_FIX_LIST 끝 표지를 고정 이름으로"
  # 삭제 — 값 받는 줄 지우기(차등 테스트 reference 의 것)
  expect_red "$(mutate delete "$DT")" noval "변이(삭제) — 값 받는 줄을 지운다"
  # 추가 — 모델이 고른다는 문장 더하기
  expect_red "$(mutate add "$IC")" phrase "변이(추가) — 「새로 고른 16진수」 문장을 더한다"
  # 형태 — 큰따옴표 꼴(고정 이름) · 큰따옴표 꼴(값 자리는 그대로) · 따옴표 없음
  expect_red "$(mutate reshape "$SK")" fixed "변이(형태) — <<\"QG_FIX_LIST\" 큰따옴표 꼴"
  expect_red "$(mutate reshape2 "$SK")" form "변이(형태) — 값 자리를 둔 큰따옴표 꼴"
  expect_red "$(mutate reshape3 "$SK")" form "변이(형태) — 따옴표 없는 꼴(몸이 셸에서 풀린다)"
  # 끝 줄 — 시작만 바꾸고 끝 줄을 옛 이름으로 두면 펜스 끝까지 몸이 된다
  expect_red "$(mutate endline "$SK")" end "변이(끝 줄) — 끝 줄이 끝 표지와 다르다"
}

case_corpus_derived
case_fixed_terminator_absent
case_new_form_present
case_value_line_before_each
case_model_picks_phrase_absent
case_mutations
finish
