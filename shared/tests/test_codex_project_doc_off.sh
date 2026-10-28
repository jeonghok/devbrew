#!/usr/bin/env bash
# guards: plugins/** shared/**
# codex 를 부르는 곳 전부가 검토 트리의 AGENTS.md 를 지시로 불러오지 않게 하는 설정을
# 실제 호출에 싣고 있는지 잰다. 대상은 도출한다 — 새 호출이 생기면 자동으로 든다.
#
# 도출: 추적되는 비-테스트 파일 전부(tests · fixtures · spike · *.md 제외)에서 주석이 아닌
# 줄 가운데 `codex exec`(앞에 timeout · command · env 가 붙어도, 공백이 둘이어도, 옵션이
# 사이에 껴도) · `"$CODEX…" exec` · python/js 의 `"codex", "exec"` 를 가진 줄을 호출로 본다.
# 심볼릭 링크는 가리키는 실체로 접고, 실체가 도출 집합에 있는지 따로 잰다.
#
# 판정: 호출 블록(줄 끝 `\` 로 이어지는 줄 · `||` 줄까지; python/js 는 다음 빈 줄까지)을
# 읽고 `"${이름[@]}"` 배열은 그 배열의 대입 내용으로 펼친 뒤 센다. 설정이 정확히 한 번이
# 아니거나, `project_doc_max_bytes` 가 `=0` 꼴이 아닌 채로 있거나, 펼칠 수 없는 배열이나
# 두 번 이상 대입된 배열을 쓰면 실패다.
set -u -o pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

T="$(mktemp -d)" || { echo "임시 폴더 실패"; exit 1; }
trap 'rm -rf "$T"' EXIT

cat > "$T/scan.py" <<'PY'
import itertools, os, re, sys

FLAG = "-c 'project_doc_max_bytes=0'"
SH_CALL = re.compile(
    r"""\bcodex\b[ \t]+(?:-\S+[ \t]+(?:\S+[ \t]+)??)*?(?:exec|e)\b"""
    r"""|CODEX[A-Z_]*\}?"?[ \t]+exec\b""")
SCRIPT_CALL = re.compile(r"""["']codex["']\s*,\s*["']exec["']""")
SKIP_DIR = re.compile(r"(^|/)(tests|fixtures|spike)/")


def is_comment(s):
    t = s.lstrip()
    return t.startswith("#") or t.startswith("//")


def strip_comment(s):
    return re.sub(r"(^|[ \t])#.*$", "", s)


def scan(root, files):
    seen = set()
    out = []
    links = []
    for rel in files:
        if SKIP_DIR.search(rel) or rel.endswith((".md", ".audit")):
            continue
        p = os.path.join(root, rel)
        try:
            raw = open(p, "rb").read()
        except OSError:
            continue
        if b"\0" in raw:
            continue
        lines = raw.decode("utf-8", "ignore").split("\n")
        hits = [i for i, ln in enumerate(lines)
                if not is_comment(ln) and (SH_CALL.search(ln) or SCRIPT_CALL.search(ln))]
        if not hits:
            continue
        rp = os.path.realpath(p)
        if os.path.islink(p):
            links.append((rel, rp))
            continue
        if rp in seen:
            continue
        seen.add(rp)
        out.append((rel, rp, lines, hits))
    return out, links


def block(lines, i):
    blk = [lines[i]]
    if SCRIPT_CALL.search(lines[i]):
        j = i + 1
        while j < len(lines) and lines[j].strip() != "" and j - i < 30:
            blk.append(lines[j]); j += 1
        return " ".join(x.strip() for x in blk)
    cur = lines[i]
    j = i
    while "||" not in cur and cur.rstrip().endswith("\\") and j + 1 < len(lines):
        j += 1
        cur = lines[j]
        blk.append(cur)
    return " ".join(strip_comment(x).strip().rstrip("\\") for x in blk)


