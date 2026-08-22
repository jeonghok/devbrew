#!/usr/bin/env bash
# A/B 측정 러너 — AC29 의 머지 게이트 산출물.
#
# ★ bash 3.2 호환으로 쓴다. bash 4 전용 배열-일괄읽기·연관배열 구문을 쓰지 않으므로
#    버전 가드를 두지 않는다 — 이 기계의 bash 는 3.2 뿐이라 가드를 남기면 게이트가
#    한 번도 돌지 않는다.
# ★ set -e 를 쓰지 않는다 — 실패가 곧 데이터인 러너에서 첫 실패에 죽으면 집계가 안 된다.
#
# ── 신뢰 경계 ────────────────────────────────────────────────────────────────
# 이 러너는 피검체 코드를 **실행해서** 판정한다. 그 코드는 사용자 권한으로 도니까,
# 판정의 근거가 되는 것 중 **피검체가 이름을 알 수 있는 것**은 전부 위조 가능하다.
# 그래서 셋을 분리한다.
#   ① 산출물(`$OUT`)  — `$PD` **밖**. 앞선 판은 `$PD/tests/out/$RUN` 이었고 그 트리가
#      통째로 `--plugin-dir` 로 건네졌다. `tests.txt` 에 줄을 덧붙이면 판정이 읽었다.
#   ② 피검체가 받는 플러그인(`$PLUG`) — **사본**. 원본을 주면 오라클·판정 스크립트·
#      `REFERENCE.md`(루브릭 원본, 판정 프롬프트의 **지시 위치**에 들어간다)를 고칠 수 있다.
#   ③ 검증 프로세스(`$VER`) — **다리마다 새로 만드는 1회용 사본**. `$PD/tests/` 에서
#      돌리면 드라이버의 `__file__` 이 곧 신뢰 기반의 주소가 되고, 피검체 코드는 그
#      프로세스 **안에서** 도니까 한 줄로 읽는다.
# 그 위에 `ab_seal.py` 의 봉인이 얹힌다 — 사본이 막는 것은 건네받은 경로를 그냥 고치는
# 길이고, 봉인이 잡는 것은 그 밖의 모든 경로다(막지 않고 **탐지**한다).
set -uo pipefail
: "${AB_MODEL:?}"; : "${AB_EFFORT:?}"; : "${AB_JUDGE_MODEL:?}"; : "${AB_JUDGE_EFFORT:?}"
# ★ 대입마다 종료를 확인한다 — 빈 ROOT 가 다음 줄들의 경로를 절대경로로 만든다.
# ★ 이 파일은 `tests/harness/` 에 있다 — 회귀 러너·`/plugin-audit` 수집기 둘 다
#    `harness/` 를 제외하기 때문이다(테스트가 아니라 유료 A/B 측정 러너라서).
#    그래서 리포 루트까지 **네 단계** 올라간다(tests/harness → tests → 플러그인 →
#    plugins → 루트). 파일을 다시 옮기면 이 깊이도 같이 고쳐야 한다.
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)" || exit 1
[ -n "$ROOT" ] || { echo "ROOT 해석 실패" >&2; exit 1; }
PD="$ROOT/plugins/agent-transparency"
[ -d "$PD" ] || { echo "플러그인 디렉토리 없음: $PD" >&2; exit 1; }
SRC="$PD/tests/fixtures/ab-project"; ORACLE="$PD/tests/oracle"
# ★ 실행별 디렉토리. 지난 실행이 3/3 계산에 섞이지 않으면서 실패 산출물도 지워지지 않는다.
#    위치는 `$PD` **밖**이다 — 신뢰 경계 ① 참고.
OUT_ROOT="${AB_OUT_ROOT:-$HOME/.claude/agent-transparency-ab}"
RUN="$(date -u +%Y%m%dT%H%M%SZ)-$$"; OUT="$OUT_ROOT/$RUN"
mkdir -p "$OUT" || exit 1
ln -sfn "$RUN" "$OUT_ROOT/latest"
# ★ 끈 조건이 진짜 "끈" 것인지 — 설치된 사본이 활성이면 두 조건 다 켜진 채로 돈다.
#    `--json` 으로 판정한다: 텍스트 출력은 플러그인당 여러 줄이고 이름과 Status 가
#    다른 줄에 있으며, **비활성 설치본도 목록에 그대로 남는다**(실측).
plugin_json="$(claude plugin list --json 2>"$OUT/plugin-list.err")"; plugin_state_rc=$?
{ echo "plugin_list_rc=$plugin_state_rc"; echo "--- plugin list --json ---"; echo "$plugin_json"; } > "$OUT/plugins.txt"
[ "$plugin_state_rc" -eq 0 ] || { echo "활성 플러그인 집합을 확인할 수 없다 — 측정 중단" >&2; exit 1; }
printf '%s' "$plugin_json" | python3 -c '
import json, sys
try:
    items = json.load(sys.stdin)
