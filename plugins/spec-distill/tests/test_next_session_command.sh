#!/usr/bin/env bash
# guards: plugins/spec-distill/**
#
# 다음 세션 명령 — 정본 `references/proceed-gate.md` 의 `## 다음 세션 명령` 절과 그 채택자.
#
# 채택자는 정본 포인터에서 도출한다(`shared/tests/adopter_derivation.sh`, 바닥 3). 채택자마다 자기 표면
# (SKILL.md + references/*.md)에서 잰다:
#   - 단독 줄 `**다음 세션 줄 — ①/② 공통**` 이 정확히 하나이고, 그 아래 첫 비지 않은 줄이 `> `…`` 인용 줄이다.
#   - 다음 세션 줄 모양의 인용 줄이 표면 전체에 정확히 하나다. 세는 것은 인용 줄뿐이다 —
#     `> `@<` · `> `/<plugin>:<skill> @` 로 시작하는 줄(들여쓰기 허용). 코드 펜스나 인라인 코드 안의 사본은 세지 않는다.
#     ①·② 가 줄을 따로 정의하거나 표지 밖에 인용 줄을 두면 2 가 된다.
#   - slash 줄: skill 이름 바로 뒤 `@<…>` 토큰 수 ≤ 정본 한도 표의 그 받는 쪽 수. 락은 숫자를 들지 않는다.
#   - 평문 줄: `@<…>` 토큰으로 시작하고 토큰 뒤에 `Skill ` 호출이 온다. 절대경로 치환 · 거부 advisory 문구 ·
#     「git 작업 트리 루트의 절대경로를 함께 낸다」 · 「경로에 공백이 있으면」 가 표면에 있다.
#   - 꺾쇠 자리표는 줄 앞 `@<…>` 토큰에만 있다. 원소(토큰)가 늘어도 통과한다.
#   - 표면에 `따로 입력` 이 있다.
# 표면 파일 목록은 bash 가 도출해 `채택자디렉토리::파일1::파일2…` 인자로 파서에 넘긴다(파서는 glob 하지 않는다).
# 그 목록은 presence 코퍼스 가드(`assert_presence_corpus_skill_owned`)를 지난다 — 정본은 코퍼스 밖이다.
# 정본 절 단언에는 그 절을 실제로 읽었다는 양성 짝이 붙는다.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
CANON="$SD/references/proceed-gate.md"
CANON_REF='references/proceed-gate\.md'
. "$REPO_ROOT/shared/tests/assert.sh"
. "$REPO_ROOT/shared/tests/adopter_derivation.sh"
. "$REPO_ROOT/shared/tests/presence_corpus.sh"

derive_reference_adopters "$SD" "$CANON_REF" "$REPO_ROOT" 0
if [ "${1:-}" = "--emit-scanned" ]; then
  { printf '%s' "$SCANNED"; printf '%s\n' "$CANON"; } | sed "s|^$REPO_ROOT/||"
  exit 0
fi

n_adopt=0
ADOPTER_ARGS=()
while IFS= read -r a; do
  [ -n "$a" ] || continue
  n_adopt=$((n_adopt + 1))
  ADOPTER_ARGS+=("$a")
done < <(printf '%s' "$ADOPTERS")
if [ "$n_adopt" -ge 3 ]; then
  ok "채택자 ${n_adopt}개 도출 (정본 포인터, 바닥 3)"
else
  no "채택자 ${n_adopt}개 — 바닥 3 미만이다. 포인터를 잃은 skill 이 측정 밖으로 나갔다"
fi
if [ ! -f "$CANON" ]; then
  no "정본 ${CANON} 부재"
  finish; exit $?
fi

