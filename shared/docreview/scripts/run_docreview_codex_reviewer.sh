#!/usr/bin/env bash
# run_docreview_codex_reviewer.sh — 문서 리뷰 엔진(shared/docreview)의 codex co-reviewer. 정본.
#
# **처분** — consumer=orchestrator · fail-open · disclosure=advisory
#
# 실제 소비자는 같은 엔진의 docreview_route.py(§6.3 라우팅의 codex 입력)다. 이 파일은
# spec-distill·quality-gates 두 플러그인에 같은 파일 단위 심볼릭 링크로 배포되므로(설계
# §12 「신규(호스트)」) consumer= 경로가 어느 한 플러그인과도 같을 수 없다(처분 락 축 A⑤
# — 이 파일 자체가 애초에 어느 플러그인 서브트리에도 없다). 그래서 orchestrator 로 적고
# 실제 소비자는 이 주석이 밝힌다. fail-open 인 이유 — codex 는 모델 다양성 보조지
# 주 판정자가 아니다(설계 §9 「codex 부재·실패」행:
# 공시하되 막지 않는다).
#
# Usage: run_docreview_codex_reviewer.sh <profile.md> <doc-or-bundle> <project_dir> <out_yaml>
# 성공·실패 모두 <out_yaml> 에 codex_findings_to_yaml.py --emit-keys docreview 스키마의
# 중첩 YAML 을 쓴다. <out_yaml> 자체를 못 쓰면(디렉토리 부재·권한·RO 마운트) YAML 이
# 애초에 불가능하므로 rc 3 으로 죽는다 — 호출자는 rc==3 을 보면 <out_yaml> 을 지워야
# 한다(형제 run_codex_reviewer.sh 와 같은 계약. 이 fail-
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
#   0 성공 · 1 `prompt_build_failed`(층 1·처분 목록이 빔) · 3 `ground_truth_empty`(빈 문자열·
#   null·목록 — 게이트와 같은 이름) · 4 `profile_body_empty`(본문이 공백뿐 — 게이트와 같은 이름) ·
#   5 `profile_parse_ambiguous`(frontmatter 가 허용 목록 줄 문법 밖 — 문법 전부는 빌더의
#   `_parse_frontmatter` 주석이다 — 이거나, 같은 매핑의 중복 키, 또는 읽는 필드의 모양·타입이 다름:
#   ground_truth 가 문자열이 아님 · web 이 bool 이 아님 · 층·처분이 문자열 목록이 아님 · 경로 중간의
#   키(`layer_rubric`)가 있지만 매핑이 아님) ·
#   6 `profile_field_missing`(읽는 필드 — layer_rubric.layer1·layer2 · allowed_dispositions ·
#   ground_truth · web — 가 없음, frontmatter 부재 포함) · 7 `preamble_missing`(P21 preamble 파일이
#   없거나, 비었거나, 한 줄 HTML 주석뿐 — 그러면 codex 를 부르지 않는다. 내용에 P21 절이 있는지는
#   보지 않는다: 그것은 P21 지배 락 plugins/quality-gates/tests/test_codex_prompt_untrusted_clause.sh
#   가 배포 preamble 로 잰다).
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
    """frontmatter 가 이 러너의 허용 목록 줄 문법(`_parse_frontmatter`) 밖이거나, 읽는 필드의 타입이
    다르다 — rc 5 → `profile_parse_ambiguous`. 값을 추측하지 않고 멈춘다."""


class _Missing(Exception):
    """이 러너가 읽는 필드가 없다 — rc 6 → `profile_field_missing`(게이트도 거절한다)."""


def _ambiguous(why):
    raise _Ambiguous(why)


# 읽기 지점마다 `_read("<게이트 JSON 경로>", 값)` 을 거친다. 락이 이 호출들을 AST 로 도출해 게이트가
# 같은 경로에서 읽은 값과 등식 대조하므로, 새 필드를 읽으면 대조에 저절로 들어간다(R38 a).
PARSED = {}


def _read(path, value):
    PARSED[path] = value
    return value


