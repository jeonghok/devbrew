# Law 2 agent-tools 락 — 값 경로(value path)의 선행 결함 4건

- **일자**: 2026-07-28
- **대상**: `plugins/quality-gates/tests/test_agent_frontmatter_keys.sh` — `plugins/*/agents/*.md` 전부에
  fail-closed `tools:` allowlist 를 요구하는 이 리포의 권위 있는 Law 2 락
- **성격**: **기록 전용 감사**. 이 문서는 코드를 고치지 않는다. 사용자가 별도 사이클로 라우팅한
  선행(pre-existing) 결함 목록이다.
- **확인 범위**: 4건 전부 `5b0caff`(브랜치 이전)와 HEAD(`feature/spec-distill-brief-review-pipeline`,
  v2.14.2 수정 포함) **양쪽에서 동일하게 재현**된다 — 어느 것도 이 브랜치가 만든 것이 아니고,
  이 브랜치의 v2.14.0~v2.14.2 수정이 건드리지도 않았다.
- **측정 환경**: macOS(darwin 25.5.0), bash 3.2, BSD sed/grep/awk, PyYAML 6.0.3, python3.

## 공통 근본 원인

**구조화된 포맷의 의미(semantics)를 셸 텍스트 매칭으로 검사하고 있다.** 같은 값은 늘 다른
스펠링이 있고, 그래서 **열거는 닫히지 않는다.** 아래 4건은 서로 다른 버그가 아니라 그 하나의
성질이 네 자리에서 드러난 것이다.

이 브랜치가 이미 적용한 두 봉쇄는 **닫히는 모양**이었다:

1. **키 경로의 여집합(complement) 형태 화이트리스트** — 스펠링을 열거하는 대신 "허용 형태
   밖은 전부 거절"로 뒤집었다(v2.14.1 S-1, v2.14.2 A-3).
2. **실제 파서와의 differential 검사** — 락이 믿은 값과 PyYAML 이 resolve 하는 값을 대조한다
   (`test_agent_tools_lock_differential.sh`, v2.14.1 S-3).

**값 경로는 둘 중 어느 것도 받지 못했다.** 값 검사는 여전히 "거절할 시작 문자"와 "거절할 제어
문자"의 열거이고, differential 하니스에는 아래 결함들을 겨눈 코퍼스 케이스가 하나도 없다.
(닫힘 보증이 왜 열거보다 강한지는 락 파일 자체의 `(2) 형태 화이트리스트 = 닫힘 보증` 주석 참조.)

## 재현 하니스

아래 4건 전부 이 스크립트 하나로 재현된다. 인자는 검사할 락의 경로다.

```bash
#!/usr/bin/env bash
# 사용: repro.sh <락 경로>
#   현행:  repro.sh plugins/quality-gates/tests/test_agent_frontmatter_keys.sh
#   이전:  git show 5b0caff:plugins/quality-gates/tests/test_agent_frontmatter_keys.sh > /tmp/old.sh
#          repro.sh /tmp/old.sh
set -u
LOCK="${1:?lock path}"
W="$(mktemp -d)" || exit 1
[ -n "$W" ] && [ -d "$W" ] || exit 1
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/plugins/probe/agents"
mk() { printf -- '---\nname: probe\ndescription: fixture\nmodel: inherit\n%b\n---\n\nbody\n' \
       "$1" > "$W/plugins/probe/agents/probe.md"; }
for f in 'tools: null' 'tools: ~' 'tools: Null' 'tools: NULL' 'tools: # 도구 없음' \
         'tools: {grant: Write}' 'tools: Read\0302\0205tools: [Write]' \
         'tools: Read\0342\0200\0250tools: [Write]' 'tools: Read\0342\0200\0251tools: [Write]' \
         'tools: Read,\0302\0240Write'; do
  mk "$f"
  printf '%-40s C=%-6s UTF8=%s\n' "$(printf '%b' "$f" | tr '\n' '/')" \
    "$(LC_ALL=C           bash "$LOCK" "$W" >/dev/null 2>&1 && echo GREEN || echo RED)" \
    "$(LC_ALL=en_US.UTF-8 bash "$LOCK" "$W" >/dev/null 2>&1 && echo GREEN || echo RED)"
done
```

락이 *"자신이 검증했다고 믿는 값"* 은 진단 채널에서 직접 읽는다(추측하지 말 것 —
락 로직을 재구현하면 같은 버그를 두 번 쓰게 되어 아무것도 증명하지 못한다):

```bash
DEVBREW_AGENT_TOOLS_LOCK_EMIT=1 bash <락> "$W" 3>&1 1>/dev/null 2>/dev/null
# → DECL<TAB><파일><TAB>scalar|zero-seq<TAB><락이 믿은 값>
```

**실측 결과 (`5b0caff` 와 HEAD 가 한 줄도 다르지 않다):**