def judge(lines, i):
    text = block(lines, i)
    names = sorted(set(re.findall(r'"\$\{([A-Za-z_][A-Za-z0-9_]*)\[@\]\}"', text)))
    choices = []
    for name in names:
        defs = [m.group(2) for m in (re.match(r"\s*(%s)=\((.*)\)\s*$" % re.escape(name), l)
                                      for l in lines) if m]
        if not defs:
            return -1, "펼칠 수 없는 배열 %s" % name
        choices.append(defs)
    counts = set()
    for combo in itertools.product(*choices):
        t = text
        for name, d in zip(names, combo):
            t = t.replace('"${%s[@]}"' % name, d)
        toks = re.findall(r"project_doc_max_bytes\S*", t)
        bad = [x for x in toks if x != "project_doc_max_bytes=0'"]
        if bad:
            return -1, "`=0` 꼴이 아닌 토큰: %s" % bad[0]
        counts.add(t.count(FLAG))
    if len(counts) != 1:
        return -1, "대입 갈래마다 설정 수가 다르다: %s" % sorted(counts)
    return counts.pop(), ""


def main():
    root = sys.argv[1]
    files = [l.rstrip("\n") for l in sys.stdin if l.strip()]
    ents, links = scan(root, files)
    real = {rp for _, rp, _, _ in ents}
    for rel, rp, lines, hits in ents:
        print("DERIVED\t%s" % rel)
        for i in hits:
            n, note = judge(lines, i)
            print("CALL\t%s:%d\t%d\t%s" % (rel, i + 1, n, note))
    for rel, rp in links:
        if rp not in real:
            print("SYMLINK\t%s\t실체가 도출 집합에 없다" % rel)
        else:
            print("LINKOK\t%s" % rel)


main()
PY

run_scan() {   # <root> ; 표준입력: 파일 목록
  python3 -I "$T/scan.py" "$1"
}

OUT="$(git ls-files | run_scan "$ROOT")"
# `--emit-scanned` — 이 락이 판정한 호출 파일(도출 집합). test_guards_coverage_bidirectional.sh 가 위 선언과 대조한다.
if [ "${1:-}" = "--emit-scanned" ]; then printf '%s\n' "$OUT" | awk -F'\t' '$1 == "DERIVED" { print $2 }'; exit 0; fi
n_run="$(printf '%s\n' "$OUT" | grep -c '^DERIVED')"
if [ "$n_run" -eq 0 ]; then
  no "도출: codex 호출 파일이 0개 — 도출 기준이 깨졌다. 아래 검사는 공허하다"
  finish; exit
fi
ok "도출: 호출 파일 ${n_run}개"

for want in plugins/plugin-audit/scripts/run_audit_codex_reviewer.sh \
            plugins/quality-gates/scripts/run_artifact_codex_reviewer.sh \
            plugins/quality-gates/scripts/run_codex_reviewer.sh \
            shared/docreview/scripts/run_docreview_codex_reviewer.sh; do
  if printf '%s\n' "$OUT" | grep -qxF -- "DERIVED	$want"; then
    ok "양성 대조: ${want##*/} 가 도출 목록에 있다"
  else
    no "양성 대조: $want 가 도출 목록에 없다"
  fi
done

while IFS="	" read -r kind a b c; do
  case "$kind" in
    CALL)
      if [ "$b" = "1" ]; then ok "$a: codex 호출 인자에 설정이 정확히 한 번"
      else no "$a: 설정이 ${b} 번(-1 은 판정 불가) ${c}"; fi ;;
    SYMLINK) no "$a: $b" ;;
    LINKOK) ok "$a: 링크의 실체가 도출 집합에 있다" ;;
  esac
done <<EOF_O
$OUT
EOF_O

# ── 차등 선택 — 도출된 호출 파일 하나만 바뀌어도 qg 의 후보 계산이 이 락을 고르는가 ──────────
# 이름 매핑은 .py/.js 소스만 짝짓는다 — 셸 러너가 바뀔 때 이 락이 고려지는 길은 `# guards:` 뿐이다.
# 격리된 리포에서 잰다(실제 리포에 객체 · 참조를 쓰지 않는다).
SEL="$ROOT/plugins/quality-gates/scripts/compute-test-scope-candidates.sh"
SELF="shared/tests/test_codex_project_doc_off.sh"
sel_has_self() {   # <바뀐 파일(리포 상대)> → 이 락이 후보에 들면 0
  local R="$T/sel"
  rm -rf "$R" && mkdir -p "$R/${SELF%/*}" "$R/$(dirname "$1")" || return 2
  cp "$SEL" "$R/sut.sh" && cp "${SEL%/*}/resolve-baseline.sh" "$R/" && cp "$ROOT/$SELF" "$R/$SELF" || return 2
  printf 'x\n' > "$R/$1"
  ( cd "$R" && git init -q -b main && git config user.email t@t && git config user.name t \
    && git add -A && git commit -qm init \
    && git update-ref refs/remotes/origin/main main \
    && git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main \
    && printf 'changed\n' >> "$1" \
    && bash sut.sh --emit-guards 2>/dev/null ) | grep -qxF -- "$SELF"
}
n_sel=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n_sel=$((n_sel+1))
  if sel_has_self "$f"; then ok "차등 선택: $f 가 바뀌면 이 락이 후보에 든다"
  else no "차등 선택: $f 가 바뀌어도 이 락이 후보에 들지 않는다(\`# guards:\` 를 확인)"; fi
