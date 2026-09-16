#!/usr/bin/env bash
# guards: plugins/*/skills/*.md plugins/*/commands/*.md plugins/*/references/*.md
#
# skill · command · reference 마크다운이 모델에게 건네는 플러그인 루트는 cwd 로 풀리지 않는다.
#
# 치환은 SKILL.md 본문을 로드할 때 글자 그대로의 `${CLAUDE_PLUGIN_ROOT}` 토큰에만 온다. Bash 도구
# 환경에는 그 변수가 없고, `Read` 로 연 reference 파일은 글자 그대로 온다(2.1.270 실측 — 설계
# docs/superpowers/specs/2026-09-14-plugin-root-cwd-fallback-design.md 「실측」). 그래서 잰다:
#
#  축 1  — 본문 어디에도 bare 가 아닌 루트 전개(`${CLAUDE_PLUGIN_ROOT` 뒤에 `}` 가 아닌 무엇이든 — `:-` · `-` · `:=` · `:?` 등)가 없다. SKILL.md 에서도 치환되지 않아 끝자락으로 떨어진다(C1).
#  축 1b — 본문 어디에도 cwd 상대 플러그인 루트가 없다: `./plugins/` 리터럴(대입 끝자락 · 산문 모두),
#          그리고 자기 플러그인 스크립트를 실행하는 코드 스팬 · bash 줄이 넘기는 cwd 상대
#          `plugins/<자기 플러그인>/…` 인자. 처분 앵커 · 문서 포인터처럼 명령이 아닌 자리와 감사 대상
#          `plugins/<target>` 은 명령의 첫 낱말이 자기 스크립트가 아니거나 자기 플러그인 이름이 아니라서
#          걸리지 않는다.
#  축 2  — reference 파일의 bash 펜스(들여쓴 펜스 포함) 중 루트를 쓰는 것은, 같은 펜스에서 그 사용보다
#          앞에 `X="${CLAUDE_PLUGIN_ROOT}"; [ -n "$X" ] || { echo "…" >&2; exit N; }` 한 줄이 있다.
#          「루트를 쓴다」는 코퍼스 전체에서 모은 가드 변수 이름으로 판정한다 — reference 펜스는 SKILL.md
#          펜스 뒤에 이어 붙여 한 호출로 도는 것이 호출 관습이라, 그 파일 안에 대입이 없어도 루트를 쓴다.
#  축 2b — 루트 변수는 cwd 에서 만들어지지 않는다(모든 마크다운의 bash 펜스). 대입을 잡는 자리는 줄머리 ·
#          `;&|(){}` 뒤 · 선언 키워드(`export`/`local`/`declare`/`typeset`/`readonly`) 뒤이고 `+=` 를
#          포함하되, 그중에서도 변수마다 **맨 왼쪽 대입 하나만** 판정한다. 기본값 전개는 연산자가
#          `-` · `=` · `?` · `+` 중 하나이고 앞에 `:` 또는 `+` 가 올 수 있는 모든 `${V…}` 를 본다.
#          값이 cwd 에서 오는지는 **세 표기**로만 판정한다 — `$(pwd` · `$PWD` · 앞머리 `plugins/`.
#          가드를 지난 펜스에서는 한 걸음 더 엄격하다 — **그 변수의** 맨 왼쪽 대입의 우변이 치환 토큰
#          «그 자체»여야 한다(그 «줄»의 첫 대입이 아니다 — 다른 이름의 대입은 애초에 판정 대상이
#          아니다). 그 엄격함의 대가는 거짓 RED 셋이다: `V="${CLAUDE_PLUGIN_ROOT}/하위경로"` · 값을
#          세우지 않는 전개(`${V:+…}`) · 펜스의 **주석** 안에 대입 문구를 적은 줄(줄을 있는 그대로
#          보므로 주석도 살아 있는 코퍼스다 — 다만 변수 앞에 `;&|(){}` 같은 경계 문자가 올 때만
#          걸린다. `# 주의: V="$(pwd)"` 는 조용하고 `# 예) V="$(pwd)"` 는 걸린다).
#  축 3  — 루트 토큰을 담은 reference 마다 그것을 `Read` 하는 SKILL.md 줄이 있고, 그 줄은 전부
#          `${CLAUDE_PLUGIN_ROOT}/…` 절대 형태이며, 같은 절에 치환 안내 문장이 **줄 전체 그대로** 있다.
#          부분 문자열로 재면 문장 뒤에 부정을 붙여도 통과한다.
#  C3/C4 — 가드 줄의 메시지에 `${CLAUDE_PLUGIN_ROOT}` 가 없고(SKILL.md 에서는 그것까지 치환된다), 가드를
#          담은 펜스에서 가드 앞에 `set -u` 가 없다(unbound 오류가 복구 메시지를 가린다).
#  C5    — 가드 메시지가 정본 문안과 **통째로** 같다(허용되는 꼬리는 복귀 지시 하나 — 실제로 쓰는 곳은
#          reviewing-spec 뿐이지만 검사는 플러그인을 가리지 않는다). 치환이 없는 하니스에서 cwd 실행을
#          실제로 막는 것은 비0 종료가 아니라 이 문장이다. 부분 문자열로 재면 두 문구를 품은 채 뒤에
#          부정을 붙여 뜻을 뒤집을 수 있다(실측) — 축 3 이 안내 문장에 줄 전체 일치를 쓰는 이유와 같다.
#          C5 의 이빨은 GUARD 가 알아보는 자리에서 끝난다 — 알아보지 못한 가드는 비교 자체가 없다.
#  C6    — 루트를 대입하며 가드 모양을 취한 줄은 정본 가드 형태다. 그 줄이 정규식 밖 형태로 다시 쓰이면
#          그 자리는 C3 · C4 · C5 · 축 2b 에서 통째로 빠지는데, 개수만 세면 「지켜졌다」와 「보이지
#          않는다」가 구별되지 않는다. **C6 의 후보 집합은 정본 접두사 표기 자신이다** — 접두사를 바꾼
#          재작성(`readonly V=…` · 중괄호 없음 · 큰따옴표 없음 · 두 줄로 쪼갬)은 GUARD 와 C6 을 동시에
#          멀게 한다. 가드 줄 수와 가드를 지나는 펜스 수를 함께 내되 **판정하는 것은 펜스 수 하나**다
#          (오늘의 수로 핀한 하한).
#  행동  — 대표 펜스 둘(SKILL.md 하나 · reference 하나)을 잘라, 무치환 · 변수 없음 · cwd 에
#          `./plugins/quality-gates/scripts/` 미끼가 있는 조건에서 미끼가 돌지 않고 비0 으로 끝나며
#          복구 지시가 나오는지, 토큰을 픽스처 루트로 바꾼 조건에서 픽스처 스크립트가 도는지 실행한다.
#          축 1b 의 자기 하니스 인자 탐지에는 합성 단위를 태우는 양성 대조가 따로 있다(N_PROBE).
#
# **이 락은 셸을 파싱하지 않는다.** 토크나이저가 없고 따옴표를 추적하지 않으며, `#` 가 주석을 여는지는
# 줄-종단 정규식이 정한다. 결과가 둘이다 — 따옴표 «안»의 `#` 가 축 1b 에서 논리 줄의 나머지를 지우고,
# 주석 «안»의 대입 문구가 축 2b 의 살아 있는 코퍼스가 된다.
#
# 축마다 보는 «단위»가 다르다. **한 물리 줄만** — C4 · C6. **한 줄 + 그 파일의 플러그인 이름** — C5
# (정본 문안이 `[<플러그인>] ` 접두를 쓴다). **한 줄을 펜스 범위 안에서** — C3(앞선 `set -u` 를 기억해
# 뒀다가 뒤 가드 줄에서 낸다) · 축 2b(앞선 가드가 채운 변수 집합). **한 줄 + 코퍼스 전역 이름 집합** —
# 축 2b 의 판정 대상 변수(전파일을 훑어 만든다). **한 줄을 헤딩 절 범위 안에서** — 축 3.
# **축 1b 는 분할의 «양쪽»에 걸친다**: 자기 하니스 인자 하위검사는 `\` 이어쓰기를 합치지만 **토큰
# 경계에서만**이고(결합이 공백을 끼워 넣어, 토큰 «안»을 쪼갠 이어쓰기는 다시 붙지 않는다) 산문 코드
# 스팬은 개행 너머로 훑는 반면, `./plugins/` 리터럴 하위검사는 결합이 전혀 없는 한 물리 줄 검사다.
# 그리고 한 줄 «안»에서도 축 2b 는 변수마다 맨 왼쪽 대입 하나만 본다.
#
# 그래서 빠진 층위는 「논리 줄 합치기」가 아니라 **따옴표 인식 + 명령 단위 분해**이고, 그 교체가
# 후속이다. 아래는 그 빠진 층위의 사례들이다 — 표기를 더 열거하는 것은 해법이 아니다.
#
# 재지 못하는 것:
#  - 가드의 «표기». 정본 한 줄 · 큰따옴표 형태만 알아본다. 두 줄로 쪼개거나 홑따옴표 · 따옴표 없음 ·
#    `readonly` 접두로 쓰면 그 자리는 C3 · C4 · C5 · C6 · 축 2b 에서 통째로 빠진다. 기존 가드의 그런
#    «재작성»은 **그 펜스에 다른 정본 가드가 없을 때만** 가드 회계가 잡는다(세어지는 수가 준다) —
#    회계가 잡지 못하는 것은 아래 「회계의 이빨」.
#  - 대입의 «위치». 셸 키워드 뒤(`if …; then V=…` · `do V=…`)와 앞붙임(`env V=…`)은 축 2b 의 경계
#    목록 밖이다. 그래서 「경로가 없으면 cwd 를 쓴다」는 조건부 fallback 은 가드 뒤에 있어도 조용하다.
#  - 대입의 «차례». 같은 줄에서 그 변수의 맨 왼쪽 대입이 통과하면 뒤따르는 같은 변수의 재대입은 보이지
#    않는다 — 앞에 토큰 대입을 두고 공백 하나를 넣어 `; V=$(pwd)` 를 이으면 조용하다(실측). 구분자를
#    열거해 메울 자리가 아니라 위에서 이름 댄 빠진 층위에 속한다.
#  - 값의 «출처». 가드가 없는 펜스에서 cwd 판정은 세 표기 열거가 전부다 — `$(cd .. && pwd)` ·
#    `` `pwd` `` · `$(git rev-parse --show-toplevel)` · `$( pwd )` 는 지나간다. 우변 포착이 공백에서
#    끊기는 것(`\S*`)이 그 절반의 이유다.
#  - C6 의 후보 집합이 정본 접두사 표기 자신이라, 접두사를 바꾼 재작성은 못 본다(위 C6 절).
#  - 코퍼스의 범위. 글롭은 skills · commands · references 뿐이다 — `agents/` · `hooks/` 는 밖이다.
#  - 이름의 전역성. 루트 변수 이름은 코퍼스 «전역»으로 예약되고 축 2b 뿐 아니라 **축 2** 에도 먹인다 —
#    축 2 에서 더 세게 문다: reference 펜스에서는 예약된 이름을 «언급»하는 것만으로 가드를 요구받는다
#    (`echo "PR #$PR"` 한 줄이 그 펜스를 축 2 대상으로 만든다). 지금 예약된 이름은 `QG` · `SD` · `PR` ·
#    `PA` 이고, `PR` 은 pull request 번호로 쓰일 개연성이 높아 장래 거짓 RED 의 1순위다. 이름은 스캔
#    모집단에서 거두므로 **추적조차 되지 않은 로컬 초안**이 이름을 예약해 커밋된 무관한 파일을 붉게
#    만들 수 있다(실측).
#  - 행동 테스트의 도달 범위. 무치환 쪽은 가드가 먼저 비0 으로 끝나므로 가드 «뒤» 의 줄을 한 줄도
#    실행하지 못하고, 치환 흉내 쪽은 픽스처 경로가 실재해 조건부 fallback 이 발동하지 않는다.
#  - 축 1b 의 «주석 처리»와 «명령 자리». unit 조립이 따옴표를 모르고 주석을 뗀다 — 인용어 안의 `#` 가
#    논리 줄의 나머지를 지운다: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/x.sh" --label "a # b"
#    plugins/<자기>/x` 는 조용하다. 자기 스크립트를 cwd 상대로 지명한 형태에서는 그 «경로 토큰 자신»이
#    위반이라 이 우회가 성립하지 않는다 — 우회는 스크립트를 루트 토큰으로 지명할 때만 있다.
#    축 2b 에서 같은 이유로 걷어낸 장치가 여기엔 남아 있다. 또 unit 의 «첫» 명령만 보므로 앞에 다른
#    명령이 붙으면(`echo x; bash plugins/<자기>/scripts/y.sh`) 자기 하니스 호출이 보이지 않는다.
#  - 축 3 의 «줄 전체 일치». `Read <경로>.md` 뒤에 꼬리 텍스트가 붙으면 그 포인터는 절대-형태 검사와
#    안내-문장 검사에서 통째로 보이지 않는다(그 reference 를 여는 적합한 Read 줄이 달리 없으면 「Read
#    하는 SKILL.md 줄이 없다」로 시끄럽게 난다).
#  - 회계의 «이빨». 핀한 하한은 보상되지 «않은» 제거·재작성만 잡는다. 못 잡는 것 **다섯**: ① 한 자리를
#    비정본으로 재작성하면서 다른 자리에 정본 가드를 더하면 합계가 복구된다 ② 인식되지 않는 가드를 단
#    새 펜스의 «추가»에는 최소값이 결코 발화하지 않는다 ③ 가드를 지우며 같은 편집에서 핀 숫자를 내리면
#    통과한다 — 핀은 시험 대상 파일 «안»의 두 자리 숫자이고 독립된 증인이 없다 ④ 한 펜스에 정본 가드가
#    둘이면 첫 가드의 재작성이 펜스 수를 바꾸지 않아 조용하다(오늘의 코퍼스가 펜스당 가드 하나라 살아
#    있을 뿐이고, 어떤 단언도 그 성질을 붙들지 않는다) ⑤ 핀은 «내려가기만» 한다 — 정직한 가드 추가가
#    영구 여유를 미리 지불하고, 무관한 나중 커밋이 그것을 소리 없이 쓴다(실측).
#    한때 계수 모집단을 추적되는 파일로 좁혀 ①을 막으려 했으나, 가드는 전부 이미 추적되는 파일에 살고
#    파서는 index 가 아니라 디스크를 읽으므로 그 좁힘이 막는 것은 «새 파일에 저술된 가드»뿐이었다 —
#    실효 ≈0 에 거짓 RED 만 새로 만들어 되돌렸다. ①~⑤ 를 실제로 닫는 자리는 시험 대상 파일 «밖»에 둔
#    자리별 원장과 `>=` 가 아닌 등호이고, 그것은 층위 교체(후속)다.
#  - 그 밖: 이름만 적힌 스크립트 호출과 「리포 root에서」 같은 산문 루트 진술(실행 지시인지 설명인지
#    가려야 한다), 치환이 없는 하니스에서 모델이 `Read` 경로를 어떻게 푸는지, `Read` 로 연 파일이 다시
#    가리키는 2차 포인터, 대입 문법을 벗어난 루트 설정(`printf -v` · `eval` · 배열), 태그가 `bash` 가
#    아닌 펜스(태그 없음 · `sh`) — 축 1b 의 자기 하니스 인자 · 축 2 · 축 2b · C3 · C4 · C5 · C6 은 bash
#    태그 펜스만 본다. 축 1b 의 자기 하니스 인자는 `X="$(interp … )"` 로 감싼 호출을 놓친다.
#
# 재지 «않는» 것: SKILL.md 펜스의 가드 **존재**. 설계 D6 의 결정이다 — 가드 없는 bare 토큰은 치환이
# 없어도 `/scripts/…` 로 풀려 cwd 로 가지 않는다. **가드가 있는데 cwd fallback 으로 변질되는 경우를
# 축 2b 가 다 잡는 것은 아니다** — 위 「대입의 위치」와 「가드의 표기」가 그 구멍이고, 측정으로
# 확인됐다. D6 은 그 구멍을 안고 내린 결정이며, 메우는 자리는 이 락이 아니라 층위 교체(후속)다.
#
# 파싱은 python 으로 한다 — 셸 본문 추출기는 조용히 깨진다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1