```
tools: null                              C=GREEN  UTF8=GREEN
tools: ~                                 C=GREEN  UTF8=GREEN
tools: Null                              C=GREEN  UTF8=GREEN
tools: NULL                              C=GREEN  UTF8=GREEN
tools: # 도구 없음                        C=GREEN  UTF8=GREEN
tools: {grant: Write}                    C=GREEN  UTF8=GREEN
tools: Read<U+0085>tools: [Write]        C=GREEN  UTF8=GREEN
tools: Read<U+2028>tools: [Write]        C=GREEN  UTF8=GREEN
tools: Read<U+2029>tools: [Write]        C=GREEN  UTF8=GREEN
tools: Read,<U+00A0>Write                C=GREEN  UTF8=RED
```

---

## ① YAML null 동의어가 bare-`tools:` 가드를 그대로 통과한다

| 항목 | 내용 |
|---|---|
| **트리거 문서** | `tools: null` · `tools: ~` · `tools: Null` · `tools: NULL` · 값 자리에 주석만 있는 `tools: # 도구 없음` |
| **PyYAML resolve** | 다섯 전부 `None` |
| **락 보고** | 다섯 전부 **PASS**. `DECL … scalar … null` / `~` / `Null` / `NULL` / `# 도구 없음` — 즉 락은 이것들을 *"토큰 하나짜리 정상 allowlist"* 로 검증했다고 믿는다 |
| **재현** | 위 하니스의 앞 5줄 |

락은 bare `tools:`(값 없음)를 **명시적으로** 거절하고, 그 근거를 자기 주석에 이렇게 적어 뒀다:

> null 은 런타임이 "키 미설정 = 전 도구 허용"으로 읽을 수 있는 silent fail-open 이고 빈 시퀀스와
> **다른 값**이다.

그 근거는 값이 `None` 이라는 데서 나온다. 그런데 **같은 `None` 을 뜻하는 다른 다섯 스펠링은 전부
통과한다.** 거절된 것은 값이 아니라 스펠링 하나였다. 이것은 이 브랜치가 키 경로에서 방금 고친
것(같은 키의 여러 스펠링을 열거로 막으려다 샌 것, v2.14.1 S-1)과 **같은 실패이고, 같은 파일에서
한 화면 아래**에 있다.

`tools: # 도구 없음` 이 특히 사나운 이유: 인라인 주석 제거는 `[[:blank:]]#` 를 요구하는데, 이
값은 트림 뒤 `#` 로 시작해 앞에 blank 가 없다 — 그래서 주석이 벗겨지지 않고 `# 도구 없음` 이
통째로 "무해한 토큰 하나"가 된다. 파서에게는 값 자체가 없는 줄이다.

## ② flow mapping 이 거절 집합에 없다

| 항목 | 내용 |
|---|---|
| **트리거 문서** | `tools: {grant: Write}` |
| **PyYAML resolve** | `{'grant': 'Write'}` (dict) |
| **락 보고** | **PASS**. `DECL … scalar … {grant: Write}` — plain scalar 로 취급하고, comma 토큰 루프는 `{grant: Write}` 라는 토큰 하나만 보므로 정확 문자열 `Write` 와 매칭되지 않는다 |
| **재현** | 위 하니스의 6번째 줄 |

값 단계의 구조적 거절 `case` 는 `[` · 인용부호 · `>`/`|` · `&`/`*` · `!!` 를 거절한다 — **`{` 는
없다.** flow-seq(`[…]`)를 거절한 근거인 *"토큰이 쪼개져 금지 이름 정확매칭을 피한다"* 가
flow mapping 에 **그대로** 적용되는데도 열거에서 빠졌다. 열거가 닫히지 않는다는 것의 교과서적
사례다.

## ③ Unicode 줄바꿈이 중복 키를 숨긴다

| 항목 | 내용 |
|---|---|
| **트리거 문서** | `tools: Read<U+0085>tools: [Write]` (U+2028 · U+2029 도 동일) |
| **PyYAML resolve** | `['Write']` — 파서는 이것을 **두 줄**로 보고 중복 키를 마지막 값으로 resolve 한다 |
| **락 보고** | **PASS**. `DECL … scalar … Read<U+0085>tools: [Write]` — 락에게는 **한 줄**이라 중복 키 카운트가 1 이고, 값은 무해한 토큰 하나로 보인다 |
| **재현** | 위 하니스의 7~9번째 줄 |

YAML 명세는 U+0085(NEL) · U+2028(LS) · U+2029(PS) 를 줄바꿈으로 취급하고 PyYAML 은 그대로
구현한다. `grep`/`awk` 는 그러지 않는다. 그래서 락의 **줄 개념 자체가** 파서와 다르다 —
frontmatter 창 추출(`awk`), 중복 키 카운트(`grep -c`), 형태 화이트리스트(column-0 판정),
multiline continuation 탐지가 **전부** 이 잘못된 줄 분할 위에 서 있다.