# PyYAML 없이 stdlib 만으로 — 이 러너는 `HOME` 이 격리되는 하니스(예: codex 인증 격리)에서
# site-packages 의 PyYAML 에 닿지 못해 죽었다(실측 — T6b 가 PyYAML 을 걷어낸 이유). 그래서 게이트
# (`docreview_state.py:load_profile()`, PyYAML)의 파서를 다시 쓰지 않는다. 대신 아래 **허용 목록
# 줄 문법**만 받는다(Task 3c R42 — 「모호한 모양 탐지」는 열거라 라운드마다 새 모양이 샜다).
#
# 평문 토큰(`[A-Za-z0-9_]+`)의 타입은 PyYAML resolver(YAML 1.1)의 규칙 그대로다 — 이 문자 집합에서
# 문자열이 아닌 것은 bool · int · null 뿐이다(float 는 `.`, 날짜는 `-` 가 있어야 한다).
_BOOL_TRUE = ("yes", "Yes", "YES", "true", "True", "TRUE", "on", "On", "ON")
_BOOL_FALSE = ("no", "No", "NO", "false", "False", "FALSE", "off", "Off", "OFF")
_NULL = ("null", "Null", "NULL")
_INT = re.compile(r"""^(?:[-+]?0b[0-1_]+
                     |[-+]?0[0-7_]+
                     |[-+]?(?:0|[1-9][0-9_]*)
                     |[-+]?0x[0-9a-fA-F_]+
                     |[-+]?[1-9][0-9_]*(?::[0-5]?[0-9])+)$""", re.X)
_TOKEN = re.compile(r"[A-Za-z0-9_]+")
_DQ = re.compile(r'"((?:[^"\\]|\\\\)*)"')


class _Other:
    """문자열·bool·null 이 아닌 평문 토큰(PyYAML 은 int 로 읽는다). 읽는 필드에 오면 멈춘다."""

    def __init__(self, raw):
        self.raw = raw

    def __repr__(self):
        return "<non-string %s>" % self.raw


def _key(k):
    if k in _BOOL_TRUE or k in _BOOL_FALSE or k in _NULL:
        _ambiguous("key that PyYAML does not read as a string: " + k)
    return k


def _plain_token(tok):
    if tok in _BOOL_TRUE:
        return True
    if tok in _BOOL_FALSE:
        return False
    if tok in _NULL:
        return None
    if _INT.match(tok):
        return _Other(tok)
    return tok


def _scalar_at(s, i):
    # 한 줄 값 안의 스칼라 하나 — 큰따옴표 문자열(escape 는 `\\` 하나만: 배포 프로필의 정규식
    # 문자열이 쓰는 것 — 그 밖의 `\` 는 문법 밖) 또는 평문 토큰. 돌려주는 것: (값, 다음 위치).
    if s.startswith('"', i):
        dm = _DQ.match(s, i)
        if not dm:
            _ambiguous("double-quoted scalar not closed on its line or with an unsupported escape")
        return dm.group(1).replace("\\\\", "\\"), dm.end()
    tm = _TOKEN.match(s, i)
    if not tm:
        _ambiguous("value outside the line grammar")
    return _plain_token(tm.group(0)), tm.end()


def _flow(s, i):
    # 한 줄에서 닫히는 flow 목록 `[a, "b"]` · 매핑 `{k: a, k2: "b"}` — 항목은 스칼라뿐(중첩 없음).
    close = "]" if s[i] == "[" else "}"
    keys, vals = [], []
    i += 1
    while True:
        while s.startswith(" ", i):
            i += 1
        if not vals and s.startswith(close, i):
            i += 1
            break
        if close == "}":
            km = re.compile(r"[a-z_][a-z0-9_]*").match(s, i)
            if not km or not s.startswith(": ", km.end()):
                _ambiguous("flow mapping entry outside the line grammar")
            keys.append(_key(km.group(0)))
            i = km.end() + 2
        val, i = _scalar_at(s, i)
        vals.append(val)
        while s.startswith(" ", i):
            i += 1
        if s.startswith(",", i):
            i += 1
            continue
        if s.startswith(close, i):
            i += 1
            break
        _ambiguous("flow collection not closed on its line, nested, or malformed")
    if close == "]":
        return vals, i
    if len(set(keys)) != len(keys):
        _ambiguous("duplicate key in a flow mapping")
    return dict(zip(keys, vals)), i