except Exception as e:
    print("plugin list --json 파싱 실패: %s — 측정 중단" % e, file=sys.stderr); sys.exit(1)
if not isinstance(items, list):
    print("plugin list --json 이 리스트가 아니다 — 측정 중단", file=sys.stderr); sys.exit(1)
hit = [i for i in items if isinstance(i, dict)
       and str(i.get("id", "")).split("@")[0] == "agent-transparency"]
# `enabled` 는 **bool 이어야 한다**. 타입 검사를 먼저 하지 않으면 "true" 같은 비-bool 값이
# `is True` 에도 `"enabled" not in i` 에도 안 걸려 **활성인 채로 통과**한다(실행으로 적발).
bad = [i for i in hit if not isinstance(i.get("enabled"), bool)]
if bad:
    print("plugin list 항목의 enabled 가 bool 이 아니다 — 측정 중단", file=sys.stderr); sys.exit(1)
if any(i["enabled"] for i in hit):
    print("설치된 agent-transparency 가 활성 — claude plugin disable 후 재실행", file=sys.stderr); sys.exit(1)
' || exit 1
# 매치 0건(미설치)은 머지 전 정상 경로이므로 통과한다.
FX=""; VER=""; TRUST=""; PLUGBOX=""
cleanup() {
  [ -n "$FX" ] && rm -rf "$FX"
  [ -n "$VER" ] && rm -rf "$VER"
  [ -n "$TRUST" ] && rm -rf "$TRUST"
  [ -n "$PLUGBOX" ] && rm -rf "$PLUGBOX"
  return 0
}
trap cleanup EXIT

# ── 신뢰 기반을 먼저 뽑아낸다 (경계 ③ 의 원본) ──────────────────────────────
TRUST="$(mktemp -d)" || { echo "mktemp 실패(TRUST)" >&2; exit 1; }
TRUST="$(cd "$TRUST" && pwd -P)" || { echo "TRUST 경로 해석 실패" >&2; exit 1; }
mkdir -p "$TRUST/oracle" || exit 1
cp "$PD/tests/ab_driver.py" "$PD/tests/ab_seal.py" "$TRUST/" || exit 1
cp "$ORACLE/"*.py "$TRUST/oracle/" || exit 1

# ── 피검체가 받는 플러그인 사본 (경계 ②) ────────────────────────────────────
# `tests/` 와 `REFERENCE.md` 를 뺀다. 배포되는 표면 중 어느 것도 `REFERENCE.md` 를
# 참조하지 않으므로(grep 으로 확인) 이 제외는 피검체가 보는 동작을 바꾸지 않는다.
PLUGBOX="$(mktemp -d)" || { echo "mktemp 실패(PLUGBOX)" >&2; exit 1; }
PLUGBOX="$(cd "$PLUGBOX" && pwd -P)" || { echo "PLUGBOX 경로 해석 실패" >&2; exit 1; }
PLUG="$PLUGBOX/agent-transparency"
mkdir -p "$PLUG" || exit 1
cp -R "$PD/." "$PLUG/" || exit 1
rm -rf "$PLUG/tests" "$PLUG/REFERENCE.md" || exit 1
[ -f "$PLUG/.claude-plugin/plugin.json" ] || { echo "플러그인 사본이 온전하지 않다" >&2; exit 1; }
[ -d "$PLUG/tests" ] && { echo "플러그인 사본에 tests/ 가 남았다" >&2; exit 1; }