# 대상은 열거가 아니라 도출이다. pathspec 의 `*` 는 `/` 를 넘으므로 세 글롭이 모든 깊이를 덮고,
# 심볼릭 링크로 배포된 파일(mode 120000)도 경로로 나온다 — 읽기는 링크를 따라간다.
# 추적 전인 새 파일도 대상이다(`--others --exclude-standard`) — 스캔도 계수도 같은 모집단이다.
CORPUS="$(git ls-files --cached --others --exclude-standard -- \
  'plugins/*/skills/*.md' 'plugins/*/commands/*.md' 'plugins/*/references/*.md' | LC_ALL=C sort -u)"
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' "$CORPUS"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/plugin-root-lock.XXXXXX")" || { echo "mktemp 실패" >&2; exit 1; }
trap 'rm -rf "$TMP"' EXIT
printf '%s\n' "$CORPUS" > "$TMP/corpus.txt"

python3 - "$TMP" "$TMP/corpus.txt" > "$TMP/report.tsv" <<'PY'
import os
import re
import sys

out_dir, corpus_file = sys.argv[1], sys.argv[2]
files = [l for l in open(corpus_file, encoding="utf-8").read().split("\n") if l]
TOKEN = "${CLAUDE_PLUGIN_ROOT}"
SENT = ("그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는 치환되지 않은 채로 온다 — 읽거나 실행할 때 "
        "`${CLAUDE_PLUGIN_ROOT}` 로 바꿔 넣는다. 위 `Read` 줄의 경로가 절대 경로로 보이지 않으면 reference 를 "
        "cwd 에서 찾지 말고 멈춰 보고한다.")