def _value(s):
    # 한 줄 값 전체 — 스칼라 또는 flow 컬렉션. 그 뒤에는 아무것도 없다(꼬리 주석도 없다).
    if s[:1] in ("[", "{"):
        v, i = _flow(s, 0)
    else:
        v, i = _scalar_at(s, 0)
    if i != len(s):
        _ambiguous("text after a value")
    return v


def _parse_frontmatter(fm):
    # **허용 목록 줄 문법**(Task 3c R42) — 배포 프로필 넷과 러너에 프로필을 먹이는 fixture 가 실제로
    # 쓰는 모양만 받고, 그 밖의 줄은 전부 `profile_parse_ambiguous` 로 멈춘다. 모든 줄은 다음 중 하나다:
    #   · 빈 줄
    #   · 컬럼-0 `key: <한 줄 값>`
    #   · 컬럼-0 `key:` — 블록을 연다. 자식은 아래 두 모양 중 한 가지(섞지 않는다). 자식이 없으면 null
    #   · 2칸 `subkey: <한 줄 값>`  (블록의 매핑 자식)
    #   · 2칸 `- <한 줄 스칼라>`    (블록의 시퀀스 자식)
    # 키는 `[a-z_][a-z0-9_]*`(PyYAML 이 문자열로 읽지 않는 bool·null 낱말은 뺀다). 한 줄 값은 그
    # 줄에서 끝난다: 큰따옴표 문자열(escape 는 `\\` 하나) · 평문 토큰 `[A-Za-z0-9_]+` · 스칼라만 담은
    # flow 목록/매핑. 주석 줄(배포 프로필·fixture 가 쓰지 않는다 — 받으면 「주석이냐 내용이냐」를
    # 따지는 규칙이 다시 생긴다) · 꼬리 주석 · 작은따옴표 · block scalar(`|` `>`) · 앵커·별칭·태그 ·
    # 따옴표가 든 평문 · 여러 줄에 걸친 값 · 탭 · LF 밖의 줄바꿈은 받지 않는다. 같은 매핑의 중복 키도
    # 멈춘다(게이트의 `duplicate_key` 와 같은 판정).
    #
    # 보장하는 것: 값이 한 줄을 넘지 않으므로 「따옴표·flow 연속줄 속 컬럼-0 키」 부류가 모양째 없다.
    # 이 문법을 통과한 frontmatter 를 PyYAML 도 받는다면 같은 구조와 같은 값(문자열의 `\\` 해제 ·
    # 토큰의 bool·int·null 해석 포함)으로 읽는다 — 두 파서가 **모두 받을 때**의 성질이다. 이 문법은
    # 받지만 PyYAML 은 거절하는 입력(큰따옴표 안 비인쇄 문자 · `0x_` 류 토큰)이 있다: 엔진 경로에서는
    # 게이트가 먼저 거절하므로 도달하지 않고, 러너만 단독으로 부르면 그 값으로 codex 를 부른다.
    # 보장하지 않는 것: 게이트의 **스키마** 검사(필드 집합 ·
    # 처분 어휘 · detectors · 정규식 컴파일 · decision_log/defer_target 모양) — 그것은
    # `load_profile()` 몫이고, 엔진 경로는 언제나 게이트를 먼저 지난다.
    for ch in ("\r", "\x85", "\u2028", "\u2029", "\t"):
        if ch in fm:
            _ambiguous("character outside the line grammar (%r)" % ch)
    top, block, kind = {}, None, None
    for line in fm.split("\n"):
        if not line:
            continue
        lm = re.fullmatch(r"([a-z_][a-z0-9_]*):(?: (.+))?", line)
        if lm:
            key = _key(lm.group(1))
            if key in top:
                _ambiguous("duplicate key: " + key)
            if lm.group(2) is None:
                top[key], block, kind = None, key, None
            else:
                top[key], block = _value(lm.group(2)), None
            continue
        lm = re.fullmatch(r"  ([a-z_][a-z0-9_]*): (.+)", line)
        if lm and block is not None and kind in (None, "map"):
            if top[block] is None:
                top[block] = {}
            key = _key(lm.group(1))
            if key in top[block]:
                _ambiguous("duplicate key: %s.%s" % (block, key))
            top[block][key], kind = _value(lm.group(2)), "map"
            continue
        lm = re.fullmatch(r"  - (.+)", line)
        if lm and block is not None and kind in (None, "seq"):
            if top[block] is None:
                top[block] = []
            val, i = _scalar_at(lm.group(1), 0)
            if i != len(lm.group(1)):
                _ambiguous("text after a list item")
            top[block].append(val)
            kind = "seq"
            continue
        _ambiguous("line outside the line grammar")
    return top


