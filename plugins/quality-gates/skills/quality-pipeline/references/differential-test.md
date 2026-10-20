# 차등 테스트 절차

이번 변경이 닿는 테스트를 기준선 트리와 HEAD 트리에서 각각 돌려 짝짓는다. 무엇을 돌릴지는 오케스트레이터가
고르고, 실행 · 짝짓기 · 판정 입력은 스크립트가 만든다. 스크립트는 전부 오케스트레이터가 직접 부른다 — 테스트를
돌려 결과를 보고하는 subagent 는 없고, 이 호출 결과가 authoritative 다.

## 지킬 것

- R1 0 단위 · 0 어댑터는 `not-certified (scope-empty)` 다.
- R2 어느 축이든 error 는 인증을 막고, (pass, error) 는 NEW_REGRESSION 이다.
- R3 exit 127 · 러너 없음 · setup 실패는 unrun 이고, (unrun, x) 는 baseline-unrunnable 이다.
- R4 0/1/127 밖의 종료 코드는 unrun 으로 접지 않는다.
- R5 기준선 행은 기준선 트리에서 실제로 돈 것만 유효하다.
- R6 실행 안 메모는 리포 밖에 살고 실행과 함께 사라진다.
- R7 단위마다 축별로 정확히 한 행이다. 누락은 SILENT_DROP, 중복은 거부다.
- R8 기대 단위 목록은 두 결과와 독립인 입력(배정 파일)이다.
- R9 bulk · 도말 실행의 양측 red 는 `granularity-smear` 이고, 입도는 러너에서 도출한다.
- R10 unit 별로 돈 양측 red 는 막지 않고 공시한다.
- R11 HEAD 축은 작업트리 전체를 봉인한 별도 트리다. 지금 쓰는 작업 트리에서 돌리지 않는다.
- R12 HEAD 축을 기준선 커밋으로 만들지 않는다.
- R13 두 축의 트리가 같으면 비교가 성립하지 않는다(not-certified).
- R14 기준선 트리는 어댑터를 스스로 다시 탐지한다.
- R15 flaky 재실행은 NEW_REGRESSION 만, HEAD 트리에서, 정확히 한 번이다. 관측하지 못하면 원래 행을 지킨다.
- R16 고른 단위를 어느 어댑터도 못 돌리면 막는다.
- R17 생산자 실패를 「비었음」으로 읽지 않는다.
- R18 짝짓기 · 집계가 0 이 아닌 종료 코드를 내거나 읽을 수 없으면 `not-certified (error-axis)` 다.
- R19 배정된 러너마다 두 축의 행 파일이 있어야 집계한다.
- R20 단위는 트리 안에 있어야 하고, shell 단위는 `tests/*.sh` 이면서 실행 비트가 있어야 한다.
- R21 unittest 는 판정하지 못하는 파일을 claim 하지 않고, go 단위는 `*_test.go` 를 요구한다.
- R22 kill switch 는 오케스트레이터와 러너 양쪽에서 저장소 코드 실행을 막는다.
- R23 일회용 트리는 모든 종료 경로에서 지운다.
- R24 판정 인자는 숫자를 만든 직후의 펜스가 낸 줄(`qg-verdict-args:`)의 글자 그대로다 — 모델은 숫자를 고르거나 옮겨 적지 않고 그 줄을 판정 펜스에 붙인다.

R2~R5 · R7 · R9~R11 · R14 · R15 · R17 · R19~R21 은 `run-test-selection.sh` 와 `diff-test-results.py` 가
코드로 지킨다. 아래 절차는 그 스크립트들을 빠짐없이 부르는 순서다.

## D0 실행 시작 — 첫 iteration 에서 한 번

`DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 이면 이 절차 전체를 건너뛰고 판정 입력은
`--reason kill-switch` 다(R22). 차등 결과 줄은 SKILL 의 kill switch 문단 펜스가 낸다. 러너도 같은 스위치를 보고 저장소 코드를 돌리지 않는다.

실행 안 메모를 만든다. 경로를 기억해 두고 실행이 끝날 때까지 모든 iteration 이 같은 메모를 쓴다(R6):

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/qg-worktree.sh" memo-init "<project_dir>"
```