done <<EOF_S
$(printf '%s\n' "$OUT" | awk -F'\t' '$1 == "DERIVED" { print $2 }')
EOF_S
[ "$n_sel" -eq "$n_run" ] || no "차등 선택: 잰 파일 ${n_sel}개가 도출 ${n_run}개와 다르다"

# ── 판별력 대조 ────────────────────────────────────────────────────────────
mkdir -p "$T/c"
FL="-c 'project_doc_max_bytes=0'"
printf '#!/bin/bash\ntimeout 600 codex exec - \\\n    -s read-only \\\n    --json || rc=$?\n' > "$T/c/prefix.sh"
printf '#!/bin/bash\ncodex  exec - \\\n    -s read-only || rc=$?\n' > "$T/c/dblspace.sh"
printf '#!/bin/bash\ncodex exec -C x -s read-only - < in || rc=$?\n' > "$T/c/optfirst.sh"
printf '#!/bin/bash\n"$CODEX_BIN" exec - \\\n    --json || rc=$?\n' > "$T/c/bin.sh"
printf "#!/bin/bash\ncodex exec - \\\\\n    $FL \\\\\n    $FL \\\\\n    --json || rc=\$?\n" > "$T/c/dup.sh"
printf "#!/bin/bash\ncodex exec - \\\\\n    -c 'project_doc_max_bytes=1' \\\\\n    --json || rc=\$?\n" > "$T/c/badval.sh"
printf "#!/bin/bash\ncodex exec - \\\\\n    --json || rc=\$?  # $FL\n" > "$T/c/commented.sh"
printf "#!/bin/bash\nA=(-c 'x=1')\nA=($FL)\ncodex exec - \\\\\n    \"\${A[@]}\" || rc=\$?\n" > "$T/c/arr2.sh"
printf "#!/bin/bash\nA=($FL)\ncodex exec - \\\\\n    \"\${A[@]}\" \\\\\n    --json || rc=\$?\n" > "$T/c/arr1.sh"
printf "#!/bin/bash\ntimeout 9 codex exec -C x - \\\\\n    $FL || rc=\$?\n" > "$T/c/okprefix.sh"
printf 'import subprocess\nsubprocess.run(["codex", "exec", "-"],\n    input=b"")\n' > "$T/c/call.py"

ctl() {   # <파일> <기대값> <메시지>
  local r
  r="$(printf '%s\n' "$1" | run_scan "$T/c" | grep '^CALL' | head -1 | cut -f3)"
  assert_eq "$r" "$2" "$3"
}
ctl prefix.sh 0 "음의 대조: timeout 접두 호출도 도출되고 설정 없음으로 센다"
ctl dblspace.sh 0 "음의 대조: 공백 둘 \`codex  exec\` 도 도출된다"
ctl optfirst.sh 0 "음의 대조: \`codex exec -C x -s read-only -\` 도 도출된다"
ctl bin.sh 0 "음의 대조: \"\$CODEX_BIN\" exec 도 도출된다"
ctl call.py 0 "음의 대조: python subprocess 호출도 도출된다"
ctl dup.sh 2 "음의 대조: 설정이 둘이면 2"
ctl badval.sh -1 "음의 대조: =0 꼴이 아닌 값은 판정 불가로 실패"
ctl commented.sh 0 "음의 대조: 줄 끝 주석 안의 설정은 세지 않는다"
ctl arr2.sh -1 "음의 대조: 두 번 대입된 배열은 갈래마다 따지고 한 갈래라도 빠지면 실패"
ctl arr1.sh 1 "양의 대조: 한 번 대입된 배열은 펼쳐 1 로 센다"
ctl okprefix.sh 1 "양의 대조: 접두가 붙어도 설정이 있으면 1"
finish