이것이 v2.14.1 S-1 이 봉쇄한 중복 키 우회(`tools : [Write]`)와 **동일한 공격**이라는 점이
핵심이다. S-1 은 *스펠링* 축을 닫았고, 이 결함은 *줄 분할* 축으로 같은 곳에 도달한다.

## ④ L3 토큰 트림이 값 경로에서 유일하게 `LC_ALL=C` 가 없는 `sed` 다

| 항목 | 내용 |
|---|---|
| **트리거 문서** | `tools: Read,<U+00A0>Write` (comma 뒤 NBSP) |
| **PyYAML resolve** | 문자열 `'Read,\xa0Write'` |
| **락 보고** | **로케일에 따라 갈린다.** `LC_ALL=C` → **PASS** / `LC_ALL=en_US.UTF-8`·`ko_KR.UTF-8`·앰비언트 `C.UTF-8` → FAIL |
| **재현** | 위 하니스의 마지막 줄 — 두 열의 값이 다른 유일한 행이다 |

L3 토큰 루프의 per-token 트림은 값 경로에서 **유일하게 `LC_ALL=C` 가 붙지 않은 `sed`** 다
(HEAD 기준 `test_agent_frontmatter_keys.sh` L3 루프 첫 줄, `sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`).
그 위쪽 값-패딩 검사들은 v2.14.1 S-2 에서 전부 `LC_ALL=C` 로 고정됐는데 이 한 줄만 남았다 —
**같은 클래스, 미청소.**

실측된 귀결이 두 가지다:

- **보안 컨트롤의 verdict 가 앰비언트 로케일에 의존한다.** 같은 바이트가 CI 에서는 RED,
  `LC_ALL=C` 셸에서는 GREEN 이다. 게이트의 비결정성 그 자체가 결함이다.
- **`LC_ALL=C` 쪽이 fail-open 방향이다.** 그 로케일에서 토큰은 `\xa0Write` 로 남아 정확 문자열
  `Write` 와 매칭되지 않는다. 반면 JS 런타임의 `String.prototype.trim()` 은 U+00A0 를 벗기므로
  같은 값을 `["Read","Write"]` 로 읽는다 — 락이 승인한 선언이 런타임에서 `Write` 를 부여한다.

⚠️ **이 한 건은 기존 differential 하니스가 잡지 못한다.** ①②③ 은 파서 합치 불변식에 바로
걸린다(basis=`scalar` 인데 파서가 각각 `null`/`other`/`list` 로 resolve) — 코퍼스 케이스만 없을
뿐이다. ④ 는 락과 PyYAML 이 **값 문자열에 대해 합치한다**(둘 다 `Read,\xa0Write`, 토큰 분할도
동일). 어긋나는 상대는 PyYAML 이 아니라 **런타임의 trim 의미론**이다. 그래서 ④ 는 파서
differential 이 아니라 **L1 verdict 기대치**(그리고 로케일을 명시적으로 강제하는 회귀 테스트)로만
못 박을 수 있다.

---

## 이 목록을 어떻게 닫아야 하는가 (다음 사이클용 메모, 처방 아님)

네 건을 하나씩 패치하는 것은 **다섯 번째 스펠링을 부르는 길**이다 — 이 파일이 ⑥~⑰ 과
S-1/S-2 로 이미 세 라운드에 걸쳐 배운 게임이다. 값 경로에 아직 없는 두 가지가 위에서 말한
바로 그 **닫히는 모양** 둘이다:

- **여집합 화이트리스트**: "거절할 시작 문자 열거" 를 뒤집어 *"허용 값 형태(plain 단일 라인
  comma-scalar, 그리고 리터럴 `[]`) 밖은 전부 거절"* 로. `{`(②)·null 동의어(①)는 열거하지
  않아도 이 뒤집기 하나에 걸린다.
- **파서 differential 코퍼스**: ①②③ 은 이미 존재하는 불변식이 잡는다. 케이스만 없다.
  ④ 는 로케일을 명시적으로 흔드는 별도 케이스가 필요하다.

## 남는 한계

- 이 측정은 macOS/BSD 도구체인 1대에서 이뤄졌다. GNU sed/grep 은 `[[:space:]]` 의 비-ASCII
  취급이 다를 수 있어 ④ 의 두 열이 리눅스에서 뒤집힐 수 있다 — 결론(로케일 의존 = 비결정)은
  그대로지만 어느 로케일이 fail-open 인지는 재측정이 필요하다.
- ④ 의 "JS 런타임이 U+00A0 를 trim 한다" 는 `String.prototype.trim` 의 명세(WhiteSpace 에
  `<USP>` 포함)에 근거한 것이고, Claude Code 런타임이 `tools:` 값을 실제로 그 함수로
  분해하는지는 **이 감사에서 확인하지 않았다**. 확인 실패는 부재 증명이 아니므로 그 전제에
  기대지 않고도 성립하는 결함(verdict 의 로케일 의존)을 먼저 적어 뒀다.