exit 2 면 stderr 를 그대로 보이고 이 실행에서는 차등 테스트를 하지 않는다 — 이 iteration 과 이후 모든 iteration 의
판정 입력은 `--reason error-axis` 다(D1~D6 을 돌지 않는다). 차등 결과 줄은 iteration 마다 D7 의 펜스로 낸다.

기준선을 정한다. 기준선 커밋은 실행마다 하나로 고정된다 — 기준선 행 파일(`<memo>/baseline-<runner>.tsv`)이 한
커밋에 묶여 iteration 사이에 재사용되기 때문이다. 첫 iteration 의 스코프 파일로 정한다. 범위 모드(세션 폴더에
`range-scope.txt` 가 있다)면 아래 `resolve-baseline.sh` 펜스를 돌리지 않는다 — 기준선은 그다음 판별 펜스가 찍는 시작 커밋이고,
지금 체크아웃의 merge_base 는 범위와 무관하다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/resolve-baseline.sh"
```

```bash
TOP="$(git rev-parse --show-toplevel)" || { echo "[quality-gates] git 리포 밖이다 — /quality-gates:quality-pipeline 은 git 리포 안에서만 돈다. 멈춘다." >&2; exit 1; }
RD="${TOP}/.claude/quality-gates/<session-id>"
S="$RD/topic-scope.txt"; RS="$RD/range-scope.txt"
if [ -f "$RS" ] && [ "$(sed -n 's/^status: //p' "$RS")" = ok ]; then printf 'scope0=range\nboundary=%s\n' "$(sed -n 's/^start: //p' "$RS")"
elif [ -f "$S" ] && [ "$(sed -n 's/^status: //p' "$S")" = ok ]; then printf 'scope0=topic\nboundary=%s\n' "$(sed -n 's/^boundary: //p' "$S")"; else echo "scope0=session"; fi
```

- `scope0=range` 이면 기준선 커밋은 `boundary=` 값 — 범위의 시작 커밋이다(리뷰 diff 의 기준과 같다).
- `scope0=topic` 이면 기준선 커밋은 `boundary=` 값이다.
- `scope0=session` 이면 기준선 커밋은 `merge_base:` 다. `degraded: yes` 면 기준선 커밋은 `-` 이다 — 기준선 축을
  돌리지 못한다. session 스코프에서는 D2 가 같은 기준선을 풀다가 exit 4 로 멈추므로 판정 입력은 error-axis 가 된다.

`scope0` 와 기준선 커밋을 기억해 둔다 — D1 이 매 iteration 대조한다. 뒤 iteration 에서 스코프가 session ↔ topic 으로
바뀌거나 경계가 달라지면 그 iteration 은 기준선이 어긋나 판정하지 않는다(error-axis, D1). 한 줄로 알린다:
`> [quality-gates] baseline: <base 또는 topic 키> @ <기준선 커밋 앞 12자> (<ahead>커밋 앞섬)`.
범위면 키 칸은 `range` 이고 앞섬 칸은 범위 파일의 `commits:` 값이다. 범위 모드는 iteration 1 에서 끝나므로 기준선이
어긋날 뒤 iteration 이 없다.

## D1 HEAD 축 트리 — 매 iteration

이 iteration 의 스코프 파일(Step 1a 가 이번 iteration 에 쓴 것)을 읽어 HEAD 축 트리를 만든다(R11 · R12). 먼저 앞
iteration 이 세션 폴더에 남긴 차등 출력 사본을 지운다 — 이 iteration 이 D5 에 닿지 못하면 사본이 없어야 한다.
범위 스코프면 봉인하지 않고 범위 파일의 끝 커밋으로 `create-head --range` 를 부른다(얼린 범위 파일과 다시 대조한다 —
시작 커밋이나 움직인 ref 로는 만들지 않는다). 토픽 스코프면 봉인하지 않고 그 파일의 `head_commit:` 으로 `create-head --topic` 을 부르고(합친 트리를 다시 도출해
대조한다), 아니면 작업트리 전체를 봉인한 커밋으로 부른다. `<D0 의 스코프: topic | session | range>` 와 `<D0 의 기준선 커밋>` 은
D0 에서 기억해 둔 값이다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
TOP="$(git rev-parse --show-toplevel)" || { echo "[quality-gates] git 리포 밖이다 — /quality-gates:quality-pipeline 은 git 리포 안에서만 돈다. 멈춘다." >&2; exit 1; }
RD="${TOP}/.claude/quality-gates/<session-id>"
rm -f "$RD/differential.yaml" "$RD/differential-not-counted.md"
SCOPE0="<D0 의 스코프: topic | session | range>"; BASE0="<D0 의 기준선 커밋>"
S="$RD/topic-scope.txt"; RS="$RD/range-scope.txt"; scope=session; base="$BASE0"; key=""; hc=""; tree=""
if [ -f "$RS" ] && [ "$(sed -n 's/^status: //p' "$RS")" = ok ]; then
  scope=range; base=$(sed -n 's/^start: //p' "$RS"); hc=$(sed -n 's/^end: //p' "$RS"); tree="$hc"
elif [ -f "$S" ] && [ "$(sed -n 's/^status: //p' "$S")" = ok ]; then
  scope=topic; base=$(sed -n 's/^boundary: //p' "$S"); key=$(sed -n 's/^topic_key: //p' "$S")
  hc=$(sed -n 's/^head_commit: //p' "$S"); tree=$(sed -n 's/^tree: //p' "$S")
fi
if [ "$scope" != "$SCOPE0" ] || [ "$base" != "$BASE0" ]; then
  echo "[quality-gates] 이번 반복의 비교 기준(${scope} @ ${base:--})이 처음 반복의 기준(${SCOPE0} @ ${BASE0})과 달라서, 이번 반복의 테스트 비교는 판정에 쓰지 않는다(error-axis). 기준을 바꾸려면 /quality-gates:quality-pipeline 을 처음부터 다시 돌린다." >&2
  echo "axis=mismatch"; exit 0
fi
head_tree=""; cand=""
if [ "$scope" = range ]; then
  cand="$hc"; head_tree=$("$QG/scripts/qg-worktree.sh" create-head "$hc" "<session-id>" --range "$RD/range-scope.txt") || head_tree=""
elif [ "$scope" = topic ]; then
  cand="$hc"; head_tree=$("$QG/scripts/qg-worktree.sh" create-head "$hc" "<session-id>" --topic "$key") || head_tree=""
else
  cand=$("$QG/scripts/seal-worktree.sh" seal "<session-id>") || cand=""
  if [ -n "$cand" ]; then head_tree=$("$QG/scripts/qg-worktree.sh" create-head "$cand" "<session-id>") || head_tree=""; fi
fi
head_commit="-"; [ -n "$head_tree" ] && head_commit="$cand"
printf 'axis=ok\nscope=%s\nboundary=%s\ntree=%s\nhead_commit=%s\nhead_tree=%s\n' "$scope" "$base" "${tree:--}" "$head_commit" "$head_tree"
```

