#!/usr/bin/env bash
# state-keying 불변식 회귀 락 — read==write 디렉토리(harness sid).
# 전신 test_reviewing_spec_lock.sh(AC1/AC2/AC14/AC8-a·b·c/AC11)의 대상(review_lock.py
# set/pause, harness_sid 배선)은 SKILL 을 arm_ledger 세 verb 로 재배선하며 소멸했고,
# 살아남은 불변식은 좁혀서 승계했다 — 내용이 살아 있는 불변식을 형태 변화 이유로
# 버리는 것은 삭제 스윕의 실패 모드다.
#
# ── 문서 리뷰 엔진 전환(reviewing-spec 껍데기화)이 이 파일에 한 일 ────────────
# 두 가지다.
#
# ① **구조 앵커 재조준.** 껍데기의 절 이름이 바뀌었다(`## Steps` → `## 입력`,
#    `## Approve handoff sequence` → `### check-born`, Phase 5 의 두 종료 자리 →
#    `### clear-inflight A/B`). 창을 재조준하지 않으면 이 파일의 여덟 단언이 전부
#    「윈도우가 비었다」로 떨어져 **무엇도 재지 못한다.** 재는 것은 그대로다.
#
# ② **S2 의 대상 교체.** 옛 S2 는 SKILL 안의 리터럴 `continuity read collapse 금지`
#    를 찾았다. 그 문구가 지키던 것은 `rereview_count`/`issue_history` continuity
#    카운터를 harness-sid 로 collapse 하지 말라는 것이었는데, 그 카운터가 엔진 상태
#    (`docreview-state.md`)로 이관되면서 **그 위험 자체가 사라졌다** — 이제 껍데기가
#    세는 continuity 카운터가 없다. 없어진 규칙의 리터럴을 계속 요구하면 락은
#    거짓 인용을 강제하는 장치가 된다. 그래서 지우지 않고, 이 파일의 본래 주제
#    (state keying)에서 **아직 살아 있는 위험**으로 대상을 바꾼다: 껍데기의 READ 와
#    상태를 쓰는 WRITE 전부가 같은 `$STATE` 디렉토리를 가리키는가(∀ 형태).
#    S3/S9 는 각 자리의 «존재»를, S8/S10 은 `$session_id` 라는 «한 가지» 오키잉을
#    잡는다 — 새 이름의 세 번째 키가 들어오면 셋 다 침묵한다. S2 가 그 자리를 맡는다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$REPO_ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# 윈도우 추출: ASCII-stable 구조 앵커로 대상 절만 잘라 grep(섹션 배치 증명).
# 창 함수의 골격은 옛 test_reviewing_spec_lock.sh 에서 그대로 옮긴 것이다 — 이미 이
# SKILL 에 대해 동작하는 술어를 재작성하지 않고 앵커 문자열만 새 절 이름으로 바꾼다.
# sed 의 범위 주소는 **종료 주소가 매칭되지 않으면 EOF 까지** 출력한다. 그러면 "같은
# 섹션 안에 있다"를 주장하는 락이 조용히 file-wide 존재 확인으로 바뀐다 — 측정:
# step-4 라벨을 한 토큰 rename 하면 step3 윈도우가 12줄 → 130줄(217줄 파일 중)로
# 늘어나는데 스위트는 GREEN 이었고, 이어서 advisory 를 kill-switch 섹션으로 옮겨도
# GREEN 이었다(공존 주장 완전 무효화).
#
# 기존 `[[ -z ]]` 가드는 **빈** 윈도우만 잡는다 — 한쪽만 보는 가드다. 그래서 종료
# 앵커의 존재를 먼저 확인하고, 없으면 **빈 출력**을 낸다. 새 보고 경로를 만들지 않고
# 이미 있는 빈-윈도우 FAIL 가드를 재사용하는 것이 요점이다(락이 늘면 락끼리 어긋난다).
# **존재 확인만으로는 부족하다.** sed 는 종료 주소를 시작 매치 **다음 줄부터** 찾으므로,
# 종료 앵커가 파일에 있어도 시작보다 **앞에** 있으면 범위는 그대로 EOF 까지 흐른다.
# 실측: step-3 블록을 routing-table 뒤로 옮기면 윈도우가 12줄 → 129줄이 되는데 앵커는
# 여전히 존재하므로 존재-검사는 통과하고 스위트는 GREEN 이었다(= 고쳤다고 믿은 그 구멍).
# 그래서 물어야 할 것은 "앵커가 있는가" 가 아니라 **"범위가 앵커에서 끝났는가"** 다 —
# 출력의 마지막 줄이 종료 앵커면 sed 는 거기서 멈춘 것이고, 아니면 EOF 까지 흐른 것이다.
# 이 술어는 앵커 부재도 함께 잡으므로(없으면 마지막 줄도 매치되지 않는다) 이전 검사를
# 포함한다. 새 보고 경로는 만들지 않는다 — 빈 출력으로 기존 FAIL 가드를 그대로 쓴다.
bounded_window() {  # $1=시작 정규식  $2=종료 정규식
  local out; out="$(sed -n "/$1/,/$2/p" "$SKILL")"
  [[ -n "$out" ]] || return 0
  grep -q "$2" <<<"$(tail -n1 <<<"$out")" || return 0
  printf '%s\n' "$out"
}