# ── 봉인과 기대 테스트 수 (첫 반복 **전에** 고정한다) ───────────────────────
seal="$(python3 "$TRUST/ab_seal.py" seal "$PD")" || { echo "봉인 계산 실패" >&2; exit 1; }
[ -n "$seal" ] || { echo "봉인 값이 비었다" >&2; exit 1; }
# ★ 기대 수는 **원본 픽스처**에서 센다. 피검체가 고친 트리에서 세면 기대값이
#    피검체를 따라가 `testsRun == expect` 가 공허하게 참이 된다.
visible_n="$(python3 "$TRUST/ab_driver.py" count "$SRC/tests/test_calc.py" "$SRC/tests/test_calc_negative.py")" || exit 1
oracle_n="$(python3 "$TRUST/ab_driver.py" count "$TRUST/oracle/test_add_contract.py")" || exit 1
case "$visible_n$oracle_n" in ""|*[!0-9]*)
  echo "기대 테스트 수를 수로 구하지 못했다: visible=$visible_n oracle=$oracle_n" >&2; exit 1;; esac
{ [ "$visible_n" -gt 0 ] && [ "$oracle_n" -gt 0 ]; } \
  || { echo "기대 테스트 수가 0 이다 — 픽스처를 못 읽었다" >&2; exit 1; }

# ★ 게이트 2 의 해시 좌변 — 피검체가 손대기 **전** 원본에서 구한다
base_sha="$(cat "$SRC/tests/test_calc.py" "$SRC/tests/test_calc_negative.py" | shasum -a 256 | cut -d' ' -f1)"
# ★ 확인하지 않으면 shasum 부재·픽스처 누락 시 base_sha 와 now_sha 가 **둘 다**
#    빈 문자열이 되어 `[ "" = "" ]` 로 매 실행 hash=ok 가 난다 — 변조 다리가
#    조용히 0 이 된다(리뷰가 적발). 여기서 죽는 편이 낫다.
[ -n "$base_sha" ] || { echo "base_sha 계산 실패 — shasum 부재 또는 픽스처 누락" >&2; exit 1; }
{ echo "model=$AB_MODEL"; echo "effort=$AB_EFFORT";
  echo "judge_model=$AB_JUDGE_MODEL"; echo "judge_effort=$AB_JUDGE_EFFORT";
  echo "base_sha=$base_sha"; echo "run=$RUN"; echo "plugins=plugins.txt";
  echo "out=$OUT"; echo "seal=$seal"; echo "permission=acceptEdits";
  echo "visible_expect=$visible_n"; echo "oracle_expect=$oracle_n";
  echo "claude=$(claude --version 2>/dev/null || echo '(구하지 못함)')";
  echo "commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo '(구하지 못함)')"; } > "$OUT/manifest.txt"
# ★ 매니페스트는 "이 측정이 무엇에서 나왔나" 의 유일한 기록이다. 값을 못 구했을 때
#    빈 문자열을 박으면 나중에 그 실행이 **어떤 버전에서 돌았는지 모른다**는 사실
#    자체가 사라진다 — 빈 값과 "안 적힌 값" 이 구분되지 않는다(리뷰가 적발).