- `axis=mismatch` 면 stderr 를 그대로 보이고 D2~D5 를 건너뛴다. D5 전에 끝났으므로 이 iteration 의 판정 입력은
  `--reason error-axis` 다(D7).
- `head_commit=` 이 이 iteration 의 HEAD 커밋이다. 트리를 못 만들었으면 `-` 이고 `head_tree=` 는 비었다 — D3 이
  HEAD 축을 관측 없음으로 채우고 D5 에도 `-` 를 넘긴다.

## D2 후보와 배정 — 매 iteration

후보의 바닥을 받는다. 토픽 · 범위 스코프면 `--topic <boundary> <tree>` 를 붙인다 — 두 값은 D1 이 이 iteration 의 스코프
파일에서 읽어 찍은 `boundary=` · `tree=` 다. 범위면 그것이 `--topic <start> <end>`(범위 파일의 시작 · 끝 커밋)다.
펜스가 같은 스코프 파일에서 두 값을 직접 읽는다 — 옮겨 적지 않는다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
TOP="$(git rev-parse --show-toplevel)" || { echo "[quality-gates] git 리포 밖이다 — /quality-gates:quality-pipeline 은 git 리포 안에서만 돈다. 멈춘다." >&2; exit 1; }
RD="${TOP}/.claude/quality-gates/<session-id>"
S="$RD/topic-scope.txt"; RS="$RD/range-scope.txt"; b=""; t=""
if [ -f "$RS" ] && [ "$(sed -n 's/^status: //p' "$RS")" = ok ]; then
  b=$(sed -n 's/^start: //p' "$RS"); t=$(sed -n 's/^end: //p' "$RS")