# 채택자별 표면(SKILL.md + references/*.md)을 bash 가 도출한다 — 파서는 이 목록만 읽는다.
SURFACE_ARR=()
SURFACE_ARGS=()
for a in "${ADOPTER_ARGS[@]+"${ADOPTER_ARGS[@]}"}"; do
  arg="$a"
  for f in "$a/SKILL.md" "$a"/references/*.md; do
    [ -f "$f" ] || continue
    SURFACE_ARR+=("$f")
    arg="${arg}::${f}"
  done
  SURFACE_ARGS+=("$arg")
done
assert_presence_corpus_skill_owned "다음 세션 줄 채택자 표면" "${SURFACE_ARR[@]+"${SURFACE_ARR[@]}"}"
canon_in=0
for f in "${SURFACE_ARR[@]+"${SURFACE_ARR[@]}"}"; do
  [ "$f" = "$CANON" ] && canon_in=1
done
if [ "$canon_in" -eq 1 ]; then
  no "코퍼스: 정본($CANON)이 스캔 대상에 들어 있다 — 앵커 리터럴을 담은 파일이라 단언이 그것으로 만족된다"
else
  ok "코퍼스: 정본이 스캔 대상에 없다 (자기 만족 불가)"
fi

tmp="$(mktemp)" || { no "mktemp 실패 — 측정하지 못했다"; finish; exit $?; }
trap 'rm -f "$tmp"' EXIT
PYTHONDONTWRITEBYTECODE=1 python3 - "$CANON" "${SURFACE_ARGS[@]+"${SURFACE_ARGS[@]}"}" >"$tmp" <<'PY'
import pathlib
import re
import sys

MARK = "**다음 세션 줄 — ①/② 공통**"
TOKEN = r"@<[^<>]+>"
LINE_SHAPE = re.compile(r"^\s*> `(@<|/[\w-]+:[\w-]+ @)")
out = []


def ok(m):
    out.append("OK\t" + m)


def no(m):
    out.append("NO\t" + m)


def flat(s):
    return " ".join(s.split())


canon = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
m = re.search(r"^## 다음 세션 명령\n(.*?)(?=^## |\Z)", canon, re.S | re.M)
sec = m.group(1) if m else ""
if sec.strip():
    ok("정본(양성): `## 다음 세션 명령` 절을 읽었다")
else:
    no("정본: `## 다음 세션 명령` 절이 없다 — 아래 정본 단언이 공허하다")
fsec = flat(sec)
for label, needle in [
    ("규칙 1 두 줄 따로", "두 줄을 따로 입력하라는 안내"),
    ("규칙 2 경로 목록", "각 skill 은 읽힐 경로 목록(1개 이상)을 정한다"),
    ("규칙 2 토큰 반복", "원소마다 `@<경로>` 토큰을 하나씩"),
    ("규칙 3 받는 쪽이 모양을 정한다", "줄의 모양은 받는 쪽이 정한다"),
    ("규칙 5 평문 줄은 절대경로", "평문 줄의 경로는 **절대경로**로 쓴다"),
    ("규칙 5 slash 줄은 받는 쪽 기준", "slash 줄의 경로는 받는 쪽이 푸는 기준으로 쓴다"),
    ("규칙 5 치환 · 공백 거부", "치환하지 않은 자리표가 하나라도 남거나 경로에 공백이 있으면 노출하지 않는다"),
    ("규칙 6 Step A 전 원소", "원소 하나라도 working-tree 에 없으면 명령을 노출하지 않는다"),
    ("규칙 7 위치 공시", "git 작업 트리 루트의 절대경로를 낸다"),
    ("표지 정의", MARK),
]:
    (ok if needle in fsec else no)(f"정본 {label}: {needle}")

limits = {}
for row in re.finditer(r"^\s*\|\s*`([^`]+)`\s*\|[^|\n]*\|\s*(\d+)\s*\|\s*$", sec, re.M):
    limits[row.group(1)] = int(row.group(2))
if "spec-distill:spec-interview" in limits:
    ok(f"정본 한도 표(양성): spec-distill:spec-interview 한도 {limits['spec-distill:spec-interview']} 를 읽었다")
else:
    no("정본 한도 표: spec-distill:spec-interview 행이 없다 — slash 줄 한도를 잴 수 없다")
if re.search(r"^\s*\|\s*외부 skill[^|\n]*\|[^|\n]*\|\s*제한 없음\s*\|\s*$", sec, re.M):
    ok("정본 한도 표: 외부 skill(평문 줄) = 제한 없음")
else:
    no("정본 한도 표: 외부 skill(평문 줄) 행이 없다")

for d in sys.argv[2:]:
    parts = d.split("::")
    d = pathlib.Path(parts[0])
    name = d.name
    files = [pathlib.Path(x) for x in parts[1:]]
    texts = {f: f.read_text(encoding="utf-8").splitlines() for f in files}
    body = flat("\n".join("\n".join(t) for t in texts.values()))
    (ok if "따로 입력" in body else no)(f"{name}: 표면에 「따로 입력」 안내가 있다")
    marks = [(f, i) for f in files for i, l in enumerate(texts[f]) if l.strip() == MARK]
    if len(marks) != 1:
        no(f"{name}: 표지 줄이 {len(marks)}개 — 정확히 1개여야 한다")
        continue
    ok(f"{name}: 표지 줄 1개 ({marks[0][0].name}:{marks[0][1] + 1})")
    f, i = marks[0]
    rest = [l for l in texts[f][i + 1:] if l.strip()]
    nxt = rest[0] if rest else ""
    q = re.fullmatch(r"> `(.+)`", nxt)
    if not q:
        no(f"{name}: 표지 아래 첫 줄이 인용 줄 `> `…`` 이 아니다: {nxt[:80]}")
        continue
    line = q.group(1)
    shaped = [f"{g.name}:{j + 1}" for g in files for j, l in enumerate(texts[g]) if LINE_SHAPE.match(l)]
    if len(shaped) == 1:
        ok(f"{name}: 다음 세션 줄 모양의 인용 줄이 표면에 1개")
    else:
        no(f"{name}: 다음 세션 줄 모양의 인용 줄이 {len(shaped)}개 — ①·② 가 줄을 따로 정의했거나 표지 밖에 줄이 있다: {shaped}")
    if line.startswith("/"):
        s = re.match(rf"/([\w-]+:[\w-]+)((?: {TOKEN})+)(?= |$)", line)
        if not s:
            no(f"{name}: slash 줄인데 skill 이름 바로 뒤에 `@<…>` 토큰이 없다: {line[:80]}")
            continue
        recv = s.group(1)
        n = len(re.findall(TOKEN, s.group(2)))
        tail = line[s.end():]
        if recv not in limits:
            no(f"{name}: slash 줄의 받는 쪽 {recv} 이 정본 한도 표에 없다")
        elif n <= limits[recv]:
            ok(f"{name}: slash 줄 @ 토큰 {n}개 ≤ {recv} 한도 {limits[recv]}")
        else:
            no(f"{name}: slash 줄 @ 토큰 {n}개 > {recv} 한도 {limits[recv]}")
    else:
        p = re.match(rf"((?:{TOKEN} )+)", line)
        if not p:
            no(f"{name}: 평문 줄이 `@<…>` 토큰으로 시작하지 않는다: {line[:80]}")
            continue
        n = len(re.findall(TOKEN, p.group(1)))
        tail = line[p.end():]
        ok(f"{name}: 평문 줄이 @ 토큰 {n}개로 시작한다")
        (ok if "Skill " in tail else no)(f"{name}: 평문 줄이 토큰 뒤에 부를 skill(`Skill …`)을 잇는다")
        for needle in ("절대경로로 치환한 뒤 노출한다",
                       "경로에 공백이 있으면 노출하지 않고 `[spec-distill] 다음 세션 줄을 만들 수 없다",
                       "직접 첨부하고 아래 문장을 그대로 붙여 넣어",
                       "git 작업 트리 루트의 절대경로를 함께 낸다",
                       "`@` 토큰을 뗀 나머지 문장을 그대로 보인 뒤 멈춘다"):
            (ok if needle in body else no)(f"{name}: 평문 줄 규칙 문구 — {needle}")
    left = re.findall(r"<[^<>]+>", tail)
    if left:
        no(f"{name}: 꺾쇠 자리표가 줄 앞 @ 토큰 밖에 있다: {left}")
    else:
        ok(f"{name}: 꺾쇠 자리표는 줄 앞 @ 토큰에만 있다")

print("\n".join(out))
print("END")
PY
prc=$?
if [ "$prc" -ne 0 ]; then
  no "파서 실패(rc=${prc}) — 측정하지 못했다"
  cat "$tmp"
fi
grep -qx 'END' "$tmp" || no "파서 출력이 끝까지 오지 않았다(END 없음) — 단언이 잘렸다"
while IFS=$'\t' read -r kind msg; do
  case "$kind" in
    OK) ok "$msg" ;;
    NO) no "$msg" ;;
  esac
done < "$tmp"
finish