# 가드 메시지의 정본. 이 문안이 치환 없는 하니스에서 cwd 실행을 막는 실제 컨트롤이라, C5 는 부분
# 문자열이 아니라 이 문자열과 통째로 맞춘다(축 3 이 SENT 에 쓰는 방식과 같다).
MSG = ("플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 "
       "값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라")
# 유일하게 허용되는 꼬리. reviewing-spec 은 리뷰 없이 끝나는 모든 출구가 이 복귀 지시로 끝난다는 계약을
# 갖는다(그 skill 의 `ends_with_return`). 「아무 꼬리나 허용」으로 두면 두 문구를 품은 채 뒤에 부정을
# 붙이는 우회가 통과한다 — 실측(변이 M22).
RS_TAIL = (" — 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 "
           "요청하라(brainstorming 의 사용자 리뷰 게이트).")
FM = re.compile(r"\A---\n.*?\n---\n", re.S)
FOPEN = re.compile(r"^(\s*)```(\S*)\s*$")
GUARD = re.compile(r'^\s*([A-Za-z_]\w*)="\$\{CLAUDE_PLUGIN_ROOT\}"; \[ -n "\$\1" \] \|\| '
                   r'\{ echo "([^"]*)" >&2; exit [1-9][0-9]*; \}(\s+#.*)?\s*$')