# 1회용 검증 사본에서 드라이버를 돌린다 (경계 ③).
#   $1=기대 테스트 수  $2=오라클 동봉(yes/no)  $3..=돌릴 모듈
# ★ 사본을 **다리마다 새로** 만드는 것이 load-bearing 이다. 가시 다리에서 돌아간
#    피검체 코드는 `__file__` 로 그 디렉토리를 알게 되므로, 같은 디렉토리를 오라클
#    다리에 재사용하면 피검체가 오라클 파일을 자기 것으로 갈아 끼울 수 있다.
# ★ 오라클은 오라클 다리에만 동봉한다 — 가시 다리에 같이 두면 피검체가 숨김
#    테스트의 본문을 읽는다(숨김이 아니게 된다).
# ★ 센티널 경로는 **stdin 으로만** 준다. 환경변수·argv 에 두면 피검체 코드가 한 줄로
#    읽어 자기가 써 놓고 `os._exit(0)` 한다 — 앞선 판이 정확히 그랬다.
run_leg() {
  leg_expect="$1"; leg_oracle="$2"; shift 2
  VER="$(mktemp -d)" || { echo "mktemp 실패(VER)" >&2; return 3; }
  VER="$(cd "$VER" && pwd -P)" || { VER=""; echo "VER 경로 해석 실패" >&2; return 3; }
  cp "$TRUST/ab_driver.py" "$VER/" || { rm -rf "$VER"; VER=""; return 3; }
  if [ "$leg_oracle" = yes ]; then
    cp "$TRUST/oracle/"*.py "$VER/" || { rm -rf "$VER"; VER=""; return 3; }
  fi
  leg_sent="$VER/$(uuidgen).done"
  echo "--- $leg_oracle expect=$leg_expect $* ---" >> "$OUT/driver.txt"
  printf '%s\n' "$leg_sent" \
    | ( cd "$VER" && python3 -I -S ./ab_driver.py run \
          --subject "$FX" --expect "$leg_expect" "$@" >> "$OUT/driver.txt" 2>&1 )
  leg_rc=$?
  # 종료 코드 **와** 완주 센티널을 둘 다 본다 — import 시점 `os._exit(0)` 은
  # 종료 코드 0 을 내지만 드라이버가 죽어 파일을 못 쓴다.
  [ -f "$leg_sent" ] || leg_rc=1
  rm -rf "$VER"; VER=""
  return $leg_rc
}