elif [ -f "$S" ] && [ "$(sed -n 's/^status: //p' "$S")" = ok ]; then
  b=$(sed -n 's/^boundary: //p' "$S"); t=$(sed -n 's/^tree: //p' "$S")
fi
if [ -n "$t" ]; then
  "$QG/scripts/compute-test-scope-candidates.sh" --topic "$b" "$t"; echo "candidates rc=$?"
  "$QG/scripts/compute-test-scope-candidates.sh" --total --tree "$t"; echo "total rc=$?"
else
  "$QG/scripts/compute-test-scope-candidates.sh"; echo "candidates rc=$?"
  "$QG/scripts/compute-test-scope-candidates.sh" --total; echo "total rc=$?"
fi
```

`candidates rc` · `total rc` 의 exit 4 는 「후보 없음」이 아니다(R17). stderr 를 그대로 보이고 이 iteration 의 판정 입력은 `--reason error-axis` 다.

후보는 바닥이다. 오케스트레이터는 diff 와 의도 출처를 보고 영향 테스트를 **더할** 수만 있고 뺄 수는 없다. 낡았거나
(이번 변경과 무관한 옛 동작을 검사) 골라 담은(변경을 피해 가는) 테스트로 판단한 것은 그대로 돌리되 커버리지로 세지
않는다. 그 목록을 테스트마다 한 줄 이유와 함께 메모에 적는다 — 없으면 `(없음)` 한 줄이다. 영향 테스트가 하나도
없다고 판단되면 그 사실도 여기에 적는다 — 0 단위면 D5 가 scope-empty 를 낸다. 실행 끝의 `result.md` `## 차등 테스트` 가
이 목록을 싣는다:

```bash
cat > "<memo>/not-counted-i<N>.md" <<'QG_NOT_COUNTED'
<- <테스트 경로> — <이유 한 줄> 줄들, 없으면 (없음)>
QG_NOT_COUNTED
```

D3/D4 밖에서 스위트나 테스트를 돌릴 수 있다 — 원인을 찾는 조사용이다. 돌리기 전에 `> [quality-gates] 조사용 실행 — 판정에 안 씀: <명령>` 한 줄을 내고, 결과를 판정 입력 어디에도(배정 · 커버리지로 세지 않을 목록 · 행 파일 · D5 · 합성기) 넣지 않고, D3/D4 의 트리(기준선 · head 트리)에서는 돌리지 않는다. `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 이면 조사용 실행도 하지 않는다 — 저장소 코드를 호스트에서 돌리기 때문이다.

고른 파일을 배정 파일로 바꾼다. unit 변환(파일 → 패키지 · bulk 흡수)은 스크립트가 한다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
printf '%s\n' <고른 파일들> | "$QG/scripts/run-test-selection.sh" assign "<스캔 트리>" "<memo>/assign-i<N>.tsv"
```

스캔 트리는 D1 의 `head_tree` 다(비었으면 `<project_dir>`). 범위 스코프에서 이 대체는 어느 러너가 맡을지 정하는 데만 쓰인다 —
`head_tree` 가 비면 D3 이 HEAD 축을 관측 없음으로 채우므로 지금 체크아웃(시작 커밋일 수 있다)의 테스트 결과는 판정에 들어가지 않는다. 배정 파일의 행은
`<unit>\t<runner|unclaimed>\t<granularity>` 이고 마지막 줄은 `#qg-assign` 꼬리다. `unclaimed` 는 어느 러너 어댑터
9종도 못 돌리는 후보다 — 판정에서 silent-drop 이 된다(R16).

계획을 한 줄로 알린다. 분모는 `--total` 의 출력이다(토픽 · 범위 스코프면 `--total --tree <tree>` — 범위면 `--total --tree <end>`):

> `> Differential scope: 영향 테스트 <N>개 선택 (전체 <M>개 중), 러너 <runners> — 이번 변경의 영향분만 기준선 대비로 돌린다.`

`granularity: bulk` 러너가 하나라도 있으면 같은 줄 뒤에 `커버리지 미보장(러너가 선택을 무시함)` 을 붙인다.

## D3 HEAD 축 실행 — 매 iteration