HEADING = re.compile(r"^#{1,6} ")
READ = re.compile(r"^\s*Read\s+(\S+\.md)\s*$")
SET_U = re.compile(r"^\s*set\s+(-[A-Za-z]*u|-o\s+nounset)")
INTERP = {"python3", "python", "bash", "sh", "node", "exec", "env"}
REP = {"skill": ("plugins/quality-gates/skills/quality-pipeline/SKILL.md", "/scripts/check-review-scope.sh"),
       "ref": ("plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md", "/scripts/resolve-baseline.sh")}


def emit(tag, path, line, text):
    print(f"{tag}\t{path}:{line}\t{' '.join(text.split())[:170]}")


def load(path):
    txt = open(path, encoding="utf-8").read()
    m = FM.match(txt)
    return txt.split("\n"), (txt[:m.end()].count("\n") if m else 0)


def fences(lines, start):
    """(여는 idx, 닫는 idx, 언어, 들여쓰기). 닫는 줄은 같은 들여쓰기의 ``` 이다 — 목록 안 펜스 포함."""
    out, i = [], start
    while i < len(lines):
        m = FOPEN.match(lines[i])
        if m:
            ind, lang = m.group(1), m.group(2)
            close = re.compile("^" + re.escape(ind) + r"```\s*$")
            j = i + 1
            while j < len(lines) and not close.match(lines[j]):
                j += 1
            out.append((i, j, lang, ind))
            i = j + 1
            continue
        i += 1
    return out


scripts_cache = {}


def own_scripts(p):
    if p not in scripts_cache:
        d = os.path.join("plugins", p, "scripts")
        names = os.listdir(d) if os.path.isdir(d) else []
        scripts_cache[p] = {n for n in names if re.search(r"\.(py|sh|js)$", n)}
    return scripts_cache[p]


def command_violations(unit, p, is_bash):
    """자기 스크립트를 실행하는 명령 단위라면 그 안의 cwd 상대 `plugins/<p>/…` 낱말들.

    산문 코드 스팬은 인자가 있을 때만 명령으로 본다 — 경로 하나만 담긴 스팬은 문서 포인터다."""
    toks = [t.strip("\"'`(") for t in unit.split()]
    i = 0
    while i < len(toks) and (re.match(r"^[A-Za-z_]\w*=", toks[i]) or toks[i] in INTERP):
        m = re.match(r'^[A-Za-z_]\w*="?\$\((.*)$', toks[i])
        if m and m.group(1):
            toks[i] = m.group(1).strip("\"'")
            break
        i += 1
    if i >= len(toks) or os.path.basename(toks[i]) not in own_scripts(p):
        return []
    if not is_bash and len(toks) - i == 1:
        return []
    bad = []
    for t in toks[i:]:
        if t.startswith("--") and "=" in t:
            t = t.split("=", 1)[1]
        if t.startswith(f"plugins/{p}/") or t == f"plugins/{p}":
            bad.append(t)
    return bad