step1_window()  { bounded_window '^## 입력$' '^## 프로필$'; }

# W: 입력 윈도우가 비어 있지 않다 — 빈 윈도우는 앵커(## 입력 / ## 프로필 헤더)가
# SKILL에서 사라졌다는 뜻이지 통과가 아니다.
w_out="$(step1_window)"
[[ -n "$w_out" ]] \
  && ok "W: 입력 윈도우가 비어 있지 않다 (앵커 생존)" \
  || no "W: 입력 윈도우가 비었다 — 구조 앵커 파손"

# S1 (전 AC12 그대로): `## 입력` 이 state_path.py session-id 로 read 를 해석
# (read==write 디렉토리 불변식 — 이게 깨지면 스킬이 훅과 다른 파일을 읽어
# arm-once 전체가 무의미해진다).
# herestring 으로 받는다 — 파이프면 `grep -q` 가 첫 매치에 종료하며 생산자에 SIGPIPE 를
# 보내고, `set -o pipefail` 이 그 141 을 파이프라인 실패로 표면화해 **매치했는데도 FAIL**
# 이 난다. 이 파일에서 파이프를 쓰던 유일한 검사였고, S5–S7 은 이미 herestring 이다.
grep -qF 'state_path.py" session-id' <<<"$w_out" \
  && ok "S1: 입력 절이 state_path.py session-id 로 state 를 해석한다" \
  || no "S1: 입력 절에 session-id read 해석이 없다"

# S2 (재조준 — 헤더 ② 참조): read==write 디렉토리 불변식의 **∀ 형태**.
#   (a) READ 가 `$harness_sid` 로 `$STATE` 를 만든다.
#   (b) sid 를 받는 arm_ledger 상태-write 가 **전부** 같은 `$harness_sid` 로 키잉된다.
# (b) 는 «키가 $session_id 가 아니다»(S8/S10)보다 세다 — 어떤 이름이 오든 전체 수와
# harness_sid 로 키잉된 수가 갈리는 순간 잡힌다. 열거가 아니라 도출이다.
grep -qE '^STATE="\$ROOT/\$harness_sid/' "$SKILL" \
  && ok "S2a: arm 원장 READ 가 \$harness_sid 로 \$STATE 를 만든다" \
  || no "S2a: \$STATE 가 \$harness_sid 에서 도출되지 않는다 — 훅과 다른 파일을 읽는다"
# S2a2: 엔진 상태 디렉터리는 arm 원장과 **같은 루트·세션** 아래에서 **문서별로** 도출된다.
# S2a 의 `^STATE="` 는 `STATE_DIR=` 을 매치하지 않으므로 따로 잰다. 세 성분이 전부 있어야 한다:
# 루트(`$ROOT`)와 세션(`$harness_sid`)이 arm 원장과 갈리면 같은 세션의 두 상태가 다른 자리에
# 앉아 재개·GC·훅 판독이 서로 다른 것을 보고, 문서(`$spec_path`)가 빠지면 한 세션에서 리뷰한
# 두 문서가 한 원장의 라운드·재리뷰 상한·finding 을 나눠 쓴다. 도출이 실제로 문서마다 다른
# 자리를 내는지는 실행으로 잰다(test_reviewing_spec_residue.sh 의 P 셀).
grep -qE '^STATE_DIR="\$\(python3 "[^"]*/scripts/docreview_state\.py" state-dir-for --root "\$ROOT" --session "\$harness_sid" --doc "\$\{spec_path:-\}"' "$SKILL" \
  && ok "S2a2: 엔진 state 디렉터리가 \$ROOT · \$harness_sid · \$spec_path 에서 state-dir-for 로 도출된다" \
  || no "S2a2: \$STATE_DIR 이 \$ROOT · \$harness_sid · \$spec_path 셋에서 state-dir-for 로 도출되지 않는다 — 엔진 상태가 arm 원장과 갈리거나 문서를 넘어 섞인다"
