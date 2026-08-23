#!/usr/bin/env bash
# 스킬이 플러그인 루트를 어떻게 해석하는지 잰다. 두 축이다.
#
# `CLAUDE_PLUGIN_ROOT` 는 Bash 도구 환경에 없다(2.1.239 실측). command 계층의 `!`
# 펜스는 하니스가 치환하지만 skill 의 지시는 모델이 Bash 도구로 실행하므로 치환이
# 없다 — bare 참조는 `/scripts/...` 로 확장된다.
#
# **축 A — 펜스 단위.** Bash 도구는 호출마다 새 셸이라 대입이 다음 펜스로 넘어가지
# 않는다. 스킬 상단 1회 대입은 두 번째 펜스부터 조용히 깨진다. 그래서 "파일 어딘가에
# fallback 이 있다"가 아니라 "그 펜스 안에 있다"를 잰다.
#
# **축 B — 본문 전수.** 실행 지시는 펜스 밖에도 있다: ``Run `<path>/scripts/x.sh` ``
# 같은 산문 인라인이 그것이다. 축 A 만 두면 그런 지시가 락 밖에 남고, 새 파일이나
# 태그 없는 펜스를 쓰는 스킬은 통째로 샌다(2026-08-23 리뷰 지적). 그래서 본문에는
# bare 참조가 **한 곳도** 없어야 한다. frontmatter 는 제외한다 — 거기의
# `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/...)` 는 실행 지시가 아니라 권한 패턴이고,
# 하니스가 그 표기 그대로 매칭한다(치환하면 권한이 깨진다).
#
# 파싱은 python 으로 한다 — 셸 본문 추출기는 조용히 깨진다(중첩 펜스·따옴표).
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"

report="$(python3 - "$ROOT/plugins/quality-gates/skills" <<'PY'
import sys, pathlib, re
root = pathlib.Path(sys.argv[1])
FENCE = re.compile(r"^```bash\n(.*?)^```", re.M | re.S)
FM    = re.compile(r"\A---\n.*?\n---\n", re.S)
VAR   = re.compile(r"\$\{CLAUDE_PLUGIN_ROOT(?!:-)")   # `:-` 가 뒤따르지 않는 참조
fences = fence_bad = bare = 0
for md in sorted(root.rglob("*.md")):
    txt = md.read_text(encoding="utf-8")
    body = FM.sub("", txt, count=1)
    off  = len(txt) - len(body)
    # 축 A
    for m in FENCE.finditer(body):
        b = m.group(1)
        if "CLAUDE_PLUGIN_ROOT" not in b:
            continue
        fences += 1
        if "CLAUDE_PLUGIN_ROOT:-" not in b:
            fence_bad += 1
            print(f"FENCE_NO_FALLBACK\t{md.relative_to(root)}:{txt[:off+m.start()].count(chr(10))+1}")
    # 축 B
    for m in VAR.finditer(body):
        bare += 1
        print(f"BARE\t{md.relative_to(root)}:{txt[:off+m.start()].count(chr(10))+1}")
print(f"FENCES\t{fences}")
print(f"FENCE_BAD\t{fence_bad}")
print(f"BARE_TOTAL\t{bare}")
PY
)"
printf '%s\n' "$report" | grep -vE '^(FENCES|FENCE_BAD|BARE_TOTAL)' | sed 's/^/    /'

n_fences="$(printf '%s\n' "$report" | awk -F'\t' '$1=="FENCES"{print $2}')"
n_fbad="$(printf '%s\n'   "$report" | awk -F'\t' '$1=="FENCE_BAD"{print $2}')"
n_bare="$(printf '%s\n'   "$report" | awk -F'\t' '$1=="BARE_TOTAL"{print $2}')"

# 비-vacuous: 검사 대상 펜스가 실재해야 한다. 0곳이면 축 A 는 아무것도 안 잰다.
[ "${n_fences:-0}" -ge 20 ] \
  && ok "축 A 대상 bash 펜스 ${n_fences}곳 — vacuous 아님" \
  || no "축 A 대상 펜스가 ${n_fences:-0}곳뿐 — 코퍼스 도출이 무너졌다(태그·경로 변경?)"

[ "${n_fbad:-1}" -eq 0 ] \
  && ok "축 A: 그 변수를 쓰는 모든 bash 펜스가 같은 펜스 안에서 fallback 을 대입한다" \
  || no "축 A: fallback 없는 펜스 ${n_fbad}곳 — Bash 도구에서 /scripts/... 로 확장된다"

[ "${n_bare:-1}" -eq 0 ] \
  && ok "축 B: 스킬 본문에 bare 참조가 없다 (산문 인라인·태그 없는 펜스 포함)" \
  || no "축 B: 본문 bare 참조 ${n_bare}곳 — 펜스 밖 실행 지시가 락을 빠져나간다"

# 양성 대조 — 이 락의 전제(형제 플러그인도 같은 계약)가 살아 있는지.
grep -q 'CLAUDE_PLUGIN_ROOT:-' "$ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md" \
  && ok "양성 대조: spec-distill 도 같은 계약을 쓴다" \
  || no "양성 대조 실패: spec-distill 쪽 계약이 사라졌다 — 이 락의 전제가 무너졌다"

finish