# 가드가 잡는 루트 변수 이름은 코퍼스 전체에서 모은다. reference 펜스를 SKILL.md 펜스 뒤에 이어 붙여
# 한 호출로 도는 것이 이 리포의 호출 관습이라, 그 파일 안에 대입이 없어도 루트를 쓰는 펜스일 수 있다 —
# 파일 안 대입만 보면 그런 펜스는 축 2 대상에서 통째로 빠지고 하한도 그것을 세지 않는다.
GLOBAL_ROOTVARS = set()
for _p in files:
    _lines, _s = load(_p)
    for _l in _lines[_s:]:
        _g = GUARD.match(_l)
        if _g:
            GLOBAL_ROOTVARS.add(_g.group(1))
        _m = re.match(r'^\s*([A-Za-z_]\w*)="\$\{CLAUDE_PLUGIN_ROOT\}"', _l)
        if _m:
            GLOBAL_ROOTVARS.add(_m.group(1))

n_a2 = 0
n_guard = 0          # GUARD 정규식이 인식한 가드 줄
n_guard_fence = 0    # 그 가드를 지나는 bash 펜스(펜스당 1)
ref_with_var = []
skills = [f for f in files if f.endswith("/SKILL.md")]
for path in files:
    lines, start = load(path)
    p = path.split("/")[1]
    fz = fences(lines, start)
    infence = set()
    bash_units = []
    for (o, c, lang, ind) in fz:
        infence.update(range(o, c + 1))
        if lang != "bash":
            continue
        buf, first = "", None
        for k in range(o + 1, c):
            t = re.sub(r"(^|\s)#.*$", "", lines[k])
            first = k if first is None else first
            if t.rstrip().endswith("\\"):
                buf += t.rstrip()[:-1] + " "
                continue
            bash_units.append((first, buf + t))
            buf, first = "", None
    # 축 1 · 축 1b(리터럴)
    for k in range(start, len(lines)):
        if re.search(r"\$\{CLAUDE_PLUGIN_ROOT(?!\})", lines[k]):
            emit("A1", path, k + 1, lines[k])
        if "./plugins/" in lines[k]:
            emit("A1B", path, k + 1, lines[k])
    # 축 1b(자기 하니스 인자) — 산문의 코드 스팬(여러 줄 허용, 빈 줄 불허) + bash 논리 줄
    prose = "\n".join("" if (k < start or k in infence) else lines[k] for k in range(len(lines)))
    spans = [(prose[:m.start()].count("\n"), m.group(1)) for m in re.finditer(r"`([^`]+)`", prose)
             if "\n\n" not in m.group(1)]
    for (k, unit, is_bash) in [u + (True,) for u in bash_units] + [s + (False,) for s in spans]:
        for t in command_violations(unit, p, is_bash):
            emit("A1B", path, k + 1, f"{t} ← {unit}")
    # C3 · C4 — 가드 줄
    for (o, c, lang, ind) in fz:
        if lang != "bash":
            continue
        seen_set_u = None
        fence_has_guard = False
        for k in range(o + 1, c):
            if SET_U.match(lines[k]):
                seen_set_u = k
            # C6 — 루트를 대입하고 가드 모양(뒤에 `;`)을 취한 줄은 정본 가드여야 한다. 이 줄이 정규식
            # 밖 형태로 다시 쓰이면 그 자리는 C3 · C4 · C5 · 축 2b 에서 통째로 빠지는데, 개수만 세면
            # 「지켜졌다」와 「보이지 않는다」가 구별되지 않는다.
            if re.match(r'^\s*[A-Za-z_]\w*="\$\{CLAUDE_PLUGIN_ROOT\}"\s*;', lines[k]) \
                    and not GUARD.match(lines[k]):
                emit("C6", path, k + 1, lines[k])
            g = GUARD.match(lines[k])
            if g:
                n_guard += 1
                if not fence_has_guard:
                    fence_has_guard = True
                    n_guard_fence += 1
                if "CLAUDE_PLUGIN_ROOT" in g.group(2):
                    emit("C4", path, k + 1, lines[k])
                if seen_set_u is not None:
                    emit("C3", path, seen_set_u + 1, lines[seen_set_u])
                # C5 — 메시지는 정본 문안과 **통째로** 같다. 치환이 없는 하니스에서 cwd 실행을 실제로
                # 막는 것은 비0 종료가 아니라 이 문장이고(설계 §2 의 고리 (2)), 부분 문자열로 재면 두
                # 문구를 품은 채 뒤에 부정을 붙여 뜻을 뒤집을 수 있다 — 축 3 이 안내 문장에 줄 전체
                # 일치를 쓰는 이유와 같다. 정본은 `[<플러그인>] ` + MSG, reviewing-spec 은 그 뒤에
                # 복귀 꼬리를 붙인다(그 skill 의 계약).
                if g.group(2) not in (f"[{p}] {MSG}", f"[{p}] {MSG}{RS_TAIL}"):
                    emit("C5", path, k + 1, lines[k])
    # 축 2b — 가드가 잡은 루트 변수를 같은 펜스에서 cwd 쪽 값으로 다시 대입하지 않는다.
    # 가드는 빈 값에서 멈출 뿐 그 뒤를 보지 않는다. 이 릴리스가 「설치본 skill 은 워킹트리 스크립트를
    # 더는 돌리지 않는다」를 공시했으므로, `pwd` 로 루트를 되살리려는 유인이 새로 생겼다.
    # reference 뿐 아니라 SKILL.md 펜스도 본다 — 가드를 둔 자리라면 그 가드가 지켜져야 한다.
    for (o, c, lang, ind) in fz:
        if lang != "bash":
            continue
        guarded_here = set()
        for k in range(o + 1, c):
            g = GUARD.match(lines[k])
            if g:
                guarded_here.add(g.group(1))
                continue
            # 규칙은 제약이다: **루트 변수는 cwd 에서 만들어지지 않는다.** 잡는 자리는 줄머리 ·
            # `;&|(){}` 뒤 · 선언 키워드 뒤의 대입(`+=` 포함)과 기본값 전개 네 연산자이고, cwd 판정은
            # 세 표기(`$(pwd` · `$PWD` · 앞머리 `plugins/`)다. 가드를 지난 펜스에서는 우변이 치환 토큰
            # 그 자체여야 한다. 셸 키워드 뒤와 앞붙임 위치는 경계 목록 밖이다(머리말 「대입의 위치」).
            #
            # 줄은 «있는 그대로» 본다. 한때 주석을 먼저 떼어 냈는데 그 제거가 따옴표를 몰라
            # `echo "x # y"; V=$(pwd)` 를 통째로 지웠다 — 막으려던 우회(꼬리 주석에 토큰을 적어 우변
            # 검사를 무력화)는 우변 포착이 공백에서 끊기게 된 뒤로 이미 불가능하므로, 그 제거는 여는
            # 구멍만 남기고 막는 것이 없었다. 대신 주석 «안»의 대입 문구에 거짓 RED 가 날 수 있다 —
            # 소리 나는 쪽이다.
            cwdish = lambda s: bool(re.search(r"\$\(\s*pwd\b|\$\{?PWD\b", s)
                                    or re.match(r"\.?/?plugins/", s.strip("\"'")))
            for v in sorted(guarded_here | GLOBAL_ROOTVARS):
                a = re.search(r"(?:^|[;&|(){}]|\b(?:export|local|declare|typeset|readonly)\s+)\s*"
                              + v + r"\+?=\s*(\S*)", lines[k])
                if a:
                    rhs = a.group(1).strip("\"'")
                    if rhs != TOKEN and (cwdish(rhs) or v in guarded_here):
                        emit("A2B", path, k + 1, lines[k])
                        break
                d = re.search(r"\$\{" + v + r"[:+]?[-=?+]([^}]*)\}", lines[k])
                if d and (cwdish(d.group(1)) or v in guarded_here):
                    emit("A2B", path, k + 1, lines[k])
                    break
            # 재료(`$(pwd)`) 자체는 금지하지 않는다 — 코퍼스는 그것을 러너에 넘기는 **프로젝트 경로**
            # 인자와 사용자 인자 절대화에 정직하게 쓴다(19곳 실측). 제약은 값의 출처가 아니라 **무엇에
            # 대입되는가**다: 루트 변수가 cwd 에서 만들어지면 위반이고, 그 밖의 변수는 이 축이 아니다.
    # 축 2 — reference 의 루트 사용 펜스. reference 한정은 설계 D6 이다: SKILL.md 의 가드 없는 bare
    # 토큰은 치환이 없어도 `/scripts/…` 로 풀려 cwd 로 가지 않는다. 가드가 cwd fallback 으로 변질되는
    # 경우는 축 2 가 아니라 축 2b 가 파일 종류와 무관하게 «보되 다 잡지는 못한다» — 머리말
    # 「대입의 위치」·「가드의 표기」가 그 구멍이다.
    if "/references/" in path:
        body = "\n".join(lines[start:])
        if "CLAUDE_PLUGIN_ROOT" in body:
            ref_with_var.append(path)
        rootvars = set(re.findall(r'([A-Za-z_]\w*)="\$\{CLAUDE_PLUGIN_ROOT\}"', body)) | GLOBAL_ROOTVARS
        for (o, c, lang, ind) in fz:
            if lang != "bash":
                continue
            blk = [(k, lines[k]) for k in range(o + 1, c)]
            def uses(t):
                return "CLAUDE_PLUGIN_ROOT" in t or any(re.search(r"\$\{?" + v + r"\b", t) for v in rootvars)
            if not any(uses(t) for (k, t) in blk):
                continue
            n_a2 += 1
            guarded, bad = set(), None
            for (k, t) in blk:
                g = GUARD.match(t)
                if g:
                    guarded.add(g.group(1))
                    continue
                if "CLAUDE_PLUGIN_ROOT" in t and not guarded:
                    bad = (k, "가드 앞에서 루트 토큰을 쓴다: " + t)
                    break
                late = [v for v in rootvars if re.search(r"\$\{?" + v + r"\b", t) and v not in guarded]
                if late:
                    bad = (k, f"가드 앞에서 ${late[0]} 를 쓴다: " + t)
                    break
            if not guarded:
                emit("A2", path, o + 1, "루트를 쓰는 펜스에 가드가 없다")
            elif bad:
                emit("A2", path, bad[0] + 1, bad[1])
    # 행동 테스트용 대표 펜스
    for role, (rp, needle) in REP.items():
        if path != rp:
            continue
        hits = [(o, c, ind) for (o, c, lang, ind) in fz if lang == "bash"
                and any(needle in lines[k] for k in range(o + 1, c))]
        if len(hits) != 1:
            print(f"REP_BAD\t{role}\t{path}\t{len(hits)}")
            continue
        o, c, ind = hits[0]
        with open(os.path.join(out_dir, f"{role}_fence.sh"), "w", encoding="utf-8") as fh:
            fh.write("\n".join(l[len(ind):] if l.startswith(ind) else l for l in lines[o + 1:c]) + "\n")
        print(f"REP\t{role}\t{path}:{o + 1}")