# S2a3 (∀ — S2a2 의 짝): SKILL 안의 `STATE_DIR=` 대입이 **전부** 같은 도출을 거친다. S2a2 는
# `## 입력` 한 줄의 존재만 잰다 — 펜스의 재도출이나 새 대입이 세션 디렉토리 자체를 쓰면
# 침묵한다. 하한 2(`## 입력` + codex 펜스)는 이 등식의 vacuity 바닥이다.
sd_tot=$(grep -cE '^[[:space:]]*STATE_DIR=' "$SKILL")
sd_der=$(grep -cE '^[[:space:]]*STATE_DIR=.*docreview_state\.py" state-dir-for --root "\$ROOT" --session "\$harness_sid" --doc "\$\{spec_path:-\}"' "$SKILL")
if [[ "$sd_tot" -lt 2 ]]; then
  no "S2a3: STATE_DIR 대입이 ${sd_tot}건뿐 — \`## 입력\` 과 codex 펜스 두 자리가 안 찼다. 아래 등식은 이 상태에서 공허하다"
elif [[ "$sd_tot" -eq "$sd_der" ]]; then
  ok "S2a3: STATE_DIR 대입 ${sd_tot}건이 전부 문서별 도출을 거친다"
else
  no "S2a3: STATE_DIR 대입 ${sd_tot}건 중 문서별 도출은 ${sd_der}건 — 나머지가 세션 디렉토리를 문서를 넘어 나눠 쓴다"
fi
# sid 를 받는 verb 는 둘뿐이다(check-born 은 sid 인자를 안 받는다 — 조회이지 상태
# write 가 아니다). 그 둘의 **모든** 호출과 harness_sid 로 키잉된 호출의 수를 비교한다.
sid_tot=$(grep -cE 'arm_ledger\.py" (mark-reviewed|clear-inflight) "' "$SKILL")
sid_hs=$(grep -cE 'arm_ledger\.py" (mark-reviewed|clear-inflight) "\$harness_sid"' "$SKILL")
if [[ "$sid_tot" -lt 3 ]]; then
  no "S2b: sid 를 받는 arm_ledger 호출이 ${sid_tot}건뿐 — 세 자리(mark-reviewed 1 + clear-inflight 2)가 안 찼다. 아래 등식은 이 상태에서 공허하다"
elif [[ "$sid_tot" -eq "$sid_hs" ]]; then
  ok "S2b: sid 를 받는 arm_ledger 호출 ${sid_tot}건이 전부 \$harness_sid 로 키잉된다 (read==write ∀)"
else
  no "S2b: sid 를 받는 arm_ledger 호출 ${sid_tot}건 중 \$harness_sid 키잉은 ${sid_hs}건 — 나머지가 훅과 다른 파일을 쓴다"
fi

# S3 (전 AC8-count 승계 — 형태만 변경): "trio 명령이 전부 $harness_sid로 키잉된다"는
# 이제 arm_ledger.py의 mark-reviewed 한 verb로 표현된다 (check-born은 sid 인자를 받지
# 않는다 — approve 시점 조회이지 세션 상태 write가 아님).
# **정상 경로의 상태 write 는 여전히 이것 하나다.** v0.36.0 이 더한 `clear-inflight` 는
# 종료 자리 두 곳(`### clear-inflight A` 문서 부재 · `### clear-inflight B` ④ 멈춤)에서만 도는 복구 verb 라 이 개수에 들어오지
# 않는다 — 같은 read==write 불변식을 지지만 S9/S10 이 따로 잠근다.
cnt=$(grep -cE 'arm_ledger\.py" mark-reviewed "\$harness_sid' "$SKILL")
[[ "$cnt" -eq 1 ]] \
  && ok "S3: exactly 1 arm_ledger state-write command keys \$harness_sid (got $cnt)" \
  || no "S3: expected 1 harness_sid-keyed arm_ledger command, got $cnt"

