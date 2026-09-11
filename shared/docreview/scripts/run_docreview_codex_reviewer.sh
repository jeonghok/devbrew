#!/usr/bin/env bash
# run_docreview_codex_reviewer.sh — 문서 리뷰 엔진(shared/docreview)의 codex co-reviewer. 정본.
#
# **처분** — consumer=orchestrator · fail-open · disclosure=advisory
#
# 실제 소비자는 같은 엔진의 docreview_route.py(§6.3 라우팅의 codex 입력)다. 이 파일은
# spec-distill·quality-gates 두 플러그인에 같은 파일 단위 심볼릭 링크로 배포되므로(설계
# §12 「신규(호스트)」) consumer= 경로가 어느 한 플러그인과도 같을 수 없다(처분 락 축 A⑤
# — 이 파일 자체가 애초에 어느 플러그인 서브트리에도 없다). 그래서 orchestrator 로 적고
# 실제 소비자는 이 주석이 밝힌다. fail-open 인 이유는 형제 run_brief_codex_reviewer.sh 와
# 같다 — codex 는 모델 다양성 보조지 주 판정자가 아니다(설계 §9 「codex 부재·실패」행:
# 공시하되 막지 않는다).
#
# Usage: run_docreview_codex_reviewer.sh <profile.md> <doc-or-bundle> <project_dir> <out_yaml>
# 성공·실패 모두 <out_yaml> 에 codex_findings_to_yaml.py --emit-keys docreview 스키마의
# 중첩 YAML 을 쓴다. <out_yaml> 자체를 못 쓰면(디렉토리 부재·권한·RO 마운트) YAML 이
# 애초에 불가능하므로 rc 3 으로 죽는다 — 호출자는 rc==3 을 보면 <out_yaml> 을 지워야
# 한다(형제 run_brief_codex_reviewer.sh·run_seed_codex_reviewer.sh 와 같은 계약. 이 fail-
# closed 가 핵심이다 — 조용히 죽으면 직전 라운드의 stale YAML 이 이번 라운드 판정으로
# 읽힌다).
#
# 프롬프트 빌더는 자리별 파일(build_*_codex_prompt.py)로 안 뽑는다 — 문서 리뷰 엔진은
# 프로필 넷을 전부 이 러너 하나로 흡수하므로(설계 §5.2), 빌더는 아래 인라인 python 함수
# 하나다.
set -euo pipefail

PROFILE="${1:-}"
DOC="${2:-}"
PROJECT_DIR="${3:-}"
OUTPUT_PATH="${4:-}"

# CLAUDE_PLUGIN_ROOT는 훅 실행에만 주입된다 — 스킬의 bash 블록에는 오지 않는다.
# fallback 없이 참조하면 `set -u` 아래서 codex에 도달하기 전에 즉사한다. 형제
# 러너들과 같은 철자를 쓴다(세 번째 철자를 발명하지 않는다).
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

if [[ -z "$OUTPUT_PATH" ]]; then
  echo "usage: run_docreview_codex_reviewer.sh <profile> <doc-or-bundle> <project_dir> <out_yaml>" >&2
  exit 2
fi