# 축 3
for r in ref_with_var:
    hits = []
    for s in skills:
        lines, start = load(s)
        heads = [k for k in range(start, len(lines)) if HEADING.match(lines[k])]
        fz = fences(lines, start)
        infence = set()
        for (o, c, lang, ind) in fz:
            infence.update(range(o, c + 1))
        heads = [k for k in heads if k not in infence]
        for k in range(start, len(lines)):
            m = READ.match(lines[k])
            if not m:
                continue
            ptr = m.group(1)
            if ptr.startswith(TOKEN + "/"):
                tgt, form = os.path.normpath(os.path.join("plugins", s.split("/")[1], ptr[len(TOKEN) + 1:])), "abs"
            elif ptr.startswith("$"):
                continue
            else:
                tgt, form = os.path.normpath(os.path.join(os.path.dirname(s), ptr)), "rel"
            if tgt != os.path.normpath(r):
                continue
            lo = max([h for h in heads if h < k], default=start)
            hi = min([h for h in heads if h > k], default=len(lines))
            hits.append((s, k, form, any(lines[j].strip() == SENT for j in range(lo, hi))))
    if not hits:
        emit("A3", r, 0, "이 reference 를 Read 하는 SKILL.md 줄이 없다")
    for (s, k, form, has_sent) in hits:
        if form != "abs":
            emit("A3", s, k + 1, "상대 형태 Read — 설치본에서 모델이 cwd 로 풀 수 있다")
        if not has_sent:
            emit("A3", s, k + 1, "같은 절에 치환 안내 문장(줄 전체)이 없다")