def _field(data, *path):
    # 키가 없으면 부재(rc 6)다. 경로 중간의 키가 있지만 매핑이 아니면(`layer_rubric: [a]` · 맨
    # `layer_rubric:`) 부재가 아니라 모양이 다른 것이다(rc 5) — 게이트도 둘을 다른 사유
    # (`fields_missing` · `layer_rubric_invalid`)로 가른다.
    d = data
    for i, k in enumerate(path):
        if not isinstance(d, dict):
            _ambiguous("not a mapping: " + ".".join(path[:i]))
        if k not in d:
            raise _Missing(".".join(path))
        d = d[k]
    return d


def _str_list_field(data, *path):
    v = _field(data, *path)
    if not isinstance(v, list) or not all(isinstance(x, str) for x in v):
        _ambiguous("not a list of strings: " + ".".join(path))
    return v


def _ground_truth(data):
    # `ground_truth`(설계 §5.3 「정답의 출처」) — codex 가 문서를 **무엇에 대조해** 보는가. 게이트는
    # 비지 않은 문자열만 받는다. 빈 문자열·null·목록은 게이트의 거절과 같은 판정으로 `""`(→ rc 3
    # `ground_truth_empty`), 그 밖의 문자열이 아닌 값(bool · int · 매핑)은 rc 5 로 멈춘다.
    v = _field(data, "ground_truth")
    if v is None or isinstance(v, list) or (isinstance(v, str) and not v.strip()):
        return ""
    if not isinstance(v, str):
        _ambiguous("ground_truth is not a string")
    return v


def _web(data):
    # YAML 1.1 bool 만 받는다(평문 토큰의 타입은 PyYAML resolver 그대로). 없으면 멈춘다 — 게이트도
    # `fields_missing` 으로 거절한다(웹이 켜지는 쪽으로도, 꺼지는 쪽으로도 추측하지 않는다).
    v = _field(data, "web")
    if not isinstance(v, bool):
        _ambiguous("web is not a YAML boolean")
    return v


# 읽기 — 전부 `_read` 를 거친다. 문법 밖·타입 불일치는 rc 5, 읽는 필드의 부재는 rc 6.
try:
    if not m:
        raise _Missing("frontmatter")
    data = _parse_frontmatter(fm_text)
    lr_layer1 = _read("layer_rubric.layer1", _str_list_field(data, "layer_rubric", "layer1"))
    lr_layer2 = _read("layer_rubric.layer2", _str_list_field(data, "layer_rubric", "layer2"))
    ad = _read("allowed_dispositions", _str_list_field(data, "allowed_dispositions"))
    gt = _read("ground_truth", _ground_truth(data))
    web = _read("web", _web(data))
except _Ambiguous as e:
    sys.stderr.write("[docreview] profile_parse_ambiguous — %s\n" % e)
    sys.exit(5)
except _Missing as e:
    sys.stderr.write("[docreview] profile_field_missing — %s\n" % e)
    sys.exit(6)