배정 파일의 러너마다(unclaimed 제외) 그 러너의 unit 을 bulk 로 돌리고, fail 이나 error 행이 있으면 그 unit 만
per-unit 으로 다시 돌린다. 다시 돈 행이 bulk 행을 교체한다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/run-test-selection.sh" run "<head_tree>" "<runner>" bulk "<memo>/head-<runner>-i<N>.tsv" <unit>...
"$QG/scripts/run-test-selection.sh" run "<head_tree>" "<runner>" per-unit "<memo>/head-<runner>-i<N>.tsv" <fail·error 인 unit>...
```

D1 의 `head_tree` 가 비었으면(봉인이나 트리 생성 실패 — `head_commit=-`) stderr 를 그대로 보이고, 지금 작업 트리로 대신 돌리지 않는다. 대신 그
러너의 unit 을 관측 없음으로 채우고 HEAD 커밋은 `-` 로 둔다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/run-test-selection.sh" unrun "<memo>/head-<runner>-i<N>.tsv" "<runner>" - <unit>...
```

## D4 기준선 축 — 매 iteration, 아직 돌지 않은 unit 만

같은 실행 안에서 기준선 커밋은 바뀌지 않는다 — 아래 `<기준선 커밋>` 은 D0 이 정한 값이다. 메모에 관측된 행이 없는
unit 만 돌린다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/run-test-selection.sh" pending "<memo>/baseline-<runner>.tsv" <unit>...
```

나온 unit 이 있으면 기준선 트리를 만들어 D3 과 같은 bulk → per-unit 두 단계로 돌린다. 기준선 트리는 어댑터를
스스로 다시 탐지하므로 HEAD 의 어댑터 집합을 가져다 쓰지 않는다(R14):

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
base_tree=$("$QG/scripts/qg-worktree.sh" create-baseline "<기준선 커밋>" "<session-id>") || base_tree=""
printf 'base_tree=%s\n' "$base_tree"
```

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/run-test-selection.sh" run "<base_tree>" "<runner>" bulk "<memo>/baseline-<runner>.tsv" <pending unit>...
"$QG/scripts/run-test-selection.sh" run "<base_tree>" "<runner>" per-unit "<memo>/baseline-<runner>.tsv" <fail·error 인 unit>...
```

기준선 커밋이 `-` 이거나 `base_tree` 가 비면 stderr 를 보이고 pending unit 을 관측 없음으로 채운다 — 커밋 칸에는
그 축의 기준선 커밋(`-` 포함)을 그대로 쓴다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/run-test-selection.sh" unrun "<memo>/baseline-<runner>.tsv" "<runner>" "<기준선 커밋>" <pending unit>...
```

## D5 짝짓기 — 매 iteration

리포 루트에서 부른다(펜스가 그리로 옮긴다). `<기준선 커밋>` 은 D0 의 값, `<HEAD 커밋>` 은 D1 이 찍은 `head_commit=`
값(`-` 포함)이다. 같은 펜스가 출력 파일과 D2 의 커버리지 제외 목록을 세션 폴더에 사본으로 덮어쓰고, 그 사본
`$RD/differential.yaml` 이 이 iteration 의 판정 입력이다 — Step 4 의 합성기와 실행 끝의 `result.md` 가 메모가 아니라 이 사본
(마지막 iteration 의 것)을 읽는다. 펜스 끝에서 `verdict.py --emit-args` 가 같은 사본으로 차등 결과 줄을 낸다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
TOP="$(git rev-parse --show-toplevel)" || { echo "[quality-gates] git 리포 밖이다 — /quality-gates:quality-pipeline 은 git 리포 안에서만 돈다. 멈춘다." >&2; exit 1; }
RD="${TOP}/.claude/quality-gates/<session-id>"
cd "$TOP" || exit 1
"$QG/scripts/diff-test-results.py" --assign "<memo>/assign-i<N>.tsv" --rows "<memo>" --iter <N> \
  --baseline-commit "<기준선 커밋>" --head-commit "<HEAD 커밋>" > "<memo>/diff-i<N>.yaml"
diff_rc=$?
if [ "$diff_rc" -eq 0 ] && [ -s "<memo>/diff-i<N>.yaml" ]; then
  cp "<memo>/diff-i<N>.yaml" "$RD/differential.yaml" || { diff_rc=4; rm -f "$RD/differential.yaml"; }
else
  rm -f "$RD/differential.yaml"