# 축 1b 자기 하니스 인자 탐지의 양성 대조. `own_scripts()` 가 빈 집합이 되면(디렉토리 이름 변경 ·
# 확장자 변경) 그 축은 위반 0 을 조용히 낸다 — 합성 단위 하나를 같은 코드 경로로 태워 잡히는지 본다.
probe = 0
for _p in sorted({f.split("/")[1] for f in files}):
    _sc = sorted(own_scripts(_p))
    if not _sc:
        continue
    if command_violations(f"{_sc[0]} --in plugins/{_p}/x", _p, True):
        probe = 1
    break
print(f"N_PROBE\t{probe}")
# 가드 회계 — 가드 줄 수와 그 가드를 지나는 펜스 수. 판정은 아래 셸 쪽에서 «펜스 수 하나»를 오늘의
# 수로 핀한 하한과 견준다. 한때 `n_guard >= n_guard_fence` 관계식을 썼는데 펜스마다 앞이 k · 뒤가
# min(k,1) 만큼 늘어나 어떤 입력에서도 참이었고, 그 뒤 두 하한을 같은 값으로 핀했더니 앞의 조건이
# 뒤에 지배당해 역시 발화할 수 없었다 — 그래서 단언은 하나다.
print(f"N_GUARD\t{n_guard}\t{n_guard_fence}")
print(f"N_CORPUS\t{len(files)}")
print(f"N_A2\t{n_a2}")
print(f"N_A3\t{len(ref_with_var)}")
PY
py_rc=$?

count() { awk -F'\t' -v t="$1" '$1==t' "$TMP/report.tsv" | wc -l | tr -d ' '; }
val()   { awk -F'\t' -v t="$1" '$1==t {print $2}' "$TMP/report.tsv"; }
show()  { awk -F'\t' -v t="$1" '$1==t {print "      " $2 "  " $3}' "$TMP/report.tsv"; }

assert_eq "$py_rc" "0" "파서가 끝까지 돌았다 (rc $py_rc)"
n_corpus="$(val N_CORPUS)"; n_a2="$(val N_A2)"; n_a3="$(val N_A3)"
[ "${n_corpus:-0}" -ge 30 ] && ok "대상 마크다운 ${n_corpus}개 — vacuous 아님" \
  || no "대상 마크다운이 ${n_corpus:-0}개뿐 — 도출이 무너졌다(글롭 · 경로 변경?)"
for ax in A1 A1B A2 A2B A3 C3 C4 C5 C6; do
  n="$(count "$ax")"
  case "$ax" in
    A1)  what="축 1: 본문의 bare 가 아닌 CLAUDE_PLUGIN_ROOT 전개" ;;
    A1B) what="축 1b: 본문의 cwd 상대 플러그인 루트(./plugins/ · 자기 하니스 cwd 인자)" ;;
    A2)  what="축 2: reference 펜스가 가드보다 먼저 루트를 쓴다 / 가드가 없다" ;;
    A2B) what="축 2b: 가드 뒤에 루트 변수를 다시 대입한다" ;;
    A3)  what="축 3: reference 를 여는 Read 줄이 절대 형태가 아니거나 안내 문장이 없다" ;;
    C3)  what="C3: 가드 앞의 set -u" ;;
    C4)  what="C4: 가드 메시지 안의 루트 토큰" ;;
    C5)  what="C5: 가드 메시지가 정본 문안이 아니다" ;;
    C6)  what="C6: 루트를 대입하는 가드 모양 줄이 정본 가드 형태가 아니다" ;;
  esac
  assert_eq "$n" "0" "$what — ${n}곳"
  [ "$n" -eq 0 ] || show "$ax"
done
# 하한 — 코퍼스가 무너지면(태그 · 들여쓰기 인식 · 경로) 축 2 · 3 이 공허하게 통과한다.
[ "${n_a2:-0}" -ge 22 ] && ok "축 2 대상 reference 펜스 ${n_a2}곳 (하한 22)" \
  || no "축 2 대상 reference 펜스가 ${n_a2:-0}곳 — 하한 22 미달(들여쓴 펜스 인식이 무너졌나?)"
[ "${n_a3:-0}" -ge 2 ] && ok "축 3 대상 reference ${n_a3}개 (하한 2)" \
  || no "축 3 대상 reference 가 ${n_a3:-0}개 — 하한 2 미달"