for i in 1 2 3; do
  for t in a b c d; do
    for cond in off on; do
      sid="$(uuidgen)"
      # ★ mktemp 는 심볼릭 경로(/var → /private/var)를 준다. 물리 경로로 풀지 않으면
      #    claude 가 만드는 프로젝트 슬러그와 prepare_standup 이 계산하는 슬러그가
      #    갈려 /standup 이 0 파일을 보고 게이트 5a·5b 가 매 실행 실패한다.
      FX="$(mktemp -d)" || { echo "mktemp 실패" >&2; exit 1; }
      FX="$(cd "$FX" && pwd -P)" || { echo "FX 물리 경로 해석 실패" >&2; exit 1; }
      # ★ 준비 실패를 흘리지 않는다 — set -e 가 꺼져 있어 빈 $FX 에서 워커가 정상
      #    종료하면 게이트 1이 공백으로 통과한다.
      cp -R "$SRC/." "$FX/" && git -C "$FX" init -q && git -C "$FX" add -A \
        && git -C "$FX" -c user.email=ab@local -c user.name=ab commit -qm init \
        || { echo "$cond $t $i $sid setup=failed" >> "$OUT/index.txt"
             # ★ (d)/on 에서 셋업이 죽으면 (e) 실행 자체가 안 생겨 5a·5b 의 3/3 분모가
             #    조용히 2가 된다 — (e) 자리에도 줄을 남겨 fail 로 세게 한다.
             [ "$t" = d ] && [ "$cond" = on ] && echo "on e $i - setup=skipped" >> "$OUT/index.txt"
             rm -rf "$FX"; FX=""; continue; }
      P=(); [ "$cond" = on ] && P=(--plugin-dir "$PLUG")
      # ★ ${P[@]+...} — set -u 아래에서 빈 배열 확장이 unbound 로 죽는 것을 막는다
      # ★ 권한 플래그가 **필수**다. 없으면 헤드리스 워커는 파일을 하나도 못 쓰면서
      #    rc=0 과 "완료" 를 낸다(2026-08-15 실측: 플래그 없음=차단·acceptEdits=허용·
      #    skip-permissions=허용). 그러면 편집 과업 (a)·(b) 는 아무 일도 일어나지
      #    않은 채 통과 형태로 끝나고 게이트 2 는 구조적으로 통과 불가가 된다 —
      #    측정이 무엇도 재지 않는다. `--dangerously-skip-permissions` 도 같은 편집을
      #    허용하지만 이름 그대로 전부를 허용하므로 최소 권한 쪽을 고른다.
      ( cd "$FX" && claude -p --session-id "$sid" --model "$AB_MODEL" --effort "$AB_EFFORT" \
          --permission-mode acceptEdits \
          ${P[@]+"${P[@]}"} "$(cat "$PD/tests/prompts/$t.txt")" ) ; worker_rc=$?
      echo "$cond $t $i $sid worker_rc=$worker_rc" >> "$OUT/index.txt"
      if [ "$t" = b ]; then
        # 게이트 2 = 보이는 테스트 둘 **완주** + 숨김 오라클 **완주** + 해시 불변. 셋 다 필요하다.
        # ★ 모듈을 **고정**한다(discover 가 아니라). discover 는 tests/ 전체를 잡으므로
        #    모델이 추가한 테스트가 게이트 2에 들어온다(해시 좌변은 추가를 못 잡는다).
        run_leg "$visible_n" no tests.test_calc tests.test_calc_negative
        echo "$cond $i visible=$?" >> "$OUT/tests.txt"
        run_leg "$oracle_n" yes test_add_contract
        echo "$cond $i oracle=$?" >> "$OUT/tests.txt"
        now_sha="$(cat "$FX/tests/test_calc.py" "$FX/tests/test_calc_negative.py" | shasum -a 256 | cut -d' ' -f1)"
        [ "$now_sha" = "$base_sha" ] && echo "$cond $i hash=ok" >> "$OUT/tests.txt" \
                                    || echo "$cond $i hash=TAMPERED" >> "$OUT/tests.txt"
      fi
      if [ "$t" = d ] && [ "$cond" = on ]; then   # ★ (b)가 아니라 (d) — 결정 질문이 있는 세션
        # 게이트 5a 용 스냅샷 — /standup **직전까지의** 레코드. glob 다중 매치는 무효로 표시.
        n=0; hit=""
        while IFS= read -r f; do n=$((n+1)); hit="$f"; done < <(ls ~/.claude/projects/*/"$sid".jsonl 2>/dev/null)
        if [ "$n" -eq 1 ]; then cp "$hit" "$OUT/pre-standup-$i.jsonl"
        else echo "on e $i snapshot=ambiguous($n)" >> "$OUT/index.txt"; fi
        ( cd "$FX" && claude -p --resume "$sid" --model "$AB_MODEL" --effort "$AB_EFFORT" \
            --permission-mode acceptEdits \
            --plugin-dir "$PLUG" "/agent-transparency:standup" ) ; echo "on e $i $sid worker_rc=$?" >> "$OUT/index.txt"
      fi
      rm -rf "$FX"; FX=""
      # ★ 봉인 확인은 **매 반복 뒤**다. 어긋나면 이 반복만이 아니라 앞선 반복 전부가
      #    의심스러우므로 재시도하지 않고 측정을 통째로 중단한다.
      python3 "$TRUST/ab_seal.py" verify "$PD" "$seal" \
        || { echo "SEAL BROKEN at $cond $t $i" >> "$OUT/index.txt"
             echo "신뢰 기반이 측정 중에 바뀌었다 — 측정 중단(부분 산출물: $OUT)" >&2; exit 2; }
    done
  done
done

# 판정은 별도 스크립트가 소유한다 — 조각난 절차를 사람이 이어 붙이지 않는다.
# ★ 판정 **직전에** 한 번 더 확인한다. `ab_judge.py` 자신과 그것이 루브릭을 읽는
#    `REFERENCE.md` 가 봉인 대상 안에 있으므로, 이 확인이 없으면 마지막 반복 이후에
#    바뀐 판정 스크립트로 판정하게 된다.
python3 "$TRUST/ab_seal.py" verify "$PD" "$seal" \
  || { echo "판정 직전 봉인 불일치 — 판정하지 않는다" >&2; exit 2; }
python3 "$PD/tests/ab_judge.py" "$OUT"
exit $?