# S4 (신규 teeth): S3의 정규식이 "$session_id"를 쓴 가짜 줄을 배제한다 — S3이
# 존재만 재고 값을 구분 못 하는 위양성을 봉쇄. production 파일은 건드리지 않고
# heredoc 프로브 문자열 하나에 같은 grep을 돌려 0건인지만 본다.
probe=$(cat <<'EOF'
python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/arm_ledger.py" mark-reviewed "$session_id" "$spec_path"
EOF
)
probe_cnt=$(grep -cE 'arm_ledger\.py" mark-reviewed "\$harness_sid' <<<"$probe")
[[ "$probe_cnt" -eq 0 ]] \
  && ok "S4: S3 정규식이 \$session_id 가짜 줄을 배제한다 (real teeth)" \
  || no "S4: S3 정규식이 \$session_id 가짜 줄까지 매치했다 (got $probe_cnt) — 위양성"

# S5 (전 AC8-c 승계): approve 창에서 `check-born` 이 **실제로 호출된다**.
# V9 는 'approve_handoff' 를 production 밖으로 밀어내는 *음의* 락이고, 음의 락은
# 대체물을 통째로 지워도 통과한다. 전신 AC8-c 는 approve 창 안의 배선을 잡고 있었으나
# 승계 없이 삭제됐다 — mutation 으로 확인된 구멍(이 줄을 지워도 shell 스위트 전부 green).
# 설계 §6 이 이 호출을 AP2 검증 앵커로 지정하므로 배선은 load-bearing 이다.
approve_window() { bounded_window '^### check-born' '^### clear-inflight A'; }
aw_out="$(approve_window)"
if [[ -z "$aw_out" ]]; then
  no "S5: approve 윈도우가 비었다 — 구조 앵커 파손(통과 아님)"
elif grep -qF 'arm_ledger.py" check-born' <<<"$aw_out"; then
  ok "S5: approve 창에서 check-born 이 호출된다 (전 AC8-c 승계)"
else
  no "S5: approve 창에 check-born 호출이 없다 — 미커밋 advisory 배선 소실"
fi

# S7 (전 AC11-b 승계): degradation advisory 가 살아 있다.
# "빈 harness_sid 는 조용히 skip 하지 않고 loud advisory 를 남긴다"는 계약이고,
# CLAUDE.md 의 graceful-degradation-with-loud-logging 요구다. 조용한 degrade 는
# 문서가 리뷰 완료로 기록되지 않은 채 넘어간다는 뜻이다.
#
# **짝이던 S6 은 v0.36.0 에서 없앴다** — 그것이 잠그던 advisory 는 진입 절의
# 진입-정리 write 가 실패했음을 알리는 문구였는데, 그 write 자체가 은퇴했다(진입 시점의
# 상태 계약이 통째로 사라졌다). 지금 진입 시점에는 sid 에 의존하는 write 가 없다 —
# 남은 write 는 `### mark-reviewed`(S7)와 종료 자리의 `clear-inflight`
# (S9/S10)뿐이고, 둘 다 진입이 아니라 종료 쪽이다. 락을 남기려면 아무 일도 하지 않는
# 단계를 되살려야 하는데, 그건 락이 제품을 끌고 다니는 것이다.

# S7 은 섹션 윈도우 안에서 잰다 — file-wide grep 이면 리터럴이 SKILL 어디에 있든
# 통과해, advisory 를 기록 지점 밖으로 옮기는 변경을 못 잡는다(라벨은 mark-reviewed
# 자리라고 주장하면서). 리터럴 삭제 mutation 만으로는 두 설계를 구분할 수 없다.
step3_window() { bounded_window '^### mark-reviewed' '^### check-born'; }
s3_out="$(step3_window)"
if [[ -z "$s3_out" ]]; then
  no "S7: mark-reviewed 윈도우가 비었다 — 구조 앵커 파손(통과 아님)"
elif grep -qF '리뷰 완료 기록(mark-reviewed)을 남기지 못했다' <<<"$s3_out"; then
  ok "S7: mark-reviewed 창 안에 미기록 advisory 존재 (전 AC11-b)"
else
  no "S7: mark-reviewed 창에서 미기록 advisory 소실 — 조용한 degrade"
fi