# 가드 회계 — 가드가 정규식 밖 형태로 다시 쓰이면 그 자리는 C3 · C4 · C5 · 축 2b 에서 조용히 빠진다.
# 그래서 «가드를 지나는 펜스 수»를 오늘의 수로 핀한 하한과 견준다. 단언은 **하나**다: 가드 줄 수는
# 함께 출력하되 판정하지 않는다 — 두 수를 같은 값으로 핀하면 앞의 조건이 뒤에 지배당해 결코 발화할 수
# 없고(그 전에 쓰던 항상-참 관계식과 같은 부류다), 이빨은 어차피 뒤의 하한에서 나온다.
# **가드를 정직하게 지운 것이 «확인된» 경우에만 이 숫자를 같은 커밋에서 내린다** — 내리는 행위가 그
# 삭제의 공시다. 확인 없이 내리면 그만큼의 집행이 영구히 사라진다. 이 공시에는 독립된 증인이 없고
# (핀은 이 파일 «안»의 두 자리 숫자다) 핀은 내려가기만 하므로, 못 잡는 다섯 경우는 머리말
# 「회계의 이빨」에 적혀 있다.
N_GUARD_FENCE_MIN=45
n_guard="$(awk -F'\t' '$1=="N_GUARD" {print $2}' "$TMP/report.tsv")"
n_guard_fence="$(awk -F'\t' '$1=="N_GUARD" {print $3}' "$TMP/report.tsv")"
[ "${n_guard_fence:-0}" -ge "$N_GUARD_FENCE_MIN" ] \
  && ok "가드를 지나는 펜스 ${n_guard_fence}곳 — 핀한 하한 $N_GUARD_FENCE_MIN 이상 (가드 줄 ${n_guard}개는 관찰값, 판정 아님)" \
  || no "가드 회계가 무너졌다: 가드를 지나는 펜스 ${n_guard_fence:-0}곳(하한 $N_GUARD_FENCE_MIN) · 가드 ${n_guard:-0}줄 — 가드가 정규식 밖 형태로 다시 쓰였나(그 자리는 C3 · C4 · C5 · 축 2b 에서 빠진다). 하한을 내리는 것은 «가드를 정말로 지웠음을 확인한» 경우에만 하고, 그 밖에는 원인을 먼저 찾아라 — 확인 없이 내리면 그만큼의 집행이 영구히 사라진다."

# 양성 대조 — 자기 하니스 인자 탐지는 대상 스크립트 목록이 비면 조용히 0 을 낸다(부재 락에는 양의 짝).
[ "$(val N_PROBE)" = "1" ] && ok "축 1b 자기 하니스 탐지 양성 대조 — 합성 단위를 잡는다" \
  || no "축 1b 자기 하니스 탐지가 합성 단위를 잡지 못했다 — 이 축은 이 실행에서 아무것도 재지 않았다"

# ── 행동 — 대표 펜스 둘 ──────────────────────────────────────────────────────
USER_REPO="$TMP/user"; FX="$TMP/fx/quality-gates"
mkdir -p "$USER_REPO/plugins/quality-gates/scripts" "$FX/scripts"
for n in check-review-scope.sh resolve-baseline.sh; do
  printf '#!/bin/sh\ntouch "%s/BAIT.%s"\n' "$TMP" "$n" > "$USER_REPO/plugins/quality-gates/scripts/$n"
  printf '#!/bin/sh\ntouch "%s/FIX.%s"\n' "$TMP" "$n" > "$FX/scripts/$n"
  chmod +x "$USER_REPO/plugins/quality-gates/scripts/$n" "$FX/scripts/$n"
done
for role in skill ref; do
  case "$role" in skill) n=check-review-scope.sh ;; ref) n=resolve-baseline.sh ;; esac
  fence="$TMP/${role}_fence.sh"
  if ! grep -q "^REP	$role	" "$TMP/report.tsv" || [ ! -s "$fence" ]; then
    no "행동($role): 대표 펜스($n)를 정확히 하나 찾지 못했다 — 아래 판정은 무의미하다"
    continue
  fi
  rm -f "$TMP/BAIT.$n" "$TMP/FIX.$n"
  ( cd "$USER_REPO" && env -i PATH="/usr/bin:/bin" HOME="$TMP" bash "$fence" ) >"$fence.out" 2>"$fence.err"; rc=$?
  [ "$rc" -ne 0 ] && ok "행동($role) 무치환: 비0 종료 (rc $rc)" || no "행동($role) 무치환: rc 0 으로 끝났다"
  [ ! -e "$TMP/BAIT.$n" ] && ok "행동($role) 무치환: cwd 의 미끼 $n 가 돌지 않았다" \
    || no "행동($role) 무치환: cwd 의 미끼 $n 가 돌았다 — 사용자 저장소의 스크립트를 실행한다"
  err="$(cat "$fence.err")"
  assert_contains "$err" "플러그인 루트 미해석" "행동($role) 무치환: stderr 에 원인이 나온다"
  assert_contains "$err" "추측하지 말고(cwd 포함) 멈춰 보고하라" "행동($role) 무치환: stderr 에 복구 지시가 나온다"
  python3 -c '
import sys
src, dst, root = sys.argv[1:4]
t = open(src, encoding="utf-8").read()
open(dst, "w", encoding="utf-8").write(t.replace("${CLAUDE_PLUGIN_ROOT}", root))
' "$fence" "$fence.subst" "$FX"
  rm -f "$TMP/BAIT.$n" "$TMP/FIX.$n"
  ( cd "$USER_REPO" && env -i PATH="/usr/bin:/bin" HOME="$TMP" bash "$fence.subst" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] && [ -e "$TMP/FIX.$n" ] && ok "행동($role) 치환 흉내: 픽스처 플러그인의 $n 가 돌았다 (양성 짝)" \
    || no "행동($role) 치환 흉내: 픽스처 플러그인의 $n 가 돌지 않았다 (rc $rc)"
  [ ! -e "$TMP/BAIT.$n" ] && ok "행동($role) 치환 흉내: 미끼는 돌지 않았다" || no "행동($role) 치환 흉내: 미끼가 돌았다"
done

finish