fi
if [ -f "<memo>/not-counted-i<N>.md" ]; then cp "<memo>/not-counted-i<N>.md" "$RD/differential-not-counted.md"; else rm -f "$RD/differential-not-counted.md"; fi
echo "diff_rc=$diff_rc"
if [ "$diff_rc" -eq 0 ] && [ -f "$RD/differential.yaml" ]; then
  python3 "$QG/scripts/verdict.py" --emit-args --differential "$RD/differential.yaml"
else
  python3 "$QG/scripts/verdict.py" --emit-args --reason error-axis
fi
```

펜스의 마지막 줄(`qg-verdict-args: --new-failures K …`)이 이 iteration 의 차등 결과 줄이다 — 글자 그대로 들고 있다가 SKILL 의
`## Final verdict` 판정 펜스에 붙인다. 그 줄이 없으면(`verdict.py` 가 0 이 아닌 값으로 끝났다) stderr 를 그대로 보이고 멈춘다 — 판정 없음.

`per_adapter` 의 `attributions` 에 `NEW_REGRESSION` 인 unit 이 있으면 그 unit 만 HEAD 축 트리에서 한 번 다시 돌리고
(flaky 재실행) 이 펜스를 다시 부른다. 마지막 호출의 결과가 이 iteration 의 결과다(R15):

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/run-test-selection.sh" run "<head_tree>" "<runner>" flaky "<memo>/head-<runner>-i<N>.tsv" <NEW_REGRESSION unit>...
```

## D6 트리 정리 — 모든 종료 경로

이 iteration 에서 만든 트리는 결과가 어떻든 지운다(R23). 지울 트리가 없으면 건너뛴다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
for t in "<base_tree>" "<head_tree>"; do
  if [ -n "$t" ] && [ -d "$t" ]; then "$QG/scripts/qg-worktree.sh" remove "$t"; fi
done
```

## D7 판정 입력

Step 4 의 합성기에 싣는 판정 입력은 아래 표가 정한다. 실행 끝의 판정 줄은 차등 결과 줄을 쓴다(R24) — 이 절차는 값을 옮겨 적지 않는다.

| 이 절차의 결과 | `verdict.py` 에 |
|---|---|
| D0 의 kill switch | `--reason kill-switch` |
| `diff_rc=0` 이고 `$RD/differential.yaml` 이 있다 | `--differential "$RD/differential.yaml"` |
| `diff_rc` 가 0 이 아니다 · 파일이 없다 · D5 전에 절차가 끝났다(D0 메모 실패 · D2 exit 4 포함) | `--reason error-axis` (R18) |

D5 전에 끝난 경우에는 D1 의 `axis=mismatch` 와, D0 의 메모 만들기가 실패한 실행의 이후 모든 iteration 이 함께 든다.
D5 에 닿지 못한 iteration 은 이 펜스로 차등 결과 줄을 낸다(D5 의 두 행은 D5 펜스가, kill switch 행은 SKILL 의 kill switch 문단 펜스가 낸다):

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
python3 "$QG/scripts/verdict.py" --emit-args --reason error-axis
```

판정 줄의 「차등 새 실패」 칸은 마지막 iteration 의 차등 결과 줄의 `--new-failures` 값이다 — D5 펜스의 `verdict.py --emit-args` 가
그 사본의 `new_failures:` 에서 낸다. `result.md` 의 `## 차등 테스트` 에는 그 사본을 그대로 붙이고, D2 에서
커버리지로 세지 않은 테스트 목록(`$RD/differential-not-counted.md`)을 덧붙인다. 양측 빨강을 공시하는
`resolution_disclosure:` 줄이 있으면 판정 줄 옆에도 그대로 보인다(R10). bulk 러너가 양측 red 면 이 문장을 그대로 쓴다:

> `기준선도 빨간 상태입니다. 이 러너(<runner>)는 파일 단위 지목이 안 되므로 그 안에 새 회귀가 숨었는지 구분하지 못했습니다.`

## D8 실행 끝 — 메모 지우기

파이프라인이 어느 경로로 끝나든(최종 판정 · Stop · 중단) 마지막에 메모를 지운다(R6). 최종 판정으로 끝나면 SKILL 의
`## Final verdict` 기록 펜스 바로 뒤, 게시 앞이다 — 기록은 메모가 아니라 세션 폴더의 사본을 읽는다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/qg-worktree.sh" memo-drop "<memo>"
```