# S8 (S3 의 in-file 음의 짝): S3 은 개수만 세므로, 올바른 `$harness_sid` 줄과 엉뚱한
# `$session_id` 줄이 함께 있어도 개수를 채워 통과한다. S4 는 heredoc 프로브에 대한
# *정규식 대조군*이지 검사 대상 파일의 속성이 아니다 — 전신 AC8-a/b 는 창 안에서
# `! grep ... "$session_id"` 를 걸고 있었다.
if grep -qE 'arm_ledger\.py" mark-reviewed "\$session_id' "$SKILL"; then
  no "S8: SKILL 안에 \$session_id 로 키잉된 arm_ledger 호출이 있다 — read==write 파손"
else
  ok "S8: SKILL 안에 \$session_id 로 키잉된 arm_ledger 호출이 없다 (S3 의 음의 짝)"
fi

# S9: 종료 자리 **두 곳 각각**에서 `clear-inflight` 가 호출된다.
# 두 경로(A = spec_path 부재 · B = ④ 멈춤)는 `mark-reviewed` 가
# 배제된 채로도 도달할 수 있고, 그때 in-flight 표시를 두고 나가면 그 문서는 TTL
# (900초)까지 발견에서 빠진다. file-wide grep 은 두 호출이 한 자리로 뭉쳐도 통과하므로
# **경로별 윈도우**로 잰다 — 이 파일이 S1/S5/S7 에서 쓰는 것과 같은 이유다.
stepA_window() { bounded_window '^### clear-inflight A' '^### clear-inflight B'; }
stepC_window() { bounded_window '^### clear-inflight B' '^## 게이트$'; }
for pair in "clear-inflight A:stepA_window" "clear-inflight B:stepC_window"; do
  label="${pair%%:*}"; fn="${pair##*:}"
  out="$($fn)"
  if [[ -z "$out" ]]; then
    no "S9: $label 윈도우가 비었다 — 구조 앵커 파손(통과 아님)"
  elif grep -qE 'arm_ledger\.py" clear-inflight "\$harness_sid' <<<"$out"; then
    ok "S9: $label 창에서 clear-inflight 가 \$harness_sid 로 호출된다"
  else
    no "S9: $label 창에 harness_sid-키잉 clear-inflight 호출이 없다 — 표시가 TTL 까지 남는다"
  fi
done

# S10 (S9 의 음의 짝): S9 는 존재만 재므로 엉뚱한 sid 로 키잉된 호출이 **함께** 있어도
# 통과한다. `$session_id` 로 키잉하면 스킬이 훅과 다른 파일의 표시를 지워, 훅이 읽는
# 원장에는 표시가 그대로 남는다 — 조용한 fail-open 이라 사람 눈엔 성공으로 보인다.
if grep -qE 'arm_ledger\.py" clear-inflight "\$session_id' "$SKILL"; then
  no "S10: SKILL 안에 \$session_id 로 키잉된 clear-inflight 가 있다 — read==write 파손"
else
  ok "S10: SKILL 안에 \$session_id 로 키잉된 clear-inflight 가 없다 (S9 의 음의 짝)"
fi

# S11: 빈 `$harness_sid` advisory 가 **형제 세 자리 전부**에 있다.
# S7 은 mark-reviewed 자리만 잡는다. 종료 자리 둘은 같은 모양의 호출인데
# 그 자리엔 락이 없었고, 실제로 한 자리만 이 문구를 빠뜨린 채 머지될 뻔했다.
# 집행 방향 자체는 이미 fail-closed 다(`SESSION_PATTERN` 이 '' 를 거부해 arm_ledger 가
# exit 2 + stderr). 여기서 잠그는 것은 **공시**다 — 세 자리 중 하나만 침묵하면 그
# 비대칭이 다음 복사본으로 옮겨간다. 그것이 이 결함이 퍼지는 경로다.
for pair in "clear-inflight A:stepA_window" "clear-inflight B:stepC_window"; do
  label="${pair%%:*}"; fn="${pair##*:}"
  out="$($fn)"
  if [[ -z "$out" ]]; then
    no "S11: $label 윈도우가 비었다 — 구조 앵커 파손(통과 아님)"
  elif grep -qE '\$harness_sid` 가 빈 값이면.*advisory' <<<"$out"; then
    ok "S11: $label 창에 빈 harness_sid advisory 지시가 있다"
  else
    no "S11: $label 창에 빈 harness_sid advisory 지시가 없다 — 형제 자리와 비대칭"
  fi
done
finish
