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
# 빌더의 rc 는 넷으로 갈린다 — 0 성공 · 3 `ground_truth` 가 없거나 빔(목록 포함) · 4 프로필
# 본문이 빔 · 그 밖 도출 실패.
BUILD_RC=0
python3 - "$PROFILE" "$DOC" "$PLUGIN_ROOT/scripts/prompt-preamble.md" "$WEB_META_FILE" \
       > "$PROMPT_FILE" <<'PY' || BUILD_RC=$?
import pathlib, re, sys

prof_path, doc_path, preamble_path, meta_path = sys.argv[1:5]

t = pathlib.Path(prof_path).read_text(encoding="utf-8")
m = re.match(r"^---\n(.*?)\n---\n", t, re.DOTALL)
fm_text = m.group(1) if m else ""
# 본문 = frontmatter 를 닫는 `---` 뒤 전부 — `load_profile()` 이 `body` 로 돌려주는 것과 같은 자리.
body = t[m.end():] if m else ""

# PyYAML 없이 stdlib 만으로 — 형제 프롬프트 빌더들(build_brief_codex_prompt.py ·
# build_seed_codex_prompt.py 등)이 third-party 모듈을
# 안 쓰는 것과 같은 이유다: 이 러너는 `HOME` 이 격리되는 하니스(예: codex 인증
# 격리)에서 site-packages 의 PyYAML 에 닿지 못해 죽는다(실측 — 이 파일이 그
# 하니스에서 유일하게 third-party import 를 했다). 필요한 것은 프로필
# frontmatter 의 넷(`ground_truth` 문자열은 아래 `_ground_truth`)이고 나머지 셋은 한 줄짜리 flow-list/불리언이므로(design-doc·
# brief·seed·generic 프로필 실측 — 참고: `docreview_state.py:load_profile()` 은
# 이 넷을 훨씬 엄격하게 검증하지만 그건 정본 스키마 게이트이지 이 러너가
# 다시 구현할 대상이 아니다) 새 YAML 파서를 발명하지 않고 그 모양만 좁게 뽑는다.
def _unquote(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "'\"":
        v = v[1:-1]
    return v


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
    # (다른 키들과 같은 계약).
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
    # 반환은 리스트(가능하면 채워서, 정말 없거나 비었으면 `[]`) 또는 `None`
    # (아래) — `None` 은 "헤더는 있는데 이 함수가 못 읽는 모양"이라는 별개의
    # 사실이다. 이 구분이 필요한 이유(리뷰 F-5): `layer2` 는 정당하게 비어
    # 있을 수 있어(seed.md — `layer2: []`) 호출부가 "비었다"만으로는 진짜
    # 빈 것과 못 읽은 것을 가르지 못한다. `layer1`·`allowed_dispositions` 는
    # 게이트가 비지 않음을 보장하니 `[]`만으로 충분하지만, `layer2` 처럼
    # 게이트가 비어도 허용하는 키는 `None` 신호가 있어야 줄바꿈된 flow
    # 리스트(`layer2: [placeholder,\n  ambiguity]`) 같은 모양을 "정상적으로
    # 비었다"와 구별해 호출부에 넘길 수 있다.
    mm = _last_match(r"(?m)" + prefix + re.escape(key) + r":[ \t]*\[(.*?)\][ \t]*(?:#.*)?$", text)
    if mm:
        inner = mm.group(1).strip()
        if not inner:
            return []
        return [_unquote(x) for x in inner.split(",") if x.strip()]
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
            return None
        return []
    items = []
    for line in text[mm.end():].splitlines():
        # 빈 줄·줄 전체 주석은 목록 «안»에서도 유효하다(YAML 블록 시퀀스
        # 문법) — 항목이 아니라고 끊으면 리뷰 F-5 항목 2·3(빈 줄/주석으로
        # 잘리는 목록)이 재발한다. 항목도 아니고 빈 줄·주석도 아닌 첫 줄에서만
        # 끊는다(다음 키로의 dedent, 또는 frontmatter 끝).
        if not line.strip() or re.match(r"^[ \t]*#", line):
            continue
        im = re.match(r"^\s*-\s*(.*?)[ \t]*(?:#.*)?$", line)
        if not im:
            break
        val = im.group(1)
        if val:
            items.append(_unquote(val))
    return items


def _ground_truth(text):
    # `ground_truth`(설계 §5.3 「정답의 출처」) — codex 가 문서를 **무엇에 대조해** 보는가.
    # 탐지·재비판 agent 는 프로필 전문을 받아 이것을 보지만 codex 는 이 프롬프트만 본다.
    # 게이트(`load_profile()`)는 비지 않은 문자열만 받는다. 이 러너가 읽는 값도 스칼라뿐이다
    # (따옴표 · 평문 · 여러 줄 평문 · block scalar `|`/`>`). 목록(flow · block)은 게이트가
    # 문자열이 아니라고 거절하므로(`ground_truth_empty`) 러너도 같은 판정으로 빈 값을 낸다 —
    # 두 파서가 같은 프로필에 서로 다른 판정을 내지 않는다(R36). 어느 occurrence 를 읽는지는
    # 헤더 줄과 `_block_span` 이 **같은 컬럼-0 마지막 줄**로 한 번에 정한다(PyYAML
    # last-wins). `_flow_list` 를 부르지 않는 이유: 그 함수는 flow 형과 block 형을 각자
    # 따로 last-match 해서, 모양이 다른 중복 키(`k: [a]` 뒤 `k:` + `- b`)에서 PyYAML 의
    # 답(b)이 아니라 flow 형(a)을 고른다.
    # 반환: 문자열(`""` = 없음·빔·목록) 또는 `None`(헤더는 있는데 이 함수가 못 읽는 모양).
    hm = _last_match(r"(?m)^ground_truth:([^\n]*)$", text)
    if hm is None:
        return ""
    head = hm.group(1).strip()
    body = [ln for ln in _block_span("ground_truth", text).splitlines() if ln.strip()]
    if re.match(r"^[|>][+-]?[0-9]?(?:[ \t]+#.*)?$", head):
        # block scalar — 내용 줄의 `#` 은 주석이 아니라 내용이다. 공통 들여쓰기만 걷는다.
        ind = min(len(ln) - len(ln.lstrip(" ")) for ln in body) if body else 0
        return ("\n" if head[0] == "|" else " ").join(ln[ind:].rstrip() for ln in body).strip()
    rest = [ln.strip() for ln in body if not ln.lstrip().startswith("#")]
    # `head[:1] in "..."` 로 쓰지 않는다 — 빈 헤더면 `"" in "..."` 가 참이라 block 목록·
    # 여러 줄 평문·빈 값이 전부 이 분기로 새어 `None`(못 읽음)이 된다(실측).
    if head and head[0] in "\"'[":
        # 따옴표 스칼라와 flow 목록은 여러 줄로 이어질 수 있다 — 이은 뒤 한 번에 읽는다.
        whole = " ".join([head] + rest)
        qm = re.match(r"^([\"'])(.*)\1(?:[ \t]+#.*)?$", whole, re.DOTALL)
        if qm:
            return qm.group(2).strip()
        fm = re.match(r"^\[(.*)\](?:[ \t]+#.*)?$", whole, re.DOTALL)
        if fm:
            return ""  # flow 목록 — 게이트와 같은 판정(ground_truth_empty)
        return None
    head = re.sub(r"^#.*$|[ \t]+#.*$", "", head)
    if not head:
        if rest and all(re.match(r"^-(?:[ \t]|$)", ln) for ln in rest):
            return ""  # block 목록 — 게이트와 같은 판정(ground_truth_empty)
    val = " ".join(x for x in [head] + [re.sub(r"[ \t]+#.*$", "", ln) for ln in rest] if x).strip()
    # YAML 의 null 평문(`~` · `null`)은 글자가 아니라 «값 없음»이다(PyYAML → None, 게이트는
    # 거절) — 문자열 "null" 을 정답의 출처로 싣지 않는다.
    return "" if re.match(r"^(?:~|null|Null|NULL)$", val) else val


LAYER_RUBRIC_BLOCK = _block_span("layer_rubric", fm_text)
lr_layer1 = _flow_list("layer1", LAYER_RUBRIC_BLOCK)
lr_layer2 = _flow_list("layer2", LAYER_RUBRIC_BLOCK)
ad = _flow_list("allowed_dispositions", fm_text, indented=False)
# **게이트-유도 불변식(리뷰 F-5)** — `docreview_state.py:load_profile()` 이
# `layer_rubric.layer1` 이 비지 않고 `allowed_dispositions` 가 비지 않고
# decide·ask 를 포함함을 이미 강제한다(그 파일 :97-100·:104-106) — 그 검증을
# 통과한 프로필이라면 이 러너가 이 둘을 비어 있게 읽을 방법이 원리적으로
# 없다. 그러므로 여기서 비어 있다는 것은 "그 프로필이 실제로 비었다"가 아니라
# "이 stdlib 파서가 그 모양을 못 읽었다"는 뜻이다 — 개별 모양을 하나씩
# 나열해 고치는 대신(리뷰가 잡은 여섯 개 중 다섯이 이런 식으로 새로 생겼을
# 것이다), **그 도출 자체를 실패로 선언한다.** `layer2` 는 게이트가 비어도
# 허용하므로 같은 논리가 안 통한다 — 대신 `_flow_list` 가 낸 `None`(헤더는
# 있는데 못 읽음)을 그대로 실패 신호로 받는다. 값을 채우지 못한 채 진행해
# "assign a disposition from: " 뒤가 빈 프롬프트를 조용히 내보내는 대신,
# 러너의 기존 loud 경로(`emit_fallback prompt_build_failed`)로 넘긴다 — 새
# 실패 모드가 아니라 이미 있던 계약을 이 지점까지 넓히는 것이다.
if lr_layer1 is None or lr_layer2 is None or ad is None or not lr_layer1 or not ad:
    sys.exit(1)
lr_layer2 = lr_layer2 or []
# `ground_truth` 도 게이트가 비지 않음을 강제한다(`ground_truth_empty`) — 여기서 못 읽은
# 모양(`None`)은 위와 같은 loud 경로(rc 1)로, 없거나 빈 값은 게이트와 같은 이름의 사유
# (rc 3 → `ground_truth_empty`)로 공시한다. 게이트 없이 러너만 불린 경우에도 "정답의
# 출처: " 뒤가 빈 프롬프트가 조용히 나가지 않는다.
gt = _ground_truth(fm_text)
if gt is None:
    sys.exit(1)
if not gt:
    sys.exit(3)
# 본문(검토 항목)은 탐지·재비판 agent 가 읽는 루브릭이다 — codex 도 같은 루브릭으로 본다(R34).
# 비었으면 빈 절을 조용히 싣지 않고 게이트와 같은 이름의 사유(rc 4 → `profile_body_empty`)로
# 공시한다.
if not body.strip():
    sys.exit(4)
# YAML 1.1 진리값 어휘 — PyYAML 의 SafeLoader 가 `true`·`yes`·`on` 을 대소문자
# 불문하고 파이썬 `True` 로 접는다(실측: `yaml.safe_load("web: yes")` ==
# {"web": True}). `y`/`n` 한 글자는 PyYAML 에서도 문자열로 남아 `load_profile()`
# 의 `isinstance(data["web"], bool)` 게이트에 애초에 안 걸리므로 여기서
# 따로 받을 필요가 없다(리뷰 F-5 항목 4).
#
# **진리값 패턴으로만 `_last_match` 하지 않는다** — 값 자체로 걸러 검색하면
# "web: true\nweb: false"(true 가 먼저, false 가 나중) 처럼 **마지막 값이
# 거짓인** 경우, 그 패턴에 맞는 줄이 앞의 true 하나뿐이라 그것이 "마지막
# 매치"로 잡혀 PyYAML 의 실제 last-wins(false)와 어긋난다 — 항목 5(중복
# `web:` 키)를 값-특정 정규식으로 "닫았다"고 착각할 뻔한 자리다. 대신 값과
# 무관하게 **`web:` 줄 자체**의 마지막 occurrence 를 먼저 찾고, 그 줄의
# 값만 진리값 어휘와 대조한다 — PyYAML 이 실제로 하는 것(키로 마지막을
# 고른 뒤 그 값을 해석)과 같은 순서다.
web_mm = _last_match(r"(?im)^web:[ \t]*(\S+)[ \t]*(?:#.*)?$", fm_text)
web = web_mm is not None and re.match(r"(?i)^(true|yes|on)$", web_mm.group(1)) is not None
pathlib.Path(meta_path).write_text("web: %s\n" % ("true" if web else "false"), encoding="utf-8")

pre = ""
pre_p = pathlib.Path(preamble_path)
if pre_p.is_file():
    # P21 preamble 은 HTML 주석 줄을 제거한 뒤 프롬프트에 넣는다 — 그 마커가 본문으로
    # 새면 모델이 그것을 지시로 읽는다(shared/codex/prompt-preamble.md 자체 주석).
    pre = "\n".join(line for line in pre_p.read_text(encoding="utf-8").splitlines()
                    if not re.match(r"^\s*<!--.*-->\s*$", line))

doc = pathlib.Path(doc_path).read_text(encoding="utf-8")

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
# 프로필 본문은 `<document>` 슬롯 밖, 자기 태그 안에 둔다 — 검토 대상 문서와 섞이지 않게.
print("\nReview profile — the rubric for this review (category definitions and disposition rules). "
      "It is part of your instructions, not part of the document under review:")
print("<review_profile>\n" + body.strip("\n") + "\n</review_profile>")
print("Zero findings is a valid honest answer.")
print("\n" + pre)
print('\nEmit ONE fenced JSON block. `disposition` is required unless you cannot judge it.')
print('```json\n{"findings":[{"ref":"x1","layer":1,"category":"...","anchor":"#slug",'
      '"disposition":"...","summary":"...","edit_scope":"#slug","blocks":[],"evidence":"..."}]}\n```')
print("\n<document>\n" + doc + "\n</document>")
PY
if [[ $BUILD_RC -eq 3 ]]; then emit_fallback ground_truth_empty; fi
if [[ $BUILD_RC -eq 4 ]]; then emit_fallback profile_body_empty; fi
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