if os.environ.get("DOCREVIEW_CODEX_PARSED_OUT"):
    pathlib.Path(os.environ["DOCREVIEW_CODEX_PARSED_OUT"]).write_text(
        json.dumps(PARSED, ensure_ascii=False), encoding="utf-8")
# **게이트-유도 불변식(리뷰 F-5)** — `load_profile()` 이 `layer_rubric.layer1` 과
# `allowed_dispositions` 가 비지 않음을 강제한다. 그러므로 여기서 비어 있으면 그 프로필은 게이트를
# 지나지 못했다 — "assign a disposition from: " 뒤가 빈 프롬프트를 조용히 내보내지 않고 기존 loud
# 경로(`emit_fallback prompt_build_failed`)로 넘긴다. `layer2` 는 게이트가 비어도 허용한다(seed).
if not lr_layer1 or not ad:
    sys.exit(1)
# `ground_truth` 값이 빔·null·목록이면 게이트와 같은 이름의 사유(rc 3 → `ground_truth_empty`)로 공시한다(키 부재는 위 rc 6) —
# 게이트 없이 러너만 불린 경우에도 "정답의 출처: " 뒤가 빈 프롬프트가 나가지 않는다.
if not gt:
    sys.exit(3)
# 본문(검토 항목)은 탐지·재비판 agent 가 읽는 루브릭이다 — codex 도 같은 루브릭으로 본다(R34).
# 비었으면 빈 절을 조용히 싣지 않고 게이트와 같은 이름의 사유(rc 4 → `profile_body_empty`)로
# 공시한다.
if not body.strip():
    sys.exit(4)
pathlib.Path(meta_path).write_text("web: %s\n" % ("true" if web else "false"), encoding="utf-8")

# P21 preamble 이 없으면 주입 경계 없이 codex 를 부르지 않는다(rc 7 → `preamble_missing`) — 예전에는
# 파일이 없으면 빈 문자열로 진행해 `codex_failed: false` 인 채 P21 절 없는 프롬프트가 나갔다(재리뷰
# 실측). HTML 주석 줄은 제거한 뒤 싣는다 — 그 마커가 본문으로 새면 모델이 그것을 지시로 읽는다.
pre_p = pathlib.Path(preamble_path)
if not pre_p.is_file():
    sys.stderr.write("[docreview] preamble_missing — %s\n" % preamble_path)
    sys.exit(7)
pre = "\n".join(line for line in pre_p.read_text(encoding="utf-8").splitlines()
                if not re.match(r"^\s*<!--.*-->\s*$", line))
if not pre.strip():
    sys.stderr.write("[docreview] preamble_missing — %s is empty\n" % preamble_path)
    sys.exit(7)

doc = pathlib.Path(doc_path).read_text(encoding="utf-8")

# 순서는 형제 codex 프롬프트 빌더 둘(build_codex_prompt.py · build_artifact_codex_prompt.py 의
# PROMPT_TEMPLATE, 실측)과 같다 —
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
print('`replacement` is required for `decide` — what the document becomes if fixed. '
      'To propose deletion, write the literal `대체안 없음 — 그냥 뺀다`. Leaving the field '
      'empty is NOT a deletion proposal. `if_unfixed` states what remains if nothing changes '
      '(the consequence, not a restatement of the problem).')
print('```json\n{"findings":[{"ref":"x1","layer":1,"category":"...","anchor":"#slug",'
      '"disposition":"...","summary":"...","edit_scope":"#slug","blocks":[],"evidence":"...",'
      '"replacement":"...","if_unfixed":"..."}]}\n```')
PY
if [[ $BUILD_RC -eq 3 ]]; then emit_fallback ground_truth_empty; fi
if [[ $BUILD_RC -eq 4 ]]; then emit_fallback profile_body_empty; fi
if [[ $BUILD_RC -eq 5 ]]; then emit_fallback profile_parse_ambiguous; fi
if [[ $BUILD_RC -eq 6 ]]; then emit_fallback profile_field_missing; fi
if [[ $BUILD_RC -eq 7 ]]; then emit_fallback preamble_missing; fi
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