# 절대화는 `cd "$PROJECT_DIR"` **이전**이다 — 아니면 상대 경로가 project_dir 기준으로
# 조용히 잘못 풀린다(형제 러너들이 B3 에서 얻은 교훈과 같은 자리).
[[ "$OUTPUT_PATH" = /* ]] || OUTPUT_PATH="$PWD/$OUTPUT_PATH"
[[ "$DOC" = /* ]] || DOC="$PWD/$DOC"
[[ "$PROFILE" = /* ]] || PROFILE="$PWD/$PROFILE"

# stale 제거 + 쓰기 가능성 확인을 자원을 처음 만지는 지점에서 한다. 여기서 실패하면
# YAML 자체가 불가능하므로 rc 3 — 호출자가 <out_yaml> 을 지워야 한다는 계약의 근거다.
: > "$OUTPUT_PATH" 2>/dev/null || {
  echo "[docreview] 산출물 경로에 쓸 수 없다: $OUTPUT_PATH" >&2
  exit 3
}

# `write_failclosed` · `_degrade_if_empty` 는 shared/codex/runner_common.sh 정본을
# 그대로 쓴다(설계 §5.2 표 「reviewing-document.md」 행의 의존). source 를 가드한다 —
# 위 guarded truncate 가 이미 OUTPUT_PATH 를 0바이트로 만들어 놨고 트랩은 아직
# 안 떴다. source 실패가 `set -e` 아래서 즉사하면 0바이트 산출물이 "성공, 발견 0건"
# 으로 읽힌다.
# shellcheck source=/dev/null
_RUNNER_COMMON="$(dirname -- "${BASH_SOURCE[0]}")/runner_common.sh"
if [ -r "$_RUNNER_COMMON" ] && bash -n "$_RUNNER_COMMON" 2>/dev/null \
   && . "$_RUNNER_COMMON"; then
  :
else
  printf 'findings: []\nmeta:\n  codex_failed: true\n  reason: runner_common_unloadable\n  exit_code: 0\n' \
    > "$OUTPUT_PATH" 2>/dev/null || {
      echo "[docreview] runner_common.sh 로드 실패 + 산출물 기록 실패 — 호출자는 stale 을 지워야 한다" >&2
      exit 3
    }
  echo "[docreview] runner_common.sh 를 로드할 수 없다 — degrade 기록 후 종료(공유 정본 미배포)" >&2
  exit 0
fi
emit_fallback() { write_failclosed "$OUTPUT_PATH" "$1" || exit 3; exit 0; }

[[ -n "$PROJECT_DIR" ]] || emit_fallback missing_project_dir
[[ -f "$PROFILE" ]] || emit_fallback profile_missing
[[ -f "$DOC" ]] || emit_fallback doc_missing
cd "$PROJECT_DIR" || emit_fallback project_dir_unreachable

# 스크래치 디렉토리 대입은 트랩 무장 **이전**이다(`cd ""` repo-delete footgun 회피).
SCRATCH="$(mktemp -d -t docreview-codex-XXXXXX)" || emit_fallback scratch_dir_uncreatable
# 트랩 한 줄 — 여러 줄로 펼치면 순서 락이 이 줄을 못 보고 무력화된다(형제 러너 계약과 같다).
trap 'rm -rf "$SCRATCH"; _degrade_if_empty "$OUTPUT_PATH" aborted_before_completion' EXIT
PROMPT_FILE="$SCRATCH/prompt.md"
WEB_META_FILE="$SCRATCH/web.meta"
STDOUT_FILE="$SCRATCH/codex.jsonl"
STDERR_FILE="$SCRATCH/codex.stderr"

# 프롬프트 조립(러너 안 인라인 빌더) — 프로필의 frontmatter(`ground_truth` · `layer_rubric` ·
# `allowed_dispositions` · `web`) · 프로필 본문(검토 항목 — 탐지·재비판 agent 가 읽는 것과
# 같은 루브릭) · shared/codex/prompt-preamble.md(P21) 로 프롬프트 하나를 낸다. `web` 판정을 **같은 호출에서** WEB_META_FILE 에 함께 써서, frontmatter
# 파싱을 두 번(프롬프트용 · 웹 스위치용) 하지 않는다 — 파싱이 한 곳이면 그 결과를 두
# 갈래로 읽는 자리가 하나이므로 웹 인자를 만드는 지점도 하나로 유지하기 쉽다(P11).
# 빌더의 rc 와 그것이 남기는 fail-closed 사유(이 러너의 사유 목록은 이 주석과 앞쪽의
# `emit_fallback` 호출들이 전부다):
#   0 성공 · 1 `prompt_build_failed`(층 1·처분 도출 실패) · 3 `ground_truth_empty`(없음·빔·
#   null·목록 — 게이트와 같은 이름) · 4 `profile_body_empty`(본문이 공백뿐 — 게이트와 같은 이름) ·
#   5 `profile_parse_ambiguous`(이 stdlib 파서가 게이트(PyYAML)와 같은 값을 읽는다고 보장할 수
#   없는 모양 — 추측해서 읽지 않고 멈춘다: 따옴표·flow 스칼라가 열린 채 컬럼 0 에 온 줄 · `\n`
#   밖의 줄바꿈 · 콜론 앞 공백 · 앵커·태그·별칭 · escape 있는 큰따옴표 · 문자열이 아닌 평문 ·
#   매핑 모양 · 문단 있는 접힘 스칼라 · 못 읽는 목록 모양 · bool 이 아닌 web).
# `DOCREVIEW_CODEX_PARSED_OUT=<경로>` 가 있으면 빌더가 읽은 frontmatter 값(`_read` 경로 → 값)을
# 그 경로에 JSON 으로 남긴다 — 게이트와의 등식 대조(test_docreview_codex.sh)가 쓰는 관측 채널.
BUILD_RC=0
python3 - "$PROFILE" "$DOC" "$PLUGIN_ROOT/scripts/prompt-preamble.md" "$WEB_META_FILE" \
       > "$PROMPT_FILE" <<'PY' || BUILD_RC=$?
import json, os, pathlib, re, sys

prof_path, doc_path, preamble_path, meta_path = sys.argv[1:5]

# stdout 을 UTF-8 로 고정한다 — 프로필 본문(한국어)이 ascii 계열 stdout 인코딩에서
# UnicodeEncodeError 로 빌더를 죽이지 않게. 형제 빌더의 `configure_stdout()`
# (shared/codex/codex_prompt_common.py)과 같은 가드다(이 러너는 그 모듈을 import 하지 않는다).
try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, OSError, ValueError):
    pass

t = pathlib.Path(prof_path).read_text(encoding="utf-8")
m = re.match(r"^---\n(.*?)\n---\n", t, re.DOTALL)
fm_text = m.group(1) if m else ""
# 본문 = frontmatter 를 닫는 `---` 뒤 전부 — `load_profile()` 이 `body` 로 돌려주는 것과 같은 자리.
body = t[m.end():] if m else ""


class _Ambiguous(Exception):
    """이 파서가 게이트(`load_profile()`, PyYAML)와 같은 값을 읽는다고 보장할 수 없는 모양.
    추측해서 읽지 않는다 — rc 5 → `profile_parse_ambiguous`."""


def _ambiguous(why):
    raise _Ambiguous(why)


# 읽기 지점마다 `_read("<게이트 JSON 경로>", 값)` 을 거친다. 락이 이 호출들을 AST 로 도출해 게이트가
# 같은 경로에서 읽은 값과 등식 대조하므로, 새 필드를 읽으면 대조에 저절로 들어간다(R38 a).
PARSED = {}


def _read(path, value):
    PARSED[path] = value
    return value


# PyYAML(YAML 1.1) 암묵 해석기 중 문자열이 아닌 것 — PyYAML resolver.py 의 정규식 그대로다(re.X).
# 평문 스칼라가 여기 맞으면 PyYAML 은 문자열이 아닌 값(bool·float·int·merge·null·timestamp·value)
# 으로 읽는다.
_NONSTR_PLAIN = [re.compile(p, re.X) for p in (
    r"""^(?:yes|Yes|YES|no|No|NO|true|True|TRUE|false|False|FALSE|on|On|ON|off|Off|OFF)$""",
    r"""^(?:[-+]?(?:[0-9][0-9_]*)\.[0-9_]*(?:[eE][-+][0-9]+)?
         |\.[0-9][0-9_]*(?:[eE][-+][0-9]+)?
         |[-+]?[0-9][0-9_]*(?::[0-5]?[0-9])+\.[0-9_]*
         |[-+]?\.(?:inf|Inf|INF)
         |\.(?:nan|NaN|NAN))$""",
    r"""^(?:[-+]?0b[0-1_]+
         |[-+]?0[0-7_]+
         |[-+]?(?:0|[1-9][0-9_]*)
         |[-+]?0x[0-9a-fA-F_]+
         |[-+]?[1-9][0-9_]*(?::[0-5]?[0-9])+)$""",
    r"""^(?:<<)$""",
    r"""^(?:~|null|Null|NULL|)$""",
    r"""^(?:[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]
         |[0-9][0-9][0-9][0-9]-[0-9][0-9]?-[0-9][0-9]?
          (?:[Tt]|[ \t]+)[0-9][0-9]?
          :[0-9][0-9]:[0-9][0-9](?:\.[0-9]*)?
          (?:[ \t]*(?:Z|[-+][0-9][0-9]?(?::[0-9][0-9])?))?)$""",
    r"""^(?:=)$""",
)]
_NULL_PLAIN = re.compile(r"^(?:~|null|Null|NULL)$")
_YAML_TRUE = ("yes", "Yes", "YES", "true", "True", "TRUE", "on", "On", "ON")
_YAML_FALSE = ("no", "No", "NO", "false", "False", "FALSE", "off", "Off", "OFF")


def _indent(ln):
    return len(ln) - len(ln.lstrip(" "))


def _scan_frontmatter(fm):
    # 헤더 정규식·`_block_span`·`_flow_list` 는 「컬럼 0 의 `key:` 줄은 최상위 키다」에 기댄다. 그
    # 전제는 block scalar 에서만 참이다 — PyYAML 은 **따옴표 스칼라의 연속줄과 flow 컬렉션**을
    # 컬럼 0 에서도 받고, `\n` 밖의 줄바꿈(`\r` `\x85` U+2028 U+2029)도 줄 경계로 본다(리뷰 I1·M3
    # 실측: flow 매핑 연속줄에 둔 컬럼-0 `web: true` 를 게이트는 defer_target 의 값으로, 러너는
    # 최상위 web 으로 읽었다). 그 모양을 만나면 값을 추측하지 않고 멈춘다. 게이트가 받는 평범한
    # 모양(한 줄 따옴표 · 한 줄 flow · 들여쓴 연속줄 · block scalar)은 통과한다.
    for ch in ("\r", "\x85", "\u2028", "\u2029"):
        if ch in fm:
            _ambiguous("line break other than LF")
    stack = []
    block_indent = None
    for line in fm.split("\n"):
        if block_indent is not None:
            if not line.strip() or _indent(line) > block_indent:
                continue
            block_indent = None
        if stack:
            if line.strip() and line[:1] != " ":
                _ambiguous("column-0 line inside an open quoted or flow scalar")
            pos = 0
        else:
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            if re.match(r"^[ \t]*[A-Za-z_][\w.-]*[ \t]+:(?:[ \t]|$)", line):
                _ambiguous("whitespace before ':' in a key")
            km = re.match(r"^[ \t]*(?:-[ \t]+)?(?:[^\s#'\"\[{][^:#]*:(?:[ \t]+|$))?", line)
            pos = km.end()
            pos += re.match(r"(?:[&!]\S*[ \t]+)*", line[pos:]).end()
            if re.match(r"[|>][+-]?[0-9]?[ \t]*(?:#.*)?$", line[pos:]):
                block_indent = _indent(line)
                continue
            if line[pos:pos + 1] not in ("\"", "'", "[", "{"):
                continue
        i, started = pos, bool(stack)
        while i < len(line):
            c = line[i]
            if not stack:
                if started:
                    break
                stack.append(c)
                started = True
            elif stack[-1] == "\"":
                if c == "\\":
                    i += 1
                elif c == "\"":
                    stack.pop()
            elif stack[-1] == "'":
                if c == "'":
                    if line[i + 1:i + 2] == "'":
                        i += 1
                    else:
                        stack.pop()
            elif c in "\"'[{":
                stack.append(c)
            elif c in "]}":
                stack.pop()
            elif c == "#" and line[i - 1:i] in (" ", "\t"):
                break
            i += 1
    if stack:
        _ambiguous("unclosed quoted or flow scalar")


def _quoted(s, where):
    # 한 덩어리 따옴표 스칼라(+ 꼬리 주석). 큰따옴표의 escape(`\`)는 해석하지 않고 멈춘다(게이트는
    # escape 를 푼다 — 같은 값을 보장할 수 없다). 작은따옴표의 `''` 는 YAML 규칙대로 `'` 다.
    qm = re.match(r"^\"([^\"\\]*)\"(?:[ \t]+#.*)?$", s)
    if qm:
        return qm.group(1)
    qm = re.match(r"^'((?:[^']|'')*)'(?:[ \t]+#.*)?$", s)
    if qm:
        return qm.group(1).replace("''", "'")
    _ambiguous("unreadable quoted scalar: " + where)


def _plain(val, where):
    # 평문 스칼라 — PyYAML 이 **같은 문자열**로 읽는 모양만 받는다.
    if (re.match(r"^(?:[-?:](?:[ \t]|$)|[,\[\]{}#&*!|>'\"%@`])", val)
            or re.search(r":(?:[ \t]|$)", val)):
        _ambiguous("unreadable plain scalar: " + where)
    if any(p.match(val) for p in _NONSTR_PLAIN):
        _ambiguous("non-string plain scalar: " + where)
    return val


def _item(raw, where):
    raw = raw.strip()
    if raw[:1] in ("\"", "'"):
        return _quoted(raw, where)
    return _plain(raw, where)


def _web(text):
    # YAML 1.1 진리값 — PyYAML SafeLoader 는 yes·true·on(과 반대말)을 소문자·첫 글자 대문자·
    # 전부 대문자 세 표기로만 bool 로 읽는다(resolver.py). 키는 대소문자를 가린다(`Web:` 은 다른
    # 키다). **`web:` 줄 자체의 마지막 occurrence 를 먼저 고르고 그 값을 해석한다** — 값 패턴으로
    # last-match 하면 `web: true` 뒤 `web: false` 에서 앞의 true 를 고른다(리뷰 F-5 항목 5).
    # 어휘 밖의 값(따옴표 · 태그 · 빈 값 · 다음 줄의 값)은 같은 값을 보장할 수 없어 멈춘다. 키가
    # 없으면 꺼짐이다(웹이 켜지는 쪽으로 추측하지 않는다).
    wm = _last_match(r"(?m)^web:([^\n]*)$", text)
    if wm is None:
        return False
    val = re.sub(r"(?:^|[ \t]+)#.*$", "", wm.group(1)).strip()
    if val in _YAML_TRUE:
        return True
    if val in _YAML_FALSE:
        return False
    _ambiguous("web is not a YAML boolean")

# PyYAML 없이 stdlib 만으로 — 형제 프롬프트 빌더들(build_brief_codex_prompt.py ·
# build_seed_codex_prompt.py 등)이 third-party 모듈을
# 안 쓰는 것과 같은 이유다: 이 러너는 `HOME` 이 격리되는 하니스(예: codex 인증
# 격리)에서 site-packages 의 PyYAML 에 닿지 못해 죽는다(실측 — 이 파일이 그
# 하니스에서 유일하게 third-party import 를 했다). 필요한 것은 프로필
# frontmatter 의 넷(`ground_truth` 문자열은 아래 `_ground_truth`)이고 나머지 셋은 한 줄짜리 flow-list/불리언이므로(design-doc·
# brief·seed·generic 프로필 실측 — 참고: `docreview_state.py:load_profile()` 은
# 이 넷을 훨씬 엄격하게 검증하지만 그건 정본 스키마 게이트이지 이 러너가
# 다시 구현할 대상이 아니다) 새 YAML 파서를 발명하지 않고 그 모양만 좁게 뽑는다.
def _last_match(pattern, text):
    # PyYAML 은 매핑에 같은 키가 두 번 나오면 **나중 값이 이긴다**(실측:
    # `yaml.safe_load("a: 1\na: 2")` == {"a": 2}). `re.search` 는 반대로 첫
    # 매치를 낸다 — 중복 키가 있으면 이 러너와 `load_profile()` 이 서로 다른
    # 값을 "정답"으로 읽는, fail-open 방향의 불일치가 된다(리뷰 F-5 항목
    # 5·6 — `web:` 중복은 킬 스위치에 인접한 통제라 특히 위험하다). 마지막
    # 매치를 취해 PyYAML 의 last-wins 규칙에 맞춘다.
    last = None
    for last in re.finditer(pattern, text):
        pass
    return last


def _block_span(top_key, text):
    # **컬럼-0 키의 마지막 occurrence 뒤부터, 다음 컬럼-0 키(또는 frontmatter
    # 끝) 앞까지**가 그 최상위 키의 몸통이다. 이 함수가 존재하는 이유(리뷰
    # F-6): `ground_truth:` 같은 다른 최상위 키가 block scalar(`ground_truth:
    # |`)일 수 있고, 그 스칼라 «본문»에 우연히 "layer1: [decoy]" 같은 줄이
    # 있으면 `_last_match(r"^\s*layer1:...", 전체 frontmatter)` 가 그 decoy 를
    # 진짜 헤더로 잘못 집는다 — YAML 구조 경계를 안 지키는 정규식의 대가다.
    # 이걸 막는 성질은 이미 `web:` 에 있다(컬럼 0 고정, `\s*` 없음) — block
    # scalar 의 내용은 **부모보다 반드시 더 들여써야** 하므로(YAML 문법)
    # 컬럼 0에 올 수 없다. `layer_rubric:` 자신도 최상위 키라 같은 성질을
    # 쓸 수 있다: 그 블록의 시작·끝을 컬럼-0 경계로 먼저 자르면, `layer1`/
    # `layer2` 검색을 그 안으로만 좁혀 다른 키의 block scalar 내용이 애초에
    # 검색 범위에 들어오지 않는다. 중복 `layer_rubric:` 도 last-wins 로 고른다
    # (다른 키들과 같은 계약). 단 따옴표·flow 스칼라의 연속줄은 컬럼 0 에 올 수 있다 — 그 모양은
    # `_scan_frontmatter` 가 이 함수보다 먼저 멈춘다(리뷰 I1).
    matches = list(re.finditer(r"(?m)^" + re.escape(top_key) + r":[^\n]*\n?", text))
    if not matches:
        return ""
    start = matches[-1].end()
    nm = re.search(r"(?m)^\S", text[start:])
    return text[start:start + nm.start()] if nm else text[start:]


def _flow_list(key, text, indented=True):
    # `layer1`·`layer2` 는 `layer_rubric:` 아래 2칸 들여쓰기다(`indented=True`,
    # 기본값) — 호출부가 `_block_span("layer_rubric", ...)` 로 이미 좁혀진
    # 텍스트를 넘기므로 `^\s*` 가 다른 최상위 키의 block scalar 내용을 잘못
    # 물 위험이 없다(리뷰 F-6, 위 `_block_span` 설명 참조). `allowed_
    # dispositions` 는 최상위 키라 `indented=False` 로 불러 컬럼 0에
    # 고정한다 — `web:` 과 같은 성질(block scalar 내용은 부모보다 반드시
    # 더 들여써야 하므로 컬럼 0에 못 온다, YAML 문법).
    prefix = r"^\s*" if indented else r"^"
    #
    # 형식은 **둘 다** 받는다 — flow(`key: [a, b, c]`)와 block(`key:\n  - a\n
    # - b`). `load_profile()`(docreview_state.py, 실 PyYAML)은 이 상위 스키마
    # 게이트라 둘 다 통과시키는데, 이 러너가 flow만 읽으면 그 게이트가 아무것도
    # 보호하지 못한다 — design-doc.md 의 `protected_headings` 가 이미 block
    # 이고(리뷰 F-1), layer1/layer2/allowed_dispositions 가 나중에 길어져 block
    # 으로 옮겨가면 flow 전용 파서는 **조용히 빈 리스트**를 내고(그 프로필 자체는
    # 여전히 유효하므로 게이트가 안 잡는다) 프롬프트는 "assign a disposition
    # from: " 뒤가 빈 채로 나간다. 트레일링 `# comment` 도 두 형식 모두에서
    # 허용한다(비교 지점: `web:` 아래에도 같은 요구가 있다).
    #
    # 반환은 리스트다(정말 없거나 비었으면 `[]`). 헤더는 있는데 이 함수가 못 읽는 모양은
    # 리스트를 내지 않고 `_ambiguous` 로 멈춘다(rc 5 → `profile_parse_ambiguous`). 이 구분이
    # 필요한 이유(리뷰 F-5): `layer2` 는 정당하게 비어 있을 수 있어(seed.md — `layer2: []`)
    # 「비었다」만으로는 진짜 빈 것과 못 읽은 것(줄바꿈된 flow 리스트
    # `layer2: [placeholder,\n  ambiguity]` 등)을 가르지 못한다. 항목도 게이트(PyYAML)가 같은
    # 문자열로 읽는 모양만 받는다(`_item`) — 앵커·태그·escape·문자열 아닌 평문은 멈춘다.
    mm = _last_match(r"(?m)" + prefix + re.escape(key) + r":[ \t]*\[(.*?)\][ \t]*(?:#.*)?$", text)
    if mm:
        inner = mm.group(1).strip()
        if not inner:
            return []
        return [_item(x, key) for x in inner.split(",") if x.strip()]
    # 헤더 뒤 개행을 **정규식 안에서** 소비한다(`$` 대신 리터럴 `\n`) — `$` 로
    # 끊으면 `mm.end()` 가 개행 문자 바로 앞에 멈춰, 그 뒤 `splitlines()` 의 첫
    # 원소가 빈 문자열이 된다("\n  - a".splitlines() == ['', '  - a']) — 그
    # 빈 줄이 `- ` 패턴에 안 맞아 첫 항목을 보기도 전에 루프가 끊긴다(실측
    # 회귀 — 고치기 전엔 block 세 프로필 모두 빈 리스트를 냈다).
    mm = _last_match(r"(?m)" + prefix + re.escape(key) + r":[ \t]*(?:#.*)?\n", text)
    if not mm:
        # 헤더 줄 자체가 이 두 형태(flow·block) 중 어디에도 안 맞는다. 콜론
        # 뒤에 공백·코멘트가 아닌 내용이 있으면(줄바꿈된 flow list 등) 그
        # 키는 «존재하지만 이 파서가 못 읽는 모양»이다 — 키가 아예 없는 것과
        # 다르다(리뷰 F-5, layer2 잔여). 콜론 뒤에 아무 내용도 없으면(키
        # 자체가 없거나, `key:` 뿐이고 뒤에 목록이 없거나) 정말 빈 것으로
        # 본다.
        if re.search(r"(?m)" + prefix + re.escape(key) + r":[ \t]*\S", text):
            _ambiguous("unreadable list shape: " + key)
        return []
    h = _indent(mm.group(0).rstrip("\n").split("\n")[-1])
    items = []
    for line in text[mm.end():].splitlines():
        # 빈 줄·줄 전체 주석은 목록 «안»에서도 유효하다(YAML 블록 시퀀스
        # 문법) — 항목이 아니라고 끊으면 리뷰 F-5 항목 2·3(빈 줄/주석으로
        # 잘리는 목록)이 재발한다. 항목도 아니고 빈 줄·주석도 아닌 줄은 헤더
        # 들여쓰기 이하면 다음 키(목록 끝)이고, 더 깊으면 이 파서가 못 읽는 모양이다.
        if not line.strip() or re.match(r"^[ \t]*#", line):
            continue
        im = re.match(r"^[ \t]*-(?:[ \t]+(.*?))?(?:[ \t]+#.*)?[ \t]*$", line)
        if im:
            if not im.group(1):
                _ambiguous("empty list item: " + key)
            items.append(_item(im.group(1), key))
            continue
        if _indent(line) <= h:
            break
        _ambiguous("unreadable list shape: " + key)
    return items


def _ground_truth(text):
    # `ground_truth`(설계 §5.3 「정답의 출처」) — codex 가 문서를 **무엇에 대조해** 보는가.
    # 게이트(`load_profile()`)는 비지 않은 문자열만 받는다. 이 함수는 게이트와 **같은 문자열을
    # 읽을 수 있는 모양만** 읽는다: 따옴표 한 덩어리(들여쓴 연속줄 포함 · 작은따옴표의 `''` 는 `'`)
    # · 문자열로 해석되는 평문 · literal `|` · 문단 없는 folded `>`. 목록(flow · block)·null·빔은
    # 게이트의 거절과 같은 판정으로 `""`(→ rc 3 `ground_truth_empty`, R36 — 목록에 한한 일치다).
    # 그 밖(문자열 아닌 평문 · 매핑 · 앵커·태그·별칭 · escape 있는 큰따옴표 · 문단 있는 folded ·
    # 들여쓰기 지시자)은 같은 값을 보장할 수 없어 `_ambiguous` 로 멈춘다(rc 5). 어느 occurrence 를
    # 읽는지는 헤더 줄과 `_block_span` 이 **같은 컬럼-0 마지막 줄**로 한 번에 정한다(PyYAML
    # last-wins — 중복 키 자체는 게이트가 거절한다, R37). `_flow_list` 를 부르지 않는 이유: 그
    # 함수는 flow 형과 block 형을 각자 따로 last-match 한다.
    hm = _last_match(r"(?m)^ground_truth:([^\n]*)$", text)
    if hm is None:
        return ""
    head = hm.group(1).strip()
    lines = _block_span("ground_truth", text).split("\n")
    while lines and not lines[-1].strip():
        lines.pop()
    filled = [i for i, ln in enumerate(lines) if ln.strip()]
    gaps = bool(filled) and any(not lines[i].strip() for i in range(filled[0], filled[-1] + 1))
    if re.match(r"^[&!*]", head):
        _ambiguous("anchor, tag or alias: ground_truth")
    bm = re.match(r"^([|>])([+-]?)([0-9]?)(?:[ \t]+#.*)?$", head)
    if bm:
        # block scalar — 내용 줄의 `#` 은 주석이 아니라 내용이다. 기준 들여쓰기는 첫 내용 줄의 것.
        if bm.group(3):
            _ambiguous("indentation indicator: ground_truth")
        if not filled:
            return ""
        base = _indent(lines[filled[0]])
        if any(_indent(lines[i]) < base for i in filled):
            _ambiguous("block scalar indentation: ground_truth")
        if bm.group(1) == "|":
            return "\n".join(ln[base:] if ln.strip() else "" for ln in lines[filled[0]:]).strip()
        if gaps or any(_indent(lines[i]) > base for i in filled):
            _ambiguous("folded scalar with paragraphs or more-indented lines: ground_truth")
        return " ".join(lines[i][base:] for i in filled).strip()
    # `head[:1] in "..."` 로 쓰지 않는다 — 빈 헤더면 `"" in "..."` 가 참이다(실측). 튜플로 가른다.
    if head[:1] in ("\"", "'"):
        if gaps:
            _ambiguous("blank line inside quoted scalar: ground_truth")
        return _quoted(" ".join([head] + [lines[i].strip() for i in filled]), "ground_truth")
    if head[:1] == "[":
        whole = " ".join([head] + [lines[i].strip() for i in filled])
        if re.match(r"^\[.*\](?:[ \t]+#.*)?$", whole, re.DOTALL):
            return ""  # flow 목록 — 게이트와 같은 판정(ground_truth_empty)
        _ambiguous("unreadable flow sequence: ground_truth")
    if head[:1] == "{":
        _ambiguous("mapping: ground_truth")
    head = re.sub(r"^#.*$|[ \t]+#.*$", "", head).strip()
    comments = [lines[i] for i in filled if lines[i].strip().startswith("#")]
    rest = [lines[i].strip() for i in filled if not lines[i].strip().startswith("#")]
    if not head:
        if not rest:
            return ""  # 맨 헤더 — null
        if all(re.match(r"^-(?:[ \t]|$)", ln) for ln in rest):
            return ""  # block 목록 — 게이트와 같은 판정(ground_truth_empty)
        if any(re.match(r"^[^\s#'\"\[{\-][^:]*:(?:[ \t]|$)", ln) for ln in rest):
            _ambiguous("mapping: ground_truth")
    if gaps or comments:
        _ambiguous("multi-line plain scalar with blank or comment lines: ground_truth")
    val = " ".join(x for x in [head] + [re.sub(r"[ \t]+#.*$", "", ln) for ln in rest] if x).strip()
    # YAML 의 null 평문(`~` · `null`)은 글자가 아니라 «값 없음»이다(PyYAML → None, 게이트는
    # 거절) — 문자열 "null" 을 정답의 출처로 싣지 않는다.
    if _NULL_PLAIN.match(val):
        return ""
    return _plain(val, "ground_truth")


# 읽기 — 전부 `_read` 를 거치고, 못 믿을 모양은 `_Ambiguous` 로 이 한 자리에서 멈춘다(rc 5).
try:
    _scan_frontmatter(fm_text)
    LAYER_RUBRIC_BLOCK = _block_span("layer_rubric", fm_text)
    lr_layer1 = _read("layer_rubric.layer1", _flow_list("layer1", LAYER_RUBRIC_BLOCK))
    lr_layer2 = _read("layer_rubric.layer2", _flow_list("layer2", LAYER_RUBRIC_BLOCK))
    ad = _read("allowed_dispositions", _flow_list("allowed_dispositions", fm_text, indented=False))
    gt = _read("ground_truth", _ground_truth(fm_text))
    web = _read("web", _web(fm_text))
except _Ambiguous as e:
    sys.stderr.write("[docreview] profile_parse_ambiguous — %s\n" % e)
    sys.exit(5)
if os.environ.get("DOCREVIEW_CODEX_PARSED_OUT"):
    pathlib.Path(os.environ["DOCREVIEW_CODEX_PARSED_OUT"]).write_text(
        json.dumps(PARSED, ensure_ascii=False), encoding="utf-8")
# **게이트-유도 불변식(리뷰 F-5)** — `docreview_state.py:load_profile()` 이
# `layer_rubric.layer1` 이 비지 않고 `allowed_dispositions` 가 비지 않고
# decide·ask 를 포함함을 이미 강제한다(그 파일 :97-100·:104-106) — 그 검증을
# 통과한 프로필이라면 이 러너가 이 둘을 비어 있게 읽을 방법이 원리적으로
# 없다. 그러므로 여기서 비어 있다는 것은 "그 프로필이 실제로 비었다"가 아니라
# "이 stdlib 파서가 그 모양을 못 읽었다"는 뜻이다 — 개별 모양을 하나씩
# 나열해 고치는 대신(리뷰가 잡은 여섯 개 중 다섯이 이런 식으로 새로 생겼을
# 것이다), **그 도출 자체를 실패로 선언한다.** `layer2` 는 게이트가 비어도
# 허용하므로 같은 논리가 안 통한다 — 헤더는 있는데 못 읽는 모양은 `_flow_list` 가
# `_ambiguous` 로 이미 멈췄다(위 try, rc 5). 값을 채우지 못한 채 진행해
# "assign a disposition from: " 뒤가 빈 프롬프트를 조용히 내보내는 대신,
# 러너의 기존 loud 경로(`emit_fallback prompt_build_failed`)로 넘긴다 — 새
# 실패 모드가 아니라 이미 있던 계약을 이 지점까지 넓히는 것이다.
if not lr_layer1 or not ad:
    sys.exit(1)
# `ground_truth` 도 게이트가 비지 않은 문자열을 강제한다(`ground_truth_empty`) — 못 읽는 모양은
# 위 try 에서 rc 5 로 멈췄고, 없음·빔·null·목록은 게이트와 같은 이름의 사유(rc 3 →
# `ground_truth_empty`)로 공시한다. 게이트 없이 러너만 불린 경우에도 "정답의 출처: " 뒤가 빈
# 프롬프트가 조용히 나가지 않는다.
if not gt:
    sys.exit(3)
# 본문(검토 항목)은 탐지·재비판 agent 가 읽는 루브릭이다 — codex 도 같은 루브릭으로 본다(R34).
# 비었으면 빈 절을 조용히 싣지 않고 게이트와 같은 이름의 사유(rc 4 → `profile_body_empty`)로
# 공시한다.
if not body.strip():
    sys.exit(4)
pathlib.Path(meta_path).write_text("web: %s\n" % ("true" if web else "false"), encoding="utf-8")

pre = ""
pre_p = pathlib.Path(preamble_path)
if pre_p.is_file():
    # P21 preamble 은 HTML 주석 줄을 제거한 뒤 프롬프트에 넣는다 — 그 마커가 본문으로
    # 새면 모델이 그것을 지시로 읽는다(shared/codex/prompt-preamble.md 자체 주석).
    pre = "\n".join(line for line in pre_p.read_text(encoding="utf-8").splitlines()
                    if not re.match(r"^\s*<!--.*-->\s*$", line))

doc = pathlib.Path(doc_path).read_text(encoding="utf-8")

# 순서는 형제 codex 프롬프트 빌더 넷(build_codex_prompt.py · build_artifact_codex_prompt.py ·
# build_brief_codex_prompt.py · build_seed_codex_prompt.py 의 PROMPT_TEMPLATE, 실측)과 같다 —
# 지시(역할 · 정답의 출처 · 층 · 처분 · 프로필 본문) → P21 preamble → 입력 태그 → 출력 형식.
# preamble 의 마지막 앵커와 `<document>` 사이에는 공백만 둔다 — test_codex_prompt_untrusted_clause.sh
# 의 지배 축이 이 러너도 잰다. 프로필 본문은 `<document>` 슬롯 밖, 자기 태그 안에 둔다.
print("You are an independent document reviewer in a read-only sandbox. Do NOT modify files.")
print("\nGround truth (the source the document is judged against): " + gt)
print("\nReview the document in two layers.")
print("Layer 1 (big-picture coherence) — categories: "
      + ", ".join(str(x) for x in lr_layer1))
l2 = lr_layer2 or ["(none — skip layer 2)"]
print("Layer 2 (detail completeness) — categories: " + ", ".join(str(x) for x in l2))
print("For each finding assign a disposition from: " + ", ".join(str(x) for x in ad))
print("  decide = user must decide · ask = ask the user · fix = author edits · drop = not worth raising"
      + (" · defer = hand to the implementation plan" if "defer" in ad else ""))
print("\nReview profile (category definitions and disposition rules for this review):")
print("<review_profile>\n" + body.strip("\n") + "\n</review_profile>")
print("Zero findings is a valid honest answer.")
print("\n" + pre)
print("\n<document>\n" + doc + "\n</document>")
print('\nEmit ONE fenced JSON block. `disposition` is required unless you cannot judge it.')
print('```json\n{"findings":[{"ref":"x1","layer":1,"category":"...","anchor":"#slug",'
      '"disposition":"...","summary":"...","edit_scope":"#slug","blocks":[],"evidence":"..."}]}\n```')
PY
if [[ $BUILD_RC -eq 3 ]]; then emit_fallback ground_truth_empty; fi
if [[ $BUILD_RC -eq 4 ]]; then emit_fallback profile_body_empty; fi
if [[ $BUILD_RC -eq 5 ]]; then emit_fallback profile_parse_ambiguous; fi
if [[ $BUILD_RC -ne 0 ]]; then emit_fallback prompt_build_failed; fi

# 웹 스위치 — 이 if/else 가 WEB_ARGS 를 만드는 **유일한 자리**다(P11). 기본값은 꺼짐:
# 프로필 web:false 면 두 kill switch 와 무관하게 꺼져 있고(WEB_META_FILE 이 "web: false"),
# `web: true` 여도 두 호스트 kill switch(DEVBREW_SPEC_DISTILL_DISABLE_WEB ·
# DEVBREW_QUALITY_GATES_DISABLE_WEB) 중 하나라도 켜져 있으면 끈다 — 공유 러너는 자기
# 호스트를 모르므로 과잉 적용(둘 다 검사)이 안전한 방향이다.
WEB_ARGS=(-c 'tools.web_search=false' -c 'web_search="disabled"')
WEB_META_VAL="$(cat "$WEB_META_FILE" 2>/dev/null || true)"
if [[ "$WEB_META_VAL" == "web: true" \
      && "${DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0}" != "1" \
      && "${DEVBREW_QUALITY_GATES_DISABLE_WEB:-0}" != "1" ]]; then
  WEB_ARGS=(-c 'tools.web_search=true' -c 'web_search="live"')
elif [[ "$WEB_META_VAL" == "web: true" ]]; then
  echo "[docreview] web 비활성(kill switch) — codex 리포 근거만" >&2
fi

EXIT_CODE=0
codex exec - \
    -C "$PROJECT_DIR" \
    -s read-only \
    "${WEB_ARGS[@]}" \
    --json \
    < "$PROMPT_FILE" \
    > "$STDOUT_FILE" \
    2>"$STDERR_FILE" || EXIT_CODE=$?

OVERRIDE_REASON=""
[[ $EXIT_CODE -ne 0 ]] && OVERRIDE_REASON=exit_nonzero

if ! python3 "$PLUGIN_ROOT/scripts/codex_findings_to_yaml.py" \
       --stderr-file "$STDERR_FILE" \
       --meta-override-exit-code "$EXIT_CODE" \
       --meta-override-reason "$OVERRIDE_REASON" \
       --emit-keys docreview \
       < "$STDOUT_FILE" > "$OUTPUT_PATH"; then
  echo 'findings: []' > "$OUTPUT_PATH"
  echo 'meta:' >> "$OUTPUT_PATH"; echo '  codex_failed: true' >> "$OUTPUT_PATH"
  echo '  reason: yaml_conversion_failed' >> "$OUTPUT_PATH"
  exit 0
fi
